class_name CampUI
extends Control
## Форт V3: действия привязаны к участкам, павильоны — временный адаптер.

const Ring = preload("res://scripts/fort_ui_ring.gd")
const USE_3D := true
const USE_CUTAWAY := true
var use_cutaway := USE_CUTAWAY # Старые сценарии могут явно выбрать прежнюю диораму.
var cutaway_markers: Control
var _worker_target := -1
const FORT_ICON := {"hq": "castle", "barracks": "legion", "kitchen": "bread",
	"smelter": "anvil", "sawmill": "wood", "tannery": "clothes", "store": "amphora",
	"forge": "hammer", "drill": "swords", "infirmary": "medic", "mars": "laurels",
	"stable": "horse", "tower": "castle", "treasury": "coins", "arsenal": "shield"}
const TOP_NAMES := {"money": "Денарии", "rations": "Пайки", "glory": "Слава", "ingots": "Слитки"}
const TOP_ICONS := {"money": "coins", "rations": "bread", "glory": "laurels", "ingots": "coins"}
const TOP_TIPS := {
	"money": "Денарии поступают в казну города от налогов.",
	"rations": "Пайки готовят полевые кухни и городские пекарни. Собирайте их для походов.",
	"glory": "Слава — награда за победы и задания дня.",
	"ingots": "Слитки копятся в Сокровищнице. Ещё их можно найти в сундуках.",
}
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
var guide: PanelContainer
var guide_text: Label
var _guide_target: Control
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
	"barracks": "Призыв жителей. Места в отряде: 3 → 4 → 5 на уровнях 1, 3, 5.",
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
var chips: HBoxContainer
var ration_label: Label
var glory_label: Label
var mats_label: Label
var resource_chips := {}
var bubbles := {}
var ingot_label: Label
var chest_button: Button
var speed_widgets: Array = []
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
var card_scroll: ScrollContainer
var card_body: VBoxContainer
var selected := ""
var card_level: Label
var upgrade_button: Button
var upgrade_reason: Label
var main_action_reason: Label
var upgrade_timer: Label
var upgrade_bar: ProgressBar
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
	return lu._btn(text, 0, 16, hud.ico(icon, 48) if icon != "" else null, "", action)


func _text(text: String, sz := 16, bold := false) -> Label:
	return hud._label(text, sz, bold, LegionUi.C_INK)


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
	if lg.flags.has("camp_told") or top_button == null or not lg.window_open() or not top_button.is_visible_in_tree() or visible:
		return
	var rig = hud.game.get("rig")
	if hud.advisor_panel.visible or hud.game.tool != "" or (rig != null and rig.cine) or not hud.game.stories.cine.is_empty():
		return
	lg.flags["camp_told"] = true
	hud.advisor("Лагерь открыт", "Призывайте жителей в Легион — кнопка «Легион» наверху.", Callable(), false, true)   # маленькая карточка в углу, не мешает
	hud.show_pointer({"kind": "legion", "tip": "Лагерь"})
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
	visible = true
	move_to_front()
	_start_diorama()
	_prepare_guide()
	set_process(true)
	set_process_input(true)
	_refresh()
	_layout()
	hud._update_pointer()


func close() -> void:
	if lu.camp_window != "":
		lu.close(false)
	_close_modal()
	_hide_card()
	_stop_diorama()
	for entry: Dictionary in _collection_fx:
		(entry["tween"] as Tween).kill()
		if is_instance_valid(entry["label"]):
			(entry["label"] as Label).queue_free()
	_collection_fx.clear()
	guide.hide()
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
	chips = HBoxContainer.new()
	chips.name = "FortResources"
	chips.add_theme_constant_override("separation", 12)
	add_child(chips)
	for resource: String in TOP_NAMES:
		_resource_bar(resource)
	ration_label = resource_chips["rations"]
	glory_label = resource_chips["glory"]
	ingot_label = resource_chips["ingots"]
	left_column = VBoxContainer.new()
	left_column.add_theme_constant_override("separation", 12)
	add_child(left_column)
	campaign_button = _nav("Поход", "scroll", _campaign)
	daily_button = _nav("Задания дня", "book", func(): _aux("daily"))
	chest_button = _nav("Сундуки", "commerce", show_chests)
	var arena := _nav("Арена", "swords", func(): pass)
	arena.disabled = true
	arena.tooltip_text = I18n.t("Бои с другими игроками откроются позже.")
	var lock := hud._icon("lock", 24)
	arena.add_child(lock)
	lock.position = Vector2(42, 40)
	build_button = hud._round("hammer", I18n.t("Строить"), 96, show_build_menu)
	build_button.name = "FortBuild"
	add_child(build_button)
	_badge(build_button)
	var build_label := _text(I18n.t("Строить"), 17, true)
	build_button.add_child(build_label)
	build_label.position = Vector2(0, 100)
	build_label.custom_minimum_size.x = 96
	build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exit_button = _button("×", close)
	exit_button.tooltip_text = I18n.t("Закрыть")
	exit_button.custom_minimum_size = Vector2(44, 44)
	add_child(exit_button)
	bottom = HBoxContainer.new()
	add_child(bottom)
	bottom.add_child(_button("Отряд", show_squad, "shield"))
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
	guide = hud._panel(self, "bar", 0, 10)
	guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide_text = _text("", 18, true)
	guide.add_child(guide_text)
	guide.hide()


