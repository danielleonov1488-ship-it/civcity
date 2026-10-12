class_name Hud
extends CanvasLayer
## Интерфейс в римском духе — рисованный набор владельца (assets/ui/ai): резные рамки с меандром, свитки
## с валиками, бронзовые медальоны с цветными иконками, табличка с орлом и лентой названия города. Устроен как в Town to City:
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
var _medals := {}
var _grey_mat: ShaderMaterial

const AI := "res://assets/ui/ai/"     # рисованный интерфейс (иконки, рамки, медальоны, значки)
const CARD := Vector2(128, 176)       # карточка постройки в свитке стройки
const PLATE := Vector2(264, 70)       # табличка с названием города (картинка 640×169)
const TASKS_Y := 128                  # просьбы горожан (и карточка обучения) — под табличкой города
const BAR_H := 92                     # высота нижних полос: окна инструментов встают над ними
const MIN_W := 1300.0                 # интерфейс не крупнее, чем помещается в 1300 точек по ширине
const FAM_Y := 70                     # семьи на площади — под фишками классов, справа от таблички
const NOTES_Y := 68                   # всплывашки — под фишками классов (сдвигаются вправо от значков семей)
const ADV_Y := 136                    # советник — ниже значков семей

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
var city_card: Control
var top_panel: Control
var fam_box: HBoxContainer            # семьи на площади ждут жилья (как очередь поезда в Town to City)
var _fam_known := {}
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
var open_dsub := "plants"             # вкладка украшений
var tray_dtabs: HBoxContainer
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
var world_icons := {}                 # id постройки → значок беды
var badge_layer: Control              # значки над постройками: всегда одного размера на экране (как в Town to City)
var badges := {}                      # ключ → {pos, icon, n}
var paused_speed := 1.0
var hidden_ui := false
var bell_count := 0
var bell_badge: Label
var pointer: TextureRect
var pointer_target: Control
var pointer_text: Label
var credits_panel: PanelContainer         # титры: кто и что сделал для игры
var hover_tip: PanelContainer             # мгновенная подсказка у плашки города и фишек классов
var hover_box: VBoxContainer
var hover_src: Control                    # над чем сейчас мышь
var hover_level: Control                  # зоны плашки города: уровень, жители, счастье
var hover_pop: Control
var hover_happy: Control
var _cursor_key := ""                     # какой курсор стоит сейчас (стрелка, рука, молоток, кирка, поворот)
var _cursor_px := 0


func _ready() -> void:
	layer = 10
	_fonts()
	theme_main = _theme()
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme_main
	root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(root)
	_badge_layer()
	_city_card()
	_class_chips()
	_families()
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
	_credits_panel()
	_buy_panel()
	_pointer()
	_hover_tip_panel()
	apply_scale(float(game.settings.get("ui_scale", 1.0)))
	get_window().size_changed.connect(func(): apply_scale(float(game.settings.get("ui_scale", 1.0))))
	get_tree().node_added.connect(_on_node_added)
	_hook_buttons(self)
	_make_icons()


## Размер интерфейса из настроек, но не крупнее, чем помещается по ширине окна (MIN_W логических точек):
## иначе нижние полосы и кнопки наверху наезжают друг на друга
func apply_scale(s: float) -> void:
	var ws := Vector2(get_window().size)
	if ws.x < 64.0 or ws.y < 64.0:
		get_window().content_scale_factor = clampf(s, 0.7, 1.6)
		return
	var st := minf(ws.x / 1600.0, ws.y / 900.0)          # растяжение canvas_items от базовых 1600×900
	var top := minf(1.6, ws.x / (st * MIN_W))
	get_window().content_scale_factor = clampf(s, 0.7, maxf(0.7, top))


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
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND      # над кнопкой — курсор-«рука»
	b.pressed.connect(func():
		if game and game.sound:
			game.sound.ui("click"))


# ---------- оформление ----------

func _fonts() -> void:
	font = _lining(load("res://assets/fonts/AlegreyaSans-Bold.ttf"))
	font_bold = _lining(load("res://assets/fonts/AlegreyaSans-ExtraBold.ttf"))
	font_title = load("res://assets/fonts/Philosopher-Bold.ttf")


## Цифры одной высоты и ширины (у Alegreya по умолчанию «старинные»: 0 похож на «о», часы дёргаются)
func _lining(f: Font) -> Font:
	var v := FontVariation.new()
	v.base_font = f
	var ts := TextServerManager.get_primary_interface()
	v.opentype_features = {ts.name_to_tag("lnum"): 1, ts.name_to_tag("tnum"): 1}
	return v


## Рисованная рамка 9-slice: поля картинки m и поля текста cm — [слева, сверху, справа, снизу].
## Поля замерены по картинкам (углы, валики и розетки не растягиваются); tile — края плиткой (меандр)
func _ai_box(name: String, m: Array, cm: Array, tile := false) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load(AI + name + ".png")
	s.texture_margin_left = m[0]
	s.texture_margin_top = m[1]
	s.texture_margin_right = m[2]
	s.texture_margin_bottom = m[3]
	s.content_margin_left = cm[0]
	s.content_margin_top = cm[1]
	s.content_margin_right = cm[2]
	s.content_margin_bottom = cm[3]
	if tile:
		s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return s


## Резная рамка с меандром и розетками по углам — окна (рамка 21 px)
func _box_panel(pad := 8.0) -> StyleBoxTexture:
	return _ai_box("g_panel", [46, 46, 45, 47], [21 + pad, 20 + pad, 21 + pad, 21 + pad], true)


## Та же рамка потоньше (10 px) — полосы внизу экрана, панели инструментов
func _box_bar(pad := 4.0) -> StyleBoxTexture:
	return _ai_box("g_panel_xs", [23, 23, 22, 24], [10 + pad, 9 + pad, 10 + pad, 13 + pad], true)


## Вертикальный свиток: валики сверху и снизу (просьбы, карточка постройки, главное меню).
## Пергамент начинается на 31-й точке под верхним валиком и кончается за 32 точки до низа, по бокам — с 27-й
func _box_scroll_v(pad := 10.0) -> StyleBoxTexture:
	return _ai_box("g_scroll_v", [34, 33, 34, 36], [27 + pad, 28 + pad * 0.5, 27 + pad, 32 + pad * 0.5])


## Горизонтальный свиток: валики слева и справа (стройка, советник, обучение)
func _box_scroll_h(pad := 8.0) -> StyleBoxTexture:
	return _ai_box("g_scroll_h", [45, 58, 45, 63], [44 + pad * 1.5, 26 + pad, 44 + pad * 1.5, 29 + pad])


## Плашка — длинная бронзовая кнопка (кнопки, фишки, всплывашки, подсказки)
func _box_pill(h := 16.0, v := 6.0, name := "g_btn") -> StyleBoxTexture:
	return _ai_box(name, [22, 12, 22, 12], [h, v, h, v])


## Бронзовый медальон под размер кнопки; у «нажатого» свечение выходит за край (рамка совпадает с обычным)
func _medal(name: String, size: float) -> StyleBoxTexture:
	var key := "%s:%d" % [name, int(size)]
	if _medals.has(key):
		return _medals[key]
	var s := StyleBoxTexture.new()
	s.texture = load(AI + name + ".png")
	if name == "medal_on":
		var e := size * 0.077
		s.expand_margin_left = e
		s.expand_margin_right = e
		s.expand_margin_top = e
		s.expand_margin_bottom = e
	_medals[key] = s
	return s


func _theme() -> Theme:
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 18
	t.set_stylebox("panel", "PanelContainer", _box_panel())
	t.set_stylebox("normal", "Button", _box_pill())
	t.set_stylebox("hover", "Button", _box_pill(16, 6, "g_btn_hover"))
	t.set_stylebox("pressed", "Button", _box_pill(16, 6, "g_btn_on"))
	t.set_stylebox("hover_pressed", "Button", _box_pill(16, 6, "g_btn_on"))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	var dis := _box_pill()
	dis.modulate_color = Color(0.85, 0.82, 0.78, 0.8)
	t.set_stylebox("disabled", "Button", dis)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", C_INK)
	t.set_color("font_disabled_color", "Button", Color(C_INK, 0.45))
	# иконки на кнопках рисованные и цветные — не красим
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		t.set_color(c, "Button", Color.WHITE)
	t.set_color("icon_disabled_color", "Button", Color(1, 1, 1, 0.45))
	t.set_constant("h_separation", "Button", 8)
	t.set_color("font_color", "Label", C_INK)
	t.set_stylebox("panel", "TooltipPanel", _box_pill(16, 10))
	t.set_color("font_color", "TooltipLabel", C_INK)
	t.set_font("font", "TooltipLabel", font)
	t.set_font_size("font_size", "TooltipLabel", 17)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "CheckBox", C_INK)
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		t.set_stylebox(st, "CheckBox", StyleBoxEmpty.new())
	var on: Texture2D = load(AI + "g_check_on.png")
	var off: Texture2D = load(AI + "g_check_off.png")
	t.set_icon("checked", "CheckBox", on)
	t.set_icon("unchecked", "CheckBox", off)
	t.set_icon("checked_disabled", "CheckBox", on)
	t.set_icon("unchecked_disabled", "CheckBox", off)
	t.set_constant("h_separation", "CheckBox", 8)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "OptionButton", C_INK)
	# полосы прокрутки: тот же пергаментный жёлоб в бронзовой кайме, бегунок — золотой (как у ползунка)
	var hs := _ai_box("g_slider", [8, 0, 8, 0], [0, 7, 0, 7])
	var hg := _ai_box("g_slider_fill", [8, 0, 8, 0], [8, 7, 8, 7])
	var hgl := hg.duplicate() as StyleBoxTexture
	hgl.modulate_color = Color(1.12, 1.08, 1.0)
	t.set_stylebox("scroll", "HScrollBar", hs)
	t.set_stylebox("grabber", "HScrollBar", hg)
	t.set_stylebox("grabber_highlight", "HScrollBar", hgl)
	t.set_stylebox("grabber_pressed", "HScrollBar", hgl)
	var vs := _ai_box("g_slider_v", [0, 8, 0, 8], [7, 0, 7, 0])
	var vg := _ai_box("g_slider_fill_v", [0, 8, 0, 8], [7, 8, 7, 8])
	var vgl := vg.duplicate() as StyleBoxTexture
	vgl.modulate_color = Color(1.12, 1.08, 1.0)
	t.set_stylebox("scroll", "VScrollBar", vs)
	t.set_stylebox("grabber", "VScrollBar", vg)
	t.set_stylebox("grabber_highlight", "VScrollBar", vgl)
	t.set_stylebox("grabber_pressed", "VScrollBar", vgl)
	for sbn in ["HScrollBar", "VScrollBar"]:
		t.set_stylebox("scroll_focus", sbn, StyleBoxEmpty.new())
	t.set_constant("scrollbar_h_separation", "ScrollContainer", 4)
	t.set_constant("scrollbar_v_separation", "ScrollContainer", 6)
	# ползунок: пергаментный жёлоб в бронзовой кайме, заполненная часть — золотая, ручка — бронзовая с лавром
	t.set_stylebox("slider", "HSlider", _ai_box("g_slider", [8, 0, 8, 0], [0, 8, 0, 8]))
	var fill := _ai_box("g_slider_fill", [8, 0, 8, 0], [0, 8, 0, 8])
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var knob: Texture2D = load(AI + "g_knob.png")
	t.set_icon("grabber", "HSlider", knob)
	t.set_icon("grabber_highlight", "HSlider", knob)
	t.set_icon("grabber_disabled", "HSlider", knob)
	return t


## Есть ли рисованная (цветная) иконка
func painted(name: String) -> bool:
	return ResourceLoader.exists(AI + "icons/%s.png" % name)


## Иконка нужного размера: рисованная PNG из assets/ui/ai/icons (цветная — не красится),
## иначе белая SVG из assets/ui/icons (красится через modulate)
func ico(name: String, size := 64) -> Texture2D:
	var key := "%s:%d" % [name, size]
	if _ico.has(key):
		return _ico[key]
	var tex: Texture2D = null
	var png := AI + "icons/%s.png" % name
	if ResourceLoader.exists(png):
		var img := (load(png) as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		img.clear_mipmaps()
		img.convert(Image.FORMAT_RGBA8)
		var px := clampi(size, 8, img.get_width())
		if px != img.get_width():
			img.resize(px, px, Image.INTERPOLATE_LANCZOS)
		img.generate_mipmaps()
		tex = ImageTexture.create_from_image(img)
	else:
		var path := "res://assets/ui/icons/%s.svg" % name
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


## Иконка: рисованная — в своих цветах; белая SVG (если рисованной нет) — цветом col
func _icon(name: String, size := 22, col := C_INK) -> TextureRect:
	var r := TextureRect.new()
	r.texture = ico(name, mini(128, size * 2))
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.modulate = Color.WHITE if painted(name) else col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Картинка из рисованного набора (портрет, табличка, логотип…) с сохранением пропорций
func _pic(name: String, size: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load(AI + name)
	r.custom_minimum_size = size
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Портрет класса жителей в бронзовом медальоне
func _cls_pic(cl: String, size: float) -> TextureRect:
	return _pic("class_%s.png" % cl, Vector2(size, size))


## Серый «неактивный» вид: замок, нет лавки рядом, нельзя изучить
func _grey(c: CanvasItem, on := true) -> void:
	if not on:
		c.material = null
		return
	if _grey_mat == null:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV) * COLOR;\n\tfloat g = dot(c.rgb, vec3(0.3, 0.59, 0.11));\n\tCOLOR = vec4(mix(c.rgb, vec3(g) * vec3(1.03, 0.98, 0.9), 0.88), c.a * 0.7);\n}\n"
		_grey_mat = ShaderMaterial.new()
		_grey_mat.shader = sh
	c.material = _grey_mat


## Тонкий бронзовый разделитель с лавровой розеткой
func _divider(h := 22.0) -> TextureRect:
	var d := _pic("divider.png", Vector2(0, h))
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return d


## Бронзовый медальон с иконкой посередине (иконка всегда внутри круга)
func _round(name: String, tip: String, size := 56, cb: Callable = Callable()) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	for st: Array in [["normal", "medal"], ["hover", "medal_hover"], ["pressed", "medal_on"], ["hover_pressed", "medal_on"], ["disabled", "medal_lock"]]:
		b.add_theme_stylebox_override(st[0], _medal(st[1], size))
	# у круглых рисованных значков (глаз, «i», «?», галочка) своё золотое кольцо снято: эмаль становится лицом медальона
	var face := painted(name + "_m")
	var ic := _icon(name + "_m" if face else name, int(size * (0.74 if face else 0.62)))
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	var o := size * (0.135 if face else 0.19)
	ic.offset_left = o
	ic.offset_right = -o
	ic.offset_top = o
	ic.offset_bottom = -o
	ic.name = "ic"
	b.add_child(ic)
	b.set_meta("icon", name)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


