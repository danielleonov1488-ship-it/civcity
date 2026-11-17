extends Node3D
## logic=1 — только модель. Без аргумента — модель и три снимка; запускает владелец проверки.

const Fixture = preload("res://scripts/test_fort_fixture.gd")
var fails := 0
var out := "D:/CivCity/.work/stage4/gear1/shots/"
var game: Game
var camp: CampUI
var saved_clock := -1.0
var logic_only := false


func check(ok: bool, reason: String) -> bool:
	print(("GEAR1 PASS " if ok else "GEAR1 FAIL ") + reason)
	if not ok:
		fails += 1
	return ok


func _ready() -> void:
	saved_clock = Legion.clock
	for arg in OS.get_cmdline_user_args():
		if arg == "logic=1":
			logic_only = true
		if arg.begins_with("out="):
			out = arg.substr(4).trim_suffix("/") + "/"
	Legion.clock = 2000000.0
	_rules()
	_queue()
	_power()
	_legacy()
	_balance()
	Legion.clock = saved_clock
	if logic_only or fails > 0:
		_finish()
		return
	Game.boot = {"new": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	add_child(game)
	game.can_save = false
	_screens()


func town() -> City:
	var c := City.new(Land.new())
	c.cozy_v = 1
	c.legion_v = 3
	c.hero = {}
	c.money = 1e6
	c.legion.army_tick()
	c.legion.fort["money"] = 1e6
	c.legion.fort["smith_knowledge"] = true
	c.legion.flags["camp_open"] = true
	c.legion.mats = {"iron": 10000.0, "wood": 10000.0, "leather": 10000.0}
	Fixture.set_level(c.legion, "hq", 12)
	Fixture.set_level(c.legion, "barracks", 1)
	Fixture.set_level(c.legion, "forge", 2)
	Fixture.set_level(c.legion, "arsenal", 2)
	return c


func worker(lg: Legion, type: String) -> int:
	var s := lg._add_soldier({"name": "Кузнец", "cls": "legionary", "stars": 1})
	var id := int(lg.fort_slot_plot(type)["id"])
	check(lg.fort_assign(id, int(s["id"])), "assign worker " + type)
	return id


func _rules() -> void:
	var c := town()
	var lg: Legion = c.legion
	var id := worker(lg, "forge")
	var armory := worker(lg, "arsenal")
	var p := lg.fort_plot(id)
	for tier in range(1, 11):
		p["lv"] = Gear.tier_room_level(tier) - 1
		check(lg.can_craft(id, "sword", tier) != "", "tier %d blocked one room level below" % tier)
		p["lv"] = Gear.tier_room_level(tier)
		check(lg.can_craft(id, "sword", tier) == "", "tier %d opens at room level %d" % [tier, p["lv"]])
		check(lg.craft_tier_max(id) == tier, "unlocked tier %d" % tier)
		check(int(Gear.TIER_TIME[tier - 1]) == int([300, 1800, 3600, 7200, 14400, 28800, 43200, 86400, 129600, 172800][tier - 1]), "stepped timer %d" % tier)
	for kind: String in Gear.CRAFT_TYPES:
		var place := id if Gear.craft_room(kind) == "forge" else armory
		check(lg.can_craft(place, kind, 1) == "" and lg.can_craft(armory if place == id else id, kind, 1) != "", "room recipe " + kind)
	for lv in [2, 4, 8, 12]:
		p["lv"] = lv
		check(lg.craft_capacity(id) == (1 if lv < 4 else 2 if lv < 8 else 3), "queue capacity %d" % lv)
	check(Gear.tier_of({"ilvl": 1}) == 1 and Gear.tier_of({"ilvl": 5}) == 1 and Gear.tier_of({"ilvl": 6}) == 2 and Gear.tier_of({"ilvl": 99}) == 10, "legacy ilvl mapping")
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 91233
	b.seed = 91233
	var counts := [0, 0, 0, 0, 0]
	var matching := true
	for i in 10000:
		var r := Gear.roll_craft_rarity(a)
		matching = matching and r == Gear.roll_craft_rarity(b)
		counts[r] += 1
	var total := 0
	for n: int in Gear.CRAFT_ODDS:
		total += n
	check(matching and total == 100 and counts.all(func(n: int): return n > 0), "seeded rarity, all five rarities, odds sum to 100")
	var odds_ok := true
	for r in 5:
		odds_ok = odds_ok and absi(int(counts[r]) - int(Gear.CRAFT_ODDS[r]) * 100) < 250
	check(odds_ok, "rarity distribution follows displayed odds")


func _queue() -> void:
	var c := town()
	var lg: Legion = c.legion
	var id := int(lg.fort_slot_plot("forge")["id"])
	var money := c.money
	var materials := lg.mats.duplicate()
	check(not lg.craft_start(id, "sword", 1) and lg.mats == materials and c.money == money, "no worker: no craft and no payment")
	id = worker(lg, "forge")
	var armory := worker(lg, "arsenal")
	Fixture.set_level(lg, "forge", 8)
	var need := Gear.craft_mats("sword", 1)
	check(lg.craft_start(id, "sword", 1) and lg.mat("iron") == int(materials["iron"]) - int(need["iron"]), "materials paid at enqueue")
	check(lg.craft_start(id, "bow", 1) and lg.craft_start(id, "staff", 2) and not lg.craft_start(id, "spear", 1), "three jobs, fourth rejected")
	check(lg.craft_start(armory, "helmet", 1), "armory works independently")
	var state := lg._rng.state
	Legion.clock += 100.0
	lg.fort_finish()
	check(is_equal_approx(float(lg.craft_queue(id)[0]["left"]), 200.0) and is_equal_approx(float(lg.craft_queue(id)[1]["left"]), 300.0), "serial timer spends work only on first job")
	var sid := int(lg.fort_worker(id)["id"])
	check(lg.fort_assign(id, 0), "unassign worker")
	Legion.clock += 600.0
	lg.fort_finish()
	check(float(lg.craft_queue(id)[0]["left"]) == 200.0 and lg.craft_ready(id) == 0 and lg.craft_ready(armory) == 1, "unassigned queue pauses; other room finishes")
	check(not lg.has_method("speed_up"), "paused queue has no paid money shortcut")
	check(lg.fort_assign(id, sid), "resume worker")
	Legion.clock += 250.0
	lg.fort_finish()
	check(lg.craft_ready(id) == 1 and is_equal_approx(float(lg.craft_queue(id)[1]["left"]), 250.0), "offline surplus passes to next job")
	check(lg._rng.state == state and lg.store_count() == 0, "completion waits for collect, without rolling rarity")
	while lg.store_count() < lg.store_cap():
		lg.add_item(Gear.craft_item("helmet", 1))
	check(lg.craft_collect(id).is_empty() and lg._rng.state == state and lg.craft_ready(id) == 1, "full storage preserves finished job and RNG")
	lg.sell_item(int(lg.items[0]["id"]))
	var saved: Dictionary = JSON.parse_string(JSON.stringify(lg.to_dict()))
	var copy := town()
	copy.legion.from_dict(saved)
	var got := lg.craft_collect(id)
	var other := copy.legion.craft_collect(id)
	check(not got.is_empty() and got == other and lg.craft_queue(id).size() == 2, "save/load preserves queue, timer and next rarity roll")
	check(lg.craft_collect(id).is_empty(), "collect cannot take unfinished item")
	var next_left := float(lg.craft_queue(id)[1]["left"])
	Legion.clock += 250.0
	lg.fort_finish()
	check(lg.craft_ready(id) == 1 and float(lg.craft_queue(id)[0]["left"]) == 0.0
		and float(lg.craft_queue(id)[1]["left"]) == next_left, "full timer completes active job without shortening the next one")
	var p := lg.fort_plot(id)
	p["up"] = {"to": 9, "end": Legion.now() + 100.0, "total": 100.0}
	var left := float(lg.craft_queue(id)[1]["left"])
	Legion.clock += 150.0
	lg.fort_finish()
	check(is_equal_approx(float(lg.craft_queue(id)[1]["left"]), left - 50.0), "room upgrade pauses crafting exactly until completion")


func _power() -> void:
	var c := town()
	var lg: Legion = c.legion
	var s := lg._add_soldier({"name": "Гай", "cls": "legionary", "stars": 1})
	lg._v3_reclass(s)
	var sid := int(s["id"])
	var barracks := lg.fort_slot_plot("barracks")
	for kind: String in Gear.KIND_CLS:
		for tier in range(1, 10):
			var it := lg.add_item(Gear.craft_item(kind, tier, 2))
			lg.equip(sid, int(it["id"]))
			var type := String(Gear.KIND_CLS[kind])
			var before := Legion.power(lg.soldier_stats(s, type))
			barracks["lv"] = 2
			var level_gain := Legion.power(lg.soldier_stats(s, type)) - before
			barracks["lv"] = 1
			it["tier"] = tier + 1
			var tier_gain := Legion.power(lg.soldier_stats(s, type)) - before
			check(tier_gain > level_gain and s["cls"] == type, "%s tier %d gains %d > level %d; weapon decides class" % [kind, tier, tier_gain, level_gain])
			lg.sell_item(int(it["id"])) # Надетое не продастся; следующее оружие вернёт его на склад.
			for spare: Dictionary in lg.items.duplicate():
				if int(spare.get("on", 0)) == 0:
					lg.sell_item(int(spare["id"]))
	var armor := lg.add_item(Gear.craft_item("armor", 3, 1))
	var change := lg.equip_power(sid, int(armor["id"]))
	check(int(change[1]) > int(change[0]) and int(armor["on"]) == 0, "equip preview is positive and does not mutate inventory")
	var before := lg.soldier_stats(s, String(s["cls"]))
	lg.equip(sid, int(armor["id"]))
	var after := lg.soldier_stats(s, String(s["cls"]))
	check(int(after["hp"]) > int(before["hp"]) and float(after["armor"]) > float(before["armor"]), "equipping armour increases HP and armour")
	check(Fixture.house_fighter(lg, sid), "fighter lives in barracks")
	lg.set_place(0, sid)
	var snap := lg.pvp_snapshot()
	var stats := Legion.snapshot_stats(snap)
	check(stats.size() == 1 and stats[0]["atk"] == after["atk"] and stats[0]["hp"] == after["hp"] and stats[0]["armor"] == after["armor"], "snapshot mirrors gear battle stats")
	var old := Legion.snapshot_stats({"squad": [{"type": "legionary", "level": 2}]})
	check(old[0]["atk"] == Legion.unit_stats("legionary", 2)["atk"], "legacy snapshot unchanged")
	var filtered := Legion.gear_snapshot_stats({"hp": 100, "atk": "bad", "on": 5, "rate": 0, "vs": {"human": "bad"}})
	check(not filtered.has("on") and not filtered.has("atk") and filtered["rate"] > 0, "snapshot filters unsupported keys and invalid numbers")


func _legacy() -> void:
	var c := town()
	var lg: Legion = c.legion
	var id := worker(lg, "forge")
	lg.forging = {"slot": "weapon", "cls": "archer", "rarity": 3, "ilvl": 16, "set": "gallic", "end": Legion.now() + 240.0, "total": 500.0}
	var saved: Dictionary = JSON.parse_string(JSON.stringify(lg.to_dict()))
	var copy := town()
	copy.legion.from_dict(saved)
	check(copy.legion.forging.is_empty() and copy.legion.craft_queue(id).size() == 1 and float(copy.legion.craft_queue(id)[0]["left"]) == 240.0, "old paid order migrates with remaining timer")
	Legion.clock += 240.0
	var got := copy.legion.craft_collect(id)
	check(got.get("set", "") == "gallic" and int(got.get("rarity", 0)) == 3 and int(got.get("tier", 0)) == 4, "legacy order keeps class, set, rarity and mapped tier")
	var old := City.new(Land.new())
	old.cozy_v = 1
	old.legion_v = 0
	old.legion.from_dict({"v": 3, "items": [{"id": 5, "slot": "weapon", "cls": "legionary", "rarity": 1, "ilvl": 16}], "forging": saved["forging"]})
	check(not old.legion.item(5).has("tier") and not old.legion.forging.is_empty() and not old.legion.to_dict().has("fort"), "V2 save retains ilvl and legacy forge")


func _balance() -> void:
	var c := town()
	var lg: Legion = c.legion
	Fixture.set_level(lg, "hq", 1)
	for i in 3:
		var s := lg._add_soldier({"name": "Воин %d" % i, "cls": "legionary", "stars": 1})
		for kind: String in ["sword", "helmet", "armor", "offhand"]:
			var it := lg.add_item(Gear.craft_item(kind, 1))
			lg.equip(int(s["id"]), int(it["id"]))
		check(Fixture.house_fighter(lg, int(s["id"])), "fixture fighter lives in barracks")
		lg.set_place(i, int(s["id"]))
	for stage in 3:
		# Пращников снимает лучник; на волчьей тропе нужны щиты.
		var first := lg.soldier(int(lg.squad3[0]))
		var it := lg.add_item(Gear.craft_item("bow" if stage == 1 else "sword", 2 if stage == 1 else 1))
		lg.equip(int(first["id"]), int(it["id"]))
		var st := lg.stage_info(0, 0, stage)
		var setup := lg.make_battle(st, 991 + stage)
		var a := LegionSim.new(setup.duplicate(true)).run(false)
		var b := LegionSim.new(setup.duplicate(true)).run(false)
		check(bool(a.get("win", false)), "starter tier 1–2 wins battle %d without skills" % (stage + 1))
		check(a == b, "battle %d deterministic" % (stage + 1))
	# Ещё более ранний отряд: только оружие, без шлемов, доспехов и щитов.
	for s: Dictionary in lg.soldiers:
		for slot: String in ["helmet", "armor", "offhand"]:
			lg.unequip(int(s["id"]), slot)
	for stage in 3:
		var first := lg.soldier(int(lg.squad3[0]))
		var it := lg.add_item(Gear.craft_item("bow" if stage == 1 else "sword", 2 if stage == 1 else 1))
		lg.equip(int(first["id"]), int(it["id"]))
		var result := LegionSim.new(lg.make_battle(lg.stage_info(0, 0, stage), 991 + stage)).run(false)
		check(bool(result.get("win", false)), "starter weapons only win battle %d" % (stage + 1))
	for r in 10:
		check(int(lg.stage_info(0, r, 0)["recommended_tier"]) == r + 1, "region %d expects tier %d" % [r + 1, r + 1])


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(file: String) -> void:
	await frames(15)
	if DisplayServer.get_name() == "headless":
		check(false, "screenshots require a rendering run; use logic=1 for headless")
		return
	await RenderingServer.frame_post_draw
	if check(get_viewport().get_texture().get_image().save_png(out + file) == OK, "save " + file):
		print("GEAR1 SHOT " + out + file)


func _screens() -> void:
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
	check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory")
	var city: City = game.city
	city.cozy_v = 1
	city.legion_v = 3
	city.hero = {}
	city.money = 1e6
	var lg: Legion = city.legion
	lg.army_tick()
	lg.flags["camp_open"] = true
	lg.flags["camp3d_guide"] = 4
	lg.fort = {"money": 1e6, "smith_knowledge": true, "exp": 1, "plots": [], "next_id": 0, "up": {}}
	lg._fort_add_plot("hq", 4)
	for type: String in ["barracks", "forge", "arsenal", "kitchen", "drill", "store"]:
		lg._fort_add_plot(type, 4)
	lg._fort_sync_camp()
	lg.mats = {"iron": 1000.0, "wood": 1000.0, "leather": 1000.0}
	var forge := worker(lg, "forge")
	worker(lg, "arsenal")
	var s := lg._add_soldier({"name": "Луций", "cls": "legionary", "stars": 3})
	lg._v3_reclass(s)
	for kind: String in ["sword", "helmet", "armor", "offhand"]:
		var it := lg.add_item(Gear.craft_item(kind, 2, 2))
		lg.equip(int(s["id"]), int(it["id"]))
	var better := lg.add_item(Gear.craft_item("sword", 3, 3))
	camp = CampUI.of(game.hud)
	check(camp != null, "HUD camp attached")
	if camp == null:
		_finish()
		return
	camp.open()
	check(lg.craft_start(forge, "sword", 1), "screenshot craft fixture")
	camp.show_plot(forge)
	camp.main_action.pressed.emit()
	check(camp.lu.camp_window == "craft" and camp.lu._craft_plot == forge, "room action opens correct craft panel")
	await shot("1_craft_panel.png")
	camp.lu.close()
	camp._show_soldier(int(s["id"]))
	if not check(is_instance_valid(camp.modal_panel) and camp.modal_panel.name == "FortDwellerCard", "new dweller gear card"):
		_finish()
		return
	var slots := camp.modal_panel.find_child("FortGearSlots", true, false)
	check(slots != null and slots.find_children("TierBadge", "Label", true, false).size() == 4, "four tier badges")
	await shot("2_soldier_gear.png")
	var weapon_button := camp.modal_panel.find_child("FortGear_weapon", true, false) as Button
	if not check(weapon_button != null, "weapon slot button"):
		_finish()
		return
	weapon_button.pressed.emit()
	var change := lg.equip_power(int(s["id"]), int(better["id"]))
	var equip_button := camp.modal_panel.find_child("FortEquip_%d" % int(better["id"]), true, false) as Button
	if not check(equip_button != null and equip_button.tooltip_text.contains(I18n.t("Сила: %d → %d") % [int(change[0]), int(change[1])]) and int(change[1]) > int(change[0]), "visible equip power comparison"):
		_finish()
		return
	equip_button.pressed.emit()
	check(int(better["on"]) == int(s["id"]) and camp.modal_panel.find_child("FortEquipChange", true, false) != null, "equip feedback on new card")
	await shot("2b_equip_comparison.png")
	camp._close_modal()
	# Только время фикстуры; готовность и пузырь проверяются обычным tick.
	lg.fort_plot(forge)["t"] = Legion.now() - 301.0
	lg.fort_finish()
	camp._hide_card()
	camp._refresh()
	check((camp.plot_markers[forge]["collect"] as Control).visible and lg.craft_ready(forge) == 1, "forge collect bubble")
	await shot("3_forge_bubble.png")
	var count := lg.store_count()
	(camp.plot_markers[forge]["collect"] as Button).pressed.emit()
	check(lg.store_count() == count + 1 and lg.craft_ready(forge) == 0, "bubble collects into shared storage")
	camp.close()
	_finish()


func _finish() -> void:
	Legion.clock = saved_clock
	print("GEAR1 DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
