extends Node3D
## Витрина CivCity на Godot: долина с площадью и фонтаном, улицы с римскими домами рядами,
## ворота в скале на севере (оттуда приезжают переселенцы), море на востоке, холмы, пинии и кипарисы,
## тёплый свет с отражённым светом и мягкими тенями, дым из труб, птицы.
## Снимки для проверки: Godot --path godot -- --shot=путь.png --view=x,z,yaw,pitch,dist --hour=7.5

var terrain: Terrain
var rig: CameraRig
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var lamps: Array[OmniLight3D] = []
var hour := 7.6
var shot_path := ""
var shot_frame := 150
var frame := 0
var house_rects: Array[Rect2] = []
var blocked := PackedByteArray()   # клетки под постройками и вплотную к ним — там не растут деревья и трава
var footprints := []          # {c, ax, hw, hd} — повёрнутые прямоугольники домов (чтобы не налезали)
var houses := []              # {door, smoke: [частицы], pos, lived} — для заселения
var obstacles := []           # [Vector2 центр, радиус] — фонтан, прилавки, скамьи, фонари
var benches := []             # [Vector2 место, Vector2 куда смотрит сидящий]
var stall_spots := []         # [Vector2 где стоит покупатель, Vector2 куда смотрит]
var mat_props := Kit.material()


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	hour = float(args.get("hour", "7.6"))
	shot_path = args.get("shot", "")
	shot_frame = int(args.get("frames", "150"))
	_environment()
	terrain = Terrain.new()
	_town()
	_laundry()
	_aqueduct(Vector2(7.0, 14.0), Vector2(27.0, 33.0), 9.5)
	_mark_blocked(0.5)
	_yards()
	_pave_rect(Vector2(40.0, 58.4), 6.2, 7.2, Terrain.Kind.PLAZA)
	_ground()
	_water()
	_nature()
	_grass()
	add_child(Birds.new())
	var ppl := People.new()
	ppl.terrain = terrain
	ppl.houses = houses
	ppl.footprints = footprints
	ppl.obstacles = obstacles
	ppl.benches = benches
	ppl.stall_spots = stall_spots
	add_child(ppl)
	rig = CameraRig.new()
	rig.terrain = terrain
	add_child(rig)
	var v := str(args.get("view", "38,44,200,38,34")).split(",")
	rig.set_view(Vector3(float(v[0]), Terrain.TOWN_Y, float(v[1])), float(v[2]), float(v[3]), float(v[4]))
	_set_hour(hour)


func _process(_dt: float) -> void:
	frame += 1
	if shot_path != "" and frame == shot_frame:
		var img := get_viewport().get_texture().get_image()
		img.save_png(shot_path)
		print("SHOT ", shot_path, " fps=", Engine.get_frames_per_second())
		get_tree().quit()


# ---------- небо, солнце, свет ----------

func _environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("5b8fcc")
	sky_mat.sky_horizon_color = Color("e7d3b4")
	sky_mat.ground_horizon_color = Color("d8c3a0")
	sky_mat.ground_bottom_color = Color("6e6b56")
	sky_mat.sun_angle_max = 25.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.4
	env.ssao_power = 1.7
	env.ssao_detail = 0.8
	env.ssil_enabled = true
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.9
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_bounce_feedback = 0.6
	env.sdfgi_min_cell_size = 0.15
	env.sdfgi_energy = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color("dcc9ac")
	env.fog_density = 0.004
	env.fog_aerial_perspective = 0.5
	env.fog_sky_affect = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 110.0
	sun.light_angular_distance = 1.4
	sun.shadow_blur = 1.2
	add_child(sun)


