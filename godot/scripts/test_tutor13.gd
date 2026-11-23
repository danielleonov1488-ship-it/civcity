extends "res://scripts/test_tutor7.gd"

const TestSuite = preload("res://scripts/test_perf14a3_suite.gd")
## Полный путь новой игры, замеры каждого кадра и снимок каждую секунду.

const Task := "D:/CivCity/.work/stage7/tutor13/"
const ViewSize := Vector2i(1280, 720)
const FortStep = Legion.FortGuide

class ArrowTrace:
	var rows := {}
	var current := ""
	var last_pos := Vector2.ZERO
	var last_side := 0.0
	var last_gliding := false
	var last_key := ""
	var last_blocked := 0.0

	func visibility(arrow: TextureRect, key: String, label: String) -> void:
		var next := key if arrow.is_visible_in_tree() else ""
		if next != current:
			if current != "":
				rows[current]["hide"] += 1
			if next != "":
				if not rows.has(next):
					rows[next] = {"target": label, "frames": 0, "show": 0, "hide": 0, "flips": 0, "repicks": 0, "jumps": 0, "max_px": 0.0}
				rows[next]["show"] += 1
			current = next

	func sample(arrow: TextureRect, key: String, label: String, side: float, gliding: bool, blocked: float, dt: float) -> void:
		visibility(arrow, key, label)
		if current != "":
			rows[current]["frames"] += 1
		if current != "" and current == last_key:
			var row: Dictionary = rows[current]
			if not is_equal_approx(side, last_side):
				if last_blocked + dt > 0.5 and is_zero_approx(blocked):
					row["repicks"] += 1
				else:
					row["flips"] += 1
			if not gliding and not last_gliding:
				var distance := arrow.position.distance_to(last_pos)
				row["max_px"] = maxf(row["max_px"], distance)
				if distance > 40.0:
					row["jumps"] += 1
		last_pos = arrow.position
		last_side = side
		last_gliding = gliding
		last_key = current
		last_blocked = blocked

var city_trace := ArrowTrace.new()
var fort_trace := ArrowTrace.new()
var camp: CampUI
var watching := false
var free_play := false
var row_click := false
var violations := {"build_arrow": 0, "build_badge": 0, "idle_arrow": 0, "info_arrow": 0}
var strip_folder := ""
var strip_index := 0
var strip_start := 0
var strip_next := 0
var strip_busy := false


func _ready() -> void:
	await launcher_run("TUTOR13", String(get_meta("perf14_shots", Task + "shots/")),
		String(get_meta("perf14_profiles", Task + "profiles/")))


func finish_run() -> void:
	print(tag + " DONE fails=%d" % fails)
	TestSuite.finish(self, 1 if fails > 0 else 0)


func _process(dt: float) -> void:
	super._process(dt)
	if not watching:
		return
	var id := tut.cur_id()
	city_trace.sample(hud.pointer, _city_arrow_key(), hud.pointer_text.text, hud.pointer.rotation, hud._pointer_draw_gliding, hud._pointer_blocked, dt)
	var point: Dictionary = hud.badges.get("tutorial_target", {})
	if point.get("icon") == "build":
		violations["build_badge"] += 1
	if hud.pointer.is_visible_in_tree():
		if tut.active() and (Defs.B.has(game.tool) or game.is_road_tool(game.tool)):
			violations["build_arrow"] += 1
		if free_play and not row_click:
			violations["idle_arrow"] += 1
		if hud.pointer_target == tut.next_btn:
			violations["info_arrow"] += 1
	if is_instance_valid(camp):
		fort_trace.sample(camp.guide_pointer, _fort_arrow_key(), camp.guide_text.text, float(camp.guide_pointer.flip_v), camp._guide_arrow_draw_gliding, camp._guide_arrow_blocked, dt)
	if strip_start > 0 and Time.get_ticks_msec() >= strip_next and not strip_busy:
		strip_next += 1000
		_save_strip(id)


