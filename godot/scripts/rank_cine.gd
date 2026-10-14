extends Node
## Ролик «Новый ранг»: город перешёл на новый уровень — камера летит к почтовой станции, в пыли старая станция
## уходит, новая поднимается из-под земли; табличка с названием ранга и подпись, что открылось; камера отходит,
## показывая город вокруг, и возвращается туда, где была. Один раз на каждый ранг (city.tips.rank_cine).
## Esc, пробел, Enter, правая кнопка или щелчок — пропустить. Ждёт, пока игрок не занят (окно, стройка, обучение);
## в меню, демо, промо, на снимках, в тестах и автопроверке не играет.

const BAR := 0.11                    # высота чёрных полос — доля высоты экрана
const DUST := 0.3                    # пыль, и старая станция пропадает
const RISE := 1.8                    # новая поднимается из-под земли
const SETTLE := 0.2
const HOLD := 2.4                    # табличка и подпись, камера отходит
const BACK := 1.5                    # возврат к камере игрока
const T_REVEAL := DUST + RISE + SETTLE
const T_ORBIT := T_REVEAL + HOLD
## кадры: [поворот от фасада, °; наклон, °; доля расстояния; куда смотрим — доля высоты станции].
## Чем выше точка взгляда, тем ниже станция в кадре: к концу она под табличкой, а не за ней
const SHOT_A := [-32.0, 20.0, 1.05, 0.45]
const SHOT_B := [6.0, 17.0, 0.92, 0.6]
const SHOT_C := [24.0, 30.0, 1.7, 0.85]
const ORD := {2: "второй", 3: "третий", 4: "четвёртый", 5: "пятый", 6: "шестой"}
const AS_NAME := ["", "хутором", "деревней"]          # «Город стал …!» — советник после первых двух рангов
const PICK := ["floor2", "scribes1", "artisans", "school"]   # их советник называет первыми

var game
var hud
var force := false                   # тесты: играть и когда игра — не главная сцена
var pending := {}                    # ранг ждёт ролика: {from, to, late}; late — станция уже показана новой
var cine := {}                       # идёт ролик: фаза, время, кадр, призрак станции
var ui: CanvasLayer
var _poll := 0.0
var _head_dy := 0.0                  # табличка съезжает сверху на место


func setup(g) -> void:
	game = g
	hud = g.hud
	var c: City = game.city
	if not c.tips.has("rank_cine"):
		c.tips["rank_cine"] = c.level        # старые сохранения: уже полученные ранги не показываем
	elif int(c.tips["rank_cine"]) < c.level:
		pending = {"from": int(c.tips["rank_cine"]), "to": c.level, "late": true}   # вышли из игры, не досмотрев
	c.level_up.connect(_on_level_up)


## Где ролик вообще бывает: своя игра (новая или загруженная), не снимок, не автопроверка, не тестовая сцена
func allowed() -> bool:
	if game == null or not game.ready_done or game.rig == null:
		return false
	if not (game.mode in ["new", "play"]) or game.shot_path != "" or QaDrive._inst != null:
		return false
	return force or game == get_tree().current_scene


## Игрок ничем не занят — можно забрать камеру
func calm() -> bool:
	if not hud.visible or not hud.root.visible or hud.hidden_ui:
		return false
	if LegionBattle.current != null or float(game.speed) <= 0.0:
		return false
	if game.painting or game.pressing or game.rot_drag or not game.moving.is_empty() or not game.moving_nature.is_empty():
		return false
	if not game.place_lock.is_empty() or game.tool == "settle":
		return false                     # выбирает дом семье или держит повёрнутую постройку
	var tut = game.tutorial
	if tut != null and (not tut.cine.is_empty() or tut.active()):
		return false
	for p in [hud.pause_panel, hud.settings_panel, hud.credits_panel, hud.research_panel, hud.events_panel,
			hud.finance_panel, hud.stats_panel, hud.buy_panel]:
		if p != null and p.visible:
			return false
	var lu := LegionUi.of(hud)
	if lu != null and lu.visible:
		return false
	var acc = hud.get_node_or_null("AccountUi")
	if acc != null:
		var mk = acc.get("_modal_kind")
		if mk != null and String(mk) != "":
			return false
	return not game.city.center().is_empty()


