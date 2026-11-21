extends Node3D

const Person = preload("res://scripts/fort_person.gd")
const PersonLook = preload("res://scripts/legion_person_look.gd")
const Fixture = preload("res://scripts/test_fort_fixture.gd")
const SHOTS := "D:/CivCity/.work/stage7/legion13/shots/"

var game: Game
var camp: CampUI
var lg: Legion
var fails := 0
var output := SHOTS


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			output = arg.trim_prefix("out=").trim_suffix("/") + "/"
	check(DirAccess.make_dir_recursive_absolute(output) == OK, "shot directory")
	Game.boot = {"new": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	add_child(game)
	game.can_save = false
	var saved_clock := Legion.clock
	var saved_pvp := Legion.pvp_hero_srv
	await _run()
	Legion.clock = saved_clock
	Legion.pvp_hero_srv = saved_pvp
	print("LEGION13 DONE fails=", fails)
	get_tree().quit(int(fails > 0))


func check(ok: bool, description: String) -> bool:
	if not ok:
		fails += 1
		print("LEGION13 FAIL ", description)
	return ok


func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func resize(pixels: Vector2i) -> void:
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = pixels
	await frames(10)
	check(get_viewport().get_visible_rect().size.is_equal_approx(Vector2(pixels)), "viewport " + str(pixels))


func shot(file: String) -> void:
	await frames(5)
	await RenderingServer.frame_post_draw
	var path := output.path_join(file + ".png")
	if check(get_viewport().get_texture().get_image().save_png(path) == OK, "save " + file):
		print("LEGION13 SHOT ", path)


func _run() -> void:
	for _elapsed in 3600:
		if game.ready_done:
			break
		await frames(5)
	if not check(game.ready_done, "game ready"):
		return
	game.settings["autosave"] = false
	game.hud.set_speed(0.0)
	game.city.legion_v = 3
	game.city.cozy_v = 1
	lg = game.city.legion
	lg.sync_v2()
	Legion.clock = 1900000000.0
	lg.flags["camp_open"] = true
	camp = CampUI.attach(game.hud)
	camp.open()
	await resize(Vector2i(1920, 1080))
	lg.flags["fort_guide"] = Legion.FortGuide.FINISH
	lg.finish_fort_guide()
	if not check(lg.squad_count() == 2 and not lg.hero_dweller().is_empty(), "starter squad"):
		return
	await _portrait_cache()
	_market_numbers()
	await _screens()


func _art(parent: Node) -> Array[Node]:
	if not is_instance_valid(parent):
		return []
	return parent.find_children("FortPortraitArt", "TextureRect", true, false)


func _wait_art(art: Array[Node], context: String) -> bool:
	for i in 420:
		if art.all(func(node: Node): return is_instance_valid(node) and bool(node.get_meta("portrait_ready", false))):
			return true
		await frames(1)
	return check(false, "portrait render " + context)


func _verify_art(parent: Node, count: int, context: String) -> void:
	var art := _art(parent)
	if check(art.size() >= count, "portrait count " + context + " " + str(art.size())):
		await _wait_art(art, context)
		for rect: TextureRect in art:
			check(rect.has_meta("person_portrait") and (rect.texture is ImageTexture), "person texture " + context)


func _portrait_cache() -> void:
	var stand := HBoxContainer.new()
	stand.position = Vector2(-2000, -2000)
	add_child(stand)
	var people: Array[Dictionary] = [
		{"id": 451, "look": {"female": false, "skin": "A", "hair": 4, "hair_color": "A", "beard": 3}},
		{"id": 452, "look": {"female": true, "skin": "C", "hair": 5, "hair_color": "C", "beard": 0}}]
	for person: Dictionary in [people[0], people[1], people[0]]:
		stand.add_child(Person.portrait(person, 60))
	stand.add_child(Person.portrait(people[0], 60, [Gear.craft_item("helmet", 1)]))
	stand.add_child(Person.portrait(Person.hero_person(lg), 60))
	var art := _art(stand)
	if await _wait_art(art, "cache"):
		var a: Texture2D = art[0].texture
		var b: Texture2D = art[1].texture
		check(a != b and a.get_image().get_data() != b.get_image().get_data(), "two people have different images")
		check(a == art[2].texture, "same look shares cached texture")
		check(a != art[3].texture and a.get_image().get_data() != art[3].texture.get_image().get_data(), "helmet changes portrait pixels")
		check(bool(art[3].get_meta("portrait_loadout")["helmet"]), "helmet in portrait loadout")
		check(int(art[4].get_meta("portrait_crown")) > 0, "hero wreath in portrait")
	var service: Node = get_tree().root.get_node("FortPortraits")
	if check(service != null, "portrait render service"):
		var usec: int = service.work_usec
		var start := Engine.get_process_frames()
		var backlog := HBoxContainer.new()
		stand.add_child(backlog)
		for i in 20:
			var p := {"id": 7000 + i, "look": {"female": false, "skin": ["A", "B", "C"][i % 3], "hair": i % 8,
				"hair_color": ["A", "B", "C", "S"][i % 4], "beard": i % 5}}
			backlog.add_child(Person.portrait(p, 60))
		var render_queue: Dictionary = service._pending
		check(render_queue.size() >= 20, "20 different portraits queued")
		await _wait_art(_art(backlog), "20 queued")
		var elapsed := maxi(1, Engine.get_process_frames() - start)
		var mean := (int(service.work_usec) - usec) / (elapsed * 1000.0)
		print("LEGION13 PORTRAIT average_ms=%.3f frames=%d" % [mean, elapsed])
		check(mean <= 2.0, "average portrait render budget")
		check((service._cache as Dictionary).size() <= 64, "bounded portrait cache")
	stand.queue_free()


func _market_numbers() -> void:
	var saved := lg.to_dict().duplicate(true)
	lg.flags["fort_lessons"] = {}
	lg.fort["money"] = 0.0
	lg.rations = 0.0
	lg.watch_fort_lessons()
	check(lg.fort_lesson_state("market") == "", "lesson waits for money")
	lg.fort["money"] = lg.money_cap() * 0.8
	lg.watch_fort_lessons()
	check(lg.fort_lesson_state("market") == "pending", "lesson when restocking is possible")
	camp.show_market()
	check(lg.fort_lesson_state("market") == "done", "market opens from the lesson")
	camp._close_modal()
	var price := lg.market_quote("rations", 0)
	var before := lg.city_money()
	check(int(price["amount"]) == roundi(lg.ration_cap() * 0.1), "10 percent pack")
	check(lg.market_exchange("rations", 0), "bought food")
	check(lg.rations == float(price["amount"]) and lg.city_money() == before - float(price["price"]), "exact pack and payment")
	check(not lg.market_exchange("rations", 2) and lg.market_quote("rations", 2)["why"] == "Склад полон", "cap blocks purchase")
	var sale := lg.market_quote("rations", 0, true)
	before = lg.city_money()
	check(int(sale["price"]) == floori(float(price["price"]) / 4.0) and lg.market_exchange("rations", 0, true), "sale at quarter price")
	check(lg.rations == 0.0 and lg.city_money() == before + float(sale["price"]), "exact stock and sale proceeds")
	var goods := lg.market_offers().duplicate(true)
	var day := int(goods["day"])
	check(goods["offers"].size() == 4, "four goods")
	check(lg.market_purchase(day, 0), "daily purchase")
	check(not lg.market_purchase(day, 0), "daily purchase once")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(lg.to_dict()))
	lg.from_dict(restored)
	check(JSON.stringify(lg.market_offers()["offers"]) == JSON.stringify(goods["offers"]), "daily goods stable after reload")
	check(not lg.market_purchase(day, 0), "purchase stays redeemed after reload")
	var time := Legion.clock
	Legion.clock += Legion.MARKET_DAY_SECONDS
	check(int(lg.market_offers()["day"]) == day + 1 and lg.market_offers()["bought"].is_empty() and not lg.market_purchase(day, 0), "24 h refresh and stale purchase")
	Legion.clock = time
	saved.erase("market")
	lg.from_dict(saved)
	check(lg.market_offers()["offers"].size() == 4, "old save opens market")
	print("LEGION13 MARKET exchange, caps, sale, daily reload and refresh")


