extends "res://scripts/test_perf14_base.gd"

const Timers = preload("res://scripts/perf14_timers.gd")
const CityTimers = preload("res://scripts/perf13_timers.gd")
const PIPELINES := [Performance.PIPELINE_COMPILATIONS_CANVAS, Performance.PIPELINE_COMPILATIONS_MESH,
	Performance.PIPELINE_COMPILATIONS_SURFACE, Performance.PIPELINE_COMPILATIONS_DRAW,
	Performance.PIPELINE_COMPILATIONS_SPECIALIZATION]
const LIMITS := [25.0, 33.0, 50.0, 100.0]

var report: FileAccess
var events: FileAccess
var top: Array[Dictionary] = []
var pending: Array[String] = []
var pipeline_counts := PackedInt64Array()
var counts := PackedInt64Array([0, 0, 0, 0])
var active := false
var before := 0
var process_ms := 0.0
var draw_ms := 0.0
var draw_started := 0
var phase_counts := {}
var phase_samples := {}
var phase_pipelines := {}
var traces := PackedStringArray()
var frame_count := 0
var scenario := ""
var phase := ""
var fails := 0


func _ready() -> void:
	setup_run()
	_run.call_deferred()


func _run() -> void:
	Spectacle.warm_crowds = not args.has("cold_crowd")
	var tag := str(args.get("tag", "before"))
	report = FileAccess.open(out.path_join("hitch_%s.md" % tag), FileAccess.WRITE)
	events = FileAccess.open(out.path_join("hitch_%s.jsonl" % tag), FileAccess.WRITE)
	if report == null or events == null:
		_fail("не открыт отчёт")
		get_tree().quit(1)
		return
	_line("# PERF14 · рывки (%s)" % tag)
	_line("")
	_line("Адаптер %s. Длительности по часам, от начала кадра до начала следующего. Таймеры вложены: их нельзя складывать. Счётчики компиляции показывают количество, CPU/GPU рендера — данные последнего доступного кадра. Неизмеренный остаток не приписывается компиляции или загрузке." % RenderingServer.get_video_adapter_name())
	get_tree().process_frame.connect(_frame)
	RenderingServer.frame_pre_draw.connect(_before_draw)
	RenderingServer.frame_post_draw.connect(_after_draw)
	for q: String in str(args.get("q", "high,low")).split(","):
		for kind: String in str(args.get("city", "owner,new")).split(","):
			scenario = "%s/%s" % [kind, q]
			var perf20c := args.has("perf20c")
			var startup_us := Time.get_ticks_usec()
			if args.has("focus") or perf20c:
				_begin()
				_mark("загрузка")
			var booted := await boot_city(kind, q, true)
			var startup_ms := (Time.get_ticks_usec() - startup_us) / 1000.0
			if args.has("focus") or perf20c:
				await _finish(true)
				_line("До готовности (%s): %.1f мс." % [scenario, startup_ms])
			if not booted:
				_fail("не открыт город " + scenario)
				continue
			if args.has("startup_only"):
				continue
			game.hud.set_speed(0.0)
			if args.has("free_only"):
				game._set_hour(9.0)
			else:
				_prepare_sites()
			set_view(OWNER_VIEWS if kind == "owner" else NEW_VIEWS, 0)
			await frames(90)
			if scenario == "owner/high" and not args.has("cold_crowd") and not perf20c:
				await _pipeline_replay()
			_begin()
			if perf20c:
				await _first_use()
			elif not args.has("free_only"):
				await _actions()
			await _free_play()
			await _finish()
			if args.has("perf22g") and q == "verylow":
				_check_mobile_budget()
	events.close()
	report.close()
	print("HITCH14 %s fails=%d" % ["DONE" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails else 0)


func _pipeline_replay() -> void:
	var vp := get_viewport()
	var before_draw := int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW))
	var before_specialization := int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION))
	await Game.CityWarmup._render(game, vp.msaa_3d, vp.screen_space_aa, game.sun.shadow_enabled, true)
	var draw := int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)) - before_draw
	var specialization := int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)) - before_specialization
	_line("Повтор прохода после освобождения сеток: draw +%d, specialization +%d." % [draw, specialization])


