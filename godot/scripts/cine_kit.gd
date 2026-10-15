class_name CineKit
extends Node
## Общее для роликов (вынесено из rank_cine.gd; ролик ранга и обучение пока живут по-старому):
## чёрные полосы сверху и снизу, затемнение, «стекло» над миром (мышь не щёлкает город и не крутит камеру),
## «Пропустить ›», интерфейс тает и возвращается, камера плывёт к кадру и потом обратно к игроку,
## скорость игры на время ролика ×1 и потом прежняя (окно свернули — отдаётся тому, кто вернёт её при разворачивании).
## Клавиши: Esc и правая кнопка — пропустить (on_skip); пробел, Enter и щелчок по кадру — дальше (on_next, если задан,
## иначе тоже пропустить). Кто ведёт ролик, зовёт tick(dt) каждый кадр, cam_to — новый кадр, back — домой.
## Когда камера вернулась и интерфейс виден — сигнал finished, узел удаляет себя сам.

signal finished

const BAR := 0.11                    # высота чёрных полос — доля высоты экрана

var game
var hud
var on_skip := Callable()
var on_next := Callable()
var ui: CanvasLayer
var block: Control                   # ловит мышь над миром; сюда же ролик кладёт облачко и подписи
var veil: ColorRect
var bar_top: ColorRect
var bar_bot: ColorRect
var skip_btn: Button
var caption: Label                   # подпись в нижней полосе (награда)
var t := 0.0                         # сколько идёт ролик
var phase := ""                      # run | back | ""
var bars := 0.0
var speed0 := 1.0
var tool0 := ""
var overlay := ""
var pos := Vector3.ZERO              # где камера сейчас и куда смотрит
var look := Vector3.ZERO
var _from := []                      # полёт камеры: откуда [pos, look], куда, сколько, прошло, высота дуги
var _to := []
var _dur := 0.0
var _ct := 0.0
var _arc := 0.0
var _back := 0.0
var _bt := 0.0


## Начать: камера — ролику, интерфейс тает, скорость ×1
func begin(g) -> void:
	game = g
	hud = g.hud
	tool0 = game.tool
	game.set_tool("")                    # начатую дорогу set_tool дописывает, призрак и перенос убирает
	hud._close_tray()
	hud._hide_info()
	hud.advisor_panel.visible = false
	game._plot_hover(Vector2i(-1, -1))
	overlay = hud.overlay
	if overlay != "":
		hud.set_overlay("")              # «Обзор»: подсветка домов и значки — в кадре им не место
	var rig = game.rig
	rig._orbit = false
	rig._pan = false
	rig.cine = true
	var p0: Array = rig.pose()
	pos = p0[0]
	look = p0[1]
	speed0 = float(game.speed)
	game.speed = 1.0
	phase = "run"
	_ui()


func active() -> bool:
	return phase != ""


## Камера плывёт к кадру (p — где, l — куда смотрит) за dur с; arc — подъём посередине пути
func cam_to(p: Vector3, l: Vector3, dur: float, arc := -1.0) -> void:
	_from = [pos, look]
	_to = [p, l]
	_dur = maxf(0.01, dur)
	_ct = 0.0
	_arc = minf(6.0, pos.distance_to(p) * 0.12) if arc < 0.0 else arc


## Камера сейчас летит
func moving() -> bool:
	return not _to.is_empty() and _ct < _dur


## Кадр сразу, без полёта
func cam_set(p: Vector3, l: Vector3) -> void:
	_to = []
	_cam(p, l)


func _cam(p: Vector3, l: Vector3) -> void:
	p.y = maxf(p.y, game.land.height_at(p.x, p.z) + 1.0)
	pos = p
	look = l
	game.rig.cine_look(p, l)


func tick(dt: float) -> void:
	if phase == "":
		return
	t += dt
	if phase == "run":
		if not _to.is_empty():
			_ct = minf(_dur, _ct + dt)
			var u := smoothstep(0.0, _dur, _ct)
			_cam((_from[0] as Vector3).lerp(_to[0], u) + Vector3.UP * _arc * sin(u * PI), (_from[1] as Vector3).lerp(_to[1], u))
		_hud_alpha(1.0 - smoothstep(0.0, 0.45, t))
		if t >= 0.45:
			hud.visible = false
		bars = smoothstep(0.0, 0.8, t)
		_bars(bars)
	elif phase == "back":
		_bt += dt
		var u := smoothstep(0.0, _back, _bt)
		var to: Array = game.rig.pose()
		game.rig.cine_look((_from[0] as Vector3).lerp(to[0], u), (_from[1] as Vector3).lerp(to[1], u))
		veil.color.a = maxf(0.0, veil.color.a - dt * 3.0)
		_bars(minf(bars, 1.0 - smoothstep(0.0, _back * 0.7, _bt)))
		if _bt > _back * 0.35:
			hud.visible = true
			_hud_alpha(maxf(hud.root.modulate.a, smoothstep(_back * 0.35, _back, _bt)))
		if _bt >= _back:
			_end()