func _city_arrow_key() -> String:
	return "%s/%d" % [tut.cur_id() if tut.active() else "row", hud._pointer_id]


func _fort_arrow_key() -> String:
	return "%d/%s" % [camp.lg.fort_guide_step(), camp._guide_arrow_id]


func _city_arrow_visibility() -> void:
	city_trace.visibility(hud.pointer, _city_arrow_key(), hud.pointer_text.text)


func _fort_arrow_visibility() -> void:
	fort_trace.visibility(camp.guide_pointer, _fort_arrow_key(), camp.guide_text.text)


func _save_strip(id: String) -> void:
	strip_busy = true
	var index := strip_index
	strip_index += 1
	await RenderingServer.frame_post_draw
	var frame := get_viewport().get_texture().get_image()
	if check(frame.get_size() == ViewSize, "strip source is 1280x720"):
		frame.resize(320, 180, Image.INTERPOLATE_LANCZOS)
		var label := id if tut.cine.is_empty() else "cart_cinematic"
		check(frame.save_jpg(strip_folder.path_join("%03d_%s.jpg" % [index, label]), 0.92) == OK, "save strip frame")
	strip_busy = false


func shot(file: String) -> void:
	if file == "00_hero.png" or file == "01_camera_after_hero.png" or file == "04_arrival.png":
		return
	await frames(3)
	await RenderingServer.frame_post_draw
	var frame := get_viewport().get_texture().get_image()
	var path := out.path_join(file)
	if check(frame.get_size() == ViewSize and frame.save_png(path) == OK, "save " + file):
		print("TUTOR13 SHOT ", path)


func next_frame_step(id: String, previous: String) -> bool:
	await get_tree().process_frame
	var advanced := check(tut.cur_id() == id, previous + " advances within one frame to " + id)
	check(not hud.pointer.visible, previous + " arrow hidden on completion frame")
	if advanced:
		print("TUTOR13 AUTO ", previous, " -> ", id)
	return advanced


func tap_arrow() -> bool:
	var button := hud.pointer_target as Button
	if not check(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled, "clickable target at " + tut.cur_id()):
		return false
	button.pressed.emit()
	await frames(6)
	return true


func tap_map_badge() -> bool:
	for key: String in hud.badges:
		if hud.badges[key]["n"] == hud.pointer_target:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			hud._badge_input(click, key)
			return true
	return check(false, "clickable map badge at " + tut.cur_id())


func select_for_placement(type: String) -> bool:
	for i in 4:
		if game.tool == type:
			return check(not hud.pointer.visible and not hud.badges.has("tutorial_target"), "no guidance during placement of " + type)
		if not await tap_arrow():
			return false
	return check(false, "could not select " + type)


func place_by_click(type: String, near: Vector2) -> bool:
	for z in range(-4, 7, 2):
		for x in range(-4, 7, 2):
			var at := near + Vector2(x, z)
			var placement: Dictionary = game.placement(type, at)
			if placement["err"] != "" or (not placement["noroad"] if type == "house_pleb" else placement.get("sub") != "road"):
				continue
			var world := Vector3(at.x, game.land.height_at(at.x, at.y), at.y)
			var click := InputEventMouseButton.new()
			click.position = game.rig.cam.unproject_position(world)
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			game._input(click)
			if not get_viewport().get_visible_rect().has_point(click.position) or hud.mouse_over_ui():
				continue
			var before := city.next_id
			game.hover = at
			game._unhandled_input(click)
			click.pressed = false
			game._unhandled_input(click)
			game._mouse_pos = Vector2(-1, -1)
			if city.next_id > before:
				return true
	return check(false, "click valid location for " + type)


func until_ms(duration: int) -> void:
	var deadline := Time.get_ticks_msec() + duration
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func aim_placement(at: Vector2) -> void:
	var world := Vector3(at.x, game.land.height_at(at.x, at.y), at.y)
	var motion := InputEventMouseMotion.new()
	motion.position = game.rig.cam.unproject_position(world)
	game._input(motion)


