extends Node

const CASES := ["perf", "camp_ui", "gfx", "tutor13", "legion12"]
const LIMIT_MS := 600000
const DEFAULT_DIR := "D:/CivCity/.work/stage7/perf14a3/after"

var _result := -1


static func finish(test: Node, code := 0) -> void:
	var callback: Callable = test.get_meta("perf14_done", Callable())
	if callback.is_valid():
		callback.call(code)
	else:
		test.get_tree().quit(code)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var dir := DEFAULT_DIR
	var cases := PackedStringArray(CASES)
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("dir="):
			dir = a.trim_prefix("dir=")
		elif a.begins_with("cases="):
			cases = a.trim_prefix("cases=").split(",", false)
	var failures := 0
	for name: String in cases:
		var shots := dir.path_join("shots").path_join(name) + "/"
		var profile := dir.path_join("profiles").path_join(name)
		if DirAccess.make_dir_recursive_absolute(profile) != OK or DirAccess.make_dir_recursive_absolute(shots) != OK:
			print("PERF14A3 FAIL ", name, ": папка недоступна")
			failures += 1
			continue
		OS.set_environment("CIVCITY_SAVEDIR", profile)
		OS.set_environment("CIVCITY_GFX_SHOTS", shots)
		OS.set_environment("CIVCITY_HEROSCREEN", "0")
		GamePaths._dir = ""
		Engine.time_scale = 1.0
		Engine.max_fps = 0
		var scene := load("res://test_%s.tscn" % name) as PackedScene
		var test := scene.instantiate()
		match name:
			"budget14":
				test.set_meta("perf14_args", {"out": dir, "report": "budget.md"})
			"perf":
				test.set("A", {"mode": "regress", "out": shots})
			"camp_ui", "legion12":
				test.set("out", shots)
			"tutor13", "perf20c_pick", "perf21b":
				test.set_meta("perf14_shots", shots)
				test.set_meta("perf14_profiles", profile)
		_result = -1
		test.set_meta("perf14_done", _complete)
		print("PERF14A3 START ", name)
		add_child(test)
		var until := Time.get_ticks_msec() + LIMIT_MS
		while _result < 0 and Time.get_ticks_msec() < until:
			await get_tree().process_frame
		print("PERF14A3 %s %s exit=%d" % ["PASS" if _result == 0 else "FAIL", name, _result])
		failures += int(_result != 0)
		test.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	print("PERF14A3 DONE fails=", failures)
	get_tree().quit(1 if failures else 0)


func _complete(code: int) -> void:
	_result = code
