class_name PhotoMode
extends Node
## Режим фото (клавиша P или кнопка «Фото» вверху справа), как в Town to City: интерфейс прячется, камеру можно
## опустить к самой земле и наклонить почти до горизонта, выбрать время суток и размытие, пойти следом за жителем
## (щелчком по нему, кнопкой «За жителем» или «Герой») и сохранить снимок PNG в папку «Снимки» рядом с сохранениями.
## Выйти — P, Esc или кнопкой. После выхода камера, свет и интерфейс — как были. Без звуков (в интерфейсе — только монетки).

const DIR_NAME := "Снимки"
const BLUR_GAME := 0.19                # «Размытие» по умолчанию — как миниатюра в игре (CameraRig: 0,09)
const FOLLOW_DIST := 6.0               # за жителем — близко, чуть сверху, цель на уровне груди
const FOLLOW_PITCH := 14.0
const FOLLOW_LIFT := 0.85

var game
var on := false
var root: Control                      # своё: панель режима и вспышка (интерфейс игры при этом спрятан)
var bar: PanelContainer
var sl_pitch: HSlider
var sl_time: HSlider
var sl_blur: HSlider
var lbl_time: Label
var btn_follow: Button
var btn_next: Button
var btn_hero: Button
var lbl_saved: Label
var btn_folder: Button
var row_saved: HBoxContainer           # строка «Снимок сохранён…» — только после снимка
var hint: Control
var flash: ColorRect
var last_file := ""
var follow_rid := -1                   # за каким жителем идёт камера (-1 — ни за кем; кошка — follow_cat)
var follow_cat := {}
var _hidden: Array = []                # [узел, был ли виден] — интерфейс до режима фото
var _look0 := -1.0                     # свет «как в час» до режима фото (обычно −1 — по часам игры)
var _cam0: Array = []                  # камера до режима фото: [цель, поворот, наклон, даль — куда ведёт; и где сейчас]
var _fps0 := false
var _last := Vector3.INF               # где был тот, за кем идём, в прошлый кадр (куда он идёт)
var _dir := Vector2.ZERO
var _snapping := false
var _gone_t := 0.0                     # сколько секунд того, за кем идём, не видно (зашёл в дом)
var _raised := false                   # камера сама поднялась над крышами (низко — стены): опустится, когда станет видно
var _rng := RandomNumberGenerator.new()     # свой случай: выбор жителя не трогает случай города
var snaps := 0                         # сколько снимков за игру (проверки)


func _ready() -> void:
	_rng.seed = 7
	if game.rig:
		game.rig.follow_ended.connect(_on_follow_ended)


func toggle() -> void:
	if on:
		close()
	else:
		open()


func open() -> void:
	if on or game == null or game.mode == "menu" or game.rig == null or game.rig.cine or game.hud == null:
		return
	var hud = game.hud
	if root == null:
		_build()
	game.set_tool("")
	hud.set_overlay("")
	hud._close_tray()
	hud.close_panels()
	game.select_building({})
	game._clear_highlight()
	game.rig.stop_follow()
	var rg: CameraRig = game.rig
	_cam0 = [rg._target_t, rg._yaw_t, rg._pitch_t, rg._dist_t, rg.target, rg.yaw, rg.pitch, rg.dist]
	# весь интерфейс игры — прочь (окна, значки над домами, подписи); своё — видно
	_hidden = []
	for ch in hud.get_children():
		if ch is CanvasItem and ch != root:
			_hidden.append([ch, (ch as CanvasItem).visible])
			(ch as CanvasItem).visible = false
	_plot_borders(false)
	if game.gfx and game.gfx.get("_fps_box") != null and is_instance_valid(game.gfx._fps_box):
		_fps0 = game.gfx._fps_box.visible
		game.gfx._fps_box.visible = false
	_look0 = game.look_hour
	game.people.outline_off = true
	hud.hidden_ui = true                       # подсветка домов, рожицы, ролик ранга «ждёт, пока игрок свободен»
	on = true
	game.rig.set_photo(true)
	var low := Gfx.is_low(str(game.settings.get("quality", "high")))
	game.rig.blur = 0.0 if low else BLUR_GAME
	sl_blur.set_value_no_signal((0.0 if low else BLUR_GAME) * 100.0)
	sl_pitch.min_value = game.rig.pitch_min()
	sl_pitch.set_value_no_signal(game.rig.pitch_deg())
	sl_time.set_value_no_signal(game.look_hour if game.look_hour >= 0.0 else game.hour)
	_time_label()
	lbl_saved.text = ""
	btn_folder.visible = false
	row_saved.visible = false
	_follow_buttons()
	root.visible = true
	# подсказка — один раз за город
	var c: City = game.city
	if c != null and not c.tips.has("photo_tip"):
		c.tips["photo_tip"] = true
		hint.visible = true
		hint.modulate.a = 1.0
		var tw := hint.create_tween()
		tw.tween_interval(12.0)
		tw.tween_property(hint, "modulate:a", 0.0, 1.0)
		tw.tween_callback(func(): hint.visible = false)
	else:
		hint.visible = false


