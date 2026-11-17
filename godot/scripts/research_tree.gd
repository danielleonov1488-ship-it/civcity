extends VBoxContainer
## Один ранг на странице, восемь маленьких картинок в ряд, без прокрутки.

const CARD := Vector2(92, 112)
const GAP := 8.0
const COLUMNS := 8
const BADGE_GOOD := Color("487333")
const BADGE_BAD := Color("a53d32")
var hud
var scroll: ScrollContainer
var detail: VBoxContainer
var only_available: CheckBox
var cards: Dictionary = {}
var sections: Dictionary = {}
var rank_tabs: Dictionary = {}
var current_rank := 0
var _rank_bar: HBoxContainer
var selected := ""
var study: Button
var popup: PanelContainer
var open_scroll := false
var _state := ""
var _first := ""
var _built := false
var _buildings: Dictionary = {}
var _done_material: ShaderMaterial
var _badge_good: StyleBoxFlat
var _badge_bad: StyleBoxFlat
var _empty: Label
var _popup_title: Label
var _popup_picture: TextureRect
var _popup_cost: Label
var _popup_reason: Label
var _detail_scroll: ScrollContainer
var _focus_serial := 0


func setup(owner_hud, parent: VBoxContainer) -> void:
	hud = owner_hud
	var tools := HBoxContainer.new()
	tools.name = "ResearchTools"
	tools.add_theme_constant_override("separation", 12)
	tools.add_child(CityStyle.pictogram("research", 20))
	hud.lbl_research_rp = hud._label("0", 16, true, CityStyle.INK)
	tools.add_child(hud.lbl_research_rp)
	hud.lbl_research_rate = hud._label("", 13, true, CityStyle.INK)
	tools.add_child(hud.lbl_research_rate)
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(space)
	only_available = CheckBox.new()
	only_available.name = "OnlyAvailable"
	only_available.text = "Только доступные"
	only_available.add_theme_font_size_override("font_size", 13)
	only_available.toggled.connect(func(_on: bool):
		close_detail()
		rebuild(true))
	tools.add_child(only_available)
	parent.add_child(tools)
	_rank_bar = HBoxContainer.new()
	_rank_bar.name = "ResearchRankTabs"
	_rank_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_rank_bar.add_theme_constant_override("separation", 8)
	parent.add_child(_rank_bar)
	scroll = ScrollContainer.new()
	scroll.name = "ResearchScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = false
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	hud.research_box = VBoxContainer.new()
	hud.research_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(hud.research_box)
	hud.research_box.add_child(self)
	name = "ResearchRanks"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout_sections)
	scroll.get_v_scroll_bar().value_changed.connect(func(_value: float): _place_popup())
	_make_popup()
	hud.root.resized.connect(fit_window)
	fit_window()


func fit_window() -> void:
	hud.research_panel.custom_minimum_size = Vector2(900, 460)
	scroll.custom_minimum_size = Vector2(792, 284)
	_detail_scroll.custom_minimum_size.y = clampf(hud.root.size.y - 510, 100, 160)
	hud._snug(hud.research_panel)
	_layout_sections()
	_place_popup.call_deferred()


func state_key() -> String:
	var c: City = hud.game.city
	return str([c.level, int(c.rp), c.econ, c.cozy_v, c.legion_v, c.research, c.tips.get("seen_r", {}), only_available.button_pressed, current_rank])


func refresh() -> void:
	if not _built or _state != state_key():
		rebuild()
	else:
		# Миниатюры стройки могут догрузиться после открытия окна.
		for id: String in cards:
			_update_picture(cards[id].get_node("Picture"), Defs.research(id))
		if popup.visible:
			_update_picture(_popup_picture, Defs.research(selected))
			_update_detail_state()


func rebuild(auto_scroll := false) -> void:
	# Имя оставлено для подсказок и прежних тестов. Узлы создаём только один раз.
	if not _built:
		_build()
	_state = state_key()
	_first = ""
	for r: Dictionary in Defs.RESEARCH:
		var id := String(r["id"])
		if _first == "" and hud.game.city.can_research(id) == "":
			_first = id
		_update_card(cards[id], r)
	_layout_sections()
	if popup.visible:
		if not (cards[selected] as Control).visible:
			close_detail()
		else:
			_update_detail_state()
	if auto_scroll:
		focus_rank(hud.game.city.level)


