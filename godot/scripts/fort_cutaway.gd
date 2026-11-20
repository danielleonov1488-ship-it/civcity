class_name FortCutaway
extends Camp3D
## Рисованный разрез форта в отдельном 2D-слое.

signal person_pressed(sid: int, newcomer: bool)
signal person_moved(sid: int, plot_id: int)
signal move_finished
signal room_deselected
signal drag_updated(point: Vector2, room_id: int, person_name: String)

const FortPerson = preload("res://scripts/fort_person.gd")
const Actor = preload("res://scripts/charpilot_actor.gd")
const PersonLayer = preload("res://scripts/fort_person_layer.gd")
const ART := "res://assets/legion_b1/"
const ICON_ART := "res://assets/fort/cutaway/icons/"
const ROOM_ART := {"hq": "praetorium", "barracks": "barracks", "kitchen": "kitchen",
	"store": "granary", "forge": "forge", "arsenal": "armory", "infirmary": "infirmary",
	"mars": "shrine", "smelter": "smelter", "sawmill": "carpentry", "tannery": "tannery",
	"treasury": "treasury", "drill": "drill", "stable": "stable", "tower": "tower"}
const STATIONS := {"kitchen": [0.35, 0.53, 0.38], "forge": [0.70, 0.49, 0.25],
	"treasury": [0.59, 0.57, 0.49], "barracks": [0.45, 0.48, 0.46]}
const WORK_CLIPS := {"kitchen": "PickUp_Table", "forge": "Interact", "treasury": "Interact", "barracks": "Sword_Idle"}
const RangedPose = preload("res://scripts/legion_ranged_pose.gd")


const CELL := Vector2(360, 240)
const PERSON_HEIGHT := CELL.y * 0.55
const ROW_PITCH := 285.0
const PILLAR_WIDTH := 45.0
const STAIR_WIDTH := 155.0
const CLOSE_ZOOM := CELL.y / 0.6
const ROOM_FOCUS_ZOOM := CELL.y / 0.48
const SPRITE_LIMIT := 40
const NO_POINT := Vector2(-10000, -10000)

var room_rects: Dictionary = {}
var room_sprites: Dictionary = {}
var room_stages: Dictionary = {}
var shell: Node2D
var backdrop: Sprite2D
var grid := Legion.FORT_START_GRID
var _stage: Node2D
var _rooms: Node2D
var people_layer: PersonLayer
var _people_nodes: Dictionary = {}
var _rim_layer: Node2D
var _shell_texture: Texture2D
var _textures: Dictionary = {}
var _column_x := PackedFloat32Array()
var _stair_col := 1
var _right_edge := 0.0
var _ground_y := 0.0
var _target_focus := Vector3.ZERO
var _target_zoom := 400.0
var _view_scale := 1.0
var _layout_sig := ""
var _hover_id := -1
var selected_room := -1
var placement_rooms: Dictionary = {}
var _dust := GradientTexture2D.new()
var _drag_name := ""
var _drop_allowed: Dictionary = {}
var drag_sid := 0
var drag_newcomer := false
var drag_ghost: Actor
var _drag_height := PERSON_HEIGHT
var drag_target := -1
var _person_down := 0
var _down_newcomer := false
var _down_pos := Vector2.ZERO
var _click_move := false


static func room_art(type: String) -> String:
	return String(ROOM_ART.get(type, "barracks"))


static func room_icon(type: String) -> Texture2D:
	return load(ICON_ART + room_art(type) + ".png") as Texture2D


static func room_stage(level: int) -> int:
	return 1 if level < 4 else 2 if level < 8 else 3


static func room_texture_path(type: String, level: int, building := false) -> String:
	if building:
		return ART + "rooms/building.jpg"
	if type.is_empty():
		return ART + "rooms/empty.jpg"
	return ART + "rooms/%s_%d.jpg" % [room_art(type), room_stage(level)]


static func person_art(person: Dictionary, room: String = "", newcomer := false) -> String:
	return FortPerson.art(person, room, newcomer)


static func portrait_path(person: Dictionary, room: String = "", newcomer := false) -> String:
	return FortPerson.portrait_path(person, room, newcomer)


