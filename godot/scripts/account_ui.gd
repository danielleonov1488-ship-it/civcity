class_name AccountUi
extends Control
## Окна аккаунта в рисованном стиле игры (assets/ui/ai): вход и регистрация — в главном меню вместо кнопок
## (как было в браузерной версии: без входа не играем), строка «вы вошли · Выйти» под кнопками меню, блок
## в настройках (почта, облако, «Выйти»), «Уничтожить город» с тремя подтверждениями (последнее — написать
## название города), вопрос «какой город оставить» и «сохраняем город в облаке…» при выходе.
## Логика входа и облака — в Account.me() (account.gd); здесь только окна.

const MONTHS := ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"]
const FIELD_W := 290.0                    # ширина полей в свитке меню (свиток 380, поля пергамента по бокам)

var hud
var _menu_p: PanelContainer               # свиток с кнопками главного меню
var _login: PanelContainer                # окно входа (в меню — на месте свитка с кнопками)
var _login_in_modal := false
var _mode := "login"                      # login | reg | forgot
var _note := ""
var _modal: Control                       # затемнение с окном посередине (одно на экран)
var _modal_kind := ""
var _acc_line: VBoxContainer              # в меню: почта, состояние облака, «Выйти»


func setup(h) -> void:
	hud = h
	name = "AccountUi"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = h.theme_main
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	h.add_child(self)
	Account.me().changed.connect(_on_changed)


## Окна для этого интерфейса (если игра без входа — тесты, --nologin — окна всё равно нужны для «Уничтожить город»)
static func for_hud(h) -> AccountUi:
	var u = h.get_node_or_null("AccountUi")
	if u is AccountUi:
		return u
	u = AccountUi.new()
	u.setup(h)
	return u


func _menu_mode() -> bool:
	return hud.game != null and hud.game.mode == "menu" and hud.menu_root != null


# ---------- главное меню ----------

## Меню: без входа — окно входа под логотипом, со входом — кнопки и строка «вы вошли»
func menu() -> void:
	if not _menu_mode():
		return
	if _modal_kind == "busy" or _modal_kind == "login":
		_close_modal()
	if _menu_p == null or not is_instance_valid(_menu_p):
		for c in hud.menu_root.find_children("*", "PanelContainer", true, false):
			_menu_p = c
			break
	if _menu_p == null:
		return
	var col: Node = _menu_p.get_parent()
	if not Account.me().signed_in():
		_menu_p.visible = false
		if _login == null or not is_instance_valid(_login) or _login_in_modal:
			_login = _scroll(380)
			_login.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_login_in_modal = false
			col.add_child(_login)
			_mode = "login"
			_fill_login()
		_login.visible = true
		return
	if _login and is_instance_valid(_login) and not _login_in_modal:
		_login.queue_free()
		_login = null
	_note = ""
	_menu_p.visible = true
	_menu_line()


func _menu_line() -> void:
	var v: Node = _menu_p.get_child(0) if _menu_p.get_child_count() > 0 else null
	if v == null:
		return
	if _acc_line == null or not is_instance_valid(_acc_line):
		_acc_line = VBoxContainer.new()
		_acc_line.name = "acc_line"
		_acc_line.add_theme_constant_override("separation", 2)
		v.add_child(_acc_line)
	hud._clear(_acc_line)
	_acc_line.add_child(hud._divider(14))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(hud._icon("person", 22, hud.C_SOFT))
	var who: Label = hud._label(Account.me().email, 16, true, hud.C_INK)
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	who.custom_minimum_size = Vector2(0, 0)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.clip_text = true
	who.tooltip_text = "Вы вошли как " + Account.me().email
	who.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(who)
	var out := _link("Выйти", func(): Account.me().logout())
	out.name = "acc_out"
	h.add_child(out)
	_acc_line.add_child(h)
	var st: Label = hud._wrap(hud._label(status_text(), 14, false, hud.C_SOFT), FIELD_W)
	st.name = "acc_state"
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_acc_line.add_child(st)


