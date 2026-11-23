class_name LegionBattle
extends Node

const CityWarmup = preload("res://scripts/city_warmup.gd")
const Perf14 = preload("res://scripts/perf14_timers.gd")
const Perf13 = preload("res://scripts/perf13_timers.gd")
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

const Look = preload("res://scripts/legion_look.gd")
const BattleView = preload("res://scripts/legion_battle_view.gd")
const BattleSound = preload("res://scripts/legion_battle_sound.gd")
const Kit = preload("res://scripts/ui_kit_a.gd")
const FortPerson = preload("res://scripts/fort_person.gd")
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
var battle_sound: BattleSound
var _city_sound: Sound
var views := {}                            # id бойца → AnimatedSprite2D
var shots := {}                            # снаряд симуляции → узел 2D

# ход боя
var speed := 1.0
var paused := false
var phase := "loading"                     # loading | intro | fight | ending | result_loading | result
var acc := 0.0
var intro_t := 0.0
var end_t := 0.0
var slowmo := 1.0
var zoom := 1.0
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
var top_block: Panel
var speed_controls: HBoxContainer
var ally_health: TeamHealth
var enemy_health: TeamHealth
var ally_name: Label
var enemy_name: Label
var enemy_medal: TextureRect
var battle_clock: Label
var wave_chip: Panel
var wave_lbl: Label
var time_left := LegionSim.TIME_LIMIT
var _score_step := -1
var _clock_second := -1
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
	var started := Perf14.begin()
	_fonts()
	canvas = CanvasLayer.new()
	canvas.layer = LAYER
	add_child(canvas)
	_build_fade()
	_loading(setup)
	Perf14.end(Perf14.BATTLE_OPEN, started)
	# сначала экран с картой провинции, потом (пока он виден) собирается поле — без «замёрзшего» города
	await get_tree().process_frame
	await get_tree().process_frame
	if is_queued_for_deletion():
		return
	_enter()
	await get_tree().process_frame
	battle_sound = BattleSound.new()
	battle_sound.load_on_ready = false
	add_child(battle_sound)
	await battle_sound.prepare_pack()
	if is_queued_for_deletion():
		return
	await _build_screen()
	if not is_queued_for_deletion():
		_start(setup)


## Город уходит в тень: интерфейс спрятан, камера города не слушает клавиш, 3D города не рисуется
func _enter() -> void:
	var vp := get_viewport()
	_saved = {"disable_3d": vp.disable_3d}
	if game != null:
		_city_sound = game.sound
		if is_instance_valid(_city_sound):
			_city_sound.duck_for_battle(get_instance_id(), true)
		_saved["speed"] = game.speed
		_saved["hud"] = game.hud.visible
		game.legion_cover(self, true)
		_saved["cine"] = game.rig.cine if game.rig else false
		if game.tool != "":
			game.set_tool("")
		game.hud.visible = false
		if game.rig:
			game.rig.cine = true
	vp.disable_3d = true


func _leave() -> void:
	_release_music()
	if _saved.is_empty():
		return
	get_viewport().disable_3d = bool(_saved.get("disable_3d", false))
	if game != null and is_instance_valid(game):
		game.hud.visible = bool(_saved.get("hud", true))
		game.legion_cover(self, false)
		if game.rig:
			game.rig.cine = bool(_saved.get("cine", false))
		game.hud.set_speed(float(_saved.get("speed", 1.0)))


func _exit_tree() -> void:
	_release_music()
	if is_instance_valid(game):
		game.legion_cover(self, false)


func _release_music() -> void:
	if is_instance_valid(_city_sound):
		_city_sound.duck_for_battle(get_instance_id(), false)
	_city_sound = null


# =====================================================================
#   экран: поле и интерфейс
# =====================================================================

func _build_screen() -> void:
	var started := Perf14.begin()
	battle_view = BattleView.new()
	battle_view.name = "LegionBattleView"
	battle_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle_view.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(battle_view)
	battle_view.legacy_layout = bool(opts.get("legacy_layout", false))
	battle_view.set_zoom(zoom)
	battle_view.field_sound.connect(_field_sound)
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
	Perf14.end(Perf14.BATTLE_UI, started)
	await get_tree().process_frame
	started = Perf14.begin()
	_top_bar()
	_boss_box()
	Perf14.end(Perf14.BATTLE_UI, started)
	await get_tree().process_frame
	started = Perf14.begin()
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
	Perf14.end(Perf14.BATTLE_UI, started)


func _build_fade() -> void:
	# Занавес виден первым, пока собираются поле и интерфейс.
	fade = ColorRect.new()
	fade.z_index = 20
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


## Общий счёт боя, быстрые команды и пауза.
func _top_bar() -> void:
	retreat_btn = Kit.round_button(_icon_tex("eagle"))
	retreat_btn.name = "LegionBattleRetreat"
	retreat_btn.focus_mode = Control.FOCUS_NONE
	retreat_btn.tooltip_text = "Отступить"
	retreat_btn.pressed.connect(_ask_retreat)
	ui.add_child(retreat_btn)
	_pin(retreat_btn, Control.PRESET_TOP_LEFT, Vector2(18, 12), Vector2(94, 94))

	var right := HBoxContainer.new()
	right.name = "LegionBattleSpeed"
	right.add_theme_constant_override("separation", 5)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speed_controls = right
	ui.add_child(right)
	for s: int in [1, 2, 3]:
		var b := _button("×%d" % s, "", func(): _set_speed(float(s)), 46)
		b.toggle_mode = true
		b.tooltip_text = "Скорость боя ×%d" % s
		right.add_child(b)
		speed_btns[s] = b
	auto_btn = _button("Авто", "", _toggle_auto, 72)
	auto_btn.toggle_mode = true
	auto_btn.tooltip_text = "Умения отряд жмёт сам — вовремя и с умом"
	right.add_child(auto_btn)

	pause_btn = Kit.round_button(_icon_tex("pause"))
	pause_btn.name = "LegionBattlePause"
	pause_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.pressed.connect(_toggle_pause)
	ui.add_child(pause_btn)
	pause_btn.custom_minimum_size = Vector2(72, 72)
	_pin(pause_btn, Control.PRESET_TOP_RIGHT, Vector2(-88, 12), Vector2(72, 72))
	_score_box()
	ui.resized.connect(_layout_top)
	right.minimum_size_changed.connect(_layout_top)
	_layout_top()
	_refresh_speed()


