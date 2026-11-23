extends "res://scripts/test_perf.gd"

const LEGACY_CFG := "user://render.cfg"
const NEW_VIEWS := "center:192:124:15:42:60,wide:192:140:15:50:130,far:192:160:15:55:240"
const SWITCH_LIMIT_MS := 100.0

var shots_dir := ""
var results: FileAccess
var before_cfg := ""


func _ready() -> void:
	before_cfg = FileAccess.get_file_as_string(LEGACY_CFG)
	if not Gfx.depth_prepass():
		fail("старый render.cfg применился до загрузки игры")
	super._ready()


func fail(reason: String) -> void:
	fails += 1
	print("PERF14E8 FAIL ", reason)


func _run(_mode: String) -> void:
	shots_dir = str(A.get("out", GamePaths.save_dir().path_join("shots")))
	DirAccess.make_dir_recursive_absolute(shots_dir)
	var new_city: bool = A.get("city") == "new"
	if (RenderingServer.get_current_rendering_method() != "forward_plus"
			or RenderingServer.get_current_rendering_driver_name() != "vulkan" or (not new_city and city_src != OWNER)):
		fail("нужны Forward+, Vulkan и заданный город")
		_finish()
		return
	if not before_cfg.contains("depth_prepass/enable=false"):
		fail("нет старого файла с выключенным проходом")
	results = FileAccess.open(shots_dir.path_join("samples.tsv"), FileAccess.WRITE)
	if results == null:
		fail("не удалось открыть таблицу")
		_finish()
		return
	results.store_line("city\tstep\tquality\tview\tdepth\tssao\tgpu_ms\tcpu_prep_ms\tframe_ms\tlaptop_fps")
	A["warm"] = A.get("warm", "48")
	A["n"] = A.get("n", "90")
	if not await _wait_city():
		results.close()
		_finish()
		return
	await _settle()
	if new_city:
		if Gfx.depth_prepass():
			fail("новая игра на «Низкой» запустилась с проходом")
		var new_views := _views(NEW_VIEWS)
		await _measure_preset("new", 0, "low", new_views)
		await _click_quality("verylow")
		await _measure_preset("new", 1, "verylow", new_views)
	else:
		await _owner_sequence()
	if FileAccess.get_file_as_string(LEGACY_CFG) != before_cfg:
		fail("игра изменила старый render.cfg")
	results.close()
	await _menu_exit()


func _owner_sequence() -> void:
	var owner_views := _views(VIEWS_REGRESS)
	var first_high: Image
	var sequence := ["high", "verylow", "high", "low", "medium"]
	print("PERF14E8 START pid=", OS.get_process_id(), " buildings=", game.city.buildings.size())
	for step in sequence.size():
		var quality: String = sequence[step]
		if step > 0:
			await _click_quality(quality)
		await _measure_preset("owner", step, quality, owner_views)
		var center := await _golden_preset(step, quality, owner_views)
		if step == 0:
			first_high = center
		if step == 2:
			_regress_image("high/center", center, first_high, true)
	await _depth_ab(owner_views.back())


func _depth_ab(view: Array) -> void:
	await _click_quality("verylow")
	_view(view)
	var off := await _measure("e8/depth_ab/off")
	ProjectSettings.set_setting(Gfx.DEPTH_PREPASS, true)
	var on := await _measure("e8/depth_ab/on")
	ProjectSettings.set_setting(Gfx.DEPTH_PREPASS, false)
	var off_again := await _measure("e8/depth_ab/off_again")
	print("PERF14E8 GPU A/B verylow/%s off=%.3f on=%.3f off=%.3f" % [view[0], off["gpu"], on["gpu"], off_again["gpu"]])
	if float(on["gpu"]) <= maxf(float(off["gpu"]), float(off_again["gpu"])):
		fail("A/B: не видно выигрыша от выключения прохода")


func _wait_city() -> bool:
	var deadline := Time.get_ticks_msec() + 150_000
	while not game.ready_done and Time.get_ticks_msec() < deadline:
		await frames(5)
	if not game.ready_done:
		fail("город не загрузился")
		return false
	game.can_save = false
	game.settings["autosave"] = false
	game.settings["quality_user"] = true
	game.hud.set_speed(0.0)
	game.hud.visible = false
	game.rig.cine = true
	game.weather.force = 0.0
	game.weather.level = 0.0
	game.weather.wet = 0.0
	game.weather.left_h = 0.0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	vp = get_viewport().get_viewport_rid()
	Engine.max_fps = 0
	await _perf13_wait_icons()
	while game._clock_busy or game._placement_running:
		await frames(1)
	if get_window().size != Vector2i(1920, 1080):
		fail("размер окна %s" % str(get_window().size))
		return false
	return true


