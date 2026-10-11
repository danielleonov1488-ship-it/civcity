class_name Hud
extends CanvasLayer
## Интерфейс в стиле Town to City: светлые панели с тонкой коричневой рамкой.
## Слева вверху — город (звание, жители, счастье, день, скорость), справа вверху — казна,
## слева — задания, снизу посередине — разделы стройки с карточками, слева снизу — кисти дорог,
## справа снизу — снос и сохранение. Карточка постройки — справа. Советник — слева снизу.

var game
var root: Control
var font: Font
var font_bold: Font
var theme_main: Theme
var icons := {}

var lbl_city: Label
var lbl_pop: Label
var lbl_happy: Label
var lbl_day: Label
var lbl_money: Label
var lbl_income: Label
var speed_btns := []
var tasks_box: VBoxContainer
var cats_box: HBoxContainer
var tray: PanelContainer
var tray_grid: HBoxContainer
var open_cat := ""
var hint_panel: PanelContainer
var hint_name: Label
var hint_text: Label
var hint_status: Label
var info_panel: PanelContainer
var info_box: VBoxContainer
var info_building := {}
var advisor_panel: PanelContainer
var adv_title: Label
var adv_text: Label
var toast_box: VBoxContainer
var buy_panel: PanelContainer
var buy_plot := Vector2i(-1, -1)
var road_btns := {}
var goods_panel: PanelContainer
var paused_speed := 1.0

const C_PANEL := Color("fbf6ea")
const C_EDGE := Color("b89a6c")
const C_INK := Color("3b2c1d")
const C_SOFT := Color("7a6650")
const C_GOOD := Color("4f7f2e")
const C_BAD := Color("b0412e")
const C_GOLD := Color("c9932e")


func _ready() -> void:
	layer = 10
	_fonts()
	theme_main = _theme()
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme_main
	add_child(root)
	_city_panel()
	_money_panel()
	_tasks_panel()
	_bottom_bar()
	_hint_panel()
	_info_panel()
	_advisor_panel()
	_buy_panel()
	_goods_panel()
	toast_box = VBoxContainer.new()
	toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_box.position = Vector2(-260, 74)
	toast_box.custom_minimum_size = Vector2(520, 0)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_box)
	_make_icons()


# ---------- оформление ----------

func _fonts() -> void:
	var lat: FontFile = load("res://assets/fonts/Nunito-latin-798ec6.woff2")
	var cyr: FontFile = load("res://assets/fonts/Nunito-cyrillic-373a90.woff2")
	lat.fallbacks = [cyr]
	var fv := FontVariation.new()
	fv.base_font = lat
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	font = fv
	var fb := FontVariation.new()
	fb.base_font = lat
	fb.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 850}
	font_bold = fb


func _box(bg: Color, edge: Color, r := 12, bw := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(bw)
	s.set_corner_radius_all(r)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(0.25, 0.17, 0.08, 0.22)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 2)
	return s


func _theme() -> Theme:
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 16
	t.set_stylebox("panel", "PanelContainer", _box(Color(C_PANEL, 0.96), C_EDGE))
	t.set_color("font_color", "Label", C_INK)
	var bn := _box(Color("fffdf6"), Color("cdb38a"), 10, 2)
	bn.content_margin_left = 10
	bn.content_margin_right = 10
	bn.content_margin_top = 6
	bn.content_margin_bottom = 6
	bn.shadow_size = 2
	var bh := bn.duplicate() as StyleBoxFlat
	bh.bg_color = Color("fff6dd")
	bh.border_color = Color("c9932e")
	var bp := bn.duplicate() as StyleBoxFlat
	bp.bg_color = Color("f3e2b8")
	bp.border_color = Color("a8782e")
	t.set_stylebox("normal", "Button", bn)
	t.set_stylebox("hover", "Button", bh)
	t.set_stylebox("pressed", "Button", bp)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("disabled", "Button", bn)
	t.set_color("font_color", "Button", C_INK)
	t.set_color("font_hover_color", "Button", C_INK)
	t.set_color("font_pressed_color", "Button", C_INK)
	t.set_color("font_disabled_color", "Button", Color(C_INK, 0.45))
	t.set_font("font", "Button", font_bold)
	t.set_font_size("font_size", "Button", 15)
	return t


