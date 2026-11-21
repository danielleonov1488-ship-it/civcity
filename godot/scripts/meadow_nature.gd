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
## Природа 2 (14.11, владелец: «природа у нас отстой… как в паке Synty»): плавная земля (Land.smooth_on), трава-ковёр
## (GrassCarpet), в рощах и на лугах — в основном деревья и кусты набора, листва и трава сочнее. CIVCITY_NATURE2=0 —
## как было (сравнения «было/стало» в одной сборке)
static var v2 := OS.get_environment("CIVCITY_NATURE2") != "0"
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
	if v2 and (name.begins_with("SM_Env_Tree_0") or name.begins_with("SM_Env_Tree_Large")):
		# природа 2: почти все рощи — деревья набора (раскидистые луговые, берёзы, фруктовые), прежние оливы — для
		# римского вида (примерно каждое пятое); кипарисы (Thin) — как были
		if m < 0.36:
			var nmv := "M:SM_Env_Tree_Meadow_0%d" % (1 + rng.randi() % 2)
			return [nmv, _tree_xf(nmv, rng.randf_range(4.8, 7.2) if name.contains("Large") else rng.randf_range(4.4, 6.4), rng), {}]
		if m < 0.58:
			var nmb := "M:SM_Env_Tree_Birch_0%d" % (1 + rng.randi() % 3)
			return [nmb, _tree_xf(nmb, rng.randf_range(4.8, 6.8) if not nmb.ends_with("3") else rng.randf_range(3.6, 4.6), rng), {}]
		if m < 0.8:
			var nmf := "M:SM_Env_Tree_Fruit_0%d" % (1 + rng.randi() % 3)
			return [nmf, _tree_xf(nmf, rng.randf_range(3.6, 4.8), rng), {"bloom": 1}]
		return [name, s, {}]
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
		if m < (0.82 if v2 else 0.5):
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
		# камни набора — больше круглых и груд мелких; угловатые (сверху похожи на ящики) — реже и меньше
		if m < 0.6:
			var t2 := rng.randf()
			if t2 < 0.4:
				return ["M:SM_Env_Rock_Round_01", rng.randf_range(0.14, 0.3), {}]
			if t2 < 0.8:
				return ["M:SM_Env_Rock_Small_Pile_0%d" % (1 + rng.randi() % 2), rng.randf_range(0.8, 1.2), {}]
			return ["M:SM_Env_Rock_0%d" % [1, 2, 5][rng.randi() % 3], rng.randf_range(0.12, 0.22), {}]
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
	m.set_shader_parameter("road_tint", Vector3(1.12, 1.03, 0.88))
	m.set_shader_parameter("noise_tex", noise_tex())
	m.set_shader_parameter("meadow_on", true)
	if v2:
		# природа 2: земля под травой — сочная жёлто-зелёная (в тон траве-ковру: вдали, где ковра нет, — тот же цвет)
		m.set_shader_parameter("pal0", Vector3(0.12, 0.2, 0.028))
		m.set_shader_parameter("pal1", Vector3(0.16, 0.25, 0.034))
		m.set_shader_parameter("pal2", Vector3(0.2, 0.3, 0.042))
		m.set_shader_parameter("pal3", Vector3(0.26, 0.34, 0.05))


## Плавный шум для пятен травы (shaders/land.gdshader noise_tex): 4 бесшовных симплекс-шума (разные семена) в каналах
## RGBA, 256², с мипмапами; один раз за запуск (~десятки мс)
static var _noise: ImageTexture = null
static func noise_tex() -> ImageTexture:
	if _noise != null:
		return _noise
	var S := 256
	var chans := []
	for i in 4:
		var fn := FastNoiseLite.new()
		fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		fn.seed = 501 + i * 17
		fn.frequency = 0.012
		fn.fractal_octaves = 3
		chans.append(fn.get_seamless_image(S, S, false, false, 0.1, true).get_data())
	var c0: PackedByteArray = chans[0]       # Packed* внутри Array копируются при каждом обращении — берём один раз
	var c1: PackedByteArray = chans[1]
	var c2: PackedByteArray = chans[2]
	var c3: PackedByteArray = chans[3]
	var data := PackedByteArray()
	data.resize(S * S * 4)
	for k in S * S:
		data[k * 4] = c0[k]
		data[k * 4 + 1] = c1[k]
		data[k * 4 + 2] = c2[k]
		data[k * 4 + 3] = c3[k]
	var img := Image.create_from_data(S, S, false, Image.FORMAT_RGBA8, data)
	img.generate_mipmaps()
	_noise = ImageTexture.create_from_image(img)
	return _noise