## Станцию пока не перерисовывать новой — её покажет ролик
func holds_station() -> bool:
	return not cine.is_empty() or (not pending.is_empty() and not bool(pending["late"]))


## Всплывашку «Город теперь — …» заменяет ролик (событие остаётся в колокольчике)
func covers_toast() -> bool:
	return not cine.is_empty() or not pending.is_empty()


func _on_level_up(lvl: int) -> void:
	if not allowed() or lvl <= int(game.city.tips.get("rank_cine", 0)):
		return
	if not cine.is_empty():
		pending = {"from": int(cine["to"]), "to": lvl, "late": true}
	elif pending.is_empty():
		pending = {"from": lvl - 1, "to": lvl, "late": not calm()}
		_poll = 0.0
	else:
		pending["to"] = lvl              # несколько рангов за раз — один ролик


func _process(dt: float) -> void:
	if not cine.is_empty():
		_tick(minf(dt, 0.05))
		return
	if pending.is_empty() or game == null or not game.ready_done:
		return
	_poll += dt
	if _poll < 0.4:
		return
	_poll = 0.0
	if not allowed():
		if not bool(pending["late"]):
			_release()                   # придержанную станцию — показать новой
		pending = {}
	elif calm():
		_start()
	elif not bool(pending["late"]):
		_release()


## Игрок занят — станция становится новой сразу (с облачком), а ролик подождёт и начнётся с затемнения
func _release() -> void:
	pending["late"] = true
	var st: Dictionary = game.city.center()
	if not st.is_empty():
		game._show(st)
		game._puff(Vector3(st["pos"].x, float(st["y"]), st["pos"].y), Color("fff3c8"))


func _start() -> void:
	var c: City = game.city
	var st: Dictionary = c.center()
	var from := int(pending["from"])
	var to := c.level
	var late := bool(pending["late"])
	pending = {}
	c.tips["rank_cine"] = to             # сразу: даже если выйдут посреди ролика, второй раз не покажем
	if from >= to:
		game._show(st)
		return
	var tool0: String = game.tool
	game.set_tool("")                    # начатую дорогу set_tool дописывает, призрак и перенос убирает
	hud._close_tray()
	hud._hide_info()
	game._plot_hover(Vector2i(-1, -1))
	var reach: bool = hud.reach_on
	if reach:
		hud._toggle_reach()              # кольца дальности — тоже 3D, в кадре им не место
	var rig = game.rig
	rig._orbit = false
	rig._pan = false
	rig.cine = true
	var p0: Array = rig.pose()
	var top: float = c.blueprint(st).top_y()
	var old_top: float = Catalog.make("center", from, int(st.get("variant", 0)), int(st.get("color", 0))).top_y()
	cine = {"t": 0.0, "pt": 0.0, "phase": "fade" if late else "glide", "st": st, "from": from, "to": to,
		"p0": p0[0], "l0": p0[1], "pos": p0[0], "look": p0[1], "top": top, "dy": maxf(1.6, top - old_top + 0.4),
		"side": _side(st), "glide": clampf(0.8 + float(rig.dist) / 80.0, 1.2, 2.0), "speed0": float(game.speed),
		"tool0": tool0, "reach": reach, "d0": false, "d1": false, "hid": false, "shown": false, "said": false, "bars": 0.0}
	game.speed = 1.0
	_ui()
	cine["ghost"] = _ghost(st)           # собрать заранее, пока камера летит, — без рывка в кадре