func _click_quality(quality: String) -> void:
	var panel: Control = game.hud.settings_panel
	game.hud.visible = true
	game.hud._open_settings(true)
	panel.show()
	if panel.find_child("quality_restart", true, false) != null:
		fail("осталась строка о перезапуске")
	var button := panel.find_child("q_" + quality, true, false) as Button
	if button == null:
		fail("нет кнопки " + quality)
		return
	var previous: String = game.settings["quality"]
	var before_draw := int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW))
	var before_special := int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION))
	var started := Time.get_ticks_usec()
	button.pressed.emit()
	var ms := (Time.get_ticks_usec() - started) / 1000.0
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(game.settings_path()))
	if not saved is Dictionary or saved.get("quality") != quality:
		fail("выбранный пресет не записан: " + quality)
	if ms >= SWITCH_LIMIT_MS:
		fail("переход %s → %s занял %.2f мс" % [previous, quality, ms])
	panel.hide()
	game.hud.visible = false
	Engine.max_fps = 0
	var first_frames := PackedFloat32Array()
	for i in 8:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		first_frames.append((now - started) / 1000.0)
		started = now
	print("PERF14E8 SWITCH %s → %s handler=%.2f ms first_frames=%s draw=%d specialization=%d" % [previous, quality,
		ms, str(first_frames), int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)) - before_draw,
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)) - before_special])
	var deadline := Time.get_ticks_msec() + 20_000
	while Gfx.swap_busy() and Time.get_ticks_msec() < deadline:
		await frames(1)
	if Gfx.swap_busy():
		fail("замена картинок ещё не закончилась: " + quality)


func _measure_preset(town: String, step: int, quality: String, views: Array) -> void:
	var depth := not Gfx.is_low(quality)
	if game.settings["quality"] != quality or Gfx.depth_prepass() != depth or game.env.ssao_enabled != depth:
		fail("проход глубины или SSAO не соответствуют " + quality)
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for view: Array in views:
		_view(view)
		game._set_hour(9.0)
		var sample := await _measure("e8/%s/%d/%s/%s" % [town, step, quality, view[0]])
		var gpu: float = sample["gpu"]
		var cpu: float = sample["rcpu"]
		if gpu <= 0.0 or cpu <= 0.0:
			fail("нет замера GPU или CPU")
		results.store_line("%s\t%d\t%s\t%s\t%d\t%d\t%.4f\t%.4f\t%.4f\t%.2f" % [
			town, step, quality, view[0], int(Gfx.depth_prepass()), int(game.env.ssao_enabled),
			gpu, cpu, sample["frame"], 1000.0 / maxf(0.01, 9.0 * gpu + 1.3 * cpu)])
		results.flush()


func _golden_preset(step: int, quality: String, views: Array) -> Image:
	_freeze()
	var center: Image
	for view: Array in views:
		_view(view)
		game._set_hour(9.0)
		await frames(SHOT_WAIT)
		var image := await _snap()
		var tag := "%s_%s" % [quality, view[0]]
		var path := shots_dir.path_join("%d_%s.png" % [step, tag])
		if image.save_png(path) == OK:
			print("PERF14E8 SHOT ", path)
		else:
			fail("не удалось записать " + path)
		_regress_image("%s/%s" % [quality, view[0]], image, Image.load_from_file(GOLDEN.path_join(tag + ".png")), false)
		if view[0] == "center":
			center = image
	_unfreeze()
	game.hud.set_speed(0.0)
	game.hud.visible = false
	game.rig.cine = true
	return center


func _menu_exit() -> void:
	RenderingServer.viewport_set_measure_render_time(vp, false)
	await frames(8)
	game.hud.visible = true
	game.rig.cine = false
	game.hud.set_speed(4.0)
	await frames(12)
	game.hud._toggle(game.hud.pause_panel)
	for node in game.hud.pause_panel.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == "Выход" and button.is_visible_in_tree():
			print("PERF14E8 DONE fails=", fails, " menu exit")
			button.pressed.emit()
			return
	fail("нет кнопки выхода в меню паузы")
	_finish()


func _finish() -> void:
	print("PERF14E8 DONE fails=", fails)
	TestSuite.finish(self, int(fails != 0))