## Своя и чужая земля для травы (shaders/land.gdshader own_tex): точка на участок, белое — чужая; при загрузке
## и после покупки участка (game._update_plot_signs)
static var _own_img: Image = null
static var _own_tex: ImageTexture = null
static func plots_tex(g) -> void:
	if not on() or g.land_mat == null or g.land == null:
		return
	var n := Land.PLOTS                       # точка на участок: с плавной выборкой граница — мягкий переход через участок, без углов
	if _own_img == null or _own_img.get_width() != n:
		_own_img = Image.create(n, n, false, Image.FORMAT_L8)
		_own_tex = null
	for j in n:
		for i in n:
			var own: bool = g.land.owned.has(Vector2i(i, j))
			_own_img.set_pixel(i, j, Color(0, 0, 0) if own else Color(1, 1, 1))
	if _own_tex == null:
		_own_tex = ImageTexture.create_from_image(_own_img)
	else:
		_own_tex.update(_own_img)
	g.land_mat.set_shader_parameter("own_tex", _own_tex)
	g.land_mat.set_shader_parameter("own_on", true)


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
	Streams.set_far(g.land.streams)           # река — за край карты, в долину пейзажа до горизонта (Game._horizon)
	print("Streams: ", list, " за ", Time.get_ticks_msec() - t0, " мс")


## Всё, что встаёт после рощ и лугов: жизнь у ручьёв, мосты, поля с оградами, мельницы, луга в цветах
static func life(g) -> void:
	_water_life(g)
	if not on():
		_bridges(g)
		return
	_stream_banks(g)
	_flow(g)
	_bridges(g)
	if not gen_low:
		_patches(g)
		_fields(g)


## Жизнь на воде реки (15.11): на озере — лодка с рыбаком (только в «уютных» городах, как на прудах), утки и лебедь
## кружат; на реке — утки в широких спокойных местах (кружат на месте, как на прудах)
static func _water_life(g) -> void:
	var land: Land = g.land
	for id: int in Streams.RIVER_IDS:
		if not land.streams.has(id):
			continue
		var p := Streams.plan(id)
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + 500 + id
		var pl: Vector3 = p["pool"]
		var bn: Node = g.get_node_or_null("Boats")
		if pl.z > 0.0:
			var c := Vector2(pl.x, pl.y)
			if bn != null and bn.has_method("add_lake"):
				bn.add_lake(pl)
			for k in 4:
				var nm := "#swan" if k == 0 else ("#duck" if k % 2 == 0 else "#duck_f")
				_swimmer(g, nm, c, pl.z * rng.randf_range(0.3, 0.55), rng)
		# утки на реке: кружки по 1,8 м в воде, не у моста и не в озере
		var bridge_at := Vector2(-1000, -1000)
		for br: Dictionary in land.bridges:
			bridge_at = br["pos"]
		var placed := 0
		for s: Dictionary in Streams.samples(id, 22.0):
			var q: Vector2 = s["p"]
			if placed >= 7 or q.distance_to(bridge_at) < 16.0 or (pl.z > 0.0 and q.distance_to(Vector2(pl.x, pl.y)) < pl.z + 4.0):
				continue
			var good := true
			for a in 8:
				if not land.is_water(q + Vector2.from_angle(a * TAU / 8.0) * 2.0):
					good = false
			if not good or rng.randf() < 0.3:
				continue
			placed += 1
			for k in 2:
				_swimmer(g, "#duck" if k == 0 else "#duck_f", q, 1.4, rng)


