extends Node3D
## BAL1: модель баланса и карточки. Запускает Claude; сохранения игрока не пишем.

var out := "D:/CivCity/.work/stage2/bal1/shots/"
var game
var fails := 0


func check(ok: bool, reason: String) -> bool:
	if not ok:
		fails += 1
		print("BAL1 FAIL " + reason)
	return ok


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2 and pair[0] == "out":
			out = pair[1].trim_suffix("/") + "/"
	_model()
	if DisplayServer.get_name() == "headless":
		_finish()
		return
	Game.boot = {"new": "1", "hour": "10"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	game.can_save = false
	_run_ui()


func _town(n: int) -> City:
	var c := City.new(Land.new())
	c.cozy_v = 1
	c.econ = 1
	c.money = 1000000.0
	for i in n:
		var h := c.place("house_pleb", Land.START + Vector2(8.0 * (i % 8), 8.0 * (i / 8)), 0.0, 0, 0, true)
		if not check(not h.is_empty(), "town house %d" % i):
			continue
		h["pop"] = 4
		h["families"] = [{"name": "Проба%d" % i, "n": 4, "cls": "plebs"}]
	c.compute()
	return c


func _road(c: City, b: Dictionary) -> void:
	var door := c.door_point(b)
	c.land.paint_line(door - Vector2(3, 0), door + Vector2(3, 0), 2.0, Land.Kind.ROAD, true)


func _model() -> void:
	var c := _town(4)
	var h: Dictionary = c.buildings.values()[0]
	var shops := ["weaver", "dice", "potter"]
	var scores := {}
	for i in shops.size():
		scores[shops[i]] = int(Defs.B[shops[i]]["bonus"])
		var shop := c.place(shops[i], Land.START + Vector2(-8 + i * 8, -10), 0.0, 0, 0, true)
		if check(not shop.is_empty(), "shop fixture %s" % shops[i]):
			_road(c, shop)
			c.hire(shop, c.job_max(shop))
	c.compute()
	for type: String in shops:
		check((h["score"] as Dictionary).has(type), "working nearby shop counted in coverage: " + type)
		for part: Array in h["happy_parts"]:
			check(not String(part[0]).begins_with(String(Defs.B[type]["name"])), "plebs card excludes " + type)
	check(not (h["missing"] as Array).has("faith"), "faith is not required at rank zero")
	c.level = 2
	c.compute()
	check((h["missing"] as Array).has("faith"), "unrelated shops do not cover faith from rank two")
	c.level = 0
	c.compute()
	check((h["missing"] as Array).has("food"), "non-food shops do not feed plebs")
	check(City.shop_parts(shops, scores, 1, "plebs").is_empty(), "plebs get no clothes, fun or goods bonus")
	check(City.shop_parts(shops, scores, 1, "artisans").size() == 2, "artisans count clothes and fun only")
	check(City.shop_parts(shops, scores, 1, "patricians").size() == 3, "patricians count all three categories")
	check(City.shop_parts(shops, scores, 1).size() == 3, "legacy shop calculation stays unfiltered")
	check(c.base_happy("plebs") == 44 and c.base_happy("artisans") == 40 and c.base_happy("patricians") == 38, "new base happiness")
	check(c.missing_penalty() == 8 and c.arrive_happy() == 45, "rank zero threshold 45, missing penalty 8")
	# Перестройка начинает учитывать нужные новому классу лавки, не теряет их бонусы.
	c.research["artisans"] = true
	var predicted := c.upgrade_happy(h)
	h["type"] = "house_artisan"
	c.compute()
	var actual := 0
	for part: Array in h["happy_parts"]:
		actual += int(part[1])
	check(predicted == actual, "upgrade preview matches recomputed happiness: %d / %d" % [predicted, actual])
	h["type"] = "house_pleb"
	c.cozy_v = 0
	c.compute()
	check(c.base_happy("plebs") == 44 and c.missing_penalty() == 10 and c.arrive_happy() == 60, "legacy happiness rules")
	c.research["reach1"] = true
	check(is_equal_approx(c.shop_range(Defs.B["stall_fruit"]), Defs.range_m(Defs.B["stall_fruit"]) * 1.33), "legacy food range")
	c.cozy_v = 1
	check(is_equal_approx(c.shop_range(Defs.B["stall_fruit"]), Defs.range_m(Defs.B["stall_fruit"]) * 1.2), "new food range")
	_arrivals()
	_upkeep()
	_ranks()


func _arrivals() -> void:
	var c := _town(10)
	c.place("center", Land.START + Vector2(-20, -20), 0.0, 0, 0, true)
	var empty := c.place("house_pleb", Land.START + Vector2(-16, 0), 0.0, 0, 0, true)
	check(not empty.is_empty(), "empty arrival home")
	c.level = 2
	c.settled_total = 10
	c.compute()
	c.stats["happy"] = 90
	c.arrive_t = 99.0
	c._tick_arrivals()
	check(c.incoming > 0 and c.arrivals_blocked() == "", "unemployment never blocks a happy city")
	c.stats["free"] = {"plebs": 1000}
	check(c.arrivals_blocked() == "", "many free adults do not block arrivals")
	c.level = 0
	c.stats["pop"] = 14
	c.stats["free"] = {"plebs": 7}
	c.stats["happy"] = 20
	check(c.arrivals_blocked() == "", "starter cannot be trapped before 15 residents")
	c.stats["pop"] = 20
	c.stats["free"] = {"plebs": 0}
	c.stats["happy"] = 44
	check(c.arrivals_blocked().contains("45%"), "rank zero blocks at 44 and prints threshold 45")
	c.stats["happy"] = 45
	check(c.arrivals_blocked() == "", "rank zero allows at 45")
	for rank in 8:
		c.level = rank
		check(c.arrive_happy() == int(Defs.ARRIVE_HAPPY_LVL[rank]), "threshold rank %d" % rank)
	c.cozy_v = 0
	c.stats["happy"] = 90
	c.stats["free"] = {"plebs": 50}
	check(c.arrivals_blocked() == "", "legacy ignores unemployment")


func _upkeep() -> void:
	for version in [0, 1]:
		var c := _town(10)
		c.cozy_v = version
		var wanted := 10.0 * float(Defs.B["house_pleb"]["cost"]) * 0.006 * 0.5 if version == 1 else 0.0
		c.sim_day()
		check(is_equal_approx(float(c.stats["upkeep"]), wanted), "houses upkeep version %d: %.3f / %.3f" % [version, float(c.stats["upkeep"]), wanted])
		check(int(c.hist_series("upkeep")[-1]) == -roundi(wanted), "house upkeep included in finance history")
		check(is_equal_approx(c.upkeep_rate(), 0.006 if version == 1 else 0.005), "upkeep rate version %d" % version)


func _ranks() -> void:
	var pops := [15, 40, 80, 140, 230, 350, 500]
	for i in pops.size():
		check(int(Balance.LEVELS[i + 1]["pop"]) == pops[i], "population rank %d" % (i + 1))
	for id: String in ["theatre", "academy"]:
		check(int(Defs.research(id)["lvl"]) == 6 and int(Balance.LEVELS[6]["pop"]) == 350, id + " research available at 350")
	for type: String in ["colosseum", "pantheon", "pharos", "circus_fl"]:
		# Ключи построек проверяем отдельно от названий исследований.
		if not check(Defs.B.has(type), "late building " + type):
			continue
		var id := String(Defs.B[type].get("unlock", ""))
		check(int(Defs.research(id).get("lvl", -1)) == 7 and int(Balance.LEVELS[7]["pop"]) == 500, type + " research available at 500")


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func texts(node: Node) -> String:
	var result := ""
	if node is Label or node is Button:
		result += String(node.text) + "\n"
	for child in node.get_children():
		result += texts(child)
	return result


func shot(file: String) -> void:
	await frames(12)
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(out + file)
	if check(error == OK, "save " + file):
		print("BAL1 SHOT " + out + file)


func _run_ui() -> void:
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
	game.speed = 0.0
	I18n.set_lang("ru")
	game.tutorial.step = Tutorial.STEPS.size()
	game.tutorial.card.visible = false
	game.tutorial.set_process(false)
	game.hud.apply_reveal(3)
	game.hud.close_panels()
	game.hud.advisor_panel.visible = false
	if not check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory"):
		_finish()
		return
	var c: City = game.city
	var hud: Hud = game.hud
	c.cozy_v = 1
	c.money = 1000000.0
	c.level = 2
	c.settled_total = 12
	var station := c.center()
	if station.is_empty():
		station = c.place("center", Land.START, 0.0, 0, 0, true)
	for i in 12:
		var h := c.place("house_pleb", Land.START + Vector2(18 + (i % 4) * 8, (i / 4) * 8), 0.0, 0, 0, true)
		if check(not h.is_empty(), "UI house"):
			h["pop"] = 4
			h["families"] = [{"name": "Квинты%d" % i, "n": 4, "cls": "plebs"}]
	c.compute()
	game.rig.set_view(Vector3(station["pos"].x, station["y"], station["pos"].y), 20, 38, 30)
	hud.open_info(station)
	check(not texts(hud.info_box).contains("нет свободной работы"), "station has no work gate")
	await shot("1_station_work.png")
	hud.close_panels()
	hud.set_overlay("happy")
	hud.fill_overlay()
	check(not texts(hud._ov_legend).contains("нет свободной работы"), "overview has no work gate")
	await shot("2_overview_work.png")
	hud.set_overlay("")
	c.sim_day()
	hud.close_panels()
	hud._fill_finance()
	hud.finance_panel.visible = true
	check(texts(hud.finance_panel).contains("Содержание построек за час") and texts(hud.finance_panel).contains("Дома: 0,3%"), "finance includes and explains house upkeep")
	await shot("3_house_upkeep.png")
	hud.close_panels()
	var house: Dictionary = {}
	for b: Dictionary in c.buildings.values():
		if c.is_house(b):
			house = b
			break
	if check(not house.is_empty(), "house card fixture"):
		var shops := ["weaver", "dice", "potter"]
		for i in shops.size():
			var shop := c.place(shops[i], (house["pos"] as Vector2) + Vector2(-8 + i * 8, -10), 0.0, 0, 0, true)
			if check(not shop.is_empty(), "UI shop"):
				_road(c, shop)
			c.hire(shop, c.job_max(shop))
		c.compute()
		hud.house_more = true
		hud.open_info(house)
		for type: String in shops:
			check(not texts(hud.info_box).contains(String(Defs.B[type]["name"])), "house card hides unneeded " + type)
		await shot("4_house_bonus.png")
	_finish()


func _finish() -> void:
	print("BAL1 DONE fails=%d" % fails)
	get_tree().quit(0 if fails == 0 else 1)
