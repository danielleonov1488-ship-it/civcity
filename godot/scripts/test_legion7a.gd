extends Node3D
## Экономика форта и кадры для проверки владельцем. Godot запускает только владелец.

const Fixture = preload("res://scripts/test_fort_fixture.gd")
var out := "D:/CivCity/.work/stage6/legion7a/shots/"
var fails := 0
var game: Game
var camp: CampUI


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4).trim_suffix("/") + "/"
	Game.boot = {"new": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	game.can_save = false
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, message: String) -> bool:
	if not ok:
		fails += 1
		push_error("LEGION7A FAIL " + message)
	return ok


func shot(file: String) -> void:
	await frames(8)
	await RenderingServer.frame_post_draw
	if check(get_viewport().get_texture().get_image().save_png(out + file) == OK, "save " + file):
		print("LEGION7A SHOT ", out + file)


func town() -> City:
	var c := City.new(Land.new())
	c.cozy_v = 1
	c.legion_v = 3
	c.level = 5
	c.money = 10000.0
	c.stats["pop"] = 64
	c.name = "Форум Аврелия"
	c.legion.flags["camp_open"] = true
	c.legion.army_tick()
	return c


func _economy() -> void:
	var c := town()
	var lg := c.legion
	var city_money := c.money
	check(lg.city_money() == 500.0 and lg.chest_queue == ["wooden"] and lg.items.is_empty(), "new Legion: 500 denarii, one chest, no gear")
	var dweller := Fixture.recruit(lg)
	if not check(not dweller.is_empty(), "accept dweller"):
		return
	check(lg.worn(dweller).is_empty(), "recruit is gearless")
	c.hero = Hero.make("Гай Аврелий", 0, Hero.PRESETS[0]["look"], true, 777)
	lg.army_tick()
	check(lg.items.is_empty() and lg.soldiers.all(func(s: Dictionary): return lg.worn(s).is_empty()), "hero and all dwellers are gearless")
	var treasury := lg.fort_slot_plot("treasury")
	check(not treasury.is_empty() and Legion.fort_production("treasury", 1)["resource"] == "money", "early treasury produces denarii")
	if treasury.is_empty():
		return
	var tid := int(treasury["id"])
	check(lg.fort_assign(tid, int(dweller["id"])), "treasury worker")
	Legion.clock += 3600.0
	lg.fort_finish()
	check(is_equal_approx(float(treasury["pend"]), 240.0) and lg.city_money() == 500.0, "treasury holds income until collected")
	check(lg.fort_collect(tid) == 240 and lg.city_money() == 740.0 and c.money == city_money, "collect pays Legion only")
	lg.fort["money"] = lg.money_cap()
	var pending := float(treasury["pend"])
	Legion.clock += 3600.0
	lg.fort_finish()
	check(float(treasury["pend"]) == pending and lg.fort_collect(tid) == 0, "full treasury stops production and collection")
	Legion.clock += 3600.0
	lg._pay({"money": 1})
	lg.fort_finish()
	check(float(treasury["pend"]) == pending, "spending after full storage does not bank idle income")
	lg.fort["money"] = 0.0
	check(lg.fort_can_build("kitchen", lg.fort_empty_plot()) != "", "city wealth cannot buy fort room")
	lg.fort["money"] = 100000.0
	var before := lg.city_money()
	var kitchen := lg.fort_empty_plot()
	var cost := Legion.fort_cost("kitchen", 1)
	check(lg.fort_build("kitchen", kitchen) and lg.city_money() == before - float(cost["money"]), "room paid by Legion")
	lg.ingots = 10000
	check(lg.fort_instant(kitchen) and int(lg.fort_plot(kitchen)["lv"]) == 1, "paid construction instant")
	Fixture.set_level(lg, "hq", 3)
	lg.mats = {"wood": 10000.0, "iron": 10000.0, "leather": 10000.0}
	lg.glory = 10000.0
	before = lg.city_money()
	check(lg.fort_instant(kitchen) and lg.city_money() == before - float(Legion.fort_cost("kitchen", 2)["money"]), "fresh instant pays Legion upgrade cost")
	before = lg.city_money()
	check(lg.fort_expand() and lg.city_money() == before - float(Legion.fort_exp_info(1)["cost"]["money"]), "expansion pays Legion")
	lg.fort["up"]["end"] = Legion.now()
	lg.fort_finish()
	check(not lg.has_method("speed_up"), "Legion has no paid money speed-up")
	before = lg.city_money()
	check(lg.train_hero() and lg.city_money() < before, "hero training pays Legion")
	before = lg.city_money()
	check(lg.train(int(dweller["id"])) and lg.city_money() < before, "dweller training pays Legion")
	check(c.money == city_money, "all fort actions preserve city money")