func setup(legion: Legion, game: Node) -> bool:
	lg = legion
	city_game = game
	name = "FortCutaway"
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not ResourceLoader.exists(ART + "fort/shell_front.png"):
		return false
	sub = SubViewport.new()
	sub.name = "FortCutawayWorld"
	sub.disable_3d = true
	sub.world_2d = World2D.new()
	sub.size = Vector2i(size).max(Vector2i.ONE)
	sub.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	sub.gui_disable_input = true
	add_child(sub)
	backdrop = Sprite2D.new()
	backdrop.name = "Landscape"
	backdrop.texture = _texture(ART + "fort/background.jpg")
	sub.add_child(backdrop)
	_stage = Node2D.new()
	_stage.name = "PaintedFort"
	sub.add_child(_stage)
	_shell_texture = _texture(ART + "fort/shell_front.png")
	people_layer = PersonLayer.new()
	people_layer.name = "Dwellers"
	people_layer.z_index = 2
	sub.add_child(people_layer)
	people_layer.setup("FortPeople3D", 14.0, false)
	people_layer.fit(size)
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(1.0, 0.86, 0.62, 0.88), Color(0.94, 0.74, 0.52, 0)])
	_dust.gradient = fade
	_dust.fill = GradientTexture2D.FILL_RADIAL
	_dust.fill_from = Vector2(0.5, 0.5)
	_dust.fill_to = Vector2(1, 0.5)
	active = true
	sync()
	resized.connect(_resize_view)
	mouse_exited.connect(func(): highlight(""))
	return true


func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path] as Texture2D


func _layer(layer_name: String, depth: int) -> Node2D:
	var layer := Node2D.new()
	layer.name = layer_name
	layer.z_index = depth
	_stage.add_child(layer)
	return layer


func _paint(parent: Node2D, tex: Texture2D, dest: Rect2, region := Rect2()) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.position = dest.position
	if region.has_area():
		sprite.region_enabled = true
		sprite.region_rect = region
		sprite.region_filter_clip_enabled = true
		sprite.scale = dest.size / region.size
	else:
		sprite.scale = dest.size / tex.get_size()
	parent.add_child(sprite)
	return sprite


func sync() -> void:
	if not active:
		return
	lg._fort_init()
	var entries: Array = (lg.fort.get("plots", []) as Array).duplicate()
	entries.sort_custom(func(a: Dictionary, b: Dictionary): return int(a["id"]) < int(b["id"]))
	var layout_data: Array = [lg.fort.get("exp", 0), lg.fort.get("grid", [])]
	var newcomers := lg.fort_newcomers()
	var people_data: Array = [newcomers]
	for p: Dictionary in entries:
		layout_data.append([p["id"], p["b"], p["lv"], not lg.fort_plot_timer(int(p["id"])).is_empty()])
		people_data.append(p.get("workers", []))
	for person: Dictionary in lg.soldiers:
		var state := lg.s_state(person)
		people_data.append([person["id"], state, person.get("look", {}), lg.worn(person)])
	people_data.append(lg.squad3)
	var sig := str(layout_data)
	var rebuilt := sig != _layout_sig
	if rebuilt:
		_layout_sig = sig
		_build_cutaway(entries)
	var people_sig := str(people_data)
	if rebuilt or _people_sig != people_sig:
		_people_sig = people_sig
		_build_people(entries, newcomers)
	if drag_sid != 0:
		_refresh_drop_rims()


