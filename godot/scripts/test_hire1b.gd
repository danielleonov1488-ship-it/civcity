extends Node3D
## Регресс HIRE1b: сохранение работы, обучение, просьбы и очередь советника.

var out := "D:/CivCity/.work/stage7/cityttc9b/shots/hire1b/"
var game: Game
var fails := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2 and pair[0] == "out":
			out = pair[1].trim_suffix("/") + "/"
	var profile := "D:/CivCity/.work/stage7/cityttc9b/profiles/hire1b_%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	if not check(DirAccess.make_dir_recursive_absolute(profile) == OK, "isolated profile directory"):
		_finish()
		return
	OS.set_environment("CIVCITY_SAVEDIR", profile)
	OS.set_environment("CIVCITY_NOMINPAUSE", "1")
	OS.set_environment("CIVCITY_HEROSCREEN", "0")
	GamePaths._dir = ""
	Game.boot = {"new": "1", "hour": "10", "nologin": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	game.can_save = false
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, why: String) -> bool:
	if not ok:
		fails += 1
		print("HIRE1B FAIL " + why)
	return ok


func shot(file: String) -> void:
	await frames(8)
	await RenderingServer.frame_post_draw
	if check(get_viewport().get_texture().get_image().save_png(out + file) == OK, "save " + file):
		print("HIRE1B SHOT " + out + file)


func place(c: City, type: String, pos: Vector2) -> Dictionary:
	var b := c.place(type, pos, 0.0, 0, 0, true)
	var door := c.door_point(b)
	c.land.paint_line(door - Vector2(3, 0), door + Vector2(3, 0), 2.0, Land.Kind.ROAD, true)
	c.compute()
	return b


func people_for(c: City) -> People:
	var ppl := People.new()
	ppl.city = c
	for home: Dictionary in c.buildings.values():
		if c.is_house(home):
			for family: Dictionary in home["families"]:
				ppl._make_family(family["name"], int(family["n"]), int(home["id"]), home["pos"], "", family)
	ppl._assign_jobs()
	return ppl


func jobs(c: City) -> Dictionary:
	var result := {}
	for w: Dictionary in c.workforce():
		result["%d:%d" % [int(w["home"]), int(w["m"]["sd"])]] = int(w["m"].get("job", -1))
	return result


func counts(c: City) -> Dictionary:
	var result := {}
	for b: Dictionary in c.buildings.values():
		if c.job_max(b) > 0:
			result[int(b["id"])] = c.hired_of(b)
	return result


func model(automatic: bool) -> City:
	var c := City.new(Land.new())
	c.cozy_v = 1
	c.auto_hire = automatic
	c.level = 4
	for i in 3:
		var home := place(c, "house_artisan" if i == 2 else "house_pleb", Land.START + Vector2(i * 10, 0))
		home["families"] = [{"name": "Проверка%d" % i, "n": 3, "m": [
			{"pn": "Первый", "sx": 0, "age": 1, "sd": i * 10 + 1},
			{"pn": "Вторая", "sx": 1, "age": 1, "sd": i * 10 + 2},
			{"pn": "Ребёнок", "sx": 0, "age": 0, "sd": i * 10 + 3}]}]
		home["pop"] = 3
	place(c, "bakery", Land.START + Vector2(0, 12))
	place(c, "scriptorium", Land.START + Vector2(12, 12))
	place(c, "stall_fruit", Land.START + Vector2(24, 12))
	c.compute()
	return c