func _resource_bar(resource: String) -> void:
	var panel := hud._panel(chips, "bar", 0, 10)
	panel.custom_minimum_size = Vector2(210, 76)
	panel.tooltip_text = I18n.t(String(TOP_TIPS[resource]))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	panel.add_child(row)
	var res_icon := TextureRect.new()
	res_icon.texture = load(FortCutaway.ART + "icons/res_" + ("denarii" if resource == "money" else resource) + ".png")
	res_icon.custom_minimum_size = Vector2(40, 40)
	res_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	res_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(res_icon)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 1)
	row.add_child(body)
	body.add_child(_text(I18n.t(String(TOP_NAMES[resource])), 12))
	var number := _text("0", 23, true)
	body.add_child(number)
	resource_chips[resource] = number
	var fill := lu._bar(0, 0)
	fill.custom_minimum_size.y = 5
	fill.visible = resource in ["rations", "ingots"]
	body.add_child(fill)
	var plus := _button("+", func(): show_resource_popup(resource))
	plus.name = "Plus_" + resource
	plus.custom_minimum_size = Vector2(28, 30)
	plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plus.tooltip_text = I18n.t("Где получить")
	row.add_child(plus)
	resource_bars[resource] = {"panel": panel, "fill": fill, "plus": plus}


func _badge(button: Button) -> Label:
	var label := _text("", 14, true)
	label.add_theme_color_override("font_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("a52e26")
	style.set_corner_radius_all(14)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	label.add_theme_stylebox_override("normal", style)
	button.add_child(label)
	label.position = Vector2(button.custom_minimum_size.x - 19, -3)
	label.hide()
	counters[button] = label
	return label


func _count(button: Button, amount: int) -> void:
	var label: Label = counters[button]
	label.text = str(amount)
	label.visible = amount > 0


func _nav(title: String, icon: String, action: Callable) -> Button:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 2)
	left_column.add_child(group)
	var button := hud._round(icon, I18n.t(title), 64, action)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	group.add_child(button)
	_badge(button)
	var label := _text(I18n.t(title), 13, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	group.add_child(label)
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
	var ck := minf(k, (size.x - 120.0) / maxf(1.0, chips.size.x))
	chips.scale = Vector2.ONE * ck
	chips.position = Vector2((size.x - chips.size.x * ck) * 0.5, 12)
	exit_button.position = Vector2(size.x - 54, 12)
	left_column.reset_size()
	left_column.scale = Vector2.ONE * k
	left_column.position = Vector2(16, 116 * k)
	build_button.scale = Vector2.ONE * k
	build_button.position = size - Vector2(124, 146) * k
	bottom.reset_size()
	bottom.scale = Vector2.ONE * k
	bottom.position = Vector2(22, size.y - 66 * k)
	extra_plots.scale = Vector2.ONE * k
	extra_plots.position = Vector2(150 * k, size.y - 148 * k)
	extra_plots.size = Vector2(maxf(150, size.x / k - 310), 136)
	gate.hide()
	if is_instance_valid(card):
		card.scale = Vector2.ONE * k
		card.size = Vector2(760, 376)
		card.position = Vector2((size.x - 760 * k) * 0.5, size.y - 392 * k + _sheet_offset)
	_fit_modal()
	_layout_guide()
	if diorama is FortCutaway:
		_layout_cutaway_markers(k)


func _process(dt: float) -> void:
	if not visible:
		return
	for resource: String in bubbles:
		var bubble: Button = bubbles[resource]["button"]
		var full := float(lg.pending_resources.get(resource, 0.0)) >= lg.resource_cap(resource) - 0.001
		var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.005) if full else 1.0
		bubble.modulate = Color(pulse, pulse, 1.0)
	if is_instance_valid(_guide_target) and guide.visible:
		var glow := 1.12 + 0.10 * sin(Time.get_ticks_msec() * 0.004)
		_guide_target.modulate = Color(glow, glow, 1.0)
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
	return "%d:%02d:%02d" % [t / 3600, (t % 3600) / 60, t % 60]


func _roster_signature() -> String:
	var entries := []
	for s: Dictionary in lg.soldiers:
		entries.append([s["id"], s["name"], _class(s), s["stars"], s["rank"], lg.s_state(s)])
	return str([entries, lg.squad3, lg.camp, lg.upg.keys(), lg.hero_level(), lg.hero_training.is_empty(), lg.forging.is_empty(), _plot_signature()])


