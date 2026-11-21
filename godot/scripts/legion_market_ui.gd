extends RefCounted
## Рынок форта, цены и ограничения проверяет Легион.

const Look = preload("res://scripts/legion_look.gd")
const Kit = preload("res://scripts/ui_kit_a.gd")
const Store = preload("res://scripts/legion_store_ui.gd")
const NAMES := {"rations": "Еда", "wood": "Дерево", "iron": "Железо", "leather": "Кожа"}


static func open(ui: Variant, daily: bool) -> void:
	var body: VBoxContainer = ui._new_framed_modal(930)
	var panel: Control = ui.modal_panel
	panel.name = "FortMarketWindow"
	panel.set_meta("daily", daily)
	var header := HBoxContainer.new()
	body.add_child(header)
	var balance := _number(Look.resource("money"), "")
	balance.get_child(1).name = "FortMarketBalance"
	header.add_child(balance)
	header.add_child(Look.heading(I18n.t("Рынок"), 44))
	var close := Look.close_button(ui._close_modal, 52)
	close.name = "FortMarketClose"
	header.add_child(close)
	body.add_child(Look.divider())
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	for daily_tab: bool in [false, true]:
		var title := I18n.t("Товары дня" if daily_tab else "Обмен")
		var button := Look.button(title, Look.icon("market"), Look.OLIVE if daily_tab == daily else Look.PAPER, Vector2(215, 44))
		button.name = "FortMarketDaily" if daily_tab else "FortMarketExchange"
		button.pressed.connect(ui.show_market.bind(daily_tab))
		tabs.add_child(button)
	body.add_child(tabs)
	if daily:
		_daily(ui, body, panel)
	else:
		_exchange(ui, body)
	refresh(ui)
	ui._fit_modal.call_deferred()


static func _exchange(ui: Variant, body: VBoxContainer) -> void:
	for resource: String in Legion.MARKET_ROOMS:
		var tile := Look.panel(Look.INSET, 8)
		body.add_child(tile)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		tile.add_child(row)
		var title := VBoxContainer.new()
		title.custom_minimum_size.x = 170
		title.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(title)
		title.add_child(_number(Look.resource(resource), I18n.t(NAMES[resource])))
		var stock := Look.label("", 20, Look.WINE)
		stock.name = "FortMarketStock_" + resource
		title.add_child(stock)
		for pack in Legion.MARKET_PACKS.size():
			var col := VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_theme_constant_override("separation", 2)
			row.add_child(col)
			var amount := Look.label("", 23, Look.INK, true)
			amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			amount.name = "FortMarketPack_%s_%d" % [resource, pack]
			col.add_child(amount)
			for sell: bool in [false, true]:
				var btn := Look.button("", null, Look.OLIVE if not sell else Look.PAPER, Vector2(146, 35))
				btn.name = "FortMarketTrade_%s_%d_%d" % [resource, pack, int(sell)]
				btn.set_meta("trade", [resource, pack, sell])
				btn.pressed.connect(_trade.bind(ui, resource, pack, sell))
				col.add_child(btn)


