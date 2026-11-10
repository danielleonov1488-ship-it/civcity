class_name FriendsUi
extends RefCounted
## Вкладка «Друзья» журнала города («Уютный Рим», этап 6 — онлайн-уют; SocialNet ↔ server/social.js):
## наш город (сколько раз наши гости бывали у других, «нравится», кто добавил нас), найти город по названию и добавить
## в друзья, друзья — «В гости», «Подарок» (кошка или украшение), «Убрать»; откуда сейчас едут туристы и сколько это
## прибавляет гостиницам; подарки друзей в нашем городе. Всё строится помощниками окна (hud._label, _wrap, _icon…).

const C_GOOD := Color("4f7a2a")
const C_BAD := Color("b0402a")

static var _query := ""
static var _found: Array = []
static var _msg := ""
static var _gift_for := 0                     # у какого друга раскрыт ряд подарков
static var _busy := false


static func fill(hud, list: VBoxContainer) -> void:
	var sn := SocialNet.me()
	if not sn.changed.is_connected(_redraw.bind(hud)):
		sn.changed.connect(_redraw.bind(hud))
	var g = hud.game
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(hud._icon("family", 30, hud.C_GOLD))
	head.add_child(hud._label("Друзья и гости", 20, false, hud.C_INK, hud.font_title))
	list.add_child(head)
	if not sn.signed_in():
		list.add_child(_text(hud, "Войдите в аккаунт (Меню → Настройки) — тогда к вам поедут гости из городов других игроков, а друзьям можно дарить подарки и ходить к ним в гости."))
		return
	if int(g.city.cozy_v) < 1 or not (String(g.mode) in ["play", "new"]):
		list.add_child(_text(hud, "Друзья и гости из других городов — в новой игре «Уютного Рима» (Меню → Новая игра)."))
		return
	if sn.unsupported:
		list.add_child(_text(hud, "Сервер ещё не умеет друзей — загляните позже."))
		return
	if sn.state.is_empty():
		list.add_child(_text(hud, "Связываемся с сервером…"))
		if not _busy:
			_busy = true
			sn.refresh(func(err):
				_busy = false
				_msg = err
				_redraw(hud))
		return
	var me: Dictionary = sn.state.get("me", {})
	# наш город
	list.add_child(_text(hud, "Ваш город «%s». Гости из него бывали у других %s, «нравится» — %d, вас добавили в друзья — %d." % [
		String(me.get("name", g.city.name)), _times(int(me.get("visits", 0))), int(me.get("likes", 0)), int(me.get("followers", 0))], 15, hud.C_INK))
	var bonus := SocialNet.tour_bonus(g.city)
	var gl: Array = sn.state.get("guests", [])
	if not gl.is_empty():
		var names := PackedStringArray(gl.map(func(e): return "«%s»%s" % [String(e["name"]), " ♥" if bool(e.get("friend", false)) else ""]))
		list.add_child(_text(hud, "Туристы едут из: %s. Гостиницам это даёт +%d%% дохода (за город-друга +6%%, за прочий +3%%, до +40%%)." % [", ".join(names), roundi(bonus * 100.0)]))
	else:
		list.add_child(_text(hud, "Туристов из других городов пока нет: их города ещё не сыграли с картой города. Добавьте друзей — гости поедут от них."))
	list.add_child(hud._divider(8))
	# найти город
	list.add_child(hud._label("Добавить друга", 16, true, hud.C_INK))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var e := LineEdit.new()
	e.name = "friend_query"
	e.max_length = 24
	e.text = _query
	e.placeholder_text = "Название города, например Аквилея"
	e.custom_minimum_size = Vector2(360, 40)
	e.add_theme_stylebox_override("normal", hud._box_pill(14, 6, "g_btn_on"))
	e.add_theme_font_override("font", hud.font_bold)
	e.add_theme_font_size_override("font_size", 16)
	e.add_theme_color_override("font_color", hud.C_INK)
	e.add_theme_color_override("font_placeholder_color", Color(hud.C_SOFT, 0.55))
	e.add_theme_color_override("caret_color", hud.C_INK)
	row.add_child(e)
	var find := _btn(hud, "Найти", "view", func(): _do_find(hud, e.text))
	e.text_submitted.connect(func(t): _do_find(hud, t))
	row.add_child(find)
	list.add_child(row)
	for f: Dictionary in _found:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		var l: Label = hud._label(_line(f), 14, false, hud.C_INK)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.add_child(l)
		var fid := int(f["id"])
		var is_f := (sn.state.get("friends", []) as Array).any(func(x): return int(x["id"]) == fid)
		if is_f:
			r.add_child(hud._label("уже друг", 14, true, C_GOOD))
		else:
			r.add_child(_btn(hud, "В друзья", "plus", func(): _act(hud, func(cb): sn.add_friend(fid, cb), "«%s» — теперь ваш друг" % String(f["name"]))))
		list.add_child(r)
	if _msg != "":
		list.add_child(_text(hud, _msg, 14, hud.C_INK))
	list.add_child(hud._divider(8))
	# друзья
	var fl: Array = sn.state.get("friends", [])
	list.add_child(hud._label("Друзья (%d из %d) · подарков сегодня: %d из %d" % [fl.size(), int(me.get("friends_max", 30)),
		int(me.get("gifts_left", 0)), int(me.get("gift_day", 3))], 16, true, hud.C_INK))
	if fl.is_empty():
		list.add_child(_text(hud, "Пока никого. Спросите у друзей название их города (табличка вверху слева) и найдите его выше."))
	for f: Dictionary in fl:
		var fid := int(f["id"])
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		var l: Label = hud._label(_line(f), 14, false, hud.C_INK if bool(f.get("live", false)) else hud.C_SOFT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(250, 0)
		r.add_child(l)
		r.add_child(_btn(hud, "В гости", "view", func(): _visit(hud, fid)))
		r.add_child(_btn(hud, "Подарок", "mail", func():
			_gift_for = 0 if _gift_for == fid else fid
			_redraw(hud), int(me.get("gifts_left", 0)) <= 0, "Подарков на сегодня больше нет — завтра снова"))
		r.add_child(_btn(hud, "", "close", func(): _act(hud, func(cb): sn.unfriend(fid, cb), "«%s» больше не в друзьях" % String(f["name"]))))
		box.add_child(r)
		if _gift_for == fid:
			var gr := HFlowContainer.new()
			gr.add_theme_constant_override("h_separation", 6)
			gr.add_theme_constant_override("v_separation", 6)
			var kinds: Dictionary = sn.state.get("gifts", {})
			for k in kinds:
				var kind := String(k)
				gr.add_child(_btn(hud, String(kinds[k]).capitalize() if kind != "cat" else "Кошка", String(SocialNet.GIFT_ICON.get(kind, "mail")), func():
					_gift_for = 0
					_act(hud, func(cb): sn.gift(fid, kind, cb), "Подарок ушёл в «%s»: %s" % [String(f["name"]), String(kinds[k])])))
			box.add_child(gr)
		list.add_child(box)
	# подарки друзей у нас
	var got := gifts_here(g.city)
	if not got.is_empty():
		list.add_child(hud._divider(8))
		list.add_child(hud._label("Подарки друзей в вашем городе", 16, true, hud.C_INK))
		list.add_child(_text(hud, ", ".join(PackedStringArray(got)) + "."))


## Подарки в городе: «кошка Мурка — из «Брундизий»», «статуя — из …», и ещё не поставленные
static func gifts_here(c) -> Array:
	var out := []
	for k: Dictionary in c.cats:
		if String(k.get("gift", "")) != "":
			out.append("кошка %s — из «%s»" % [String(k["nm"]), String(k["gift"])])
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		if String(b.get("gift", "")) != "":
			out.append("%s — из «%s»" % [String((Defs.B.get(String(b["type"]), {}) as Dictionary).get("name", b["type"])).to_lower(), String(b["gift"])])
	for t in c.gifts:
		if Defs.B.has(String(t)):
			out.append("%s ×%d — ждёт места (в стройке, «Подарок»)" % [String(Defs.B[t]["name"]).to_lower(), (c.gifts[t] as Array).size()])
	return out


static func _line(f: Dictionary) -> String:
	var c: Dictionary = f.get("card", {}) if typeof(f.get("card")) == TYPE_DICTIONARY else {}
	var s := "«%s»" % String(f.get("name", "?"))
	if not c.is_empty():
		s += " — %s, %d жит." % [String(c.get("rank", "")), int(c.get("pop", 0))]
		if String(c.get("title", "")) != "":
			s += ", %s" % String(c["title"])
		if String(c.get("hero", "")) != "":
			s += ", герой %s" % String(c["hero"])
	if not bool(f.get("live", true)):
		s += " (давно не заходил)"
	return s


static func _times(n: int) -> String:
	if n % 10 in [2, 3, 4] and not (n % 100 in [12, 13, 14]):
		return "%d раза" % n
	return "%d раз" % n


static func _text(hud, t: String, sz := 14, col = null) -> Label:
	return hud._wrap(hud._label(t, sz, false, hud.C_SOFT if col == null else col), 540)


static func _btn(hud, text: String, icon: String, cb: Callable, off := false, why := "") -> Button:
	var b := Button.new()
	b.text = text
	if icon != "":
		b.icon = hud.ico(icon, 22)
	hud._small_btn(b)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.disabled = off
	if off and why != "":
		b.tooltip_text = why
	b.pressed.connect(cb)
	return b


static func _redraw(hud) -> void:
	if hud == null or not is_instance_valid(hud) or hud.journal_panel == null or not hud.journal_panel.visible:
		return
	var g = hud.game
	if g == null or g.stories == null or g.stories.ui == null:
		return
	if String(g.stories.ui.journal_tab) == "friends":
		g.stories.ui.fill_journal()


static func _do_find(hud, t: String) -> void:
	_query = t.strip_edges()
	if _query.length() < 2:
		_msg = "Напишите хотя бы две буквы названия"
		_found = []
		_redraw(hud)
		return
	_msg = "Ищем…"
	_redraw(hud)
	SocialNet.me().find(_query, func(lst: Array, err: String):
		_found = lst
		_msg = err if err != "" else ("Такого города не нашлось — проверьте название" if lst.is_empty() else "")
		_redraw(hud))


## Действие с сервером: пока идёт — «…», потом строка-итог
static func _act(hud, call: Callable, ok_text: String) -> void:
	if _busy:
		return
	_busy = true
	_msg = "…"
	_redraw(hud)
	call.call(func(err: String):
		_busy = false
		_msg = err if err != "" else ok_text
		if err == "" and hud.game and hud.game.sound:
			hud.game.sound.ui("coins")
		_redraw(hud))


static func _visit(hud, id: int) -> void:
	if _busy:
		return
	_busy = true
	_msg = "Собираемся в дорогу…"
	_redraw(hud)
	SocialNet.me().visit(id, func(v: Dictionary, err: String):
		_busy = false
		if err != "" or v.is_empty():
			_msg = err if err != "" else "Не получилось"
			_redraw(hud)
			return
		_msg = ""
		hud.game.visit_city(v))