func _refresh() -> void:
	if is_instance_valid(diorama):
		diorama.sync()
	(resource_chips["money"] as Label).text = hud.fmt(lg.city_money())
	ration_label.text = "%d / %d" % [lg.rations_now(), lg.ration_cap()]
	glory_label.text = hud.fmt(lg.glory)
	ingot_label.text = "%d / %d" % [lg.ingots, lg.resource_cap("ingots")]
	(resource_bars["rations"]["fill"] as ProgressBar).value = lg.rations / maxf(1, lg.ration_cap())
	(resource_bars["ingots"]["fill"] as ProgressBar).value = float(lg.ingots) / maxf(1, lg.resource_cap("ingots"))
	_count(chest_button, lg.chest_queue.size())
	_count(daily_button, lg.daily_done() if lg.can_open_daily() == "" else 0)
	var frontier := lg.frontier()
	var stage := lg.stage_info(int(frontier["cycle"]), int(frontier["r"]), int(frontier["s"]))
	# Передний край может быть закрыт, но повторный бой всё ещё доступен.
	var battle_ready := lg.can_fight(stage) == "" or lg.can_fight(lg.stage_info(0, 0, 0)) == ""
	_count(campaign_button, 1 if battle_ready else 0)
	var available := 0
	for type: String in Legion.FORT_B:
		if type != "hq" and lg.fort_can_build(type, lg.fort_empty_plot()) == "":
			available += 1
	_count(build_button, available)
	_sync_markers()
	_refresh_bubbles()
	_refresh_hero()
	_refresh_speeds()
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
	if diorama is FortCutaway:
		diorama.focus_plot("plot_%d" % plot_id)
	card_backdrop = Control.new()
	add_child(card_backdrop)
	card_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	card_backdrop.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_hide_card())
	card = hud._panel(self, "panel", 0, 18)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.name = "FortBuildingCard"
	card_scroll = ScrollContainer.new()
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(card_scroll)
	card_body = VBoxContainer.new()
	card_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_body.add_theme_constant_override("separation", 10)
	card_scroll.add_child(card_body)
	_build_card()
	_refresh_card()
	_sheet_offset = 100.0
	_layout()
	_card_tween = create_tween()
	_card_tween.tween_method(_slide_sheet, 100.0, 0.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _slide_sheet(offset: float) -> void:
	_sheet_offset = offset
	_layout()


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
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	card_body.add_child(head)
	head.add_child(_room_icon(selected, 88))
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 6)
	head.add_child(details)
	var title := HBoxContainer.new()
	details.add_child(title)
	var name_label := _text(I18n.t(String(Legion.FORT_B[selected]["name"])), 26, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(name_label)
	var level_panel := hud._panel(title, "bar", 0, 6)
	card_level = _text(I18n.t("ур. %d") % int(info["lv"]), 15, true)
	level_panel.add_child(card_level)
	title.add_child(_button("×", _hide_card))
	details.add_child(_wrap(I18n.t("Даёт: %s") % String(info["gives"]), 16))
	var next := _wrap(I18n.t("ур. %d: %s") % [int(info["lv"]) + 1, String(info["gives_next"])], 14)
	next.add_theme_color_override("font_color", Color("326443"))
	details.add_child(next)
	_worker_card(card_body)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 22)
	card_body.add_child(actions)
	var primary := VBoxContainer.new()
	primary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(primary)
	main_action = _button("", _main_action, String(FORT_ICON[selected]))
	main_action.name = "FortMainAction"
	main_action.custom_minimum_size = Vector2(290, 52)
	main_action.add_theme_stylebox_override("normal", hud._box_pill(16, 8, "g_btn_on"))
	primary.add_child(main_action)
	main_action_reason = _wrap("", 13)
	primary.add_child(main_action_reason)
	if selected == "barracks":
		recruit_button = main_action
	if selected == "hq":
		var expansion := Legion.fort_exp_info(int(lg.fort["exp"]) + 1)
		primary.add_child(_cost_icons(expansion["cost"]))
		primary.add_child(_text(I18n.t("%d участков · %s") % [int(expansion["plots"]), duration_text(float(expansion["time_h"]) * 3600.0 / maxf(0.001, lg.time_k))], 13))
	var upgrade := VBoxContainer.new()
	upgrade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(upgrade)
	upgrade_button = _button("Улучшить", _upgrade, "hammer")
	upgrade_button.custom_minimum_size.y = 44
	upgrade.add_child(upgrade_button)
	upgrade_cost = VBoxContainer.new()
	upgrade.add_child(upgrade_cost)
	upgrade_cost.add_child(_cost_icons(info["next_cost"]))
	upgrade_cost.add_child(_text(duration_text(float(info["next_time"])), 14))
	var timer_row := HBoxContainer.new()
	upgrade.add_child(timer_row)
	card_ring = Ring.new()
	card_ring.custom_minimum_size = Vector2(56, 56)
	timer_row.add_child(card_ring)
	upgrade_timer = _text("", 24, true)
	upgrade_timer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	timer_row.add_child(upgrade_timer)
	upgrade_reason = _wrap("", 13)
	card_body.add_child(upgrade_reason)
	_add_speed(upgrade, "fort_%d" % selected_plot)
	if selected == "hq":
		_add_speed(primary, "fort_expand")


func _refresh_card() -> void:
	var plot := lg.fort_plot(selected_plot)
	if plot.is_empty() or not is_instance_valid(main_action):
		return
	var timer: Dictionary = plot["up"]
	if selected == "hq" and timer.is_empty():
		timer = lg.fort.get("up", {})
	var running := not timer.is_empty()
	var left := maxf(0.0, float(timer.get("end", 0.0)) - Legion.now())
	card_ring.visible = running
	card_ring.set("value", 1.0 - left / maxf(1, float(timer.get("total", 1))))
	upgrade_timer.visible = running
	upgrade_timer.text = clock_text(left)
	upgrade_button.visible = not running
	upgrade_cost.visible = not running
	var why := lg.fort_can_upgrade(selected_plot)
	upgrade_button.disabled = why != ""
	upgrade_button.tooltip_text = I18n.t(why)
	upgrade_reason.text = I18n.t(why) if not running else ""
	upgrade_reason.visible = upgrade_reason.text != ""
	var prod := Legion.fort_production(selected, maxi(1, int(plot["lv"])))
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
				title = I18n.t("Призвать")
				reason = lg.can_recruit_resident()
			"forge": title = I18n.t("Ковать")
			"drill": title = I18n.t("Тренировать")
			"mars": title = I18n.t("Таланты")
			"store": title = I18n.t("Запасы")
			"infirmary": title = I18n.t("Лечить")
			"arsenal": title = I18n.t("Снаряжение")
			"hq":
				title = I18n.t("Расширить форт")
				reason = lg.fort_can_expand()
			_: title = I18n.t("Отряд")
	if selected != "hq" and lg.fort_worker(selected_plot).is_empty() and not running:
		title = I18n.t("Назначить")
		reason = ""
	if int(plot["lv"]) == 0 or running:
		reason = I18n.t("Здание строится.")
	main_action.text = title
	main_action.disabled = reason != ""
	main_action.tooltip_text = I18n.t(reason)
	main_action_reason.text = I18n.t(reason) if not running else ""
	main_action_reason.visible = main_action_reason.text != ""
	_refresh_costs(card_body)


