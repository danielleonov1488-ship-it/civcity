class_name QaDrive
extends Node
## Автопроверка СОБРАННОЙ игры без человека (тестовые сцены в сборку не попадают). Работает только с аргументом
## --qa=…; в обычной игре attach() сразу выходит и ничего не создаёт.
##   CivCity.exe -- --menu --qa=login   --qa_mail=… --qa_pass=… [--qa_reg=1] --qa_out=DIR
##        меню: окно входа → (вкладка «Регистрация») → почта и пароль → «Войти» → «Играть» → новый город:
##        дорога и дома → сохранить → в облако → выход через «Выход» (как игрок)
##   CivCity.exe -- --menu --qa=restore --qa_mail=… --qa_pass=… --qa_expect=N --qa_out=DIR
##        пустая папка сохранений: вход → город скачан из облака → «Играть» → в городе N построек
##   CivCity.exe -- --menu --qa=legion --qa_out=DIR    (сессия от лаунчера: CIVCITY_SESSION)
##        «Играть» → город из облака → медальон «Легион» → «В бой!» → ×3 и «Авто» → итог → «В лагерь» → выход
## Печатает строки «QA …» (в журнал godot.log), снимки — в qa_out. Последняя строка: «QA DONE fails=N».

const PacksScript := preload("res://scripts/packs.gd")

static var _inst: QaDrive = null
static var _checked := false

var args := {}
var game = null
var out := ""
var fails := 0
var _started := false


static func attach(g) -> void:
	if not _checked:
		_checked = true
		var a := {}
		for s in OS.get_cmdline_user_args():
			var kv := s.trim_prefix("--").split("=", true, 1)
			a[kv[0]] = kv[1] if kv.size() > 1 else "1"
		if not a.has("qa"):
			return
		_inst = QaDrive.new()
		_inst.name = "QaDrive"
		_inst.args = a
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_inst)
	if _inst != null:
		_inst.game = g


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	out = str(args.get("qa_out", ""))
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
	print("QA start scenario=", args.get("qa"), " version=", ProjectSettings.get_setting("application/config/version", ""), " packs_missing=", PacksScript.missing)
	var t := get_tree().create_timer(float(args.get("qa_timeout", "420")), true, false, true)
	t.timeout.connect(func():
		print("QA FAIL timeout")
		print("QA DONE fails=", fails + 1)
		get_tree().quit(4))
	match str(args.get("qa")):
		"login":
			_login_flow()
		"restore":
			_restore_flow()
		"legion":
			_legion_flow()
		_:
			print("QA FAIL unknown scenario")
			_done()


# ---------- помощники ----------

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(what: String, ok: bool) -> bool:
	print(("QA ok   " if ok else "QA FAIL ") + what)
	if not ok:
		fails += 1
	return ok


func shot(n: String) -> void:
	await frames(3)
	if out == "":
		return
	var p := out.path_join(n + ".png")
	get_viewport().get_texture().get_image().save_png(p)
	print("QA shot ", p)


func _g():
	return game if game != null and is_instance_valid(game) else null


## Ждать, пока игра на сцене в одном из режимов и готова (после «Играть» сцена создаётся заново)
func wait_mode(modes: Array, sec: float, not_this = null) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000.0:
		var g = _g()
		if g != null and g != not_this and g.ready_done and g.mode in modes:
			return true
		await frames(5)
	return false


