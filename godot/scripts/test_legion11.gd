extends "res://scripts/test_legion7c.gd"
## Маршрут первого похода общий с 7c. Дальше — уроки и окно Штаба.

const Fixture = preload("res://scripts/test_fort_fixture.gd")

var pending_saves := {}


func _ready() -> void:
	suite = "LEGION11"
	out = "D:/CivCity/.work/stage7/legion11/shots/"
	await _resize(Vector2i(1920, 1080))
	await super._ready()


func intro_capture(file: String) -> void:
	if file == "01_gate":
		_check_dialog("1080 first chapter")
		await capture("1_dialog")


func _before_finish() -> void:
	game.city.level = 0
	lg.rations = 800.0
	lg.ingots = 0
	lg.fort["money"] = 500.0
	lg.mats = {"iron": 0.0, "wood": 0.0, "leather": 0.0}
	lg.flags["fort_guide"] = Step.FINISH
	lg.finish_fort_guide()
	lg.flags["fort_lessons"].erase("outfit")
	# Новый урок проходит в LEGION13, здесь сохраняем маршрут четырёх уроков.
	lg.flags["fort_lessons"]["market"] = "skipped"


func _after_intro(_during: Dictionary, _before_load: float, _reserved: float) -> void:
	await _restore(save_round_trip())
	check(lg.flags.has("fort_lessons") and lg.fort_lesson() == "", "chapter two stays available before its first lesson")
	if not await _storage_lesson():
		return
	if not await _hq_lesson():
		return
	if not await _knowledge_lesson():
		return
	if not await _outfit_lesson():
		return
	var finished := save_round_trip()
	await _restore(finished)
	var lessons := ["store", "knowledge", "outfit", "hq"]
	for id: String in lessons:
		check(lg.fort_lesson_state(id) == "done", "saved completion " + id)
	check(lg.fort_lesson() == "" and not camp.guide_layer.visible, "no hints after completed lessons")
	for id: String in lessons:
		await _restore(pending_saves[id])
		if not check(lg.fort_lesson() == id, "saved active lesson " + id):
			continue
		check(camp.guide_skip.text == I18n.t("Пропустить урок"), "skip caption applies only to the active lesson " + id)
		if not press(camp.guide_skip, "skip " + id):
			continue
		var skipped := save_round_trip()
		await _restore(skipped)
		check(lg.fort_lesson_state(id) == "skipped" and lg.fort_lesson() != id, "saved skip " + id)
	await _restore(finished)


func _storage_lesson() -> bool:
	check(lg.fort_lesson_state("store") == "", "storage lesson waits for cap")
	lg.rations = lg.resource_cap("rations")
	await _settle()
	check(lg.fort_lesson_state("store") == "", "no store lesson before the room is built")
	Fixture.set_level(lg, "hq", 2)
	Fixture.set_level(lg, "store", 1)
	lg.fort["money"] = 30000.0
	lg.rations = lg.resource_cap("rations")
	await _settle()
	pending_saves["store"] = save_round_trip()
	lg.flags["fort_lessons"].erase("hq")
	if not _lesson_target("store"):
		return false
	_check_dialog("1080 store")
	await capture("2_store_full_lesson")
	_tap_room("store")
	await _settle()
	var opened := is_instance_valid(camp.card) and camp.selected == "store"
	camp._hide_card()
	lg.rations -= 200
	Fixture.set_level(lg, "hq", 1)
	lg.fort["money"] = 500.0
	lg.flags["fort_lessons"].erase("hq")
	return check(opened and lg.fort_lesson_state("store") == "done", "opening store card finishes lesson")