func _screens() -> void:
	lg.flags["fort_lessons_off"] = true
	Fixture.set_level(lg, "hq", 3)
	Fixture.set_level(lg, "barracks", 2)
	var barracks := int(lg.fort_slot_plot("barracks")["id"])
	Fixture.gate(lg, 3)
	var trainee := Fixture.recruit(lg, false)
	check(not trainee.is_empty() and lg.fort_assign(barracks, int(trainee.get("id", 0))), "barracks fixture")
	check(not Fixture.recruit(lg, false).is_empty(), "available trainee fixture")
	lg.rations = 325.0
	lg.fort["money"] = minf(6500.0, lg.money_cap() * 0.76)
	lg.mats["wood"] = roundi(lg.resource_cap("wood") / 2.0)
	lg.mats["iron"] = lg.resource_cap("iron")
	lg.mats["leather"] = roundi(lg.resource_cap("leather") * 0.17)
	camp._refresh()

	game.hud.hero_btn_refresh()
	var hero := game.hud.hero_btn.get_node("ic") as TextureRect
	await _wait_art([hero], "city hero")
	check(int(hero.get_meta("portrait_crown", 0)) > 0, "top-right hero medallion")
	await _verify_art(camp.profile_button, 1, "fort hero medallion")

	camp.show_plot(0)
	await _verify_art(camp.card, 2, "HQ")
	camp._campaign()
	camp.lu.open_fort_stage(0, 0, 0)
	await frames(4)
	await _verify_art(camp.lu.overlay, 2, "stage squad")
	_fit(camp.lu.overlay, "1080 stage")
	await shot("1_stage_card_portraits")
	camp.lu.close()
	await _results()

	camp.show_squad()
	await _verify_art(camp.modal_panel, 2, "squad tab")
	_fit(camp.modal_panel, "1080 squad")
	await shot("3_squad_tab")
	camp._close_modal()
	camp.show_plot(barracks)
	await _verify_art(camp.card, 1, "barracks")
	_fit(camp.card, "1080 barracks")
	await shot("4_barracks_card")
	camp.show_worker_picker()
	await _verify_art(camp.modal_panel, 1, "dweller chooser")
	_fit(camp.modal_panel, "1080 chooser")
	await shot("5_dweller_chooser")
	camp.show_people()
	await _verify_art(camp.modal_panel, 3, "dweller list")
	camp.show_recruit_picker()
	await _verify_art(camp.modal_panel, 1, "gate newcomers")

	camp.market_button.pressed.emit()
	await frames(8)
	check(camp.modal_panel.name == &"FortMarketWindow", "market button opens market")
	_fit(camp.modal_panel, "1080 exchange")
	await shot("6_market_exchange")
	var daily := camp.modal_panel.find_child("FortMarketDaily", true, false) as Button
	if check(daily != null, "market goods tab"):
		daily.pressed.emit()
	await frames(7)
	_fit(camp.modal_panel, "1080 goods")
	await shot("7_market_daily")
	camp._close_modal()
	await _pvp()
	camp.open()
	await resize(Vector2i(1280, 720))
	camp.show_squad()
	await frames(8)
	_fit(camp.modal_panel, "720 squad")
	camp.show_plot(barracks)
	await frames(8)
	_fit(camp.card, "720 barracks")
	camp.show_worker_picker()
	await frames(8)
	_fit(camp.modal_panel, "720 chooser")
	camp.show_market(true)
	await frames(8)
	_fit(camp.modal_panel, "720 goods")
	camp.show_market()
	await frames(8)
	_fit(camp.modal_panel, "720 exchange")
	await shot("9_720p_market")


