extends Node
## Название города против сервера НА ЭТОМ КОМПЬЮТЕРЕ (никогда не живой): проверка сама запускает node server/index.js
## (порт 3016, данные — .work/srvtest_name, стираются), заводит две учётки и играет новую игру (город сохраняется
## в папку проверки gpu_run):
##   bash .work/py/gpu_run.sh res://test_city_name.tscn [-- out=D:/CivCity/.work/gd node=путь/к/node.exe]
## Проверяет: имя с сервера само встаёт на табличку (Легиона ещё нет); советник один раз зовёт назвать город;
## табличка — курсор-рука и подсказка «Щёлкните — назвать город»; щелчок — окно «Название города»; занятое имя —
## текст сервера (409), окно открыто; грубое — отказ сразу (сервер тоже отказывает и «двойникам» букв); без входа
## и без связи — честная причина и «Повторить», ничего не меняется; «Повторить» со связью — сохранено: табличка,
## city.name, me.name, сохранение на диске, подпись для облака; длинное имя — мельче; Легион: кнопка «Имя» открывает
## то же окно (Esc закрывает только его), переименование оттуда, таблица лучших — с новым именем; «Сохранить» с тем же
## именем ставит его на табличку (город, загруженный со старым именем); новая игра в той же сессии — имя с сервера на
## табличке и в подписи ролика сразу, без ожидания. Фильтр грубых слов — те же примеры, что у сервера
## (server/names_cases.json). Снимки: name_tip, name_hover, name_modal, name_409, name_rude, name_nologin, name_offline,
## name_renamed, name_long, name_legion_modal, name_legion_after, name_top, name_newgame. В конце «NAME DONE fails=N».

const PORT := 3016
const API := "http://127.0.0.1:3016/api"
const DATA := "D:/CivCity/.work/srvtest_name"
var game
var out := "D:/CivCity/.work/gd"
var node_exe := "node"
var fails := 0
var srv_pid := -1


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out":
			out = kv[1]
		if kv.size() == 2 and kv[0] == "node":
			node_exe = kv[1]
	DirAccess.make_dir_recursive_absolute(out)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func secs(t: float) -> void:
	await get_tree().create_timer(t).timeout


func check(name: String, ok: bool, extra = null) -> void:
	if not ok:
		fails += 1
	print(("ok   " if ok else "FAIL ") + name + ("" if ok or extra == null else "  " + str(extra)))