func _hq_lesson() -> bool:
	check(lg.fort_lesson_state("hq") == "", "HQ lesson waits until affordable")
	game.city.level = 5
	var hq := int(lg.fort_slot_plot("hq")["id"])
	var cost: Dictionary = lg.fort_info(hq)["next_cost"]
	lg.fort["money"] = float(cost["money"]) - 1
	lg.mats = {"iron": 90.0, "wood": 90.0, "leather": 90.0}
	lg.glory = 10000
	await _settle()
	check(lg.fort_lesson_state("hq") == "", "HQ lesson waits for denarii")
	lg.fort["money"] += 2.0
	await _settle()
	if not _lesson_target("hq"):
		return false
	pending_saves["hq"] = save_round_trip()
	_tap_room("hq")
	await _settle()
	if not _lesson_target("hq", camp.upgrade_button) or not press(camp.upgrade_button, "open HQ upgrade"):
		return false
	await _settle()
	if not _verify_hq(1):
		return false
	check(lg.fort_lesson_state("hq") == "done", "opening upgrade finishes HQ lesson")
	await capture("5_hq_window")
	var money := lg.city_money()
	var mats := lg.mats.duplicate()
	var action := _button_in(camp.modal_panel, "FortHQConfirm")
	if not press(action, "start timed HQ upgrade"):
		return false
	action.pressed.emit()
	check(lg.city_money() == money - float(cost["money"]), "timed HQ upgrade pays denarii once")
	for resource: String in cost["mats"]:
		check(lg.mat(resource) == float(mats[resource]) - float(cost["mats"][resource]), "timed HQ upgrade pays " + resource + " once")
	var timer := lg.fort_plot_timer(hq)
	if not check(int(timer.get("to", 0)) == 2, "one HQ construction to level 2"):
		return false
	Legion.clock = float(timer["end"]) + 0.1
	lg.fort_finish()
	camp._clear_room_selection()
	await _settle()
	await _resize(Vector2i(1280, 720))
	check(not camp.guide_layer.is_visible_in_tree(), "720p: knowledge waits until the Forge exists")
	camp.show_hq_upgrade(hq)
	await _settle()
	if not _verify_hq(2):
		return false
	await capture("6_hq_window_720")

	action = _button_in(camp.modal_panel, "FortHQConfirm")
	check(is_instance_valid(action) and action.disabled, "HQ window explains shortage and disables payment")
	var reason := camp.modal_panel.find_child("FortHQReason", true, false) as Label
	check(reason != null and reason.text != "", "HQ window gives a reason")

	var before_instant := save_round_trip()
	var next_cost: Dictionary = lg.fort_info(hq)["next_cost"]
	var price := int(lg.fort_instant_info(hq)["price"])
	lg.fort["money"] = float(next_cost["money"])
	lg.ingots = price
	var next_mats := lg.mats.duplicate()
	await _settle()
	var instant := _button_in(camp.modal_panel, "FortHQInstant")
	if not press(instant, "instant HQ upgrade"):
		return false
	instant.pressed.emit()
	check(lg.camp_level("hq") == 3 and lg.city_money() == 0.0 and lg.ingots == 0, "instant HQ upgrade pays denarii and ingots once")
	for resource: String in next_cost["mats"]:
		check(lg.mat(resource) == float(next_mats[resource]) - float(next_cost["mats"][resource]), "instant HQ upgrade pays " + resource + " once")
	await _restore(before_instant)
	await _resize(Vector2i(1920, 1080))
	return true


func _knowledge_lesson() -> bool:
	check(lg.fort_lesson_state("knowledge") == "", "no knowledge lesson before the Forge")
	lg.fort["money"] = 1000000.0
	lg.mats = {"iron": 900000.0, "wood": 900000.0, "leather": 900000.0}
	Fixture.set_level(lg, "forge", 1)
	await _settle()
	pending_saves["knowledge"] = save_round_trip()
	var forge := int(lg.fort_slot_plot("forge")["id"])
	var smith := Fixture.recruit(lg, false)
	if not check(not smith.is_empty() and lg.fort_assign(forge, int(smith["id"])), "smith fixture assigned"):
		return false
	await _settle()
	_tap_room("forge")
	await _settle()
	var tree_button := _button_in(camp.card, "FortRoomKnowledge")
	if not _lesson_target("knowledge", tree_button) or not press(tree_button, "open forge tree"):
		return false
	await _settle()
	var smith_node := _button_in(camp.modal_panel, "KnowNode_smith")
	if not _lesson_target("knowledge", smith_node) or not press(smith_node, "select Smithing Knowledge"):
		return false
	await _settle()
	var learn := _button_in(camp.modal_panel, "FortLearnSmith")
	if not _lesson_target("knowledge", learn):
		return false
	_check_dialog("1080 knowledge")
	await capture("3_knowledge_lesson")
	if not press(learn, "learn smithing"):
		return false
	await _settle()
	if not check(lg.smith_known() and lg.knowledge_timer().is_empty(), "smith knowledge is instant"):
		return false
	if not _lesson_target("knowledge", camp.upgrade_button) or not press(camp.upgrade_button, "upgrade forge for tier I"):
		return false
	var upgrade := lg.fort_plot_timer(forge)
	if not check(int(upgrade.get("to", 0)) == Gear.tier_room_level(1), "forge reaches tier I recipe gate"):
		return false
	Legion.clock = float(upgrade["end"]) + 0.1
	lg.fort_finish()
	await _settle()
	_tap_room("forge")
	await _settle()
	if not press(camp.main_action, "open forge recipes"):
		return false
	await _settle()
	var recipe := _button_in(camp.lu.overlay, "CraftKind_sword")
	if not _lesson_target("knowledge", recipe) or not press(recipe, "select first recipe"):
		return false
	await _settle()
	var start := _button_in(camp.lu.overlay, "CraftStart")
	if not _lesson_target("knowledge", start) or not press(start, "start first craft"):
		return false
	check(lg.craft_queue(forge).size() == 1 and lg.fort_lesson_state("knowledge") == "done", "first craft ends knowledge lesson")
	camp.lu.close()
	await _settle()
	return true


