extends VBoxContainer
## Один ранг на странице, полные имена и покупка в карточке, без прокрутки.

const CARD := Vector2(136, 142)
const GAP := 10.0
const COLUMNS := 6
const BADGE_GOOD := Color("487333")
const BADGE_BAD := Color("a53d32")
const SHORT_EFFECTS := {
	"scribes1": "+1 свиток в час от каждого скриптория.",
	"legion": "Казармы и отряд Легиона.",
	"archery": "Лучники Легиона бьют издалека.",
	"catshop": "Шляпки и бантики для городских кошек.",
	"deco_craft": "Горн, наковальня, ткацкий станок и печь.",
	"deco_garden": "Самшит, шпалеры и цветочные партеры.",
	"prem_patrician": "Экседра и бассейн: счастье сверх предела украшений.",
	"deco_mosaic": "Фрески и мозаики на стены домов.",
	"prem_mosaic": "Мозаичное панно и мозаичный дворик.",
	"deco_fest": "Гирлянды, знамёна, столы и помост поэта.",
	"deco_gods": "Высокие статуи, бронзовый треножник и орёл.",
	"prem_eternal": "Статуя триумфатора и фонтан с тритонами.",
}
var hud
var scroll: ScrollContainer
var detail: VBoxContainer
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
var _popup_picture: TextureRect
var floor_preview: HBoxContainer
var confirm: HBoxContainer
var confirm_text: Label
var confirm_yes: Button
var pending := ""
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
	parent.add_child(tools)
	_rank_bar = HBoxContainer.new()
	_rank_bar.name = "ResearchRankTabs"
	_rank_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_rank_bar.add_theme_constant_override("separation", 4)
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
	_make_confirm(parent)
	hud.root.resized.connect(fit_window)
	fit_window()


func fit_window() -> void:
	hud.research_panel.custom_minimum_size = Vector2(900, 460)
	scroll.custom_minimum_size = Vector2(CARD.x * COLUMNS + GAP * (COLUMNS - 1), 284)
	hud._snug(hud.research_panel)
	_layout_sections()
	_place_popup.call_deferred()


func state_key() -> String:
	var c: City = hud.game.city
	return str([c.level, int(c.rp), c.econ, c.cozy_v, c.legion_v, c.research, c.tips.get("seen_r", {}), current_rank])


