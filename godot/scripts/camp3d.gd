class_name Camp3D
extends SubViewportContainer
## Отдельный мир лагеря. Перед павильонами нет стен и крыши.

signal building_pressed(slot: String)
signal view_changed

const PLOTS := {
	"hq": Vector3(0, 0, -15), "mars": Vector3(22, 0, -15),
	"barracks": Vector3(-21, 0, -1), "forge": Vector3(21, 0, 0),
	"drill": Vector3(-18, 0, 14), "store": Vector3(18, 0, 14),
}
const CITY_TYPES := {"hq": "principia", "barracks": "barracks", "forge": "forge", "mars": "mars", "store": "armory"}
const LEVEL_PROPS := {
	"hq": {2: ["#mil_standard"], 3: ["#mil_eagle", "SM_Prop_Table_04"], 5: ["wing"]},
	"barracks": {2: ["#mil_standard"], 3: ["SM_Prop_Weapon_Rack_02", "SM_Prop_Seat_Kline_02"], 5: ["wing"]},
	"forge": {2: ["#mil_standard"], 3: ["#mil_ingots", "SM_Prop_Grinding_Wheel_01"], 5: ["wing"]},
	"drill": {2: ["#mil_standard"], 3: ["#mil_target", "#mil_quiver"], 5: ["wing"]},
	"mars": {2: ["#mil_standard"], 3: ["SM_Prop_Jar_01", "#mil_eagle"], 5: ["wing"]},
	"store": {2: ["#mil_standard"], 3: ["#mil_logs", "#mil_hides"], 5: ["wing"]},
}
const MAX_FIGURES := 16
const DEFAULT_ZOOM := 66.0
const MIN_ZOOM := 27.0
const MAX_ZOOM := 78.0
const GATE := Vector3(0, 0, 24)
const WALK_TIME := 9.0

var lg: Legion
var sub: SubViewport
var world: Node3D
var camera: Camera3D
var buildings := {}
var highlights := {}
var scaffolds := {}
var figures: Array[Dictionary] = []
var arrivals := {}
var focus := Vector3.ZERO
var zoom := DEFAULT_ZOOM
var active := false
var _building_sig := ""
var _people_sig := ""
var _clock := 0.0
var _accum := 0.0
var _dragging := false
var _drag_distance := 0.0


func setup(legion: Legion) -> bool:
	lg = legion
	name = "Camp3D"
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Без набора моделей оставляем живописный запасной экран.
	if not Synty.has("SK_Chr_Solider_Male_01"):
		return false
	for model: String in ["SK_Chr_Solider_Male_01", "SK_Chr_Worker_Male_01", "SK_Chr_Politician_Male_01", "SK_Chr_Captain_Male_01", "SK_Chr_Soldier_Female_02"]:
		if not ResourceLoader.exists(Citizen.DIR + model + ".fbx"):
			return false
	if not ResourceLoader.exists("res://assets/people/UAL1_Standard.glb"):
		return false
	sub = SubViewport.new()
	sub.name = "CampWorld"
	sub.own_world_3d = true
	sub.size = Vector2i(maxi(1, int(size.x)), maxi(1, int(size.y)))
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub.msaa_3d = get_viewport().msaa_3d
	sub.gui_disable_input = true
	add_child(sub)
	world = Node3D.new()
	sub.add_child(world)
	_light()
	_ground()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.far = 250.0
	world.add_child(camera)
	camera.current = true
	active = true
	_update_camera()
	sync()
	resized.connect(_update_camera)
	mouse_exited.connect(func(): highlight(""))
	return true


func _light() -> void:
	var env := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("87b8ce")
	sky_material.sky_horizon_color = Color("e8dbb9")
	sky_material.ground_horizon_color = Color("c8c497")
	sky_material.ground_bottom_color = Color("65734d")
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d5e4ef")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("ffe1ae")
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 130.0
	sun.light_angular_distance = 1.8
	world.add_child(sun)


