class_name UnionUi
extends RefCounted
## Вкладка «Союз» журнала города (docs/ONLINE_V2.md §4; SocialNet ↔ server/unions.js): без союза — что это такое,
## создать свой (название, герб, цвет, открытый или по заявке) или найти и вступить; в союзе — цель недели с тремя
## порогами, участники и их очки, заявки (глава), готовые фразы, «Выйти». Помощники окна — как у FriendsUi.

const C_GOOD := Color("4f7a2a")
const COLORS := [Color("a3283a"), Color("2f5585"), Color("4f6b3a"), Color("c99a2e"), Color("5e2350"), Color("3f7f86"), Color("6b4a2e"), Color("26211f")]

static var _name := ""
static var _emblem := 0
static var _color := 0
static var _open := true
static var _query := ""
static var _found: Array = []
static var _msg := ""
static var _busy := false


static func fill(hud, list: VBoxContainer) -> void:
	var sn := SocialNet.me()
	if not sn.changed.is_connected(_redraw.bind(hud)):
		sn.changed.connect(_redraw.bind(hud))
	var g = hud.game
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(hud._icon("legion", 30, hud.C_GOLD))
	head.add_child(hud._label("Союз городов", 20, false, hud.C_INK, hud.font_title))
	list.add_child(head)
	if not sn.signed_in():
		list.add_child(FriendsUi._text(hud, "Войдите в аккаунт (Меню → Настройки) — тогда можно вступить в союз с другими игроками."))
		return
	if int(g.city.cozy_v) < 1 or not (String(g.mode) in ["play", "new"]):
		list.add_child(FriendsUi._text(hud, "Союзы — в новой игре «Уютного Рима» (Меню → Новая игра)."))
		return
	if sn.union_unsupported:
		list.add_child(FriendsUi._text(hud, "Сервер ещё не умеет союзы — загляните позже."))
		return
	if sn.union.is_empty():
		list.add_child(FriendsUi._text(hud, "Связываемся с сервером…"))
		if not _busy:
			_busy = true
			sn.union_refresh(func(err):
				_busy = false
				_msg = err
				_redraw(hud))
		return
	var me: Dictionary = sn.union.get("me", {})
	if bool(me.get("in_union", false)):
		_mine(hud, list, sn)
	else:
		_none(hud, list, sn)
	if _msg != "":
		list.add_child(FriendsUi._text(hud, _msg, 14, hud.C_INK))


