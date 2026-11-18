extends Node3D
## Таймеры и четыре кадра форта. Запускает владелец проверки.

const Fixture = preload("res://scripts/test_fort_fixture.gd")
var out := "D:/CivCity/.work/stage6/legion7a2/shots/fort6/"
var fails := 0
var logic_only := false
var saved_clock := -1.0
var saved_lang := "ru"
var game: Game
var camp: CampUI


func check(ok: bool, reason: String) -> bool:
	if not ok:
		fails += 1
		print("FORT6 FAIL " + reason)
	return ok


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "logic=1":
			logic_only = true
		if arg.begins_with("out="):
			out = arg.substr(4).trim_suffix("/") + "/"
	saved_clock = Legion.clock
	saved_lang = I18n.lang
	Legion.clock = 2000000.0
	I18n.set_lang("ru")
	_timers()
	_timer_paths()
	_instant()
	_separate_money()
	_formatting()
	if logic_only or fails > 0:
		_finish()
		return
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1920, 1080)
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	game.can_save = false
	add_child(game)
	_screens()


func town() -> City:
	var c := City.new(Land.new())
	c.cozy_v = 1
	c.legion_v = 3
	c.level = Defs.LEVELS.size() - 1
	c.money = 1e12
	c.legion.army_tick()
	c.legion.fort["money"] = 1e12
	c.legion.mats = {"iron": 1e9, "wood": 1e9, "leather": 1e9}
	c.legion.glory = 1e9
	c.legion.ingots = 10000
	return c


func _timers() -> void:
	var expected := [0, 300, 900, 7200, 21600, 43200, 86400, 172800, 259200, 345600, 432000, 518400, 604800]
	for level in expected.size():
		check(roundi(Legion.camp_time_h(level) * 3600.0) == int(expected[level]), "timer L%d" % level)
	var total := 0.0
	for level in range(2, 13):
		total += Legion.camp_time_h(level)
	check(total >= 650.0 and total <= 720.0 and is_equal_approx(total, 692.25), "path 1 to 12 is 692.25 hours")
	for level in range(13, 26):
		check(is_equal_approx(Legion.camp_time_h(level) - Legion.camp_time_h(level - 1), 24.0), "endless daily step L%d" % level)


func _timer_paths() -> void:
	for time_scale: float in [1.0, 2.0]:
		for type: String in ["hq", "kitchen", "forge"]:
			var room_city := town()
			var room_lg: Legion = room_city.legion
			room_lg.time_k = time_scale
			Fixture.set_level(room_lg, "hq", 12)
			Fixture.set_level(room_lg, type, 11)
			var room_id := int(room_lg.fort_slot_plot(type)["id"])
			var seconds := 604800.0 * float(Legion.FORT_B[type]["time_k"]) / time_scale
			check(is_equal_approx(float(room_lg.fort_info(room_id)["next_time"]), seconds)
				and is_equal_approx(float(room_lg.camp_info(type)["time"]), seconds), type + " preview uses common timer")
			if check(room_lg.fort_upgrade(room_id), type + " upgrade starts"):
				check(is_equal_approx(float(room_lg.fort_plot(room_id)["up"]["total"]), seconds), type + " actual timer matches preview")
		for expansion in [0, 5, 9]:
			for axis: String in ["floor", "section"]:
				var expansion_city := town()
				var expansion_lg: Legion = expansion_city.legion
				expansion_lg.time_k = time_scale
				Fixture.set_level(expansion_lg, "hq", 30)
				expansion_lg.fort["exp"] = expansion
				var info := expansion_lg.fort_expansion_info(axis)
				var hours := Legion.camp_time_h(expansion + 3)
				check(is_equal_approx(float(info["time_h"]), hours), axis + " expansion uses common timer")
				if check(expansion_lg.fort_expand(axis), axis + " expansion starts"):
					check(is_equal_approx(float(expansion_lg.fort["up"]["total"]), hours * 3600.0 / time_scale), axis + " actual timer matches preview")
	var c := town()
	var lg: Legion = c.legion
	var id := lg.fort_empty_plot()
	if check(lg.fort_build("kitchen", id), "first construction starts"):
		check(is_equal_approx(float(lg.fort_plot(id)["up"]["total"]), 300.0), "first construction stays five minutes")
		Legion.clock = Legion.now() + 1e7
		lg.fort_finish()
		check(int(lg.fort_plot(id)["lv"]) == 1 and not lg.camp_busy(), "large fixture clock jump still finishes")


