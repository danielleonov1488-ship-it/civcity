class_name Tutorial
extends Node
## Один шаг и одна стрелка. Старые номера читаем один раз, дальше сохраняем id.

var game
var hud
var step := -1
var card: PanelContainer
var title: Label
var text: Label
var icon_box: Control
var dots: HBoxContainer
var camera_keys: TextureRect
var next_btn: Button
var show_btn: Button
var _move0 := 0.0
var _zoom0 := 0
var _card_fade: Tween
var _script_built := false
var _research_hint: Control
var hint: Label
var _rp0 := 0
var _opening := false

const MapBadge = preload("res://scripts/map_badge.gd")
const OLD_IDS := ["move", "turn", "road", "houses", "cart", "settle", "house", "food", "workers", "script", "research", "done"]
const STEPS := [
	{"id": "move", "title": "Осмотримся", "icon": "move", "text": "Подвигайте камеру и смените масштаб."},
	{"id": "houses", "title": "Три дома", "icon": "housing", "text": "Поставьте три дома. Дорогу добавим потом."},
	{"id": "road", "title": "Первая улица", "icon": "road", "text": "Соедините дома дорогой с площадью."},
	{"id": "cart", "title": "Едут!", "icon": "horse", "text": "Дождитесь семей у станции."},
	{"id": "settle", "title": "Новоселье", "icon": "family", "text": "Выберите семью, затем светящийся дом."},
	{"id": "house", "title": "Как им живётся?", "icon": "info", "text": "Откройте дом семьи."},
	{"id": "house_info", "title": "Как им живётся?", "icon": "info", "next": true, "text": "Посмотрите на значки в карточке дома."},
	{"id": "food", "title": "Еда", "icon": "food", "text": "Поставьте фруктовую лавку у домов."},
	{"id": "workers", "title": "Работники", "icon": "hammer", "text": "Нажмите «+» в карточке лавки."},
	{"id": "script", "title": "Знания", "icon": "quill", "text": "Поставьте скрипторий и наймите писца."},
	{"id": "research", "title": "Исследования", "icon": "research", "text": "Выберите знание и нажмите «Изучить»."},
	{"id": "done", "title": "Город в ваших руках", "icon": "laurels", "next": true, "text": "Стройте, заселяйте и радуйте жителей."},
]
const UI_AFTER := {"settle": 1, "script": 2, "done": 3}
const BUILD_STEPS := {"houses": "house_pleb", "food": "stall_fruit", "script": "scriptorium"}


static func step_index(id: String) -> int:
	if id == "turn":
		return 0
	for i in STEPS.size():
		if STEPS[i]["id"] == id:
			return i
	return -1


static func saved_step(tips: Dictionary) -> int:
	var old: int = int(tips.get("tut", -1))
	if old < 0:
		return -1
	if tips.has("tut_id"):
		var by_id := step_index(String(tips["tut_id"]))
		if by_id >= 0:
			return by_id
	return step_index(OLD_IDS[old]) if old < OLD_IDS.size() else -1


func setup(g) -> void:
	game = g
	hud = g.hud
	_card()
	step = resume_step(game.city)
	game.city.family_assigned.connect(_assigned)
	if step >= 0:
		_enter(step)
	else:
		card.hide()


## Старые дома остаются на месте; возвращаемся к ближайшему нужному действию.
static func resume_step(c: City) -> int:
	var i := saved_step(c.tips)
	if i < 0:
		return i
	var id := String(STEPS[i]["id"])
	# Сохранение возвращает семью в пути на площадь.
	if id in ["house", "house_info"] and not c.arrivals.is_empty() and _house_target(c).is_empty():
		return step_index("settle")
	if int(c.tips.get("tut_v", 0)) >= 8:
		return i
	if id in ["houses", "road"]:
		return step_index("houses") if c._count(func(b): return c.is_house(b)) < 3 else step_index("road")
	if id in ["cart", "settle"] and c.families_came() == 0 and not c.has_connected_house():
		return step_index("road") if c._count(func(b): return c.is_house(b)) >= 3 else step_index("houses")
	return i


static func start_new(c: City) -> void:
	c.tips["tut_v"] = 8
	c.tips["tut"] = 0
	c.tips["tut_id"] = "move"
	c.tips["ui"] = 0


## После героя показываем управление; повозка ждёт дороги к дому.
func welcome() -> void:
	if active() and cur_id() == "move":
		_enter(step_index("move"))


func active() -> bool:
	return step >= 0 and step < STEPS.size()


func cur_id() -> String:
	return String(STEPS[step]["id"]) if active() else ""


