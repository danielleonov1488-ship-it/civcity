extends Node3D
## Шесть экранов стиля A и проверки действий. Запускает владелец тестов.

const Fixture = preload("res://scripts/test_fort_fixture.gd")
const Look = preload("res://scripts/legion_look.gd")
const Kit = preload("res://scripts/ui_kit_a.gd")
var out := "D:/CivCity/.work/stage6/legion7a2/shots/fort5b/"
var fails := 0
var game: Game
var camp: CampUI
var lg: Legion
var saved_clock := -1.0
var capture_size := Vector2i(1920, 1080)


func check(ok: bool, reason: String) -> bool:
	if not ok:
		fails += 1
		print("FORT5B FAIL " + reason)
	return ok


func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func shot(file: String) -> void:
	await frames(16)
	await RenderingServer.frame_post_draw
	if check(get_viewport().get_texture().get_image().save_png(out + file) == OK, "save " + file):
		print("FORT5B SHOT " + out + file)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4).trim_suffix("/") + "/"
		if arg.begins_with("viewport="):
			var parts := arg.substr(9).split("x")
			if parts.size() == 2:
				capture_size = Vector2i(int(parts[0]), int(parts[1]))
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = capture_size
	saved_clock = Legion.clock
	Legion.clock = 2000000.0
	Game.boot = {"new": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	game.can_save = false
	add_child(game)
	_run()


func _finish() -> void:
	if is_instance_valid(camp):
		camp.close()
	Legion.clock = saved_clock
	print("FORT5B DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _run() -> void:
	var waited := 0
	while not game.ready_done:
		await frames(5)
		waited += 5
		if not check(waited < 18000, "ready_done timeout"):
			_finish()
			return
	game.can_save = false
	game.settings["autosave"] = false
	game.set_process(false)
	if not check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory"):
		_finish()
		return
	var city: City = game.city
	city.cozy_v = 1
	city.legion_v = 3
	city.money = 125400
	for i in 16:
		var house := city.place("house_pleb", Land.START + Vector2((i % 8) * 8, (i / 8) * 8), 0.0, 0, 0, true)
		if not check(not house.is_empty(), "house fixture"):
			_finish()
			return
		house["families"] = [{"name": "Юлии%d" % i, "n": 4, "cls": "plebs"}]
		house["pop"] = 4
	city.compute()
	lg = city.legion
	lg.fort = {}
	lg.camp = {}
	lg.soldiers.clear()
	lg.items.clear()
	lg.squad3 = [0, 0, 0, 0, 0]
	lg.flags["camp_open"] = true
	lg.flags["camp_told"] = true
	lg.flags["camp3d_guide"] = 4
	lg.army_tick()
	lg.fort["money"] = 125400.0
	lg.fort["know"] = {"smith": true}
	for entry: Array in [["hq", 3], ["barracks", 1], ["kitchen", 1], ["forge", 4], ["store", 1]]:
		Fixture.set_level(lg, String(entry[0]), int(entry[1]))
	lg.mats = {"iron": 10000.0, "wood": 10000.0, "leather": 10000.0}
	lg.glory = 3850
	lg.rations = 28
	lg.ingots = 120
	lg.queue_chest("wooden")
	lg.queue_chest("bronze")
	var kitchen := int(lg.fort_slot_plot("kitchen")["id"])
	var forge := int(lg.fort_slot_plot("forge")["id"])
	var cook := Fixture.recruit(lg, false)
	var smith := Fixture.recruit(lg, false)
	var person := Fixture.recruit(lg)
	if not check(not cook.is_empty() and not smith.is_empty() and not person.is_empty(), "three residents"):
		_finish()
		return
	check(lg.fort_assign(kitchen, int(cook["id"])) and lg.fort_assign(forge, int(smith["id"])), "assign production workers")
	var cook_id := int(cook["id"])
	var outfit := lg.add_item(Gear.craft_item("cook", 1))
	check(lg.equip(cook_id, int(outfit["id"])), "equip kitchen worker for the guide")
	var sid := int(person["id"])
	person["stars"] = 3
	for kind: String in ["sword", "helmet", "armor", "offhand"]:
		var it := lg.add_item(Gear.craft_item(kind, 2, 2))
		check(lg.equip(sid, int(it["id"])), "equip fixture " + kind)
	for kind: String in ["sword", "bow", "staff", "spear", "helmet", "armor", "offhand"]:
		lg.add_item(Gear.craft_item(kind, 3, 3))
	lg.fort_plot(kitchen)["pend"] = 3.0
	Fixture.gate(lg, 3)
	camp = CampUI.of(game.hud)
	if not check(camp != null, "CampUI attached"):
		_finish()
		return
	camp.open()
	await frames(12)
	check(get_viewport().get_visible_rect().size.is_equal_approx(Vector2(capture_size)), "initial viewport size")
	check(camp.diorama is FortCutaway, "painted fort stays active")
	check(camp.chips.get_child_count() == 7 and camp.chips.columns == 4
		and camp.chips.get_child(3).name == "FortResource_glory", "seven resources with glory in the top row")
	check(camp.population_button.icon == Kit.texture("family") and camp.population_button.text.contains(str(lg.fort_population())), "population pill")
	_navigation_checks()
	var ration_chip := camp.chips.get_node_or_null("FortResource_rations") as Control
	if check(ration_chip != null and ration_chip.is_visible_in_tree(), "rations are in top HUD"):
		var bread := ration_chip.find_child("ResourceIcon", true, false) as TextureRect
		check(bread != null and bread.texture == Look.resource("rations")
			and camp.ration_label.text == camp.hud.fmt(lg.rations_now()), "painted rations with current amount")
	_top_bar_checks("hud")
	var guide_tag := str(capture_size.y)
	await _guide_checks(Legion.FortGuide.FIRST_BATTLE, camp.campaign_button, guide_tag + "/first battle")
	await shot("1_fort_hud.png")
	await _fresh_top_bar_checks("fresh/hud")
	await _fort_guide_checks(kitchen, cook_id, int(outfit["id"]), guide_tag)
	camp.show_plot(forge)
	check(camp.card.find_child("FortRoomPicture", true, false) != null, "room frame and cutaway picture")
	check(camp.upgrade_button.disabled and camp.requirement_banner.visible and camp.instant_button.disabled, "HQ requirement gates both upgrade actions")
	check(camp.main_action.icon == Kit.texture("craft"), "forge craft action")
	var room_id := camp.card.get_instance_id()
	camp._refresh()
	check(camp.card.get_instance_id() == room_id, "room survives value refresh")
	await _window_checks(camp.card, "room")
	check(camp.main_action.text == I18n.t("Ковать"), "room action label")
	check(camp.room_stock_bar.get_theme_stylebox("fill") is StyleBoxFlat, "room value fill")
	await shot("2_room_card.png")
	camp.show_plot(kitchen)
	await frames(16)
	var production := camp.card.find_child("FortRoomStock", true, false) as Control
	var resource_icon := production.find_children("*", "TextureRect", true, false)[0] as TextureRect
	check(resource_icon.texture == Look.resource("rations"), "production resource icon")
	check(camp.room_stock_bar.value > 0 and (camp.room_stock_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color == Look.OLIVE, "production olive fill")
	camp.show_build_menu()
	check(camp.build_cards.size() == Legion.FORT_B.size() - 2
		and not camp.build_cards.has("hq") and not camp.build_cards.has("drill"), "room catalog without HQ and drill")
	check((camp.build_cards["forge"]["picture"] as Control).get_child_count() > 0, "build pictures")
	await _window_checks(camp.modal_panel, "build")
	await _build_button_checks()
	await shot("3_build_menu.png")
	camp.show_chests()
	await frames(4)
	var starter := camp.modal_panel.find_child("FortChest_wooden", true, false) as Control
	check(is_instance_valid(starter) and starter.is_visible_in_tree(), "wooden chest in storage")
	camp.show_dweller(sid)
	var slots := camp.modal_panel.find_child("FortGearSlots", true, false)
	check(slots != null and slots.find_children("FortGear_*", "Button", true, false).size() == 5, "five equipment slots")
	for slot: String in Gear.SLOTS_V3:
		var button := camp.modal_panel.find_child("FortGear_" + slot, true, false) as Button
		if not check(button != null, "slot " + slot):
			continue
		var tier := button.get_node_or_null("TierBadge") as Label
		check(tier == null if slot == Gear.OUTFIT_SLOT else tier != null and tier.text == "2", "equipped tier " + slot)
	check(camp.modal_panel.find_child("FortInventoryGrid", true, false) != null, "inventory grid")
	await _window_checks(camp.modal_panel, "dweller")
	check((camp.modal_panel.find_child("FortInventoryTitle", true, false) as Label).text == I18n.t("На складе"), "inventory title spacing")
	var move := camp.modal_panel.find_child("FortMoveDweller", true, false) as Button
	check(move.text == I18n.t("Переместить") and move.icon == Kit.texture("swap"), "move action")
	for gain: Label in camp.modal_panel.find_children("PowerDelta", "Label", true, false):
		var positive := int(gain.text) >= 0
		var tint := gain.get_theme_color("font_color")
		check(tint.g > tint.r if positive else tint.r > tint.g, "equipment delta color")
	await shot("4_dweller_card.png")
	var better: Dictionary = lg.items.filter(func(it: Dictionary): return int(it.get("on", 0)) == 0 and it["slot"] == "weapon" and it["cls"] == "legionary")[0]
	var before := Legion.power(lg.soldier_stats(person, "legionary"))
	camp._equip_dweller(sid, int(better["id"]))
	check(int(better["on"]) == sid and Legion.power(lg.soldier_stats(person, "legionary")) != before, "equipment still changes stats")   # набор II распадается — сила может и упасть
	camp._close_modal()
	check(lg.craft_start(forge, "sword", 1), "craft fixture starts")
	var active_job: Dictionary = lg.craft_queue(forge)[0]
	active_job["left"] = float(active_job["total"]) * 0.65
	active_job["end"] = Legion.now() + float(active_job["left"])
	camp.lu.open_craft(forge)
	await frames(4)
	var craft := camp.lu.overlay.find_child("CraftPanel", true, false)
	if check(craft != null, "craft panel"):
		var craft_id := craft.get_instance_id()
		camp.lu._craft_win()
		camp.lu._tick_live()
		check(camp.lu.overlay.find_child("CraftPanel", true, false).get_instance_id() == craft_id, "craft survives timer refresh")
		check(craft.find_child("CraftKinds", true, false).get_child_count() == 4
			and craft.find_child("CraftOutfits", true, false).get_child_count() == Gear.WORK_OUTFITS.size()
			and craft.find_child("CraftRarityOdds", true, false).get_child_count() == 5, "weapons, work outfits and five weapon rarity odds")
		var active_ring := craft.find_child("CraftTimerRing", true, false) as Control
		check(float(active_ring.get("value")) > 0 and float(active_ring.get("value")) < 1, "active timer ring progress")
		await _window_checks(craft, "craft/timer")
		active_job["left"] = 0.0
		active_job["end"] = 0.0
		camp.lu._craft_win()
		await _window_checks(craft, "craft")
		_craft_button_checks(craft)
	await shot("5_craft_panel.png")
	camp.lu.close()
	camp._campaign()
	await frames(6)
	var map := camp.lu.fort_map
	var back: Button = map.get_node_or_null("CampaignBack") if is_instance_valid(map) else null
	check(is_instance_valid(map) and map.is_visible_in_tree() and not camp.lu.win.visible
		and map.find_child("FortMapNodes", true, false) != null and map.find_child("FortProvinces", true, false) != null,
		"full-screen campaign trail and provinces")
	var map_rations: Label = camp.lu.fort_map_values.get("rations")
	check(is_instance_valid(map_rations) and map_rations.is_visible_in_tree()
		and map_rations.text == camp.hud.fmt(lg.rations_now()), "map top bar also shows rations")
	await shot("6_campaign.png")
	if check(back != null and back.icon == Look.icon("map") and back.is_visible_in_tree(), "campaign back"):
		back.pressed.emit()
		check(camp.visible and not camp.lu.visible, "map returns to fort")
	else:
		camp.lu.close()
	await _small_window_checks(forge, sid, kitchen, cook_id, int(outfit["id"]))
	camp.show_newcomer(int(lg.fort_newcomers()[0]["id"]))
	check(camp.modal_panel.name == "FortNewcomerCard" and camp.modal_panel.has_meta("ui_kit_a"), "newcomer kit")
	await _newcomer_checks("newcomer")
	camp.show_expansion("floor")
	check(camp.modal_panel.name == "FortExpansionCard" and camp.modal_panel.has_meta("ui_kit_a"), "expansion kit")
	camp._close_modal()
	_instant_checks(kitchen, forge)
	_finish()


func _window_checks(window: Control, tag: String) -> void:
	await frames(16)
	if not check(is_instance_valid(window), tag + " window exists"):
		return
	var safe := Rect2(Vector2.ONE * 24, get_viewport().get_visible_rect().size - Vector2.ONE * 48)
	check(safe.grow(1).encloses(window.get_global_rect()), tag + " 24 px screen margin")
	var count := 0
	for node: Node in window.find_children("*", "Button", true, false):
		var b := node as Button
		if not b.has_meta("ui_kit_a") or not b.is_visible_in_tree():
			continue
		var rect := b.get_global_rect()
		var visible_rect := rect
		var parent := b.get_parent()
		while parent is Control:
			var control := parent as Control
			if control.clip_contents or control is ScrollContainer:
				visible_rect = visible_rect.intersection(control.get_global_rect())
			if control == window:
				break
			parent = parent.get_parent()
		if not visible_rect.has_area():
			continue # За краем горизонтальной ленты кнопка не рисуется.
		count += 1
		var compact_close: bool = window.name == "FortDwellerCard" and b.get_meta("kit_role", "") == "close"
		var minimum_height := 40.0 if compact_close else 56.0
		check(rect.size.y >= minimum_height - 0.1, "%s/%s drawn height >= %d" % [tag, b.name, int(minimum_height)])
		if compact_close:
			var close_skin := b.get_theme_stylebox("normal") as StyleBoxTexture
			check(is_equal_approx(rect.size.x, rect.size.y) and close_skin != null
				and close_skin.texture == Kit.texture(Kit.ROOT + "buttons/close_btn.png"),
				tag + " round B1 close")
		check(window.get_global_rect().grow(1).encloses(rect), tag + "/" + b.name + " inside window")
		check(visible_rect.grow(1).encloses(rect), tag + "/" + b.name + " not clipped")
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			var style := b.get_theme_stylebox(state) as StyleBoxTexture
			if check(style != null and style.texture != null, tag + "/" + b.name + " texture " + state):
				check(style.get_texture_margin(SIDE_TOP) + style.get_texture_margin(SIDE_BOTTOM) <= b.size.y, tag + "/" + b.name + " slice fits height")
		if b.get_meta("kit_role", "") == "action":
			var has_icon := b.icon != null
			var has_text := not b.text.strip_edges().is_empty()
			for child: Node in b.find_children("*", "Control", true, false):
				if child is TextureRect and (child as TextureRect).texture != null and (child as Control).is_visible_in_tree():
					has_icon = true
				if child is Label and not (child as Label).text.strip_edges().is_empty() and (child as Control).is_visible_in_tree():
					has_text = true
			check(has_icon and has_text, tag + "/" + b.name + " action has icon and label/count")
	check(count > 0, tag + " visible kit buttons checked")


func _build_button_checks() -> void:
	for type: String in camp.build_cards:
		var b: Button = camp.build_cards[type]["button"]
		if not b.is_visible_in_tree():
			continue
		camp.build_scroll.ensure_control_visible(b)
		await frames(2)
		check(camp.modal_panel.get_global_rect().grow(1).encloses(b.get_global_rect()), "build/" + type + " whole button in window")
		check(b.get_global_rect().size.y >= 56 and b.icon != null and not b.text.is_empty(), "build/" + type + " icon, price, height")
	camp.build_scroll.scroll_horizontal = 0
	await frames(2)


func _craft_button_checks(panel: Control) -> void:
	var selected := panel.find_child("CraftKind_sword", true, false) as Button
	check((selected.get_node("SelectionRing") as Control).visible, "selected recipe gold ring")
	var tier := panel.find_child("CraftTier_1", true, false) as Button
	check((tier.get_node("SelectionRing") as Control).visible, "selected tier gold ring")
	var locked := panel.find_child("CraftTier_10", true, false) as Button
	check(not locked.disabled and locked.get_node_or_null("CraftRecipeLock") != null, "locked tier grey and padlock")
	check(panel.find_children("CraftTimerRing", "Control", true, false).size() == 1, "queue timer ring")
	var collect := panel.find_child("CraftCollect_0", true, false) as Button
	check(collect.visible and collect.text == I18n.t("Собрать · %d") % 1, "ready collect label and count")
	var start := panel.find_child("CraftStart", true, false) as Button
	var cost := Gear.craft_mats("sword", 1)
	var iron := I18n.t("железо: %d") % int(cost["iron"])
	var wood := I18n.t("дерево: %d") % int(cost["wood"])
	check(start.icon == Kit.texture("craft") and start.text == I18n.t("Ковать · %s") % (iron + " · " + wood),
		"craft action icon and material costs")
	var store := panel.find_child("CraftEquipment", true, false) as Button
	check(store.text == I18n.t("Снаряжение") and store.icon != null, "bottom action filled")


func _small_window_checks(forge: int, sid: int, kitchen: int, cook_id: int, outfit: int) -> void:
	var small_size := Vector2i(1280, 720)
	get_window().size = small_size
	await frames(12)
	check(get_viewport().get_visible_rect().size.is_equal_approx(Vector2(small_size)), "720 viewport size")
	_top_bar_checks("720/hud")
	await _fresh_top_bar_checks("720/fresh/hud")
	await _guide_checks(Legion.FortGuide.FIRST_BATTLE, camp.campaign_button, "720/first battle")
	await _fort_guide_checks(kitchen, cook_id, outfit, "720")
	camp.show_plot(forge)
	await _window_checks(camp.card, "720/room")
	camp.show_build_menu()
	await _window_checks(camp.modal_panel, "720/build")
	await _build_button_checks()
	camp.show_dweller(sid)
	await _window_checks(camp.modal_panel, "720/dweller")
	camp._close_modal()
	camp.lu.open_craft(forge)
	await frames(4)
	var panel := camp.lu.overlay.find_child("CraftPanel", true, false) as Control
	await _window_checks(panel, "720/craft")
	check(lg.craft_start(forge, "sword", 1), "full queue fixture starts")
	camp.lu._craft_win()
	await frames(4)
	panel = camp.lu.overlay.find_child("CraftPanel", true, false) as Control
	await _window_checks(panel, "720/craft/full queue")
	camp.lu.close()
	camp.show_newcomer(int(lg.fort_newcomers()[0]["id"]))
	await _newcomer_checks("720/newcomer")
	camp._close_modal()
	get_window().size = capture_size
	await frames(12)


func _fresh_top_bar_checks(tag: String) -> void:
	var money := lg.city_money()
	var rations := lg.rations
	var glory := lg.glory
	var ingots := lg.ingots
	lg.fort["money"] = 1740.0
	lg.rations = lg.ration_cap()
	lg.glory = 0
	lg.ingots = 0
	camp._refresh()
	await frames(3)
	_top_bar_checks(tag)
	lg.fort["money"] = money
	lg.rations = rations
	lg.glory = glory
	lg.ingots = ingots
	camp._refresh()


func _navigation_checks() -> void:
	var icons: Array[String] = ["trophy", "squad", "quests", "money"]
	if not check(camp.left_column.get_child_count() == icons.size() and camp.build_button.text == I18n.t("Строить"), "icon navigation"):
		return
	for i in icons.size():
		var button := camp.left_column.get_child(i) as Button
		check(button.icon == Look.icon(icons[i]) and not button.tooltip_text.is_empty(), "navigation icon and tooltip " + icons[i])
	check(camp.chest_button.name == "FortStorageButton" and camp.chest_button.icon != null, "storage navigation")
	check(camp.order_button.name == "FortCityOrder"
		and camp.order_button.tooltip_text.begins_with(I18n.t("Заказать денарии из города")), "city order tooltip")
	check(camp.order_ring != null and camp.order_ring.get_parent() == camp.order_button, "city order timer ring")


func _top_bar_checks(tag: String) -> void:
	for resource: String in camp.resource_bars:
		var panel: Control = camp.resource_bars[resource]["panel"]
		var number: Label = camp.resource_chips[resource]
		var icon := panel.find_child("ResourceIcon", true, false) as TextureRect
		check(panel.get_global_rect().encloses(number.get_global_rect()), tag + "/" + resource + " number inside pill")
		check(number.vertical_alignment == VERTICAL_ALIGNMENT_CENTER, tag + "/" + resource + " number centered")
		check(icon != null and icon.texture == Look.resource(resource) and icon.custom_minimum_size.x >= 42, tag + "/" + resource + " painted resource icon")
		check(panel.get_theme_stylebox("panel") is StyleBoxFlat, tag + "/" + resource + " flat palette")


func _fort_guide_checks(kitchen: int, cook_id: int, outfit: int, tag: String) -> void:
	lg.flags["fort_guide_sid"] = cook_id
	lg.flags["fort_guide_plot"] = kitchen
	lg.flags["fort_guide_item"] = outfit
	var collect := camp.plot_markers.get(kitchen, {}).get("collect") as Control
	await _guide_checks(Legion.FortGuide.KITCHEN, collect, tag + "/kitchen collect")
	await _guide_checks(Legion.FortGuide.STORE, camp.build_button, tag + "/store build")
	await _guide_checks(Legion.FortGuide.SECOND_BATTLE, camp.campaign_button, tag + "/second battle")
	lg.finish_fort_guide()
	camp._layout_guide()


func _guide_checks(step: int, target: Control, tag: String) -> void:
	lg.flags["fort_guide"] = step
	camp._layout_guide()
	await frames(12)
	await RenderingServer.frame_post_draw
	if not check(is_instance_valid(target) and target.is_visible_in_tree()
		and camp.guide.is_visible_in_tree() and camp._guide_target == target, tag + " guide targets control"):
		return
	var viewport := get_viewport().get_visible_rect()
	var strip := camp.guide.get_global_rect()
	var button := target.get_global_rect()
	var text_rect := camp.guide_text.get_global_rect()
	check(viewport.encloses(strip), tag + " dialog strip inside viewport")
	var bottom := Rect2(Vector2(viewport.get_center().x - strip.size.x * 0.5,
		viewport.end.y - strip.size.y - 22.0 * camp.guide.scale.y), strip.size)
	if not bottom.intersects(button.grow(6.0)):
		check(viewport.end.y - strip.end.y <= 24.0, tag + " dialog strip at the bottom")
	check(camp.guide_text.is_visible_in_tree() and strip.grow(0.1).encloses(text_rect),
		"%s whole text inside dialog strip (text %s, strip %s)" % [tag, text_rect, strip])
	check(not strip.intersects(button), tag + " dialog strip clears target")
	var pointer := camp.guide_pointer.get_global_rect()
	check(camp.guide_pointer.is_visible_in_tree() and viewport.encloses(pointer), tag + " pointer inside viewport")
	var above := not camp.guide_pointer.flip_v
	var tip := Vector2(pointer.get_center().x, pointer.end.y if above else pointer.position.y)
	var edge := Vector2(button.get_center().x, button.position.y if above else button.end.y)
	check(pointer.get_center().distance_to(edge) <= 120.0 and tip.distance_to(edge) <= 4.0,
		tag + " green arrow near and pointing at target")


func _newcomer_checks(tag: String) -> void:
	await frames(16)
	var window := camp.modal_panel
	if not check(is_instance_valid(window), tag + " window exists"):
		return
	for node: Node in window.find_children("*", "PanelContainer", true, false):
		var panel := node as PanelContainer
		if panel.is_visible_in_tree():
			check(_has_visible_content(panel), tag + "/" + String(window.get_path_to(panel)) + " no empty visible panel")
	var hint := window.find_child("FortNewcomerClass", true, false) as TextureRect
	check(hint != null and hint.texture != null and hint.is_visible_in_tree() and not hint.tooltip_text.is_empty(), tag + " class hint icon")
	var stars := window.find_child("FortTalentStars", true, false) as Control
	check(stars != null and stars.is_visible_in_tree() and stars.get_child_count() == 5, tag + " five talent stars")
	var origin := window.find_child("FortNewcomerOrigin", true, false) as Label
	check(origin != null and origin.is_visible_in_tree() and not origin.text.strip_edges().is_empty(), tag + " origin line")
	var viewport := get_viewport().get_visible_rect()
	check(viewport.encloses(window.get_global_rect()), tag + " window inside viewport")
	for name: String in ["FortNewcomerClass", "FortTalentStars", "FortNewcomerOrigin"]:
		var content := window.find_child(name, true, false) as Control
		check(content != null and content.get_global_rect().has_area() and window.get_global_rect().encloses(content.get_global_rect()), tag + "/" + name + " content inside card")


func _has_visible_content(node: Node) -> bool:
	for child: Node in node.get_children():
		if child is Control and not (child as Control).is_visible_in_tree():
			continue
		if child is Label and not (child as Label).text.strip_edges().is_empty():
			return true
		if child is TextureRect and (child as TextureRect).texture != null:
			return true
		if child is Button and ((child as Button).icon != null or not (child as Button).text.strip_edges().is_empty()):
			return true
		if _has_visible_content(child):
			return true
	return false


func _instant_checks(kitchen: int, forge: int) -> void:
	var money := lg.city_money()
	var ingots := lg.ingots
	check(not lg.fort_instant(forge) and lg.ingots == ingots and lg.city_money() == money, "instant respects HQ gate without debit")
	lg.ingots = 0
	check(not lg.fort_instant(kitchen) and lg.city_money() == money, "instant needs ingots before normal payment")
	lg.ingots = 10000
	var quote := lg.fort_instant_info(kitchen)
	check(int(quote["price"]) == maxi(1, ceili(1.2 * sqrt(float(lg.fort_info(kitchen)["next_time"]) / 60.0))), "fresh instant price follows square root")
	var level := int(lg.fort_plot(kitchen)["lv"])
	check(lg.fort_instant(kitchen), "instant upgrade succeeds")
	check(int(lg.fort_plot(kitchen)["lv"]) == level + 1 and lg.ingots == 10000 - int(quote["price"]) and lg.city_money() < money, "instant pays both costs and completes once")
	check(lg.fort_upgrade(kitchen), "timed upgrade starts")
	var timed_quote := lg.fort_instant_info(kitchen)
	var left := float(lg.fort_plot(kitchen)["up"]["end"]) - Legion.now()
	check(int(timed_quote["price"]) == maxi(1, ceili(1.2 * sqrt(left / 60.0))), "active instant price follows remaining minutes")
	var paid := lg.city_money()
	var stock := lg.ingots
	check(lg.fort_instant(kitchen) and lg.city_money() == paid and lg.ingots == stock - int(timed_quote["price"]), "active timer instant does not charge upgrade twice")
	var after := lg.ingots
	check(not lg.fort_instant(kitchen, timed_quote) and lg.ingots == after, "stale quote cannot buy next level")