## Кнопка-картинка без медальона: у рисованных значков скорости и «закрыть» уже есть свой круг
func _bare(name: String, tip: String, size := 34, cb: Callable = Callable()) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	var e := StyleBoxEmpty.new()
	for st in ["normal", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, e)
	b.add_theme_stylebox_override("hover", _medal("medal_hover", size))
	var ic := _icon(name, size)
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.name = "ic"
	b.add_child(ic)
	b.set_meta("icon", name)
	b.set_meta("bare", true)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


func _set_on(b: Button, on: bool) -> void:
	var s: float = b.custom_minimum_size.x
	if b.has_meta("bare"):
		b.add_theme_stylebox_override("normal", _medal("medal_on", s) if on else StyleBoxEmpty.new())
		(b.get_node("ic") as CanvasItem).modulate = Color.WHITE if on else Color(0.86, 0.82, 0.76)
		return
	b.add_theme_stylebox_override("normal", _medal("medal_on" if on else "medal", s))
	b.add_theme_stylebox_override("hover", _medal("medal_on" if on else "medal_hover", s))


## Медальон с подписью снизу (разделы стройки, инструменты)
func _round_lbl(name: String, text: String, tip: String, size := 60, cb: Callable = Callable()) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -6)
	var b := _round(name, tip, size, cb)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)
	var l := _label(text, 14, true, C_INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	v.set_meta("btn", b)
	return v


## Панель: "panel" — резная рамка (окна), "bar" — рамка потоньше (полосы на экране),
## "scroll_v" / "scroll_h" — свитки; старое имя "papyrus" = "bar". pad — отступ текста от рамки
func _panel(parent: Control = null, tex := "panel", _m := 0.0, pad := -1.0) -> PanelContainer:
	var p := PanelContainer.new()
	var sb: StyleBoxTexture
	match tex:
		"scroll_v":
			sb = _box_scroll_v(10.0 if pad < 0 else pad)
		"scroll_h":
			sb = _box_scroll_h(8.0 if pad < 0 else pad)
		"bar", "papyrus":
			sb = _box_bar(4.0 if pad < 0 else pad)
		_:
			sb = _box_panel(8.0 if pad < 0 else pad)
	p.add_theme_stylebox_override("panel", sb)
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
	c.set_meta("put", [preset, off])


## Godot сам не уменьшает окно, когда содержимого стало меньше: прикрепляем заново — размер станет по содержимому
func _snug(c: Control) -> void:
	if c.has_meta("put"):
		var m: Array = c.get_meta("put")
		_put(c, m[0], m[1])
	else:
		c.reset_size()


## Убрать содержимое сразу (а не в конце кадра), чтобы размер окна пересчитался по новому
func _clear(box: Node) -> void:
	for ch in box.get_children():
		box.remove_child(ch)
		ch.queue_free()


## Ещё раз подогнать окно под содержимое через кадр — когда перенос строк уже посчитан по настоящей ширине
func _refit(c: Control) -> void:
	if c.has_meta("refit"):
		return
	c.set_meta("refit", true)
	await get_tree().process_frame
	if is_instance_valid(c):
		c.remove_meta("refit")
		_snug(c)


## Текст с переносом строк фиксированной ширины. Ширину задаём сразу (а не после раскладки):
## иначе новая надпись нулевой ширины считает себя в одну букву на строку — огромной высоты,
## и окно вытягивается до низа экрана
func _wrap(l: Label, w: float) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(w, 0)
	l.size = Vector2(w, l.size.y)
	return l


## Плашка-фишка (классы, семьи, всплывашки, лавки в карточке дома)
func _chip(dark := false, cm := 10.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box_pill(cm + 6.0, maxf(5.0, cm * 0.5), "g_btn_on" if dark else "g_btn"))
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
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -13)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	city_card = v
	root.add_child(v)
	_put(v, Control.PRESET_TOP_LEFT, Vector2(8, 6))
	# табличка: орёл в лавровом венке и красная лента с названием города
	var plate := _pic("plate.png", PLATE)
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.z_index = 1
	lbl_city = _label("Новый Рим", 20, false, C_CREAM, font_title)
	lbl_city.add_theme_color_override("font_outline_color", Color("4a120c"))
	lbl_city.add_theme_constant_override("outline_size", 6)
	lbl_city.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl_city.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_city.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_city.clip_text = true
	# лента на картинке: x 0.33…0.91, y 0.29…0.71
	lbl_city.offset_left = PLATE.x * 0.335
	lbl_city.offset_right = -PLATE.x * 0.095
	lbl_city.offset_top = PLATE.y * 0.27
	lbl_city.offset_bottom = -PLATE.y * 0.3
	plate.add_child(lbl_city)
	v.add_child(plate)
	# плашка под табличкой: уровень, жители, счастье; день, скорость, время (верх прячется под лентой)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box_pill(13, 4))
	p.size_flags_horizontal = Control.SIZE_SHRINK_END
	p.custom_minimum_size = Vector2(PLATE.x - 20, 0)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -1)
	p.add_child(col)
	var top_gap := Control.new()
	top_gap.custom_minimum_size = Vector2(0, 5)
	col.add_child(top_gap)
	# уровень, жители, счастье: каждая пара «значок + число» — одна зона для подсказки целиком (без щелей между ними)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 0)
	lbl_level = _label("Стоянка", 14, true, C_SOFT)
	hover_level = _hover_zone(row, [lbl_level], _tip_level)
	lbl_pop = _label("0", 16, true)
	hover_pop = _hover_zone(row, [_icon("family", 20), lbl_pop], _tip_pop)
	lbl_happy = _label("0%", 16, true, C_GOOD)
	hover_happy = _hover_zone(row, [_icon("happy", 20), lbl_happy], _tip_happy)
	for z: Control in [hover_level, hover_pop, hover_happy]:
		z.set_meta("tip_anchor", p)            # подсказка встаёт под всей плашкой, не закрывая день и скорость
	col.add_child(row)
	var t := HBoxContainer.new()
	t.alignment = BoxContainer.ALIGNMENT_CENTER
	t.add_theme_constant_override("separation", 3)
	lbl_day = _label("День 1", 14, true, C_SOFT)
	t.add_child(lbl_day)
	for sp: Array in [[0.0, "pause", "Пауза (пробел)"], [1.0, "play", "Обычная скорость (1)"], [2.0, "fastfwd", "Быстро (2)"], [4.0, "fastfwd3", "Очень быстро (3)"]]:
		var sv: float = sp[0]
		var b := _bare(sp[1], sp[2], 26, func(): set_speed(sv))
		t.add_child(b)
		speed_btns.append([b, sv])
	lbl_clock = _label("08:00", 14, true, C_SOFT)
	t.add_child(lbl_clock)
	col.add_child(t)


func _class_chips() -> void:
	class_box = HBoxContainer.new()
	_put(class_box, Control.PRESET_TOP_LEFT, Vector2(PLATE.x + 16, 6))
	class_box.add_theme_constant_override("separation", 6)
	root.add_child(class_box)


## Интерфейс открывается постепенно (как в Town to City): 0 — только стройка, 1 — плашка города и классы,
## 2 — кнопки сверху справа, 3 — всё, включая задания
func ui_level() -> int:
	if game == null or game.city == null:
		return 3
	return int(game.city.tips.get("ui", 3))


func apply_reveal(lvl: int) -> void:
	for x: Control in [city_card, class_box]:
		if x and x.visible != (lvl >= 1):
			x.visible = lvl >= 1
			if x.visible:
				x.modulate.a = 0.0
				x.create_tween().tween_property(x, "modulate:a", 1.0, 0.6)
	if top_panel and top_panel.visible != (lvl >= 2):
		top_panel.visible = lvl >= 2
		if top_panel.visible:
			top_panel.modulate.a = 0.0
			top_panel.create_tween().tween_property(top_panel, "modulate:a", 1.0, 0.6)
	if lvl < 3:
		tasks_panel.visible = false
	# пока плашки города нет, семьи ждут в самом углу
	_put(fam_box, Control.PRESET_TOP_LEFT, Vector2(10, 12) if lvl < 1 else Vector2(PLATE.x + 16, FAM_Y))


func _families() -> void:
	fam_box = HBoxContainer.new()
	_put(fam_box, Control.PRESET_TOP_LEFT, Vector2(PLATE.x + 16, FAM_Y))
	fam_box.add_theme_constant_override("separation", 6)
	fam_box.visible = false
	root.add_child(fam_box)


## Значки семей на площади: щелчок — выбрать им дом
func _fill_families() -> void:
	_clear(fam_box)
	_snug(fam_box)
	var c: City = game.city
	fam_box.visible = not c.arrivals.is_empty() and game.mode != "demo"
	if not fam_box.visible:
		_fam_known = {}
		return
	var chip := _chip(false, 10.0)
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	chip.add_child(h)
	var cap := _label("Ждут\nжилья", 14, true, C_SOFT)
	cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(cap)
	var now := {}
	for f in c.arrivals:
		var nm: String = f["name"]
		var cd: Dictionary = Defs.CLASSES[f["cls"]]
		var home_name: String = Defs.B[cd["house"]]["name"]
		var b := _round("family", "Семья %s · %d чел. · %s\nХотят жить: «%s»\nНажмите и выберите им дом" % [nm, int(f["n"]), cd["name"].to_lower(), home_name], 50,
			func(): game.start_settle(nm))
		if game.tool == "settle" and game.settle_fam.get("name", "") == nm:
			_set_on(b, true)
		var cnt := _label(str(int(f["n"])), 16, true, C_CREAM)
		cnt.add_theme_color_override("font_outline_color", Color("3a2412"))
		cnt.add_theme_constant_override("outline_size", 7)
		cnt.position = Vector2(35, 28)
		b.add_child(cnt)
		if f["cls"] != "plebs":
			var ci := _cls_pic(f["cls"], 24)
			ci.position = Vector2(-6, -6)
			b.add_child(ci)
		h.add_child(b)
		now[nm] = true
		if not _fam_known.has(nm):
			# новая семья — медальон мягко «подпрыгивает»
			b.pivot_offset = Vector2(25, 25)
			b.scale = Vector2(0.6, 0.6)
			var tw := b.create_tween()
			tw.tween_property(b, "scale", Vector2(1.12, 1.12), 0.25).set_trans(Tween.TRANS_BACK)
			tw.tween_property(b, "scale", Vector2.ONE, 0.2)
	_fam_known = now
	fam_box.add_child(chip)



## Повозка впервые встала из-за низкого счастья: объясняет советник (дальше — обычная всплывашка)
func on_arrive_block(text: String) -> void:
	if game.mode == "demo" or game.mode == "menu" or (game.tutorial and game.tutorial.active()):
		notify(text, "happy")
		return
	var c: City = game.city
	var ht: Array = c.stats.get("happy_tips", [])
	var tip := ("\n\nСовет: " + String(ht[0]) + ".") if not ht.is_empty() else ""
	advisor("Новые семьи не едут", ("Первые %d семьи приезжают всегда, а дальше в город переселяются, только если счастье города не ниже %d%%. Сейчас — %d%%, и повозка ждёт на дороге.\n\nНаведите мышь на счастье вверху — там видно, из чего оно складывается и что его поднимет. Как только счастье поднимется, повозка сразу поедет." % [int(_defc("ARRIVE_FREE", 3)), int(_defc("ARRIVE_HAPPY", 60)), int(c.stats.get("happy", 0))]) + tip)


## Советы о приезжих: первая семья; семья, которой негде жить
func on_arrival(f: Dictionary) -> void:
	var c: City = game.city
	if game.mode == "demo" or (game.tutorial and game.tutorial.active()):
		return
	if c.settled_total == 0 and not c.tips.has("first_family"):
		c.tips["first_family"] = true
		advisor("Приехали первые жители!", "Семьи сошли с повозки на площадь у станции и ждут жилья. Нажмите на значок семьи слева вверху — подходящие дома засветятся, — и щёлкните по дому.

Пока семьи ждут, новые не едут: на площади помещается всего несколько семей. Так город растёт постепенно.")
		return
	if c.homes_for(f).is_empty() and not c.tips.has("nohome_" + f["cls"]):
		c.tips["nohome_" + f["cls"]] = true
		var cd: Dictionary = Defs.CLASSES[f["cls"]]
		advisor("Семье негде жить", "Семья %s (%s) ищет «%s», а свободных мест нет. Постройте дом у дороги — семья подождёт на площади." % [f["name"], cd["name"].to_lower(), Defs.B[cd["house"]]["name"]])


func _tasks() -> void:
	tasks_panel = _panel(null, "scroll_v", 0, 4)
	_put(tasks_panel, Control.PRESET_TOP_LEFT, Vector2(8, TASKS_Y))
	tasks_panel.custom_minimum_size = Vector2(328, 0)
	tasks_box = VBoxContainer.new()
	tasks_box.add_theme_constant_override("separation", 4)
	tasks_panel.add_child(tasks_box)


# ---------- мгновенные подсказки: плашка города (уровень, жители, счастье) и фишки классов ----------

const TIP_W := 330.0
var _hover_hold := 0                        # сколько кадров не проверять, ушла ли мышь (после пересборки)


func _hover_tip_panel() -> void:
	hover_tip = _panel(null, "bar", 0, 6)
	hover_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_tip.visible = false
	hover_tip.z_index = 20
	hover_box = VBoxContainer.new()
	hover_box.add_theme_constant_override("separation", 3)
	hover_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_tip.add_child(hover_box)


## Зона подсказки: значок и число вместе (с полями по бокам — между зонами нет «мёртвых» щелей).
## Подсказка открывается сразу, где бы ни была мышь над зоной
func _hover_zone(parent: Control, items: Array, build: Callable) -> Control:
	var z := HBoxContainer.new()
	z.add_theme_constant_override("separation", 3)
	z.custom_minimum_size = Vector2(0, 24)
	z.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for it: Control in items:
		it.mouse_filter = Control.MOUSE_FILTER_IGNORE
		it.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		z.add_child(it)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 5)
	m.add_theme_constant_override("margin_right", 5)
	m.add_child(z)
	parent.add_child(m)
	_hover_on(m, build)
	return m


func _hover_on(c: Control, build: Callable) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.set_meta("tip", build)
	c.mouse_entered.connect(func(): _show_hover(c))
	c.mouse_exited.connect(func():
		if hover_src == c:
			_hide_hover())


func _show_hover(c: Control) -> void:
	hover_src = c
	_fill_hover()


func _hide_hover() -> void:
	hover_src = null
	if hover_tip:
		hover_tip.visible = false


## Пересобрать подсказку (при наведении и при каждом обновлении города — числа живые)
func _fill_hover() -> void:
	if hover_src == null or not is_instance_valid(hover_src) or not hover_src.is_visible_in_tree():
		_hide_hover()
		return
	_clear(hover_box)
	(hover_src.get_meta("tip") as Callable).call(hover_box)
	hover_tip.visible = true
	_hover_hold = 3
	_place_hover()
	_place_hover_later()


func _place_hover() -> void:
	if hover_src == null or not is_instance_valid(hover_src):
		return
	hover_tip.reset_size()
	var r := hover_src.get_global_rect()
	var below := r.end.y
	if hover_src.has_meta("tip_anchor"):
		below = (hover_src.get_meta("tip_anchor") as Control).get_global_rect().end.y
	var p := Vector2(r.position.x - 8.0, below + 4.0)
	p.x = clampf(p.x, 4.0, maxf(4.0, root.size.x - hover_tip.size.x - 4.0))
	hover_tip.position = p


