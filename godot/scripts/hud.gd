class_name Hud
extends CanvasLayer
## Интерфейс в римском духе — рисованный набор владельца (assets/ui/ai): резные рамки с меандром, свитки
## с валиками, бронзовые медальоны с цветными иконками, табличка с орлом и лентой названия города. Устроен как в Town to City:
## сверху слева — город, жители, счастье, время; рядом — три класса жителей; под ними — задания со стрелкой-подсказкой.
## Сверху справа — события, исследования, финансы, жители, «Обзор» (счастье домов, потребности), фото, меню.
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
var name_plate: TextureRect           # табличка с названием: в своём городе её можно нажать (окно «Название города»)
const CITY_FONT := 20                 # размер названия на ленте (длинное — мельче, show_city_name)
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
var bar_left: PanelContainer             # нижние полосы: дороги, разделы стройки, инструменты с казной
var bar_mid: PanelContainer
var bar_right: PanelContainer
var tray: PanelContainer
var tray_grid: HBoxContainer
var tray_tabs: HBoxContainer
var tray_title: Label
var open_cat := ""
var open_sub := "food"
var open_dsub := "plants"             # вкладка украшений
var tray_dtabs: HBoxContainer
var tool_panel: PanelContainer
var undo_btn: Button                      # медаль «Отменить» в панели постройки (3.6)
var thumb_rect: TextureRect               # живая картинка постройки (3.4)
var color_box: HBoxContainer              # ряд цветов фасада (3.4)
var gate_check: CheckBox                  # забор: калитка посередине
const THUMB := Vector2i(220, 140)
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
var adv_skip: Button                        # «Пропустить обучение» у совета-шага (advisor(…, skip))
var adv_ok: Button                          # «Понятно» (у вопроса Gfx — «Не надо»)
var _adv_skip_cb := Callable()
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
var floor_badge: Label                    # на кнопке «Этаж»: сколько домов готовы к этажу
const FLOOR_TIP := "Этаж (U): щёлкните по дому со стрелкой или ведите с зажатой кнопкой вдоль улицы — этаж получат все готовые дома под курсором"
var cloud_off: CloudBadge             # значок «нет связи с облаком» слева от колокольчика
var pointer: TextureRect
var pointer_target: Control
var pointer_text: Label
var credits_panel: PanelContainer         # титры: кто и что сделал для игры
var journal_panel: PanelContainer = null  # журнал «Истории горожан» (собирает StoryUi при первом открытии)
var hover_tip: PanelContainer             # мгновенная подсказка у плашки города и фишек классов
var hover_box: VBoxContainer
var hover_src: Control                    # над чем сейчас мышь
var hover_level: Control                  # зоны плашки города: уровень, жители, счастье
var hover_pop: Control
var hover_happy: Control
var rank_btn: Button                      # «Перейти на новый уровень» — под табличкой города, когда все условия выполнены
var full_money: Label                     # «Казна полна — доход пропадает» над казной
var full_rp: Label                        # «Полки полны — очки пропадают»
var _cursor_key := ""                     # какой рисованный курсор стоит на обычной стрелке (по инструменту, см. _cursor_world)
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
	_rank_button()
	_top_right()
	_bottom_left()
	_bottom_center()
	_bottom_right()
	_tool_panel()
	_overlay_panel()
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
	LegionUi.attach(self)                      # окно «Легион» и его медальон сверху справа (scripts/legion_ui.gd)
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
	_fit_bottom.call_deferred()               # экран в точках стал уже — полосы внизу подогнать


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
		elif ResourceLoader.exists(path):         # собранная игра: исходных SVG нет, только импортированная картинка 512
			var img := (load(path) as Texture2D).get_image()
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			img.resize(maxi(1, roundi(img.get_width() * size / 512.0)), maxi(1, roundi(img.get_height() * size / 512.0)), Image.INTERPOLATE_LANCZOS)
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
	lbl_city = _label(CityName.PLACEHOLDER, CITY_FONT, false, C_CREAM, font_title)
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
	name_plate = plate
	if game != null and game.mode in ["play", "new"]:
		# в своём городе табличку можно нажать — окно «Название города» (в меню и готовом городе — просто надпись)
		plate.mouse_filter = Control.MOUSE_FILTER_STOP
		plate.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		plate.tooltip_text = "Щёлкните — назвать город"
		plate.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				plate.accept_event()
				open_city_name())
		plate.mouse_entered.connect(func(): plate.modulate = Color(1.12, 1.09, 1.03))
		plate.mouse_exited.connect(func(): plate.modulate = Color.WHITE)
	show_city_name()
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


## Название города на табличке: имя с сервера (city.name), пока его нет — «Новый Рим» (в меню и готовом городе — всегда).
## Длинное имя (до 24 знаков) — мельче, чтобы целиком влезло в ленту
func show_city_name() -> void:
	var nm := CityName.PLACEHOLDER
	if game != null and game.city != null and game.mode in ["play", "new"] and String(game.city.name) != "":
		nm = String(game.city.name)
	if lbl_city == null or (lbl_city.text == nm and lbl_city.has_meta("fit")):
		return
	lbl_city.text = nm
	lbl_city.set_meta("fit", true)
	var w := PLATE.x * (1.0 - 0.335 - 0.095) - 6.0
	var sz := CITY_FONT
	while sz > 11 and font_title.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > w:
		sz -= 1
	lbl_city.add_theme_font_size_override("font_size", sz)


## Щелчок по табличке: окно «Название города» (то же, что у кнопки «Имя» в «Легионе»)
func open_city_name() -> void:
	if game == null or not (game.mode in ["play", "new"]):
		return
	if game.sound:
		game.sound.ui("click")
	_close_windows()
	CityName.open(self)


## Никаких окон на экране (для советов «к слову»: про название города)
func _screen_free() -> bool:
	for x in [info_panel, events_panel, research_panel, finance_panel, stats_panel, pause_panel, settings_panel, buy_panel, credits_panel, tray, journal_panel]:
		if x and x.visible:
			return false
	var lu := LegionUi.of(self)
	if (lu != null and lu.visible) or CityName.window(self) != null:
		return false
	var au = get_node_or_null("AccountUi")
	return au == null or au._modal == null or not is_instance_valid(au._modal)


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
	var nf := int(_defc("ARRIVE_FREE", 3))
	advisor("Новые семьи не едут", ("Первые %d %s приезжают всегда, а дальше в город переселяются, только если счастье города не ниже %d%%. Сейчас — %d%%, и повозка ждёт на дороге.\n\nНаведите мышь на счастье вверху — там видно, из чего оно складывается и что его поднимет. Как только счастье поднимется, повозка сразу поедет." % [nf, _plural(nf, "семья", "семьи", "семей"), int(_defc("ARRIVE_HAPPY", 60)), int(c.stats.get("happy", 0))]) + tip)


