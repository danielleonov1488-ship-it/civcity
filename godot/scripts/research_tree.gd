extends Control
## Дерево исследований: карточки в столбцах рангов, связи рисуются под ними.

const CARD := Vector2(170, 76)
const STEP := Vector2(222, 94)
var hud
var scroll: ScrollContainer
var detail: VBoxContainer
var only_available: CheckBox
var cards: Dictionary = {}
var selected := ""
var study: Button
var _state := ""
var _first := ""
var open_scroll := false


func setup(owner_hud, parent: VBoxContainer) -> void:
	hud = owner_hud
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 12)
	tools.add_child(hud._icon("research", 26, Hud.C_SOFT))
	hud.lbl_research_rp = hud._label("0", 22, true)
	tools.add_child(hud.lbl_research_rp)
	hud.lbl_research_rate = hud._label("", 16, true, Hud.C_GOOD)
	tools.add_child(hud.lbl_research_rate)
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(space)
	only_available = CheckBox.new()
	only_available.name = "OnlyAvailable"
	only_available.text = "Только доступные"
	only_available.toggled.connect(func(_on: bool): rebuild(true))
	tools.add_child(only_available)
	parent.add_child(tools)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	parent.add_child(body)
	scroll = ScrollContainer.new()
	scroll.name = "ResearchScroll"
	scroll.custom_minimum_size = Vector2(764, 484)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	hud.research_box = VBoxContainer.new()
	scroll.add_child(hud.research_box)
	hud.research_box.add_child(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var side := ScrollContainer.new()
	side.name = "ResearchDetailScroll"
	side.custom_minimum_size = Vector2(264, 484)
	side.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(side)
	detail = VBoxContainer.new()
	detail.name = "ResearchDetails"
	detail.custom_minimum_size.x = 246
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 10)
	side.add_child(detail)
	set_process(false)


func state_key() -> String:
	var c: City = hud.game.city
	return str([c.level, int(c.rp), c.research, only_available.button_pressed])


func refresh() -> void:
	if _state != state_key():
		rebuild()
	else:
		# Миниатюры стройки могут догрузиться после открытия окна.
		for id: String in cards:
			var img: TextureRect = cards[id].get_node("Picture")
			img.texture = picture(Defs.research(id))


func rebuild(auto_scroll := false) -> void:
	_state = state_key()
	hud._clear(self)
	cards.clear()
	_first = ""
	var c: City = hud.game.city
	var height := 480.0
	for tier in Defs.LEVELS.size():
		var head := HBoxContainer.new()
		head.position = Vector2(28 + tier * STEP.x, 10)
		head.size = Vector2(CARD.x, 38)
		head.add_child(hud._icon("lock" if tier > c.level else "level", 22, Hud.C_SOFT))
		head.add_child(hud._label(Defs.LEVELS[tier]["name"], 19, false, Hud.C_SOFT if tier > c.level else Hud.C_INK, hud.font_title))
		add_child(head)
		var row := 0
		for r: Dictionary in Defs.RESEARCH:
			if int(r["lvl"]) != tier:
				continue
			var id := String(r["id"])
			var why := c.can_research(id)
			if only_available.button_pressed and why != "":
				continue
			if _first == "" and why == "":
				_first = id
			var b := make_card(r)
			b.position = Vector2(28 + tier * STEP.x, 66 + row * STEP.y)
			add_child(b)
			cards[id] = b
			row += 1
		height = maxf(height, 80 + row * STEP.y)
	custom_minimum_size = Vector2(Defs.LEVELS.size() * STEP.x + 28, height)
	if cards.is_empty():
		var empty: Label = hud._label("Пока нет доступных исследований", 20, true, Hud.C_SOFT)
		empty.position = Vector2(28, 80)
		add_child(empty)
	if selected == "":
		selected = _first if _first != "" else String(Defs.RESEARCH[0]["id"])
	show_detail(selected)
	queue_redraw()
	if auto_scroll:
		focus_card(_first if _first != "" else selected)


func building_ids(id: String) -> Array[String]:
	var out: Array[String] = []
	for type: String in Defs.B:
		if hud.game.city.unlock_id(type) == id and Defs.B[type].get("research_list", true):
			out.append(type)                     # мельницы — только украшения, в исследованиях их нет (FIX1)
	return out


func picture(r: Dictionary) -> Texture2D:
	for type: String in building_ids(String(r["id"])):
		if hud.icons.get(type) != null:
			return hud.icons[type]
	return hud.ico(String(r["icon"]), 128)