func _build() -> void:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nvoid fragment() {\n vec4 c = texture(TEXTURE, UV) * COLOR;\n float g = dot(c.rgb, vec3(0.3, 0.59, 0.11));\n COLOR = vec4(mix(c.rgb, vec3(g), 0.38), c.a * 0.88);\n}\n"
	_done_material = ShaderMaterial.new()
	_done_material.shader = shader
	_badge_good = _badge_style(BADGE_GOOD)
	_badge_bad = _badge_style(BADGE_BAD)
	current_rank = clampi(hud.game.city.level, 0, Defs.LEVELS.size() - 1)
	for tier in Defs.LEVELS.size():
		var tab := Button.new()
		tab.name = "RankTab_%d" % tier
		tab.toggle_mode = true
		tab.custom_minimum_size = Vector2(84, 52)
		tab.tooltip_text = String(Defs.LEVELS[tier]["name"])
		hud._card_button(tab)
		tab.custom_minimum_size = Vector2(84, 52)
		var tab_body := VBoxContainer.new()
		tab_body.add_theme_constant_override("separation", 0)
		tab.add_child(tab_body)
		tab_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 3)
		var medal: TextureRect = CityStyle.pictogram("level", 24)
		medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tab_body.add_child(medal)
		var caption: Label = hud._label(String(Defs.LEVELS[tier]["name"]), 11, true, CityStyle.INK)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.clip_text = true
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tab_body.add_child(caption)
		for child: Control in tab.find_children("*", "Control", true, false):
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tab.pressed.connect(select_rank.bind(tier))
		_rank_bar.add_child(tab)
		rank_tabs[tier] = tab
		var section := Control.new()
		section.name = "Rank_%d" % tier
		section.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(section)
		sections[tier] = section
		var ribbon := PanelContainer.new()
		ribbon.name = "Ribbon"
		ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ribbon.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		section.add_child(ribbon)
		var heading := HBoxContainer.new()
		heading.alignment = BoxContainer.ALIGNMENT_CENTER
		heading.add_theme_constant_override("separation", 12)
		heading.add_child(CityStyle.pictogram("housing", 18))
		heading.add_child(hud._label(String(Defs.LEVELS[tier]["name"]), 18, false, CityStyle.INK, hud.font_title))
		ribbon.add_child(heading)
		var grid := GridContainer.new()
		grid.name = "Items"
		grid.add_theme_constant_override("h_separation", int(GAP))
		grid.add_theme_constant_override("v_separation", int(GAP))
		section.add_child(grid)
		for r: Dictionary in Defs.RESEARCH:
			if int(r["lvl"]) != tier:
				continue
			var id := String(r["id"])
			var item := make_card(r)
			grid.add_child(item)
			cards[id] = item
		var wash := ColorRect.new()
		wash.name = "RankLockOverlay"
		wash.color = Color(1.0, 0.97, 0.91, 0.40)
		wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		section.add_child(wash)
		var notice := HBoxContainer.new()
		notice.name = "RankLockNotice"
		notice.alignment = BoxContainer.ALIGNMENT_CENTER
		notice.add_theme_constant_override("separation", 8)
		notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
		notice.add_child(CityStyle.pictogram("lock", 20))
		notice.add_child(hud._label(I18n.t("Откроется на уровне «%s»") % I18n.t(String(Defs.LEVELS[tier]["name"])), 12, true, CityStyle.INK))
		section.add_child(notice)
	_empty = hud._label("Пока нет доступных исследований", 16, true, CityStyle.INK)
	_empty.name = "ResearchEmpty"
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.custom_minimum_size.y = 100
	add_child(_empty)
	_built = true