func _begin() -> void:
	counts.fill(0)
	top.clear()
	pending.clear()
	Timers.reset_frame()
	phase_counts.clear()
	phase_samples.clear()
	phase_pipelines.clear()
	traces.clear()
	CityTimers.usec.resize(CityTimers.LABELS.size())
	CityTimers.usec.fill(0)
	Timers.enabled = true
	CityTimers.enabled = true
	pipeline_counts = _pipelines()
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	frame_count = 0
	before = Time.get_ticks_usec()
	phase = "город"
	active = true


func _first_use() -> void:
	var site := Vector2(64, 74)
	game.weather.force = 0.0
	game._set_hour(9.0)
	game.rig.set_view(Vector3(site.x, Land.BASE_Y, site.y), 15, 42, 40)
	await frames(60)
	_mark("первая стройка")
	game.build_anim = true
	var house := game.city.place("house_pleb", site, 0.0, 0, 0, true, Vector2i.ZERO, true)
	game.build_anim = false
	if house.is_empty() or not game._grow_live.has(house["id"]):
		_fail("первая стройка без анимации")
	else:
		game._finish_placement({}, site)
		var build_deadline := Time.get_ticks_msec() + 12000
		while (game._grow_live.has(house["id"]) or game._placement_running) and Time.get_ticks_msec() < build_deadline:
			await frames(1)
	await frames(45)
	if args.has("perf22g") and not house.is_empty():
		_mark("снос тестового дома")
		await _demolish_focus(house)

	_mark("первый закат")
	game._set_hour(20.0)
	await frames(90)
	_mark("первая ночь")
	game._set_hour(23.0)
	await frames(90)
	_mark("первый дождь")
	game.weather.force = 1.0
	await frames(180)
	var rain_particles: bool = game.settings["quality"] != "verylow"
	if game.weather.level <= 0.0 or game.weather.rain.emitting != rain_particles:
		_fail("дождь или его частицы не соответствуют пресету")
	game.weather.force = 0.0
	game._set_hour(9.0)
	_mark("пауза перед фортом")
	# Старый город владельца сохранён до появления разреза форта.
	game.city.cozy_v = maxi(1, game.city.cozy_v)
	game.city.legion_v = 3
	game.city.legion.free_mode = true
	game.city.legion.sync_v2()
	await frames(90)

	_mark("первый форт")
	var camp := CampUI.attach(game.hud)
	camp.open()
	var deadline := Time.get_ticks_msec() + 15000
	while camp.opening and Time.get_ticks_msec() < deadline:
		await frames(1)
	await frames(45)
	if not camp.visible or camp.opening or not is_instance_valid(camp.diorama):
		_fail("форт не открылся")
	_mark("первая карта похода")
	camp._campaign()
	deadline = Time.get_ticks_msec() + 15000
	while not is_instance_valid(camp.lu.fort_map) and Time.get_ticks_msec() < deadline:
		await frames(1)
	await frames(60)
	if not camp.lu.visible or not is_instance_valid(camp.lu.fort_map):
		_fail("карта похода не открылась")
	camp.lu.close(false)
	_mark("возврат из форта")
	camp.close()
	await frames(90)

	_mark("первый бой · загрузка")
	var battle := open_battle(false)
	deadline = Time.get_ticks_msec() + 80000
	while is_instance_valid(battle) and battle.phase == "loading" and Time.get_ticks_msec() < deadline:
		await frames(1)
	_mark("первый бой · бой и итог")
	while is_instance_valid(battle) and battle.phase != "result" and Time.get_ticks_msec() < deadline:
		await frames(1)
	if is_instance_valid(battle) and battle.phase == "result":
		if args.has("perf22g"):
			await frames(30) # первый видимый кадр итога входит в замер
		_mark("возврат из боя")
		battle._close()
		await battle.tree_exited
	else:
		_fail("бой не дошёл до итога")
		if is_instance_valid(battle):
			battle.abort()
	await frames(90)
	if get_viewport().disable_3d:
		_fail("город не вернулся после боя")

	var views := OWNER_VIEWS if scenario.begins_with("owner") else NEW_VIEWS
	_mark("исходный вид")
	set_view(views, 0)
	await frames(45)
	_mark("отдаление")
	set_view(views, 2)
	await frames(90)
	_mark("возврат к площадке")
	game.rig.set_view(Vector3(62, Land.BASE_Y, 80), 15, 42, 64)
	await frames(45)
	if args.has("perf22g"):
		await _first_large_builds()
		return
	for type: String in ["medic", "academy", "colosseum"]:
		_mark("первая модель " + type)
		await game._request_preview(type, 0, 0)
		await frames(45)
		_mark("первая постройка " + type)
		var sliced := args.has("perf21b")
		var at := Vector2(62, 84)
		var b := game.city.place(type, at, 0.0, 0, 0, true, Vector2i.ZERO, sliced)
		if sliced and not b.is_empty():
			game._finish_placement({}, at, true)
		await frames(90)
		if b.is_empty() or not game.visuals.has(b["id"]):
			_fail("нет модели " + type)
		elif Spectacle.is_venue(type) and not game.spectacle.venues.has(b["id"]):
			_fail("нет трибун " + type)
		if not b.is_empty():
			_mark("подготовка площадки")
			if sliced:
				game.demolish_building(b, false)
				while game._placement_running:
					await frames(1)
			else:
				game.city.remove(b, false)
			await frames(12)


