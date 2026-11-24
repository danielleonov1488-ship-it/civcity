extends "res://scripts/test_perf14_base.gd"

const SHOTS := "D:/CivCity/.work/stage7/perf20c/shots"
const RUN := "D:/CivCity/.work/stage7/perf20c/pick"
const TestSuite = preload("res://scripts/test_perf14a3_suite.gd")

var shot_dir := SHOTS
var fails := 0
var cursor := Vector2.INF


func _ready() -> void:
	shot_dir = str(get_meta("perf14_shots", SHOTS))
	set_meta("perf14_args", {"out": str(get_meta("perf14_profiles", RUN))})
	_run.call_deferred()


func _run() -> void:
	setup_run()
	if not await boot_city("new", "high", false):
		_check(false, "новый город не открылся")
		TestSuite.finish(self, 1)
		return
	if not game.tutorial.cine.is_empty():
		game.tutorial._cine_skip()
		while not game.tutorial.cine.is_empty():
			await frames(1)
	game.tutorial.finish()
	game.hud.set_speed(0.0)
	game.hud.refresh()
	await get_tree().create_timer(0.7, false, false, true).timeout
	_check(not game.settings.has("tasks_folded"), "чистые настройки")
	_check(game.hud.tasks_panel.visible and not game.hud.tasks_folded()
		and game.hud.tasks_box.find_child("unfold", true, false) == null, "свиток сразу развёрнут")
	await _shot("requests_expanded.png")
	game.hud.fold_tasks(true)
	var saved = JSON.parse_string(FileAccess.get_file_as_string(game.settings_path()))
	_check(saved is Dictionary and saved.get("tasks_folded") == true, "выбор сворачивания сохранён")
	game.settings.erase("tasks_folded")
	game._load_settings()
	_check(game.hud.tasks_folded(), "выбор сворачивания прочитан")
	game.hud.fold_tasks(false)

	var tree_at := Vector2(160.0, 140.0)
	var street := tree_at + Vector2(1.5, 0.0)
	var land := game.land
	land.flatten_cells(land.footprint_cells([Rect2(-8, -8, 16, 16)], tree_at, 0.0), Land.BASE_Y, Land.Kind.GRASS)
	land.flatten_cells(land.footprint_cells([Rect2(1, -8, 7, 16)], tree_at, 0.0), Land.BASE_Y, Land.Kind.ROAD)
	var tree := game.city.place("nat_tree", tree_at, 0.0, 8, 0, true)
	if tree.is_empty():
		_check(false, "посаженное дерево не создано")
		TestSuite.finish(self, 1)
		return
	game.rig.set_view(Vector3(street.x, Land.BASE_Y, street.y), 0.0, 65.0, CameraRig.DIST_MIN)
	await frames(8)
	var cam := game.rig.cam
	var road_pixel := _road_miss(tree, street)
	_point(road_pixel)
	_check(land.is_road(game.hover), "курсор над пустой мостовой")
	_check_empty_hover()
	await _shot("paving_no_pick.png")

	for distance: float in [CameraRig.DIST_MIN, 34.0]:
		game.rig.set_view(Vector3(street.x, Land.BASE_Y, street.y), 0.0, 65.0, distance)
		await frames(2)
		var stem := Vector3(tree_at.x, float(tree["y"]) + 0.55, tree_at.y)
		var stem_pixel := cam.unproject_position(stem)
		_point(stem_pixel)
		_check(game.pick_building().get("id") == tree["id"], "ствол выбирается, масштаб %.1f" % distance)
		_click()
		_check(game.selected.get("id") == tree["id"] and game.hud.info_b.get("id") == tree["id"],
			"карточка дерева открывается, масштаб %.1f" % distance)
		if distance == CameraRig.DIST_MIN:
			await _shot("tree_pick.png")

	var handles: Array = game.visuals[tree["id"]]["h"]
	var hidden := game.parts.hide_handles(handles)
	_point(cursor + Vector2(0.1, 0))
	_check(game.pick_building().is_empty(), "скрытое дерево не выбирается")
	game.parts.restore(hidden)

	# Курсор рядом с корнем дикого дерева, но луч проходит мимо ствола и кроны.
	game.city.remove(tree, false)
	game.hud._hide_info()
	game._add_nature("SM_Env_Tree_01", Transform3D(Basis.IDENTITY, Vector3(tree_at.x, Land.BASE_Y, tree_at.y)), tree_at)
	game.rig.set_view(Vector3(street.x, Land.BASE_Y, street.y), 0.0, 65.0, CameraRig.DIST_MIN)
	await frames(2)
	game.set_tool("bulldoze")
	_point(cam.unproject_position(Vector3(street.x, Land.BASE_Y, street.y)))
	game._hover_any(game.hover)
	_check(game.hover_nature.is_empty(), "снос не подсвечивает дикое дерево рядом с курсором")
	_click()
	_check(not game.nature_at(tree_at).is_empty(), "щелчок по мостовой не удаляет дикое дерево")
	game.set_tool("")
	print("PERF20C_PICK DONE fails=", fails)
	TestSuite.finish(self, 1 if fails else 0)


