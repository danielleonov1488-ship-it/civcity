class_name Account
extends Node
## Account.me() — вход в аккаунт CivCity и город в облаке. Как в браузерной версии: без входа не играем.
## Город у игрока один и живёт на сервере (ячейка rome2, отдельно от городов старой браузерной игры);
## на компьютере лежит его копия city.json. В облако город уходит после сохранений (не чаще раза в минуту)
## и при выходе из игры. Пропал интернет после входа — играем дальше, облако догонит.
##
## Откуда вход:
##  1) CIVCITY_SESSION = {"token", "email", "api"} — от программы запуска CivCity (она сама спрашивает почту и пароль);
##  2) иначе — свой вход в игре: токен лежит в папке сохранений в account.dat, зашифрованный ключом этого компьютера
##     (пароль нигде не хранится).
## Адрес сервера: --api=… или CIVCITY_API, иначе из CIVCITY_SESSION, иначе https://civcity.ru/api.
##
## Сверка при запуске (как в браузерной версии): у копии на компьютере есть хозяин (owner) и номер облачного
## сохранения, от которого она идёт (base). Чужой город не переезжает к другому игроку. Если город менялся и тут,
## и на другом компьютере, — игра спрашивает, какой оставить (близкие по размеру — берёт тот, что новее).
## Тесты и снимки (--shot, готовый город, игра внутри тестовой сцены, --nologin, CIVCITY_NOLOGIN=1) входа не просят.
## Один узел на всю игру (Account.me()) — висит прямо под корнем дерева и переживает перезапуск сцены
## (меню ↔ город): отправка в облако не обрывается. Не автозагрузка: имя автозагрузки не видно проверке скриптов.

signal changed                                  # вход, выход, связь с облаком — обновить надписи

const GAME := "rome2"                           # ячейка сохранений новой игры на сервере
const API_DEFAULT := "https://civcity.ru/api"
const SITE := "https://civcity.ru"
const UP_GAP := 60.0                            # в облако — не чаще раза в минуту (автосохранение — раз в полторы)
const RETRY_GAP := 60.0                         # нет связи — пробуем снова через минуту
const TIMEOUT := 20.0
const UP_TIMEOUT := 120.0
const QUIT_WAIT := 12.0                         # сколько ждать облака при выходе из игры
const SESSION_FILE := "account.dat"
const CLOUD_FILE := "cloud.json"
const ASIDE_FILE := "city_before_cloud.json"    # копия городка с компьютера, который заменили облачным

var api := API_DEFAULT
var email := ""
var token := ""
var launcher := false                           # вход дала программа запуска
var net := "idle"                               # idle | checking | online | offline | old (сервер ещё без ячейки rome2)
var synced := false                             # город сверен с облаком (можно отправлять)
var syncing := false
var cloud := {}                                 # owner, base, hash, up_at, destroy, api — хранится в cloud.json
var cloud_save = null                           # что сервер сказал о последнем сохранении
var game = null
var ui = null                                   # AccountUi текущего интерфейса
var force_on := false                           # тесты: вход нужен, даже если игра внутри тестовой сцены
var nologin := false
var test := ""                                  # --cloudtest=…
var test_shot := ""
var last_error := ""
var up_fail := ""                               # почему город не ушёл в облако (для надписи в настройках)
var last_net := ""                              # почему не дошёл последний запрос: dns | connect | tls | timeout | read ("" — дошёл)
var off_since := 0.0                            # с какого времени (unix) нет связи с сервером (0 — связь есть): значок «нет облака»
var off_told := false                           # советник уже сказал про связь (раз за запуск игры)

var _data := ""                                 # последнее сохранение города (строка) и его отпечаток
var _hash := ""
var _meta := {}
var _busy := false
var _last_status := 0                           # чем ответил сервер на последнюю отправку (0 — нет связи)
var _last_try := -1.0e9
var _last_sync := -1.0e9
var _ask_open := false                          # открыт вопрос «какой город оставить»
var _go_after := ""                             # после сверки сразу в игру (нажали «Играть»)
var _go_ok := false                             # следующий вход в игру — без проверок
var _quitting := false
var _test_frame := 0
## Номер входа: растёт при входе, выходе и потере входа. Ответ сервера, пришедший уже после смены аккаунта
## (медленная отправка города пережила выход), ничего не записывает — иначе город прежнего игрока стал бы «нашим»
var _gen := 0

static var _inst: Account = null


