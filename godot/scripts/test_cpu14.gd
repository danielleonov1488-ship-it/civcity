extends Node

const OWNER := "D:/CivCity/.work/owner_save/city.json"
const OUT := "D:/CivCity/.work/stage7/perf14d"
const WARM := 90
const SAMPLES := 180

var game: Game
var args := {}
var report: FileAccess
var run_dir := ""
var vp: RID
var frame_start := 0
var late_process := 0
var last_frame := 0
var sample_limit := 0
var collect_render := false
var frame_ms := PackedFloat64Array()
var script_ms := PackedFloat64Array()
var tail_ms := PackedFloat64Array()
var render_ms := PackedFloat64Array()
var gpu_ms := PackedFloat64Array()


func _ready() -> void:
	process_priority = 1000000
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	_run.call_deferred()


func _run() -> void:
	var tag: String = args.get("tag", "cpu14_%d" % OS.get_process_id())
	run_dir = OUT.path_join("profiles").path_join(tag)
	if DirAccess.make_dir_recursive_absolute(run_dir) != OK:
		_fail("папка профилей недоступна")
		return
	report = FileAccess.open(OUT.path_join(tag + ".tsv"), FileAccess.WRITE)
	if report == null:
		_fail("отчёт недоступен")
		return
	print("CPU14 ", tag, " | ", OS.get_cmdline_args(), " | ", RenderingServer.get_video_adapter_name())
	report.store_line("city\tquality\tscale\tframe_ms\tfps\tp95_ms\tscripts_ms\tend_of_frame_ms\tprep_ms\tgpu_ms\tresidents\tactors\tin_frustum")
	get_tree().process_frame.connect(_begin_frame)
	RenderingServer.frame_pre_draw.connect(_before_draw)
	vp = get_viewport().get_viewport_rid()
	for kind: String in ["owner", "new"]:
		if not await _boot(kind):
			_fail("город не загружен: " + kind)
			return
		for quality: String in ["high", "low"]:
			game.settings["quality"] = quality
			game._apply_quality()
			Gfx.swap_all()
			Engine.max_fps = 0
			var full_scale := get_viewport().scaling_3d_scale
			for scale: float in [full_scale, 0.25]:
				get_viewport().scaling_3d_scale = scale
				RenderingServer.viewport_set_measure_render_time(vp, true)
				await _frames(WARM)
				await _sample(SAMPLES, true)
				var ms := _pct(frame_ms, 0.5)
				if ms <= 0.0 or render_ms.is_empty():
					_fail("нет отсчётов рендера")
					return
				var on_screen: int = int(Gfx.tier_n[0]) + int(Gfx.tier_n[1]) + int(Gfx.tier_n[2])
				var row := "%s\t%s\t%.2f\t%.3f\t%.1f\t%.3f\t%.3f\t%.3f\t%.3f\t%.3f\t%d\t%d\t%d" % [
					kind, quality, scale, ms, 1000.0 / ms, _pct(frame_ms, 0.95), _pct(script_ms, 0.5),
					_pct(tail_ms, 0.5), _pct(render_ms, 0.5), _pct(gpu_ms, 0.5), game.people.residents.size(),
					game.people._shown.size(), on_screen]
				report.store_line(row)
				report.flush()
				print("CPU14 ROW ", row)
			if kind == "owner" and quality == "high":
				await _profile()
		get_viewport().scaling_3d_scale = 1.0
	report.close()
	print("CPU14 DONE")
	get_tree().quit()