func close() -> void:
	if not on:
		return
	on = false
	game.hud.hidden_ui = false
	_stop_follow()
	game.rig.set_photo(false)
	if _cam0.size() == 8:
		# камера — туда, где была до режима фото (плывёт назад); поворот — ближним путём, без лишнего круга
		var rg: CameraRig = game.rig
		rg._target_t = _cam0[0]
		rg._yaw_t = rg.yaw + angle_difference(rg.yaw, float(_cam0[1]))
		rg._pitch_t = _cam0[2]
		rg._dist_t = _cam0[3]
		if rg.cine:                            # уже идёт ролик: сразу — он вернётся к прежнему виду, а не к снимку
			rg.target = _cam0[4]
			rg.yaw = _cam0[5]
			rg._yaw_t = _cam0[1]
			rg.pitch = _cam0[6]
			rg.dist = _cam0[7]
	_cam0 = []
	game.people.outline_off = false
	if game.people.focus_rid != 0:
		game.people.set_focus(0)
	if not game.people.focus_cat.is_empty():
		game.people.set_focus_cat({})
	game.look_hour = _look0
	game._set_hour(game.hour)
	for e: Array in _hidden:
		if is_instance_valid(e[0]):
			(e[0] as CanvasItem).visible = bool(e[1])
	_hidden = []
	_plot_borders(true)
	if game.gfx and game.gfx.get("_fps_box") != null and is_instance_valid(game.gfx._fps_box):
		game.gfx._fps_box.visible = _fps0
	root.visible = false


## Клавиши в режиме фото (game._unhandled_input): true — клавиша взята
func key(k: InputEventKey) -> bool:
	match k.keycode:
		KEY_P, KEY_ESCAPE:
			close()
			return true
		KEY_F12, KEY_ENTER, KEY_KP_ENTER:
			snap()
			return true
		KEY_SPACE, KEY_1, KEY_2, KEY_3:
			return false                       # пауза и скорость — как в игре
	return true                                # остальное (инструменты, снос, отмена) в режиме фото не действует


## Щелчок по миру в режиме фото: по жителю (кошке) — камера идёт за ним
func click(mp: Vector2) -> void:
	var sel: Dictionary = game.people.pick(mp)
	if sel.has("r"):
		follow_person(int((sel["r"] as Dictionary)["id"]))
	elif sel.has("cat"):
		_follow_cat(sel["cat"])


# ---------- следом за жителем ----------

## Житель на улице поближе к середине кадра (из нескольких ближних — случайный, не тот же)
func pick_walker() -> int:
	var t: Vector3 = game.rig.target
	var list := []
	for r in game.people.residents:
		var n = r["node"]
		if n == null or not is_instance_valid(n) or not (n as Node3D).is_visible_in_tree() or float(r["fade"]) < 0.5:
			continue
		if String(r["state"]) != "walk" or int(r["id"]) == follow_rid:
			continue
		var p := (n as Node3D).global_position
		list.append([Vector2(p.x - t.x, p.z - t.z).length_squared(), int(r["id"])])
	if list.is_empty():
		return -1
	list.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	return int(list[_rng.randi() % mini(4, list.size())][1])


