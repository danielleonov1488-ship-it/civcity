extends Node3D
## Тур новой игры. Запускает проверяющий; Godot при подготовке теста не запускать.

const OUT := "D:/CivCity/.work/stage5/tour5/shots/"
const PROFILE_ROOT := "D:/CivCity/.work/stage5/tour5/"
const MAX_HOURS := 144 # Один час игры при 1×, как в test_pace.
const STREETS := [
	[Vector2(192, 128), Vector2(192, 178)],
	[Vector2(172, 136), Vector2(214, 136)],
	[Vector2(172, 150), Vector2(214, 150)],
	[Vector2(172, 164), Vector2(214, 164)],
	[Vector2(172, 178), Vector2(214, 178)],
]

var game: Node
var city: Object
var hud: Node
var camp: Node
var warns: int = 0
var skips: int = 0
var fails: int = 0
var hours: int = 0
var roads_drawn: Dictionary = {}
var points: Array[Vector2] = []
var homes: Array[Dictionary] = []
var shops: Array[Dictionary] = []
var definitions: Dictionary = {}
var researches: Array = []
var warned: Dictionary = {}
var profile: String = ""
var current_shot: String = "boot"
var saved_environment: Dictionary = {}
var fort_city_state: Dictionary = {}


func _ready() -> void:
	# savedir в командной строке имеет приоритет над окружением: чужой профиль не трогаем.
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--savedir=") or arg.trim_prefix("--").get_slice("=", 0) == "sandbox":
			_fail("Запустите тур без --savedir и --sandbox: профиль выбирает сам тест")
			_finish()
			return
	profile = PROFILE_ROOT + "profile_%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	if DirAccess.make_dir_recursive_absolute(profile) != OK or DirAccess.make_dir_recursive_absolute(OUT) != OK:
		_fail("Не удалось создать папки тура")
		_finish()
		return
	_env("CIVCITY_SAVEDIR", profile)
	_env("CIVCITY_NOLOGIN", "1")
	_env("CIVCITY_NOMINPAUSE", "1")
	_env("CIVCITY_HEROSCREEN", "0")
	if GamePaths.save_dir().simplify_path() != profile.simplify_path():
		_fail("GamePaths уже выбрал другой профиль; загрузка отменена")
		_finish()
		return
	print("TOUR PROFILE ", profile)
	Game.sandbox = false
	Game.boot = {"new": "1", "nologin": "1"}
	var scene: PackedScene = load("res://main.tscn") as PackedScene
	if scene == null:
		_fail("Нет main.tscn")
		_finish()
		return
	game = scene.instantiate()
	_write(game, "can_save", false)
	add_child(game)
	# _ready игры выставляет can_save заново перед первым await.
	_write(game, "can_save", false)
	_run()


func _process(_dt: float) -> void:
	_write(game, "can_save", false)


func _env(key: String, value: String) -> void:
	saved_environment[key] = {"had": OS.has_environment(key), "value": OS.get_environment(key)}
	OS.set_environment(key, value)


func _read(obj: Variant, key: String, fallback: Variant = null) -> Variant:
	if obj is Dictionary:
		return obj.get(key, fallback)
	if not obj is Object or not is_instance_valid(obj):
		return fallback
	for property: Dictionary in obj.get_property_list():
		if String(property.get("name", "")) == key:
			var value: Variant = obj.get(key)
			return fallback if value == null else value
	return fallback


func _write(obj: Variant, key: String, value: Variant) -> bool:
	if not obj is Object or not is_instance_valid(obj):
		return false
	for property: Dictionary in obj.get_property_list():
		if String(property.get("name", "")) == key:
			obj.set(key, value)
			return true
	return false


func _has(obj: Variant, method: String) -> bool:
	return obj is Object and is_instance_valid(obj) and obj.has_method(method)


func _call(obj: Variant, method: String, args: Array = [], fallback: Variant = null) -> Variant:
	if not _has(obj, method):
		return fallback
	return obj.callv(method, args)


func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


func _array(value: Variant) -> Array:
	return value if value is Array else []


func _visible(node: Variant) -> bool:
	return node is CanvasItem and is_instance_valid(node) and node.is_visible_in_tree()


