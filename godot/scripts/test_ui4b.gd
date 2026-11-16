extends Node3D
## UI4b: безопасная проекция, нужды по рангу, найм бота и красная стрелка этажа.

const Pace = preload("res://scripts/test_pace.gd")
var out := "D:/CivCity/.work/stage4/ui4b/shots/"
var game
var hud: Hud
var city: City
var fails := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=").trim_suffix("/") + "/"
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	game.can_save = false
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, why: String) -> void:
	if not ok:
		fails += 1
		print("UI4B FAIL " + why)


func shot(file: String) -> void:
	hud.advisor_panel.hide()
	await frames(8)
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(out + file)
	check(error == OK, "save " + file)
	if error == OK:
		print("UI4B SHOT " + out + file)


func _finish() -> void:
	print("UI4B DONE fails=%d" % fails)
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
	game.settings["advisor_off"] = true
	game.speed = 0.0
	game.build_anim = false
	game.rig.cine = true
	game.tutorial.step = Tutorial.STEPS.size()
	game.tutorial.card.hide()
	game.tutorial.set_process(false)
	hud = game.hud
	city = game.city
	city.cozy_v = 1
	city.auto_hire = false
	city.money = 1000000.0
	city.tips["tut"] = -1
	city.tips["ui"] = 3
	city.research["floor2"] = true
	hud.apply_reveal(3)
	hud.close_panels()
	I18n.set_lang("ru")
	check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory")
	var home := city.place("house_pleb", Vector2(177, 136), 0.0, 0, 0, true)
	if home.is_empty():
		check(false, "house fixture")
		_finish()
		return
	var door := city.door_point(home)
	game.land.paint_line(door, Vector2(Land.ROAD_X, door.y), 0.9, Land.Kind.ROAD)
	_add_family(home, "Юлии", 2)
	game.rig.set_view(Vector3(177, 3, 136), 20, 55, 46)
	await frames(8)
	_rank_data()
	for rank in [0, 1, 2]:
		city.level = rank
		city.compute()
		check(home["missing"].has("faith") == (rank >= 2), "faith penalty at rank %d" % rank)
		check(int(city.stats["needs"]["faith"]["houses"]) == (1 if rank >= 2 else 0), "faith average at rank %d" % rank)
		check(Cover.overview_sets(city, "faith")["tint"].has(home["id"]) == (rank >= 2), "faith overlay at rank %d" % rank)
		hud.refresh()
		hud.open_info(home)
		await frames(3)
		var strip := hud.info_box.find_child("NeedStrip", true, false) as Control
		check(strip != null, "need strip")
		if strip != null:
			var faith := strip.get_node("need_faith") as Control
			check(String(faith.get_meta("state")) == ("red" if rank >= 2 else "disabled"), "faith UI state")
			if rank < 2:
				check(faith.tooltip_text == "с уровня «Деревня»", "faith unlock tooltip")
		await shot("needs_rank%d.png" % rank)
	hud.close_panels()
	_projection_checks()
	await _camera_sweep()
	_numeric_checks()
	_hiring_checks()
	_floor_checks(home)
	await shot("badges_safe.png")
	_finish()


func _rank_data() -> void:
	for rank in range(Defs.LEVELS.size()):
		check(Defs.needs_for("plebs", rank) == (["food"] if rank < 2 else ["food", "faith"]), "plebs rank %d" % rank)
		check(Defs.needs_for("artisans", rank) == (["food", "clothes", "fun"] if rank < 2 else ["food", "faith", "clothes", "fun"]), "artisans rank %d" % rank)
		check(Defs.needs_for("patricians", rank).size() == 6, "patricians rank %d" % rank)


func _projection_checks() -> void:
	var cam: Camera3D = game.rig.cam
	var vr := get_viewport().get_visible_rect()
	var xf := cam.get_camera_transform()
	var ahead := xf.origin - xf.basis.z * 20.0
	var extent := Vector2(44, 44)
	var anchor := Vector2(0.5, 0.5)
	check(not Hud._badge_layout(cam, ahead, extent, anchor, vr, false).is_empty(), "ordinary front badge")
	for bad: Vector3 in [Vector3(NAN, 0, 0), Vector3(INF, 0, 0), xf.origin, xf.origin + xf.basis.z, xf.origin - xf.basis.z * cam.near * 0.5, xf.origin + xf.basis.x * 1.0e30 - xf.basis.z]:
		check(Hud._badge_layout(cam, bad, extent, anchor, vr, false).is_empty(), "reject bad/near/behind/offscreen point")
	for bad_size: Vector2 in [Vector2(NAN, 44), Vector2(INF, 44), Vector2(1.0e20, 44), Vector2.ZERO]:
		check(Hud._badge_layout(cam, ahead, bad_size, anchor, vr, false).is_empty(), "reject invalid badge size")
	check(Hud._badge_layout(cam, ahead, extent, Vector2(NAN, 0), vr, false).is_empty(), "reject invalid anchor")
	check(Hud._badge_layout(cam, ahead, extent, anchor, Rect2(0, 0, INF, 900), false).is_empty(), "reject invalid viewport")
	for distance: float in [0.000001, 0.01, 0.05, 1.0, 35.0, 215.0, 1000.0]:
		var layout := Hud._badge_layout(cam, xf.origin - xf.basis.z * distance, extent, anchor, vr, true)
		if not layout.is_empty():
			check((layout["pos"] as Vector2).is_finite(), "finite position")
			var factor: Vector2 = layout["scale"]
			check(factor.is_finite() and factor.x >= 0.5 and factor.x <= 1.5, "bounded scale")
	# Плохие данные остаются в словаре, до Control они дойти не должны.
	hud.set_badge("ui4b_bad", Vector3(NAN, INF, 0), "house_problem", true)
	hud._place_badges()
	var node: Control = hud.badges["ui4b_bad"]["n"]
	check(not node.visible and node.position.is_finite() and node.scale.is_finite(), "invalid world badge stays hidden and finite")
	hud.clear_badge("ui4b_bad")


