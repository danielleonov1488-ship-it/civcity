extends Node3D

const Suite = preload("res://scripts/test_perf14a3_suite.gd")
const SHOP := "stall_fruit"
const ZOOMS := [42.0, 9.0, CameraRig.DIST_MAX]
const SHOTS := "D:/CivCity/.work/stage7/fix26/shots"

var game: Game


func _ready() -> void:
	Game.boot = {"new": "1", "nologin": "1", "hour": "11"}
	game = preload("res://main.tscn").instantiate() as Game
	add_child(game)
	game.can_save = false
	_run()


func _run() -> void:
	if not _check(await _until(func(): return game.ready_done, 90000), "город не открылся"):
		return
	game.can_save = false
	game.settings["autosave"] = false
	game.tutorial.finish()
	game.hud.set_speed(0.0)
	game.hud.close_panels()
	var city := game.city
	city.cozy_v = 1
	city.auto_hire = false
	city.money = 2500.0
	city.tips["free_place"] = true
	var land := game.land
	var flat := land.footprint_cells([Rect2(-48, -9, 96, 18)], Vector2(188, 182), 0.0)
	land.flatten_cells(flat, Land.BASE_Y, Land.Kind.GRASS)
	game.clear_nature_cells(flat)
	city.road_cells += land.paint_line(Vector2(144, 180), Vector2(232, 180), 1.3, Land.Kind.ROAD, true).size()
	var station_door := city.door_point(city.center())
	city.road_cells += land.paint_line(station_door, Vector2(station_door.x, 180), 1.3, Land.Kind.ROAD, true).size()
	var pl := game.placement_hint("house_pleb", Vector2(157, 184))
	if not _check(pl["err"] == "" and not pl.get("noroad", false), "площадка дома у дороги: %s" % pl["err"]):
		return
	var home := city.place("house_pleb", pl["pos"], pl["yaw"], pl["variant"], pl["color"])
	if not _check(not home.is_empty() and city.house_connected(home) and city.manual_hiring(), "дом у дороги: построен=%s, подключён=%s, ручной найм=%s" %
			[not home.is_empty(), not home.is_empty() and city.house_connected(home), city.manual_hiring()]):
		return
	var id := int(home["id"])
	if not _check(await _until(func(): return game.visuals.has(id) and not game._grow_live.has(id)), "дом ещё строится"):
		return
	var renderer := RenderingServer.get_current_rendering_method()
	game.set_tool(SHOP)
	var near := _roadside_spot(166.0)
	var far := _roadside_spot(220.0)
	if not _check(near.is_finite() and far.is_finite(), "годные для лавки места у дороги"):
		return
	for zoom: float in ZOOMS:
		await _move_ghost(near, zoom)
		var in_reach := await _until(func(): return _valid_ghost(near) and game.cover.lit.has(id))
		if not _check(in_reach and game.cover.pool.visible and game.cover.want.get(id) == Cover.GREEN
				and game.cover.lit[id]["col"] == Cover.GREEN and game.cover.sets.get("why") == "staff",
				"%s, зум %.0f: дом должен светиться до найма, позиция=%s, ошибка=%s, без дороги=%s, охват=%s" %
				[renderer, zoom, game.place_info.get("pos"), game.place_info.get("err"),
					game.place_info.get("noroad"), game.cover.sets]):
			return
		print("FIX26 PASS ", renderer, " zoom=", zoom, " дом подсвечен до найма")
		if zoom == ZOOMS[0]:
			if not await _shot("stall_reach_%s.png" % renderer):
				return
		await _move_ghost(far, zoom)
		var out_of_reach := await _until(func(): return _valid_ghost(far) and not game.cover.lit.has(id))
		if not _check(out_of_reach and not game.cover.want.has(id) and not game.cover.pool.visible,
				"%s, зум %.0f: подсветка осталась вдали" % [renderer, zoom]):
			return
		print("FIX26 PASS ", renderer, " zoom=", zoom, " вдали подсветка гаснет")
	# Общий расчёт работает для бань, а фонтан и храм идут через охват памятников.
	for type: String in ["balnea", "fountain", "temple"]:
		var reach := Cover.place_sets(city, type, near)
		if not _check((reach["green"] as Array).has(id), "%s: дом не в охвате" % type):
			return
	city.auto_hire = true
	var short_staff := Cover.place_sets(city, SHOP, near)
	if not _check(short_staff["why"] == "staff" and (short_staff["green"] as Array).has(id),
			"при автонайме пока нет людей, но виден будущий охват"):
		return
	game.set_tool("")
	print("FIX26 DONE")
	Suite.finish(self)


func _roadside_spot(x: float) -> Vector2:
	for z: float in [182.5, 182.0, 181.75, 183.0, 183.5, 184.0]:
		var at := Vector2(x, z)
		var pl := game.placement_hint(SHOP, at)
		if pl.get("err") == "" and not pl.get("noroad", true):
			return at
	return Vector2.INF


func _move_ghost(at: Vector2, zoom: float) -> void:
	game.rig.set_view(Vector3(at.x, Land.BASE_Y, at.y), 0.0, 66.0, zoom)
	await get_tree().process_frame
	var screen := game.rig.cam.unproject_position(Vector3(at.x, game.land.height_at(at.x, at.y), at.y))
	var event := InputEventMouseMotion.new()
	event.position = screen
	event.global_position = screen
	get_viewport().push_input(event, true)
	await get_tree().process_frame


func _valid_ghost(at: Vector2) -> bool:
	var pl := game.place_info
	return pl.get("_t") == SHOP and pl.get("err") == "" and not pl.get("noroad", true) 		and is_instance_valid(game.ghost) and game.ghost.visible and game.hover.distance_to(at) < 0.5


func _until(condition: Callable, timeout := 15000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return condition.call()


func _shot(name: String) -> bool:
	await RenderingServer.frame_post_draw
	var path := SHOTS.path_join(name)
	var error := get_viewport().get_texture().get_image().save_png(path)
	if not _check(error == OK, "сохранение снимка %s: %s" % [path, error]):
		return false
	print("FIX26 SHOT ", path)
	return true


func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("FIX26 FAIL " + message)
		Suite.finish(self, 1)
	return ok
