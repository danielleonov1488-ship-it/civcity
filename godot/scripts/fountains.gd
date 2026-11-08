class_name Fountains
extends Node3D
## Живая вода в фонтанах («Уютный Рим», этап 7 «фонтаны оживают по акведуку»): из чаш фонтанов бьёт струя, из львиных
## пастей льётся вода. Есть в городе акведук — струи вдвое гуще и выше. Места — по чертежу постройки: верх каждой
## чаши SM_Prop_Fountain_0X, пасть SM_Prop_Marble_LionHead_01 (вода — вперёд от пасти). Струи — частицы только у фонтанов
## рядом с точкой взгляда (NEAR), на «Очень низкой» — нет.

const NEAR := 55.0
const SCAN := 2.0                        # с — как часто пересматривать фонтаны города
const TYPES := ["fountain", "smallfountain", "nymphaeum"]

var game
var jets := {}                           # id постройки → {em: [GPUParticles3D], kind: [top|spout], aqua}
var _scan := 0.0
var _aqua := false


func setup(g) -> void:
	game = g


func _process(dt: float) -> void:
	if game == null or not game.ready_done or game.city == null:
		return
	_scan -= dt
	var q := str(game.settings.get("quality", "high"))
	var at: Vector3 = game.rig.target if game.rig else Vector3.ZERO
	if _scan <= 0.0:
		_scan = SCAN
		_aqua = false
		for id in game.city.buildings:
			if Defs.base_of(String(game.city.buildings[id]["type"])) == "aqua":
				_aqua = true
				break
		_sync(at)
	for id in jets:
		var J: Dictionary = jets[id]
		var near: bool = (J["at"] as Vector3).distance_to(at) < NEAR and q != "verylow"
		for p: GPUParticles3D in J["em"]:
			p.emitting = near
			p.speed_scale = clampf(float(game.speed), 0.2, 2.0)
			p.amount_ratio = (1.0 if _aqua else 0.5) * (0.6 if q == "low" else 1.0)


func _sync(at: Vector3) -> void:
	var seen := {}
	for id in game.city.buildings:
		var b: Dictionary = game.city.buildings[id]
		if not Defs.base_of(String(b["type"])) in TYPES and String(b["type"]) not in TYPES:
			continue
		seen[id] = true
		var key := "%s|%d" % [b["type"], int(b.get("variant", 0))]
		if jets.has(id) and String(jets[id]["key"]) == key and bool(jets[id]["aqua"]) == _aqua:
			continue
		_drop(id)
		jets[id] = _make(b, key)
	for id in jets.keys():
		if not seen.has(id):
			_drop(id)


func _drop(id) -> void:
	if not jets.has(id):
		return
	for p: Node in jets[id]["em"]:
		p.queue_free()
	jets.erase(id)


func _make(b: Dictionary, key: String) -> Dictionary:
	var xf: Transform3D = game.city.xf(b)
	var bp: Bp = game.city.blueprint(b)
	var ems := []
	for p in bp.parts:
		var nm := String(p[0])
		var t: Transform3D = p[1]
		if nm.begins_with("SM_Prop_Fountain_0") and not nm.contains("Insert"):
			var ab := Bp.model_aabb(nm)
			var top := t * Vector3(ab.get_center().x, ab.position.y + ab.size.y, ab.get_center().z)
			var sc := t.basis.get_scale().x
			ems.append(_jet(xf * top, Vector3.UP, 2.0 * sqrt(maxf(0.3, sc)) * (1.25 if _aqua else 1.0), 14.0, 0.65, 30))
			# вода переливается через край чаши — завеса капель по кругу
			var rim := _jet(xf * (top - Vector3(0, ab.size.y * sc * 0.35, 0)), Vector3.UP, 0.35, 70.0, 0.5, 60)
			var pm := rim.process_material as ParticleProcessMaterial
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			pm.emission_ring_axis = Vector3.UP
			pm.emission_ring_radius = ab.size.x * sc * 0.24
			pm.emission_ring_inner_radius = ab.size.x * sc * 0.22
			pm.emission_ring_height = 0.02
			ems.append(rim)
		elif nm == "SM_Prop_Marble_LionHead_01":
			var dir := (xf.basis * t.basis * Vector3(0, 0, 1)).normalized()
			var mouth := xf * (t * Vector3(0, 0.12, 0.12))
			ems.append(_jet(mouth, dir, 0.9 * (1.2 if _aqua else 1.0), 4.0, 0.4, 24))
	return {"em": ems, "key": key, "aqua": _aqua, "at": xf.origin}


func _jet(pos: Vector3, dir: Vector3, vel: float, spread: float, life: float, amount: int) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount * (2 if _aqua else 1)
	p.lifetime = life
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	var pm := ParticleProcessMaterial.new()
	pm.direction = dir
	pm.spread = spread
	pm.initial_velocity_min = vel * 0.85
	pm.initial_velocity_max = vel
	pm.gravity = Vector3(0, -9.0, 0)
	pm.scale_min = 0.7
	pm.scale_max = 1.2
	pm.particle_flag_align_y = true
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
	var ft := GradientTexture1D.new()
	ft.gradient = fade
	pm.color_ramp = ft
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.2)              # струйка — тонкая и вытянутая по ходу (align_y)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.88, 0.95, 1.0, 0.6)
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	p.global_position = pos
	return p
