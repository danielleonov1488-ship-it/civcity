class_name FortCutaway
extends Camp3D
## Рисованный разрез форта в отдельном 2D-слое.

signal person_pressed(sid: int, newcomer: bool)
signal person_moved(sid: int, plot_id: int)
signal move_finished

const ART := "res://assets/legion_b1/"
const ICON_ART := "res://assets/fort/cutaway/icons/"
const ROOM_ART := {"hq": "praetorium", "barracks": "barracks", "kitchen": "kitchen",
	"store": "granary", "forge": "forge", "arsenal": "armory", "infirmary": "infirmary",
	"mars": "shrine", "smelter": "smelter", "sawmill": "carpentry", "tannery": "tannery",
	"treasury": "treasury", "drill": "drill", "stable": "stable", "tower": "tower"}
const WORKER_ART := {"kitchen": "cook", "forge": "smith", "treasury": "treasurer",
	"mars": "priest", "smelter": "smith", "sawmill": "smith", "stable": "cavalry"}
const STATIONS := {"kitchen": [0.35, 0.53, 0.38], "forge": [0.70, 0.49, 0.25],
	"treasury": [0.59, 0.57, 0.49]}
const MILITARY_ROOMS := ["barracks", "drill", "tower", "arsenal"]
const MILITARY_ART := ["legionary", "archer", "priest", "cavalry"]
const CELL := Vector2(360, 240)
const ROW_PITCH := 285.0
const PILLAR_WIDTH := 45.0
const STAIR_WIDTH := 155.0
const CLOSE_ZOOM := CELL.y / 0.6
const ROOM_FOCUS_ZOOM := CELL.y / 0.48
const SPRITE_LIMIT := 40
const BODY_CENTER := Vector2(-12, -112)
const NO_POINT := Vector2(-10000, -10000)

var room_rects: Dictionary = {}
var room_sprites: Dictionary = {}
var room_stages: Dictionary = {}
var shell: Node2D
var backdrop: Sprite2D
var grid := Vector2i(3, 2)
var _stage: Node2D
var _rooms: Node2D
var _figure_layer: Node2D
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
var _drop_allowed: Dictionary = {}
var drag_sid := 0
var drag_newcomer := false
var drag_ghost: Sprite2D
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
	if not newcomer:
		if bool(person.get("hero", false)):
			return "hero"
		if WORKER_ART.has(room):
			return String(WORKER_ART[room])
		if room in MILITARY_ROOMS:
			var cls := String(person.get("cls", "legionary"))
			return cls if cls in MILITARY_ART else "legionary"
	var female := bool(person.get("female", int(person.get("res", {}).get("m", {}).get("sx", 0)) == 1))
	return "newcomer_female" if female else "newcomer_male"


static func portrait_path(person: Dictionary, room: String = "", newcomer := false) -> String:
	return ART + "chars/" + person_art(person, room, newcomer) + "_portrait.png"


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
	_figure_layer = _layer("Dwellers", 2)
	_figure_layer.y_sort_enabled = true
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
		layout_data.append([p["id"], p["b"], p["lv"], not (p["up"] as Dictionary).is_empty()])
		people_data.append(p.get("workers", []))
	for person: Dictionary in lg.soldiers:
		var state := "" if bool(person.get("hero", false)) else lg.s_state(person)
		people_data.append([person["id"], state, person_art(person), person.get("cls", "")])
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
		var building := not (p["up"] as Dictionary).is_empty()
		var level := int(p["lv"])
		var room := _paint(_rooms, _texture(room_texture_path(String(p["b"]), level, building)), rect)
		room.name = "Room_%d" % id
		room_sprites[id] = room
		room_stages[id] = room_stage(level)
		var rim := ReferenceRect.new()
		rim.position = rect.position
		rim.size = rect.size
		rim.editor_only = false
		rim.border_width = 4.0
		rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rim_layer.add_child(rim)
		rim.hide()
		highlights[key] = rim
		if building:
			scaffolds[key] = room
	# У старых фортов бывают ячейки без игрового участка.
	for i in range(index, cells.size()):
		var cell := cells[i]
		_paint(_rooms, _texture(room_texture_path("", 0)), Rect2(Vector2(_column_x[cell.x], cell.y * ROW_PITCH), CELL))
	_build_shell()
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


