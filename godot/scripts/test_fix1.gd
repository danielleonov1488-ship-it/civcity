extends Node3D
## FIX1: проверки модели и пять кадров. Запускает Claude, сохранения игрока не пишем.

var out := "D:/CivCity/.work/stage2/fix1/shots/"
var game
var fails := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2 and pair[0] == "out":
			out = pair[1].trim_suffix("/") + "/"
	Game.boot = {"new": "1", "hour": "10"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	game.can_save = false
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, reason: String) -> bool:
	if not ok:
		fails += 1
		print("FIX1 FAIL " + reason)
	return ok


func shot(file: String) -> void:
	await frames(12)
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(out + file)
	if check(error == OK, "save " + file):
		print("FIX1 SHOT " + out + file)


func texts(node: Node) -> String:
	var result := ""
	if node is Label or node is Button:
		result += String(node.text) + "\n"
	for child in node.get_children():
		result += texts(child)
	return result


func _run() -> void:
	var waited := 0
	while not game.ready_done:
		await frames(5)
		waited += 5
		if waited >= 18000:
			check(false, "ready_done timeout")
			_finish()
			return
	game.can_save = false
	game.settings["autosave"] = false
	game.settings["advisor_off"] = true
	I18n.set_lang("ru")
	game.speed = 0.0
	game.tutorial.step = Tutorial.STEPS.size()
	game.tutorial.card.visible = false
	game.tutorial.set_process(false)
	game.city.tips["tut"] = -1
	game.city.tips["ui"] = 3
	game.hud.apply_reveal(3)
	game.hud.close_panels()
	game.hud.advisor_panel.visible = false
	if not check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory"):
		_finish()
		return
	var c: City = game.city
	var hud: Hud = game.hud
	c.money = 1000000
	c.level = 2
	c.research["farm"] = true
	c.research["floor2"] = true
	c.research["floor3"] = true
	var station := c.center()
	if station.is_empty():
		station = c.place("center", Land.START, 0.0, 0, 0, true)
	var h := c.place("house_pleb", Land.START + Vector2(18, 0), 0.0, 0, 0, true)
	if not check(not h.is_empty() and not station.is_empty(), "fixtures"):
		_finish()
		return
	h["tier"] = 3
	h["families"] = [{"name": "Юлии", "n": 2}]
	h["pop"] = 2
	game._show(h)
	c.compute()
	_capacity(c, h)
	_arrivals(c, h)
	_returning(c, h)
	check(c.house_free_floors(h) == 2, "three floors with one family leave two floors")
	check(c.house_room_text(h) == "Место ещё для 2 семей", "house room wording")
	for type: String in ["windmill", "windmill_2"]:
		check(hud._types_in("decor", "yard").has(type), type + " in decor")
		check(not hud._types_in("farming").has(type), type + " absent from farming")
		check(not bool(Defs.B[type].get("research_list", true)), type + " absent from research list")
		check(c.unlocked(type) == c.unlocked("farm"), type + " unlock follows farm")
	var farm_known: bool = c.research.has("farm")
	c.research.erase("farm")
	check(not c.unlocked("windmill") and not c.unlocked("windmill_2"), "windmills locked before farms")
	if farm_known:
		c.research["farm"] = true
	game.rig.set_view(Vector3(h["pos"].x, h["y"], h["pos"].y), 20, 38, 30)
	hud.open_dsub = "yard"
	hud.decor_query = "мельниц"
	hud.decor_mode = "search"
	hud._toggle_cat("decor")
	await shot("1_decor_menu.png")
	hud._toggle_cat("farming")
	await shot("2_farm_menu.png")
	hud._close_tray()
	await _birds(h)
	hud.visible = true
	hud.house_more = false
	game.rig.set_view(Vector3(h["pos"].x, h["y"] + 2.0, h["pos"].y), 20, 36, 24)
	game.select_building(h)
	hud.open_info(h)
	check(texts(hud.info_box).contains("Место ещё для 2 семей"), "house card shows free families")
	await shot("4_house_card.png")
	var f := c.new_family("plebs")
	c.family_arrived(f, false)
	game.people._on_resident_returned(f)
	c.set_arrivals_paused(true)
	hud._update_world_icons()
	var key := "b%d" % int(station["id"])
	check(not hud.badges.has(key), "station does not duplicate waiting family badge")
	game.rig.set_view(Vector3(station["pos"].x, station["y"] + 1.0, station["pos"].y), 20, 38, 30)
	game.select_building(station)
	hud.open_info(station)
	check(texts(hud.info_box).contains("Пауза: новые семьи не едут") and texts(hud.info_box).contains("Отказать"), "post card pause and refuse")
	await shot("5_post_card.png")
	_station_click(station)
	game.start_settle(String(f["name"]))
	check(texts(hud.variant_box).contains("Отказать"), "waiting family card refuses")
	var happy := int(c.stats["happy"])
	for button in hud.variant_box.get_children():
		if button is Button and button.text == "Отказать":
			button.pressed.emit()
			break
	check(c.arrival(String(f["name"])).is_empty(), "refuse button removes arrival")
	check(int(c.stats["happy"]) == happy, "refuse has no happiness penalty")
	check(not game.people.waiting_family_pos(String(f["name"])).is_finite(), "refuse removes family figures")
	check(c.arrive_t < 0.0, "refusal delays replacement family")
	_finish()