## Время суток: солнце встаёт на востоке (со стороны моря), низкое солнце — золотое, ночью горят фонари
func _set_hour(h: float) -> void:
	var day := clampf((h - 5.5) / 14.0, 0.0, 1.0)          # 5:30 → 0, 19:30 → 1
	var ang := day * PI
	var to_sun := Vector3(cos(ang), sin(ang) * 0.95 + 0.04, 0.38).normalized()
	var night := h < 5.6 or h > 19.6
	if night:
		to_sun = Vector3(-0.3, 0.55, -0.5).normalized()     # луна
	var elev := clampf(to_sun.y, 0.0, 1.0)
	var c := Vector3(38, 0, 44)
	sun.look_at_from_position(c + to_sun * 120.0, c, Vector3.UP)
	var warm := Color("ffb26e").lerp(Color("fff1dc"), smoothstep(0.15, 0.7, elev))
	sun.light_color = Color("9fb4ff") if night else warm
	sun.light_energy = 0.35 if night else 1.4 + 1.6 * smoothstep(0.05, 0.6, elev)
	sky_mat.sky_horizon_color = Color("2b3550") if night else Color("f0c99a").lerp(Color("e3d8c4"), smoothstep(0.1, 0.6, elev))
	sky_mat.sky_top_color = Color("101833") if night else Color("5b8fcc")
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color.darkened(0.1)
	env.ambient_light_energy = 0.25 if night else 0.55
	env.fog_light_color = Color("39436a") if night else warm.lerp(Color("dcc9ac"), 0.6)
	for l in lamps:
		l.visible = night or h < 6.6 or h > 18.8
		l.light_energy = 2.4 if night else 1.2


# ---------- земля и вода ----------

func _ground() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = terrain.mesh()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/ground.gdshader")
	mi.material_override = sm
	add_child(mi)


func _water() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	pm.subdivide_width = 120
	pm.subdivide_depth = 120
	mi.mesh = pm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/water.gdshader")
	mi.material_override = sm
	mi.position = Vector3(40, Terrain.SEA_Y, 40)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ---------- город ----------

var _house_seed := 100


## Пересекаются ли два повёрнутых прямоугольника (проверка разделяющих осей)
static func _obb_hit(a: Dictionary, b: Dictionary) -> bool:
	for f in [a, b]:
		var ax: Vector2 = f["ax"]
		for axis: Vector2 in [ax, Vector2(-ax.y, ax.x)]:
			var pa := _proj(a, axis)
			var pb := _proj(b, axis)
			if pa.y <= pb.x or pb.y <= pa.x:
				return false
	return true


static func _proj(f: Dictionary, axis: Vector2) -> Vector2:
	var c: Vector2 = f["c"]
	var ax: Vector2 = f["ax"]
	var az := Vector2(-ax.y, ax.x)
	var r: float = absf(ax.dot(axis)) * f["hw"] + absf(az.dot(axis)) * f["hd"]
	var m := c.dot(axis)
	return Vector2(m - r, m + r)


func _fits(fp: Dictionary) -> bool:
	for o in footprints:
		if _obb_hit(fp, o):
			return false
	# не на мостовой и не на площади: углы и середина
	var c: Vector2 = fp["c"]
	var ax: Vector2 = fp["ax"]
	var az := Vector2(-ax.y, ax.x)
	for u: float in [-1.0, 0.0, 1.0]:
		for v: float in [-1.0, 0.0, 1.0]:
			var q: Vector2 = c + ax * u * (fp["hw"] - 0.2) + az * v * (fp["hd"] - 0.2)
			if q.distance_to(Terrain.PLAZA_C) < terrain.plaza_r(q):
				return false
			var rd: Array = terrain.road_dist(q)
			if (rd[0] as float) < (rd[1] as float):
				return false
			var i := int(q.x / Terrain.CELL)
			var j := int(q.y / Terrain.CELL)
			if not terrain.inside(i, j) or absf(terrain.h[terrain.idx(i, j)] - Terrain.TOWN_Y) > 0.3:
				return false
	return true


