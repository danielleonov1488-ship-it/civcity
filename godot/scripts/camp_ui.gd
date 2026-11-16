class_name CampUI
extends Control
## Лагерь V3: плашки следуют зданиям, окна — размеру экрана.

const USE_3D := true
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
	top_button = _button("Лагерь", func(): toggle(), "tent")
	hud.top_panel.add_child(top_button)
	hud.top_panel.move_child(top_button, 0)
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
	if top_button.visible != on:
		top_button.visible = on
		hud._fit_top.call_deferred()
	if visible and not on:
		close()
	if on and not lg.flags.has("camp_told"):
		_camp_moment.call_deferred()


## Лагерь открылся (50 жителей): один раз — спокойная карточка советника, стрелка и кивок кнопки «Лагерь».
## Занят советник или идёт ролик — подождём следующего обновления
func _camp_moment() -> void:
	if lg.flags.has("camp_told") or top_button == null or not top_button.visible or visible:
		return
	var rig = hud.game.get("rig")
	if hud.advisor_panel.visible or hud.game.tool != "" or (rig != null and rig.cine) or not hud.game.stories.cine.is_empty():
		return
	lg.flags["camp_told"] = true
	hud.advisor("Лагерь открыт", "Призывайте жителей в Легион — кнопка «Лагерь» наверху.", Callable(), false, true)   # маленькая карточка в углу, не мешает
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
		hit.focus_mode = Control.FOCUS_NONE
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hit.tooltip_text = String(Legion.CAMP_NAME[slot])
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(1, 0.93, 0.65, 0)
		normal.set_corner_radius_all(28)
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color.a = 0.17
		hover.border_color = Color(1, 0.88, 0.55, 0.4)
		hover.set_border_width_all(2)
		hit.add_theme_stylebox_override("normal", normal)
		hit.add_theme_stylebox_override("hover", hover)
		hit.add_theme_stylebox_override("pressed", hover)
		hit.pressed.connect(func(): show_building(slot))
		add_child(hit)
		hotspots[slot] = hit
		var p := hud._panel(self, "bar", 0, 9)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 1)
		p.add_child(v)
		var title := _text("", 16, true)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(title)
		var state := _text("", 13)
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(state)
		var bar := lu._bar(150, 0)
		bar.custom_minimum_size.y = 6
		v.add_child(bar)
		plaques[slot] = {"panel": p, "title": title, "state": state, "bar": bar}
		# Плашка тоже нажимается, но не закрывает здание.
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		p.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				show_building(slot)
				p.accept_event())
		p.mouse_entered.connect(func(): hit.add_theme_stylebox_override("normal", hover))
		p.mouse_exited.connect(func(): hit.add_theme_stylebox_override("normal", normal))
		p.mouse_entered.connect(func():
			if is_instance_valid(diorama):
				diorama.highlight(slot))
		p.mouse_exited.connect(func():
			if is_instance_valid(diorama):
				diorama.highlight(""))
	gate = _button("Поход", _campaign, "scroll")
	add_child(gate)
	chips = HBoxContainer.new()
	chips.add_theme_constant_override("separation", 10)
	add_child(chips)
	ration_label = _chip("bread")
	glory_label = _chip("laurels")
	resource_chips["rations"] = ration_label
	for resource: String in ["iron", "wood", "leather"]:
		resource_chips[resource] = _chip(String(RESOURCE_ICON[resource]), resource)
	mats_label = resource_chips["iron"]
	ingot_label = _chip("coins")
	(ingot_label.get_parent().get_parent() as Control).tooltip_text = I18n.t("Золотые слитки — редкая награда. Пригодятся позже.")
	chest_button = _button("Сундуки", show_chests, "coins")
	chips.add_child(chest_button)
	_build_bubbles()
	daily_button = _button("Сундук дня", func(): _aux("daily"), "coins")
	chips.add_child(daily_button)
	exit_button = _button("×", close)
	exit_button.tooltip_text = "Закрыть"
	exit_button.custom_minimum_size = Vector2(44, 44)
	add_child(exit_button)
	bottom = HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	add_child(bottom)
	bottom.add_child(_button("Отряд", show_squad, "shield"))
	bottom.add_child(_button("Поход", _campaign, "scroll"))
	var arena := _button("Арена — скоро", func(): pass)
	arena.disabled = true
	arena.tooltip_text = "Бои с другими игроками откроются позже."
	bottom.add_child(arena)
	for b: Button in bottom.get_children():
		b.custom_minimum_size = Vector2(180, 48)
	guide = hud._panel(self, "bar", 0, 10)
	guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide_text = _text("", 18, true)
	guide_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide.add_child(guide_text)
	guide.hide()


