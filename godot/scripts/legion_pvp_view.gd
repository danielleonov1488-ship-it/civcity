class_name LegionPvpView
extends RefCounted
## Части вкладки «Против городов» окна «Легион», которым нужен сервер (LegionNet): состав отряда соперника
## маленькими портретами, название нашего города (кнопка «Имя» — окно CityName), отбитые нападения, таблица лучших городов.
## Всё строится помощниками окна (LegionUi: _l, _title, _wl, _btn, _modal, _tr, _unit_tex…), чтобы выглядело так же.

const C_INK := Color("4a2c17")
const C_SOFT := Color("7a5a3c")
const C_GOOD := Color("4f7a2a")
const C_BAD := Color("b0402a")
const C_GOLD := Color("a8740f")


## Отряд соперника: его герой (если есть — первым, в золотом кружке), портреты родов войск (одинаковые — «×n»),
## уровни в подсказке
static func squad_strip(ui: LegionUi, parent: Control, snap) -> void:
	if not (snap is Dictionary):
		return
	var order := []
	var by := {}
	for e in (snap as Dictionary).get("squad", []):
		if not (e is Dictionary) or not Legion.UNITS.has(String(e.get("type", ""))):
			continue
		var t := String(e["type"])
		if not by.has(t):
			by[t] = []
			order.append(t)
		by[t].append(int(e.get("level", 1)))
	var he := Legion.snap_hero_entry(snap)
	if order.is_empty() and he.is_empty():
		return
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not he.is_empty():
		var hc := Panel.new()
		hc.name = "rival_hero"
		hc.custom_minimum_size = Vector2(30, 30)
		hc.add_theme_stylebox_override("panel", ui.hud._medal("medal_on", 30))
		hc.mouse_filter = Control.MOUSE_FILTER_PASS
		var hs := Legion.snap_hero(he, clampf(float(snap.get("atk_b", 0.0)), 0.0, 0.6), clampf(float(snap.get("hp_b", 0.0)), 0.0, 0.6))
		hc.tooltip_text = "Их герой — %s, ур. %d: здоровье %d, урон %d" % [String(hs["name"]), int(hs["level"]), int(hs["hp"]), int(hs["atk"])]
		var ic := ui._tr(ui.hud.ico("caesar", 64), 22)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = 4
		ic.offset_top = 4
		ic.offset_right = -4
		ic.offset_bottom = -4
		hc.add_child(ic)
		h.add_child(hc)
	for t: String in order:
		var lv: Array = by[t]
		var lo: int = lv.min()
		var hi: int = lv.max()
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		var U: Dictionary = Legion.UNITS[t]
		cell.tooltip_text = "%s%s, ур. %s" % [U["many"] if lv.size() > 1 else U["name"], (" ×%d" % lv.size()) if lv.size() > 1 else "",
			str(lo) if lo == hi else "%d–%d" % [lo, hi]]
		var tr := ui._tr(ui._unit_tex(t), 30)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(tr)
		if lv.size() > 1:
			var l := ui._l("×%d" % lv.size(), 13, true, C_SOFT)
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(l)
		h.add_child(cell)
	parent.add_child(h)


