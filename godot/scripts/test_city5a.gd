extends Node3D
## CITY5a: модель и кадры. Godot запускает только проверяющий.

const Preference = preload("res://scripts/family_preference.gd")
var out := "D:/CivCity/.work/stage5/city5a/shots/"
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


func check(ok: bool, why: String) -> void:
	if not ok:
		fails += 1
		print("CITY5A FAIL " + why)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


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
		print("CITY5A SHOT " + out + file)


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
	check(city.wants_v == 1 and city.legion.v3(), "new game enables CITY5a and fort")
	check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory")
	_catalog()
	_wants()
	_happiness()
	_arrivals()
	await _floor_ui()
	_finish()


func _catalog() -> void:
	for category: Array in Defs.CATS:
		var types: Array = hud._types_in(String(category[0]), "food" if category[0] == "commerce" else "")
		for type: String in types:
			check(city.city_buildable(type), "catalog excludes military " + type)
	check(hud._types_in("military").is_empty(), "military catalog empty")
	city.level = 7
	for r: Dictionary in Defs.RESEARCH:
		city.research[r["id"]] = true
	hud.refresh()
	check(not (hud.cats["military"].get_parent() as Control).visible, "military tab stays hidden at last rank")
	for type: String in Defs.B:
		if Defs.B[type].get("kind", "") == "military":
			check(not city.unlocked(type) and not city.city_buildable(type), "fort building closed " + type)
			check(not String(city.check_place(type, Land.START, 0.0)["err"]).is_empty(), "placement rejects " + type)
			check(city.place(type, Land.START, 0.0).is_empty(), "direct placement rejects " + type)
	var old := City.new(Land.new())
	old.research["legion"] = true
	var barracks := old.place("barracks", Land.START, 0.0, 0, 0, true)
	var saved := old.save_data()
	old.load_data(saved)
	check(old.wants_v == 0 and old.buildings.has(barracks["id"]), "old save keeps military building and legacy rules")
	check(not old.city_buildable("barracks") and old.place("barracks", Land.START, 0.0).is_empty(), "old save cannot build another barracks")
	old.remove(old.buildings[barracks["id"]], false)
	check(not old.buildings.has(barracks["id"]), "old military building can be demolished")
	city.legion.sync_v2()
	var story: Dictionary = StoryDefs.story("bandits")
	check(not JSON.stringify(story).contains('"count","barracks"'), "bandits does not ask for city barracks")
	check(not JSON.stringify(StoryDefs.story("letter")).contains('"count","barracks"'), "letter does not require city barracks")
	city.level = 0
	city.research.clear()