func _place_hover_later() -> void:
	await get_tree().process_frame
	if hover_tip.visible:
		_place_hover()


## Мышь ушла, а сигнал «ушла» не пришёл (фишку пересобрали под мышью) — прячем подсказку сами
func _hover_tick() -> void:
	if hover_tip == null or not hover_tip.visible:
		return
	if hover_src == null or not is_instance_valid(hover_src) or not hover_src.is_visible_in_tree():
		_hide_hover()
		return
	if _hover_hold > 0:
		_hover_hold -= 1                    # пересобранную фишку ещё раскладывают — проверим через пару кадров
		return
	var h := root.get_viewport().gui_get_hovered_control()
	if h != null:
		if h != hover_src and not hover_src.is_ancestor_of(h):
			_hide_hover()
		return
	if not hover_src.get_global_rect().grow(2.0).has_point(hover_src.get_global_mouse_position()):
		_hide_hover()


func _tip_head(v: Control, icon: Variant, text: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 7)
	h.add_child(icon if icon is Control else _icon(String(icon), 28))
	var l := _label(text, 20, false, C_INK, font_title)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	v.add_child(h)


func _tip_text(v: Control, text: String, col := C_SOFT, size := 15, bold := false) -> void:
	v.add_child(_wrap(_label(text, size, bold, col), TIP_W))


## Строка подсказки: значок · подпись · значение; ok = 1 / 0 — галочка или крестик в конце
func _tip_row(v: Control, icon: Variant, text: String, val: String, col := C_INK, ok := -1) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.custom_minimum_size = Vector2(TIP_W, 0)
	if icon is Control:
		h.add_child(icon)
	elif String(icon) != "":
		h.add_child(_icon(String(icon), 22, C_SOFT))
	var l := _label(text, 15)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	var vl := _label(val, 15, true, col)
	vl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(vl)
	if ok >= 0:
		var mk := _icon("check" if ok == 1 else "close", 18)
		mk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(mk)
	v.add_child(h)


static func _plural(n: int, one: String, few: String, many: String) -> String:
	var m := n % 100
	if m >= 11 and m <= 14:
		return many
	match n % 10:
		1:
			return one
		2, 3, 4:
			return few
	return many


## Уровень города → что нужно для следующего и что он даст
func _tip_level(v: VBoxContainer) -> void:
	var c: City = game.city
	_tip_head(v, "level", "Уровень города: «%s»" % Defs.LEVELS[c.level]["name"])
	var nx := c.next_level()
	if nx.is_empty():
		_tip_text(v, "Это высший уровень — ваш город стал Вечным!", C_GOOD, 15, true)
		return
	_tip_text(v, "Следующий уровень — «%s». Нужно:" % nx["name"], C_INK, 15, true)
	var pop := int(c.stats["pop"])
	var hp := int(c.stats["happy"])
	var pop_ok := pop >= int(nx["pop"])
	var hp_ok := hp >= int(nx["happy"])
	_tip_row(v, "family", "Жителей", "%s / %s" % [fmt(pop), fmt(int(nx["pop"]))], C_GOOD if pop_ok else C_BAD, 1 if pop_ok else 0)
	_tip_row(v, "happy", "Счастье города", "%d%% / %d%%" % [hp, int(nx["happy"])], C_GOOD if hp_ok else C_BAD, 1 if hp_ok else 0)
	# пределы — с уже изученными хранилищами (как money_cap/rp_cap), а не голые числа уровня
	_tip_text(v, "На новом уровне казна вмещает %s ден., очков исследований — %s, открываются новые исследования." % [fmt(c.money_cap_for(c.level + 1)), fmt(c.rp_cap_for(c.level + 1))])
	if not pop_ok:
		_tip_text(v, "Жителей прибавится, если строить дома у дорог и заселять приезжих.", C_INK, 14)
	if not hp_ok:
		_tip_text(v, "Счастье поднимают лавки рядом с домами, украшения и памятники — наведите на счастье, там подробнее.", C_INK, 14)


## Жители → по классам, кто ждёт жилья и едет в повозке
func _tip_pop(v: VBoxContainer) -> void:
	var c: City = game.city
	_tip_head(v, "family", "Жители: %s" % fmt(int(c.stats["pop"])))
	for cl in Defs.CLASS_ORDER:
		var cd: Dictionary = Defs.CLASSES[cl]
		var n := int(c.stats["residents"].get(cl, 0))
		if n == 0 and not c.unlocked(cd["house"]):
			continue
		_tip_row(v, _cls_pic(cl, 26), cd["name"], "%s чел." % fmt(n))
	var fam_n := c.arrivals.size()
	var ppl := 0
	for f in c.arrivals:
		ppl += int(f["n"])
	if fam_n > 0:
		_tip_row(v, "tent", "Ждут жилья на площади", "%d %s · %d чел." % [fam_n, _plural(fam_n, "семья", "семьи", "семей"), ppl], C_BAD)
	if not c.pending.is_empty():
		_tip_row(v, "family", "Идут в свой новый дом", "%d %s" % [c.pending.size(), _plural(c.pending.size(), "семья", "семьи", "семей")], C_GOOD)
	if c.incoming > 0:
		_tip_row(v, "horse", "Едут в повозке", "%d %s" % [c.incoming, _plural(c.incoming, "семья", "семьи", "семей")], C_INK)
	var block := String(c.stats.get("arrive_block", ""))
	if block != "":
		_tip_text(v, block, C_BAD, 14, true)
	elif fam_n > 0:
		_tip_text(v, "Нажмите на значок семьи слева вверху и выберите им дом.", C_INK, 14)
	else:
		_tip_text(v, "Повозка привозит новые семьи по большой дороге. Стройте дома у дорог — им будет где жить.", C_SOFT, 14)


## Счастье города → из чего складывается, по классам, что сделать и что оно даёт
func _tip_happy(v: VBoxContainer) -> void:
	var c: City = game.city
	var hp := int(c.stats["happy"])
	_tip_head(v, "happy", "Счастье города: %d%%" % hp)
	var parts: Array = c.stats.get("happy_parts", [])
	if not parts.is_empty():
		_tip_text(v, "Из чего складывается (в среднем на жителя):", C_INK, 14, true)
		var first := true
		for p: Array in parts:
			var val := int(p[1])
			_tip_row(v, "", String(p[0]), ("%d%%" % val) if first else _pct(val), C_INK if first else (C_GOOD if val > 0 else (C_BAD if val < 0 else C_SOFT)))
			first = false
	var shown := 0
	for cl in Defs.CLASS_ORDER:
		if int(c.stats["residents"].get(cl, 0)) > 0:
			shown += 1
	if shown > 1 or parts.is_empty():
		_tip_text(v, "По классам:", C_INK, 14, true)
		for cl in Defs.CLASS_ORDER:
			if int(c.stats["residents"].get(cl, 0)) <= 0:
				continue
			var ch := int(c.stats["class_happy"].get(cl, 0))
			_tip_row(v, _cls_pic(cl, 24), Defs.CLASSES[cl]["name"], "%d%%" % ch, C_GOOD if ch >= 60 else (C_GOLD if ch >= 40 else C_BAD))
	var tips: Array = c.stats.get("happy_tips", [])
	_tip_text(v, "Что сделать:", C_INK, 14, true)
	if tips.is_empty():
		_tip_text(v, "• Лавки нужных видов рядом с домами, украшения между домами и памятники поднимают счастье; теснота и нехватка лавок — опускают.", C_INK, 14)
	for t in tips:
		_tip_text(v, "• " + String(t), C_INK, 14)
	_tip_text(v, "Счастливые жители платят больше налогов, а новые семьи едут, пока счастье города не ниже %d%%. Щёлкните по дому — карточка покажет, чего не хватает именно ему." % int(_defc("ARRIVE_HAPPY", 60)), C_SOFT, 14)


## Фишка класса → жители, счастье, нужды (у скольких домов нет нужной лавки), работа
func _tip_class(v: VBoxContainer, cl: String) -> void:
	var c: City = game.city
	var cd: Dictionary = Defs.CLASSES[cl]
	var n := int(c.stats["residents"].get(cl, 0))
	_tip_head(v, _cls_pic(cl, 40), "%s · %s %s" % [cd["name"], fmt(n), _plural(n, "житель", "жителя", "жителей")])
	var hp := int(c.stats["class_happy"].get(cl, 0))
	_tip_row(v, "happy", "Счастье", "%d%%" % hp, C_GOOD if hp >= 60 else (C_GOLD if hp >= 40 else C_BAD))
	var houses := []
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		if c.is_house(b) and c.def(b)["cls"] == cl:
			houses.append(b)
	_tip_text(v, "Нужно рядом с домом «%s»:" % Defs.B[cd["house"]]["name"], C_INK, 14, true)
	for nd in cd["needs"]:
		var miss := 0
		for b in houses:
			if nd in b.get("missing", []):
				miss += 1
		var txt := "есть у всех" if miss == 0 else "нет у %d из %d" % [miss, houses.size()]
		if houses.is_empty():
			txt = "—"
		_tip_row(v, Defs.NEEDS[nd]["icon"], Defs.NEEDS[nd]["name"], txt, C_GOOD if miss == 0 else C_BAD, -1 if houses.is_empty() else (1 if miss == 0 else 0))
	var jobs := int(c.stats["jobs"].get(cl, 0))
	var workers := int(c.stats["workers"].get(cl, 0))
	var free := int(c.stats["free"].get(cl, 0))
	_tip_row(v, "hammer", "Могут работать", "%d чел." % workers)
	_tip_row(v, "commerce", "Мест для них в лавках и мастерских", "%d" % jobs, C_BAD if jobs > workers else C_INK)
	if jobs > workers:
		_tip_text(v, "Работников не хватает — постройки работают слабее. Заселите больше семей. Лишнее место можно убрать (−) там, где оно меньше всего нужно, например у скриптория: лавка, у которой забрали всех работников, закрывается.", C_BAD, 14)
	elif free > 0:
		_tip_text(v, "Свободны %d — могут работать в новых постройках." % free, C_SOFT, 14)
	_tip_text(v, "Налог: %s ден. в час с жителя — больше, когда жители счастливы." % String.num(float(cd["tax"]), 1).replace(".", ","), C_SOFT, 14)


# ---------- курсор: рисованная стрелка вместо курсора Windows ----------

const CURSOR_HOT := 4.0 / 64.0          # «горячая точка» — кончик стрелки в (4, 4) на картинке 64×64
var _cursor_cache := {}


## Картинка курсора assets/ui/ai/cursor_<key>.png нужного размера (нет своей — стрелка)
func _cursor_image(key: String, px: int) -> Image:
	var ck := "%s:%d" % [key, px]
	if _cursor_cache.has(ck):
		return _cursor_cache[ck]
	var path := AI + "cursor_%s.png" % key
	if not ResourceLoader.exists(path):
		path = AI + "cursor_arrow.png"
	var img: Image = null
	if ResourceLoader.exists(path):
		img = (load(path) as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		img.clear_mipmaps()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(px, px, Image.INTERPOLATE_LANCZOS)
	_cursor_cache[ck] = img
	return img


## Какой курсор нужен сейчас: над окнами — стрелка (над кнопками — «рука»), над городом — по инструменту:
## стройка — молоток, снос — кирка, перенос и заселение — рука, поворот — стрелки по кругу
func _cursor_tick() -> void:
	var px := int(clampf(roundf(30.0 * get_viewport().get_final_transform().get_scale().x), 24.0, 128.0))
	var key := "arrow"
	if game and game.ready_done and root.visible and (menu_root == null or not menu_root.visible) and not mouse_over_ui():
		var t: String = game.tool
		if game.rot_drag or (game.rig and game.rig._orbit):
			key = "rotate"
		elif t == "bulldoze" or t == "erase":
			key = "bulldoze"
		elif t in ["road", "path", "plaza"] or Defs.B.has(t):
			key = "build"
		elif t in ["move", "move_nature", "copy", "settle"]:
			key = "hand"
	if key == _cursor_key and px == _cursor_px:
		return
	if px != _cursor_px:
		var hand := _cursor_image("hand", px)
		if hand:
			Input.set_custom_mouse_cursor(hand, Input.CURSOR_POINTING_HAND, Vector2(px, px) * CURSOR_HOT)
	_cursor_key = key
	_cursor_px = px
	var img := _cursor_image(key, px)
	if img:
		Input.set_custom_mouse_cursor(img, Input.CURSOR_ARROW, Vector2(px, px) * CURSOR_HOT)


# ---------- сверху справа ----------

## Сверху справа — отдельные бронзовые медальоны без общей рамки (как в Town to City), с мягкой тенью под каждым
func _top_right() -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_panel = h
	root.add_child(h)
	_put(h, Control.PRESET_TOP_RIGHT, Vector2(-10, 6))
	var bell := _round("bell", "События города", 48, func(): _toggle(events_panel); _fill_events())
	h.add_child(_shadowed(bell))
	top_btns["bell"] = bell
	bell_badge = _label("", 15, true, C_CREAM)
	bell_badge.add_theme_color_override("font_outline_color", C_BAD)
	bell_badge.add_theme_constant_override("outline_size", 9)
	bell_badge.position = Vector2(35, -4)
	bell.add_child(bell_badge)
	for t: Array in [["research", "research", "Исследования"], ["finance", "finance", "Финансы"], ["stats", "stats", "Жители и работники"],
			["view", "view", "Показать охват лавок"], ["photo", "photo", "Фото: спрятать интерфейс (любая клавиша — вернуть)"], ["menu", "menu", "Меню игры"]]:
		var id: String = t[0]
		var b := _round(t[1], t[2], 48, func(): _top_action(id))
		h.add_child(_shadowed(b))
		top_btns[id] = b


var _shadow_tex: Texture2D


## Медальон на мягкой круглой тени — читается и на светлой траве, и на крышах
func _shadowed(b: Control) -> Control:
	if _shadow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(0.12, 0.07, 0.03, 0.55))
		g.set_color(1, Color(0.12, 0.07, 0.03, 0.0))
		g.add_point(0.62, Color(0.12, 0.07, 0.03, 0.42))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(0.5, 0.0)
		gt.width = 64
		gt.height = 64
		_shadow_tex = gt
	var c := Control.new()
	c.custom_minimum_size = b.custom_minimum_size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := TextureRect.new()
	sh.texture = _shadow_tex
	sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sh.set_anchors_preset(Control.PRESET_FULL_RECT)
	var e := b.custom_minimum_size.x * 0.12
	sh.offset_left = -e
	sh.offset_top = -e + 2.0
	sh.offset_right = e
	sh.offset_bottom = e + 3.0
	c.add_child(sh)
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(b)
	return c



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


## Окно посреди экрана: открывается одно, а свиток стройки и карточка постройки при этом прячутся
func _toggle(p: Control) -> void:
	var was := p.visible
	_close_windows()
	p.visible = not was
	if p.visible:
		_close_tray()
		_hide_info()


func _close_windows() -> void:
	for x in [events_panel, research_panel, finance_panel, stats_panel, pause_panel, settings_panel, buy_panel, credits_panel]:
		if x:
			x.visible = false


