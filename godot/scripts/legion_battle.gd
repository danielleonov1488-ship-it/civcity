class_name LegionBattle
extends Node
## Рисованный бой Легиона: ход боя считает LegionSim фиксированным шагом.
## Город на паузе, его 3D-кадр скрыт. Поле, бойцы и эффекты рисуются в CanvasLayer.
##
## Подключение: LegionBattle.attach(game) — один раз после загрузки города (game.gd). Окно «Легион» зовёт
## legion.start_battle(st) / start_pvp_battle(opp) → сигнал legion.battle_requested(setup) → открывается бой.
## Бой сам зовёт legion.apply_result / apply_pvp_result, показывает итог (звёзды, награда, что открылось) и по выходу
## шлёт legion.battle_closed(out) — окно «Легион» открывается снова. Можно открыть и напрямую:
## LegionBattle.open(host, setup, on_done, opts) (host — Game или любой узел; без города — для проверок).
##
## Управление: кнопки умений внизу (или клавиши 1–7), «Авто» — умения жмёт сам отряд (только в пройденных боях
## и боях с городами), скорость ×1/×2/×3, пробел — пауза, Esc — отступить (с вопросом), колёсико — приблизить поле.
## Учебный первый бой (setup.tutorial = "oil"): ×1 без «Авто»; шайка вышла кучей — бой замирает, стрелка на масле.

signal finished(out: Dictionary)          # бой окончен, итог подсчитан (до закрытия экрана итога)

const BattleView = preload("res://scripts/legion_battle_view.gd")
const Kit = preload("res://scripts/ui_kit_a.gd")
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
const PERK_SAY := {"oil": "Кипящее масло!", "testudo": "Черепаха!", "bandage": "Перевязка!", "volley": "Залп!", "horn": "Боевой рог!",
	"eagle": "Знамя орла!", "fire": "Огненные стрелы!"}
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
var battle_view: BattleView
var views := {}                            # id бойца → AnimatedSprite2D
var shots := {}                            # снаряд симуляции → узел 2D

# ход боя
var speed := 1.0
var paused := false
var phase := "intro"                       # intro | fight | ending | result
var acc := 0.0
var intro_t := 0.0
var end_t := 0.0
var slowmo := 1.0
var zoom := 1.0
var _snd_t := {}
var _saved := {}
var _boss_unit: LegionSim.Unit
var _immune_said := false
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
## не сбежится и ещё чуть-чуть.
var _crowds: Array = []
var _summon_warns := 0

# экран
var canvas: CanvasLayer
var ui: Control
var bars: BarsLayer
var fade: ColorRect
var fade_map: TextureRect
var fade_lbl: Label
var boss_panel: Control
var boss_name: Label
var boss_bar: ProgressBar
var boss_pic: TextureRect
var wave_lbl: Label
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
## on_done(out) — по выходу; opts: {"legion": Legion (без города), "speed": 1…3, "auto": bool, "zoom": float}
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
	speed = clampf(float(opts.get("speed", legion.flags.get("battle_speed", 1.0))), 1.0, 3.0)
	zoom = clampf(float(opts.get("zoom", 1.0)), 0.75, 1.25)
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
	if _saved.is_empty():
		return
	get_viewport().disable_3d = bool(_saved.get("disable_3d", false))
	if game != null and is_instance_valid(game):
		game.hud.visible = bool(_saved.get("hud", true))
		if game.rig:
			game.rig.cine = bool(_saved.get("cine", false))
		game.hud.set_speed(float(_saved.get("speed", 1.0)))


# =====================================================================
#   экран: поле и интерфейс
# =====================================================================

func _build_screen() -> void:
	canvas = CanvasLayer.new()
	canvas.layer = LAYER
	add_child(canvas)
	battle_view = BattleView.new()
	battle_view.name = "LegionBattleView"
	battle_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle_view.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(battle_view)
	battle_view.set_zoom(zoom)
	battle_view.gui_input.connect(_field_input)
	views = battle_view.views
	shots = battle_view.shots
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


