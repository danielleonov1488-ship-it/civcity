extends Node
## Только test_perf mode=procprof: прямой замер одного вызова, без остановки дочерних анимаций.

var target: Node
var counter: Array
var invoke: Callable
var enabled := true


func setup(n: Node, totals: Array) -> void:
	target = n
	counter = totals
	invoke = Callable(n, "_process")
	process_priority = n.process_priority


func _process(dt: float) -> void:
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return
	# Внутри вызова is_processing() и set_process(false) имеют обычный смысл.
	target.set_process(true)
	var t0 := Time.get_ticks_usec()
	invoke.call(dt)
	var us := Time.get_ticks_usec() - t0
	if is_instance_valid(target):
		enabled = target.is_processing()
		target.set_process(false)
		if not enabled:
			set_process(false)
	counter[0] = int(counter[0]) + us
	counter[1] = int(counter[1]) + 1