## Единственный узел аккаунта (создаётся при первом обращении, под корнем дерева)
static func me() -> Account:
	if _inst == null or not is_instance_valid(_inst):
		_inst = Account.new()
		_inst.name = "Account"
		(Engine.get_main_loop() as SceneTree).root.add_child(_inst)
	return _inst


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	nologin = args.has("nologin") or OS.get_environment("CIVCITY_NOLOGIN") == "1"
	test = str(args.get("cloudtest", ""))
	test_shot = str(args.get("cloudshot", ""))
	force_on = test != ""
	var env_api := str(args.get("api", OS.get_environment("CIVCITY_API"))).strip_edges()
	var sess = JSON.parse_string(OS.get_environment("CIVCITY_SESSION")) if OS.get_environment("CIVCITY_SESSION") != "" else null
	if typeof(sess) == TYPE_DICTIONARY and str(sess.get("token", "")) != "":
		token = str(sess["token"])
		email = str(sess.get("email", ""))
		launcher = true
		if str(sess.get("api", "")) != "":
			api = str(sess["api"])
	if env_api != "":
		api = env_api
	api = api.trim_suffix("/")
	if token == "":
		_load_session()
	_load_cloud()
	var t := Timer.new()
	t.wait_time = 5.0
	t.autostart = true
	t.timeout.connect(_tick)
	add_child(t)


# ---------- нужен ли вход ----------

func _g():
	return game if game != null and is_instance_valid(game) else null


## Игрок переносит постройку или дерево (Game.save() вернул бы её на место — как и автосохранение, ждём)
static func _carrying(g) -> bool:
	return not (g.moving as Dictionary).is_empty() or not (g.moving_nature as Dictionary).is_empty()


## Нужен ли вход для этой игры: тесты, снимки и готовый город — без входа
func required() -> bool:
	var g = _g()
	if g == null:
		return false
	if force_on:
		return true
	if nologin or g.shot_path != "" or g.promo or g.mode == "demo":
		return false
	return g.get_tree().current_scene == g          # игру встроили в тестовую сцену — это проверка, не игрок


func signed_in() -> bool:
	return token != ""


## Игра на сцене: меню, свой город или новый (вызывается в конце Game._ready)
func attach(g) -> void:
	game = g
	_ask_open = false
	_go_ok = false
	_test_frame = 0
	ui = null
	if not required():
		get_tree().set_auto_accept_quit(true)
		return
	get_tree().set_auto_accept_quit(false)          # окно закрывают — сначала отправим город в облако
	ui = AccountUi.for_hud(g.hud)
	if g.mode == "menu":
		ui.menu()
		if token != "" and not synced and not syncing:
			sync()
	elif g.mode == "play" or g.mode == "new":
		if token == "":
			g.can_save = false
			g.restart.call_deferred("menu")         # без входа играть нельзя — в меню, там окно входа
			return
		if not synced and not syncing:
			sync()
	changed.emit()


# ---------- вход и выход ----------

func login(mail: String, password: String, register: bool, consent := false) -> String:
	var body := {"email": mail.strip_edges(), "password": password}
	if register:
		body["consent"] = consent         # галочка согласия на обработку данных (сервер запоминает время)
	var r := await _call(HTTPClient.METHOD_POST, "/register" if register else "/login", body, false, TIMEOUT, false)
	if r["status"] == 0:
		return String(NetHttp.explain(r)["short"])    # настоящая причина, без «проверьте интернет»
	if r["status"] != 200:
		return str(r["error"])
	var d: Dictionary = r["data"]
	if str(d.get("token", "")) == "":
		return "Сервер ответил странно — попробуйте ещё раз"
	email = str(d.get("email", mail))
	token = str(d["token"])
	launcher = false
	_gen += 1
	_ask_open = false
	_store_session()
	synced = false
	net = "idle"
	sync()
	changed.emit()
	return ""


func forgot(mail: String) -> String:
	var r := await _call(HTTPClient.METHOD_POST, "/forgot", {"email": mail.strip_edges()}, false, TIMEOUT, false)
	if r["status"] == 0:
		return String(NetHttp.explain(r)["short"])
	if r["status"] != 200:
		return str(r["error"])
	return ""


