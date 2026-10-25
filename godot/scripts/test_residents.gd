extends Node
## Этап 6 (часть 1) плана от 24.10 (docs/PLAN_2026-10-24_tech.md 6.1–6.5, 6.9): жители с именами, семья в карточке дома,
## карточка жителя, обводка и «Следовать», кошки с именами и карточка кошки, облик (лавки и «Внешность»), «Горожане».
##   bash .work/py/gpu_run.sh res://test_residents.tscn            — новый город; в конце «RES DONE fails=0»
##   … -- mode=owner   — копия города владельца: члены семей создаются один раз и те же при второй загрузке (до сохранения),
##                        после сохранения — те же, работа та же, файл больше не больше чем на 5 %, облик взрослых тот же;
##                        щелчок по жителю на 34 м; поиск в «Горожанах» среди 578 жителей
## Снимки — .work/gd/a/res_*.png

const OWNER := "D:/CivCity/.work/owner_save/city.json"
const SHOTS := "D:/CivCity/.work/gd/a/"
var game
var c: City
var ppl: People
var hud
var fails := 0
var mode := ""
var cands := []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("mode="):
			mode = a.trim_prefix("mode=")
	if mode == "owner" and FileAccess.file_exists(OWNER):
		DirAccess.copy_absolute(OWNER, GamePaths.save_dir().path_join("city.json"))
		_boot({"play": "1", "hour": "11"})
	else:
		mode = ""
		_boot({"new": "1", "hour": "11"})
	_run()


func _boot(b: Dictionary) -> void:
	Game.boot = b
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)


## Загрузить город заново (тот же файл в папке сохранений)
func _reboot() -> void:
	game.queue_free()
	await frames(5)
	_boot({"play": "1", "hour": "11"})
	while not game.ready_done:
		await frames(5)
	_bind()
	await frames(5)


func _bind() -> void:
	c = game.city
	ppl = game.people
	hud = game.hud
	game.can_save = false


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, what: String, extra = null) -> bool:
	print(("RES PASS " if ok else "RES FAIL ") + what + ("" if ok or extra == null else "  " + str(extra)))
	if not ok:
		fails += 1
	return ok


