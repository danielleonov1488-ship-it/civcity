extends "res://scripts/test_perf.gd"
## Замеры отдельной сценой, с теми же сохранением и камерами, что у test_perf.

const STAGE := "D:/CivCity/.work/stage7/perf14b"
const PREVIOUS_GOLDEN := "D:/CivCity/.work/perf_ref/golden_s9d"
const STAT = preload("res://scripts/smooth_scale.gd")
const STRESS_CHANGES := 300
const STRESS_VRAM_LIMIT := 16 * 1024 * 1024
const UPSCALERS := {
	"Bilinear": Viewport.SCALING_3D_MODE_BILINEAR,
	"FSR1": Viewport.SCALING_3D_MODE_FSR,
	"FSR2": Viewport.SCALING_3D_MODE_FSR2,
	"Nearest": Viewport.SCALING_3D_MODE_NEAREST,
}
const BUSY_SHADER := """
shader_type spatial;
render_mode unshaded, fog_disabled, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled;
uniform int work = 16;
void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}
void fragment() {
	vec2 p = SCREEN_UV;
	for (int i = 0; i < work; i++) {
		p = sin(p.yx * vec2(2.17, 2.31) + vec2(0.74, 0.38));
	}
	ALBEDO = vec3(p * 0.5 + 0.5, 0.4);
	ALPHA = 0.02;
}
"""

var output := STAGE.path_join("shots")


func fail(what: String) -> void:
	fails += 1
	print("SMOOTH14 FAIL ", what)


func _run(mode: String) -> void:
	if city_src.is_empty() and A.get("city", OWNER) != "new":
		fail("нет сохранения владельца")
		get_tree().quit(1)
		return
	output = str(A.get("out", output))
	DirAccess.make_dir_recursive_absolute(output)
	await _prepare_city()
	var views := _views(VIEWS_OWNER if not city_src.is_empty() else VIEWS_NEW)
	var candidate := mode == "regress" or A.has("candidate")
	if mode == "stress":
		await _size(1080)
		await _stress(views[0])
	var visual := not city_src.is_empty() and mode in ["regress", "visual"]
	if mode in ["regress", "matrix", "final"]:
		await _matrix(views[0], candidate)
	if visual:
		await _size(1080)
		await _comparisons()
	if mode in ["regress", "load", "final"]:
		await _size(1080)
		await _load_test(views[0], candidate)
	if visual:
		await _effects(views)
		await _upscalers(views)
		await _walking(views[2])
	if mode == "final" and not city_src.is_empty():
		game.queue_free()
		await game.tree_exited
		await frames(2)
		city_src = ""
		_boot("new")
		await _prepare_city()
		await _matrix(_views(VIEWS_NEW)[0], false)
	print("SMOOTH14 DONE fails=%d" % fails)
	get_tree().quit(1 if fails else 0)


func _prepare_city() -> void:
	while not game.ready_done:
		await frames(5)
	game.can_save = false
	game.settings["quality_user"] = true
	game.settings["fps_cap"] = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	vp = get_viewport().get_viewport_rid()
	print("SMOOTH14 ADAPTER ", RenderingServer.get_video_adapter_name(), " city=", "new" if city_src.is_empty() else "owner", " houses=", game.city.buildings.size())
	await _perf13_wait_icons()