func rim(col: Color, glow := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fff9ec")
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	if glow:
		sb.shadow_color = Color(col, 0.24)
		sb.shadow_size = 7
	return sb


func make_card(r: Dictionary) -> Button:
	var c: City = hud.game.city
	var id := String(r["id"])
	var done := c.research.has(id)
	var available := c.can_research(id) == ""
	var locked: bool = not done and (Defs.story_of(r) != "" or int(r["lvl"]) > c.level or (r.has("after") and not c.research.has(r["after"])))
	var col := Hud.C_GOOD if done else (Hud.C_GOLD if available else Color("ae9e89"))
	var b := Button.new()
	b.name = "Research_" + id
	b.set_meta("rid", id)
	b.set_meta("state", "done" if done else ("available" if available else ("locked" if locked else "points")))
	b.size = CARD
	b.custom_minimum_size = CARD
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", rim(col, available))
	b.add_theme_stylebox_override("hover", rim(Hud.C_GOLD, true))
	b.add_theme_stylebox_override("pressed", rim(Hud.C_GOLD))
	b.tooltip_text = tooltip(r)
	var img := TextureRect.new()
	img.name = "Picture"
	img.position = Vector2(5, 14)
	img.size = Vector2(48, 48)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.texture = picture(r)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(img)
	var label: Label = hud._label(String(r["name"]), 14, true, Hud.C_SOFT if locked else Hud.C_INK)
	label.position = Vector2(57, 6)
	label.size = Vector2(106, 42)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.max_lines_visible = 2
	b.add_child(label)
	var cost := HBoxContainer.new()
	cost.position = Vector2(57, 50)
	cost.add_child(hud._icon("check" if done else "research", 18, Hud.C_GOOD if done else Hud.C_SOFT))
	cost.add_child(hud._label("Изучено" if done else str(r["cost"]), 14, true, Hud.C_GOOD if done else (Hud.C_BAD if not locked and c.rp < float(r["cost"]) else Hud.C_SOFT)))
	b.add_child(cost)
	for child: Control in b.find_children("*", "Control", true, false):
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if locked:
		hud._grey(img)
		b.self_modulate = Color(0.86, 0.86, 0.86)
	b.pressed.connect(func():
		show_detail(id)
		hud.show_pointer({"kind": "study", "tip": ""}))
	if hud.game.mode in ["new", "play"] and c.is_new_r(id):
		var pill: Control = hud._new_pill(b, "corner")
		pill.visible = true
		b.mouse_entered.connect(func():
			if c.mark_seen_r(id):
				pill.visible = false
				hud.update_new_marks())
	return b


func tooltip(r: Dictionary) -> String:
	var id := String(r["id"])
	var text := I18n.t(String(r["name"]))
	if r.has("desc"):
		text += "\n" + I18n.t(String(r["desc"]))
	var decor: Array[String] = []
	for type: String in building_ids(id):
		var d: Dictionary = Defs.B[type]
		if String(d.get("cat", "")) == "decor":
			decor.append(I18n.t(String(d["name"])))
		else:
			text += "\n" + I18n.t("Открывает: %s — %s") % [I18n.t(String(d["name"])), I18n.t(String(d.get("desc", "")))]
	if not decor.is_empty():
		text += "\n" + I18n.t("Открывает украшения: %s.") % ", ".join(decor)
		if hud.game.city.econ >= 1 and id in Defs.DECOR_SETS:
			text += "\n" + I18n.t("Набор: три разных вида из него рядом с домом — ещё +%d%% счастья.") % Defs.SET_BONUS
	return text + "\n" + I18n.t(String(hud.game.city.can_research(id)))


func paragraph(text: String, color := Hud.C_INK) -> void:
	var l: Label = hud._label(text, 16, false, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 238
	detail.add_child(l)


func show_detail(id: String) -> void:
	var r := Defs.research(id)
	if r.is_empty():
		return
	selected = id
	hud._clear(detail)
	var img := TextureRect.new()
	img.custom_minimum_size = Vector2(238, 126)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.texture = picture(r)
	detail.add_child(img)
	var title: Label = hud._label(String(r["name"]), 23, false, Hud.C_INK, hud.font_title)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = 238
	detail.add_child(title)
	var c: City = hud.game.city
	var why := c.can_research(id)
	detail.add_child(hud._row("research", "Стоимость", str(r["cost"]), Hud.C_BAD if c.rp < float(r["cost"]) else Hud.C_INK))
	study = Button.new()
	study.name = "StudyResearch"
	study.text = "Изучено" if c.research.has(id) else "Изучить"
	study.disabled = why != ""
	study.custom_minimum_size.y = 38
	study.tooltip_text = why
	study.pressed.connect(func():
		if c.do_research(id):
			hud._fill_research()
			if hud.tray.visible:
				hud._fill_cards()
		else:
			refresh())
	detail.add_child(study)
	if why != "":
		paragraph(why, Hud.C_GOOD if c.research.has(id) else Hud.C_SOFT)
	if r.has("after"):
		paragraph(I18n.t("После: «%s»") % I18n.t(String(Defs.research(r["after"])["name"])), Hud.C_SOFT)
	if r.has("desc"):
		paragraph(String(r["desc"]))
	if c.econ >= 1 and id in Defs.DECOR_SETS:
		paragraph(I18n.t("Набор: три разных вида из него рядом с домом — ещё +%d%% счастья.") % Defs.SET_BONUS, Hud.C_GOOD)
	for type: String in building_ids(id):
		var d: Dictionary = Defs.B[type]
		paragraph(I18n.t("Открывает постройку: %s") % I18n.t(String(d["name"])))
		if d.has("bonus"):
			var category := String(Defs.NEEDS.get(String(d.get("sub", "")), {}).get("name", ""))
			paragraph(I18n.t("+%d%% счастья домам рядом") % int(d["bonus"]) + (" · " + I18n.t(category) if category != "" else ""), Hud.C_GOOD)
		elif d.has("rp"):
			paragraph(I18n.t("+%s очков исследований в час") % Hud.fmt_rate(float(d["rp"])), Hud.C_GOOD)
		elif d.has("deco"):
			paragraph(I18n.t("Красота: +%d") % int(d["deco"]), Hud.C_GOOD)
		if d.has("desc") and not r.has("desc"):
			paragraph(String(d["desc"]))
		paragraph(I18n.t("Постройка: %s ден.") % hud.fmt(d.get("cost", 0)), Hud.C_SOFT)
		if d.has("jobs"):
			var jobs: Array[String] = []
			for cls: String in d["jobs"]:
				jobs.append("%d %s" % [int(d["jobs"][cls]), I18n.t(String(Defs.CLASSES[cls]["name"]))])
			paragraph(I18n.t("Рабочие: %s") % ", ".join(jobs), Hud.C_SOFT)
	var eta: String = hud.rp_eta(float(r["cost"])) if not c.research.has(id) else ""
	if eta != "":
		paragraph(I18n.t("Хватит через %s") % eta, Hud.C_SOFT)


func focus_card(id: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(scroll) and cards.has(id) and is_instance_valid(cards[id]):
		scroll.ensure_control_visible(cards[id])


func reveal(id: String) -> void:
	if only_available.button_pressed and not cards.has(id):
		only_available.set_pressed_no_signal(false)
		rebuild()
	show_detail(id)
	focus_card(id)


func _draw() -> void:
	if hud == null:
		return
	for r: Dictionary in Defs.RESEARCH:
		var id := String(r["id"])
		var parent := String(r.get("after", ""))
		if not cards.has(id) or not cards.has(parent):
			continue
		var a: Control = cards[parent]
		var b: Control = cards[id]
		var col := Hud.C_GOOD if hud.game.city.research.has(parent) else Color("9c7753")
		var points := PackedVector2Array()
		if is_equal_approx(a.position.x, b.position.x):
			var p := a.position + Vector2(0, CARD.y * 0.5)
			var q := b.position + Vector2(0, CARD.y * 0.5)
			points = PackedVector2Array([p, p - Vector2(14, 0), Vector2(q.x - 14, q.y), q])
		else:
			var p := a.position + Vector2(CARD.x, CARD.y * 0.5)
			var q := b.position + Vector2(0, CARD.y * 0.5)
			var bend := maxf(24, (q.x - p.x) * 0.5)
			for i in 25:
				points.append(p.bezier_interpolate(p + Vector2(bend, 0), q - Vector2(bend, 0), q, float(i) / 24.0))
		draw_polyline(points, col, 3.0, true)
		var end := points[points.size() - 1]
		draw_colored_polygon(PackedVector2Array([end, end + Vector2(-6, -4), end + Vector2(-6, 4)]), col)
