class_name Hud
extends CanvasLayer
## Интерфейс в римском духе: свитки-папирусы с деревянными валиками, бронзовые медальоны с иконками,
## лавровый венок и красное знамя с названием города. Устроен как в Town to City:
## сверху слева — город, жители, счастье, время; рядом — три класса жителей; под ними — задания со стрелкой-подсказкой.
## Сверху справа — события, исследования, финансы, жители, охват, фото, меню.
## Снизу: слева — дороги, посередине — разделы стройки (свиток разворачивается с карточками), справа — инструменты, деньги, очки.

var game
var root: Control
var font: Font
var font_bold: Font
var font_title: Font
var theme_main: Theme
var icons := {}                      # картинки построек для карточек
var _ico := {}

const C_INK := Color("4a2c17")
const C_SOFT := Color("7a5a3c")
const C_GOOD := Color("4f7a2a")
const C_BAD := Color("b0402a")
const C_GOLD := Color("c98a1e")
const C_CREAM := Color("fff4dc")

var lbl_city: Label
var lbl_level: Label
var lbl_pop: Label
var lbl_happy: Label
var lbl_day: Label
var lbl_clock: Label
var speed_btns := []
var class_box: HBoxContainer
var tasks_box: VBoxContainer
var tasks_panel: PanelContainer
var lbl_money: Label
var lbl_income: Label
var lbl_rp: Label
var lbl_rp_day: Label
var cats := {}
var top_btns := {}
var tray: PanelContainer
var tray_grid: HBoxContainer
var tray_tabs: HBoxContainer
var tray_title: Label
var open_cat := ""
var open_sub := "food"
var tool_panel: PanelContainer
var tool_title: Label
var tool_keys: Label
var tool_err: Label
var variant_box: HBoxContainer
var road_panel: PanelContainer
var road_btns := {}
var tool_btns := {}
var info_panel: PanelContainer
var info_box: VBoxContainer
var info_b := {}
var advisor_panel: PanelContainer
var adv_title: Label
var adv_text: Label
var notes_box: VBoxContainer
var events_panel: PanelContainer
var research_panel: PanelContainer
var research_box: VBoxContainer
var lbl_research_rp: Label
var finance_panel: PanelContainer
var stats_panel: PanelContainer
var pause_panel: PanelContainer
var settings_panel: PanelContainer
var buy_panel: PanelContainer
var buy_plot := Vector2i(-1, -1)
var menu_root: Control
var world_icons := {}
var paused_speed := 1.0
var hidden_ui := false
var bell_count := 0
var bell_badge: Label
var pointer: TextureRect
var pointer_target: Control
var pointer_text: Label


func _ready() -> void:
	layer = 10
	_fonts()
	theme_main = _theme()
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme_main
	add_child(root)
	_city_card()
	_class_chips()
	_tasks()
	_top_right()
	_bottom_left()
	_bottom_center()
	_bottom_right()
	_tool_panel()
	_info_panel()
	_advisor()
	_notes()
	_events_panel()
	_research_panel()
	_finance_panel()
	_stats_panel()
	_pause_panel()
	_settings_panel()
	_buy_panel()
	_pointer()
	apply_scale(float(game.settings.get("ui_scale", 1.0)))
	get_tree().node_added.connect(_on_node_added)
	_hook_buttons(self)
	_make_icons()


func apply_scale(s: float) -> void:
	get_window().content_scale_factor = clampf(s, 0.7, 1.6)


## Щелчок у каждой кнопки интерфейса
func _on_node_added(n: Node) -> void:
	if n is BaseButton and is_ancestor_of(n):
		_hook(n)


func _hook_buttons(n: Node) -> void:
	for c in n.find_children("*", "BaseButton", true, false):
		_hook(c)


func _hook(b: BaseButton) -> void:
	if b.has_meta("snd"):
		return
	b.set_meta("snd", true)
	b.pressed.connect(func():
		if game and game.sound:
			game.sound.ui("click"))


# ---------- оформление ----------

func _fonts() -> void:
	font = load("res://assets/fonts/AlegreyaSans-Bold.ttf")
	font_bold = load("res://assets/fonts/AlegreyaSans-ExtraBold.ttf")
	font_title = load("res://assets/fonts/Philosopher-Bold.ttf")


func _tex_box(name: String, m: float, cm := 14.0, mv := -1.0, cmv := -1.0) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load("res://assets/ui/%s.png" % name)
	s.texture_margin_left = m
	s.texture_margin_right = m
	s.texture_margin_top = m if mv < 0 else mv
	s.texture_margin_bottom = m if mv < 0 else mv
	s.content_margin_left = cm
	s.content_margin_right = cm
	s.content_margin_top = cm if cmv < 0 else cmv
	s.content_margin_bottom = cm if cmv < 0 else cmv
	return s


