class_name LegionBattle
extends Node
## 3D-бой Легиона: уютная диорама области похода, где наш отряд и враги дерутся сами (автобой как в Hustle Castle),
## а игрок вовремя жмёт умения. Бой считает LegionSim (legion_sim.gd) фиксированным шагом — тот же, что в проверках
## баланса, — а здесь он только показывается: бойцы (legion_fighter.gd) идут, бьют, стреляют, падают; летят стрелы,
## болты и камни; масло, залп, черепаха, перевязка и рог видны на поле (legion_fx.gd); земля, деревья, свет и
## туман — своей области (legion_field.gd).
##
## Как устроено: город не трогаем — он остаётся в памяти, только не рисуется (у главного окна выключен 3D-кадр,
## интерфейс города спрятан, время города на паузе). Бой рисуется в своём мире (SubViewport с own_world_3d) в размер
## окна и показывается картинкой поверх; поверх неё — цветокоррекция как в городе и интерфейс боя. После боя всё
## возвращается как было.
##
## Подключение: LegionBattle.attach(game) — один раз после загрузки города (game.gd). Окно «Легион» зовёт
## legion.start_battle(st) / start_pvp_battle(opp) → сигнал legion.battle_requested(setup) → открывается бой.
## Бой сам зовёт legion.apply_result / apply_pvp_result, показывает итог (звёзды, награда, что открылось) и по выходу
## шлёт legion.battle_closed(out) — окно «Легион» открывается снова. Можно открыть и напрямую:
## LegionBattle.open(host, setup, on_done, opts) (host — Game или любой узел; без города — для проверок).
##
## Управление: кнопки умений внизу (или клавиши 1–5), «Авто» — умения жмёт сам отряд (только в пройденных боях
## и боях с городами), скорость ×1/×2/×3, пробел — пауза, Esc — отступить (с вопросом), колёсико — камера ближе или дальше.
## Учебный первый бой (setup.tutorial = "oil"): ×1 без «Авто»; шайка вышла кучей — бой замирает, стрелка на масле.

signal finished(out: Dictionary)          # бой окончен, итог подсчитан (до закрытия экрана итога)

const LAYER := 30
const AI := "res://assets/ui/ai/"
const C_INK := Color("4a2c17")
const C_SOFT := Color("7a5a3c")
const C_GOOD := Color("4f7a2a")
const C_BAD := Color("b0402a")
const C_GOLD := Color("e8b84a")
const C_CREAM := Color("fff4dc")
## Что за картинка у умения, пока нет листа владельца (значки игры)
const PERK_ALT := {"oil": "pot", "testudo": "shield", "bandage": "medic", "volley": "arrow", "horn": "music"}
const PERK_SAY := {"oil": "Кипящее масло!", "testudo": "Черепаха!", "bandage": "Перевязка!", "volley": "Залп!", "horn": "Боевой рог!"}
## PvP: на каком поле бьются с отрядом обороны другого города
const PVP_BIOMES := ["hills", "forest", "labyrinth", "desert"]

static var current: LegionBattle

var host: Node
var game                                   # Game, если бой открыт из города
var legion: Legion
var setup := {}
var opts := {}
var on_done := Callable()
var sim: LegionSim
var out := {}
var stage := {}
var pvp := false
var quality := "high"

# мир боя
var sub: SubViewport
var world: Node3D
var cam: Camera3D
var cam_attrs: CameraAttributesPractical
var field := {}
var fx: LegionFx
var views := {}                            # id бойца → {u, f, rings…}
var shots := {}                            # снаряд (LegionSim.Shot) → MeshInstance3D
var _pool := {}                            # заготовленные бойцы будущих волн: ключ → [LegionFighter]

# ход боя
var speed := 1.0
var paused := false
var phase := "intro"                       # intro | fight | ending | result
var acc := 0.0
var t_vis := 0.0
var intro_t := 0.0
var end_t := 0.0
var slowmo := 1.0
var cam_x := -1.0
var cam_d := 24.0
var shake := 0.0
var zoom := 1.0                            # колёсико мыши: ближе (до 0,6) или дальше (до 1,2)
var _snd_t := {}
var _saved := {}
var _seed := 1
var _boss_unit: LegionSim.Unit
var _last_wave := 0
var _fps_t := 0.0
var _fps_n := 0
var fps_avg := 0.0
# учебный первый бой (setup.tutorial = "oil"): шайка сбилась в кучу — бой замирает, стрелка на «Кипящее масло»
var tut := ""
var tut_freeze := false
var tut_done := false
var tut_arrow: TextureRect
var hint_until := 14.0                     # до какой секунды боя видна подсказка над умениями
## «Толпа!»: красный круг шириной в котёл масла идёт за кучей врагов (волна-«куча», шайка атамана), пока она
## не сбежится и ещё чуть-чуть: [{units, ring, t}]
var _crowds: Array = []
var _summon_warns := 0

# экран
var canvas: CanvasLayer
var view_rect: TextureRect
var grade: ShaderMaterial
var ui: Control
var bars: BarsLayer
var fade: ColorRect
var fade_map: TextureRect
var fade_lbl: Label
var title_lbl: Label
var sub_lbl: Label
var wave_box: HBoxContainer
var boss_panel: Control
var boss_name: Label
var boss_bar: ProgressBar
var boss_pic: TextureRect
var perk_bar: Control
var perk_btns := {}
var banner: PanelContainer
var banner_lbl: Label
var _banner_t := 0.0
var _banner_dur := 1.6
var speed_btns := {}
var auto_btn: Button
var pause_btn: Button
var retreat_btn: Button
var modal: Control
var pause_lbl: Label
var hint_lbl: Label
var players: Array[AudioStreamPlayer] = []

var font: Font
var font_bold: Font
var font_title: Font


# =====================================================================
#   вход
# =====================================================================

## Подключить к городу: бой открывается, когда окно «Легион» просит бой (сигнал battle_requested)
static func attach(g: Node) -> void:
	if g == null or g.get("city") == null:
		return
	var lg: Legion = g.city.legion
	if lg.has_meta("battle_hook"):
		return
	lg.set_meta("battle_hook", true)
	lg.battle_requested.connect(func(s: Dictionary) -> void:
		if current != null and is_instance_valid(current):
			return
		LegionBattle.open(g, s))


## Открыть бой: host — Game (город прячется на время боя) или любой узел (проверки без города);
## on_done(out) — по выходу; opts: {"legion": Legion (без города), "speed": 1…3, "auto": bool, "quality": "low"|"high"}
static func open(h: Node, s: Dictionary, done := Callable(), o := {}) -> LegionBattle:
	var b := LegionBattle.new()
	b.name = "LegionBattle"
	b.host = h
	b.setup = s
	b.on_done = done
	b.opts = o
	current = b
	h.add_child(b)
	return b


func _ready() -> void:
	game = host if host.get("city") != null and host.get("hud") != null else null
	legion = opts.get("legion", null)
	if legion == null and game != null:
		legion = game.city.legion
	if legion == null:
		legion = Legion.new()
		legion.free_mode = true
	if game != null:
		quality = String(game.settings.get("quality", "high"))
	quality = String(opts.get("quality", quality))
	if quality == "verylow":
		quality = "low"                           # бой на «Очень низкой» — как на «Низкой»
	speed = clampf(float(opts.get("speed", legion.flags.get("battle_speed", 1.0))), 1.0, 3.0)
	zoom = clampf(float(opts.get("zoom", 1.0)), 0.3, 1.5)
	_fonts()
	_build_screen()
	_loading(setup)
	# сначала экран с картой провинции, потом (пока он виден) собирается поле — без «замёрзшего» города
	await get_tree().process_frame
	await get_tree().process_frame
	_enter()
	_start(setup)


## Город уходит в тень: интерфейс спрятан, время стоит, камера города не слушает клавиш, 3D города не рисуется
func _enter() -> void:
	var vp := get_viewport()
	_saved = {"disable_3d": vp.disable_3d}
	if game != null:
		_saved["speed"] = game.speed
		_saved["hud"] = game.hud.visible
		_saved["cine"] = game.rig.cine if game.rig else false
		if game.tool != "":
			game.set_tool("")
		game.hud.set_speed(0.0)
		game.hud.visible = false
		if game.rig:
			game.rig.cine = true
	vp.disable_3d = true


func _leave() -> void:
	get_viewport().disable_3d = bool(_saved.get("disable_3d", false))
	if game != null and is_instance_valid(game):
		game.hud.visible = bool(_saved.get("hud", true))
		if game.rig:
			game.rig.cine = bool(_saved.get("cine", false))
		game.hud.set_speed(float(_saved.get("speed", 1.0)))


# =====================================================================
#   экран: картинка мира, цвет кадра, интерфейс
# =====================================================================

