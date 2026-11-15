extends Node
## Легион 3.0, этап L3.1 (docs/LEGION_V3.md): правила и данные без новых окон — ворота V3 (City.legion_v), лагерь из шести мест
## (уровни, таймеры, один строитель, потолок — Штаб), открытие с 50 жителей, призыв жителя (безработные первыми, пол 30),
## оружие решает класс, четыре слота без знака, пять мест в два ряда, пайки от пекарен, скрытые таланты и умения,
## военные здания не ставятся на карту, сохранение. Старый город (legion_v 0) — как прежде.
##   bash .work/py/gpu_run.sh --headless res://test_legion3.tscn      → «L3 DONE fails=N»

var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("L3 PASS " if ok else "L3 FAIL ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	_gate()
	_unlock()
	_recruit()
	_pick_jobs()
	_floor_roster()
	_gear_class()
	_squad()
	_camp()
	_rations()
	_hidden()
	_save()
	_choice3()
	_hero3()
	_collection3()
	_speed3()
	_chests3()
	_chest_award3()
	print("L3 DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


## Новый город Легиона 3.0: n_fam домов плебеев по семье из четырёх (безработные: построек с работой нет)
func _town(n_fam: int, v := 3) -> City:
	var c := City.new(Land.new())
	c.cozy_v = 1
	c.legion_v = v
	c.money = 1e6
	for i in n_fam:
		var h := c.place("house_pleb", Land.START + Vector2(8.0 * (i % 8), 8.0 * (i / 8)), 0.0, 0, 0, true)
		h["families"] = [{"name": "Юлии%d" % i, "n": 4, "cls": "plebs"}]
		h["pop"] = 4
	c.compute()
	return c


## Постройка с работой, подключённая к дороге (в пустой проверке дорог нет)
func _work(c: City, type: String, at: Vector2) -> void:
	var b := c.place(type, Land.START + at, 0.0, 0, 0, true)
	b["road"] = true
	b["over"] = false


## В каждом доме жителей по записям семей столько же, сколько в «pop»
func _fams_ok(c: City) -> bool:
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		if c.is_house(b):
			var n := 0
			for f: Dictionary in b["families"]:
				n += int(f["n"])
				if typeof(f.get("m")) == TYPE_ARRAY and (f["m"] as Array).size() != int(f["n"]):
					return false
			if n != int(b["pop"]):
				return false
	return true


func _gate() -> void:
	print("== ворота V3")
	var c := _town(2)
	var L: Legion = c.legion
	L.army_tick()
	_check(c.legion_v == 3 and L.v3() and Legion.V3 and Legion.V2, "новая игра: legion_v=%d, V3=%s, V2=%s" % [c.legion_v, Legion.V3, Legion.V2])
	var c0 := City.new(Land.new())
	c0.cozy_v = 1
	c0.research["legion"] = true
	c0.legion.army_tick()
	_check(c0.legion_v == 0 and not c0.legion.v3() and not Legion.V3 and c0.legion.window_open() and c0.legion.slots() == 3
		and c0.legion.soldiers.size() == 3 and c0.legion.recruits.size() == 3 and c0.unlocked("barracks"),
		"старый город: V3 нет, окно по исследованию, 3 стартовых воина, казармы ставятся")
	c.legion.army_tick()
	_check(L.soldiers.is_empty() and L.recruits.is_empty() and L.camp_level("barracks") == 1 and L.camp_level("forge") == 0,
		"V3: ни стартовых воинов, ни новобранцев дня (воинов %d, кандидатов %d)" % [L.soldiers.size(), L.recruits.size()])


func _unlock() -> void:
	print("== открытие с 50 жителей")
	var c := _town(12)
	var h := c.place("house_pleb", Land.START + Vector2(8.0 * 4, 8.0 * 2), 0.0, 0, 0, true)
	h["families"] = [{"name": "Квинты", "n": 1, "cls": "plebs"}]
	h["pop"] = 1
	c.compute()
	var L: Legion = c.legion
	_check(int(c.stats["pop"]) == 49 and not L.window_open() and L.lock_text() != "" and not (CAMP_TXT in L.army_tick()), "49 жителей: лагерь закрыт («%s»)" % L.lock_text())
	h["families"][0]["n"] = 2
	h["pop"] = 2
	c.compute()
	var m1 := L.army_tick()
	var m2 := L.army_tick()
	_check(int(c.stats["pop"]) == 50 and L.window_open() and L.lock_text() == "", "50 жителей: лагерь открыт")
	_check(CAMP_TXT in m1 and not (CAMP_TXT in m2), "сообщение «%s» — один раз" % CAMP_TXT)


const CAMP_TXT := "Лагерь открыт: призывайте жителей в Легион — кнопка «Лагерь» наверху"


func _recruit() -> void:
	print("== призыв жителя")
	var c := _town(13)
	var L: Legion = c.legion
	L.army_tick()
	var pop0 := int(c.stats["pop"])
	_check(pop0 == 52 and L.can_recruit_resident() == "", "52 жителя, призыв можно (%s)" % L.can_recruit_resident())
	var m0 := float(c.money)
	var s := L.recruit_resident()
	_check(not s.is_empty() and int(c.stats["pop"]) == pop0 - 1 and _fams_ok(c), "призыв: жителей %d → %d, семьи в домах сходятся" % [pop0, int(c.stats["pop"])])
	_check(String(s["from"]).contains(" безработн") and L.soldiers.size() == 1, "безработный первым: «%s»" % String(s["from"]))
	_check(String(s["cls"]) == "legionary" and L.worn(s).size() == 1 and Gear.weapon_class(L.worn(s)[0]) == "legionary" and int(L.worn(s)[0]["rarity"]) == 0,
		"новобранец — легионер с мечом даром")
	_check(float(c.money) == m0, "призыв бесплатный")
	# уволить — житель возвращается (ждёт жилья на площади)
	var sid := int(s["id"])
	var a0 := c.arrivals.size()
	_check(L.dismiss(sid) and L.soldiers.is_empty() and c.arrivals.size() == a0 + 1 and int(c.arrivals[-1]["n"]) == 1,
		"уволили: воинов %d, на площади ждёт %s" % [L.soldiers.size(), String(c.arrivals[-1]["name"]) if not c.arrivals.is_empty() else "никто"])
	_check(not L.items.any(func(it): return bool(it.get("free", false))), "меч даром не остался на складе")


## Не безработные: из работающей профессии, но не из еды, пока еды не хватает
func _pick_jobs() -> void:
	print("== откуда берут, если безработных нет")
	var c := _town(13)
	var L: Legion = c.legion
	L.army_tick()
	_work(c, "farm", Vector2(0, 40))
	_work(c, "bakery", Vector2(10, 40))
	c.stats["free"] = {"plebs": 0, "artisans": 0, "patricians": 0}
	_check(c.food_short() and (c.resident_pick() as Dictionary).is_empty(), "еды не хватает: поля и пекарни не трогают (взять некого)")
	_check(L.can_recruit_resident().begins_with("Некого"), "причина отказа: «%s»" % L.can_recruit_resident())
	_work(c, "sawmill", Vector2(20, 40))
	c.stats["free"] = {"plebs": 0, "artisans": 0, "patricians": 0}
	var pk := c.resident_pick()
	_check(String(pk.get("job", "")) == "sawmill", "берут из лесопилки: %s" % [pk])
	var pop0 := int(c.stats["pop"])
	var s := L.recruit_resident()
	_check(String(s.get("from", "")).contains("пильщ") and int(c.stats["pop"]) == pop0 - 1, "«%s»" % String(s.get("from", "")))


func _floor_roster() -> void:
	print("== пол 30 и места в лагере")
	var c := _town(7)
	var h := c.place("house_pleb", Land.START + Vector2(8.0 * 7, 0), 0.0, 0, 0, true)
	h["families"] = [{"name": "Секстии", "n": 2, "cls": "plebs"}]
	h["pop"] = 2
	c.compute()
	var L: Legion = c.legion
	L.army_tick()
	L.flags["camp_open"] = true                  # лагерь уже открывали
	_check(int(c.stats["pop"]) == 30 and L.can_recruit_resident().contains("мало жителей") and L.recruit_resident().is_empty()
		and int(c.stats["pop"]) == 30, "30 жителей: призыв отказал («%s»), жителей осталось %d" % [L.can_recruit_resident(), int(c.stats["pop"])])
	h["families"][0]["n"] = 3
	h["pop"] = 3
	c.compute()
	_check(L.can_recruit_resident() == "" and not L.recruit_resident().is_empty() and int(c.stats["pop"]) == 30, "31 → призвали одного, снова 30")
	_check(L.can_recruit_resident() != "" and L.recruit_resident().is_empty(), "дальше нельзя: 30 — предел")
	# предел мест: 4 + уровень казарм (1) = 5
	var c2 := _town(14)
	var L2: Legion = c2.legion
	L2.army_tick()
	var n := 0
	for i in 6:
		if not L2.recruit_resident().is_empty():
			n += 1
	_check(n == 5 and L2.soldiers.size() == 5 and L2.roster_cap() == 5 and L2.can_recruit_resident().contains("нет мест"),
		"казарма 1: воинов %d из %d, шестого не взяли («%s»)" % [L2.soldiers.size(), L2.roster_cap(), L2.can_recruit_resident()])
	var soldiers_only := L2.soldiers.size()
	L2.camp["barracks"] = 3
	_check(L2.roster_cap() == 7 and L2.can_recruit_resident() == "" and soldiers_only == 5, "казарма 3: мест %d" % L2.roster_cap())


func _gear_class() -> void:
	print("== оружие решает класс, четыре слота")
	var c := _town(13)
	var L: Legion = c.legion
	L.army_tick()
	var s := L.recruit_resident()
	var s2 := L.recruit_resident()
	var sid := int(s["id"])
	var res := {}
	for w in [["archer", "bow"], ["priest", "staff"], ["cavalry", "spear"], ["legionary", "sword"]]:
		var it := L.add_item({"slot": "weapon", "cls": String(w[0]), "rarity": 2, "ilvl": 1})
		L.equip(sid, int(it["id"]))
		res[w[1]] = String(L.soldier(sid)["cls"])
	_check(res == {"bow": "archer", "staff": "priest", "spear": "cavalry", "sword": "legionary"}, "оружие → класс: %s" % [res])
	# оружие с другого воина: у того — меч даром, класс легионер
	var bow := L.add_item({"slot": "weapon", "cls": "archer", "rarity": 1, "ilvl": 1})
	L.equip(int(s2["id"]), int(bow["id"]))
	L.equip(sid, int(bow["id"]))
	_check(String(L.soldier(sid)["cls"]) == "archer" and String(L.soldier(int(s2["id"]))["cls"]) == "legionary" and L.worn(L.soldier(int(s2["id"]))).size() == 1,
		"лук перешёл к другому воину: он лучник, прежний владелец снова легионер с мечом")
	L.unequip(sid, "weapon")
	_check(String(L.soldier(sid)["cls"]) == "legionary" and L.worn(L.soldier(sid)).size() == 1, "сняли оружие — меч даром, легионер")
	# щит — любому; знак — нельзя, и не считается
	var q := L.add_item({"slot": "offhand", "cls": "archer", "rarity": 1, "ilvl": 1})
	_check(L.can_equip(sid, int(q["id"])) == "" and L.equip(sid, int(q["id"])) and String(L.soldier(sid)["cls"]) == "legionary", "щит лучника — легионеру, класс прежний")
	var bd := L.add_item({"slot": "badge", "cls": "", "rarity": 3, "ilvl": 3})
	var g0 := L.gear_bonus(L.soldier(sid))
	L.soldier(sid)["gear"]["badge"] = int(bd["id"])
	var g1 := L.gear_bonus(L.soldier(sid))
	_check(L.can_equip(sid, int(bd["id"])) != "" and is_equal_approx(float(g0["atk"]), float(g1["atk"])) and L.worn(L.soldier(sid)).all(func(it): return it["slot"] != "badge"),
		"знак: надеть нельзя («%s»), если есть — не считается" % L.can_equip(sid, int(bd["id"])))
	L.soldier(sid)["gear"].erase("badge")
	var seen := {}
	var bad := false
	for i in 300:
		L.items.clear()
		var d := L._drop({"idx": 6, "boss": i % 3 == 0}, true)
		if d.has("slot"):
			seen[String(d["slot"])] = true
			if String(d["slot"]) == "weapon" and not (String(d["cls"]) in Soldiers.V3_CLASS_IDS):
				bad = true
	_check(Gear.SLOTS_V3.size() == 4 and seen.size() == 4 and not seen.has("badge") and not bad, "добыча: слоты %s, знака нет, оружие — четырёх классов" % [seen.keys()])
	var e := Legion.new()
	_check(Legion.UNITS["priest"]["hp"] == 170 and Legion.UNITS["priest"]["heal"] > 0.0 and Legion.UNITS["priest"]["armor"] == 12 and Legion.UNITS["priest"]["range"] == 6.0
		and Legion.UNITS["cavalry"]["hp"] == 240 and bool(Legion.UNITS["cavalry"]["backline"]) and Legion.UNITS["cavalry"]["armor"] == 22 and Legion.UNITS["cavalry"]["speed"] > 2.0,
		"жрец и всадник в таблице: числа и признаки")
	var st_l := L.soldier_stats(L.soldier(sid), "legionary")
	var st_a := L.soldier_stats(L.soldier(sid), "archer")
	var st_c := L.soldier_stats(L.soldier(sid), "cavalry")
	_check(float(st_l["vs"]["swift"]) >= 1.3 and float(st_l["vs"]["cavalry"]) >= 1.3 and float(st_l["vs"]["beast"]) >= 1.3
		and float(st_a["vs"]["armored"]) >= 1.3 and float(st_c["vs"]["ranged"]) >= 1.3 and bool(st_c["backline"]), "счётчики: легионер > всадник > лучник > легионер")
	e = null


func _squad() -> void:
	print("== отряд: пять мест в два ряда")
	var c := _town(14)
	var L: Legion = c.legion
	L.army_tick()
	var ids := []
	for i in 5:
		ids.append(int(L.recruit_resident()["id"]))
	var arch := L.add_item({"slot": "weapon", "cls": "archer", "rarity": 1, "ilvl": 1})
	var stf := L.add_item({"slot": "weapon", "cls": "priest", "rarity": 1, "ilvl": 1})
	var spr := L.add_item({"slot": "weapon", "cls": "cavalry", "rarity": 1, "ilvl": 1})
	L.equip(ids[3], int(arch["id"]))
	L.equip(ids[4], int(stf["id"]))
	L.equip(ids[2], int(spr["id"]))
	var open1 := []
	for i in 5:
		open1.append(L.set_place(i, ids[i]))
	_check(L.slots() == 3 and open1 == [true, true, true, false, false], "казарма 1: открыты 3 места %s" % [open1])
	L.camp["barracks"] = 3
	_check(L.slots() == 4 and L.set_place(3, ids[3]) and not L.set_place(4, ids[4]), "казарма 3: 4 места")
	L.camp["barracks"] = 5
	_check(L.slots() == 5 and L.set_place(4, ids[4]), "казарма 5: 5 мест")
	var sq := L.squad_v3()
	var rows := []
	var keys := []
	for u: Dictionary in sq:
		rows.append(int(u["row"]))
		keys.append(String(u["key"]))
	_check(rows == [0, 0, 0, 1, 1] and keys == ["legionary", "legionary", "cavalry", "archer", "priest"], "ряды в отряде %s, классы %s" % [rows, keys])
	var st := Legion.stage(0, 0, 0)
	var setup := L.make_battle(st, 5)
	var rows2 := []
	for u: Dictionary in setup["squad"]:
		rows2.append(int(u["row"]))
	_check(rows2 == [0, 0, 0, 1, 1] and setup["squad"].size() == 5, "ряды — в данных боя %s" % [rows2])
	# новая постановка: воин переходит с места на место
	L.set_place(0, ids[4])
	_check(int(L.squad3[0]) == ids[4] and int(L.squad3[4]) == 0, "воин не стоит на двух местах: %s" % [L.squad3])
	L.set_place(4, ids[0])
	# бой считается с жрецом и всадником (L3.2 научит их поведению; здесь — без падения)
	var setup2 := L.make_battle(st, 5)
	var res := LegionSim.new(setup2).run(true)
	_check(res.has("win") and res.has("total") and int(res["total"]) == 5, "бой с жрецом и всадником посчитан: win=%s" % res.get("win"))


func _camp() -> void:
	print("== лагерь: уровни, таймеры, строитель, потолок Штаба")
	var c := _town(13)
	var L: Legion = c.legion
	L.army_tick()
	var t := []
	for to in range(2, 9):
		t.append(roundi(Legion.camp_time_h(to) * 3600.0))
	_check(t == [300, 1800, 7200, 28800, 86400, 129600, 172800], "таймеры до 2…8 уровня, с: %s" % [t])
	_check(L.camp_level("hq") == 1 and L.camp_level("barracks") == 1 and L.camp_level("drill") == 1 and L.camp_level("forge") == 0
		and L.camp_level("mars") == 0 and L.camp_level("store") == 0, "старт: штаб, казарма, плац — 1; кузница, Марс, склад — не построены")
	var why := L.camp_can_upgrade("barracks")
	_check(why.contains("Выше Штаба"), "ни одно здание выше Штаба: «%s»" % why)
	_check(L.camp_can_upgrade("forge").contains("Штаб"), "кузницу со Штабом 1 не построить: «%s»" % L.camp_can_upgrade("forge"))
	var why_hq := L.camp_can_upgrade("hq")
	_check(why_hq.contains("город"), "Штабу нужен ранг города: «%s»" % why_hq)
	c.level = 1
	var m0 := float(c.money)
	var ok := L.camp_upgrade("hq")
	_check(ok and L.camp_left("hq") > 0.0 and absf(L.camp_left("hq") - 300.0) < 5.0 and float(c.money) < m0, "Штаб → 2: идёт %d с, заплачено %d" % [roundi(L.camp_left("hq")), roundi(m0 - float(c.money))])
	_check(L.camp_can_upgrade("drill").contains("Строитель занят"), "строитель один: «%s»" % L.camp_can_upgrade("drill"))
	L.upg["camp_hq"]["end"] = Legion.now() - 1.0
	var ev := L.tick()
	_check(L.camp_level("hq") == 2 and not L.camp_busy() and ev.any(func(x): return String(x).contains("Штаб")), "таймер вышел: Штаб %d, события %s" % [L.camp_level("hq"), ev])
	_check(L.camp_can_upgrade("forge") == "" and L.camp_can_upgrade("store") == "" and L.camp_can_upgrade("mars").contains("Штаб"), "кузница и склад — со Штабом 2, Марс — с 3: «%s»" % L.camp_can_upgrade("mars"))
	_check(L.camp_upgrade("forge") and L.camp_progress("forge") < 0.1, "кузницу строят")
	L.upg["camp_forge"]["end"] = Legion.now() - 1.0
	L.tick()
	_check(L.camp_level("forge") == 1 and L.forge_lvl() == 1 and L.available("forge"), "кузница построена: уровень %d" % L.camp_level("forge"))
	L.camp["barracks"] = 3
	L.camp["drill"] = 6
	_check(L.barracks_lvl() == 3 and L.roster_cap() == 7 and L.slots() == 4 and L.train_places() == 3, "казарма 3: мест в отряде %d, воинов до %d; плац 6: тренировок %d" % [L.slots(), L.roster_cap(), L.train_places()])
	L.camp["store"] = 2
	_check(L.store_cap() == Gear.STORE_BASE + 2 * Gear.STORE_PER and L.ration_cap() == 30, "склад 2: мест %d, пайков до %d" % [L.store_cap(), L.ration_cap()])
	L.camp["mars"] = 2
	_check(L.perk_max() == 7, "Марс 2: умения до %d" % L.perk_max())
	L.camp["hq"] = 12
	L.camp["barracks"] = 12
	_check(L.camp_can_upgrade("hq").contains("Максимальный") and L.camp_can_upgrade("barracks").contains("Максимальный"), "предел уровня")
	# таланты и умения
	var c2 := _town(13)
	var L2: Legion = c2.legion
	L2.army_tick()
	var s := L2.recruit_resident()
	_check(L2.can_talent(int(s["id"]), 0, 0).contains("Штабом 6") and not L2.talents_open(), "таланты скрыты до Штаба 6: «%s»" % L2.can_talent(int(s["id"]), 0, 0))
	L2.camp["hq"] = 6
	_check(L2.talents_open() and not L2.can_talent(int(s["id"]), 0, 0).contains("Штабом"), "Штаб 6: таланты открыты")
	_check(L2.open_perks().is_empty() and L2.can_upgrade_perk("oil").contains("Марса") and not L2.perks_open(), "умения скрыты, пока нет Храма Марса")
	L2.camp["mars"] = 1
	_check(L2.perks_open() and L2.open_perks().has("oil"), "Храм Марса построен: умения открыты")


func _rations() -> void:
	print("== пайки")
	var c := _town(13)
	var L: Legion = c.legion
	L.army_tick()
	_check(L.rations_now() == 20 and L.ration_cap() == 20, "в начале полный запас: %d из %d" % [L.rations_now(), L.ration_cap()])
	L.rations = 0.0
	for i in 24:
		L.on_hour()
	_check(L.rations_now() == 0 and L.collect_resource("rations") == 2 and L.rations_now() == 2 and L.rations_per_day() == 2.0, "сутки без пекарни: +%d" % L.rations_now())
	_work(c, "bakery", Vector2(0, 40))
	L.rations = 0.0
	for i in 24:
		L.on_hour()
	_check(L.bakeries_working() == 1 and L.collect_resource("rations") == 5 and L.rations_now() == 5 and L.rations_per_day() == 5.0, "сутки с пекарней: +%d (в день %.0f)" % [L.rations_now(), L.rations_per_day()])
	L.rations = 19.0
	for i in 24:
		L.on_hour()
	_check(L.collect_resource("rations") == 1 and L.rations_now() == 20, "запас не больше предела: %d" % L.rations_now())
	var st := Legion.stage(0, 0, 0)
	_check(L.ration_cost(st) == 2 and L.ration_cost({"boss": true}) == 4 and L.ration_cost({"junior": true}) == 4, "бой стоит 2, босс — 4")
	L.rations = 1.0
	_check(L.can_fight(st).contains("Нет пайков") or L.can_fight(st).contains("воинов"), "пайков мало — в бой нельзя: «%s»" % L.can_fight(st))
	for i in 3:
		L.recruit_resident()
	L.set_place(0, int(L.soldiers[0]["id"]))
	L.rations = 10.0
	_check(L.can_fight(st) == "", "пайков хватает, воин в отряде: бой разрешён («%s»)" % L.can_fight(st))
	var setup := L.make_battle(st, 3)
	L.apply_result(setup, {"win": false, "alive": 0, "total": 1, "fallen": [], "time": 10.0, "hp_left": 0.0, "inputs": [], "perks_used": {}, "summons": 0})
	_check(L.rations_now() == 8, "бой стоил 2 пайка: осталось %d" % L.rations_now())


func _hidden() -> void:
	print("== военные здания не ставятся на карту")
	var c := _town(13)
	var L: Legion = c.legion
	L.army_tick()
	c.level = 3
	var bad := []
	for t: String in Legion.V3_HIDDEN:
		if c.unlocked(t) or String(c.check_place(t, Land.START + Vector2(0, 60), 0.0)["err"]) == "":
			bad.append(t)
	_check(bad.is_empty() and Legion.V3_HIDDEN.size() == 10, "десять военных зданий закрыты: %s" % [bad])
	_check(c.unlocked("sawmill") and c.unlocked("smelter") and c.unlocked("tannery"), "мастерские остались в городе")
	var c0 := _town(1, 0)
	c0.research["legion"] = true
	c0.level = 3
	_check(c0.unlocked("barracks") and c0.unlocked("forge"), "старый город: казармы и кузница открыты")


func _save() -> void:
	print("== сохранение")
	var c := _town(14)
	var L: Legion = c.legion
	L.army_tick()
	var s := L.recruit_resident()
	var s2 := L.recruit_resident()
	var stf := L.add_item({"slot": "weapon", "cls": "priest", "rarity": 2, "ilvl": 2})
	L.equip(int(s2["id"]), int(stf["id"]))
	L.camp["forge"] = 2
	L.camp["barracks"] = 3
	L.set_place(0, int(s["id"]))
	L.set_place(3, int(s2["id"]))
	L.rations = 7.5
	c.level = 1
	L.camp_upgrade("hq")
	var d: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	var c2 := City.new(Land.new())
	c2.load_data(d)
	var L2: Legion = c2.legion
	L2.army_tick()
	_check(c2.legion_v == 3 and L2.v3() and L2.camp_level("forge") == 2 and L2.camp_level("barracks") == 3 and L2.camp_level("hq") == 1, "ворота и уровни лагеря после загрузки")
	_check(L2.upg.has("camp_hq") and L2.camp_busy(), "идущая стройка Штаба сохранилась")
	_check(L2.soldiers.size() == 2 and String(L2.soldier(int(s2["id"]))["cls"]) == "priest" and L2.soldier(int(s["id"])).has("res") and String(L2.soldier(int(s["id"]))["from"]) == String(s["from"]),
		"воины: %d, жрец остался жрецом, «откуда» и житель на месте" % L2.soldiers.size())
	_check(L2.squad3 == [int(s["id"]), 0, 0, int(s2["id"]), 0] and L2.slots() == 4 and absf(L2.rations - 7.5) < 0.01, "отряд %s, пайки %.1f" % [L2.squad3, L2.rations])
	var sq := L2.squad_v3()
	_check(sq.size() == 2 and int(sq[0]["row"]) == 0 and int(sq[1]["row"]) == 1 and String(sq[1]["key"]) == "priest", "в бою: первый ряд и жрец во втором")
	var ok := L2.dismiss(int(s2["id"]))
	_check(ok and c2.arrivals.size() == 1, "после загрузки увольнение возвращает горожанина")


func _choice3() -> void:
	var c := _town(14)
	var L: Legion = c.legion
	L.army_tick()
	var first := L.recruit_candidates()
	var again := L.recruit_candidates()
	_check(first.size() == 4 and first == again, "кандидаты стабильны, четыре карточки")
	if first.size() != 4:
		return
	var sorted := true
	for i in range(1, first.size()):
		sorted = sorted and int(first[i - 1]["stars"]) >= int(first[i]["stars"])
	var next := L.recruit_candidates(4, 1)
	_check(sorted and next.size() == 4 and first[0]["key"] != next[0]["key"], "лучшие первыми, следующая страница другая")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	var copy := City.new(Land.new())
	copy.load_data(saved)
	_check(copy.legion.recruit_candidates() == first, "кандидаты и звёзды переживают сохранение")
	var pick: Dictionary = first[2].duplicate()
	var expected_stars := int(pick["stars"])
	pick["stars"] = 99
	var population := int(c.stats["pop"])
	var soldier := L.recruit_resident(pick)
	_check(not soldier.is_empty() and soldier["name"] == pick["name"] and int(soldier["res"]["m"]["sd"]) == int(pick["sd"])
		and int(soldier["stars"]) == expected_stars and int(c.stats["pop"]) == population - 1, "выбрали именно этого жителя; звёзды считает модель")
	_check(L.recruit_resident(pick).is_empty() and int(c.stats["pop"]) == population - 1 and _fams_ok(c), "повторный выбор устаревшей карточки никого не забирает")
	_check(L.candidate_stars({"sd": 123, "job": "sawmill", "cls": "artisans", "age": 2}) >= L.candidate_stars({"sd": 123, "age": 1}), "опыт и ремесло повышают качество")
	# Реальная работа жителя; пищевые работники при нехватке еды исключены.
	_work(c, "bakery", Vector2(0, 40))
	var bakery := L.building_rec("bakery")
	var p: Dictionary = L.recruit_candidates()[0]
	var house: Dictionary = c.buildings[int(p["home"])]
	for family: Dictionary in house["families"]:
		for member: Dictionary in family.get("m", []):
			if int(member["sd"]) == int(p["sd"]):
				member["job"] = int(bakery["id"])
	var choices := c.resident_choices()
	_check(not c.food_short() or not choices.any(func(x: Dictionary): return x["key"] == p["key"]), "пекаря при нехватке еды не призывают")


func _hero3() -> void:
	var c := _town(14)
	var L: Legion = c.legion
	L.army_tick()
	var recruit := L.recruit_resident()
	L.set_place(0, int(recruit["id"]))
	c.hero = Hero.make("Гай Валерий", 0, Hero.PRESETS[0]["look"], true, 777)
	var population := int(c.stats["pop"])
	L.army_tick()
	L.army_tick()
	var hero: Dictionary = L.soldiers[0]
	var sid := int(hero["id"])
	_check(bool(hero.get("hero", false)) and L.soldiers.size() == 2 and int(L.squad3[0]) == sid and int(L.squad3[1]) == int(recruit["id"])
		and int(c.stats["pop"]) == population, "герой первый, прежний воин переехал, жителей не убыло")
	_check(not L.dismiss(sid) and not L.set_place(0, 0) and not L.set_place(2, sid), "героя нельзя уволить или убрать с первого места")
	var setup := L.make_battle(Legion.stage(0, 0, 0), 19)
	_check(setup.has("hero_look") and setup["squad"][0]["key"] == "hero" and setup["squad"][0]["place"] == 0, "герой в бою со своим обликом")
	L.glory = 10000
	var money := c.money
	var glory := L.glory
	_check(L.train_hero() and c.money < money and L.glory < glory and L.squad_v3().size() == 1, "тренировка стоит денег и Славы; герой занят")
	var old_clock := Legion.clock
	Legion.clock = float(L.hero_training["end"]) + 1.0
	L.tick()
	_check(L.hero_level() == 2 and L.hero_training.is_empty() and L.squad_v3().size() == 2, "герой вернулся на новом уровне")
	_check(Legion.hero_time_h(8) > Legion.hero_time_h(7) and Legion.hero_time_h(30) > Legion.hero_time_h(20), "таймер героя растёт и за таблицей")
	L.hero_lv3 = Legion.HERO_MAX3 - 1
	c.money = maxf(c.money, 1000000.0)              # тренировка у предела дорогая — казна полна
	L.glory = maxf(L.glory, 100000.0)
	_check(L.train_hero(), "герой может вырасти выше максимума обычных воинов")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	var copy := City.new(Land.new())
	copy.load_data(saved)
	copy.legion.army_tick()
	_check(copy.legion.hero_level() == Legion.HERO_MAX3 - 1 and not copy.legion.hero_training.is_empty()
		and bool(copy.legion.soldiers[0].get("hero", false)) and not copy.legion.dismiss(sid), "герой и его тренировка сохраняются")
	var entry := L.hero_entry()
	_check(int(entry.get("hero_v", 0)) == 3 and int(Legion.snap_hero(entry, 0.0, 0.0)["level"]) == L.hero_level(), "снимок V3 не обрезает уровень героя")
	Legion.clock = float(L.hero_training["end"]) + 1.0
	L.tick()
	_check(L.hero_level() == Legion.HERO_MAX3 and not L.train_hero(), "предел героя соблюдается")
	Legion.clock = old_clock


func _collection3() -> void:
	var c := _town(14)
	var L: Legion = c.legion
	L.army_tick()
	_work(c, "smelter", Vector2(0, 40))
	_work(c, "sawmill", Vector2(12, 40))
	_work(c, "tannery", Vector2(24, 40))
	var old_clock := Legion.clock
	Legion.clock = 200000.0
	L.mats_t = Legion.clock - 3600.0
	var before := L.mat("iron")
	L._mats_tick(Legion.clock)
	var pend := 0.0
	for r: String in L.pending_resources:
		pend += float(L.pending_resources[r])
	# какая мастерская встала в тесном городке — та и копит (место у плавильни бывает занято домами)
	_check(pend > 0.0 and L.mat("iron") == before, "мастерская копит до сбора, не в запас")
	for resource: String in Gear.MATS:
		var cap := L.resource_cap(resource)
		L.pending_resources[resource] = float(cap)
		L.mats[resource] = 0.0
		L.mats_t = Legion.clock - 72.0 * 3600.0
		L._mats_tick(Legion.clock)
		_check(float(L.pending_resources[resource]) == cap and L.collect_resource(resource) == cap and L.mat(resource) == cap,
			"полный накопитель стоит; сбор до предела: " + resource)
		L.pending_resources[resource] = 10.0
		_check(L.collect_resource(resource) == 0 and float(L.pending_resources[resource]) == 10.0, "полный запас сохраняет несобранное: " + resource)
		L.mats[resource] = cap - 3
		_check(L.collect_resource(resource) == 3 and L.mat(resource) == cap and float(L.pending_resources[resource]) == 7.0, "частичный сбор не теряет остаток: " + resource)
	L.rations = 0.0
	for i in 1000:
		L._rations_hour()
	_check(float(L.pending_resources["rations"]) == L.ration_cap() and L.rations_now() == 0
		and L.collect_resource("rations") == L.ration_cap(), "пайки тоже копятся до предела и собираются вручную")
	L.pending_resources["iron"] = 180.0
	var saved: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	var copy := City.new(Land.new())
	copy.load_data(saved)
	_check(float(copy.legion.pending_resources["iron"]) == 180.0, "загрузка до мастерских не обрезает накопитель")
	Legion.clock = old_clock


func _speed3() -> void:
	var c := _town(14)
	var L: Legion = c.legion
	L.army_tick()
	var old_clock := Legion.clock
	Legion.clock = 300000.0
	L.upg["camp_hq"] = {"to": 2, "end": Legion.clock + 86400.0, "total": 86400.0}
	L.hero_training = {"to": 2, "end": Legion.clock + 86400.0, "total": 86400.0}
	var money := c.money
	for i in 4:
		_check(L.speed_up("camp_hq" if i % 2 == 0 else "hero"), "ускорение %d" % (i + 1))
	var paid := c.money
	_check(paid < money and L.speed_remaining() == 0.0 and not L.speed_up("hero") and c.money == paid, "общий предел 2 ч, пятая попытка бесплатна и отклонена")
	_check(float(L.upg["camp_hq"]["end"]) == Legion.clock + 82800.0 and float(L.hero_training["end"]) == Legion.clock + 82800.0, "каждый клик убрал 30 мин")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	var copy := City.new(Land.new())
	copy.load_data(saved)
	_check(copy.legion.speed_remaining() == 0.0, "загрузка не сбрасывает суточный предел")
	c.day += 1
	_check(L.speed_remaining() == 7200.0 and L.speed_up("camp_hq"), "следующий игровой день возвращает лимит")
	c.money = 0.0
	_check(not L.speed_up("hero"), "без казны не ускорить")
	Legion.clock = old_clock


func _chests3() -> void:
	var c := _town(14)
	var other := _town(14)
	var L: Legion = c.legion
	var M: Legion = other.legion
	L.army_tick()
	M.army_tick()
	c.money = 0.0
	other.money = 0.0
	L._rng.seed = 91827
	M._rng.seed = 91827
	L.queue_chest("gold")
	M.queue_chest("gold")
	var a := L.open_chest("gold")
	var b := M.open_chest("gold")
	_check(a == b and not a.is_empty(), "фиксированное зерно даёт одинаковую добычу")
	_check(Gear.SLOTS_V3.has(String(a["item"]["slot"])) and int(a["item"]["rarity"]) in [0, 2, 3, 4]
		and int(a["rations"]) > 0 and int(a["iron"]) > 0 and int(a["money"]) > 0, "сундук содержит допустимую вещь и ресурсы")
	for i in 4:
		_check(L.queue_chest("wooden"), "место для сундука %d" % i)
	_check(not L.queue_chest("gold") and L.chest_queue.size() == 4 and L.open_chest("bronze").is_empty(), "максимум 4, чужой вид не открыть")
	L.ingots = 7
	var saved: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	var copy := City.new(Land.new())
	copy.load_data(saved)
	_check(copy.legion.ingots == 7 and copy.legion.chest_queue == L.chest_queue, "слитки и ожидающие сундуки сохраняются")
	_check(copy.legion.open_chest("wooden") == L.open_chest("wooden"), "JSON сохраняет следующий бросок RNG без потери 64 бит")
	while L.store_count() < L.store_cap():
		L.add_item({"slot": "armor", "rarity": 0, "ilvl": 1, "cls": ""})
	var rng_state := L._rng.state
	var count := L.chest_queue.size()
	_check(L.open_chest("wooden").is_empty() and L.chest_queue.size() == count and L._rng.state == rng_state, "полный склад не расходует сундук и RNG")
	var old := _town(2, 0)
	old.legion.army_tick()
	var old_save := old.legion.to_dict()
	_check(not old_save.has("ingots") and not old_save.has("hero_lv3") and not old.legion.queue_chest("gold")
		and old.legion.collect_resource("iron") == 0 and not old.legion.speed_up("camp_hq"), "V2 не получает новые ключи и действия")
	var empty := _town(14)
	empty.legion.from_dict({})
	_check(empty.legion.ingots == 0 and empty.legion.hero_level() == 1 and empty.legion.chest_queue.is_empty(), "старое V3 сохранение получает безопасные значения")


func _chest_award3() -> void:
	var c := _town(14)
	var L: Legion = c.legion
	L.army_tick()
	var soldier := L.recruit_resident()
	L.set_place(0, int(soldier["id"]))
	var setup := L.make_battle(Legion.stage(0, 0, 0), 17)
	var money := c.money
	var out := L.apply_result(setup, {"win": true, "alive": 1, "total": 1, "fallen": [], "time": 10.0,
		"hp_left": 1.0, "inputs": [], "perks_used": {}, "summons": 0})
	_check(L.chest_queue.size() == 1 and out.has("camp_chest") and out["camp_chest"] != "full", "первая победа гарантирует сундук")
	_check(c.money >= money, "награда не срезает уже накопленную казну выше предела")
