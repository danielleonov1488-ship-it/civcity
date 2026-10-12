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
	_buy_panel()
	_pointer()
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
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	lbl_level = _label("Стоянка", 14, true, C_SOFT)
	lbl_level.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(lbl_level)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(5, 0)
	row.add_child(gap)
	row.add_child(_icon("family", 20))
	lbl_pop = _label("0", 16, true)
	row.add_child(lbl_pop)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(4, 0)
	row.add_child(gap2)
	row.add_child(_icon("happy", 20))
	lbl_happy = _label("0%", 16, true, C_GOOD)
	row.add_child(lbl_happy)
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
	for x in [events_panel, research_panel, finance_panel, stats_panel, pause_panel, settings_panel, buy_panel]:
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
		var keys := {"road": "Ведите с зажатой левой кнопкой. [ ] — размер, Ctrl+Z — отменить.",
			"path": "Утоптанная тропа — почти даром.", "plaza": "Плитка для площадей у рынков и храмов.", "erase": "Стирает дорогу под кистью.",
			"bulldoze": "Наведите на постройку, дерево или камень — подсветится красным. Щелчок — снести.", "copy": "Щёлкните по постройке — возьмёте такую же.",
			"move": "Щёлкните по постройке, дереву или камню и поставьте на новое место.", "move_nature": "Поставьте на новое место. Z/X — повернуть."}
		tool_keys.text = keys.get(t, "") + "\nПравая кнопка — отмена"


func tool_status(err: String) -> void:
	if tool_err.text != err:
		tool_err.text = err
		tool_err.visible = err != ""
		_snug(tool_panel)



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


func _fill_info() -> void:
	_fill_info_body()
	_snug(info_panel)


func _fill_info_body() -> void:
	_clear(info_box)
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
		(ib.get_node("ic") as TextureRect).texture = ico("color", 60)
		ib.pressed.connect(func(): c.recolor(b))
	hdr.add_child(ib)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := _label(d["name"], 21, false, C_INK, font_title)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(nm)
	hdr.add_child(tv)
	var close := _bare("close", "Закрыть", 34, func(): close_panels())
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hdr.add_child(close)
	info_box.add_child(hdr)
	info_box.add_child(_divider(18))
	match d["kind"]:
		"house":
			var cls: Dictionary = Defs.CLASSES[d["cls"]]
			tv.add_child(_label("%s · этаж %d из %d · цвет «%s»" % [cls["name"], int(b["tier"]), Defs.floors_max(d["cls"]), Defs.PALETTE[int(b["color"])]["name"]], 14, true, C_SOFT))
			var hp := int(b["happy"])
			var hrow := HBoxContainer.new()
			var hi := _icon("happy", 30)
			_grey(hi, hp < 50)
			hrow.add_child(hi)
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
				var ni := _icon(need["icon"], 28)
				_grey(ni, shops.is_empty())          # нет лавки рядом — серая
				r.add_child(ni)
				if shops.is_empty():
					r.add_child(_label("%s: нет лавки рядом (−10%%)" % need["name"], 15, true, C_BAD))
				else:
					var fl := HFlowContainer.new()
					fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					for t in shops:
						var chip := _chip()
						var ch := HBoxContainer.new()
						ch.add_child(_icon(Defs.B[t].get("icon", "commerce"), 20))
						ch.add_child(_label("+%d%%" % int(b["score"][t]), 14, true, C_GOOD))
						chip.add_child(ch)
						chip.tooltip_text = Defs.B[t]["name"]
						fl.add_child(chip)
					r.add_child(fl)
				info_box.add_child(r)
			# семьи: портрет класса и число людей
			var fams: Array = b.get("families", [])
			if fams.is_empty():
				info_box.add_child(_label("Ждёт новосёлов — повозка привезёт семью из тоннеля", 15, true, C_SOFT))
			for f in fams:
				var fr := HBoxContainer.new()
				fr.add_theme_constant_override("separation", 6)
				fr.add_child(_cls_pic(d["cls"], 30))
				var fl := _label("Семья %s" % f["name"], 16, true)
				fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				fr.add_child(fl)
				fr.add_child(_label("%d чел." % int(f["n"]), 16, true, C_SOFT))
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
			info_box.add_child(_hire_row(b))
			if not b.get("active", true):
				var why := {"store": "Нет склада рядом — нечем торговать", "good": "Нет сырья: %s" % {"wheat": "постройте пшеничное поле", "olives": "посадите оливковую рощу", "grapes": "посадите виноградник"}.get(d.get("needs_good", ""), ""),
					"road": "Нет дороги у входа", "staff": "Нет работников: наймите (+) — или нужно больше жителей"}
				var wl := _label(why.get(b.get("why", "staff"), "Не работает"), 15, true, C_BAD)
				wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				info_box.add_child(wl)
		"monument":
			info_box.add_child(_row("happy", "Счастье всем вокруг", "+%d%%" % int(d["bonus"]), C_GOOD))
			info_box.add_child(_row("arrow", "Дальность", Defs.WORD[int(d["range"])]))
		"rp":
			info_box.add_child(_row("research", "Очки исследований в день", "+%.1f" % (float(d["rp"]) * float(b.get("staff", 1.0))), C_GOOD))
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
	var credits := _label("Модели — Synty POLYGON Ancient Empire. Музыка — записи Шопена, Шумана и Сати из Викисклада (общественное достояние). Звуки — Kenney и авторы OpenGameArt (CC0). Рисованный интерфейс сделан для CivCity; значки инструментов — по мотивам game-icons.net (Lorc, Delapouite), CC BY 3.0. Шрифты Philosopher и Alegreya Sans — OFL. Движения людей — Quaternius, CC0.", 14, false, C_SOFT)
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


