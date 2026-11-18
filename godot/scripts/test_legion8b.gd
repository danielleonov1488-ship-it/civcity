extends "res://scripts/test_legion8.gd"
## Кадры LEGION8 и отдельная проверка карточки на двух разрешениях.

const BattleView = preload("res://scripts/legion_battle_view.gd")


func _ready() -> void:
	out = "D:/CivCity/.work/stage7/legion8b/shots/"
	super._ready()


func _report_tag() -> String:
	return "LEGION8B"


func _test_room() -> void:
	await super._test_room()
	camp.show_building("barracks")
	await frames(8)
	_check_room_card("1080p")
	# Меняем размер с уже открытой карточкой.
	get_window().size = Vector2i(1280, 720)
	await frames(10)
	_check_room_card("720p")
	for resource: String in camp.resource_bars:
		var panel: Control = camp.resource_bars[resource]["panel"]
		var icon := panel.find_child("ResourceIcon", true, false) as TextureRect
		check(icon != null and icon.get_global_rect().size.x >= 49.0, "720p painted icon " + resource)
	await shot("02_room_card_720.png")
	camp._hide_card()
	get_window().size = Vector2i(1920, 1080)
	await frames(10)


func _check_room_card(resolution: String) -> void:
	var viewport := get_viewport().get_visible_rect()
	check(int(viewport.size.y) == (720 if resolution == "720p" else 1080), resolution + " test viewport")
	var rect := camp.card.get_global_rect()
	check(viewport.encloses(rect), resolution + " room card inside viewport")
	check(camp.card.find_children("*", "ScrollContainer", true, false).is_empty(), resolution + " no inner scroll")
	for button: Button in [camp.instant_button, camp.upgrade_button]:
		check(button.is_visible_in_tree() and rect.encloses(button.get_global_rect()), resolution + " visible price and action " + button.name)
	var values := camp.card.find_children("FortRoomMetricValues", "Label", true, false)
	var gains := camp.card.find_children("FortRoomMetricGain", "Label", true, false)
	if check(values.size() == 2 and gains.size() == 2, resolution + " two barracks metrics"):
		check((values[0] as Label).text == "3 → 4" and (values[1] as Label).text == "6 → 7",
			resolution + " integer comparisons")
		check((gains[0] as Label).text == "+1" and (gains[1] as Label).text == "+1", resolution + " integer gains")


func _test_campaign() -> void:
	var stage := lg.stage_info(0, 0, 2)
	var count := 0
	for wave: Array in stage["waves"]:
		count += wave.count("forestBear")
	check(stage["theme"] == "Медвежья тропа" and count == 6, "Italian trail has six forest bears")
	var portraits := {"forestBear": 4, "hadesBear": 4, "hadesGuardian": 1, "venomBear": 4}
	var unit := LegionSim.Unit.new()
	unit.side = "enemy"
	for id: String in portraits:
		var art := Legion.art("enemy", id)
		unit.key = id
		unit.tags.assign(Legion.ENEMIES[id]["tags"])
		check(int(art["i"]) == int(portraits[id]) and Legion.art_texture("enemy", id) != null
			and BattleView.sheet_id(unit) == "bear", "bear portrait and B1 sprite for " + id)
	await super._test_campaign()