func _on_changed() -> void:
	if not is_instance_valid(hud):
		return
	if _menu_mode():
		var need_login := not Account.me().signed_in()
		var showing_login := _login != null and is_instance_valid(_login) and not _login_in_modal and _login.visible
		if need_login != showing_login:
			menu()
		elif not need_login and _acc_line and is_instance_valid(_acc_line):
			var st := _acc_line.find_child("acc_state", true, false) as Label
			if st:
				st.text = status_text()
	if hud.settings_panel and hud.settings_panel.visible:
		settings_refresh(hud)


# ---------- окно входа ----------

## Вход посреди игры (вход устарел): в меню — под логотипом, в игре — окно поверх
func login_modal(note: String) -> void:
	_note = note
	_mode = "login"
	if _menu_mode():
		menu()
		if _login and is_instance_valid(_login):
			_fill_login()
		return
	var w := _window("Вход", 440, false)
	_login = w[0]
	_login_in_modal = true
	_open_modal(_login, "login")
	_fill_login()


func _fill_login() -> void:
	if _login == null or not is_instance_valid(_login):
		return
	var v: VBoxContainer
	if _login_in_modal:
		v = _login.get_child(0)
		while v.get_child_count() > 2:              # заголовок и разделитель окна остаются
			var ch := v.get_child(2)
			v.remove_child(ch)
			ch.queue_free()
	else:
		hud._clear(_login)
		v = VBoxContainer.new()
		_login.add_child(v)
	v.add_theme_constant_override("separation", 8)
	if _mode == "forgot":
		_fill_forgot(v)
		return
	if not _login_in_modal:
		var t: Label = hud._label("Вход" if _mode == "login" else "Регистрация", 28, false, hud.C_INK, hud.font_title)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
	# вкладки «Вход» / «Регистрация»
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 6)
	for tb: Array in [["login", "Вход"], ["reg", "Регистрация"]]:
		var b := Button.new()
		b.text = tb[1]
		b.name = "tab_" + tb[0]
		b.custom_minimum_size = Vector2(140, 40)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 18)
		var key: String = tb[0]
		if key == _mode:
			b.add_theme_stylebox_override("normal", hud._box_pill(16, 6, "g_btn_on"))
			b.add_theme_stylebox_override("hover", hud._box_pill(16, 6, "g_btn_on"))
			b.add_theme_font_override("font", hud.font_bold)
		b.pressed.connect(func():
			if _mode != key:
				_mode = key
				_fill_login())
		tabs.add_child(b)
	v.add_child(tabs)
	var note := _note if _note != "" else "Город хранится на сервере: не потеряется, и играть можно с любого компьютера."
	var nl: Label = hud._wrap(hud._label(note, 15, false, hud.C_BAD if _note != "" else hud.C_SOFT), FIELD_W)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nl)
	v.add_child(hud._divider(16))
	v.add_child(hud._label("Почта", 16, true))
	var em := _field(false, "имя@почта.ру")
	em.name = "email"
	em.text = Account.me().email
	v.add_child(em)
	v.add_child(hud._label("Пароль" if _mode == "login" else "Пароль — не короче 6 знаков", 16, true))
	var pw := _field(true, "")
	pw.name = "pass"
	v.add_child(pw)
	var err: Label = hud._wrap(hud._label("", 15, true, hud.C_BAD), FIELD_W)
	err.name = "err"
	err.visible = false
	v.add_child(err)
	var go := Button.new()
	go.name = "go"
	go.text = "Войти" if _mode == "login" else "Создать аккаунт"
	go.icon = hud.ico("keys", 36)
	go.custom_minimum_size = Vector2(FIELD_W, 52)
	go.add_theme_font_size_override("font_size", 22)
	go.add_theme_font_override("font", hud.font_bold)
	v.add_child(go)
	var submit := func(): _submit(em, pw, err, go)
	go.pressed.connect(submit)
	em.text_submitted.connect(func(_t): pw.grab_focus())
	pw.text_submitted.connect(func(_t): submit.call())
	if _mode == "login":
		var fg := _link("Забыли пароль?", func():
			_mode = "forgot"
			_fill_login())
		fg.name = "forgot"
		fg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(fg)
	else:
		var tip: Label = hud._wrap(hud._label("Подтверждать почту не нужно — она понадобится, только если забудете пароль.", 14, false, hud.C_SOFT), FIELD_W)
		tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(tip)
	if not _login_in_modal:
		var ex := _link("Выход из игры", func(): Account.me().quit_game())
		ex.name = "exit"
		ex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ex)
	var first: LineEdit = pw if em.text != "" else em
	(func(): if is_instance_valid(first) and first.is_inside_tree(): first.grab_focus()).call_deferred()   # окно могли тут же пересобрать