static func _swimmer(g, nm: String, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = Parts._special_mesh(nm)
	g.add_child(mi)
	g.swimmers.append({"n": mi, "c": c, "r": r, "a": rng.randf() * TAU, "w": rng.randf_range(0.05, 0.12) * (1.0 if rng.randf() < 0.5 else -1.0), "ph": rng.randf() * TAU})


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
					var rr := rng.randf() < 0.6
					_add(g, "M:SM_Env_Rock_Round_01" if rr else "M:SM_Env_Rock_Small_Pile_01", q0, rng.randf_range(0.18, 0.3) if rr else 1.0, rng, -0.08)
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
			if rng.randf() < 0.09:
				var q3 := p + nor * rng.randf_range(-1.3, 1.3) * w
				if _free_spot(g, q3):
					var yr := land.height_at(q3.x, q3.y)
					var small := rng.randf() < 0.65
					var rn := "M:SM_Env_Rock_Small_01" if small else "M:SM_Env_Rock_Round_01"
					var rs := rng.randf_range(0.8, 1.6) if small else rng.randf_range(0.12, 0.22)    # камешки ~0,3–0,5 м, валуны ~0,3–0,5 м
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
		if Streams.def_of(id).get("river", false):
			_river_life(g, id, rng)


## Жизнь у реки (15.11): камыш густыми куртинами по обоим берегам, валуны в воде и у воды, галька грудами на отмелях,
## кувшинки у берегов, у озера — кольцо камыша, кувшинки, камни и коряга-бревно на мели. «Низкая»: без мелочи набора
static func _river_life(g, id: int, rng: RandomNumberGenerator) -> void:
	var land: Land = g.land
	for s: Dictionary in Streams.samples(id, 1.6):
		var p: Vector2 = s["p"]
		var w: float = s["w"]
		var dir: Vector2 = s["dir"]
		var nor := Vector2(-dir.y, dir.x)
		for side: float in [-1.0, 1.0]:
			if not gen_low and rng.randf() < 0.3:
				var q := p + nor * side * (w + rng.randf_range(-0.1, 1.1))
				if _free_spot(g, q):
					var y := land.height_at(q.x, q.y)
					var cnt := 1 + rng.randi() % 2
					for c in cnt:
						var qq := q + Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5))
						g._add_nature("M:SM_Env_Grass_Tall_Clump_0%d" % (1 + rng.randi() % 5), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.5, 0.9)),
							Vector3(qq.x, maxf(land.height_at(qq.x, qq.y), Land.WATER_Y - 0.12), qq.y)), qq)
			var sh: float = s["sh"]
			if rng.randf() < (0.16 if sh > 1.6 else 0.05):   # галька грудами на песчаных отмелях
				var qp := p + nor * side * (w + rng.randf_range(0.2, maxf(sh, 0.8)))
				if _free_spot(g, qp):
					_add(g, "M:SM_Env_Rock_Small_Pile_0%d" % (1 + rng.randi() % 2), qp, rng.randf_range(0.9, 1.4), rng, -0.05)
			if rng.randf() < 0.05:                         # валун у самой воды
				var qb := p + nor * side * (w + rng.randf_range(-0.6, 1.0))
				if _free_spot(g, qb):
					var rn := "M:SM_Env_Rock_0%d" % [1, 2, 5][rng.randi() % 3]
					_add(g, rn, qb, rng.randf_range(0.14, 0.26), rng, -0.1)
			if w > 1.5 and rng.randf() < 0.06:             # кувшинки у берегов (и в широких местах)
				var ql := p + nor * side * w * rng.randf_range(0.45, 0.85)
				if land.is_water(ql):
					g._add_nature("M:SM_Env_Lillies_0%d" % (1 + rng.randi() % 3), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.35, 0.6)),
						Vector3(ql.x, Land.WATER_Y + 0.012, ql.y)), ql)
		if rng.randf() < 0.05:                              # камень посреди реки
			var qm := p + nor * rng.randf_range(-0.5, 0.5) * w
			if land.is_water(qm):
				g._add_nature("M:SM_Env_Rock_0%d" % [1, 2, 5][rng.randi() % 3], Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.1, 0.17)),
					Vector3(qm.x, Land.WATER_Y - 0.05, qm.y)), qm)
	# озеро: камыш кольцом по берегу, кувшинки, камни
	var pl: Vector3 = Streams.plan(id)["pool"]
	if pl.z > 0.0:
		var c := Vector2(pl.x, pl.y)
		for k in int(pl.z * 6.0):
			var a := rng.randf() * TAU
			var q := c + Vector2(cos(a), sin(a)) * pl.z * rng.randf_range(0.82, 1.22)
			var y := land.height_at(q.x, q.y)
			if y > Land.WATER_Y + 0.7 or not _free_spot(g, q):
				continue
			if not gen_low and rng.randf() < 0.75:
				g._add_nature("M:SM_Env_Grass_Tall_Clump_0%d" % (1 + rng.randi() % 5), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.6, 1.0)),
					Vector3(q.x, maxf(y, Land.WATER_Y - 0.1), q.y)), q)
			elif rng.randf() < 0.5:
				_add(g, "M:SM_Env_Rock_Small_Pile_0%d" % (1 + rng.randi() % 2), q, rng.randf_range(0.9, 1.4), rng, -0.05)
		for k in int(pl.z * 0.6):
			var a2 := rng.randf() * TAU
			var q2 := c + Vector2(cos(a2), sin(a2)) * pl.z * rng.randf_range(0.5, 0.9)
			if land.is_water(q2):
				_add(g, "M:SM_Env_Rock_0%d" % [1, 2, 5][rng.randi() % 3], q2, rng.randf_range(0.12, 0.2), rng, -0.12)


