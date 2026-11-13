class_name MeadowNature
extends RefCounted
## Природа из набора Meadow Forest (13.11, владелец: «теперь у нас и мельницы, и цветочки, и земля, и деревья, и
## водичка, и дороги»): какие деревья, кусты, цветы и камни встают в рощах и на лугах (pick — вместо части прежних
## Synty Ancient Empire), богатая мелочь лугов, поля рапса, подсолнухов и пшеницы с каменными оградами на дальних
## окраинах, жизнь у ручьёв (камыш, камни, кувшинки, родник), мосты, мельницы и водяное колесо. Всё — те же
## «природные» детали (game._add_nature): их можно снести и перенести, под постройкой они убираются; природа
## не сохраняется — растёт заново при загрузке (как прежде).
##
## Скорость (владелец: «≥120 кадров даже на старых ПК»): богатая мелочь (трава, цветы, поля, ограды) видна только на
## «Средней» и «Высокой»; деревья набора (листва — тысячи карточек) на «Низкой» и «Очень низкой» рисуются прежними
## лёгкими деревьями Synty того же роста (подмена сетки в тех же MultiMesh — места и ручки природы не меняются).

const SEED := 1313

## Рост моделей набора (верх, м при масштабе 1) — масштаб подбирается под нужную высоту
const TOP := {"SM_Env_Tree_Meadow_01": 12.8, "SM_Env_Tree_Meadow_02": 7.5, "SM_Env_Tree_Birch_01": 9.2, "SM_Env_Tree_Birch_02": 8.5,
	"SM_Env_Tree_Birch_03": 4.6, "SM_Env_Tree_Fruit_01": 5.1, "SM_Env_Tree_Fruit_02": 4.7, "SM_Env_Tree_Fruit_03": 3.9,
	"SM_Env_Bush_01": 2.8, "SM_Env_Bush_02": 1.8, "SM_Env_Bush_03": 3.1}
## Прежнее дерево того же облика — для «Низкой» и «Очень низкой» (Synty Ancient Empire)
const STANDIN := {"SM_Env_Tree_Meadow_01": "SM_Env_Tree_01", "SM_Env_Tree_Meadow_02": "SM_Env_Tree_03", "SM_Env_Tree_Birch_01": "SM_Env_Tree_02",
	"SM_Env_Tree_Birch_02": "SM_Env_Tree_02", "SM_Env_Tree_Birch_03": "SM_Env_Tree_04", "SM_Env_Tree_Fruit_01": "SM_Env_Tree_04",
	"SM_Env_Tree_Fruit_02": "SM_Env_Tree_04", "SM_Env_Tree_Fruit_03": "SM_Env_Tree_Bush_01", "SM_Env_Bush_01": "SM_Env_Tree_Bush_01",
	"SM_Env_Bush_02": "SM_Env_Tree_Bush_02", "SM_Env_Bush_03": "SM_Env_Tree_Bush_03"}

static var low := false                     # сейчас «Низкая» или «Очень низкая» (Gfx.apply → game.meadow_quality)
## Природа выросла на «Низкой» или «Очень низкой» (загрузка): рощи и луга — прежние Synty, без мелочи набора — та же
## картинка и та же скорость, что до набора. Уровень сменили в игре на высокий — природа набора вырастет со следующей
## загрузки; сменили на низкий — деревья набора подменяются прежними, мелочь прячется (quality)
static var gen_low := false
static var _standin := {}


static func on() -> bool:
	return Meadow.has("M:SM_Env_Tree_Birch_01")


static func _tree_xf(name: String, h: float, rng: RandomNumberGenerator) -> float:
	return h / float(TOP.get(name.trim_prefix("M:").split("@")[0], 5.0)) * rng.randf_range(0.9, 1.1)