func _submit(em: LineEdit, pw: LineEdit, err: Label, go: Button) -> void:
	var mail := em.text.strip_edges()
	err.visible = false
	if not mail.contains("@") or not mail.contains("."):
		_err(err, "Проверьте адрес почты")
		em.grab_focus()
		return
	if pw.text.length() < 6:
		_err(err, "Пароль — не короче 6 знаков")
		pw.grab_focus()
		return
	var label := go.text
	go.disabled = true
	go.text = "Входим…" if _mode == "login" else "Создаём аккаунт…"
	var e: String = await Account.me().login(mail, pw.text, _mode == "reg")
	if not is_instance_valid(go):
		return
	go.disabled = false
	go.text = label
	if e != "":
		_err(err, e)
		pw.grab_focus()
		return
	pw.text = ""
	_note = ""
	if _login_in_modal:
		_close_modal()
		_login = null
		_login_in_modal = false
	else:
		menu()


func _err(l: Label, text: String) -> void:
	l.text = text
	l.visible = true
	if _login and is_instance_valid(_login):
		hud._refit(_login)


func _fill_forgot(v: VBoxContainer) -> void:
	if not _login_in_modal:
		var t: Label = hud._label("Забыли пароль?", 28, false, hud.C_INK, hud.font_title)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
	v.add_child(hud._wrap(hud._label("Пришлём на почту ссылку. Откройте её — на сайте civcity.ru задайте новый пароль, а потом войдите здесь. Ссылка действует час.", 15, false, hud.C_SOFT), FIELD_W))
	v.add_child(hud._divider(16))
	v.add_child(hud._label("Почта", 16, true))
	var em := _field(false, "имя@почта.ру")
	em.name = "email"
	em.text = Account.me().email
	v.add_child(em)
	var msg: Label = hud._wrap(hud._label("", 15, true, hud.C_GOOD), FIELD_W)
	msg.name = "msg"
	msg.visible = false
	v.add_child(msg)
	var go := Button.new()
	go.name = "send"
	go.text = "Прислать ссылку"
	go.custom_minimum_size = Vector2(FIELD_W, 50)
	go.add_theme_font_size_override("font_size", 20)
	go.add_theme_font_override("font", hud.font_bold)
	v.add_child(go)
	var send := func():
		var mail := em.text.strip_edges()
		if not mail.contains("@"):
			msg.add_theme_color_override("font_color", hud.C_BAD)
			msg.text = "Проверьте адрес почты"
			msg.visible = true
			return
		go.disabled = true
		var e: String = await Account.me().forgot(mail)
		if not is_instance_valid(go):
			return
		go.disabled = false
		msg.add_theme_color_override("font_color", hud.C_BAD if e != "" else hud.C_GOOD)
		msg.text = e if e != "" else "Если такая почта есть в игре, письмо уже летит. Проверьте и папку «Спам»."
		msg.visible = true
		if _login and is_instance_valid(_login):
			hud._refit(_login)
	go.pressed.connect(send)
	em.text_submitted.connect(func(_t): send.call())
	var site := _link("Открыть сайт civcity.ru", func(): OS.shell_open(Account.SITE))
	site.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(site)
	var back := _link("Назад ко входу", func():
		_mode = "login"
		_fill_login())
	back.name = "back"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)
	em.call_deferred("grab_focus")


