extends "res://scripts/test_perf.gd"

const STAGE := "D:/CivCity/.work/stage7/perf14e5"
const LOAD_QUALITIES := ["high", "verylow"]
const SHADOW_QUALITIES := ["high", "medium", "low"]
const CITY_VIEWS := "center:192:124:15:42:60,wide:192:140:15:50:130,far:192:160:15:55:240"
const MIB := 1048576.0

var output: String
var load_quality := "high"
var sharing := false
var boot_start := 0
var memory_rows: FileAccess
var gpu_rows: FileAccess
var fly_rows: FileAccess
var pixel_rows: FileAccess


func _boot(m: String) -> void:
	if A.has("sharing"):
		sharing = A["sharing"] == "1"
	Game.perf14_share_meshes = sharing
	seed(1405)
	var settings := FileAccess.open(GamePaths.save_dir().path_join("settings.json"), FileAccess.WRITE)
	settings.store_string(JSON.stringify({"quality": load_quality, "quality_user": true,
		"ui_scale": 1.0, "fullscreen": false, "autosave": false, "width": 1920, "height": 1080}))
	settings.close()
	boot_start = Time.get_ticks_usec()
	super._boot(m)


func _run(_mode: String) -> void:
	output = str(A.get("out", STAGE.path_join("shots")))
	if RenderingServer.get_current_rendering_method() != "forward_plus" or city_src != OWNER:
		fail("нужны Forward+ и сохранение владельца")
		_done()
		return
	DirAccess.make_dir_recursive_absolute(output)
	memory_rows = _table("memory", "city\tquality\tsharing\tload_ms\tvram_mib\tram_mib\tmeshes\tplace_p50_ms\tplace_max_ms\tparts_p50_ms")
	gpu_rows = _table("gpu", "city\tquality\tview\tswap\tgpu_ms\tframe_ms\tdraws\tshadow_draws\tactive")
	fly_rows = _table("fly", "city\tquality\tswap\tprogress\tframe_ms\tupdate_ms\tswitches\tdraw_compilations")
	pixel_rows = _table("pixels", "city\tquality\tview\tactive\tequal_first\tequal_repeat\tbaseline_stable")
	if memory_rows == null or gpu_rows == null or fly_rows == null or pixel_rows == null:
		fail("не удалось открыть таблицы")
		_done()
		return
	if not A.has("warm"):
		A["warm"] = "34"
	if not A.has("n"):
		A["n"] = "40"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	print("PERF14E5 GPU ", RenderingServer.get_video_adapter_name(), " pid=", OS.get_process_id())
	if A.has("diagnose"):
		await _diagnose()
		_done()
		return
	var first := true
	for city: String in str(A.get("cities", "owner,new")).split(",", false):
		for q: String in LOAD_QUALITIES:
			for share: bool in [false, true]:
				if A.has("sharing") and share != (A["sharing"] == "1"):
					continue
				if not first:
					var old: Node = game
					old.queue_free()
					await old.tree_exited
					await frames(12)
					load_quality = q
					sharing = share
					_boot("play" if city == "owner" else "new")
				first = false
				await _bench(city, q)
	_done()


func fail(reason: String) -> void:
	fails += 1
	print("PERF14E5 FAIL ", reason)


func _done() -> void:
	for file: FileAccess in [memory_rows, gpu_rows, fly_rows, pixel_rows]:
		if file != null:
			file.close()
	print("PERF14E5 DONE fails=", fails)
	get_tree().quit(0 if fails == 0 else 1)


func _table(name: String, header: String) -> FileAccess:
	var file := FileAccess.open(output.path_join(name + ".tsv"), FileAccess.WRITE)
	if file != null:
		file.store_line(header)
	return file