func _outfit_lesson() -> bool:
	check(lg.fort_lesson_state("outfit") == "", "outfit lesson waits for a work outfit")
	var cook := Fixture.recruit(lg, false)
	var sid := int(cook.get("id", 0))
	var kitchen := int(lg.fort_slot_plot("kitchen")["id"])
	if not check(sid > 0 and lg.fort_assign(kitchen, sid), "cook fixture assigned"):
		return false
	var apron := lg.add_item(Gear.craft_item("cook", 1, 0))
	await _settle()
	if not _lesson_target("outfit"):
		return false
	check(lg.fort_outfit_lesson_target().x == sid, "apron targets the cook")
	pending_saves["outfit"] = save_round_trip()
	click_person(sid)
	await _settle()
	var slot := _button_in(camp.modal_panel, "FortGear_outfit")
	if not _lesson_target("outfit", slot) or not press(slot, "open outfit slot"):
		return false
	await _settle()
	var item := _button_in(camp.modal_panel, "FortEquip_%d" % int(apron["id"]))
	if not _lesson_target("outfit", item):
		return false
	_check_dialog("1080 outfit")
	await capture("4_outfit_lesson")
	if not press(item, "equip apron"):
		return false
	var bonus := camp.modal_panel.find_child("FortOutfitBonus", true, false) as Label
	check(bonus != null and bonus.text == "+15% к выпуску кухни" and bonus.scale.x < 1.0, "apron bonus pops in")
	check(int(apron["on"]) == sid and lg.fort_lesson_state("outfit") == "done", "outfit lesson finished on equip")
	return true


func _verify_hq(level: int) -> bool:
	var panel := camp.modal_panel
	if not check(is_instance_valid(panel) and panel.name == "FortHQUpgrade", "HQ dedicated window"):
		return false
	_check_labels(panel, "HQ %d→%d" % [level, level + 1])
	var grid := panel.find_child("FortHQUnlocks", true, false)
	var actual := {}
	for tile: Control in grid.get_children():
		actual[tile.get_meta("hq_key")] = tile.get_meta("hq_value")
	var next := level + 1
	var expected := {"room_level": str(next)}
	if Legion.fort_room_slots_at("barracks", next) > Legion.fort_room_slots_at("barracks", level):
		expected["barracks"] = "+1"
	for type: String in Legion.FORT_B:
		var amount := Legion.fort_max_at(type, next) - Legion.fort_max_at(type, level)
		if amount > 0:
			expected["room:" + type] = "+%d" % amount
	for e in Legion.FORT_EXP:
		if int(e["hq"]) == next:
			expected["floor"] = "+%d" % lg.fort_grid().x
			expected["section"] = "+%d" % lg.fort_grid().y
	for resource: String in Legion.STOCK_RESOURCES:
		var stores := lg.fort_level_sum("store")
		var gain := Legion.resource_cap_at(resource, next, stores) - Legion.resource_cap_at(resource, level, stores)
		if gain > 0:
			expected["cap:" + resource] = "+" + game.hud.fmt(gain)
	for id: String in Legion.Knowledge.NODES:
		var entry: Dictionary = Legion.Knowledge.NODES[id]
		if int(entry["hq"]) == next:
			expected["knowledge:" + id] = I18n.t(entry["tiers"])
	var slots := Legion.places_at(next) - Legion.places_at(level)
	if slots > 0:
		expected["squad"] = "+%d" % slots
	for r in Legion.REGIONS2.size():
		var gate := int(Legion.REGIONS2[r]["prin"])
		var min_hq := maxi(Legion.PRIN_NONE, int(lg.flags.get("prin0", 0)))
		if gate > maxi(min_hq, level) and gate <= maxi(min_hq, next):
			expected["province:%d" % r] = I18n.t("Провинция %d") % (r + 1)
	check(actual == expected, "HQ %d exact diff: %s vs %s" % [level, actual, expected])
	return true