func move_camera() -> void:
	var drag_button := InputEventMouseButton.new()
	drag_button.button_index = MOUSE_BUTTON_RIGHT
	drag_button.pressed = true
	game.rig._unhandled_input(drag_button)
	var drag := InputEventMouseMotion.new()
	for dx: float in [-180.0, 180.0]:
		drag.relative = Vector2(dx, 0.0)
		game.rig._unhandled_input(drag)
	drag_button.pressed = false
	game.rig._unhandled_input(drag_button)


func zoom_camera() -> void:
	var zoom := InputEventMouseButton.new()
	zoom.button_index = MOUSE_BUTTON_WHEEL_UP
	zoom.pressed = true
	game.rig._unhandled_input(zoom)


func run() -> void:
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = ViewSize
	await frames(5)
	var strip_root := Task if out == Task + "shots/" else out.get_base_dir()
	strip_folder = strip_root.path_join("strip_frames/%d" % int(Time.get_unix_time_from_system()))
	if not check(DirAccess.make_dir_recursive_absolute(strip_folder) == OK, "strip directory"):
		return
	print("TUTOR13 STRIP FRAMES ", strip_folder)
	strip_start = Time.get_ticks_msec()
	strip_next = strip_start
	watching = true
	hud.pointer.visibility_changed.connect(_city_arrow_visibility)
	if not await city_route():
		watching = false
		return
	await request_route()
	check_repick()
	await fort_route()
	for reason: String in violations:
		check(violations[reason] == 0, "%s frames = %d" % [reason, violations[reason]])
	print("TUTOR13 ABSENCE ", JSON.stringify(violations))
	report_trace(city_trace, "CITY")
	report_trace(fort_trace, "FORT")
	watching = false


