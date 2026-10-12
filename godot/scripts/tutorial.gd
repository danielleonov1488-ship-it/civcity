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
		"text": "Нажмите «Мостовую» слева внизу и ведите мышью с зажатой левой кнопкой — от площади у станции в поле."},
	{"id": "houses", "title": "Три дома", "icon": "housing",
		"text": "Откройте «Жильё» и поставьте три дома плебеев вдоль дороги. Дом сам повернётся фасадом к ней."},
	{"id": "cart", "title": "Едут!", "icon": "horse",
		"text": "Из тоннеля в скале выехала повозка с первыми семьями. Подождём, пока они сойдут на площадь у станции."},
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
		"text": "Задания слева подскажут, что дальше. Семьи будут приезжать по двое — не забывайте их заселять. Счастливые дома сами надстраивают этажи. Удачи, градоначальник!"},
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
			var ctr := c.center()
			if not ctr.is_empty():
				var dp: Vector2 = c.door_point(ctr)
				game.rig.set_view(Vector3(dp.x, Land.BASE_Y, dp.y), 15, 40, 34)
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