func _lesson_target(id: String, target: Control = null) -> bool:
	var want := String(target.name) if is_instance_valid(target) else "(fort)"
	var actual := String(camp._guide_target.name) if is_instance_valid(camp._guide_target) else "(fort)"
	return check(lg.fort_lesson() == id and camp.guide_pointer.is_visible_in_tree()
		and camp._guide_rect.has_area() and get_viewport().get_visible_rect().grow(1).encloses(camp._guide_rect)
		and (target == null or (target.is_visible_in_tree() and camp._guide_target == target)),
		"%s visible target %s; got %s at %s (%s)" % [id, want, actual, camp._guide_rect, camp.guide_text.text])


func _check_dialog(tag: String) -> void:
	check(camp.guide.is_visible_in_tree() and is_instance_valid(camp.guide_portrait)
		and camp.guide_portrait.actor.get_meta("loadout").get("outfit") == "centurion", tag + " live centurion")
	_check_labels(camp.guide, tag)
	if camp.guide_pointer.is_visible_in_tree():
		check(get_viewport().get_visible_rect().grow(1).encloses(camp.guide_pointer.get_global_rect()), tag + " arrow in bounds")
		var lit := Rect2(camp.guide_layer.global_position + camp.guide_spotlight.position, camp.guide_spotlight.size)
		check(camp.guide_shade.is_visible_in_tree() and lit.encloses(camp._guide_rect), tag + " target is lit")


func _check_labels(panel: Control, tag: String) -> void:
	var screen := get_viewport().get_visible_rect().grow(1)
	check(screen.encloses(panel.get_global_rect()), tag + " panel in bounds: %s within %s" % [panel.get_global_rect(), screen])
	for label: Label in panel.find_children("*", "Label", true, false):
		if not label.is_visible_in_tree():
			continue
		check(screen.encloses(label.get_global_rect()), tag + " label in bounds: " + label.text)
		var min_size := label.get_minimum_size()
		check(label.size.x + 1 >= min_size.x and label.size.y + 1 >= min_size.y and label.get_visible_line_count() == label.get_line_count(),
			tag + " label fits: " + label.text)


func _button_in(parent: Control, id: String) -> Button:
	return parent.find_child(id, true, false) as Button if is_instance_valid(parent) else null


func _tap_room(kind: String) -> void:
	var view := camp.diorama as FortCutaway
	var id := int(lg.fort_slot_plot(kind)["id"])
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = view.plot_footprint(id).get_center()
	event.pressed = false
	view._gui_input(event)


func _settle() -> void:
	camp._refresh()
	await frames(8)
	camp._layout_guide()


func _restore(data: Dictionary) -> void:
	camp.close()
	lg.from_dict(data.duplicate(true))
	camp.open()
	await _settle()


func _resize(pixels: Vector2i) -> void:
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = pixels
	await frames(10)
	check(get_viewport().get_visible_rect().size.is_equal_approx(Vector2(pixels)), "viewport %s" % str(pixels))


func capture(file: String) -> void:
	await RenderingServer.frame_post_draw
	var path := out + file + ".png"
	if check(get_viewport().get_texture().get_image().save_png(path) == OK, "save " + file):
		print(suite, " SHOT ", path)