func _build_cutaway(entries: Array) -> void:
	var next_grid := lg.fort_grid()
	var fit := _rooms == null or grid != next_grid
	for node: Node2D in [_rooms, shell, _rim_layer]:
		if is_instance_valid(node):
			node.free()
	_rooms = _layer("Rooms", 0)
	shell = _layer("Shell", 1)
	_rim_layer = _layer("RoomHighlights", 3)
	plots.clear()
	room_rects.clear()
	room_sprites.clear()
	room_stages.clear()
	highlights.clear()
	scaffolds.clear()
	_hover_id = -1
	grid = next_grid
	_stair_col = maxi(1, ceili((grid.x - 2) * 0.5))
	_column_x.resize(grid.x)
	for col in grid.x:
		_column_x[col] = col * (CELL.x + PILLAR_WIDTH) + (STAIR_WIDTH - PILLAR_WIDTH if col >= _stair_col else 0.0)
	_right_edge = _column_x[-1] + CELL.x
	# Порядок участков совпадает с прежним разрезом.
	var cells: Array[Vector2i] = []
	for row in grid.y:
		var row_cells: Array[int] = []
		for col in grid.x:
			if row != 0 or col < _stair_col or col > _stair_col + 1:
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
		var cell := Vector2i(_stair_col, 0)
		var width := CELL.x * 2.0 + PILLAR_WIDTH
		if id != 0:
			cell = cells[index]
			width = CELL.x
			index += 1
		var rect := Rect2(_column_x[cell.x], cell.y * ROW_PITCH, width, CELL.y)
		var key := "plot_%d" % id
		var center := rect.get_center()
		plots[key] = Vector3(center.x, center.y, 0)
		room_rects[id] = rect
		var building := not lg.fort_plot_timer(id).is_empty()
		var level := int(p["lv"])
		var room := _paint(_rooms, _texture(room_texture_path(String(p["b"]), level, building)), rect)
		room.name = "Room_%d" % id
		room_sprites[id] = room
		room_stages[id] = room_stage(level)
		var rim := ReferenceRect.new()
		rim.position = rect.position
		rim.size = rect.size
		rim.editor_only = false
		rim.border_width = 0.0
		rim.draw.connect(_draw_room_corners.bind(rim))
		rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rim_layer.add_child(rim)
		rim.hide()
		highlights[key] = rim
		if building:
			scaffolds[key] = room
			_construction_overlay(id, rect)
	# У старых фортов бывают ячейки без игрового участка.
	for i in range(index, cells.size()):
		var cell := cells[i]
		_paint(_rooms, _texture(room_texture_path("", 0)), Rect2(Vector2(_column_x[cell.x], cell.y * ROW_PITCH), CELL))
	_build_shell()
	_refresh_rims()
	bounds = Rect2(-540, -382, _right_edge + 625, _ground_y + 382 + 35)
	var center := bounds.get_center()
	overview = Vector3(center.x, center.y, 0)
	default_zoom = _fit_zoom()
	if fit:
		focus = overview
		_target_focus = overview
		zoom = default_zoom
		_target_zoom = zoom
	_update_camera()


func _construction_overlay(id: int, rect: Rect2) -> void:
	var dust := Node2D.new()
	dust.name = "ConstructionCloud_%d" % id
	dust.position = rect.position
	_rooms.add_child(dust)
	var scaffold := Node2D.new()
	scaffold.name = "Scaffold"
	dust.add_child(scaffold)
	scaffold.draw.connect(func():
		var dims := rect.size
		scaffold.draw_rect(Rect2(Vector2.ZERO, dims), Color(0.20, 0.12, 0.07, 0.46))
		for x: float in [0.07, 0.5, 0.93]:
			_scaffold_beam(scaffold, dims * Vector2(x, 0.04), dims * Vector2(x, 0.96), 18.0)
		for y: float in [0.17, 0.77]:
			_scaffold_beam(scaffold, dims * Vector2(0.04, y), dims * Vector2(0.96, y), 21.0)
		_scaffold_beam(scaffold, dims * Vector2(0.07, 0.77), dims * Vector2(0.50, 0.17), 14.0)
		_scaffold_beam(scaffold, dims * Vector2(0.50, 0.17), dims * Vector2(0.93, 0.77), 14.0))
	_paint(dust, _dust, Rect2(Vector2.ZERO, rect.size)).modulate.a = 0.48
	for i in 5:
		var offset := Vector2(0.15 * i, 0.60 - (i % 2) * 0.18)
		var puff := _paint(dust, _dust, Rect2(rect.size * offset, rect.size * Vector2(0.32, 0.40)))
		puff.name = "Dust_%d" % i
		var x := puff.position.x
		var distance := rect.size.x * 0.08
		var motion := puff.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		motion.tween_property(puff, "position:x", x + distance, 1.4 + i * 0.2)
		motion.tween_property(puff, "position:x", x, 1.4 + i * 0.2)


func _scaffold_beam(scaffold: Node2D, from: Vector2, to: Vector2, width: float) -> void:
	scaffold.draw_line(from + Vector2(3, 4), to + Vector2(3, 4), Color("392115"), width + 4.0, true)
	scaffold.draw_line(from, to, Color("925c37"), width, true)
	scaffold.draw_line(from - Vector2(2, 2), to - Vector2(2, 2), Color("d6a26c"), width * 0.25, true)


func _shell_piece(src: Rect2, at: Vector2, width: float) -> Sprite2D:
	return _paint(shell, _shell_texture, Rect2(at, Vector2(width, src.size.y)), src)


