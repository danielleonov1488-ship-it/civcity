extends "res://scripts/promo_cam.gd"
## Независимые дубли, без настоящих сохранений.

const FortFixture = preload("res://scripts/test_fort_fixture.gd")
const CENTER := Vector2(193, 115)
const ROAD_A := Vector2(192, 115)
const ROAD_B := Vector2(210, 115)
const CITY_CLIPS := ["road_drag", "three_houses", "move_in", "fruit_stall", "hire",
	"floor", "garden", "fountain", "requests", "research", "arena_build", "cityrise"]
const LEGION_CLIPS := ["fort", "recruit", "battle", "campaign"]
const SCENIC := {
	"rain": {"hour": [14.1, 14.3], "keys": [[0, Vector3(192, 0, 145), 184, 23, 24], [10, Vector3(192, 0, 156), 180, 20, 21]]},
	"autumn": {"hour": [16.1, 16.3], "keys": [[0, Vector3(212, 0, 147), 324, 30, 17], [10, Vector3(215, 0, 149), 350, 25, 17]]},
	"arena_full": {"hour": [15.9, 16.1], "life": 13.0, "follow": "venue", "venue": "colosseum", "show": ["show", 1.0, 1.0],
		"keys": [[0, Vector3(0, 1.6, 0), 47, 53, 15], [11, Vector3(0, 1.8, 0), 76, 46, 14]], "blur": 0.04},
	"festival": {"hour": [16.8, 17.0], "keys": [[0, Vector3(192, 2.0, 88), 185, 17, 13], [10, Vector3(192, 2.7, 105), 178, 17, 15]]},
	"harvest": {"hour": [9.0, 9.2], "keys": [[0, Vector3(169, 0.4, 77), 193, 30, 21], [10, Vector3(170, 0.4, 87), 204, 30, 20]]},
	"boats": {"hour": [16.9, 17.1], "follow": "boat", "keys": [[0, Vector3(0, 0.24, 0), 84, 21, 8], [10, Vector3(0, 0.24, 0), 115, 26, 8]]},
	"day_night": {"hour": [8.1, 22.4], "keys": [[0, Vector3(192, 0, 167), 20, 40, 39], [14, Vector3(194, 0, 167), 32, 37, 38]]},
	"top_down": {"hour": [17.2, 17.4], "keys": [[0, Vector3(176, 3.0, 157), 0, 86, 9], [6, Vector3(182, 1.0, 160), 0, 86, 27],
		[14, Vector3(192, 0, 166), 0, 84, 205]], "blur": 0.0},
}

var city: City
var hud: Hud
var camp: CampUI
var battle: LegionBattle
var boat: Node3D
var cursor: Node2D
var cursor_tween: Tween
var events: Array = []
var event_index := 0
var gesture := Vector2.ZERO
var started_road := false
var house_site := Vector2.ZERO
var feature := {}
var started_recording := false
var rise_buildings := 0
var arena_gathering := false


func _clip_config(name: String) -> Dictionary:
	if name == "arrival":
		var cfg: Dictionary = CLIPS[name].duplicate()
		cfg["keys"] = [[0, Vector3(0, 1.2, 0), 4, 16, 13.5], [5, Vector3(0, 1.3, 0), 11, 19, 13],
			[10, Vector3(0, 1.3, 0), 21, 23, 13.5]]
		return cfg
	if SCENIC.has(name):
		var cfg: Dictionary = SCENIC[name].duplicate()
		var path: Array = cfg["keys"]
		cfg["dur"] = float(path[-1][0])
		cfg["ease"] = "inout"
		cfg["v"] = {"dist": 1.06, "fov": 30.0}
		return cfg
	if not (name in CITY_CLIPS or name in LEGION_CLIPS):
		return super._clip_config(name)
	var at := Vector3(CENTER.x, 0.6, CENTER.y)
	var zoom := 21.0
	var angle := 49.0
	match name:
		"road_drag":
			at = Vector3(200, 0.6, 115)
			zoom = 33
		"three_houses":
			at = Vector3(193, 0.9, 119)
			zoom = 38
			angle = 54
		"move_in":
			at = Vector3(191.5, 1, 99)
			zoom = 24
			angle = 34
		"fruit_stall":
			at = Vector3(184, 0.8, 116)
			zoom = 32
		"floor":
			at = Vector3(187, 2.2, 121)
			zoom = 20
			angle = 36
		"garden", "fountain":
			at = Vector3(200, 0.8, 121)
			zoom = 24
		"arena_build":
			at = Vector3(207, 2, 138)
			zoom = 43
			angle = 53
		"cityrise":
			at = Vector3(192, 0, 132)
			zoom = 80
			angle = 67
	return {"dur": 10.0, "hour": [10.0, 10.1], "life": 10.0, "warm": 2.0, "blur": 0.0,
		"keys": [[0, at, 0, angle, zoom]], "v": {"dist": 1.0, "fov": 32.0}}