func _boot(kind: String) -> bool:
	if is_instance_valid(game):
		game.queue_free()
		await game.tree_exited
		await _frames(2)
	var dir := run_dir.path_join(kind)
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return false
	GamePaths._dir = dir
	if kind == "owner" and DirAccess.copy_absolute(OWNER, dir.path_join("city.json")) != OK:
		return false
	var settings := FileAccess.open(dir.path_join("settings.json"), FileAccess.WRITE)
	if settings == null:
		return false
	settings.store_string(JSON.stringify({"quality": "high", "quality_user": true, "fullscreen": false, "fps_cap": 0}))
	settings.close()
	seed(1420)
	Game.boot = {"play" if kind == "owner" else "new": "1", "nologin": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	add_child(game)
	while not game.ready_done:
		await _frames(1)
	game.can_save = false
	get_window().size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var point := Vector2(210, 145) if kind == "owner" else Vector2(192, 124)
	game.rig.set_view(Vector3(point.x, game.land.height_at(point.x, point.y), point.y), 15, 42, 60)
	game.weather.force = 0.0
	game._set_hour(9.0)
	game.hud.set_speed(1.0)
	var expected := 0
	for type: String in Defs.B:
		if not bool(Defs.B[type].get("hidden", false)):
			expected += 1
	var deadline := Time.get_ticks_msec() + 90000
	while game.hud.icons.size() < expected and Time.get_ticks_msec() < deadline:
		await _frames(10)
	print("CPU14 icons ", game.hud.icons.size(), "/", expected)
	await _frames(120)
	return game.hud.icons.size() == expected


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _begin_frame() -> void:
	frame_start = Time.get_ticks_usec()


func _process(_dt: float) -> void:
	late_process = Time.get_ticks_usec()


func _before_draw() -> void:
	var now := Time.get_ticks_usec()
	if frame_ms.size() < sample_limit and last_frame > 0 and late_process >= frame_start:
		frame_ms.append((now - last_frame) / 1000.0)
		script_ms.append((late_process - frame_start) / 1000.0)
		tail_ms.append((now - late_process) / 1000.0)
		# Барьер движка уже пройден: чтение статистики не заставляет ждать предыдущий кадр.
		if collect_render:
			render_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
			gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
	last_frame = now


func _sample(count: int, with_render: bool) -> void:
	frame_ms.clear()
	script_ms.clear()
	tail_ms.clear()
	render_ms.clear()
	gpu_ms.clear()
	collect_render = with_render
	sample_limit = count
	while frame_ms.size() < count:
		await get_tree().process_frame
	sample_limit = 0


func _profile() -> void:
	People.perf = true
	Gfx.perf = true
	game.people.perf_us = 0
	game.people.perf_sec.clear()
	game.gfx.anim_us = 0
	await _sample(SAMPLES, false)
	People.perf = false
	Gfx.perf = false
	var stats := {}
	for key: String in game.people.perf_sec:
		stats[key] = float(game.people.perf_sec[key]) / SAMPLES / 1000.0
	print("CPU14 PEOPLE ", JSON.stringify(stats), " total=", game.people.perf_us / float(SAMPLES) / 1000.0,
		" gfx_anims=", game.gfx.anim_us / float(SAMPLES) / 1000.0, " tiers=", Gfx.tier_n)
	var callbacks := {}
	for node: Node in get_tree().root.find_children("*", "", true, false):
		var script: Script = node.get_script()
		if script != null and (node.is_processing() or node.is_physics_processing()):
			var name := script.resource_path.get_file().get_basename()
			if node != self:
				if not callbacks.has(name):
					callbacks[name] = []
				callbacks[name].append(node)
	print("CPU14 ACTIVE ", callbacks.keys())
	if args.get("profile", "0") != "1":
		return
	for name: String in callbacks:
		var states := {}
		await _sample(40, false)
		var before := _pct(script_ms, 0.5)
		for node: Node in callbacks[name]:
			if is_instance_valid(node):
				states[node] = Vector2i(int(node.is_processing()), int(node.is_physics_processing()))
				node.set_process(false)
				node.set_physics_process(false)
		await _sample(40, false)
		var off := _pct(script_ms, 0.5)
		for node in states:
			if is_instance_valid(node):
				var state: Vector2i = states[node]
				node.set_process(bool(state.x))
				node.set_physics_process(bool(state.y))
		await _sample(40, false)
		var on := (_pct(script_ms, 0.5) + before) * 0.5
		print("CPU14 SCRIPT %s\t%d\t%.3f\t%.3f\t%+.3f" % [name, states.size(), on, off, on - off])


static func _pct(samples: PackedFloat64Array, p: float) -> float:
	if samples.is_empty():
		return 0.0
	var sorted := samples.duplicate()
	sorted.sort()
	return sorted[roundi((sorted.size() - 1) * p)]


func _fail(reason: String) -> void:
	print("CPU14 FAIL ", reason)
	get_tree().quit(1)
