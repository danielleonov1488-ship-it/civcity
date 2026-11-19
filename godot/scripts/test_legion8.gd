extends Node3D
## Шесть состояний по макетам этапа. Запускается отдельно от сохранений игрока.

const Fixture = preload("res://scripts/test_fort_fixture.gd")
const Look = preload("res://scripts/legion_look.gd")
const SHOTS := "D:/CivCity/.work/stage7/legion8/shots/"
const MIN_EMPTY := 8

var out := SHOTS
var game: Game
var camp: CampUI
var lg: Legion
var view: FortCutaway
var fails := 0
var saved_clock := 0.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4).trim_suffix("/") + "/"
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1920, 1080)
	saved_clock = Legion.clock
	Game.boot = {"new": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	game.can_save = false
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _report_tag() -> String:
	return "LEGION8"


func check(ok: bool, message: String) -> bool:
	if not ok:
		fails += 1
		print(_report_tag() + " FAIL " + message)
	return ok


func shot(file: String) -> void:
	await frames(10)
	await RenderingServer.frame_post_draw
	if check(get_viewport().get_texture().get_image().save_png(out + file) == OK, "save " + file):
		print(_report_tag() + " SHOT " + out + file)


func _finish() -> void:
	Legion.clock = saved_clock
	print("%s DONE fails=%d" % [_report_tag(), fails])
	get_tree().quit(1 if fails > 0 else 0)


func _populate() -> int:
	var city: City = game.city
	city.cozy_v = 1
	city.legion_v = 3
	city.level = 5
	city.name = "Нова Рома"
	city.hero = Hero.make("Гай Валерий", 0, Hero.PRESETS[0]["look"], true, 777)
	lg = city.legion
	lg.fort = {}
	lg.camp = {}
	lg.soldiers.clear()
	lg.upg.clear()
	lg.flags["camp_open"] = true
	lg.flags["camp_told"] = true
	lg.flags["fort_guide"] = Legion.FortGuide.DONE
	lg.squad3 = [0, 0, 0, 0, 0]
	lg.army_tick()
	var vacant := 0
	for plot: Dictionary in lg.fort["plots"]:
		if plot["b"] == "":
			vacant += 1
	check(lg.fort_grid() == Legion.FORT_START_GRID and vacant >= MIN_EMPTY, "starting fort has eight or more build slots")
	Fixture.set_level(lg, "hq", 2)
	Fixture.set_level(lg, "barracks", 2)
	Fixture.set_level(lg, "kitchen", 2)
	Fixture.set_level(lg, "drill", 4)
	lg.mats = {"wood": 40.0, "iron": 40.0, "leather": 40.0}
	lg.fort["money"] = 2840.0
	lg.ingots = 18
	lg.glory = 120
	lg.rations = 12
	lg.progress = 2
	lg.chest_queue = ["wooden", "bronze"]
	var tit := Fixture.recruit(lg)
	var livia := Fixture.recruit(lg)
	if not check(not tit.is_empty() and not livia.is_empty(), "two squad members"):
		return 0
	tit["name"] = "Тит Клавдий"
	livia["name"] = "Ливия"
	lg.set_place(1, int(tit["id"]))
	lg.set_place(2, int(livia["id"]))
	for type: String in ["kitchen", "treasury", "drill"]:
		var person := Fixture.recruit(lg, false)
		if not check(not person.is_empty(), "dweller for " + type):
			return 0
		var plot := lg.fort_slot_plot(type)
		lg.fort_assign(int(plot["id"]), int(person["id"]))
		if type != "drill":
			plot["pend"] = 18.0 if type == "kitchen" else 54.0
	Fixture.gate(lg, 1)
	return int(tit["id"])


func _test_fort() -> void:
	for key: String in ["money", "rations", "glory", "ingots"]:
		var panel: Control = camp.resource_bars[key]["panel"]
		var pic := panel.find_child("ResourceIcon", true, false) as TextureRect
		var number: Label = camp.resource_chips[key]
		check(pic != null and pic.texture != null and pic.texture == Look.resource(key) and pic.texture.get_size() == Vector2(128, 128)
			and pic.get_global_rect().size.x >= 49.0 and not number.text.is_empty(), "large icon and amount for " + key)
	check(camp.builder_counter.text == "1/1" and camp.builder_plus.visible, "idle builder HUD")
	check(camp.quest_line.visible and camp.quest_progress.text == "0/1", "pinned campaign goal")
	check(camp.campaign_button.text == I18n.t("Карта") and camp.market_button.text == I18n.t("Рынок"), "map and market buttons")
	check(camp.guide_skip.text == I18n.t("Пропустить обучение"), "clear guide skip caption")
	var vacant := 0
	for plot: Dictionary in lg.fort["plots"]:
		if plot["b"] == "" and view.plot_footprint(int(plot["id"])).intersects(Rect2(Vector2.ZERO, camp.size)):
			vacant += 1
	check(vacant >= MIN_EMPTY, "eight empty slots visible in overview")
	await shot("01_fort.png")


func _test_room() -> void:
	camp.show_building("barracks")
	await frames(6)
	check(camp.card.find_child("FortRoomDescription", true, false) == null, "room card uses metric titles and icons")
	check(camp.card.find_children("*", "ScrollContainer", true, false).is_empty(), "room card has no scrolling")
	check(camp.card.find_children("FortRoomMetricIcon", "TextureRect", true, false).size() >= 1, "room metrics have pictograms")
	check(camp.requirement_banner.visible and camp.requirement_banner.find_child("RequirementIcon", true, false) != null, "HQ requirement and lock")
	check(camp.instant_button.icon == Look.resource("ingots") and camp.upgrade_button.icon == Look.resource("money")
		and camp.upgrade_button.disabled and camp.instant_button.disabled, "both priced actions use resource icons")
	await shot("02_room_card.png")
	camp._hide_card()


func _test_build() -> void:
	var id := lg.fort_empty_plot()
	var funds := lg.city_money()
	camp.show_build_menu()
	camp._choose_build("store")
	check(camp.placement_type == "store" and lg.city_money() == funds and view.placement_rooms.size() >= MIN_EMPTY, "catalogue selects empty plots without payment")
	var hammer: Button = camp.plot_markers[id]["button"]
	check(hammer.is_visible_in_tree() and (hammer.get_node("ic") as TextureRect).texture == Look.icon("build"), "hammer in a free plot")
	hammer.pressed.emit()
	await frames(4)
	if not check(lg.camp_busy() and camp.builder_counter.text == "0/1", "builder reserved by real construction"):
		return
	var marker: Dictionary = camp.plot_markers[id]
	var cloud := view.find_child("ConstructionCloud_%d" % id, true, false) as Node2D
	var footprint: Rect2 = view.room_rects[id]
	if check(cloud != null and cloud.visible and cloud.position.is_equal_approx(footprint.position), "construction overlay at the room"):
		check(cloud.get_node_or_null("Scaffold") != null and cloud.has_node("Dust_0") and cloud.has_node("Dust_4"),
			"scaffold and dust cover the room")
	check(view.find_children("Builder_*", "", true, false).is_empty(), "no builder figure")
	var timer: Button = marker["clock"]
	check(timer.is_visible_in_tree() and timer.text != "" and view.plot_footprint(id).has_point(timer.get_global_rect().get_center() - view.global_position),
		"construction timer on room")
	(marker["clock"] as Button).pressed.emit()
	check(camp.room_actions.visible and camp.room_actions.find_child("FortRoomInfo", true, false) != null
		and camp.room_actions.find_child("FortCancelBuild", true, false) != null
		and camp.room_actions.find_child("FortSpeedUp", true, false) != null, "bottom construction bar")
	await shot("03_construction.png")
	var cancel := camp.room_actions.find_child("FortCancelBuild", true, false) as Button
	if not check(cancel != null, "cancel button available"):
		return
	cancel.pressed.emit()
	check(camp.modal_panel.name == "FortCancelConstruction" and lg.camp_busy(), "cancellation waits for confirmation")
	var quote := lg.fort_cancel_quote(id)
	var confirm := camp.modal_panel.find_child("FortConfirmCancel", true, false) as Button
	if not check(confirm != null, "cancel confirmation button"):
		return
	confirm.pressed.emit()
	check(not lg.fort_cancel(id, quote) and lg.fort_plot(id)["b"] == "" and is_equal_approx(lg.city_money(), funds), "refund applied exactly once")
	check(camp.builder_counter.text == "1/1", "builder freed after cancellation")
	camp.show_build_menu(id)
	camp._choose_build("store")
	var speed := camp.room_actions.find_child("FortSpeedUp", true, false) as Button
	if not check(speed != null, "existing construction can be accelerated"):
		return
	speed.pressed.emit()
	var finish := camp.modal_panel.find_child("FortFinishNow", true, false) as Button
	if not check(finish != null and not finish.disabled and finish.icon == Look.resource("ingots"), "speed dialog quotes gold ingots"):
		return
	var ingots := lg.ingots
	var paid := lg.city_money()
	finish.pressed.emit()
	check(lg.ingots < ingots and lg.city_money() == paid and camp.builder_counter.text == "1/1",
		"speed up charges only ingots and frees the builder")


func _test_drag(sid: int) -> void:
	var drill := int(lg.fort_slot_plot("drill")["id"])
	var target := view.project(drill)
	view.begin_person_move(sid, false, view.person_project(sid))
	view.update_person_move(target)
	check(is_instance_valid(view.drag_ghost) and view.drag_ghost._opacity < 1.0 and view.drag_target == drill, "translucent drag silhouette")
	check(camp.drag_name.visible and camp.drag_name.text == String(lg.soldier(sid)["name"]), "dweller name follows drag")
	check(camp.drag_context.visible and camp.drag_context.text.contains(I18n.t("свободно %d из %d") % [1, 2]), "training room shows free capacity")
	await shot("04_dweller_drag.png")
	view.cancel_person_move()
	check(not camp.drag_name.visible and lg.fort_is_fighter(sid), "cancel drag keeps assignment")


func _test_campaign() -> void:
	camp.campaign_button.pressed.emit()
	var ui: LegionUi = camp.lu
	var index := int(lg.frontier()["s"])
	await frames(8)
	if not check(is_instance_valid(ui.fort_map) and not ui.fort_prep_open, "map opens first"):
		return
	var stage := ui.fort_map.find_child("FortStage_%d" % index, true, false) as Button
	if not check(stage != null, "current battle on trail"):
		return
	stage.pressed.emit()
	await frames(8)
	if not check(is_instance_valid(ui.overlay), "stage opens overlay"):
		return
	var prep := ui.overlay.find_child("FortBattlePrep", true, false)
	if check(prep != null, "battle preparation modal"):
		check(prep.find_children("FortPrepSlot_*", "", true, false).size() == Legion.SQUAD_V3, "full squad slot row")
		var locked := prep.find_child("FortPrepSlot_3", true, false)
		check(locked != null and bool(locked.get_meta("locked", false)), "Barracks requirements on locked slots")
		for key: String in ["FortPrepPower", "FortPrepEnemies", "FortPrepRewards"]:
			check(prep.find_child(key, true, false) != null, key)
		check(ui._fight_btn.icon == Look.resource("rations")
			and float(ui._fight_btn.get_meta("ration_cost")) == lg.ration_cost(lg.stage_info(0, 0, index)), "button uses same ration cost as battle")
	await shot("05_battle_prep.png")
	ui._close_fort_prep()
	check(ui.fort_map.find_child("FortProvinces", true, false) != null and int(ui.sel["s"]) == index, "provinces and selected node survive back")
	var pins := ui.fort_map.find_child("FortMapNodes", true, false)
	if check(pins != null, "nodes parent"):
		var battles := 0
		var has_lock := false
		var has_boss := false
		for button: Node in pins.get_children():
			if button.has_meta("stage"):
				battles += 1
				has_lock = has_lock or bool(button.get_meta("locked"))
				has_boss = has_boss or bool(button.get_meta("boss"))
		check(battles == Legion.stages() and has_lock and has_boss, "all trail nodes, locks, and boss")
	await shot("06_map.png")
	var back := ui.fort_map.find_child("CampaignBack", true, false) as Button
	if check(back != null, "return action"):
		back.pressed.emit()
		check(camp.visible and not ui.visible, "returns to fort")


func _run() -> void:
	var waited := 0
	while not game.ready_done and waited < 18000:
		await frames(5)
		waited += 5
	if not check(game.ready_done, "ready_done timeout"):
		_finish()
		return
	if not check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory"):
		_finish()
		return
	game.can_save = false
	game.settings["autosave"] = false
	game.speed = 0.0
	Legion.clock = Time.get_unix_time_from_system()
	var sid := _populate()
	if sid == 0:
		_finish()
		return
	camp = CampUI.attach(game.hud)
	camp.open()
	camp.set_process(false)
	view = camp.diorama as FortCutaway
	if not check(is_instance_valid(view), "painted fort opened"):
		_finish()
		return
	await frames(10)
	await _test_fort()
	await _test_room()
	await _test_build()
	await _test_drag(sid)
	await _test_campaign()
	_finish()
