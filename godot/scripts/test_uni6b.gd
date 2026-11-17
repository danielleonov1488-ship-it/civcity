extends "res://scripts/test_uni6_support.gd"
## Регресс UNI6-b: ширина, очередь советов, предложения и стрелки по просьбе игрока.


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	if not await boot_run("UNI6B", "D:/CivCity/.work/stage5/uni6b/shots/"):
		finish_run()
		return
	game.tutorial.finish()
	game.tutorial.set_process(false)
	game.stories.set_process(false)
	game.settings["tasks_folded"] = false
	game.settings["advisor_off"] = true
	hud.quiet_tips = 1
	city.level = 5
	city.research["floor2"] = true
	city.research["floor3"] = true
	city.auto_hire = true
	clear_guidance()
	await cards_and_research()
	await advice_queue()
	await offers()
	await pointer_rule()
	await advice_copy()
	finish_run()


func cards_and_research() -> void:
	var home := place("house_pleb", Land.START + Vector2(-12, 16))
	if home.is_empty():
		return
	home["families"] = [{"name": "Корнелии", "n": 4, "cls": "plebs"}]
	home["pop"] = 4
	Residents.fit(home["families"][0], 42, "plebs")
	var source := place("stall_fruit", Land.START + Vector2(-12, 24))
	if source.is_empty():
		return
	city.compute()
	for lang: String in ["ru", "en"]:
		I18n.set_lang(lang)
		for more: bool in [false, true]:
			hud.house_more = more
			hud.open_info(home)
			await frames(12)
			check(absf(hud.info_panel.size.x - Hud.INFO_WIDTH) <= 1.0, lang + " house stays 340 including scroll, more=%s" % more)
			var scroll := hud.info_box.find_child("house_scroll", true, false) as ScrollContainer
			check(scroll != null and scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_RESERVE, "house reserves scrollbar inside card")
			inspect_panel(hud.info_panel)
			await shot("01_house_%s_%s.png" % [lang, "more" if more else "short"])
		hud.close_panels()
		hud._open_overview("people")
		await frames()
		for name: String in ["tab_main", "tab_people"]:
			var tab := hud.overview_panel.find_child(name, true, false) as Button
			if check(tab != null and tab.icon != null, name + " icon and short text"):
				var width := tab.get_theme_font("font").get_string_size(I18n.t(tab.text), HORIZONTAL_ALIGNMENT_LEFT, -1, tab.get_theme_font_size("font_size")).x
				var style := tab.get_theme_stylebox("normal")
				width += style.get_content_margin(SIDE_LEFT) + style.get_content_margin(SIDE_RIGHT) + tab.get_theme_constant("icon_max_width") + tab.get_theme_constant("h_separation")
				check(width <= tab.size.x + 1.0, lang + " " + name + " whole text fits")
		inspect_panel(hud.overview_panel)
		await shot("02_overview_%s.png" % lang)
		hud.close_panels()
	I18n.set_lang("ru")
	var i := 0
	for cls: String in Defs.CLASS_ORDER:
		var type: String = {"plebs": "stall_fruit", "artisans": "taberna", "patricians": "theatre"}[cls]
		var work := source if i == 0 else place(type, Land.START + Vector2(12 + 16 * i, 16))
		i += 1
		if work.is_empty():
			continue
		hud.open_info(work)
		await frames()
		var row := hud.info_box.find_child("hire_class_" + cls, true, false) as HBoxContainer
		if check(row != null, cls + " availability row"):
			var picture := row.get_child(0) as TextureRect
			check(picture != null and picture.texture == CityStyle.icon(String(CityStyle.CLASS_ICON[cls])), cls + " city class pictogram")
		await shot("03_workers_%s.png" % cls)
	hud.close_panels()
	hud._top_action("research")
	await frames()
	var tree = hud.research_tree
	tree.select_rank(Defs.LEVELS.size() - 1)
	tree.reveal("deco_flowers")
	await frames(12)
	check(tree.current_rank == int(Defs.research("deco_flowers")["lvl"]), "research detail reveals correct rank")
	(tree.cards["deco_flowers"] as Control).mouse_entered.emit()
	await frames()
	inspect_panel(tree.popup)
	await shot("04_research_detail.png")
	hud.close_panels()
	check(not tree.popup.visible, "research detail closes with window")
	clear_guidance()


func advice_queue() -> void:
	game.settings["advisor_off"] = false
	hud.quiet_tips = 0
	clear_guidance()
	city.stats["happy"] = 25
	city.stats["arrive_block"] = "low"
	hud.advisor("Налоги по классам", "Откройте «Обзор города» → «Деньги», чтобы изменить налоги.", Callable(), true)
	hud.advisor("Другой совет", "Совет, который игрок ещё читает", Callable(), true)
	hud.on_arrive_block("Новые семьи не едут")
	check(hud.adv_title.text == "Налоги по классам" and city.tips.has("arrive_wait"), "arrival warning waits for taxes")
	hud.adv_ok.pressed.emit()
	hud._tip_next = 0
	hud._flush_guidance()
	check(hud.advisor_panel.visible and hud.adv_title.text == "Другой совет" and city.tips.has("arrive_wait"), "warning survives queued advice")
	hud.adv_ok.pressed.emit()
	hud._tip_next = 0
	city.stats["happy"] = 41
	hud._flush_guidance()
	check(hud.advisor_panel.visible and hud.adv_title.text == "Новые семьи не едут" and hud.adv_text.text.contains("41%") and not city.tips.has("arrive_wait"), "arrival warning uses happiness at display time")
	await shot("05_arrival_after_taxes.png")
	clear_guidance()
	city.stats["arrive_block"] = ""