func _orders() -> void:
	var c := town()
	var lg := c.legion
	var info := lg.city_order_info()
	check(info["percent"] == 5 and info["amount"] == 500, "HQ1 order is five percent of current city balance")
	check(lg.order_city_money() == 500 and c.money == 9500.0 and lg.city_money() == 1000.0, "order transfers exact amount")
	check(c.events.filter(func(e: Dictionary): return String(e.get("text", "")).contains("Обоз")).size() == 1, "one city bell line")
	var money := c.money
	check(lg.order_city_money() == 0 and c.money == money, "immediate repeat rejected")
	lg.time_k = 1000.0
	Legion.clock += 17999.0
	check(lg.order_city_money() == 0 and is_equal_approx(float(lg.city_order_info()["left"]), 1.0), "cooldown uses five real hours despite timer speed")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	var restored := City.new(Land.new())
	restored.load_data(saved)
	check(restored.legion.order_city_money() == 0 and restored.legion.city_money() == lg.city_money(), "save/load retains money and cooldown")
	Legion.clock += 1.0
	Fixture.set_level(lg, "hq", 6)
	check(lg.city_order_info()["percent"] == 10, "HQ6 order is ten percent")
	Fixture.set_level(lg, "hq", 20)
	check(lg.city_order_info()["percent"] == 15, "order percent capped at fifteen")
	lg.fort["money"] = lg.money_cap() - 7.0
	check(lg.order_city_money() == 7 and lg.city_money() == lg.money_cap() and c.money == money - 7.0, "order capped by free storage")
	Legion.clock += Legion.CITY_ORDER_SECONDS
	check(lg.order_city_money() == 0 and float(lg.city_order_info()["left"]) == 0.0, "full storage does not spend cooldown")
	lg.fort["money"] = 0.0
	c.money = -100.0
	check(lg.order_city_money() == 0 and c.money == -100.0, "empty city cannot send or create money")
	lg.time_k = 1.0
	lg.receive_money(lg.money_cap() + 100.0)
	check(lg.city_money() == lg.money_cap(), "other income respects Legion cap")


func _migration() -> void:
	var c := town()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	saved["legion"]["fort"].erase("money")
	saved["magis_v"] = 1
	saved["magis"]["treasury"] = 1234.5
	var restored := City.new(Land.new())
	restored.load_data(saved)
	check(restored.legion.city_money() == 1234.5 and restored.magis_treasury == 0.0 and restored.money == c.money, "old military treasury migrates without touching city")
	var again: Dictionary = JSON.parse_string(JSON.stringify(restored.save_data()))
	restored.load_data(again)
	check(restored.legion.city_money() == 1234.5 and restored.legion.chest_queue == ["wooden"], "reload never duplicates money or starter chest")
	saved["magis"]["treasury"] = 0.0
	restored.load_data(saved)
	check(restored.legion.city_money() == 500.0, "old save without treasury receives 500")
	saved["legion"]["fort"]["money"] = 70000.0
	restored.load_data(saved)
	check(restored.legion.city_money() == 70000.0, "migration preserves existing money above storage cap")


func _gear_and_battles() -> void:
	var c := town()
	var lg := c.legion
	var fighter := Fixture.recruit(lg)
	if not check(not fighter.is_empty(), "battle fighter"):
		return
	lg.set_place(0, int(fighter["id"]))
	var stage := lg.stage_info(0, 0, 0)
	lg.rations = lg.ration_cost(stage) - 0.1
	check(lg.prepare_battle(stage).is_empty(), "battle rejects insufficient kitchen rations")
	lg.rations = 10.0
	var cost := lg.ration_cost(stage)
	var setup := lg.prepare_battle(stage)
	if not check(not setup.is_empty(), "battle starts"):
		return
	check(lg.rations == 10.0 - cost and setup.get("rations_paid", false), "battle charges rations at start")
	var item_count := lg.items.size()
	var result := lg.apply_result(setup, {"win": true, "alive": 1, "total": 1, "fallen": [], "time": 30.0, "hp_left": 1.0, "inputs": [], "perks_used": {}, "summons": 0})
	check(lg.rations == 10.0 - cost and lg.items.size() == item_count and not result.has("item") and result.has("camp_chest") and lg.chest_queue.size() == 2, "victory gives chest and never charges rations twice")
	check(lg._drop(stage, true).is_empty(), "direct battle item drop disabled in V3")
	check(lg.ration_cost({"boss": true}) == 4.0 and cost == 2.0, "normal and boss ration cost")
	var reward := lg.open_chest("wooden")
	check(reward.has("item") and lg.items.size() == item_count + 1, "gear arrives when chest is opened")
	check(c.money == 10000.0, "chest and battle leave city money intact")
	for kind: String in Legion.CHEST_RARITY_ODDS:
		var sum := 0
		for chance: int in Legion.CHEST_RARITY_ODDS[kind]:
			sum += chance
		check(sum == 100, "rarity odds total 100: " + kind)