func _layout_top() -> void:
	var buttons_width := speed_controls.get_combined_minimum_size().x
	_pin(speed_controls, Control.PRESET_TOP_RIGHT, Vector2(-98.0 - buttons_width, 28), Vector2(buttons_width, 40))
	var width := minf(ui.size.x * 0.49, ui.size.x - 2.0 * (110.0 + buttons_width))
	width = maxf(310.0, width)
	var top := 8.0 if width * 0.5 + 110.0 + buttons_width <= ui.size.x * 0.5 else 112.0
	_pin(top_block, Control.PRESET_CENTER_TOP, Vector2(-width * 0.5, top), Vector2(width, 106))
	if _banner_t > 0.0:
		_place_banner()


func _score_box() -> void:
	top_block = Panel.new()
	top_block.name = "LegionBattleScore"
	top_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_block.add_theme_stylebox_override("panel", Kit.box("panels/card_frame", 67, 0, 112))
	ui.add_child(top_block)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 7)
	top_block.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	row.offset_left = 15.0
	row.offset_right = -15.0
	row.offset_top = 9.0
	row.offset_bottom = 68.0
	_score_medal(row, _icon_tex("eagle"), 52)
	ally_health = TeamHealth.new()
	ally_health.name = "AllyTeamHealth"
	ally_name = _score_side(row, ally_health)
	_score_medal(row, _icon_tex("swords"), 58)
	enemy_health = TeamHealth.new()
	enemy_health.name = "EnemyTeamHealth"
	enemy_health.enemy = true
	enemy_name = _score_side(row, enemy_health)
	enemy_medal = _score_medal(row, null, 52)

	battle_clock = _label("", 26, true)
	battle_clock.name = "LegionBattleTimer"
	battle_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_block.add_child(battle_clock)
	_pin(battle_clock, Control.PRESET_CENTER_TOP, Vector2(-42, 70), Vector2(84, 31))

	wave_chip = Panel.new()
	wave_chip.name = "LegionBattleWaveChip"
	wave_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_chip.add_theme_stylebox_override("panel", Kit.box("panels/panel_inset", 30, 0, 26))
	wave_chip.hide()
	top_block.add_child(wave_chip)
	_pin(wave_chip, Control.PRESET_CENTER_TOP, Vector2(44, 73), Vector2(105, 25))
	wave_lbl = _label("", 16, true)
	wave_lbl.name = "LegionBattleWave"
	wave_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wave_chip.add_child(wave_lbl)
	wave_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _score_medal(row: HBoxContainer, icon: Texture2D, side: float) -> TextureRect:
	var rim := Kit.image(Kit.ROOT + "panels/slot_round.png", Vector2.ONE * side)
	rim.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(rim)
	var pic := Kit.image(icon, Vector2.ZERO)
	rim.add_child(pic)
	_pin(pic, Control.PRESET_CENTER, Vector2.ONE * -side * 0.35, Vector2.ONE * side * 0.70)
	return pic


func _score_side(row: HBoxContainer, health: TeamHealth) -> Label:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 1)
	row.add_child(column)
	health.custom_minimum_size = Vector2(0, 30)
	health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(health)
	health.caption = _label("", 18, true, C_CREAM)
	health.caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health.caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	health.caption.clip_text = true
	health.caption.add_theme_color_override("font_outline_color", Color("361b0d"))
	health.caption.add_theme_constant_override("outline_size", 4)
	health.add_child(health.caption)
	health.caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var side_name := _label("", 18, true)
	side_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(side_name)
	return side_name


## Компактная полоса босса под общим счётом.
func _boss_box() -> void:
	var p := PanelContainer.new()
	p.name = "LegionBattleBoss"
	p.add_theme_stylebox_override("panel", Kit.box("panels/panel_inset", 32, 6, 42))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 7)
	p.add_child(h)
	boss_pic = Kit.image(null, Vector2(30, 30))
	h.add_child(boss_pic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	boss_name = _label("", 16, false, C_INK, font_title)
	boss_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(boss_name)
	boss_bar = ProgressBar.new()
	boss_bar.show_percentage = false
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_bar.custom_minimum_size = Vector2(0, 9)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.25, 0.14, 0.08, 0.85)
	bg.set_corner_radius_all(4)
	bg.border_color = Color("a8740f")
	bg.set_border_width_all(2)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color("c0392b")
	fg.set_corner_radius_all(4)
	fg.border_color = Color(1, 0.6, 0.5, 0.35)
	fg.border_width_top = 2
	boss_bar.add_theme_stylebox_override("background", bg)
	boss_bar.add_theme_stylebox_override("fill", fg)
	boss_bar.max_value = 1.0
	boss_bar.step = 0.0
	v.add_child(boss_bar)
	boss_panel = p
	p.visible = false
	top_block.add_child(p)
	_pin(p, Control.PRESET_CENTER_BOTTOM, Vector2(-132, 5), Vector2(264, 42))


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
	_place_banner()
	_banner_t = dur
	_banner_dur = dur


func _place_banner() -> void:
	var sz := banner.get_combined_minimum_size()
	# Оставляем место под босса, даже если он ещё не вышел.
	var y := maxf(-232.0, boss_panel.get_global_rect().end.y + 12.0 - ui.size.y * 0.5)
	_pin(banner, Control.PRESET_CENTER, Vector2(-sz.x * 0.5, y), sz)