func _first_large_builds() -> void:
	var old_level := game.city.level
	game.city.level = maxi(old_level, 6)
	for type: String in ["medic", "academy", "colosseum"]:
		var credit := int(game.city.wonder_credits.get(type, 0))
		game.city.wonder_credits[type] = 1
		_mark("первая постройка " + type)
		var b := await _place_focus(type, Vector2(62, 80))
		if credit > 0:
			game.city.wonder_credits[type] = credit
		else:
			game.city.wonder_credits.erase(type)
		if b.is_empty():
			_fail("не поставлена " + type)
			continue
		var id := int(b["id"])
		var deadline := Time.get_ticks_msec() + 25000
		while game._grow_live.has(id) and Time.get_ticks_msec() < deadline:
			await frames(1)
		if not game.visuals.has(id) or (type == "colosseum" and not game.spectacle.venues.has(id)):
			_fail("нет постройки после анимации " + type)
		_mark("снос тестовой постройки " + type)
		await _demolish_focus(b)
		await frames(12)
	game.city.level = old_level


func _check_mobile_budget() -> void:
	if not Gfx.mobile_renderer() or not scenario.ends_with("/verylow"):
		_fail("PERF22: нужен Mobile на «Очень низкой»")
	if counts[3] > 0:
		_fail("PERF22: после загрузки %d кадров >100 мс" % counts[3])
	for action: String in ["первый бой · загрузка", "первый бой · бой и итог"]:
		var over: PackedInt64Array = phase_counts.get(action, PackedInt64Array([0, 0, 0, 0]))
		if not phase_samples.has(action):
			_fail("PERF22: нет замера «%s»" % action)
		elif over[2] > 0:
			_fail("PERF22: «%s» — %d кадров >50 мс" % [action, over[2]])