func _make_dweller(art: String, height: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _texture(ART + "chars/" + art + ".png")
	sprite.hframes = 8
	sprite.offset.y = 128.0 - 242.0
	sprite.scale = Vector2.ONE * (height / 242.0)
	return sprite


func _add_dweller(person: Dictionary, id: int, role: String, art: String, home: Vector2, away: float, height: float, works := false) -> void:
	if figures.size() >= SPRITE_LIMIT - 1:
		return
	var sid := int(person.get("id", 0))
	var sprite := _make_dweller(art, height)
	sprite.name = "Dweller_%d" % sid if sid != 0 else "Builder_%d" % id
	sprite.position = home
	_figure_layer.add_child(sprite)
	figures.append({"node": sprite, "id": sid, "plot": id, "role": role, "art": art, "home": home,
		"away": away, "phase": fmod(float(sid) * 1.23, 6.0), "works": works})


func _build_people(entries: Array, newcomers: Array[Dictionary]) -> void:
	for entry: Dictionary in figures:
		(entry["node"] as Sprite2D).free()
	figures.clear()
	for index in newcomers.size():
		var person := newcomers[index]
		var home := Vector2(gate.x + (index - (newcomers.size() - 1) * 0.5) * 115, gate.y + (index % 2) * 13)
		_add_dweller(person, -2, "newcomer", person_art(person, "", true), home, home.x, 178.0)
	if room_rects.has(0):
		var rect: Rect2 = room_rects[0]
		for person: Dictionary in lg.soldiers:
			if bool(person.get("hero", false)):
				var home := rect.position + rect.size * Vector2(0.63, 0.88)
				_add_dweller(person, 0, "hero", "hero", home, home.x - 58.0, 172.0)
				break
	var occupied: Array[Dictionary] = []
	var widest_room := 0
	for plot: Dictionary in entries:
		var id := int(plot["id"])
		if id == 0:
			continue
		var room: Rect2 = room_rects[id]
		var type := String(plot["b"])
		if not (plot["up"] as Dictionary).is_empty():
			var home := room.position + room.size * Vector2(0.51, 0.88)
			_add_dweller({}, id, "builder", "smith", home, home.x - 45.0, 155.0, true)
		elif int(plot["lv"]) > 0:
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
				return
	var yard := lg.fort_worker_choices()
	var columns := maxi(1, floori(_right_edge / 100.0))
	for index in mini(yard.size(), SPRITE_LIMIT - 1 - figures.size()):
		var person := yard[index]
		var home := Vector2(60.0 + (index % columns) * 100.0, _ground_y + 12.0 - floorf(float(index) / columns) * 52.0)
		_add_dweller(person, -1, "courtyard", person_art(person), home, home.x + 32.0, 158.0)


func _place_occupant(person: Dictionary, entry: Dictionary, index: int, count: int) -> void:
	var type: String = entry["type"]
	var id: int = entry["id"]
	var room: Rect2 = entry["rect"]
	var art := person_art(person, type)
	var works := index == 0 and STATIONS.has(type)
	var ranks := 1 if count <= 5 else 2 if count <= 12 else 3
	var across := ceili(float(count) / ranks)
	var rank := floori(float(index) / across)
	var rank_count := mini(across, count - rank * across)
	var x := 0.5 if rank_count == 1 else lerpf(0.19, 0.81, float(index % across) / (rank_count - 1))
	var y := 0.88 - rank * 0.14
	if works:
		x = float(STATIONS[type][int(room_stages[id]) - 1])
	var home := room.position + room.size * Vector2(x, y)
	var walk_width := 62.0 if count == 1 else 25.0
	var direction := -1.0 if x >= 0.5 else 1.0
	var height := 185.0 if art == "cavalry" else 171.0
	if count >= 3:
		height *= maxf(0.42, 0.74 - rank * 0.08 - maxi(0, across - 5) * 0.024)
	_add_dweller(person, id, type, art, home, home.x + walk_width * direction, height, works)


func _animate_people(delta: float) -> void:
	_clock += delta
	var half := size * (0.5 / _view_scale)
	var visible_area := Rect2(Vector2(focus.x, focus.y) - half - Vector2(75, 4), half * 2.0 + Vector2(150, 195))
	for entry: Dictionary in figures:
		var sprite: Sprite2D = entry["node"]
		var home: Vector2 = entry["home"]
		var away: float = entry["away"]
		var phase := _clock + float(entry["phase"])
		var t := fposmod(phase, 7.2)
		var x := home.x
		var frame := int(phase * 2.0) % 2
		var flip := away < home.x
		if bool(entry["works"]) and t < 3.4:
			frame = 6 + int(phase * 3.5) % 2
			flip = false
		elif away != home.x:
			if t >= 5.8:
				x = lerpf(away, home.x, (t - 5.8) / 1.4)
				frame = 2 + int(phase * 8.0) % 4
				flip = not flip
			elif t >= 4.8:
				x = away
			elif t >= 3.4:
				x = lerpf(home.x, away, (t - 3.4) / 1.4)
				frame = 2 + int(phase * 8.0) % 4
		var point := Vector2(x, home.y)
		sprite.visible = visible_area.has_point(point)
		if sprite.visible:
			sprite.position = point
			sprite.flip_h = flip
			sprite.frame = frame


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


func highlight(slot: String) -> void:
	if drag_sid != 0:
		return
	if _hover_id >= 0:
		(highlights["plot_%d" % _hover_id] as ReferenceRect).hide()
	_hover_id = -1 if slot.is_empty() else _id(slot)
	var rim: ReferenceRect = highlights.get("plot_%d" % _hover_id)
	if rim != null:
		rim.border_color = Color(1, 0.78, 0.4, 0.78)
		rim.show()


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
						focus_plot(key)
						building_pressed.emit(key)
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


func _body_center(sprite: Sprite2D) -> Vector2:
	var body := BODY_CENTER
	if sprite.flip_h:
		body.x = -body.x
	return sprite.position + body * sprite.scale


func _find_person(sid: int, newcomer: bool) -> Dictionary:
	for entry: Dictionary in figures:
		if int(entry["id"]) == sid and (entry["role"] == "newcomer") == newcomer:
			return entry
	return {}


func person_project(sid: int, newcomer := false) -> Vector2:
	var entry := _find_person(sid, newcomer)
	if entry.is_empty():
		return NO_POINT
	var sprite: Sprite2D = entry["node"]
	return _screen_point(_body_center(sprite)) if sprite.visible else NO_POINT


func pick_person(pos: Vector2) -> Dictionary:
	var best := {}
	var distance := INF
	var point := _plane_point(pos)
	for entry: Dictionary in figures:
		var sprite: Sprite2D = entry["node"]
		if int(entry["id"]) == 0 or not sprite.visible:
			continue
		var center := _body_center(sprite)
		var half := Vector2(85 if entry["art"] == "cavalry" else 67, 113) * sprite.scale
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
	if person.is_empty() or bool(person.get("hero", false)) or (not newcomer and lg.s_state(person) != "ready"):
		return
	var entry := _find_person(sid, newcomer)
	var room := String(lg.fort_plot(lg.fort_worker_plot(sid)).get("b", "")) if not newcomer else ""
	var source: Sprite2D = entry.get("node")
	drag_ghost = _make_dweller(person_art(person, room, newcomer), 171.0)
	if source != null:
		drag_ghost.texture = source.texture
		drag_ghost.scale = source.scale
		drag_ghost.frame = source.frame
		drag_ghost.flip_h = source.flip_h
	drag_ghost.name = "FortDragGhost"
	drag_ghost.modulate.a = 0.5
	drag_ghost.z_index = 4
	_stage.add_child(drag_ghost)
	drag_sid = sid
	drag_newcomer = newcomer
	_click_move = click_move
	_refresh_drop_rims()
	update_person_move(get_local_mouse_position() if pos == Vector2.INF else pos)


func _drop_valid(id: int) -> bool:
	if drag_newcomer:
		var p := lg.fort_plot(id)
		if lg.fort_room_slots(id) <= 0 or not (p["up"] as Dictionary).is_empty() or lg.can_recruit_resident() != "":
			return false
		var occupants := lg.fort_occupants(id)
		return occupants.size() < lg.fort_room_slots(id) or lg.s_state(occupants[0]) == "ready"
	return lg.fort_can_assign(id, drag_sid) == ""


func _tint_drop_rim(id: int, rim: ReferenceRect) -> void:
	var color := Color("55dd83") if bool(_drop_allowed[id]) else Color("ef705d")
	color.a = 0.95 if id == drag_target else 0.48
	rim.border_color = color


func _refresh_drop_rims() -> void:
	for id: int in room_rects:
		var rim: ReferenceRect = highlights["plot_%d" % id]
		_drop_allowed[id] = _drop_valid(id)
		_tint_drop_rim(id, rim)
		rim.show()


func update_person_move(pos: Vector2) -> void:
	if drag_sid == 0 or not is_instance_valid(drag_ghost):
		return
	drag_ghost.position = _plane_point(pos)
	drag_ghost.position += drag_ghost.position - _body_center(drag_ghost)
	var id := _pick_id(pos)
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
	var ok := id >= 0 and _drop_valid(id) and lg.fort_drop(id, sid, drag_newcomer)
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
	for slot: String in highlights:
		(highlights[slot] as ReferenceRect).hide()
	move_finished.emit()


func expansion_project(axis: String) -> Vector2:
	var point := Vector2(_right_edge * 0.5, -345) if axis == "floor" else Vector2(_right_edge + 55, (grid.y - 0.8) * ROW_PITCH * 0.50)
	return _screen_point(point)


func focus_plot(slot: String, close_view := true) -> void:
	var id := _id(slot)
	_target_focus = plots.get("plot_%d" % id, overview) if close_view else overview
	_target_zoom = ROOM_FOCUS_ZOOM if close_view else default_zoom
	_clamp_target()


func _clamp_target() -> void:
	var half := Vector2(_target_zoom * size.x / maxf(1, size.y), _target_zoom) * 0.5
	_target_focus.x = clampf(_target_focus.x, minf(overview.x, bounds.position.x + half.x), maxf(overview.x, bounds.end.x - half.x))
	_target_focus.y = clampf(_target_focus.y, minf(overview.y, bounds.position.y + half.y), maxf(overview.y, bounds.end.y - half.y))


func _fit_zoom() -> float:
	var height := maxf(1.0, size.y)
	var usable := Vector2(maxf(1.0, size.x - minf(230, size.x * 0.24)), maxf(1.0, size.y - minf(145, size.y * 0.22)))
	return maxf(CLOSE_ZOOM, maxf(bounds.size.y * height / usable.y, bounds.size.x * height / usable.x))


func _resize_view() -> void:
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