func _boot_args(hour: float) -> Dictionary:
	var boot := super._boot_args(hour)
	if clip_name in CITY_CLIPS or clip_name in LEGION_CLIPS:
		boot.erase("promo")
		boot.erase("noui")
		boot["new"] = "1"
		boot["shot"] = "D:/CivCity/.work/stage7/promo27/unused.png"
	elif clip_name in ["rain", "autumn", "festival", "boats", "harvest"]:
		boot["cozy"] = "1"
		if clip_name == "autumn":
			boot["seasons"] = "1"
	return boot


func _setup(full: bool) -> void:
	city = game.city
	hud = game.hud
	game.weather.force = 0.0
	match clip_name:
		"rain":
			game.weather.force = 0.9
		"autumn":
			game.seasons.force_m = 9.4
		"festival":
			# Витрина скрывает праздничное убранство, включаем его штатным действием города.
			city.money = maxf(city.money, 100000)
			var mode: String = game.mode
			game.mode = "new"
			var lit := city.festival()
			game.mode = mode
			if not lit:
				_fail(city.can_festival())
			elif game.fest_vis.is_empty() or (game.fest_vis["h"] as Array).is_empty():
				_fail("нет праздничного убранства")
		"boats":
			var lake: Boats = game.get_node("Boats")
			for b: Dictionary in lake.boats:
				if (b["c"] as Vector2).distance_to(Vector2(130, 182)) < 1.0:
					boat = b["n"]
					break
			if not is_instance_valid(boat):
				_fail("лодка не найдена")
		"top_down":
			_center_on_roof()
	if clip_name in CITY_CLIPS or clip_name in LEGION_CLIPS:
		_setup_gameplay()
	else:
		super._setup(full)


func _center_on_roof() -> void:
	var mid := Vector2(176, 157)
	var nearest := INF
	for b: Dictionary in city.buildings.values():
		if not city.is_house(b):
			continue
		var p: Vector2 = b["pos"]
		var d := mid.distance_squared_to(p)
		if d < nearest:
			nearest = d
			keys[0][1] = Vector3(p.x, float(b["y"]) + 2.8, p.y)
	if nearest == INF:
		_fail("нет дома для верхнего плана")


func _pose(t: float) -> void:
	super._pose(t)
	var cam: Camera3D = rig.cam
	rig.target = cam.global_position - cam.global_transform.basis.z * (rig.attrs.dof_blur_far_distance / 1.12)


func _anchor() -> void:
	if follow == "boat" and is_instance_valid(boat):
		anchor_pos = boat.global_position
	else:
		super._anchor()


func _gate() -> bool:
	if clip_name == "battle":
		return is_instance_valid(battle) and battle.phase in ["intro", "fight"] and battle.fade.modulate.a <= 0.001
	if clip_name in ["fort", "recruit"]:
		return is_instance_valid(camp) and camp.visible and not camp.opening and is_instance_valid(camp.diorama)
	return super._gate()


