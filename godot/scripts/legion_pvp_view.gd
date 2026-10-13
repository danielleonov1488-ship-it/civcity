class_name LegionPvpView
extends RefCounted
## Части вкладки «Против городов» окна «Легион», которым нужен сервер (LegionNet): состав отряда соперника
## маленькими портретами, название нашего города в боях (переименовать), отбитые нападения, таблица лучших городов.
## Всё строится помощниками окна (LegionUi: _l, _title, _wl, _btn, _modal, _tr, _unit_tex…), чтобы выглядело так же.

const C_INK := Color("4a2c17")
const C_SOFT := Color("7a5a3c")
const C_GOOD := Color("4f7a2a")
const C_BAD := Color("b0402a")
const C_GOLD := Color("a8740f")


## Отряд соперника: портреты родов войск (одинаковые — «×n»), уровни в подсказке
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
	if order.is_empty():
		return
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	if net.has_method("pvp_rename"):
		var b := ui._btn("Имя", 0, 14, ui.hud.ico("quill", 64), "" if nm != "" else "Сервер ещё не ответил", func(): rename(ui))
		b.tooltip_text = "Переименовать город для боёв"
		h.add_child(b)
	box.add_child(h)
	var dw := int(st.get("def_wins", 0))
	var dl := int(st.get("def_losses", 0))
	if dw + dl > 0:
		box.add_child(ui._l("Отбито нападений: %d из %d" % [dw, dw + dl], 15, true, C_SOFT))


## Окно «Название города в боях»
static func rename(ui: LegionUi) -> void:
	var net = ui._net()
	if net == null or not net.has_method("pvp_rename"):
		return
	var p := ui._modal(500)
	var v: VBoxContainer = p.get_child(0)
	var t := ui._title("Название города в боях", 28)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(ui._wl("Его видят соперники, летописи их боёв и таблица лучших городов. От 3 до 24 знаков: буквы, цифры, пробел, дефис.", 440, 15, C_SOFT, false, true))
	var e := LineEdit.new()
	e.max_length = 24
	e.text = String((net.me_state as Dictionary).get("name", ""))
	e.custom_minimum_size = Vector2(420, 46)
	e.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	e.add_theme_stylebox_override("normal", ui.hud._box_pill(18, 8, "g_btn_on"))
	var fo := StyleBoxFlat.new()
	fo.draw_center = false
	fo.border_color = Color("d9a441")
	fo.set_border_width_all(2)
	fo.set_corner_radius_all(20)
	e.add_theme_stylebox_override("focus", fo)
	e.add_theme_font_override("font", ui.hud.font_bold)
	e.add_theme_font_size_override("font_size", 20)
	e.add_theme_color_override("font_color", C_INK)
	e.add_theme_color_override("caret_color", C_INK)
	e.add_theme_color_override("selection_color", Color(C_GOLD, 0.35))
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(e)
	var err := ui._wl("", 440, 15, C_BAD, true, true)
	v.add_child(err)
	var bh := HBoxContainer.new()
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	bh.add_theme_constant_override("separation", 12)
	var ok := ui._btn("Сохранить", 170, 19, null, "", func(): pass)
	var go := func():
		var nm := e.text.strip_edges()
		if nm.length() < 3:
			err.text = "Название — от 3 до 24 знаков"
			return
		ok.disabled = true
		err.text = ""
		net.pvp_rename(nm, func(msg: String):
			if not is_instance_valid(ok):
				return
			ok.disabled = false
			if msg != "":
				err.text = msg
				return
			ui._close_overlay()
			ui._say("Теперь ваш город в боях — «%s»" % nm)
			ui._rebuild())
	ok.pressed.connect(go)
	e.text_submitted.connect(func(_t): go.call())
	bh.add_child(ok)
	bh.add_child(ui._btn("Отмена", 140, 19, null, "", func(): ui._close_overlay()))
	v.add_child(bh)
	e.call_deferred("grab_focus")
	e.call_deferred("select_all")


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
	body.add_child(ui._wl("Собираем вести со всей империи…", 600, 17, C_SOFT, true, true))
	v.add_child(body)
	var bh := HBoxContainer.new()
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	bh.add_child(ui._btn("Закрыть", 160, 19, null, "", func(): ui._close_overlay()))
	v.add_child(bh)
	net.pvp_top(func(d: Dictionary, err: String):
		if not is_instance_valid(body):
			return
		ui.hud._clear(body)
		if err != "":
			body.add_child(ui._wl("Не получилось связаться с сервером: %s" % err, 600, 16, C_BAD, true, true))
			return
		_fill_top(ui, body, d))


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
