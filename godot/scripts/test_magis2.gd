extends Node3D
## Регрессии MAGIS2: кнопка по рангу и низкий приоритет советов. Запускает проверяющий.

var out := "D:/CivCity/.work/stage5/magis2/shots/"
var game: Game
var hud: Hud
var fails := 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=").trim_suffix("/") + "/"
	if DirAccess.make_dir_recursive_absolute(out) != OK:
		check(false, "shot directory")
		_finish()
		return
	GamePaths._dir = out + "user_" + str(Time.get_ticks_usec())
	if DirAccess.make_dir_recursive_absolute(GamePaths._dir) != OK:
		check(false, "isolated settings directory")
		_finish()
		return
	var settings := FileAccess.open(GamePaths._dir.path_join("settings.json"), FileAccess.WRITE)
	if settings == null:
		check(false, "isolated settings file")
		_finish()
		return
	settings.store_string(JSON.stringify({"fullscreen": false, "autosave": false, "lang": "ru", "ui_scale": 1.0, "quality": "medium", "quality_user": true}))
	settings.close()
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	game.can_save = false
	add_child(game)
	_run()


func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func check(ok: bool, reason: String) -> void:
	if not ok:
		fails += 1
		print("MAGIS2 FAIL " + reason)


func shot(file: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await frames(10)
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(out + file)
	check(error == OK, "save " + file)
	if error == OK:
		print("MAGIS2 SHOT " + out + file)


func _free_advisor() -> void:
	hud.advisor_panel.hide()
	hud._tip_next = 0


func _top_buttons() -> int:
	return hud.top_panel.find_children("*", "Button", true, false).filter(func(b: Button): return b != hud.cloud_off and b.is_visible_in_tree()).size()


func _run() -> void:
	var waited := 0
	while not game.ready_done:
		await frames(5)
		waited += 5
		if waited >= 18000:
			check(false, "ready_done timeout")
			_finish()
			return
	game.can_save = false
	game.speed = 0.0
	game.set_process(false)
	game.settings["autosave"] = false
	game.settings["advisor_off"] = false
	game.tutorial.step = Tutorial.STEPS.size()
	game.tutorial.card.hide()
	game.tutorial.set_process(false)
	game.stories.set_process(false)
	game.stories.force = true
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 720)
	I18n.set_lang("ru")
	hud = game.hud
	hud.quiet_tips = 0
	hud.tip_gap = false
	var c := game.city
	c.tips["tut"] = -1
	c.tips["ui"] = 3
	hud.apply_reveal(3)
	hud.close_panels()
	var legion_money := game.city.legion.city_money()
	_free_advisor()
	var ui := MagisUI.of(hud)
	check(ui != null, "magistracy entry attached")
	if ui == null:
		_finish()
		return
	c.level = 0
	ui.refresh()
	check(not ui.top_button.is_visible_in_tree() and _top_buttons() == 6, "six buttons while magistracy hidden")
	await shot("1_topbar_hidden.png")
	c.level = int(Defs.MAGIS[0]["rank"])
	ui.refresh()
	check(ui.top_button.is_visible_in_tree() and _top_buttons() == 7, "seven buttons when first magistracy opens")
	check(c.legion.city_money() == legion_money, "magistracy visibility does not transfer Legion denarii")
	await shot("2_topbar_open.png")
	# Оставляем только два ожидающих совета: этаж и первая магистратура.
	for key: String in ["unpaid_tip", "rank_tip", "fest_tip", "hero_tip", "full_money", "full_rp", "tax_tip", "dim_tip", "set_tip", "pave_up_tip", "prem_tip", "chron_tip", "hire_tip"]:
		c.tips[key] = true
	c.research["floor2"] = true
	c.tips.erase("floor_tool")
	c.tips.erase("magis_open_censura")
	hud._top_action("research")
	hud._once_tips()
	check(not c.tips.has("floor_tool") and not c.tips.has("magis_open_censura"), "open research keeps both advice messages pending")
	hud.close_panels()
	await frames(2)
	hud._once_tips()
	check(hud.advisor_panel.visible and hud.adv_title.text == "Этаж — без карточки дома" and not c.tips.has("magis_open_censura"), "floor advice wins after research closes")
	await shot("3_floor_advice.png")
	check(not MagisUI.advise(hud) and hud.adv_title.text == "Этаж — без карточки дома", "magistracy never replaces open advisor")
	_free_advisor()
	hud.tip_gap = true
	hud._tip_next = Time.get_ticks_msec() + 60000
	check(not MagisUI.advise(hud) and not c.tips.has("magis_open_censura"), "advisor cooldown keeps magistracy pending")
	hud.tip_gap = false
	_free_advisor()
	# До очередного опроса Stories совет об истории уже имеет приоритет.
	c.stories["offer"] = {"id": "cat"}
	c.tips.erase("story_tip")
	check(game.stories.advice_pending() and not MagisUI.advise(hud) and not c.tips.has("magis_open_censura"), "pending story advice wins before its poll")
	game.stories._advise_once()
	check(hud.adv_title.text == "Истории горожан" and not MagisUI.advise(hud), "story advice keeps advisor")
	c.stories["offer"] = {}
	_free_advisor()
	game.rank_cine.pending = {"from": 0, "to": 1, "late": true}
	check(not MagisUI.advise(hud) and not c.tips.has("magis_open_censura"), "pending rank message wins")
	game.rank_cine.pending = {}
	var tutorial_step := game.tutorial.step
	game.tutorial.step = 0
	check(not MagisUI.advise(hud) and not c.tips.has("magis_open_censura"), "tutorial keeps magistracy pending")
	game.tutorial.step = tutorial_step
	hud._once_tips()
	check(hud.advisor_panel.visible and hud.adv_title.text == String(MagisUI.ADVICE["censura"]) and c.tips.has("magis_open_censura"), "magistracy finally speaks when advisor is free")
	await shot("4_magistracy_advice.png")
	_free_advisor()
	check(not MagisUI.advise(hud) and not hud.advisor_panel.visible, "magistracy is said only once")
	_finish()


func _finish() -> void:
	print("MAGIS2 DONE fails=", fails)
	get_tree().quit(1 if fails > 0 else 0)