func wait_until(cond: Callable, sec: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000.0:
		if cond.call():
			return true
		await frames(5)
	return false


func center_of(c: Control) -> Vector2:
	return c.get_viewport().get_final_transform() * (c.get_global_transform_with_canvas() * (c.size / 2.0))


## Настоящий щелчок мышью по середине кнопки (через Input, как у игрока)
func click(c: Control) -> void:
	var p := center_of(c)
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	Input.parse_input_event(m)
	await frames(3)
	for pressed: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = p
		e.global_position = p
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		Input.parse_input_event(e)
		await frames(3)


func find_button(root: Node, text: String) -> Button:
	if root == null:
		return null
	for b in root.find_children("*", "Button", true, false):
		var bt := b as Button
		if bt.is_visible_in_tree() and not bt.disabled and bt.text.strip_edges() == text:
			return bt
	return null


func _done() -> void:
	print("QA DONE fails=", fails)
	await frames(2)
	get_tree().quit(0 if fails == 0 else 1)


func _city_line(g) -> String:
	var c = g.city
	return "buildings=%d pop=%d day=%d money=%d level=%d" % [c.buildings.size(), int(c.stats.get("pop", 0)), int(c.day), int(c.money), int(c.level)]


## Окно входа в меню: почта, пароль, «Войти»/«Создать аккаунт» — щелчками
func _sign_in(register: bool) -> bool:
	if not await wait_mode(["menu"], 120.0):
		return check("меню открылось", false)
	await frames(30)
	var acc := Account.me()
	var lg: Control = acc.ui._login if acc.ui and is_instance_valid(acc.ui) else null
	check("в меню окно входа вместо кнопок", lg != null and is_instance_valid(lg) and lg.visible)
	if lg == null:
		return false
	await shot("01_login")
	if register:
		var tab := lg.find_child("tab_reg", true, false) as Button
		if tab:
			await click(tab)
			await frames(6)
	var em := lg.find_child("email", true, false) as LineEdit
	var pw := lg.find_child("pass", true, false) as LineEdit
	var go := lg.find_child("go", true, false) as Button
	if not check("поля входа на месте", em != null and pw != null and go != null):
		return false
	em.text = str(args.get("qa_mail", ""))
	pw.text = str(args.get("qa_pass", ""))
	await click(go)
	var ok := await wait_until(func(): return acc.signed_in(), 25.0)
	check("вошли (%s)" % ("регистрация" if register else "вход"), ok)
	if not ok:
		var err := lg.find_child("err", true, false) as Label if is_instance_valid(lg) else null
		print("QA login error: ", err.text if err else "?")
		await shot("01_login_failed")
		return false
	await wait_until(func(): return acc.synced or acc.net == "offline" or acc.net == "old", 25.0)
	await frames(20)
	print("QA account net=", acc.net, " synced=", acc.synced, " cloud_save=", acc.cloud_save != null)
	await shot("02_signed_in")
	return true


## «Играть» в меню → город (новый или свой). Возвращает режим или ""
func _press_play() -> String:
	var g = _g()
	var b := find_button(g.hud.menu_root if g and g.hud else null, "Играть")
	if not check("кнопка «Играть» в меню", b != null):
		return ""
	await click(b)
	if not await wait_mode(["new", "play"], 120.0, g):
		check("город открылся после «Играть»", false)
		return ""
	await frames(60)
	return str(_g().mode)


func _quit_like_player() -> void:
	# «Выход» = Account.quit_game(): город уходит в облако, потом выход (как кнопка в меню и крестик окна)
	var g = _g()
	if g and g.can_save:
		g.save()
	var acc := Account.me()
	await acc._upload_wait(12.0)
	check("город в облаке (ничего не ждёт отправки)", not acc.pending())
	print("QA cloud base=", acc.cloud.get("base"), " net=", acc.net)
	await _done()


# ---------- сценарии ----------

func _login_flow() -> void:
	if not await _sign_in(args.has("qa_reg")):
		await _done()
		return
	var m := await _press_play()
	if m == "":
		await _done()
		return
	check("новый город (режим new)", m == "new")
	var g = _g()
	var c = g.city
	# дорога от станции и дома вдоль неё — как первые шаги игрока
	g.land.paint_line(Vector2(185, 104), Vector2(185, 136), 1.3, Land.Kind.ROAD, true)
	g.people.refresh(g.land.road_chunks.keys())
	var n := 0
	for z in range(112, 136, 2):
		for side in [-4.0, 4.0]:
			if n >= 3:
				break
			var pl: Dictionary = g.placement("house_pleb", Vector2(185 + side, z))
			if pl["err"] == "":
				c.place("house_pleb", pl["pos"], pl["yaw"], pl["variant"], pl["color"])
				n += 1
	g.rig.set_view(Vector3(186, 2, 116), 20, 48, 46)
	await frames(90)
	check("поставлены 3 дома", n == 3)
	print("QA city ", _city_line(g))
	await shot("03_new_city")
	await _quit_like_player()


func _restore_flow() -> void:
	if not await _sign_in(false):
		await _done()
		return
	var acc := Account.me()
	check("город скачан из облака в пустую папку", FileAccess.file_exists(GamePaths.save_dir().path_join("city.json")))
	var m := await _press_play()
	if m == "":
		await _done()
		return
	check("свой город (режим play)", m == "play")
	var g = _g()
	print("QA city ", _city_line(g))
	if args.has("qa_expect"):
		check("в городе %s построек, как в облаке" % args["qa_expect"], g.city.buildings.size() == int(args["qa_expect"]))
	await shot("03_restored")
	print("QA account net=", acc.net, " synced=", acc.synced)
	await _quit_like_player()


func _legion_flow() -> void:
	if not await wait_mode(["menu"], 120.0):
		check("меню открылось", false)
		await _done()
		return
	var acc := Account.me()
	await wait_until(func(): return acc.synced or acc.net == "offline", 25.0)
	check("сессия лаунчера: вошли без окна входа", acc.signed_in() and acc.launcher)
	await frames(20)
	await shot("01_menu")
	var m := await _press_play()
	if m == "":
		await _done()
		return
	var g = _g()
	print("QA city ", _city_line(g))
	var lg: Legion = g.city.legion
	var ui := LegionUi.of(g.hud)
	check("медальон «Легион» виден", ui != null and ui.btn_wrap.visible)
	if ui == null:
		await _done()
		return
	await click(ui.btn)
	await frames(20)
	check("окно «Легион» открылось щелчком", ui.visible)
	await shot("02_legion_window")
	var fight := find_button(ui, "В бой!")
	if fight == null:
		fight = find_button(ui, "Повторить бой")
	if not check("кнопка «В бой!»", fight != null):
		await _done()
		return
	var p0: int = lg.progress
	var closed := []
	lg.battle_closed.connect(func(o): closed.append(o))
	await click(fight)
	var opened := await wait_until(func(): return LegionBattle.current != null, 10.0)
	check("3D-бой открылся", opened)
	if not opened:
		await _done()
		return
	var b: LegionBattle = LegionBattle.current
	await wait_until(func(): return b.phase == "fight", 30.0)
	await frames(30)
	var x3 := find_button(b, "×3")
	if x3:
		await click(x3)
	var auto := find_button(b, "Авто")
	if auto and not auto.button_pressed:
		await click(auto)
	await frames(240)
	await shot("03_battle")
	var res := await wait_until(func(): return b.phase == "result", 200.0)
	check("бой закончился, экран итога", res)
	await frames(60)
	await shot("04_result")
	var back := find_button(b, "В лагерь")
	if check("кнопка «В лагерь»", back != null):
		await click(back)
	await wait_until(func(): return not closed.is_empty(), 15.0)
	check("бой закрылся, город вернулся", not closed.is_empty() and LegionBattle.current == null and g.hud.visible)
	var o: Dictionary = closed[0] if not closed.is_empty() else {}
	print("QA battle win=", o.get("win"), " alive=", o.get("alive"), "/", o.get("total"), " reward=", o.get("reward"), " progress ", p0, "->", lg.progress)
	await frames(60)
	await shot("05_after")
	# «Против городов»: отряд обороны уходит на сервер, список соперников (живые города и «вольные»)
	if ui.visible and ui.tabs.has("pvp"):
		await click(ui.tabs["pvp"])
		var listed := await wait_until(func(): return find_button(ui, "Напасть") != null, 20.0)
		check("«Против городов»: список соперников с сервера", listed)
		await frames(20)
		await shot("06_pvp")
	await _quit_like_player()