## С какой стороны фасада меньше построек игрока: оттуда начинается облёт (+1 — с «минусовой»)
func _side(st: Dictionary) -> float:
	var c: City = game.city
	var n := [0, 0]
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		if b["id"] == st["id"] or c.def(b)["kind"] == "decor":
			continue
		var v: Vector2 = (b["pos"] as Vector2) - (st["pos"] as Vector2)
		if v.length() > 30.0 or v.length() < 0.1:
			continue
		var a := angle_difference(float(st["yaw"]), atan2(v.x, v.y))
		if absf(a) < deg_to_rad(70.0):
			n[1 if a > 0.0 else 0] += 1
	return 1.0 if n[0] < n[1] else -1.0


## Кадр k = [поворот, наклон, доля расстояния, доля высоты] → [где камера, куда смотрит]
func _shot(k: Array) -> Array:
	var st: Dictionary = cine["st"]
	var top: float = cine["top"]
	var f := City.facing(float(st["yaw"]))
	var look := Vector3(st["pos"].x + f.x, float(st["y"]) + top * float(k[3]), st["pos"].y + f.y)
	var yaw := float(st["yaw"]) + deg_to_rad(float(k[0]) * float(cine["side"]))
	var p := deg_to_rad(float(k[1]))
	var d := (16.0 + top * 1.2) * float(k[2])
	return [look + Vector3(sin(yaw) * cos(p), sin(p), cos(yaw) * cos(p)) * d, look]


## Облёт: A → B к моменту, когда станция встала (камера на миг замирает), потом B → C — отходит, виден город
func _orbit(t: float) -> Array:
	var a: Array = SHOT_A
	var b: Array = SHOT_B
	var u := smoothstep(0.0, T_REVEAL, t)
	if t > T_REVEAL:
		a = SHOT_B
		b = SHOT_C
		u = smoothstep(T_REVEAL, T_ORBIT + BACK * 0.5, t)
	return _shot([lerpf(a[0], b[0], u), lerpf(a[1], b[1], u), lerpf(a[2], b[2], u), lerpf(a[3], b[3], u)])


func _cam(pos: Vector3, look: Vector3) -> void:
	pos.y = maxf(pos.y, game.land.height_at(pos.x, pos.z) + 1.2)
	cine["pos"] = pos
	cine["look"] = look
	game.rig.cine_look(pos, look)


## Новая станция целиком, без подсветки призрака и с тенью (как надстройка этажа в промо-ролике)
func _ghost(st: Dictionary) -> Node3D:
	var gh := Parts.ghost(game.city.blueprint(st), "place")
	for mi: GeometryInstance3D in gh.find_children("*", "GeometryInstance3D", true, false):
		mi.material_overlay = null
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	gh.transform = game.city.xf(st)
	gh.visible = false
	game.add_child(gh)
	return gh


## Показать станцию в облике уровня t (под затемнением — старую, чтобы она ушла в пыль)
func _show_tier(st: Dictionary, t: int) -> void:
	var t0 := int(st["tier"])
	st["tier"] = t
	game._show(st)
	st["tier"] = t0


## Пыль рядами вдоль фасада (z — от середины станции); таймеры — у игры, не у ролика
func _dust(rows: Array) -> void:
	var xf: Transform3D = game.city.xf(cine["st"])
	var i := 0
	for z in rows:
		for x in [-3.6, 0.0, 3.6]:
			game.get_tree().create_timer(0.07 * i).timeout.connect(game._puff.bind(xf * Vector3(x, 0.2, float(z)), Color("e8dcc4")))
			i += 1


func _phase(name: String) -> void:
	cine["phase"] = name
	cine["pt"] = 0.0