# =====================================================================
#   бой: мир, бойцы
# =====================================================================

func _start(s: Dictionary) -> void:
	phase = "loading"
	var started := Perf14.begin()
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
	var tree := get_tree()
	var paths := BattleView.opening_art(biome)
	Perf14.end(Perf14.BATTLE_OPEN, started)
	var art := await CityWarmup.fetch(tree, paths)
	if phase == "closing" or is_queued_for_deletion():
		return
	started = Perf14.begin()
	battle_view.set_field(biome)
	Perf14.end(Perf14.BATTLE_FIELD, started)
	await tree.process_frame
	if phase == "closing" or is_queued_for_deletion():
		return
	started = Perf14.begin()
	battle_sound.reset(biome)
	battle_view.pvp = pvp
	battle_view.legion = legion
	battle_view.hero_look = s.get("hero_look", {})
	battle_view.enemy_hero_look = s.get("enemy_hero_look", {})
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
	Perf14.end(Perf14.BATTLE_OPEN, started)
	await battle_view.prewarm(s.get("waves", []))
	if phase == "closing" or is_queued_for_deletion():
		return
	started = Perf14.begin()
	art.clear()
	var deadline := Time.get_ticks_usec() + 5000
	for u in sim.units:
		_view(u)
		if Time.get_ticks_usec() >= deadline:
			Perf14.end(Perf14.BATTLE_OPEN, started)
			await tree.process_frame
			if phase == "closing" or is_queued_for_deletion():
				return
			started = Perf14.begin()
			deadline = Time.get_ticks_usec() + 5000
	_score_names()
	ally_health.initialized = false
	enemy_health.initialized = false
	_clock_second = -1
	_score_step = -1
	battle_clock.visible = tut == "" and not bool(s.get("fort_guide_first", false))
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
	_update_ui(0.0)
	if bool(stage.get("boss", false)):
		say("Босс: " + String(stage.get("name", "")), 2.6)
	var tw := create_tween()
	fade.modulate.a = 1.0
	tw.tween_interval(0.25)
	tw.tween_property(fade, "modulate:a", 0.0, 0.6)


## Занавес перед боем: карта провинции и «Легион выступает: …»
var _opening_map_request := 0


func _loading(s: Dictionary) -> void:
	_opening_map_request += 1
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
		var region := String(Legion.regions()[r]["id"])
		_load_opening_map(region)
		var nm := String(st.get("theme", "")) if String(st.get("theme", "")) != "" else String(st.get("name", ""))
		fade_lbl.text = "%s — %s" % [String(st.get("title", "")), nm] if nm != "" else String(st.get("title", ""))


func _load_opening_map(region: String) -> void:
	var request := _opening_map_request
	var path := String(Legion.art("map", region)["file"])
	if not ResourceLoader.exists(path):
		path = path.get_basename() + ".jpg"
	var art := await CityWarmup.fetch(get_tree(), {path: true})
	if is_inside_tree() and not is_queued_for_deletion() and request == _opening_map_request:
		fade_map.texture = art.get(path) as Texture2D


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
	var fresh := not views.has(u.id)
	var fighter := battle_view.add_unit(u)
	if fresh and u.alive and BattleSound.is_horse(u):
		battle_sound.play("horse_whinny", battle_view.sound_pan(fighter.position))
	return fighter


func _score_names() -> void:
	var city_name := String(game.city.name).strip_edges() if game != null else ""
	ally_name.text = I18n.t("Вы") if city_name.is_empty() else city_name
	var title := ""
	if pvp:
		var rival: Dictionary = setup.get("opponent", {})
		title = String(rival.get("name", "")).strip_edges()
	elif setup.has("event"):
		title = String((setup["event"] as Dictionary).get("title", ""))
	else:
		title = String(stage.get("theme", ""))
		if title.is_empty():
			title = String(stage.get("name", ""))
		title = I18n.t(title)
	enemy_name.text = I18n.t("Соперник") if title.is_empty() else title


func _waves_ui() -> void:
	var total := 1 if bool(setup.get("enemy_formation", false)) else maxi(1, sim.waves.size())
	wave_chip.visible = total > 1
	wave_lbl.text = I18n.t("Волна %d/%d") % [clampi(sim.wave_idx + 1, 1, total), total]
	var lead: LegionSim.Unit
	_boss_unit = null
	for u in sim.units:
		if u.side == "enemy" and u.wave == sim.wave_idx:
			if lead == null or u.boss:
				lead = u
			if u.boss:
				_boss_unit = u
				break
	enemy_medal.texture = BattleView.portrait(lead) if lead != null else _icon_tex("helmet")
	enemy_health.initialized = false


func _update_score(dt: float) -> void:
	var started := Perf13.begin()
	_update_score_profiled(dt)
	Perf13.end(Perf13.SCORE, started)


func _update_score_profiled(dt: float) -> void:
	if _score_step != sim.steps or dt == 0.0:
		_score_step = sim.steps
		var ally_hp := 0.0
		var ally_max := 0.0
		var enemy_hp := 0.0
		var enemy_max := 0.0
		for u in sim.units:
			if u.side == "ally":
				ally_hp += u.hp
				ally_max += u.max_hp
			elif u.wave == sim.wave_idx:
				enemy_hp += u.hp
				enemy_max += u.max_hp
		ally_health.update_health(ally_hp, ally_max, dt)
		enemy_health.update_health(enemy_hp, enemy_max, dt)
	else:
		ally_health.update_health(ally_health.hp, ally_health.max_hp, dt)
		enemy_health.update_health(enemy_health.hp, enemy_health.max_hp, dt)

	time_left = maxf(0.0, LegionSim.TIME_LIMIT - sim.t)
	var seconds := ceili(time_left - 0.00001)
	if seconds != _clock_second:
		_clock_second = seconds
		battle_clock.text = "%02d:%02d" % [seconds / 60, seconds % 60]
		battle_clock.add_theme_color_override("font_color", Color("a1261c") if seconds <= 30 else C_INK)