func city_route() -> bool:
	check(tut.cur_id() == "move" and tut.camera_keys.visible and not tut.next_btn.visible, "camera card has no confirm")
	await shot("1_move_card.png")
	await until_ms(1150)
	move_camera()
	await frames(3)
	check(tut.cur_id() == "move", "movement alone does not finish camera")
	zoom_camera()
	if not await next_frame_step("houses", "move"):
		return false
	await frames(12)
	if not await tap_arrow():
		return false
	await shot("2_build_menu_arrow.png")
	await until_ms(1050)
	if not await select_for_placement("house_pleb"):
		return false
	var square := city.door_point(city.center())
	game.rig.set_view(Vector3(square.x - 6.0, Land.BASE_Y, square.y + 19.0), 15, 48, 43)
	await until_ms(500)
	aim_placement(square + Vector2(-13, 12))
	await frames(10)
	check(is_instance_valid(game.ghost) and game.ghost.visible, "ordinary placement ghost is visible")
	await shot("3_placing_no_arrow.png")
	await until_ms(1050)
	for k in 3:
		var count := city.next_id
		if not place_by_click("house_pleb", square + Vector2(-13, 12 + k * 8)):
			return false
		homes.append(city.buildings[count])
		if k < 2:
			await frames(3)
			check(tut.cur_id() == "houses", "three houses required")
	if not await next_frame_step("road", "houses"):
		return false
	await until_ms(1050)
	if not await tap_arrow():
		return false
	if game.tool != "road":
		(hud.road_btns["road"] as Button).pressed.emit()
	await frames(5)
	check(not hud.pointer.visible, "no arrow while using the road brush")
	var bottom := square.y
	for home: Dictionary in homes:
		bottom = maxf(bottom, city.door_point(home).y + 3.0)
	paint_path([square, Vector2(square.x, bottom)])
	for home: Dictionary in homes:
		var door := city.door_point(home)
		paint_path([Vector2(square.x, door.y), door])
	city.compute()
	game.people.refresh(game.land.road_chunks.keys())
	if not await next_frame_step("cart", "road"):
		return false
	game.speed = 8.0
	if not await wait_step("settle", 5000):
		return false
	print("TUTOR13 AUTO cart -> settle")
	game.speed = 0.0
	await until_ms(600)
	if hud.pointer_target is MapBadge:
		if not tap_map_badge():
			return false
	elif not await tap_arrow():
		return false
	await until_ms(300)
	game.rig.set_view(Vector3(square.x - 6.0, Land.BASE_Y, square.y + 10.0), 15, 45, 40)
	await until_ms(500)
	check(hud.pointer_target is MapBadge, "settlement points to an actual house")
	await shot("4_settle.png")
	await until_ms(550)
	if not tap_map_badge() or not await next_frame_step("house", "settle"):
		return false
	game.speed = 8.0
	for frame in 4000:
		if city.settled_total > 0:
			break
		await get_tree().process_frame
	game.speed = 0.0
	await until_ms(650)
	if not tap_map_badge() or not await next_frame_step("house_info", "house"):
		return false
	await until_ms(1050)
	check(tut.hint.visible and tut.next_btn.visible and not hud.pointer.visible, "house icon explanation is informational")
	tut.next_btn.pressed.emit()
	game.rig.set_view(Vector3(square.x - 6.0, Land.BASE_Y, square.y + 19.0), 15, 48, 43)
	await until_ms(500)
	if not await select_for_placement("stall_fruit"):
		return false
	if not place_by_click("stall_fruit", square + Vector2(-5, 14)):
		return false
	if not await next_frame_step("workers", "food"):
		return false
	await until_ms(700)
	await shot("5_hire_plus.png")
	await until_ms(450)
	var plus := hud.pointer_target as Button
	if not check(is_instance_valid(plus) and plus.has_meta("hire_class"), "worker arrow on plus"):
		return false
	plus.pressed.emit()
	if not await next_frame_step("script", "workers"):
		return false
	await until_ms(600)
	if not await select_for_placement("scriptorium"):
		return false
	var count := city.next_id
	if not place_by_click("scriptorium", square + Vector2(-5, 26)):
		return false
	var school: Dictionary = city.buildings[count]
	await until_ms(600)
	check(tut.cur_id() == "script" and not tut.next_btn.visible, "scriptorium also requires a scribe")
	if not city.can_hire(school):
		game.speed = 8.0
		for frame in 5000:
			if not city.arrivals.is_empty():
				break
			await get_tree().process_frame
		game.speed = 0.0
		await until_ms(350)
		if hud.pointer_target is MapBadge:
			if not tap_map_badge():
				return false
		elif not await tap_arrow():
			return false
		await until_ms(450)
		if not tap_map_badge():
			return false
		game.speed = 8.0
		for frame in 5000:
			if city.can_hire(school):
				break
			await get_tree().process_frame
		game.speed = 0.0
		await until_ms(600)
	plus = hud.pointer_target as Button
	if not check(is_instance_valid(plus) and plus.has_meta("hire_class"), "scribe arrow on plus"):
		return false
	plus.pressed.emit()
	if not await next_frame_step("research", "script"):
		return false
	await until_ms(750)
	if not await tap_arrow():
		return false
	await until_ms(600)
	check(hud.pointer_target == hud.research_tree.cheapest_available(), "arrow points at the available study")
	await shot("6_research.png")
	await until_ms(450)
	if not await tap_arrow():
		return false
	var yes: Button = hud.research_tree.confirm_yes
	if not check(hud.pointer_target == yes, "arrow points at confirmation"):
		return false
	await until_ms(550)
	yes.pressed.emit()
	if not await next_frame_step("done", "research"):
		return false
	await until_ms(1050)
	await shot("7_done.png")
	check(tut.next_btn.visible and not hud.pointer.visible, "final card has no arrow")
	tut.next_btn.pressed.emit()
	strip_start = 0
	while strip_busy:
		await get_tree().process_frame
	get_window().size = ViewSize
	check(not tut.active() and not hud.pointer.visible, "tutorial closed")
	return true


