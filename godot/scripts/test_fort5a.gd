extends Node3D
## Запускает владелец тестов. Не использует пользовательские сохранения.

const Fixture = preload("res://scripts/test_fort_fixture.gd")
var out := "D:/CivCity/.work/stage5/fort5a2/shots/"
var fails := 0
var game: Game
var camp: CampUI
var lg: Legion
var saved_clock := -1.0


func check(ok: bool, reason: String) -> bool:
	if not ok:
		fails += 1
		print("FORT5A FAIL " + reason)
	return ok


func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func shot(file: String) -> void:
	await frames(12)
	await RenderingServer.frame_post_draw
	if check(get_viewport().get_texture().get_image().save_png(out + file) == OK, "save " + file):
		print("FORT5A SHOT " + out + file)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() == 2 and parts[0] == "out":
			out = parts[1].trim_suffix("/") + "/"
	saved_clock = Legion.clock
	Legion.clock = 1000000.0
	Game.boot = {"new": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	game.can_save = false
	add_child(game)
	_run()


func _finish() -> void:
	if is_instance_valid(camp):
		camp.close()
	Legion.clock = saved_clock
	print("FORT5A DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _run() -> void:
	var waited := 0
	while not game.ready_done:
		await frames(5)
		waited += 5
		if not check(waited < 18000, "ready_done timeout"):
			_finish()
			return
	game.can_save = false
	game.settings["autosave"] = false
	game.set_process(false)
	if not check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory"):
		_finish()
		return
	var city: City = game.city
	city.cozy_v = 1
	city.legion_v = 3
	city.money = 1e8
	for i in 16:
		var house := city.place("house_pleb", Land.START + Vector2((i % 8) * 8, (i / 8) * 8), 0.0, 0, 0, true)
		if not check(not house.is_empty(), "house fixture"):
			_finish()
			return
		house["families"] = [{"name": "Юлии%d" % i, "n": 4, "cls": "plebs"}]
		house["pop"] = 4
	city.compute()
	if game.people != null:
		game.people.sync_members()
	lg = city.legion
	lg.fort = {}
	lg.camp = {}
	lg.soldiers.clear()
	lg.items.clear()
	lg.squad3 = [0, 0, 0, 0, 0]
	lg.flags["camp_open"] = true
	lg.flags["camp_told"] = true
	lg.flags["camp3d_guide"] = 4
	lg.army_tick()
	Fixture.set_level(lg, "hq", 3)
	Fixture.set_level(lg, "kitchen", 1)
	lg.mats = {"wood": 10000.0, "iron": 10000.0, "leather": 10000.0}
	lg.rations = 0
	var population := int(city.stats["pop"])
	var workers: Dictionary = city.stats["workers"].duplicate(true)
	var buildings: Dictionary = city.buildings.duplicate(true)
	city.stats["happy"] = 54
	lg.fort_arrival_hour(100)
	check(lg.fort_newcomers().is_empty(), "unhappy city sends nobody")
	city.stats["happy"] = 80
	var interval := lg.fort_arrival_interval()
	city.stats["pop"] = population * 2
	check(lg.fort_arrival_interval() < interval, "population speeds arrivals")
	city.stats["pop"] = population
	lg.fort_arrival_hour(interval - 0.01)
	check(lg.fort_newcomers().is_empty(), "no early arrival")
	lg.fort_arrival_hour(0.02)
	check(lg.fort_newcomers().size() == 1, "arrival at happy rate")
	lg.fort_arrival_hour(interval * 10)
	check(lg.fort_newcomers().size() == 3, "gate queue limited to three")
	city.stats["happy"] = 60
	check(lg.fort_arrival_interval() > interval, "happiness speeds arrivals")
	city.stats["happy"] = 80
	var first: Dictionary = lg.fort_newcomers()[0]
	check(int(first["stars"]) >= 1 and int(first["stars"]) <= 5 and first.has_all(["name", "look_seed", "class_hint"]), "newcomer identity")
	camp = CampUI.of(game.hud)
	if not check(camp != null, "CampUI attached"):
		_finish()
		return
	camp.open()
	await frames(10)
	if not check(camp.diorama is FortCutaway, "cutaway available"):
		_finish()
		return
	var view := camp.diorama as FortCutaway
	check(view.figures.any(func(e: Dictionary): return e["role"] == "newcomer"), "gate figures")
	camp.show_newcomer(int(first["id"]))
	check(camp.modal_panel.name == "FortNewcomerCard", "gate mini-card")
	camp._close_modal()
	await shot("1_gate_newcomers.png")
	var accepted := lg.fort_accept(int(first["id"]))
	var sid := int(accepted.get("id", 0))
	check(sid == int(first["id"]) and lg.fort_worker_plot(sid) == -1, "accept keeps identity, waits in courtyard")
	check(int(city.stats["pop"]) == population and city.stats["workers"] == workers and city.buildings == buildings, "city population, jobs, families unchanged")
	check(not lg.set_place(1, sid), "courtyard person cannot enter squad")
	var kitchen := int(lg.fort_slot_plot("kitchen")["id"])
	var barracks := int(lg.fort_slot_plot("barracks")["id"])
	camp._refresh()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = view.person_project(sid)
	view._gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = view.get_global_transform_with_canvas() * view.project(kitchen)
	motion.relative = Vector2(20, 0)
	view._input(motion)
	check(view.drag_sid == sid and is_instance_valid(view.drag_ghost) and view.drag_target == kitchen, "drag has ghost and target")
	check(view.highlights["plot_%d" % kitchen].visible and not view._drop_valid(0), "green room and invalid HQ")
	await shot("2_drag_ghost.png")
	check(view.finish_person_move(view.project(kitchen)) and lg.fort_worker_plot(sid) == kitchen, "drag courtyard into kitchen")
	view.begin_person_move(sid, false, view.project(0))
	check(not view.finish_person_move(view.project(0)) and lg.fort_worker_plot(sid) == kitchen, "invalid drop preserves assignment")
	var second := lg.fort_newcomers()[0]
	var sid2 := int(second["id"])
	check(lg.fort_drop(barracks, sid2, true) and lg.fort_is_fighter(sid2), "drag gate into barracks")
	check(lg.fort_squad_candidates().any(func(p: Dictionary): return int(p["id"]) == sid2) and lg.set_place(1, sid2), "barracks resident is squad candidate")
	check(lg.fort_assign(kitchen, sid2), "move fighter onto full work room")
	check(lg.fort_worker_plot(sid2) == kitchen and lg.fort_worker_plot(sid) == barracks and not lg.squad3.has(sid2), "full room swaps first occupant and clears worker from squad")
	check(lg.fort_assign(barracks, sid2) and lg.fort_occupants(barracks).size() == 2, "move between rooms")
	check(lg.fort_room_slots(kitchen) == 1, "level one work slot")
	Fixture.set_level(lg, "kitchen", 7)
	check(lg.fort_room_slots(kitchen) == 3, "work room grows to three slots")
	Fixture.set_level(lg, "kitchen", 1)
	var item := lg.add_item({"slot": "weapon", "cls": "legionary", "tier": 3, "rarity": 2, "ilvl": 3})
	var before := Legion.power(lg.soldier_stats(accepted, "legionary"))
	camp.show_dweller(sid)
	check(camp.modal_panel.name == "FortDwellerCard" and camp.modal_panel.find_child("FortGearSlots", true, false).get_child_count() == 4, "dweller card has four slots")
	camp._equip_dweller(sid, int(item["id"]))
	check(Legion.power(lg.soldier_stats(accepted, "legionary")) > before and int(item["on"]) == sid and camp.modal_panel.find_child("FortEquipChange", true, false) != null, "card equip changes stats and shows before/after")
	await shot("3_dweller_card.png")
	camp._dweller_next(sid, 1)
	check(camp.dweller_sid == sid2, "card next person")
	camp._move_dweller(sid2)
	check(view.drag_sid == sid2, "move button highlights rooms")
	view.cancel_person_move()
	var capacity := lg.roster_cap()
	while lg.fort_population() < capacity:
		Fixture.gate(lg, 1)
		check(not lg.recruit_resident().is_empty(), "capacity fixture accepts")
	Fixture.gate(lg, 1)
	var waiting := lg.fort_newcomers().size()
	var gate_id := int(lg.fort_newcomers()[0]["id"])
	check(lg.fort_accept(gate_id).is_empty() and not lg.fort_drop(kitchen, gate_id, true) and lg.fort_newcomers().size() == waiting, "capacity blocks acceptance and gate drop without consuming queue")
	check(lg.fort_release(gate_id) and int(city.stats["pop"]) == population, "release newcomer leaves city alone")
	Fixture.gate(lg, 2)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(lg.to_dict()))
	var copy := City.new(Land.new())
	copy.cozy_v = 1
	copy.legion_v = 3
	copy.legion.from_dict(saved)
	check(copy.legion.fort_newcomers() == lg.fort_newcomers() and copy.legion.fort_worker_plot(sid) == barracks and copy.legion.fort_population() == capacity, "JSON preserves queue IDs, assignments, population")
	var old: Dictionary = saved.duplicate(true)
	old["fort"].erase("population_v")
	old["squad3"][1] = sid2
	for p: Dictionary in old["fort"]["plots"]:
		p.erase("workers")
	copy.legion.from_dict(old)
	check(copy.legion.soldier(sid).get("name") == accepted["name"] and int(copy.legion.item(int(item["id"]))["on"]) == sid, "migration preserves soldier and equipment")
	check(copy.legion.fort_is_fighter(sid2) and int(copy.legion.squad3[1]) == sid2, "old squad keeps barracks home")
	accepted["res"] = {"fam": "Старая семья", "m": {"sd": 1}}
	check(lg.dismiss(sid) and int(city.stats["pop"]) == population and city.buildings == buildings, "old V3 soldier never returns to city families")
	check(not camp.expand_floor.visible, "floor button hidden while a cell is free")
	Fixture.set_level(lg, "smelter", 1)
	camp._refresh()
	await frames(5)
	check(lg.fort_empty_plot() < 0 and camp.expand_floor.visible and camp.expand_section.visible, "full fort shows floor and section buttons")
	await shot("4_plus_floor.png")
	camp.show_expansion("section")
	check(lg.fort_expand("section") and not lg.fort_expand("floor"), "expansion uses one builder")
	Legion.clock = float(lg.fort["up"]["end"])
	lg.fort_finish()
	check(lg.fort_empty_plot() >= 0 and int(lg.fort.get("sections", 0)) == 1, "section adds buildable cells")
	check(int(Legion.fort_exp_info(20)["plots"]) > int(Legion.fort_exp_info(19)["plots"]), "endless formula")
	check(int(city.stats["pop"]) == population and city.stats["workers"] == workers and city.buildings == buildings, "all fort operations preserve city")
	_finish()
