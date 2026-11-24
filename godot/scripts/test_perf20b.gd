extends "res://scripts/test_pixels14.gd"

const PERF20_ROOT := "D:/CivCity/.work/stage7/perf20b"
const PERF21_ROOT := "D:/CivCity/.work/stage7/perf21a"
const Perf14Base = preload("res://scripts/test_perf14_base.gd")
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


func _run(mode: String) -> void:
	var perf21 := mode == "perf21a"
	while not game.ready_done:
		await frames(5)
	if city_src.is_empty() or get_window().size != Vector2i(1920, 1080):
		fail("нужны город владельца и окно 1920×1080")
		_finish20()
		return
	shot_dir = str(A.get("out", (PERF21_ROOT if perf21 else PERF20_ROOT).path_join("raw")))
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
	var qualities: Array = ["low", "verylow"] if perf21 or renderer == "forward_plus" else ["verylow"]
	for q: String in qualities:
		if perf21 and A.has("screens_only"):
			break
		_quality(q)
		game._set_hour(9.0)
		for v: Array in [views[0], views[2]]:
			_pose(v)
			if perf21:
				await _matrix21(q, v[0], renderer)
			else:
				await _matrix20(q, v[0], renderer)
	if perf21:
		await _screens21(views)
		for name_: String in ["field", "outline", "decal", "construction", "fort", "campaign", "battle", "speed_result", "menu"]:
			if not FileAccess.file_exists(shot_dir.path_join(name_ + ".png")):
				fail("не снят экран " + name_)
	elif renderer == "forward_plus":
		_quality("low")
		await _motion20(views)
	_finish20()


func _matrix21(q: String, view: String, renderer: String) -> void:
	_quality(q)
	var scale := _surface.scaling_3d_scale
	await _record20(q, view, "base", scale)
	await _shot20("%s_%s_base" % [q, view])
	if renderer == "mobile":
		for factor: float in [0.75, 0.85, 1.0]:
			for key: String in ["fxaa", "smaa", "off"]:
				_setup20(factor, key, renderer)
				await _record20(q, view, key, factor)
				await _shot20(_name20(q, view, key, factor))
	_quality(q)
	await _record20(q, view, "base_repeat", scale)


func _screens21(views: Array) -> void:
	_quality("low")
	game.seasons.force_m = 6.0
	_pose(views[0])
	for look: Array in [["day", 9.0], ["sunset", 20.0], ["night", 23.0]]:
		game._set_hour(look[1])
		await frames(55)
		await _shot20(look[0])
	game._set_hour(9.0)
	game.weather.force = 1.0
	game.weather.level = 1.0
	game.weather.wet = 0.99
	await frames(75)
	if not game.weather.rain.emitting:
		fail("дождь не начался")
	await _shot20("rain")
	game.weather.force = 0.0
	game.weather.level = 0.0
	game.weather.wet = 0.0
	game.weather._wet_mat = null
	game.weather._rain_mat = null
	game.seasons.force_m = 10.0
	await frames(65)
	await _shot20("autumn")
	game.seasons.force_m = 6.0
	var field: Dictionary = {}
	for b: Dictionary in game.city.buildings.values():
		if b["type"] == "farm":
			field = b
			break
	if field.is_empty():
		fail("в сохранении нет поля")
	else:
		var at: Vector3 = game.city.xf(field).origin
		game.rig.set_view(at, 15.0, 42.0, 16.0)
		game.grass.fill_now()
		await frames(55)
		await _shot20("field")
		game.select_building(field)
		await frames(15)
		await _shot20("outline")
		game.select_building({})
		var decal: Node3D = game.stories._route_dot(Vector2(at.x + 2.5, at.z))
		await frames(12)
		await _shot20("decal")
		decal.queue_free()
	var site := Vector2(64.0, 74.0)
	game.rig.set_view(Vector3(site.x, game.land.height_at(site.x, site.y), site.y), 15.0, 42.0, 20.0)
	game.grass.fill_now()
	game.build_anim = true
	var house: Dictionary = game.city.place("house_pleb", site, 0.0, 0, 0, true, Vector2i.ZERO, true)
	game.build_anim = false
	if house.is_empty() or not game._grow_live.has(house["id"]):
		fail("стройка не началась")
	else:
		game._finish_placement({}, site)
		await frames(16)
		await _shot20("construction")
		await frames(40)
	await _screens21_legion()
	game.rig.cine = false
	game.gfx.start_speed_test()
	var deadline := Time.get_ticks_msec() + 70000
	if not game.gfx.speed_test_active():
		fail("проверка скорости не началась")
	else:
		await frames(60)
		await _shot20("speed_running")
		while game.gfx.speed_test_active() and Time.get_ticks_msec() < deadline:
			await frames(1)
		if game.gfx.speed_test_active() or game.gfx.speed_test.report_text.is_empty():
			fail("проверка скорости не закончилась")
		else:
			await _shot20("speed_result")
	await game.gfx.prepare_speed_test_exit()
	RenderingServer.viewport_set_measure_render_time(vp, false)
	game.queue_free()
	await game.tree_exited
	await frames(2)
	_boot("menu")
	while not game.ready_done:
		await frames(1)
	await frames(75)
	await _shot20("menu")


func _screens21_legion() -> void:
	game.hud.show()
	game.city.cozy_v = maxi(1, game.city.cozy_v)
	game.city.legion_v = 3
	var legion: Legion = game.city.legion
	legion.free_mode = true
	legion.sync_v2()
	legion.flags["fort_guide_v"] = 2
	legion.flags["fort_guide"] = Legion.FortGuide.DONE
	for i in range(legion.soldiers.size(), 6):
		legion._add_soldier({"name": "PERF %d" % i, "cls": "legionary", "look_seed": 5130 + i})
	var camp := CampUI.attach(game.hud)
	camp.open()
	var deadline := Time.get_ticks_msec() + 15000
	while camp.opening and Time.get_ticks_msec() < deadline:
		await frames(1)
	await frames(45)
	var fort := camp.diorama as FortCutaway
	if not camp.visible or fort == null or fort.figures.is_empty():
		fail("форт или фигуры не появились")
	else:
		await _shot20("fort")
		camp._campaign()
		await frames(65)
		if camp.lu.visible and is_instance_valid(camp.lu.fort_map):
			await _shot20("campaign")
		else:
			fail("карта похода не появилась")
		camp.lu.close(false)
	camp.close()
	await frames(35)
	var fixture := Perf14Base.new()
	fixture.game = game
	var battle := fixture.open_battle(true)
	fixture.free()
	deadline = Time.get_ticks_msec() + 80000
	while battle.phase in ["loading", "intro"] and Time.get_ticks_msec() < deadline:
		await frames(1)
	if battle.phase != "fight" or battle.views.is_empty():
		fail("бойцы не появились")
	else:
		await _shot20("battle")
	battle.abort()
	await frames(35)


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
		print(_test_name() + " SHOT ", file)


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
	print(_test_name() + " FAIL ", message)


func _test_name() -> String:
	return "PERF21A" if A.get("mode", "") == "perf21a" else "PERF20B"


func _finish20() -> void:
	if sweep != null:
		sweep.close()
	print(_test_name() + " DONE fails=", fails)
	TestSuite.finish(self, 1 if fails else 0)