func _stress(view: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1402
	var viewport := get_viewport()
	for q: String in ["high", "low"]:
		_preset(q, true)
		_view(view)
		var baseline_scale := viewport.scaling_3d_scale
		var baseline_mode := viewport.scaling_3d_mode
		var floor_scale: float = STAT.STEPS[q][0]
		var middle := (1.0 + floor_scale) * 0.5
		# Сравниваем память на одном масштабе и в одном режиме после освобождения буферов.
		await frames(180)
		var before := await _stress_vram()
		var marks := PackedInt64Array()
		var peak := before
		var switches := 0
		print("SMOOTH14 STRESS START ", q, " bytes=", before)
		for i in STRESS_CHANGES:
			var upper := i % 2 == 1
			var scale := rng.randf_range(middle, 1.0) if upper else rng.randf_range(floor_scale, middle)
			if i % 20 == 0:
				scale = floor_scale
			elif i % 20 == 1:
				scale = 1.0
			var mode := Viewport.SCALING_3D_MODE_FSR if rng.randi_range(0, 1) == 0 else Viewport.SCALING_3D_MODE_BILINEAR
			if viewport.scaling_3d_mode != mode:
				viewport.scaling_3d_mode = mode
				switches += 1
			viewport.scaling_3d_scale = scale
			await frames(rng.randi_range(2, 10))
			peak = maxi(peak, int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)))
			if (i + 1) % 50 == 0:
				viewport.scaling_3d_mode = baseline_mode
				viewport.scaling_3d_scale = baseline_scale
				await frames(90)
				marks.append(await _stress_vram())
				print("SMOOTH14 STRESS MARK ", q, " changes=", i + 1, " bytes=", marks[-1])
		var final := marks[-1]
		print("SMOOTH14 STRESS RESULT %s changes=%d switches=%d before=%d final=%d peak=%d marks=%s" %
			[q, STRESS_CHANGES, switches, before, final, peak, str(marks)])
		if before <= 0 or final <= 0:
			fail("нет показаний видеопамяти " + q)
		elif final - before > STRESS_VRAM_LIMIT or final - marks[0] > STRESS_VRAM_LIMIT:
			fail("рост видеопамяти " + q)


