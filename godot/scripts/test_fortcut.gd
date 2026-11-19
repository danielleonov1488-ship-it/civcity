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
		var draws := camp.diorama.sub.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		peak_draws = maxi(peak_draws, draws)
		await frames(1)
	await RenderingServer.frame_post_draw
	if check(get_viewport().get_texture().get_image().save_png(out + file) == OK, "save " + file):
		print("FORTCUT SHOT " + out + file)
	check(camp.diorama.figures.size() < FortCutaway.SPRITE_LIMIT, "figure cap: " + file)
	check(peak_draws <= 600, "draw calls > 600: " + file)


func fixture(late: bool) -> void:
	lg.fort = {"money": 1e7, "know": {"smith": true}, "exp": 3 if late else 0, "plots": [], "next_id": 0, "up": {}}
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
	lg._fort_fill_grid()
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
	old["fort"].erase("population_v")
	old["fort"].erase("workers_v")
	for p: Dictionary in old["fort"]["plots"]:
		p.erase("worker")
		p.erase("legacy_worker")
		p.erase("workers")
	copy.legion.from_dict(JSON.parse_string(JSON.stringify(old)))
	var migrated := copy.legion.fort_worker(id).duplicate(true)
	check(not migrated.is_empty(), "legacy built rooms get a worker")
	copy.legion.from_dict(JSON.parse_string(JSON.stringify(copy.legion.to_dict())))
	check(copy.legion.fort_worker(id) == migrated, "legacy migration runs once")
	check(assigned_sid != 0 and lg.fort_assign(int(barracks["id"]), assigned_sid) and lg.fort_worker_plot(assigned_sid) == int(barracks["id"]), "worker moves between rooms")
	var squad_person := lg._add_soldier({"name": "Воин отряда", "cls": "legionary", "stars": 1})
	check(lg.fort_assign(int(barracks["id"]), int(squad_person["id"])) and lg.set_place(1, int(squad_person["id"])), "barracks soldier enters squad")
	check(lg.fort_assign(id, int(squad_person["id"])) and not lg.squad3.has(int(squad_person["id"])), "worker leaves squad when moved")
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
	if not check(view.grid == Vector2i(5, 3) and view.room_sprites.size() == 14 and built == 4 and vacant == 10, "early: three floors, four built and ten empty"):
		_finish()
		return
	check(view.sub.disable_3d and view.people_layer.viewport.own_world_3d and view.people_layer.viewport.transparent_bg, "painted viewport and shared 3D people")
	check(not view.figures.is_empty() and view.figures[0]["node"] is Node3D, "3D dwellers loaded")
	for id: int in view.room_rects:
		check(view._pick(view.project(id)) == "plot_%d" % id, "room picking " + str(id))
	var empty := lg.fort_empty_plot()
	if not check(empty >= 0 and camp.plot_markers.has(empty), "early empty plot has a marker"):
		_finish()
		return
	(camp.plot_markers[empty]["button"] as Button).pressed.emit()
	check(camp.build_plot_id == empty and is_instance_valid(camp.build_scroll), "empty slot opens its catalog")
	camp._close_modal()
	await shot("1_early.png")
	fixture(true)
	model_checks()
	view.sync()
	camp._refresh()
	check(view.grid == Vector2i(5, 4) and view.room_sprites.size() == 19, "late expansion 3")
	var kitchen := int(lg.fort_slot_plot("kitchen")["id"])
	check((camp.plot_markers[kitchen]["state"] as Label).visible, "unassigned room shows !")
	var seen := {}
	for p: Dictionary in lg.fort["plots"]:
		seen[FortCutaway.room_art(String(p["b"]))] = true
	check(seen.size() == 15, "all fifteen painted room types (seen %s)" % [seen.keys()])
	await shot("2_late.png")
	var forge := int(lg.fort_slot_plot("forge")["id"])
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = view.plot_footprint(forge).position + Vector2(8, 8)
	click.pressed = true
	view._gui_input(click)
	click.pressed = false
	view._gui_input(click)
	check(camp.room_action_id == forge and view.selected_room == forge and camp.room_actions.visible,
		"forge selected from cutaway")
	var info := camp.room_actions.find_child("FortRoomInfo", true, false) as Button
	if not check(info != null, "selected forge offers room info"):
		return
	info.pressed.emit()
	check(camp.selected_plot == forge and is_instance_valid(camp.card), "info opens forge card")
	camp._hide_card()
	view.focus_plot("forge")
	await get_tree().create_timer(1.1).timeout
	var smith := false
	for entry: Dictionary in view.figures:
		if int(entry["plot"]) == forge and entry["role"] == "forge":
			var actor: Node3D = entry["node"]
			for i in 32:
				view._animate_people(0.25)
				smith = smith or (actor.visible and entry["clip"] == "Interact")
	check(smith, "smith working in forge")
	var forge_rect := view.plot_footprint(forge)
	var room_height := forge_rect.size.y / view.size.y
	check(room_height >= 0.45 and room_height <= 0.50, "selected room occupies 45 to 50 percent of viewport height")
	check(Rect2(Vector2.ZERO, view.size).encloses(forge_rect), "selected room fits in viewport")
	await shot("3_zoom_forge.png")
	var off_screen := false
	for id: int in view.room_rects:
		if not Rect2(Vector2.ZERO, view.size).intersects(view.plot_footprint(id)):
			off_screen = true
			break
	check(off_screen, "close-up leaves some rooms off screen")
	var paused := false
	for entry: Dictionary in view.figures:
		var actor: Node3D = entry["node"]
		if actor.visible:
			continue
		var before := float(entry["sample"])
		view._animate_people(0.45)
		check(not actor.visible and float(entry["sample"]) == before, "off-screen pose is held")
		paused = true
		break
	check(paused, "close-up pauses off-screen figures")
	# Панорамируем с приближением до каждого участка, включая дальний этаж.
	var pan := InputEventMouseButton.new()
	pan.button_index = MOUSE_BUTTON_MIDDLE
	pan.position = view.size * 0.5
	pan.pressed = true
	view._gui_input(pan)
	for id: int in view.room_rects:
		var motion := InputEventMouseMotion.new()
		motion.relative = view.size * 0.5 - view.project(id)
		view._gui_input(motion)
		view._process(2.0)
		check(Rect2(Vector2.ZERO, view.size).encloses(view.plot_footprint(id))
			and view._pick_id(view.project(id)) == id, "room %d reachable by panning" % id)
	pan.pressed = false
	view._gui_input(pan)
	# Урок с целью за краем кадра не перехватывает камеру.
	var hq_id := int(lg.fort_slot_plot("hq")["id"])
	var screen := Rect2(Vector2.ZERO, view.size)
	check(not screen.intersects(view.plot_footprint(hq_id)), "HQ is offscreen after panning")
	var before_lesson := view._target_focus
	lg.flags["fort_lessons"] = {"hq": "pending"}
	camp._layout_guide()
	check(camp.guide.is_visible_in_tree() and not camp.guide_shade.is_visible_in_tree()
		and not camp.guide_pointer.is_visible_in_tree(), "offscreen lesson leaves the fort readable")
	view._process(2.0)
	check(view._target_focus.is_equal_approx(before_lesson), "visible lesson leaves camera where player panned")
	lg.finish_fort_lesson("hq", true)
	lg.flags.erase("fort_lessons")
	camp._layout_guide()
	check(not camp.guide_layer.is_visible_in_tree(), "inactive guide layer is hidden")
	view.focus_plot("hq", false)
	view._process(2.0)
	for id: int in view.room_rects:
		check(Rect2(Vector2.ZERO, view.size).encloses(view.plot_footprint(id)), "room %d visible in overview" % id)
	camp.show_plot(kitchen)
	check(camp.main_action.get_meta("action_name") == I18n.t("Назначить"), "main action assigns worker")
	await shot("4_card_assign.png")
	camp.main_action.pressed.emit()
	check(is_instance_valid(camp.modal_panel) and camp.modal_panel.name == "FortWorkerPicker", "assignment picker")
	camp._close_modal()
	camp.show_plot(int(lg.fort_slot_plot("barracks")["id"]))
	var busy_text := I18n.t("Строитель занят: %s") % I18n.t(String(Legion.FORT_B["tannery"]["name"]))
	check(camp.upgrade_button.disabled and camp.upgrade_reason.is_visible_in_tree() and camp.upgrade_reason.text == busy_text, "builder busy on card")
	check(not camp.main_action.disabled and camp.main_action.get_meta("action_name") == I18n.t("Отряд"), "barracks opens squad while builder is busy")
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