func follow_person(rid: int) -> bool:
	var ppl: People = game.people
	if rid < 0 or not ppl.by_id.has(rid):
		return false
	_stop_follow()
	follow_rid = rid
	ppl.set_focus(rid)                         # рисуется всегда (без обводки: outline_off)
	game.rig.start_follow(func():
		var r: Dictionary = ppl.by_id.get(rid, {})
		return ppl.person_pos(r) if not r.is_empty() else null)
	_follow_camera()
	return true


func _follow_cat(ct: Dictionary) -> void:
	var ppl: People = game.people
	_stop_follow()
	follow_cat = ct
	ppl.set_focus_cat(ct)
	game.rig.start_follow(func():
		return ppl.cat_pos(ct) if ppl.cats.has(ct) else null)
	_follow_camera()
	game.rig.lift = 0.25


func _follow_camera() -> void:
	game.rig.set_dist(FOLLOW_DIST)
	game.rig.set_pitch_deg(FOLLOW_PITCH)
	game.rig.lift = FOLLOW_LIFT
	sl_pitch.set_value_no_signal(FOLLOW_PITCH)
	_raised = false
	_last = Vector3.INF
	_dir = Vector2.ZERO
	_follow_buttons()


## Герой (Д11), если он есть в этой сборке и городе
func hero_rid() -> int:
	var hr = game.people.get("hero_r")
	if typeof(hr) == TYPE_DICTIONARY and not (hr as Dictionary).is_empty() and game.people.by_id.has(int(hr.get("id", -1))):
		return int(hr["id"])
	return -1


func _stop_follow() -> void:
	var was := follow_rid >= 0 or not follow_cat.is_empty()
	follow_rid = -1
	follow_cat = {}
	if was:
		game.rig.stop_follow()
	if game.people.focus_rid != 0:
		game.people.set_focus(0)
	if not game.people.focus_cat.is_empty():
		game.people.set_focus_cat({})
	game.rig.lift = 0.0
	if root:
		_follow_buttons()


## Камеру сдвинули сами (WASD, правая кнопка) — камера больше не идёт следом
func _on_follow_ended() -> void:
	if not on or (follow_rid < 0 and follow_cat.is_empty()):
		return
	follow_rid = -1
	follow_cat = {}
	game.rig.lift = 0.0
	if game.people.focus_rid != 0:
		game.people.set_focus(0)
	if not game.people.focus_cat.is_empty():
		game.people.set_focus_cat({})
	_follow_buttons()


