class_name Seasons
extends Node3D
## Времена года («Уютный Рим», PLAN_COZY §10): по игровому календарю (год — Renown.CAL_YEAR дней, по два дня на месяц)
## листва и трава меняются плавно: осенью деревья золотые, рыжие и багряные и с них падают листья, зимой зелень
## тусклая и буроватая, весной часть деревьев цветёт. Правила игры не меняет — только вид. Только в новой игре
## (City.cozy_v ≥ 1); в старых городах, меню и витрине — всегда лето (как было). На «Очень низкой» листья не падают.
## Цвета — shaders/foliage.gdshader (деревья и кусты, Synty.set_season) и land.gdshader season (трава).

const NAMES := {"winter": "зима", "spring": "весна", "summer": "лето", "autumn": "осень"}
const EMITTERS := 6                       # столько деревьев у взгляда роняют листья
const NEAR := 26.0

var game
var now := Vector4.ZERO                   # x осень, y зима, z весна (0…1)
var force_m := -1.0                       # проверки и снимки: ≥ 0 — этот месяц (0 — начало января … 12)
var leaves: Array = []                    # [GPUParticles3D]
var _scan_t := 0.0
var _sent := Vector4(-1, -1, -1, -1)


## Месяц года (0 — начало января … 12) у дня d в час h
static func month(d: int, h := 12.0) -> float:
	return fposmod((float(d) + h / 24.0) / float(Renown.CAL_YEAR) * 12.0, 12.0)


## Сила осени, зимы и весны в месяц m: осень — с сентября до конца ноября, зима — декабрь…февраль,
## весна (цветение) — апрель; летом всё как было
static func weights(m: float) -> Vector4:
	var au := smoothstep(8.0, 9.4, m) * (1.0 - smoothstep(11.0, 11.9, m))
	var wi := maxf(smoothstep(11.0, 11.9, m), 1.0 - smoothstep(1.6, 2.5, m))
	var sp := smoothstep(2.5, 3.2, m) * (1.0 - smoothstep(4.3, 5.1, m))
	return Vector4(au, wi, sp, 0.0)


static func id_of(d: int) -> String:
	var m := month(d)
	if m < 2.0 or m >= 11.0:
		return "winter"
	if m < 5.0:
		return "spring"
	if m < 8.0:
		return "summer"
	return "autumn"


static func name_of(d: int) -> String:
	return NAMES[id_of(d)]


func setup(g) -> void:
	game = g
	for i in EMITTERS:
		var p := _leaves()
		add_child(p)
		p.emitting = false
		leaves.append(p)


func _process(dt: float) -> void:
	if game == null or not game.ready_done or game.city == null:
		return
	var want := Vector4.ZERO
	if force_m >= 0.0:
		want = weights(force_m)
	elif int(game.city.cozy_v) >= 1 and game.mode != "menu":
		want = weights(month(int(game.city.day), float(game.hour)))
	now = want
	if (now - _sent).length() > 0.004 or (now == Vector4.ZERO and _sent != Vector4.ZERO):
		_sent = now
		Synty.set_season(now)
		if game.land_mat != null:
			game.land_mat.set_shader_parameter("season", now)
	_scan_t -= dt
	if _scan_t <= 0.0:
		_scan_t = 1.5
		_place_leaves()


