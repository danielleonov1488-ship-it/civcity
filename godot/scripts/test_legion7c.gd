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
	game.settings["autosave"] = false
	game.hud.set_speed(0.0)
	var city := game.city
	city.cozy_v = 1
	city.legion_v = 3
	city.hero = Hero.make("Гай Валерий", 0, Hero.PRESETS[0]["look"], true, 777)
	lg = city.legion
	Legion.clock = Time.get_unix_time_from_system()
	lg.flags["camp_open"] = true
	camp = CampUI.attach(game.hud)
	camp.open()
	await shot("01_gate", Step.FIRST_BATTLE, camp.campaign_button)
	var during := save_round_trip()
	if not press(camp.campaign_button, "open campaign"):
		return
	await frames(6)
	var first := camp.lu.guide_stage_button
	await shot("02_stage_one", Step.FIRST_BATTLE, first)
	if not press(first, "choose the first battle"):
		return
	await frames(6)
	var fight := camp.lu._fight_btn
	check(is_instance_valid(fight) and int(fight.get_meta("ration_cost", -1)) == 0, "first battle is free")
	await shot("03_free_battle", Step.FIRST_BATTLE, fight)
	camp.lu.close()
	camp.open()
	_before_finish()
	await _after_intro(during, lg.rations, 0.0)


func _before_finish() -> void:
	lg.flags["fort_lessons_off"] = true


func _after_intro(during: Dictionary, before_load: float, _reserved: float) -> void:
	camp.close()
	lg.from_dict(during.duplicate(true))
	camp.open()
	await frames(6)
	check(lg.fort_guide_step() == Step.FIRST_BATTLE and camp.guide_pointer.is_visible_in_tree(), "opening survives save and load")
	if not press(camp.guide_skip, "skip an active step"):
		return
	check(lg.fort_guide_step() == Step.DONE and not camp.guide_pointer.is_visible_in_tree(), "skip hides arrow immediately")
	check(camp._guide_target == null and not camp._guide_rect.has_area(), "skip clears guide target")
	check(is_equal_approx(lg.rations, before_load), "skip keeps food")
	var skipped := save_round_trip()
	camp.close()
	lg.from_dict(skipped)
	camp.open()
	await shot("04_skipped_reload", Step.DONE)
