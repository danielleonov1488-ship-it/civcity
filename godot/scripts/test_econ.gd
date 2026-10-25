extends Node
## Экономика v2 (этап 2 плана 24.10) без графики: кривая очков и денег (2.1, 2.3), повторы лавок и украшений в новой игре
## (2.5, 2.6), налоги по классам (2.7), история денег за 48 часов (2.4), старые сохранения — без перемен; Легион из истории (Д9).
##   bash .work/py/gpu_run.sh --headless res://test_econ.tscn      → «ECON DONE fails=N»

var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	_curve()
	_repeats()
	_taxes()
	_history()
	_old_save()
	print("ECON DONE fails=%d" % fails)
	get_tree().quit()


## Кривая v2: старт 2000, казна и полки первых рангов, ряды «Хутора» и «Деревни», награды первых просьб, Легион из истории
func _curve() -> void:
	print("== кривая очков и денег")
	_check(Defs.START_MONEY == 2000 and int(Defs.LEVELS[0]["money"]) == 2500 and int(Defs.LEVELS[1]["money"]) == 4000,
		"старт 2000, казна «Стоянки» 2500, «Хутора» 4000")
	var shelves := []
	for i in 5:
		shelves.append(int(Defs.LEVELS[i]["rp"]))
	_check(shelves == [250, 500, 800, 1100, 1300], "полки рангов 0–4: %s" % [shelves])
	var row := {}
	for r: Dictionary in Defs.RESEARCH:
		if r.has("story"):
			continue
		var l := int(r["lvl"])
		if not row.has(l):
			row[l] = []
		(row[l] as Array).append(int(r["cost"]))
	var r1: Array = row[1]
	var r2: Array = row[2]
	_check(int(r1.max()) <= 100 and int(r2.max()) <= 0.28 * float(Defs.LEVELS[2]["rp"]), "дороже всех: на «Хуторе» %d, в «Деревне» %d (≤ 28%% полок)" % [int(r1.max()), int(r2.max())])
	_check(int(Defs.research("bakery")["lvl"]) == 2 and int(Defs.research("cobbler")["lvl"]) == 2, "Пекарня и Сапожник — в ряду «Деревни»")
	var early := 0
	var hutor := 0
	for q: Dictionary in Defs.REQUESTS:
		if q["id"] in ["road1", "houses3", "fam3", "fruit", "scriptorium", "research1", "lights", "decor5", "fed6"]:
			early += int(q["rp"])
		elif q["id"] in ["hamlet", "scriptorium2", "market", "floor2", "pop40", "fountain4"]:
			hutor += int(q["rp"])
	_check(early == 65 and hutor == 150, "очки просьб: до «Хутора» %d, на «Хуторе» %d" % [early, hutor])
	var lr := Defs.research("legion")
	_check(int(lr["lvl"]) == 1 and int(lr["cost"]) == 0 and String(lr.get("story", "")) == "bandits" and String(Defs.research("archery").get("after", "")) == "legion"
		and int(Defs.research("archery")["lvl"]) == 2 and int(Defs.B["barracks"]["cost"]) <= 600,
		"Легион — история «Разбойники у арки» на «Хуторе»; Стрельбище — «Деревня»; Казармы %d ден." % int(Defs.B["barracks"]["cost"]))
	# самое дорогое в ряду помещается на полки этого ранга (с «Новыми полками» — вдвое, с «Городка»)
	var bad := []
	for l in row:
		var capr := int(Defs.LEVELS[int(l)]["rp"]) * (2 if int(l) >= 4 else 1)
		if int((row[l] as Array).max()) > capr:
			bad.append(l)
	_check(bad.is_empty(), "дороже полок нет ни в одном ряду %s" % [bad])