func _setup_gameplay() -> void:
	game.can_save = false
	game.settings["autosave"] = false
	game.settings["advisor_off"] = true
	game.settings["line_road"] = false
	game.tutorial.step = Tutorial.STEPS.size()
	game.tutorial.card.hide()
	game.tutorial.set_process(false)
	I18n.set_lang("ru")
	city.tips["tut"] = -1
	city.tips["ui"] = 3
	city.tips["free_place"] = true
	city.level = 7 if clip_name == "arena_build" else 3
	city.money = 92000 if clip_name == "arena_build" else 12500
	city.rp = 32
	city.goal_pace = false
	hud.visible = clip_name != "cityrise"
	hud.apply_reveal(3)
	hud.close_panels()
	hud.advisor_panel.hide()
	if clip_name in ["cityrise", "three_houses", "floor", "fruit_stall", "fountain", "arena_build"]:
		hud.set_speed(4.0)
	if clip_name == "cityrise":
		_cityrise()
		return
	# Обычные инструменты и подсветка работают, камера получает позу только от съёмки.
	rig.cine = false
	rig.set_process(false)
	rig.set_process_unhandled_input(false)
	rig.set_process_input(false)
	_make_cursor()
	if clip_name in LEGION_CLIPS:
		_setup_legion()
		return
	if clip_name != "road_drag":
		_road(Vector2(179, 115), Vector2(214, 115))
		var door := city.door_point(city.center())
		_road(door, Vector2(door.x, 115))
	if clip_name not in ["move_in", "three_houses", "requests", "road_drag", "arena_build"]:
		feature = _home(Vector2(187, 121), PI, 0, true)
		_home(Vector2(179, 121), PI, 1, true)
		_home(Vector2(187, 108), 0, 2, true)
	city.compute()
	match clip_name:
		"road_drag":
			_at(0.8, _tool.bind("road"))
			_at(1.8, _point.bind(ROAD_A))
			_at(2.8, _start_road)
			_at(7.1, _end_road)
		"three_houses":
			_at(0.6, _tool.bind("house_pleb"))
			for i in 3:
				_build_at(2.6 + 2.8 * i, "house_pleb", Vector2(183 + 8 * i, 121))
		"move_in":
			_move_in_plan()
		"fruit_stall":
			city.auto_hire = false
			_at(1.0, _tool.bind("stall_fruit"))
			_at(3.9, _preview_build.bind("stall_fruit", Vector2(182, 112)))
			_at(5.4, _verify_preview)
			_at(6.5, _commit_build.bind("stall_fruit"))
			_at(7.5, _clear_tool)
		"hire":
			city.auto_hire = false
			feature = _place("stall_fruit", Vector2(198, 111), 0, 0)
			city.compute()
			_at(1.5, _point.bind(feature.get("pos", CENTER)))
			_at(2.5, hud.open_info.bind(feature))
			_at(4.1, _aim_node.bind("hire_plus"))
			_at(5.8, _press_node.bind("hire_plus"))
			_at(6.5, _verify_hire)
		"floor":
			city.research["floor2"] = true
			_at(1.1, _aim_control.bind(hud.tool_btns.get("floor")))
			_at(2.6, _tool.bind("floor"))
			_at(3.5, _point.bind(feature.get("pos", CENTER), 2.0))
			_at(5.4, _buy_floor)
		"garden":
			city.research["deco_garden"] = true
			_at(1.0, _tool.bind("parterre_2"))
			_build_at(5.2, "parterre_2", Vector2(198, 122))
		"fountain":
			city.research["fountain"] = true
			_at(1.0, _tool.bind("fountain"))
			_build_at(4.2, "fountain", Vector2(201, 122))
		"requests":
			_setup_request()
		"research":
			_at(1.5, _aim_control.bind(hud.top_btns.get("research")))
			_at(2.9, hud._top_action.bind("research"))
			_at(5.8, _aim_control.bind(hud.research_panel))
		"arena_build":
			city.research["colosseum"] = true
			for i in 9:
				_home(Vector2(157 + 8 * (i % 4), 109 + 14 * (i / 4)), 0, i % 3, true)
			_road(Vector2(153, 129), Vector2(224, 129))
			city.compute()
			_at(0.8, _tool.bind("colosseum"))
			_build_at(3.3, "colosseum", Vector2(207, 140))
			_at(13.7, _verify_spectators)
	hud.refresh()