func _upgrade() -> void:
	if not lg.fort_upgrade(selected_plot):
		hud.notify(I18n.t(lg.fort_can_upgrade(selected_plot)), "lock")
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
		var p := hud._panel(parent, "bar", 0, 8)
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
			_add_speed(v, "train_%d" % sid)
		else:
			var home := hud._round("housing", "Отпустить домой — снова станет жителем", 40, func(): lg.dismiss(sid); _refresh())
			row.add_child(home)


## Прямой призыв оставлен для прежних сценариев проверки.
func recruit() -> void:
	_recruit_pick({})


func open_recruit_picker() -> void:
	_worker_target = -1
	recruit_page = 0
	show_recruit_picker()


func show_recruit_picker() -> void:
	if hud.game.people != null:
		hud.game.people.sync_members()
	var target := _worker_target
	var v := _new_modal(570)
	_worker_target = target
	v.add_child(_text("Кого призвать?", 24, true))
	var candidates := lg.recruit_candidates(4, recruit_page)
	for candidate: Dictionary in candidates:
		var p := hud._panel(v, "bar", 0, 10)
		var row := HBoxContainer.new()
		p.add_child(row)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)
		details.add_child(_text(String(candidate["name"]), 18, true))
		details.add_child(_text(I18n.t(String(candidate["former"])), 14))
		details.add_child(_text("★".repeat(int(candidate["stars"])) + "☆".repeat(5 - int(candidate["stars"])), 18, true))
		var choose := _button("Призвать", func(): _recruit_pick(candidate), "legion")
		choose.disabled = lg.can_recruit_resident() != ""
		choose.tooltip_text = lg.can_recruit_resident()
		row.add_child(choose)
	if candidates.is_empty():
		v.add_child(_wrap(lg.can_recruit_resident()))
	v.add_child(_button("Других", func(): recruit_page += 1; show_recruit_picker()))
	v.add_child(_button("← Лагерь", _close_modal))
	_fit_modal.call_deferred()


func _recruit_pick(pick: Dictionary) -> void:
	var target := _worker_target
	var soldier := lg.recruit_resident(pick)
	if soldier.is_empty():
		hud.notify(lg.can_recruit_resident() if lg.can_recruit_resident() != "" else "Житель уже недоступен. Выберите другого.", "lock")
		show_recruit_picker()
		_refresh()
		return
	if target >= 0:
		if not lg.fort_assign(target, int(soldier["id"])):
			hud.notify(I18n.t("Не удалось назначить работника. Выберите его снова."), "lock")
		_close_modal()
		show_plot(target)
		_refresh()
		return
	if is_instance_valid(diorama):
		diorama.sync()
		diorama.recruit_walk(int(soldier["id"]))
	_refresh()
	var v := _new_modal(500)
	recruit_result = is_instance_valid(diorama)
	if recruit_result:
		var shade := modal.get_child(0) as ColorRect
		shade.color = Color(0.10, 0.06, 0.03, 0.12)
	v.add_child(_wrap(I18n.t("%s → новобранец %s") % [String(soldier.get("from", soldier["name"])), Soldiers.stars_text(int(soldier["stars"]))], 22))
	v.add_child(_wrap("В руках меч — Легионер. Дай лук — станет Лучником.", 17))
	v.add_child(_button("В отряд", show_squad, "shield"))
	v.add_child(_button("Закрыть", _close_modal))
	_fit_modal.call_deferred()


func _new_modal(width: float) -> VBoxContainer:
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
	modal_panel = hud._panel(modal, "scroll_v", 0, 20)
	modal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_panel.custom_minimum_size.x = width
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	modal_panel.add_child(v)
	return v


func _fit_modal() -> void:
	if not is_instance_valid(modal_panel):
		return
	modal_panel.reset_size()
	var dims := modal_panel.get_combined_minimum_size()
	var k := minf(1.0, minf((size.x - 24) / maxf(1, dims.x), (size.y - 24) / maxf(1, dims.y)))
	modal_panel.scale = Vector2.ONE * k
	modal_panel.position = (size - dims * k) * 0.5
	if _popup_resource != "":
		var bar: Control = resource_bars[_popup_resource]["panel"]
		var rect := bar.get_global_rect()
		modal_panel.position = Vector2(clampf(rect.position.x - global_position.x, 12, maxf(12, size.x - dims.x * k - 12)), rect.end.y - global_position.y + 8)
	if recruit_result:
		# Карточка справа оставляет путь от ворот к казарме на виду.
		modal_panel.position = Vector2(maxf(12, size.x - dims.x * k - 16), maxf(76, size.y - dims.y * k - 82))


