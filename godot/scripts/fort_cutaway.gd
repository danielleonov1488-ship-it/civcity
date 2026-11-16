class_name FortCutaway
extends Camp3D

signal person_pressed(sid: int, newcomer: bool)
signal person_moved(sid: int, plot_id: int)
signal move_finished

const PersonPreview = preload("res://scripts/fort_person_preview.gd")
## Рисованный разрез: комнаты в XY, живые люди перед живописью.

const ART := "res://assets/fort/cutaway/"
const CELL := Vector2(6.0, 4.0)
const CLOSE_ZOOM := 4.0 / 0.6
const ROOM_ART := {"hq": "praetorium", "barracks": "barracks", "kitchen": "kitchen",
	"store": "granary", "forge": "forge", "arsenal": "armory", "infirmary": "infirmary",
	"mars": "shrine", "smelter": "smelter", "sawmill": "carpentry", "tannery": "tannery",
	"treasury": "treasury", "drill": "barracks", "stable": "barracks", "tower": "armory"}
const GRIDS := [Vector2i(3, 2), Vector2i(3, 3), Vector2i(4, 3), Vector2i(4, 4), Vector2i(5, 4), Vector2i(5, 5)]
const WORK := {"forge": "Interact", "kitchen": "PickUp_Table", "mars": "Pray",
	"sawmill": "Interact", "smelter": "Interact", "tannery": "Fixing_Kneeling",
	"infirmary": "PickUp_Table", "store": "Idle_Talking", "treasury": "Idle_Talking"}

var room_rects: Dictionary = {}
var room_meshes: Dictionary = {}
var room_stages: Dictionary = {}
var shell: Node3D
var backdrop: MeshInstance3D
var grid := Vector2i(3, 2)
var _textures: Dictionary = {}
var _target_focus := Vector3.ZERO
var _target_zoom := 20.0
var _layout_sig := ""
var _rim_material: ShaderMaterial
var _shadow_material: StandardMaterial3D
var _has_figures := false
var _hover := ""
var drag_sid := 0
var drag_newcomer := false
var drag_ghost: Node3D
var drag_target := -1
var _person_down := 0
var _down_newcomer := false
var _down_pos := Vector2.ZERO
var _click_move := false


static func room_art(type: String) -> String:
	return String(ROOM_ART.get(type, "barracks"))


static func room_icon(type: String) -> Texture2D:
	return load(ART + "icons/" + room_art(type) + ".png") as Texture2D