func _bench(city: String, q: String) -> void:
	while not game.ready_done:
		await frames(1)
	var load_ms := (Time.get_ticks_usec() - boot_start) / 1000.0
	game.can_save = false
	game.settings["autosave"] = false
	var boot_q: String = game.settings.get("quality", "")
	if boot_q != q:
		fail("качество при загрузке %s вместо %s" % [boot_q, q])
	var weather: Weather = game.weather
	weather.force = 0.0
	weather.left_h = 0.0
	weather.level = 0.0
	weather.wet = 0.0
	game.hud.set_speed(0.0)
	game.rig.cine = true
	game._set_hour(9.0)
	game.hud.visible = false
	await _perf13_wait_icons()
	await get_tree().create_timer(0.7).timeout
	var views := _views(VIEWS_REGRESS if city == "owner" else CITY_VIEWS)
	_quality(q)
	_view(views.back())
	await frames(40)
	if game.shadow_depth == null or get_window().size != Vector2i(1920, 1080):
		fail("нужны оптимизация теней и окно 1920×1080")
		return
	if q == "verylow" and game.shadow_depth.swapped != 0:
		fail("материалы переключились на качестве без теней")
	var mesh_count := _mesh_count()
	var vram := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / MIB
	var ram := OS.get_static_memory_usage() / MIB
	print("PERF14E5 MEMORY %s %s %d load=%.1f vram=%.2f ram=%.2f meshes=%d" % [city, q, int(sharing), load_ms, vram, ram, mesh_count])
	if sharing and q == "high" and not A.has("memory_only"):
		vp = get_viewport().get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(vp, true)
		for quality: String in SHADOW_QUALITIES:
			_quality(quality)
			await _fly(city, quality, views.front(), views.back(), false)
			await _fly(city, quality, views.front(), views.back(), true)
			for view: Array in views:
				_view(view)
				for swap: bool in [false, true]:
					game.shadow_depth.enabled = swap
					var data := await _measure("%s %s %s swap=%d" % [city, quality, view[0], int(swap)])
					if float(data["gpu"]) <= 0.0:
						fail("нет замера GPU")
					gpu_rows.store_line("%s\t%s\t%s\t%d\t%.3f\t%.3f\t%d\t%d\t%d" % [city, quality, view[0], int(swap),
						data["gpu"], data["frame"], data["vis_d"], data["sh_d"], game.shadow_depth.swapped])
					gpu_rows.flush()
	if not A.has("memory_only"):
		await _pixel_checks(city, q, views)
	_quality(q)
	var placement := await _place_buildings()
	memory_rows.store_line("%s\t%s\t%d\t%.3f\t%.2f\t%.2f\t%d\t%.3f\t%.3f\t%.3f" % [city, q, int(sharing),
		load_ms, vram, ram, mesh_count, placement[0], placement[1], placement[2]])
	memory_rows.flush()


func _view(v: Array) -> void:
	super._view(v)
	game.grass.fill_now()


func _mesh_count() -> int:
	var ids := {}
	for node: MultiMeshInstance3D in game.find_children("*", "MultiMeshInstance3D", true, false):
		if node.get_viewport() == get_viewport() and node.multimesh != null and node.multimesh.mesh != null:
			ids[node.multimesh.mesh.get_instance_id()] = true
	return ids.size()


func _place_buildings() -> Array[float]:
	var total := PackedFloat32Array()
	var parts := PackedFloat32Array()
	game.build_anim = false
	Parts.profile_place = true
	for i in 12:
		var p := Vector2(54 + 15 * (i % 6), 108 + 20 * floori(i / 6.0))
		var pool: Parts = game.parts
		var before := pool.place_usec
		var start := Time.get_ticks_usec()
		var building: Dictionary = game.city.place("house_pleb", p, 0.0, 0, i % 4, true)
		total.append((Time.get_ticks_usec() - start) / 1000.0)
		parts.append((pool.place_usec - before) / 1000.0)
		if building.is_empty():
			fail("не удалось поставить дом для замера")
		await frames(2)
	Parts.profile_place = false
	return [_pct(total, 0.5), _pct(total, 1.0), _pct(parts, 0.5)]


func _fly(city: String, q: String, center: Array, far: Array, swap: bool) -> void:
	game.shadow_depth.enabled = swap
	game.shadow_depth.profile = true
	_view(center)
	await frames(25)
	var started := Time.get_ticks_usec()
	var last := started
	var progress := 0.0
	var max_update := 0
	var max_frame := 0.0
	var swaps := 0
	var draw_start := int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW))
	while progress < 1.0:
		var mix_k := 1.0 - absf(2.0 * progress - 1.0)
		var view := ["fly"]
		for i in range(1, 6):
			view.append(lerpf(float(center[i]), float(far[i]), mix_k))
		super._view(view)
		await frames(1)
		var now := Time.get_ticks_usec()
		var frame_ms := (now - last) / 1000.0
		var update: int = game.shadow_depth.update_usec
		var changed: int = game.shadow_depth.switches
		var draw := int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)) - draw_start
		fly_rows.store_line("%s\t%s\t%d\t%.5f\t%.3f\t%.3f\t%d\t%d" % [city, q, int(swap), progress, frame_ms, update / 1000.0, changed, draw])
		max_update = maxi(max_update, update)
		max_frame = maxf(max_frame, frame_ms)
		swaps += changed
		progress = (now - started) / 2000000.0
		last = now
	super._view(center)
	game.shadow_depth.profile = false
	fly_rows.flush()
	print("PERF14E5 FLY %s %s %d frame_max=%.3f update_max=%.3f swaps=%d" % [city, q, int(swap), max_frame, max_update / 1000.0, swaps])
	if max_update > 8000 or (swap and swaps == 0):
		fail("полёт %s %s: переключений %d, максимум %.3f мс" % [city, q, swaps, max_update / 1000.0])


