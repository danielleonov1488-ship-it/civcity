extends Node3D
## Дерево и три строки переписи. Запускает владелец проверки; сохранения не пишем.

var out := "D:/CivCity/.work/stage2/ui3/shots/"
var game
var hud: Hud
var city: City
var stories: Stories
var failed := false


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
		failed = true
		print("UI3 FAIL ", message)
		push_error("UI3 FAIL " + message)
		get_tree().quit(1)
	return ok


func shot(file: String) -> bool:
	await frames(8)
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(out + file)
	if not check(error == OK, "save " + file):
		return false
	print("UI3 SHOT ", out + file)
	return true


func _run() -> void:
	var waited := 0
	while not game.ready_done:
		await frames(5)
		waited += 5
		if not check(waited < 18000, "ready_done timeout"):
			return
	game.can_save = false
	game.settings["autosave"] = false
	game.settings["tasks_folded"] = false
	game.settings["advisor_off"] = true
	city = game.city
	city.auto_hire = true  # прежняя фикстура
	hud = game.hud
	stories = game.stories
	stories.force = true
	game.rank_cine.force = false
	if game.tutorial.active():
		game.tutorial.step = Tutorial.STEPS.size()
		game.tutorial.card.visible = false
	city.tips["tut"] = -1
	city.tips["ui"] = 3
	city.tips["rank_pressed"] = true
	hud.apply_reveal(3)
	hud.set_speed(0.0)
	game._set_hour(10.5)
	if not check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory"):
		return
	# Все четыре состояния и зависимость в одном ранге / между рангами.
	city.level = 3
	city.rp = 140
	city.research["stall_veg"] = true
	city.research["warehouse"] = true
	city.research.erase("weaver")
	city.research.erase("butcher")
	city.research.erase("cobbler")
	city.research.erase("artisans")
	city.compute()
	hud._top_action("research")
	await frames(6)
	var tree = hud.research_tree
	if not check(tree.current_rank == city.level and not tree.scroll.get_v_scroll_bar().visible, "current rank page without scrollbar"):
		return
	if not check(tree.cards.size() == Defs.RESEARCH.size(), "all research nodes"):
		return
	for pair: Array in [["warehouse", "done"], ["butcher", "available"], ["cobbler", "locked"], ["artisans", "points"], ["patricians", "locked"]]:
		if not check(String(tree.cards[pair[0]].get_meta("state")) == pair[1], "state " + String(pair[0])):
			return
	var window_rect := hud.research_panel.get_global_rect()
	if not check(Rect2(Vector2.ZERO, hud.root.size).encloses(window_rect), "research window fits HUD at 1280x720"):
		return
	if not await shot("1_tree.png"):
		return
	hud._scroll_research("butcher")
	await frames(5)
	(tree.cards["butcher"] as Button).pressed.emit()
	await frames(4)
	if not check(String(tree.selected) == "butcher" and not tree.study.disabled and hud.pointer_target == tree.study, "node details and study pointer"):
		return
	if not await shot("2_tree_node_panel.png"):
		return
	var before := city.rp
	(tree.study as Button).pressed.emit()
	tree.confirm_yes.pressed.emit()
	if not check(city.research.has("butcher") and is_equal_approx(city.rp, before - float(Defs.research("butcher")["cost"])), "study uses City cost and unlock"):
		return
	# Переход к закрытому исследованию выбирает карточку без фильтра.
	hud._scroll_research("cobbler")
	await frames(5)
	if not check(tree.cards.has("cobbler") and tree.study.disabled and not tree.confirm.visible, "reveal locked node without buying"):
		return
	hud.close_panels()
	if not check(city.new_research() == 0, "unseen research marked on close"):
		return
	if not make_census_town():
		return
	# Как stage7b/test_story: прежние истории пройдены, писец предлагает перепись.
	city.stories = City.stories_new()
	city.stories["h"] = 5800
	for id in ["cat", "bandits", "leak", "square", "donkey", "crowded", "fair", "wedding", "kittens"]:
		city.stories["done"][id] = {"day": 0, "h": 1}
	stories.off = []
	for sd: Dictionary in StoryDefs.all():
		if String(sd["id"]) != "census":
			stories.off.append(String(sd["id"]))
	stories._h_seen = -1
	stories._tried = ""
	stories.tick()
	if not check(String(city.stories["offer"].get("id", "")) == "census", "scribe offers census"):
		return
	stories.accept("go")
	var active: Dictionary = city.stories["active"]
	if not check(stories._goal_kind(active) == "census" and not bool(active["flags"].get("c_person", false)), "census target exists"):
		return
	hud.advisor_panel.hide()
	hud.refresh()
	await frames(4)
	var row: Control = hud.tasks_box.find_child("story_row", true, false)
	var parts: Control = row.find_child("parts", true, false) if row != null else null
	if not check(parts != null and parts.get_child_count() >= 3, "three census task lines"):
		return
	(parts.get_child(0) as Button).pressed.emit()
	await frames(8)
	var query: LineEdit = hud.stats_panel.find_child("q", true, false)
	if not check(query.text == String(active["census"]["name"]) and hud.people_filter == "" and hud.pointer_target == hud.people_target and hud.pointer.visible, "name filter, highlighted row and arrow"):
		return
	if not check(not bool(active["flags"].get("c_person", false)), "opening list does not complete step"):
		return
	if not await shot("3_census_step.png"):
		return
	(hud.people_target as Button).pressed.emit()
	await frames(3)
	stories.tick()
	if not check(bool(active["flags"].get("c_person", false)) and hud.badges.has("quest_target"), "resident card completes step and marks world"):
		return
	var all_parts: Array = stories.row_info()["parts"]
	stories.part_click(all_parts[1])
	await frames(8)
	if not check(hud.people_filter == "happy" and is_instance_valid(hud.people_target) and hud.pointer_target == hud.people_target, "happiest family guided"):
		return
	(hud.people_target as Button).pressed.emit()
	await frames(3)
	stories.tick()
	if not check(bool(active["flags"].get("c_best", false)), "happiest family home completes step"):
		return
	all_parts = stories.row_info()["parts"]
	stories.part_click(all_parts[2])
	await frames(8)
	if not check(hud.people_filter == "kids" and is_instance_valid(hud.people_target) and hud.pointer_target == hud.people_target, "child filter guided"):
		return
	(hud.people_target as Button).pressed.emit()
	await frames(3)
	stories.tick()
	if not check(bool(active["flags"].get("c_child", false)) and bool(active.get("ready", false)), "all census cards complete report step"):
		return
	print("UI3 DONE")
	get_tree().quit()