## Течение: полоса над водой каждого ручья (светлые струйки бегут вниз по течению). Одна сетка на все ручьи, без теней;
## на «Низкой» и «Очень низкой» спрятана (quality)
static var flow_node: MeshInstance3D = null
static func _flow(g) -> void:
	var land: Land = g.land
	var sts := [SurfaceTool.new(), SurfaceTool.new()]           # 0 — ручьи, 1 — река (шире и быстрее)
	for st: SurfaceTool in sts:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := [false, false]
	for id: int in land.streams:
		var p := Streams.plan(id)
		var pts: PackedVector2Array = p["pts"]
		var wid: PackedFloat32Array = p["w"]
		var rv := 1 if bool(p["river"]) else 0
		var st: SurfaceTool = sts[rv]
		var pl: Vector3 = p["pool"]
		var acc := 0.0
		for i in range(1, pts.size()):
			var a := pts[i - 1]
			var b := pts[i]
			var l := a.distance_to(b)
			if rv == 1 and (b.x < -2.0 or b.y < -2.0 or b.x > Land.SIZE + 2.0 or a.x > Land.SIZE + 2.0 or a.y < -2.0):
				acc += l
				continue                             # за краем карты воду рисует полоса реки (Streams.far_ribbon_mesh)
			if rv == 1 and pl.z > 0.0 and a.distance_to(Vector2(pl.x, pl.y)) < pl.z * 0.9:
				acc += l
				continue                             # в озере течения нет
			var da := (pts[mini(i, pts.size() - 1)] - pts[maxi(i - 2, 0)]).normalized()
			var db := (pts[mini(i + 1, pts.size() - 1)] - pts[i - 1]).normalized()
			var na := Vector2(-da.y, da.x) * wid[i - 1] * 0.9
			var nb := Vector2(-db.y, db.x) * wid[i] * 0.9
			var y := Land.WATER_Y + 0.02
			var v := [Vector3(a.x - na.x, y, a.y - na.y), Vector3(a.x + na.x, y, a.y + na.y), Vector3(b.x + nb.x, y, b.y + nb.y), Vector3(b.x - nb.x, y, b.y - nb.y)]
			var uv := [Vector2(0, acc), Vector2(1, acc), Vector2(1, acc + l), Vector2(0, acc + l)]
			for k: int in [0, 1, 2, 0, 2, 3]:
				st.set_uv(uv[k])
				st.set_normal(Vector3.UP)
				st.add_vertex(v[k])
			acc += l
			any[rv] = true
	if not any[0] and not any[1]:
		return
	var mi := MeshInstance3D.new()
	var am := ArrayMesh.new()
	var mats := []
	for rv2 in 2:
		if not any[rv2]:
			continue
		(sts[rv2] as SurfaceTool).commit(am)
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/stream_flow.gdshader")
		if rv2 == 1:
			m.set_shader_parameter("speed", 0.95)
			m.set_shader_parameter("across_scale", 0.45)
			m.set_shader_parameter("strength", 0.42)
		mats.append(m)
	mi.mesh = am
	for si in mats.size():
		mi.set_surface_override_material(si, mats[si])
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