func _card() -> void:
	card = PanelContainer.new()
	card.name = "TutorialCard"
	card.add_theme_stylebox_override("panel", hud.guide_style())
	card.custom_minimum_size = Vector2(416, 96)
	hud.root.add_child(card)
	hud._put(card, Control.PRESET_TOP_LEFT, Vector2(8, hud.TASKS_Y + 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)
	icon_box = Panel.new()
	icon_box.custom_minimum_size = Vector2(48, 48)
	icon_box.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(icon_box)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	h.add_child(v)
	title = hud._label("", 16, true)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(title)
	text = hud._label("", 12)
	text.clip_text = true
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(text)
	hint = hud._label("", 12)
	hint.name = "TutorialHouseHint"
	hint.hide()
	v.add_child(hint)
	dots = HBoxContainer.new()
	dots.add_theme_constant_override("separation", 4)
	v.add_child(dots)
	for i in STEPS.size():
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(6, 6)
		dots.add_child(dot)
	var skip: Button = hud.guide_link("Пропустить обучение", finish)
	skip.name = "TutorialSkip"
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	v.add_child(actions)
	skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(skip)
	show_btn = hud.guide_button("Показать", show_target)
	show_btn.name = "TutorialShow"
	show_btn.custom_minimum_size = Vector2(76, 30)
	show_btn.add_theme_font_size_override("font_size", 12)
	actions.add_child(show_btn)
	# Клавиши показываем рядом с карточкой осмотра.
	camera_keys = TextureRect.new()
	camera_keys.name = "TutorialCameraKeys"
	camera_keys.texture = preload("res://assets/ui/tutorial_keys.svg")
	camera_keys.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	camera_keys.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	camera_keys.size = Vector2(296, 56)
	camera_keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camera_keys.hide()
	hud.root.add_child(camera_keys)
	next_btn = hud.guide_button("Понятно", _confirm)
	next_btn.custom_minimum_size = Vector2(76, 30)
	next_btn.add_theme_font_size_override("font_size", 12)
	next_btn.name = "TutorialNext"
	next_btn.hide()
	actions.add_child(next_btn)


func _enter(i: int) -> void:
	var changed := step != i
	step = i
	_script_built = false
	_research_hint = null
	game.city.tips["tut_v"] = 8
	game.city.tips["tut"] = i
	game.city.tips["tut_id"] = cur_id()
	var s: Dictionary = STEPS[i]
	card.show()
	title.text = s["title"]
	text.text = s["text"]
	camera_keys.visible = cur_id() == "move"
	next_btn.visible = bool(s.get("next", false))
	show_btn.text = "Открыть дом" if cur_id() == "house" else "Показать"
	show_btn.visible = cur_id() not in ["move", "cart"] and not next_btn.visible
	hint.visible = cur_id() == "house_info"
	if hint.visible:
		hint.text = "Значки — что нужно семье.\nЗелёное — есть, бледное — нужно поставить рядом."
	if changed:
		if _card_fade != null:
			_card_fade.kill()
		card.modulate.a = 0.55
		_card_fade = create_tween()
		_card_fade.tween_property(card, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)
	for j in dots.get_child_count():
		var style := StyleBoxFlat.new()
		style.bg_color = CityStyle.OLIVE if j == i else (Color("9b9468") if j < i else Color("d9cdb3"))
		style.set_corner_radius_all(3)
		(dots.get_child(j) as Panel).add_theme_stylebox_override("panel", style)
	hud._clear(icon_box)
	var ic := CityStyle.pictogram(String(s["icon"]), 48)
	ic.size = Vector2(48, 48)
	icon_box.add_child(ic)
	_move0 = game.rig.look_distance
	_zoom0 = game.rig.look_zooms
	_rp0 = game.city.research.size()
	hud.clear_badge("tutorial_target")
	hud._ptr_shown = {}
	hud.advisor_panel.hide()
	var c: City = game.city
	match cur_id():
		"cart":
			if c.families_came() == 0:
				c._tick_arrivals()
			var cart: Dictionary = game.people.cart
			if cart.get("state", "") == "wait":
				cart["t"] = minf(float(cart["t"]), 0.6)
			var ctr: Dictionary = c.center()
			if not ctr.is_empty():
				var dp: Vector2 = c.door_point(ctr)
				game.rig.set_view(Vector3(dp.x, Land.BASE_Y, dp.y), 15, 40, 34)
		"research":
			# Карточка писца больше не закрывает кнопку исследований и стрелку.
			game.set_tool("")
			hud._close_tray()
			hud._hide_info()
			var cheapest := 1e9
			for r: Dictionary in Defs.RESEARCH:
				if c.research_open(String(r["id"])):
					cheapest = minf(cheapest, float(r["cost"]))
			if cheapest < 1e9:
				c.rp = maxf(c.rp, minf(c.rp_cap(), cheapest))
		"houses", "road", "settle", "house", "food", "workers", "script", "done":
			game.set_tool("")
			hud._close_tray()
			hud._hide_info()
	hud.apply_reveal(int(c.tips.get("ui", 3)))
	hud._update_pointer()
	layout()


func reveal() -> void:
	var on := active()
	hud.bar_left.visible = not on or cur_id() != "move"
	hud.bar_mid.visible = not on or step >= step_index("houses")
	hud.bar_right.visible = not on
	for cat: String in hud.cats:
		if cat == "military":
			continue
		var first := {"housing": "houses", "commerce": "food", "farming": "script", "decor": "done", "monuments": "done"}
		(hud.cats[cat].get_parent() as Control).visible = not on or step >= step_index(String(first.get(cat, "done")))


func layout() -> void:
	if not active() or not card.visible:
		return
	var pos := Vector2(8, hud.TASKS_Y + 24)
	var required: Array[Rect2] = []
	if is_instance_valid(hud.pointer_target) and hud.pointer_target.is_visible_in_tree():
		var margin := 12.0 if hud.pointer_target is MapBadge else 62.0
		required.append(hud.pointer_target.get_global_rect().grow(margin))
		# Не накрываем карточку исследования, в которую ведёт стрелка.
		var parent: Node = hud.pointer_target.get_parent()
		while parent != null and parent != hud.root:
			if parent is Button:
				required.append((parent as Control).get_global_rect().grow(8))
				break
			parent = parent.get_parent()
	var avoid: Array[Rect2] = required.duplicate()
	for panel: Control in [hud.info_panel, hud.research_panel, hud.fam_box, hud.tray]:
		if panel.is_visible_in_tree():
			avoid.append(panel.get_global_rect().grow(8))
	var found := false
	# Сначала бережём всё окно. На низком экране — хотя бы саму цель и её карточку.
	for attempt in 2:
		var obstacles: Array[Rect2] = avoid if attempt == 0 else required
		for x: float in [8.0, maxf(8.0, hud.root.size.x - card.size.x - 8.0)]:
			for y in range(int(hud.TASKS_Y + 24), int(hud.root.size.y - card.size.y - 92), 24):
				var rect := Rect2(Vector2(x, y), card.size)
				var free := true
				for other: Rect2 in obstacles:
					if rect.intersects(other):
						free = false
						break
				if free:
					pos = rect.position
					found = true
					break
			if found:
				break
		if found:
			break
	if card.position != pos:
		hud._put(card, Control.PRESET_TOP_LEFT, pos)
	var keys_pos := pos + Vector2(10, card.size.y + 10)
	if camera_keys.position != keys_pos:
		camera_keys.position = keys_pos


## Та же цель, что у единственной стрелки: открываем нужный раздел и подводим камеру.
func show_target() -> void:
	var c: City = game.city
	match cur_id():
		"road":
			hud._do_click({"kind": "road"})
		"houses", "food", "script":
			if cur_id() != "script" or c._count(func(b): return b["type"] == "scriptorium") == 0:
				hud._do_click({"kind": "build", "type": BUILD_STEPS[cur_id()]})
		"settle":
			if game.tool != "settle":
				hud._do_click({"kind": "fam"})
		"research":
			if not hud.research_panel.visible:
				hud._top_action("research")
	hud._update_pointer()
	var target: Control = hud.pointer_target
	if is_instance_valid(target):
		for entry: Dictionary in hud.badges.values():
			if entry["n"] == target:
				var pos: Vector3 = entry["pos"]
				if cur_id() == "house":
					var open: Callable = entry["cb"]
					if open.is_valid():
						open.call()
					return
				game.rig.set_view(pos, 15, 40, 30)
				break
	hud._ensure_pointer_visible()


func _confirm() -> void:
	if active() and bool(STEPS[step].get("next", false)):
		_done()


func _assigned(_name: String, home: int) -> void:
	if cur_id() == "settle":
		game.city.tips["tut_home"] = home
		_done()


func _done() -> void:
	if not active():
		return
	hud._hide_guidance_pointer(true)
	var id := cur_id()
	if UI_AFTER.has(id):
		game.city.tips["ui"] = maxi(int(game.city.tips.get("ui", 0)), int(UI_AFTER[id]))
	if step >= STEPS.size() - 1:
		finish()
		return
	game.sound.ui("coins")
	_enter(step + 1)


func finish() -> void:
	step = STEPS.size()
	game.city.tips["tut"] = -1
	game.city.tips["tut_id"] = ""
	game.city.tips["ui"] = 3
	game.settings["tut_done"] = true
	game.save_settings()
	card.hide()
	camera_keys.hide()
	next_btn.hide()
	hud.clear_badge("tutorial_target")
	hud._ptr_shown = {}
	hud._hide_guidance_pointer(true)
	hud.apply_reveal(3)
	hud.refresh()


func _process(dt: float) -> void:
	if not cine.is_empty():
		if game != null and float(game._min_speed) >= 0.0:
			return
		_cine_tick(dt)
		return
	if not active() or game == null or not game.ready_done or _opening or HeroScreen.is_open(game):
		return
	if _check(cur_id()):
		_done()
	else:
		# Лавку закрывает переход к найму; у скриптория найм в этом же шаге.
		if cur_id() == "script" and not _script_built and game.city._count(func(b): return b["type"] == "scriptorium") > 0:
			_script_built = true
			if game.tool == "scriptorium":
				game.set_tool("")
			hud._update_pointer()
		layout()


func _check(id: String) -> bool:
	var c: City = game.city
	match id:
		"move":
			return float(game.rig.look_distance) - _move0 >= 12.0 and int(game.rig.look_zooms) > _zoom0
		"road":
			return c.has_connected_house()
		"houses":
			return c._count(func(b): return c.is_house(b)) >= 3
		"cart":
			return not c.arrivals.is_empty()
		"settle":
			return c.settled_total > 0 or not c.pending.is_empty()
		"house":
			var target := _house_target(c)
			return hud.info_panel.visible and not target.is_empty() and is_same(hud.info_b, target)
		"food":
			return c._count(func(b): return b["type"] == "stall_fruit") >= 1
		"workers":
			return c._count(func(b): return b["type"] == "stall_fruit" and c.hired_of(b) > 0) >= 1
		"script":
			return c._count(func(b): return b["type"] == "scriptorium" and c.hired_of(b) > 0) >= 1
		"research":
			return c.research.size() > _rp0
	return false


static func _house_target(c: City) -> Dictionary:
	var home: Dictionary = c.buildings.get(int(c.tips.get("tut_home", -1)), {})
	if not home.is_empty() and (int(home.get("coming", 0)) > 0 or int(home.get("pop", 0)) > 0):
		return home
	for b: Dictionary in c.buildings.values():
		if c.is_house(b) and (int(b.get("coming", 0)) > 0 or int(b.get("pop", 0)) > 0):
			return b
	return {}


func _world(pos: Vector3, icon: String, cb := Callable()) -> Control:
	hud.set_badge("tutorial_target", pos, icon, false, "", cb)
	return hud.badges["tutorial_target"]["n"] as Control


func _building(b: Dictionary, icon := "info") -> Control:
	var top: float = game.city.blueprint(b).top_y() + 1.2
	return _world(Vector3(b["pos"].x, float(b["y"]) + top, b["pos"].y), icon, func():
		game.select_building(b)
		hud.open_info(b))


func _build_target(type: String) -> Control:
	if not game.city.unlocked(type):
		return null
	return hud._card_or_cat(String(Defs.B[type]["cat"]), type)


## Маленькая первая семья иногда даёт лишь одного работника.
func _more_workers() -> Array:
	var c: City = game.city
	if not c.pending.is_empty():
		text.text = "Ждём семью у дома."
		return [null, ""]
	if game.tool == "settle":
		var homes: Array = c.homes_for(game.settle_fam)
		var from: Vector2 = c.center()["pos"]
		homes.sort_custom(func(a, b): return (a["pos"] as Vector2).distance_squared_to(from) < (b["pos"] as Vector2).distance_squared_to(from))
		if not homes.is_empty():
			var key := "settle%d" % int(homes[0]["id"])
			if hud.badges.has(key):
				text.text = "Поселите ещё семью — нужен работник."
				return [hud.badges[key]["n"], "Выберите дом"]
	if not c.arrivals.is_empty():
		hud._hide_info()
		text.text = "Поселите ещё семью — нужен работник."
		return [family_target(), "Семья"]
	text.text = "Ещё одна семья скоро приедет."
	return [null, ""]


func pointer() -> Array:
	if _opening or not cine.is_empty() or HeroScreen.is_open(game):
		return [null, ""]
	var c: City = game.city
	var id := cur_id()
	var tool: String = game.tool
	var placing: bool = Defs.B.has(tool) or game.is_road_tool(tool)
	show_btn.visible = id not in ["move", "cart"] and not next_btn.visible and not placing
	if id == "research" and hud.research_panel.visible:
		show_btn.hide()
	if id == "houses":
		text.text = "Поставьте дома рядом с площадью." if tool == "house_pleb" else STEPS[step]["text"]
	if placing:
		return [null, ""]
	if id in ["workers", "script"]:
		var type := "stall_fruit" if id == "workers" else "scriptorium"
		for b: Dictionary in c.buildings.values():
			if b["type"] == type and c.hired_of(b) == 0:
				if not c.can_hire(b):
					return _more_workers()
				text.text = String(STEPS[step]["text"])
				if not hud.info_panel.visible or int(hud.info_b.get("id", -1)) != int(b["id"]):
					hud.open_info(b)
				return [hud._do_target(hud.hire_do(b)), "Нанять работника"]
	match id:
		"road":
			return [hud.road_target(), "Дороги"]
		"houses":
			return [_build_target("house_pleb"), "Дом плебеев"]
		"settle":
			if game.tool == "settle":
				var homes: Array = c.homes_for(game.settle_fam)
				var from: Vector2 = c.center()["pos"]
				homes.sort_custom(func(a, b): return (a["pos"] as Vector2).distance_squared_to(from) < (b["pos"] as Vector2).distance_squared_to(from))
				if not homes.is_empty():
					var key := "settle%d" % int(homes[0]["id"])
					if hud.badges.has(key):
						return [hud.badges[key]["n"], "Выберите дом"]
			if not c.pending.is_empty() or c.settled_total > 0:
				return [null, ""]
			return [family_target(), "Семья"]
		"house":
			var home := _house_target(c)
			if not home.is_empty():
				var arriving := int(home.get("coming", 0)) > 0
				return [_building(home), "Семья въезжает…" if arriving else "Как им живётся?"]
		"food":
			return [_build_target("stall_fruit"), "Еда"]
		"script":
			return [_build_target("scriptorium"), "Знания"]
		"research":
			if not hud.research_panel.visible:
				return [hud.top_btns.get("research"), "Исследования"]
			var tree = hud.research_tree
			if tree.pending != "":
				return [tree.confirm_yes, "Да"]
			var target: Control = tree.cheapest_available()
			if target != _research_hint:
				_research_hint = target
				hud._ensure_pointer_visible.call_deferred()
			return [target, "Изучить"]
	return [null, ""]


func family_target() -> Control:
	var arrivals: Array = game.city.arrivals
	if not arrivals.is_empty():
		var key := "fam_" + String(arrivals[0]["name"])
		if hud.badges.has(key):
			return hud.badges[key]["n"] as Control
	return hud._do_target({"kind": "fam"})


# ---------- вступительный ролик: первая повозка въезжает в город (как поезд в Town to City) ----------
## Чёрные полосы кино, интерфейс прячется; камера сначала смотрит на арку въезда — из-под неё выезжает повозка
## с первыми семьями, — потом едет рядом с ней крупным планом до площади у станции. Семьи сходят, подпись просит
## выбрать им дом, и камера плавно возвращается туда, где была. «Пропустить», Esc или правая кнопка — сразу к игре.

const INTRO_FROM_Z := 56.0           # повозка начинает путь за 8 м до арки, а не из-за горизонта
const INTRO_PACE := 1.6              # и едет чуть бодрее обычного — до станции секунд двенадцать
const INTRO_BAR := 0.11              # высота чёрных полос — доля высоты экрана
const INTRO_SAY := ["Первые переселенцы прибыли в ваш город!", "Им нужен дом — выберите его"]
var cine := {}                       # идёт ролик: фаза, время, где камера и куда смотрит
var cine_ui: CanvasLayer


## Первая повозка — после дороги к дому, на шаге «Едут!».
func intro_wanted() -> bool:
	if game == null or hud == null or not cine.is_empty() or not game.ready_done:
		return false
	var c: City = game.city
	if c.tips.has("intro") or game.shot_path != "" or not (game.mode in ["new", "play"]) or not hud.visible or not hud.root.visible:
		return false                     # (интерфейс спрятан для снимка — игрок занят, ролик не нужен)
	if c.settled_total > 0 or not c.arrivals.is_empty() or not c.pending.is_empty():
		return false
	return cur_id() in ["road", "cart"] if active() else game == get_tree().current_scene and c.has_connected_house()


## Повозка тронулась — начинаем: затемнение, и сразу общий план у арки
func intro_start(cart: Dictionary) -> void:
	game.city.tips["intro"] = true
	game.people.cart_seek_z(INTRO_FROM_Z)
	cart["mult"] = 0.0                   # ждёт у арки, пока экран темнеет
	cart["show"] = true                  # и едет своим шагом, даже если на миг выйдет из кадра
	# что игрок делал мышью — отпускаем (начатую дорогу дописываем), инструмент и свиток стройки убираем
	if game.painting:
		game._release()
	game.pressing = false
	game.rot_drag = false
	game.place_lock = {}
	game.set_tool("")
	hud._close_tray()
	var rig = game.rig
	rig._orbit = false
	rig._pan = false
	rig.cine = true
	var p0: Array = rig.pose()
	cine = {"t": 0.0, "phase": "fade", "pt": 0.0, "cart": cart, "speed0": float(game.speed), "said": -1,
		"pos": p0[0], "look": p0[1], "h": (cart["n"] as Node3D).rotation.y, "back": 1.8}
	game.speed = 1.0
	_cine_ui()


func _cine_ui() -> void:
	cine_ui = CanvasLayer.new()
	cine_ui.layer = 40                   # над интерфейсом, под экраном загрузки
	add_child(cine_ui)
	var block := Control.new()           # ловит мышь: пока идёт ролик, мир не щёлкается и камера не крутится
	block.set_anchors_preset(Control.PRESET_FULL_RECT)
	block.mouse_filter = Control.MOUSE_FILTER_STOP
	cine_ui.add_child(block)
	var veil := ColorRect.new()          # затемнение при смене кадра
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.02, 0.015, 0.01, 0.0)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(veil)
	cine["veil"] = veil
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0.02, 0.015, 0.01)
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if top else 1.0
		bar.anchor_bottom = bar.anchor_top
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.add_child(bar)
		cine["bar_top" if top else "bar_bot"] = bar
	var cap := Label.new()
	cap.anchor_right = 1.0
	cap.anchor_top = 1.0 - INTRO_BAR
	cap.anchor_bottom = 1.0
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.add_theme_font_override("font", hud.font_title)
	cap.add_theme_font_size_override("font_size", 32)
	cap.add_theme_color_override("font_color", Color("fff3dc"))
	cap.modulate.a = 0.0
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(cap)
	cine["cap"] = cap
	var skip := Button.new()
	skip.text = "Пропустить  ›"
	skip.flat = true
	skip.focus_mode = Control.FOCUS_NONE
	skip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND   # как у всех кнопок — рисованная «рука»
	skip.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip.anchor_left = 1.0
	skip.anchor_right = 1.0
	skip.anchor_top = 1.0 - INTRO_BAR
	skip.anchor_bottom = 1.0
	skip.offset_left = -260
	skip.offset_right = -30
	skip.add_theme_font_override("font", hud.font_title)
	skip.add_theme_font_size_override("font_size", 20)
	for st in ["font_color", "font_focus_color"]:
		skip.add_theme_color_override(st, Color(1.0, 0.94, 0.82, 0.62))
	for st in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		skip.add_theme_color_override(st, Color("ffe7a8"))
	skip.pressed.connect(_cine_skip)
	block.add_child(skip)
	cine["skip"] = skip
	_cine_bars(0.0)