func _actions() -> void:
	_mark("поворот к площадке")
	game.rig.set_view(Vector3(62, Land.BASE_Y, 80), 15, 42, 64)
	await frames(45)
	_mark("анимация строительства")
	var home := Vector2(64, 74)
	game.build_anim = true
	var sliced := args.has("focus")
	var b0 := game.city.place("house_pleb", home, 0.0, 0, 0, true, Vector2i.ZERO, sliced)
	game.build_anim = false
	if sliced and not b0.is_empty():
		if not game._grow_live.has(b0["id"]):
			_fail("первая стройка без анимации")
		game._finish_placement({}, home)
	await get_tree().create_timer(4.5, false, false, true).timeout
	if sliced:
		_mark("снос первого дома")
	if not b0.is_empty():
		if sliced:
			await _demolish_focus(b0)
		else:
			game.city.remove(b0, false)
	elif sliced:
		_fail("первая стройка не запущена")
	await frames(6)
	await _colosseum_normal()
	var types: Array[String] = []
	for key: String in Defs.B:
		if game.city.city_buildable(key) and not Defs.B[key].get("fixed", false) and key != "center":
			types.append(key)
	# Одна площадка на тип, затем освобождаем место. Сотни тестовых объектов не остаются в городе.
	var view_pos := Vector3(62, Land.BASE_Y, 80)
	for key in types:
		if args.has("focus") and key not in ["medic", "academy"]:
			continue
		if args.has("focus"):
			_mark("модель " + key)
			await game._request_preview(key, 0, 0)
		var had_credit := game.city.wonder_credits.has(key)
		var original_credit := int(game.city.wonder_credits.get(key, 0))
		game.city.wonder_credits[key] = 1
		var def: Dictionary = Defs.B[key]
		var cell := Vector2(62, 80)
		if def.get("water", false):
			cell = Vector2(62, 152)
		elif def.get("shore", false):
			cell = Vector2(62, 171)
		var camera_target := Vector3(cell.x, Land.BASE_Y, cell.y)
		if view_pos.distance_to(camera_target) > 18.0:
			_mark("поворот к воде" if def.get("water", false) or def.get("shore", false) else "возврат к площадке")
			game.rig.set_view(camera_target, 15, 42, 64)
			view_pos = camera_target
			await frames(12)
		var level_before := game.city.level
		if args.has("focus") and key == "academy":
			game.city.level = maxi(level_before, 6)
		for pass_index in 2:
			_mark("строительство %s #%d" % [key, pass_index + 1])
			game._place_refresh_frame = Engine.get_process_frames()
			var b: Dictionary
			if args.has("focus"):
				b = await _place_focus(key, cell)
			else:
				b = game.city.place(key, cell, 0.0, 0, 0, true)
			if b.is_empty() or not is_finite(float(b.get("y", INF))):
				_fail("постройка " + key)
				continue
			await frames(2)
			_mark("открытие карточки %s #%d" % [key, pass_index + 1])
			game.select_building(b)
			await frames(2)
			_mark("закрытие карточки " + key)
			game.hud._hide_info()
			await frames(1)
			_mark("снос тестовой постройки " + key)
			if args.has("focus"):
				await _demolish_focus(b)
				_verify_placement("снос " + key)
			else:
				game.city.remove(b, false)
			await frames(2)
		game.city.level = level_before
		if had_credit:
			game.city.wonder_credits[key] = original_credit
		else:
			game.city.wonder_credits.erase(key)

	_mark("портрет горожанина")
	if not game.people.residents.is_empty():
		game.hud.open_person({"r": game.people.residents[0]})
		await frames(20)
		if not game.hud.info_panel.visible or not game.hud.info_p.has("r"):
			_fail("не открылась карточка горожанина")
		game.hud._hide_info()
	_mark("портрет кота")
	if not game.people.cats.is_empty():
		game.hud.open_person({"cat": game.people.cats[0]})
		await frames(20)
		if not game.hud.info_panel.visible or not game.hud.info_p.has("cat"):
			_fail("не открылась карточка кошки")
		game.hud._hide_info()

	_mark("смена дня")
	await game._sim_hour(true)
	await frames(3)
	var saved_at := FileAccess.get_file_as_string(game.save_path())
	game.can_save = true
	_mark("автосохранение")
	await game._autosave()
	await frames(6)
	var saved := FileAccess.get_file_as_string(game.save_path())
	if saved == saved_at or not JSON.parse_string(saved) is Dictionary:
		_fail("не обновился файл автосохранения")
	game.can_save = false

	_mark("открытие форта")
	var camp := CampUI.attach(game.hud)
	camp.open()
	await frames(60)
	_mark("закрытие форта")
	camp.close()
	await frames(30)
	_mark("открытие боя")
	var battle := open_battle(false)
	await frames(6)
	_mark("бой 16×16")
	var battle_end := Time.get_ticks_msec() + 80000
	while is_instance_valid(battle) and battle.phase != "result" and Time.get_ticks_msec() < battle_end:
		await frames(1)
	if is_instance_valid(battle) and battle.phase == "result":
		_mark("завершение боя")
		battle._close()
		await battle.tree_exited
	else:
		_fail("бой не дошёл до итогов")
		if is_instance_valid(battle):
			battle.abort()
	await frames(20)

	_mark("дождь")
	game.weather.force = 1.0
	await frames(30)
	_mark("ночь")
	game._set_hour(23.0)
	await frames(30)
	_mark("утро / прекращение дождя")
	game.weather.force = 0.0
	game._set_hour(9.0)
	await frames(30)
	_mark("исследования")
	game.hud._top_action("research")
	await frames(12)
	game.hud._close_windows()
	_mark("просьбы")
	game.hud.fold_tasks(false)
	await frames(12)
	game.hud.fold_tasks(true)
	_mark("настройки")
	game.hud._open_settings()
	await frames(12)
	game.hud._close_windows()
	_mark("отдаление")
	var views := OWNER_VIEWS if scenario.begins_with("owner") else NEW_VIEWS
	set_view(views, 2)
	await frames(30)
	_mark("приближение")
	set_view(views, 0)
	await frames(30)


