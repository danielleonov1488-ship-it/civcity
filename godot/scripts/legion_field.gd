class_name LegionField
extends RefCounted
## Поле боя Легиона (legion_battle.gd): маленькая уютная диорама для каждой области похода — земля с тропой вдоль
## поля, за полем холмы, деревья, камни и приметы области (лагерь разбойников, медвежья пещера, менгиры галлов,
## болото с камышом, стены Лабиринта, скалы у моря, оазис и шатры Карфагена, врата Аида с огнями), свой свет,
## небо, туман и цвет кадра — тот же тёплый «игрушечный» вид, что в городе.
##
## Поле: ось x — вдоль боя (наши слева), z — поперёк, камера смотрит с +z. Бой идёт в полосе |z| < 3,5,
## x от −12 до 16 — там ничего не ставим (только низкая трава). Всё строится кодом из моделей Synty и Artisau.
##
## build(root, biome, seed, quality) → {env, sun, grade: {параметры grade.gdshader}, lights: [OmniLight3D с мерцанием],
## height: Callable(x, z) → высота земли}; tick(info, t) — мерцание огней.

## Области: цвета земли (4 оттенка травы, тропа, склоны), холмы (высота позади поля, по бокам), свет и туман, цвет кадра
const BIOMES := {
	"forest": {"g": ["4f6326", "5a6d2a", "667a31", "728336"], "path": "93714a", "dirt": "5e4a32", "path_half": 2.7,
		"back_h": 7.0, "side_h": 3.0, "bumps": 0.6,
		"sun": "ffe4c0", "sun_e": 2.5, "elev": 40.0, "amb": "c2c0d0", "amb_e": 0.55,
		"sky_top": "79a3cf", "sky_hor": "f0dcb8", "fog": "e2d6b8", "fog_d": 0.0035,
		"grade": {"gain": Vector3(1.07, 0.97, 0.84), "shadow_tint": Vector3(0.86, 0.84, 0.95), "green_shift": 0.55, "sat": 1.0, "contrast": 1.12, "tint": Vector3.ONE},
		"fx": "pollen", "birds": true},
	"hills": {"g": ["6a6a2c", "767630", "848036", "918a3c"], "path": "9a7a4c", "dirt": "7a5e3c", "path_half": 2.5,
		"back_h": 11.0, "side_h": 5.0, "bumps": 1.1,
		"sun": "ffe0b4", "sun_e": 2.6, "elev": 36.0, "amb": "c8c0c4", "amb_e": 0.55,
		"sky_top": "7fa6cc", "sky_hor": "f2d8ac", "fog": "e8d2a8", "fog_d": 0.0035,
		"grade": {"gain": Vector3(1.08, 0.97, 0.82), "shadow_tint": Vector3(0.87, 0.84, 0.94), "green_shift": 0.65, "sat": 0.98, "contrast": 1.12, "tint": Vector3.ONE},
		"fx": "pollen", "birds": true},
	"darkforest": {"g": ["2f4a26", "37522a", "40592e", "4a6232"], "path": "6e5638", "dirt": "3e3226", "path_half": 2.4,
		"back_h": 6.0, "side_h": 3.0, "bumps": 0.5,
		"sun": "f6dcb0", "sun_e": 1.9, "elev": 34.0, "amb": "9aa8c0", "amb_e": 0.6,
		"sky_top": "6f8cac", "sky_hor": "c8ccb8", "fog": "a8b4a4", "fog_d": 0.009, "fog_near": 26.0, "fog_far": 95.0, "fog_k": 0.85,
		"grade": {"gain": Vector3(1.04, 1.0, 0.9), "shadow_tint": Vector3(0.84, 0.88, 0.96), "green_shift": 0.35, "sat": 0.95, "contrast": 1.1, "tint": Vector3(0.98, 1.0, 1.02)},
		"fx": "fireflies"},
	"swamp": {"g": ["4a4e2a", "52562c", "5c5e30", "666634"], "path": "6a5a3c", "dirt": "40362a", "path_half": 2.3,
		"back_h": 3.0, "side_h": 1.5, "bumps": 0.35, "mud": 1.0,
		"sun": "eadcb8", "sun_e": 1.8, "elev": 30.0, "amb": "a4acb4", "amb_e": 0.62,
		"sky_top": "8496a6", "sky_hor": "c8c8b0", "fog": "b4b8a0", "fog_d": 0.012, "fog_near": 22.0, "fog_far": 80.0, "fog_k": 0.9,
		"grade": {"gain": Vector3(1.03, 1.0, 0.9), "shadow_tint": Vector3(0.86, 0.9, 0.94), "green_shift": 0.3, "sat": 0.9, "contrast": 1.08, "tint": Vector3(1.0, 1.0, 0.98)},
		"fx": "mist"},
	"labyrinth": {"g": ["626a32", "6c7236", "767a3c", "807f42"], "path": "9c8c70", "dirt": "7a6850", "path_half": 3.2, "tiles": 1.0,
		"back_h": 4.0, "side_h": 2.0, "bumps": 0.4,
		"sun": "fff0d0", "sun_e": 2.4, "elev": 40.0, "amb": "b8b8cc", "amb_e": 0.5,
		"sky_top": "6f9fd6", "sky_hor": "f2e2c4", "fog": "eadcc0", "fog_d": 0.003,
		"grade": {"gain": Vector3(1.07, 0.98, 0.86), "shadow_tint": Vector3(0.86, 0.84, 0.96), "green_shift": 0.6, "sat": 1.0, "contrast": 1.12, "tint": Vector3.ONE},
		"fx": "dust"},
	"rocks": {"g": ["7a7448", "84804e", "8e8854", "9a9258"], "path": "a89068", "dirt": "7e7464", "path_half": 2.8,
		"back_h": 14.0, "side_h": 6.0, "bumps": 1.3, "sea": true,
		"sun": "ffe8c8", "sun_e": 2.6, "elev": 40.0, "amb": "c0c8d8", "amb_e": 0.58,
		"sky_top": "6a9cd2", "sky_hor": "eedcc0", "fog": "dcd6c8", "fog_d": 0.003,
		"grade": {"gain": Vector3(1.06, 0.98, 0.88), "shadow_tint": Vector3(0.85, 0.86, 0.96), "green_shift": 0.6, "sat": 1.0, "contrast": 1.12, "tint": Vector3.ONE},
		"fx": "dust", "birds": true},
	"desert": {"g": ["b48e56", "bc965c", "c49e62", "cca66a"], "path": "a07a48", "dirt": "9a7a50", "path_half": 2.6, "dunes": 1.0,
		"back_h": 5.0, "side_h": 2.5, "bumps": 0.9,
		"sun": "ffe2b0", "sun_e": 2.3, "elev": 46.0, "amb": "c8b8b8", "amb_e": 0.5,
		"sky_top": "7aa8d8", "sky_hor": "f6deb4", "fog": "f0d8b0", "fog_d": 0.0035,
		"grade": {"gain": Vector3(1.08, 0.97, 0.84), "shadow_tint": Vector3(0.88, 0.84, 0.94), "green_shift": 0.7, "sat": 0.98, "contrast": 1.12, "tint": Vector3.ONE},
		"fx": "sand"},
	"hades": {"g": ["3a3238", "41383e", "4a4044", "52474a"], "path": "5e4c48", "dirt": "2e2628", "path_half": 2.6, "cracks": 1.0,
		"back_h": 9.0, "side_h": 4.0, "bumps": 1.0,
		"sun": "ffb894", "sun_e": 1.7, "elev": 30.0, "amb": "a090c0", "amb_e": 0.7,
		"sky_top": "3a2e58", "sky_hor": "a85a5a", "fog": "6a4a64", "fog_d": 0.01, "fog_near": 28.0, "fog_far": 100.0, "fog_k": 0.85,
		"grade": {"gain": Vector3(1.05, 0.94, 0.9), "shadow_tint": Vector3(0.9, 0.84, 1.0), "green_shift": 0.2, "sat": 1.05, "contrast": 1.1, "tint": Vector3(1.04, 0.95, 1.08)},
		"fx": "embers"},
}