func _label(text: String, size := 16, bold := false, col := C_INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if bold:
		l.add_theme_font_override("font", font_bold)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _panel(at: Vector2, preset := Control.PRESET_TOP_LEFT) -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_preset(preset)
	p.position = at
	root.add_child(p)
	return p


func mouse_over_ui() -> bool:
	var h := root.get_viewport().gui_get_hovered_control()
	return h != null and h != root


# ---------- город и казна ----------

func _city_panel() -> void:
	var p := _panel(Vector2(14, 12))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	lbl_city = _label("Деревня", 22, true)
	v.add_child(lbl_city)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	lbl_pop = _label("Жителей: 0", 15)
	lbl_happy = _label("Счастье: —", 15)
	row.add_child(lbl_pop)
	row.add_child(lbl_happy)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	v.add_child(row2)
	lbl_day = _label("День 1", 15, false, C_SOFT)
	lbl_day.custom_minimum_size = Vector2(110, 0)
	row2.add_child(lbl_day)
	for s: Array in [["❚❚", 0.0], ["▶", 1.0], ["▶▶", 2.0], ["▶▶▶", 4.0]]:
		var b := Button.new()
		b.text = s[0]
		b.custom_minimum_size = Vector2(44, 30)
		b.add_theme_font_size_override("font_size", 12)
		var sp: float = s[1]
		b.pressed.connect(func(): set_speed(sp))
		row2.add_child(b)
		speed_btns.append([b, sp])


func _money_panel() -> void:
	var p := _panel(Vector2(-14, 12), Control.PRESET_TOP_RIGHT)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	var row := HBoxContainer.new()
	v.add_child(row)
	row.add_child(_label("💰", 20))
	lbl_money = _label("3 000 / 4 000", 22, true)
	row.add_child(lbl_money)
	lbl_income = _label("+0 в день", 14, false, C_SOFT)
	lbl_income.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(lbl_income)
	var gb := Button.new()
	gb.text = "Товары и склады"
	gb.add_theme_font_size_override("font_size", 13)
	gb.pressed.connect(func(): goods_panel.visible = not goods_panel.visible; refresh())
	v.add_child(gb)


func _tasks_panel() -> void:
	var p := _panel(Vector2(14, 128))
	p.custom_minimum_size = Vector2(300, 0)
	tasks_box = VBoxContainer.new()
	tasks_box.add_theme_constant_override("separation", 6)
	p.add_child(tasks_box)


func _goods_panel() -> void:
	goods_panel = _panel(Vector2(-14, 130), Control.PRESET_TOP_RIGHT)
	goods_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	goods_panel.custom_minimum_size = Vector2(250, 0)
	goods_panel.visible = false


func fmt(v: float) -> String:
	var s := str(int(round(absf(v))))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out


func refresh() -> void:
	var c: City = game.city
	var r: int = c.max_rank
	lbl_city.text = "%s · %s" % ["Новый Рим", Defs.RANKS[r][1]]
	lbl_pop.text = "👥 %s" % fmt(c.stats["pop"])
	lbl_happy.text = "🙂 %d%%" % int(c.stats["happy"])
	var season: String = ["весна", "лето", "осень", "зима"][(c.day / 30) % 4]
	lbl_day.text = "День %d · %s" % [c.day + 1, season]
	lbl_money.text = "%s / %s" % [fmt(c.money), fmt(c.treasury_cap())]
	var inc: float = c.stats["income"]
	lbl_income.text = ("+" if inc >= 0 else "") + fmt(inc) + " в день"
	lbl_income.add_theme_color_override("font_color", C_GOOD if inc >= 0 else C_BAD)
	for sb in speed_btns:
		(sb[0] as Button).add_theme_color_override("font_color", C_GOLD if is_equal_approx(game.speed, sb[1]) else C_INK)
	# задания
	for ch in tasks_box.get_children():
		ch.queue_free()
	tasks_box.add_child(_label("Задания", 17, true))
	for g in c.active_goals(3):
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(290, 0)
		var prog := mini(c.goal_progress(g["id"]), int(g["need"]))
		b.text = "%s\n%d / %d · награда %d" % [g["text"], prog, g["need"], g["reward"]]
		b.add_theme_font_size_override("font_size", 14)
		b.tooltip_text = g["hint"]
		var tl: String = g.get("tool", "")
		var hint: String = g["hint"]
		b.pressed.connect(func():
			advisor(g["text"], hint)
			if tl != "":
				select_build(tl))
		tasks_box.add_child(b)
	# товары
	if goods_panel.visible:
		for ch in goods_panel.get_children():
			ch.queue_free()
		var v := VBoxContainer.new()
		goods_panel.add_child(v)
		v.add_child(_label("Склады (вместимость %d)" % int(c.stats["cap"]), 16, true))
		for g in Defs.GOODS:
			var row := HBoxContainer.new()
			var n := _label(Defs.GOODS[g]["name"], 14)
			n.custom_minimum_size = Vector2(140, 0)
			row.add_child(n)
			row.add_child(_label(str(int(c.goods[g])), 14, true))
			v.add_child(row)
		v.add_child(_label("Налоги %+d · торговля %+d · содержание −%d" % [int(c.stats["taxes"]), int(c.stats["trade"]), int(c.stats["upkeep"])], 13, false, C_SOFT))
	if open_cat != "":
		_update_cards()
	if not info_building.is_empty() and info_panel.visible:
		_fill_info()


func set_speed(s: float) -> void:
	game.speed = s
	refresh()


func toggle_pause() -> void:
	if game.speed > 0.0:
		paused_speed = game.speed
		set_speed(0.0)
	else:
		set_speed(paused_speed)


# ---------- нижняя панель: кисти дорог, разделы, снос ----------

func _bottom_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -74
	bar.offset_bottom = -12
	bar.add_theme_constant_override("separation", 16)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	# кисти дорог
	var roads := PanelContainer.new()
	var rh := HBoxContainer.new()
	rh.add_theme_constant_override("separation", 6)
	roads.add_child(rh)
	for t: Array in [["road", "Мостовая"], ["plaza", "Площадь"], ["path", "Тропа"], ["erase", "Ластик"]]:
		var b := Button.new()
		b.text = t[1]
		b.tooltip_text = {"road": "Каменная мостовая — главные улицы (R). Ведите с зажатой кнопкой. [ ] — ширина, Ctrl+Z — отменить.",
			"plaza": "Площадь из узорной плитки — для форумов и рынков.", "path": "Утоптанная тропа — почти даром.", "erase": "Стереть дорогу под кистью."}[t[0]]
		var tn: String = t[0]
		b.pressed.connect(func(): game.set_tool("" if game.tool == tn else tn))
		rh.add_child(b)
		road_btns[tn] = b
	bar.add_child(roads)
	# разделы
	var cats := PanelContainer.new()
	cats_box = HBoxContainer.new()
	cats_box.add_theme_constant_override("separation", 6)
	cats.add_child(cats_box)
	for c: Array in Defs.CATS:
		var b := Button.new()
		b.text = c[1]
		var cid: String = c[0]
		b.pressed.connect(func(): _toggle_cat(cid))
		cats_box.add_child(b)
	bar.add_child(cats)
	# снос и сохранение
	var tools := PanelContainer.new()
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 6)
	tools.add_child(th)
	var bd := Button.new()
	bd.text = "Снести"
	bd.tooltip_text = "Нажмите на постройку — вернётся половина цены (B)."
	bd.pressed.connect(func(): game.set_tool("" if game.tool == "bulldoze" else "bulldoze"))
	th.add_child(bd)
	road_btns["bulldoze"] = bd
	var bs := Button.new()
	bs.text = "Сохранить"
	bs.pressed.connect(func(): game.save(); toast("Город сохранён", "ok"))
	th.add_child(bs)
	bar.add_child(tools)
	# лоток с карточками над разделами
	tray = PanelContainer.new()
	tray.anchor_left = 0.5
	tray.anchor_right = 0.5
	tray.anchor_top = 1.0
	tray.anchor_bottom = 1.0
	tray.offset_left = -500
	tray.offset_right = 500
	tray.offset_top = -262
	tray.offset_bottom = -84
	tray.visible = false
	root.add_child(tray)
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(980, 160)
	tray.add_child(sc)
	tray_grid = HBoxContainer.new()
	tray_grid.add_theme_constant_override("separation", 8)
	sc.add_child(tray_grid)


