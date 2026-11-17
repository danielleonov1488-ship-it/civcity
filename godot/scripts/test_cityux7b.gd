extends "res://scripts/test_uni6_support.gd"

const DecorFacing = preload("res://scripts/decor_facing.gd")
## Запускает проверяющий. Все записи и снимки — в папке этой задачи.


func _ready() -> void:
	tag = "CITYUX7B"
	out = "D:/CivCity/.work/stage6/cityux7b/shots/"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=").trim_suffix("/") + "/"
	var profile := "D:/CivCity/.work/stage6/cityux7b/profiles/run_%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	if not check(DirAccess.make_dir_recursive_absolute(profile) == OK and DirAccess.make_dir_recursive_absolute(out) == OK, "isolated directories"):
		finish_run()
		return
	OS.set_environment("CIVCITY_SAVEDIR", profile)
	OS.set_environment("CIVCITY_NOLOGIN", "1")
	OS.set_environment("CIVCITY_NOMINPAUSE", "1")
	OS.set_environment("CIVCITY_HEROSCREEN", "0")
	GamePaths._dir = ""
	Game.sandbox = false
	Game.boot = {"new": "1", "nologin": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	game.can_save = false
	add_child(game)
	for i in 18000:
		if game.ready_done:
			break
		await get_tree().process_frame
	if not check(game.ready_done, "ready_done timeout"):
		finish_run()
		return
	city = game.city
	hud = game.hud
	game.can_save = false
	game.settings["autosave"] = false
	game.settings["advisor_off"] = false
	game.speed = 0.0
	game.build_anim = false
	game.tutorial.finish()
	game.stories.set_process(false)
	clear_guidance()
	city.tips["ui"] = 3
	city.tips["tut"] = -1
	city.tips["rank_pressed"] = true
	hud.apply_reveal(3)
	city.wants_v = 1
	city.cozy_v = 1
	city.money = 100000.0
	I18n.set_lang("ru")
	get_window().size = Vector2i(1440, 900)
	want_generation()
	penalties()
	await visual_checks()
	finish_run()


func want_generation() -> void:
	var first := City.new(Land.new())
	var second := City.new(Land.new())
	first.wants_v = 1
	second.wants_v = 1
	first.rng.seed = 731
	second.rng.seed = 731
	for rank: int in [0, 1]:
		first.level = rank
		second.level = rank
		var count := 0
		for i in 1024:
			var a := first.new_family("plebs")
			var b := second.new_family("plebs")
			check(a == b, "same city RNG gives same family")
			var want := String(a.get("want", ""))
			check(want == "" or want in FamilyWant.ORDER, "valid want id")
			count += int(want != "")
		check(count == 0 if rank == 0 else count >= 180 and count <= 330, "wants start at Hamlet, about one in four")
	var legacy := City.new(Land.new())
	legacy.wants_v = 0
	legacy.level = 6
	check(not legacy.new_family("plebs").has("want"), "legacy families keep their rules")


func penalties() -> void:
	var c := City.new(Land.new())
	c.cozy_v = 1
	c.wants_v = 1
	c.level = 2
	c.money = 100000.0
	c.research["ogorod"] = true
	var home := c.place("house_pleb", Vector2(177, 136), 0.0, 0, 0, true)
	var garden := c.place("ogorod", Vector2(185, 136), 0.0, 0, 0, true)
	if not check(not home.is_empty() and not garden.is_empty(), "economy fixture"):
		return
	for building: Dictionary in [home, garden]:
		var door := c.door_point(building)
		c.land.paint_line(door - Vector2(3, 0), door + Vector2(3, 0), 2.0, Land.Kind.ROAD, true)
	check(c.settled(int(home["id"]), 4, "Теренции") == 4, "economy family")
	home["happy"] = 40.0
	home["happy_target"] = 40.0
	c.compute()
	if not check(c.hire(garden) == 1, "resident assigned to workplace"):
		return
	c.compute()
	var full := float(garden["staff"])
	var tax := c.house_tax(home)
	home["happy"] = 39.0
	c.compute()
	check(full > 0.0 and is_equal_approx(float(garden["staff"]), full * 0.5), "below 40 halves this worker's output")
	check(is_equal_approx(c.house_tax(home), tax * 0.5), "below 40 halves tax")
	check(c.unhappy_badge(home), "below 40 immediately shows sad badge")
	home["happy"] = 40.0
	c.compute()
	check(is_equal_approx(float(garden["staff"]), full) and not c.unhappy_badge(home), "40 restores work and badge")
	var first: Dictionary = home["families"][0]
	first["grace_until"] = 0
	var other := first.duplicate(true)
	other["name"] = "Фабии"
	home["families"].append(other)
	home["pop"] = 8
	home["happy"] = 24.0
	c.clock_h = 100
	var quiet_events: Array = []
	var toasts: Array = []
	c.quiet.connect(func(text: String, icon: String): quiet_events.append([text, icon]))
	c.event.connect(func(text: String, icon: String): toasts.append([text, icon]))
	for i in 47:
		c._grow_house(home)
	check(home["families"].size() == 2 and int(home["down"]) == 47, "no departure before 48 hours")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	var loaded := City.new(Land.new())
	loaded.land.load_changes(c.land.save_changes())
	loaded.load_data(saved)
	check(int(loaded.buildings[home["id"]]["down"]) == 47, "48-hour counter survives JSON save")
	c._grow_house(home)
	check(home["families"].size() == 1 and int(home["pop"]) == 4 and int(home["down"]) == 0, "one family leaves at hour 48")
	check(quiet_events.size() == 1 and toasts.is_empty(), "departure goes only to bell")
	home["happy"] = 25.0
	home["down"] = 47
	c._grow_house(home)
	check(int(home["down"]) == 0 and home["families"].size() == 1, "25 resets continuous low happiness")


func visual_checks() -> void:
	city.level = 2
	city.research["deco_trees"] = true
	city.research["artisans"] = true
	var home := place("house_pleb", Vector2(177, 136))
	if home.is_empty():
		return
	check(city.settled(int(home["id"]), 4, "Теренции") == 4, "visual home occupied")
	var family: Dictionary = home["families"][0]
	game.people._make_family(String(family["name"]), 4, int(home["id"]), city.door_point(home), "plebs", family)
	city.tips.erase("want_advice")
	city.tips.erase("want_arrived")
	hud.tip_gap = true
	hud._tip_next = Time.get_ticks_msec() + 3600000
	for entry: Array in [["Плавтии", "plaza"], ["Помпеи", "water"], ["Фабии", ""]]:
		var f := {"name": entry[0], "n": 3, "cls": "plebs", "want": entry[1]}
		city.family_arrived(f, false)
		game.people._on_resident_returned(f)
	clear_guidance()
	hud._tip_next = Time.get_ticks_msec() + 3600000
	hud._fill_families()
	hud._family_badge_next_ms = 0
	hud._family_badges()
	await frames(20)
	var icons := hud.fam_box.find_children("WantIcon", "TextureRect", true, false)
	check(icons.size() == 2, "only waiting families with wants show small discs")
	for f: Dictionary in city.arrivals:
		var key := "fam_" + String(f["name"])
		if check(hud.badges.has(key), "family has map badge"):
			var badge = hud.badges[key]["n"]
			var want := String(f.get("want", ""))
			check(badge.preference_texture == (MapBadge.want_texture(want) if want != "" else null), "map and waiting medallions use same want texture")
	await shot("01_waiting_wants.png")
	check(String(city.tips.get("want_arrived", "")) == "plaza", "first actual wanted arrival queued advice")
	check(hud._want_advice(), "first arrived want explained")
	await frames()
	var advice_icon := hud.advisor_panel.find_child("WantAdviceIcon", true, false) as TextureRect
	check(hud.advisor_panel.visible and advice_icon != null and advice_icon.visible and advice_icon.texture == MapBadge.want_texture("plaza"), "want advisor contains matching icon")
	check(hud.adv_text.text.split("\n").size() <= 3 and not hud._want_advice(), "want advisor is short and once only")
	await shot("02_want_advice.png")
	clear_guidance()
	var stories: Stories = game.stories
	var active := {"id": "square", "home": home["id"], "fam": "Теренции", "step": 1, "flags": {}, "t0": 0, "id0": city.next_id}
	city.stories["offer"] = {}
	city.stories["active"] = active
	var info := stories.row_info()
	var parts: Array = info.get("parts", [])
	check(parts.size() == 3 and String(info["text"]).contains(":"), "quest has speaker and one row per requirement")
	for part: Dictionary in parts:
		check(String(part["text"]).contains("осталось") and String(part["icon"]) != "" and not part["do"].is_empty(), "checklist icon, remaining count, build action")
	stories.part_click(parts[0])
	check(game.tool == "bench" and hud.open_cat == "decor", "checklist opens build menu and selects bench")
	game.set_tool("")
	hud._close_tray()
	game.settings["tasks_folded"] = false
	hud.refresh()
	await shot("03_quest_checklist.png")
	var zone := Vector2(184, 164)
	game.rig.set_view(Vector3(zone.x, Land.BASE_Y, zone.y), 20, 48, 34)
	stories.choose_zone()
	check(game.tool == "story_zone", "choose place enters zone tool")
	var screen: Vector2 = get_viewport().get_camera_3d().unproject_position(Vector3(zone.x, city.land.height_at(zone.x, zone.y), zone.y))
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	Input.parse_input_event(motion)
	await frames()
	check(game.brush_ring.visible and game.brush_disc.visible, "zone ghost circle follows mouse")
	await shot("04_placing_zone.png")
	check(stories.place_zone(zone) and stories._hp(active).is_equal_approx(zone), "player fixes quest center")
	var zone_save: Dictionary = JSON.parse_string(JSON.stringify(city.save_data()))
	check(zone_save["stories"]["active"]["zone"] == [zone.x, zone.y], "zone is saved as ordinary JSON coordinates")
	check((stories.row_info()["buttons"] as Array).any(func(b: Array) -> bool: return b[0] == "Перенести"), "zone can be moved later")
	var bench := place("bench", zone + Vector2(2, 0))
	if not bench.is_empty():
		var counted := stories.progress(active, stories._step(active)["goal"])
		check(int(counted["benches"]) >= 1 and (bench["pos"] as Vector2).distance_to(home["pos"]) > 15.0, "items in chosen circle count far from original house")
	var before := stories._hp(active)
	check(not stories.place_zone(Vector2.INF) and not stories.place_zone(Vector2(-1000, -1000)) and stories._hp(active) == before, "invalid zone leaves chosen place unchanged")
	stories.choose_zone()
	game.set_tool("")
	check(stories._hp(active) == before, "cancel leaves prior zone unchanged")
	single_goal()
	await bench_direction(zone + Vector2(6, 5))
	game.set_tool("")
	city.stories["active"] = {}
	clear_guidance()
	home["happy"] = 10.0
	home["happy_target"] = 10.0
	city.compute()
	check(city.can_upgrade(home) == "", "needs and low happiness do not block upgrade")
	city.money = float(city.upgrade_price(home) - 1)
	check(city.can_upgrade(home) == "Не хватает денариев", "upgrade still checks money")
	city.money = 100000.0
	check(city.upgrade_house(home), "occupied house upgrades with missing needs")
	check(not (home["missing"] as Array).is_empty(), "new class missing needs computed immediately")
	hud.open_info(home)
	await frames()
	var block := hud.info_box.find_child("HouseMissing", true, false)
	check(block != null, "upgraded house shows missing block")
	if block != null:
		for need: String in Defs.needs_for("artisans", city.level):
			check((block.find_child("Missing_" + need, true, false) != null) == (int(home["need_coverage"].get(need, 0)) < 100), "missing block exactly matches " + need)
	game.rig.set_view(Vector3(177, Land.BASE_Y, 136), 20, 48, 32)
	await shot("06_upgraded_missing.png")
	clear_guidance()
	home["happy"] = 39
	city.tips.erase("unhappy_penalty")
	hud._once_tips()
	check(city.tips.has("unhappy_penalty") and hud.adv_text.text.split("\n").size() <= 2, "penalty explained once in two lines")
	clear_guidance()
	var empty := place("house_pleb", Vector2(164, 125))
	if not empty.is_empty():
		check(city.can_upgrade(empty) == "" and city.upgrade_house(empty), "empty houses can also upgrade")
	city.research["patricians"] = true
	city.compute()
	check(city.can_upgrade(home) == "" and city.upgrade_house(home), "domus upgrade also ignores needs and happiness")


func single_goal() -> void:
	var c := City.new(Land.new())
	var goal: Array = StoryDefs.goal_step(StoryDefs.story("square"), "square")["goal"]
	var index := 0
	for type: String in ["bench", "bench", "bench", "tree", "cypress", "well"]:
		index += 1
		c.buildings[index] = {"id": index, "type": type, "pos": Vector2(index, 0)}
	var result := Stories.square_eval(c, Vector2.ZERO, goal)
	check(bool(result["met"]) and not result.has("tier"), "one square goal without tiers")
	check(int(StoryDefs.story("square")["reward"]["monument"][0]) == 3, "one fixed square reward")
	c.buildings[7] = {"id": 7, "type": "sundial", "pos": Vector2(0, 2)}
	check(Stories.square_eval(c, Vector2.ZERO, goal) == result, "optional sundial does not change completion or reward")


func bench_direction(at: Vector2) -> void:
	game.set_tool("bench")
	var pl: Dictionary = game.placement("bench", at)
	if not check(String(pl.get("err", "")) == "", "valid bench preview fixture"):
		return
	for yaw: float in [0.0, PI * 0.5, PI]:
		pl["yaw"] = yaw
		game._decor_arrow(pl)
		check(game.decor_arrow != null and game.decor_arrow.visible, "front arrow on valid bench")
		var facing := DecorFacing.front(Catalog.make("bench", int(pl["tier"]), int(pl["variant"]), int(pl["color"])), "bench")
		var direction: Vector3 = Basis(Vector3.UP, yaw) * (facing["front"] as Vector3)
		check(game.decor_arrow.basis.z.dot(direction) > 0.99, "arrow rotates with actual model front")
		var fake := {"kw": 1, "id": -1, "type": "bench", "variant": pl["variant"], "color": pl["color"], "tier": pl["tier"]}
		for seat: Array in game.people._bench_seats(fake):
			var look := Vector3(sin(yaw + float(seat[1])), 0, cos(yaw + float(seat[1])))
			check(look.dot(direction) > 0.99, "seated citizens face the preview arrow")
	game.rig.set_view(Vector3(at.x, Land.BASE_Y, at.y), 20, 48, 14)
	game.place_info = pl
	var screen: Vector2 = get_viewport().get_camera_3d().unproject_position(Vector3(at.x, city.land.height_at(at.x, at.y), at.y))
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	Input.parse_input_event(motion)
	game.hover = at
	game._decor_arrow(pl)
	await shot("05_bench_front_arrow.png")
	pl["err"] = "Здесь занято"
	game._decor_arrow(pl)
	check(not game.decor_arrow.visible, "invalid placement hides arrow")
	game.set_tool("")
	check(not game.decor_arrow.visible, "leaving placement hides arrow")