func persistence() -> void:
	var c := model(false)
	for b: Dictionary in c.buildings.values():
		if b["type"] == "bakery":
			check(c.hire(b, 2) == 2, "partial bakery fixture")
		elif b["type"] == "scriptorium":
			check(c.hire(b) == 1, "scriptorium fixture")
	var expected := jobs(c)
	var hired := counts(c)
	var free: Dictionary = c.stats["free"].duplicate()
	for round_n in 2:
		var data: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
		check(not data.has("auto_hire"), "test override is not saved")
		var restored := City.new(Land.new())
		restored.load_data(data)
		check(restored.manual_hiring() and jobs(restored) == expected, "manual named jobs round %d" % round_n)
		check(counts(restored) == hired and restored.stats["free"] == free, "manual counts and vacancies round %d" % round_n)
		var ppl := people_for(restored)
		check(ppl.residents.all(func(r: Dictionary) -> bool: return int(r["job"]) == int(r["m"].get("job", -1))), "People uses restored assignments")
		ppl.sync_members()
		check(jobs(restored) == expected and counts(restored) == hired, "sync does not change restored jobs")
		ppl.free()
		c = restored
	# Прежняя фикстура: cozy_v=1, но hire=-1 и job_class ещё нет.
	c = model(true)
	var old_people := people_for(c)
	old_people.sync_members()
	expected = jobs(c)
	check(expected.values().count(-1) < expected.size(), "automatic fixture has real workers")
	var old_data: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	var restored := City.new(Land.new())
	restored.load_data(old_data)
	check(restored.manual_hiring() and jobs(restored) == expected, "negative hire restores existing named jobs")
	var new_people := people_for(restored)
	check(new_people.residents.all(func(r: Dictionary) -> bool: return int(r["job"]) == int(r["m"].get("job", -1))), "negative hire survives People setup")
	for b: Dictionary in old_data["buildings"]:
		b.erase("hire")
	var missing_hire := City.new(Land.new())
	missing_hire.load_data(old_data)
	check(missing_hire.manual_hiring() and jobs(missing_hire) == expected, "missing hire restores existing named jobs")
	# Старое настоящее сохранение: без cozy_v, без чисел найма и без назначений.
	for b: Dictionary in old_data["buildings"]:
		for family: Dictionary in b["families"]:
			for m: Dictionary in family["m"]:
				m.erase("job")
				m.erase("job_class")
	var legacy := City.new(Land.new())
	old_data["cozy_v"] = 0
	legacy.load_data(old_data)
	check(legacy.cozy_v == 0 and not legacy.manual_hiring(), "cozy_v=0 keeps automatic staffing")
	old_data.erase("cozy_v")
	legacy.load_data(old_data)
	check(legacy.cozy_v == 0 and not legacy.manual_hiring(), "missing cozy_v keeps automatic staffing")
	for b: Dictionary in legacy.buildings.values():
		check(legacy.hired_of(b) == legacy.job_max(b), "legacy workplace capacity")
	for b: Dictionary in legacy.buildings.values():
		b["road"] = true                       # фикстура без дорог: старый город считает здания у дороги
	var legacy_people := people_for(legacy)
	check(legacy_people.residents.any(func(r: Dictionary) -> bool: return int(r["job"]) >= 0), "legacy People automatically fills jobs")
	check(legacy_people.residents.all(func(r: Dictionary) -> bool: return not r["child"] or int(r["job"]) < 0), "legacy children never work")
	old_people.free()
	new_people.free()
	legacy_people.free()


func request_row(hud: Hud, text: String) -> Button:
	for row in hud.tasks_box.get_children():
		if row is MarginContainer:
			for label: Label in row.find_children("*", "Label", true, false):
				if label.text == text:
					for child in row.get_children():
						if child is Button:
							return child
	return null


