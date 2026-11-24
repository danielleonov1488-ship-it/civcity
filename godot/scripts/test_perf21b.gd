extends "res://scripts/test_perf14_base.gd"

const Suite = preload("res://scripts/test_perf14a3_suite.gd")
const TASK_DIR := "D:/CivCity/.work/stage7/perf22f"
const ARENAS := ["colosseum", "circus_fl", "theatre", "odeon"]
const ZOOMS := [42.0, 9.0, CameraRig.DIST_MAX]

var shots := ""
var fails := 0


func _ready() -> void:
	if not has_meta("perf21b_venues_only"):
		_run.call_deferred()


func _run() -> void:
	if has_meta("perf14_profiles"):
		set_meta("perf14_args", {"out": str(get_meta("perf14_profiles"))})
	setup_run()
	if not args.has("out"):
		out = TASK_DIR
	shots = str(get_meta("perf14_shots", out.path_join("shots")))
	DirAccess.make_dir_recursive_absolute(shots)
	Game.sandbox = false
	OS.set_environment("CIVCITY_HEROSCREEN", "0")
	if await boot_city("new", "high", false):
		game.tutorial.finish()
		game.hud.set_speed(0.0)
		game.city.money = 200000.0
		game.city.tips["free_place"] = true
		game.city.research[Defs.B["nat_tree"]["unlock"]] = true
		game.hud._close_tray()
		_flat(Vector2(173, 135), Vector2(64, 50))
		var sites := [Vector2(160, 126), Vector2(177, 126), Vector2(152, 146)]
		for index in ZOOMS.size():
			game.hud.close_panels()
			await _old_points(Vector2(160 + index * 17, 126), ZOOMS[index])
			await _tools(sites[index], ZOOMS[index])
		await _click_visible_house(Vector2(168, 152))
		if not args.has("baseline") and not args.has("matrix_only"):
			await _arenas(Vector2(177, 192))
	else:
		_check(false, "новый город не открылся")
	print("PERF21B DONE fails=", fails)
	Suite.finish(self, int(fails > 0))


func _tools(at: Vector2, distance: float) -> void:
	var label := "zoom_%d" % int(distance)
	game.hud.close_panels()
	# На близком зуме центрируем весь мазок на карте. Клетка земли — 25 см.
	var road := at + Vector2(0.0, 2.5)
	_aim(road, distance)
	game.set_tool("road")
	game.brush_line = true
	var start := _screen(road - Vector2(1.25, 0.0))
	var end := _screen(road + Vector2(1.25, 0.0))
	_move(start)
	await frames(2)
	_button(start, true)
	var started_on_map := _on_map(start) and game.painting
	_move(end, MOUSE_BUTTON_MASK_LEFT)
	await frames(2)
	_button(end, false)
	var cells := 0
	for i in range(-4, 5):
		if game.land.is_road(road + Vector2(i * Land.CELL, 0.0)):
			cells += 1
	_check(started_on_map and _on_map(end) and cells == 9, "%s дорога %d/9 клеток" % [label, cells])
	await frames(4)

	var ground := at - Vector2(0.0, 3.0)
	_aim(ground, distance)
	game.set_tool("house_pleb")
	game.tool_variant = 0
	game.next_variant = 0
	var pixel := _screen(ground)
	var ready := await _preview(pixel, "house_pleb")
	var id := game.city.next_id
	if ready:
		_click(pixel)
	var b: Dictionary = game.city.buildings.get(id, {})
	game.set_tool("")
	var house_ok := _check(not b.is_empty(), label + " дом")
	if not house_ok:
		# Проверяем карточку и снос даже после ошибки установки.
		var checked := game.city.check_place("house_pleb", ground, 0.0)
		if checked["err"] == "":
			b = game.city.place("house_pleb", ground, 0.0, 0, 0, false, Vector2i.ZERO, false, checked)
		id = int(b.get("id", -1))
	if not b.is_empty():
		var built := await _until(func(): return game.visuals.has(id) and not game._grow_live.has(id))
		_check(built, label + " стройка завершилась")
		var pos: Vector2 = b["pos"]
		var target := Vector3(pos.x, float(b["y"]) + 1.2, pos.y)
		game.hud.close_panels()
		if distance == 9.0:
			_aim(at, distance)
			var old_roof := game.rig.cam.unproject_position(target)
			_move(old_roof)
			await frames(2)
			print("PERF21B OBS zoom_9 прежняя точка сноса: UI=", game.hud.mouse_over_ui(), " экран=", old_roof)
		_aim(pos, distance)
		var roof := game.rig.cam.unproject_position(target)
		_move(roof)
		await frames(2)
		_click(roof)
		if not _check(_on_map(roof) and _card(id), label + " карточка дома"):
			print("PERF21B OBS карточка: экран=", roof, " ожидается=", id,
				" выбрано=", game.selected.get("id"), " карточка=", game.hud.info_b.get("id"))
		if not args.has("baseline") and not args.has("matrix_only"):
			await _shot(label + ".png")
		game.hud.close_panels()
		game.set_tool("bulldoze")
		_move(roof)
		await frames(2)
		_click(roof)
		_check(not game.city.buildings.has(id), label + " снос")
		game.set_tool("")
	else:
		_check(false, label + " карточка дома: нет постройки")
		_check(false, label + " снос: нет постройки")

	var tree_at := at + Vector2(4.0, 7.0)
	var tree := game.city.place("nat_tree", tree_at, 0.0, 8, 0)
	_aim(tree_at, distance)
	await frames(4)
	var stem := game.rig.cam.unproject_position(Vector3(tree_at.x, float(tree.get("y", Land.BASE_Y)) + 0.55, tree_at.y))
	_move(stem)
	await frames(2)
	_click(stem)
	_check(_on_map(stem) and not tree.is_empty() and _card(int(tree["id"])), label + " дерево")
	var empty_at := tree_at - Vector2(4.0, 0.0)
	_aim(empty_at, distance)
	var empty := _screen(empty_at)
	_move(empty)
	await frames(2)
	var empty_on_map := _on_map(empty) and game.hover != Vector2.INF and game.land.occ_at(game.hover) == 0
	_click(empty)
	_check(empty_on_map and game.selected.is_empty() and not game.hud.info_panel.visible, label + " пустая земля")


