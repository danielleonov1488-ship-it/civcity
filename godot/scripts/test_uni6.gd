extends "res://scripts/test_uni6_support.gd"
## Шесть городских окон, найм без профессий и дополнительные городские панели.


func _ready() -> void:
	if not await boot_run("UNI6", "D:/CivCity/.work/stage5/uni6/shots/"):
		finish_run()
		return
	await run()
	finish_run()


func run() -> void:
	no_profession_preference()
	game.tutorial.finish()
	game.tutorial.set_process(false)
	clear_guidance()
	game.settings["advisor_off"] = true
	city.level = 5
	city.research["floor2"] = true
	city.research["artisans"] = true
	var home := place("house_pleb", Land.START + Vector2(-12, 16))
	if home.is_empty():
		return
	home["families"] = [{"name": "Юлии", "n": 4, "cls": "plebs"}]
	home["pop"] = 4
	Residents.fit(home["families"][0], 42, "plebs")
	# Старые ключи оставлены в сохранении; они не дают бонус и не рисуют значки.
	for m: Dictionary in home["families"][0]["m"]:
		m["prof"] = "scholar"
	city.compute()
	hud.open_info(home)
	await frames()
	inspect_panel(hud.info_panel)
	await shot("01_house.png")
	var work := place("scriptorium", Land.START + Vector2(12, 16))
	if work.is_empty():
		return
	check(city.hire(work) == 1, "hire ordinary citizen")
	home["happy"] = 40.0
	city.compute()
	var full := 1.0 / city.job_max(work)
	check(not Defs.PROF_ON and int(work["staff_count"]) == 1 and is_equal_approx(float(work["staff"]), full), "old profession gives no 20 percent bonus")
	home["happy"] = 39.0
	city.compute()
	check(int(work["staff_count"]) == 1 and is_equal_approx(float(work["staff"]), full * 0.5), "below 40 halves output, not the number of workers")
	home["happy"] = 40.0
	city.compute()
	hud.open_info(work)
	await frames()
	inspect_panel(hud.info_panel)
	inspect_slots()
	await shot("02_building.png")
	hud._top_action("research")
	await frames()
	inspect_panel(hud.research_panel)
	await shot("03_research.png")
	var tree = hud.research_tree
	for tier: int in tree.rank_tabs:
		tree.select_rank(tier)
		await frames(2)
		inspect_panel(hud.research_panel)
	# После обхода рангов целевое знание надо сначала вернуть в видимую страницу.
	tree.reveal("deco_flowers")
	await frames()
	(tree.cards["deco_flowers"] as Control).mouse_entered.emit()
	await frames()
	inspect_panel(tree.popup)
	hud.close_panels()
	check(not tree.popup.visible, "research popup closes with window")
	var magis := MagisUI.attach(hud)
	magis.open()
	await frames()
	check(magis.cards.size() == 18, "eighteen edicts without scroll")
	check(magis.find_children("*", "ScrollContainer", true, false).is_empty(), "magistracies have no scroll")
	inspect_panel(magis.frame)
	for card: Button in magis.cards.values():
		check(magis.frame.get_global_rect().encloses(card.get_global_rect()), "edict inside window")
	await shot("04_magistracy.png")
	magis._popup("cens_artisan_charter")
	await frames()
	inspect_panel(magis.popup_panel)
	magis.close()
	Tutorial.start_new(city)
	game.tutorial._enter(Tutorial.step_index("workers"))
	# На этом шаге нужна лавка, поэтому показываем реальный городской объект.
	var shop := place("stall_fruit", Land.START + Vector2(12, 28))
	if shop.is_empty():
		return
	hud.open_info(shop)
	hud._update_pointer()
	await frames()
	game.tutorial.layout()
	inspect_panel(game.tutorial.card)
	check(game.tutorial.card.size.x <= 420.0, "tutorial width")
	check(not game.tutorial.card.get_global_rect().intersects(hud.pointer_target.get_global_rect()), "tutorial clears hire target")
	await shot("05_tutorial.png")
	game.tutorial.finish()
	clear_guidance()
	hud._hide_info()
	hud.advisor("Работа в новом здании", "Выберите класс и нажмите «+». Чтобы уволить работника, нажмите на его портрет.", Callable(), true, false, hud.hire_do(shop))
	await frames()
	check(hud.advisor_panel.size.x <= 520.0 and hud.adv_show.visible, "advisor width and show target")
	inspect_panel(hud.advisor_panel)
	await shot("06_advisor.png")
	hud.adv_show.pressed.emit()
	await frames()
	check(hud.info_panel.visible and hud.info_b == shop and hud.pointer_target == hud.info_box.find_child("hire_plus", true, false), "advisor Show leads to plus")
	hud.close_panels()
	for tab: String in ["city", "money", "people", "events"]:
		hud._open_overview(tab)
		await frames()
		inspect_panel(hud.overview_panel)
		hud.close_panels()
	city.arrivals.append({"name": "Клавдии", "n": 3, "cls": "plebs"})
	hud._fill_families()
	await frames()
	inspect_panel(hud.fam_box)
	hud.open_info(city.center())
	await frames()
	inspect_panel(hud.info_panel)


## Ближняя семья без подходящей профессии выигрывает у дальней с подходящей.
func no_profession_preference() -> void:
	if Defs.PROF_ON:
		return
	var c := City.new(Land.new())
	c.cozy_v = 1
	c.auto_hire = false
	c.money = 100000.0
	c.level = 5
	var shop := c.place("stall_fruit", Land.START, 0.0, 0, 0, true)
	for index in 2:
		var h := c.place("house_pleb", Land.START + Vector2(12 + index * 24, 12), 0.0, 0, 0, true)
		if not check(not h.is_empty(), "preference home fixture"):
			return
		h["families"] = [{"name": "Юлии" if index == 0 else "Клавдии", "n": 2, "cls": "plebs"}]
		h["pop"] = 2
		for m: Dictionary in Residents.fit(h["families"][0], 50 + index, "plebs"):
			m["prof"] = "farmer" if index == 0 else "trader"
		var dp: Vector2 = c.door_point(h)
		c.land.paint_line(dp - Vector2(3, 0), dp + Vector2(3, 0), 2.0, Land.Kind.ROAD, true)
	if not check(not shop.is_empty(), "preference shop fixture"):
		return
	var door: Vector2 = c.door_point(shop)
	c.land.paint_line(door - Vector2(3, 0), door + Vector2(3, 0), 2.0, Land.Kind.ROAD, true)
	c.compute()
	check(c.hire(shop) == 1, "preference hire succeeds")
	var staff := c.staff_members(shop)
	check(staff.size() == 1 and String(staff[0]["family"]) == "Юлии", "profession does not beat distance")