## Повторы: вторая лавка того же вида — ровно половина её бонуса, третья — четверть, другой вид — целиком; украшения
## 100 / 60 / 30%: три одинаковых светильника = 1,9 одного, три разных = 3; старые правила (econ 0) — простая сумма
func _repeats() -> void:
	print("== повторы лавок и украшений")
	var p1 := City.shop_parts(["mimes", "dice"], {"mimes": 8, "dice": 6}, 1)
	_check(int(p1[0][1]) == 8 and int(p1[1][1]) == 3 and bool(p1[1][2]) and String(p1[1][0]).contains("вполовину"),
		"вторая лавка развлечений — ровно половина своего бонуса: %s" % [p1])
	var p3 := City.shop_parts(["mimes", "dice", "musicians", "weaver"], {"mimes": 8, "dice": 6, "musicians": 5, "weaver": 6}, 1)
	_check(int(p3[2][1]) == 1 and String(p3[2][0]).contains("четверть") and int(p3[3][1]) == 6 and not bool(p3[3][2]),
		"третья — четверть (5 → %d), лавка одежды — целиком (%d)" % [int(p3[2][1]), int(p3[3][1])])
	var p0 := City.shop_parts(["mimes", "dice"], {"mimes": 8, "dice": 6}, 0)
	_check(int(p0[0][1]) == 8 and int(p0[1][1]) == 6 and not bool(p0[1][2]), "старые правила — целиком: %s" % [p0])
	var one := float(Defs.B["candelabrum"]["deco"])
	var same := City.deco_points([["candelabrum", one], ["candelabrum", one], ["candelabrum", one]], 1)
	var diff := City.deco_points([["candelabrum", one], ["lamp_post", 3.0], ["bench", 3.0]], 1)
	var old := City.deco_points([["candelabrum", one], ["candelabrum", one], ["candelabrum", one]], 0)
	_check(is_equal_approx(float(same[0]), 1.9 * one) and bool(same[1]) and is_equal_approx(float(diff[0]), one + 6.0) and not bool(diff[1])
		and is_equal_approx(float(old[0]), 3.0 * one), "украшения: три одинаковых %.1f (= 1,9 × %.0f), три разных %.1f, по-старому %.1f" % [float(same[0]), one, float(diff[0]), float(old[0])])
	# в городе: дом и три светильника рядом
	var c := City.new(Land.new())
	c.money = 1e6
	for r in ["q_lights"]:
		c.research[r] = true
	var hp := Land.START
	var h := c.place("house_pleb", hp, 0.0, 0, 0, true)
	for k in 3:
		c.place("candelabrum", hp + Vector2(4.0 + 2.0 * k, 3.0), 0.0, 0, 0, true)
	c.econ = 1
	c.compute()
	var d1 := float(h["deco"])
	c.econ = 0
	c.compute()
	var d0 := float(h["deco"])
	_check(is_equal_approx(d1, 1.9 * one) and is_equal_approx(d0, 3.0 * one), "дом у трёх светильников: новая игра %.1f, старый город %.1f" % [d1, d0])
	# подсветка охвата (Cover): четвёртый такой же светильник прибавит 30% своих очков, скамья — целиком
	c.econ = 1
	c.compute()
	var add_same := Cover._deco_add(c, h, "candelabrum", one, 1.0)
	var add_other := Cover._deco_add(c, h, "bench", 3.0, 1.0)
	var drop_one := Cover._deco_add(c, h, "candelabrum", one, -1.0)
	_check(is_equal_approx(add_same, 0.3 * one) and is_equal_approx(add_other, 3.0) and is_equal_approx(drop_one, -0.3 * one),
		"подсветка: ещё светильник +%.1f, скамья +%.1f, убрать светильник %.1f" % [add_same, add_other, drop_one])


## Налоги по классам: ×0,8 / ×1,3 к налогу и +5 / −8 к счастью дома на следующем пересчёте; с «Деревни»; сохраняются
func _taxes() -> void:
	print("== налоги по классам")
	var c := City.new(Land.new())
	c.money = 1e6
	var h := c.place("house_pleb", Land.START, 0.0, 0, 0, true)
	c.settled(int(h["id"]), 4, "Проба")
	c.level = 1
	_check(not c.tax_open(), "на «Хуторе» налоги по классам ещё закрыты")
	c.level = 2
	_check(c.tax_open(), "с «Деревни» — открыты")
	c.compute()
	var hap0 := int(h["happy"])
	var t0 := c.house_tax(h)
	var proj := c.happy_if_tax("plebs", 2)
	_check(int(h["happy"]) == hap0 and c.tax_of("plebs") == 1, "прикидка «если высокие» (%d%%) ничего не меняет в городе" % proj)
	c.set_tax("plebs", 0)
	var soft_h := int(h["happy"]) - hap0
	var soft_t := c.house_tax(h) / t0
	c.set_tax("plebs", 2)
	var high_h := int(h["happy"]) - hap0
	var high_t := c.house_tax(h) / t0
	_check(soft_h == 5 and is_equal_approx(soft_t, 0.8) and high_h == -8 and is_equal_approx(high_t, 1.3),
		"мягкие: счастье %+d, налог ×%.2f; высокие: счастье %+d, налог ×%.2f" % [soft_h, soft_t, high_h, high_t])
	var has_line := false
	for p: Array in h["happy_parts"]:
		has_line = has_line or String(p[0]) == "Налоги: высокие"
	_check(has_line, "в карточке дома — строка «Налоги: высокие»")
	var d: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	var c2 := City.new(Land.new())
	c2.load_data(d)
	_check(c2.tax_of("plebs") == 2 and c2.tax_of("artisans") == 1, "налоги сохраняются: %s" % [c2.taxes])
	c.set_tax("plebs", 1)
	_check(c.taxes.is_empty() and int(h["happy"]) == hap0, "обычные — как раньше")


