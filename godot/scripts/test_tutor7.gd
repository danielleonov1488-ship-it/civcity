extends "res://scripts/test_tutor6.gd"
## Настоящий запуск: профиль с пройденным обучением, создание героя, камера, дома, дорога, приезд.

const CAMERA_TIMEOUT_MS := 75000


func _ready() -> void:
	await launcher_run("TUTOR7", "D:/CivCity/.work/stage6/tutor8/shots/launcher/")


func launcher_run(prefix: String, folder: String, profiles := "D:/CivCity/.work/stage6/tutor8/profiles") -> void:
	tag = prefix
	out = folder
	var lang := "ru"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=").trim_suffix("/") + "/"
		if arg.begins_with("profiles="):
			profiles = arg.trim_prefix("profiles=").trim_suffix("/")
		if arg.begins_with("lang="):
			lang = arg.trim_prefix("lang=")
		if arg.begins_with("profiles="):
			profiles = arg.trim_prefix("profiles=")
	get_window().size = Vector2i(1440, 900)
	var profile := "%s/%s_%d_%d" % [profiles, tag.to_lower(), int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	if not check(DirAccess.make_dir_recursive_absolute(profile) == OK and DirAccess.make_dir_recursive_absolute(out) == OK, "isolated directories"):
		finish_run()
		return
	# Повторная новая игра после завершённого обучения — исходный сбой владельца.
	var settings_file := FileAccess.open(profile.path_join("settings.json"), FileAccess.WRITE)
	if not check(settings_file != null, "isolated settings"):
		finish_run()
		return
	settings_file.store_string(JSON.stringify({"tut_done": true, "autosave": false, "lang": lang}))
	settings_file.close()
	GamePaths._dir = ""
	OS.set_environment("CIVCITY_SAVEDIR", profile)
	OS.set_environment("CIVCITY_NOLOGIN", "1")
	OS.set_environment("CIVCITY_NOMINPAUSE", "1")
	OS.set_environment("CIVCITY_HEROSCREEN", "1")
	Game.sandbox = false
	Game.boot = {"new": "1", "hour": "11", "nologin": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	game.can_save = false
	add_child(game)
	for i in 18000:
		if game.ready_done:
			break
		await get_tree().process_frame
	if not check(game.ready_done, "ready_done timeout"):
		finish_run()
		return
	city = game.city
	hud = game.hud
	tut = game.tutorial
	game.can_save = false
	game.settings["autosave"] = false
	check(bool(game.settings.get("tut_done", false)), "existing completed-tutorial preference loaded")
	check(tut.active() and Tutorial.saved_step(city.tips) == 0 and hud.tutorial_busy(), "new city owns its tutorial state")
	var hero := hud.get_node_or_null("HeroScreen") as HeroScreen
	if not check(hero != null and hero.mode == "new", "launcher opens hero creation"):
		finish_run()
		return
	await shot("00_hero.png")
	var go := hero.find_child("go", true, false) as Button
	if not check(go != null and not go.disabled, "hero can enter city"):
		finish_run()
		return
	go.pressed.emit()
	var started := Time.get_ticks_msec()
	var saw_camera := false
	while Time.get_ticks_msec() - started < CAMERA_TIMEOUT_MS:
		check(tut.cine.is_empty() and city.incoming == 0 and city.arrivals.is_empty(), "no arrival before houses and road")
		if not HeroScreen.is_open(game) and tut.card.is_visible_in_tree() and tut.cur_id() == "move":
			saw_camera = true
			break
		await get_tree().process_frame
	check(saw_camera, "camera card visible directly after hero")
	if not saw_camera:
		finish_run()
		return
	game.speed = 0.0
	check(bool(city.hero.get("made", false)) and game.hero_offer_done and not HeroScreen.is_open(game), "created hero accepted")
	check(tut.camera_keys.is_visible_in_tree() and tut.camera_keys.texture != null, "camera key pictograms visible")
	check(not tut._check("move"), "cinematic movement is not player camera input")
	check(not hud.advisor_panel.visible and not hud.notes_box.is_visible_in_tree(), "one tutorial voice after hero")
	await shot("01_camera_after_hero.png")
	# Дальше та же цепочка действий игрока: дома, улица, семья, лавка, писец, исследование.
	game.build_anim = false
	city.money = 100000.0
	await run()
	check(saw_arrival and city.tips.has("intro"), "real launcher arrival cutscene after connection")
	finish_run()
