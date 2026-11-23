extends Node

const Report = preload("res://scripts/speed_test_report.gd")
const OWNER := "D:/CivCity/.work/owner_save/city.json"
const STAGE := "D:/CivCity/.work/stage7/perf14g2"

var game: Game
var out := STAGE.path_join("shots")
var speed_test
var fails := 0
var scenario := "full"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_unit()
	if DisplayServer.get_name() == "headless" or fails != 0:
		_done()
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("case="):
			scenario = arg.trim_prefix("case=")
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=")
	if not _check(scenario in ["full", "stop", "menu", "normal"], "known scenario") or not await _boot():
		_done()
		return
	print("SPEEDTEST CASE ", scenario)
	if scenario == "normal":
		await _play_and_quit()
		return
	if scenario == "menu":
		await _measure("ru", "high", false, false)
		if fails == 0:
			await _measure("ru", "high", true, false)
		await _play_and_quit()
		return
	if scenario == "stop":
		await _measure("en", "high", false, false)
	else:
		await _measure("ru", "high", true, true)
		if fails == 0:
			await _measure("en", "verylow", true, true)
		if fails == 0:
			await _measure("en", "verylow", false, false)
	await get_tree().process_frame
	_done()


func _play_and_quit() -> void:
	if fails != 0:
		_done()
		return
	var distance := game.rig.dist
	game.rig.set_view(Vector3(208, 0, 140), 22.0, 41.0, 52.0)
	game.hud.set_speed(4.0)
	var before := game.hour
	var deadline := Time.get_ticks_msec() + 8000
	while is_equal_approx(game.hour, before) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not _check(not is_equal_approx(game.hour, before) and game.rig.dist != distance, "regular play advances"):
		_done()
		return
	game.hud._toggle(game.hud.pause_panel)
	for node in game.hud.pause_panel.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == "Выход" and button.is_visible_in_tree():
			button.pressed.emit()
			if scenario == "menu":
				_check(not game.gfx._measure and game.gfx._speed_exit_frame > Engine.get_process_frames(),
					"render timing disabled before menu exit")
			print("SPEEDTEST DONE fails=", fails, " menu exit")
			return
	_check(false, "Exit button in pause menu")
	_done()


func _unit() -> void:
	I18n.set_lang("en")
	var a := Report.Samples.new()
	for i in 99:
		a.add(10.0, 4.0, 2.0)
	a.add(50.0, 0.0, 0.0)
	var b := Report.Samples.new()
	b.add(100.0, 8.0, 0.0)
	var total := Report.Samples.new()
	total.merge(a)
	total.merge(b)
	var stats := total.stats()
	_check(stats["count"] == 101 and is_equal_approx(stats["fps"], 101000.0 / 1140.0), "weighted average FPS")
	_check(is_equal_approx(stats["low"], 1000.0 / 75.0) and stats["worst"] == 100.0, "slowest 1% and worst frame")
	_check(stats["over33"] == 2 and stats["over50"] == 1, "strict frame thresholds")
	_check(is_equal_approx(stats["cpu"], 4.04) and stats["gpu"] == 2.0, "available CPU/GPU samples")
	var info := {"version": "1.0 (build 7)", "os": "Test", "gpu": "GPU", "adapter": "Vulkan", "driver": "123",
		"cpu": "CPU", "cores": 8, "ram": "8.0 GiB", "screen": "1920x1080", "window": "1280x720", "scale": 0.75,
		"cap": "60", "vsync": "on", "quality": "high", "smooth": "on", "buildings": 75, "citizens": 250}
	var segments: Array[Report.Samples] = [a, b, Report.Samples.new(), Report.Samples.new()]
	var formatted := Report.format_report(info, segments, stats)
	_check(formatted.split("\n").size() == 11 and formatted.contains("build 7") and formatted.contains("250 citizens")
		and formatted.contains("Smoothness: on") and formatted.contains("Wide | 1 | 10.0 | 10.0 | 100.0 | — | 8.00 | 1 | 1")
		and formatted.contains("Far | 0 | —"), "report formatting")
	var green := Report.verdict({"fps": 50.0, "low": 35.0}, "high")
	_check(green["grade"] == "smooth" and I18n.t(green["text"]) == "Smooth gameplay" and I18n.t("кадров/с") == "FPS", "smooth threshold and translation")
	_check(Report.verdict({"fps": 30.0, "low": 20.0}, "high")["grade"] == "stutter", "yellow grade")
	_check(Report.verdict({"fps": 30.0, "low": 19.9}, "high")["grade"] == "heavy", "red grade")
	_check(Report.verdict({"fps": 80.0, "low": 34.9}, "high")["quality"] == "medium", "low FPS changes verdict")
	_check(Report.verdict({"fps": 30.0, "low": 20.0}, "medium")["quality"] == "low", "playable threshold")
	_check(Report.verdict({"fps": 29.9, "low": 50.0}, "high")["quality"] == "low", "average FPS changes verdict")
	_check(Report.verdict({"fps": 12.0, "low": 6.0}, "verylow")["quality"] == "verylow", "quality floor")
	_check(Report.verdict({}, "medium")["quality"] == "medium", "empty result")
	I18n.set_lang("ru")
	print("SPEEDTEST UNIT fails=", fails)


