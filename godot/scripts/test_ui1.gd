extends Node3D
## Семь кадров UI1. Запускает проверяющий; сохранения и настройки изолированы.

var out := "D:/CivCity/.work/stage2/ui1/shots/"
var game
var hud: Hud


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2 and pair[0] == "out":
			out = pair[1] if pair[1].ends_with("/") else pair[1] + "/"
	if not check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory"):
		return
	GamePaths._dir = out + "user_" + str(Time.get_ticks_usec())
	if not check(DirAccess.make_dir_recursive_absolute(GamePaths._dir) == OK, "isolated settings directory"):
		return
	var settings := FileAccess.open(GamePaths._dir.path_join("settings.json"), FileAccess.WRITE)
	if not check(settings != null, "isolated settings file"):
		return
	settings.store_string(JSON.stringify({"fullscreen": false, "autosave": false, "lang": "ru", "ui_scale": 1.0, "quality": "medium", "quality_user": true, "settings_more": false}))
	settings.close()
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 720)
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
		print("UI1 FAIL ", message)
		push_error("UI1 FAIL " + message)
		get_tree().quit(1)
	return ok


func shot(file: String) -> bool:
	await frames(12)
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(out + file)
	if not check(error == OK, "save " + file):
		return false
	print("UI1 SHOT ", out + file)
	return true


func fits(panel: Control) -> bool:
	var rect := panel.get_global_rect()
	return Rect2(Vector2.ZERO, hud.root.size).grow(1.0).encloses(rect)