# ---------- настройки ----------

## Блок аккаунта в окне настроек (строится вместе с окном): почта, облако, «Выйти», «Уничтожить город…»
static func settings_block(h, v: VBoxContainer) -> void:
	var box := VBoxContainer.new()
	box.name = "acc_box"
	box.add_theme_constant_override("separation", 6)
	box.add_child(h._divider(18))
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	r.add_child(h._icon("person", 26, h.C_SOFT))
	var t: Label = h._wrap(h._label("", 18, true), 420)
	t.name = "acc_text"
	r.add_child(t)
	box.add_child(r)
	var st: Label = h._wrap(h._label("", 15, false, h.C_SOFT), 456)
	st.name = "acc_state"
	box.add_child(st)
	var bt := HBoxContainer.new()
	bt.add_theme_constant_override("separation", 10)
	var now := Button.new()
	now.name = "acc_now"
	now.text = "Сохранить в облако"
	now.icon = h.ico("save", 32)
	now.pressed.connect(func():
		now.disabled = true
		await Account.me().save_now()
		if is_instance_valid(now):
			now.disabled = false
			settings_refresh(h))
	bt.add_child(now)
	var out := Button.new()
	out.name = "acc_out"
	out.text = "Выйти из аккаунта"
	out.icon = h.ico("exit", 32)
	out.pressed.connect(func():
		h.settings_panel.visible = false
		Account.me().logout())
	bt.add_child(out)
	box.add_child(bt)
	v.add_child(box)
	var d := Button.new()
	d.name = "destroy"
	d.text = "Уничтожить город…"
	d.icon = h.ico("demolish", 32)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		d.add_theme_color_override(c, h.C_BAD)
	d.tooltip_text = "Снести весь город и начать с чистого поля"
	d.pressed.connect(func():
		h.settings_panel.visible = false
		AccountUi.for_hud(h).destroy(1))
	v.add_child(d)


## Обновить блок аккаунта (окно настроек открыли или что-то поменялось)
static func settings_refresh(h) -> void:
	if h.settings_panel == null:
		return
	var box := h.settings_panel.find_child("acc_box", true, false) as Control
	if box == null:
		return
	box.visible = Account.me().required() and Account.me().signed_in()
	if box.visible:
		(box.find_child("acc_text", true, false) as Label).text = "Вы вошли как %s" % Account.me().email
		(box.find_child("acc_state", true, false) as Label).text = status_text()
		(box.find_child("acc_now", true, false) as Button).visible = Account.me().synced and Account.me().net != "old"
	var d := h.settings_panel.find_child("destroy", true, false) as Control
	if d:
		var g = h.game
		d.visible = g != null and (g.mode == "play" or g.mode == "new" or (g.mode == "menu" and FileAccess.file_exists(g.save_path())))


## Что сейчас с облаком — одной фразой
static func status_text() -> String:
	match Account.me().net:
		"checking":
			return "Сверяем город с облаком…"
		"offline":
			return "Нет связи с сервером — играем дальше, город уйдёт в облако, когда связь появится."
		"old":
			return "Облако для этой версии игры на сервере ещё не включено — город сохраняется на этом компьютере."
	if Account.me()._ask_open:
		return "Нужно выбрать, какой город оставить — облачный или этот."
	if not Account.me().synced:
		# сверка не удалась (сервер ответил ошибкой) — город пока не уходит в облако, честно об этом
		var e: String = Account.me().last_error
		return e if e != "" else "Город ещё не сверен с облаком — попробуем снова через минуту. Он сохраняется на этом компьютере."
	if Account.me().up_fail != "":
		return Account.me().up_fail
	var up := int(Account.me().cloud.get("up_at", 0))
	if Account.me().pending() and up > 0:
		return "В облаке — город от %s, свежие изменения уйдут в течение минуты." % when(up)
	if up > 0:
		return "Город в облаке — сохранён %s." % when(up)
	return "Город сохраняется в облаке раз в минуту и при выходе из игры."