func _close_modal() -> void:
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
				b.add_theme_stylebox_override("normal", hud._box_pill(16, 6, "g_btn_on"))
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
		var sid := int(s["id"])
		var soldier_row := HBoxContainer.new()
		roster.add_child(soldier_row)
		var b := _button(_soldier_title(s), func(): _assign(sid), String(CLASS_ICON.get(_class(s), "swords")))
		b.set_meta("quest_soldier", sid)
		b.disabled = selected_place < 0 or bool(s.get("hero", false))
		b.tooltip_text = "Сначала выберите пустое место." if selected_place < 0 else lu._soldier_status(s)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		soldier_row.add_child(b)
		soldier_row.add_child(hud._round("info", String(s["name"]), 40, func(): _show_soldier(sid)))
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


func _campaign() -> void:
	_guide_advance(3)
	_close_modal()
	_hide_card()
	lu.open("campaign")


func _aux(kind: String, sid := 0) -> void:
	_close_modal()
	_hide_card()
	lu.open_camp_window(kind, sid)


static func duration_text(seconds: float) -> String:
	var minutes := maxi(1, ceili(seconds / 60.0)) if seconds > 0.0 else 0
	if minutes >= 1440:
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
		var b := hud._round(String(RESOURCE_ICON[resource]), "", 48, func(): _collect(resource))
		if resource != "rations":
			(b.get_node("ic") as TextureRect).texture = lu._mat_tex(resource)
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
	if resource == "rations":
		_guide_advance(0)
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


func _add_speed(parent: VBoxContainer, key: String) -> void:
	var box := VBoxContainer.new()
	parent.add_child(box)
	var b := _button("", func(): lg.speed_up(key); _refresh())
	box.add_child(b)
	var quota := _text("", 13)
	box.add_child(quota)
	speed_widgets.append({"box": box, "button": b, "quota": quota, "key": key})
	_refresh_speeds()


func _refresh_speeds() -> void:
	speed_widgets = speed_widgets.filter(func(entry: Dictionary): return is_instance_valid(entry["box"]) and not entry["box"].is_queued_for_deletion())
	for entry: Dictionary in speed_widgets:
		var info := lg.speed_info(String(entry["key"]))
		(entry["box"] as Control).visible = float(info["left"]) > 0.0
		var b: Button = entry["button"]
		b.text = I18n.t("Ускорить: −%s за %d ден.") % [duration_text(minf(1800.0, minf(float(info["left"]), lg.speed_remaining()))), int(info["price"])]
		b.disabled = not bool(info["allowed"])
		(entry["quota"] as Label).text = I18n.t("сегодня ещё %s") % duration_text(lg.speed_remaining())


func show_hero() -> void:
	var v := _new_modal(560)
	hero_card_level = lg.hero_level()
	v.add_child(_text("♛ " + Hero.name_of(lg.city()), 26, true))
	v.add_child(_wrap("Первый воин Легиона. Герой остаётся с вами.", 16))
	v.add_child(_wrap("Снаряжение героя улучшает Склад.", 14))
	hero_status = _wrap("", 20)
	v.add_child(hero_status)
	hero_bar = lu._bar(0, 0)
	v.add_child(hero_bar)
	v.add_child(lu._cost_row(lg.hero_train_info()["cost"]))
	hero_train_button = _button("Тренировать героя", func(): lg.train_hero(); show_hero(), "laurels")
	v.add_child(hero_train_button)
	_add_speed(v, "hero")
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
	v.add_child(_wrap("Первая победа даёт сундук. За повторную: 15% за каждую звезду. Мест — 4.", 14))
	v.add_child(_wrap(Legion.CHEST_ODDS, 15))
	v.add_child(_wrap("Слитки: деревянный 2% · бронзовый 4% · золотой 6%. По 1–3 слитка.", 14))
	for kind: String in lg.chest_queue:
		var b := _button(I18n.t("Открыть: %s") % I18n.t(String(Legion.CHEST_NAMES[kind])), func(): show_chests(lg.open_chest(kind)); _refresh(), "coins")
		b.disabled = lg.store_count() >= lg.store_cap()
		b.tooltip_text = I18n.t("Освободите место для вещи на Складе.") if b.disabled else I18n.t("Открывается сразу.")
		v.add_child(b)
	if lg.chest_queue.is_empty():
		v.add_child(_wrap("Сундуки принесут победы в походах."))
	if not reward.is_empty():
		v.add_child(hud._divider(8))
		v.add_child(_wrap(I18n.t("Добыча: %d ден. · %d пайков · %d слитков") % [int(reward["money"]) - int(reward.get("money_lost", 0)), int(reward["rations"]), int(reward["ingots"])], 18))
		v.add_child(_wrap(I18n.t("Железо %d · Дерево %d · Кожа %d") % [int(reward["iron"]), int(reward["wood"]), int(reward["leather"])]))
		v.add_child(_wrap(Gear.name_of(reward["item"]), 18))
	v.add_child(_button("← Лагерь", _close_modal))
	_fit_modal.call_deferred()