func _build_screen() -> void:
	canvas = CanvasLayer.new()
	canvas.layer = LAYER
	add_child(canvas)
	sub = SubViewport.new()
	sub.own_world_3d = true
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var root_vp := get_tree().root
	sub.msaa_3d = root_vp.msaa_3d
	sub.screen_space_aa = root_vp.screen_space_aa
	sub.use_debanding = root_vp.use_debanding
	sub.anisotropic_filtering_level = root_vp.anisotropic_filtering_level
	if quality == "low":
		sub.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		sub.scaling_3d_scale = 0.75
	add_child(sub)
	_fit_sub()
	get_window().size_changed.connect(_fit_sub)
	view_rect = TextureRect.new()
	view_rect.texture = sub.get_texture()
	view_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view_rect.stretch_mode = TextureRect.STRETCH_SCALE
	view_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	view_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	view_rect.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			var mb := e as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom = clampf(zoom * 0.92, 0.6, 1.2)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom = clampf(zoom / 0.92, 0.6, 1.2))
	canvas.add_child(view_rect)
	var gr := ColorRect.new()
	gr.set_anchors_preset(Control.PRESET_FULL_RECT)
	gr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grade = ShaderMaterial.new()
	grade.shader = load("res://shaders/grade.gdshader")
	gr.material = grade
	canvas.add_child(gr)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = _theme()
	canvas.add_child(ui)
	bars = BarsLayer.new()
	bars.battle = self
	bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bars)
	_top_bar()
	_boss_box()
	_perk_bar()
	_banner_box()
	pause_lbl = _label("Пауза — пробел, чтобы продолжить", 22, true, C_CREAM)
	pause_lbl.add_theme_color_override("font_outline_color", Color(0.18, 0.1, 0.04, 0.9))
	pause_lbl.add_theme_constant_override("outline_size", 8)
	pause_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_lbl.visible = false
	ui.add_child(pause_lbl)
	_pin(pause_lbl, Control.PRESET_CENTER, Vector2(-260, 40), Vector2(520, 40))
	hint_lbl = _label("", 17, true, C_CREAM)
	hint_lbl.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.04, 0.85))
	hint_lbl.add_theme_constant_override("outline_size", 6)
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.visible = false
	ui.add_child(hint_lbl)
	_pin(hint_lbl, Control.PRESET_CENTER_BOTTOM, Vector2(-420, -176), Vector2(840, 30))
	# стрелка учебного боя над кнопкой умения (качается)
	tut_arrow = TextureRect.new()
	tut_arrow.texture = _icon_tex("arrow_down")
	tut_arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tut_arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tut_arrow.size = Vector2(60, 60)
	tut_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tut_arrow.visible = false
	ui.add_child(tut_arrow)
	# занавес между городом и боем: карта провинции (лист 40 владельца) и название боя
	fade = ColorRect.new()
	fade.color = Color(0.12, 0.08, 0.05, 1.0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(fade)
	fade_map = TextureRect.new()
	fade_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade_map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fade_map.modulate = Color(0.62, 0.56, 0.5, 1.0)
	fade_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.add_child(fade_map)
	fade_lbl = _label("", 40, false, C_CREAM, font_title)
	fade_lbl.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.05, 0.9))
	fade_lbl.add_theme_constant_override("outline_size", 10)
	fade_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fade.add_child(fade_lbl)
	_pin(fade_lbl, Control.PRESET_CENTER, Vector2(-500, -40), Vector2(1000, 80))
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
		add_child(p)
		players.append(p)


## Мир боя рисуется в размер окна (в настоящих точках экрана — без размытия)
func _fit_sub() -> void:
	var ws := get_window().size
	sub.size = Vector2i(maxi(64, ws.x), maxi(64, ws.y))


func _fonts() -> void:
	font = _lining(load("res://assets/fonts/AlegreyaSans-Bold.ttf"))
	font_bold = _lining(load("res://assets/fonts/AlegreyaSans-ExtraBold.ttf"))
	font_title = load("res://assets/fonts/Philosopher-Bold.ttf")


static func _lining(f: Font) -> Font:
	var v := FontVariation.new()
	v.base_font = f
	var ts := TextServerManager.get_primary_interface()
	v.opentype_features = {ts.name_to_tag("lnum"): 1, ts.name_to_tag("tnum"): 1}
	return v


static func _box(name: String, m: Array, cm: Array, tile := false) -> StyleBoxTexture:
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


## Оформление как у интерфейса города (рисованный набор владельца)
func _theme() -> Theme:
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 18
	t.set_stylebox("panel", "PanelContainer", _box("g_panel", [46, 46, 45, 47], [29, 28, 29, 29], true))
	var pill := func(n: String) -> StyleBoxTexture: return _box(n, [22, 12, 22, 12], [16, 6, 16, 6])
	t.set_stylebox("normal", "Button", pill.call("g_btn"))
	t.set_stylebox("hover", "Button", pill.call("g_btn_hover"))
	t.set_stylebox("pressed", "Button", pill.call("g_btn_on"))
	t.set_stylebox("hover_pressed", "Button", pill.call("g_btn_on"))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	var dis: StyleBoxTexture = pill.call("g_btn")
	dis.modulate_color = Color(0.85, 0.82, 0.78, 0.8)
	t.set_stylebox("disabled", "Button", dis)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", C_INK)
	t.set_color("font_disabled_color", "Button", Color(C_INK, 0.45))
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		t.set_color(c, "Button", Color.WHITE)
	t.set_constant("h_separation", "Button", 6)
	t.set_color("font_color", "Label", C_INK)
	t.set_stylebox("panel", "TooltipPanel", pill.call("g_btn"))
	t.set_color("font_color", "TooltipLabel", C_INK)
	t.set_font("font", "TooltipLabel", font)
	t.set_font_size("font_size", "TooltipLabel", 16)
	return t


## Привязать к краю или середине экрана: preset — точка привязки, off — смещение левого верхнего угла от неё, sz — размер
static func _pin(c: Control, preset: int, off: Vector2, sz: Vector2) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = off.x
	c.offset_top = off.y
	c.offset_right = off.x + sz.x
	c.offset_bottom = off.y + sz.y