func _layout_sections() -> void:
	if not _built:
		return
	var width := maxf(792, size.x)
	var grid_width := CARD.x * COLUMNS + GAP * (COLUMNS - 1)
	var any_visible := false
	for tier: int in sections:
		var section: Control = sections[tier]
		var grid := section.get_node("Items") as GridContainer
		var count := 0
		for child: Control in grid.get_children():
			if child.visible:
				count += 1
		section.visible = tier == current_rank and count > 0
		any_visible = any_visible or section.visible
		var locked: bool = tier > hud.game.city.level
		var rows := ceili(float(count) / COLUMNS)
		var height := 32 + rows * CARD.y + maxi(0, rows - 1) * GAP + 20
		section.custom_minimum_size = Vector2(0, height)
		var ribbon := section.get_node("Ribbon") as PanelContainer
		ribbon.position = Vector2(0, 0)
		ribbon.size = Vector2(width, 26)
		grid.columns = COLUMNS
		grid.position = Vector2((width - grid_width) * 0.5, 32)
		grid.size = Vector2(grid_width, 0)
		var wash := section.get_node("RankLockOverlay") as ColorRect
		wash.size = Vector2(width, height)
		wash.visible = locked
		var notice := section.get_node("RankLockNotice") as HBoxContainer
		notice.position = Vector2(0, height - 20)
		notice.size = Vector2(width, 20)
		notice.visible = locked
		var tab := rank_tabs[tier] as Button
		tab.set_pressed_no_signal(tier == current_rank)
		tab.modulate = Color(1, 1, 1, 0.45) if locked else Color.WHITE
		tab.set_meta("current", tier == hud.game.city.level)
		var frame: StyleBoxFlat = hud._card_frame(8, 3)
		if tier == hud.game.city.level:
			frame.border_color = CityStyle.OLIVE
			frame.set_border_width_all(2)
		tab.add_theme_stylebox_override("normal", frame)
		if tier == current_rank:
			frame = frame.duplicate() as StyleBoxFlat
			frame.bg_color = Color("e0e2c4")
			tab.add_theme_stylebox_override("pressed", frame)
			tab.add_theme_stylebox_override("hover_pressed", frame)
		for child: Control in tab.find_children("*", "Control", true, false):
			if child is Label:
				(child as Label).add_theme_color_override("font_color", CityStyle.INK)
			elif child is TextureRect:
				child.modulate = CityStyle.OLIVE
	_empty.visible = not any_visible
	_place_popup.call_deferred()


func building_ids(id: String) -> Array[String]:
	if _buildings.has(id):
		return _buildings[id]
	var out: Array[String] = []
	for type: String in Defs.B:
		if hud.game.city.unlock_id(type) == id and Defs.B[type].get("research_list", true):
			out.append(type)  # Мельницы-украшения в исследованиях не показываем.
	_buildings[id] = out
	return out


func picture(r: Dictionary) -> Texture2D:
	for type: String in building_ids(String(r["id"])):
		if hud.icons.get(type) != null:
			return hud.icons[type]
	return CityStyle.icon(String(r["icon"]))


func _update_picture(img: TextureRect, r: Dictionary) -> void:
	img.texture = picture(r)
	var alpha := img.modulate.a
	var building_picture := false
	for type: String in building_ids(String(r["id"])):
		if hud.icons.get(type) != null:
			building_picture = true
			break
	img.modulate = Color.WHITE if building_picture else CityStyle.OLIVE
	img.modulate.a = alpha


