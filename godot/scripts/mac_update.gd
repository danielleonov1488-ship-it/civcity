class_name MacUpdate
extends Node
## Новая версия для Mac. Игру для Mac друзья скачивают архивом с сайта (лаунчера на Mac нет), и обновляется она
## новым архивом. При запуске игра читает https://civcity.ru/game/mac.json — {"build": N, "min": M, "url": …} (его
## пишет bash deploy/deploy.sh mac) — и сравнивает со своей сборкой (res://mac_build.txt, его кладёт в набор
## bash tools/build_game.sh mac):
##   своя < min   — окно во весь экран «Вышла новая версия CivCity для Mac. Скачайте её, чтобы играть дальше.» с
##                  кнопками «Скачать новую версию» (адрес из файла — в браузере) и «Выйти»; играть нельзя: окно
##                  закрывает меню и вход, «Играть» не срабатывает;
##   своя < build — тихая строка в меню «Вышла новая версия для Mac — скачать»;
##   иначе — ничего. Нет связи, нет файла, ответ не читается, дольше TIMEOUT — тоже ничего: сетевая ошибка никогда
##   не мешает играть.
## Одна проверка на запуск (узел под корнем дерева, как Account, — переживает меню ↔ город). Запрос уходит в начале
## загрузки города; ждём ответа по часам — TIMEOUT с после того, как игра загрузилась (attach): кадры загрузки бывают
## по несколько секунд, и тайм-аут HTTPRequest (он считает время кадров) они съели бы, хотя ответ пришёл бы за доли
## секунды. (Запрос в своём потоке не годится: при молчащем сервере поток висит на чтении, и игра не закрылась бы.)
## «Играть» ждёт проверку, но не дольше, — старая сборка не успеет уйти в город раньше окна. Только на Mac (признак macos) и не в
## редакторе. Проверки (test_mac_update) включают её где угодно: MacUpdate.test_url / test_build или в командной
## строке --macupdate=адрес и --macbuild=N (так проверяется и собранная игра на Windows).

signal decided(state: String)

const URL := "https://civcity.ru/game/mac.json"
const PAGE := "https://civcity.ru/mac/"          # страница для друзей: скачать, первый запуск, управление
const SAFE := "https://civcity.ru/"               # открываем в браузере только свои адреса
const TIMEOUT := 5.0
const LINE_TEXT := "Вышла новая версия для Mac — скачать"
const BLOCK_TITLE := "Вышла новая версия CivCity для Mac. Скачайте её, чтобы играть дальше."

static var test_url := ""                          # проверки: откуда читать (вместо URL; включает проверку не на Mac)
static var test_build := -1                        # проверки: «своя» сборка
static var test_timeout := 0.0                     # проверки: ждать ответа не дольше (с)
static var test_opened := ""                       # проверки: какой адрес открыли бы в браузере (браузер не открываем)
static var _inst: MacUpdate = null

var state := "idle"                                # idle | checking | ok | newer | blocked | failed | off
var why := ""                                      # failed: почему (net / status / json)
var build := 0                                     # своя сборка (0 — неизвестна: ни окна, ни строки)
var latest := 0
var min_build := 0
var url := ""
var overlay: CanvasLayer                           # окно «скачайте новую версию»
var _game = null
var _deadline := 0                                 # Time.get_ticks_msec: позже — «нет ответа», играть можно


## Нужна ли проверка: Mac (не редактор) или проверка задала адрес
static func wanted() -> bool:
	if test_url != "":
		return true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--macupdate="):
			return true
	return OS.has_feature("macos") and not OS.has_feature("editor")


## Game._ready, в самом начале: на Mac — начать проверку (на Windows узла даже не появляется)
static func check_at_start(g = null) -> void:
	if wanted():
		var m := me()
		if g != null:
			m._game = g                        # окно — в оформлении игры, как только у неё появится интерфейс
		m.start()


## Game._ready, в конце: строка в меню или окно
static func attach_game(g) -> void:
	if _inst != null and is_instance_valid(_inst):
		_inst.attach(g)


## «Играть» (hud._menu_go): можно ли (ждёт проверку, не дольше TIMEOUT); на Windows — сразу да
static func allow_play() -> bool:
	if _inst == null or not is_instance_valid(_inst):
		return true
	return await _inst.may_play()