## Советы о приезжих: первая семья; семья, которой негде жить
func on_arrival(f: Dictionary) -> void:
	var c: City = game.city
	if game.mode == "demo" or (game.tutorial and game.tutorial.active()):
		return
	if c.settled_total == 0 and not c.tips.has("first_family"):
		c.tips["first_family"] = true
		advisor("Приехали первые жители!", "Семьи сошли с повозки на площадь у станции и ждут жилья. Нажмите на значок семьи слева вверху — подходящие дома засветятся, — и щёлкните по дому.

Пока семьи ждут, новые не едут: на площади помещается всего несколько семей. А везёт их повозка только туда, где в домах есть свободное место, — стройте дома заранее. Так город растёт постепенно.")
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


# ---------- новый уровень по кнопке (как зелёная кнопка в Town to City) ----------

const RANK_H := 50                          # на столько опускаются просьбы, когда видна кнопка уровня


func _rank_button() -> void:
	rank_btn = Button.new()
	rank_btn.text = "Перейти на новый уровень"
	rank_btn.icon = ico("level", 40)
	rank_btn.expand_icon = false
	rank_btn.focus_mode = Control.FOCUS_NONE
	rank_btn.add_theme_font_override("font", font_bold)
	rank_btn.add_theme_font_size_override("font_size", 18)
	rank_btn.add_theme_stylebox_override("normal", _box_pill(18, 6, "g_btn_on"))
	rank_btn.add_theme_stylebox_override("hover", _box_pill(18, 6, "g_btn_hover"))
	rank_btn.add_theme_stylebox_override("pressed", _box_pill(18, 6, "g_btn_on"))
	rank_btn.add_theme_stylebox_override("hover_pressed", _box_pill(18, 6, "g_btn_on"))
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		rank_btn.add_theme_color_override(st, C_GOOD)
	rank_btn.custom_minimum_size = Vector2(PLATE.x, 44)
	rank_btn.visible = false
	rank_btn.pressed.connect(press_rank)
	root.add_child(rank_btn)
	_put(rank_btn, Control.PRESET_TOP_LEFT, Vector2(8, TASKS_Y + 2))


## Кнопка видна: условия выполнены, город не в меню и не в демо, обучение кончилось
func rank_shown() -> bool:
	if game == null or game.city == null or game.mode in ["demo", "menu"]:
		return false
	if game.tutorial and game.tutorial.active():
		return false
	return ui_level() >= 1 and game.city.rank_ok()


## «Перейти на новый уровень»: уровень +1, ролик «Новый ранг» сыграет сам (rank_cine ловит level_up)
func press_rank() -> void:
	var c: City = game.city
	if not c.rank_ok():
		return
	advisor_panel.visible = false            # ролик ждёт, пока открыт советник, — убираем его
	_hide_hover()
	_hide_info()
	c.rank_up()
	refresh()


## Кнопка уровня и сдвиг просьб под неё; плашка уровня светится, пока город готов
func _update_rank_ui() -> void:
	var on := rank_shown()
	if rank_btn.visible != on:
		rank_btn.visible = on
		_put(tasks_panel, Control.PRESET_TOP_LEFT, Vector2(8, TASKS_Y + (RANK_H if on else 0)))
	if on:
		var nx: Dictionary = game.city.next_level()
		rank_btn.tooltip_text = "Город готов стать «%s»: все условия выполнены. Нажмите — откроются новые исследования, казна станет вместительнее." % nx.get("name", "")
	lbl_level.add_theme_color_override("font_color", C_GOOD if on else C_SOFT)
	if not on:
		lbl_level.modulate = Color.WHITE
		rank_btn.self_modulate = Color.WHITE


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


## Уровень города → чек-лист условий следующего (галочки, сколько из скольких) и что он даст.
## Сам город уровень не поднимает: когда всё готово, под табличкой появляется кнопка «Перейти на новый уровень»
func _tip_level(v: VBoxContainer) -> void:
	var c: City = game.city
	_tip_head(v, "level", "Уровень города: «%s»" % Defs.LEVELS[c.level]["name"])
	var nx := c.next_level()
	if nx.is_empty():
		_tip_text(v, "Это высший уровень — ваш город стал Вечным!", C_GOOD, 15, true)
		return
	var nd := c.rank_needs()
	var met := c.rank_met()
	_tip_text(v, "Следующий уровень — «%s». Готово %d из %d:" % [nx["name"], met, nd.size()], C_INK, 15, true)
	for e: Dictionary in nd:
		var val := ("%d%% / %d%%" % [int(e["have"]), int(e["need"])]) if e["pct"] else ("%s / %s" % [fmt(int(e["have"])), fmt(int(e["need"]))])
		_tip_row(v, e["icon"], e["text"], val, C_GOOD if e["ok"] else C_BAD, 1 if e["ok"] else 0)
		if not e["ok"] and e["icon"] != "family" and not e["pct"]:
			# постройка условия: что сделать прямо сейчас (та же подсказка, что у стрелки просьб и в карточке станции)
			var say := String(need_do(e["p"], String(e.get("tool", ""))).get("say", ""))
			if say != "":
				_tip_text(v, "   → " + say + ".", C_SOFT, 13)
	if met == nd.size():
		_tip_text(v, "Всё готово! Нажмите «Перейти на новый уровень» под табличкой города — когда сами захотите.", C_GOOD, 15, true)
	# пределы — с уже изученными хранилищами (как money_cap/rp_cap), а не голые числа уровня
	_tip_text(v, "На новом уровне казна вмещает %s ден., очков исследований — %s%s, открываются новые исследования." % [fmt(c.money_cap_for(c.level + 1)), fmt(c.rp_cap_for(c.level + 1)), _caps_text(c.level + 1)])
	if met < nd.size():
		if not nd[0]["ok"]:
			_tip_text(v, "Жителей прибавится, если строить дома у дорог и заселять приезжих.", C_INK, 14)
		if not nd[1]["ok"]:
			_tip_text(v, "Счастье поднимают лавки рядом с домами, украшения и памятники — наведите на счастье, там подробнее.", C_INK, 14)
		for i in range(2, nd.size()):
			if not nd[i]["ok"]:
				# что делать по каждой постройке — под её строкой (→ …); закрытое не помещается на полки — там же
				_tip_text(v, "Щёлкните по почтовой станции — в её карточке строки условий нажимаются и ведут прямо к делу.", C_INK, 14)
				break


## «, скрипториев — до 3, школ — до 2» — пределы построек для очков исследований на уровне lvl
func _caps_text(lvl: int) -> String:
	var out := ""
	for t in ["scriptorium", "school", "library", "academy"]:
		var mx: Array = Defs.B[t].get("max", [])
		if mx.is_empty():
			continue
		var n := int(mx[clampi(lvl, 0, mx.size() - 1)])
		if n > 0:
			out += ", %s — до %d" % [String(Defs.B[t].get("gen", t)), n]
	return out


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
	_arrive_rows(v, true)
	var block := String(c.stats.get("arrive_block", ""))
	var wait := c.arrive_wait()
	if block != "":
		_tip_text(v, block, C_BAD, 14, true)
	elif wait != "":
		_tip_text(v, wait, C_BAD, 14, true)
	elif fam_n > 0:
		_tip_text(v, "Нажмите на значок семьи слева вверху и выберите им дом.", C_INK, 14)
	else:
		_tip_text(v, "Повозка привозит новые семьи по большой дороге — только туда, где есть место. Стройте дома у дорог заранее.", C_SOFT, 14)


## Строки о повозке: как часто ходит (и почему чаще) и на сколько семей есть место в домах.
## tip — в мгновенной подсказке (иначе — в карточке станции)
func _arrive_rows(v: Control, tip: bool) -> void:
	var c: City = game.city
	var am: Array = c.arrive_mult()
	var every := "раз в %s ч" % String.num(c.arrive_every(), 1).replace(".", ",")
	var fit := maxi(0, c.free_fit())
	var fit_txt := ("на %d %s" % [fit, _plural(fit, "семью", "семьи", "семей")]) if fit > 0 else "нет"
	if tip:
		_tip_row(v, "horse", "Повозка с семьями", every, C_INK)
		if float(am[0]) < 1.0:
			_tip_text(v, "Чаще обычного: %s." % am[1], C_GOOD, 14)
		_tip_row(v, "housing", "Свободное место в домах", fit_txt, C_GOOD if fit > 0 else C_BAD)
	else:
		v.add_child(_row("horse", "Повозка с семьями", every))
		if float(am[0]) < 1.0:
			v.add_child(_wrap(_label("Чаще обычного: %s." % am[1], 14, true, C_GOOD), 330))
		v.add_child(_row("housing", "Место в домах", fit_txt, C_GOOD if fit > 0 else C_BAD))


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


# ---------- курсор: рисованные курсоры вместо курсоров Windows (assets/ui/ai/cursors, см. scripts/cursors.gd) ----------

const Cursors := preload("res://scripts/cursors.gd")
## Формы курсора с постоянной картинкой. Обычная стрелка (CURSOR_ARROW) меняется по инструменту, «рука» светится при нажатии;
## CURSOR_FORBIDDEN ставится недоступным кнопкам — над ними серая стрелка (нажать нельзя). Текстовый курсор — как в Windows
const CURSOR_FIXED := {Input.CURSOR_WAIT: "wait", Input.CURSOR_BUSY: "wait", Input.CURSOR_MOVE: "move", Input.CURSOR_DRAG: "hand_glow",
	Input.CURSOR_CAN_DROP: "hand", Input.CURSOR_FORBIDDEN: "arrow_grey", Input.CURSOR_VSIZE: "resize_v", Input.CURSOR_HSIZE: "resize_h",
	Input.CURSOR_BDIAGSIZE: "resize_diag", Input.CURSOR_FDIAGSIZE: "resize_diag", Input.CURSOR_HELP: "help", Input.CURSOR_CROSS: "cross"}
var _cursor_hand := ""


## Какой курсор нужен сейчас. Над окнами — стрелка, над кнопками и значками — «рука», над недоступной кнопкой — серая;
## над городом — по инструменту и по тому, что под мышью (_cursor_world). Зажата левая кнопка — стрелка и рука светятся
func _cursor_tick() -> void:
	var px := Cursors.size_for(get_viewport())
	var down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var key := "arrow"
	var ui := mouse_over_ui()
	if game == null or not game.ready_done:
		key = "wait"
	elif ui:
		_cursor_disabled_btn()
	elif root.visible:
		key = _cursor_world()
	if down and key in ["arrow", "hand"]:
		key += "_glow"
	var hand := "hand_glow" if down else "hand"
	if key == _cursor_key and hand == _cursor_hand and px == _cursor_px:
		return
	if px != _cursor_px:
		for sh in CURSOR_FIXED:
			Cursors.put(sh, CURSOR_FIXED[sh], px)
	_cursor_key = key
	_cursor_hand = hand
	_cursor_px = px
	Cursors.put(Input.CURSOR_POINTING_HAND, hand, px)
	Cursors.put(Input.CURSOR_ARROW, key, px)


## Курсор над городом (мышь не над окнами)
func _cursor_world() -> String:
	var t: String = game.tool
	var rig = game.rig
	if game.rot_drag or (rig and rig._orbit):
		return "rotate"                     # поворот постройки (левая зажата и ведут вбок) или камеры (зажатое колёсико)
	if rig and rig._pan and game._rmb_moved > 6.0:
		return "move"                       # тянут карту правой кнопкой
	if t == "":
		# щёлкнуть можно: постройка — откроется карточка, участок с табличкой — купить, потерянная кошка — нашли
		var sto = game.get("stories")
		if sto != null and sto.near_cat(game._mouse_pos):
			return "hand"
		return "hand" if game.plot_fill_key.x >= 0 or not game.pick_building().is_empty() else "arrow"
	if t in ["bulldoze", "move", "copy"]:
		var b: Dictionary = game.pick_building()
		var d: Dictionary = {} if b.is_empty() else game.city.def(b)
		if d.get("fixed", false) or (t == "move" and d.get("wall", false)):
			return "forbidden"                  # почтовую станцию не снести и не перенести, украшение на стене не переносится
		return {"bulldoze": "demolish", "move": "move", "copy": "hand"}[t]
	if t == "erase":
		return "demolish"
	if t in ["road", "path", "plaza"]:
		return "road"
	if t == "move_nature":
		var p: Vector2 = game.hover
		var ok: bool = p != Vector2.INF and game.land.occ_at(p) == 0 and not game.land.is_water(p) and not game.land.is_road(p)
		return "move" if ok else "arrow_red"
	if t == "settle":
		return "people"
	if t == "floor":
		# над домом, которому можно этаж, — «строить»; над домом, которому нельзя, — красная стрелка (у курсора — почему)
		return {1: "build", 0: "arrow_red"}.get(int(game.floor_hover), "arrow")
	if Defs.B.has(t):
		if game.hover != Vector2.INF and String(game.place_info.get("err", "")) != "":
			return "arrow_red"                  # здесь не поставить — призрак красный
		if not game.moving.is_empty():
			return "move"
		return "monument" if Defs.B[t].get("cat", "") == "special" else "build"
	return "arrow"


## Недоступная кнопка (не хватает денег, ещё закрыто) — серая стрелка вместо «руки»: нажать нельзя
func _cursor_disabled_btn() -> void:
	var h := root.get_viewport().gui_get_hovered_control()
	if h is BaseButton and h.has_meta("snd"):
		var want := Control.CURSOR_FORBIDDEN if (h as BaseButton).disabled else Control.CURSOR_POINTING_HAND
		if h.mouse_default_cursor_shape != want:
			h.mouse_default_cursor_shape = want


# ---------- сверху справа ----------

## Сверху справа — отдельные бронзовые медальоны без общей рамки (как в Town to City), с мягкой тенью под каждым
func _top_right() -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_panel = h
	root.add_child(h)
	_put(h, Control.PRESET_TOP_RIGHT, Vector2(-10, 6))
	# перечёркнутое облачко — нет связи с облаком дольше 2 минут (scripts/cloud_badge.gd); обычно скрыто
	cloud_off = CloudBadge.make(self, 40)
	cloud_off.holder = _shadowed(cloud_off)
	cloud_off.holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cloud_off.holder.visible = false
	h.add_child(cloud_off.holder)
	var bell := _round("bell", "События города", 48, func(): _toggle(events_panel); _fill_events())
	h.add_child(_shadowed(bell))
	top_btns["bell"] = bell
	bell_badge = _label("", 15, true, C_CREAM)
	bell_badge.add_theme_color_override("font_outline_color", C_BAD)
	bell_badge.add_theme_constant_override("outline_size", 9)
	bell_badge.position = Vector2(35, -4)
	bell.add_child(bell_badge)
	for t: Array in [["research", "research", "Исследования"], ["finance", "finance", "Финансы"], ["stats", "stats", "Жители и работники"],
			["view", "view", "Обзор: счастье каждого дома и где чего не хватает"], ["photo", "photo", "Фото: спрятать интерфейс (любая клавиша — вернуть)"], ["menu", "menu", "Меню игры"]]:
		var id: String = t[0]
		var b := _round(t[1], t[2], 48, func(): _top_action(id))
		h.add_child(_shadowed(b))
		top_btns[id] = b
	_new_pill(top_btns["research"], "bottom")         # «НОВОЕ» — открылись исследования, которых игрок ещё не видел


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
			_update_pointer()                     # стрелка просьбы — с кнопки на карточку нужного исследования
		"finance":
			_toggle(finance_panel)
			refresh()
		"stats":
			_toggle(stats_panel)
			refresh()
		"view":
			set_overlay("" if overlay != "" else overlay_last)
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
	for x in [events_panel, research_panel, finance_panel, stats_panel, pause_panel, settings_panel, buy_panel, credits_panel, journal_panel]:
		if x:
			x.visible = false
	LegionUi.close_for(self)


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


# ---------- «Обзор» (вместо кругов охвата, решение владельца Д3) ----------
## Счастье каждого дома (рожица и цифра, дом подсвечен цветом) или одна потребность: где она есть (зелёные),
## где нет (красные, значок ✗), значки — лавки этого вида. Подсветку и значки ставит game.cover (cover.gd).
## Окно с режимами и легендой — справа внизу (там, где окно инструмента: при «Обзоре» инструмента нет);
## открыта карточка постройки — окно встаёт левее неё (_place_overlay), чтобы режимы и легенда оставались видны.

var overlay := ""                     # "" — выключен; "happy" — счастье; food, clothes… — одна потребность
var overlay_last := "happy"
var overlay_panel: PanelContainer
var _ov_btns := {}
var _ov_title: Label
var _ov_legend: VBoxContainer
const OV_DATIVE := {"plebs": "плебеям", "artisans": "ремесленникам", "patricians": "патрициям"}
const OV_HAS := {"food": ["Еда есть рядом", "Еды рядом нет"], "clothes": ["Одежда есть рядом", "Одежды рядом нет"],
	"fun": ["Развлечения есть рядом", "Развлечений рядом нет"], "services": ["Услуги есть рядом", "Услуг рядом нет"],
	"goods": ["Товары есть рядом", "Товаров рядом нет"]}


func _overlay_panel() -> void:
	overlay_panel = _panel(null, "bar", 0, 8)
	_put(overlay_panel, Control.PRESET_BOTTOM_RIGHT, Vector2(-10, -BAR_H - 10))
	overlay_panel.custom_minimum_size = Vector2(360, 0)
	overlay_panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	overlay_panel.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	var t := _label("Обзор", 21, false, C_INK, font_title)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(_bare("close", "Закрыть обзор (Esc или правая кнопка)", 30, func(): set_overlay("")))
	v.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for m: String in ["happy"] + Defs.NEED_ORDER + ["water"]:
		var mm := m
		var icon: String = "happy" if m == "happy" else ("water" if m == "water" else Defs.NEEDS[m]["icon"])
		var tip: String = "Счастье каждого дома" if m == "happy" else ("Вода: у каких домов фонтан рядом, а у каких нет" if m == "water" \
			else "%s: где есть, а где нет" % Defs.NEEDS[m]["name"])
		var b := _round(icon, tip, 46, func(): set_overlay(mm))
		row.add_child(b)
		_ov_btns[m] = b
	v.add_child(row)
	_ov_title = _label("", 18, true, C_INK)
	v.add_child(_ov_title)
	_ov_legend = VBoxContainer.new()
	_ov_legend.add_theme_constant_override("separation", 4)
	v.add_child(_ov_legend)


## Включить «Обзор» в режиме mode ("" — выключить). Инструмент при этом убираем: стройка показывает свой охват сама
func set_overlay(mode: String) -> void:
	if mode != "" and game and game.tool != "":
		game.set_tool("")
	overlay = mode
	if mode != "":
		overlay_last = mode
		_close_tray()
	if top_btns.has("view"):
		_set_on(top_btns["view"], mode != "")
	overlay_panel.visible = mode != ""
	if game and game.cover:
		game.cover.refresh()                  # подсветка и значки; при mode != "" — и легенда (fill_overlay)
	if mode != "":
		cover_tip()


## Легенда «Обзора»: что значат цвета и сколько каких домов (числа живые — после каждого пересчёта города)
func fill_overlay() -> void:
	if overlay == "" or overlay_panel == null:
		return
	for m in _ov_btns:
		_set_on(_ov_btns[m], m == overlay)
	_clear(_ov_legend)
	var s: Dictionary = game.cover.sets
	var n: Array = s.get("n", [0, 0, 0])
	if overlay == "happy":
		_ov_title.text = "Счастье каждого дома"
		_ov_row(_face("face_good", 24), "%d%% и больше — хорошо, хватит на 2-й этаж" % Cover.HAPPY_GOOD, n[0])
		_ov_row(_face("face_mid", 24), "%d–%d%% — так себе" % [Cover.HAPPY_BAD, Cover.HAPPY_GOOD - 1], n[1])
		_ov_row(_face("face_bad", 24), "Меньше %d%% — плохо" % Cover.HAPPY_BAD, n[2])
		_ov_legend.add_child(_wrap(_label("Щёлкните по дому — в карточке видно, из чего его счастье. Пустые дома не подсвечены.", 14, false, C_SOFT), 340))
	elif overlay == "water":
		_ov_title.text = "Вода"
		_ov_row(_swatch(Cover.GREEN), "Фонтан рядом: +%d%% счастья" % int(Defs.B["fountain"]["bonus"]), n[0])
		if int(n[1]) > 0:
			_ov_row(_swatch(Cover.GOLD), "Фонтан рядом не работает — нет дороги у входа", n[1])
		_ov_row(_swatch(Cover.RED), "Фонтана рядом нет", n[2])
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		r.add_child(_icon("water", 24))
		r.add_child(_wrap(_label("Значки над крышами — где стоят фонтаны", 15, false, C_INK), 300))
		_ov_legend.add_child(r)
		_ov_legend.add_child(_wrap(_label("Фонтан поит дома вокруг себя. Для «Посёлка» нужен хотя бы один. Пустые дома не подсвечены.", 14, false, C_SOFT), 340))
	else:
		var nd: Dictionary = Defs.NEEDS[overlay]
		_ov_title.text = nd["name"]
		var who := []
		for cl in Defs.CLASS_ORDER:
			if (Defs.CLASSES[cl]["needs"] as Array).has(overlay):
				who.append(OV_DATIVE.get(cl, cl))
		_ov_row(_swatch(Cover.GREEN), OV_HAS[overlay][0], n[0])
		_ov_row(_swatch(Cover.RED), "%s: −%d%% счастья" % [OV_HAS[overlay][1], Defs.MISSING_PENALTY], n[2])
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		r.add_child(_icon(nd["icon"], 24))
		r.add_child(_wrap(_label("Значки над крышами — где стоят такие лавки", 15, false, C_INK), 300))
		_ov_legend.add_child(r)
		_ov_legend.add_child(_wrap(_label("Нужно: %s. Пустые дома не подсвечены." % ", ".join(who), 14, false, C_SOFT), 340))
	_snug(overlay_panel)


func _ov_row(mark: Control, text: String, count: int) -> void:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(mark)
	var l := _label(text, 15, false, C_INK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(l)
	r.add_child(_label("%d %s" % [count, _plural(count, "дом", "дома", "домов")], 15, true, C_SOFT))
	_ov_legend.add_child(r)


## Цветной квадратик для легенды — тот же цвет, что у подсветки домов
func _swatch(col: Color) -> Control:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(5)
	sb.set_border_width_all(2)
	sb.border_color = Color("3a2412")
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(24, 24)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Рожица, нарисованная кодом (зелёная улыбается, золотая — ровно, красная грустит)
func _face(kind: String, size := 26) -> Control:
	var f := FaceIcon.new()
	f.mood = {"face_good": 1, "face_mid": 0, "face_bad": -1}.get(kind, 0)
	f.col = {"face_good": Color("6fbf4a"), "face_mid": Color("e8b53a"), "face_bad": Color("d9553a")}.get(kind, Color("e8b53a"))
	f.custom_minimum_size = Vector2(size, size)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return f


class FaceIcon extends Control:
	var mood := 1                     # 1 — довольный, 0 — так себе, −1 — грустный
	var col := Color("6fbf4a")

	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.5
		var c := size * 0.5
		var ink := Color("3a2412")
		draw_circle(c, r, ink)
		draw_circle(c, r - maxf(1.5, r * 0.12), col)
		draw_circle(c + Vector2(-r * 0.32, -r * 0.2), r * 0.13, ink)
		draw_circle(c + Vector2(r * 0.32, -r * 0.2), r * 0.13, ink)
		var w := maxf(1.6, r * 0.14)
		match mood:
			1:
				draw_arc(c + Vector2(0, -r * 0.08), r * 0.5, PI * 0.2, PI * 0.8, 10, ink, w, true)
			-1:
				draw_arc(c + Vector2(0, r * 0.72), r * 0.42, PI * 1.22, PI * 1.78, 10, ink, w, true)
			_:
				draw_line(c + Vector2(-r * 0.34, r * 0.34), c + Vector2(r * 0.34, r * 0.34), ink, w, true)


## Золотая стрелка вверх, нарисованная кодом: «можно надстроить этаж» (над крышей и на кнопке «Этаж»)
class UpArrow extends Control:
	func _draw() -> void:
		var pts := PackedVector2Array()
		for p: Vector2 in [Vector2(0.5, 0.03), Vector2(0.97, 0.5), Vector2(0.69, 0.5), Vector2(0.69, 0.97), Vector2(0.31, 0.97), Vector2(0.31, 0.5), Vector2(0.03, 0.5)]:
			pts.append(p * size)
		draw_colored_polygon(pts, Color("f2c14e"))
		# светлый блик слева — как у рисованных медальонов
		draw_colored_polygon(PackedVector2Array([Vector2(0.5, 0.12) * size, Vector2(0.5, 0.5) * size, Vector2(0.16, 0.44) * size]), Color("fde39a"))
		var ln := pts.duplicate()
		ln.append(pts[0])
		draw_polyline(ln, Color("3a2412"), maxf(1.5, minf(size.x, size.y) * 0.08), true)


## Значок, нарисованный кодом: рожица (face_good | face_mid | face_bad) или стрелка вверх (up); иначе null
func _drawn(icon: String, size: int) -> Control:
	if icon.begins_with("face_"):
		return _face(icon, size)
	if icon == "up":
		var a := UpArrow.new()
		a.custom_minimum_size = Vector2(size * 0.8, size)
		a.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return a
	return null


# ---------- рожицы после стройки (как в Town to City): над домами, чьё счастье поменялось, — «+5%» и улыбка ----------
# Пул POPS готовых плашек в слое значков: всплывают с задержкой (волна от постройки), поднимаются на 40 точек и гаснут

const POP_T := 2.2                    # сколько живёт рожица, с
const POP_RISE := 40.0                # на сколько точек поднимается
var _pops: Array = []                 # [{n: плашка, face, lbl, pos: точка мира, t0: когда всплыть (мс), on}]


func happy_pop(pos: Vector3, delta: int, delay := 0.0) -> void:
	var e: Dictionary = {}
	for p: Dictionary in _pops:
		if not p["on"]:
			e = p
			break
	if e.is_empty():
		if _pops.size() < Game.POPS_MAX:
			e = _make_pop()
			_pops.append(e)
		else:
			# все заняты — берём ту, что всплыла раньше всех
			e = _pops[0]
			for p: Dictionary in _pops:
				if int(p["t0"]) < int(e["t0"]):
					e = p
	var good := delta > 0
	var f: FaceIcon = e["face"]
	f.mood = 1 if good else -1
	f.col = Color("6fbf4a") if good else Color("d9553a")
	f.queue_redraw()
	var l: Label = e["lbl"]
	l.text = _pct(delta)
	l.add_theme_color_override("font_color", Color("c9ffb0") if good else Color("ffb7a3"))
	e["pos"] = pos
	e["t0"] = Time.get_ticks_msec() + int(delay * 1000.0)
	e["on"] = true
	(e["n"] as Control).visible = false


func _make_pop() -> Dictionary:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := _face("face_good", 24) as FaceIcon
	f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(f)
	var l := _label("", 18, true, C_CREAM)
	l.add_theme_color_override("font_outline_color", Color("2a1a0c"))
	l.add_theme_constant_override("outline_size", 7)
	h.add_child(l)
	h.visible = false
	badge_layer.add_child(h)
	return {"n": h, "face": f, "lbl": l, "pos": Vector3.ZERO, "t0": 0, "on": false}


## Сколько рожиц сейчас в деле (ждут своей очереди или всплывают) — для проверок
func pops_active() -> int:
	var n := 0
	for p: Dictionary in _pops:
		if p["on"]:
			n += 1
	return n


func _place_pops() -> void:
	if _pops.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	var now := Time.get_ticks_msec()
	var show: bool = cam != null and root.visible and not hidden_ui and not (game.rig != null and game.rig.cine)
	for p: Dictionary in _pops:
		if not p["on"]:
			continue
		var n: Control = p["n"]
		var t := float(now - int(p["t0"])) / 1000.0
		if t > POP_T:
			p["on"] = false
			n.visible = false
			continue
		var w: Vector3 = p["pos"]
		if t < 0.0 or not show or cam.is_position_behind(w):
			n.visible = false
			continue
		var k := t / POP_T
		var pt := cam.unproject_position(w)
		n.reset_size()
		n.position = (pt - Vector2(n.size.x * 0.5, n.size.y) - Vector2(0, POP_RISE * ease(k, 0.5))).round()
		# быстро проявляется, держится, мягко гаснет; в начале чуть больше — «выпрыгивает»
		n.modulate.a = clampf(t / 0.15, 0.0, 1.0) * clampf((POP_T - t) / 0.8, 0.0, 1.0)
		n.pivot_offset = n.size * 0.5
		n.scale = Vector2.ONE * (1.0 + 0.25 * maxf(0.0, 1.0 - t / 0.25))
		n.visible = true


# ---------- «НОВОЕ» (как в Town to City): открылось исследованием или рангом, а игрок ещё не смотрел ----------
# Карточка — пока на неё не навели мышь (0,4 с) или не взяли; исследование — пока не навели или не закрыли окно;
# разделы, вкладки, кнопка исследований и «Этаж» — пока внутри есть новое (City.is_new, tips.seen — в сохранении)

## Пометка на кнопке b: "top" — плашка «НОВОЕ» над медальоном, "bottom" — под ним, "card" — в углу карточки,
## "dot" — красная точка (узкие вкладки)
func _new_pill(b: Control, where: String) -> Control:
	var p: Control
	if where == "dot":
		var d := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("d0432c")
		sb.set_corner_radius_all(8)
		sb.set_border_width_all(2)
		sb.border_color = C_CREAM
		d.add_theme_stylebox_override("panel", sb)
		d.size = Vector2(15, 15)
		d.position = Vector2(b.custom_minimum_size.x - 13, -3)
		p = d
	else:
		var pc := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("c4402a")
		sb.set_corner_radius_all(6)
		sb.set_border_width_all(2)
		sb.border_color = Color("fbe6b0")
		sb.content_margin_left = 5
		sb.content_margin_right = 5
		sb.content_margin_top = 0
		sb.content_margin_bottom = 1
		pc.add_theme_stylebox_override("panel", sb)
		pc.add_child(_label("НОВОЕ", 11, true, C_CREAM))
		pc.reset_size()
		var w := b.custom_minimum_size.x
		var sz := pc.get_combined_minimum_size()
		match where:
			"card":
				pc.position = Vector2(w - sz.x - 9, 44)       # в углу картинки, под названием (название не закрывает)
			"corner":
				pc.position = Vector2(w - sz.x * 0.5 - 6, -8)
			"bottom":
				pc.position = Vector2((w - sz.x) * 0.5, b.custom_minimum_size.y - sz.y + 6)
			_:
				pc.position = Vector2((w - sz.x) * 0.5, -sz.y + 6)
		p = pc
	p.name = "new_mark"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in p.find_children("*", "Control", true, false):
		(ch as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.visible = false
	b.add_child(p)
	return p


func _show_new(b: Control, on: bool) -> void:
	var p := b.get_node_or_null("new_mark") as Control
	if p and p.visible != on:
		p.visible = on


## Пометки «НОВОЕ» на разделах, вкладках, кнопках исследований и «Этаж», на карточках открытого свитка
func update_new_marks() -> void:
	if game == null or game.city == null:
		return
	var c: City = game.city
	var play: bool = game.mode in ["new", "play"]
	var n: Dictionary = c.new_counts() if play else {}
	for cid in cats:
		_show_new(cats[cid], int(n.get(cid, 0)) > 0)
	for b in tray_tabs.get_children():
		_show_new(b, int(n.get("commerce|" + String(b.get_meta("sub")), 0)) > 0)
	for b in tray_dtabs.get_children():
		_show_new(b, int(n.get("decor|" + String(b.get_meta("sub")), 0)) > 0)
	_show_new(top_btns["research"], play and c.new_research() > 0)
	_show_new(tool_btns["floor"], play and c.is_new("@floor"))
	floor_badge.visible = not (play and c.is_new("@floor"))      # число готовых домов — когда «НОВОЕ» снято (они на одном месте)
	for b in tray_grid.get_children():
		if b.has_meta("type"):
			_show_new(b, play and c.is_new(b.get_meta("type")))


## Мышь на карточке 0,4 с — карточку посмотрели: «НОВОЕ» с неё снимается
func _card_hovered(b: Button, type: String) -> void:
	if not (game.mode in ["new", "play"]) or not game.city.is_new(type):
		return
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(b) and b.is_hovered() and game.city.mark_seen(type):
		update_new_marks()


# ---------- подпись у курсора, пока ставят лавку (сколько новых домов, сколько уже с такой же) ----------

var cover_box: VBoxContainer
var _cover_l: Array = []              # строки: зелёная, синяя, третья — предупреждение или заметка (кремовая)


func cover_caption(green: String, blue: String, soft := "") -> void:
	_cap3 = [green, blue, soft]
	_caption_refresh()


## Четвёртая строка у курсора — тихий статус инструмента: «Прямая» (прямая линия дороги), «В счёт скверика ✓» /
## «Далеко от дома — не в счёт» (цель истории рядом с домом). "" — нет. Ставит game._update_tool каждый кадр
func cursor_note(text: String, col := Color("fff4dc")) -> void:
	if text == _note and col == _note_col:
		if text != "" and cover_box and cover_box.visible:
			_place_caption()
		return
	_note = text
	_note_col = col
	_caption_refresh()


var _cap3 := ["", "", ""]
var _note := ""
var _note_col := Color("fff4dc")
var _err := ""                            # пятая строка — что не так с местом постройки, красным (3.5)
var _hint := false                        # значок поворота «Z / X» — первые 3 постановки (3.5)
var _hint_row: HBoxContainer


## Почему здесь не поставить — у курсора одной короткой красной строкой (тот же текст, что в панели, тем же кадром);
## hint — показать значок поворота «Z / X»
func cursor_error(text: String, hint := false) -> void:
	if text == _err and hint == _hint:
		return
	_err = text
	_hint = hint
	_caption_refresh()


func _caption_refresh() -> void:
	if cover_box == null:
		cover_box = VBoxContainer.new()
		cover_box.add_theme_constant_override("separation", -2)
		cover_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for col in [Color("b4ffae"), Color("a9d4ff"), Color("ffe3a3"), Color("fff4dc"), Color("ffab96")]:
			var l := _label("", 19, true, col)
			l.add_theme_color_override("font_outline_color", Color("2a1a0c"))
			l.add_theme_constant_override("outline_size", 8)
			l.visible = false
			cover_box.add_child(l)
			_cover_l.append(l)
		_hint_row = HBoxContainer.new()
		_hint_row.add_theme_constant_override("separation", 4)
		_hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hi := TextureRect.new()
		hi.texture = load(AI + "cursors/rotate.png")
		hi.custom_minimum_size = Vector2(26, 26)
		hi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hi.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hint_row.add_child(hi)
		var hl := _label("Z / X — повернуть", 17, true, Color("fff4dc"))
		hl.add_theme_color_override("font_outline_color", Color("2a1a0c"))
		hl.add_theme_constant_override("outline_size", 8)
		_hint_row.add_child(hl)
		_hint_row.visible = false
		cover_box.add_child(_hint_row)
		cover_box.visible = false
		root.add_child(cover_box)
	var tx := [_cap3[0], _cap3[1], _cap3[2], _note, _err]
	var on := false
	var changed := false
	if _hint_row.visible != _hint:
		_hint_row.visible = _hint
		changed = true
	on = _hint
	for i in 5:
		var l: Label = _cover_l[i]
		on = on or tx[i] != ""
		if l.text != tx[i]:
			l.text = tx[i]
			l.visible = tx[i] != ""
			changed = true
	(_cover_l[3] as Label).add_theme_color_override("font_color", _note_col)
	if changed:
		cover_box.reset_size()
	if cover_box.visible != on:
		cover_box.visible = on
	if on:
		_place_caption()


## Подпись справа снизу от курсора; не влезает — по другую сторону курсора, и всегда целиком на экране
func _place_caption() -> void:
	var mp: Vector2 = game._mouse_pos if game._mouse_pos.x >= 0.0 else root.get_local_mouse_position()
	var sz := cover_box.get_combined_minimum_size()
	var p := mp + Vector2(30, 26)
	if p.x + sz.x > root.size.x - 6.0:
		p.x = mp.x - 18.0 - sz.x
	if p.y + sz.y > root.size.y - 6.0:
		p.y = mp.y - 14.0 - sz.y
	p.x = clampf(p.x, 6.0, maxf(6.0, root.size.x - sz.x - 6.0))
	p.y = clampf(p.y, 6.0, maxf(6.0, root.size.y - sz.y - 6.0))
	cover_box.position = p.round()


## Советник один раз (tips.cover_tip): кругов охвата больше нет — подсветка домов, и есть «Обзор»
func cover_tip() -> void:
	var c: City = game.city
	if c.tips.has("cover_tip") or not _tip_free():
		return
	c.tips["cover_tip"] = true
	advisor("Кому достанется лавка", "Кругов охвата больше нет — смотрите на цвет домов. Пока ставите лавку, зелёные дома получат её впервые, а синие уже снабжает такая же лавка: вторая такая же им ничего не прибавит. У курсора написано, сколько новых домов, а значки над крышами показывают, где такие лавки уже стоят. С памятниками и украшениями так же: зелёным домам станет лучше.\n\nКнопка «Обзор» вверху справа (глаз) покажет счастье каждого дома или одну потребность — где еда, одежда и прочее есть, а где нет.")


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
	bar_left = p
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	for t: Array in [["road", "road", "Мостовая", "Мостовая: каменная улица. Ведите с зажатой кнопкой; R — поверх других дорог"], ["path", "path", "Тропа", "Тропа: утоптанная дорожка — почти даром"],
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
	var lt := _label("", 15, false, C_SOFT)        # «Прямая линия: …» — что будет при этом способе
	lt.name = "line_tip"
	lt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lt.custom_minimum_size = Vector2(300, 0)
	lt.visible = false
	vb.add_child(lt)
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
		"linefree", "linestraight":
			game.brush_line = nm == "linestraight"
			# у дорог и у ластика — своя «Прямая линия»; помнится и после перезапуска
			game.settings["line_erase" if game.tool == "erase" else "line_road"] = game.brush_line
			_store_settings()
		"brushround": game.brush_square = false
		"brushsquare": game.brush_square = true
		"undo": game._undo("road")
		"redo": game._redo()
	refresh_tools()
	refresh_undo()


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
		var lt := road_panel.find_child("line_tip", true, false) as Label
		if lt:
			# что сейчас будет: прямая ложится при отпускании, свободная — сразу под кистью
			lt.text = ("Прямая линия: нажмите в начале и отпустите в конце — дорога ляжет при отпускании. «Рисовать свободно» — сразу под кистью." if game.tool != "erase" else "Прямая линия: стирает от точки нажатия до точки отпускания.") if game.brush_line else ""
			lt.visible = not lt.text.is_empty()
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
	bar_mid = p
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	for c: Array in Defs.CATS:
		var cid: String = c[0]
		var short: String = Defs.CAT_SHORT.get(cid, c[1])
		var v := _round_lbl(c[2], short, c[1], 54, func(): _toggle_cat(cid))
		h.add_child(v)
		cats[cid] = v.get_meta("btn")
		_new_pill(cats[cid], "top")
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
		_new_pill(b, "dot")
	tray_dtabs = HBoxContainer.new()
	tray_dtabs.add_theme_constant_override("separation", 4)
	top.add_child(tray_dtabs)
	for ds: Array in Defs.DECOR_SUBS:
		var dn: String = ds[0]
		var b := _round(ds[2], ds[1], 40, func(): open_dsub = dn; _fill_cards())
		b.set_meta("sub", dn)
		tray_dtabs.add_child(b)
		_new_pill(b, "dot")
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
	bar_right = p
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 0)
	p.add_child(pv)
	# «Казна полна» и «Полки полны» — над счётчиками, только пока доход или очки пропадают
	full_money = _label("Казна полна — доход пропадает", 14, true, C_BAD)
	full_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	full_money.mouse_filter = Control.MOUSE_FILTER_PASS
	full_money.tooltip_text = "Казна заполнена до предела — новые денарии пропадают. Потратьте их: дома, этажи, лавки, памятники, украшения, игры в честь богов (с уровня «Посёлок» — в карточке почтовой станции), новые участки земли. Предел растёт с уровнем города и исследованиями хранилищ."
	full_money.visible = false
	pv.add_child(full_money)
	full_rp = _label("Полки полны — очки пропадают", 14, true, C_BAD)
	full_rp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	full_rp.mouse_filter = Control.MOUSE_FILTER_PASS
	full_rp.tooltip_text = "Очков исследований столько, сколько вмещают полки, — новые пропадают. Изучите что-нибудь в свитке исследований вверху справа."
	full_rp.visible = false
	pv.add_child(full_rp)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	pv.add_child(h)
	for t: Array in [["floor", "housing", "Этаж", FLOOR_TIP], ["copy", "copy", "Копия", "Копировать постройку (Ctrl+C) — тот же облик, цвет и поворот. Быстро: наведите на постройку и нажмите F"], ["move", "move", "Перенос", "Перенести постройку, дерево или камень (M)"],
			["bulldoze", "demolish", "Снос", "Снос (Delete): постройки, деревья, камни"]]:
		var tn: String = t[0]
		var v := _round_lbl(t[1], t[2], t[3], 48, func(): game.set_tool("" if game.tool == tn else tn))
		h.add_child(v)
		tool_btns[tn] = v.get_meta("btn")
	# «Этаж»: на доме — золотая стрелка вверх; число — сколько домов готовы к этажу; «НОВОЕ» — пока инструмент не брали
	var fb: Button = tool_btns["floor"]
	var ar := UpArrow.new()
	ar.name = "up"
	ar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ar.position = Vector2(27, 23)
	ar.size = Vector2(17, 19)
	fb.add_child(ar)
	floor_badge = _label("", 15, true, C_CREAM)
	floor_badge.add_theme_color_override("font_outline_color", C_GOOD)
	floor_badge.add_theme_constant_override("outline_size", 9)
	floor_badge.position = Vector2(35, -4)
	fb.add_child(floor_badge)
	_new_pill(fb, "top")
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


## Полоса разделов посередине не заходит под правую (крупный интерфейс, длинная казна, «Полки полны»):
## тогда она сдвигается влево — в просвет у полосы дорог, но не на неё
func _fit_bottom() -> void:
	if bar_left == null or bar_mid == null or bar_right == null or not bar_mid.has_meta("put"):
		return
	var vw := root.size.x
	var wl := maxf(bar_left.size.x, bar_left.get_combined_minimum_size().x)
	var wm := maxf(bar_mid.size.x, bar_mid.get_combined_minimum_size().x)
	var wr := maxf(bar_right.size.x, bar_right.get_combined_minimum_size().x)
	var mid_l := (vw - wm) * 0.5
	var over := mid_l + wm + 8.0 - (vw - 10.0 - wr)              # насколько середина наехала бы на правую
	var room := mid_l - (10.0 + wl + 8.0)                          # сколько места до полосы дорог
	var dx := -ceilf(clampf(over, 0.0, maxf(0.0, room)))
	var off: Vector2 = (bar_mid.get_meta("put") as Array)[1]
	if not is_equal_approx(off.x, dx):
		_put(bar_mid, Control.PRESET_CENTER_BOTTOM, Vector2(dx, off.y))


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
	var names := {"housing": "Жильё", "commerce": "Лавки и мастерские", "farming": "Хозяйство и науки", "decor": "Украшения", "special": "Памятники",
		"military": "Военные постройки Легиона"}
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
		_new_pill(b, "card")
		b.mouse_entered.connect(func(): _card_hovered(b, tp))
		tray_grid.add_child(b)
	var w := minf(1180.0, list.size() * (CARD.x + 10.0) - 10.0)
	_snug(tray)
	# полоса прокрутки (если карточек больше, чем влезает) — ниже лавров карточек
	(tray.find_child("scroll", true, false) as Control).custom_minimum_size = Vector2(w, CARD.y + (20.0 if list.size() * (CARD.x + 10.0) - 10.0 > 1180.0 else 2.0))

	_update_cards()
	update_new_marks()
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
			var rph: float = game.city.rp_per_hour(type) if game and game.city else float(d["rp"])
			t += "\n\nОчки исследований: +%s в час\nРабочие: %s" % [String.num(rph, 1), _jobs_text(d)]
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
	var mx: int = game.city.build_max(type) if game and game.city else -1
	if mx >= 0:
		t += "\nВ городе: %d из %d" % [cnt, mx]
		if cnt > mx:
			t += " — сверх предела не работают: %d" % (cnt - mx)
		var lv: int = game.city.level
		var amx: Array = Defs.B[type]["max"]
		if lv + 1 < Defs.LEVELS.size():           # сколько можно будет на следующем уровне
			t += " (на уровне «%s» — %d)" % [Defs.LEVELS[lv + 1]["name"], int(amx[mini(lv + 1, amx.size() - 1)])]
	else:
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
		if c.build_max(type) >= 0:
			var tip := _card_tip(type)       # «В городе: N из M» меняется с каждой постройкой и рангом
			if b.tooltip_text != tip:
				b.tooltip_text = tip
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
		elif c.cap_err(type) != "":
			# предел уровня города: больше таких не поставить, пока город не вырастет
			var lm := _label("Предел: %d" % c.build_max(type), 12, true, C_SOFT)
			lm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lm.custom_minimum_size = Vector2(84, 0)
			pr.add_child(lm)
			b.add_theme_stylebox_override("normal", _card_box("g_card"))
			_grey(img)
		elif d.get("trophy", false):
			# трофей Легиона — бесплатно
			pr.add_child(_icon("laurels", 22))
			pr.add_child(_label("Трофей", 16, true, C_GOOD))
			b.add_theme_stylebox_override("normal", _card_box("g_card"))
			_grey(img, false)
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
	if game.mode in ["new", "play"] and game.city.mark_seen(type):
		update_new_marks()                    # взяли карточку — она больше не «НОВОЕ»
	if game.city.cap_err(type) != "":
		notify(game.city.cap_err(type), "lock")
		return
	game.end_copy()                           # карточку взяли сами — обычная стройка, не продолжение копии
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
	# город впервые готов к новому уровню — стрелка на кнопку, пока её не нажмут
	if rank_btn and rank_btn.visible and not game.city.tips.has("rank_pressed") and game.tool == "":
		pointer_target = rank_btn
		pointer_text.text = ""                # кнопка сама говорит, что делать; подпись легла бы на просьбы
		return
	# обучение Легиону (4 шага: Казармы → окно → учебный бой → улучшение) — scripts/legion_ui.gd
	var lu := LegionUi.of(self)
	if lu != null and lu.tut_active():
		var lp: Array = lu.tut_pointer()
		if lp[0] != null:
			pointer_target = lp[0]
			pointer_text.text = lp[1]
			return
	if ui_level() < 3:
		return
	# идущая история горожан: стрелка — к тому, чего не хватает по её шагу (лавка, склад, «Этаж», «Обзор → Вода»)
	var sto = game.get("stories")
	if sto != null:
		var sp: Dictionary = sto.pointer_do()
		if not sp.is_empty():
			pointer_target = _do_target(sp)
			if game.tool != "" and Defs.B.has(game.tool):
				pointer_target = null
			pointer_text.text = String(sp.get("tip", ""))
			return
	var goals: Array = game.city.active_goals(1)
	if goals.is_empty():
		return
	# стрелка — к тому, чего не хватает: первая невыполненная часть просьбы (склад → мясная лавка), закрытое —
	# к исследованиям, этажи — к «Этажу», счастье и снабжение — к «Обзору» (need_do / _do_target)
	var rt := _request_target(goals[0])
	pointer_target = rt["target"]
	if game.tool != "" and Defs.B.has(game.tool):
		pointer_target = null
	pointer_text.text = String(rt["tip"])


# ---------- что сделать по условию: просьбы, их части и строки уровня (стрелка, подпись, щелчок) ----------

## Стрелка к просьбе g: {target — куда показать (или null), tip — подпись у стрелки}
func _request_target(g: Dictionary) -> Dictionary:
	var w := request_do(g)
	return {"target": _do_target(w), "tip": String(w.get("tip", "")), "do": w}


## Что сделать по просьбе g: первая невыполненная часть (parts — в виде условий уровня) или вся просьба
func request_do(g: Dictionary) -> Dictionary:
	for pt: Dictionary in g.get("parts", []):
		if game.city.progress_of(pt["p"]) < int(pt.get("n", 1)):
			return need_do(pt["p"], String(pt.get("tool", "")))
	return need_do(g["p"], String(g.get("tool", "")))


## Что сделать по условию p (вид — как у просьб и условий уровня; tool — какую постройку взять):
## {kind, type, rid, layer, tip — подпись у стрелки, say — что сделать, одной фразой}. kind: build — взять постройку type;
## research — она закрыта, нужно исследование rid; research_any — любое исследование; cap — предел уровня; floor — «Этаж»;
## view — «Обзор» со слоем layer; road — «Мостовая»; fam — семья на площади; rank — кнопка нового уровня; {} — делать нечего
func need_do(p: Array, tool := "") -> Dictionary:
	var c: City = game.city
	var arg = p[1] if p.size() > 1 else null
	match String(p[0]):
		"near":
			# фонтан у домов: фонтана ещё нет — поставить; есть — «Обзор → Вода»: где вода есть, а где нет
			if String(arg) == "fountain" and c.count_type("fountain") > 0 and tool == "":
				return {"kind": "view", "layer": "water", "tip": "Обзор",
					"say": "«Обзор» (глаз вверху справа) → «Вода»: красные дома — без воды; поставьте фонтан посреди них"}
			return _do_type(tool if tool != "" else String(arg))
		"count":
			return _do_type(tool if tool != "" else String(arg))
		"houses":
			return _do_type(tool if tool != "" else "house_pleb")
		"light":
			return _do_type(tool if tool != "" else "lamp_post")
		"kind":
			if tool != "" or String(arg) == "decor":
				return _do_type(tool if tool != "" else "bench")
			for t in Defs.B:
				if Defs.B[t]["kind"] == arg and String(Defs.B[t].get("cat", "")) != "":
					return _do_type(t)
		"cls":
			return _do_type(tool if tool != "" else String(Defs.CLASSES[String(arg)]["house"]))
		"store":
			for t in ["warehouse", "butcher"]:
				if c.count_type(t) == 0:
					return _do_type(t)
			return _do_type("butcher")
		"shops":
			return _do_shop(arg)
		"fed":
			# лавок этого вида ещё нет — сначала поставить (или открыть); есть — «Обзор»: где их не хватает
			if _shops_of(String(arg)) == 0:
				return _do_shop(String(arg))
			return {"kind": "view", "layer": String(arg), "tip": "Обзор",
				"say": "«Обзор» (глаз вверху справа) → «%s»: красные дома — без неё; поставьте лавку между ними" % Defs.NEEDS[arg]["name"]}
		"floors":
			var rid := "floor%d" % int(arg)
			if not c.research.has(rid):
				return _do_research(rid, "Этажи открывает исследование «%s»" % Defs.research(rid)["name"])
			return {"kind": "floor", "tip": "Этаж",
				"say": "«Этаж» справа внизу (U): дом должен быть полон, счастье в нём — не ниже %d%%" % int(Defs.FLOOR_HAPPY.get(int(arg), 65))}
		"happy":
			return {"kind": "view", "layer": "happy", "tip": "Обзор", "say": "«Обзор» покажет дома, где плохо; наведите на счастье вверху — там видно, что его поднимет"}
		"pop":
			if not c.arrivals.is_empty() and fam_box != null and fam_box.visible:
				return {"kind": "fam", "tip": "Семья", "say": "Семьи ждут на площади: нажмите на значок семьи и выберите им дом"}
			if String(c.stats.get("arrive_block", "")) != "":
				return {"kind": "view", "layer": "happy", "tip": "Обзор", "say": String(c.stats["arrive_block"])}
			var w := _do_type("house_pleb")
			w["say"] = "Стройте дома заранее: повозка везёт семьи только туда, где есть свободное место"
			return w
		"research":
			return {"kind": "research_any", "tip": "Исследования", "say": "Свиток вверху справа — меню исследований"}
		"road":
			return {"kind": "road", "tip": "Мостовая", "say": "«Мостовая» слева внизу: ведите с зажатой кнопкой"}
		"fam":
			return {"kind": "fam", "tip": "Семья", "say": "Нажмите на значок семьи слева вверху и выберите им дом"}
		"rank":
			var lv := int(arg)
			if c.level >= lv:
				return {}
			if c.rank_ok():
				return {"kind": "rank", "tip": "", "say": "Нажмите «Перейти на новый уровень» под табличкой города"}
			for e: Dictionary in c.rank_needs(lv):
				if not e["ok"] and e.has("p"):
					return need_do(e["p"], String(e.get("tool", "")))
	return {}


## Постройка type: открыта — взять её; закрыта — исследование (доступное: «Мясная лавка» после «Склада»); предел уровня
func _do_type(type: String) -> Dictionary:
	var c: City = game.city
	if not Defs.B.has(type):
		return {}
	var d: Dictionary = Defs.B[type]
	var nm := String(d["name"])
	if not c.unlocked(type):
		var rid := String(d.get("unlock", ""))
		if Defs.research(rid).is_empty():
			return {"kind": "locked", "type": type, "tip": nm, "say": "«%s» откроется %s" % [nm, Defs.unlock_text(rid)]}
		var w := _do_research(rid, "«%s» открывает исследование «%s»" % [nm, Defs.research(rid)["name"]])
		w["type"] = type
		return w
	var cap := c.cap_err(type)
	if cap != "":
		return {"kind": "cap", "type": type, "tip": "Предел уровня", "say": cap}
	return {"kind": "build", "type": type, "tip": nm,
		"say": "«%s» — в разделе «%s» внизу" % [nm, Defs.CAT_SHORT.get(String(d.get("cat", "")), "")]}


## Исследование rid (или то, что надо изучить раньше него); say — что оно откроет
func _do_research(rid: String, say: String) -> Dictionary:
	var c: City = game.city
	var r := Defs.research(rid)
	while r.has("after") and not c.research.has(String(r["after"])):
		rid = String(r["after"])
		r = Defs.research(rid)
	var why := c.can_research(rid)
	if why != "" and why != "Уже изучено":
		say += ". Сейчас: " + why.left(1).to_lower() + why.substr(1)
	return {"kind": "research", "rid": rid, "tip": "Исследования", "say": say}


## Разные лавки (sub — этого вида, null — любые): открытую, которой ещё нет, — взять; нет такой — открыть ближайшую
func _do_shop(sub) -> Dictionary:
	var c: City = game.city
	var locked := ""
	var lk := 99
	for t in Defs.B:
		var d: Dictionary = Defs.B[t]
		if d["kind"] != "shop" or (sub != null and String(d.get("sub", "")) != String(sub)) or c.count_type(t) > 0:
			continue
		if c.unlocked(t):
			return _do_type(t)
		var lv := int(Defs.research(String(d.get("unlock", ""))).get("lvl", 98))
		if lv < lk:
			lk = lv
			locked = t
	if locked != "":
		return _do_type(locked)
	for t in Defs.B:                           # все лавки вида уже стоят — взять любую ещё раз
		if Defs.B[t]["kind"] == "shop" and (sub == null or String(Defs.B[t].get("sub", "")) == String(sub)):
			return _do_type(t)
	return {}


func _shops_of(sub: String) -> int:
	var c: City = game.city
	return c._count(func(b): return c.def(b)["kind"] == "shop" and String(c.def(b).get("sub", "")) == sub)


## Куда показать стрелкой то, что нужно сделать (need_do): карточка (сначала её раздел и вкладка), исследования
## (в открытом окне — сама карточка исследования), «Этаж», «Обзор», уровень города
func _do_target(w: Dictionary) -> Control:
	match String(w.get("kind", "")):
		"build":
			var type := String(w["type"])
			var cat := String(Defs.B[type].get("cat", ""))
			if game.tool == type or cat == "":
				return null
			return _card_or_cat(cat, type)
		"research", "research_any":
			if research_panel.visible:
				return _research_card(String(w.get("rid", "")))
			return top_btns.get("research")
		"cap":
			return rank_btn if rank_btn.visible else hover_level
		"floor":
			return null if game.tool == "floor" else tool_btns.get("floor")
		"view":
			var layer := String(w["layer"])
			if overlay == layer:
				return null
			return _ov_btns.get(layer) if overlay != "" else top_btns.get("view")
		"road":
			return null if game.tool == "road" else road_btns.get("road")
		"fam":
			if game.tool != "settle" and fam_box.visible and fam_box.get_child_count() > 0:
				for x in fam_box.get_child(0).find_children("*", "Button", true, false):
					return x
		"rank":
			return rank_btn
	return null


## Щелчок по строке просьбы или условия уровня: взять нужную постройку, открыть исследования на нужной карточке,
## «Этаж», «Обзор» со слоем, семью на площади
func _do_click(w: Dictionary) -> void:
	match String(w.get("kind", "")):
		"build":
			select_build(String(w["type"]))
		"research", "research_any":
			if not research_panel.visible:
				_top_action("research")
			_scroll_research(String(w.get("rid", "")))
		"floor":
			if game.tool != "floor":
				game.set_tool("floor")
		"view":
			set_overlay(String(w["layer"]))
		"road":
			if game.tool != "road":
				game.set_tool("road")
		"fam":
			if not game.city.arrivals.is_empty():
				game.start_settle(game.city.arrivals[0]["name"])
	_update_pointer()


## Карточка исследования rid в открытом окне (или null)
func _research_card(rid: String) -> Control:
	if rid == "" or research_box == null:
		return null
	for sec in research_box.get_children():
		if sec.is_queued_for_deletion():
			continue                              # окно только что пересобрали: старые ряды ещё не удалены
		for b in sec.find_children("*", "Button", true, false):
			if String(b.get_meta("rid", "")) == rid:
				return b
	return null


## Окно исследований прокрутить к карточке rid (окно собирается в этом кадре — ждём раскладку)
func _scroll_research(rid: String) -> void:
	if rid == "":
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var b := _research_card(rid)
	if b == null:
		return
	var sc := research_box.get_parent() as ScrollContainer
	if sc:
		sc.ensure_control_visible(b)
	_update_pointer()


## Части условия одной строкой: «Склад ✓ · Мясная лавка 0/1» (parts просьбы или условия уровня)
func parts_line(parts: Array) -> String:
	var bits := []
	for pt: Dictionary in parts:
		var have: int
		var need: int
		if pt.has("ok"):                        # строка уровня (City.rank_needs)
			have = int(pt["have"])
			need = int(pt["need"])
		else:
			have = game.city.progress_of(pt["p"])
			need = int(pt.get("n", 1))
		var txt := String(pt.get("text", ""))
		if have >= need:
			bits.append(txt + " ✓")
		elif pt.get("pct", false):
			bits.append("%s %d%%/%d%%" % [txt, have, need])
		else:
			bits.append("%s %s/%s" % [txt, fmt(mini(have, need)), fmt(need)])
	return " · ".join(bits)


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
	_place_pops()
	_place_notes()
	_place_overlay()
	_cursor_tick()
	_hover_tick()
	if tool_panel and tool_panel.visible and Engine.get_process_frames() % 30 == 0:
		refresh_undo()                        # отменить постройку можно 30 с — медаль сереет сама
	if rank_btn and rank_btn.visible:
		# город готов к новому уровню: кнопка и надпись уровня мягко светятся
		var k := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 320.0)
		rank_btn.self_modulate = Color.WHITE.lerp(Color(1.2, 1.16, 1.02), k)
		lbl_level.modulate = Color.WHITE.lerp(Color(1.35, 1.35, 1.1), k)

	if _fold_badge and is_instance_valid(_fold_badge):
		# на свёрнутом свитке новое «✓» мягко светится 2 с
		var gk := 0.0
		if Time.get_ticks_msec() < _fold_glow_until:
			gk = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 140.0)
		_fold_badge.modulate = Color.WHITE.lerp(Color(1.35, 1.4, 1.2), gk)
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
	var tr := HBoxContainer.new()
	tr.add_theme_constant_override("separation", 6)
	tool_title = _label("", 21, false, C_INK, font_title)
	tool_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tool_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tr.add_child(tool_title)
	# 3.6: поставили по ошибке — отменить с полным возвратом (30 с, пока никто не живёт)
	undo_btn = _round("undo", "Отменить постройку", 38, func(): game._undo("place"); refresh_undo())
	undo_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.add_child(undo_btn)
	v.add_child(tr)
	# 3.4: живая картинка постройки — тот же облик и цвет, что у призрака
	thumb_rect = TextureRect.new()
	thumb_rect.custom_minimum_size = Vector2(THUMB.x, THUMB.y)
	thumb_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	thumb_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb_rect.visible = false
	v.add_child(thumb_rect)
	# 3.4: цвет фасада — «Авто» (не как у соседей) или один из 10
	color_box = HBoxContainer.new()
	color_box.add_theme_constant_override("separation", 3)
	color_box.visible = false
	v.add_child(color_box)
	color_box.add_child(_label("Цвет:", 16, true))
	var auto := Button.new()
	auto.text = "Авто"
	auto.focus_mode = Control.FOCUS_NONE
	auto.add_theme_font_size_override("font_size", 14)
	auto.tooltip_text = "Цвет выберет игра — не такой, как у соседних домов (Shift+C — следующий цвет)"
	auto.set_meta("ci", -1)
	auto.pressed.connect(func(): game.set_color(-1); thumb_update())
	color_box.add_child(auto)
	for i in Defs.PALETTE.size():
		var ci := i
		var sw := Button.new()
		sw.custom_minimum_size = Vector2(22, 22)
		sw.focus_mode = Control.FOCUS_NONE
		sw.tooltip_text = "%s (Shift+C — следующий цвет)" % Defs.PALETTE[i]["name"]
		sw.set_meta("ci", i)
		sw.pressed.connect(func(): game.set_color(ci); thumb_update())
		color_box.add_child(sw)
	color_restyle()
	variant_box = HBoxContainer.new()
	variant_box.add_theme_constant_override("separation", 4)
	v.add_child(variant_box)
	gate_check = CheckBox.new()
	gate_check.text = "Калитка посередине (G)"
	gate_check.add_theme_font_size_override("font_size", 16)
	gate_check.focus_mode = Control.FOCUS_NONE
	gate_check.toggled.connect(func(x): game.fence_gate = x; game._fence_key = "")
	gate_check.visible = false
	v.add_child(gate_check)
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
	thumb_rect.visible = false
	color_box.visible = false
	gate_check.visible = false
	undo_btn.visible = Defs.B.has(t)          # у дорог свои «Отменить» и «Вернуть» — в панели кисти
	refresh_undo()
	if t == "":
		return
	if t == "floor":
		var c: City = game.city
		var n: int = c.floor_ready(false).size()
		tool_title.text = "Этаж · готовы домов: %d" % n
		tool_err.text = ""
		tool_keys.text = "Щёлкните по дому со стрелкой — над ним вырастет этаж, туда въедет ещё семья. Ведите с зажатой кнопкой вдоль улицы — этаж получат все готовые дома под курсором, пока хватает денариев.\nГотов дом, когда он полон, а счастье в нём от %d%% (3-й этаж — от %d%%). Esc или правая кнопка — выход." % [int(Defs.FLOOR_HAPPY[2]), int(Defs.FLOOR_HAPPY[3])]
		if not c.research.has("floor2"):
			tool_err.text = "Этажи откроет исследование «%s» (уровень «%s»)" % [Defs.research("floor2")["name"], Defs.LEVELS[int(Defs.research("floor2")["lvl"])]["name"]]
		elif n == 0:
			tool_err.text = "Пока ни один дом не готов: наведите на дом — у курсора будет написано, чего ему не хватает"
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
		thumb_rect.visible = true
		color_box.visible = d["kind"] != "decor" and game.moving.is_empty()
		color_restyle()
		thumb_update()
		var keys := "Повернуть: зажмите левую кнопку и ведите мышь вбок (или Z/X) · правая кнопка — отмена"
		if d.get("seg", false):
			keys = "Тяните с зажатой кнопкой, как дорогу: звенья встанут по линии, цена — у курсора. Щелчок — одно звено (Z/X — повернуть). Esc или правая кнопка посреди — отмена"
			gate_check.visible = d.get("gate", false)
			gate_check.set_pressed_no_signal(game.fence_gate)
		elif d.get("wall", false):
			keys = "Наведите на стену дома — украшение встанет там, где курсор, на любом этаже, мимо окон и дверей · правая кнопка — отмена"
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
				b.set_meta("vi", i)
				# панель не пересобираем: кнопка под мышью остаётся, призрак стоит на месте и сразу меняет фасад
				b.pressed.connect(_facade_pick.bind(vi))
				if game.tool_variant == i:
					b.add_theme_stylebox_override("normal", _medal("medal_on", 34))
				variant_box.add_child(b)
			var rnd := CheckBox.new()
			rnd.text = "Случайный"
			rnd.button_pressed = game.tool_variant < 0
			rnd.add_theme_font_size_override("font_size", 15)
			rnd.toggled.connect(func(x): game.tool_variant = -1 if x else game.next_variant; _facade_restyle())
			variant_box.add_child(rnd)
		if d["kind"] != "decor" and d["kind"] != "farm":
			keys += "\nПривязка к дороге (R): " + ("вкл" if game.snap else "выкл")
		tool_keys.text = keys
	else:
		var names := {"road": "Мостовая", "path": "Тропа", "plaza": "Площадь", "erase": "Ластик", "bulldoze": "Снос", "copy": "Копировать", "move": "Перенести", "move_nature": "Перенести"}
		tool_title.text = names.get(t, t)
		var keys := {"road": "Каменная улица. Ведите с зажатой левой кнопкой. [ ] — размер, Ctrl+Z — отменить, Esc посреди мазка — отменить его.",
			"path": "Утоптанная тропа — самая дешёвая дорога: ею удобно тянуть длинные улицы к окраинам.", "plaza": "Плитка для площадей у рынков и храмов — самая дорогая.", "erase": "Наведите на дорогу — что уберётся, видно красным. Ведите с зажатой кнопкой: дорога уберётся, когда отпустите (Esc посреди — передумать). Звенья заборов под ластиком тоже уберутся.",
			"bulldoze": "Наведите на постройку, дерево или камень — подсветится красным. Щелчок — снести.", "copy": "Щёлкните по постройке — возьмёте такую же: тот же облик, цвет фасада и поворот. Без инструмента — наведите на постройку и нажмите F.",
			"move": "Щёлкните по постройке, дереву или камню и поставьте на новое место.", "move_nature": "Поставьте на новое место. Z/X — повернуть."}
		var txt: String = keys.get(t, "")
		if Defs.ROAD_COST.has(t):
			# цена видна сразу: сколько стоит метр при нынешней кисти — у всех трёх видов дороги
			tool_title.text = "%s · около %s ден. за метр" % [names[t], price_txt(road_price_m(t))]
			txt += "\nМетр при кисти %s: тропа ~%s · мостовая ~%s · площадь ~%s ден." % [
				("%.2f" % game.brush_r).trim_suffix("0").replace(".", ","), price_txt(road_price_m("path")), price_txt(road_price_m("road")), price_txt(road_price_m("plaza"))]
		tool_keys.text = txt + "\nПравая кнопка — отмена"


## Выбран фасад: медали перекрашиваются, призрак меняет облик сразу (game._ghost_frozen), панель не пересобирается
func _facade_pick(vi: int) -> void:
	game.tool_variant = vi
	game.next_variant = vi
	_facade_restyle()
	thumb_update()                            # картинка в панели — сразу, тем же щелчком


func _facade_restyle() -> void:
	for ch in variant_box.get_children():
		if ch is CheckBox:
			(ch as CheckBox).set_pressed_no_signal(game.tool_variant < 0)
		elif ch is Button and ch.has_meta("vi"):
			(ch as Button).add_theme_stylebox_override("normal", _medal("medal_on" if game.tool_variant == int(ch.get_meta("vi")) else "medal", 34))


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
var _stroke_warn: Label


## Подпись у курсора, пока тянут прямую дорогу, ластик или забор (3.1, 3.2): main — «12 м · 42 ден.», warn — вторая
## строка («Денег хватит до сюда»). Гаснет вместе с подписью мазка (stroke_live(…, done))
func stroke_text(main: String, warn := "", col := C_CREAM) -> void:
	stroke_live(0.0, "road", false)           # подпись и казна — как у мазка
	_stroke_lbl.text = main
	_stroke_lbl.add_theme_color_override("font_color", col)
	if _stroke_warn == null:
		_stroke_warn = _label("", 17, true, Color("ffb09a"))
		_stroke_warn.add_theme_color_override("font_outline_color", Color("3a2412"))
		_stroke_warn.add_theme_constant_override("outline_size", 7)
		_stroke_lbl.add_child(_stroke_warn)
	_stroke_warn.text = warn
	_stroke_warn.visible = warn != ""
	_stroke_warn.position = Vector2(0, 24)
	_stroke_lbl.reset_size()


## Медали «Отменить»: в панели постройки — серая, когда отменять нечего (подсказка — что отменится и сколько
## вернётся); у дорог «Отменить» и «Вернуть» — серые, когда стопки пусты (3.6)
func refresh_undo() -> void:
	if undo_btn:
		var u: Dictionary = game.undo_place_info()
		undo_btn.disabled = u.is_empty()
		if u.is_empty():
			undo_btn.tooltip_text = "Отменить постройку можно 30 секунд, пока в ней никто не живёт"
		else:
			undo_btn.tooltip_text = "Отменить: %s, вернётся %s ден." % [u["name"], fmt(float(u["cost"]))]
			if float(u.get("glory", 0.0)) > 0.0:
				undo_btn.tooltip_text += " и %d Славы" % roundi(float(u["glory"]))     # памятник Легиона
		_grey(undo_btn.get_node("ic") as CanvasItem, u.is_empty())
	for nm in ["undo", "redo"]:
		if road_btns.has(nm):
			var b: Button = road_btns[nm]
			var empty: bool = (game.undo_stack if nm == "undo" else game.redo_stack).is_empty()
			if nm == "undo" and not empty:
				empty = String((game.undo_stack.back() as Dictionary).get("t", "road")) == "place"
			b.disabled = empty
			_grey(b.get_node("ic") as CanvasItem, empty)


## Ряд цветов: выбранный — в золотой рамке
func color_restyle() -> void:
	if color_box == null:
		return
	for b in color_box.get_children():
		if not (b is Button) or not b.has_meta("ci"):
			continue
		var ci := int(b.get_meta("ci"))
		var on: bool = ci == int(game.color_user)
		if ci < 0:
			b.custom_minimum_size = Vector2(52, 26)
			b.add_theme_stylebox_override("normal", _box_pill(8, 2, "g_btn_on" if on else "g_btn"))
			b.add_theme_stylebox_override("hover", _box_pill(8, 2, "g_btn_hover"))
			b.add_theme_stylebox_override("pressed", _box_pill(8, 2, "g_btn_on"))
			continue
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Defs.PALETTE[ci]["c"]
			sb.set_corner_radius_all(11)
			sb.set_border_width_all(3 if on else (2 if st == "hover" else 1))
			sb.border_color = C_GOLD if on else (C_SOFT if st == "hover" else Color(0.29, 0.17, 0.09, 0.6))
			b.add_theme_stylebox_override(st, sb)
	thumb_update()


# ---------- живая картинка постройки в панели (3.4) ----------

var _thumb_vp: SubViewport
var _thumb_cam: Camera3D
var _thumb_holder: Node3D
var _thumb_key := ""


func _thumb_make() -> void:
	var vp := SubViewport.new()
	vp.size = THUMB
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
	_thumb_cam = Camera3D.new()
	_thumb_cam.fov = 30
	vp.add_child(_thumb_cam)
	_thumb_holder = Node3D.new()
	vp.add_child(_thumb_holder)
	_thumb_vp = vp
	thumb_rect.texture = vp.get_texture()


## Облик будущей постройки (тип, этаж, фасад, цвет) — как у призрака; картинка перерисовывается один раз, только
## когда облик поменялся (без чтения с видеокарты: ViewportTexture прямо в панели)
func thumb_update() -> void:
	if thumb_rect == null or not thumb_rect.visible or game == null or not Defs.B.has(game.tool):
		return
	var t: String = game.tool
	var pl: Dictionary = game.place_info if String(game.place_info.get("_t", "")) == t else {}
	var d: Dictionary = Defs.B[t]
	var tier := int(pl.get("tier", 1 if d["kind"] == "house" else 0))
	var v := int(pl.get("variant", 0))
	if d["kind"] != "decor" and game.moving.is_empty():
		v = int(game.next_variant)
	var c := int(pl.get("color", maxi(0, int(game.place_color))))
	if int(game.color_user) >= 0 and d["kind"] != "decor":
		c = int(game.color_user)
	if d.get("seg", false):
		v = 1 if game.fence_gate else 0
	var key := "%s:%d:%d:%d" % [t, tier, v, c]
	if key == _thumb_key:
		return
	_thumb_key = key
	if _thumb_vp == null:
		_thumb_make()
	for ch in _thumb_holder.get_children():
		ch.queue_free()
	var g := Parts.ghost(Catalog.make(t, tier, v, c), "outline", Color(0, 0, 0, 0))
	for gi: GeometryInstance3D in g.find_children("*", "GeometryInstance3D", true, false):
		gi.material_override = null
	for ch in g.get_children():
		if ch is MeshInstance3D and (ch as MeshInstance3D).mesh == Parts._special_mesh("#dark") and (ch as Node3D).position.y < -0.05:
			g.remove_child(ch)
			ch.free()
	_thumb_holder.add_child(g)
	var box := Artisau.aabb(g)
	var ctr := box.get_center()
	var rad := maxf(0.3 if d["kind"] == "decor" else 0.6, box.size.length() * 0.5)
	var dir := Vector3(0.62, 0.6, 0.95).normalized()
	_thumb_cam.look_at_from_position(ctr + dir * rad / sin(deg_to_rad(15.0)) * 0.95, ctr, Vector3.UP)
	_thumb_vp.render_target_update_mode = SubViewport.UPDATE_ONCE

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
	if _stroke_warn:
		_stroke_warn.visible = false
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
	row.tooltip_text = "Сколько работников нанять. Чем больше — тем больше домов обслуживает постройка, но каждый работник стоит %s ден. в час (жалованье растёт с уровнем города) и нужен жителям ниже классом" % String.num(c.wage(), 2).replace(".", ",")
	var minus := Button.new()
	minus.text = "−"
	_small(minus)
	minus.focus_mode = Control.FOCUS_NONE
	minus.disabled = h <= 0
	minus.tooltip_text = "Уволить работника"
	minus.pressed.connect(func(): game.happy_action(func(): c.set_hire(b, h - 1), b["pos"]); _fill_info())
	var plus := Button.new()
	plus.text = "+"
	_small(plus)
	plus.focus_mode = Control.FOCUS_NONE
	plus.disabled = h >= mx
	plus.tooltip_text = "Нанять работника"
	plus.pressed.connect(func(): game.happy_action(func(): c.set_hire(b, h + 1), b["pos"]); _fill_info())
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


## Строка карточки, которую можно нажать: прозрачная кнопка поверх (подсветка при наведении, подсказка tip)
func _clickable(row: Control, tip: String, cb: Callable) -> Control:
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in row.find_children("*", "Control", true, false):
		(ch as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(row)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	var e := StyleBoxEmpty.new()
	for st in ["normal", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, e)
	var hov := _box_pill(8, 2, "g_btn_hover")
	hov.modulate_color = Color(1, 1, 1, 0.45)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("hover_pressed", hov)
	b.tooltip_text = tip
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(cb)
	m.add_child(b)
	return m


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
			_cover_rows(b, "")
			if d.get("store", false):
				_store_row(b)
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
			_cover_rows(b, "Радует домов")
		"rp":
			info_box.add_child(_row("research", "Очки исследований в час", "+%.1f" % (c.rp_per_hour(b["type"]) * float(b.get("staff", 1.0))), C_GOOD))
			if b.get("over", false):
				# старый город: таких построек больше, чем можно на этом уровне — лишние не работают (их не сносим)
				info_box.add_child(_wrap(_label("Сверх предела уровня — не работает", 15, true, C_BAD), cw))
				var nl := c.level + 1
				var mx: Array = d.get("max", [])
				while nl < Defs.LEVELS.size() and nl < mx.size() and int(mx[nl]) <= c.build_max(b["type"]):
					nl += 1
				var more := (" Больше заработает на уровне «%s»." % Defs.LEVELS[nl]["name"]) if nl < Defs.LEVELS.size() and nl < mx.size() else ""
				info_box.add_child(_wrap(_label("На уровне «%s» работают %d (первые построенные).%s Сносить не нужно: пока постройка не работает, она ничего не стоит." % [Defs.LEVELS[c.level]["name"], c.build_max(b["type"]), more], 14, false, C_SOFT), cw))
			else:
				info_box.add_child(_hire_row(b))
		"farm":
			info_box.add_child(_row("wheat", "Даёт", {"wheat": "пшеницу", "olives": "оливки", "grapes": "виноград"}[d["makes"]], C_GOOD))
			info_box.add_child(_hire_row(b))
		"store":
			info_box.add_child(_row("arrow", "Разносит товары", Defs.WORD[4]))
			_cover_rows(b, "Снабжает лавок")
			info_box.add_child(_hire_row(b))
		"center":
			tv.add_child(_label("Уровень города: %s" % Defs.LEVELS[c.level]["name"], 14, true, C_SOFT))
			info_box.add_child(_row("scroll", "Почта привозит свитки", "+%s в час" % String.num(float(Defs.LEVELS[c.level].get("rp_h", 0.0)), 1), C_GOOD))
			var nx := c.next_level()
			if not nx.is_empty():
				# чек-лист условий следующего уровня; когда всё готово — кнопка «Перейти на новый уровень»
				var nd := c.rank_needs()
				info_box.add_child(_row("level", "Следующий уровень", "%s · %d из %d" % [nx["name"], c.rank_met(), nd.size()]))
				for e: Dictionary in nd:
					var val := ("%d%% / %d%%" % [int(e["have"]), int(e["need"])]) if e["pct"] else ("%s / %s" % [fmt(int(e["have"])), fmt(int(e["need"]))])
					var r := _row(e["icon"], e["text"], val, C_GOOD if e["ok"] else C_BAD)
					var mk := _icon("check" if e["ok"] else "close", 18)
					mk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					r.add_child(mk)
					# невыполненное условие — щелчком к делу (та же стрелка, что у просьб): постройка, исследование, «Этаж», «Обзор»
					var w: Dictionary = {} if e["ok"] else need_do(e["p"], String(e.get("tool", "")))
					if w.is_empty():
						info_box.add_child(r)
					else:
						info_box.add_child(_clickable(r, String(w.get("say", "")) + ".", func(): _do_click(need_do(e["p"], String(e.get("tool", ""))))))
				if rank_shown():
					var rb := Button.new()
					rb.text = "Перейти на новый уровень"
					rb.icon = ico("level", 32)
					rb.focus_mode = Control.FOCUS_NONE
					rb.add_theme_font_override("font", font_bold)
					rb.add_theme_stylebox_override("normal", _box_pill(16, 6, "g_btn_on"))
					for st in ["font_color", "font_hover_color", "font_pressed_color"]:
						rb.add_theme_color_override(st, C_GOOD)
					rb.pressed.connect(press_rank)
					info_box.add_child(rb)
			_arrive_rows(info_box, false)
			var wait := c.arrive_wait()
			if wait != "":
				info_box.add_child(_wrap(_label(wait, 14, true, C_BAD), 330))
			if c.waiting > 0:
				info_box.add_child(_row("tent", "Ждут жилья", "%d %s" % [c.waiting, _plural(c.waiting, "семья", "семьи", "семей")], C_BAD))
			_fest_rows(info_box)
		"decor":
			info_box.add_child(_row("flower", "Очки украшения", "+%d" % int(d.get("deco", 1)), C_GOOD))
			_cover_rows(b, "Радует домов")
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
		# «Копировать»: сразу в руках такая же постройка — тот же облик, цвет фасада и поворот
		var bc := Button.new()
		bc.text = "Копировать"
		bc.icon = ico("copy", 32)
		bc.tooltip_text = "Взять такую же: тот же облик, цвет фасада и поворот.\nБыстро — наведите на любую постройку и нажмите F"
		bc.pressed.connect(func(): close_panels(); game.copy_building(b))
		h.add_child(bc)
		info_box.add_child(h)


## Лавке нужен склад (3.9): «Товар со склада · 40 м» или «Нет склада рядом — товар не идёт» и «Показать склад»
func _store_row(b: Dictionary) -> void:
	var c: City = game.city
	var st: Dictionary = c.store_for(b)
	if not st.is_empty() and bool(st["ok"]):
		info_box.add_child(_row("warehouse", "Товар со склада", "%d м" % roundi(float(st["d"])), C_GOOD))
	elif not st.is_empty() and bool(st["near"]):
		info_box.add_child(_wrap(_label("Склад рядом не работает: %s — товар не идёт" % c.idle_text(st["b"]), 15, true, C_BAD), 330))
	else:
		info_box.add_child(_wrap(_label("Нет склада рядом — товар не идёт", 15, true, C_BAD), 330))
	if st.is_empty():
		info_box.add_child(_wrap(_label("Постройте склад рядом (раздел «Хозяйство»): со склада разносят товар по лавкам.", 14, false, C_SOFT), 330))
		return
	var w: Dictionary = st["b"]
	var sb := Button.new()
	sb.text = "Показать склад" + ("" if bool(st["near"]) else " (%d м — далеко)" % roundi(float(st["d"])))
	sb.icon = ico("warehouse", 32)
	sb.focus_mode = Control.FOCUS_NONE
	sb.name = "show_store"
	sb.pressed.connect(func():
		if not c.buildings.has(int(w["id"])):
			return
		game.select_building(w)
		game.rig.fly_to(Vector3((w["pos"] as Vector2).x, float(w["y"]), (w["pos"] as Vector2).y))
		open_info(w))
	info_box.add_child(sb)


## Строки карточки об охвате (те же числа, что подсветка домов, Cover.selected_sets): head — сколько своих домов
## (лавок у склада); ниже — сколько из них получают то же и от другой такой же постройки (синие)
func _cover_rows(b: Dictionary, head: String) -> void:
	var c: City = game.city
	var s := Cover.selected_sets(c, b)
	var kind: String = c.def(b)["kind"]
	if head != "":
		var n: int = (s["green"] as Array).size() if kind == "decor" else int(s["own"])
		info_box.add_child(_row("commerce" if kind == "store" else "housing", head, str(n), C_GOOD if n > 0 else C_SOFT))
	var k: int = s["dup"]
	var t: String = {"shop": "Из них уже с такой же лавкой", "monument": "Из них радует и другой такой же",
		"store": "Из них уже с другим складом", "decor": "Украшений уже хватает"}.get(kind, "")
	var blue := Color("2f63a8")
	info_box.add_child(_row("housing" if kind != "store" else "commerce", t, str(k), blue if k > 0 else C_SOFT))
	if k > 0:
		var why := "Синим домам украшений уже хватает — больше не прибавится." if kind == "decor" \
			else "Синие получают то же от другой такой же постройки — им эта ничего не добавляет. Зелёные — только от этой."
		info_box.add_child(_wrap(_label(why, 14, false, C_SOFT), 330))
	var hf: int = s.get("half", 0)
	if hf > 0:
		# +1% за каждые 2 очка: очко этого украшения ждёт следующего рядом
		info_box.add_child(_wrap(_label("Ещё %d %s прибавит вместе со следующим украшением рядом." % [hf, _plural(hf, "дому", "домам", "домам")], 14, false, C_SOFT), 330))


## Карточка станции: игры в честь богов (с уровня «Посёлок») — идут ли, когда снова и кнопка «Устроить игры — N ден.»
func _fest_rows(v: Control) -> void:
	var c: City = game.city
	if not c.fest_open():
		return
	var F: Dictionary = Defs.FESTIVAL
	v.add_child(_divider(14))
	if c.fest_left > 0:
		v.add_child(_row("laurels", "Игры в честь богов", "идут, ещё %d ч" % c.fest_left, C_GOOD))
		v.add_child(_wrap(_label("Весь город празднует: счастье всех домов +%d%%, повозка с семьями ходит чаще." % int(F["happy"]), 14, false, C_GOOD), 330))
		return
	var why := c.can_festival()
	var st := "можно устроить"
	if c.fest_cd > 0:
		st = "через %d ч" % c.fest_cd
	elif why != "":
		st = "мало денариев" if why.begins_with("Не хватает") else ""
	v.add_child(_row("laurels", "Игры в честь богов", st, C_GOOD if why == "" else (C_BAD if why.begins_with("Не хватает") else C_SOFT)))
	var fb := Button.new()
	fb.name = "fest_btn"
	fb.text = "Устроить игры — %s ден." % fmt(c.fest_price())
	fb.icon = ico("laurels", 32)
	fb.focus_mode = Control.FOCUS_NONE
	fb.disabled = why != ""
	fb.tooltip_text = why if why != "" else "Устроить игры в честь богов"
	fb.pressed.connect(press_festival)
	v.add_child(fb)
	var txt := "На сутки: счастье всех домов +%d%%, повозка ходит чаще. Цена зависит от налогов: %s." % [int(F["happy"]), fest_rates()]
	v.add_child(_wrap(_label(why if why != "" else txt, 14, why != "", C_BAD if why.begins_with("Не хватает") else C_SOFT), 330))


## Почём игры с жителя каждого класса (City.fest_price): «по 3 ден. за плебея, 5,5 — за ремесленника, 11,3 — за патриция»
func fest_rates() -> String:
	var c: City = game.city
	var who := {"plebs": "плебея", "artisans": "ремесленника", "patricians": "патриция"}
	var out := []
	for cl in who:
		var tax := float(Defs.CLASSES[cl]["tax"]) * (1.25 if cl == "patricians" and c.research.has("taxes1") else 1.0)
		var x := roundf(tax * float(Defs.FESTIVAL["tax_k"]) * 10.0) / 10.0
		var v := (str(roundi(x)) if is_equal_approx(x, roundf(x)) else String.num(x, 1)).replace(".", ",")
		out.append(("по %s ден. за %s" if out.is_empty() else "%s — за %s") % [v, who[cl]])
	return ", ".join(out)


## «Устроить игры» в карточке станции: платим, город празднует (звук — только монетки)
func press_festival() -> void:
	if game.city.festival():
		game.sound.ui("coins")
	refresh()


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
	if c.research.has("floor2"):
		var tk := _wrap(_label("Много домов сразу — инструментом «Этаж» справа внизу (U): ведите мышью по улице", 13, false, C_SOFT), cw)
		tk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_box.add_child(tk)


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
	if CityName.close(self):
		return true                              # окно «Название города» — поверх всего: закрывается первым, одно
	var any := info_panel.visible or advisor_panel.visible or buy_panel.visible
	for x in [events_panel, research_panel, finance_panel, stats_panel, pause_panel, settings_panel, credits_panel, journal_panel]:
		if x == null:
			continue
		any = any or x.visible
		x.visible = false
	any = LegionUi.close_for(self) or any        # окно «Легион» (scripts/legion_ui.gd)
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
	# «Понятно» справа; слева от него — «Пропустить обучение», если совет — шаг обучения (advisor(…, skip))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	adv_skip = Button.new()
	adv_skip.text = "Пропустить обучение"
	adv_skip.focus_mode = Control.FOCUS_NONE
	adv_skip.add_theme_font_size_override("font_size", 14)
	adv_skip.visible = false
	adv_skip.pressed.connect(func():
		advisor_panel.visible = false
		if _adv_skip_cb.is_valid():
			_adv_skip_cb.call()
		_update_pointer())
	row.add_child(adv_skip)
	var ok := Button.new()
	ok.text = "Понятно"
	ok.pressed.connect(func(): advisor_panel.visible = false)
	row.add_child(ok)
	adv_ok = ok


## Совет: заголовок и текст; skip — совет начинает обучение: рядом с «Понятно» кнопка «Пропустить обучение»
func advisor(title: String, text: String, skip := Callable()) -> void:
	adv_title.text = title
	adv_text.text = text
	adv_skip.text = "Пропустить обучение"     # другое действие (Gfx: «Включить «Низкую»») ставит свою надпись после
	adv_skip.add_theme_font_size_override("font_size", 14)
	adv_ok.text = "Понятно"
	_adv_skip_cb = skip
	adv_skip.visible = skip.is_valid()
	advisor_panel.visible = true


func _notes() -> void:
	notes_box = VBoxContainer.new()
	_put(notes_box, Control.PRESET_CENTER_TOP, Vector2(0, NOTES_Y))     # под фишками классов, не на них
	notes_box.custom_minimum_size = Vector2(440, 0)
	notes_box.add_theme_constant_override("separation", 5)
	notes_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(notes_box)


## «Обзор» справа внизу; открыта карточка постройки — встаём левее неё (карточка рисуется поверх и закрыла бы
## режимы и легенду, а легенда сама зовёт щёлкнуть по дому). Сдвиг — через _put: _snug в fill_overlay его сохранит
func _place_overlay() -> void:
	if overlay_panel == null or not overlay_panel.visible:
		return
	var x := -10.0
	if info_panel.visible:
		x = minf(-10.0, info_panel.position.x - root.size.x - 12.0)
		x = maxf(x, overlay_panel.size.x + 10.0 - root.size.x)        # не уезжать за левый край
	var m: Array = overlay_panel.get_meta("put", [Control.PRESET_BOTTOM_RIGHT, Vector2(-10, -BAR_H - 10)])
	if not is_equal_approx((m[1] as Vector2).x, x):
		_put(overlay_panel, Control.PRESET_BOTTOM_RIGHT, Vector2(x, -BAR_H - 10))


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
	var rc = game.get("rank_cine") if game else null
	if icon == "level" and rc != null and rc.covers_toast():
		bell_count += 1                   # новый ранг покажет ролик — всплывашка не нужна, только колокольчик
		bell_badge.text = str(bell_count)
		return
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
	# окно закрыли — всё, что в нём было новым, игрок видел: «НОВОЕ» с исследований снимается
	research_panel.visibility_changed.connect(func():
		if not research_panel.visible and game and game.city and game.mode in ["new", "play"]:
			for r in Defs.RESEARCH:
				game.city.mark_seen_r(r["id"])
			update_new_marks()
			# изучили второй этаж — про «Этаж» советник скажет, когда окно закрыто. Через кадр: Esc, правая кнопка
			# и щелчок по карте закрывают окна (close_panels) вместе с советником — совет погас бы, не показавшись.
			# Сначала «Легион собран!» (изучили «Легион»), потом остальные советы: они ждут, пока советник занят
			var lu := LegionUi.of(self)
			if lu != null:
				lu._update_button.call_deferred()
			_once_tips.call_deferred())


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
			b.set_meta("rid", id)                 # стрелка просьбы находит карточку нужного исследования
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
			if game.mode in ["new", "play"] and c.is_new_r(id):
				# «НОВОЕ» — открылось новым рангом или изученным раньше; навели мышь — посмотрели
				var pm := _new_pill(b, "corner")
				pm.visible = true
				b.mouse_entered.connect(func():
					if game.city.mark_seen_r(id):
						pm.visible = false
						update_new_marks())
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
	var tx := []
	for cl in ["plebs", "artisans", "patricians"]:
		tx.append(String.num(float(Defs.CLASSES[cl]["tax"]), 1).replace(".", ","))
	var hint := _label("Налог платит каждый житель: плебей — %s, ремесленник — %s, патриций — %s денария в час; счастливые платят больше. Содержание: каждая постройка (кроме домов и украшений) стоит в час %s%% своей цены, а каждый работник — %s ден. жалованья; жалованье растёт с уровнем города. Казна не вмещает больше предела — поднимайте уровень города и изучайте хранилища." % [tx[0], tx[1], tx[2], String.num(Defs.UPKEEP * 100.0, 1).replace(".", ","), String.num(c.wage(), 2).replace(".", ",")], 14, false, C_SOFT)
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
	Account.me().quit_game()                  # сначала город уходит в облако (не дольше нескольких секунд)


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
	Gfx.settings_block(self, v)               # «Графика» (4 уровня), «Показывать FPS», видеокарта — scripts/gfx.gd
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
	# аккаунт (почта, облако, «Выйти») и «Уничтожить город…» с тремя подтверждениями — scripts/account_ui.gd
	AccountUi.settings_block(self, v)


# ---------- титры ----------

## Кто и что сделал для игры (по файлам CREDITS/LICENSE в assets). Разделы: [заголовок, значок, [[что, кто · лицензия], …]]
const CREDITS := [
	["Игра", "laurels", [
		["CivCity — уютный римский город", "замысел, игровой дизайн и решения — Leonov Labs"],
		["Программирование, мир, жители и интерфейс", "Leonov Labs вместе с Claude (Anthropic)"]]],
	["Город и постройки", "housing", [
		["Synty Studios — POLYGON Ancient Empire", "3D-модели домов, лавок, храмов, деревьев и украшений · лицензия Synty Store"],
		["Artisau — Ancient Greece Low Poly", "статуи и мелкие предметы, шатры, слон и Минотавр в боях Легиона · CC0"]]],
	["Жители и животные", "family", [
		["Quaternius — Universal Base Characters, Modular Character Outfits", "жители города · CC0"],
		["Quaternius — Universal Animation Library", "походка, работа и отдых жителей · CC0"],
		["Quaternius — коровы, ослы, лошади, овцы, кошки, волк, бык", "животные в городе и звери в боях Легиона · CC0"],
		["jeremy — «Duck» (Poly Pizza)", "утки на прудах · CC-BY 3.0"],
		["Poly by Google — «Duck» (Poly Pizza)", "лебедь на прудах (перекрашен) · CC-BY 3.0"]]],
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
		["Kenney — Interface Sounds, RPG Audio, UI Audio", "щелчки, стройка, монеты, звуки боя · CC0 · kenney.nl"],
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
	var by := _label("Создано Leonov Labs", 18, true, C_INK)
	by.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(by)
	var tg := LinkButton.new()
	tg.text = "Наш канал в Telegram — t.me/leonovlabs"
	tg.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	tg.add_theme_font_override("font", font_bold)
	tg.add_theme_font_size_override("font_size", 15)
	tg.add_theme_color_override("font_color", C_SOFT)
	tg.add_theme_color_override("font_hover_color", C_INK)
	tg.focus_mode = Control.FOCUS_NONE
	tg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tg.pressed.connect(func(): OS.shell_open("https://t.me/leonovlabs"))
	col.add_child(tg)
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
	Gfx.settings_refresh(self)
	AccountUi.settings_refresh(self)
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
	ok.name = "ok"
	ok.text = "Купить"
	ok.icon = ico("coins", 32)
	ok.pressed.connect(func():
		if game.city.buy_plot(buy_plot):
			game._update_plot_signs()
			buy_panel.visible = false
		else:
			ask_buy(buy_plot))                    # не купили — почему, пишем тут же (без всплывашек)
	h.add_child(ok)
	var no := Button.new()
	no.text = "Не сейчас"
	no.pressed.connect(func(): buy_panel.visible = false)
	h.add_child(no)
	v.add_child(h)


## Окно покупки участка. Цена выше предела казны — так и пишем (какой уровень или исследование поможет), «Купить» гаснет;
## просто мало денариев — сколько в казне сейчас
func ask_buy(p: Vector2i) -> void:
	buy_plot = p
	var c: City = game.city
	var price := c.plot_price()
	var t := "Участок 64 × 64 м за краем вашей земли. Купить его за %s денариев? На нём можно будет строить. Каждый следующий участок — дороже." % fmt(price)
	var over := float(price) > c.money_cap()
	if over:
		t += "\n\n" + plot_cap_note()
	elif c.money < float(price):
		t += "\n\nВ казне пока %s ден. — накопите ещё %s." % [fmt(c.money), fmt(ceilf(float(price) - c.money))]
	(buy_panel.find_child("text", true, false) as Label).text = t
	(buy_panel.find_child("ok", true, false) as Button).disabled = over
	buy_panel.visible = true


## Участок дороже, чем вмещает казна: на каком уровне города он станет по карману (или с «Новым хранилищем денег»)
func plot_cap_note() -> String:
	var c: City = game.city
	var price := float(c.plot_price())
	var t := "Сейчас казна вмещает только %s ден. — столько не скопить." % fmt(c.money_cap())
	var lv := ""
	for l in range(c.level + 1, Defs.LEVELS.size()):
		if c.money_cap_for(l) >= price:
			lv = Defs.LEVELS[l]["name"]
			break
	# хранилище, которое можно изучить уже сейчас (вдвое больше казна) — если его хватит
	var vault := ""
	for id in ["vault1", "vault2"]:
		var r := Defs.research(id)
		if c.research.has(id):
			continue
		if c.level >= int(r["lvl"]) and (not r.has("after") or c.research.has(r["after"])) and c.money_cap() * 2.0 >= price:
			vault = r["name"]
		break
	if lv != "":
		t += " Участок станет по карману на уровне «%s»" % lv + (" или когда изучите «%s»." % vault if vault != "" else ".")
	elif vault != "":
		t += " Изучите «%s» — казна станет вдвое больше." % vault
	return t


# ---------- обновление ----------

func refresh() -> void:
	if game == null or game.city == null:
		return
	var c: City = game.city
	lbl_level.text = Defs.LEVELS[c.level]["name"]          # подсказка — мгновенная, _tip_level
	lbl_pop.text = fmt(c.stats["pop"])
	lbl_happy.text = "%d%%" % int(c.stats["happy"])
	lbl_day.text = "День %d" % (c.day + 1)
	show_city_name()
	lbl_money.text = "%s / %s" % [fmt(c.money), fmt(c.money_cap())]
	lbl_money.tooltip_text = "Денарии в казне / предел казны"
	var net := float(c.stats.get("income", 0.0)) - float(c.stats.get("upkeep", 0.0))
	lbl_income.text = ("+" if net >= 0 else "") + fmt(net)
	lbl_income.tooltip_text = "Доход за час"
	lbl_income.add_theme_color_override("font_color", C_GOOD if net >= 0 else C_BAD)
	lbl_rp.text = "%s / %s" % [fmt(c.rp), fmt(c.rp_cap())]
	lbl_rp.tooltip_text = "Очки исследований / предел. Дают почта на станции, скрипторий, школа, библиотека"
	lbl_rp_day.text = "+%.1f" % float(c.stats.get("rp_day", 0.0)) if float(c.stats.get("rp_day", 0.0)) > 0.0 else ""
	for sb in speed_btns:
		_set_on(sb[0], is_equal_approx(game.speed, sb[1]))
	_update_full_marks()
	_update_rank_ui()
	_update_floor_btn()
	update_new_marks()
	_fit_bottom()                             # казна длиннее, «Полки полны» — правая полоса шире
	_fill_classes()
	_fill_families()
	_fill_tasks()
	_once_tips()
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


## «Казна полна — доход пропадает» / «Полки полны — очки пропадают»: казна или полки у предела, а прибавка есть
func _update_full_marks() -> void:
	var c: City = game.city
	var play: bool = not (game.mode in ["demo", "menu"])
	var net := float(c.stats.get("income", 0.0)) - float(c.stats.get("upkeep", 0.0))
	var m_on := play and c.money >= c.money_cap() - 0.5 and net > 0.0
	var r_on := play and c.rp >= c.rp_cap() - 0.05 and float(c.stats.get("rp_day", 0.0)) > 0.0
	if full_money.visible != m_on or full_rp.visible != r_on:
		full_money.visible = m_on
		full_rp.visible = r_on
		var r1 := Defs.research("research1")
		full_rp.tooltip_text = "Очков исследований столько, сколько вмещают полки, — новые пропадают. Изучите что-нибудь в свитке исследований вверху справа." \
			+ (("\nИли изучите «%s» — полки вместят вдвое больше." % r1["name"]) if not c.research.has("research1") and c.level >= int(r1["lvl"]) else "")
		# куда пустить денарии: игры — когда открыты, участки — когда следующий не дороже предела казны
		var ways := "дома, этажи, лавки, памятники, украшения"
		if c.fest_open():
			ways += ", игры в честь богов (в карточке почтовой станции)"
		if _plot_fits():
			ways += ", новые участки земли"
		full_money.tooltip_text = "Казна заполнена до предела — новые денарии пропадают. Потратьте их: %s. Предел растёт с уровнем города и исследованиями хранилищ." % ways
		_snug(full_money.get_parent().get_parent() as Control)


## Кнопка «Этаж»: до «Второго жилого этажа» серая (в подсказке — чем откроется); потом число — сколько домов готовы
## к этажу (полные и счастливые; денариев может и не хватать — тогда над домом красная цена)
func _update_floor_btn() -> void:
	var c: City = game.city
	var fb: Button = tool_btns["floor"]
	var open := c.research.has("floor2")
	var n: int = c.floor_ready(false).size() if open and game.mode in ["new", "play"] else 0
	var txt := str(n) if n > 0 else ""
	if floor_badge.text != txt:
		floor_badge.text = txt
	var tip := FLOOR_TIP + ("\nГотовы к этажу сейчас: %d" % n if open else "")
	if not open:
		tip = "Этаж (U): надстроить этаж полному дому, где жителям хорошо. Откроется исследованием «%s» (уровень «%s»)" % [
			Defs.research("floor2")["name"], Defs.LEVELS[int(Defs.research("floor2")["lvl"])]["name"]]
	if fb.tooltip_text != tip:
		fb.tooltip_text = tip
	if game.tool == "floor" and tool_panel.visible:
		_fill_tool_panel()                    # «готовы домов: N» — живое
	if bool(fb.get_meta("open", true)) != open or not fb.has_meta("open"):
		fb.set_meta("open", open)
		_grey(fb.get_node("ic"), not open)
		(fb.get_node("up") as CanvasItem).modulate = Color.WHITE if open else Color(0.62, 0.6, 0.56, 0.75)


## Советник один раз (tips.floor_tool): этажи — инструментом «Этаж», без карточки каждого дома
func floor_tip() -> void:
	var c: City = game.city
	if c.tips.has("floor_tool") or not c.research.has("floor2") or not _tip_free():
		return
	c.tips["floor_tool"] = true
	advisor("Этаж — без карточки дома", "Надстраивать этажи теперь удобнее: кнопка «Этаж» справа внизу (или клавиша U). Над каждым домом, которому можно этаж, встанет золотая стрелка с ценой, а сам дом засветится зелёным. Щёлкните по такому дому — или ведите мышью с зажатой кнопкой вдоль улицы: этаж получат все готовые дома под курсором, пока хватает денариев.\n\nГотов дом, когда он полон, а счастье в нём от %d%% (для третьего этажа — от %d%%). Наведите на дом без стрелки — у курсора будет написано, чего ему не хватает. Число на кнопке — сколько домов готовы сейчас. Выйти — Esc или правая кнопка." % [int(Defs.FLOOR_HAPPY[2]), int(Defs.FLOOR_HAPPY[3])])


## Следующий участок земли по карману: продаётся (есть табличка) и не дороже предела казны
func _plot_fits() -> bool:
	var c: City = game.city
	return float(c.plot_price()) <= c.money_cap() and not game.plot_signs.is_empty()


## Можно ли сейчас показать совет советника (один раз на механику): своя игра, обучение кончилось,
## советник и ролик свободны
func _tip_free() -> bool:
	if game == null or not (game.mode in ["new", "play"]) or game.shot_path != "" or not visible or not root.visible:
		return false
	if game.tutorial and game.tutorial.active():
		return false
	if advisor_panel.visible:
		return false
	var rc = game.get("rank_cine")
	return rc == null or (rc.cine.is_empty() and rc.pending.is_empty())


## Советы один раз: город готов к новому уровню; казна полна; полки полны
func _once_tips() -> void:
	var c: City = game.city
	if not _tip_free():
		return
	if rank_btn.visible and not c.tips.has("rank_tip"):
		c.tips["rank_tip"] = true
		var nx := c.next_level()
		advisor("Город готов к новому уровню!", "Все условия для уровня «%s» выполнены. Город сам не растёт: нажмите кнопку «Перейти на новый уровень» под табличкой города (или в карточке почтовой станции) — когда сами захотите.\n\nНовый уровень откроет новые исследования, казна станет вместительнее. Условия следующего уровня всегда видно, если навести мышь на уровень города." % nx.get("name", ""))
		return
	if c.fest_open() and int(c.stats.get("pop", 0)) > 0 and not c.tips.has("fest_tip"):
		c.tips["fest_tip"] = true
		advisor("Игры в честь богов", fest_note())
		return
	if c.research.has("floor2") and not c.tips.has("floor_tool") and not research_panel.visible:
		floor_tip()                           # изучили второй этаж (или старый город после обновления) — один раз про «Этаж»
		return
	if full_money.visible and not c.tips.has("full_money"):
		c.tips["full_money"] = true
		var fest := " Или устройте игры в честь богов — в карточке почтовой станции." if c.fest_open() else ""
		# участки — только когда следующий по карману (дороже предела казны его не купить)
		var land := ", участки земли за краем своей" if _plot_fits() else ""
		var vault := " и изучите «%s»" % Defs.research("vault1")["name"] if not c.research.has("vault1") else ""
		advisor("Казна полна", "Казна заполнена до предела — новые денарии пропадают. Пустите их в дело: новые дома и этажи, лавки, украшения и памятники%s.%s Чтобы казна вмещала больше, поднимайте уровень города%s." % [land, fest, vault])
		return
	if full_rp.visible and not c.tips.has("full_rp"):
		c.tips["full_rp"] = true
		advisor("Полки полны", "Очков исследований столько, сколько вмещают полки, — новые пропадают. Изучите что-нибудь в свитке исследований вверху справа. Полки вырастут на новом уровне города и с исследованием «Новые полки для свитков».")
		return
	# название: сервер дал городу имя сам (игрок его ещё не выбирал) — один раз, когда на экране ничего не открыто;
	# rename — сервер уже умеет менять название (старый сервер его не шлёт: совет не тратим на смену, которая не выйдет)
	var me: Dictionary = LegionNet.me().me_state
	if not c.tips.has("name_tip") and not me.is_empty() and bool(me.get("rename", false)) and not bool(me.get("custom", true)) and _screen_free():
		c.tips["name_tip"] = true
		advisor("Как назовём город?", "Дайте городу имя — щёлкните по табличке с названием вверху слева. Это имя увидят соперники и таблица лучших городов.")


## Советник один раз (tips.fest_tip), когда открылись игры в честь богов: что дают, сколько стоят, где кнопка
func fest_note() -> String:
	var c: City = game.city
	var F: Dictionary = Defs.FESTIVAL
	var often := "раз в двое суток" if int(F["cd"]) == 48 else "раз в %d ч" % int(F["cd"])
	return ("Город дорос до уровня «%s» — теперь можно устраивать игры в честь богов. Целые сутки весь город празднует: счастье всех домов на %d%% выше, а повозка с семьями ходит чаще.\n\n" \
		+ "Чем больше налогов платит город, тем дороже игры: %s (сейчас — %s ден.). Устраивать их можно %s. Щёлкните по почтовой станции — кнопка «Устроить игры» в её карточке.") \
		% [Defs.LEVELS[int(F["lvl"])]["name"], int(F["happy"]), fest_rates(), fmt(c.fest_price()), often]


## Что поменялось в старом городе после обновления темпа (советник один раз, city.tips.v22_pace)
func pace_note() -> String:
	var c: City = game.city
	var t := "Аве! В городе кое-что поменялось — коротко о главном:\n\n"
	t += "• Новый уровень город больше не получает сам. Когда выполнены все условия — жители, счастье и нужные постройки, — под табличкой города появится кнопка «Перейти на новый уровень». Список условий — если навести мышь на уровень города.\n"
	t += "• Повозка везёт семьи только туда, где есть свободное место. Если мест нет, приедет одна семья «ищет жильё» — значит, пора строить. Счастливый город (от 70%) зовёт семьи чаще.\n"
	t += "• Налоги стали ниже, а жалованье работникам и содержание построек растут вместе с городом — денарии снова стоит беречь.\n"
	t += "• Школ, библиотек и академий теперь можно держать ограниченное число — по уровню города, как скрипториев."
	var oc := c.over_cap()
	if not oc.is_empty():
		var by := {}
		for id in oc:
			var nm := String(Defs.B[c.buildings[id]["type"]].get("gen", "построек"))
			by[nm] = int(by.get(nm, 0)) + 1
		var parts := []
		for nm in by:
			parts.append("%s — %d" % [nm, by[nm]])
		t += " Сверх предела у вас: %s. Они остаются на месте, но не работают и ничего не стоят, пока город не вырастет — сносить их не нужно." % ", ".join(parts)
	return t


## Событие только в колокольчик: число на значке, без всплывашки
func bell(_text: String, _icon := "info") -> void:
	if events_panel.visible:
		_fill_events()
		return
	bell_count += 1
	bell_badge.text = str(bell_count)


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
	var sto = game.get("stories")
	var story: bool = sto != null and (not sto.row_info().is_empty() or sto.journal_any() or not sto.orders.row_info().is_empty())   # история горожан — золотая строка сверху, заказ старосты — под ней
	tasks_panel.visible = (not goals.is_empty() or story) and game.mode != "demo" and ui_level() >= 3
	if _fold_city != c:
		_fold_city = c                           # другой город (новая игра, загрузка) — счёт «✓» с нуля
		_fold_done0 = c.goals_done.size()
	if tasks_panel.visible:
		if tasks_folded():                       # свёрнут — тот же свиток, валики сошлись: одна строка
			_fill_tasks_folded(goals)
		else:
			_fill_tasks_body(goals)
	# свиток по содержимому: прикрепить заново уже ПОСЛЕ заполнения (иначе он сжимается до пустого и
	# просьбы вылезают за нижний валик) и ещё раз через кадр, когда перенос строк уже посчитан
	_snug(tasks_panel)
	_refit(tasks_panel)


# ---------- свиток просьб сворачивается (отзыв 17): узкая полоска «Просьбы · 3», сам не разворачивается ----------

var _fold_city: City = null
var _fold_done0 := 0                         # сколько просьб было выполнено, когда свиток свернули
var _fold_badge: Label = null                # «✓1» на свёрнутом свитке
var _fold_badge_n := 0
var _fold_glow_until := 0                    # до какого мига (мс) «✓» мягко светится


## Свиток свёрнут (настройка tasks_folded); во время обучения — всегда развёрнут
func tasks_folded() -> bool:
	if game == null or (game.tutorial and game.tutorial.active()):
		return false
	return bool(game.settings.get("tasks_folded", false))


## Свернуть / развернуть свиток просьб (запоминается в настройках) — за 0,2 с
func fold_tasks(on: bool) -> void:
	game.settings["tasks_folded"] = on
	_store_settings()
	_fold_done0 = game.city.goals_done.size()
	_fold_badge_n = 0
	_fill_tasks()
	tasks_panel.pivot_offset = Vector2(tasks_panel.size.x * 0.5, 0.0)
	tasks_panel.scale = Vector2(1.0, 0.6)
	tasks_panel.modulate.a = 0.4
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(tasks_panel, "scale", Vector2.ONE, 0.2)
	tw.tween_property(tasks_panel, "modulate:a", 1.0, 0.2)


## Настройки — в файл, без применения: окно и качество графики не трогаем (не мигает)
func _store_settings() -> void:
	if game == null:
		return
	var f := FileAccess.open(game.settings_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(game.settings))


## Свёрнутый свиток: значок, «Просьбы · N», зелёный «✓1», если что-то выполнилось, золотая точка — история ждёт
func _fill_tasks_folded(goals: Array) -> void:
	var c: City = game.city
	var row := MarginContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 7)
	h.add_child(_icon("scroll", 26, C_SOFT))
	var t := _label("Просьбы · %d" % goals.size(), 19, false, C_INK, font_title)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(t)
	var done := c.goals_done.size() - _fold_done0
	_fold_badge = null
	if done > 0:
		var bd := _label("✓%d" % done, 17, true, C_CREAM)
		bd.add_theme_color_override("font_outline_color", C_GOOD)
		bd.add_theme_constant_override("outline_size", 8)
		bd.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bd.tooltip_text = "Выполнено просьб, пока свиток свёрнут: %d" % done
		h.add_child(bd)
		_fold_badge = bd
		if done > _fold_badge_n:
			_fold_glow_until = Time.get_ticks_msec() + 2000    # новое — мягко светится 2 с
	_fold_badge_n = done
	var sto = game.get("stories")
	if sto != null and (not sto.row_info().is_empty() or bool(sto.orders.row_info().get("waiting", false))):
		var dot := GoldDot.new()                 # история горожан ждёт (или заказ старосты, за который ещё не взялись)
		dot.name = "story_dot"
		dot.custom_minimum_size = Vector2(14, 14)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(dot)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(sp)
	var ch := Chevron.new()
	ch.down = true
	ch.custom_minimum_size = Vector2(22, 22)
	ch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ch)
	row.add_child(h)
	var b := Button.new()                      # вся полоска — кнопка «развернуть»
	b.name = "unfold"
	b.focus_mode = Control.FOCUS_NONE
	var e := StyleBoxEmpty.new()
	for st in ["normal", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, e)
	var hov := _box_pill(8, 2, "g_btn_hover")
	hov.modulate_color = Color(1, 1, 1, 0.4)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("hover_pressed", hov)
	b.tooltip_text = "Развернуть свиток просьб"
	b.pressed.connect(fold_tasks.bind(false))
	row.add_child(b)
	row.custom_minimum_size = Vector2(300, 0)
	tasks_box.add_child(row)


## Кнопка со стрелкой-шевроном в медальоне: свернуть (▴) / развернуть (▾)
func _chevron_btn(down: bool, tip: String, size: int, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	var e := StyleBoxEmpty.new()
	for st in ["normal", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, e)
	b.add_theme_stylebox_override("hover", _medal("medal_hover", size))
	var ch := Chevron.new()
	ch.down = down
	ch.set_anchors_preset(Control.PRESET_FULL_RECT)
	ch.offset_left = size * 0.16
	ch.offset_right = -size * 0.16
	ch.offset_top = size * 0.16
	ch.offset_bottom = -size * 0.16
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ch)
	b.pressed.connect(cb)
	return b


## Шеврон, нарисованный кодом: золотой с тёмной каймой, как стрелка «Этажа»
class Chevron extends Control:
	var down := false

	func _draw() -> void:
		var ys := [0.68, 0.32, 0.68] if not down else [0.34, 0.7, 0.34]
		var pts := PackedVector2Array([Vector2(0.14, ys[0]) * size, Vector2(0.5, ys[1]) * size, Vector2(0.86, ys[2]) * size])
		var w := maxf(2.0, minf(size.x, size.y) * 0.16)
		draw_polyline(pts, Color("3a2412"), w + 3.0, true)
		draw_polyline(pts, Color("f2c14e"), w, true)


## Золотая точка: история горожан ждёт (на свёрнутом свитке)
class GoldDot extends Control:
	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.5
		draw_circle(size * 0.5, r, Color("3a2412"))
		draw_circle(size * 0.5, r - 1.6, Color("f2c14e"))
		draw_circle(size * 0.5 + Vector2(-r * 0.25, -r * 0.25), r * 0.3, Color("fde39a"))


func _fill_tasks_body(goals: Array) -> void:
	var c: City = game.city
	var hdr := HBoxContainer.new()
	hdr.alignment = BoxContainer.ALIGNMENT_CENTER
	hdr.add_theme_constant_override("separation", 6)
	hdr.add_child(_icon("scroll", 26, C_SOFT))
	hdr.add_child(_label("Просьбы горожан", 20, false, C_INK, font_title))
	var sto = game.get("stories")
	if sto != null and sto.journal_any():
		# книжка — журнал «Истории горожан» (пройденные истории, «Пересмотреть»)
		hdr.add_child(_bare("bookshelf", "Истории горожан: журнал", 28, func(): sto.ui.open_journal()))
	if not (game.tutorial and game.tutorial.active()):
		var fb := _chevron_btn(false, "Свернуть свиток", 28, fold_tasks.bind(true))
		fb.name = "fold"
		hdr.add_child(fb)
	tasks_box.add_child(hdr)
	tasks_box.add_child(_divider(14))
	if sto != null:
		sto.ui.task_row(tasks_box)           # история горожан — золотая строка наверху
		sto.ui.order_row(tasks_box)          # заказ старосты — под ней (сам не открывается)
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
		var rank_lv := int((g["p"] as Array)[1]) if String((g["p"] as Array)[0]) == "rank" else -1
		if rank_lv > 0:
			# «Станьте хутором»: условия уровня — из данных (Defs.LEVELS), чтобы не расходились с кнопкой
			hint_txt = "Нужно: %s.\n%s" % [c.rank_text(rank_lv), hint_txt]
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
		if rank_lv > 0 and prog >= int(g["need"]):
			cnt.text = "готово!"                  # осталось нажать «Перейти на новый уровень»
			cnt.add_theme_color_override("font_color", C_GOOD)
		cnt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pr.add_child(cnt)
		v.add_child(pr)
		# из чего просьба: «Склад ✓ · Мясная лавка 0/1»; у «Станьте деревней» — что ещё не готово из условий уровня
		var sub := ""
		if g.has("parts"):
			sub = parts_line(g["parts"])
		elif rank_lv > c.level:
			sub = parts_line(c.rank_needs(rank_lv).filter(func(e): return not e["ok"]))
		if sub != "" and prog < int(g["need"]):
			var sl := _wrap(_label(sub, 13, true, C_SOFT), 222)
			sl.name = "parts"
			v.add_child(sl)
		h.add_child(v)
		row.add_child(h)
		row.add_child(b)                          # кнопка последней — поверх строки, ловит щелчок и подсказку
		var gg: Dictionary = g
		var gh := hint_txt
		b.pressed.connect(func():
			# щелчок: подсказка советника и сразу к делу — нужная постройка, исследование, «Этаж» или «Обзор» (need_do)
			var w := request_do(gg)
			var say := String(w.get("say", ""))
			if gh != "":
				advisor(gg["text"], gh + (("\n\nСейчас: " + say + ".") if say != "" and (gg.has("parts") or rank_lv > 0) else ""))
			elif say != "":
				advisor(gg["text"], say + ".")
			_do_click(w))
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
		if b.get("over", false):
			continue                 # сверх предела уровня: работников ей не нужно, всё сказано в карточке — без значка
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
## style: "" — как выше; "mark" — маленький бронзовый медальон со значком (такие же лавки, лавки в «Обзоре»);
## "plain" — только рисованный значок (✗ в «Обзоре»). Значок "face_good|mid|bad" с текстом — рожица и цифра
func set_badge(key: String, pos: Vector3, icon: String, warn := false, text := "", cb: Callable = Callable(), style := "") -> void:
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
	if style == "mark":
		var pm := PanelContainer.new()
		pm.add_theme_stylebox_override("panel", _medal("medal", 38))
		pm.custom_minimum_size = Vector2(38, 38)
		var ic := _icon(icon, 24)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pm.add_child(ic)
		if warn:
			pm.modulate = Color(1.0, 0.62, 0.55)          # не работает — значок краснеет
		p = pm
	elif style == "plain":
		p = _face(icon, 26) if icon.begins_with("face_") else _icon(icon, 26)
	elif text == "" and ResourceLoader.exists(AI + "badge_%s.png" % icon):
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
			var dr := _drawn(icon, 22)             # рожица «Обзора», стрелка «Этажа» — нарисованы кодом
			h.add_child(dr if dr else _icon(icon, 26, C_GOLD))
			# красная цена — денариев не хватает (стрелка «Этажа»)
			h.add_child(_label(text, 15 if icon.begins_with("face_") else 17, true, C_BAD if warn else C_INK))
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


## Значок с ключом на prefix под точкой mp (координаты интерфейса), "" — нет. «Этаж»: стрелки мышь не ловят
## (мазок идёт по городу), а дом под стрелкой ищет game._floor_pick. Из нескольких под мышью — верхний (нарисован
## последним): за что видно, за то и платят. skip_warn — красные (не по карману) не в счёт
func badge_at(mp: Vector2, prefix: String, skip_warn := false) -> String:
	if mp.x < 0.0:
		return ""
	var best := ""
	var best_i := -1
	for k in badges:
		if String(k).begins_with(prefix) and not (skip_warn and bool(badges[k]["warn"])):
			var n: Control = badges[k]["n"]
			if n.visible and n.get_index() > best_i and n.get_global_rect().grow(3.0).has_point(mp):
				best_i = n.get_index()
				best = String(k)
	return best


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
	mk.call("Выход", "exit", func(): Account.me().quit_game())
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
	if not Account.me().may_play(m):          # без входа не играем; сначала сверка города с облаком (account.gd)
		return
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


## Папка готовых картинок построек (user://icons/…): своя у каждой сборки — поменялись файлы игры (код, модели), и
## картинки рисуются заново; старые папки удаляются. В редакторе ключ — сами скрипты построек
const ICON_V := 1                         # поменяли свет, камеру или размер картинок — увеличить
const ICON_SRC := ["catalog.gd", "cat_houses.gd", "cat_shops.gd", "cat_civic.gd", "cat_monuments.gd", "cat_decor.gd", "cat_military.gd",
	"parts.gd", "synty.gd", "kit.gd", "bp.gd", "artisau.gd", "entrance.gd", "hud.gd"]


func _icon_dir() -> String:
	var key := "v%d" % ICON_V
	if OS.has_feature("editor"):
		for f: String in ICON_SRC:
			key += FileAccess.get_md5("res://scripts/" + f)
	else:
		var exe := OS.get_executable_path()
		for p: String in [exe.get_basename() + ".pck", exe.get_base_dir().path_join("CivCity_models.pck")]:
			var fa := FileAccess.open(p, FileAccess.READ)
			if fa:
				key += "_%d_%d" % [FileAccess.get_modified_time(p), fa.get_length()]
	var root := "user://icons"
	var name := key.md5_text().substr(0, 12)
	DirAccess.make_dir_recursive_absolute(root.path_join(name))
	for old in DirAccess.get_directories_at(root):
		if old != name:
			var od := root.path_join(old)
			for f in DirAccess.get_files_at(od):
				DirAccess.remove_absolute(od.path_join(f))
			DirAccess.remove_absolute(od)
	return root.path_join(name)


## Картинки построек для карточек: готовые берём из папки (имя — тип и отпечаток деталей облика), рисуем только
## недостающие — при запуске почти нет чтений картинки с видеокарты (на слабых видеокартах на них падала игра)
func _icons_async(vp: SubViewport, cam: Camera3D, holder: Node3D) -> void:
	var col := 0
	var idir := _icon_dir()
	var drawn := 0
	for type in Defs.B:
		if type == "center":
			continue
		var d: Dictionary = Defs.B[type]
		var tier := 2 if d["kind"] == "house" else 0
		col = (col + 3) % Defs.PALETTE.size()
		# у украшений облик задаёт тип (Catalog.make сам берёт их постоянный цвет) — картинка как поставленное
		var bp: Bp = Catalog.make(type, tier, 0, col)
		var path := idir.path_join("%s_%s.png" % [type, str(bp.parts).md5_text().substr(0, 12)])
		if FileAccess.file_exists(path):
			var ci := Image.load_from_file(path)
			if ci != null and not ci.is_empty():
				icons[type] = ImageTexture.create_from_image(ci)
				continue
		drawn += 1
		var g := Parts.ghost(bp, "outline", Color(0, 0, 0, 0))
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
		if not _icons_alive(vp):
			return                                # игру закрыли посреди картинок: окна и сцены уже нет
		var img := vp.get_texture().get_image()
		if deco:
			# украшения маленькие: обрезать пустые поля, чтобы облик был крупно и облики отличались на карточке
			var r := img.get_used_rect()
			if r.size.x > 8 and r.size.y > 8:
				r = r.grow(int(maxf(r.size.x, r.size.y) * 0.05)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
				img = img.get_region(r)
		icons[type] = ImageTexture.create_from_image(img)
		img.save_png(path)
		g.queue_free()
		await get_tree().process_frame
		if not _icons_alive(vp):
			return
	vp.queue_free()
	if drawn > 0:
		print("Картинки построек: нарисовано %d, остальные — из %s" % [drawn, idir])
	if tray.visible:
		_update_cards()


## Картинки карточек ещё можно рисовать: игра не закрывается, интерфейс и его окошко для картинок на месте
func _icons_alive(vp: SubViewport) -> bool:
	return _quitting == false and is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(vp) 		and vp.is_inside_tree() and get_tree() != null


var _quitting := false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_PREDELETE:
		_quitting = true                          # закрываем игру: картинки карточек больше не рисуем