const LANE_Z := 3.6                      # полоса боя: здесь ничего не ставим
const LANE_X := Vector2(-13.0, 17.0)

static var _soft: Texture2D


## Строит поле под root. Возвращает данные для боя (свет, туман, цвет кадра, высота земли)
static func build(root: Node3D, biome: String, seed_v: int, quality := "high") -> Dictionary:
	Synty._index()
	var B: Dictionary = BIOMES.get(biome, BIOMES["forest"])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var noise := FastNoiseLite.new()
	noise.seed = seed_v
	noise.frequency = 0.045
	noise.fractal_octaves = 3
	var hfun := func(x: float, z: float) -> float: return _height(B, noise, x, z)
	var info := {"biome": biome, "lights": [], "height": hfun, "grade": B["grade"], "nodes": []}
	_ground(root, B, hfun)
	_environment(root, B, info, quality)
	var batch := SyntyBatch.new()
	match biome:
		"forest": _forest(root, batch, rng, hfun, info)
		"hills": _hills(root, batch, rng, hfun, info)
		"darkforest": _darkforest(root, batch, rng, hfun, info)
		"swamp": _swamp(root, batch, rng, hfun, info)
		"labyrinth": _labyrinth(root, batch, rng, hfun, info)
		"rocks": _rocks(root, batch, rng, hfun, info)
		"desert": _desert(root, batch, rng, hfun, info)
		"hades": _hades(root, batch, rng, hfun, info)
	batch.build(root, quality != "low")
	_ambient(root, String(B.get("fx", "")), info)
	if bool(B.get("birds", false)):
		var birds := Birds.new()
		birds.center = Vector3(2.0, 0.0, -16.0)
		root.add_child(birds)
	return info


## Мерцание огней (костры, жаровни, огни Аида)
static func tick(info: Dictionary, t: float) -> void:
	for l: OmniLight3D in info.get("lights", []):
		if is_instance_valid(l):
			var k: float = l.get_meta("e", 1.0)
			var ph: float = l.get_meta("ph", 0.0)
			l.light_energy = k * (0.85 + 0.1 * sin(t * 7.3 + ph) + 0.06 * sin(t * 13.1 + ph * 2.0))


# =====================================================================
#   земля
# =====================================================================

## Высота земли: в полосе боя ровно, позади поднимаются холмы, по бокам тоже; впереди чуть ниже
static func _height(B: Dictionary, noise: FastNoiseLite, x: float, z: float) -> float:
	var n := noise.get_noise_2d(x, z) * 0.5 + 0.5
	var back := smoothstep(-5.0, -34.0, z)
	var side := smoothstep(20.0, 42.0, absf(x - 2.0))
	var h := back * float(B["back_h"]) * (0.45 + 0.9 * n) + side * float(B["side_h"]) * (0.4 + 0.8 * n)
	# мелкие бугры вне полосы боя
	var lane := 1.0 - smoothstep(LANE_Z, LANE_Z + 3.0, absf(z))
	h += (n - 0.5) * float(B["bumps"]) * (1.0 - lane)
	# впереди земля чуть уходит вниз (кадр как с холма)
	h -= smoothstep(6.0, 22.0, z) * 0.8
	if bool(B.get("sea", false)):
		# у моря: справа и позади берег уходит под воду (уровень моря −0,8), слева — скалы
		var shore := smoothstep(-6.5, -16.0, z)
		var cliffs := smoothstep(2.0, -16.0, x)
		h = lerpf(-2.4 * shore + (n - 0.5) * 0.4 * shore, h, cliffs)
	return h


static func _ground(root: Node3D, B: Dictionary, hfun: Callable) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x0 := -70.0
	var x1 := 74.0
	var z0 := -80.0
	var z1 := 28.0
	var step := 1.0
	var nx := int((x1 - x0) / step) + 1
	var nz := int((z1 - z0) / step) + 1
	for j in nz:
		for i in nx:
			var x := x0 + i * step
			var z := z0 + j * step
			# вдали — крупнее шаг не нужен: сетка и так лёгкая (~15 тыс. треугольников)
			st.add_vertex(Vector3(x, hfun.call(x, z), z))
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			var b := a + 1
			var c := a + nx
			var d := c + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(b)
			st.add_index(d)
			st.add_index(c)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/battle_ground.gdshader")
	var g: Array = B["g"]
	sm.set_shader_parameter("g0", Color(String(g[0])))
	sm.set_shader_parameter("g1", Color(String(g[1])))
	sm.set_shader_parameter("g2", Color(String(g[2])))
	sm.set_shader_parameter("g3", Color(String(g[3])))
	sm.set_shader_parameter("path_col", Color(String(B["path"])))
	sm.set_shader_parameter("dirt_col", Color(String(B["dirt"])))
	sm.set_shader_parameter("path_half", float(B.get("path_half", 2.6)))
	sm.set_shader_parameter("mud", float(B.get("mud", 0.0)))
	sm.set_shader_parameter("cracks", float(B.get("cracks", 0.0)))
	sm.set_shader_parameter("tiles", float(B.get("tiles", 0.0)))
	sm.set_shader_parameter("dunes", float(B.get("dunes", 0.0)))
	mi.material_override = sm
	mi.name = "Ground"
	root.add_child(mi)


# =====================================================================
#   свет, небо, туман
# =====================================================================

