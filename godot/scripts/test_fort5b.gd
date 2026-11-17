extends Node3D
## Шесть экранов стиля A и проверки действий. Запускает владелец тестов.

const Fixture = preload("res://scripts/test_fort_fixture.gd")
const Kit = preload("res://scripts/ui_kit_a.gd")
var out := "D:/CivCity/.work/stage5/fort5d/shots/"
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
	check(camp.diorama is FortCutaway, "painted fort stays active")
	check(camp.chips.get_child_count() == 4 and camp.resource_chips.keys() == ["money", "rations", "glory", "ingots"], "four top resources")
	check(camp.population_button.icon == Kit.texture("family") and camp.population_button.text.contains(str(lg.fort_population())), "population pill")
	check(camp.left_column.get_child_count() == 5 and camp.campaign_button.text == "" and camp.build_button.text == "", "icon navigation")
	check(camp.ration_label.text == "%d / %d" % [lg.rations_now(), lg.ration_cap()], "rations are in top HUD")
	_top_bar_checks("hud")
	await _guide_checks(1, camp.build_button, "hud/build")
	await shot("1_fort_hud.png")
	await _fresh_top_bar_checks("fresh/hud")
	await _guide_checks(0, camp.plot_markers[kitchen]["collect"], "hud/collect long text")
	await _guide_checks(3, camp.campaign_button, "hud/campaign short text")
	lg.flags["camp3d_guide"] = 4
	camp._layout_guide()
	camp.show_plot(forge)
	check(camp.card.has_meta("ui_kit_a") and camp.card.find_child("FortRoomPicture", true, false) != null, "room frame and cutaway picture")
	check(camp.upgrade_button.disabled and camp.requirement_banner.visible and camp.instant_button.disabled, "HQ requirement gates both upgrade actions")
	check(camp.main_action.icon == Kit.texture("craft"), "forge craft action")
	var room_id := camp.card.get_instance_id()
	camp._refresh()
	check(camp.card.get_instance_id() == room_id, "room survives value refresh")
	await _window_checks(camp.card, "room")
	check(camp.main_action.text == I18n.t("Ковать"), "room action label")
	check(camp.room_stock_bar.get_theme_stylebox("fill") is StyleBoxTexture, "textured room fill")
	await shot("2_room_card.png")
	camp.show_plot(kitchen)
	await frames(16)
	var production := camp.card.find_child("FortRoomStock", true, false) as Control
	var resource_icon := production.find_children("*", "TextureRect", true, false)[0] as TextureRect
	check(resource_icon.texture == Kit.resource("rations"), "production resource icon")
	check(camp.room_stock_bar.value > 0 and (camp.room_stock_bar.get_theme_stylebox("fill") as StyleBoxTexture).texture == Kit.box("panels/bar_fill_gold", 20, 0, 20).texture, "production gold fill")
	camp.show_build_menu()
	check(camp.build_cards.size() == Legion.FORT_B.size() - 1, "all room cards")
	check((camp.build_cards["forge"]["picture"] as Control).get_child_count() > 0, "build pictures")
	await _window_checks(camp.modal_panel, "build")
	await _build_button_checks()
	await _guide_checks(2, camp.build_cards["kitchen"]["button"], "build/kitchen")
	lg.flags["camp3d_guide"] = 4
	camp._layout_guide()
	await shot("3_build_menu.png")
	camp.show_dweller(sid)
	var slots := camp.modal_panel.find_child("FortGearSlots", true, false)
	check(slots != null and slots.get_child_count() == 4 and slots.find_children("TierBadge", "Label", true, false).size() == 4, "four equipped slots and tier badges")
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
		check(craft.find_child("CraftKinds", true, false).get_child_count() == 4 and craft.find_child("CraftRarityOdds", true, false).get_child_count() == 5, "recipe icons and five rarity odds")
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
	var back := camp.lu.find_child("CampaignBack", true, false) as Button
	check(back != null and back.icon == Kit.texture("back") and camp.lu.win.has_meta("ui_kit_a"), "campaign frame and back")
	await shot("6_campaign.png")
	camp.lu.close()
	await _small_window_checks(forge, sid)
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
		check(rect.size.y >= 56.0 - 0.1, tag + "/" + b.name + " drawn height >= 56")
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
	check(locked.disabled and (locked.get_node("MedallionLock") as Control).visible and locked.self_modulate.r < 0.7, "locked tier grey and padlock")
	check(panel.find_children("CraftTimerRing", "Control", true, false).size() == 1, "queue timer ring")
	var collect := panel.find_child("CraftCollect_0", true, false) as Button
	check(collect.visible and collect.text == I18n.t("Собрать · %d") % 1, "ready collect label and count")
	var start := panel.find_child("CraftStart", true, false) as Button
	check(start.icon == Kit.texture("craft") and start.text.contains("10"), "craft action icon and material cost")
	var store := panel.find_child("CraftEquipment", true, false) as Button
	check(store.text == I18n.t("Снаряжение") and store.icon != null, "bottom action filled")