func _node(root: Node, node_name: String) -> Node:
	return root.find_child(node_name, true, false) if is_instance_valid(root) else null


func _script_node(root: Node, file: String) -> Node:
	if not is_instance_valid(root):
		return null
	var script: Script = root.get_script() as Script
	if script != null and script.resource_path.get_file() == file:
		return root
	for child: Node in root.get_children():
		var found: Node = _script_node(child, file)
		if found != null:
			return found
	return null


func _frames(count: int = 8) -> void:
	for i: int in count:
		await get_tree().process_frame


func _seconds(seconds: float) -> void:
	var end: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame


func _skip(reason: String) -> void:
	skips += 1
	print("TOUR SKIP ", reason)


func _fail(reason: String) -> void:
	fails += 1
	print("TOUR FAIL ", reason)


func _warn(key: String, reason: String) -> void:
	if warned.has(key):
		return
	warned[key] = true
	warns += 1
	print("TOUR WARN ", current_shot, " ", reason)


func _run() -> void:
	var deadline: int = Time.get_ticks_msec() + 240000
	while not bool(_read(game, "ready_done", false)):
		if Time.get_ticks_msec() >= deadline:
			_fail("ready_done timeout")
			_finish()
			return
		await _frames(1)
	city = _read(game, "city") as Object
	hud = _read(game, "hud") as Node
	if city == null or hud == null:
		_fail("После ready_done отсутствует город или HUD")
		_finish()
		return
	_write(game, "can_save", false)
	_write(game, "speed", 0.0)
	var settings: Dictionary = _dict(_read(game, "settings"))
	settings["autosave"] = false
	var defs: Script = load("res://scripts/defs.gd") as Script
	if defs == null:
		_fail("Нет определений построек")
		_finish()
		return
	var constants: Dictionary = defs.get_script_constant_map()
	definitions = _dict(constants.get("B"))
	researches = _array(constants.get("RESEARCH"))
	await _seconds(0.6)
	var tutorial: Node = _read(game, "tutorial") as Node
	if not _visible(_read(tutorial, "card")) and not _visible(_read(hud, "advisor_panel")):
		_warn("intro", "На первом экране не видно обучения или советника")
	await _shot("01_first_screen.png")
	# Публичное завершение обучения сохраняет настройки только в изолированный профиль.
	if _has(tutorial, "finish"):
		_call(tutorial, "finish")
	else:
		_skip("Нет завершения обучения; последующие окна могут быть перекрыты")
	_write(game, "build_anim", false)
	_call(city, "set_arrivals_paused", [true])
	_close_city()
	_road(STREETS[0][0], Vector2(192, 150))
	_road(STREETS[1][0], STREETS[1][1])
	for target: Vector2 in [Vector2(186, 132), Vector2(199, 132)]:
		var house: Dictionary = _place("house_pleb", target)
		if not house.is_empty():
			homes.append(house)
	var shop: Dictionary = _place("stall_fruit", Vector2(187, 140))
	if not shop.is_empty():
		shops.append(shop)
	_city_view(Vector2(192, 137), 45.0)
	if homes.size() != 2 or shop.is_empty():
		_warn("first_build", "Не удалось поставить ровно два первых дома и лавку")
	await _frames(12)
	_check_house_badges()
	await _shot("02_first_street.png")
	var family: Dictionary = _waiting_family()
	if not family.is_empty():
		var center: Dictionary = _dict(_call(city, "center"))
		_city_view(center.get("pos", Vector2(192, 124)), 35.0)
		await _seconds(0.4) # Значки семей обновляются четыре раза в секунду.
		_check_family_badge(String(family.get("name", "")))
		await _shot("03_station_family.png")
		if _has(game, "start_settle") and not homes.is_empty():
			_call(game, "start_settle", [String(family.get("name", ""))])
			_city_view(Vector2(192, 134), 43.0)
			await _frames(12)
			_check_settle_badges()
			await _shot("04_settle_mode.png")
			await _walk_home(family, homes[0])
		else:
			_skip("04: нет режима заселения или подходящего дома")
	else:
		_skip("03: нет ожидающей семьи")
		_skip("04: нет семьи для выбора жилья")
	_close_city()
	var settled_home: Dictionary = _first_settled()
	if not settled_home.is_empty() and _has(hud, "open_info"):
		_call(game, "select_building", [settled_home])
		_call(hud, "open_info", [settled_home])
		_city_view(settled_home.get("pos", Vector2(192, 136)), 28.0)
		await _shot("05_house_card.png")
	else:
		_skip("05: нет заселённого дома или карточки дома")
	_close_city()
	if not shop.is_empty() and _has(hud, "open_info"):
		_call(game, "select_building", [shop])
		_call(hud, "open_info", [shop])
		await _frames()
		var plus: Button = _node(hud, "hire_plus") as Button
		if plus == null or not _visible(plus):
			_skip("06: строка ручного найма ещё не подключена")
		await _shot("06_shop_hiring.png")
		_hire(shop)
	else:
		_skip("06: нет лавки или карточки")
	_close_city()
	await _research_window()
	_close_city()
	await _hamlet()
	await _magistracy()
	_close_city()
	await _grow(52)
	# Свет готов до открытия форта: кадры 10–14 относятся к одному состоянию города.
	if _place("lamp_post", Vector2(188, 146)).is_empty():
		_warn("night_lamp", "Не удалось поставить фонарь для ночного кадра")
	await _fort()
	await _night()
	_finish()


