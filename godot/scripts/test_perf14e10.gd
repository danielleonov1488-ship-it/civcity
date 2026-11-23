extends "res://scripts/test_perf14e9.gd"

const FASTER := "Ещё быстрее — после перезапуска игры"
const FULL_QUALITY := "Полное качество — после перезапуска игры"

var session_depth: bool
var samples: FileAccess


func _ready() -> void:
	var requested_depth := not OS.get_cmdline_user_args().has("depth=off")
	session_depth = Gfx.depth_prepass()
	var config := FileAccess.get_file_as_string(Gfx.RENDER_OVERRIDE)
	print("PERF14E10 STARTUP depth=", session_depth, " render_cfg=", JSON.stringify(config))
	if session_depth != requested_depth or (session_depth and FileAccess.file_exists(Gfx.RENDER_OVERRIDE)) \
			or (not session_depth and not config.contains("depth_prepass/enable=false")):
		fail("неверный проход глубины при запуске")
	else:
		super._ready()
		return
	_finish()


func fail(reason: String) -> void:
	fails += 1
	print("PERF14E10 FAIL ", reason)


func _boot(mode: String) -> void:
	# golden_s9d строит природу до первого снижения качества, одинаково для обеих сессий.
	A["layout_quality"] = "high"
	super._boot(mode)


func _run(_mode: String) -> void:
	if A.has("probe") or A.has("probe_after"):
		fail("пробы e9 с переключением прохода глубины отключены в этом стенде")
		_finish()
		return
	var output := str(A.get("out", GamePaths.save_dir().path_join("shots")))
	samples = FileAccess.open(output.path_join("samples.tsv"), FileAccess.WRITE)
	if samples == null or city_src != OWNER:
		fail("нужны папка замеров и город владельца")
		_finish()
		return
	samples.store_line("city\tstep\tquality\tview\tdepth\tssao\tgpu_ms\tcpu_prep_ms\tframe_ms\tlaptop_fps")
	A["warm"] = A.get("warm", "48")
	A["n"] = A.get("n", "90")
	shots_dir = output.path_join("owner")
	await _run_city()
	if session_depth:
		game.settings["quality"] = "high"
		game.write_settings()
	game.queue_free()
	await frames(2)
	city_src = ""
	shots_dir = output.path_join("new")
	_boot("new")
	await _run_city()
	samples.close()
	_finish()


func _switch_bench(views: Array) -> void:
	var sequence := ["high", "verylow", "high", "low", "medium", "verylow"] if session_depth else ["verylow", "low", "high", "verylow"]
	# После загрузки раскладки восстанавливаем стартовый пресет из настроек сеанса.
	var initial: String = sequence[0]
	_quality(initial)
	var center_grass := {}
	var first_high: Image
	vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for step: int in sequence.size():
		var quality: String = sequence[step]
		if step > 0:
			var source: String = game.settings["quality"]
			_view(views[0])
			var ms := _click_quality(quality)
			if quality == "verylow" and ms >= SWITCH_LIMIT_MS:
				fail("переход %s → verylow занял %.2f мс" % [source, ms])
			await _switch_frames(source, quality)
		else:
			_check_quality(quality, "%d_%s" % [step, quality], false)
		await _wait_rebuilds()
		_foliage_state("%d_%s" % [step, quality])
		for view: Array in views:
			_view(view)
			game._set_hour(9.0)
			await _wait_rebuilds()
			await frames(SHOT_WAIT)
			var image := await _snap()
			var key := "%s/%s" % [quality, view[0]]
			var tag := key.replace("/", "_")
			if city_src == OWNER and session_depth and key == "high/center":
				if step == 0:
					center_grass = _grass_counts()
					first_high = image
				else:
					# Ковёр держит прежнюю густоту при разнице до 5%. Сохраняем живой кадр
					# и повторяем снимок с той же историей ковра, что у первого high.
					_save_shot(image, "%d_%s_live" % [step, tag])
					_regress_image(key, image, first_high, true)
					var live_grass := _grass_counts()
					_restore_grass_counts(center_grass)
					image = await _snap()
					_restore_grass_counts(live_grass)
			_save_shot(image, "%d_%s" % [step, tag])
			if city_src == OWNER and session_depth != Gfx.is_low(quality):
				_regress_image(key, image, Image.load_from_file(GOLDEN.path_join(tag + ".png")), false)
			if Gfx.is_low(quality):
				await _measure_view(step, quality, view[0])
		if city_src == OWNER and step == (1 if session_depth else 2):
			await _shot_hint(quality)
	RenderingServer.viewport_set_measure_render_time(vp, false)


func _grass_counts() -> Dictionary:
	var counts := {}
	for key: Vector2i in game.grass.tiles:
		var tile: Dictionary = game.grass.tiles[key]
		var counts_in_tile := {}
		for part: String in ["g", "f"]:
			var node: MultiMeshInstance3D = tile[part]
			if node:
				counts_in_tile[part] = Vector2i(node.multimesh.instance_count, node.multimesh.visible_instance_count)
		counts[key] = counts_in_tile
	return counts