func _small_window_checks(forge: int, sid: int) -> void:
	get_window().size = Vector2i(1280, 720)
	await frames(12)
	_top_bar_checks("720/hud")
	await _fresh_top_bar_checks("720/fresh/hud")
	await _guide_checks(1, camp.build_button, "720/build")
	await _guide_checks(3, camp.campaign_button, "720/campaign")
	lg.flags["camp3d_guide"] = 4
	camp._layout_guide()
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
	var money := game.city.money
	var rations := lg.rations
	var glory := lg.glory
	var ingots := lg.ingots
	game.city.money = 1740
	lg.rations = lg.ration_cap()
	lg.glory = 0
	lg.ingots = 0
	camp._refresh()
	await frames(3)
	_top_bar_checks(tag)
	game.city.money = money
	lg.rations = rations
	lg.glory = glory
	lg.ingots = ingots
	camp._refresh()


func _top_bar_checks(tag: String) -> void:
	for resource: String in camp.resource_bars:
		var panel: Control = camp.resource_bars[resource]["panel"]
		var number: Label = camp.resource_chips[resource]
		var fill: ProgressBar = camp.resource_bars[resource]["fill"]
		var pill := panel.get_global_rect()
		var drawn_scale := panel.get_global_transform().get_scale().abs()
		var value_rect := number.get_global_rect()
		check(pill.encloses(value_rect), tag + "/" + resource + " number inside pill")
		check(pill.encloses(fill.get_global_rect()), tag + "/" + resource + " fill inside pill")
		# Кремовая середина между золотыми краями, включая обводку числа.
		var cream := Rect2(pill.position + Vector2(78, 18) * drawn_scale, Vector2(panel.size.x - 112, 46) * drawn_scale)
		var outline := number.get_theme_constant("outline_size")
		check(outline > 0 and cream.grow(0.1).encloses(value_rect.grow(outline * drawn_scale.y)), tag + "/" + resource + " outlined number inside cream")
		check(number.vertical_alignment == VERTICAL_ALIGNMENT_CENTER, tag + "/" + resource + " number centered")
		check(cream.grow(0.1).encloses(fill.get_global_rect()) and fill.get_global_rect().position.y >= value_rect.end.y, tag + "/" + resource + " thin fill below number inside cream")
		var frame := panel.get_theme_stylebox("panel") as StyleBoxTexture
		check(frame != null and frame.get_texture_margin(SIDE_TOP) + frame.get_texture_margin(SIDE_BOTTOM) <= panel.size.y, tag + "/" + resource + " pill slices fit height")
		for state: String in ["background", "fill"]:
			var style := fill.get_theme_stylebox(state) as StyleBoxTexture
			check(style != null and style.get_texture_margin(SIDE_TOP) + style.get_texture_margin(SIDE_BOTTOM) <= fill.size.y, tag + "/" + resource + " fill slices fit height")


func _guide_checks(step: int, target: Control, tag: String) -> void:
	lg.flags["camp3d_guide"] = step
	camp._layout_guide()
	await frames(3)
	if not check(camp.guide.is_visible_in_tree() and camp._guide_target == target, tag + " guide targets control"):
		return
	var viewport := get_viewport().get_visible_rect()
	var bubble := camp.guide.get_global_rect()
	var button := target.get_global_rect()
	check(viewport.encloses(bubble), tag + " guide inside viewport")
	check(bubble.grow(0.1).encloses(camp.guide_text.get_global_rect()), tag + " whole guide text inside bubble")
	var gap := Vector2(maxf(0, maxf(button.position.x - bubble.end.x, bubble.position.x - button.end.x)),
		maxf(0, maxf(button.position.y - bubble.end.y, bubble.position.y - button.end.y)))
	check(gap.length() <= 120, tag + " guide within 120 px of target")
	check(bubble.end.y <= button.position.y + 2, tag + " guide above target")
	var pointer := camp.guide_pointer.get_global_rect()
	check(camp.guide_pointer.is_visible_in_tree() and viewport.encloses(pointer), tag + " pointer inside viewport")
	check(absf(pointer.get_center().x - button.get_center().x) <= 1 and absf(pointer.end.y - button.position.y) <= 4, tag + " arrow touches target")
	var font := camp.guide_text.get_theme_font("font")
	var text_width := font.get_string_size(camp.guide_text.text, HORIZONTAL_ALIGNMENT_LEFT, -1, camp.guide_text.get_theme_font_size("font_size")).x
	var padding := camp.guide.get_theme_stylebox("panel").get_minimum_size().x
	check(absf(camp.guide.size.x - text_width - padding) <= 4, tag + " compact text-sized bubble")


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
