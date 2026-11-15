class_name GrassCarpet
extends Node3D
## Трава-ковёр (14.11, владелец: «хочу, чтобы выглядело как в паке Synty вся природа»): на свободной траве вокруг
## камеры — густые кустики травы и полевые цветы набора Meadow Forest (на картинке набора земли под травой почти не
## видно). Куски по TILE м — по MultiMesh на траву и на цветы (два вызова отрисовки на кусок), без теней, вдали
## каждый кустик гаснет сам (шейдер, fade). Не растёт на дорогах, площадях, тропах, под постройками и у их стен
## (окантовка), на узоре кисти «Земля», под арками акведука, на пашне и в воде; у воды — выше (камыш).
## Куски строятся понемногу каждый кадр (не дольше BUDGET_MS), кусок с поменявшейся землёй — заново.
## Уровни графики: «Высокая» — далеко и густо, «Средняя» — ближе и реже, «Низкая» — только у самой камеры (в обычном
## виде города её нет), «Очень низкая» — нет. Ничего не сохраняется: ковёр — только картинка.
## 15.11 (отзыв владельца: «травы слишком много»): трава — кочками с полянами между ними (два шума: большие пятна и
## кочки), цветов втрое меньше и в основном белые и розовые (shaders/grass_carpet.gdshader, fmode). Дальность — по
## настройке «Трава и цветы» (Близко / Далеко / Не скрывать / Выключить). Кисти «Трава» и «Убрать траву» красят маску
## Land.grass_mask: где посажено — густая трава и цветы, где убрано — пусто (маска сохраняется в городе).

const TILE := 32.0
const BUDGET_MS := 3.0
const Q := {
	"high": {"r": 92.0, "sp": 0.5},
	"medium": {"r": 64.0, "sp": 0.62},
	"low": {"r": 30.0, "sp": 0.78},
	"verylow": {"r": 0.0, "sp": 1.0},
}
## «Трава и цветы» в настройках: во сколько раз дальше (или ближе) прежней дальности уровня графики. По умолчанию — «Далеко»
## на «Высокой» и «Близко» (как было) на остальных: «Низкая» и «Очень низкая» тяжелее не становятся, пока игрок сам не
## выберет «Не скрывать»
const RANGE := {"near": 1.0, "far": 1.7, "all": 3.2, "off": 0.0}
const RANGE_NAMES := {"near": "Близко", "far": "Далеко", "all": "Не скрывать", "off": "Выключить"}
const VERYLOW_ALL_R := 26.0             # «Очень низкая» с «Не скрывать»: ковёр только у самой камеры

static func range_key(st: Dictionary, q: String) -> String:
	var k := str(st.get("grass_range", ""))
	if RANGE.has(k):
		return k
	return "far" if q == "high" else "near"

## Цвет травы (линейный): у корня и на кончиках — сочная жёлто-зелёная, как на картинке набора
const ROOT := Color(0.085, 0.2, 0.025)
const TIP := Color(0.5, 0.66, 0.12)

var game
var land: Land
var radius := 0.0
var spacing := 0.6
var tiles := {}                 # Vector2i → {"g": MultiMeshInstance3D, "f": MultiMeshInstance3D, "n": [grass, flowers]}
var dirty := {}                 # Vector2i → true: землю поменяли — построить заново
var _job := {}                  # кусок, который строится по кадрам: {key, row, rows, g: [], f: []}
var _mat_g: ShaderMaterial
var _mat_f: ShaderMaterial
var _mesh_g: Mesh
var _mesh_f: Mesh
var _fn := FastNoiseLite.new()  # большие пятна густоты (поляны и заросли)
var _fc := FastNoiseLite.new()  # кочки травы внутри зарослей
var _ff := FastNoiseLite.new()  # цветочные поляны
var _on := true
static var mats: Array = []     # материалы ковра (снимки сверки: MeadowNature.freeze — без качания)


