extends "res://scripts/test_uni6_support.gd"
## Вся цепочка через обычные игровые действия; шаги тест не переставляет.

var tut: Tutorial
var homes: Array[Dictionary] = []
var saw_arrival := false


func _ready() -> void:
	if not await boot_run("TUTOR6", "D:/CivCity/.work/stage6/tutor8/shots/tutor6/", "D:/CivCity/.work/stage6/tutor8/profiles"):
		finish_run()
		return
	tut = game.tutorial
	await run()
	finish_run()


func wait_step(id: String, limit := 3600) -> bool:
	for i in limit:
		if tut.cur_id() == id and tut.cine.is_empty():
			return true
		check(not hud.advisor_panel.visible and not hud.notes_box.is_visible_in_tree(), "one voice while waiting for " + id)
		if not tut.cine.is_empty() and not saw_arrival:
			saw_arrival = true
			check(tut.cur_id() in ["road", "cart"] and city.has_connected_house(), "arrival only after connected home")
			await shot("04_arrival.png")
		await get_tree().process_frame
	return check(false, "step " + id + " timed out at " + tut.cur_id())


func expected_target(id: String) -> Control:
	match id:
		"move":
			return tut.camera_keys if tut.next_btn.disabled else tut.next_btn
		"road":
			return hud.badges["tutorial_target"]["n"] if game.tool == "road" and tut._road_chosen else hud.road_target()
		"houses":
			return hud._card_or_cat("housing", "house_pleb")
		"house":
			if tut._house_seen:
				return tut.next_btn
			return hud.badges["tutorial_target"]["n"] if hud.badges.has("tutorial_target") else null
		"cart":
			return hud.badges["tutorial_target"]["n"] if hud.badges.has("tutorial_target") else null
		"settle":
			return hud._do_target({"kind": "fam"})
		"food":
			return hud._card_or_cat("commerce", "stall_fruit")
		"workers":
			return hud.info_box.find_child("hire_plus", true, false) as Control
		"script":
			return hud._card_or_cat("farming", "scriptorium")
		"research":
			return hud.top_btns["research"]
		"done":
			return tut.next_btn
	return null


func snapshot_step(id: String) -> bool:
	if not await wait_step(id):
		return false
	game.speed = 0.0
	hud._update_pointer()
	await frames(10)
	await check_arrow_frames(id)
	tut.layout()
	var target: Control = hud.pointer_target
	check(I18n.t(tut.text.text).length() <= 60, id + " translated step is short")
	check(tut.text.get_theme_font("font").get_string_size(I18n.t(tut.text.text), HORIZONTAL_ALIGNMENT_LEFT, -1, tut.text.get_theme_font_size("font_size")).x <= tut.text.size.x + 1.0, id + " complete step text fits")
	check(is_instance_valid(target) and target == expected_target(id), id + " expected pointer target")
	if id in ["cart", "house"]:
		check(not hud._pointer_badge.is_empty() and hud._pointer_badge["n"] == target, id + " world anchor")
	check(not hud.badges.has("quest_target"), id + " no story pointer")
	check(not hud.advisor_panel.visible and not hud.notes_box.is_visible_in_tree(), id + " no competing advisor/toast")
	var legion := LegionUi.of(hud)
	check(legion == null or not legion.tut_active(), id + " no Legion tutorial")
	check(game.stories.pointer_do().is_empty(), id + " no story instruction")
	check(tut.card.size.x <= 420.0, id + " compact tutorial")
	if is_instance_valid(target):
		check(target.is_visible_in_tree(), id + " actionable target is visible")
		check(tut.card.is_ancestor_of(target) or not tut.card.get_global_rect().intersects(target.get_global_rect()), id + " card clears target")
	check(tut.text.text.length() <= 60 and I18n.t(tut.text.text).length() <= 60, id + " short instruction")
	inspect_panel(tut.card)
	var data := city.save_data()
	check(Tutorial.saved_step(data.get("tips", {})) == Tutorial.step_index(id), id + " saves current step")
	await shot("%02d_%s.png" % [Tutorial.step_index(id) + 1, id])
	return true