func _old_points(at: Vector2, distance: float) -> void:
	_aim(at, distance)
	var targets := {"начало дороги": at + Vector2(-3.0, 2.5), "конец дороги": at + Vector2(3.0, 2.5),
		"дом": at - Vector2(0.0, 3.0)}
	for name: String in targets:
		game.set_tool("house_pleb" if name == "дом" else "road")
		var pixel := _screen(targets[name])
		_move(pixel)
		await frames(2)
		var err := ""
		if name == "дом":
			err = str(game.placement_hint("house_pleb", targets[name]).get("err", ""))
		print("PERF21B OBS zoom_%d прежняя точка «%s»: кадр=%s UI=%s экран=%s %s" %
			[int(distance), name, _on_map(pixel), game.hud.mouse_over_ui(), pixel, err])
	game.set_tool("")


func _click_visible_house(at: Vector2) -> void:
	_aim(at, 9.0)
	game.set_tool("house_pleb")
	var pixel := _screen(at)
	if not _check(await _preview(pixel, "house_pleb"), "призрак дома перед движением камеры"):
		game.set_tool("")
		return
	var shown: Vector2 = game.place_info["pos"]
	var id := game.city.next_id
	# Камера сдвинулась между последним кадром призрака и щелчком.
	_aim(at + Vector2(0.5, 0.0), 9.0)
	var live := game.ground_at_mouse()
	_check(live.distance_to(shown) > 0.25, "новый луч земли ушёл от призрака: %s" % live)
	_click(pixel)
	game.set_tool("")
	var b: Dictionary = game.city.buildings.get(id, {})
	var actual: Vector2 = b.get("pos", Vector2.INF)
	_check(shown.distance_to(actual) < 0.05, "дом на месте призрака: %s → %s" % [shown, actual])