func _tick(dt: float) -> void:
	cine["t"] = float(cine["t"]) + dt
	cine["pt"] = float(cine["pt"]) + dt
	var pt: float = cine["pt"]
	var veil: ColorRect = cine["veil"]
	if float(cine["t"]) > 20.0 and cine["phase"] != "back":
		_skip()                          # на всякий случай: ролик не дольше 20 секунд
		pt = 0.0
	match cine["phase"]:
		"glide":
			# к станции по небольшой дуге; интерфейс тает
			var g: float = cine["glide"]
			var u := smoothstep(0.0, g, pt)
			var a := _orbit(0.0)
			var p0: Vector3 = cine["p0"]
			var arc := minf(8.0, p0.distance_to(a[0]) * 0.12) * sin(u * PI)
			_cam(p0.lerp(a[0], u) + Vector3.UP * arc, (cine["l0"] as Vector3).lerp(a[1], u))
			_hud_out(pt)
			if pt >= g:
				_phase("orbit")
		"fade":
			# станция уже новая: под затемнением возвращаем старую и сразу ставим камеру у фасада
			veil.color.a = smoothstep(0.0, 0.45, pt)
			_hud_out(pt)
			if pt >= 0.45:
				_show_tier(cine["st"], int(cine["from"]))
				var a := _orbit(0.0)
				_cam(a[0], a[1])
				_phase("open")
		"open":
			veil.color.a = 1.0 - smoothstep(0.0, 0.6, pt)
			if pt >= 0.6:
				_phase("orbit")
		"orbit":
			_orbit_tick(pt)
		"back":
			# плавно назад, туда, где камера была до ролика; полосы уходят, интерфейс возвращается
			var bl: float = cine["back"]
			var u := smoothstep(0.0, bl, pt)
			var to: Array = game.rig.pose()
			game.rig.cine_look((cine["from_pos"] as Vector3).lerp(to[0], u), (cine["from_look"] as Vector3).lerp(to[1], u))
			veil.color.a = maxf(0.0, veil.color.a - dt * 3.0)
			_bars(minf(float(cine.get("bars", 1.0)), 1.0 - smoothstep(0.0, bl * 0.7, pt)))
			if pt > bl * 0.35:
				hud.visible = true
				_hud_alpha(maxf(hud.root.modulate.a, smoothstep(bl * 0.35, bl, pt)))
			if pt >= bl:
				_end()
			return
	if cine["phase"] != "back":
		cine["bars"] = smoothstep(0.0, 0.8, float(cine["t"]))
		_bars(cine["bars"])


func _hud_out(pt: float) -> void:
	_hud_alpha(1.0 - smoothstep(0.0, 0.45, pt))
	if pt >= 0.45:
		hud.visible = false


## Прозрачность интерфейса: окна (root), значки над миром и стрелка к заданию — вместе
func _hud_alpha(a: float) -> void:
	hud.root.modulate.a = a
	for n in [hud.badge_layer, hud.pointer, hud.pointer_text]:
		if n != null:
			(n as CanvasItem).modulate.a = a


## Облёт: пыль, старая станция пропадает, новая поднимается из-под земли (низ скрыт землёй); встала — табличка
func _orbit_tick(pt: float) -> void:
	var o := _orbit(pt)
	_cam(o[0], o[1])
	var st: Dictionary = cine["st"]
	if not bool(cine["d0"]):
		cine["d0"] = true
		_dust([1.4, -2.0])
	if pt >= DUST and not bool(cine["hid"]):
		cine["hid"] = true
		game._hide(st)
		var g0 = cine.get("ghost")
		if g0 != null and is_instance_valid(g0):
			(g0 as Node3D).visible = true
	var gh = cine.get("ghost")
	if bool(cine["hid"]) and gh != null and is_instance_valid(gh):
		var u := clampf((pt - DUST) / RISE, 0.0, 1.0)
		var xf: Transform3D = game.city.xf(st)
		(gh as Node3D).position = xf.origin - Vector3.UP * float(cine["dy"]) * pow(1.0 - u, 3.0)
		if pt - DUST >= 0.6 and not bool(cine["d1"]):
			cine["d1"] = true
			_dust([1.4])
	if pt >= T_REVEAL:
		_reveal(true)
	if pt >= T_REVEAL + 0.4 and not bool(cine["said"]):
		_say()
	if pt >= T_ORBIT:
		_back(BACK)


