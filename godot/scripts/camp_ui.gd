class_name CampUI
extends Control

const CityWarmup = preload("res://scripts/city_warmup.gd")
const Perf14 = preload("res://scripts/perf14_timers.gd")
## Форт V3: действия привязаны к участкам, павильоны — временный адаптер.

const Kit = preload("res://scripts/ui_kit_a.gd")
const Look = preload("res://scripts/legion_look.gd")
const MarketUI = preload("res://scripts/legion_market_ui.gd")
const FortPerson = preload("res://scripts/fort_person.gd")
const Ring = preload("res://scripts/fort_ui_ring.gd")
const KnowUI = preload("res://scripts/legion_knowledge_ui.gd")
const HqUI = preload("res://scripts/legion_hq_ui.gd")
const StoreUI = preload("res://scripts/legion_store_ui.gd")
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
var knowledge_focus := ""
var knowledge_back := Callable()
var knowledge_sig := ""
var knowledge_button: Button
var dweller_sid := 0
var dweller_slot := ""
var dweller_change := ""
const STAR_TIP := "Звёзды — талант: больше звёзд — сильнее рост характеристик"
const FORT_ICON := {"hq": "castle", "barracks": "legion", "kitchen": "bread",
	"smelter": "anvil", "sawmill": "wood", "tannery": "clothes", "store": "amphora",
	"forge": "hammer", "drill": "swords", "infirmary": "medic", "mars": "laurels",
	"stable": "horse", "tower": "castle", "treasury": "coins", "arsenal": "shield"}
const TOP_NAMES := {"money": "Денарии", "rations": "Еда", "glory": "Слава", "ingots": "Слитки",
	"iron": "Железо", "wood": "Дерево", "leather": "Кожа"}
