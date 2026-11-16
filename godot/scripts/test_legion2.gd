extends Node3D
## Шесть кадров и проверки жизненного цикла. Запускает только владелец тестов.

var out := "D:/CivCity/.work/stage2/legion2/shots/"
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


func check(ok: bool, reason: String) -> bool:
	if not ok:
		print("LEGION2 FAIL " + reason)
		get_tree().quit(1)
	return ok


func shot(file: String) -> bool:
	await frames(8)
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(out + file)
	if not check(err == OK, "save " + file):
		return false
	print("LEGION2 SHOT " + file)
	return true


func _inside_plaques() -> bool:
	var screen := Rect2(camp.global_position, camp.size)
	for slot: String in camp.plaques:
		var panel: Control = camp.plaques[slot]["panel"]
		if not check(screen.encloses(panel.get_global_rect()), "plaque outside screen: " + slot):
			return false
	return true


func _finish_upgrade(legion: Legion, slot: String) -> bool:
	var before := legion.camp_level(slot)
	if not check(legion.camp_upgrade(slot), "upgrade " + slot + ": " + legion.camp_can_upgrade(slot)):
		return false
	legion.upg["camp_" + slot]["end"] = Legion.now() - 1
	legion.tick()
	return check(legion.camp_level(slot) == before + 1, "finish timer " + slot)


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
	city.money = 1000000
	city.hero = Hero.make("Гай Валерий", 0, Hero.PRESETS[0]["look"], true, 777)
	for i in 16:
		var house := city.place("house_pleb", Land.START + Vector2(8.0 * (i % 8), 8.0 * (i / 8)), 0, 0, 0, true)
		if not check(not house.is_empty(), "house %d" % i):
			return
		house["families"] = [{"name": "Юлии%d" % i, "n": 4, "cls": "plebs"}]
		house["pop"] = 4
	city.compute()
	var legion: Legion = city.legion
	legion.army_tick()
	legion.glory = 10000
	legion.mats = {"iron": 1000.0, "wood": 1000.0, "leather": 1000.0}
	if not check(city.stats["pop"] >= 60 and legion.v3(), "V3 and population"):
		return
	# Стартовые уровни — фикстура; изменения проходят через обычные таймеры.
	legion.camp["hq"] = 3
	legion.camp["barracks"] = 2
	legion.camp["forge"] = 1
	legion.camp["store"] = 1
	legion.camp["mars"] = 1
	if not _finish_upgrade(legion, "barracks") or not _finish_upgrade(legion, "forge"):
		return
	var recruits: Array[int] = []
	for i in 4:
		var soldier := legion.recruit_resident()
		if not check(not soldier.is_empty(), "recruit %d" % i):
			return
		recruits.append(int(soldier["id"]))
	# Герой уже занимает первое место, ставим ещё трёх новобранцев.
	for i in 3:
		if not check(legion.set_place(i + 1, recruits[i]), "place %d" % i):
			return
	if not check(legion.squad_v3().size() == 4, "three placed plus hero"):
		return
	city.money = maxf(city.money, 100000.0)
	legion.glory = maxf(legion.glory, 10000.0)
	var why := legion.camp_can_upgrade("store")
	if not check(legion.camp_upgrade("store"), "start store scaffold: " + why):
		return
	legion.flags["camp3d_guide"] = 4
	legion.rations = 8
	legion.pending_resources = {"rations": 6.0, "iron": 12.0, "wood": 10.0, "leather": 7.0}
	city.changed.emit()
	camp = CampUI.of(game.hud)
	if not check(camp != null, "camp attached"):
		return
	camp.open()
	await frames(10)
	if not check(is_instance_valid(camp.diorama), "Camp3D created (no painting fallback)"):
		return
	if not check(get_viewport().disable_3d, "city render disabled while camp open"):
		return
	if not check(camp.diorama.sub.own_world_3d and camp.diorama.figures.size() <= 16, "own world / figure cap"):
		return
	for slot: String in Camp3D.PLOTS:
		if not check(camp.diorama._pick(camp.diorama.project(slot)) == slot, "footprint picking: " + slot):
			return
	if not _inside_plaques() or not await shot("1_camp3d.png"):
		return
	camp.diorama.focus_plot("barracks")
	if not _inside_plaques() or not await shot("2_zoom_barracks.png"):
		return
	camp.diorama.focus_plot("barracks", false)
	var before := legion.soldiers.size()
	camp._recruit_pick(legion.recruit_candidates()[0])
	camp._close_modal()
	camp._hide_card()
	if not check(legion.soldiers.size() == before + 1, "recruit from picker"):
		return
	var sid := int(legion.soldiers[-1]["id"])
	await get_tree().create_timer(3.0).timeout
	if not check(camp.diorama.arrivals.has(sid), "recruit walks through gate"):
		return
	var walker_found := false
	for entry: Dictionary in camp.diorama.figures:
		if int(entry["id"]) == sid:
			var pos: Vector3 = (entry["node"] as Node3D).position
			walker_found = pos.distance_to(Camp3D.GATE) > 0.2 and pos.distance_to(entry["home"]) > 0.2
	if not check(walker_found, "recruit between gate and barracks"):
		return
	if not await shot("3_recruit_walkin.png"):
		return
	if not check(camp.diorama.scaffolds.has("store") and camp.diorama.figures.size() <= 16, "scaffold and figure cap"):
		return
	camp.diorama.focus_plot("store")
	if not await shot("4_upgrade_scaffold.png"):
		return
	# Закрытие, новая сцена и первая подсказка на стартовых участках.
	var old: WeakRef = weakref(camp.diorama)
	camp.close()
	if not check(not get_viewport().disable_3d and not camp.is_processing(), "city restored / CampUI stopped"):
		return
	await frames(2)
	if not check(old.get_ref() == null and camp.find_children("Camp3D*", "", true, false).is_empty(), "no Camp3D processing after close"):
		return
	var saved_camp := legion.camp.duplicate(true)
	var saved_upg := legion.upg.duplicate(true)
	var saved_soldiers := legion.soldiers.duplicate(true)
	var saved_squad := legion.squad3.duplicate()
	legion.soldiers = legion.soldiers.filter(func(soldier: Dictionary): return bool(soldier.get("hero", false)))
	for i in range(1, legion.squad3.size()):
		legion.set_place(i, 0)
	legion.camp = Legion.CAMP_START.duplicate(true)
	legion.upg.clear()
	legion.flags.erase("camp3d_guide")
	legion.rations = legion.ration_cap()
	legion.pending_resources["rations"] = 0.0
	var total := legion.rations
	camp.open()
	await frames(8)
	if not check(camp.guide.visible and int(legion.flags["camp3d_guide"]) == 0, "first guidance arrow"):
		return
	if not check(is_equal_approx(total, legion.rations + float(legion.pending_resources["rations"])), "tutorial preserves ration total"):
		return
	if not await shot("5_guide_step1.png"):
		return
	camp._collect("rations")
	if not check(int(legion.flags["camp3d_guide"]) == 1, "guide advances on collection"):
		return
	camp.close()
	await frames(2)
	legion.camp = saved_camp
	legion.upg = saved_upg
	legion.soldiers = saved_soldiers
	legion.squad3 = saved_squad
	camp.open()
	if not check(int(legion.flags["camp3d_guide"]) == 1, "guide persists on reopen"):
		return
	camp.show_building("barracks")
	if not await shot("6_card_over_3d.png"):
		return
	camp._hide_card()
	var candidates := legion.recruit_candidates()
	if not check(not candidates.is_empty(), "guide recruit available"):
		return
	camp._recruit_pick(candidates[0])
	camp._close_modal()
	if not check(int(legion.flags["camp3d_guide"]) == 2, "guide advances on recruitment"):
		return
	camp.show_squad()
	camp._pick_place(3)
	camp._assign(int(legion.soldiers[-1]["id"]))
	camp._close_modal()
	if not check(int(legion.flags["camp3d_guide"]) == 3, "guide advances on placement"):
		return
	camp._campaign()
	if not check(int(legion.flags["camp3d_guide"]) == 4, "guide completes at campaign"):
		return
	camp.lu.close()
	if not check(camp.visible and int(legion.flags["camp3d_guide"]) == 4, "completed guide stays completed"):
		return
	old = weakref(camp.diorama)
	camp.close()
	await frames(2)
	if not check(not get_viewport().disable_3d and old.get_ref() == null, "final close frees camp"):
		return
	print("LEGION2 DONE")
	get_tree().quit()