func shot(name: String) -> void:
	hud.advisor_panel.visible = false          # совет советника не закрывает снимок
	await frames(8)
	DirAccess.make_dir_recursive_absolute(SHOTS)
	if mode == "owner" and not name.begins_with("res_owner"):
		name = name.replace("res_", "res_owner_")
	get_viewport().get_texture().get_image().save_png(SHOTS + name)
	print("SHOT ", name)


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	_bind()
	game.tutorial.step = Tutorial.STEPS.size()
	game.tutorial.card.visible = false
	c.tips["tut"] = -1
	c.tips["ui"] = 3
	hud.apply_reveal(3)
	await frames(5)
	if mode == "owner":
		await _owner()
	else:
		await _new()
	print("RES DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


# ---------- новый город ----------

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
	ppl.refresh(game.land.road_chunks.keys())
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
			var b := c.place(type, pl["pos"], pl["yaw"], pl["variant"], pl["color"], true)
			game._show(b)
			return b
	return {}


func _key(m: Dictionary) -> String:
	return "%s|%d" % [String(m.get("pn", "")), int(m.get("sd", 0))]


func _new() -> void:
	game.speed = 0.0
	c.money = 90000
	c.level = 4
	for r in Defs.RESEARCH:
		c.research[r["id"]] = true
	var o := Land.CENTER + Vector2(0, 14)
	street(o + Vector2(-26, 0), o + Vector2(26, 0))
	street(o + Vector2(-26, 12), o + Vector2(26, 12))
	street(o + Vector2(-26, 0), o + Vector2(-26, 12))
	var houses := []
	for i in 8:
		var h := put("house_pleb", o + Vector2(-20 + i * 5.5, 0))
		if not h.is_empty():
			houses.append(h)
	var shops := {}
	for t: String in ["stall_fruit", "bakery", "weaver", "barber", "dyer", "fullonica", "tailor", "jeweler", "butcher"]:
		shops[t] = put(t, o + Vector2(-20 + shops.size() * 5.0, 12))
	for i in 2:
		houses.append(put("house_artisan", o + Vector2(10 + i * 6, 12)))
	check(houses.size() >= 8 and not shops["barber"].is_empty() and not shops["dyer"].is_empty(), "город: дома и лавки поставлены", [houses.size(), shops.keys()])
	houses = houses.filter(func(h): return not h.is_empty())
	# семьи как после загрузки — во все дома, кроме двух: туда — семьи с повозки
	var k := 0
	for h: Dictionary in houses.slice(0, houses.size() - 2):
		var nm := "Проба%d" % k
		k += 1
		var n := c.house_cap(h)
		c.settled(int(h["id"]), n, nm)
		ppl._make_family(nm, n, int(h["id"]), c.door_point(h))
	c.compute()
	ppl._assign_jobs()
	# 6.1 правила: записи на месте, отец — мужчина, мать — женщина, имена в семье не повторяются, n = m
	var ok_rules := true
	var bad := []
	for id in c.buildings:
		for f: Dictionary in c.buildings[id].get("families", []):
			var ms: Array = f.get("m", [])
			var names := {}
			for m: Dictionary in ms:
				names[String(m["pn"])] = true
			var good := ms.size() == int(f["n"]) and names.size() == ms.size() and int(ms[0]["sx"]) == 0 and int(ms[0]["age"]) == 1 \
				and (ms.size() < 2 or (int(ms[1]["sx"]) == 1 and String(ms[1]["pn"]) == StoryDefs.nomen_f(String(f["name"]))))
			if not good:
				ok_rules = false
				bad.append(f)
	check(ok_rules, "члены семей: ровно n, отец и мать, имена не повторяются, мать — по роду", bad.slice(0, 2))
	check(Residents.gen("Юлии", 4, "plebs", 7) == Residents.gen("Юлии", 4, "plebs", 7), "одна семья с тем же ключом — те же люди")
	var any_nom := ppl.residents.filter(func(r): return not r.has("m")).size()
	check(any_nom == 0, "у каждого жителя запись члена семьи", any_nom)
	# повозка: седоки — те же люди, что сойдут на площадь (облик тот же)
	var load: Array = c.make_load(2)
	check(not load.is_empty(), "повозка везёт семьи", load.size())
	if not load.is_empty():
		ppl.cart["load"] = load
		ppl._cart_board(load)
		var seat_keys := []
		for rd: Citizen in ppl.cart["riders"]:
			seat_keys.append(Citizen.look_key(rd.look))
		var before := ppl.residents.size()
		ppl._drop()
		var walk_keys := []
		for r: Dictionary in ppl.residents.slice(before):
			walk_keys.append(Citizen.look_key(ppl.look_of(r)))
		seat_keys.sort()
		walk_keys.sort()
		check(seat_keys == walk_keys and not seat_keys.is_empty(), "в повозке и на площади — те же люди", [seat_keys.size(), walk_keys.size()])
		check(c.arrivals.size() >= 1 and (c.arrivals[0].get("m", []) as Array).size() == int(c.arrivals[0]["n"]), "на площади семья с членами", c.arrivals)
		# семья входит в дом: в записи дома — именно вошедшие
		var af: Dictionary = c.arrivals[0]
		var hh: Dictionary = houses[houses.size() - 2]
		if c.assign(String(af["name"]), int(hh["id"])):
			var fam := ppl._fam_members(String(af["name"]), int(hh["id"]))
			var r0: Dictionary = fam[0]
			r0["p"] = c.door_point(hh)
			r0["goal"] = "settle"
			ppl._arrive(r0)
			var hf: Dictionary = ppl._family_rec(String(af["name"]), int(hh["id"]))
			var same := not hf.is_empty() and (hf["m"] as Array).size() == int(hf["n"])
			for r: Dictionary in ppl._fam_members(String(af["name"]), int(hh["id"])):
				same = same and (hf["m"] as Array).any(func(x): return is_same(x, r["m"]))
			check(same, "семья вошла в дом: в доме записи вошедших (те же люди)", hf)
	c.compute()
	ppl._assign_jobs()
	for i in 3:
		ppl._new_cat()
	check(c.cats.size() >= 3 and ppl.cats.filter(func(x): return x.has("rec")).size() >= 3, "кошки с именами — в записи города", c.cats)
	# день идёт: кто на работе, кто в лавках
	game.speed = 1.0
	hud.set_speed(1.0)
	var mid := o + Vector2(0, 6)
	game.rig.set_view(Vector3(mid.x, Land.BASE_Y, mid.y), 200, 42, 34)
	await frames(240)
	await _pick_test(20)
	await _tip_test()
	await _building_click(houses)
	await _card_test()
	await _looks_test(shops)
	await _cat_test()
	await _house_card_test(houses)
	_search_test()
	await _demolish_test(houses)
	await _save_load_test()


## Щелчок по 20 случайным жителям на 34 м: ≥ 95 % — карточка именно его
func _pick_test(n: int) -> void:
	var cam: Camera3D = game.rig.cam
	var tried := 0
	var hit := 0
	var seen := 0
	# людей на улице мало — щёлкаем несколько раз, пока город живёт (за раунд — те, кто сейчас стоит отдельно)
	for round in 30:
		if tried >= n:
			break
		if round > 0:
			hud.close_panels()
			game._mouse_pos = Vector2(5, 5)      # мышь — в сторону (не задерживаться на прохожем: совет — в своей проверке)
			await frames(45)
		var vis := []
		for r in ppl.residents:
			var cz: Citizen = r["node"]
			if cz == null or float(r["fade"]) < 1.0 or not cz.is_visible_in_tree():
				continue
			var p := cz.global_position + Vector3(0, 0.45 * cz.scale.y / Citizen.SIZE, 0)
			if cam.is_position_behind(p) or not cam.is_position_in_frustum(p):
				continue
			vis.append([r, cam.unproject_position(p)])
		seen = maxi(seen, vis.size())
		# только те, рядом с кем на экране (40 точек) никого: иначе щелчок честно достанется ближнему к камере
		var lone := []
		var sz: Vector2 = get_viewport().get_visible_rect().size
		for e: Array in vis:
			var alone := true
			for e2: Array in vis:
				if e2 != e and (e2[1] as Vector2).distance_to(e[1]) < 40.0:
					alone = false
			for ct in ppl.cats:
				var cn: Node3D = ct.get("n")
				if cn and not cam.is_position_behind(cn.global_position) and cam.unproject_position(cn.global_position).distance_to(e[1]) < 40.0:
					alone = false
			if alone and (e[1] as Vector2).x > 40 and (e[1] as Vector2).y > 120 and (e[1] as Vector2).x < sz.x - 480 and (e[1] as Vector2).y < sz.y - 140:
				lone.append(e)
		lone.shuffle()
		for e: Array in lone.slice(0, mini(4, n - tried)):
			tried += 1
			hud.close_panels()
			game._mouse_pos = e[1]
			game._click()
			var sel: Dictionary = hud.info_p.get("r", {})
			if is_same(sel, e[0]) and hud.info_panel.visible and ppl.focus_rid == int(e[0]["id"]):
				hit += 1
			else:
				var pk: Dictionary = ppl.pick(e[1])
				var cz: Citizen = e[0]["node"]
				print("  промах: ", e[1], " ", People.name_of(e[0]), " → ", People.name_of(sel) if not sel.is_empty() else "—", " info_p=", hud.info_p.keys(),
					" pick=", pk.keys(), " узел=", cz != null, " голова=", cam.unproject_position(cz.hair_att.global_position) if cz and cz.hair_att else Vector2.ZERO,
					" ступни=", cam.unproject_position(cz.global_position) if cz else Vector2.ZERO, " state=", e[0]["state"], " act=", e[0]["act"])
	game._mouse_pos = Vector2(5, 5)
	check(tried >= n and hit >= int(ceil(tried * 0.95)), "щелчок по жителю на 34 м: %d из %d (на виду до %d)" % [hit, tried, seen])
	if hit > 0:
		await shot("res_card_person.png")


## Советник один раз: мышь задержалась на прохожем (не по времени — не мешает стройке)
func _tip_test() -> void:
	hud.close_panels()
	var cam: Camera3D = game.rig.cam
	var who := {}
	for r in ppl.residents:
		var cz: Citizen = r["node"]
		if cz != null and float(r["fade"]) >= 1.0 and cam.is_position_in_frustum(cz.global_position):
			who = r
			if r["state"] != "walk":
				break                             # стоит на месте — лучше всего
	if not check(not who.is_empty(), "житель на виду (для совета)"):
		return
	check(not c.tips.has("people_tip"), "совета о жителях ещё не было")
	# мышь держим на нём (идёт — ведём за ним), пока советник не скажет
	for i in 90:
		var cz: Citizen = who["node"]
		if cz == null:
			break
		game._mouse_pos = cam.unproject_position(cz.global_position + Vector3(0, 0.45 * cz.scale.y / Citizen.SIZE, 0))
		await frames(1)
		if c.tips.has("people_tip"):
			break
	check(c.tips.has("people_tip") and hud.advisor_panel.visible, "мышь задержалась на прохожем — советник рассказал о карточке жителя")
	hud.advisor_panel.visible = false
	game._mouse_pos = Vector2(5, 5)


## Щелчок мимо людей — карточка постройки, как раньше
func _building_click(houses: Array) -> void:
	var cam: Camera3D = game.rig.cam
	var real := 0
	var got := 0
	var tried := 0
	for h: Dictionary in houses:
		var p := Vector3((h["pos"] as Vector2).x, float(h["y"]) + 2.2, (h["pos"] as Vector2).y)
		if cam.is_position_behind(p) or not cam.is_position_in_frustum(p):
			continue
		var sp := cam.unproject_position(p)
		var vs: Vector2 = get_viewport().get_visible_rect().size
		if sp.x < 60 or sp.y < 140 or sp.x > vs.x - 480 or sp.y > vs.y - 140:
			continue                            # под окнами интерфейса щелчок не дошёл бы до города
		if not ppl.pick(sp).is_empty():
			continue
		tried += 1
		hud.close_panels()
		game._mouse_pos = sp
		game._click()
		# щелчок достался тому же, чему и без жителей (постройке на луче — этому дому или той, что перед ним), а не жителю
		var pb: Dictionary = game.pick_building()
		if hud.info_p.is_empty() and int(hud.info_b.get("id", -1)) == int(pb.get("id", -1)):
			got += 1
			real += 0 if pb.is_empty() else 1
		else:
			print("  мимо дома %d: info_p=%s info_b=%s" % [int(h["id"]), str(hud.info_p.keys()), str(hud.info_b.get("type", "—"))])
	check(real >= 2 and got == tried, "щелчок мимо людей — карточка постройки, как раньше (%d из %d, с постройкой %d)" % [got, tried, real])


func _texts(n: Node) -> String:
	var s := ""
	for l in n.find_children("*", "Label", true, false):
		s += (l as Label).text + "\n"
	for b in n.find_children("*", "Button", true, false):
		s += (b as Button).text + "\n"
	return s


## Карточка: имя, семья, работа, «Сейчас», «Желание»; «Следовать» — камера ведёт; Esc и WASD — перестаёт
func _card_test() -> void:
	var r := {}
	for x in ppl.residents:
		if int(x["job"]) >= 0 and x["node"] != null and not x["child"]:
			r = x
			break
	if not check(not r.is_empty(), "есть работник на виду"):
		return
	game.select_person({"r": r})
	await frames(3)
	var t := _texts(hud.info_box)
	var jb: Dictionary = c.buildings[int(r["job"])]
	check(t.contains(People.name_of(r)) and t.contains("Сейчас") and t.contains("Желание") and t.contains(String(c.def(jb)["name"])) \
		and t.contains("Следовать"), "карточка: имя, работа, «Сейчас», «Желание», «Следовать»", t.replace("\n", " | ").left(400))
	check(PersonCard._vp != null and PersonCard._who is Citizen, "живой портрет в карточке")
	var mats := 0
	for mi: MeshInstance3D in (r["node"] as Node).find_children("*", "MeshInstance3D", true, false):
		mats += 1 if mi.material_overlay != null else 0
	check(mats > 0, "выбранный обведён (material_overlay)", mats)
	var keep_view: Array = [game.rig.target, game.rig.yaw, game.rig.pitch, game.rig.dist]
	var sp: float = game.speed
	hud.set_speed(0.0)
	var pp0: Vector3 = ppl.person_pos(r)
	game.rig.set_view(pp0, rad_to_deg(game.rig.yaw), 32, 7)
	await shot("res_outline_near.png")
	game.rig.set_view(pp0, rad_to_deg(game.rig.yaw), 42, 34)
	await shot("res_outline_34.png")
	game.rig.set_view(keep_view[0], rad_to_deg(keep_view[1]), rad_to_deg(keep_view[2]), keep_view[3])
	hud.set_speed(sp)
	PersonCard.toggle_follow(hud, {"r": r})
	check(game.rig.following(), "«Следовать» — камера идёт за ним")
	await frames(150)
	var pp: Vector3 = ppl.person_pos(r)
	var d2 := Vector2(game.rig.target.x - pp.x, game.rig.target.z - pp.z).length()
	check(d2 < 1.5, "камера у жителя (%.2f м)" % d2)
	await shot("res_follow.png")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	game._unhandled_input(esc)
	check(not game.rig.following() and hud.info_panel.visible and not hud.info_p.is_empty(), "Esc — камера перестала следовать, карточка осталась")
	PersonCard.toggle_follow(hud, {"r": r})
	var w := InputEventKey.new()
	w.keycode = KEY_W
	w.physical_keycode = KEY_W
	w.pressed = true
	Input.parse_input_event(w)
	await frames(4)
	var wu := w.duplicate() as InputEventKey
	wu.pressed = false
	Input.parse_input_event(wu)
	check(not game.rig.following(), "WASD — камера перестала следовать")
	# выбранный рисуется и сверх MAX_VIS
	var mv: int = ppl.max_vis
	ppl.max_vis = ppl.visible_count
	var off := {}
	for x in ppl.residents:
		if x["node"] == null and ppl._drawable(x):
			off = x
			break
	if not off.is_empty():
		game.select_person({"r": off})
		await frames(2)
		check(off["node"] != null, "выбранный рисуется сверх MAX_VIS")
	ppl.max_vis = mv
	hud.close_panels()
	check(ppl.focus_rid == 0, "карточку закрыли — выбор снят")


## Облик: цирюльня у невидимого, дети без бород и венков, «Внешность» — сразу и на портрете
func _looks_test(shops: Dictionary) -> void:
	var r := {}
	for x in ppl.residents:
		if x["node"] == null and not x["child"] and not x["female"] and not (x["m"] as Dictionary).has("look"):
			r = x
			break
	if check(not r.is_empty(), "взрослый мужчина не на виду"):
		var lk0: Dictionary = ppl.look_of(r).duplicate()
		ppl.rng.seed = 12345
		for i in 60:
			ppl._shop_visit(r, "barber")
			if (r["m"] as Dictionary).has("look"):
				break
		var lk1: Dictionary = ppl.look_of(r)
		check((r["m"] as Dictionary).has("look") and (int(lk1["hair"]) != int(lk0["hair"]) or int(lk1["beard"]) != int(lk0["beard"])),
			"у цирюльника (не на виду) — новая стрижка или борода", [lk0.get("hair"), lk0.get("beard"), lk1.get("hair"), lk1.get("beard")])
	var rg := RandomNumberGenerator.new()
	rg.seed = 99
	var bad := 0
	for i in 500:
		var rr := RandomNumberGenerator.new()
		rr.seed = rg.randi()
		var fem := i % 2 == 0
		var cls: String = ["plebs", "artisans", "patricians"][i % 3]
		var lk := Citizen.roll_look(rr, fem, true, cls == "patricians", "", cls)
		var t: String = ["barber", "jeweler", "weaver", "dyer", "tailor", "fullonica"][i % 6]
		for k in 3:
			Looks.visit(lk, t, fem, true, cls, rg)
		var cz := Citizen.build(lk, true)
		var att := cz.hair_att.get_children().filter(func(x): return String(x.name).contains("Beard") or String(x.name).contains("Crown"))
		if int(lk["beard"]) != 0 or int(lk["crown"]) != 0 or not att.is_empty():
			bad += 1
		cz.free()
	check(bad == 0, "500 детей в лавках — ни бород, ни венков", bad)
	# «Внешность» в карточке: причёска ► — на улице и на портрете в тот же кадр
	var w := {}
	for x in ppl.residents:
		if x["node"] != null and not x["child"]:
			w = x
			break
	if not check(not w.is_empty(), "житель на виду для «Внешности»"):
		return
	game.select_person({"r": w})
	PersonCard.edit = true
	hud._fill_info()
	await frames(2)
	var nxt: Button = null
	for b in hud.info_box.find_children("*", "Button", true, false):
		if (b as Button).text == "►":
			nxt = b
			break
	if check(nxt != null, "«Внешность»: кнопки причёски"):
		var h0 := int(ppl.look_of(w)["hair"])
		nxt.pressed.emit()
		var h1 := int(ppl.look_of(w)["hair"])
		var who = PersonCard._who
		check(h1 != h0 and who is Citizen and int((who as Citizen).look["hair"]) == h1 and int((w["node"] as Citizen).look["hair"]) == h1,
			"причёска сменилась сразу: в записи, на улице и на портрете", [h0, h1])
		var sw: Button = null
		for b in hud.info_box.find_children("*", "Button", true, false):
			if (b as Button).tooltip_text == "Этот цвет":
				sw = b
		if check(sw != null, "«Внешность»: цвета одежды (ткацкая лавка, красильня)"):
			sw.pressed.emit()
			check(String(ppl.look_of(w).get("main", "")) != "", "цвет одежды выбран")
		await shot("res_looks.png")
	PersonCard.edit = false
	hud.close_panels()


## Кошка: щелчок — карточка с именем; «Погладить» — без звука и без пользы
func _cat_test() -> void:
	var cam: Camera3D = game.rig.cam
	var ct: Dictionary = {}
	for x in ppl.cats:
		if x.has("rec"):
			ct = x
			break
	if not check(not ct.is_empty(), "кошка с именем"):
		return
	ct["state"] = "sit"
	ct["t"] = 30.0
	var cp: Vector3 = ppl.cat_pos(ct)
	game.rig.set_view(Vector3(cp.x, Land.BASE_Y, cp.z), 200, 42, 34)
	await frames(20)
	var hits := 0
	for i in 20:
		var sp := cam.unproject_position(ppl.cat_pos(ct) + Vector3(0, 0.15, 0)) + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		var pk: Dictionary = ppl.pick(sp)
		if is_same(pk.get("cat", {}), ct):
			hits += 1
	check(hits >= 19, "щелчок по кошке на 34 м: %d из 20" % hits)
	game.select_person({"cat": ct})
	await frames(3)
	var t := _texts(hud.info_box)
	check(t.contains(String(ct["nm"])) and t.contains("Погладить") and t.contains("Сейчас"), "карточка кошки: имя, «Сейчас», «Погладить»", t.replace("\n", " | ").left(300))
	var sp0: float = game.speed
	hud.set_speed(0.0)                         # пауза: налоги и мяуканье по часам не путают проверку
	var money := c.money
	var hp := int(c.stats.get("happy", 0))
	var snd0: Dictionary = (game.sound.played as Dictionary).duplicate()
	ppl.pet_now(ct)
	await frames(2)
	check(ct["state"] == "pet" and (game.sound.played as Dictionary) == snd0 and not (ct["snd"] as AudioStreamPlayer3D).playing 		and is_equal_approx(money, c.money) and hp == int(c.stats.get("happy", 0)),
		"«Погладить»: кошка мурлычет без звука, городу ничего не прибавилось", [ct["state"], snd0, game.sound.played, money, c.money])
	hud.set_speed(sp0)
	game.rig.set_view(ppl.cat_pos(ct), 200, 34, 6)
	await shot("res_card_cat.png")
	hud.close_panels()


## Карточка дома: кто в семье; щелчок по фишке — карточка этого жителя
func _house_card_test(houses: Array) -> void:
	var h: Dictionary = houses[0]
	game.select_building(h)
	hud.open_info(h)
	await frames(3)
	var f: Dictionary = h["families"][0]
	var first := String(f["m"][0]["pn"])
	var chip: Button = null
	var cl: Node = hud.info_box.find_child("m_" + first, true, false)
	if cl != null:
		for b in cl.find_children("*", "Button", true, false):
			chip = b
	var t := _texts(hud.info_box)
	if check(chip != null and (t.contains(first + " —") or t.contains(first + ",")), "в карточке дома — члены семьи («%s — …»)" % first):
		await shot("res_house_family.png")
		chip.pressed.emit()
		await frames(2)
		var sel: Dictionary = hud.info_p.get("r", {})
		check(not sel.is_empty() and String(sel["m"]["pn"]) == first, "щелчок по члену семьи — его карточка")
	hud.close_panels()


## «Горожане»: поиск по имени и по семье
func _search_test() -> void:
	var r: Dictionary = ppl.residents[ppl.residents.size() / 2]
	var t0 := Time.get_ticks_usec()
	var res := PersonCard.search(ppl, String(r["pn"]), "")
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	check(res.any(func(x): return is_same(x, r)), "«Горожане»: поиск по имени «%s» находит (%.2f мс)" % [r["pn"], ms])
	var res2 := PersonCard.search(ppl, StoryDefs.fam_gen(String(r["fam"])), "")
	check(res2.any(func(x): return x["fam"] == r["fam"]), "«Горожане»: поиск по семье")
	var kids := PersonCard.search(ppl, "", "kids")
	check(kids.all(func(x): return x["child"]), "«Горожане»: фильтр «дети»")
	# окно «Жители и работники» → «Горожане»: строка поиска, строки жителей, щелчок — карточка и камера за ним
	hud._top_action("stats")
	hud.stats_tab = "people"
	hud._fill_stats()
	var q: LineEdit = hud.stats_panel.find_child("q", true, false)
	q.text = String(r["pn"])
	hud._fill_people()
	var list: Node = hud.stats_panel.find_child("plist", true, false)
	var rows := list.find_children("*", "Button", true, false)
	check(hud.stats_panel.visible and rows.size() >= 1 and _texts(list).contains(People.name_of(r)), "окно «Горожане»: найден «%s»" % People.name_of(r), rows.size())
	if not rows.is_empty():
		(rows[0] as Button).pressed.emit()
		check(not hud.stats_panel.visible and not hud.info_p.is_empty() and game.rig.following(), "строка в «Горожанах» — карточка жителя, камера за ним")
	hud.stats_tab = ""
	hud.close_panels()


## Дом снесли: семья на площади — те же люди; кошка дома — к ближнему дому
func _demolish_test(houses: Array) -> void:
	var h: Dictionary = {}
	var ct: Dictionary = {}
	for x in ppl.cats:
		if x.has("rec") and c.buildings.has(int(x["home"])):
			ct = x
			h = c.buildings[int(x["home"])]
			break
	if not check(not ct.is_empty() and not (h.get("families", []) as Array).is_empty(), "кошка живёт у дома с семьёй"):
		return
	var f: Dictionary = h["families"][0]
	var keys := (f["m"] as Array).map(func(m): return _key(m))
	c.remove(h)
	await frames(2)
	check(int(ct["home"]) != int(h["id"]) and c.buildings.has(int(ct["home"])) and int((ct["rec"] as Dictionary)["home"]) == int(ct["home"]),
		"дом снесли — кошка перешла к ближнему дому")
	var af: Dictionary = c.arrival(String(f["name"]))
	var keys2 := (af.get("m", []) as Array).map(func(m): return _key(m))
	keys.sort()
	keys2.sort()
	check(keys == keys2 and not keys.is_empty(), "семья снесённого дома на площади — те же люди", [keys, keys2])


## Сохранение → загрузка: члены семей, работа, облик, кошки — те же
func _save_load_test() -> void:
	ppl.sync_members()
	var mh := Residents.members_hash(c)
	var jobs := {}
	var looks := {}
	for r in ppl.residents:
		if r.has("m") and int(r["home"]) > 0:
			looks[_key(r["m"])] = Citizen.look_key(ppl.look_of(r))
			if int(r["job"]) >= 0:
				jobs[_key(r["m"])] = int(r["job"])
	var cats := c.cats.map(func(e): return "%s|%d|%d" % [e["nm"], int(e["fur"]), int(e["home"])])
	var data: Dictionary = game._save_data()
	var f := FileAccess.open(GamePaths.save_dir().path_join("city.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	await _reboot()
	check(Residents.members_hash(c) == mh, "загрузка: члены семей те же")
	var jok := 0
	var lok := 0
	for r in ppl.residents:
		if not r.has("m"):
			continue
		var k := _key(r["m"])
		if jobs.has(k) and int(r["job"]) == int(jobs[k]):
			jok += 1
		if looks.has(k) and Citizen.look_key(ppl.look_of(r)) == looks[k]:
			lok += 1
	check(jok == jobs.size() and jobs.size() > 0, "загрузка: работа та же (%d из %d)" % [jok, jobs.size()])
	check(lok == looks.size(), "загрузка: облик тот же (и сменённый в лавке) (%d из %d)" % [lok, looks.size()])
	var cats2 := c.cats.map(func(e): return "%s|%d|%d" % [e["nm"], int(e["fur"]), int(e["home"])])
	check(cats2 == cats and ppl.cats.filter(func(x): return x.has("rec")).size() == cats.size(), "загрузка: кошки те же (имя, окрас, дом)", [cats, cats2])


# ---------- город владельца ----------

func _adult_looks() -> String:
	var s := ""
	for id in c.buildings.keys():
		for f: Dictionary in c.buildings[id].get("families", []):
			for m: Dictionary in f.get("m", []):
				if int(m["age"]) >= 1:
					s += Citizen.look_key(Residents.look_of(m, String(c.def(c.buildings[id])["cls"]))) + ";"
	return s.sha256_text()


func _owner() -> void:
	var fams := 0
	var good := 0
	var people := 0
	for id in c.buildings:
		for f: Dictionary in c.buildings[id].get("families", []):
			fams += 1
			people += int(f["n"])
			if (f.get("m", []) as Array).size() == int(f["n"]):
				good += 1
	check(fams > 100 and good == fams, "город владельца: у всех %d семей члены (%d чел.)" % [fams, people], good)
	var h1 := Residents.members_hash(c)
	var l1 := _adult_looks()
	var t0 := Time.get_ticks_usec()
	var res := PersonCard.search(ppl, "Гай", "")
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	check(not res.is_empty() and ms < 16.0, "«Горожане»: «Гай» среди %d жителей — %.2f мс" % [ppl.residents.size(), ms])
	game.speed = 1.0
	hud.set_speed(1.0)
	var ctr: Dictionary = c.center()
	game.rig.set_view(Vector3((ctr["pos"] as Vector2).x, Land.BASE_Y, (ctr["pos"] as Vector2).y + 10), 200, 42, 34)
	await frames(200)
	await _pick_test(20)
	await _reboot()
	check(Residents.members_hash(c) == h1, "вторая загрузка до сохранения — те же члены семей")
	check(_adult_looks() == l1, "облик взрослых тот же")
	var size0 := FileAccess.get_file_as_string(OWNER).length()
	ppl.sync_members()
	var jobs := {}
	for r in ppl.residents:
		if r.has("m") and int(r["job"]) >= 0 and int(r["home"]) > 0:
			jobs[_key(r["m"])] = int(r["job"])
	var s := JSON.stringify(game._save_data())
	var f := FileAccess.open(GamePaths.save_dir().path_join("city.json"), FileAccess.WRITE)
	f.store_string(s)
	f.close()
	var grow := float(s.length()) / float(size0) - 1.0
	check(grow <= 0.05, "сохранение больше на %.1f %% (не больше 5 %%)" % (grow * 100.0), [size0, s.length()])
	await _reboot()
	check(Residents.members_hash(c) == h1, "после сохранения — те же члены семей")
	check(_adult_looks() == l1, "после сохранения — тот же облик")
	var jok := 0
	for r in ppl.residents:
		if r.has("m") and jobs.has(_key(r["m"])) and int(r["job"]) == int(jobs[_key(r["m"])]):
			jok += 1
	check(jobs.size() > 100 and jok == jobs.size(), "после сохранения — та же работа (%d из %d)" % [jok, jobs.size()])
	check(c.cats.size() > 0 and c.cats.size() == ppl.cats.filter(func(x): return x.has("rec")).size(), "кошки с именами в городе владельца (%d)" % c.cats.size())
	var r := {}
	for x in ppl.residents:
		if x["node"] != null and int(x["job"]) >= 0:
			r = x
			break
	if not r.is_empty():
		game.select_person({"r": r})
		await shot("res_owner_card.png")
		hud.close_panels()