func refresh() -> void:
	if not _built or _state != state_key():
		rebuild()
	else:
		# Миниатюры стройки могут догрузиться после открытия окна.
		for id: String in cards:
			_update_picture(cards[id].get_node("Picture"), Defs.research(id))
		if popup.visible:
			_update_picture(_popup_picture, Defs.research(selected))


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
	_update_detail_state()
	_layout_sections()
	if popup.visible:
		if not (cards[selected] as Control).visible:
			close_detail()
		else:
			show_detail(selected)
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
		tab.custom_minimum_size = Vector2(102, 52)
		tab.tooltip_text = String(Defs.LEVELS[tier]["name"])
		hud._card_button(tab)
		tab.custom_minimum_size = Vector2(102, 52)
		var tab_body := VBoxContainer.new()
		tab_body.add_theme_constant_override("separation", 0)
		tab.add_child(tab_body)
		tab_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 3)
		var medal: TextureRect = CityStyle.pictogram("level", 18)
		medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var rank_lock := CityStyle.pictogram("lock", 16)
		rank_lock.name = "RankPadlock"
		rank_lock.position = Vector2(80, 3)
		tab.add_child(rank_lock)
		tab_body.add_child(medal)
		var caption: Label = hud._label(String(Defs.LEVELS[tier]["name"]), 14, true, CityStyle.INK)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.name = "RankName"
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
		var links := Control.new()
		links.name = "PrerequisiteLinks"
		links.mouse_filter = Control.MOUSE_FILTER_IGNORE
		section.add_child(links)
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
	var width := maxf(CARD.x * COLUMNS + GAP * (COLUMNS - 1), size.x)
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
		wash.visible = false
		var notice := section.get_node("RankLockNotice") as HBoxContainer
		notice.position = Vector2(0, height - 20)
		notice.size = Vector2(width, 20)
		notice.visible = locked
		var tab := rank_tabs[tier] as Button
		tab.set_pressed_no_signal(tier == current_rank)
		tab.modulate = Color.WHITE
		(tab.find_child("RankPadlock", true, false) as Control).visible = locked
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
		if section.visible:
			scroll.custom_minimum_size.y = height
			custom_minimum_size.y = height
		_draw_links.call_deferred(tier)
	_empty.visible = not any_visible
	hud._snug.call_deferred(hud.research_panel)
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
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var frame := CityStyle.panel(10, 0)
		if state != "normal":
			frame.bg_color = Color("e5d8b8")
			frame.border_color = CityStyle.OLIVE
		b.add_theme_stylebox_override(state, frame)
	var img := TextureRect.new()
	img.name = "Picture"
	img.position = Vector2((CARD.x - 42) * 0.5, 2)
	img.size = Vector2(42, 42)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	b.add_child(img)
	var label: Label = hud._label(String(r["name"]), 14, true, CityStyle.INK)
	label.name = "ItemName"
	label.position = Vector2(4, 44)
	label.size = Vector2(CARD.x - 8, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.max_lines_visible = -1
	b.add_child(label)
	var badge := PanelContainer.new()
	badge.name = "CostBadge"
	badge.position = Vector2(30, 85)
	badge.custom_minimum_size = Vector2(CARD.x - 60, 24)
	b.add_child(badge)
	var cost := HBoxContainer.new()
	cost.alignment = BoxContainer.ALIGNMENT_CENTER
	cost.add_theme_constant_override("separation", 5)
	var coin := CityStyle.pictogram("research", 18)
	coin.name = "Icon"
	cost.add_child(coin)
	var price: Label = hud._label("", 14, true, CityStyle.INK)
	price.name = "Cost"
	cost.add_child(price)
	badge.add_child(cost)
	var tick := CityStyle.pictogram("check", 16)
	tick.name = "DoneTick"
	tick.position = Vector2(CARD.x - 22, 22)
	b.add_child(tick)
	var lock := CityStyle.pictogram("lock", 18)
	lock.name = "ParentLock"
	lock.position = Vector2(CARD.x - 24, 22)
	b.add_child(lock)
	var prior := CityStyle.pictogram("research", 18)
	prior.name = "PrerequisiteIcon"
	prior.position = Vector2(6, 4)
	b.add_child(prior)
	var mark := CityStyle.pictogram("research_sparkles", 16)
	mark.name = "new_mark"
	mark.position = Vector2(CARD.x - 22, 3)
	b.add_child(mark)
	for child: Control in b.find_children("*", "Control", true, false):
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var action := _button("Изучить", request_study.bind(id))
	action.name = "Study"
	action.position = Vector2(6, 113)
	action.custom_minimum_size = Vector2(0, 26)
	action.size = Vector2(CARD.x - 12, 26)
	CityStyle.button(action)
	b.add_child(action)
	b.pressed.connect(func():
		select_card(id)
		hud.show_pointer({"kind": "study", "tip": ""}))
	b.mouse_entered.connect(func():
		_mark_seen(id)
		show_detail(id))
	b.mouse_exited.connect(func(): popup.hide())
	action.mouse_entered.connect(func(): show_detail(id))
	action.mouse_exited.connect(func(): popup.hide())
	b.focus_entered.connect(select_card.bind(id))
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
	b.visible = c.research_visible(id)
	b.set_meta("tooltip", tooltip(r))
	var img := b.get_node("Picture") as TextureRect
	_update_picture(img, r)
	img.material = _done_material if done else null
	img.modulate.a = 0.6 if locked else 1.0
	(b.get_node("ItemName") as Label).add_theme_color_override("font_color", CityStyle.INK)
	var badge := b.get_node("CostBadge") as PanelContainer
	badge.add_theme_stylebox_override("panel", _badge_good if done or c.rp >= float(r["cost"]) else _badge_bad)
	var cost := badge.get_child(0) as HBoxContainer
	var coin := cost.get_node("Icon") as TextureRect
	coin.texture = CityStyle.icon("check" if done else "research")
	coin.set_meta("city_icon", "check" if done else "research")
	var color := BADGE_GOOD if done or available else Color("777568")
	coin.modulate = color
	(cost.get_node("Cost") as Label).add_theme_color_override("font_color", color)
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
	var action := b.get_node("Study") as Button
	action.disabled = why != ""
	action.text = "Изучено" if done else "Изучить"
	var prior := b.get_node("PrerequisiteIcon") as TextureRect
	prior.visible = r.has("after") and int(Defs.research(String(r["after"]))["lvl"]) != int(r["lvl"])
	if prior.visible:
		_update_picture(prior, Defs.research(String(r["after"])))
	(b.get_node("new_mark") as Control).visible = hud.game.mode in ["new", "play"] and c.is_new_r(id)


func tooltip(r: Dictionary) -> String:
	var id := String(r["id"])
	var lines: Array[String] = [I18n.t(String(r["name"]))]
	if r.has("after") and not hud.game.city.research.has(r["after"]):
		lines.append(I18n.t("Сначала: %s") % I18n.t(String(Defs.research(r["after"])["name"])))
	elif int(r["lvl"]) > hud.game.city.level:
		lines.append(I18n.t("Нужен уровень «%s»") % I18n.t(String(Defs.LEVELS[int(r["lvl"])]["name"])))
	elif Defs.story_of(r) != "":
		lines.append(I18n.t("Откроется %s") % I18n.t(Defs.unlock_text(id)))
	elif not hud.game.city.research.has(id) and hud.game.city.rp < float(r["cost"]):
		lines.append(I18n.t("Не хватает очков исследований"))
	if id in ["floor2", "floor3"]:
		lines.append(I18n.t("Надстроить %d-й этаж: полный дом, счастье от %d%%.") % [2 if id == "floor2" else 3, 65 if id == "floor2" else 75])
	elif id == Defs.ROAD_UP_RES:
		lines.append(I18n.t("Улучшение дорог и счастье домов у улицы."))
	elif SHORT_EFFECTS.has(id):
		lines.append(I18n.t(String(SHORT_EFFECTS[id])))
	elif r.has("desc"):
		lines.append(I18n.t(String(r["desc"])).split(". ")[0].trim_suffix(".") + ".")
	else:
		var buildings := building_ids(id)
		if not buildings.is_empty():
			var d: Dictionary = Defs.B[buildings[0]]
			if d.has("bonus"):
				lines.append(I18n.t("+%d%% счастья домам рядом") % int(d["bonus"]))
			else:
				lines.append(I18n.t("Открывает: %s") % I18n.t(String(d["name"])))
	return "\n".join(lines.slice(0, 3))


func _make_popup() -> void:
	popup = PanelContainer.new()
	popup.name = "ResearchTooltip"
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.z_index = 20
	popup.add_theme_stylebox_override("panel", CityStyle.panel(10, 8))
	hud.root.add_child(popup)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	popup.add_child(row)
	_popup_picture = TextureRect.new()
	_popup_picture.custom_minimum_size = Vector2(40, 40)
	_popup_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_popup_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_popup_picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_popup_picture)
	floor_preview = HBoxContainer.new()
	floor_preview.name = "FloorPreview"
	floor_preview.alignment = BoxContainer.ALIGNMENT_CENTER
	floor_preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	floor_preview.add_child(CityStyle.pictogram("housing", 22))
	var arrow := CityStyle.pictogram("arrow", 14)
	arrow.pivot_offset = Vector2(7, 7)
	arrow.rotation_degrees = -90
	floor_preview.add_child(arrow)
	floor_preview.add_child(CityStyle.pictogram("housing", 34))
	row.add_child(floor_preview)
	detail = VBoxContainer.new()
	detail.add_theme_constant_override("separation", 2)
	row.add_child(detail)
	popup.hide()