## Листопад: падают с ближайших к взгляду деревьев (не с пустого неба над мостовой)
func _place_leaves() -> void:
	var q := str(game.settings.get("quality", "high"))
	var on := now.x > 0.05 and q != "verylow"
	var trees := []
	if on:
		var at: Vector3 = game.rig.target if game.rig else Vector3.ZERO
		var c0 := Vector2i(int((at.x - NEAR) / 2.0), int((at.z - NEAR) / 2.0))
		var c1 := Vector2i(int((at.x + NEAR) / 2.0), int((at.z + NEAR) / 2.0))
		for kx in range(c0.x, c1.x + 1):
			for kz in range(c0.y, c1.y + 1):
				for it: Dictionary in game.nature.get(Vector2i(kx, kz), []):
					var nm := String(it["name"])
					if not nm.begins_with("SM_Env_Tree") or nm.contains("Bush"):
						continue
					var xf: Transform3D = it["xf"]
					var d := Vector2(xf.origin.x - at.x, xf.origin.z - at.z).length()
					if d < NEAR:
						trees.append([d, nm, xf])
		trees.sort_custom(func(a, b): return a[0] < b[0])
	var used := []
	for e: Array in trees:
		if used.size() >= EMITTERS:
			break
		var xf: Transform3D = e[2]
		var far := true
		for u: Transform3D in used:
			if u.origin.distance_to(xf.origin) < 3.0:
				far = false
				break
		if far:
			used.append(xf)
	for i in EMITTERS:
		var p: GPUParticles3D = leaves[i]
		if i < used.size():
			var xf: Transform3D = used[i]
			var nm := ""
			for e: Array in trees:
				if e[2] == xf:
					nm = e[1]
					break
			var box := Bp.model_aabb(nm)
			var sc := xf.basis.get_scale()
			p.global_position = xf.origin + Vector3(0, box.size.y * sc.y * 0.62, 0)
			var pm := p.process_material as ParticleProcessMaterial
			var r := maxf(0.4, minf(box.size.x, box.size.z) * sc.x * 0.33)
			pm.emission_box_extents = Vector3(r, box.size.y * sc.y * 0.15, r)
			p.amount_ratio = clampf(now.x, 0.0, 1.0) * (0.5 if q == "low" else 1.0)
			p.emitting = true
		else:
			p.emitting = false


## Листок: маленький ромбик (5 см), с двух сторон; кружится и медленно падает, покачиваясь
func _leaves() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Leaves"
	p.amount = 10
	p.lifetime = 9.0
	p.preprocess = 4.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-4, -8, -4), Vector3(8, 10, 8))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(1, 0.3, 1)
	pm.direction = Vector3(0.3, -1, 0.1)
	pm.spread = 35.0
	pm.initial_velocity_min = 0.08
	pm.initial_velocity_max = 0.22
	pm.gravity = Vector3(0.04, -0.06, 0.02)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 1.6
	pm.turbulence_influence_min = 0.03
	pm.turbulence_influence_max = 0.08
	pm.particle_flag_rotate_y = true
	pm.angular_velocity_min = -220.0
	pm.angular_velocity_max = 220.0
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.scale_min = 0.75
	pm.scale_max = 1.25
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	gr.colors = PackedColorArray([Color(0.95, 0.68, 0.15), Color(0.92, 0.45, 0.1), Color(0.72, 0.18, 0.07), Color(0.55, 0.35, 0.14)])
	var gt := GradientTexture1D.new()
	gt.gradient = gr
	pm.color_initial_ramp = gt
	p.process_material = pm
	p.draw_pass_1 = _leaf_mesh()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


static var _leaf: ArrayMesh


static func _leaf_mesh() -> ArrayMesh:
	if _leaf != null:
		return _leaf
	var L := 0.028
	var W := 0.018
	var tilt := Basis(Vector3(0, 0, 1), deg_to_rad(38.0)) * Basis(Vector3(1, 0, 0), deg_to_rad(20.0))
	var pts := [Vector3(0, 0, -L * 0.5), Vector3(W * 0.5, 0.002, -L * 0.05), Vector3(0, 0, L * 0.5), Vector3(-W * 0.5, 0.002, -L * 0.05)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri in [[0, 1, 2], [0, 2, 3]]:
		for k in tri:
			st.set_normal(tilt * Vector3.UP)
			st.add_vertex(tilt * (pts[k] as Vector3))
	_leaf = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.9
	_leaf.surface_set_material(0, m)
	return _leaf
