class_name Tutorial
extends Node
## Обучение при первом входе — как в Town to City: по одному действию за шаг, стрелка показывает,
## куда нажать, интерфейс открывается постепенно. Шаг и уровень интерфейса хранятся в city.tips,
## поэтому после загрузки обучение продолжается с того же места. Можно пропустить в любой момент.

var game
var hud
var step := -1
var card: PanelContainer
var title: Label
var text: Label
var icon_box: Control
var count: Label
var next_btn: Button
var _cam0 := Vector3.ZERO
var _yaw0 := 0.0
var _dist0 := 0.0
var _rp0 := 0
var _t := 0.0
var _wait := 0.0                     # пауза после выполненного шага (галочка)

const STEPS := [
	{"id": "move", "title": "Осмотримся", "icon": "move",
		"text": "Двигайте камеру клавишами W A S D или стрелками. Колёсико мыши — ближе и дальше."},
	{"id": "turn", "title": "Повороты", "icon": "view",
		"text": "Зажмите колёсико мыши и ведите в сторону — камера повернётся. Можно и клавишами Q и E. Правая кнопка мыши тянет карту."},
	{"id": "road", "title": "Первая улица", "icon": "road",
		"text": "Нажмите «Мостовую» слева внизу и ведите мышью с зажатой левой кнопкой — от площади у станции в поле. Цена метра видна в окне справа внизу, казна убывает прямо на глазах. Самая дешёвая дорога — «Тропа»: ею выгодно тянуть длинные улицы."},
	{"id": "houses", "title": "Три дома", "icon": "housing",
		"text": "Откройте «Жильё» и поставьте три дома плебеев вдоль дороги. Подведите дом вплотную к дороге — он сам встанет ровно фасадом к ней."},
	{"id": "cart", "title": "Едут!", "icon": "horse",
		"text": "По большой дороге через арку едет повозка с первыми семьями. Подождём, пока они сойдут на площадь у станции."},
	{"id": "settle", "title": "Новоселье", "icon": "family",
		"text": "Нажмите на значок семьи слева вверху — подходящие дома засветятся. Щёлкните по дому, и семья пойдёт туда."},
	{"id": "house", "title": "Как им живётся?", "icon": "info",
		"text": "Семья получила дом! Щёлкните по нему — карточка покажет жителей, их счастье и чего им не хватает."},
	{"id": "food", "title": "Еда", "icon": "food",
		"text": "Тёплый дом — это начало, но жителям нужна еда. Откройте «Лавки» и поставьте фруктовую лавку рядом с домами."},
	{"id": "workers", "title": "Работники", "icon": "hammer", "next": true,
		"text": "В лавке работают жители соседних домов: утром идут за прилавок, вечером — домой. Щёлкните по лавке: кнопками + и − нанимают и увольняют работников. Больше работников — больше домов накормит лавка, но каждому надо платить."},
	{"id": "script", "title": "Знания", "icon": "quill",
		"text": "Новые лавки, дома и украшения открываются исследованиями. Очки исследований даёт скрипторий — откройте «Хозяйство» и поставьте его."},
	{"id": "research", "title": "Исследования", "icon": "research",
		"text": "Нажмите на свиток вверху справа и изучите что-нибудь — например, цветы и вазоны для красоты."},
	{"id": "done", "title": "Город в ваших руках", "icon": "laurels", "next": true,
		"text": "Задания слева подскажут, что дальше. Семьи будут приезжать по двое, пока в городе счастье от 60% — не забывайте их заселять. Полному счастливому дому можно купить этаж в его карточке. Удачи, градоначальник!"},
]

## Уровень интерфейса после шага: 0 — только стройка, 1 — плашка города и классы, 2 — кнопки сверху, 3 — всё
const UI_AFTER := {"settle": 1, "script": 2, "done": 3}


func setup(g) -> void:
	game = g
	hud = g.hud
	_card()
	var c: City = game.city
	step = int(c.tips.get("tut", -1))
	if step >= 0 and step < STEPS.size():
		_enter(step)
	else:
		card.visible = false


static func start_new(c: City) -> void:
	c.tips["tut"] = 0
	c.tips["ui"] = 0


func active() -> bool:
	return step >= 0 and step < STEPS.size()


func cur_id() -> String:
	return STEPS[step]["id"] if active() else ""