func _add_house(pos: Vector2, facing: Vector2, p: Dictionary) -> bool:
	var axd := Vector2(facing.y, -facing.x)
	var fp := {"c": pos, "ax": axd, "hw": float(p.get("w", 4.4)) / 2 + 0.02, "hd": float(p.get("d", 4.6)) / 2 + 0.25}
	if not _fits(fp):
		return false
	footprints.append(fp)
	_house_seed += 1
	p["seed"] = _house_seed
	var hb := House.new()
	var res := hb.build(p)
	var mi := MeshInstance3D.new()
	mi.mesh = res["mesh"]
	mi.material_override = mat_props
	var y := terrain.height_at(pos.x, pos.y)
	var ang := atan2(facing.x, facing.y)      # +Z дома смотрит по facing
	mi.transform = Transform3D(Basis(Vector3.UP, ang), Vector3(pos.x, y, pos.y))
	add_child(mi)
	house_rects.append(Rect2(pos - Vector2(3.2, 3.2), Vector2(6.4, 6.4)))
	var rec := {"door": mi.transform * (res["door"] as Vector3) + Vector3(facing.x, 0, facing.y) * 0.9, "smoke": [], "pos": pos, "lived": false, "face": facing}
	for s in res["smoke"]:
		rec["smoke"].append(_smoke(mi.transform * (s as Vector3)))
	houses.append(rec)
	return true


## Ряд домов вдоль улицы a→b с одной стороны (side = ±1): стена к стене, фасадом к улице
func _row(a: Vector2, b: Vector2, side: float, setback: float, from_t := 0.0, to_t := 1.0) -> void:
	var dir := (b - a).normalized()
	var nrm := Vector2(-dir.y, dir.x) * side
	var len := a.distance_to(b)
	var t := from_t * len
	var rng := RandomNumberGenerator.new()
	rng.seed = int(a.x * 13 + a.y * 7 + side * 3)
	while t < to_t * len - 3.0:
		var w := rng.randf_range(3.6, 5.0)
		var d := rng.randf_range(4.2, 5.2)
		var fl: int = [1, 2, 2, 2, 3][rng.randi() % 5]
		var roofs := ["gable", "gable", "hip", "hip", "terrace"]
		var p := {"w": w, "d": d, "floors": fl, "roof": roofs[rng.randi() % roofs.size()],
			"shop": rng.randf() < 0.4, "balcony": fl >= 2 and rng.randf() < 0.5}
		var c := a + dir * (t + w / 2) + nrm * (setback + d / 2)
		# дом смотрит фасадом на улицу; его ось X идёт вдоль улицы
		if _add_house(c, -nrm, p):
			t += w + (0.0 if rng.randf() < 0.7 else rng.randf_range(1.0, 2.5))
		else:
			t += 0.8