## Выйти из аккаунта: город уходит в облако, потом окно входа в главном меню
func logout() -> void:
	var g = _g()
	if g and g.mode != "menu" and g.can_save and g.ready_done:
		g.save()
	if ui and is_instance_valid(ui):
		ui.busy("Сохраняем город в облаке…")
	await _upload_wait(QUIT_WAIT)
	if token != "":
		_call(HTTPClient.METHOD_POST, "/logout", {}, false, 8.0)             # заголовок с токеном собирается сразу; ответа не ждём
	_gen += 1                                       # запоздавший ответ на отправку города — уже не для этого входа
	token = ""
	launcher = false
	synced = false
	net = "idle"
	cloud_save = null
	_data = ""
	_hash = ""
	DirAccess.remove_absolute(_path(SESSION_FILE))
	changed.emit()
	g = _g()
	if g and g.mode != "menu":
		g.can_save = false
		g.restart("menu")
	elif ui and is_instance_valid(ui):
		ui.busy("")
		ui.menu()


func _session_lost() -> void:
	_go_after = ""
	_gen += 1
	_ask_open = false                               # окно входа заменит вопрос «какой город оставить» — после входа спросим снова
	token = ""
	launcher = false
	synced = false
	net = "idle"
	DirAccess.remove_absolute(_path(SESSION_FILE))
	changed.emit()
	if ui and is_instance_valid(ui):
		ui.login_modal("Вход устарел — войдите снова, чтобы город сохранялся в облаке.")


# ---------- сверка с облаком ----------

func sync() -> void:
	if syncing or token == "":
		return
	syncing = true
	var gen := _gen
	net = "checking"
	_last_sync = _now()
	changed.emit()
	await _sync_body()
	syncing = false
	if gen != _gen:
		# пока сверяли, вышли или вошли другим аккаунтом: эта сверка уже ни о чём — сверить заново нового
		changed.emit()
		if token != "" and not synced:
			sync.call_deferred()
		return
	if not synced and not _ask_open and token != "" and net == "online":
		net = "idle"                                # сверка не удалась (ответ с ошибкой) — _tick повторит её через минуту
	changed.emit()
	if _go_after != "":
		if synced or net == "offline" or net == "old":
			_go_now()
		elif not _ask_open and token != "":
			_go_after = ""                          # сверка не удалась (сервер ответил ошибкой) — сказать и не держать
			if ui and is_instance_valid(ui):
				ui.busy("")
				ui.message("Облако", last_error if last_error != "" else "Не получилось сверить город с облаком. Попробуйте ещё раз через минуту.")


func _sync_body() -> void:
	var g = _g()
	var gen := _gen
	if g and g.mode != "menu" and g.can_save and g.ready_done and not _carrying(g):
		g.save()                                    # сверяем то, что сейчас на экране (переносимую постройку не роняем)
	var r := await _call(HTTPClient.METHOD_GET, "/me?game=" + GAME)
	if gen != _gen:
		return                                      # пока ждали, сменился вход
	if r["status"] == 401:
		_session_lost()
		return
	if r["status"] != 200:
		net = "offline"                             # играем дальше, облако догонит
		last_error = str(r["error"])
		return
	last_error = ""
	var d: Dictionary = r["data"]
	if str(d.get("game", "")) != GAME:
		net = "old"                                 # сервер ещё не знает новую игру — в облако не пишем
		return
	net = "online"
	email = str(d.get("email", email))
	if launcher:
		_store_session()
	cloud_save = d.get("save")
	if bool(cloud.get("destroy", false)):
		var dr := await _send_destroy()
		if gen != _gen:
			return
		if bool(cloud.get("destroy", false)):
			return
		if dr == "conflict":
			cloud["destroy_ask"] = true
			_store_cloud()
	if bool(cloud.get("destroy_ask", false)):
		if str(cloud.get("owner", "")) in ["", email]:
			# уничтожали без связи, а город в облаке тем временем сохраняли с другого компьютера: не затираем — спросить
			_ask(_local(), cloud_save, "destroy")
			return
		cloud.erase("destroy_ask")                  # вопрос был для другого аккаунта этого компьютера
		_store_cloud()
	var local := _local()
	var act := _decide(local, cloud_save)
	g = _g()
	var playing: bool = g != null and g.mode != "menu"
	var foreign := str(cloud.get("owner", "")) != "" and str(cloud.get("owner", "")) != email
	if act == "take" and playing and not local.is_empty() and not foreign:
		act = "ask"                                 # свой город на экране не подменяем молча
	match act:
		"aside":
			_set_aside()
			cloud["owner"] = email
			cloud["base"] = null
			cloud["hash"] = ""
			_store_cloud()
			synced = true
			if playing:
				g.can_save = false
				g.restart("new")
		"take":
			await _take_cloud(playing)
		"keep":
			_adopt_local(local)
			synced = true
			_upload(true)
		"ok":
			_adopt_local(local)
			synced = true
		"ask":
			_ask(local, cloud_save, "start")


