extends Node3D

const TestSuite = preload("res://scripts/test_perf14a3_suite.gd")
const OUTPUT := "D:/CivCity/.work/stage7/polish18/shots"

class ArenaFixture extends RefCounted:
	var me_state := {
		"name": "Рим", "rating": 420, "def_wins": 1,
		"arena": {"league": 0, "league_name": "Бронза", "season": 1, "ends_in": 123456,
			"leagues": [["Бронза", 0], ["Серебро", 600]], "next": {"name": "Серебро", "at": 600},
			"money": [200], "glory": [4], "s_att": 1, "min_att": 3}
	}

	var opponents: Array = []

	func pvp_opponents(callback: Callable) -> void:
		callback.call(opponents, "")

var game: Game
var camp: CampUI
var legion: Legion
var fails := 0
var out := OUTPUT


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=")
	Game.boot = {"new": "1", "nologin": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	add_child(game)
	game.can_save = false
	var original_hero := Legion.pvp_hero_srv
	await _run()
	Legion.pvp_hero_srv = original_hero
	print("POLISH18 DONE fails=", fails)
	TestSuite.finish(self, int(fails > 0))


func _run() -> void:
	if not _check(DisplayServer.get_name() != "headless", "нужно окно для снимков"):
		return
	var startup: WeakRef = weakref(game.loading)
	if not _check(await _wait(func(): return game.ready_done and (startup == null or startup.get_ref() == null), 90000), "загрузка города"):
		return
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1920, 1080)
	game.settings["autosave"] = false
	game.tutorial.finish()
	game.hud.set_speed(0.0)
	game.city.legion_v = 3
	game.city.cozy_v = 1
	legion = game.city.legion
	legion.sync_v2()
	legion.flags["camp_open"] = true
	camp = CampUI.attach(game.hud)
	camp.open()
	if not _check(await _wait(func(): return not camp.opening and camp.guide_pointer.is_visible_in_tree()), "стрелка в форте"):
		return
	await _map()
	await _arena()
	await _victory()


func _map() -> void:
	var old_target := str(camp.campaign_button.get_instance_id())
	_check(camp._guide_arrow_id == old_target, "стрелка у кнопки Карта")
	camp.campaign_button.pressed.emit()
	var deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline:
		await RenderingServer.frame_post_draw
		if camp.lu.visible and camp.guide_pointer.is_visible_in_tree():
			if not _check(camp._guide_arrow_id != old_target, "стрелка осталась на кнопке Карта"):
				return
			var pin := camp.lu.guide_stage_button
			if is_instance_valid(pin) and camp._guide_target == pin:
				_check(not camp._guide_arrow_draw_gliding and camp._guide_rect.has_area(), "скачок сразу к миссии")
				_check(absf(camp.guide_pointer.position.x + camp.guide_pointer.size.x * camp.guide_pointer.scale.x * 0.5
					- camp.guide_spotlight.get_center().x) < 4.0, "стрелка над первой миссией")
				_shot("01_map_first_target")
				return
	_check(false, "не появилась стрелка у первой миссии")


func _arena() -> void:
	legion.free_mode = true
	Legion.pvp_hero_srv = true
	var ui := camp.lu
	ui._net_checked = true
	var fixture := ArenaFixture.new()
	ui._net_obj = fixture
	var look := {"sx": 1, "skin": "C", "hair": 5, "hc": "S", "cape": "2f5585", "main": "4d7397", "crown": 2}
	fixture.opponents = [
		{"name": "Остия", "rating": 440, "city_level": 3, "snapshot": {"squad": [
			{"type": "hero", "level": 3, "name": "Аврелия", "look": look}, {"type": "archer", "level": 2}]}},
		{"name": "Капуя", "rating": 320, "bot": true, "snapshot": {"squad": [
			{"type": "legionary", "level": 2}, {"type": "priest", "level": 1}, {"type": "cavalry", "level": 1}]}}
	]
	ui.open("pvp")
	if not _check(await _wait(func(): return ui.find_child("rival_hero", true, false) != null), "окно арены"):
		return
	var body := ui.content.get_child(0) as HBoxContainer
	var left := body.get_child(0) as VBoxContainer
	_check(ui.find_child("FortPvpDefense", true, false) != null, "????? ???????")
	for panel: PanelContainer in left.get_children():
		var margin := panel.get_theme_stylebox("panel")
		_check(margin.get_margin(SIDE_LEFT) >= 18.0 and margin.get_margin(SIDE_TOP) >= 18.0, "поля слева и сверху")
	var rivals := ui.find_children("RivalClassPortrait_*", "", true, false)
	var arts := []
	for rival: Control in rivals:
		var art := rival.get_child(0) as TextureRect
		if _check(art != null and art.texture != null, "портрет класса вместо силуэта"):
			arts.append(art.texture.resource_path.get_file())
	_check(arts == ["archer_portrait.png", "legionary_portrait.png", "priest_portrait.png",
		"cavalry_portrait.png"], "разные портреты четырёх классов игроков и ботов")
	var hero := ui.find_child("rival_hero", true, false)
	if _check(hero != null, "герой соперника"):
		var face := hero.find_child("FortPortraitArt", true, false) as TextureRect
		_check(await _wait(func(): return bool(face.get_meta("portrait_ready", false))), "лицо героя соперника")
		_check(face.get_meta("portrait_look") == Legion.pvp_rival_look(ui._pvp_list[0]["snapshot"], ui._pvp_list[0]), "облик героя из снимка")
	await RenderingServer.frame_post_draw
	_shot("02_arena")
	ui.close(false)


func _victory() -> void:
	var setup := legion.make_battle(legion.stage_info(0, 0, 0), 50)
	setup.erase("tutorial")
	var battle := LegionBattle.open(game, setup)
	if not _check(await _wait(func(): return battle.phase == "intro" and battle.fade.modulate.a < 0.05), "подготовка боя"):
		battle.abort()
		return
	var rescued := [legion._fort_newcomer(), legion._fort_newcomer()]
	battle.out = {"win": true, "alive": 2, "total": 2, "stars": 3, "star_mask": 7,
		"reward": {"money": 150, "rations": 300}, "rescued": rescued}
	await battle._show_result(true)
	var row := battle.find_child("FortRescuedRewards", true, false)
	if _check(row != null and battle.phase == "result" and battle.modal.visible, "видимая карточка победы"):
		var faces := row.find_children("FortPortraitArt", "TextureRect", true, false)
		_check(faces.size() == rescued.size(), "оба места спасённых жителей")
		for face: TextureRect in faces:
			_check(face.texture is ImageTexture and bool(face.get_meta("portrait_ready", false)), "лицо готово к показу победы")
		await RenderingServer.frame_post_draw
		_shot("03_victory")
	battle.abort()


func _wait(condition: Callable, timeout_ms := 12000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return bool(condition.call())


func _shot(file: String) -> void:
	var path := out.path_join(file + ".png")
	if _check(get_viewport().get_texture().get_image().save_png(path) == OK, "сохранение " + file):
		print("POLISH18 SHOT ", path)


func _check(ok: bool, reason: String) -> bool:
	if not ok:
		fails += 1
		print("POLISH18 FAIL ", reason)
	return ok
