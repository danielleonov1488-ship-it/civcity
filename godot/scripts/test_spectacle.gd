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
	check(not V.is_empty() and (V["lay"]["seats"] as Array).size() > 250, "места на трибунах: %d" % (0 if V.is_empty() else (V["lay"]["seats"] as Array).size()))
	game.speed = 3.0
	game._set_hour(12.5)
	var ok := await _until(func(): return V["phase"] == "gather", 20.0)
	check(ok, "по расписанию начался сбор")
	ok = await _until(func(): return _show_people() > 0, 20.0)
	check(ok, "горожане идут на представление: %d" % _show_people())
	ok = await _until(func(): return (V["who"] as Array).size() > 40, 30.0)
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
	_end()


func _end() -> void:
	print("SPEC DONE fails=%d" % fails)
	get_tree().quit()
