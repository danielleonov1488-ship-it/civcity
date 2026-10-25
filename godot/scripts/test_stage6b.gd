extends Node
## Решения владельца 25.10 (docs/PLAN_2026-10-24_additions.md): Д12 «Перестроить» и Д14 «Кошачья лавка».
##   bash .work/py/gpu_run.sh res://test_stage6b.tscn              — новая игра; в конце «S6B DONE fails=0»; снимки — .work/gd/b/s6b_*.png
##   … -- mode=owner                                               — копия города владельца: перенос сохранения, сколько домов помещается
##   … -- shots=0                                                  — без снимков (быстрее)
## Д12: дом плебеев → дом ремесленников → городской домус только щелчком игрока (инструмент, карточка), сам дом не растёт;
##      условия (класс, нужды, счастье после перестройки с запасом, место, денарии), семьи остаются («тесновато»),
##      условия уровня считают перестроенные дома, мазок вдоль улицы — одна строка в колокольчик, сохранение.
## Д14: «Кошачья лавка» работает, в ней кошки и вещицы; хозяева кошек из обслуженных домов покупают обновки (не больше
##      CAT_ITEMS_MAX), кошка носит вещь (узел на кости), карточка кошки — вещи и выбор в лавке, сохранение и старые сохранения.

const OWNER := "D:/CivCity/.work/owner_save/city.json"
const SHOTS := "D:/CivCity/.work/gd/b/"
var game
var c: City
var land: Land
var fails := 0
var mode := ""
var shots := true


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("mode="):
			mode = a.trim_prefix("mode=")
		if a == "shots=0":
			shots = false
	if mode == "owner" and FileAccess.file_exists(OWNER):
		DirAccess.copy_absolute(OWNER, GamePaths.save_dir().path_join("city.json"))
		Game.boot = {"play": "1", "hour": "11"}
	else:
		Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, what: String, extra = null) -> bool:
	print(("S6B PASS " if ok else "S6B FAIL ") + what + ("" if ok or extra == null else "  " + str(extra)))
	if not ok:
		fails += 1
	return ok


