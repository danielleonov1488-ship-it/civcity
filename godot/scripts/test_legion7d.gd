extends Node3D
## Три кадра форта B1 на новой тестовой партии.

const Actor = preload("res://scripts/charpilot_actor.gd")
const OUT := "D:/CivCity/.work/stage6/legion7d/shots/"
var out := OUT
var game: Game
var camp: CampUI
var lg: Legion
var view: FortCutaway
var fails := 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=").trim_suffix("/") + "/"
	var saved_clock := Legion.clock
	var saved_lang := I18n.lang
	I18n.set_lang("ru")
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1920, 1080)
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	game.can_save = false
	add_child(game)
	await _run()
	if is_instance_valid(camp):
		camp.close()
	Legion.clock = saved_clock
	I18n.set_lang(saved_lang)
	print("LEGION7D DONE fails=", fails)
	get_tree().quit(0 if fails == 0 else 1)


func check(ok: bool, reason: String) -> bool:
	if not ok:
		fails += 1
		print("LEGION7D FAIL ", reason)
	return ok


func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func shot(file: String) -> void:
	await frames(18)
	await RenderingServer.frame_post_draw
	if check(get_viewport().get_texture().get_image().save_png(out + file) == OK, "save " + file):
		print("LEGION7D SHOT ", out + file)


func _check_art() -> void:
	var paths := {}
	for type: String in Legion.FORT_B:
		for level: int in [1, 4, 8]:
			var path := FortCutaway.room_texture_path(type, level)
			var tex := _load_texture(path)
			var expected := Vector2(3072, 1024) if type == "hq" else Vector2(1536, 1024)
			check(tex != null and tex.get_size() == expected, "room texture " + path)
			paths[path] = true
	check(paths.size() == Legion.FORT_B.size() * 3, "distinct art for every room and level stage")
	for art: String in ["legionary", "archer", "priest", "cavalry", "hero", "cook", "smith", "treasurer", "newcomer_male", "newcomer_female"]:
		var sheet := _load_texture(FortCutaway.ART + "chars/" + art + ".png")
		var face := _load_texture(FortCutaway.ART + "chars/" + art + "_portrait.png")
		check(sheet != null and sheet.get_size() == Vector2(2048, 256), "eight frames " + art)
		check(face != null and face.get_size() == Vector2(256, 256), "portrait " + art)
	for type: String in ["archer", "priest", "cavalry", "legionary"]:
		check(FortCutaway.person_art({"cls": type}, "barracks") == type, "military class " + type)
	check(FortCutaway.person_art({"res": {"m": {"sx": 1}}}) == "newcomer_female", "legacy dweller appearance")


