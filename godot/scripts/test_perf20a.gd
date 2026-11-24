extends "res://scripts/test_perf.gd"

const ProbeDetail = preload("res://scripts/test_perf20a_detail.gd")
const STAGE := "D:/CivCity/.work/stage7/perf20a"
const CASES := ["base", "24", "48", "64", "shadow", "base_repeat"]
const VIEWS := "center:210:145:15:42:60,far:192:160:15:55:240"
const SHADOW_BEGIN := "Render Directional/SpotLight Shadows"

var _sector_keys := {}
var _shadow_keys := {}
var _rows: FileAccess
var _out := ""
var _rd: RenderingDevice
var _shadow_samples := PackedFloat32Array()


func _run(_mode: String) -> void:
	if city_src != OWNER or RenderingServer.get_current_rendering_method() != "forward_plus":
		fail("нужны город владельца и Forward+")
		_finish()
		return
	_out = str(A.get("out", STAGE.path_join("shots/raw")))
	if DirAccess.make_dir_recursive_absolute(_out) != OK:
		fail("папка замеров недоступна")
		_finish()
		return
	_rows = FileAccess.open(_out.path_join("samples.tsv"), FileAccess.WRITE)
	if _rows == null:
		fail("не открыт файл замеров")
		_finish()
		return
	_rows.store_line("case\tquality\tview\tgpu_median_ms\tgpu_p99_ms\tcpu_process_ms\tcpu_render_ms\tframe_median_ms\tframe_p99_ms\tvisible_draws\tshadow_draws\tvisible_primitives\tshadow_primitives\tshadow_pass_ms")
	_rd = RenderingServer.get_rendering_device()
	await _ready_game()
	if game.city.buildings.size() != 357 or get_window().size != Vector2i(1920, 1080):
		fail("ожидались 357 зданий и окно 1920×1080: %d, %s" % [game.city.buildings.size(), str(get_window().size)])
		_finish()
		return
	print("PERF20A READY ", RenderingServer.get_video_adapter_name(), " ", get_window().size)
	_select_groups()
	for label: String in str(A.get("sets", ",".join(CASES))).split(",", false):
		if label != "base":
			var old: Node = game
			old.queue_free()
			await old.tree_exited
			await frames(12)
			var detail := ProbeDetail.new()
			detail.tile_m = float(label.get_slice("+", 0))
			detail.area_keys = _sector_keys
			if label.ends_with("shadow"):
				detail.exact_shadow_keys = _shadow_keys
			Parts.detail_config = detail
			_boot("play")
			await _ready_game()
			print("PERF20A CASE %s tiles=%d shadow_meshes=%d" % [label, detail.tiles, detail.exact_shadows])
			if detail.tile_m > 0.0 and detail.tiles == 0:
				fail("секторы не созданы: " + label)
		await _bench(label)
		await _capture(label)
	_finish()


func _ready_game() -> void:
	while not game.ready_done:
		await frames(5)
	game.can_save = false
	game.settings["autosave"] = false
	game.settings["quality_user"] = true
	game.hud.set_speed(0.0)
	game.rig.cine = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _perf13_wait_icons()
	vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)


func _select_groups() -> void:
	var choices := []
	var shadows := {}
	for key: String in game.parts.groups:
		var name := key.get_slice("|", 0)
		if not (name.begins_with("SM_Bld_") or name.begins_with("SM_Prop_")):
			continue
		if name.contains("Door") or name.contains("Shutter"):
			continue
		var group: Dictionary = game.parts.groups[key]
		var count: int = int(group["used"]) - group["free"].size()
		if count < 24:
			continue
		var faces := 0
		var surfaces := 0
		for sub: Dictionary in group["subs"]:
			var mesh := (sub["mm"] as MultiMesh).mesh as ArrayMesh
			if mesh == null:
				continue
			var cast: bool = (sub["mmi"] as MultiMeshInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			for surface: Dictionary in mesh.get("_surfaces"):
				var tris := float(surface.get("index_count", surface["vertex_count"])) / 3.0
				faces += int(tris)
				surfaces += 1
				if cast:
					shadows[name] = float(shadows.get(name, 0.0)) + count * tris
		if faces * count < 15000 or not ProbeDetail._opaque_area(group):
			continue
		var mm: MultiMesh = group["subs"][0]["mm"]
		var footprint := Rect2()
		var seen := false
		for slot in int(group["used"]):
			var pose := mm.get_instance_transform(slot)
			if pose.basis == Basis.IDENTITY.scaled(Vector3.ZERO):
				continue
			var point := Vector2(pose.origin.x, pose.origin.z)
			footprint = footprint.expand(point) if seen else Rect2(point, Vector2.ZERO)
			seen = true
		if maxf(footprint.size.x, footprint.size.y) > 72.0:
			choices.append([key, faces * count / float(surfaces), count])
	choices.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))
	for row: Array in choices.slice(0, 16):
		_sector_keys[row[0]] = true
		print("PERF20A SECTOR ", row[2], " ", row[0])
	var names := shadows.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return float(shadows[a]) > float(shadows[b]))
	for name: String in names.slice(0, 24):
		_shadow_keys[name] = true
	print("PERF20A CASTERS ", _shadow_keys.keys())


