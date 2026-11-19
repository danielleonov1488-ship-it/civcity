class_name FortPersonPreview
extends Control
## Живой портрет использует тот же комплект, что и разрез.

const FortPerson = preload("res://scripts/fort_person.gd")
const Actor = preload("res://scripts/charpilot_actor.gd")
const PersonLayer = preload("res://scripts/fort_person_layer.gd")

var actor: Actor
var layer: PersonLayer
var _clock := 0.0
var _full_body := false
var _headroom := 0.0


func setup(person: Dictionary, gear: Array, pixels: float, full_body := false, headroom := 0.0) -> void:
	_full_body = full_body
	_headroom = headroom
	custom_minimum_size = Vector2(pixels, pixels)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer = PersonLayer.new()
	add_child(layer)
	layer.setup("FortPortraitWorld", 3.0)
	actor = FortPerson.make(person, layer.viewport, gear)
	resized.connect(_fit)
	_fit()


func _fit() -> void:
	layer.fit(size)
	if _full_body:
		var feet := size * Vector2(0.5, 0.94)
		var height := minf(size.y * 0.81, size.x * 1.48)
		layer.place(actor, feet, height, 12.0)
		layer.shadows = PackedVector3Array([Vector3(feet.x, feet.y, height)])
		layer.queue_redraw()
	else:
		layer.place(actor, size * Vector2(0.5, 1.94 + _headroom), size.y * 1.83, 14.0)


func _process(delta: float) -> void:
	if is_instance_valid(actor) and actor.visible and is_visible_in_tree():
		_clock += delta * (0.65 if _full_body else 1.0)
		actor.animate("Idle", _clock)
