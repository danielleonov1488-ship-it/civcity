extends Node3D
## Зрелища в живой игре (готовый город, режим demo — ничего не сохраняет): ставим амфитеатр, часы идут сами —
## сбор (горожане идут к входу и садятся), бои, овация и расход; сохранение посреди представления; снос во время игр;
## на «Низкой» зрителей меньше. Запуск: bash .work/py/gpu_run.sh res://test_spectacle.tscn
var game
var fails := 0


func _ready() -> void:
	Game.boot = {"demo": "1", "noui": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, what: String) -> bool:
	print("SPEC %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1
	return ok


func _until(f: Callable, secs: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not f.call() and Time.get_ticks_msec() - t0 < secs * 1000.0:
		await frames(5)
	return f.call()


func _place_venue(type: String) -> Dictionary:
	var c: City = game.city
	c.research[Defs.B[type]["unlock"]] = true
	for ring in range(4, 30):
		for k in 16:
			var a := TAU * k / 16.0
			var p := Land.START + Vector2(cos(a), sin(a)) * ring * 4.0
			for yaw: float in [0.0, PI / 2, PI, -PI / 2]:
				var chk := c.check_place(type, p, yaw, 0, 0, -2)
				if chk["err"] == "" or chk["err"] == "Нужна дорога у входа":
					return c.place(type, p, yaw, 0, 0, true)
	return {}


func _show_people() -> int:
	var n := 0
	for r: Dictionary in game.people.residents:
		if r["act"] == "show" or str((r["dest"] as Dictionary).get("act", "")) == "show":
			n += 1
	return n


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(30)
	var sp: Spectacle = game.spectacle
	check(sp != null, "зрелища заведены в игре")
	var b := _place_venue("colosseum")
	if not check(not b.is_empty(), "амфитеатр встал в готовом городе"):
		_end()
		return
	await frames(10)
	var V: Dictionary = sp.venues.get(int(b["id"]), {})
	# новый маленький амфитеатр (NewArena, как четыре дома) — мест заметно меньше прежних двухсот
	var need := 40 if NewArena.covers("colosseum") else 200
	check(not V.is_empty() and (V["lay"]["seats"] as Array).size() > need, "места на трибунах (больше %d): %d" % [need, 0 if V.is_empty() else (V["lay"]["seats"] as Array).size()])
	game.speed = 3.0
	game._set_hour(12.5)
	var ok := await _until(func(): return V["phase"] == "gather", 20.0)
	check(ok, "по расписанию начался сбор")
	ok = await _until(func(): return _show_people() > 0, 20.0)
	check(ok, "горожане идут на представление: %d" % _show_people())
	var fill_n := mini(40, int((V["lay"]["seats"] as Array).size() * 0.6))     # у маленького амфитеатра всего ~50 мест
	ok = await _until(func(): return (V["who"] as Array).size() > fill_n, 30.0)
	check(ok, "трибуны заполняются: %d" % (V["who"] as Array).size())
	var rid_on := (V["who"] as Array).filter(func(s): return int(s["rid"]) > 0).size()
	ok = await _until(func(): return (V["who"] as Array).filter(func(s): return int(s["rid"]) > 0).size() > 0, 30.0)
	check(ok, "на трибунах — и сами горожане (по облику): %d" % (V["who"] as Array).filter(func(s): return int(s["rid"]) > 0).size())
	ok = await _until(func(): return V["phase"] == "show", 30.0)
	check(ok, "началось представление")
	ok = await _until(func(): return not (V["act"].pairs as Array).is_empty(), 10.0)
	check(ok, "на арене гладиаторы")
	# сидящие — на месте и лицом к арене
	var bad := 0
	var root: Node3D = V["root"]
	for s: Dictionary in V["who"]:
		if s["st"] != "sit":
			continue
		var seat: Dictionary = V["lay"]["seats"][s["seat"]]
		var p: Vector3 = seat["root"]
		var f := Vector3(sin(float(seat["yaw"])), 0, cos(float(seat["yaw"])))
		var to_c := -Vector3(p.x, 0, p.z).normalized()
		if f.dot(to_c) < 0.9:
			bad += 1
	check(bad == 0, "все сидящие лицом к арене (не так: %d)" % bad)
	# сохранение посреди игр
	var sd: Dictionary = game._save_data()
	check(not sd.is_empty(), "сохранение посреди представления собирается")
	ok = await _until(func(): return float(game.hour) >= 17.3 or V["phase"] == "leave", 0.1)
	game._set_hour(17.35)
	ok = await _until(func(): return V["phase"] == "leave", 20.0)
	check(ok, "представление кончилось — расходятся")
	ok = await _until(func(): return V["phase"] == "idle" and (V["who"] as Array).is_empty(), 60.0)
	check(ok, "все ушли с трибун (осталось %d)" % (V["who"] as Array).size())
	ok = await _until(func(): return game.people.residents.filter(func(r): return r["act"] == "show").is_empty(), 30.0)
	check(ok, "горожане вышли и пошли по делам")
	# снос посреди игр: никто не застрял
	game._set_hour(13.95)
	await _until(func(): return V["phase"] == "show" and (V["who"] as Array).size() > 50, 20.0)
	game.city.remove(b, false)
	await frames(20)
	check(not sp.venues.has(int(b["id"])), "снесли во время игр — площадка убрана")
	ok = await _until(func(): return game.people.residents.filter(func(r): return r["act"] == "show").is_empty(), 20.0)
	check(ok, "горожан со снесённой трибуны отпустили")
	# «Низкая» — зрителей меньше
	var b2 := _place_venue("colosseum")
	await frames(10)
	var V2: Dictionary = sp.venues.get(int(b2["id"]), {})
	sp._target(V2)
	var full: int = V2["target"]
	game.settings["quality"] = "low"
	sp._target(V2)
	check(int(V2["target"]) < full * 0.7, "на «Низкой» зрителей меньше: %d из %d" % [int(V2["target"]), full])
	game.settings["quality"] = "high"
	game.city.remove(b2, false)
	await _life()
	_end()


## «Уютный Рим», этап 3: утренняя служба в храме (люди стоят на ступенях лицом к жрецу) и купальщики в термах
func _life() -> void:
	var sp: Spectacle = game.spectacle
	var t := _place_venue("temple")
	var th := _place_venue("baths")
	if not check(not t.is_empty() and not th.is_empty(), "храм и термы встали"):
		return
	await frames(10)
	var T: Dictionary = sp.venues.get(int(t["id"]), {})
	var B: Dictionary = sp.venues.get(int(th["id"]), {})
	check(not T.is_empty() and (T["lay"]["seats"] as Array).size() >= 30 and (T["lay"] as Dictionary).has("priest"),
		"храм: мест на ступенях %d, жрец наверху" % (0 if T.is_empty() else (T["lay"]["seats"] as Array).size()))
	var wet := true
	for s: Dictionary in (B["lay"]["seats"] as Array):
		wet = wet and String(s["pose"]) == "bath" and (s["root"] as Vector3).y < -0.3
	check(not B.is_empty() and (B["lay"]["seats"] as Array).size() >= 10 and wet, "термы: купальщиков в бассейнах %d, по грудь в воде" % (B["lay"]["seats"] as Array).size())
	game._set_hour(6.95)
	var ok := await _until(func(): return T["phase"] == "gather" and T.has("priest_cp"), 20.0)
	check(ok, "в 7 утра — сбор на службу, жрец вышел")
	ok = await _until(func(): return (T["who"] as Array).filter(func(s): return s["st"] == "sit").size() > 10, 40.0)
	check(ok, "горожане стоят на службе: %d" % (T["who"] as Array).size())
	var bad := 0
	var pr: Vector3 = T["lay"]["priest"]["root"]
	for s: Dictionary in T["who"]:
		var seat: Dictionary = T["lay"]["seats"][s["seat"]]
		var f := Vector3(sin(float(seat["yaw"])), 0, cos(float(seat["yaw"])))
		var to_p := Vector3(pr.x - (seat["root"] as Vector3).x, 0, pr.z - (seat["root"] as Vector3).z).normalized()
		if f.dot(to_p) < 0.85:
			bad += 1
	check(bad == 0, "все на службе — лицом к жрецу (не так: %d)" % bad)
	game._set_hour(9.75)
	ok = await _until(func(): return B["phase"] == "gather" or B["phase"] == "show", 20.0)
	ok = ok and await _until(func(): return (B["who"] as Array).size() > 4, 40.0)
	check(ok, "термы открылись — купаются: %d" % (B["who"] as Array).size())
	game._set_hour(10.05)
	ok = await _until(func(): return T["phase"] == "idle" and (T["who"] as Array).is_empty() and not T.has("priest_cp"), 60.0)
	check(ok, "служба кончилась — все разошлись, жрец ушёл")
	# школа: утром дети на скамьях, учитель перед ними
	var sc := _place_venue("school")
	await frames(10)
	var S: Dictionary = sp.venues.get(int(sc.get("id", -1)), {})
	check(not S.is_empty() and (S["lay"]["seats"] as Array).size() >= 8 and (S["lay"] as Dictionary).has("priest"),
		"школа: мест на скамьях %d, учитель" % (0 if S.is_empty() else (S["lay"]["seats"] as Array).size()))
	if not S.is_empty():
		sp.force(int(sc["id"]), "show", 1.0, true)
		var kids := 0
		for s: Dictionary in S["who"]:
			kids += 1 if float((s["cp"] as Dictionary)["s"]) < Crowd.SIZE * 0.9 else 0
		check((S["who"] as Array).size() >= 8 and kids == (S["who"] as Array).size(), "на уроке — одни дети: %d из %d" % [kids, (S["who"] as Array).size()])
		sp.force(int(sc["id"]), "")
		game.city.remove(sc, false)
	# таверна (этап 5, только новая игра): вечером — за столиками и на скамьях, двое стоят у жаровни; взрослые
	var cv: int = game.city.cozy_v
	game.city.cozy_v = 1
	var tv := _place_venue("taberna")
	await frames(10)
	var TV: Dictionary = sp.venues.get(int(tv.get("id", -1)), {})
	var nsit := 0
	if not TV.is_empty():
		for st: Dictionary in TV["lay"]["seats"]:
			nsit += 1 if String(st["pose"]) == "sit" else 0
	check(not TV.is_empty() and nsit >= 6 and (TV["lay"]["seats"] as Array).size() > nsit, "таверна: сидячих мест %d, стоячих %d" % [nsit, 0 if TV.is_empty() else (TV["lay"]["seats"] as Array).size() - nsit])
	if not TV.is_empty():
		sp.force(int(tv["id"]), "show", 1.0, true)
		var grown := 0
		for st: Dictionary in TV["who"]:
			grown += 1 if float((st["cp"] as Dictionary)["s"]) >= Crowd.SIZE * 0.9 else 0
		check((TV["who"] as Array).size() >= 6 and grown == (TV["who"] as Array).size(), "вечер в таверне — одни взрослые: %d" % grown)
		var hr: float = game.hour
		game._set_hour(20.0)
		var tp: Vector2 = tv["pos"]
		game.rig.set_view(Vector3(tp.x, Land.BASE_Y, tp.y), rad_to_deg(float(tv["yaw"])) + 20.0, 46, 10)
		await frames(90)
		var img := get_viewport().get_texture().get_image()
		if img != null:
			DirAccess.make_dir_recursive_absolute("D:/CivCity/.work/spectacle")
			img.save_png("D:/CivCity/.work/spectacle/tavern_evening.png")
		game._set_hour(hr)
		sp.force(int(tv["id"]), "")
		game.city.remove(tv, false)
	# шествие перед играми: из Лудуса к амфитеатру — знаменосец и шестеро гладиаторов (новая игра)
	var lu := _place_venue("ludus")
	var co := _place_venue("colosseum")
	await frames(10)
	var CV: Dictionary = sp.venues.get(int(co.get("id", -1)), {})
	if not lu.is_empty() and not CV.is_empty():
		sp._procs.clear()
		var pth: PackedVector2Array = game.people._path(game.city.door_point(lu), game.city.door_point(co))
		print("SPEC путь шествия: точек %d, от %s до %s" % [pth.size(), game.city.door_point(lu), game.city.door_point(co)])
		sp._procession(CV)
		if sp._procs.is_empty() and pth.is_empty():
			sp._procession(CV, Land.START + Vector2(-20, 0), Land.START + Vector2(20, 4))   # в проверке у построек нет дорог — путь по площади
		var np: int = sp._procs.size()
		var hr2: float = game.hour
		var sp0: float = game.speed
		game.speed = 3.0
		var moved := await _until(func(): return sp._procs.filter(func(q): return is_instance_valid(q["f"]) and (q["f"] as Node3D).visible).size() >= 4, 30.0)
		check(np == sp.PROC_N + 1 and moved, "шествие: идут %d (видно не меньше четырёх)" % np)
		var lead: Dictionary = sp._procs[sp._procs.size() / 2] if not sp._procs.is_empty() else {}
		if not lead.is_empty() and is_instance_valid(lead["f"]):
			var fp: Vector3 = (lead["f"] as Node3D).position
			game.rig.set_view(fp, 30.0, 62, 14)
			await frames(30)
			var img2 := get_viewport().get_texture().get_image()
			if img2 != null:
				img2.save_png("D:/CivCity/.work/spectacle/procession.png")
		var done := await _until(func(): return sp._procs.is_empty(), 120.0)
		check(done, "шествие дошло до амфитеатра — все вошли")
		game.speed = sp0
		game._set_hour(hr2)
	if not co.is_empty():
		game.city.remove(co, false)
	if not lu.is_empty():
		game.city.remove(lu, false)
	game.city.cozy_v = cv
	var gone := [int(t["id"]), int(th["id"])]
	game.city.remove(t, false)
	game.city.remove(th, false)
	await frames(10)
	# в готовом городе свои храм и термы тоже живут — смотрим только тех, кто шёл в снесённые
	var stuck := func() -> int: return game.people.residents.filter(func(r): return r["act"] == "show" and int((r["dest"] as Dictionary).get("bid", -1)) in gone).size()
	ok = await _until(func(): return stuck.call() == 0, 20.0)
	check(ok, "снесли храм и термы — горожан отпустили (осталось %d)" % stuck.call())


func _end() -> void:
	print("SPEC DONE fails=%d" % fails)
	get_tree().quit()
