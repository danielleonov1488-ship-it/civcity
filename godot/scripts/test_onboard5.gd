extends Node3D
## ONBOARD5: семьи, карточки, найм, исследования и короткий совет о ранге.
## Godot запускает проверяющий; профиль и снимки изолированы от сохранений игрока.

const ROOT := "D:/CivCity/.work/stage5/onboard5/"
var out := ROOT + "shots/"
var game: Game
var city: City
var hud: Hud
var fails := 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--savedir=") or arg.trim_prefix("--").begins_with("sandbox="):
			check(false, "run without savedir or sandbox overrides")
			_finish()
			return
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=").trim_suffix("/") + "/"
	var profile := ROOT + "profiles/run_%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	if not check(DirAccess.make_dir_recursive_absolute(profile) == OK, "profile directory"):
		_finish()
		return
	OS.set_environment("CIVCITY_SAVEDIR", profile)
	OS.set_environment("CIVCITY_NOLOGIN", "1")
	OS.set_environment("CIVCITY_NOMINPAUSE", "1")
	OS.set_environment("CIVCITY_HEROSCREEN", "0")
	if not check(GamePaths.save_dir().simplify_path() == profile.simplify_path(), "isolated profile"):
		_finish()
		return
	Game.sandbox = false
	Game.boot = {"new": "1", "hour": "10", "nologin": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	game.can_save = false
	add_child(game)
	game.can_save = false
	_run()


func _process(_dt: float) -> void:
	if is_instance_valid(game):
		game.can_save = false


func frames(n: int = 8) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, why: String) -> bool:
	if not ok:
		fails += 1
		print("ONBOARD5 FAIL " + why)
	return ok


func shot(file: String) -> void:
	await frames(12)
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(out + file)
	if check(error == OK, "save " + file):
		print("ONBOARD5 SHOT " + out + file)


func place(type: String, at: Vector2) -> Dictionary:
	var b := city.place(type, at, 0.0, 0, 0, true)
	if check(not b.is_empty(), "place " + type):
		var door := city.door_point(b)
		city.land.paint_line(door - Vector2(3, 0), door + Vector2(3, 0), 2.0, Land.Kind.ROAD, true)
		city.compute()
	return b


func _run() -> void:
	var waited := 0
	while not game.ready_done:
		await frames(5)
		waited += 5
		if not check(waited < 18000, "ready_done timeout"):
			_finish()
			return
	game.settings["autosave"] = false
	game.settings["advisor_off"] = true
	game.speed = 0.0
	game.build_anim = false
	game.tutorial.step = Tutorial.STEPS.size()
	game.tutorial.card.hide()
	game.tutorial.set_process(false)
	I18n.set_lang("ru")
	city = game.city
	hud = game.hud
	city.cozy_v = 1
	city.auto_hire = false
	city.tips["tut"] = -1
	hud.guidance_queue.clear()
	hud._clear(hud.notes_box)
	city.tips["ui"] = 3
	city.money = 100000
	hud.apply_reveal(3)
	hud.close_panels()
	hud.advisor_panel.hide()
	if not check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory"):
		_finish()
		return
	await _families()
	if not await _cards():
		_finish()
		return
	await _research()
	await _ranks()
	_finish()


func _families() -> void:
	city.set_arrivals_paused(true)
	# Три семьи, девять людей: счётчик должен показывать именно три.
	for i in 3:
		var family := city.new_family("plebs")
		family["n"] = i + 2
		city.family_arrived(family, false)
		game.people._on_resident_returned(city.arrival(String(family["name"])))
	city.compute()
	hud.refresh()
	hud._family_badge_next_ms = 0
	hud._family_badges()
	await frames(40)
	var station := city.center()
	var p: Vector2 = station["pos"]
	game.rig.set_view(Vector3(p.x, float(station["y"]) + 1, p.y), 20, 38, 30)
	var count := hud.fam_box.find_child("WaitingFamilyCount", true, false) as Label
	check(count != null and count.text == "3" and count.tooltip_text == "3 семьи ждут жилья", "family total and units")
	check(hud.fam_box.find_children("*", "Button", true, false).size() == 3, "each family remains selectable")
	check(not hud.badges.has("b%d" % int(station["id"])), "no duplicate roof badge while arrivals paused")
	var badge_count := 0
	for key: String in hud.badges:
		if key.begins_with("fam_"):
			badge_count += 1
	check(badge_count == 3, "one map badge per waiting family")
	for family: Dictionary in city.arrivals:
		var key := "fam_" + String(family["name"])
		check(hud.badges.has(key), "family badge " + String(family["name"]))
		hud._badge_click(key)
		check(game.tool == "settle" and game.settle_fam.get("name", "") == family["name"], "badge starts settlement for its own family")
		game.set_tool("")
	hud.close_panels()
	await shot("01_waiting_families.png")


