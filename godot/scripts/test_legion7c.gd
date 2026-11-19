extends Node3D
## Обычные действия форта. Часы двигаем вручную, сохранение проверяем в памяти.

const Step = Legion.FortGuide
var suite := "LEGION7C"
var out := "D:/CivCity/.work/stage6/legion7c/shots/"
var game: Game
var camp: CampUI
var lg: Legion
var fails := 0
var previous_clock := -1.0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=").trim_suffix("/") + "/"
	Game.boot = {"new": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	add_child(game)
	game.can_save = false
	previous_clock = Legion.clock
	await _run()
	Legion.clock = previous_clock
	print(suite, " DONE fails=", fails)
	get_tree().quit(0 if fails == 0 else 1)


func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func check(ok: bool, message: String) -> bool:
	if not ok:
		fails += 1
		print(suite, " FAIL ", message)
	return ok


func shot(file: String, step: int, target: Control = null, person := -1, newcomer := false, drop_plot := -1) -> void:
	await frames(8)
	if not camp.lu.visible:
		camp._layout_guide()
	await frames(2)
	check(lg.fort_guide_step() == step, file + " step")
	var arrows := game.hud.root.find_children("FortGuideArrow", "TextureRect", true, false)
	var shown := 0
	for arrow: Control in arrows:
		shown += int(arrow.is_visible_in_tree())
	var active := step != Step.DONE
	check(shown == int(active), file + " visible arrow count")
	check(camp.guide.is_visible_in_tree() == active and not game.hud.pointer.visible, file + " guide only")
	if active:
		if target != null:
			check(camp._guide_target == target and target.is_visible_in_tree(), file + " arrow control")
			check(camp._guide_rect.is_equal_approx(target.get_global_rect()), file + " target bounds")
		elif drop_plot >= 0:
			var view := camp.diorama as FortCutaway
			var room := view.plot_footprint(drop_plot)
			var expected := Rect2(view.global_position + room.position, room.size)
			check(view.drag_sid > 0 and camp._guide_target == null and room.has_area()
				and camp._guide_rect.is_equal_approx(expected), file + " arrow on room footprint")
		elif person > 0 and camp.diorama is FortCutaway:
			var view := camp.diorama as FortCutaway
			var point := view.global_position + view.person_project(person, newcomer)
			check(camp._guide_rect.get_center().distance_to(point) < 3.0, file + " arrow on person")
		else:
			check(false, file + " target missing")
		check(get_viewport().get_visible_rect().grow(1).encloses(camp._guide_rect), file + " target on screen")
		var rect := camp.guide_pointer.get_global_rect()
		var tip_y := rect.position.y if camp.guide_pointer.flip_v else rect.end.y
		var edge := camp._guide_rect.end.y if camp.guide_pointer.flip_v else camp._guide_rect.position.y
		check(absf(tip_y - edge) <= 4.0 and absf(rect.get_center().x - camp._guide_rect.get_center().x) <= 4.0, file + " arrow tip")
		for line: String in camp.guide_text.text.split("\n"):
			check(line.length() <= 60, file + " short copy")
	await intro_capture(file)


func intro_capture(file: String) -> void:
	await RenderingServer.frame_post_draw
	var path := out + file + ".png"
	if check(get_viewport().get_texture().get_image().save_png(path) == OK, "save " + file):
		print(suite, " SHOT ", path)


func press(button: Button, message: String) -> bool:
	if not check(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled, message):
		return false
	button.pressed.emit()
	return true


func click_person(sid: int, newcomer := false) -> void:
	var view := camp.diorama as FortCutaway
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = view.person_project(sid, newcomer)
	view._gui_input(event)
	event.pressed = false
	event.position = view.get_global_transform_with_canvas() * event.position
	view._input(event)


func save_round_trip() -> Dictionary:
	return JSON.parse_string(JSON.stringify(lg.to_dict())) as Dictionary


func _run() -> void:
	var waited := 0
	while not game.ready_done and waited < 18000:
		await frames(5)
		waited += 5
	if not check(game.ready_done, "ready_done timeout"):
		return
	if not check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory"):
		return
	game.can_save = false
	game.settings["autosave"] = false
	game.hud.set_speed(0.0)
	var city := game.city
	city.cozy_v = 1
	city.legion_v = 3
	city.hero = {}
	city.tips["tut"] = 0
	lg = city.legion
	Legion.clock = Time.get_unix_time_from_system()
	lg.fort = {}
	lg.camp = {}
	lg.flags.erase("camp3d_guide")
	lg.flags.erase("fort_guide")
	lg.flags.erase("chest_start")
	lg.flags["camp_open"] = true
	lg.flags["camp_told"] = true
	lg.soldiers.clear()
	lg.items.clear()
	lg.squad3 = [0, 0, 0, 0, 0]
	lg.rations_t = 0.0
	lg.army_tick()
	camp = CampUI.of(game.hud)
	if not check(camp != null and game.hud.tutorial_busy(), "camp with active city tutorial"):
		return
	camp.open()
	await frames(8)
	var arrivals := lg.fort_newcomers()
	if not check(camp.diorama is FortCutaway and arrivals.size() == 1, "arrived without waiting"):
		return
	var sid := int(arrivals[0]["id"])
	await shot("01_gate", Step.RECRUIT, null, sid, true)
	click_person(sid, true)
	await frames(4)
	if not check(is_instance_valid(camp.modal_panel), "gate card opened"):
		return
	var accept := camp.modal_panel.find_child("FortAccept", true, false) as Button
	await shot("01_accept", Step.RECRUIT, accept)
	if not press(accept, "accept recruit"):
		return
	check(not lg.soldier(sid).is_empty() and not is_instance_valid(camp.modal), "accepted, courtyard visible")
	await shot("02_build", Step.KITCHEN, camp.build_button)
	if not press(camp.build_button, "open building menu"):
		return
	await frames(4)
	var kitchen_button := camp.build_cards.get("kitchen", {}).get("button") as Button
	await shot("02_kitchen_card", Step.KITCHEN, kitchen_button)
	if not press(kitchen_button, "choose kitchen"):
		return
	var first_plot := lg.fort_empty_plot()
	var hammer: Button = camp.plot_markers[first_plot]["button"]
	await shot("02_place_kitchen", Step.KITCHEN, hammer)
	if not press(hammer, "place kitchen"):
		return
	var kitchen := lg.fort_slot_plot("kitchen")
	if not check(not kitchen.is_empty() and not (kitchen["up"] as Dictionary).is_empty(), "real construction"):
		return
	var kitchen_id := int(kitchen["id"])
	Legion.clock = float(kitchen["up"]["end"]) + 0.1
	lg.fort_finish()
	camp._refresh()
	await shot("02_drag_to_kitchen", Step.KITCHEN, null, sid)
	var view := camp.diorama as FortCutaway
	view.begin_person_move(sid, false, view.person_project(sid))
	await shot("02_drop_kitchen", Step.KITCHEN, null, -1, false, kitchen_id)
	if not check(view.finish_person_move(view.project(kitchen_id)), "drop in kitchen"):
		return
	var bread: Button = camp.plot_markers[kitchen_id]["collect"]
	var rations_chip: Button = camp.resource_bars["rations"]["plus"]
	await shot("03_cooking", Step.RATIONS, rations_chip)
	check(bread.disabled, "batch cannot be collected at once")
	var during := save_round_trip()
	var before_load := lg.rations
	var reserved := float(during["flags"]["fort_guide_rations"])
	camp.close()
	await frames(2)
	# Продолжаем на копии, чтобы флаги в снимке остались на шаге готовки.
	lg.from_dict(during.duplicate(true))
	camp.open()
	bread = camp.plot_markers[kitchen_id]["collect"]
	await shot("03_resumed", Step.RATIONS, rations_chip)
	check(is_equal_approx(lg.rations, before_load) and lg.fort_worker_plot(sid) == kitchen_id, "loaded worker and rations")
	Legion.clock += Legion.FORT_GUIDE_COOK_SECS - 1.0
	lg.fort_finish()
	camp._refresh()
	check(bread.disabled, "full batch still takes about 20 seconds")
	Legion.clock += 1.1
	lg.fort_finish()
	camp._refresh()
	await shot("03_collect", Step.RATIONS, rations_chip)
	if not press(rations_chip, "collect rations"):
		return
	check(is_equal_approx(lg.rations - before_load, float(Legion.FORT_GUIDE_BATCH)), "first batch adds rations")
	await shot("04_chests", Step.CHEST, camp.chest_button)
	if not press(camp.chest_button, "open chest window"):
		return
	if not check(is_instance_valid(camp.modal_panel), "chest window shown"):
		return
	var chest := camp.modal_panel.find_child("FortChest_wooden", true, false) as Button
	await shot("04_wooden", Step.CHEST, chest)
	if not press(chest, "preview starter chest"):
		return
	var confirm_chest := camp.modal_panel.find_child("FortChestOpen", true, false) as Button
	if not press(confirm_chest, "open starter chest"):
		return
	var iid := int(lg.flags.get("fort_guide_item", 0))
	if not check(not lg.item(iid).is_empty() and not lg.chest_queue.has("wooden") and is_instance_valid(camp.modal_panel), "starter item received"):
		return
	var back := camp.modal_panel.find_child("FortChestBack", true, false) as Button
	await shot("04_reward", Step.EQUIP, back)
	if not press(back, "return from reward"):
		return
	await shot("05_dweller", Step.EQUIP, null, sid)
	click_person(sid)
	await frames(4)
	if not check(is_instance_valid(camp.modal_panel), "dweller card opened"):
		return
	var equip := camp.modal_panel.find_child("FortEquip_%d" % iid, true, false) as Button
	await shot("05_equip", Step.EQUIP, equip)
	if not press(equip, "equip starter item"):
		return
	check(int(lg.item(iid).get("on", 0)) == sid, "item worn by recruit")
	await shot("06_barracks", Step.BARRACKS, null, sid)
	view = camp.diorama as FortCutaway
	view.begin_person_move(sid, false, view.person_project(sid))
	var barracks := int(lg.fort_slot_plot("barracks")["id"])
	await shot("06_drop_barracks", Step.BARRACKS, null, -1, false, barracks)
	if not check(view.finish_person_move(view.project(barracks)), "drop in barracks"):
		return
	check(lg.fort_is_fighter(sid) and lg.squad3.has(sid), "recruit joins battle squad")
	await shot("07_campaign", Step.CAMPAIGN, camp.campaign_button)
	if not press(camp.campaign_button, "open campaign"):
		return
	await frames(5)
	if not check(is_instance_valid(camp.lu.fort_map), "full-screen tutorial map"):
		return
	var first_stage := camp.lu.fort_map.find_child("LegionFirstStage", true, false) as Button
	await shot("07_stage_one", Step.CAMPAIGN, first_stage)
	if not press(first_stage, "select first stage"):
		return
	var fight := camp.lu._fight_btn
	if not check(is_instance_valid(fight), "fight action exists"):
		return
	var cost := float(fight.get_meta("ration_cost", -1.0))
	check(cost > 0.0 and fight.text.contains("%.1f" % cost), "battle button shows ration cost")
	await shot("07_first_battle", Step.CAMPAIGN, fight)
	var before_fight := lg.rations
	if not press(fight, "start first battle"):
		return
	check(is_equal_approx(before_fight - lg.rations, cost), "first fight consumes rations")
	var battle := LegionBattle.current
	if not check(is_instance_valid(battle), "battle scene opened"):
		return
	battle.speed = 8.0
	var deadline := Time.get_ticks_msec() + 90000
	while is_instance_valid(battle) and battle.phase != "result" and Time.get_ticks_msec() < deadline:
		await frames(4)
	if not check(is_instance_valid(battle) and battle.phase == "result", "first battle result"):
		if is_instance_valid(battle):
			battle.abort()
		return
	var return_button := battle.find_child("LegionBattleReturn", true, false) as Button
	if not press(return_button, "return after first battle"):
		battle.abort()
		return
	deadline = Time.get_ticks_msec() + 5000
	while not camp.visible and Time.get_ticks_msec() < deadline:
		await frames(4)
	if not check(camp.visible, "battle returns to fort"):
		return
	await shot("08_treasury", Step.FINISH, camp.order_button)
	_before_finish()
	if not press(camp.guide_next, "acknowledge last step"):
		return
	await shot("08_complete", Step.DONE)
	await _after_intro(during, before_load, reserved)


func _before_finish() -> void:
	lg.flags["fort_lessons_off"] = true


func _after_intro(during: Dictionary, before_load: float, reserved: float) -> void:
	camp.close()
	lg.from_dict(during.duplicate(true))
	camp.open()
	await frames(6)
	check(lg.fort_guide_step() == Step.RATIONS and camp.guide_pointer.is_visible_in_tree(), "skip starts on active rations step")
	if not press(camp.guide_skip, "skip an active step"):
		return
	check(lg.fort_guide_step() == Step.DONE and not camp.guide_pointer.is_visible_in_tree(), "skip hides arrow immediately")
	check(camp._guide_target == null and not camp._guide_rect.has_area(), "skip clears guide target")
	check(is_equal_approx(lg.rations, before_load + reserved), "skip restores reserved rations")
	var skipped := save_round_trip()
	camp.close()
	lg.from_dict(skipped)
	camp.open()
	await shot("09_skipped_reload", Step.DONE)
