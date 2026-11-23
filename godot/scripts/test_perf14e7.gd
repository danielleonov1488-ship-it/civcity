extends "res://scripts/test_perf.gd"

const SpeedCheck = preload("res://scripts/speed_test.gd")
const LAPTOP_LEVELS := ["low", "verylow"]
const NEW_VIEWS := "center:192:124:15:42:60,wide:192:140:15:50:130,far:192:160:15:55:240"

var had_override := false
var shots_dir := ""
var results: FileAccess


func _ready() -> void:
	had_override = FileAccess.file_exists(Gfx.RENDER_OVERRIDE)
	super._ready()


func _boot(mode: String) -> void:
	seed(1407)
	AnimClock.movie = 10.0
	super._boot(mode)


func fail(reason: String) -> void:
	fails += 1
	print("PERF14E7 FAIL ", reason)


func _run(_mode: String) -> void:
	var phase: String = A.get("phase", "on")
	var depth := Gfx.depth_prepass()
	shots_dir = A.get("out", GamePaths.save_dir().path_join("shots"))
	DirAccess.make_dir_recursive_absolute(shots_dir)
	print("PERF14E7 START phase=", phase, " depth=", depth, " config=", had_override, " user=", OS.get_user_data_dir())
	if depth != (phase != "off") or had_override != (phase != "on"):
		fail("неверное состояние прохода при старте")
	if RenderingServer.get_current_rendering_method() != "forward_plus" or city_src != OWNER:
		fail("нужны Forward+ и сохранение владельца")
	if fails > 0:
		_finish()
		return
	await _wait_city()
	if phase == "corrupt":
		_check_selection("high", "high", true)
		_finish()
		return
	results = FileAccess.open(shots_dir.path_join("samples.tsv"), FileAccess.WRITE)
	if results == null:
		fail("не удалось открыть таблицу")
		_finish()
		return
	results.store_line("city\tquality\tview\tdepth\ttile_m\tgpu_ms\tcpu_prep_ms\tgame_cpu_ms\tdraws\tshadow_draws\tlaptop_ms\tlaptop_fps")
	A["warm"] = A.get("warm", "48")
	A["n"] = A.get("n", "90")
	await _measure_city("owner", 0.0)
	if depth:
		await _check_controls()
	else:
		await _golden_low("depth_off")
	await _restart_city("new", 0.0)
	await _measure_city("new", 0.0)
	if not depth:
		for tile_m: float in [48.0, 32.0]:
			await _restart_city("play", tile_m)
			await _measure_city("owner", tile_m)
			await _golden_low("tiles_%d" % tile_m)
			await _restart_city("new", tile_m)
			await _measure_city("new", tile_m)
		await _check_controls()
	results.close()
	_finish()


func _wait_city() -> void:
	while not game.ready_done:
		await frames(5)
	game.can_save = false
	game.settings["autosave"] = false
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


func _restart_city(mode: String, tile_m: float) -> void:
	var old: Node = game
	old.queue_free()
	await old.tree_exited
	await frames(12)
	Parts.detail_config = null
	if tile_m > 0.0:
		Parts.detail_config = Parts.Detail.new()
		Parts.detail_config.tile_m = tile_m
	_boot(mode)
	await _wait_city()


func _measure_city(town: String, tile_m: float) -> void:
	var start_depth := Gfx.depth_prepass()
	var views := _views(VIEWS_REGRESS if town == "owner" else NEW_VIEWS)
	var qualities := LAPTOP_LEVELS + ["high"] if tile_m == 0.0 else LAPTOP_LEVELS
	var detail: Parts.Detail = game.parts.detail
	print("PERF14E7 CITY ", town, " buildings=", game.city.buildings.size(), " tile_m=", tile_m,
		" tiles=", detail.tiles if detail != null else 0)
	if tile_m > 0.0 and town == "owner" and (detail == null or detail.tiles == 0):
		fail("разбиение города на плитки не включилось")
	for quality: String in qualities:
		_quality(quality)
		RenderingServer.viewport_set_measure_render_time(vp, true)
		for view: Array in views:
			_view(view)
			game._set_hour(9.0)
			var sample := await _measure("e7/%s/%s/%s/%.0f" % [town, quality, view[0], tile_m])
			var gpu: float = sample["gpu"]
			var cpu: float = sample["rcpu"]
			var predicted := 9.0 * gpu + 1.3 * cpu
			if gpu <= 0.0 or cpu <= 0.0:
				fail("нет времени GPU или подготовки CPU")
			results.store_line("%s\t%s\t%s\t%d\t%.0f\t%.4f\t%.4f\t%.4f\t%d\t%d\t%.4f\t%.2f" % [
				town, quality, view[0], int(start_depth), tile_m, gpu, cpu, sample["proc"], sample["vis_d"], sample["sh_d"],
				predicted, 1000.0 / maxf(predicted, 0.01)])
			results.flush()
	_quality("low")