func _chip(icon: String, resource := "") -> Label:
	var p := hud._panel(chips, "bar", 0, 10)
	var row := HBoxContainer.new()
	p.add_child(row)
	row.add_child(lu._tr(lu._mat_tex(resource), 24) if resource != "" else hud._icon(icon, 24))
	var l := _text("", 16, true)
	row.add_child(l)
	return l


func _layout() -> void:
	if chips == null or size.x < 1.0:
		return
	var cover := maxf(size.x / IMAGE_SIZE.x, size.y / IMAGE_SIZE.y)
	image_rect = Rect2((size - IMAGE_SIZE * cover) * 0.5, IMAGE_SIZE * cover)
	var ui_scale := minf(1.0, minf(size.x / 1000.0, size.y / 680.0))
	for slot: String in Legion.CAMP_SLOTS:
		var hit: Button = hotspots[slot]
		hit.size = image_rect.size * Vector2(0.16, 0.14)
		hit.position = image_rect.position + image_rect.size * Vector2(CENTRES[slot]) - hit.size * 0.5
		var p: PanelContainer = plaques[slot]["panel"]
		p.reset_size()
		p.scale = Vector2.ONE * ui_scale
		p.position = image_rect.position + image_rect.size * Vector2(PLAQUES[slot]) - p.size * ui_scale * 0.5
		if is_instance_valid(diorama):
			hit.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hit.visible = false
			var footprint := diorama.footprint(slot)
			hit.position = footprint.position
			hit.size = footprint.size
			p.position = _screen_anchor(diorama.project(slot, 6.0), p.size * ui_scale)
		else:
			hit.visible = true
			hit.mouse_filter = Control.MOUSE_FILTER_STOP
	_layout_bubbles(ui_scale)
	chips.reset_size()
	var ck := minf(ui_scale, (size.x - 110.0) / maxf(1.0, chips.size.x))
	chips.scale = Vector2.ONE * ck
	chips.position = Vector2((size.x - chips.size.x * ck) * 0.5, 14)
	exit_button.position = Vector2(size.x - 56, 10)
	bottom.reset_size()
	bottom.scale = Vector2.ONE * ui_scale
	bottom.position = Vector2((size.x - bottom.size.x * ui_scale) * 0.5, size.y - 64 * ui_scale)
	gate.reset_size()
	gate.scale = Vector2.ONE * ui_scale
	gate.position = image_rect.position + image_rect.size * Vector2(0.49, 0.89) - gate.size * ui_scale * 0.5
	if is_instance_valid(diorama):
		gate.position = _screen_anchor(diorama.project("gate", 1.5), gate.size * ui_scale)
	# Ворота и нижняя полоса не перекрывают друг друга.
	gate.visible = gate.position.y + gate.size.y * ui_scale < bottom.position.y - 4
	if is_instance_valid(card):
		card.scale = Vector2.ONE * ui_scale
		card.size = Vector2(420, maxf(220, (size.y - 155) / ui_scale))
		card.position = Vector2(size.x - 16 - 420 * ui_scale, 74)
	_fit_modal()
	_layout_guide()


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
	return str([entries, lg.squad3, lg.camp, lg.upg.keys(), lg.hero_level(), lg.hero_training.is_empty(), lg.forging.is_empty()])