func _stress_vram() -> int:
	var samples := PackedFloat32Array()
	for i in 30:
		await get_tree().process_frame
		samples.append(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	return int(STAT.percentile(samples, 0.5))


func _size(height: int) -> void:
	DisplayServer.window_set_size(Vector2i(1920, height))
	await frames(12)
	if get_window().size != Vector2i(1920, height):
		fail("размер окна %s вместо 1920×%d" % [get_window().size, height])


func _preset(q: String, tuned: bool, adaptive := false) -> void:
	Gfx.weak_tuning = tuned
	game.gfx.smooth_test = adaptive
	game.settings["smooth"] = adaptive
	_quality(q)


func _wait_seconds(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _sample(label: String, count: int) -> Dictionary:
	# Сторож может снять свой замер при выходе из города, поэтому начинаем после разогрева.
	RenderingServer.viewport_set_measure_render_time(vp, true)
	await frames(6)
	var gpu := PackedFloat32Array()
	var frame := PackedFloat32Array()
	var scales := {}
	var previous := Time.get_ticks_usec()
	var viewport := get_viewport()
	for i in count:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - previous) / 1000.0
		previous = now
		frame.append(ms)
		var cost := RenderingServer.viewport_get_measured_render_time_gpu(vp)
		if cost > 0.0:
			gpu.append(cost)
		var scale := "%.2f" % viewport.scaling_3d_scale
		scales[scale] = float(scales.get(scale, 0.0)) + ms
	var total := 0.0
	for sum: float in scales.values():
		total += sum
	for scale: String in scales:
		scales[scale] = snappedf(100.0 * float(scales[scale]) / maxf(total, 0.001), 0.1)
	var sample := {"gpu": STAT.percentile(gpu, 0.5), "frame": STAT.percentile(frame, 0.5),
		"p75": STAT.percentile(frame, 0.75), "fps": 1000.0 * count / maxf(total, 0.001)}
	var ms: float = sample["gpu"]
	if gpu.is_empty():
		fail(label + ": нет замера GPU")
	print("SMOOTH14 DATA %s gpu=%.3f frame=%.3f p75=%.3f fps=%.1f uhd=%.1f/%.1f/%.1f scales=%s" %
		[label, ms, sample["frame"], sample["p75"], sample["fps"], ms * 7.0, ms * 9.0, ms * 11.0, JSON.stringify(scales)])
	return sample


func _matrix(view: Array, candidate: bool) -> void:
	for height in [1200, 1080]:
		await _size(height)
		_view(view)
		for q: String in PRESETS:
			var label := "%d %s" % [height, q]
			for phase: String in (["before", "fixed", "adaptive"] if height == 1200 else ["fixed", "before", "adaptive"]):
				_preset(q, candidate and phase != "before", phase == "adaptive")
				game._set_hour(float(A.get("hour", "9")))
				await frames(60)
				if phase == "adaptive":
					await _wait_seconds(float(A.get("adapt", "10")))
				await _sample(label + " " + phase, 180 if phase == "adaptive" else 90)
	_preset("low", candidate)


func _effects(views: Array) -> void:
	var glow_levels: Array[float] = []
	for i in 7:
		glow_levels.append(game.env.get_glow_level(i))
	for q: String in ["low", "verylow"]:
		for effect: String in ["fixed", "ssao_off", "glow", "grass_old", "water_old", "lod_old", "citizens_old", "shadow_old", "shadow_hard"]:
			Gfx._sun_low = -1
			_preset(q, true)
			_view(views[3] if effect == "water_old" else views[2])
			match effect:
				"ssao_off": game.env.ssao_enabled = false
				"glow":
					game.env.glow_enabled = true
					for i in 7:
						game.env.set_glow_level(i, 0.8 if i == 1 else 0.0)
				"grass_old":
					Gfx.weak_tuning = false
					game.grass.set_quality(q)
					Gfx.weak_tuning = true
				"water_old":
					await frames(50)
					await _sample("effect %s water_simple" % q, 90)
					for name_: String in ["CityWater", "RiverFar"]:
						var water: MeshInstance3D = game.get_node_or_null(name_)
						if water:
							water.set_instance_shader_parameter("simple_water", false)
				"lod_old": get_viewport().mesh_lod_threshold = 12.0 if q == "verylow" else 1.0
				"citizens_old":
					game.people.max_vis = int(Gfx.VIS[q])
					game.gfx._citizen_shadows(false)
				"shadow_old":
					RenderingServer.directional_shadow_atlas_set_size(4096, true)
					game.sun.directional_shadow_max_distance = 128.0
				"shadow_hard":
					RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
					game.sun.shadow_enabled = true
					game.sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
					game.sun.directional_shadow_max_distance = 70.0
			await frames(60)
			await _sample("effect %s %s" % [q, effect], 90)
	Gfx._sun_low = -1
	for i in glow_levels.size():
		game.env.set_glow_level(i, glow_levels[i])


func _save_shot(name_: String, img: Image) -> void:
	var path := output.path_join(name_)
	if img.save_png(path) == OK:
		print("SMOOTH14 SHOT ", path)
	else:
		fail("не записан снимок " + path)


func _upscalers(views: Array) -> void:
	_preset("low", true)
	_freeze(true)
	var modes := UPSCALERS.duplicate()
	if RenderingServer.get_current_rendering_driver_name() == "metal":
		modes["MetalFX Spatial"] = Viewport.SCALING_3D_MODE_METALFX_SPATIAL
		modes["MetalFX Temporal"] = Viewport.SCALING_3D_MODE_METALFX_TEMPORAL
	var crop_size := Vector2i(390, 182)
	var sheet := Image.create_empty(crop_size.x * modes.size(), crop_size.y * 9, false, Image.FORMAT_RGB8)
	var scene_indices := [2, 0, 3]
	var offsets := [Vector2i(765, 505), Vector2i(570, 260), Vector2i(660, 340)]
	var viewport := get_viewport()
	for row in 3:
		var scale: float = [0.5, 0.6, 0.77][row]
		var base := 0.0
		var col := 0
		for name_: String in modes:
			viewport.scaling_3d_mode = modes[name_]
			viewport.scaling_3d_scale = scale
			for crop in 3:
				_view(views[scene_indices[crop]])
				await frames(45)
				if crop == 0:
					var data := await _sample("upscale %.2f %s" % [scale, name_], 90)
					if col == 0:
						base = data["gpu"]
					var extra := float(data["gpu"]) - base
					print("SMOOTH14 UPSCALER %.2f %s delta=%+.3f uhd9=%+.3f" % [scale, name_, extra, extra * 9.0])
				var img := await _snap()
				img.convert(Image.FORMAT_RGB8)
				sheet.blit_rect(img, Rect2i(offsets[crop], crop_size), Vector2i(col * crop_size.x, (row * 3 + crop) * crop_size.y))
			col += 1
	_save_shot("3_upscalers.png", sheet)
	_unfreeze()
	await _pan(views[2])


func _pan(view: Array) -> void:
	var crop := Rect2i(765, 505, 390, 182)
	var sheet := Image.create_empty(crop.size.x * 3, crop.size.y * 2, false, Image.FORMAT_RGB8)
	var viewport := get_viewport()
	game.hud.visible = false
	for row in 2:
		_view(view)
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if row == 0 else Viewport.SCALING_3D_MODE_FSR2
		viewport.scaling_3d_scale = 0.6
		await frames(90)
		for step in 18:
			var pan := view.duplicate()
			pan[1] = float(view[1]) + step * 0.32
			_view(pan)
			await frames(1)
			if step % 6 == 5:
				var img := await _snap()
				img.convert(Image.FORMAT_RGB8)
				sheet.blit_rect(img, crop, Vector2i(crop.size.x * (step / 6), crop.size.y * row))
	_save_shot("3b_pan.png", sheet)
	game.hud.visible = true


func _walking(view: Array) -> void:
	var land: Land = game.land
	var center := land.cell(Vector2(view[1], view[2]))
	var start := Vector2.ZERO
	var direction := Vector2.ZERO
	var best := INF
	for x in range(center.x - 24, center.x + 25):
		for z in range(center.y - 24, center.y + 25):
			var point := land.cell_center(x, z)
			if not land.is_road(point):
				continue
			var distance := Vector2(center).distance_squared_to(Vector2(x, z))
			if distance >= best:
				continue
			for axis: Vector2 in [Vector2.RIGHT, Vector2.DOWN]:
				var finish := point + 2.0 * axis
				if land.is_road(point + axis) and land.is_road(finish):
					start = point
					direction = axis
					best = distance
					break
	if direction == Vector2.ZERO:
		fail("нет дороги для проверки FSR2 на прохожем")
		return
	_freeze()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1402
	var walker := Citizen.create(rng, false)
	add_child(walker)
	walker.play("Walk_Loop", 0.0)
	walker.anim.speed_scale = 0.0
	var stride := walker.anim_len("Walk_Loop")
	walker.rotation.y = atan2(direction.x, direction.y)
	var midpoint := start + direction
	game.rig.set_view(Vector3(midpoint.x, land.height_at(midpoint.x, midpoint.y) + 0.35, midpoint.y),
		0.0 if direction == Vector2.RIGHT else 90.0, 45.0, 7.0)
	var crop := Rect2i(665, 360, 590, 360)
	var sheet := Image.create_empty(crop.size.x * 3, crop.size.y * 2, false, Image.FORMAT_RGB8)
	var viewport := get_viewport()
	for row in 2:
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if row == 0 else Viewport.SCALING_3D_MODE_FSR2
		viewport.scaling_3d_scale = 0.6
		walker.position = Vector3(start.x, land.height_at(start.x, start.y), start.y)
		walker.anim.seek(0.0, true)
		await frames(60)
		for step in 30:
			var point := start + direction * (2.0 * step / 29.0)
			walker.position = Vector3(point.x, land.height_at(point.x, point.y), point.y)
			walker.anim.seek(fposmod(step / 60.0, stride), true)
			await RenderingServer.frame_post_draw
			if step % 10 == 9:
				var image := viewport.get_texture().get_image()
				image.convert(Image.FORMAT_RGB8)
				sheet.blit_rect(image, crop, Vector2i(crop.size.x * (step / 10), crop.size.y * row))
	walker.queue_free()
	_save_shot("3c_walking.png", sheet)
	_unfreeze()


func _comparisons() -> void:
	var views := _views(VIEWS_REGRESS)
	var destination := str(A.get("golden", ""))
	var candidates := {}
	var keep_old := true
	if not destination.is_empty():
		for q: String in PRESETS:
			for view: Array in views:
				var file := "%s_%s.png" % [q, view[0]]
				if FileAccess.file_exists(destination.path_join(file)):
					fail("эталон уже существует: " + file)
					return
	Gfx._sun_low = -1
	_freeze()
	for q: String in ["verylow", "low", "high", "medium"]:
		var compare_views: Array = views if not destination.is_empty() or not Gfx.is_low(q) else [views[0]]
		_preset(q, false)
		var old := await _shots([q], compare_views, "before")
		_preset(q, true)
		var current := await _shots([q], compare_views, "after")
		for key: String in current:
			var result := _same(old[key], current[key])
			print("SMOOTH14 DIFF ", key, " ", result["info"])
			if Gfx.is_low(q):
				candidates[key] = current[key]
				continue
			if float(result["mean"]) != 0.0:
				keep_old = false
				fail("пиксели до и после различаются: " + key)
			if not destination.is_empty():
				var file := key.replace("/", "_") + ".png"
				var reference := Image.load_from_file(PREVIOUS_GOLDEN.path_join(file))
				var golden_diff := _same(current[key], reference)
				print("SMOOTH14 S9D ", key, " ", golden_diff["info"])
				if float(golden_diff["mean"]) != 0.0:
					keep_old = false
					fail("пиксели golden_s9d различаются: " + key)
		if q == "medium":
			continue
		var name_: String = {"verylow": "1_verylow_before_after.png", "low": "2_low_before_after.png", "high": "4_high_unchanged.png"}[q]
		var before: Image = old[q + "/center"]
		var after: Image = current[q + "/center"]
		var size := before.get_size()
		var strip := Image.create_empty(size.x * (3 if q == "high" else 2), size.y, false, Image.FORMAT_RGB8)
		before.convert(Image.FORMAT_RGB8)
		after.convert(Image.FORMAT_RGB8)
		strip.blit_rect(before, Rect2i(Vector2i.ZERO, size), Vector2i.ZERO)
		strip.blit_rect(after, Rect2i(Vector2i.ZERO, size), Vector2i(size.x, 0))
		if q == "high":
			var difference := before.get_data()
			var other := after.get_data()
			for i in difference.size():
				difference[i] = mini(255, 4 * absi(difference[i] - other[i]))
			var diff := Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGB8, difference)
			strip.blit_rect(diff, Rect2i(Vector2i.ZERO, size), Vector2i(size.x * 2, 0))
		_save_shot(name_, strip)
	_unfreeze()
	if not destination.is_empty() and keep_old:
		_save_set(candidates, destination)
		for key: String in candidates:
			var file := key.replace("/", "_") + ".png"
			if not FileAccess.file_exists(destination.path_join(file)):
				fail("не записан кадр эталона: " + file)
		for q: String in ["high", "medium"]:
			for view: Array in views:
				var file := "%s_%s.png" % [q, view[0]]
				if DirAccess.copy_absolute(PREVIOUS_GOLDEN.path_join(file), destination.path_join(file)) != OK:
					fail("не скопирован прежний эталон: " + file)
		print("SMOOTH14 GOLDEN ", destination)


