extends Control
## Кольцо сбора или таймера; ввод получает кнопка под ним.

var value := 0.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()
var tint := Color("b78835")
var thickness := 4.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.5 - thickness * 0.5 - 1.0
	if radius <= 0.0:
		return
	draw_arc(size * 0.5, radius, -PI * 0.5, PI * 1.5, 64, Color("d5c5a5"), thickness, true)
	if value > 0.0:
		draw_arc(size * 0.5, radius, -PI * 0.5, -PI * 0.5 + TAU * value, 64, tint, thickness, true)