## Один узел на запуск, под корнем дерева. Добавляется в конце кадра (call_deferred): при запуске игры его создаёт
## Game._ready главной сцены, а корень в это время ещё расставляет детей — add_child сразу не сработал бы
## (в собранной игре это обрушивало запуск; в проверках игра вложена в сцену проверки, и там такого не видно)
static func me() -> MacUpdate:
	if _inst == null or not is_instance_valid(_inst):
		_inst = MacUpdate.new()
		_inst.name = "MacUpdate"
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_inst)
	return _inst


## Своя сборка: из командной строки (проверки), из проверки, из файла в наборе (сборка для Mac); 0 — неизвестна
static func our_build() -> int:
	if test_build >= 0:
		return test_build
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--macbuild="):
			return int(a.trim_prefix("--macbuild="))
	if FileAccess.file_exists("res://mac_build.txt"):
		return int(FileAccess.get_file_as_string("res://mac_build.txt").strip_edges())
	return 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Начать проверку (Game._ready, в самом начале — пока грузится город, ответ уже придёт). Второй раз — ничего
func start() -> void:
	if state != "idle":
		return
	var src := test_url
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--macupdate="):
			src = a.trim_prefix("--macupdate=")
	if src == "":
		if not OS.has_feature("macos") or OS.has_feature("editor"):
			state = "off"
			return
		src = URL
	build = our_build()
	state = "checking"
	if not is_inside_tree():
		await ready                            # узел встанет в дерево в конце кадра (me)
	_fetch(src)


func _fetch(src: String) -> void:
	var cut := src.find("/", src.find("://") + 3)
	var base := src.substr(0, cut) if cut > 0 else src
	var path := src.substr(cut) if cut > 0 else "/"
	if _game == null:
		_arm()                                 # без игры (проверки) — часы идут сразу
	# тайм-аут запроса выключен (0): его ведут часы (_deadline в _process) — кадры загрузки его не съедят
	var r: Dictionary = await NetHttp.fetch(self, base, HTTPClient.METHOD_GET, path, null, "", {"timeout": 0.0, "safe": false})
	if state != "checking":
		return
	if int(r.get("status", 0)) != 200:
		_decide({}, "net:" + str(r.get("net", "")) if int(r.get("status", 0)) == 0 else "status:%d" % int(r["status"]))
		return
	_decide(r.get("data", {}), "")


func _decide(d: Dictionary, fail: String) -> void:
	var nb := int(d.get("build", 0)) if (typeof(d.get("build")) == TYPE_FLOAT or typeof(d.get("build")) == TYPE_INT) else 0
	var mn := int(d.get("min", 0)) if (typeof(d.get("min")) == TYPE_FLOAT or typeof(d.get("min")) == TYPE_INT) else 0
	latest = nb
	min_build = mn
	var u := str(d.get("url", ""))
	url = u if u.begins_with(SAFE) else PAGE
	if fail != "" or nb <= 0:
		state = "failed"
		why = fail if fail != "" else "json"
	elif build > 0 and build < mn:
		state = "blocked"
	elif build > 0 and build < nb:
		state = "newer"
	else:
		state = "ok"
	print("MacUpdate: своя сборка %d, на сайте %d (обязательна с %d) → %s%s" % [build, nb, mn, state, (" (" + why + ")") if why != "" else ""])
	if state == "blocked" and (_game == null or not is_instance_valid(_game) or _hud_ready(_game)):
		_block()                               # игра ещё грузится — окно поставит attach (в том же кадре, что и меню)
	elif state == "newer" and _game != null and is_instance_valid(_game):
		_menu_line(_game)
	decided.emit(state)


static func _hud_ready(g) -> bool:
	return g.hud != null and is_instance_valid(g.hud) and g.hud.is_inside_tree() and g.hud.theme_main != null


## Часы ожидания: TIMEOUT с с этой минуты (игра загрузилась — дальше кадры обычные)
func _arm() -> void:
	if _deadline == 0:
		_deadline = Time.get_ticks_msec() + int((test_timeout if test_timeout > 0.0 else TIMEOUT) * 1000.0)


func _process(_dt: float) -> void:
	if state == "checking" and _deadline > 0 and Time.get_ticks_msec() > _deadline:
		for c in get_children():
			if c is HTTPRequest:
				(c as HTTPRequest).cancel_request()   # запрос без тайм-аута — снять, чтобы не висел
				c.queue_free()
		_decide({}, "timeout")                 # сервер молчит — играем