## Что делать с городом на компьютере (local) и в облаке (cs)
func _decide(local: Dictionary, cs) -> String:
	var foreign := str(cloud.get("owner", "")) != "" and str(cloud.get("owner", "")) != email
	if cs == null:
		return "aside" if foreign and not local.is_empty() else "keep"
	if foreign or local.is_empty():
		return "take"
	if cloud.get("base") != null and int(cloud["base"]) == int(cs["id"]):
		return "ok" if local["hash"] == str(cloud.get("hash", "")) else "keep"
	# в облаке что-то новое (другой компьютер, откат, уничтожение)
	if local["hash"] == str(cloud.get("hash", "")) or _fresh(local["meta"]):
		return "take"
	if bool(cs.get("destroyed", false)):
		return "ask"
	if _close(local["meta"], cs.get("meta") if typeof(cs.get("meta")) == TYPE_DICTIONARY else {}):
		return "take" if float(cs.get("created", 0)) / 1000.0 >= float(local["time"]) else "keep"
	return "ask"


## Город только начат — его не жалко заменить облачным
func _fresh(m: Dictionary) -> bool:
	return int(m.get("pop", 0)) == 0 and int(m.get("n", 0)) <= 1


## Города почти одинаковые — спрашивать незачем, берём более новый
func _close(a: Dictionary, b: Dictionary) -> bool:
	var pa := int(a.get("pop", 0))
	var pb := int(b.get("pop", 0))
	return absi(pa - pb) <= maxi(2, int(maxi(pa, pb) * 0.05)) and absi(int(a.get("day", 0)) - int(b.get("day", 0))) <= 1 \
		and absi(int(a.get("n", 0)) - int(b.get("n", 0))) <= 2


func _adopt_local(local: Dictionary) -> void:
	cloud["owner"] = email
	if not local.is_empty():
		_data = local["data"]
		_hash = local["hash"]
		_meta = local["meta"]
	_store_cloud()


## Взять город из облака: скачать, старую копию отложить, перезапустить игру, если она уже идёт
func _take_cloud(reload: bool) -> bool:
	var cs = cloud_save
	var local_exists := FileAccess.file_exists(_save_path())
	if cs != null and bool(cs.get("destroyed", false)):
		if local_exists:
			_set_aside()
		cloud["owner"] = email
		cloud["base"] = int(cs["id"])
		cloud["hash"] = ""
		_data = ""
		_hash = ""
		_store_cloud()
		synced = true
		var g0 = _g()
		if reload and g0:
			g0.can_save = false
			g0.restart("new")
		return true
	var gen := _gen
	var r := await _call(HTTPClient.METHOD_GET, "/save?game=" + GAME, null, false, UP_TIMEOUT)
	if gen != _gen:
		return false                                # пока скачивали, сменился вход — чужой город не кладём
	if r["status"] == 401:
		_session_lost()
		return false
	if r["status"] != 200 or str(r["data"].get("game", "")) != GAME:
		net = "offline" if r["status"] == 0 else net
		last_error = "Не получилось скачать город из облака — попробуем позже"
		return false
	var sv = r["data"].get("save")
	if sv == null:
		synced = true
		return true
	if bool(sv.get("destroyed", false)) or sv.get("data") == null:
		cloud_save = sv
		return await _take_cloud(reload)
	var s := str(sv["data"])
	var d = JSON.parse_string(s)
	if typeof(d) != TYPE_DICTIONARY or int(d.get("version", 1)) < 2:
		last_error = "Город в облаке повреждён — оставляем город с компьютера"
		push_warning("Account: облачный город не читается")
		cloud["base"] = int(sv["id"])               # город с компьютера заменит испорченный в облаке
		cloud["owner"] = email
		_store_cloud()
		synced = true
		return false
	if local_exists:
		_set_aside()
	var f := FileAccess.open(_save_path(), FileAccess.WRITE)
	if f == null:
		last_error = "Не получилось записать город на диск"
		return false
	f.store_string(s)
	f.close()
	cloud_save = sv
	cloud["owner"] = email
	cloud["base"] = int(sv["id"])
	cloud["hash"] = s.sha256_text()
	cloud["up_at"] = int(float(sv.get("created", 0)) / 1000.0)
	_data = s
	_hash = cloud["hash"]
	_meta = meta_of(d)
	_store_cloud()
	synced = true
	print("Account: город взят из облака (сохранение %d, построек %d)" % [int(sv["id"]), int(_meta.get("n", 0))])
	var g = _g()
	if reload and g:
		g.can_save = false
		g.restart("play")
	return true


