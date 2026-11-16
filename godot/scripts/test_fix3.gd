extends "res://scripts/test_pave.gd"
## FIX3: настоящий ввод стройки с ожидающим советом о найме (F5 → F10 → T8).

const FIX3_SHOTS := "D:/CivCity/.work/stage4/fix3/shots/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(FIX3_SHOTS)
	GamePaths._dir = FIX3_SHOTS + "user_" + str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(GamePaths._dir)
	var file := FileAccess.open(GamePaths._dir.path_join("settings.json"), FileAccess.WRITE)
	if not ok("isolated settings", file != null):
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify({"fullscreen": false, "autosave": false, "lang": "ru", "ui_scale": 1.0, "quality": "medium", "quality_user": true}))
	file.close()
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 720)
	super._ready()                       # Game.boot = {"new": "1"}, main.tscn


func ok(name: String, cond: bool, info := "") -> bool:
	if not cond:
		fails += 1
	print("FIX3 ", "PASS " if cond else "FAIL ", name, (" " + info) if info != "" else "")
	return cond


func shot(name: String) -> void:
	var file := FIX3_SHOTS + name
	var err := get_viewport().get_texture().get_image().save_png(file)
	if ok("save " + name, err == OK):
		print("FIX3 SHOT ", file)


func _run() -> void:
	var waited := 0
	while not game.ready_done:
		await frames(5)
		waited += 5
		if not ok("ready_done", waited < 18000):
			get_tree().quit(1)
			return
	game.can_save = false
	game.settings["autosave"] = false
	game.speed = 0.0
	game.tutorial.step = Tutorial.STEPS.size()
	game.tutorial.card.visible = false
	game.city.tips["tut"] = -1
	game.city.tips["ui"] = 3
	game.city.tips["intro"] = true
	game.city.tips["cover_tip"] = true
	game.city.research["fountain"] = true
	game.city.money = 50000.0
	game.hud.apply_reveal(3)
	game.hud.quiet_tips = 0
	game.hud.advisor_panel.visible = false
	game.rig.set_view(Vector3(180, 2, 150), 15, 58, 60)
	_paint()
	await frames(40)
	await _f5_mouse()                    # лавка ставится тем же щелчком, что у игрока
	ok("hire advice stays queued during building", game.city.tips.has("manual_hire_pending") and not game.city.tips.has("manual_hire_tip") and not game.hud.advisor_panel.visible)
	await _f10_angles()
	await _t8_rotate()
	shot("fix3_rotated_house.png")
	game.set_tool("")
	game.hud._tip_next = 0
	ok("hire advice appears after building", game.hud._manual_hire_advice() and game.hud.advisor_panel.visible and game.city.tips.has("manual_hire_tip"))
	await frames(8)
	shot("fix3_hire_advice.png")
	print("FIX3 DONE fails=", fails)
	get_tree().quit(1 if fails > 0 else 0)