## Без союза: создать или найти
static func _none(hud, list: VBoxContainer, sn: SocialNet) -> void:
	var goals: Array = sn.union.get("goals", [])
	var gtxt := ""
	if goals.size() >= 3:
		gtxt = " Пороги недели: %d, %d и %d очков — награда до %d ден. и %d Славы каждому." % [int(goals[0]["pts"]), int(goals[1]["pts"]), int(goals[2]["pts"]),
			int(goals[2]["money"]), int(goals[2]["glory"])]
	list.add_child(FriendsUi._text(hud, "Союз — до %d городов, которые вместе выполняют цель недели. Очки приносят победы над городами (+3, поражение +1), гости из вашего города у других (+1), «нравится» (+1) и подарки друзьям (+2).%s" % [int(sn.union.get("max", 15)), gtxt]))
	list.add_child(hud._divider(8))
	list.add_child(hud._label("Создать свой союз", 16, true, hud.C_INK))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var e := _edit(hud, _name, "Название, например Волчья стая")
	e.text_changed.connect(func(t): _name = t)
	row.add_child(e)
	list.add_child(row)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	var emb: Array = sn.union.get("emblems", ["орёл"])
	row2.add_child(FriendsUi._btn(hud, "Герб: %s" % String(emb[_emblem % emb.size()]), "shield", func():
		_emblem = (_emblem + 1) % emb.size()
		_redraw(hud)))
	var sw := ColorRect.new()
	sw.color = COLORS[_color % COLORS.size()]
	sw.custom_minimum_size = Vector2(28, 28)
	row2.add_child(FriendsUi._btn(hud, "Цвет", "color", func():
		_color = (_color + 1) % COLORS.size()
		_redraw(hud)))
	row2.add_child(sw)
	row2.add_child(FriendsUi._btn(hud, "Вступают сразу" if _open else "По заявке", "keys", func():
		_open = not _open
		_redraw(hud)))
	row2.add_child(FriendsUi._btn(hud, "Создать", "plus", func():
		_act(hud, "create", {"name": _name, "emblem": _emblem, "color": _color, "open": _open}, "Союз создан — зовите друзей!")))
	list.add_child(row2)
	list.add_child(hud._divider(8))
	list.add_child(hud._label("Найти союз", 16, true, hud.C_INK))
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 8)
	var q := _edit(hud, _query, "Начало названия (пусто — лучшие союзы)")
	row3.add_child(q)
	var go := func(t: String):
		_query = t.strip_edges()
		_msg = "Ищем…"
		_redraw(hud)
		sn.union_list(_query, func(lst: Array, err: String):
			_found = lst
			_msg = err if err != "" else ("Союзов не нашлось" if lst.is_empty() else "")
			_redraw(hud))
	q.text_submitted.connect(go)
	row3.add_child(FriendsUi._btn(hud, "Найти", "view", func(): go.call(q.text)))
	list.add_child(row3)
	for u: Dictionary in _found:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		var sw2 := ColorRect.new()
		sw2.color = COLORS[int(u.get("color", 0)) % COLORS.size()]
		sw2.custom_minimum_size = Vector2(14, 28)
		r.add_child(sw2)
		var l: Label = hud._label("«%s» — %s, %d/%d, очков недели %d, глава «%s»" % [String(u["name"]), String(emb[int(u.get("emblem", 0)) % emb.size()]),
			int(u.get("n", u.get("members", 0))), int(u.get("max", 15)), int(u.get("week_pts", 0)), String(u.get("leader", "?"))], 14, false, hud.C_INK)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.add_child(l)
		var uid := int(u["id"])
		var full := int(u.get("n", 0)) >= int(u.get("max", 15))
		r.add_child(FriendsUi._btn(hud, "Вступить" if bool(u.get("open", true)) else "Заявка", "plus", func():
			_act(hud, "join", {"id": uid}, "Заявка отправлена — глава союза её увидит" if not bool(u.get("open", true)) else "Вы в союзе «%s»!" % String(u["name"])), full, "В союзе нет мест"))
		list.add_child(r)