## Отложить город с компьютера в city_before_cloud.json (его заменяет облачный или он чужой)
func _set_aside() -> void:
	var p := _save_path()
	if not FileAccess.file_exists(p):
		return
	var aside := _path(ASIDE_FILE)
	if FileAccess.file_exists(aside):
		DirAccess.remove_absolute(aside)
	DirAccess.rename_absolute(p, aside)


func _ask(local: Dictionary, cs, why: String) -> void:
	if _ask_open:
		return
	if ui == null or not is_instance_valid(ui):
		return
	_ask_open = true
	ui.ask_city(local.get("meta", {}), int(local.get("time", 0)), cs, why)


## Ответ на «какой город оставить»: cloud — взять облачный, иначе — оставить этот и отправить его в облако
func resolve(take_cloud: bool) -> void:
	_ask_open = false
	if cloud.has("destroy_ask"):
		cloud.erase("destroy_ask")                  # на вопрос после отменённого уничтожения ответили
		_store_cloud()
	var g = _g()
	var playing: bool = g != null and g.mode != "menu"
	if take_cloud:
		if not await _take_cloud(playing) and not synced:
			if net == "online":
				net = "idle"                        # через минуту сверим снова
			if ui and is_instance_valid(ui):
				ui.message("Облако", last_error if last_error != "" else "Не получилось скачать город из облака — попробуем позже.")
	else:
		_adopt_local(_local() if not playing else {"data": _data, "hash": _hash, "meta": _meta})
		synced = true
		if _data == "":
			# города на диске ещё нет (только что начат после «Уничтожить город»): его первая отправка пойдёт
			# поверх облачного (force) — иначе сервер снова ответил бы «в облаке новее» и вопрос повторился бы
			cloud["force_next"] = email
			_store_cloud()
		_upload(true)
	changed.emit()
	if _go_after != "":
		_go_now()


# ---------- в игру из меню ----------

## Можно ли сейчас начинать игру (кнопка «Играть»): нужен вход и сверка с облаком
func may_play(m: String) -> bool:
	if _go_ok:
		_go_ok = false
		return true
	if not required() or not (m == "play" or m == "new"):
		return true
	if token == "":
		if ui and is_instance_valid(ui):
			ui.menu()
		return false
	if _ask_open:
		return false
	if synced or net == "offline" or net == "old":
		_go_after = m
		_go_now()
		return false
	_go_after = m
	if not syncing:
		sync()
	if ui and is_instance_valid(ui):
		ui.busy("Сверяем город с облаком…")
	return false


func _go_now() -> void:
	_go_after = ""
	var g = _g()
	if g == null or g.mode != "menu" or g.hud == null:
		return
	if ui and is_instance_valid(ui):
		ui.busy("")
	_go_ok = true
	g.hud._menu_go("play" if FileAccess.file_exists(_save_path()) else "new")


# ---------- отправка города ----------

## Игра записала город на диск (Game.save) — запомнить и отправить в облако, когда подойдёт время
func after_save(s: String) -> void:
	var g = _g()
	if not required() or token == "":
		return
	_data = s
	_hash = s.sha256_text()
	if g and g.city:
		var c = g.city
		_meta = {"pop": int(c.stats.get("pop", 0)), "day": int(c.day), "level": int(c.level), "money": int(c.money), "n": c.buildings.size(),
			"city": city_name(), "v": str(ProjectSettings.get_setting("application/config/version", ""))}
	_tick()


func pending() -> bool:
	return _data != "" and _hash != str(cloud.get("hash", ""))


func _tick() -> void:
	if not required() or token == "" or _quitting:
		return
	if not synced:
		if not syncing and (net == "offline" or net == "idle") and _now() - _last_sync >= RETRY_GAP:
			var g = _g()
			if g and _carrying(g):
				return                              # сверка сохраняет город, а сохранение роняет переносимую постройку — после переноса
			_forget_address()
			sync()                                  # связь вернулась — сначала сверка, потом отправка
		return
	if _busy or _ask_open or net == "old" or not pending():
		return
	if _now() - _last_try >= (UP_GAP if net == "online" else RETRY_GAP):
		if net == "offline":
			_forget_address()
		_upload(false)