func _process(dt: float) -> void:
	if not on:
		return
	if game.rig == null or game.rig.cine:
		close()                                # начался ролик (новый ранг, повозка) — режим фото уступает
		return
	if not sl_pitch.has_focus() and absf(sl_pitch.value - game.rig.pitch_deg()) > 0.5:
		sl_pitch.set_value_no_signal(game.rig.pitch_deg())     # повернули средней кнопкой
	if follow_rid >= 0 and not game.people.by_id.has(follow_rid):
		_stop_follow()                         # житель уехал из города
	if follow_rid < 0 and follow_cat.is_empty():
		return
	# житель зашёл в дом или лавку — через полторы секунды камера идёт за другим (за героем — ждёт у двери)
	if follow_rid >= 0 and follow_rid != hero_rid():
		var r: Dictionary = game.people.by_id.get(follow_rid, {})
		var nd = r.get("node")
		var seen: bool = nd != null and is_instance_valid(nd) and (nd as Node3D).is_visible_in_tree() and float(r.get("fade", 0.0)) > 0.3
		_gone_t = 0.0 if seen else _gone_t + dt
		if _gone_t > 1.5:
			_gone_t = 0.0
			var nx := pick_walker()
			if nx >= 0:
				follow_person(nx)
			return
	# камера — сзади-сбоку от того, за кем идём; там стена дома — заходим с другой стороны
	var f = game.rig.follow.call() if game.rig.follow.is_valid() else null
	if not (f is Vector3):
		return
	var p: Vector3 = f
	if _last.is_finite() and dt > 0.0:
		var v := Vector2(p.x - _last.x, p.z - _last.z) / dt
		if v.length() > 0.3:
			_dir = _dir.lerp(v.normalized(), clampf(dt * 3.0, 0.0, 1.0))
	_last = p
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		_raised = false
		return                                 # игрок сам поворачивает камеру
	var moving := _dir.length() >= 0.2
	var look: Vector3 = p + Vector3(0, game.rig.lift, 0)
	var base: float = atan2(-_dir.x, -_dir.y) - 0.5 if moving else game.rig.yaw
	var pd: float = game.rig.pitch_deg()
	# поднимались над крышами, а теперь и низко видно — опускаемся обратно к жителю
	if _raised and pd > FOLLOW_PITCH and _clear(look, base, FOLLOW_PITCH):
		_raised = false
		_set_pitch(FOLLOW_PITCH)
		pd = FOLLOW_PITCH
	if not moving and _clear(look, base, pd):
		return                                 # стоит у прилавка — камера там, где была, если не за стеной
	var want := _turn(look, base, pd)
	if want == INF:
		# кругом стены и крыши — смотрим сверху, пока луч до жителя не пройдёт над ними
		for pu: float in [35.0, 50.0, 65.0]:
			if pu > pd:
				want = _turn(look, base, pu)
				if want != INF:
					_raised = true
					_set_pitch(pu)
					break
	if want == INF:
		want = base
		if pd < 35.0:
			_raised = true
			_set_pitch(35.0)
	game.rig.turn_to(want, dt * (1.5 if moving else 4.0))


## Поворот камеры около base, откуда при наклоне pitch_d тот, за кем идём, виден (INF — ниоткуда)
func _turn(look: Vector3, base: float, pitch_d: float) -> float:
	for da: float in [0.0, 0.7, -0.7, 1.4, -1.4, 2.2, -2.2, PI]:
		if _clear(look, base + da, pitch_d):
			return base + da
	return INF


func _set_pitch(deg: float) -> void:
	game.rig.set_pitch_deg(deg)
	sl_pitch.set_value_no_signal(deg)


## От того, за кем идём (look — куда смотрит камера), до камеры (поворот a, наклон pitch_d, даль — как сейчас) луч
## идёт над постройками: верхушка постройки под лучом ниже него — и на полметра по бокам (угол дома не срежет кадр);
## сама камера не вплотную к стене
func _clear(look: Vector3, a: float, pitch_d: float) -> bool:
	var d: float = game.rig.dist * CameraRig.K
	var pr := deg_to_rad(pitch_d)
	var dir := Vector2(sin(a), cos(a))
	var side := Vector2(dir.y, -dir.x) * 0.6
	for k: float in [0.2, 0.35, 0.5, 0.65, 0.8, 0.9, 1.0, 1.1]:
		var q := Vector2(look.x, look.z) + dir * d * cos(pr) * k
		var y := look.y + d * sin(pr) * k
		if _solid(q, y) or _solid(q + side, y) or _solid(q - side, y):
			return false
	return true


## Постройка в точке q выше высоты y (украшения не в счёт)
func _solid(q: Vector2, y: float) -> bool:
	var id: int = game.land.occ_at(q)
	if id < 0:
		return y < Land.BASE_Y + 9.0           # арка у въезда
	var b: Dictionary = game.city.buildings.get(id, {})
	if b.is_empty() or String(game.city.def(b)["kind"]) == "decor":
		return false
	return float(b["y"]) + game.city.blueprint(b).top_y() + 0.3 > y


# ---------- снимок ----------