func _box(parent: Node3D, pos: Vector3, dims: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dims
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	mesh.material = mat
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	parent.add_child(node)
	return node


func _prop(parent: Node3D, model: String, pos: Vector3, scale_v := 1.0, yaw := 0.0) -> Node3D:
	var node: Node3D
	if model.begins_with("#mil_"):
		var mi := MeshInstance3D.new()
		mi.mesh = CatMilitary.kit_mesh(model)
		node = mi
	elif Synty.has(model):
		node = Synty.make(model)
	else:
		return null
	node.name = model.trim_prefix("#")
	parent.add_child(node)
	node.position = pos
	node.scale = Vector3.ONE * scale_v
	node.rotation.y = yaw
	return node


func _ground() -> void:
	var ground := _box(world, Vector3(0, -0.4, 0), Vector3(70, 0.8, 50), Color("7d9757"))
	var shader := Shader.new()
	shader.code = "shader_type spatial; varying vec3 p; void vertex(){p=VERTEX;} void fragment(){float v=sin(p.x*0.48)*sin(p.z*0.35)*0.025+sin(p.x*3.1+p.z*2.7)*0.012; ALBEDO=vec3(0.39,0.49,0.24)+v; ROUGHNESS=1.0;}"
	var grass := ShaderMaterial.new()
	grass.shader = shader
	ground.material_override = grass
	_box(world, Vector3(0, 0.025, 3), Vector3(5.5, 0.05, 43), Color("b6a17a"))
	for z: float in [-15.0, 0.0, 14.0]:
		_box(world, Vector3(0, 0.03, z), Vector3(49, 0.06, 3), Color("b6a17a"))
	# Частокол собран в одну сетку, без сотен отдельных узлов.
	var fence := Kit.new()
	for x in range(-34, 35):
		for z: float in [-24.0, 24.0]:
			if z > 0 and absi(x) < 5:
				continue
			fence.boxc(Vector3(x, 1.15, z), Vector3(0.72, 2.3, 0.65), Color("866443"))
	for z in range(-23, 24):
		for x: float in [-34.0, 34.0]:
			fence.boxc(Vector3(x, 1.15, z), Vector3(0.65, 2.3, 0.72), Color("866443"))
	var wall := MeshInstance3D.new()
	wall.mesh = fence.mesh()
	wall.material_override = Kit.material(0.9)
	world.add_child(wall)
	for x: float in [-4.5, 4.5]:
		_box(world, Vector3(x, 2.4, 24), Vector3(0.9, 4.8, 0.9), Color("65452e"))
		_prop(world, "#mil_standard", Vector3(x, 4.8, 24), 0.9)
	_box(world, Vector3(0, 4.7, 24), Vector3(10, 0.6, 1), Color("65452e"))
	for pos: Vector3 in [Vector3(-26, 0, -17), Vector3(-17, 0, -18), Vector3(-28, 0, 18)]:
		_prop(world, "#mil_tent", pos, 1.5)
		_crate(world, pos + Vector3(3, 0.6, 1))
	for x: float in [-31.0, 30.0]:
		_prop(world, "SM_Env_Tree_Thin_01", Vector3(x, 0, -19), 1.3)


func _crate(parent: Node3D, pos: Vector3) -> void:
	_box(parent, pos, Vector3(1.3, 1.2, 1.1), Color("a5784a"))
	for x: float in [-0.45, 0.45]:
		_box(parent, pos + Vector3(x, 0, 0.56), Vector3(0.13, 1.2, 0.08), Color("d1a36b"))


func sync() -> void:
	if not active:
		return
	var sig := str([lg.camp, lg.upg.keys()])
	if sig != _building_sig:
		_building_sig = sig
		for node: Node3D in buildings.values():
			node.free()
		buildings.clear()
		highlights.clear()
		scaffolds.clear()
		for slot: String in PLOTS:
			_build_plot(slot)
		_people_sig = ""
	var roster := []
	for soldier: Dictionary in lg.soldiers:
		roster.append([soldier["id"], soldier.get("gear", {}), soldier.get("hero", false)])
	var people_sig := str([roster, lg.items, lg.hero_level(), Hero.look(lg.city())])
	if people_sig != _people_sig:
		_people_sig = people_sig
		_people()


func _build_plot(slot: String) -> void:
	var root := Node3D.new()
	root.name = "Plot_" + slot
	root.position = PLOTS[slot]
	world.add_child(root)
	buildings[slot] = root
	var base := _box(root, Vector3(0, 0.04, 0), Vector3(13, 0.08, 10), Color("c9b68c"))
	highlights[slot] = base
	if not lg.camp_built(slot):
		base.visible = false
		for x in range(-6, 7, 2):
			for z: float in [-5.0, 5.0]:
				_box(root, Vector3(x, 0.08, z), Vector3(1, 0.1, 0.18), Color("f3df9e"))
		for z in range(-4, 5, 2):
			for x: float in [-6.0, 6.0]:
				_box(root, Vector3(x, 0.08, z), Vector3(0.18, 0.1, 1), Color("f3df9e"))
	else:
		if slot != "drill":
			_pavilion(root, slot)
		_interior(root, slot)
		for level: int in LEVEL_PROPS[slot]:
			if lg.camp_level(slot) < level:
				continue
			var props: Array = LEVEL_PROPS[slot][level]
			for i in props.size():
				var model := String(props[i])
				if model == "wing":
					_prop(root, "#mil_tent", Vector3(-7.5, 0.1, -1.5), 1.4)
					_crate(root, Vector3(-7.5, 0.7, 2))
				else:
					_prop(root, model, Vector3(-5.3 + i * 2.4, 0.1, 3.8), 1.0)
	if lg.upg.has("camp_" + slot):
		_scaffold(root, slot)


func _pavilion(root: Node3D, slot: String) -> void:
	# Упрощённый разрез военных зданий: задняя стена и узкая полоса кровли.
	root.set_meta("city_type", CITY_TYPES[slot])
	_box(root, Vector3(0, 1.7, -4.2), Vector3(12, 3.4, 0.45), Color("e2cda9"))
	_box(root, Vector3(0, 0.5, -3.92), Vector3(12, 0.6, 0.12), Color("a84f3b"))
	for x: float in [-5.6, 5.6]:
		_prop(root, "SM_Bld_Pillar_02", Vector3(x, 0.1, -3.2), 1.2)
		_box(root, Vector3(x, 0.7, 0), Vector3(0.45, 1.4, 6), Color("d9c19c"))
	var roof := _box(root, Vector3(0, 3.7, -3.6), Vector3(12.8, 0.35, 1.7), Color("ab5139"))
	roof.rotation.x = -0.17
	for x in range(-6, 7):
		_box(root, Vector3(x, 3.91, -3.6), Vector3(0.09, 0.12, 1.7), Color("cc7650"))


func _interior(root: Node3D, slot: String) -> void:
	match slot:
		"hq":
			_box(root, Vector3(0, 1.0, 0), Vector3(4.6, 0.22, 2.4), Color("825a38"))
			for x: float in [-1.8, 1.8]:
				_box(root, Vector3(x, 0.5, 0), Vector3(0.25, 1, 1.5), Color("684a32"))
			_box(root, Vector3(0, 1.13, 0), Vector3(3.5, 0.03, 1.7), Color("ead7a3"))
			for x in 5:
				_box(root, Vector3(-1.3 + x * 0.6, 1.16, sin(x) * 0.5), Vector3(0.23, 0.06, 0.19), Color("a94c38"))
			_prop(root, "#mil_standard", Vector3(-4, 0.1, -2), 1.25)
			_prop(root, "#mil_standard", Vector3(4, 0.1, -2), 1.25)
		"barracks":
			for x: float in [-4.1, 0.0, 4.1]:
				for y: float in [0.48, 1.85]:
					_box(root, Vector3(x, y, -2), Vector3(2.5, 0.2, 2.1), Color("775636"))
					_box(root, Vector3(x, y + 0.17, -2), Vector3(2.3, 0.18, 1.9), Color("cebc88"))
					_box(root, Vector3(x - 0.8, y + 0.3, -2), Vector3(0.5, 0.15, 1.4), Color("eee0bb"))
				for dx: float in [-1.3, 1.3]:
					_box(root, Vector3(x + dx, 1.2, -2.8), Vector3(0.12, 2.4, 0.12), Color("775636"))
		"forge":
			_prop(root, "SM_Prop_Forge_01", Vector3(3.4, 0.1, -2), 1.4, -PI / 2)
			_prop(root, "SM_Prop_Anvil_01", Vector3(-1, 0.1, 0), 1.3)
			_prop(root, "#mil_ingots", Vector3(-4, 0.1, -2), 1.6)
			var ember := _box(root, Vector3(3.1, 0.8, -1.7), Vector3(0.8, 0.2, 0.7), Color("f48838"))
			var mat := ember.mesh.surface_get_material(0) as StandardMaterial3D
			mat.emission_enabled = true
			mat.emission = Color("ff6b22")
			mat.emission_energy_multiplier = 2.0
			var fire := OmniLight3D.new()
			fire.position = Vector3(3, 1.5, -1)
			fire.light_color = Color("ff9c40")
			fire.light_energy = 1.8
			fire.omni_range = 6
			root.add_child(fire)
		"mars":
			_box(root, Vector3(0, 0.65, -2), Vector3(3, 1.3, 2), Color("c9ba9b"))
			_prop(root, "SM_Prop_Statue_01", Vector3(0, 1.3, -2), 1.1)
			_box(root, Vector3(0, 0.6, 1), Vector3(2.7, 1.2, 1.3), Color("e6d8b7"))
			_prop(root, "SM_Prop_Jar_01", Vector3(3, 0.1, -1), 1.3)
		"store":
			for i in 5:
				_crate(root, Vector3(-4 + i * 1.6, 0.7, -2))
			for i in 3:
				_prop(root, "SM_Prop_Jar_01", Vector3(2 + i, 0.1, 1.5), 1.1)
			_prop(root, "SM_Prop_Sack_Stack_01", Vector3(-4, 0.1, 1), 1.3)
		"drill":
			for x: float in [-3.5, 0.0, 3.5]:
				_prop(root, "#mil_dummy", Vector3(x, 0.1, -1), 1.25)
			_prop(root, "SM_Prop_Weapon_Rack_01", Vector3(-5, 0.1, 3), 1.0)
			_prop(root, "SM_Prop_Weapon_Rack_01_Insert_01", Vector3(-5, 0.1, 3), 1.0)


func _scaffold(root: Node3D, slot: String) -> void:
	var scaffold := Node3D.new()
	scaffold.name = "Scaffolding"
	root.add_child(scaffold)
	scaffolds[slot] = scaffold
	for x: float in [-6.5, 6.5]:
		for z: float in [-4.5, 2.5]:
			_box(scaffold, Vector3(x, 2.5, z), Vector3(0.22, 5, 0.22), Color("947147"))
		for y: float in [1.7, 3.3]:
			_box(scaffold, Vector3(x, y, -1), Vector3(1.3, 0.18, 7.5), Color("ad8b55"))
		var brace := _box(scaffold, Vector3(x, 2.4, -1), Vector3(0.2, 0.2, 8), Color("80603d"))
		brace.rotation.x = 0.48
	_prop(scaffold, "SM_Prop_Ladder_01", Vector3(6.6, 0, 3), 1.25)


func _manual_animations(node: Node) -> Array:
	var players := node.find_children("*", "AnimationPlayer", true, false)
	for ap: AnimationPlayer in players:
		ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return players


func _register(node: Node3D, pos: Vector3, role: String, sid := 0) -> void:
	world.add_child(node)
	node.position = pos
	var players := _manual_animations(node)
	figures.append({"node": node, "home": pos, "role": role, "id": sid, "phase": figures.size() * 0.61, "players": players})


func _fighter(soldier: Dictionary) -> LegionFighter:
	if bool(soldier.get("hero", false)):
		return LegionFighter.create_hero(Hero.battle_look(lg.city(), lg.camp_level("store")), 1.3, int(soldier["id"]))
	var weapon := lg.item(int(soldier.get("gear", {}).get("weapon", 0)))
	var cls := Gear.weapon_class(weapon) if not weapon.is_empty() else "legionary"
	# В казарме всадник спешен, но копьё остаётся при нём.
	var model := "spearman" if cls == "cavalry" else ("legionPriest" if cls == "priest" else cls)
	return LegionFighter.create(model, 1.3, int(soldier["id"]))


func _civilian(pos: Vector3, role: String, animation: String) -> void:
	if figures.size() >= MAX_FIGURES:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 701 + figures.size()
	var model := "SK_Chr_Politician_Male_01" if role == "priest" else "SK_Chr_Worker_Male_01"
	var citizen := Citizen.create(rng, false, false, false, model, "pleb")
	citizen.scale *= 1.6
	_register(citizen, pos, role)
	citizen.play(animation, 0.0, figures.size() * 0.17)
	citizen.rotation.y = PI
	if role == "carrier":
		citizen.set_carry(true)
		_crate(citizen, Vector3(0, 0.8, 0.5))
	if role == "smith" or role == "builder":
		# Молот в правой кисти следует рабочему движению.
		var sk := citizen.find_children("*", "Skeleton3D", true, false)
		if not sk.is_empty():
			var hand := BoneAttachment3D.new()
			hand.bone_name = "RightHand"
			sk[0].add_child(hand)
			_prop(hand, "SM_Prop_Tool_Hammer_01", Vector3.ZERO, 1.0)


func _people() -> void:
	for entry: Dictionary in figures:
		(entry["node"] as Node).free()
	figures.clear()
	var regular: Array[Dictionary] = []
	var hero_added := false
	for soldier: Dictionary in lg.soldiers:
		if bool(soldier.get("hero", false)):
			if hero_added:
				continue
			var hero := _fighter(soldier)
			_register(hero, Vector3(PLOTS["hq"]) + Vector3(0, 0.1, 2.3), "hero", int(soldier["id"]))
			hero.rotation.y = PI
			hero_added = true
		elif arrivals.has(int(soldier["id"])):
			regular.push_front(soldier)
		else:
			regular.append(soldier)
	for i in mini(6, regular.size()):
		var soldier: Dictionary = regular[i]
		var home := Vector3(PLOTS["barracks"]) + Vector3(-4 + (i % 3) * 4, 0.1, 0.3 + (i / 3) * 2.5)
		var f := _fighter(soldier)
		_register(f, home, "soldier", int(soldier["id"]))
		f.rotation.y = -0.4 if i % 2 == 0 else 0.4
		if i % 2 == 0 and f.anim != null and f.anim.has_animation("Idle_Talking"):
			f.clip["idle"] = "Idle_Talking"
			f._state = ""
			f.set_motion(false)
	if lg.camp_built("drill"):
		for i in 3:
			var f := LegionFighter.create("legionary" if i != 1 else "spearman", 1.3, 80 + i)
			_register(f, Vector3(PLOTS["drill"]) + Vector3(-3.5 + i * 3.5, 0.1, 1.0), "drill")
			f.rotation.y = PI
	if lg.camp_built("forge"):
		_civilian(Vector3(PLOTS["forge"]) + Vector3(-1, 0.1, 1.4), "smith", "Interact")
	if lg.camp_built("mars"):
		_civilian(Vector3(PLOTS["mars"]) + Vector3(0, 0.1, 3), "priest", "Pray")
	if lg.camp_built("store"):
		_civilian(Vector3(PLOTS["store"]) + Vector3(0, 0.1, 1), "carrier", "Walk_Loop")
	for slot: String in scaffolds:
		_civilian(Vector3(PLOTS[slot]) + Vector3(6, 0.1, 3.5), "builder", "Interact")


func recruit_walk(sid: int) -> void:
	arrivals[sid] = 0.0
	_people()
	for entry: Dictionary in figures:
		if int(entry["id"]) == sid:
			(entry["node"] as Node3D).position = GATE


func _process(dt: float) -> void:
	if not active:
		return
	_accum += dt
	if _accum < 1.0 / 30.0:
		return
	var step := minf(_accum, 0.1)
	_accum = 0.0
	_clock += step
	for sid: int in arrivals.keys():
		arrivals[sid] = float(arrivals[sid]) + step
	for entry: Dictionary in figures:
		var node: Node3D = entry["node"]
		var role := String(entry["role"])
		var sid := int(entry["id"])
		var phase := float(entry["phase"])
		if arrivals.has(sid):
			var t := clampf(float(arrivals[sid]) / WALK_TIME, 0, 1)
			var home: Vector3 = entry["home"]
			node.position = GATE.lerp(home, t)
			var direction := home - GATE
			node.rotation.y = atan2(direction.x, direction.z)
			(node as LegionFighter).set_motion(t < 1.0, direction.length() / WALK_TIME)
			if t >= 1.0:
				arrivals.erase(sid)
		elif role == "carrier":
			var home: Vector3 = entry["home"]
			var t := fposmod(_clock * 0.6, 8.0)
			node.position = home + Vector3(-2 + (t if t < 4 else 8 - t), 0, 0)
			node.rotation.y = PI / 2 if t < 4 else -PI / 2
		elif role == "priest":
			node.rotation.x = 0.025 * sin(_clock * 1.3)
		if node is LegionFighter:
			var f := node as LegionFighter
			if role == "drill" and fposmod(_clock + phase, 2.3) < step:
				f.attack()
			f.tick(step)
		for ap: AnimationPlayer in entry["players"]:
			ap.advance(step)
	# При быстром призыве видны лишь шесть последних; остальные тоже доходят.
	for sid: int in arrivals.keys():
		if float(arrivals[sid]) >= WALK_TIME:
			arrivals.erase(sid)


func project(slot: String, height := 0.0) -> Vector2:
	var point: Vector3 = GATE if slot == "gate" else Vector3(PLOTS.get(slot, Vector3.ZERO))
	return camera.unproject_position(point + Vector3(0, height, 0)) * size / Vector2(sub.size)


func footprint(slot: String) -> Rect2:
	var center: Vector3 = PLOTS[slot]
	var rect := Rect2(camera.unproject_position(center), Vector2.ZERO)
	for x: float in [-6.5, 6.5]:
		for z: float in [-5.0, 5.0]:
			rect = rect.expand(camera.unproject_position(center + Vector3(x, 0, z)))
	return Rect2(rect.position * size / Vector2(sub.size), rect.size * size / Vector2(sub.size))


func highlight(slot: String) -> void:
	for key: String in highlights:
		var mesh: MeshInstance3D = highlights[key]
		var mat := mesh.mesh.surface_get_material(0) as StandardMaterial3D
		mat.emission_enabled = key == slot
		mat.emission = Color("d1a34a")
		mat.emission_energy_multiplier = 0.32
		mesh.visible = lg.camp_built(key) or key == slot


func _pick(pos: Vector2) -> String:
	var pixel := pos * Vector2(sub.size) / size
	var origin := camera.project_ray_origin(pixel)
	var ray := camera.project_ray_normal(pixel)
	if absf(ray.y) < 0.001:
		return ""
	var point := origin + ray * (-origin.y / ray.y)
	for slot: String in PLOTS:
		var offset := point - Vector3(PLOTS[slot])
		if absf(offset.x) <= 6.5 and absf(offset.z) <= 5:
			return slot
	return ""


func _gui_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom = clampf(zoom * (0.90 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.11), MIN_ZOOM, MAX_ZOOM)
			_update_camera()
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
			_dragging = mb.pressed
			if mb.pressed:
				_drag_distance = 0.0
			elif mb.button_index == MOUSE_BUTTON_LEFT and _drag_distance < 5:
				var slot := _pick(mb.position)
				if slot != "":
					building_pressed.emit(slot)
		accept_event()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _dragging and (motion.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_MIDDLE)) != 0:
			_drag_distance += motion.relative.length()
			focus.x -= motion.relative.x * zoom / maxf(1, size.y)
			focus.z -= motion.relative.y * zoom / maxf(1, size.y) * 1.4
			focus.x = clampf(focus.x, -22, 22)
			focus.z = clampf(focus.z, -16, 16)
			_update_camera()
		else:
			_dragging = false
			highlight(_pick(motion.position))
		accept_event()


func focus_plot(slot: String, close_view := true) -> void:
	focus = Vector3(PLOTS.get(slot, Vector3.ZERO)) if close_view else Vector3.ZERO
	zoom = MIN_ZOOM if close_view else DEFAULT_ZOOM
	_update_camera()


func _update_camera() -> void:
	if camera == null:
		return
	camera.size = zoom
	camera.position = focus + Vector3(8, 66, 60)
	camera.look_at(focus, Vector3.UP)
	view_changed.emit()


func shutdown() -> void:
	active = false
	set_process(false)
	process_mode = Node.PROCESS_MODE_DISABLED
	if sub != null:
		sub.render_target_update_mode = SubViewport.UPDATE_DISABLED
	hide()