func _badge_style(_col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CityStyle.CREAM
	sb.border_color = CityStyle.RIM
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(9)
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	return sb


func make_card(r: Dictionary) -> Button:
	var id := String(r["id"])
	var b := Button.new()
	b.name = "Research_" + id
	b.set_meta("rid", id)
	b.custom_minimum_size = CARD
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.78, 0.61, 0.31, 0.09)
	hover.set_corner_radius_all(12)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Hud.C_GOLD
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(12)
	b.add_theme_stylebox_override("focus", focus)
	var img := TextureRect.new()
	img.name = "Picture"
	img.position = Vector2(14, 0)
	img.size = Vector2(64, 64)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	b.add_child(img)
	var label: Label = hud._label(String(r["name"]), 13, true, CityStyle.INK)
	label.name = "ItemName"
	label.position = Vector2(0, 66)
	label.clip_text = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.max_lines_visible = 1
	label.tooltip_text = String(r["name"])
	# Сначала обрезка, затем размер: длинное имя уже не расширит Control.
	label.custom_minimum_size = Vector2(CARD.x, 18)
	label.size = Vector2(CARD.x, 18)
	b.add_child(label)
	# Подпись вне контейнера растягивалась по тексту (проба: 178 точек у «Класс ремесленников») и наезжала
	# на соседей — режем сами: переведённое имя с многоточием по ширине ячейки, полное — в подсказке
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = fit_name(I18n.t(String(r["name"])), label)
	# ширину ей всё равно раздувают вправо — ставим текст влево и сдвигаем на половину свободного места:
	# обрезанное имя стоит ровно под картинкой, как бы ни росла сама подпись
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.position.x = floorf((CARD.x - name_width(label)) * 0.5)
	var badge := PanelContainer.new()
	badge.name = "CostBadge"
	badge.position = Vector2(12, 88)
	badge.size = Vector2(68, 20)
	b.add_child(badge)
	var cost := HBoxContainer.new()
	cost.alignment = BoxContainer.ALIGNMENT_CENTER
	cost.add_theme_constant_override("separation", 5)
	var coin: TextureRect = CityStyle.pictogram("research", 13)
	coin.name = "Icon"
	cost.add_child(coin)
	var price: Label = hud._label("", 11, true, CityStyle.INK)
	price.name = "Cost"
	cost.add_child(price)
	badge.add_child(cost)
	var tick: TextureRect = CityStyle.pictogram("check", 16)
	tick.name = "DoneTick"
	tick.position = Vector2(70, 46)
	b.add_child(tick)
	var lock: TextureRect = CityStyle.pictogram("lock", 16)
	lock.name = "ParentLock"
	lock.position = Vector2(70, 46)
	b.add_child(lock)
	var mark := HBoxContainer.new()
	mark.name = "new_mark"
	mark.position = Vector2(64, 0)
	mark.add_theme_constant_override("separation", 3)
	mark.add_child(CityStyle.pictogram("research_sparkles", 16))
	mark.tooltip_text = "НОВОЕ"
	b.add_child(mark)
	for child: Control in b.find_children("*", "Control", true, false):
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.pressed.connect(func():
		_mark_seen(id)
		show_detail(id)
		hud.show_pointer({"kind": "study", "tip": ""}))
	b.mouse_entered.connect(func(): _mark_seen(id))
	return b


func _mark_seen(id: String) -> void:
	var c: City = hud.game.city
	if hud.game.mode in ["new", "play"] and c.mark_seen_r(id):
		(cards[id].get_node("new_mark") as Control).hide()
		hud.update_new_marks()


func _update_card(b: Button, r: Dictionary) -> void:
	var c: City = hud.game.city
	var id := String(r["id"])
	var done := c.research.has(id)
	var why := c.can_research(id)
	var available := why == ""
	var parent_locked: bool = r.has("after") and not c.research.has(r["after"])
	var locked: bool = not done and (Defs.story_of(r) != "" or int(r["lvl"]) > c.level or parent_locked)
	b.set_meta("state", "done" if done else ("available" if available else ("locked" if locked else "points")))
	b.visible = c.research_visible(id) and (not only_available.button_pressed or available)
	b.tooltip_text = tooltip(r)
	var img := b.get_node("Picture") as TextureRect
	_update_picture(img, r)
	img.material = _done_material if done else null
	img.modulate.a = 0.6 if locked else 1.0
	(b.get_node("ItemName") as Label).add_theme_color_override("font_color", Hud.C_SOFT if locked else CityStyle.INK)
	var badge := b.get_node("CostBadge") as PanelContainer
	badge.add_theme_stylebox_override("panel", _badge_good if done or c.rp >= float(r["cost"]) else _badge_bad)
	var cost := badge.get_child(0) as HBoxContainer
	var coin := cost.get_node("Icon") as TextureRect
	coin.texture = CityStyle.icon("check" if done else "research")
	coin.set_meta("city_icon", "check" if done else "research")
	coin.modulate = CityStyle.OLIVE
	(cost.get_node("Cost") as Label).text = "" if done else str(r["cost"])
	badge.tooltip_text = "Изучено" if done else str(r["cost"])
	badge.reset_size()
	badge.position.x = (CARD.x - badge.size.x) * 0.5
	var tick := b.get_node("DoneTick") as TextureRect
	tick.visible = done
	tick.modulate = Hud.C_GOOD
	var lock := b.get_node("ParentLock") as TextureRect
	lock.visible = not done and locked
	lock.modulate = Hud.C_SOFT
	(b.get_node("new_mark") as Control).visible = hud.game.mode in ["new", "play"] and c.is_new_r(id)


func tooltip(r: Dictionary) -> String:
	var id := String(r["id"])
	var text := I18n.t(String(r["name"]))
	if r.has("after") and not hud.game.city.research.has(r["after"]):
		text += "\n" + I18n.t("Сначала: %s") % I18n.t(String(Defs.research(r["after"])["name"]))
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
	var why: String = hud.game.city.can_research(id)
	return text + ("\n" + I18n.t(why) if why != "" else "")


