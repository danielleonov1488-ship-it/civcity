extends "res://scripts/test_perf.gd"

const DEPTH := "rendering/driver/depth_prepass/enable"
const NEW_VIEWS := "center:192:124:15:42:60,wide:192:140:15:50:130,far:192:160:15:55:240"
const SWITCH_LIMIT_MS := 100.0

var shots_dir: String


func fail(reason: String) -> void:
	fails += 1
	print("PERF14E9 FAIL ", reason)


func _run(_mode: String) -> void:
	var output := str(A.get("out", GamePaths.save_dir().path_join("shots")))
	var both := A.has("both")
	shots_dir = output.path_join("owner") if both else output
	await _run_city()
	if both:
		game.settings["quality"] = "high"
		game.write_settings()
		game.queue_free()
		await frames(2)
		city_src = ""
		shots_dir = output.path_join("new")
		_boot("new")
		await _run_city()
	_finish()


func _run_city() -> void:
	DirAccess.make_dir_recursive_absolute(shots_dir)
	var deadline := Time.get_ticks_msec() + 150_000
	while not game.ready_done and Time.get_ticks_msec() < deadline:
		await frames(5)
	if not game.ready_done or RenderingServer.get_current_rendering_method() != "forward_plus" \
			or RenderingServer.get_current_rendering_driver_name() != "vulkan" or get_window().size != Vector2i(1920, 1080):
		fail("нужны готовый город и окно 1920×1080, Forward+ Vulkan")
		return
	game.can_save = false
	game.settings["autosave"] = false
	game.settings["quality_user"] = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _perf13_wait_icons()
	await _wait_rebuilds()
	await _settle()
	game._set_hour(9.0)
	_freeze()
	var views := _views(VIEWS_REGRESS if city_src == OWNER else NEW_VIEWS)
	print("PERF14E9 START city=", city_src if city_src != "" else "new", " generated_low=", MeadowNature.gen_low)
	if A.has("probe"):
		await _probe_switches(views[0])
	else:
		await _switch_bench(views)
		if A.has("probe_after") and city_src.is_empty():
			shots_dir = shots_dir.path_join("probe")
			DirAccess.make_dir_recursive_absolute(shots_dir)
			A["probe"] = "1"
			await _probe_switches(views[0], true)
	_unfreeze()


func _wait_rebuilds() -> void:
	var deadline := Time.get_ticks_msec() + 30_000
	while _rebuilds_pending() and Time.get_ticks_msec() < deadline:
		await frames(1)
	if _rebuilds_pending():
		fail("очередь обновлений не закончилась")


func _rebuilds_pending() -> bool:
	var grass: GrassCarpet = game.grass
	var grass_busy := is_instance_valid(grass) and grass.radius > 0.0 and grass._settled_cam != grass._cam()
	return Gfx.swap_busy() or game._clock_busy or game._placement_running or not game.parts._initial_draw.is_empty() or grass_busy


func _click_quality(quality: String) -> float:
	var panel: Control = game.hud.settings_panel
	game.hud.visible = true
	game.hud._open_settings(true)
	var button := panel.find_child("q_" + quality, true, false) as Button
	if button == null:
		fail("нет кнопки " + quality)
		return 0.0
	var previous: String = game.settings["quality"]
	var started := Time.get_ticks_usec()
	button.pressed.emit()
	var ms := (Time.get_ticks_usec() - started) / 1000.0
	panel.hide()
	game.hud.visible = false
	# Переход остаётся в игре, а на снимке нужна сцена под ним. Время теста заморожено.
	if is_instance_valid(game._quality_fade):
		game._quality_fade.hide()
	Engine.max_fps = 0
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(game.settings_path()))
	if not saved is Dictionary or saved.get("quality") != quality:
		fail("выбранный пресет не записан: " + quality)
	if ms >= SWITCH_LIMIT_MS and not A.has("probe"):
		fail("переход %s → %s занял %.2f мс" % [previous, quality, ms])
	if not A.has("probe") and (not bool(ProjectSettings.get_setting(DEPTH)) or game.env.ssao_enabled == Gfx.is_low(quality)):
		fail("проход глубины или SSAO после переключения: " + quality)
	print("PERF14E9 SWITCH %s → %s handler=%.2f ms depth=%s ssao=%s" % [previous, quality, ms,
		ProjectSettings.get_setting(DEPTH), game.env.ssao_enabled])
	return ms


func _save_shot(image: Image, name: String) -> void:
	var path := shots_dir.path_join(name + ".png")
	if image.save_png(path) == OK:
		print("PERF14E9 SHOT ", path)
	else:
		fail("не удалось записать " + path)