## Игра на сцене (конец Game._ready): строка в меню или окно — сейчас, если ответ уже есть, иначе — когда придёт
func attach(g) -> void:
	_game = g
	if state == "checking":
		_arm()
	if state == "newer":
		_menu_line(g)
	elif state == "blocked":
		_block()


## «Играть» (hud._menu_go): дождаться проверки; false — играть нельзя (окно «скачайте новую версию»)
func may_play() -> bool:
	while state == "checking":
		await decided
	return state != "blocked"


func open_download() -> void:
	var u := url if url != "" else PAGE
	if test_url != "":
		test_opened = u                        # проверка: браузер не открываем, только запоминаем адрес
		return
	OS.shell_open(u)


# ---------- окна ----------

## Тихая строка в главном меню — внизу слева, над подсказкой про управление
func _menu_line(g) -> void:
	var h = g.hud
	if g.mode != "menu" or h == null or h.menu_root == null or not is_instance_valid(h.menu_root):
		return
	if h.menu_root.get_node_or_null("mac_update") != null:
		return
	var b := LinkButton.new()
	b.name = "mac_update"
	b.text = LINE_TEXT
	b.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", h.font_bold)
	b.add_theme_font_size_override("font_size", 18)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, h.C_CREAM if c != "font_hover_color" else Color("ffe2a0"))
	b.add_theme_color_override("font_outline_color", Color("3a2412"))
	b.add_theme_constant_override("outline_size", 6)
	b.tooltip_text = "Откроется в браузере. Распакуйте архив и запускайте новую CivCity — город и вход сохранятся."
	b.pressed.connect(open_download)
	h._put(b, Control.PRESET_BOTTOM_LEFT, Vector2(80, -68))
	h.menu_root.add_child(b)
	h._hook_buttons(h.menu_root)


## Окно во весь экран: играть нельзя, пока не скачают новую версию
func _block() -> void:
	if overlay != null and is_instance_valid(overlay):
		return
	var h = null
	if _game != null and is_instance_valid(_game) and _hud_ready(_game):
		h = _game.hud
	var vp := get_viewport()
	if vp:
		vp.gui_release_focus()                 # печатали почту во входе — клавиши больше не туда
	overlay = CanvasLayer.new()
	overlay.name = "mac_update_block"
	overlay.layer = 120                        # над всем интерфейсом игры (Hud, вход, советник)
	add_child(overlay)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	if h != null:
		root.theme = h.theme_main
	overlay.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.13, 0.08, 0.05, 0.93)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(col)
	if h != null:
		var logo: TextureRect = h._pic("logo.png", Vector2(470, 231))
		logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(logo)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(620, 0)
	if h != null:
		p.add_theme_stylebox_override("panel", h._box_panel(18))
	col.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	var ink := Color("4a2c17")
	var t := Label.new()
	t.text = BLOCK_TITLE
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(540, 0)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 28)
	t.add_theme_color_override("font_color", ink)
	if h != null:
		t.add_theme_font_override("font", h.font_title)
	v.add_child(t)
	if h != null:
		v.add_child(h._divider())
	var s := Label.new()
	s.text = "Архив скачается в браузере. Распакуйте его и запускайте новую CivCity вместо старой — город и вход сохранятся."
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.custom_minimum_size = Vector2(540, 0)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_theme_font_size_override("font_size", 18)
	s.add_theme_color_override("font_color", Color("7a5a3c"))
	if h != null:
		s.add_theme_font_override("font", h.font)
	v.add_child(s)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	var go := Button.new()
	go.name = "download"
	go.text = "Скачать новую версию"
	go.custom_minimum_size = Vector2(260, 54)
	go.pressed.connect(open_download)
	row.add_child(go)
	var out := Button.new()
	out.name = "quit"
	out.text = "Выйти"
	out.custom_minimum_size = Vector2(160, 54)
	out.pressed.connect(func(): get_tree().quit())
	row.add_child(out)
	for b: Button in [go, out]:
		b.add_theme_font_size_override("font_size", 20)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if h != null:
			b.add_theme_font_override("font", h.font_bold)
	go.grab_focus.call_deferred()


## Клавиши, пока открыто окно, в игру не идут (Esc, пробел, буквы камеры); Cmd+Q закрывает игру сама macOS
func _input(e: InputEvent) -> void:
	if overlay != null and is_instance_valid(overlay) and e is InputEventKey:
		var k := e as InputEventKey
		if k.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_TAB, KEY_LEFT, KEY_RIGHT]:
			return                             # кнопки окна — с клавиатуры тоже
		get_viewport().set_input_as_handled()