func _town() -> void:
	var k := Kit.new()
	# ворота в скале
	k.xf = Transform3D(Basis.IDENTITY, Vector3(Terrain.GATE.x, Terrain.TOWN_Y, Terrain.GATE.y - 0.4))
	for f in Props.gate(k):
		_light(k.xf * (f as Vector3), Color("ffa04a"), 6.0)
	# фонтан посреди площади
	var pc := Terrain.PLAZA_C
	# фонтан: круглая чаша, посередине — статуя девушки с кувшином на постаменте
	k.xf = Transform3D(Basis.IDENTITY, Vector3(pc.x, Terrain.TOWN_Y, pc.y))
	Props.fountain(k)
	_art("Women_holding_jar", pc, 1.9, PI, 1.25)
	obstacles.append([pc, 2.8])
	# храм на южной стороне площади, фасадом к фонтану; перед ступенями — статуи богов
	var temple_p := Vector2(40.0, 58.4)
	footprints.append({"c": temple_p, "ax": Vector2(1, 0), "hw": 4.9, "hd": 5.8, "noyard": true})
	_art("Tenple_001", temple_p, 8.7, PI / 2)
	for st: Array in [[Vector2(36.4, 51.4), "Athenea"], [Vector2(43.6, 51.4), "Hercules"], [Vector2(30.6, 40.6), "Zeus"], [Vector2(45.6, 42.2), "Hera"]]:
		var sp2: Vector2 = st[0]
		_art("Statue_Base_Small", sp2, 1.0, 0.0)
		var face := (pc - sp2).normalized()
		_art(st[1], sp2, 2.3, atan2(face.x, face.y), 1.0)
		obstacles.append([sp2, 0.9])
	_art("Sun_Clock", Vector2(41.8, 39.4), 1.15, 0.4)
	obstacles.append([Vector2(41.8, 39.4), 0.7])
	# прилавки рынка, скамьи, амфоры, ящики
	var stalls := [Vector2(34.0, 40.6), Vector2(42.4, 41.0), Vector2(33.6, 47.6), Vector2(43.0, 47.4)]
	for i in stalls.size():
		var sp: Vector2 = stalls[i]
		var face := (pc - sp).normalized()
		k.xf = Transform3D(Basis(Vector3.UP, atan2(face.x, face.y) + PI / 2), Vector3(sp.x, Terrain.TOWN_Y, sp.y))
		Props.stall(k, i + 3)
		obstacles.append([sp, 1.45])
		stall_spots.append([sp + face * 1.9, -face])
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		var bp := pc + Vector2(cos(a), sin(a)) * 3.2
		k.xf = Transform3D(Basis(Vector3.UP, -a + PI / 2), Vector3(bp.x, Terrain.TOWN_Y, bp.y))
		Props.bench(k)
		obstacles.append([bp, 0.85])
		benches.append([bp, Vector2(cos(a), sin(a))])
	# фонари вокруг площади и вдоль дороги от ворот
	var lamp_pts := []
	for i in 8:
		var a := TAU * i / 8.0 + 0.2
		lamp_pts.append(pc + Vector2(cos(a), sin(a)) * (terrain.plaza_r(pc + Vector2(cos(a), sin(a))) - 0.6))
	for zz: float in [20.0, 27.0, 33.0]:
		lamp_pts.append(Vector2(41.9, zz))
	for lp in lamp_pts:
		var p2: Vector2 = lp
		k.xf = Transform3D(Basis.IDENTITY, Vector3(p2.x, terrain.height_at(p2.x, p2.y), p2.y))
		var fire := Props.lamp(k)
		obstacles.append([p2, 0.3])
		lamps.append(_light(k.xf * fire, Color("ffbf70"), 7.0))
	# кипарисы и пинии в городе
	for i in 6:
		var tp := Vector2(37.2 + (i % 2) * 5.6, 20.0 + int(i / 2) * 5.5)
		k.xf = Transform3D(Basis.IDENTITY, Vector3(tp.x, Terrain.TOWN_Y, tp.y))
		Props.cypress(k, i + 40)
	for i in 10:
		k.xf = Transform3D(Basis(Vector3.UP, i * 1.3), Vector3(pc.x + randf_range(-7, 7), Terrain.TOWN_Y, pc.y + randf_range(-7, 7)))
		if (k.xf.origin - Vector3(pc.x, k.xf.origin.y, pc.y)).length() > 3.0:
			if i % 2 == 0:
				Props.amphora(k, Vector3.ZERO, i)
			else:
				Props.crate(k, Vector3.ZERO)
	var mi := MeshInstance3D.new()
	mi.mesh = k.mesh()
	mi.material_override = mat_props
	add_child(mi)
	# дома вокруг площади — сплошным рядом вдоль её края, фасадом к фонтану; выходы улиц свободны
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var a := 0.0
	while a < TAU:
		var w := rng.randf_range(3.8, 5.0)
		var dirv := Vector2(cos(a), sin(a))
		var edge := pc + dirv * (terrain.plaza_r(pc + dirv) + 0.5)
		var da := (w + 0.25) / edge.distance_to(pc)
		var mid := a + da * 0.5
		var dm := Vector2(cos(mid), sin(mid))
		var d := rng.randf_range(4.4, 5.2)
		var fl: int = [2, 2, 3][rng.randi() % 3]
		var em := pc + dm * (terrain.plaza_r(pc + dm) + 0.5)
		_add_house(em + dm * d / 2, -dm, {"w": w, "d": d, "floors": fl, "roof": ["gable", "hip", "gable", "hip", "terrace"][rng.randi() % 5],
			"shop": rng.randf() < 0.7, "balcony": fl == 3 or rng.randf() < 0.3})
		a += da
	_row(Vector2(30, 44.5), Vector2(17, 46.0), 1.0, 1.9)
	_row(Vector2(30, 44.5), Vector2(17, 46.0), -1.0, 1.9)
	_row(Vector2(46.5, 45.7), Vector2(58, 48.0), 1.0, 1.9)
	_row(Vector2(46.5, 45.7), Vector2(58, 48.0), -1.0, 1.9)
	_row(Vector2(38.4, 35.5), Vector2(40.0, 25.0), 1.0, 2.6, 0.0, 0.85)
	_row(Vector2(38.4, 35.5), Vector2(40.0, 25.0), -1.0, 2.6, 0.0, 0.85)
	# пинии в городе — только там, где нет домов
	var tk := Kit.new()
	for tp: Vector2 in [Vector2(29.5, 38.5), Vector2(46.5, 38.0), Vector2(46.8, 51.0), Vector2(29.0, 51.5), Vector2(33.0, 54.5), Vector2(44.0, 55.0)]:
		var probe := {"c": tp, "ax": Vector2(1, 0), "hw": 1.2, "hd": 1.2}
		var ok := true
		for o in footprints:
			if _obb_hit(probe, o):
				ok = false
				break
		if ok and (terrain.road_dist(tp)[0] as float) > 2.0:
			tk.xf = Transform3D(Basis.IDENTITY, Vector3(tp.x, Terrain.TOWN_Y, tp.y))
			Props.pine(tk, int(tp.x * 10))
	var tmi := MeshInstance3D.new()
	tmi.mesh = tk.mesh()
	tmi.material_override = mat_props
	add_child(tmi)


