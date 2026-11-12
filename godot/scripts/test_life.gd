extends Node
## Жизнь построек (Life, владелец 12.11: «чтобы всё открывалось и взаимодействовало с жителями»): двери распахиваются
## перед жителями и прикрываются за ними, ставни Synty по часам (утром открыты, ночью закрыты), жители сидят на мебели
## домов, лавок, таверны. Улица из домов всех классов и лавок, снимки вблизи.
##   bash .work/py/gpu_run.sh res://test_life.tscn -- out=D:/CivCity/.work/life/<метка>/ part=all      → «LIFE DONE fails=0»
## part: doors | shut | seats | alive | all (через запятую); video=1 — кадры входа в дом подряд (out/frames_door/) для ролика

var game
var c: City
var ppl: People
var hud
var life: Life
var fails := 0
var out := "D:/CivCity/.work/life/t/"
var parts := ["all"]
var video := false
var B := []                                 # постройки улицы
const NO_LEAF := ["taberna"]                # вход — открытая арка двора (двустворчатый проём без створок)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.trim_prefix("out=")
		elif a.begins_with("part="):
			parts = Array(a.trim_prefix("part=").split(","))
		elif a == "video=1":
			video = true
	Game.boot = {"new": "1", "hour": "10"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func want(p: String) -> bool:
	return parts.has("all") or parts.has(p)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func secs(t: float) -> void:
	var w := 0.0
	while w < t:
		await get_tree().process_frame
		w += get_process_delta_time()


func check(ok: bool, what: String, extra = null) -> bool:
	print(("LIFE PASS " if ok else "LIFE FAIL ") + what + ("" if ok or extra == null else "  " + str(extra)))
	if not ok:
		fails += 1
	return ok


func shot(name: String) -> void:
	hud.advisor_panel.visible = false
	await frames(3)
	DirAccess.make_dir_recursive_absolute(out)
	get_viewport().get_texture().get_image().save_png(out + name)
	print("SHOT ", out + name)


## Поставить постройку у точки (ищем место по кругу)
func put(type: String, at: Vector2) -> Dictionary:
	for k in 60:
		var p := at + Vector2(cos(k * 2.4), sin(k * 2.4)) * (k * 0.3)
		var pl: Dictionary = game.placement(type, p)
		if pl["err"] == "":
			var b := c.place(type, pl["pos"], pl["yaw"], pl["variant"], pl["color"], true)
			game._show(b)
			return b
	print("LIFE NOTE не встало ", type, " у ", at)
	return {}


## Камера у входа постройки b: сбоку под углом (видно, как створка уходит внутрь)
func door_view(b: Dictionary, side := 30.0, d := 5.0, pitch := 22.0) -> void:
	var dp := c.door_point(b)
	var y: float = game.land.height_at(dp.x, dp.y)
	game.rig.set_view(Vector3(dp.x, y + 0.8, dp.y), rad_to_deg(float(b["yaw"])) + side, pitch, d)


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	c = game.city
	ppl = game.people
	hud = game.hud
	life = game.life
	game.can_save = false
	game.tutorial.step = Tutorial.STEPS.size()
	game.tutorial.card.visible = false
	c.tips["tut"] = -1
	c.tips["ui"] = 3
	hud.apply_reveal(3)
	for r in Defs.RESEARCH:
		c.research[r["id"]] = true
	c.level = 7
	c.money = 900000
	c.cozy_v = 1
	game.speed = 1.0
	ppl.max_vis = 400
	var X0 := 140.0
	var Z0 := 120.0
	game.clear_nature(Vector2(X0 + 45.0, Z0 + 6.0), 60.0)
	game.land.paint_line(Vector2(X0 - 6.0, Z0), Vector2(X0 + 112.0, Z0), 1.6, Land.Kind.ROAD, true)
	ppl.refresh(game.land.road_chunks.keys())
	await frames(4)
	# [тип, этажей]: дома всех классов (и этажей), лавки, таверна, термополий
	var spec := [["house_pleb", 1], ["house_artisan", 1], ["house_patrician", 1], ["house_pleb", 3], ["butcher", 1], ["bakery", 1],
		["cobbler", 1], ["house_artisan", 2], ["taberna", 1], ["thermopolium", 1], ["wineshop", 1]]
	var x := X0
	for e: Array in spec:
		var b := put(e[0], Vector2(x, Z0 + 4.0))
		x += 10.0 if String(e[0]) in ["house_patrician", "taberna", "thermopolium"] else 7.0
		if b.is_empty():
			continue
		if int(e[1]) > 1:
			b["tier"] = int(e[1])
			game._show(b)
		if c.is_house(b):
			b["pop"] = 3
			game._show(b)
		B.append(b)
	await frames(10)
	for b: Dictionary in B:
		var bp := c.blueprint(b)
		var inf := life.info(bp, String(b["type"]))
		print("LIFE INFO %s:%d id=%d doors=%s pairs=%d seats=%d" % [b["type"], int(b["tier"]), int(b["id"]), str((inf["doors"] as Array).map(func(d): return [bp.parts[int(d[0])][0], d[1], d[2]])),
			int(inf["pairs"]), (inf["seats"] as Array).size()])
	if want("doors"):
		await _doors()
	if want("shut"):
		await _shutters()
	if want("seats"):
		await _seats()
	if want("alive"):
		await _alive()
	print("LIFE DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


# ---------- двери ----------

## Ручки створок двери постройки и их нынешние места (для сверки «вернулось в точности»)
func leaf_xfs(b: Dictionary) -> Array:
	var bp := c.blueprint(b)
	var hs: Array = (game.visuals[int(b["id"])] as Dictionary)["h"]
	var out2 := []
	for d: Array in life.info(bp, String(b["type"]))["doors"]:
		var h: Array = hs[int(d[0])]
		for sub in (h[0] as Dictionary)["subs"]:
			out2.append((sub["mm"] as MultiMesh).get_instance_transform(int(h[1])))
	return out2


func _doors() -> void:
	game._set_hour(10.0)
	# у каждой постройки улицы: дверь нашлась, распахивается, прикрывается и встаёт точно как была
	for b: Dictionary in B:
		var nm := "%s%d" % [b["type"], int(b["tier"])]
		var inf := life.info(c.blueprint(b), String(b["type"]))
		if NO_LEAF.has(String(b["type"])):
			check((inf["doors"] as Array).is_empty(), "у %s вход без створки (открытый проём)" % nm)
			continue
		if not check(not (inf["doors"] as Array).is_empty(), "дверь найдена: " + nm):
			continue
		door_view(b)
		await frames(4)
		var x0 := leaf_xfs(b)
		await shot("door_%s_0.png" % nm)
		life.door(b, 0.9)
		check(life._doors.has(int(b["id"])), "дверь пошла (в кадре): " + nm)
		await secs(0.45)
		check(life.door_k(int(b["id"])) > 0.95, "распахнута: " + nm, life.door_k(int(b["id"])))
		var x1 := leaf_xfs(b)
		check(x1 != x0, "створка сдвинулась: " + nm)
		await shot("door_%s_1.png" % nm)
		await secs(1.4)
		check(not life._doors.has(int(b["id"])), "прикрылась: " + nm)
		check(leaf_xfs(b) == x0, "встала точно как была: " + nm)
	# вне кадра — ничего не происходит
	var b0: Dictionary = B[0]
	var far := c.door_point(b0) + Vector2(400.0, 300.0)
	game.rig.set_view(Vector3(far.x, 2.0, far.y), 0.0, 40.0, 20.0)
	await frames(4)
	life.door(b0, 1.0)
	check(not life._doors.has(int(b0["id"])), "вне кадра дверь не шевелится")
	# настоящий житель: входит в дом — дверь открывается, за ним закрывается; выходит — снова
	var h: Dictionary = B[0]
	ppl._make_family("Дверь", 3, int(h["id"]), c.door_point(h))
	var fam := ppl.residents.filter(func(r): return int(r["home"]) == int(h["id"]) and not r["child"])
	if not check(not fam.is_empty(), "жильцы для двери"):
		return
	for m: Dictionary in ppl.residents.filter(func(r): return int(r["home"]) == int(h["id"])):
		m["job"] = int(B[4]["id"])           # «на работу уже сходили»: дома сидят, сами дверью не хлопают
		m["done_today"] = true
	var r: Dictionary = fam[0]
	ppl._release(r)
	r["state"] = "idle"
	r["act"] = ""
	r["seq"] = []
	r["t"] = 999.0
	var dp := c.door_point(h)
	r["p"] = dp + City.facing(float(h["yaw"])) * 0.15
	door_view(h, 38.0, 4.6, 18.0)
	await frames(3)
	var cn: Citizen = ppl._node(r)
	r["fade"] = 1.0
	cn.set_alpha(1.0)
	ppl._place(r)
	await frames(10)
	var fdir := out + "frames_door/"
	if video:
		DirAccess.make_dir_recursive_absolute(fdir)
	var fi := 0
	var x0r := leaf_xfs(h)
	ppl._door_in(r, h, "home")
	var went := false
	var opened := false
	var t := 0.0
	var snaps := {0.15: "a", 0.6: "b", 1.1: "c", 2.2: "d", 3.4: "e"}
	while t < 3.6:
		await get_tree().process_frame
		t += get_process_delta_time()
		opened = opened or life.door_k(int(h["id"])) > 0.95
		went = went or (r["state"] == "home" and r["node"] == null)
		if video:
			get_viewport().get_texture().get_image().save_png(fdir + "f%04d.png" % fi)
			fi += 1
		for s: float in snaps.keys():
			if t >= s:
				await shot("door_walk_in_%s.png" % snaps[s])
				snaps.erase(s)
	check(opened, "житель входит — дверь распахнулась")
	check(went, "житель вошёл", [r["state"], r["node"]])
	check(not life._doors.has(int(h["id"])) and leaf_xfs(h) == x0r, "за ним дверь закрылась, как была")
	# выходит: дверь открывается перед ним
	var to := dp + City.axis(float(h["yaw"])) * 6.0 + City.facing(float(h["yaw"])) * 1.0
	ppl._go(r, to, "stroll")
	var opened2 := false
	t = 0.0
	var snaps2 := {0.3: "a", 1.0: "b", 2.6: "c"}
	while t < 2.8:
		await get_tree().process_frame
		t += get_process_delta_time()
		opened2 = opened2 or life.door_k(int(h["id"])) > 0.95
		if video:
			get_viewport().get_texture().get_image().save_png(fdir + "f%04d.png" % fi)
			fi += 1
		for s: float in snaps2.keys():
			if t >= s:
				await shot("door_walk_out_%s.png" % snaps2[s])
				snaps2.erase(s)
	check(opened2, "житель выходит — дверь распахнулась")
	await secs(1.0)
	check(not life._doors.has(int(h["id"])) and leaf_xfs(h) == x0r, "и снова закрылась, как была")


# ---------- ставни ----------

## Места всех створок ставен постройки (для сверки «вернулось в точности»)
func shut_xfs(b: Dictionary) -> Array:
	var hs: Array = (game.visuals[int(b["id"])] as Dictionary)["h"]
	var res := []
	for e: Array in life.info(c.blueprint(b), String(b["type"]))["shut"]:
		var h: Array = hs[int(e[0])]
		for sub in (h[0] as Dictionary)["subs"]:
			res.append((sub["mm"] as MultiMesh).get_instance_transform(int(h[1])))
	return res


## Камера перед фасадом постройки b (видны все окна)
func face_view(b: Dictionary, side := 18.0, d := 9.0, pitch := 14.0) -> void:
	var p: Vector2 = b["pos"]
	var y: float = game.land.height_at(p.x, p.y)
	var f := City.facing(float(b["yaw"]))
	var at := p + f * 1.0
	game.rig.set_view(Vector3(at.x, y + 2.2, at.y), rad_to_deg(float(b["yaw"])) + side, pitch, d)


func _shutters() -> void:
	var with := B.filter(func(b): return int(life.info(c.blueprint(b), String(b["type"]))["pairs"]) > 0)
	check(with.size() >= 5, "ставни нашлись у построек улицы: %d" % with.size())
	game._set_hour(12.0)
	await secs(1.0)
	var x0 := {}
	for b: Dictionary in with:
		x0[int(b["id"])] = shut_xfs(b)
		check(is_equal_approx(life.shut_k(int(b["id"])), 1.0), "днём открыты: %s" % b["type"])
	var shots := with.slice(0, 6)
	for b: Dictionary in shots:
		face_view(b)
		await frames(5)
		await shot("shut_%s%d_%d_0.png" % [b["type"], int(b["tier"]), int(b["id"])])
	# ночь: закрываются — вразнобой, плавно (камера у первого дома: в кадре — значит, с движением)
	var b0: Dictionary = shots[0]
	face_view(b0)
	await frames(3)
	game._set_hour(23.6)
	await secs(0.7)
	await shot("shut_close_mid_a.png")
	await secs(2.0)
	await shot("shut_close_mid_b.png")
	await secs(6.5)
	var closed := 0
	var total := 0
	for b: Dictionary in with:
		var np: int = life.info(c.blueprint(b), String(b["type"]))["pairs"]
		for pi in np:
			total += 1
			var w := life._want(b, pi, game.hour)
			if w == 0.0:
				closed += 1
			check(is_equal_approx(life.shut_k(int(b["id"]), pi), w), "ночью ставни по часам: %s пара %d" % [b["type"], pi], [life.shut_k(int(b["id"]), pi), w])
	check(closed > total / 2, "ночью закрыта большая часть ставен: %d из %d" % [closed, total])
	for b: Dictionary in shots:
		face_view(b)
		await frames(5)
		await shot("shut_%s%d_%d_1.png" % [b["type"], int(b["tier"]), int(b["id"])])
	# вся улица ночью: где-то ставни открыты и теплится огонёк
	var mid: Vector2 = (B[0]["pos"] as Vector2).lerp(B[B.size() - 1]["pos"] as Vector2, 0.35)
	game.rig.set_view(Vector3(mid.x, 1.0, mid.y), rad_to_deg(float(B[0]["yaw"])) + 25.0, 26.0, 26.0)
	await frames(8)
	await shot("shut_street_night.png")
	# пустой дом — закрыт и днём
	var hb: Dictionary = with.filter(func(b): return c.is_house(b))[0]
	hb["pop"] = 0
	game._set_hour(12.0)
	await secs(0.5)
	game._show(hb)
	await frames(3)
	check(life.shut_k(int(hb["id"])) == 0.0, "пустой дом стоит со ставнями закрытыми", life.shut_k(int(hb["id"])))
	hb["pop"] = 3
	game._show(hb)
	x0[int(hb["id"])] = shut_xfs(hb)
	# утро: открываются по одному
	game._set_hour(5.5)
	await secs(1.0)
	face_view(b0)
	await frames(3)
	game._set_hour(8.05)
	await secs(1.2)
	await shot("shut_open_mid_a.png")
	await secs(2.5)
	await shot("shut_open_mid_b.png")
	await secs(6.0)
	for b: Dictionary in with:
		check(is_equal_approx(life.shut_k(int(b["id"])), 1.0), "утром открыты: %s" % b["type"], life.shut_k(int(b["id"])))
		check(shut_xfs(b) == x0[int(b["id"])], "и встали точно как построены: %s%d" % [b["type"], int(b["tier"])])
	# далеко от камеры: ставни не трогаются вовсе, пока камера не подъедет
	var bf: Dictionary = with[with.size() - 1]
	var far := (bf["pos"] as Vector2) + Vector2(420.0, 330.0)
	game.rig.set_view(Vector3(far.x, 2.0, far.y), 0.0, 40.0, 20.0)
	await frames(3)
	game._set_hour(23.6)
	await secs(1.5)
	check(is_equal_approx(life.shut_k(int(bf["id"])), 1.0), "далеко от камеры — не трогаются", life.shut_k(int(bf["id"])))
	face_view(bf)
	await secs(8.0)
	check(life.shut_k(int(bf["id"])) < 1.0, "камера подъехала — догнали часы", life.shut_k(int(bf["id"])))


# ---------- мебель ----------

## Житель садится на место d (уже подошёл): череда «сесть — сидеть», снимок вблизи
func sit_at(r: Dictionary, d: Dictionary, name: String) -> void:
	ppl._release(r)
	ppl._claim(r, d)
	r["p"] = d["p"]
	r["state"] = "walk"
	r["goal"] = "errand"
	r["path"] = PackedVector2Array()
	var p: Vector2 = d["p"]
	game.rig.set_view(Vector3(p.x, game.land.height_at(p.x, p.y) + 0.5, p.y), rad_to_deg(float(d["yaw"])) + 35.0, 34.0, 4.4)
	await frames(3)
	ppl._begin(r)
	r["fade"] = 1.0
	if r["node"] != null:
		(r["node"] as Citizen).set_alpha(1.0)


func _seats() -> void:
	game._set_hour(12.0)
	var hosts := B.filter(func(b): return not life.seats(b).is_empty())
	print("LIFE NOTE мебель у: ", hosts.map(func(b): return "%s:%d" % [b["type"], life.seats(b).size()]))
	check(hosts.size() >= 3, "сиденья нашлись у нескольких построек: %d" % hosts.size())
	var tv: Array = B.filter(func(b): return b["type"] == "taberna")
	check(not tv.is_empty() and not life.seats(tv[0]).is_empty(), "у таверны — места за столами")
	check(life.seats(tv[0]).any(func(s): return bool(s[5])), "за столом таверны — пьют")
	# жильцы
	for k in [2, 3, 7]:
		if k < B.size() and c.is_house(B[k]):
			ppl._make_family("Мебель%d" % k, 4, int(B[k]["id"]), c.door_point(B[k]))
	var adults := ppl.residents.filter(func(r): return not r["child"] and not r.has("hero") and int(r["home"]) != int(B[0]["id"]))
	for m: Dictionary in adults:
		m["job"] = int(B[4]["id"])
		m["done_today"] = true
	check(adults.size() >= 4, "взрослых жителей хватает: %d" % adults.size())
	# поиск мебели вокруг улицы находит места
	var mid: Vector2 = (B[0]["pos"] as Vector2).lerp(B[B.size() - 1]["pos"] as Vector2, 0.5)
	var found := 0
	for k in 10:
		if not ppl._furn_target(adults[0], mid, 60.0).is_empty():
			found += 1
	check(found >= 8, "жители находят, где присесть (%d из 10)" % found)
	if found < 8:
		for b: Dictionary in hosts:
			var xf := c.xf(b)
			for s: Array in life.seats(b):
				var w: Vector3 = xf * (s[0] as Vector3)
				var mw: Vector3 = xf * (s[3] as Vector3)
				var pp := Vector2(w.x, w.z)
				var q := ppl._near_free(pp, 4)
				var f := Vector2(w.x - mw.x, w.z - mw.z).normalized()
				print("LIFE DBG %s seat=%s p=%s free=%s near=%s front=%s back=%s occ=%d" % [b["type"], s[0], pp, ppl._free(pp), q.distance_to(pp) if q != Vector2.INF else -1.0,
					ppl._front_free(Vector2(mw.x, mw.z), f, int(b["id"])), ppl._front_free(Vector2(mw.x, mw.z), -f, int(b["id"])), game.land.occ_at(pp)])
	# таверна: за столом с чашей; дом и лавка — на скамье
	var cases := []
	cases.append([tv[0], "taberna"])
	for b: Dictionary in hosts:
		if b["type"] != "taberna" and cases.size() < 4:
			cases.append([b, String(b["type"])])
	var i := 0
	var sat := []
	var seated := 0
	for cs: Array in cases:
		if i >= adults.size():
			break
		var b: Dictionary = cs[0]
		var r: Dictionary = adults[i]
		var d := ppl._furn_seat(r, b)
		for k in 30:                           # у таверны — место за столом (с чашей)
			if b["type"] != "taberna" or (not d.is_empty() and bool(d["drink"])):
				break
			d = ppl._furn_seat(r, b)
		if d.is_empty():
			print("LIFE NOTE у «%s» не подойти к мебели (стоит в траве у соседей)" % cs[1])
			continue
		i += 1
		seated += 1
		await sit_at(r, d, cs[1])
		await secs(3.2)
		check(r["act"] == "sit" and ppl._sitting(r), "сидит у «%s»" % cs[1], [r["act"], r["seq"]])
		if bool(d["drink"]):
			check(ppl.props_want(r) == ["cup"], "за столом таверны — чаша в руке", ppl.props_want(r))
			ppl._anim(r, "Sit_Drink", 0.0, 0.5)
			r["sw"] = 99.0
			var q: Vector2 = r["p"]
			var fb := City.facing(float(b["yaw"]))
			game.rig.set_view(Vector3(q.x, game.land.height_at(q.x, q.y) + 0.5, q.y) + Vector3(fb.x, 0, fb.y) * 0.5, rad_to_deg(float(b["yaw"])) + 25.0, 30.0, 4.2)
			await secs(1.2)
			await shot("seat_%s_drink.png" % cs[1])
		else:
			await shot("seat_%s.png" % cs[1])
		sat.append(r)
	check(seated >= 3 and sat.any(func(x): return bool(x.get("drink", false))), "садятся у разных построек: %d, за столом таверны — с чашей" % seated)
	# второй за тем же столом таверны — соседи болтают и пьют
	if i < adults.size():
		var r2: Dictionary = adults[i]
		var d2 := ppl._furn_seat(r2, tv[0])
		if check(not d2.is_empty(), "второе место за столами таверны"):
			await sit_at(r2, d2, "taberna2")
			await secs(3.5)
			check(r2["act"] == "sit" and ppl._sitting(r2), "второй гость сидит")
			var p: Vector2 = tv[0]["pos"]
			var f := City.facing(float(tv[0]["yaw"]))
			var at := p + f * 1.2
			game.rig.set_view(Vector3(at.x, game.land.height_at(at.x, at.y) + 0.4, at.y), rad_to_deg(float(tv[0]["yaw"])) + 20.0, 32.0, 6.5)
			await secs(1.5)
			await shot("seat_taberna_two.png")
	# место занято — второй туда же не сядет; постройку убрали — её мебели в поиске нет
	if not sat.is_empty():
		var r0: Dictionary = sat[0]
		var k0: int = int((r0["dest"] as Dictionary)["k"])
		var taken := false
		for k in 20:
			var dd := ppl._furn_seat(adults[adults.size() - 1], tv[0])
			if not dd.is_empty() and int(dd["k"]) == k0:
				taken = true
		check(not taken, "занятое место другому не предлагают")
	var hb: Dictionary = hosts.filter(func(b): return b["type"] != "taberna")[0]
	game._hide(hb)
	check(not life.seat_hosts(hb["pos"], 5.0).has(hb), "постройку убрали — её мебели в поиске нет")
	game._show(hb)
	check(life.seat_hosts(hb["pos"], 5.0).has(hb), "снова показали — мебель снова в поиске")
	# вечером столы таверны — гостям Spectacle
	game._set_hour(19.0)
	check(not life.seat_hosts(tv[0]["pos"], 5.0).has(tv[0]), "вечером мебель таверны жителям не предлагают")
	game._set_hour(12.0)


# ---------- живые мелочи: полив цветов, дети у фонтана ----------

## Житель уже на месте d — дело начинается (как в test_leisure)
func begin_at(r: Dictionary, d: Dictionary) -> void:
	ppl._release(r)
	ppl._claim(r, d)
	r["p"] = d["p"]
	r["state"] = "walk"
	r["goal"] = "errand"
	r["path"] = PackedVector2Array()
	ppl._begin(r)
	r["fade"] = 1.0
	if r["node"] != null:
		(r["node"] as Citizen).set_alpha(1.0)


func _alive() -> void:
	game._set_hour(8.5)
	# полив: у дома плебеев — ящик под окном и горшки у двери
	var h: Dictionary = B[0]
	var wl := life.water(h)
	check(not wl.is_empty(), "у дома есть цветы для полива: %d" % wl.size())
	ppl._make_family("Полив", 3, int(h["id"]), c.door_point(h))
	var fam := ppl.residents.filter(func(r): return int(r["home"]) == int(h["id"]) and not r["child"])
	for m: Dictionary in ppl.residents.filter(func(r): return int(r["home"]) == int(h["id"])):
		m["job"] = int(B[4]["id"])
		m["done_today"] = true
	var d := {}
	for k in 20:
		d = ppl._water_flowers(fam[0], h)
		if not d.is_empty():
			break
	if check(not d.is_empty(), "житель находит, где полить цветы"):
		var r: Dictionary = fam[0]
		var p: Vector2 = d["p"]
		game.rig.set_view(Vector3(p.x, game.land.height_at(p.x, p.y) + 0.5, p.y), rad_to_deg(float(h["yaw"])) + 40.0, 26.0, 3.8)
		await frames(3)
		begin_at(r, d)
		await secs(1.6)
		check(r["act"] == "water", "поливает", r["act"])
		await secs(0.6)
		check(ppl.props_want(r) == ["jug"], "с кувшином в руке", ppl.props_want(r))
		var fy := ppl._yaw_to(r["p"], d["face"])
		check(absf(angle_difference(float(r["yaw"]), fy)) < 0.3, "лицом к цветам", [r["yaw"], fy])
		await secs(0.4)
		await shot("alive_water.png")
		var p2: Vector2 = d["p"]
		game.rig.set_view(Vector3(p2.x, game.land.height_at(p2.x, p2.y) + 0.5, p2.y), rad_to_deg(float(h["yaw"])) - 60.0, 22.0, 3.4)
		await secs(0.5)
		await shot("alive_water_b.png")
		ppl._release(r)
		r["state"] = "idle"
		r["act"] = ""
	# дети у фонтана: фонтанчик на улице, дети прибегают и играют вокруг
	var X0: float = (B[0]["pos"] as Vector2).x
	var Z0: float = (B[0]["pos"] as Vector2).y
	var fb := put("smallfountain", Vector2(X0 + 30.0, Z0 - 6.5))     # у самой улицы, напротив домов
	if not check(not fb.is_empty(), "фонтанчик встал"):
		return
	await frames(5)
	ppl._make_family("Фонтан", 5, int(B[3]["id"]), c.door_point(B[3]))
	var kids := ppl.residents.filter(func(r): return r["child"])
	if not check(kids.size() >= 2, "дети есть: %d" % kids.size()):
		return
	var found := 0
	for k in 10:
		if not ppl._fountain_play(fb["pos"]).is_empty():
			found += 1
	check(found >= 8, "у фонтана находится место поиграть (%d из 10)" % found)
	for kd: Dictionary in kids.slice(0, 3):
		var dd := ppl._fountain_play(fb["pos"])
		if dd.is_empty():
			continue
		begin_at(kd, dd)
	var fp: Vector2 = fb["pos"]
	game.rig.set_view(Vector3(fp.x, game.land.height_at(fp.x, fp.y) + 0.3, fp.y), 30.0, 32.0, 7.0)
	await secs(2.5)
	var playing := kids.slice(0, 3).filter(func(kd): return kd["act"] == "play" and (kd["p"] as Vector2).distance_to(fp) < 7.0)
	check(playing.size() >= 2, "дети играют у фонтана: %d" % playing.size())
	await shot("alive_fountain_kids.png")
	await secs(1.5)
	await shot("alive_fountain_kids_b.png")