## Пока идёт ролик: Esc и правая кнопка — пропустить; клавиши игре не достаются
func _input(e: InputEvent) -> void:
	if cine.is_empty():
		return
	if e is InputEventKey:
		if e.is_pressed() and not e.is_echo() and (e as InputEventKey).keycode == KEY_ESCAPE:
			_cine_skip()
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		if e.is_pressed():
			_cine_skip()
		get_viewport().set_input_as_handled()


func _cine_skip() -> void:
	if cine.is_empty() or cine["phase"] == "back":
		return
	var cart: Dictionary = cine["cart"]
	if cart.get("state", "") == "in":
		cart["mult"] = 1.0               # повозка доедет сама, обычным шагом
	_cine_back(1.0)


func _cine_phase(name: String) -> void:
	cine["phase"] = name
	cine["pt"] = 0.0


func _cine_back(dur: float) -> void:
	if cine["phase"] == "back":
		return
	cine["from_pos"] = cine["pos"]
	cine["from_look"] = cine["look"]
	cine["back"] = dur
	(cine["cart"] as Dictionary)["show"] = false
	_cine_say(-1)
	_cine_phase("back")


## Подпись внизу: прежняя гаснет, новая проявляется (-1 — просто погасить)
func _cine_say(i: int) -> void:
	var cap: Label = cine["cap"]
	cine["said"] = maxi(int(cine["said"]), i)
	var tw := cap.create_tween()
	if cap.modulate.a > 0.01:
		tw.tween_property(cap, "modulate:a", 0.0, 0.35)
	if i >= 0:
		tw.tween_callback(func(): cap.text = intro_line(i))
		tw.tween_property(cap, "modulate:a", 1.0, 0.7)


