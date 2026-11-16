extends Node3D
## Фикстура без сохранений; запуск и кадры выполняет владелец тестов.

var out := "D:/CivCity/.work/stage3/fortscene/shots/"
var game
var camp: CampUI
var legion: Legion
var fails := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2 and pair[0] == "out":
			out = pair[1].trim_suffix("/") + "/"
	Game.boot = {"new": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	game.can_save = false
	_run()


func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func check(ok: bool, reason: String) -> bool:
	if not ok:
		fails += 1
		print("FORTSCENE FAIL " + reason)
	return ok


func shot(file: String, save := true) -> void:
	await frames(10)
	var peak := 0
	for i in 8:
		await RenderingServer.frame_post_draw
		peak = maxi(peak, camp.diorama.sub.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
		await frames(1)
	print("FORTSCENE DRAWCALLS %d" % peak)
	check(peak > 0, "no rendering: " + file)
	if int(legion.fort["exp"]) == 3:
		check(peak <= 1100, "expansion 3 draw calls %d > 1100" % peak)
	if save:
		await RenderingServer.frame_post_draw
		var error := get_viewport().get_texture().get_image().save_png(out + file)
		if check(error == OK, "save " + file):
			print("FORTSCENE SHOT " + out + file)


func fixture(expansion: int) -> void:
	# Штаб отдельно от 6/14/26 мест. Есть пустые участки и повторные казармы.
	legion.fort = {"exp": expansion, "plots": [], "next_id": 0, "up": {}}
	legion._fort_add_plot("hq", 1 if expansion == 0 else (4 if expansion == 2 else 7))
	var types: Array[String] = ["barracks", "kitchen", "forge", "drill", "store", "mars", "barracks", "smelter", "sawmill", "tannery", "infirmary", "arsenal", "stable", "treasury", "tower"]
	for i in int(Legion.fort_exp_info(expansion)["plots"]):
		var type: String = types[i % types.size()]
		var level: int = [1, 4, 7][i % 3]
		if i % 7 == 5:
			type = ""
			level = 0
		legion._fort_add_plot(type, level)
	var upgrade := legion.fort_plot(5)
	upgrade["up"] = {"to": int(upgrade["lv"]) + 1, "start": Legion.now(), "end": Legion.now() + 3600, "total": 3600.0}
	legion._fort_sync_camp()
	legion.flags["camp3d_guide"] = 4
	legion.flags["camp_open"] = true
	legion.changed.emit()
	if is_instance_valid(camp) and is_instance_valid(camp.diorama):
		camp.diorama.sync()
		camp.diorama.focus_plot("hq", false)
		camp._refresh()


func inspect() -> void:
	var view := camp.diorama
	check(view.buildings.size() == (legion.fort["plots"] as Array).size(), "all model plots rendered")
	check(view.figures.size() <= Camp3D.MAX_FIGURES, "animated figure cap")
	check(view.structures.get_node("TowerSentries").get_child_count() == 8, "two sentries on each corner")
	check(view.kit_batches.get("tower", []).size() >= 4, "corner towers")
	check(view.kit_batches.has("palisade_seg") and view.kit_batches.has("palisade_seg_b"), "alternating palisade")
	check(view._pick(view.project("gate")) == "gate", "gate picking")
	var stages := {}
	for plot: Dictionary in legion.fort["plots"]:
		var key := "plot_%d" % int(plot["id"])
		var root: Node3D = view.buildings[key]
		var pos: Vector3 = view.plots[key]
		check(view._pick(view.project(key)) == key, "pick " + key)
		check(view.bounds.encloses(Rect2(pos.x - 4.5, pos.z - 4.5, 9, 9)), "walls enclose " + key)
		stages[String(root.get_meta("stage"))] = true
		if String(plot["b"]) == "":
			check(root.has_node("BuildSign"), "empty plot sign")
		if not (plot["up"] as Dictionary).is_empty():
			check(view.scaffolds.has(key), "scaffolding " + key)
	check(stages.has("tent") and stages.has("timber") and stages.has("stone") and stages.has("empty"), "all building stages")
	var x := view.bounds.end.x
	var z := view.bounds.get_center().y
	check(is_equal_approx(CampScenery.height_at(x, z, view.bounds), 1.2), "rampart top 1.2m")
	check(is_equal_approx(CampScenery.height_at(x + 2.75, z, view.bounds), -1.2), "ditch bottom -1.2m")
	for material: Material in [CampScenery.wood_material(), CampScenery.wood_material(true)]:
		check((material as StandardMaterial3D).albedo_texture != null, "wood texture")
	check(CampScenery.wood_material() == CampScenery.wood_material(), "wood material cache")
	var screen := Rect2(Vector2.ZERO, view.size)
	for x0: float in [view.bounds.position.x - 2, view.bounds.end.x + 2]:
		for z0: float in [view.bounds.position.y - 2, view.bounds.end.y + 6]:
			var pixel := view.camera.unproject_position(view.world.to_global(Vector3(x0, 11, z0))) * view.size / Vector2(view.sub.size)
			check(screen.has_point(pixel), "overview fits towers and bridge")


func _run() -> void:
	var waited := 0
	while not game.ready_done:
		await frames(5)
		waited += 5
		if waited >= 18000:
			check(false, "ready_done timeout")
			get_tree().quit(1)
			return
	game.can_save = false
	game.settings["autosave"] = false
	if not check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory"):
		get_tree().quit(1)
		return
	var city: City = game.city
	city.cozy_v = 1
	city.legion_v = 3
	city.hero = {}
	city.money = 1000000
	for i in 18:
		var house := city.place("house_pleb", Land.START + Vector2(8.0 * (i % 8), 8.0 * (i / 8)), 0, 0, 0, true)
		if not check(not house.is_empty(), "fixture house"):
			get_tree().quit(1)
			return
		house["families"] = [{"name": "Test", "n": 4, "cls": "plebs"}]
		house["pop"] = 4
	city.compute()
	legion = city.legion
	legion.army_tick()
	fixture(0)
	for i in 4:
		var soldier := legion.recruit_resident()
		if check(not soldier.is_empty(), "fixture recruit"):
			legion.set_place(i, int(soldier["id"]))
	camp = CampUI.of(game.hud)
	if not check(camp != null, "camp attached"):
		get_tree().quit(1)
		return
	camp.open()
	await frames(10)
	if not check(is_instance_valid(camp.diorama), "3D fort loaded"):
		get_tree().quit(1)
		return
	inspect()
	var initial := camp.diorama.plots.duplicate()
	await shot("1_exp0.png")
	fixture(2)
	inspect()
	for key: String in initial:
		check(initial[key] == camp.diorama.plots[key], "stable coordinates " + key)
	await shot("2_exp2.png")
	fixture(3)
	inspect()
	await shot("exp3_budget", false)
	fixture(4)
	inspect()
	await shot("3_exp4.png")
	camp.diorama.focus_plot("plot_1")
	await shot("4_close_tents.png")
	camp.diorama.focus_plot("plot_3")
	await shot("5_close_stone.png")
	camp.diorama.focus_plot("gate")
	camp.diorama.zoom = maxf(40, camp.diorama.bounds.size.x / (camp.size.x / camp.size.y) + 10)
	camp.diorama._update_camera()
	await shot("6_towers_gate.png")
	# Один сигнал на победу, проход по дороге, повторное открытие без повтора.
	var battle := legion.make_battle(Legion.stage(0, 0, 0), 17)
	legion.apply_result(battle, {"win": true, "alive": 4, "total": 4, "fallen": [], "time": 10.0,
		"hp_left": 1.0, "inputs": [], "perks_used": {}, "summons": 0})
	camp.diorama.sync()
	check(not legion.flags.has("march_in") and not camp.diorama.arrivals.is_empty(), "march consumed once")
	await get_tree().create_timer(1.0).timeout
	for entry: Dictionary in camp.diorama.figures:
		if camp.diorama.arrivals.has(int(entry["id"])):
			check(absf((entry["node"] as Node3D).position.x) < 0.01, "march stays on main road")
	# Пустой участок и повторное здание выбираются по ID.
	camp.show_building("plot_6")
	check(camp.build_plot_id == 6, "build menu retains empty plot ID")
	camp._close_modal()
	camp.show_building("plot_7")
	check(camp.selected_plot == 7, "duplicate barracks picking")
	camp._hide_card()
	var old: WeakRef = weakref(camp.diorama)
	camp.close()
	await frames(2)
	check(old.get_ref() == null and not get_viewport().disable_3d, "close frees fort / restores city")
	camp.open()
	await frames(8)
	check(is_instance_valid(camp.diorama) and camp.diorama.arrivals.is_empty(), "reopen without repeated march")
	camp.close()
	print("FORTSCENE DONE")
	get_tree().quit(1 if fails > 0 else 0)