func _pave_rect(c: Vector2, hw: float, hd: float, kd: int) -> void:
	for j in range(int((c.y - hd) / Terrain.CELL), int((c.y + hd) / Terrain.CELL) + 1):
		for i in range(int((c.x - hw) / Terrain.CELL), int((c.x + hw) / Terrain.CELL) + 1):
			if terrain.inside(i, j):
				var kk := terrain.idx(i, j)
				if absf(terrain.h[kk] - Terrain.TOWN_Y) < 0.6:
					terrain.kind[kk] = kd
					terrain.h[kk] = Terrain.TOWN_Y


func _mark_blocked(margin: float) -> void:
	blocked.resize(Terrain.N * Terrain.N)
	blocked.fill(0)
	for f in footprints:
		var c: Vector2 = f["c"]
		var ax: Vector2 = f["ax"]
		var az := Vector2(-ax.y, ax.x)
		var hw: float = float(f["hw"]) + margin
		var hd: float = float(f["hd"]) + margin
		var r := hw + hd
		for j in range(int((c.y - r) / Terrain.CELL), int((c.y + r) / Terrain.CELL) + 1):
			for i in range(int((c.x - r) / Terrain.CELL), int((c.x + r) / Terrain.CELL) + 1):
				if not terrain.inside(i, j):
					continue
				var q := Vector2((i + 0.5) * Terrain.CELL, (j + 0.5) * Terrain.CELL) - c
				if absf(q.dot(ax)) < hw and absf(q.dot(az)) < hd:
					blocked[terrain.idx(i, j)] = 1


## Отмостка вокруг домов: мощёная полоса перед фасадом и по бокам, под домом — утоптанная земля
func _yards() -> void:
	for fp in footprints:
		if fp.get("noyard", false):
			continue
		var c: Vector2 = fp["c"]
		var ax: Vector2 = fp["ax"]
		var az := Vector2(-ax.y, ax.x)
		var hw: float = fp["hw"] + 0.7
		var hd: float = fp["hd"] + 0.7
		var r := hw + hd
		for j in range(int((c.y - r) / Terrain.CELL), int((c.y + r) / Terrain.CELL) + 1):
			for i in range(int((c.x - r) / Terrain.CELL), int((c.x + r) / Terrain.CELL) + 1):
				if not terrain.inside(i, j):
					continue
				var q := Vector2((i + 0.5) * Terrain.CELL, (j + 0.5) * Terrain.CELL) - c
				var u := absf(q.dot(ax))
				var v := absf(q.dot(az))
				var kk := terrain.idx(i, j)
				if u < hw and v < hd and terrain.kind[kk] == Terrain.Kind.GRASS and absf(terrain.h[kk] - Terrain.TOWN_Y) < 0.3:
					terrain.kind[kk] = Terrain.Kind.COBBLE
					terrain.h[kk] = Terrain.TOWN_Y