func _close_city() -> void:
	# close_panels закрывает один верхний слой за вызов.
	for i: int in 8:
		if not bool(_call(hud, "close_panels", [], false)):
			break
	_call(game, "set_tool", [""])
	_call(game, "select_building", [{}])
	var advisor: Control = _read(hud, "advisor_panel") as Control
	if is_instance_valid(advisor):
		advisor.hide()


func _city_view(at: Vector2, distance: float) -> void:
	var rig: Object = _read(game, "rig") as Object
	_call(rig, "set_view", [Vector3(at.x, 2.0, at.y), 15.0, 48.0, distance])


func _budget(cost: float) -> void:
	var money: float = float(_read(city, "money", 0.0))
	if money < cost:
		_write(city, "money", cost + 100.0)
		print("TOUR NOTE test money +", ceili(cost + 100.0 - money))


func _road(a: Vector2, b: Vector2) -> void:
	var key: String = str(a) + ":" + str(b)
	if roads_drawn.has(key):
		return
	var land: Object = _read(game, "land") as Object
	if not _has(land, "paint_line"):
		_skip("Нет кисти дорог")
		return
	_budget(a.distance_to(b) * 12.0)
	var cells: Array = _array(_call(land, "paint_line", [a, b, 1.3, Land.Kind.ROAD, true]))
	roads_drawn[key] = true
	_write(city, "road_cells", int(_read(city, "road_cells", 0)) + cells.size())
	_write(city, "money", float(_read(city, "money", 0.0)) - cells.size() * float(Defs.ROAD_COST.get("road", 0)))
	var direction: Vector2 = (b - a).normalized()
	var side: Vector2 = Vector2(-direction.y, direction.x)
	for i: int in int(a.distance_to(b)) + 1:
		for offset: float in [-4.5, -3.2, 3.2, 4.5]:
			points.append(a + direction * i + side * offset)
	var chunks: Dictionary = _dict(_read(land, "road_chunks"))
	_call(_read(game, "people"), "refresh", [chunks.keys()])
	_call(city, "compute")