func until(cond: Callable, limit: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > limit * 1000.0:
			return false
		await frames(2)
	return true


func move(p: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	Input.parse_input_event(m)
	await frames(3)


func click(p: Vector2) -> void:
	await move(p)
	for pressed: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = p
		e.global_position = p
		e.button_index = MOUSE_BUTTON_LEFT
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		e.pressed = pressed
		Input.parse_input_event(e)
		await frames(3)


func key(k: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.physical_keycode = k
		ev.pressed = down
		Input.parse_input_event(ev)
		await frames(2)
	await frames(3)


func center_of(c: Control) -> Vector2:
	return c.get_viewport().get_final_transform() * (c.get_global_transform_with_canvas() * (c.size / 2.0))


func shot(name: String) -> void:
	await frames(8)
	var p := "%s/%s.png" % [out, name]
	get_viewport().get_texture().get_image().save_png(p)
	print("shot ", p)


func http(method: int, path: String, body = null, token := "") -> Dictionary:
	return await NetHttp.fetch(self, API, method, path, body, token, {"timeout": 5.0})


func finish() -> void:
	if srv_pid > 0:
		OS.kill(srv_pid)
	print("NAME DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


# ---------- сервер на этом компьютере ----------

func start_server() -> bool:
	DirAccess.make_dir_recursive_absolute(DATA)
	for f in DirAccess.get_files_at(DATA):
		DirAccess.remove_absolute(DATA.path_join(f))
	OS.set_environment("PORT", str(PORT))
	OS.set_environment("DATA_DIR", DATA)
	OS.set_environment("ORIGINS", "*")
	OS.set_environment("SMTP_HOST", "")
	OS.set_environment("SMTP_PASS", "")
	srv_pid = OS.create_process(node_exe, ["--disable-warning=ExperimentalWarning", ProjectSettings.globalize_path("res://").path_join("../server/index.js").simplify_path()])
	if srv_pid <= 0:
		print("FAIL сервер не запустился (node: %s)" % node_exe)
		return false
	NetHttp.test_timeout = 2.0
	for i in 40:
		var r := await http(HTTPClient.METHOD_GET, "/health")
		if int(r["status"]) == 200:
			return true
		await secs(0.25)
	print("FAIL сервер на %s не отвечает" % API)
	return false


func register(mail: String) -> String:
	var r := await http(HTTPClient.METHOD_POST, "/register", {"email": mail, "password": "secret-" + mail.get_slice("@", 0), "consent": true})
	return String((r["data"] as Dictionary).get("token", ""))


# ---------- проверка ----------

## Фильтр грубых слов в игре — на тех же примерах, что у сервера (server/test_pvp.js)
func rude_cases() -> void:
	var path := ProjectSettings.globalize_path("res://").path_join("../server/names_cases.json").simplify_path()
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary):
		check("примеры грубых слов: %s" % path, false)
		return
	var miss := (d["bad"] as Array).filter(func(s): return not CityName.rude(String(s)))
	var wrong := (d["good"] as Array).filter(func(s): return CityName.rude(String(s)))
	check("фильтр в игре = на сервере: %d грубых пойманы, %d обычных проходят" % [(d["bad"] as Array).size(), (d["good"] as Array).size()],
		miss.is_empty() and wrong.is_empty(), {"miss": miss, "wrong": wrong})


func _run() -> void:
	rude_cases()
	if not await start_server():
		finish()
		return
	var stamp := int(Time.get_unix_time_from_system()) % 100000
	var tok_a := await register("name-a-%d@test.local" % stamp)
	var tok_b := await register("name-b-%d@test.local" % stamp)
	check("две учётки на сервере проверки", tok_a != "" and tok_b != "")
	var name_b := "Капуя %d" % stamp
	var rb := await http(HTTPClient.METHOD_PUT, "/pvp/name", {"name": name_b}, tok_b)
	check("B назвал город «%s» (без Легиона)" % name_b, int(rb["status"]) == 200 and String(rb["data"]["me"]["name"]) == name_b, rb)
	var rr := await http(HTTPClient.METHOD_PUT, "/pvp/name", {"name": "XYЙ"}, tok_a)
	check("сервер не берёт грубое имя из латинских «двойников» (400)", int(rr["status"]) == 400 and String(rr["error"]) == CityName.MSG_RUDE, rr)

	# новая игра; вход — учётка A (Account без окна входа: игра внутри проверки)
	var save := GamePaths.save_dir().path_join("city.json")
	if FileAccess.file_exists(save):
		DirAccess.remove_absolute(save)
	var acc := Account.me()
	var net := LegionNet.me()
	acc.api = API
	acc.token = tok_a
	net.force_on = true
	Game.boot = {"new": "1", "hour": "10.5"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	while not game.ready_done:
		await frames(5)
	await frames(20)
	var hud: Hud = game.hud
	var c: City = game.city
	var plate: TextureRect = hud.name_plate
	check("пока сервер не ответил — «Новый Рим»", c.name == "" and hud.lbl_city.text == CityName.PLACEHOLDER, [c.name, hud.lbl_city.text])
	check("подпись ролика без имени — «ваш город»", game.tutorial.intro_line(0) == "Первые переселенцы прибыли в ваш город!", game.tutorial.intro_line(0))

	# имя с сервера приходит само (Легиона нет) и встаёт на табличку
	var got := await until(func(): return c.name != "", 20.0)
	var srv_name := String(net.me_state.get("name", ""))
	check("имя с сервера пришло без Легиона: «%s»" % srv_name, got and srv_name != "" and c.name == srv_name and hud.lbl_city.text == srv_name and
		not bool(net.me_state.get("custom", true)) and bool(net.me_state.get("rename", false)), [c.name, hud.lbl_city.text, net.me_state])
	check("подпись для облака — то же имя", acc.city_name() == srv_name, acc.city_name())

	# совет: один раз, когда на экране ничего нет
	hud.advisor_panel.visible = false                # приветствие новой игры
	hud.refresh()
	await frames(6)
	check("советник зовёт назвать город", hud.advisor_panel.visible and hud.adv_title.text == "Как назовём город?" and
		hud.adv_text.text.contains("щёлкните по табличке") and c.tips.has("name_tip"), [hud.adv_title.text])
	await shot("name_tip")
	hud.advisor_panel.visible = false
	hud.refresh()
	await frames(4)
	check("совет — только один раз", not hud.advisor_panel.visible)

	# табличка: рука, подсказка, подсветка
	await move(center_of(plate))
	await secs(1.3)
	check("над табличкой — курсор-рука и подсказка «Щёлкните — назвать город»", plate.mouse_filter == Control.MOUSE_FILTER_STOP and
		plate.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND and plate.tooltip_text == "Щёлкните — назвать город" and
		get_viewport().gui_get_hovered_control() == plate, get_viewport().gui_get_hovered_control())
	await shot("name_hover")

	# щелчок — окно
	await click(center_of(plate))
	await frames(6)
	var w := CityName.window(hud)
	check("щелчок по табличке открыл окно «Название города»", w != null)
	if w == null:
		finish()
		return
	var field := w.find_child("field", true, false) as LineEdit
	var err := w.find_child("error", true, false) as Label
	var save_btn := w.find_child("save", true, false) as Button
	check("в поле — нынешнее имя", field.text == srv_name, field.text)
	await shot("name_modal")

	# занятое имя — текст сервера, окно открыто
	field.text = name_b
	await click(center_of(save_btn))
	await until(func(): return err.text != "", 15.0)
	check("занятое имя: «%s»" % err.text, err.text == "Такое название уже занято — придумайте другое" and CityName.window(hud) != null and
		hud.lbl_city.text == srv_name and c.name == srv_name, [err.text, hud.lbl_city.text])
	await shot("name_409")

	# грубое — отказ сразу (Enter в поле); и корень, разорванный дефисом («Сохранить»)
	for bad in ["Х у й", "Пиз-дец"]:
		err.text = ""
		field.text = bad
		if bad == "Х у й":
			field.grab_focus()
			await key(KEY_ENTER)
		else:
			await click(center_of(save_btn))
		check("грубое имя «%s» — отказ сразу: «%s»" % [bad, err.text], err.text == CityName.MSG_RUDE and String(net.me_state.get("name", "")) == srv_name and
			CityName.window(hud) != null)
	await shot("name_rude")

	# без входа — причина и «Повторить»
	acc.token = ""
	field.text = "Аквилея Новая"
	await click(center_of(save_btn))
	await until(func(): return err.text != "", 5.0)
	check("без входа: причина и «Повторить»", err.text.contains("войдите") and save_btn.text == "Повторить" and c.name == srv_name, [err.text, save_btn.text])
	await shot("name_nologin")
	acc.token = tok_a

	# без связи — причина, код, «Повторить»; ничего не меняется
	acc.api = "http://127.0.0.1:9/api"
	err.text = ""
	await click(center_of(save_btn))
	await until(func(): return err.text != "" and not save_btn.disabled, 20.0)
	var code := w.find_child("code", true, false) as Label
	check("без связи: «%s» + «Повторить»" % err.text, err.text.contains("не отвечает") and save_btn.text == "Повторить" and code.visible and
		c.name == srv_name and hud.lbl_city.text == srv_name and String(net.me_state.get("name", "")) == srv_name, [err.text, save_btn.text, code.text])
	await shot("name_offline")

	# связь вернулась — «Повторить» сохраняет
	acc.api = API
	await click(center_of(save_btn))
	var done := await until(func(): return CityName.window(hud) == null, 15.0)
	var nm1 := "Аквилея Новая"
	check("«Повторить» со связью: окно закрылось, табличка «%s»" % hud.lbl_city.text, done and hud.lbl_city.text == nm1 and c.name == nm1 and
		String(net.me_state.get("name", "")) == nm1 and bool(net.me_state.get("custom", false)), [hud.lbl_city.text, net.me_state])
	var saved := FileAccess.get_file_as_string(save)
	var sd = JSON.parse_string(saved)
	check("город сохранён с новым именем (city.json name)", sd is Dictionary and String(sd.get("name", "")) == nm1, sd.get("name") if sd is Dictionary else saved.length())
	check("подпись для облака — новое имя", acc.city_name() == nm1)
	var st := await http(HTTPClient.METHOD_GET, "/pvp/state", null, tok_a)
	check("на сервере — новое имя", String(st["data"]["me"]["name"]) == nm1, st["data"])
	await move(Vector2(800, 500))
	await shot("name_renamed")

	# город со старым именем (загрузили прежнее сохранение): «Сохранить» с тем же именем ставит имя сервера на табличку
	c.name = "Старый Рим"
	hud.show_city_name()
	await click(center_of(plate))
	await frames(6)
	w = CityName.window(hud)
	check("в поле — имя с сервера, не старое из сохранения", w != null and (w.find_child("field", true, false) as LineEdit).text == nm1)
	if w != null:
		await click(center_of(w.find_child("save", true, false) as Button))
		await frames(4)
	check("«Сохранить» с тем же именем: окно закрылось, табличка «%s»" % hud.lbl_city.text, CityName.window(hud) == null and
		hud.lbl_city.text == nm1 and c.name == nm1, [hud.lbl_city.text, c.name])

	# длинное имя — мельче, целиком в ленте
	var keep := c.name
	c.name = "Колония Аврелия Августа"
	hud.show_city_name()
	await frames(3)
	var fs := hud.lbl_city.get_theme_font_size("font_size")
	var tw := hud.font_title.get_string_size(c.name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	check("длинное имя — шрифт %d, ширина %d из %d" % [fs, int(tw), int(hud.lbl_city.size.x)], fs < Hud.CITY_FONT and tw <= hud.lbl_city.size.x, [fs, tw])
	await shot("name_long")
	c.name = keep
	hud.show_city_name()
	check("обычное имя — снова крупно", hud.lbl_city.get_theme_font_size("font_size") == Hud.CITY_FONT)

	# Легион: кнопка «Имя» — то же окно
	c.level = 6
	c.research["legion"] = true
	c.research["archery"] = true
	c.money = 18000.0
	var spots := [Vector2(150, 205), Vector2(166, 205)]
	var i := 0
	for t in ["barracks", "range"]:
		c.place(t, spots[i], 0.0, 0, -1, true)
		i += 1
	var lg: Legion = c.legion
	lg.progress = 6
	lg.levels = {"legionary": 4, "archer": 3}
	lg._ensure()
	lg.squad = ["legionary", "archer", "legionary"]
	lg.flags["tut"] = "done"
	lg.flags["seen"] = true
	lg.flags["advised"] = true
	c.changed.emit()
	hud.advisor_panel.visible = false
	await frames(10)
	var ui := LegionUi.of(hud)
	ui.open("pvp")
	await until(func(): return ui._pvp_state == "ok" or ui._pvp_state == "error", 20.0)
	await frames(10)
	check("вкладка «Против городов» открылась", ui.visible and ui._pvp_state == "ok", [ui._pvp_state, ui._pvp_err])
	var me_lbl := ui.content.find_children("*", "Label", true, false).filter(func(l): return (l as Label).text == "Ваш город в боях: «%s»" % nm1)
	check("«Ваш город в боях» — то же имя", not me_lbl.is_empty())
	var rb2 := ui.content.find_child("RenameCity", true, false) as Button
	check("кнопка «Имя» есть", rb2 != null and not rb2.disabled)
	if rb2 == null:
		finish()
		return
	await click(center_of(rb2))
	await frames(6)
	w = CityName.window(hud)
	check("«Имя» в Легионе открыло то же окно «Название города»", w != null and (w.find_child("field", true, false) as LineEdit).text == nm1)
	await shot("name_legion_modal")
	(w.find_child("field", true, false) as LineEdit).grab_focus()
	await key(KEY_ESCAPE)
	check("Esc закрыл только окно названия (Легион открыт)", CityName.window(hud) == null and ui.visible)
	# переименовать из Легиона
	await click(center_of(rb2))
	await frames(6)
	w = CityName.window(hud)
	var nm2 := "Аквилея Великая"
	(w.find_child("field", true, false) as LineEdit).text = nm2
	await click(center_of(w.find_child("save", true, false) as Button))
	await until(func(): return CityName.window(hud) == null, 15.0)
	await frames(10)
	var me_lbl2 := ui.content.find_children("*", "Label", true, false).filter(func(l): return (l as Label).text == "Ваш город в боях: «%s»" % nm2)
	check("из Легиона: табличка и «Ваш город в боях» — «%s»" % nm2, hud.lbl_city.text == nm2 and c.name == nm2 and not me_lbl2.is_empty(), hud.lbl_city.text)
	await shot("name_legion_after")
	# таблица лучших — с новым именем (отряд обороны уже на сервере: у A нет города в облаке, сверять не с чем)
	LegionPvpView.top(ui)
	await until(func(): return ui.overlay != null and ui.overlay.find_children("*", "ScrollContainer", true, false).size() > 0, 15.0)
	await frames(8)
	var rows := ui.overlay.find_children("*", "Label", true, false).filter(func(l): return (l as Label).text == nm2 + "  (вы)") if ui.overlay != null else []
	check("в таблице лучших — «%s  (вы)»" % nm2, not rows.is_empty())
	await shot("name_top")
	ui._close_overlay()
	ui.close()

	# новая игра в той же сессии (LegionNet переживает перезапуск): имя с сервера — на табличке и в ролике сразу
	game.can_save = false
	game.queue_free()
	await frames(4)
	if FileAccess.file_exists(save):
		DirAccess.remove_absolute(save)
	Game.boot = {"new": "1", "hour": "10.5"}
	net._busy = true                                   # пока смотрим — без запросов к серверу (имя только из памяти)
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	while not game.ready_done:
		await frames(5)
	await frames(3)
	hud = game.hud
	check("новая игра: табличка сразу «%s» (сервер ещё не спрошен)" % hud.lbl_city.text, hud.lbl_city.text == nm2 and game.city.name == nm2 and
		acc.city_name() == nm2 and net._state_t < 0.0, [hud.lbl_city.text, game.city.name, net._state_t])
	check("новая игра: подпись ролика — «%s»" % game.tutorial.intro_line(0), game.tutorial.intro_line(0) == "Первые переселенцы прибыли в город «%s»!" % nm2)
	net._busy = false
	var asked := await until(func(): return net._state_t > 0.0, 15.0)
	check("новая игра: свежее состояние спрошено сразу, не через 5 минут", asked and hud.lbl_city.text == nm2)
	await frames(10)
	await shot("name_newgame")
	finish()