## cam — [откуда, куда]: камеру держим так каждый кадр (открытая карточка тянет камеру к выбранному)
func shot(name: String, cam: Array = []) -> void:
	if not shots:
		return
	if game.hud.advisor_panel.visible:
		game.hud.advisor_panel.visible = false      # советы в кадре не нужны (их проверяют свои проверки)
	for i in 12:
		if cam.size() == 2:
			game.rig.cine_look(cam[0], cam[1])
		await frames(1)
	DirAccess.make_dir_recursive_absolute(SHOTS)
	get_viewport().get_texture().get_image().save_png(SHOTS + name)
	print("SHOT ", SHOTS + name)


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	c = game.city
	land = game.land
	game.can_save = false
	if mode == "owner":
		await _owner()
	else:
		await _new()
	print("S6B DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


# ---------- помощники ----------

func _settle(b: Dictionary, tier: int, per := -1) -> void:
	var cls: String = c.def(b)["cls"]
	b["tier"] = clampi(tier, 1, Defs.floors_max(cls, int(b.get("variant", 0))))
	var n := int(Defs.CLASSES[cls]["per_floor"]) if per < 0 else per
	var fams := []
	for f in int(b["tier"]):
		fams.append({"name": Defs.FAMILIES[(int(b["id"]) * 3 + f) % Defs.FAMILIES.size()], "n": n})
	b["families"] = fams
	b["pop"] = n * int(b["tier"])
	game._show(b)


func place(type: String, at: Vector2, step := Vector2(0, -0.5), tries := 16, variant := -1) -> Dictionary:
	for k in tries:
		var pl: Dictionary = game.placement(type, at + step * k, variant)
		if pl["err"] == "":
			return c.place(type, pl["pos"], pl["yaw"], pl["variant"], pl["color"], true)
	print("S6B NOTE не встало %s у %s: %s" % [type, str(at), game.placement(type, at).get("err", "")])
	return {}


## Проверка загружает город поверх живой игры: кошкам на улице — их записи из загруженного (в игре загрузка — до кошек)
func _relink() -> void:
	for ct in game.people.cats:
		if ct.has("rec"):
			for rec: Dictionary in c.cats:
				if String(rec["nm"]) == String(ct["rec"]["nm"]):
					ct["rec"] = rec


func _raw(h: Dictionary) -> int:
	var s := 0
	for p: Array in h.get("happy_parts", []):
		s += int(p[1])
	return s


func _labels(n: Node) -> String:
	var out := []
	for l in n.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	for bt in n.find_children("*", "Button", true, false):
		out.append((bt as Button).text)
	return " | ".join(out)


# ---------- новая игра ----------

func _new() -> void:
	for r in Defs.RESEARCH:
		c.research[r["id"]] = true
	for t in ["upgrade_tool", "floor_tool", "cat_item_tip", "tax_tip", "set_tip", "prem_tip", "dim_tip", "fest_tip", "rank_tip"]:
		c.tips[t] = true                        # советы один раз — не в кадр
	c.level = 4
	c.money = 60000.0
	var X0 := 150.0
	var Z0 := 196.0
	game.clear_nature(Vector2(X0 + 22.0, Z0 + 6.0), 40.0)
	land.paint_line(Vector2(X0 - 6.0, Z0), Vector2(X0 + 52.0, Z0), 1.6, Land.Kind.ROAD, true)
	land.paint_line(Vector2(X0 - 6.0, Z0 + 14.0), Vector2(X0 + 52.0, Z0 + 14.0), 1.6, Land.Kind.ROAD, true)
	await frames(6)
	# ряд домов у дороги: плебеи (этажи 1, 2, 3, 3), ремесленники (2, 3); за последним плебейским — сосед вплотную
	var houses := []
	var spec := [["house_pleb", 1], ["house_pleb", 2], ["house_pleb", 3], ["house_pleb", 3], ["house_artisan", 2], ["house_artisan", 3], ["house_pleb", 2]]
	for k in spec.size():
		var hb := place(String(spec[k][0]), Vector2(X0 + k * 5.0, Z0 - 3.0), Vector2(0.3, 0), 8, k % 5)
		if not hb.is_empty():
			houses.append(hb)
	check(houses.size() == spec.size(), "ряд из %d домов у дороги" % spec.size(), houses.size())
	if houses.size() < spec.size():
		return
	for k in houses.size():
		_settle(houses[k], int(spec[k][1]))
	var hp1: Dictionary = houses[0]
	var hp3: Dictionary = houses[2]
	var ha3: Dictionary = houses[5]
	var hblk: Dictionary = houses[6]
	# фонтан вплотную за последним плебейским домом — дому ремесленников некуда расти назад
	var pb := 0.0
	for r: Rect2 in Catalog.make("house_pleb", 1, int(hblk["variant"]), 0).footprint():
		pb = minf(pb, r.position.y)
	var hf := 0.0
	for r: Rect2 in Catalog.make("fountain", 0, 0, 0).footprint():
		hf = maxf(hf, maxf(absf(r.position.y), absf(r.end.y)))
	var back: Vector2 = (hblk["pos"] as Vector2) + City.facing(float(hblk["yaw"])) * (pb - 0.3 - hf)
	var behind := c.place("fountain", back, float(hblk["yaw"]), 0, -1, true)
	c.compute()
	# --- до лавок: нужды класса не закрыты ---
	var why0 := c.can_upgrade(hp3)
	check(why0.contains("нужны ещё"), "без лавок дом не готов: «%s»" % why0)
	check(c.upgrade_to(hp1) == "house_artisan" and c.upgrade_to(ha3) == "house_patrician" and c.upgrade_to({"type": "house_patrician"}) == "",
		"плебеи → ремесленники → домус, выше некуда")
	check(c.upgrade_price(hp1) == 300 and c.upgrade_price(hp3) == 1200 and c.upgrade_price(ha3) == 3200, "цены по классу и этажам: 300 / 1200 / 3200",
		[c.upgrade_price(hp1), c.upgrade_price(hp3), c.upgrade_price(ha3)])
	check(c.upgrade_variant(ha3) >= Defs.PAT_TOWN and c.upgrade_tier(ha3) == 3, "дом ремесленников станет городским домусом в 3 этажа",
		[c.upgrade_variant(ha3), c.upgrade_tier(ha3)])
	# --- лавки всех видов и украшения напротив, через дорогу ---
	var shops := []
	var row := 0
	for t in ["stall_fruit", "weaver", "catshop", "musicians", "barber", "potter", "bakery", "dice", "cobbler", "herbalist"]:
		var s := place(t, Vector2(X0 + 2.0 + row * 5.5, Z0 + 3.4), Vector2(0.3, -0.12), 16)
		if not s.is_empty():
			shops.append(s)
		row += 1
	for k in 10:
		place("lamp_post", Vector2(X0 + 1.0 + k * 3.6, Z0 - 8.5), Vector2(0.3, -0.3), 8)
		place("flowers", Vector2(X0 + 2.5 + k * 3.6, Z0 - 9.5), Vector2(0.3, -0.3), 8)
	c.compute()
	var cs: Dictionary = {}
	for s in shops:
		if String(s["type"]) == "catshop":
			cs = s
	check(not cs.is_empty() and bool(cs.get("active", false)), "«Кошачья лавка» встала и работает", cs.get("why", "нет"))
	# --- дом сам не растёт: сутки игры — классы те же ---
	var types := {}
	for h in houses:
		types[int(h["id"])] = String(h["type"])
	for i in 24:
		c.sim_day()
	var same := true
	for h in houses:
		same = same and String(c.buildings[int(h["id"])]["type"]) == String(types[int(h["id"])])
	check(same, "за сутки ни один дом не перестроился сам")
	c.money = 60000.0
	c.compute()
	var whys := []
	for h in houses:
		whys.append("%d:%s/%d%%" % [int(h["id"]), c.can_upgrade(h), c.upgrade_happy(h)])
	print("S6B NOTE готовность: ", whys)
	var blk := c.can_upgrade(hblk)
	check(String(c.upgrade_place(hblk)["err"]) != "" and c._upgrade_blocker(hblk) != "", "за домом фонтан — дом ремесленников не помещается (мешает %s)" % c._upgrade_blocker(hblk))
	check(blk.begins_with("Не помещается") or not c.upgrade_missing(hblk).is_empty() or c.upgrade_happy(hblk) < 65, "у курсора — почему: «%s»" % blk)
	# --- карточка дома: галочки и кнопка ---
	game.select_building(hp3)
	game.hud.open_info(hp3)
	await frames(6)
	var card := _labels(game.hud.info_box)
	check(card.contains("Перестроить в дом ремесленников") and card.contains("Счастье после перестройки"), "карточка дома: «Перестроить» с условиями")
	if shots:
		var hp: Vector2 = hp3["pos"]
		game.rig.set_view(Vector3(hp.x, Land.BASE_Y, hp.y), rad_to_deg(float(hp3["yaw"])) + 20.0, 38, 22)
		await frames(10)
		for sc in game.hud.info_panel.find_children("house_scroll", "ScrollContainer", true, false):
			(sc as ScrollContainer).scroll_vertical = 100000      # вниз — к «Перестроить»
		await shot("s6b_house_card.png")
	game.hud.close_panels()
	# --- перестройка: тот же дом, семьи, цвет; счастье — как обещано ---
	if not check(c.can_upgrade(hp3) == "", "трёхэтажный дом плебеев готов к перестройке", c.can_upgrade(hp3)):
		return
	var promise := c.upgrade_happy(hp3)
	var id3 := int(hp3["id"])
	var fam0 := JSON.stringify(hp3["families"])
	var col0 := int(hp3["color"])
	var m0 := c.money
	var art0 := c.progress_of(["count", "house_artisan"])
	if shots:
		var mid: Vector2 = (houses[3]["pos"] as Vector2)
		game.rig.set_view(Vector3(mid.x, Land.BASE_Y, mid.y), rad_to_deg(float(hp3["yaw"])) + 18.0, 40, 34)
		game.set_tool("upgrade")
		await frames(30)
		await shot("s6b_upgrade_tool.png")
		game.set_tool("")
		var hp: Vector2 = hp3["pos"]
		game.rig.set_view(Vector3(hp.x, Land.BASE_Y + 2.0, hp.y), rad_to_deg(float(hp3["yaw"])) + 22.0, 26, 15)
		await frames(20)
		await shot("s6b_upgrade_before.png")
	check(c.upgrade_house(hp3), "перестроили дом")
	var h3: Dictionary = c.buildings.get(id3, {})
	check(not h3.is_empty() and String(h3["type"]) == "house_artisan" and int(h3["tier"]) == 3, "тот же дом №%d стал домом ремесленников в 3 этажа" % id3)
	check(JSON.stringify(h3["families"]) == fam0 and int(h3["color"]) == col0, "семьи и цвет фасада — прежние")
	check(absf(m0 - c.money - 1200.0) < 0.5, "списано 1200 ден.", m0 - c.money)
	check(_raw(h3) == promise, "счастье после перестройки — как обещал прогноз (%d)" % promise, _raw(h3))
	check(int(h3["pop"]) == 12 and c.house_cap(h3) == 9, "12 жильцов на 9 мест — тесновато, никто не выселен", [h3["pop"], c.house_cap(h3)])
	check(c.settled(id3, 2, "Новые") == 0, "в тесный дом новая семья не въезжает")
	check(c.progress_of(["count", "house_artisan"]) == art0 + 1, "условие «дома ремесленников» считает перестроенный дом")
	var occ_ok := true
	for k in (h3["cells"] as PackedInt32Array):
		occ_ok = occ_ok and land.occ[k] == id3
	check(occ_ok and (h3["cells"] as PackedInt32Array).size() > 0, "клетки дома — по новому облику, заняты им")
	game.set_tool("")
	await frames(60)
	if shots:
		await shot("s6b_upgrade_scaffold.png")
		await frames(240)
		await shot("s6b_upgrade_after.png")
	# жильцы — уже ремесленники
	var cls_ok := true
	for r in game.people.residents:
		if int(r["home"]) == id3:
			cls_ok = cls_ok and String(r["cls"]) == "artisans"
	check(cls_ok, "жильцы перестроенного дома — ремесленники")
	# --- в городской домус ---
	c.compute()
	var wa := c.can_upgrade(ha3)
	print("S6B NOTE домус: ", wa, " прогноз ", c.upgrade_happy(ha3))
	if wa.begins_with("Счастье"):
		# патрициям нужно 75%: ставим украшения поближе
		for k in 6:
			place("statue", (ha3["pos"] as Vector2) - City.facing(float(ha3["yaw"])) * 6.5 + City.axis(float(ha3["yaw"])) * (k - 2.5) * 2.2, Vector2(0, -0.4), 5)
		c.compute()
		wa = c.can_upgrade(ha3)
	if check(wa == "", "дом ремесленников готов стать домусом", wa):
		var ida := int(ha3["id"])
		c.upgrade_house(ha3)
		var hd: Dictionary = c.buildings[ida]
		check(String(hd["type"]) == "house_patrician" and int(hd["variant"]) >= Defs.PAT_TOWN and int(hd["tier"]) == 3, "стал городским домусом в 3 этажа",
			[hd["type"], hd["variant"], hd["tier"]])
		check(c.floor_price(hd) == 0 and Defs.floors_max("patricians", int(hd["variant"])) == 3, "городскому домусу выше трёх этажей не строят")
	# --- мазок инструментом: два дома за раз, одна строка в колокольчик ---
	var ready := c.upgrade_ready()
	print("S6B NOTE готовы к перестройке: ", ready)
	game.set_tool("upgrade")
	await frames(4)
	check(game.cover.state == "upgrade", "инструмент «Перестроить»: подсветка готовых домов")
	var mk: int = game.hud.badges.keys().filter(func(k): return String(k).begins_with("mo")).size()
	check(mk == ready.size() + (c.upgrade_ready(false).size() - ready.size()), "над готовыми домами — стрелки с ценой (%d)" % mk)
	var ev0 := c.events.size()
	game.floor_drag = true
	for id in ready.slice(0, 2):
		game._floor_buy(c.buildings[id])
	game._floor_end()
	var last := String(c.events[-1]["text"]) if c.events.size() > ev0 else ""
	check(ready.size() < 2 or (c.events.size() == ev0 + 1 and last.contains("Перестроили 2 дома")), "мазок: одна строка в колокольчик «%s»" % last)
	game.set_tool("")
	# --- сохранение: перестроенные дома те же после загрузки ---
	var sd := c.save_data()
	var js := JSON.stringify(sd)
	c.load_data(JSON.parse_string(js))
	_relink()
	var h3b: Dictionary = c.buildings.get(id3, {})
	check(not h3b.is_empty() and String(h3b["type"]) == "house_artisan" and int(h3b["pop"]) == 12, "после загрузки дом ремесленников с 12 жильцами")
	await _cats(cs, houses)


# ---------- кошки и «Кошачья лавка» ----------

func _cats(cs: Dictionary, houses: Array) -> void:
	var ppl: People = game.people
	c.compute()
	cs = c.buildings.get(int(cs.get("id", -1)), {})
	if not check(not cs.is_empty(), "лавка на месте после загрузки"):
		return
	var served: Array = cs.get("serves", [])
	check(not served.is_empty(), "лавка обслуживает дома рядом (%d)" % served.size(), [cs.get("active"), cs.get("why"), cs.get("staff"), cs.get("near_n"), cs.get("fill")])
	if served.is_empty():
		return
	# кошки с именами: у обслуженных домов и одна — далеко (у дома, который лавка не обслуживает)
	for k in 5:
		ppl._new_cat()
	var recs: Array = c.cats
	check(recs.size() >= 5, "в городе кошки с именами (%d)" % recs.size())
	var far := {}
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		if c.is_house(b) and not served.has(int(id)) and int(b["pop"]) > 0:
			far = b
	for i in recs.size():
		var rec: Dictionary = recs[i]
		rec.erase("it")
		rec.erase("wr")
		rec["home"] = int(served[i % served.size()]) if i > 0 or far.is_empty() else int(far["id"])
	for ct in ppl.cats:
		if ct.has("rec"):
			ct["home"] = int(ct["rec"]["home"])
	# хозяева покупают обновки: за много часов — у обслуженных, не больше CAT_ITEMS_MAX; у дальней — нет
	var ev0 := c.events.size()
	for i in 400:
		c.hour_n += 1
		c._cat_shop_hour()
	var got := 0
	var over := false
	for i in recs.size():
		var it: Array = recs[i].get("it", [])
		if i > 0 or far.is_empty():
			got += 1 if not it.is_empty() else 0
		over = over or it.size() > Defs.CAT_ITEMS_MAX
		if i > 0 or far.is_empty():
			over = over or (not it.is_empty() and not it.has(String(recs[i].get("wr", ""))))
	check(got >= recs.size() - 2, "у кошек обслуженных домов — обновки (%d из %d)" % [got, recs.size() - (0 if far.is_empty() else 1)])
	check(not over, "не больше %d вещиц, надета — своя" % Defs.CAT_ITEMS_MAX)
	check(far.is_empty() or (recs[0].get("it", []) as Array).is_empty(), "кошке у дома без лавки обновок не купили")
	var lines := c.events.slice(ev0).filter(func(e): return String(e["text"]).contains("«Кошачьей лавке»"))
	check(not lines.is_empty() and bool(c.tips.get("cat_item_first", false)), "покупки — в колокольчике (%d строк), советник узнает" % lines.size(),
		lines.slice(0, 1))
	# кошка носит вещь: на модели — узел на кости
	await frames(4)
	var dressed := 0
	for ct in ppl.cats:
		if String(People.cat_rec(ct).get("wr", "")) != "" and not (ct["n"] as Node).find_children("cat_acc*", "", true, false).is_empty():
			dressed += 1
	check(dressed >= got - 1 and dressed > 0, "кошки в обновках на улице (%d)" % dressed)
	# игрок выбирает кошке вещь в лавке: денарии, сразу надета; снять
	var rec0: Dictionary = recs[1]
	var left: Array = Defs.CAT_ITEM_ORDER.filter(func(x): return not (rec0.get("it", []) as Array).has(x))
	var m0 := c.money
	var pick: String = left[0] if not left.is_empty() else ""
	if pick != "":
		check(c.buy_cat_item(rec0, pick) and String(rec0["wr"]) == pick and absf(m0 - c.money - float(Defs.CAT_ITEMS[pick]["price"])) < 0.5,
			"игрок купил кошке «%s» за %d ден. — надета" % [Defs.CAT_ITEMS[pick]["name"], int(Defs.CAT_ITEMS[pick]["price"])])
	check(c.wear_cat_item(rec0, "") and String(rec0["wr"]) == "", "снять вещь")
	check(not c.wear_cat_item(rec0, "nosuch"), "чужую вещь не надеть")
	c.wear_cat_item(rec0, String((rec0["it"] as Array)[0]))
	# карточка кошки: вещи и выбор в лавке
	var ct1: Dictionary = {}
	for ct in ppl.cats:
		if is_same(People.cat_rec(ct), rec0):
			ct1 = ct
	if check(not ct1.is_empty(), "кошка этой записи — на улице"):
		ct1["p"] = (cs["pos"] as Vector2) + City.facing(float(cs["yaw"])) * 2.0 - City.axis(float(cs["yaw"])) * 1.6
		ct1["state"] = "sit"
		ct1["t"] = 999.0
		ppl._cat_place(ct1)
		game.select_person({"cat": ct1})
		game.hud.open_person({"cat": ct1})
		await frames(8)
		var txt := _labels(game.hud.info_box)
		check(txt.contains("Вещи") and txt.contains("Выбрать в «Кошачьей лавке»") and txt.contains(String(Defs.CAT_ITEMS[rec0["wr"]]["name"])),
			"карточка кошки: её вещи и выбор в лавке")
		if shots:
			# кошка у лавки — сверху вдоль улицы (лавку с трёх сторон обступают соседи и дома через дорогу)
			var cp: Vector3 = ppl.cat_pos(ct1)
			game.rig.set_view(cp, rad_to_deg(float(cs["yaw"])) + 90.0, 60, 9)
			await frames(30)
			await shot("s6b_cat_card.png")
		game.hud.close_panels()
	# карточка лавки
	game.select_building(cs)
	game.hud.open_info(cs)
	await frames(8)
	check(_labels(game.hud.info_box).contains("Сегодня на витрине"), "карточка «Кошачьей лавки»: витрина и товары")
	if shots:
		var sp: Vector2 = cs["pos"]
		game.rig.set_view(Vector3(sp.x, Land.BASE_Y, sp.y), rad_to_deg(float(cs["yaw"])) + 60.0, 62, 14)
		await frames(30)
		await shot("s6b_shop_card.png")
	game.hud.close_panels()
	# лавка: кошки внутри и вещицы на витрине
	var vis: Dictionary = game.visuals.get(int(cs["id"]), {})
	var pets: Array = vis.get("pets", [])
	var shop_cats := pets.filter(func(n): return is_instance_valid(n) and not (n as Node).find_children("*", "Skeleton3D", true, false).is_empty())
	var worn := shop_cats.filter(func(n): return not (n as Node).find_children("cat_acc*", "", true, false).is_empty())
	check(shop_cats.size() >= 4 and worn.size() >= 4 and pets.size() >= 8, "в лавке кошки (%d, в вещицах %d), вещицы и клубок (%d)" % [shop_cats.size(), worn.size(), pets.size()])
	if shots:
		game.hud.visible = false
		game.rig.cine = true
		var sp: Vector2 = cs["pos"]
		var f := City.facing(float(cs["yaw"]))
		var ax := City.axis(float(cs["yaw"]))
		var y0 := land.height_at(sp.x, sp.y)
		# спереди, чуть сбоку: вся лавка, кошки у двери, на прилавке и клубок
		var look := Vector3(sp.x + f.x * 0.7, y0 + 0.85, sp.y + f.y * 0.7)
		var eye := look + Vector3(f.x * 4.4 + ax.x * 0.7, 1.5, f.y * 4.4 + ax.y * 0.7)
		game.rig.cine_look(eye, look)
		await frames(40)
		await shot("s6b_catshop.png")
		# крупно: дверь, корзинка с кошкой, кошка у клубка
		var look2 := Vector3(sp.x + f.x * 0.9 - ax.x * 0.7, y0 + 0.4, sp.y + f.y * 0.9 - ax.y * 0.7)
		game.rig.cine_look(look2 + Vector3(f.x * 2.3 + ax.x * 0.5, 0.75, f.y * 2.3 + ax.y * 0.5), look2)
		await frames(40)
		await shot("s6b_catshop_close.png")
		# крупно: прилавок — кошка в шляпке, вещицы на подставках
		var look3 := Vector3(sp.x + f.x * 1.1 + ax.x * 0.9, y0 + 0.75, sp.y + f.y * 1.1 + ax.y * 0.9)
		game.rig.cine_look(look3 + Vector3(f.x * 2.0 - ax.x * 0.4, 0.55, f.y * 2.0 - ax.y * 0.4), look3)
		await frames(40)
		await shot("s6b_catshop_counter.png")
		# кошки в обновках на улице: в ряд перед лавкой, у каждой — своя вещица (все девять видов), крупно
		var row := ppl.cats.filter(func(x): return not People.cat_rec(x).is_empty())
		var k := 0
		for ct in row:
			var rr := People.cat_rec(ct)
			var item: String = Defs.CAT_ITEM_ORDER[k % Defs.CAT_ITEM_ORDER.size()]
			var it: Array = rr.get("it", [])
			if not it.has(item):
				it.append(item)
			rr["it"] = it
			rr["wr"] = item
			# два ряда у лавки: впереди пять, за ними остальные (со сдвигом)
			var r2 := 0 if k < 5 else 1
			var kk := k if k < 5 else k - 5
			var nr := 5 if r2 == 0 else row.size() - 5
			ct["p"] = sp + f * (1.95 + r2 * 0.75) + ax * (kk - (nr - 1) * 0.5 + r2 * 0.3) * 0.62
			ct["yaw"] = float(cs["yaw"]) + 0.5
			ct["state"] = ["sit", "walk", "sit", "pet", "sit", "walk", "sit"][k % 7]
			ct["path"] = PackedVector2Array()
			ct["t"] = 999.0
			k += 1
		game.speed = 0.0
		for i in 3:
			ppl._cats_step(0.016)
			await frames(1)
		var mid := Vector3(sp.x + f.x * 2.3, y0 + 0.22, sp.y + f.y * 2.3)
		game.rig.cine_look(mid + Vector3(f.x * 3.1 + ax.x * 0.3, 1.45, f.y * 3.1 + ax.y * 0.3), mid + Vector3(-f.x * 0.4, 0.2, -f.y * 0.4))
		await frames(30)
		await shot("s6b_cats_street.png")
		game.speed = 1.0
		game.rig.cine = false
		game.hud.visible = true
	# сохранение: вещицы кошек — в записи; старое сохранение и чужие id — без вещей
	var sd := c.save_data()
	var cat_js := JSON.stringify(sd["cats"])
	check(cat_js.contains("\"it\"") and cat_js.contains("\"wr\""), "вещицы кошек — в сохранении")
	var probe := {}
	City.cat_items_load({"it": ["bow", "nosuch", "bow"], "wr": "nosuch"}, probe)
	check(JSON.stringify(probe) == JSON.stringify({"it": ["bow"], "wr": ""}), "загрузка: только известные вещи, надето — из своих", probe)
	var old := {}
	City.cat_items_load({"nm": "Луна"}, old)
	check(old.is_empty(), "старая запись кошки — без вещей")
	c.load_data(JSON.parse_string(JSON.stringify(sd)))
	_relink()
	var same := true
	for i in mini(recs.size(), c.cats.size()):
		same = same and JSON.stringify(c.cats[i].get("it", [])) == JSON.stringify(sd["cats"][i].get("it", []))
	check(same, "после загрузки у кошек те же вещи")
	# без лавки игрок вещь не купит
	c.remove(c.buildings[int(cs["id"])], false)
	var rec2: Dictionary = c.cats[0]
	var left2: Array = Defs.CAT_ITEM_ORDER.filter(func(x): return not (rec2.get("it", []) as Array).has(x))
	check(left2.is_empty() or not c.buy_cat_item(rec2, String(left2[0])), "лавки нет — выбрать кошке вещь нельзя")


# ---------- город владельца ----------

func _owner() -> void:
	c.compute()
	var plebs := 0
	var fit_a := 0
	var arts := 0
	var fit_p := 0
	var reasons := {}
	for id in c.buildings:
		var h: Dictionary = c.buildings[id]
		if not c.is_house(h):
			continue
		var why := c.can_upgrade(h, false)
		var key := why.split(" ")[0] if why != "" else "готов"
		reasons[key] = int(reasons.get(key, 0)) + 1
		var chk := c.upgrade_place(h) if c.upgrade_to(h) != "" else {"err": "-"}
		match String(h["type"]):
			"house_pleb":
				plebs += 1
				fit_a += 1 if String(chk["err"]) == "" else 0
			"house_artisan":
				arts += 1
				fit_p += 1 if String(chk["err"]) == "" else 0
	print("S6B OWNER плебеев %d (помещается %d), ремесленников %d (городской домус помещается %d), причины %s" % [plebs, fit_a, arts, fit_p, reasons])
	check(plebs == 0 or fit_a * 100 >= plebs * 80, "город владельца: дом ремесленников помещается у %d из %d плебейских" % [fit_a, plebs])
	check(arts == 0 or fit_p * 100 >= arts * 80, "город владельца: городской домус помещается у %d из %d домов ремесленников" % [fit_p, arts])
	var bad := []
	for rec: Dictionary in c.cat_recs():
		if rec.has("it") or rec.has("wr"):
			bad.append(City.cat_rec_name(rec))
	check(bad.is_empty(), "старые кошки — без вещей (%d кошек)" % c.cat_recs().size(), bad)
	var types := {}
	for id in c.buildings:
		types[id] = String(c.buildings[id]["type"])
	for i in 12:
		c.sim_day()
	var ch := []
	for id in types:
		if c.buildings.has(id) and String(c.buildings[id]["type"]) != String(types[id]):
			ch.append(id)
	check(ch.is_empty(), "за 12 часов ни один дом не перестроился сам", ch)
	check(c.is_new("@upgrade") == c.research.has("artisans"), "кнопка «Перестроить» — с пометкой «НОВОЕ» в старом городе")
	game.set_tool("upgrade")
	await frames(10)
	check(game.cover.state == "upgrade", "инструмент «Перестроить» в городе владельца")
	if shots:
		await shot("s6b_owner_upgrade.png")
	game.set_tool("")