func _field_input(e: InputEvent) -> void:
	var next := zoom
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			next *= 0.92
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			next /= 0.92
	elif e is InputEventMagnifyGesture and e.factor > 0.0:
		if CameraRig.gesture_once(e, "battle"):
			next /= e.factor
		battle_view.accept_event()
	elif e is InputEventPanGesture:
		if CameraRig.gesture_once(e, "battle"):
			next *= exp(-e.delta.y * 0.08)
		battle_view.accept_event()
	if next != zoom:
		zoom = clampf(next, 0.75, 1.25)
		battle_view.set_zoom(zoom)


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


## Табличка волн, быстрые команды и пауза.
func _top_bar() -> void:
	retreat_btn = Kit.round_button(_icon_tex("eagle"))
	retreat_btn.name = "LegionBattleRetreat"
	retreat_btn.focus_mode = Control.FOCUS_NONE
	retreat_btn.tooltip_text = "Отступить"
	retreat_btn.pressed.connect(_ask_retreat)
	ui.add_child(retreat_btn)
	_pin(retreat_btn, Control.PRESET_TOP_LEFT, Vector2(18, 12), Vector2(94, 94))

	var plate := Kit.image(Kit.ROOT + "panels/ribbon_title.png", Vector2.ZERO)
	ui.add_child(plate)
	_pin(plate, Control.PRESET_CENTER_TOP, Vector2(-268, 12), Vector2(536, 108))
	wave_lbl = _label("", 52, false, Color("681b0c"), font_title)
	wave_lbl.name = "LegionBattleWave"
	wave_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plate.add_child(wave_lbl)
	wave_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 5)
	right.alignment = BoxContainer.ALIGNMENT_END
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(right)
	_pin(right, Control.PRESET_TOP_RIGHT, Vector2(-407, 28), Vector2(290, 40))
	for s: int in [1, 2, 3]:
		var b := _button("×%d" % s, "", func(): _set_speed(float(s)), 50)
		b.toggle_mode = true
		b.tooltip_text = "Скорость боя ×%d" % s
		right.add_child(b)
		speed_btns[s] = b
	auto_btn = _button("Авто", "", _toggle_auto, 80)
	auto_btn.toggle_mode = true
	auto_btn.tooltip_text = "Умения отряд жмёт сам — вовремя и с умом"
	right.add_child(auto_btn)

	pause_btn = Kit.round_button(_icon_tex("pause"))
	pause_btn.name = "LegionBattlePause"
	pause_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.pressed.connect(_toggle_pause)
	ui.add_child(pause_btn)
	_pin(pause_btn, Control.PRESET_TOP_RIGHT, Vector2(-104, 12), Vector2(88, 88))
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
	_pin(p, Control.PRESET_CENTER_TOP, Vector2(-230, 116), Vector2(460, 80))


## Умения внизу: медальоны и кольца перезарядки.
func _perk_bar() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	perk_bar = row
	ui.add_child(perk_bar)


func _fill_perks() -> void:
	for c in perk_bar.get_children():
		perk_bar.remove_child(c)
		c.queue_free()
	perk_btns.clear()
	var ids: Array[String] = []
	for id: String in Legion.perk_ids():
		if sim.perks["ally"].has(id):
			ids.append(id)
	var diameter := 160.0 if ids.size() <= 3 else 112.0
	var medal := Kit.texture(Kit.ROOT + "buttons/round_frame_big.png")
	for i in ids.size():
		var id := ids[i]
		var pb := PerkButton.new()
		pb.name = "BattlePerk_" + id
		pb.battle = self
		pb.key_n = i + 1
		pb.medal = medal
		pb.art = Legion.art_texture("perk", id)
		if pb.art == null:
			pb.art = _icon_tex(String(PERK_ALT.get(id, "swords")))
		pb.custom_minimum_size = Vector2.ONE * diameter
		pb.tooltip_text = "%s (клавиша %d)\n%s" % [Legion.PERKS[id]["name"], i + 1, Legion.PERKS[id]["desc"]]
		pb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		pb.focus_mode = Control.FOCUS_NONE
		pb.pressed.connect(use_perk.bind(id))
		perk_bar.add_child(pb)
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
	banner_lbl = _label("", 29, false, C_INK, font_title)
	banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(banner_lbl)
	banner.modulate.a = 0.0
	ui.add_child(banner)