func _show_soldier(sid: int) -> void:
	if bool(lg.soldier(sid).get("hero", false)):
		show_hero()
	else:
		_aux("soldier", sid)


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
		cutaway_markers = Control.new()
		cutaway_markers.name = "CutawayMarkers"
		cutaway_markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cutaway_markers)
		move_child(cutaway_markers, 2)
		_plots_sig = ""
	diorama.building_pressed.connect(show_building)
	diorama.view_changed.connect(_layout)
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


func _screen_anchor(center: Vector2, dims: Vector2) -> Vector2:
	return Vector2(clampf(center.x - dims.x * 0.5, 8, maxf(8, size.x - dims.x - 8)),
		clampf(center.y - dims.y * 0.5, 76, maxf(76, size.y - dims.y - 82)))


func _prepare_guide() -> void:
	if lg.flags.has("camp3d_guide"):
		return
	lg.flags["camp3d_guide"] = 0
	# Переложить часть стартового запаса в пузырь: первый сбор без ожидания.
	# Сумма запасов сохраняется, подарка сверх лимита нет.
	var pending := float(lg.pending_resources.get("rations", 0.0))
	var cap := float(lg.ration_cap())
	if lg.rations >= cap and pending >= cap:
		# В старом сохранении оба запаса уже полны: незачем учить сбору.
		lg.flags["camp3d_guide"] = 1
		return
	if pending < 1.0 or lg.rations >= lg.ration_cap():
		var sample := minf(3.0, minf(floorf(lg.rations), maxf(0.0, cap - pending)))
		lg.rations -= sample
		lg.pending_resources["rations"] = pending + sample
	if float(lg.pending_resources.get("rations", 0.0)) < 1.0:
		lg.flags["camp3d_guide"] = 1


func _guide_advance(expected: int) -> void:
	if int(lg.flags.get("camp3d_guide", 0)) == expected:
		lg.flags["camp3d_guide"] = expected + 1
		lg.changed.emit()
		_layout_guide()


func _layout_guide() -> void:
	if guide == null:
		return
	if is_instance_valid(_guide_target):
		_guide_target.modulate = Color.WHITE
	_guide_target = null
	var step := int(lg.flags.get("camp3d_guide", 4))
	guide.visible = visible and step < 4 and not is_instance_valid(card) and lu.camp_window == ""
	if is_instance_valid(modal) and not is_instance_valid(build_scroll):
		guide.hide()
	if not guide.visible:
		return
	var target: Control
	var tip := ""
	match step:
		0:
			target = bubbles["rations"]["button"]
			for id: int in plot_markers:
				var plot := lg.fort_plot(id)
				if plot["b"] == "kitchen" and float(plot["pend"]) >= 1.0:
					target = plot_markers[id]["collect"]
					break
			tip = "Соберите пайки"
		1:
			target = build_button
			tip = "Откройте стройку"
		2:
			target = build_cards.get("kitchen", {}).get("button", build_button)
			tip = "Постройте полевую кухню" if lg.fort_count("kitchen") == 0 else "Откройте полевую кухню"
		3:
			target = campaign_button
			tip = "В поход!"
	if target == null or not target.is_visible_in_tree():
		guide.hide()
		return
	_guide_target = target
	guide_text.text = I18n.t(tip) + " ↓"
	guide.reset_size()
	var k := minf(1.0, size.y / 720.0)
	guide.scale = Vector2.ONE * k
	var rect := target.get_global_rect()
	guide.position = _screen_anchor(rect.position - global_position + Vector2(rect.size.x * 0.5, -28 * k), guide.size * k)
	guide.move_to_front()


func _stock(resource: String) -> float:
	if resource == "money":
		return lg.city_money()
	if resource == "glory":
		return lg.glory
	if resource == "ingots":
		return float(lg.ingots)
	return lg.rations if resource == "rations" else float(lg.mats.get(resource, 0.0))


