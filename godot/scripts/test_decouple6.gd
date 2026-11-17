extends Node3D
## Запускает владелец проверки. Пользовательские сохранения не пишем.

const Fixture = preload("res://scripts/test_fort_fixture.gd")
var game
var city: City
var fails := 0
var out := "D:/CivCity/.work/stage5/decouple6/shots/"


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=").trim_suffix("/") + "/"
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	game.can_save = false
	_run()


func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func check(ok: bool, message: String) -> bool:
	print(("DECOUPLE6 PASS " if ok else "DECOUPLE6 FAIL ") + message)
	if not ok:
		fails += 1
	return ok


func shot(file: String) -> void:
	await frames(8)
	if not check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory"):
		return
	await RenderingServer.frame_post_draw
	if check(get_viewport().get_texture().get_image().save_png(out + file) == OK, "save " + file):
		print("DECOUPLE6 SHOT " + out + file)


func _run() -> void:
	var waited := 0
	while not game.ready_done:
		await frames(5)
		waited += 5
		if waited >= 18000:
			check(false, "ready_done timeout")
			_finish()
			return
	city = game.city
	game.can_save = false
	game.settings["autosave"] = false
	game.speed = 0.0
	if game.tutorial.active():
		game.tutorial.step = Tutorial.STEPS.size()
		game.tutorial.card.visible = false
	city.tips["tut"] = -1
	city.tips["ui"] = 3
	game.hud.apply_reveal(3)
	game.hud.advisor_panel.visible = false
	city.level = 2
	city.money = 1000000.0
	city.auto_hire = true
	for i in 15:
		var home := city.place("house_pleb", Vector2(145 + 6 * (i % 8), 210 + 8 * (i / 8)), 0.0, 0, 0, true)
		if check(not home.is_empty(), "fixture house %d" % i):
			home["families"] = [{"name": "Юлии%d" % i, "n": 4, "cls": "plebs"}]
			home["pop"] = 4
	city.compute()
	_independence()
	_prices()
	_stories()
	_gate()
	_fort_payment()
	_rewards()
	_save_compatibility()
	city.level = 7
	city.money = 1000000.0
	for research: Dictionary in Defs.RESEARCH:
		city.research[String(research["id"])] = true
	game.hud.advisor_panel.visible = false
	game.set_tool("arch")
	await shot("city_price.png")
	game.set_tool("")
	game.hud.find_hero()
	await shot("city_hero.png")
	_finish()


