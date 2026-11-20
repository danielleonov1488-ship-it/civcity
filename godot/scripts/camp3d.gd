class_name Camp3D
extends SubViewportContainer
## Растущий форт: стабильные участки, общий пул деталей, отдельный мир.

signal building_pressed(slot: String)
signal view_changed

const SCENERY := preload("res://scripts/camp_scenery.gd")
const ArcheryPose = preload("res://scripts/legion_ranged_pose.gd")
const MAX_FIGURES := 16
const DEFAULT_ZOOM := 48.0
const MIN_ZOOM := 18.0
const MAX_ZOOM := 72.0
const WALK_TIME := 9.0
var plots: Dictionary = {}
var bounds := Rect2(-16, -20, 32, 52)
var gate := Vector3.ZERO
var overview := Vector3.ZERO
var default_zoom := DEFAULT_ZOOM
var max_zoom := MAX_ZOOM
var scenery: Node3D
var structures: Node3D
var props: Parts
var kit_batches: Dictionary = {}
var corner_towers: Array[Vector3] = []
var _expansion := -1

var lg: Legion
var city_game: Node
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


func setup(legion: Legion, game: Node) -> bool:
	lg = legion
	city_game = game
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
	sub.screen_space_aa = get_viewport().screen_space_aa
	sub.use_taa = get_viewport().use_taa
	sub.gui_disable_input = true
	add_child(sub)
	world = Node3D.new()
	world.name = "CampScene"
	world.position = SCENERY.ORIGIN
	sub.add_child(world)
	_light()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.far = 320.0
	world.add_child(camera)
	camera.current = true
	active = true
	sync()
	resized.connect(_update_camera)
	mouse_exited.connect(func(): highlight(""))
	return true


func _light() -> void:
	SCENERY.lighting(world, sub, city_game)


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
	if not model.begins_with("#mil_") and not Synty.has(model):
		return null
	# Реквизит всей крепости в одном пуле; предметы в руках остаются у костей.
	if is_instance_valid(props) and structures.is_ancestor_of(parent):
		var xf := Transform3D(Basis(Vector3.UP, yaw).scaled_local(Vector3.ONE * scale_v), pos)
		props.place_one(model, props.global_transform.affine_inverse() * parent.global_transform * xf)
		return null
	var node: Node3D
	if model.begins_with("#mil_"):
		var mi := MeshInstance3D.new()
		mi.mesh = CatMilitary.kit_mesh(model)
		node = mi
	else:
		node = Synty.make(model)
	parent.add_child(node)
	node.position = pos
	node.scale = Vector3.ONE * scale_v
	node.rotation.y = yaw
	return node


func _ground() -> void:
	if is_instance_valid(scenery):
		scenery.free()
	scenery = Node3D.new()
	scenery.name = "FortLandscape"
	world.add_child(scenery)
	SCENERY.terrain(scenery, city_game, plots, bounds)
	SCENERY.surroundings(scenery, plots, bounds)
	SCENERY.river(scenery, bounds)


func _crate(parent: Node3D, pos: Vector3) -> void:
	if structures.is_ancestor_of(parent):
		if not kit_batches.has("crate"):
			kit_batches["crate"] = []
		kit_batches["crate"].append(structures.global_transform.affine_inverse() * parent.global_transform * Transform3D(Basis.IDENTITY, pos))
	else:
		var node := MeshInstance3D.new()
		node.mesh = SCENERY.kit_meshes("crate")[0]["mesh"]
		node.position = pos
		parent.add_child(node)