## В союзе: цель недели, участники, заявки, фразы
static func _mine(hud, list: VBoxContainer, sn: SocialNet) -> void:
	var u: Dictionary = sn.union.get("union", {})
	var me: Dictionary = sn.union.get("me", {})
	var emb: Array = sn.union.get("emblems", ["орёл"])
	var leader := bool(me.get("leader", false))
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 8)
	var sw := ColorRect.new()
	sw.color = COLORS[int(u.get("color", 0)) % COLORS.size()]
	sw.custom_minimum_size = Vector2(16, 30)
	hr.add_child(sw)
	hr.add_child(hud._label("«%s» · герб: %s · %d из %d · %s" % [String(u.get("name", "")), String(emb[int(u.get("emblem", 0)) % emb.size()]),
		int(u.get("members", 0)), int(u.get("max", 15)), "вступают сразу" if bool(u.get("open", true)) else "по заявке"], 16, true, hud.C_INK))
	list.add_child(hr)
	# цель недели
	var goals: Array = u.get("goals", [])
	var pts := int(u.get("week_pts", 0))
	var top := int(goals[goals.size() - 1]["pts"]) if not goals.is_empty() else 100
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(540, 10)
	bar.show_percentage = false
	bar.max_value = top
	bar.value = mini(pts, top)
	list.add_child(bar)
	var gp := PackedStringArray()
	for gg: Dictionary in goals:
		gp.append("%d%s" % [int(gg["pts"]), " ✓" if pts >= int(gg["pts"]) else ""])
	list.add_child(FriendsUi._text(hud, "Цель недели: %d очков (пороги %s). До конца недели — %s. Ваши очки — %d." % [pts, ", ".join(gp),
		LegionPvpView._left(int(u.get("ends_in", 0))), int(me.get("week_pts", 0))], 14, hud.C_INK))
	if not goals.is_empty():
		list.add_child(FriendsUi._text(hud, "Награда каждому, кто принёс очки: %s." % ", ".join(PackedStringArray(goals.map(func(x): return "%d ден. и %d Славы" % [int(x["money"]), int(x["glory"])])))))
	list.add_child(hud._divider(8))
	# участники
	list.add_child(hud._label("Участники", 16, true, hud.C_INK))
	for m: Dictionary in u.get("list", []):
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		var l: Label = hud._label("%s«%s» — очков за неделю %d, рейтинг боёв %d" % ["★ " if bool(m.get("leader", false)) else "", String(m["name"]), int(m.get("week_pts", 0)), int(m.get("rating", 0))],
			14, bool(m.get("me", false)), hud.C_INK)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		var mid := int(m["id"])
		if leader and not bool(m.get("me", false)):
			r.add_child(FriendsUi._btn(hud, "Исключить", "close", func(): _act(hud, "kick", {"id": mid}, "«%s» больше не в союзе" % String(m["name"]))))
		list.add_child(r)
	var reqs: Array = sn.union.get("requests", [])
	if leader and not reqs.is_empty():
		list.add_child(hud._label("Заявки", 16, true, hud.C_INK))
		for q: Dictionary in reqs:
			var r := HBoxContainer.new()
			r.add_theme_constant_override("separation", 8)
			var l: Label = hud._label("«%s» — рейтинг боёв %d" % [String(q["name"]), int(q.get("rating", 0))], 14, false, hud.C_INK)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r.add_child(l)
			var qid := int(q["id"])
			r.add_child(FriendsUi._btn(hud, "Принять", "check", func(): _act(hud, "accept", {"id": qid, "yes": true}, "«%s» — в союзе" % String(q["name"]))))
			r.add_child(FriendsUi._btn(hud, "", "close", func(): _act(hud, "accept", {"id": qid, "yes": false}, "Заявка отклонена")))
			list.add_child(r)
	list.add_child(hud._divider(8))
	# фразы
	list.add_child(hud._label("Разговор союза", 16, true, hud.C_INK))
	var chat: Array = u.get("chat", [])
	for cm: Dictionary in chat.slice(maxi(0, chat.size() - 8)):
		list.add_child(FriendsUi._text(hud, "«%s»: %s" % [String(cm["name"]), String(cm["text"])], 14, hud.C_INK))
	if chat.is_empty():
		list.add_child(FriendsUi._text(hud, "Пока тихо — скажите что-нибудь."))
	var fr := HFlowContainer.new()
	fr.add_theme_constant_override("h_separation", 6)
	fr.add_theme_constant_override("v_separation", 6)
	var phrases: Array = sn.union.get("phrases", [])
	for i in phrases.size():
		var k := i
		fr.add_child(FriendsUi._btn(hud, String(phrases[i]), "", func(): _act(hud, "say", {"phrase": k}, "")))
	list.add_child(fr)
	list.add_child(hud._divider(8))
	list.add_child(FriendsUi._btn(hud, "Выйти из союза", "exit", func(): _act(hud, "leave", {}, "Вы вышли из союза")))


static func _edit(hud, text: String, ph: String) -> LineEdit:
	var e := LineEdit.new()
	e.max_length = 24
	e.text = text
	e.placeholder_text = ph
	e.custom_minimum_size = Vector2(360, 40)
	e.add_theme_stylebox_override("normal", hud._box_pill(14, 6, "g_btn_on"))
	e.add_theme_font_override("font", hud.font_bold)
	e.add_theme_font_size_override("font_size", 16)
	e.add_theme_color_override("font_color", hud.C_INK)
	e.add_theme_color_override("font_placeholder_color", Color(hud.C_SOFT, 0.55))
	e.add_theme_color_override("caret_color", hud.C_INK)
	return e


static func _redraw(hud) -> void:
	if hud == null or not is_instance_valid(hud) or hud.journal_panel == null or not hud.journal_panel.visible:
		return
	var g = hud.game
	if g == null or g.stories == null or g.stories.ui == null:
		return
	if String(g.stories.ui.journal_tab) == "union":
		g.stories.ui.fill_journal()


static func _act(hud, what: String, body: Dictionary, ok_text: String) -> void:
	if _busy:
		return
	_busy = true
	_msg = "…"
	_redraw(hud)
	SocialNet.me().union_do(what, body, func(err: String, _d: Dictionary):
		_busy = false
		_msg = err if err != "" else ok_text
		if err == "" and what == "create":
			_name = ""
		_redraw(hud))
