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
	_visits()
	_legion()
	_army()
	_gear()
	_forge()
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


## Этап 3: семья сходила в термы — дому +3% на 48 ч; потом бонус проходит; в старом городе походы не считаются
func _visits() -> void:
	print("== походы")
	var c := City.new(Land.new())
	c.cozy_v = 1
	c.money = 1e6
	var h := c.place("house_pleb", Land.START, 0.0, 0, 0, true)
	h["pop"] = 5
	c.note_visit(int(h["id"]), "bath")
	c.note_visit(int(h["id"]), "temple")
	c.compute()
	var got := {}
	for p: Array in h["happy_parts"]:
		got[String(p[0])] = int(p[1])
	var city_row := 0
	for p: Array in c.stats["happy_parts"]:
		if String(p[0]).begins_with("Походы"):
			city_row = int(p[1])
	_check(got.get("Ходили в термы", 0) == 3 and got.get("Были на службе в храме", 0) == 3 and city_row == 6,
		"после терм и службы: дому +3%% и +3%%, в счастье города — строка «Походы» %d%%" % city_row)
	c.clock_h += Balance.VISIT_H + 1
	c.compute()
	var left := false
	for p: Array in h["happy_parts"]:
		left = left or String(p[0]) == "Ходили в термы"
	var d: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	var c2 := City.new(Land.new())
	c2.load_data(d)
	_check(not left and c2.clock_h == c.clock_h and (c2.visits.get(int(h["id"]), {}) as Dictionary).has("bath"), "через %d ч бонус прошёл; походы и часы сохраняются" % (Balance.VISIT_H + 1))
	var c0 := City.new(Land.new())
	var h0 := c0.place("house_pleb", Land.START, 0.0, 0, 0, true)
	c0.note_visit(int(h0["id"]), "bath")
	_check(c0.visits.is_empty(), "старый город — походы не считаются")


## Легион 2.0, этап 0 в новой игре: строитель один (всё сразу не улучшить), стройки дольше, повтор боя — треть награды
func _legion() -> void:
	print("== Легион: строители и время")
	var c := City.new(Land.new())
	c.cozy_v = 1
	c.money = 1e7
	var L: Legion = c.legion
	c.research["legion"] = true
	c.research["archery"] = true
	c.place("barracks", Land.START + Vector2(20, 0), 0.0, 0, 0, true)
	c.place("range", Land.START + Vector2(-20, 0), 0.0, 0, 0, true)
	L._set_level("legionary", 8)
	var t9 := float(L.upgrade_info("legionary")["time"])
	L._set_level("legionary", 1)
	var ok1 := L.upgrade("legionary")
	var why := L.can_upgrade("archer")
	_check(L.builders() == 1 and ok1 and why.begins_with("Все строители заняты") and is_equal_approx(t9, 26.0 * 3600.0),
		"строитель один: второе улучшение — «%s»; 9-й уровень — %.0f ч" % [why, t9 / 3600.0])
	L.tick()
	var st := {"reward": {"money": 100}}
	var rep: int = int(Legion.reward_for(st, false)["money"])
	var c0 := City.new(Land.new())
	c0.legion.tick()
	var rep0: int = int(Legion.reward_for(st, false)["money"])
	c.legion.tick()
	_check(rep == 35 and rep0 == 100 and c0.legion.builders() > 5, "повтор боя: в новой игре %d из 100, в старой %d; в старой строители без предела" % [rep, rep0])


