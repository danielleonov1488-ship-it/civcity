extends Node
## «Вышла новая версия для Mac» (scripts/mac_update.gd) против своего маленького сервера на этом компьютере
## (127.0.0.1, отвечает тут же, из проверки; живой сайт не трогаем):
##   bash .work/py/gpu_run.sh res://test_mac_update.tscn   — в конце «MACUPD DONE fails=0»; снимки — .work/gd/a/mac/macupd_*.png
## Своя сборка — 10. На сайте min 12 → окно во весь экран, «Играть» не срабатывает, «Скачать новую версию» открывает
## адрес из файла, «Выйти» есть; build 12, min 9 → тихая строка в меню (ведёт туда же), окна нет; build 10 → ничего;
## нет связи, 404, не JSON, сервер молчит, чужой адрес в url → играть можно (молчание — не дольше тайм-аута + 1 с,
## чужой адрес заменяется страницей civcity.ru/mac/).

const SHOTS := "D:/CivCity/.work/gd/a/mac/"
const OUR := 10

var fails := 0
var srv := TCPServer.new()
var port := 0
var conns := []                                   # [StreamPeerTCP, принятый запрос]
var game


func check(ok: bool, what: String, extra = null) -> bool:
	print(("MACUPD PASS " if ok else "MACUPD FAIL ") + what + ("" if ok or extra == null else "  " + str(extra)))
	if not ok:
		fails += 1
	return ok


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	await frames(6)
	DirAccess.make_dir_recursive_absolute(SHOTS)
	get_viewport().get_texture().get_image().save_png(SHOTS + name)
	print("SHOT ", SHOTS + name)


# ---------- свой сервер: ответ по пути запроса ----------

func _reply(path: String) -> Array:
	match path:
		"/blocked.json":
			return [200, '{"build": 12, "min": 12, "url": "https://civcity.ru/download/CivCity-mac-12.zip", "size": 1}']
		"/quiet.json":
			return [200, '{"build": 12, "min": 9, "url": "https://civcity.ru/download/CivCity-mac-12.zip"}']
		"/same.json":
			return [200, '{"build": 10, "min": 10, "url": "https://civcity.ru/download/CivCity-mac-10.zip"}']
		"/evil.json":
			return [200, '{"build": 12, "min": 12, "url": "https://example.com/not-ours.zip"}']
		"/bad.json":
			return [200, 'это не JSON']
		"/slow.json":
			return []                              # молчим
	return [404, '{"error": "нет такого"}']


func _process(_dt: float) -> void:
	while srv.is_listening() and srv.is_connection_available():
		conns.append([srv.take_connection(), ""])
	for c: Array in conns:
		var t: StreamPeerTCP = c[0]
		t.poll()
		if t.get_status() != StreamPeerTCP.STATUS_CONNECTED or c[1] == "done" or c[1] == "slow":
			continue
		var n := t.get_available_bytes()
		if n > 0:
			c[1] += t.get_utf8_string(n)
		if not String(c[1]).contains("\r\n\r\n"):
			continue
		var path := String(c[1]).get_slice("\r\n", 0).get_slice(" ", 1)
		var r := _reply(path)
		if r.is_empty():
			c[1] = "slow"
			continue
		var body := String(r[1]).to_utf8_buffer()
		var head := "HTTP/1.1 %d %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [r[0], "OK" if r[0] == 200 else "Not Found", body.size()]
		t.put_data(head.to_utf8_buffer())
		t.put_data(body)
		c[1] = "done"


func _ready() -> void:
	for p in range(18431, 18531):
		if srv.listen(p, "127.0.0.1") == OK:
			port = p
			break
	check(port > 0, "свой сервер на 127.0.0.1:%d" % port)
	# как в собранной игре: проверку начинают из _ready главной сцены, пока корень расставляет детей (раньше тут
	# add_child не срабатывал, и запуск на Mac падал)
	MacUpdate.test_url = base() + "/same.json"
	MacUpdate.test_build = OUR
	MacUpdate.test_timeout = 2.0
	MacUpdate.check_at_start()
	_run()


func base() -> String:
	return "http://127.0.0.1:%d" % port


## Новая проверка с нуля (как новый запуск игры): адрес, своя сборка, тайм-аут
func fresh(path: String, timeout := 2.0) -> MacUpdate:
	var old := MacUpdate._inst
	MacUpdate._inst = null
	if old != null and is_instance_valid(old):
		old.name = "MacUpdate_old_%d" % Time.get_ticks_usec()   # прежняя проверка ещё может посылать сигнал — убрать в конце кадра
		old.queue_free()
	MacUpdate.test_url = path if path.begins_with("http") else base() + path
	MacUpdate.test_build = OUR
	MacUpdate.test_timeout = timeout
	MacUpdate.test_opened = ""
	return MacUpdate.me()


## Только проверка, без игры: состояние, сколько ждали, нет окна
func alone(path: String, want: String, what: String, timeout := 2.0) -> MacUpdate:
	var m := fresh(path, timeout)
	var t0 := Time.get_ticks_msec()
	m.start()
	while m.state == "checking":
		await m.decided
	var ms := Time.get_ticks_msec() - t0
	var can: bool = await MacUpdate.allow_play()
	check(m.state == want and (want == "blocked") == (m.overlay != null) and can == (want != "blocked") and ms <= int((timeout + 1.5) * 1000.0),
		"%s → %s за %d мс, играть: %s" % [what, m.state, ms, "да" if can else "нет"], [m.state, m.why, m.overlay])
	return m