func build_near(type: String, near: Vector2) -> Dictionary:
	game.set_tool(type)
	for z in range(-4, 7, 2):
		for x in range(-4, 7, 2):
			var pl: Dictionary = game.placement(type, near + Vector2(x, z))
			if String(pl.get("err", "")) == "" and (bool(pl.get("noroad", false)) if type == "house_pleb" else String(pl.get("sub", "")) == "road"):
				var b := city.place(type, pl["pos"], pl["yaw"], pl["variant"], pl["color"])
				if not b.is_empty():
					hud.on_workplace_built(b)
					game.set_tool("")
					return b
	check(false, "valid placement " + type)
	game.set_tool("")
	return {}


func run() -> void:
	check(Tutorial.saved_step({"tut": 1}) == Tutorial.step_index("move"), "old turn maps to camera")
	for i in Tutorial.OLD_IDS.size():
		check(Tutorial.saved_step({"tut": i}) == Tutorial.step_index(Tutorial.OLD_IDS[i]), "old save index %d" % i)
	check(Tutorial.saved_step({"tut": 8, "tut_id": ""}) == Tutorial.step_index("workers"), "empty old id falls back to number")
	check(Tutorial.saved_step({"tut": -1}) == -1, "skip remains skipped on load")
	for s: Dictionary in Tutorial.STEPS:
		check(String(s["text"]).length() <= 60 and String(s["title"]).length() <= 60, "short step " + String(s["id"]))
	clear_guidance()
	# Чужой совет, всплывашка и будущие магистратуры ждут окончания цепочки.
	hud.advisor("Работа в новом здании", "Работников добавляют кнопкой «+» в карточке здания. Кнопка «−» освобождает место.", Callable(), true)
	hud._toast("Первые переселенцы прибыли в ваш город!", "family")
	check(hud.guidance_queue.size() == 2, "advisor and toast queued")
	check(not MagisUI.advise(hud), "magistracy waits for tutorial")
	var old_level := city.level
	city.level = 1
	check(not MagisUI.advise(hud) and not city.tips.has("magis_open_censura"), "new magistracy advice remains pending")
	city.level = old_level
	check(not game.stories._offer_first(false), "story offer waits for tutorial")
	var legion := LegionUi.of(hud)
	check(legion == null or legion.tut_pointer()[0] == null, "Legion pointer suppressed")
	hud.rank_btn.show()
	hud._update_pointer()
	check(hud.pointer_target == expected_target("move"), "rank pointer yields to tutorial")
	hud.rank_btn.hide()
	if not await snapshot_step("move"):
		return
	check(not tut._check("move"), "camera needs movement and zoom")
	if tut._step_age < 3.0:
		tut.next_btn.pressed.emit()
		check(tut.cur_id() == "move" and tut._wait == 0.0, "camera minimum three seconds applies to confirm")
	# Обычный правый drag: через тот же обработчик, что у игрока.
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_RIGHT
	down.pressed = true
	game.rig._unhandled_input(down)
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(30, 0)
	game.rig._unhandled_input(drag)
	down.pressed = false
	game.rig._unhandled_input(down)
	await get_tree().create_timer(3.1).timeout
	check(tut.cur_id() == "move" and not tut._check("move"), "one accidental right-drag never skips camera")
	var zoom := InputEventMouseButton.new()
	zoom.button_index = MOUSE_BUTTON_WHEEL_UP
	zoom.pressed = true
	game.rig._unhandled_input(zoom)
	check(not tut._check("move"), "one drag and one zoom still need twelve metres")
	down.pressed = true
	game.rig._unhandled_input(down)
	for dx: float in [-180.0, 180.0]:
		drag.relative = Vector2(dx, 0)
		game.rig._unhandled_input(drag)
	down.pressed = false
	game.rig._unhandled_input(down)
	if not await snapshot_step("houses"):
		return
	var dp: Vector2 = city.door_point(city.center())
	await choose_build("housing", "house_pleb", "02_houses")
	for k in 3:
		var home := build_near("house_pleb", dp + Vector2(-13, 12 + k * 8))
		if home.is_empty():
			return
		homes.append(home)
		city._tick_arrivals()
		check(city.incoming == 0 and city.arrivals.is_empty(), "no arrivals before first connected house")
		check(not city.can_host(home, {"cls": "plebs", "n": 2}), "no-road home cannot be settled")
		hud._update_world_icons()
		check(hud.world_icons.has(int(home["id"])) and hud.world_icons[int(home["id"])][0] == "road", "no_road badge on house")
	# Старое сохранение с уже построенными домами не теряет постройки.
	var current_tips := city.tips.duplicate(true)
	city.tips = {"tut": -1}
	city._tick_arrivals()
	check(city.incoming == 0, "skipped tutorial also waits for first connection")
	city.tips = {"tut": 2, "tut_id": "road"}
	check(Tutorial.resume_step(city) == Tutorial.step_index("road") and homes.size() == 3, "old road save keeps houses")
	city.tips = current_tips
	if not await snapshot_step("road"):
		return
	check(not tut._check("road"), "three houses alone do not finish road step")
	(hud.pointer_target as Button).pressed.emit()
	hud._update_pointer()
	await frames()
	await pointer_shot(hud.road_btns["road"], "03_road_card.png")
	(hud.pointer_target as Button).pressed.emit()
	hud._update_pointer()
	await frames()
	check(tut._road_chosen and game.tool == "road", "explicit cobblestone choice")
	await pointer_shot(hud.badges["tutorial_target"]["n"], "03_road_place.png")
	# Отдельный кусок у двери не соединяет дом с площадью.
	var door := city.door_point(homes[0])
	paint_path([door - Vector2(0.7, 0), door + Vector2(0.7, 0)])
	city.compute()
	city._tick_arrivals()
	check(not city.house_connected(homes[0]) and not tut._check("road") and city.incoming == 0, "isolated road cannot dispatch first cart")
	var bottom := dp.y
	for home: Dictionary in homes:
		bottom = maxf(bottom, city.door_point(home).y + 3.0)
	paint_path([dp, Vector2(dp.x, bottom)])
	for home: Dictionary in homes:
		var to := city.door_point(home)
		paint_path([Vector2(dp.x, to.y), to])
	city.compute()
	game.people.refresh(game.land.road_chunks.keys())
	game.set_tool("")
	check(city.has_connected_house(), "road reaches houses from square")
	if not await snapshot_step("cart"):
		return
	game.speed = 8.0
	if not await snapshot_step("settle"):
		return
	var family_button := hud._do_target({"kind": "fam"}) as Button
	if not check(family_button != null, "family medallion"):
		return
	family_button.pressed.emit()
	hud._update_pointer()
	await frames()
	var fitting: Array = city.homes_for(game.settle_fam)
	check(fitting.size() == 3 and game.settle_keys.size() == fitting.size() and game.settle_marks.size() == fitting.size() * 2, "all fitting houses glow")
	for home: Dictionary in fitting:
		check(game.settle_keys.has("settle%d" % int(home["id"])), "fitting home has glow and badge")
	fitting.sort_custom(func(a, b): return (a["pos"] as Vector2).distance_squared_to(city.center()["pos"]) < (b["pos"] as Vector2).distance_squared_to(city.center()["pos"]))
	if not check(not fitting.is_empty(), "fitting home"):
		return
	var badge_key := "settle%d" % int(fitting[0]["id"])
	check(hud.pointer_target == hud.badges[badge_key]["n"], "pointer on nearest fitting home")
	check(hud.badges[badge_key]["n"].texture == MapBadge.badge_texture("home_room"), "home_room badge")
	await pointer_shot(hud.badges[badge_key]["n"], "05_settle_home.png")
	check(game._settle_into(fitting[0]), "settle chosen family")
	check(tut.cur_id() == "house" and hud.pointer_target == null and not hud.pointer.visible, "assignment completes step and hides arrow immediately")
	await shot("05_assignment_no_arrow.png")
	await frames(3)
	if not city.pending.is_empty():
		check(hud.pointer_target == null and not hud.pointer.visible, "no station arrow while family walks")
	game.speed = 8.0
	for i in 12000:
		if city.settled_total > 0:
			break
		await get_tree().process_frame
	check(city.settled_total > 0, "family reaches home")
	if not await snapshot_step("house"):
		return
	for home: Dictionary in homes:
		if int(home.get("pop", 0)) > 0:
			game.select_building(home)
			hud.open_info(home)
			break
	await frames(30)
	hud._update_pointer()
	check(tut.cur_id() == "house" and not tut._check("house") and tut.next_btn.visible and tut.hint.visible, "opening house needs explicit understood")
	check(tut.hint.text == "Значки — что нужно семье.\nЗелёное — есть, бледное — нужно поставить рядом.", "two-line house hint")
	for line: String in I18n.t(tut.hint.text).split("\n"):
		check(line.length() <= 60, "short translated house hint line")
	await pointer_shot(tut.next_btn, "06_house_understood.png")
	tut.next_btn.pressed.emit()
	if not await snapshot_step("food"):
		return
	await choose_build("commerce", "stall_fruit", "07_food")
	var shop := build_near("stall_fruit", dp + Vector2(-5, 14))
	if shop.is_empty() or not await snapshot_step("workers"):
		return
	check(not tut._check("workers"), "workers step needs actual hire")
	check(city.tips.has("manual_hire_pending") and not city.tips.has("manual_hire_tip"), "workplace advice remains queued during tutorial")
	(hud.pointer_target as Button).pressed.emit()
	check(city.hired_of(shop) == 1, "plus hires a worker")
	if not await snapshot_step("script"):
		return
	await choose_build("farming", "scriptorium", "09_script")
	var script := build_near("scriptorium", dp + Vector2(-5, 26))
	if script.is_empty():
		return
	# Если первая семья мала, обучение тем же указателем ведёт ко второй.
	if not city.can_hire(script):
		game.speed = 8.0
		for i in 12000:
			if not city.arrivals.is_empty():
				break
			await get_tree().process_frame
		game.speed = 0.0
		if not check(not city.arrivals.is_empty(), "second family for scribe"):
			return
		await pointer_shot(hud._do_target({"kind": "fam"}), "09_scribe_family.png")
		(hud.pointer_target as Button).pressed.emit()
		hud._update_pointer()
		await frames()
		var fit := city.homes_for(game.settle_fam)
		if not check(not fit.is_empty(), "second connected home"):
			return
		fit.sort_custom(func(a, b): return (a["pos"] as Vector2).distance_squared_to(city.center()["pos"]) < (b["pos"] as Vector2).distance_squared_to(city.center()["pos"]))
		await pointer_shot(hud.badges["settle%d" % int(fit[0]["id"])]["n"], "09_scribe_home.png")
		check(game._settle_into(fit[0]), "assign second family")
		hud._update_pointer()
		check(hud.pointer_target == null, "no arrow while future worker walks")
		game.speed = 8.0
		for i in 12000:
			if city.can_hire(script):
				break
			await get_tree().process_frame
		game.speed = 0.0
	hud._update_pointer()
	await frames()
	check(tut.cur_id() == "script" and not tut._check("script"), "script step waits for scribe")
	check(hud.pointer_target == hud.info_box.find_child("hire_plus", true, false), "scribe pointer directly on plus")
	await pointer_shot(hud.info_box.find_child("hire_plus", true, false), "09_script_plus.png")
	(hud.pointer_target as Button).pressed.emit()
	if not await snapshot_step("research"):
		return
	(hud.pointer_target as Button).pressed.emit()
	await frames()
	hud._update_pointer()
	var research_card := hud.pointer_target as Button
	if not check(research_card != null and hud.research_panel.is_ancestor_of(research_card), "pointer on available knowledge"):
		return
	await pointer_shot(research_card, "10_research_card.png")
	research_card.pressed.emit()
	await frames()
	hud._update_pointer()
	check(hud.pointer_target == hud.research_tree.study and not hud.research_tree.study.disabled, "pointer on Study")
	check(not tut._check("research"), "opening knowledge is not completion")
	await pointer_shot(hud.research_tree.study, "10_research_study.png")
	hud.research_tree.study.pressed.emit()
	hud._update_pointer()
	check(hud.pointer_target == hud.research_tree.confirm_yes, "pointer on inline Yes")
	hud.research_tree.confirm_yes.pressed.emit()
	if not await snapshot_step("done"):
		return
	check(not hud.advisor_panel.visible and hud.guidance_queue.size() >= 2, "queue still waits at done card")
	hud.close_panels()
	game.set_tool("")
	hud._tip_next = 0
	tut.next_btn.pressed.emit()
	hud._flush_guidance()
	await frames(3)
	check(not hud.tutorial_busy() and not tut.card.visible and not tut.camera_keys.visible and not tut.next_btn.visible, "tutorial finished and hidden")
	check(hud.advisor_panel.visible and hud.adv_title.text == "Работа в новом здании" and hud.notes_box.get_child_count() == 0, "queued advisor appears first, alone")
	hud.advisor_panel.hide()
	hud._tip_next = 0
	hud._flush_guidance()
	await frames(3)
	check(not hud.advisor_panel.visible and hud.notes_box.get_child_count() == 1, "queued toast appears after advisor")
	clear_guidance()
	tut._enter(Tutorial.step_index("move"))
	await get_tree().create_timer(3.1).timeout
	await pointer_shot(tut.next_btn, "01_camera_understood.png")
	tut.next_btn.pressed.emit()
	check(await wait_step("houses"), "camera understood offers manual completion")
	tut._enter(Tutorial.step_index("food"))
	var skip := tut.card.find_child("TutorialSkip", true, false) as Button
	skip.pressed.emit()
	check(not tut.active() and Tutorial.saved_step((JSON.parse_string(JSON.stringify(city.save_data())) as Dictionary).get("tips", {})) == -1, "skip is saved")