## Что встанет вместо прежней детали природы (часть рощ и лугов — из набора Meadow): [имя, масштаб, remap]
static func pick(rng: RandomNumberGenerator, name: String, s: float) -> Array:
	if not on() or gen_low:
		return [name, s, {}]
	var m := rng.randf()
	if name.begins_with("SM_Env_Tree_0"):
		if m < 0.2:
			var nm := "M:SM_Env_Tree_Meadow_0%d" % (1 + rng.randi() % 2)
			return [nm, _tree_xf(nm, rng.randf_range(4.6, 6.6), rng), {}]
		if m < 0.36:
			var nm2 := "M:SM_Env_Tree_Birch_0%d" % (1 + rng.randi() % 3)
			return [nm2, _tree_xf(nm2, rng.randf_range(4.8, 6.8) if not nm2.ends_with("3") else rng.randf_range(3.6, 4.6), rng), {}]
		if m < 0.44:
			var nm3 := "M:SM_Env_Tree_Fruit_0%d" % (1 + rng.randi() % 3)
			return [nm3, _tree_xf(nm3, rng.randf_range(3.6, 4.8), rng), {"bloom": 1}]
	elif name.begins_with("SM_Env_Bush_Cluster") or name.begins_with("SM_Env_Tree_Bush"):
		if m < 0.5:
			var nb := "M:SM_Env_Bush_0%d" % (1 + rng.randi() % 3)
			return [nb, _tree_xf(nb, rng.randf_range(1.3, 2.2), rng), {}]
	elif name.begins_with("SM_Env_Flowers"):
		if m < 0.55:
			if rng.randf() < 0.7:
				return ["M:SM_Env_Wildflowers_0%d" % (1 + rng.randi() % 3), rng.randf_range(0.8, 1.3), {}]
			return ["M:SM_Env_Flowers_Flat_0%d" % (1 + rng.randi() % 3), rng.randf_range(0.5, 0.8), {}]
	elif name.begins_with("SM_Env_Grass"):
		if m < 0.55:
			var t := rng.randf()
			if t < 0.4:
				return ["M:SM_Env_Grass_Short_Clump_0%d" % (1 + rng.randi() % 3), rng.randf_range(0.8, 1.3), {}]
			if t < 0.75:
				return ["M:SM_Env_Grass_Med_Clump_0%d" % (1 + rng.randi() % 3), rng.randf_range(0.8, 1.2), {}]
			return ["M:SM_Env_Grass_Tall_Clump_0%d" % (1 + rng.randi() % 5), rng.randf_range(0.6, 0.95), {}]
	elif name.begins_with("SM_Env_Rock_Cliff"):
		if m < 0.75:
			var t2 := rng.randf()
			if t2 < 0.55:
				return ["M:SM_Env_Rock_0%d" % (1 + rng.randi() % 6), rng.randf_range(0.18, 0.42), {}]
			if t2 < 0.8:
				return ["M:SM_Env_Rock_Small_Pile_0%d" % (1 + rng.randi() % 2), rng.randf_range(0.8, 1.3), {}]
			return ["M:SM_Env_Rock_Round_01", rng.randf_range(0.2, 0.4), {}]
	return [name, s, {}]


## Богатая мелочь лугов (только «Средняя» и «Высокая»): кочки травы, кустики, полевые цветы, клевер — [имя, масштаб] или []
static func extra(rng: RandomNumberGenerator, forest: float) -> Array:
	if not on() or gen_low:
		return []
	var t := rng.randf()
	if forest > 0.15:
		# у опушек: папоротник-кустики травы, листва на земле
		if t < 0.5:
			return ["M:SM_Env_Ground_Cover_0%d" % (1 + rng.randi() % 3), rng.randf_range(0.6, 1.0)]
		return ["M:SM_Env_Grass_Bush_01", rng.randf_range(0.5, 0.8)]
	if t < 0.45:
		return ["M:SM_Env_Grass_Tall_Clump_0%d" % (1 + rng.randi() % 5), rng.randf_range(0.6, 1.0)]
	if t < 0.8:
		return ["M:SM_Env_Wildflowers_0%d" % (1 + rng.randi() % 3), rng.randf_range(0.8, 1.3)]
	return ["M:SM_Env_Flowers_Flat_0%d" % (1 + rng.randi() % 3), rng.randf_range(0.5, 0.8)]