func _refresh() -> void:
	if is_instance_valid(diorama):
		diorama.sync()
	ration_label.text = I18n.t("Пайки %d / %d") % [lg.rations_now(), lg.ration_cap()]
	glory_label.text = I18n.t("Слава %d") % int(lg.glory)
	for resource: String in resource_chips:
		var label: Label = resource_chips[resource]
		if resource != "rations":
			label.text = "%s %d" % [I18n.t(String(RESOURCE_NAME[resource])), lg.mat(resource)]
		(label.get_parent().get_parent() as Control).tooltip_text = _resource_tip(resource)
	ingot_label.text = I18n.t("Слитки %d") % lg.ingots
	(glory_label.get_parent().get_parent() as Control).tooltip_text = I18n.t("Слава — за победы. Нужна для умений и тренировки героя.")
	chest_button.text = I18n.t("Сундуки %d / 4") % lg.chest_queue.size()
	_refresh_bubbles()
	_refresh_hero()
	_refresh_speeds()
	var daily_state := "✓" if bool(lg.daily.get("opened", false)) else ("!" if lg.can_open_daily() == "" else "%d/%d" % [lg.daily_done(), lg.daily_tasks().size()])
	daily_button.text = I18n.t("Сундук дня") + " · " + daily_state
	for slot: String in Legion.CAMP_SLOTS:
		var p: Dictionary = plaques[slot]
		(p["title"] as Label).text = I18n.t("%s · ур. %d") % [I18n.t(String(Legion.CAMP_NAME[slot])), lg.camp_level(slot)]
		var running := lg.upg.has("camp_" + slot)
		var state: Label = p["state"]
		state.text = duration_text(lg.camp_left(slot)) if running else (I18n.t("Штаб ур. %d") % int(Legion.CAMP_HQ_NEED.get(slot, 1)) if not lg.camp_built(slot) else "")
		state.visible = state.text != ""
		var bar: ProgressBar = p["bar"]
		bar.visible = running
		bar.value = lg.camp_progress(slot) if running else 0.0
		var title: Label = p["title"]
		title.add_theme_color_override("font_color", LegionUi.C_SOFT if not lg.camp_built(slot) else LegionUi.C_INK)
		if not lg.camp_built(slot) and not running:
			state.text = "🔒 " + state.text
			(p["title"] as Label).text = I18n.t("Построить: %s") % I18n.t(String(Legion.CAMP_NAME[slot]))
	var sig := _roster_signature()
	if selected != "":
		if sig != _card_sig:
			_build_card()
		_refresh_card()
	if is_instance_valid(squad_body) and sig != _squad_sig:
		_build_squad()
	_layout()


func show_building(slot: String) -> void:
	if not Legion.CAMP_SLOTS.has(slot):
		return
	_close_modal()
	_hide_card()
	selected = slot
	card = hud._panel(self, "panel", 0, 18)
	card_scroll = ScrollContainer.new()
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(card_scroll)
	card_body = VBoxContainer.new()
	card_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_body.add_theme_constant_override("separation", 10)
	card_scroll.add_child(card_body)
	_build_card()
	_refresh_card()
	_layout()


func _hide_card() -> void:
	if is_instance_valid(card):
		card.hide()
		card.queue_free()
	card = null
	selected = ""
	_training.clear()


func _clear(control: Control) -> void:
	for child in control.get_children():
		control.remove_child(child)
		child.queue_free()


func _build_card() -> void:
	var scroll := card_scroll.scroll_vertical
	_clear(card_body)
	_training.clear()
	recruit_button = null
	recruit_reason = null
	roster_label = null
	_card_sig = _roster_signature()
	var head := HBoxContainer.new()
	card_level = _text("", 22, true)
	card_level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(card_level)
	head.add_child(_button("×", _hide_card))
	card_body.add_child(head)
	card_body.add_child(_wrap(String(EFFECTS[selected])))
	upgrade_timer = _text("", 18, true)
	card_body.add_child(upgrade_timer)
	upgrade_bar = lu._bar(0, 0)
	card_body.add_child(upgrade_bar)
	var info := lg.camp_info(selected)
	if not bool(info["max"]):
		card_body.add_child(lu._cost_row(info["cost"]))
		card_body.add_child(_text(I18n.t("Время: %s") % duration_text(float(info["time"])), 14))
	upgrade_button = _button("Улучшить" if lg.camp_built(selected) else "Построить", _upgrade, "hammer")
	card_body.add_child(upgrade_button)
	upgrade_reason = _wrap("", 13)
	card_body.add_child(upgrade_reason)
	_add_speed(card_body, "camp_" + selected)
	card_body.add_child(hud._divider(12))
	match selected:
		"hq":
			var need := int(Legion.PRIN_CITY[mini(int(info["to"]), Legion.PRIN_CITY.size() - 1)])
			card_body.add_child(_wrap(I18n.t("Следующий уровень Штаба: город «%s».") % I18n.t(String(Defs.LEVELS[need]["name"]))))
		"barracks":
			recruit_button = _button("Призвать", open_recruit_picker, "legion")
			recruit_button.custom_minimum_size.y = 54
			card_body.add_child(recruit_button)
			recruit_reason = _wrap("", 13)
			card_body.add_child(recruit_reason)
			roster_label = _text("", 16, true)
			card_body.add_child(roster_label)
			_roster(card_body, false)
		"drill":
			card_body.add_child(_wrap(I18n.t("Мест тренировки: %d") % lg.train_places()))
			_roster(card_body, true)
		"forge", "store", "mars":
			if selected == "store":
				card_body.add_child(_button("Сундуки", show_chests, "coins"))
			if selected == "forge" and not lg.forging.is_empty():
				card_body.add_child(_wrap(I18n.t("Ковка · ур. %d · %s") % [int(lg.forging["ilvl"]), duration_text(lg.forge_left())]))
				_add_speed(card_body, "forge")
			var text := {"forge": "Кузница", "store": "Склад", "mars": "Умения в бою"}
			var slot := selected
			var action := _button(String(text[slot]), func(): _aux(slot))
			action.disabled = not lg.camp_built(slot)
			action.tooltip_text = "Сначала постройте здание." if action.disabled else ""
			card_body.add_child(action)
	card_scroll.set_deferred("scroll_vertical", scroll)