## Легион 2.0, этап 1: воины-новобранцы — трое с городом, новобранцы дня, тренировка, ранения, сохранение; старый город — без них
func _army() -> void:
	print("== Легион: воины-новобранцы")
	var c := City.new(Land.new())
	c.cozy_v = 1
	c.money = 1e6
	var L: Legion = c.legion
	c.research["legion"] = true
	c.place("barracks", Land.START + Vector2(20, 0), 0.0, 0, 0, true)
	L.army_tick()
	var c0 := City.new(Land.new())
	c0.legion.army_tick()
	_check(L.soldiers.size() == 3 and L.recruits.size() == 3 and c0.legion.soldiers.is_empty() and not c0.legion.army_on(),
		"с городом пришли %d воина, новобранцев %d; в старом городе воинов %d" % [L.soldiers.size(), L.recruits.size(), c0.legion.soldiers.size()])
	var m0 := float(c.money)
	var cost := L.recruit_cost(0)
	var ok := L.recruit(0)
	_check(ok and L.soldiers.size() == 4 and L.recruits.size() == 2 and is_equal_approx(m0 - float(c.money), float(cost)),
		"взяли новобранца за %d ден.: воинов %d, кандидатов осталось %d" % [cost, L.soldiers.size(), L.recruits.size()])
	# тренировка: место одно (Казармы 1), ранг растёт по таймеру
	var a: Dictionary = L.soldiers[0]
	var b: Dictionary = L.soldiers[1]
	var t1 := L.train(int(a["id"]))
	var why := L.can_train(int(b["id"]))
	a["train_end"] = Legion.now() - 1.0
	L.army_tick()
	_check(t1 and why.begins_with("Все места тренировки заняты") and int(a["rank"]) == 1 and L.s_state(a) == "ready",
		"тренировка: второй ждёт («%s»), первый теперь ранга %d" % [why, int(a["rank"])])
	# в бой — воины с прибавкой звёзд и ранга; павший ранен, его место занимает запасной
	L.squad = ["legionary", "legionary", "legionary"]
	var sq := L.battle_squad()
	var plain: Dictionary = Legion.unit_stats("legionary", 1)
	var strong := 0
	for u: Dictionary in sq:
		if int(u["hp"]) > int(plain["hp"]):
			strong += 1
	_check(sq.size() == (4 if L.hero_ready() else 3) and int(sq[sq.size() - 1].get("sid", -1)) > 0 and strong >= 1,
		"в бою %d бойцов с именами (%s), сильнее простого — %d" % [sq.size(), String(sq[sq.size() - 1].get("sname", "")), strong])
	var setup := {"squad": sq}
	var sid := int(sq[sq.size() - 1]["sid"])
	var hurt := L._army_after(setup, {"fallen": [sid]})
	var sq2 := L.battle_squad()
	var ids := []
	for u: Dictionary in sq2:
		ids.append(int(u.get("sid", -1)))
	_check(hurt.size() == 1 and L.s_state(L.soldier(sid)) == "wound" and not (sid in ids) and sq2.size() == sq.size(),
		"павший ранен (%s), в отряде его заменил запасной" % ", ".join(hurt))
	for s: Dictionary in L.soldiers:
		s["wound_end"] = Legion.now() + 600.0
	_check(L._army_squad().is_empty() and L.auto_squad().count("") == L.auto_squad().size(), "все ранены — в бой идти некому, «Лучший состав» пуст")
	# настоящий бой: павшие воины приходят в итоге (fallen)
	for s: Dictionary in L.soldiers:
		s["wound_end"] = 0.0
	var sim_setup := {"kind": "campaign", "squad": L._army_squad(), "waves": [[Legion.enemy_stats("wolf", 6.0), Legion.enemy_stats("wolf", 6.0), Legion.enemy_stats("wolf", 6.0)]],
		"perks": {}, "seed": 7, "food": 0, "packs": []}
	var res := LegionSim.new(sim_setup).run(true)
	_check(not bool(res["win"]) and (res.get("fallen", []) as Array).size() == int(res["total"]) - int(res["alive"]),
		"бой с сильными волками проигран: пали %d воинов (их номера в итоге)" % (res.get("fallen", []) as Array).size())
	# сохранение
	var d := L.to_dict()
	var L2 := Legion.new()
	L2.from_dict(JSON.parse_string(JSON.stringify(d)))
	_check(L2.soldiers.size() == L.soldiers.size() and int(L2.soldier(int(a["id"]))["rank"]) == 1 and L2.sid_next == L.sid_next and L2.recruits.size() == 2,
		"сохранение: воинов %d, ранг первого %d, кандидатов %d" % [L2.soldiers.size(), int(L2.soldier(int(a["id"])).get("rank", -1)), L2.recruits.size()])
	# счастливый большой город — звёзды лучше
	var lo: Array = Soldiers.star_odds(Soldiers.quality(45, 0))
	var hi: Array = Soldiers.star_odds(Soldiers.quality(90, 7))
	_check(float(hi[2]) + float(hi[3]) + float(hi[4]) > 2.5 * (float(lo[2]) + float(lo[3]) + float(lo[4])),
		"шанс 3★+: обычный город %.0f%%, счастливый большой %.0f%%" % [float(lo[2]) + float(lo[3]) + float(lo[4]), float(hi[2]) + float(hi[3]) + float(hi[4])])


