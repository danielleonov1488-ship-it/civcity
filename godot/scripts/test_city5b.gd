extends "res://scripts/test_ui4.gd"
## CITY5b: шесть кадров, компактные карточки и дерево исследований.

const ResearchChecks = preload("res://scripts/test_research8.gd")


func _ready() -> void:
	out = "D:/CivCity/.work/stage5/city5b/shots/"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=").trim_suffix("/") + "/"
	get_window().size = Vector2i(1440, 900)
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	game.can_save = false
	add_child(game)
	_run()


func check(ok: bool, why: String) -> bool:
	if not ok:
		fails += 1
		print("CITY5B FAIL " + why)
	return ok


func shot(file: String) -> void:
	hud.advisor_panel.hide()
	await frames(12)
	hud._place_badges()
	await RenderingServer.frame_post_draw
	if check(get_viewport().get_texture().get_image().save_png(out + file) == OK, "save " + file):
		print("CITY5B SHOT " + out + file)


func _finish() -> void:
	print("CITY5B DONE fails=", fails)
	get_tree().quit(0 if fails == 0 else 1)


func _run() -> void:
	var waited := 0
	while not game.ready_done:
		await frames(5)
		waited += 5
		if waited >= 18000:
			check(false, "ready_done timeout")
			_finish()
			return
	game.can_save = false
	game.settings["autosave"] = false
	game.settings["advisor_off"] = true
	game.settings["tasks_folded"] = true
	game.speed = 0.0
	game.build_anim = false
	game.rig.cine = true
	game.tutorial.step = Tutorial.STEPS.size()
	game.tutorial.card.hide()
	game.tutorial.set_process(false)
	I18n.set_lang("ru")
	hud = game.hud
	city = game.city
	city.level = 5
	city.money = 1000000
	city.rp = 100000
	city.auto_hire = false
	city.tips["tut"] = -1
	city.tips["ui"] = 3
	city.research["floor2"] = true
	city.research["artisans"] = true
	hud.apply_reveal(3)
	hud.close_panels()
	if not check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory"):
		_finish()
		return
	var house := place("house_pleb", Vector2(177, 136))
	house["tier"] = 2
	family(house, "Юлии", true)
	(house["families"] as Array)[0]["want"] = "trees"
	var bare := place("house_pleb", Vector2(145, 158))
	family(bare, "Валерии", true)
	var isolated := place("house_pleb", Vector2(227, 122), false)
	isolated["tier"] = 2
	family(isolated, "Туллии")
	var fruit := place("stall_fruit", Vector2(183, 137))
	var temple := place("temple", Vector2(155, 131))
	place("barber", Vector2(207, 130))
	# Поперечные улицы упираются в продолжение дороги от площади станции.
	game.land.paint_line(Vector2(Land.ROAD_X, 126), Vector2(Land.ROAD_X, 165), 1.4, Land.Kind.ROAD)
	city.compute()
	check(city.house_connected(house) and city.house_connected(bare), "fixture streets connect both houses to station")
	for building: Dictionary in [fruit, temple]:
		check(city.hire(building, city.job_max(building)) > 0, "hire " + String(building["type"]))
	bare["happy"] = 20
	bare["unhappy_h"] = 3
	for f: Dictionary in bare["families"]:
		f["grace_until"] = 0
	var waiting := city.new_family("plebs")
	waiting["want"] = "quiet"
	city.family_arrived(waiting, false)
	game.people._on_resident_returned(waiting)
	city.compute()
	city.changed.emit()
	city.arrivals_changed.emit()
	hud._update_world_icons()
	hud._family_badge_next_ms = 0
	hud._family_badges()
	game.rig.set_view(Vector3(183, 3, 134), 0, 50, 94)
	await frames(12)
	_badges_without_text()
	check(hud.badges.has("b%d" % int(bare["id"])), "problem badge present")
	await shot("1_badges_city.png")
	game.start_settle(String(waiting["name"]))
	await frames(6)
	var settle_key := "settle%d" % int(house["id"])
	check(hud.badges.has(settle_key), "settle room present")
	check(city.house_free_floors(isolated) > 0 and not hud.badges.has("settle%d" % int(isolated["id"])), "disconnected house has no settle badge despite free room")
	if hud.badges.has(settle_key):
		var room: Badge = hud.badges[settle_key]["n"]
		check(room.texture == Badge.badge_texture("home_room") and room.matches, "home_room plus want match")
		check(room.match_texture == Badge.badge_texture("match"), "approved match disc")
	_badges_without_text()
	await shot("2_settle_mode.png")
	game.set_tool("")
	var family_key := "fam_" + String(waiting["name"])
	check(hud.badges.has(family_key), "waiting family present")
	if hud.badges.has(family_key):
		var badge: Badge = hud.badges[family_key]["n"]
		check(badge.size == Vector2(44, 44) and badge.texture == Badge.badge_texture("family"), "family 44px hit area")
		check(badge.preference_texture == Badge.badge_texture("want_quiet"), "attached want disc")
		var at: Vector3 = hud.badges[family_key]["pos"]
		game.rig.set_view(at - Vector3(0, 1, 0), 0, 48, 30)
	await shot("3_family_waiting.png")
	game.rig.set_view(Vector3(174, 2, 137), 0, 48, 65)
	game.select_building(house)
	hud.open_info(house)
	await frames(8)
	_card_bounds()
	check(hud.info_box.find_children("sources_*", "Control", true, false).size() == Defs.needs_for("plebs", city.level).size(), "only required needs get rows")
	var scroll := hud.info_box.find_child("house_scroll", true, false) as ScrollContainer
	check(scroll != null and hud.info_panel.size.y <= 600.0, "compact house scroll")
	var members := hud.info_box.find_child("Members", true, false) as Control
	var preference := hud.info_box.find_child("Preference", true, false) as Control
	var family := hud.info_box.find_child("family_0", true, false)
	check(family is PanelContainer and members != null and preference != null and family.is_ancestor_of(members) and family.is_ancestor_of(preference), "busts and want share one family block")
	await shot("4_house_card.png")
	game.select_building(fruit)
	hud.open_info(fruit)
	await frames(8)
	_card_bounds()
	for action: String in ["InfoDemolish", "InfoMove", "InfoCopy"]:
		var button := hud.info_box.find_child(action, true, false) as Button
		check(button != null and button.text == "" and button.size.x <= 36, "small round " + action)
	check(hud.info_box.find_child("hire_plus", true, false) != null, "hire action retained")
	await shot("5_building_card.png")
	await _research_pages()
	_finish()