## Снимок кадра без панели режима: PNG в «Снимки» рядом с сохранениями. Путь к файлу ("" — не вышло)
func snap() -> String:
	if not on or _snapping:
		return ""
	_snapping = true
	root.visible = false
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var dir := photo_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(file_name())
	var n := 2
	while FileAccess.file_exists(path):
		path = dir.path_join(file_name(" (%d)" % n))
		n += 1
	var err := img.save_png(path)
	_snapping = false
	if not on:
		return path if err == OK else ""
	root.visible = true
	if err == OK:
		snaps += 1
		last_file = path
		lbl_saved.text = "Снимок сохранён: %s/%s" % [DIR_NAME, path.get_file()]
		btn_folder.visible = true
		row_saved.visible = true
		flash.visible = true
		flash.color.a = 0.55
		var tw := flash.create_tween()
		tw.tween_property(flash, "color:a", 0.0, 0.4)
		tw.tween_callback(func(): flash.visible = false)
		return path
	lbl_saved.text = "Снимок не сохранился — нет доступа к папке"
	row_saved.visible = true
	return ""


## Папка снимков — рядом с сохранениями игры (в её данных, не где попало на диске)
static func photo_dir() -> String:
	return GamePaths.save_dir().path_join(DIR_NAME)


## «Город 2026-10-26 14-03-22.png»: название города без знаков, которых не бывает в именах файлов
func file_name(suffix := "") -> String:
	var nm := ""
	var src := String(game.city.name) if game.city != null else ""
	for ch in src:
		if ch == " " or ch == "-" or ch == "_" or ch.to_upper() != ch.to_lower() or ch.is_valid_int():
			nm += ch
	nm = nm.strip_edges()
	if nm == "":
		nm = "CivCity"
	var t := Time.get_datetime_dict_from_system()
	return "%s %04d-%02d-%02d %02d-%02d-%02d%s.png" % [nm, t["year"], t["month"], t["day"], t["hour"], t["minute"], t["second"], suffix]


# ---------- панель режима ----------

func _build() -> void:
	var hud = game.hud
	root = Control.new()
	root.name = "PhotoUi"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = hud.theme_main
	root.visible = false
	hud.add_child(root)
	flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1, 0.98, 0.92, 0.0)
	flash.visible = false
	root.add_child(flash)
	bar = hud._panel(root, "bar", 0, 8)
	hud._put(bar, Control.PRESET_CENTER_BOTTOM, Vector2(0, -12))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	bar.add_child(v)
	# ряд 1: наклон, время суток, размытие
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 10)
	r1.add_child(hud._icon("photo", 26, hud.C_SOFT))
	r1.add_child(hud._label("Фото", 20, false, hud.C_INK, hud.font_title))
	sl_pitch = _slider(r1, "Наклон", 2.0, 80.0, 1.0, "Наклон камеры: от взгляда сверху до самой земли (средняя кнопка мыши — тоже)",
		func(x: float):
			_raised = false                    # наклон выбрал игрок — сама камера его не меняет обратно
			game.rig.set_pitch_deg(x))
	sl_time = _slider(r1, "Время суток", 0.0, 24.0, 0.25, "Свет как в этот час (часы города идут как шли)", _set_time)
	lbl_time = hud._label("12:00", 15, true, hud.C_SOFT)
	lbl_time.custom_minimum_size = Vector2(44, 0)
	r1.add_child(lbl_time)
	sl_blur = _slider(r1, "Размытие", 0.0, 100.0, 1.0, "Глубина резкости: резко там, куда смотрит камера, мягко ближе и дальше",
		func(x: float): game.rig.blur = x / 100.0)
	v.add_child(r1)
	# ряд 2: за жителем, герой, снимок, выйти
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 8)
	r2.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_follow = _btn(r2, "За жителем", "Камера пойдёт следом за жителем на улице (или щёлкните по любому жителю)", func():
		if follow_rid >= 0 or not follow_cat.is_empty():
			_stop_follow()
		else:
			follow_person(pick_walker()))
	btn_next = _btn(r2, "Другой житель", "Пойти за другим жителем поблизости", func(): follow_person(pick_walker()))
	btn_hero = _btn(r2, "Герой", "Камера пойдёт за вашим героем", func(): follow_person(hero_rid()))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(18, 0)
	r2.add_child(sp)
	var sb := _btn(r2, "Снимок  (F12)", "Сохранить кадр без интерфейса в папку «Снимки»", func(): snap())
	sb.add_theme_font_override("font", hud.font_bold)
	_btn(r2, "Выйти  (P)", "Вернуться к игре (P или Esc)", close)
	v.add_child(r2)
	# ряд 3: куда сохранилось
	var r3 := HBoxContainer.new()
	r3.add_theme_constant_override("separation", 8)
	r3.alignment = BoxContainer.ALIGNMENT_CENTER
	lbl_saved = hud._label("", 14, false, hud.C_SOFT)
	r3.add_child(lbl_saved)
	btn_folder = _btn(r3, "Открыть папку", "Показать снимок в папке", func():
		if last_file != "":
			OS.shell_show_in_file_manager(last_file))
	btn_folder.visible = false
	r3.visible = false
	row_saved = r3
	v.add_child(r3)
	# подсказка — над панелью, один раз за город
	var hp: PanelContainer = hud._chip(false, 12.0)
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp.add_child(hud._wrap(hud._label("Режим фото. Колёсико — ближе, средняя кнопка — повернуть и наклонить, правая кнопка или WASD — двигать. Щёлкните по жителю — камера пойдёт за ним. F12 — снимок, P или Esc — выйти.", 15, true, hud.C_INK), 560))
	root.add_child(hp)
	hud._put(hp, Control.PRESET_CENTER_BOTTOM, Vector2(0, -150))
	hint = hp
	hint.visible = false