func sync() -> void:
	if not active:
		return
	lg._fort_init()
	var state: Array = [lg.fort.get("exp", 0), not (lg.fort.get("up", {}) as Dictionary).is_empty()]
	for plot: Dictionary in lg.fort.get("plots", []):
		state.append([plot["id"], plot["b"], plot["lv"], plot["up"]])
	var sig := str(state)
	if sig != _building_sig:
		_building_sig = sig
		var expanded := _expansion != int(lg.fort.get("exp", 0))
		_expansion = int(lg.fort.get("exp", 0))
		_layout_fort()
		if is_instance_valid(structures):
			structures.free()
		structures = Node3D.new()
		structures.name = "FortStructures"
		world.add_child(structures)
		props = Parts.new()
		props.name = "FortProps"
		props.tint_split = Parts.split_on
		structures.add_child(props)
		buildings.clear()
		highlights.clear()
		scaffolds.clear()
		kit_batches.clear()
		if expanded:
			_ground()
		_walls()
		for plot: Dictionary in lg.fort["plots"]:
			_build_plot(plot)
		SCENERY.flush_kit(structures, kit_batches)
		_people_sig = ""
		if expanded:
			focus = overview
			zoom = _fit_zoom()
		_update_camera()
	var roster: Array = []
	for soldier: Dictionary in lg.soldiers:
		roster.append([soldier["id"], soldier.get("gear", {}), soldier.get("hero", false)])
	var people_sig := str([roster, lg.items, lg.hero_level(), Hero.look(lg.city())])
	if people_sig != _people_sig:
		_people_sig = people_sig
		_people()
	if bool(lg.flags.get("march_in", false)):
		_march_in()


func _build_plot(plot: Dictionary) -> void:
	var key := "plot_%d" % int(plot["id"])
	var type := String(plot["b"])
	var level := int(plot["lv"])
	var root := Node3D.new()
	root.name = "Plot_%d" % int(plot["id"])
	root.position = plots[key]
	structures.add_child(root)
	buildings[key] = root
	root.set_meta("plot_id", int(plot["id"]))
	root.set_meta("stage", "empty" if type == "" else ("tent" if level <= 2 else ("timber" if level <= 5 else "stone")))
	var base := _box(root, Vector3(0, 0.035, 0), Vector3(9, 0.07, 9), Color("c9b68c"))
	base.name = "Foundation"
	(base.mesh as PrimitiveMesh).material = SCENERY.floor_material(type)
	highlights[key] = base
	SCENERY.foundation(root, type == "", props)
	if type != "":
		if level <= 2:
			_tents(root, type)
		elif type != "drill":
			var shell := Node3D.new()
			shell.name = "Pavilion"
			root.add_child(shell)
			shell.scale = Vector3(0.62, 0.85, 0.8)
			SCENERY.pavilion(shell, type, level <= 5, props)
			root.set_meta("cutaway", true)
			root.set_meta("city_piece_count", shell.get_meta("city_piece_count", 0))
		var interior := Node3D.new()
		interior.name = "Interior"
		root.add_child(interior)
		interior.scale = Vector3.ONE * 0.65
		interior.position.z = 1.3 if level <= 2 else 0.0
		_interior(interior, type)
		# Каждый уровень добавляет припасы, после первого — знамёна.
		for i in mini(level, 8):
			_prop(root, "SM_Prop_Sack_01" if i % 2 == 0 else "SM_Prop_Jar_01", Vector3(-3.8 + (i % 4) * 0.7, 0.1, -3.5 + (i / 4) * 0.9), 0.6)
		if level >= 2:
			_prop(root, "#mil_standard", Vector3(3.6, 0.1, 2.6), 0.85)
		if level >= 5:
			_prop(root, "#mil_standard", Vector3(-3.6, 0.1, 2.6), 0.85)
		if level >= 7:
			_prop(root, "#mil_eagle", Vector3(0, 0.1, -3.7), 0.8)
	if not (plot["up"] as Dictionary).is_empty():
		_scaffold(root, key)