func _colosseum_normal() -> void:
	_mark("Колизей · предварительный просмотр")
	await game._request_preview("colosseum", 0, 0)
	_mark("Колизей · обычная анимация стройки")
	game.speed = 3.0
	var before := int(game.city.wonder_credits.get("colosseum", 0))
	game.city.wonder_credits["colosseum"] = 1
	var b := await _place_focus("colosseum", Vector2(62, 80))
	if before > 0:
		game.city.wonder_credits["colosseum"] = before
	else:
		game.city.wonder_credits.erase("colosseum")
	game.speed = 0.0
	if b.is_empty():
		_fail("Колизей: стройка не запущена")
		return
	var id := int(b["id"])
	var deadline := Time.get_ticks_msec() + 25000
	while game._grow_live.has(id) and Time.get_ticks_msec() < deadline:
		await frames(1)
	if not game.visuals.has(id) or not game.spectacle.venues.has(id):
		_fail("Колизей: после стройки нет трибун")
	_mark("снос тестового Колизея")
	await _demolish_focus(b)
	if game.spectacle.venues.has(id):
		_fail("Колизей остался после сноса")
	if args.has("focus"):
		_verify_placement("снос colosseum")
	game._clear_preview_models()
	await frames(8)


func _demolish_focus(b: Dictionary) -> void:
	var id := int(b["id"])
	game.demolish_building(b, false)
	while game._placement_running:
		await frames(1)
	if game.city.buildings.has(id) or game.visuals.has(id) or game._grow_live.has(id):
		_fail("осталась постройка после сноса " + String(b["type"]))


## Настоящее нажатие «поставить» с выбранной постройкой, затем сверка итогов пересчёта.
func _place_focus(type: String, at: Vector2) -> Dictionary:
	var action := phase
	_mark("предварительный просмотр " + type)
	game.set_tool(type)
	game.next_variant = 0
	while game._preview_pending:
		await frames(1)
	game.hover = at
	var pl := game.placement(type, at)
	await game._request_preview(type, int(pl["tier"]), int(pl["variant"]), int(pl["color"]))
	if pl["err"] != "":
		_fail("%s: %s" % [type, pl["err"]])
		game.set_tool("")
		return {}
	if is_instance_valid(game.ghost):
		game.ghost.queue_free()
	game.ghost_key = "%s:%d:%d:%d:%s" % [type, pl["tier"], pl["variant"], pl["color"], Vector2i.ZERO]
	game.ghost = game._take_preview_ghost(Catalog.make(type, pl["tier"], pl["variant"], pl["color"]), game.ghost_key)
	game.ghost.show()
	await frames(2)
	_mark(action)
	var id := game.city.next_id
	game.hover = at
	game._build_here()
	while game._placement_running:
		await frames(1)
	await frames(2)
	var b: Dictionary = game.city.buildings.get(id, {})
	if not b.is_empty() and args.has("focus"):
		_verify_placement(type)
	game.set_tool("")
	return b


func _verify_placement(type: String) -> void:
	# Сама сверка не входит в замер игрового кадра.
	active = false
	var c := game.city
	var snapshot := JSON.stringify(c.save_data(true))
	var ready_upgrades = c._upg_ready
	var stats := c.stats.duplicate(true)
	var fields := {}
	for b: Dictionary in c.buildings.values():
		fields[b["id"]] = [b["road"], b["staff"], b["active"], b["needs"].duplicate(true), b.get("happy_target")]
	c.compute(true)
	c._upg_ready = ready_upgrades
	var match_ok := snapshot == JSON.stringify(c.save_data(true)) and stats == c.stats
	for b: Dictionary in c.buildings.values():
		match_ok = match_ok and fields[b["id"]] == [b["road"], b["staff"], b["active"], b["needs"], b.get("happy_target")]
	if not match_ok:
		_fail("сохранение или поля расчёта отличаются после стройки: " + type)
	else:
		_line("Сверка полей после стройки %s: совпали." % type)
	Timers.reset_frame()
	CityTimers.usec.fill(0)
	before = Time.get_ticks_usec()
	active = true