## Легион 2.0, этап 2: вещи 5 редкостей — числа, надеть/снять, класс, бой сильнее, добыча, Склад, продажа, сохранение
func _gear() -> void:
	print("== Легион: снаряжение")
	var c := City.new(Land.new())
	c.cozy_v = 1
	c.money = 1e5
	var L: Legion = c.legion
	c.research["legion"] = true
	c.place("barracks", Land.START + Vector2(20, 0), 0.0, 0, 0, true)
	L.army_tick()
	var w0 := Gear.stats({"slot": "weapon", "rarity": 0, "ilvl": 1})
	var w4 := Gear.stats({"slot": "weapon", "rarity": 4, "ilvl": 10})
	_check(is_equal_approx(float(w4["atk"]) / float(w0["atk"]), 2.8 * 1.45), "легендарный 10-го уровня сильнее обычного 1-го в %.2f раза" % (float(w4["atk"]) / float(w0["atk"])))
	var s: Dictionary = L.soldiers[0]
	var sid := int(s["id"])
	var before := L.soldier_stats(s, "legionary")
	var sw := L.add_item({"slot": "weapon", "cls": "legionary", "rarity": 3, "ilvl": 5})
	var bow := L.add_item({"slot": "weapon", "cls": "archer", "rarity": 2, "ilvl": 5})
	var arm := L.add_item({"slot": "armor", "cls": "", "rarity": 1, "ilvl": 5})
	var why := L.can_equip(sid, int(bow["id"]))
	var ok := L.equip(sid, int(sw["id"])) and L.equip(sid, int(arm["id"]))
	var after := L.soldier_stats(s, "legionary")
	_check(ok and why.begins_with("Это для класса") and int(after["atk"]) > int(before["atk"]) and int(after["hp"]) > int(before["hp"]) and float(after["armor"]) > float(before["armor"]),
		"надели меч и доспех: урон %d → %d, здоровье %d → %d; лук легионеру — «%s»" % [int(before["atk"]), int(after["atk"]), int(before["hp"]), int(after["hp"]), why])
	_check(L.store_count() == 1 and Gear.name_of(sw) == "Эпический гладий" and Gear.name_of(arm) == "Добротная лорика", "на Складе 1 (лук); «%s», «%s»" % [Gear.name_of(sw), Gear.name_of(arm)])
	# вещь переходит от воина к воину
	var s2: Dictionary = L.soldiers[1]
	L.equip(int(s2["id"]), int(arm["id"]))
	_check(not (s["gear"] as Dictionary).has("armor") and int(L.item(int(arm["id"]))["on"]) == int(s2["id"]), "доспех перешёл ко второму воину")
	L.unequip(int(s2["id"]), "armor")
	_check(L.store_count() == 2 and int(L.item(int(arm["id"]))["on"]) == 0, "сняли — на Складе 2")
	# продажа
	c.money = 100.0
	var m0 := float(c.money)
	var price := Legion.item_price(bow)
	L.sell_item(int(bow["id"]))
	_check(L.store_count() == 1 and is_equal_approx(float(c.money) - m0, float(price)) and price > 0, "продали лук за %d ден." % price)
	# добыча: босс — наверняка; Склад полон — честно
	var boss := {"boss": true, "idx": 29}
	var d := L._drop(boss, true)
	_check(not d.is_empty() and not d.has("full") and int(d["ilvl"]) >= 9, "босс 3-й провинции: %s %d ур." % [Gear.name_of(d), int(d.get("ilvl", 0))])
	var rar := [0, 0, 0, 0, 0]
	for i in 400:
		var it := Gear.roll(L._rng, 5, false, ["legionary"])
		rar[int(it["rarity"])] += 1
	while L.store_count() < L.store_cap():
		L.add_item({"slot": "badge", "cls": "", "rarity": 0, "ilvl": 1})
	var full := L._drop(boss, true)
	_check(full.has("full") and rar[0] > rar[2] and rar[2] > rar[4], "Склад полон (%d) — «не уместилась»; редкости из 400: %s" % [L.store_cap(), str(rar)])
	# сохранение
	var L2 := Legion.new()
	L2.from_dict(JSON.parse_string(JSON.stringify(L.to_dict())))
	var s3 := L2.soldier(sid)
	_check(L2.items.size() == L.items.size() and int((s3["gear"] as Dictionary).get("weapon", 0)) == int(sw["id"]) and L2.iid_next == L.iid_next
		and int(L2.soldier_stats(s3, "legionary")["atk"]) == int(after["atk"]), "сохранение: вещей %d, меч на месте, урон тот же" % L2.items.size())


