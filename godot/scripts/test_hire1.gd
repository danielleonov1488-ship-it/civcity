extends Node3D
## HIRE1: ручной найм, экономика, сохранение и четыре кадра. Godot запускает проверяющий.

var out := "D:/CivCity/.work/stage4/hire1/shots/"
var game
var fails := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2 and pair[0] == "out":
			out = pair[1].trim_suffix("/") + "/"
	Game.boot = {"new": "1", "hour": "10"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	game.can_save = false
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, why: String) -> bool:
	if not ok:
		fails += 1
		print("HIRE1 FAIL " + why)
	return ok


func shot(file: String) -> void:
	await frames(12)
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(out + file)
	if check(error == OK, "save " + file):
		print("HIRE1 SHOT " + out + file)


func texts(node: Node) -> String:
	var result := ""
	if node is Label or node is Button:
		result += String(node.text) + "\n"
	for child in node.get_children():
		result += texts(child)
	return result


func road(c: City, b: Dictionary) -> void:
	var door := c.door_point(b)
	c.land.paint_line(door - Vector2(3, 0), door + Vector2(3, 0), 2.0, Land.Kind.ROAD, true)
	c.compute()


func place(c: City, type: String, pos: Vector2) -> Dictionary:
	var b := c.place(type, pos, 0.0, 0, 0, true)
	road(c, b)
	return b


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
	game.settings["advisor_off"] = true
	game.speed = 0.0
	game.build_anim = false
	game.tutorial.step = Tutorial.STEPS.size()
	game.tutorial.card.hide()
	game.tutorial.set_process(false)
	I18n.set_lang("ru")
	var c: City = game.city
	var hud: Hud = game.hud
	c.cozy_v = 1
	c.auto_hire = false
	c.level = 3
	c.money = 1000000
	c.tips["tut"] = -1
	c.tips["ui"] = 3
	hud.apply_reveal(3)
	hud.close_panels()
	hud.advisor_panel.hide()
	if not check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory"):
		_finish()
		return
	var at := Land.START + Vector2(22, 8)
	for i in 9:
		var home := place(c, "house_pleb", at + Vector2(-12 + (i % 3) * 9, 12 + (i / 3) * 8))
		var family := {"name": "Юлии%d" % i, "n": 2, "cls": "plebs"}
		home["families"] = [family]
		home["pop"] = 2
		home["happy"] = 60  # новосёлы довольны, проверяем выпуск без штрафа
		game.people._make_family(family["name"], 2, int(home["id"]), c.door_point(home), "plebs", family)
	c.compute()
	var farm := place(c, "farm", at + Vector2(-23, -10))
	var store := place(c, "warehouse", at + Vector2(-10, 0))
	check(c.hire(farm, c.job_max(farm)) == c.job_max(farm), "explicit farm staff")
	check(c.hire(store, c.job_max(store)) == c.job_max(store), "explicit warehouse staff")
	var shop := place(c, "bakery", at)
	check(c.job_max(shop) == 3, "bakery has three slots")
	check(c.hired_of(shop) == 0 and float(shop["staff"]) == 0.0, "new shop has zero workers")
	check(not shop["active"] and int(shop.get("cap", -1)) == 0 and int(shop["served"]) == 0, "empty shop has zero coverage")
	game.people._assign_jobs()
	check(game.people.residents.all(func(r: Dictionary) -> bool: return int(r["job"]) != int(shop["id"])), "building never auto-hires")
	hud._do_click(hud.hire_do(shop))
	await frames(5)
	check(texts(hud.info_box).contains("свободно: %d" % int(c.stats["free"]["plebs"])), "empty card shows free workers")
	check(hud.info_box.find_child("worker_slots", true, false).get_child_count() == 3, "three visible slots")
	check(hud._do_target(hud.hire_do(shop)) == hud.info_box.find_child("hire_plus", true, false), "quest pointer targets plus")
	await shot("1_card_empty.png")
	var free_before := int(c.stats["free"]["plebs"])
	var nearest: Dictionary = {}
	for r: Dictionary in game.people.residents:
		if int(r["job"]) < 0 and not r["child"] and int(r["home"]) > 0:
			r["p"] = at + Vector2(60, 0)
			r["m"]["prof"] = "farmer"
			if nearest.is_empty():
				nearest = r
	if not check(not nearest.is_empty(), "free adult fixture"):
		_finish()
		return
	nearest["p"] = at + Vector2(0.5, 0)
	nearest["m"]["prof"] = "trader"
	var plus := hud.info_box.find_child("hire_plus", true, false) as Button
	plus.pressed.emit()
	await frames(5)
	check(c.hired_of(shop) == 1 and int(nearest["job"]) == int(shop["id"]), "plus hires nearest fitting free adult")
	check(int(c.stats["free"]["plebs"]) == free_before - 1, "one free adult consumed")
	var full_cap := int(Defs.CAPACITY[int(c.def(shop)["cap"])])
	check(is_equal_approx(float(shop["staff"]), (1.2 if Defs.PROF_ON else 1.0) / 3.0), "one fitting worker gives 1.2 of three slots")
	check(int(shop["cap"]) == ceili(float(full_cap) * (1.2 if Defs.PROF_ON else 1.0) / 3.0), "capacity includes fitting profession once")
	check(int(shop["served"]) <= int(shop["cap"]), "served houses obey capacity")
	hud._update_world_icons()
	check(not hud.world_icons.has(shop["id"]), "partial shop has no permanent badge")
	game._hover_building(shop)
	check(not hud.badges.has("work_partial"), "partial staff stays in card, no extra map badge")
	game._clear_highlight()
	check(not hud.badges.has("work_partial"), "partial badge clears off hover")
	await shot("2_card_partial.png")
	hud.refresh()
	await frames(5)
	var counter := hud.class_box.find_child("free_plebs", true, false) as Button
	check(counter != null and counter.text == "+%d" % int(c.stats["free"]["plebs"]), "topbar free matches adults")
	await shot("3_topbar_free.png")
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	var restored := City.new(Land.new())
	restored.load_data(snapshot)
	check(restored.manual_hiring() and restored.hired_of(restored.buildings[int(shop["id"])]) == 1, "save restores manual hire")
	check(int(restored.stats["free"]["plebs"]) == int(c.stats["free"]["plebs"]), "save restores free count")
	var minus := hud.info_box.find_child("hire_minus", true, false) as Button
	minus.pressed.emit()
	await frames(5)
	check(c.hired_of(shop) == 0 and int(nearest["job"]) < 0, "minus frees same worker")
	check(int(c.stats["free"]["plebs"]) == free_before, "free counter restored")
	check(int(shop["cap"]) == 0 and int(shop["served"]) == 0, "fire clears previous coverage")
	hud.close_panels()
	hud._update_world_icons()
	var badge: Dictionary = hud.badges.get("b%d" % shop["id"], {})
	check(badge.get("icon", "") == "no_workers" and bool(badge.get("warn", false)) and (badge["n"] as Control).tooltip_text.contains("Нет работников"), "red no-worker badge")
	await shot("4_badge_noworkers.png")
	# Новая семья заселяется, но не занимает ни одного пустого места.
	var arrival_home := place(c, "house_pleb", at + Vector2(25, 15))
	check(c.settled(int(arrival_home["id"]), 2, "Новые") == 2, "arrival settles")
	var family: Dictionary = arrival_home["families"][0]
	var newcomers: Array = game.people._make_family("Новые", 2, int(arrival_home["id"]), arrival_home["pos"], "plebs", family)
	game.people._assign_jobs()
	check(newcomers.all(func(r: Dictionary) -> bool: return int(r["job"]) < 0), "arrivals stay free")
	check(c.hired_of(shop) == 0 and int(c.stats["free"]["plebs"]) == free_before + 2, "arrivals do not fill player vacancies")
	c.stats["happy"] = 100
	c.settled_total = 20
	c.arrive_t = 99.0
	c._tick_arrivals()
	check(c.arrivals_blocked() == "", "work does not gate arrivals")
	# Нужный класс обязателен; плебеи не занимают места ремесленников.
	var artisan_shop := place(c, "taberna", at + Vector2(28, -10))
	check(not c.can_hire(artisan_shop) and c.hire(artisan_shop) == 0, "wrong class cannot hire")
	hud.open_info(artisan_shop)
	check(texts(hud.info_box).contains("Нет свободных горожан нужного класса"), "unavailable class explained")
	check((hud.info_box.find_child("hire_plus", true, false) as Button).disabled, "unavailable plus disabled")
	# Наука, сырьё и материалы: пусто = 0, половина/треть штата = та же доля.
	var script := place(c, "scriptorium", at + Vector2(12, -10))
	check(c.hire(script) == 1 and is_equal_approx(float(script["staff"]), 0.5), "research half staff")
	check(is_equal_approx(float(c.rp_sources().get("scriptorium", 0.0)), c.rp_per_hour("scriptorium") * 0.5), "research output half")
	c.fire(script)
	check(float(script["staff"]) == 0.0, "research stops empty")
	c.fire(farm, 99)
	check(not c.goods.has("wheat"), "empty field produces nothing")
	c.hire(farm)
	check(is_equal_approx(float(c.goods.get("wheat", 0.0)), (1.2 if Defs.PROF_ON else 1.0) / 3.0), "farmer output follows profession setting")
	var smelter := place(c, "smelter", at + Vector2(25, -25))
	check(is_zero_approx(c.legion.workshop_k("smelter")), "empty workshop has no minimum output")
	c.hire(smelter)
	check(c.hired_of(smelter) == 1, "workshop explicitly hired")
	check(is_equal_approx(c.legion.workshop_k("smelter"), float(smelter["staff"])), "materials follow staff")
	_model_edges()
	_legacy()
	_finish()


