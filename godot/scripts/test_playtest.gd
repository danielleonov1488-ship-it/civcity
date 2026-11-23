extends Node3D
## Новая игра через интерфейс. Модель читаем для маршрута и замеров.

const Record = preload("res://scripts/test_playtest_record.gd")
const MapBadge = preload("res://scripts/map_badge.gd")
const Guide = Legion.FortGuide
const MAIN = preload("res://main.tscn")
const TASK := "D:/CivCity/.work/stage7/playtest13"
const SIZE := Vector2i(1920, 1080)
const CITY_FAST := 4.0 # Третья ступень на панели города.
const CITY_KEYS := ["buildings", "land", "money", "rp", "level", "research", "goals", "arrivals",
	"incoming", "settled_total", "road_cells", "plots_bought", "name", "hero", "stories", "wonder_credits"]
const FORT_KEYS := ["fort", "soldiers", "items", "squad3", "progress", "wins", "stars", "mats",
	"ingots", "pending_resources", "rations", "hero_lv3", "hero_training", "chest_queue", "market"]

var log := Record.new()
var game: Game
var hud: Hud
var city: City
var tut: Tutorial
var camp: CampUI
var fort: Legion
var previous_pointer_step := ""
var previous_pointer_id := 0
var previous_fort_step := -1
var previous_fort_id := ""
var toasts := {}
var popups := {}
var bell := 0
var watched_hud := 0
var mouse := Vector2(960, 510)
var mouse_buttons := 0
var key_shots: Array[String] = []
var step_label := ""
var road_origin := Vector2.ZERO
var homes: Array[Dictionary] = []
var counts := {"build": 0, "settle": 0, "hire": 0, "research": 0, "roads": 0, "cards": 0, "requests": 0}
var status := {}
var output := TASK
var profile := ""
var taking_measurements := false
var allow_pause_on_load := false