func start_menu() -> void:
	if game != null and is_instance_valid(game):
		game.queue_free()
		await frames(3)
	Game.boot = {"menu": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	while not game.ready_done:
		await frames(5)
	await frames(20)


func _run() -> void:
	await frames(5)
	var m0 := MacUpdate.me()
	while m0.state == "checking":
		await m0.decided
	check(m0.is_inside_tree() and m0.state == "ok", "проверка, начатая из _ready главной сцены, встала в дерево и дошла до конца", [m0.state, m0.is_inside_tree()])
	# ---------- без игры: все ответы сервера ----------
	check(MacUpdate.our_build() == 0 or MacUpdate.test_build >= 0, "своя сборка в редакторе неизвестна (нет res://mac_build.txt)", MacUpdate.our_build())
	await alone("/same.json", "ok", "та же сборка")
	await alone("/quiet.json", "newer", "сборка новее, но не обязательна")
	var m := await alone("/blocked.json", "blocked", "обязательная новая сборка")
	check(m.url == "https://civcity.ru/download/CivCity-mac-12.zip", "адрес скачивания — из файла", m.url)
	m = await alone("/evil.json", "blocked", "чужой адрес в url")
	check(m.url == MacUpdate.PAGE, "чужой адрес заменён страницей %s" % MacUpdate.PAGE, m.url)
	await alone("/bad.json", "failed", "ответ не JSON")
	await alone("/missing.json", "failed", "нет файла (404)")
	await alone("/slow.json", "failed", "сервер молчит", 1.0)
	var closed := port + 1
	var probe := TCPServer.new()
	while probe.listen(closed, "127.0.0.1") != OK:
		closed += 1
	probe.stop()
	await alone("http://127.0.0.1:%d/game/mac.json" % closed, "failed", "нет связи (порт закрыт)")
	MacUpdate.test_build = 0
	m = fresh("/blocked.json")
	MacUpdate.test_build = 0
	m.start()
	while m.state == "checking":
		await m.decided
	check(m.state == "ok" and m.overlay == null, "своя сборка неизвестна (0) — ни окна, ни строки", m.state)

	# ---------- в игре: окно во весь экран ----------
	fresh("/blocked.json")
	await start_menu()
	m = MacUpdate.me()
	while m.state == "checking":
		await m.decided
	await frames(5)
	check(m.state == "blocked" and m.overlay != null and m.overlay.layer > game.hud.layer, "в меню — окно «скачайте новую версию» поверх всего", [m.state, m.overlay])
	var labels: Array = m.overlay.find_children("*", "Label", true, false)
	var texts := labels.map(func(l): return (l as Label).text)
	check(texts.has(MacUpdate.BLOCK_TITLE), "текст окна: «%s»" % MacUpdate.BLOCK_TITLE, texts)
	var go: Button = m.overlay.find_child("download", true, false)
	var out: Button = m.overlay.find_child("quit", true, false)
	check(go != null and go.text == "Скачать новую версию" and out != null and out.text == "Выйти", "кнопки «Скачать новую версию» и «Выйти»")
	await shot("macupd_blocked.png")
	game.hud._menu_go("new")
	await frames(30)
	check(game.mode == "menu" and is_instance_valid(game) and game.hud.menu_root.find_children("*", "Label", true, false).all(func(l): return (l as Label).text != "Загрузка…"),
		"«Играть» при устаревшей сборке не срабатывает")
	go.pressed.emit()
	check(MacUpdate.test_opened == "https://civcity.ru/download/CivCity-mac-12.zip", "«Скачать новую версию» открывает адрес из файла", MacUpdate.test_opened)
	# клавиши под окном в игру не идут (Esc, пробел)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await frames(3)
	check(m.overlay != null and m.overlay.visible, "Esc окно не закрывает")
	m.overlay.queue_free()
	m.overlay = null

	# ---------- в игре: тихая строка в меню ----------
	fresh("/quiet.json")
	await start_menu()
	m = MacUpdate.me()
	while m.state == "checking":
		await m.decided
	await frames(5)
	var line: LinkButton = game.hud.menu_root.get_node_or_null("mac_update")
	check(m.state == "newer" and line != null and line.is_visible_in_tree() and line.text == MacUpdate.LINE_TEXT and m.overlay == null,
		"сборка новее — тихая строка «%s» в меню, окна нет" % MacUpdate.LINE_TEXT, [m.state, line])
	var can: bool = await MacUpdate.allow_play()
	check(can, "с тихой строкой играть можно")
	await shot("macupd_quiet.png")
	if line:
		line.pressed.emit()
	check(MacUpdate.test_opened == "https://civcity.ru/download/CivCity-mac-12.zip", "строка ведёт на скачивание", MacUpdate.test_opened)

	# ---------- в игре: нет связи — меню как обычно ----------
	fresh("http://127.0.0.1:%d/game/mac.json" % closed)
	await start_menu()
	m = MacUpdate.me()
	while m.state == "checking":
		await m.decided
	await frames(5)
	check(m.state == "failed" and m.overlay == null and game.hud.menu_root.get_node_or_null("mac_update") == null, "нет связи — меню как обычно, без окна и строки", m.state)
	MacUpdate.test_url = ""
	MacUpdate.test_build = -1
	print("MACUPD DONE fails=%d" % fails)
	get_tree().quit()