func _events(t: float) -> void:
	if not (clip_name in CITY_CLIPS or clip_name in LEGION_CLIPS):
		super._events(t)
		return
	if not started_recording:
		started_recording = true
		if not _gate():
			_fail("сцена не закончила загрузку")
	while event_index < events.size() and t >= float(events[event_index][0]):
		var action: Callable = events[event_index][1]
		action.call()
		event_index += 1
	if is_instance_valid(cursor):
		game._mouse_pos = cursor.position
	if started_road:
		var u := smoothstep(2.8, 7.1, t)
		var p := ROAD_A.lerp(ROAD_B, u)
		_set_cursor(_screen(p))
		game._paint_to(p)
	if clip_name == "arena_build" and t >= 7.8 and not arena_gathering:
		_gather_spectators()


func _at(t: float, action: Callable) -> void:
	events.append([t, action])


func _make_cursor() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	cursor = Node2D.new()
	cursor.position = Vector2(W * 0.64, H * 0.54)
	layer.add_child(cursor)
	var path := PackedVector2Array([Vector2(0, 0), Vector2(1, 26), Vector2(7, 19),
		Vector2(12, 28), Vector2(17, 25), Vector2(12, 16), Vector2(22, 15)])
	var fill := Polygon2D.new()
	fill.color = Color("ffefcc")
	fill.polygon = path
	cursor.add_child(fill)
	var border := Line2D.new()
	border.width = 2.0
	border.default_color = Color("432e20")
	border.closed = true
	border.points = path
	cursor.add_child(border)


func _screen(p: Vector2, y := 0.2) -> Vector2:
	return rig.cam.unproject_position(Vector3(p.x, game.land.height_at(p.x, p.y) + y, p.y))


func _set_cursor(p: Vector2) -> void:
	if is_instance_valid(cursor_tween):
		cursor_tween.kill()
	cursor.position = p
	game._mouse_pos = p


func _aim(p: Vector2) -> void:
	if is_instance_valid(cursor_tween):
		cursor_tween.kill()
	cursor_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cursor_tween.tween_property(cursor, "position", p, 0.8)


func _point(p: Vector2, y := 0.2) -> void:
	_aim(_screen(p, y))


func _aim_control(control: Control) -> void:
	if is_instance_valid(control) and control.is_visible_in_tree():
		_aim(control.get_global_rect().get_center())


func _aim_node(name: String) -> void:
	_aim_control(hud.find_child(name, true, false) as Control)


func _press_node(name: String) -> void:
	var b := hud.find_child(name, true, false) as Button
	if b == null or b.disabled:
		_fail("недоступна кнопка " + name)
		return
	b.pressed.emit()


func _verify_hire() -> void:
	if city.hired_of(feature) != 1:
		_fail("лавка не наняла работника")


func _tool(name: String) -> void:
	game.set_tool(name)


func _road(a: Vector2, b: Vector2) -> void:
	city.road_cells += game.land.paint_line(a, b, 1.75, Land.Kind.ROAD, true).size()
	var steps := maxi(1, ceili(a.distance_to(b)))
	for i in steps + 1:
		game.clear_nature(a.lerp(b, float(i) / steps), 1.8)


func _start_road() -> void:
	game.hover = ROAD_A
	game._click()
	started_road = game.painting
	if not started_road:
		_fail("мазок дороги не начался")


func _end_road() -> void:
	game._paint_to(ROAD_B)
	game._release()
	started_road = false
	game.set_tool("")


func _build_at(t: float, type: String, p: Vector2) -> void:
	_at(t - 1.4, _preview_build.bind(type, p))
	_at(t, _commit_build.bind(type))
	_at(t + 1.0, _clear_tool)


func _preview_build(type: String, p: Vector2) -> void:
	_tool(type)
	for step in [Vector2.ZERO, Vector2(0, 2), Vector2(0, -2), Vector2(3, 0), Vector2(-3, 0), Vector2(0, 5)]:
		var q: Vector2 = p + step
		var plan: Dictionary = game.placement(type, q)
		if plan.get("err", "!") == "" and (type != "stall_fruit" or not plan.get("noroad", false)):
			gesture = q
			_point(q)
			return
	_fail("нет места для " + type)