func _model_edges() -> void:
	var c := City.new(Land.new())
	c.cozy_v = 1
	c.level = 4
	var home := place(c, "house_pleb", Land.START)
	home["families"] = [{"name": "Плебеи", "n": 4, "m": [
		{"pn": "Первый", "sd": 1, "age": 1, "sx": 0}, {"pn": "Вторая", "sd": 2, "age": 1, "sx": 1},
		{"pn": "Ребёнок", "sd": 3, "age": 0, "sx": 0}, {"pn": "Ребёнок", "sd": 4, "age": 0, "sx": 1}]}]
	home["pop"] = 4
	var inn := place(c, "mansio", Land.START + Vector2(12, 0))
	check(int(c.stats["free"]["plebs"]) == 2, "children excluded from free adults")
	check(c.hire(inn, 10) == 2 and not c.can_hire(inn), "mixed slots do not turn plebs into artisans")
	var rich := place(c, "house_artisan", Land.START + Vector2(24, 0))
	rich["families"] = [{"name": "Мастера", "n": 2}]
	rich["pop"] = 2
	c.compute()
	check(c.hired_of(inn) == 2, "new class never auto-fills remaining slot")
	check(c.hire(inn) == 1 and int(c.jobs_of(inn).get("artisans", 0)) == 1, "mixed class slot explicitly hired")
	var before := c.hired_of(inn)
	# Пропавшего работника никто автоматически не заменяет, даже при наличии свободного взрослого.
	var members: Array = rich["families"][0]["m"]
	var worker: Dictionary = members[0] if int(members[0].get("job", -1)) >= 0 else members[1]
	members.erase(worker)
	rich["families"][0]["n"] = 1
	rich["pop"] = 1
	c.compute()
	check(c.hired_of(inn) == before - 1 and c.can_hire(inn), "departure leaves vacancy for player")
	check(c.hire(inn) == 1, "player replaces departed worker")
	# Временные расчёты перестройки не стирают назначения из записей людей.
	c.buildings.erase(int(home["id"]))
	c.compute()
	c.buildings[int(home["id"])] = home
	c.compute()
	check(c.hired_of(inn) == 3, "preview compute preserves staff")
	var old_id := int(inn["id"])
	c.moving_id = old_id
	c.remove(inn, false)
	var moved := place(c, "mansio", Land.START + Vector2(12, 12))
	moved["hire"] = 3
	c.moving_id = -1
	c.rehome(old_id, int(moved["id"]))
	c.compute()
	check(c.hired_of(moved) == 3, "moving workplace preserves named workers")
	check(c.fire(moved, 99) == 3 and c.hired_of(moved) == 0, "fire clamps to actual staff")


func _legacy() -> void:
	var c := City.new(Land.new())
	var home := place(c, "house_pleb", Land.START)
	home["pop"] = 8
	var shop := place(c, "stall_fruit", Land.START + Vector2(8, 0))
	check(c.cozy_v == 0 and c.hired_of(shop) == c.job_max(shop) and shop["active"], "legacy auto staffing")
	var ppl := People.new()
	ppl.city = c
	ppl.residents = [{"id": 1, "home": int(home["id"]), "child": false, "cls": "plebs", "p": home["pos"], "job": -1}]
	ppl._assign_jobs()
	check(int(ppl.residents[0]["job"]) == int(shop["id"]), "legacy People still auto assigns")
	ppl.free()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	saved.erase("cozy_v")
	var loaded := City.new(Land.new())
	loaded.load_data(saved)
	check(loaded.cozy_v == 0 and loaded.hired_of(loaded.buildings[int(shop["id"])]) == 1, "missing flag stays legacy")


func _finish() -> void:
	print("HIRE1 DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