func _toggle_cat(cid: String) -> void:
	if open_cat == cid:
		open_cat = ""
		tray.visible = false
		return
	open_cat = cid
	tray.visible = true
	_fill_cards()


func _fill_cards() -> void:
	for ch in tray_grid.get_children():
		ch.queue_free()
	for type in Defs.B:
		var d: Dictionary = Defs.B[type]
		if d["cat"] != open_cat:
			continue
		var b := Button.new()
		b.custom_minimum_size = Vector2(124, 150)
		b.set_meta("type", type)
		b.tooltip_text = "%s\n%s" % [d["name"], d["desc"]]
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 0)
		b.add_child(v)
		var img := TextureRect.new()
		img.custom_minimum_size = Vector2(120, 96)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img.texture = icons.get(type)
		img.name = "img"
		v.add_child(img)
		var n := _label(d["name"], 13, true)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n.custom_minimum_size = Vector2(118, 0)
		v.add_child(n)
		var pr := _label("", 13, false, C_SOFT)
		pr.name = "price"
		pr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(pr)
		var tp: String = type
		b.pressed.connect(func(): select_build(tp))
		tray_grid.add_child(b)
	_update_cards()


func _update_cards() -> void:
	var c: City = game.city
	for b in tray_grid.get_children():
		if not b.has_meta("type"):
			continue
		var type: String = b.get_meta("type")
		var d: Dictionary = Defs.B[type]
		var pr: Label = b.find_child("price", true, false)
		var img: TextureRect = b.find_child("img", true, false)
		if img and img.texture == null:
			img.texture = icons.get(type)
		if not c.unlocked(type):
			pr.text = "🔒 " + Defs.RANKS[int(d.get("rank", 0))][1]
			b.modulate = Color(1, 1, 1, 0.55)
		else:
			pr.text = "💰 %s" % fmt(d["cost"])
			b.modulate = Color(1, 1, 1, 1) if c.money >= float(d["cost"]) else Color(1, 0.85, 0.85, 0.85)


