extends Node3D
## Снимки LEGION1. Запуск только у владельца тестов, без пользовательских сохранений.

const Fixture = preload("res://scripts/test_fort_fixture.gd")
var out := "D:/CivCity/.work/stage2/legion1/shots/"
var game
var camp: CampUI


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2 and pair[0] == "out":
			out = pair[1].trim_suffix("/") + "/"
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
		print("LEGION1 FAIL " + message)
		get_tree().quit(1)
	return ok


func shot(file: String) -> bool:
	await frames(8)
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(out + file)
	if not check(err == OK, "save " + file):
		return false
	print("LEGION1 SHOT " + file)
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
	city.money = 100000
	city.hero = Hero.make("Гай Валерий", 0, Hero.PRESETS[0]["look"], true, 777)
	for i in 15:
		var house := city.place("house_pleb", Land.START + Vector2(8.0 * (i % 8), 8.0 * (i / 8)), 0.0, 0, 0, true)
		if not check(not house.is_empty(), "house %d" % i):
			return
		house["families"] = [{"name": "Юлии%d" % i, "n": 4, "cls": "plebs"}]
		house["pop"] = 4
	city.compute()
	var legion: Legion = city.legion
	legion.army_tick()
	legion.glory = 10000
	preload("res://scripts/test_fort_fixture.gd").set_level(legion, "hq", 3)
	preload("res://scripts/test_fort_fixture.gd").set_level(legion, "barracks", 3)
	preload("res://scripts/test_fort_fixture.gd").set_level(legion, "forge", 2)
	preload("res://scripts/test_fort_fixture.gd").set_level(legion, "store", 2)
	preload("res://scripts/test_fort_fixture.gd").set_level(legion, "mars", 1)
	legion.rations = legion.ration_cap()
	legion.ingots = 3
	legion.pending_resources = {"iron": legion.mat_cap("iron"), "wood": 34.0, "leather": 18.0, "rations": 6.0}
	var population := int(city.stats["pop"])
	for i in 2:
		var soldier := Fixture.recruit(legion)
		if not check(not soldier.is_empty() and legion.set_place(i + 1, int(soldier["id"])), "recruit and assign"):
			return
	if not check(int(city.stats["pop"]) == population, "gate recruitment keeps city population"):
		return
	city.changed.emit()
	camp = CampUI.of(game.hud)
	if not check(camp != null, "camp attached"):
		return
	camp.open()
	if not check(camp.visible and camp.bubbles.size() == 4 and camp.resource_chips.size() == 7
			and camp.chips.columns == 4 and camp.chips.get_child(3).name == "FortResource_glory", "four bubbles and seven chips in two rows"):
		return
	if not await shot("1_camp.png"):
		return
	var amount := legion.mat("iron")
	camp._collect("iron")
	if not check(legion.mat("iron") > amount, "bubble collected"):
		return
	Fixture.gate(legion)
	camp.open_recruit_picker()
	var roster := legion.soldiers.size()
	if not check(is_instance_valid(camp.modal) and legion.recruit_candidates().size() == 3, "three gate candidates"):
		return
	if not await shot("2_recruit_pick.png"):
		return
	var pick: Dictionary = legion.recruit_candidates()[1]
	camp._recruit_pick(pick)
	if not check(legion.soldiers.size() == roster + 1 and legion.soldiers[-1]["name"] == pick["name"], "selected resident"):
		return
	camp.show_hero()
	if not check(bool(legion.soldiers[0].get("hero", false)) and not legion.dismiss(int(legion.soldiers[0]["id"])), "hero protected"):
		return
	if not check(legion.train_hero(), legion.can_train_hero()):
		return
	camp.show_hero()
	if not await shot("3_hero_card.png"):
		return
	legion.queue_chest("wooden")
	legion.queue_chest("bronze")
	legion.queue_chest("gold")
	camp.show_chests()
	if not await shot("4_chest.png"):
		return
	camp._close_modal()
	camp._campaign()
	await frames(10)
	var back := camp.lu.find_child("CampaignBack", true, false) as Button
	if not check(camp.lu.visible and back != null and back.is_visible_in_tree(), "campaign back button"):
		return
	if not await shot("5_campaign_back.png"):
		return
	back.pressed.emit()
	await frames(3)
	if not check(camp.visible and not camp.lu.visible, "back returns to camp"):
		return
	camp._campaign()
	camp.lu.close()
	if not check(camp.visible and not camp.lu.visible, "close returns to camp"):
		return
	for kind: String in ["forge", "store", "mars"]:
		camp._aux(kind)
		await frames(2)
		camp.lu.close()
		if not check(camp.visible and not camp.lu.visible, "back from " + kind):
			return
	print("LEGION1 DONE")
	get_tree().quit()