func _make_popup() -> void:
	popup = PanelContainer.new()
	popup.name = "ResearchItemPopup"
	popup.custom_minimum_size.x = 326
	popup.add_theme_stylebox_override("panel", CityStyle.panel(12, 12))
	hud.root.add_child(popup)
	popup.hide()
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	popup.add_child(body)
	var header := HBoxContainer.new()
	_popup_title = hud._label("", 23, false, Hud.C_INK, hud.font_title)
	_popup_title.custom_minimum_size.x = 230
	_popup_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_popup_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_popup_title.max_lines_visible = 2
	_popup_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(_popup_title)
	header.add_child(hud._bare("close", "Закрыть", 30, close_detail))
	body.add_child(header)
	_popup_picture = TextureRect.new()
	_popup_picture.name = "Picture"
	_popup_picture.custom_minimum_size = Vector2(280, 106)
	_popup_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_popup_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	body.add_child(_popup_picture)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_detail_scroll)
	detail = VBoxContainer.new()
	detail.name = "ResearchDetails"
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 8)
	_detail_scroll.add_child(detail)
	var cost := HBoxContainer.new()
	cost.alignment = BoxContainer.ALIGNMENT_CENTER
	cost.add_child(CityStyle.pictogram("research", 23))
	_popup_cost = hud._label("", 18, true)
	cost.add_child(_popup_cost)
	body.add_child(cost)
	_popup_reason = hud._label("", 15, false, Hud.C_SOFT)
	_popup_reason.name = "StudyReason"
	_popup_reason.custom_minimum_size.x = 280
	_popup_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_popup_reason.max_lines_visible = 4
	_popup_reason.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.add_child(_popup_reason)
	study = Button.new()
	study.name = "StudyResearch"
	study.custom_minimum_size.y = 40
	study.pressed.connect(func():
		var c: City = hud.game.city
		if c.do_research(selected):
			hud._fill_research()
			if hud.tray.visible:
				hud._fill_cards()
		else:
			refresh())
	CityStyle.button(study)
	body.add_child(study)
	CityStyle.apply(popup)