func _capacity(c: City, h: Dictionary) -> void:
	var saved: Array = h["families"].duplicate(true)
	h["tier"] = 1
	check(c.house_free_floors(h) == 0 and not c.can_host(h, {"cls": "plebs", "n": 2}), "one floor holds exactly one family of two")
	check(not c.house_room_text(h).contains("Место ещё"), "full house has no free-room claim")
	h["tier"] = 3
	c.pending["Резерв"] = {"home": h["id"], "name": "Резерв", "n": 4, "cls": "plebs"}
	h["coming"] = 4
	check(c.house_free_floors(h) == 1, "walking family reserves one floor")
	check(c.settled(int(h["id"]), 4, "Резерв") == 4, "reserved family enters whole")
	check(int(h["coming"]) == 0 and not c.pending.has("Резерв"), "settlement clears reservation")
	check(c.house_free_floors(h) == 1, "two families occupy two floors")
	check(c.settled(int(h["id"]), 2, "Третьи") == 2 and c.house_free_floors(h) == 0, "third family occupies last floor")
	check(c.settled(int(h["id"]), 2, "Лишние") == 0, "no fourth family on three floors")
	h["families"] = saved
	h["pop"] = 2
	check(c.settled(int(h["id"]), 1, "Один") == 0, "no new singleton through settlement")
	check(c.settled(int(h["id"]), 5, "Пятеро") == 0, "no oversized new family")
	c.compute()


func _arrivals(c: City, h: Dictionary) -> void:
	var counts := {2: 0, 3: 0, 4: 0}
	for cls: String in Defs.CLASS_ORDER:
		for i in 1000:
			var f := c.new_family(cls)
			var n := int(f["n"])
			if not check(n >= 2 and n <= 4, "arrival size " + cls):
				return
			counts[n] += 1
	check(absf(float(counts[2]) / 3000.0 - 0.25) < 0.06, "two-person weight")
	check(absf(float(counts[3]) / 3000.0 - 0.45) < 0.06, "three-person weight")
	check(absf(float(counts[4]) / 3000.0 - 0.30) < 0.06, "four-person weight")
	c.arrivals.clear()
	c.pending.clear()
	c.incoming = 0
	var free := {h["id"]: 2}
	check(c._take_room(free, "plebs", 2) and int(free[h["id"]]) == 1, "family of two uses one floor")
	check(c._take_room(free, "plebs", 4) and int(free[h["id"]]) == 0, "family of four uses one floor")
	c.set_arrivals_paused(true)
	var t := c.arrive_t
	for i in 100:
		c._tick_arrivals()
	check(c.incoming == 0 and c.arrivals.is_empty() and c.arrive_t == t, "pause stops new arrivals and timer")
	check(c.make_load(3).is_empty(), "paused station cannot load cart")
	var data: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	check(bool(data.get("arrivals_paused", false)), "pause serialized")
	# Отдельная земля: загрузка не меняет занятые клетки игровой сцены.
	var restored := City.new(Land.new())
	restored.load_data(data)
	check(restored.arrivals_paused, "pause restored")
	check(restored.house_free_floors(restored.buildings[int(h["id"])]) == 2, "family floors survive save round-trip")
	data.erase("arrivals_paused")
	restored.load_data(data)
	check(not restored.arrivals_paused, "old save defaults to running arrivals")
	c.set_arrivals_paused(false)
	c.stats["happy"] = 90
	c.arrive_t = 99.0
	c._tick_arrivals()
	check(c.incoming > 0, "resume starts arrivals")
	for i in 60:
		var load_families := c.make_load(10)
		check(load_families.size() <= c.house_free_floors(h), "cart respects family floors")
		for f: Dictionary in load_families:
			check(int(f["n"]) >= 2 and int(f["n"]) <= 4, "cart does not shrink family")
	c.incoming = 0


