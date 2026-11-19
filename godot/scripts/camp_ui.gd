class_name CampUI
extends Control
## Форт V3: действия привязаны к участкам, павильоны — временный адаптер.

const Kit = preload("res://scripts/ui_kit_a.gd")
const Look = preload("res://scripts/legion_look.gd")
const FortPerson = preload("res://scripts/fort_person.gd")
const Ring = preload("res://scripts/fort_ui_ring.gd")
const USE_3D := true
const USE_CUTAWAY := true
var use_cutaway := USE_CUTAWAY # Старые сценарии могут явно выбрать прежнюю диораму.
var cutaway_markers: Control
var _worker_target := -1
var city_plaque: PanelContainer
var city_name_label: Label
var hq_level_label: Label
var order_button: Button
var order_ring: Control
var population_button: Button
var expand_floor: Button
var expand_section: Button
var dweller_sid := 0
var dweller_slot := ""
var dweller_change := ""
const STAR_TIP := "Звёзды — талант: больше звёзд — сильнее рост характеристик"
const FORT_ICON := {"hq": "castle", "barracks": "legion", "kitchen": "bread",
	"smelter": "anvil", "sawmill": "wood", "tannery": "clothes", "store": "amphora",
	"forge": "hammer", "drill": "swords", "infirmary": "medic", "mars": "laurels",
	"stable": "horse", "tower": "castle", "treasury": "coins", "arsenal": "shield"}
const TOP_NAMES := {"money": "Денарии", "rations": "Пайки", "glory": "Слава", "ingots": "Слитки"}
const TOP_TIPS := {
	"money": "Денарии Легиона: Сокровищница, сундуки и обоз из города. Склад повышает потолок.",
	"rations": "Пайки — еда для походов. Готовит кухня",
	"glory": "Слава — награда за победы и задания дня.",
	"ingots": "Слитки можно найти в сундуках. Они завершают стройку сразу.",
}
var room_stock_bar: ProgressBar
var instant_button: Button
var instant_price: Label
var requirement_banner: PanelContainer
var squad_button: Button
var selected_plot := -1
var resource_bars := {}
var left_column: VBoxContainer
var campaign_button: Button
var build_button: Button
var counters := {}
var plot_markers := {}
var extra_plots: ScrollContainer
var extra_row: HBoxContainer
var _plots_sig := ""
var card_backdrop: Control
var card_ring: Control
var main_action: Button
var upgrade_cost: Control
var build_cards := {}
var build_scroll: ScrollContainer
var build_focus := ""
var build_plot_id := -1
var _build_sig := ""
var _card_tween: Tween
var _sheet_offset := 0.0
var stock_labels := {}
var _support_kind := ""
var _support_sig := ""
var _healing: Array[Dictionary] = []
var _popup_resource := ""
var diorama: Camp3D
var background: TextureRect
var guide_layer: Control
var guide: PanelContainer
var guide_text: Label
var guide_pointer: TextureRect
var guide_skip: Button
var _guide_target: Control
var _guide_rect := Rect2()
var _guide_dragging := false
var _collection_fx: Array[Dictionary] = []
var _city_render_owned := false
var _previous_disable_3d := false

const IMAGE_SIZE := Vector2(1920, 1080)
const CENTRES := {
	"hq": Vector2(0.50, 0.25), "mars": Vector2(0.785, 0.25),
	"barracks": Vector2(0.24, 0.43), "forge": Vector2(0.80, 0.48),
	"drill": Vector2(0.25, 0.70), "store": Vector2(0.75, 0.70),
}
const PLAQUES := {
	"hq": Vector2(0.50, 0.15), "mars": Vector2(0.785, 0.21),
	"barracks": Vector2(0.24, 0.36), "forge": Vector2(0.80, 0.41),
	"drill": Vector2(0.25, 0.61), "store": Vector2(0.75, 0.61),
}
const EFFECTS := {
	"hq": "Уровень лагеря: остальные здания не выше Штаба.",
	"barracks": "Казарма — дом бойцов. Бойцы отсюда идут в отряд",
	"forge": "Оружие и доспехи. Наборы — с уровня 5.",
	"drill": "Тренировка повышает ранг и силу воинов.",
	"mars": "Умения в бою. Их потолок — уровень храма.",
	"store": "Хранит добычу. Каждый уровень даёт ещё 5 пайков.",
}
const CLASS_ICON := {"legionary": "swords", "archer": "arrow", "priest": "medic", "cavalry": "horse"}

var hud: Hud
var lg: Legion
var lu: LegionUi
var top_button: Button
var image_rect := Rect2()
var hotspots := {}
var plaques := {}
var chips: GridContainer
var builder_counter: Button
var builder_plus: Button
var profile_button: Button
var market_button: Button
var quest_line: Button
var quest_progress: Label
var quest_title: Label
var room_actions: PanelContainer
var room_actions_title: Label
var room_action_row: HBoxContainer
var room_action_id := -1
var room_action_running := false
var drag_name: Label
var drag_context: Label
var placement_type := ""
var placement_back: Button
var placement_hint: Label
var build_pinned := false
var build_tab := 0
var ration_label: Label
var glory_label: Label
var mats_label: Label
var resource_chips := {}
var bubbles := {}
var ingot_label: Label
var chest_button: Button
var hero_status: Label
var hero_train_button: Button
var hero_bar: ProgressBar
var hero_card_level := -1
var recruit_page := 0
var recruit_result := false
const RESOURCE_NAME := {"iron": "Железо", "wood": "Дерево", "leather": "Кожа", "rations": "Пайки"}
const RESOURCE_ICON := {"iron": "hammer", "wood": "wood", "leather": "shield", "rations": "bread"}
const RESOURCE_TIP := {
	"iron": "Железо — из Плавильни в городе. Нужно для оружия в Кузнице.",
	"wood": "Дерево — из Лесопилки в городе. Нужно для оружия и щитов в Кузнице.",
	"leather": "Кожа — из Кожевни в городе. Нужна для доспехов в Кузнице.",
	"rations": "Пайки — из пекарен. Тратятся на походы. Кухня Штаба даёт ещё 2 в день.",
}
const RESOURCE_BUILD := {"iron": "Постройте Плавильню в городе.", "wood": "Постройте Лесопилку в городе.",
	"leather": "Постройте Кожевню в городе.", "rations": "Постройте пекарню в городе."}
var daily_button: Button
var bottom: HBoxContainer
var exit_button: Button
var gate: Button
var card: PanelContainer
var card_body: VBoxContainer
var selected := ""
var card_level: Label
var upgrade_button: Button
var upgrade_reason: Label
var upgrade_timer: Label
var recruit_button: Button
var recruit_reason: Label
var roster_label: Label
var modal: Control
var modal_panel: PanelContainer
var squad_body: VBoxContainer
var selected_place := -1
var _elapsed := 0.0
var _card_sig := ""
var _squad_sig := ""
var _training := []


static func of(h: Hud) -> CampUI:
	return h.root.get_node_or_null("CampUI") as CampUI if h != null and h.root != null else null


static func attach(h: Hud) -> CampUI:
	var u := of(h)
	if u == null:
		u = CampUI.new()
		u.setup(h)
	return u


static func close_for(h: Hud) -> bool:
	var u := of(h)
	if u == null or not u.visible:
		return false
	u.close()
	return true


func setup(h: Hud) -> void:
	hud = h
	lg = h.game.city.legion
	lu = LegionUi.of(h)
	name = "CampUI"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	h.root.add_child(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	background = bg
	bg.texture = load("res://assets/ui/camp_bg.jpg") as Texture2D
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_screen()
	# Одна точка входа: существующий медальон Легиона.
	top_button = lu.btn
	lg.changed.connect(_update_entry)
	hud.game.city.changed.connect(_update_entry)
	resized.connect(_layout)
	_update_entry()
	_layout.call_deferred()
	set_process(false)
	set_process_input(false)


func _button(text: String, action: Callable, icon := "") -> Button:
	var aliases := {"scroll": "map", "book": "tasks", "commerce": "chest", "swords": "soldier", "shield": "squad", "hammer": "build", "housing": "family", "bread": "need_food", "coins": "collect"}
	var icon_key := String(Look.ALIASES.get(icon, icon))
	var tex: Texture2D = Look.icon(icon) if Look.ICONS.has(icon_key) else Kit.texture(String(aliases.get(icon, icon)))
	if tex == null and icon != "":
		tex = hud.ico(icon, 48)
	var b := Kit.close_button() if text in ["×", "Закрыть"] else Kit.button("cream", tex, I18n.t(text))
	b.tooltip_text = I18n.t(text)
	b.pressed.connect(action)
	return b


func _text(text: String, sz := 16, _bold := false) -> Label:
	return Kit.label(text, sz)


func _wrap(text: String, sz := 15) -> Label:
	var l := _text(text, sz)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _update_entry() -> void:
	if top_button == null:
		return
	var on: bool = lg.v3() and lg.window_open() and hud.game.mode in ["play", "new"]
	if visible and not on:
		close()
	if on and not lg.flags.has("camp_told"):
		_camp_moment.call_deferred()


## Лагерь открылся (50 жителей): один раз — спокойная карточка советника, стрелка и кивок кнопки «Лагерь».
## Занят советник или идёт ролик — подождём следующего обновления
func _camp_moment() -> void:
	if hud.tutorial_busy() or not hud._tip_free():
		return
	if lg.flags.has("camp_told") or top_button == null or not lg.window_open() or not top_button.is_visible_in_tree() or visible:
		return
	var rig = hud.game.get("rig")
	if hud.advisor_panel.visible or hud.game.tool != "" or (rig != null and rig.cine) or not hud.game.stories.cine.is_empty():
		return
	lg.flags["camp_told"] = true
	hud.advisor("Лагерь открыт", "Новобранцы ждут у ворот форта. Примите их и назначьте в комнаты.", Callable(), false, true)
	# стрелки сама не показываем (владелец 17.11: после обучения автоматических стрелок нет) — только совет и мигание кнопки
	var tw := top_button.create_tween()
	for i in 3:
		tw.tween_property(top_button, "modulate", Color(1.7, 1.45, 0.8), 0.35)
		tw.tween_property(top_button, "modulate", Color.WHITE, 0.35)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if not lg.v3() or not lg.window_open():
		hud.notify(lg.lock_text(), "lock")
		return
	hud._close_windows()
	hud._close_tray()
	hud._hide_info()
	hud.game.set_tool("")
	hud.advisor_panel.hide()
	lg.flags["seen"] = true
	lg.army_tick()
	lg.begin_fort_guide()
	lg.fort_guide_newcomer()
	visible = true
	move_to_front()
	_start_diorama()
	set_process(true)
	set_process_input(true)
	_refresh()
	_layout()
	hud._update_pointer()


func close() -> void:
	if lu.camp_window != "":
		lu.close(false)
	_set_placement("")
	_clear_room_selection()
	_close_modal()
	_hide_card()
	_stop_diorama()
	for entry: Dictionary in _collection_fx:
		(entry["tween"] as Tween).kill()
		if is_instance_valid(entry["label"]):
			(entry["label"] as Label).queue_free()
	_collection_fx.clear()
	guide_layer.hide()
	set_process(false)
	set_process_input(false)
	hide()
	hud._update_pointer()


func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		if lu.camp_window != "":
			lu.close()
		elif is_instance_valid(modal):
			_close_modal()
		elif is_instance_valid(card):
			_hide_card()
		elif placement_type != "":
			_cancel_placement()
		elif room_action_id >= 0:
			_clear_room_selection()
		else:
			close()
	# Горячие клавиши города не должны включать стройку за картинкой.
	get_viewport().set_input_as_handled()


func _build_screen() -> void:
	for slot: String in Legion.CAMP_SLOTS:
		var hit := Button.new()
		hit.flat = true
		hit.pressed.connect(func(): show_building(slot))
		add_child(hit)
		hotspots[slot] = hit
		var marker := _marker(-1, slot)
		add_child(marker["panel"])
		plaques[slot] = marker
	city_plaque = Look.panel(Look.DARK, 6)
	city_plaque.name = "FortCityPlaque"
	city_plaque.custom_minimum_size = Vector2(264, 64)
	add_child(city_plaque)
	var city_row := HBoxContainer.new()
	city_plaque.add_child(city_row)
	var level_badge := Look.panel(Look.WINE, 4)
	level_badge.custom_minimum_size = Vector2(50, 50)
	var level := Look.label("1", 30, Look.PAPER, true)
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_badge.add_child(level)
	level_badge.name = "FortHQMedallion"
	city_row.add_child(level_badge)
	hq_level_label = level_badge.get_child(0) as Label
	city_name_label = Look.label("", 31, Look.PAPER, true)
	city_name_label.name = "FortCityName"
	city_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	city_name_label.custom_minimum_size.x = 150
	city_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	city_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	city_row.add_child(city_name_label)
	chips = GridContainer.new()
	chips.columns = 2
	chips.name = "FortResources"
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 6)
	add_child(chips)
	for resource: String in ["rations", "money", "glory", "ingots"]:
		_resource_bar(resource)
	ration_label = resource_chips["rations"]
	glory_label = resource_chips["glory"]
	ingot_label = resource_chips["ingots"]
	left_column = VBoxContainer.new()
	left_column.add_theme_constant_override("separation", 12)
	add_child(left_column)
	campaign_button = _screen_button("Карта", "map", _campaign, Look.WINE)
	campaign_button.name = "FortMap"
	_badge(campaign_button)
	var arena := _nav("Арена", "trophy", func(): pass)
	arena.disabled = true
	arena.add_theme_stylebox_override("disabled", Look.box(Look.DARK, Look.BRONZE, 40, 6))
	arena.tooltip_text = I18n.t("Бои с другими игроками откроются позже.")
	squad_button = _nav("Отряд", "squad", show_squad)
	daily_button = _nav("Задания дня", "quests", func(): _aux("daily"))
	chest_button = _nav("Сундуки", "chest", show_chests)
	order_button = _nav("Заказать денарии из города", "money", _order_city_money)
	order_button.name = "FortCityOrder"
	order_ring = Ring.new()
	order_ring.name = "FortCityOrderRing"
	order_button.add_child(order_ring)
	order_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	build_button = _screen_button("Строить", "build", show_build_menu)
	build_button.name = "FortBuild"
	_badge(build_button)
	market_button = _screen_button("Рынок", "market", func(): _aux("store"))
	market_button.name = "FortMarket"
	exit_button = _screen_button("×", "", close, Look.DARK, Vector2(48, 48))
	exit_button.tooltip_text = I18n.t("Закрыть")
	bottom = HBoxContainer.new()
	add_child(bottom)
	population_button = _screen_button("", "family", show_people, Look.DARK, Vector2(128, 50))
	population_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	population_button.name = "FortPopulation"
	profile_button = _screen_button("", "", show_hero, Look.SLATE, Vector2(80, 80))
	profile_button.name = "FortProfile"
	profile_button.tooltip_text = I18n.t("Командир")
	var portrait := FortPerson.portrait({"hero": true}, "hq", false, 74)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	profile_button.add_child(portrait)
	portrait.position = Vector2(3, 3)
	builder_counter = _screen_button("", "build", _show_builder, Look.DARK, Vector2(128, 50))
	builder_counter.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	builder_counter.name = "FortBuilders"
	builder_plus = _screen_button("+", "", _show_builder, Look.DARK, Vector2(48, 50))
	builder_plus.tooltip_text = I18n.t("Строители")
	builder_plus.name = "FortBuildersPlus"
	placement_back = _screen_button("Назад", "", _cancel_placement, Look.WINE)
	placement_back.name = "FortCancelPlacement"
	placement_back.hide()
	placement_hint = Look.label("", 24, Look.PAPER)
	placement_hint.add_theme_stylebox_override("normal", Look.box(Look.DARK, Look.BRONZE, 8, 8))
	add_child(placement_hint)
	placement_hint.hide()
	_build_fort_overlays()


	expand_floor = Kit.button("gold", "plus")
	expand_floor.pressed.connect(func(): show_expansion("floor"))
	expand_floor.name = "FortPlusFloor"
	add_child(expand_floor)
	expand_section = Kit.button("gold", "build")
	expand_section.pressed.connect(func(): show_expansion("section"))
	expand_section.name = "FortPlusSection"
	add_child(expand_section)
	gate = _button("Поход", _campaign, "scroll")
	add_child(gate)
	extra_plots = ScrollContainer.new()
	extra_plots.name = "FortPlotStrip"
	extra_plots.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(extra_plots)
	extra_row = HBoxContainer.new()
	extra_row.add_theme_constant_override("separation", 14)
	extra_plots.add_child(extra_row)
	_build_bubbles()
	guide_layer = Control.new()
	guide_layer.name = "FortGuideLayer"
	guide_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.root.add_child(guide_layer)
	guide_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	guide_layer.hide()
	guide = Kit.inset()
	guide.name = "FortGuide"
	guide.add_theme_stylebox_override("panel", Kit.box("panels/panel_inset", 40, 12, 56))
	guide_layer.add_child(guide)
	guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide.resized.connect(func(): _layout_guide.call_deferred())
	var guide_body := VBoxContainer.new()
	guide_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide_body.add_theme_constant_override("separation", 3)
	guide.add_child(guide_body)
	guide_text = _text("", 18, true)
	guide_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide_body.add_child(guide_text)
	guide_skip = hud.guide_link(I18n.t("Пропустить обучение"), _skip_guide)
	guide_skip.name = "FortGuideSkip"
	guide_skip.add_theme_font_size_override("font_size", 14)
	guide_skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	guide_body.add_child(guide_skip)
	guide_pointer = TextureRect.new()
	guide_pointer.name = "FortGuideArrow"
	guide_pointer.texture = preload("res://assets/ui/icons/fort_guide_arrow.svg")
	guide_pointer.size = Vector2(64, 64)
	guide_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide_layer.add_child(guide_pointer)


func _screen_button(title: String, icon: String, action: Callable, color := Look.PAPER, dims := Vector2(148, 60)) -> Button:
	var button := Look.button(I18n.t(title), Look.icon(icon), color, dims)
	button.pressed.connect(action)
	add_child(button)
	return button


func _build_fort_overlays() -> void:
	quest_line = _screen_button("", "quests", _quest_campaign, Look.DARK, Vector2(314, 60))
	quest_line.name = "FortQuestLine"
	quest_line.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var verb := Look.label(I18n.t("Победите:"), 17, Look.PAPER)
	verb.position = Vector2(58, 5)
	quest_line.add_child(verb)
	quest_title = Look.label("", 21, Look.PAPER)
	quest_title.position = Vector2(58, 25)
	quest_title.size.x = 204
	quest_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	quest_line.add_child(quest_title)
	quest_progress = Look.label("0/1", 21, Look.PAPER)
	quest_progress.position = Vector2(269, 18)
	quest_line.add_child(quest_progress)
	room_actions = Look.panel(Look.DARK, 14)
	room_actions.name = "FortRoomActions"
	add_child(room_actions)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	room_actions.add_child(body)
	room_actions_title = Look.label("", 29, Look.PAPER, true)
	room_actions_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(room_actions_title)
	room_action_row = HBoxContainer.new()
	room_action_row.add_theme_constant_override("separation", 12)
	room_action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(room_action_row)
	room_actions.hide()
	drag_name = Look.label("", 22, Look.PAPER)
	drag_name.name = "FortDragName"
	drag_name.add_theme_stylebox_override("normal", Look.box(Look.SLATE, Look.PAPER, 8, 7))
	add_child(drag_name)
	drag_name.hide()
	drag_context = Look.label("", 19, Look.PAPER)
	drag_context.name = "FortDragContext"
	drag_context.add_theme_stylebox_override("normal", Look.box(Look.DARK, Look.BRONZE, 8, 6))
	add_child(drag_context)
	drag_context.hide()


func _resource_bar(resource: String) -> void:
	var panel := Look.chip(resource, "0", show_resource_popup.bind(resource))
	panel.name = "FortResource_" + resource
	panel.tooltip_text = I18n.t(String(TOP_NAMES[resource])) + "\n" + I18n.t(String(TOP_TIPS[resource]))
	chips.add_child(panel)
	var click: Button = panel.get_meta("hit")
	click.name = "Plus_" + resource
	click.tooltip_text = panel.tooltip_text
	resource_chips[resource] = panel.get_meta("number")
	resource_bars[resource] = {"panel": panel, "plus": click}


func _badge(button: Button) -> Label:
	var label := button.get_node_or_null("Counter") as Label
	if label == null:
		label = Kit.badge(button)
	label.position = Vector2(button.custom_minimum_size.x - 25, -4)
	label.hide()
	counters[button] = label
	return label


func _count(button: Button, amount: int) -> void:
	var label: Label = counters[button]
	label.text = str(amount)
	label.visible = amount > 0


func _nav(title: String, icon: String, action: Callable) -> Button:
	var button := Look.button("", Look.icon(icon), Look.DARK, Vector2(56, 56), true)
	button.tooltip_text = I18n.t(title)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left_column.add_child(button)
	button.pressed.connect(action)
	_badge(button)
	return button


func _layout() -> void:
	if chips == null or size.x < 1.0:
		return
	var cover := maxf(size.x / IMAGE_SIZE.x, size.y / IMAGE_SIZE.y)
	image_rect = Rect2((size - IMAGE_SIZE * cover) * 0.5, IMAGE_SIZE * cover)
	var k := minf(1.0, minf(size.x / 1000.0, size.y / 720.0))
	for slot: String in Legion.CAMP_SLOTS:
		var hit: Button = hotspots[slot]
		hit.size = image_rect.size * Vector2(0.16, 0.14)
		hit.position = image_rect.position + image_rect.size * Vector2(CENTRES[slot]) - hit.size * 0.5
		hit.visible = not is_instance_valid(diorama)
		hit.mouse_filter = Control.MOUSE_FILTER_STOP if hit.visible else Control.MOUSE_FILTER_IGNORE
		var marker: Control = plaques[slot]["panel"]
		marker.scale = Vector2.ONE * k
		var center := image_rect.position + image_rect.size * Vector2(PLAQUES[slot])
		if is_instance_valid(diorama):
			center = diorama.project(slot, 5.0)
		marker.position = _screen_anchor(center, Vector2(68, 118) * k)
	_layout_bubbles(k)
	chips.reset_size()
	var hk := clampf(minf(size.x / 1260.0, size.y / 790.0), 0.8, 1.08)
	var edge := 22.0 * hk
	var resource_scale := maxf(1.0, hk)
	chips.scale = Vector2.ONE * resource_scale
	chips.position = Vector2(size.x - edge - 182.0 * hk - chips.size.x * resource_scale, edge)
	city_plaque.scale = Vector2.ONE * hk
	city_plaque.size = Vector2(264, 64)
	city_plaque.position = Vector2(edge, edge)
	population_button.position = Vector2(size.x - edge - 128 * hk, edge + 88.0 * hk)
	profile_button.position = Vector2(size.x - edge - 104 * hk, edge)
	builder_counter.position = Vector2(size.x - edge - 182 * hk, edge + 144 * hk)
	builder_plus.position = Vector2(size.x - edge - 48 * hk, edge + 144 * hk)
	exit_button.position = Vector2(size.x - edge - 48 * hk, size.y - edge - 124 * hk)
	left_column.reset_size()
	left_column.scale = Vector2.ONE * hk
	left_column.position = Vector2(edge, edge + 77 * hk)
	quest_line.position = Vector2(edge, minf(size.y * 0.68, size.y - edge - 132 * hk))
	campaign_button.position = Vector2(edge, size.y - edge - 60 * hk)
	market_button.position = size - Vector2(edge + 148 * hk, edge + 60 * hk)
	build_button.position = market_button.position - Vector2(160 * hk, 0)
	placement_back.position = market_button.position
	placement_hint.reset_size()
	placement_hint.scale = Vector2.ONE * hk
	placement_hint.position = Vector2((size.x - placement_hint.size.x * hk) * 0.5, size.y - edge - 53.0 * hk)
	for button: Button in [campaign_button, build_button, market_button, population_button, builder_counter,
			builder_plus, profile_button, exit_button, quest_line, placement_back]:
		button.reset_size()
		button.scale = Vector2.ONE * hk
	room_actions.reset_size()
	room_actions.scale = Vector2.ONE * minf(hk, (size.x - 2.0 * edge) / maxf(1.0, room_actions.size.x))
	room_actions.position = Vector2((size.x - room_actions.size.x * room_actions.scale.x) * 0.5,
		size.y - edge - room_actions.size.y * room_actions.scale.y - (66.0 * hk if size.x < 1150 else 0.0))
	bottom.hide()


	extra_plots.scale = Vector2.ONE * k
	extra_plots.position = Vector2(150 * k, size.y - 148 * k)
	extra_plots.size = Vector2(maxf(150, size.x / k - 310), 136)
	gate.hide()
	_fit_room_card()
	_fit_modal()
	if diorama is FortCutaway:
		_layout_cutaway_view()
	else:
		_layout_guide()


func _process(dt: float) -> void:
	if not visible:
		return
	for resource: String in bubbles:
		var bubble: Button = bubbles[resource]["button"]
		var full := float(lg.pending_resources.get(resource, 0.0)) >= lg.resource_cap(resource) - 0.001
		var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.005) if full else 1.0
		bubble.modulate = Color(pulse, pulse, 1.0)
	var dragging := diorama is FortCutaway and (diorama as FortCutaway).drag_sid != 0
	if dragging != _guide_dragging:
		_guide_dragging = dragging
		_refresh_fort_visibility()
		_layout_guide()
	for id: int in plot_markers:
		var marker: Dictionary = plot_markers[id]
		var collect: Button = marker["collect"]
		var full: bool = bool(collect.get_meta("fort_full", false))
		collect.pivot_offset = collect.size * 0.5
		collect.scale = Vector2.ONE * (1.18 + 0.08 * sin(Time.get_ticks_msec() * 0.005) if full else 1.0)
	_elapsed += dt
	if _elapsed < 0.5:
		return
	_elapsed = 0.0
	# tick завершает стройку, обучение, ковку и обновляет задания дня.
	for message in lg.tick():
		hud.game.city._quiet(message, "legion")
	_refresh()


static func clock_text(seconds: float) -> String:
	var t := maxi(0, ceili(seconds))
	if t >= 86400:
		return duration_text(float(t))
	return "%d:%02d:%02d" % [t / 3600, (t % 3600) / 60, t % 60]


func _roster_signature() -> String:
	var entries := []
	for s: Dictionary in lg.soldiers:
		entries.append([s["id"], s["name"], _class(s), s["stars"], s["rank"], lg.s_state(s)])
	return str([entries, lg.squad3, lg.camp, lg.fort.get("up", {}), lg.upg.keys(), lg.hero_level(), lg.hero_training.is_empty(), lg.forging.is_empty(), lg.smith_known(), _plot_signature()])


func _refresh() -> void:
	lg.fort_guide_newcomer()
	if is_instance_valid(diorama):
		diorama.sync()
	population_button.text = "%d/%d" % [lg.fort_population(), lg.roster_cap()]
	population_button.tooltip_text = I18n.t("Жители форта · у ворот: %d") % lg.fort_newcomers().size()
	var full_fort := lg.fort_empty_plot() < 0
	expand_floor.visible = full_fort and diorama is FortCutaway
	expand_section.visible = expand_floor.visible
	var expand_tip := lg.fort_can_expand()
	expand_floor.tooltip_text = I18n.t("+ этаж") + ("\n" + I18n.t(expand_tip) if expand_tip != "" else "")
	expand_section.tooltip_text = I18n.t("+ секция") + ("\n" + I18n.t(expand_tip) if expand_tip != "" else "")
	city_name_label.text = hud.game.city.name if hud.game.city.name != "" else I18n.t("Новый Рим")
	city_plaque.tooltip_text = city_name_label.text + " · " + I18n.t("Штаб ур. %d") % lg.camp_level("hq")
	hq_level_label.text = str(lg.camp_level("hq"))
	_refresh_city_order()
	var builder := lg.fort_builder_count()
	builder_counter.text = "%d/%d" % [builder.x, builder.y]
	builder_counter.tooltip_text = I18n.t("Свободные строители") if builder.x > 0 else I18n.t(lg.fort_builder_text())
	Look.set_chip_value(resource_chips["money"], hud.fmt(lg.city_money()))
	Look.set_chip_value(ration_label, hud.fmt(lg.rations_now()))
	Look.set_chip_value(glory_label, hud.fmt(lg.glory))
	Look.set_chip_value(ingot_label, hud.fmt(lg.ingots))


	_count(squad_button, lg.fort_squad_candidates().size())
	_count(chest_button, lg.chest_queue.size())
	_count(daily_button, lg.daily_done() if lg.can_open_daily() == "" else 0)
	var frontier := lg.frontier()
	var stage := lg.stage_info(int(frontier["cycle"]), int(frontier["r"]), int(frontier["s"]))
	quest_title.text = I18n.t(String(stage.get("theme") if String(stage.get("theme", "")) != "" else stage["name"]))
	quest_progress.text = "✓" if bool(stage["done"]) else "0/1"
	quest_line.tooltip_text = I18n.t("Победите:") + " " + quest_title.text
	# Передний край может быть закрыт, но повторный бой всё ещё доступен.
	var battle_ready := lg.can_fight(stage) == "" or lg.can_fight(lg.stage_info(0, 0, 0)) == ""
	_count(campaign_button, 1 if battle_ready else 0)
	var available := 0
	for type: String in Legion.FORT_B:
		if type != "hq" and lg.fort_can_build(type, lg.fort_empty_plot()) == "":
			available += 1
	_count(build_button, available)
	_sync_markers()
	_refresh_room_actions()
	_refresh_speed_up()
	_refresh_fort_visibility()
	_refresh_bubbles()
	_refresh_hero()
	var sig := _roster_signature()
	if selected_plot >= 0 and is_instance_valid(card):
		if sig != _card_sig:
			_build_card()
		_refresh_card()
	if is_instance_valid(squad_body) and sig != _squad_sig:
		_build_squad()
	for resource: String in stock_labels:
		var label: Label = stock_labels[resource]
		label.text = "%d / %d" % [lg.mat(resource), lg.resource_cap(resource)]
	if is_instance_valid(build_scroll):
		_refresh_build_menu()
	if _support_kind != "" and is_instance_valid(modal_panel) and sig != _support_sig:
		_show_support(_support_kind)
	_refresh_support()
	_layout()


func _show_builder() -> void:
	if lg.fort_builder_count().x > 0:
		show_build_menu()
		return
	for plot: Dictionary in lg.fort["plots"]:
		if not lg.fort_plot_timer(int(plot["id"])).is_empty():
			if diorama is FortCutaway:
				_select_fort_room("plot_%d" % int(plot["id"]))
			else:
				show_plot(int(plot["id"]))
			return
	hud.notify(I18n.t(lg.fort_builder_text()), "lock")


func _select_fort_room(key: String) -> void:
	var id := int(key.trim_prefix("plot_"))
	var plot := lg.fort_plot(id)
	if plot.is_empty():
		return
	if placement_type != "":
		if plot["b"] == "":
			_place_build(id)
		return
	if plot["b"] == "":
		show_build_menu(id)
		return
	room_action_id = id
	room_action_running = not lg.fort_plot_timer(id).is_empty()
	(diorama as FortCutaway).select_room(id)
	_refresh_fort_visibility()
	_build_room_actions()
	_layout()


func _clear_room_selection() -> void:
	room_action_id = -1
	room_actions.hide()
	if diorama is FortCutaway:
		(diorama as FortCutaway).select_room(-1)


func _refresh_fort_visibility() -> void:
	var quiet := placement_type != "" or _guide_dragging
	left_column.visible = not quiet
	for button: Control in [quest_line, campaign_button, market_button, build_button, exit_button]:
		button.visible = not quiet
	placement_back.visible = placement_type != "" and not _guide_dragging
	placement_hint.visible = placement_back.visible
	room_actions.visible = room_action_id >= 0 and not quiet
	if quiet:
		expand_floor.hide()
		expand_section.hide()


func _refresh_room_actions() -> void:
	if room_action_id < 0:
		return
	var plot := lg.fort_plot(room_action_id)
	if plot.is_empty() or plot["b"] == "":
		_clear_room_selection()
		return
	var running := not lg.fort_plot_timer(room_action_id).is_empty()
	if running != room_action_running:
		room_action_running = running
		_build_room_actions()


func _build_room_actions() -> void:
	_clear(room_action_row)
	var id := room_action_id
	var plot := lg.fort_plot(id)
	var type := String(plot["b"])
	var name_text := I18n.t(String(Legion.FORT_B[type]["name"]))
	room_actions_title.text = I18n.t("%s · строится") % name_text if room_action_running else I18n.t("%s · ур. %d") % [name_text, int(plot["lv"])]
	var info := _room_action("Инфо", "info", show_plot.bind(id))
	info.name = "FortRoomInfo"
	if room_action_running:
		if not lg.fort_cancel_quote(id).is_empty() and not (type == "kitchen" and lg.fort_guide_step() == Legion.FortGuide.KITCHEN):
			_room_action("Отменить", "", _show_cancel_construction.bind(id)).name = "FortCancelBuild"
		_room_action("Ускорить", "build", _show_speed_up.bind(id), Look.WINE).name = "FortSpeedUp"
	else:
		_room_action("Улучшить", "build", show_plot.bind(id), Look.WINE)
		var quick := String({"barracks": "Отряд", "drill": "Тренировать", "forge": "Ковать", "arsenal": "Изготовить", "infirmary": "Лечить"}.get(type, "Назначить"))
		if type != "hq":
			_room_action(quick, "squad", func():
				show_plot(id)
				if is_instance_valid(main_action) and not main_action.disabled:
					_main_action())


func _room_action(title: String, icon: String, action: Callable, fill := Look.PAPER) -> Button:
	var button := Look.button(I18n.t(title), Look.icon(icon), fill, Vector2(180, 62))
	button.pressed.connect(action)
	room_action_row.add_child(button)
	return button


func _show_cancel_construction(id: int) -> void:
	var quote := lg.fort_cancel_quote(id)
	if quote.is_empty():
		_close_modal()
		_refresh()
		return
	var panel := _new_modal(500, true)
	modal_panel.name = "FortCancelConstruction"
	panel.add_child(Look.label(I18n.t("Отменить стройку?"), 32, Look.INK, true))
	panel.add_child(Look.label(I18n.t("Вернётся на склад"), 22))
	var refund := _cost_icons(quote["refund"], false)
	refund.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(refund)
	if refund.get_child_count() == 0:
		panel.add_child(Look.label(I18n.t("Возврата нет"), 21))
	var confirm := _button("Отменить стройку", func():
		if lg.fort_cancel(id, quote):
			_close_modal()
			_refresh()
		else:
			_show_cancel_construction(id))
	confirm.name = "FortConfirmCancel"
	panel.add_child(confirm)
	panel.add_child(_button("Назад", _close_modal))
	_fit_modal.call_deferred()


func _show_speed_up(id: int) -> void:
	var timer := lg.fort_plot_timer(id)
	if timer.is_empty():
		_close_modal()
		_refresh()
		return
	var panel := _new_modal(560, true)
	modal_panel.name = "FortSpeedDialog"
	panel.add_child(Look.label(I18n.t("Ускорить стройку"), 34, Look.INK, true))
	var clock := Look.label("", 26)
	clock.name = "FortSpeedClock"
	panel.add_child(clock)
	var bar := Look.meter(0, float(timer["total"]))
	bar.name = "FortSpeedProgress"
	panel.add_child(bar)
	var confirm := Look.button("", Look.resource("ingots"), Look.WINE)
	confirm.name = "FortFinishNow"
	confirm.pressed.connect(func():
		if lg.fort_speed_up(id, confirm.get_meta("quote", {})):
			_close_modal()
			_refresh()
		else:
			_show_speed_up(id))
	panel.add_child(confirm)
	panel.add_child(_button("Назад", _close_modal))
	modal_panel.set_meta("plot", id)
	_refresh_speed_up()
	_fit_modal.call_deferred()


func _refresh_speed_up() -> void:
	if not is_instance_valid(modal_panel) or modal_panel.name != "FortSpeedDialog":
		return
	var id := int(modal_panel.get_meta("plot"))
	var timer := lg.fort_plot_timer(id)
	if timer.is_empty():
		_close_modal()
		return
	var left := maxf(0, float(timer["end"]) - Legion.now())
	(modal_panel.find_child("FortSpeedClock", true, false) as Label).text = clock_text(left)
	(modal_panel.find_child("FortSpeedProgress", true, false) as ProgressBar).value = float(timer["total"]) - left
	var confirm := modal_panel.find_child("FortFinishNow", true, false) as Button
	var quote := lg.fort_instant_info(id)
	confirm.set_meta("quote", quote)
	var free = lg.fort_guide_step() == Legion.FortGuide.KITCHEN and lg.fort_plot(id).get("b") == "kitchen"
	confirm.icon = Look.icon("build") if free else Look.resource("ingots")
	confirm.text = I18n.t("Бесплатно") if free else I18n.t("Ускорить") + " · " + str(quote["price"])
	confirm.disabled = not free and String(quote["why"]) != ""
	confirm.tooltip_text = I18n.t(String(quote["why"])) if confirm.disabled else confirm.text


func _show_drag_context(point: Vector2, id: int, person_name: String) -> void:
	if guide_active():
		_layout_guide()
	drag_name.text = person_name
	drag_name.reset_size()
	drag_name.position = _screen_anchor(point - Vector2(0, 68), drag_name.size, 8, 8)
	drag_name.show()
	var view := diorama as FortCutaway
	var plot := lg.fort_plot(id)
	var total := lg.fort_room_slots(id)
	drag_context.visible = total > 0
	if total == 0:
		return
	var free := maxi(0, total - lg.fort_occupants(id).size())
	var action := I18n.t("Тренировка" if plot["b"] == "drill" else "Назначение")
	var valid := view._drop_valid(id)
	if valid:
		drag_context.text = action + " · " + (I18n.t("свободно %d из %d") % [free, total] if free > 0 else I18n.t("Заменить жителя"))
	else:
		var reason := "Здание строится." if not lg.fort_plot_timer(id).is_empty() else "Перенос недоступен"
		if not view.drag_newcomer:
			reason = lg.fort_can_assign(id, view.drag_sid)
		drag_context.text = I18n.t(reason)
	drag_context.reset_size()
	var rect := view.plot_footprint(id)
	drag_context.position = _screen_anchor(Vector2(rect.get_center().x, rect.end.y - 6), drag_context.size, 8, 8)


func show_building(slot: String) -> void:
	# Совместимость с Camp3D и прежними проверками; карточка хранит только ID участка.
	if slot.begins_with("plot_"):
		show_plot(int(slot.trim_prefix("plot_")))
		return
	if slot == "gate":
		show_plot(0)
		return
	var plot := lg.fort_slot_plot(slot)
	if plot.is_empty():
		plot = lg.fort_slot_plot("hq")
	if not plot.is_empty():
		show_plot(int(plot["id"]))


func show_plot(plot_id: int) -> void:
	var plot := lg.fort_plot(plot_id)
	if plot.is_empty() or String(plot["b"]) == "":
		show_build_menu(plot_id if not plot.is_empty() else -1)
		return
	_close_modal()
	_hide_card()
	selected_plot = plot_id
	selected = String(plot["b"])
	card_backdrop = Control.new()
	add_child(card_backdrop)
	card_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Look.DIM
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_backdrop.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_backdrop.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_hide_card())
	card = Look.panel(Look.PAPER, 20)
	add_child(card)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.name = "FortBuildingCard"
	card.minimum_size_changed.connect(_fit_room_card, Object.CONNECT_DEFERRED)
	card_body = VBoxContainer.new()
	card_body.add_theme_constant_override("separation", 8)
	card.add_child(card_body)
	_build_card()
	_refresh_card()
	_sheet_offset = 28.0
	_layout()
	_card_tween = create_tween()
	_card_tween.tween_method(_slide_sheet, _sheet_offset, 0.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _slide_sheet(offset: float) -> void:
	_sheet_offset = offset
	_fit_room_card()


func _fit_room_card() -> void:
	if not is_instance_valid(card):
		return
	Kit.fit_modal(card, size, Vector2(900, 0))
	card.position.y = minf(card.position.y + _sheet_offset, size.y - card.size.y * card.scale.y - 24.0)


func _hide_card() -> void:
	if _card_tween != null and _card_tween.is_valid():
		_card_tween.kill()
	for node: Control in [card, card_backdrop]:
		if is_instance_valid(node):
			node.hide()
			node.queue_free()
	card = null
	card_backdrop = null
	selected = ""
	selected_plot = -1
	_training.clear()


func _clear(control: Control) -> void:
	for child in control.get_children():
		control.remove_child(child)
		child.queue_free()


func _build_card() -> void:
	_clear(card_body)
	_training.clear()
	recruit_button = null
	_card_sig = _roster_signature()
	var info := lg.fort_info(selected_plot)
	if info.is_empty():
		_hide_card()
		return
	var level := int(info["lv"])
	var timer := lg.fort_plot_timer(selected_plot)
	var running := not timer.is_empty()
	var room_name := I18n.t(String(Legion.FORT_B[selected]["name"]))
	var head := HBoxContainer.new()
	var title := Look.label(I18n.t("%s · уровень %d") % [room_name, int(timer.get("to", level))], 48, Look.INK, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(title)
	head.add_child(Look.button("×", null, Look.INSET, Vector2(48, 48)))
	(head.get_child(1) as Button).pressed.connect(_hide_card)
	card_body.add_child(head)
	card_body.add_child(HSeparator.new())

	var picture := _room_picture(selected, level, Vector2(212, 104), running)
	picture.name = "FortRoomPicture"
	if running:
		picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card_body.add_child(picture)
		card_ring = Ring.new()
		card_ring.custom_minimum_size = Vector2(44, 44)
		var running_row := HBoxContainer.new()
		running_row.alignment = BoxContainer.ALIGNMENT_CENTER
		card_body.add_child(running_row)
		running_row.add_child(card_ring)
		upgrade_timer = Look.label("")
		running_row.add_child(upgrade_timer)
		var speed := Look.button(I18n.t("Ускорить"), Look.icon("build"), Look.WINE)
		speed.pressed.connect(_show_speed_up.bind(selected_plot))
		card_body.add_child(speed)
		main_action = null
		return

	var summary := HBoxContainer.new()
	summary.add_theme_constant_override("separation", 12)
	summary.add_child(picture)
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var stats := VBoxContainer.new()
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 6)
	summary.add_child(stats)
	card_body.add_child(summary)
	var prod: Dictionary = info["producing"]
	if not prod.is_empty():
		var next := lg.fort_plot_production(selected_plot, selected, level + 1)
		var resource_icon := Look.resource(String(prod["resource"]))
		_room_metric(stats, I18n.t("Производство в час"), resource_icon, float(prod["rate"]), float(next["rate"]))
		_room_metric(stats, I18n.t("Запас в комнате"), resource_icon, float(prod["cap"]), float(next["cap"]))
	elif selected == "barracks":
		_room_metric(stats, I18n.t("Места в боевом отряде"), Look.icon("squad"), Legion.places_at(level), Legion.places_at(level + 1))
		_room_metric(stats, I18n.t("Места в казарме"), Look.icon("family"),
			Legion.fort_room_slots_at(selected, level), Legion.fort_room_slots_at(selected, level + 1))
	elif selected == "store":
		var added := int(Legion.FORT_B["store"]["rations_per"])
		_room_metric(stats, I18n.t("Запас пайков"), Look.resource("rations"), lg.ration_cap(), lg.ration_cap() + added)
	elif selected == "hq":
		_room_metric(stats, I18n.t("Уровень форта"), FortCutaway.room_icon(selected), level, level + 1)
		var opens := HBoxContainer.new()
		for type: String in Legion.FORT_B:
			if type == "hq" or not (Legion.FORT_B[type]["max"] as Array).has(level + 1):
				continue
			var symbol := Kit.image(FortCutaway.room_icon(type), Vector2(42, 42))
			symbol.mouse_filter = Control.MOUSE_FILTER_PASS
			symbol.tooltip_text = I18n.t(String(Legion.FORT_B[type]["name"]))
			opens.add_child(symbol)
		stats.add_child(opens)
	else:
		_room_metric(stats, I18n.t("Места в комнате"), FortCutaway.room_icon(selected),
			Legion.fort_room_slots_at(selected, level), Legion.fort_room_slots_at(selected, level + 1))
	_worker_card(card_body)
	if selected in ["forge", "arsenal"] and not lg.smith_known():
		var lock := Look.label(I18n.t(Legion.SMITH_LOCK), 18, Look.WINE)
		lock.name = "FortSmithLock"
		card_body.add_child(lock)
	main_action = Look.button("", Look.icon("squad"), Look.INSET, Vector2(132, 46))
	main_action.name = "FortMainAction"
	main_action.pressed.connect(_main_action)
	card_body.add_child(main_action)
	if selected == "barracks":
		recruit_button = main_action

	requirement_banner = Look.panel(Look.INSET, 9)
	requirement_banner.name = "FortRequirementBanner"
	var requirement := HBoxContainer.new()
	requirement_banner.add_child(requirement)
	var lock_icon := Kit.image(Look.icon("lock"), Vector2(34, 34))
	lock_icon.name = "RequirementIcon"
	requirement.add_child(lock_icon)
	upgrade_reason = Look.label("", 23, Look.WINE)
	upgrade_reason.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	upgrade_reason.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	requirement.add_child(upgrade_reason)
	card_body.add_child(requirement_banner)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	card_body.add_child(actions)

	instant_button = Look.button(I18n.t("Мгновенно"), Look.resource("ingots"), Look.PAPER, Vector2(215, 64))
	instant_button.name = "FortInstant"
	instant_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	instant_button.pressed.connect(_instant_upgrade)
	instant_price = Look.label("")
	instant_price.name = "FortInstantPrice"
	instant_price.hide()
	instant_button.add_child(instant_price)
	actions.add_child(instant_button)
	var timed := VBoxContainer.new()
	timed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(timed)
	upgrade_button = Look.button(I18n.t("Улучшить") + " · " + hud.fmt(float(info["next_cost"].get("money", 0))) + " · " + duration_text(float(info["next_time"])),
		Look.resource("money"), Look.WINE, Vector2(265, 64))
	upgrade_button.name = "FortUpgrade"
	upgrade_button.pressed.connect(_upgrade)
	timed.add_child(upgrade_button)
	var extra_cost: Dictionary = (info["next_cost"] as Dictionary).duplicate()
	extra_cost.erase("money")
	upgrade_cost = _cost_icons(extra_cost)
	(upgrade_cost as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	timed.add_child(upgrade_cost)


func _room_metric(parent: VBoxContainer, title: String, tex: Texture2D, current: float, next: float) -> void:
	var stock := Look.panel(Color("faf3e8"), 6)
	stock.name = "FortRoomStock"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	stock.add_child(row)
	var pic := Kit.image(tex, Vector2(46, 46))
	pic.name = "FortRoomMetricIcon"
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pic)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.alignment = BoxContainer.ALIGNMENT_CENTER
	detail.add_theme_constant_override("separation", 3)
	row.add_child(detail)
	var heading := HBoxContainer.new()
	detail.add_child(heading)
	var label := Look.label(title, 22)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(label)
	var now_value := roundi(current)
	var next_value := roundi(next)
	var values := Look.label("%d → %d" % [now_value, next_value], 22)
	values.name = "FortRoomMetricValues"
	heading.add_child(values)
	var gain := Look.label("", 21, Look.OLIVE)
	gain.name = "FortRoomMetricGain"
	gain.custom_minimum_size.x = 52
	gain.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if next_value > now_value:
		gain.text = "+%d" % (next_value - now_value)
	heading.add_child(gain)
	room_stock_bar = Look.meter(current, next)
	room_stock_bar.name = "FortRoomStockFill"
	room_stock_bar.custom_minimum_size.y = 14
	detail.add_child(room_stock_bar)
	parent.add_child(stock)


func _refresh_card() -> void:
	var plot := lg.fort_plot(selected_plot)
	if plot.is_empty():
		return
	var timer := lg.fort_plot_timer(selected_plot)
	var running := not timer.is_empty()
	if running and is_instance_valid(upgrade_timer):
		var left := maxf(0.0, float(timer["end"]) - Legion.now())
		card_ring.set("value", 1.0 - left / maxf(1, float(timer["total"])))
		upgrade_timer.text = clock_text(left)
	if not is_instance_valid(main_action) or running:
		return
	var why := lg.fort_can_upgrade(selected_plot)
	upgrade_button.disabled = why != ""
	upgrade_button.tooltip_text = I18n.t("Улучшить") + ("\n" + I18n.t(why) if why != "" else "")
	upgrade_reason.text = I18n.t("Нужен Штаб ур. %d") % (int(plot["lv"]) + 1) if why.begins_with("Выше Штаба") else I18n.t(why)
	requirement_banner.visible = why != ""
	var prod := lg.fort_plot_production(int(plot["id"]), selected, maxi(1, int(plot["lv"])))
	var title := ""
	var reason := ""
	if not prod.is_empty():
		title = I18n.t("Собрать %d") % floori(float(plot["pend"]) + 0.0001)
		if float(plot["pend"]) < 0.9999:
			reason = I18n.t("Ресурсы ещё готовятся.")
		elif _stock(String(prod["resource"])) >= lg.resource_cap(String(prod["resource"])):
			reason = I18n.t("Запас полон. Потратьте ресурсы, чтобы собрать ещё.")
	else:
		match selected:
			"barracks":
				title = I18n.t("Отряд")
			"forge": title = I18n.t("Ковать")
			"drill": title = I18n.t("Тренировать")
			"mars": title = I18n.t("Таланты")
			"store": title = I18n.t("Запасы")
			"infirmary": title = I18n.t("Лечить")
			"arsenal": title = I18n.t("Изготовить")
			"hq":
				title = I18n.t("Расширить форт")
				reason = lg.fort_can_expand()
			_: title = I18n.t("Отряд")
	if selected != "hq" and lg.fort_worker(selected_plot).is_empty() and not running:
		title = I18n.t("Назначить")
		reason = ""
	if selected in ["forge", "arsenal"] and not lg.smith_known():
		title = I18n.t("Кузнечное знание")
		reason = ""
	if int(plot["lv"]) == 0 or running:
		reason = I18n.t("Здание строится.")
	main_action.set_meta("action_name", title)
	main_action.text = title
	var action_icon := "collect"
	if title == I18n.t("Назначить"):
		action_icon = "assign"
	elif prod.is_empty():
		action_icon = String({"forge": "craft", "arsenal": "craft", "drill": "soldier", "barracks": "squad", "hq": "build", "store": "chest", "mars": "star", "infirmary": "need_services"}.get(selected, "squad"))
	main_action.icon = Look.resource(String(prod["resource"])) if not prod.is_empty() and action_icon == "collect" else Look.icon(action_icon)
	main_action.disabled = reason != ""
	main_action.tooltip_text = title + ("\n" + I18n.t(reason) if reason != "" else "")
	var quote := lg.fort_instant_info(selected_plot)
	instant_button.set_meta("quote", quote)
	instant_price.text = str(int(quote["price"]))
	instant_button.text = I18n.t("Мгновенно") + " · " + instant_price.text
	instant_button.disabled = String(quote["why"]) != ""
	instant_button.tooltip_text = I18n.t("Завершить сразу") + ("\n" + I18n.t(String(quote["why"])) if quote["why"] != "" else "")
	_refresh_costs(card_body)


func _upgrade() -> void:
	var id := selected_plot
	if lg.fort_upgrade(id):
		_hide_card()
		_select_fort_room("plot_%d" % id)
	else:
		hud.notify(I18n.t(lg.fort_can_upgrade(id)), "lock")
	_refresh()


func _class(s: Dictionary) -> String:
	var gear: Dictionary = s.get("gear", {})
	var weapon := lg.item(int(gear.get("weapon", 0)))
	return Gear.weapon_class(weapon) if not weapon.is_empty() else "legionary"


func _soldier_title(s: Dictionary) -> String:
	return ("♛ " if bool(s.get("hero", false)) else "") + "%s · %s" % [String(s["name"]), Soldiers.stars_text(int(s["stars"]))]


func _roster(parent: VBoxContainer, training: bool) -> void:
	if lg.soldiers.is_empty():
		parent.add_child(_wrap("Пока нет воинов. Призовите жителя в Казарме."))
	for s: Dictionary in lg.soldiers:
		var sid := int(s["id"])
		var p := Kit.inset()
		parent.add_child(p)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 5)
		p.add_child(v)
		var row := HBoxContainer.new()             # имя воина и (в Казарме) маленькая кнопка «домой» — одной строкой
		row.add_theme_constant_override("separation", 6)
		v.add_child(row)
		var b := _button(_soldier_title(s), func(): _show_soldier(sid), String(CLASS_ICON.get(_class(s), "swords")))
		b.add_theme_font_size_override("font_size", 14)
		b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = Soldiers.class_name_of(_class(s))
		row.add_child(b)
		if bool(s.get("hero", false)):
			v.add_child(_button("Тренировать героя", show_hero, "laurels"))
		elif training:
			var status := _wrap(lu._soldier_status(s), 13)
			v.add_child(status)
			var bar := lu._bar(0, lg.train_progress(s))
			v.add_child(bar)
			var rank := int(s["rank"])
			var train_button := _button(I18n.t("Тренировать · %s") % hud.fmt(float(Soldiers.train_cost(rank))), func(): lg.train(sid); _refresh(), "coins")
			v.add_child(train_button)
			_training.append({"id": sid, "status": status, "bar": bar, "button": train_button})
		else:
			var home := Kit.round_button("back")
			home.custom_minimum_size = Vector2(40, 40)
			home.tooltip_text = I18n.t("Отпустить из форта")
			home.pressed.connect(func(): lg.dismiss(sid); _refresh())
			row.add_child(home)


## Прямой призыв оставлен для прежних сценариев проверки.
func recruit() -> void:
	_recruit_pick({})


func open_recruit_picker() -> void:
	_worker_target = -1
	recruit_page = 0
	show_recruit_picker()


func show_recruit_picker() -> void:
	var v := _new_modal(570)
	v.add_child(_text(I18n.t("У ворот форта"), 24, true))
	var candidates := lg.fort_newcomers()
	for candidate: Dictionary in candidates:
		var p := Kit.inset()
		v.add_child(p)
		var row := HBoxContainer.new()
		p.add_child(row)
		row.add_child(_person_portrait(candidate, 64, true))
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)
		details.add_child(_text(String(candidate["name"]), 18, true))
		details.add_child(_text(Soldiers.class_name_of(String(candidate.get("class_hint", "legionary"))), 14))
		var stars_label := _text(Soldiers.stars_text(int(candidate["stars"])), 18, true)
		stars_label.mouse_filter = Control.MOUSE_FILTER_PASS
		stars_label.tooltip_text = I18n.t(STAR_TIP)
		details.add_child(stars_label)
		var choose := _button("Принять", func(): _recruit_pick(candidate), "legion")
		choose.name = "FortGate_%d" % int(candidate["id"])
		choose.disabled = lg.can_recruit_resident() != ""
		choose.tooltip_text = lg.can_recruit_resident()
		row.add_child(choose)
		row.add_child(_button("Отпустить", func(): lg.fort_release(int(candidate["id"])); show_recruit_picker(); _refresh()))
	if candidates.is_empty():
		v.add_child(_wrap(lg.can_recruit_resident()))
	v.add_child(_button("← Лагерь", _close_modal))
	_fit_modal.call_deferred()


func _recruit_pick(pick: Dictionary) -> void:
	var teaching := lg.fort_guide_step() == Legion.FortGuide.RECRUIT
	var soldier := lg.recruit_resident(pick)
	if soldier.is_empty():
		hud.notify(lg.can_recruit_resident() if lg.can_recruit_resident() != "" else I18n.t("Новобранец уже ушёл."), "lock")
		show_recruit_picker()
		_refresh()
		return
	if is_instance_valid(diorama):
		diorama.sync()
		diorama.recruit_walk(int(soldier["id"]))
	_close_modal()
	if not teaching:
		show_dweller(int(soldier["id"]))
	_refresh()


func _new_modal(width: float, marble := false) -> VBoxContainer:
	_hide_card()
	_close_modal()
	modal = Control.new()
	add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_close_modal())
	var shade := ColorRect.new()
	shade.color = Color(0.10, 0.06, 0.03, 0.48)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_panel = Look.panel(Look.PAPER, 24) if marble else Kit.card()
	modal.add_child(modal_panel)
	modal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_panel.custom_minimum_size.x = width
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	modal_panel.add_child(v)
	return v


func _fit_modal() -> void:
	if not is_instance_valid(modal_panel):
		return
	Kit.fit_modal(modal_panel, size)
	var dims := modal_panel.size
	var k := modal_panel.scale.x
	if _popup_resource != "":
		var bar: Control = resource_bars[_popup_resource]["panel"]
		var rect := bar.get_global_rect()
		modal_panel.position = Vector2(clampf(rect.position.x - global_position.x, 24, maxf(24, size.x - dims.x * k - 24)), rect.end.y - global_position.y + 8)
	if recruit_result:
		# Карточка справа оставляет путь от ворот к казарме на виду.
		modal_panel.position = Vector2(maxf(24, size.x - dims.x * k - 24), maxf(24, size.y - dims.y * k - 82))
	if is_instance_valid(build_scroll):
		modal_panel.position.y = size.y - dims.y * k - 24
	modal_panel.position = modal_panel.position.clamp(Vector2.ONE * 24, (size - dims * k - Vector2.ONE * 24).max(Vector2.ONE * 24))
	_layout_guide.call_deferred()


func _close_modal() -> void:
	dweller_sid = 0
	_worker_target = -1
	_popup_resource = ""
	_healing.clear()
	stock_labels.clear()
	build_cards.clear()
	build_scroll = null
	_support_kind = ""
	_training.clear()
	if is_instance_valid(modal):
		modal.hide()
		modal.queue_free()
	modal = null
	recruit_result = false
	hero_status = null
	hero_bar = null
	hero_train_button = null
	modal_panel = null
	squad_body = null
	selected_place = -1
	_layout_guide.call_deferred()


func show_squad() -> void:
	squad_body = _new_modal(640)
	_build_squad()


func _build_squad() -> void:
	_clear(squad_body)
	_squad_sig = _roster_signature()
	var head := HBoxContainer.new()
	var title := _text("Отряд", 26, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_button("← Лагерь", _close_modal))
	squad_body.add_child(head)
	squad_body.add_child(_wrap("Выберите пустое место, затем воина. Нажмите занятое место, чтобы освободить его.", 14))
	for row_index in 2:
		squad_body.add_child(_text("Передний ряд" if row_index == 0 else "Задний ряд", 14, true))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		squad_body.add_child(row)
		for i in range(0 if row_index == 0 else 3, 3 if row_index == 0 else 5):
			var soldier := lg.soldier(int(lg.squad3[i]))
			var locked := i >= lg.slots()
			var label := I18n.t("Казарма ур. %d") % (3 if i == 3 else 5) if locked else (I18n.t("Выбрано") if i == selected_place else I18n.t("Пустое место"))
			if not locked and not soldier.is_empty():
				label = ("♛ " if bool(soldier.get("hero", false)) else "") + String(soldier["name"]) + "\n" + Soldiers.stars_text(int(soldier["stars"]))
			var icon := "lock" if locked else (String(CLASS_ICON.get(_class(soldier), "swords")) if not soldier.is_empty() else "shield")
			var b := _button(label, func(): _pick_place(i), icon)
			b.set_meta("quest_slot", i)
			b.custom_minimum_size = Vector2(188, 72)
			b.add_theme_font_size_override("font_size", 13)
			b.clip_text = true
			b.disabled = locked or bool(soldier.get("hero", false))
			b.tooltip_text = label
			if i == selected_place:
				Kit.style_button(b, "gold")
			row.add_child(b)
	squad_body.add_child(_wrap(I18n.t("Готовы к бою: %d / %d") % [lg.squad_v3().size(), lg.slots()], 14))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size.y = 180
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	squad_body.add_child(sc)
	var roster := VBoxContainer.new()
	roster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(roster)
	if lg.soldiers.is_empty():
		roster.add_child(_wrap("Пока нет воинов. Призовите жителя в Казарме."))
	for s: Dictionary in lg.soldiers:
		if not lg.fort_is_fighter(int(s["id"])):
			continue
		var sid := int(s["id"])
		var soldier_row := HBoxContainer.new()
		roster.add_child(soldier_row)
		var b := _button(_soldier_title(s), func(): _assign(sid), String(CLASS_ICON.get(_class(s), "swords")))
		b.set_meta("quest_soldier", sid)
		b.disabled = selected_place < 0 or bool(s.get("hero", false))
		b.tooltip_text = "Сначала выберите пустое место." if selected_place < 0 else lu._soldier_status(s)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		soldier_row.add_child(b)
		var info := Kit.round_button("info")
		info.custom_minimum_size = Vector2(40, 40)
		info.tooltip_text = String(s["name"])
		info.pressed.connect(func(): _show_soldier(sid))
		soldier_row.add_child(info)
	squad_body.add_child(_wrap("Меч — Легионер · Лук — Лучник · Посох — Жрец · Копьё — Всадник", 14))
	_fit_modal.call_deferred()


func _pick_place(index: int) -> void:
	if index >= lg.slots():
		return
	if int(lg.squad3[index]) != 0:
		lg.set_place(index, 0)
	selected_place = index
	_build_squad()


func _assign(sid: int) -> void:
	if selected_place >= 0 and lg.set_place(selected_place, sid):
		selected_place = -1
		_build_squad()


func _quest_campaign() -> void:
	var frontier := lg.frontier()
	_campaign()
	lu.open_fort_stage(int(frontier["cycle"]), int(frontier["r"]), int(frontier["s"]))


func _campaign() -> void:
	_clear_room_selection()
	_close_modal()
	_hide_card()
	lu.open("campaign")


func _aux(kind: String, sid := 0) -> void:
	_clear_room_selection()
	_close_modal()
	_hide_card()
	lu.open_camp_window(kind, sid)


static func duration_text(seconds: float) -> String:
	var minutes := maxi(1, ceili(seconds / 60.0)) if seconds > 0.0 else 0
	if minutes >= 1440:
		if minutes % 1440 == 0:
			return I18n.t("%d д") % (minutes / 1440)
		return I18n.t("%d д %d ч") % [minutes / 1440, (minutes % 1440) / 60]
	if minutes >= 60:
		return I18n.t("%d ч %d мин") % [minutes / 60, minutes % 60]
	return I18n.t("%d мин") % minutes


func _resource_tip(resource: String) -> String:
	var text := I18n.t(String(RESOURCE_TIP[resource]))
	var missing := lg.bakeries_working() == 0 if resource == "rations" else lg.count_type(Legion.workshop_of(resource)) == 0
	if missing:
		text += "\n" + I18n.t(String(RESOURCE_BUILD[resource]))
	return text


func _build_bubbles() -> void:
	# Городские производства остаются доступны: форт добавляет собственные буферы.
	for resource: String in ["rations", "iron", "wood", "leather"]:
		var box := Control.new()
		box.custom_minimum_size = Vector2(48, 48)
		box.size = Vector2(48, 48)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(box)
		var b := Kit.round_button(Look.resource(resource))
		b.custom_minimum_size = Vector2(48, 48)
		b.pressed.connect(func(): _collect(resource))
		b.name = "Collect_" + resource
		box.add_child(b)
		var ring := Ring.new()
		box.add_child(ring)
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bubbles[resource] = {"box": box, "button": b, "bar": ring}


func _layout_bubbles(k: float) -> void:
	for resource: String in bubbles:
		var box: Control = bubbles[resource]["box"]
		box.scale = Vector2.ONE * k
		var slot := "hq" if resource == "rations" else "store"
		var marker: Control = plaques[slot]["panel"]
		var index := 0 if resource == "rations" else ["iron", "wood", "leather"].find(resource)
		box.position = _screen_anchor(marker.position + Vector2((index - 1) * 52 + 34, -24) * k, Vector2(48, 48) * k)


func _refresh_bubbles() -> void:
	for resource: String in bubbles:
		var amount := float(lg.pending_resources.get(resource, 0.0))
		var cap := lg.resource_cap(resource)
		var b: Button = bubbles[resource]["button"]
		(bubbles[resource]["box"] as Control).visible = amount >= 0.9999
		b.disabled = amount < 0.9999 or _stock(resource) >= cap
		b.tooltip_text = I18n.t("Собрать %d") % floori(amount + 0.0001) + " · " + I18n.t(String(RESOURCE_NAME[resource]))
		if b.disabled:
			b.tooltip_text += "\n" + I18n.t("Запас полон. Потратьте ресурсы, чтобы собрать ещё.")
		bubbles[resource]["bar"].set("value", amount / maxf(1.0, cap))


func _collect(resource: String) -> void:
	var source: Button = bubbles[resource]["button"]
	var origin := source.global_position
	var amount := lg.collect_resource(resource)
	if amount <= 0:
		return
	_fly_resource(resource, amount, origin)
	_refresh()


func _fly_resource(resource: String, amount: int, origin: Vector2) -> void:
	var fly := _text("+%d" % amount, 25, true)
	fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fly)
	fly.global_position = origin
	# Материалы летят к Складу: в верхней строке только четыре основных ресурса.
	var target: Control = resource_chips[resource] if resource_chips.has(resource) else plaques["store"]["panel"]
	var tween := create_tween().set_parallel(true)
	_collection_fx = _collection_fx.filter(func(entry: Dictionary): return is_instance_valid(entry["label"]))
	_collection_fx.append({"tween": tween, "label": fly})
	tween.tween_property(fly, "global_position", target.global_position, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(fly, "modulate:a", 0.0, 0.25).set_delay(0.45)
	tween.chain().tween_callback(fly.queue_free)


func show_hero() -> void:
	var v := _new_modal(560)
	hero_card_level = lg.hero_level()
	v.add_child(_text("♛ " + Hero.name_of(lg.city()), 26, true))
	for person: Dictionary in lg.soldiers:
		if bool(person.get("hero", false)):
			var portrait := _person_portrait(person, 136)
			portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			v.add_child(portrait)
			break
	v.add_child(_wrap("Первый воин Легиона. Герой остаётся с вами.", 16))
	v.add_child(_wrap("Снаряжение героя улучшает Склад.", 14))
	hero_status = _wrap("", 20)
	v.add_child(hero_status)
	hero_bar = lu._bar(0, 0)
	v.add_child(hero_bar)
	v.add_child(lu._cost_row(lg.hero_train_info()["cost"]))
	hero_train_button = _button("Тренировать героя", func(): lg.train_hero(); show_hero(), "laurels")
	v.add_child(hero_train_button)
	v.add_child(_button("← Лагерь", _close_modal))
	_refresh_hero()
	_fit_modal.call_deferred()


func _refresh_hero() -> void:
	if not is_instance_valid(hero_status) or hero_status.is_queued_for_deletion():
		return
	if hero_card_level != lg.hero_level():
		show_hero()
		return
	var running := not lg.hero_training.is_empty()
	var info := lg.hero_train_info()
	var left := maxf(0.0, float(lg.hero_training.get("end", 0.0)) - Legion.now()) if running else float(info["time"])
	hero_status.text = I18n.t("ур. %d → %d · %s") % [lg.hero_level(), int(info["to"]), duration_text(left)]
	hero_bar.visible = running
	hero_bar.value = 1.0 - left / maxf(1.0, float(lg.hero_training.get("total", 1.0))) if running else 0.0
	hero_train_button.disabled = lg.can_train_hero() != ""
	hero_train_button.tooltip_text = lg.can_train_hero()


func show_chests(reward: Dictionary = {}) -> void:
	var v := _new_modal(620)
	v.add_child(_text(I18n.t("Сундуки %d / 4") % lg.chest_queue.size(), 25, true))
	if not guide_active():
		v.add_child(_wrap("Первая победа даёт сундук. За повторную: 15% за каждую звезду. Мест — 4.", 14))
		v.add_child(_wrap("Редкости: обычное / редкое / эпическое / легендарное", 14))
		v.add_child(_wrap(Legion.CHEST_ODDS, 15))
		v.add_child(_wrap("Слитки: деревянный 2% · бронзовый 4% · золотой 6%. По 1–3 слитка.", 14))
	for kind: String in lg.chest_queue:
		var b := _button(I18n.t("Открыть: %s") % I18n.t(String(Legion.CHEST_NAMES[kind])), func(): show_chests(lg.open_chest(kind)); _refresh(), "coins")
		b.name = "FortChest_" + kind
		b.disabled = lg.store_count() >= lg.store_cap()
		b.tooltip_text = I18n.t("Освободите место для вещи на Складе.") if b.disabled else I18n.t("Открывается сразу.")
		v.add_child(b)
	if lg.chest_queue.is_empty() and reward.is_empty():
		v.add_child(_wrap("Сундуки принесут победы в походах."))
	if not reward.is_empty():
		v.add_child(hud._divider(8))
		v.add_child(_wrap(I18n.t("Добыча: %d ден. · %d пайков · %d слитков") % [int(reward["money"]) - int(reward.get("money_lost", 0)), int(reward["rations"]), int(reward["ingots"])], 18))
		v.add_child(_wrap(I18n.t("Железо %d · Дерево %d · Кожа %d") % [int(reward["iron"]), int(reward["wood"]), int(reward["leather"])]))
		v.add_child(_wrap(Gear.name_of(reward["item"]), 18))
	var back := _button("← Лагерь", _close_modal)
	back.name = "FortChestBack"
	v.add_child(back)
	_fit_modal.call_deferred()


func _show_soldier(sid: int) -> void:
	if bool(lg.soldier(sid).get("hero", false)):
		show_hero()
	else:
		show_dweller(sid)


func _start_diorama() -> void:
	if not _city_render_owned:
		_previous_disable_3d = get_viewport().disable_3d
		_city_render_owned = true
		get_viewport().disable_3d = true
	if not USE_3D or not lg.v3() or is_instance_valid(diorama):
		return
	var scene: Camp3D = FortCutaway.new() if use_cutaway else Camp3D.new()
	add_child(scene)
	move_child(scene, 1)
	if not scene.setup(lg, hud.game):
		scene.shutdown()
		scene.queue_free()
		background.show()
		return
	diorama = scene
	if diorama is FortCutaway:
		(diorama as FortCutaway).person_pressed.connect(func(sid: int, newcomer: bool):
			if newcomer:
				show_newcomer(sid)
			else:
				_show_soldier(sid))
		(diorama as FortCutaway).person_moved.connect(func(_sid: int, _id: int): _refresh())
		(diorama as FortCutaway).room_deselected.connect(_clear_room_selection)
		(diorama as FortCutaway).drag_updated.connect(_show_drag_context)
		(diorama as FortCutaway).move_finished.connect(func():
			drag_name.hide()
			drag_context.hide()
			if guide_active():
				_layout_guide())
		cutaway_markers = Control.new()
		cutaway_markers.name = "CutawayMarkers"
		cutaway_markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cutaway_markers)
		move_child(cutaway_markers, 2)
		_plots_sig = ""
		diorama.view_changed.connect(_layout_cutaway_view)
	else:
		diorama.view_changed.connect(_layout)
	diorama.building_pressed.connect(_select_fort_room if diorama is FortCutaway else show_building)
	background.hide()


func _stop_diorama() -> void:
	if is_instance_valid(cutaway_markers):
		for entry: Dictionary in plot_markers.values():
			counters.erase(entry["button"])
		cutaway_markers.queue_free()
		cutaway_markers = null
		plot_markers.clear()
		_plots_sig = ""
	if is_instance_valid(diorama):
		diorama.shutdown()
		diorama.queue_free()
		diorama = null
	if _city_render_owned:
		get_viewport().disable_3d = _previous_disable_3d
		_city_render_owned = false
	if is_instance_valid(background):
		background.show()


func _exit_tree() -> void:
	_stop_diorama()
	if is_instance_valid(guide_layer):
		guide_layer.queue_free()


func _screen_anchor(center: Vector2, dims: Vector2, top_margin := 76.0, bottom_margin := 82.0) -> Vector2:
	return Vector2(clampf(center.x - dims.x * 0.5, 8, maxf(8, size.x - dims.x - 8)),
		clampf(center.y - dims.y * 0.5, top_margin, maxf(top_margin, size.y - dims.y - bottom_margin)))


func guide_active() -> bool:
	var step := lg.fort_guide_step()
	return step > Legion.FortGuide.INACTIVE and step < Legion.FortGuide.DONE


func _skip_guide() -> void:
	lg.finish_fort_guide()
	_layout_guide()
	if visible:
		_refresh()
	elif lu.visible:
		lu._dirty = true


func _guide_person(sid: int, newcomer := false) -> Rect2:
	if diorama is FortCutaway:
		var cutaway := diorama as FortCutaway
		var point := cutaway.person_project(sid, newcomer)
		if Rect2(Vector2.ZERO, size).has_point(point):
			return Rect2(cutaway.global_position + point - Vector2(16, 16), Vector2(32, 32))
	_guide_target = population_button
	return Rect2()


func _guide_room(type: String) -> Control:
	var id := int(lg.fort_slot_plot(type).get("id", -1))
	var marker: Dictionary = plot_markers.get(id, {})
	if not lg.fort_plot_timer(id).is_empty():
		return marker.get("clock") as Control
	return marker.get("panel") as Control


func _guide_modal_target(target_name: String) -> Control:
	return modal_panel.find_child(target_name, true, false) as Control


func _guide_move_target(sid: int, type: String) -> void:
	if is_instance_valid(modal_panel):
		var id := int(lg.fort_slot_plot(type).get("id", -1))
		_guide_target = _guide_modal_target("FortMoveDweller" if dweller_sid == sid else "FortMoveTo_%d" % id)
		if _guide_target == null:
			_guide_target = _guide_modal_target("FortPerson_%d" % sid)
	elif diorama is FortCutaway and (diorama as FortCutaway).drag_sid == sid:
		var view := diorama as FortCutaway
		var id := int(lg.fort_slot_plot(type).get("id", -1))
		var room := view.plot_footprint(id).intersection(Rect2(Vector2.ZERO, view.size))
		_guide_rect = Rect2(view.global_position + room.position, room.size)
	else:
		_guide_rect = _guide_person(sid)


func _layout_guide() -> void:
	if not is_instance_valid(guide_layer):
		return
	_guide_target = null
	_guide_rect = Rect2()
	if not guide_active():
		guide_layer.hide()
		return
	var step := lg.fort_guide_step()
	var sid := int(lg.flags.get("fort_guide_sid", 0))
	var cooking_id := int(lg.flags.get("fort_guide_plot", -1))
	var tip := ""
	if lu.visible:
		if lu.camp_window != "" or step != Legion.FortGuide.CAMPAIGN:
			guide_layer.hide()
			return
		tip = "В поход! Первый бой"
		if lu.guide_stage_button == null:
			_guide_target = lu.guide_region_button
		else:
			var first_selected := lu.sel == {"c": 0, "r": 0, "s": 0} and is_instance_valid(lu._fight_btn) and bool(lg.flags.get("fort_guide_stage", false))
			_guide_target = lu._fight_btn if first_selected else lu.guide_stage_button
	elif not visible or is_instance_valid(card):
		guide_layer.hide()
		return
	else:
		match step:
			Legion.FortGuide.RECRUIT:
				tip = "Новобранец у ворот — нажмите на него"
				var arrivals := lg.fort_newcomers()
				if not arrivals.is_empty():
					var newcomer := int(arrivals[0]["id"])
					if is_instance_valid(modal_panel):
						_guide_target = _guide_modal_target("FortAccept")
						if _guide_target == null:
							_guide_target = _guide_modal_target("FortGate_%d" % newcomer)
						if _guide_target == null:
							_guide_target = _guide_modal_target("FortGatePeople")
					else:
						_guide_rect = _guide_person(newcomer, true)
			Legion.FortGuide.KITCHEN:
				var kitchen := lg.fort_slot_plot("kitchen")
				if kitchen.is_empty():
					tip = "Постройте кухню"
					if placement_type != "":
						_guide_target = plot_markers.get(lg.fort_empty_plot(), {}).get("button") as Control
					else:
						_guide_target = build_cards.get("kitchen", {}).get("button") as Control if is_instance_valid(build_scroll) else build_button
				elif int(kitchen["lv"]) == 0 or not (kitchen["up"] as Dictionary).is_empty():
					tip = "Кухня строится…"
					_guide_target = room_action_row.find_child("FortSpeedUp", false, false) as Control if room_action_id == int(kitchen["id"]) and not is_instance_valid(modal) else _guide_room("kitchen")
					if is_instance_valid(modal_panel):
						_guide_target = _guide_modal_target("FortFinishNow")
				else:
					tip = "Перетащите его на кухню"
					_guide_move_target(sid, "kitchen")
			Legion.FortGuide.RATIONS:
				if lg.fort_worker_plot(sid) == cooking_id:
					tip = "Готовит пайки… Нажмите на хлеб над кухней"
					_guide_target = plot_markers.get(cooking_id, {}).get("collect") as Control
				else:
					tip = "Перетащите его на кухню"
					_guide_move_target(sid, "kitchen")
			Legion.FortGuide.CHEST:
				tip = "Откройте сундук"
				_guide_target = _guide_modal_target("FortChest_wooden") if is_instance_valid(modal_panel) else chest_button
			Legion.FortGuide.EQUIP:
				tip = "Оденьте воина: нажмите на него и выберите вещь"
				if is_instance_valid(modal_panel):
					var iid := int(lg.flags.get("fort_guide_item", 0))
					if dweller_sid == sid:
						_guide_target = _guide_modal_target("FortEquip_%d" % iid)
						if _guide_target == null:
							_guide_target = _guide_modal_target("FortAllGear")
					else:
						_guide_target = _guide_modal_target("FortChestBack")
						if _guide_target == null:
							_guide_target = _guide_modal_target("FortPerson_%d" % sid)
				else:
					_guide_rect = _guide_person(sid)
			Legion.FortGuide.BARRACKS:
				tip = "Назначьте его в казарму — он станет бойцом"
				_guide_move_target(sid, "barracks")
			Legion.FortGuide.CAMPAIGN:
				tip = "В поход! Первый бой"
				_guide_target = campaign_button
			Legion.FortGuide.FINISH:
				tip = "Сокровищница копит денарии.\nДеньги из города — кнопкой слева, раз в 5 часов"
				_guide_target = order_button
	if is_instance_valid(_guide_target) and _guide_target.is_visible_in_tree():
		_guide_rect = _guide_target.get_global_rect()
		if _guide_target == lu.guide_stage_button and is_instance_valid(lu.fort_map):
			_guide_rect = _guide_rect.intersection(lu.fort_map.get_global_rect())
	if not _guide_rect.has_area():
		guide_layer.hide()
		return
	guide_text.text = I18n.t(tip)
	guide_skip.text = I18n.t("Понятно" if step == Legion.FortGuide.FINISH else "Пропустить обучение")
	guide.reset_size()
	var area := guide_layer.size
	var k := minf(1.0, minf(area.y / 720.0, maxf(1.0, area.x - 16) / maxf(1.0, guide.size.x)))
	guide.scale = Vector2.ONE * k
	guide_pointer.scale = Vector2.ONE * k
	var rect := Rect2(_guide_rect.position - guide_layer.global_position, _guide_rect.size)
	var arrow_size := guide_pointer.size * k
	var dims := guide.size * k
	var x := clampf(rect.get_center().x, arrow_size.x * 0.5, maxf(arrow_size.x * 0.5, area.x - arrow_size.x * 0.5))
	var above := rect.position.y >= arrow_size.y + dims.y + 8.0 or rect.get_center().y > area.y * 0.5
	var y := rect.position.y - arrow_size.y + 2.0 if above else rect.end.y - 2.0
	guide_pointer.flip_v = not above
	guide_pointer.position = Vector2(x - arrow_size.x * 0.5, y)
	var bubble_y := y - dims.y * 0.5 if above else y + arrow_size.y + dims.y * 0.5
	guide.position = _screen_anchor(Vector2(x, bubble_y), dims, 8, 8)
	guide_layer.move_to_front()
	guide_layer.show()


func _stock(resource: String) -> float:
	if resource == "money":
		return lg.city_money()
	if resource == "glory":
		return lg.glory
	if resource == "ingots":
		return float(lg.ingots)
	return lg.rations if resource == "rations" else float(lg.mats.get(resource, 0.0))


func _cost_icons(cost: Dictionary, highlight_shortage := true) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	var amounts: Dictionary = cost.get("mats", {}).duplicate()
	for resource: String in ["money", "glory"]:
		if float(cost.get(resource, 0)) > 0:
			amounts[resource] = cost[resource]
	var labels := {}
	for resource: String in ["money", "glory", "iron", "wood", "leather"]:
		var amount := float(amounts.get(resource, 0))
		if amount <= 0:
			continue
		var pair := HBoxContainer.new()
		row.add_child(pair)
		pair.add_child(Kit.image(Look.resource(resource), Vector2(28, 28)))
		var number := _text(hud.fmt(amount) if is_equal_approx(amount, floorf(amount)) else String.num(amount, 2), 16, true)
		pair.add_child(number)
		labels[resource] = number
	if highlight_shortage:
		row.set_meta("cost", amounts)
		row.set_meta("cost_labels", labels)
		_refresh_costs(row)
	return row


func _refresh_costs(node: Node) -> void:
	if node.has_meta("cost_labels"):
		var labels: Dictionary = node.get_meta("cost_labels")
		var amounts: Dictionary = node.get_meta("cost")
		for resource: String in labels:
			(labels[resource] as Label).add_theme_color_override("font_color", LegionUi.C_BAD if _stock(resource) < float(amounts[resource]) else LegionUi.C_INK)
	for child: Node in node.get_children():
		_refresh_costs(child)