## Земля и дороги из набора (shaders/land.gdshader, meadow_on): трава с клевером, цветами и мхом, мостовая из булыжника,
## тропы — утоптанная земля, кромки и дворики — гравий, берега — земля
static func ground(g) -> void:
	if not on():
		return
	var m: ShaderMaterial = g.land_mat
	var t := func(n: String) -> Texture2D: return load(Meadow._tex_path(n))
	m.set_shader_parameter("g_tex_a", t.call("Grass_Texture_01"))
	m.set_shader_parameter("g_tex_b", t.call("Grass_Texture_02"))
	m.set_shader_parameter("g_clover", t.call("Grass_Clovers_Texture_01"))
	m.set_shader_parameter("g_flower", t.call("Grass_Flowers_Texture_01"))
	m.set_shader_parameter("g_moss", t.call("Moss_Texture_01"))
	m.set_shader_parameter("path_tex", t.call("Dirt_Cracked_Pebbles_Texture_01"))
	m.set_shader_parameter("gravel_tex", t.call("Gravel_Texture_01"))
	m.set_shader_parameter("earth_tex", t.call("Dirt_Texture_01"))
	m.set_shader_parameter("tile_road", t.call("Cobblestone_Texture_01"))
	m.set_shader_parameter("road_scale", 3.2)
	m.set_shader_parameter("meadow_on", true)


## Ложбины ручьёв по исходной карте — в фоне, пока грузится город (≈0,5–1 с счёта не задерживают загрузку). Читает
## только исходную карту (base_h, base_kind) — её до прокладки ручьёв никто не меняет
static var _task := -1
static func prepare(land: Land) -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
	_task = WorkerThreadPool.add_task(func() -> void:
		for id: int in Streams.ids():
			Streams.cells(land, id))


## Ручьи — после того как город построен или загружен (scripts/streams.gd)
static func streams(g) -> void:
	gen_low = Gfx.is_low(str(g.settings.get("quality", "high")))
	var t0 := Time.get_ticks_msec()
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	var list := Streams.choose(g.land, g.land.streams_saved)
	Streams.apply(g.land, list)
	print("Streams: ", list, " за ", Time.get_ticks_msec() - t0, " мс")


## Всё, что встаёт после рощ и лугов: жизнь у ручьёв, мосты, поля с оградами, мельницы, луга в цветах
static func life(g) -> void:
	if not on():
		_bridges(g)
		return
	_stream_banks(g)
	_flow(g)
	_bridges(g)
	if not gen_low:
		_patches(g)
		_fields(g)


static func _near_road(g, p: Vector2, r: float) -> bool:
	for o: Vector2 in [Vector2.ZERO, Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r), Vector2(r, r) * 0.7, Vector2(-r, r) * 0.7, Vector2(r, -r) * 0.7, Vector2(-r, -r) * 0.7]:
		var q: Vector2 = p + o
		if q.x > 0.0 and q.y > 0.0 and q.x < Land.SIZE and q.y < Land.SIZE and Land.walk_kind(g.land.kind_at(q.x, q.y)):
			return true
	return false


static func _free_spot(g, p: Vector2) -> bool:
	var land: Land = g.land
	if p.x < 1.0 or p.y < 1.0 or p.x > Land.SIZE - 1.0 or p.y > Land.SIZE - 1.0:
		return false
	var c := land.cell(p)
	var k := land.idx(c.x, c.y)
	return land.kind[k] == Land.Kind.GRASS and land.occ[k] == 0 and not land.under.has(k)