func _score_floor() -> float:
	return (boss_panel if boss_panel.visible else top_block).get_global_rect().end.y


# =====================================================================
#   ход боя
# =====================================================================


func _process(dt: float) -> void:
	var started := Perf13.begin()
	_process_profiled(dt)
	Perf13.end(Perf13.BATTLE, started)


func _process_profiled(dt: float) -> void:
	if sim == null or phase in ["loading", "closing", "result_loading"]:
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
	battle_sound.advance(dt, speed, run)
	if phase == "intro":
		intro_t += dt
		if intro_t > 2.4:
			phase = "fight"
	if hint_lbl.visible and (sim.t > hint_until or phase == "ending" or phase == "result"):
		hint_lbl.modulate.a = maxf(0.0, hint_lbl.modulate.a - dt * 1.5)
		if hint_lbl.modulate.a <= 0.0:
			hint_lbl.visible = false
	var step_started := Perf13.begin()
	if run and phase != "result":
		acc += gdt
		var n := 0
		while acc >= LegionSim.DT and n < 16 and sim.result.is_empty() and not tut_freeze:
			sim.step(LegionSim.DT)
			acc -= LegionSim.DT
			n += 1
			_handle(sim.take_events())
			_tut_check()
	Perf13.end(Perf13.SIM, step_started)
	_tut_arrow(dt)
	if not sim.result.is_empty() and (phase == "fight" or phase == "intro"):
		_begin_end()
	if phase == "ending":
		end_t += dt
		slowmo = lerpf(0.4, 1.0, smoothstep(0.2, 1.6, end_t))
		if end_t > 2.4:
			_show_result(true)
			return
	_update_crowds(gdt)
	var fighting := phase == "intro" or phase == "fight"
	battle_sound.update_field(sim, dt, run and fighting, battle_view)
	battle_view.tick(sim, gdt, dt, acc, fighting)
	_update_ui(dt)
	var had_floats := not bars.floats.is_empty()
	bars.age_floats(dt)
	if had_floats or gdt > 0.0 or phase == "result":
		bars.queue_redraw()


func _fps(dt: float) -> void:
	_fps_t += dt
	_fps_n += 1
	if _fps_t >= 1.0:
		fps_avg = _fps_n / _fps_t
		_fps_t = 0.0
		_fps_n = 0


func _handle(evs: Array) -> void:
	if not evs.is_empty():
		_score_step = -1
	for e: Dictionary in evs:
		match String(e["type"]):
			"wave":
				var n := int(e["n"])
				# волна-«куча» (походы): «Толпа!» и красный круг за ней (в учебном бою — своя подсказка)
				var pack: bool = not pvp and tut == "" and (n - 1) in (setup.get("packs", []) as Array)
				if n > 1:
					var last: bool = n == int(e["total"])
					say(("Босс: " + String(stage.get("name", ""))) if last and bool(stage.get("boss", false)) else "Волна %d из %d" % [n, int(e["total"])], 1.8)
				var boss_wave := false
				for u in sim.units:
					if u.wave == n - 1 and u.side == "enemy" and u.boss:
						boss_wave = true
						break
				battle_sound.wave(boss_wave)
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
				battle_sound.play("war_horn", 0.0, -1.0, 0.86)
				battle_view.ring(_view(e["unit"]).position, 88.0, BattleView.ALERT)
			"summon":
				_summon(e)
			"attack":
				var u: LegionSim.Unit = e["unit"]
				var fighter := _view(u)
				battle_view.request_strike(fighter, _view(e["target"]))
				if u.shot == "":
					_melee_foley(u, fighter)
			"shoot":
				var s: LegionSim.Shot = e["shot"]
				battle_view.shoot(s)
				if s.from != null:
					var pan := battle_view.sound_pan(_view(s.from).position)
					match s.kind:
						"arrow":
							battle_sound.play("bow_release", pan)
							if battle_sound.chance(0.32):
								battle_sound.later("arrow_fly", 0.038, pan * 0.7)
						"bolt", "stone":
							battle_sound.play("swing", pan, 0.0, 0.88)
						"boulder":
							battle_sound.play("giant_vox", pan)
			"hit":
				_hit(e)
			"death":
				var u: LegionSim.Unit = e["unit"]
				var pan := battle_view.sound_pan(_view(u).position)
				_animal_foley(u, pan, true)
				if u.boss or u.key == "hero" or (not "beast" in u.tags and battle_sound.chance(0.25)):
					battle_sound.play("death_vox", pan, -4.0 if not BattleSound.animal_voice(u.key, true).is_empty() else 0.0)
				if BattleSound.is_horse(u):
					battle_sound.play("horse_whinny", pan, -2.0)
			"revive":
				var u: LegionSim.Unit = e["unit"]
				_view(u).revive()
				say("%s поднимается — легион не дрогнет!" % u.name, 1.8)
			"heal":
				var f := _view(e["unit"])
				battle_view.burst("fx_heal", f.chest(), 1.05)
				bars.float_value(f, int(e["amount"]), "heal", sim.t)
				var src: LegionSim.Unit = e.get("from")
				battle_sound.play("heal", battle_view.sound_pan(f.position))
				if src != null and src.alive:
					var priest := _view(src)
					battle_view.cast(priest, f)
					battle_view.ring(priest.position, 55.0, BattleView.GOLD)
			"slam", "boom":
				var pos := BattleView.point(float(e["x"]), float(e["z"]))
				battle_view.ring(pos, float(e["r"]) * 49.0, BattleView.GOLD)
				battle_view.burst("fx_hit", pos - Vector2(0, 46), 1.25)
			"charge":
				var u: LegionSim.Unit = e["unit"]
				var fighter := _view(u)
				if fighter.boss_model != null and fighter.actor.clip_length("Charge") > 0.0:
					battle_view.request_strike(fighter, _view(e["target"]), "Charge")
				_melee_foley(u, fighter)
				battle_view.ring(fighter.position, 67.0, BattleView.ALERT)
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
	bars.float_value(f, int(e["dmg"]), "crit" if crit else ("hurt" if u.side == "ally" else "dmg"), sim.t)
	var src: LegionSim.Unit = e.get("from")
	var pan := battle_view.sound_pan(f.position)
	var melee := src != null and src.shot == ""
	if melee:
		# Симуляция сообщает замах и урон одним шагом. Оставляем зазор в звуке.
		battle_sound.later(BattleView.melee_sound(src, u, sim.t), BattleSound.ATTACK_BEAT, pan, 1.0 if crit else 0.0)
	if src != null and (crit or not u.alive):
		battle_sound.later("hit_flesh", BattleSound.ATTACK_BEAT + 0.018 if melee else 0.035, pan)
	if u.alive and src != null and u.hp > 0.0:
		if battle_sound.chance(0.22):
			_animal_foley(u, pan, true)
		var big := crit or float(e["dmg"]) >= u.max_hp * 0.15
		if big and "human" in u.tags and battle_sound.chance(0.34):
			battle_sound.later("grunt", BattleSound.ATTACK_BEAT if melee else 0.02, pan)