func _place(type: String, target: Vector2) -> Dictionary:
	if not definitions.has(type) or not _has(game, "placement") or not _has(city, "place"):
		_skip("Нет постройки/API: " + type)
		return {}
	_budget(float(_dict(definitions[type]).get("cost", 0)))
	var candidates: Array[Vector2] = points.duplicate()
	# Украшения можно ставить и между домами.
	if _dict(definitions[type]).get("kind", "") == "decor":
		for x: int in range(-5, 6):
			for y: int in range(-5, 6):
				candidates.append(target + Vector2(x, y))
	candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.distance_squared_to(target) < b.distance_squared_to(target))
	var tried: int = 0
	for at: Vector2 in candidates:
		tried += 1
		if tried > 650:
			break
		# Сброс привязки между пробами — тот же приём, что в test_pace.
		_write(game, "last_snap_n", Vector2.ZERO)
		_write(game, "last_snap_p", Vector2.INF)
		_write(game, "manual_yaw", false)
		_write(game, "yaw_set", false)
		_write(game, "place_lock", {})
		_write(game, "tool_yaw", 0.0)
		_write(game, "snap", true)
		var pl: Dictionary = _dict(_call(game, "placement", [type, at]))
		if pl.is_empty() or String(pl.get("err", "?")) != "":
			continue
		if _dict(definitions[type]).get("kind", "") != "decor" and pl.get("sub", "") != "road":
			continue
		if not pl.get("pos") is Vector2:
			continue
		return _dict(_call(city, "place", [type, pl["pos"], float(pl.get("yaw", 0.0)), int(pl.get("variant", 0)), int(pl.get("color", -1))]))
	_warn("place:" + type + str(target), "Нет места у дороги для " + type + " рядом с " + str(target))
	return {}


func _waiting_family() -> Dictionary:
	if not _has(city, "new_family") or not _has(city, "family_arrived") or not city.has_signal("resident_returned"):
		return {}
	var family: Dictionary = _dict(_call(city, "new_family", ["plebs"]))
	if family.is_empty():
		return {}
	family["want"] = "quiet" # Среди двух домов точно есть совпадение желания.
	_call(city, "family_arrived", [family, false])
	# Публичный сигнал создаёт ожидающих людей, как в тестах CITY5a.
	var arrival: Dictionary = _dict(_call(city, "arrival", [String(family.get("name", ""))]))
	if arrival.is_empty():
		return {}
	city.emit_signal("resident_returned", arrival)
	return arrival


func _check_family_badge(family_name: String) -> void:
	var badges: Dictionary = _dict(_read(hud, "badges"))
	var badge: Dictionary = _dict(badges.get("fam_" + family_name))
	if not _visible(badge.get("n")):
		_warn("family_badge", "У ожидающей семьи нет видимого значка")
	elif _read(badge.get("n"), "preference_texture") == null:
		_skip("03: значок желания семьи ещё не подключён")


func _check_house_badges() -> void:
	var badges: Dictionary = _dict(_read(hud, "badges"))
	var count: int = 0
	for entry: Variant in badges.values():
		var badge: Dictionary = _dict(entry)
		if not _visible(badge.get("n")) or not badge.get("pos") is Vector3:
			continue
		var at: Vector3 = badge["pos"]
		for home: Dictionary in homes:
			var position_2d: Vector2 = home.get("pos", Vector2.INF)
			if Vector2(at.x, at.z).distance_to(position_2d) < 3.0:
				count += 1
				break
	if count == 0:
		_skip("02: у первых домов пока нет видимых значков")


func _check_settle_badges() -> void:
	var badges: Dictionary = _dict(_read(hud, "badges"))
	var room: bool = false
	var matched: bool = false
	var visible_count: int = 0
	for key: Variant in badges:
		var entry: Dictionary = _dict(badges[key])
		var icon: String = String(entry.get("icon", ""))
		if not _visible(entry.get("n")):
			continue
		if not String(key).begins_with("settle") and icon not in ["home_room", "match", "keys"]:
			continue
		visible_count += 1
		room = room or icon == "home_room"
		matched = matched or bool(_read(entry.get("n"), "matches", false)) or bool(_read(entry.get("n"), "match", false)) or icon == "match"
	if visible_count == 0:
		_warn("settle_badges", "В режиме заселения нет видимых значков домов")
	if not room:
		_skip("04: home_room ещё отсутствует; сняты доступные значки жилья")
	if not matched:
		_warn("settle_match", "Нет отметки match при подходящем желании семьи")


func _walk_home(family: Dictionary, home: Dictionary) -> void:
	if not bool(_call(city, "assign", [String(family.get("name", "")), int(home.get("id", -1))], false)):
		_warn("assign", "Первая семья не получила дом")
		return
	_call(game, "set_tool", [""])
	_write(game, "speed", 6.0)
	var deadline: int = Time.get_ticks_msec() + 20000
	while int(home.get("pop", 0)) == 0 and Time.get_ticks_msec() < deadline:
		await _frames(1)
	_write(game, "speed", 0.0)
	if int(home.get("pop", 0)) == 0:
		_warn("walk", "Семья не дошла до дома за 20 секунд")