func paragraph(text: String, color := Hud.C_INK) -> void:
	var l: Label = hud._label(text, 15, false, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 264
	detail.add_child(l)


func show_detail(id: String) -> void:
	var r := Defs.research(id)
	if r.is_empty() or not cards.has(id):
		return
	selected = id
	hud._clear(detail)
	_detail_scroll.scroll_vertical = 0
	if r.has("desc"):
		paragraph(String(r["desc"]))
	var c: City = hud.game.city
	if c.econ >= 1 and id in Defs.DECOR_SETS:
		paragraph(I18n.t("Набор: три разных вида из него рядом с домом — ещё +%d%% счастья.") % Defs.SET_BONUS, Hud.C_GOOD)
	for type: String in building_ids(id):
		var d: Dictionary = Defs.B[type]
		paragraph(I18n.t("Открывает постройку: %s") % I18n.t(String(d["name"])))
		if d.has("desc"):
			paragraph(String(d["desc"]))
		if d.has("bonus"):
			var category := String(Defs.NEEDS.get(String(d.get("sub", "")), {}).get("name", ""))
			paragraph(I18n.t("+%d%% счастья домам рядом") % int(d["bonus"]) + (" · " + I18n.t(category) if category != "" else ""), Hud.C_GOOD)
		elif d.has("rp"):
			paragraph(I18n.t("+%s очков исследований в час") % Hud.fmt_rate(float(d["rp"])), Hud.C_GOOD)
		elif d.has("deco"):
			paragraph(I18n.t("Красота: +%d") % int(d["deco"]), Hud.C_GOOD)
		if Defs.CAT_SHORT.has(String(d.get("cat", ""))):
			paragraph(I18n.t("Раздел: %s") % I18n.t(String(Defs.CAT_SHORT[d["cat"]])), Hud.C_SOFT)
		paragraph(I18n.t("Постройка: %s ден.") % hud.fmt(d.get("cost", 0)), Hud.C_SOFT)
		if d.has("jobs"):
			var jobs: Array[String] = []
			for cls: String in d["jobs"]:
				jobs.append("%d %s" % [int(d["jobs"][cls]), I18n.t(String(Defs.CLASSES[cls]["name"]))])
			paragraph(I18n.t("Рабочие: %s") % ", ".join(jobs), Hud.C_SOFT)
	if r.has("after"):
		paragraph(I18n.t("Сначала: %s") % I18n.t(String(Defs.research(r["after"])["name"])), Hud.C_SOFT)
	_popup_title.text = String(r["name"])
	popup.move_to_front()
	popup.show()
	_update_detail_state()
	popup.reset_size()
	_place_popup()
	_place_popup.call_deferred()


func _update_detail_state() -> void:
	if selected == "":
		return
	var r := Defs.research(selected)
	var c: City = hud.game.city
	var done := c.research.has(selected)
	var why := c.can_research(selected)
	_update_picture(_popup_picture, r)
	_popup_picture.material = _done_material if done else null
	_popup_cost.text = I18n.t("Стоимость: %s") % str(r["cost"])
	_popup_cost.add_theme_color_override("font_color", BADGE_BAD if c.rp < float(r["cost"]) and not done else Hud.C_GOOD)
	study.text = "Изучено" if done else "Изучить"
	study.disabled = why != ""
	study.tooltip_text = why
	var eta: String = hud.rp_eta(float(r["cost"])) if not done else ""
	_popup_reason.text = I18n.t(why)
	_popup_reason.tooltip_text = why
	if eta != "":
		_popup_reason.text += ("\n" if why != "" else "") + I18n.t("Хватит через %s") % eta
	_popup_reason.visible = _popup_reason.text != ""
	CityStyle.apply(popup)
	_place_popup.call_deferred()


func _place_popup() -> void:
	if popup == null or not popup.visible or not cards.has(selected):
		return
	var card := cards[selected] as Control
	if not hud.research_panel.visible or not card.is_visible_in_tree() or not scroll.get_global_rect().intersects(card.get_global_rect()):
		close_detail()
		return
	var rect := card.get_global_rect()
	var at := Vector2(rect.end.x + 12, rect.position.y - 16)
	if at.x + popup.size.x > hud.root.size.x - 12:
		at.x = rect.position.x - popup.size.x - 12
	at.x = clampf(at.x, 12, maxf(12, hud.root.size.x - popup.size.x - 12))
	at.y = clampf(at.y, 12, maxf(12, hud.root.size.y - popup.size.y - 12))
	popup.position = at.round()


func close_detail() -> void:
	if popup != null:
		popup.hide()


func focus_rank(tier: int) -> void:
	select_rank(tier)


func focus_card(id: String) -> bool:
	if not cards.has(id):
		return false
	select_rank(int(Defs.research(id)["lvl"]))
	_focus_serial += 1
	var serial := _focus_serial
	await get_tree().process_frame
	await get_tree().process_frame
	return serial == _focus_serial and hud.research_panel.visible and (cards[id] as Control).is_visible_in_tree()


func reveal(id: String) -> void:
	if not cards.has(id):
		return
	if only_available.button_pressed and not (cards[id] as Control).visible:
		only_available.set_pressed_no_signal(false)
		rebuild()
	close_detail()
	if await focus_card(id):
		show_detail(id)


func _input(event: InputEvent) -> void:
	if not popup.visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_detail()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not popup.get_global_rect().has_point(popup.get_global_mouse_position()):
			close_detail()


func select_rank(tier: int) -> void:
	var next_rank := clampi(tier, 0, Defs.LEVELS.size() - 1)
	if current_rank != next_rank:
		close_detail()
	current_rank = next_rank
	_layout_sections()
	scroll.scroll_vertical = 0


## Имя исследования по ширине ячейки: длинное — с многоточием (Label вне контейнера сам не режет)
static func fit_name(full: String, label: Label) -> String:
	var f: Font = label.get_theme_font("font")
	var fs: int = label.get_theme_font_size("font_size")
	var room := CARD.x - 6.0
	if f == null or f.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= room:
		return full
	var cut := full
	while cut.length() > 1 and f.get_string_size(cut.strip_edges() + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		cut = cut.substr(0, cut.length() - 1)
	return cut.strip_edges() + "…"


static func name_width(label: Label) -> float:
	var f: Font = label.get_theme_font("font")
	return f.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x if f else CARD.x