## История денег: 48 часов, «+N/ч» — доход прошлого часа, за сутки сумма сходится с казной, траты по видам, сохранение
func _history() -> void:
	print("== история денег")
	var c := City.new(Land.new())
	c.place("center", Land.CENTER, PI / 2, 0, 0, true)
	c.money = 500.0                                # ниже предела казны: сутки видны в казне
	var h := c.place("house_pleb", Land.START, 0.0, 0, 0, true)
	c.settled(int(h["id"]), 4, "Проба")
	var marks := []
	for i in 60:
		marks.append(c.money)
		if i == 50:
			c.place("flowers", Land.START + Vector2(6, 0), 0.0, 0, 0)   # стройка посреди суток
		c.sim_day()
	marks.append(c.money)
	_check(c.hist.size() == Defs.HIST_N, "в истории ровно %d часов (%d)" % [Defs.HIST_N, c.hist.size()])
	var s := 0
	for k in ["tax", "wage", "upkeep", "build", "fest", "land", "legion", "reward", "other"]:
		s += c.hist_sum(k, 24)
	s -= c.hist_sum("lost", 24)
	var delta := roundi(float(marks[60])) - roundi(float(marks[36]))
	_check(s == delta and delta != 0, "за сутки по видам %d = изменение казны %d" % [s, delta])
	var last: Array = c.hist[-1]
	var net := int(last[0]) + int(last[1]) + int(last[2])
	_check(absi(net - roundi(float(c.stats["income"]) - float(c.stats["upkeep"]))) <= 1, "«+N/ч» = доход прошлого часа (%d)" % net)
	_check(c.hist_sum("build", 24) <= -int(Defs.B["flowers"]["cost"]) + 1, "стройка посреди суток — в «стройке» (%d)" % c.hist_sum("build", 24))
	var d: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	var c2 := City.new(Land.new())
	c2.load_data(d)
	_check(c2.hist == c.hist and JSON.stringify(d["hist"]).length() < 10000, "история сохраняется (%d байт)" % JSON.stringify(d["hist"]).length())


## Старое сохранение (без econ_v, налогов и истории): правила прежние, счастье то же, Легион не трогаем
func _old_save() -> void:
	print("== старое сохранение")
	var c := City.new(Land.new())
	c.money = 1e6
	c.research["q_lights"] = true
	c.research["legion"] = true
	var h := c.place("house_pleb", Land.START, 0.0, 0, 0, true)
	for k in 3:
		c.place("candelabrum", Land.START + Vector2(4.0 + 2.0 * k, 3.0), 0.0, 0, 0, true)
	var d: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	for k in ["econ_v", "taxes", "hist"]:
		d.erase(k)
	var c2 := City.new(Land.new())
	c2.load_data(d)
	c.econ = 0
	c.compute()
	var h2: Dictionary = c2.buildings[int(h["id"])]
	_check(c2.econ == 0 and c2.taxes.is_empty() and c2.hist.is_empty() and int(h2["happy"]) == int(h["happy"]) and is_equal_approx(float(h2["deco"]), float(h["deco"])),
		"без econ_v: прежние правила, счастье %d = %d" % [int(h2["happy"]), int(h["happy"])])
	_check(c2.legion.window_open() and c2.can_research("legion") == "Уже изучено", "Легион, изученный за очки, остаётся")