func _first_settled() -> Dictionary:
	for home: Dictionary in homes:
		if int(home.get("pop", 0)) > 0:
			return home
	return {}


func _hire(building: Dictionary) -> void:
	if building.is_empty():
		return
	var count: int = int(_call(city, "job_max", [building], 1))
	_call(city, "hire", [building, count])


func _research_window() -> void:
	var panel: Control = _read(hud, "research_panel") as Control
	var tree: Node = _read(hud, "research_tree") as Node
	if panel == null or tree == null:
		_skip("07: нет окна исследований")
		return
	panel.show()
	_call(tree, "refresh")
	_call(tree, "rebuild")
	_call(tree, "fit_window")
	await _shot("07_research.png")
	panel.hide()


func _advance() -> bool:
	if hours >= MAX_HOURS or not _has(city, "sim_day"):
		return false
	# sim_day — один игровой час, как в боте test_pace; clock_h считает сама модель.
	_call(city, "sim_day")
	hours += 1
	return true


func _grow(target_population: int) -> void:
	for street: Array in STREETS.slice(2):
		_road(street[0], street[1])
	_road(Vector2(192, 150), Vector2(192, 178))
	var attempts: int = 0
	while int(_dict(_read(city, "stats")).get("pop", 0)) < target_population and attempts < 22:
		attempts += 1
		var home: Dictionary = {}
		for candidate: Dictionary in homes:
			if int(candidate.get("pop", 0)) == 0 and int(candidate.get("coming", 0)) == 0:
				home = candidate
				break
		if home.is_empty():
			home = _place("house_pleb", Vector2(178 + (attempts % 6) * 6, 141 + (attempts / 6) * 13))
			if home.is_empty():
				break
			homes.append(home)
		var family: Dictionary = _dict(_call(city, "new_family", ["plebs"]))
		if family.is_empty() or not _has(city, "settled") or not city.has_signal("resident_returned"):
			_skip("Нет API ускоренного заселения")
			break
		family["n"] = 4
		family["want"] = "market"
		family.erase("m") # Имена членов семьи создаст обычный обработчик People.
		_call(city, "family_arrived", [family, false])
		if not bool(_call(city, "assign", [String(family.get("name", "")), int(home.get("id", -1))], false)):
			_warn("grow_assign", "Не удалось назначить семью в новый дом")
			break
		var took: int = int(_call(city, "settled", [int(home.get("id", -1)), 4, String(family.get("name", ""))], 0))
		if took <= 0:
			break
		family["home"] = int(home.get("id", -1))
		# Берём запись из дома: экономика и люди должны разделять одни и те же m.
		var residents: Array = _array(home.get("families"))
		var resident_family: Dictionary = _dict(residents.back()) if not residents.is_empty() else family
		var visual_family: Dictionary = resident_family.duplicate()
		visual_family["home"] = int(home.get("id", -1))
		visual_family["cls"] = "plebs"
		city.emit_signal("resident_returned", visual_family)
		if homes.size() % 3 == 0:
			var food: Dictionary = _place("stall_fruit", home.get("pos", Vector2(192, 145)))
			if not food.is_empty():
				shops.append(food)
		for food: Dictionary in shops:
			_hire(food)
		_call(city, "compute")
		await _frames(1)
	_call(city, "compute")
	print("TOUR NOTE growth pop=", _dict(_read(city, "stats")).get("pop", 0), " target=", target_population)


