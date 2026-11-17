extends Node3D
## MAGIS1: модель, все эффекты, совместимость и четыре кадра. Запускает проверяющий.

var out := "D:/CivCity/.work/stage5/magis/shots/"
var game
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


func check(ok: bool, reason: String) -> void:
	if not ok:
		fails += 1
		print("MAGIS1 FAIL " + reason)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(file: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.hud.advisor_panel.hide()
	await frames(8)
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(out + file)
	check(error == OK, "save " + file)
	if error == OK:
		print("MAGIS1 SHOT " + out + file)


func _put(c: City, type: String, at: Vector2) -> Dictionary:
	var b := c.place(type, at, 0.0, 0, 0, true)
	check(not b.is_empty(), "fixture " + type)
	if not b.is_empty():
		var door := c.door_point(b)
		c.land.paint_line(door - Vector2(3, 0), door + Vector2(3, 0), 2.0, Land.Kind.ROAD, true)
	return b


func _fixture(c: City) -> void:
	c.cozy_v = 1
	c.auto_hire = true
	c.wants_v = 0
	c.econ = 1
	c.legion_v = 3
	c.level = 5
	c.money = 1000000.0
	c.bulk = true
	for r: Dictionary in Defs.RESEARCH:
		c.research[r["id"]] = true
	for i in 12:
		var cls := "plebs" if i < 8 else ("artisans" if i < 10 else "patricians")
		var h := _put(c, String(Defs.CLASSES[cls]["house"]), Land.START + Vector2((i % 4) * 9 - 18, (i / 4) * 8 + 12))
		h["pop"] = 4
		h["families"] = [{"name": "Проба%d" % i, "n": 4, "cls": cls}]
	var types := ["center", "stall_fruit", "herbalist", "temple", "scriptorium", "farm", "warehouse", "mansio"]
	for i in types.size():
		_put(c, types[i], Land.START + Vector2(-28 + (i % 4) * 15, -12 - (i / 4) * 14))
	c.bulk = false
	c.fest_left = 24
	c.legion.flags["camp_open"] = true
	c.compute()


func _rules(c: City) -> void:
	for m: Dictionary in Defs.MAGIS:
		c.level = int(m["rank"]) - 1
		check(not Magis.is_open(c, String(m["id"])), "locked " + String(m["id"]))
		check(Magis.can_adopt(c, String(m["edicts"][0]["id"])) != "", "locked action")
		c.level += 1
		check(Magis.is_open(c, String(m["id"])), "opens at rank " + String(m["id"]))
	c.level = 4
	check(Magis.seats(c) == 1, "one seat before City")
	var id := "cens_pleb_levy"
	var before := c.money
	check(Magis.adopt(c, id), "adopt")
	check(c.money == before - 400.0 and c.edict_mul("tax_k:plebs") == 1.0, "cost deducted; pending has no effect")
	check(not Magis.adopt(c, "cens_artisan_charter"), "pending occupies the seat")
	for i in 5:
		Magis.hour(c)
	check(not Magis.active(c, id), "not active before deadline")
	Magis.hour(c)
	check(Magis.active(c, id) and c.edict_mul("tax_k:plebs") == 1.2, "active at six game hours")
	var paid := c.money
	check(Magis.cancel(c, id) and c.money == paid, "active cancel is free without refund")
	check(int(c.magis_cooldown[id]) == 24 and not Magis.adopt(c, id), "24-hour cooldown")
	for i in 23:
		Magis.hour(c)
	check(not Magis.adopt(c, id), "cannot readopt at 23 hours")
	Magis.hour(c)
	check(Magis.adopt(c, id), "can readopt at 24 hours")
	before = c.money
	check(Magis.cancel(c, id) and c.money == before + 400.0, "pending refund")
	c.magis_cooldown.clear()
	c.level = 5
	check(Magis.seats(c) == 2, "two seats at City")
	check(Magis.adopt(c, id) and Magis.adopt(c, "cens_artisan_charter"), "two pending fit")
	check(not Magis.adopt(c, "cens_settler_drive"), "third edict rejected")
	c.magis_orders.clear()
	c.magis_cooldown.clear()
	c.magis_orders = {"aed_market_day": {"left": 0, "paid": 800}, "praet_guilds": {"left": 0, "paid": 1400}, "quaes_export_duty": {"left": 0, "paid": 900}}
	check(is_equal_approx(c.edict_mul("shop_income"), 1.2 * 1.15 * 0.85), "active multipliers compose as a product")
	c.magis_orders = {"cens_pleb_levy": {"left": 0, "paid": 400}, "cens_settler_drive": {"left": 0, "paid": 400}}
	check(c.edict_add("happy:plebs") + c.edict_add("happy:all") == -7.0, "happiness additions compose as a sum")
	c.magis_orders.clear()
	c.money = 1000000.0
	c.compute()


func _all_effects(c: City) -> void:
	var tested := 0
	for m: Dictionary in Defs.MAGIS:
		for e: Dictionary in m["edicts"]:
			c.magis_orders.clear()
			c.magis_cooldown.clear()
			c.magis_gate_on = false
			c.compute()
			var baseline := {}
			for key: String in e["fx"]:
				baseline[key] = MagisPreview.metric(c, key)["value"]
			var grain_before := float(c.goods.get("wheat", 0.0))
			var cap_before := int(c.buildings.values().filter(func(b: Dictionary): return b["type"] == "stall_fruit")[0]["cap"])
			check(Magis.adopt(c, String(e["id"])), "adopt " + String(e["id"]))
			for i in int(e["hours"]):
				Magis.hour(c)
			c.compute()
			for key: String in e["fx"]:
				var before := float(baseline[key])
				var after := float(MagisPreview.metric(c, key)["value"])
				var delta := float(e["fx"][key]) if key.begins_with("happy:") or key == "legion_denarii" else float(e["fx"][key]) - 1.0
				if key in ["arrivals", "legion_gate"]:
					delta = -delta
				check((after - before) * delta > 0.0, "%s hooks %s: %.3f → %.3f" % [e["id"], key, before, after])
			if e["fx"].has("work_output"):
				var sign := float(e["fx"]["work_output"]) - 1.0
				check((float(c.goods["wheat"]) - grain_before) * sign > 0.0, "farm output is real")
				var cap_after := int(c.buildings.values().filter(func(b: Dictionary): return b["type"] == "stall_fruit")[0]["cap"])
				check((cap_after - cap_before) * sign > 0.0, "shop output is real")
			check(MagisPreview.rows(c, String(e["id"])).size() == e["fx"].size(), "all effects previewed")
			tested += 1
	check(tested == 18, "all eighteen edicts tested")
	c.magis_orders.clear()
	c.magis_cooldown.clear()
	c.compute()
	check(Magis.adopt(c, "trib_war_chest"), "war chest fixture")
	for i in 18:
		Magis.hour(c)
	var held := c.magis_treasury
	c.sim_day()
	check(c.magis_treasury > held and float(c.stats["legion_denarii"]) > 0.0, "city income reaches Legion treasury")
	held = c.magis_treasury
	var money := c.money
	c.legion._pay({"money": held * 0.5})
	check(is_equal_approx(c.magis_treasury, held * 0.5) and c.money == money, "Legion spends its treasury first")
	c.magis_orders.clear()
	c.magis_gate_on = true
	c.magis_gate_h = 0.0
	c.magis_gate_queue.clear()
	for i in 24:
		Magis.hour(c)
	check(c.magis_gate_queue.size() == 1, "one volunteer after 24 game hours")
	var gate_pick: Dictionary = c.magis_gate_queue[0].duplicate()
	var pop_before := int(c.stats["pop"])
	check(not c.legion.recruit_resident(gate_pick).is_empty(), "gate volunteer can be recruited")
	check(int(c.stats["pop"]) == pop_before and c.magis_gate_queue.is_empty(), "volunteer does not remove a resident")


func _saves(c: City) -> void:
	c.magis_orders = {"cens_pleb_levy": {"left": 0, "paid": 400}, "quaes_scholars": {"left": 7, "paid": 900}}
	c.magis_cooldown = {"cens_settler_drive": 17}
	c.magis_gate_h = 7.5
	var save := c.save_data()
	var land := Land.new()
	land.load_changes(c.land.save_changes())
	var restored := City.new(land)
	restored.auto_hire = true
	restored.load_data(JSON.parse_string(JSON.stringify(save)))
	check(c.magis_orders == restored.magis_orders and c.magis_cooldown == restored.magis_cooldown and c.magis_gate_h == restored.magis_gate_h and c.magis_gate_queue == restored.magis_gate_queue and is_equal_approx(c.magis_treasury, restored.magis_treasury), "JSON save/load active, pending, cooldown, gate and treasury")
	check(restored.edict_mul("tax_k:plebs") == 1.2 and restored.edict_mul("rp_rate") == 1.0, "pending stays inactive after load")
	var old := save.duplicate(true)
	old.erase("magis_v")
	old.erase("magis")
	var clean := City.new(Land.new())
	clean.auto_hire = true
	clean.land.load_changes(c.land.save_changes())
	clean.load_data(old)
	check(clean.magis_orders.is_empty() and clean.magis_treasury == 0.0, "old save has no edicts")
	var current := old.duplicate(true)
	current["magis_v"] = 1
	current["magis"] = {}
	var neutral := City.new(Land.new())
	neutral.auto_hire = true
	neutral.land.load_changes(c.land.save_changes())
	neutral.load_data(current)
	for m: Dictionary in Defs.MAGIS:
		for e: Dictionary in m["edicts"]:
			for key: String in e["fx"]:
				check(clean.edict_mul(key) == 1.0 and clean.edict_add(key) == 0.0, "neutral identity " + key)
				check(MagisPreview.metric(clean, key) == MagisPreview.metric(neutral, key), "old save identical metric " + key)
	clean.sim_day()
	neutral.sim_day()
	for key: String in ["income", "upkeep", "rp_day", "happy", "shop_income", "export_income"]:
		check(clean.stats[key] == neutral.stats[key], "old save identical hourly " + key)
	check(clean.money == neutral.money and clean.rp == neutral.rp, "old save identical hourly balances")


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
	game.tutorial.step = Tutorial.STEPS.size()
	game.tutorial.card.hide()
	game.tutorial.set_process(false)
	I18n.set_lang("ru")
	check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory")
	var fixture := City.new(Land.new())
	_fixture(fixture)
	_rules(fixture)
	_all_effects(fixture)
	_saves(fixture)
	var c: City = game.city
	_fixture(c)
	var hud: Hud = game.hud
	c.tips["tut"] = -1
	c.tips["ui"] = 3
	hud.apply_reveal(3)
	hud.close_panels()
	hud.advisor_panel.hide()
	var ui := MagisUI.of(hud)
	check(ui != null, "HUD entry attached")
	c.level = 0
	ui.refresh()
	check(not ui.top_button.visible, "HUD button hidden before first rank")
	c.level = 2
	ui.open()
	await frames(4)
	check(ui.visible and ui.top_button.visible and ui.cards.size() == 18, "opens with eighteen cards")
	check(ui.find_children("*", "ScrollContainer", true, false).is_empty(), "no scrollbar")
	for id: String in ui.cards:
		var card: Button = ui.cards[id]
		check(card.is_visible_in_tree() and ui.frame.get_global_rect().encloses(card.get_global_rect()), "visible card inside window " + id)
	await shot("1_window.png")
	ui._popup("cens_pleb_levy")
	check(ui.preview_label.text.contains("Было → стало") and ui.preview_label.text.contains("→"), "before → after text")
	await shot("2_popup.png")
	Magis.adopt(c, "cens_pleb_levy")
	ui._close_popup()
	ui.refresh()
	await shot("3_pending.png")
	for i in 6:
		Magis.hour(c)
	c.compute()
	ui.close()
	var home: Dictionary = c.buildings.values().filter(func(b: Dictionary): return b["type"] == "house_pleb")[0]
	check(home["happy_parts"].any(func(part: Array): return part[0] == "Эдикты" and int(part[1]) == -4), "happiness edicts row")
	hud.house_more = true
	hud.open_info(home)
	check(hud.info_box.find_children("*", "Label", true, false).any(func(label: Label): return label.text == "Эдикты"), "happiness row visible in detailed card")
	await shot("4_happiness_row.png")
	_finish()


func _finish() -> void:
	print("MAGIS1 DONE fails=", fails)
	get_tree().quit(1 if fails > 0 else 0)