func _ready() -> void:
	# Game.restart() должен перезагружать обычную main.tscn, а наблюдатель остаётся в корне дерева.
	process_priority = 10000
	call_deferred("_run")


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			output = arg.trim_prefix("out=")
		if arg.begins_with("--savedir="):
			profile = arg.trim_prefix("--savedir=")
	if profile.is_empty():
		profile = output.path_join("profiles/%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()])
	if not log.setup(output):
		print("PLAYTEST FAIL Не удалось создать папку снимков")
		get_tree().quit(1)
		return
	if DisplayServer.get_name() == "headless" or not _profile():
		_fail("Для прогона нужны отдельный профиль и окно Godot")
		await _finish()
		return
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = SIZE
	get_tree().auto_accept_quit = false
	log.viewport_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(log.viewport_rid, true)
	RenderingServer.frame_pre_draw.connect(log.pre_draw)
	RenderingServer.frame_post_draw.connect(log.post_draw)
	Game.sandbox = false
	Game.boot = {"new": "1", "nologin": "1"}
	var main := MAIN.instantiate() as Game
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	var ready := await _wait("запуск новой игры", func(): return main.ready_done, 90.0)
	if not ready:
		await _finish()
		return
	_bind(main)
	log.metric("run.profile", profile)
	log.metric("run.quality", game.settings.get("quality"))
	log.metric("run.viewport", str(get_viewport().get_visible_rect().size))
	log.metric("run.sandbox", Game.sandbox)
	await _begin(1)
	status["city_tutorial"] = await _city_tutorial()
	if not status["city_tutorial"] and tut.active() and _press(_button(tut.card, "TutorialSkip")):
		log.issue("Обучение города прервано через кнопку, чтобы проверить оставшиеся фазы")
		await _frames(8)
	await _begin(2)
	status["free_play"] = await _free_play()
	await _begin(3)
	status["fort"] = await _fort_route()
	await _begin(4)
	status["reload"] = await _settings_and_reload()
	await _finish()


func _profile() -> bool:
	if DirAccess.make_dir_recursive_absolute(profile) != OK:
		return false
	if FileAccess.file_exists(profile.path_join("city.json")) or FileAccess.file_exists(profile.path_join("settings.json")):
		return false
	GamePaths._dir = ""
	OS.set_environment("CIVCITY_SAVEDIR", profile)
	OS.set_environment("CIVCITY_NOLOGIN", "1")
	OS.set_environment("CIVCITY_HEROSCREEN", "1")
	var settings := FileAccess.open(profile.path_join("settings.json"), FileAccess.WRITE)
	if settings == null:
		return false
	settings.store_string(JSON.stringify({"quality": "high", "quality_user": true}))
	settings.close()
	return true


func _bind(main: Game) -> void:
	game = main
	hud = game.hud
	city = game.city
	tut = game.tutorial
	camp = CampUI.of(hud)
	fort = city.legion


func _begin(number: int) -> void:
	while not key_shots.is_empty():
		await get_tree().process_frame
	step_label = ""
	log.begin(number)
	taking_measurements = true
	print("PLAYTEST PHASE ", number)


func _fail(reason: String) -> bool:
	print("PLAYTEST FAIL ", reason)
	log.issue(reason)
	return false


func _check(condition: bool, reason: String) -> bool:
	return condition or _fail(reason)


func _finish() -> void:
	while log.busy or not key_shots.is_empty():
		await get_tree().process_frame
	taking_measurements = false
	log.evidence["routes"] = status
	log.finish()
	if not OS.get_cmdline_user_args().has("--playtest-postprocess"):
		print("PLAYTEST DONE issues=", log.issues.size())
	get_tree().quit(0 if log.issues.is_empty() else 1)


func _process(dt: float) -> void:
	if not taking_measurements:
		return
	var active := get_tree().current_scene as Game
	var window := "loading"
	if is_instance_valid(active) and active.ready_done:
		window = "settings" if active.hud.settings_panel.visible else "play"
	var load_step := "" if active == null else active.loading_step
	log.clock(dt, game.speed if is_instance_valid(game) and game.ready_done else 0.0, window, load_step)
	if active != null and active.ready_done and active != game:
		_bind(active)
		if allow_pause_on_load and game.mode == "play":
			_speed(0.0)
	if not is_instance_valid(game) or not game.is_inside_tree() or not game.ready_done:
		log.frame(get_viewport(), "Загрузка")
		return
	var battle := LegionBattle.current
	var windows := _windows(battle)
	var title := _title(battle)
	_track_arrows()
	_track_messages(windows)
	_track_steps(battle)
	log.scan_text(game, title, get_viewport().get_visible_rect(), I18n.lang == "en")
	log.frame(get_viewport(), title)
	if not key_shots.is_empty():
		log.shot(get_viewport(), key_shots.pop_front())


func _windows(battle: LegionBattle) -> Dictionary:
	var windows := {}
	for control: Control in [hud.settings_panel, hud.pause_panel, hud.buy_panel, hud.credits_panel,
			hud.research_tree.confirm,
			camp.modal_panel if is_instance_valid(camp) else null, battle.modal if is_instance_valid(battle) else null]:
		if _shown(control):
			windows[control.get_instance_id()] = str(control.name)
	return windows


func _title(battle: LegionBattle) -> String:
	if is_instance_valid(battle):
		return "Бой · " + battle.phase
	if _shown(camp.modal_panel):
		if camp.modal_panel.name == &"FortMarketWindow":
			return I18n.t("Рынок")
		return _caption(camp.modal_panel, str(camp.modal_panel.name))
	if camp.lu.visible:
		return "К походу" if camp.lu.fort_prep_open else "Карта похода"
	if camp.visible:
		if _shown(camp.card):
			return _caption(camp.card, "Карточка форта")
		return camp.guide_text.text if _shown(camp.guide) else "Форт"
	if HeroScreen.is_open(game):
		return "Ваш герой"
	if not tut.cine.is_empty():
		return "Едут! · повозка"
	for panel: Control in [hud.settings_panel, hud.pause_panel, hud.research_panel, hud.info_panel, hud.advisor_panel]:
		if _shown(panel):
			return _caption(panel, str(panel.name))
	if tut.active():
		return tut.title.text
	return "Главное меню" if game.mode == "menu" else "Город"


func _caption(control: Control, fallback: String) -> String:
	for label: Label in control.find_children("*", "Label", true, false):
		if label.is_visible_in_tree() and not label.text.is_empty():
			return log.translated(label, label.text)
	return fallback


func _track_steps(battle: LegionBattle) -> void:
	var label := ""
	if log.phase == 1 and tut.active() and _shown(tut.card) and not HeroScreen.is_open(game):
		label = "city_" + tut.cur_id()
	elif log.phase == 3 and (camp.visible or camp.lu.visible or is_instance_valid(battle)):
		var step := fort.fort_guide_step()
		if step > Guide.INACTIVE and step < Guide.DONE:
			label = "fort_%02d_%s" % [step, str(Guide.keys()[step]).to_lower()]
	if label != "" and step_label != label:
		step_label = label
		log.progress(label)
		_shot("p%d_%s" % [log.phase, label])


func _track_arrows() -> void:
	var city_id := hud._pointer_id
	var city_step := tut.cur_id()
	var city_shown := _shown(hud.pointer) and (tut.active() or hud._ptr_shown.is_empty())
	var city_stale := city_id == previous_pointer_id and previous_pointer_step != city_step
	if not city_stale or not city_shown:
		previous_pointer_step = city_step
	previous_pointer_id = city_id
	log.arrow("city", "%s/%s" % [previous_pointer_step, _target_key(hud.pointer_target, hud.pointer_text.text)],
		city_shown, hud.pointer.global_position, hud._pointer_side, hud._pointer_draw_gliding,
		city_stale or (tut.active() and tut._check(city_step)), not tut.active())
	if not is_instance_valid(camp.guide_pointer):
		log.arrow("fort", "", false, Vector2.ZERO, false, false, false, false)
		return
	var step := fort.fort_guide_step()
	var fort_id := camp._guide_arrow_id
	var fort_shown := _shown(camp.guide_pointer) and camp._guide_lesson_id.is_empty()
	var fort_stale := fort_id == previous_fort_id and previous_fort_step != step
	if not fort_stale or not fort_shown:
		previous_fort_step = step
	previous_fort_id = fort_id
	log.arrow("fort", "%d/%s" % [previous_fort_step, _target_key(camp._guide_target, camp.guide_text.text)],
		fort_shown, camp.guide_pointer.global_position, camp.guide_pointer.flip_v,
		camp._guide_arrow_draw_gliding, fort_stale, step >= Guide.DONE)


func _target_key(target: Variant, fallback: String) -> String:
	if is_instance_valid(target) and target is Control:
		if not str(target.name).begins_with("@"):
			return str(target.name)
		if target is Button and not target.text.is_empty():
			return target.text
		if not target.tooltip_text.is_empty():
			return target.tooltip_text
	return fallback


func _track_messages(windows: Dictionary) -> void:
	var now_toasts := {}
	var now_popups := {}
	if _shown(hud.notes_box):
		for note: Control in hud.notes_box.get_children():
			if _shown(note):
				now_toasts[note.get_instance_id()] = true
	if _shown(hud.advisor_panel):
		now_popups[hud.adv_title.text] = true
		windows[hud.advisor_panel.get_instance_id()] = hud.adv_title.text
	var new_toasts := 0
	var new_popups := 0
	for id: int in now_toasts:
		new_toasts += int(not toasts.has(id))
	for title: String in now_popups:
		new_popups += int(not popups.has(title))
	var badge := hud.bell_count
	var hud_id := hud.get_instance_id()
	log.notifications(now_toasts.size(), new_toasts, now_popups.size(), new_popups,
		maxi(0, badge - bell) if watched_hud == hud_id else 0)
	toasts = now_toasts
	popups = now_popups
	bell = badge
	watched_hud = hud_id
	log.modal_windows(windows)


func _shown(control: Variant) -> bool:
	return is_instance_valid(control) and control is Control and control.is_visible_in_tree()


func _frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _wait(label: String, condition: Callable, timeout := 24.0, tutorial_wait := false, required := true,
		intro := false) -> bool:
	var start := Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec() - start < int(timeout * 1000.0):
		await get_tree().process_frame
	var elapsed := float(Time.get_ticks_msec() - start) / 1000.0
	if tutorial_wait:
		log.tutorial_wait(label, elapsed, intro)
	return bool(condition.call()) or (required and _fail("Тайм-аут: " + label))


func _shot(name_text: String) -> void:
	if not key_shots.has(name_text):
		key_shots.append(name_text)


func _button(root: Node, node_name: String) -> Button:
	return root.find_child(node_name, true, false) as Button if is_instance_valid(root) else null


func _button_text(root: Node, caption: String) -> Button:
	if not is_instance_valid(root):
		return null
	for button: Button in root.find_children("*", "Button", true, false):
		if _shown(button) and (button.text == caption or log.translated(button, button.text) == caption):
			return button
	return null


func _press(button: BaseButton) -> bool:
	if not _shown(button) or button.disabled:
		return false
	button.pressed.emit()
	return true


func _guided() -> bool:
	var target := hud.pointer_target
	if not _shown(target) or target.is_queued_for_deletion():
		return false
	if target is BaseButton:
		return _press(target)
	if target is MapBadge and _shown(target):
		for key: String in hud.badges:
			if hud.badges[key]["n"] == target:
				return _press_badge(key)
	return false


func _press_badge(key: String) -> bool:
	var badge := hud.badges.get(key, {}).get("n") as Control
	if not _shown(badge) or not _on_map(badge.get_global_rect().get_center()):
		return false
	var click := InputEventMouseButton.new()
	click.position = badge.get_global_rect().get_center()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	hud._badge_input(click, key)
	return true


func _speed(value: float) -> bool:
	for entry: Array in hud.speed_btns:
		if float(entry[1]) == value:
			return _press(entry[0])
	return false


func _event(event: InputEvent) -> void:
	get_viewport().push_input(event, true)


func _move(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = point - mouse
	event.button_mask = mouse_buttons
	mouse = point
	_event(event)


func _mouse_button(point: Vector2, index: MouseButton, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = index
	event.pressed = down
	if index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		var bit := 1 << (index - 1)
		mouse_buttons = (mouse_buttons | bit) if down else (mouse_buttons & ~bit)
	event.button_mask = mouse_buttons
	_event(event)


func _click(point: Vector2) -> void:
	_move(point)
	_mouse_button(point, MOUSE_BUTTON_LEFT, true)
	_mouse_button(point, MOUSE_BUTTON_LEFT, false)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	_event(event)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	_event(event)


func _pan(delta: Vector2) -> void:
	# Движение настоящего обработчика камеры. Мышь ОС остаётся у владельца.
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	game.rig._unhandled_input(right)
	var motion := InputEventMouseMotion.new()
	motion.relative = delta
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	game.rig._unhandled_input(motion)
	right.pressed = false
	game.rig._unhandled_input(right)


func _pan_to(point: Vector2) -> void:
	var rig := game.rig
	var delta := Vector2(rig._target_t.x, rig._target_t.z) - point
	var yaw := rig._yaw_t
	var amount := rig._dist_t * 0.0016
	_pan(Vector2(delta.dot(Vector2(cos(yaw), -sin(yaw))), delta.dot(Vector2(sin(yaw), cos(yaw)))) / amount)
	await _pause(0.35)


func _world(point: Vector2, height := 0.0) -> Vector2:
	return game.rig.cam.unproject_position(Vector3(point.x, game.land.height_at(point.x, point.y) + height, point.y))


func _on_map(point: Vector2) -> bool:
	return get_viewport().get_visible_rect().grow(-12).has_point(point)


func _build_tool(kind: String, guided: bool) -> bool:
	for attempt in 5:
		if game.tool == kind:
			return true
		var target := hud._card_or_cat(String(Defs.B[kind]["cat"]), kind) as BaseButton
		var clicked := _guided() if guided else _press(target)
		if not clicked:
			await _pause(0.25)
		else:
			await _frames(4)
	return game.tool == kind


func _place(kind: String, near: Vector2, road := false) -> Dictionary:
	var offsets: Array[Vector2] = []
	for z in range(-6, 7, 2):
		for x in range(-6, 7, 2):
			offsets.append(Vector2(x, z))
	offsets.sort_custom(func(a: Vector2, b: Vector2): return a.length_squared() < b.length_squared())
	var tried := 0
	for offset: Vector2 in offsets:
		if game.tool != kind:
			break
		var spot := near + offset
		var point := _world(spot)
		if not _on_map(point):
			continue
		# Сначала оценка места, затем настоящий призрак в этой точке и щелчок.
		var approximate := game.placement_hint(kind, spot)
		if approximate.get("err") != "" or (road and approximate.get("noroad", false)):
			continue
		tried += 1
		_move(point)
		await _frames()
		var placement := game.place_info
		if hud.mouse_over_ui() or not is_instance_valid(game.ghost) or not game.ghost.visible \
				or placement.get("err") != "" or (road and placement.get("noroad", false)):
			continue
		var id := city.next_id
		_click(point)
		await _frames(3)
		if city.buildings.has(id):
			counts["build"] += 1
			log.progress("построено " + kind)
			return city.buildings[id]
	print("PLAYTEST OBS нет места ", kind, " рядом с ", near, " проверено призраков=", tried)
	return {}


func _road_tool(guided: bool) -> bool:
	if game.tool != "road":
		if guided:
			_guided()
		else:
			_press(hud.road_target() as BaseButton)
		await _frames(4)
	if game.tool != "road":
		_press(hud.road_btns.get("road") as Button)
		await _frames(3)
	return game.tool == "road"


func _paint(points: Array[Vector2]) -> bool:
	var start := _world(points[0])
	if not _on_map(start):
		return false
	_move(start)
	await _frames()
	if hud.mouse_over_ui():
		return false
	var before := city.road_cells
	_mouse_button(start, MOUSE_BUTTON_LEFT, true)
	for i in range(1, points.size()):
		var parts := maxi(2, ceili(points[i - 1].distance_to(points[i]) / 4.0))
		for k in range(1, parts + 1):
			_move(_world(points[i - 1].lerp(points[i], float(k) / parts)))
			await _frames()
	_mouse_button(mouse, MOUSE_BUTTON_LEFT, false)
	await _frames(5)
	if city.road_cells > before:
		counts["roads"] += 1
		log.progress("новый участок дороги")
		return true
	return false


func _city_tutorial() -> bool:
	var hero := hud.get_node_or_null("HeroScreen") as HeroScreen
	if not _check(hero != null, "Новая игра не открыла выбор героя"):
		return false
	_shot("p1_hero")
	await _pause(0.5)
	_press(_button_text(hero, "Случайный"))
	await _frames(4)
	if not _check(_press(_button(hero, "go")), "Нет кнопки создания героя"):
		return false
	if not await _wait("переход от героя к камере", func(): return _shown(tut.card) and not HeroScreen.is_open(game), 60, true):
		return false
	await _pause(0.4)
	_pan(Vector2(-240, 20))
	_pan(Vector2(240, -20))
	var zoom := InputEventMouseButton.new()
	zoom.button_index = MOUSE_BUTTON_WHEEL_UP
	zoom.pressed = true
	game.rig._unhandled_input(zoom)
	if not await _city_step("houses", "камера"):
		return false
	road_origin = city.door_point(city.center())
	await _pan_to(road_origin + Vector2(-8, 17))
	if not _check(await _build_tool("house_pleb", true), "Стрелка не привела к карточке дома"):
		return false
	for i in 3:
		var home := await _place("house_pleb", road_origin + Vector2(-13, 12 + i * 8))
		if not _check(not home.is_empty(), "Не построен дом %d" % (i + 1)):
			return false
		homes.append(home)
	if not await _city_step("road", "три дома") or not _check(await _road_tool(true), "Не выбрана кисть дороги"):
		return false
	var bottom := road_origin.y
	for home: Dictionary in homes:
		bottom = maxf(bottom, city.door_point(home).y + 3.0)
	await _paint([road_origin, Vector2(road_origin.x, bottom)])
	for home: Dictionary in homes:
		if game.tool != "road" and not await _road_tool(false):
			break
		var door := city.door_point(home)
		await _paint([Vector2(road_origin.x, door.y), door])
	if not await _city_step("settle", "прибытие первой повозки", 58, true):
		return false
	if not _check(not game.is_road_tool(game.tool), "Кисть дороги осталась активной на Новоселье"):
		return false
	await _pause(0.65)
	var family := {"house": -1, "start": 0, "arrived": 0}
	city.family_assigned.connect(func(_name: String, home: int):
		family["house"] = home
		family["start"] = Time.get_ticks_msec(), CONNECT_ONE_SHOT)
	city.house_changed.connect(func(home: Dictionary, _up: bool):
		if int(home["id"]) == int(family["house"]) and city.settled_total > 0 and family["arrived"] == 0:
			family["arrived"] = Time.get_ticks_msec())
	if not _check(await _settle(true), "Не удалось поселить первую семью") or not await _city_step("house", "выбор дома семьи"):
		return false
	var target := hud.pointer_target
	var followed := game.people.follows_settling_house(family["house"])
	log.metric("tutorial.follow_started", followed)
	_check(followed, "Камера не повела семью после выбора дома")
	if not _check(target is MapBadge and hud.pointer_text.text == "Семья въезжает…", "Шаг не указал на дом семьи сразу"):
		return false
	var opened := _guided() or _press(tut.show_btn)
	if not _check(opened, "Не удалось открыть дом семьи") or not await _city_step("house_info", "карточка дома"):
		return false
	var arriving := int(hud.info_b.get("id", -1)) == int(family["house"]) and city.settled_total == 0 \
		and _shown(hud.info_panel.find_child("HouseArriving", true, false))
	log.metric("tutorial.house_open_before_arrival", arriving)
	_check(arriving, "Карточка дома не показала семью в пути")
	var camera_start := game.rig.target
	await log.shot(get_viewport(), "p1_house_arriving")
	await _pause(0.7)
	_check(game.people.follows_settling_house(family["house"]) and game.rig.target.distance_to(camera_start) > 0.1,
		"Камера не продолжила движение при открытой карточке")
	_press(tut.next_btn)
	if not await _city_step("food", "пояснение значков дома"):
		return false
	await _pan_to(road_origin + Vector2(-8, 17))
	if not _check(await _build_tool("stall_fruit", true), "Не выбрана фруктовая лавка"):
		return false
	if not _check(not (await _place("stall_fruit", road_origin + Vector2(-5, 14))).is_empty(), "Не поставлена фруктовая лавка"):
		return false
	if not await _city_step("workers", "фруктовая лавка"):
		return false
	if not await _guided_hire("workers") or not await _city_step("script", "найм в лавку"):
		return false
	var walk := float(int(family["arrived"]) - int(family["start"])) / 1000.0
	log.metric("tutorial.family_walk_seconds", walk)
	_check(walk > 0.0 and walk <= 6.0, "Семья шла до дома %.2f с (порог 6 с)" % walk)
	if not _check(await _build_tool("scriptorium", true), "Не выбран скрипторий"):
		return false
	if not _check(not (await _place("scriptorium", road_origin + Vector2(-5, 26))).is_empty(), "Не поставлен скрипторий"):
		return false
	if not await _guided_hire("script") or not await _city_step("research", "найм писца"):
		return false
	if not await _research(true) or not await _city_step("done", "исследование"):
		return false
	await _pause(0.8)
	_press(tut.next_btn)
	return await _wait("завершение обучения города", func(): return not tut.active(), 8, true)


func _city_step(id: String, description: String, timeout := 18.0, intro := false) -> bool:
	return await _wait(description, func(): return tut.cur_id() == id, timeout, true, true, intro)


func _settle(guided: bool) -> bool:
	if game.tool != "settle":
		if guided:
			await _wait("значок семьи", func(): return _shown(hud.pointer_target), 3, false, false)
			_guided()
			await _frames(4)
		if game.tool != "settle":
			for family: BaseButton in hud.fam_box.find_children("*", "BaseButton", true, false):
				if _press(family):
					break
		await _frames(5)
	if game.tool != "settle":
		if guided:
			print("PLAYTEST OBS семья не выбрана, инструмент=", game.tool, " target=", _target_key(hud.pointer_target, ""))
		return false
	var fitting := city.homes_for(game.settle_fam)
	if fitting.is_empty():
		if guided:
			print("PLAYTEST OBS у семьи нет доступного дома, домов=", homes.size())
		_key(KEY_ESCAPE)
		return false
	var before := city.settled_total + city.pending.size()
	if guided:
		_guided()
		await _frames(4)
	for home: Dictionary in fitting:
		if city.settled_total + city.pending.size() > before:
			break
		var key := "settle%d" % int(home["id"])
		if not _press_badge(key):
			await _pan_to(home["pos"])
			_press_badge(key)
		await _frames(4)
	if city.settled_total + city.pending.size() == before:
		_press(_button_text(hud.tool_panel, "Выбрать дом за меня"))
	await _frames(6)
	if city.settled_total + city.pending.size() <= before:
		return false
	counts["settle"] += 1
	log.progress("семья выбрала дом")
	if counts["settle"] == 1:
		_shot("p%d_first_settle" % log.phase)
	return true


func _guided_hire(step: String) -> bool:
	var started := Time.get_ticks_msec()
	var hired := false
	while tut.cur_id() == step and Time.get_ticks_msec() - started < 110000:
		var target := hud.pointer_target
		if _shown(target) and not target.is_queued_for_deletion():
			if target is Button and target.has_meta("hire_class") and not target.disabled:
				var building_id := int(hud.info_b.get("id", -1))
				var before := city.hired_of(hud.info_b)
				_click(target.get_global_transform_with_canvas() * (target.size * 0.5))
				await _frames(6)
				var building: Dictionary = city.buildings.get(building_id, {})
				if not building.is_empty() and city.hired_of(building) > before:
					hired = true
					counts["hire"] += 1
					log.progress("нанят работник через «+»")
			elif not city.arrivals.is_empty() and await _settle(true):
				_hire_wait(step, started)
				started = Time.get_ticks_msec()
		await _pause(0.25)
	_hire_wait(step, started)
	var passed := hired and tut.cur_id() != step
	log.metric("tutorial.hire_" + step, passed)
	return _check(passed, "Шаг найма не завершился после щелчка «+»: " + step)


func _hire_wait(step: String, started: int) -> void:
	var seconds := float(Time.get_ticks_msec() - started) / 1000.0
	log.tutorial_wait(step + " · работник", seconds)


func _research(guided: bool) -> bool:
	var changes := city.research.size()
	if not _shown(hud.research_panel):
		var pressed := _guided() if guided else _press(hud.top_btns.get("research"))
		if not pressed:
			return false
		await _frames(6)
	var study: Button = hud.research_tree.cheapest_available()
	if not _press(study):
		_key(KEY_ESCAPE)
		return false
	await _frames(5)
	if not _press(hud.research_tree.confirm_yes):
		return false
	await _frames(4)
	if city.research.size() <= changes:
		return false
	counts["research"] += 1
	log.progress("исследование изучено")
	if counts["research"] == 1:
		_shot("p%d_first_research" % log.phase)
	await _pause(0.45)
	_key(KEY_ESCAPE)
	return true


func _free_play() -> bool:
	road_origin = city.door_point(city.center())
	_key(KEY_ESCAPE)
	if not _check(_speed(CITY_FAST), "Третья ступень скорости недоступна"):
		return false
	log.metric("city.free_play_speed", game.speed)
	var at_start := counts.duplicate()
	var deadline := Time.get_ticks_msec() + 540000
	var cycle := 0
	while float(log.phases[2]["game_s"]) < 1200.0 and Time.get_ticks_msec() < deadline:
		if game.rig.cine:
			await _pause(1.0)
			continue
		if game.speed != CITY_FAST:
			_speed(CITY_FAST)
		if _shown(hud.advisor_panel):
			await _pause(0.7)
			_press(hud.adv_ok)
		if not city.arrivals.is_empty() and city.free_fit() > 0:
			await _settle(false)
		if cycle % 3 == 0:
			await _request()
		if cycle % 3 == 1:
			await _visit_buildings()
		if cycle % 4 == 1 and city.rp > 0.0:
			await _research(false)
		if cycle < 3 or cycle % 10 == 5:
			await _extend_roads(cycle)
		if cycle % 4 == 2 and city.free_fit() < 2 and city.money > 150.0:
			await _add_near_road("house_pleb")
		cycle += 1
		await _pause(3.0)
	for kind: String in counts:
		log.metric("city.free_" + kind, int(counts[kind]) - int(at_start[kind]))
	log.metric("city.population", fort.city_pop())
	log.metric("city.requests_completed", city.goals_done.size())
	return _check(float(log.phases[2]["game_s"]) >= 1200.0, "Не набрано 20 игровых минут на третьей скорости")


func _request() -> void:
	if _press(_button(hud.tasks_box, "unfold")):
		await _frames(5)
	for goal: Dictionary in city.active_goals(6):
		var request := hud.request_do(goal)
		var kind := String(request.get("kind", ""))
		if kind not in ["build", "hire", "research", "research_any", "road"]:
			continue
		var goal_text := I18n.t(goal["text"])
		for row: Node in hud.tasks_box.get_children():
			if not row is MarginContainer:
				continue
			var matched := false
			for label: Label in row.find_children("*", "Label", true, false):
				matched = matched or label.text == goal_text
			if not matched or not _press(row.get_child(-1) as Button):
				continue
			counts["requests"] += 1
			await _frames(5)
			print("PLAYTEST REQUEST ", goal_text, " · ", kind)
			_press(hud.adv_ok)
			match kind:
				"build": await _add_near_road(String(request["type"]))
				"hire": await _hire_plus()
				"research", "research_any": await _research(false)
				"road": await _extend_roads(0)
			return


func _add_near_road(kind: String) -> bool:
	if not Defs.B.has(kind) or not city.unlocked(kind) or not await _build_tool(kind, false):
		return false
	var built := false
	for offset: Vector2 in [Vector2(9, 13), Vector2(-7, 11), Vector2(8, 22), Vector2(-8, 28),
			Vector2(5, 32), Vector2(15, 28), Vector2(-15, 25)]:
		var at := road_origin + offset
		if not _on_map(_world(at)):
			await _pan_to(at)
		if not (await _place(kind, at, true)).is_empty():
			built = true
			break
	_key(KEY_ESCAPE)
	return built


func _extend_roads(index: int) -> void:
	var across := [12.0, 22.0, 31.0, 38.0]
	var z: float = across[index % across.size()]
	await _pan_to(road_origin + Vector2(0, z - 3))
	if not await _road_tool(false):
		return
	await _paint([road_origin + Vector2(0, maxf(0.0, z - 12.0)), road_origin + Vector2(0, z)])
	await _paint([road_origin + Vector2(-13, z), road_origin + Vector2(14, z)])
	_key(KEY_ESCAPE)


func _visit_buildings() -> void:
	var home := {}
	var workshop := {}
	var can_hire := false
	for building: Dictionary in city.buildings.values():
		if home.is_empty() and city.is_house(building):
			home = building
		if not can_hire and not city.def(building).get("jobs", {}).is_empty():
			can_hire = city.can_hire(building)
			if can_hire or workshop.is_empty():
				workshop = building
		if not home.is_empty() and can_hire:
			break
	for building: Dictionary in [home, workshop]:
		if building.is_empty() or not await _open_building(building):
			continue
		counts["cards"] += 1
		if building == workshop:
			await _hire_plus()
		await _pause(0.45)
		_key(KEY_ESCAPE)


func _open_building(building: Dictionary) -> bool:
	if game.tool != "":
		_key(KEY_ESCAPE)
	var at: Vector2 = building["pos"]
	if not _on_map(_world(at, 3.0)):
		await _pan_to(at)
	for height: float in [2.0, 4.0, 1.0, 6.0]:
		var point := _world(at, height)
		if not _on_map(point):
			continue
		_move(point)
		await _frames()
		if hud.mouse_over_ui() or game.pick_building().get("id") != building["id"]:
			continue
		_click(point)
		await _frames(4)
		if _shown(hud.info_panel) and hud.info_b.get("id") == building["id"]:
			return true
	return false


func _hire_plus() -> void:
	for button: Button in hud.info_panel.find_children("*", "Button", true, false):
		if button.has_meta("hire_class") and _press(button):
			counts["hire"] += 1
			log.progress("нанят работник")
			await _frames(4)
			return


func _fort_route() -> bool:
	for i in 3:
		if game.tool == "":
			break
		_key(KEY_ESCAPE)
	var fallback := not fort.camp_unlocked()
	log.metric("fort.unlock_fallback", fallback)
	if fallback:
		# Тот же флаг, что в test_legion12. Жители, деньги, часы и бои — из этой партии.
		fort.flags["camp_open"] = true
		print("PLAYTEST FALLBACK camp_open, жителей ", fort.city_pop(), "/", Legion.CAMP_POP)
	if not _check(await _open_fort(), "Легион не открылся с городского медальона"):
		return false
	_shot("p3_fort_open")
	await _pause(0.8)
	var tutorial_done := await _fort_tutorial()
	if camp.lu.visible:
		_key(KEY_ESCAPE)
	if not camp.visible:
		await _open_fort()
	if not tutorial_done and fort.fort_guide_step() < Guide.DONE and _press(camp.guide_skip):
		log.issue("Обучение форта прервано через кнопку, чтобы проверить рынок, карточки и бой")
		await _frames(6)
	var market := await _market()
	var cards := await _fort_cards()
	var extra := await _fight(-1, true)
	log.metric("fort.tutorial_completed", tutorial_done)
	log.metric("fort.market_pack", market)
	log.metric("fort.cards_opened", cards)
	log.metric("fort.extra_battle", extra)
	if camp.visible:
		_press(camp.exit_button)
	return tutorial_done and market and cards == 3 and extra


func _open_fort() -> bool:
	if not camp.visible:
		_press(hud.adv_ok)
		if not _press(hud.top_btns.get("legion")):
			return false
	return await _wait("открытие форта", func(): return camp.visible and not camp.opening, 8.0)


func _fort_tutorial() -> bool:
	if not await _fight(0):
		return false
	if not await _outfit("treasury") or not await _outfit("kitchen"):
		return false
	if not await _room_click(0) or not _press(_button(camp.modal_panel, "FortHQConfirm")):
		return _fail("Обучение форта: не удалось улучшить Штаб")
	await _pause(0.55)
	if not _press(camp.build_button):
		return _fail("Обучение форта: кнопка строительства")
	await _frames(6)
	if not _press(camp.build_cards.get("store", {}).get("button") as Button):
		return _fail("Обучение форта: карточка Склада")
	await _frames(6)
	var empty := fort.fort_empty_plot()
	var marker := camp.plot_markers.get(empty, {}).get("button") as Button
	if not _press(marker) and not await _room_click(empty):
		return _fail("Обучение форта: пустое место для Склада")
	if not await _wait("Склад готов", func(): return fort.fort_guide_step() == Guide.TRAIN, 16, true):
		return false
	var newcomers := fort.fort_newcomers()
	if not _check(not newcomers.is_empty(), "Обучение форта: нет ученика у ворот"):
		return false
	var sid := int(newcomers[0]["id"])
	var barracks := int(fort.fort_slot_plot("barracks")["id"])
	if not await _drag_person(sid, true, barracks):
		return _fail("Обучение форта: перенос ученика в Казарму")
	if not await _wait("тренировка в Казарме", func(): return fort.fort_guide_step() == Guide.SQUAD, 20, true):
		return false
	if not await _drag_person(sid, false, 0) or not await _fight(1):
		return false
	await _pause(0.65)
	if not _check(fort.fort_guide_step() == Guide.FINISH and _press(camp.guide_skip), "Обучение форта: завершение после второго боя"):
		return false
	return await _wait("обучение форта завершилось", func(): return fort.fort_guide_step() == Guide.DONE, 8, true)


func _fight(index: int, fast := false) -> bool:
	if not _check(camp.visible and _press(camp.campaign_button), "Бой %d: карта похода недоступна" % index):
		return false
	await _frames(8)
	if not _shown(camp.lu.guide_stage_button) and _shown(camp.lu.guide_region_button) and index >= 0:
		_press(camp.lu.guide_region_button)
		await _frames(6)
	var target := camp.lu.guide_stage_button if index >= 0 else _extra_stage()
	if not _check(_press(target), "Бой %d: этап на карте недоступен" % index):
		return false
	await _frames(7)
	if not _check(_press(camp.lu._fight_btn), "Бой %d: кнопка начала недоступна" % index):
		return false
	var battle := LegionBattle.current
	if not _check(is_instance_valid(battle), "Бой %d не загрузился" % index):
		return false
	log.progress("бой %d начался" % index)
	var stem := "p3_battle_%s" % (str(index + 1) if index >= 0 else "extra")
	_shot(stem + "_start")
	var speed_ok := true
	if fast:
		await _wait("кнопка ×2 в бою", func():
			var button := battle.speed_btns.get(2) as Button
			return _shown(button) and not button.disabled, 10.0)
		speed_ok = _check(_press(battle.speed_btns.get(2)) and battle.speed == 2.0, "В третьем бою не включилась скорость ×2")
		log.metric("fort.extra_battle_speed", battle.speed)
	if not await _wait("результат боя %d" % index, func(): return battle.phase == "result", 58, index >= 0):
		return false
	log.progress("бой %d завершился" % index)
	log.metric("fort.battle_%s_victory" % (str(index + 1) if index >= 0 else "extra"), battle.out.get("win", false))
	_shot(stem + "_result")
	await _pause(0.65)
	var win := bool(battle.out.get("win", false))
	if not _press(_button(battle, "LegionBattleReturn")):
		return _fail("Нет кнопки возврата в форт")
	var returned := await _wait("возврат из боя", func():
		return ((camp.visible and not camp.opening) or (camp.lu.visible and not camp.lu.battle_returning)) \
			and LegionBattle.current == null, 18, index >= 0)
	if camp.lu.visible:
		_key(KEY_ESCAPE)
		returned = await _wait("закрытие карты похода", func(): return camp.visible and not camp.opening and not camp.lu.visible, 8)
	return returned and speed_ok and (index < 0 or _check(win, "Поражение в учебном бою %d" % (index + 1)))


func _extra_stage() -> Button:
	var pins := camp.lu.find_child("FortMapNodes", true, false)
	if pins == null:
		return null
	var frontier := int(fort.frontier()["s"])
	for index: int in [frontier, 1, 0]:
		for button: Button in pins.find_children("*", "Button", false, false):
			if button.get_meta("stage", -1) == index and not button.get_meta("locked", true):
				if fort.can_fight(fort.stage_info(0, 0, index)).is_empty():
					log.metric("fort.extra_stage", index + 1)
					return button
	return null


func _outfit(kind: String) -> bool:
	var newcomers := fort.fort_newcomers()
	var room := int(fort.fort_slot_plot(kind)["id"])
	if not _check(not newcomers.is_empty(), "Нет жителя для " + kind):
		return false
	var sid := int(newcomers[0]["id"])
	if not await _drag_person(sid, true, room):
		return _fail("Не удалось перетащить жителя в " + kind)
	await _frames(8)
	var iid := int(fort.flags.get("fort_guide_item", 0))
	if not await _person_click(sid) or not _press(_button(camp.modal_panel, "FortGear_outfit")):
		return _fail("Не открылась одежда жителя в " + kind)
	await _frames(6)
	if not _press(_button(camp.modal_panel, "FortEquip_%d" % iid)):
		return _fail("Недоступна рабочая одежда в " + kind)
	await _frames(6)
	if int(fort.item(iid).get("on", 0)) != sid:
		_press(_button(camp.modal_panel, "FortItemEquip"))
	await _frames(6)
	if _shown(camp.modal_panel):
		_key(KEY_ESCAPE)
	await _frames(5)
	return _check(_press(camp.plot_markers.get(room, {}).get("collect") as Button), "Не собран запас в " + kind)


func _fort_point(local: Vector2) -> Vector2:
	return camp.diorama.get_global_transform_with_canvas() * local


func _room_click(id: int) -> bool:
	var view := camp.diorama as FortCutaway
	if not is_instance_valid(view):
		return false
	var rect := view.plot_footprint(id).intersection(Rect2(Vector2.ZERO, view.size))
	var points: Array[Vector2] = []
	if rect.has_area():
		for offset: Vector2 in [Vector2(0.21, -0.24), Vector2(-0.23, -0.23), Vector2.ZERO,
				Vector2(0.4, 0.35), Vector2(-0.4, 0.35)]:
			var local := rect.get_center() + rect.size * offset
			if view._pick(local) == "plot_%d" % id and view.pick_person(local).is_empty() and _on_map(_fort_point(local)):
				points.append(local)
	for local: Vector2 in points:
		_click(_fort_point(local))
		await _frames(5)
		if _room_selected(id):
			return true
	if _press(camp.plot_markers.get(id, {}).get("button") as Button):
		await _frames(5)
	# Проигрываем тот же щелчок в GUI разреза, если ввод перехвачен.
	if not _room_selected(id) and not points.is_empty():
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = points[0]
		click.pressed = true
		view._gui_input(click)
		click.pressed = false
		view._gui_input(click)
		await _frames(5)
	return _room_selected(id)


func _room_selected(id: int) -> bool:
	return camp.room_action_id == id or camp.hq_window_id == id or (camp.selected_plot == id and _shown(camp.card))


func _person_click(sid: int) -> bool:
	var view := camp.diorama as FortCutaway
	if not is_instance_valid(view):
		return false
	var rect := view.person_hit_rect(sid, false)
	if not rect.has_area():
		return false
	_click(_fort_point(rect.get_center()))
	await _frames(6)
	if not _shown(camp.modal_panel):
		# Отпускание ловит _input, как в test_legion7c.
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = rect.get_center()
		click.pressed = true
		view._gui_input(click)
		click.pressed = false
		click.position = _fort_point(rect.get_center())
		view._input(click)
		await _frames(4)
	return camp.dweller_sid == sid and _shown(camp.modal_panel)


func _drag_person(sid: int, newcomer: bool, room: int) -> bool:
	var view := camp.diorama as FortCutaway
	if not is_instance_valid(view):
		return false
	var source := _fort_point(view.person_project(sid, newcomer))
	var target := _fort_point(view.project(room))
	if not _on_map(source) or not _on_map(target):
		return false
	_move(source)
	await _frames()
	_mouse_button(source, MOUSE_BUTTON_LEFT, true)
	for i in range(1, 9):
		_move(source.lerp(target, float(i) / 8.0))
		await _frames()
	await _pause(0.3)
	_mouse_button(target, MOUSE_BUTTON_LEFT, false)
	await _frames(7)
	if fort.fort_worker_plot(sid) != room:
		# Повтор жеста через те же обработчики разреза, что использует test_legion12.
		view.begin_person_move(sid, newcomer, view.person_project(sid, newcomer))
		view.update_person_move(view.project(room))
		await _pause(0.4)
		view.finish_person_move(view.project(room))
		await _frames(6)
		log.metric("fort.drag_handler_retries", int(log.metrics.get("fort.drag_handler_retries", 0)) + 1)
	if fort.fort_worker_plot(sid) != room:
		return false
	log.progress("житель назначен в комнату %d" % room)
	return true


func _market() -> bool:
	if not _check(_press(camp.market_button), "Недоступна кнопка Рынок"):
		return false
	await _frames(8)
	_shot("p3_market")
	await _pause(0.6)
	var bought := false
	var before := fort.city_money()
	for resource: String in ["rations", "wood", "iron", "leather"]:
		if _press(_button(camp.modal_panel, "FortMarketTrade_%s_0_0" % resource)):
			await _frames(5)
			bought = fort.city_money() < before
			if bought:
				log.progress("куплена пачка: " + resource)
				_shot("p3_market_purchase")
				break
	var closed := _press(_button(camp.modal_panel, "FortMarketClose"))
	await _frames(4)
	_check(closed and not _shown(camp.modal_panel), "Рынок остался открыт перед проверкой комнат")
	return _check(bought, "На Рынке не куплена пачка")


func _fort_cards() -> int:
	var viewed := 0
	for kind: String in ["hq", "barracks"]:
		var room := int(fort.fort_slot_plot(kind).get("id", -1))
		if not _check(await _room_click(room), "Не выбрана комната форта: " + kind):
			continue
		if not _shown(camp.card):
			var info := _button(camp.room_actions, "FortRoomInfo")
			if not _check(_press(info), "Нет кнопки «Инфо» для комнаты " + kind):
				continue
		if _check(_shown(camp.card) and camp.selected_plot == room, "Карточка комнаты не открылась: " + kind):
			viewed += 1
			log.progress("открыта карточка " + kind)
			_shot("p3_card_" + kind)
			await _pause(0.65)
			_key(KEY_ESCAPE)
			await _frames(4)
		if camp.room_action_id >= 0:
			_key(KEY_ESCAPE)
			await _frames(3)
	var sid := int(fort.hero_dweller().get("id", 0))
	if await _person_click(sid):
		viewed += 1
		_shot("p3_card_dweller")
		await _pause(0.65)
		_key(KEY_ESCAPE)
	_check(viewed == 3, "Не все карточки форта открылись (Штаб, Казарма, житель): %d/3" % viewed)
	return viewed


func _open_settings() -> bool:
	if not _press(hud.top_btns.get("menu")):
		return false
	await _frames(5)
	return _press(_button_text(hud.pause_panel, I18n.t("Настройки")))


func _switch_language(lang: String) -> bool:
	if not _check(await _open_settings(), "Окно настроек недоступно для " + lang):
		return false
	await _frames(8)
	if I18n.lang == "en":
		log.next_scan = 0
		_shot("p4_settings_en")
		await _pause(5.2)
	var previous := game.get_instance_id()
	if not _check(_press(_button(hud.settings_panel, "lang_" + lang)), "Недоступна кнопка языка " + lang):
		return false
	return await _wait("загрузка языка " + lang, func():
		return is_instance_valid(game) and game.get_instance_id() != previous and I18n.lang == lang, 90)


func _save_ui() -> Dictionary:
	if not _press(hud.top_btns.get("menu")):
		return {}
	await _frames(4)
	if not _press(_button_text(hud.pause_panel, I18n.t("Сохранить"))):
		return {}
	var path := profile.path_join("city.json")
	if not FileAccess.file_exists(path):
		return {}
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return saved if saved is Dictionary else {}


func _settings_and_reload() -> bool:
	allow_pause_on_load = true
	_speed(0.0)
	var en := await _switch_language("en")
	var ru := await _switch_language("ru") if en else false
	log.metric("settings.english_and_back", en and ru)
	_press(hud.adv_ok)
	var before := await _save_ui()
	if not _check(not before.is_empty(), "Сохранение из меню не записано"):
		return false
	var previous := game.get_instance_id()
	_press(hud.top_btns.get("menu"))
	await _frames(5)
	if not _check(_press(_button_text(hud.pause_panel, "Главное меню")), "Нет выхода в главное меню"):
		return false
	if not await _wait("главное меню", func(): return is_instance_valid(game) and game.mode == "menu" and game.get_instance_id() != previous, 90):
		return false
	log.progress("главное меню открыто")
	if not _check(_press(_button_text(hud.menu_root, "Играть")), "Нет кнопки Играть для загрузки города"):
		return false
	if not await _wait("загрузка сохранённого города", func(): return is_instance_valid(game) and game.mode == "play", 90):
		return false
	log.progress("город загружен")
	_shot("p4_city_reloaded")
	await _pause(0.6)
	_press(hud.adv_ok)
	var after := await _save_ui()
	if not _check(not after.is_empty(), "После загрузки не записано контрольное сохранение"):
		return false
	var diffs: Array[String] = []
	_diff_keys(before, after, CITY_KEYS, "city", diffs)
	_diff_keys(before.get("tips", {}), after.get("tips", {}), ["tut", "tut_id", "ui"], "city.tips", diffs)
	_diff_keys(before.get("legion", {}), after.get("legion", {}), FORT_KEYS, "fort", diffs)
	var before_flags: Dictionary = before.get("legion", {}).get("flags", {})
	var after_flags: Dictionary = after.get("legion", {}).get("flags", {})
	_diff_keys(before_flags, after_flags, ["camp_open", "fort_guide", "fort_lessons", "battle_speed"], "fort.flags", diffs)
	log.metric("save.diff_count", diffs.size())
	log.metric("save.identical_essentials", diffs.is_empty())
	log.evidence["save_diff"] = diffs
	log.evidence["save_keys"] = {"city": CITY_KEYS, "fort": FORT_KEYS}
	if await _open_fort():
		_shot("p4_fort_reloaded")
		await _pause(0.7)
		_press(camp.exit_button)
	else:
		_fail("Форт после загрузки не открылся")
	return _check(diffs.is_empty(), "Основные данные различаются после загрузки: %s" % str(diffs.slice(0, 5))) and en and ru


func _diff_keys(before: Dictionary, after: Dictionary, keys: Array, path: String, diffs: Array[String]) -> void:
	for key: String in keys:
		_diff(before.get(key), after.get(key), path + "." + key, diffs)


func _diff(before: Variant, after: Variant, path: String, diffs: Array[String]) -> void:
	if typeof(before) != typeof(after):
		diffs.append("%s: типы %s → %s" % [path, type_string(typeof(before)), type_string(typeof(after))])
	elif before is Dictionary:
		var keys: Array = before.keys()
		for key: Variant in after:
			if not before.has(key):
				keys.append(key)
		for key: Variant in keys:
			_diff(before.get(key), after.get(key), path + "." + str(key), diffs)
	elif before is Array:
		if before.size() != after.size():
			diffs.append("%s: записей %d → %d" % [path, before.size(), after.size()])
		for i in mini(before.size(), after.size()):
			_diff(before[i], after[i], "%s[%d]" % [path, i], diffs)
	elif before is float and is_equal_approx(before, after):
		return
	elif before != after:
		diffs.append("%s: %s → %s" % [path, str(before).left(100), str(after).left(100)])
