extends Node3D

const Fixture = preload("res://scripts/test_fort_fixture.gd")
const Know = preload("res://scripts/legion_knowledge.gd")
var out := "D:/CivCity/.work/stage7/legion10b/shots/"
var game: Game
var camp: CampUI
var lg: Legion
var fails := 0
var forge := -1
var kitchen := -1
var sid := 0


func _ready() -> void:
	var clock_before := Legion.clock
	var lang_before := I18n.lang
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=").trim_suffix("/") + "/"
	I18n.set_lang("ru")
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	game.can_save = false
	add_child(game)
	await _run()
	if is_instance_valid(camp):
		camp.close()
	Legion.clock = clock_before
	I18n.set_lang(lang_before)
	print("LEGION10 DONE fails=", fails)
	get_tree().quit(0 if fails == 0 else 1)


func check(ok: bool, reason: String) -> bool:
	if not ok:
		fails += 1
		print("LEGION10 FAIL ", reason)
	return ok


func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func shot(file: String) -> void:
	await frames(7)
	await RenderingServer.frame_post_draw
	if check(get_viewport().get_texture().get_image().save_png(out + file) == OK, "save " + file):
		print("LEGION10 SHOT ", file)


func _run() -> void:
	var waited := 0
	while not game.ready_done:
		await frames(5)
		waited += 5
		if not check(waited < 18000, "ready_done timeout"):
			return
	game.can_save = false
	game.settings["autosave"] = false
	if not check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot folder"):
		return
	if not _fixture():
		return
	_model()
	camp = CampUI.of(game.hud)
	if not check(camp != null, "CampUI attached"):
		return
	camp.open()
	camp.set_process(false)
	await _resize(Vector2i(1920, 1080))
	await _screens()
	await _resize(Vector2i(1280, 720))
	await _responsive("720", "en")


func _fixture() -> bool:
	var city := game.city
	city.cozy_v = 1
	city.legion_v = 3
	city.level = 5
	city.name = "Нова Рома"
	city.hero = Hero.make("Гай Валерий", 0, Hero.PRESETS[0]["look"], true, 777)
	lg = city.legion
	lg.fort = {}
	lg.camp = {}
	lg.soldiers.clear()
	lg.items.clear()
	lg.upg.clear()
	lg.flags["camp_open"] = true
	lg.flags["camp_told"] = true
	lg.flags["fort_guide"] = Legion.FortGuide.DONE
	lg.time_k = 1.0
	Legion.clock = Time.get_unix_time_from_system()
	lg.army_tick()
	Fixture.set_level(lg, "hq", 5)
	Fixture.set_level(lg, "forge", 5)
	Fixture.set_level(lg, "store", 1)
	Fixture.set_level(lg, "kitchen", 1)
	forge = int(lg.fort_slot_plot("forge")["id"])
	kitchen = int(lg.fort_slot_plot("kitchen")["id"])
	lg.fort["money"] = 19000.0
	lg.mats = {"iron": 130000.0, "wood": 99000.0, "leather": 79000.0}
	lg.ingots = 100
	lg.glory = 120
	lg.chest_queue = ["wooden", "bronze", "gold"]
	var cook := Fixture.recruit(lg, false)
	var smith := Fixture.recruit(lg, false)
	if not check(not cook.is_empty() and not smith.is_empty(), "residents for rooms"):
		return false
	cook["name"] = "Аврелий"
	sid = int(cook["id"])
	return check(lg.fort_assign(kitchen, sid) and lg.fort_assign(forge, int(smith["id"])), "workers assigned")