func _probe_switches(view: Array, toggle_at_switch := false) -> void:
	_view(view)
	for source: String in ["high", "medium"]:
		ProjectSettings.set_setting(DEPTH, true)
		if game.settings["quality"] != source:
			_click_quality(source)
		await _wait_rebuilds()
		await frames(SHOT_WAIT)
		_save_shot(await _snap(), source + "_before")
		if toggle_at_switch:
			ProjectSettings.set_setting(DEPTH, false)
		_click_quality("verylow")
		_foliage_state(source + "_start")
		var seen := 0
		var started := Time.get_ticks_msec()
		var samples := {}
		for target: int in [1, 10, 60, 180, 600]:
			await frames(target - seen)
			samples[target] = await _snap()
			print("PERF14E9 FRAME source=%s frame=%d elapsed=%d ms swap=%s" % [source, target,
				Time.get_ticks_msec() - started, Gfx.swap_busy()])
			seen = target
		for frame: int in samples:
			_save_shot(samples[frame], "%s_verylow_%03d" % [source, frame])
		_foliage_state(source + "_settled")
		await _wait_rebuilds()
		for on: bool in [true, false]:
			ProjectSettings.set_setting(DEPTH, on)
			await frames(60)
			_save_shot(await _snap(), source + ("_depth_on" if on else "_depth_off"))
		if A.has("isolate"):
			Gfx.small_textures(false)
			await _wait_rebuilds()
			await frames(60)
			_save_shot(await _snap(), source + "_full_textures")
			Gfx.small_textures(true)
			Gfx.swap_all()
			await frames(60)
			_save_shot(await _snap(), source + "_sync_textures")
	ProjectSettings.set_setting(DEPTH, true)


func _foliage_state(label: String) -> void:
	var totals := {"synty": [0, 0], "meadow": [0, 0], "standin": [0, 0]}
	for group: Dictionary in game.parts.groups.values():
		var name := str(group["key"]).get_slice("|", 0)
		if not (name.contains("Tree") or name.contains("Bush")):
			continue
		for sub: Dictionary in group["subs"]:
			var node: MultiMeshInstance3D = sub["mmi"]
			if not node.is_visible_in_tree():
				continue
			var mesh: MultiMesh = sub["mm"]
			var kind := "synty" if not name.begins_with("M:") else ("standin" if sub.has("hi") and mesh.mesh != sub["hi"] else "meadow")
			var count: Array = totals[kind]
			count[0] += 1
			count[1] += mesh.visible_instance_count if mesh.visible_instance_count >= 0 else mesh.instance_count
	print("PERF14E9 FOLIAGE ", label, " ", totals, " far_forest=", game.far_forest.size())


func _switch_bench(views: Array) -> void:
	var sequence := ["high", "verylow", "high", "low", "medium", "verylow"]
	var captures := {}
	for step: int in sequence.size():
		var quality: String = sequence[step]
		_view(views[0])
		if game.settings["quality"] != quality:
			var source: String = game.settings["quality"]
			_click_quality(quality)
			await _switch_frames(source, quality)
		await _wait_rebuilds()
		game._set_hour(9.0)
		for view: Array in views:
			_view(view)
			await _wait_rebuilds()
			await frames(SHOT_WAIT)
			var image := await _snap()
			var key := "%s/%s" % [quality, view[0]]
			var tag := key.replace("/", "_")
			_save_shot(image, "%d_%s" % [step, tag])
			if city_src == OWNER:
				_regress_image(key, image, Image.load_from_file(GOLDEN.path_join(tag + ".png")), false)
			else:
				var samples: Array = captures.get_or_add(key, [])
				samples.append(image)
	if city_src != OWNER:
		await _compare_sync(views, captures)


func _compare_sync(views: Array, captures: Dictionary) -> void:
	# У нового города нет кадров в golden_s9d. Сверяем со штатным test_perf на той же карте.
	for quality: String in PRESETS:
		_quality(quality)
		await _wait_rebuilds()
		for view: Array in views:
			_view(view)
			game._set_hour(9.0)
			await _wait_rebuilds()
			await frames(SHOT_WAIT)
			var reference := await _snap()
			var key := "%s/%s" % [quality, view[0]]
			_save_shot(reference, "ref_" + key.replace("/", "_"))
			for actual: Image in captures[key]:
				_regress_image(key, actual, reference, false)


func _switch_frames(source: String, quality: String) -> void:
	var samples := PackedFloat32Array()
	var captures := {}
	var started := Time.get_ticks_usec()
	for i: int in range(1, 9):
		await frames(1)
		var now := Time.get_ticks_usec()
		samples.append((now - started) / 1000.0)
		if i == 2 and quality == "verylow":
			# process_frame уже обработал первый полный кадр с новым качеством.
			captures[1] = get_viewport().get_texture().get_image()
		started = Time.get_ticks_usec()
	print("PERF14E9 SWITCH %s → %s first_frames_ms=%s" % [source, quality, str(samples)])
	if quality == "verylow":
		var seen := 8
		for target: int in [10, 60, 180, 600]:
			await frames(target - seen)
			captures[target] = await _snap()
			seen = target
		for frame: int in captures:
			_save_shot(captures[frame], "%s_verylow_%03d" % [source, frame])


func _finish() -> void:
	print("PERF14E9 DONE fails=", fails)
	TestSuite.finish(self, int(fails != 0))
