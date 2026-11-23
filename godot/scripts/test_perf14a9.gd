extends Node

var _result := -1
var _previous_frame := 0
var _loading_frames := 0
var _slow_frames: Array[String] = []
var _test: Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var path := OS.get_environment("CIVCITY_PERF14A9_PLAN")
	var plan: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not plan is Array or plan.is_empty():
		print("PERF14A9 FAIL нет плана проверки")
		get_tree().quit(1)
		return
	var failures := 0
	for stage: Dictionary in plan:
		var label: String = stage["label"]
		OS.set_environment("CIVCITY_SAVEDIR", stage["saves"])
		GamePaths._dir = ""
		Gfx._tdir = ""
		Engine.max_fps = 0
		Engine.time_scale = 1.0
		_result = -1
		_test = _create_test(stage["script"])
		if _test == null:
			print("PERF14A9 FAIL не создана проверка ", label)
			failures += 1
			continue
		var options: Dictionary = stage["args"]
		if stage["script"] == "hitch14":
			_test.set_meta("perf14_args", options)
		else:
			_test.set("A", options)
		_test.set_meta("perf14_done", _complete)
		_previous_frame = Time.get_ticks_usec()
		_loading_frames = 0
		_slow_frames.clear()
		var deadline := Time.get_ticks_msec() + 600_000
		print("PERF14A9 START ", label, " depth=", Gfx.depth_prepass(), " user=", OS.get_user_data_dir())
		get_tree().process_frame.connect(_record_loading_frame)
		add_child(_test)
		while _result < 0 and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		if get_tree().process_frame.is_connected(_record_loading_frame):
			get_tree().process_frame.disconnect(_record_loading_frame)
		print("PERF14A9 %s %s exit=%d" % ["PASS" if _result == 0 else "FAIL", label, _result])
		failures += int(_result != 0)
		_test.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	print("PERF14A9 DONE fails=", failures)
	get_tree().quit(int(failures != 0))


func _create_test(id: String) -> Node:
	var path := "res://scripts/test_%s.gd" % id
	if id == "perf":
		return (load(path) as Script).new()
	# Только выход из стенда перенаправляется в пакетный запуск.
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string(path).replace(
		"get_tree().quit(", 'get_meta("perf14_done").call(')
	if script.reload() != OK:
		return null
	return script.new() as Node


func _record_loading_frame() -> void:
	var now := Time.get_ticks_usec()
	var ms := (now - _previous_frame) / 1000.0
	_previous_frame = now
	_loading_frames += 1
	var game: Game = _test.get("game")
	if ms > 250.0:
		_slow_frames.append("%d %.2f %s" % [_loading_frames, ms, game.loading_step if game != null else ""])
	if game != null and game.ready_done:
		get_tree().process_frame.disconnect(_record_loading_frame)
		print("PERF14A9 READY process_ms=", Time.get_ticks_msec(), " frames=", _loading_frames,
			" over_250=", _slow_frames.size(), " slow=", _slow_frames)


func _complete(code: int) -> void:
	_result = code