func _tents(root: Node3D, type: String) -> void:
	if type == "barracks":
		for x: float in [-2.1, 2.1]:
			_kit("tent_small", root.position + Vector3(x, 0.08, -1.3), 0, Vector3.ONE * 0.82)
	elif type in ["kitchen", "store", "arsenal", "infirmary"]:
		_kit("tent_long", root.position + Vector3(0, 0.08, -1.8), PI / 2, Vector3.ONE * 0.8)
	elif type == "hq":
		_kit("tent_command", root.position + Vector3(0, 0.08, -0.6))
	elif type != "drill":
		_kit("tent_small", root.position + Vector3(0, 0.08, -1.8))


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
			var kit := Kit.new()
			for x: float in [-4.1, 0.0, 4.1]:
				for y: float in [0.48, 1.85]:
					kit.boxc(Vector3(x, y, -0.9), Vector3(2.5, 0.2, 2.1), Color("775636"))
					kit.boxc(Vector3(x, y + 0.17, -0.9), Vector3(2.3, 0.18, 1.9), Color("b89b77"))
					kit.boxc(Vector3(x - 0.8, y + 0.3, -0.9), Vector3(0.5, 0.15, 1.4), Color("eee0bb"))
					kit.boxc(Vector3(x + 0.5, y + 0.28, -0.9), Vector3(0.7, 0.04, 1.9), Color("9e4436"))
				for dx: float in [-1.3, 1.3]:
					for z: float in [-1.8, 0]:
						kit.boxc(Vector3(x + dx, 1.2, z), Vector3(0.12, 2.4, 0.12), Color("775636"))
			var bunks := MeshInstance3D.new()
			bunks.name = "Bunks"
			bunks.mesh = kit.mesh()
			bunks.material_override = Kit.material(0.9)
			root.add_child(bunks)
		"forge":
			_prop(root, "SM_Prop_Forge_01", Vector3(3.4, 0.1, -0.7), 1.4, -PI / 2)
			_prop(root, "SM_Prop_Anvil_01", Vector3(-1, 0.1, 0), 1.3)
			_prop(root, "#mil_ingots", Vector3(-4, 0.1, -2), 1.6)
			var ember := _box(root, Vector3(3.1, 0.8, -0.4), Vector3(0.8, 0.2, 0.7), Color("f48838"))
			var mat := ember.mesh.surface_get_material(0) as StandardMaterial3D
			mat.emission_enabled = true
			mat.emission = Color("ff6b22")
			mat.emission_energy_multiplier = 2.0
			var fire := OmniLight3D.new()
			fire.position = Vector3(3, 1.5, -1)
			fire.light_color = Color("ff9c40")
			fire.light_energy = 1.8
			fire.omni_range = 6
			fire.shadow_enabled = false
			root.add_child(fire)
		"mars":
			_box(root, Vector3(0, 0.65, -0.9), Vector3(3, 1.3, 2), Color("c9ba9b"))
			_prop(root, "SM_Prop_Statue_01", Vector3(0, 1.3, -0.9), 1.1)
			_box(root, Vector3(0, 0.6, 1), Vector3(2.7, 1.2, 1.3), Color("e6d8b7"))
			_prop(root, "SM_Prop_Jar_01", Vector3(3, 0.1, -1), 1.3)
			_prop(root, "SM_Prop_Brazier_03", Vector3(0, 1.2, 1), 0.65)
			_prop(root, "SM_Prop_Brazier_03_Insert_01", Vector3(0, 1.2, 1), 0.65)
			var embers := _box(root, Vector3(0, 1.8, 1), Vector3(0.4, 0.12, 0.4), Color("ff9c40"))
			var glow := embers.mesh.surface_get_material(0) as StandardMaterial3D
			glow.emission_enabled = true
			glow.emission = Color("ff7926")
			glow.emission_energy_multiplier = 2.0
			var altar_light := OmniLight3D.new()
			altar_light.name = "AltarFire"
			altar_light.position = Vector3(0, 2.1, 1)
			altar_light.light_color = Color("ffac58")
			altar_light.light_energy = 0.7
			altar_light.omni_range = 4
			altar_light.shadow_enabled = false
			root.add_child(altar_light)
		"store":
			for i in 4:
				_crate(root, Vector3(-3.8 + i * 1.6, 0.7, -0.8))
			_crate(root, Vector3(-2.2, 1.9, -0.8))
			for i in 3:
				_prop(root, "SM_Prop_Jar_01", Vector3(2 + i, 0.1, 1.5), 1.1)
			_prop(root, "SM_Prop_Sack_Stack_01", Vector3(-4, 0.1, 2.4), 1.1)
		"drill":
			var stand := _box(root, Vector3(4.6, 0.3, -2), Vector3(2.6, 0.6, 2.4), Color("98714d"))
			stand.name = "CommanderStand"
			_prop(root, "#mil_standard", Vector3(5.2, 0.6, -2.7), 0.9)
			for x: float in [-3.5, 0.0, 3.5]:
				_prop(root, "#mil_dummy", Vector3(x, 0.1, -1), 1.25)
			_prop(root, "SM_Prop_Weapon_Rack_01", Vector3(-5, 0.1, 3), 1.0)
			_prop(root, "SM_Prop_Weapon_Rack_01_Insert_01", Vector3(-5, 0.1, 3), 1.0)

		"kitchen":
			SCENERY.cauldron(root)
			_prop(root, "SM_Prop_Table_04", Vector3(-3.6, 0.1, 0), 1.0)
			_prop(root, "SM_Prop_Jar_01", Vector3(3.2, 0.1, 1), 1.2)
		"smelter":
			_prop(root, "SM_Prop_Forge_01", Vector3(1.5, 0.1, -0.5), 1.3)
			_prop(root, "#mil_ingots", Vector3(-2, 0.1, 2), 1.3)
		"sawmill":
			_prop(root, "#mil_logs", Vector3(-2, 0.1, 0), 1.5)
			_prop(root, "SM_Prop_Table_04", Vector3(2.3, 0.1, 1), 1.2)
		"tannery":
			_prop(root, "#mil_hides", Vector3(-1.5, 0.1, 0), 1.6)
			_prop(root, "SM_Prop_Jar_01", Vector3(3, 0.1, 1.5), 1.2)
		"infirmary":
			for x: float in [-2, 2]:
				_prop(root, "SM_Prop_Seat_Kline_02", Vector3(x, 0.1, 0))
		"arsenal":
			for x: float in [-2.5, 2.5]:
				_prop(root, "SM_Prop_Weapon_Rack_02", Vector3(x, 0.1, 0))
		"treasury":
			_crate(root, Vector3(-2, 0.7, 0))
			_prop(root, "#mil_ingots", Vector3(1.5, 0.1, 1.5), 1.2)
		"stable":
			_prop(root, "SM_Prop_Sack_Stack_01", Vector3(-3, 0.1, 1), 1.5)
			_prop(root, "#mil_logs", Vector3(2, 0.1, 1), 1.2)
		"tower":
			_prop(root, "#mil_standard", Vector3(0, 0.1, 0), 1.6)