func _model() -> void:
	var saved := lg.to_dict().duplicate(true)
	var old := saved.duplicate(true)
	old["fort"].erase("know")
	old["fort"].erase("know_at")
	old["fort"]["smith_knowledge"] = true
	lg.from_dict(old)
	check(lg.smith_known() and lg.fort["know"] == {"smith": true}, "old save migrated to know.smith")
	old["fort"].erase("smith_knowledge")
	lg.from_dict(old)
	check(lg.fort["know"].is_empty() and lg.knowledge_timer().is_empty(), "empty old save")
	check(not lg.learn("bows"), "bows prerequisites")
	Fixture.set_level(lg, "hq", 1)
	check(not lg.learn("smith"), "HQ gate")
	Fixture.set_level(lg, "hq", 5)
	var start := lg.city_money()
	var iron := lg.mat("iron")
	check(lg.learn("smith") and not lg.learn("smith") and lg.city_money() == start - 800 and lg.mat("iron") == iron - Legion.Knowledge.NODES["smith"]["mats"]["iron"], "root paid once")
	check(not lg.craft_start(forge, "bow", 1), "bows refused before knowledge")
	check(not lg.craft_start(forge, "sword", 3), "tier 3 sword needs weap3")
	check(lg.fort_assign(forge, 0), "unassign smith for research")
	var wood := lg.mat("wood")
	var leather := lg.mat("leather")
	start = lg.city_money()
	check(lg.learn("bows") and not lg.learn("bows") and not lg.learn("staffs")
		and lg.city_money() == start - 1200 and lg.mat("wood") == wood - Legion.Knowledge.NODES["bows"]["mats"]["wood"] and lg.mat("leather") == leather - Legion.Knowledge.NODES["bows"]["mats"]["leather"]
		and lg.knowledge_timer().get("id") == "bows", "one paid timer without a worker")
	var during := lg.to_dict().duplicate(true)
	var end := float(lg.knowledge_timer().get("end", 0.0))
	check(is_equal_approx(end - Legion.now(), 3600.0), "one hour at normal speed")
	lg.from_dict(during)
	check(not lg.knows("bows") and float(lg.knowledge_timer().get("end", 0.0)) == end, "active timer persists")
	Legion.clock = end + 1.0
	lg.fort_finish()
	var smith_id := 0
	for person: Dictionary in lg.soldiers:
		if not bool(person.get("hero", false)) and int(person["id"]) != sid:
			smith_id = int(person["id"])
			break
	check(lg.knows("bows") and lg.knowledge_timer().is_empty() and lg.fort_assign(forge, smith_id)
		and lg.craft_start(forge, "bow", 1), "timer finishes and bow enters queue")
	var ingots_before := lg.ingots
	check(lg.learn("weap3"), "weapon tiers start")
	var price := lg.knowledge_instant_price()
	check(price == Legion.instant_ingots(4.0 * 3600.0) and not lg.finish_knowledge_now("staffs") and lg.finish_knowledge_now("weap3")
		and not lg.finish_knowledge_now("weap3") and lg.ingots == ingots_before - price and lg.knows("weap3"), "instant construction price and single payment")
	lg.fort["know"]["reforge"] = true
	var item := lg.add_item(Gear.craft_item("sword", 2, 3))
	var id := int(item["id"])
	var quote := lg.reforge_quote(id)
	check(quote["mats"] == Gear.craft_mats("sword", 3) and lg.reforge_item(id, 3) and not lg.reforge_item(id, 3)
		and Gear.tier_of(item) == 3 and item["rarity"] == 3, "reforge tier, price and rarity")
	_caps()
	var p := lg.fort_plot(kitchen)
	lg.rations = lg.resource_cap("rations")
	p["pend"] = 8.0
	p["t"] = Legion.now() - 3600.0
	lg.fort_finish()
	check(float(p["pend"]) == 8.0 and lg.fort_collect(kitchen) == 0, "full production paused")
	lg.rations -= 3
	check(lg.fort_collect(kitchen) == 3 and float(p["pend"]) == 5.0 and lg.rations == lg.resource_cap("rations"), "partial collect leaves remainder")
	while lg.store_count() < lg.store_cap():
		lg.add_item(Gear.craft_item("sword", 1))
	lg.fort["know"]["luck1"] = true
	check(lg.craft_odds() == [52, 30, 13, 4, 1], "improved craft odds I")
	lg.fort["know"]["luck2"] = true
	check(lg.craft_odds() == [42, 33, 17, 6, 2], "improved craft odds II")
	var plain := lg.smelt_preview(id)
	lg.fort["know"]["smelt"] = true
	var boosted := lg.smelt_preview(id)
	for res: String in plain:
		check(int(boosted[res]) == roundi(float(plain[res]) * 1.5), "smelt bonus " + res)
	var queue := lg.chest_queue.duplicate()
	var rng_before := lg._rng.state
	check(lg.open_chest("wooden").is_empty() and lg.chest_queue == queue and lg._rng.state == rng_before, "full storage refuses chest before rolling")
	lg.from_dict(saved)


