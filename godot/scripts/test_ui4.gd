extends Node3D
## UI4: реальные нужды, пять видов значков и пять кадров. Godot запускает проверяющий.

const Preference = preload("res://scripts/family_preference.gd")
const Badge = preload("res://scripts/map_badge.gd")
var out := "D:/CivCity/.work/stage4/ui4/shots/"
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


func check(ok: bool, why: String) -> bool:
	if not ok:
		fails += 1
		print("UI4 FAIL " + why)
	return ok


func shot(file: String) -> void:
	hud.advisor_panel.hide()
	await frames(12)
	hud._place_badges()
	await RenderingServer.frame_post_draw
	if check(get_viewport().get_texture().get_image().save_png(out + file) == OK, "save " + file):
		print("UI4 SHOT " + out + file)


func place(type: String, pos: Vector2, with_road := true, variant := 0) -> Dictionary:
	var b := city.place(type, pos, 0.0, variant, 0, true)
	check(not b.is_empty(), "fixture " + type)
	if with_road and not b.is_empty():
		var door := city.door_point(b)
		game.land.paint_line(door, Vector2(Land.ROAD_X, door.y), 0.9, Land.Kind.ROAD)
	return b


func family(home: Dictionary, name: String, child := false) -> void:
	var cls := String(city.def(home)["cls"])
	var f := {"name": name, "n": 3 if child else 2, "cls": cls}
	var members := Residents.gen(name, int(f["n"]), cls, int(home["id"]))
	if child:
		members[2]["age"] = 0
	f["m"] = members
	home["families"].append(f)
	home["pop"] = int(home["pop"]) + int(f["n"])
	game.people._make_family(name, int(f["n"]), int(home["id"]), city.door_point(home), cls, f)


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
	game.settings["tasks_folded"] = true
	game.speed = 0.0
	game.build_anim = false
	game.rig.cine = true
	game.tutorial.step = Tutorial.STEPS.size()
	game.tutorial.card.hide()
	game.tutorial.set_process(false)
	I18n.set_lang("ru")
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1440, 900)
	hud = game.hud
	city = game.city
	city.wants_v = 0  # прежняя фикстура; CITY5a — test_city5a
	city.cozy_v = 1
	city.auto_hire = false
	city.level = 5
	city.money = 1000000
	city.tips["tut"] = -1
	city.tips["ui"] = 3
	city.research["floor2"] = true
	city.research["artisans"] = true
	hud.apply_reveal(3)
	hud.close_panels()
	if not check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory"):
		_finish()
		return
	var plebs := place("house_pleb", Vector2(177, 136))
	plebs["tier"] = 2
	family(plebs, "Юлии", true)
	var patrician := place("house_patrician", Vector2(173, 154), true, Defs.PAT_TOWN)
	patrician["tier"] = 3
	for name: String in ["Корнелии", "Клавдии", "Фабии"]:
		family(patrician, name, true)
	var ready := place("house_pleb", Vector2(177, 116))
	family(ready, "Ливии", true)
	var bare := place("house_pleb", Vector2(145, 158))
	family(bare, "Валерии", true)
	var isolated := place("house_pleb", Vector2(227, 122), false)
	family(isolated, "Туллии")
	var fruit := place("stall_fruit", Vector2(183, 137))
	var temple := place("temple", Vector2(155, 131))
	var weaver := place("weaver", Vector2(165, 151))
	var potter := place("potter", Vector2(181, 161))
	var dice := place("dice", Vector2(164, 164))
	var no_workers := place("barber", Vector2(207, 130))
	place("forum", Vector2(150, 108))
	# Два взрослых в каждой семье: нанимаем настоящие записи жителей.
	city.compute()
	for b: Dictionary in [fruit, temple, dice]:
		check(city.hire(b, city.job_max(b)) == city.job_max(b), "full staff " + String(b["type"]))
	for b: Dictionary in [weaver, potter]:
		check(city.hire(b, 1) == 1, "half staff " + String(b["type"]))
	var waiting := city.new_family("plebs")
	city.family_arrived(waiting, false)
	game.people._on_resident_returned(waiting)
	city.compute()
	city.changed.emit()
	city.arrivals_changed.emit()
	await frames(15)
	_check_needs(plebs, patrician, temple, ready, bare)
	hud._update_world_icons()
	hud._family_badge_next_ms = 0
	hud._family_badges()
	hud.close_panels()
	game.rig.set_view(Vector3(183, 3, 134), 0, 50, 94)
	await frames(8)
	hud._place_badges()
	_check_badges(isolated, no_workers, ready, bare, waiting)
	await shot("1_badges_close.png")
	game.rig.set_view(Vector3(183, 3, 134), 0, 50, 160)
	await frames(8)
	hud._place_badges()
	var problem: Control = hud.badges["b%d" % int(bare["id"])]["n"]
	check(problem.visible and problem.scale.x >= 0.85 and is_equal_approx(problem.modulate.a, 1.0), "problem pin stays clear at far zoom")
	await shot("2_badges_far.png")
	hud._badge_click("b%d" % int(bare["id"]))
	check(int(hud.info_b.get("id", -1)) == int(bare["id"]), "problem pin opens house card")
	hud.house_more = false
	game.rig.set_view(Vector3(174, 2, 137), 0, 48, 65)
	game.select_building(plebs)
	hud.open_info(plebs)
	await frames(6)
	_check_card(plebs, 1)
	check((hud.info_box.find_child("need_clothes", true, false) as Control).get_meta("state") == "disabled", "unneeded clothes grey in plebs card")
	check(_texts(hud.info_box).contains("Место ещё для 1 семьи"), "free family floor visible")
	await shot("3_house_card_plebs.png")
	game.select_building(patrician)
	hud.open_info(patrician)
	await frames(6)
	_check_card(patrician, 3)
	await shot("4_house_card_patrician.png")
	# Никакой обрезки после четвёртой семьи, и в подробном режиме тоже.
	family(patrician, "Эмилии")
	family(patrician, "Антонии")
	city.compute()
	for details: bool in [false, true]:
		hud.house_more = details
		hud.open_info(patrician)
		_check_card(patrician, 5)
	hud.close_panels()
	hud._open_overview("city")
	await frames(6)
	var strip := hud.overview_pages["city"].find_child("NeedStrip", true, false) as Control
	check(strip != null and strip.get_child_count() == 6, "overview contains six needs")
	if strip != null:
		for n: String in Defs.NEED_ORDER:
			check(int(strip.get_node("need_" + n).get_meta("coverage")) == int(city.stats["needs"][n]["coverage"]), "overview uses average " + n)
	await shot("5_overview_needs.png")
	hud.close_panels()
	_perf()
	_finish()


