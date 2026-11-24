extends "res://scripts/test_pixels14.gd"

const PERF20_ROOT := "D:/CivCity/.work/stage7/perf20b"
const SCALES := [0.75, 0.85, 0.90, 1.00]
const AA := {
	"fxaa": Viewport.SCREEN_SPACE_AA_FXAA,
	"smaa": Viewport.SCREEN_SPACE_AA_SMAA,
	"off": Viewport.SCREEN_SPACE_AA_DISABLED,
	"msaa2": Viewport.SCREEN_SPACE_AA_DISABLED,
}
const SERIES := ["off", "sharp0", "fsr2"]

var _surface: Viewport
var _phase_shader: Array[ShaderMaterial] = []


func _run(_mode: String) -> void:
	while not game.ready_done:
		await frames(5)
	if city_src.is_empty() or get_window().size != Vector2i(1920, 1080):
		fail("нужны город владельца и окно 1920×1080")
		_finish20()
		return
	shot_dir = str(A.get("out", PERF20_ROOT.path_join("raw")))
	if DirAccess.make_dir_recursive_absolute(shot_dir) != OK:
		fail("нет папки стенда")
		_finish20()
		return
	sweep = FileAccess.open(shot_dir.path_join("samples.tsv"), FileAccess.WRITE)
	if sweep == null:
		fail("не открыть samples.tsv")
		_finish20()
		return
	sweep.store_line("quality\tview\tcase\tscale\tgpu_median_ms\tgpu_p99_ms\tuhd_fps\tuhd_fps_p99\tsamples")
	game.can_save = false
	game.settings["autosave"] = false
	game.settings["quality_user"] = true
	game.settings["smooth"] = false
	game.settings["show_fps"] = false
	game.gfx.refresh()
	var weather: Weather = game.weather
	if weather != null:
		weather.force = 0.0
		weather.left_h = 0.0
		weather.level = 0.0
		weather.wet = 0.0
	game.rig.cine = true
	game.hud.set_speed(0.0)
	game.hud.hide()
	await _perf13_wait_icons()
	_surface = get_viewport()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	vp = _surface.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var renderer := RenderingServer.get_current_rendering_method()
	print("PERF20B READY ", RenderingServer.get_video_adapter_name(), " ", renderer, "/",
		RenderingServer.get_current_rendering_driver_name(), " ", get_window().size,
		" buildings=", game.city.buildings.size(), " depth_prepass=", Gfx.depth_prepass())
	var views := _views(VIEWS_REGRESS)
	var qualities: Array = ["low", "verylow"] if renderer == "forward_plus" else ["verylow"]
	for q: String in qualities:
		_quality(q)
		game._set_hour(9.0)
		for v: Array in [views[0], views[2]]:
			_pose(v)
			await _matrix20(q, v[0], renderer)
	if renderer == "forward_plus":
		_quality("low")
		await _motion20(views)
	_finish20()


func _pose(view: Array) -> void:
	_view(view)
	if game.grass != null:
		game.grass.fill_now()


func _matrix20(q: String, view: String, renderer: String) -> void:
	_quality(q)
	var base_scale := _surface.scaling_3d_scale
	var base_sharpness := _surface.fsr_sharpness
	var base_mode := _surface.scaling_3d_mode
	var base_aa := _surface.screen_space_aa
	var base_msaa := _surface.msaa_3d
	await _record20(q, view, "base", base_scale)
	await _shot20("%s_%s_base" % [q, view])
	var scales: Array = SCALES if renderer == "forward_plus" else [0.5, 0.75]
	var aa_keys: Array = AA.keys() if renderer == "forward_plus" else ["fxaa", "off", "msaa2"]
	if renderer == "forward_plus" and q == "verylow":
		scales = [0.5] + scales
	for scale: float in scales:
		for key: String in aa_keys:
			_setup20(scale, key, renderer)
			await _record20(q, view, key, scale)
			await _shot20(_name20(q, view, key, scale))
		if renderer == "forward_plus" and (scale == 0.85 or scale == 0.90):
			var probes := ["sharp0", "sharp05", "fsr2"]
			if RenderingServer.get_current_rendering_driver_name() == "metal" and OS.has_feature("arm64"):
				probes.append_array(["metalfx_spatial", "metalfx_temporal"])
			for key: String in probes:
				_setup20(scale, key, renderer)
				await _record20(q, view, key, scale)
				await _shot20(_name20(q, view, key, scale))
	_surface.msaa_3d = base_msaa
	_surface.screen_space_aa = base_aa
	_surface.fsr_sharpness = base_sharpness
	_surface.scaling_3d_mode = base_mode
	_surface.scaling_3d_scale = base_scale
	await _record20(q, view, "base_repeat", base_scale)


func _setup20(scale: float, key: String, renderer := "forward_plus") -> void:
	_surface.msaa_3d = Viewport.MSAA_2X if key == "msaa2" else Viewport.MSAA_DISABLED
	_surface.screen_space_aa = AA.get(key, Viewport.SCREEN_SPACE_AA_DISABLED)
	_surface.fsr_sharpness = 0.0 if key == "sharp0" else (0.5 if key == "sharp05" else 0.2)
	var mode := Viewport.SCALING_3D_MODE_FSR if scale < 1.0 and renderer == "forward_plus" else Viewport.SCALING_3D_MODE_BILINEAR
	match key:
		"fsr2":
			mode = Viewport.SCALING_3D_MODE_FSR2
		"metalfx_spatial":
			mode = Viewport.SCALING_3D_MODE_METALFX_SPATIAL
		"metalfx_temporal":
			mode = Viewport.SCALING_3D_MODE_METALFX_TEMPORAL
	_surface.scaling_3d_mode = mode
	_surface.scaling_3d_scale = scale