## Мост там, где ручей проходит под большой дорогой: дорога остаётся насыпью, по бокам — римская кладка из деталей
## Ancient Empire в тёплом травертине: над водой — арка с пилястрами по сторонам, дальше — сплошная стенка, у концов —
## пилястры, по краю дороги — парапет с карнизом, на уровне дороги — тяга. Мост не сносится (как арка въезда)
static func _bridges(g) -> void:
	var land: Land = g.land
	for br: Dictionary in land.bridges:
		if br.get("river", false):
			_river_bridge(g, br)
			continue
		var c: Vector2 = br["pos"]
		var sd: Vector2 = br["dir"]                    # куда течёт ручей
		# вдоль дороги — по самой дороге (15.11: ручей часто идёт под дорогой наискось, мост «поперёк ручья» стоял криво)
		var rd := _road_dir(land, c, Vector2(-sd.y, sd.x))
		var sin_t := maxf(absf(rd.x * sd.y - rd.y * sd.x), 0.45)     # синус угла между дорогой и ручьём
		var y: float = br["y"]
		var w: float = br["w"]
		var hw := Land.ROAD_R
		var depth := y - (Land.WATER_Y - 0.25)         # от дороги до дна у арки
		var half := clampf((w + Streams.SHORE + (y - Land.WATER_Y - 0.25) / Streams.SLOPE) / sin_t, 3.0, 10.0)
		var ws := clampf((w * 2.0 + 1.0) / sin_t, 2.6, 6.0)       # пролёт арки — вдоль дороги, с запасом на наклон ручья
		var bp := Bp.new(91)
		var yaw := atan2(rd.x, rd.y)                    # местная +Z — вдоль дороги, +X — вниз по ручью
		var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, y, c.y))
		# тёплый травертин: камень стен и кладка пилястр — в тон арке въезда и терракотовому городу
		var stone := {"Stucco_White_01": "Stone_01", "tints": {"Stone_01": Color(1.06, 0.94, 0.78), "Building_Large_Brick_01": Color(1.0, 0.9, 0.76)}}
		var blocks := {"Building_Large_Brick_01": "Building_Large_Brick_01", "tints": {"Building_Large_Brick_01": Color(1.02, 0.9, 0.74)}}
		for side: float in [-1.0, 1.0]:
			var x := side * (hw + 0.05)
			# стенка над насыпью: посередине — арка над водой, по сторонам — сплошная кладка
			_side_piece(bp, "SM_Bld_Wall_Door_Double_01", side, x, -depth, -ws * 0.5, ws * 0.5, depth, 1.0, 2.5, 3.01, stone)
			for e: float in [-1.0, 1.0]:
				var z0 := ws * 0.5 if e > 0.0 else -half
				var z1 := half if e > 0.0 else -ws * 0.5
				if z1 - z0 > 0.2:
					_side_piece(bp, "SM_Bld_Wall_01", side, x, -depth, z0, z1, depth, 1.0, 2.5, 3.01, stone)
			# тяга на уровне дороги и парапет с карнизом
			_side_piece(bp, "SM_Bld_Wall_Large_Cap_01", side, x + side * 0.05, -0.12, -half - 0.2, half + 0.2, 0.22, 0.9, 5.02, 1.0, stone)
			_side_piece(bp, "SM_Bld_Wall_01", side, x, 0.0, -half - 0.2, half + 0.2, 0.62, 0.8, 2.5, 3.01, stone)
			_side_piece(bp, "SM_Bld_Wall_Large_Cap_01", side, x + side * 0.02, 0.62, -half - 0.3, half + 0.3, 0.18, 0.7, 5.02, 1.0, stone)
			# пилястры: по сторонам арки (от дна) и у концов моста (до верха парапета)
			for zp: float in [-ws * 0.5, ws * 0.5, -half, half]:
				var hp := depth + 0.62 + 0.15
				var pb := Basis(Vector3(0, 0, -side), Vector3.UP, Vector3(side, 0, 0)) * Basis.from_scale(Vector3(0.5 / 0.92, hp / 4.55, 0.42 / 0.92))
				bp.parts.append(["SM_Bld_Wall_Large_Pillar_01", Transform3D(pb, Vector3(x + side * 0.12, -depth, zp)), blocks])
		g.parts.place(bp, xf)
		# под аркой — вода дальше (короткая полоса воды в насыпь), чтобы в проёме блестела вода, а не земля
		var under := Bp.new(92)
		for side2: float in [-1.0, 1.0]:
			CatMonuments._box(under, "#water", Vector3(side2 * (hw - 0.3), Land.WATER_Y - y + 0.02, 0.0), Vector3(1.0, 0.04, ws - 0.3))
		g.parts.place(under, xf)