## Станция встала: настоящая вместо призрака, облачка; full — ещё монетки и табличка (при пропуске — тихо)
func _reveal(full: bool) -> void:
	if bool(cine["shown"]):
		return
	cine["shown"] = true
	var gh = cine.get("ghost")
	if gh != null and is_instance_valid(gh):
		(gh as Node).queue_free()
	cine.erase("ghost")
	var st: Dictionary = cine["st"]
	if game.city.buildings.has(st["id"]):
		game._show(st)
	var base := Vector3(st["pos"].x, float(st["y"]), st["pos"].y)
	game._puff(base, Color("fff3c8"))
	game._puff(base + Vector3(0, float(cine["top"]) * 0.5, 0), Color("fff3c8"))
	if full:
		if game.sound:
			game.sound.ui("coins")       # из звуков интерфейса владелец оставил только монетки
		_title_in()


func _back(dur: float) -> void:
	if cine["phase"] == "back":
		return
	_reveal(false)
	cine["from_pos"] = cine["pos"]
	cine["from_look"] = cine["look"]
	cine["back"] = dur
	_title_out()
	_phase("back")


func _skip() -> void:
	if cine.is_empty() or cine["phase"] == "back":
		return
	_back(0.9)


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
	var gh = cine.get("ghost")
	if gh != null and is_instance_valid(gh):
		(gh as Node).queue_free()
	var st: Dictionary = game.city.center()
	if not st.is_empty() and (int(st["tier"]) != int(cine["to"]) or not game.visuals.has(st["id"])):
		game._show(st)                   # за время ролика пришёл ещё ранг — станция уже следующая
	if bool(cine["reach"]) and not hud.reach_on:
		hud._toggle_reach()
	var s0: float = cine["speed0"]
	var tool0: String = cine["tool0"]
	var to: int = cine["to"]
	cine = {}
	if is_equal_approx(float(game.speed), 1.0):
		hud.set_speed(s0)
	else:
		hud.refresh()
	if Defs.B.has(tool0) or game.is_road_tool(tool0):
		game.set_tool(tool0)             # строил — строит дальше
	_advise(to)


## Пока идёт ролик: Esc, пробел, Enter и правая кнопка — пропустить; клавиши игре не достаются
func _input(e: InputEvent) -> void:
	if cine.is_empty():
		return
	if e is InputEventKey:
		var k := e as InputEventKey
		if k.pressed and not k.echo and k.keycode in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			_skip()
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		if e.is_pressed():
			_skip()
		get_viewport().set_input_as_handled()


## Щелчок левой по кадру — тоже пропустить (не в первые полсекунды: вдруг игрок щёлкал по городу)
func _on_block_input(e: InputEvent) -> void:
	if cine.is_empty() or float(cine["t"]) <= 0.6:
		return
	if e is InputEventMouseButton and e.is_pressed() and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_skip()


# ---------- полосы, табличка, подпись ----------

