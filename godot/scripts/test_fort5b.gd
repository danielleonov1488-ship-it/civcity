extends Node3D
## Шесть экранов стиля A и проверки действий. Запускает владелец тестов.

const Fixture = preload("res://scripts/test_fort_fixture.gd")
const Kit = preload("res://scripts/ui_kit_a.gd")
var out := "D:/CivCity/.work/stage5/fort5b/shots/"
var fails := 0
var game: Game
var camp: CampUI
var lg: Legion
var saved_clock := -1.0


func check(ok: bool, reason: String) -> bool:
	if not ok:
		fails += 1
		print("FORT5B FAIL " + reason)
	return ok


func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func shot(file: String) -> void:
	await frames(16)
	await RenderingServer.frame_post_draw
	if check(get_viewport().get_texture().get_image().save_png(out + file) == OK, "save " + file):
		print("FORT5B SHOT " + out + file)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4).trim_suffix("/") + "/"
	saved_clock = Legion.clock
	Legion.clock = 2000000.0
	Game.boot = {"new": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	game.can_save = false
	add_child(game)
	_run()


func _finish() -> void:
	if is_instance_valid(camp):
		camp.close()
	Legion.clock = saved_clock
	print("FORT5B DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _run() -> void:
	var waited := 0
	while not game.ready_done:
		await frames(5)
		waited += 5
		if not check(waited < 18000, "ready_done timeout"):
			_finish()
			return
	game.can_save = false
	game.settings["autosave"] = false
	game.set_process(false)
	if not check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory"):
		_finish()
		return
	var city: City = game.city
	city.cozy_v = 1
	city.legion_v = 3
	city.money = 125400
	for i in 16:
		var house := city.place("house_pleb", Land.START + Vector2((i % 8) * 8, (i / 8) * 8), 0.0, 0, 0, true)
		if not check(not house.is_empty(), "house fixture"):
			_finish()
			return
		house["families"] = [{"name": "Юлии%d" % i, "n": 4, "cls": "plebs"}]
		house["pop"] = 4
	city.compute()
	lg = city.legion
	lg.fort = {}
	lg.camp = {}
	lg.soldiers.clear()
	lg.items.clear()
	lg.squad3 = [0, 0, 0, 0, 0]
	lg.flags["camp_open"] = true
	lg.flags["camp_told"] = true
	lg.flags["camp3d_guide"] = 4
	lg.army_tick()
	for entry: Array in [["hq", 3], ["barracks", 1], ["kitchen", 1], ["forge", 4], ["store", 1]]:
		Fixture.set_level(lg, String(entry[0]), int(entry[1]))
	lg.mats = {"iron": 10000.0, "wood": 10000.0, "leather": 10000.0}
	lg.glory = 3850
	lg.rations = 28
	lg.ingots = 120
	lg.queue_chest("wooden")
	lg.queue_chest("bronze")
	var kitchen := int(lg.fort_slot_plot("kitchen")["id"])
	var forge := int(lg.fort_slot_plot("forge")["id"])
	var cook := Fixture.recruit(lg, false)
	var smith := Fixture.recruit(lg, false)
	var person := Fixture.recruit(lg)
	if not check(not cook.is_empty() and not smith.is_empty() and not person.is_empty(), "three residents"):
		_finish()
		return
	check(lg.fort_assign(kitchen, int(cook["id"])) and lg.fort_assign(forge, int(smith["id"])), "assign production workers")
	var sid := int(person["id"])
	person["stars"] = 3
	for kind: String in ["sword", "helmet", "armor", "offhand"]:
		var it := lg.add_item(Gear.craft_item(kind, 2, 2))
		check(lg.equip(sid, int(it["id"])), "equip fixture " + kind)
	for kind: String in ["sword", "bow", "staff", "spear", "helmet", "armor", "offhand"]:
		lg.add_item(Gear.craft_item(kind, 3, 3))
	lg.fort_plot(kitchen)["pend"] = 3.0
	Fixture.gate(lg, 3)
	camp = CampUI.of(game.hud)
	if not check(camp != null, "CampUI attached"):
		_finish()
		return
	camp.open()
	await frames(12)
	check(camp.diorama is FortCutaway, "painted fort stays active")
	check(camp.chips.get_child_count() == 4 and camp.resource_chips.keys() == ["money", "rations", "glory", "ingots"], "four top resources")
	check(camp.population_button.icon == Kit.texture("family") and camp.population_button.text.contains(str(lg.fort_population())), "population pill")
	check(camp.left_column.get_child_count() == 5 and camp.campaign_button.text == "" and camp.build_button.text == "", "icon navigation")
	check(camp.ration_label.text == "%d / %d" % [lg.rations_now(), lg.ration_cap()], "rations are in top HUD")
	await shot("1_fort_hud.png")
	camp.show_plot(forge)
	check(camp.card.has_meta("ui_kit_a") and camp.card.find_child("FortRoomPicture", true, false) != null, "room frame and cutaway picture")
	check(camp.upgrade_button.disabled and camp.requirement_banner.visible and camp.instant_button.disabled, "HQ requirement gates both upgrade actions")
	check(camp.main_action.icon == Kit.texture("craft"), "forge craft action")
	var room_id := camp.card.get_instance_id()
	camp._refresh()
	check(camp.card.get_instance_id() == room_id, "room survives value refresh")
	await shot("2_room_card.png")
	camp.show_build_menu()
	check(camp.build_cards.size() == Legion.FORT_B.size() - 1, "all room cards")
	check((camp.build_cards["forge"]["picture"] as Control).get_child_count() > 0, "build pictures")
	await shot("3_build_menu.png")
	camp.show_dweller(sid)
	var slots := camp.modal_panel.find_child("FortGearSlots", true, false)
	check(slots != null and slots.get_child_count() == 4 and slots.find_children("TierBadge", "Label", true, false).size() == 4, "four equipped slots and tier badges")
	check(camp.modal_panel.find_child("FortInventoryGrid", true, false) != null, "inventory grid")
	await shot("4_dweller_card.png")
	var better: Dictionary = lg.items.filter(func(it: Dictionary): return int(it.get("on", 0)) == 0 and it["slot"] == "weapon" and it["cls"] == "legionary")[0]
	var before := Legion.power(lg.soldier_stats(person, "legionary"))
	camp._equip_dweller(sid, int(better["id"]))
	check(int(better["on"]) == sid and Legion.power(lg.soldier_stats(person, "legionary")) != before, "equipment still changes stats")   # набор II распадается — сила может и упасть
	camp._close_modal()
	check(lg.craft_start(forge, "sword", 1), "craft fixture starts")
	camp.lu.open_craft(forge)
	await frames(4)
	var craft := camp.lu.overlay.find_child("CraftPanel", true, false)
	if check(craft != null, "craft panel"):
		var craft_id := craft.get_instance_id()
		camp.lu._craft_win()
		camp.lu._tick_live()
		check(camp.lu.overlay.find_child("CraftPanel", true, false).get_instance_id() == craft_id, "craft survives timer refresh")
		check(craft.find_child("CraftKinds", true, false).get_child_count() == 4 and craft.find_child("CraftRarityOdds", true, false).get_child_count() == 5, "recipe icons and five rarity odds")
	await shot("5_craft_panel.png")
	camp.lu.close()
	camp._campaign()
	await frames(6)
	var back := camp.lu.find_child("CampaignBack", true, false) as Button
	check(back != null and back.icon == Kit.texture("back") and camp.lu.win.has_meta("ui_kit_a"), "campaign frame and back")
	await shot("6_campaign.png")
	camp.lu.close()
	camp.show_newcomer(int(lg.fort_newcomers()[0]["id"]))
	check(camp.modal_panel.name == "FortNewcomerCard" and camp.modal_panel.has_meta("ui_kit_a"), "newcomer kit")
	camp.show_expansion("floor")
	check(camp.modal_panel.name == "FortExpansionCard" and camp.modal_panel.has_meta("ui_kit_a"), "expansion kit")
	camp._close_modal()
	_instant_checks(kitchen, forge)
	_finish()


func _instant_checks(kitchen: int, forge: int) -> void:
	var money := lg.city_money()
	var ingots := lg.ingots
	check(not lg.fort_instant(forge) and lg.ingots == ingots and lg.city_money() == money, "instant respects HQ gate without debit")
	lg.ingots = 0
	check(not lg.fort_instant(kitchen) and lg.city_money() == money, "instant needs ingots before normal payment")
	lg.ingots = 10000
	var quote := lg.fort_instant_info(kitchen)
	var level := int(lg.fort_plot(kitchen)["lv"])
	check(lg.fort_instant(kitchen), "instant upgrade succeeds")
	check(int(lg.fort_plot(kitchen)["lv"]) == level + 1 and lg.ingots == 10000 - int(quote["price"]) and lg.city_money() < money, "instant pays both costs and completes once")
	check(lg.fort_upgrade(kitchen), "timed upgrade starts")
	var timed_quote := lg.fort_instant_info(kitchen)
	var paid := lg.city_money()
	var stock := lg.ingots
	check(lg.fort_instant(kitchen) and lg.city_money() == paid and lg.ingots == stock - int(timed_quote["price"]), "active timer instant does not charge upgrade twice")
	var after := lg.ingots
	check(not lg.fort_instant(kitchen, timed_quote) and lg.ingots == after, "stale quote cannot buy next level")