## Подпись ролика: имя города — то же, что на табличке (с сервера); пока его нет — «ваш город»
func intro_line(i: int) -> String:
	if _opening and i == 1:
		return "Начнём с улицы и домов для семей."
	var nm := String(game.city.name) if i == 0 and game != null and game.city != null else ""
	return "Первые переселенцы прибыли в город «%s»!" % nm if nm != "" else String(INTRO_SAY[i])


func _cine_bars(k: float) -> void:
	var h := get_viewport().get_visible_rect().size.y * INTRO_BAR * k
	(cine["bar_top"] as Control).offset_bottom = h
	(cine["bar_bot"] as Control).offset_top = -h
	(cine["skip"] as Control).modulate.a = k


## Общий план: камера на городской стороне арки, чуть сбоку, медленно наезжает — повозка выезжает из-под арки на нас
func _cine_arch(pt: float) -> Array:
	var g := Land.GATE
	var gy: float = game.land.height_at(g.x, g.y + 12.0)
	var u := smoothstep(0.0, 5.0, pt)
	return [Vector3(g.x + 5.5, gy + 2.8, g.y + 14.0).lerp(Vector3(g.x + 4.2, gy + 2.2, g.y + 10.5), u), Vector3(g.x, gy + 1.7, g.y - 2.0)]