func setup(g) -> void:
	game = g
	land = g.land
	name = "GrassCarpet"
	_fn.seed = 1414
	_fn.frequency = 0.035
	_fn.fractal_octaves = 2
	_fc.seed = 2727
	_fc.frequency = 0.21
	_fc.fractal_octaves = 2
	_ff.seed = 3939
	_ff.frequency = 0.05
	_ff.fractal_octaves = 2
	if not Meadow.has("M:SM_Env_Grass_Med_Clump_01") or not MeadowNature.v2:
		_on = false
		return
	_mesh_g = _clump_mesh("M:SM_Env_Grass_Med_Clump_01@0")
	_mesh_f = _clump_mesh("M:SM_Env_Wildflowers_01@2")
	_mat_g = ShaderMaterial.new()
	_mat_g.shader = preload("res://shaders/grass_carpet.gdshader")
	_mat_g.set_shader_parameter("tex", load(Meadow._tex_path("Grass_Mid_01")))
	_mat_g.set_shader_parameter("root_col", Vector3(ROOT.r, ROOT.g, ROOT.b))
	_mat_g.set_shader_parameter("tip_col", Vector3(TIP.r, TIP.g, TIP.b))
	_mat_f = _mat_g.duplicate() as ShaderMaterial
	_mat_f.set_shader_parameter("flowers", true)
	_mat_f.set_shader_parameter("tex_arr", _flower_array())
	Synty.season_mats.append(_mat_g)          # времена года (Synty.set_season ставит season и им)
	mats = [_mat_g, _mat_f]
	g.city.building_added.connect(func(b): _invalidate_cells(b.get("cells", PackedInt32Array())))
	g.city.building_removed.connect(func(b): _invalidate_cells(b.get("cells", PackedInt32Array())))


## Сетка одного кустика из набора (ступень детализации в имени), материал — свой
func _clump_mesh(nm: String) -> Mesh:
	var src := Meadow.make(nm)
	var out: Mesh = null
	for mi: MeshInstance3D in src.find_children("*", "MeshInstance3D", true, false):
		out = mi.mesh.duplicate() as Mesh
		break
	src.free()
	return out


## Картинки цветов набора — массивом (у каждого кустика цветов своя), 1024² с мипмапами
func _flower_array() -> Texture2DArray:
	var imgs: Array[Image] = []
	for n in ["WildFlowers_01", "WildFlowers_02", "WildFlowers_03"]:
		var t: Texture2D = load(Meadow._tex_path(n))
		var im := t.get_image()
		if im.is_compressed():
			im.decompress()
		im.convert(Image.FORMAT_RGBA8)
		im.resize(1024, 1024, Image.INTERPOLATE_LANCZOS)
		im.generate_mipmaps()
		imgs.append(im)
	var arr := Texture2DArray.new()
	arr.create_from_images(imgs)
	return arr


func set_quality(q: String) -> void:
	var p: Dictionary = Q.get(q, Q["high"])
	var sp := float(p["sp"])
	var rk := range_key(game.settings, q) if game != null else "near"
	var base := float(p["r"])
	if q == "verylow" and rk == "all":
		base = VERYLOW_ALL_R
	radius = base * float(RANGE[rk]) if _on else 0.0
	if rk == "all" and radius > 0.0 and q != "verylow":
		radius = maxf(radius, 150.0)
	if not is_equal_approx(sp, spacing):
		spacing = sp
		for k in tiles:
			dirty[k] = true                   # другая густота — куски заново
	for m: ShaderMaterial in [_mat_g, _mat_f]:
		if m:
			m.set_shader_parameter("fade", Vector2(radius * 0.62, radius))
	visible = radius > 0.0
	if radius <= 0.0:
		for k in tiles.keys():
			_drop(k)


func invalidate_chunk(ch: Vector2i) -> void:
	var k := Vector2i(int(ch.x * Land.CH * Land.CELL / TILE), int(ch.y * Land.CH * Land.CELL / TILE))
	if tiles.has(k) or (not _job.is_empty() and _job["key"] == k):
		dirty[k] = true


## Кистью «Трава» / «Убрать траву» поменяли маску в прямоугольнике — куски под ним строятся заново
func invalidate_rect(a: Vector2, b: Vector2) -> void:
	for j in range(int(minf(a.y, b.y) / TILE), int(maxf(a.y, b.y) / TILE) + 1):
		for i in range(int(minf(a.x, b.x) / TILE), int(maxf(a.x, b.x) / TILE) + 1):
			var k := Vector2i(i, j)
			if tiles.has(k) or (not _job.is_empty() and _job["key"] == k):
				dirty[k] = true