func _returning(c: City, h: Dictionary) -> void:
	var members := Residents.fit(h["families"][0], 42, "plebs")
	var member: Dictionary = members.pop_back()
	h["families"][0]["n"] = 1
	h["pop"] = 1
	check(c.house_free_floors(h) == 2, "surviving singleton keeps its floor")
	check(c.return_resident({"fam": "Юлии", "cls": "plebs", "m": member}), "resident returns")
	check((h["families"] as Array).size() == 1 and int(h["families"][0]["n"]) == 2 and c.arrivals.is_empty(), "return rejoins original family without creating singleton")


func _birds(h: Dictionary) -> void:
	var rb: RoofBirds = null
	for node in game.find_children("*", "Node3D", true, false):
		if node is RoofBirds:
			rb = node
	if not check(rb != null, "roof birds node"):
		return
	var triangle := PackedVector3Array([Vector3(-1, 2, -1), Vector3(1, 2, -1), Vector3(0, 2, 1)])
	check(RoofBirds._surface_at(triangle, Vector3(0, 9, 0)).is_equal_approx(Vector3(0, 2, 0)), "surface comes from triangles, not guessed height")
	check(not RoofBirds._surface_at(triangle, Vector3(3, 9, 0)).is_finite(), "no surface means no perch")
	var kit_faces := rb._model_faces("K:pleb_0_1/House")
	check(not kit_faces.is_empty() and RoofBirds._surface_at(kit_faces, Vector3.ZERO).is_finite(), "parts house roof surface")
	var spots := rb._spots(h)
	if not check(not spots.is_empty(), "Synty house has real roof perch"):
		return
	rb.set_process(false)
	rb.clear()
	var point: Vector3 = game.city.xf(h) * (spots[0] as Vector3)
	rb.birds.append(rb._bird(int(h["id"]), point, 0.0))
	rb._draw(0.0)
	game.hud.visible = false
	game.rig.set_view(point, 28, 27, 5.5)
	await shot("3_birds.png")


func _station_click(station: Dictionary) -> void:
	game.set_tool("")
	game.hover = Vector2.INF
	var cam: Camera3D = game.rig.cam
	var found := false
	for box: AABB in Game.pick_boxes(game.city.blueprint(station)):
		var point: Vector3 = game.city.xf(station) * (box.position + box.size * Vector3(0.5, 0.85, 0.5))
		var screen := cam.unproject_position(point)
		var hit: Dictionary = game._ray_pick(cam.project_ray_origin(screen), cam.project_ray_normal(screen), false)
		if int(hit.get("id", -1)) != int(station["id"]) or not game.people.pick(screen).is_empty():
			continue
		game._mouse_pos = screen
		game._click()
		found = int(game.hud.info_b.get("id", -1)) == int(station["id"]) and game.tool != "settle"
		break
	check(found, "click on station building opens its card while a family waits")
	game._mouse_pos = Vector2(-1, -1)


func _finish() -> void:
	print("FIX1 DONE")
	get_tree().quit(1 if fails > 0 else 0)
