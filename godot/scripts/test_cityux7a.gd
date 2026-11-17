extends Node3D
## Проверки интерфейса; запускает проверяющий. Пользовательские сохранения не пишем.

var out := "D:/CivCity/.work/stage6/cityux7a/shots/"
var prefix := "CITYUX7A"
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
	get_window().size = Vector2i(1280, 720)
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
	check(get_viewport().get_texture().get_image().save_png(out + file) == OK, "save " + file)
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
	event.position = node.get_viewport().get_final_transform() * (node.get_global_transform_with_canvas() * (node.size * 0.5))
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
	await frames()
	await wait_for_pictures()
	check(tree.cards.size() == Defs.RESEARCH.size(), "all research nodes")
	check(tree.current_rank == city.level, "opens current rank")
	check(hud.research_panel.find_child("OnlyAvailable", true, false) == null, "no research filter")
	for tier: int in tree.rank_tabs:
		var tab: Control = tree.rank_tabs[tier]
		var caption := tab.find_child("RankName", true, false) as Label
		check(caption.get_theme_font_size("font_size") >= 14, "readable rank %d" % tier)
		check(caption.get_theme_color("font_color") == CityStyle.INK and tab.modulate.a == 1.0, "dark future rank text")
		check((tab.find_child("RankPadlock", true, false) as Control).visible == (tier > city.level), "future rank padlock")
	for id: String in tree.cards:
		item_ids[id] = tree.cards[id].get_instance_id()
	for tier: int in tree.sections:
		tree.select_rank(tier)
		await frames()
		var bounds := Rect2(Vector2.ZERO, hud.root.size)
		check(bounds.encloses(hud.research_panel.get_global_rect()), "rank fits viewport %d" % tier)
		for r: Dictionary in Defs.RESEARCH:
			var card: Control = tree.cards[String(r["id"])]
			if not card.is_visible_in_tree():
				continue
			var label := card.get_node("ItemName") as Label
			check(label.text == I18n.t(String(r["name"])), "full name " + String(r["id"]))
			check(label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING and not label.text.contains("…"), "no name ellipsis")
			check(label.get_line_count() <= 2 and label.size.y >= label.get_line_height() * label.get_line_count(), "name fits two lines " + String(r["id"]))
			check(tree.scroll.get_global_rect().grow(1).encloses(card.get_global_rect()), "card fits page")
			var price := card.get_node("CostBadge").get_child(0) as Control
			check((price.get_node("Icon") as Control).custom_minimum_size.x >= 18, "18px price icon")
			check((price.get_node("Cost") as Label).get_theme_font_size("font_size") >= 14, "14px price")
			check(card.has_node("Study"), "per-card study")
		check(not tree.scroll.get_v_scroll_bar().visible and not tree.scroll.get_h_scroll_bar().visible, "no research scrolling")
	tree.select_rank(2)
	await shot("00_full_names.png")
	tree.select_rank(3)
	await frames()
	var potter: Button = tree.cards["potter"]
	var action := potter.get_node("Study") as Button
	check(not action.disabled and (tree.cards["mimes"].get_node("Study") as Button).disabled, "affordability buttons")
	check((tree.cards["floor3"].get_node("ParentLock") as Control).visible, "prerequisite padlock")
	check(tree.tooltip(Defs.research("floor3")).contains("Сначала: " + String(Defs.research("floor2")["name"])), "prerequisite in tooltip")
	check((tree.cards["floor3"].get_node("PrerequisiteIcon") as Control).visible, "other rank prerequisite icon")
	var good := (potter.get_node("CostBadge").get_child(0).get_node("Cost") as Label).get_theme_color("font_color")
	var grey := (tree.cards["mimes"].get_node("CostBadge").get_child(0).get_node("Cost") as Label).get_theme_color("font_color")
	check(good != grey, "green and grey price states")
	await move_to(potter)
	check(tree.popup.visible and tree.popup.name == "ResearchTooltip", "tooltip on actual hover")
	check(tree.popup.find_children("*", "Button", true, false).is_empty(), "tooltip has no popup actions")
	check(tree.detail.get_child_count() <= 3 and tree._popup_picture.texture != null, "tiny picture and short tooltip")
	await shot("01_research_hover.png")
	var before := city.rp
	action.pressed.emit()
	check(tree.confirm.visible and tree.pending == "potter" and not city.research.has("potter"), "study asks before spending")
	check(tree.confirm_text.text == "Изучить «Гончарная» за 320 свитков?", "inline confirm copy")
	check(tree.study_target() == tree.confirm_yes, "tutorial targets confirmation")
	await shot("02_inline_confirm.png")
	(tree.confirm.get_node("ConfirmNo") as Button).pressed.emit()
	check(city.rp == before and not tree.confirm.visible, "No cancels free of charge")
	action.pressed.emit()
	city.rp = 0
	hud._fill_research()
	tree.confirm_yes.pressed.emit()
	check(not city.research.has("potter"), "stale confirmation cannot study")
	city.rp = before
	hud._fill_research()
	action.pressed.emit()
	tree.confirm_yes.pressed.emit()
	check(city.research.has("potter") and is_equal_approx(city.rp, before - 320.0), "Yes spends exactly once")
	tree.confirm_yes.pressed.emit()
	check(is_equal_approx(city.rp, before - 320.0), "double Yes cannot spend twice")
	check(hud.research_panel.visible and action.disabled and action.text == "Изучено", "window stays and card updates")
	check(same_items(), "card nodes reused")
	await shot("03_studied.png")
	tree.select_rank(1)
	await frames()
	var link := tree.sections[1].get_node("PrerequisiteLinks").get_node_or_null("butcher") as Line2D
	check(link != null and link.visible and link.points.size() >= 4, "same-page prerequisite connector")
	await shot("04_dependencies.png")
	hud.close_panels()
	check(not tree.popup.visible and not tree.confirm.visible, "closing hides tooltip and confirmation")
	await _build_menus()
	await _top_tooltips()
	print(prefix, " DONE fails=", fails)
	get_tree().quit(1 if fails > 0 else 0)


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
