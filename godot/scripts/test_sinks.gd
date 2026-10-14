extends Node
## Траты этапа 1b: праздник «Игры в честь богов» и земля новой игры.
##   bash .work/py/gpu_run.sh res://test_sinks.tscn   — в конце «SINKS DONE fails=0»; снимки — .work/gd/sinks_*.png
## Земля: новая игра — свои участки x 2–3, z 1–3 (x 128–256, z 64–256 м), цена k-го купленного 6000 × 1,3^(k−1) до
## тысяч, счётчик купленных в сохранении (у старых сохранений — сверх 16); готовый город меню — как был.
## Праздник: с «Посёлка», 3 ден. за жителя, сутки +8% счастья всем домам и повозка ×0,7, снова — через 48 ч;
## сохраняется; карточка станции, советник один раз, наряд города (шесты, знамёна, гирлянды) и толпа у станции.

const STREETS := [[Vector2(172, 136), Vector2(198, 136)], [Vector2(172, 150), Vector2(198, 150)], [Vector2(172, 164), Vector2(198, 164)]]
const PRICES := [6000, 8000, 10000, 13000, 17000, 22000, 29000, 38000, 49000, 64000, 83000]

var game
var c                                # City
var fails := 0
var cands: Array = []


func _ready() -> void:
	Game.boot = {"new": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, what: String) -> void:
	print(("SINKS PASS " if ok else "SINKS FAIL ") + what)
	if not ok:
		fails += 1


func shot(name: String) -> void:
	await frames(6)
	DirAccess.make_dir_recursive_absolute("D:/CivCity/.work/gd")
	get_viewport().get_texture().get_image().save_png("D:/CivCity/.work/gd/" + name)
	print("SHOT ", name)


func reset() -> void:
	game.last_snap_n = Vector2.ZERO
	game.last_snap_p = Vector2.INF
	game.manual_yaw = false
	game.yaw_set = false
	game.place_lock = {}
	game.tool_yaw = 0.0
	game.snap = true


func street(a: Vector2, b: Vector2) -> void:
	var ch: Array = game.land.paint_line(a, b, 1.3, Land.Kind.ROAD, true)
	c.road_cells += ch.size()
	game.people.refresh(game.land.road_chunks.keys())
	var dir := (b - a).normalized()
	var side := Vector2(-dir.y, dir.x)
	for i in int(a.distance_to(b)) + 1:
		for s in [-3.2, 3.2]:
			cands.append(a + dir * i + side * s)


func put(type: String, target: Vector2) -> Dictionary:
	cands.sort_custom(func(p, q): return p.distance_squared_to(target) < q.distance_squared_to(target))
	for p in cands.slice(0, 300):
		reset()
		var pl: Dictionary = game.placement(type, p)
		if pl["err"] == "" and pl["sub"] == "road":
			return c.place(type, pl["pos"], pl["yaw"], pl["variant"], pl["color"])
	return {}


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	c = game.city
	game.can_save = false
	game.speed = 0.0
	game.tutorial.step = Tutorial.STEPS.size()
	game.tutorial.card.visible = false
	c.tips["tut"] = -1
	c.tips["ui"] = 3
	game.hud.apply_reveal(3)
	await frames(5)
	await _land()
	await _festival()
	print("SINKS DONE fails=%d" % fails)
	get_tree().quit()


# ---------- земля ----------