func _arenas(at: Vector2) -> void:
	_flat(at, Vector2(70.0, 66.0))
	for type: String in ARENAS:
		game.city.level = Defs.LEVELS.size() - 1
		game.city.research[Defs.B[type]["unlock"]] = true
		# Награды за городские цели ограничивают казну, поэтому даём деньги перед каждой стройкой.
		game.city.money = 200000.0
		game.hud.close_panels()
		_aim(at, 72.0)
		game.set_tool(type)
		game.tool_variant = 0
		game.next_variant = 0
		var pixel := _screen(at)
		if not _check(await _preview(pixel, type), type + " годное место"):
			game.set_tool("")
			continue
		var pl := game.place_info
		var id := game.city.next_id
		_click(pixel)
		game.set_tool("")
		var b: Dictionary = game.city.buildings.get(id, {})
		if not _check(not b.is_empty() and is_equal_approx(float(b["y"]), Land.BASE_Y),
				"%s построен на ровной земле (y=%s, призрак y=%s)" % [type, b.get("y"), pl["y"]]):
			continue
		await _until(func(): return game.spectacle.venues.has(id), 45000)
		var venue: Dictionary = game.spectacle.venues.get(id, {})
		if _check(game.visuals.has(id) and not venue.is_empty(), type + " модель и трибуны готовы"):
			var seats: Array = venue["lay"]["seats"]
			_check(not seats.is_empty(), "%s мест на трибунах: %d" % [type, seats.size()])
			game.spectacle.force(id, "show", 0.30, true)
			var audience: Array = venue["who"]
			var seated := 0
			var root: Node3D = venue["root"]
			for person: Dictionary in audience:
				if person["st"] == "sit":
					var seat := root.to_global(seats[person["seat"]]["root"])
					if seat.y >= game.land.height_at(seat.x, seat.z) - 0.1:
						seated += 1
			_check(seated > 0 and seated == audience.size(), "%s зрители над землёй: %d/%d" % [type, seated, audience.size()])
			game.rig.set_view(Vector3(at.x, Land.BASE_Y, at.y), 20.0, 54.0, 72.0 if type in ["colosseum", "circus_fl"] else 50.0)
			game.hud.close_panels()
			_move(Vector2(100.0, 650.0))
			await frames(8)
			await _shot(type + ".png")
		game.demolish_building(b, false)
		await _until(func(): return not game._placement_running)
		_check(not game.spectacle.venues.has(id), type + " трибуны убраны при сносе")


## Снимки площадок после завершения маршрутов бота, в том же запуске Godot.
func capture_venues(active_game: Game, folder: String) -> int:
	game = active_game
	shots = folder
	if not _check(DirAccess.make_dir_recursive_absolute(shots) == OK, "папка снимков площадок"):
		return fails
	game.can_save = false
	game.hud.set_speed(0.0)
	game.set_tool("")
	game.city.tips["free_place"] = true
	set_quality("high")
	await _arenas(Vector2(177.0, 192.0))
	print("PERF21B VENUES DONE fails=", fails)
	return fails


func _flat(at: Vector2, size: Vector2) -> void:
	var land := game.land
	var cells := land.footprint_cells([Rect2(-size * 0.5, size)], at, 0.0)
	land.flatten_cells(cells, Land.BASE_Y, Land.Kind.GRASS)
	game.clear_nature_cells(cells)


func _aim(at: Vector2, distance: float) -> void:
	game.rig.set_view(Vector3(at.x, Land.BASE_Y, at.y), 0.0, 66.0, distance)


func _on_map(pixel: Vector2) -> bool:
	return get_viewport().get_visible_rect().has_point(pixel)


func _card(id: int) -> bool:
	return game.selected.get("id") == id and game.hud.info_b.get("id") == id and game.hud.info_panel.visible


func _until(condition: Callable, ms := 24000) -> bool:
	var deadline := Time.get_ticks_msec() + ms
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await frames(1)
	return condition.call()


func _preview(pixel: Vector2, type: String) -> bool:
	if not _on_map(pixel):
		print("PERF21B OBS ", type, " точка вне кадра: ", pixel)
		return false
	_move(pixel)
	await frames(2)
	var ready := await _until(func() -> bool:
		return (game.place_info.get("_t") == type
			and is_instance_valid(game.ghost) and game.ghost.visible), 10000)
	var err: String = game.place_info.get("err", "нет призрака")
	var blocked := game.hud.mouse_over_ui()
	if not ready or blocked or err != "":
		print("PERF21B OBS ", type, " экран=", pixel, " земля=", game.ground_at_mouse(), " UI=", blocked, " ошибка=", err)
	return ready and not blocked and err == ""


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


func _click(at: Vector2) -> void:
	_button(at, true)
	_button(at, false)


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