func _field_sound(event: String, pan: float) -> void:
	battle_sound.play(event, pan)


func _melee_foley(u: LegionSim.Unit, fighter: BattleView.Fighter) -> void:
	var pan := battle_view.sound_pan(fighter.position)
	battle_sound.play("swing", pan)
	_animal_foley(u, pan, false)


func _animal_foley(u: LegionSim.Unit, pan: float, hurt: bool) -> void:
	var event := BattleSound.animal_voice(u.key, hurt)
	if not event.is_empty():
		battle_sound.play(event, pan, -2.0 if hurt else 0.0)


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
	battle_sound.play("war_horn", 0.0, -2.0, 0.83)
	battle_view.ring(_view(u).position, 86.0, BattleView.ALERT)
	if k == "avalanche" or k == "chariot":
		battle_view.lane(float(e.get("z", 0.0)), BattleView.ALERT, float(u.abil.get("warn", 1.4)))


func _v2_event(e: Dictionary) -> void:
	match String(e["type"]):
		"avalanche":
			battle_view.lane(float(e["z"]), Color("e7f2ff"), 0.8, 32.0)
			battle_sound.play("boulder", 0.0, 0.0, 0.85)
		"chariot":
			battle_view.lane(float(e["z"]), Color("c6986a"), 1.2, 30.0)
			var impact := BattleView.point(0.0, float(e["z"]))
			battle_sound.play("hit_wood" if bool(e["stopped"]) else "hit_heavy", battle_view.sound_pan(impact))
			say("Копейщики остановили колесницы!" if bool(e["stopped"]) else "Колесницы прошли по ряду!", 1.6)
		"cry":
			say("Боевой клич! Враги бьют сильнее", 1.8)
			battle_sound.play("battle_cry", battle_view.sound_pan(_view(e["unit"]).position), 0.0, 0.95)
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
			bars.float_text(_view(u), I18n.t("неуязвим"), "hurt")
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
			battle_sound.play("oil", battle_view.sound_pan(pos), 0.0, 1.0, true)
		"volley", "fire":
			var tint := Color("ff9c4d") if id == "fire" else Color.WHITE
			var foes := sim.alive_of("enemy" if ours else "ally")
			for u in foes:
				var to := _view(u).chest()
				battle_view.volley(to + Vector2(-320.0 if ours else 320.0, -155.0), to, tint)
			var pan := -0.3 if ours else 0.3
			for delay: float in [0.0, 0.13, 0.27]:
				battle_sound.later("bow_release", delay, pan, -2.0, 1.0, true)
			battle_sound.later("arrow_fly", 0.17, pan * 0.5)
			if id == "fire":
				battle_sound.play("oil", pan, -6.0)
		"testudo", "horn", "eagle":
			for u in sim.alive_of(side):
				battle_view.ring(_view(u).position, 66.0, BattleView.GOLD, 0.9)
			var event := "hit_metal" if id == "testudo" else ("war_horn" if id == "horn" else "war_drum")
			battle_sound.play(event, -0.25 if ours else 0.25, -2.0, 1.0, true)


func _begin_end() -> void:
	var started := Perf14.begin()
	_begin_end_timed()
	Perf14.end(Perf14.BATTLE_RESULT, started)


func _begin_end_timed() -> void:
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
	out["timeout"] = bool(res.get("timeout", false))
	var win := bool(out.get("win", false))
	battle_sound.finish(win)
	finished.emit(out)
	if not bool(out["retreat"]):
		say(I18n.t("Время вышло") if out["timeout"] else ("Победа!" if win else "Отряд отступает…"), 2.0)


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