## У ручьёв: камыш и высокая трава по берегам, камни (и в воде), кувшинки в широких местах и в заводи, цветы на
## склонах ложбины, у родника — груда камней
static func _stream_banks(g) -> void:
	var land: Land = g.land
	for id: int in land.streams:
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + id * 31
		for s: Dictionary in Streams.samples(id, 1.1):
			var p: Vector2 = s["p"]
			var w: float = s["w"]
			var dir: Vector2 = s["dir"]
			var nor := Vector2(-dir.y, dir.x)
			var t: float = s["t"]
			if t < 0.04 and rng.randf() < 0.5:
				var q0 := p + Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0))
				if _free_spot(g, q0) and not land.is_water(q0):
					_add(g, "M:SM_Env_Rock_0%d" % (1 + rng.randi() % 6), q0, rng.randf_range(0.15, 0.3), rng, -0.08)
			for side: float in [-1.0, 1.0]:
				if rng.randf() < 0.3:
					var q := p + nor * side * (w + rng.randf_range(0.0, 0.6))
					if _free_spot(g, q) and not gen_low:
						var y := land.height_at(q.x, q.y)
						g._add_nature("M:SM_Env_Grass_Tall_Clump_0%d" % (1 + rng.randi() % 5), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.45, 0.75)),
							Vector3(q.x, maxf(y, Land.WATER_Y - 0.12), q.y)), q)
				if rng.randf() < 0.22:
					var q2 := p + nor * side * (w + rng.randf_range(1.2, 4.5))
					if _free_spot(g, q2) and not land.is_water(q2) and not gen_low:
						_add(g, "M:SM_Env_Wildflowers_0%d" % (1 + rng.randi() % 3), q2, rng.randf_range(0.8, 1.2), rng)
			if rng.randf() < 0.14:
				var q3 := p + nor * rng.randf_range(-1.3, 1.3) * w
				if _free_spot(g, q3):
					var yr := land.height_at(q3.x, q3.y)
					var small := rng.randf() < 0.65
					var rn := "M:SM_Env_Rock_Small_01" if small else "M:SM_Env_Rock_0%d" % (1 + rng.randi() % 6)
					var rs := rng.randf_range(0.8, 1.6) if small else rng.randf_range(0.12, 0.22)    # камешки ~0,3–0,5 м, валуны ~0,3–0,6 м
					g._add_nature(rn, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rs), Vector3(q3.x, yr - 0.06, q3.y)), q3)
			if w > 1.1 and t > 0.15 and rng.randf() < 0.1:
				var q4 := p + nor * rng.randf_range(-0.4, 0.4) * w
				if land.is_water(q4):
					g._add_nature("M:SM_Env_Lillies_0%d" % (1 + rng.randi() % 3), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.3, 0.5)),
						Vector3(q4.x, Land.WATER_Y + 0.012, q4.y)), q4)
		var pl: Vector3 = Streams.plan(id)["pool"]
		if pl.z > 0.0:
			for k in int(pl.z * 1.2):
				var a := rng.randf() * TAU
				var q5 := Vector2(pl.x, pl.y) + Vector2(cos(a), sin(a)) * pl.z * rng.randf_range(0.15, 0.65)
				if land.is_water(q5):
					g._add_nature("M:SM_Env_Lillies_0%d" % (1 + rng.randi() % 3), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.35, 0.6)),
						Vector3(q5.x, Land.WATER_Y + 0.012, q5.y)), q5)
		# водяное колесо у южного ручья (римляне ставили водяные мельницы) — на новых картах
		if id == 2 and land.meadow_new:
			_waterwheel(g, id)