## Римский мост через реку (15.11): несколько арок подряд вдоль дороги, под ними течёт вода. Дорога для ходьбы остаётся
## насыпью (клетки не меняются), а видимая земля под мостом — дно реки (Land.vis_h); мост — плита с арками по обоим
## бокам из деталей Ancient Empire (стена с аркой, пилястры, тяга, парапет с карнизом) в тёплом травертине. Мост стоит
## ровно вдоль дороги, наклон дороги по холму повторяет. Не сносится (как арка въезда)
static func _river_bridge(g, br: Dictionary) -> void:
	var land: Land = g.land
	var c: Vector2 = br["pos"]
	var sd: Vector2 = br["dir"]
	var rd := _road_dir(land, c, Vector2(-sd.y, sd.x))
	# пролёт: по клеткам дороги над рекой — от t0 до t1 вдоль дороги (метры от середины c)
	var t0 := INF
	var t1 := -INF
	for k: int in br["cells"]:
		var t := (land.cell_center(k % Land.N, k / Land.N) - c).dot(rd)
		t0 = minf(t0, t)
		t1 = maxf(t1, t)
	var tc := (t0 + t1) * 0.5
	var span := (t1 - t0) + 1.0
	var n := maxi(3, int(ceil(span / 3.5)))
	var aw := clampf(span / n, 2.9, 4.4)
	var T := n * aw
	var ctr := c + rd * tc
	# высота и наклон дороги: прямая по высотам дороги на длину моста с запасом
	var sx := 0.0
	var sy := 0.0
	var sxx := 0.0
	var sxy := 0.0
	var m := 0
	for tt in range(-int(T * 0.5) - 6, int(T * 0.5) + 7):
		var q := ctr + rd * float(tt)
		var yy := land.height_at(q.x, q.y)
		sx += float(tt)
		sy += yy
		sxx += float(tt * tt)
		sxy += float(tt) * yy
		m += 1
	var slope := (float(m) * sxy - sx * sy) / maxf(float(m) * sxx - sx * sx, 1e-4)
	var y0 := (sy - slope * sx) / float(m)
	var hw := Land.ROAD_R
	var depth := y0 - (Land.WATER_Y - 0.25)
	var half := T * 0.5 + clampf(depth / 0.6, 2.5, 7.0)
	var bp := Bp.new(93)
	var yaw := atan2(rd.x, rd.y)                        # местная +Z — вдоль дороги
	var xf := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -atan(slope)), Vector3(ctr.x, y0, ctr.y))
	var stone := {"Stucco_White_01": "Stone_01", "tints": {"Stone_01": Color(1.06, 0.94, 0.78), "Building_Large_Brick_01": Color(1.0, 0.9, 0.76)}}
	var blocks := {"Building_Large_Brick_01": "Building_Large_Brick_01", "tints": {"Building_Large_Brick_01": Color(1.02, 0.9, 0.74)}}
	# толща моста под дорогой (потолок арок), мощёная проезжая часть сверху
	CatMonuments._box(bp, "#marble", Vector3(0, -0.4, 0), Vector3(hw * 2.0 + 0.12, 0.8, T + 0.1))
	CatMonuments._put(bp, "SM_Bld_Base_Floor_01", Transform3D(Basis.from_scale(Vector3((hw * 2.0 + 0.1) / 2.5, 1, (T + 0.6) / 2.5)), Vector3(-hw - 0.05, 0.03, -T * 0.5 - 0.3)), {"Stone_01": "Floor_Tiles_04"})
	for side: float in [-1.0, 1.0]:
		var x := side * (hw + 0.05)
		# стенка над насыпью: арки подряд над водой, по краям — сплошная кладка до конца моста
		for i in n:
			var z0 := -T * 0.5 + i * aw
			var d_i := depth + slope * (z0 + aw * 0.5)
			_side_piece(bp, "SM_Bld_Wall_Door_Double_01", side, x, -d_i, z0, z0 + aw, d_i, 1.0, 2.5, 3.01, stone)
		for e: float in [-1.0, 1.0]:
			var za := T * 0.5 if e > 0.0 else -half
			var zb := half if e > 0.0 else -T * 0.5
			var d_e := depth + slope * (za + zb) * 0.5
			if zb - za > 0.2:
				_side_piece(bp, "SM_Bld_Wall_01", side, x, -d_e, za, zb, d_e, 1.0, 2.5, 3.01, stone)
		# тяга на уровне дороги и парапет с карнизом
		_side_piece(bp, "SM_Bld_Wall_Large_Cap_01", side, x + side * 0.05, -0.12, -half - 0.2, half + 0.2, 0.22, 0.9, 5.02, 1.0, stone)
		_side_piece(bp, "SM_Bld_Wall_01", side, x, 0.0, -half - 0.2, half + 0.2, 0.62, 0.8, 2.5, 3.01, stone)
		_side_piece(bp, "SM_Bld_Wall_Large_Cap_01", side, x + side * 0.02, 0.62, -half - 0.3, half + 0.3, 0.18, 0.7, 5.02, 1.0, stone)
		# пилястры: между арками (от воды) и у концов моста
		var zs := []
		for i in range(0, n + 1):
			zs.append(-T * 0.5 + i * aw)
		zs.append(-half)
		zs.append(half)
		for zp: float in zs:
			var d_p := depth + slope * zp
			var hp := d_p + 0.62 + 0.15
			var pb := Basis(Vector3(0, 0, -side), Vector3.UP, Vector3(side, 0, 0)) * Basis.from_scale(Vector3(0.5 / 0.92, hp / 4.55, 0.42 / 0.92))
			bp.parts.append(["SM_Bld_Wall_Large_Pillar_01", Transform3D(pb, Vector3(x + side * 0.12, -d_p, zp)), blocks])
	g.parts.place(bp, xf)