func _restore_grass_counts(counts: Dictionary) -> void:
	for key: Vector2i in counts:
		if not game.grass.tiles.has(key):
			continue
		var tile: Dictionary = game.grass.tiles[key]
		for part: String in counts[key]:
			var node: MultiMeshInstance3D = tile[part]
			var count: Vector2i = counts[key][part]
			if node and node.multimesh.instance_count == count.x:
				node.multimesh.visible_instance_count = count.y


func _click_quality(quality: String) -> float:
	var panel: Control = game.hud.settings_panel
	game.hud.visible = true
	game.hud._open_settings(true)
	panel.show()
	var button := panel.find_child("q_" + quality, true, false) as Button
	if button == null:
		fail("нет кнопки " + quality)
		return 0.0
	var previous: String = game.settings["quality"]
	var started := Time.get_ticks_usec()
	button.pressed.emit()
	var ms := (Time.get_ticks_usec() - started) / 1000.0
	_check_quality(quality, previous + "_" + quality, true)
	print("PERF14E10 SWITCH %s → %s handler=%.2f ms depth=%s ssao=%s" % [
		previous, quality, ms, Gfx.depth_prepass(), game.env.ssao_enabled])
	return ms


func _check_quality(quality: String, tag: String, capture: bool) -> void:
	var panel: Control = game.hud.settings_panel
	if not capture:
		game.hud.visible = true
		game.hud._open_settings(true)
		panel.show()
	var low := Gfx.is_low(quality)
	var expected_ssao := session_depth and not low
	var expected_hint := FASTER if session_depth else FULL_QUALITY
	var hint := panel.find_child("quality_restart", true, false) as Label
	if hint == null or hint.is_visible_in_tree() != (session_depth == low) \
			or (hint.is_visible_in_tree() and hint.text != expected_hint):
		fail("строка о перезапуске: " + quality)
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(game.settings_path()))
	var config := ConfigFile.new()
	if (capture and (not saved is Dictionary or saved.get("quality") != quality
			or config.load(Gfx.RENDER_OVERRIDE) != OK
			or config.get_value("rendering", "driver/depth_prepass/enable", null) != not low)):
		fail("пресет или проход для следующего запуска не записан: " + quality)
	if game.settings["quality"] != quality or game._applied_quality != quality or Gfx.depth_prepass() != session_depth \
			or game.env.ssao_enabled != expected_ssao or game.env.glow_enabled != not low \
			or game.sun.shadow_enabled != (quality != "verylow") or get_viewport().msaa_3d != (Viewport.MSAA_DISABLED if low else Viewport.MSAA_2X):
		fail("пресет не применился сразу или изменился проход глубины: " + quality)
	print("PERF14E10 HINT ", tag, " ", hint.text if hint and hint.is_visible_in_tree() else "скрыта")
	panel.hide()
	game.hud.visible = false
	if is_instance_valid(game._quality_fade):
		game._quality_fade.hide()
	Engine.max_fps = 0


func _shot_hint(quality: String) -> void:
	var panel: Control = game.hud.settings_panel
	_view(_views(VIEWS_REGRESS)[0])
	game.hud.visible = true
	game.hud._open_settings(true)
	panel.show()
	await frames(3)
	_save_shot(await _snap(), quality + "_restart_ru")
	if not session_depth:
		I18n.set_lang("en")
		if I18n.t(FULL_QUALITY) != "Full quality after a restart":
			fail("нет английской строки о перезапуске")
		await frames(3)
		_save_shot(await _snap(), quality + "_restart_en")
		I18n.set_lang("ru")
	panel.hide()
	game.hud.visible = false


func _measure_view(step: int, quality: String, view: String) -> void:
	var town := "owner" if city_src == OWNER else "new"
	var sample := await _measure("e10/%s/%d/%s/%s" % [town, step, quality, view])
	var gpu: float = sample["gpu"]
	var cpu: float = sample["rcpu"]
	if gpu <= 0.0 or cpu <= 0.0:
		fail("нет замера GPU или CPU")
	samples.store_line("%s\t%d\t%s\t%s\t%d\t%d\t%.4f\t%.4f\t%.4f\t%.2f" % [
		town, step, quality, view, int(Gfx.depth_prepass()), int(game.env.ssao_enabled),
		gpu, cpu, sample["frame"], 1000.0 / maxf(0.01, 9.0 * gpu + 1.3 * cpu)])
	samples.flush()


func _save_shot(image: Image, name: String) -> void:
	var path := shots_dir.path_join(name + ".png")
	if image.save_png(path) == OK:
		print("PERF14E10 SHOT ", path)
	else:
		fail("не удалось записать " + path)


func _finish() -> void:
	print("PERF14E10 DONE fails=", fails)
	TestSuite.finish(self, int(fails != 0))