func pointer_shot(expected: Control, file: String) -> void:
	hud._update_pointer()
	await frames(8)
	await check_arrow_frames(file)
	var anchored: bool = not hud._pointer_badge.is_empty() and hud._pointer_badge.get("n") == expected
	check(is_instance_valid(expected) and hud.pointer_target == expected and (expected.is_visible_in_tree() or anchored), file + " exact control")
	if expected == tut.next_btn:
		var from := hud.pointer.position + hud.pointer.size * 0.5
		var delta := expected.get_global_rect().get_center() - from
		var aim := Vector2.DOWN.rotated(hud.pointer.rotation)
		check(delta.dot(aim) > 0.0 and absf(delta.cross(aim)) <= 2.0, file + " arrow points at Understood")
	check(not hud.advisor_panel.visible and not hud.notes_box.is_visible_in_tree() and not hud.badges.has("quest_target"), file + " one voice")
	await shot(file)


func check_arrow_frames(context: String) -> void:
	var arrows := hud.find_children("GuidanceArrow", "TextureRect", true, false)
	check(arrows.size() == 1 and arrows[0] == hud.pointer, context + " single arrow node")
	for i in 8:
		var arrow := hud.pointer
		if not check(arrow.is_visible_in_tree() and arrow.size.is_equal_approx(Vector2(64, 64))
				and arrow.texture.resource_path == "res://assets/ui/tutorial_arrow.svg"
				and get_viewport().get_visible_rect().grow(1.0).encloses(Rect2(arrow.position, arrow.size)),
				"%s large green arrow, frame %d (size %s)" % [context, i, arrow.size]):
			return
		await get_tree().process_frame


