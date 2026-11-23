extends Node3D
## Первые кадры открытия форта на отдельном сохранении.

const Fixture = preload("res://scripts/test_fort_fixture.gd")
const Cutaway = preload("res://scripts/fort_cutaway.gd")
const COUNT := 10
const TILE := Vector2i(480, 270)

var out := "D:/CivCity/.work/stage7/perf14a5/shots"
var game: Game


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=")
	_run.call_deferred()


func _run() -> void:
	if not _check(DirAccess.make_dir_recursive_absolute(out) == OK, "папка снимков"):
		return
	if not _check(await _boot("new"), "новый город не загрузился"):
		return
	var legion := game.city.legion
	legion.flags["camp_open"] = true
	Fixture.set_level(legion, "hq", 2)
	Fixture.set_level(legion, "store", 1)
	Fixture.set_level(legion, "forge", 1)
	Fixture.gate(legion)
	var soldier := Fixture.recruit(legion)
	if not _check(not soldier.is_empty(), "нет жителя для Штаба"):
		return
	var sid := int(soldier["id"])
	game.save()
	if not _check(FileAccess.file_exists(game.save_path()), "нет тестового сохранения"):
		return
	var camp := CampUI.of(game.hud)
	if not await _capture(camp, "first"):
		return
	camp.close()
	await get_tree().process_frame
	if not await _capture(camp, "reopen"):
		return
	camp.close()
	game.queue_free()
	await get_tree().process_frame
	if not _check(await _boot("play"), "сохранение не загрузилось"):
		return
	var occupants := game.city.legion.fort_occupants(0)
	if not _check(occupants.any(func(person: Dictionary) -> bool: return int(person["id"]) == sid), "житель Штаба не загрузился"):
		return
	if not await _capture(CampUI.of(game.hud), "loaded"):
		return
	print("FORT14A5 DONE")
	get_tree().quit()


func _boot(mode: String) -> bool:
	Game.boot = {mode: "1", "nologin": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	var deadline := Time.get_ticks_msec() + 120000
	while not game.ready_done and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not game.ready_done:
		return false
	await get_tree().create_timer(0.7, true, false, true).timeout
	game.settings["autosave"] = false
	return true


func _capture(camp: CampUI, label: String) -> bool:
	if not _check(camp != null, "нет экрана форта"):
		return false
	var opening: Array[Image] = []
	var visible_fort: Array[Image] = []
	var people_drawn := false
	camp.open()
	var deadline := Time.get_ticks_msec() + 15000
	while visible_fort.size() < COUNT and Time.get_ticks_msec() < deadline:
		await RenderingServer.frame_post_draw
		var cutaway := camp.diorama as Cutaway
		var visible_now := is_instance_valid(cutaway) and cutaway.is_visible_in_tree()
		if visible_now:
			var layer := cutaway.people_layer
			if not _check(not layer.overlay.visible or layer._texture_ready, label + ": показана неготовая текстура"):
				return false
			people_drawn = people_drawn or layer.overlay.visible
		if opening.size() < COUNT or visible_now:
			var frame := get_viewport().get_texture().get_image()
			if opening.size() < COUNT:
				opening.append(frame)
			if visible_now:
				visible_fort.append(frame)
	if not _check(visible_fort.size() == COUNT and people_drawn, label + ": нет десяти кадров с разрезом или слоя жителей"):
		return false
	return _strip(opening, label + "_click") and _strip(visible_fort, label + "_rooms")


func _strip(frames: Array[Image], label: String) -> bool:
	var strip := Image.create(TILE.x * 5, TILE.y * 2, false, Image.FORMAT_RGB8)
	for i in frames.size():
		var frame := frames[i].duplicate() as Image
		frame.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
		frame.convert(Image.FORMAT_RGB8)
		strip.blit_rect(frame, Rect2i(Vector2i.ZERO, TILE), Vector2i(i % 5, i / 5) * TILE)
	var path := out.path_join(label + ".png")
	if not _check(strip.save_png(path) == OK, "не записан " + path):
		return false
	print("FORT14A5 SHOT ", path)
	return true


func _check(ok: bool, message: String) -> bool:
	if not ok:
		print("FORT14A5 FAIL ", message)
		get_tree().quit(1)
	return ok