func _build_shell() -> void:
	var stair_x: float = _column_x[_stair_col] - STAIR_WIDTH
	var stair_end: float = _column_x[_stair_col]
	_shell_piece(Rect2(420, 48, 210, 382), Vector2(-210, -382), 210.0)
	var roof_cap := minf(120.0, stair_x * 0.22)
	_shell_piece(Rect2(630, 48, 120, 382), Vector2(0, -382), roof_cap)
	var left_roof := minf(stair_x - roof_cap, 600.0)
	_tile_roof(roof_cap, stair_x - roof_cap - left_roof)
	var left_source := maxf(410.0, left_roof)
	_shell_piece(Rect2(1350 - left_source, 48, left_source, 382), Vector2(stair_x - left_roof, -382), left_roof)
	_shell_piece(Rect2(1350, 48, 240, 382), Vector2(stair_x, -382), STAIR_WIDTH)
	# Дополнительные пролёты повторяют черепицу, угловая башня сохраняет размер.
	_tile_roof(stair_end, _right_edge - stair_end - 765.0)
	_shell_piece(Rect2(1590, 48, 590, 382), Vector2(_right_edge - 765.0, -382), 590.0)
	_shell_piece(Rect2(2180, 48, 250, 382), Vector2(_right_edge - 175.0, -382), 250.0)
	# Пол, простенки и лестница берутся из одних и тех же полос атласа.
	for row in grid.y:
		var y := row * ROW_PITCH
		var last := row == grid.y - 1
		var source_y := 430.0 if row == 0 else 1000.0 if last else 715.0
		var strip_h := 337.0 if last else ROW_PITCH
		for col in grid.x:
			var x: float = _column_x[col]
			_shell_piece(Rect2(1590, source_y + CELL.y, CELL.x, strip_h - CELL.y), Vector2(x, y + CELL.y), CELL.x)
			if col == 0 or col == _stair_col:
				continue
			var inside_hq := row == 0 and col == _stair_col + 1
			var skip_y := CELL.y if inside_hq else 0.0
			_shell_piece(Rect2(1950, source_y + skip_y, PILLAR_WIDTH, strip_h - skip_y), Vector2(x - PILLAR_WIDTH, y + skip_y), PILLAR_WIDTH)
		_shell_piece(Rect2(1350, source_y, 240, strip_h), Vector2(stair_x, y), STAIR_WIDTH)
		_shell_piece(Rect2(2355, source_y, 75, strip_h), Vector2(_right_edge, y), 75.0)
		if row == 0:
			_shell_piece(Rect2(420, 430, 210, 135), Vector2(-210, y), 210.0)
			_shell_piece(Rect2(450, 565, 180, strip_h - 135.0), Vector2(-180, y + 135.0), 180.0)
		else:
			var wall := _shell_piece(Rect2(2355, source_y, 75, strip_h), Vector2(0, y), 75.0)
			wall.scale.x = -1.0
	var gate_size := Vector2(645, 573)
	_ground_y = (grid.y - 1) * ROW_PITCH + CELL.y + 100.0
	var gate_sprite := _paint(shell, _texture(ART + "fort/gate.png"), Rect2(-560, _ground_y + 30.0 - gate_size.y, gate_size.x, gate_size.y))
	gate_sprite.name = "Gate"
	gate = Vector3(-255, _ground_y - 22.0, 0)


func _tile_roof(start_x: float, width: float) -> void:
	var x := start_x
	var end := start_x + width
	while x < end:
		var span := minf(360.0, end - x)
		_shell_piece(Rect2(1690, 48, span, 382), Vector2(x, -382), span)
		x += span


func _add_dweller(person: Dictionary, id: int, role: String, home: Vector2, away: float, height: float, works := false) -> void:
	if figures.size() >= SPRITE_LIMIT - 1:
		return
	var sid := int(person["id"])
	var gear := lg.worn(person)
	var clothes := FortPerson.loadout(person, gear)
	var actor: Actor = _people_nodes.get(sid)
	if actor == null or actor.get_meta("look", {}) != person.get("look", {}):
		if actor != null:
			actor.free()
		actor = FortPerson.make(person, people_layer.viewport, gear)
		actor.name = "Dweller_%d" % sid
		_people_nodes[sid] = actor
	elif actor.get_meta("loadout") != clothes and actor.problem.is_empty():
		actor.set_loadout(clothes)
		actor.set_meta("loadout", clothes)
	figures.append({"node": actor, "id": sid, "plot": id, "role": role, "home": home, "feet": home,
		"away": away, "height": height, "phase": fmod(float(sid) * 1.23, 6.0), "works": works,
		"clip": "Idle", "sample": 0.0, "yaw": 15.0})