func _verify_preview() -> void:
	if game.cover.lit.is_empty() or (game.cover.sets.get("green", []) as Array).is_empty():
		_fail("нет зелёного охвата лавки")


func _commit_build(type: String) -> void:
	game.hover = gesture
	_set_cursor(_screen(gesture))
	var before := city.buildings.size()
	game._build_here()
	if city.buildings.size() <= before:
		_fail("не удалось построить " + type)


func _clear_tool() -> void:
	game.set_tool("")


func _place(type: String, at: Vector2, yaw: float, variant: int, animate := false) -> Dictionary:
	game.build_anim = animate
	var b := city.place(type, at, yaw, variant, 0, true)
	game.build_anim = false
	return b


func _home(at: Vector2, yaw: float, variant: int, occupied: bool) -> Dictionary:
	var h := _place("house_pleb", at, yaw, variant)
	if not h.is_empty() and occupied:
		_fill(h)
		h["happy"] = 95
		for f: Dictionary in h["families"]:
			game.people._make_family(f["name"], int(f["n"]), int(h["id"]), city.door_point(h), "plebs", f)
	return h


func _buy_floor() -> void:
	if feature.is_empty():
		_fail("нет дома для этажа")
		return
	feature["happy"] = 95
	var old := int(feature["tier"])
	game._floor_buy(feature)
	if int(feature["tier"]) == old:
		_fail(city.can_buy_floor(feature))
	game._floor_end()
	_clear_tool()


func _move_in_plan() -> void:
	feature = _home(Vector2(196.5, 102), -PI / 2, 1, false)
	if feature.is_empty():
		_fail("нет дома для новосёлов")
		return
	house_site = feature["pos"]
	city.compute()
	city.incoming = 1
	var cart_data: Dictionary = game.people.cart
	cart_data["state"] = "wait"
	cart_data["t"] = 0.0
	cart_data["show"] = true
	_at(0.0, game.people.cart_seek_z.bind(91.0))
	_at(4.4, _settle_prepare)
	_at(5.1, _point.bind(house_site, 1.4))
	_at(6.4, _settle_commit)
	_at(9.0, hud.set_speed.bind(2.0))
	_at(14.7, _verify_move_in)


func _settle_prepare() -> void:
	if city.arrivals.is_empty():
		return
	game.start_settle(String(city.arrivals[0]["name"]))


func _settle_commit() -> void:
	if game.settle_fam.is_empty():
		_settle_prepare()
	if game.settle_fam.is_empty() or not game._settle_into(feature):
		_fail("семья не выбрала дом")


func _verify_move_in() -> void:
	if int(feature.get("pop", 0)) == 0:
		_fail("семья ещё не вошла в дом")


func _setup_request() -> void:
	for q: Dictionary in Defs.REQUESTS:
		if q["id"] not in ["fruit", "scriptorium", "lights"]:
			city.goals_done.append(q["id"])
	game.settings["tasks_folded"] = false
	_at(1.0, _aim_control.bind(hud.tasks_panel))
	_at(2.8, _tool.bind("stall_fruit"))
	_build_at(5.9, "stall_fruit", Vector2(187, 112))
	_at(8.0, _verify_request)


func _verify_request() -> void:
	if not city.goals_done.has("fruit"):
		_fail("просьба не выполнена")


func _gather_spectators() -> void:
	var v: Dictionary = game.spectacle.venue_of("colosseum")
	if not v.is_empty():
		arena_gathering = true
		game.spectacle.force(int(v["id"]), "gather", 0.92)


func _verify_spectators() -> void:
	var venue: Dictionary = game.spectacle.venue_of("colosseum")
	if venue.is_empty() or (venue["who"] as Array).size() < 18:
		_fail("трибуны не заполнились")