static func when(unix: int) -> String:
	if unix <= 0:
		return "давно"
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(unix + bias)
	var n := Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()) + bias)
	var hm := "%02d:%02d" % [int(d["hour"]), int(d["minute"])]
	if d["year"] == n["year"] and d["month"] == n["month"] and d["day"] == n["day"]:
		return "сегодня в " + hm
	return "%d %s в %s" % [int(d["day"]), MONTHS[int(d["month"]) - 1], hm]


# ---------- уничтожить город ----------

## Три подтверждения, последнее — написать название города (как в браузерной версии)
func destroy(step: int) -> void:
	var nm := Account.me().city_name()
	var w: Array
	match step:
		1:
			w = _window("Уничтожить город", 520, true)
			_text(w[1], "Уничтожить «%s»?" % nm, 22, true)
			_text(w[1], "Пропадёт всё: дома, жители, лавки, деньги, знания и украшения. Вместо города будет чистое поле.")
			_buttons(w[1], [["Нет, оставить", "", func(): _close_modal()], ["Продолжить", "danger", func(): destroy(2)]])
		2:
			w = _window("Точно уничтожить?", 520, true)
			_text(w[1], "Это нельзя отменить. Город, который вы строили, исчезнет навсегда.")
			_buttons(w[1], [["Нет, оставить город", "", func(): _close_modal()], ["Да, уничтожить", "danger", func(): destroy(3)]])
		_:
			w = _window("Последний шаг", 520, true)
			_text(w[1], "Чтобы уничтожить город, напишите его название:")
			_text(w[1], nm, 24, true)
			var f := _field(false, "название города")
			f.name = "city_name"
			f.custom_minimum_size = Vector2(440, 46)
			f.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			(w[1] as VBoxContainer).add_child(f)
			var row := _buttons(w[1], [["Отмена", "", func(): _close_modal()], ["Уничтожить навсегда", "danger", func(): _destroy_go()]])
			var go: Button = row.get_child(1)
			go.name = "destroy_go"
			go.disabled = true
			var norm := func(s: String) -> String: return s.strip_edges().to_lower().replace("ё", "е")
			f.text_changed.connect(func(t): go.disabled = norm.call(t) != norm.call(nm))
			f.text_submitted.connect(func(t):
				if norm.call(t) == norm.call(nm):
					_destroy_go())
			f.call_deferred("grab_focus")
	_open_modal(w[0], "destroy")


func _destroy_go() -> void:
	_close_modal()
	Account.me().destroy_city()


# ---------- какой город оставить ----------