func select_build(type: String) -> void:
	if not Defs.B.has(type):
		return
	var cat: String = Defs.B[type]["cat"]
	if open_cat != cat and cat != "":
		open_cat = cat
		tray.visible = true
		_fill_cards()
	if not game.city.unlocked(type):
		toast("«%s» откроется со званием «%s»" % [Defs.B[type]["name"], Defs.RANKS[int(Defs.B[type].get("rank", 0))][1]], "warn")
		return
	game.set_tool(type)


# ---------- подсказка инструмента ----------

func _hint_panel() -> void:
	hint_panel = PanelContainer.new()
	hint_panel.anchor_left = 0.5
	hint_panel.anchor_right = 0.5
	hint_panel.anchor_top = 1.0
	hint_panel.anchor_bottom = 1.0
	hint_panel.offset_left = -330
	hint_panel.offset_right = 330
	hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(hint_panel)
	var v := VBoxContainer.new()
	hint_panel.add_child(v)
	hint_name = _label("", 17, true)
	hint_text = _label("", 14, false, C_SOFT)
	hint_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_status = _label("", 14, true, C_BAD)
	v.add_child(hint_name)
	v.add_child(hint_text)
	v.add_child(hint_status)
	hint_panel.visible = false


func on_tool(t: String) -> void:
	for k in road_btns:
		(road_btns[k] as Button).add_theme_color_override("font_color", C_GOLD if k == t else C_INK)
	hint_panel.visible = t != ""
	hint_panel.offset_bottom = -272 if tray.visible else -86
	hint_panel.offset_top = hint_panel.offset_bottom - 10
	hint_status.text = ""
	match t:
		"": return
		"road": _hint("Мостовая", "Ведите с зажатой левой кнопкой. [ ] — ширина кисти, Ctrl+Z — отменить мазок. Правая кнопка — отменить.")
		"plaza": _hint("Площадь", "Узорная плитка для форумов, рынков и фонтанов.")
		"path": _hint("Тропа", "Утоптанная земля — для окраин и полей. Почти даром.")
		"erase": _hint("Ластик", "Стирает дорогу под кистью.")
		"bulldoze": _hint("Снос", "Нажмите на постройку — вернётся половина цены. Центр города не сносится.")
		_:
			var d: Dictionary = Defs.B[t]
			_hint(d["name"] + " · 💰 " + fmt(d["cost"]), d["desc"] + ("  У дороги встанет фасадом к ней; Z / X — повернуть." if d["kind"] != "decor" else "  Z / X — повернуть."))


func _hint(n: String, t: String) -> void:
	hint_name.text = n
	hint_text.text = t