func _wants() -> void:
	check(FamilyWant.ORDER.size() == 7 and FamilyWant.LOOK.size() == 7, "exactly seven wants")
	check(not FamilyWant.ORDER.has("cat") and not FamilyWant.ORDER.has("bather") and not FamilyWant.ORDER.has("baths"), "no cat or baths want")
	city.level = 0
	for i in 32:
		check(String(city.new_family("plebs").get("want", "")) == "", "no wants before Hamlet")
	city.level = 1
	var kinds := {}
	var count := 0
	for i in 512:
		var f := city.new_family("plebs")
		var want := String(f.get("want", ""))
		check(want == "" or want in FamilyWant.ORDER, "generated want is valid")
		if want != "":
			count += 1
			kinds[want] = true
	check(count >= 80 and count <= 180 and kinds.size() == 7, "about one in four families has a want")
	city.level = 0
	var probe := City.new(Land.new())
	probe.cozy_v = 1
	probe.wants_v = 1
	var h := {"id": 1, "type": "house_pleb", "pos": Vector2(170, 140), "families": [], "pop": 3}
	# Точные границы радиусов, рабочая лавка и отсутствие штрафа.
	for pair: Array in [["trees", "tree", 12.0], ["water", "fountain", 15.0], ["flowers", "planter", 10.0], ["market", "stall_fruit", 15.0], ["temple", "lararium", 25.0]]:
		var id := String(pair[0])
		var radius := float(pair[2])
		var b := {"id": 2, "type": String(pair[1]), "pos": h["pos"] + Vector2(radius, 0), "active": true}
		probe.buildings = {1: h, 2: b}
		var f := {"name": "Проба", "n": 3, "want": id}
		h["families"] = [f]
		check(Preference.matches(probe, h, f), "want matches at radius: " + id)
		var parts: Array = probe.trait_parts(h, 0, [], 0, {})
		check(parts.size() == 1 and int(parts[0][1]) == 5, "fulfilled want gives exactly +5: " + id)
		b["pos"] += Vector2(0.1, 0)
		check(not Preference.matches(probe, h, f) and probe.trait_parts(h, 0, [], 0, {}).is_empty(), "outside radius gives zero: " + id)
		if id == "market":
			b["pos"] = h["pos"]
			b["active"] = false
			check(not Preference.matches(probe, h, f), "closed food stall does not fulfil market")
	probe.buildings = {1: h}
	for i in 3:
		probe.buildings[2 + i] = {"id": 2 + i, "type": "house_pleb", "pos": h["pos"] + Vector2(5, i)}
	check(not FamilyWant.matches(probe, h, "quiet"), "three neighbours break quiet")
	probe.buildings.erase(4)
	check(FamilyWant.matches(probe, h, "quiet"), "two neighbours fulfil quiet")
	h["families"] = [{"name": "Тихие", "n": 3, "want": "quiet"}]
	check(int(probe.trait_parts(h, 0, [], 0, {})[0][1]) == 5, "quiet gives +5")
	# Вдали от площади станции: убираем единственный мазок, а не часть большой площади.
	check(not FamilyWant.matches(probe, h, "plaza"), "terrain fixture starts without plaza")
	var at: Vector2 = h["pos"] + Vector2(8, 0)
	var cell := probe.land.cell(at)
	probe.land.kind[probe.land.idx(cell.x, cell.y)] = Land.Kind.PLAZA
	probe.land.gen += 1
	check(FamilyWant.matches(probe, h, "plaza"), "small paved plaza fulfils want")
	h["families"] = [{"name": "Площадь", "n": 3, "want": "plaza"}]
	check(int(probe.trait_parts(h, 0, [], 0, {})[0][1]) == 5, "plaza gives +5")
	probe.land.kind[probe.land.idx(cell.x, cell.y)] = Land.Kind.GRASS
	probe.land.gen += 1
	check(not FamilyWant.matches(probe, h, "plaza"), "removing plaza invalidates cache")
	var height := float(probe.land.h[probe.land.idx(cell.x, cell.y)])
	probe.land.h[probe.land.idx(cell.x, cell.y)] = Land.WATER_Y - 0.25
	probe.land.gen += 1
	check(FamilyWant.matches(probe, h, "water"), "terrain water fulfils want")
	probe.land.h[probe.land.idx(cell.x, cell.y)] = height
	probe.land.gen += 1
	check(not FamilyWant.matches(probe, h, "water"), "drained water invalidates cache")
	probe.want_nature = func(_pos: Vector2, radius: float, id: String) -> bool: return id == "trees" and is_equal_approx(radius, 12.0)
	check(FamilyWant.matches(probe, h, "trees"), "natural grove counts")
	probe.want_nature = Callable()
	var legacy := {"name": "Юлии", "n": 3}
	check(Preference.main(legacy) in Balance.TRAIT_ORDER, "old family still has legacy traits")


func _road(c: City, b: Dictionary) -> void:
	var door := c.door_point(b)
	c.land.paint_line(door - Vector2(3, 0), door + Vector2(3, 0), 1.0, Land.Kind.ROAD, true)