func _caps() -> void:
	for id: String in Know.NODES:
		var node: Dictionary = Know.NODES[id]
		var hq := int(node["hq"])
		check(_price_fits(hq, node), "knowledge price at HQ %d: %s" % [hq, id])
		var seconds := float(node["hours"]) * 3600.0
		check(seconds == 0 or Legion.instant_ingots(seconds) <= Legion.resource_cap_at("ingots", hq, 1), "instant knowledge price " + id)
	for room: String in Legion.FORT_B:
		for tier in range(1, 31):
			var hq := maxi(tier - 1, 1) if room == "hq" else maxi(tier, int(Legion.FORT_B[room]["max"][0]))
			check(_price_fits(hq, Legion.fort_cost(room, tier)), "room price " + room + " " + str(tier))
			check(Legion.instant_ingots(Legion.camp_time_h(tier) * 3600.0) <= Legion.resource_cap_at("ingots", hq, 1), "instant room price " + room + " " + str(tier))
	for recipe: String in Gear.CRAFT_TYPES:
		for tier in range(1, Gear.TIERS + 1):
			var hq := Gear.tier_room_level(tier)
			for need: String in Know.recipe_requirements(recipe, tier):
				hq = maxi(hq, int(Know.NODES[need]["hq"]))
			check(_price_fits(hq, {"mats": Gear.craft_mats(recipe, tier)}), "craft price " + recipe + " " + str(tier))
	for slot: String in Gear.SLOTS_V3:
		check(_price_fits(6, {"money": Gear.SET_FORGE["money"], "mats": lg.set_mats(slot)}), "set price " + slot)


func _price_fits(hq: int, cost: Dictionary) -> bool:
	if int(cost.get("money", 0)) > Legion.resource_cap_at("money", hq, 1):
		return false
	for res: String in cost.get("mats", {}):
		if int(cost["mats"][res]) > Legion.resource_cap_at(res, hq, 1):
			return false
	return true


func _resize(pixels: Vector2i) -> void:
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = pixels
	await frames(8)
	check(get_viewport().get_visible_rect().size.is_equal_approx(Vector2(pixels)), "viewport %s" % str(pixels))


func _screens() -> void:
	lg.rations = lg.resource_cap("rations") - 3
	lg.ingots = lg.resource_cap("ingots")
	lg.mats = {"iron": 175.0, "wood": 145.0, "leather": 120.0}
	lg.fort_plot(kitchen)["pend"] = 7.0
	lg.fort["know"] = {"smith": true, "bows": true, "weap3": true, "outfit": true}
	lg.fort["know_at"] = {"id": "staffs", "end": Legion.now() + 3100.0, "total": 7200.0}
	for i in 18:
		lg.add_item(Gear.craft_item(["sword", "bow", "staff", "helmet", "armor", "offhand", "cook"][i % 7], 1 + i % 3, i % 5))
	var apron := lg.add_item(Gear.craft_item("cook", 1))
	lg.equip(sid, int(apron["id"]))
	camp._refresh()
	check((camp.resource_bars["ingots"]["lock"] as Control).visible, "full resource lock visible")
	await shot("1_topbar_full.png")
	camp.chest_button.pressed.emit()
	await _panel("1080 store")
	var cells := camp.modal_panel.find_child("FortInventoryGrid", true, false)
	var locks := camp.modal_panel.find_children("FortStoreLocked_*", "PanelContainer", true, false)
	check(cells != null and cells.get_child_count() == lg.store_cap() and locks.size() == Gear.STORE_PER, "store capacity and one locked row")
	await shot("2_store_window.png")
	Fixture.set_level(lg, "store", 5)
	camp.show_storage("all", 1)
	cells = camp.modal_panel.find_child("FortInventoryGrid", true, false)
	check(cells != null and cells.get_child_count() == 5, "last store page shows only the remaining capacity")
	Fixture.set_level(lg, "store", 1)
	camp.show_storage()
	var chest := camp.modal_panel.find_child("FortChest_wooden", true, false) as Button
	if check(chest != null, "chest storage tile"):
		chest.pressed.emit()
	await _panel("1080 chest")
	await shot("3_chest_preview.png")
	var open := camp.modal_panel.find_child("FortChestOpen", true, false) as Button
	check(open != null and not open.disabled, "preview offers open")
	var close_preview := camp.modal_panel.find_child("FortChestPreviewClose", true, false) as Button
	if check(close_preview != null and close_preview.get_meta("kit_role", "") == "close", "preview uses B1 close"):
		close_preview.pressed.emit()
		check(camp.modal_panel.find_child("FortChestPreview", true, false) == null, "preview close keeps storage open")
	while lg.store_count() < lg.store_cap():
		lg.add_item(Gear.craft_item("bow", 1))
	camp.show_storage("chest", 0, "wooden")
	open = camp.modal_panel.find_child("FortChestOpen", true, false) as Button
	check(open != null and open.disabled, "full preview disables confirm")
	camp.show_knowledge("bows")
	await _panel("1080 tree")
	check(camp.modal_panel.find_children("KnowledgeTier_*", "PanelContainer", true, false).size() == Know.NODES.size(), "all knowledge nodes show a tier or effect")
	check(camp.modal_panel.find_child("KnowledgeClock_staffs", true, false) != null
		and camp.modal_panel.find_child("KnowledgeLock_armor9", true, false) != null, "tree shows learning and HQ pills")
	var medallions := camp.modal_panel.find_children("KnowNode_*", "Button", true, false)
	for pattern: String in ["KnowledgeTier_*", "KnowledgeClock_*", "KnowledgeLock_*"]:
		for pill: Control in camp.modal_panel.find_children(pattern, "PanelContainer", true, false):
			for button: Control in medallions:
				check(not pill.get_global_rect().intersects(button.get_global_rect()), "%s clear of %s" % [pill.name, button.name])
	var learned := camp.modal_panel.find_child("FortLearnKnowledge", true, false) as Button
	check(learned != null and learned.disabled, "learned node has disabled action")
	await shot("4_tree.png")
	var timer := lg.knowledge_timer()
	lg.fort["know_at"] = {}
	for material: String in Legion.Knowledge.NODES["spears"]["mats"]:
		lg.mats[material] = float(Legion.Knowledge.NODES["spears"]["mats"][material])
	camp.show_knowledge("spears")
	var learn := camp.modal_panel.find_child("FortLearnKnowledge", true, false) as Button
	check(learn != null and not learn.disabled, "available knowledge action")
	await shot("5_node_card.png")
	lg.fort["know_at"] = timer
	camp._close_modal()
	camp.lu._craft_kind = "spear"
	camp.lu._craft_tier = 1
	camp.lu.open_craft(forge)
	await frames(5)
	var lock := camp.lu.overlay.find_child("CraftKnowledgeLock", true, false) as Button
	check(lock != null and (camp.lu.overlay.find_child("CraftStart", true, false) as Button).disabled, "locked recipe")
	await shot("6_craft_locked.png")
	if lock != null:
		lock.pressed.emit()
		check(camp.knowledge_focus == "spears", "recipe opens correct node")
	camp.lu.close()
	camp._close_modal()
	camp._collect_plot(kitchen)
	check(float(lg.fort_plot(kitchen)["pend"]) == 4.0 and lg.rations == lg.resource_cap("rations"), "partial collect through room UI")
	camp._refresh()
	check(bool(camp.plot_markers[kitchen]["collect"].get_meta("stock_lock", false)), "room bubble uses lock")
	await shot("7_room_full_bubble.png")
	await get_tree().create_timer(0.7).timeout
	camp.show_dweller(sid)
	await _panel("1080 dweller")
	check(camp.modal_panel.find_child("FortPortraitArt", true, false) != null, "live preview present")
	await shot("8_dweller_card.png")
	(camp.resource_bars["ingots"]["plus"] as Button).pressed.emit()
	check(camp.modal_panel.name == "FortResourcePopup", "resource cap popup")
	camp._jump_to_type("store")
	var caps := camp.card.find_child("FortStoreCaps", true, false)
	check(caps != null and caps.get_child_count() == 7, "store card six stocks and item cap")