## Течение: полоса над водой каждого ручья (светлые струйки бегут вниз по течению). Одна сетка на все ручьи, без теней;
## на «Низкой» и «Очень низкой» спрятана (quality)
static var flow_node: MeshInstance3D = null
static func _flow(g) -> void:
	var land: Land = g.land
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for id: int in land.streams:
		var p := Streams.plan(id)
		var pts: PackedVector2Array = p["pts"]
		var wid: PackedFloat32Array = p["w"]
		var acc := 0.0
		for i in range(1, pts.size()):
			var a := pts[i - 1]
			var b := pts[i]
			var da := (pts[mini(i, pts.size() - 1)] - pts[maxi(i - 2, 0)]).normalized()
			var db := (pts[mini(i + 1, pts.size() - 1)] - pts[i - 1]).normalized()
			var na := Vector2(-da.y, da.x) * wid[i - 1] * 0.9
			var nb := Vector2(-db.y, db.x) * wid[i] * 0.9
			var l := a.distance_to(b)
			var y := Land.WATER_Y + 0.02
			var v := [Vector3(a.x - na.x, y, a.y - na.y), Vector3(a.x + na.x, y, a.y + na.y), Vector3(b.x + nb.x, y, b.y + nb.y), Vector3(b.x - nb.x, y, b.y - nb.y)]
			var uv := [Vector2(0, acc), Vector2(1, acc), Vector2(1, acc + l), Vector2(0, acc + l)]
			for k: int in [0, 1, 2, 0, 2, 3]:
				st.set_uv(uv[k])
				st.set_normal(Vector3.UP)
				st.add_vertex(v[k])
			acc += l
			any = true
	if not any:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/stream_flow.gdshader")
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = not low
	g.add_child(mi)
	flow_node = mi


static func _add(g, name: String, q: Vector2, s: float, rng: RandomNumberGenerator, dy := 0.0) -> void:
	var y: float = g.land.height_at(q.x, q.y)
	g._add_nature(name, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(q.x, y + dy, q.y)), q)


static func _waterwheel(g, id: int) -> void:
	var land: Land = g.land
	var ss := Streams.samples(id, 1.0)
	var s: Dictionary = ss[int(ss.size() * 0.55)]
	var p: Vector2 = s["p"]
	var dir: Vector2 = s["dir"]
	var nor := Vector2(-dir.y, dir.x)
	var w: float = s["w"]
	var q := p + nor * (w + 0.35)
	if not _free_spot(g, q):
		return
	# опора — на берегу, колесо — в воде, ось — поперёк ручья (проверено на снимке: .work/nature/sheets/countryside.jpg)
	var yaw := atan2(nor.x, nor.y) + PI * 0.5
	var y := land.height_at(q.x, q.y)
	g._add_nature("M:SM_Prop_WaterWheel_01", Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * 0.62), Vector3(q.x, y - 0.25, q.y)), q)


## Мост там, где ручей проходит под большой дорогой: дорога остаётся насыпью, по бокам — каменные стенки с аркой
## над водой, поверху — парапеты. Мост не сносится (как арка въезда)
static func _bridges(g) -> void:
	var land: Land = g.land
	for br: Dictionary in land.bridges:
		var c: Vector2 = br["pos"]
		var sd: Vector2 = br["dir"]                    # куда течёт ручей
		var rd := Vector2(-sd.y, sd.x)                 # вдоль дороги
		var y: float = br["y"]
		var w: float = br["w"]
		var hw := Land.ROAD_R
		var depth := y - (Land.WATER_Y - 0.1)
		var half := clampf(w + Streams.SHORE + (y - Land.WATER_Y - 0.25) / Streams.SLOPE, 3.0, 8.5)
		var bp := Bp.new(91)
		var yaw := atan2(rd.x, rd.y)                    # местная +Z — вдоль дороги, +X — вниз по ручью
		var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, y, c.y))
		var stone := CatGrand.TRAV
		var ws := w * 2.0 + 0.6                         # пролёт арки
		for side: float in [-1.0, 1.0]:
			var x := side * (hw + 0.12)
			# стенка с аркой над водой: арка — кусок стены с двойной дверью Synty (как у акведука), по краям — сплошная
			var sc := Basis.from_scale(Vector3(ws / Bp.M, depth / 3.01, 0.6))
			var face_yaw := 0.0 if side > 0.0 else PI
			bp.parts.append(["SM_Bld_Wall_Door_Double_01", Transform3D(Basis(Vector3.UP, face_yaw + PI * 0.5) * sc,
				Vector3(x, -depth, side * ws * 0.5)), stone])
			for e: float in [-1.0, 1.0]:
				var l := half - ws * 0.5
				if l < 0.2:
					continue
				var zc := e * (ws * 0.5 + l * 0.5)
				CatMonuments._box(bp, "#marble", Vector3(x, -depth * 0.5, zc), Vector3(0.5, depth, l))
			# парапет и столбики по краю
			CatMonuments._box(bp, "#marble", Vector3(side * (hw + 0.18), 0.28, 0.0), Vector3(0.32, 0.56, half * 2.0))
			CatMonuments._box(bp, "#marble", Vector3(side * (hw + 0.18), 0.6, 0.0), Vector3(0.42, 0.1, half * 2.0 + 0.1))
			for e2: float in [-1.0, 1.0]:
				CatMonuments._box(bp, "#marble", Vector3(side * (hw + 0.18), 0.4, e2 * half), Vector3(0.5, 0.8, 0.5))
		g.parts.place(bp, xf)
		# под аркой — вода дальше (короткая полоса воды в насыпь) и тёплый камень свода, а не чёрная дыра
		var under := Bp.new(92)
		for side2: float in [-1.0, 1.0]:
			CatMonuments._box(under, "#water", Vector3(side2 * (hw - 0.2), Land.WATER_Y - y + 0.02, 0.0), Vector3(0.9, 0.04, ws - 0.2))
		g.parts.place(under, xf)