func _instant() -> void:
	var c := town()
	var lg: Legion = c.legion
	Fixture.set_level(lg, "hq", 12)
	Fixture.set_level(lg, "kitchen", 11)
	var p := lg.fort_slot_plot("kitchen")
	var id := int(p["id"])
	for sample: Array in [[0.0, 1], [1.0, 1], [300.0, 3], [900.0, 5], [3600.0, 10], [21600.0, 23], [86400.0, 46], [604800.0, 121]]:
		var seconds := float(sample[0])
		p["up"] = {"to": 12, "end": Legion.now() + seconds, "total": maxf(1.0, seconds)}
		var quote := lg.fort_instant_info(id)
		check(int(quote["price"]) == int(sample[1])
			and int(quote["price"]) == maxi(1, ceili(1.2 * sqrt(seconds / 60.0))), "instant price for %.0f seconds" % seconds)
		check(int(lg.fort_instant_info(id)["price"]) == int(quote["price"]), "quote is stable at frozen clock")
	p["up"] = {"to": 12, "end": Legion.now() + 604800.0, "total": 604800.0}
	var before := int(lg.fort_instant_info(id)["price"])
	Legion.clock += 518400.0
	check(before == 121 and int(lg.fort_instant_info(id)["price"]) == 46, "price follows remaining time")
	p["up"] = {}
	var quote := lg.fort_instant_info(id)
	check(int(quote["price"]) == 121, "fresh seven-day upgrade price")
	var money := lg.city_money()
	var cost := float(Legion.fort_cost("kitchen", 12)["money"])
	if check(lg.fort_instant(id, quote), "fresh instant succeeds"):
		check(int(p["lv"]) == 12 and lg.ingots == 10000 - 121
			and is_equal_approx(lg.city_money(), money - cost), "fresh instant pays both costs once")
	var ingots := lg.ingots
	check(not lg.fort_instant(id, quote) and lg.ingots == ingots, "stale quote cannot buy next level")
	p["up"] = {"to": 13, "end": Legion.now() + 86400.0, "total": 86400.0}
	lg.ingots = 45
	check(not lg.fort_instant(id) and lg.ingots == 45 and lg.city_money() == money - cost, "insufficient ingots never debit")
	lg.ingots = 1000
	money = lg.city_money()
	if check(lg.fort_instant(id), "active instant succeeds"):
		check(int(p["lv"]) == 13 and lg.ingots == 954 and lg.city_money() == money, "active instant only pays ingots")
	p["up"] = {"to": 14, "end": Legion.now(), "total": 86400.0}
	check(not lg.fort_instant(id) and lg.ingots == 954 and int(p["lv"]) == 14, "expired timer finishes without buying next level")
	lg.fort["up"] = {"to": 1, "end": Legion.now() + 604800.0, "total": 604800.0}
	check(int(lg.fort_instant_info(0)["price"]) == 121, "HQ expansion instant uses same formula")


func _separate_money() -> void:
	var c := town()
	var lg: Legion = c.legion
	Fixture.set_level(lg, "hq", 12)
	Fixture.set_level(lg, "kitchen", 11)
	var id := int(lg.fort_slot_plot("kitchen")["id"])
	if not check(lg.fort_upgrade(id), "separate money fixture starts seven-day upgrade"):
		return
	var timer: Dictionary = lg.fort_plot(id)["up"].duplicate(true)
	var money := c.money
	lg.fort["money"] = 0.0
	lg.tick()
	check(lg.fort_plot(id)["up"] == timer and c.money == money and lg.city_money() == 0.0,
		"rich city cannot fund or shorten a Legion timer")
	c.money = 0.0
	c.day += 1
	lg.tick()
	check(lg.fort_plot(id)["up"] == timer and lg.city_money() == 0.0,
		"city balance and day do not change Legion timers")
	check(not lg.has_method("speed_up") and not lg.has_method("speed_info")
		and not lg.has_method("speed_remaining"), "paid money speed-up removed")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(lg.to_dict()))
	saved["speed_day"] = c.day
	saved["speed_used"] = 7200.0
	var copy := town()
	copy.legion.from_dict(saved)
	var loaded := copy.legion.to_dict()
	check(copy.legion.fort_plot(id)["up"] == timer and copy.legion.city_money() == 0.0,
		"old speed quota loads without changing timer or Legion money")
	check(not loaded.has("speed_day") and not loaded.has("speed_used"), "obsolete speed quota is no longer saved")