func _slider(row: HBoxContainer, title: String, lo: float, hi: float, step: float, tip: String, cb: Callable) -> HSlider:
	var hud = game.hud
	var l: Label = hud._label(title, 15, true, hud.C_INK)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(130, 26)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_NONE
	s.tooltip_text = tip
	s.value_changed.connect(cb)
	row.add_child(s)
	return s


func _btn(row: HBoxContainer, text: String, tip: String, cb: Callable) -> Button:
	var hud = game.hud
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_stylebox_override("normal", hud._box_pill(14, 4))
	b.add_theme_stylebox_override("hover", hud._box_pill(14, 4, "g_btn_hover"))
	b.add_theme_stylebox_override("pressed", hud._box_pill(14, 4, "g_btn_on"))
	b.add_theme_stylebox_override("disabled", hud._box_pill(14, 4))
	b.custom_minimum_size = Vector2(0, 30)
	b.pressed.connect(cb)
	row.add_child(b)
	return b


func _set_time(h: float) -> void:
	game.look_hour = clampf(h, 0.0, 23.99)
	game._set_hour(game.hour)
	_time_label()


func _time_label() -> void:
	var h: float = sl_time.value
	lbl_time.text = "%02d:%02d" % [int(h) % 24, int(fposmod(h, 1.0) * 60.0)]


func _follow_buttons() -> void:
	var fol := follow_rid >= 0 or not follow_cat.is_empty()
	btn_follow.text = "Остановиться" if fol else "За жителем"
	btn_next.visible = fol and follow_cat.is_empty() and follow_rid != hero_rid()
	btn_hero.visible = hero_rid() >= 0
	btn_hero.disabled = follow_rid >= 0 and follow_rid == hero_rid()


## Золотые рамки участков на продажу — тоже интерфейс: в режиме фото прячем
func _plot_borders(vis: bool) -> void:
	for k in game.plot_signs:
		var s: Node = game.plot_signs[k]
		if is_instance_valid(s):
			var b := s.get_node_or_null("border")
			if b is Node3D:
				(b as Node3D).visible = vis
