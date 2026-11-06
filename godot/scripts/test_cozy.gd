extends Node
## «Уютный Рим», этап 1 (docs/PLAN_COZY.md) без графики: ранги за качество и меньше жителей (Balance.LEVELS),
## повозка в большом городе реже, «Большой город» в счастье домов; старые города (cozy_v 0) — по-прежнему.
##   bash .work/py/gpu_run.sh --headless res://test_cozy.tscn      → «COZY DONE fails=N»

var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	_table()
	_ranks()
	_size()
	_arrive()
	_save()
	print("COZY DONE fails=%d" % fails)
	get_tree().quit()


## Таблица рангов: жителей всё больше, «Вечный город» — 800; постройки в условиях открыты к этому рангу
func _table() -> void:
	print("== таблица рангов")
	var pops := []
	var ok_up := true
	for i in range(1, Balance.LEVELS.size()):
		pops.append(int(Balance.LEVELS[i]["pop"]))
		if i > 1 and int(Balance.LEVELS[i]["pop"]) <= int(Balance.LEVELS[i - 1]["pop"]):
			ok_up = false
	_check(Balance.LEVELS.size() == Defs.LEVELS.size(), "рангов столько же, сколько в Defs.LEVELS (%d)" % Defs.LEVELS.size())
	_check(ok_up and pops == [15, 40, 90, 170, 300, 500, 800], "жители рангов: %s" % [pops])
	var late := []
	for i in range(1, Balance.LEVELS.size()):
		for n: Dictionary in Balance.LEVELS[i]["need"]:
			if String(n["p"][0]) != "count":
				continue
			var t := String(n["p"][1])
			var u := String(Defs.B[t].get("unlock", ""))
			if u != "" and int(Defs.research(u).get("lvl", 0)) > i - 1:
				late.append("%s (ранг %d, исследование уровня %d)" % [t, i, int(Defs.research(u)["lvl"])])
	_check(late.is_empty(), "постройки в условиях ранга открываются раньше него %s" % [late])


## Город: в «Уютном Риме» условия — из Balance, в старом — из Defs.LEVELS; имя и казна — общие
func _ranks() -> void:
	print("== ранги в городе")
	var c := City.new(Land.new())
	var old_pop := int(c.rank_needs(1)[0]["need"])
	c.cozy_v = 1
	var cn: Array = c.rank_needs(1)
	_check(old_pop == int(Defs.LEVELS[1]["pop"]) and int(cn[0]["need"]) == 15 and int(cn[1]["need"]) == 55, "«Хутор»: было %d жителей, стало %d, счастье %d%%" % [old_pop, int(cn[0]["need"]), int(cn[1]["need"])])
	var last: Dictionary = c.lv(7)
	_check(String(last["name"]) == "Вечный город" and int(last["pop"]) == 800 and int(last["money"]) == int(Defs.LEVELS[7]["money"]),
		"«Вечный город»: 800 жителей, казна из Defs (%d)" % int(last["money"]))
	_check(c.next_level()["pop"] == 15 and c.rank_text(1).contains("15"), "следующий уровень и подсказка — по новым числам: «%s»" % c.rank_text(1))
	var tier: Dictionary = c.rank_needs(1)[2]
	c.research["stall_veg"] = true
	_check(String(tier["p"][0]) == "tier" and bool(tier["pct"]) and int(tier["need"]) == Balance.TIER_PCT and c.progress_of(["tier", 0]) > int(tier["have"]),
		"условие «%s»: %d%% → %d%% после исследования" % [tier["text"], int(tier["have"]), c.progress_of(["tier", 0])])


## «Большой город»: −1% за каждые 60 жителей сверх 120, не больше −8%; в счастье дома — строка
func _size() -> void:
	print("== большой город")
	var v := [Balance.size_penalty(100), Balance.size_penalty(180), Balance.size_penalty(300), Balance.size_penalty(800)]
	_check(v == [0, -1, -3, -8], "штраф при 100/180/300/800 жителях: %s" % [v])
	for cz in [0, 1]:
		var c := City.new(Land.new())
		c.cozy_v = cz
		c.money = 1e6
		var h := c.place("house_pleb", Land.START, 0.0, 0, 0, true)
		h["pop"] = 300
		c.compute()
		var line := 0
		for p: Array in h["happy_parts"]:
			if String(p[0]) == "Большой город":
				line = int(p[1])
		var city_line := 0
		for p: Array in c.stats["happy_parts"]:
			if String(p[0]) == "Большой город":
				city_line = int(p[1])
		if cz == 1:
			_check(line == -3 and city_line == -3, "300 жителей: в доме «Большой город» %d%%, в счастье города %d%%" % [line, city_line])
		else:
			_check(line == 0 and city_line == 0, "старый город — без «Большого города»")


## Повозка: при 400 жителях — реже на 400/ARRIVE_SLOW_POP, при 1000 — не больше ARRIVE_SLOW_MAX; старый город — как был
func _arrive() -> void:
	print("== повозка")
	var c := City.new(Land.new())
	c.stats["pop"] = 400
	c.level = 5                                # следующему рангу («Большой город») нужно 500
	var e0 := c.arrive_every()
	c.cozy_v = 1
	var e1 := c.arrive_every()
	c.stats["pop"] = 1000
	var e2 := c.arrive_every()
	_check(is_equal_approx(e1, e0 * (1.0 + 400.0 / Balance.ARRIVE_SLOW_POP)) and is_equal_approx(e2, e0 * Balance.ARRIVE_SLOW_MAX * Balance.AHEAD_SLOW),
		"промежуток: прежний %.2f ч, при 400 жителях %.2f, при 1000 (больше, чем нужно рангу) %.2f" % [e0, e1, e2])


## cozy_v сохраняется; старое сохранение (без cozy_v) — по прежним правилам
func _save() -> void:
	print("== сохранение")
	var c := City.new(Land.new())
	c.cozy_v = 1
	var d: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	var c2 := City.new(Land.new())
	c2.load_data(d)
	d.erase("cozy_v")
	var c3 := City.new(Land.new())
	c3.load_data(d)
	_check(c2.cozy_v == 1 and c3.cozy_v == 0, "cozy_v после загрузки: %d; старое сохранение: %d" % [c2.cozy_v, c3.cozy_v])