func _scaffold(root: Node3D, slot: String) -> void:
	var scaffold := Node3D.new()
	scaffold.name = "Scaffolding"
	scaffold.scale = Vector3(0.66, 0.8, 0.8)
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
	if figures.size() >= MAX_FIGURES:
		node.free()
		return
	world.add_child(node)
	node.position = pos
	var players := _manual_animations(node)
	var entry := {"node": node, "home": pos, "role": role, "id": sid, "phase": figures.size() * 0.61, "players": players}
	var fighter := node as LegionFighter
	if fighter != null and fighter.style == "bow":
		fighter.offhand.hide()
		fighter.clip["idle"] = "Idle"
		fighter.set_motion(false)
		fighter.anim.advance(0.0)
		var archery := ArcheryPose.new(fighter.skel, fighter.body, "bow")
		archery.apply(ArcheryPose.BOW_IDLE, 0.0)
		entry["archery"] = archery
	figures.append(entry)


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
			_register(hero, _position("hq") + Vector3(0, 0.1, 2.3), "hero", int(soldier["id"]))
			hero.rotation.y = PI
			hero_added = true
		elif arrivals.has(int(soldier["id"])):
			regular.push_front(soldier)
		else:
			regular.append(soldier)
	for i in mini(6, regular.size()):
		var soldier: Dictionary = regular[i]
		var home := _position("barracks") + Vector3(-2.5 + (i % 3) * 2.5, 0.1, 2.0 + (i / 3) * 1.3)
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
			_register(f, _position("drill") + Vector3(-2.3 + i * 2.3, 0.1, 1.0), "drill")
			f.rotation.y = PI
	if lg.camp_built("forge"):
		_civilian(_position("forge") + Vector3(-1, 0.1, 1.4), "smith", "Interact")
	if lg.camp_built("mars"):
		_civilian(_position("mars") + Vector3(0, 0.1, 3), "priest", "Pray")
	if lg.camp_built("store"):
		_civilian(_position("store") + Vector3(0, 0.1, 1), "carrier", "Walk_Loop")
	if lg.camp_built("kitchen"):
		_civilian(_position("kitchen") + Vector3(0, 0.1, 2.8), "cook", "Interact")
	for slot: String in scaffolds:
		var scaffold: Node3D = scaffolds[slot]
		_civilian(world.to_local(scaffold.global_position) + Vector3(3.8, 0.1, 2.8), "builder", "Interact")
	for entry: Dictionary in figures:
		var sid := int(entry["id"])
		if arrivals.has(sid):
			(entry["node"] as Node3D).position = _arrival_position(entry["home"], float(arrivals[sid]) / WALK_TIME)