func _badges_without_text() -> void:
	for entry: Dictionary in hud.badges.values():
		var badge: Badge = entry["n"]
		check(badge.label == null and badge.find_children("*", "Label", true, false).is_empty(), "no badge label")
		check(String(entry["text"]) == "" and badge.texture.resource_path.begins_with(Badge.BADGES), "badge uses approved PNG")
		check(badge.size == Vector2(44, 44), "44px hit area")
	for want: String in FamilyWant.ORDER:
		check(Badge.want_texture(want).resource_path.ends_with("want_" + ("square" if want == "plaza" else want) + ".png"), "want texture " + want)


func _card_bounds() -> void:
	check(absf(hud.info_panel.size.x - 340.0) <= 1.0, "card width 340 including scroll (now %.1f)" % hud.info_panel.size.x)
	check(Rect2(Vector2.ZERO, hud.root.size).encloses(hud.info_panel.get_global_rect()), "card inside HUD")
	for label: Label in hud.info_box.find_children("*", "Label", true, false):
		check(label.get_theme_color("font_color") in [CityStyle.INK, Hud.C_GOOD, Hud.C_BAD], "city ink and semantic numbers")


func _research_pages() -> void:
	city.level = 7
	hud._top_action("research")
	await frames(8)
	var tree = hud.research_tree
	check(tree.cards.size() == Defs.RESEARCH.size(), "all research controls retained")
	check(tree.sections.size() == Defs.LEVELS.size(), "one section per city rank")
	var ids := {}
	var counts := {}
	var largest := 0
	for id: String in tree.cards:
		var card: Button = tree.cards[id]
		ids[id] = card.get_instance_id()
		if card.visible:
			var tier := int(Defs.research(id)["lvl"])
			counts[tier] = 1 + int(counts.get(tier, 0))
			if int(counts[tier]) > int(counts.get(largest, 0)):
				largest = tier
	ResearchChecks.check_tree(hud, city, check)
	city.level = 3
	tree.refresh()
	await frames(6)
	ResearchChecks.check_tree(hud, city, check)
	city.level = 7
	tree.refresh()
	tree.select_rank(largest)
	await frames(6)
	await _wait_research_pictures()
	await shot("6_research.png")
	var available: Button
	for card: Button in tree.cards.values():
		if card.is_visible_in_tree() and not card.disabled:
			available = card
			break
	if check(available != null, "available research fixture"):
		var id := String(available.get_meta("rid"))
		tree.reveal(id)
		await frames(8)
		check(not tree.popup.visible and tree.selected == id and tree.study == available, "reveal scrolls to item without opening tooltip")
		tree.show_detail(id)
		await frames(6)
		ResearchChecks.check_tooltip(tree.popup, check)
		var before := city.rp
		available.pressed.emit()
		check(tree.confirm.visible and tree.confirm.get_parent() == available and not city.research.has(id), "inline confirmation before study")
		tree.confirm_yes.pressed.emit()
		check(hud.research_panel.visible and city.research.has(id) and city.rp < before, "study spends points and leaves the menu open")
	for id: String in ids:
		check(tree.cards[id].get_instance_id() == ids[id], "research nodes reused")


func _wait_research_pictures() -> void:
	var tree = hud.research_tree
	for attempt in 3600:
		var loaded := true
		for r: Dictionary in Defs.RESEARCH:
			if int(r["lvl"]) != tree.current_rank or not (tree.cards[String(r["id"])] as Control).is_visible_in_tree():
				continue
			var types: Array[String] = tree.building_ids(String(r["id"]))
			for type: String in types:
				if city.city_buildable(type) and hud.icons.get(type) == null:
					loaded = false
		if loaded:
			tree.refresh()
			return
		await frames(5)
	check(false, "research pictures timeout")