func _happiness() -> void:
	var c := City.new(Land.new())
	c.cozy_v = 1
	c.econ = 1
	c.wants_v = 1
	c.auto_hire = true
	c.money = 100000.0
	var h := c.place("house_pleb", Vector2(177, 125), 0.0, 0, 0, true)
	_road(c, h)
	var f := c.new_family("plebs")
	f["want"] = "temple"
	c.family_arrived(f, false)
	check(c.assign(String(f["name"]), int(h["id"])), "family assigned")
	check(c.pending[f["name"]]["want"] == "temple", "want survives assignment")
	check(c.settled(int(h["id"]), int(f["n"]), String(f["name"])) == int(f["n"]), "family settled")
	check(int(h["happy"]) == maxi(60, int(h["happy_target"])), "new family starts at max(target, 60)")
	check(int(h["families"][0]["grace_until"]) == c.clock_h + 24, "grace lasts one day")
	var before := float(h["happy"])
	for i in 10:
		c.compute()
	check(is_equal_approx(before, float(h["happy"])), "repeated compute does not advance happiness")
	var shop := c.place("stall_fruit", Vector2(181, 128), 0.0, 0, 0, true)
	_road(c, shop)
	c.compute()
	check(is_equal_approx(before, float(h["happy"])), "new shop does not flip happiness instantly")
	check(int(h["happy_target"]) == 60, "first houses and one staffed food stall target 60")
	h["happy"] = 20
	c.sim_day()
	check(is_equal_approx(float(h["happy"]), 25.0), "one game hour raises happiness by at most five")
	h["happy"] = 90
	c.sim_day()
	check(is_equal_approx(float(h["happy"]), 85.0), "one game hour lowers happiness by at most five")
	# Защита от значка и отъезда даже при намеренно плохой фикстуре.
	for hour in range(c.clock_h, 24):
		h["happy"] = 0
		h["unhappy_h"] = 20
		h["down"] = 19
		check(c.unhappy_badge(h), "below 40 percent shows sad badge at hour %d" % hour)
		c.sim_day()
		check(int(h["pop"]) == int(f["n"]), "grace prevents leaving at hour %d" % hour)
	check(not c.house_in_grace(h), "grace ends at hour 24")
	h["happy"] = 39
	h["happy_target"] = 39
	h["unhappy_h"] = 0
	for i in 3:
		c._happiness_hour()
		check(c.unhappy_badge(h), "below 40 percent shows sad badge immediately")
	h["happy"] = 40
	h["happy_target"] = 40
	c._happiness_hour()
	check(not c.unhappy_badge(h) and int(h["unhappy_h"]) == 0, "40 percent clears unhappy streak")
	# JSON — тот же числовой формат, что у настоящего сохранения.
	h["happy"] = 63
	h["unhappy_h"] = 2
	var saved: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	c.load_data(saved)
	h = c.buildings[int(h["id"])]
	check(c.wants_v == 1 and int(h["happy"]) == 63 and int(h["unhappy_h"]) == 2, "save keeps displayed happiness and streak")
	check(h["families"][0]["want"] == "temple" and int(h["families"][0]["grace_until"]) == 24, "save keeps want and grace deadline")
	# Пять семей и одна лавка: первое звание достижимо без этажей и поздних классов.
	c.level = 0
	c.bulk = true
	for i in 4:
		var next := c.place("house_pleb", Vector2(170 + i * 5, 136), 0.0, 0, 0, true)
		_road(c, next)
		c.settled(int(next["id"]), 4, "Проба%d" % i)
	c.bulk = false
	c.compute()
	for i in 8:
		c.sim_day()
	check(int(c.stats["pop"]) >= 15 and int(c.stats["happy"]) >= 55, "starting homes can meet first-rank population and happiness")
	for r: Dictionary in Defs.RESEARCH:
		if int(r["lvl"]) == 0:
			c.research[r["id"]] = true
	var school := c.place("scriptorium", Vector2(165, 115), 0.0, 0, 0, true)
	_road(c, school)
	c.compute()
	check(c.rank_ok() and c.rank_up(), "first rank can be reached with early services")
	var empty := c.place("house_pleb", Vector2(160, 145), 0.0, 0, 0, true)
	var travelling := c.new_family("plebs")
	travelling["want"] = "water"
	c.family_arrived(travelling, false)
	check(c.assign(String(travelling["name"]), int(empty["id"])), "save fixture family is walking")
	var saved_travel: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	c.load_data(saved_travel)
	check(c.arrival(String(travelling["name"])).get("want", "") == "water", "walking family retains want after save and load")