## Луга в цветах: куртины полевых цветов и плоских цветочков (по 6–14 в круге 3–5 м) там, где нет рощ, вдали от города
static func _patches(g) -> void:
	var land: Land = g.land
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 7
	var fn := FastNoiseLite.new()
	fn.seed = 77
	fn.frequency = 0.02
	for n in 420:
		var p := Vector2(rng.randf_range(10.0, Land.SIZE - 10.0), rng.randf_range(10.0, Land.SIZE - 10.0))
		var cnt := 6 + rng.randi() % 9
		var r := rng.randf_range(3.0, 5.0)
		var tone := rng.randi() % 3
		if fn.get_noise_2d(p.x, p.y) > 0.15:
			continue
		var ds := maxf(absf(p.x - Land.START.x) - 40.0, absf(p.y - Land.START.y) - 40.0)
		if ds < 0.0:
			continue
		for k in cnt:
			var q := p + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * r
			if not _free_spot(g, q) or land.is_water(q) or _near_road(g, q, 2.0):
				continue
			var nm := ("M:SM_Env_Wildflowers_0%d" % (1 + (tone + rng.randi() % 2) % 3)) if rng.randf() < 0.7 else ("M:SM_Env_Flowers_Flat_0%d" % (1 + rng.randi() % 3))
			_add(g, nm, q, rng.randf_range(0.9, 1.5) if nm.contains("Wild") else rng.randf_range(0.5, 0.8), rng)


