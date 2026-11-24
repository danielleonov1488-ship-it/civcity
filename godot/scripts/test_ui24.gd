extends Node3D

const SHOTS := "D:/CivCity/.work/stage7/ui24/shots"
const FULL_TIP := "Полки полны — новые очки пропадают. Изучите что-нибудь."
const TestSuite = preload("res://scripts/test_perf14a3_suite.gd")

var initial_old_ui := Hud.old_ui


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.boot = {"new": "1", "hour": "11", "nologin": "1"}
	var game := (load("res://main.tscn") as PackedScene).instantiate() as Game
	game.can_save = false
	add_child(game)
	for i in 18000:
		if game.ready_done:
			break
		await get_tree().process_frame
	if not _check(game.ready_done, "ready_done timeout"):
		return
	game.speed = 0.0
	game.settings["autosave"] = false
	game.settings["advisor_off"] = true
	var hud: Hud = game.hud
	hud.quiet_tips = 1
	game.tutorial.finish()
	get_window().size = Vector2i(1280, 720)
	await get_tree().create_timer(0.9, true, false, true).timeout

	var city: City = game.city
	var button: Button = hud.top_btns["research"]
	var badge := hud.research_full_badge
	city.level = 1
	city.rp = city.rp_cap()
	city.sim_day()
	var income := float(city.stats.get("rp_day", 0.0))
	if not _check(income > 0.0, "post gives research income"):
		return
	city.stats["rp_day"] = 0.0
	hud.refresh(1)
	if not _check(not badge.visible and button.tooltip_text == "Исследования", "full shelves without income"):
		return
	city.stats["rp_day"] = income
	hud.refresh(1)

	if not await _check_scales(hud):
		return

	game.settings["ui_scale"] = 1.0
	hud.apply_scale(1.0)
	_move_mouse(Vector2(600, 300))
	await _frames(5)
	if not Hud.old_ui and not await _shot("01_badge.png"):
		return
	var point := get_viewport().get_final_transform() * (button.get_global_transform_with_canvas() * (button.size * 0.5))
	_move_mouse(point)
	var delay := float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec", 0.5))
	await get_tree().create_timer(delay + 0.3, true, false, true).timeout
	var hovered := get_viewport().gui_get_hovered_control()
	if not _check(hovered == button, "research button receives hover, got %s" % [hovered]):
		return
	if not Hud.old_ui and not await _shot("02_tooltip.png"):
		return

	button.pressed.emit()
	await _frames(5)
	var study: Button = hud.research_tree.cheapest_available()
	if not _check(study != null, "affordable research available from the scroll"):
		return
	var id := String(study.get_meta("rid"))
	study.pressed.emit()
	hud.research_tree.confirm_yes.pressed.emit()
	await _frames(20)
	if not _check(city.research_done(id) and city.rp < city.rp_cap()
			and float(city.stats.get("rp_day", 0.0)) > 0.0, "research spent points while income stays positive"):
		return
	if not _check(not badge.visible and not hud.full_rp.visible and button.tooltip_text == "Исследования",
			"badge clears after spending and the regular tooltip returns"):
		return
	if not Hud.old_ui:
		# Пересобираем медальоны в старом стиле в том же запуске.
		hud.close_panels()
		hud.top_panel.hide()
		Hud.old_ui = true
		hud._medals.clear()
		hud._top_right()
		city.rp = city.rp_cap()
		hud.refresh(1)
		if not await _check_scales(hud):
			return
	print("UI24 DONE fails=0")
	_finish(0)


func _check_scales(hud: Hud) -> bool:
	var button: Button = hud.top_btns["research"]
	var badge := hud.research_full_badge
	var medal := button.get_theme_stylebox("normal") as StyleBoxTexture
	var texture_root := Hud.AI if Hud.old_ui else Hud.MB
	if not _check(medal != null and medal.texture.resource_path.begins_with(texture_root), "medallion texture matches UI style"):
		return false
	for scale: float in [1.0, hud.ui_cap()]:
		hud.game.settings["ui_scale"] = scale
		hud.apply_scale(scale)
		await _frames(5)
		var shown := badge.is_visible_in_tree() and hud.full_rp.is_visible_in_tree()
		if not _check(is_equal_approx(get_window().content_scale_factor, scale) and shown
				and badge.text == "!" and button.tooltip_text == FULL_TIP, "badge and tooltip at scale %.2f" % scale):
			return false
		if not _check(get_viewport().get_visible_rect().encloses(badge.get_global_rect()), "badge inside viewport"):
			return false
		print("UI24 PASS scale=%.2f old_ui=%s" % [scale, Hud.old_ui])
	return true


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _move_mouse(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)


func _shot(file: String) -> bool:
	await RenderingServer.frame_post_draw
	var frame := get_viewport().get_texture().get_image()
	var size := frame.get_size()
	var scale := Vector2(size) / get_viewport().get_visible_rect().size
	var crop := Vector2i(Vector2(660, 190) * scale).min(size)
	var image := frame.get_region(Rect2i(Vector2i(size.x - crop.x, 0), crop))
	var path := str(get_meta("perf14_shots", SHOTS)).path_join(file)
	if not _check(image.save_png(path) == OK, "save " + path):
		return false
	print("UI24 SHOT ", path)
	return true


func _check(ok: bool, message: String) -> bool:
	if not ok:
		print("UI24 FAIL ", message)
		_finish(1)
	return ok


func _finish(code: int) -> void:
	Hud.old_ui = initial_old_ui
	TestSuite.finish(self, code)