static func _daily(ui: Variant, body: VBoxContainer, panel: Control) -> void:
	var lg: Legion = ui.lg
	var daily_goods := lg.market_offers()
	var day := int(daily_goods["day"])
	panel.set_meta("day", day)
	var clock := _number(Look.icon("timer"), "")
	clock.get_child(1).name = "FortMarketTimer"
	clock.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(clock)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 10)
	body.add_child(cards)
	for index in daily_goods["offers"].size():
		var offer: Dictionary = daily_goods["offers"][index]
		var card := Look.panel(Look.INSET, 10)
		card.custom_minimum_size.x = 188
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cards.add_child(card)
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 7)
		card.add_child(list)
		var icon: Texture2D
		var title := ""
		match String(offer["kind"]):
			"chest":
				icon = Store._chest_icon(offer["chest"])
				title = I18n.t(Legion.CHEST_NAMES[offer["chest"]])
			"item":
				icon = Store.item_icon(ui, offer["item"])
				var item: Dictionary = offer["item"]
				var kind := Gear.work_kind(item)
				if kind.is_empty():
					kind = Gear.craft_kind(item["slot"], item.get("cls", ""))
				title = I18n.t(String(Gear.CRAFT_TYPES[kind]))
				title += "\n%s %d" % [I18n.t("Тир"), Gear.tier_of(item)]
			"resource":
				icon = Look.resource(offer["resource"])
				title = "%s · %s" % [I18n.t(NAMES[offer["resource"]]), ui.hud.fmt(offer["amount"])]
		var pic := Kit.image(icon, Vector2(78, 78))
		pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		list.add_child(pic)
		var caption := Look.label(title, 22, Look.INK, true)
		caption.custom_minimum_size.y = 62
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(caption)
		var btn := Look.button("", null, Look.OLIVE, Vector2(146, 44))
		btn.name = "FortMarketOffer_%d" % index
		btn.set_meta("offer", index)
		btn.pressed.connect(_buy.bind(ui, day, index))
		list.add_child(btn)


static func _number(icon: Texture2D, value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(Kit.image(icon, Vector2(32, 32)))
	var label := Look.label(value, 25, Look.INK)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	return row


static func refresh(ui: Variant) -> void:
	var panel: Control = ui.modal_panel
	if not is_instance_valid(panel) or panel.name != &"FortMarketWindow":
		return
	var lg: Legion = ui.lg
	(panel.find_child("FortMarketBalance", true, false) as Label).text = ui.hud.fmt(lg.city_money())
	if bool(panel.get_meta("daily")):
		var goods := lg.market_offers()
		var day := int(goods["day"])
		if int(panel.get_meta("day")) != day:
			ui.show_market(true)
			return
		var left := (day + 1) * Legion.MARKET_DAY_SECONDS - Legion.now()
		(panel.find_child("FortMarketTimer", true, false) as Label).text = I18n.t("Обновление через %s") % ui.clock_text(left)
		for btn: Button in panel.find_children("FortMarketOffer_*", "Button", true, false):
			var index := int(btn.get_meta("offer"))
			_price(ui, btn, "Купить · %s", int(goods["offers"][index]["price"]), lg.market_offer_reason(day, index))
	else:
		for resource: String in Legion.MARKET_ROOMS:
			var stock := panel.find_child("FortMarketStock_" + resource, true, false) as Label
			stock.text = "%s / %s" % [ui.hud.fmt(lg.fort_stock(resource)), ui.hud.fmt(lg.resource_cap(resource))]
		for btn: Button in panel.find_children("FortMarketTrade_*", "Button", true, false):
			var trade: Array = btn.get_meta("trade")
			var quote := lg.market_quote(trade[0], trade[1], trade[2])
			_price(ui, btn, "Продать · %s" if trade[2] else "Купить · %s", int(quote["price"]), quote["why"])
			if not trade[2]:
				var pack := panel.find_child("FortMarketPack_%s_%d" % [trade[0], trade[1]], true, false) as Label
				pack.text = ui.hud.fmt(quote["amount"])


static func _price(ui: Variant, btn: Button, caption: String, price: int, reason: String) -> void:
	var label := I18n.t(caption) % ui.hud.fmt(price)
	btn.disabled = not reason.is_empty()
	btn.text = I18n.t(reason) if btn.disabled else label
	btn.tooltip_text = "%s · %s" % [label, I18n.t(reason)] if btn.disabled else label


static func _trade(ui: Variant, resource: String, pack: int, sell: bool) -> void:
	ui.lg.market_exchange(resource, pack, sell)
	ui._refresh()


static func _buy(ui: Variant, day: int, index: int) -> void:
	ui.lg.market_purchase(day, index)
	ui._refresh()