func say(text: String, dur := 1.6) -> void:
	banner_lbl.text = text
	var sz := banner.get_combined_minimum_size()
	_pin(banner, Control.PRESET_CENTER, Vector2(-sz.x * 0.5, -232), sz)
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
	_clear_world()
	var biome := "forest"
	if pvp:
		var nm := String((s.get("opponent", {}) as Dictionary).get("name", ""))
		biome = PVP_BIOMES[absi(nm.hash()) % PVP_BIOMES.size()]
	else:
		var r := int(stage.get("r", 0))
		biome = String(Legion.regions()[clampi(r, 0, Legion.regions().size() - 1)]["biome"])
	battle_view.set_field(biome)
	battle_view.legion = legion
	battle_view.hero_look = s.get("hero_look", {})
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
	battle_view.prewarm()
	for u in sim.units:
		_view(u)
	_waves_ui()
	_fill_perks()
	_refresh_speed()
	# первые бои: тихая подсказка над умениями (как устроен бой), потом не мешает
	var seen := int(legion.flags.get("battle_hints", 0))
	hint_lbl.visible = (seen < 3 or tut != "") and not sim.perks["ally"].is_empty()
	hint_lbl.modulate.a = 1.0
	_pin(hint_lbl, Control.PRESET_CENTER_BOTTOM, Vector2(-420, -258 if tut != "" else -204), Vector2(840, 30))
	hint_until = INF if tut != "" else 14.0
	if tut != "":
		hint_lbl.text = "Учебный бой. Отряд дерётся сам; ваше — состав и умения в нужный миг."
	elif hint_lbl.visible:
		legion.flags["battle_hints"] = seen + 1
		hint_lbl.text = "Жмите умения, когда они готовы (клавиши 1–7)."
	_handle(sim.take_events())
	phase = "intro"
	intro_t = 0.0
	end_t = 0.0
	slowmo = 1.0
	acc = 0.0
	paused = false
	pause_lbl.visible = false
	retreat_btn.disabled = false
	_refresh_speed()
	if bool(stage.get("boss", false)):
		say("Босс: " + String(stage.get("name", "")), 2.6)
	_play("horn", -6.0)
	_play("cry", -15.0)
	var tw := create_tween()
	fade.modulate.a = 1.0
	tw.tween_interval(0.25)
	tw.tween_property(fade, "modulate:a", 0.0, 0.6)


## Занавес перед боем: карта провинции и «Легион выступает: …»
func _loading(s: Dictionary) -> void:
	fade.modulate.a = 1.0
	var st: Dictionary = s.get("stage", {})
	if s.has("event"):
		fade_map.texture = null
		fade_lbl.text = "Легион выступает: %s" % String((s["event"] as Dictionary).get("title", ""))
	elif String(s.get("kind", "")) == "pvp":
		fade_map.texture = null
		fade_lbl.text = "Легион выступает: город «%s»" % String((s.get("opponent", {}) as Dictionary).get("name", "?"))
	else:
		var r := clampi(int(st.get("r", 0)), 0, Legion.regions().size() - 1)
		fade_map.texture = Legion.art_texture("map", String(Legion.regions()[r]["id"]))
		var nm := String(st.get("theme", "")) if String(st.get("theme", "")) != "" else String(st.get("name", ""))
		fade_lbl.text = "%s — %s" % [String(st.get("title", "")), nm] if nm != "" else String(st.get("title", ""))