func _finish() -> void:
	print("DECOUPLE6 DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _city_signature() -> Dictionary:
	var homes: Array = []
	var ids: Array = []
	for id in city.buildings:
		if city.is_house(city.buildings[id]):
			ids.append(id)
	city.compute(false, ids)
	for id in ids:
		var home: Dictionary = city.buildings[id]
		homes.append([home["happy"], home.get("happy_target", 0), home.get("happy_parts", []).duplicate(true)])
	var unlocks: Array = []
	var prices: Array = []
	var wardrobe: Array = []
	for type: String in Defs.B:
		unlocks.append(city.unlocked(type))
		prices.append(city.build_price(type))
	for kind: String in Hero.ITEMS:
		for item: Dictionary in Hero.ITEMS[kind]:
			wardrobe.append(Hero.open(city, item.get("need", {})))
	return {"homes": homes, "unlocks": unlocks, "prices": prices, "wardrobe": wardrobe, "happy": city.stats["happy"], "collections": Collections.sections(city), "wins": Chronicle.value(city, "wins")}


func _strong_legion() -> void:
	var legion: Legion = city.legion
	legion.wins = 100
	legion.pvp_wins = 50
	legion.progress = 300
	legion.rating = 100000
	legion.pvp_rating = 100000
	legion.glory = 100000.0
	legion.triumph_left = int(Legion.TRIUMPH["hours"])
	legion.flags["arena"] = 5
	legion.built.clear()
	for wonder: Dictionary in Legion.WONDERS:
		legion.built[String(wonder["id"])] = true
	legion.trophies["forest"] = true
	for unit: String in Legion.UNIT_IDS:
		legion.levels[unit] = Legion.MAX_LEVEL
	for support: String in Legion.SUPPORT:
		legion.blevels[support] = 10
	for stage in Legion.stages():
		legion.stars[Legion.stage_key(0, 0, stage)] = Legion.STAR_ALL


func _independence() -> void:
	var legion: Legion = city.legion
	var research: Dictionary = city.research.duplicate(true)
	var old_level := city.level
	for modern: bool in [false, true]:
		city.legion_v = 3 if modern else 0
		for studied: bool in [false, true]:
			city.research = research.duplicate(true)
			if studied:
				for item: Dictionary in Defs.RESEARCH:
					city.research[String(item["id"])] = true
			for rank in Defs.LEVELS.size():
				city.level = rank
				legion.from_dict({})
				var empty := _city_signature()
				_strong_legion()
				var strong := _city_signature()
				check(empty == strong, "same city with empty/strong Legion: V3=%s research=%s rank=%d" % [modern, studied, rank])
	city.legion_v = 3
	city.level = old_level
	city.research = research
	legion.from_dict({})
	city.compute()


func _prices() -> void:
	check(not city.research_visible("legion") and not city.research_visible("archery"), "military research is absent from modern city progression")
	var prices := {"venus": 10250, "pharos": 17000, "circus_fl": 43000, "arch": 7250, "colosseum": 32500, "pantheon": 64000}
	for type: String in prices:
		check(not Defs.B[type].has("glory") and city.build_price(type) == float(prices[type]), "denarii price " + type)
	for type: String in ["arch", "colosseum", "pantheon", "venus", "pharos", "circus_fl", "legionpost", "lararium", "trophy_cart"]:
		var unlock := String(Defs.B[type]["unlock"])
		check(not Defs.research(unlock).is_empty() and Defs.story_of(Defs.research(unlock)) == "", "city research reaches " + type)
		city.research[unlock] = true
		check(city.unlocked(type), "reachable without Legion " + type)
	city.legion.glory = 0.0
	city.money = city.build_price("legionpost")
	var position := Vector2(206, 196)
	var quote := city.check_place("legionpost", position, 0.0)
	check(not String(quote["err"]).contains("Славы"), "placement never asks for glory")
	# Позицию для оплаты выбираем по настоящей проверке земли.
	var placed := false
	for x in range(198, 244, 4):
		position = Vector2(x, 196)
		quote = city.check_place("legionpost", position, 0.0)
		if String(quote["err"]) != "":
			continue
		var building := city.place("legionpost", position, 0.0)
		placed = not building.is_empty()
		break
	check(placed and is_zero_approx(city.money) and is_zero_approx(city.legion.glory), "city placement spends only denarii")
	var optional_road := City.road_optional
	City.road_optional = true
	city.money = city.build_price("arch")
	placed = false
	for x in range(202, 242, 4):
		position = Vector2(x, 200)
		quote = city.check_place("arch", position, 0.0)
		if String(quote["err"]) != "":
			continue
		placed = not city.place("arch", position, 0.0).is_empty()
		break
	City.road_optional = optional_road
	check(placed and is_zero_approx(city.money) and is_zero_approx(city.legion.glory), "former glory monument spends denarii with zero glory")
	city.money = 1000000.0


func _requires_legion(value: Variant) -> bool:
	if value is Array:
		var array: Array = value
		if not array.is_empty() and typeof(array[0]) == TYPE_STRING and String(array[0]) in ["legion_win", "soldiers"]:
			return true
		if array.size() >= 2 and typeof(array[0]) == TYPE_STRING and typeof(array[1]) == TYPE_STRING and String(array[0]) == "pay" and String(array[1]) == "glory":
			return true
		if array.size() >= 2 and typeof(array[0]) == TYPE_STRING and String(array[0]) == "count" and typeof(array[1]) == TYPE_STRING:
			var type := String(array[1])
			if Defs.B.has(type) and not city.city_buildable(type):
				return true
		for child in array:
			if _requires_legion(child):
				return true
	elif value is Dictionary:
		var data: Dictionary = value
		if bool(data.get("camp", false)) or data.has("battle") or String(data.get("kind", "")) == "legion":
			return true
		for need in data.get("needs", []):
			if String(need) in ["legion", "archery", "s_bandits", "s_letter"]:
				return true
		for key in data:
			if _requires_legion(data[key]):
				return true
	return false


func _stories() -> void:
	for id: String in ["bandits", "letter"]:
		var story := StoryDefs.story(id)
		check(not story.is_empty() and bool(story.get("disabled", false)), "disabled data retained " + id)
		check(game.stories.can_offer(story).is_empty(), "never offered " + id)
	for story: Dictionary in StoryDefs.all():
		if StoryDefs.city_enabled(story):
			check(not _requires_legion(story), "city-only goals " + String(story["id"]))
	var saved := City.stories_new()
	saved["active"] = {"id": "bandits", "step": 3, "flags": {"won": 0}, "fam": "Юлии"}
	saved["offer"] = {"id": "letter", "home": 1}
	saved["later"] = {"bandits": 99999}
	var loaded := City.stories_load(JSON.parse_string(JSON.stringify(saved)))
	check(loaded["active"].is_empty() and loaded["offer"].is_empty() and loaded["later"].is_empty(), "old military stories release chain and timers")
	check(int(loaded["suspended"]["bandits"]["active"]["step"]) == 3 and loaded["suspended"].has("letter"), "old progress retained without reward")
	check(City.stories_load(JSON.parse_string(JSON.stringify(loaded))) == loaded, "suspension survives second load")
	city.stories = loaded
	city.stories["h"] = 100000
	city.stories["last_h"] = 0
	city.stories["done"]["cat"] = {"h": 1}
	check(game.stories.time_ok() and game.stories.gap_now() == StoryDefs.GAP_H, "normal city story cadence after migration")
	city.research["deco_trees"] = true
	check(not game.stories.can_offer(StoryDefs.story("square")).is_empty(), "next city story available after disabled stories")
	check(game.hud._do_target({"kind": "legion"}) == null, "city guide has no Legion step")


func _gate() -> void:
	var legion: Legion = city.legion
	legion.flags["camp_open"] = true
	legion.army_tick()
	legion.fort["newcomers"] = []
	legion.fort["arrival"] = 0.0
	city.stats["happy"] = 54
	legion.fort_arrival_hour(100.0)
	check(legion.fort_newcomers().is_empty(), "unhappy city sends no newcomers")
	city.stats["happy"] = 55
	legion.fort_arrival_hour(100.0)
	check(legion.fort_newcomers().size() == 3, "happy city sends at most three newcomers")
	legion.fort_arrival_hour(1000.0)
	check(legion.fort_newcomers().size() == 3, "gate queue stays capped at three")
	var population := int(city.stats["pop"])
	var families: Array = []
	for building: Dictionary in city.buildings.values():
		families.append(building.get("families", []).duplicate(true))
	var first := int(legion.fort_newcomers()[0]["id"])
	check(not legion.fort_accept(first).is_empty(), "newcomer can join fort")
	city.compute()
	var after: Array = []
	for building: Dictionary in city.buildings.values():
		after.append(building.get("families", []).duplicate(true))
	check(int(city.stats["pop"]) == population and families == after, "newcomer does not take a city resident")
	city.stats["happy"] = 54
	legion.fort_arrival_hour(100.0)
	check(legion.fort_newcomers().size() == 2, "no refill while city unhappy")
	city.stats["happy"] = 80
	legion.fort_arrival_hour(100.0)
	check(legion.fort_newcomers().size() == 3, "happy city refills gate")


func _fort_payment() -> void:
	var legion: Legion = city.legion
	city.level = 5
	Fixture.set_level(legion, "hq", 5)
	Fixture.set_level(legion, "kitchen", 1)
	legion.mats = {"wood": 10000.0, "iron": 10000.0, "leather": 10000.0}
	legion.glory = 10000.0
	var kitchen := int(legion.fort_slot_plot("kitchen")["id"])
	var price := float(Legion.fort_cost("kitchen", 2)["money"])
	city.magis_treasury = price / 2.0
	city.money = 1000000.0
	var money := city.money
	check(legion.fort_upgrade(kitchen), "fort upgrade starts")
	check(is_zero_approx(city.magis_treasury) and is_equal_approx(city.money, money - price / 2.0), "fort spends treasury first then city money")


func _rewards() -> void:
	var money := city.money
	var rp := city.rp
	var treasury := city.magis_treasury
	city.legion._give({"money": 125, "rp": 20, "glory": 3})
	check(city.money == money and city.rp == rp and city.magis_treasury == treasury + 125, "military rewards stay out of city economy")
	check(float(city.legion.flags.get("research_loot", 0)) >= 20.0, "former research loot retained in Legion save")
	var signature := _city_signature()
	city.legion.pvp_rating = 100000
	city.legion.glory = 100000.0
	check(city.legion.build_wonder("circus") and city.legion.triumph(), "Legion wonders and triumph still work")
	check(_city_signature() == signature, "wonder and triumph leave city unchanged")


func _save_compatibility() -> void:
	city.research["arch"] = true
	var old_arch := city.place("arch", Vector2(238, 234), 0.0, 0, 0, true)
	var arch_id := int(old_arch["id"])
	var old_tier := int(old_arch["tier"])
	var snapshot: Dictionary = city.save_data()
	(snapshot["legion"] as Dictionary).erase("city_decoupled")
	var before := city.buildings.size()
	var money := city.money
	var glory := city.legion.glory
	city.load_data(JSON.parse_string(JSON.stringify(snapshot)))
	check(city.buildings.size() == before and city.money == money and city.legion.glory == glory, "save keeps buildings and never refunds old glory")
	check(city.buildings.has(arch_id) and int(city.buildings[arch_id]["tier"]) == old_tier and city.legion.built.has("arch"), "legacy monument stays and military bonus migrates once")
	var tier := int(city.buildings[arch_id]["tier"])
	city.legion.sync_tiers(true)
	check(int(city.buildings[arch_id]["tier"]) == tier, "military levels never restyle city buildings")
	check(city.stories["suspended"].has("bandits"), "disabled story progress remains in city save")