func guidance(c: City, hud: Hud, shop: Dictionary, home: Dictionary) -> Dictionary:
	var tut: Tutorial = game.tutorial
	c.settled_total = 0
	check(not tut._check("settle"), "settlement waits for a choice of home")
	c.pending["Проверка"] = {"n": 2, "cls": "plebs", "home": int(home["id"]), "m": [
		{"pn": "Первый", "sx": 0, "age": 1, "sd": 1}, {"pn": "Вторая", "sx": 1, "age": 1, "sd": 2}]}
	check(tut._check("settle"), "assigned family completes settlement step")
	check(c.workforce().is_empty() and not c.can_hire(shop), "walking family is not available for hiring yet")
	if not check(c.settled(int(home["id"]), 2, "Проверка") == 2, "family arrives at home"):
		return {}
	var family: Dictionary = home["families"][0]
	game.people._make_family(family["name"], 2, int(home["id"]), home["pos"], "", family)
	tut._enter(Tutorial.step_index("house"))
	hud.open_info(home)
	tut._house_hint()
	check(not tut._check("house") and tut.next_btn.visible and not tut.next_btn.disabled, "house step waits for confirmation")
	tut.next_btn.pressed.emit()
	check(tut._wait > 0.0, "house confirmation advances tutorial")
	tut._enter(Tutorial.step_index("workers"))
	hud._update_pointer()
	check(not tut._check("workers"), "tutorial requires actual hire")
	var plus := hud._do_target(hud.hire_do(shop)) as Button
	if check(plus != null and hud.pointer_target == plus and not plus.disabled and plus.get_meta("hire_class", "") == "plebs" and plus.icon == CityStyle.icon("plus"), "tutorial points to the plebeian hire button"):
		plus.pressed.emit()
	check(tut._check("workers"), "real plus completes worker requirement")
	# Завершённое обучение; настройки и пользовательские сохранения не пишем.
	tut.step = Tutorial.STEPS.size()
	tut.card.hide()
	c.tips["tut"] = -1
	c.tips["ui"] = 3
	hud.apply_reveal(3)
	hud.close_panels()
	hud.advisor_panel.hide()
	c.goals_done = ["road1", "houses3"]
	c.goals_vis = 1
	c.tips["rank_pressed"] = true
	hud._ptr_shown = {}
	hud.refresh()
	var goals := c.active_goals(1)
	if not check(not goals.is_empty() and goals[0]["id"] == "fam3", "first request fixture"):
		return {}
	var first: Dictionary = goals[0]
	hud._update_pointer()
	check(hud.pointer_target == null, "early request has no automatic pointer")
	var request: Dictionary = hud._request_target(first)
	hud.show_pointer(request["do"])
	check(hud.pointer_target != null and hud.pointer_target == request["target"], "requested early pointer keeps priority")
	# Ненанятое здание само не открывается и не забирает стрелку просьбы.
	var empty := place(c, "scriptorium", Land.START + Vector2(38, 16))
	hud.close_panels()
	hud._update_pointer()
	check(not hud.info_panel.visible and hud.pointer_target != null and hud.pointer_target == request["target"], "unopened workplace never steals pointer")
	await shot("1_early_request.png")
	hud._ptr_shown = {}
	hud.open_info(empty)
	check(hud.pointer_target == null, "opened workplace has no automatic pointer")
	hud.show_pointer(hud.hire_do(empty))
	check(hud.pointer_target == hud._do_target(hud.hire_do(empty)) and hud.pointer_target != null, "requested hire points to plus")
	await shot("2_open_empty_card.png")
	check(c.hire(empty) == 1, "hire in opened card")
	hud._update_pointer()
	check(hud._do_target(hud.hire_do(empty)) == null, "partially staffed card does not point to plus")
	hud._ptr_shown = {}
	hud.close_panels()
	c.level = 1
	for goal: Dictionary in Defs.REQUESTS:
		if not c.goals_done.has(goal["id"]):
			c.goals_done.append(goal["id"])
		if goal["id"] == "hamlet":
			break
	game.settings["tasks_folded"] = false
	hud.refresh()
	await frames(5)
	hud._update_pointer()
	goals = c.active_goals(1)
	if not check(not goals.is_empty() and goals[0]["id"] == "scriptorium2", "hamlet request fixture"):
		return {}
	var goal: Dictionary = goals[0]
	check(hud.pointer_target == null, "hamlet does not show automatic request pointer")
	var row := request_row(hud, String(goal["text"]))
	if check(row != null and row.is_visible_in_tree(), "second scriptorium request row visible"):
		row.pressed.emit()
		await frames(5)
		check(hud.pointer_target != null and hud.pointer.visible, "request row click shows pointer")
	await shot("3_second_scriptorium_request.png")
	hud._ptr_shown = {}
	hud.close_panels()
	hud.advisor_panel.hide()
	return empty