## Свиток стройки и карточка постройки не открыты вместе (как в Town to City): одно прячет другое
func _close_tray() -> void:
	if tray and tray.visible:
		open_cat = ""
		tray.visible = false
		_refresh_cat_buttons()


func _hide_info() -> void:
	if info_panel and (info_panel.visible or not info_b.is_empty()):
		info_panel.visible = false
		info_b = {}
		if game:
			game.select_building({})


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
	var p := _panel(null, "bar", 0, 1)
	_put(p, Control.PRESET_BOTTOM_LEFT, Vector2(10, -6))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	for t: Array in [["road", "road", "Мостовая", "Мостовая: каменная улица (R). Ведите с зажатой кнопкой"], ["path", "path", "Тропа", "Тропа: утоптанная дорожка — почти даром"],
			["plaza", "plaza", "Площадь", "Площадь из узорной плитки"], ["erase", "eraser", "Ластик", "Ластик: стереть дорогу"]]:
		var tn: String = t[0]
		var v := _round_lbl(t[1], t[2], t[3], 50, func(): game.set_tool("" if game.tool == tn else tn))
		h.add_child(v)
		road_btns[tn] = v.get_meta("btn")
	# настройки кисти над кнопками
	road_panel = _panel(null, "bar", 0, 6)
	_put(road_panel, Control.PRESET_BOTTOM_LEFT, Vector2(10, -BAR_H - 10))
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
	sl.value = game.brush_r
	sl.value_changed.connect(func(x): game.brush_r = x; refresh_tools())
	sl.name = "size"
	r1.add_child(sl)
	var sv := _label("", 17, true)            # число на ползунке: какой размер кисти сейчас
	sv.name = "size_val"
	sv.custom_minimum_size = Vector2(34, 0)
	r1.add_child(sv)
	vb.add_child(r1)
	var price := _label("", 16, false, C_SOFT)   # сколько стоит метр дороги при этой кисти
	price.name = "price"
	vb.add_child(price)
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
	_refresh_brush()
	_fill_tool_panel()


## Кисть дороги: какой способ и форма выбраны, размер, «поверх других дорог»
func _refresh_brush() -> void:
	if road_btns.has("linefree"):
		_set_on(road_btns["linefree"], not game.brush_line)
		_set_on(road_btns["linestraight"], game.brush_line)
		_set_on(road_btns["brushround"], not game.brush_square)
		_set_on(road_btns["brushsquare"], game.brush_square)
		(road_btns["over"] as CheckBox).set_pressed_no_signal(game.brush_over)
		(road_panel.find_child("size", true, false) as HSlider).set_value_no_signal(game.brush_r)
		(road_panel.find_child("size_val", true, false) as Label).text = ("%.2f" % game.brush_r).trim_suffix("0").replace(".", ",")
		var t: String = game.tool
		var pl := road_panel.find_child("price", true, false) as Label
		if Defs.ROAD_COST.has(t):
			pl.text = "Метр — около %s ден. (полоса %s м)" % [price_txt(road_price_m(t)), ("%.1f" % (game.brush_r * 2.0)).replace(".", ",")]
		else:
			pl.text = "Стирать дорогу — бесплатно" if t == "erase" else ""
		pl.visible = pl.text != ""


func _bottom_center() -> void:
	var p := _panel(null, "bar", 0, 1)
	_put(p, Control.PRESET_CENTER_BOTTOM, Vector2(0, -6))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	for c: Array in Defs.CATS:
		var cid: String = c[0]
		var short: String = {"housing": "Жильё", "commerce": "Лавки", "farming": "Хозяйство", "decor": "Украшения", "special": "Памятники"}.get(cid, c[1])
		var v := _round_lbl(c[2], short, c[1], 54, func(): _toggle_cat(cid))
		h.add_child(v)
		cats[cid] = v.get_meta("btn")
	# свиток с карточками над разделами (разворачивается)
	tray = _panel(null, "scroll_h", 0, 5)
	_put(tray, Control.PRESET_CENTER_BOTTOM, Vector2(0, -BAR_H))

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
		var b := _round(Defs.NEEDS[n]["icon"], Defs.NEEDS[n]["name"], 40, func(): open_sub = nn; _fill_cards())
		b.set_meta("sub", nn)
		tray_tabs.add_child(b)
	tray_dtabs = HBoxContainer.new()
	tray_dtabs.add_theme_constant_override("separation", 4)
	top.add_child(tray_dtabs)
	for ds: Array in Defs.DECOR_SUBS:
		var dn: String = ds[0]
		var b := _round(ds[2], ds[1], 40, func(): open_dsub = dn; _fill_cards())
		b.set_meta("sub", dn)
		tray_dtabs.add_child(b)
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.name = "scroll"
	v.add_child(sc)
	tray_grid = HBoxContainer.new()
	tray_grid.add_theme_constant_override("separation", 10)
	sc.add_child(tray_grid)


func _bottom_right() -> void:
	var p := _panel(null, "bar", 0, 1)
	_put(p, Control.PRESET_BOTTOM_RIGHT, Vector2(-10, -6))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	for t: Array in [["copy", "copy", "Копия", "Копировать постройку (Ctrl+C)"], ["move", "move", "Перенос", "Перенести постройку, дерево или камень (M)"],
			["bulldoze", "demolish", "Снос", "Снос (Delete): постройки, деревья, камни"]]:
		var tn: String = t[0]
		var v := _round_lbl(t[1], t[2], t[3], 48, func(): game.set_tool("" if game.tool == tn else tn))
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
	_hide_info()
	_close_windows()
	_fill_cards()
	_refresh_cat_buttons()
	_unroll()


## Свиток разворачивается из середины
func _unroll() -> void:
	if game and game.sound:
		pass
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
		if cat == "decor" and sub != "" and d.get("sub", "") != sub:
			continue
		out.append(type)
	return out


func _fill_cards() -> void:
	for ch in tray_grid.get_children():
		tray_grid.remove_child(ch)
		ch.queue_free()
	tray_tabs.visible = open_cat == "commerce"
	for b in tray_tabs.get_children():
		_set_on(b, b.get_meta("sub") == open_sub)
	tray_dtabs.visible = open_cat == "decor"
	for b in tray_dtabs.get_children():
		_set_on(b, b.get_meta("sub") == open_dsub)
	var names := {"housing": "Жильё", "commerce": "Лавки и мастерские", "farming": "Хозяйство и науки", "decor": "Украшения", "special": "Памятники"}
	tray_title.text = names.get(open_cat, "")
	if open_cat == "commerce":
		tray_title.text += " · " + Defs.NEEDS[open_sub]["name"]
	if open_cat == "decor":
		for ds: Array in Defs.DECOR_SUBS:
			if ds[0] == open_dsub:
				tray_title.text += " · " + String(ds[1])
	var list := _types_in(open_cat, open_dsub if open_cat == "decor" else open_sub)
	for type in list:
		var d: Dictionary = Defs.B[type]
		var b := Button.new()
		b.custom_minimum_size = CARD
		b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		b.set_meta("type", type)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", _card_box("g_card"))
		b.add_theme_stylebox_override("hover", _card_box("g_card_hover"))
		b.add_theme_stylebox_override("pressed", _card_box("g_card_hover"))
		b.add_theme_stylebox_override("hover_pressed", _card_box("g_card_hover"))
		b.tooltip_text = _card_tip(type)
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 0)
		v.offset_top = 8
		v.offset_left = 11
		v.offset_right = -11
		v.offset_bottom = -30                # снизу — лавровая розетка рамки
		b.add_child(v)
		var nm := _label(d["name"], 14, true, C_INK)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.custom_minimum_size = Vector2(104, 36)
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nm.add_theme_constant_override("line_spacing", -3)
		v.add_child(nm)
		var img := TextureRect.new()
		img.custom_minimum_size = Vector2(104, 80)
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
	var w := minf(1180.0, list.size() * (CARD.x + 10.0) - 10.0)
	_snug(tray)
	# полоса прокрутки (если карточек больше, чем влезает) — ниже лавров карточек
	(tray.find_child("scroll", true, false) as Control).custom_minimum_size = Vector2(w, CARD.y + (20.0 if list.size() * (CARD.x + 10.0) - 10.0 > 1180.0 else 2.0))

	_update_cards()
	_update_pointer()


## Рамка карточки постройки (картинка 128×181, снизу лавровая розетка); у подсвеченной свечение за краем
func _card_box(name: String) -> StyleBoxTexture:
	var key := "card:" + name
	if _medals.has(key):
		return _medals[key]
	var g := 8.0 if name == "g_card_hover" else 0.0
	var s := _ai_box(name, [10 + g, 10 + g, 10 + g, 32 + g], [0, 0, 0, 0])
	s.expand_margin_left = g
	s.expand_margin_right = g
	s.expand_margin_top = g
	s.expand_margin_bottom = g
	_medals[key] = s
	return s


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
		t += "\n\nОткроется %s" % Defs.unlock_text(d["unlock"])
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
			# серая карточка с замком (замок нарисован на рамке)
			var why := Defs.unlock_short(d["unlock"])
			if why == d["name"]:
				why = "Исследование"
			var ln := _label(why, 12, true, C_SOFT)
			ln.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ln.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			ln.custom_minimum_size = Vector2(84, 0)
			pr.add_child(ln)
			var sp := Control.new()                  # справа на рамке нарисован замок
			sp.custom_minimum_size = Vector2(16, 0)
			pr.add_child(sp)
			b.add_theme_stylebox_override("normal", _card_box("g_card_lock"))
			_grey(img)
		else:
			pr.add_child(_icon("coins", 22))
			pr.add_child(_label(fmt(d["cost"]), 18, true, C_INK if c.money >= float(d["cost"]) else C_BAD))
			b.add_theme_stylebox_override("normal", _card_box("g_card"))
			_grey(img, false)


func select_build(type: String) -> void:
	if not Defs.B.has(type):
		return
	var cat: String = Defs.B[type]["cat"]
	if cat == "commerce":
		open_sub = Defs.B[type]["sub"]
	if cat == "decor":
		open_dsub = Defs.B[type].get("sub", open_dsub)
		if tray.visible and open_cat == "decor":
			_fill_cards()
	_hide_info()
	if (open_cat != cat or not tray.visible) and cat != "":
		_close_windows()
		open_cat = cat
		tray.visible = true
		_fill_cards()
		_refresh_cat_buttons()
		_unroll()
	if not game.city.unlocked(type):
		notify("«%s» откроется %s" % [Defs.B[type]["name"], Defs.unlock_text(Defs.B[type]["unlock"])], "lock")
		return
	game.set_tool(type)
	_update_pointer()


# ---------- стрелка-подсказка к заданию ----------

func _pointer() -> void:
	pointer = TextureRect.new()
	pointer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pointer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pointer.texture = ico("arrow_down", 104)          # золотая стрелка с лавром
	pointer.custom_minimum_size = Vector2(52, 52)
	pointer.size = Vector2(52, 52)
	pointer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	if game.tutorial and game.tutorial.active():
		var pt: Array = game.tutorial.pointer()
		pointer_target = pt[0]
		pointer_text.text = pt[1]
		return
	if ui_level() < 3:
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
		"lights":
			pointer_target = _card_or_cat("decor", "lamp_post")
			tip = "Украшения"
		"fam3":
			if game.tool != "settle" and fam_box.visible and fam_box.get_child_count() > 0:
				for x in fam_box.get_child(0).find_children("*", "Button", true, false):
					pointer_target = x
					tip = "Семья"
					break
		"market", "fed6":
			pointer_target = cats.get("commerce")
			tip = "Лавки"
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
		# карточка на другой вкладке — показать на вкладку
		var tabs: HBoxContainer = tray_dtabs if cat == "decor" else (tray_tabs if cat == "commerce" else null)
		if tabs:
			for t in tabs.get_children():
				if t.get_meta("sub", "") == Defs.B[type].get("sub", ""):
					return t
	return cats.get(cat)


func _process(_dt: float) -> void:
	_place_badges()
	_place_notes()
	_cursor_tick()
	_hover_tick()

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
			pointer.position = Vector2(r.get_center().x - 26, (r.position.y - 58 - bob) if above else (r.end.y + 2 + bob))
			if above:
				pointer_text.position = pointer.position + Vector2(26 - pointer_text.size.x / 2.0, -26)
			else:
				# стрелка снизу смотрит вверх: подпись сбоку от неё, чтобы не налезать на окна ниже
				var vw := root.size.x
				var px := pointer.position.x + 50.0
				if px + pointer_text.size.x > vw - 6.0:
					px = pointer.position.x + 2.0 - pointer_text.size.x
				pointer_text.position = Vector2(px, pointer.position.y + 26.0 - pointer_text.size.y / 2.0)



# ---------- панель инструмента (справа над кнопками) ----------

func _tool_panel() -> void:
	tool_panel = _panel(null, "bar", 0, 8)
	_put(tool_panel, Control.PRESET_BOTTOM_RIGHT, Vector2(-10, -BAR_H - 10))
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
	if road_panel.visible:
		_refresh_brush()
	tool_err.text = ""

	_fill_tool_panel()
	_update_pointer()


func _fill_tool_panel() -> void:
	_fill_tool_panel_body()
	tool_err.visible = tool_err.text != ""
	_snug(tool_panel)


func _fill_tool_panel_body() -> void:
	var t: String = game.tool
	tool_panel.visible = t != ""
	_clear(variant_box)
	variant_box.visible = false
	if t == "":
		return
	if t == "settle":
		var f: Dictionary = game.settle_fam
		var cd: Dictionary = Defs.CLASSES[f.get("cls", "plebs")]
		var home_name: String = Defs.B[cd["house"]]["name"]
		tool_title.text = "Семья %s" % f.get("name", "")
		tool_keys.text = "%d чел. · %s. Хотят жить: «%s».\nЩёлкните по светящемуся дому. Правая кнопка — отмена." % [int(f.get("n", 0)), cd["name"].to_lower(), home_name]
		if game.city.homes_for(f).is_empty():
			tool_err.text = "Свободного дома нет — постройте «%s» у дороги. Семья подождёт на площади." % home_name
		else:
			variant_box.visible = true
			var auto := Button.new()
			auto.text = "Выбрать дом за меня"
			auto.pressed.connect(func(): game.settle_auto())
			variant_box.add_child(auto)
		return
	if Defs.B.has(t):
		var d: Dictionary = Defs.B[t]
		tool_title.text = "%s · %s ден." % [d["name"], fmt(d["cost"])]
		var keys := "Повернуть: зажмите левую кнопку и ведите мышь вбок (или Z/X) · правая кнопка — отмена"
		if int(d.get("variants", 1)) > 1:
			keys = "C/V — другой фасад · " + keys
			variant_box.visible = true
			variant_box.add_child(_label("Фасад:", 16, true))
			for i in int(d["variants"]):
				var vi := i
				var b := Button.new()
				b.text = str(i + 1)
				_small(b)
				b.tooltip_text = "Фасад %d" % (i + 1)
				b.pressed.connect(func(): game.tool_variant = vi; game.next_variant = vi; _fill_tool_panel())
				if game.tool_variant == i:
					b.add_theme_stylebox_override("normal", _medal("medal_on", 34))
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
		var keys := {"road": "Каменная улица. Ведите с зажатой левой кнопкой. [ ] — размер, Ctrl+Z — отменить.",
			"path": "Утоптанная тропа — самая дешёвая дорога: ею удобно тянуть длинные улицы к окраинам.", "plaza": "Плитка для площадей у рынков и храмов — самая дорогая.", "erase": "Стирает дорогу под кистью.",
			"bulldoze": "Наведите на постройку, дерево или камень — подсветится красным. Щелчок — снести.", "copy": "Щёлкните по постройке — возьмёте такую же.",
			"move": "Щёлкните по постройке, дереву или камню и поставьте на новое место.", "move_nature": "Поставьте на новое место. Z/X — повернуть."}
		var txt: String = keys.get(t, "")
		if Defs.ROAD_COST.has(t):
			# цена видна сразу: сколько стоит метр при нынешней кисти — у всех трёх видов дороги
			tool_title.text = "%s · около %s ден. за метр" % [names[t], price_txt(road_price_m(t))]
			txt += "\nМетр при кисти %s: тропа ~%s · мостовая ~%s · площадь ~%s ден." % [
				("%.2f" % game.brush_r).trim_suffix("0").replace(".", ","), price_txt(road_price_m("path")), price_txt(road_price_m("road")), price_txt(road_price_m("plaza"))]
		tool_keys.text = txt + "\nПравая кнопка — отмена"