func _refresh_card() -> void:
	card_level.text = I18n.t("%s · ур. %d") % [I18n.t(String(Legion.CAMP_NAME[selected])), lg.camp_level(selected)]
	var running := lg.upg.has("camp_" + selected)
	upgrade_timer.visible = running
	upgrade_timer.text = I18n.t("ур. %d → %d · %s") % [lg.camp_level(selected), lg.camp_level(selected) + 1, duration_text(lg.camp_left(selected))]
	upgrade_bar.visible = running
	upgrade_bar.value = lg.camp_progress(selected) if running else 0.0
	var why := lg.camp_can_upgrade(selected)
	upgrade_button.visible = not running
	upgrade_button.disabled = why != ""
	upgrade_button.tooltip_text = why
	upgrade_reason.text = why if not running else ""
	upgrade_reason.visible = upgrade_reason.text != ""
	if recruit_button != null:
		why = lg.can_recruit_resident()
		recruit_button.disabled = why != ""
		recruit_button.tooltip_text = why
		recruit_reason.text = why
		recruit_reason.visible = why != ""
		roster_label.text = I18n.t("Воинов %d / %d") % [lg.soldiers.size(), lg.roster_cap()]
	for entry: Dictionary in _training:
		var s := lg.soldier(int(entry["id"]))
		var status: Label = entry["status"]
		status.text = lu._soldier_status(s)
		var button: Button = entry["button"]
		why = lg.can_train(int(entry["id"]))
		# В V3 места тренировки даёт Плац.
		if why.begins_with("Все места тренировки заняты"):
			why = I18n.t("Все места заняты. Улучшите Плац.")
		button.disabled = why != ""
		button.tooltip_text = why
		var bar: ProgressBar = entry["bar"]
		bar.visible = lg.s_state(s) == "train"
		bar.value = lg.train_progress(s) if bar.visible else 0.0


func _upgrade() -> void:
	if not lg.camp_upgrade(selected):
		hud.notify(lg.camp_can_upgrade(selected), "lock")
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
	recruit_page = 0
	show_recruit_picker()


func show_recruit_picker() -> void:
	if hud.game.people != null:
		hud.game.people.sync_members()
	var v := _new_modal(570)
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
	var soldier := lg.recruit_resident(pick)
	if soldier.is_empty():
		hud.notify(lg.can_recruit_resident() if lg.can_recruit_resident() != "" else "Житель уже недоступен. Выберите другого.", "lock")
		show_recruit_picker()
		_refresh()
		return
	_guide_advance(1)
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
	_close_modal()
	modal = Control.new()
	add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.10, 0.06, 0.03, 0.48)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_panel = hud._panel(modal, "scroll_v", 0, 20)
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
	if recruit_result:
		# Карточка справа оставляет путь от ворот к казарме на виду.
		modal_panel.position = Vector2(maxf(12, size.x - dims.x * k - 16), maxf(76, size.y - dims.y * k - 82))


func _close_modal() -> void:
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
		var b := _button(_soldier_title(s), func(): _assign(sid), String(CLASS_ICON.get(_class(s), "swords")))
		b.disabled = selected_place < 0 or bool(s.get("hero", false))
		b.tooltip_text = "Сначала выберите пустое место." if selected_place < 0 else lu._soldier_status(s)
		roster.add_child(b)
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
		if not bool(lg.soldier(sid).get("hero", false)):
			_guide_advance(2)
		selected_place = -1
		_build_squad()


func _campaign() -> void:
	_guide_advance(3)
	lu.open("campaign")


