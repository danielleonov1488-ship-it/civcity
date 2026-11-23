extends RefCounted
## Короткие окна отбрасывают одиночные рывки, подъём требует устойчивого запаса.

const WINDOW := 0.5
const CHANGE_INTERVAL := 3.0
const HIGH_STEPS := [0.77, 0.88, 1.0]
const STEPS := {
	"verylow": [0.45, 0.5, 0.6, 0.67, 0.77, 0.88, 1.0],
	"low": [0.6, 0.67, 0.75, 0.88, 1.0],
	"medium": HIGH_STEPS,
	"high": HIGH_STEPS,
}

var scale := 1.0
var _elapsed := 0.0
var _since_change := 0.0
var _frames := PackedFloat32Array()
var _gpu := PackedFloat32Array()
var _over := 0
var _under := 0
var _recovery := false


func reset(start: float) -> void:
	scale = start
	_since_change = 0.0
	clear()


func clear() -> void:
	_elapsed = 0.0
	_frames.clear()
	_gpu.clear()
	_over = 0
	_under = 0
	_recovery = false


func sample(seconds: float, gpu_ms: float, target_ms: float, quality: String) -> bool:
	_elapsed += seconds
	_since_change += seconds
	_frames.append(seconds * 1000.0)
	if gpu_ms > 0.0:
		_gpu.append(gpu_ms)
	if _elapsed < WINDOW:
		return false
	var frame := percentile(_frames, 0.75)
	var gpu := percentile(_gpu, 0.75)
	_elapsed = 0.0
	_frames.clear()
	_gpu.clear()

	var low := quality in ["low", "verylow"]
	var budget := target_ms if low else maxf(target_ms, 1000.0 / 60.0)
	var steps: Array = STEPS[quality]
	var step := steps.find(scale)
	var next: float = steps[mini(step + 1, steps.size() - 1)]
	var over := frame > budget * 1.035 and (gpu <= 0.0 or gpu > budget * 0.92)
	# При синхронизации кадр может быть ровно по лимиту. Тогда запас виден по GPU.
	var projected := gpu * pow(next / scale, 2.0)
	var under := projected < budget * (0.80 if low else 0.93) if gpu > 0.0 else frame < budget * 0.88
	if not low and gpu > 0.0 and frame > budget * 1.035:
		under = gpu * pow(1.0 / scale, 2.0) < budget * 0.80  # Упёрлись в CPU, вернём чёткость.
	_over = _over + 1 if over else 0
	_under = _under + 1 if under else 0
	if _since_change < CHANGE_INTERVAL:
		return false
	if _over >= 2 and step > 0:
		scale = steps[step - 1]
		_since_change = 0.0
		_over = 0
		_under = 0
		_recovery = true
		return true
	if _under >= (6 if _recovery else (4 if low else 2)) and scale < 1.0:
		scale = next
		_since_change = 0.0
		_over = 0
		_under = 0
		_recovery = false
		return true
	return false


static func percentile(values: PackedFloat32Array, fraction: float) -> float:
	if values.is_empty():
		return 0.0
	values.sort()
	return values[floori((values.size() - 1) * fraction)]