func _ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 40                        # над интерфейсом, под экраном загрузки
	add_child(ui)
	var block := Control.new()           # ловит мышь: пока идёт ролик, мир не щёлкается и камера не крутится
	block.set_anchors_preset(Control.PRESET_FULL_RECT)
	block.mouse_filter = Control.MOUSE_FILTER_STOP
	block.gui_input.connect(_on_block_input)
	ui.add_child(block)
	var veil := ColorRect.new()          # затемнение (ролик, начатый позже)
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
	# табличка: «Новый ранг города», под ним орёл и красная лента с названием ранга
	var head := VBoxContainer.new()
	head.anchor_left = 0.5
	head.anchor_right = 0.5
	head.offset_left = -300
	head.offset_right = 300
	head.alignment = BoxContainer.ALIGNMENT_BEGIN
	head.add_theme_constant_override("separation", 0)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.modulate.a = 0.0
	block.add_child(head)
	cine["head"] = head
	var kick := Label.new()
	kick.text = "НОВЫЙ РАНГ ГОРОДА"
	kick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kick.add_theme_font_override("font", hud.font_title)
	kick.add_theme_font_size_override("font_size", 22)
	kick.add_theme_color_override("font_color", Color("ffe7a8"))
	kick.add_theme_color_override("font_outline_color", Color("3a2412"))
	kick.add_theme_constant_override("outline_size", 6)
	head.add_child(kick)
	var psz := Vector2(560, 148)
	var plate := TextureRect.new()
	plate.texture = load(Hud.AI + "plate.png")
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.custom_minimum_size = psz
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(plate)
	var name_lbl := Label.new()
	name_lbl.text = String(Defs.LEVELS[int(cine["to"])]["name"])
	name_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	# лента на картинке: x 0.33…0.91, y 0.29…0.71
	name_lbl.offset_left = psz.x * 0.335
	name_lbl.offset_right = -psz.x * 0.095
	name_lbl.offset_top = psz.y * 0.27
	name_lbl.offset_bottom = -psz.y * 0.3
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	name_lbl.add_theme_font_override("font", hud.font_title)
	name_lbl.add_theme_font_size_override("font_size", 40)
	name_lbl.add_theme_color_override("font_color", Hud.C_CREAM)
	name_lbl.add_theme_color_override("font_outline_color", Color("4a120c"))
	name_lbl.add_theme_constant_override("outline_size", 8)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(name_lbl)
	# подпись в нижней полосе: что дал новый ранг
	var sub := Label.new()
	sub.anchor_right = 1.0
	sub.anchor_top = 1.0 - BAR
	sub.anchor_bottom = 1.0
	sub.offset_left = 280
	sub.offset_right = -280
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_override("font", hud.font_bold)
	sub.add_theme_font_size_override("font_size", 19)
	sub.add_theme_color_override("font_color", Color("fff3dc"))
	sub.modulate.a = 0.0
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(sub)
	cine["sub"] = sub
	var skip := Button.new()
	skip.text = "Пропустить  ›"
	skip.flat = true
	skip.focus_mode = Control.FOCUS_NONE
	skip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	skip.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip.anchor_left = 1.0
	skip.anchor_right = 1.0
	skip.anchor_top = 1.0 - BAR
	skip.anchor_bottom = 1.0
	skip.offset_left = -260
	skip.offset_right = -30
	skip.add_theme_font_override("font", hud.font_title)
	skip.add_theme_font_size_override("font_size", 20)
	for s in ["font_color", "font_focus_color"]:
		skip.add_theme_color_override(s, Color(1.0, 0.94, 0.82, 0.62))
	for s in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		skip.add_theme_color_override(s, Color("ffe7a8"))
	skip.pressed.connect(_skip)
	block.add_child(skip)
	cine["skip"] = skip
	_bars(0.0)


func _bars(k: float) -> void:
	var h := get_viewport().get_visible_rect().size.y * BAR * k
	(cine["bar_top"] as Control).offset_bottom = h
	(cine["bar_bot"] as Control).offset_top = -h
	(cine["skip"] as Control).modulate.a = k
	var head: Control = cine["head"]
	head.offset_top = h + 18.0 + _head_dy
	head.offset_bottom = head.offset_top + 190.0