func _view(v: Array) -> void:
	super._view(v)
	if game.grass != null:
		game.grass.fill_now()


func _bench(label: String) -> void:
	for q: String in ["high", "verylow"]:
		_quality(q)
		for v: Array in _views(VIEWS):
			_view(v)
			game._set_hour(9.0)
			await frames(int(A.get("warm", "90")))
			var row := await _sample()
			var shadow := "—"
			if q == "high" and _rd != null and EngineDebugger.has_profiler("visual"):
				shadow = await _measure_shadow()
			var line := PackedStringArray([label, q, String(v[0])])
			for value: Variant in row:
				line.append(str(value))
			line.append(shadow)
			var record := "\t".join(line)
			_rows.store_line(record)
			_rows.flush()
			print("PERF20A SAMPLE ", record)


func _sample() -> Array:
	var gpu := PackedFloat32Array()
	var cpu := PackedFloat32Array()
	var frame := PackedFloat32Array()
	if not get_tree().process_frame.is_connected(_on_frame):
		get_tree().process_frame.connect(_on_frame)
		RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	_proc_ms.clear()
	_rec = true
	var last := Time.get_ticks_usec()
	for i in maxi(100, int(A.get("n", "180"))):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		frame.append((now - last) / 1000.0)
		last = now
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
	_rec = false
	if _pct(gpu, 0.5) <= 0.0:
		fail("недоступны замеры GPU")
	var rs := RenderingServer
	return ["%.4f" % _pct(gpu, 0.5), "%.4f" % _pct(gpu, 0.99), "%.4f" % _pct(_proc_ms, 0.5),
		"%.4f" % _pct(cpu, 0.5), "%.4f" % _pct(frame, 0.5), "%.4f" % _pct(frame, 0.99),
		rs.viewport_get_render_info(vp, rs.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, rs.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		rs.viewport_get_render_info(vp, rs.VIEWPORT_RENDER_INFO_TYPE_SHADOW, rs.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		rs.viewport_get_render_info(vp, rs.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, rs.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
		rs.viewport_get_render_info(vp, rs.VIEWPORT_RENDER_INFO_TYPE_SHADOW, rs.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)]


func _measure_shadow() -> String:
	EngineDebugger.profiler_enable("visual", true)
	await frames(12)
	_shadow_samples.clear()
	for i in 48:
		RenderingServer.call_on_render_thread(_read_shadow_timing)
		await frames(1)
	EngineDebugger.profiler_enable("visual", false)
	return "—" if _shadow_samples.is_empty() else "%.4f" % _pct(_shadow_samples, 0.5)


func _read_shadow_timing() -> void:
	for i in _rd.get_captured_timestamps_count() - 1:
		if _rd.get_captured_timestamp_name(i) == SHADOW_BEGIN:
			var start := _rd.get_captured_timestamp_gpu_time(i)
			var end := _rd.get_captured_timestamp_gpu_time(i + 1)
			if end > start:
				_shadow_samples.append((end - start) / 1000000.0)
			return


func _capture(label: String) -> void:
	_freeze()
	var views := _views(VIEWS)
	for q: String in ["low", "verylow"]:
		_quality(q)
		for v: Array in views:
			_view(v)
			game._set_hour(9.0)
			await frames(90)
			await _shot("%s_%s_%s" % [label, q, v[0]])
	_quality("high")
	_view(views[0])
	game._set_hour(12.0)
	await frames(120)
	await _shot(label + "_high_noon")
	game._set_hour(20.5)
	await frames(120)
	await _shot(label + "_high_sunset")
	_unfreeze()


func _shot(name: String) -> void:
	var path := _out.path_join(name + ".png")
	var image := await _snap()
	if image.save_png(path) == OK:
		print("PERF20A SHOT ", path)
	else:
		fail("не записан кадр " + path)


func fail(what: String) -> void:
	fails += 1
	print("PERF20A FAIL ", what)


func _finish() -> void:
	Parts.detail_config = null
	print("PERF20A DONE fails=", fails)
	TestSuite.finish(self, int(fails > 0))