func _run() -> void:
	var waited := 0
	while not game.ready_done:
		await frames(5)
		waited += 5
		if not check(waited < 18000, "ready_done timeout"):
			return
	# Загрузка настроек разворачивает окно; фиксируем размер уже после неё.
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 720)
	game.can_save = false
	game.speed = 0.0
	game.settings["autosave"] = false
	game.tutorial.step = Tutorial.STEPS.size()
	game.tutorial.card.visible = false
	hud = game.hud
	hud.quiet_tips = 1
	var city: City = game.city
	city.tips["tut"] = -1
	city.tips["ui"] = 3
	city.cozy_v = 1
	city.legion_v = 3
	city.money = 1000000
	city.legion.flags["camp_told"] = true
	hud.apply_reveal(3)
	for i in 15:
		var home := city.place("house_pleb", Land.START + Vector2(8.0 * (i % 8), 8.0 * (i / 8)), 0.0, 0, 0, true)
		if not check(not home.is_empty(), "house %d" % i):
			return
		home["families"] = [{"name": "Юлии%d" % i, "n": 4, "cls": "plebs"}]
		home["pop"] = 4
	city.research["farm"] = true
	var workplace := city.place("farm", Land.START + Vector2(24, 24), 0.0, 0, 0, true)
	if not check(not workplace.is_empty(), "workplace"):
		return
	city.arrivals.append({"name": "Корнелии", "n": 4, "cls": "plebs"})
	city.compute()
	city.legion.army_tick()
	city.changed.emit()
	hud.advisor_panel.visible = false
	hud._close_windows()
	await frames(20)
	if not check(int(city.stats["pop"]) >= 60 and int(city.stats["jobs"].get("plebs", 0)) > 0, "populated city and jobs"):
		return
	var camp := CampUI.of(hud)
	if not check(camp != null and camp.top_button == hud.top_btns["legion"], "single Legion entry"):
		return
	if not check(camp.top_button.is_visible_in_tree() and camp.top_button.tooltip_text == "Легион", "Legion medal visible"):
		return
	camp.top_button.pressed.emit()
	if not check(camp.visible, "Legion medal opens CampUI"):
		return
	camp.close()
	for id: String in ["finance", "stats", "bell", "view"]:
		if not check(hud.top_btns[id] == hud.top_btns["overview"], "legacy alias " + id):
			return
	if not check(hud.top_panel.find_children("*", "Button", true, false).filter(func(b): return b != hud.cloud_off).size() == 6, "six top buttons including hero"):
		return
	# Фильтр и счётчик: обычные строки остаются в полном журнале.
	hud.bell_count = 0
	hud.bell_badge.text = ""
	var routine := {"day": 0, "text": "Дому семьи Юлиев надстроили 2-й этаж — место ещё для 4 жителей", "icon": "housing"}
	city.events.append(routine)
	hud.bell(String(routine["text"]), "housing")
	if not check(hud.bell_count == 0 and not hud._important_event(routine), "routine event has no badge"):
		return
	var event := {"day": 0, "text": "Просьба выполнена: Изучите что-нибудь (+10 ден.)", "icon": "check"}
	city.events.append(event)
	hud.bell(String(event["text"]), "check")
	if not check(hud.bell_count == 1, "important unread badge"):
		return
	if not await shot("1_topbar.png"):
		return
	hud._open_settings()
	await frames(12)
	var more := hud.settings_panel.find_child("settings_more_body", true, false) as Control
	var details := hud.settings_panel.find_child("settings_more", true, false) as Button
	if not check(not more.visible and details.text == "Подробнее ▸" and fits(hud.settings_panel), "collapsed settings fit 1280x720"):
		return
	if not check(hud.settings_panel.find_child("marble", true, false) == null, "no marble switch"):
		return
	for key: String in ["q_high", "q_medium", "q_low", "q_verylow", "music", "sfx", "fs", "lang_row", "adv"]:
		var control := hud.settings_panel.find_child(key, true, false) as Control
		if not check(control != null and control.is_visible_in_tree(), "basic setting " + key):
			return
	if not await shot("2_settings.png"):
		return
	details.pressed.emit()
	# save_settings() снова применяет режим окна.
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 720)
	await frames(12)
	if not check(more.visible and details.text == "Подробнее ▾" and fits(hud.settings_panel), "expanded settings fit 1280x720"):
		return
	for key: String in ["ui_scale", "show_fps", "cap_60", "gpu_name", "grass_far"]:
		var control := hud.settings_panel.find_child(key, true, false)
		if not check(control != null and more.is_ancestor_of(control), "advanced setting " + key):
			return
	var stored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.settings_path()))
	if not check(bool(stored.get("settings_more", false)), "expanded state saved"):
		return
	if not await shot("3_settings_more.png"):
		return
	hud._close_windows()
	hud._open_settings()
	if not check(more.visible, "expanded state survives reopening"):
		return
	hud._top_action("overview")
	await frames(12)
	if not check(hud.overview_tab == "city" and hud.bell_count == 1 and fits(hud.overview_panel), "city tab preserves unread badge and fits"):
		return
	if not await shot("4_overview_city.png"):
		return
	var map := hud.overview_panel.find_child("overview_happiness_map", true, false) as Button
	map.pressed.emit()
	if not check(not hud.overview_panel.visible and hud.overlay == "happy", "map button opens happiness overlay and closes overview"):
		return
	hud._top_action("view")
	if not check(hud.overlay == "", "legacy view toggles overlay"):
		return
	hud._top_action("finance")
	if not check(hud.overview_panel.visible and hud.overview_tab == "money", "legacy finance opens Money"):
		return
	if not await shot("5_overview_money.png"):
		return
	hud._top_action("stats")
	if not check(hud.overview_tab == "people", "legacy stats opens Residents"):
		return
	if not await shot("6_overview_people.png"):
		return
	# Более 30 важных строк: остаются последние, полный журнал не урезается видом.
	for i in 35:
		city.events.append({"day": i, "text": "Просьба выполнена: Изучите что-нибудь (+%d ден.)" % (i + 1), "icon": "check"})
	city.events.append({"day": 35, "text": "Семья Юлиев уехала: им плохо живётся", "icon": "person"})
	city.events.append({"day": 35, "text": "Город теперь — «Хутор»! Открылись новые исследования, казна вмещает 100 ден.", "icon": "level"})
	city.events.append({"day": 35, "text": "Сегодня Сатурналии! Город празднует сутки: счастье домов +10%, известность растёт.", "icon": "laurels"})
	city.events.append({"day": 35, "text": "Легион победил: Разбойники!", "icon": "legion"})
	city.events.append({"day": 35, "text": "Изучено: Пекарня", "icon": "research"})
	city.events.append(routine.duplicate())
	game.settings["advisor_off"] = true
	hud.advisor("Налоги по классам", "Теперь налоги можно настроить для каждого класса — в «Обзоре города» → «Деньги».")
	if not check(not hud.advisor_panel.visible and bool(city.events[-1].get("advisor", false)), "disabled advisor goes to Events"):
		return
	var full_log: Array = city.events.duplicate(true)
	hud._top_action("bell")
	await frames(12)
	var filtered: Array = hud._overview_events()
	var list := hud.events_panel.find_child("list", true, false)
	if not check(hud.overview_tab == "events" and hud.bell_count == 0 and hud.bell_badge.text == "", "Events clears unread badge"):
		return
	if not check(filtered.size() == 30 and list.get_child_count() == 30 and city.events == full_log, "latest 30 important events; full data intact"):
		return
	if not check(not filtered.has(routine) and bool(filtered[0].get("advisor", false)), "routine hidden; advisor visible"):
		return
	var long_text := "Город теперь — «Хутор»! Открылись новые исследования, казна вмещает 100 ден."
	if not check(hud._event_line(long_text) == "Город теперь — «Хутор»!", "long event uses first sentence"):
		return
	if not await shot("7_overview_events.png"):
		return
	print("UI1 DONE")
	get_tree().quit()