## Город менялся и на этом компьютере, и в облаке: показать оба и спросить
func ask_city(lm: Dictionary, ltime: int, cs, why: String) -> void:
	var w := _window("Какой город оставить?", 600, false)
	var v: VBoxContainer = w[1]
	if why == "conflict":
		_text(v, "Пока вы играли, город в облаке сохранили на другом компьютере.")
	elif why == "destroy":
		_text(v, "Вы уничтожили город, пока не было связи, а на другом компьютере его с тех пор сохраняли. Облачный город мы не тронули.")
	else:
		_text(v, "Город в облаке и город на этом компьютере разные.")
	var cm: Dictionary = cs.get("meta", {}) if cs != null and typeof(cs.get("meta")) == TYPE_DICTIONARY else {}
	var ctime := int(float(cs.get("created", 0)) / 1000.0) if cs != null else 0
	var destroyed: bool = cs != null and bool(cs.get("destroyed", false))
	if destroyed:
		_row(v, "demolish", "В облаке город уничтожен (%s) — там чистое поле." % when(ctime))
	else:
		_row(v, "scroll", "В облаке — %s. Сохранён %s." % [_size_text(cm), when(ctime)])
	if why == "destroy" and int(lm.get("pop", 0)) == 0 and int(lm.get("n", 0)) <= 1:
		_row(v, "housing", "На этом компьютере — новый город на чистом поле.")
	else:
		_row(v, "housing", "На этом компьютере — %s. Сохранён %s." % [_size_text(lm), when(ltime)])
	_buttons(v, [["Начать с чистого поля" if destroyed else "Взять из облака", "", func():
			_close_modal()
			Account.me().resolve(true)],
		["Оставить этот", "", func():
			_close_modal()
			Account.me().resolve(false)]])
	_text(v, "Второй город не пропадёт: его последнее сохранение останется в облаке, а город с компьютера — копией в папке сохранений.", 14, false, hud.C_SOFT)
	_open_modal(w[0], "ask")


static func _size_text(m: Dictionary) -> String:
	var pop := int(m.get("pop", 0))
	var s := "жителей %s" % pop
	if m.has("day"):
		s += ", день %d" % int(m["day"])
	if m.has("n"):
		s += ", построек %d" % int(m["n"])
	return s


# ---------- сообщение ----------

func message(title: String, text: String) -> void:
	var w := _window(title, 480, true)
	_text(w[1], text)
	_buttons(w[1], [["Понятно", "", func(): _close_modal()]])
	_open_modal(w[0], "message")


# ---------- «подождите» ----------

## Окно «Сверяем город с облаком…» / «Сохраняем город в облаке…»; пустой текст — убрать
func busy(text: String) -> void:
	if text == "":
		if _modal_kind == "busy":
			_close_modal()
		return
	if _modal_kind == "ask" or _modal_kind == "login":
		return
	var p := _scroll(420)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var l: Label = hud._label(text, 24, false, hud.C_INK, hud.font_title)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.name = "busy_text"
	v.add_child(l)
	var s: Label = hud._wrap(hud._label("Это несколько секунд.", 15, false, hud.C_SOFT), 320)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	_open_modal(p, "busy")      # песочные часы — у самого окна (см. _open_modal), а не у всей игры


# ---------- кирпичики ----------