func _title_in() -> void:
	var head: Control = cine["head"]
	_head_dy = -12.0
	var tw := head.create_tween().set_parallel(true)
	tw.tween_property(head, "modulate:a", 1.0, 0.35)
	tw.tween_property(self, "_head_dy", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _title_out() -> void:
	for key in ["head", "sub"]:
		var n: Control = cine[key]
		if n.modulate.a > 0.0:
			n.create_tween().tween_property(n, "modulate:a", 0.0, 0.35)


func _say() -> void:
	cine["said"] = true
	var sub: Label = cine["sub"]
	sub.text = _say_text()
	sub.create_tween().tween_property(sub, "modulate:a", 1.0, 0.6)


## Подпись — из данных (уровни, исследования, пределы), чтобы не врала после правок баланса
func _say_text() -> String:
	var from: int = cine["from"]
	var to: int = cine["to"]
	var out := []
	if to - from >= 2:
		var ranks := []
		for l in range(from + 1, to + 1):
			ranks.append(String(Defs.LEVELS[l]["name"]))
		out.append("Город прошёл сразу %d %s: %s." % [to - from, Hud._plural(to - from, "ранг", "ранга", "рангов"), _join(ranks)])
	var rh := float(Defs.LEVELS[to].get("rp_h", 0.0))
	if rh > 0.0:
		out.append("Станция выросла — почта привозит %s в час." % _scrolls(rh))
	var names := []
	for r in Defs.RESEARCH:
		if int(r["lvl"]) > from and int(r["lvl"]) <= to:
			names.append(String(r["name"]))
	if names.size() > 3:
		out.append("Открылись исследования: %s и ещё\u00a0%d." % [", ".join(names.slice(0, 3)), names.size() - 3])
	elif not names.is_empty():
		out.append("Открылись исследования: %s." % _join(names))
	var mx: Array = Defs.B["scriptorium"].get("max", [])
	if not mx.is_empty():
		out.append("Скрипториев можно держать:\u00a0%d." % int(mx[mini(to, mx.size() - 1)]))
	out.append("Казна вмещает %s\u00a0ден." % hud.fmt(game.city.money_cap_for(to)))
	return " ".join(out)


## «1,5 свитка», «2 свитка», «5 свитков» (число не отрывается от слова при переносе)
static func _scrolls(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		var n := int(roundf(v))
		return "%d\u00a0%s" % [n, Hud._plural(n, "свиток", "свитка", "свитков")]
	return "%s\u00a0свитка" % String.num(v, 1).replace(".", ",")


## «А», «А и Б», «А, Б и В»
static func _join(a: Array) -> String:
	if a.size() <= 1:
		return "" if a.is_empty() else String(a[0])
	return ", ".join(a.slice(0, a.size() - 1)) + " и " + String(a[-1])


## После хутора и деревни советник объясняет, что теперь можно и что дальше
func _advise(to: int) -> void:
	if to < 1 or to >= AS_NAME.size() or to >= Defs.LEVELS.size() - 1:
		return
	var tut = game.tutorial
	if tut != null and tut.active():
		return
	var t := ""
	var mx: Array = Defs.B["scriptorium"].get("max", [])
	if not mx.is_empty():
		var n := int(mx[mini(to, mx.size() - 1)])
		if ORD.has(n) and n > int(mx[mini(to - 1, mx.size() - 1)]):
			t += "Теперь можно поставить %s скрипторий — исследования пойдут быстрее. " % ORD[n]
	var names := []
	for id in PICK:
		for r in Defs.RESEARCH:
			if r["id"] == id and int(r["lvl"]) == to:
				names.append("«%s»" % r["name"])
	for r in Defs.RESEARCH:
		if names.size() >= 3:
			break
		if int(r["lvl"]) == to and not (r["id"] in PICK):
			names.append("«%s»" % r["name"])
	if not names.is_empty():
		t += "В свитке исследований вверху справа открылись %s и другие." % ", ".join(names)
	var nx: Dictionary = Defs.LEVELS[to + 1]
	if to == 1:
		t += "\n\nСледующий уровень — «%s»: %d жителей и счастье от %d%%." % [nx["name"], int(nx["pop"]), int(nx["happy"])]
	else:
		t += "\n\nДальше город растёт спокойнее: следующий уровень — «%s», ему нужно %d жителей и счастье от %d%%." % [nx["name"], int(nx["pop"]), int(nx["happy"])]
	hud.advisor("Город стал %s!" % AS_NAME[to], t)
