extends Node3D
## Проверка UI форта и пять снимков. Запускает владелец; сохранения отключены.

const Fixture = preload("res://scripts/test_fort_fixture.gd")
var out := "D:/CivCity/.work/stage3/fortui/shots/"
var game
var camp: CampUI
var lg: Legion


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
		print("FORTUI FAIL ", message)
		push_error("FORTUI FAIL " + message)
		get_tree().quit(1)
	return ok


func shot(file: String) -> bool:
	await frames(20)
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(out + file)
	if not check(error == OK, "save " + file):
		return false
	print("FORTUI SHOT ", out + file)
	return true


func build(type: String) -> int:
	var id := lg.fort_empty_plot()
	if not check(lg.fort_build(type, id), "build " + type + ": " + lg.fort_can_build(type, id)):
		return -1
	# Завершаем реальный таймер и даём зданию произвести ресурс за 3 часа.
	var plot := lg.fort_plot(id)
	plot["up"]["end"] = Legion.now() - 10800.0
	plot["t"] = Legion.now() - 11100.0
	lg.fort_finish()
	var worker := lg._add_soldier({"name": "Работник", "cls": "legionary", "stars": 1})
	check(lg.fort_assign(id, int(worker["id"])), "assign fixture worker")
	plot["t"] = Legion.now() - 10800.0
	lg.fort_finish()
	return id


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
	for i in 16:
		var house := city.place("house_pleb", Land.START + Vector2(8.0 * (i % 8), 8.0 * (i / 8)), 0.0, 0, 0, true)
		if not check(not house.is_empty(), "house %d" % i):
			return
		house["families"] = [{"name": "Юлии%d" % i, "n": 4, "cls": "plebs"}]
		house["pop"] = 4
	city.compute()
	lg = city.legion
	lg.army_tick()
	if not check(lg.v3() and int(city.stats["pop"]) >= 60, "V3 and 60 residents"):
		return
	# Чистые участки нового форта, без переноса из прежнего лагеря.
	lg.fort = {}
	lg.camp = {}
	lg.upg.clear()
	lg._camp_init()
	lg.fort["money"] = 1e6
	lg.fort["smith_knowledge"] = true
	# Эта фикстура проверяет пять новых производственных комнат.
	var treasury_fixture := lg.fort_slot_plot("treasury")
	treasury_fixture["b"] = ""
	treasury_fixture["lv"] = 0
	Fixture.set_level(lg, "hq", 3)
	lg.glory = 10000
	lg.mats = {"iron": 100.0, "wood": 100.0, "leather": 10.0}
	# Участки получаем расширением: размер совпадает с сеткой разреза.
	if not check(lg.fort_expand(), "fixture expands: " + lg.fort_can_expand()):
		return
	lg.fort["up"]["end"] = Legion.now() - 1.0
	lg.fort_finish()
	if not check(int(lg.fort["exp"]) == 1 and (lg.fort["plots"] as Array).size() == int(Legion.fort_exp_info(1)["plots"]) + 1, "fixture uses expansion grid size"):
		return
	var free_plots := 0
	for plot: Dictionary in lg.fort["plots"]:
		if int(plot["id"]) > 0 and plot["b"] == "":
			free_plots += 1
	if not check(free_plots >= 5, "fixture has room for two kitchens, smelter, sawmill and tower"):
		return
	lg.rations = 2.0
	lg.flags["camp_told"] = true
	lg.flags["camp3d_guide"] = 4
	lg.pending_resources = {"rations": 0.0, "iron": 0.0, "wood": 0.0, "leather": 0.0}
	var kitchen := build("kitchen")
	var smelter := build("smelter")
	if not check(kitchen >= 0 and smelter >= 0, "production buildings"):
		return
	if not check(float(lg.fort_plot(kitchen)["pend"]) >= 2.9 and float(lg.fort_plot(smelter)["pend"]) >= 11.9, "production accrues through API"):
		return
	city.changed.emit()
	camp = CampUI.of(game.hud)
	if not check(camp != null, "CampUI attached"):
		return
	camp.open()
	await frames(8)
	if not check(camp.resource_chips.keys() == ["money", "rations", "glory", "ingots"] and camp.chips.get_child_count() == 4, "four top resources only"):
		return
	if not check(camp.plot_markers.has(kitchen) and camp.plot_markers.has(smelter), "new plots accessible without a pavilion"):
		return
	if not check(camp.build_button.custom_minimum_size == Vector2(150, 150) and camp.campaign_button.custom_minimum_size == Vector2(76, 76), "round action sizes"):
		return
	if not await shot("1_main.png"):
		return
	camp.show_build_menu()
	if not check(camp.build_cards.size() == Legion.FORT_B.size() - 1, "all build cards"):
		return
	if not await shot("2_build_menu.png"):
		return
	camp.show_plot(kitchen)
	if not check(camp.selected_plot == kitchen and camp.main_action.text.contains(str(floori(float(lg.fort_plot(kitchen)["pend"]) + 0.0001))) and camp.main_action.get_meta("action_name") == I18n.t("Собрать %d") % floori(float(lg.fort_plot(kitchen)["pend"]) + 0.0001), "plot-based kitchen collect action"):
		return
	if not await shot("3_card_kitchen.png"):
		return
	var before := lg.rations
	camp.main_action.pressed.emit()
	if not check(lg.rations > before and not camp._collection_fx.is_empty(), "collect and fly animation"):
		return
	camp.show_building("hq")
	if not check(camp.selected_plot == int(lg.fort_slot_plot("hq")["id"]) and camp.main_action.get_meta("action_name") == I18n.t("Расширить форт"), "HQ expansion action"):
		return
	if not await shot("4_card_hq.png"):
		return
	(camp.resource_bars["rations"]["plus"] as Button).pressed.emit()
	if not check(is_instance_valid(camp.modal_panel) and not is_instance_valid(camp.card), "plus popup replaces sheet"):
		return
	if not await shot("5_plus_popup.png"):
		return
	camp._jump_to_type("kitchen")
	if not check(camp.selected_plot == kitchen, "resource jump to producing plot"):
		return
	var outside := InputEventMouseButton.new()
	outside.button_index = MOUSE_BUTTON_LEFT
	outside.pressed = true
	camp.card_backdrop.gui_input.emit(outside)
	if not check(not is_instance_valid(camp.card), "outside click closes sheet"):
		return
	Fixture.set_level(lg, "hq", 1)
	camp.show_build_menu()
	if not check((camp.build_cards["forge"]["button"] as Button).disabled and (camp.build_cards["forge"]["button"] as Button).tooltip_text.contains(I18n.t("Штаб ур. %d") % 2), "HQ gate shown on locked card"):
		return
	Fixture.set_level(lg, "hq", 3)
	camp._close_modal()
	# Тот же ресурс на втором участке: сбор не должен снимать первый буфер.
	var second := build("kitchen")
	if not check(second >= 0, "second kitchen"):
		return
	lg.rations = 0
	var first_pending := float(lg.fort_plot(kitchen)["pend"])
	camp._refresh()
	camp.show_plot(second)
	camp.main_action.pressed.emit()
	if not check(lg.rations >= 3 and absf(float(lg.fort_plot(kitchen)["pend"]) - first_pending) < 0.01, "collection uses selected plot"):
		return
	lg.rations = lg.ration_cap()
	camp._refresh()
	if not check(camp.main_action.disabled, "full storage disables collection"):
		return
	# Кнопка стройки вызывает fort_build, новый участок ждёт таймер.
	var free_ids: Array[int] = []
	for plot: Dictionary in lg.fort["plots"]:
		if int(plot["id"]) > 0 and plot["b"] == "":
			free_ids.append(int(plot["id"]))
	free_ids.sort()
	if not check(not free_ids.is_empty(), "fixture has a free cutaway room before auto-build"):
		return
	var empty := free_ids[0]
	# Порядок массива сохранения не меняет порядок комнат разреза.
	(lg.fort["plots"] as Array).reverse()
	camp.show_build_menu()
	if not check(camp.selected_plot == -1 and camp.build_plot_id == empty and lg.fort_empty_plot() == empty, "build menu targets first free cutaway room without selection"):
		return
	# строитель один: прежняя стройка (вторая кухня) должна закончиться, иначе «Строитель занят»
	var clk: float = Legion.clock
	Legion.clock = Legion.now() + 1.0e7
	lg.fort_finish()
	Legion.clock = clk
	lg.fort["money"] = maxf(lg.city_money(), 1000000.0)   # казна на стройку лесопилки (прежние шаги её потратили)
	camp._choose_build("sawmill")
	if not check(camp.selected_plot == empty and lg.fort_plot(empty)["b"] == "sawmill" and camp.card_ring.visible, "build menu auto-picks free plot"):
		return
	if not await shot("6_auto_build.png"):
		return
	if not check(camp.card.find_child("FortSpeedAction", true, false) == null, "construction has no paid money shortcut"):
		return
	Legion.clock = float(lg.fort_plot(empty)["up"]["end"])
	lg.fort_finish()
	camp._refresh()
	if not check((lg.fort_plot(empty)["up"] as Dictionary).is_empty(), "timer completes short build"):
		return
	if not check(build("tower") >= 0, "fill last expansion plot"):
		return
	while lg.fort_empty_plot() >= 0:
		if not check(build("tower") >= 0, "fill remaining expansion plot"):
			return
	# При полном форте меню ведёт к расширению, без попытки занять чужой участок.
	if not check(lg.fort_empty_plot() == -1, "fixture filled all plots"):
		return
	camp.show_build_menu()
	if not check((camp.build_cards["tower"]["button"] as Button).disabled, "full fort blocks build"):
		return
	camp.show_building("hq")
	var expansion: Dictionary = Legion.fort_exp_info(int(lg.fort["exp"]) + 1)
	if not check(lg.camp_level("hq") < int(expansion["hq"]) and lg.fort_can_expand().contains("Штаб") and camp.main_action.disabled, "next expansion gated by HQ"):
		return
	Fixture.set_level(lg, "hq", int(expansion["hq"]))
	camp._refresh()
	if not check(lg.fort_can_expand() == "" and not camp.main_action.disabled, "HQ expansion allowed: " + lg.fort_can_expand()):
		return
	camp.main_action.pressed.emit()
	if not check(not (lg.fort["up"] as Dictionary).is_empty(), "HQ starts expansion: " + lg.fort_can_expand()):
		return
	if not check(camp.card_ring.visible, "HQ expansion timer visible"):
		return
	lg.fort["up"]["end"] = Legion.now() - 1
	lg.fort_finish()
	camp._refresh()
	if not check(lg.fort_empty_plot() >= 0, "expansion provides plots"):
		return
	# Бедная казна: цена и доступность обновляются, не только при открытии меню.
	camp.show_build_menu()
	lg.fort["money"] = 0.0
	camp._refresh()
	if not check((camp.build_cards["tower"]["button"] as Button).disabled, "unaffordable build blocked"):
		return
	lg.fort["money"] = 1000000.0
	camp._close_modal()
	camp.show_stocks()
	if not check(camp.stock_labels.size() == 3, "warehouse material amounts and caps"):
		return
	camp._close_modal()
	var arsenal := build("arsenal")
	if not check(arsenal >= 0 and not lg.camp_built("store"), "arsenal without warehouse fixture"):
		return
	camp.show_plot(arsenal)
	camp.main_action.pressed.emit()
	if not check(camp.lu.camp_window == "craft" and camp.lu.visible and camp.lu._craft_plot == arsenal, "arsenal opens its craft queue without warehouse"):
		return
	camp.lu.open_camp_window("store")
	if not check(camp.lu.camp_window == "store" and camp.lu.visible, "craft panel opens shared gear storage"):
		return
	camp.lu.close()
	# Новый порядок: стройка → кухня → назначение и сбор → поход.
	lg.flags["camp3d_guide"] = 1
	camp.show_build_menu()
	if not check(int(lg.flags["camp3d_guide"]) == 2, "guide build menu"):
		return
	var guide_kitchen := int(lg.fort_slot_plot("kitchen")["id"])
	camp._choose_build("kitchen")
	if not check(int(lg.flags["camp3d_guide"]) == 0 and camp.selected_plot == guide_kitchen, "guide kitchen waits for collect"):
		return
	lg.rations = 0
	lg.fort_plot(guide_kitchen)["t"] = Legion.now() - 7200
	lg.fort_finish()
	var before_collect := lg.rations
	camp._collect_plot(guide_kitchen)
	if not check(int(lg.flags["camp3d_guide"]) == 3 and lg.rations > before_collect, "guide collect"):
		return
	camp._campaign()
	if not check(int(lg.flags["camp3d_guide"]) == 4, "guide campaign"):
		return
	camp.lu.close()
	camp.close()
	await frames(3)
	if not check(not camp.visible and not game.get_viewport().disable_3d, "closing restores city"):
		return
	print("FORTUI DONE")
	get_tree().quit()