## Поля на дальних окраинах: рапс, подсолнухи, пшеница рядами, по краю — каменная ограда, на углу груда камней;
## у части полей на новых картах — мельница
static func _fields(g) -> void:
	var land: Land = g.land
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 11
	var placed := []
	var mills := 0
	for n in 120:
		if placed.size() >= 12:
			break
		var p := Vector2(rng.randf_range(24.0, Land.SIZE - 24.0), rng.randf_range(24.0, Land.SIZE - 24.0))
		var ds := maxf(absf(p.x - Land.START.x) - 40.0, absf(p.y - Land.START.y) - 40.0)
		var kind := rng.randi() % 3                    # 0, 1 — жёлтое поле (горчица, рапс), 2 — подсолнухи
		var W := rng.randf_range(12.0, 20.0) if kind != 2 else rng.randf_range(7.0, 10.0)
		var D := rng.randf_range(8.0, 13.0) if kind != 2 else rng.randf_range(5.0, 7.0)
		var yaw := (rng.randi() % 4) * PI * 0.5 + rng.randf_range(-0.12, 0.12)
		if ds < 60.0 or land.is_owned(p):
			continue
		var far := false
		for o: Vector2 in placed:
			if o.distance_to(p) < 34.0:
				far = true
		if far:
			continue
		var ax := Vector2(cos(yaw), -sin(yaw))
		var az := Vector2(sin(yaw), cos(yaw))
		var ok := true
		var y0: float = land.height_at(p.x, p.y)
		for fx: float in [-0.5, 0.0, 0.5]:
			for fz: float in [-0.5, 0.0, 0.5]:
				var q := p + ax * fx * (W + 2.0) + az * fz * (D + 2.0)
				if not _free_spot(g, q) or land.is_water(q) or _near_road(g, q, 3.0) or absf(land.height_at(q.x, q.y) - y0) > 1.6:
					ok = false
		if not ok:
			continue
		placed.append(p)
		g.clear_nature(p, Vector2(W, D).length() * 0.5 + 1.0)   # рощи и кусты, выросшие на месте поля, — прочь
		var step := 1.5 if kind != 2 else 1.05
		var nx := int(W / step)
		var nz := int(D / step)
		for iz in nz:
			for ix in nx:
				var q := p + ax * ((ix + 0.5) * step - W * 0.5 + rng.randf_range(-0.15, 0.15)) + az * ((iz + 0.5) * step - D * 0.5 + rng.randf_range(-0.1, 0.1))
				if not _free_spot(g, q):
					continue
				var yy: float = land.height_at(q.x, q.y)
				var nm := ""
				var s := 1.0
				match kind:
					0, 1:
						# рапс набора без своей картинки (в файлах её нет) — жёлтое поле из «CropField»
						nm = "M:SM_Env_CropField_Clump_0%d" % (1 + rng.randi() % 2)
						s = rng.randf_range(0.75, 0.9)
					_:
						nm = "M:SM_Env_Sunflower_01"
						s = rng.randf_range(0.85, 1.05)
				g._add_nature(nm, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(q.x, yy, q.y)), q)
		# каменная ограда по длинному краю (куски по 5,3 м) и груда камней на углу
		var edge := az * (D * 0.5 + 0.9)
		var segs := int(W / 5.0)
		for i in segs:
			var q2 := p + edge + ax * ((i + 0.5) * (W / segs) - W * 0.5)
			if _free_spot(g, q2) and not land.is_water(q2):
				var y2: float = land.height_at(q2.x, q2.y)
				g._add_nature("M:SM_Prop_Stonewall_Long_01", Transform3D(Basis(Vector3.UP, yaw + rng.randf_range(-0.05, 0.05)).scaled(Vector3(W / segs / 5.3, 0.8, 0.8)),
					Vector3(q2.x, y2 - 0.05, q2.y)), q2)
		var corner := p - ax * (W * 0.5 + 1.2) - az * (D * 0.5 + 0.6)
		if _free_spot(g, corner):
			_add(g, "M:SM_Env_Rock_Small_Pile_0%d" % (1 + rng.randi() % 2), corner, rng.randf_range(1.2, 1.8), rng)
		# мельница у поля пшеницы или рапса — только на новых картах, не больше двух
		if land.meadow_new and kind != 2 and mills < 2:
			var mp := p + ax * (W * 0.5 + 5.0)
			var mok := true
			for o2: Vector2 in [Vector2.ZERO, Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3)]:
				if not _free_spot(g, mp + o2) or land.is_water(mp + o2) or _near_road(g, mp + o2, 3.0):
					mok = false
			if mok:
				mills += 1
				g.clear_nature(mp, 4.0)
				var ym: float = land.height_at(mp.x, mp.y)
				g._add_nature("M:SM_Bld_Windmill_0%d" % (1 + mills % 2), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * 0.72),
					Vector3(mp.x, ym, mp.y)), mp)


# ---------- качество ----------

## Уровень графики поменялся (Gfx.apply): богатая мелочь — только «Средняя» и «Высокая»; деревья набора на «Низкой»
## и «Очень низкой» — прежними лёгкими деревьями того же роста
static func quality(g, is_low: bool) -> void:
	low = is_low
	if g.parts == null:
		return
	for grp: Dictionary in g.parts.groups.values():
		if String(grp.get("key", "")).begins_with("M:"):
			apply_group(grp)
	if g.land_mat:
		g.land_mat.set_shader_parameter("rich", not is_low)
	if is_instance_valid(flow_node):
		flow_node.visible = not is_low


