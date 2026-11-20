extends RefCounted
## Предпросмотр улучшения Штаба: данные берутся из правил форта.

const Look = preload("res://scripts/legion_look.gd")
const Kit = preload("res://scripts/ui_kit_a.gd")
const KnowUI = preload("res://scripts/legion_knowledge_ui.gd")


static func build(ui: Variant, id: int) -> void:
	var lg: Legion = ui.lg
	var plot := lg.fort_plot(id)
	var level := int(plot["lv"])
	var free := lg.fort_guide_free("hq", level + 1)
	var unlocks := lg.fort_hq_unlocks(level)
	var body: VBoxContainer = ui._new_framed_modal(1250)
	ui.hq_window_id = id
	var panel: Control = ui.modal_panel
	panel.name = "FortHQUpgrade"
	panel.set_meta("before_level", level)
	var header := HBoxContainer.new()
	body.add_child(header)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 52
	header.add_child(spacer)
	header.add_child(Look.heading(I18n.t("Улучшение Штаба"), 43))
	header.add_child(Look.close_button(ui._close_modal, 52))
	var levels := Look.label("%s   %d  →  %d" % [I18n.t("Уровень форта"), level, level + 1], 36, Look.WINE, true)
	levels.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(levels)
	body.add_child(Look.divider())

	var title := Look.label(I18n.t("Откроется на новом уровне"), 26, Look.INK, true)
	body.add_child(title)
	var grid := GridContainer.new()
	grid.name = "FortHQUnlocks"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	for type: String in unlocks["rooms"]:
		_tile(grid, "room:" + type, FortCutaway.room_icon(type), I18n.t(Legion.FORT_B[type]["name"]), "+%d" % int(unlocks["rooms"][type]))
	var expansion: Dictionary = unlocks["expansion"]
	if not expansion.is_empty():
		_tile(grid, "floor", Look.icon("build"), I18n.t("Этаж · места"), "+%d" % int(expansion["floor"]))
		_tile(grid, "section", Look.icon("build"), I18n.t("Секция · места"), "+%d" % int(expansion["section"]))
	var stock_names := {"money": "Денарии", "rations": "Еда", "ingots": "Слитки", "iron": "железо", "wood": "Дерево", "leather": "кожа"}
	for resource: String in unlocks["caps"]:
		_tile(grid, "cap:" + resource, Look.resource(resource), I18n.t("Запас") if resource == "rations" else I18n.t("Запас: %s") % I18n.t(stock_names[resource]).capitalize(), "+" + ui.hud.fmt(unlocks["caps"][resource]))
	_tile(grid, "room_level", FortCutaway.room_icon("hq"), I18n.t("Предел уровня комнат"), str(unlocks["room_level"]))
	for key: String in ["barracks", "squad"]:
		if int(unlocks[key]) > 0:
			_tile(grid, key, FortCutaway.room_icon("barracks") if key == "barracks" else Look.icon("squad"),
				I18n.t("Места в казарме" if key == "barracks" else "Места в отряде"), "+%d" % int(unlocks[key]))
	for knowledge: String in unlocks["knowledge"]:
		var data: Dictionary = Legion.Knowledge.NODES[knowledge]
		_tile(grid, "knowledge:" + knowledge, KnowUI.node_icon(knowledge), I18n.t(data["name"]), I18n.t(String(data["tiers"])))
	for region: int in unlocks["provinces"]:
		_tile(grid, "province:%d" % region, Look.icon("map"), I18n.t(Legion.REGIONS2[region]["name"]), I18n.t("Провинция %d") % (region + 1))

	body.add_child(Look.divider())
	var price := HBoxContainer.new()
	price.name = "FortHQPrice"
	price.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(price)
	var info := lg.fort_info(id)
	var cost: Dictionary = {} if free else info["next_cost"]
	for resource: String in ["money", "iron", "wood", "leather", "glory"]:
		var amount := int(cost.get(resource, cost.get("mats", {}).get(resource, 0)))
		if amount > 0:
			var name_text := I18n.t(stock_names.get(resource, "Слава")).capitalize()
			var tile := _tile(price, "price:" + resource, Look.resource(resource), name_text, ui.hud.fmt(amount))
			tile.set_meta("cost_resource", resource)
			tile.set_meta("cost_amount", amount)
	var time := _tile(price, "time", Look.icon("timer"), I18n.t("Время"), I18n.t("Мгновенно") if free else ui.duration_text(float(info["next_time"])))
	time.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var status := HBoxContainer.new()
	status.name = "FortHQStatus"
	status.alignment = BoxContainer.ALIGNMENT_CENTER
	status.custom_minimum_size.y = 28
	body.add_child(status)
	var lock := Kit.image(KnowUI.lock_icon(), Vector2(24, 24))
	status.add_child(lock)
	var reason := Look.label("", 20, Look.WINE)
	reason.name = "FortHQReason"
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_child(reason)
	reason.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	body.add_child(buttons)
	var instant := Look.button(I18n.t("Мгновенно"), Look.resource("ingots"), Look.PAPER, Vector2(225, 56))
	instant.name = "FortHQInstant"
	instant.pressed.connect(_apply.bind(ui, panel, id, level, true))
	buttons.add_child(instant)
	instant.visible = not free
	var upgrade := Look.button(I18n.t("Улучшить"), Look.icon("build"), Look.WINE, Vector2(225, 56))
	upgrade.name = "FortHQConfirm"
	if free:
		upgrade.text = I18n.t("Улучшить · Бесплатно")
	upgrade.pressed.connect(_apply.bind(ui, panel, id, level, false))
	buttons.add_child(upgrade)
	refresh(ui)
	ui._fit_modal.call_deferred()