## Направление дороги у моста (единичный вектор): главная ось клеток мостовой, троп и площадей вокруг точки c (радиус 7 м);
## нет дороги вокруг — dflt
static func _road_dir(land: Land, c: Vector2, dflt: Vector2) -> Vector2:
	var sxx := 0.0
	var sxy := 0.0
	var syy := 0.0
	var n := 0
	var N := Land.N
	var ci := int(c.x / Land.CELL)
	var cj := int(c.y / Land.CELL)
	var rr := int(7.0 / Land.CELL)
	for dj in range(-rr, rr + 1, 2):
		for di in range(-rr, rr + 1, 2):
			var i := ci + di
			var j := cj + dj
			if i < 0 or j < 0 or i >= N or j >= N or di * di + dj * dj > rr * rr:
				continue
			if not Land.walk_kind(land.kind[j * N + i]):
				continue
			sxx += float(di * di)
			sxy += float(di * dj)
			syy += float(dj * dj)
			n += 1
	if n < 30:
		return dflt
	var th := 0.5 * atan2(2.0 * sxy, sxx - syy)
	return Vector2(cos(th), sin(th))


## Деталь стены Synty вдоль дороги на боку моста: длина по дороге — от z0 до z1, высота h от y0, толщина — tk.
## Стены Synty — вдоль своей +X (длина lx), высота ly, наружу — +Z: поворачиваем так, чтобы наружу смотрела сторона моста
static func _side_piece(bp: Bp, name: String, side: float, x: float, y0: float, z0: float, z1: float, h: float, tk: float, lx: float, ly: float, rm: Dictionary) -> void:
	var b := Basis(Vector3(0, 0, -side), Vector3.UP, Vector3(side, 0, 0)) * Basis.from_scale(Vector3((z1 - z0) / lx, h / ly, tk))
	bp.parts.append([name, Transform3D(b, Vector3(x, y0, z1 if side > 0.0 else z0)), rm])


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
			# (get_meta с умолчанием null ругается в журнал, если ключа нет — проверяем has_meta)
			if not sm.has_meta("frz0"):
				sm.set_meta("frz0", true)
				var sw0 = sm.get_shader_parameter("sway")
				var sp0 = sm.get_shader_parameter("speed")
				if sw0 != null:
					sm.set_meta("sway0", sw0)
				if sp0 != null:
					sm.set_meta("speed0", sp0)
			if sm.has_meta("sway0"):
				sm.set_shader_parameter("sway", 0.0 if on_ else sm.get_meta("sway0"))
			if sm.has_meta("speed0"):
				sm.set_shader_parameter("speed", 0.0 if on_ else sm.get_meta("speed0"))
	for gm: ShaderMaterial in GrassCarpet.mats:
		gm.set_shader_parameter("sway", 0.0 if on_ else 0.07)
	if is_instance_valid(flow_node):
		flow_node.visible = not on_ and not low
