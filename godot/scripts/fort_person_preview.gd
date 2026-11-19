class_name FortPersonPreview
extends Control
## Живой портрет использует тот же комплект, что и разрез.

const FortPerson = preload("res://scripts/fort_person.gd")
const Actor = preload("res://scripts/charpilot_actor.gd")
const PersonLayer = preload("res://scripts/fort_person_layer.gd")

var actor: Actor
var layer: PersonLayer
var _clock := 0.0


func setup(person: Dictionary, gear: Array, pixels: float) -> void:
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
	layer.place(actor, size * Vector2(0.5, 1.94), size.y * 1.83, 14.0)


func _process(delta: float) -> void:
	if is_instance_valid(actor) and actor.visible and is_visible_in_tree():
		_clock += delta
		actor.animate("Idle", _clock)