func _invalidate_cells(cells: PackedInt32Array) -> void:
	var seen := {}
	for c in cells:
		var k := Vector2i(int((c % Land.N) * Land.CELL / TILE), int((c / Land.N) * Land.CELL / TILE))
		if not seen.has(k):
			seen[k] = true
			if tiles.has(k) or (not _job.is_empty() and _job["key"] == k):
				dirty[k] = true


func _cam() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam else Vector3(Land.START.x, 50.0, Land.START.y)


func _tile_dist(k: Vector2i, cam: Vector3) -> float:
	var x0 := k.x * TILE
	var z0 := k.y * TILE
	var q := Vector3(clampf(cam.x, x0, x0 + TILE), Land.BASE_Y, clampf(cam.z, z0, z0 + TILE))
	return q.distance_to(cam)


func _process(_dt: float) -> void:
	if radius <= 0.0 or land == null:
		return
	step(BUDGET_MS)


## Куски вокруг камеры: недостающие и поменявшиеся — строить (не дольше ms), дальние — убрать, густота вдали — реже
func step(ms: float) -> bool:
	var cam := _cam()
	var t0 := Time.get_ticks_usec()
	var r := radius
	var near_hole := false
	var c := Vector2i(int(cam.x / TILE), int(cam.z / TILE))
	var n := int(ceil(r / TILE)) + 1
	var want: Array = []
	for j in range(c.y - n, c.y + n + 1):
		for i in range(c.x - n, c.x + n + 1):
			var k := Vector2i(i, j)
			if i < 0 or j < 0 or i * TILE >= Land.SIZE or j * TILE >= Land.SIZE:
				continue
			var d := _tile_dist(k, cam)
			if d < r and (not tiles.has(k) or dirty.has(k)):
				want.append([d, k])
				if d < r * 0.55 and not tiles.has(k):
					near_hole = true          # камеру перенесли: дыра в ковре на виду — строим быстрее
	# дальние — прочь
	for k: Vector2i in tiles.keys():
		var d := _tile_dist(k, cam)
		if d > r + TILE * 0.75:
			_drop(k)
			continue
		# вдали — реже (кустики идут в случайном порядке: видна равномерная часть)
		var e: Dictionary = tiles[k]
		var lod := clampf(1.0 - (d - r * 0.35) / (r * 0.65) * 0.65, 0.35, 1.0)
		for m in ["g", "f"]:
			var mmi: MultiMeshInstance3D = e[m]
			if mmi:
				var vc := int(mmi.multimesh.instance_count * lod)
				if absi(vc - mmi.multimesh.visible_instance_count) > mmi.multimesh.instance_count / 20:
					mmi.multimesh.visible_instance_count = vc   # только когда заметно поменялось (не каждый кадр)
	if want.is_empty() and _job.is_empty():
		return false
	want.sort_custom(func(a, b): return a[0] < b[0])
	if not _job.is_empty():
		var jk: Vector2i = _job["key"]
		if _tile_dist(jk, cam) > r:
			_job = {}                         # камера ушла — этот кусок не нужен
	if near_hole:
		ms = maxf(ms, 10.0)
	while Time.get_ticks_usec() - t0 < ms * 1000.0:
		if _job.is_empty():
			if want.is_empty():
				break
			var k: Vector2i = want.pop_front()[1]
			_job = {"key": k, "row": 0, "rows": int(TILE / spacing), "g": [], "f": []}
			dirty.erase(k)
		_rows(_job, 4)
		if int(_job["row"]) >= int(_job["rows"]):
			_finish(_job)
			_job = {}
	return not want.is_empty() or not _job.is_empty()


## Сразу всё вокруг камеры (загрузка, снимки проверок)
func fill_now() -> void:
	if radius <= 0.0 or land == null:
		return
	for i in 400:
		if not step(50.0):
			break


