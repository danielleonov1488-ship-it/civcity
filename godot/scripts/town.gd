extends Node3D
## Витрина CivCity на моделях Synty POLYGON Ancient Empire (куплено владельцем): долина с площадью и фонтаном, улицы с римскими домами рядами,
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
var batch := SyntyBatch.new()      # все детали Synty — пачками, одним вызовом на вид детали
var fires: Array[Vector3] = []      # огонь жаровен и факелов (ночью светят)


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
	_mark_blocked(0.5)
	_yards()
	_pave_rect(Vector2(41.5, 61.0), 6.2, 7.6, Terrain.Kind.PLAZA)
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
	var w: int = p.get("w", 2)
	var axd := Vector2(facing.y, -facing.x)
	var fp := {"c": pos, "ax": axd, "hw": w * 1.25 + 0.02, "hd": 2.5 + 0.12}
	if not _fits(fp):
		return false
	footprints.append(fp)
	_house_seed += 1
	p["seed"] = _house_seed
	var y := terrain.height_at(pos.x, pos.y)
	var ang := atan2(facing.x, facing.y)      # +Z дома смотрит по facing
	var xf := Transform3D(Basis(Vector3.UP, ang), Vector3(pos.x, y, pos.y))
	var hb := SyntyHouse.new()
	hb.batch = batch
	hb.place = xf
	hb.build(p)
	if hb.interior:
		add_child(hb.interior)
	var rec := {"door": xf * hb.door, "smoke": [], "pos": pos, "lived": false, "face": facing}
	for sp in hb.smoke:
		rec["smoke"].append(_smoke(xf * sp))
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
	while t < to_t * len - 2.5:
		var w: int = [1, 2, 2, 2, 3][rng.randi() % 5]
		var fl: int = [1, 2, 2, 2, 3, 3][rng.randi() % 6]
		var p := {"w": w, "floors": fl, "roof": "flat" if rng.randf() < 0.25 else "gable",
			"shop": rng.randf() < 0.45, "beams": rng.randf() < 0.35}
		var c := a + dir * (t + w * 1.25) + nrm * (setback + 2.5)
		if _add_house(c, -nrm, p):
			t += w * 2.5 + (0.02 if rng.randf() < 0.75 else rng.randf_range(1.5, 3.0))
		else:
			t += 0.8

## Деталь Synty в точке pos земли, повёрнутая на yaw (масштаб s) — в общую пачку
func _sy(name: String, pos: Vector2, yaw: float, s := 1.0, lift := 0.0) -> void:
	var y := terrain.height_at(pos.x, pos.y) + lift
	batch.add(name, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), Vector3(pos.x, y, pos.y)))