## Группа пула (одна модель на кусок 48 м) — по нынешнему уровню
static func apply_group(grp: Dictionary) -> void:
	if int(grp.get("mq", -1)) == int(low):
		return
	grp["mq"] = int(low)
	var name := String(grp["key"]).split("|")[0]
	var subs: Array = grp["subs"]
	if Meadow.rich(name):
		for sub: Dictionary in subs:
			(sub["mmi"] as MultiMeshInstance3D).visible = not low
		return
	var base := name.trim_prefix("M:").split("@")[0]
	if not STANDIN.has(base) or subs.is_empty():
		return
	# главная часть (самая большая) — подменяется прежним деревом, остальные (ветки) прячутся
	var main := int(grp.get("main", -1))
	if main < 0:
		var best := -1.0
		for i in subs.size():
			var sz := ((subs[i] as Dictionary)["mm"] as MultiMesh).mesh.get_aabb().size
			if sz.length() > best:
				best = sz.length()
				main = i
		grp["main"] = main
	for i in subs.size():
		var sub: Dictionary = subs[i]
		var mm: MultiMesh = sub["mm"]
		if i == main:
			if not sub.has("hi"):
				sub["hi"] = mm.mesh
			mm.mesh = _standin_mesh(base, sub) if low else sub["hi"]
		else:
			(sub["mmi"] as MultiMeshInstance3D).visible = not low


## Прежнее дерево Synty, запечённое в сетку под рост дерева набора (в тех же осях, что главная часть его модели)
static func _standin_mesh(base: String, sub: Dictionary) -> Mesh:
	if _standin.has(base):
		return _standin[base]
	var hi: Mesh = sub["hi"]
	var local: Transform3D = sub["local"]
	var top := (local * hi.get_aabb()).end.y
	var src := Synty.make(STANDIN[base], {"tint": Synty.GREEN})
	var items := []
	var stop := 0.01
	for mi: MeshInstance3D in src.find_children("*", "MeshInstance3D", true, false):
		var rel := Citizen._rel(mi, src)
		stop = maxf(stop, (rel * mi.mesh.get_aabb()).end.y)
		items.append([mi, rel])
	var k := top / stop
	var am := ArrayMesh.new()
	for it: Array in items:
		var mi: MeshInstance3D = it[0]
		var xf: Transform3D = local.affine_inverse() * Transform3D(Basis.from_scale(Vector3.ONE * k), Vector3.ZERO) * (it[1] as Transform3D)
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			for i in vs.size():
				vs[i] = xf * vs[i]
			for i in ns.size():
				ns[i] = (xf.basis * ns[i]).normalized()
			arr[Mesh.ARRAY_VERTEX] = vs
			if not ns.is_empty():
				arr[Mesh.ARRAY_NORMAL] = ns
			arr[Mesh.ARRAY_TANGENT] = null
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var m := mi.get_surface_override_material(s)
			if m == null:
				m = mi.mesh.surface_get_material(s)
			am.surface_set_material(am.get_surface_count() - 1, m)
	src.free()
	_standin[base] = am
	return am


## Снимки для сверки (test_perf: время стоит): качание листвы, крылья мельниц и течение ручьёв — замерли
static func freeze(on_: bool) -> void:
	for k in Meadow._mats:
		var m = Meadow._mats[k]
		if m is ShaderMaterial:
			var sm := m as ShaderMaterial
			if not sm.has_meta("sway0"):
				sm.set_meta("sway0", sm.get_shader_parameter("sway"))
				sm.set_meta("speed0", sm.get_shader_parameter("speed"))
			if sm.get_meta("sway0") != null:
				sm.set_shader_parameter("sway", 0.0 if on_ else sm.get_meta("sway0"))
			if sm.get_meta("speed0") != null:
				sm.set_shader_parameter("speed", 0.0 if on_ else sm.get_meta("speed0"))
	if is_instance_valid(flow_node):
		flow_node.visible = not on_ and not low