func recruit_walk(sid: int) -> void:
	arrivals[sid] = 0.0
	_people()
	for entry: Dictionary in figures:
		if int(entry["id"]) == sid:
			(entry["node"] as Node3D).position = _arrival_position(entry["home"], 0.0)


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
		var archery: ArcheryPose = entry.get("archery")
		var sid := int(entry["id"])
		var phase := float(entry["phase"])
		if arrivals.has(sid):
			var t := minf(float(arrivals[sid]) / WALK_TIME, 1)
			var home: Vector3 = entry["home"]
			node.position = _arrival_position(home, t)
			var direction := _arrival_position(home, minf(t + 0.01, 1.0)) - node.position
			node.rotation.y = atan2(direction.x, direction.z)
			(node as LegionFighter).set_motion(t < 1.0, maxf(1.0, gate.distance_to(home) / WALK_TIME))
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
			if archery == null and role == "drill" and fposmod(_clock + phase, 2.3) < step:
				f.attack()
			f.tick(step)
		for ap: AnimationPlayer in entry["players"]:
			ap.advance(step)
		if archery != null:
			var t := fposmod(_clock + phase, 2.3)
			var walking: bool = (node as LegionFighter)._moving
			var practice := not walking and role == "drill" and t < float(ArcheryPose.LENGTHS[ArcheryPose.BOW])
			archery.apply(ArcheryPose.BOW if practice else ArcheryPose.BOW_IDLE, t, 0.0 if walking else 1.0)
	# При быстром призыве видны лишь шесть последних; остальные тоже доходят.
	for sid: int in arrivals.keys():
		if float(arrivals[sid]) >= WALK_TIME:
			arrivals.erase(sid)


func project(slot: Variant, height := 0.0) -> Vector2:
	return camera.unproject_position(world.to_global(_position(String(slot)) + Vector3(0, height, 0))) * size / Vector2(sub.size)


func footprint(slot: String) -> Rect2:
	var center := _position(slot)
	var rect := Rect2(camera.unproject_position(world.to_global(center)), Vector2.ZERO)
	for x: float in [-4.5, 4.5]:
		for z: float in [-4.5, 4.5]:
			rect = rect.expand(camera.unproject_position(world.to_global(center + Vector3(x, 0, z))))
	return Rect2(rect.position * size / Vector2(sub.size), rect.size * size / Vector2(sub.size))


func highlight(slot: String) -> void:
	for key: String in highlights:
		var mesh: MeshInstance3D = highlights[key]
		var mat := mesh.mesh.surface_get_material(0) as StandardMaterial3D
		mat.emission_enabled = slot != "" and key == _key(slot)
		mat.emission = Color("d1a34a")
		mat.emission_energy_multiplier = 0.32
		mesh.visible = true


func _pick(pos: Vector2) -> String:
	var pixel := pos * Vector2(sub.size) / size
	var origin := camera.project_ray_origin(pixel)
	var ray := camera.project_ray_normal(pixel)
	if absf(ray.y) < 0.001:
		return ""
	var point := world.to_local(origin + ray * ((world.global_position.y - origin.y) / ray.y))
	if absf(point.x) < 2.75 and absf(point.z - gate.z) < 3.0:
		return "gate"
	for slot: String in plots:
		var offset := point - _position(slot)
		if absf(offset.x) <= 4.5 and absf(offset.z) <= 4.5:
			return slot
	return ""


func _gui_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom = clampf(zoom * (0.90 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.11), MIN_ZOOM, max_zoom)
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
			focus.x = clampf(focus.x, bounds.position.x, bounds.end.x)
			focus.z = clampf(focus.z, bounds.position.y, bounds.end.y)
			_update_camera()
		else:
			_dragging = false
			highlight(_pick(motion.position))
		accept_event()


func focus_plot(slot: String, close_view := true) -> void:
	focus = _position(slot) if close_view else overview
	zoom = MIN_ZOOM if close_view else _fit_zoom()
	_update_camera()


