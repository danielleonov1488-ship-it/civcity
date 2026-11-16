extends Node3D
## Разделы исследований и покупка. Снимки делает владелец проверки; сохранения не пишем.

var out := "D:/CivCity/.work/stage4/research2/shots/"
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
			out = pair[1] if pair[1].ends_with("/") else pair[1] + "/"
	get_window().size = Vector2i(1280, 720)
	Game.boot = {"new": "1", "legion": "0"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	game.can_save = false
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, message: String) -> bool:
	if not ok:
		fails += 1
		print("RESEARCH2 FAIL ", message)
		print("RESEARCH2 DONE fails=", fails)
		get_tree().quit(1)
	return ok


func shot(file: String) -> bool:
	await frames(8)
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(out + file)
	if not check(error == OK, "save " + file):
		return false
	print("RESEARCH2 SHOT ", out + file)
	return true


func same_items() -> bool:
	if tree.cards.size() != item_ids.size():
		return false
	for id: String in item_ids:
		if not is_instance_valid(tree.cards.get(id)) or tree.cards[id].get_instance_id() != item_ids[id]:
			return false
	return true


func wait_for_pictures() -> bool:
	# Первые разделы должны показывать здания, а не временные значки.
	for attempt in 3600:
		var loaded := true
		for r: Dictionary in Defs.RESEARCH:
			if int(r["lvl"]) not in [0, 3]:
				continue
			var types: Array[String] = tree.building_ids(String(r["id"]))
			if not types.is_empty() and hud.icons.get(types[0]) == null:
				loaded = false
		if loaded:
			tree.refresh()
			return true
		await frames(5)
	return check(false, "building pictures timeout")