static func _environment(root: Node3D, B: Dictionary, info: Dictionary, quality: String) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(String(B["sky_top"]))
	sm.sky_horizon_color = Color(String(B["sky_hor"]))
	sm.ground_horizon_color = Color(String(B["sky_hor"])).darkened(0.1)
	sm.ground_bottom_color = Color(String(B["dirt"]))
	sm.sun_angle_max = 25.0
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(String(B["amb"]))
	env.ambient_light_energy = float(B["amb_e"])
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.tonemap_exposure = 1.1
	env.ssao_enabled = quality != "low"
	env.ssao_radius = 0.8
	env.ssao_intensity = 2.5
	env.ssao_power = 1.5
	env.ssao_detail = 0.8
	env.ssao_light_affect = 0.3
	env.glow_enabled = quality != "low"
	env.glow_intensity = 0.55
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(String(B["fog"]))
	# туман только вдали: ближе fog_near (м) воздух прозрачный, к fog_far — плотность fog_k
	env.fog_depth_begin = float(B.get("fog_near", 42.0))
	env.fog_depth_end = float(B.get("fog_far", 150.0))
	env.fog_depth_curve = 1.3
	env.fog_density = float(B.get("fog_k", 0.75))
	env.fog_aerial_perspective = 0.2
	env.fog_sky_affect = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 70.0
	sun.light_angular_distance = 2.0
	sun.shadow_blur = 1.5
	sun.light_color = Color(String(B["sun"]))
	sun.light_energy = float(B["sun_e"])
	var elev := deg_to_rad(float(B["elev"]))
	# солнце справа и чуть спереди, как в городе: лица освещены, тени ложатся влево и назад
	var flat := Vector3(1.0, 0.0, 0.55).normalized()
	var dir := (flat * cos(elev) + Vector3.UP * sin(elev)).normalized()
	root.add_child(sun)
	sun.look_at_from_position(dir * 60.0, Vector3.ZERO, Vector3.UP)
	info["env"] = env
	info["sun"] = sun


# =====================================================================
#   расстановка
# =====================================================================

## Случайная точка вне полосы боя: позади (back), впереди (front) или по бокам (side)
static func _spot(rng: RandomNumberGenerator, zone: String) -> Vector2:
	match zone:
		"back":
			return Vector2(rng.randf_range(-36.0, 42.0), rng.randf_range(-48.0, -5.5))
		"near_back":
			return Vector2(rng.randf_range(-22.0, 28.0), rng.randf_range(-11.0, -4.6))
		"front":
			return Vector2(rng.randf_range(-20.0, 26.0), rng.randf_range(5.0, 11.0))
		"side":
			var left := rng.randf() < 0.5
			return Vector2(rng.randf_range(-34.0, -15.0) if left else rng.randf_range(19.0, 40.0), rng.randf_range(-8.0, 6.0))
		"far":
			return Vector2(rng.randf_range(-60.0, 66.0), rng.randf_range(-75.0, -40.0))
		"grove":
			return Vector2(rng.randf_range(-26.0, 32.0), rng.randf_range(-16.0, -6.8))
		"deep":
			return Vector2(rng.randf_range(-40.0, 46.0), rng.randf_range(-50.0, -15.0))
	return Vector2.ZERO


## Много моделей Synty одной пачкой: names — из каких выбирать, zone — где, s — размер [мин, макс]
static func _scatter(batch: SyntyBatch, rng: RandomNumberGenerator, hfun: Callable, names: Array, n: int, zone: String, s: Vector2, remap := {}, keep_out := Rect2()) -> void:
	for i in n:
		var p := _spot(rng, zone)
		if keep_out.has_area() and keep_out.has_point(p):
			p = _spot(rng, zone)
			if keep_out.has_point(p):
				continue
		var nm: String = names[rng.randi() % names.size()]
		var y: float = hfun.call(p.x, p.y)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(s.x, s.y)), Vector3(p.x, y - 0.05, p.y))
		batch.add(nm, xf, remap)


## Одна модель Synty в точке
static func _put(root: Node3D, name: String, p: Vector2, hfun: Callable, yaw := 0.0, s := 1.0, remap := {}) -> Node3D:
	var n := Synty.make(name, remap)
	n.position = Vector3(p.x, hfun.call(p.x, p.y), p.y)
	n.rotation.y = yaw
	n.scale = Vector3.ONE * s
	root.add_child(n)
	return n


## Модель Artisau высотой h (м) в точке
static func _art(root: Node3D, name: String, p: Vector2, hfun: Callable, h: float, yaw := 0.0) -> Node3D:
	var n := Artisau.make(name, h)
	n.position = Vector3(p.x, hfun.call(p.x, p.y) - 0.03, p.y)
	n.rotation.y = yaw
	root.add_child(n)
	return n


## Мелочь Kit (камни, кочки) одной сеткой: MultiMesh
static func _kit_many(root: Node3D, rng: RandomNumberGenerator, hfun: Callable, mesh_name: String, n: int, zone: String, s: Vector2) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = LegionFighter._kit_mesh(mesh_name)
	mm.instance_count = n
	for i in n:
		var p := _spot(rng, zone)
		var sc := rng.randf_range(s.x, s.y)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.7, 1.1), sc))
		mm.set_instance_transform(i, Transform3D(b, Vector3(p.x, hfun.call(p.x, p.y) + 0.02, p.y)))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	root.add_child(mi)


## Лужа или пруд: плоская неровная капля с блестящей тёмной водой (без глубины — вода города здесь не нужна)
static func _pool(root: Node3D, c: Vector2, sz: Vector2, hfun: Callable, col: Color, seed_v := 1, glow := Color(0, 0, 0, 0)) -> void:
	var k := Kit.new()
	k.blob(Vector3.ZERO, Vector3(sz.x * 0.5, 0.04, sz.y * 0.5), col, seed_v, 0.12)
	var mi := MeshInstance3D.new()
	mi.mesh = k.mesh()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.06
	m.metallic = 0.2
	m.metallic_specular = 0.9
	if glow.a > 0.0:
		m.emission_enabled = true
		m.emission = glow
		m.emission_energy_multiplier = 0.6
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(c.x, hfun.call(c.x, c.y) + 0.015, c.y)
	root.add_child(mi)