const TOP_TIPS := {
	"money": "Денарии Легиона: Сокровищница, сундуки и обоз из города. Склад повышает потолок.",
	"rations": "Еду для походов готовит кухня.",
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
var guide_next: Button
var guide_speaker: Label
var guide_portrait: FortPersonPreview
var guide_shade: ColorRect
var guide_spotlight := Rect2()
var _guide_ack := ""
var _guide_lesson_id := ""
var hq_window_id := -1
var _guide_target: Control
var _guide_rect := Rect2()
var _guide_arrow_rect := Rect2()
var _guide_arrow_id := ""
var _guide_arrow_above := true
var _guide_arrow_blocked := 0.0
var _guide_arrow_goal := Vector2.ZERO
var _guide_arrow_from := Vector2.ZERO
var _guide_arrow_progress := 1.0
var _guide_arrow_draw_gliding := false
var _guide_arrow_glide: Tween
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
	"store": "Увеличивает запас ресурсов.",
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
var _profile_art: TextureRect
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
var recruit_page := 0
var recruit_result := false
const RESOURCE_NAME := {"iron": "Железо", "wood": "Дерево", "leather": "Кожа", "rations": "Еда"}
const RESOURCE_ICON := {"iron": "hammer", "wood": "wood", "leather": "shield", "rations": "bread"}
const RESOURCE_TIP := {
	"iron": "Железо — из Плавильни в городе. Нужно для оружия в Кузнице.",
	"wood": "Дерево — из Лесопилки в городе. Нужно для оружия и щитов в Кузнице.",
	"leather": "Кожа — из Кожевни в городе. Нужна для доспехов в Кузнице.",
	"rations": "Кухня и городские пекарни дают еду.",
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
	if not hud.game.ready_done:
		return
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


var _opening_serial := 0
var opening := false


func open() -> void:
	var started := Perf14.begin()
	_open()
	Perf14.end(Perf14.FORT_OPEN, started)


func _open() -> void:
	if not lg.v3() or not lg.window_open():
		hud.notify(lg.lock_text(), "lock")
		return
	hud._close_windows()
	hud._close_tray()
	hud._hide_info()
	hud.game.set_tool("")
	hud.advisor_panel.hide()
	lg.flags["seen"] = true
	var started := Perf14.begin()
	lg.army_tick()
	lg.begin_fort_guide()
	Perf14.detail("fort_open_rules", started)
	visible = true
	move_to_front()
	_opening_serial += 1
	opening = true
	_open_diorama(_opening_serial)
	set_process(true)
	set_process_input(true)
	started = Perf14.begin()
	_refresh()
	_layout()
	hud._update_pointer()
	Perf14.detail("fort_open_hud", started)


func close() -> void:
	_opening_serial += 1
	opening = false
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
		elif knowledge_focus != "" and knowledge_back.is_valid():
			knowledge_back.call()
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
	chips.columns = 4
	chips.name = "FortResources"
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 6)
	add_child(chips)
	for resource: String in ["rations", "money", "ingots", "iron", "wood", "leather", "glory"]:
		_resource_bar(resource)
	chips.move_child(resource_bars["glory"]["panel"], 3)
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
	chest_button = _screen_button("", "", show_storage, Look.DARK, Vector2(65, 52))
	chest_button.icon = KnowUI.art("store", "all")
	chest_button.name = "FortStorageButton"
	chest_button.tooltip_text = I18n.t("Склад")
	_badge(chest_button)
	knowledge_button = _screen_button("", "", func(): show_knowledge(String(lg.knowledge_timer().get("id", "smith"))), Look.DARK, Vector2(66, 50))
	knowledge_button.icon = KnowUI.node_icon("sets")
	knowledge_button.name = "FortKnowledgeButton"
	knowledge_button.tooltip_text = I18n.t("Знание снаряжения")
	order_button = _nav("Заказать денарии из города", "money", _order_city_money)
	order_button.name = "FortCityOrder"
	order_ring = Ring.new()
	order_ring.name = "FortCityOrderRing"
	order_button.add_child(order_ring)
	order_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	build_button = _screen_button("Строить", "build", show_build_menu)
	build_button.name = "FortBuild"
	_badge(build_button)
	market_button = _screen_button("Рынок", "market", show_market)
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
	var portrait := FortPerson.portrait(FortPerson.hero_person(lg), 74, lg.worn(lg.hero_dweller()))
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	profile_button.add_child(portrait)
	portrait.position = Vector2(3, 3)
	_profile_art = portrait.get_child(0) as TextureRect
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
	guide_layer.resized.connect(_layout_guide, Object.CONNECT_DEFERRED)
	guide_layer.hide()
	guide_shade = ColorRect.new()
	guide_shade.color = Color(0.07, 0.035, 0.026, 0.63)
	guide_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade := ShaderMaterial.new()
	shade.shader = preload("res://shaders/fort_guide_shade.gdshader")
	guide_shade.material = shade
	guide_layer.add_child(guide_shade)
	guide_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	guide = PanelContainer.new()
	guide.name = "FortGuide"
	guide.add_theme_stylebox_override("panel", Look.box(Color(0.24, 0.105, 0.08, 0.94), Color("d1a765"), 13, 0))
	guide_layer.add_child(guide)
	guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var surface := Control.new()
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide.add_child(surface)
	guide_speaker = Look.label(I18n.t("Центурион"), 23, Color("fff0cb"), true)
	guide_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide_speaker.add_theme_stylebox_override("normal", Look.box(Color("633628"), Color("d1a765"), 8, 8))
	surface.add_child(guide_speaker)
	guide_text = Look.label("", 26, Look.PAPER)
	guide_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	surface.add_child(guide_text)
	guide_skip = hud.guide_link(I18n.t("Пропустить обучение"), _skip_guide)
	guide_skip.name = "FortGuideSkip"
	guide_skip.add_theme_font_size_override("font_size", 16)
	guide_skip.add_theme_color_override("font_color", Color("f1d7a5"))
	surface.add_child(guide_skip)
	guide_next = hud.guide_link("▼", _continue_guide)
	guide_next.name = "FortGuideContinue"
	guide_next.tooltip_text = I18n.t("Продолжить")
	guide_next.add_theme_font_size_override("font_size", 21)
	guide_next.add_theme_color_override("font_color", Look.PAPER)
	surface.add_child(guide_next)
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
	var compact := resource in Gear.MATS
	var panel := Look.chip(resource, "0", _resource_pressed.bind(resource), compact)
	panel.name = "FortResource_" + resource
	panel.tooltip_text = I18n.t(String(TOP_NAMES[resource]))
	chips.add_child(panel)
	var click: Button = panel.get_meta("hit")
	click.name = "Plus_" + resource
	click.tooltip_text = panel.tooltip_text
	resource_chips[resource] = panel.get_meta("number")
	resource_bars[resource] = {"panel": panel, "plus": click}
	if resource in Legion.STOCK_RESOURCES:
		var bar := Look.meter(0, 1)
		bar.name = "FortCapacityBar"
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.custom_minimum_size.y = 5
		bar.add_theme_stylebox_override("background", Look.box(Color("55493b"), Color("55493b"), 3, 0))
		click.add_child(bar)
		bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		bar.offset_left = 8
		bar.offset_right = -8
		bar.offset_top = -7
		bar.offset_bottom = -2
		var lock := Kit.image(KnowUI.lock_icon(), Vector2(22, 22))
		lock.name = "FortCapacityLock"
		click.add_child(lock)
		lock.position = Vector2(36 if compact else 43, 3)
		resource_bars[resource]["meter"] = bar
		resource_bars[resource]["lock"] = lock


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
	chest_button.position = campaign_button.position - Vector2(0, 64 * hk)
	knowledge_button.position = Vector2(size.x - edge - knowledge_button.custom_minimum_size.x * hk, edge + 202 * hk)
	market_button.position = size - Vector2(edge + 148 * hk, edge + 60 * hk)
	build_button.position = market_button.position - Vector2(160 * hk, 0)
	placement_back.position = market_button.position
	placement_hint.reset_size()
	placement_hint.scale = Vector2.ONE * hk
	placement_hint.position = Vector2((size.x - placement_hint.size.x * hk) * 0.5, size.y - edge - 53.0 * hk)
	for button: Button in [campaign_button, build_button, market_button, population_button, builder_counter,
			builder_plus, profile_button, exit_button, quest_line, placement_back, chest_button, knowledge_button]:
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
	var guide_shown := guide_layer.is_visible_in_tree()
	if guide_shown and guide_pointer.visible:
		_place_guide_pointer(dt)
	if not visible:
		if not guide_shown:
			set_process(false)
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
	var started := Perf14.begin()
	for message in lg.tick():
		hud.game.city._quiet(message, "legion")
		if String(message).ends_with("!") or String(message) == I18n.t("Плац стал частью Казармы — стройматериалы вернулись"):
			hud.notify(message, "legion")
	Perf14.detail("fort_tick", started)
	_refresh()


static func clock_text(seconds: float) -> String:
	var t := maxi(0, ceili(seconds))
	if t >= 86400:
		return duration_text(float(t))
	return "%d:%02d:%02d" % [t / 3600, (t % 3600) / 60, t % 60]


func _roster_signature() -> String:
	var entries := []
	for s: Dictionary in lg.soldiers:
		entries.append([s["id"], s["name"], _class(s), s["stars"], s["rank"], lg.s_state(s), s.get("look"), s.get("gear")])
	return str([entries, lg.squad3, lg.camp, lg.fort.get("up", {}), lg.upg.keys(), lg.hero_level(), lg.forging.is_empty(), lg.smith_known(), _plot_signature()])


func _refresh() -> void:
	var started := Perf14.begin()
	_refresh_profiled()
	Perf14.detail("fort_refresh", started)


func _refresh_profiled() -> void:
	lg.watch_fort_lessons()
	FortPerson.bind_portrait(_profile_art, FortPerson.hero_person(lg), lg.worn(lg.hero_dweller()))
	if is_instance_valid(diorama) and not opening:
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
	for resource: String in resource_bars:
		var stock := _stock(resource)
		Look.set_chip_value(resource_chips[resource], _stock_text(resource, stock))
		if resource not in Legion.STOCK_RESOURCES:
			continue
		var entry: Dictionary = resource_bars[resource]
		var cap := lg.resource_cap(resource)
		var full := stock >= cap
		var bar: ProgressBar = entry["meter"]
		bar.max_value = cap
		bar.value = stock
		if bool(bar.get_meta("full", false)) != full or not bar.has_meta("full"):
			bar.set_meta("full", full)
			var shade := Color("e5bb5b") if full else Color("879766")
			bar.add_theme_stylebox_override("fill", Look.box(shade, shade, 3, 0))
		(entry["lock"] as Control).visible = full
		(entry["plus"] as Button).tooltip_text = I18n.t(TOP_NAMES[resource]) + " · %s / %s" % [_stock_text(resource, stock), hud.fmt(cap)]
	var know := lg.knowledge_timer()
	knowledge_button.text = "" if know.is_empty() else clock_text(float(know["end"]) - Legion.now())
	knowledge_button.custom_minimum_size.x = 66 if know.is_empty() else 150
	knowledge_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if know.is_empty() else HORIZONTAL_ALIGNMENT_LEFT

	KnowUI.refresh(self)
	HqUI.refresh(self)
	MarketUI.refresh(self)


	_count(squad_button, lg.fort_squad_candidates().size())
	_count(chest_button, lg.store_count())
	chest_button.tooltip_text = I18n.t("Вещи %d/%d") % [lg.store_count(), lg.store_cap()]
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
	var sig := _roster_signature()
	if selected_plot >= 0 and is_instance_valid(card):
		if sig != _card_sig:
			_build_card()
		_refresh_card()
	if is_instance_valid(squad_body) and sig != _squad_sig:
		_build_squad()
	for resource: String in stock_labels:
		var label: Label = stock_labels[resource]
		label.text = "%s / %s" % [hud.fmt(lg.mat(resource)), hud.fmt(lg.resource_cap(resource))]
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
	if id == 0 and lg.fort_guide_step() == Legion.FortGuide.HQ:
		show_hq_upgrade(id)
		return
	if _show_lesson_room(id):
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
	for button: Control in [quest_line, campaign_button, market_button, build_button, exit_button, chest_button, knowledge_button]:
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
		if not lg.fort_cancel_quote(id).is_empty():
			_room_action("Отменить", "", _show_cancel_construction.bind(id)).name = "FortCancelBuild"
		_room_action("Ускорить", "build", _show_speed_up.bind(id), Look.WINE).name = "FortSpeedUp"
	else:
		if type == "hq":
			_room_action("Улучшить", "build", show_hq_upgrade.bind(id), Look.WINE)
		else:
			_room_action("Улучшить", "build", show_plot.bind(id), Look.WINE)
		var quick := String({"barracks": "Назначить", "forge": "Ковать", "arsenal": "Изготовить", "infirmary": "Лечить"}.get(type, "Назначить"))
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
	confirm.icon = Look.resource("ingots")
	confirm.text = I18n.t("Ускорить") + " · " + hud.fmt(quote["price"])
	confirm.disabled = String(quote["why"]) != ""
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
	var action := I18n.t({"hq": "Отряд", "barracks": "Тренировка"}.get(plot["b"], "Назначение"))
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
	if selected == "store":
		lg.finish_fort_lesson("store")
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
	var area := size
	Kit.fit_modal(card, area, Vector2(900, 0))
	if selected == "hq" and is_instance_valid(upgrade_button) and lg.fort_lesson() == "hq":
		var guide_space := 170.0 * minf(1.0, size.y / 840.0)
		if card.position.y + card.size.y * card.scale.y + _sheet_offset > size.y - guide_space:
			area.y -= guide_space
			Kit.fit_modal(card, area, Vector2(900, 0))
	card.position.y = minf(card.position.y + _sheet_offset, area.y - card.size.y * card.scale.y - 24.0)
	_layout_guide.call_deferred()


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
	var shown_level := level if selected == "hq" and not (lg.fort["up"] as Dictionary).is_empty() else int(timer.get("to", level))
	var title := Look.label(I18n.t("%s · уровень %d") % [room_name, shown_level], 48, Look.INK, true)
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
		_barracks_status(stats, level)
	elif selected == "store":
		var caps := GridContainer.new()
		caps.name = "FortStoreCaps"
		caps.columns = 2
		caps.add_theme_constant_override("h_separation", 18)
		caps.add_theme_constant_override("v_separation", 3)
		stats.add_child(caps)
		for resource: String in Legion.STOCK_RESOURCES:
			_cap_row(caps, Look.resource(resource), lg.resource_cap(resource), lg.resource_cap(resource, 1), TOP_NAMES[resource])
		_cap_row(caps, KnowUI.art("store", "all"), lg.store_cap(), lg.store_cap_after(1), "Снаряжение")
	elif selected == "hq":
		_room_metric(stats, I18n.t("Уровень форта"), FortCutaway.room_icon(selected), level, level + 1)

	else:
		_room_metric(stats, I18n.t("Места в комнате"), FortCutaway.room_icon(selected),
			Legion.fort_room_slots_at(selected, level), Legion.fort_room_slots_at(selected, level + 1))
	_worker_card(card_body)
	if selected in ["forge", "arsenal"] and not lg.smith_known():
		var lock := Look.label(I18n.t(Legion.SMITH_LOCK), 18, Look.WINE)
		lock.name = "FortSmithLock"
		card_body.add_child(lock)
	if selected in ["forge", "arsenal"]:
		var id := selected_plot
		var knowledge := Look.button(I18n.t("Знание снаряжения"), KnowUI.node_icon("sets"), Look.INSET, Vector2(132, 46))
		knowledge.name = "FortRoomKnowledge"
		knowledge.pressed.connect(func():
			var focus := "smith" if selected == "forge" else "armor1"
			if selected == "forge" and lg.fort_lesson() == "knowledge" and not lg.smith_known():
				focus = "bows"
			show_knowledge(focus, show_plot.bind(id)))
		card_body.add_child(knowledge)
	main_action = Look.button("", null, Look.INSET, Vector2(132, 46))
	main_action.name = "FortMainAction"
	main_action.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	main_action.pressed.connect(_main_action)
	card_body.add_child(main_action)
	if selected == "hq":
		var info_row := _expansion_cost_row(lg.fort_expansion_info())
		info_row.name = "FortExpansionCost"
		card_body.add_child(info_row)
		var expansion_reason := Look.label("", 20, Look.WINE)
		expansion_reason.name = "FortExpansionReason"
		expansion_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		expansion_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_body.add_child(expansion_reason)
	elif selected == "barracks":
		recruit_button = main_action

	requirement_banner = Look.panel(Look.INSET, 9)
	requirement_banner.name = "FortRequirementBanner"
	var requirement := HBoxContainer.new()
	requirement_banner.add_child(requirement)
	var lock_icon := Kit.image(Look.icon("lock"), Vector2(34, 34))
	lock_icon.name = "RequirementIcon"
	requirement.add_child(lock_icon)
	upgrade_reason = Look.label("", 23, Look.WINE)
	upgrade_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	upgrade_reason.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	requirement.add_child(upgrade_reason)
	card_body.add_child(requirement_banner)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	card_body.add_child(actions)

	instant_button = Look.button(I18n.t("Мгновенно"), Look.resource("ingots"), Look.PAPER, Vector2(215, 64))
	instant_button.name = "FortInstant"
	instant_button.visible = selected != "hq"
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
	if selected == "hq":
		upgrade_button.text = I18n.t("Улучшить")
		upgrade_button.icon = Look.icon("build")
	upgrade_button.name = "FortUpgrade"
	upgrade_button.pressed.connect(_upgrade)
	timed.add_child(upgrade_button)
	var extra_cost: Dictionary = (info["next_cost"] as Dictionary).duplicate()
	extra_cost.erase("money")
	upgrade_cost = _cost_icons(extra_cost)
	(upgrade_cost as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	timed.add_child(upgrade_cost)


func _cap_row(parent: Control, texture: Texture2D, current: int, next: int, title: String) -> void:
	var row := HBoxContainer.new()
	row.tooltip_text = I18n.t(title)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(Kit.image(texture, Vector2(30, 30)))
	row.add_child(Look.label("%s → %s" % [hud.fmt(current), hud.fmt(next)], 22))
	parent.add_child(row)


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
	var values := Look.label("%s → %s" % [hud.fmt(now_value), hud.fmt(next_value)], 22)
	values.name = "FortRoomMetricValues"
	heading.add_child(values)
	var gain := Look.label("", 21, Look.OLIVE)
	gain.name = "FortRoomMetricGain"
	gain.custom_minimum_size.x = 52
	gain.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if next_value > now_value:
		gain.text = "+" + hud.fmt(next_value - now_value)
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
	for timer_label: Node in card_body.find_children("FortTrainingTimer*", "Label", true, false):
		var person := lg.soldier(int(timer_label.get_meta("sid")))
		var info := lg.training_info(person, plot)
		var training := lg.s_state(person) == "train"
		var status := "" if training else I18n.t(lg._training_reason(person, plot))
		(timer_label as Label).text = status if status != "" else duration_text(lg.s_left(person) if training else float(info["time"]))
		var timer_icon := timer_label.get_parent().get_node_or_null("FortTrainingClock") as TextureRect
		if timer_icon != null:
			timer_icon.visible = status == ""
	var why := lg.fort_can_upgrade(selected_plot)
	upgrade_button.disabled = selected != "hq" and why != ""
	upgrade_button.tooltip_text = I18n.t("Улучшить") + ("\n" + I18n.t(why) if why != "" else "")
	upgrade_reason.text = I18n.t("Нужен Штаб ур. %d") % (int(plot["lv"]) + 1) if why.begins_with("Выше Штаба") else I18n.t(why)
	requirement_banner.visible = why != ""
	var prod := lg.fort_plot_production(int(plot["id"]), selected, maxi(1, int(plot["lv"])))
	var title := ""
	var reason := ""
	if not prod.is_empty():
		var amount := floori(float(plot["pend"]) + 0.0001)
		title = I18n.t("Собрать %s") % hud.fmt(amount) if amount > 0 else I18n.t("Собрать")
		if amount == 0:
			reason = I18n.t("Ресурсы ещё готовятся.")
		elif _stock(String(prod["resource"])) >= lg.resource_cap(String(prod["resource"])):
			reason = I18n.t("Запас полон. Потратьте ресурсы, чтобы собрать ещё.")
	else:
		match selected:
			"barracks":
				title = I18n.t("Назначить")
			"forge": title = I18n.t("Ковать")
			"drill": title = I18n.t("Тренировать")
			"mars": title = I18n.t("Таланты")
			"store": title = I18n.t("Склад")
			"infirmary": title = I18n.t("Лечить")
			"arsenal": title = I18n.t("Изготовить")
			"hq":
				title = I18n.t("Расширить форт")
				reason = _expansion_reason(lg.fort_expansion_info())
				var expansion_reason := card_body.get_node("FortExpansionReason") as Label
				expansion_reason.text = reason
				expansion_reason.visible = reason != ""
			_: title = I18n.t("Отряд")
	if selected not in ["hq", "store"] and lg.fort_worker(selected_plot).is_empty() and not running:
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
		action_icon = String({"forge": "craft", "arsenal": "craft", "drill": "soldier", "barracks": "squad", "store": "chest", "mars": "star", "infirmary": "need_services"}.get(selected, "squad"))
	main_action.icon = Look.resource(String(prod["resource"])) if not prod.is_empty() and action_icon == "collect" else Look.icon(action_icon)
	if selected == "hq":
		main_action.icon = FortCutaway.room_icon("hq")
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
	var started := Perf14.begin()
	_upgrade_room()
	Perf14.detail("fort_upgrade", started)


func _upgrade_room() -> void:
	var id := selected_plot
	if selected == "hq":
		show_hq_upgrade(id)
		return
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
	return "%s · %s" % [String(s["name"]), Soldiers.stars_text(int(s["stars"]))]


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
		row.add_child(_person_portrait(s, 40))
		var b := _button(_soldier_title(s), func(): _show_soldier(sid))
		b.add_theme_font_size_override("font_size", 14)
		b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = Soldiers.class_name_of(_class(s))
		row.add_child(b)
		if training:
			var status := _wrap(lu._soldier_status(s), 13)
			v.add_child(status)
			var bar := lu._bar(0, lg.train_progress(s))
			v.add_child(bar)
			var rank := int(s["rank"])
			var train_button := _button(I18n.t("Тренировать · %s") % hud.fmt(50 * (rank + 1)), func(): lg.train(sid); _refresh(), "bread")
			v.add_child(train_button)
			_training.append({"id": sid, "status": status, "bar": bar, "button": train_button})
		elif not bool(s.get("hero", false)):
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
			if knowledge_focus != "" and knowledge_back.is_valid():
				knowledge_back.call()
			else:
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


func _new_framed_modal(width: float) -> VBoxContainer:
	var body := _new_modal(width)
	Look.bronze_frame(modal_panel as UiKitA.CardPanel)
	return body


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
	hq_window_id = -1
	knowledge_focus = ""
	knowledge_back = Callable()
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
	modal_panel = null
	squad_body = null
	selected_place = -1
	_layout_guide.call_deferred()


func show_squad(place := -1) -> void:
	squad_body = _new_modal(640)
	modal_panel.name = "FortSquad"
	selected_place = place
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
	squad_body.add_child(_wrap("Выберите место, затем бойца Штаба.", 14))
	for row_index in 2:
		squad_body.add_child(_text("Передний ряд" if row_index == 0 else "Задний ряд", 14, true))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		squad_body.add_child(row)
		for i in range(0 if row_index == 0 else 3, 3 if row_index == 0 else 5):
			var soldier := lg.soldier(int(lg.squad3[i]))
			var unlock := lg.fort_place_unlock_level(i)
			var label := I18n.t("Выбрано" if i == selected_place else "Пустое место")
			var icon := "shield"
			if unlock > 0:
				label = I18n.t("Штаб %s") % Legion.roman(unlock)
				icon = "lock"
			elif not soldier.is_empty():
				label = String(soldier["name"]) + "\n" + Soldiers.stars_text(int(soldier["stars"]))
				icon = ""
			var b := _button(label, func(): _pick_place(i), icon)
			b.name = "FortSquadPlace_%d" % i
			b.disabled = unlock > 0
			b.set_meta("quest_slot", i)
			b.custom_minimum_size = Vector2(188, 72)
			b.add_theme_font_size_override("font_size", 16)
			if bool(soldier.get("hero", false)):
				b.add_theme_color_override("font_color", Color("85632e"))
			b.tooltip_text = label
			if i == selected_place:
				Kit.style_button(b, "gold")
			row.add_child(b)
			if unlock == 0 and not soldier.is_empty():
				b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
				b.clip_text = true
				var face := _person_portrait(soldier, 48)
				b.add_child(face)
				face.position = Vector2(5, 12)
	squad_body.add_child(_wrap(I18n.t("Отряд %d/%d") % [lg.squad_count(), lg.slots()], 14))
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
		soldier_row.add_child(_person_portrait(s, 40))
		var b := _button(_soldier_title(s), func(): _assign(sid))
		b.set_meta("quest_soldier", sid)
		b.disabled = selected_place < 0
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
	# Собранное число поднимается к своей плашке.
	var target: Control = resource_chips[resource] if resource_chips.has(resource) else plaques["store"]["panel"]
	var tween := create_tween().set_parallel(true)
	_collection_fx = _collection_fx.filter(func(entry: Dictionary): return is_instance_valid(entry["label"]))
	_collection_fx.append({"tween": tween, "label": fly})
	tween.tween_property(fly, "global_position", target.global_position, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(fly, "modulate:a", 0.0, 0.25).set_delay(0.45)
	tween.chain().tween_callback(fly.queue_free)


func show_hero() -> void:
	show_dweller(int(lg.hero_dweller().get("id", 0)))





func show_market(daily := false) -> void:
	_clear_room_selection()
	lg.finish_fort_lesson("market")
	MarketUI.open(self, daily)


func show_storage(tab := "all", page := 0, chest := "", reward: Dictionary = {}) -> void:
	StoreUI.store(self, tab, page, chest, reward)


func show_chests(reward: Dictionary = {}) -> void:
	show_storage("chest", 0, "", reward)

func _show_soldier(sid: int) -> void:
	show_dweller(sid)


func _open_diorama(serial: int) -> void:
	var tree := get_tree()
	_cover_city()
	var art := {}
	if USE_3D and use_cutaway and not is_instance_valid(diorama) and DisplayServer.get_name() != "headless":
		await tree.process_frame
		if serial != _opening_serial or not visible:
			return
		var paths := FortCutaway.opening_art(lg)
		if ResourceLoader.exists(FortCutaway.ART + "fort/shell_front.png"):
			art = await CityWarmup.fetch(tree, paths)
	if serial != _opening_serial or not visible:
		return
	var started := Perf14.begin()
	_start_diorama()
	Perf14.end(Perf14.CAMP_BUILD, started)
	if diorama is FortCutaway:
		var cutaway := diorama as FortCutaway
		for path: String in art:
			if art[path] is Texture2D:
				cutaway.remember_art(path, art[path])
		await tree.process_frame
		if serial != _opening_serial or not visible:
			return
		await cutaway.prepare_opening()
		if serial != _opening_serial or not visible:
			return
		await tree.process_frame
		if serial != _opening_serial or not visible:
			return
		cutaway.show()
		background.hide()
	started = Perf14.begin()
	_refresh()
	_layout()
	opening = false
	Perf14.end(Perf14.CAMP_BUILD, started)
	art.clear()
	if DisplayServer.get_name() != "headless":
		lu.warm_fort_map.call_deferred()


func _cover_city() -> void:
	if not _city_render_owned:
		_previous_disable_3d = get_viewport().disable_3d
		_city_render_owned = true
		hud.game.legion_cover(self, true)
		get_viewport().disable_3d = true


func _start_diorama() -> void:
	if not USE_3D or not lg.v3() or is_instance_valid(diorama):
		return
	var scene: Camp3D = FortCutaway.new() if use_cutaway else Camp3D.new()
	if scene is FortCutaway:
		(scene as FortCutaway).defer_initial_sync = true
		scene.hide()
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
		(diorama as FortCutaway).person_moved.connect(func(sid: int, id: int):
			if sid == int(lg.flags.get("fort_guide_sid", 0)) and id == int(lg.flags.get("fort_guide_plot", -1)) and lg.flags.has("fort_guide_item"):
				hud.notify(I18n.t("Новый наряд!"), "equip")
			_refresh())
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
	if not (diorama is FortCutaway):
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
		if is_instance_valid(hud.game):
			hud.game.legion_cover(self, false)
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
	return (step > Legion.FortGuide.INACTIVE and step < Legion.FortGuide.DONE) or lg.fort_lesson() != ""


func _skip_guide() -> void:
	var step := lg.fort_guide_step()
	if step == Legion.FortGuide.DONE:
		lg.finish_fort_lesson(lg.fort_lesson(), true)
	else:
		if step != Legion.FortGuide.FINISH:
			lg.flags["fort_lessons_off"] = true
		lg.finish_fort_guide()
	_guide_ack = ""
	_layout_guide()
	if visible:
		_refresh()
	elif lu.visible:
		lu._dirty = true


func _continue_guide() -> void:
	if lg.fort_guide_step() == Legion.FortGuide.FINISH:
		_skip_guide()
		return
	_guide_ack = guide_text.text
	_layout_guide()


func _guide_person(sid: int, newcomer := false) -> Rect2:
	if diorama is FortCutaway:
		var cutaway := diorama as FortCutaway
		var hit := cutaway.person_hit_rect(sid, newcomer)
		if hit.has_area() and Rect2(Vector2.ZERO, cutaway.size).has_point(hit.get_center()):
			return Rect2(cutaway.global_position + hit.position, hit.size)
	_guide_target = population_button
	return Rect2()


func _guide_room(type: String) -> Control:
	var id := int(lg.fort_slot_plot(type).get("id", -1))
	var marker: Dictionary = plot_markers.get(id, {})
	if not lg.fort_plot_timer(id).is_empty():
		return marker.get("clock") as Control
	return marker.get("panel") as Control


func _guide_modal_target(target_name: String) -> Control:
	return modal_panel.find_child(target_name, true, false) as Control if is_instance_valid(modal_panel) else null


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
	_guide_arrow_rect = Rect2()
	if not guide_active():
		guide_layer.hide()
		return
	_guide_lesson_id = lg.fort_lesson()
	var tip := _guide_lesson_tip(_guide_lesson_id) if _guide_lesson_id != "" else _guide_first_tip()
	if _guide_lesson_id in ["store", "hq"] and (is_instance_valid(modal) and not is_instance_valid(build_scroll) or is_instance_valid(card) and selected != _lesson_room(_guide_lesson_id)):
		tip = ""
	var area := guide_layer.size
	if area.x <= 0.0 or area.y <= 0.0:
		guide_layer.hide()
		return
	var bounds := Rect2(guide_layer.global_position, area)
	if is_instance_valid(_guide_target) and _guide_target.is_visible_in_tree():
		_guide_rect = _guide_target.get_global_rect()
		_guide_arrow_rect = _guide_rect
		if _guide_target == lu.guide_stage_button and is_instance_valid(lu.fort_map):
			_guide_rect = _guide_rect.intersection(lu.fort_map.get_global_rect())
		var parent := _guide_target.get_parent()
		while parent is Control:
			if parent.clip_contents:
				_guide_rect = _guide_rect.intersection((parent as Control).get_global_rect())
			parent = parent.get_parent()
	if not _guide_arrow_rect.has_area():
		_guide_arrow_rect = _guide_rect
	_guide_rect = _guide_rect.intersection(bounds)
	if tip == "" or (not _guide_arrow_rect.has_area() and _guide_lesson_id == ""):
		guide_layer.hide()
		return
	_draw_guide(tip, area)


func _guide_first_tip() -> String:
	var step := lg.fort_guide_step()
	var sid := int(lg.flags.get("fort_guide_sid", 0))
	var combat := lg.fort_guide_combat()
	if lu.visible:
		if lu.camp_window != "" or not combat:
			return ""
		_guide_target = lu._fight_btn if lu.fort_prep_open else lu.guide_stage_button
		if not is_instance_valid(_guide_target):
			_guide_target = lu.guide_region_button
		return "Разбойники держат пленных у дороги. Освободим их!" if step == Legion.FortGuide.FIRST_BATTLE else "Отряд готов! Идём в бой."
	if not visible:
		return ""
	match step:
		Legion.FortGuide.FIRST_BATTLE, Legion.FortGuide.SECOND_BATTLE:
			_guide_target = campaign_button
			return "Разбойники держат пленных у дороги. Освободим их!" if step == Legion.FortGuide.FIRST_BATTLE else "Отряд готов! Идём в бой."
		Legion.FortGuide.TREASURY, Legion.FortGuide.KITCHEN:
			var type := "treasury" if step == Legion.FortGuide.TREASURY else "kitchen"
			var room := lg.fort_slot_plot(type)
			if sid == 0 or lg.fort_worker_plot(sid) != int(room.get("id", -1)):
				_guide_recruit_target(type)
				return "Поставьте жителя в Сокровищницу." if type == "treasury" else "Поставьте жителя на кухню."
			if lg.fort_guide_collect_ready(int(room["id"])) and not is_instance_valid(modal_panel):
				_guide_target = plot_markers.get(int(room["id"]), {}).get("collect") as Control
				return "Соберите денарии." if type == "treasury" else "Соберите еду."
			if dweller_sid == sid and is_instance_valid(modal_panel):
				var iid := int(lg.flags.get("fort_guide_item", 0))
				_guide_target = _guide_modal_target("FortItemEquip")
				if _guide_target == null and dweller_slot == Gear.OUTFIT_SLOT:
					_guide_target = _guide_modal_target("FortEquip_%d" % iid)
				if _guide_target == null:
					_guide_target = _guide_modal_target("FortGear_outfit")
				return "Наденьте рабочую одежду."
			_guide_rect = _guide_person(sid)
			return "Новый наряд! Откройте карточку жителя."
		Legion.FortGuide.HQ:
			_guide_target = _guide_modal_target("FortHQConfirm") if hq_window_id == 0 else _guide_room("hq")
			return "Улучшите Штаб бесплатно."
		Legion.FortGuide.STORE:
			if placement_type == "store":
				_guide_target = plot_markers.get(lg.fort_empty_plot(), {}).get("button") as Control
			elif is_instance_valid(build_scroll):
				_guide_target = build_cards.get("store", {}).get("button") as Control
			else:
				_guide_target = build_button
			return "Постройте Склад бесплатно."
		Legion.FortGuide.TRAIN:
			if sid != 0 and lg.s_state(lg.soldier(sid)) == "train":
				_guide_rect = _guide_person(sid)
				return "Житель тренируется."
			_guide_recruit_target("barracks")
			return "Перетащите жителя в Казарму."
		Legion.FortGuide.SQUAD:
			_guide_move_target(sid, "hq")
			return "Перетащите бойца в Штаб."
		Legion.FortGuide.FINISH:
			_guide_target = campaign_button
			return "Дальше — сами. Удачи, командир!"
	return ""


func _guide_recruit_target(type: String) -> void:
	var arrivals := lg.fort_newcomers()
	var view := diorama as FortCutaway
	if view != null and view.drag_sid != 0:
		var room := view.plot_footprint(int(lg.fort_slot_plot(type).get("id", -1)))
		_guide_rect = Rect2(view.global_position + room.position, room.size)
	elif is_instance_valid(modal_panel):
		_guide_target = _guide_modal_target("FortAccept")
		if _guide_target == null and not arrivals.is_empty():
			_guide_target = _guide_modal_target("FortGate_%d" % int(arrivals[0]["id"]))
		if _guide_target == null and dweller_sid > 0:
			_guide_target = _guide_modal_target("FortMoveDweller")
	elif not arrivals.is_empty():
		_guide_rect = _guide_person(int(arrivals[0]["id"]), true)
	else:
		var yard := lg.fort_worker_choices()
		if not yard.is_empty():
			_guide_move_target(int(yard[0]["id"]), type)


func _show_lesson_room(id: int) -> bool:
	var type := String(lg.fort_plot(id).get("b", ""))
	if type == "" or type != _lesson_room(lg.fort_lesson()) or not lg.fort_plot_timer(id).is_empty():
		return false
	show_plot(id)
	return true


func _lesson_room(lesson: String) -> String:
	return String({"store": "store", "knowledge": "forge", "hq": "hq"}.get(lesson, ""))


func _guide_lesson_room(type: String) -> void:
	var id := int(lg.fort_slot_plot(type).get("id", -1))
	if id < 0:
		if placement_type == type:
			_guide_target = plot_markers.get(lg.fort_empty_plot(), {}).get("button") as Control
		elif is_instance_valid(build_scroll):
			_guide_target = build_cards.get(type, {}).get("button") as Control
			if is_instance_valid(_guide_target) and not _guide_target.is_visible_in_tree():
				_guide_target = _guide_modal_target("FortBuildTab_2")
		elif not is_instance_valid(modal) and not is_instance_valid(card):
			_guide_target = build_button
	elif not is_instance_valid(modal) and not is_instance_valid(card):
		if diorama is FortCutaway and lg.fort_plot_timer(id).is_empty():
			var view := diorama as FortCutaway
			var footprint := view.plot_footprint(id).intersection(Rect2(Vector2.ZERO, view.size))
			_guide_rect = Rect2(view.global_position + footprint.position, footprint.size)
		else:
			_guide_target = _guide_room(type)


func _guide_lesson_tip(id: String) -> String:
	if not visible:
		return ""
	if lu.visible:
		if id != "knowledge" or lu.camp_window != "craft" or not is_instance_valid(lu.overlay):
			return ""
		if lg.craft_tier_max(lu._craft_plot) < 1:
			_guide_target = lu.overlay.find_child("CampModalBack", true, false) as Control
			return "Улучшите Кузницу для ковки."
		var recipe := lu.overlay.find_child("CraftKind_sword", true, false) as Control
		_guide_target = recipe
		if lu._craft_kind == "sword" and bool(lg.flags.get("fort_lesson_recipe", false)):
			if lu._craft_tier == 1:
				_guide_target = lu.overlay.find_child("CraftStart", true, false) as Control
				return "Начните ковку меча."
			_guide_target = lu.overlay.find_child("CraftTier_1", true, false) as Control
		return "Выберите меч первого уровня."
	match id:
		"store":
			_guide_lesson_room("store")
			return "Склад полон — производство стоит. Улучшите Склад."
		"knowledge":
			return _guide_knowledge_tip()
		"outfit":
			var target := lg.fort_outfit_lesson_target(dweller_sid)
			if target.x == 0:
				target = lg.fort_outfit_lesson_target()
			if dweller_sid > 0 and target.x == dweller_sid:
				_guide_target = _guide_modal_target("FortGear_outfit")
				if dweller_slot == Gear.OUTFIT_SLOT:
					_guide_target = _guide_modal_target("FortEquip_%d" % target.y)
				return "Наденьте рабочую одежду."
			if is_instance_valid(modal_panel):
				_guide_target = _guide_modal_target("FortPerson_%d" % target.x)
				if _guide_target == null:
					return ""
			elif not is_instance_valid(card):
				if target.x != 0:
					_guide_rect = _guide_person(target.x)
				else:
					return "Назначьте работника для новой одежды."
			return "Откройте карточку работника."
		"market":
			if is_instance_valid(modal_panel):
				return ""
			_guide_target = market_button
			return "На рынке можно пополнить запасы или продать лишнее."
		"hq":
			if is_instance_valid(card) and selected == "hq":
				_guide_target = upgrade_button
				return "Нажмите «Улучшить» и посмотрите, что откроется."
			_guide_lesson_room("hq")
			return "Можно улучшить Штаб. Откройте его."
	return ""


func _guide_knowledge_tip() -> String:
	var forge := lg.fort_slot_plot("forge")
	if knowledge_focus != "":
		if lg.smith_known():
			_guide_target = _guide_modal_target("FortKnowledgeBack")
			return "Вернитесь в кузницу."
		_guide_target = _guide_modal_target("KnowNode_smith")
		if knowledge_focus == "smith":
			_guide_target = _guide_modal_target("FortLearnSmith")
		return "Изучите кузнечное знание."
	if is_instance_valid(modal_panel) and modal_panel.name == "FortWorkerPicker":
		var choices := lg.fort_worker_choices()
		_guide_target = _guide_modal_target("FortWorkerRecruit" if choices.is_empty() else "FortWorkerChoice_%d" % int(choices[0]["id"]))
		return "Назначьте кузнеца."
	if is_instance_valid(modal) and not is_instance_valid(build_scroll) or is_instance_valid(card) and selected != "forge":
		return ""
	var forge_id := int(forge.get("id", -1))
	var renovating := not lg.fort_plot_timer(forge_id).is_empty()
	if is_instance_valid(card) and not renovating:
		if not lg.smith_known():
			_guide_target = card.find_child("FortRoomKnowledge", true, false) as Control
			return "Откройте знания в кузнице."
		if lg.craft_tier_max(selected_plot) < 1:
			_guide_target = upgrade_button
			return "Улучшите Кузницу для ковки."
		_guide_target = main_action
		return "Назначьте кузнеца." if lg.fort_worker(selected_plot).is_empty() else "Откройте рецепты кузницы."
	if renovating:
		_guide_target = _guide_room("forge") if not is_instance_valid(card) else null
		return "Кузница улучшается. Подождите."
	_guide_lesson_room("forge")
	return "Постройте кузницу." if forge.is_empty() else "Откройте кузницу."


func _draw_guide(tip: String, area: Vector2) -> void:
	var translated := I18n.t(tip)
	if guide_text.text != translated:
		_guide_ack = ""
	var k := minf(1.0, area.y / 840.0)
	var dims := Vector2(minf(1100.0, area.x * 0.78 / k), 130.0)
	guide.scale = Vector2.ONE * k
	guide.size = dims
	guide.position = Vector2((area.x - dims.x * k) * 0.5, area.y - (dims.y + 22.0) * k)
	guide_speaker.reset_size()
	guide_speaker.position = Vector2(174, -21)
	guide_text.position = Vector2(174, 25)
	# Текст — только после ширины (иначе перенос по старой ширине раздувает высоту метки), затем размер ещё раз.
	guide_text.size = Vector2(dims.x - 212, 65)
	guide_text.text = translated
	guide_text.size = Vector2(dims.x - 212, 65)
	var finish := lg.fort_guide_step() == Legion.FortGuide.FINISH
	var read := _guide_ack == translated
	guide_skip.text = I18n.t("Понятно" if finish else "Пропустить урок")
	guide_skip.reset_size()
	guide_skip.position = Vector2(174, dims.y - guide_skip.size.y - 11)
	guide_next.reset_size()
	guide_next.position = dims - guide_next.size - Vector2(27, 10)

	if read:
		dims.y = 48.0
		guide.size = dims
		guide.position.y = area.y - (dims.y + 22.0) * k
		guide_speaker.position = Vector2(13, (dims.y - guide_speaker.size.y) * 0.5)
		guide_skip.position = Vector2(dims.x - guide_skip.size.x - 22, (dims.y - guide_skip.size.y) * 0.5)
	var rect := Rect2(_guide_rect.position - guide_layer.global_position, _guide_rect.size)
	var has_target := rect.has_area()
	guide_pointer.scale = Vector2.ONE * k
	if has_target:
		var arrow_size := guide_pointer.size * k
		var above := _guide_arrow_above
		# Полоса не перекрывает подсвеченную кнопку.
		var strip := Rect2(guide.position, dims * k)
		if strip.intersects(rect.grow(6)):
			var left := rect.position.x - strip.size.x - 12.0
			var right := rect.end.x + 12.0
			if left >= 12.0:
				guide.position.x = left
			elif right + strip.size.x <= area.x - 12.0:
				guide.position.x = right
			else:
				guide.position.y = maxf(30.0 * k, rect.position.y - (dims.y + 18.0) * k - (arrow_size.y if above else 0.0))
	guide_spotlight = rect.grow(5).intersection(Rect2(Vector2.ZERO, area)) if has_target else Rect2()
	var corner := guide_spotlight.position / area
	var end := guide_spotlight.end / area
	(guide_shade.material as ShaderMaterial).set_shader_parameter("spotlight", Vector4(corner.x, corner.y, end.x, end.y))
	if _guide_arrow_rect.has_area():
		_place_guide_pointer(0.0)
		guide_pointer.show()
	else:
		guide_pointer.hide()
	guide_layer.move_to_front()
	guide_layer.show()
	# Карта похода закрывает сам форт, стрелка продолжает двигаться поверх карты.
	set_process(true)
	guide.show()
	guide_shade.visible = has_target and not read
	guide_text.visible = not read
	guide_next.visible = not read
	if not is_instance_valid(guide_portrait):
		guide_portrait = FortPersonPreview.new()
		guide_portrait.name = "FortGuidePortrait"
		var surface := guide.get_child(0) as Control
		surface.add_child(guide_portrait)
		surface.move_child(guide_portrait, 0)
		guide_portrait.setup({"id": 1, "centurion": true}, [], 150, false, 0.10)
		guide_portrait.position = Vector2(10, -23)
		guide_portrait.size = Vector2.ONE * 150
	guide_portrait.visible = not read


## Держим стрелку с одной стороны цели даже при прокрутке у края.
func _place_guide_pointer(dt: float) -> void:
	var screen := Rect2(Vector2.ZERO, guide_layer.size)
	var target_rect := _guide_rect if _guide_rect.has_area() else _guide_arrow_rect
	var rect := Rect2(target_rect.position - guide_layer.global_position, target_rect.size)
	var arrow_size := guide_pointer.size * guide_pointer.scale
	var strip := Rect2(guide.position, guide.size * guide.scale)
	var target_id := str(_guide_target.get_instance_id()) if is_instance_valid(_guide_target) else str([lg.fort_guide_step(), _guide_lesson_id, guide_text.text, _guide_dragging])
	var new_target := target_id != _guide_arrow_id
	var x := rect.get_center().x
	if selected == "hq" and _guide_target == upgrade_button:
		x = rect.end.x - arrow_size.x
	x -= arrow_size.x * 0.5
	var above := Vector2(x, rect.position.y - arrow_size.y + 2.0)
	var below := Vector2(x, rect.end.y - 2.0)
	var box := Rect2(above if _guide_arrow_above else below, arrow_size)
	var blocked := not screen.intersects(box) or strip.encloses(box)
	_guide_arrow_blocked = _guide_arrow_blocked + dt if blocked else 0.0
	var was_above := _guide_arrow_above
	if new_target or _guide_arrow_blocked > 0.5:
		var maximum := (screen.end - arrow_size).max(Vector2.ZERO)
		var over := Rect2(above.clamp(Vector2.ZERO, maximum), arrow_size)
		var under := Rect2(below.clamp(Vector2.ZERO, maximum), arrow_size)
		var over_cost := above.distance_squared_to(over.position) + 4.0 * over.intersection(strip).get_area()
		var under_cost := below.distance_squared_to(under.position) + 4.0 * under.intersection(strip).get_area()
		_guide_arrow_above = over_cost <= under_cost
		_guide_arrow_blocked = 0.0
	var limit := (screen.end - arrow_size).max(Vector2.ZERO)
	var goal := (above if _guide_arrow_above else below).clamp(Vector2.ZERO, limit)
	var bob := 3.0 * sin(Time.get_ticks_msec() / 650.0) * (-1.0 if _guide_arrow_above else 1.0)
	var at := (goal + Vector2(0.0, bob)).clamp(Vector2.ZERO, limit)
	var retarget := new_target or was_above != _guide_arrow_above or _guide_arrow_goal.distance_to(goal) > 40.0
	retarget = retarget or not _guide_arrow_draw_gliding and guide_pointer.position.distance_to(at) > 40.0
	if _guide_arrow_id != "" and retarget:
		if _guide_arrow_glide != null:
			_guide_arrow_glide.kill()
		_guide_arrow_from = guide_pointer.position
		_guide_arrow_progress = 0.0
		_guide_arrow_glide = create_tween()
		_guide_arrow_glide.tween_property(self, "_guide_arrow_progress", 1.0, 0.2).set_trans(Tween.TRANS_SINE)
	_guide_arrow_id = target_id
	_guide_arrow_goal = goal
	guide_pointer.flip_v = not _guide_arrow_above
	_guide_arrow_draw_gliding = _guide_arrow_progress < 1.0
	guide_pointer.position = _guide_arrow_from.lerp(at, _guide_arrow_progress).clamp(Vector2.ZERO, limit)


func _stock(resource: String) -> float:
	if resource == "money":
		return lg.city_money()
	if resource == "glory":
		return lg.glory
	if resource == "ingots":
		return float(lg.ingots)
	return lg.rations if resource == "rations" else float(lg.mats.get(resource, 0.0))


func _stock_text(resource: String, stock: float) -> String:
	return hud.fmt(floori(stock + 0.0001) if resource == "rations" or resource in Gear.MATS else stock)


func _cost_icons(cost: Dictionary, highlight_shortage := true) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	var amounts: Dictionary = cost.get("mats", {}).duplicate()
	for resource: String in ["money", "glory", "rations"]:
		if float(cost.get(resource, 0)) > 0:
			amounts[resource] = cost[resource]
	var labels := {}
	for resource: String in ["money", "glory", "rations", "iron", "wood", "leather"]:
		var amount := float(amounts.get(resource, 0))
		if amount <= 0:
			continue
		var pair := HBoxContainer.new()
		row.add_child(pair)
		pair.add_child(Kit.image(Look.resource(resource), Vector2(28, 28)))
		var number := _text(hud.fmt(amount), 16, true)
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


func _resource_pressed(resource: String) -> void:
	show_resource_popup(resource)


func show_resource_popup(resource: String) -> void:
	if not TOP_NAMES.has(resource):
		return
	var v := _new_modal(385, true)
	_popup_resource = resource
	modal_panel.name = "FortResourcePopup"
	var heading := HBoxContainer.new()
	heading.add_child(Kit.image(Look.resource(resource), Vector2(46, 46)))
	var title := Look.label(I18n.t(TOP_NAMES[resource]), 28, Look.INK, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	heading.add_child(_button("×", _close_modal))
	v.add_child(heading)
	if resource in Legion.STOCK_RESOURCES:
		var numbers := Look.label("%s / %s" % [_stock_text(resource, _stock(resource)), hud.fmt(lg.resource_cap(resource))], 34)
		numbers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(numbers)
		var store := Look.button(I18n.t("К складу"), FortCutaway.room_icon("store"), Look.INSET)
		store.pressed.connect(_jump_to_type.bind("store"))
		v.add_child(store)
	if resource == "money":
		var info := lg.city_order_info()
		var order := _button("Заказать денарии из города", _order_city_money, "coins")
		order.disabled = info["why"] != ""
		order.text += " · +%s / %s" % [hud.fmt(float(info["amount"])), hud.fmt(lg.resource_cap(resource))]
		order.tooltip_text = order_button.tooltip_text
		v.add_child(order)
	elif resource == "glory":
		v.add_child(_button("Поход", _campaign, "scroll"))
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
	var started := Perf14.begin()
	_build_menu(plot_id)
	Perf14.detail("fort_build_menu", started)


func _build_menu(plot_id: int) -> void:
	_set_placement("")
	_clear_room_selection()
	build_pinned = plot_id >= 0
	build_plot_id = plot_id if build_pinned else lg.fort_empty_plot()
	var lesson_room := _lesson_room(lg.fort_lesson())
	if not is_instance_valid(build_scroll) and lesson_room in ["store", "forge"] and lg.fort_count(lesson_room) == 0:
		build_tab = 2
		build_focus = lesson_room
	var v := _new_modal(970, true)
	if lg.fort_guide_step() == Legion.FortGuide.STORE:
		build_tab = 2
		build_focus = "store"
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
		if type in ["hq", "drill"]:
			continue
		var spec: Dictionary = Legion.FORT_B[type]
		var panel := Look.panel(Look.INSET, 12)
		panel.custom_minimum_size = Vector2(265, 308)
		row.add_child(panel)
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 7)
		panel.add_child(body)
		var picture := _room_picture(type, 1, Vector2(202, 104), false, false)
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
		if lg.fort_guide_free(type, 1):
			body.add_child(Look.label(I18n.t("Бесплатно"), 19, Look.OLIVE))
		else:
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
		tab.name = "FortBuildTab_%d" % tab_index
		tab.pressed.connect(func():
			build_tab = tab_index
			if tab_index == 2 and lesson_room in ["store", "forge"]:
				build_focus = lesson_room
			show_build_menu(build_plot_id if build_pinned else -1))
		tabs_row.add_child(tab)
	var picture_paths := {}
	for type: String in build_cards:
		var group := 0 if not Legion.fort_production(type, 1).is_empty() else 1 if type in ["barracks", "drill", "stable"] else 2
		var shown := group == build_tab
		(build_cards[type]["panel"] as Control).visible = shown
		if shown:
			picture_paths[FortCutaway.room_texture_path(type, 1)] = true
	_build_sig = _plot_signature()
	_refresh_build_menu()
	_fit_modal.call_deferred()
	_focus_build_card.call_deferred()
	_build_pictures(build_scroll, picture_paths)


func _build_pictures(scroll: ScrollContainer, paths: Dictionary) -> void:
	var textures := await CityWarmup.fetch(get_tree(), paths)
	if not is_instance_valid(scroll) or scroll != build_scroll:
		return
	var started := Perf14.begin()
	for type: String in build_cards:
		var path := FortCutaway.room_texture_path(type, 1)
		if textures.has(path):
			var frame: PanelContainer = build_cards[type]["picture"]
			var pic := frame.get_child(0) as TextureRect
			pic.texture = textures[path]
			if diorama is FortCutaway:
				(diorama as FortCutaway).remember_art(path, pic.texture)
	Perf14.detail("fort_build_pictures", started)


func _focus_build_card() -> void:
	var type := build_focus
	build_focus = ""
	if type == "" and lg.fort_guide_step() == Legion.FortGuide.STORE:
		type = "store"
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
	var started := Perf14.begin()
	_place_build_profiled(id, type)
	Perf14.end(Perf14.CAMP_BUILD, started)
	Perf14.detail("fort_build_action", started)


func _place_build_profiled(id: int, type: String) -> void:
	var room_type := placement_type if type == "" else type
	var started := Perf14.begin()
	var built := lg.fort_build(room_type, id)
	Perf14.detail("fort_build_rules", started)
	if not built:
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
	if selected not in ["hq", "store"] and lg.fort_worker(selected_plot).is_empty():
		show_worker_picker()
		return
	if not Legion.fort_production(selected, int(plot["lv"])).is_empty():
		_collect_plot(selected_plot, main_action.global_position)
		return
	match selected:
		"barracks": show_worker_picker()
		"forge", "arsenal":
			var plot_id := selected_plot
			_close_modal()
			_hide_card()
			lu.open_craft(plot_id)
		"mars": _aux(selected)
		"store": show_storage()
		"drill": _show_support("drill")
		"infirmary": _show_support("infirmary")
		"hq": show_expansion("", true)
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
		data.append([plot["id"], plot["b"], plot["lv"], (plot["up"] as Dictionary).is_empty(), plot.get("workers", [])])
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
	collect.add_theme_color_override("icon_disabled_color", Color.WHITE)
	collect.add_theme_stylebox_override("disabled", Look.box(Look.DARK, Look.BRONZE, 10, 4))
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
	var knowledge := Look.button("", KnowUI.node_icon("smith"), Look.DARK, Vector2(132, 38))
	knowledge.name = "FortForgeKnowledgeTimer"
	knowledge.position = Vector2(-32, -42)
	knowledge.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	knowledge.add_theme_constant_override("icon_max_width", 28)
	knowledge.pressed.connect(func(): show_knowledge(String(lg.knowledge_timer().get("id", "smith"))))
	panel.add_child(knowledge)
	knowledge.hide()
	return {"knowledge": knowledge, "panel": panel, "button": button, "clock": clock, "title": level, "state": alert, "collect": collect, "ring": ring, "timer": timer}


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
	var know_badge: Button = marker["knowledge"]
	know_badge.hide()
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
	if type == "forge" and not lg.knowledge_timer().is_empty():
		know_badge.text = clock_text(float(lg.knowledge_timer()["end"]) - Legion.now())
		know_badge.icon = KnowUI.node_icon(String(lg.knowledge_timer()["id"]))
		know_badge.show()
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
		collect.text = "+" + hud.fmt(floori(float(plot["pend"]) + 0.0001))
		collect.tooltip_text = I18n.t("Собрать")
		var full := _stock(resource) >= lg.resource_cap(resource)
		collect.disabled = full
		if full and not lg.fort_guide_collect_ready(int(plot["id"])):
			collect.show()
			collect.icon = KnowUI.lock_icon()
			collect.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			collect.text = ""
			collect.tooltip_text = I18n.t("Запас полон. Потратьте ресурсы, чтобы собрать ещё.")
			collect.set_meta("stock_lock", true)
		else:
			collect.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			collect.set_meta("stock_lock", false)
		(marker["ring"] as Control).visible = not bool(collect.get_meta("stock_lock"))
		marker["ring"].set("value", float(plot["pend"]) / maxf(1.0, float(prod["cap"])))
		if lg.fort_guide_collect_ready(int(plot["id"])):
			collect.show()
			collect.disabled = false
		idle = not full and float(plot["pend"]) >= float(prod["cap"]) - 0.001
	elif type == "barracks" and level > 0:
		idle = true
		for soldier: Dictionary in lg.soldiers:
			if lg.s_state(soldier) == "train" and int(soldier.get("train_plot", -1)) == int(plot["id"]):
				idle = false
				(marker["timer"] as Control).show()
				marker["timer"].set("value", lg.train_progress(soldier))
				button.tooltip_text += " · " + clock_text(lg.s_left(soldier))
				break
	collect.set_meta("fort_full", idle and not prod.is_empty())
	var alert: Label = marker["state"]
	alert.text = "!"
	var needs_worker := type != "hq" and level > 0 and lg.fort_worker(int(plot["id"])).is_empty()
	alert.visible = (idle or needs_worker) and timer.is_empty()
	if needs_worker:
		button.tooltip_text += "\n" + I18n.t("Нет работника. Назначьте человека в карточке.")
	if alert.visible and not needs_worker:
		button.tooltip_text += "\n" + I18n.t("Можно тренировать воина." if type == "barracks" else "Производство заполнено. Соберите ресурсы.")


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


func _barracks_status(parent: VBoxContainer, level: int) -> void:
	parent.add_child(Look.label(I18n.t("Предел обучения: %d") % Legion.training_cap(level), 21))
	for person: Dictionary in lg.fort_occupants(selected_plot):
		var info := lg.training_info(person, lg.fort_plot(selected_plot))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		parent.add_child(row)
		var heading := Look.label(I18n.t("Ур. %d → %d") % [info["level"], info["to"]] if int(info["to"]) <= int(info["cap"]) else I18n.t("Уровень %d") % info["level"], 20)
		heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(heading)
		var terms := HBoxContainer.new()
		terms.name = "FortTrainingTerms"
		terms.add_theme_constant_override("separation", 8)
		row.add_child(terms)
		if int(info["to"]) <= int(info["cap"]):
			var food := Kit.image(Look.resource("rations"), Vector2(28, 28))
			food.name = "FortTrainingFood"
			terms.add_child(food)
			var price := Look.label(hud.fmt(info["food"]), 20)
			price.name = "FortTrainingPrice"
			terms.add_child(price)
			terms.add_child(Look.label("·", 20))
			var clock := Kit.image("timer", Vector2(24, 24))
			clock.name = "FortTrainingClock"
			clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			terms.add_child(clock)
		var timer := Look.label("", 20)
		timer.name = "FortTrainingTimer"
		timer.set_meta("sid", person["id"])
		terms.add_child(timer)


func _worker_card(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "FortWorker"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var count := _text(I18n.t("Отряд %d/%d" if selected == "hq" else "%d / %d") % [lg.fort_occupants(selected_plot).size(), lg.fort_room_slots(selected_plot)], 19, true)
	count.name = "FortWorkerName"
	row.add_child(count)
	if selected == "hq":
		_hq_squad_places(row)
		return
	var pixels := 76
	for person: Dictionary in lg.fort_occupants(selected_plot):
		var sid := int(person["id"])
		var b := Kit.round_button(null)
		b.custom_minimum_size = Vector2(pixels + 12, pixels + 12)
		b.tooltip_text = String(person["name"])
		b.pressed.connect(func(): show_dweller(sid))
		row.add_child(b)
		var face := _person_portrait(person, pixels)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(face)
		face.position = Vector2(6, 6)
	var plus := Kit.round_button("plus")
	plus.name = "FortAssignSlot"
	plus.tooltip_text = I18n.t("Назначить")
	plus.pressed.connect(show_worker_picker)
	row.add_child(plus)


func _hq_squad_places(row: HBoxContainer) -> void:
	for index in Legion.SQUAD_V3:
		var seat := VBoxContainer.new()
		seat.name = "FortHQPlace_%d" % index
		seat.custom_minimum_size.x = 74
		seat.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(seat)
		var sid := int(lg.squad3[index])
		var unlock := lg.fort_place_unlock_level(index)
		if unlock > 0:
			var lock := Kit.image("lock", Vector2(32, 32))
			lock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			seat.add_child(lock)
			var label := Look.label(I18n.t("Штаб %s") % Legion.roman(unlock), 18, Look.WINE)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			seat.add_child(label)
			continue
		var button := Look.button("", Kit.texture("plus") if sid == 0 else null, Look.INSET, Vector2(66, 66), true)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		seat.add_child(button)
		if sid == 0:
			button.name = "FortHQEmptyPlace"
			button.tooltip_text = I18n.t("Пустое место")
			button.pressed.connect(show_squad.bind(index))
			continue
		var person := lg.soldier(sid)
		button.tooltip_text = String(person["name"])
		button.pressed.connect(show_dweller.bind(sid))
		var face := _person_portrait(person, 60)
		button.add_child(face)
		face.position = Vector2(3, 3)


func show_worker_picker() -> void:
	var target := selected_plot
	var v := _new_modal(540)
	modal_panel.name = "FortWorkerPicker"
	v.add_child(_text(I18n.t("Кто будет тренироваться?" if selected == "barracks" else "Кто будет работать?"), 24, true))
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
		button.name = "FortWorkerChoice_%d" % sid
		var why := lg.fort_can_assign(target, sid)
		button.disabled = why != ""
		button.tooltip_text = I18n.t(why)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
	var recruit_worker := _button("У ворот форта", open_recruit_picker, "legion")
	recruit_worker.name = "FortWorkerRecruit"
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
		var row := HBoxContainer.new()
		body.add_child(row)
		row.add_child(_person_portrait(person, 46))
		var button := _button(_soldier_title(person), func(): _show_soldier(sid))
		button.name = "FortPerson_%d" % sid
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
	v.add_child(_button("Закрыть", _close_modal))
	_fit_modal.call_deferred()


func show_dweller(sid: int, slot := "", change := "", tab := "all", page := 0) -> void:
	var person := lg.soldier(sid)
	if person.is_empty():
		_close_modal()
		return
	var v := _new_framed_modal(1480)
	modal_panel.name = "FortDwellerCard"
	dweller_sid = sid
	dweller_slot = slot
	dweller_change = change
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 8)
	v.add_child(columns)
	var left_panel := Look.panel(Look.INSET, 14)
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left_panel)
	var left := VBoxContainer.new()
	left_panel.add_child(left)
	var title := Look.label(String(person["name"]), 37, Color("85632e") if bool(person.get("hero", false)) else Look.INK, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(title)
	var stats := lg.soldier_stats(person, Legion.unit_of_class(String(person["cls"])))
	var health := Look.meter(float(stats["hp"]), float(stats["hp"]))
	health.custom_minimum_size.y = 7
	left.add_child(health)
	var figure_row := HBoxContainer.new()
	figure_row.add_theme_constant_override("separation", 8)
	left.add_child(figure_row)
	var profile := VBoxContainer.new()
	profile.alignment = BoxContainer.ALIGNMENT_CENTER
	profile.custom_minimum_size.x = 113
	figure_row.add_child(profile)
	var job := Look.label(Soldiers.class_name_of(String(person["cls"])).capitalize(), 21)
	profile.add_child(Look.label(I18n.t("Уровень %d") % (int(person["rank"]) + 1), 19))
	profile.add_child(job)
	var stars := Look.label("★".repeat(int(person["stars"])) + "☆".repeat(5 - int(person["stars"])), 18, Look.WINE)
	stars.tooltip_text = I18n.t(STAR_TIP)
	stars.mouse_filter = Control.MOUSE_FILTER_PASS
	profile.add_child(stars)
	for entry: Array in [["need_services", "Здоровье", roundi(float(stats["hp"]))], ["soldier", "Атака", roundi(float(stats["atk"]))],
			["equip", "Защита", roundi(float(stats["armor"]))], ["star", "Сила", Legion.power(stats)]]:
		var stat := HBoxContainer.new()
		stat.add_child(Kit.image(String(entry[0]), Vector2(30, 30)))
		stat.add_child(Look.label(str(entry[2]), 25))
		stat.tooltip_text = I18n.t(String(entry[1]))
		stat.mouse_filter = Control.MOUSE_FILTER_PASS
		profile.add_child(stat)
	var hands := VBoxContainer.new()
	figure_row.name = "FortGearSlots"
	hands.alignment = BoxContainer.ALIGNMENT_CENTER
	figure_row.add_child(hands)
	_dweller_slot(hands, person, "weapon", tab, page)
	_dweller_slot(hands, person, "offhand", tab, page)
	var portrait := Look.panel(Look.PAPER, 3)
	portrait.name = "FortDwellerPortrait"
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	figure_row.add_child(portrait)
	var preview := FortPersonPreview.new()
	preview.name = "FortPortraitArt"
	portrait.add_child(preview)
	preview.setup(person, lg.worn(person), 245, true)
	preview.custom_minimum_size = Vector2(245, 355)
	var clothing := VBoxContainer.new()
	clothing.alignment = BoxContainer.ALIGNMENT_CENTER
	figure_row.add_child(clothing)
	for gear_slot: String in ["helmet", "armor", Gear.OUTFIT_SLOT]:
		_dweller_slot(clothing, person, gear_slot, tab, page)
	var clothes := lg.item(int(person.get("gear", {}).get(Gear.OUTFIT_SLOT, 0)))
	if not clothes.is_empty():
		var bonus := Look.label(StoreUI.item_stats(lg, clothes), 20)
		bonus.name = "FortOutfitBonus"
		bonus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bonus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		left.add_child(bonus)
		if change == "outfit":
			bonus.modulate = Color(1.0, 1.0, 1.0, 0.0)
			bonus.resized.connect(func(): bonus.pivot_offset = bonus.size * 0.5)
			bonus.scale = Vector2.ONE * 0.82
			var pop := create_tween().set_parallel(true)
			pop.tween_property(bonus, "modulate", Color.WHITE, 0.16)
			pop.tween_property(bonus, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var move := Look.button(I18n.t("Переместить"), Kit.texture("swap"), Look.INSET)
	move.name = "FortMoveDweller"
	move.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	move.disabled = not lg.fort_can_move(sid)
	move.pressed.connect(func(): _move_dweller(sid))
	left.add_child(move)
	if bool(person.get("hero", false)):
		var edit := Look.button(I18n.t("Изменить облик"), null, Look.PAPER)
		edit.name = "FortHeroCustomize"
		edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		edit.pressed.connect(func():
			close()
			hud.game.open_hero_screen("edit"))
		left.add_child(edit)
	var store_panel := Look.panel(Look.PAPER, 14)
	columns.add_child(store_panel)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 652
	store_panel.add_child(right)
	var head := HBoxContainer.new()
	right.add_child(head)
	var caption := Look.label(I18n.t("На складе"), 32, Look.INK, true)
	caption.name = "FortInventoryTitle"
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(caption)
	head.add_child(Look.close_button(_close_modal, 49))
	StoreUI.grid(self, right, sid, tab, page, slot)
	if change != "" and change != "outfit":
		var feedback := Look.label(change, 20, Look.OLIVE)
		feedback.name = "FortEquipChange"
		right.add_child(feedback)
	var navigation := HBoxContainer.new()
	navigation.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(navigation)
	var previous := Look.button("‹", null, Look.INSET, Vector2(52, 42))
	var next := Look.button("›", null, Look.INSET, Vector2(52, 42))
	previous.tooltip_text = I18n.t("Предыдущий житель")
	next.tooltip_text = I18n.t("Следующий житель")
	previous.pressed.connect(_dweller_next.bind(sid, -1))
	next.pressed.connect(_dweller_next.bind(sid, 1))
	navigation.add_child(previous)
	for s: Dictionary in lg.soldiers:
		var id := int(s["id"])
		var dot := Look.label("●" if id == sid else "○", 20, Look.WINE if id == sid else Look.EDGE)
		dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		navigation.add_child(dot)
	navigation.add_child(next)
	_fit_modal.call_deferred()


func _dweller_slot(parent: Control, person: Dictionary, slot: String, tab: String, page: int) -> void:
	var sid := int(person["id"])
	var it := lg.item(int(person.get("gear", {}).get(slot, 0)))
	var button := _gear_slot_button(78, dweller_slot == slot)
	button.name = "FortGear_" + slot
	button.tooltip_text = I18n.t(String(Gear.SLOT_NAME[slot])).capitalize()
	if not it.is_empty():
		button.tooltip_text += "\n" + Gear.name_of(it) + "\n" + StoreUI.item_stats(lg, it)
		if slot == Gear.OUTFIT_SLOT and lg.fort_lesson() == "outfit" and lg.fort_outfit_lesson_target(sid).x == sid:
			button.pressed.connect(show_dweller.bind(sid, slot))
		else:
			button.pressed.connect(StoreUI.item_card.bind(self, int(it["id"]), sid, show_dweller.bind(sid, "", "", tab, page)))
	else:
		button.pressed.connect(show_dweller.bind(sid, slot))
	var icon := Kit.image(StoreUI.item_icon(self, it) if not it.is_empty() else Kit.texture("res://assets/ui/ai/icons/%s.png" % String(LegionUi.GEAR_ICON[slot])), Vector2(62, 62))
	icon.position = Vector2(8, 8)
	button.add_child(icon)
	if not it.is_empty():
		var badge := Look.label(str(Gear.tier_of(it)), 18, Look.PAPER)
		badge.name = "TierBadge"
		badge.add_theme_stylebox_override("normal", Look.box(Look.DARK, Look.BRONZE, 6, 3))
		badge.position = Vector2(5, 50)
		button.add_child(badge)
	parent.add_child(button)

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
	var icon := Kit.image(StoreUI.item_icon(self, it), Vector2.ZERO)
	body.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var badge := Kit.label(str(Gear.tier_of(it)), 14, true)
	badge.name = "TierBadge"
	badge.position = Vector2(pixels - 36, pixels - 40)
	body.add_child(badge)
	return frame


func guide_equip_item(sid: int, slot: String) -> int:
	if slot == Gear.OUTFIT_SLOT and lg.fort_guide_step() in [Legion.FortGuide.TREASURY, Legion.FortGuide.KITCHEN] and sid == int(lg.flags.get("fort_guide_sid", 0)):
		return int(lg.flags.get("fort_guide_item", 0))
	if slot == Gear.OUTFIT_SLOT and lg.fort_lesson() == "outfit":
		return lg.fort_outfit_lesson_target(sid).y
	return 0


func _equip_dweller(sid: int, iid: int) -> void:
	var delta := lg.equip_power(sid, iid)
	if lg.equip(sid, iid):
		if lg.fort_guide_collect_ready(lg.fort_worker_plot(sid)):
			_close_modal()
			hud.notify(I18n.t(StoreUI.item_stats(lg, lg.item(iid))), "happy")
		else:
			var it := lg.item(iid)
			var feedback: String = "outfit" if it.get("slot") == Gear.OUTFIT_SLOT else I18n.t("Было → стало: %d → %d") % [int(delta[0]), int(delta[1])]
			show_dweller(sid, "", feedback)
		_refresh()


func _dweller_next(sid: int, direction: int) -> void:
	var ids: Array[int] = []
	for person: Dictionary in lg.soldiers:
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


func _expansion_reason(info: Dictionary) -> String:
	var why := lg.fort_can_expand()
	if why.begins_with("Для расширения нужен Штаб"):
		return I18n.t("Для расширения нужен Штаб %d уровня") % int(info["hq"])
	return I18n.t(why)


func _expansion_cost_row(info: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.add_child(_cost_icons(info["cost"]))
	row.add_child(Look.label("·", 19))
	row.add_child(Kit.time_row(duration_text(float(info["seconds"]))))
	return row


func show_expansion(axis := "", from_hq := false) -> void:
	var v := _new_modal(470)
	modal_panel.name = "FortExpansionCard"
	var choosing := axis == ""
	var back: Callable = show_building.bind("hq") if from_hq else _close_modal
	var title := "Расширить форт" if choosing else ("+ этаж" if axis == "floor" else "+ секция")
	v.add_child(Kit.ribbon(I18n.t(title)))
	v.add_child(_room_picture("hq", lg.camp_level("hq"), Vector2(400, 150)))
	var info := lg.fort_expansion_info(axis)
	v.add_child(_expansion_cost_row(info))
	var why := _expansion_reason(info)
	if why != "":
		v.add_child(Kit.banner_red(why))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	if choosing:
		for choice: String in ["floor", "section"]:
			var option := _button("+ этаж" if choice == "floor" else "+ секция", show_expansion.bind(choice, from_hq), "build")
			option.name = "FortExpand_" + choice
			option.disabled = why != ""
			row.add_child(option)
		row.add_child(_button("Закрыть", back))
		_fit_modal.call_deferred()
		return
	var build := Kit.button("green", "build")
	build.name = "FortExpansionConfirm"
	build.tooltip_text = I18n.t("Строить")
	build.pressed.connect(func():
		if lg.fort_expand(axis):
			back.call()
			_refresh()
		else:
			show_expansion(axis, from_hq))
	build.disabled = why != ""
	row.add_child(build)
	row.add_child(_button("Закрыть", back))
	_fit_modal.call_deferred()


func show_hq_upgrade(id: int) -> void:
	if lg.fort_plot(id).get("b") != "hq":
		return
	if not lg.fort_plot_timer(id).is_empty():
		show_plot(id)
		return
	HqUI.build(self, id)
	lg.finish_fort_lesson("hq")


func _instant_upgrade() -> void:
	var started := Perf14.begin()
	if lg.fort_instant(selected_plot, instant_button.get_meta("quote", {})):
		_build_card()
	_refresh()
	Perf14.detail("fort_instant", started)


func _room_picture(type: String, level: int, dims: Vector2, building := false, with_art := true) -> PanelContainer:
	var frame := Kit.inset()
	var source: Variant = FortCutaway.room_texture_path(type, level, building) if with_art else null
	var pic := Kit.image(source, dims)
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.clip_contents = true
	frame.add_child(pic)
	return frame


func _person_portrait(person: Dictionary, pixels: float, newcomer := false) -> PanelContainer:
	var frame := FortPerson.portrait(person, pixels, [] if newcomer else lg.worn(person))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	order_button.tooltip_text += "\n%s / %s" % [hud.fmt(lg.city_money()), hud.fmt(lg.resource_cap("money"))]
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
	show_knowledge("smith")


func show_knowledge(id := "smith", back := Callable()) -> void:
	KnowUI.build(self, id, back)
	KnowUI.refresh(self)