func _boot() -> bool:
	var profile := GamePaths.save_dir().path_join("speed_test_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	if not _check(DirAccess.make_dir_recursive_absolute(profile) == OK and DirAccess.make_dir_recursive_absolute(out) == OK, "isolated output"):
		return false
	if not _check(DirAccess.copy_absolute(OWNER, profile.path_join("city.json")) == OK, "owner save copy"):
		return false
	var settings := FileAccess.open(profile.path_join("settings.json"), FileAccess.WRITE)
	if not _check(settings != null, "isolated settings"):
		return false
	settings.store_string(JSON.stringify({"quality": "high", "quality_user": true, "show_fps": false, "autosave": false,
		"fullscreen": false, "fps_cap": 0, "lang": "ru"}))
	settings.close()
	GamePaths._dir = profile
	Game.boot = {"play": "1", "nologin": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	add_child(game)
	var deadline := Time.get_ticks_msec() + 150000
	while not game.ready_done and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not _check(game.ready_done and game.city.buildings.size() > 100, "owner city loaded"):
		return false
	game.can_save = false
	game.hud.advisor_panel.hide()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	game.weather.force = 0.0
	game._set_hour(9.0)
	# Ждём фоновые иконки построек перед первым замером.
	var icons := 0
	for key: String in Defs.B:
		icons += int(not bool(Defs.B[key].get("hidden", false)))
	deadline = Time.get_ticks_msec() + 90000
	while game.hud.icons.size() < icons and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return _check(game.hud.icons.size() == icons, "building icons ready")


func _measure(lang: String, quality: String, full: bool, capture: bool) -> void:
	I18n.set_lang(lang)
	game.settings["quality"] = quality
	game._apply_quality()
	Gfx.swap_all()
	game.gfx._set_measure(lang == "en" or scenario == "menu")
	game.hud.set_speed(2.0 if lang == "ru" else 0.0)
	game.hud.paused_speed = 4.0
	game.rig.set_view(Vector3(211, 0, 145), 16.0, 42.0, 61.0)
	game.hud._open_settings()
	var button := game.hud.settings_panel.find_child("speed_test", true, false) as Button
	if not _check(button != null and button.is_visible_in_tree(), "settings button " + lang):
		return
	if capture:
		await _shot(lang + "_button")
	game.hud.advisor_panel.hide()
	game.hud.guidance_queue.clear()
	var tip := game.hud.advisor_panel
	if lang == "en":
		game.tutorial._enter(Tutorial.step_index("move"))
		tip = game.tutorial.card
	else:
		game.hud._guidance_playing = true
		game.hud.advisor("Этаж — без карточки дома",
			"Нажмите «Этаж» справа внизу или клавишу U. Для нескольких домов ведите мышью с зажатой кнопкой вдоль улицы — этаж получат готовые дома, пока хватает денариев.",
			Callable(), true)
		game.hud._guidance_playing = false
	if not _check(tip.is_visible_in_tree(), "guidance shown before start " + lang):
		return
	game.rig._yaw_t += 0.05
	var before := _state()
	button.pressed.emit()
	speed_test = game.gfx.speed_test
	if not _check(speed_test != null and _running() and _guidance_hidden(), "started from settings with guidance hidden " + lang):
		return
	var deadline := Time.get_ticks_msec() + 30000
	while speed_test.active and speed_test._countdown < 0 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not _check(_running() and speed_test._countdown in range(1, 41), "countdown " + lang):
		return
	if capture:
		await _shot(lang + "_running")

	if not full:
		var stop := speed_test._running.find_children("*", "Button", true, false)[0] as Button
		stop.pressed.emit()
		_check(_state() == before and _detached() and not speed_test._layer.visible and speed_test.report_path == ""
			and not game.hud.guidance_suspended and tip.is_visible_in_tree(), "Stop restores state and guidance " + lang)
		print("SPEEDTEST STOP render timing restored=", game.gfx._measure)
		return

	var after := []
	speed_test._result.visibility_changed.connect(func(): after.append_array(_state()), CONNECT_ONE_SHOT)
	deadline = Time.get_ticks_msec() + 75000
	while speed_test.active and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not _check(not speed_test.active and _detached() and after == before and speed_test._result.is_visible_in_tree()
			and _guidance_hidden(), "full run restores state while keeping guidance hidden " + lang):
		return
	for samples in speed_test._samples:
		if not _check(samples.frames.size() > 10, "frames in each segment " + lang):
			return
	var path: String = speed_test.report_path
	var report: String = speed_test.report_text
	if not _check(path.begins_with("user://speed_test/") and FileAccess.get_file_as_string(path) == report
			and report.contains("Quality: " + quality), "saved report " + lang):
		return
	if capture:
		await _capture_result(lang, quality)
		if lang == "ru":
			_copy_report(report)
	speed_test._close()
	_check(not speed_test._layer.visible and not game.hud.guidance_suspended and tip.is_visible_in_tree()
		and (lang != "en" or game.tutorial.camera_keys.is_visible_in_tree()), "guidance restored after result " + lang)
	if lang == "ru":
		tip.hide()


func _capture_result(lang: String, quality: String) -> void:
	var grades := {"smooth": {"fps": 72.0, "low": 52.0}, "stutter": {"fps": 47.0, "low": 32.0}, "heavy": {"fps": 26.0, "low": 16.0}}
	var measured_grade: String = speed_test._medal.grade
	print("SPEEDTEST VERDICT ", lang, " ", measured_grade, " ", speed_test._fps.text, " FPS")
	for grade: String in grades:
		var sample: Dictionary = grades[grade]
		if grade != "smooth" or measured_grade != grade:
			speed_test._show_result(sample, "high")
			_check(speed_test._fps.text == str(roundi(sample["fps"])), "FPS display " + grade)
		_check(speed_test._medal.grade == grade and _guidance_hidden(), "result grade and hidden guidance " + lang + " " + grade)
		await _shot(lang + "_" + grade + "_result")
	# Проверяем применение после снимков, чтобы не влиять на следующий замер.
	if lang == "en":
		var recommended: String = speed_test._recommended
		speed_test._apply.pressed.emit()
		_check(game.settings["quality"] == recommended and game.settings["quality_user"] and not speed_test._apply.visible,
			"apply recommendation")
	else:
		# У синтетического результата другой пресет. Возвращаем настоящий перед проверкой копирования.
		var total := Report.Samples.new()
		for sample in speed_test._samples:
			total.merge(sample)
		speed_test._show_result(total.stats(), quality)


func _copy_report(report: String) -> void:
	speed_test._copy.pressed.emit()
	var clipboard := DisplayServer.clipboard_get().replace("\r\n", "\n")
	if not _check(clipboard == report, "copied report"):
		return
	var path := out.path_join("ru_report.txt")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if _check(file != null and file.store_string(clipboard + "\n"), "clipboard text artifact"):
		file.close()
		print("SPEEDTEST REPORT ", path)


func _guidance_hidden() -> bool:
	var hud := game.hud
	var tut := game.tutorial
	return hud.guidance_suspended and not hud.advisor_panel.is_visible_in_tree() and not hud.notes_box.is_visible_in_tree() \
		and not hud.pointer.is_visible_in_tree() and not hud.pointer_text.is_visible_in_tree() \
		and not tut.card.is_visible_in_tree() and not tut.camera_keys.is_visible_in_tree()


func _detached() -> bool:
	return not RenderingServer.frame_pre_draw.is_connected(speed_test._before_draw) \
		and not get_tree().process_frame.is_connected(speed_test._begin_frame)


func _state() -> Array:
	return [game.rig.capture_view(), game.rig.cine, game.rig.is_processing(), game.rig.is_processing_unhandled_input(),
		game.hud.visible, game.hud.root.visible, game.gfx._fps_box.visible,
		game.gfx._measure, game.speed, game.hud.paused_speed, game.settings["quality"], get_viewport().scaling_3d_scale, Engine.max_fps]


func _running() -> bool:
	return speed_test.active and speed_test._running.is_visible_in_tree() and not game.rig.is_processing() and game.speed == 0.0 \
		and not game.hud.visible and not game.hud.settings_panel.visible and not game.gfx._fps_box.visible and game.gfx._measure


func _shot(name: String) -> void:
	for i in 4:
		await get_tree().process_frame
	var path := out.path_join(name + ".png")
	if _check(get_viewport().get_texture().get_image().save_png(path) == OK, "screenshot " + name):
		print("SPEEDTEST SHOT ", path)


func _check(ok: bool, reason: String) -> bool:
	if not ok:
		fails += 1
		print("SPEEDTEST FAIL ", reason)
	return ok


func _done() -> void:
	if is_instance_valid(game) and game.gfx != null:
		await game.gfx.prepare_speed_test_exit()
	print("SPEEDTEST DONE fails=", fails)
	get_tree().quit(0 if fails == 0 else 1)