## Окно в резной рамке: заголовок посередине, разделитель; closable — крестик «закрыть»
func _window(title: String, w: float, closable: bool) -> Array:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", hud._box_panel(10))
	p.custom_minimum_size = Vector2(w, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var hdr := HBoxContainer.new()
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(36, 0)
	hdr.add_child(sp)
	var t: Label = hud._label(title, 30, false, hud.C_INK, hud.font_title)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_child(t)
	if closable:
		var close: Button = hud._bare("close", "Закрыть", 36, func(): _close_modal())
		close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hdr.add_child(close)
	else:
		var sp2 := Control.new()
		sp2.custom_minimum_size = Vector2(36, 0)
		hdr.add_child(sp2)
	v.add_child(hdr)
	v.add_child(hud._divider())
	return [p, v]


## Свиток (как у главного меню)
func _scroll(w: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", hud._box_scroll_v(18))
	p.custom_minimum_size = Vector2(w, 0)
	return p


func _open_modal(win: Control, kind: String) -> void:
	if _modal_kind == "ask" and kind != "ask":
		Account.me()._ask_open = false              # вопрос «какой город оставить» закрыт другим окном — сверка спросит снова
	_close_modal()
	_modal = Control.new()
	_modal.name = "modal_" + kind
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.07, 0.03, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.add_child(dim)
	if kind == "busy":
		# «подождите»: песочные часы над всем экраном, пока окно открыто. Курсор — у затемнения, не общий
		# (Input.set_default_cursor_shape): окно уходит вместе со сценой (выход из аккаунта, «Уничтожить город»),
		# и часы не могут остаться висеть над городом
		dim.mouse_default_cursor_shape = Control.CURSOR_WAIT
		_modal.mouse_default_cursor_shape = Control.CURSOR_WAIT
		win.mouse_default_cursor_shape = Control.CURSOR_WAIT
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal.add_child(cc)
	cc.add_child(win)
	add_child(_modal)
	_modal_kind = kind
	hud._hook_buttons(_modal)


func _close_modal() -> void:
	if _modal and is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null
	_modal_kind = ""


## Поле ввода: пергамент в бронзовой кайме (как нажатая плашка), золотая обводка у выбранного
func _field(secret: bool, hint: String) -> LineEdit:
	var e := LineEdit.new()
	e.secret = secret
	e.placeholder_text = hint
	e.custom_minimum_size = Vector2(FIELD_W, 46)
	e.add_theme_stylebox_override("normal", hud._box_pill(18, 8, "g_btn_on"))
	e.add_theme_stylebox_override("read_only", hud._box_pill(18, 8, "g_btn_on"))
	var fo := StyleBoxFlat.new()
	fo.bg_color = Color(0, 0, 0, 0)
	fo.draw_center = false
	fo.border_color = hud.C_GOLD
	fo.set_border_width_all(2)
	fo.set_corner_radius_all(20)
	fo.expand_margin_left = 1
	fo.expand_margin_right = 1
	e.add_theme_stylebox_override("focus", fo)
	e.add_theme_font_override("font", hud.font)
	e.add_theme_font_size_override("font_size", 19)
	e.add_theme_color_override("font_color", hud.C_INK)
	e.add_theme_color_override("font_placeholder_color", Color(hud.C_SOFT, 0.55))
	e.add_theme_color_override("caret_color", hud.C_INK)
	e.add_theme_color_override("selection_color", Color(hud.C_GOLD, 0.35))
	e.add_theme_color_override("font_selected_color", hud.C_INK)
	e.add_theme_constant_override("caret_width", 2)
	e.context_menu_enabled = true
	e.mouse_default_cursor_shape = Control.CURSOR_IBEAM
	return e


## Ссылка: мягкий коричневый текст, подчёркивание при наведении
func _link(text: String, cb: Callable) -> LinkButton:
	var b := LinkButton.new()
	b.text = text
	b.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	b.add_theme_font_override("font", hud.font_bold)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", hud.C_SOFT)
	b.add_theme_color_override("font_hover_color", hud.C_INK)
	b.add_theme_color_override("font_pressed_color", hud.C_GOLD)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _text(v: VBoxContainer, text: String, size := 18, bold := false, col: Color = Color("4a2c17")) -> Label:
	var l: Label = hud._wrap(hud._label(text, size, bold, col), maxf(200.0, (v.get_parent() as Control).custom_minimum_size.x - 70.0))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	return l


func _row(v: VBoxContainer, icon: String, text: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.add_child(hud._icon(icon, 34))
	var l: Label = hud._wrap(hud._label(text, 18, true), maxf(200.0, (v.get_parent() as Control).custom_minimum_size.x - 120.0))
	h.add_child(l)
	v.add_child(h)


## Ряд кнопок: [текст, "danger" | "", действие]
func _buttons(v: VBoxContainer, items: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 14)
	for it: Array in items:
		var b := Button.new()
		b.text = it[0]
		b.custom_minimum_size = Vector2(210, 50)
		b.add_theme_font_size_override("font_size", 19)
		b.add_theme_font_override("font", hud.font_bold)
		if it[1] == "danger":
			for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
				b.add_theme_color_override(c, hud.C_BAD)
		b.pressed.connect(it[2])
		h.add_child(b)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	v.add_child(gap)
	v.add_child(h)
	return h