func setup(legion: Legion, game: Node) -> bool:
	lg = legion
	city_game = game
	name = "FortCutaway"
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not ResourceLoader.exists(ART + "rooms/empty.jpg"):
		return false
	sub = SubViewport.new()
	sub.name = "FortCutawayWorld"
	sub.own_world_3d = true
	sub.size = Vector2i(maxi(1, int(size.x)), maxi(1, int(size.y)))
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub.msaa_3d = Viewport.MSAA_2X
	sub.gui_disable_input = true
	add_child(sub)
	world = Node3D.new()
	world.name = "PaintedFort"
	sub.add_child(world)
	_cutaway_light()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.1
	camera.far = 120.0
	world.add_child(camera)
	camera.current = true
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
void fragment() {
	vec2 d = min(UV, vec2(1.0) - UV);
	float edge = min(d.x, d.y);
	float rim = 1.0 - smoothstep(0.008, 0.035, edge);
	ALBEDO = vec3(1.0, 0.76, 0.35);
	EMISSION = ALBEDO * 0.25;
	ALPHA = rim * 0.48;
}"""
	_rim_material = ShaderMaterial.new()
	_rim_material.shader = shader
	_prepare_shadow()
	_has_figures = Synty.has("SK_Chr_Solider_Male_01") and ResourceLoader.exists("res://assets/people/UAL1_Standard.glb")
	active = true
	sync()
	resized.connect(_resize_view)
	mouse_exited.connect(func(): highlight(""))
	return true


func _cutaway_light() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("95c6ed")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("fff1d7")
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var sky := WorldEnvironment.new()
	sky.environment = environment
	world.add_child(sky)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25, -25, 0)
	light.light_color = Color("fff0da")
	light.light_energy = 0.85
	light.shadow_enabled = false
	world.add_child(light)


func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(ART + path)
	return _textures[path] as Texture2D


func _quad(parent: Node3D, pos: Vector3, dims: Vector2, path: String, alpha := false) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = dims
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _texture(path)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if alpha:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = false
	mesh.material = material
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	node.position = pos
	return node


func sync() -> void:
	if not active:
		return
	lg._fort_init()
	var entries: Array = (lg.fort.get("plots", []) as Array).duplicate()
	entries.sort_custom(func(a: Dictionary, b: Dictionary): return int(a["id"]) < int(b["id"]))
	var layout_data: Array = [lg.fort.get("exp", 0), lg.fort.get("grid", [])]
	var people_data: Array = [lg.fort_newcomers()]
	for p: Dictionary in entries:
		layout_data.append([p["id"], p["b"], p["lv"], (p["up"] as Dictionary).is_empty()])
		people_data.append([p["id"], p.get("workers", []), lg.fort_worker(int(p["id"])).is_empty()])
	for person: Dictionary in lg.soldiers:
		people_data.append([person["id"], lg.s_state(person), person.get("gear", {})])
	var sig := str(layout_data)
	var rebuilt := sig != _layout_sig
	if rebuilt:
		_layout_sig = sig
		_expansion = int(lg.fort.get("exp", 0))
		_build_cutaway(entries)
	if rebuilt or _people_sig != str(people_data):
		_people_sig = str(people_data)
		_people()


func _build_cutaway(entries: Array) -> void:
	for node: Node3D in [structures, shell, backdrop]:
		if is_instance_valid(node):
			node.free()
	structures = Node3D.new()
	structures.name = "Rooms"
	world.add_child(structures)
	shell = Node3D.new()
	shell.name = "Shell"
	world.add_child(shell)
	plots.clear()
	room_rects.clear()
	room_meshes.clear()
	room_stages.clear()
	highlights.clear()
	scaffolds.clear()
	grid = lg.fort_grid()
	# Старые сохранения не обрезаем, даже если участков в них больше.
	while grid.x * grid.y - 1 < entries.size():
		grid.y += 1
	var width := grid.x * CELL.x
	var height := grid.y * CELL.y
	var start := -width * 0.5
	var hq_col := maxi(0, ceili((grid.x - 2) * 0.5))
	var cells: Array[Vector2i] = []
	for row in grid.y:
		var row_cells: Array[int] = []
		for col in grid.x:
			if row == 0 and col in [hq_col, hq_col + 1]:
				continue
			row_cells.append(col)
		row_cells.sort_custom(func(a: int, b: int):
			var da := absf(a - (grid.x - 1) * 0.5)
			var db := absf(b - (grid.x - 1) * 0.5)
			return a < b if is_equal_approx(da, db) else da < db)
		for col: int in row_cells:
			cells.append(Vector2i(col, row))
	var index := 0
	for p: Dictionary in entries:
		var id := int(p["id"])
		var cell := Vector2i(hq_col, 0) if id == 0 else cells[index]
		if id != 0:
			index += 1
		var dims := Vector2(12, 4) if id == 0 else CELL
		var center := Vector2(start + cell.x * CELL.x + dims.x * 0.5, height - (cell.y + 0.5) * CELL.y)
		var key := "plot_%d" % id
		plots[key] = Vector3(center.x, center.y, 0)
		room_rects[id] = Rect2(center - dims * 0.5, dims)
		var building := not (p["up"] as Dictionary).is_empty()
		var level := int(p["lv"])
		var stage := 1 if level < 4 else 2 if level < 8 else 3
		var path := "rooms/empty.jpg" if p["b"] == "" else "rooms/building.jpg" if building else "rooms/%s_%d.jpg" % [room_art(String(p["b"])), stage]
		var room := _quad(structures, Vector3(center.x, center.y, 0), dims, path)
		room.name = "Room_%d" % id
		room_meshes[id] = room
		room_stages[id] = stage
		var rim := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = dims - Vector2(0.05, 0.05)
		mesh.material = _rim_material
		rim.mesh = mesh
		rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		structures.add_child(rim)
		rim.position = room.position + Vector3(0, 0, 0.08)
		rim.visible = false
		highlights[key] = rim
		if building:
			scaffolds[key] = room
	# Пустые декоративные ячейки только у старых нетипичных сохранений.
	for i in range(index, cells.size()):
		var cell: Vector2i = cells[i]
		_quad(structures, Vector3(start + (cell.x + 0.5) * CELL.x, height - (cell.y + 0.5) * CELL.y, 0), CELL, "rooms/empty.jpg")
	for row in grid.y:
		var y := (row + 0.5) * CELL.y
		_quad(shell, Vector3(start, y, 2.0), Vector2(1, 4.1), "shell/wall_left.png", true)
		_quad(shell, Vector3(-start, y, 2.0), Vector2(1, 4.1), "shell/wall_right.png", true)
		for col in range(1, grid.x):
			if row == grid.y - 1 and col == hq_col + 1:
				continue
			_quad(shell, Vector3(start + col * CELL.x, y, 1.9), Vector2(0.375, 4.0), "shell/pillar_mid.png", true)
	for row in range(grid.y + 1):
		for col in grid.x:
			_quad(shell, Vector3(start + (col + 0.5) * CELL.x, row * CELL.y, 2.1), Vector2(6.1, 0.375), "shell/floor_slab.png", true)
	for col in grid.x:
		_quad(shell, Vector3(start + (col + 0.5) * CELL.x, -0.2, 2.2), Vector2(6.1, 0.625), "shell/foundation.png", true)
	var roof_colonnade := _expansion >= 3
	var roof_height := (width + 1.2) * (0.25 if roof_colonnade else 1.0 / 6.0)
	_quad(shell, Vector3(0, height + roof_height * 0.42, 2.3), Vector2(width + 1.2, roof_height), "shell/roof_colonnade.png" if roof_colonnade else "shell/roof.png", true)
	_quad(shell, Vector3(start - 2.7, 4.0, 1.6), Vector2(4.5, 9), "shell/gate_tower.png", true)
	_quad(shell, Vector3(-start + 3.2, 2.5, -0.2), Vector2(6.5, 6.5), "shell/yard_right.png", true)
	bounds = Rect2(start - 5.2, -0.7, width + 12, height + roof_height + 1.4)
	overview = Vector3(bounds.get_center().x, bounds.get_center().y, 0)
	gate = Vector3(start - 2.7, 0.48, 1)
	var bg_width := maxf(90, bounds.size.x * 3)
	backdrop = _quad(world, Vector3(0, height * 0.45, -12), Vector2(bg_width, bg_width * 0.5625), "shell/background.jpg")
	focus = overview
	_target_focus = overview
	default_zoom = _fit_zoom()
	zoom = default_zoom
	_target_zoom = zoom
	_update_camera()


func _prepare_shadow() -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.12, 0.07, 0.025, 0.36), Color(0.12, 0.07, 0.025, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 1.0)
	_shadow_material = StandardMaterial3D.new()
	_shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow_material.albedo_texture = texture


func _add_person(node: Node3D, id: int, sid: int, role: String, x_offset: float) -> void:
	if figures.size() >= MAX_FIGURES:
		node.free()
		return
	world.add_child(node)
	node.set_process(false)
	if room_rects.has(id):
		var rect: Rect2 = room_rects[id]
		node.position = Vector3(rect.get_center().x + x_offset, rect.position.y + CELL.y * 0.12, 1.1)
	else:
		node.position = gate + Vector3(x_offset - 1.4, 0, 2.0) if id == -2 else Vector3(grid.x * CELL.x * 0.5 + 1.2 + fmod(x_offset, 4.05), 0.45 + floorf(x_offset / 4.05) * 1.6, 2.0)
	node.rotation.y = -0.35 if role in ["guard", "hero", "barracks"] else -0.8
	var players: Array = _manual_animations(node)
	for ap: AnimationPlayer in players:
		ap.advance(0.0)
	var shadow := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.9, 0.16)
	mesh.material = _shadow_material
	shadow.mesh = mesh
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(shadow)
	# Тень в плоскости картины, не вращается вместе с человеком.
	shadow.top_level = true
	shadow.global_position = world.to_global(node.position + Vector3(0, 0.01, -0.15))
	figures.append({"node": node, "home": node.position, "role": role, "id": sid, "plot": id, "players": players})


func _room_worker(p: Dictionary, worker: Dictionary, building: bool) -> void:
	if figures.size() >= MAX_FIGURES:
		return
	var type := String(p["b"])
	var sid := int(worker.get("id", 0))
	if not building and type in ["barracks", "tower", "arsenal", "stable", "drill"]:
		_add_person(_fighter(worker), int(p["id"]), sid, "guard", -0.6)
		return
	if not ResourceLoader.exists(Citizen.DIR + Citizen.PLEBS[0] + ".fbx"):
		return
	var citizen := PersonPreview.civilian(worker if not worker.is_empty() else {"id": int(p["id"]) + 409})
	citizen.scale *= 1.6
	var role := "builder" if building else type
	var animation := "Interact" if building else String(WORK.get(type, "Idle"))
	if not citizen.anim.has_animation(animation):
		animation = "Idle"
	citizen.play(animation, 0.0, 0.0)
	_add_person(citizen, int(p["id"]), sid, role, -0.7 if type == "forge" else 0.4)
	if building or type in ["forge", "sawmill", "kitchen"]:
		var skeletons := citizen.find_children("*", "Skeleton3D", true, false)
		if not skeletons.is_empty():
			var hand := BoneAttachment3D.new()
			hand.bone_name = "RightHand"
			skeletons[0].add_child(hand)
			var tool := "SM_Prop_Tool_Hammer_01" if building or type == "forge" else "SM_Prop_Tool_Saw_01" if type == "sawmill" else "SM_Prop_Tool_Spoon_01"
			if Synty.has(tool):
				_prop(hand, tool, Vector3.ZERO)


func _people() -> void:
	for entry: Dictionary in figures:
		(entry["node"] as Node).free()
	figures.clear()
	if not _has_figures:
		return
	var gate_index := 0
	for person: Dictionary in lg.fort_newcomers():
		var node := PersonPreview.civilian(person)
		node.scale *= 1.6
		_add_person(node, -2, int(person["id"]), "newcomer", gate_index * 1.35)
		var marker := Label3D.new()
		marker.text = "!"
		marker.font_size = 80
		marker.pixel_size = 0.01
		marker.modulate = Color("ffd77a")
		marker.outline_modulate = Color("49351e")
		marker.position.y = 2.3
		node.add_child(marker)
		gate_index += 1
	var yard_index := 0
	for person: Dictionary in lg.fort_worker_choices():
		var node := PersonPreview.civilian(person)
		node.scale *= 1.6
		_add_person(node, -1, int(person["id"]), "courtyard", yard_index * 1.35)
		yard_index += 1
	var hero := {}
	for person: Dictionary in lg.soldiers:
		if bool(person.get("hero", false)):
			hero = person
			break
	if not hero.is_empty() and room_rects.has(0):
		_add_person(_fighter(hero), 0, int(hero["id"]), "hero", -1.5)
	# В комнатах показаны их настоящие жители.
	for p: Dictionary in lg.fort["plots"]:
		if not (p["up"] as Dictionary).is_empty():
			_room_worker(p, {}, true)
		elif int(p["id"]) != 0 and int(p["lv"]) > 0:
			var index := 0
			for person: Dictionary in lg.fort_occupants(int(p["id"])):
				var before := figures.size()
				_room_worker(p, person, false)
				if figures.size() > before:
					var entry: Dictionary = figures[-1]
					(entry["node"] as Node3D).position.x += -1.0 + index * 1.25
					entry["home"] = (entry["node"] as Node3D).position
				index += 1


func recruit_walk(_sid: int) -> void:
	# Новый человек появляется в своей комнате при следующей синхронизации.
	sync()


func _process(dt: float) -> void:
	if not active:
		return
	var moving := focus.distance_to(_target_focus) > 0.001 or absf(zoom - _target_zoom) > 0.001
	if moving:
		var weight := 1.0 - exp(-dt * 11.0)
		focus = focus.lerp(_target_focus, weight)
		zoom = lerpf(zoom, _target_zoom, weight)
		_update_camera()
	_accum += dt
	if _accum < 1.0 / 30.0:
		return
	var step := minf(_accum, 0.1)
	_accum = 0.0
	for entry: Dictionary in figures:
		var node: Node3D = entry["node"]
		var on_screen := Rect2(Vector2(-50, -100), size + Vector2(100, 200)).has_point(person_project(int(entry["id"]), entry["role"] == "newcomer")) if int(entry["plot"]) < 0 else footprint("plot_%d" % int(entry["plot"])).intersects(Rect2(Vector2.ZERO, size))
		node.visible = on_screen
		if not on_screen:
			continue
		if node is LegionFighter:
			(node as LegionFighter).tick(step)
		elif node is Citizen:
			(node as Citizen)._process(step)
		for ap: AnimationPlayer in entry["players"]:
			ap.advance(step)


func _id(slot: Variant) -> int:
	if slot is int:
		return int(slot)
	var key := String(slot)
	if key.begins_with("plot_"):
		return int(key.trim_prefix("plot_"))
	return int(lg.fort_slot_plot(key).get("id", 0))


func project(slot: Variant, height := 0.0) -> Vector2:
	var id := _id(slot)
	if not room_rects.has(id):
		return Vector2(-10000, -10000)
	var rect: Rect2 = room_rects[id]
	# Маркеры над центром, аргумент height сохранён для старого окна.
	var y := rect.end.y - 0.12 if height > 0.0 else rect.get_center().y
	return camera.unproject_position(world.to_global(Vector3(rect.get_center().x, y, 1.5))) * size / Vector2(sub.size)


func footprint(slot: String) -> Rect2:
	var id := _id(slot)
	if not room_rects.has(id):
		return Rect2()
	var rect: Rect2 = room_rects[id]
	var a := camera.unproject_position(world.to_global(Vector3(rect.position.x, rect.end.y, 0))) * size / Vector2(sub.size)
	var b := camera.unproject_position(world.to_global(Vector3(rect.end.x, rect.position.y, 0))) * size / Vector2(sub.size)
	return Rect2(a, b - a)


func highlight(slot: String) -> void:
	_hover = slot
	for key: String in highlights:
		(highlights[key] as MeshInstance3D).visible = slot != "" and key == _key(slot)


func _pick(pos: Vector2) -> String:
	if camera == null or size.x < 1 or size.y < 1:
		return ""
	var pixel := pos * Vector2(sub.size) / size
	var origin := camera.project_ray_origin(pixel)
	var ray := camera.project_ray_normal(pixel)
	if absf(ray.z) < 0.001:
		return ""
	var point := world.to_local(origin + ray * (-origin.z / ray.z))
	for id: int in room_rects:
		if (room_rects[id] as Rect2).has_point(Vector2(point.x, point.y)):
			return "plot_%d" % id
	return ""


func _gui_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var person := pick_person(event.position)
			if not person.is_empty():
				_person_down = int(person["id"])
				_down_newcomer = person["role"] == "newcomer"
				_down_pos = event.position
				accept_event()
				return
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var before := _plane_point(event.position)
			_target_zoom = clampf(_target_zoom * (0.86 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 0.86), CLOSE_ZOOM, default_zoom)
			var ratio := _target_zoom / zoom
			_target_focus = before + (focus - before) * ratio
			_clamp_target()
			accept_event()
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			if event.pressed:
				_dragging = true
				_drag_distance = 0.0
				_target_focus = focus
				_target_zoom = zoom
			else:
				_dragging = false
				if event.button_index == MOUSE_BUTTON_LEFT and _drag_distance < 7:
					var key := _pick(event.position)
					if key != "":
						focus_plot(key)
						building_pressed.emit(key)
			accept_event()
	elif event is InputEventMouseMotion:
		if _person_down != 0 or drag_sid != 0:
			return
		if _dragging:
			_drag_distance += event.relative.length()
			var units := zoom / maxf(1, size.y)
			_target_focus += Vector3(-event.relative.x * units, event.relative.y * units, 0)
			_clamp_target()
		else:
			highlight(_pick(event.position))


func person_project(sid: int, newcomer := false) -> Vector2:
	for entry: Dictionary in figures:
		if int(entry["id"]) == sid and (entry["role"] == "newcomer") == newcomer:
			var node: Node3D = entry["node"]
			return camera.unproject_position(node.global_position + Vector3(0, 1.0, 0)) * size / Vector2(sub.size)
	return Vector2(-10000, -10000)


func pick_person(pos: Vector2) -> Dictionary:
	var best := {}
	var distance := INF
	for entry: Dictionary in figures:
		if int(entry["id"]) == 0:
			continue
		var center := person_project(int(entry["id"]), entry["role"] == "newcomer")
		var pixels := maxf(14.0, size.y / maxf(1, zoom) * 0.65)
		var rect := Rect2(center - Vector2(pixels, pixels * 1.2), Vector2(pixels * 2, pixels * 2.6))
		if rect.has_point(pos) and center.distance_to(pos) < distance:
			best = entry
			distance = center.distance_to(pos)
	return best


func _input(event: InputEvent) -> void:
	if not active or (_person_down == 0 and drag_sid == 0):
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_person_move()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var pos: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if drag_sid == 0 and pos.distance_to(_down_pos) >= 7.0:
			begin_person_move(_person_down, _down_newcomer, pos)
		if drag_sid != 0:
			update_person_move(pos)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			cancel_person_move()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT and (not event.pressed or _click_move):
			var sid := _person_down
			var newcomer := _down_newcomer
			if drag_sid != 0:
				# Клик по панели поверх разреза не считается броском в комнату.
				var hovered := get_viewport().gui_get_hovered_control()
				var over_room := hovered == self or (hovered != null and hovered.has_meta("fort_room_hit"))
				var pos: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
				finish_person_move(pos if over_room else Vector2(-10000, -10000))
			else:
				_person_down = 0
				person_pressed.emit(sid, newcomer)
			get_viewport().set_input_as_handled()


func begin_person_move(sid: int, newcomer := false, pos := Vector2.INF, click_move := false) -> void:
	cancel_person_move()
	var person := lg.soldier(sid)
	if newcomer:
		for candidate: Dictionary in lg.fort_newcomers():
			if int(candidate["id"]) == sid:
				person = candidate
	if person.is_empty() or bool(person.get("hero", false)) or (not newcomer and lg.s_state(person) != "ready"):
		return
	drag_sid = sid
	drag_newcomer = newcomer
	_click_move = click_move
	drag_ghost = PersonPreview.civilian(person) if newcomer or not lg.fort_is_fighter(sid) else _fighter(person)
	if drag_ghost is Citizen:
		drag_ghost.scale *= 1.6
	world.add_child(drag_ghost)
	drag_ghost.name = "FortDragGhost"
	drag_ghost.rotation.y = -0.35
	for mesh: MeshInstance3D in drag_ghost.find_children("*", "MeshInstance3D", true, false):
		mesh.transparency = 0.25
	update_person_move(get_local_mouse_position() if pos == Vector2.INF else pos)


func _drop_valid(id: int) -> bool:
	if drag_newcomer:
		var p := lg.fort_plot(id)
		if lg.fort_room_slots(id) <= 0 or not (p["up"] as Dictionary).is_empty() or lg.can_recruit_resident() != "":
			return false
		var occupants := lg.fort_occupants(id)
		return occupants.size() < lg.fort_room_slots(id) or lg.s_state(occupants[0]) == "ready"
	return lg.fort_can_assign(id, drag_sid) == ""


func update_person_move(pos: Vector2) -> void:
	if drag_sid == 0 or not is_instance_valid(drag_ghost):
		return
	var point := world.to_local(_plane_point(pos))
	drag_ghost.position = Vector3(point.x, point.y - 1, 4.0)
	var key := _pick(pos)
	drag_target = int(key.trim_prefix("plot_")) if key != "" else -1
	for slot: String in highlights:
		var id := int(slot.trim_prefix("plot_"))
		var rim: MeshInstance3D = highlights[slot]
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.18, 0.72, 0.32, 0.42 if id == drag_target else 0.14) if _drop_valid(id) else Color(0.78, 0.18, 0.12, 0.42 if id == drag_target else 0.14)
		rim.material_override = mat
		rim.visible = true


func finish_person_move(pos: Vector2) -> bool:
	if drag_sid == 0:
		return false
	update_person_move(pos)
	var sid := drag_sid
	var id := drag_target
	var ok := id >= 0 and _drop_valid(id) and lg.fort_drop(id, sid, drag_newcomer)
	cancel_person_move()
	if ok:
		sync()
		person_moved.emit(sid, id)
	return ok


func cancel_person_move() -> void:
	if is_instance_valid(drag_ghost):
		drag_ghost.queue_free()
	drag_ghost = null
	drag_sid = 0
	drag_target = -1
	_person_down = 0
	_click_move = false
	for slot: String in highlights:
		var rim: MeshInstance3D = highlights[slot]
		rim.material_override = null
		rim.hide()
	move_finished.emit()


func expansion_project(axis: String) -> Vector2:
	var point := Vector3(0, grid.y * CELL.y + grid.x * CELL.x / 7.0 + 1.4, 3.0) if axis == "floor" else Vector3(grid.x * CELL.x * 0.5 + 2.2, grid.y * CELL.y * 0.65, 3.0)
	return camera.unproject_position(world.to_global(point)) * size / Vector2(sub.size)


func _plane_point(pos: Vector2) -> Vector3:
	var pixel := pos * Vector2(sub.size) / size
	var origin := camera.project_ray_origin(pixel)
	var ray := camera.project_ray_normal(pixel)
	return origin + ray * (-origin.z / ray.z)


func focus_plot(slot: String, close_view := true) -> void:
	var id := _id(slot)
	_target_focus = plots.get("plot_%d" % id, overview) if close_view else overview
	_target_zoom = CLOSE_ZOOM if close_view else default_zoom
	_clamp_target()


func _clamp_target() -> void:
	var half := Vector2(_target_zoom * size.x / maxf(1, size.y), _target_zoom) * 0.5
	_target_focus.x = clampf(_target_focus.x, minf(bounds.get_center().x, bounds.position.x + half.x), maxf(bounds.get_center().x, bounds.end.x - half.x))
	_target_focus.y = clampf(_target_focus.y, minf(bounds.get_center().y, bounds.position.y + half.y), maxf(bounds.get_center().y, bounds.end.y - half.y))


func _fit_zoom() -> float:
	var usable := Vector2(maxf(320, size.x - 220), maxf(240, size.y - 170))
	return maxf(bounds.size.y * size.y / usable.y, bounds.size.x * size.y / usable.x)


func _resize_view() -> void:
	var overview_mode := absf(_target_zoom - default_zoom) < 0.1
	default_zoom = _fit_zoom()
	_target_zoom = default_zoom if overview_mode else clampf(_target_zoom, CLOSE_ZOOM, default_zoom)
	zoom = _target_zoom
	_clamp_target()
	focus = _target_focus
	_update_camera()


func _update_camera() -> void:
	if camera == null:
		return
	camera.size = zoom
	camera.position = Vector3(focus.x, focus.y, 40)
	camera.rotation = Vector3.ZERO
	if is_instance_valid(backdrop):
		backdrop.position.x = focus.x * 0.10
		backdrop.position.y = grid.y * CELL.y * 0.45 + (focus.y - overview.y) * 0.06
	view_changed.emit()