func _build_people(entries: Array, newcomers: Array[Dictionary]) -> void:
	figures.clear()
	for index in newcomers.size():
		var person := newcomers[index]
		var home := Vector2(gate.x + (index - (newcomers.size() - 1) * 0.5) * 115, gate.y + (index % 2) * 13)
		_add_dweller(person, -2, "newcomer", home, home.x, PERSON_HEIGHT)
	var occupied: Array[Dictionary] = []
	var widest_room := 0
	for plot: Dictionary in entries:
		var id := int(plot["id"])
		var room: Rect2 = room_rects[id]
		var type := String(plot["b"])
		if lg.fort_plot_timer(id).is_empty() and int(plot["lv"]) > 0:
			var occupants := lg.fort_occupants(id)
			if not occupants.is_empty():
				occupied.append({"id": id, "type": type, "rect": room, "people": occupants})
				widest_room = maxi(widest_room, occupants.size())
	# Сначала по человеку на комнату, затем остальные жильцы.
	for index in mini(widest_room, SPRITE_LIMIT - 1):
		for entry: Dictionary in occupied:
			var occupants: Array[Dictionary] = entry["people"]
			if index < occupants.size():
				_place_occupant(occupants[index], entry, index, mini(occupants.size(), SPRITE_LIMIT - 1))
			if figures.size() >= SPRITE_LIMIT - 1:
				break
	var yard := lg.fort_worker_choices()
	var columns := maxi(1, floori(_right_edge / 112.0))
	for index in mini(yard.size(), SPRITE_LIMIT - 1 - figures.size()):
		var person := yard[index]
		var home := Vector2(80.0 + (index % columns) * 112.0, _ground_y + 12.0 - floorf(float(index) / columns) * 52.0)
		_add_dweller(person, -1, "courtyard", home, minf(home.x + 26.0, _right_edge - 78.0), PERSON_HEIGHT)
	var retained := {}
	for entry: Dictionary in figures:
		retained[entry["id"]] = true
	for sid: int in _people_nodes.keys():
		if not retained.has(sid):
			(_people_nodes[sid] as Node3D).free()
			_people_nodes.erase(sid)
	_animate_people(0.0)


func _place_occupant(person: Dictionary, entry: Dictionary, index: int, count: int) -> void:
	var type: String = entry["type"]
	var id: int = entry["id"]
	var room: Rect2 = entry["rect"]
	var works: bool = STATIONS.has(type) and lg.fort_worker(id).get("id") == person["id"]
	var ranks := 1 if count <= 5 else 2 if count <= 12 else 3
	var across := ceili(float(count) / ranks)
	var rank := floori(float(index) / across)
	var rank_count := mini(across, count - rank * across)
	var x := 0.5 if rank_count == 1 else lerpf(0.19, 0.81, float(index % across) / (rank_count - 1))
	var y := 0.89 - rank * 0.07
	if works:
		x = float(STATIONS[type][int(room_stages[id]) - 1])
	var height := PERSON_HEIGHT * (1.0 - rank * 0.04)
	var margin := height * 0.62
	var left := room.position.x + margin
	var right := room.end.x - margin
	var home := room.position + room.size * Vector2(x, y)
	home.x = clampf(home.x, left, right)
	var walk_width := 62.0 if count == 1 else 25.0
	var direction := -1.0 if x >= 0.5 else 1.0
	var away := clampf(home.x + walk_width * direction, left, right)
	_add_dweller(person, id, type, home, away, height, works)


func _animate_people(delta: float) -> void:
	_clock += delta
	var screen_area := Rect2(Vector2.ZERO, size)
	var render_area := Rect2()
	people_layer.shadows.clear()
	for entry: Dictionary in figures:
		var actor: Actor = entry["node"]
		var home: Vector2 = entry["home"]
		var height := float(entry["height"]) * _view_scale
		if not actor.problem.is_empty() or (int(entry["id"]) == drag_sid and (entry["role"] == "newcomer") == drag_newcomer):
			actor.hide()
			continue
		if not screen_area.grow(height + 64.0 * _view_scale).has_point(_screen_point(home)):
			actor.hide()
			continue
		var away: float = entry["away"]
		var phase := _clock + float(entry["phase"])
		var t := fposmod(phase, 7.2)
		var x := home.x
		var clip := "Idle"
		var yaw := 24.0 if away >= home.x else -24.0
		if bool(entry["works"]) and t < 3.4:
			clip = String(WORK_CLIPS[entry["role"]])
			yaw = 24.0
		elif away != home.x:
			if t >= 5.8:
				x = lerpf(away, home.x, (t - 5.8) / 1.4)
				clip = "Walk"
				yaw *= -2.0
			elif t >= 4.8:
				x = away
			elif t >= 3.4:
				x = lerpf(home.x, away, (t - 3.4) / 1.4)
				clip = "Walk"
				yaw *= 2.0
		var feet := Vector2(x, home.y)
		var sample := phase
		if actor.ranged != null and actor.ranged.mode == "bow" and clip != "Walk":
			var training := String(entry["role"]) in ["drill", "tower"]
			var drill_time := fposmod(phase, 3.0)
			clip = RangedPose.BOW if training and drill_time < RangedPose.LENGTHS[RangedPose.BOW] else RangedPose.BOW_IDLE
			sample = drill_time
		var pixel := _screen_point(feet)
		var bounds := _figure_bounds(pixel, height)
		actor.visible = screen_area.intersects(bounds)
		if actor.visible:
			entry["feet"] = feet
			entry["clip"] = clip
			entry["sample"] = sample
			entry["yaw"] = yaw
			people_layer.place(actor, pixel, height, yaw)
			actor.animate(clip, sample)
			people_layer.shadows.append(Vector3(pixel.x, pixel.y, height))
			render_area = render_area.merge(bounds) if render_area.has_area() else bounds
	if is_instance_valid(drag_ghost):
		# Призрак двигается по всему экрану вслед за мышью.
		render_area = screen_area
	people_layer.crop_to(render_area)
	people_layer.queue_redraw()