func _responsive(tag: String, language: String) -> void:
	I18n.set_lang(language)
	camp.show_storage()
	await _panel(tag + " storage")
	camp.show_storage("chest", 0, "wooden")
	await _panel(tag + " storage + preview")
	for id: String in ["smith", "staffs", "armor1", "outfit", "sets"]:
		camp.show_knowledge(id)
		await _panel(tag + " tree " + id)
	camp.show_dweller(sid)
	await _panel(tag + " dweller")
	var tiles := camp.modal_panel.find_children("FortEquip_*", "Button", true, false)
	if check(not tiles.is_empty(), tag + " wearable items"):
		(tiles[0] as Button).pressed.emit()
		await _panel(tag + " item comparison")
		check(camp.modal_panel.find_child("FortItemEquip", true, false) != null, tag + " item equip action")


func _panel(tag: String) -> void:
	await frames(5)
	if not check(is_instance_valid(camp.modal_panel), tag + " panel missing"):
		return
	var viewport := get_viewport().get_visible_rect().grow(0.5)
	var rect := camp.modal_panel.get_global_rect().grow(0.5)
	var close_found := false
	for button: Button in camp.modal_panel.find_children("*", "Button", true, false):
		close_found = close_found or button.get_meta("kit_role", "") == "close"
	check(camp.modal_panel is UiKitA.CardPanel and close_found, tag + " shared frame and B1 close")
	check(viewport.encloses(rect), tag + " modal outside viewport")
	check(camp.modal_panel.find_children("*", "ScrollContainer", true, false).is_empty(), tag + " unexpected scrollbar")
	for label: Label in camp.modal_panel.find_children("*", "Label", true, false):
		if not label.is_visible_in_tree():
			continue
		check(label.size.x + 0.5 >= label.get_combined_minimum_size().x and label.size.y + 0.5 >= label.get_combined_minimum_size().y
			and rect.encloses(label.get_global_rect()), tag + " label overflow " + label.text)