func _land() -> void:
	var L: Land = game.land
	var own := L.owned.keys()
	own.sort()
	check(own == [Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3)], "new game owns plots x 2–3, z 1–3: %s" % [own])
	# все точки тестов (x 150–214, z 104–230) и обучения у станции — на своей земле
	var inside := true
	for p: Vector2 in [Vector2(150, 104), Vector2(214, 104), Vector2(150, 230), Vector2(214, 230), Land.CENTER, Land.START, Vector2(192, 126), Vector2(129, 65), Vector2(255, 255)]:
		inside = inside and L.is_owned(p)
	check(inside, "test and tutorial coordinates are on own land")
	check(not L.is_owned(Vector2(120, 150)) and not L.is_owned(Vector2(260, 150)) and not L.is_owned(Vector2(192, 260)), "outside x 128–256, z 64–256 is not owned")
	c.money = 3000.0
	var e: String = c.check_place("house_pleb", Vector2(110, 150), 0.0)["err"]
	check(e == "Эта земля ещё не куплена", "building outside: «%s»" % e)
	# цены участков: k-й купленный — 6000 × 1,3^(k−1), до тысяч
	var got := []
	for k in PRICES.size():
		c.plots_bought = k
		got.append(c.plot_price())
	c.plots_bought = 0
	check(got == PRICES, "plot prices %s" % [got])
	check(game.plot_signs.size() == 10, "for-sale signs around the 2×3 land: %d" % game.plot_signs.size())
	check(c.can_buy(Vector2i(4, 2)) and c.can_buy(Vector2i(1, 1)) and not c.can_buy(Vector2i(0, 2)) and not c.can_buy(Vector2i(4, 4)), "only plots next to own land are for sale")
	c.money = 5000.0
	check(not c.buy_plot(Vector2i(4, 2)), "not enough money: plot not bought")
	c.money = 20000.0
	check(c.buy_plot(Vector2i(4, 2)) and is_equal_approx(c.money, 14000.0) and c.plots_bought == 1 and c.plot_price() == 8000, "first plot 6000, next 8000 (money %d)" % int(c.money))
	game._update_plot_signs()
	check(game.plot_signs.size() == 10 and not game.plot_signs.has(Vector2i(4, 2)) and game.plot_signs.has(Vector2i(5, 2)), "signs moved: %d" % game.plot_signs.size())
	e = c.check_place("house_pleb", Vector2(290, 150), 0.0)["err"]
	check(e != "Эта земля ещё не куплена", "bought land can be built on: «%s»" % e)
	# сохранение: счётчик купленных едет в файле; старое сохранение (без счётчика) — купленные сверх 16
	var d: Dictionary = c.save_data()
	var ld: Dictionary = L.save_changes()
	check(int(d.get("plots_bought", -1)) == 1 and (ld["plots"] as Array).size() == 7, "saved: plots_bought 1, 7 plots")
	var c2 := City.new(L)
	c2.load_data(d)
	check(c2.plots_bought == 1 and c2.plot_price() == 8000, "loaded: plots_bought %d" % c2.plots_bought)
	var old := d.duplicate(true)
	old.erase("plots_bought")
	var keep: Dictionary = L.owned.duplicate()
	var plots := []
	for j in range(1, 5):
		for i in range(1, 5):
			plots.append([i, j])
	plots.append([0, 2])
	plots.append([5, 3])
	L.load_changes({"plots": plots})
	var c3 := City.new(L)
	c3.load_data(old)
	check(L.owned.size() == 18 and c3.plots_bought == 2 and c3.plot_price() == 10000, "old save with 18 plots: 2 bought, next 10000 (%d)" % c3.plot_price())
	plots.resize(16)
	L.load_changes({"plots": plots})
	var c4 := City.new(L)
	c4.load_data(old)
	check(L.owned.size() == 16 and c4.plots_bought == 0 and c4.plot_price() == 6000, "old save with 4×4 keeps all its land, next plot 6000")
	L.owned = keep
	# готовый город меню и витрины — прежняя земля 4×4
	check(Land.new().owned.size() == 16, "menu/demo land unchanged: 4×4 plots")
	game.hud.advisor_panel.visible = false
	game.rig.set_view(Vector3(192, 2, 165), 0, 72, 340)
	await shot("sinks_land.png")


# ---------- праздник ----------