## Домой: камера плывёт к игроку, полосы уходят, интерфейс возвращается
func back(dur := 1.2) -> void:
	if phase != "run":
		return
	_from = [pos, look]
	_back = maxf(0.05, dur)
	_bt = 0.0
	phase = "back"
	for n: Control in [caption]:
		if n != null and n.modulate.a > 0.0:
			n.create_tween().tween_property(n, "modulate:a", 0.0, 0.3)


func _end() -> void:
	var rig = game.rig
	rig.cine = false
	rig._orbit = false
	rig._pan = false
	hud.visible = true
	_hud_alpha(1.0)
	if ui != null:
		ui.queue_free()
		ui = null
	phase = ""
	if overlay != "" and hud.overlay == "" and game.tool == "":
		hud.set_overlay(overlay)
	if float(game._min_speed) >= 0.0:
		# окно свёрнуто — скорость игрока отдаём тому, кто вернёт её при разворачивании
		if is_equal_approx(float(game._min_speed), 1.0):
			game._min_speed = speed0
			hud.paused_speed = speed0
		hud.refresh()
	elif is_equal_approx(float(game.speed), 1.0):
		hud.set_speed(speed0)
	else:
		hud.refresh()
	if Defs.B.has(tool0) or game.is_road_tool(tool0):
		game.set_tool(tool0)             # строил — строит дальше
	finished.emit()
	queue_free()


## Прозрачность интерфейса: окна (root), значки над миром и стрелка к заданию — вместе
func _hud_alpha(a: float) -> void:
	hud.root.modulate.a = a
	for n in [hud.badge_layer, hud.pointer, hud.pointer_text]:
		if n != null:
			(n as CanvasItem).modulate.a = a


## Пока идёт ролик: Esc и правая кнопка — пропустить; пробел и Enter — дальше; клавиши игре не достаются
func _input(e: InputEvent) -> void:
	if phase != "run":
		if phase == "back" and (e is InputEventKey or (e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT)):
			get_viewport().set_input_as_handled()
		return
	if e is InputEventKey:
		var k := e as InputEventKey
		if k.pressed and not k.echo:
			if k.keycode == KEY_ESCAPE:
				_skip()
			elif k.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
				_next()
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		if e.is_pressed():
			_skip()
		get_viewport().set_input_as_handled()


## Щелчок левой по кадру (не по кнопкам облачка) — дальше (не в первые полсекунды: вдруг игрок щёлкал по городу)
func _on_block_input(e: InputEvent) -> void:
	if phase != "run" or t <= 0.5:
		return
	if e is InputEventMouseButton and e.is_pressed() and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_next()


func _skip() -> void:
	if on_skip.is_valid():
		on_skip.call()
	else:
		back(0.9)


func _next() -> void:
	if on_next.is_valid():
		on_next.call()
	else:
		_skip()


func _ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 40                        # над интерфейсом, под экраном загрузки
	add_child(ui)
	block = Control.new()
	block.set_anchors_preset(Control.PRESET_FULL_RECT)
	block.mouse_filter = Control.MOUSE_FILTER_STOP
	block.theme = hud.theme_main
	block.gui_input.connect(_on_block_input)
	ui.add_child(block)
	veil = ColorRect.new()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.02, 0.015, 0.01, 0.0)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(veil)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0.02, 0.015, 0.01)
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if top else 1.0
		bar.anchor_bottom = bar.anchor_top
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.add_child(bar)
		if top:
			bar_top = bar
		else:
			bar_bot = bar
	caption = Label.new()
	caption.anchor_right = 1.0
	caption.anchor_top = 1.0 - BAR
	caption.anchor_bottom = 1.0
	caption.offset_left = 280
	caption.offset_right = -280
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_override("font", hud.font_bold)
	caption.add_theme_font_size_override("font_size", 19)
	caption.add_theme_color_override("font_color", Color("fff3dc"))
	caption.modulate.a = 0.0
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(caption)
	skip_btn = Button.new()
	skip_btn.text = "Пропустить  ›"
	skip_btn.flat = true
	skip_btn.focus_mode = Control.FOCUS_NONE
	skip_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	skip_btn.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip_btn.anchor_left = 1.0
	skip_btn.anchor_right = 1.0
	skip_btn.anchor_top = 1.0 - BAR
	skip_btn.anchor_bottom = 1.0
	skip_btn.offset_left = -260
	skip_btn.offset_right = -30
	skip_btn.add_theme_font_override("font", hud.font_title)
	skip_btn.add_theme_font_size_override("font_size", 20)
	for s in ["font_color", "font_focus_color"]:
		skip_btn.add_theme_color_override(s, Color(1.0, 0.94, 0.82, 0.62))
	for s in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		skip_btn.add_theme_color_override(s, Color("ffe7a8"))
	skip_btn.pressed.connect(_skip)
	block.add_child(skip_btn)
	_bars(0.0)


func _bars(k: float) -> void:
	if bar_top == null:
		return
	var h := get_viewport().get_visible_rect().size.y * BAR * k
	bar_top.offset_bottom = h
	bar_bot.offset_top = -h
	skip_btn.modulate.a = k


## Подпись в нижней полосе (награда истории): мягко проявляется
func say_caption(text: String) -> void:
	if caption == null:
		return
	caption.text = text
	caption.create_tween().tween_property(caption, "modulate:a", 1.0, 0.6)