## Связи не было — забыть адрес сервера: VPN мог его поменять, а Godot помнит адреса до перезапуска игры
func _forget_address() -> void:
	if net == "offline" or off_since > 0.0:
		IP.clear_cache(NetHttp.host_of(api))


## Значок «нет связи с облаком» нажали — попробовать сразу, не дожидаясь минуты
func retry_now() -> void:
	if not required() or token == "" or _quitting:
		return
	IP.clear_cache(NetHttp.host_of(api))
	if not synced:
		if not syncing:
			var g = _g()
			if g == null or not _carrying(g):
				sync()
	elif not _busy and not _ask_open and net != "old" and pending():
		_upload(false)


func _upload(force: bool, quiet := false) -> void:
	if _busy or token == "" or _data == "":
		return
	var gen := _gen
	var who := email
	if bool(cloud.get("destroy", false)):
		_busy = true
		var dr := await _send_destroy()
		_busy = false
		if gen != _gen:
			return
		if dr == "conflict":
			# уничтожали без связи, а город в облаке сохраняли с другого компьютера — не затираем его, спросить
			cloud["destroy_ask"] = true
			_store_cloud()
			_last_status = 409
			if not quiet:
				_ask({"meta": _meta, "time": int(Time.get_unix_time_from_system())}, cloud_save, "destroy")
			changed.emit()
			return
		if bool(cloud.get("destroy", false)):
			_last_status = 0
			return
		force = true
	if bool(cloud.get("destroy_ask", false)):
		_last_status = 409                          # выход из игры не ждёт: сначала ответ на вопрос, какой город оставить
		if not quiet:
			_ask({"meta": _meta, "time": int(Time.get_unix_time_from_system())}, cloud_save, "destroy")
		return
	if str(cloud.get("force_next", "")) == who:
		force = true
	_busy = true
	_last_try = _now()
	var sent := _hash
	_meta["city"] = city_name()
	_meta["v"] = str(ProjectSettings.get_setting("application/config/version", ""))
	var body := {"data": _data, "base": cloud.get("base"), "meta": _meta, "force": force}
	var r := await _call(HTTPClient.METHOD_PUT, "/save?game=" + GAME, body, true, UP_TIMEOUT)
	_busy = false
	if gen != _gen:
		return                                      # пока город летел, вышли или вошли другим аккаунтом — не наш ответ
	_last_status = int(r["status"])
	match int(r["status"]):
		200:
			if str(r["data"].get("game", "")) != GAME:
				net = "old"
			else:
				net = "online"
				up_fail = ""
				cloud["base"] = int(r["data"]["id"])
				cloud["hash"] = sent
				cloud["owner"] = who
				cloud.erase("force_next")
				cloud["up_at"] = int(Time.get_unix_time_from_system())
				cloud_save = {"id": cloud["base"], "created": float(r["data"].get("created", 0)), "meta": _meta}
				_store_cloud()
		409:
			net = "online"
			cloud_save = r["data"].get("latest")
			if not quiet:
				_ask({"meta": _meta, "time": int(Time.get_unix_time_from_system())}, cloud_save, "conflict")
		401:
			if not quiet:
				_session_lost()
		0:
			net = "offline"
		413:
			up_fail = "Город слишком большой для облака — он сохраняется на этом компьютере"
		_:
			up_fail = str(r["error"])
	changed.emit()


## Дождаться, пока город уйдёт в облако (выход из игры, выход из аккаунта), но не дольше t секунд
func _upload_wait(t: float) -> void:
	if not required() or token == "" or not synced or net == "old":
		return
	var t0 := _now()
	var tried := false
	while _now() - t0 < t:
		if not _busy:
			if not pending() or (tried and _last_status != 200):
				return                              # ушёл в облако — или не вышло (нет связи, конфликт): не держим
			tried = true
			_upload(false, true)
		await get_tree().create_timer(0.1, true, false, true).timeout


## «Сохранить в облако сейчас» (кнопка в настройках): без ожидания минуты
func save_now() -> void:
	var g = _g()
	if g and g.can_save and g.ready_done:
		g.save()
	if synced and pending() and not _busy:
		await _upload(false)
	changed.emit()