func tool_status(err: String) -> void:
	if tool_err.text != err:
		tool_err.text = err
		tool_err.visible = err != ""
		_snug(tool_panel)


## Цена метра дороги при нынешней кисти: полоса шириной 2r из клеток по 25 см
func road_price_m(t: String) -> float:
	if not Defs.ROAD_COST.has(t):
		return 0.0
	return 2.0 * float(game.brush_r) / Land.CELL / Land.CELL * float(Defs.ROAD_COST[t])


## Цена словами: мелочь — с десятыми, остальное — целыми
func price_txt(v: float) -> String:
	if v < 9.95:
		return ("%.1f" % v).trim_suffix(",0").trim_suffix(".0").replace(".", ",")
	return fmt(v)


var _stroke_lbl: Label
var _stroke_tw: Tween

## Пока ведут кисть: казна меняется сразу, у курсора — сколько стоит этот мазок (или что денег не хватило).
## done — мазок окончен, подпись мягко гаснет
func stroke_live(cost: float, t: String, broke := false, done := false) -> void:
	var c: City = game.city
	lbl_money.text = "%s / %s" % [fmt(c.money), fmt(c.money_cap())]
	if _stroke_lbl == null:
		_stroke_lbl = _label("", 19, true, C_CREAM)
		_stroke_lbl.add_theme_color_override("font_outline_color", Color("3a2412"))
		_stroke_lbl.add_theme_constant_override("outline_size", 8)
		_stroke_lbl.visible = false
		root.add_child(_stroke_lbl)
	if done:
		if _stroke_lbl.visible:
			if _stroke_tw:
				_stroke_tw.kill()
			_stroke_tw = _stroke_lbl.create_tween()
			_stroke_tw.tween_interval(0.9)
			_stroke_tw.tween_property(_stroke_lbl, "modulate:a", 0.0, 0.6)
			_stroke_tw.tween_callback(func(): _stroke_lbl.visible = false)
		return
	if t == "erase" or not Defs.ROAD_COST.has(t):
		_stroke_lbl.visible = false
		return
	if _stroke_tw and _stroke_tw.is_valid():
		_stroke_tw.kill()
	if broke:
		_stroke_lbl.text = "Не хватает денариев · мазок %s ден." % fmt(cost)
		_stroke_lbl.add_theme_color_override("font_color", Color("ffb09a"))
	else:
		_stroke_lbl.text = "Этот мазок: %s ден." % fmt(cost)
		_stroke_lbl.add_theme_color_override("font_color", C_CREAM)
	_stroke_lbl.modulate.a = 1.0
	_stroke_lbl.visible = true
	_stroke_lbl.reset_size()
	var mp: Vector2 = game._mouse_pos if game._mouse_pos.x >= 0.0 else root.get_local_mouse_position()
	_stroke_lbl.position = (mp + Vector2(24, -40)).round()



# ---------- карточка постройки ----------

func _info_panel() -> void:
	info_panel = _panel(null, "scroll_v", 0, 8)
	_put(info_panel, Control.PRESET_TOP_RIGHT, Vector2(-10, 62))
	info_panel.custom_minimum_size = Vector2(370, 0)
	info_panel.visible = false
	info_box = VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 6)
	info_box.custom_minimum_size = Vector2(330, 0)
	info_panel.add_child(info_box)


func open_info(b: Dictionary) -> void:
	_close_tray()
	_close_windows()
	info_b = b
	info_panel.visible = true
	_fill_info()



## Строка «Работники: 2 / 3  [−] [+]» — нанять или уволить
func _hire_row(b: Dictionary) -> HBoxContainer:
	var c: City = game.city
	var mx := c.job_max(b)
	var h := c.hired_of(b)
	var row := _row("hammer", "Работники", "%d / %d · %d%%" % [h, mx, int(float(b.get("staff", 1.0)) * 100.0)], C_GOOD if float(b.get("fill", 1.0)) >= 0.99 and h > 0 else C_BAD)
	row.tooltip_text = "Сколько работников нанять. Чем больше — тем больше домов обслуживает постройка, но каждый работник стоит %.1f ден. в час и нужен жителям ниже классом" % City.WAGE
	var minus := Button.new()
	minus.text = "−"
	_small(minus)
	minus.focus_mode = Control.FOCUS_NONE
	minus.disabled = h <= 0
	minus.tooltip_text = "Уволить работника"
	minus.pressed.connect(func(): c.set_hire(b, h - 1); _fill_info())
	var plus := Button.new()
	plus.text = "+"
	_small(plus)
	plus.focus_mode = Control.FOCUS_NONE
	plus.disabled = h >= mx
	plus.tooltip_text = "Нанять работника"
	plus.pressed.connect(func(): c.set_hire(b, h + 1); _fill_info())
	row.add_child(minus)
	row.add_child(plus)
	return row


## Маленькая круглая кнопка-медальон со знаком (−, +, номер фасада)
func _small(b: Button, w := 34.0) -> void:
	b.custom_minimum_size = Vector2(w, w)
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_font_override("font", font_bold)
	for st: Array in [["normal", "medal"], ["hover", "medal_hover"], ["pressed", "medal_on"], ["hover_pressed", "medal_on"], ["disabled", "medal_lock"]]:
		b.add_theme_stylebox_override(st[0], _medal(st[1], w))


func _row(icon: String, text: String, val: String, col := C_INK) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	r.add_child(_icon(icon, 24, C_SOFT))
	var l := _label(text, 17)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(l)
	r.add_child(_label(val, 18, true, col))
	return r


## Карточку пересобирают при каждом обновлении города (раз в игровой час) — и каждый раз она должна
## сжаться ровно по содержимому: прикрепляем заново сразу и ещё раз через кадр (после переноса строк)
func _fill_info() -> void:
	_fill_info_body()
	_snug(info_panel)
	_refit(info_panel)


func _fill_info_body() -> void:
	_clear(info_box)
	var b := info_b
	if b.is_empty() or not game.city.buildings.has(b["id"]):
		info_panel.visible = false
		return
	var c: City = game.city
	var d := c.def(b)
	# у дома карточка шире: слева — нужды и жильцы, справа — из чего складывается счастье
	var cw := 500.0 if c.is_house(b) else 330.0
	info_box.custom_minimum_size = Vector2(cw, 0)
	info_panel.custom_minimum_size = Vector2(cw + 40.0, 0)
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	var ib := _round(d.get("icon", Defs.CLASSES[d["cls"]]["icon"] if d.has("cls") else "info"), "Сменить цвет" if c.is_house(b) else d["name"], 48)
	if c.is_house(b):
		(ib.get_node("ic") as TextureRect).texture = ico("color", 60)
		ib.pressed.connect(func(): c.recolor(b))
	hdr.add_child(ib)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := _wrap(_label(d["name"], 21, false, C_INK, font_title), cw - 104.0)
	tv.add_child(nm)
	hdr.add_child(tv)
	var close := _bare("close", "Закрыть", 34, func(): close_panels())
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hdr.add_child(close)
	info_box.add_child(hdr)
	info_box.add_child(_divider(18))
	match d["kind"]:
		"house":
			_fill_house(b, d, tv, cw)
		"shop":
			tv.add_child(_label(Defs.NEEDS[d["sub"]]["name"], 14, true, C_SOFT))
			info_box.add_child(_row("happy", "Счастье домам", "+%d%%" % int(d["bonus"]), C_GOOD))
			info_box.add_child(_row("arrow", "Дальность", Defs.WORD[int(d["range"])]))
			info_box.add_child(_row("housing", "Обслуживает домов", "%d из %d" % [int(b.get("served", 0)), int(ceil(float(Defs.CAPACITY[int(d["cap"])]) * float(b.get("staff", 1.0))))]))
			info_box.add_child(_hire_row(b))
			if not b.get("active", true):
				var st_txt := c.idle_text(b)            # нет работников: почему именно (никто не живёт, не тот класс, мало мест)
				var why := {"store": "Нет склада рядом — нечем торговать", "good": "Нет сырья: %s" % {"wheat": "постройте пшеничное поле", "olives": "посадите оливковую рощу", "grapes": "посадите виноградник"}.get(d.get("needs_good", ""), ""),
					"road": "Нет дороги у входа", "staff": "Не работает: " + st_txt}
				var wl := _wrap(_label(why.get(b.get("why", "staff"), "Не работает"), 15, true, C_BAD), cw)
				info_box.add_child(wl)
		"monument":
			info_box.add_child(_row("happy", "Счастье всем вокруг", "+%d%%" % int(d["bonus"]), C_GOOD))
			info_box.add_child(_row("arrow", "Дальность", Defs.WORD[int(d["range"])]))
		"rp":
			info_box.add_child(_row("research", "Очки исследований в час", "+%.1f" % (float(d["rp"]) * float(b.get("staff", 1.0))), C_GOOD))
			info_box.add_child(_hire_row(b))
		"farm":
			info_box.add_child(_row("wheat", "Даёт", {"wheat": "пшеницу", "olives": "оливки", "grapes": "виноград"}[d["makes"]], C_GOOD))
			info_box.add_child(_hire_row(b))
		"store":
			info_box.add_child(_row("arrow", "Разносит товары", Defs.WORD[4]))
			info_box.add_child(_hire_row(b))
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
	if not c.is_house(b):                      # у дома вместо описания — что даёт счастье (см. _fill_house)
		info_box.add_child(_wrap(_label(d["desc"], 14, false, C_SOFT), cw))
	if not d.get("fixed", false):
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		var bd := Button.new()
		bd.text = "Снести"
		bd.icon = ico("demolish", 32)
		bd.pressed.connect(func(): c.remove(b); close_panels())
		h.add_child(bd)
		if not d.get("wall", false):              # украшение на стене не переносится (только снести и повесить заново)
			var bm := Button.new()
			bm.text = "Перенести"
			bm.icon = ico("move", 32)
			# переносим именно эту постройку (не ту, что под курсором за карточкой)
			bm.pressed.connect(func(): game.set_tool("move"); game.start_move(b); close_panels())
			h.add_child(bm)
		info_box.add_child(h)


## Карточка дома (как в Town to City): счастье крупно и что оно даёт; слева — что нужно классу и какая лавка
## закрывает каждую нужду, жильцы; справа — из чего складывается счастье (b["happy_parts"] из City.compute);
## внизу — кнопка «Надстроить этаж» (City.can_buy_floor / buy_floor / floor_price).
## Тело карточки — в прокрутке не выше места над нижней полосой: высокая карточка (патриции, много семей)
## не закрывает казну внизу и не уходит за край экрана; шапка и кнопки «Снести / Перенести» видны всегда
func _fill_house(b: Dictionary, d: Dictionary, tv: VBoxContainer, cw: float) -> void:
	var outer := info_box
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.custom_minimum_size = Vector2(cw, 0)
	var sc := ScrollContainer.new()
	sc.name = "house_scroll"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.follow_focus = false
	sc.add_child(body)
	outer.add_child(sc)
	info_box = body
	_fill_house_body(b, d, tv, cw)
	info_box = outer
	_fit_house_scroll(sc, body)
	_fit_house_scroll_later(sc, body, int(b["id"]))


## Высота прокрутки карточки дома: по содержимому, но не ниже верха нижней полосы (казна, Копия/Перенос/Снос)
func _fit_house_scroll(sc: ScrollContainer, body: Control) -> void:
	if not is_instance_valid(sc) or not is_instance_valid(body):
		return
	var want := body.get_combined_minimum_size().y
	sc.custom_minimum_size.y = 0.0
	var outside := info_panel.get_combined_minimum_size().y      # шапка, кнопки и поля окна
	var room := get_viewport().get_visible_rect().size.y - 62.0 - BAR_H - 10.0 - outside
	sc.custom_minimum_size.y = minf(want, maxf(160.0, room))


## Через кадр (перенос строк уже посчитан) — ещё раз по настоящей высоте; карточку пересобирают каждый
## игровой час — прокрутка остаётся там, где её оставил игрок
func _fit_house_scroll_later(sc: ScrollContainer, body: Control, id: int) -> void:
	await get_tree().process_frame
	if not is_instance_valid(sc):
		return
	_fit_house_scroll(sc, body)
	_snug(info_panel)
	var hs: Array = info_panel.get_meta("house_scroll", [-1, 0])
	for k in 2:
		if int(hs[0]) == id:
			sc.scroll_vertical = int(hs[1])
		if k == 0:
			await get_tree().process_frame
			if not is_instance_valid(sc):
				return
	sc.get_v_scroll_bar().value_changed.connect(func(v: float):
		if is_instance_valid(info_panel):
			info_panel.set_meta("house_scroll", [id, int(v)]))
	if int(hs[0]) != id:
		info_panel.set_meta("house_scroll", [id, 0])