func request_route() -> void:
	free_play = true
	hud.close_panels()
	city.rp = city.rp_cap()
	hud._top_action("research")
	await frames(8)
	var study: Button = hud.research_tree.cheapest_available()
	if check(is_instance_valid(study), "manual study available after tutorial"):
		study.pressed.emit()
		await until_ms(350)
		check(hud.research_tree.pending != "" and not hud.pointer.visible and hud._ptr_shown.is_empty(), "ordinary research does not start guidance")
		hud.research_tree.cancel_confirm()
	hud.close_panels()
	game.speed = 1.0
	await until_ms(60000)
	print("TUTOR13 IDLE 60s arrow_frames=", violations["idle_arrow"])
	game.speed = 0.0
	hud.close_panels()
	city.level = 1
	for goal: Dictionary in Defs.REQUESTS:
		if not city.goals_done.has(goal["id"]):
			city.goals_done.append(goal["id"])
		if goal["id"] == "hamlet":
			break
	game.settings["tasks_folded"] = false
	hud.refresh()
	await frames(8)
	var goals := city.active_goals(1)
	if not check(not goals.is_empty(), "request available after tutorial"):
		return
	var row_text: String = goals[0]["text"]
	var row: Button
	for child: Node in hud.tasks_box.get_children():
		if child is MarginContainer:
			for label: Label in child.find_children("*", "Label", true, false):
				if label.text == row_text:
					for button: Node in child.get_children():
						if button is Button:
							row = button
	if not check(is_instance_valid(row) and row.is_visible_in_tree(), "clickable request row"):
		return
	row_click = true
	row.pressed.emit()
	var start := Time.get_ticks_msec()
	await until_ms(350)
	check(hud.pointer.visible, "row click shows the pointer")
	await until_ms(Hud.PTR_SHOW_MS - 750)
	check(hud.pointer.visible, "row pointer persists until its timeout")
	while hud.pointer.visible and Time.get_ticks_msec() - start < Hud.PTR_SHOW_MS + 1000:
		await get_tree().process_frame
	var elapsed := Time.get_ticks_msec() - start
	check(not hud.pointer.visible and absi(elapsed - Hud.PTR_SHOW_MS) <= 750, "row timeout %d ms" % elapsed)
	print("TUTOR13 ROW duration_ms=", elapsed)
	row_click = false
	await until_ms(350)


func check_repick() -> void:
	var probe := Control.new()
	hud.root.add_child(probe)
	probe.size = Vector2(60, 32)
	probe.position = Vector2(600, 230)
	hud._place_tutorial_pointer(probe, Vector2.INF, 0.0)
	var initial := hud._pointer_side
	probe.position.y = -48.0
	hud._place_tutorial_pointer(probe, Vector2.INF, 0.49)
	check(initial == Vector2.UP and hud._pointer_side == initial, "initial side held for 0.49 seconds off-screen")
	hud._place_tutorial_pointer(probe, Vector2.INF, 0.02)
	check(hud._pointer_side == Vector2.DOWN and is_zero_approx(hud._pointer_progress), "side re-picked with glide after 0.5 seconds off-screen")
	if initial != hud._pointer_side:
		print("TUTOR13 REPICK held_ms=490 repicked_ms=510")
	probe.queue_free()