func _theme() -> Theme:
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 18
	t.set_stylebox("panel", "PanelContainer", _tex_box("papyrus", 30, 22))
	t.set_stylebox("normal", "Button", _tex_box("btn2", 20, 14, 20, 8))
	t.set_stylebox("hover", "Button", _tex_box("btn2_hover", 20, 14, 20, 8))
	t.set_stylebox("pressed", "Button", _tex_box("btn2_on", 20, 14, 20, 8))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("disabled", "Button", _tex_box("btn2", 20, 14, 20, 8))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", C_INK)
	t.set_color("font_disabled_color", "Button", Color(C_INK, 0.45))
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		t.set_color(c, "Button", C_INK)
	t.set_constant("h_separation", "Button", 8)
	t.set_color("font_color", "Label", C_INK)
	t.set_stylebox("panel", "TooltipPanel", _tex_box("papyrus", 26, 14))
	t.set_color("font_color", "TooltipLabel", C_INK)
	t.set_font("font", "TooltipLabel", font)
	t.set_font_size("font_size", "TooltipLabel", 17)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "CheckBox", C_INK)
	t.set_stylebox("normal", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("focus", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("hover_pressed", "CheckBox", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "OptionButton", C_INK)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.48, 0.3, 0.16, 0.35)
	sb.set_corner_radius_all(4)
	t.set_stylebox("scroll", "VScrollBar", sb)
	var gr := StyleBoxFlat.new()
	gr.bg_color = Color("8a5a30")
	gr.set_corner_radius_all(4)
	t.set_stylebox("grabber", "VScrollBar", gr)
	t.set_stylebox("grabber_highlight", "VScrollBar", gr)
	t.set_stylebox("grabber_pressed", "VScrollBar", gr)
	t.set_stylebox("scroll", "HScrollBar", sb)
	t.set_stylebox("grabber", "HScrollBar", gr)
	t.set_stylebox("grabber_highlight", "HScrollBar", gr)
	t.set_stylebox("grabber_pressed", "HScrollBar", gr)
	var sl := StyleBoxFlat.new()
	sl.bg_color = Color(0.48, 0.3, 0.16, 0.45)
	sl.set_corner_radius_all(4)
	sl.content_margin_top = 4
	sl.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", sl)
	var sla := StyleBoxFlat.new()
	sla.bg_color = C_GOLD
	sla.set_corner_radius_all(4)
	t.set_stylebox("grabber_area", "HSlider", sla)
	t.set_stylebox("grabber_area_highlight", "HSlider", sla)
	return t


## Иконка из набора (белая SVG) нужного размера — красим через modulate
func ico(name: String, size := 64) -> Texture2D:
	var key := "%s:%d" % [name, size]
	if _ico.has(key):
		return _ico[key]
	var path := "res://assets/ui/icons/%s.svg" % name
	var tex: Texture2D = null
	if FileAccess.file_exists(path):
		var img := Image.new()
		img.load_svg_from_string(FileAccess.get_file_as_string(path), size / 512.0)
		tex = ImageTexture.create_from_image(img)
	_ico[key] = tex
	return tex


func _label(text: String, size := 18, bold := false, col := C_INK, f: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_font_override("font", f if f else (font_bold if bold else font))
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _icon(name: String, size := 22, col := C_INK) -> TextureRect:
	var r := TextureRect.new()
	r.texture = ico(name, 64)
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.modulate = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Бронзовый медальон с иконкой посередине (иконка всегда внутри круга)
func _round(name: String, tip: String, size := 56, cb: Callable = Callable()) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	for st: Array in [["normal", "medal"], ["hover", "medal_hover"], ["pressed", "medal_on"], ["disabled", "medal_lock"]]:
		b.add_theme_stylebox_override(st[0], _tex_box(st[1], 0, 0))
	var ic := _icon(name, int(size * 0.5))
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = size * 0.25
	ic.offset_right = -size * 0.25
	ic.offset_top = size * 0.23
	ic.offset_bottom = -size * 0.27
	ic.name = "ic"
	b.add_child(ic)
	b.set_meta("icon", name)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


func _set_on(b: Button, on: bool) -> void:
	b.add_theme_stylebox_override("normal", _tex_box("medal_on" if on else "medal", 0, 0))


## Медальон с подписью снизу (разделы стройки, инструменты)
func _round_lbl(name: String, text: String, tip: String, size := 60, cb: Callable = Callable()) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	var b := _round(name, tip, size, cb)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)
	var l := _label(text, 14, true, C_INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	v.set_meta("btn", b)
	return v


func _panel(parent: Control = null, tex := "papyrus", m := 30.0, cm := 22.0) -> PanelContainer:
	var p := PanelContainer.new()
	if tex != "papyrus" or m != 30.0 or cm != 22.0:
		p.add_theme_stylebox_override("panel", _tex_box(tex, m, cm))
	(parent if parent else root).add_child(p)
	return p


## Прикрепить окно к углу/краю экрана со сдвигом off (растёт от края внутрь экрана)
func _put(c: Control, preset: int, off: Vector2) -> void:
	c.set_anchors_preset(preset)
	var gh := Control.GROW_DIRECTION_END
	var gv := Control.GROW_DIRECTION_END
	match preset:
		Control.PRESET_TOP_RIGHT:
			gh = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_BOTTOM_LEFT:
			gv = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_BOTTOM_RIGHT:
			gh = Control.GROW_DIRECTION_BEGIN
			gv = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_CENTER_TOP:
			gh = Control.GROW_DIRECTION_BOTH
		Control.PRESET_CENTER_BOTTOM:
			gh = Control.GROW_DIRECTION_BOTH
			gv = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_CENTER:
			gh = Control.GROW_DIRECTION_BOTH
			gv = Control.GROW_DIRECTION_BOTH
	c.grow_horizontal = gh
	c.grow_vertical = gv
	c.offset_left = off.x
	c.offset_right = off.x
	c.offset_top = off.y
	c.offset_bottom = off.y


func _chip(dark := false, cm := 10.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _tex_box("pill_dark" if dark else "pill", 18, cm, 18, cm * 0.7))
	return p


func fmt(v: float) -> String:
	var n := int(round(absf(v)))
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out


func mouse_over_ui() -> bool:
	if menu_root and menu_root.visible:
		return true
	var h := root.get_viewport().gui_get_hovered_control()
	return h != null and h != root


# ---------- город, классы, задания ----------

func _city_card() -> void:
	var p := _panel(null, "papyrus", 30, 26)
	_put(p, Control.PRESET_TOP_LEFT, Vector2(10, 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	# лавровый венок с орлом — герб города
	var crest := Control.new()
	crest.custom_minimum_size = Vector2(92, 92)
	var wr := TextureRect.new()
	wr.texture = load("res://assets/ui/wreath.png")
	wr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wr.set_anchors_preset(Control.PRESET_FULL_RECT)
	crest.add_child(wr)
	var eagle := _icon("eagle", 44, Color("8a5a22"))
	eagle.position = Vector2(24, 20)
	crest.add_child(eagle)
	h.add_child(crest)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	# знамя с названием
	var ban := TextureRect.new()
	ban.texture = load("res://assets/ui/banner.png")
	ban.custom_minimum_size = Vector2(240, 50)
	ban.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ban.stretch_mode = TextureRect.STRETCH_SCALE
	lbl_city = _label("Новый Рим", 26, false, C_CREAM, font_title)
	lbl_city.add_theme_color_override("font_outline_color", Color("5a1a10"))
	lbl_city.add_theme_constant_override("outline_size", 6)
	lbl_city.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl_city.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_city.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_city.offset_top = -3
	ban.add_child(lbl_city)
	v.add_child(ban)
	lbl_level = _label("Стоянка", 19, true, C_SOFT)
	lbl_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_level.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(lbl_level)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.add_child(_icon("family", 26))
	lbl_pop = _label("0", 21, true)
	row.add_child(lbl_pop)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(16, 0)
	row.add_child(gap)
	row.add_child(_icon("happy", 26, C_GOOD))
	lbl_happy = _label("0%", 21, true, C_GOOD)
	row.add_child(lbl_happy)
	v.add_child(row)
	var t := HBoxContainer.new()
	t.alignment = BoxContainer.ALIGNMENT_CENTER
	t.add_theme_constant_override("separation", 4)
	lbl_day = _label("День 1", 17, true, C_SOFT)
	t.add_child(lbl_day)
	for sp: Array in [[0.0, "pause", "Пауза (пробел)"], [1.0, "play", "Обычная скорость (1)"], [2.0, "fastfwd", "Быстро (2)"], [4.0, "fastfwd", "Очень быстро (3)"]]:
		var s: float = sp[0]
		var b := _round(sp[1], sp[2], 36, func(): set_speed(s))
		t.add_child(b)
		speed_btns.append([b, s])
	lbl_clock = _label("08:00", 16, true, C_SOFT)
	t.add_child(lbl_clock)
	v.add_child(t)


func _class_chips() -> void:
	class_box = HBoxContainer.new()
	_put(class_box, Control.PRESET_TOP_LEFT, Vector2(420, 12))
	class_box.add_theme_constant_override("separation", 8)
	root.add_child(class_box)


func _tasks() -> void:
	tasks_panel = _panel(null, "scroll_v", 36, 26)
	_put(tasks_panel, Control.PRESET_TOP_LEFT, Vector2(10, 204))
	tasks_panel.custom_minimum_size = Vector2(330, 0)
	tasks_box = VBoxContainer.new()
	tasks_box.add_theme_constant_override("separation", 6)
	tasks_panel.add_child(tasks_box)


# ---------- сверху справа ----------

func _top_right() -> void:
	var p := _panel(null, "papyrus", 26, 12)
	_put(p, Control.PRESET_TOP_RIGHT, Vector2(-10, 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	var bell := _round("bell", "События города", 52, func(): _toggle(events_panel); _fill_events())
	h.add_child(bell)
	top_btns["bell"] = bell
	bell_badge = _label("", 15, true, C_CREAM)
	bell_badge.add_theme_color_override("font_outline_color", C_BAD)
	bell_badge.add_theme_constant_override("outline_size", 9)
	bell_badge.position = Vector2(36, -4)
	bell.add_child(bell_badge)
	for t: Array in [["research", "research", "Исследования"], ["finance", "finance", "Финансы"], ["stats", "stats", "Жители и работники"],
			["view", "view", "Показать охват лавок"], ["photo", "photo", "Фото: спрятать интерфейс (любая клавиша — вернуть)"], ["menu", "menu", "Меню игры"]]:
		var id: String = t[0]
		var b := _round(t[1], t[2], 52, func(): _top_action(id))
		h.add_child(b)
		top_btns[id] = b


func _top_action(id: String) -> void:
	match id:
		"research":
			_toggle(research_panel)
			_fill_research()
		"finance":
			_toggle(finance_panel)
			refresh()
		"stats":
			_toggle(stats_panel)
			refresh()
		"view":
			_toggle_reach()
		"photo":
			_photo()
		"menu":
			_toggle(pause_panel)


func _toggle(p: Control) -> void:
	var was := p.visible
	for x in [events_panel, research_panel, finance_panel, stats_panel, pause_panel, settings_panel]:
		if x:
			x.visible = false
	p.visible = not was
	if p.visible and game and game.sound:
		game.sound.ui("open")


var reach_on := false
var reach_rings := []


func _toggle_reach() -> void:
	reach_on = not reach_on
	_set_on(top_btns["view"], reach_on)
	for r in reach_rings:
		(r as Node).queue_free()
	reach_rings.clear()
	if not reach_on:
		return
	for id in game.city.buildings:
		var b: Dictionary = game.city.buildings[id]
		var r := Defs.range_m(game.city.def(b))
		if r <= 0.0 or game.city.def(b)["kind"] == "decor":
			continue
		var ring: MeshInstance3D = game._ring(Color(1.0, 0.85, 0.4, 0.55) if b.get("active", true) else Color(1.0, 0.3, 0.2, 0.6))
		ring.visible = true
		ring.position = Vector3(b["pos"].x, float(b["y"]) + 0.15, b["pos"].y)
		ring.scale = Vector3(r, 1, r)
		reach_rings.append(ring)


func _photo() -> void:
	hidden_ui = true
	root.visible = false


func _unhandled_key_input(e: InputEvent) -> void:
	if hidden_ui and e.is_pressed():
		hidden_ui = false
		root.visible = true
		get_viewport().set_input_as_handled()


# ---------- снизу ----------

func _bottom_left() -> void:
	var p := _panel(null, "papyrus", 26, 22)
	_put(p, Control.PRESET_BOTTOM_LEFT, Vector2(10, -8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	for t: Array in [["road", "road", "Мостовая", "Мостовая: каменная улица (R). Ведите с зажатой кнопкой"], ["path", "path", "Тропа", "Тропа: утоптанная дорожка — почти даром"],
			["plaza", "plaza", "Площадь", "Площадь из узорной плитки"], ["erase", "eraser", "Ластик", "Ластик: стереть дорогу"]]:
		var tn: String = t[0]
		var v := _round_lbl(t[1], t[2], t[3], 56, func(): game.set_tool("" if game.tool == tn else tn))
		h.add_child(v)
		road_btns[tn] = v.get_meta("btn")
	# настройки кисти над кнопками
	road_panel = _panel()
	_put(road_panel, Control.PRESET_BOTTOM_LEFT, Vector2(10, -118))
	road_panel.visible = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	road_panel.add_child(vb)
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 8)
	r1.add_child(_label("Размер кисти", 17, true))
	var sl := HSlider.new()
	sl.min_value = 0.5
	sl.max_value = 4.0
	sl.step = 0.25
	sl.custom_minimum_size = Vector2(160, 26)
	sl.value_changed.connect(func(x): game.brush_r = x)
	sl.name = "size"
	r1.add_child(sl)
	vb.add_child(r1)
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 4)
	for t: Array in [["linefree", "Рисовать свободно"], ["linestraight", "Прямая линия: от точки до точки"], ["brushround", "Круглая кисть"], ["brushsquare", "Квадратная кисть"], ["undo", "Отменить (Ctrl+Z)"], ["redo", "Вернуть (Ctrl+Y)"]]:
		var nm: String = t[0]
		var b := _round(nm, t[1], 46, func(): _road_opt(nm))
		r2.add_child(b)
		road_btns[nm] = b
	vb.add_child(r2)
	var over := CheckBox.new()
	over.text = "Рисовать поверх других дорог (R)"
	over.button_pressed = true
	over.add_theme_font_size_override("font_size", 16)
	over.toggled.connect(func(x): game.brush_over = x)
	over.name = "over"
	road_btns["over"] = over
	vb.add_child(over)


func _road_opt(nm: String) -> void:
	match nm:
		"linefree": game.brush_line = false
		"linestraight": game.brush_line = true
		"brushround": game.brush_square = false
		"brushsquare": game.brush_square = true
		"undo": game._undo()
		"redo": game._redo()
	refresh_tools()


func refresh_tools() -> void:
	if road_btns.has("linefree"):
		_set_on(road_btns["linefree"], not game.brush_line)
		_set_on(road_btns["linestraight"], game.brush_line)
		_set_on(road_btns["brushround"], not game.brush_square)
		_set_on(road_btns["brushsquare"], game.brush_square)
		(road_btns["over"] as CheckBox).set_pressed_no_signal(game.brush_over)
		(road_panel.find_child("size", true, false) as HSlider).set_value_no_signal(game.brush_r)
	_fill_tool_panel()


func _bottom_center() -> void:
	var p := _panel(null, "papyrus", 26, 22)
	_put(p, Control.PRESET_CENTER_BOTTOM, Vector2(0, -8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	for c: Array in Defs.CATS:
		var cid: String = c[0]
		var short: String = {"housing": "Жильё", "commerce": "Лавки", "farming": "Хозяйство", "decor": "Украшения", "special": "Памятники"}.get(cid, c[1])
		var v := _round_lbl(c[2], short, c[1], 62, func(): _toggle_cat(cid))
		h.add_child(v)
		cats[cid] = v.get_meta("btn")
	# свиток с карточками над разделами (разворачивается)
	tray = _panel(null, "scroll_h", 34, 20)
	(tray.get_theme_stylebox("panel") as StyleBoxTexture).content_margin_left = 40
	(tray.get_theme_stylebox("panel") as StyleBoxTexture).content_margin_right = 40
	_put(tray, Control.PRESET_CENTER_BOTTOM, Vector2(0, -120))
	tray.visible = false
	tray.clip_contents = true
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	tray.add_child(v)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 10)
	tray_title = _label("", 22, false, C_INK, font_title)
	top.add_child(tray_title)
	tray_tabs = HBoxContainer.new()
	tray_tabs.add_theme_constant_override("separation", 4)
	top.add_child(tray_tabs)
	v.add_child(top)
	for n in Defs.NEED_ORDER:
		var nn: String = n
		var b := _round(Defs.NEEDS[n]["icon"], Defs.NEEDS[n]["name"], 42, func(): open_sub = nn; _fill_cards())
		b.set_meta("sub", nn)
		tray_tabs.add_child(b)
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.name = "scroll"
	v.add_child(sc)
	tray_grid = HBoxContainer.new()
	tray_grid.add_theme_constant_override("separation", 10)
	sc.add_child(tray_grid)


func _bottom_right() -> void:
	var p := _panel(null, "papyrus", 26, 22)
	_put(p, Control.PRESET_BOTTOM_RIGHT, Vector2(-10, -8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	for t: Array in [["copy", "copy", "Копия", "Копировать постройку (Ctrl+C)"], ["move", "move", "Перенос", "Перенести постройку, дерево или камень (M)"],
			["bulldoze", "demolish", "Снос", "Снос (Delete): постройки, деревья, камни"]]:
		var tn: String = t[0]
		var v := _round_lbl(t[1], t[2], t[3], 54, func(): game.set_tool("" if game.tool == tn else tn))
		h.add_child(v)
		tool_btns[tn] = v.get_meta("btn")
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(6, 0)
	h.add_child(sep)
	var counters := VBoxContainer.new()
	counters.add_theme_constant_override("separation", 2)
	counters.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(counters)
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 6)
	r1.add_child(_icon("research", 26, C_SOFT))
	lbl_rp = _label("0 / 300", 20, true)
	lbl_rp.mouse_filter = Control.MOUSE_FILTER_PASS
	r1.add_child(lbl_rp)
	lbl_rp_day = _label("", 15, true, C_GOOD)
	r1.add_child(lbl_rp_day)
	counters.add_child(r1)
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 6)
	r2.add_child(_icon("coins", 26, C_GOLD))
	lbl_money = _label("0", 22, true)
	lbl_money.mouse_filter = Control.MOUSE_FILTER_PASS
	r2.add_child(lbl_money)
	lbl_income = _label("", 15, true, C_GOOD)
	r2.add_child(lbl_income)
	counters.add_child(r2)


func _toggle_cat(cid: String) -> void:
	if open_cat == cid and tray.visible:
		open_cat = ""
		tray.visible = false
		_refresh_cat_buttons()
		return
	open_cat = cid
	tray.visible = true
	_fill_cards()
	_refresh_cat_buttons()
	_unroll()


## Свиток разворачивается из середины
func _unroll() -> void:
	if game and game.sound:
		game.sound.ui("scroll")
	await get_tree().process_frame
	var w := tray.get_combined_minimum_size().x
	tray.pivot_offset = Vector2(w / 2.0, 0)
	tray.scale = Vector2(0.08, 1.0)
	var tw := create_tween()
	tw.tween_property(tray, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _refresh_cat_buttons() -> void:
	for c in cats:
		_set_on(cats[c], c == open_cat and tray.visible)


func _types_in(cat: String, sub := "") -> Array:
	var out := []
	for type in Defs.B:
		var d: Dictionary = Defs.B[type]
		if d["cat"] != cat:
			continue
		if cat == "commerce" and d.get("sub", "") != sub:
			continue
		out.append(type)
	return out


func _fill_cards() -> void:
	for ch in tray_grid.get_children():
		ch.queue_free()
	tray_tabs.visible = open_cat == "commerce"
	for b in tray_tabs.get_children():
		_set_on(b, b.get_meta("sub") == open_sub)
	var names := {"housing": "Жильё", "commerce": "Лавки и мастерские", "farming": "Хозяйство и науки", "decor": "Украшения", "special": "Памятники"}
	tray_title.text = names.get(open_cat, "")
	if open_cat == "commerce":
		tray_title.text += " · " + Defs.NEEDS[open_sub]["name"]
	var list := _types_in(open_cat, open_sub)
	for type in list:
		var d: Dictionary = Defs.B[type]
		var b := Button.new()
		b.custom_minimum_size = Vector2(128, 172)
		b.set_meta("type", type)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", _tex_box("card2", 22, 6))
		b.add_theme_stylebox_override("hover", _tex_box("card2_hover", 22, 6))
		b.add_theme_stylebox_override("pressed", _tex_box("card2_hover", 22, 6))
		b.tooltip_text = _card_tip(type)
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 0)
		v.offset_top = 8
		v.offset_left = 6
		v.offset_right = -6
		v.offset_bottom = -6
		b.add_child(v)
		var nm := _label(d["name"], 15, true, C_INK)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.custom_minimum_size = Vector2(112, 38)
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		v.add_child(nm)
		var img := TextureRect.new()
		img.custom_minimum_size = Vector2(112, 88)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img.texture = icons.get(type)
		img.name = "img"
		v.add_child(img)
		var pr := HBoxContainer.new()
		pr.alignment = BoxContainer.ALIGNMENT_CENTER
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pr.name = "price"
		v.add_child(pr)
		var tp: String = type
		b.pressed.connect(func(): select_build(tp))
		tray_grid.add_child(b)
	var w := minf(1180.0, list.size() * 138.0)
	(tray.find_child("scroll", true, false) as Control).custom_minimum_size = Vector2(w, 178)
	_update_cards()
	_update_pointer()


func _card_tip(type: String) -> String:
	var d: Dictionary = Defs.B[type]
	var t: String = d["name"].to_upper() + "\n" + d["desc"]
	match d["kind"]:
		"shop":
			t += "\n\nСчастье домам: +%d%%\nДальность обслуживания: %s\nОбслуживает домов: %s\nРабочие: %s" % [d["bonus"], Defs.WORD[int(d["range"])],
				Defs.WORD[int(d["cap"])], _jobs_text(d)]
			t += "\nНужен склад рядом" if d.get("store", false) else "\nСклад не требуется"
		"monument":
			t += "\n\nСчастье всем вокруг: +%d%%\nДальность: %s" % [d["bonus"], Defs.WORD[int(d["range"])]]
		"rp":
			t += "\n\nОчки исследований: +%s в час\nРабочие: %s" % [str(d["rp"]), _jobs_text(d)]
		"house":
			var c: Dictionary = Defs.CLASSES[d["cls"]]
			t += "\n\nЖители: %s, %d на этаж\nНужно им: %s" % [c["name"].to_lower(), c["per_floor"], ", ".join(c["needs"].map(func(n): return Defs.NEEDS[n]["name"].to_lower()))]
		"decor":
			t += "\n\nОчки украшения: %d" % int(d.get("deco", 1))
		"farm", "store":
			if d.has("jobs"):
				t += "\n\nРабочие: %s" % _jobs_text(d)
	if game and game.city and not game.city.unlocked(type):
		t += "\n\nОткроется исследованием «%s»" % Defs.research(d["unlock"]).get("name", "")
	var cnt := 0
	if game and game.city:
		for id in game.city.buildings:
			if game.city.buildings[id]["type"] == type:
				cnt += 1
	t += "\nВ городе: %d" % cnt
	return t


func _jobs_text(d: Dictionary) -> String:
	var parts := []
	for c in d.get("jobs", {}):
		parts.append("%d %s" % [d["jobs"][c], Defs.CLASSES[c]["name"].to_lower()])
	return ", ".join(parts) if not parts.is_empty() else "не нужны"


func _update_cards() -> void:
	var c: City = game.city
	for b in tray_grid.get_children():
		if not b.has_meta("type"):
			continue
		var type: String = b.get_meta("type")
		var d: Dictionary = Defs.B[type]
		var img: TextureRect = b.find_child("img", true, false)
		if img and img.texture == null:
			img.texture = icons.get(type)
		var pr: HBoxContainer = b.find_child("price", true, false)
		for x in pr.get_children():
			x.queue_free()
		if not c.unlocked(type):
			pr.add_child(_icon("lock", 18, C_SOFT))
			var ln := _label(Defs.research(d["unlock"]).get("name", ""), 13, true, C_SOFT)
			ln.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ln.custom_minimum_size = Vector2(90, 0)
			pr.add_child(ln)
			b.add_theme_stylebox_override("normal", _tex_box("card2_lock", 22, 6))
			img.modulate = Color(1, 1, 1, 0.55)
		else:
			pr.add_child(_icon("coins", 20, C_GOLD))
			pr.add_child(_label(fmt(d["cost"]), 18, true, C_INK if c.money >= float(d["cost"]) else C_BAD))
			b.add_theme_stylebox_override("normal", _tex_box("card2", 22, 6))
			img.modulate = Color(1, 1, 1, 1)


func select_build(type: String) -> void:
	if not Defs.B.has(type):
		return
	var cat: String = Defs.B[type]["cat"]
	if cat == "commerce":
		open_sub = Defs.B[type]["sub"]
	if (open_cat != cat or not tray.visible) and cat != "":
		open_cat = cat
		tray.visible = true
		_fill_cards()
		_refresh_cat_buttons()
		_unroll()
	if not game.city.unlocked(type):
		notify("«%s» откроется исследованием «%s»" % [Defs.B[type]["name"], Defs.research(Defs.B[type]["unlock"]).get("name", "")], "lock")
		return
	game.set_tool(type)
	_update_pointer()


# ---------- стрелка-подсказка к заданию ----------

func _pointer() -> void:
	pointer = TextureRect.new()
	pointer.texture = load("res://assets/ui/arrow.png")
	pointer.custom_minimum_size = Vector2(52, 52)
	pointer.size = Vector2(52, 52)
	pointer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pointer.visible = false
	add_child(pointer)
	pointer_text = _label("", 17, true, C_CREAM)
	pointer_text.add_theme_color_override("font_outline_color", Color("3a2412"))
	pointer_text.add_theme_constant_override("outline_size", 7)
	pointer_text.visible = false
	add_child(pointer_text)


## Куда показывает стрелка для первого задания
func _update_pointer() -> void:
	pointer_target = null
	if game == null or game.city == null or game.mode == "demo" or game.mode == "menu":
		return
	var goals: Array = game.city.active_goals(1)
	if goals.is_empty():
		return
	var g: Dictionary = goals[0]
	var tip := ""
	match g["id"]:
		"road1":
			if game.tool != "road":
				pointer_target = road_btns.get("road")
				tip = "Мостовая"
		"houses3", "artisan", "patrician":
			if g["id"] != "houses3" and not game.city.unlocked({"artisan": "house_artisan", "patrician": "house_patrician"}[g["id"]]):
				pointer_target = top_btns.get("research")
				tip = "Исследования"
			else:
				pointer_target = _card_or_cat("housing", {"houses3": "house_pleb", "artisan": "house_artisan", "patrician": "house_patrician"}[g["id"]])
				tip = "Жильё"
		"fruit":
			pointer_target = _card_or_cat("commerce", "stall_fruit")
			tip = "Лавки"
		"scriptorium", "store":
			pointer_target = _card_or_cat("farming", "scriptorium" if g["id"] == "scriptorium" else "warehouse")
			tip = "Хозяйство"
		"research1", "floor2":
			if not research_panel.visible:
				pointer_target = top_btns.get("research")
				tip = "Исследования"
		"decor5":
			pointer_target = _card_or_cat("decor", "flowers")
			tip = "Украшения"
		"temple":
			pointer_target = _card_or_cat("special", "temple")
			tip = "Памятники"
	if game.tool != "" and Defs.B.has(game.tool):
		pointer_target = null
	pointer_text.text = tip


func _card_or_cat(cat: String, type: String) -> Control:
	if tray.visible and open_cat == cat:
		for b in tray_grid.get_children():
			if b.get_meta("type", "") == type:
				return b
	return cats.get(cat)


func _process(_dt: float) -> void:
	if game and lbl_clock:
		var h := int(game.hour)
		var m := int((game.hour - h) * 60.0) / 10 * 10
		lbl_clock.text = "%02d:%02d" % [h, m]
	if pointer:
		var t: Control = pointer_target
		var show := t != null and is_instance_valid(t) and t.is_visible_in_tree() and root.visible
		pointer.visible = show
		pointer_text.visible = show
		if show:
			var r := t.get_global_rect()
			var bob := sin(Time.get_ticks_msec() / 160.0) * 7.0
			var above := r.position.y > 200.0
			pointer.rotation = 0.0 if above else PI
			pointer.pivot_offset = Vector2(26, 26)
			pointer.position = Vector2(r.get_center().x - 26, (r.position.y - 58 - bob) if above else (r.end.y + 6 + bob))
			pointer_text.position = pointer.position + Vector2(26 - pointer_text.size.x / 2.0, -26 if above else 56)


# ---------- панель инструмента (справа над кнопками) ----------

func _tool_panel() -> void:
	tool_panel = _panel()
	_put(tool_panel, Control.PRESET_BOTTOM_RIGHT, Vector2(-10, -118))
	tool_panel.custom_minimum_size = Vector2(350, 0)
	tool_panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	tool_panel.add_child(v)
	tool_title = _label("", 21, false, C_INK, font_title)
	v.add_child(tool_title)
	variant_box = HBoxContainer.new()
	variant_box.add_theme_constant_override("separation", 4)
	v.add_child(variant_box)
	tool_keys = _label("", 15, false, C_SOFT)
	tool_keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tool_keys.custom_minimum_size = Vector2(320, 0)
	v.add_child(tool_keys)
	tool_err = _label("", 16, true, C_BAD)
	tool_err.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tool_err.custom_minimum_size = Vector2(320, 0)
	v.add_child(tool_err)


func on_tool(t: String) -> void:
	for k in road_btns:
		if road_btns[k] is Button and k in ["road", "path", "plaza", "erase"]:
			_set_on(road_btns[k], k == t)
	for k in tool_btns:
		_set_on(tool_btns[k], k == t or (k == "move" and t == "move_nature"))
	road_panel.visible = game.is_road_tool(t)
	tool_err.text = ""
	_fill_tool_panel()
	_update_pointer()


func _fill_tool_panel() -> void:
	var t: String = game.tool
	tool_panel.visible = t != ""
	for ch in variant_box.get_children():
		ch.queue_free()
	variant_box.visible = false
	if t == "":
		return
	if Defs.B.has(t):
		var d: Dictionary = Defs.B[t]
		tool_title.text = "%s · %s ден." % [d["name"], fmt(d["cost"])]
		var keys := "Z/X — поворот · правая кнопка — отмена"
		if int(d.get("variants", 1)) > 1:
			keys = "C/V — другой фасад · " + keys
			variant_box.visible = true
			variant_box.add_child(_label("Фасад:", 16, true))
			for i in int(d["variants"]):
				var vi := i
				var b := Button.new()
				b.text = str(i + 1)
				b.custom_minimum_size = Vector2(38, 34)
				b.tooltip_text = "Фасад %d" % (i + 1)
				b.pressed.connect(func(): game.tool_variant = vi; game.next_variant = vi; _fill_tool_panel())
				if game.tool_variant == i:
					b.add_theme_stylebox_override("normal", _tex_box("btn2_on", 20, 10, 20, 6))
				variant_box.add_child(b)
			var rnd := CheckBox.new()
			rnd.text = "Случайный"
			rnd.button_pressed = game.tool_variant < 0
			rnd.add_theme_font_size_override("font_size", 15)
			rnd.toggled.connect(func(x): game.tool_variant = -1 if x else game.next_variant; _fill_tool_panel())
			variant_box.add_child(rnd)
		if d["kind"] != "decor" and d["kind"] != "farm":
			keys += "\nПривязка к дороге (R): " + ("вкл" if game.snap else "выкл")
		tool_keys.text = keys
	else:
		var names := {"road": "Мостовая", "path": "Тропа", "plaza": "Площадь", "erase": "Ластик", "bulldoze": "Снос", "copy": "Копировать", "move": "Перенести", "move_nature": "Перенести"}
		tool_title.text = names.get(t, t)
		var keys := {"road": "Ведите с зажатой левой кнопкой. [ ] — размер, Ctrl+Z — отменить.",
			"path": "Утоптанная тропа — почти даром.", "plaza": "Плитка для площадей у рынков и храмов.", "erase": "Стирает дорогу под кистью.",
			"bulldoze": "Наведите на постройку, дерево или камень — подсветится красным. Щелчок — снести.", "copy": "Щёлкните по постройке — возьмёте такую же.",
			"move": "Щёлкните по постройке, дереву или камню и поставьте на новое место.", "move_nature": "Поставьте на новое место. Z/X — повернуть."}
		tool_keys.text = keys.get(t, "") + "\nПравая кнопка — отмена"


func tool_status(err: String) -> void:
	tool_err.text = err


# ---------- карточка постройки ----------

func _info_panel() -> void:
	info_panel = _panel(null, "scroll_v", 36, 26)
	_put(info_panel, Control.PRESET_TOP_RIGHT, Vector2(-10, 92))
	info_panel.custom_minimum_size = Vector2(370, 0)
	info_panel.visible = false
	info_box = VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 6)
	info_box.custom_minimum_size = Vector2(330, 0)
	info_panel.add_child(info_box)


func open_info(b: Dictionary) -> void:
	info_b = b
	info_panel.visible = true
	_fill_info()


func _row(icon: String, text: String, val: String, col := C_INK) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	r.add_child(_icon(icon, 22, C_SOFT))
	var l := _label(text, 17)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(l)
	r.add_child(_label(val, 18, true, col))
	return r


func _fill_info() -> void:
	for ch in info_box.get_children():
		ch.queue_free()
	var b := info_b
	if b.is_empty() or not game.city.buildings.has(b["id"]):
		info_panel.visible = false
		return
	var c: City = game.city
	var d := c.def(b)
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	var ib := _round(d.get("icon", Defs.CLASSES[d["cls"]]["icon"] if d.has("cls") else "info"), "Сменить цвет" if c.is_house(b) else d["name"], 48)
	if c.is_house(b):
		(ib.get_node("ic") as TextureRect).texture = ico("color", 64)
		ib.pressed.connect(func(): c.recolor(b))
	hdr.add_child(ib)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := _label(d["name"], 21, false, C_INK, font_title)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(nm)
	hdr.add_child(tv)
	var close := _round("close", "Закрыть", 38, func(): close_panels())
	hdr.add_child(close)
	info_box.add_child(hdr)
	match d["kind"]:
		"house":
			var cls: Dictionary = Defs.CLASSES[d["cls"]]
			tv.add_child(_label("%s · этаж %d из %d · цвет «%s»" % [cls["name"], int(b["tier"]), Defs.floors_max(d["cls"]), Defs.PALETTE[int(b["color"])]["name"]], 14, true, C_SOFT))
			var hp := int(b["happy"])
			var hrow := HBoxContainer.new()
			hrow.add_child(_icon("happy", 30, C_GOOD if hp >= 50 else C_BAD))
			hrow.add_child(_label("+%d%% счастье жителей" % hp, 20, true, C_GOOD if hp >= 50 else C_BAD))
			info_box.add_child(hrow)
			info_box.add_child(_row("flower", "Очки украшения (%d)" % int(b.get("deco", 0)), "+%d%%" % int(b.get("deco_bonus", 0)), C_GOOD))
			if float(b.get("monuments", 0.0)) > 0.0:
				info_box.add_child(_row("level", "Памятники рядом", "+%d%%" % int(b["monuments"]), C_GOOD))
			info_box.add_child(_row("huts", "Теснота", "%d%%" % int(b.get("density", 0)), C_BAD if float(b.get("density", 0)) < 0 else C_SOFT))
			var tax := int(b["pop"]) * float(cls["tax"]) * (0.5 + minf(100.0, float(hp)) / 100.0)
			info_box.add_child(_row("income", "Доход в час", "+%s" % fmt(tax), C_GOOD))
			# потребности: какие лавки обслуживают дом
			for n in Defs.NEED_ORDER:
				var need: Dictionary = Defs.NEEDS[n]
				var shops := []
				for t in b.get("score", {}):
					if Defs.B[t].get("sub", "") == n:
						shops.append(t)
				var required: bool = n in cls["needs"]
				if shops.is_empty() and not required:
					continue
				var r := HBoxContainer.new()
				r.add_theme_constant_override("separation", 4)
				r.add_child(_icon(need["icon"], 26, C_INK if not shops.is_empty() else C_BAD))
				if shops.is_empty():
					r.add_child(_label("%s: нет лавки рядом (−10%%)" % need["name"], 15, true, C_BAD))
				else:
					var fl := HFlowContainer.new()
					fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					for t in shops:
						var chip := _chip()
						var ch := HBoxContainer.new()
						ch.add_child(_icon(Defs.B[t].get("icon", "commerce"), 16))
						ch.add_child(_label("+%d%%" % int(b["score"][t]), 14, true, C_GOOD))
						chip.add_child(ch)
						chip.tooltip_text = Defs.B[t]["name"]
						fl.add_child(chip)
					r.add_child(fl)
				info_box.add_child(r)
			# семьи
			var fams: Array = b.get("families", [])
			if fams.is_empty():
				info_box.add_child(_label("Ждёт новосёлов — повозка привезёт семью из тоннеля", 15, true, C_SOFT))
			for f in fams:
				var fr := HBoxContainer.new()
				fr.add_child(_label("Семья %s" % f["name"], 16, true))
				var sp := Control.new()
				sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				fr.add_child(sp)
				for k in int(f["n"]):
					fr.add_child(_icon("person", 18, C_SOFT))
				info_box.add_child(fr)
			var fmax := Defs.floors_max(d["cls"])
			if int(b["tier"]) < fmax:
				var need_floor := "floor2" if int(b["tier"]) == 1 else "floor3"
				var hint := "Надстроит этаж, когда дом полон и счастье не ниже %d%%" % (55 + 12 * (int(b["tier"]) - 1))
				if not c.research.has(need_floor):
					hint += " (сначала изучите «%s»)" % Defs.research(need_floor)["name"]
				var hl := _label(hint, 14, false, C_SOFT)
				hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				info_box.add_child(hl)
		"shop":
			tv.add_child(_label(Defs.NEEDS[d["sub"]]["name"], 14, true, C_SOFT))
			info_box.add_child(_row("happy", "Счастье домам", "+%d%%" % int(d["bonus"]), C_GOOD))
			info_box.add_child(_row("arrow", "Дальность", Defs.WORD[int(d["range"])]))
			info_box.add_child(_row("housing", "Обслуживает домов", "%d из %d" % [int(b.get("served", 0)), int(ceil(float(Defs.CAPACITY[int(d["cap"])]) * float(b.get("staff", 1.0))))]))
			info_box.add_child(_row("hammer", "Работники", "%d%% (%s)" % [int(float(b.get("staff", 1.0)) * 100.0), _jobs_text(d)], C_GOOD if float(b.get("staff", 1.0)) >= 0.99 else C_BAD))
			if not b.get("active", true):
				var why := {"store": "Нет склада рядом — нечем торговать", "good": "Нет сырья: %s" % {"wheat": "постройте пшеничное поле", "olives": "посадите оливковую рощу", "grapes": "посадите виноградник"}.get(d.get("needs_good", ""), ""),
					"road": "Нет дороги у входа", "staff": "Не хватает работников — нужно больше жителей"}
				var wl := _label(why.get(b.get("why", "staff"), "Не работает"), 15, true, C_BAD)
				wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				info_box.add_child(wl)
		"monument":
			info_box.add_child(_row("happy", "Счастье всем вокруг", "+%d%%" % int(d["bonus"]), C_GOOD))
			info_box.add_child(_row("arrow", "Дальность", Defs.WORD[int(d["range"])]))
		"rp":
			info_box.add_child(_row("research", "Очки исследований в день", "+%.1f" % (float(d["rp"]) * float(b.get("staff", 1.0))), C_GOOD))
			info_box.add_child(_row("hammer", "Работники", "%d%% (%s)" % [int(float(b.get("staff", 1.0)) * 100.0), _jobs_text(d)]))
		"farm":
			info_box.add_child(_row("wheat", "Даёт", {"wheat": "пшеницу", "olives": "оливки", "grapes": "виноград"}[d["makes"]], C_GOOD))
			info_box.add_child(_row("hammer", "Работники", "%d%%" % int(float(b.get("staff", 1.0)) * 100.0)))
		"store":
			info_box.add_child(_row("arrow", "Разносит товары", Defs.WORD[4]))
			info_box.add_child(_row("hammer", "Работники", "%d%%" % int(float(b.get("staff", 1.0)) * 100.0)))
		"center":
			tv.add_child(_label("Уровень города: %s" % Defs.LEVELS[c.level]["name"], 14, true, C_SOFT))
			var nx := c.next_level()
			if not nx.is_empty():
				info_box.add_child(_row("level", "Следующий уровень", nx["name"]))
				info_box.add_child(_row("family", "Жителей", "%d / %d" % [int(c.stats["pop"]), int(nx["pop"])], C_GOOD if int(c.stats["pop"]) >= int(nx["pop"]) else C_INK))
				info_box.add_child(_row("happy", "Счастье", "%d%% / %d%%" % [int(c.stats["happy"]), int(nx["happy"])], C_GOOD if int(c.stats["happy"]) >= int(nx["happy"]) else C_INK))
			if c.waiting > 0:
				info_box.add_child(_row("tent", "Ждут жилья", "%d семей" % c.waiting, C_BAD))
		"decor":
			info_box.add_child(_row("flower", "Очки украшения", "+%d" % int(d.get("deco", 1)), C_GOOD))
	var desc := _label(d["desc"], 14, false, C_SOFT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(300, 0)
	info_box.add_child(desc)
	if not d.get("fixed", false):
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		var bd := Button.new()
		bd.text = "Снести"
		bd.icon = ico("demolish", 32)
		bd.pressed.connect(func(): c.remove(b); close_panels())
		h.add_child(bd)
		var bm := Button.new()
		bm.text = "Перенести"
		bm.icon = ico("move", 32)
		bm.pressed.connect(func(): game.set_tool("move"); game.hover = b["pos"]; game._click(); close_panels())
		h.add_child(bm)
		info_box.add_child(h)




## Закрыть окна; true — было что закрывать
func close_panels() -> bool:
	var any := info_panel.visible or advisor_panel.visible or buy_panel.visible
	for x in [events_panel, research_panel, finance_panel, stats_panel, pause_panel, settings_panel]:
		any = any or x.visible
		x.visible = false
	info_panel.visible = false
	advisor_panel.visible = false
	buy_panel.visible = false
	info_b = {}
	if game:
		game.select_building({})
	_update_pointer()
	return any


func house_event(b: Dictionary, up: bool) -> void:
	if not info_b.is_empty() and info_b.get("id", -1) == b["id"]:
		_fill_info()


# ---------- советник, всплывашки, события ----------

func _advisor() -> void:
	advisor_panel = _panel(null, "scroll_h", 34, 20)
	(advisor_panel.get_theme_stylebox("panel") as StyleBoxTexture).content_margin_left = 44
	(advisor_panel.get_theme_stylebox("panel") as StyleBoxTexture).content_margin_right = 44
	_put(advisor_panel, Control.PRESET_CENTER_TOP, Vector2(0, 110))
	advisor_panel.custom_minimum_size = Vector2(680, 0)
	advisor_panel.visible = false
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	advisor_panel.add_child(h)
	var face := Control.new()
	face.custom_minimum_size = Vector2(96, 96)
	var wr := TextureRect.new()
	wr.texture = load("res://assets/ui/wreath.png")
	wr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wr.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.add_child(wr)
	var bust := _icon("caesar", 54, Color("6b4422"))
	bust.position = Vector2(21, 18)
	face.add_child(bust)
	h.add_child(face)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	adv_title = _label("", 24, false, C_INK, font_title)
	v.add_child(adv_title)
	adv_text = _label("", 17)
	adv_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	adv_text.custom_minimum_size = Vector2(500, 0)
	v.add_child(adv_text)
	var ok := Button.new()
	ok.text = "Понятно"
	ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	ok.pressed.connect(func(): advisor_panel.visible = false)
	v.add_child(ok)


func advisor(title: String, text: String) -> void:
	adv_title.text = title
	adv_text.text = text
	advisor_panel.visible = true


func _notes() -> void:
	notes_box = VBoxContainer.new()
	_put(notes_box, Control.PRESET_CENTER_TOP, Vector2(0, 10))
	notes_box.custom_minimum_size = Vector2(480, 0)
	notes_box.add_theme_constant_override("separation", 6)
	notes_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(notes_box)


## Событие: короткая плашка наверху (не посреди экрана) и запись в колокольчике
func notify(text: String, icon := "info") -> void:
	var p := _chip(false, 16.0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(_icon(icon, 26, C_SOFT))
	var l := _label(text, 16, true)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(420, 0)
	h.add_child(l)
	p.add_child(h)
	notes_box.add_child(p)
	while notes_box.get_child_count() > 3:
		var o := notes_box.get_child(0)
		notes_box.remove_child(o)
		o.queue_free()
	p.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	tw.tween_interval(5.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)
	if icon in ["check", "level"] and game and game.sound:
		game.sound.ui("done")
	if not events_panel.visible:
		bell_count += 1
		bell_badge.text = str(bell_count)


func _window(title: String, w := 560.0) -> Array:
	var p := _panel(null, "scroll_v", 36, 30)
	_put(p, Control.PRESET_CENTER, Vector2.ZERO)
	p.custom_minimum_size = Vector2(w, 0)
	p.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var hdr := HBoxContainer.new()
	var t := _label(title, 30, false, C_INK, font_title)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_child(t)
	var close := _round("close", "Закрыть", 40, func(): p.visible = false)
	hdr.add_child(close)
	v.add_child(hdr)
	return [p, v, hdr]


func _events_panel() -> void:
	var w := _window("События", 540)
	events_panel = w[0]
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(500, 440)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	(w[1] as VBoxContainer).add_child(sc)
	var list := VBoxContainer.new()
	list.name = "list"
	list.add_theme_constant_override("separation", 6)
	sc.add_child(list)


func _fill_events() -> void:
	bell_count = 0
	bell_badge.text = ""
	var list: VBoxContainer = events_panel.find_child("list", true, false)
	for ch in list.get_children():
		ch.queue_free()
	var ev: Array = game.city.events.duplicate()
	ev.reverse()
	if ev.is_empty():
		list.add_child(_label("Пока ничего не случилось.", 17, false, C_SOFT))
	for e in ev:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.add_child(_icon(e["icon"], 24, C_SOFT))
		h.add_child(_label("День %d" % int(e["day"]), 15, true, C_SOFT))
		var l := _label(e["text"], 16)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(370, 0)
		h.add_child(l)
		list.add_child(h)


# ---------- исследования ----------

func _research_panel() -> void:
	var w := _window("Исследования", 800)
	research_panel = w[0]
	var hdr: HBoxContainer = w[2]
	var rp := HBoxContainer.new()
	rp.add_child(_icon("research", 28, C_SOFT))
	lbl_research_rp = _label("0", 22, true)
	rp.add_child(lbl_research_rp)
	hdr.add_child(rp)
	hdr.move_child(rp, 1)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(760, 560)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	(w[1] as VBoxContainer).add_child(sc)
	research_box = VBoxContainer.new()
	research_box.add_theme_constant_override("separation", 10)
	research_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(research_box)


func _fill_research() -> void:
	if not research_panel.visible:
		return
	var c: City = game.city
	lbl_research_rp.text = "%s / %s" % [fmt(c.rp), fmt(c.rp_cap())]
	for ch in research_box.get_children():
		ch.queue_free()
	for lvl in Defs.LEVELS.size():
		var sec := PanelContainer.new()
		sec.add_theme_stylebox_override("panel", _tex_box("section", 18, 8))
		var sh := HBoxContainer.new()
		sh.alignment = BoxContainer.ALIGNMENT_CENTER
		sh.add_child(_icon("level", 24, C_SOFT))
		sh.add_child(_label(Defs.LEVELS[lvl]["name"], 22, false, C_INK, font_title))
		if lvl > c.level:
			sh.add_child(_icon("lock", 20, C_SOFT))
			sh.add_child(_label("— откроется, когда город станет таким", 14, true, C_SOFT))
		sec.add_child(sh)
		research_box.add_child(sec)
		var grid := HFlowContainer.new()
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		grid.alignment = FlowContainer.ALIGNMENT_CENTER
		research_box.add_child(grid)
		for r in Defs.RESEARCH:
			if int(r["lvl"]) != lvl:
				continue
			var id: String = r["id"]
			var done := c.research.has(id)
			var why := c.can_research(id)
			var cell := VBoxContainer.new()
			cell.custom_minimum_size = Vector2(120, 0)
			cell.add_theme_constant_override("separation", 2)
			var b := _round(r["icon"], "", 64)
			var tip: String = r["name"].to_upper()
			if r.has("desc"):
				tip += "\n" + r["desc"]
			for type in Defs.B:
				if Defs.B[type].get("unlock", "") == id:
					tip += "\nОткрывает: " + Defs.B[type]["name"] + " — " + Defs.B[type]["desc"]
			if r.has("after"):
				tip += "\nПосле: «%s»" % Defs.research(r["after"])["name"]
			tip += "\n\n" + ("Изучено" if done else ("Стоимость: %d очков" % r["cost"]) + ("" if why == "" else "\n" + why))
			b.tooltip_text = tip
			if done:
				_set_on(b, true)
			elif why != "":
				b.modulate = Color(1, 1, 1, 0.55)
			b.pressed.connect(func():
				if game.city.do_research(id):
					_fill_research()
					if tray.visible:
						_fill_cards()
				else:
					notify(game.city.can_research(id), "lock"))
			var bc := CenterContainer.new()
			bc.add_child(b)
			cell.add_child(bc)
			var nl := _label(r["name"], 14, true)
			nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nl.custom_minimum_size = Vector2(118, 0)
			cell.add_child(nl)
			if done:
				var ok := HBoxContainer.new()
				ok.alignment = BoxContainer.ALIGNMENT_CENTER
				ok.add_child(_icon("check", 18, C_GOOD))
				cell.add_child(ok)
			else:
				var cost := HBoxContainer.new()
				cost.alignment = BoxContainer.ALIGNMENT_CENTER
				cost.add_child(_icon("research", 16, C_SOFT))
				cost.add_child(_label(str(r["cost"]), 15, true, C_INK if c.rp >= float(r["cost"]) else C_BAD))
				cell.add_child(cost)
			grid.add_child(cell)



# ---------- финансы, статистика ----------

func _finance_panel() -> void:
	var w := _window("Финансы", 480)
	finance_panel = w[0]
	var v := VBoxContainer.new()
	v.name = "body"
	(w[1] as VBoxContainer).add_child(v)


func _stats_panel() -> void:
	var w := _window("Жители и работники", 540)
	stats_panel = w[0]
	var v := VBoxContainer.new()
	v.name = "body"
	(w[1] as VBoxContainer).add_child(v)


func _fill_finance() -> void:
	var v: VBoxContainer = finance_panel.find_child("body", true, false)
	for ch in v.get_children():
		ch.queue_free()
	var c: City = game.city
	v.add_child(_row("coins", "В казне", "%s / %s" % [fmt(c.money), fmt(c.money_cap())]))
	v.add_child(_row("income", "Налоги в день", "+%s" % fmt(c.stats.get("income", 0.0)), C_GOOD))
	v.add_child(_row("hammer", "Содержание построек в день", "−%s" % fmt(c.stats.get("upkeep", 0.0)), C_BAD))
	v.add_child(_row("research", "Очки исследований", "%s / %s (+%.1f в день)" % [fmt(c.rp), fmt(c.rp_cap()), float(c.stats.get("rp_day", 0.0))]))
	var hint := _label("Налог платит каждый житель: плебей — %.2f, ремесленник — %.2f, патриций — %.2f денария в день; счастливые платят больше. Казна не вмещает больше предела — поднимайте уровень города и изучайте хранилища." % [Defs.CLASSES["plebs"]["tax"], Defs.CLASSES["artisans"]["tax"], Defs.CLASSES["patricians"]["tax"]], 14, false, C_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(400, 0)
	v.add_child(hint)


func _fill_stats() -> void:
	var v: VBoxContainer = stats_panel.find_child("body", true, false)
	for ch in v.get_children():
		ch.queue_free()
	var c: City = game.city
	for cl in Defs.CLASS_ORDER:
		var cd: Dictionary = Defs.CLASSES[cl]
		v.add_child(_label(cd["name"], 19, false, C_INK, font_title))
		v.add_child(_row(cd["icon"], "Жителей", str(int(c.stats["residents"].get(cl, 0)))))
		v.add_child(_row("happy", "Счастье", "%d%%" % int(c.stats.get("class_happy", {}).get(cl, 0)), C_GOOD))
		v.add_child(_row("hammer", "Работники / рабочие места", "%d / %d" % [int(c.stats["workers"].get(cl, 0)), int(c.stats["jobs"].get(cl, 0))]))
		v.add_child(_row("check", "Свободных работников", str(int(c.stats["free"].get(cl, 0)))))




# ---------- меню паузы, настройки, покупка земли ----------

func _pause_panel() -> void:
	var w := _window("Меню", 380)
	pause_panel = w[0]
	var v: VBoxContainer = w[1]
	for t: Array in [["Продолжить", "play", func(): pause_panel.visible = false], ["Сохранить", "save", func(): _save_now()],
			["Настройки", "settings", func(): pause_panel.visible = false; _open_settings()], ["Главное меню", "level", func(): game.restart("menu")], ["Выход", "exit", func(): _quit()]]:
		var b := Button.new()
		b.text = t[0]
		b.icon = ico(t[1], 40)
		b.expand_icon = false
		b.custom_minimum_size = Vector2(320, 54)
		b.add_theme_font_size_override("font_size", 21)
		b.pressed.connect(t[2])
		v.add_child(b)


func _save_now() -> void:
	if game.can_save:
		game.save()
		notify("Город сохранён", "save")
	else:
		notify("Готовый город не сохраняется — начните свой в главном меню", "info")
	pause_panel.visible = false


func _quit() -> void:
	if game.can_save:
		game.save()
	get_tree().quit()


func _settings_panel() -> void:
	var w := _window("Настройки", 520)
	settings_panel = w[0]
	var v: VBoxContainer = w[1]
	v.add_theme_constant_override("separation", 12)
	var mk_slider := func(text: String, icon: String, key: String, lo: float, hi: float, step: float) -> HSlider:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		r.add_child(_icon(icon, 26, C_SOFT))
		var l := _label(text, 18, true)
		l.custom_minimum_size = Vector2(190, 0)
		r.add_child(l)
		var sl := HSlider.new()
		sl.name = key
		sl.min_value = lo
		sl.max_value = hi
		sl.step = step
		sl.custom_minimum_size = Vector2(220, 28)
		sl.value_changed.connect(func(x):
			game.settings[key] = x
			if key == "music" or key == "sfx":
				game.sound.apply_volumes())
		sl.drag_ended.connect(func(_c): game.save_settings())
		r.add_child(sl)
		v.add_child(r)
		return sl
	mk_slider.call("Музыка", "music", "music", 0.0, 1.0, 0.05)
	mk_slider.call("Звуки", "sound", "sfx", 0.0, 1.0, 0.05)
	mk_slider.call("Размер интерфейса", "view", "ui_scale", 0.8, 1.4, 0.05)
	var q := HBoxContainer.new()
	q.add_theme_constant_override("separation", 8)
	q.add_child(_icon("photo", 26, C_SOFT))
	var ql := _label("Графика", 18, true)
	ql.custom_minimum_size = Vector2(190, 0)
	q.add_child(ql)
	for opt: Array in [["high", "Высокая"], ["medium", "Средняя"], ["low", "Низкая"]]:
		var b := Button.new()
		b.text = opt[1]
		b.name = "q_" + opt[0]
		var key: String = opt[0]
		b.pressed.connect(func(): game.settings["quality"] = key; game.save_settings(); _open_settings(true))
		q.add_child(b)
	v.add_child(q)
	var fs := CheckBox.new()
	fs.text = "Полный экран"
	fs.name = "fs"
	fs.add_theme_font_size_override("font_size", 18)
	fs.toggled.connect(func(x): game.settings["fullscreen"] = x; game.save_settings())
	v.add_child(fs)
	var au := CheckBox.new()
	au.text = "Автосохранение"
	au.name = "auto"
	au.add_theme_font_size_override("font_size", 18)
	au.toggled.connect(func(x): game.settings["autosave"] = x; game.save_settings())
	v.add_child(au)
	var nb := Button.new()
	nb.text = "Начать новый город"
	nb.name = "newgame"
	nb.pressed.connect(func():
		if not nb.has_meta("sure"):
			nb.set_meta("sure", true)
			nb.text = "Точно? Прежний город сотрётся — нажмите ещё раз"
			return
		game.new_game())
	v.add_child(nb)
	var credits := _label("Модели — Synty POLYGON Ancient Empire. Музыка — записи Шопена, Шумана и Сати из Викисклада (общественное достояние). Звуки — Kenney и авторы OpenGameArt (CC0). Иконки — game-icons.net (Lorc, Delapouite), CC BY 3.0. Шрифты Philosopher и Alegreya Sans — OFL. Движения людей — Quaternius, CC0.", 14, false, C_SOFT)
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credits.custom_minimum_size = Vector2(460, 0)
	v.add_child(credits)


func _open_settings(stay := false) -> void:
	(settings_panel.find_child("fs", true, false) as CheckBox).set_pressed_no_signal(bool(game.settings["fullscreen"]))
	(settings_panel.find_child("auto", true, false) as CheckBox).set_pressed_no_signal(bool(game.settings["autosave"]))
	for key in ["music", "sfx", "ui_scale"]:
		(settings_panel.find_child(key, true, false) as HSlider).set_value_no_signal(float(game.settings.get(key, 1.0)))
	for q in ["high", "medium", "low"]:
		var b: Button = settings_panel.find_child("q_" + q, true, false)
		b.add_theme_stylebox_override("normal", _tex_box("btn2_on" if game.settings["quality"] == q else "btn2", 20, 14, 20, 8))
	if not stay:
		_toggle(settings_panel)


func _buy_panel() -> void:
	var w := _window("Новая земля", 460)
	buy_panel = w[0]
	var v: VBoxContainer = w[1]
	var l := _label("", 18)
	l.name = "text"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(410, 0)
	v.add_child(l)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 10)
	var ok := Button.new()
	ok.text = "Купить"
	ok.icon = ico("coins", 32)
	ok.pressed.connect(func():
		if game.city.buy_plot(buy_plot):
			game._update_plot_signs()
			buy_panel.visible = false
		else:
			notify("Не хватает денариев", "coins"))
	h.add_child(ok)
	var no := Button.new()
	no.text = "Не сейчас"
	no.pressed.connect(func(): buy_panel.visible = false)
	h.add_child(no)
	v.add_child(h)


func ask_buy(p: Vector2i) -> void:
	buy_plot = p
	(buy_panel.find_child("text", true, false) as Label).text = "Участок 64 × 64 м за краем вашей земли. Купить его за %s денариев? На нём можно будет строить." % fmt(game.city.plot_price())
	buy_panel.visible = true


# ---------- обновление ----------

func refresh() -> void:
	if game == null or game.city == null:
		return
	var c: City = game.city
	lbl_level.text = Defs.LEVELS[c.level]["name"]
	var nx := c.next_level()
	lbl_level.tooltip_text = "Уровень города" if nx.is_empty() else "Следующий уровень «%s»: %d жителей и счастье %d%%" % [nx["name"], nx["pop"], nx["happy"]]
	lbl_pop.text = fmt(c.stats["pop"])
	lbl_happy.text = "%d%%" % int(c.stats["happy"])
	lbl_day.text = "День %d" % (c.day + 1)
	lbl_money.text = "%s / %s" % [fmt(c.money), fmt(c.money_cap())]
	lbl_money.tooltip_text = "Денарии в казне / предел казны"
	var net := float(c.stats.get("income", 0.0)) - float(c.stats.get("upkeep", 0.0))
	lbl_income.text = ("+" if net >= 0 else "") + fmt(net)
	lbl_income.tooltip_text = "Доход за час"
	lbl_income.add_theme_color_override("font_color", C_GOOD if net >= 0 else C_BAD)
	lbl_rp.text = "%s / %s" % [fmt(c.rp), fmt(c.rp_cap())]
	lbl_rp.tooltip_text = "Очки исследований / предел. Дают скрипторий, школа, библиотека"
	lbl_rp_day.text = "+%.1f" % float(c.stats.get("rp_day", 0.0)) if float(c.stats.get("rp_day", 0.0)) > 0.0 else ""
	for sb in speed_btns:
		_set_on(sb[0], is_equal_approx(game.speed, sb[1]))
	_fill_classes()
	_fill_tasks()
	if tray.visible:
		_update_cards()
	if info_panel.visible:
		_fill_info()
	if research_panel.visible:
		lbl_research_rp.text = "%s / %s" % [fmt(c.rp), fmt(c.rp_cap())]
	if finance_panel.visible:
		_fill_finance()
	if stats_panel.visible:
		_fill_stats()
	_update_world_icons()
	_update_pointer()


func _fill_classes() -> void:
	for ch in class_box.get_children():
		ch.queue_free()
	var c: City = game.city
	for cl in Defs.CLASS_ORDER:
		var cd: Dictionary = Defs.CLASSES[cl]
		if not c.unlocked(cd["house"]) and int(c.stats["residents"].get(cl, 0)) == 0:
			continue
		var chip := _chip(false, 14.0)
		chip.tooltip_text = "%s: %d жителей, счастье %d%%, свободных работников %d" % [cd["name"], int(c.stats["residents"].get(cl, 0)), int(c.stats["class_happy"].get(cl, 0)), int(c.stats["free"].get(cl, 0))]
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var med := Control.new()
		med.custom_minimum_size = Vector2(46, 46)
		var bg := TextureRect.new()
		bg.texture = load("res://assets/ui/medal.png")
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		med.add_child(bg)
		var ic := _icon(cd["icon"], 24)
		ic.position = Vector2(11, 10)
		med.add_child(ic)
		h.add_child(med)
		var v1 := VBoxContainer.new()
		v1.add_theme_constant_override("separation", -2)
		v1.add_child(_label(cd["name"], 14, true, C_SOFT))
		var n := _label(str(int(c.stats["residents"].get(cl, 0))), 20, true)
		v1.add_child(n)
		h.add_child(v1)
		var v2 := VBoxContainer.new()
		v2.add_theme_constant_override("separation", 0)
		var hr := HBoxContainer.new()
		hr.add_child(_icon("happy", 20, C_GOOD))
		hr.add_child(_label("%d%%" % int(c.stats["class_happy"].get(cl, 0)), 18, true, C_GOOD))
		v2.add_child(hr)
		var wr := HBoxContainer.new()
		wr.add_child(_icon("hammer", 20, C_SOFT))
		var fr := int(c.stats["free"].get(cl, 0))
		var short := int(c.stats["jobs"].get(cl, 0)) - int(c.stats["workers"].get(cl, 0))
		wr.add_child(_label(("+%d" % fr) if short <= 0 else ("−%d" % short), 18, true, C_INK if short <= 0 else C_BAD))
		v2.add_child(wr)
		h.add_child(v2)
		chip.add_child(h)
		class_box.add_child(chip)


func _fill_tasks() -> void:
	for ch in tasks_box.get_children():
		ch.queue_free()
	var c: City = game.city
	var goals := c.active_goals(3)
	tasks_panel.visible = not goals.is_empty() and game.mode != "demo"
	if goals.is_empty():
		return
	var hdr := HBoxContainer.new()
	hdr.alignment = BoxContainer.ALIGNMENT_CENTER
	hdr.add_child(_icon("scroll", 26, C_SOFT))
	hdr.add_child(_label("Задания", 22, false, C_INK, font_title))
	tasks_box.add_child(hdr)
	var first := true
	for g in goals:
		var prog := mini(c.goal_progress(g["id"]), int(g["need"]))
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(292, 58)
		b.tooltip_text = g.get("hint", g["text"]) + "\nНаграда: %d ден.%s" % [g["money"], (", %d оч. исследований" % g["rp"]) if int(g["rp"]) > 0 else ""]
		var h := HBoxContainer.new()
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_theme_constant_override("separation", 8)
		var med := Control.new()
		med.custom_minimum_size = Vector2(40, 40)
		med.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var bg := TextureRect.new()
		bg.texture = load("res://assets/ui/medal_on.png" if first else "res://assets/ui/medal.png")
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		med.add_child(bg)
		var ic := _icon(g.get("icon", "check"), 20, C_INK)
		ic.position = Vector2(10, 9)
		med.add_child(ic)
		h.add_child(med)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var t := _label(g["text"], 16, true)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size = Vector2(230, 0)
		v.add_child(t)
		var pr := HBoxContainer.new()
		var bar := ProgressBar.new()
		bar.max_value = int(g["need"])
		bar.value = prog
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(180, 9)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bgs := StyleBoxFlat.new()
		bgs.bg_color = Color(0.48, 0.3, 0.16, 0.25)
		bgs.set_corner_radius_all(4)
		var fgs := StyleBoxFlat.new()
		fgs.bg_color = C_GOOD
		fgs.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("background", bgs)
		bar.add_theme_stylebox_override("fill", fgs)
		pr.add_child(bar)
		pr.add_child(_label("%d/%d" % [prog, int(g["need"])], 14, true, C_SOFT))
		v.add_child(pr)
		h.add_child(v)
		b.add_child(h)
		var gg: Dictionary = g
		b.pressed.connect(func():
			if gg.has("hint"):
				advisor(gg["text"], gg["hint"])
			if gg.has("tool"):
				select_build(gg["tool"]))
		tasks_box.add_child(b)
		first = false


func toggle_pause() -> void:
	if game.speed > 0.0:
		paused_speed = game.speed
		set_speed(0.0)
	else:
		set_speed(paused_speed)


func set_speed(s: float) -> void:
	game.speed = s
	refresh()


# ---------- значки над постройками (нет работников, нет склада, ждут жильё) ----------

var _badges := {}


func _badge(name: String) -> Texture2D:
	if _badges.has(name):
		return _badges[name]
	var bg := Image.load_from_file(ProjectSettings.globalize_path("res://assets/ui/medal_on.png"))
	bg.resize(96, 96, Image.INTERPOLATE_BILINEAR)
	var ic := Image.new()
	ic.load_svg_from_string(FileAccess.get_file_as_string("res://assets/ui/icons/%s.svg" % name), 56.0 / 512.0)
	ic.convert(Image.FORMAT_RGBA8)
	for y in ic.get_height():
		for x in ic.get_width():
			var px := ic.get_pixel(x, y)
			ic.set_pixel(x, y, Color(C_INK.r, C_INK.g, C_INK.b, px.a))
	bg.convert(Image.FORMAT_RGBA8)
	bg.blend_rect(ic, Rect2i(0, 0, ic.get_width(), ic.get_height()), Vector2i(20, 17))
	var t := ImageTexture.create_from_image(bg)
	_badges[name] = t
	return t


func _update_world_icons() -> void:
	var want := {}
	var c: City = game.city
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		var d := c.def(b)
		var icon := ""
		if d["kind"] == "shop" and not b.get("active", true):
			icon = {"store": "warehouse", "good": "wheat", "road": "road"}.get(b.get("why", ""), "hammer")
		elif d["kind"] in ["rp", "farm", "store", "monument"] and d.has("jobs") and float(b.get("staff", 1.0)) < 0.99:
			icon = "hammer"
		elif d["kind"] == "center" and c.waiting > 0:
			icon = "keys"
		elif c.is_house(b) and int(b["pop"]) == 0:
			icon = "family"
		if icon != "":
			want[id] = icon
	for id in world_icons.keys():
		if not want.has(id) or world_icons[id][1] != want[id]:
			(world_icons[id][0] as Node).queue_free()
			world_icons.erase(id)
	for id in want:
		if world_icons.has(id):
			continue
		var b: Dictionary = c.buildings[id]
		var s := Sprite3D.new()
		s.texture = _badge(want[id])
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.pixel_size = 0.012
		s.no_depth_test = true
		s.render_priority = 10
		var top := 4.0 + (int(b["tier"]) * 3.0 if c.is_house(b) else 2.0)
		s.position = Vector3(b["pos"].x, float(b["y"]) + top, b["pos"].y)
		game.add_child(s)
		world_icons[id] = [s, want[id]]




# ---------- стартовое меню ----------

func show_menu(has_save: bool) -> void:
	root.visible = false
	menu_root = Control.new()
	menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_root.theme = theme_main
	add_child(menu_root)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _tex_box("scroll_v", 36, 34))
	_put(p, Control.PRESET_TOP_LEFT, Vector2(110, 120))
	p.custom_minimum_size = Vector2(400, 0)
	menu_root.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	var crest := Control.new()
	crest.custom_minimum_size = Vector2(130, 100)
	crest.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var wr := TextureRect.new()
	wr.texture = load("res://assets/ui/wreath.png")
	wr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wr.set_anchors_preset(Control.PRESET_FULL_RECT)
	crest.add_child(wr)
	var eagle := _icon("eagle", 52, Color("8a5a22"))
	eagle.position = Vector2(39, 22)
	crest.add_child(eagle)
	v.add_child(crest)
	var title := _label("CivCity", 60, false, C_INK, font_title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := _label("Уютный римский город", 19, true, C_SOFT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var mk := func(text: String, icon: String, cb: Callable) -> Button:
		var b := Button.new()
		b.text = text
		b.icon = ico(icon, 44)
		b.custom_minimum_size = Vector2(320, 60)
		b.add_theme_font_size_override("font_size", 24)
		b.add_theme_font_override("font", font_bold)
		b.pressed.connect(cb)
		v.add_child(b)
		return b
	mk.call("Играть", "play", func(): _menu_go("play" if has_save else "new"))
	mk.call("Настройки", "settings", func(): _menu_settings())
	mk.call("Выход", "exit", func(): get_tree().quit())
	var foot := _label("Колёсико — масштаб · зажатое колёсико — вращать · правая кнопка — двигать", 16, true, C_CREAM)
	foot.add_theme_color_override("font_outline_color", Color("3a2412"))
	foot.add_theme_constant_override("outline_size", 6)
	_put(foot, Control.PRESET_BOTTOM_LEFT, Vector2(110, -40))
	menu_root.add_child(foot)
	_hook_buttons(menu_root)


## Настройки из главного меню: меню прячется, пока открыто окно (иначе оно перехватывало щелчки)
func _menu_settings() -> void:
	menu_root.visible = false
	root.visible = true
	for ch in root.get_children():
		(ch as CanvasItem).visible = ch == settings_panel
	_open_settings(true)
	settings_panel.visible = true
	if not settings_panel.visibility_changed.is_connected(_menu_settings_closed):
		settings_panel.visibility_changed.connect(_menu_settings_closed)


func _menu_settings_closed() -> void:
	if game.mode == "menu" and not settings_panel.visible and menu_root:
		root.visible = false
		menu_root.visible = true


func _menu_go(m: String) -> void:
	var l := _label("Загрузка…", 32, false, C_CREAM, font_title)
	l.add_theme_color_override("font_outline_color", Color("3a2412"))
	l.add_theme_constant_override("outline_size", 8)
	l.set_anchors_preset(Control.PRESET_CENTER)
	menu_root.add_child(l)
	await get_tree().process_frame
	await get_tree().process_frame
	game.restart(m)


# ---------- картинки построек для карточек ----------

func _make_icons() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(200, 168)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("f3e6cf")
	e.ambient_light_energy = 0.85
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.2
	we.environment = e
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.light_energy = 2.2
	sun.light_color = Color("fff0d8")
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 30
	vp.add_child(cam)
	var holder := Node3D.new()
	vp.add_child(holder)
	_icons_async(vp, cam, holder)


func _icons_async(vp: SubViewport, cam: Camera3D, holder: Node3D) -> void:
	var col := 0
	for type in Defs.B:
		if type == "center":
			continue
		var d: Dictionary = Defs.B[type]
		var tier := 2 if d["kind"] == "house" else 0
		col = (col + 3) % Defs.PALETTE.size()
		var g := Parts.ghost(Catalog.make(type, tier, 0, col), "outline", Color(0, 0, 0, 0))
		for gi: GeometryInstance3D in g.find_children("*", "GeometryInstance3D", true, false):
			gi.material_override = null
		holder.add_child(g)
		var box := Artisau.aabb(g)
		var c := box.get_center()
		var rad := maxf(0.6, box.size.length() * 0.5)
		var dir := Vector3(0.62, 0.6, 0.95).normalized()
		cam.look_at_from_position(c + dir * rad / sin(deg_to_rad(15.0)) * 0.95, c, Vector3.UP)
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		icons[type] = ImageTexture.create_from_image(vp.get_texture().get_image())
		g.queue_free()
		await get_tree().process_frame
	vp.queue_free()
	if tray.visible:
		_update_cards()