func advice(c: City, hud: Hud, shop: Dictionary, scriptorium: Dictionary) -> void:
	game.set_tool("")
	var home := place(c, "house_artisan", Land.START + Vector2(49, 20))
	home["families"] = [{"name": "Мастера", "n": 2, "m": [
		{"pn": "Взрослый", "sx": 0, "age": 1, "sd": 3}, {"pn": "Ребёнок", "sx": 1, "age": 0, "sd": 4}]}]
	home["pop"] = 2
	c.compute()
	check(c.hired_of(shop) == c.job_max(shop) and c.hired_of(scriptorium) == 1 and c.can_hire(scriptorium, "artisans") and not c.can_hire(scriptorium, "plebs"), "filled first workplace and one artisan available for the next slot")
	# Оставляем только советы, чью очерёдность проверяем.
	hud.advisor_panel.hide()
	hud.guidance_queue.clear()
	hud._clear(hud.notes_box)
	game.settings["advisor_off"] = false
	hud._tip_next = 0
	c.tips.erase("manual_hire_tip")
	c.tips.erase("manual_hire_pending")
	c.tips.erase("unpaid_tip")
	c.tips["unhappy_penalty"] = true
	c.tips["want_advice"] = true
	c.unpaid_h = Defs.UNPAID_H
	c.money = 0
	hud.on_workplace_built(shop)
	check(not hud.advisor_panel.visible and c.tips.has("manual_hire_pending"), "building queues advice")
	hud._once_tips()
	check(hud.adv_title.text == "Казна пуста" and c.tips.has("unpaid_tip"), "urgent treasury tip wins")
	check(not c.tips.has("manual_hire_tip") and c.tips.has("manual_hire_pending"), "hire advice remains queued")
	await shot("4_urgent_advisor.png")
	hud._once_tips()
	check(hud.adv_title.text == "Казна пуста" and not c.tips.has("manual_hire_tip"), "visible advisor is not replaced")
	hud.advisor_panel.hide()
	hud.tip_gap = true
	hud._tip_next = Time.get_ticks_msec() + 30000
	hud._once_tips()
	check(not hud.advisor_panel.visible and not c.tips.has("manual_hire_tip"), "hire advice respects advisor gap")
	hud._tip_next = 0
	game.set_tool("house_pleb")
	hud._once_tips()
	check(not hud.advisor_panel.visible and c.tips.has("manual_hire_pending") and not c.tips.has("manual_hire_tip"), "hire advice waits while building")
	game.set_tool("")
	hud._once_tips()
	if not check(hud.advisor_panel.visible and hud.adv_title.text == "Работа в новом здании" and c.tips.has("manual_hire_tip") and hud.adv_show.visible, "hire advice opens with a Show action"):
		return
	await shot("5_hire_advisor.png")
	hud.adv_show.pressed.emit()
	await shot("6_advisor_hire_target.png")
	var next_plus := hud.pointer_target as Button
	var correct_target: bool = (hud.info_panel.visible and hud.info_b == scriptorium and hud.pointer.visible
			and next_plus != null and not next_plus.disabled and next_plus.get_meta("hire_class", "") == "artisans")
	if check(correct_target, "hire advice uses the available artisan plus in the partially staffed workplace"):
		next_plus.pressed.emit()
		check(c.hired_of(scriptorium) == 2 and int(c.stats["free"]["artisans"]) == 0, "highlighted plus fills the remaining slot")
	hud.on_workplace_built(scriptorium)
	check(not c.tips.has("manual_hire_pending") and not hud._manual_hire_advice(), "hire explanation is one time")


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
	game.tutorial.set_process(false)
	game.tutorial.step = Tutorial.STEPS.size()
	game.tutorial.card.hide()
	I18n.set_lang("ru")
	if not check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory"):
		_finish()
		return
	persistence()
	var c: City = game.city
	var hud: Hud = game.hud
	c.cozy_v = 1
	c.auto_hire = false
	c.level = 0
	c.money = 100000
	c.tips["tut"] = -1
	c.tips["ui"] = 3
	hud.apply_reveal(3)
	hud.close_panels()
	hud.advisor_panel.hide()
	var home := place(c, "house_pleb", Land.START + Vector2(12, 12))
	var shop := place(c, "stall_fruit", Land.START + Vector2(25, 12))
	game.rig.set_view(Vector3(210, Land.BASE_Y, 160), 20, 45, 48)
	var scriptorium := await guidance(c, hud, shop, home)
	if not scriptorium.is_empty():
		await advice(c, hud, shop, scriptorium)
	_finish()


func _finish() -> void:
	print("HIRE1B DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