func _clear_world() -> void:
	battle_view.clear()
	bars.floats.clear()
	_crowds.clear()
	_summon_warns = 0
	_immune_said = false
	_banner_t = 0.0
	banner.modulate.a = 0.0
	_boss_unit = null
	boss_pic.texture = null
	if sim != null:
		sim.dispose()
		sim = null
	_close_modal()


func _view(u: LegionSim.Unit) -> BattleView.Fighter:
	if u.boss:
		_boss_unit = u
	return battle_view.add_unit(u)


func _waves_ui() -> void:
	var total := 1 if bool(setup.get("enemy_formation", false)) else maxi(1, sim.waves.size())
	wave_lbl.text = I18n.t("Волна %d/%d") % [clampi(sim.wave_idx + 1, 1, total), total]


# =====================================================================
#   ход боя
# =====================================================================


func _process(dt: float) -> void:
	if sim == null:
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
	_update_crowds(gdt)
	battle_view.tick(sim, gdt, dt, acc, phase == "intro" or phase == "fight")
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
				var fresh: Array = []
				for u in sim.units:
					if u.wave == n - 1 and u.side == "enemy":
						_view(u)
						fresh.append(u)
				if pack:
					_crowd(fresh, "Толпа! Масло накроет всех разом")
				_waves_ui()
			"warn" when String(e.get("kind", "summon")) != "summon":
				_warn2(e)
			"warn":
				_summon_warns += 1
				say("Атаман созывает шайку! Масло — когда сбегутся" if _summon_warns == 1 else "Атаман снова созывает шайку!", 2.4)
				_play("horn", -4.0, 0.72)
				battle_view.ring(_view(e["unit"]).position, 88.0, BattleView.ALERT)
			"summon":
				_summon(e)
			"attack":
				var u: LegionSim.Unit = e["unit"]
				_view(u).attack()
				if u.key == "catapult" or u.key == "ballista":
					_play("creak", -12.0, randf_range(0.9, 1.1))
			"shoot":
				var s: LegionSim.Shot = e["shot"]
				battle_view.shoot(s)
				if s.kind == "arrow" or s.kind == "bolt":
					_play("whoosh", -16.0, randf_range(1.1, 1.4))
			"hit":
				_hit(e)
			"death":
				_play("fall", -10.0, randf_range(0.85, 1.05))
			"revive":
				var u: LegionSim.Unit = e["unit"]
				_view(u).revive()
				say("%s поднимается — легион не дрогнет!" % u.name, 1.8)
			"heal":
				var f := _view(e["unit"])
				battle_view.burst("fx_heal", f.chest(), 1.05)
				bars.float_text(battle_view.screen(f.head()), "+%d" % int(e["amount"]), "heal")
				var src: LegionSim.Unit = e.get("from")
				if src != null and src.alive:
					var priest := _view(src)
					priest.attack()
					battle_view.ring(priest.position, 55.0, BattleView.GOLD)
			"slam", "boom":
				var pos := BattleView.point(float(e["x"]), float(e["z"]))
				battle_view.ring(pos, float(e["r"]) * 49.0, BattleView.GOLD)
				battle_view.burst("fx_hit", pos - Vector2(0, 46), 1.25)
				_play("boom" if e["type"] == "boom" else "fall", -8.0, 0.7)
			"charge":
				var u: LegionSim.Unit = e["unit"]
				battle_view.ring(_view(u).position, 67.0, BattleView.ALERT)
				say(String(u.name) + " бросается в атаку!", 1.2)
			"perk":
				_perk_fx(e)
			"avalanche", "chariot", "cry", "interrupt", "ward", "storm", "immune":
				_v2_event(e)