func _arrivals() -> void:
	var c := City.new(Land.new())
	c.cozy_v = 1
	c.wants_v = 1
	for i in 128:
		check(c.pick_class() == "plebs", "rank zero arrival is plebeian")
		var load := c.make_load(1)
		check(not load.is_empty() and load[0]["cls"] == "plebs", "rank zero cart is plebeian")
	c.gifts["house_artisan"] = ["Друг"]
	check(not c.arrival_class_open("artisans"), "gift cannot bypass class research")
	c.level = 2
	c.research["artisans"] = true
	check(c.arrival_class_open("artisans"), "researched artisan housing allows arrivals")
	c.level = 7
	for r: Dictionary in Defs.RESEARCH:
		c.research[r["id"]] = true
	c.stats["pop"] = 39
	check(not c.arrival_class_open("patricians"), "sandbox patricians blocked below forty residents")
	c.stats["pop"] = 40
	check(c.arrival_class_open("patricians"), "patricians allowed from forty residents with research")
	c.research.erase("patricians")
	check(not c.arrival_class_open("patricians"), "population cannot bypass patrician research")


func _floor_ui() -> void:
	city.legion.sync_v2()
	city.level = 1
	city.money = 100000.0
	city.research["floor2"] = true
	var h := city.place("house_pleb", Vector2(177, 125), 0.0, 0, 0, true)
	_road(city, h)
	var f := city.new_family("plebs")
	f["want"] = "trees"
	city.family_arrived(f, false)
	city.assign(String(f["name"]), int(h["id"]))
	city.settled(int(h["id"]), int(f["n"]), String(f["name"]))
	h["happy"] = 80
	city.compute()
	check(city.can_buy_floor(h) == "", "floor fixture is ready")
	game.rig.set_view(Vector3(177, 2, 125), 0, 52, 65)
	game.set_tool("")
	hud.refresh()
	hud._update_world_icons()
	await frames(5)
	hud._place_badges()
	for key: String in hud.badges:
		var entry: Dictionary = hud.badges[key]
		if entry["icon"] == "up":
			check(not (entry["n"] as Control).visible, "floor arrow hidden outside tool")
	check(hud.floor_badge.visible and hud.floor_badge.text == str(city.floor_ready(false).size()), "floor button shows ready count")
	check(hud.floor_badge.get_theme_color("font_color") == Hud.C_GOOD, "floor counter is green")
	await shot("1_floor_idle.png")
	game.set_tool("floor")
	await frames(8)
	var key := "fl%d" % int(h["id"])
	check(hud.badges.has(key) and hud.badges[key]["icon"] == "up", "floor tool creates price arrow")
	await shot("2_floor_tool.png")
	game.set_tool("")
	await frames(5)
	check(not hud.badges.has(key), "leaving floor tool clears arrow")
	var empty := city.place("house_pleb", Vector2(168, 125), 0.0, 0, 0, true)
	city.place("tree", Vector2(165, 130), 0.0, 0, 0, true)
	var waiting := city.new_family("plebs")
	waiting["want"] = "trees"
	city.family_arrived(waiting, false)
	game.people._on_resident_returned(waiting)
	game.start_settle(String(waiting["name"]))
	await frames(8)
	var settle_key := "settle%d" % int(empty["id"])
	check(Preference.matches(city, empty, waiting), "settling house matches visible want")
	check(hud.badges.has(settle_key), "settling keys are present")
	if hud.badges.has(settle_key):
		check(bool(hud.badges[settle_key]["n"].get("matches")), "settling keys expose want match mark")
	await shot("3_want_match.png")
	game.set_tool("")


func _finish() -> void:
	print("CITY5A DONE fails=%d" % fails)
	get_tree().quit(0 if fails == 0 else 1)
