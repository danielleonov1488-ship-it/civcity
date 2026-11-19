extends Node
## Модель без рендера и пользовательских сохранений. Запускает владелец тестов.

const FIXTURE = preload("res://scripts/test_fort_fixture.gd")
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("FORT1 PASS " if ok else "FORT1 FAIL ") + what)
	if not ok:
		fails += 1


func town(version := 3) -> City:
	var c := City.new(Land.new())
	c.cozy_v = 1
	c.legion_v = version
	c.level = Defs.LEVELS.size() - 1
	c.money = 1e9
	c.legion.army_tick()
	if version >= 3:
		c.legion.fort["money"] = 1e9
	c.legion.glory = 1e8
	c.legion.mats = {"iron": 1e6, "wood": 1e6, "leather": 1e6}
	return c


func finish_build(l: Legion, id: int) -> void:
	var u: Dictionary = l.fort_plot(id)["up"]
	if u.is_empty():
		check(false, "expected building timer")
		return
	Legion.clock = float(u["end"])
	l.tick()
	if l.fort_room_slots(id) > 0:
		assign_worker(l, id)


func assign_worker(l: Legion, id: int) -> void:
	if l.fort_worker(id).is_empty():
		var person := l._add_soldier({"name": "Работник", "cls": "legionary", "stars": 1})
		check(l.fort_assign(id, int(person["id"])), "assign worker")