func _aux(kind: String, sid := 0) -> void:
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
	for resource: String in ["rations", "iron", "wood", "leather"]:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		add_child(box)
		var b := _button("", func(): _collect(resource), String(RESOURCE_ICON[resource]))
		if resource != "rations":
			b.icon = lu._mat_tex(resource)
		b.name = "Collect_" + resource
		b.custom_minimum_size = Vector2(98, 42)
		box.add_child(b)
		var bar := lu._bar(98, 0)
		bar.custom_minimum_size.y = 7
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(bar)
		bubbles[resource] = {"box": box, "button": b, "bar": bar}


func _layout_bubbles(k: float) -> void:
	for resource: String in bubbles:
		var box: VBoxContainer = bubbles[resource]["box"]
		box.reset_size()
		box.scale = Vector2.ONE * k
		var anchor := Vector2(0.50, 0.32) if resource == "rations" else Vector2(0.75, 0.76)
		var shift := 0.0 if resource == "rations" else float(["iron", "wood", "leather"].find(resource) - 1) * 106.0 * k
		box.position = image_rect.position + image_rect.size * anchor - box.size * k * 0.5 + Vector2(shift, 0)
		if is_instance_valid(diorama):
			var slot := "hq" if resource == "rations" else "store"
			box.position = _screen_anchor(diorama.project(slot, 1.5) + Vector2(shift, 38 * k), box.size * k)


func _refresh_bubbles() -> void:
	for resource: String in bubbles:
		var amount := float(lg.pending_resources.get(resource, 0.0))
		var cap := lg.resource_cap(resource)
		var b: Button = bubbles[resource]["button"]
		b.text = "%d / %d" % [floori(amount + 0.0001), cap]
		var stock := lg.rations if resource == "rations" else float(lg.mats.get(resource, 0.0))
		b.disabled = amount < 0.9999 or stock >= cap
		b.tooltip_text = _resource_tip(resource) + "\n" + I18n.t("Нажмите, чтобы собрать.")
		if stock >= cap:
			b.tooltip_text += "\n" + I18n.t("Запас полон. Потратьте ресурсы, чтобы собрать ещё.")
		(bubbles[resource]["bar"] as ProgressBar).value = amount / maxf(1.0, cap)


func _collect(resource: String) -> void:
	var amount := lg.collect_resource(resource)
	if amount <= 0:
		return
	if resource == "rations":
		_guide_advance(0)
	var fly := _text("+%d" % amount, 25, true)
	fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fly)
	var source: Button = bubbles[resource]["button"]
	var target: Label = resource_chips[resource]
	fly.global_position = source.global_position
	var tween := create_tween().set_parallel(true)
	_collection_fx = _collection_fx.filter(func(entry: Dictionary): return is_instance_valid(entry["label"]))
	_collection_fx.append({"tween": tween, "label": fly})
	tween.tween_property(fly, "global_position", target.global_position, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(fly, "modulate:a", 0.0, 0.25).set_delay(0.45)
	tween.chain().tween_callback(fly.queue_free)
	_refresh()


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
	var scene := Camp3D.new()
	add_child(scene)
	move_child(scene, 1)
	if not scene.setup(lg, hud.game):
		scene.shutdown()
		scene.queue_free()
		background.show()
		return
	diorama = scene
	diorama.building_pressed.connect(show_building)
	diorama.view_changed.connect(_layout)
	background.hide()


func _stop_diorama() -> void:
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
	guide.visible = visible and step < 4 and not is_instance_valid(modal) and not is_instance_valid(card) and lu.camp_window == ""
	if not guide.visible:
		return
	var target: Control
	var tip := ""
	match step:
		0:
			target = bubbles["rations"]["button"]
			tip = "Соберите пайки"
		1:
			target = plaques["barracks"]["panel"]
			tip = "Призовите воина"
		2:
			target = bottom.get_child(0) as Control
			tip = "Поставьте его в строй"
		3:
			target = gate if gate.visible else bottom.get_child(1) as Control
			tip = "В поход!"
	if target == null:
		return
	_guide_target = target
	guide_text.text = I18n.t(tip) + " ↓"
	guide.reset_size()
	var k := minf(1.0, size.y / 720.0)
	guide.scale = Vector2.ONE * k
	var rect := target.get_global_rect()
	guide.position = _screen_anchor(rect.position - global_position + Vector2(rect.size.x * 0.5, -28 * k), guide.size * k)
	guide.move_to_front()
