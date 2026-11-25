extends Node3D

const TestSuite = preload("res://scripts/test_perf14a3_suite.gd")

const Step = Legion.FortGuide
const Look = preload("res://scripts/legion_look.gd")
const Fixture = preload("res://scripts/test_fort_fixture.gd")
const PersonLook = preload("res://scripts/legion_person_look.gd")
const OUTPUT := "D:/CivCity/.work/stage7/legion12/shots/"

var out := OUTPUT
var game: Game
var camp: CampUI
var legion: Legion
var fails := 0
var actions := 0
var tutorial_wait := 0.0
var longest_wait := 0.0


signal check_done
var embedded_output := ""


func _ready() -> void:
	if not embedded_output.is_empty():
		out = embedded_output
	for arg: String in OS.get_cmdline_user_args() if embedded_output.is_empty() else []:
		if arg.begins_with("out=") and arg.length() > 4:
			out = arg.trim_prefix("out=").trim_suffix("/") + "/"
	if not check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory " + out):
		print("LEGION12 DONE fails=", fails)
		_finish_check(1)
		return
	Game.boot = {"new": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	add_child(game)
	game.can_save = false
	var previous_clock := Legion.clock
	await _run()
	Legion.clock = previous_clock
	print("LEGION12 DONE fails=", fails)
	_finish_check(int(fails != 0))


func _finish_check(code: int) -> void:
	if embedded_output.is_empty():
		TestSuite.finish(self, code)
	else:
		check_done.emit()


func check(ok: bool, reason: String) -> bool:
	if not ok:
		fails += 1
		print("LEGION12 FAIL ", reason)
	return ok


func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func ready_ui() -> void:
	await frames(6)
	var deadline := Time.get_ticks_msec() + 10000
	while camp.opening and Time.get_ticks_msec() < deadline:
		await frames(1)
	check(not camp.opening, "fort room controls ready")
	camp._layout_guide()
	await frames(2)


func shot(name_text: String) -> void:
	await ready_ui()
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	var path := out + name_text + ".png"
	if check(get_viewport().get_texture().get_image().save_png(path) == OK, "PNG " + name_text):
		print("LEGION12 SHOT ", path)


func resize(pixels: Vector2i) -> void:
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = pixels
	await frames(10)
	check(get_viewport().get_visible_rect().size.is_equal_approx(Vector2(pixels)), "viewport " + str(pixels))


func spot(context: String, target: Control = null) -> void:
	camp._layout_guide()
	check(camp.guide_pointer.is_visible_in_tree() and camp._guide_rect.has_area(), "guide arrow " + context)
	check(get_viewport().get_visible_rect().grow(1.0).encloses(camp._guide_rect), "guide bounds " + context)
	if target != null:
		check(camp._guide_target == target and target.is_visible_in_tree(), "guide target " + context)


func tap(button: Button, context: String, guided := true) -> bool:
	await ready_ui()
	if not check(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled, "button " + context):
		return false
	if guided:
		spot(context, button)
		actions += 1
	button.pressed.emit()
	return true


func drag(sid: int, room: int, newcomer: bool) -> bool:
	await ready_ui()
	spot("person %d" % sid)
	var view := camp.diorama as FortCutaway
	if not check(is_instance_valid(view), "fort cutaway ready for drag"):
		return false
	view.begin_person_move(sid, newcomer, view.person_project(sid, newcomer))
	view.update_person_move(view.project(room))
	await ready_ui()
	spot("drop %d" % room)
	actions += 1
	return check(view.finish_person_move(view.project(room)), "move %d to %d" % [sid, room])


func scan_ui(node: Node, context: String, fit := false) -> void:
	if node is Control and node.is_visible_in_tree():
		var texts: Array[String] = [node.tooltip_text]
		if node is Button or node is Label:
			texts.append(node.text)
		for value: String in texts:
			var lower := value.to_lower()
			check(not lower.contains("пайк") and not lower.contains("паёк") and not lower.contains("пайок"), "food wording " + context + " " + value)
		if fit and node is Label and node.text != "":
			var label := node as Label
			var detail := "%s [%s] %s" % [context, label.name, label.text]
			check(label.get_visible_line_count() == label.get_line_count(), "label height " + detail)
			if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
				var font := label.get_theme_font("font")
				var pixels := label.get_theme_font_size("font_size")
				for line: String in label.text.split("\n"):
					var width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
					check(width <= label.size.x + 2.0, "label width %s (%.0f / %.0f)" % [detail, width, label.size.x])
			var parent := label.get_parent()
			while parent is Control and not (parent is ScrollContainer):
				parent = parent.get_parent()
			if not (parent is ScrollContainer):
				check(get_viewport().get_visible_rect().grow(2.0).encloses(label.get_global_rect()), "label bounds " + detail)
	for child: Node in node.get_children():
		scan_ui(child, context, fit)


func _run() -> void:
	var waited := 0
	while not game.ready_done and waited < 18000:
		await frames(5)
		waited += 5
	if not check(game.ready_done, "game ready"):
		return
	game.settings["autosave"] = false
	game.hud.set_speed(0.0)
	await resize(Vector2i(1920, 1080))
	var city := game.city
	city.legion_v = 3
	city.cozy_v = 1
	legion = city.legion
	legion.sync_v2()
	Legion.clock = 1900000000.0
	legion.flags["camp_open"] = true
	camp = CampUI.attach(game.hud)
	camp.open()
	if not check(legion.fort_guide_step() == Step.FIRST_BATTLE and legion.squad_count() == 2, "starter squad and guide"):
		return
	balance()
	await ready_ui()
	scan_ui(camp, "fort", true)
	spot("first battle", camp.campaign_button)
	await ready_ui()
	var first := legion.stage_info(0, 0, 0)
	for seed in range(1, 21):
		var result := LegionSim.new(legion.make_battle(first, seed)).run(false)
		check(result["win"] and int(result["alive"]) == 2, "opening ×1 seed %d" % seed)
		check(float(result["time"]) <= 10.0, "opening length seed %d" % seed)
	print("LEGION12 SEEDS 20")
	if not await fight(0):
		return
	if not check(legion.fort_guide_step() == Step.TREASURY, "rescued at the gate"):
		return
	if not await outfit_step("treasury", "scribe"):
		return
	if not await outfit_step("kitchen", "cook"):
		return
	var before := legion.city_money()
	await ready_ui()
	spot("HQ room")
	camp._select_fort_room("plot_0")
	actions += 1
	await ready_ui()
	scan_ui(camp, "HQ window", true)
	var upgrade := camp.modal_panel.find_child("FortHQConfirm", true, false) as Button
	check(upgrade != null and upgrade.text.contains("Бесплатно"), "HQ free label")
	if not await tap(upgrade, "HQ confirm"):
		return
	check(legion.camp_level("hq") == 2 and legion.fort_plot_timer(0).is_empty() and legion.city_money() == before, "free instant HQ2")
	if not await tap(camp.build_button, "build"):
		return
	await ready_ui()
	var build := camp.build_cards.get("store", {}).get("button") as Button
	if not await tap(build, "store catalog"):
		return
	var empty := legion.fort_empty_plot()
	spot("empty plot")
	camp._select_fort_room("plot_%d" % empty)
	actions += 1
	if not check(legion.fort_plot(empty).get("b") == "store" and legion.fort_plot_timer(empty).is_empty() and legion.city_money() == before, "free instant store"):
		return
	var arrivals := legion.fort_newcomers()
	if not check(not arrivals.is_empty(), "third arrival"):
		return
	var learner := int(arrivals[0]["id"])
	var barracks := int(legion.fort_slot_plot("barracks")["id"])
	var food := legion.rations
	if not await drag(learner, barracks, true):
		return
	await ready_ui()
	var wait := legion.s_left(legion.soldier(learner))
	check(wait > 0 and wait <= 10.0 and legion.rations == food, "training is free and takes 10 seconds")
	waited_for(wait)
	check(legion.soldier(learner)["rank"] == 1, "training leveled third dweller")
	await ready_ui()
	if not await drag(learner, 0, false):
		return
	check(legion.squad_count() == 3 and legion.fort_guide_step() == Step.SECOND_BATTLE, "third squad place")
	if not await fight(1):
		return
	check(legion.fort_guide_step() == Step.FINISH, "finish after second victory")
	if not await tap(camp.guide_skip, "finish guide", false):
		return
	check(legion.fort_guide_step() == Step.DONE, "guide saved as done")
	camp.show_plot(empty)
	await ready_ui()
	await polish_screens(empty, barracks)
	await model_checks(barracks, learner)
	pacing()


func check_places(root: Control, prefix: String, locks: Dictionary) -> void:
	if not check(is_instance_valid(root), "place list " + prefix):
		return
	for index in Legion.SQUAD_V3:
		var place := root.find_child(prefix + str(index), true, false) as Control
		if not check(place != null, "place %s%d" % [prefix, index]):
			continue
		if prefix == "FortPrepSlot_":
			check(bool(place.get_meta("locked")) == locks.has(index), "stage lock state %d" % index)
		elif place is Button:
			check((place as Button).disabled == locks.has(index), "squad lock state %d" % index)
		if not locks.has(index):
			continue
		var title := I18n.t("Штаб %s") % Legion.roman(int(locks[index]))
		if place is Button:
			var button := place as Button
			check(button.icon == Look.icon("lock") and button.text == title and not button.clip_text,
				"squad lock " + title)
		else:
			var icon := place.get_child(0)
			var caption := place.get_child(1) as Label
			var texture: Texture2D = icon.icon if icon is Button else icon.texture
			check(texture == Look.icon("lock") and caption != null and caption.text == title, prefix + title)


func check_hq() -> void:
	var action := camp.main_action
	check(action.text == I18n.t("Расширить форт") and action.icon != null and action.icon == FortCutaway.room_icon("hq") and action.is_visible_in_tree(),
		"labelled expansion action")
	check(camp.upgrade_button.text == I18n.t("Улучшить") and camp.upgrade_button.is_visible_in_tree(), "separate HQ upgrade")
	var cost := camp.card_body.get_node("FortExpansionCost") as HBoxContainer
	var info := legion.fort_expansion_info()
	var numbers: Dictionary = cost.get_child(0).get_meta("cost_labels")
	check((numbers["money"] as Label).text == game.hud.fmt(info["cost"]["money"])
		and (cost.get_child(2).get_child(1) as Label).text == CampUI.duration_text(float(info["seconds"])), "expansion price and time")
	var reason := camp.card_body.get_node("FortExpansionReason") as Label
	check(action.disabled and reason.is_visible_in_tree() and reason.text.contains(str(info["hq"])), "HQ expansion lock reason")
	check_places(camp.card, "FortHQPlace_", {3: 4, 4: 6})
	for index in Legion.SQUAD_V3:
		var sid := int(legion.squad3[index])
		if sid == 0:
			continue
		var seat := camp.card.find_child("FortHQPlace_%d" % index, true, false)
		var face := seat.find_child("FortPortraitArt", true, false) as TextureRect
		var person := legion.soldier(sid)
		if check(face != null and face.has_meta("person_portrait"), "individual portrait %d" % sid):
			var look: Dictionary = face.get_meta("portrait_look")
			check(look == PersonLook.ensure(person), "portrait matches dweller %d" % sid)
			if bool(person.get("hero", false)):
				check(int(face.get_meta("portrait_crown")) > 0, "hero wears the wreath")


func polish_screens(store: int, barracks: int) -> void:
	# Проверяем размеры в обычном форте и переход из урока в окно улучшения.
	camp.show_plot(0)
	await ready_ui()
	scan_ui(camp.card, "guided HQ 1080p", true)
	await resize(Vector2i(1280, 720))
	await ready_ui()
	scan_ui(camp.card, "guided HQ 720p", true)
	await resize(Vector2i(1920, 1080))
	camp.show_hq_upgrade(0)
	await ready_ui()
	scan_ui(camp.modal_panel, "HQ upgrade 1080p", true)
	camp._close_modal()
	var save := snapshot()
	var hero := int(legion.hero_dweller()["id"])
	for pixels: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		var large := pixels.y == 1080
		var resolution := "%dp" % pixels.y
		await resize(pixels)
		camp.show_building("hq")
		await shot("1_hq_card" if large else "5_720p_hq_card")
		check_hq()
		scan_ui(camp, "HQ " + resolution, true)
		camp.upgrade_button.pressed.emit()
		await ready_ui()
		scan_ui(camp.modal_panel, "HQ upgrade " + resolution, true)
		camp.show_squad()
		if large:
			await shot("4_squad_tab")
		else:
			await ready_ui()
		check_places(camp.modal_panel, "FortSquadPlace_", {3: 4, 4: 6})
		scan_ui(camp.modal_panel, "squad " + resolution, true)
		camp.show_dweller(hero, Gear.OUTFIT_SLOT)
		await ready_ui()
		scan_ui(camp.modal_panel, "dweller and outfit " + resolution, true)
		camp.show_resource_popup("rations")
		await ready_ui()
		scan_ui(camp.modal_panel, "food popup " + resolution, true)
		for room: String in ["kitchen", "treasury", "store"]:
			camp.show_plot(store if room == "store" else int(legion.fort_slot_plot(room)["id"]))
			await ready_ui()
			scan_ui(camp.card, room + " " + resolution, true)
		camp._campaign()
		await ready_ui()
		scan_ui(camp.lu, "map " + resolution, true)
		camp.lu.open_fort_stage(0, 0, 1)
		await ready_ui()
		if large:
			await shot("2_stage_card_locked_places")
		var prep := camp.lu.overlay.find_child("FortBattlePrep", false, false) as Control
		check_places(prep, "FortPrepSlot_", {3: 4, 4: 6})
		scan_ui(prep, "stage card " + resolution, true)
		camp.lu.close()
		check(legion.fort_assign(barracks, hero), "barracks trainee " + resolution)
		camp.show_plot(barracks)
		if large:
			await shot("3_barracks_card")
		else:
			await ready_ui()
		var terms := camp.card.find_child("FortTrainingTerms", true, false) as HBoxContainer
		var price := terms.get_node("FortTrainingPrice") as Label
		var food := terms.get_node("FortTrainingFood") as TextureRect
		var clock := terms.get_node("FortTrainingClock") as TextureRect
		var time := terms.get_node("FortTrainingTimer") as Label
		check(food.texture == Look.resource("rations") and price.text == "50"
			and (terms.get_child(2) as Label).text == "·" and clock.texture == Look.icon("timer") and clock.is_visible_in_tree()
			and time.text == CampUI.duration_text(60.0) and terms.get_theme_constant("separation") >= 8,
			"separated barracks price and time " + resolution)
		check(camp.main_action.text == I18n.t("Назначить") and camp.main_action.icon == Look.icon("assign")
			and camp.main_action.icon_alignment == HORIZONTAL_ALIGNMENT_LEFT, "assignment icon beside text " + resolution)
		scan_ui(camp.card, "barracks " + resolution, true)
		camp.main_action.pressed.emit()
		await ready_ui()
		scan_ui(camp.modal_panel, "worker picker " + resolution, true)
		camp._close_modal()
		legion.from_dict(save.duplicate(true))
		camp._refresh()
		await expansion_flow(resolution)
		legion.from_dict(save.duplicate(true))
		camp._refresh()
		camp.close()
		var previous_rank := game.city.level
		game.city.level = int(Magis.magistracy("tribunus")["rank"])
		var magis := MagisUI.of(game.hud)
		magis.open()
		(magis.cards["trib_scant_rations"] as Button).pressed.emit()
		await frames(8)
		if check(is_instance_valid(magis.popup_panel) and magis.popup_panel.is_visible_in_tree(), "ration edict " + resolution):
			scan_ui(magis.popup_panel, "ration edict " + resolution, true)
		magis.close()
		game.city.level = previous_rank
		camp.open()
		print("LEGION12 UI ", resolution)
	await resize(Vector2i(1920, 1080))


func expansion_flow(resolution: String) -> void:
	Fixture.set_level(legion, "hq", 3)
	var expansion := legion.fort_expansion_info()
	legion.fort["money"] = expansion["cost"]["money"]
	for resource: String in expansion["cost"]["mats"]:
		legion.mats[resource] = expansion["cost"]["mats"][resource]
	camp.show_building("hq")
	if await tap(camp.main_action, "unlocked HQ expansion", false):
		await ready_ui()
		var floor := camp.modal_panel.find_child("FortExpand_floor", true, false) as Button
		var section := camp.modal_panel.find_child("FortExpand_section", true, false) as Button
		check(floor != null and not floor.disabled and section != null and not section.disabled, "both expansion directions reached from HQ")
		scan_ui(camp.modal_panel, "expansion choice " + resolution, true)
		if await tap(section, "expand by a section", false):
			await ready_ui()
			check(camp.modal_panel.name == "FortExpansionCard" and camp.modal_panel.find_child("FortExpand_section", true, false) == null,
				"expansion choice opens confirmation")
			scan_ui(camp.modal_panel, "expansion confirmation " + resolution, true)
			var confirm := camp.modal_panel.find_child("FortExpansionConfirm", true, false) as Button
			if await tap(confirm, "confirm expansion to the side", false):
				var timer := legion.fort_plot_timer(0)
				check(timer.get("axis") == "section" and legion.city_money() == 0.0
					and camp.modal_panel == null, "HQ expansion starts and charges once " + resolution)
				await ready_ui()
				if check(is_instance_valid(camp.card) and is_instance_valid(camp.card_ring) and camp.card_ring.is_visible_in_tree(),
					"HQ returns with expansion timer " + resolution):
					scan_ui(camp.card, "expansion timer " + resolution, true)
	camp._close_modal()
	camp._hide_card()


func balance() -> void:
	check(Legion.fort_production("kitchen", 1).get("rate") == 100 and Legion.fort_production("kitchen", 1).get("cap") == 1000, "kitchen L1")
	check(Legion.fort_production("kitchen", 2).get("rate") == 200 and Legion.fort_production("kitchen", 2).get("cap") == 2000, "kitchen L2")
	check(Legion.fort_production("treasury", 1).get("rate") == 200 and Legion.fort_production("treasury", 1).get("cap") == 1500, "treasury L1")
	for level in range(2, 5):
		check(legion.fort_build_seconds("hq", level) == [5.0, 900.0, 1800.0][level - 2], "HQ time %d" % level)
	check(legion.ration_cost(Legion.stage(0, 0, 1)) == 100 and legion.ration_cost(Legion.stage(0, 0, Legion.stages() - 1)) == 200, "campaign and boss cost")


func waited_for(seconds: float) -> void:
	Legion.clock += seconds
	tutorial_wait += seconds
	longest_wait = maxf(longest_wait, seconds)
	legion.army_tick()
	camp._refresh()


func fight(index: int) -> bool:
	if not await tap(camp.campaign_button, "map"):
		return false
	await ready_ui()
	if not check(is_instance_valid(camp.lu.fort_map), "fort map"):
		return false
	scan_ui(camp.lu, "map", true)
	if index == 1:
		scan_ui(camp.lu, "map stage card", true)
	if not await tap(camp.lu.guide_stage_button, "stage %d" % index):
		return false
	await ready_ui()
	var fight_button: Button = camp.lu._fight_btn
	var prep := camp.lu.overlay.find_child("FortBattlePrep", false, false) as Control
	var locks := {2: 2, 3: 4, 4: 6} if index == 0 else {3: 4, 4: 6}
	check_places(prep, "FortPrepSlot_", locks)
	scan_ui(camp.lu, "tutorial stage card", true)
	if index == 1:
		await resize(Vector2i(1280, 720))
		await ready_ui()
		scan_ui(camp.lu, "tutorial stage card 720p", true)
		check_places(prep, "FortPrepSlot_", locks)
		await resize(Vector2i(1920, 1080))
	var cost := 0 if index == 0 else 100
	var food := legion.rations
	check(int(fight_button.get_meta("ration_cost", -1)) == cost, "displayed cost %d" % index)
	if cost > 0:
		check(fight_button.icon == Look.resource("rations") and fight_button.text.ends_with("100"), "bread icon and whole cost")
	if not await tap(fight_button, "fight %d" % index):
		return false
	check(is_equal_approx(food - legion.rations, float(cost)), "food deduction %d" % index)
	var battle := LegionBattle.current
	if not check(is_instance_valid(battle), "battle launched"):
		return false
	battle.speed = 8.0
	var deadline := Time.get_ticks_msec() + 60000
	while is_instance_valid(battle) and battle.phase != "result" and Time.get_ticks_msec() < deadline:
		await frames(3)
	if not check(is_instance_valid(battle) and battle.phase == "result", "battle result"):
		return false
	check(bool(battle.out.get("win", false)), "tutorial victory %d" % index)
	var seconds := float(battle.out.get("time", 0.0))
	tutorial_wait += seconds
	longest_wait = maxf(longest_wait, seconds)
	if index == 0:
		check((battle.out.get("rescued", []) as Array).size() == 3, "rescued three people")
		check(battle.find_child("FortRescuedRewards", true, false) != null, "rescued reward row")
		await ready_ui()
		scan_ui(battle.modal, "rescued rewards 1080p", true)
		await resize(Vector2i(1280, 720))
		await frames(8)
		scan_ui(battle.modal, "rescued rewards 720p", true)
		await resize(Vector2i(1920, 1080))
	if not await tap(battle.find_child("LegionBattleReturn", true, false) as Button, "return to fort", false):
		return false
	deadline = Time.get_ticks_msec() + 8000
	while not camp.visible and Time.get_ticks_msec() < deadline:
		await frames(3)
	print("LEGION12 BATTLE stage=%d time=%.2f" % [index + 1, seconds])
	return check(camp.visible, "battle returns to fort")


func outfit_step(type: String, kind: String) -> bool:
	var arrivals := legion.fort_newcomers()
	if not check(not arrivals.is_empty(), "newcomer " + type):
		return false
	var sid := int(arrivals[0]["id"])
	var id := int(legion.fort_slot_plot(type)["id"])
	if not await drag(sid, id, true):
		return false
	var outfit := int(legion.flags.get("fort_guide_item", 0))
	check(Gear.work_kind(legion.item(outfit)) == kind, "outfit drop " + type)
	await ready_ui()
	spot("open dweller " + type)
	actions += 1
	camp.show_dweller(sid)
	var slot := camp.modal_panel.find_child("FortGear_outfit", true, false) as Button
	if not await tap(slot, "outfit slot " + type):
		return false
	await ready_ui()
	scan_ui(camp.modal_panel, "outfit picker " + type, true)
	var option := camp.modal_panel.find_child("FortEquip_%d" % outfit, true, false) as Button
	if not await tap(option, "equip " + type):
		return false
	if int(legion.item(outfit).get("on", 0)) != sid:
		await ready_ui()
		var equip := camp.modal_panel.find_child("FortItemEquip", true, false) as Button
		if not await tap(equip, "confirm outfit " + type):
			return false
	check(int(legion.item(outfit).get("on", 0)) == sid and legion.work_bonus(legion.soldier(sid), kind) > 0.0, "outfit worn " + type)
	await ready_ui()
	var collect := camp.plot_markers.get(id, {}).get("collect") as Button
	var resource := "money" if type == "treasury" else "rations"
	check(collect != null and collect.icon == Look.resource(resource), "collect icon " + type)
	return await tap(collect, "collect " + type)


func snapshot() -> Dictionary:
	return JSON.parse_string(JSON.stringify(legion.to_dict())) as Dictionary


func synced() -> bool:
	var ids: Array = legion.fort_occupants(0).map(func(person: Dictionary): return int(person["id"]))
	return ids == legion.squad3.filter(func(id: int): return id != 0)


func model_checks(barracks: int, learner: int) -> void:
	var save := snapshot()
	check(synced(), "squad matches room")
	var hero := int(legion.hero_dweller()["id"])
	var kitchen := int(legion.fort_slot_plot("kitchen")["id"])
	check(legion.fort_assign(kitchen, hero) and synced() and not legion.squad3.has(hero), "hero works outside squad")
	var cook := legion.add_item(Gear.craft_item("cook", 1))
	check(legion.equip(hero, int(cook["id"])) and legion.work_bonus(legion.soldier(hero), "cook") > 0.0, "hero uses work outfit")
	await ready_ui()
	var stage := legion.stage_info(0, 0, 0)
	check(LegionSim.new(legion.make_battle(stage, 100)).run(false)["win"], "battle without hero")
	var food := legion.rations
	check(legion.fort_assign(barracks, hero) and legion.rations == food - 50.0 and legion.s_state(legion.soldier(hero)) == "train", "hero starts paid training")
	check(not legion.squad3.has(hero), "training outside squad")
	legion.soldier(hero)["rank"] = Legion.training_cap(1) - 1
	legion.soldier(hero)["train_end"] = 0.0
	check(not legion.train(hero), "room training cap")
	check(legion.set_place(4, hero) and synced() and legion.squad3[4] == hero, "hero joins in back row")
	check(legion.set_place(0, hero) and synced() and legion.squad3[0] == hero, "reorder swaps and keeps membership")
	check(legion.set_place(4, hero) and not legion.dismiss(hero), "hero moved and protected from release")
	legion.from_dict(snapshot())
	check(synced() and legion.squad3[4] == hero and legion.hero_level() == Legion.training_cap(1), "hero and squad survive save/load")
	check(legion.fort_drop(-1, learner) and synced() and not legion.squad3.has(learner), "drop to yard")
	legion.from_dict(save.duplicate(true))
	lesson_checks()
	legion.from_dict(save.duplicate(true))
	migration_checks()
	legion.from_dict(save.duplicate(true))
	camp._refresh()


func lesson_checks() -> void:
	var store := legion.fort_slot_plot("store")
	store["b"] = ""
	store["lv"] = 0
	legion.rations = legion.ration_cap()
	legion.fort["money"] = 0
	legion.flags["fort_lessons"] = {}
	legion.flags.erase("fort_lesson_active")
	legion.watch_fort_lessons()
	check(legion.fort_lesson_state("store") == "" and legion.fort_lesson_state("knowledge") == "", "locked lessons wait")
	store["b"] = "store"
	store["lv"] = 1
	legion.rations = legion.ration_cap()
	legion.fort["money"] = 30000
	legion.watch_fort_lessons()
	check(legion.fort_lesson() == "store", "store lesson after affordable store exists (%s, %s)" % [legion.fort_lesson(), legion.fort_can_upgrade(int(store["id"]))])


func migration_checks() -> void:
	var old := snapshot()
	old["fort"].erase("roles_v")
	old["flags"].erase("fort_guide_v")
	old["flags"].erase("fort_economy_v")
	old["flags"]["fort_guide"] = 6
	old["progress"] = 1
	old["hero_lv3"] = 5
	old["hero_training"] = {"to": 6, "end": Legion.now() + 60.0, "total": 60.0}
	var old_squad: Array = (old["squad3"] as Array).map(func(id: Variant): return int(id))
	var plots: Array = old["fort"]["plots"]
	var drill := int(legion.fort_empty_plot())
	var worker := int(legion.fort_occupants(int(legion.fort_slot_plot("treasury")["id"]))[0]["id"])
	for person: Dictionary in old["soldiers"]:
		if int(person["id"]) == worker:
			person["train_plot"] = drill
			person["train_end"] = Legion.now() + 90.0
	for plot: Dictionary in plots:
		if plot["b"] == "barracks":
			plot["workers"] = old_squad.filter(func(id): return int(id) != 0)
		if int(plot["id"]) == drill:
			plot["b"] = "drill"
			plot["lv"] = 2
	old["mats"] = {"wood": 40.0, "iron": 40.0, "leather": 40.0}
	legion.from_dict(old)
	check(legion.squad3 == old_squad and synced(), "migration keeps the old squad: %s vs %s" % [legion.squad3, old_squad])
	check(legion.fort_plot(drill)["b"] == "" and legion.mat("wood") > 7900, "drill emptied and refunded")
	check(legion.hero_level() == 5 and legion.s_state(legion.hero_dweller()) == "train", "old hero level and timer")
	check(legion.fort_plot(legion.fort_worker_plot(worker)).get("b") == "barracks", "old trainee moved")
	check(legion.fort_guide_step() == Step.SECOND_BATTLE, "old guide resumes near current progress")


func pacing() -> void:
	# 20 секунд на чтение, выбор и жест. Бои и постройки используют часы модели.
	var tutorial := actions * 19.0 + tutorial_wait
	check(tutorial >= 300.0 and tutorial <= 480.0 and longest_wait <= 10.0, "tutorial pace")
	var original := snapshot()
	var origin := Legion.now() - tutorial
	var next_battle := Legion.now()
	var last_loss := -1
	var stage_attempts := 0
	var reached := {2: tutorial / 60.0}
	for i in 1200:
		legion.army_tick()
		var level := legion.camp_level("hq")
		if not reached.has(level):
			reached[level] = (Legion.now() - origin) / 60.0
		if level >= 5:
			break
		for type: String in ["treasury", "kitchen"]:
			legion.fort_collect(int(legion.fort_slot_plot(type)["id"]))
		if legion.fort_can_upgrade(0) == "":
			legion.fort_upgrade(0)
		elif Legion.now() >= next_battle and legion.city_money() < legion.money_cap():
			var front := legion.frontier()
			var index := int(front["s"])
			if last_loss == legion.progress:
				index = maxi(0, index - 1)
			var st := legion.stage_info(int(front["cycle"]), int(front["r"]), index)
			if legion.can_fight(st) == "":
				var setup := legion.prepare_battle(st)
				var result := LegionSim.new(setup).run(false)
				legion.apply_result(setup, result)
				stage_attempts += 1
				if not bool(result["win"]):
					last_loss = legion.progress
				if stage_attempts <= 12:
					print("LEGION12 GREEDY stage=%d win=%s stock=%d" % [int(st["idx"]) + 1, result["win"], legion.city_money()])
				next_battle = Legion.now() + maxf(10.0, float(result["time"]))
		Legion.clock += 15.0
	print("LEGION12 PACE tutorial=%.2f min max_wait=%.2f sec HQ=%s" % [tutorial / 60.0, longest_wait, str(reached)])
	check(float(reached.get(3, -1)) >= 15.0 and float(reached.get(3, 999)) <= 25.0, "HQ3 pace")
	check(float(reached.get(4, -1)) >= 30.0 and float(reached.get(4, 999)) <= 60.0, "HQ4 pace")
	check(float(reached.get(5, -1)) >= 85.0 and float(reached.get(5, 999)) <= 240.0, "HQ5 pace")
	legion.from_dict(original)