func _update_camera() -> void:
	if camera == null:
		return
	var was_overview := is_equal_approx(zoom, default_zoom)
	default_zoom = _fit_zoom()
	if was_overview:
		zoom = default_zoom
	max_zoom = default_zoom * 1.5
	zoom = clampf(zoom, MIN_ZOOM, max_zoom)
	focus.x = clampf(focus.x, bounds.position.x, bounds.end.x)
	focus.z = clampf(focus.z, bounds.position.y, bounds.end.y)
	camera.size = zoom
	var distance := maxf(90.0, zoom * 1.4)
	camera.far = maxf(320.0, distance * 4.0)
	camera.position = focus + Vector3(0.08, 0.74, 0.67).normalized() * distance
	camera.look_at(world.to_global(focus), Vector3.UP)
	view_changed.emit()


func shutdown() -> void:
	active = false
	set_process(false)
	process_mode = Node.PROCESS_MODE_DISABLED
	if sub != null:
		sub.render_target_update_mode = SubViewport.UPDATE_DISABLED
	hide()


## Порядок не зависит от числа открытых участков: расширение не двигает здания.
static func grid_positions(count: int) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]
	var columns := 1
	var rows := 3
	while cells.size() * 2 < count:
		if columns * 2 < rows:
			for row in rows:
				cells.append(Vector2i(columns, row))
			columns += 1
		else:
			for column in columns:
				cells.append(Vector2i(column, rows))
			rows += 1
	for cell: Vector2i in cells:
		for side: float in [-1, 1]:
			if result.size() < count:
				result.append(Vector3(side * (8 + cell.x * 12), 0, cell.y * 12))
	return result


func _layout_fort() -> void:
	plots.clear()
	var count := maxi(int(Legion.fort_exp_info(_expansion)["plots"]), (lg.fort["plots"] as Array).size() - 1)
	var positions := grid_positions(count)
	var extent := Rect2(-8, -20, 16, 16)
	for p: Vector3 in positions:
		extent = extent.expand(Vector2(p.x - 8, p.z - 8)).expand(Vector2(p.x + 8, p.z + 8))
	bounds = extent
	var index := 0
	for plot: Dictionary in lg.fort["plots"]:
		var id := int(plot["id"])
		plots["plot_%d" % id] = Vector3(0, 0, -12) if id == 0 else positions[index]
		if id != 0:
			index += 1
	gate = Vector3(0, 0.1, bounds.end.y)
	overview = Vector3(0, 0, bounds.get_center().y)


func _key(slot: String) -> String:
	if plots.has(slot) or slot == "gate":
		return slot
	var plot := lg.fort_slot_plot(slot)
	return "plot_%d" % int(plot.get("id", 0))


func _position(slot: String) -> Vector3:
	return gate if slot == "gate" else Vector3(plots.get(_key(slot), Vector3.ZERO))


func _fit_zoom() -> float:
	var aspect := maxf(0.4, size.x / maxf(1, size.y))
	return maxf((bounds.size.x + 20) / aspect, (bounds.size.y + 20) * 0.75 + 12) * 1.12


func _kit(piece: String, pos: Vector3, yaw := 0.0, scale_v := Vector3.ONE) -> void:
	if not kit_batches.has(piece):
		kit_batches[piece] = []
	kit_batches[piece].append(Transform3D(Basis(Vector3.UP, yaw).scaled_local(scale_v), pos))