func fort_route() -> void:
	city.legion_v = 3
	city.cozy_v = 1
	var legion := city.legion
	legion.sync_v2()
	var old_clock := Legion.clock
	Legion.clock = 1900000000.0
	legion.flags["camp_open"] = true
	camp = CampUI.attach(hud)
	camp.guide_pointer.visibility_changed.connect(_fort_arrow_visibility)
	camp.open()
	await until_ms(650)
	if not check(legion.fort_guide_step() == FortStep.FIRST_BATTLE and camp.guide_pointer.is_visible_in_tree(), "fort starts with the battle"):
		Legion.clock = old_clock
		return
	camp.campaign_button.pressed.emit()
	await until_ms(650)
	if not check(is_instance_valid(camp.lu.guide_stage_button) and camp.guide_pointer.is_visible_in_tree(), "fort map guide"):
		Legion.clock = old_clock
		return
	camp.lu.guide_stage_button.pressed.emit()
	await until_ms(650)
	if not check(is_instance_valid(camp.lu._fight_btn) and camp.guide_pointer.is_visible_in_tree(), "fort fight guide"):
		Legion.clock = old_clock
		return
	camp.lu._fight_btn.pressed.emit()
	await frames(6)
	var battle := LegionBattle.current
	if is_instance_valid(battle):
		battle.speed = 8.0
		var deadline := Time.get_ticks_msec() + 60000
		while is_instance_valid(battle) and battle.phase != "result" and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
	if not check(is_instance_valid(battle) and battle.phase == "result" and bool(battle.out.get("win", false)), "fort battle won"):
		Legion.clock = old_clock
		return
	var back := battle.find_child("LegionBattleReturn", true, false) as Button
	if not check(back != null, "return to fort"):
		Legion.clock = old_clock
		return
	back.pressed.emit()
	await until_ms(1050)
	if check(legion.fort_guide_step() == FortStep.TREASURY, "fort second step") and await fort_room("treasury"):
		check(legion.fort_guide_step() == FortStep.KITCHEN, "fort third step")
		await fort_room("kitchen")
	await until_ms(350)
	camp.close()
	await frames(3)
	Legion.clock = old_clock


func fort_room(type: String) -> bool:
	var arrivals := camp.lg.fort_newcomers()
	if not check(not arrivals.is_empty() and camp.guide_pointer.is_visible_in_tree(), "guided newcomer for " + type):
		return false
	var sid := int(arrivals[0]["id"])
	var room := int(camp.lg.fort_slot_plot(type)["id"])
	var view := camp.diorama as FortCutaway
	view.begin_person_move(sid, true, view.person_project(sid, true))
	view.update_person_move(view.project(room))
	await until_ms(550)
	check(camp.guide_pointer.is_visible_in_tree(), "guided room " + type)
	if not check(view.finish_person_move(view.project(room)), "place fort worker " + type):
		return false
	await until_ms(600)
	camp.show_dweller(sid)
	await until_ms(550)
	var slot := camp.modal_panel.find_child("FortGear_outfit", true, false) as Button
	if not check(slot != null and camp.guide_pointer.is_visible_in_tree(), "guided fort outfit " + type):
		return false
	slot.pressed.emit()
	await until_ms(550)
	var outfit := int(camp.lg.flags.get("fort_guide_item", 0))
	var option := camp.modal_panel.find_child("FortEquip_%d" % outfit, true, false) as Button
	if not check(option != null, "choose fort outfit " + type):
		return false
	option.pressed.emit()
	await until_ms(550)
	if int(camp.lg.item(outfit).get("on", 0)) != sid:
		var equip := camp.modal_panel.find_child("FortItemEquip", true, false) as Button
		if not check(equip != null, "equip fort outfit " + type):
			return false
		equip.pressed.emit()
		await until_ms(550)
	var collect: Button = camp.plot_markers.get(room, {}).get("collect")
	if not check(collect != null and camp.guide_pointer.is_visible_in_tree(), "guided fort collect " + type):
		return false
	collect.pressed.emit()
	await until_ms(550)
	return true


func report_trace(trace: ArrowTrace, context: String) -> void:
	check(not trace.rows.is_empty(), context + " observed arrow targets")
	for target: String in trace.rows:
		var result: Dictionary = trace.rows[target]
		print("TUTOR13 METRIC ", context, " ", target, " ", JSON.stringify(result))
		check(result["show"] <= 1 and result["hide"] <= 1, context + " visibility " + target)
		check(result["flips"] == 0, context + " stable side " + target)
		check(result["jumps"] == 0, context + " smooth motion " + target)