func _fill_classes() -> void:
	_clear(class_box)
	_snug(class_box)
	var c: City = game.city
	for cl in Defs.CLASS_ORDER:
		var cd: Dictionary = Defs.CLASSES[cl]
		if not c.unlocked(cd["house"]) and int(c.stats["residents"].get(cl, 0)) == 0:
			continue
		var chip := _chip(false, 8.0)
		chip.tooltip_text = "%s: %d жителей, счастье %d%%, свободных работников %d" % [cd["name"], int(c.stats["residents"].get(cl, 0)), int(c.stats["class_happy"].get(cl, 0)), int(c.stats["free"].get(cl, 0))]
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
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


func _fill_tasks() -> void:
	_clear(tasks_box)
	_snug(tasks_panel)
	var c: City = game.city
	var goals := c.active_goals(3)
	tasks_panel.visible = not goals.is_empty() and game.mode != "demo" and ui_level() >= 3
	if goals.is_empty():
		return
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
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(266, 52)
		var who: Array = Defs.WHO.get(g.get("who", "advisor"), Defs.WHO["advisor"])
		b.tooltip_text = "%s\n%s\nНаграда: %d ден.%s%s" % [who[0], g.get("hint", g["text"]), g["money"], (", %d оч. исследований" % g["rp"]) if int(g["rp"]) > 0 else "",
			("\nОткроется: " + g["reward"]) if g.has("reward") else ""]
		var h := HBoxContainer.new()
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
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
		v.add_theme_constant_override("separation", 2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var t := _label(g["text"], 15, true)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size = Vector2(214, 0)
		v.add_child(t)
		var pr := HBoxContainer.new()
		var bar := ProgressBar.new()
		bar.max_value = int(g["need"])
		bar.value = prog
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(172, 14)

		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# жёлоб и золотая полоса — как у ползунка
		bar.add_theme_stylebox_override("background", _ai_box("g_slider", [8, 0, 8, 0], [8, 0, 8, 0]))
		bar.add_theme_stylebox_override("fill", _ai_box("g_slider_fill", [8, 0, 8, 0], [8, 0, 8, 0]))
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
## нет работников, склада, сырья, дороги, ждут жилья, сюда можно заселить; или плашка с монетой и ценой участка
func set_badge(key: String, pos: Vector3, icon: String, warn := false, text := "") -> void:
	if badges.has(key):
		var old: Dictionary = badges[key]
		old["pos"] = pos
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
	badge_layer.add_child(p)
	p.reset_size()
	badges[key] = {"pos": pos, "icon": icon, "warn": warn, "text": text, "n": p, "anc": anc, "ph": float(hash(key) % 628) / 100.0}


func clear_badge(key: String) -> void:
	if badges.has(key):
		(badges[key]["n"] as Node).queue_free()
		badges.erase(key)


func _place_badges() -> void:
	if badges.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var vr := get_viewport().get_visible_rect()
	var show: bool = root.visible and game.mode != "menu"
	var t := Time.get_ticks_msec() / 1000.0
	for k in badges:
		var b: Dictionary = badges[k]
		var p: Control = b["n"]
		var w: Vector3 = b["pos"]
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