func _free_play() -> void:
	game.can_save = true
	game.hud.set_speed(3.0)
	var seconds := float(args.get("seconds", "180"))
	_mark("свободная симуляция ×3")
	await get_tree().create_timer(seconds, false, false, true).timeout
	game.hud.set_speed(0.0)
	game.can_save = false


func _prepare_sites() -> void:
	# Две площадки вдали от исходного города, одна с тестовым прудом.
	var land := game.land
	for x in [28.0, 62.0, 96.0]:
		for z in [46.0, 80.0, 114.0, 152.0, 171.0]:
			land.owned[land.plot_of(Vector2(x, z))] = true
	land.flatten_cells(land.footprint_cells([Rect2(-34, -34, 68, 68)], Vector2(62, 80), 0.0),
		Land.BASE_Y, Land.Kind.GRASS)
	land.flatten_cells(land.footprint_cells([Rect2(-25, -19, 50, 38)], Vector2(62, 152), 0.0),
		Land.WATER_Y - Land.STEP, Land.Kind.SAND)
	land.flatten_cells(land.footprint_cells([Rect2(-12, 0, 24, 12)], Vector2(62, 171), 0.0),
		Land.BASE_Y, Land.Kind.GRASS)


func _mark(action: String) -> void:
	phase = action
	pending.append(action)


func _pipelines() -> PackedInt64Array:
	var values := PackedInt64Array()
	for id: Performance.Monitor in PIPELINES:
		values.append(int(Performance.get_monitor(id)))
	return values


func _before_draw() -> void:
	if active:
		draw_started = Time.get_ticks_usec()
		process_ms = (draw_started - before) / 1000.0


func _after_draw() -> void:
	if active and draw_started > 0:
		draw_ms = (Time.get_ticks_usec() - draw_started) / 1000.0
		draw_started = 0


func _frame() -> void:
	if not active:
		return
	var now := Time.get_ticks_usec()
	var ms := (now - before) / 1000.0
	var pipes := _pipelines()
	if args.has("perf20c"):
		var samples: Array = phase_samples.get_or_add(phase, [])
		samples.append(ms)
		var totals: PackedInt64Array = phase_pipelines.get(phase, PackedInt64Array([0, 0, 0, 0, 0]))
		for i in pipes.size():
			totals[i] += pipes[i] - pipeline_counts[i]
		phase_pipelines[phase] = totals
	if ms > LIMITS[0] or (args.has("ui_trace") and Timers.usec[Timers.UI] > 8000):
		var split := Timers.sections()
		for id in CityTimers.LABELS.size():
			if CityTimers.usec[id] > 0:
				split[CityTimers.LABELS[id]] = CityTimers.usec[id] / 1000.0
		var vp := get_viewport().get_viewport_rid()
		var extras := {}
		if phase != "загрузка" and is_instance_valid(game):
			for sub: SubViewport in game.find_children("*", "SubViewport", true, false):
				if sub.render_target_update_mode != SubViewport.UPDATE_DISABLED:
					var sub_rid := sub.get_viewport_rid()
					RenderingServer.viewport_set_measure_render_time(sub_rid, true)
					extras[str(sub.get_path())] = RenderingServer.viewport_get_measured_render_time_gpu(sub_rid)
		var row := {"scenario": scenario, "frame": frame_count, "ms": ms, "phase": phase,
			"actions": pending.duplicate(), "sections_ms": split, "loads_us": Timers.load_paths.duplicate(),
			"process_ms": process_ms, "draw_ms": draw_ms, "game_hour": game.hour if is_instance_valid(game) else 0.0,
			"loading_step": game.loading_step if is_instance_valid(game) and phase == "загрузка" else "",
			"clock_busy": is_instance_valid(game) and game._clock_busy, "hour_total_ms": CityTimers.usec[CityTimers.CITY_HOUR] / 1000.0, "render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(vp),
			"gpu_root_ms": RenderingServer.viewport_get_measured_render_time_gpu(vp), "gpu_sub_ms": extras,
			"pipeline_canvas_mesh_surface_draw_specialization": []}
		for i in pipes.size():
			row["pipeline_canvas_mesh_surface_draw_specialization"].append(pipes[i] - pipeline_counts[i])
		if args.has("perf22g") and pipes[3] > pipeline_counts[3]:
			var battle := LegionBattle.current
			if is_instance_valid(battle) and is_instance_valid(battle.battle_view):
				var fading := PackedStringArray()
				for fighter: LegionBattleView.Fighter in battle.battle_view.views.values():
					if is_instance_valid(fighter.actor) and fighter.actor._opacity < 1.0:
						fading.append(fighter.unit.key)
				row["fading_actors"] = fading
		traces.append(JSON.stringify(row))
		if top.size() < 10 or float(top[-1]["ms"]) < ms:
			top.append(row)
			top.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["ms"] > b["ms"])
			if top.size() > 10:
				top.pop_back()
		var per_phase: PackedInt64Array = phase_counts.get(phase, PackedInt64Array([0, 0, 0, 0]))
		for i in LIMITS.size():
			var hit := int(ms > LIMITS[i])
			counts[i] += hit
			per_phase[i] += hit
		phase_counts[phase] = per_phase
	frame_count += 1
	pipeline_counts = pipes
	pending.clear()
	Timers.reset_frame()
	CityTimers.usec.fill(0)
	draw_ms = 0.0
	process_ms = 0.0
	before = Time.get_ticks_usec()