## Легион 2.0, этап 3: Кузница — разобрать на обломки, выковать вещь (обломки, денарии, время), полный Склад — ждёт, сохранение
func _forge() -> void:
	print("== Легион: Кузница")
	var c := City.new(Land.new())
	c.cozy_v = 1
	c.money = 5000.0
	var L: Legion = c.legion
	c.research["legion"] = true
	c.place("barracks", Land.START + Vector2(20, 0), 0.0, 0, 0, true)
	L.army_tick()
	var no := L.can_forge("helmet", "", 0)
	c.place("forge", Land.START + Vector2(-20, 0), 0.0, 0, 0, true)
	var ids := []
	for i in 3:
		ids.append(int(L.add_item({"slot": "badge", "cls": "", "rarity": 0, "ilvl": 2})["id"]))
	for id in ids:
		L.smelt(id)
	var why1 := L.can_forge("helmet", "", 1)
	var why2 := L.can_forge("helmet", "", 2)
	_check(no == "Постройте Кузницу" and int(L.shards[0]) == 3 and L.items.is_empty() and why1 == "" and why2.begins_with("Нужна Кузница"),
		"без Кузницы — «%s»; разобрали 3 вещи — серых обломков %d; добротную можно, редкую — «%s»" % [no, int(L.shards[0]), why2])
	var m0 := float(c.money)
	var ok := L.forge("helmet", "", 1)
	var busy := L.can_forge("armor", "", 0)
	_check(ok and int(L.shards[0]) == 0 and is_equal_approx(m0 - float(c.money), 150.0) and busy.begins_with("Кузница занята"), "куём добротный шлем: обломки ушли, 150 ден.; вторая ковка — «%s»" % busy)
	L.forging["end"] = Legion.now() - 1.0
	L.army_tick()
	var it: Dictionary = L.items[0] if not L.items.is_empty() else {}
	_check(L.forging.is_empty() and not it.is_empty() and int(it["rarity"]) == 1 and String(it["slot"]) == "helmet", "выкован: %s" % (Gear.name_of(it) if not it.is_empty() else "—"))
	# полный Склад — вещь ждёт в Кузнице
	L.forge("armor", "", 0)
	while L.store_count() < L.store_cap():
		L.add_item({"slot": "badge", "cls": "", "rarity": 0, "ilvl": 1})
	L.forging["end"] = Legion.now() - 1.0
	var msgs := L.army_tick()
	_check(not L.forging.is_empty() and bool(L.forging.get("wait", false)) and ", ".join(msgs).contains("Склад полон"), "Склад полон — вещь ждёт: «%s»" % ", ".join(msgs))
	var L2 := Legion.new()
	L2.from_dict(JSON.parse_string(JSON.stringify(L.to_dict())))
	_check(not L2.forging.is_empty() and String(L2.forging["slot"]) == "armor" and L2.shards.size() == 5, "сохранение: ковка и обломки на месте")