func _record20(q: String, view: String, key: String, scale: float) -> void:
	await frames(55)
	var gpu := PackedFloat32Array()
	for i in 120:
		await get_tree().process_frame
		var ms := RenderingServer.viewport_get_measured_render_time_gpu(vp)
		if ms > 0.0:
			gpu.append(ms)
	var med := _pct(gpu, 0.5)
	var p99 := _pct(gpu, 0.99)
	if gpu.size() < 115:
		fail("неполный замер GPU " + _name20(q, view, key, scale))
	var row := "%s\t%s\t%s\t%.2f\t%.4f\t%.4f\t%.2f\t%.2f\t%d" % [
		q, view, key, scale, med, p99, 1000.0 / maxf(0.01, 9.0 * med), 1000.0 / maxf(0.01, 9.0 * p99), gpu.size()]
	sweep.store_line(row)
	sweep.flush()
	print("PERF20B SAMPLE ", row)


static func _name20(q: String, view: String, key: String, scale: float) -> String:
	return "%s_%s_%03d_%s" % [q, view, roundi(scale * 100.0), key]


func _shot20(name_: String) -> void:
	var file := shot_dir.path_join(name_ + ".png")
	var image := await _snap()
	if image == null or image.get_size() != Vector2i(1920, 1080) or image.save_png(file) != OK:
		fail("не записан кадр " + file)
	else:
		print("PERF20B SHOT ", file)


func _motion20(views: Array) -> void:
	var land: Land = game.land
	var center := land.cell(Vector2(views[0][1], views[0][2]))
	var start := Vector2.ZERO
	var direction := Vector2.ZERO
	var best := INF
	for x in range(center.x - 24, center.x + 25):
		for z in range(center.y - 24, center.y + 25):
			var point := land.cell_center(x, z)
			var distance := Vector2(center).distance_squared_to(Vector2(x, z))
			if distance >= best or not land.is_road(point):
				continue
			for axis: Vector2 in [Vector2.RIGHT, Vector2.DOWN]:
				if land.is_road(point + axis) and land.is_road(point + 2.0 * axis):
					start = point
					direction = axis
					best = distance
					break
	if direction == Vector2.ZERO:
		fail("нет дороги для серии с прохожим")
		return
	A["water"] = "1"
	_freeze()
	_index_scene()
	# Одинаковая фаза волны и течение для каждого алгоритма.
	for shader_name: String in ["water", "pool_water", "stream_flow"]:
		for mat: ShaderMaterial in materials.get(shader_name, {}):
			var shader := Shader.new()
			shader.code = mat.shader.code.replace("shader_type spatial;", "shader_type spatial;\nuniform float perf20_time = 10.0;").replace("TIME", "perf20_time")
			var params := {}
			for uniform: Dictionary in mat.shader.get_shader_uniform_list():
				var key: String = uniform["name"]
				params[key] = mat.get_shader_parameter(key)
			saved.append(_replace_shader.bind(mat, mat.shader, params))
			_replace_shader(mat, shader, params)
			_phase_shader.append(mat)
	if _phase_shader.is_empty():
		fail("не найдены материалы воды")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1402
	var walker := Citizen.create(rng, false)
	add_child(walker)
	walker.play("Walk_Loop", 0.0)
	walker.anim.speed_scale = 0.0
	var stride := walker.anim_len("Walk_Loop")
	walker.rotation.y = atan2(direction.x, direction.y)
	var mid := start + direction
	for motion: String in ["walk", "water"]:
		walker.visible = motion == "walk"
		if walker.visible:
			game.rig.set_view(Vector3(mid.x, land.height_at(mid.x, mid.y) + 0.35, mid.y),
				0.0 if direction == Vector2.RIGHT else 90.0, 45.0, 7.0)
		for scale: float in [0.85, 0.90]:
			for key: String in SERIES:
				_setup20(scale, key)
				walker.position = Vector3(start.x, land.height_at(start.x, start.y), start.y)
				walker.anim.seek(0.0, true)
				if motion == "water":
					_pose(views[2])
				for mat: ShaderMaterial in _phase_shader:
					mat.set_shader_parameter("perf20_time", 10.0)
				await frames(60)
				for step in 32:
					if motion == "walk":
						var point := start + direction * (2.0 * step / 31.0)
						walker.position = Vector3(point.x, land.height_at(point.x, point.y), point.y)
						walker.anim.seek(fposmod(step / 30.0, stride), true)
					else:
						for mat: ShaderMaterial in _phase_shader:
							mat.set_shader_parameter("perf20_time", 10.0 + step / 30.0)
					if step in [3, 7, 11, 15, 19, 23, 27, 31]:
						await _shot20(_name20("low", motion, key, scale) + "_%02d" % step)
					else:
						await RenderingServer.frame_post_draw
	walker.queue_free()
	_restore()
	_unfreeze()


func fail(message: String) -> void:
	fails += 1
	print("PERF20B FAIL ", message)


func _finish20() -> void:
	if sweep != null:
		sweep.close()
	print("PERF20B DONE fails=", fails)
	TestSuite.finish(self, 1 if fails else 0)