func _finish(startup := false) -> void:
	await frames(1)
	active = false
	Timers.enabled = false
	CityTimers.enabled = false
	for event: String in traces:
		events.store_line(event)
	events.flush()
	var free: PackedInt64Array = phase_counts.get("свободная симуляция ×3", PackedInt64Array([0, 0, 0, 0]))
	_line("")
	if not startup:
		_line("Свободная игра ×3 (%s): %d / %d / %d / %d кадров >25 / >33 / >50 / >100 мс." % [scenario, free[0], free[1], free[2], free[3]])
		_line("")
	_line("## %s%s · %d кадров" % [scenario, " · загрузка" if startup else "", frame_count])
	_line("")
	_line("| >25 мс | >33 мс | >50 мс | >100 мс |")
	_line("|---:|---:|---:|---:|")
	_line("| %d | %d | %d | %d |" % [counts[0], counts[1], counts[2], counts[3]])
	_line("")
	if args.has("perf20c"):
		_phase_report()
	_line("| Кадр | мс | Действие | Основные замеры CPU, мс | GPU / компиляции draw |")
	_line("|---:|---:|---|---|---:|")
	for row in top:
		var sorted: Array = row["sections_ms"].keys()
		sorted.sort_custom(func(a: String, b: String) -> bool: return row["sections_ms"][a] > row["sections_ms"][b])
		var parts := PackedStringArray()
		for key: String in sorted.slice(0, 5):
			if row["sections_ms"][key] >= 0.2:
				parts.append("%s %.1f" % [key, row["sections_ms"][key]])
		_line("| %d | %.1f | %s | %s | %.1f / %d |" % [row["frame"], row["ms"], row["phase"],
			", ".join(parts), row["gpu_root_ms"], row["pipeline_canvas_mesh_surface_draw_specialization"][3]])


func _phase_report() -> void:
	_line("| Действие | Кадры | p99, мс | 1% low, к/с | Пик, мс | >50 мс | >100 мс | Draw | Specialization |")
	_line("|---|---:|---:|---:|---:|---:|---:|---:|---:|")
	for action: String in phase_samples:
		var samples: Array = phase_samples[action]
		samples.sort()
		var n := samples.size()
		var p99: float = samples[ceili(n * 0.99) - 1]
		var slow := maxi(1, ceili(n * 0.01))
		var slow_ms := 0.0
		for i in range(n - slow, n):
			slow_ms += float(samples[i])
		var late: PackedInt64Array = phase_counts.get(action, PackedInt64Array([0, 0, 0, 0]))
		var pipes: PackedInt64Array = phase_pipelines[action]
		_line("| %s | %d | %.2f | %.1f | %.2f | %d | %d | %d | %d |" %
			[action, n, p99, 1000.0 * slow / maxf(0.001, slow_ms), samples[-1], late[2], late[3], pipes[3], pipes[4]])
	_line("")


func _line(line: String) -> void:
	report.store_line(line)
	report.flush()
	print(line)


func _fail(reason: String) -> void:
	fails += 1
	print("HITCH14 FAIL ", reason)