func _drop(k: Vector2i) -> void:
	var e: Dictionary = tiles[k]
	for m in ["g", "f"]:
		if e[m]:
			(e[m] as Node).queue_free()
	tiles.erase(k)
	dirty.erase(k)


## Несколько рядов точек куска: где растёт трава, где цветы, где камыш
func _rows(job: Dictionary, nrows: int) -> void:
	var k: Vector2i = job["key"]
	var x0 := k.x * TILE
	var z0 := k.y * TILE
	var rows: int = job["rows"]
	var sp := TILE / rows
	var rng := RandomNumberGenerator.new()
	var gl: Array = job["g"]
	var fl: Array = job["f"]
	var N := Land.N
	var r0: int = job["row"]
	for row in range(r0, mini(r0 + nrows, rows)):
		rng.seed = hash(Vector3i(k.x, k.y, row))
		for col in rows:
			var x := x0 + (col + rng.randf()) * sp
			var z := z0 + (row + rng.randf()) * sp
			var ci := int(x / Land.CELL)
			var cj := int(z / Land.CELL)
			if ci < 2 or cj < 2 or ci >= N - 2 or cj >= N - 2:
				continue
			var kk := cj * N + ci
			if land.kind[kk] != Land.Kind.GRASS or land.occ[kk] != 0 or land.wear[kk] > 30 or land.deco[kk] != 0:
				continue
			# у дорог, троп и площадей — чистая кромка (0,5 м)
			if Land.walk_kind(land.kind[kk - 2]) or Land.walk_kind(land.kind[kk + 2]) or Land.walk_kind(land.kind[kk - 2 * N]) or Land.walk_kind(land.kind[kk + 2 * N]):
				continue
			if not land.under.is_empty() and land.under.has(kk):
				continue
			if kk < land.bare.size() and land.bare[kk] != 0:
				continue                          # внутри постройки (двор, комнаты за проёмами) — без травы
			var y := land.surface_y(x, z)
			if y < Land.WATER_Y + 0.04:
				continue
			var gm := land.gm_at(x, z)
			if gm == 2:
				continue                          # «Убрать траву» — здесь пусто
			var nz := _fn.get_noise_2d(x, z)
			var wet := y < Land.WATER_Y + 0.35
			# цветы: редкие одиночные и цветочные поляны (там, где посадил игрок, — чаще)
			var pf := 0.006 + (0.07 if _ff.get_noise_2d(x, z) > 0.3 else 0.0)
			var flower := not wet and rng.randf() < (maxf(pf, 0.035) if gm == 1 else pf)
			if not flower:
				# трава кочками: большие пятна (поляны без травы) × кочки внутри; у воды — гуще и выше (камыш)
				var keep := 0.9
				if gm != 1:
					var dens := clampf((nz + 0.1) * 2.2, 0.0, 1.0)
					keep = dens * (0.1 + 0.9 * smoothstep(-0.1, 0.45, _fc.get_noise_2d(x, z))) * 0.8
				if rng.randf() > keep and not wet:
					continue
			var s := rng.randf_range(0.75, 1.2)
			var sy := s * (rng.randf_range(1.5, 2.1) if wet else rng.randf_range(0.8, 1.15))
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, sy, s))
			var e := [Transform3D(basis, Vector3(x, y - 0.03, z)), Color(rng.randf(), rng.randf(), rng.randf(), 1.0)]
			if flower:
				fl.append(e)
			else:
				gl.append(e)
	job["row"] = mini(r0 + nrows, rows)


func _finish(job: Dictionary) -> void:
	var k: Vector2i = job["key"]
	if tiles.has(k):
		_drop(k)
	var e := {"g": _mm(job["g"], _mesh_g, _mat_g), "f": _mm(job["f"], _mesh_f, _mat_f)}
	tiles[k] = e


func _mm(list: Array, mesh: Mesh, mat: Material) -> MultiMeshInstance3D:
	if list.is_empty() or mesh == null:
		return null
	# случайный порядок — вдали видна равномерная часть (visible_instance_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = list.size()
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t = list[i]
		list[i] = list[j]
		list[j] = t
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = list.size()
	for i in list.size():
		mm.set_instance_transform(i, list[i][0])
		mm.set_instance_custom_data(i, list[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi
