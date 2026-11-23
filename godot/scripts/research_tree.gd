extends VBoxContainer
## Городские исследования на одном свитке: ранги, ветки и покупка на месте.

const WINDOW_SIZE := Vector2(820, 836)
const CARD_WIDTH := 118.0
const PICTURE_SIDE := 72.0
const NAME_WIDTH := 114.0
const NAME_Y := 92.0
const CARD_GAP := 18.0
const ROW_GAP := 30.0
const COLUMNS := 5
const GUTTER := 30.0
const RIBBON_HEIGHT := 52.0
const LINK_COLOR := Color("a5704c")
const BADGE_GOOD := Color("425f33")
const SYMBOLS := preload("res://assets/ui/ttc/research_symbols.png")
const PAPER := preload("res://assets/ui/ttc/research_paper.png")
const ART_REGIONS := {
	"frame": Rect2(243, 33, 398, 395),
	"research": Rect2(1087, 80, 487, 304),
	"rank": Rect2(233, 475, 440, 382),
	"lock": Rect2(1173, 474, 304, 385),
}
const UPGRADE_PICTURES := {
	"reach1": "stall_veg", "floor2": "house_pleb", "floor3": "house_pleb",
	"scribes1": "scriptorium", "store1": "warehouse", "vault1": "",
	"scribes2": "scriptorium", "research1": "", "taxes1": "",
	"vault2": "", "pave_up": "",
}
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
var current_rank := 0
var selected := ""
var study: Button
var popup: PanelContainer
var open_scroll := false
var _state := ""
var _first := ""
var _built := false
var _buildings: Dictionary = {}
var _building_rules := -1
var _art: Dictionary = {}
var _muted: ShaderMaterial
var _rank_cards: Dictionary = {}
var _rank_offsets: Dictionary = {}
var _row_bottoms: Dictionary = {}
var _edges: Array[Dictionary] = []
var _hovered := ""
var _popup_picture: TextureRect
var floor_preview: HBoxContainer
var confirm: PanelContainer
var confirm_text: Label
var confirm_yes: Button
var pending := ""
var _focus_serial := 0
var _lock_notices: Dictionary = {}
var _empty: Label
var _layout_width := 0.0


func setup(owner_hud, parent: VBoxContainer, header: HBoxContainer) -> void:
	hud = owner_hud
	hud.research_panel.add_theme_stylebox_override("panel", _surface("fbefda", "a6724c", 16, 10))
	parent.add_theme_constant_override("separation", 6)
	_make_points(header)
	_make_tabs(parent)
	scroll = ScrollContainer.new()
	scroll.name = "ResearchScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.clip_contents = true
	var bar := scroll.get_v_scroll_bar()
	bar.add_theme_stylebox_override("scroll", _surface("efddc0", "efddc0", 5, 4))
	bar.add_theme_stylebox_override("grabber", _surface("b38257", "a6724c", 5, 4))
	bar.add_theme_stylebox_override("grabber_highlight", _surface("a6724c", "94603d", 5, 4))
	bar.add_theme_stylebox_override("grabber_pressed", _surface("94603d", "875338", 5, 4))
	bar.value_changed.connect(func(_value: float): _place_popup())
	parent.add_child(scroll)
	name = "ResearchRanks"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 3)
	hud.research_box = self
	scroll.add_child(self)
	resized.connect(_width_changed)
	_make_popup()
	_make_confirm()
	hud.root.resized.connect(fit_window)
	fit_window()


func _make_points(header: HBoxContainer) -> void:
	var points := PanelContainer.new()
	points.name = "ResearchPoints"
	points.custom_minimum_size.x = 114
	points.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	points.add_theme_stylebox_override("panel", _surface("f3dfb8", "d4b282", 14, 6))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	points.add_child(row)
	hud.research_points = points
	row.add_child(_symbol("research", 23))
	var amounts := VBoxContainer.new()
	amounts.add_theme_constant_override("separation", -3)
	row.add_child(amounts)
	hud.lbl_research_rp = hud._label("0", 18, true, CityStyle.INK)
	amounts.add_child(hud.lbl_research_rp)
	hud.lbl_research_rate = hud._label("", 12, false, Color("805737"))
	amounts.add_child(hud.lbl_research_rate)
	header.add_child(points)
	header.move_child(points, header.get_child_count() - 2)
	var spacer := header.get_child(0) as Control
	spacer.custom_minimum_size.x = points.custom_minimum_size.x + 36 + header.get_theme_constant("separation")
	var close := header.get_child(header.get_child_count() - 1) as Button
	(close.get_node("ic") as TextureRect).modulate = Color("805737")


func _make_tabs(parent: VBoxContainer) -> void:
	var tabs := HBoxContainer.new()
	tabs.name = "ResearchTabs"
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 5)
	parent.add_child(tabs)
	var city_tab := Button.new()
	city_tab.name = "CityTab"
	city_tab.text = "Город"
	city_tab.toggle_mode = true
	city_tab.keep_pressed_outside = true
	city_tab.focus_mode = Control.FOCUS_NONE
	city_tab.custom_minimum_size = Vector2(96, 29)
	city_tab.add_theme_stylebox_override("normal", _surface("f3e6cc", "c4ac88", 7, 4))
	city_tab.add_theme_stylebox_override("hover", _surface("e9d7b7", "bda27a", 7, 4))
	city_tab.add_theme_stylebox_override("pressed", _surface("8e704c", "7b6242", 7, 4))
	city_tab.add_theme_stylebox_override("hover_pressed", _surface("987853", "826744", 7, 4))
	for color: String in ["font_color", "font_hover_color"]:
		city_tab.add_theme_color_override(color, CityStyle.INK)
	for color: String in ["font_pressed_color", "font_hover_pressed_color"]:
		city_tab.add_theme_color_override(color, Color("fff4df"))
	city_tab.add_theme_font_override("font", hud.font_bold)
	city_tab.add_theme_font_size_override("font_size", 16)
	tabs.add_child(city_tab)
	city_tab.set_pressed_no_signal(true)
	city_tab.toggled.connect(func(_on: bool): city_tab.set_pressed_no_signal(true))
	for index in 3:
		var locked := Button.new()
		locked.name = "LockedTab%d" % (index + 1)
		locked.disabled = true
		locked.focus_mode = Control.FOCUS_NONE
		locked.custom_minimum_size = Vector2(74, 29)
		locked.tooltip_text = "Закрыто"
		locked.add_theme_stylebox_override("disabled", _surface("e9dac2", "dbcbaf", 7, 4))
		var lock := _symbol("lock", 15)
		locked.add_child(lock)
		lock.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
		lock.modulate.a = 0.62
		tabs.add_child(locked)


func fit_window() -> void:
	var panel: PanelContainer = hud.research_panel
	var room: Vector2 = hud.root.size - Vector2(24, 24)
	var factor := minf(1.0, minf(room.x / WINDOW_SIZE.x, room.y / WINDOW_SIZE.y))
	panel.custom_minimum_size = WINDOW_SIZE
	panel.size = WINDOW_SIZE
	panel.scale = Vector2.ONE * maxf(0.1, factor)
	panel.position = (hud.root.size - panel.size * panel.scale) * 0.5
	_place_popup()


func _width_changed() -> void:
	if _built and not is_equal_approx(_layout_width, size.x):
		_layout_sections()


func state_key() -> String:
	var c: City = hud.game.city
	return str([c.level, int(c.rp), c.econ, c.cozy_v, c.decor_v, c.legion_v, c.research, c.tips.get("seen_r", {}), I18n.lang])


func refresh() -> void:
	if not _built or _state != state_key():
		rebuild()
		return
	# Миниатюры стройки могут догрузиться после открытия.
	for id: String in cards:
		_update_picture(cards[id].get_node("Picture"), Defs.research(id))
	if popup.visible:
		_update_picture(_popup_picture, Defs.research(_hovered))


func rebuild(auto_scroll := false) -> void:
	if not _built:
		_build()
	_state = state_key()
	_first = ""
	for r: Dictionary in Defs.RESEARCH:
		var id := String(r["id"])
		var card: Button = cards[id]
		_update_card(card, r)
		if _first.is_empty() and card.visible and not card.disabled:
			_first = id
	if pending != "" and hud.game.city.can_research(pending) != "":
		cancel_confirm()
	_layout_sections()
	if popup.visible:
		show_detail(_hovered)
	if auto_scroll:
		focus_rank(hud.game.city.level)


func _build() -> void:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nvoid fragment() {\n vec4 c = COLOR;\n float g = dot(c.rgb, vec3(0.30, 0.59, 0.11));\n COLOR = vec4(mix(c.rgb, vec3(g), 0.88), c.a);\n}\n"
	_muted = ShaderMaterial.new()
	_muted.shader = shader
	for tier in Defs.LEVELS.size():
		_build_section(tier)
	for r: Dictionary in Defs.RESEARCH:
		var id := String(r["id"])
		var tier := int(r["lvl"])
		var items: Control = sections[tier].get_node("Items")
		var card := make_card(r)
		items.add_child(card)
		cards[id] = card
		_rank_cards[tier].append(card)
		var parents := Defs.research_prerequisites(r)
		for previous: String in parents:
			_build_link(id, previous, tier, id + "_" + previous if parents.size() > 1 else id)
	_empty = hud._label("Пока нет доступных исследований", 16, true, CityStyle.INK)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_empty)
	_built = true


func _build_section(tier: int) -> void:
	var section := Control.new()
	section.name = "Rank_%d" % tier
	section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(section)
	sections[tier] = section
	var rank_cards: Array[Button] = []
	_rank_cards[tier] = rank_cards

	var base := Panel.new()
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.add_theme_stylebox_override("panel", _surface("fbedd4", "d5b88c", 1, 0))
	section.add_child(base)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var parchment := _picture(_atlas(PAPER, Rect2(513, 0, 510, 511)), Vector2.ZERO)
	parchment.name = "Parchment"
	parchment.stretch_mode = TextureRect.STRETCH_SCALE
	parchment.modulate.a = 0.45
	base.add_child(parchment)
	parchment.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 1)
	var ribbon := _picture(_atlas(PAPER, Rect2(1025, 340, 511, 172)), Vector2.ZERO)
	ribbon.name = "Ribbon"
	ribbon.stretch_mode = TextureRect.STRETCH_SCALE
	base.add_child(ribbon)
	ribbon.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	ribbon.offset_bottom = RIBBON_HEIGHT

	var links := Control.new()
	links.name = "PrerequisiteLinks"
	links.mouse_filter = Control.MOUSE_FILTER_IGNORE
	links.z_index = 1
	section.add_child(links)
	var items := Control.new()
	items.name = "Items"
	items.mouse_filter = Control.MOUSE_FILTER_IGNORE
	items.z_index = 2
	section.add_child(items)
	items.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var heading := HBoxContainer.new()
	heading.name = "RankHeading"
	heading.z_index = 2
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_theme_constant_override("separation", 9)
	section.add_child(heading)
	heading.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	heading.offset_bottom = RIBBON_HEIGHT
	heading.add_child(_symbol("rank", 31))
	var rank_name: String = Defs.LEVELS[tier]["name"]
	var caption: Label = hud._label(rank_name, 25, true, CityStyle.INK)
	caption.name = "RankName"
	heading.add_child(caption)

	var notice := HBoxContainer.new()
	notice.name = "RankLockNotice"
	notice.z_index = 2
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.add_theme_constant_override("separation", 5)
	var lock := _symbol("lock", 15)
	lock.name = "RankPadlock"
	notice.add_child(lock)
	var text: Label = hud._label("", 14, true, Color("765139"))
	notice.add_child(text)
	section.add_child(notice)
	_lock_notices[tier] = notice


func _build_link(id: String, previous: String, tier: int, link_name: String) -> void:
	var line := Line2D.new()
	line.name = link_name
	line.width = 1.8
	line.default_color = LINK_COLOR
	line.antialiased = true
	sections[tier].get_node("PrerequisiteLinks").add_child(line)
	_edges.append({"parent": previous, "child": id, "line": line})


func _layout_sections() -> void:
	_layout_width = size.x
	var width := size.x if size.x > 1.0 else WINDOW_SIZE.x - 30.0
	var band_width := width - GUTTER * 2.0
	var columns := clampi(floori(band_width / (CARD_WIDTH + CARD_GAP)), 1, COLUMNS)
	var pitch := maxf(band_width / columns, CARD_WIDTH + CARD_GAP)
	var ranks_y := 0.0
	var count := 0
	for tier: int in sections:
		var section: Control = sections[tier]
		var locked: bool = tier > hud.game.city.level
		var notice: HBoxContainer = _lock_notices[tier]
		notice.visible = locked
		(notice.get_child(1) as Label).text = I18n.t("Откроется на уровне «%s»") % I18n.t(String(Defs.LEVELS[tier]["name"]))
		notice.reset_size()
		notice.position = Vector2(width - notice.size.x - 14.0, (RIBBON_HEIGHT - notice.size.y) * 0.5)
		(section.find_child("Ribbon", true, false) as TextureRect).modulate = Color("ead8bd") if locked else Color.WHITE
		(section.find_child("Parchment", true, false) as TextureRect).modulate.a = 0.28 if locked else 0.45
		(section.get_node("Items") as Control).modulate.a = 0.66 if locked else 1.0
		_rank_offsets[tier] = ranks_y
		var layers: Array[Array] = []
		for card: Button in _rank_cards[tier]:
			if not card.visible:
				continue
			var depth := _depth(Defs.research(String(card.get_meta("rid"))), tier)
			while layers.size() <= depth:
				layers.append([])
			layers[depth].append(card)
			count += 1
		var y := RIBBON_HEIGHT + 16.0
		# Ряды заполняем по порядку глубины, но наследник встаёт в ближайший ряд сразу под своими родителями
		# (владелец: «Больший охват» — ровно под тремя лавками, линия не обходит соседний ряд).
		var queue: Array = []
		for layer: Array in layers:
			queue.append_array(layer)
		var placed := {}
		while not queue.is_empty():
			var row: Array = []
			for pass_children: bool in [true, false]:   # сначала наследники готовых родителей, потом остальные
				for card: Button in queue:
					var rid := String(card.get_meta("rid"))
					if row.size() >= columns or row.has(card) or _has_parent(rid, tier) != pass_children:
						continue
					if _parents_placed(rid, tier, placed):
						row.append(card)
			if row.is_empty():
				row.append(queue[0])
			for card: Button in row:
				queue.erase(card)
			y = _place_row(row, width, y, columns, pitch, tier)
			for card: Button in row:
				placed[String(card.get_meta("rid"))] = true
		section.custom_minimum_size.y = y
		ranks_y += y + get_theme_constant("separation")
	_empty.visible = count == 0
	_draw_links()
	_place_popup()


func _depth(r: Dictionary, tier: int) -> int:
	var depth := 0
	for id: String in Defs.research_prerequisites(r):
		var parent: Control = cards[id]
		if parent.visible:
			var previous := Defs.research(id)
			var parent_depth := _depth(previous, tier) if int(previous["lvl"]) == tier else 0
			depth = maxi(depth, parent_depth + 1)
	return depth


## Все видимые родители этого ранга уже стоят в рядах выше.
func _parents_placed(id: String, tier: int, placed: Dictionary) -> bool:
	for previous: String in Defs.research_prerequisites(Defs.research(id)):
		var parent: Control = cards[previous]
		if parent.visible and int(Defs.research(previous)["lvl"]) == tier and not placed.has(previous):
			return false
	return true


## Есть ли у карточки видимый родитель того же ранга (тогда её место — под родителями).
func _has_parent(id: String, tier: int) -> bool:
	for previous: String in Defs.research_prerequisites(Defs.research(id)):
		var parent: Control = cards[previous]
		if parent.visible and int(Defs.research(previous)["lvl"]) == tier:
			return true
	return false


func _place_row(row: Array, width: float, y: float, columns: int, pitch: float, tier: int) -> float:
	var children: Array = row.filter(func(c: Button) -> bool: return _has_parent(String(c.get_meta("rid")), tier))
	var n := columns if not children.is_empty() else row.size()
	var left := (width - ((n - 1) * pitch + CARD_WIDTH)) * 0.5
	var free: Array[int] = []
	for i in n:
		free.append(i)
	var bottom := y
	# Сначала наследники занимают места под родителями, остальные — свободные места слева направо.
	var ordered: Array = children.duplicate()
	for card: Button in row:
		if not ordered.has(card):
			ordered.append(card)
	for card: Button in ordered:
		var id := String(card.get_meta("rid"))
		var slot := free[0]
		if children.has(card):
			var parent_x := 0.0
			var parents := 0
			for previous: String in Defs.research_prerequisites(Defs.research(id)):
				var parent: Control = cards[previous]
				if parent.visible:
					parent_x += parent.position.x
					parents += 1
			var target := (parent_x / parents - left) / pitch if parents > 0 else (n - 1) * 0.5
			for candidate: int in free:
				if absf(candidate - target) < absf(slot - target):
					slot = candidate
		free.erase(slot)
		card.position = Vector2(left + slot * pitch, y).round()
		_measure_card(card, id)
		bottom = maxf(bottom, card.position.y + card.size.y)
	for card: Button in row:
		_row_bottoms[card.get_meta("rid")] = bottom
	return bottom + ROW_GAP


func _draw_links() -> void:
	var route := 0
	for edge: Dictionary in _edges:
		var line: Line2D = edge["line"]
		var before: String = edge["parent"]
		var after: String = edge["child"]
		var parent: Control = cards[before]
		var child: Control = cards[after]
		line.visible = parent.visible and child.visible
		if not line.visible:
			continue
		var parent_rank := int(Defs.research(before)["lvl"])
		var child_rank := int(Defs.research(after)["lvl"])
		var offset: float = _rank_offsets[parent_rank] - _rank_offsets[child_rank]
		var parent_circle := parent.get_node("Medallion") as TextureRect
		var child_circle := child.get_node("Medallion") as TextureRect
		var start := parent.position + parent_circle.position + Vector2(parent_circle.size.x * 0.5, parent_circle.size.y + offset)
		var end := child.position + child_circle.position + Vector2(child_circle.size.x * 0.5, 0.0)
		var turn_y: float = _row_bottoms[before] + offset + 10.0
		# Из-под медали выходим сбоку от названия и цены.
		var side := parent.position.x + CARD_WIDTH + 4.0
		var stem_y := start.y + (NAME_Y - parent_circle.size.y) * 0.5
		var points := PackedVector2Array([start, Vector2(start.x, stem_y), Vector2(side, stem_y), Vector2(side, turn_y)])
		if parent_rank != child_rank or end.y - turn_y > ROW_GAP:
			# Через другие ряды идём по левому полю.
			var lane := lerpf(9.0, GUTTER - 7.0, float(route) / maxf(1.0, _edges.size() - 1.0))
			points.append(Vector2(lane, turn_y))
			turn_y = end.y - 9.0
			points.append(Vector2(lane, turn_y))
			route += 1
		points.append(Vector2(end.x, turn_y))
		points.append(end)
		line.points = points
		line.modulate.a = 0.55 if child_rank > hud.game.city.level else 1.0


func building_ids(id: String) -> Array[String]:
	var c: City = hud.game.city
	if c.decor_v != _building_rules:
		_buildings.clear()
		_building_rules = c.decor_v
	if _buildings.has(id):
		return _buildings[id]
	var out: Array[String] = []
	if bool(Defs.research(id).get("initial", false)) and Defs.B.has(id):
		out.append(id)
	for type: String in Defs.B:
		if c.unlock_id(type) == id and c.city_buildable(type) and Defs.B[type].get("research_list", true):
			out.append(type)
	var upgrade_picture := String(UPGRADE_PICTURES.get(id, ""))
	if out.is_empty() and not upgrade_picture.is_empty():
		out.append(upgrade_picture)
	_buildings[id] = out
	return out


func _update_picture(img: TextureRect, r: Dictionary) -> void:
	for type: String in building_ids(String(r["id"])):
		var icon: Texture2D = hud.building_icon(type)
		if icon:
			img.texture = icon
			img.modulate = Color.WHITE
			return
	img.texture = CityStyle.icon(String(r["icon"]))
	img.modulate = Color("8b5b3b")


func _surface(fill: String, rim: String, radius: int, pad: int) -> StyleBoxFlat:
	var style := CityStyle.panel(radius, pad)
	style.bg_color = Color(fill)
	style.border_color = Color(rim)
	return style


func _atlas(texture: Texture2D, area: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = area
	atlas.filter_clip = true
	return atlas


func _picture(texture: Texture2D, dimensions: Vector2) -> TextureRect:
	var pic := TextureRect.new()
	pic.texture = texture
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.size = dimensions
	return pic


func _symbol(key: String, side: int) -> TextureRect:
	if not _art.has(key):
		_art[key] = _atlas(SYMBOLS, ART_REGIONS[key])
	var pic := _picture(_art[key], Vector2(side, side))
	pic.custom_minimum_size = pic.size
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return pic


func make_card(r: Dictionary) -> Button:
	var id := String(r["id"])
	var card := Button.new()
	card.name = "Research_" + id
	card.set_meta("rid", id)
	card.custom_minimum_size.x = CARD_WIDTH
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		card.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var focus := _surface("ffffff00", "b28052", 7, 0)
	card.add_theme_stylebox_override("focus", focus)
	var medallion := _symbol("frame", 82)
	medallion.name = "Medallion"
	medallion.position = Vector2((CARD_WIDTH - medallion.size.x) * 0.5, 0)
	card.add_child(medallion)
	var img := _picture(null, Vector2(PICTURE_SIDE, PICTURE_SIDE))
	img.name = "Picture"
	img.position = Vector2((CARD_WIDTH - PICTURE_SIDE) * 0.5, 3)
	card.add_child(img)

	var label: Label = hud._label("", 16, true, CityStyle.INK)
	label.name = "ItemName"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_constant_override("line_spacing", 2)
	label.custom_minimum_size.x = NAME_WIDTH
	label.size = Vector2(NAME_WIDTH, label.get_line_height() + 2.0)
	label.position = Vector2((CARD_WIDTH - NAME_WIDTH) * 0.5, NAME_Y)
	card.add_child(label)
	_make_cost(card, int(r["cost"]))
	_make_badge(card, "DoneTick", false)
	_make_badge(card, "Upgrade", true)
	var lock := _symbol("lock", 19)
	lock.name = "ParentLock"
	lock.position = Vector2(CARD_WIDTH * 0.5 + 18, 57)
	card.add_child(lock)
	var mark := CityStyle.pictogram("research_sparkles", 16)
	mark.name = "new_mark"
	mark.position = Vector2(CARD_WIDTH * 0.5 - 41, 5)
	mark.size = mark.custom_minimum_size
	mark.modulate = Color("a46c32")
	card.add_child(mark)

	card.pressed.connect(request_study.bind(id))
	card.mouse_entered.connect(func():
		_mark_seen(id)
		show_detail(id))
	card.mouse_exited.connect(func():
		if _hovered == id:
			_hide_popup())
	card.focus_entered.connect(select_card.bind(id))
	return card


func _make_cost(card: Button, points: int) -> void:
	var badge := PanelContainer.new()
	badge.name = "CostBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.name = "Price"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	var icon := _symbol("research", 15)
	icon.name = "Icon"
	row.add_child(icon)
	var price: Label = hud._label(hud.fmt(points), 14, true, CityStyle.INK)
	price.name = "Cost"
	row.add_child(price)
	badge.add_child(row)
	card.add_child(badge)


func _make_badge(card: Button, node_name: String, upgrade: bool) -> void:
	var disc := Panel.new()
	disc.name = node_name
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.add_theme_stylebox_override("panel", _surface("637c39", "fff0d2", 12, 0))
	disc.position = Vector2(CARD_WIDTH * 0.5 + 20.0, 2.0 if upgrade else 58.0)
	disc.size = Vector2(20, 20)
	card.add_child(disc)
	if upgrade:
		var arrow := Polygon2D.new()
		arrow.color = Color("fff4d8")
		arrow.polygon = PackedVector2Array([Vector2(5, 13), Vector2(10, 6), Vector2(15, 13)])
		disc.add_child(arrow)
	else:
		var tick := CityStyle.pictogram("check", 14)
		tick.position = Vector2(3, 3)
		tick.size = Vector2(14, 14)
		tick.modulate = Color("fff4d8")
		disc.add_child(tick)


func _measure_card(card: Button, id: String) -> void:
	var label := card.get_node("ItemName") as Label
	var line_count := label.get_line_count()
	var text_height := 0
	for index in line_count:
		text_height += label.get_line_height(index)
	text_height += maxi(0, line_count - 1) * label.get_theme_constant("line_spacing")
	label.size = Vector2(NAME_WIDTH, maxf(text_height + 2.0, label.get_minimum_size().y + 1.0))
	var badge := card.get_node("CostBadge") as PanelContainer
	badge.reset_size()
	badge.position = Vector2(roundf((CARD_WIDTH - badge.size.x) * 0.5), label.position.y + label.size.y + 3.0)
	var base_height := badge.position.y + badge.size.y
	if id == pending:
		confirm.position = Vector2(0.0, base_height + 4.0)
		confirm.reset_size()
		confirm.size.x = CARD_WIDTH
	card.size = Vector2(CARD_WIDTH, base_height + (confirm.size.y + 4.0 if id == pending else 0.0))


func _mark_seen(id: String) -> void:
	var c: City = hud.game.city
	if hud.game.mode in ["new", "play"] and c.mark_seen_r(id):
		(cards[id].get_node("new_mark") as Control).hide()
		hud.update_new_marks()


func _update_card(card: Button, r: Dictionary) -> void:
	var c: City = hud.game.city
	var id := String(r["id"])
	var done := c.research_done(id)
	var locked := not done and not c.research_open(id)
	var available := c.can_research(id) == ""
	card.set_meta("state", "done" if done else ("locked" if locked else ("available" if available else "points")))
	card.set_meta("tooltip", tooltip(r))
	card.visible = c.research_visible(id) and not bool(r.get("hidden", false))
	if Defs.B.has(id) and Defs.B[id].get("sub", "") == "wonders":
		card.visible = card.visible and c.city_buildable(id)
	card.disabled = not available
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if available else Control.CURSOR_ARROW
	var img := card.get_node("Picture") as TextureRect
	_update_picture(img, r)
	img.material = _muted if locked else null
	(card.get_node("Medallion") as TextureRect).material = _muted if locked else null
	(card.get_node("ItemName") as Label).text = I18n.t(String(r["name"]))
	var badge := card.get_node("CostBadge") as PanelContainer
	badge.visible = not done and not locked
	var price := badge.get_node("Price/Cost") as Label
	price.add_theme_color_override("font_color", BADGE_GOOD if available else Color("6d685c"))
	badge.add_theme_stylebox_override("panel", _surface("e3e8cc", "bdc4a0", 9, 3) if available else _surface("e9e2d4", "d1c8b8", 9, 3))
	(badge.get_node("Price/Icon") as TextureRect).modulate.a = 1.0 if available else 0.55
	(card.get_node("DoneTick") as Control).visible = done
	(card.get_node("ParentLock") as Control).visible = locked
	(card.get_node("Upgrade") as Control).visible = UPGRADE_PICTURES.has(id)
	(card.get_node("new_mark") as Control).visible = hud.game.mode in ["new", "play"] and c.is_new_r(id)


func tooltip(r: Dictionary) -> String:
	var id := String(r["id"])
	var lines: Array[String] = [I18n.t(String(r["name"]))]
	var c: City = hud.game.city
	var prerequisite := c.missing_research_prerequisite(r)
	if not c.research_done(id):
		if prerequisite != "":
			lines.append(I18n.t("Сначала: %s") % I18n.t(String(Defs.research(prerequisite)["name"])))
		elif int(r["lvl"]) > c.level:
			lines.append(I18n.t("Нужен уровень «%s»") % I18n.t(String(Defs.LEVELS[int(r["lvl"])]["name"])))
		elif Defs.story_of(r) != "":
			lines.append(I18n.t("Откроется %s") % I18n.t(Defs.unlock_text(id)))
		elif c.rp < float(r["cost"]):
			lines.append(I18n.t("Не хватает очков исследований"))
	if id in ["floor2", "floor3"]:
		lines.append(I18n.t("Надстроить %d-й этаж: полный дом, счастье от %d%%.") % [2 if id == "floor2" else 3, 65 if id == "floor2" else 75])
	elif id == Defs.ROAD_UP_RES:
		lines.append(I18n.t("Улучшение дорог и счастье домов у улицы."))
	elif SHORT_EFFECTS.has(id):
		lines.append(I18n.t(String(SHORT_EFFECTS[id])))
	elif bool(r.get("initial", false)):
		lines.append(I18n.t("Доступно с начала игры"))
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
	popup.add_theme_stylebox_override("panel", _surface("fff3dd", "b08056", 10, 8))
	hud.root.add_child(popup)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	popup.add_child(row)
	_popup_picture = _picture(null, Vector2(46, 46))
	_popup_picture.custom_minimum_size = _popup_picture.size
	_popup_picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_popup_picture)
	floor_preview = HBoxContainer.new()
	floor_preview.name = "FloorPreview"
	floor_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floor_preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for picture_node: TextureRect in [CityStyle.pictogram("housing", 22), CityStyle.pictogram("arrow", 14), CityStyle.pictogram("housing", 34)]:
		picture_node.modulate = Color("8b5b3b")
		picture_node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		floor_preview.add_child(picture_node)
	var arrow := floor_preview.get_child(1) as TextureRect
	arrow.pivot_offset = Vector2(7, 7)
	arrow.rotation_degrees = -90
	row.add_child(floor_preview)
	detail = VBoxContainer.new()
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_theme_constant_override("separation", 2)
	row.add_child(detail)
	popup.resized.connect(_place_popup)
	popup.hide()


func show_detail(id: String) -> void:
	var card := cards.get(id) as Control
	if pending != "" or not is_on_scroll(card):
		_hide_popup()
		return
	_hovered = id
	floor_preview.visible = id in ["floor2", "floor3"]
	_popup_picture.visible = not floor_preview.visible
	hud._clear(detail)
	var lines := tooltip(Defs.research(id)).split("\n")
	var text_width := 110.0
	for index in lines.size():
		var label: Label = hud._label("", 15, index == 0, CityStyle.INK)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = lines[index]
		text_width = maxf(text_width, label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 2.0)
		detail.add_child(label)
	detail.custom_minimum_size.x = minf(370.0, text_width)
	_update_picture(_popup_picture, Defs.research(id))
	popup.show()
	popup.reset_size()
	_place_popup()


func _place_popup() -> void:
	if popup == null or not popup.visible:
		return
	var card := cards.get(_hovered) as Control
	if not is_on_scroll(card):
		_hide_popup()
		return
	var root: Control = hud.root
	var to_root := root.get_global_transform_with_canvas().affine_inverse()
	var rect := (to_root * card.get_global_transform_with_canvas()) * Rect2(Vector2.ZERO, card.size)
	var view := (to_root * popup.get_viewport_rect()).grow(-8.0)
	var scale_limit := minf(view.size.x / popup.size.x, view.size.y / popup.size.y)
	popup.scale = Vector2.ONE * minf(hud.research_panel.scale.x, scale_limit)
	var extent := popup.size * popup.scale
	var at := Vector2(rect.end.x + 6.0, rect.position.y)
	if at.x + extent.x > view.end.x:
		at.x = rect.position.x - extent.x - 6.0
	if at.y + extent.y > view.end.y:
		at.y = rect.position.y - extent.y - 6.0
	popup.position = at.round().clamp(view.position, (view.end - extent).max(view.position))


func is_on_scroll(card: Control) -> bool:
	return card != null and card.is_visible_in_tree() and Rect2(Vector2.ZERO, scroll.size).intersects(_scroll_rect(card))


func _scroll_rect(control: Control) -> Rect2:
	var to_scroll := scroll.get_global_transform_with_canvas().affine_inverse()
	return (to_scroll * control.get_global_transform_with_canvas()) * Rect2(Vector2.ZERO, control.size)


func _ensure_scroll_visible(control: Control) -> void:
	# Положение полосы прокрутки задано в точках свитка.
	var rect := _scroll_rect(control)
	var bar := scroll.get_v_scroll_bar()
	var top := minf(0.0, rect.position.y - 2.0)
	var bottom := maxf(0.0, rect.end.y - bar.page + 2.0)
	scroll.scroll_vertical += floori(top) if top < 0.0 else ceili(bottom)


func _hide_popup() -> void:
	_hovered = ""
	popup.hide()


func close_detail() -> void:
	_focus_serial += 1
	_hide_popup()
	cancel_confirm()


func focus_rank(tier: int) -> void:
	select_rank(tier)


func select_rank(tier: int) -> void:
	close_detail()
	current_rank = clampi(tier, 0, Defs.LEVELS.size() - 1)
	var serial := _focus_serial
	await get_tree().process_frame
	await get_tree().process_frame
	if serial == _focus_serial and hud.research_panel.visible and sections.has(current_rank):
		var section: Control = sections[current_rank]
		scroll.scroll_vertical = roundi(section.position.y)


func focus_card(id: String) -> bool:
	var card := cards.get(id) as Control
	if card == null:
		return false
	_focus_serial += 1
	var serial := _focus_serial
	await get_tree().process_frame
	await get_tree().process_frame
	if serial != _focus_serial or not card.is_visible_in_tree():
		return false
	current_rank = int(Defs.research(id)["lvl"])
	_ensure_scroll_visible(card)
	return true


func reveal(id: String) -> void:
	close_detail()
	if await focus_card(id):
		select_card(id)
		(cards[id] as Control).grab_focus()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and pending != "":
		cancel_confirm()
		get_viewport().set_input_as_handled()


func _make_confirm() -> void:
	confirm = PanelContainer.new()
	confirm.name = "ResearchConfirm"
	confirm.add_theme_stylebox_override("panel", _surface("f6e7c7", "c29a69", 7, 4))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 3)
	confirm.add_child(body)
	confirm_text = hud._label("", 14, true, CityStyle.INK)
	confirm_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(confirm_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	body.add_child(row)
	confirm_yes = _button("Да", accept_study)
	confirm_yes.name = "ConfirmYes"
	row.add_child(confirm_yes)
	var no := _button("Нет", cancel_confirm)
	no.name = "ConfirmNo"
	row.add_child(no)
	confirm.hide()
	add_child(confirm)


func select_card(id: String) -> void:
	selected = id
	study = cards[id]
	_mark_seen(id)


func request_study(id: String) -> void:
	select_card(id)
	if not study.is_visible_in_tree() or hud.game.city.can_research(id) != "" or pending == id:
		return
	pending = id
	confirm.reparent(study, false)
	confirm_text.text = I18n.t("Изучить за %s?") % hud.fmt(int(Defs.research(id)["cost"]))
	_hide_popup()
	confirm.show()
	_layout_sections()
	confirm_yes.grab_focus()
	_keep_confirm_visible.call_deferred(id)
	hud.show_pointer({"kind": "study", "tip": ""})


func _keep_confirm_visible(id: String) -> void:
	if pending == id and confirm.is_visible_in_tree():
		_ensure_scroll_visible(confirm)
		hud._update_pointer()


func accept_study() -> void:
	var id := pending
	cancel_confirm()
	if id != "" and hud.game.city.do_research(id):
		hud._fill_research()
		if hud.tray.visible:
			hud._fill_cards()
		_animate_studied(cards[id])
	else:
		refresh()


func _animate_studied(card: Button) -> void:
	var tick := card.get_node("DoneTick") as Control
	tick.pivot_offset = tick.size * 0.5
	tick.scale = Vector2.ONE * 0.55
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(tick, "scale", Vector2.ONE, 0.26)


func cancel_confirm() -> void:
	if pending.is_empty():
		return
	pending = ""
	confirm.hide()
	_layout_sections()
	hud._update_pointer()


func study_target() -> Control:
	if pending != "":
		return confirm_yes
	return study if is_on_scroll(study) and not study.disabled else null


func cheapest_available() -> Button:
	var target: Button
	var cost := INF
	for r: Dictionary in Defs.RESEARCH:
		var card := cards.get(String(r["id"])) as Button
		if card != null and card.is_visible_in_tree() and not card.disabled and float(r["cost"]) < cost:
			target = card
			cost = float(r["cost"])
	return target


func _button(text: String, cb: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(40, 24)
	button.add_theme_font_override("font", hud.font_bold)
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(cb)
	CityStyle.button(button)
	return button