## Смещение от повозки (влево, вверх, вперёд — по её ходу) в мировых осях
func _cine_rel(v: Vector3) -> Vector3:
	var h: float = cine["h"]
	return Vector3(cos(h), 0, -sin(h)) * v.x + Vector3.UP * v.y + Vector3(sin(h), 0, cos(h)) * v.z


## Крупный план: камера едет вместе с повозкой со стороны возницы — сначала спереди, потом сбоку.
## Смещения сглаживаются, а не положение: повозка всегда в кадре, а камера мягко обходит её
func _cine_follow(pt: float, dt: float) -> void:
	var u := smoothstep(0.5, 9.0, pt)
	var want_off := _cine_rel(Vector3(4.2, 2.6, 6.4).lerp(Vector3(6.6, 3.0, 1.4), u))
	var want_look := _cine_rel(Vector3(0.0, 0.9, 1.0))
	cine["off"] = (cine["off"] as Vector3).lerp(want_off, 1.0 - exp(-dt * 1.3))
	cine["loff"] = (cine["loff"] as Vector3).lerp(want_look, 1.0 - exp(-dt * 2.6))


## Приехали: камера отходит и поднимается над остановившейся повозкой — видно, как семьи сходят и идут на площадь
func _cine_arrive(dt: float) -> void:
	cine["off"] = (cine["off"] as Vector3).lerp(_cine_rel(Vector3(7.8, 5.4, 4.0)), 1.0 - exp(-dt * 0.9))
	cine["loff"] = (cine["loff"] as Vector3).lerp(_cine_rel(Vector3(-0.6, 0.4, 1.0)), 1.0 - exp(-dt * 1.2))