func _wall_run(a: Vector3, b: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	var length := a.distance_to(b)
	var n := ceili(length / 2.0)
	for i in n:
		var p := a.lerp(b, (i + 0.5) / n)
		p.y = 1.2 + rng.randf_range(-0.04, 0.04)
		_kit("palisade_seg" if i % 2 == 0 else "palisade_seg_b", p,
			yaw + deg_to_rad(rng.randf_range(-2, 2)), Vector3(length / n / 2.0 + 0.025, 1, 1))


func _walls() -> void:
	corner_towers.clear()
	var left := bounds.position.x
	var right := bounds.end.x
	var back := bounds.position.y
	var front := bounds.end.y
	var rng := RandomNumberGenerator.new()
	rng.seed = 7311
	_wall_run(Vector3(left, 0, back), Vector3(right, 0, back), PI, rng)
	_wall_run(Vector3(left, 0, front), Vector3(-2.7, 0, front), 0, rng)
	_wall_run(Vector3(2.7, 0, front), Vector3(right, 0, front), 0, rng)
	_wall_run(Vector3(left, 0, back), Vector3(left, 0, front), -PI / 2, rng)
	_wall_run(Vector3(right, 0, back), Vector3(right, 0, front), PI / 2, rng)
	for x: float in [left, right]:
		for z: float in [back, front]:
			var p := Vector3(x, 1.2, z)
			corner_towers.append(p)
			_kit("tower", p)
	# Малый форт — четыре башни; затем дополнительные через ~30 м.
	if _expansion > 0:
		for x: float in [left, right]:
			var depth_sections := ceili(bounds.size.y / 30.0)
			for i in range(1, depth_sections):
				_kit("tower", Vector3(x, 1.2, lerpf(back, front, float(i) / depth_sections)))
		var width_sections := ceili(bounds.size.x / 30.0)
		for i in range(1, width_sections):
			var x := lerpf(left, right, float(i) / width_sections)
			_kit("tower", Vector3(x, 1.2, back))
			if absf(x) > 5.0:
				_kit("tower", Vector3(x, 1.2, front))
	_kit("gate", gate - Vector3(0, 0.1, 0))
	_kit("bridge", gate + Vector3(0, -0.485, 3))
	for z: float in [back - 4.4, front + 4.4]:
		for i in int(bounds.size.x / 4):
			var x := left + 2 + i * 4
			if z > 0 and absf(x) < 4:
				continue
			if i % 4 != 3:
				_kit("stakes_row", Vector3(x, 0, z), PI if z < 0 else 0)
	for x: float in [left - 4.4, right + 4.4]:
		for i in int(bounds.size.y / 4):
			if i % 4 != 3:
				_kit("stakes_row", Vector3(x, 0, back + 2 + i * 4), PI / 2)
	if not (lg.fort.get("up", {}) as Dictionary).is_empty():
		var work := Node3D.new()
		work.name = "WallWorks"
		work.position = Vector3(right - 4, 0, front - 6)
		structures.add_child(work)
		_scaffold(work, "gate")
	_sentries()


func _sentries() -> void:
	var guards := Node3D.new()
	guards.name = "TowerSentries"
	structures.add_child(guards)
	for i in corner_towers.size():
		for side: float in [-1, 1]:
			var soldier := LegionFighter.create("spearman", 1.0, 910 + i * 2 + int(side > 0))
			guards.add_child(soldier)
			soldier.position = corner_towers[i] + Vector3(side * 0.65, 7.85, 0)
			soldier.rotation.y = PI if i % 2 == 0 else 0.0
			soldier.set_motion(false)
			for player: AnimationPlayer in _manual_animations(soldier):
				player.advance(0.25 + i * 0.13)
			# Замороженная поза: часовые не расходуют лимит анимированных фигур.
			soldier.process_mode = Node.PROCESS_MODE_DISABLED


func _march_in() -> void:
	lg.flags.erase("march_in")
	var index := 0
	for value: Variant in lg.squad3:
		var sid := int(value)
		if sid != 0 and not lg.soldier(sid).is_empty():
			arrivals[sid] = -index * 0.8
			index += 1
	_people()
	for entry: Dictionary in figures:
		if arrivals.has(int(entry["id"])):
			(entry["node"] as Node3D).position = _arrival_position(entry["home"], float(arrivals[int(entry["id"])]) / WALK_TIME)


func _arrival_position(home: Vector3, t: float) -> Vector3:
	# Мост, главная дорога, поперечная дорожка, вход на участок.
	var start := gate + Vector3(0, 0, 6)
	var row_path := roundf(home.z / 12.0) * 12.0 + 6.0
	var turn := Vector3(0, 0.1, row_path)
	var entrance := Vector3(home.x, 0.1, row_path)
	var first := start.distance_to(turn)
	var second := turn.distance_to(entrance)
	var third := entrance.distance_to(home)
	var distance := t * (first + second + third)
	if distance <= first:
		return start.lerp(turn, distance / maxf(0.01, first))
	if distance <= first + second:
		return turn.lerp(entrance, (distance - first) / maxf(0.01, second))
	return entrance.lerp(home, (distance - first - second) / maxf(0.01, third))