func _label(text: String, size := 18, bold := false, col := C_INK, f: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", f if f != null else (font_bold if bold else font))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _icon_tex(name: String) -> Texture2D:
	var p := AI + "icons/%s.png" % name
	return load(p) if ResourceLoader.exists(p) else null


func _button(text: String, icon: String, cb: Callable, w := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	if icon != "":
		var tx := _icon_tex(icon)
		if tx:
			b.icon = tx
	b.add_theme_constant_override("icon_max_width", 24)
	b.add_theme_font_override("font", font_bold)
	b.add_theme_font_size_override("font_size", 17)
	b.custom_minimum_size = Vector2(w, 40)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


## Верх: слева «Отступить», посередине табличка с названием боя и волнами, справа скорость, «Авто», пауза
func _top_bar() -> void:
	retreat_btn = _button("Отступить", "exit", _ask_retreat, 150)
	ui.add_child(retreat_btn)
	_pin(retreat_btn, Control.PRESET_TOP_LEFT, Vector2(18, 16), Vector2(150, 40))
	# табличка: орёл и красная лента (как название города), под ней — волны
	var plate := TextureRect.new()
	plate.texture = load(AI + "plate.png")
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(plate)
	_pin(plate, Control.PRESET_CENTER_TOP, Vector2(-235, 6), Vector2(470, 124))
	title_lbl = _label("", 22, false, C_CREAM, font_title)
	title_lbl.add_theme_color_override("font_outline_color", Color(0.35, 0.08, 0.05, 0.7))
	title_lbl.add_theme_constant_override("outline_size", 4)
	title_lbl.position = Vector2(118, 27)
	title_lbl.size = Vector2(318, 34)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.clip_text = true
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	plate.add_child(title_lbl)
	sub_lbl = _label("", 16, true, Color("f3dfb3"))
	sub_lbl.position = Vector2(118, 55)
	sub_lbl.size = Vector2(318, 24)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_color_override("font_outline_color", Color(0.35, 0.08, 0.05, 0.6))
	sub_lbl.add_theme_constant_override("outline_size", 3)
	sub_lbl.clip_text = true
	sub_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	plate.add_child(sub_lbl)
	wave_box = HBoxContainer.new()
	wave_box.alignment = BoxContainer.ALIGNMENT_CENTER
	wave_box.add_theme_constant_override("separation", 6)
	wave_box.position = Vector2(118, 92)
	wave_box.size = Vector2(318, 22)
	wave_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(wave_box)
	# справа: скорость боя, «Авто», пауза
	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.alignment = BoxContainer.ALIGNMENT_END
	ui.add_child(right)
	_pin(right, Control.PRESET_TOP_RIGHT, Vector2(-430, 16), Vector2(412, 40))
	for s: int in [1, 2, 3]:
		var b := _button("×%d" % s, "", func(): _set_speed(float(s)), 58)
		b.toggle_mode = true
		b.tooltip_text = "Скорость боя ×%d" % s
		right.add_child(b)
		speed_btns[s] = b
	auto_btn = _button("Авто", "", _toggle_auto, 92)
	auto_btn.toggle_mode = true
	auto_btn.tooltip_text = "Умения отряд жмёт сам — вовремя и с умом"
	right.add_child(auto_btn)
	pause_btn = _button("", "pause", _toggle_pause, 54)
	pause_btn.tooltip_text = "Пауза (пробел)"
	right.add_child(pause_btn)
	_refresh_speed()


## Полоса здоровья босса под табличкой: портрет, имя, полоса
func _boss_box() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box("g_panel_xs", [23, 23, 22, 24], [14, 10, 16, 12], true))
	p.custom_minimum_size = Vector2(460, 0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	boss_pic = TextureRect.new()
	boss_pic.custom_minimum_size = Vector2(54, 54)
	boss_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	boss_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(boss_pic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	boss_name = _label("", 19, false, C_INK, font_title)
	v.add_child(boss_name)
	boss_bar = ProgressBar.new()
	boss_bar.show_percentage = false
	boss_bar.custom_minimum_size = Vector2(0, 16)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.25, 0.14, 0.08, 0.85)
	bg.set_corner_radius_all(6)
	bg.border_color = Color("a8740f")
	bg.set_border_width_all(2)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color("c0392b")
	fg.set_corner_radius_all(5)
	fg.border_color = Color(1, 0.6, 0.5, 0.35)
	fg.border_width_top = 2
	boss_bar.add_theme_stylebox_override("background", bg)
	boss_bar.add_theme_stylebox_override("fill", fg)
	boss_bar.max_value = 1.0
	v.add_child(boss_bar)
	boss_panel = p
	p.visible = false
	ui.add_child(p)
	_pin(p, Control.PRESET_CENTER_TOP, Vector2(-230, 128), Vector2(460, 80))


## Умения внизу: бронзовые медальоны с картинками, перезарядка — тёмный сектор и секунды
func _perk_bar() -> void:
	perk_bar = PanelContainer.new()
	(perk_bar as PanelContainer).add_theme_stylebox_override("panel", _box("g_panel_xs", [23, 23, 22, 24], [16, 8, 16, 10], true))
	perk_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	perk_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(perk_bar)


func _fill_perks() -> void:
	for c in perk_bar.get_children():
		c.queue_free()
	perk_btns.clear()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	perk_bar.add_child(h)
	var ids := []
	for id in Legion.PERK_IDS:
		if sim.perks["ally"].has(id):
			ids.append(id)
	if ids.is_empty():
		var l := _label("Отряд дерётся сам; ваше — состав и умения в нужный миг", 17, true, C_SOFT)
		h.add_child(l)
	var n := 0
	for id: String in ids:
		n += 1
		var pb := PerkButton.new()
		pb.battle = self
		pb.id = id
		pb.key_n = n
		pb.lvl = int(sim.perks["ally"][id]["lvl"])
		pb.icon = Legion.art_texture("perk", id)
		if pb.icon == null:
			pb.icon = _icon_tex(String(PERK_ALT.get(id, "swords")))
		pb.medal = load(AI + "medal.png")
		pb.medal_on = load(AI + "medal_on.png")
		pb.custom_minimum_size = Vector2(96, 122)
		pb.tooltip_text = "%s (клавиша %d)\n%s" % [Legion.PERKS[id]["name"], n, Legion.PERKS[id]["desc"]]
		pb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		h.add_child(pb)
		perk_btns[id] = pb
	_place_perks()
	await get_tree().process_frame
	_place_perks()


func _place_perks() -> void:
	if not is_instance_valid(perk_bar):
		return
	var sz := perk_bar.get_combined_minimum_size()
	_pin(perk_bar, Control.PRESET_CENTER_BOTTOM, Vector2(-sz.x * 0.5, -sz.y - 10), sz)


func _banner_box() -> void:
	banner = PanelContainer.new()
	banner.add_theme_stylebox_override("panel", _box("g_scroll_h", [45, 58, 45, 63], [70, 22, 70, 26]))
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_lbl = _label("", 34, false, C_INK, font_title)
	banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(banner_lbl)
	banner.modulate.a = 0.0
	ui.add_child(banner)


func say(text: String, dur := 1.6) -> void:
	banner_lbl.text = text
	var sz := banner.get_combined_minimum_size()
	_pin(banner, Control.PRESET_CENTER, Vector2(-sz.x * 0.5, -205), sz)
	_banner_t = dur
	_banner_dur = dur


# =====================================================================
#   бой: мир, бойцы
# =====================================================================

func _start(s: Dictionary) -> void:
	setup = s
	out = {}
	pvp = String(s.get("kind", "campaign")) == "pvp"
	stage = s.get("stage", {})
	_seed = int(s.get("seed", 1))
	_clear_world()
	var biome := "forest"
	if pvp:
		var nm := String((s.get("opponent", {}) as Dictionary).get("name", ""))
		biome = PVP_BIOMES[absi(nm.hash()) % PVP_BIOMES.size()]
	else:
		var r := int(stage.get("r", 0))
		biome = String(Legion.REGIONS[clampi(r, 0, Legion.REGIONS.size() - 1)]["biome"])
	world = Node3D.new()
	world.name = "BattleWorld"
	sub.add_child(world)
	field = LegionField.build(world, biome, int(stage.get("r", 0)) * 101 + int(stage.get("s", 0)) * 7 + 3, quality)
	var gp: Dictionary = field.get("grade", {})
	for k in gp:
		grade.set_shader_parameter(k, gp[k])
	grade.set_shader_parameter("warm_keep", 0.0)
	grade.set_shader_parameter("vignette", 0.5)
	fx = LegionFx.new()
	world.add_child(fx)
	cam = Camera3D.new()
	cam.fov = 30.0
	cam.near = 0.3
	cam.far = 320.0
	cam_attrs = CameraAttributesPractical.new()
	cam_attrs.dof_blur_far_enabled = quality != "low"
	cam_attrs.dof_blur_near_enabled = quality != "low"
	cam_attrs.dof_blur_amount = 0.085
	cam.attributes = cam_attrs
	world.add_child(cam)
	cam.make_current()
	sim = LegionSim.new(setup)
	# учебный бой: управление — у игрока, скорость ×1, «Авто» и скорость спрятаны
	tut = "" if pvp else String(s.get("tutorial", ""))
	tut_freeze = false
	tut_done = false
	tut_arrow.visible = false
	if tut != "":
		speed = 1.0
	elif not opts.has("speed"):
		speed = clampf(float(legion.flags.get("battle_speed", speed)), 1.0, 3.0)
	for b in speed_btns.values():
		(b as Control).visible = tut == ""
	auto_btn.visible = tut == ""
	# «Авто» — только для пройденных боёв (и боёв с городами): в первый раз бой ведёт сам игрок
	var auto_ok := pvp or bool(opts.get("auto_any", false)) or legion.stage_done(int(stage.get("cycle", 0)), int(stage.get("r", 0)), int(stage.get("s", 0)))
	auto_btn.disabled = not auto_ok
	auto_btn.tooltip_text = "Умения отряд жмёт сам — вовремя и с умом" if auto_ok else "Авто — для пройденных боёв: в первый раз ведите бой сами"
	var want := bool(opts.get("auto", legion.flags.get("battle_auto", false)))
	sim.set_auto(want and auto_ok and tut == "")   # запоминается: бой с городом повторит сервер
	_prewarm()
	views.clear()
	shots.clear()
	for u in sim.units:
		_view(u)
	_title()
	_fill_perks()
	_refresh_speed()
	# первые бои: тихая подсказка над умениями (как устроен бой), потом не мешает
	var seen := int(legion.flags.get("battle_hints", 0))
	hint_lbl.visible = (seen < 3 or tut != "") and not sim.perks["ally"].is_empty()
	hint_lbl.modulate.a = 1.0
	_pin(hint_lbl, Control.PRESET_CENTER_BOTTOM, Vector2(-420, -262 if tut != "" else -176), Vector2(840, 30))
	hint_until = INF if tut != "" else 14.0
	if tut != "":
		hint_lbl.text = "Учебный бой. Отряд дерётся сам; ваше — состав и умения в нужный миг."
	elif hint_lbl.visible:
		legion.flags["battle_hints"] = seen + 1
		hint_lbl.text = "Отряд дерётся сам; ваше — состав и умения в нужный миг. Умение засветилось — жмите (клавиши 1–5)."
	_handle(sim.take_events())
	phase = "intro"
	intro_t = 0.0
	end_t = 0.0
	slowmo = 1.0
	acc = 0.0
	t_vis = 0.0
	paused = false
	pause_lbl.visible = false
	retreat_btn.disabled = false
	cam_x = -6.0
	_camera(0.0)
	say(stage.get("title", "Бой") if not pvp else "Бой с городом", 2.2)
	if bool(stage.get("boss", false)):
		say("Босс: " + String(stage.get("name", "")), 2.6)
	_play("horn", -6.0)
	var tw := create_tween()
	fade.modulate.a = 1.0
	tw.tween_interval(0.25)
	tw.tween_property(fade, "modulate:a", 0.0, 0.6)


## Занавес перед боем: карта провинции и «Легион выступает: …»
func _loading(s: Dictionary) -> void:
	fade.modulate.a = 1.0
	var st: Dictionary = s.get("stage", {})
	if String(s.get("kind", "")) == "pvp":
		fade_map.texture = null
		fade_lbl.text = "Легион выступает: город «%s»" % String((s.get("opponent", {}) as Dictionary).get("name", "?"))
	else:
		var r := clampi(int(st.get("r", 0)), 0, Legion.REGIONS.size() - 1)
		fade_map.texture = Legion.art_texture("map", String(Legion.REGIONS[r]["id"]))
		var nm := String(st.get("theme", "")) if String(st.get("theme", "")) != "" else String(st.get("name", ""))
		fade_lbl.text = "%s — %s" % [String(st.get("title", "")), nm] if nm != "" else String(st.get("title", ""))


func _clear_world() -> void:
	for id in views:
		var v: Dictionary = views[id]
		for k in ["testudo", "horn", "summon"]:
			if v.has(k) and is_instance_valid(v[k]):
				(v[k] as Node).queue_free()
	views.clear()
	shots.clear()
	_pool.clear()
	_crowds.clear()
	_summon_warns = 0
	_boss_unit = null
	if sim != null:
		sim.dispose()
	if world != null and is_instance_valid(world):
		world.queue_free()
	world = null
	if modal != null and is_instance_valid(modal):
		modal.queue_free()
	modal = null


## Заранее собрать бойцов будущих волн (чтобы волна вышла без рывка)
func _prewarm() -> void:
	var need := {}
	var waves: Array = setup.get("waves", [])
	for i in range(1 if not bool(setup.get("enemy_formation", false)) else 0, waves.size()):
		for st: Dictionary in waves[i]:
			var k := String(st["key"])
			need[k] = int(need.get(k, 0)) + 1
	# шайка атамана: на три созыва вперёд
	for w: Array in waves:
		for st: Dictionary in w:
			for f: Dictionary in (st.get("summon", {}) as Dictionary).get("foes", []):
				need[String(f["key"])] = int(need.get(String(f["key"]), 0)) + 3
	for k in need:
		var list: Array = []
		for i in int(need[k]):
			var size := float(Legion.ENEMIES.get(k, {}).get("size", 1.0))
			var f := LegionFighter.create(k, size, _seed + i * 31 + k.hash(), Legion.UNITS.has(k))
			f.visible = false
			world.add_child(f)
			list.append(f)
		_pool[k] = list


func _view(u: LegionSim.Unit) -> Dictionary:
	if views.has(u.id):
		return views[u.id]
	var f: LegionFighter = null
	var list: Array = _pool.get(u.key, []) if u.side == "enemy" else []
	if not list.is_empty():
		f = list.pop_back()
	elif u.key == "hero" and u.side == "ally" and setup.has("hero_look"):
		f = LegionFighter.create_hero(setup["hero_look"], u.size * 1.08, _seed + u.id * 7919)   # свой герой (Д11): его лицо, цвета, плащ, снаряжение; чуть крупнее
		world.add_child(f)
	else:
		f = LegionFighter.create(u.key, u.size, _seed + u.id * 7919, u.side == "enemy" and Legion.UNITS.has(u.key))
		world.add_child(f)
	f.visible = true
	f.position = Vector3(u.x, _h(u.x, u.z), u.z)
	f.rotation.y = _face_yaw(u, 1.0 if u.side == "ally" else -1.0, 0.0)
	f.set_speed(speed)
	var v := {"u": u, "f": f, "hp": u.hp_frac(), "dead": false, "px": u.x, "pz": u.z, "step_t": 0.0}
	views[u.id] = v
	if u.boss:
		_boss_unit = u
	return v


func _h(x: float, z: float) -> float:
	var hf: Callable = field.get("height", Callable())
	return float(hf.call(x, z)) if hf.is_valid() else 0.0


## Куда смотреть: на цель (вполоборота к зрителю), без цели — вдоль своего хода или к врагу
func _face_yaw(u: LegionSim.Unit, dx: float, dz: float) -> float:
	var d := Vector2(dx, dz)
	if u.target != null and u.target.alive:
		d = Vector2(u.target.x - u.x, (u.target.z - u.z) * 0.6)
	if d.length() < 0.05:
		d = Vector2(1.0 if u.side == "ally" else -1.0, 0.0)
	d = d.normalized()
	# вполоборота к камере (она спереди, со стороны +z)
	d.y += 0.68
	return atan2(d.x, d.y)


func _title() -> void:
	if pvp:
		var opp: Dictionary = setup.get("opponent", {})
		title_lbl.text = "Город «%s»" % String(opp.get("name", "?"))
		sub_lbl.text = "Отряд обороны · рейтинг %d" % int(opp.get("rating", 0))
	else:
		title_lbl.text = String(stage.get("title", ""))
		var s := int(stage.get("s", 0))
		sub_lbl.text = String(stage.get("name", "")) if bool(stage.get("boss", false)) else "Бой %d из %d" % [s + 1, Legion.STAGES]
		if String(stage.get("theme", "")) != "":
			sub_lbl.text += " · " + String(stage["theme"])
	_waves_ui()


func _waves_ui() -> void:
	for c in wave_box.get_children():
		c.queue_free()
	var total := sim.waves.size() if not bool(setup.get("enemy_formation", false)) else 1
	if total <= 1:
		return
	var l := _label("Волна", 14, true, Color("f3dfb3"))
	l.add_theme_color_override("font_outline_color", Color(0.3, 0.1, 0.05, 0.7))
	l.add_theme_constant_override("outline_size", 3)
	wave_box.add_child(l)
	for i in total:
		var d := WavePip.new()
		d.on = i <= sim.wave_idx
		d.boss = bool(stage.get("boss", false)) and i == total - 1
		d.custom_minimum_size = Vector2(18, 18)
		wave_box.add_child(d)


# =====================================================================
#   ход боя
# =====================================================================

func _process(dt: float) -> void:
	if sim == null or world == null:
		return
	dt = minf(dt, 0.1)
	_fps(dt)
	if _banner_t > 0.0:
		_banner_t -= dt
		banner.modulate.a = clampf(minf(_banner_t * 3.0, (_banner_dur - _banner_t) * 6.0 + 1.0), 0.0, 1.0) if _banner_t > 0.0 else 0.0   # длинная надпись видна сразу
	else:
		banner.modulate.a = maxf(0.0, banner.modulate.a - dt * 4.0)
	var run := (not paused and not tut_freeze and modal == null) or phase == "result"
	var gdt := dt * speed * slowmo if run else 0.0
	t_vis += gdt
	if phase == "intro":
		intro_t += dt
		if intro_t > 2.4:
			phase = "fight"
	if hint_lbl.visible and (sim.t > hint_until or phase == "ending" or phase == "result"):
		hint_lbl.modulate.a = maxf(0.0, hint_lbl.modulate.a - dt * 1.5)
		if hint_lbl.modulate.a <= 0.0:
			hint_lbl.visible = false
	if run and phase != "result":
		acc += gdt
		var n := 0
		while acc >= LegionSim.DT and n < 16 and sim.result.is_empty() and not tut_freeze:
			sim.step(LegionSim.DT)
			acc -= LegionSim.DT
			n += 1
			_handle(sim.take_events())
			_tut_check()
	_tut_arrow(dt)
	if not sim.result.is_empty() and (phase == "fight" or phase == "intro"):
		_begin_end()
	if phase == "ending":
		end_t += dt
		slowmo = lerpf(0.4, 1.0, smoothstep(0.2, 1.6, end_t))
		if end_t > 2.4:
			_show_result()
	_update_views(gdt, dt)
	_update_crowds(gdt)
	_update_shots()
	fx.tick(gdt)
	LegionField.tick(field, t_vis)
	_camera(dt)
	_update_ui()
	bars.queue_redraw()


func _fps(dt: float) -> void:
	_fps_t += dt
	_fps_n += 1
	if _fps_t >= 1.0:
		fps_avg = _fps_n / _fps_t
		_fps_t = 0.0
		_fps_n = 0


func _handle(evs: Array) -> void:
	for e: Dictionary in evs:
		match String(e["type"]):
			"wave":
				var n := int(e["n"])
				# волна-«куча» (походы): «Толпа!» и красный круг за ней (в учебном бою — своя подсказка)
				var pack: bool = not pvp and tut == "" and (n - 1) in (setup.get("packs", []) as Array)
				if n > 1:
					var last: bool = n == int(e["total"])
					say(("Босс: " + String(stage.get("name", ""))) if last and bool(stage.get("boss", false)) else "Волна %d из %d" % [n, int(e["total"])], 1.8)
					_play("horn", -10.0, 1.15)
				_last_wave = n
				var fresh: Array = []
				for u in sim.units:
					if u.wave == n - 1 and u.side == "enemy":
						_view(u)
						fresh.append(u)
				if pack:
					_crowd(fresh, "Толпа! Масло накроет всех разом")
				_waves_ui()
			"warn":
				# Атаман трубит в рог: через warn секунд вбежит шайка (круг под ним пульсирует — _update_views)
				_summon_warns += 1
				say("Атаман созывает шайку! Масло — когда сбегутся" if _summon_warns == 1 else "Атаман снова созывает шайку!", 2.4)
				_play("horn", -4.0, 0.72)
				var u: LegionSim.Unit = e["unit"]
				var f: LegionFighter = _view(u)["f"]
				fx.ring(f.position, 2.6, Color(0.95, 0.18, 0.1, 0.9), 0.9, 1.0)
			"summon":
				var fresh: Array = []
				for nu: LegionSim.Unit in e["units"]:
					_view(nu)
					fresh.append(nu)
					fx.dust(Vector3(nu.x, _h(nu.x, nu.z), nu.z), 0.8)
				_crowd(fresh)
			"attack":
				var u: LegionSim.Unit = e["unit"]
				var v := _view(u)
				(v["f"] as LegionFighter).attack()
				if u.key == "catapult" or u.key == "ballista":
					_play("creak", -12.0, randf_range(0.9, 1.1))
			"shoot":
				var s: LegionSim.Shot = e["shot"]
				var mi := MeshInstance3D.new()
				mi.mesh = LegionFx.shot_mesh(s.kind)
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				if s.kind == "arrow" or s.kind == "sling":
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				world.add_child(mi)
				shots[s] = mi
				_place_shot(s, mi)
				if s.kind == "arrow" or s.kind == "bolt":
					_play("whoosh", -16.0, randf_range(1.1, 1.4))
			"hit":
				var u: LegionSim.Unit = e["unit"]
				var v := _view(u)
				var f: LegionFighter = v["f"]
				f.hurt()
				var from: LegionSim.Unit = e.get("from")
				var p := f.global_position + Vector3(0, f.top * 0.55, 0)
				bars.float_text(_screen(f.global_position + Vector3(0, f.top + 0.1, 0)), str(int(e["dmg"])) + ("!" if bool(e["crit"]) else ""),
					"crit" if bool(e["crit"]) else ("hurt" if u.side == "ally" else "dmg"))
				if from != null and from.shot == "":
					var metal := "beast" not in u.tags and "beast" not in from.tags
					if metal:
						fx.sparks(p + Vector3(randf_range(-0.2, 0.2), 0, 0.15))
						_play("clash", -13.0 if not bool(e["crit"]) else -9.0, randf_range(0.9, 1.15))
					else:
						fx.dust(Vector3(p.x, 0.3, p.z), 0.5)
						_play("thud", -12.0, randf_range(0.8, 1.1))
				elif from == null:
					pass
				else:
					_play("thud", -18.0, randf_range(1.2, 1.5))
			"death":
				var u: LegionSim.Unit = e["unit"]
				var v := _view(u)
				var f: LegionFighter = v["f"]
				f.die()
				v["dead"] = true
				fx.dust(Vector3(f.global_position.x, f.global_position.y, f.global_position.z), 1.2 * maxf(1.0, u.size))
				_play("fall", -10.0, randf_range(0.85, 1.05))
				for k in ["testudo", "horn", "summon"]:
					if v.has(k) and is_instance_valid(v[k]):
						(v[k] as Node).queue_free()
						v.erase(k)
			"slam":
				var at := Vector3(float(e["x"]), _h(float(e["x"]), float(e["z"])), float(e["z"]))
				fx.ring(at, float(e["r"]), Color(0.96, 0.88, 0.7, 0.85), 0.55)
				fx.dust(at, 1.6)
				shake = maxf(shake, 0.18)
				_play("fall", -8.0, 0.7)
			"boom":
				var at := Vector3(float(e["x"]), _h(float(e["x"]), float(e["z"])), float(e["z"]))
				fx.ring(at, float(e["r"]), Color(0.96, 0.86, 0.66, 0.9), 0.6)
				fx.dust(at, 2.0)
				fx.burst(at + Vector3(0, 0.2, 0), Color(0.55, 0.5, 0.44, 1.0), 10, 3.0, 3.5, 0.12, 0.8, false, 9.0, 0.0)
				shake = maxf(shake, 0.25)
				_play("boom", -7.0, randf_range(0.85, 1.0))
			"charge":
				var u: LegionSim.Unit = e["unit"]
				fx.dust(Vector3(u.x, 0.0, u.z), 1.4)
				say(String(u.name) + " бросается в атаку!", 1.2)
				shake = maxf(shake, 0.2)
			"perk":
				_perk_fx(e)
			"heal":
				var u: LegionSim.Unit = e["unit"]
				var v := _view(u)
				var f: LegionFighter = v["f"]
				for i in 6:
					fx.add(f.global_position + Vector3(randf_range(-0.3, 0.3), randf_range(0.3, 1.2), randf_range(-0.3, 0.3)),
						Vector3(0, 1.1, 0), Color(0.55, 1.0, 0.5, 0.9), 0.14, 1.0, -0.4, 0.2, true)
				bars.float_text(_screen(f.global_position + Vector3(0, f.top + 0.3, 0)), "+%d" % int(e["amount"]), "heal")
			"end":
				pass


func _perk_fx(e: Dictionary) -> void:
	var id := String(e["id"])
	var side := String(e["side"])
	var ours := side == "ally"
	var allies := sim.alive_of(side)
	var foes := sim.alive_of("enemy" if ours else "ally")
	say((PERK_SAY.get(id, "") as String) if ours else "Соперник: " + String(Legion.PERKS[id]["name"]), 1.3)
	if perk_btns.has(id) and ours:
		(perk_btns[id] as PerkButton).pop = 1.0
	match id:
		"oil":
			var at := Vector3(float(e.get("x", 0.0)), 0.0, float(e.get("z", 0.0)))
			at.y = _h(at.x, at.z)
			fx.cauldron(at - Vector3(0.6 if ours else -0.6, 0, 0))
			_play("pot", -8.0, 0.8)
		"volley":
			var pts := []
			for u in foes:
				pts.append(Vector3(u.x, _h(u.x, u.z), u.z))
			fx.volley(pts)
			for i in 3:
				_play("whoosh", -12.0, randf_range(0.8, 1.0))
		"testudo":
			for u in allies:
				fx.burst(Vector3(u.x, 1.0, u.z), Color(1.0, 0.84, 0.4, 0.9), 8, 0.8, 1.2, 0.1, 0.7, true, 0.5)
			_play("pot", -10.0, 1.2)
		"bandage":
			for u in allies:
				for i in 5:
					fx.add(Vector3(u.x + randf_range(-0.3, 0.3), 0.5, u.z + randf_range(-0.3, 0.3)), Vector3(0, 1.4, 0), Color(0.55, 1.0, 0.5, 0.9), 0.12, 1.0, 0.0, 0.3, true)
		"horn":
			var cx := 0.0
			for u in allies:
				cx += u.x
			cx /= maxf(1.0, allies.size())
			fx.ring(Vector3(cx, 0.0, 0.0), 5.0, Color(1.0, 0.66, 0.3, 0.9), 0.9, 1.2)
			_play("horn", -6.0, 1.0)


func _begin_end() -> void:
	phase = "ending"
	end_t = 0.0
	tut_freeze = false                       # отступили, пока бой стоял на масле
	retreat_btn.disabled = true
	var res := sim.result
	if pvp:
		out = legion.apply_pvp_result(setup, res)
	else:
		out = legion.apply_result(setup, res)
	out["retreat"] = bool(res.get("retreat", false))
	finished.emit(out)
	var win := bool(out.get("win", false))
	if not bool(out["retreat"]):
		say("Победа!" if win else "Отряд отступает…", 2.0)
	for id in views:
		var v: Dictionary = views[id]
		var u: LegionSim.Unit = v["u"]
		if u.alive and ((u.side == "ally") == win):
			(v["f"] as LegionFighter).cheer()
	_play("win" if win else "fall", -6.0 if win else -10.0, 1.0)


func _update_views(gdt: float, dt: float) -> void:
	var k := 1.0 - exp(-dt * 16.0)
	for id in views:
		var v: Dictionary = views[id]
		var u: LegionSim.Unit = v["u"]
		var f: LegionFighter = v["f"]
		f.set_speed(speed * slowmo if gdt > 0.0 else 0.0)
		if gdt > 0.0:
			f.tick(gdt)
		if not u.alive:
			continue
		var p := f.position
		var dx := u.x - float(v["px"])
		var dz := u.z - float(v["pz"])
		p.x = lerpf(p.x, u.x, k)
		p.z = lerpf(p.z, u.z, k)
		f.position = p
		f.set_ground(_h(p.x, p.z))
		v["px"] = u.x
		v["pz"] = u.z
		if phase != "ending" and phase != "result":
			var fast := u.horn_k if u.horn > sim.t else 1.0
			f.set_motion(u.moving, u.speed * fast * (1.4 if u.entering else 1.0))
			f.face(_face_yaw(u, dx * 30.0 if absf(dx) > 0.001 else (1.0 if u.side == "ally" else -1.0), dz * 30.0), gdt)
			# шаги поднимают пыль
			if u.moving and gdt > 0.0 and (u.speed >= 1.8 or u.size > 1.2):
				v["step_t"] = float(v["step_t"]) - gdt
				if float(v["step_t"]) <= 0.0:
					v["step_t"] = 0.3 / maxf(0.5, u.speed)
					fx.add(Vector3(p.x + randf_range(-0.15, 0.15), f.position.y + 0.04, p.z + randf_range(-0.15, 0.15)), Vector3(randf_range(-0.2, 0.2), 0.2, 0),
						Color(0.8, 0.72, 0.58, 0.16 * minf(1.6, u.size)), 0.2 * u.size, 0.7, -0.1, 1.2)
		else:
			f.face(_face_yaw(u, 1.0 if u.side == "ally" else -1.0, 0.0), dt)
		# черепаха и рог — круги под ногами; ожог — языки пламени
		_status(v, "testudo", u.testudo > sim.t, Color(1.0, 0.82, 0.35, 0.85))
		_status(v, "horn", u.horn > sim.t, Color(1.0, 0.5, 0.25, 0.8))
		_status(v, "summon", u.summon_warned and phase == "fight", Color(0.95, 0.16, 0.08, 0.9))
		if u.burn > sim.t and gdt > 0.0 and randf() < 0.5:
			fx.add(f.global_position + Vector3(randf_range(-0.3, 0.3), randf_range(0.2, 1.1) * u.size, randf_range(-0.2, 0.2)), Vector3(0, 1.3, 0),
				Color(1.0, 0.55 + randf() * 0.3, 0.15, 0.95), 0.16, 0.5, -0.5, -0.4, true)
		if f.embers and gdt > 0.0 and randf() < 0.25:
			fx.add(f.global_position + Vector3(randf_range(-0.4, 0.4), randf_range(0.2, 0.8) * u.size, randf_range(-0.3, 0.3)), Vector3(0, 0.6, 0),
				Color(1.0, 0.45, 0.15, 0.9), 0.06, 0.9, -0.3, 0.0, true)


func _status(v: Dictionary, kind: String, on: bool, col: Color) -> void:
	if on and not v.has(kind):
		var size: float = (v["u"] as LegionSim.Unit).size
		v[kind] = fx.status_ring(col, (1.0 if kind == "summon" else 0.6) * size)
	elif not on and v.has(kind):
		if is_instance_valid(v[kind]):
			(v[kind] as Node).queue_free()
		v.erase(kind)
	if v.has(kind):
		var r: MeshInstance3D = v[kind]
		var f: LegionFighter = v["f"]
		r.position = Vector3(f.position.x, f.position.y + 0.05 + (0.01 if kind == "horn" else 0.0), f.position.z)
		var pulse := 1.0 + sin(t_vis * 6.0) * 0.06
		if kind == "summon":
			pulse = 1.0 + absf(sin(t_vis * 7.0)) * 0.3       # рог атамана: круг бьётся, как тревога
		r.scale = Vector3(pulse, 1.0, pulse) * (1.18 if kind == "horn" else 1.0)


## Красный круг за кучей врагов (радиус — как у котла масла): идёт за ними, пока не сбегутся, и ещё 2,5 с;
## сбежались — надпись text (миг для масла)
func _crowd(units: Array, text := "") -> void:
	if units.size() < 2 or fx == null:
		return
	var ring := fx.status_ring(Color(0.95, 0.2, 0.1, 0.85), 2.2)
	_crowds.append({"units": units, "ring": ring, "t": 0.0, "say": text})
	_update_crowds(0.0)


func _update_crowds(gdt: float) -> void:
	var keep: Array = []
	for c: Dictionary in _crowds:
		var ring: MeshInstance3D = c["ring"]
		var n := 0
		var at := Vector3.ZERO
		var entering := false
		for u: LegionSim.Unit in c["units"]:
			if u.alive:
				n += 1
				at += Vector3(u.x, 0.0, u.z)
				entering = entering or u.entering
		if not entering:
			if float(c["t"]) == 0.0 and gdt > 0.0 and String(c["say"]) != "" and n >= 2:
				say(String(c["say"]), 2.4)
			c["t"] = float(c["t"]) + gdt
		if n < 2 or float(c["t"]) > 2.5 or phase == "ending" or phase == "result" or not is_instance_valid(ring):
			if is_instance_valid(ring):
				ring.queue_free()
			continue
		at /= n
		at.y = _h(at.x, at.z) + 0.07
		ring.position = at
		var pulse := 1.0 + absf(sin(t_vis * 5.0)) * 0.12
		ring.scale = Vector3(pulse, 1.0, pulse)
		keep.append(c)
	_crowds = keep


func _update_shots() -> void:
	var live := {}
	for s in sim.shots:
		live[s] = true
	for s in shots.keys():
		var mi: MeshInstance3D = shots[s]
		if not live.has(s):
			# долетел: стрела и болт — пыль, камни — у боя своё событие (boom)
			var sh: LegionSim.Shot = s
			if sh.kind == "arrow" or sh.kind == "bolt" or sh.kind == "sling":
				fx.dust(Vector3(sh.x1, _h(sh.x1, sh.z1) + 0.3, sh.z1), 0.35)
			mi.queue_free()
			shots.erase(s)
			continue
		_place_shot(s, mi)


func _shot_pos(s: LegionSim.Shot, k: float) -> Vector3:
	var fs := s.from.size if s.from != null else 1.0
	var ts := s.target.size if s.target != null else 1.0
	var y0 := 1.25 * fs
	if s.kind == "bolt":
		y0 = 1.0
	elif s.kind == "stone":
		y0 = 1.3
	elif s.kind == "boulder":
		y0 = 1.9 * fs
	var y1 := 0.8 * ts
	if s.kind == "stone" or s.kind == "boulder":
		y1 = 0.25
	var d := absf(s.x1 - s.x0)
	var arc := 0.6 + d * 0.07
	match s.kind:
		"stone", "boulder":
			arc = 2.4 + d * 0.16
		"bolt":
			arc = 0.12 + d * 0.01
		"sling":
			arc = 0.4 + d * 0.05
	return Vector3(lerpf(s.x0, s.x1, k), lerpf(y0, y1, k) + sin(k * PI) * arc, lerpf(s.z0, s.z1, k))


func _place_shot(s: LegionSim.Shot, mi: MeshInstance3D) -> void:
	var k := s.k() + clampf(acc / maxf(0.001, s.dur), 0.0, 0.1)
	var p := _shot_pos(s, minf(1.0, k))
	var q := _shot_pos(s, minf(1.0, k + 0.03))
	mi.position = p
	if s.kind == "stone" or s.kind == "boulder" or s.kind == "sling":
		mi.rotation = Vector3(k * 9.0, k * 7.0, 0.0)
		if s.kind == "sling":
			mi.scale = Vector3.ONE * 0.8
	elif q.distance_squared_to(p) > 1e-8:
		mi.look_at(q, Vector3.UP)
		mi.rotate_object_local(Vector3.UP, PI)


# =====================================================================
#   камера: вступление, слежение за схваткой, тряска
# =====================================================================

func _camera(dt: float) -> void:
	var alive_x := 0.0
	var n := 0
	for u in sim.units:
		if u.alive and not u.entering and u.speed > 0.0:
			alive_x += u.x
			n += 1
	var want := clampf(alive_x / n if n > 0 else 0.0, -2.5, 3.5)
	if opts.has("cam_x"):
		want = float(opts["cam_x"])            # проверки: камера стоит над точкой поля
	var vs := Vector2(sub.size)
	var aspect := vs.x / maxf(1.0, vs.y)
	var base_d := 19.0 * maxf(1.0, 1.7 / maxf(0.5, aspect)) * zoom
	var pitch := deg_to_rad(25.0)
	var d := base_d
	var tx := want
	if phase == "intro":
		var k := smoothstep(0.0, 2.4, intro_t)
		k = k * k * (3.0 - 2.0 * k)
		tx = lerpf(-6.0, want, k)
		d = lerpf(11.5, base_d, k)
		pitch = deg_to_rad(lerpf(14.0, 25.0, k))
		cam_x = tx
	elif phase == "ending" or phase == "result":
		d = lerpf(cam_d, base_d * 0.86, minf(1.0, dt * 0.8))
		cam_x = lerpf(cam_x, want, minf(1.0, dt * 1.0))
	else:
		cam_x = lerpf(cam_x, want, minf(1.0, dt * 1.2))
		d = lerpf(cam_d, base_d, minf(1.0, dt * 2.0))
	cam_d = d
	var target := Vector3(cam_x + 0.6, 0.9, -1.6)
	var pos := target + Vector3(0.0, sin(pitch), cos(pitch)) * d
	if shake > 0.0:
		pos += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.4
		shake = maxf(0.0, shake - dt * 0.8)
	cam.look_at_from_position(pos, target, Vector3.UP)
	cam_attrs.dof_blur_far_distance = d * 1.15
	cam_attrs.dof_blur_far_transition = d * 0.9
	cam_attrs.dof_blur_near_distance = d * 0.58
	cam_attrs.dof_blur_near_transition = d * 0.3


## Точка мира → точка интерфейса (интерфейс в логических единицах окна)
func _screen(p: Vector3) -> Vector2:
	if cam == null or cam.is_position_behind(p):
		return Vector2(-999, -999)
	var sp := cam.unproject_position(p)
	var k := ui.size / Vector2(sub.size)
	return sp * k


# =====================================================================
#   интерфейс: умения, босс, скорость
# =====================================================================

func _update_ui() -> void:
	for id in perk_btns:
		var pb: PerkButton = perk_btns[id]
		pb.charge = sim.perk_charge(id)
		pb.left = sim.perk_ready(id)
		pb.active = phase == "fight" or phase == "intro"
		pb.auto = bool(sim.auto["ally"])
		pb.queue_redraw()
	var boss := _boss_unit
	if boss != null and boss.alive:
		boss_panel.visible = true
		boss_name.text = boss.name
		boss_bar.value = boss.hp_frac()
		if boss_pic.texture == null:
			boss_pic.texture = Legion.art_texture("enemy", boss.key)
			if boss_pic.texture == null:
				boss_pic.texture = _icon_tex("helmet")
	else:
		boss_panel.visible = false


func _set_speed(s: float) -> void:
	if tut != "":
		return
	speed = s
	legion.flags["battle_speed"] = s
	_refresh_speed()


func _refresh_speed() -> void:
	for s in speed_btns:
		(speed_btns[s] as Button).set_pressed_no_signal(int(speed) == int(s))
	if auto_btn and sim:
		var on := bool(sim.auto["ally"])
		auto_btn.set_pressed_no_signal(on)
		auto_btn.icon = _icon_tex("check") if on else null
	if pause_btn:
		pause_btn.icon = _icon_tex("play" if paused else "pause")


func _toggle_auto() -> void:
	if auto_btn.disabled or tut != "":
		_refresh_speed()
		return
	sim.set_auto(not bool(sim.auto["ally"]))
	legion.flags["battle_auto"] = sim.auto["ally"]
	_refresh_speed()


func _toggle_pause() -> void:
	if phase == "result" or modal != null:
		return
	paused = not paused
	pause_lbl.visible = paused
	_refresh_speed()


func use_perk(id: String) -> void:
	if phase != "fight" and phase != "intro":
		return
	if tut_freeze and id != "oil":
		return
	if sim.press(id):
		_handle(sim.take_events())
		if tut_freeze and id == "oil":
			# учебный бой: масло накрыло шайку — бой идёт дальше
			tut_freeze = false
			tut_done = true
			tut_arrow.visible = false
			legion.flags["tut_oil"] = true
			hint_lbl.text = "Отлично! Котёл снова закипит через %d с." % int(Legion.PERKS["oil"]["cd"])
			hint_lbl.visible = true
			hint_lbl.modulate.a = 1.0
			hint_until = sim.t + 6.0


## Учебный бой: вторая волна (шайка кучей) вышла на поле — бой замирает, масло готово, стрелка на кнопке
func _tut_check() -> void:
	if tut != "oil" or tut_done or tut_freeze or sim.wave_idx < 1 or not sim.result.is_empty():
		return
	var n := 0
	for u in sim.units:
		if u.side == "enemy" and u.wave == sim.wave_idx and u.alive:
			if u.entering:
				return
			n += 1
	if n == 0 or not sim.perks["ally"].has("oil"):
		return
	tut_freeze = true
	acc = 0.0
	sim.perks["ally"]["oil"]["ready"] = 0.0
	hint_lbl.text = "Разбойники сбились в кучу! Жмите «Кипящее масло» (клавиша 1)"
	hint_lbl.visible = true
	hint_lbl.modulate.a = 1.0
	say("Разбойники сбились в кучу!", 2.0)


## Стрелка над кнопкой «Кипящее масло», пока бой стоит (покачивается)
func _tut_arrow(_dt: float) -> void:
	var pb: Control = perk_btns.get("oil")
	tut_arrow.visible = tut_freeze and pb != null and is_instance_valid(pb) and phase != "result"
	if not tut_arrow.visible:
		return
	var r := pb.get_global_rect()
	var bob := sin(Time.get_ticks_msec() / 160.0) * 8.0
	var k := ui.get_global_transform().affine_inverse()
	var top := k * Vector2(r.get_center().x, r.position.y)
	tut_arrow.position = Vector2(top.x - tut_arrow.size.x * 0.5, top.y - tut_arrow.size.y - 2.0 + bob)


func _unhandled_key_input(e: InputEvent) -> void:
	pass


func _input(e: InputEvent) -> void:
	if not (e is InputEventKey):
		return
	# клавиши боя не уходят в город (там ими ставят дома, крутят камеру и меняют скорость)
	get_viewport().set_input_as_handled()
	if sim == null or world == null:
		return
	var k := e as InputEventKey
	if not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_ESCAPE:
			if phase == "result":
				_close()
			elif modal != null:
				_close_modal()
			elif phase != "ending":
				_ask_retreat()
		KEY_SPACE:
			_toggle_pause()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			var i := int(k.keycode - KEY_1)
			var ids := perk_btns.keys()
			if i < ids.size():
				use_perk(String(ids[i]))


# =====================================================================
#   отступление, итог, выход
# =====================================================================

func _ask_retreat() -> void:
	if phase == "ending" or phase == "result" or modal != null:
		return
	var p := _modal_panel(440)
	var v: VBoxContainer = p.get_child(0)
	var t := _label("Отступить?", 30, false, C_INK, font_title)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var d := _label("Бой будет проигран, провиант не вернётся. Бойцы вернутся в лагерь целыми.", 18, false, C_SOFT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(380, 0)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(d)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	h.add_child(_button("Отступить", "exit", _retreat, 160))
	h.add_child(_button("Продолжить бой", "play", _close_modal, 190))
	v.add_child(h)


func _retreat() -> void:
	_close_modal()
	if not sim.result.is_empty():
		return
	var alive := sim.alive_of("ally").size()
	var hp := 0.0
	var mx := 0.0
	for u in sim.units:
		if u.side == "ally":
			mx += u.max_hp
			if u.alive:
				hp += u.hp
	sim.result = {"win": false, "alive": alive, "total": sim.total, "timeout": false, "time": sim.t, "hp_left": hp / maxf(1.0, mx), "retreat": true}
	sim.dispose()
	_begin_end()
	end_t = 1.6


func _modal_panel(w: float) -> PanelContainer:
	if modal != null and is_instance_valid(modal):
		modal.queue_free()
	var back := ColorRect.new()
	back.color = Color(0.1, 0.06, 0.03, 0.45)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(back)
	modal = back
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(w, 0)
	p.set_anchors_preset(Control.PRESET_CENTER)
	back.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	p.resized.connect(func(): p.position = (back.size - p.size) * 0.5)
	back.resized.connect(func(): p.position = (back.size - p.size) * 0.5)
	return p


func _close_modal() -> void:
	if modal != null and is_instance_valid(modal):
		modal.queue_free()
	modal = null


## Экран итога: победа или поражение, звёзды, добыча, рейтинг, что открылось; дальше — следующий бой, ещё раз, в лагерь
func _show_result() -> void:
	phase = "result"
	var win := bool(out.get("win", false))
	var p := _modal_panel(560)
	var v: VBoxContainer = p.get_child(0)
	v.add_theme_constant_override("separation", 10)
	# лавровый венок со звездой — победа, сломанное копьё — поражение (лист 38 владельца; без него — значки игры)
	var badge := TextureRect.new()
	badge.texture = _sheet("38", 14 if win else 13)
	if badge.texture == null:
		badge.texture = _icon_tex("laurels" if win else "swords")
	badge.custom_minimum_size = Vector2(84, 84)
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(badge)
	var head := _label("Победа!" if win else ("Отступили" if bool(out.get("retreat", false)) else "Поражение"), 44, false, Color("6b4a12") if win else C_BAD, font_title)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var where := ""
	if pvp:
		where = "Бой с городом «%s»" % String((setup.get("opponent", {}) as Dictionary).get("name", "?"))
	else:
		where = "%s — %s" % [stage.get("title", ""), stage.get("theme", "") if String(stage.get("theme", "")) != "" else stage.get("name", "")]
	var wl := _label(where, 18, true, C_SOFT)
	wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(wl)
	if win and not pvp:
		var sr := Stars.new()
		sr.n = int(out.get("stars", 0))
		sr.mask = int(out.get("star_mask", 0))
		sr.custom_minimum_size = Vector2(200, 56)
		sr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(sr)
		v.add_child(_star_lines())
	var al := _label("Вернулись %d из %d бойцов" % [int(out.get("alive", 0)), int(out.get("total", 0))], 18, false, C_INK)
	al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(al)
	v.add_child(_squad_row())
	var rw: Dictionary = out.get("reward", {})
	if not rw.is_empty():
		var rh := HBoxContainer.new()
		rh.alignment = BoxContainer.ALIGNMENT_CENTER
		rh.add_theme_constant_override("separation", 18)
		for key: String in ["money", "glory", "rp"]:
			if rw.has(key):
				rh.add_child(_reward_chip(key, int(rw[key])))
		v.add_child(rh)
		if int(out.get("money_lost", 0)) > 0:
			# казна полна: предел остаётся, но честно — сколько не уместилось
			var ll := _label("Казна полна — не уместилось %d ден." % int(out["money_lost"]), 15, true, C_BAD)
			ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(ll)
		if bool(out.get("first", false)):
			var fl := _label("Первая победа здесь — добыча больше!", 16, true, C_GOOD)
			fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(fl)
		if int(out.get("star_glory", 0)) > 0:
			var gl := _label("Все три звезды в этом бою — +%d Славы!" % int(out["star_glory"]), 16, true, C_GOOD)
			gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(gl)
	var chest: Dictionary = out.get("chest", {})
	if not chest.is_empty():
		var ct := "Все 30 звёзд «%s»! Сундук Славы +%d." % [String(chest["region"]), int(chest["glory"])]
		if String(chest.get("trophy", "")) != "" and Defs.B.has(String(chest["trophy"])):
			ct += " В город — трофей «%s» (раздел «Украшения»)." % String(Defs.B[String(chest["trophy"])]["name"])
		var cl := _label(ct, 17, true, Color("6b4a12"))
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cl.custom_minimum_size = Vector2(480, 0)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(cl)
	if pvp:
		var dd := int(out.get("delta", 0))
		var dl := _label("Рейтинг побед: %s%d" % ["+" if dd >= 0 else "", dd], 19, true, C_GOOD if dd >= 0 else C_BAD)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(dl)
	elif int(out.get("rating", 0)) > 0:
		var rl := _label("Рейтинг походов +%d" % int(out["rating"]), 18, true, C_GOOD)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(rl)
	var unl: Array = out.get("unlocks", [])
	if not unl.is_empty():
		var ul := _label("Открыто: " + ", ".join(unl) + ".", 18, true, Color("6b4a12"))
		ul.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ul.custom_minimum_size = Vector2(480, 0)
		ul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(ul)
	if not win:
		var tip := "Не беда! Улучшите бойцов в окне «Легион» → «Войска», поставьте в отряд тех, кто сильнее против этих врагов, и вовремя жмите умения."
		if not pvp:
			# совет по составу под этот бой (без тех родов войск, которых у игрока ещё нет)
			var sh := legion.squad_hint(stage)
			var ct := legion.tips(stage)
			if sh != "":
				tip += " " + sh
			# совет против этих врагов — и при совете по составу (у боёв леса он про то же — тогда не повторяем)
			if ct != "" and (sh == "" or not bool(stage.get("fixed", false))):
				tip += " " + ct
		var tl := _label(tip, 16, false, C_SOFT)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.custom_minimum_size = Vector2(480, 0)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(tl)
	var bh := HBoxContainer.new()
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	bh.add_theme_constant_override("separation", 10)
	v.add_child(bh)
	var nx: Dictionary = out.get("next", {})
	if win and not pvp and not nx.is_empty() and not bool(out.get("boss_beaten", false)):
		var why := legion.can_fight(nx)
		var nb := _button("Дальше: " + (String(nx["name"]) if bool(nx.get("boss", false)) else "бой %d" % (int(nx["s"]) + 1)), "swords", func(): _again(nx), 0)
		nb.disabled = why != ""
		nb.tooltip_text = why
		bh.add_child(nb)
	if not pvp:
		var st := legion.stage_info(int(stage["cycle"]), int(stage["r"]), int(stage["s"]))
		var why2 := legion.can_fight(st)
		var ab := _button("Ещё раз", "redo", func(): _again(st), 0)
		ab.disabled = why2 != ""
		ab.tooltip_text = why2
		bh.add_child(ab)
	bh.add_child(_button("В лагерь" if not pvp else "К соперникам", "legion", _close, 0))


## Три условия звёзд под звёздами: добытые — золотые, недобытая — серая и почему («пали 1 из 3»)
func _star_lines() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var mask := int(out.get("star_mask", 0))
	var texts := Legion.star_texts(stage)
	for i in 3:
		var on := (mask & (1 << i)) != 0
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		var s := Stars.new()
		s.of = 1
		s.n = 1 if on else 0
		s.custom_minimum_size = Vector2(24, 24)
		h.add_child(s)
		h.add_child(_label(String(texts[i]), 16, on, C_INK if on else C_SOFT))
		if not on:
			h.add_child(_label("— " + Legion.star_miss(i, out, stage), 16, true, C_BAD))
		box.add_child(h)
	# один раз — как устроены звёзды
	if not legion.flags.has("stars_tip"):
		legion.flags["stars_tip"] = true
		var tl := _label("Звёзды — за мастерство, каждая добывается раз и навсегда. Все три в бою — +%d Славы; все 30 звёзд провинции — сундук Славы и трофей в город." % Legion.STAR_GLORY, 14, false, C_SOFT)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.custom_minimum_size = Vector2(460, 0)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(tl)
		return box
	var best := int(out.get("star_best", 0))
	if best > int(out.get("stars", 0)):
		var bl := _label("Лучшее в этом бою — %d %s из 3: добытые звёзды не теряются" % [best, Hud._plural(best, "звезда", "звезды", "звёзд")], 14, false, C_SOFT)
		box.add_child(bl)
	return box


## Отряд после боя: портреты бойцов (лист 35 владельца), павшие — серые
func _squad_row() -> Control:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 6)
	h.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for u in sim.units:
		if u.side != "ally":
			continue
		var tr := TextureRect.new()
		tr.texture = Legion.art_texture("unit", u.key) if Legion.UNITS.has(u.key) else null
		if u.key == "hero":
			tr.texture = _hero_face()                 # свой герой — его лицо (с медальона «Герой»), в круге
			if tr.texture != null:
				tr.material = StoryUi._mask_mat()
		if tr.texture == null:
			tr.texture = _icon_tex(String({"legionary": "helmet", "spearman": "shield", "archer": "arrow", "ballista": "hammer", "catapult": "rock", "hero": "caesar"}.get(u.key, "helmet")))
		tr.custom_minimum_size = Vector2(54, 54)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.tooltip_text = "%s, ур. %d%s" % [u.name, u.level, "" if u.alive else " — пал в бою"]
		if not u.alive:
			tr.modulate = Color(0.42, 0.38, 0.36, 0.75)
		h.add_child(tr)
	return h


## Лицо героя для итога боя: картинка медальона «Герой» (null — ещё не нарисована)
func _hero_face() -> Texture2D:
	var hud = game.hud if game != null else null
	var hb: Button = hud.get("hero_btn") if hud != null else null
	if hb == null or hb.get_node_or_null("ic") == null or (hb.get_node("ic") as TextureRect).material == null:
		return null
	return (hb.get_node("ic") as TextureRect).texture


## Картинка с листа владельца (assets/ui/ai/legion/<лист>.png) по номеру; null — листа нет
func _sheet(sheet: String, i: int) -> Texture2D:
	var path := Legion.ART_DIR + sheet + ".png"
	if not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	if tex == null:
		return null
	var g: Array = Legion.ART_SHEETS.get(sheet, [1, 1])
	var w := tex.get_width() / int(g[0])
	var hh := tex.get_height() / int(g[1])
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2((i % int(g[0])) * w, (i / int(g[0])) * hh, w, hh)
	return at


func _reward_chip(key: String, n: int) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	var ic := TextureRect.new()
	var tex: Texture2D = null
	match key:
		"money":
			tex = _icon_tex("coins")
		"glory":
			tex = _icon_tex("laurels")
		"rp":
			tex = _icon_tex("research")
	ic.texture = tex
	ic.custom_minimum_size = Vector2(34, 34)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(ic)
	var names := {"money": "денариев", "glory": "Славы", "rp": "очков знаний"}
	var l := _label("+%d %s" % [n, names.get(key, "")], 21, true, C_GOOD)
	h.add_child(l)
	return h


## Следующий бой или тот же ещё раз — не выходя в город
func _again(st: Dictionary) -> void:
	if legion.can_fight(st) != "":
		return
	var s := legion.make_battle(st)
	_loading(s)
	fade.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, 0.35)
	tw.tween_callback(func():
		_close_modal()
		_start(s))


## Выход в город: всё возвращается как было, окно «Легион» открывается снова (battle_closed)
func _close() -> void:
	if phase == "closing":
		return
	phase = "closing"
	fade_map.texture = null
	fade_lbl.text = ""
	fade.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, 0.3)
	tw.tween_callback(func():
		_clear_world()
		_leave()
		if game != null and is_instance_valid(game) and game.can_save and not out.is_empty():
			game.save()                          # добыча и прогресс похода — сразу в сохранение (и в облако)
		var o := out
		if current == self:
			current = null
		legion.battle_closed.emit(o)
		if on_done.is_valid():
			on_done.call(o)
		queue_free())


