extends "res://scripts/test_uni6_support.gd"
## Вся цепочка через обычные игровые действия; шаги тест не переставляет.

var tut: Tutorial
var homes: Array[Dictionary] = []


func _ready() -> void:
	if not await boot_run("TUTOR6", "D:/CivCity/.work/stage5/uni6/tutorial/"):
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
		await get_tree().process_frame
	return check(false, "step " + id + " timed out at " + tut.cur_id())


func expected_target(id: String) -> Control:
	match id:
		"move":
			return tut.camera_keys
		"road":
			return hud.badges["tutorial_target"]["n"] if game.tool == "road" else hud.road_target()
		"houses":
			return hud._card_or_cat("housing", "house_pleb")
		"cart", "house":
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
	tut.layout()
	var target: Control = hud.pointer_target
	check(I18n.t(tut.text.text).length() <= 60, id + " translated step is short")
	check(tut.text.get_theme_font("font").get_string_size(I18n.t(tut.text.text), HORIZONTAL_ALIGNMENT_LEFT, -1, tut.text.get_theme_font_size("font_size")).x <= tut.text.size.x + 1.0, id + " complete step text fits")
	check(is_instance_valid(target) and target == expected_target(id), id + " expected pointer target")
	check(hud.pointer.visible, id + " exactly one pointer visible")
	check(not hud.badges.has("quest_target"), id + " no story pointer")
	check(not hud.advisor_panel.visible and not hud.notes_box.is_visible_in_tree(), id + " no competing advisor/toast")
	var legion := LegionUi.of(hud)
	check(legion == null or not legion.tut_active(), id + " no Legion tutorial")
	check(game.stories.pointer_do().is_empty(), id + " no story instruction")
	check(tut.card.size.x <= 420.0, id + " compact tutorial")
	if is_instance_valid(target):
		check(target.is_visible_in_tree(), id + " actionable target is visible")
		check(not tut.card.get_global_rect().intersects(target.get_global_rect()), id + " card clears target")
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
			if String(pl.get("err", "")) == "" and String(pl.get("sub", "")) == "road":
				var b := city.place(type, pl["pos"], pl["yaw"], pl["variant"], pl["color"])
				if not b.is_empty():
					hud.on_workplace_built(b)
					game.set_tool("")
					return b
	check(false, "valid placement " + type)
	game.set_tool("")
	return {}


func run() -> void:
	check(Tutorial.saved_step({"tut": 1}) == Tutorial.step_index("road"), "old turn maps to road")
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
	check(hud.pointer_target == tut.camera_keys, "rank pointer yields to tutorial")
	hud.rank_btn.hide()
	if not await snapshot_step("move"):
		return
	check(not tut._check("move"), "camera needs movement")
	game.rig._target_t += Vector3(6, 0, 2)
	if not await snapshot_step("road"):
		return
	var dp: Vector2 = city.door_point(city.center())
	game.set_tool("road")
	hud._update_pointer()
	check(hud.pointer_target == hud.badges["tutorial_target"]["n"], "road tool points to map")
	game.painting = true
	game.stroke = []
	game.stroke_cost = 0.0
	game.brush_line = false
	for k in 64:
		game._paint_at(dp + Vector2(0, 2 + k * 0.5))
	game._release()
	game.people.refresh(game.land.road_chunks.keys())
	game.set_tool("")
	if not await snapshot_step("houses"):
		return
	for k in 3:
		var home := build_near("house_pleb", dp + Vector2(5, 10 + k * 8))
		if home.is_empty():
			return
		homes.append(home)
		city._tick_arrivals()
		check(city.incoming == 0, "cart waits for its tutorial step")
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
	check(game._settle_into(fitting[0]), "settle chosen family")
	game.speed = 8.0
	if not await snapshot_step("house"):
		return
	for home: Dictionary in homes:
		if int(home.get("pop", 0)) > 0:
			game.select_building(home)
			hud.open_info(home)
			break
	if not await snapshot_step("food"):
		return
	var shop := build_near("stall_fruit", dp + Vector2(-5, 14))
	if shop.is_empty() or not await snapshot_step("workers"):
		return
	check(not tut._check("workers"), "workers step needs actual hire")
	check(city.tips.has("manual_hire_pending") and not city.tips.has("manual_hire_tip"), "workplace advice remains queued during tutorial")
	(hud.pointer_target as Button).pressed.emit()
	check(city.hired_of(shop) == 1, "plus hires a worker")
	if not await snapshot_step("script"):
		return
	var script := build_near("scriptorium", dp + Vector2(-5, 26))
	if script.is_empty():
		return
	hud._update_pointer()
	await frames()
	check(tut.cur_id() == "script" and not tut._check("script"), "script step waits for scribe")
	check(hud.pointer_target == hud.info_box.find_child("hire_plus", true, false), "scribe pointer directly on plus")
	(hud.pointer_target as Button).pressed.emit()
	if not await snapshot_step("research"):
		return
	(hud.pointer_target as Button).pressed.emit()
	await frames()
	hud._update_pointer()
	var research_card := hud.pointer_target as Button
	if not check(research_card != null and hud.research_panel.is_ancestor_of(research_card), "pointer on available knowledge"):
		return
	research_card.pressed.emit()
	await frames()
	hud._update_pointer()
	check(hud.pointer_target == hud.research_tree.study and not hud.research_tree.study.disabled, "pointer on Study")
	check(not tut._check("research"), "opening knowledge is not completion")
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
	tut._enter(Tutorial.step_index("food"))
	var skip := tut.card.find_child("TutorialSkip", true, false) as Button
	skip.pressed.emit()
	check(not tut.active() and Tutorial.saved_step((JSON.parse_string(JSON.stringify(city.save_data())) as Dictionary).get("tips", {})) == -1, "skip is saved")
