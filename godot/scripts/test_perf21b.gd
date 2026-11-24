extends "res://scripts/test_perf14_base.gd"

const Suite = preload("res://scripts/test_perf14a3_suite.gd")
const TASK_DIR := "D:/CivCity/.work/stage7/perf21b"
const ARENAS := ["colosseum", "circus_fl", "theatre", "odeon"]

var shots := ""
var fails := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	set_meta("perf14_args", {"out": str(get_meta("perf14_profiles", TASK_DIR.path_join("placement_profiles")))})
	setup_run()
	shots = str(get_meta("perf14_shots", TASK_DIR.path_join("shots")))
	DirAccess.make_dir_recursive_absolute(shots)
	Game.sandbox = false
	OS.set_environment("CIVCITY_HEROSCREEN", "0")
	if await boot_city("new", "high", false):
		game.tutorial.finish()
		game.hud.set_speed(0.0)
		game.city.money = 100000.0
		var land := game.land
		var site := Vector2(160, 126)
		land.flatten_cells(land.footprint_cells([Rect2(-23, -15, 78, 48)], site, 0.0), Land.BASE_Y, Land.Kind.GRASS)
		game.city.place("house_pleb", site + Vector2(-8, 0), 0.0, 0, 0, true)
		for index in 3:
			var at := site + Vector2(index * 17.0, 0)
			await _tools(at, [42.0, 9.0, CameraRig.DIST_MAX][index])
		await _arenas(site + Vector2(15, 18))
	else:
		_check(false, "новый город не открылся")
	print("PERF21B DONE fails=", fails)
	Suite.finish(self, int(fails > 0))


func _tools(at: Vector2, distance: float) -> void:
	var label := "zoom_%d" % int(distance)
	var cam := game.rig.cam
	game.rig.set_view(Vector3(at.x, Land.BASE_Y, at.y), 0.0, 66.0, distance)
	game.hud.close_panels()
	await frames(3)
	# Сразу после движения нажимаем и отпускаем: промежуточного игрового кадра нет.
	game.set_tool("road")
	game.brush_line = true
	var start := _screen(at + Vector2(-3, 2.5))
	var end := _screen(at + Vector2(3, 2.5))
	_move(start)
	_button(start, true)
	_move(end, MOUSE_BUTTON_MASK_LEFT)
	_button(end, false)
	_check(game.land.is_road(at + Vector2(-2, 2.5)) and game.land.is_road(at + Vector2(2, 2.5)), label + " оба конца дороги")
	await frames(4)

	game.set_tool("house_pleb")
	game.tool_variant = 0
	game.next_variant = 0
	var ground := at - Vector2(0, 3.0)
	var pixel := _screen(ground)
	_move(pixel)
	var deadline := Time.get_ticks_msec() + 8000
	while (game._preview_pending or not is_instance_valid(game.ghost) or not game.ghost.visible) and Time.get_ticks_msec() < deadline:
		await frames(1)
	_check(not game.hud.mouse_over_ui() and game.place_info.get("err", "") == "", label + " доступное место")
	var id := game.city.next_id
	_button(pixel, true)
	_button(pixel, false)
	var b: Dictionary = game.city.buildings.get(id, {})
	if not _check(not b.is_empty(), label + " дом появился"):
		game.set_tool("")
		return
	game.set_tool("")
	deadline = Time.get_ticks_msec() + 24000
	while game._grow_live.has(id) and Time.get_ticks_msec() < deadline:
		await frames(1)
	_check(game.visuals.has(id), label + " стройка завершилась")
	await _shot(label + ".png")
	game.set_tool("bulldoze")
	var pos: Vector2 = b["pos"]
	var roof := cam.unproject_position(Vector3(pos.x, float(b["y"]) + 1.2, pos.y))
	_move(roof)
	_button(roof, true)
	_button(roof, false)
	_check(not game.city.buildings.has(id), label + " щелчок снёс дом")
	game.set_tool("")
	await frames(4)


func _arenas(at: Vector2) -> void:
	game.rig.set_view(Vector3(at.x, Land.BASE_Y, at.y), 15.0, 62.0, 58.0)
	for type: String in ARENAS:
		var b := game.city.place(type, at, 0.0, 0, 0, true, Vector2i.ZERO, true)
		if not _check(not b.is_empty(), type + " поставлен"):
			continue
		var id: int = b["id"]
		game._finish_placement({}, at, true)
		var deadline := Time.get_ticks_msec() + 20000
		while not game.spectacle.venues.has(id) and Time.get_ticks_msec() < deadline:
			await frames(1)
		var venue: Dictionary = game.spectacle.venues.get(id, {})
		if _check(game.visuals.has(id) and not venue.is_empty(), type + " модель и трибуны готовы"):
			var layout: Dictionary = venue["lay"]
			_check(not (layout["seats"] as Array).is_empty(), type + " места рассчитаны")
			game.spectacle.force(id, "show", 0.30, true)
			_check(not (venue["who"] as Array).is_empty(), type + " зрители сели")
			await _shot(type + ".png")
		game.demolish_building(b, false)
		while game._placement_running:
			await frames(1)
		_check(not game.spectacle.venues.has(id), type + " трибуны убраны при сносе")
	for type: String in ["medic", "academy"]:
		var bp := Catalog.make(type, 0, 0, 0)
		_check(Game._large_blueprint(bp), "%s поставлен в очередь подготовки (%d деталей)" % [type, bp.parts.size()])


func _screen(at: Vector2) -> Vector2:
	return game.rig.cam.unproject_position(Vector3(at.x, game.land.height_at(at.x, at.y), at.y))


func _move(at: Vector2, mask := 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.button_mask = mask
	get_viewport().push_input(event, true)


func _button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.pressed = down
	get_viewport().push_input(event, true)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var file := shots.path_join(name)
	if _check(get_viewport().get_texture().get_image().save_png(file) == OK, "снимок " + name):
		print("PERF21B SHOT ", file)


func _check(ok: bool, what: String) -> bool:
	if not ok:
		fails += 1
	print("PERF21B %s %s" % ["OK" if ok else "FAIL", what])
	return ok