## Бросить бой без итога (проверки, выход из игры)
func abort() -> void:
	if sim != null:
		sim.dispose()
	_clear_world()
	_leave()
	if current == self:
		current = null
	queue_free()


# =====================================================================
#   звук: удары, щиты, падения, скрип машин, рог (рог — синтез)
# =====================================================================

const SOUNDS := {"clash": ["knifeSlice", "knifeSlice2", "chop"], "thud": ["dropLeather", "chop"], "fall": ["dropLeather"],
	"pot": ["metalPot1", "metalPot2", "metalPot3"], "creak": ["creak1", "creak3"], "whoosh": ["cloth1", "drawKnife1", "drawKnife2"],
	"boom": ["dropLeather"], "win": ["handleCoins"]}
static var _streams := {}
static var _horn: AudioStreamWAV


func _play(kind: String, db := -10.0, pitch := 1.0) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_snd_t.get(kind, -1.0)) < 0.07:
		return
	_snd_t[kind] = now
	var st: AudioStream = null
	if kind == "horn":
		st = _horn_stream()
	else:
		var list: Array = SOUNDS.get(kind, [])
		if list.is_empty():
			return
		var nm: String = list[randi() % list.size()]
		if not _streams.has(nm):
			var path := "res://assets/sfx/battle/%s.ogg" % nm
			_streams[nm] = load(path) if ResourceLoader.exists(path) else null
		st = _streams[nm]
	if st == null:
		return
	for p in players:
		if not p.playing:
			p.stream = st
			p.volume_db = db
			p.pitch_scale = pitch
			p.play()
			return


