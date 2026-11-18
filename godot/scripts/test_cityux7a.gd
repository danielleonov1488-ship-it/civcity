extends Node3D
## Проверки интерфейса; запускает проверяющий. Пользовательские сохранения не пишем.

const ResearchChecks = preload("res://scripts/test_research8.gd")

var out := "D:/CivCity/.work/stage6/cityux7a/shots/"
var prefix := "CITYUX7A"
var resolution := Vector2i(1280, 720)
var only_research := false
var game
var hud: Hud
var city: City
var tree
var fails := 0
var item_ids: Dictionary = {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2 and pair[0] == "out":
			out = pair[1].trim_suffix("/") + "/"
	get_window().size = resolution
	Game.boot = {"new": "1", "legion": "0"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	game.can_save = false
	_run()


func frames(n := 6) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, message: String) -> bool:
	if not ok:
		fails += 1
		print(prefix, " FAIL ", message)
	return ok


func shot(file: String) -> void:
	await frames(8)
	await RenderingServer.frame_post_draw
	if check(get_viewport().get_texture().get_image().save_png(out + file) == OK, "save " + file):
		print(prefix, " SHOT ", out + file)


func same_items() -> bool:
	for id: String in item_ids:
		if tree.cards[id].get_instance_id() != item_ids[id]:
			return false
	return true


func text_in(node: Node) -> String:
	var result := ""
	for label: Label in node.find_children("*", "Label", true, false):
		result += label.text + "\n"
	return result


func move_to(node: Control) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _pointer_at(node)
	event.global_position = event.position
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await frames(3)


func card_of(type: String) -> Control:
	for child: Control in hud.tray_grid.get_children():
		if child.get_meta("type", "") == type:
			return child
	return null


func wait_for_pictures() -> void:
	for attempt in 3600:
		var loaded := true
		for id: String in ["potter", "stall_veg", "warehouse"]:
			var types: Array[String] = tree.building_ids(id)
			if not types.is_empty() and hud.icons.get(types[0]) == null:
				loaded = false
		if loaded:
			tree.refresh()
			return
		await frames(5)
	check(false, "building pictures timeout")


func _run() -> void:
	var waited := 0
	while not game.ready_done and waited < 18000:
		await frames(5)
		waited += 5
	if not check(game.ready_done, "ready_done timeout"):
		print(prefix, " DONE fails=", fails)
		get_tree().quit(1)
		return
	game.can_save = false
	game.settings["autosave"] = false
	game.settings["advisor_off"] = true
	game.rank_cine.force = false
	if game.tutorial.active():
		game.tutorial.step = Tutorial.STEPS.size()
		game.tutorial.card.hide()
	hud = game.hud
	city = game.city
	I18n.set_lang("ru")
	city.tips["tut"] = -1
	city.tips["ui"] = 3
	city.tips["rank_pressed"] = true
	city.tips["seen_r"] = {}
	hud.apply_reveal(3)
	hud.set_speed(0.0)
	game._set_hour(10.5)
	check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory")
	city.level = 3
	city.rp = 340
	city.research["dyer"] = true
	city.research["stall_veg"] = true
	for id: String in ["floor2", "floor3", "warehouse", "potter", "mimes", "patricians"]:
		city.research.erase(id)
	city.compute()
	hud._top_action("research")
	tree = hud.research_tree
	await _research_menu()
	hud.close_panels()
	if not only_research:
		await _build_menus()
		await _top_tooltips()
	_finish()


func _finish() -> void:
	print(prefix, " DONE fails=", fails)
	get_tree().quit(1 if fails > 0 else 0)


func _pointer_at(node: Control) -> Vector2:
	return node.get_viewport().get_final_transform() * (node.get_global_transform_with_canvas() * (node.size * 0.5))


func _click(node: Control, button := MOUSE_BUTTON_LEFT) -> void:
	await move_to(node)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down and button == MOUSE_BUTTON_LEFT else 0
		event.pressed = down
		event.position = _pointer_at(node)
		event.global_position = event.position
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames(1)
	await frames()


func _research_menu() -> void:
	await frames()
	await wait_for_pictures()
	check(tree.cards.size() == Defs.RESEARCH.size(), "all research nodes")
	check(tree.current_rank == city.level, "opens at current rank")
	var tab_row := hud.research_panel.find_child("ResearchTabs", true, false) as Control
	var city_tab := tab_row.get_node("CityTab") as Button
	check(city_tab.button_pressed and not city_tab.disabled and tab_row.get_child_count() == 4, "City tab selected")
	for node: Button in tab_row.get_children():
		if node != city_tab:
			check(node.disabled, "reserved tab locked")
	for id: String in tree.cards:
		item_ids[id] = tree.cards[id].get_instance_id()
	for lang: String in ["en", "ru"]:
		I18n.set_lang(lang)
		hud._fill_research()
		await frames()
		ResearchChecks.check_tree(hud, city, check)

	tree.select_rank(0)
	await frames()
	check(tree.scroll.scroll_vertical == 0, "scroll returns to first rank")
	await shot("00_research_top.png")
	await _click(tree.scroll, MOUSE_BUTTON_WHEEL_DOWN)
	check(tree.scroll.scroll_vertical > 0, "mouse wheel scrolls research")
	tree.select_rank(3)
	await frames()
	check(tree.scroll.scroll_vertical > 0, "middle rank is further down")
	await shot("01_research_middle.png")

	var potter: Button = tree.cards["potter"]
	var mimes: Button = tree.cards["mimes"]
	var floor3: Button = tree.cards["floor3"]
	check(not potter.disabled and mimes.disabled, "affordability on the item")
	check((floor3.get_node("ParentLock") as Control).visible and (floor3.get_node("Upgrade") as Control).visible, "locked upgrade has both badges")
	check(tree.tooltip(Defs.research("floor3")).contains("Сначала: " + String(Defs.research("floor2")["name"])), "prerequisite in tooltip")
	await move_to(potter)
	check(tree.popup.visible and tree.popup.name == "ResearchTooltip", "tooltip on actual hover")
	ResearchChecks.check_tooltip(tree.popup, check)
	check(tree.popup.find_children("*", "Button", true, false).is_empty(), "tooltip has no actions")
	check(tree.detail.get_child_count() <= 3 and tree._popup_picture.texture != null, "picture and short tooltip")
	await shot("02_research_hover.png")

	var before := city.rp
	await _click(potter)
	check(tree.confirm.visible and tree.pending == "potter" and not city.research.has("potter"), "click asks before spending")
	check(tree.confirm.get_parent() == potter and tree.confirm.position.y >= (potter.get_node("ItemName") as Label).get_rect().end.y, "confirm is inline below the item name")
	check(tree.confirm_text.text == "Изучить за 320?", "inline confirm copy")
	check(tree.study_target() == tree.confirm_yes, "tutorial targets confirmation")
	await shot("03_research_confirm.png")
	await _click(tree.confirm.find_child("ConfirmNo", true, false) as Button)
	check(city.rp == before and not tree.confirm.visible, "No cancels free of charge")
	await _click(potter)
	city.rp = 0
	hud._fill_research()
	tree.confirm_yes.pressed.emit()
	check(not city.research.has("potter"), "stale confirmation cannot study")
	city.rp = before
	hud._fill_research()
	await _click(potter)
	await _click(tree.confirm_yes)
	check(city.research.has("potter") and is_equal_approx(city.rp, before - 320.0), "Yes spends exactly once")
	tree.confirm_yes.pressed.emit()
	check(is_equal_approx(city.rp, before - 320.0), "double Yes cannot spend twice")
	check(hud.research_panel.visible and potter.disabled and (potter.get_node("DoneTick") as Control).visible
		and not (potter.get_node("CostBadge") as Control).visible, "window stays open and bought item gets its badge")
	check(same_items(), "item nodes reused")

	get_window().size = resolution
	await frames()
	ResearchChecks.check_tree(hud, city, check)
	await tree.focus_card("floor3")
	await frames()
	tree.show_detail("floor3")
	await frames()
	ResearchChecks.check_tooltip(tree.popup, check)
	hud.close_panels()
	check(not tree.popup.visible and not tree.confirm.visible, "closing hides tooltip and confirmation")


func _build_menus() -> void:
	city.level = 0
	city.research.erase("stall_fish")
	city.research.erase("patricians")
	city.research.erase("s_leak")
	hud.refresh()
	for cid: String in hud.cats:
		check((hud.cats[cid] as Control).get_parent().visible == (not hud._category_types(cid).is_empty()), "empty category hidden " + cid)
	hud._toggle_cat("commerce")
	hud.open_sub = "food"
	hud._fill_cards()
	check(card_of("stall_fish") == null and card_of("stall_veg") != null, "locked card absent beside open card")
	for type: String in Defs.B:
		if not city.unlocked(type):
			check(not hud._category_types(String(Defs.B[type]["cat"])).has(type), "locked category member absent " + type)
	city.rp = 100
	check(city.do_research("stall_fish"), "unlock fish fixture")
	hud.refresh()
	await frames()
	var fish := card_of("stall_fish")
	check(fish != null and fish.get_node("new_mark").visible, "new unlock appears immediately with NEW")
	city.research.erase("stall_fish")
	hud.refresh()
	check(card_of("stall_fish") == null, "revoked unlock removes card immediately")
	hud._toggle_cat("decor")
	hud.decor_query = "фонтан"
	hud.decor_mode = "search"
	hud._fill_cards()
	for card: Control in hud.tray_grid.get_children():
		if card.has_meta("type"):
			check(city.unlocked(String(card.get_meta("type"))), "locked search result absent")
	await shot("05_build_unlocked.png")
	hud.close_panels()


func _top_tooltips() -> void:
	hud._close_tray()
	hud.refresh()
	await frames()
	var flow := city.projected_finance()
	check(is_equal_approx(float(flow["income"]) - float(flow["expense"]), city.projected_net()), "money breakdown equals net")
	await move_to(hud.hover_money)
	var money := text_in(hud.hover_box)
	check(hud.hover_src == hud.hover_money and hud.hover_tip.visible and money.contains("Налоги") and money.contains("Лавки") and money.contains("Туристы") and money.contains("Содержание") and money.contains("Жалованье") and money.contains("Казна вмещает"), "money hover breakdown and cap")
	await shot("06_money_breakdown.png")
	await move_to(hud.hover_rp)
	var rp := text_in(hud.hover_box)
	check(hud.hover_src == hud.hover_rp and hud.hover_tip.visible and rp.contains("Почта") and rp.contains("Скриптории") and rp.contains("Школы") and rp.contains("Полки вмещают"), "research hover breakdown and shelf cap")
	await shot("07_research_breakdown.png")