## Под рейтингом: «Ваш город в боях: …» с кнопкой «Переименовать» и сколько нападений отбито
static func me_rows(ui: LegionUi, box: VBoxContainer, net) -> void:
	if net == null or not ("me_state" in net):
		return
	var st: Dictionary = net.me_state
	var nm := String(st.get("name", ""))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var l := ui._l("Ваш город в боях: «%s»" % nm if nm != "" else "Ваш город в боях: …", 15, true, C_INK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	l.tooltip_text = "Так ваш город видят соперники и таблица лучших городов"
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(l)
	if net.has_method("set_city_name"):
		var b := ui._btn("Имя", 0, 14, ui.hud.ico("quill", 64), "" if nm != "" else "Сервер ещё не ответил", func(): rename(ui))
		b.name = "RenameCity"
		if nm != "":
			b.tooltip_text = "Переименовать город (то же, что щелчок по табличке с названием)"
		h.add_child(b)
	box.add_child(h)
	var dw := int(st.get("def_wins", 0))
	var dl := int(st.get("def_losses", 0))
	if dw + dl > 0:
		box.add_child(ui._l("Отбито нападений: %d из %d" % [dw, dw + dl], 15, true, C_SOFT))


## Окно «Название города» — то же, что по щелчку по табличке города (CityName); после сохранения окно перерисуется
static func rename(ui: LegionUi) -> void:
	var net = ui._net()
	if net == null or not net.has_method("set_city_name"):
		return
	ui._close_overlay()
	CityName.open(ui.hud, func(nm: String):
		if is_instance_valid(ui) and ui.visible:
			ui._say("Теперь ваш город — «%s»" % nm)
			ui._rebuild())


## Окно «Лучшие города»: 50 первых по рейтингу побед и наше место
static func top(ui: LegionUi) -> void:
	var net = ui._net()
	if net == null or not net.has_method("pvp_top"):
		return
	var p := ui._modal(680)
	p.name = "TopCities"
	var v: VBoxContainer = p.get_child(0)
	var hh := HBoxContainer.new()
	hh.alignment = BoxContainer.ALIGNMENT_CENTER
	hh.add_theme_constant_override("separation", 10)
	hh.add_child(ui._tr(ui._ic39("trophy"), 52))
	var tt := ui._title("Лучшие города", 32)
	hh.add_child(tt)
	v.add_child(hh)
	v.add_child(ui._wl("Рейтинг побед над городами: растёт с победами, падает с поражениями. Открывает старшие чудеса света.", 600, 15, C_SOFT, false, true))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	body.custom_minimum_size = Vector2(620, 420)
	v.add_child(body)
	var bh := HBoxContainer.new()
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	bh.add_child(ui._btn("Закрыть", 160, 19, null, "", func(): ui._close_overlay()))
	v.add_child(bh)
	_top_load(ui, body)


## Запросить таблицу лучших (и снова — по «Повторить»). auto — после ошибки один раз повторить самим через 5 с
static func _top_load(ui: LegionUi, body: VBoxContainer, auto := true) -> void:
	var net = ui._net()
	ui.hud._clear(body)
	body.add_child(ui._wl("Собираем вести со всей империи…", 600, 17, C_SOFT, true, true))
	var wb: WeakRef = weakref(body)               # окно могли закрыть, пока ждали ответ
	net.pvp_top(func(d: Dictionary, err: String):
		var bx := wb.get_ref() as VBoxContainer
		if bx == null:
			return
		ui.hud._clear(bx)
		if err != "":
			var f: Dictionary = (net.last_fail as Dictionary).duplicate() if "last_fail" in net else {}
			if f.is_empty():
				f = {"title": "Не получилось", "text": err}
			var again := auto and bx.is_inside_tree()
			error_block(ui, bx, f, func(): _top_load(ui, bx, false), "пробуем снова сами…" if again else "")
			if again:
				# связь могла мигнуть — один раз пробуем снова сами, через 5 секунд
				bx.get_tree().create_timer(5.0).timeout.connect(func():
					var b2 := wb.get_ref() as VBoxContainer
					# окно закрыто или уже грузится/загружено по «Повторить» — не трогаем
					if b2 != null and b2.is_inside_tree() and b2.get_node_or_null("NetError") != null:
						_top_load(ui, b2, false))
			return
		_fill_top(ui, bx, d))


## Ошибка связи в окне: заголовок, что случилось и что делать, «Повторить» и мелкий код («Код: timeout · 14:32»)
static func error_block(ui: LegionUi, parent: Control, f: Dictionary, retry: Callable, note := "") -> void:
	var v := VBoxContainer.new()
	v.name = "NetError"
	v.add_theme_constant_override("separation", 6)
	v.add_child(ui._title(String(f.get("title", "Не получилось")), 22, C_BAD))
	var t := String(f.get("text", ""))
	if t != "":
		v.add_child(ui._wl(t, 600, 16, C_INK))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var b := ui._btn("Повторить", 0, 17, ui.hud.ico("redo", 64), "", retry)
	b.name = "Retry"
	h.add_child(b)
	var code := String(f.get("code", ""))
	if note != "":
		code = note if code == "" else code + " · " + note
	if code != "":
		var cl := ui._l(code, 13, false, C_SOFT)
		cl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(cl)
	v.add_child(h)
	parent.add_child(v)


static func _fill_top(ui: LegionUi, body: VBoxContainer, d: Dictionary) -> void:
	var list: Array = d.get("top", [])
	if list.is_empty():
		body.add_child(ui._wl("Пока в таблице никого нет — станьте первым!", 600, 17, C_SOFT, true, true))
		return
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(620, 380)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 4)
	sc.add_child(rows)
	var me_row: Control = null
	for e in list:
		if not (e is Dictionary):
			continue
		var r: Dictionary = e
		var mine := bool(r.get("me", false))
		var chip: PanelContainer = ui.hud._chip(mine, 8)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		var place := int(r.get("place", 0))
		var pl := ui._l(str(place), 20, true, [Color("b8860b"), Color("8a8f98"), Color("a0612b")][place - 1] if place >= 1 and place <= 3 else C_SOFT)
		pl.custom_minimum_size = Vector2(36, 0)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(pl)
		h.add_child(ui._tr(ui.hud.ico("laurels" if place <= 3 else "castle", 64), 30))
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", -3)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nl := ui._l(String(r.get("name", "?")) + ("  (вы)" if mine else ""), 17, true, C_INK)
		nl.clip_text = true
		tv.add_child(nl)
		var lvl := clampi(int(r.get("city_level", 0)), 0, Defs.LEVELS.size() - 1)
		var dw := int(r.get("def_wins", 0))
		var dt := dw + int(r.get("def_losses", 0))
		tv.add_child(ui._l("%s · побед %d из %d%s" % [Defs.LEVELS[lvl]["name"], int(r.get("wins", 0)), int(r.get("wins", 0)) + int(r.get("losses", 0)),
			(" · отбито %d из %d" % [dw, dt]) if dt > 0 else ""], 13, true, C_SOFT))
		h.add_child(tv)
		var rl := ui._l(ui.hud.fmt(float(r.get("rating", 0))), 22, true, C_GOLD if place <= 3 else C_INK)
		rl.custom_minimum_size = Vector2(80, 0)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(rl)
		chip.add_child(h)
		rows.add_child(chip)
		if mine:
			me_row = chip
	body.add_child(sc)
	var m: Dictionary = d.get("me", {})
	var pl2 := int(m.get("place", 0))
	var foot := ""
	if pl2 > 0:
		foot = "Ваше место: %d из %d · рейтинг %s" % [pl2, int(d.get("total", pl2)), ui.hud.fmt(float(m.get("rating", 0)))]
	else:
		foot = "Вас пока нет в таблице: выставьте отряд обороны и сразитесь с другим городом."
	body.add_child(ui._wl(foot, 600, 16, C_INK, true, true))
	if me_row != null:
		var show := func():
			if is_instance_valid(sc) and is_instance_valid(me_row):
				sc.ensure_control_visible(me_row)
		show.call_deferred()