func _fill_house_body(b: Dictionary, d: Dictionary, tv: VBoxContainer, cw: float) -> void:
	var c: City = game.city
	var cl: String = d["cls"]
	var cls: Dictionary = Defs.CLASSES[cl]
	var tier := int(b["tier"])
	var fmax := Defs.floors_max(cl)
	tv.add_child(_label("%s · этаж %d из %d · цвет «%s»" % [cls["name"], tier, fmax, Defs.PALETTE[int(b["color"])]["name"]], 14, true, C_SOFT))
	var hp := int(b["happy"])
	var hcol := C_GOOD if hp >= 60 else (C_GOLD if hp >= 40 else C_BAD)
	# счастье крупно и налог с дома
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	var hi := _icon("happy", 36)
	_grey(hi, hp < 40)
	top.add_child(hi)
	var hl := _label("Счастье %d%%" % hp, 25, true, hcol)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(hl)
	var tax := float(cls["tax"])
	if cl == "patricians" and c.research.has("taxes1"):
		tax *= 1.25
	var inc := int(b["pop"]) * tax * (0.5 + minf(100.0, float(hp)) / 100.0)
	var chip := _chip(false, 10.0)
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.tooltip_text = "Налог с дома за час. Чем счастливее жители, тем больше платят: при 100% — втрое больше, чем при 0%"
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 4)
	ch.add_child(_icon("income", 22))
	ch.add_child(_label("+%s ден. в час" % fmt(inc), 16, true, C_GOOD))
	chip.add_child(ch)
	top.add_child(chip)
	info_box.add_child(top)
	# что даёт счастье — одной строкой
	var why_happy := "Счастливые жители платят больше налогов, а новые семьи едут, пока счастье города не ниже %d%%" % int(_defc("ARRIVE_HAPPY", 60))
	if tier < fmax:
		why_happy += "; при счастье дома от %d%% можно надстроить этаж" % _floor_need(b)
	info_box.add_child(_wrap(_label(why_happy + ".", 14, false, C_SOFT), cw))
	if hp < 25 and int(b["pop"]) > 0:
		info_box.add_child(_wrap(_label("Счастье ниже 25% — семьи скоро начнут уезжать!", 15, true, C_BAD), cw))
	info_box.add_child(_divider(14))
	# две колонки
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	var lw := 250.0
	var rw := cw - lw - 14.0
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 5)
	left.custom_minimum_size = Vector2(lw, 0)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 3)
	right.custom_minimum_size = Vector2(rw, 0)
	cols.add_child(left)
	cols.add_child(right)
	info_box.add_child(cols)
	# слева: нужды класса — значок с галочкой или крестиком и лавка, что её закрывает
	var dat := {"plebs": "Плебеям", "artisans": "Ремесленникам", "patricians": "Патрициям"}
	left.add_child(_label("%s нужно" % dat.get(cl, cls["name"]), 16, true, C_SOFT))
	var pen := int(_defc("MISSING_PENALTY", 10))
	for n in Defs.NEED_ORDER:
		var need: Dictionary = Defs.NEEDS[n]
		var shops := []
		for t in b.get("score", {}):
			if Defs.B[t].get("sub", "") == n:
				shops.append(t)
		var required: bool = n in cls["needs"]
		if shops.is_empty() and not required:
			continue
		var ok := not shops.is_empty()
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		var ib := Control.new()
		ib.custom_minimum_size = Vector2(32, 32)
		ib.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ib.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var ni := _icon(need["icon"], 30)
		_grey(ni, not ok)                       # нет лавки рядом — серая
		ib.add_child(ni)
		var mk := _icon("check" if ok else "close", 17)
		mk.position = Vector2(18, 17)
		ib.add_child(mk)
		r.add_child(ib)
		var nv := VBoxContainer.new()
		nv.add_theme_constant_override("separation", -2)
		nv.add_child(_label(need["name"] + ("" if required else " · не обязательно"), 15, true, C_INK if ok else C_BAD))
		var sub := ""
		if ok:
			var names := []
			for t in shops:
				names.append(Defs.B[t]["name"])
			sub = ", ".join(names)
		else:
			var can := []                        # какие открытые лавки закрыли бы нужду
			for t in Defs.B:
				if Defs.B[t]["kind"] == "shop" and Defs.B[t].get("sub", "") == n and c.unlocked(t):
					can.append("«%s»" % Defs.B[t]["name"])
			# лавка этого вида рядом уже стоит, но не работает или не успевает ко всем — сказать почему
			# (а не «поставьте ещё одну»)
			var near_s := {}
			for sid in c.buildings:
				var s: Dictionary = c.buildings[sid]
				var sd := c.def(s)
				if sd["kind"] != "shop" or sd.get("sub", "") != n or (s["pos"] as Vector2).distance_to(b["pos"]) > c.shop_range(sd):
					continue
				if not s.get("active", true):
					near_s = s                       # неработающая важнее переполненной
					break
				if near_s.is_empty() and int(s.get("served", 0)) >= int(s.get("cap", 0)):
					near_s = s
			r.mouse_filter = Control.MOUSE_FILTER_PASS
			if not near_s.is_empty() and not near_s.get("active", true):
				sub = "«%s» рядом не работает: %s" % [c.def(near_s)["name"], c.idle_text(near_s)]
			elif not near_s.is_empty():
				sub = "«%s» рядом не успевает ко всем (−%d%%)" % [c.def(near_s)["name"], pen]
				r.tooltip_text = "Лавка обслуживает столько домов, сколько позволяют её работники. Наймите ей работников или поставьте рядом ещё одну лавку этого вида"
			elif not can.is_empty():
				sub = "Нет рядом (−%d%%) — поставьте %s" % [pen, can[0]]
				if can.size() > 1:
					r.tooltip_text = "Эту нужду закроет любая из лавок: %s" % ", ".join(can)
			else:
				sub = "Нет рядом (−%d%%) — лавку откроют исследования" % pen
		nv.add_child(_wrap(_label(sub, 13, false, C_SOFT if ok else C_BAD), lw - 38.0))
		r.add_child(nv)
		left.add_child(r)
	# слева: жильцы
	left.add_child(_label("Жильцы · %d из %d мест" % [int(b["pop"]), c.house_cap(b)], 16, true, C_SOFT))
	var fams: Array = b.get("families", [])
	if fams.is_empty():
		left.add_child(_wrap(_label("Пока пусто: семья приедет на повозке — заселите её значком слева вверху", 13, false, C_SOFT), lw))
	# больше четырёх семей (домус патрициев) — первые три строками, остальные одной строкой
	var shown_f := fams if fams.size() <= 4 else fams.slice(0, 3)
	for f in shown_f:
		var fr := HBoxContainer.new()
		fr.add_theme_constant_override("separation", 6)
		fr.add_child(_cls_pic(cl, 26))
		var fl := _label("Семья %s" % f["name"], 15, true)
		fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fl.clip_text = true
		fr.add_child(fl)
		fr.add_child(_label("%d чел." % int(f["n"]), 15, true, C_SOFT))
		left.add_child(fr)
	if fams.size() > shown_f.size():
		var rest := fams.slice(shown_f.size())
		var ppl := 0
		var names := []
		for f in rest:
			ppl += int(f["n"])
			names.append("%s (%d)" % [f["name"], int(f["n"])])
		var more := _label("и ещё %d %s · %d чел." % [rest.size(), _plural(rest.size(), "семья", "семьи", "семей"), ppl], 14, true, C_SOFT)
		more.mouse_filter = Control.MOUSE_FILTER_PASS
		more.tooltip_text = "Семьи: " + ", ".join(names)
		left.add_child(more)
	# справа: из чего складывается счастье
	right.add_child(_label("Из чего счастье", 16, true, C_SOFT))
	var parts: Array = b.get("happy_parts", [])
	if parts.is_empty():
		parts = _happy_parts_old(b, cl)
	var first := true
	for p: Array in parts:
		var v := int(p[1])
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 4)
		var l := _wrap(_label(String(p[0]), 14, false, C_INK), rw - 52.0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		var vl := _label(("%d%%" % v) if first else _pct(v), 15, true, C_INK if first else (C_GOOD if v > 0 else (C_BAD if v < 0 else C_SOFT)))
		vl.custom_minimum_size = Vector2(46, 0)
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		r.add_child(vl)
		right.add_child(r)
		first = false
	var line := ColorRect.new()
	line.color = Color(C_SOFT, 0.45)
	line.custom_minimum_size = Vector2(0, 2)
	right.add_child(line)
	var tr := HBoxContainer.new()
	var tl := _label("Итого", 16, true)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tr.add_child(tl)
	tr.add_child(_label("%d%%" % hp, 17, true, hcol))
	right.add_child(tr)
	# внизу: этаж покупает игрок
	if tier >= fmax:
		info_box.add_child(_wrap(_label("Выше этот дом не строят: этаж %d из %d" % [tier, fmax], 14, false, C_SOFT), cw))
		return
	if not c.has_method("can_buy_floor"):
		var hint := "Надстроит этаж, когда дом полон и счастье не ниже %d%%" % _floor_need(b)
		info_box.add_child(_wrap(_label(hint, 14, false, C_SOFT), cw))
		return
	var price := int(c.call("floor_price", b))
	var why := String(c.call("can_buy_floor", b))
	var fb := Button.new()
	fb.focus_mode = Control.FOCUS_NONE
	fb.text = "Надстроить этаж · %s ден." % fmt(price)
	fb.icon = ico("housing", 36)
	fb.expand_icon = false
	fb.custom_minimum_size = Vector2(cw, 50)
	fb.add_theme_font_size_override("font_size", 21)
	fb.add_theme_font_override("font", font_bold)
	fb.disabled = why != ""
	fb.tooltip_text = why if why != "" else "Ещё %d места — в дом въедет новая семья" % int(cls["per_floor"])
	fb.pressed.connect(func():
		if c.call("buy_floor", b):
			if game.sound:
				game.sound.ui("coins")
			_fill_info())
	info_box.add_child(fb)
	if why != "":
		var wl := _wrap(_label(why, 14, true, C_BAD), cw)
		wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_box.add_child(wl)


## Слагаемые счастья дома по старым полям (если City.compute их ещё не считает)
func _happy_parts_old(b: Dictionary, cl: String) -> Array:
	var out := [["Основа", int(Defs.CLASSES[cl].get("base", 40))]]
	for t in b.get("score", {}):
		out.append([Defs.B[t]["name"], int(b["score"][t])])
	if int(b.get("deco_bonus", 0)) != 0:
		out.append(["Украшения", int(b["deco_bonus"])])
	if float(b.get("monuments", 0.0)) > 0.0:
		out.append(["Памятники", int(b["monuments"])])
	if float(b.get("density", 0.0)) < 0.0:
		out.append(["Теснота", int(b["density"])])
	for n in b.get("missing", []):
		out.append(["Нет лавки: " + String(Defs.NEEDS[n]["name"]).to_lower(), -10])
	return out


## «+5%», «−10%» (настоящий минус)
func _pct(v: int) -> String:
	return ("+%d%%" % v) if v > 0 else (("−%d%%" % -v) if v < 0 else "0%")


## С какого счастья дома можно надстроить следующий этаж
func _floor_need(b: Dictionary) -> int:
	if game.city.has_method("floor_need"):
		return int(game.city.call("floor_need", b))
	return 55 + 12 * (int(b["tier"]) - 1)


var _defs_map := {}


## Число из Defs по имени (если его там нет — запасное), чтобы интерфейс не ломался от переименований
func _defc(name: String, dflt: Variant) -> Variant:
	if _defs_map.is_empty():
		_defs_map = (load("res://scripts/defs.gd") as Script).get_script_constant_map()
	return _defs_map.get(name, dflt)


## Закрыть окна; true — было что закрывать
func close_panels() -> bool:
	var any := info_panel.visible or advisor_panel.visible or buy_panel.visible
	for x in [events_panel, research_panel, finance_panel, stats_panel, pause_panel, settings_panel, credits_panel]:
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
	advisor_panel = _panel(null, "scroll_h", 0, 6)
	_put(advisor_panel, Control.PRESET_CENTER_TOP, Vector2(0, ADV_Y))        # ниже значков семей; всплывашки пока прячутся

	advisor_panel.custom_minimum_size = Vector2(640, 0)
	advisor_panel.visible = false
	advisor_panel.visibility_changed.connect(func(): notes_box.visible = not advisor_panel.visible)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	advisor_panel.add_child(h)
	# советник Марк — портрет в лавровой раме
	var face := _pic("advisor.png", Vector2(100, 100))
	face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(face)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	adv_title = _label("", 23, false, C_INK, font_title)
	v.add_child(adv_title)
	adv_text = _label("", 17)
	adv_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	adv_text.custom_minimum_size = Vector2(440, 0)
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
	_put(notes_box, Control.PRESET_CENTER_TOP, Vector2(0, NOTES_Y))     # под фишками классов, не на них
	notes_box.custom_minimum_size = Vector2(440, 0)
	notes_box.add_theme_constant_override("separation", 5)
	notes_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(notes_box)


## Всплывашки посередине сверху, но не на значках семей слева и не на карточке постройки справа
func _place_notes() -> void:
	if notes_box == null or root == null:
		return
	var w := root.size.x
	var half := maxf(220.0, notes_box.size.x * 0.5)
	var lo := 0.0
	if fam_box.visible and fam_box.get_child_count() > 0:
		lo = fam_box.position.x + fam_box.size.x + 12.0
	var hi := w
	if info_panel.visible:
		hi = info_panel.position.x - 12.0
	var cx := clampf(w * 0.5, lo + half, maxf(lo + half, hi - half))
	var off := roundf(cx - w * 0.5)
	if not is_equal_approx(notes_box.offset_left, off - half) or not is_equal_approx(notes_box.offset_right, off + half):
		notes_box.offset_left = off - half
		notes_box.offset_right = off + half


## Событие: короткая плашка наверху (не посреди экрана) и запись в колокольчике
func notify(text: String, icon := "info") -> void:
	if game and game.tutorial and game.tutorial.active() and icon in ["check", "research", "info"]:
		bell_count += 1                   # во время обучения не мешаем всплывашками — только в колокольчик
		bell_badge.text = str(bell_count)
		return
	var p := _chip(false, 12.0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(_icon(icon, 26, C_SOFT))
	var l := _label(text, 15, true)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(360, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	p.add_child(h)
	notes_box.add_child(p)
	while notes_box.get_child_count() > 2:
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
		pass
	if not events_panel.visible:
		bell_count += 1
		bell_badge.text = str(bell_count)


func _window(title: String, w := 560.0) -> Array:
	var p := _panel(null, "panel", 0, 10)
	_put(p, Control.PRESET_CENTER, Vector2.ZERO)
	p.custom_minimum_size = Vector2(w, 0)
	p.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var hdr := HBoxContainer.new()
	var sp := Control.new()                      # противовес кнопке «закрыть» — заголовок ровно посередине
	sp.custom_minimum_size = Vector2(36, 0)
	hdr.add_child(sp)
	var t := _label(title, 30, false, C_INK, font_title)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_child(t)
	var close := _bare("close", "Закрыть", 36, func(): p.visible = false)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hdr.add_child(close)
	v.add_child(hdr)
	v.add_child(_divider())
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
		h.add_child(_label("День %d" % (int(e["day"]) + 1), 15, true, C_SOFT))
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
	# очки — справа у «закрыть»; слева такой же по ширине противовес, чтобы заголовок стоял ровно над разделителем
	var rp := HBoxContainer.new()
	rp.add_child(_icon("research", 28, C_SOFT))
	lbl_research_rp = _label("0", 22, true)
	rp.add_child(lbl_research_rp)
	rp.add_theme_constant_override("separation", 4)
	rp.alignment = BoxContainer.ALIGNMENT_END
	rp.custom_minimum_size = Vector2(170, 0)
	hdr.add_child(rp)
	hdr.move_child(rp, hdr.get_child_count() - 2)
	(hdr.get_child(0) as Control).custom_minimum_size = Vector2(170 + 36 + 4, 0)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(760, 520)

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
		sec.add_theme_stylebox_override("panel", _box_pill(18, 4, "g_btn_on" if lvl > c.level else "g_btn"))
		var sh := HBoxContainer.new()
		sh.alignment = BoxContainer.ALIGNMENT_CENTER
		sh.add_theme_constant_override("separation", 6)
		sh.add_child(_icon("level", 28, C_SOFT))
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
			var b := _round(r["icon"], "", 60)
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
			# светится то, что можно изучить прямо сейчас; изученное — обычный медальон (ниже галочка);
			# не хватает очков — обычный; закрыто уровнем или порядком — серый
			var locked: bool = int(r["lvl"]) > c.level or (r.has("after") and not c.research.has(r["after"]))
			if not done and why == "":
				_set_on(b, true)
			elif locked and not done:
				b.add_theme_stylebox_override("normal", _medal("medal_lock", 60))
				_grey(b.get_node("ic"))
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
				ok.add_child(_icon("check", 22, C_GOOD))
				cell.add_child(ok)
			else:
				var cost := HBoxContainer.new()
				cost.alignment = BoxContainer.ALIGNMENT_CENTER
				cost.add_child(_icon("research", 20, C_SOFT))
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
	v.add_child(_row("income", "Налоги за час", "+%s" % fmt(c.stats.get("income", 0.0)), C_GOOD))
	v.add_child(_row("hammer", "Содержание построек за час", "−%s" % fmt(c.stats.get("upkeep", 0.0)), C_BAD))
	v.add_child(_row("research", "Очки исследований", "%s / %s (+%.1f в час)" % [fmt(c.rp), fmt(c.rp_cap()), float(c.stats.get("rp_day", 0.0))]))
	var hint := _label("Налог платит каждый житель: плебей — %.2f, ремесленник — %.2f, патриций — %.2f денария в час; счастливые платят больше. Казна не вмещает больше предела — поднимайте уровень города и изучайте хранилища." % [Defs.CLASSES["plebs"]["tax"], Defs.CLASSES["artisans"]["tax"], Defs.CLASSES["patricians"]["tax"]], 14, false, C_SOFT)
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
		var hd := HBoxContainer.new()
		hd.add_theme_constant_override("separation", 8)
		hd.add_child(_cls_pic(cl, 36))
		var hl := _label(cd["name"], 20, false, C_INK, font_title)
		hl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hd.add_child(hl)
		v.add_child(hd)
		v.add_child(_row("family", "Жителей", str(int(c.stats["residents"].get(cl, 0)))))
		v.add_child(_row("happy", "Счастье", "%d%%" % int(c.stats.get("class_happy", {}).get(cl, 0)), C_GOOD))
		v.add_child(_row("hammer", "Работники / рабочие места", "%d / %d" % [int(c.stats["workers"].get(cl, 0)), int(c.stats["jobs"].get(cl, 0))]))
		v.add_child(_row("check", "Свободных работников", str(int(c.stats["free"].get(cl, 0)))))




# ---------- меню паузы, настройки, покупка земли ----------

func _pause_panel() -> void:
	var w := _window("Меню", 380)
	pause_panel = w[0]
	var v: VBoxContainer = w[1]
	for t: Array in [["Продолжить", "play", func(): pause_panel.visible = false], ["Сохранить", "save", func(): _save_now()],
			["Настройки", "settings", func(): pause_panel.visible = false; _open_settings()], ["Титры", "laurels", func(): open_credits()],
			["Главное меню", "level", func(): game.restart("menu")], ["Выход", "exit", func(): _quit()]]:
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


# ---------- титры ----------

## Кто и что сделал для игры (по файлам CREDITS/LICENSE в assets). Разделы: [заголовок, значок, [[что, кто · лицензия], …]]
const CREDITS := [
	["Игра", "laurels", [
		["CivCity — уютный римский город", "замысел, игровой дизайн и решения — команда CivCity"],
		["Программирование, мир, жители и интерфейс", "команда CivCity вместе с Claude (Anthropic)"]]],
	["Город и постройки", "housing", [
		["Synty Studios — POLYGON Ancient Empire", "3D-модели домов, лавок, храмов, деревьев и украшений · лицензия Synty Store"],
		["Artisau — Ancient Greece Low Poly", "статуи и мелкие предметы · CC0"]]],
	["Жители и животные", "family", [
		["Quaternius — Universal Base Characters, Modular Character Outfits", "жители города · CC0"],
		["Quaternius — Universal Animation Library", "походка, работа и отдых жителей · CC0"],
		["Quaternius — коровы, ослы, лошади, овцы", "животные · CC0"]]],
	["Музыка", "music", [
		["Записи из Викисклада и Musopen", "общественное достояние (PD) и CC0 · громкость выровнена для игры"],
		["Эрик Сати — Гимнопедия № 1", "PD"],
		["Фредерик Шопен — Ноктюрн ми-бемоль мажор, соч. 9 № 2", "CC0"],
		["Роберт Шуман — «Грёзы» из «Детских сцен»", "PD"],
		["Фредерик Шопен — Ноктюрн соль мажор, соч. 37 № 2", "исп. Ольга Гуревич · CC0"],
		["Фредерик Шопен — Вальс ля-бемоль мажор, соч. 69 № 1", "CC0"],
		["Фредерик Шопен — Ноктюрн ми минор, соч. 72 № 1", "CC0"],
		["Роберт Шуман — «О чужих странах и людях»", "PD"],
		["Фредерик Шопен — Ноктюрн фа-диез мажор, соч. 15 № 2", "CC0"],
		["Фредерик Шопен — Вальс ля минор", "PD"],
		["Роберт Шуман — «Поэт говорит»", "PD"],
		["Эдвард Григ — «Утро» из сюиты «Пер Гюнт»", "Musopen Symphony · PD"],
		["Иоганн Себастьян Бах — Ария", "Air Force Strings, оркестр ВВС США · PD"],
		["Антонио Вивальди — Концерт для двух мандолин, RV 532, Анданте", "The Modena Chamber Orchestra · PD"],
		["Анонимный романс (Jeux interdits)", "Джим Гринингер, гитара · CC0"],
		["Йозеф Гайдн — Квартет «Жаворонок», Адажио", "Musopen String Quartet · PD"],
		["Иоганн Пахельбель — Канон", "Strolling Strings, оркестр ВВС США · PD"],
		["Клод Дебюсси — «Священный танец»", "камерный оркестр морской пехоты США, арфа — Карен Гримзи · PD"],
		["Томазо Альбинони — Концерт для гобоя ре минор, Адажио", "Пол Арден-Тейлор, гобой · CC0"],
		["Георг Фридрих Гендель — «Музыка на воде», Менуэт", "камерный оркестр морской пехоты США · PD"],
		["Иоганн Себастьян Бах — Гольдберг-вариации, Ария", "Кимико Исидзака · CC0"],
		["Вольфганг Амадей Моцарт — Серенада «Гран партита», Адажио", "оркестр морской пехоты США · PD"],
		["Антонио Вивальди — «Зима», Ларго", "The Modena Chamber Orchestra · PD"],
		["Александр Бородин — Квартет № 2, Ноктюрн", "Musopen String Quartet · PD"],
		["Феликс Мендельсон — «Итальянская» симфония, Анданте", "Musopen Symphony · PD"],
		["Георг Фридрих Гендель — «Гармоничный кузнец»", "Musopen, клавесин · CC0"],
		["Антонин Дворжак — Квартет № 10, Романс", "Musopen String Quartet · PD"],
		["Людвиг ван Бетховен — «Патетическая» соната, Адажио", "Musopen · CC0"]]],
	["Звуки", "sound", [
		["Kenney — Interface Sounds, RPG Audio, UI Audio", "щелчки, стройка, монеты · CC0 · kenney.nl"],
		["Kerzoven — «Cat Purr & Meow», IgnasD — «Meow»", "кошки · OpenGameArt, CC0"],
		["isaiah658 — «Ambient Bird Sounds»", "птицы · OpenGameArt, CC0"]]],
	["Интерфейс", "scroll", [
		["Рисованные рамки, свитки, медальоны, иконки, портреты и логотип", "нарисованы для CivCity"],
		["Часть значков инструментов", "по мотивам game-icons.net — Lorc, Delapouite · CC BY 3.0"]]],
	["Шрифты", "quill", [
		["Philosopher — Jovanny Lemonad", "SIL Open Font License 1.1"],
		["Alegreya Sans — Huerta Tipográfica", "SIL Open Font License 1.1"]]],
	["Движок", "settings", [
		["Godot Engine 4", "© Хуан Линецкий, Ариэль Манзур и участники Godot · лицензия MIT · godotengine.org"]]],
]


func _credits_panel() -> void:
	var w := _window("Титры", 680)
	credits_panel = w[0]
	var v: VBoxContainer = w[1]
	var sc := ScrollContainer.new()
	sc.name = "scroll"
	sc.custom_minimum_size = Vector2(640, 560)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(col)
	col.add_child(_pic("logo.png", Vector2(600, 150)))
	var tag := _label("Уютный римский город", 20, false, C_SOFT, font_title)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tag)
	for sec: Array in CREDITS:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 10)
		col.add_child(gap)
		var hdr := HBoxContainer.new()
		hdr.alignment = BoxContainer.ALIGNMENT_CENTER
		hdr.add_theme_constant_override("separation", 8)
		hdr.add_child(_icon(sec[1], 30))
		hdr.add_child(_label(sec[0], 24, false, C_INK, font_title))
		col.add_child(hdr)
		col.add_child(_divider(14))
		for it: Array in sec[2]:
			var a := _wrap(_label(it[0], 17, true, C_INK), 600)
			a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(a)
			var bl := _wrap(_label(it[1], 14, false, C_SOFT), 600)
			bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(bl)
			var sp := Control.new()
			sp.custom_minimum_size = Vector2(0, 3)
			col.add_child(sp)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 18)
	col.add_child(gap2)
	var thanks := _label("Спасибо, что играете!", 26, false, C_INK, font_title)
	thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(thanks)
	var gap3 := Control.new()
	gap3.custom_minimum_size = Vector2(0, 30)
	col.add_child(gap3)
	# игрок крутит колёсико или тянет полосу — титры больше не плывут сами
	var stop := func(e: InputEvent):
		if e is InputEventMouseButton and credits_panel.has_meta("roll"):
			(credits_panel.get_meta("roll") as Tween).kill()
			credits_panel.remove_meta("roll")
	sc.gui_input.connect(stop)
	sc.get_v_scroll_bar().gui_input.connect(stop)


