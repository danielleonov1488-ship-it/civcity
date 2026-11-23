extends Node
## ONLINE15: настоящий локальный сервер, отдельный профиль и снимки из игры.

const FortFixture = preload("res://scripts/test_fort_fixture.gd")
const API := "http://127.0.0.1:3016/api"
const TOWN := "Остия"

var home := OS.get_environment("ONLINE15_HOME")
var shots := OS.get_environment("ONLINE15_SHOTS")
var email := OS.get_environment("ONLINE15_SMOKE_EMAIL")
var password := OS.get_environment("ONLINE15_SMOKE_PASSWORD")
var game: Game


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, what: String) -> bool:
	if not ok:
		print("ONLINE15 FAIL ", what)
		get_tree().quit(1)
	else:
		print("ONLINE15 OK ", what)
	return ok


func until(predicate: Callable, seconds := 25.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not predicate.call():
		if Time.get_ticks_msec() >= deadline:
			return false
		await get_tree().process_frame
	return true


func shot(name: String) -> void:
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var file := shots.path_join(name + ".png")
	if check(get_viewport().get_texture().get_image().save_png(file) == OK, "снимок " + name):
		print("ONLINE15 SHOT ", file)


func boot_city() -> void:
	# Сам тест остаётся в дереве, когда игра перезагружает свою сцену при визите.
	Game.boot = {"demo": "1", "hour": "11.0"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game


func prepare_fort(c: City) -> bool:
	c.cozy_v = 1
	c.legion_v = 3
	c.level = 6
	c.money = 90000.0
	c.hero = Hero.make("Марк Лавиний", 0, {}, true, 42)
	var lg := c.legion
	lg.flags["camp_open"] = true
	lg.flags["camp_said"] = true
	lg.flags["tut"] = "done"
	lg.flags["battle_speed"] = 3.0
	lg.flags["battle_auto"] = true
	lg.sync_v2()
	FortFixture.set_level(lg, "hq", 12)
	FortFixture.set_level(lg, "barracks", 12)
	lg._ensure_hero3()
	for i in 5:
		var cls: String = ["legionary", "legionary", "cavalry", "archer", "archer"][i]
		var s := lg.hero_dweller() if i == 0 else lg._add_soldier({"name": ["", "Тит", "Луций", "Гай", "Публий"][i], "stars": 5})
		s["stars"] = 5
		s["rank"] = 11
		var sid := int(s["id"])
		if not lg.set_place(i, sid):
			return false
		for slot: String in ["weapon", "helmet", "armor", "offhand"]:
			var item := lg.add_item({"slot": slot, "cls": cls if slot == "weapon" else "", "tier": 4, "rarity": 3}, true)
			if not lg.equip(sid, int(item.get("id", 0))):
				return false
	lg.pvp_charges = 5
	c.changed.emit()
	return lg.pvp_open() and lg.squad_count() == 5


func wait_game(previous_id: int) -> bool:
	var ok := await until(func():
		var active := get_tree().current_scene as Game
		return is_instance_valid(active) and active.get_instance_id() != previous_id and active.ready_done, 240.0)
	if ok:
		game = get_tree().current_scene as Game
		await get_tree().create_timer(0.7).timeout
	return ok


func _run() -> void:
	if not check(home != "" and shots != "" and email != "" and OS.get_environment("CIVCITY_API") == API, "изолированная среда"):
		return
	boot_city()
	if not check(await until(func(): return game.ready_done, 240.0), "готовый город загрузился"):
		return
	if not check(prepare_fort(game.city), "готов отряд из пяти бойцов"):
		return
	var fixture := FileAccess.open(home.path_join("town_template.json"), FileAccess.WRITE) if not FileAccess.file_exists(home.path_join("town_template.json")) else null
	if fixture != null:
		fixture.store_string(JSON.stringify(game._save_data()))
		fixture.close()
	if not check(FileAccess.file_exists(home.path_join("town_template.json")), "записан шаблон тестового города"):
		return
	# Открываем рабочий режим сохранений с тем же городом.
	var acc := Account.me()
	game.mode = "play"
	game.can_save = true
	var login_error := await acc.login(email, password, true, true)
	if not check(login_error == "" and acc.signed_in(), "регистрация через Account: " + login_error):
		return
	acc.attach(game)
	if not check(await until(func(): return acc.synced and not acc.syncing and not acc._busy), "первое сохранение ушло в облако"):
		return
	var seed_output := []
	var seed_code := OS.execute(OS.get_environment("ONLINE15_NODE"), ["--disable-warning=ExperimentalWarning", home.path_join("seed_bots.js")], seed_output, true)
	if not check(seed_code == 0, "подготовка девяти городов" if seed_code == 0 else str(seed_output)):
		return

	var city_name := "Лавиний " + email.get_slice("@", 0).right(7)
	CityName.open(game.hud)
	var box := CityName.window(game.hud)
	if not check(box != null, "открылось окно названия"):
		return
	(box.find_child("field", true, false) as LineEdit).text = city_name
	(box.find_child("save", true, false) as Button).pressed.emit()
	if not check(await until(func(): return CityName.window(game.hud) == null and game.city.name == city_name), "имя принято сервером и появилось на карте"):
		return
	await shot("01_city_name")
	await acc.save_now()
	if not check(await until(func(): return not acc._busy and not acc.pending()), "облако сохранило новое имя"):
		return

	if not await arena(city_name) or not await trial():
		return
	var sn := SocialNet.me()
	var friends_refresh := {"error": "ожидание"}
	sn.refresh(func(err: String): friends_refresh["error"] = err)
	if not check(await until(func(): return friends_refresh["error"] == "") and (sn.state.get("friends", []) as Array).size() >= 3, "три города есть в друзьях"):
		return
	var friends: Array = sn.state["friends"]
	var target: Dictionary = friends[friends.find_custom(func(f: Dictionary): return f.get("name") == TOWN)]
	game.stories.ui.open_journal("friends")
	await shot("07_friends")

	await acc.save_now()
	if not check(await until(func(): return not acc._busy and not acc.pending()), "город с результатами сохранён в облаке"):
		return
	var cloud := await NetHttp.fetch(self, API, HTTPClient.METHOD_GET, "/save?game=rome2", null, acc.token)
	var save: Dictionary = (cloud.get("data", {}) as Dictionary).get("save", {})
	var expected := String(save.get("data", ""))
	if not check(int(cloud["status"]) == 200 and expected != "", "проверена сохранённая копия на сервере"):
		return
	game.hud.journal_panel.hide()
	game.hud._open_settings()
	await shot("08_cloud_saved")
	game.hud.settings_panel.hide()

	var own := game.get_instance_id()
	FriendsUi._visit(game.hud, int(target["id"]))
	if not check(await wait_game(own), "переход в город друга"):
		return
	if not check(game.visiting.get("name") == TOWN and not game.can_save and game.city.buildings.size() > 0, "Остия открылась для просмотра"):
		return
	if not check(FileAccess.file_exists(GamePaths.save_dir().path_join("visit_city.json")), "копия города друга лежит в тестовом профиле"):
		return
	await shot("09_visit")

	# Новый каталог и новый узел Account. Сессия и локальный город отсутствуют.
	var fresh := OS.get_environment("ONLINE15_FRESH")
	OS.set_environment("CIVCITY_SAVEDIR", fresh)
	GamePaths._dir = ""
	var fresh_city := GamePaths.save_dir().path_join("city.json")
	acc.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	acc = Account.me()
	if not check(not FileAccess.file_exists(fresh_city) and not acc.signed_in(), "чистый профиль без города и сессии"):
		return
	login_error = await acc.login(email, password, false)
	if not check(login_error == "" and await until(func(): return acc.synced and not acc.syncing), "вход заново и скачивание из облака: " + login_error):
		return
	var downloaded := FileAccess.get_file_as_string(fresh_city)
	if not check(downloaded == expected, "скачанная копия совпала с сервером побайтно"):
		return
	var guest := game.get_instance_id()
	game.restart("play")
	if not check(await wait_game(guest), "скачанный город загрузился"):
		return
	if not check(game.city.name == city_name and game.city.buildings.size() > 0, "открыт свой город из чистого профиля"):
		return
	await shot("10_cloud_download")
	print("ONLINE15 DONE")
	get_tree().quit()


func arena(city_name: String) -> bool:
	var ln := LegionNet.me()
	var ui := LegionUi.of(game.hud)
	var camp := CampUI.attach(game.hud)
	camp.open()
	if not check(await until(func(): return camp.visible and not camp.opening, 40.0), "открылся форт"):
		return false
	var entry := camp.find_child("FortArena", true, false) as Button
	if not check(entry != null and not entry.disabled, "кнопка арены доступна в форте"):
		return false
	entry.pressed.emit()
	if not check(await until(func(): return ui._pvp_state == "ok", 45.0), "арена получила соперников: " + ui._pvp_err):
		return false
	var target_index: int = ui._pvp_list.find_custom(func(o: Dictionary): return not bool(o.get("bot", true)))
	if not check(target_index >= 0, "засеянный город есть среди соперников"):
		return false
	var before := int(ln.me_state.get("rating", -1))
	await shot("02_arena")
	ui._attack(ui._pvp_list[target_index])
	if not check(await battle_shot("03_arena_result"), "бой арены дошёл до результата"):
		return false
	if not check(await until(func(): return int(ln.me_state.get("rating", -1)) > before), "победа, сервер поднял рейтинг с %d до %d" % [before, int(ln.me_state.get("rating", -1))]):
		return false
	LegionBattle.current._close()
	await until(func(): return not is_instance_valid(LegionBattle.current))
	ui.open("pvp")
	LegionPvpView.top(ui)
	if not check(await until(func():
		return ui.overlay != null and ui.overlay.find_children("*", "Label", true, false).any(
			func(l: Label): return l.text.contains(city_name) and l.text.contains("(вы)"))), "город появился в таблице рейтинга"):
		return false
	await shot("04_arena_rating")
	ui._close_overlay()
	ui.close(false)
	return true


func trial() -> bool:
	var ui := LegionUi.of(game.hud)
	var sn := SocialNet.me()
	ui.open("events")
	if not check(await until(func(): return (sn.events.get("tiers", []) as Array).size() == 3), "сервер прислал три испытания"):
		return false
	var before := int(sn.events["me"]["tries_left"])
	await shot("05_weekly")
	ui._trial(1)
	if not check(await battle_shot("06_weekly_result"), "бой недельного испытания дошёл до результата"):
		return false
	if not check(await until(func(): return sn.events.has("accepted")) and sn.events["accepted"] == true and int(sn.events["me"]["tries_left"]) == before - 1, "сервер принял испытание и списал одну попытку"):
		return false
	print("ONLINE15 OK очки испытания ", int(sn.events.get("score", 0)))
	LegionBattle.current._close()
	await until(func(): return not is_instance_valid(LegionBattle.current))
	ui.close(false)
	return true


func battle_shot(file: String) -> bool:
	if not await until(func(): return is_instance_valid(LegionBattle.current) and LegionBattle.current.phase == "result", 210.0):
		return false
	await shot(file)
	return true

