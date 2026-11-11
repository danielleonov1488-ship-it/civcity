extends Node
## Досуг жителей (владелец 12.11: «чтобы они буквально взаимодействовали с миром, наслаждались природой»):
## нюхают цветы, отдыхают под деревом, умываются у фонтанчика, молятся у храма, любуются статуей, кормят уток,
## хлопают музыкантам, читают свиток на скамье. Проверка: место нашлось, череда движений — та, снимок вблизи.
##   bash .work/py/gpu_run.sh res://test_leisure.tscn -- out=D:/CivCity/.work/kit/leisure/      → «LEI DONE fails=0»

var game
var c: City
var ppl: People
var hud
var fails := 0
var out := "D:/CivCity/.work/kit/leisure/"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.trim_prefix("out=")
	Game.boot = {"new": "1", "hour": "10"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func secs(t: float) -> void:
	var w := 0.0
	while w < t:
		await get_tree().process_frame
		w += get_process_delta_time()


func check(ok: bool, what: String, extra = null) -> bool:
	print(("LEI PASS " if ok else "LEI FAIL ") + what + ("" if ok or extra == null else "  " + str(extra)))
	if not ok:
		fails += 1
	return ok


func shot(name: String) -> void:
	hud.advisor_panel.visible = false
	await frames(6)
	DirAccess.make_dir_recursive_absolute(out)
	get_viewport().get_texture().get_image().save_png(out + name)
	print("SHOT ", out + name)


## Поставить постройку или украшение у точки (ищем место по кругу)
func put(type: String, at: Vector2) -> Dictionary:
	for k in 40:
		var p := at + Vector2(cos(k * 2.4), sin(k * 2.4)) * (k * 0.35)
		var pl: Dictionary = game.placement(type, p)
		if pl["err"] == "":
			var b := c.place(type, pl["pos"], pl["yaw"], pl["variant"], pl["color"], true)
			game._show(b)
			return b
	print("LEI NOTE не встало ", type, " у ", at)
	return {}


func city_door(h: Dictionary) -> Vector2:
	return c.door_point(h)


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	c = game.city
	ppl = game.people
	hud = game.hud
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
	c.legion.glory = 1000.0
	game.speed = 1.0
	ppl.max_vis = 400
	var X0 := 140.0
	var Z0 := 120.0
	game.clear_nature(Vector2(X0 + 30.0, Z0 + 6.0), 40.0)
	game.clear_nature(Vector2(X0 + 85.0, Z0 + 6.0), 20.0)
	game.land.paint_line(Vector2(X0 - 6.0, Z0), Vector2(X0 + 100.0, Z0), 1.6, Land.Kind.ROAD, true)
	ppl.refresh(game.land.road_chunks.keys())
	await frames(4)
	var B := {}
	B["temple"] = put("temple", Vector2(X0 + 6.0, Z0 + 4.0))
	B["flowers"] = put("flowers", Vector2(X0 + 20.0, Z0 - 3.0))
	B["tree"] = put("tree", Vector2(X0 + 27.0, Z0 - 4.0))
	B["smallfountain"] = put("smallfountain", Vector2(X0 + 34.0, Z0 - 3.0))
	B["statue"] = put("statue", Vector2(X0 + 41.0, Z0 - 3.0))
	B["bench"] = put("bench", Vector2(X0 + 48.0, Z0 - 2.5))
	B["musicians"] = put("musicians", Vector2(X0 + 58.0, Z0 + 3.0))
	# утки — на пруду у (215, 150): ближе к берегу, чтобы с берега было видно
	var pc := Vector2(215.0, 150.0)
	# тропа к берегу (ходят только по мостовой и тропам), утки — у её конца
	var path_ok := false
	for k in 30:
		var q := pc + Vector2(13.0 - k * 0.45, 0.0)
		if not path_ok and game.land.hq(game.land.idx(game.land.cell(q - Vector2(2.6, 0)).x, game.land.cell(q - Vector2(2.6, 0)).y)) < Land.WATER_Y:
			game.land.paint_line(q + Vector2(6.0, -4.0), q + Vector2(-0.6, 2.5), 1.0, Land.Kind.ROAD, true)
			ppl.refresh(game.land.road_chunks.keys())
			path_ok = true
		var pl: Dictionary = game.placement("duck", q)
		if pl["err"] == "":
			B["duck"] = c.place("duck", pl["pos"], pl["yaw"], pl["variant"], pl["color"], true)
			game._show(B["duck"])
			break
	await frames(10)
	for t: String in B:
		check(not (B[t] as Dictionary).is_empty(), "встало: " + t)
	# семьи (в новом городе жителей ещё нет): три дома у той же улицы, по четыре человека
	for k in 3:
		var h := put(["house_pleb", "house_artisan", "house_patrician"][k], Vector2(X0 + 74.0 + k * 9.0, Z0 + 3.5))
		if not h.is_empty():
			ppl._make_family("Лейс%d" % k, 5, int(h["id"]), city_door(h))
	var adults := ppl.residents.filter(func(r): return not r["child"] and not r.has("hero"))
	check(adults.size() >= 8, "взрослых жителей хватает: %d" % adults.size())
	# [украшение, дело, ждём в череде, какое движение снять, через сколько секунд]
	var cases := [["flowers", "smell", "Smell", "Smell", 1.6], ["tree", "shade", "Stretch", "Stretch", 1.6],
		["smallfountain", "wash", "Wash", "Wash", 1.0], ["temple", "pray", "Pray", "Pray", 1.5], ["statue", "admire", "Point", "Point", 1.5],
		["duck", "feed", "Feed", "Feed", 0.5], ["musicians", "watch", "", "Clap", 1.2], ["bench", "sit", "SIT", "", 3.2]]
	var i := 0
	for cs: Array in cases:
		var base: String = cs[0]
		var bb: Dictionary = B.get(base, {})
		if bb.is_empty() or i >= adults.size():
			continue
		var r: Dictionary = adults[i]
		i += 1
		# места у этой постройки могли занять гуляющие жители (город живёт) — освобождаем для проверки
		var sp0: Dictionary = ppl.spots.get(bb["id"], {})
		for k in sp0.keys():
			var o: Dictionary = ppl.by_id.get(int(sp0[k]), {})
			if not o.is_empty() and o != r:
				ppl._release(o)
				o["state"] = "idle"
				o["t"] = 0.0
		var d: Dictionary
		if cs[1] == "watch":
			d = ppl._watch_target(r, bb)
		elif cs[1] == "sit":
			d = ppl._seat_target(r, bb)
		elif cs[1] in People.AROUND:
			d = ppl._around_target(r, bb, cs[1])
		else:
			d = ppl._front_target(r, bb, cs[1])
		if not check(not d.is_empty(), "%s: нашлось место у «%s»" % [cs[1], base]):
			var bp := c.blueprint(bb)
			var ring := []
			for a in 8:
				var q: Vector2 = (bb["pos"] as Vector2) + Vector2(cos(TAU * a / 8.0), sin(TAU * a / 8.0)) * 1.0
				ring.append([ppl._free(q), snappedf(game.land.hq(game.land.idx(game.land.cell(q).x, game.land.cell(q).y)), 0.01)])
			print("LEI NOTE ", base, " fp=", bp.footprint(), " pos=", bb["pos"], " ring1m=", ring, " water=", Land.WATER_Y)
			continue
		# житель — уже на месте (подошёл), дело начинается
		ppl._release(r)
		ppl._claim(r, d)
		r["p"] = d["p"]
		r["state"] = "walk"
		r["goal"] = "errand"
		r["path"] = PackedVector2Array()
		var p: Vector2 = d["p"]
		var face: Vector2 = d.get("face", p + City.facing(float(d.get("yaw", 0.0))))
		var cam_yaw := rad_to_deg(ppl._yaw_to(face, p)) + (150.0 if cs[1] in ["pray", "sit", "watch"] else 200.0)
		game.rig.set_view(Vector3(p.x, Land.BASE_Y, p.y), cam_yaw, 24.0, 4.2)
		await frames(3)
		ppl._begin(r)
		r["fade"] = 1.0
		if r["node"] != null:
			(r["node"] as Citizen).set_alpha(1.0)
		if cs[1] == "sit":
			r["read"] = true
		var names := (r["seq"] as Array).map(func(s): return String(s[0]))
		if String(cs[2]) != "":
			check(names.has(cs[2]) or names.has(String(cs[2]) + "_M"), "%s: в череде есть «%s»" % [cs[1], cs[2]], names)
		if String(cs[3]) != "":
			ppl._anim(r, cs[3], 0.0, 0.0)
			r["st"] = 99.0                     # снимок: держим это движение (череда дальше не идёт)
		await secs(float(cs[4]))
		if cs[1] == "sit":
			await secs(0.5)
			check(ppl.props_want(r) == ["scroll"], "читает на скамье: свиток в руке", ppl.props_want(r))
		var node: Citizen = r["node"]
		check(node != null, "%s: житель виден" % cs[1])
		await shot("lei_%s.png" % cs[1])
		game.rig.set_view(Vector3(p.x, Land.BASE_Y, p.y), cam_yaw + 180.0, 24.0, 4.2)
		await shot("lei_%s_b.png" % cs[1])
	print("LEI DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