func _hit(e: Dictionary) -> void:
	var u: LegionSim.Unit = e["unit"]
	var f := _view(u)
	var crit := bool(e["crit"])
	f.hurt()
	battle_view.burst("fx_hit", f.chest(), 1.02 if crit else 0.78)
	bars.float_text(battle_view.screen(f.head()), str(int(e["dmg"])) + ("!" if crit else ""),
		"crit" if crit else ("hurt" if u.side == "ally" else "dmg"))
	var src: LegionSim.Unit = e.get("from")
	if src != null:
		var metal := src.shot == "" and "beast" not in u.tags and "beast" not in src.tags
		_play("clash" if metal else "thud", -9.0 if crit else -14.0, randf_range(0.9, 1.15))


func _summon(e: Dictionary) -> void:
	var fresh: Array = []
	var raised := String(e.get("kind", "")) == "raise"
	for u: LegionSim.Unit in e["units"]:
		var f := _view(u)
		fresh.append(u)
		battle_view.ring(f.position, 50.0, Color("c9ecff") if raised else BattleView.ALERT)
	if raised:
		say("Павшие встают! Жгите их маслом — сожжённые не поднимутся", 2.4)
	elif bool(e.get("rear", false)):
		say("Засада с тыла!", 1.8)
	else:
		_crowd(fresh)


## Босс готовит приём: надпись, рог, круг под ним и опасный ряд.
const WARN2 := {"raise": "%s поднимает павших!", "avalanche": "Лавина! Сомкните «Черепаху»", "warcry": "%s трубит боевой клич — собьёте ударом машины или умением!",
	"ambush": "%s: засада заходит с тыла!", "chariot": "Колесницы! Копейщики — в их ряд, или «Черепаха»", "ward": "%s перестраивает войско", "storm": "%s поднимает песчаную бурю!"}


func _warn2(e: Dictionary) -> void:
	var u: LegionSim.Unit = e["unit"]
	var k := String(e.get("kind", ""))
	var txt := String(WARN2.get(k, "%s готовит удар!"))
	say(txt % u.name if txt.contains("%s") else txt, 2.2)
	_play("horn", -5.0, 0.8)
	battle_view.ring(_view(u).position, 86.0, BattleView.ALERT)
	if k == "avalanche" or k == "chariot":
		battle_view.lane(float(e.get("z", 0.0)), BattleView.ALERT, float(u.abil.get("warn", 1.4)))


func _v2_event(e: Dictionary) -> void:
	match String(e["type"]):
		"avalanche":
			battle_view.lane(float(e["z"]), Color("e7f2ff"), 0.8, 32.0)
			_play("boom", -6.0, 0.6)
		"chariot":
			battle_view.lane(float(e["z"]), Color("c6986a"), 1.2, 30.0)
			say("Копейщики остановили колесницы!" if bool(e["stopped"]) else "Колесницы прошли по ряду!", 1.6)
		"cry":
			say("Боевой клич! Враги бьют сильнее", 1.8)
			_play("horn", -3.0, 0.6)
		"interrupt":
			say("Клич сорван!", 1.6)
			battle_view.burst("fx_hit", _view(e["unit"]).chest(), 1.1, BattleView.GOLD)
		"ward":
			say("Щиты от стрел и камней — бейте мечами!" if String(e["kind"]) == "ranged" else "Щиты от мечей — бейте стрелами!", 2.0)
		"storm":
			say("Песчаная буря: стрелы бьют слабее", 1.8)
			for z in [-2.0, 0.0, 2.0]:
				battle_view.lane(float(z), Color("e1ab71"), float(e.get("dur", 7.0)), 28.0)
		"immune":
			var u: LegionSim.Unit = e["unit"]
			bars.float_text(battle_view.screen(_view(u).head()), I18n.t("неуязвим"), "hurt")
			if not _immune_said:
				_immune_said = true
				say("%s неуязвим, пока живы его пращники" % u.name, 2.2)


