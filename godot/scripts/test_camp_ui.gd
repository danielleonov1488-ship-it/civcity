extends Node3D
## Пять кадров лагеря. Запускает владелец проверки; пользовательские сохранения не пишем.

var out := "D:/CivCity/.work/stage1/legion/camp_shots/"
var game
var camp: CampUI


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2 and pair[0] == "out":
			out = pair[1] if pair[1].ends_with("/") else pair[1] + "/"
	Game.boot = {"new": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	game.can_save = false
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("CAMPUI FAIL " + message)
		get_tree().quit(1)
	return ok


func shot(nm: String) -> bool:
	await frames(8)
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(out + nm + ".png")
	if not check(error == OK, "save " + nm):
		return false
	print("CAMPUI SHOT ", nm)
	return true


func _run() -> void:
	var waited := 0
	while not game.ready_done:
		await frames(5)
		waited += 5
		if not check(waited < 18000, "ready_done timeout"):
			return
	game.can_save = false
	game.settings["autosave"] = false
	await frames(30)
	if not check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory"):
		return
	var city: City = game.city
	city.cozy_v = 1
	city.legion_v = 3
	city.hero = {}  # В этом старом тесте проверяются обычные рекруты.
	city.money = 1000000
	for i in 15:
		var h := city.place("house_pleb", Land.START + Vector2(8.0 * (i % 8), 8.0 * (i / 8)), 0.0, 0, 0, true)
		if not check(not h.is_empty(), "house %d" % i):
			return
		h["families"] = [{"name": "Юлии%d" % i, "n": 4, "cls": "plebs"}]
		h["pop"] = 4
	city.compute()
	var legion: Legion = city.legion
	legion.army_tick()
	legion.fort["money"] = 1e6
	legion.glory = 10000
	legion.mats = {"iron": 120, "wood": 90, "leather": 60}
	if not check(int(city.stats["pop"]) >= 60 and legion.v3(), "V3 and population"):
		return
	for i in 4:
		var s := preload("res://scripts/test_fort_fixture.gd").recruit(legion)
		if not check(not s.is_empty(), "recruit %d: %s" % [i, legion.can_recruit_resident()]):
			return
		if i < 3 and not check(legion.set_place(i, int(s["id"])), "place %d" % i):
			return
	# Уровни — только фикстура; таймер запускает обычное действие модели.
	preload("res://scripts/test_fort_fixture.gd").set_level(legion, "hq", 2)
	preload("res://scripts/test_fort_fixture.gd").set_level(legion, "forge", 1)
	if not check(legion.camp_upgrade("forge"), legion.camp_can_upgrade("forge")):
		return
	city.changed.emit()
	camp = CampUI.of(game.hud)
	if not check(camp != null, "HUD camp attached"):
		return
	camp.open()
	if not check(camp.visible and camp.top_button.visible, "camp opened"):
		return
	if not await shot("1_camp"):
		return
	camp.show_building("barracks")
	if not await shot("2_barracks_card"):
		return
	camp.open_recruit_picker()
	if not check(legion.soldiers.size() == 4 and is_instance_valid(camp.modal), "picker does not recruit yet"):
		return
	preload("res://scripts/test_fort_fixture.gd").gate(legion)
	camp._recruit_pick(legion.recruit_candidates()[0])
	if not check(legion.soldiers.size() == 5 and is_instance_valid(camp.modal), "recruit result"):
		return
	if not await shot("3_recruit"):
		return
	camp.show_squad()
	if not await shot("4_squad"):
		return
	camp.show_building("forge")
	if not await shot("5_forge_card"):
		return
	print("CAMPUI DONE")
	get_tree().quit()