func _figure_bounds(feet: Vector2, height: float) -> Rect2:
	return Rect2(feet - Vector2(height * 0.65, height * 1.13),
		Vector2(height * 1.3, height * 1.23)).grow(4.0)


func recruit_walk(_sid: int) -> void:
	sync()


func _process(dt: float) -> void:
	if not active:
		return
	if focus.distance_to(_target_focus) > 0.1 or absf(zoom - _target_zoom) > 0.1:
		var weight := 1.0 - exp(-dt * 11.0)
		focus = focus.lerp(_target_focus, weight)
		zoom = lerpf(zoom, _target_zoom, weight)
		_update_camera()
	_animate_people(dt)


func _id(slot: Variant) -> int:
	if slot is int:
		return int(slot)
	var key := String(slot)
	if key.begins_with("plot_"):
		return int(key.trim_prefix("plot_"))
	return int(lg.fort_slot_plot(key).get("id", 0))


func _screen_point(point: Vector2) -> Vector2:
	return _stage.position + point * _view_scale


func _plane_point(pos: Vector2) -> Vector2:
	return (pos - _stage.position) / _view_scale


func project(slot: Variant, height := 0.0) -> Vector2:
	var id := _id(slot)
	if not room_rects.has(id):
		return NO_POINT
	var rect: Rect2 = room_rects[id]
	return _screen_point(Vector2(rect.get_center().x, rect.position.y + 7.0 if height > 0.0 else rect.get_center().y))


func footprint(slot: String) -> Rect2:
	return plot_footprint(_id(slot))


func plot_footprint(id: int) -> Rect2:
	if not room_rects.has(id):
		return Rect2()
	var rect: Rect2 = room_rects[id]
	return Rect2(_screen_point(rect.position), rect.size * _view_scale)


func _draw_room_corners(rim: ReferenceRect) -> void:
	var span := minf(rim.size.x, rim.size.y) * 0.15
	for corner: Vector2 in [Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN, Vector2.ONE]:
		var p := corner * (rim.size - Vector2.ONE * 8.0) + Vector2(4, 4)
		var direction := Vector2.ONE - 2.0 * corner
		rim.draw_line(p, p + Vector2(direction.x * span, 0), rim.border_color, 7.0, true)
		rim.draw_line(p, p + Vector2(0, direction.y * span), rim.border_color, 7.0, true)


func select_room(id: int) -> void:
	selected_room = id
	_refresh_rims()


func highlight(slot: String) -> void:
	if drag_sid == 0:
		_hover_id = -1 if slot.is_empty() else _id(slot)
		_refresh_rims()


func _refresh_rims() -> void:
	for id: int in room_rects:
		var rim: ReferenceRect = highlights["plot_%d" % id]
		var marked := id == selected_room or id == _hover_id or placement_rooms.has(id)
		rim.visible = drag_sid != 0 or marked
		if drag_sid != 0:
			_tint_drop_rim(id, rim)
		else:
			rim.border_color = Color("fff0c6") if id == selected_room else Color("cfa569")
			rim.queue_redraw()


func _pick_id(pos: Vector2) -> int:
	if not Rect2(Vector2.ZERO, size).has_point(pos):
		return -1
	var point := _plane_point(pos)
	for id: int in room_rects:
		if (room_rects[id] as Rect2).has_point(point):
			return id
	return -1