func _run() -> void:
	var waited := 0
	while not game.ready_done:
		await frames(5)
		waited += 5
		if not check(waited < 18000, "ready_done timeout"):
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
	if not check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory"):
		return
	# Посёлок: готовая красильня, доступная гончарная, дорогие мимы, закрытый этаж.
	city.level = 3
	city.rp = 340
	city.research["stall_veg"] = true
	city.research["warehouse"] = true
	city.research["dyer"] = true
	for id in ["floor2", "floor3", "weaver", "cobbler", "potter", "mimes", "patricians"]:
		city.research.erase(id)
	city.compute()
	city.stats["rp_day"] = 4.5
	hud._top_action("research")
	tree = hud.research_tree
	await frames(10)
	if not check(tree.cards.size() == Defs.RESEARCH.size() and tree.sections.size() == Defs.LEVELS.size(), "all items and ranks built"):
		return
	for id: String in tree.cards:
		item_ids[id] = tree.cards[id].get_instance_id()
	var rank: Control = tree.sections[3]
	if not check(absf(float(tree.scroll.scroll_vertical) - rank.position.y) < 3, "open at current rank"):
		return
	if not check(tree.scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and not tree.popup.visible, "vertical scroll without a permanent side panel"):
		return
	for pair: Array in [["dyer", "done"], ["potter", "available"], ["mimes", "points"], ["floor3", "locked"], ["patricians", "locked"]]:
		if not check(String(tree.cards[pair[0]].get_meta("state")) == pair[1], "state " + String(pair[0])):
			return
	var cost_good: StyleBoxFlat = tree.cards["potter"].get_node("CostBadge").get_theme_stylebox("panel")
	var cost_bad: StyleBoxFlat = tree.cards["mimes"].get_node("CostBadge").get_theme_stylebox("panel")
	if not check(cost_good.bg_color == tree.BADGE_GOOD and cost_bad.bg_color == tree.BADGE_BAD, "green and red costs"):
		return
	if not check(tree.cards["dyer"].get_node("DoneTick").visible and tree.cards["dyer"].get_node("Picture").material != null, "done tick and desaturation"):
		return
	if not check(tree.cards["floor3"].get_node("ParentLock").visible and tree.cards["floor3"].tooltip_text.contains("Сначала: " + String(Defs.research("floor2")["name"])), "parent lock and tooltip"):
		return
	if not check(tree.sections[4].get_node("RankLockOverlay").visible and not rank.get_node("RankLockOverlay").visible, "whole future section locked"):
		return
	if not check(hud.lbl_research_rp.text == "%s / %s" % [hud.fmt(city.rp), hud.fmt(city.rp_cap())] and hud.lbl_research_rate.text == "+4,5 в час", "points and hourly rate"):
		return
	if not await wait_for_pictures():
		return
	var bounds := Rect2(Vector2.ZERO, hud.root.size)
	if not check(bounds.encloses(hud.research_panel.get_global_rect()), "window fits HUD at 1280x720"):
		return
	for tier: int in tree.sections:
		var grid: GridContainer = tree.sections[tier].get_node("Items")
		if not check(grid.columns in [4, 5], "four or five items per row"):
			return
	tree.scroll.scroll_vertical = 0
	if not await shot("1_research_top.png"):
		return
	tree.focus_rank(3)
	await frames(6)
	if not await shot("2_research_mid.png"):
		return
	var potter: Button = tree.cards["potter"]
	var image: TextureRect = potter.get_node("Picture")
	var buildings: Array[String] = tree.building_ids("potter")
	if not check(not buildings.is_empty() and image.texture == hud.icons[buildings[0]] and image.size.x >= 120 and image.size.y >= 100, "large HUD building picture"):
		return
	if not check(potter.get_node("new_mark").visible, "new sparkle before inspecting"):
		return
	potter.pressed.emit()
	await frames(6)
	if not check(tree.popup.visible and tree.selected == "potter" and not tree.study.disabled and hud.pointer_target == tree.study, "item popup and study pointer"):
		return
	if not check(not potter.get_node("new_mark").visible and not city.is_new_r("potter"), "inspecting marks item seen"):
		return
	if not check(bounds.encloses(tree.popup.get_global_rect()), "popup fits HUD"):
		return
	var text := ""
	for label: Label in tree.detail.find_children("*", "Label", true, false):
		text += label.text + "\n"
	if not check(text.contains("Рабочие:") and text.contains("Раздел:") and text.contains("счастья"), "popup explains workers, category and happiness"):
		return
	if not await shot("3_item_popup.png"):
		return
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	var release := InputEventKey.new()
	release.keycode = KEY_ESCAPE
	Input.parse_input_event(release)
	await frames(2)
	if not check(not tree.popup.visible and hud.research_panel.visible, "Esc closes the popup first"):
		return
	potter.pressed.emit()
	await frames(3)
	# Обновление очков не меняет узлы и не позволяет купить без очков.
	city.rp = 0
	hud._fill_research()
	if not check(same_items() and tree.study.disabled and tree._popup_reason.text.contains("Не хватает"), "refresh disables study with a reason without rebuilding"):
		return
	tree.study.pressed.emit()
	if not check(not city.research.has("potter") and city.rp == 0, "City rejects unavailable study"):
		return
	city.rp = 340
	hud._fill_research()
	var before := city.rp
	tree.study.pressed.emit()
	if not check(city.research.has("potter") and is_equal_approx(city.rp, before - float(Defs.research("potter")["cost"])), "study spends research points"):
		return
	if not check(same_items() and tree.study.disabled and tree.cards["potter"].get_meta("state") == "done", "purchase refreshes existing controls"):
		return
	city.rp = 340
	hud._fill_research()
	tree.only_available.set_pressed(true)
	await frames(5)
	for id: String in tree.cards:
		if not check((tree.cards[id] as Control).visible == (city.can_research(id) == ""), "available filter " + id):
			return
	if not check(same_items() and not tree.sections[4].visible and not tree.popup.visible, "filter hides locked sections and reuses items"):
		return
	city.rp = 0
	hud._fill_research()
	if not check(tree._empty.visible, "empty available filter"):
		return
	# Переход из просьбы раскрывает скрытый пункт и объясняет зависимость.
	hud._scroll_research("cobbler")
	await frames(8)
	if not check(not tree.only_available.button_pressed and tree.popup.visible and tree.selected == "cobbler" and tree.study.disabled, "reveal locked item through filter"):
		return
	city.level = 4
	hud._fill_research()
	if not check(same_items() and not tree.sections[4].get_node("RankLockOverlay").visible, "rank change updates overlay without rebuilding"):
		return
	city.level = 3
	hud.close_panels()
	if not check(not tree.popup.visible and city.new_research() == 0, "closing hides popup and clears new marks"):
		return
	hud._top_action("research")
	await frames(8)
	if not check(same_items() and not tree.popup.visible and absf(float(tree.scroll.scroll_vertical) - rank.position.y) < 3, "reopen current rank without rebuilding"):
		return
	# Узкое окно перестраивает только раскладку: четыре предмета вместо пяти.
	hud.research_panel.custom_minimum_size.x = 800
	hud._snug(hud.research_panel)
	await frames(8)
	if not check((rank.get_node("Items") as GridContainer).columns == 4 and same_items(), "four columns in a narrow window without rebuilding"):
		return
	if not check(Rect2(Vector2.ZERO, hud.root.size).encloses(hud.research_panel.get_global_rect()), "narrow window fits HUD"):
		return
	tree.fit_window()
	print("RESEARCH2 DONE fails=", fails)
	get_tree().quit()