func _ready() -> void:
	var saved_clock := Legion.clock
	Legion.clock = 1000000.0
	_plot_order()
	_build_produce()
	_expand_effects()
	_producers()
	_training()
	_migrate_save()
	_defaults_v2()
	Legion.clock = saved_clock
	print("FORT1 DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _plot_order() -> void:
	var c := town()
	var l: Legion = c.legion
	var free_ids: Array[int] = []
	for p: Dictionary in l.fort["plots"]:
		if int(p["id"]) > 0 and p["b"] == "":
			free_ids.append(int(p["id"]))
	free_ids.sort()
	check(free_ids.size() >= 2, "plot order fixture has two free rooms")
	if free_ids.size() < 2:
		return
	(l.fort["plots"] as Array).reverse()
	check(l.fort_empty_plot() == free_ids[0], "first cutaway room ignores save array order")
	check(l.fort_build("kitchen", free_ids[0]), "build first free room in reversed save")
	check(l.fort_empty_plot() == free_ids[1], "next free room skips room under construction")
	check(l.fort_plot(0)["b"] == "hq", "auto-pick preserves HQ")
	for id: int in free_ids:
		l.fort_plot(id)["b"] = "tower"
	check(l.fort_empty_plot() == -1, "full reversed fort has no free room")


func _build_produce() -> void:
	var c := town()
	var l: Legion = c.legion
	check(l.fort["exp"] == 0 and l.fort["plots"].size() == 14 and l.fort_count("hq") == 1
		and l.fort_plot(0)["b"] == "hq" and l.camp_level("hq") == 1, "start: HQ 0 plus thirteen plots")
	check(l.fort_max("kitchen") == 1 and l.fort_empty_plot() > 0, "one kitchen allowed")
	var id := l.fort_empty_plot()
	l.fort["money"] = 0.0
	check(not l.fort_build("kitchen", id) and l.fort_plot(id)["b"] == "", "unaffordable build leaves plot empty")
	l.fort["money"] = 1e9
	var money := l.city_money()
	check(not l.fort_build("unknown", id) and not l.fort_build("kitchen", 0)
		and not l.fort_build("hq", id) and l.city_money() == money, "invalid builds do not spend")
	check(l.fort_build("kitchen", id) and l.city_money() < money, "kitchen starts and charges")
	check(l.fort_plot(id)["lv"] == 0 and l.fort_info(id)["producing"].is_empty()
		and l.fort_count("kitchen") == 1 and l.camp_busy(), "construction has no effect yet")
	var end := float(l.fort_plot(id)["up"]["end"])
	check(is_equal_approx(end - Legion.now(), 300.0), "first room builds in five minutes")
	Legion.clock = end - 1.0
	l.fort_finish()
	check(l.fort_plot(id)["lv"] == 0 and l.fort_collect(id) == 0, "not complete early")
	finish_build(l, id)
	check(l.fort_plot(id)["lv"] == 1 and not l.camp_busy(), "timer completes")
	check(l.fort_can_upgrade(id).contains("Выше Штаба"), "HQ caps building level")
	check(l.fort_can_build("kitchen", l.fort_empty_plot()) != "", "second kitchen blocked at HQ 1")
	l.rations = 0.0
	Legion.clock += 5400.0
	l.fort_finish()
	check(is_equal_approx(float(l.fort_plot(id)["pend"]), 1.5), "one and a half hours produces 1.5")
	check(l.fort_collect(id) == 1 and l.rations_now() == 1
		and is_equal_approx(float(l.fort_plot(id)["pend"]), 0.5), "collect whole units, keep fraction")
	Legion.clock += 100.0 * 3600.0
	l.fort_finish()
	check(l.fort_plot(id)["pend"] == 12.0, "local production cap")
	Legion.clock += 100.0 * 3600.0
	l.fort_finish()
	check(l.fort_plot(id)["pend"] == 12.0, "full producer stops")
	l.rations = l.ration_cap() - 2
	check(l.fort_collect(id) == 2 and l.rations_now() == l.ration_cap()
		and l.fort_plot(id)["pend"] == 10.0, "partial collection respects storage")
	check(l.fort_collect(id) == 0 and l.fort_plot(id)["pend"] == 10.0, "full storage loses nothing")
	Legion.clock += 1800.0
	l.fort_finish()
	check(is_equal_approx(float(l.fort_plot(id)["pend"]), 10.0), "full shared storage stops growth")
	l.rations = 0.0
	Legion.clock += 1800.0
	l.fort_finish()
	check(is_equal_approx(float(l.fort_plot(id)["pend"]), 10.5), "production restarts after spending")
	FIXTURE.set_level(l, "hq", 3)
	var second := l.fort_empty_plot()
	check(l.fort_max("kitchen") == 2 and l.fort_build("kitchen", second), "second kitchen at HQ 3")
	end = float(l.fort_plot(second)["up"]["end"])
	Legion.clock = end + 7200.0
	l.fort_finish()
	check(l.fort_plot(second)["lv"] == 1 and is_zero_approx(float(l.fort_plot(second)["pend"])), "offline build waits for a worker")
	assign_worker(l, second)
	l.fort_plot(id)["pend"] = 0.0
	l.fort_plot(id)["t"] = Legion.now()
	check(l.fort_upgrade(id), "upgrade kitchen")
	end = float(l.fort_plot(id)["up"]["end"])
	check(is_equal_approx(end - Legion.now(), 900.0), "room level two takes fifteen minutes")
	Legion.clock = end + 3600.0
	l.fort_finish()
	check(l.fort_plot(id)["lv"] == 2 and is_equal_approx(float(l.fort_plot(id)["pend"]), 2.0), "upgrading room pauses production")
	var info := l.fort_info(id)
	check(info.has_all(["type", "lv", "next_cost", "next_time", "gives", "gives_next", "producing"])
		and info["gives"] != info["gives_next"], "building information describes next effect")


func _expand_effects() -> void:
	var c := town()
	var l: Legion = c.legion
	check(l.fort_can_expand().contains("Штаб") and not l.fort_expand(), "expansion gated by HQ")
	FIXTURE.set_level(l, "hq", 3)
	var ids: Array = l.fort["plots"].map(func(p: Dictionary): return int(p["id"]))
	var wood := l.mat("wood")
	var money := l.city_money()
	l.mats["wood"] = 0.0
	check(not l.fort_expand() and l.city_money() == money and l.fort["up"].is_empty(), "missing expansion materials do not spend")
	l.mats["wood"] = wood
	check(l.fort_expand() and l.mat("wood") == wood - 20 and l.city_money() == money - 1000, "expansion pays coins and materials")
	check(is_equal_approx(float(l.fort["up"]["total"]), 7200.0), "first expansion takes two hours")
	check(not l.has_method("speed_up"), "expansion has no paid money shortcut")
	check(l.fort["plots"].size() == 14 and l.camp_busy() and not l.fort_build("kitchen", l.fort_empty_plot()), "expansion waits and uses builder")
	Legion.clock = float(l.fort["up"]["end"]) - 1.0
	l.fort_finish()
	check(l.fort["plots"].size() == 14, "no early plots")
	Legion.clock += 1.0
	l.tick()
	check(l.fort["exp"] == 1 and l.fort["plots"].size() == 19 and not l.camp_busy(), "expansion adds a floor of five plots")
	for i in ids.size():
		check(int(l.fort["plots"][i]["id"]) == int(ids[i]), "stable plot order %d" % i)
	var roster := l.roster_cap()
	var id := l.fort_empty_plot()
	check(l.fort_build("barracks", id) and l.roster_cap() == roster, "unfinished barracks gives no places")
	finish_build(l, id)
	check(l.roster_cap() == roster + 5 and l.camp_level("barracks") == 1, "second barracks adds roster places")
	check(l.fort_upgrade(id), "upgrade second barracks")
	finish_build(l, id)
	check(l.camp_level("barracks") == 2 and l.barracks_lvl() == 2 and l.roster_cap() == roster + 6, "slot wrapper returns maximum, roster sums")
	FIXTURE.set_level(l, "store", 2)
	var material_cap := l.mat_cap("iron")
	var ration_cap := l.ration_cap()
	id = l.fort_empty_plot()
	check(l.fort_build("store", id), "second warehouse allowed")
	finish_build(l, id)
	check(l.mat_cap("iron") == material_cap + 80 and l.ration_cap() == ration_cap + 5, "warehouse capacities sum")
	FIXTURE.set_level(l, "forge", 3)
	FIXTURE.set_level(l, "mars", 2)
	check(l.forge_lvl() == 3 and l.perk_max() == 7, "forge and Mars effects use buildings")
	for e in range(6, 10):
		var expansion := Legion.fort_exp_info(e)
		check(expansion["hq"] == 12 + (e - 5) * 3 and expansion["plots"] == 23 + (e - 5) * 6
			and float(expansion["time_h"]) > float(Legion.fort_exp_info(e - 1)["time_h"]), "endless expansion %d" % e)
	FIXTURE.set_level(l, "hq", 20)
	check(l.fort_upgrade(0), "HQ can grow beyond old maximum")
	finish_build(l, 0)
	check(l.camp_level("hq") == 21, "HQ level 21")
	check(Legion.camp_time_h(25) > Legion.camp_time_h(20), "high-level timers grow")
	var expanded: Dictionary = l.fort.duplicate(true)
	expanded["exp"] = 5
	expanded["grid"] = [5, 5]
	l._fort_load(expanded)
	check(l.fort["plots"].size() == 24 and l.fort_expand(), "start first expansion beyond table")
	var expand_end := float(l.fort["up"]["end"])
	Legion.clock = expand_end - 1.0
	l.fort_finish()
	check(int(l.fort["exp"]) == 5 and float(l.fort["up"]["end"]) == expand_end, "expansion waits for its full timer")
	Legion.clock = float(l.fort["up"]["end"])
	l.fort_finish()
	check(l.fort["exp"] == 6 and l.fort["plots"].size() == 29, "endless expansion adds a full floor of five plots")


func _producers() -> void:
	var c := town()
	var l: Legion = c.legion
	FIXTURE.set_level(l, "hq", 3)
	check(l.fort_expand(), "producer fixture expands")
	Legion.clock = float(l.fort["up"]["end"])
	l.fort_finish()
	for type: String in ["smelter", "sawmill", "tannery", "treasury"]:
		var existing := l.fort_slot_plot(type)
		var id := int(existing["id"]) if not existing.is_empty() else l.fort_empty_plot()
		if existing.is_empty():
			check(l.fort_build(type, id), "build " + type)
			finish_build(l, id)
		else:
			assign_worker(l, id)
		var resource := String(Legion.FORT_B[type]["production"]["resource"])
		if resource == "money":
			l.fort["money"] = 0.0
		else:
			l.mats[resource] = 0.0
		Legion.clock += 43200.0 if resource == "ingots" else 3600.0
		var collected := l.fort_collect(id)
		check(collected == (240 if resource == "money" else 4), "production and collection: " + resource)
		l.fort_plot(id)["pend"] = 1.0
		if resource == "money":
			l.fort["money"] = l.resource_cap(resource)
		else:
			l.mats[resource] = l.resource_cap(resource)
		check(l.fort_collect(id) == 0 and l.fort_plot(id)["pend"] == 1.0, "stock cap: " + resource)
	l.pending_resources["wood"] = 9.0
	l.mats["wood"] = 0.0
	check(l.collect_resource("wood") == 9, "city production collection remains separate")


func _training() -> void:
	var c := town()
	var l: Legion = c.legion
	FIXTURE.set_level(l, "hq", 5)
	FIXTURE.set_level(l, "drill", 3)
	var id := l.fort_empty_plot()
	check(l.fort_build("drill", id), "build second drill ground")
	finish_build(l, id)
	check(l.train_places() == 2, "one training place per drill ground")
	for i in 3:
		l._add_soldier({"name": "Test%d" % i, "from": "", "cls": "legionary", "stars": 3})
	var a: Dictionary = l.soldiers[0]
	var b: Dictionary = l.soldiers[1]
	check(l.train(int(a["id"])) and l.train(int(b["id"])) and not l.train(int(l.soldiers[2]["id"])), "two train, third waits")
	check(a["train_plot"] != b["train_plot"] and float(a["train_total"]) < float(b["train_total"]), "distinct grounds and level-based speed")
	var copy := town()
	copy.legion.from_dict(JSON.parse_string(JSON.stringify(l.to_dict())))
	check(copy.legion.soldiers[0]["train_plot"] == a["train_plot"] and copy.legion.fort_train_plot().is_empty(), "training assignments survive JSON")


func _migrate_save() -> void:
	var c := town()
	var l: Legion = c.legion
	var old: Dictionary = JSON.parse_string(JSON.stringify(l.to_dict()))
	old.erase("fort")
	old["camp"] = {"hq": 6, "barracks": 4, "forge": 3, "drill": 2, "store": 2, "mars": 1}
	old["upg"] = {"camp_forge": {"to": 4, "end": Legion.now() + 3600.0, "total": 7200.0}}
	old["rations"] = 500.5
	old["pending_resources"] = {"iron": 999.5}
	old["ingots"] = 500
	l.from_dict(old)
	l.fort["money"] = 1e9
	for type: String in old["camp"]:
		check(l.camp_level(type) == int(old["camp"][type]), "migration preserves " + type)
	check(l.fort_count("kitchen") == 1 and l.fort["plots"].size() == 14 and l.camp_busy(), "migration adds kitchen and keeps timer")
	check(l.rations == 500.5 and l.pending_resources["iron"] == 999.5 and l.ingots == 500
		and l.mats == old["mats"], "migration does not clamp existing resources")
	check(float(l.fort_slot_plot("forge")["up"]["end"]) == float(old["upg"]["camp_forge"]["end"])
		and l.fort_slot_plot("forge")["up"] == l.upg["camp_forge"], "migration preserves full timer and camp alias")
	finish_build(l, int(l.fort_slot_plot("forge")["id"]))
	check(l.camp_level("forge") == 4 and not l.upg.has("camp_forge"), "migrated timer finishes")
	l.fort_slot_plot("kitchen")["pend"] = 2.5
	check(l.fort_expand(), "expansion before save")
	var expansion_grid: Array = l.fort["up"]["grid"].duplicate()
	var expanded_plots := int(expansion_grid[0]) * int(expansion_grid[1]) - 1
	var before_fort: Dictionary = l.fort.duplicate(true)
	var before_pending: Dictionary = l.pending_resources.duplicate(true)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	var copy := City.new(Land.new())
	copy.load_data(saved)
	check(copy.legion.fort == before_fort and copy.legion.camp_level("forge") == 4
		and copy.legion.camp_busy(), "city save/load keeps fort, pending and expansion timer")
	check(copy.legion.pending_resources == before_pending and copy.legion.rations == l.rations
		and copy.legion.mats == l.mats and copy.legion.ingots == l.ingots, "city save/load keeps shared stock and city buffers")
	for p: Dictionary in before_fort["plots"]:
		var restored: Dictionary = copy.legion.fort_plot(int(p["id"]))
		var worker: Dictionary = l.fort_worker(int(p["id"]))
		var restored_worker: Dictionary = copy.legion.fort_worker(int(p["id"]))
		check(int(restored["worker"]) == int(p["worker"])
			and restored_worker.get("id") == worker.get("id") and restored_worker.get("name") == worker.get("name")
			and restored_worker.get("stars") == worker.get("stars"), "city save/load keeps worker %d" % int(p["id"]))
		check(restored["pend"] == p["pend"] and restored["t"] == p["t"] and restored["up"] == p["up"], "city save/load keeps production and timer %d" % int(p["id"]))
	check(copy.legion.fort["up"] == before_fort["up"] and copy.legion.fort["exp"] == before_fort["exp"]
		and copy.legion.fort["next_id"] == before_fort["next_id"], "city save/load keeps expansion state")
	var legacy_worker: Dictionary = copy.legion.fort_worker(int(l.fort_slot_plot("kitchen")["id"]))
	check(typeof(legacy_worker.get("id")) == TYPE_INT and typeof(legacy_worker.get("stars")) == TYPE_INT, "legacy worker numbers restored as integers")
	Legion.clock = float(copy.legion.fort["up"]["end"]) + 3600.0
	copy.legion.tick()
	check(copy.legion.fort["plots"].size() == expanded_plots and copy.legion.fort["grid"] == expansion_grid
		and copy.legion.fort_slot_plot("kitchen")["pend"] == 2.5, "offline expansion, full storage pauses kitchen")
	var plot := copy.legion.fort_empty_plot()
	check(copy.legion.fort_build("kitchen", plot), "build before save")
	var again := town()
	again.legion.from_dict(JSON.parse_string(JSON.stringify(copy.legion.to_dict())))
	check(again.legion.fort_plot(plot)["lv"] == 0 and not again.legion.fort_plot(plot)["up"].is_empty(), "building timer survives save")
	finish_build(again.legion, plot)
	check(again.legion.fort_plot(plot)["lv"] == 1, "restored building completes")
	var starter := town()
	var zero: Dictionary = JSON.parse_string(JSON.stringify(starter.legion.to_dict()))
	zero.erase("fort")
	zero["camp"]["hq"] = 2
	zero["upg"] = {"camp_forge": {"to": 1, "end": Legion.now() + 300.0, "total": 300.0}}
	starter.legion.from_dict(zero)
	check(starter.legion.fort_count("forge") == 1 and starter.legion.camp_level("forge") == 0, "migration keeps unfinished first building")
	finish_build(starter.legion, int(starter.legion.fort_slot_plot("forge")["id"]))
	check(starter.legion.camp_level("forge") == 1, "migrated first building completes")


func _defaults_v2() -> void:
	var c := town()
	var l: Legion = c.legion
	l.from_dict({})
	check(l.fort_count("hq") == 1 and l.camp_level("hq") == 1 and l.fort["plots"].size() == 14, "empty save has safe defaults")
	l.from_dict({"fort": {"plots": [null, {}, {"id": 0, "lv": -2}, {"id": 0, "b": "invalid"}], "exp": -1}})
	var seen := {}
	var unique := true
	for p: Dictionary in l.fort["plots"]:
		unique = unique and not seen.has(int(p["id"]))
		seen[int(p["id"])] = true
	check(unique and l.fort_count("hq") == 1 and l.camp_level("hq") == 1, "malformed plots repaired")
	var old := town(0)
	check(old.legion.fort.is_empty() and not old.legion.to_dict().has("fort")
		and not old.legion.fort_expand() and not old.legion.fort_build("kitchen", 1)
		and old.legion.fort_collect(1) == 0, "V2 save and actions untouched")