## Титры: окно посреди экрана, через пару секунд текст медленно плывёт вверх (как в кино)
func open_credits() -> void:
	_toggle(credits_panel)
	if not credits_panel.visible:
		return
	var sc: ScrollContainer = credits_panel.find_child("scroll", true, false)
	sc.scroll_vertical = 0
	if credits_panel.has_meta("roll"):
		(credits_panel.get_meta("roll") as Tween).kill()
	await get_tree().process_frame
	var bar := sc.get_v_scroll_bar()
	var top := maxf(0.0, bar.max_value - bar.page)
	if top <= 0.0 or not credits_panel.visible:
		return
	var tw := sc.create_tween()
	tw.tween_interval(2.5)
	tw.tween_method(func(y: float): sc.scroll_vertical = int(y), 0.0, top, top / 28.0)
	credits_panel.set_meta("roll", tw)


func _open_settings(stay := false) -> void:
	(settings_panel.find_child("fs", true, false) as CheckBox).set_pressed_no_signal(bool(game.settings["fullscreen"]))
	(settings_panel.find_child("auto", true, false) as CheckBox).set_pressed_no_signal(bool(game.settings["autosave"]))
	for key in ["music", "sfx", "ui_scale"]:
		(settings_panel.find_child(key, true, false) as HSlider).set_value_no_signal(float(game.settings.get(key, 1.0)))
	for q in ["high", "medium", "low"]:
		var b: Button = settings_panel.find_child("q_" + q, true, false)
		b.add_theme_stylebox_override("normal", _box_pill(16, 6, "g_btn_on" if game.settings["quality"] == q else "g_btn"))
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
	lbl_level.text = Defs.LEVELS[c.level]["name"]          # подсказка — мгновенная, _tip_level
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
	_fill_families()
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
	if hover_src:
		_fill_hover()                       # числа в открытой подсказке живые


func _fill_classes() -> void:
	var hover_cls := ""                     # мышь над фишкой класса — после пересборки подсказка остаётся на новой фишке
	if hover_src and is_instance_valid(hover_src) and hover_src.has_meta("cls"):
		hover_cls = hover_src.get_meta("cls")
	_clear(class_box)
	var c: City = game.city
	for cl in Defs.CLASS_ORDER:
		var cd: Dictionary = Defs.CLASSES[cl]
		if not c.unlocked(cd["house"]) and int(c.stats["residents"].get(cl, 0)) == 0:
			continue
		var chip := _chip(false, 8.0)
		chip.set_meta("cls", cl)
		_hover_on(chip, _tip_class.bind(cl))
		if cl == hover_cls:
			hover_src = chip
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		var pic := _cls_pic(cl, 46)               # портрет класса в медальоне
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(pic)
		var v1 := VBoxContainer.new()
		v1.add_theme_constant_override("separation", -4)
		v1.alignment = BoxContainer.ALIGNMENT_CENTER
		v1.add_child(_label(cd["name"], 13, true, C_SOFT))
		var n := _label(fmt(int(c.stats["residents"].get(cl, 0))), 18, true)
		v1.add_child(n)
		h.add_child(v1)
		var v2 := VBoxContainer.new()
		v2.add_theme_constant_override("separation", -3)
		v2.alignment = BoxContainer.ALIGNMENT_CENTER
		var hr := HBoxContainer.new()
		hr.add_theme_constant_override("separation", 3)
		hr.add_child(_icon("happy", 19, C_GOOD))
		hr.add_child(_label("%d%%" % int(c.stats["class_happy"].get(cl, 0)), 16, true, C_GOOD))
		v2.add_child(hr)
		var wr := HBoxContainer.new()
		wr.add_theme_constant_override("separation", 3)
		wr.add_child(_icon("hammer", 19, C_SOFT))
		var fr := int(c.stats["free"].get(cl, 0))
		var short := int(c.stats["jobs"].get(cl, 0)) - int(c.stats["workers"].get(cl, 0))
		wr.add_child(_label(("+%d" % fr) if short <= 0 else ("−%d" % short), 16, true, C_INK if short <= 0 else C_BAD))
		v2.add_child(wr)
		h.add_child(v2)
		chip.add_child(h)
		class_box.add_child(chip)
	_snug(class_box)                          # по содержимому — уже после заполнения


func _fill_tasks() -> void:
	_clear(tasks_box)
	var c: City = game.city
	var goals := c.active_goals(3)
	tasks_panel.visible = not goals.is_empty() and game.mode != "demo" and ui_level() >= 3
	if not goals.is_empty():
		_fill_tasks_body(goals)
	# свиток по содержимому: прикрепить заново уже ПОСЛЕ заполнения (иначе он сжимается до пустого и
	# просьбы вылезают за нижний валик) и ещё раз через кадр, когда перенос строк уже посчитан
	_snug(tasks_panel)
	_refit(tasks_panel)