func _update_ui(dt: float) -> void:
	_update_score(dt)
	for id in perk_btns:
		var pb: PerkButton = perk_btns[id]
		var charge := sim.perk_charge(id)
		var left := sim.perk_ready(id)
		var active := phase == "fight" or phase == "intro"
		var disabled: bool = not active or (tut_freeze and id != "oil")
		if pb.charge != charge or pb.left != left or pb.active != active or pb.disabled != disabled:
			pb.charge = charge
			pb.left = left
			pb.active = active
			pb.disabled = disabled
			pb.queue_redraw()
	var boss := _boss_unit
	if boss != null and not boss.alive:
		boss = null
		for u in sim.units:
			if u.side == "enemy" and u.wave == sim.wave_idx and u.boss and u.alive:
				boss = u
				break
		_boss_unit = boss
	if boss != null:
		boss_panel.visible = true
		boss_bar.value = boss.hp_frac()
		if boss_pic.get_meta("unit_id", -1) != boss.id or boss_pic.texture == null:
			boss_name.text = boss.name
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
	if sim == null or phase in ["loading", "closing", "result_loading"]:
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
	back.z_index = 8
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
func _show_result(sliced := false) -> void:
	var started := Perf14.begin()
	var rescued: Array = out.get("rescued", [])
	var wait_for_faces := not rescued.is_empty() and DisplayServer.get_name() != "headless"
	phase = "result_loading" if sliced or wait_for_faces else "result"
	var win := bool(out.get("win", false))
	var first_lesson := bool(setup.get("fort_guide_first", false)) or bool(out.get("guide_finished", false))
	var p := _modal_panel(610)
	var result_modal := modal
	if phase == "result_loading":
		result_modal.hide()
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
	var title := "Победа!" if win else ("Отступили" if bool(out.get("retreat", false)) else "Поражение")
	if bool(out.get("timeout", false)):
		title = I18n.t("Время вышло")
	var head := _label(title, 44, false, Color("6b4a12") if win else C_BAD, font_title)
	head.name = "LegionBattleResultTitle"
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
	if sliced:
		Perf14.end(Perf14.BATTLE_RESULT, started)
		await get_tree().process_frame
	await _squad_row(v, sliced)
	started = Perf14.begin() if sliced else started
	var rw: Dictionary = out.get("reward", {})
	var reward_faces: Array[TextureRect] = []
	if not rw.is_empty() or not rescued.is_empty():
		var rh := HBoxContainer.new()
		rh.alignment = BoxContainer.ALIGNMENT_CENTER
		rh.add_theme_constant_override("separation", 18)
		for key: String in ["money", "glory", "rp", "rations", "wood", "iron", "leather"]:
			if rw.has(key):
				rh.add_child(_reward_chip(key, int(rw[key])))
		if not rescued.is_empty():
			rh.name = "FortRescuedRewards"
			for person: Dictionary in rescued:
				var portrait := FortPerson.portrait(person, 58)
				var face := portrait.get_node("FortPortraitArt") as TextureRect
				var fallback := Kit.texture(FortPerson.portrait_path(person, "", true))
				if fallback != null:
					face.texture = fallback
				reward_faces.append(face)
				portrait.tooltip_text = I18n.t("Спасённые жители") + " · " + String(person["name"])
				rh.add_child(portrait)
		v.add_child(rh)
		if int(out.get("money_lost", 0)) > 0:
			# казна полна: предел остаётся, но честно — сколько не уместилось
			var ll := _label(I18n.t("Казна полна — не уместилось %s ден.") % game.hud.fmt(out["money_lost"]), 15, true, C_BAD)
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
	if sliced:
		Perf14.end(Perf14.BATTLE_RESULT, started)
		await get_tree().process_frame
		started = Perf14.begin()
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
	Perf14.end(Perf14.BATTLE_RESULT, started)
	if wait_for_faces:
		# Даём стенду дорисовать лица. При задержке остаётся портрет жителя.
		var deadline := Time.get_ticks_msec() + 1000
		while not reward_faces.all(func(face: TextureRect): return bool(face.get_meta("portrait_ready", false))) \
				and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
			if not is_instance_valid(result_modal) or modal != result_modal or phase == "closing":
				return
	result_modal.show()
	phase = "result"


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


## Отряд после боя: павшие — серые.
func _squad_row(parent: Control, sliced: bool) -> void:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 6)
	h.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(h)
	var started := Perf14.begin() if sliced else 0
	var deadline := Time.get_ticks_usec() + 4000
	for u in sim.units:
		if u.side != "ally":
			continue
		var portraits = preload("res://scripts/fort_person.gd")
		var person: Dictionary = portraits.squad_person(legion, u.src)
		var tr: PanelContainer = portraits.portrait(person, 54, legion.worn(person))
		tr.tooltip_text = "%s, ур. %d%s" % [u.name, u.level, "" if u.alive else " — пал в бою"]
		if not u.alive:
			tr.modulate = Color(0.42, 0.38, 0.36, 0.75)
		h.add_child(tr)
		if sliced and Time.get_ticks_usec() >= deadline:
			Perf14.end(Perf14.BATTLE_RESULT, started)
			await get_tree().process_frame
			started = Perf14.begin()
			deadline = Time.get_ticks_usec() + 4000
	Perf14.end(Perf14.BATTLE_RESULT, started)


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
		_:
			tex = Look.resource(key)
	ic.texture = tex
	ic.custom_minimum_size = Vector2(34, 34)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(ic)
	var names := {"money": "денариев", "glory": "Славы", "rp": "очков знаний", "rations": "Еда", "wood": "Дерево", "iron": "Железо", "leather": "Кожа"}
	var l := _label("+" + Gear.stock_text(n), 21, true, C_GOOD)
	l.tooltip_text = I18n.t(String(names.get(key, "")))
	l.mouse_filter = Control.MOUSE_FILTER_PASS
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
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	fade_map.texture = null
	fade_lbl.text = ""
	fade.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, 0.3)
	tw.tween_callback(_finish_close)


func _finish_close() -> void:
	await battle_view.clear_visible()
	var tree := get_tree()
	var started := Perf14.begin()
	# Сначала освобождаем карточку итога, затем поле и его SubViewport.
	_clear_world()
	Perf14.end(Perf14.BATTLE_CLOSE, started)
	Perf14.detail("battle_release_result", started)
	await tree.process_frame
	battle_view.hide()
	battle_view.queue_free()
	await tree.process_frame
	ui.hide()
	ui.queue_free()
	await tree.process_frame
	if is_instance_valid(game):
		await game.prepare_city_return(self)
	started = Perf14.begin()
	_leave()
	Perf14.end(Perf14.BATTLE_CLOSE, started)
	Perf14.detail("battle_leave", started)
	await tree.process_frame
	if is_instance_valid(game) and game.can_save and not out.is_empty():
		await game.save_battle_result()
	var o := out
	started = Perf14.begin()
	legion.battle_closed.emit(o)
	Perf14.end(Perf14.BATTLE_CLOSE, started)
	Perf14.detail("battle_return_ui", started)
	if is_instance_valid(game):
		var legion_ui := LegionUi.of(game.hud)
		while is_instance_valid(legion_ui) and legion_ui.battle_returning:
			await tree.process_frame
	if current == self:
		current = null
	if on_done.is_valid():
		on_done.call(o)
	queue_free()


