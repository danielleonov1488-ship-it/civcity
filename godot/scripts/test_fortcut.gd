extends Node3D
## Проверяет модель и сохраняет пять кадров. Запускается владельцем проверки.

var out := "D:/CivCity/.work/stage4/fortcut/shots/"
var game: Game
var camp: CampUI
var lg: Legion
var fails := 0
var saved_clock := -1.0
var clock_owned := false
var peak_draws := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2 and pair[0] == "out":
			out = pair[1].trim_suffix("/") + "/"
	Game.boot = {"new": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	add_child(game)
	game.can_save = false
	_run()


func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func check(ok: bool, reason: String) -> bool:
	if not ok:
		fails += 1
		print("FORTCUT FAIL " + reason)
	return ok


func shot(file: String) -> void:
	await frames(45)
	for i in 8:
		await RenderingServer.frame_post_draw
		var draws := camp.diorama.sub.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		peak_draws = maxi(peak_draws, draws)
		await frames(1)
	await RenderingServer.frame_post_draw
	if check(get_viewport().get_texture().get_image().save_png(out + file) == OK, "save " + file):
		print("FORTCUT SHOT " + out + file)
	check(camp.diorama.figures.size() <= 16, "figure cap: " + file)
	check(peak_draws <= 600, "draw calls > 600: " + file)


func fixture(late: bool) -> void:
	lg.fort = {"exp": 3 if late else 0, "plots": [], "next_id": 0, "up": {}}
	lg.upg.clear()
	lg.camp.clear()
	lg.soldiers.clear()
	lg.squad3 = [0, 0, 0, 0, 0]
	lg.sid_next = 1
	lg.flags["camp_open"] = true
	lg.flags["camp_told"] = true
	lg.hero_training.clear()
	lg.rations = 0
	lg.mats = {"iron": 1000.0, "wood": 1000.0, "leather": 1000.0}
	lg.glory = 100000
	lg._fort_add_plot("hq", 8 if late else 2)
	var types: Array[String] = []
	types.assign(["barracks", "kitchen", "store", "forge", "arsenal", "infirmary", "mars", "smelter", "sawmill", "tannery", "treasury", "drill", "tower", "stable"] if late else ["barracks", "kitchen", "forge", ""])
	for i in types.size():
		var type := types[i]
		var level: int = int([1, 4, 8][i % 3]) if late else 1
		var p := lg._fort_add_plot(type, level if type != "" else 0)
		if type != "":
			var person := lg._add_soldier({"name": "Луций %d" % (i + 1), "cls": "legionary", "stars": 2})
			check(lg.fort_assign(int(p["id"]), int(person["id"])), "fixture assignment " + type)
	lg._fort_sync_camp()
	lg._ensure_hero3()
	# Три спешенных бойца у коек. Работники остаются закреплены за комнатами.
	for i in 3:
		lg._add_soldier({"name": "Воин %d" % i, "cls": "legionary", "stars": 1})
	lg.flags["camp_open"] = true
	lg.flags["camp3d_guide"] = 4
	if late:
		check(lg.fort_assign(int(lg.fort_slot_plot("kitchen")["id"]), 0), "unassign kitchen")
		var upgrading := lg.fort_slot_plot("tannery")
		upgrading["up"] = {"to": int(upgrading["lv"]) + 1, "end": Legion.now() + 28800, "total": 28800.0}
		lg._fort_sync_camp()
	else:
		lg.fort_slot_plot("kitchen")["pend"] = 3.0
	if is_instance_valid(camp) and is_instance_valid(camp.diorama):
		camp.diorama.sync()
		camp._refresh()


func model_checks() -> void:
	var saved: Dictionary = lg.to_dict().duplicate(true)
	var kitchen := lg.fort_slot_plot("kitchen")
	var id := int(kitchen["id"])
	kitchen["pend"] = 0.0
	kitchen["t"] = Legion.now()
	Legion.clock += 3600
	lg.fort_finish()
	check(is_zero_approx(float(kitchen["pend"])), "no output without worker")
	var person: Dictionary = lg.fort_worker_choices()[0]
	check(lg.fort_assign(id, int(person["id"])), "assign free soldier")
	Legion.clock += 3600
	lg.fort_finish()
	var rate := float(Legion.fort_production("kitchen", int(kitchen["lv"]))["rate"])
	check(is_equal_approx(float(kitchen["pend"]), rate), "assigned worker produces only after assignment")
	lg.rations = lg.resource_cap("rations")
	var pending := float(kitchen["pend"])
	Legion.clock += 7200
	lg.fort_finish()
	check(is_equal_approx(float(kitchen["pend"]), pending), "zero growth at full shared storage")
	lg.rations = 0
	kitchen["pend"] = 0.0
	Legion.clock += 1800
	lg.fort_finish()
	check(is_equal_approx(float(kitchen["pend"]), rate * 0.5), "full storage time is not banked")
	kitchen["pend"] = Legion.fort_production("kitchen", int(kitchen["lv"]))["cap"]
	pending = float(kitchen["pend"])
	Legion.clock += 3600
	lg.fort_finish()
	check(is_equal_approx(float(kitchen["pend"]), pending), "local buffer cap")
	var barracks := lg.fort_slot_plot("barracks")
	check(lg.fort_can_upgrade(int(barracks["id"])).begins_with(I18n.t("Строитель занят: %s").get_slice("%s", 0)), "builder refusal explains job")
	var money := lg.city_money()
	check(not lg.fort_upgrade(int(barracks["id"])) and lg.city_money() == money, "one builder, refused upgrade does not charge")
	var assigned_sid := int(person["id"])
	var copy := City.new(Land.new())
	copy.cozy_v = 1
	copy.legion_v = 3
	copy.legion.from_dict(JSON.parse_string(JSON.stringify(lg.to_dict())))
	check(int(copy.legion.fort_plot(id)["worker"]) == assigned_sid, "worker survives JSON save/load")
	check(copy.legion.fort_assign(id, 0), "clear saved worker")
	copy.legion.from_dict(JSON.parse_string(JSON.stringify(copy.legion.to_dict())))
	check(copy.legion.fort_worker(id).is_empty(), "empty assignment stays empty on reload")
	var old: Dictionary = saved.duplicate(true)
	for p: Dictionary in old["fort"]["plots"]:
		p.erase("worker")
		p.erase("legacy_worker")
	copy.legion.from_dict(JSON.parse_string(JSON.stringify(old)))
	var migrated := copy.legion.fort_worker(id).duplicate(true)
	check(not migrated.is_empty(), "legacy built rooms get a worker")
	copy.legion.from_dict(JSON.parse_string(JSON.stringify(copy.legion.to_dict())))
	check(copy.legion.fort_worker(id) == migrated, "legacy migration runs once")
	check(assigned_sid != 0 and not lg.fort_assign(int(barracks["id"]), assigned_sid), "one worker cannot hold two rooms")
	var squad_person := lg._add_soldier({"name": "Воин отряда", "cls": "legionary", "stars": 1})
	check(lg.set_place(1, int(squad_person["id"])), "place test soldier in squad")
	check(not lg.fort_assign(id, int(squad_person["id"])), "squad soldier cannot work in a room")
	for type: String in Legion.FORT_B:
		check(not (Legion.FORT_B[type]["max"] as Array).is_empty(), "HQ requirement " + type)
	for level in range(1, 9):
		var a := Legion.fort_production("kitchen", level)
		var b := Legion.fort_production("kitchen", level + 1)
		check(is_equal_approx(float(b["rate"]) / float(a["rate"]), 2.0) and is_equal_approx(float(b["cap"]) / float(a["cap"]), 2.0), "production doubles " + str(level))
	lg.from_dict(saved)


func _run() -> void:
	var waited := 0
	while not game.ready_done:
		await frames(5)
		waited += 5
		if waited > 18000:
			check(false, "ready_done timeout")
			_finish()
			return
	game.can_save = false
	game.settings["autosave"] = false
	check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory")
	var city: City = game.city
	city.cozy_v = 1
	city.legion_v = 3
	city.level = Defs.LEVELS.size() - 1
	city.money = 10000000
	city.hero = Hero.make("Гай Валерий", 0, Hero.PRESETS[0]["look"], true, 777)
	lg = city.legion
	saved_clock = Legion.clock
	clock_owned = true
	Legion.clock = maxf(1000000, Legion.now())
	fixture(false)
	camp = CampUI.of(game.hud)
	if not check(is_instance_valid(camp), "CampUI attached"):
		_finish()
		return
	camp.open()
	await frames(10)
	if not check(camp.diorama is FortCutaway, "cutaway default path"):
		_finish()
		return
	var view := camp.diorama as FortCutaway
	var built := 0
	var vacant := 0
	for p: Dictionary in lg.fort["plots"]:
		if p["b"] == "":
			vacant += 1
		elif int(p["lv"]) > 0 and (p["up"] as Dictionary).is_empty():
			built += 1
	if not check(view.grid == Vector2i(3, 2) and view.room_meshes.size() == 5 and built == 4 and vacant == 1, "early: two floors, four built and one empty"):
		_finish()
		return
	check(view.sub.own_world_3d and view.camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "separate orthographic world")
	check(not view.figures.is_empty(), "live 3D figures loaded")
	for id: int in view.room_rects:
		check(view._pick(view.project(id)) == "plot_%d" % id, "room picking " + str(id))
	var empty := lg.fort_empty_plot()
	if not check(empty >= 0 and camp.plot_markers.has(empty), "early empty plot has a marker"):
		_finish()
		return
	(camp.plot_markers[empty]["button"] as Button).pressed.emit()
	check(camp.build_plot_id == empty and is_instance_valid(camp.build_scroll), "empty plus opens this plot")
	camp._close_modal()
	await shot("1_early.png")
	fixture(true)
	model_checks()
	view.sync()
	camp._refresh()
	check(view.grid == Vector2i(4, 4) and view.room_meshes.size() == 15, "late expansion 3")
	var kitchen := int(lg.fort_slot_plot("kitchen")["id"])
	check((camp.plot_markers[kitchen]["state"] as Label).visible, "unassigned room shows !")
	var seen := {}
	for p: Dictionary in lg.fort["plots"]:
		seen[FortCutaway.room_art(String(p["b"]))] = true
	check(seen.size() == 12, "all twelve painted room types")
	await shot("2_late.png")
	var forge := int(lg.fort_slot_plot("forge")["id"])
	view.focus_plot("plot_%d" % forge)
	await get_tree().create_timer(0.8).timeout
	var smith := false
	for entry: Dictionary in view.figures:
		if int(entry["plot"]) == forge and entry["role"] == "forge":
			smith = not (entry["players"] as Array).is_empty()
	check(smith, "smith working in forge")
	check(absf(view.zoom - FortCutaway.CLOSE_ZOOM) < 0.05, "room occupies sixty percent of viewport height")
	await shot("3_zoom_forge.png")
	var paused := false
	for entry: Dictionary in view.figures:
		if (entry["node"] as Node3D).visible or (entry["players"] as Array).is_empty():
			continue
		var player: AnimationPlayer = entry["players"][0]
		var before := player.current_animation_position
		await frames(6)
		check(is_equal_approx(before, player.current_animation_position), "off-screen room animation pauses")
		paused = true
		break
	check(paused, "zoom leaves rooms off screen")
	view.focus_plot("hq", false)
	camp.show_plot(kitchen)
	check(camp.main_action.text == I18n.t("Назначить"), "main action assigns worker")
	await shot("4_card_assign.png")
	camp.main_action.pressed.emit()
	check(is_instance_valid(camp.modal_panel) and camp.modal_panel.name == "FortWorkerPicker", "assignment picker")
	camp._close_modal()
	camp.show_plot(int(lg.fort_slot_plot("barracks")["id"]))
	check(camp.upgrade_button.disabled and camp.upgrade_reason.text.contains(I18n.t("Строитель занят: %s").get_slice("%s", 0)), "builder busy on card")
	check(is_instance_valid(camp.card_body.get_node_or_null("FortWorker/FortWorkerName")), "worker face and name on card")
	await shot("5_builder_busy.png")
	print("FORTCUT DRAWCALLS %d" % peak_draws)
	check(peak_draws > 0 and peak_draws <= 600, "rendered draw call budget")
	camp.close()
	await frames(3)
	check(not is_instance_valid(camp.diorama), "cutaway shuts down on close")
	_finish()


func _finish() -> void:
	if clock_owned:
		Legion.clock = saved_clock
	print("FORTCUT DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