func _results() -> void:
	var setup := lg.make_battle(lg.stage_info(0, 0, 0), 50)
	setup.erase("tutorial")
	var battle := LegionBattle.open(game, setup)
	await frames(8)
	if not check(battle.sim != null, "battle ready for result"):
		battle.abort()
		return
	battle.out = {"win": true, "alive": 2, "total": 2, "stars": 3, "star_mask": 7,
		"reward": {"money": 150, "rations": 300}, "rescued": lg.fort_newcomers().slice(0, 1)}
	battle._show_result()
	await frames(5)
	await _verify_art(battle.modal, 3, "victory and rescued people")
	await shot("2_victory_portraits")
	battle._close_modal()
	battle.out = {"win": false, "alive": 1, "total": 2}
	battle._show_result()
	await frames(6)
	await _verify_art(battle.modal, 2, "defeat")
	battle.abort()
	await frames(5)
	camp.open()


func _pvp() -> void:
	var selected := {"sx": 1, "skin": "C", "hair": 5, "hc": "S", "cape": "2f5585", "main": "4d7397", "crown": 2}
	var snap := {"squad": [{"type": "hero", "level": 3}, {"type": "legionary", "level": 1}]}
	var opponent := {"name": "Капуя", "snapshot": snap, "hero": {"name": "Аврелия", "look": selected}}
	Legion.pvp_hero_srv = true
	var setup := lg.make_pvp_battle(opponent, 93)
	var chosen: Dictionary = setup["enemy_hero_look"]
	check(chosen["hair"] == 5 and chosen["skin"] == "C" and chosen["cape"] == "2f5585", "PvP chosen look from snapshot")
	var fallback := Legion.pvp_rival_look(snap, {"name": "Капуя"})
	check(fallback == Legion.pvp_rival_look(snap, {"name": "Капуя"})
		and fallback != Legion.pvp_rival_look(snap, {"name": "Вейи"}), "stable PvP fallback by name")
	var battle := LegionBattle.open(game, setup)
	await frames(14)
	var found := false
	for view in battle.views.values():
		if view.unit.key == "hero" and view.unit.side == "enemy":
			found = view.actor != null and view.actor.get_meta("look", {}) == chosen
	check(found, "PvP model uses chosen look")
	var strip := HBoxContainer.new()
	strip.position = Vector2(1430, 180)
	battle.ui.add_child(strip)
	LegionPvpView.squad_strip(camp.lu, strip, snap, opponent)
	var frame := strip.find_child("rival_hero", true, false)
	await _verify_art(strip, 2, "PvP squad")
	if check(frame != null, "rival hero medallion"):
		check(_art(frame)[0].get_meta("portrait_look") == chosen, "PvP picture uses the battle look")
	strip.position = Vector2(1430, 178)
	var portrait := Person.rival_portrait(chosen, 115)
	strip.add_child(portrait)
	await _verify_art(portrait, 1, "rival detail")
	await get_tree().create_timer(1.2).timeout
	await shot("8_pvp_rival")
	battle.abort()
	await frames(5)


func _fit(node: Node, context: String) -> void:
	if node is Label and node.is_visible_in_tree() and not node.text.is_empty():
		var label := node as Label
		check(label.get_visible_line_count() == label.get_line_count(), "label height " + context + " " + label.text)
		var parent := label.get_parent()
		while parent is Control and not parent is ScrollContainer:
			parent = parent.get_parent()
		if not parent is ScrollContainer:
			check(get_viewport().get_visible_rect().grow(1.0).encloses(label.get_global_rect()), "label bounds " + context + " " + label.text)
		if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
			var width := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
			check(width <= label.size.x + 2.0, "label width " + context + " " + label.text)
	for child: Node in node.get_children():
		_fit(child, context)