func _road_miss(tree: Dictionary, street: Vector2) -> Vector2:
	var cam := game.rig.cam
	var inv := game.city.xf(tree).affine_inverse()
	var boxes := Game.pick_boxes(game.city.blueprint(tree))
	for z in range(-6, 7):
		for x in range(-2, 8):
			var at := street + Vector2(x, z) * 0.12
			if not game.land.is_road(at):
				continue
			var world := Vector3(at.x, Land.BASE_Y, at.y)
			var screen := cam.unproject_position(world)
			if not get_viewport().get_visible_rect().grow(-80.0).has_point(screen):
				continue
			var origin := cam.project_ray_origin(screen)
			var direction := cam.project_ray_normal(screen)
			var limit := origin.distance_to(world) + 0.6
			var lo := inv * origin
			var end := inv * (origin + direction * limit)
			for box: AABB in boxes:
				if box.grow(0.12).intersects_segment(lo, end) != null:
					_point(screen)
					if game.pick_building().is_empty():
						return screen
					break
	_check(false, "нет точки на мостовой внутри старого габарита дерева")
	return cam.unproject_position(Vector3(street.x, Land.BASE_Y, street.y))


func _point(at: Vector2) -> void:
	cursor = at
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	game._input(motion)
	game.hover = game.ground_at_mouse()


func _click() -> void:
	var click := InputEventMouseButton.new()
	click.position = cursor
	click.global_position = cursor
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	game._input(click)
	game._unhandled_input(click)


func _check_empty_hover() -> void:
	game._tool_note(false)
	game._hover_ms = Time.get_ticks_msec() - 500
	game._tool_note(false)
	_check(game.pick_building().is_empty() and game.hud._note.is_empty(), "пустая мостовая без подписи дерева")
	_click()
	_check(game.selected.is_empty() and not game.hud.info_panel.visible, "щелчок по мостовой не открывает карточку")


func _shot(file: String) -> void:
	var marker := Label.new()
	if cursor != Vector2.INF:
		var overlay := CanvasLayer.new()
		overlay.layer = 100
		add_child(overlay)
		overlay.add_child(marker)
		marker.text = "+"
		marker.position = cursor - Vector2(7, 17)
		marker.add_theme_font_size_override("font_size", 24)
		marker.add_theme_constant_override("outline_size", 5)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	await RenderingServer.frame_post_draw
	var path := shot_dir.path_join(file)
	var frame := get_viewport().get_texture().get_image()
	if frame != null and frame.save_png(path) == OK:
		print("PERF20C_PICK SHOT ", path)
	else:
		_check(false, "не записан снимок " + file)
	if marker.is_inside_tree():
		marker.get_parent().queue_free()
	else:
		marker.free()


func _check(ok: bool, message: String) -> void:
	if not ok:
		fails += 1
		print("PERF20C_PICK FAIL ", message)