func _formatting() -> void:
	check(CampUI.duration_text(604800.0) == "7 д", "duration: seven days")
	check(CampUI.clock_text(604800.0) == "7 д", "running clock: seven days")
	check(Legion.fmt_duration(604800.0) == "7 д", "HUD duration: seven days")
	check(CampUI.duration_text(176400.0) == "2 д 1 ч"
		and CampUI.clock_text(176400.0) == "2 д 1 ч", "day and hour remain readable")
	check(CampUI.clock_text(900.0) == "0:15:00" and CampUI.duration_text(300.0) == "5 мин", "short timer formats preserved")
	I18n.set_lang("en")
	check(CampUI.duration_text(604800.0) == "7 d" and CampUI.clock_text(604800.0) == "7 d"
		and Legion.fmt_duration(604800.0) == "7 d", "English long timers")
	I18n.set_lang("ru")


func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func shot(file: String) -> void:
	await frames(20)
	await RenderingServer.frame_post_draw
	if check(get_viewport().get_texture().get_image().save_png(out + file) == OK, "save " + file):
		print("FORT6 SHOT " + out + file)


func has_text(root: Node, text: String) -> bool:
	for label: Node in root.find_children("*", "Label", true, false):
		if (label as Label).text == text:
			return true
	return false


func _screens() -> void:
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
	I18n.set_lang("ru")
	if not check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory"):
		_finish()
		return
	var city: City = game.city
	city.cozy_v = 1
	city.legion_v = 3
	city.level = Defs.LEVELS.size() - 1
	city.money = 1e12
	var lg: Legion = city.legion
	lg.time_k = 1.0
	lg.fort = {}
	lg.camp = {}
	lg.flags["camp_open"] = true
	lg.flags["camp_told"] = true
	lg.flags["camp3d_guide"] = 4
	lg.army_tick()
	lg.fort["money"] = 1e12
	lg.mats = {"iron": 1e9, "wood": 1e9, "leather": 1e9}
	lg.glory = 1e9
	lg.ingots = 1000
	Fixture.set_level(lg, "hq", 12)
	Fixture.set_level(lg, "kitchen", 11)
	camp = CampUI.of(game.hud)
	if not check(camp != null, "CampUI attached"):
		_finish()
		return
	camp.open()
	var id := int(lg.fort_slot_plot("kitchen")["id"])
	camp.show_plot(id)
	check(camp.upgrade_button.text.contains("7 д"), "room preview shows seven days")
	check(camp.instant_price.text == "121" and camp.instant_button.icon != null, "room shows new price and icon")
	await shot("1_room_preview.png")
	if not check(lg.fort_upgrade(id), "visual seven-day upgrade starts"):
		_finish()
		return
	camp._refresh()
	check(camp.upgrade_timer.visible and camp.upgrade_timer.text == "7 д", "room running timer shows days")
	check(camp.card.find_child("FortSpeedAction", true, false) == null, "room has no paid money speed-up")
	var marker: Dictionary = camp.plot_markers[id]
	check((marker["clock"] as Button).text.contains("7 д"), "builder marker HUD uses days")
	await shot("2_room_running.png")
	Legion.clock = float(lg.fort_plot(id)["up"]["end"])
	lg.fort_finish()
	camp.show_build_menu()
	check(has_text(camp.build_cards["forge"]["panel"], "5 мин"), "build menu keeps first construction time")
	await shot("3_build_menu.png")
	Fixture.set_level(lg, "hq", 30)
	lg.fort["exp"] = 9
	camp.show_expansion("floor")
	check(has_text(camp.modal_panel, "7 д"), "floor expansion shows days")
	await shot("4_expansion.png")
	camp.show_expansion("section")
	check(has_text(camp.modal_panel, "7 д"), "section expansion shows days")
	camp.show_plot(0)
	check(camp.card.find_child("FortSpeedAction", true, false) == null, "HQ has no expansion money speed-up")
	camp.show_hero()
	check(camp.modal_panel.find_child("FortSpeedAction", true, false) == null, "hero has no paid money speed-up")
	_finish()


func _finish() -> void:
	if is_instance_valid(camp):
		camp.close()
	Legion.clock = saved_clock
	I18n.set_lang(saved_lang)
	print("FORT6 DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