## Бросить бой без итога (проверки, выход из игры)
func abort() -> void:
	phase = "closing"
	if is_instance_valid(banner):
		_clear_world()
	_leave()
	if current == self:
		current = null
	queue_free()


# =====================================================================
#   полоски здоровья и числа, кнопки умений, звёзды
# =====================================================================

## Полоски здоровья над бойцами и всплывающие числа — всё одним слоем
class TeamHealth extends Control:
	var caption: Label
	var enemy := false
	var initialized := false
	var hp := 0.0
	var max_hp := 0.0
	var displayed := 0.0
	var trail := 0.0
	var _hold := 0.0
	var _shown_hp := -1
	var _shown_max := -1
	var _frame: StyleBoxTexture
	var _fill: StyleBoxTexture

	func _ready() -> void:
		_frame = Kit.box("panels/bar_frame", 42, 0, 30)
		_fill = Kit.box("panels/bar_fill_gold" if enemy else "panels/bar_fill_green", 22, 0, 20)
		_fill.modulate_color = Color("ed6a78") if enemy else Color("93ce74")
		resized.connect(queue_redraw)

	func update_health(current: float, maximum: float, dt: float) -> void:
		var target := current / maximum if maximum > 0.0 else 0.0
		var old_fill := displayed
		var old_trail := trail
		if not initialized:
			displayed = target
			trail = target
			_hold = 0.0
			initialized = true
		elif current < hp and target < displayed:
			# Белый след задерживается на месте удара.
			_hold = 0.14
			trail = maxf(trail, displayed)
		displayed = move_toward(displayed, target, dt * 6.0)
		_hold = maxf(0.0, _hold - dt)
		if _hold <= 0.0:
			trail = move_toward(trail, displayed, dt * 3.2)
		trail = maxf(displayed, trail)
		hp = current
		max_hp = maximum
		var shown_hp := roundi(hp)
		var shown_max := roundi(max_hp)
		if shown_hp != _shown_hp or shown_max != _shown_max or caption.text.is_empty():
			_shown_hp = shown_hp
			_shown_max = shown_max
			caption.text = "%d/%d" % [shown_hp, shown_max]
		if old_fill != displayed or old_trail != trail:
			queue_redraw()


	func _draw() -> void:
		var started := Perf13.begin()
		_draw_profiled()
		Perf13.end(Perf13.TEAM_DRAW, started)


	func _draw_profiled() -> void:
		draw_style_box(_frame, Rect2(Vector2.ZERO, size))
		var width := maxf(0.0, size.x - 12.0)
		var x := 6.0 if enemy else size.x - 6.0
		if (trail - displayed) * width >= 1.0:
			var left := x + width * displayed if enemy else x - width * trail
			draw_rect(Rect2(left, 7, width * (trail - displayed), size.y - 14.0), Color("fff7ea"))
		if displayed * width >= 1.0:
			var left := x if enemy else x - width * displayed
			draw_style_box(_fill, Rect2(left, 5, width * displayed, size.y - 10.0))