func show_resource_popup(resource: String) -> void:
	if not TOP_NAMES.has(resource):
		return
	var v := _new_modal(390)
	_popup_resource = resource
	modal_panel.name = "FortResourcePopup"
	var heading := HBoxContainer.new()
	v.add_child(heading)
	var heading_icon := TextureRect.new()
	heading_icon.texture = Look.icon(resource)
	heading_icon.custom_minimum_size = Vector2(38, 38)
	heading_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	heading_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heading.add_child(heading_icon)
	var title := _text(I18n.t(String(TOP_NAMES[resource])), 24, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	heading.add_child(_button("×", _close_modal))
	v.add_child(_wrap(I18n.t(String(TOP_TIPS[resource])), 16))
	match resource:
		"rations": v.add_child(_button("К полевой кухне", func(): _jump_to_type("kitchen"), "bread"))
		"ingots": v.add_child(_button("Сундуки", show_chests, "commerce"))
		"money":
			v.add_child(_button("К Сокровищнице", func(): _jump_to_type("treasury"), "coins"))
			var order := _button("Заказать денарии из города", _order_city_money, "coins")
			order.disabled = lg.city_order_info()["why"] != ""
			order.tooltip_text = order_button.tooltip_text
			v.add_child(order)
		"glory": v.add_child(_button("Поход", _campaign, "scroll"))
	_fit_modal.call_deferred()


func _jump_to_type(type: String) -> void:
	var plot := lg.fort_slot_plot(type)
	if plot.is_empty():
		build_focus = type
		show_build_menu()
	else:
		show_plot(int(plot["id"]))
		if is_instance_valid(diorama):
			diorama.focus_plot("plot_%d" % int(plot["id"]))


func show_build_menu(plot_id := -1) -> void:
	_set_placement("")
	_clear_room_selection()
	build_pinned = plot_id >= 0
	build_plot_id = plot_id if build_pinned else lg.fort_empty_plot()
	var v := _new_modal(970, true)
	if lg.fort_guide_step() == Legion.FortGuide.KITCHEN:
		build_tab = 0
	modal_panel.name = "FortBuildMenu"
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := Look.label(I18n.t("Строить"), 38, Look.INK, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_button("×", _close_modal))
	var free := 0
	for plot: Dictionary in lg.fort.get("plots", []):
		if plot["b"] == "":
			free += 1
	v.tooltip_text = I18n.t("Свободных участков: %d") % free
	if free == 0:
		v.add_child(_button("К Штабу: расширить форт", func(): show_building("hq"), "castle"))
	build_scroll = ScrollContainer.new()
	build_scroll.name = "FortBuildScroll"
	build_scroll.custom_minimum_size = Vector2(660, 470)
	build_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(build_scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	build_scroll.add_child(row)
	for type: String in Legion.FORT_B:
		if type == "hq":
			continue
		var spec: Dictionary = Legion.FORT_B[type]
		var panel := Look.panel(Look.INSET, 12)
		panel.custom_minimum_size = Vector2(265, 308)
		row.add_child(panel)
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 7)
		panel.add_child(body)
		var picture := _room_picture(type, 1, Vector2(202, 104))
		picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		body.add_child(picture)
		var title_label := _text(I18n.t(String(spec["name"])), 18, true)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(title_label)
		var gives := Look.label(I18n.t(String(spec["gives"])), 17)
		gives.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gives.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		body.add_child(gives)
		panel.tooltip_text = gives.text
		body.add_child(_cost_icons(Legion.fort_cost(type, 1)))
		body.add_child(Kit.time_row(duration_text(lg.fort_build_seconds(type, 1))))
		var count := _text("", 14, true)
		body.add_child(count)
		var button := Look.button(I18n.t("Строить"), Look.icon("build"), Look.WINE, Vector2(132, 58))
		button.pressed.connect(func(): _choose_build(type))
		button.name = "Build_" + type
		body.add_child(button)
		var reason := _wrap("", 12)
		reason.custom_minimum_size.x = 196
		reason.visible = false
		body.add_child(reason)
		build_cards[type] = {"panel": panel, "button": button, "count": count, "reason": reason, "picture": picture}
	build_scroll.custom_minimum_size = Vector2(868, 370)
	var tabs_row := HBoxContainer.new()
	tabs_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(tabs_row)
	var tab_names := ["Добыча", "Тренировка", "Поддержка"]
	for tab_index in tab_names.size():
		var tab := Look.button(I18n.t(tab_names[tab_index]), null, Look.SLATE if build_tab == tab_index else Look.PAPER)
		tab.pressed.connect(func():
			build_tab = tab_index
			show_build_menu(build_plot_id if build_pinned else -1))
		tabs_row.add_child(tab)
	for type: String in build_cards:
		var group := 0 if not Legion.fort_production(type, 1).is_empty() else 1 if type in ["barracks", "drill", "stable"] else 2
		(build_cards[type]["panel"] as Control).visible = group == build_tab
	_build_sig = _plot_signature()
	_refresh_build_menu()
	_fit_modal.call_deferred()
	_focus_build_card.call_deferred()


func _focus_build_card() -> void:
	var type := build_focus
	build_focus = ""
	if type == "" and lg.fort_guide_step() == Legion.FortGuide.KITCHEN and lg.fort_count("kitchen") == 0:
		type = "kitchen"
	if is_instance_valid(build_scroll) and build_cards.has(type):
		build_scroll.ensure_control_visible(build_cards[type]["button"])
	_layout_guide()


func _refresh_build_menu() -> void:
	if _build_sig != _plot_signature():
		var previous := build_scroll.scroll_horizontal
		show_build_menu(build_plot_id if build_pinned else -1)
		build_scroll.set_deferred("scroll_horizontal", previous)
		return
	for type: String in build_cards:
		var entry: Dictionary = build_cards[type]
		var cap := lg.fort_max(type)
		var count := lg.fort_count(type)
		var why := lg.fort_can_build(type, build_plot_id if build_pinned else lg.fort_empty_plot())
		(entry["count"] as Label).text = "%d / %d" % [count, cap]
		var button: Button = entry["button"]
		button.text = I18n.t("Строить")
		button.icon = Look.icon("lock" if why != "" else "build")
		button.disabled = why != ""
		if cap == 0:
			why = I18n.t("Штаб ур. %d") % int(Legion.FORT_B[type]["max"][0])
		button.tooltip_text = I18n.t("Строить") + ("\n" + I18n.t(why) if why != "" else "")
		(entry["reason"] as Label).text = I18n.t(why)
		(entry["reason"] as Label).visible = why != ""
		(entry["picture"] as Control).modulate = Color(0.55, 0.55, 0.55) if cap == 0 else Color.WHITE
		_refresh_costs(entry["panel"])


func _choose_build(type: String) -> void:
	if build_pinned or not diorama is FortCutaway:
		_place_build(build_plot_id, type)
		return
	_close_modal()
	_set_placement(type)
	_refresh()


func _set_placement(type: String) -> void:
	placement_type = type
	placement_hint.text = I18n.t("Выберите участок") if type != "" else ""
	if not diorama is FortCutaway:
		return
	var view := diorama as FortCutaway
	view.placement_rooms.clear()
	if type != "":
		for plot: Dictionary in lg.fort["plots"]:
			var id := int(plot["id"])
			if plot["b"] == "" and lg.fort_can_build(type, id) == "":
				view.placement_rooms[id] = true
	view._refresh_rims()


func _cancel_placement() -> void:
	show_build_menu()
	_refresh()


func _place_build(id: int, type := "") -> void:
	var room_type := placement_type if type == "" else type
	if not lg.fort_build(room_type, id):
		hud.notify(I18n.t(lg.fort_can_build(room_type, id)), "lock")
		if is_instance_valid(build_scroll):
			_refresh_build_menu()
		return
	build_plot_id = -1
	_close_modal()
	_set_placement("")
	if diorama is FortCutaway:
		_select_fort_room("plot_%d" % id)
	else:
		show_plot(id)
	_refresh()


func _main_action() -> void:
	if selected in ["forge", "arsenal"] and not lg.smith_known():
		show_smith_knowledge()
		return
	var plot := lg.fort_plot(selected_plot)
	if plot.is_empty():
		return
	if selected != "hq" and lg.fort_worker(selected_plot).is_empty():
		show_worker_picker()
		return
	if not Legion.fort_production(selected, int(plot["lv"])).is_empty():
		_collect_plot(selected_plot, main_action.global_position)
		return
	match selected:
		"barracks": show_squad()
		"forge", "arsenal":
			var plot_id := selected_plot
			_close_modal()
			_hide_card()
			lu.open_craft(plot_id)
		"mars": _aux(selected)
		"store": show_stocks()
		"drill": _show_support("drill")
		"infirmary": _show_support("infirmary")
		"hq":
			if not lg.fort_expand():
				hud.notify(I18n.t(lg.fort_can_expand()), "lock")
			_build_card()
			_refresh()
		_: show_squad()


func show_stocks() -> void:
	var v := _new_modal(430)
	v.add_child(_text(I18n.t("Запасы"), 24, true))
	for resource: String in ["iron", "wood", "leather"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		v.add_child(row)
		row.add_child(lu._tr(lu._mat_tex(resource), 36))
		var title := _text(I18n.t(String(RESOURCE_NAME[resource])), 17)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
		var amount := _text("%d / %d" % [lg.mat(resource), lg.resource_cap(resource)], 18, true)
		row.add_child(amount)
		stock_labels[resource] = amount
	v.add_child(_button("Снаряжение", func(): _aux("store"), "shield"))
	v.add_child(_button("Закрыть", _close_modal))
	_fit_modal.call_deferred()


func _show_support(kind: String) -> void:
	var v := _new_modal(600)
	_support_kind = kind
	_support_sig = _roster_signature()
	v.add_child(_text(I18n.t("Тренировать" if kind == "drill" else "Лечить"), 24, true))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(540, 310)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	if kind == "drill":
		_roster(body, true)
		for entry: Dictionary in _training:
			var why := lg.can_train(int(entry["id"]))
			(entry["button"] as Button).disabled = why != ""
			(entry["button"] as Button).tooltip_text = I18n.t(why)
	else:
		body.add_child(_wrap(I18n.t("Раненые лечатся сами. Лазарет сокращает время лечения.")))
		if lg.count_state("wound") == 0:
			body.add_child(_text(I18n.t("Все воины здоровы."), 18, true))
		for soldier: Dictionary in lg.soldiers:
			if lg.s_state(soldier) == "wound":
				body.add_child(_text(String(soldier["name"]), 18, true))
				var status := _wrap(lu._soldier_status(soldier))
				body.add_child(status)
				_healing.append({"id": int(soldier["id"]), "status": status})
	v.add_child(_button("Закрыть", _close_modal))
	_fit_modal.call_deferred()


func _refresh_support() -> void:
	for entry: Dictionary in _training:
		var soldier := lg.soldier(int(entry["id"]))
		(entry["status"] as Label).text = lu._soldier_status(soldier)
		var why := lg.can_train(int(entry["id"]))
		(entry["button"] as Button).disabled = why != ""
		(entry["button"] as Button).tooltip_text = I18n.t(why)
		var bar: ProgressBar = entry["bar"]
		bar.visible = lg.s_state(soldier) == "train"
		bar.value = lg.train_progress(soldier) if bar.visible else 0.0
	for entry: Dictionary in _healing:
		(entry["status"] as Label).text = lu._soldier_status(lg.soldier(int(entry["id"])))


func _plot_signature() -> String:
	var data := []
	for plot: Dictionary in lg.fort.get("plots", []):
		data.append([plot["id"], plot["b"], plot["lv"], (plot["up"] as Dictionary).is_empty(), plot.get("worker", 0)])
	return str([data, (lg.fort.get("up", {}) as Dictionary).is_empty()])


func _marker(plot_id: int, type: String) -> Dictionary:
	var panel := Control.new()
	panel.custom_minimum_size = Vector2(68, 118)
	panel.size = panel.custom_minimum_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_meta("plot", plot_id)
	panel.set_meta("slot", type)
	var button := Kit.round_button(FortCutaway.room_icon(type))
	button.custom_minimum_size = Vector2(56, 56)
	button.pressed.connect(func():
		var id := int(panel.get_meta("plot"))
		if id >= 0:
			if diorama is FortCutaway:
				_select_fort_room("plot_%d" % id)
			else:
				show_plot(id)
		else:
			show_building(String(panel.get_meta("slot"))))
	panel.add_child(button)
	button.position = Vector2(6, 58)
	var level := _text("", 13, true)
	level.add_theme_stylebox_override("normal", Kit.box("buttons/badge_counter", 0, 3))
	level.add_theme_color_override("font_color", Color.WHITE)
	button.add_child(level)
	level.position = Vector2(38, 38)
	var alert := _badge(button)
	var collect := Look.button("", Look.resource("rations"), Look.PAPER, Vector2(90, 42))
	collect.name = "FortCollect"
	collect.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	collect.pressed.connect(func(): _collect_plot(int(panel.get_meta("plot"))))
	panel.add_child(collect)
	collect.position = Vector2(-11, 2)
	var ring := Ring.new()
	collect.add_child(ring)
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var timer := Ring.new()
	button.add_child(timer)
	timer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var clock := Look.button("", Look.icon("timer"), Look.DARK, Vector2(113, 43))
	clock.name = "FortConstructionTimer_%d" % plot_id
	clock.pressed.connect(func(): _select_fort_room("plot_%d" % plot_id))
	clock.position = Vector2(-22, 0)
	clock.hide()
	panel.add_child(clock)
	return {"panel": panel, "button": button, "clock": clock, "title": level, "state": alert, "collect": collect, "ring": ring, "timer": timer}


func _sync_markers() -> void:
	if diorama is FortCutaway:
		_sync_cutaway_markers()
		return
	var sig := _plot_signature()
	if sig != _plots_sig:
		_plots_sig = sig
		# Убираем ссылки на старые кнопки из счётчиков до пересоздания ряда.
		for id: int in plot_markers:
			var previous: Dictionary = plot_markers[id]
			if (previous["panel"] as Control).get_parent() == extra_row:
				counters.erase(previous["button"])
		_clear(extra_row)
		plot_markers.clear()
		var shown := {}
		for slot: String in Legion.CAMP_SLOTS:
			var plot := lg.fort_slot_plot(slot)
			if plot.is_empty():
				plot = lg.fort_slot_plot("hq")
			var id := int(plot.get("id", 0))
			var marker: Dictionary = plaques[slot]
			(marker["panel"] as Control).visible = not shown.has(id)
			(marker["panel"] as Control).set_meta("plot", id)
			(marker["button"].get_node("ic") as TextureRect).texture = hud.ico(String(FORT_ICON[String(plot["b"])]), 64)
			if not shown.has(id):
				plot_markers[id] = marker
				shown[id] = true
		for plot: Dictionary in lg.fort.get("plots", []):
			var id := int(plot["id"])
			if plot["b"] == "" or shown.has(id):
				continue
			var marker := _marker(id, String(plot["b"]))
			extra_row.add_child(marker["panel"])
			plot_markers[id] = marker
	extra_plots.visible = extra_row.get_child_count() > 0
	for slot: String in plaques:
		_refresh_marker(plaques[slot])
	for id: int in plot_markers:
		_refresh_marker(plot_markers[id])


func _refresh_marker(marker: Dictionary) -> void:
	var plot := lg.fort_plot(int((marker["panel"] as Control).get_meta("plot")))
	if plot.is_empty():
		return
	var type := String(plot["b"])
	var clock: Button = marker["clock"]
	var room_button: Button = marker["button"]
	var cutaway := diorama is FortCutaway
	room_button.visible = not cutaway or (type == "" and placement_type != "" and lg.fort_can_build(placement_type, int(plot["id"])) == "")
	clock.hide()
	if type == "":
		(marker["title"] as Control).hide()
		(marker["collect"] as Control).hide()
		(marker["state"] as Control).hide()
		(marker["timer"] as Control).hide()
		return
	var level := int(plot["lv"])
	(marker["title"] as Label).text = str(level)
	var button: Button = marker["button"]
	button.tooltip_text = I18n.t("%s · ур. %d") % [I18n.t(String(Legion.FORT_B[type]["name"])), level]
	var timer := lg.fort_plot_timer(int(plot["id"]))
	(marker["timer"] as Control).visible = not timer.is_empty()
	if not timer.is_empty():
		var left := maxf(0, float(timer["end"]) - Legion.now())
		marker["timer"].set("value", 1.0 - left / maxf(1.0, float(timer["total"])))
		button.tooltip_text += " · " + clock_text(left)
		if cutaway:
			clock.text = clock_text(left) if left >= 3600 else "%02d:%02d" % [ceili(left) / 60, ceili(left) % 60]
			clock.show()
			(marker["collect"] as Button).hide()
			return
	var prod := Legion.fort_production(type, level)
	var collect: Button = marker["collect"]
	if type in ["forge", "arsenal"]:
		collect.visible = lg.craft_ready(int(plot["id"])) > 0
		collect.icon = Kit.texture("equip")
		collect.text = "+" + str(lg.craft_ready(int(plot["id"])))
		collect.tooltip_text = I18n.t("Собрать снаряжение: %d") % lg.craft_ready(int(plot["id"]))
		collect.disabled = lg.store_count() >= lg.store_cap()
		if collect.disabled:
			collect.tooltip_text += "\n" + I18n.t("Склад полон. Продайте или наденьте лишние вещи.")
		marker["ring"].set("value", 1.0)
		if timer.is_empty():
			for job: Dictionary in lg.craft_queue(int(plot["id"])):
				if float(job["left"]) > 0.0:
					(marker["timer"] as Control).visible = true
					marker["timer"].set("value", 1.0 - float(job["left"]) / maxf(1.0, float(job["total"])))
					button.tooltip_text += " · " + clock_text(float(job["left"]) / lg.fort_work_speed(int(plot["id"]), type))
					break
	else:
		collect.visible = not prod.is_empty() and float(plot["pend"]) >= 0.9999
	var idle := false
	if not prod.is_empty():
		var resource := String(prod["resource"])
		collect.icon = Look.resource(resource)
		collect.text = "+" + str(floori(float(plot["pend"]) + 0.0001))
		collect.tooltip_text = I18n.t("Собрать %d") % floori(float(plot["pend"]) + 0.0001)
		collect.disabled = _stock(resource) >= lg.resource_cap(resource)
		if collect.disabled:
			collect.tooltip_text += "\n" + I18n.t("Запас полон. Потратьте ресурсы, чтобы собрать ещё.")
		marker["ring"].set("value", float(plot["pend"]) / maxf(1.0, float(prod["cap"])))
		if lg.fort_guide_cooking(int(plot["id"])):
			collect.show()
			collect.disabled = float(plot["pend"]) < Legion.FORT_GUIDE_BATCH - 0.0001
			collect.tooltip_text = I18n.t("Готовит пайки…") if collect.disabled else I18n.t("Собрать %d") % Legion.FORT_GUIDE_BATCH
			marker["ring"].set("value", float(plot["pend"]) / Legion.FORT_GUIDE_BATCH)
		idle = float(plot["pend"]) >= float(prod["cap"]) - 0.001
	elif type == "drill" and level > 0:
		idle = true
		for soldier: Dictionary in lg.soldiers:
			if lg.s_state(soldier) == "train" and int(soldier.get("train_plot", -1)) == int(plot["id"]):
				idle = false
	collect.set_meta("fort_full", idle and not prod.is_empty())
	var alert: Label = marker["state"]
	alert.text = "!"
	var needs_worker := type != "hq" and level > 0 and lg.fort_worker(int(plot["id"])).is_empty()
	alert.visible = (idle or needs_worker) and timer.is_empty()
	if needs_worker:
		button.tooltip_text += "\n" + I18n.t("Нет работника. Назначьте человека в карточке.")
	if alert.visible and not needs_worker:
		button.tooltip_text += "\n" + I18n.t("Можно тренировать воина." if type == "drill" else "Производство заполнено. Соберите ресурсы.")


func _collect_plot(plot_id: int, origin := Vector2.INF) -> void:
	var plot := lg.fort_plot(plot_id)
	if plot.is_empty():
		return
	if String(plot["b"]) in ["forge", "arsenal"]:
		var got := lg.craft_collect(plot_id)
		if not got.is_empty():
			_refresh()
		return
	var prod := Legion.fort_production(String(plot["b"]), int(plot["lv"]))
	if prod.is_empty():
		return
	if origin == Vector2.INF:
		origin = (plot_markers[plot_id]["collect"] as Control).global_position if plot_markers.has(plot_id) else global_position + size * 0.5
	var amount := lg.fort_collect(plot_id)
	if amount <= 0:
		return
	var resource := String(prod["resource"])
	_fly_resource(resource, amount, origin)
	_refresh()


func _room_icon(type: String, pixels: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = FortCutaway.room_icon(type)
	icon.custom_minimum_size = Vector2.ONE * pixels
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _worker_card(parent: VBoxContainer) -> void:
	if selected == "hq":
		return
	var row := HBoxContainer.new()
	row.name = "FortWorker"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var count := _text("%d / %d" % [lg.fort_occupants(selected_plot).size(), lg.fort_room_slots(selected_plot)], 19, true)
	count.name = "FortWorkerName"
	row.add_child(count)
	var occupants := lg.fort_occupants(selected_plot)
	for person: Dictionary in occupants.slice(0, 4):
		var sid := int(person["id"])
		var b := Kit.round_button(null)
		b.custom_minimum_size = Vector2(88, 88)
		b.tooltip_text = String(person["name"])
		b.pressed.connect(func(): show_dweller(sid))
		row.add_child(b)
		var face := _person_portrait(person, 76)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(face)
		face.position = Vector2(6, 6)
	if occupants.size() > 4:
		row.add_child(Look.label("+%d" % (occupants.size() - 4), 20))
	var plus := Kit.round_button("plus")
	plus.name = "FortAssignSlot"
	plus.tooltip_text = I18n.t("Назначить")
	plus.pressed.connect(show_worker_picker)
	row.add_child(plus)


func show_worker_picker() -> void:
	var target := selected_plot
	var v := _new_modal(540)
	modal_panel.name = "FortWorkerPicker"
	v.add_child(_text("Кто будет работать?", 24, true))
	var choices: Array[Dictionary] = lg.fort_worker_choices()
	if choices.is_empty():
		v.add_child(_wrap(I18n.t("Во дворе никого. Примите новобранца у ворот или переместите жителя из комнаты.")))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 250)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	for person: Dictionary in choices:
		var row := HBoxContainer.new()
		body.add_child(row)
		row.add_child(_person_portrait(person, 54))
		var sid := int(person["id"])
		var button := _button(String(person["name"]), func():
			if lg.fort_assign(target, sid):
				_close_modal()
				show_plot(target)
				_refresh())
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
	var recruit_worker := _button("У ворот форта", open_recruit_picker, "legion")
	v.add_child(recruit_worker)
	v.add_child(_button("Закрыть", _close_modal))
	_fit_modal.call_deferred()


func _sync_cutaway_markers() -> void:
	if not is_instance_valid(cutaway_markers):
		return
	for entry: Dictionary in plaques.values():
		(entry["panel"] as Control).hide()
	extra_plots.hide()
	var signature := _plot_signature()
	if signature != _plots_sig:
		_plots_sig = signature
		for entry: Dictionary in plot_markers.values():
			counters.erase(entry["button"])
		_clear(cutaway_markers)
		plot_markers.clear()
		for p: Dictionary in lg.fort["plots"]:
			var id := int(p["id"])
			var type := String(p["b"])
			var marker := _marker(id, type if type != "" else "hq")
			marker["empty"] = type == ""
			cutaway_markers.add_child(marker["panel"])
			var button: Button = marker["button"]
			button.set_meta("fort_room_hit", true)
			(marker["collect"] as Button).set_meta("fort_room_hit", true)
			button.name = "RoomButton_%d" % id
			if type == "":
				(button.get_node("ic") as TextureRect).texture = Look.icon("build")
				button.text = ""
				button.add_theme_font_size_override("font_size", 36)
				button.tooltip_text = I18n.t("Построить комнату")
			else:
				(button.get_node("ic") as TextureRect).texture = FortCutaway.room_icon(type)
			button.mouse_entered.connect(func():
				if is_instance_valid(diorama):
					diorama.highlight("plot_%d" % id))
			button.mouse_exited.connect(func():
				if is_instance_valid(diorama):
					diorama.highlight(""))
			plot_markers[id] = marker
	for marker: Dictionary in plot_markers.values():
		_refresh_marker(marker)


func _layout_cutaway_view() -> void:
	var view := diorama as FortCutaway
	var k := minf(1.0, minf(size.x / 1000.0, size.y / 720.0))
	var screen := Rect2(Vector2(0, 100), size - Vector2(0, 160))
	for id: int in plot_markers:
		var marker: Dictionary = plot_markers[id]
		var panel: Control = marker["panel"]
		var empty: bool = marker.get("empty", false)
		var rect := view.plot_footprint(id)
		var center := Vector2(rect.get_center().x, rect.position.y + rect.size.y * (0.5 if empty else 0.34))
		panel.scale = Vector2.ONE * k * 0.85
		panel.position = center - Vector2(34, 86 if empty else 20) * panel.scale
		panel.visible = rect.intersects(screen)
	_layout_expansion_marker(expand_floor, view.expansion_project("floor"), k)
	_layout_expansion_marker(expand_section, view.expansion_project("section"), k)
	# Городские буферы отделены от комнат: компактный ряд у нижней панели.
	var index := 0
	for resource: String in bubbles:
		var box: Control = bubbles[resource]["box"]
		box.position = Vector2(184 + index * 54, size.y - 67)
		index += 1
	if guide_layer.visible or guide_active():
		_layout_guide()


func _layout_expansion_marker(button: Button, point: Vector2, k: float) -> void:
	if not button.visible:
		return
	button.reset_size()
	button.scale = Vector2.ONE * k
	button.position = Vector2(clampf(point.x - button.size.x * k * 0.5, 140 * k, maxf(140 * k, size.x - button.size.x * k - 12)), clampf(point.y - button.size.y * k * 0.5, 146 * k, maxf(146 * k, size.y - 170 * k)))


func show_newcomer(sid: int) -> void:
	for person: Dictionary in lg.fort_newcomers():
		if int(person["id"]) != sid:
			continue
		var v := _new_modal(400)
		modal_panel.name = "FortNewcomerCard"
		v.add_child(Kit.ribbon(I18n.t("Новобранец")))
		var face := _person_portrait(person, 190, true)
		face.name = "FortNewcomerPortrait"
		face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(face)
		var cls := String(person.get("class_hint", "legionary"))
		var overlay := Control.new()
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Внутри рамки контейнер размещает сам рисунок.
		(face.get_node("FortPortraitArt") as TextureRect).add_child(overlay)
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var hint := Kit.image(hud.ico(String(CLASS_ICON.get(cls, "swords")), 42), Vector2(42, 42))
		hint.name = "FortNewcomerClass"
		hint.tooltip_text = I18n.t(Soldiers.class_name_of(cls))
		hint.mouse_filter = Control.MOUSE_FILTER_PASS
		overlay.add_child(hint)
		hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		hint.offset_left = -42
		hint.offset_top = -42
		hint.offset_right = 0
		hint.offset_bottom = 0
		v.add_child(_text(String(person["name"]), 24, true))
		_add_stars(v, int(person["stars"]))
		var origin := String(person.get("from", "")).strip_edges()
		if origin == "":
			origin = "Пришёл к воротам форта"
		var source := _wrap(I18n.t(origin), 16)
		source.name = "FortNewcomerOrigin"
		v.add_child(source)
		var why := lg.can_recruit_resident()
		if why != "":
			v.add_child(Kit.banner_red(I18n.t(why)))
		var row := HBoxContainer.new()
		v.add_child(row)
		var accept := Kit.button("green", "assign")
		accept.name = "FortAccept"
		accept.disabled = why != ""
		accept.tooltip_text = I18n.t("Принять") + ("\n" + I18n.t(why) if why != "" else "")
		accept.pressed.connect(func(): _recruit_pick({"id": sid}))
		row.add_child(accept)
		var release := Kit.button("red", "back")
		release.tooltip_text = I18n.t("Отпустить")
		release.pressed.connect(func(): lg.fort_release(sid); _close_modal(); _refresh())
		row.add_child(release)
		row.add_child(_button("Закрыть", _close_modal))
		_fit_modal.call_deferred()
		return


func show_people() -> void:
	var v := _new_modal(540)
	v.add_child(_text(I18n.t("Жители форта"), 24, true))
	var gate_people := _button(I18n.t("У ворот: %d") % lg.fort_newcomers().size(), open_recruit_picker, "housing")
	gate_people.name = "FortGatePeople"
	v.add_child(gate_people)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	for person: Dictionary in lg.soldiers:
		var sid := int(person["id"])
		var row := _button(_soldier_title(person), func(): _show_soldier(sid))
		row.name = "FortPerson_%d" % sid
		body.add_child(row)
	v.add_child(_button("Закрыть", _close_modal))
	_fit_modal.call_deferred()


func show_dweller(sid: int, slot := "", change := "") -> void:
	var person := lg.soldier(sid)
	if person.is_empty():
		_close_modal()
		return
	var v := _new_modal(970)
	dweller_sid = sid
	dweller_slot = slot
	dweller_change = change
	modal_panel.name = "FortDwellerCard"
	var head := HBoxContainer.new()
	v.add_child(head)
	var previous := Kit.round_button("swap")
	previous.tooltip_text = I18n.t("Предыдущий житель")
	previous.pressed.connect(func(): _dweller_next(sid, -1))
	head.add_child(previous)
	var title := Kit.ribbon(String(person["name"]))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var next := Kit.round_button("swap")
	next.tooltip_text = I18n.t("Следующий житель")
	next.pressed.connect(func(): _dweller_next(sid, 1))
	head.add_child(next)
	(previous.get_node("ic") as TextureRect).flip_h = true
	head.add_child(_button("×", _close_modal))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	v.add_child(columns)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 250
	columns.add_child(left)
	var portrait := Kit.slot(null, false, 216)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.name = "FortDwellerPortrait"
	var preview := FortPersonPreview.new()
	preview.name = "FortPortraitArt"
	portrait.add_child(preview)
	preview.setup(person, lg.worn(person), 198)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left.add_child(portrait)
	_add_stars(left, int(person["stars"]))
	left.add_child(_text(Soldiers.class_name_of(String(person["cls"])), 20, true))
	var stats := lg.soldier_stats(person, Legion.unit_of_class(String(person["cls"])))
	var stat_grid := GridContainer.new()
	stat_grid.columns = 3
	stat_grid.add_theme_constant_override("h_separation", 14)
	left.add_child(stat_grid)
	for entry: Array in [["need_services", "Здоровье", roundi(float(stats["hp"]))], ["soldier", "Атака", roundi(float(stats["atk"]))], ["equip", "Защита", roundi(float(stats["armor"]))], ["star", "Сила", Legion.power(stats)]]:
		var icon := Kit.image(String(entry[0]), Vector2(32, 32))
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		icon.tooltip_text = I18n.t(String(entry[1]))
		stat_grid.add_child(icon)
		stat_grid.add_child(_text(I18n.t(String(entry[1])), 17))
		stat_grid.add_child(_text(str(entry[2]), 23, true))
	var plot := lg.fort_plot(lg.fort_worker_plot(sid))
	var work := I18n.t(String(Legion.FORT_B[String(plot["b"])]["name"])) if not plot.is_empty() else I18n.t("Двор")
	var move := Kit.button("gold", "swap", I18n.t("Переместить"))
	move.name = "FortMoveDweller"
	move.disabled = lg.s_state(person) != "ready"
	move.tooltip_text = I18n.t("Работа: %s") % work + "\n" + I18n.t("Перетащите человека в комнату. Зелёная — можно, красная — нельзя.")
	move.pressed.connect(func(): _move_dweller(sid))
	left.add_child(move)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 610
	columns.add_child(right)
	var slots := HBoxContainer.new()
	slots.name = "FortGearSlots"
	slots.add_theme_constant_override("separation", 12)
	right.add_child(slots)
	for gear_slot: String in ["weapon", "helmet", "armor", "offhand", Gear.OUTFIT_SLOT]:
		var it := lg.item(int(person.get("gear", {}).get(gear_slot, 0)))
		var button := _gear_slot_button(104, slot == gear_slot)
		button.name = "FortGear_" + gear_slot
		button.tooltip_text = I18n.t(String(Gear.SLOT_NAME[gear_slot])).capitalize() + "\n" + (Gear.name_of(it) + "\n" + Gear.stats_text(it) if not it.is_empty() else I18n.t("Выберите вещь на складе"))
		button.pressed.connect(func(): show_dweller(sid, gear_slot))
		slots.add_child(button)
		var icon: Control = _dweller_item_icon(it, 86) if not it.is_empty() else Kit.image(hud.ico(String(LegionUi.GEAR_ICON[gear_slot]), 80), Vector2(86, 86))
		button.add_child(icon)
		icon.position = Vector2(9, 9)
	var clothes := lg.item(int(person.get("gear", {}).get(Gear.OUTFIT_SLOT, 0)))
	if not clothes.is_empty():
		var bonus := _text(Gear.name_of(clothes) + " · " + Gear.stats_text(clothes), 17)
		bonus.name = "FortOutfitBonus"
		right.add_child(bonus)
	var inventory_head := HBoxContainer.new()
	right.add_child(inventory_head)
	var inventory_title := _text(I18n.t("На складе"), 24, true)
	inventory_title.name = "FortInventoryTitle"
	var inventory_font := FontVariation.new()
	inventory_font.base_font = Kit.BOLD
	inventory_font.spacing_space = 5
	inventory_title.add_theme_font_override("font", inventory_font)
	inventory_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_head.add_child(inventory_title)
	var help := Kit.round_button("info")
	help.tooltip_text = I18n.t("Где взять?")
	help.pressed.connect(func():
		var hint := _new_modal(560)
		hint.add_child(_wrap(I18n.t("Кузница и оружейная куют вещи; сундуки за победы дают вещи"), 19))
		hint.add_child(_button("Назад", func(): show_dweller(sid, slot), "back"))
		_fit_modal.call_deferred())
	inventory_head.add_child(help)
	if slot != "":
		var filter_row := HBoxContainer.new()
		right.add_child(filter_row)
		var all_gear := _button("Все вещи", func(): show_dweller(sid), "overview")
		all_gear.name = "FortAllGear"
		filter_row.add_child(all_gear)
		var remove := _button("Снять", func():
			if lg.unequip(sid, slot):
				show_dweller(sid, slot)
				_refresh(), "back")
		remove.disabled = not (person["gear"] as Dictionary).has(slot) or lg.store_count() >= lg.store_cap()
		remove.tooltip_text = I18n.t("Склад полон. Продайте или наденьте лишние вещи.") if lg.store_count() >= lg.store_cap() else I18n.t("Снять")
		filter_row.add_child(remove)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 288)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var inventory := GridContainer.new()
	inventory.name = "FortInventoryGrid"
	inventory.columns = 6
	inventory.add_theme_constant_override("h_separation", 8)
	inventory.add_theme_constant_override("v_separation", 8)
	scroll.add_child(inventory)
	for it: Dictionary in lg.items:
		if int(it.get("on", 0)) != 0 or String(it["slot"]) not in Gear.EQUIP_SLOTS_V3 or (slot != "" and it["slot"] != slot):
			continue
		var iid := int(it["id"])
		var delta := lg.equip_power(sid, iid)
		var button := _gear_slot_button(88)
		button.name = "FortEquip_%d" % iid
		button.tooltip_text = Gear.name_of(it) + "\n" + Gear.stats_text(it)
		if it["slot"] != Gear.OUTFIT_SLOT:
			button.tooltip_text += "\n" + I18n.t("Сила: %d → %d") % [int(delta[0]), int(delta[1])] + "\n" + I18n.t("Было → стало: %d → %d") % [int(delta[0]), int(delta[1])]
		button.set_meta("power_before", int(delta[0]))
		button.set_meta("power_after", int(delta[1]))
		button.pressed.connect(func(): _equip_dweller(sid, iid))
		inventory.add_child(button)
		var icon := _dweller_item_icon(it, 70)
		button.add_child(icon)
		icon.position = Vector2(9, 6)
		if it["slot"] == Gear.OUTFIT_SLOT:
			continue
		var gain := Kit.label("%+d" % (int(delta[1]) - int(delta[0])), 15, true)
		gain.name = "PowerDelta"
		gain.add_theme_color_override("font_color", Color("83ee8e") if int(delta[1]) >= int(delta[0]) else Color("ff8b7b"))
		gain.add_theme_color_override("font_outline_color", Color("193d16") if int(delta[1]) >= int(delta[0]) else Color("58110b"))
		gain.position = Vector2(8, 62)
		button.add_child(gain)
	if inventory.get_child_count() == 0:
		var empty := Kit.slot("equip", false, 88)
		empty.tooltip_text = I18n.t("Подходящих вещей на складе нет.")
		inventory.add_child(empty)
	if change != "":
		var feedback := _text(change, 18, true)
		feedback.name = "FortEquipChange"
		right.add_child(feedback)
	_fit_modal.call_deferred()


func _gear_slot_button(pixels: float, selected_slot := false) -> Button:
	var b := Kit.button("cream")
	b.set_meta("kit_role", "slot")
	b.custom_minimum_size = Vector2.ONE * pixels
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := Kit.box("panels/slot_frame", 0, 0)
		style.modulate_color = Color(1.3, 1.15, 0.8) if selected_slot or state == "hover" else Color.WHITE
		b.add_theme_stylebox_override(state, style)
	return b


func _dweller_item_icon(it: Dictionary, pixels: float) -> Control:
	var frame := Kit.slot(null, false, pixels)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var body := Control.new()
	body.custom_minimum_size = Vector2.ONE * (pixels - 18)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(body)
	var rarity := StyleBoxFlat.new()
	rarity.bg_color = Color.TRANSPARENT
	rarity.border_color = Gear.color(int(it.get("rarity", 0)))
	rarity.set_border_width_all(3)
	rarity.set_corner_radius_all(8)
	var rim := Panel.new()
	rim.add_theme_stylebox_override("panel", rarity)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(rim)
	rim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var icon := Kit.image(lu._gear_tex(Gear.icon_of(it), String(it["slot"])), Vector2.ZERO)
	body.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var badge := Kit.label(str(Gear.tier_of(it)), 14, true)
	badge.name = "TierBadge"
	badge.position = Vector2(pixels - 36, pixels - 40)
	body.add_child(badge)
	return frame


func _equip_dweller(sid: int, iid: int) -> void:
	var delta := lg.equip_power(sid, iid)
	if lg.equip(sid, iid):
		if lg.fort_guide_step() == Legion.FortGuide.BARRACKS and sid == int(lg.flags.get("fort_guide_sid", 0)):
			_close_modal()
		else:
			var it := lg.item(iid)
			var feedback: String = "" if it.get("slot") == Gear.OUTFIT_SLOT else I18n.t("Было → стало: %d → %d") % [int(delta[0]), int(delta[1])]
			show_dweller(sid, "", feedback)
		_refresh()


func _dweller_next(sid: int, direction: int) -> void:
	var ids: Array[int] = []
	for person: Dictionary in lg.soldiers:
		if not bool(person.get("hero", false)):
			ids.append(int(person["id"]))
	if not ids.is_empty():
		show_dweller(ids[posmod(ids.find(sid) + direction, ids.size())])


func _move_dweller(sid: int) -> void:
	_close_modal()
	_hide_card()
	if diorama is FortCutaway:
		(diorama as FortCutaway).begin_person_move(sid, false, Vector2.INF, true)
	else:
		var v := _new_modal(540)
		for plot: Dictionary in lg.fort["plots"]:
			var id := int(plot["id"])
			if lg.fort_can_assign(id, sid) == "":
				var room := _button(I18n.t(String(Legion.FORT_B[String(plot["b"])]["name"])), func(): lg.fort_assign(id, sid); _close_modal(); _refresh())
				room.name = "FortMoveTo_%d" % id
				v.add_child(room)
		v.add_child(_button("Закрыть", _close_modal))
		_fit_modal.call_deferred()


func show_expansion(axis: String) -> void:
	var v := _new_modal(470)
	modal_panel.name = "FortExpansionCard"
	v.add_child(Kit.ribbon(I18n.t("+ этаж" if axis == "floor" else "+ секция")))
	v.add_child(_room_picture("hq", lg.camp_level("hq"), Vector2(400, 150)))
	var info := lg.fort_expansion_info(axis)
	v.add_child(_cost_icons(info["cost"]))
	v.add_child(Kit.time_row(duration_text(float(info["seconds"]))))
	var why := lg.fort_can_expand()
	if why != "":
		v.add_child(Kit.banner_red(I18n.t(why)))
	var row := HBoxContainer.new()
	v.add_child(row)
	var build := Kit.button("green", "build")
	build.tooltip_text = I18n.t("Строить")
	build.pressed.connect(func():
		if lg.fort_expand(axis):
			_close_modal()
			_refresh()
		else:
			show_expansion(axis))
	build.disabled = why != ""
	row.add_child(build)
	row.add_child(_button("Закрыть", _close_modal))
	_fit_modal.call_deferred()


func _instant_upgrade() -> void:
	if lg.fort_instant(selected_plot, instant_button.get_meta("quote", {})):
		_build_card()
	_refresh()


func _room_picture(type: String, level: int, dims: Vector2, building := false) -> PanelContainer:
	var frame := Kit.inset()
	var pic := Kit.image(FortCutaway.room_texture_path(type, level, building), dims)
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.clip_contents = true
	frame.add_child(pic)
	return frame


func _person_portrait(person: Dictionary, pixels: float, newcomer := false) -> PanelContainer:
	var room := "" if newcomer else String(lg.fort_plot(lg.fort_worker_plot(int(person["id"]))).get("b", ""))
	var frame := FortPerson.portrait(person, room, newcomer, pixels)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.get_child(0).name = "FortPortraitArt"
	return frame


func _add_stars(parent: Control, count: int) -> void:
	var row := HBoxContainer.new()
	row.name = "FortTalentStars"
	row.tooltip_text = I18n.t(STAR_TIP)
	parent.add_child(row)
	for i in 5:
		var star := Kit.image("star", Vector2(30, 30))
		star.modulate = Color.WHITE if i < count else Color(0.38, 0.26, 0.16, 0.45)
		row.add_child(star)


func _refresh_city_order() -> void:
	var info := lg.city_order_info()
	var left := float(info["left"])
	order_button.disabled = info["why"] != ""
	order_button.tooltip_text = I18n.t("Заказать денарии из города") + "\n" + I18n.t("%d%% казны города · %d денариев") % [int(info["percent"]), int(info["amount"])]
	order_button.tooltip_text += "\n" + (I18n.t("Следующий обоз через %s") % clock_text(left) if left > 0.0 else I18n.t("Обоз готов · раз в 5 часов"))
	if info["why"] != "" and left <= 0.0:
		order_button.tooltip_text += "\n" + I18n.t(String(info["why"]))
	order_ring.set("value", 1.0 - left / Legion.CITY_ORDER_SECONDS)


func _order_city_money() -> void:
	lg.order_city_money()
	if _popup_resource == "money":
		_close_modal()
	_refresh()


func show_smith_knowledge() -> void:
	var v := _new_modal(560)
	modal_panel.name = "FortSmithKnowledge"
	v.add_child(Kit.ribbon(I18n.t("Кузнечное знание")))
	v.add_child(_wrap("Открывает изготовление оружия и доспехов в мастерских Легиона."))
	v.add_child(_cost_icons(Legion.SMITH_KNOWLEDGE_COST))
	var why := lg.can_learn_smith()
	var learn := _button("Изучить", func(): lg.learn_smith(); _close_modal(); _refresh(), "book")
	learn.name = "FortLearnSmith"
	learn.disabled = why != ""
	learn.tooltip_text = I18n.t(why)
	v.add_child(learn)
	if why != "":
		v.add_child(Kit.banner_red(I18n.t(why)))
	v.add_child(_button("Закрыть", _close_modal))
	_fit_modal.call_deferred()