func _pixel_checks(city: String, q: String, views: Array) -> void:
	var originals := _freeze_water()
	var anim_time := AnimClock.movie
	AnimClock.movie = 10.0                 # лодки и утки используют часы анимации, а не delta
	A["water"] = "1"
	_freeze()
	var qualities := SHADOW_QUALITIES if sharing and q == "high" else [q]
	for quality: String in qualities:
		_quality(quality)
		for view: Array in views:
			_view(view)
			game._set_hour(9.0)
			var label := "%s_%s_%s_s%d" % [city, quality, view[0], int(sharing)]
			var off := await _capture(label + "_off", false)
			if not sharing or quality == "verylow":
				continue
			var on := await _capture(label + "_on", true)
			var active: int = game.shadow_depth.swapped
			var repeat := await _capture(label + "_off_repeat", false)
			var equal_first := off == on
			var equal_repeat := repeat == on
			var stable := off == repeat
			pixel_rows.store_line("%s\t%s\t%s\t%d\t%d\t%d\t%d" % [city, quality, view[0], active, int(equal_first), int(equal_repeat), int(stable)])
			pixel_rows.flush()
			if not equal_first and not equal_repeat:
				fail("отличие A/B " + label)
	_unfreeze()
	AnimClock.movie = anim_time
	game.hud.set_speed(0.0)
	game.hud.visible = false
	game.rig.cine = true
	A.erase("water")
	for shader: Shader in originals:
		shader.code = originals[shader]


func _freeze_water() -> Dictionary:
	var originals := {}
	var shaders: Array[Shader] = [preload("res://shaders/pool_water.gdshader"), preload("res://shaders/stream_flow.gdshader")]
	for receiver: Game.ShadowDepth.Receiver in game.shadow_depth.receivers.values():
		if receiver.node.name in [&"CityWater", &"RiverFar"]:
			shaders.append(receiver.materials.shader)
			shaders.append(receiver.materials.distant.shader)
	for shader: Shader in shaders:
		if not originals.has(shader):
			originals[shader] = shader.code
			shader.code = shader.code.replace("TIME", "10.0")
	return originals


func _diagnose() -> void:
	while not game.ready_done:
		await frames(1)
	game.can_save = false
	game.hud.set_speed(0.0)
	game.weather.level = 0.0
	game.weather.wet = 0.0
	await _perf13_wait_icons()
	await get_tree().create_timer(1.0).timeout
	_freeze_water()
	AnimClock.movie = 10.0
	A["water"] = "1"
	_freeze()
	_quality("low")
	var depth: Game.ShadowDepth = game.shadow_depth
	var all := depth.receivers.duplicate()
	var chunks: Array = game.chunk_nodes.values()
	for view: Array in _views(VIEWS_REGRESS):
		_view(view)
		game._set_hour(9.0)
		var label := "isolate_%s_" % view[0]
		var off := await _capture(label + "off", false)
		for kind: String in ["ground", "horizon", "foliage", "water", "all"]:
			depth.receivers.clear()
			for node: GeometryInstance3D in all:
				var entry: Game.ShadowDepth.Receiver = all[node]
				var group := "water"
				if entry.original_override == game.land_mat:
					group = "ground" if node in chunks else "horizon"
				elif node is MultiMeshInstance3D:
					group = "foliage"
				if kind == group or kind == "all":
					depth.receivers[node] = entry
			var frame := await _capture(label + kind, true)
			print("PERF14E5 ISOLATE ", view[0], " ", kind, " equal=", off == frame, " swaps=", depth.swapped, " of ", depth.receivers.size())
			depth.enabled = false
			await frames(2)
		var land_pair: Game.ShadowDepth.Materials = depth.receivers[chunks[0]].materials
		var source := land_pair.distant.shader.code
		land_pair.distant.shader.code = land_pair.shader.code
		var clone := await _capture(label + "clone", true)
		print("PERF14E5 ISOLATE ", view[0], " clone equal=", off == clone)
		depth.enabled = false
		await frames(2)
		land_pair.distant.shader.code = source
		game.land_mat.render_priority = -1
		land_pair.distant.render_priority = -1
		var priority_off := await _capture(label + "priority_off", false)
		var priority_on := await _capture(label + "priority_on", true)
		print("PERF14E5 ISOLATE ", view[0], " priority equal=", priority_off == priority_on, " baseline_equal=", off == priority_off)
		depth.enabled = false
		await frames(2)
		game.land_mat.render_priority = 0
		land_pair.distant.render_priority = 0


func _capture(label: String, swap: bool) -> PackedByteArray:
	game.shadow_depth.enabled = swap
	await frames(24)
	var img := await _snap()
	var path := output.path_join(label + ".png")
	if img == null or img.is_empty() or img.save_png(path) != OK:
		fail("не удалось сохранить " + path)
		return PackedByteArray()
	print("PERF14E5 SHOT ", path)
	return img.get_data()