static func _tile(parent: Control, key: String, icon: Texture2D, title: String, value: String) -> PanelContainer:
	var tile := Look.panel(Look.INSET, 7)
	tile.custom_minimum_size = Vector2(0, 62)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.set_meta("hq_key", key)
	tile.set_meta("hq_value", value)
	parent.add_child(tile)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	tile.add_child(row)
	row.add_child(Kit.image(icon, Vector2(34, 34)))
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 1)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	var caption := Look.label(title, 18)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(caption)
	words.add_child(Look.label(value, 20, Look.WINE))
	return tile


static func refresh(ui: Variant) -> void:
	if ui.hq_window_id < 0 or not is_instance_valid(ui.modal_panel):
		return
	var lg: Legion = ui.lg
	var panel: Control = ui.modal_panel
	var id: int = ui.hq_window_id
	var upgrade := panel.find_child("FortHQConfirm", true, false) as Button
	var instant := panel.find_child("FortHQInstant", true, false) as Button
	var reason := panel.find_child("FortHQReason", true, false) as Label
	var quote := lg.fort_instant_info(id)
	var why := lg.fort_can_upgrade(id)
	upgrade.disabled = why != ""
	instant.disabled = quote["why"] != ""
	instant.text = I18n.t("Мгновенно") + " · " + ui.hud.fmt(quote["price"])
	instant.set_meta("quote", quote)
	instant.tooltip_text = I18n.t(String(quote["why"]))
	reason.text = "" if lg.fort_guide_free("hq", int(panel.get_meta("before_level")) + 1) else I18n.t(why if why != "" else String(quote["why"]))
	(reason.get_parent().get_child(0) as Control).visible = reason.text != ""
	var price := panel.find_child("FortHQPrice", true, false)
	for tile: PanelContainer in price.get_children():
		if not tile.has_meta("cost_resource"):
			continue
		var resource := String(tile.get_meta("cost_resource"))
		var stock: float = lg.glory if resource == "glory" else lg.fort_stock(resource)
		tile.modulate = Color("f4b39b") if stock < float(tile.get_meta("cost_amount")) else Color.WHITE


static func _apply(ui: Variant, panel: Control, id: int, level: int, instant: bool) -> void:
	var lg: Legion = ui.lg
	if ui.modal_panel != panel or int(lg.fort_plot(id).get("lv", -1)) != level or not lg.fort_plot_timer(id).is_empty():
		return
	var button := panel.find_child("FortHQInstant", true, false) as Button
	var ok := lg.fort_instant(id, button.get_meta("quote")) if instant else lg.fort_upgrade(id)
	if ok:
		ui._close_modal()
		ui._select_fort_room("plot_%d" % id)
	ui._refresh()