## Отложенное «Уничтожить город» → сервер. "" — ушло (или ждёт связи: cloud.destroy остаётся), "conflict" — с тех
## пор город в облаке сохраняли с другого компьютера (base не тот): уничтожение отменено, надо спросить игрока
func _send_destroy() -> String:
	var owner := str(cloud.get("owner", ""))
	if owner != "" and owner != email:
		cloud["destroy"] = false                    # уничтожал другой аккаунт этого компьютера — его город не наш
		cloud.erase("destroy_base")
		_store_cloud()
		return ""
	var gen := _gen
	var who := email
	var r := await _call(HTTPClient.METHOD_POST, "/destroy?game=" + GAME, {"meta": {"city": city_name()}, "base": cloud.get("destroy_base")})
	if gen != _gen:
		return ""                                   # пока ждали, сменился вход — ничего не записываем
	match int(r["status"]):
		200:
			cloud["destroy"] = false
			cloud.erase("destroy_base")
			cloud["base"] = int(r["data"]["id"])
			cloud["hash"] = ""
			cloud["owner"] = who
			cloud_save = {"id": cloud["base"], "created": float(r["data"].get("created", 0)), "destroyed": true, "meta": {"city": city_name()}}
			_store_cloud()
		409:
			cloud["destroy"] = false
			cloud.erase("destroy_base")
			if (r["data"] as Dictionary).get("latest") is Dictionary:
				cloud_save = r["data"]["latest"]
			_store_cloud()
			return "conflict"
		401:
			_session_lost()
		0:
			net = "offline"
	return ""


# ---------- уничтожить город ----------

## «Уничтожить город»: в облаке — отметка (прежний город остаётся в истории сервера), на компьютере — чистое поле
func destroy_city() -> void:
	var g = _g()
	if g:
		g.can_save = false                          # пока сервер ставит отметку, автосохранение не должно отправить старый город
	if ui and is_instance_valid(ui):
		ui.busy("Уничтожаем город…")
	_data = ""
	_hash = ""
	if required() and token != "" and net != "old":
		cloud["destroy"] = true
		cloud["destroy_base"] = cloud.get("base")   # какой город уничтожаем: если отметка уйдёт позже, сервер сверит
		_store_cloud()
		if await _send_destroy() == "conflict":
			# город в облаке новее (сохраняли с другого компьютера): после перезапуска сверка спросит, какой оставить
			cloud["destroy_ask"] = true
			_store_cloud()
			synced = false
	g = _g()
	if g:
		g.new_game()                                # стирает city.json и начинает новый город


# ---------- выход из игры ----------

## Выход из игры: сначала город уходит в облако (не дольше QUIT_WAIT секунд)
func quit_game() -> void:
	if _quitting:
		get_tree().quit()
		return
	_quitting = true
	if required() and token != "" and synced and pending():
		if ui and is_instance_valid(ui):
			ui.busy("Сохраняем город в облаке…")
		await _upload_wait(QUIT_WAIT)
	if test != "":
		print("CLOUDTEST quit pending=%s base=%s net=%s" % [str(pending()), str(cloud.get("base")), net])
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not get_tree().auto_accept_quit:
		await get_tree().process_frame               # игра сохраняет город в своём _notification
		quit_game()


# ---------- запросы к серверу ----------

func _call(method: int, path: String, body = null, gz := false, timeout := TIMEOUT, auth := true) -> Dictionary:
	# повтор при сбое связи (NetHttp): чтение и вход — всегда; запись города, уничтожение, регистрация — только если
	# запрос точно не дошёл (иначе второй раз сервер ответил бы «в облаке новее» или «почта занята»)
	var safe := method == HTTPClient.METHOD_GET or path == "/login" or path == "/logout"
	var r: Dictionary = await NetHttp.fetch(self, api, method, path, body, token if auth else "", {"timeout": timeout, "gzip_body": gz, "safe": safe})
	if int(r["status"]) == 0:
		last_net = String(r["net"])
		if off_since <= 0.0:
			off_since = Time.get_unix_time_from_system()
	else:
		last_net = ""
		off_since = 0.0
	return r


# ---------- файлы: вход, состояние облака, город на диске ----------

func _path(name: String) -> String:
	return GamePaths.save_dir().path_join(name)


func _save_path() -> String:
	return GamePaths.save_dir().path_join(Game.SAVE_NAME)


func _key() -> String:
	var id := OS.get_unique_id()
	return "CivCity:%s:account" % (id if id != "" else "no-id")