func _load_test(view: Array, candidate: bool) -> void:
	_view(view)
	game.settings["fps_cap"] = 60
	_preset("low", candidate)
	var viewport := get_viewport()
	viewport.scaling_3d_scale = 1.0
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2.0, 2.0)
	quad.mesh = mesh
	quad.extra_cull_margin = 16384.0
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader := Shader.new()
	shader.code = BUSY_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	quad.material_override = material
	game.add_child(quad)
	var work := 512
	var fixed := {}
	for amount: int in [512, 1024, 1536, 2048, 3072, 4096]:
		work = amount
		material.set_shader_parameter("work", work)
		await frames(25)
		fixed = await _sample("load fixed work=%d" % work, 45)
		if float(fixed["gpu"]) >= 1000.0 / 60.0 and float(fixed["fps"]) < 58.0:
			break
	if float(fixed["gpu"]) < 1000.0 / 60.0 or float(fixed["fps"]) >= 58.0:
		fail("шейдер не создал нужную нагрузку")
	_preset("low", candidate, true)
	game.gfx._smooth.reset(1.0)
	viewport.scaling_3d_scale = 1.0
	Engine.max_fps = 60
	await _wait_seconds(16.0)
	var loaded := await _sample("load adaptive", 180)
	var loaded_scale := viewport.scaling_3d_scale
	quad.queue_free()
	await _wait_seconds(16.0)
	var recovered := await _sample("load recovered", 180)
	var recovered_scale := viewport.scaling_3d_scale
	print("SMOOTH14 LOAD steps=%d scale=%.2f -> %.2f -> %.2f fps=%.1f -> %.1f -> %.1f" %
		[work, 1.0, loaded_scale, recovered_scale, fixed["fps"], loaded["fps"], recovered["fps"]])
	if loaded_scale >= 1.0 or float(loaded["fps"]) < 58.0:
		fail("регулятор под нагрузкой не удержал 60 FPS")
	if not is_equal_approx(recovered_scale, 1.0):
		fail("регулятор не вернул масштаб 1.0")