func _perk_fx(e: Dictionary) -> void:
	var id := String(e["id"])
	var side := String(e["side"])
	var ours := side == "ally"
	say(String(PERK_SAY.get(id, "")) if ours else "Соперник: " + String(Legion.PERKS[id]["name"]), 1.3)
	if perk_btns.has(id) and ours:
		(perk_btns[id] as PerkButton).pop = 1.0
	match id:
		"oil":
			var pos := BattleView.point(float(e.get("x", 0.0)), float(e.get("z", 0.0)))
			battle_view.ring(pos, 118.0, Color("ff8e38"), 0.95)
			battle_view.burst("fx_hit", pos - Vector2(0, 73), 1.6, Color("ff9e49"))
			_play("pot", -8.0, 0.8)
			_play("oil", -10.0)
		"volley", "fire":
			var tint := Color("ff9c4d") if id == "fire" else Color.WHITE
			var foes := sim.alive_of("enemy" if ours else "ally")
			for u in foes:
				var to := _view(u).chest()
				battle_view.volley(to + Vector2(-320.0 if ours else 320.0, -155.0), to, tint)
			_play("volley", -9.0, randf_range(0.95, 1.05))
			if id == "fire":
				_play("oil", -16.0, 1.2)
		"testudo", "horn", "eagle":
			for u in sim.alive_of(side):
				battle_view.ring(_view(u).position, 66.0, BattleView.GOLD, 0.9)
			_play("pot" if id == "testudo" else "horn", -8.0)


func _begin_end() -> void:
	phase = "ending"
	end_t = 0.0
	tut_freeze = false                       # отступили, пока бой стоял на масле
	retreat_btn.disabled = true
	var res := sim.result
	if setup.has("event"):
		out = LegionEvents.apply(legion, setup, res)   # события недели (docs/ONLINE_V2.md §3): своя награда, не бои с городами
	elif pvp:
		out = legion.apply_pvp_result(setup, res)
	else:
		out = legion.apply_result(setup, res)
	out["retreat"] = bool(res.get("retreat", false))
	finished.emit(out)
	var win := bool(out.get("win", false))
	if not bool(out["retreat"]):
		say("Победа!" if win else "Отряд отступает…", 2.0)
	_play("win" if win else "fall", -6.0 if win else -10.0, 1.0)


## Круг идёт за толпой до её выхода на поле и ещё 2,5 с.
func _crowd(units: Array, text := "") -> void:
	if units.size() < 2:
		return
	_crowds.append({"units": units, "t": 0.0, "say": text, "position": Vector2.ZERO})
	_update_crowds(0.0)


func _update_crowds(gdt: float) -> void:
	for i in range(_crowds.size() - 1, -1, -1):
		var c: Dictionary = _crowds[i]
		var n := 0
		var at := Vector2.ZERO
		var entering := false
		for u: LegionSim.Unit in c["units"]:
			if u.alive:
				n += 1
				at += BattleView.point(u.x, u.z)
				entering = entering or u.entering
		if n < 2 or float(c["t"]) > 2.5 or phase == "ending" or phase == "result":
			_crowds.remove_at(i)
			continue
		if not entering:
			if float(c["t"]) == 0.0 and gdt > 0.0 and String(c["say"]) != "":
				say(String(c["say"]), 2.4)
			c["t"] = float(c["t"]) + gdt
		c["position"] = at / n
	battle_view.ground.crowds = _crowds


# =====================================================================
#   интерфейс боя и управление
# =====================================================================