func offers() -> void:
	var stories: Stories = game.stories
	stories.force = true
	stories.off.clear()
	for sd: Dictionary in StoryDefs.all():
		stories.off.append(String(sd["id"]))
	StoryDefs.extra = [
		{"id": "uni6b_first", "title": "Проба", "icon": "scroll", "lvl": 0, "pop": 0, "cast": {}, "who": "", "role": "", "steps": [{"id": "ask", "cine": []}, {"id": "wait", "goal": ["wait", 1]}]},
		{"id": "uni6b_second", "title": "Проба 2", "icon": "scroll", "lvl": 0, "pop": 0, "cast": {}, "who": "", "role": "", "steps": [{"id": "ask", "cine": []}, {"id": "wait", "goal": ["wait", 1]}]},
	]
	city.stories = City.stories_new()
	city.stories["h"] = StoryDefs.FIRST_H
	stories._h_seen = -1
	stories._tried = ""
	city.tips["tut"] = 0
	check(not stories._offer_first(false), "offer stays gated during tutorial")
	city.tips["tut"] = -1
	hud.advisor("Налоги по классам", "Совет, который игрок ещё читает", Callable(), true)
	stories.tick()
	check(String(city.stories["offer"].get("id", "")) == "uni6b_first" and hud.adv_title.text == "Налоги по классам", "quiet offer appears behind open advice after tutorial")
	check(not stories._offer_first(false) and String(city.stories["offer"].get("id", "")) == "uni6b_first", "second offer cannot replace first")
	stories.postpone()
	city.stories["h"] = int(city.stories["h"]) + StoryDefs.LATER_H - 1
	stories.tick()
	check((city.stories["offer"] as Dictionary).is_empty(), "postponed offer waits 23 hours")
	city.stories["h"] = int(city.stories["h"]) + 1
	stories.tick()
	check(String(city.stories["offer"].get("id", "")) == "uni6b_first", "postponed offer returns after day despite open advice")
	await shot("06_one_story.png")
	city.stories["offer"] = {}
	city.stories["active"] = {"id": "uni6b_first", "step": 1}
	check(not stories._offer_first(false), "active story prevents another offer")
	StoryDefs.extra = []
	stories.off.clear()
	city.stories = City.stories_new()
	clear_guidance()


func pointer_rule() -> void:
	hud.close_panels()
	game.set_tool("")
	clear_guidance()
	hud.rank_btn.show()
	hud._update_pointer()
	await frames(3)
	check(hud.pointer_target == null and not hud.pointer.visible, "rank and requests never create automatic city arrow")
	# Настоящая строка просьбы: стрелка возникает только после её щелчка.
	var goal := Defs.request("fed6")
	hud._clear(hud.tasks_box)
	hud._fill_tasks_body([goal])
	var row_button: Button = null
	for row: Node in hud.tasks_box.get_children():
		if row is MarginContainer:
			for child: Node in row.get_children():
				if child is Button:
					row_button = child as Button
	if check(row_button != null, "request line can be clicked"):
		row_button.pressed.emit()
		await frames(5)
		check(hud.pointer_target != null and hud.pointer.visible and not hud._ptr_shown.is_empty(), "request click shows arrow")
		await shot("07_requested_arrow.png")
		hud._ptr_shown["until"] = Time.get_ticks_msec() - 1
		hud._update_pointer()
		await frames(3)
		check(hud.pointer_target == null and not hud.pointer.visible and hud._ptr_shown.is_empty() and Hud.PTR_SHOW_MS == 6000, "expired arrow stays off without automatic fallback")
	game.set_tool("")
	hud.close_panels()
	clear_guidance()


func advice_copy() -> void:
	for lang: String in ["ru", "en"]:
		I18n.set_lang(lang)
		clear_guidance()
		city.tips.erase("floor_tool")
		hud.floor_tip(true)
		check(hud.adv_text.text.contains("U") and hud.adv_text.text.contains("зажатой" if lang == "ru" else "held down"), lang + " floor advice keeps key and brush")
		inspect_panel(hud.advisor_panel)
		await shot("08_floor_advice_%s.png" % lang)
		clear_guidance()
		hud.advisor("Казна пуста", hud.unpaid_advice(), Callable(), true)
		check(hud.adv_text.text.contains("налог" if lang == "ru" else "taxes"), lang + " finance advice keeps recovery")
		inspect_panel(hud.advisor_panel)
		await shot("09_finance_advice_%s.png" % lang)
	I18n.set_lang("ru")
	clear_guidance()