func _check_needs(plebs: Dictionary, patrician: Dictionary, temple: Dictionary, ready: Dictionary, bare: Dictionary) -> void:
	check(Defs.NEED_ORDER.size() == 6 and Defs.NEEDS.size() == 6, "six needs in data")
	check(Defs.CLASSES["plebs"]["needs"].size() == 2 and Defs.CLASSES["artisans"]["needs"].size() == 4 and Defs.CLASSES["patricians"]["needs"].size() == 6, "class requirements 2 / 4 / 6")
	for h: Dictionary in [plebs, patrician, ready, bare]:
		check(h["need_coverage"].size() == 6 and h["need_states"].size() == 6, "six computed values per house")
		for n: String in Defs.NEED_ORDER:
			var pct := int(h["need_coverage"][n])
			check(pct >= 0 and pct <= 100 and h["need_states"][n] == HouseNeeds.state(pct), "state and range " + n)
	for pair: Array in [[0, "red"], [33, "red"], [34, "yellow"], [66, "yellow"], [67, "green"], [100, "green"]]:
		check(HouseNeeds.state(int(pair[0])) == pair[1], "boundary " + str(pair[0]))
	check(int(plebs["need_coverage"]["faith"]) == 100 and plebs["needs"].has("faith") and not plebs["missing"].has("faith"), "temple covers faith")
	check(plebs["need_sources"]["faith"].any(func(e: Dictionary) -> bool: return int(e["id"]) == int(temple["id"])), "temple listed as faith source")
	check(int(plebs["mon_types"].get("temple", 0)) == int(Defs.B["temple"]["bonus"]), "temple retains monument bonus")
	check(patrician["need_states"]["food"] == "green" and patrician["need_states"]["clothes"] == "yellow" and patrician["need_states"]["goods"] == "yellow" and patrician["need_states"]["services"] == "red", "four needs show green, yellow, yellow, red")
	check(city.can_buy_floor(ready) == "", "real house ready for floor: " + city.can_buy_floor(ready))
	_check_shrines()
	# Алтари работают без дороги и не превращаются в лавки.
	for type: String in ["lararium", "altar", "altar_2"]:
		check(HouseNeeds.category(Defs.B[type]) == "faith", "small shrine " + type)
	var expected := 0.0
	var weight := 0
	for h: Dictionary in city.buildings.values():
		if city.is_house(h):
			expected += int(h["need_coverage"]["faith"]) * int(h["pop"])
			weight += int(h["pop"])
	check(int(city.stats["needs"]["faith"]["coverage"]) == roundi(expected / weight), "faith average weighted by residents")