func _cost_icons(cost: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	var amounts: Dictionary = cost.get("mats", {}).duplicate()
	for resource: String in ["money", "glory"]:
		if float(cost.get(resource, 0)) > 0:
			amounts[resource] = cost[resource]
	var labels := {}
	for resource: String in ["money", "glory", "iron", "wood", "leather"]:
		var amount := int(amounts.get(resource, 0))
		if amount <= 0:
			continue
		var pair := HBoxContainer.new()
		row.add_child(pair)
		pair.add_child(hud._icon(String(TOP_ICONS[resource]), 22) if TOP_ICONS.has(resource) else lu._tr(lu._mat_tex(resource), 22))
		var number := _text(hud.fmt(amount), 14, true)
		pair.add_child(number)
		labels[resource] = number
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
	heading.add_child(hud._icon(String(TOP_ICONS[resource]), 38))
	var title := _text(I18n.t(String(TOP_NAMES[resource])), 24, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	heading.add_child(_button("×", _close_modal))
	v.add_child(_wrap(I18n.t(String(TOP_TIPS[resource])), 16))
	match resource:
		"rations": v.add_child(_button("К полевой кухне", func(): _jump_to_type("kitchen"), "bread"))
		"ingots": v.add_child(_button("К Сокровищнице", func(): _jump_to_type("treasury"), "coins"))
		"money": v.add_child(_button("В город", close, "housing"))
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
	build_plot_id = plot_id if plot_id >= 0 else lg.fort_empty_plot()
	_guide_advance(1)
	var v := _new_modal(minf(1020, maxf(700, size.x - 100)))
	modal_panel.name = "FortBuildMenu"
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := _text(I18n.t("Строить"), 26, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_button("×", _close_modal))
	var free := 0
	for plot: Dictionary in lg.fort.get("plots", []):
		if plot["b"] == "":
			free += 1
	v.add_child(_text(I18n.t("Свободных участков: %d") % free, 15))
	if free == 0:
		v.add_child(_button("К Штабу: расширить форт", func(): show_building("hq"), "castle"))
	build_scroll = ScrollContainer.new()
	build_scroll.name = "FortBuildScroll"
	build_scroll.custom_minimum_size = Vector2(660, 300)
	build_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(build_scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	build_scroll.add_child(row)
	for type: String in Legion.FORT_B:
		if type == "hq":
			continue
		var spec: Dictionary = Legion.FORT_B[type]
		var panel := hud._panel(row, "bar", 0, 12)
		panel.custom_minimum_size = Vector2(224, 270)
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 7)
		panel.add_child(body)
		var picture := _room_icon(type, 64)
		picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		body.add_child(picture)
		var title_label := _text(I18n.t(String(spec["name"])), 18, true)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(title_label)
		var gives := _wrap(I18n.t(String(spec["gives"])), 14)
		gives.custom_minimum_size = Vector2(196, 38)
		body.add_child(gives)
		body.add_child(_cost_icons(Legion.fort_cost(type, 1)))
		body.add_child(_text(duration_text(Legion.camp_time_h(1) * float(spec["time_k"]) * 3600.0 / maxf(0.001, lg.time_k)), 13))
		var count := _text("", 14, true)
		body.add_child(count)
		var button := _button("Строить", func(): _choose_build(type), "hammer")
		button.name = "Build_" + type
		body.add_child(button)
		var reason := _wrap("", 12)
		reason.custom_minimum_size.x = 196
		body.add_child(reason)
		build_cards[type] = {"panel": panel, "button": button, "count": count, "reason": reason, "picture": picture}
	_build_sig = _plot_signature()
	_refresh_build_menu()
	_fit_modal.call_deferred()
	_focus_build_card.call_deferred()


func _focus_build_card() -> void:
	var type := build_focus
	build_focus = ""
	if type == "" and int(lg.flags.get("camp3d_guide", 4)) == 2:
		type = "kitchen"
	if is_instance_valid(build_scroll) and build_cards.has(type):
		build_scroll.ensure_control_visible(build_cards[type]["button"])
	_layout_guide()


func _refresh_build_menu() -> void:
	if _build_sig != _plot_signature():
		var previous := build_scroll.scroll_horizontal
		show_build_menu(build_plot_id)
		build_scroll.set_deferred("scroll_horizontal", previous)
		return
	for type: String in build_cards:
		var entry: Dictionary = build_cards[type]
		var cap := lg.fort_max(type)
		var count := lg.fort_count(type)
		var why := lg.fort_can_build(type, build_plot_id if build_plot_id >= 0 else lg.fort_empty_plot())
		(entry["count"] as Label).text = "%d / %d" % [count, cap]
		var button: Button = entry["button"]
		button.text = I18n.t("Строить")
		button.disabled = why != ""
		if cap == 0:
			why = I18n.t("Штаб ур. %d") % int(Legion.FORT_B[type]["max"][0])
			button.text = why
		# Уже построенная кухня остаётся доступной в обучении и после миграции.
		if type == "kitchen" and count > 0 and int(lg.flags.get("camp3d_guide", 4)) == 2:
			button.text = I18n.t("Открыть")
			button.disabled = false
			why = ""
		button.tooltip_text = I18n.t(why)
		(entry["reason"] as Label).text = I18n.t(why)
		(entry["picture"] as Control).modulate = Color(0.55, 0.55, 0.55) if cap == 0 else Color.WHITE
		_refresh_costs(entry["panel"])


func _choose_build(type: String) -> void:
	if type == "kitchen" and lg.fort_count(type) > 0 and int(lg.flags.get("camp3d_guide", 4)) == 2:
		_guide_advance(2)
		_jump_to_type(type)
		return
	var id := build_plot_id if build_plot_id >= 0 else lg.fort_empty_plot()
	if not lg.fort_build(type, id):
		hud.notify(I18n.t(lg.fort_can_build(type, id)), "lock")
		_refresh_build_menu()
		return
	if type == "kitchen":
		_guide_advance(2)
	build_plot_id = -1
	show_plot(id)
	_refresh()


func _main_action() -> void:
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
		"barracks": open_recruit_picker()
		"forge", "mars": _aux(selected)
		"store": show_stocks()
		"arsenal": _aux("store")
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
	var button := hud._round(String(FORT_ICON[type]), I18n.t(String(Legion.FORT_B[type]["name"])), 56, func():
		var id := int(panel.get_meta("plot"))
		if id >= 0:
			show_plot(id)
		else:
			show_building(String(panel.get_meta("slot"))))
	panel.add_child(button)
	button.position = Vector2(6, 58)
	var level := _text("", 13, true)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f4ebd6")
	style.set_corner_radius_all(8)
	style.content_margin_left = 5
	style.content_margin_right = 5
	level.add_theme_stylebox_override("normal", style)
	button.add_child(level)
	level.position = Vector2(38, 38)
	var alert := _badge(button)
	var collect := hud._round("bread", "", 48, func(): _collect_plot(int(panel.get_meta("plot"))))
	panel.add_child(collect)
	collect.position = Vector2(10, 4)
	var ring := Ring.new()
	collect.add_child(ring)
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var timer := Ring.new()
	button.add_child(timer)
	timer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return {"panel": panel, "button": button, "title": level, "state": alert, "collect": collect, "ring": ring, "timer": timer}


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
	var timer: Dictionary = plot["up"]
	if type == "hq" and timer.is_empty():
		timer = lg.fort.get("up", {})
	(marker["timer"] as Control).visible = not timer.is_empty()
	if not timer.is_empty():
		var left := maxf(0, float(timer["end"]) - Legion.now())
		marker["timer"].set("value", 1.0 - left / maxf(1.0, float(timer["total"])))
		button.tooltip_text += " · " + clock_text(left)
	var prod := Legion.fort_production(type, level)
	var collect: Button = marker["collect"]
	collect.visible = not prod.is_empty() and float(plot["pend"]) >= 0.9999
	var idle := false
	if not prod.is_empty():
		var resource := String(prod["resource"])
		(collect.get_node("ic") as TextureRect).texture = hud.ico(String(TOP_ICONS[resource]), 48) if TOP_ICONS.has(resource) else lu._mat_tex(resource)
		collect.tooltip_text = I18n.t("Собрать %d") % floori(float(plot["pend"]) + 0.0001)
		collect.disabled = _stock(resource) >= lg.resource_cap(resource)
		if collect.disabled:
			collect.tooltip_text += "\n" + I18n.t("Запас полон. Потратьте ресурсы, чтобы собрать ещё.")
		marker["ring"].set("value", float(plot["pend"]) / maxf(1.0, float(prod["cap"])))
		idle = float(plot["pend"]) >= float(prod["cap"]) - 0.001
	elif type == "drill" and level > 0:
		idle = true
		for soldier: Dictionary in lg.soldiers:
			if lg.s_state(soldier) == "train" and int(soldier.get("train_plot", -1)) == int(plot["id"]):
				idle = false
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
	var prod := Legion.fort_production(String(plot["b"]), int(plot["lv"]))
	if prod.is_empty():
		return
	if origin == Vector2.INF:
		origin = (plot_markers[plot_id]["collect"] as Control).global_position if plot_markers.has(plot_id) else global_position + size * 0.5
	var amount := lg.fort_collect(plot_id)
	if amount <= 0:
		return
	var resource := String(prod["resource"])
	if resource == "rations":
		_guide_advance(0)
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
	var worker: Dictionary = lg.fort_worker(selected_plot)
	if selected == "hq":
		for person: Dictionary in lg.soldiers:
			if bool(person.get("hero", false)):
				worker = person
				break
	var row := HBoxContainer.new()
	row.name = "FortWorker"
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	if not worker.is_empty():
		row.add_child(lu._portrait("unit", Legion.unit_of_class(String(worker.get("cls", "legionary"))), 46))
	var name_label := _text(String(worker.get("name", I18n.t("Нет работника"))), 17, true)
	name_label.name = "FortWorkerName"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)
	if selected != "hq" and not worker.is_empty():
		row.add_child(_button("Сменить работника", show_worker_picker))
		row.add_child(_button("Освободить", func(): lg.fort_assign(selected_plot, 0); _refresh()))


func show_worker_picker() -> void:
	var target := selected_plot
	var v := _new_modal(540)
	modal_panel.name = "FortWorkerPicker"
	v.add_child(_text("Кто будет работать?", 24, true))
	var choices: Array[Dictionary] = lg.fort_worker_choices()
	if choices.is_empty():
		v.add_child(_wrap("Свободных людей нет. Призовите жителя или освободите воина из отряда."))
	for person: Dictionary in choices:
		var row := HBoxContainer.new()
		v.add_child(row)
		row.add_child(lu._portrait("unit", Legion.unit_of_class(String(person["cls"])), 46))
		var sid := int(person["id"])
		var button := _button(String(person["name"]), func():
			if lg.fort_assign(target, sid):
				_close_modal()
				show_plot(target)
				_refresh())
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
	var recruit_worker := _button("Призвать из города", func():
		recruit_page = 0
		_worker_target = target
		show_recruit_picker(), "legion")
	recruit_worker.disabled = lg.can_recruit_resident() != ""
	recruit_worker.tooltip_text = I18n.t(lg.can_recruit_resident())
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
			cutaway_markers.add_child(marker["panel"])
			var button: Button = marker["button"]
			button.name = "RoomButton_%d" % id
			if type == "":
				(button.get_node("ic") as Control).hide()
				button.text = "+"
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


func _layout_cutaway_markers(k: float) -> void:
	extra_plots.hide()
	for marker: Dictionary in plaques.values():
		(marker["panel"] as Control).hide()
	for id: int in plot_markers:
		var marker: Dictionary = plot_markers[id]
		var panel: Control = marker["panel"]
		var empty := String(lg.fort_plot(id)["b"]) == ""
		var center: Vector2 = diorama.project(id, 0.0 if empty else 1.0)
		panel.scale = Vector2.ONE * k * 0.85
		panel.position = center - Vector2(34, 86 if empty else 58) * panel.scale
		panel.visible = diorama.footprint("plot_%d" % id).intersects(Rect2(Vector2(0, 100), size - Vector2(0, 160)))
	# Городские буферы отделены от комнат: компактный ряд у нижней панели.
	var index := 0
	for resource: String in bubbles:
		var box: Control = bubbles[resource]["box"]
		box.position = Vector2(170 + index * 54, size.y - 62)
		index += 1