func _festival() -> void:
	var hud = game.hud
	for s: Array in STREETS:
		street(s[0], s[1])
	var houses := []
	for i in 12:
		var b := put("house_pleb", Vector2(185, 150))
		if not b.is_empty():
			houses.append(b)
	check(houses.size() == 12, "12 houses: %d" % houses.size())
	for h in houses:
		var nm := "Проба %d" % int(h["id"])
		c.settled(int(h["id"]), c.house_cap(h), nm)
		game.people._make_family(nm, c.house_cap(h), int(h["id"]), c.door_point(h))    # жители дома (как после загрузки)
	c.level = 2
	c.compute()
	var pop := int(c.stats["pop"])
	check(pop == 48, "48 residents: %d" % pop)
	check(c.can_festival().contains("«Посёлок»"), "closed before «Посёлок»: «%s»" % c.can_festival())
	hud.refresh()
	check(not c.tips.has("fest_tip"), "no advisor before «Посёлок»")
	c.level = 3
	c.money = 100.0
	check(c.fest_price() == 3 * pop and c.can_festival().begins_with("Не хватает денариев"), "price %d = 3 × %d; «%s»" % [c.fest_price(), pop, c.can_festival()])
	check(not c.festival(), "not enough money: no games")
	# советник объясняет один раз
	hud.advisor_panel.visible = false
	hud.refresh()
	check(c.tips.has("fest_tip") and hud.advisor_panel.visible and hud.adv_title.text == "Игры в честь богов", "advisor explains the games once: «%s»" % hud.adv_title.text)
	print("  advisor: ", hud.adv_text.text.replace("\n", " / "))
	game.rig.set_view(Vector3(185, 2, 120), 20, 48, 60)
	await shot("sinks_fest_advisor.png")
	hud.advisor_panel.visible = false
	hud.refresh()
	check(not hud.advisor_panel.visible, "…and not again")
	# карточка станции: кнопка «Устроить игры — N ден.»
	c.money = 3000.0
	var ctr: Dictionary = c.center()
	hud.open_info(ctr)
	await frames(3)
	var btn: Button = hud.info_box.find_child("fest_btn", true, false)
	check(btn != null and not btn.disabled and btn.text == "Устроить игры — %s ден." % hud.fmt(3 * pop), "station card button: «%s»" % (btn.text if btn else "-"))
	game.rig.set_view(Vector3(ctr["pos"].x, 2, ctr["pos"].y), 25, 40, 30)
	await shot("sinks_fest_card.png")
	# игры: деньги, счастье +8% всем домам, повозка чаще, колокольчик, наряд города
	var hp0 := {}
	for h in houses:
		hp0[h["id"]] = int(h["happy"])
	var city_hp0 := int(c.stats["happy"])
	var ev0: int = c.events.size()
	var bell0: int = hud.bell_count
	var notes0: int = hud.notes_box.get_child_count()
	btn.pressed.emit()
	check(c.fest_left == 24 and c.fest_cd == 48 and is_equal_approx(c.money, 3000.0 - 3 * pop), "games on: 24 h, again in 48 h, paid %d" % (3 * pop))
	var plus8 := true
	for h in houses:
		plus8 = plus8 and int(h["happy"]) == int(hp0[h["id"]]) + 8
	check(plus8 and int(c.stats["happy"]) == city_hp0 + 8, "every house +8%% (city %d → %d)" % [city_hp0, int(c.stats["happy"])])
	var row := false
	for p: Array in c.stats["happy_parts"]:
		if String(p[0]).begins_with("Праздник") and int(p[1]) == 8:
			row = true
	check(row and (houses[0]["happy_parts"] as Array).any(func(p): return String(p[0]).begins_with("Праздник") and int(p[1]) == 8), "«Праздник» +8%% line in the city and house breakdown")
	check(c.events.size() == ev0 + 1 and String(c.events[-1]["text"]).begins_with("Игры в честь богов!") and hud.bell_count == bell0 + 1 and hud.notes_box.get_child_count() == notes0,
		"one bell note, no pop-up: «%s»" % String(c.events[-1]["text"]))
	c.stats["happy"] = 65
	var m65: Array = c.arrive_mult()
	c.stats["happy"] = 85
	var m85: float = c.arrive_mult()[0]
	c.compute()
	check(is_equal_approx(float(m65[0]), 0.7) and String(m65[1]).contains("игры") and is_equal_approx(m85, 0.5), "cart: 65%% ×%.2f («%s»), 85%% ×%.2f (floor 0.5)" % [float(m65[0]), m65[1], m85])
	check(c.can_festival().begins_with("Игры уже идут"), "second games refused: «%s»" % c.can_festival())
	check(not game.fest_vis.is_empty() and (game.fest_vis["h"] as Array).size() >= 16 and game.fest_vis["mesh"] != null, "the city is dressed: %d parts and garlands" % (game.fest_vis["h"] as Array).size())
	await frames(3)
	var st_txt := _texts(hud.info_box)
	check(st_txt.contains("идут, ещё 24 ч") and st_txt.contains("Чаще обычного"), "station card while the games go on")
	await shot("sinks_fest_card_on.png")
	hud.close_panels()
	# толпа: жители идут на площадь у станции
	var near := 0
	var door: Vector2 = c.door_point(ctr)
	for r in game.people.residents:
		var tg: Dictionary = game.people._fest_target(r, door + Vector2(20, 40))
		if not tg.is_empty() and (tg["p"] as Vector2).distance_to(door) < 13.0:
			near += 1
	check(near > 0 and near == game.people.residents.size(), "festival errands lead to the station square (%d of %d)" % [near, game.people.residents.size()])
	var far := 0
	for r in game.people.residents:
		if not game.people._fest_target(r, door + Vector2(0, 140)).is_empty():
			far += 1
	check(far == 0, "homes further than 110 m stay out of it")
	# снимок: все уже дошли до площади (как будто прошёл час)
	for r in game.people.residents:
		var tg: Dictionary = game.people._fest_target(r, door)
		if tg.is_empty():
			continue
		r["state"] = "idle"
		r["p"] = tg["p"]
		game.people._claim(r, tg)
		game.people._go(r, tg["p"], "errand", true)
	game.speed = 1.0
	await frames(150)
	game.speed = 0.0
	game.rig.set_view(Vector3(192, 2, 100), 200, 34, 34)
	await shot("sinks_fest_road.png")
	game._set_hour(20.5)
	await shot("sinks_fest_evening.png")
	game._set_hour(10.0)
	# сохранение посреди игр
	var d: Dictionary = c.save_data()
	var c2 := City.new(game.land)
	c2.load_data(JSON.parse_string(JSON.stringify(d)))
	check(c2.fest_left == 24 and c2.fest_cd == 48, "saved mid-games: %d h left, %d h to next" % [c2.fest_left, c2.fest_cd])
	var old := d.duplicate(true)
	old.erase("fest_left")
	old.erase("fest_cd")
	c2.load_data(old)
	check(c2.fest_left == 0 and c2.fest_cd == 0 and c2.fest_bonus() == 0, "old save: no games")
	# сутки: игры кончились — тихая запись, счастье прежнее, наряд снят; ещё сутки — можно снова
	c.money = 3000.0
	for i in 24:
		c.sim_day()
	check(c.fest_left == 0 and c.fest_cd == 24 and int(houses[0]["happy"]) == int(hp0[houses[0]["id"]]), "after 24 h: over, happiness back (%d)" % int(houses[0]["happy"]))
	check(String(c.events[-1]["text"]).begins_with("Игры в честь богов окончены") or c.events.any(func(e): return String(e["text"]).begins_with("Игры в честь богов окончены")), "bell: games over")
	check(game.fest_vis.is_empty(), "decorations removed")
	check(c.can_festival() == "Новые игры можно устроить через 24 ч", "cooldown: «%s»" % c.can_festival())
	for i in 24:
		c.sim_day()
	c.money = maxf(c.money, 3000.0)
	check(c.can_festival() == "", "after 48 h the games can be held again: «%s»" % c.can_festival())
	check(c.festival() and not game.fest_vis.is_empty(), "second games")
	# загрузка с идущими играми — город сразу наряжен (game._ready)
	game._fest_look(false)
	check(game.fest_vis.is_empty(), "look off")
	game._fest_look(true)
	check(not game.fest_vis.is_empty(), "look on again")


func _texts(n: Node) -> String:
	var out := ""
	for l in n.find_children("*", "Label", true, false):
		out += (l as Label).text + " | "
	for b in n.find_children("*", "Button", true, false):
		out += (b as Button).text + " | "
	return out