func _hamlet() -> void:
	await _grow(20)
	var school: Dictionary = _place("scriptorium", Vector2(204, 140))
	_hire(school)
	for i: int in MAX_HOURS:
		# Исследуем через обычную покупку; очки зарабатывает скрипторий.
		for item: Variant in researches:
			var research: Dictionary = _dict(item)
			var id: String = String(research.get("id", ""))
			if id != "" and int(research.get("lvl", -1)) == 0 and String(_call(city, "can_research", [id], "absent")) == "":
				_call(city, "do_research", [id])
		if bool(_call(city, "rank_ok", [], false)):
			break
		if not _advance():
			break
		await _frames(1)
	_close_city()
	_city_view(Vector2(192, 142), 50.0)
	if not bool(_call(city, "rank_ok", [], false)):
		_warn("rank", "Хутор не достигнут за первый час: " + str(_call(city, "rank_needs", [], [])))
		_skip("08: условия Хутора не выполнены; принудительного ранга нет")
		return
	var cine: Node = _read(game, "rank_cine") as Node
	_write(cine, "force", true) # Штатный переключатель роликов во вложенных тестах.
	_write(game, "speed", 0.05)
	if _has(hud, "press_rank"):
		_call(hud, "press_rank")
	else:
		_call(city, "rank_up")
	var moment: bool = false
	var deadline: int = Time.get_ticks_msec() + 25000
	while cine != null and Time.get_ticks_msec() < deadline:
		var state: Dictionary = _dict(_read(cine, "cine"))
		if String(state.get("phase", "")) == "orbit" and float(state.get("pt", 0.0)) >= 3.0:
			moment = true
			await _shot("08_rank_up.png")
			break
		await _frames(1)
	if not moment:
		_skip("08: ролик ранга недоступен; снят результат повышения")
		await _shot("08_rank_up.png")
	deadline = Time.get_ticks_msec() + 25000
	while cine != null and not _dict(_read(cine, "cine")).is_empty() and Time.get_ticks_msec() < deadline:
		await _frames(1)
	_write(game, "speed", 0.0)
	if cine != null and not _dict(_read(cine, "cine")).is_empty():
		_warn("rank_timeout", "Ролик ранга не завершился за 25 секунд")
	await _seconds(0.6)
	await _shot("08b_hamlet_advisor.png")


func _magistracy() -> void:
	var magistracy: Node = _read(hud, "magis_ui") as Node
	if magistracy == null:
		magistracy = _script_node(hud, "magis_ui.gd")
	if magistracy == null:
		magistracy = _node(hud, "MagisUI")
	if magistracy == null:
		_skip("09: магистратуры ещё не подключены")
		return
	_close_city()
	if _has(magistracy, "open"):
		_call(magistracy, "open")
	elif _has(magistracy, "toggle"):
		_call(magistracy, "toggle")
	else:
		_skip("09: нет публичного открытия магистратур")
		return
	await _frames()
	if _visible(magistracy) or _visible(_read(magistracy, "panel")):
		await _shot("09_magistracy.png")
	else:
		_skip("09: окно магистратур пока закрыто условиями города")
	_call(magistracy, "close")