func _load_session() -> void:
	var p := _path(SESSION_FILE)
	if not FileAccess.file_exists(p):
		return
	var f := FileAccess.open_encrypted_with_pass(p, FileAccess.READ, _key())
	if f == null:
		return                                      # другой компьютер или испорченный файл — войти заново
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) != TYPE_DICTIONARY or str(d.get("token", "")) == "" or str(d.get("api", "")) != api:
		return
	token = str(d["token"])
	email = str(d.get("email", ""))


func _store_session() -> void:
	var p := _path(SESSION_FILE)
	if token == "":
		DirAccess.remove_absolute(p)
		return
	var f := FileAccess.open_encrypted_with_pass(p, FileAccess.WRITE, _key())
	if f:
		f.store_string(JSON.stringify({"email": email, "token": token, "api": api}))
		f.close()


func _load_cloud() -> void:
	cloud = {"owner": "", "base": null, "hash": "", "up_at": 0, "destroy": false, "api": api}
	var p := _path(CLOUD_FILE)
	if not FileAccess.file_exists(p):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	if typeof(d) != TYPE_DICTIONARY or str(d.get("api", "")) != api:
		return                                      # другой сервер (проверки) — номера сохранений не те
	for k in d:
		cloud[k] = d[k]


func _store_cloud() -> void:
	cloud["api"] = api
	var f := FileAccess.open(_path(CLOUD_FILE), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(cloud, "\t"))
		f.close()


## Город на диске: строка, отпечаток, подпись (жители, день…) и время записи; {} — города нет
func _local() -> Dictionary:
	var p := _save_path()
	if not FileAccess.file_exists(p):
		return {}
	var s := FileAccess.get_file_as_string(p)
	var d = JSON.parse_string(s)
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	return {"data": s, "hash": s.sha256_text(), "meta": meta_of(d), "time": FileAccess.get_modified_time(p)}


## Подпись города по сохранению: жители, день, уровень, деньги, построек
static func meta_of(d: Dictionary) -> Dictionary:
	var pop := 0
	var bl: Array = d.get("buildings", [])
	for b in bl:
		if typeof(b) == TYPE_DICTIONARY:
			pop += int(b.get("pop", 0))
	return {"pop": pop, "day": int(d.get("day", 0)), "level": int(d.get("level", 0)), "money": int(d.get("money", 0)), "n": bl.size()}


func city_name() -> String:
	var g = _g()
	if g and g.hud and g.hud.lbl_city:
		return str(g.hud.lbl_city.text)
	return "Новый Рим"


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# ---------- проверка без человека ----------
## --cloudtest=menu:N  — в меню на кадре N: напечатать, вошли ли, снимок (--cloudshot=файл.png), выйти;
## --cloudtest=quit:N  — в городе на кадре N: напечатать город, снимок, сохранить, отправить в облако, выйти;
## --cloudtest=close:N — то же, но как крестик окна (NOTIFICATION_WM_CLOSE_REQUEST): игра сохраняет, облако, выход.

func _process(_dt: float) -> void:
	if test == "":
		return
	var g = _g()
	if g == null or not g.ready_done:
		return
	var kind := test.get_slice(":", 0)
	if (kind == "menu") != (g.mode == "menu"):
		return
	_test_frame += 1
	var n := int(test.get_slice(":", 1)) if test.contains(":") else 300
	if _test_frame != n:
		return
	if test_shot != "":
		g.get_viewport().get_texture().get_image().save_png(test_shot)
	if kind == "menu":
		var lg = ui._login if ui and is_instance_valid(ui) else null
		print("CLOUDTEST menu signed_in=%s login_panel=%s net=%s synced=%s" % [str(signed_in()), str(lg != null and is_instance_valid(lg) and lg.visible), net, str(synced)])
		get_tree().quit()
		return
	var c = g.city
	print("CLOUDTEST play buildings=%d pop=%d day=%d money=%d net=%s synced=%s base=%s" % [c.buildings.size(), int(c.stats.get("pop", 0)), int(c.day), int(c.money), net, str(synced), str(cloud.get("base"))])
	if kind == "close":
		print("CLOUDTEST close request")
		get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
		await get_tree().create_timer(QUIT_WAIT + 3.0).timeout
		print("CLOUDTEST FAIL still running after close")
		get_tree().quit(3)
		return
	if g.can_save:
		g.save()
	print("CLOUDTEST pending=%s" % str(pending()))
	await _upload_wait(QUIT_WAIT)
	print("CLOUDTEST uploaded pending=%s base=%s net=%s" % [str(pending()), str(cloud.get("base")), net])
	get_tree().quit()