func _update_ui() -> void:
	for id in perk_btns:
		var pb: PerkButton = perk_btns[id]
		pb.charge = sim.perk_charge(id)
		pb.left = sim.perk_ready(id)
		pb.active = phase == "fight" or phase == "intro"
		pb.disabled = not pb.active or (tut_freeze and id != "oil")
		pb.queue_redraw()
	var boss := _boss_unit
	if boss != null and boss.alive:
		boss_panel.visible = true
		boss_name.text = boss.name
		boss_bar.value = boss.hp_frac()
		if boss_pic.get_meta("unit_id", -1) != boss.id or boss_pic.texture == null:
			boss_pic.texture = BattleView.portrait(boss)
			boss_pic.set_meta("unit_id", boss.id)
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
		(pause_btn.get_node("ic") as TextureRect).texture = _icon_tex("play" if paused else "pause")
		pause_btn.tooltip_text = "Продолжить бой" if paused else "Пауза (пробел)"


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
	if sim == null:
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
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7:
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
	var p := Kit.card(Vector2(w, 0))
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
	var first_lesson := bool(setup.get("fort_guide_first", false))
	var p := _modal_panel(610)
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
	if setup.has("event"):
		var evw: Dictionary = setup["event"]
		where = String(evw.get("title", "")) + ((" — " + String(evw["sub"])) if String(evw.get("sub", "")) != "" else "")
	elif pvp:
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
	if legion.v3() and out.has("camp_chest"):
		var kind := String(out["camp_chest"])
		var chest_text := I18n.t("Сундуки заполнены — откройте один в форте.") if kind == "full" else I18n.t("В форте ждёт: %s") % I18n.t(String(Legion.CHEST_NAMES.get(kind, kind)))
		var chest_label := _label(chest_text, 18, true, C_GOOD)
		chest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(chest_label)
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
	if String(out.get("note", "")) != "":
		var nl := _label(String(out["note"]), 17, true, Color("6b4a12"))
		nl.name = "EventNote"
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.custom_minimum_size = Vector2(480, 0)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nl)
	if pvp and not setup.has("event"):
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
	if not win and not first_lesson:
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
	if win and not pvp and not first_lesson and not nx.is_empty() and not bool(out.get("boss_beaten", false)):
		var why := legion.can_fight(nx)
		var nb := _button("Дальше: " + (String(nx["name"]) if bool(nx.get("boss", false)) else "бой %d" % (int(nx["s"]) + 1)), "swords", func(): _again(nx), 0)
		_ration_button(nb, nx)
		nb.disabled = why != ""
		nb.tooltip_text = why
		Kit.style_button(nb, "green")
		bh.add_child(nb)
	if not pvp and not first_lesson:
		var st := legion.stage_info(int(stage["cycle"]), int(stage["r"]), int(stage["s"]))
		var why2 := legion.can_fight(st)
		var ab := _button("Ещё раз", "redo", func(): _again(st), 0)
		_ration_button(ab, st)
		ab.disabled = why2 != ""
		ab.tooltip_text = why2
		Kit.style_button(ab)
		bh.add_child(ab)
	var back := _button("В лагерь" if not pvp or setup.has("event") else "К соперникам", "legion", _close, 0)
	Kit.style_button(back)
	back.name = "LegionBattleReturn"
	bh.add_child(back)


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
	if not legion.flags.has("stars_tip") and not bool(setup.get("fort_guide_first", false)):
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


## Отряд после боя: портреты B1, павшие — серые
func _squad_row() -> Control:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 6)
	h.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for u in sim.units:
		if u.side != "ally":
			continue
		var tr := TextureRect.new()
		tr.texture = BattleView.portrait(u)
		tr.custom_minimum_size = Vector2(54, 54)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.tooltip_text = "%s, ур. %d%s" % [u.name, u.level, "" if u.alive else " — пал в бою"]
		if not u.alive:
			tr.modulate = Color(0.42, 0.38, 0.36, 0.75)
		h.add_child(tr)
	return h


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
	var s := legion.prepare_battle(st)
	if s.is_empty():
		return
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
	_clear_world()
	_leave()
	if current == self:
		current = null
	queue_free()


# =====================================================================
#   звук: удары, щиты, падения, скрип машин, рог (рог — синтез)
#   hf_* — звуки из Higgsfield (Mirelo): звон мечей, залп, удар камня, шипение масла, клич
# =====================================================================

