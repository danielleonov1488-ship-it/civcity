extends Node3D
## CITY5a-b: награды, земля, стрелки и огни. Движок запускает только проверяющий.

var out := "D:/CivCity/.work/stage5/city5a2/shots/"
var game
var city: City
var hud: Hud
var fails := 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
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
		print("CITY5A2 FAIL " + why)


func shot(file: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	hud.advisor_panel.hide()
	await frames(8)
	hud._place_badges()
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(out + file)
	check(error == OK, "save " + file)
	if error == OK:
		print("CITY5A2 SHOT " + out + file)


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
	city = game.city
	hud = game.hud
	city.tips["tut"] = -1
	city.tips["ui"] = 3
	hud.apply_reveal(3)
	hud.close_panels()
	check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory")
	_terrain()
	_rewards()
	await _floor()
	await _lantern()
	_finish()


func _terrain() -> void:
	var c := City.new(Land.new())
	var h := {"id": 1, "type": "house_pleb", "pos": Vector2(170, 140), "families": [], "pop": 4}
	c.buildings = {1: h}
	var at: Vector2 = h["pos"] + Vector2(8, 0)
	check(not FamilyWant.matches(c, h, "plaza"), "plaza cache starts false")
	var paint := c.land.paint_circle(at, 0.4, Land.Kind.PLAZA)
	check(not paint.is_empty() and FamilyWant.matches(c, h, "plaza"), "paint invalidates cached miss")
	var erase := c.land.paint_circle(at, 0.4, Land.Kind.GRASS)
	check(not erase.is_empty() and not FamilyWant.matches(c, h, "plaza"), "demolition invalidates cached hit")
	c.land.undo(erase)
	check(FamilyWant.matches(c, h, "plaza"), "undo demolition restores plaza want")
	c.land.undo(paint)
	check(not FamilyWant.matches(c, h, "plaza"), "undo paint removes plaza want")
	check(not FamilyWant.matches(c, h, "water"), "water cache starts false")
	var cell := c.land.cell(at)
	var k := c.land.idx(cell.x, cell.y)
	var old_y := float(c.land.h[k])
	c.land.h[k] = Land.WATER_Y - Land.STEP
	c.land._mark(cell.x, cell.y)
	check(FamilyWant.matches(c, h, "water"), "height edit invalidates cached miss")
	c.land.h[k] = old_y
	c.land._mark(cell.x, cell.y)
	check(not FamilyWant.matches(c, h, "water"), "drain invalidates cached hit")
	c.land.paint_circle(at, 0.4, Land.Kind.PLAZA)
	check(FamilyWant.matches(c, h, "plaza"), "plaza restored before moving home")
	h["pos"] = Vector2(150, 140)
	check(not FamilyWant.matches(c, h, "plaza"), "moving home invalidates terrain cache")
	h["pos"] = Vector2(170, 140)
	check(FamilyWant.matches(c, h, "plaza"), "moving home back sees plaza")
	var generation := c.land.gen
	c.land = Land.new()
	c.land.gen = generation
	check(not FamilyWant.matches(c, h, "plaza"), "new land with same generation invalidates terrain cache")


func _sum_parts(h: Dictionary) -> int:
	var result := 0
	for part: Array in h["happy_parts"]:
		result += int(part[1])
	return result


func _rewards() -> void:
	var c := City.new(Land.new())
	c.wants_v = 1
	c.cozy_v = 1
	var a := c.place("house_pleb", Vector2(170, 140), 0.0, 0, 0, true)
	var b := c.place("house_pleb", Vector2(150, 170), 0.0, 0, 0, true)
	check(not a.is_empty() and not b.is_empty(), "reward houses placed")
	if a.is_empty() or b.is_empty():
		return
	a["pop"] = 4
	a["families"] = [{"name": "Probe", "n": 4}]
	b["pop"] = 4
	b["families"] = [{"name": "Other", "n": 4}]
	c.compute(false, [int(a["id"]), int(b["id"])])
	# Сохраняем отставание от цели: награда не должна проматывать естественный дрейф.
	a["happy"] = 60
	var story := Stories.new()
	story.city = c
	var sd := {"id": "probe", "title": "Probe"}
	var binding := {"home": int(a["id"]), "fam": "Probe"}
	for reward: Dictionary in [{"happy_home": [8, 72]}, {"happy_area": [4, 10, 48]}, {"happy_all": [2, 24]}, {"happy_cls": ["plebs", 3, 24]}]:
		var before := float(a["happy"])
		var target := float(a["happy_target"])
		var other := float(b["happy"])
		var delta := 8 if reward.has("happy_home") else (4 if reward.has("happy_area") else (2 if reward.has("happy_all") else 3))
		story._give(reward, sd, binding, true)
		check(is_equal_approx(float(a["happy"]), before + delta) and is_equal_approx(float(a["happy_target"]), target + delta), "reward bumps display and target " + str(reward))
		var other_delta := 0 if reward.has("happy_home") or reward.has("happy_area") else delta
		check(is_equal_approx(float(b["happy"]), other + other_delta), "reward scope " + str(reward))
		for i in 3:
			c.compute(true)
		check(is_equal_approx(float(a["happy"]), before + delta), "compute does not repeat or smooth reward")
		check(_sum_parts(a) == int(a["happy"]), "reward parts match displayed happiness")
	var was := float(a["happy"])
	var expected := move_toward(was, float(a["happy_target"]), 5.0)
	c._happiness_hour()
	check(is_equal_approx(float(a["happy"]), expected), "natural drift stays limited to five per hour")
	var clock := c.clock_h
	c.add_story_bonus({"id": "fixture", "line": "Probe", "pct": 10, "home": int(a["id"]), "left": 24})
	check(is_equal_approx(float(a["happy"]), expected + 10) and c.clock_h == clock, "explicit fixture bumps happiness without advancing time")
	var other_before := float(b["happy"])
	c.compute(false, [int(a["id"])])
	check(is_equal_approx(float(a["happy"]), float(a["happy_target"])), "explicit home refresh snaps to target")
	check(is_equal_approx(float(b["happy"]), other_before), "explicit home refresh preserves other home's drift")
	a["happy"] = 40
	a["happy_target"] = 40
	a["unhappy_h"] = 3
	a["down"] = 19
	c.bump_happiness(a, 8)
	check(int(a["happy"]) == 48 and int(a["happy_target"]) == 48 and int(a["unhappy_h"]) == 0 and int(a["down"]) == 0, "instant recovery clears unhappy and leaving streaks")
	c.bump_happiness(a, 300)
	check(int(a["happy"]) == 200 and int(a["happy_target"]) == 200, "bump respects upper bound")
	c.bump_happiness(a, -300)
	check(int(a["happy"]) == 0 and int(a["happy_target"]) == 0, "bump respects lower bound")
	c.wants_v = 0
	c.compute(true)
	was = float(a["happy"])
	story._give({"happy_all": [5, 24]}, sd, binding, true)
	c.compute(true)
	check(is_equal_approx(float(a["happy"]), was + 5) and is_equal_approx(float(a["happy"]), float(a["happy_target"])), "legacy happiness stays instant without a double reward")
	story.free()


func _floor() -> void:
	city.level = 1
	city.money = 100000.0
	city.research["floor2"] = true
	var h := city.place("house_pleb", Vector2(177, 125), 0.0, 0, 0, true)
	check(not h.is_empty(), "floor house placed")
	if h.is_empty():
		return
	var door := city.door_point(h)
	city.land.paint_line(door - Vector2(3, 0), door + Vector2(3, 0), 1.0, Land.Kind.ROAD, true)
	city.settled(int(h["id"]), 4, "Probe")
	city.add_story_bonus({"id": "floor_fixture", "line": "Probe", "pct": 80, "home": int(h["id"]), "left": 48})
	city.compute()
	check(city.can_buy_floor(h) == "", "floor fixture ready")
	game.rig.set_view(Vector3(177, 2, 125), 0, 52, 45)
	game.set_tool("floor")
	await frames(8)
	var w := Vector3(177, float(h["y"]) + city.blueprint(h).top_y() + 1.2, 125)
	hud.set_badge("test_overlap1", w, "up", false, "111")
	hud.set_badge("test_overlap2", w, "up", true, "222")
	await frames(3)
	hud._place_badges()
	var n1: Control = hud.badges["test_overlap1"]["n"]
	var n2: Control = hud.badges["test_overlap2"]["n"]
	var p := n1.get_global_rect().intersection(n2.get_global_rect()).get_center()
	check(n1.is_visible_in_tree() and n2.is_visible_in_tree(), "overlap arrows visible in floor tool")
	check(hud.badge_at(p, "test_overlap") == "test_overlap2", "last drawn arrow wins overlap")
	check(hud.badge_at(p, "test_overlap", true) == "test_overlap1", "stroke skips red arrow to lower arrow")
	await shot("1_floor_overlap.png")
	game.set_tool("")
	await frames(3)
	check(not n1.visible and not n2.visible and hud.badge_at(p, "test_overlap") == "", "idle arrows hidden and cannot be picked")
	hud.clear_badge("test_overlap1")
	hud.clear_badge("test_overlap2")
	check(city.buy_floor(h), "buy floor")
	check(is_equal_approx(float(h["happy"]), float(h["happy_target"])), "floor immediately shows its new target")
	check(_sum_parts(h) == int(h["happy"]), "floor parts match displayed happiness")
	game.select_building(h)
	hud.open_info(h)
	await shot("2_floor_happiness.png")
	hud.close_panels()


func _lantern() -> void:
	var lamp := city.place("lamp_post", Vector2(170, 155), 0.0, 0, 0, true)
	check(not lamp.is_empty(), "lantern placed")
	if lamp.is_empty():
		return
	var lights: Array = game.visuals[int(lamp["id"])]["lights"]
	check(not lights.is_empty(), "lantern has real lights")
	var y := float(lamp["y"])
	var story: Stories = game.stories
	# Явная камера и свободный луч: проверяем скрытие, а не случайную тесноту свадебной улицы.
	var previous: CineKit = story.kit
	var processing := story.is_processing()
	var look0: float = game.look_hour
	var hour0: float = game.hour
	story.set_process(false)
	story.kit = CineKit.new()
	story.kit.pos = Vector3(170, y + 2.5, 150)
	story.kit.look = Vector3(170, y + 1.0, 160)
	game.rig.set_view(Vector3(170, y + 1.0, 155), 0, 25, 12)
	game.look_hour = Stories.DUSK
	game._set_hour(20.0)
	var handles: Array = game.visuals[int(lamp["id"])]["h"]
	check(not handles.is_empty(), "lantern has visible parts")
	story._trees_clear()
	story._trees_clear()
	game._set_hour(20.0)
	for handle: Array in handles:
		check(bool(game.parts.is_hidden(handle)), "lantern parts hide with the light")
	for light: OmniLight3D in lights:
		check(not light.visible and not game.night_lights.has(light), "hidden lantern stays dark during hour refresh")
	check(story._hid_lights.size() == lights.size(), "repeated clearing does not duplicate hidden lights")
	await shot("3_lantern_hidden.png")
	story.trees_back()
	for handle: Array in handles:
		check(not bool(game.parts.is_hidden(handle)), "lantern parts restore with the light")
	for light: OmniLight3D in lights:
		check(light.visible and game.night_lights.count(light) == 1, "lantern restores once at night")
	await shot("4_lantern_restored.png")
	game.look_hour = -1.0
	game._set_hour(11.0)
	for light: OmniLight3D in lights:
		check(not light.visible, "lantern follows daytime after restore")
	story.kit.free()
	story.kit = previous
	story.set_process(processing)
	game.look_hour = look0
	game._set_hour(hour0)


func _finish() -> void:
	print("CITY5A2 DONE fails=%d" % fails)
	get_tree().quit(0 if fails == 0 else 1)