## Модель Artisau в точке pos (на земле), высотой height, повёрнутая на yaw, приподнятая на lift
func _art(name: String, pos: Vector2, height: float, yaw: float, lift := 0.0) -> Node3D:
	var n := Artisau.make(name, height)
	n.position = Vector3(pos.x, terrain.height_at(pos.x, pos.y) + lift, pos.y)
	n.rotation.y = yaw
	add_child(n)
	return n


## Акведук: арки с холмов к городу; русло наверху на одной высоте, поэтому опоры в низинах выше
func _aqueduct(a: Vector2, b: Vector2, top: float) -> void:
	var dir := (b - a).normalized()
	var len := a.distance_to(b)
	var bay := 4.0
	var n := int(len / bay)
	for i in n:
		var p := a + dir * (bay * (i + 0.5))
		var ground := terrain.height_at(p.x, p.y)
		var h := top - ground
		if h < 3.0:
			continue
		var node := Artisau.make("Aqueduct", 0.0)
		node.scale = Vector3(bay / 8.17, h / 37.03, 2.2 / 4.72)
		node.position = Vector3(p.x, ground, p.y)
		node.rotation.y = atan2(-dir.y, dir.x)
		add_child(node)
		footprints.append({"c": p, "ax": dir, "hw": bay * 0.5, "hd": 1.3, "noyard": true})


## Верёвки с бельём во дворах за домами
func _laundry() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	for i in houses.size():
		if i % 3 != 1:
			continue
		var h: Dictionary = houses[i]
		var face: Vector2 = h["face"]
		var pos: Vector2 = h["pos"]
		var at := pos - face * rng.randf_range(3.8, 4.4)
		var probe := {"c": at, "ax": Vector2(face.y, -face.x), "hw": 1.3, "hd": 0.4, "noyard": true}
		var ok := true
		for o in footprints:
			if _obb_hit(probe, o):
				ok = false
				break
		if not ok or not terrain.inside(int(at.x / Terrain.CELL), int(at.y / Terrain.CELL)):
			continue
		if absf(terrain.height_at(at.x, at.y) - Terrain.TOWN_Y) > 0.3:
			continue
		_art("Clothes_line", at, 2.2, atan2(face.x, face.y) + PI / 2)
		footprints.append(probe)