func _check_shrines() -> void:
	var c := City.new(Land.new())
	c.cozy_v = 1
	c.level = 2
	var h := c.place("house_pleb", Land.START, 0.0, 0, 0, true)
	for type: String in ["lararium", "altar", "altar_2"]:
		var shrine := c.place(type, Land.START + Vector2(8, 0), 0.0, 0, 0, true)
		c.compute()
		check(int(h["need_coverage"]["faith"]) == 100 and float(h["deco"]) > 0, "shrine covers faith and keeps decoration " + type)
		shrine["pos"] = Land.START + Vector2(100, 100)
		c.compute()
		check(int(h["need_coverage"]["faith"]) == 0 and h["missing"].has("faith"), "shrine outside radius " + type)


func _check_badges(isolated: Dictionary, no_workers: Dictionary, ready: Dictionary, bare: Dictionary, waiting: Dictionary) -> void:
	var counts := {}
	for entry: Dictionary in hud.badges.values():
		var badge: Badge = entry["n"]
		counts[badge.kind] = int(counts.get(badge.kind, 0)) + 1
	for kind: String in ["family_waiting", "house_problem", "no_road", "no_workers"]:
		check(int(counts.get(kind, 0)) > 0, "badge count " + kind)
		print("UI4 BADGES ", kind, "=", int(counts.get(kind, 0)))
	for pair: Array in [[isolated, "road"], [no_workers, "no_workers"], [bare, "house_problem"]]:
		var key := "b%d" % int(pair[0]["id"])
		check(hud.badges.has(key) and hud.badges[key]["icon"] == pair[1], "correct badge " + String(pair[1]))
	check(not hud.badges.has("b%d" % int(ready["id"])) and not hud.badges.values().any(func(e: Dictionary) -> bool: return e["icon"] == "up"), "ready house has no permanent floor arrow")
	check(hud.floor_badge.text == str(city.floor_ready(false).size()), "floor readiness remains on button")
	var family_key := "fam_" + String(waiting["name"])
	check(hud.badges.has(family_key), "waiting family badge")
	if hud.badges.has(family_key):
		var badge: Badge = hud.badges[family_key]["n"]
		check(badge.size == Vector2(44, 44) and badge.ring == Badge.CLASS_RING["plebs"] and badge.get_child_count() == 0, "44px single family disc with class ring")


func _check_card(h: Dictionary, families: int) -> void:
	var strip := hud.info_box.find_child("NeedStrip", true, false) as Control
	check(strip != null and strip.get_child_count() == 6, "house has six icons")
	check(hud.info_box.find_children("family_*", "VBoxContainer", true, false).size() == families, "all families visible")
	check(hud.info_box.find_children("Members", "HFlowContainer", true, false).size() == families, "member heads in every family")
	for icon: Node in hud.info_box.find_children("Preference", "TextureRect", true, false):
		check((icon as Control).tooltip_text.contains("Хотят:") and (icon as Control).tooltip_text.contains("к счастью дома"), "preference tooltip has wish and actual effect")
	for n: String in Defs.CLASSES[city.def(h)["cls"]]["needs"]:
		check(hud.info_box.find_child("sources_" + n, true, false) != null, "needed source row " + n)


func _texts(node: Node) -> String:
	var text := String(node.text) + "\n" if node is Label or node is Button else ""
	for child in node.get_children():
		text += _texts(child)
	return text


func _perf() -> void:
	for i in maxi(0, 40 - hud.badges.size()):
		hud.set_badge("perf%d" % i, Vector3(180 + (i % 8), 8, 128 + (i / 8)), "family")
	hud._place_badges()
	hud.set_badge("perf_probe", Vector3(180, 8, 128), "family")
	hud._place_badges()
	var badge: Control = hud.badges["perf_probe"]["n"]
	var before := badge.position
	var started := Time.get_ticks_usec()
	for i in 200:
		hud._place_badges()
	var average := float(Time.get_ticks_usec() - started) / 200.0
	print("UI4 PLACE_US ", average)
	check(average <= 60.0 and badge.position == before, "UI2 static placement <=60us, no layout or bob")
	game.rig.cam.global_position += Vector3(3, 0, 0)
	hud._place_badges()
	check(badge.position != before, "camera movement refreshes cached positions")


func _finish() -> void:
	print("UI4 DONE fails=%d" % fails)
	get_tree().quit(0 if fails == 0 else 1)