class BarsLayer extends Control:
	const MERGE_WINDOW := 0.15
	const MAX_PER_TARGET := 3
	const OUTLINE := 5
	const BAR_EDGE := Color("593413")
	const BAR_TRIM := Color("e1a841")
	const BAR_EMPTY := Color("512412")
	const BAR_TRAIL := Color("cd8f52")
	const BAR_ALLY := Color("78da25")
	const BAR_ENEMY := Color("ea3a2c")

	class FloatText:
		var id: int
		var anchor: Vector2
		var caption: String
		var kind: String
		var amount := 0
		var numeric := false
		var since := 0.0
		var age := 0.0
		var older := false
		var box := Rect2()
		var baseline := Vector2()
		var font_size := 22
		var extent := Vector2.ZERO
		var ascent := 0.0
		var needs_measure := true

	var battle: LegionBattle
	var floats: Array[FloatText] = []
	var _rows := {}
	var _occupied: Array[Rect2] = []
	var _overlapping: Array[Rect2] = []

	func float_value(target: BattleView.Fighter, amount: int, kind: String, now: float) -> void:
		for i in range(floats.size() - 1, -1, -1):
			var fl := floats[i]
			if fl.id != target.unit.id or not fl.numeric or (fl.kind == "heal") != (kind == "heal"):
				continue
			if now - fl.since <= MERGE_WINDOW + 0.00001:
				fl.amount += amount
				if kind == "crit":
					fl.kind = "crit"
				_format_value(fl)
				return
			break
		var fl := _add_float(target, kind)
		fl.numeric = true
		fl.amount = amount
		fl.since = now
		_format_value(fl)

	func _format_value(fl: FloatText) -> void:
		fl.caption = ("+" if fl.kind == "heal" else "") + str(fl.amount) + ("!" if fl.kind == "crit" else "")
		fl.needs_measure = true

	func float_text(target: BattleView.Fighter, caption: String, kind: String) -> void:
		_add_float(target, kind).caption = caption

	func _add_float(target: BattleView.Fighter, kind: String) -> FloatText:
		var count := 0
		for i in range(floats.size() - 1, -1, -1):
			if floats[i].id != target.unit.id:
				continue
			count += 1
			floats[i].older = true
			if count >= MAX_PER_TARGET:
				floats.remove_at(i)
		var fl := FloatText.new()
		fl.id = target.unit.id
		fl.anchor = battle.battle_view.screen(target.head())
		fl.kind = kind
		floats.append(fl)
		return fl

	func age_floats(dt: float) -> void:
		for i in range(floats.size() - 1, -1, -1):
			var fl := floats[i]
			fl.age += dt * (1.8 if fl.older else 1.0)
			if fl.age >= 1.0:
				floats.remove_at(i)

	func layout_floats(reuse_heads := false) -> void:
		var started := Perf13.begin()
		layout_floats_profiled(reuse_heads)
		Perf13.end(Perf13.BARS, started)


	func layout_floats_profiled(reuse_heads: bool) -> void:
		_rows.clear()
		_occupied.clear()
		var fnt := battle.font_bold
		for i in range(floats.size() - 1, -1, -1):
			var fl := floats[i]
			var target: BattleView.Fighter = battle.views.get(fl.id)
			if target != null:
				fl.anchor = target.hud_anchor if reuse_heads and target.unit.alive else battle.battle_view.screen(target.head())
			var row: int = _rows.get(fl.id, 0)
			_rows[fl.id] = row + 1
			if fl.needs_measure:
				fl.font_size = 28 if fl.kind == "crit" else 22
				fl.ascent = fnt.get_ascent(fl.font_size)
				fl.extent = Vector2(fnt.get_string_size(fl.caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fl.font_size).x,
					fl.ascent + fnt.get_descent(fl.font_size)) + Vector2.ONE * OUTLINE
				fl.needs_measure = false
			var extent := fl.extent
			# Свежая цифра ближе к полоске здоровья.
			var y := maxf(44.0, fl.anchor.y - 13.0 - row * 37.0 - 12.0 * fl.age - extent.y)
			var x := clampf(fl.anchor.x - extent.x * 0.5, 6.0, maxf(6.0, size.x - extent.x - 6.0))
			var box := Rect2(Vector2(x, y), extent)
			if size.x > extent.x + 12.0:
				box = _free_number_box(box)
			_occupied.append(box)
			fl.box = box
			fl.baseline = box.position + Vector2(OUTLINE * 0.5, OUTLINE * 0.5 + fl.ascent)

	func _free_number_box(box: Rect2) -> Rect2:
		while true:
			_overlapping.clear()
			var blocked := false
			for other in _occupied:
				if other.end.y > box.position.y and other.position.y < box.end.y:
					_overlapping.append(other)
					if box.intersects(other):
						blocked = true
			if not blocked:
				return box
			var nearest := INF
			var x := box.position.x
			for other in _overlapping:
				var left := other.position.x - box.size.x - 3.0
				var right := other.end.x + 3.0
				if absf(box.position.x - left) < nearest and _number_fits(box, left):
					nearest = absf(box.position.x - left)
					x = left
				if absf(right - box.position.x) < nearest and _number_fits(box, right):
					nearest = absf(right - box.position.x)
					x = right
			if nearest < INF:
				box.position.x = x
				return box
			box.position.y -= box.size.y + 3.0
		return box

	func _number_fits(box: Rect2, x: float) -> bool:
		if x < 6.0 or x + box.size.x > size.x - 6.0:
			return false
		box.position.x = x
		for other in _overlapping:
			if box.intersects(other):
				return false
		return true

	func _draw() -> void:
		var started := Perf13.begin()
		_draw_profiled()
		Perf13.end(Perf13.DRAW_BARS, started)


	func _draw_profiled() -> void:
		if battle == null or battle.sim == null or battle.phase == "result":
			return
		var fnt: Font = battle.font_bold
		var scale_ui: float = battle.battle_view.world.scale.x
		var score_floor := battle._score_floor()
		for id in battle.views:
			var f: BattleView.Fighter = battle.views[id]
			var u := f.unit
			if not u.alive:
				continue
			var p := battle.battle_view.screen(f.head())
			f.hud_anchor = p
			var w := 74.0 * scale_ui
			var h := 5.5 * scale_ui
			if not battle.battle_view.legacy_layout:
				w = clampf(f.body_height() * 0.29, 39.0, 88.0) * scale_ui
				h *= 0.78
			p.y = maxf(p.y, score_floor + (h + 7.0) * 0.5 + 4.0)
			var left := p - Vector2(w * 0.5, 0)
			var right := left + Vector2(w, 0)
			draw_line(left, right, BAR_EDGE, h + 7.0, true)
			draw_line(left, right, BAR_TRIM, h + 4.0, true)
			draw_line(left, right, BAR_EMPTY, h + 1.8, true)
			var hp := u.hp_frac()
			var col := BAR_ALLY if u.side == "ally" else BAR_ENEMY
			draw_line(left, left.lerp(right, f.health), BAR_TRAIL, h, true)
			draw_line(left, left.lerp(right, hp), col, h, true)
			draw_line(left - Vector2(0, 1), left.lerp(right, hp) - Vector2(0, 1), Color(col.lightened(0.4), 0.9), 1.5, true)
		if not floats.is_empty():
			layout_floats(true)
		for fl in floats:
			var col := Color("fff1d2")
			if fl.kind == "crit":
				col = Color("ffd34d")
			elif fl.kind == "hurt":
				col = Color("ff9a7a")
			elif fl.kind == "heal":
				col = Color("9cf08a")
			col.a = 1.0 - smoothstep(0.50 if fl.older else 0.66, 1.0, fl.age)
			draw_string_outline(fnt, fl.baseline, fl.caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fl.font_size,
				OUTLINE, Color(0.2, 0.08, 0.03, col.a * 0.85))
			draw_string(fnt, fl.baseline, fl.caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fl.font_size, col)


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
	button.text += " · " + game.hud.fmt(legion.ration_cost(st))
	button.icon = Look.resource("rations")
	button.icon = _icon_tex("bread")
	button.add_theme_color_override("font_disabled_color", C_BAD if legion.rations < legion.ration_cost(st) else C_SOFT)