func _golden_low(tag: String) -> void:
	_freeze()
	var shots := await _shots(LAPTOP_LEVELS, _views(VIEWS_REGRESS), tag)
	for key: String in shots:
		var name := key.replace("/", "_")
		var image: Image = shots[key]
		_shot_image(image, tag + "_" + name)
		var expected := Image.load_from_file(GOLDEN.path_join(name + ".png"))
		if tag == "depth_off":
			_regress_image(key, image, expected, false)
		else:
			var result := _same(image, expected)
			var limit := floori(float(REGRESS_C24_BASE[key]) * REGRESS_MARGIN)
			print("PERF14E7 TILE GOLDEN %s %s mean=%.4f c24=%d/%d %s" % [tag, key, result["mean"], result["c24"], limit,
				"OK" if float(result["mean"]) <= DIFF_MEAN and int(result["c24"]) <= limit else "FAIL"])
	_unfreeze()


func _check_controls() -> void:
	game.hud.visible = true
	game.hud._open_settings(true)
	game.hud.settings_panel.show()
	var label := game.hud.settings_panel.find_child("quality_restart", true, false) as Label
	if label == null:
		fail("нет строки о перезапуске")
		return
	if Gfx.depth_prepass():
		_check_selection("low", "low", false)
		_click_quality("high")
		_check_selection("high", "high", true)
		var speed := SpeedCheck.new()
		speed.game = game
		game.add_child(speed)
		speed._build_ui()
		speed._recommended = "verylow"
		speed._apply.pressed.emit()
		speed._layer.hide()
		speed.queue_free()
		_check_selection("verylow", "verylow", false)
		Gfx.settings_refresh(game.hud)
		if not label.is_visible_in_tree():
			fail("нет подсказки при переходе на низкий пресет")
		await frames(35)
		_shot_image(await _snap(), "restart_ru")
		_click_quality("low")
		_check_selection("low", "low", false)
	else:
		_check_selection("low", "low", false)
		_click_quality("verylow")
		_check_selection("verylow", "verylow", false)
		if label.visible:
			fail("подсказка осталась после запуска с выключенным проходом")
		_click_quality("high")
		_check_selection("high", "verylow", true)
		if not label.visible:
			fail("нет подсказки при переходе на высокую")
	game.hud.settings_panel.hide()


func _click_quality(quality: String) -> void:
	var button := game.hud.settings_panel.find_child("q_" + quality, true, false) as Button
	if button == null:
		fail("нет кнопки " + quality)
		return
	var start := Time.get_ticks_usec()
	button.pressed.emit()
	print("PERF14E7 SETTINGS quality=", quality, " apply_ms=", (Time.get_ticks_usec() - start) / 1000.0)


func _check_selection(selected: String, active: String, next_depth: bool) -> void:
	var config := ConfigFile.new()
	var error := config.load(Gfx.RENDER_OVERRIDE)
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(game.settings_path()))
	if (game.selected_quality() != selected or game.settings["quality"] != active
			or not saved is Dictionary or saved.get("quality") != selected or error != OK
			or config.get_value("rendering", "driver/depth_prepass/enable", null) != next_depth):
		fail("качество %s / %s, следующий проход %s" % [selected, active, str(next_depth)])
	else:
		print("PERF14E7 SETTINGS OK selected=", selected, " active=", active, " next_depth=", next_depth)


func _shot_image(image: Image, name: String) -> void:
	var path := shots_dir.path_join(name + ".png")
	if image.save_png(path) == OK:
		print("PERF14E7 SHOT ", path)
	else:
		fail("не удалось записать " + path)


func _finish() -> void:
	Parts.detail_config = null
	print("PERF14E7 DONE fails=", fails)
	TestSuite.finish(self, int(fails > 0))