func _pick(pos: Vector2) -> String:
	var id := _pick_id(pos)
	return "plot_%d" % id if id >= 0 else ""


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
			var point := _plane_point(event.position)
			var before := Vector3(point.x, point.y, 0)
			_target_zoom = clampf(_target_zoom * (0.86 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 0.86), CLOSE_ZOOM, default_zoom)
			_target_focus = before + (focus - before) * (_target_zoom / zoom)
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
						building_pressed.emit(key)
					else:
						room_deselected.emit()
			accept_event()
	elif event is InputEventMouseMotion:
		if _person_down != 0 or drag_sid != 0:
			return
		if _dragging:
			_drag_distance += event.relative.length()
			_target_focus -= Vector3(event.relative.x, event.relative.y, 0) / _view_scale
			_clamp_target()
		else:
			highlight(_pick(event.position))


func _body_center(entry: Dictionary) -> Vector2:
	return Vector2(entry["feet"]) - Vector2(0.0, float(entry["height"]) * 0.49)


func _find_person(sid: int, newcomer: bool) -> Dictionary:
	for entry: Dictionary in figures:
		if int(entry["id"]) == sid and (entry["role"] == "newcomer") == newcomer:
			return entry
	return {}


func person_project(sid: int, newcomer := false) -> Vector2:
	var entry := _find_person(sid, newcomer)
	if entry.is_empty():
		return NO_POINT
	var actor: Actor = entry["node"]
	return _screen_point(_body_center(entry)) if actor.visible else NO_POINT


func person_hit_rect(sid: int, newcomer := false) -> Rect2:
	var entry := _find_person(sid, newcomer)
	if entry.is_empty() or not (entry["node"] as Actor).visible:
		return Rect2()
	var center := _body_center(entry)
	var half := _person_hit_half(entry)
	return Rect2(_screen_point(center - half), half * (2.0 * _view_scale))


func _person_hit_half(entry: Dictionary) -> Vector2:
	return Vector2(0.32, 0.52) * float(entry["height"])


func pick_person(pos: Vector2) -> Dictionary:
	var best := {}
	var distance := INF
	var point := _plane_point(pos)
	for entry: Dictionary in figures:
		var actor: Actor = entry["node"]
		if int(entry["id"]) == 0 or not actor.visible:
			continue
		var center := _body_center(entry)
		var half := _person_hit_half(entry)
		var d := center.distance_squared_to(point)
		if d < distance and Rect2(center - half, half * 2.0).has_point(point):
			best = entry
			distance = d
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
				# Панель над разрезом не считается комнатой.
				var hovered := get_viewport().gui_get_hovered_control()
				var over_room := hovered == self or (hovered != null and hovered.has_meta("fort_room_hit"))
				var pos: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
				finish_person_move(pos if over_room else NO_POINT)
			else:
				_person_down = 0
				person_pressed.emit(sid, newcomer)
			get_viewport().set_input_as_handled()


func begin_person_move(sid: int, newcomer := false, pos := Vector2.INF, click_move := false) -> void:
	cancel_person_move()
	var person: Dictionary = {}
	if newcomer:
		for candidate: Dictionary in lg.fort_newcomers():
			if int(candidate["id"]) == sid:
				person = candidate
				break
	else:
		person = lg.soldier(sid)
	if person.is_empty() or (not newcomer and not lg.fort_can_move(sid)):
		return
	var entry := _find_person(sid, newcomer)
	drag_ghost = FortPerson.make(person, people_layer.viewport, lg.worn(person))
	drag_ghost.name = "FortDragGhost"
	_drag_height = float(entry.get("height", PERSON_HEIGHT))
	drag_ghost.set_opacity(0.62)
	if drag_ghost.problem.is_empty():
		drag_ghost.animate(String(entry.get("clip", "Idle")), float(entry.get("sample", 0.0)))
	_drag_name = String(person.get("name", ""))
	drag_sid = sid
	drag_newcomer = newcomer
	_click_move = click_move
	_refresh_drop_rims()
	update_person_move(get_local_mouse_position() if pos == Vector2.INF else pos)


func _drop_valid(id: int) -> bool:
	return lg.fort_can_drop(id, drag_sid, drag_newcomer)


func _tint_drop_rim(id: int, rim: ReferenceRect) -> void:
	var color := Color("fff0c6") if bool(_drop_allowed.get(id, false)) else Color("bc6f62")
	color.a = 0.95 if id == drag_target else 0.48
	rim.border_color = color
	rim.queue_redraw()


func _refresh_drop_rims() -> void:
	for id: int in room_rects:
		var rim: ReferenceRect = highlights["plot_%d" % id]
		_drop_allowed[id] = _drop_valid(id)
		_tint_drop_rim(id, rim)
		rim.show()