func _fill_tasks_body(goals: Array) -> void:
	var c: City = game.city
	var hdr := HBoxContainer.new()
	hdr.alignment = BoxContainer.ALIGNMENT_CENTER
	hdr.add_theme_constant_override("separation", 6)
	hdr.add_child(_icon("scroll", 26, C_SOFT))
	hdr.add_child(_label("Просьбы горожан", 20, false, C_INK, font_title))
	tasks_box.add_child(hdr)
	tasks_box.add_child(_divider(14))
	var first := true
	for g in goals:
		var prog := mini(c.goal_progress(g["id"]), int(g["need"]))
		# строка просьбы растёт по тексту (текст сверху, под ним полоса), а прозрачная кнопка лежит поверх всей строки
		var row := MarginContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side in ["left", "right", "top", "bottom"]:
			row.add_theme_constant_override("margin_" + side, 2)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		var e := StyleBoxEmpty.new()
		for st in ["normal", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(st, e)
		var hov := _box_pill(8, 4, "g_btn_hover")
		hov.modulate_color = Color(1, 1, 1, 0.45)
		b.add_theme_stylebox_override("hover", hov)
		b.add_theme_stylebox_override("hover_pressed", hov)
		var who: Array = Defs.WHO.get(g.get("who", "advisor"), Defs.WHO["advisor"])
		var hint_txt := String(g.get("hint", ""))
		# «Соберите N жителей», а повозка стоит из-за счастья — сразу сказать почему и что делать
		var block := String(c.stats.get("arrive_block", ""))
		if String((g["p"] as Array)[0]) == "pop" and block != "":
			var ht: Array = c.stats.get("happy_tips", [])
			hint_txt = block + "." + ((" Совет: " + String(ht[0]) + ".") if not ht.is_empty() else "") + ("\n" + hint_txt if hint_txt != "" else "")
		b.tooltip_text = "%s\n%s\nНаграда: %d ден.%s%s" % [who[0], hint_txt if hint_txt != "" else String(g["text"]), g["money"], (", %d оч. исследований" % g["rp"]) if int(g["rp"]) > 0 else "",
			("\nОткроется: " + g["reward"]) if g.has("reward") else ""]
		var h := HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_theme_constant_override("separation", 8)
		var med := Panel.new()                    # медальон с иконкой просьбы; первая — светится
		med.custom_minimum_size = Vector2(44, 44)
		med.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		med.mouse_filter = Control.MOUSE_FILTER_IGNORE
		med.add_theme_stylebox_override("panel", _medal("medal_on" if first else "medal", 44))
		var ic := _icon(g.get("icon", "check"), 28, C_INK)
		ic.position = Vector2(8, 8)
		med.add_child(ic)
		h.add_child(med)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 3)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var t := _wrap(_label(g["text"], 15, true), 222)
		v.add_child(t)
		var pr := HBoxContainer.new()
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pr.add_theme_constant_override("separation", 6)
		var bar := ProgressBar.new()
		bar.max_value = int(g["need"])
		bar.value = prog
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(170, 14)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# жёлоб и золотая полоса — как у ползунка
		bar.add_theme_stylebox_override("background", _ai_box("g_slider", [8, 0, 8, 0], [8, 0, 8, 0]))
		bar.add_theme_stylebox_override("fill", _ai_box("g_slider_fill", [8, 0, 8, 0], [8, 0, 8, 0]))
		pr.add_child(bar)
		var cnt := _label("%s/%s" % [fmt(prog), fmt(int(g["need"]))], 14, true, C_SOFT)
		cnt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pr.add_child(cnt)
		v.add_child(pr)
		h.add_child(v)
		row.add_child(h)
		row.add_child(b)                          # кнопка последней — поверх строки, ловит щелчок и подсказку
		var gg: Dictionary = g
		var gh := hint_txt
		b.pressed.connect(func():
			if gh != "":
				advisor(gg["text"], gh)
			if gg.has("tool"):
				select_build(gg["tool"]))
		tasks_box.add_child(row)
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

func _update_world_icons() -> void:
	var want := {}
	var c: City = game.city
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		var d := c.def(b)
		var icon := ""
		var warn := true
		if d["kind"] == "shop" and not b.get("active", true):
			icon = {"store": "warehouse", "good": "wheat", "road": "road"}.get(b.get("why", ""), "hammer")
		elif d["kind"] in ["rp", "farm", "store", "monument"] and d.has("jobs") and (float(b.get("fill", 1.0)) < 0.99 or c.hired_of(b) == 0):
			icon = "hammer"
		elif d["kind"] == "center" and c.waiting > 0:
			icon = "family"
			warn = false
		if icon != "":
			want[id] = [icon, warn]
	for id in world_icons.keys():
		if not want.has(id) or world_icons[id] != want[id]:
			clear_badge("b%d" % id)
			world_icons.erase(id)
	for id in want:
		if world_icons.has(id):
			continue
		var b: Dictionary = c.buildings[id]
		var top: float = c.blueprint(b).top_y() + 1.2
		set_badge("b%d" % id, Vector3(b["pos"].x, float(b["y"]) + top, b["pos"].y), want[id][0], want[id][1])
		world_icons[id] = want[id]


# ---------- значки над миром ----------

func _badge_layer() -> void:
	badge_layer = Control.new()
	badge_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(badge_layer)
	move_child(badge_layer, 0)                # окна интерфейса рисуются поверх значков


## Значок над точкой мира, размер на экране постоянный (как в Town to City): рисованный пузырь —
## нет работников, склада, сырья, дороги, ждут жилья, сюда можно заселить; или плашка с монетой и ценой участка.
## Значок можно нажать: cb — что сделать; без cb — по ключу (_badge_click): семья — выбрать ей дом,
## беда над постройкой — её карточка, ключи над домом — заселить, цена участка — купить
func set_badge(key: String, pos: Vector3, icon: String, warn := false, text := "", cb: Callable = Callable()) -> void:
	if badges.has(key):
		var old: Dictionary = badges[key]
		old["pos"] = pos
		if cb.is_valid():
			old["cb"] = cb
		else:
			cb = old.get("cb", Callable())
		if old["icon"] == icon and old["warn"] == warn and old.get("text", "") == text:
			return
		(old["n"] as Node).queue_free()
	var p: Control
	var anc := Vector2(0.5, 0.5)
	if text == "" and ResourceLoader.exists(AI + "badge_%s.png" % icon):
		p = _pic("badge_%s.png" % icon, Vector2(56, 56))
		anc = Vector2(0.22, 0.96)                 # хвостик пузыря смотрит на постройку
	else:
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", _box_pill(12, 5))
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if text == "":
			pc.add_child(_icon(icon, 30, C_BAD if warn else C_INK))
		else:
			var h := HBoxContainer.new()
			h.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.add_theme_constant_override("separation", 4)
			h.add_child(_icon(icon, 26, C_GOLD))
			h.add_child(_label(text, 17, true, C_INK))
			pc.add_child(h)
		p = pc
	p.visible = false
	for ch in p.find_children("*", "Control", true, false):
		(ch as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE      # ловит мышь, когда можно нажать (_place_badges)
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.gui_input.connect(_badge_input.bind(key))
	badge_layer.add_child(p)
	p.reset_size()
	badges[key] = {"pos": pos, "icon": icon, "warn": warn, "text": text, "n": p, "anc": anc, "ph": float(hash(key) % 628) / 100.0, "cb": cb}


## Значок ловит только левую кнопку (нажатие — действие, отпускание тоже не уходит в мир);
## правая/средняя кнопка и движение мыши проходят дальше — карту можно тянуть и вращать прямо со значка
func _badge_input(e: InputEvent, key: String) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if (e as InputEventMouseButton).pressed:
			_badge_click(key)


## Нажали значок над миром
func _badge_click(key: String) -> void:
	if not badges.has(key):
		return
	var cb: Callable = badges[key].get("cb", Callable())
	if cb.is_valid():
		cb.call()
		return
	var c: City = game.city
	if key.begins_with("fam_"):
		game.start_settle(key.substr(4))                       # семья на площади — выбрать ей дом
	elif key.begins_with("settle") and key.substr(6).is_valid_int():
		var h: Dictionary = c.buildings.get(int(key.substr(6)), {})
		if not h.is_empty() and c.can_host(h, game.settle_fam):
			game._settle_into(h)                                # ключи над домом — заселить сюда
	elif key.begins_with("plot"):
		var ij := key.substr(4).split("_")
		if ij.size() == 2 and c.can_buy(Vector2i(int(ij[0]), int(ij[1]))):
			ask_buy(Vector2i(int(ij[0]), int(ij[1])))           # цена участка — купить
	elif key.begins_with("b") and key.substr(1).is_valid_int():
		var b: Dictionary = c.buildings.get(int(key.substr(1)), {})
		if b.is_empty():
			return
		if c.def(b)["kind"] == "center" and not c.arrivals.is_empty():
			game.start_settle(c.arrivals[0]["name"])             # семьи у станции — выбрать дом первой
		else:
			game.select_building(b)                              # беда над постройкой — её карточка
			open_info(b)


## Над каждой семьёй, что ждёт жилья на площади, — значок семьи (нажать — выбрать ей дом)
func _family_badges() -> void:
	var want := {}
	var c: City = game.city
	if c != null and game.people != null and game.mode != "demo" and game.mode != "menu" and game.people.has_method("waiting_family_pos"):
		for f in c.arrivals:
			var at: Vector3 = game.people.waiting_family_pos(String(f["name"]))
			if at.is_finite():
				var key := "fam_" + String(f["name"])
				want[key] = true
				set_badge(key, at + Vector3(0, 1.7, 0), "family")
	for k in badges.keys():
		if String(k).begins_with("fam_") and not want.has(k):
			clear_badge(k)


func clear_badge(key: String) -> void:
	if badges.has(key):
		(badges[key]["n"] as Node).queue_free()
		badges.erase(key)


func _place_badges() -> void:
	if game and game.ready_done:
		_family_badges()
	if badges.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var vr := get_viewport().get_visible_rect()
	var show: bool = root.visible and game.mode != "menu"
	var t := Time.get_ticks_msec() / 1000.0
	var tl: String = game.tool
	for k in badges:
		var b: Dictionary = badges[k]
		var p: Control = b["n"]
		var w: Vector3 = b["pos"]
		# нажать значок можно без инструмента; при заселении — ключи над домами и значки семей
		# (с кистью или стройкой значки мышь не ловят — не мешают вести дорогу и ставить дома)
		var can: bool = tl == "" or (tl == "settle" and (String(k).begins_with("settle") or String(k).begins_with("fam_")))
		# PASS, а не STOP: левую кнопку забирает _badge_input, а правая/средняя (тянуть и вращать карту) идут в мир
		var mf := Control.MOUSE_FILTER_PASS if can else Control.MOUSE_FILTER_IGNORE
		if p.mouse_filter != mf:
			p.mouse_filter = mf
		if not show or cam.is_position_behind(w):
			p.visible = false
			continue
		var pt := cam.unproject_position(w)
		var anc: Vector2 = b.get("anc", Vector2(0.5, 0.5))
		var bob := sin(t * 2.2 + float(b.get("ph", 0.0))) * 2.5 if anc.y > 0.9 else 0.0   # пузыри чуть покачиваются
		p.position = (pt - p.size * anc + Vector2(0, bob)).round()
		p.visible = vr.grow(30).has_point(pt)


# ---------- стартовое меню ----------

func show_menu(has_save: bool) -> void:
	root.visible = false
	menu_root = Control.new()
	menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_root.theme = theme_main
	add_child(menu_root)
	menu_root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# логотип над свитком с кнопками
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_put(col, Control.PRESET_TOP_LEFT, Vector2(70, 34))
	menu_root.add_child(col)
	var logo := _pic("logo.png", Vector2(470, 231))
	col.add_child(logo)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box_scroll_v(18))
	p.custom_minimum_size = Vector2(380, 0)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var sub := _label("Уютный римский город", 21, false, C_SOFT, font_title)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(_divider(18))
	var mk := func(text: String, icon: String, cb: Callable) -> Button:
		var b := Button.new()
		b.text = text
		b.icon = ico(icon, 40)
		b.custom_minimum_size = Vector2(300, 58)
		b.add_theme_font_size_override("font_size", 24)
		b.add_theme_font_override("font", font_bold)
		b.pressed.connect(cb)
		v.add_child(b)
		return b
	mk.call("Играть", "play", func(): _menu_go("play" if has_save else "new"))
	mk.call("Настройки", "settings", func(): _menu_settings())
	mk.call("Титры", "laurels", func(): _menu_credits())
	mk.call("Выход", "exit", func(): get_tree().quit())
	var foot := _label("Колёсико — масштаб · зажатое колёсико — вращать · правая кнопка — двигать", 16, true, C_CREAM)
	foot.add_theme_color_override("font_outline_color", Color("3a2412"))
	foot.add_theme_constant_override("outline_size", 6)
	_put(foot, Control.PRESET_BOTTOM_LEFT, Vector2(80, -36))
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


## Титры из главного меню — так же, как настройки: меню прячется, пока открыто окно
func _menu_credits() -> void:
	menu_root.visible = false
	root.visible = true
	for ch in root.get_children():
		(ch as CanvasItem).visible = false
	open_credits()
	if not credits_panel.visibility_changed.is_connected(_menu_credits_closed):
		credits_panel.visibility_changed.connect(_menu_credits_closed)


func _menu_credits_closed() -> void:
	if game.mode == "menu" and not credits_panel.visible and menu_root:
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
		# у украшений облик задаёт тип (Catalog.make сам берёт их постоянный цвет) — картинка как поставленное
		var g := Parts.ghost(Catalog.make(type, tier, 0, col), "outline", Color(0, 0, 0, 0))
		for gi: GeometryInstance3D in g.find_children("*", "GeometryInstance3D", true, false):
			gi.material_override = null
		# тёмная плашка под землёй (ровняет землю под клумбой, лужком, перголой) — на картинке не нужна
		for ch in g.get_children():
			if ch is MeshInstance3D and (ch as MeshInstance3D).mesh == Parts._special_mesh("#dark") and (ch as Node3D).position.y < -0.05:
				g.remove_child(ch)
				ch.free()
		holder.add_child(g)
		var box := Artisau.aabb(g)
		var c := box.get_center()
		var deco: bool = d["kind"] == "decor"
		var rad := maxf(0.3 if deco else 0.6, box.size.length() * 0.5)
		var dir := Vector3(0.62, 0.6, 0.95).normalized()
		cam.look_at_from_position(c + dir * rad / sin(deg_to_rad(15.0)) * 0.95, c, Vector3.UP)
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		if deco:
			# украшения маленькие: обрезать пустые поля, чтобы облик был крупно и облики отличались на карточке
			var r := img.get_used_rect()
			if r.size.x > 8 and r.size.y > 8:
				r = r.grow(int(maxf(r.size.x, r.size.y) * 0.05)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
				img = img.get_region(r)
		icons[type] = ImageTexture.create_from_image(img)
		g.queue_free()
		await get_tree().process_frame
	vp.queue_free()
	if tray.visible:
		_update_cards()