func paragraph(text: String, color := Hud.C_INK) -> void:
	var l: Label = hud._label(text, 15, false, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 264
	detail.add_child(l)


func show_detail(id: String) -> void:
	if not cards.has(id) or not (cards[id] as Control).is_visible_in_tree():
		return
	selected = id
	floor_preview.visible = id in ["floor2", "floor3"]
	_popup_picture.visible = not floor_preview.visible
	hud._clear(detail)
	for line: String in tooltip(Defs.research(id)).split("\n"):
		var label: Label = hud._label(line, 14, false, CityStyle.INK)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 400
		detail.add_child(label)
	_update_picture(_popup_picture, Defs.research(id))
	for child: Control in popup.find_children("*", "Control", true, false):
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.show()
	_place_popup.call_deferred()


func _update_detail_state() -> void:
	if pending != "" and hud.game.city.can_research(pending) != "":
		cancel_confirm()


func _place_popup() -> void:
	if popup == null or not popup.visible or not cards.has(selected):
		return
	var card := cards[selected] as Control
	if not hud.research_panel.visible or not card.is_visible_in_tree() or not scroll.get_global_rect().intersects(card.get_global_rect()):
		close_detail()
		return
	var rect := card.get_global_rect()
	popup.reset_size()
	var at := Vector2(rect.position.x, rect.end.y + 4)
	if at.y + popup.size.y > hud.root.size.y - 12:
		at.y = rect.position.y - popup.size.y - 4
	at.x = clampf(at.x, 12, maxf(12, hud.root.size.x - popup.size.x - 12))
	at.y = clampf(at.y, 12, maxf(12, hud.root.size.y - popup.size.y - 12))
	popup.position = at.round()


func close_detail() -> void:
	if popup != null:
		popup.hide()
	if confirm != null:
		cancel_confirm()


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
	close_detail()
	if await focus_card(id):
		select_card(id)
		(cards[id] as Control).grab_focus()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and pending != "":
		cancel_confirm()
		get_viewport().set_input_as_handled()


func select_rank(tier: int) -> void:
	var next_rank := clampi(tier, 0, Defs.LEVELS.size() - 1)
	if current_rank != next_rank:
		close_detail()
	current_rank = next_rank
	_layout_sections()
	scroll.scroll_vertical = 0



func _make_confirm(parent: VBoxContainer) -> void:
	var slot := MarginContainer.new()
	slot.name = "ResearchConfirmSlot"
	slot.custom_minimum_size.y = 42
	parent.add_child(slot)
	confirm = HBoxContainer.new()
	confirm.name = "ResearchConfirm"
	confirm.add_theme_constant_override("separation", 8)
	slot.add_child(confirm)
	confirm_text = hud._label("", 14, true, CityStyle.INK)
	confirm_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm.add_child(confirm_text)
	confirm_yes = _button("Да", accept_study)
	confirm_yes.name = "ConfirmYes"
	confirm.add_child(confirm_yes)
	var no := _button("Нет", cancel_confirm)
	no.name = "ConfirmNo"
	confirm.add_child(no)
	CityStyle.button(confirm_yes)
	CityStyle.button(no)
	confirm.hide()


func select_card(id: String) -> void:
	selected = id
	study = cards[id].get_node("Study") as Button
	_mark_seen(id)


func request_study(id: String) -> void:
	select_card(id)
	if hud.game.city.can_research(id) != "":
		return
	pending = id
	var r := Defs.research(id)
	confirm_text.text = I18n.t("Изучить «%s» за %s свитков?") % [I18n.t(String(r["name"])), str(r["cost"])]
	popup.hide()
	confirm.show()
	confirm_yes.grab_focus()
	hud.show_pointer({"kind": "study", "tip": ""})


func accept_study() -> void:
	var id := pending
	cancel_confirm()
	if id != "" and hud.game.city.do_research(id):
		hud._fill_research()
		if hud.tray.visible:
			hud._fill_cards()
	else:
		refresh()


func cancel_confirm() -> void:
	pending = ""
	confirm.hide()


func study_target() -> Control:
	return confirm_yes if pending != "" else study


func _button(text: String, cb: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", hud.font_bold)
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(cb)
	CityStyle.button(button)
	return button


func _draw_links(tier: int) -> void:
	var section: Control = sections[tier]
	var layer := section.get_node("PrerequisiteLinks") as Control
	for child: Line2D in layer.get_children():
		child.hide()
	for r: Dictionary in Defs.RESEARCH:
		if int(r["lvl"]) != tier or not r.has("after"):
			continue
		var id := String(r["id"])
		var prior := String(r["after"])
		if not cards.has(prior) or int(Defs.research(prior)["lvl"]) != tier:
			continue
		var a: Control = cards[prior]
		var b: Control = cards[id]
		if not a.visible or not b.visible:
			continue
		var link := layer.get_node_or_null(id) as Line2D
		if link == null:
			link = Line2D.new()
			link.name = id
			link.width = 1.0
			link.default_color = CityStyle.OLIVE
			link.antialiased = true
			layer.add_child(link)
		var grid := section.get_node("Items") as Control
		var start := grid.position + a.position + Vector2(CARD.x * 0.5, 0)
		var end := grid.position + b.position + Vector2(CARD.x * 0.5, 0)
		if is_equal_approx(start.y, end.y):
			link.points = PackedVector2Array([start, start - Vector2(0, 5), end - Vector2(0, 5), end])
		else:
			var edge := grid.position.x - 5.0
			link.points = PackedVector2Array([start, start - Vector2(0, 5), Vector2(edge, start.y - 5), Vector2(edge, end.y - 5), end - Vector2(0, 5), end])
		link.show()