func _card() -> void:
	card = hud._panel(null, "scroll_h", 0, 6)                       # свиток с валиками слева и справа
	hud._put(card, Control.PRESET_TOP_LEFT, Vector2(8, hud.TASKS_Y + 8))  # там, где потом будут задания
	card.custom_minimum_size = Vector2(540, 0)
	# окна, карточка постройки и советник рисуются поверх обучения
	hud.root.move_child(card, hud.info_panel.get_index())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	card.add_child(h)
	icon_box = Panel.new()                                          # бронзовый медальон со светом
	icon_box.custom_minimum_size = Vector2(76, 76)
	icon_box.add_theme_stylebox_override("panel", hud._medal("medal_on", 76))
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(icon_box)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	h.add_child(v)
	title = hud._label("", 25, false, hud.C_INK, hud.font_title)
	v.add_child(title)
	text = hud._label("", 17)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(380, 0)
	v.add_child(text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var skip := Button.new()
	skip.text = "Пропустить обучение"
	skip.focus_mode = Control.FOCUS_NONE
	skip.add_theme_font_size_override("font_size", 14)
	skip.add_theme_stylebox_override("normal", hud._box_pill(20, 4))
	skip.add_theme_stylebox_override("hover", hud._box_pill(20, 4, "g_btn_hover"))
	skip.add_theme_stylebox_override("pressed", hud._box_pill(20, 4, "g_btn_on"))
	skip.custom_minimum_size = Vector2(0, 30)
	skip.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	skip.pressed.connect(finish)
	row.add_child(skip)
	count = hud._label("", 14, true, hud.C_SOFT)
	count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(count)
	next_btn = Button.new()
	next_btn.text = "Дальше"
	next_btn.focus_mode = Control.FOCUS_NONE
	next_btn.pressed.connect(func(): _done())
	row.add_child(next_btn)


func _enter(i: int) -> void:
	step = i
	game.city.tips["tut"] = i
	var s: Dictionary = STEPS[i]
	card.visible = true
	title.text = s["title"]
	text.text = s["text"]
	count.text = "%d / %d" % [i + 1, STEPS.size()]
	next_btn.visible = s.get("next", false)
	for ch in icon_box.get_children():
		ch.queue_free()
	# у круглых рисованных значков (глаз, «i») своё кольцо снято — эмаль ложится в медальон
	var face: bool = hud.painted(s["icon"] + "_m")
	var isz := 56 if face else 48
	var ic: TextureRect = hud._icon(s["icon"] + "_m" if face else s["icon"], isz)
	ic.position = Vector2((76 - isz) / 2.0, (76 - isz) / 2.0)
	icon_box.add_child(ic)

	# карточка мягко появляется
	card.modulate.a = 0.0
	card.create_tween().tween_property(card, "modulate:a", 1.0, 0.35)
	_cam0 = game.rig._target_t
	_yaw0 = game.rig._yaw_t
	_dist0 = game.rig._dist_t
	_rp0 = game.city.research.size()
	var c: City = game.city
	match s["id"]:
		"cart":
			# повозка выезжает сразу, камера смотрит на площадь у станции
			if c.arrivals.is_empty() and c.incoming == 0 and c.pending.is_empty():
				c.incoming = 2
			var cart: Dictionary = game.people.cart
			if cart.get("state", "") == "wait":
				cart["t"] = minf(float(cart["t"]), 0.6)     # и трогается почти сразу — начинается ролик
			var ctr := c.center()
			if not ctr.is_empty():
				var dp: Vector2 = c.door_point(ctr)
				game.rig.set_view(Vector3(dp.x, Land.BASE_Y, dp.y), 15, 40, 34)
		"research":
			# первое исследование в обучении — сразу по карману (одно; дальше очки копит скрипторий)
			var cheapest := 1e9
			for r in Defs.RESEARCH:
				if int(r["lvl"]) <= c.level and not r.has("after") and not c.research.has(r["id"]):
					cheapest = minf(cheapest, float(r["cost"]))
			if cheapest < 1e9:
				c.rp = maxf(c.rp, minf(c.rp_cap(), cheapest))
	hud.apply_reveal(int(c.tips.get("ui", 3)))
	hud._update_pointer()


## Шаг выполнен: галочка, пауза, следующий шаг
func _done() -> void:
	if not active() or _wait > 0.0:
		return
	var id := cur_id()
	if UI_AFTER.has(id):
		game.city.tips["ui"] = maxi(int(game.city.tips.get("ui", 0)), int(UI_AFTER[id]))
		hud.apply_reveal(int(game.city.tips["ui"]))
	if step >= STEPS.size() - 1:
		finish()
		return
	title.text = "✓ " + title.text
	game.sound.ui("coins")
	_wait = 1.1


func finish() -> void:
	step = STEPS.size()
	game.city.tips["tut"] = -1
	game.city.tips["ui"] = 3
	game.settings["tut_done"] = true
	game.save_settings()
	card.visible = false
	hud.apply_reveal(3)
	hud.refresh()


func _process(dt: float) -> void:
	if not cine.is_empty():
		if game != null and float(game._min_speed) >= 0.0:
			return                   # окно свёрнуто: ролик ждёт игрока
		_cine_tick(dt)               # пока идёт ролик, шаги обучения ждут
		return
	if not active() or game == null or not game.ready_done:
		return
	if _wait > 0.0:
		_wait -= dt
		if _wait <= 0.0:
			_wait = 0.0
			_enter(step + 1)
		return
	_t += dt
	if _t < 0.2:
		return
	_t = 0.0
	if _check(cur_id()):
		_done()


func _check(id: String) -> bool:
	var c: City = game.city
	var rig = game.rig
	match id:
		"move":
			return (rig._target_t as Vector3).distance_to(_cam0) > 6.0 or absf(float(rig._dist_t) - _dist0) > 12.0
		"turn":
			return absf(angle_difference(float(rig._yaw_t), _yaw0)) > 0.6
		"road":
			return c.road_cells >= 30
		"houses":
			return c._count(func(b): return c.is_house(b)) >= 3
		"cart":
			return not c.arrivals.is_empty()
		"settle":
			return not c.pending.is_empty() or c.settled_total > 0
		"house":
			return hud.info_panel.visible and not hud.info_b.is_empty() and c.is_house(hud.info_b)
		"food":
			return c._count(func(b): return b["type"] == "stall_fruit") >= 1
		"script":
			return c._count(func(b): return b["type"] == "scriptorium") >= 1
		"research":
			return c.research.size() > _rp0
	return false


## Куда показывает стрелка на этом шаге
func pointer() -> Array:
	match cur_id():
		"road":
			if game.tool != "road":
				return [hud.road_btns.get("road"), "Мостовая"]
		"houses":
			if game.tool != "house_pleb":
				return [hud._card_or_cat("housing", "house_pleb"), "Жильё"]
		"settle":
			if game.tool != "settle" and hud.fam_box.visible and hud.fam_box.get_child_count() > 0:
				for x in hud.fam_box.get_child(0).find_children("*", "Button", true, false):
					return [x, "Семья"]
		"food":
			if game.tool != "stall_fruit":
				return [hud._card_or_cat("commerce", "stall_fruit"), "Лавки"]
		"script":
			if game.tool != "scriptorium":
				return [hud._card_or_cat("farming", "scriptorium"), "Хозяйство"]
		"research":
			if not hud.research_panel.visible:
				return [hud.top_btns.get("research"), "Исследования"]
	return [null, ""]


# ---------- вступительный ролик: первая повозка въезжает в город (как поезд в Town to City) ----------
## Чёрные полосы кино, интерфейс прячется; камера сначала смотрит на арку въезда — из-под неё выезжает повозка
## с первыми семьями, — потом едет рядом с ней крупным планом до площади у станции. Семьи сходят, подпись просит
## выбрать им дом, и камера плавно возвращается туда, где была. «Пропустить», Esc или правая кнопка — сразу к игре.

const INTRO_FROM_Z := 56.0           # повозка начинает путь за 8 м до арки, а не из-за горизонта
const INTRO_PACE := 1.6              # и едет чуть бодрее обычного — до станции секунд двенадцать
const INTRO_BAR := 0.11              # высота чёрных полос — доля высоты экрана
const INTRO_SAY := ["Первые переселенцы прибыли в Новый Рим!", "Им нужен дом — выберите его"]
var cine := {}                       # идёт ролик: фаза, время, где камера и куда смотрит
var cine_ui: CanvasLayer


## Ролик — для первой повозки новой игры. В автотестах (игра — не главная сцена) — только на шаге обучения «Едут!»
func intro_wanted() -> bool:
	if game == null or hud == null or not cine.is_empty() or not game.ready_done:
		return false
	var c: City = game.city
	if c.tips.has("intro") or game.shot_path != "" or not (game.mode in ["new", "play"]) or not hud.visible or not hud.root.visible:
		return false                     # (интерфейс спрятан для снимка — игрок занят, ролик не нужен)
	if c.settled_total > 0 or not c.arrivals.is_empty() or not c.pending.is_empty():
		return false
	return cur_id() == "cart" or game == get_tree().current_scene


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
		tw.tween_callback(func(): cap.text = INTRO_SAY[i])
		tw.tween_property(cap, "modulate:a", 1.0, 0.7)


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