func _load_texture(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _fixture() -> void:
	var city := game.city
	city.cozy_v = 1
	city.legion_v = 3
	city.name = "Нова Рома"
	city.hero = Hero.make("Гай Валерий", 0, Hero.PRESETS[0]["look"], true, 777)
	lg = city.legion
	Legion.clock = Time.get_unix_time_from_system()
	lg.fort = {"exp": 1, "grid": [3, 3], "money": 4290, "plots": [], "next_id": 0, "up": {},
		"newcomers": [], "arrival": 0.0, "know": {"smith": true}, "population_v": true, "workers_v": true}
	lg.camp = {}
	lg.upg.clear()
	lg.soldiers.clear()
	lg.squad3 = [0, 0, 0, 0, 0]
	lg.flags["camp_open"] = true
	lg.flags["camp_told"] = true
	lg.flags["fort_guide"] = Legion.FortGuide.DONE
	lg.mats = {"wood": 1000.0, "iron": 1000.0, "leather": 1000.0}
	lg.rations = 42.0
	lg.ingots = 250
	lg.chest_queue.clear()
	lg.chest_queue.append("wooden")
	lg._fort_add_plot("hq", 11)
	for type: String in ["barracks", "kitchen", "treasury", "mars", "store", "forge", ""]:
		var plot := lg._fort_add_plot(type, 0 if type == "" else 4)
		if type in ["barracks", "kitchen", "treasury", "forge", "mars"]:
			var person := lg._add_soldier({"name": "Луций", "cls": "legionary", "stars": 2})
			check(lg.fort_assign(int(plot["id"]), int(person["id"])), "fixture worker " + type)
	lg._fort_fill_grid()
	lg._fort_sync_camp()
	lg._ensure_hero3()
	lg.fort_slot_plot("kitchen")["pend"] = 6.0
	for female: bool in [false, true]:
		var newcomer := lg._fort_newcomer()
		newcomer["female"] = female
		newcomer.erase("look")
		lg._person_look(newcomer)
		(lg.fort["newcomers"] as Array).append(newcomer)
	lg._add_soldier({"name": "Марк", "cls": "legionary", "stars": 1})


func _entry(sid: int, newcomer := false) -> Dictionary:
	for person: Dictionary in view.figures:
		if int(person["id"]) == sid and (person["role"] == "newcomer") == newcomer:
			return person
	return {}


func _room_image(plot: int, path: String) -> bool:
	var sprite := view.room_sprites.get(plot) as Sprite2D
	return sprite != null and sprite.texture != null and sprite.texture.resource_path == path


func _portrait(holder: Node, file: String) -> bool:
	if holder == null:
		return false
	var art := holder.find_child("FortPortraitArt", true, false) as TextureRect
	return art != null and art.texture != null and art.texture.resource_path == FortCutaway.ART + "chars/" + file + "_portrait.png"


func _click_person(sid: int, newcomer := false) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = view.person_project(sid, newcomer)
	view._gui_input(click)
	click.pressed = false
	click.position = view.get_global_transform_with_canvas() * click.position
	view._input(click)


func _drag_person(sid: int, target: int, newcomer := false) -> bool:
	var source := _entry(sid, newcomer).get("node") as Actor
	if not check(source != null, "drag source is drawn"):
		return false
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = view.person_project(sid, newcomer)
	view._gui_input(click)
	var motion := InputEventMouseMotion.new()
	motion.position = view.get_global_transform_with_canvas() * view.project(target)
	view._input(motion)
	var ghost := view.drag_ghost
	if not check(view.drag_sid == sid and view.drag_target == target and is_instance_valid(ghost), "drag starts and follows pointer"):
		return false
	check(ghost.get_meta("look") == source.get_meta("look") and ghost.get_meta("loadout") == source.get_meta("loadout")
		and ghost._sample_clip == source._sample_clip and ghost._opacity < 1.0, "same outfit and pose in translucent ghost")
	return true


func _check_animation() -> void:
	var seen := {}
	var left := false
	var right := false
	var stays_in_room := true
	for i in 48:
		view._animate_people(0.17)
		for person: Dictionary in view.figures:
			var role: String = person["role"]
			var clip: String = person["clip"]
			var clips: Dictionary = seen.get(role, {})
			clips[clip] = true
			seen[role] = clips
			var plot := int(person["plot"])
			if plot >= 0:
				stays_in_room = stays_in_room and (view.room_rects[plot] as Rect2).has_point(person["feet"])
			if role == "barracks" and clip == "Walk":
				left = left or float(person["yaw"]) < 0.0
				right = right or float(person["yaw"]) > 0.0
	for role: String in FortCutaway.WORK_CLIPS:
		check(seen.get(role, {}).has(FortCutaway.WORK_CLIPS[role]), "work animation " + role)
	var clips: Dictionary = seen.get("barracks", {})
	check(clips.has("Idle") and clips.has("Walk") and left and right, "idle, walk and turn in room")
	check(stays_in_room, "walk stays inside the assigned room")

func _check_expansion() -> void:
	var build := lg.fort_slot_plot("smelter")
	if not check(not (build.get("up", {}) as Dictionary).is_empty(), "active construction before expansion"):
		return
	Legion.clock = float(build["up"]["end"]) + 0.1
	lg.fort_finish()
	lg.fort["money"] = float(lg.money_cap())
	for axis: String in ["floor", "section"]:
		var expected := view.grid + (Vector2i(0, 1) if axis == "floor" else Vector2i(1, 0))
		if not check(lg.fort_expand(axis), "start expansion " + axis):
			return
		Legion.clock = float(lg.fort["up"]["end"]) + 0.1
		lg.fort_finish()
		camp._refresh()
		check(view.grid == expected and view.room_sprites.size() == expected.x * expected.y - 1, "painted expansion " + axis)
		for id: int in view.room_rects:
			check(view._pick(view.project(id)) == "plot_%d" % id, "expanded plot picking %d" % id)
	for i in FortCutaway.SPRITE_LIMIT + 4:
		lg._add_soldier({"name": "Луций", "cls": "legionary", "stars": 1})
	view.sync()
	check(view.figures.size() == FortCutaway.SPRITE_LIMIT - 1, "sprite cap reserves one drag ghost")
	await frames(12)
	var started := Time.get_ticks_usec()
	await frames(90)
	var fps := 90000000.0 / maxf(1.0, Time.get_ticks_usec() - started)
	var draws := view.sub.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	print("LEGION7D PERF fps=%.1f draws=%d" % [fps, draws])


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
	_check_art()
	_fixture()
	camp = CampUI.of(game.hud)
	if not check(is_instance_valid(camp), "camp attached"):
		return
	camp.open()
	await frames(12)
	view = camp.diorama as FortCutaway
	if not check(is_instance_valid(view), "2D fort active"):
		return
	check(view.grid == Vector2i(5, 3) and view.room_sprites.size() == 14, "wider three-floor fort")
	check(view.backdrop.texture.resource_path.ends_with("/legion_b1/fort/background.jpg")
		and view.shell.get_node_or_null("Gate") is Sprite2D, "painted landscape and gate")
	check(view.people_layer.viewport.transparent_bg, "transparent 3D layer in painted fort")
	check(not view.figures.is_empty(), "dwellers present")
	for person: Dictionary in view.figures:
		var actor := person["node"] as Actor
		check(actor != null and actor.get_parent() == view.people_layer.viewport and not actor.identity.is_empty(), "dweller uses the shared 3D layer")
	var kitchen := int(lg.fort_slot_plot("kitchen")["id"])
	var cook := int(lg.fort_worker(kitchen)["id"])
	var empty := lg.fort_empty_plot()
	check(_room_image(kitchen, FortCutaway.room_texture_path("kitchen", 4)), "room selects exact level texture")
	check(_room_image(empty, FortCutaway.room_texture_path("", 0)), "vacant plot uses B1 art")
	_check_animation()
	await shot("1_fort.png")
	var arrivals := lg.fort_newcomers()
	var sid := int(arrivals[1]["id"])
	_click_person(sid, true)
	if not check(is_instance_valid(camp.modal_panel), "newcomer opens from sprite"):
		return
	check(_portrait(camp.modal_panel.find_child("FortNewcomerPortrait", true, false), "newcomer_female"), "newcomer card portrait")
	camp._close_modal()
	_click_person(cook)
	if not check(is_instance_valid(camp.modal_panel), "dweller opens from sprite"):
		return
	var portrait := camp.modal_panel.find_child("FortPortraitArt", true, false) as FortPersonPreview
	check(portrait != null and portrait.actor.get_meta("look") == lg.soldier(cook)["look"], "live portrait of the selected worker")
	await shot("2_dweller_card.png")
	camp._close_modal()
	camp.show_plot(kitchen)
	check(_portrait(camp.card_body.find_child("FortWorker", true, false), "cook"), "room worker portrait")
	camp._hide_card()
	if not _drag_person(sid, 0, true):
		return
	check(not view.finish_person_move(view.project(0)) and lg.fort_newcomers().size() == 2, "invalid drop leaves arrival at gate")
	if not _drag_person(sid, kitchen, true):
		return
	check(view.finish_person_move(view.project(kitchen)) and lg.fort_worker_plot(sid) == kitchen, "newcomer drops into room")
	var barracks := int(lg.fort_slot_plot("barracks")["id"])
	if not _drag_person(cook, barracks):
		return
	check(view.finish_person_move(view.project(barracks)) and lg.fort_is_fighter(cook), "resident moves between rooms")
	(camp.plot_markers[empty]["button"] as Button).pressed.emit()
	if not check(is_instance_valid(camp.modal_panel) and camp.build_plot_id == empty and camp.modal_panel.name == "FortBuildMenu", "empty plot opens its build menu"):
		return
	var build := camp.build_cards.get("smelter", {}).get("button") as Button
	if not check(build != null and not build.disabled, "smelter is buildable"):
		return
	build.pressed.emit()
	if not check(_room_image(empty, FortCutaway.room_texture_path("smelter", 0, true)), "construction uses B1 art"):
		return
	for plot: Dictionary in lg.fort["plots"]:
		if plot["b"] == "":
			plot["b"] = "tower"
			plot["lv"] = 1
	camp._refresh()
	check(camp.expand_floor.visible and camp.expand_section.visible, "both expansion controls are available when full")
	camp._hide_card()
	await shot("3_build.png")
	await _check_expansion()
