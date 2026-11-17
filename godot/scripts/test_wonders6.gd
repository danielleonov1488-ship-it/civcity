extends Node3D
## Проверки и пять кадров. Запускает владелец проверки; сохранения игрока не пишем.

const IDS := ["arch", "colosseum", "pantheon", "circus", "aqueduct", "trajan", "caracalla", "jupiter"]
const HIDDEN := ["circus", "aqueduct", "caracalla", "jupiter"]
const AT := Vector2(163, 210)
var game
var city: City
var fails := 0
var out := "D:/CivCity/.work/stage5/wonders6/shots/"


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=").trim_suffix("/") + "/"
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	game.hero_screen_auto = false
	add_child(game)
	game.can_save = false
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, message: String) -> bool:
	print(("WONDERS6 PASS " if ok else "WONDERS6 FAIL ") + message)
	if not ok:
		fails += 1
	return ok


func shot(file: String) -> void:
	await frames(12)
	await RenderingServer.frame_post_draw
	if check(get_viewport().get_texture().get_image().save_png(out + file) == OK, "save " + file):
		print("WONDERS6 SHOT " + out + file)


func _finish() -> void:
	print("WONDERS6 DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


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
	game.speed = 0.0
	if game.tutorial.active():
		game.tutorial.step = Tutorial.STEPS.size()
		game.tutorial.card.visible = false
	city = game.city
	city.tips["tut"] = -1
	city.tips["ui"] = 3
	game.hud.apply_reveal(3)
	game.hud.advisor_panel.visible = false
	if not check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory"):
		_finish()
		return
	_catalog()
	_rules()
	_migration()
	await _views()
	_finish()


func _catalog() -> void:
	var found := []
	for type: String in Defs.B:
		var d: Dictionary = Defs.B[type]
		if d.get("cat", "") == "special" and d.get("sub", "") == "wonders":
			found.append(type)
	found.sort()
	var expected := IDS.duplicate()
	expected.sort()
	check(found == expected, "all eight entries belong to city Wonders group")
	var visible: Array = game.hud._types_in("special", "wonders")
	check(visible.size() == 4 and visible.has("trajan"), "city group shows four completed models")
	for type: String in HIDDEN:
		check(Defs.B[type].get("hidden", false) and not visible.has(type) and not city.unlocked(type)
			and not city.city_buildable(type) and city.place(type, AT, 0.0).is_empty(), "hidden and unbuildable " + type)
	var bp := Catalog.make("trajan", 0, 0, 0)
	var bounds: Array = game._bounds(bp)
	check(absf(float(bounds[1]) - float(bounds[0]) - 6.0) < 0.6
		and absf(float(bounds[3]) - float(bounds[2]) - 6.0) < 0.6, "Trajan footprint about 6 by 6 metres")
	var names := bp.parts.map(func(part: Array): return String(part[0]))
	check(names.has("SM_Bld_Pillar_Monument_01") and names.has("SM_Prop_Statue_02")
		and names.count("SM_Bld_Base_Floor_01") >= 12 and bp.lights.size() == 2, "Synty column, statue, paved steps and two night lights")
	var house := Catalog.make("house_pleb", 2, 0, 0)
	check(bp.top_y() >= house.top_y() * 2.0 and bp.top_y() <= house.top_y() * 3.2, "town-scale column above a two-storey house")
	var ui := LegionUi.of(game.hud)
	check(not ui.tabs.has("wonders") and not ui.has_method("_wonder_card") and not ui.has_method("_build_wonders"), "Legion has no wonder tab or cards")
	check(not city.legion.has_method("build_wonder"), "no bonus-only wonder purchase API")


## Ровный испытательный квартал на своей земле, с улицей перед колонной.
func _square(c: City) -> void:
	for goal: Dictionary in Defs.REQUESTS:
		if not c.goals_done.has(goal["id"]):
			c.goals_done.append(goal["id"])    # награды просьб не вмешиваются в проверку цены
	var cells := PackedInt32Array()
	var a := c.land.cell(Vector2(136, 185))
	var z := c.land.cell(Vector2(186, 245))
	for j in range(a.y, z.y):
		for i in range(a.x, z.x):
			cells.append(c.land.idx(i, j))
	c.land.flatten_cells(cells, Land.BASE_Y, Land.Kind.GRASS)
	c.land.paint_line(Vector2(138, 214.2), Vector2(184, 214.2), 1.2, Land.Kind.ROAD, true)


func _rules() -> void:
	var c := City.new(Land.new())
	_square(c)
	c.money = 100000.0
	c.level = 4
	c.research["research1"] = true
	c.rp = 3200.0
	check(int(Defs.research("trajan")["lvl"]) == 5 and c.can_research("trajan") != "", "research is at City rank")
	c.level = 5
	check(not c.unlocked("trajan") and c.check_place("trajan", AT, 0.0)["err"] != ""
		and c.place("trajan", AT, 0.0).is_empty(), "rank alone does not unlock placement")
	check(c.do_research("trajan") and c.unlocked("trajan"), "research unlocks Trajan")
	var near := c.place("house_pleb", AT + Vector2(8, 0), 0.0, 0, 0, true)
	var far := c.place("house_pleb", AT + Vector2(0, c.need_range(Defs.B["trajan"]) + 12.0), 0.0, 0, 0, true)
	c.compute()
	var near_before := float(near["monuments"])
	var far_before := float(far["monuments"])
	var money := c.money
	var glory := c.legion.glory
	check(c.check_place("trajan", AT, 0.0)["err"] == "", "researched Trajan placeable")
	var army_before := c.legion.stats("legionary")
	var column := c.place("trajan", AT, 0.0)
	if not check(not column.is_empty(), "Trajan placed"):
		return
	check(c.legion.stats("legionary") == army_before, "placing a city wonder leaves army stats unchanged")
	check(is_equal_approx(money - c.money, 40000.0) and c.legion.glory == glory, "40000 denarii, no glory debit")
	check(float(near["monuments"]) == near_before + float(Defs.B["trajan"]["bonus"])
		and float(far["monuments"]) == far_before, "happiness bonus only within radius")
	check(c.check_place("trajan", AT + Vector2(12, 12), 0.0)["err"] != "", "only one Trajan per city")
	c.arrivals_paused = true
	c.legion.glory_acc = 0.0
	for i in 24:
		c.sim_day()
	check(is_equal_approx(c.legion.glory - glory, float(Defs.B["trajan"]["glory_day"])), "daily glory is credited after 24 hours")
	var soldier := {"id": 99, "name": "Проверка", "cls": "legionary", "stars": 1, "rank": 0, "gear": {}}
	var plain := c.legion.stats("legionary")
	var gear := c.legion.soldier_stats(soldier, "legionary")
	for type: String in IDS:
		c.legion.built[type] = true
	check(c.legion.stats("legionary") == plain and c.legion.soldier_stats(soldier, "legionary") == gear
		and is_zero_approx(c.legion.pvp_bonus("atk")) and is_zero_approx(c.legion.pvp_bonus("hp")), "legacy purchases give no army bonus")
	var gd := c.legion.glory + c.legion.glory_acc
	for i in 24:
		c.legion.on_hour()
	check(is_equal_approx(gd, c.legion.glory + c.legion.glory_acc), "Legion purchase flags produce no passive glory")
	c.cozy_v = 1
	c.legion_v = 3
	var v3 := c.legion.soldier_stats(soldier, "legionary")
	c.legion.built.clear()
	check(c.legion.soldier_stats(soldier, "legionary") == v3, "V3 gear stats ignore wonders")


func _migration() -> void:
	var c := City.new(Land.new())
	_square(c)
	for type: String in ["arch", "colosseum", "pantheon"]:
		c.research[type] = true
		c.place(type, AT + Vector2(0, -16 * (c.buildings.size() + 1)), 0.0, 0, 0, true)
	var old := c.save_data()
	old.erase("wonders_v")
	old.erase("wonder_credits")
	old["research"] = []
	old["legion"]["built"] = IDS.duplicate()
	old["legion"]["glory"] = 37.0
	old["legion"]["city_decoupled"] = true
	c.load_data(JSON.parse_string(JSON.stringify(old)))
	check(c.buildings.size() == 3 and c.count_type("arch") == 1 and c.count_type("colosseum") == 1
		and c.count_type("pantheon") == 1, "placed legacy monuments stay")
	check(c.wonders_v == 1 and c.wonder_credits.size() == 5 and c.wonder_credit_ready("trajan"), "old bonus-only purchases become five one-time credits")
	c.money = 0.0
	check(c.unlocked("trajan") and c.check_place("trajan", AT, 0.0)["err"] == "", "old owner can place free column without research or money")
	check(c.place("trajan", Vector2.ZERO, 0.0).is_empty() and c.wonder_credit_ready("trajan"), "invalid placement keeps credit")
	var col := c.place("trajan", AT, 0.0)
	if not check(not col.is_empty(), "free credit placement succeeds"):
		return
	check(c.money == 0.0 and c.legion.glory == 37.0 and not c.wonder_credits.has("trajan")
		and c.refund_price(col) == 0.0, "credit consumed with no payment or cash refund")
	var data: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	c.load_data(data)
	check(int(data["wonders_v"]) == 1 and not c.wonder_credits.has("trajan") and c.wonder_credits.size() == 4
		and c.unlocked("trajan"), "save reload cannot grant the credit twice; future credits retained")
	c.load_data(JSON.parse_string(JSON.stringify(c.save_data())))
	check(c.wonder_credits.size() == 4 and c.count_type("trajan") == 1, "second roundtrip keeps exactly one placed column")
	var id := int(col["id"])
	c.remove(c.buildings[id])
	check(c.money == 0.0 and not c.wonder_credit_ready("trajan") and c.build_price("trajan") == 40000.0, "demolition never recreates a spent credit or prints denarii")
	for type: String in HIDDEN:
		check(c.wonder_credits.has(type) and not c.unlocked(type), "future credit stored and unavailable " + type)


func _views() -> void:
	_square(city)
	city.level = 5
	city.research["trajan"] = true
	city.money = 100000.0
	city.auto_hire = true
	for p: Vector2 in [Vector2(151, 209), Vector2(175, 209), Vector2(151, 220), Vector2(175, 220), Vector2(163, 224)]:
		var home := city.place("house_pleb", p, 0.0 if p.y < 214 else PI, 0, 0, true)
		home["tier"] = 2
		game._show(home)
	city.compute()
	var column := city.place("trajan", AT, 0.0)
	if not check(not column.is_empty(), "visual column placed"):
		return
	var focus := Vector3(AT.x, Land.BASE_Y + 5.0, AT.y)
	game.hud.close_panels()
	game._set_hour(11.0)
	game.rig.set_view(focus, 145.0, 32.0, 28.0)
	await shot("1_trajan_day.png")
	game.rig.set_view(Vector3(165, Land.BASE_Y + 2.0, 212), 155.0, 48.0, 62.0)
	await shot("2_trajan_far.png")
	game._set_hour(23.0)
	game.rig.set_view(focus, 145.0, 32.0, 28.0)
	await frames(35)
	await shot("3_trajan_night.png")
	game._set_hour(11.0)
	game.hud.open_ssub = "wonders"
	game.hud._toggle_cat("special")
	check(game.hud.tray_stabs.visible and game.hud.tray_title.text.contains("Чудеса")
		and game.hud.tray_grid.get_child_count() == 4, "city build menu displays Wonders group")
	await shot("4_build_menu_wonders.png")
	# Призрак настоящего инструмента и отмена бесплатной постановки.
	city.remove(column, false)
	city.wonder_credits["trajan"] = 1
	game.hud.select_build("trajan")
	game.hud.tray.visible = false
	game.hud._refresh_cat_buttons()
	var mouse := InputEventMouseMotion.new()
	mouse.position = game.rig.cam.unproject_position(Vector3(AT.x, Land.BASE_Y, AT.y))
	Input.warp_mouse(mouse.position)
	Input.parse_input_event(mouse)
	await frames(8)
	game.hover = AT
	game.place_lock = {"p": AT}
	game.place_info = game.placement("trajan", AT, 0, 0)
	game._update_tool()
	check(game.place_info["err"] == "" and game.ghost != null and game.ghost.visible, "valid placement preview")
	await shot("5_placement.png")
	game._build_here()
	check(city.count_type("trajan") == 1 and not city.wonder_credit_ready("trajan"), "real build tool consumes credit")
	var undo: Dictionary = game.undo_place_info()
	if check(not undo.is_empty() and float(undo["cost"]) == 0.0, "free placement undo has no cash refund"):
		game._undo_place(undo)
		check(city.count_type("trajan") == 0 and city.wonder_credit_ready("trajan"), "undo restores the unspent placement right")
	game.set_tool("")