func _cards() -> bool:
	var at := Land.START + Vector2(22, 8)
	var home := place("house_pleb", at + Vector2(-12, 12))
	if home.is_empty():
		return false
	var family := city.new_family("plebs")
	family["n"] = 3
	home["families"] = [family]
	home["pop"] = 3
	game.people._make_family(String(family["name"]), 3, int(home["id"]), city.door_point(home), "plebs", family)
	city.compute()
	hud.refresh()
	hud.open_info(home)
	await frames()
	var occupancy := hud.info_box.find_child("HouseOccupancy", true, false) as Label
	check(occupancy != null and occupancy.text == "3/4" and occupancy.tooltip_text == "жителей / мест", "residents / capacity instead of unlabelled floors")
	await shot("02_house_card.png")
	var types := {"plebs": "stall_fruit", "artisans": "taberna", "patricians": "theatre"}
	var fruit: Dictionary = {}
	var i := 0
	for cls: String in Defs.CLASS_ORDER:
		var b := place(String(types[cls]), at + Vector2(i * 14, -12))
		if b.is_empty():
			return false
		i += 1
		hud.open_info(b)
		await frames()
		var free := hud.info_box.find_child("hire_free_" + cls, true, false) as Label
		var row := hud.info_box.find_child("hire_class_" + cls, true, false) as HBoxContainer
		check(free != null and free.text == "свободно: %d" % int(city.stats["free"][cls]), "free workers for " + cls)
		check(row != null and row.get_child(0) is TextureRect and (row.get_child(0) as TextureRect).texture == CityStyle.icon(String(CityStyle.CLASS_ICON[cls])) and row.tooltip_text == Defs.CLASSES[cls]["name"], "required class icon for " + cls)
		if cls == "plebs":
			fruit = b
		else:
			check((hud.info_box.find_child("hire_plus", true, false) as Button).disabled, "wrong class remains unavailable: " + cls)
	hud.open_info(fruit)
	hud._update_pointer()
	await frames()
	var plus := hud.info_box.find_child("hire_plus", true, false) as Button
	if not check(plus != null, "hire plus exists"):
		return false
	check(hud.pointer_target == null and not hud.pointer.visible, "no automatic hire pointer after tutorial")
	hud.show_pointer(hud.hire_do(fruit))
	await frames()
	check(hud._do_target(hud.hire_do(fruit)) == plus and hud.pointer_target == plus, "requested hire pointer targets actual plus")
	var rect := plus.get_global_rect()
	check(hud.pointer.visible and is_equal_approx(hud.pointer.rotation, -PI / 2.0) and absf(hud.pointer.position.x + 31 - rect.position.x) < 1 and absf(hud.pointer.position.y + 16 - rect.get_center().y) < 1, "arrow tip touches plus from left without bobbing")
	check(hud.pointer_text.get_global_rect().end.x <= hud.info_panel.get_global_rect().position.x - 6, "hire caption outside card")
	await shot("03_hire_pointer.png")
	var before := int(city.stats["free"]["plebs"])
	plus.pressed.emit()
	await frames()
	check(city.hired_of(fruit) == 1 and int(city.stats["free"]["plebs"]) == before - 1, "plus hires one free worker")
	check((hud.info_box.find_child("hire_free_plebs", true, false) as Label).text == "свободно: %d" % (before - 1), "free count refreshes after hire")
	check(hud._do_target(hud.hire_do(fruit)) == null, "first-hire pointer clears after hire")
	await shot("04_hired.png")
	return true


func _research() -> void:
	hud.close_panels()
	city.rp = 6
	hud.refresh()
	# Прямой показ окна — тот же путь, что в туре, без _top_action.
	hud.research_panel.show()
	hud.research_tree.refresh()
	await frames()
	check(hud.lbl_research_rp.text == hud.lbl_rp.text and hud.lbl_research_rp.text == "6 / 250", "direct show matches topbar")
	await shot("05_research.png")
	city.rp = 17
	city.changed.emit()
	await frames()
	check(hud.lbl_research_rp.text == hud.lbl_rp.text, "visible research points refresh")
	hud.research_panel.hide()
	city.rp = 19
	city.changed.emit()                    # верхняя полоса тоже узнаёт о новых очках
	hud._top_action("research")
	await frames()
	check(hud.lbl_research_rp.text == hud.lbl_rp.text and hud.lbl_research_rp.text == "19 / 250", "button open matches topbar")
	hud.close_panels()


func _ranks() -> void:
	game.settings["advisor_off"] = false
	for rank in [1, 2]:
		city.level = rank
		var station := city.center()
		station["tier"] = rank
		game._show(station)
		city.compute()
		I18n.set_lang("ru" if rank == 1 else "en")
		hud.refresh()
		hud.advisor_panel.hide()
		game.rank_cine._advise(rank)
		await frames()
		var text := hud.adv_text.text
		check(hud.advisor_panel.visible and text.count(".") == 2 and not text.contains("\n") and text.length() < 230, "two short rank sentences")
		check(not text.contains(city.rank_text(rank + 1)), "rank conditions remain in city panel")
		if rank == 1:
			check(text.contains("Условия следующего уровня — в табличке города слева вверху."), "next rank points to city plaque")
		else:
			check(text.contains("top left") and text.contains("Research unlocked:"), "English rank advice")
		await shot("06_rank_hamlet_ru.png" if rank == 1 else "07_rank_village_en.png")
	I18n.set_lang("ru")


func _finish() -> void:
	print("ONBOARD5 DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