func _light(at: Vector3, col: Color, rng_m: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = at
	l.light_color = col
	l.omni_range = rng_m
	l.light_energy = 1.6
	l.shadow_enabled = false
	add_child(l)
	return l


## Дым из трубы: мягкие светлые клубы поднимаются, растут и тают
func _smoke(at: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 14
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.position = at
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.25, 1, 0.1)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.35
	pm.initial_velocity_max = 0.55
	pm.gravity = Vector3(0.12, 0.05, 0.04)
	pm.damping_min = 0.05
	pm.damping_max = 0.1
	pm.scale_min = 0.7
	pm.scale_max = 1.0
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.4))
	sc.add_point(Vector2(1, 2.4))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var grad := Gradient.new()
	grad.set_color(0, Color(0.95, 0.94, 0.92, 0.32))
	grad.set_color(1, Color(0.9, 0.9, 0.9, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.7, 0.7)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	var rg := Gradient.new()
	rg.set_color(0, Color(1, 1, 1, 1))
	rg.set_color(1, Color(1, 1, 1, 0))
	var rt := GradientTexture2D.new()
	rt.gradient = rg
	rt.fill = GradientTexture2D.FILL_RADIAL
	rt.fill_from = Vector2(0.5, 0.5)
	rt.fill_to = Vector2(1.0, 0.5)
	m.albedo_texture = rt
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


# ---------- природа ----------

## Кустики травы на лугах: тысячи пучков одним вызовом (оттенок — как у земли под ними)
func _grass() -> void:
	var k := Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 6:
		var a := TAU * i / 6.0 + rng.randf() * 0.5
		var r := rng.randf_range(0.02, 0.09)
		var base := Vector3(cos(a) * r, 0, sin(a) * r)
		var tip := base * 2.2 + Vector3(rng.randf_range(-0.05, 0.05), rng.randf_range(0.2, 0.34), rng.randf_range(-0.05, 0.05))
		var side := Vector3(-sin(a), 0, cos(a)) * 0.025
		var c := Color(1, 1, 1).darkened(rng.randf() * 0.15)
		k.tri(base - side, base + side, tip, c)
		k.tri(base + side, base - side, tip, c)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = k.mesh()
	var xs: Array[Transform3D] = []
	var cs: Array[Color] = []
	for n in 60000:
		var x := rng.randf_range(0.5, 79.5)
		var z := rng.randf_range(0.5, 79.5)
		var i := int(x / Terrain.CELL)
		var j := int(z / Terrain.CELL)
		var kk := terrain.idx(i, j)
		if terrain.kind[kk] != Terrain.Kind.GRASS:
			continue
		var p := Vector2(x, z)
		if (terrain.road_dist(p)[0] as float) < 1.8 or p.distance_to(Terrain.PLAZA_C) < Terrain.PLAZA_R + 1.0:
			continue
		if blocked[kk]:
			continue
		var sc := rng.randf_range(0.7, 1.5)
		xs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.8, 1.3), sc)), Vector3(x, terrain.h[kk], z)))
		cs.append(terrain.top_color(kk, terrain.h[kk]).lightened(rng.randf_range(0.0, 0.12)))
	mm.instance_count = xs.size()
	for q in xs.size():
		mm.set_instance_transform(q, xs[q])
		mm.set_instance_color(q, cs[q])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var gm := Kit.material(0.9)
	gm.vertex_color_use_as_albedo = true
	mmi.material_override = gm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _free_spot(x: float, z: float) -> bool:
	var i := int(x / Terrain.CELL)
	var j := int(z / Terrain.CELL)
	if not terrain.inside(i, j):
		return false
	var kk := terrain.idx(i, j)
	if terrain.kind[kk] != Terrain.Kind.GRASS:
		return false
	var p := Vector2(x, z)
	if (terrain.road_dist(p)[0] as float) < 2.6:
		return false
	if p.distance_to(Terrain.PLAZA_C) < Terrain.PLAZA_R + 3.5:
		return false
	return blocked[kk] == 0


func _nature() -> void:
	var k := Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var placed := 0
	for n in 2600:
		var x := rng.randf_range(1.0, 79.0)
		var z := rng.randf_range(1.0, 79.0)
		if not _free_spot(x, z):
			continue
		var y := terrain.height_at(x, z)
		var town := Vector2(x, z).distance_to(Vector2(38, 46))
		var hill := clampf((y - Terrain.TOWN_Y) / 6.0, 0.0, 1.0)
		var r := rng.randf()
		k.xf = Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(x, y, z))
		if town < 22.0 and r < 0.5:
			continue                                   # в городе природы меньше
		if r < 0.035 + hill * 0.05:
			Props.pine(k, rng.randi())
		elif r < 0.08 + hill * 0.08:
			Props.cypress(k, rng.randi())
		elif r < 0.13:
			Props.olive(k, rng.randi())
		elif r < 0.3:
			Props.bush(k, rng.randi(), rng.randf_range(0.7, 1.3))
		elif r < 0.5:
			Props.flowers(k, rng.randi())
		elif r < 0.56 and hill > 0.2:
			Props.rock(k, rng.randi(), rng.randf_range(0.6, 1.6))
		else:
			continue
		placed += 1
	var mi := MeshInstance3D.new()
	mi.mesh = k.mesh()
	mi.material_override = mat_props
	add_child(mi)