func _knowledge() -> void:
	var c := town()
	var lg := c.legion
	Fixture.set_level(lg, "hq", 3)
	Fixture.set_level(lg, "forge", 2)
	Fixture.set_level(lg, "arsenal", 2)
	lg.mats = {"iron": 1000.0, "wood": 1000.0, "leather": 1000.0}
	lg.fort["money"] = 3000.0
	var smith := lg._add_soldier({"name": "Кузнец", "stars": 1})
	var forge := int(lg.fort_slot_plot("forge")["id"])
	lg.fort_assign(forge, int(smith["id"]))
	var money := lg.city_money()
	check(lg.can_craft(forge, "sword", 1) == Legion.SMITH_LOCK and not lg.craft_start(forge, "sword", 1) and lg.city_money() == money, "forge locked before knowledge, no payment")
	check(lg.learn_smith() and lg.city_money() == money - 800.0 and lg.mat("iron") == 980 and lg.mat("wood") == 980, "knowledge paid with Legion money and materials")
	check(not lg.learn_smith() and lg.craft_start(forge, "sword", 1) and c.money == 10000.0, "knowledge bought once; craft opens without city payment")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	var restored := City.new(Land.new())
	restored.load_data(saved)
	check(restored.legion.smith_known(), "knowledge survives save/load")


func _screens() -> void:
	var c: City = game.city
	c.cozy_v = 1
	c.legion_v = 3
	c.name = "Форум Аврелия"
	c.hero = {}
	c.money = 10000.0
	var lg := c.legion
	lg.fort = {}
	lg.camp = {}
	lg.soldiers.clear()
	lg.items.clear()
	lg.flags.clear()
	lg.flags["camp_open"] = true
	lg.flags["camp_told"] = true
	lg.flags["camp3d_guide"] = 4
	lg.army_tick()
	var fighter := Fixture.recruit(lg)
	lg.set_place(0, int(fighter["id"]))
	camp = CampUI.attach(game.hud)
	camp.open()
	camp.set_process(false)
	check(camp.city_name_label.text == c.name and camp.hq_level_label.text == "1", "city name and HQ medallion")
	check((camp.resource_chips["money"] as Label).text == game.hud.fmt(lg.city_money()), "Legion money shows current balance")
	check(camp.order_button.is_visible_in_tree() and camp.order_button.tooltip_text.contains("500"), "round order button and amount tooltip")
	await shot("1_start.png")
	camp.order_button.pressed.emit()
	check(camp.order_button.disabled and float(camp.order_ring.get("value")) < 0.01 and camp.order_button.tooltip_text.contains("5:00:00"), "order UI cooldown ring and time")
	await shot("2_order.png")
	Fixture.set_level(lg, "hq", 2)
	Fixture.set_level(lg, "forge", 2)
	camp.show_building("forge")
	check(camp.card.find_child("FortSmithLock", true, false) != null and camp.main_action.text == I18n.t("Кузнечное знание"), "forge card explains knowledge lock")
	await shot("3_forge_locked.png")
	camp.main_action.pressed.emit()
	check(camp.modal_panel.name == "FortKnowledgeTree", "knowledge action opens research")
	await shot("4_knowledge.png")
	camp._close_modal()
	lg.rations = 0.0
	camp._campaign()
	camp.lu.open_fort_stage(0, 0, 0)
	await frames(8)
	var fight := camp.lu._fight_btn
	check(fight != null and fight.disabled and fight.icon != null and float(fight.get_meta("ration_cost", 0)) == 2.0, "battle button shows ration icon, cost and shortage")
	await shot("5_battle_rations.png")
	camp.lu.close()

	camp.close()


func _run() -> void:
	var waited := 0
	while not game.ready_done:
		await frames(5)
		waited += 5
		if not check(waited < 18000, "ready timeout"):
			_finish()
			return
	game.can_save = false
	game.settings["autosave"] = false
	game.speed = 0.0
	game.set_process(false)
	game.tutorial.set_process(false)
	game.tutorial.card.hide()
	game.stories.set_process(false)
	game.hud.advisor_panel.hide()
	if not check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory"):
		_finish()
		return
	var old_clock := Legion.clock
	Legion.clock = 1000000.0
	_economy()
	_orders()
	_migration()
	_gear_and_battles()
	_knowledge()
	await _screens()
	Legion.clock = old_clock
	_finish()


func _finish() -> void:
	print("LEGION7A DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