func _town() -> void:
	var k := Kit.new()
	# ворота в скале (пока свои), из них выезжает повозка с новосёлами
	k.xf = Transform3D(Basis.IDENTITY, Vector3(Terrain.GATE.x, Terrain.TOWN_Y, Terrain.GATE.y - 0.4))
	for f in Props.gate(k):
		_light(k.xf * (f as Vector3), Color("ffa04a"), 6.0)
	var mi := MeshInstance3D.new()
	mi.mesh = k.mesh()
	mi.material_override = mat_props
	add_child(mi)
	var pc := Terrain.PLAZA_C
	# фонтан посреди площади, вокруг — скамьи и жаровни
	_sy("SM_Prop_Fountain_04", pc, 0.0, 1.25)
	_sy("SM_Prop_Fountain_04_Insert_01", pc, 0.0, 1.25)
	obstacles.append([pc, 2.6])
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		var bp := pc + Vector2(cos(a), sin(a)) * 3.6
		_sy("SM_Prop_Seat_Bench_01", bp, -a - PI / 2)
		obstacles.append([bp, 0.8])
		benches.append([bp, Vector2(cos(a), sin(a))])
	# храм на южной стороне площади, фасадом к фонтану; перед ним — статуи на постаментах
	var temple_p := Vector2(41.5, 55.6)
	var tt := SyntyTemple.new()
	tt.batch = batch
	var ts := 0.62
	tt.place = Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * ts), Vector3(temple_p.x, Terrain.TOWN_Y, temple_p.y))
	tt.build()
	for e in tt.extra:
		add_child(e)
	footprints.append({"c": temple_p + Vector2(0, 6.0), "ax": Vector2(1, 0), "hw": 5.2, "hd": 6.6, "noyard": true})
	var statues := ["SM_Prop_Statue_01", "SM_Prop_Statue_04", "SM_Prop_Statue_07", "SM_Prop_Statue_03"]
	for i in 4:
		var sp2: Vector2 = [Vector2(36.6, 53.2), Vector2(46.4, 53.2), Vector2(30.4, 40.0), Vector2(46.2, 40.6)][i]
		var face := (pc - sp2).normalized()
		_sy("SM_Prop_Plinth_02", sp2, 0.0)
		_sy(statues[i], sp2, atan2(face.x, face.y), 1.0, 0.45)
		obstacles.append([sp2, 0.8])
	_sy("SM_Prop_Sundial_01", Vector2(42.4, 38.8), 0.4)
	obstacles.append([Vector2(42.4, 38.8), 0.7])
	# рынок: столы с товаром под навесами, корзины, амфоры, повозка
	var stalls := [Vector2(33.4, 40.2), Vector2(43.4, 40.8), Vector2(33.2, 48.2), Vector2(44.0, 47.8)]
	var goods := ["SM_Prop_Basket_Set_01", "SM_Prop_Jar_Pile_01", "SM_Prop_Vase_Pile_02", "SM_Prop_Sack_Stack_01", "SM_Prop_Basket_01", "SM_Prop_Jar_01"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in stalls.size():
		var sp: Vector2 = stalls[i]
		var face := (pc - sp).normalized()
		var yaw := atan2(face.x, face.y)
		_sy("SM_Prop_Table_0%d" % (1 + i % 3), sp, yaw)
		var side := Vector2(face.y, -face.x)
		for kk in 3:
			_sy(goods[rng.randi() % goods.size()], sp - face * 0.9 + side * (kk - 1) * 0.7, yaw + rng.randf())
		obstacles.append([sp, 1.4])
		stall_spots.append([sp + face * 1.6, -face])
	_sy("SM_Prop_Cart_01", Vector2(29.8, 46.6), 1.2)
	obstacles.append([Vector2(29.8, 46.6), 1.6])
	# жаровни по краю площади и вдоль дороги от ворот — ночью горят
	var lamp_pts := []
	for i in 8:
		var a := TAU * i / 8.0 + 0.2
		lamp_pts.append(pc + Vector2(cos(a), sin(a)) * (terrain.plaza_r(pc + Vector2(cos(a), sin(a))) - 0.7))
	for zz: float in [20.0, 27.0, 33.0]:
		lamp_pts.append(Vector2(41.9, zz))
	for lp in lamp_pts:
		var p2: Vector2 = lp
		_sy("SM_Prop_Brazier_03", p2, 0.0)
		obstacles.append([p2, 0.4])
		lamps.append(_light(Vector3(p2.x, terrain.height_at(p2.x, p2.y) + 1.1, p2.y), Color("ffb060"), 7.0))
	# кипарисы вдоль дороги от ворот
	for i in 6:
		var tp := Vector2(37.0 + (i % 2) * 6.0, 20.0 + int(i / 2) * 5.5)
		_sy("SM_Env_Tree_Thin_0%d" % (1 + i % 2), tp, i * 1.3, 0.9)
	# дома вокруг площади — сплошным рядом вдоль её края, фасадом к фонтану; выходы улиц свободны
	rng.seed = 4
	var a := 0.0
	while a < TAU:
		var w: int = [1, 2, 2][rng.randi() % 3]
		var dirv := Vector2(cos(a), sin(a))
		var edge := pc + dirv * (terrain.plaza_r(pc + dirv) + 0.4)
		var da := (w * 2.5 + 0.1) / edge.distance_to(pc)
		var mid := a + da * 0.5
		var dm := Vector2(cos(mid), sin(mid))
		var fl: int = [2, 2, 3][rng.randi() % 3]
		var em := pc + dm * (terrain.plaza_r(pc + dm) + 0.4)
		_add_house(em + dm * 2.5, -dm, {"w": w, "floors": fl, "roof": "flat" if rng.randf() < 0.25 else "gable", "shop": rng.randf() < 0.75, "beams": rng.randf() < 0.3})
		a += da
	_row(Vector2(30, 44.5), Vector2(14, 46.5), 1.0, 1.7)
	_row(Vector2(30, 44.5), Vector2(14, 46.5), -1.0, 1.7)
	_row(Vector2(46.5, 45.7), Vector2(60, 48.5), 1.0, 1.7)
	_row(Vector2(46.5, 45.7), Vector2(60, 48.5), -1.0, 1.7)
	_row(Vector2(38.4, 35.5), Vector2(40.0, 23.0), 1.0, 2.4, 0.0, 0.85)
	_row(Vector2(38.4, 35.5), Vector2(40.0, 23.0), -1.0, 2.4, 0.0, 0.85)

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
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for n in 2600:
		var x := rng.randf_range(1.0, 79.0)
		var z := rng.randf_range(1.0, 79.0)
		if not _free_spot(x, z):
			continue
		var y := terrain.height_at(x, z)
		var town := Vector2(x, z).distance_to(Vector2(38, 46))
		var hill := clampf((y - Terrain.TOWN_Y) / 6.0, 0.0, 1.0)
		var r := rng.randf()
		if town < 22.0 and r < 0.55:
			continue                                   # в городе природы меньше
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.6, 0.9)), Vector3(x, y, z))
		if r < 0.03 + hill * 0.04:
			batch.add("SM_Env_Tree_0%d" % (1 + rng.randi() % 4), xf)
		elif r < 0.09 + hill * 0.07:
			batch.add("SM_Env_Tree_Thin_0%d" % (1 + rng.randi() % 2), xf)
		elif r < 0.11 and x > 55.0:
			batch.add("SM_Env_Tree_Palm_0%d" % (1 + rng.randi() % 3), xf)
		elif r < 0.2:
			batch.add("SM_Env_Tree_Bush_0%d" % (1 + rng.randi() % 3), xf)
		elif r < 0.3:
			batch.add("SM_Env_Garden_Plants_0%d" % (1 + rng.randi() % 7), xf)
		elif r < 0.42:
			batch.add("SM_Env_Flowers_0%d" % (1 + rng.randi() % 5), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(x, y, z)))
		elif r < 0.46 and hill > 0.2:
			batch.add("SM_Env_Rock_Cliff_0%d" % (1 + rng.randi() % 2), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.08, 0.18)), Vector3(x, y - 0.2, z)))
	var n_inst := batch.build(self)
	print("SYNTY instances ", n_inst, " groups ", batch.groups.size())