## Огонь: тёплый (или голубой) свет с мерцанием и язычки пламени
static func _fire(root: Node3D, at: Vector3, info: Dictionary, col := Color(1.0, 0.62, 0.3), energy := 2.2, rng_range := 7.0, size := 1.0) -> void:
	var l := OmniLight3D.new()
	l.position = at + Vector3(0, 0.5, 0)
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng_range
	l.shadow_enabled = false
	l.set_meta("e", energy)
	l.set_meta("ph", at.x * 1.7 + at.z)
	root.add_child(l)
	info["lights"].append(l)
	var p := GPUParticles3D.new()
	p.amount = 18
	p.lifetime = 0.9
	p.position = at
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.5 * size
	pm.initial_velocity_max = 1.0 * size
	pm.gravity = Vector3(0, 0.6, 0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.18 * size
	pm.scale_min = 0.5
	pm.scale_max = 0.9
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.7))
	sc.add_point(Vector2(0.4, 1.0))
	sc.add_point(Vector2(1, 0.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var grad := Gradient.new()
	grad.set_color(0, Color(col.r * 1.2, col.g * 1.1, col.b, 1.0))
	grad.set_color(1, Color(col.r, col.g * 0.5, col.b * 0.4, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	p.draw_pass_1 = _quad(0.32 * size, true)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(p)


## Дымок (костёр)
static func _smoke(root: Node3D, at: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 10
	p.lifetime = 4.5
	p.preprocess = 4.0
	p.position = at
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.3, 1, 0.1)
	pm.spread = 10.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3(0.15, 0.05, 0.0)
	pm.scale_min = 0.5
	pm.scale_max = 0.8
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.5))
	sc.add_point(Vector2(1, 2.4))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var grad := Gradient.new()
	grad.set_color(0, Color(0.86, 0.84, 0.82, 0.35))
	grad.set_color(1, Color(0.8, 0.8, 0.8, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	p.draw_pass_1 = _quad(0.9, false)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(p)


## Мягкое круглое пятнышко (частицы)
static func soft_tex() -> Texture2D:
	if _soft == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var d := Vector2(x - 31.5, y - 31.5).length() / 31.5
				var a := clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a * (3.0 - 2.0 * a)))
		_soft = ImageTexture.create_from_image(img)
	return _soft


## Квадрат-частица, повёрнутый к камере; glow — светится (огонь, искры, светлячки)
static func _quad(size: float, glow: bool, soft := 0.0) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	if soft > 0.0:
		m.proximity_fade_enabled = true
		m.proximity_fade_distance = soft
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = soft_tex()
	m.disable_receive_shadows = true
	if glow:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	q.material = m
	return q


## Жизнь в воздухе: пыльца, светлячки, туман, пыль, песок, искры
static func _ambient(root: Node3D, kind: String, info: Dictionary) -> void:
	if kind == "":
		return
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p.visibility_aabb = AABB(Vector3(-40, -5, -40), Vector3(80, 25, 60))
	var col_a := Color(1, 1, 1, 0.6)
	var col_b := Color(1, 1, 1, 0.0)
	var size := 0.06
	var glow := false
	match kind:
		"pollen", "dust":
			p.amount = 90
			p.lifetime = 8.0
			pm.emission_box_extents = Vector3(22, 2.5, 9)
			p.position = Vector3(2, 2.2, -3)
			pm.gravity = Vector3(0.05, -0.01, 0.0)
			pm.initial_velocity_min = 0.05
			pm.initial_velocity_max = 0.2
			pm.spread = 180.0
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 0.4
			col_a = Color(1.0, 0.96, 0.82, 0.55) if kind == "pollen" else Color(1.0, 0.94, 0.85, 0.35)
			size = 0.07
			glow = kind == "pollen"
		"fireflies":
			p.amount = 60
			p.lifetime = 6.0
			pm.emission_box_extents = Vector3(22, 1.6, 9)
			p.position = Vector3(2, 1.5, -4)
			pm.gravity = Vector3.ZERO
			pm.initial_velocity_min = 0.1
			pm.initial_velocity_max = 0.3
			pm.spread = 180.0
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 0.8
			col_a = Color(0.85, 1.0, 0.45, 0.9)
			size = 0.1
			glow = true
		"mist":
			p.amount = 26
			p.lifetime = 14.0
			p.preprocess = 14.0
			pm.emission_box_extents = Vector3(28, 0.3, 12)
			p.position = Vector3(2, 0.5, -6)
			pm.direction = Vector3(1, 0, 0)
			pm.spread = 10.0
			pm.initial_velocity_min = 0.15
			pm.initial_velocity_max = 0.3
			pm.gravity = Vector3.ZERO
			col_a = Color(0.9, 0.94, 0.88, 0.12)
			size = 5.0
		"sand":
			p.amount = 120
			p.lifetime = 3.0
			pm.emission_box_extents = Vector3(4, 0.6, 9)
			p.position = Vector3(-22, 0.6, -1)
			pm.direction = Vector3(1, 0.05, 0)
			pm.spread = 4.0
			pm.initial_velocity_min = 9.0
			pm.initial_velocity_max = 14.0
			pm.gravity = Vector3(0, -0.4, 0)
			col_a = Color(0.95, 0.85, 0.65, 0.28)
			size = 0.1
		"embers":
			p.amount = 110
			p.lifetime = 5.0
			pm.emission_box_extents = Vector3(24, 0.2, 10)
			p.position = Vector3(2, 0.1, -4)
			pm.direction = Vector3(0, 1, 0)
			pm.spread = 25.0
			pm.initial_velocity_min = 0.4
			pm.initial_velocity_max = 1.1
			pm.gravity = Vector3(0.1, 0.15, 0.0)
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 0.6
			col_a = Color(1.0, 0.55, 0.2, 1.0)
			size = 0.07
			glow = true
	p.preprocess = maxf(p.preprocess, p.lifetime)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	grad.colors = PackedColorArray([col_b, col_a, col_a, col_b])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	p.draw_pass_1 = _quad(size, glow, 1.6 if kind == "mist" else 0.0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(p)
	info["nodes"].append(p)


# =====================================================================
#   области
# =====================================================================

const TREES := ["SM_Env_Tree_01", "SM_Env_Tree_02", "SM_Env_Tree_03", "SM_Env_Tree_04"]
const BUSHES := ["SM_Env_Bush_Cluster_04", "SM_Env_Bush_Cluster_05", "SM_Env_Bush_Cluster_05"]
const FLOWER_BUSHES := ["SM_Env_Garden_Plants_01", "SM_Env_Garden_Plants_02", "SM_Env_Garden_Plants_04", "SM_Env_Garden_Plants_06", "SM_Env_Garden_Plants_07"]
const PALMS_LOW := ["SM_Env_Tree_Bush_01", "SM_Env_Tree_Bush_02", "SM_Env_Tree_Bush_03"]
const GRASS := ["SM_Env_Grass_01", "SM_Env_Grass_03", "SM_Env_Grass_01"]
const GRASS_BIG := ["SM_Env_Grass_02"]
const FLOWERS := ["SM_Env_Flowers_01", "SM_Env_Flowers_02", "SM_Env_Flowers_03", "SM_Env_Flowers_04", "SM_Env_Flowers_05"]
const PEBBLES := ["SM_Env_Pebbles_01", "SM_Env_Pebbles_02", "SM_Env_Pebbles_03"]


## Общая трава и мелочь у полосы боя (впереди — размыто, рамка кадра)
static func _meadow(batch: SyntyBatch, rng: RandomNumberGenerator, hfun: Callable, grass := 1.0, flowers := 1.0, remap := {}) -> void:
	_scatter(batch, rng, hfun, GRASS, int(70 * grass), "near_back", Vector2(0.6, 0.95), remap)
	_scatter(batch, rng, hfun, GRASS, int(30 * grass), "front", Vector2(0.6, 0.9), remap)
	_scatter(batch, rng, hfun, GRASS, int(50 * grass), "back", Vector2(0.8, 1.2), remap)
	_scatter(batch, rng, hfun, GRASS_BIG, int(14 * grass), "back", Vector2(0.5, 0.8), remap)
	if flowers > 0.0:
		_scatter(batch, rng, hfun, FLOWERS, int(26 * flowers), "near_back", Vector2(0.7, 1.0))
		_scatter(batch, rng, hfun, FLOWERS, int(14 * flowers), "front", Vector2(0.8, 1.1))


## Лес разбойников: светлый лес, тропа, лагерь шайки справа (палатки, костёр, бревна)
static func _forest(root: Node3D, batch: SyntyBatch, rng: RandomNumberGenerator, hfun: Callable, info: Dictionary) -> void:
	_meadow(batch, rng, hfun)
	var camp := Rect2(7.0, -15.0, 15.0, 10.0)
	_scatter(batch, rng, hfun, TREES, 46, "back", Vector2(0.62, 0.85), {}, camp)
	_scatter(batch, rng, hfun, TREES, 14, "grove", Vector2(0.5, 0.68), {}, camp)
	_scatter(batch, rng, hfun, ["SM_Env_Tree_Large_01", "SM_Env_Tree_Cluster_01", "SM_Env_Tree_Cluster_03"], 12, "far", Vector2(0.7, 0.9))
	_scatter(batch, rng, hfun, TREES, 12, "side", Vector2(0.6, 0.8))
	_scatter(batch, rng, hfun, BUSHES, 16, "near_back", Vector2(0.28, 0.42), {}, camp)
	_scatter(batch, rng, hfun, BUSHES, 10, "grove", Vector2(0.35, 0.5), {}, camp)
	_scatter(batch, rng, hfun, FLOWER_BUSHES, 14, "near_back", Vector2(0.8, 1.1), {}, camp)
	_scatter(batch, rng, hfun, FLOWER_BUSHES, 6, "front", Vector2(0.8, 1.1))
	_scatter(batch, rng, hfun, PEBBLES, 8, "near_back", Vector2(0.6, 0.9))
	for i in 5:
		var lp := _spot(rng, "grove")
		if not camp.has_point(lp):
			_art(root, "Log", lp, hfun, 0.32, rng.randf() * TAU)
	for i in 8:
		var mp := _spot(rng, "near_back")
		if not camp.has_point(mp):
			_art(root, "Mushroom", mp, hfun, rng.randf_range(0.18, 0.3), rng.randf() * TAU)
	# лагерь разбойников — справа позади поля, со стороны врага
	var cx := 14.0
	var cz := -8.5
	_art(root, "Small_Tent", Vector2(cx + 2.5, cz - 1.5), hfun, 2.2, -0.4)
	_art(root, "Small_Tent", Vector2(cx - 2.2, cz - 2.6), hfun, 2.0, 0.5)
	var fire := Vector2(cx, cz + 0.8)
	_art(root, "Campfire", fire, hfun, 0.9, 0.3)
	var fy: float = hfun.call(fire.x, fire.y)
	_fire(root, Vector3(fire.x, fy + 0.15, fire.y), info, Color(1.0, 0.62, 0.3), 2.4, 8.0)
	_smoke(root, Vector3(fire.x, fy + 1.0, fire.y))
	_art(root, "Log", Vector2(cx - 1.3, cz + 1.5), hfun, 0.35, 1.2)
	_art(root, "Log", Vector2(cx + 1.4, cz + 1.9), hfun, 0.35, -0.3)
	_put(root, "SM_Prop_Sack_Stack_01", Vector2(cx + 3.4, cz + 0.6), hfun, 0.4, 0.8)
	_put(root, "SM_Prop_Basket_Set_01", Vector2(cx - 3.2, cz + 0.4), hfun, 1.0, 0.8)
	_put(root, "SM_Prop_Weapon_Rack_02", Vector2(cx + 0.8, cz - 3.4), hfun, 0.1, 0.8)
	# наш край: значок легиона и палатка за спиной отряда
	_ours(root, hfun, info)


## Наш тыл: значок легиона, палатка, корзина стрел (за спиной отряда, слева позади)
static func _ours(root: Node3D, hfun: Callable, info: Dictionary, tent := true) -> void:
	var std := MeshInstance3D.new()
	std.mesh = CatMilitary.kit_mesh("#mil_standard")
	var p := Vector2(-11.2, -4.6)
	std.position = Vector3(p.x, hfun.call(p.x, p.y), p.y)
	std.rotation.y = 0.5
	std.scale = Vector3.ONE * 0.9
	root.add_child(std)
	if tent:
		var t := MeshInstance3D.new()
		t.mesh = CatMilitary.kit_mesh("#mil_tent")
		var tp := Vector2(-14.5, -7.2)
		t.position = Vector3(tp.x, hfun.call(tp.x, tp.y), tp.y)
		t.rotation.y = 0.7
		root.add_child(t)
	var q := MeshInstance3D.new()
	q.mesh = CatMilitary.kit_mesh("#mil_quiver")
	var qp := Vector2(-12.6, -5.2)
	q.position = Vector3(qp.x, hfun.call(qp.x, qp.y), qp.y)
	root.add_child(q)


## Дикие холмы: высокие травы, скалы, редкие деревья, пещера медведя справа
static func _hills(root: Node3D, batch: SyntyBatch, rng: RandomNumberGenerator, hfun: Callable, info: Dictionary) -> void:
	_meadow(batch, rng, hfun, 1.3, 0.6)
	_scatter(batch, rng, hfun, GRASS, 50, "grove", Vector2(1.0, 1.4), {"tint": Color(0.95, 0.85, 0.55)})
	_scatter(batch, rng, hfun, ["SM_Env_Tree_Thin_01", "SM_Env_Tree_Thin_02", "SM_Env_Tree_03"], 18, "back", Vector2(0.7, 1.0))
	var stone := {"tint": Color(0.78, 0.72, 0.62)}
	_scatter(batch, rng, hfun, ["SM_Env_Rock_Cliff_02", "SM_Env_Rock_Cliff_Layers_02"], 12, "deep", Vector2(0.5, 1.0), stone)
	_scatter(batch, rng, hfun, ["SM_Env_Rock_Cliff_02"], 6, "grove", Vector2(0.35, 0.55), stone, Rect2(9.0, -16.0, 12.0, 8.0))
	_scatter(batch, rng, hfun, ["SM_Env_Rock_Cliff_Layers_01", "SM_Env_Rock_Cliff_01"], 7, "far", Vector2(1.0, 1.5), stone)
	_scatter(batch, rng, hfun, BUSHES, 10, "near_back", Vector2(0.25, 0.4))
	_kit_many(root, rng, hfun, "#rock", 30, "near_back", Vector2(1.0, 2.6))
	_kit_many(root, rng, hfun, "#rock", 16, "front", Vector2(0.8, 1.8))
	# пещера: две скалы аркой и тёмный зев
	var c := Vector2(15.0, -12.0)
	_put(root, "SM_Env_Rock_Cliff_01", c + Vector2(-3.5, 0.0), hfun, 0.6, 0.55, stone)
	_put(root, "SM_Env_Rock_Cliff_01", c + Vector2(3.8, -0.6), hfun, 2.6, 0.55, stone)
	var mouth := MeshInstance3D.new()
	var k := Kit.new()
	k.blob(Vector3(0, 0.0, 0), Vector3(1.8, 1.7, 0.6), Color("1c1714"), 3, 0.12)
	mouth.mesh = k.mesh()
	mouth.material_override = Kit.material()
	mouth.position = Vector3(c.x, hfun.call(c.x, c.y) + 0.4, c.y + 0.6)
	root.add_child(mouth)
	_art(root, "Log", c + Vector2(1.0, 2.6), hfun, 0.35, 0.8)
	_ours(root, hfun, info)


## Галльская чаща: тёмный густой лес, менгиры кругом, частокол деревни, папоротники и грибы
static func _darkforest(root: Node3D, batch: SyntyBatch, rng: RandomNumberGenerator, hfun: Callable, info: Dictionary) -> void:
	var dark := {"tint": Color(0.62, 0.74, 0.58)}
	_meadow(batch, rng, hfun, 1.0, 0.25, dark)
	_scatter(batch, rng, hfun, ["SM_Env_Tree_Large_01", "SM_Env_Tree_Large_02", "SM_Env_Tree_Large_03", "SM_Env_Tree_01", "SM_Env_Tree_04"], 54, "back", Vector2(0.55, 0.8), dark)
	_scatter(batch, rng, hfun, ["SM_Env_Tree_Cluster_01", "SM_Env_Tree_Cluster_02"], 14, "far", Vector2(0.7, 0.9), dark)
	_scatter(batch, rng, hfun, ["SM_Env_Tree_Large_02", "SM_Env_Tree_04"], 10, "side", Vector2(0.55, 0.75), dark)
	_scatter(batch, rng, hfun, BUSHES, 22, "near_back", Vector2(0.28, 0.42), dark)
	for i in 14:
		var p := _spot(rng, "near_back" if i < 9 else "front")
		_art(root, "Fern" if i % 3 != 0 else "Mushroom", p, hfun, rng.randf_range(0.4, 0.8) if i % 3 != 0 else rng.randf_range(0.25, 0.4), rng.randf() * TAU)
	# менгиры: круг стоячих камней позади
	var c := Vector2(-2.0, -14.0)
	for i in 7:
		var a := TAU * i / 7.0
		var mi := MeshInstance3D.new()
		var k := Kit.new()
		k.blob(Vector3(0, 1.2, 0), Vector3(0.45, 1.3, 0.35), Color("8a8a84"), 20 + i, 0.14)
		mi.mesh = k.mesh()
		mi.material_override = Kit.material()
		var pp := c + Vector2(cos(a) * 4.5, sin(a) * 2.6)
		mi.position = Vector3(pp.x, hfun.call(pp.x, pp.y) - 0.2, pp.y)
		mi.rotation = Vector3(rng.randf_range(-0.08, 0.08), rng.randf() * TAU, rng.randf_range(-0.08, 0.08))
		mi.scale = Vector3.ONE * rng.randf_range(0.8, 1.2)
		root.add_child(mi)
	# частокол галльской деревни справа
	for i in 9:
		var pz := -9.5 - i * 0.05
		_put(root, "SM_Env_Fence_Wood_0%d" % (1 + i % 3), Vector2(10.0 + i * 2.2, pz), hfun, 0.0, 1.0)
	_art(root, "Big_War_Tent", Vector2(16.0, -13.0), hfun, 3.4, -0.3)
	var f := Vector2(12.5, -10.8)
	var fy: float = hfun.call(f.x, f.y)
	_put(root, "SM_Prop_Brazier_03", f, hfun, 0.0, 1.2)
	_fire(root, Vector3(f.x, fy + 1.1, f.y), info, Color(1.0, 0.6, 0.28), 1.8, 7.0, 0.6)
	_ours(root, hfun, info)


## Германские болота: лужи, камыш, кувшинки, сухие деревья, мостки, туман
static func _swamp(root: Node3D, batch: SyntyBatch, rng: RandomNumberGenerator, hfun: Callable, info: Dictionary) -> void:
	var dull := {"tint": Color(0.7, 0.72, 0.5)}
	_meadow(batch, rng, hfun, 1.2, 0.0, dull)
	_scatter(batch, rng, hfun, GRASS_BIG, 26, "back", Vector2(0.5, 0.8), {"tint": Color(0.62, 0.66, 0.42)})
	_scatter(batch, rng, hfun, GRASS, 40, "grove", Vector2(1.0, 1.4), {"tint": Color(0.7, 0.72, 0.48)})
	_scatter(batch, rng, hfun, ["SM_Env_Tree_Thin_01", "SM_Env_Tree_Thin_02"], 12, "back", Vector2(0.8, 1.1), dull)
	_scatter(batch, rng, hfun, ["SM_Env_Tree_Large_01", "SM_Env_Tree_Cluster_01"], 8, "far", Vector2(0.7, 0.9), dull)
	for i in 12:
		var p := _spot(rng, "back" if i < 8 else "side")
		_art(root, "No_leaf_Tree" if i % 2 == 0 else "No_leaf_Tree_001", p, hfun, rng.randf_range(3.5, 6.0), rng.randf() * TAU)
	# лужи-озерца позади и впереди: тёмная болотная вода с кувшинками
	var pools := [[Vector2(-6.0, -9.0), Vector2(9.0, 4.0)], [Vector2(9.0, -12.0), Vector2(12.0, 5.0)], [Vector2(-18.0, 8.0), Vector2(10.0, 3.5)],
		[Vector2(12.0, 8.5), Vector2(8.0, 3.0)], [Vector2(-14.0, -6.2), Vector2(6.0, 2.2)], [Vector2(22.0, -7.0), Vector2(7.0, 2.6)]]
	for i in pools.size():
		var c: Vector2 = pools[i][0]
		var sz: Vector2 = pools[i][1]
		_pool(root, c, sz, hfun, Color("2c3424"), 40 + i)
		for j in 3:
			_put(root, "SM_Env_Lillies_0%d" % (1 + j), c + Vector2(rng.randf_range(-sz.x, sz.x) * 0.3, rng.randf_range(-sz.y, sz.y) * 0.25), hfun, rng.randf() * TAU, 1.0)
	# мостки через болото позади
	for i in 6:
		_put(root, "SM_Prop_Beam_01", Vector2(-4.0 + i * 0.5, -9.0), hfun, PI / 2, 1.0)
	_ours(root, hfun, info)


## Лабиринт Минотавра: каменные стены и колонны позади, плиты на тропе, обломки статуй
static func _labyrinth(root: Node3D, batch: SyntyBatch, rng: RandomNumberGenerator, hfun: Callable, info: Dictionary) -> void:
	_meadow(batch, rng, hfun, 0.7, 0.4)
	_scatter(batch, rng, hfun, ["SM_Env_Tree_Palm_01", "SM_Env_Tree_03"], 8, "far", Vector2(0.7, 0.9))
	_scatter(batch, rng, hfun, PALMS_LOW, 6, "back", Vector2(0.45, 0.65))
	_scatter(batch, rng, hfun, FLOWER_BUSHES, 8, "near_back", Vector2(0.8, 1.1))
	# стены из песчаника: длинные ряды с проёмами, в три яруса глубины
	var sand := {"tint": Color(0.92, 0.8, 0.64)}
	for row: Array in [[-6.2, 0.0], [-11.0, 1.25], [-16.0, 0.6]]:
		var z: float = row[0]
		var x := -30.0 + float(row[1])
		while x < 36.0:
			if rng.randf() < 0.82:
				var w := _put(root, "SM_Bld_Wall_01", Vector2(x, z), hfun, 0.0, 1.0, sand)
				w.position.y -= 0.1
				if rng.randf() < 0.25:
					w.rotation.z = rng.randf_range(-0.04, 0.04)
			else:
				_put(root, "SM_Bld_Pillar_Monument_01_Damaged_01", Vector2(x + 1.25, z), hfun, rng.randf() * TAU, 0.7, sand)
			x += 2.5
	for i in 10:
		var p := _spot(rng, "near_back")
		p.y = clampf(p.y, -5.6, -4.6)
		_put(root, ["SM_Prop_Marble_Rubble_01", "SM_Prop_Marble_Rubble_03", "SM_Prop_Statue_Broken_02", "SM_Prop_Statue_Broken_03", "SM_Prop_Marble_Block_02"][i % 5], p, hfun, rng.randf() * TAU, 1.0)
	for i in 4:
		var p := _spot(rng, "front")
		_put(root, ["SM_Prop_Statue_Broken_05", "SM_Prop_Marble_Rubble_02", "SM_Prop_Statue_Broken_08"][i % 3], p, hfun, rng.randf() * TAU, 1.0)
	# двойной топор Крита на постаменте и колонны у входа
	_put(root, "SM_Bld_Pillar_02", Vector2(6.0, -5.2), hfun, 0.0, 1.0, sand)
	_put(root, "SM_Bld_Pillar_02", Vector2(10.0, -5.2), hfun, 0.0, 1.0, sand)
	_put(root, "SM_Prop_Statue_Lion_01", Vector2(-9.0, -5.6), hfun, 0.3, 0.8)
	_ours(root, hfun, info, false)


## Скалы циклопов: скалы ярусами, море позади справа, берег
static func _rocks(root: Node3D, batch: SyntyBatch, rng: RandomNumberGenerator, hfun: Callable, info: Dictionary) -> void:
	_meadow(batch, rng, hfun, 0.6, 0.2)
	var stone := {"tint": Color(0.8, 0.74, 0.66)}
	var bay := Rect2(-2.0, -60.0, 70.0, 52.0)
	_scatter(batch, rng, hfun, ["SM_Env_Rock_Cliff_Layers_01", "SM_Env_Rock_Cliff_Layers_02", "SM_Env_Rock_Cliff_01"], 16, "deep", Vector2(0.6, 1.1), stone, bay)
	_scatter(batch, rng, hfun, ["SM_Env_Rock_Cliff_02"], 8, "grove", Vector2(0.4, 0.7), stone, bay)
	_scatter(batch, rng, hfun, ["SM_Env_Rock_Cliff_02"], 6, "grove", Vector2(0.3, 0.45), stone, Rect2(4.0, -16.0, 40.0, 12.0))
	# скалы в море
	for i in 6:
		var rp := Vector2(rng.randf_range(4.0, 40.0), rng.randf_range(-30.0, -14.0))
		var r := _put(root, ["SM_Env_Rock_Cliff_02", "SM_Env_Rock_Cliff_Square_01"][i % 2], rp, hfun, rng.randf() * TAU, rng.randf_range(0.4, 0.9), stone)
		r.position.y = -1.2
	_scatter(batch, rng, hfun, ["SM_Env_Tree_Thin_01", "SM_Env_Tree_Palm_01"], 8, "back", Vector2(0.6, 0.85))
	_kit_many(root, rng, hfun, "#rock", 36, "near_back", Vector2(1.0, 3.0))
	_kit_many(root, rng, hfun, "#rock_big", 10, "side", Vector2(1.5, 3.0))
	_kit_many(root, rng, hfun, "#rock", 14, "front", Vector2(0.8, 2.0))
	_scatter(batch, rng, hfun, PEBBLES, 10, "near_back", Vector2(0.7, 1.0))
	# море в дали: большая гладь ниже земли (видна в просвет холмов справа)
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(260, 120)
	pm.subdivide_width = 60
	pm.subdivide_depth = 30
	sea.mesh = pm
	var water := ShaderMaterial.new()
	water.shader = load("res://shaders/water.gdshader")
	sea.material_override = water
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.position = Vector3(40.0, -0.8, -72.0)
	root.add_child(sea)
	# пещера циклопа: тёмный зев в скале позади слева
	var c := Vector2(-12.0, -14.0)
	_put(root, "SM_Env_Rock_Cliff_Layers_01", c, hfun, 0.3, 0.7, stone)
	var mouth := MeshInstance3D.new()
	var k := Kit.new()
	k.blob(Vector3.ZERO, Vector3(2.0, 2.2, 0.6), Color("1a1512"), 7, 0.12)
	mouth.mesh = k.mesh()
	mouth.material_override = Kit.material()
	mouth.position = Vector3(c.x - 0.5, hfun.call(c.x, c.y + 4.0) + 1.0, c.y + 4.5)
	root.add_child(mouth)
	_put(root, "SM_Prop_Marble_Pile_01", Vector2(9.0, -6.0), hfun, 0.4, 1.0)
	_ours(root, hfun, info)


## Пески Карфагена: дюны, пальмы оазиса, шатры наёмников, обломки колонн
static func _desert(root: Node3D, batch: SyntyBatch, rng: RandomNumberGenerator, hfun: Callable, info: Dictionary) -> void:
	_scatter(batch, rng, hfun, ["SM_Env_Tree_Palm_01", "SM_Env_Tree_Palm_02", "SM_Env_Tree_Palm_03"], 18, "back", Vector2(0.5, 0.75))
	_scatter(batch, rng, hfun, ["SM_Env_Tree_Palm_02", "SM_Env_Tree_Palm_03"], 6, "side", Vector2(0.5, 0.7))
	_scatter(batch, rng, hfun, PALMS_LOW, 10, "near_back", Vector2(0.45, 0.7))
	_scatter(batch, rng, hfun, ["SM_Env_Rock_Cliff_02", "SM_Env_Rock_Cliff_Layers_02"], 8, "far", Vector2(0.6, 1.0), {"tint": Color(0.92, 0.78, 0.6)})
	_scatter(batch, rng, hfun, ["SM_Env_Rock_Cliff_02"], 5, "back", Vector2(0.25, 0.4), {"tint": Color(0.92, 0.78, 0.6)}, Rect2(-20.0, -16.0, 44.0, 12.0))
	_scatter(batch, rng, hfun, GRASS, 30, "near_back", Vector2(0.6, 0.9), {"tint": Color(0.9, 0.8, 0.45)})
	_kit_many(root, rng, hfun, "#rock", 18, "near_back", Vector2(0.8, 2.0))
	# шатры Карфагена справа
	_art(root, "Big_War_Tent", Vector2(13.0, -9.0), hfun, 3.0, -0.2)
	_art(root, "Big_War_Tent", Vector2(19.0, -11.5), hfun, 3.2, 0.3)
	_art(root, "Small_Tent", Vector2(8.5, -7.6), hfun, 2.0, -0.6)
	_put(root, "SM_Prop_Jar_Pile_01", Vector2(10.6, -6.2), hfun, 0.0, 0.9)
	_put(root, "SM_Prop_Vase_Pile_02", Vector2(16.0, -6.8), hfun, 0.5, 0.9)
	_put(root, "SM_Bld_Pillar_Monument_01_Damaged_01", Vector2(-7.0, -8.0), hfun, 0.2, 0.75)
	_put(root, "SM_Prop_Statue_Broken_03", Vector2(-4.0, -5.4), hfun, 0.8, 1.0)
	# оазис: пруд позади слева, вокруг тростник
	_pool(root, Vector2(-14.0, -12.0), Vector2(11.0, 5.0), hfun, Color("3f7f86"), 9)
	_scatter(batch, rng, hfun, ["SM_Env_Grass_03", "SM_Env_Grass_01"], 12, "near_back", Vector2(0.8, 1.1), {"tint": Color(0.7, 0.85, 0.45)})
	_ours(root, hfun, info)


## Врата Аида: тёмная земля с жаром в трещинах, скалы, статуя Аида, голубые огни душ, обломки колонн
static func _hades(root: Node3D, batch: SyntyBatch, rng: RandomNumberGenerator, hfun: Callable, info: Dictionary) -> void:
	var ash := {"tint": Color(0.42, 0.38, 0.42)}
	_scatter(batch, rng, hfun, ["SM_Env_Rock_Cliff_Layers_01", "SM_Env_Rock_Cliff_01", "SM_Env_Rock_Cliff_Layers_02"], 18, "deep", Vector2(0.6, 1.1), ash)
	_scatter(batch, rng, hfun, ["SM_Env_Rock_Cliff_02"], 8, "grove", Vector2(0.35, 0.6), ash, Rect2(5.0, -14.0, 13.0, 9.0))
	_scatter(batch, rng, hfun, ["SM_Env_Rock_Cliff_02", "SM_Env_Rock_Cliff_Square_01"], 8, "near_back", Vector2(0.3, 0.5), ash)
	_kit_many(root, rng, hfun, "#rock", 30, "near_back", Vector2(1.0, 2.6))
	_kit_many(root, rng, hfun, "#rock", 12, "front", Vector2(0.8, 1.8))
	for i in 8:
		var p := _spot(rng, "back")
		_art(root, "No_leaf_Tree_001" if i % 2 else "No_leaf_Tree", p, hfun, rng.randf_range(3.0, 5.0), rng.randf() * TAU)
	# врата: две колонны и статуя Аида между ними, голубые огни душ в чашах
	var g := Vector2(11.0, -9.0)
	_put(root, "SM_Bld_Pillar_Monument_01", g + Vector2(-3.2, 0.0), hfun, 0.0, 0.85, ash)
	_put(root, "SM_Bld_Pillar_Monument_01_Damaged_01", g + Vector2(3.2, 0.0), hfun, 0.0, 0.85, ash)
	var hs := _art(root, "Hades", g + Vector2(0.0, -1.5), hfun, 4.6, 0.0)
	hs.rotation.y = 0.0
	for sx: float in [-1.0, 1.0]:
		var bp := g + Vector2(sx * 5.0, 1.0)
		var by: float = hfun.call(bp.x, bp.y)
		_put(root, "SM_Prop_Brazier_03", bp, hfun, 0.0, 1.2, ash)
		_fire(root, Vector3(bp.x, by + 1.1, bp.y), info, Color(0.35, 0.75, 1.0), 2.6, 8.0, 0.7)
	for i in 4:
		var bp := _spot(rng, "near_back")
		bp.y = minf(bp.y, -6.0)
		var by: float = hfun.call(bp.x, bp.y)
		_fire(root, Vector3(bp.x, by + 0.2, bp.y), info, Color(0.4, 0.7, 1.0), 1.6, 6.0, 0.5)
	for i in 6:
		var p := _spot(rng, "near_back")
		_put(root, ["SM_Prop_Statue_Broken_02", "SM_Prop_Marble_Rubble_04", "SM_Prop_Statue_Broken_05"][i % 3], p, hfun, rng.randf() * TAU, 1.0, ash)
	# Стикс: тёмная река позади, светится холодным
	for i in 7:
		_pool(root, Vector2(-30.0 + i * 10.0, -19.0 + sin(i * 1.3) * 1.2), Vector2(11.5, 4.0), hfun, Color("1c1830"), 60 + i, Color(0.18, 0.22, 0.6, 1.0))
	_ours(root, hfun, info, false)