const SOUNDS := {"clash": ["hf_clash1", "hf_clash2", "hf_clash3", "knifeSlice"], "thud": ["dropLeather", "chop"], "fall": ["dropLeather"],
	"pot": ["metalPot1", "metalPot2", "metalPot3"], "creak": ["creak1", "creak3"], "whoosh": ["cloth1", "drawKnife1", "drawKnife2"],
	"boom": ["hf_boom"], "win": ["handleCoins"], "volley": ["hf_volley"], "oil": ["hf_oil"], "cry": ["hf_cry"]}
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
#   полоски здоровья и числа, кнопки умений, звёзды
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
		var scale_ui: float = battle.battle_view.world.scale.x
		for f: BattleView.Fighter in battle.views.values():
			var u := f.unit
			if not u.alive:
				continue
			var p := battle.battle_view.screen(f.head())
			var w := 74.0 * scale_ui
			var h := 5.5 * scale_ui
			var left := p - Vector2(w * 0.5, 0)
			var right := left + Vector2(w, 0)
			draw_line(left, right, Color("593413"), h + 7.0, true)
			draw_line(left, right, Color("e1a841"), h + 4.0, true)
			draw_line(left, right, Color("512412"), h + 1.8, true)
			var hp := u.hp_frac()
			var col := Color("78da25") if u.side == "ally" else Color("ea3a2c")
			draw_line(left, left.lerp(right, f.health), Color("cd8f52"), h, true)
			draw_line(left, left.lerp(right, hp), col, h, true)
			draw_line(left - Vector2(0, 1), left.lerp(right, hp) - Vector2(0, 1), Color(col.lightened(0.4), 0.9), 1.5, true)
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


## Круглая кнопка, время перезарядки видно на кольце.
class PerkButton extends Button:
	var battle: LegionBattle
	var key_n := 1
	var art: Texture2D
	var medal: Texture2D
	var charge := 0.0
	var left := 0.0
	var active := true
	var pop := 0.0

	func _ready() -> void:
		for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())

	func _has_point(p: Vector2) -> bool:
		return p.distance_squared_to(size * 0.5) <= pow(minf(size.x, size.y) * 0.5, 2)

	func _process(dt: float) -> void:
		if pop > 0.0:
			pop = maxf(0.0, pop - dt * 3.0)

	func _draw() -> void:
		var c := size * 0.5
		var ready := charge >= 1.0 and not disabled
		var d := minf(size.x, size.y) * (0.94 + 0.05 * sin(pop * PI))
		var r := Rect2(c - Vector2.ONE * d * 0.5, Vector2.ONE * d)
		var gleam := Color(1.08, 1.06, 1.0) if is_hovered() and ready else Color.WHITE
		draw_texture_rect(medal, r, false, gleam)
		if art != null:
			draw_texture_rect(art, r.grow(-d * 0.19), false)
		var radius := d * 0.39
		if not ready:
			draw_circle(c, radius, Color(0.13, 0.046, 0.024, 0.62), true, -1.0, true)
		var fill := Color("fff0a0") if ready else Color("f9bd54")
		if charge > 0.0:
			draw_arc(c, radius, -PI / 2, -PI / 2 + TAU * charge, 48, fill, 3.0, true)
		if left > 0.0 and active:
			_number(c, str(ceili(left)), roundi(d * 0.26))
		var key_pos := c + Vector2(-0.33, -0.32) * d
		draw_circle(key_pos, 11.0, Color("633213"), true, -1.0, true)
		_number(key_pos, str(key_n), 16)

	func _number(c: Vector2, txt: String, pixels: int) -> void:
		var f: Font = battle.font_bold
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
		var pos := c + Vector2(-w * 0.5, (f.get_ascent(pixels) - f.get_descent(pixels)) * 0.5)
		draw_string_outline(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, 4, Color("351505"))
		draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, Color("fff4dc"))


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
func _ration_button(button: Button, st: Dictionary) -> void:
	if not legion.v3():
		return
	button.text += " · %.1f" % legion.ration_cost(st)
	button.icon = _icon_tex("bread")
	button.add_theme_color_override("font_disabled_color", C_BAD if legion.rations < legion.ration_cost(st) else C_SOFT)