func _setup_legion() -> void:
	var legion := city.legion
	legion.flags["camp_open"] = true
	legion.flags["camp_told"] = true
	legion.flags["camp3d_guide"] = 4
	legion._fort_init()
	legion.fort["money"] = 4000
	legion.glory = 150
	legion.rations = 300
	FortFixture.set_level(legion, "hq", 2)
	for type in ["barracks", "kitchen", "forge", "store"]:
		FortFixture.set_level(legion, type, 1)
		var worker := legion._add_soldier({"name": Defs.FAMILIES[randi() % Defs.FAMILIES.size()], "cls": "legionary", "stars": 2})
		legion.fort_assign(int(legion.fort_slot_plot(type)["id"]), int(worker["id"]))
	for i in 3:
		var unit := legion._add_soldier({"name": Defs.FAMILIES[i], "cls": "legionary", "stars": 2})
		legion.set_place(i, int(unit["id"]))
	FortFixture.gate(legion)
	match clip_name:
		"battle":
			cursor.hide()
			var setup := legion.make_battle(legion.stage_info(0, 0, 1), 27)
			setup.erase("tutorial")
			battle = LegionBattle.open(game, setup, Callable(), {"speed": 1.0, "auto": true})
		"campaign":
			LegionUi.of(hud).open("campaign")
			_at(1.0, _aim.bind(Vector2(W * 0.41, H * 0.55)))
			_at(5.0, _aim.bind(Vector2(W * 0.57, H * 0.42)))
		_:
			camp = CampUI.of(hud)
			camp.open()
			if clip_name == "fort":
				cursor.hide()
			else:
				_at(2.2, camp.show_recruit_picker)
				_at(3.8, _aim_recruit)
				_at(5.8, _recruit)


func _aim_recruit() -> void:
	var picks := city.legion.recruit_candidates()
	if not picks.is_empty():
		_aim_control(camp.find_child("FortGate_%d" % int(picks[0]["id"]), true, false) as Control)


func _recruit() -> void:
	var picks := city.legion.recruit_candidates()
	if picks.is_empty():
		_fail("нет кандидата в легион")
		return
	camp._recruit_pick(picks[0])


func _cityrise() -> void:
	# Новые улицы и дома появляются волнами, камера остаётся на месте.
	for unlock: String in ["artisans", "fountain", "deco_garden", "temple"]:
		city.research[unlock] = true
	_at(2.5, _road.bind(Vector2(192, 123), Vector2(192, 165)))
	_at(6.7, _road.bind(Vector2(176, 127), Vector2(176, 164)))
	for row in 6:
		var z := 109.0 + 9.5 * row
		var t := 1.2 + 2.2 * row
		_at(t, _road.bind(Vector2(166, z), Vector2(205 if row >= 3 else 219, z)))
		for col in 7:
			var x := 168.0 + 8.0 * col
			if col != 3 and (row < 3 or col not in [1, 5, 6]):
				_at(t + 0.3 + 0.22 * col, _rise_place.bind("house_pleb" if row < 3 else "house_artisan",
					Vector2(x, z + 4.5), PI, (row + col) % 3, true))
	_at(3.5, _rise_place.bind("stall_fruit", Vector2(196, 104), 0.0, 0, true))
	_at(7.7, _rise_place.bind("fountain", Vector2(196, 131), 0.0, 0, true))
	_at(11.2, _rise_place.bind("parterre_2", Vector2(204, 146), 0.0, 0, true))
	_at(13.2, _rise_place.bind("temple", Vector2(162, 156), PI, 0, true))
	_at(18.5, _verify_cityrise)
	events.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))


func _rise_place(type: String, at: Vector2, yaw: float, variant: int, animate: bool) -> void:
	var check := city.check_place(type, at, yaw, variant, 0)
	if check["err"] == "" and not _place(type, at, yaw, variant, animate).is_empty():
		rise_buildings += 1


func _verify_cityrise() -> void:
	if rise_buildings < 22:
		_fail("построек в таймлапсе: %d" % rise_buildings)


func _fail(reason: String) -> void:
	push_error("PROMO27 FAIL %s: %s" % [clip_name, reason])
	get_tree().quit(2)