func tool_status(err: String) -> void:
	hint_status.text = err


# ---------- карточка постройки ----------

func _info_panel() -> void:
	info_panel = _panel(Vector2(-14, 200), Control.PRESET_TOP_RIGHT)
	info_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	info_panel.custom_minimum_size = Vector2(330, 0)
	info_box = VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 4)
	info_panel.add_child(info_box)
	info_panel.visible = false


func open_info(b: Dictionary) -> void:
	info_building = b
	info_panel.visible = true
	_fill_info()


func _fill_info() -> void:
	var b := info_building
	if not game.city.buildings.has(b["id"]):
		info_panel.visible = false
		return
	for ch in info_box.get_children():
		ch.queue_free()
	var d: Dictionary = Defs.B[b["type"]]
	var title: String = d["name"]
	if d["kind"] == "house":
		title = Defs.tiers(b["type"])[b["tier"]]["name"]
	elif d["kind"] == "center":
		title = Defs.CENTER_STAGES[mini(int(b["tier"]), Defs.CENTER_STAGES.size() - 1)]
	info_box.add_child(_label(title, 20, true))
	var desc := _label(d["desc"], 13, false, C_SOFT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(300, 0)
	info_box.add_child(desc)
	if d["kind"] == "house":
		var tiers := Defs.tiers(b["type"])
		var T: Dictionary = tiers[b["tier"]]
		info_box.add_child(_label("Жители: %d из %d · счастье %d%% · красота %.1f" % [b["pop"], T["cap"], b["happy"], b["beauty"]], 14))
		if not b["road"]:
			info_box.add_child(_label("Нет дороги у входа — переселенцы не придут", 14, true, C_BAD))
		if int(b["tier"]) + 1 < tiers.size():
			var N: Dictionary = tiers[int(b["tier"]) + 1]
			info_box.add_child(_label("Чтобы вырасти до «%s»:" % N["name"], 15, true))
			for need in N["needs"]:
				var ok: bool = b["needs"].get(need, false)
				info_box.add_child(_label(("✓ " if ok else "✗ ") + Defs.NEED_LABELS[need], 14, false, C_GOOD if ok else C_BAD))
			if N.has("beauty"):
				var okb: bool = float(b["beauty"]) >= float(N["beauty"])
				info_box.add_child(_label(("✓ " if okb else "✗ ") + "Красота %d+ (сейчас %.1f)" % [N["beauty"], b["beauty"]], 14, false, C_GOOD if okb else C_BAD))
		else:
			info_box.add_child(_label("Дом вырос до предела", 14, true, C_GOOD))
	elif d["kind"] == "center":
		info_box.add_child(_label("Звание города: %s" % Defs.RANKS[game.city.max_rank][1], 14))
		var nr: int = game.city.max_rank + 1
		if nr < Defs.RANKS.size():
			info_box.add_child(_label("Следующее — «%s» с %d жителей" % [Defs.RANKS[nr][1], Defs.RANKS[nr][0]], 14, false, C_SOFT))
		info_box.add_child(_label("Ждут жилья: %d семей" % game.city.settle_queue.size(), 14, false, C_SOFT))
	else:
		if d.has("jobs"):
			info_box.add_child(_label("Работники: %d%%" % int(float(b["staff"]) * 100.0), 14))
		if d.has("produces"):
			var prod := ""
			for g in d["produces"]:
				prod += "%s %+.0f в день  " % [Defs.GOODS[g]["name"], float(d["produces"][g])]
			info_box.add_child(_label(prod, 14))
		if d.has("radius"):
			info_box.add_child(_label("Обслуживает дома в радиусе %d м" % int(d["radius"]), 14))
		if d.has("upkeep"):
			info_box.add_child(_label("Содержание: %.1f в день" % float(d["upkeep"]), 14, false, C_SOFT))
		if not b["road"]:
			info_box.add_child(_label("Нет дороги у входа — не работает", 14, true, C_BAD))
	if not d.get("fixed", false):
		var bd := Button.new()
		bd.text = "Снести (+%s)" % fmt(float(d["cost"]) * Defs.REFUND)
		bd.pressed.connect(func(): game.city.remove(b); info_panel.visible = false)
		info_box.add_child(bd)


func close_panels() -> void:
	info_panel.visible = false
	buy_panel.visible = false
	goods_panel.visible = false
	if open_cat != "":
		open_cat = ""
		tray.visible = false


func house_event(b: Dictionary, up: bool) -> void:
	if up and Defs.B[b["type"]]["kind"] == "house" and int(b["tier"]) >= 2:
		toast("Дом вырос: «%s»" % Defs.tiers(b["type"])[b["tier"]]["name"], "ok")
	if info_building.get("id", -1) == b.get("id", -2):
		_fill_info()


# ---------- советник, сообщения, покупка земли ----------

func _advisor_panel() -> void:
	advisor_panel = _panel(Vector2(14, -300), Control.PRESET_BOTTOM_LEFT)
	advisor_panel.custom_minimum_size = Vector2(380, 0)
	advisor_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var v := VBoxContainer.new()
	advisor_panel.add_child(v)
	adv_title = _label("", 17, true)
	adv_text = _label("", 14)
	adv_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	adv_text.custom_minimum_size = Vector2(350, 0)
	v.add_child(adv_title)
	v.add_child(adv_text)
	var ok := Button.new()
	ok.text = "Понятно"
	ok.pressed.connect(func(): advisor_panel.visible = false)
	v.add_child(ok)
	advisor_panel.visible = false


func advisor(title: String, text: String) -> void:
	adv_title.text = "Марк: " + title
	adv_text.text = text
	advisor_panel.visible = true


func toast(text: String, kind := "") -> void:
	var p := PanelContainer.new()
	var l := _label(text, 15, true, C_BAD if kind == "warn" else C_INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(480, 0)
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_child(p)
	while toast_box.get_child_count() > 3:
		toast_box.get_child(0).queue_free()
		toast_box.remove_child(toast_box.get_child(0))
	var tw := create_tween()
	tw.tween_interval(3.2 if kind != "rank" else 6.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


func _buy_panel() -> void:
	buy_panel = _panel(Vector2(-180, -120), Control.PRESET_CENTER)
	buy_panel.custom_minimum_size = Vector2(360, 0)
	buy_panel.visible = false


func ask_buy(p: Vector2i) -> void:
	buy_plot = p
	for ch in buy_panel.get_children():
		ch.queue_free()
	var v := VBoxContainer.new()
	buy_panel.add_child(v)
	v.add_child(_label("Купить участок земли?", 18, true))
	v.add_child(_label("Участок 16×16 м — за %s денариев." % fmt(game.city.plot_price()), 14))
	var h := HBoxContainer.new()
	v.add_child(h)
	var yes := Button.new()
	yes.text = "Купить"
	yes.pressed.connect(func():
		if game.city.buy_plot(buy_plot):
			game._update_plot_signs()
			toast("Земля куплена!", "ok")
		else:
			toast("Не хватает денариев", "warn")
		buy_panel.visible = false)
	var no := Button.new()
	no.text = "Отмена"
	no.pressed.connect(func(): buy_panel.visible = false)
	h.add_child(yes)
	h.add_child(no)
	buy_panel.visible = true


# ---------- картинки для карточек ----------

func _make_icons() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(240, 192)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("efe6d4")
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	we.environment = e
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.light_energy = 2.0
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 30
	vp.add_child(cam)
	var holder := Node3D.new()
	vp.add_child(holder)
	_icons_async(vp, cam, holder)


func _icons_async(vp: SubViewport, cam: Camera3D, holder: Node3D) -> void:
	for type in Defs.B:
		if type == "center":
			continue
		var d: Dictionary = Defs.B[type]
		var tier := 3 if type == "house" else (2 if type == "domus" else 0)
		var g := Parts.ghost(Catalog.make(type, tier, 1))
		for gi: GeometryInstance3D in g.find_children("*", "GeometryInstance3D", true, false):
			gi.transparency = 0.0
		holder.add_child(g)
		var size := maxf(float(d["w"]), float(d["d"]))
		var hgt := 3.0 if d["kind"] == "decor" else 8.0
		cam.look_at_from_position(Vector3(size * 0.9, size * 0.8 + hgt * 0.35, size * 1.3), Vector3(0, minf(hgt, size) * 0.25, 0), Vector3.UP)
		cam.size = size
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		icons[type] = ImageTexture.create_from_image(vp.get_texture().get_image())
		g.queue_free()
		await get_tree().process_frame
	vp.queue_free()
	if open_cat != "":
		_update_cards()