func make_census_town() -> bool:
	city.money = 100000
	city.level = 3
	city.research["legion"] = true
	city.legion.flags["tut"] = "done"
	var start := Land.START + Vector2(-24, 8)
	var roads: Array = game.land.paint_line(start - Vector2(8, 0), start + Vector2(48, 0), 1.3, Land.Kind.ROAD, true)
	city.road_cells += roads.size()
	game.people.refresh(game.land.road_chunks.keys())
	for i in 4:
		var h := city.place("house_pleb", start + Vector2(i * 10, 5), 0.0, 0, 0, true)
		if not check(not h.is_empty(), "census house %d" % i):
			return false
		game._show(h)
		var family := "Юлии%d" % i
		var count := city.house_cap(h)
		city.settled(int(h["id"]), count, family)
		var members: Array = game.people._make_family(family, count, int(h["id"]), city.door_point(h))
		if i == 0 and members.size() > 2:
			members[2]["child"] = true
			members[2]["m"]["age"] = 0
	for pair: Array in [["scriptorium", Vector2(0, -6)], ["stall_veg", Vector2(14, -6)]]:
		var b := city.place(String(pair[0]), start + Vector2(pair[1]), PI, 0, 0, true)
		if not check(not b.is_empty(), "census workplace " + String(pair[0])):
			return false
		game._show(b)
	city.compute()
	game.people._assign_jobs()
	return check(game.people.residents.size() >= 8, "census residents")
