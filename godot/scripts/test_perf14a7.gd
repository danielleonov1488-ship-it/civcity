extends "res://scripts/test_hitch14.gd"

var _peaks := {}
var _ui_peak := 0.0
var _ui_over := 0


func _ready() -> void:
	var defaults := {"city": "owner", "q": "high", "focus": "1", "seconds": "15", "ui_trace": "1"}
	var has_output := false
	for arg: String in OS.get_cmdline_user_args():
		has_output = has_output or arg.trim_prefix("--").begins_with("out=")
	if not has_output:
		defaults["out"] = "D:/CivCity/.work/stage7/perf14a7"
	set_meta("perf14_args", defaults)
	super._ready()


func _begin() -> void:
	_peaks.clear()
	_ui_peak = 0.0
	_ui_over = 0
	super._begin()


func _frame() -> void:
	if active:
		var ms := (Time.get_ticks_usec() - before) / 1000.0
		var ui := Timers.usec[Timers.UI] / 1000.0
		var peak: Array = _peaks.get(phase, [0.0, 0.0])
		peak[0] = maxf(peak[0], ms)
		peak[1] = maxf(peak[1], ui)
		_peaks[phase] = peak
		_ui_peak = maxf(_ui_peak, ui)
		_ui_over += int(ui > 8.0)
	super._frame()


func _finish(startup := false) -> void:
	await super._finish(startup)
	_line("")
	_line("HUD: максимум %.2f мс, кадров >8 мс: %d." % [_ui_peak, _ui_over])
	_line("")
	_line("| Действие | Макс. кадр, мс | Макс. HUD, мс |")
	_line("|---|---:|---:|")
	for action: String in _peaks:
		var peak: Array = _peaks[action]
		_line("| %s | %.2f | %.2f |" % [action, peak[0], peak[1]])
