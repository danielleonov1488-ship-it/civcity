extends RefCounted

const SEGMENTS := ["Центр вблизи", "Общий вид", "Дальний вид", "Вдоль улицы"]
const SEGMENT_SEC := 10.0

# Средний FPS и 1% low должны пройти оба порога. Для 1% low берём среднее время худшего 1% кадров.
const SMOOTH_AVG := 55.0
const SMOOTH_LOW := 45.0
const PLAYABLE_AVG := 40.0
const PLAYABLE_LOW := 28.0


class Samples:
	var frames := PackedFloat64Array()
	var cpu_sum := 0.0
	var gpu_sum := 0.0
	var render_count := 0
	var gpu_count := 0

	func add(frame_ms: float, cpu_ms: float, gpu_ms: float) -> void:
		frames.append(frame_ms)
		if cpu_ms > 0.0:
			cpu_sum += cpu_ms
			render_count += 1
		if gpu_ms > 0.0:
			gpu_sum += gpu_ms
			gpu_count += 1

	func merge(other: Samples) -> void:
		frames.append_array(other.frames)
		cpu_sum += other.cpu_sum
		gpu_sum += other.gpu_sum
		render_count += other.render_count
		gpu_count += other.gpu_count

	func stats() -> Dictionary:
		if frames.is_empty():
			return {}
		var sum_ms := 0.0
		var over33 := 0
		var over50 := 0
		for ms: float in frames:
			sum_ms += ms
			over33 += int(ms > 33.0)
			over50 += int(ms > 50.0)
		var sorted := frames.duplicate()
		sorted.sort()
		var tail := maxi(1, ceili(sorted.size() * 0.01))
		var tail_ms := 0.0
		for i in tail:
			tail_ms += sorted[sorted.size() - 1 - i]
		return {"count": frames.size(), "fps": 1000.0 * frames.size() / sum_ms,
			"low": 1000.0 * tail / tail_ms, "worst": sorted[-1], "over33": over33, "over50": over50,
			"cpu": cpu_sum / render_count if render_count > 0 else -1.0,
			"gpu": gpu_sum / gpu_count if gpu_count > 0 else -1.0}


static func verdict(stats: Dictionary, quality: String) -> Dictionary:
	var fps := float(stats.get("fps", 0.0))
	var low := float(stats.get("low", 0.0))
	if stats.is_empty():
		return {"text": "Мало кадров для оценки", "quality": quality}
	if fps >= SMOOTH_AVG and low >= SMOOTH_LOW:
		return {"text": I18n.t("Игра идёт плавно (%d кадров/с)") % roundi(fps), "quality": quality}
	if fps >= PLAYABLE_AVG and low >= PLAYABLE_LOW:
		return {"text": "Иногда подтормаживает", "quality": Gfx.lower(quality)}
	return {"text": "Игре тяжело", "quality": "low" if quality in ["high", "medium"] else Gfx.lower(quality)}


## Отчёт на одном языке, чтобы проще сравнивать присланные замеры.
static func format_report(info: Dictionary, segments: Array[Samples], total: Dictionary) -> String:
	var lines := PackedStringArray([
		"CivCity Speed Test | %s | %s" % [info["version"], info["os"]],
		"GPU: %s | %s | %s" % [info["gpu"], info["adapter"], info["driver"]],
		"CPU: %s | %d logical cores | RAM: %s" % [info["cpu"], info["cores"], info["ram"]],
		"Screen: %s | Window: %s | 3D scale: %.2f | FPS cap: %s | VSync: %s" % [
			info["screen"], info["window"], info["scale"], info["cap"], info["vsync"]],
		"Quality: %s | Smoothness: %s | City: %d buildings, %d citizens | Simulation: paused" % [
			info["quality"], info["smooth"], info["buildings"], info["citizens"]],
		"View | Frames | Avg FPS | 1% low FPS | Worst ms | GPU ms | CPU ms | >33 ms | >50 ms",
		_format_row("Total", total),
	])
	var names := ["Close-up", "Wide", "Far", "Street"]
	for i in segments.size():
		lines.append(_format_row(names[i], segments[i].stats()))
	return "\n".join(lines)


static func _format_row(title: String, stats: Dictionary) -> String:
	if stats.is_empty():
		return title + " | 0 | — | — | — | — | — | 0 | 0"
	return "%s | %d | %.1f | %.1f | %.1f | %s | %s | %d | %d" % [title, stats["count"], stats["fps"], stats["low"],
		stats["worst"], _format_ms(stats["gpu"]), _format_ms(stats["cpu"]), stats["over33"], stats["over50"]]


static func _format_ms(ms: float) -> String:
	return "%.2f" % ms if ms >= 0.0 else "—"