func _fort() -> void:
	var pop: int = int(_dict(_read(city, "stats")).get("pop", 0))
	var legion: Object = _read(city, "legion") as Object
	camp = _node(hud, "CampUI")
	if camp == null:
		camp = _script_node(hud, "camp_ui.gd")
	if pop < 50 or not _has(camp, "open") or not bool(_call(legion, "window_open", [], false)):
		for step: int in range(10, 14):
			_skip("%02d: форт недоступен, pop=%d" % [step, pop])
		return
	_call(legion, "army_tick")
	_call(camp, "open")
	await _frames(20)
	if not _visible(camp):
		for step: int in range(10, 14):
			_skip("%02d: окно форта не открылось" % step)
		return
	fort_city_state = _city_state()
	await _shot("10_fort.png")
	# Только очередь форта, без хода города: ночной кадр будет при том же состоянии.
	var interval: float = float(_call(legion, "fort_arrival_interval", [], 8.0))
	_call(legion, "fort_arrival_hour", [interval + 0.1])
	_call(camp, "close")
	_call(camp, "open")
	var newcomers: Array = _array(_call(legion, "fort_newcomers", [], []))
	if not newcomers.is_empty() and _has(camp, "show_newcomer"):
		_call(camp, "show_newcomer", [int(_dict(newcomers[0]).get("id", -1))])
		await _frames()
		if _visible(_read(camp, "modal_panel")) or _visible(_node(camp, "FortNewcomerCard")):
			await _shot("11_gate_newcomer_card.png")
		else:
			_skip("11: карточка новичка не открылась")
	else:
		_skip("11: нет новичка у ворот или его карточки")
	_call(camp, "close")
	_call(camp, "open")
	var room: Dictionary = {}
	for type: String in ["kitchen", "barracks", "hq"]:
		room = _dict(_call(legion, "fort_slot_plot", [type]))
		if not room.is_empty() and int(room.get("lv", 0)) > 0:
			break
	if not room.is_empty() and int(room.get("lv", 0)) > 0 and _has(camp, "show_plot"):
		_call(camp, "show_plot", [int(room.get("id", -1))])
		await _frames()
		if _visible(_read(camp, "card")) or _visible(_node(camp, "FortBuildingCard")):
			await _shot("12_fort_room_card.png")
		else:
			_skip("12: карточка комнаты не открылась")
	else:
		_skip("12: нет построенной комнаты или карточки")
	_call(camp, "close")
	_call(camp, "open")
	if _has(camp, "show_build_menu"):
		_call(camp, "show_build_menu")
		await _frames()
		if _visible(_read(camp, "modal_panel")) or _visible(_node(camp, "FortBuildMenu")):
			await _shot("13_fort_build_menu.png")
		else:
			_skip("13: меню строительства форта не открылось")
	else:
		_skip("13: нет меню строительства форта")
	_call(camp, "close")


func _night() -> void:
	_close_city()
	_city_view(Vector2(192, 148), 65.0)
	var clock: int = int(_read(city, "clock_h", -1))
	var pop: int = int(_dict(_read(city, "stats")).get("pop", 0))
	_write(game, "look_hour", -1.0)
	# Два кадра обычных часов применяют свет без обращения к приватным методам игры.
	# Начинаем ровно в 22:00: границу часа не пересекаем, sim_day не вызывается.
	if _write(game, "hour", 22.0) and _write(game, "clock_hours", true):
		_write(game, "speed", 0.01)
		await _frames(2)
		_write(game, "speed", 0.0)
		_write(game, "clock_hours", false)
		await _seconds(0.6)
		await _shot("14_city_night.png")
	else:
		_skip("14: нет доступных часов для ночного освещения")
	if clock != int(_read(city, "clock_h", -1)) or pop != int(_dict(_read(city, "stats")).get("pop", 0)):
		_warn("night_time", "При ночном снимке изменилось время симуляции или население")
	if not fort_city_state.is_empty() and fort_city_state != _city_state():
		_warn("fort_city_state", "Между фортом и ночным кадром изменился город: " + str(fort_city_state) + " -> " + str(_city_state()))


func _city_state() -> Dictionary:
	var stats: Dictionary = _dict(_read(city, "stats"))
	return {"clock": _read(city, "clock_h", -1), "pop": stats.get("pop", 0),
		"happy": stats.get("happy", 0), "money": _read(city, "money", 0), "rank": _read(city, "level", 0)}


func _shot(file: String) -> void:
	current_shot = file
	await _frames(12)
	if DisplayServer.get_name() == "headless":
		_skip(file + ": headless не даёт снимка экрана")
		return
	await RenderingServer.frame_post_draw
	_audit(game, get_viewport().get_visible_rect())
	_audit_badges()
	var texture: ViewportTexture = get_viewport().get_texture()
	var picture: Image = texture.get_image() if texture != null else null
	if picture == null or picture.is_empty():
		_fail("Пустой кадр " + file)
		return
	var error: Error = picture.save_png(OUT + file)
	if error != OK:
		_fail("Сохранение " + file + ": " + error_string(error))
		return
	var stats: Dictionary = _dict(_read(city, "stats"))
	var rank: Dictionary = _dict(_call(city, "lv", [int(_read(city, "level", 0))]))
	print("TOUR SHOT ", OUT + file, " pop=", stats.get("pop", 0), " happy=", stats.get("happy", 0),
		" money=", int(_read(city, "money", 0)), " rank=", rank.get("name", _read(city, "level", 0)))