func _cine_tick(dt: float) -> void:
	dt = minf(dt, 0.05)
	cine["t"] = float(cine["t"]) + dt
	cine["pt"] = float(cine["pt"]) + dt
	var pt: float = cine["pt"]
	var cart: Dictionary = cine["cart"]
	var n: Node3D = cart["n"]
	var rig = game.rig
	var veil: ColorRect = cine["veil"]
	if float(cine["t"]) > 40.0 and cine["phase"] != "back":
		_cine_back(1.2)                  # на всякий случай: ролик не дольше 40 секунд
		pt = 0.0
	if cine["phase"] != "arrive":
		cine["h"] = lerp_angle(float(cine["h"]), n.rotation.y, 1.0 - exp(-dt * 1.6))
	var want: Array = [cine["pos"], cine["look"]]
	match cine["phase"]:
		"fade":
			# экран темнеет, интерфейс прячется; под затемнением — сразу к арке
			veil.color.a = smoothstep(0.0, 0.45, pt)
			hud.root.modulate.a = 1.0 - smoothstep(0.0, 0.45, pt)
			if pt >= 0.45:
				hud.visible = false
				cart["mult"] = INTRO_PACE
				var a := _cine_arch(0.0)
				cine["pos"] = a[0]
				cine["look"] = a[1]
				want = a
				_cine_phase("arch")
		"arch":
			veil.color.a = 1.0 - smoothstep(0.0, 0.9, pt)
			want = _cine_arch(pt)
			if pt > 1.0 and int(cine["said"]) < 0:
				_cine_say(0)
			if cart["state"] != "in" or n.position.z > Land.GATE.y + 1.5:
				# повозка выехала из-под арки — камера пристраивается к ней с того места, где стоит
				cine["h"] = n.rotation.y
				cine["anchor"] = n.position
				cine["off"] = (cine["pos"] as Vector3) - n.position
				cine["loff"] = (cine["look"] as Vector3) - n.position
				_cine_phase("follow")
		"follow", "arrive":
			veil.color.a = 0.0
			if cine["phase"] == "follow":
				cine["anchor"] = n.position
				_cine_follow(pt, dt)
				if cart["state"] != "in":
					_cine_phase("arrive")       # встала у станции (дальше смотрим на это место, даже когда она поедет назад)
			else:
				_cine_arrive(dt)
				if pt > 0.8 and int(cine["said"]) < 1:
					_cine_say(1)
				if pt > 3.8:
					_cine_back(1.8)
			var an: Vector3 = cine["anchor"]
			var cp: Vector3 = an + (cine["off"] as Vector3)
			cp.y = maxf(cp.y, game.land.height_at(cp.x, cp.z) + 0.8)
			cine["pos"] = cp
			cine["look"] = an + (cine["loff"] as Vector3)
			if cine["phase"] != "back":
				rig.cine_look(cp, cine["look"])
				cine["bars"] = smoothstep(0.0, 0.8, float(cine["t"]))
				_cine_bars(cine["bars"])
			return
		"back":
			# плавно назад, туда, где камера была до ролика; полосы уходят, интерфейс возвращается
			var bl: float = cine["back"]
			var u := smoothstep(0.0, bl, pt)
			var to: Array = rig.pose()
			rig.cine_look((cine["from_pos"] as Vector3).lerp(to[0], u), (cine["from_look"] as Vector3).lerp(to[1], u))
			veil.color.a = maxf(0.0, veil.color.a - dt * 3.0)
			_cine_bars(minf(float(cine.get("bars", 1.0)), 1.0 - smoothstep(0.0, bl * 0.7, pt)))
			if pt > bl * 0.35:
				hud.visible = true
				hud.root.modulate.a = maxf(hud.root.modulate.a, smoothstep(bl * 0.35, bl, pt))
			if pt >= bl:
				_cine_end()
			return
	# камера догоняет нужный кадр мягко — без рывков на изгибах дороги
	var kk := 1.0 - exp(-dt * 2.2)
	var cp: Vector3 = (cine["pos"] as Vector3).lerp(want[0], kk)
	cp.y = maxf(cp.y, game.land.height_at(cp.x, cp.z) + 0.8)
	cine["pos"] = cp
	cine["look"] = (cine["look"] as Vector3).lerp(want[1], kk)
	rig.cine_look(cp, cine["look"])
	cine["bars"] = smoothstep(0.0, 0.8, float(cine["t"]))
	_cine_bars(cine["bars"])


func _cine_end() -> void:
	var rig = game.rig
	rig.cine = false
	rig._orbit = false
	rig._pan = false
	hud.visible = true
	hud.root.modulate.a = 1.0
	if cine_ui != null:
		cine_ui.queue_free()
		cine_ui = null
	var s0: float = cine["speed0"]
	var cart: Dictionary = cine["cart"]
	cart["show"] = false
	if cart.get("state", "") == "in":
		cart["mult"] = 1.0
	cine = {}
	if _opening:
		_opening = false
		_enter(step_index("move"))   # движение камеры в ролике не засчитываем игроку
	if float(game._min_speed) >= 0.0:
		# окно свёрнуто — скорость игрока отдаём тому, кто вернёт её при разворачивании
		if is_equal_approx(float(game._min_speed), 1.0) and s0 > 1.0:
			game._min_speed = s0
			hud.paused_speed = s0
		hud.refresh()
	elif is_equal_approx(float(game.speed), 1.0) and s0 > 1.0:
		hud.set_speed(s0)            # игрок ждал повозку на быстрой скорости — она и остаётся
	else:
		hud.refresh()