func _camera_sweep() -> void:
	var at := Vector3(177, 6, 136)
	for i in 40:
		hud.set_badge("ui4b_%d" % i, at + Vector3(i % 8, 0, i / 8), "house_problem" if i % 2 == 0 else "family", i % 2 == 0)
	var cam: Camera3D = game.rig.cam
	var keep := cam.global_transform
	# Плавный проход через плоскость значков, кадры с 40 тенями и пинами.
	for step in 100:
		var angle := float(step) * TAU / 100.0
		cam.global_position = at + Vector3(cos(angle), 0.3, sin(angle)) * lerpf(45.0, 0.01, float(step) / 99.0)
		cam.look_at(at, Vector3.UP)
		hud._place_badges()
		for entry: Dictionary in hud.badges.values():
			var badge: Control = entry["n"]
			check(badge.position.is_finite() and badge.scale.is_finite() and badge.size.is_finite(), "finite sweep geometry")
		await frames(1)
	cam.global_transform = keep
	hud._place_badges()
	await shot("camera_return.png")
	for i in 40:
		hud.clear_badge("ui4b_%d" % i)


func _numeric_checks() -> void:
	for value: float in [NAN, INF, -INF, -1.0, 0.0, 100.0, 1.0e30]:
		var pct := HouseNeeds.percent(value)
		check(pct >= 0 and pct <= 100, "bounded need coverage")
	var row := hud._need_strip({"food": NAN, "faith": INF}, ["food", "faith"], NAN)
	for child: Control in row.get_children():
		check(child.custom_minimum_size.is_finite(), "finite need width")
	row.free()


func _add_family(home: Dictionary, name: String, adults: int) -> void:
	var members := Residents.gen(name, 4, String(Defs.B[home["type"]]["cls"]), int(home["id"]))
	for i in members.size():
		members[i]["age"] = 1 if i < adults else 0
	home["families"].append({"name": name, "n": 4, "cls": String(Defs.B[home["type"]]["cls"]), "m": members})
	home["pop"] = int(home["pop"]) + 4


func _hiring_checks() -> void:
	var c := City.new(Land.new())
	c.cozy_v = 1
	c.auto_hire = false
	var home := c.place("house_pleb", Land.START, 0.0, 0, 0, true)
	_add_family(home, "Фабии", 1)
	var scribe := c.place("scriptorium", Land.START + Vector2(10, 0), 0.0, 0, 0, true)
	var fruit := c.place("stall_fruit", Land.START + Vector2(20, 0), 0.0, 0, 0, true)
	c.compute()
	var bot := Pace.new()
	bot.c = c
	bot._bhire()
	check(c.hired_of(fruit) == 1 and c.hired_of(scribe) == 0, "bot hires food before research; children stay free")
	_add_family(home, "Клавдии", 2)
	c.compute()
	bot._bhire()
	check(c.hired_of(fruit) == c.job_max(fruit) and c.hired_of(scribe) == c.job_max(scribe), "bot hires new adults into remaining slots")
	var before := c.hired_of(fruit) + c.hired_of(scribe)
	bot._bhire()
	check(before == c.hired_of(fruit) + c.hired_of(scribe), "bot hiring is idempotent")
	bot.free()


func _floor_checks(home: Dictionary) -> void:
	# Только готовность без денег: тот же путь, что у красной стрелки после мазка.
	home["happy"] = 100
	home["tier"] = 1
	city.money = 0.0
	game.set_tool("floor")
	game.cover.refresh()
	game.floor_drag = true
	game.floor_done = []
	game.floor_broke = false
	game._floor_check_broke(home)
	check(game.floor_broke, "red arrow updates floor_broke even when sweep skips it")
	check(String(game._floor_lines(home)[2]).begins_with("Не хватает денариев: этаж стоит"), "floor cursor names shortfall and price")
	game.floor_drag = false
	game.floor_broke = false
	game.set_tool("")
	city.money = 1000000.0