func _audit(node: Node, clip: Rect2) -> void:
	if node is Window and node.visible:
		var window_size: Vector2 = Vector2(node.size)
		if window_size.x > clip.size.x + 2.0 or window_size.y > clip.size.y + 2.0:
			_warn("window:" + str(node.get_path()), "Окно больше viewport: " + str(node.get_path()))
	if node is Control:
		var control: Control = node as Control
		if not control.is_visible_in_tree() or control.modulate.a < 0.01 or control.self_modulate.a < 0.01:
			return
		var rect: Rect2 = control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)
		if not rect.intersects(clip):
			return
		var path: String = str(control.get_path())
		if control is Label:
			_audit_label(control as Label, path)
		if control is PanelContainer:
			var viewport_size: Vector2 = get_viewport().get_visible_rect().size
			if rect.size.x > viewport_size.x + 2.0 or rect.size.y > viewport_size.y + 2.0:
				_warn("panel_size:" + path, "Панель больше viewport: " + path + " size=" + str(rect.size))
			if not _has_content(control):
				_warn("empty:" + path, "Пустой видимый PanelContainer: " + path)
		if control.clip_contents:
			clip = clip.intersection(rect)
	for child: Node in node.get_children():
		_audit(child, clip)


func _audit_label(label: Label, path: String) -> void:
	if label.text.strip_edges() == "" or label.size.x <= 0.0 or label.size.y <= 0.0:
		return
	var font: Font = label.get_theme_font("font")
	if font == null:
		return
	var font_size: int = label.get_theme_font_size("font_size")
	var lines: int = label.get_line_count()
	var height: float = font.get_height(font_size) * lines + label.get_theme_constant("line_spacing") * maxi(0, lines - 1)
	var width: float = 0.0
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		var text: String = label.text.to_upper() if label.uppercase else label.text
		for line: String in text.split("\n"):
			width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x)
	if width > label.size.x + 3.0 or height > label.size.y + 3.0:
		_warn("label:" + path + label.text, "Текст выходит за Label: " + path + " rect=" + str(label.size)
			+ " text=" + label.text.replace("\n", " / ").left(120))


func _has_content(node: Node) -> bool:
	for child: Node in node.get_children():
		if child is CanvasItem and not child.is_visible_in_tree():
			continue
		if child is Label and child.text.strip_edges() != "":
			return true
		if child is RichTextLabel and child.text.strip_edges() != "":
			return true
		if child is Button and (child.text != "" or child.icon != null):
			return true
		if child is TextureRect and child.texture != null:
			return true
		if child is Control and not child is Container and child.get_script() != null:
			return true # Значки и сцена форта рисуются своим скриптом.
		if _has_content(child):
			return true
	return false


func _audit_badges() -> void:
	if String(_read(game, "tool", "")) == "floor":
		return
	var badges: Dictionary = _dict(_read(hud, "badges"))
	for key: Variant in badges:
		var badge: Dictionary = _dict(badges[key])
		var node: Control = badge.get("n") as Control
		if not _visible(node):
			continue
		var icon: String = String(badge.get("icon", ""))
		# Цены участков — отдельный инструмент; здесь проверяем значки над домами и семьями.
		if icon not in ["family", "house_problem", "road", "no_workers", "keys", "home_room", "match", "up"] and not icon.begins_with("upc"):
			continue
		var text: String = String(badge.get("text", ""))
		var label: Label = _read(node, "label") as Label
		if label != null and _visible(label):
			text += label.text
		if text.strip_edges() != "":
			_warn("badge:" + str(key), "Текст у значка вне инструмента «Этаж»: " + str(key) + " " + text.left(100))


func _finish() -> void:
	_write(game, "can_save", false)
	if is_instance_valid(camp):
		_call(camp, "close")
	for key: String in saved_environment:
		var previous: Dictionary = saved_environment[key]
		if bool(previous.get("had", false)):
			OS.set_environment(key, String(previous.get("value", "")))
		else:
			OS.unset_environment(key)
	print("TOUR NOTE simulated_hours=", hours, " fails=", fails)
	print("TOUR5 DONE warns=%d skips=%d" % [warns, skips])
	get_tree().quit(1 if fails > 0 else 0)