## Боевой рог (корну): низкий тёплый звук с вибрато, мягкое нарастание и затухание
static func _horn_stream() -> AudioStreamWAV:
	if _horn != null:
		return _horn
	var rate := 22050
	var dur := 1.25
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		var env := smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(dur - 0.45, dur, t))
		var f := 146.8 * (1.0 + 0.006 * sin(TAU * 5.2 * t)) * (1.0 + 0.04 * (1.0 - smoothstep(0.0, 0.15, t)))
		var ph := fmod(f * t, 1.0)
		var saw := 2.0 * ph - 1.0
		var ph2 := fmod(f * 1.5 * t, 1.0)
		var s := saw * 0.6 + (2.0 * ph2 - 1.0) * 0.25 + sin(TAU * f * 0.5 * t) * 0.35
		lp += (s - lp) * 0.12
		var v := clampf(lp * env * 0.55, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	_horn = AudioStreamWAV.new()
	_horn.format = AudioStreamWAV.FORMAT_16_BITS
	_horn.mix_rate = rate
	_horn.stereo = false
	_horn.data = data
	return _horn


# =====================================================================
#   рисованные мелочи: полоски здоровья и числа, кнопки умений, звёзды, волны
# =====================================================================

## Полоски здоровья над бойцами и всплывающие числа — всё одним слоем
class BarsLayer extends Control:
	var battle: LegionBattle
	var floats: Array = []                 # [pos, text, kind, t]

	func float_text(p: Vector2, text: String, kind: String) -> void:
		if p.x < -100.0:
			return
		if floats.size() > 40:
			floats.pop_front()
		floats.append([p + Vector2(randf_range(-14, 14), 0), text, kind, 0.0])

	func _process(dt: float) -> void:
		var keep: Array = []
		for f: Array in floats:
			f[3] += dt
			if f[3] < 1.0:
				keep.append(f)
		floats = keep

	func _draw() -> void:
		if battle == null or battle.sim == null or battle.phase == "result":
			return
		var fnt: Font = battle.font_bold
		for id in battle.views:
			var v: Dictionary = battle.views[id]
			var u: LegionSim.Unit = v["u"]
			if not u.alive or u.boss:
				continue
			var f: LegionFighter = v["f"]
			var p := battle._screen(f.global_position + Vector3(0, f.top, 0))
			if p.x < -50.0:
				continue
			var w := 40.0 if u.size <= 1.05 else 56.0
			var hp := u.hp_frac()
			v["hp"] = lerpf(float(v["hp"]), hp, 0.12)
			var r := Rect2(p.x - w * 0.5, p.y - 4.0, w, 7.0)
			draw_rect(r.grow(1.5), Color(0.18, 0.1, 0.05, 0.75))
			draw_rect(Rect2(r.position, Vector2(w * float(v["hp"]), 7.0)), Color(1.0, 0.9, 0.7, 0.55))
			var col := Color("8cc63f") if u.side == "ally" else Color("d9473a")
			if u.side == "ally" and hp < 0.35:
				col = Color("e6b03a")
			draw_rect(Rect2(r.position, Vector2(w * hp, 7.0)), col)
			draw_rect(Rect2(r.position, Vector2(w * hp, 2.0)), Color(1, 1, 1, 0.25))
			if u.key == "hero":
				# свой герой (Д11): золотая кайма полоски и имя над ней — его видно в толчее
				draw_rect(r.grow(1.5), Color("e8b84a"), false, 2.0)
				var nm := u.name
				var tw := fnt.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
				var np := Vector2(p.x - tw * 0.5, p.y - 9.0)
				draw_string_outline(fnt, np, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(0.2, 0.08, 0.03, 0.9))
				draw_string(fnt, np, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("ffe08a"))
		for fl: Array in floats:
			var k: float = fl[3]
			var pos: Vector2 = fl[0] - Vector2(0, 46.0 * ease(k, 0.5))
			var kind: String = fl[2]
			var size := 20 if kind != "crit" else 27
			var col := Color("fff1d2")
			if kind == "crit":
				col = Color("ffd34d")
			elif kind == "hurt":
				col = Color("ff9a7a")
			elif kind == "heal":
				col = Color("9cf08a")
			col.a = 1.0 - smoothstep(0.6, 1.0, k)
			var txt: String = fl[1]
			var tw := fnt.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			draw_string_outline(fnt, pos - Vector2(tw * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0.2, 0.08, 0.03, col.a * 0.85))
			draw_string(fnt, pos - Vector2(tw * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## Кнопка умения: бронзовый медальон, картинка, перезарядка (тёмный сектор и секунды), имя, уровень, клавиша
class PerkButton extends Control:
	var battle: LegionBattle
	var id := ""
	var key_n := 1
	var lvl := 1
	var icon: Texture2D
	var medal: Texture2D
	var medal_on: Texture2D
	var charge := 0.0
	var left := 0.0
	var active := true
	var auto := false
	var pop := 0.0
	var _hover := false

	func _ready() -> void:
		mouse_entered.connect(func(): _hover = true; queue_redraw())
		mouse_exited.connect(func(): _hover = false; queue_redraw())

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			battle.use_perk(id)
			accept_event()

	func _process(dt: float) -> void:
		if pop > 0.0:
			pop = maxf(0.0, pop - dt * 3.0)
			queue_redraw()

	func _draw() -> void:
		var d := 86.0
		var c := Vector2(size.x * 0.5, 46.0)
		var ready := charge >= 1.0 and active
		var s := d * (1.0 + 0.12 * sin(pop * PI)) * (1.04 if _hover and ready else 1.0)
		var rect := Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s))
		if ready:
			var glow := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 1000.0 * 4.0)
			draw_texture_rect(medal_on, rect.grow(s * 0.08), false, Color(1, 1, 1, glow))
		draw_texture_rect(medal, rect, false)
		if icon:
			var ir := rect.grow(-s * 0.16)
			draw_texture_rect(icon, ir, false, Color(1, 1, 1, 1.0 if ready else 0.75))
		if charge < 1.0:
			# тёмный сектор того, что ещё не накопилось (по часовой от верха)
			var pts := PackedVector2Array([c])
			var a0 := -PI / 2.0 + TAU * charge
			var steps := 32
			for i in steps + 1:
				var a := lerpf(a0, -PI / 2.0 + TAU, float(i) / steps)
				pts.append(c + Vector2(cos(a), sin(a)) * s * 0.4)
			if pts.size() >= 3:
				draw_colored_polygon(pts, Color(0.12, 0.07, 0.03, 0.62))
			draw_arc(c, s * 0.42, -PI / 2.0, -PI / 2.0 + TAU * charge, 40, Color(1.0, 0.82, 0.35, 0.95), 4.0, true)
			if left > 0.0:
				var txt := str(ceili(left))
				var f: Font = battle.font_bold
				var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
				draw_string_outline(f, c + Vector2(-tw * 0.5, 11), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 6, Color(0.15, 0.08, 0.03, 0.9))
				draw_string(f, c + Vector2(-tw * 0.5, 11), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("fff1d2"))
		# клавиша
		var kf: Font = battle.font_bold
		draw_circle(c + Vector2(-s * 0.4, -s * 0.36), 12.0, Color(0.3, 0.17, 0.07, 0.9))
		draw_string(kf, c + Vector2(-s * 0.4 - 5, -s * 0.36 + 7), str(key_n), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ffe7b0"))
		# имя и уровень
		var nm := String(Legion.PERKS[id]["name"])
		var fs := 15
		var nw := battle.font_bold.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(battle.font_bold, Vector2((size.x - nw) * 0.5, 104), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(1.0, 0.96, 0.86, 0.9))
		draw_string(battle.font_bold, Vector2((size.x - nw) * 0.5, 104), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("4a2c17"))
		var lv := "ур. %d" % lvl + (" · авто" if auto else "")
		var lw := battle.font.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(battle.font, Vector2((size.x - lw) * 0.5, 119), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("7a5a3c"))


## Звёзды итога (рисуются, а не шрифтом)
class Stars extends Control:
	var n := 0
	var mask := -1                 # биты звёзд (Legion.STAR_*): горят именно эти; −1 — первые n
	var of := 3                    # сколько звёзд рисовать (1 — значок у строки условия)

	func _draw() -> void:
		if of == 1:
			_one(size * 0.5, size.y * 0.42, n > 0)
			return
		var r := size.y * 0.42
		for i in 3:
			var c := Vector2(size.x * 0.5 + (i - 1) * r * 2.3, size.y * 0.5 + (0.0 if i == 1 else 4.0))
			_one(c, r * (1.15 if i == 1 else 1.0), (mask & (1 << i)) != 0 if mask >= 0 else i < n)

	func _one(c: Vector2, rr: float, on: bool) -> void:
		var pts := PackedVector2Array()
		for k in 10:
			var a := -PI / 2.0 + k * PI / 5.0
			pts.append(c + Vector2(cos(a), sin(a)) * (rr if k % 2 == 0 else rr * 0.45))
		var shadow := PackedVector2Array()
		for p in pts:
			shadow.append(p + Vector2(0, 3))
		draw_colored_polygon(shadow, Color(0.25, 0.14, 0.05, 0.35))
		draw_colored_polygon(pts, Color("f2c24a") if on else Color(0.78, 0.72, 0.62, 0.7))
		var ol := pts.duplicate()
		ol.append(pts[0])
		draw_polyline(ol, Color("8a5a12") if on else Color(0.55, 0.48, 0.4, 0.8), 2.5, true)


## Кружок волны: пройденная/идущая — золотая, впереди — пустая; волна босса — с короной
class WavePip extends Control:
	var on := false
	var boss := false

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 8.0, Color(0.3, 0.12, 0.06, 0.85))
		draw_circle(c, 6.0, Color("f2c24a") if on else Color(0.55, 0.3, 0.2, 0.9))
		if boss:
			draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -6), c + Vector2(-3, -11), c + Vector2(0, -7), c + Vector2(3, -11), c + Vector2(5, -6)]), Color("f2c24a"))