func update_person_move(pos: Vector2) -> void:
	if drag_sid == 0 or not is_instance_valid(drag_ghost):
		return
	var source := _find_person(drag_sid, drag_newcomer)
	var height := _drag_height * _view_scale
	people_layer.place(drag_ghost, pos + Vector2(0.0, height * 0.49), height, float(source.get("yaw", 15.0)), true)
	var id := _pick_id(pos)
	drag_updated.emit(pos, id, _drag_name)
	if drag_target == id:
		return
	var previous := drag_target
	drag_target = id
	if room_rects.has(previous):
		_tint_drop_rim(previous, highlights["plot_%d" % previous])
	if id >= 0:
		_tint_drop_rim(id, highlights["plot_%d" % id])


func finish_person_move(pos: Vector2) -> bool:
	if drag_sid == 0:
		return false
	var sid := drag_sid
	var id := _pick_id(pos)
	var yard := id == -1 and Rect2(Vector2.ZERO, size).has_point(pos) and pos.y >= _screen_point(Vector2(0.0, _ground_y)).y - 36.0 * _view_scale
	var ok := (id >= 0 or yard) and lg.fort_drop(id, sid, drag_newcomer)
	cancel_person_move()
	if ok:
		sync()
		person_moved.emit(sid, id)
	return ok


func cancel_person_move() -> void:
	if is_instance_valid(drag_ghost):
		drag_ghost.hide()
		drag_ghost.queue_free()
	drag_ghost = null
	drag_sid = 0
	drag_newcomer = false
	drag_target = -1
	_person_down = 0
	_click_move = false
	_hover_id = -1
	_drop_allowed.clear()
	_refresh_rims()
	move_finished.emit()


func expansion_project(axis: String) -> Vector2:
	var point := Vector2(_right_edge * 0.5, -345) if axis == "floor" else Vector2(_right_edge + 55, (grid.y - 0.8) * ROW_PITCH * 0.50)
	return _screen_point(point)


func focus_plot(slot: String, close_view := true) -> void:
	var id := _id(slot)
	var rect: Rect2 = room_rects.get(id, Rect2())
	_target_focus = plots.get("plot_%d" % id, overview) if close_view else overview
	_target_zoom = default_zoom
	if close_view:
		var width_zoom := rect.size.x * maxf(1.0, size.y) / maxf(1.0, size.x - 48.0)
		_target_zoom = minf(default_zoom, maxf(ROOM_FOCUS_ZOOM, width_zoom))
	_clamp_target()


func _clamp_target() -> void:
	var half := Vector2(_target_zoom * size.x / maxf(1, size.y), _target_zoom) * 0.5
	_target_focus.x = clampf(_target_focus.x, minf(overview.x, bounds.position.x + half.x), maxf(overview.x, bounds.end.x - half.x))
	_target_focus.y = clampf(_target_focus.y, minf(overview.y, bounds.position.y + half.y), maxf(overview.y, bounds.end.y - half.y))


func _fit_zoom() -> float:
	var height := maxf(1.0, size.y)
	var usable := Vector2(maxf(1.0, size.x - minf(112, size.x * 0.16)), maxf(1.0, size.y - minf(126, size.y * 0.18)))
	return maxf(CLOSE_ZOOM, maxf(bounds.size.y * height / usable.y, bounds.size.x * height / usable.x))


func _resize_view() -> void:
	people_layer.fit(size)
	var overview_mode := absf(_target_zoom - default_zoom) < 0.1
	default_zoom = _fit_zoom()
	_target_zoom = default_zoom if overview_mode else clampf(_target_zoom, CLOSE_ZOOM, default_zoom)
	zoom = _target_zoom
	_clamp_target()
	focus = _target_focus
	_update_camera()


func _update_camera() -> void:
	_view_scale = maxf(1.0, size.y) / zoom
	_stage.scale = Vector2.ONE * _view_scale
	_stage.position = size * 0.5 - Vector2(focus.x, focus.y) * _view_scale
	var texture_size := backdrop.texture.get_size()
	var cover := maxf(size.x / texture_size.x, size.y / texture_size.y) * 1.08
	backdrop.scale = Vector2.ONE * cover
	var margin := (texture_size * cover - size).max(Vector2.ZERO) * 0.5
	var offset := Vector2(overview.x - focus.x, overview.y - focus.y) * (_view_scale * 0.07)
	backdrop.position = size * 0.5 + offset.clamp(-margin, margin)
	view_changed.emit()