func choose_build(cat: String, type: String, prefix: String) -> void:
	hud._close_tray()
	game.set_tool("")
	await pointer_shot(hud.cats[cat], prefix + "_category.png")
	(hud.pointer_target as Button).pressed.emit()
	await frames(8)
	for i in 3:
		hud._update_pointer()
		var target := hud.pointer_target as Button
		if not check(target != null, type + " build control"):
			return
		await pointer_shot(target, prefix + "_card%d.png" % i)
		var chosen: bool = String(target.get_meta("type", "")) == type
		target.pressed.emit()
		await frames(8)
		if chosen:
			break
	check(game.tool == type, type + " selected")
	hud._update_pointer()
	var badge: Dictionary = hud.badges.get("tutorial_target", {})
	var at := tut._place_pos
	var pl := game.placement_hint(type, at) if at.is_finite() else {}
	check(pl.get("err", "?") == "" and (type == "house_pleb" or not bool(pl.get("noroad", false))), type + " suggested spot can be built")
	if check(not badge.is_empty(), type + " world placement anchor"):
		var point: Vector3 = badge["pos"]
		var ghost := game.ghost
		var at_ghost: bool = is_instance_valid(ghost) and ghost.visible and game.place_info.get("err", "?") == "" and point.is_equal_approx(ghost.global_position + Vector3.UP)
		check(at.is_equal_approx(Vector2(point.x, point.z)) or at_ghost, type + " arrow anchored to site or valid ghost")
		await pointer_shot(badge["n"], prefix + "_placement.png")


func paint_path(points: Array[Vector2]) -> void:
	game.set_tool("road")
	game.painting = true
	game.stroke = []
	game.stroke_cost = 0.0
	game.brush_line = false
	for i in range(1, points.size()):
		var count := maxi(1, ceili(points[i - 1].distance_to(points[i]) / 0.4))
		for k in count + 1:
			game._paint_at(points[i - 1].lerp(points[i], float(k) / float(count)))
	game._release()
