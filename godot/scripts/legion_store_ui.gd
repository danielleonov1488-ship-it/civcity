extends RefCounted
## Общая сетка вещей для склада и жителя.

const Look = preload("res://scripts/legion_look.gd")
const Kit = preload("res://scripts/ui_kit_a.gd")
const KnowUI = preload("res://scripts/legion_knowledge_ui.gd")
const WORK_ICONS := {"cook": "need_food", "smith": "craft", "scribe": "research", "priest": "need_faith", "builder": "build"}
const TABS := {"all": "Все", "weapon": "Оружие", "armor": "Броня", "outfit": "Одежда", "chest": "Сундуки", "material": "Материалы"}


static func store(ui: Variant, tab: String, page: int, chest: String, reward: Dictionary) -> void:
	var body: VBoxContainer = ui._new_modal(998, true)
	ui.modal_panel.custom_minimum_size.y = 900
	ui.modal_panel.name = "FortStorage"
	var lg: Legion = ui.lg
	var header := HBoxContainer.new()
	var knowledge := Look.button("", KnowUI.node_icon("sets"), Look.WINE, Vector2(52, 50))
	knowledge.tooltip_text = I18n.t("Знание снаряжения")
	knowledge.pressed.connect(func(): ui.show_knowledge("smith", ui.show_storage.bind(tab, page, chest)))
	header.add_child(knowledge)
	var title := Look.label(I18n.t("Склад"), 42, Look.INK, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)
	var count := Look.label(I18n.t("Вещи %d/%d") % [lg.store_count(), lg.store_cap()], 25,
		Look.WINE if lg.store_count() >= lg.store_cap() else Look.INK)
	count.name = "FortStoreCount"
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(count)
	var close := Look.button("×", null, Look.INSET, Vector2(48, 48))
	close.name = "FortChestBack"
	close.pressed.connect(ui._close_modal)
	header.add_child(close)
	body.add_child(header)
	var preview := chest != "" and lg.chest_queue.has(chest)
	grid(ui, body, 0, tab, page, "", 3 if preview or not reward.is_empty() else 5)
	var breathing_space := Control.new()
	breathing_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	breathing_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(breathing_space)
	if not reward.is_empty():
		body.add_child(_reward(ui, reward))
	elif preview:
		body.add_child(_chest(ui, tab, page, chest))
	ui._fit_modal.call_deferred()


static func grid(ui: Variant, parent: VBoxContainer, sid: int, tab: String, page: int, slot := "", rows := 3) -> void:
	var lg: Legion = ui.lg
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 5)
	parent.add_child(tabs)
	for id: String in TABS:
		var active := tab == id
		var b := Look.button("", null, Look.WINE if active else Look.INSET, Vector2(86, 73))
		b.name = "FortAllGear" if id == "all" else "StoreTab_" + id
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = I18n.t(TABS[id])
		b.pressed.connect(_page.bind(ui, sid, id, 0))
		tabs.add_child(b)
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override("separation", 0)
		b.add_child(column)
		column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var icon := Kit.image(KnowUI.art("store", id, "equip"), Vector2(33, 33))
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(icon)
		var caption := Look.label(I18n.t(TABS[id]), 18 if sid != 0 else 20, Look.PAPER if active else Look.INK)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(caption)
	var entries: Array[Dictionary] = []
	if sid == 0 and tab in ["all", "chest"]:
		for kind: String in Legion.CHEST_NAMES:
			var count := lg.chest_queue.count(kind)
			if count > 0:
				entries.append({"chest": kind, "count": count})
	for it: Dictionary in lg.items:
		if int(it.get("on", 0)) != 0 or (slot != "" and it["slot"] != slot):
			continue
		if sid != 0 and lg.can_equip(sid, int(it["id"])) != "":
			continue
		var kind := String(it["slot"])
		var group := kind if kind == "weapon" else "outfit" if kind == Gear.OUTFIT_SLOT else "armor"
		if tab in ["all", group]:
			entries.append({"item": it})
	if sid == 0 and tab in ["all", "material"]:
		for res: String in Gear.MATS:
			entries.append({"material": res})
	var columns := 8 if sid == 0 else 6
	var per_page := columns * rows
	var pages := maxi(1, ceili(float(entries.size()) / per_page))
	page = clampi(page, 0, pages - 1)
	var tiles := GridContainer.new()
	tiles.name = "FortInventoryGrid"
	tiles.columns = columns
	tiles.add_theme_constant_override("h_separation", 8)
	tiles.add_theme_constant_override("v_separation", 8)
	tiles.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(tiles)
	var back := _page.bind(ui, sid, tab, page, slot)
	var pixels := 109.0 if sid == 0 else 94.0
	for j in per_page:
		var index := page * per_page + j
		var entry: Dictionary = entries[index] if index < entries.size() else {}
		var button := Look.button("", null, Look.INSET, Vector2.ONE * pixels)
		tiles.add_child(button)
		if entry.has("item"):
			_item_tile(ui, button, entry["item"], sid, pixels, back)
		elif entry.has("chest"):
			var kind: String = entry["chest"]
			button.name = "FortChest_" + kind
			button.tooltip_text = I18n.t(Legion.CHEST_NAMES[kind])
			_tile_art(button, _chest_icon(kind), pixels)
			if kind == "bronze":
				var border := Look.box(Look.INSET, Look.BRONZE, 10, 0)
				border.set_border_width_all(2)
				button.add_theme_stylebox_override("normal", border)
			_tile_text(button, "×%d" % int(entry["count"]), pixels)
			button.pressed.connect(func(): ui.show_storage(tab, page, kind))
		elif entry.has("material"):
			var res: String = entry["material"]
			_tile_art(button, Look.resource(res), pixels)
			_tile_text(button, str(lg.mat(res)), pixels)
			button.tooltip_text = I18n.t(Gear.MAT_NAME[res]) + " · %d/%d" % [lg.mat(res), lg.resource_cap(res)]
		else:
			button.disabled = true
			button.add_theme_stylebox_override("disabled", Look.box(Look.INSET.darkened(0.045), Look.EDGE, 9, 0))
			button.focus_mode = Control.FOCUS_NONE
	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.visible = pages > 1
	parent.add_child(nav)
	var prev := Look.button("‹", null, Look.INSET, Vector2(46, 38))
	var next := Look.button("›", null, Look.INSET, Vector2(46, 38))
	prev.disabled = page == 0
	next.disabled = page + 1 >= pages
	prev.pressed.connect(_page.bind(ui, sid, tab, page - 1, slot))
	next.pressed.connect(_page.bind(ui, sid, tab, page + 1, slot))
	nav.add_child(prev)
	var counter := Look.label("%d / %d" % [page + 1, pages], 22, Look.SOFT)
	counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nav.add_child(counter)
	nav.add_child(next)


static func _page(ui: Variant, sid: int, tab: String, page: int, slot := "") -> void:
	if sid == 0:
		ui.show_storage(tab, page)
	else:
		ui.show_dweller(sid, slot, "", tab, page)


static func _item_tile(ui: Variant, button: Button, it: Dictionary, sid: int, pixels: float, back: Callable) -> void:
	var iid := int(it["id"])
	button.name = "FortEquip_%d" % iid if sid != 0 else "StoreItem_%d" % iid
	button.tooltip_text = Gear.name_of(it) + "\n" + item_stats(ui.lg, it)
	var color := Gear.color(int(it["rarity"]))
	for state: String in ["normal", "hover", "pressed"]:
		var fill := Look.DARK.lerp(color, 0.28) if state == "normal" else Look.DARK.lerp(color, 0.50)
		var frame := Look.box(fill, color, 9, 0)
		frame.set_border_width_all(2)
		button.add_theme_stylebox_override(state, frame)
	if sid != 0:
		var compare: Array = ui.lg.equip_power(sid, iid)
		button.set_meta("power_before", int(compare[0]))
		button.set_meta("power_after", int(compare[1]))
		if it["slot"] != Gear.OUTFIT_SLOT:
			button.tooltip_text += "\n" + I18n.t("Было → стало: %d → %d") % [int(compare[0]), int(compare[1])]
	button.pressed.connect(item_card.bind(ui, iid, sid, back))
	_tile_art(button, item_icon(ui, it), pixels)
	_tile_text(button, str(Gear.tier_of(it)), pixels)
	var outfit := Gear.work_kind(it)
	if WORK_ICONS.has(outfit):
		var badge := Kit.image(WORK_ICONS[outfit], Vector2(22, 22))
		badge.position = Vector2(pixels - 28, pixels - 27)
		button.add_child(badge)
	if bool(it.get("new", false)):
		var dot := Panel.new()
		dot.add_theme_stylebox_override("panel", Look.box(Color("bc5037"), Look.PAPER, 12, 0))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.position = Vector2(pixels - 17, 6)
		dot.size = Vector2.ONE * 11.0
		dot.name = "FortNewItem"
		button.add_child(dot)


static func item_icon(ui: Variant, item: Dictionary) -> Texture2D:
	if item["slot"] == Gear.OUTFIT_SLOT:
		return KnowUI.art("store", "outfit", "clothes")
	if item["slot"] == "weapon":
		match Gear.weapon_class(item):
			"priest": return KnowUI.node_icon("staffs")
			"cavalry": return KnowUI.node_icon("spears")
	return ui.lu._gear_tex(Gear.icon_of(item), String(item["slot"]))


static func item_stats(lg: Legion, item: Dictionary) -> String:
	var kind := Gear.work_kind(item)
	if kind != "" and lg.knows("outfit2"):
		return I18n.t(Gear.WORK_TIP[kind]) % roundi((Gear.work_bonus(item, kind) + 0.05) * 100.0)
	return Gear.stats_text(item)


static func _tile_art(button: Button, art: Texture2D, pixels: float) -> void:
	var icon := Kit.image(art, Vector2.ONE * (pixels - 16.0))
	icon.position = Vector2(8, 6)
	button.add_child(icon)


static func _tile_text(button: Button, text: String, pixels: float) -> void:
	var label := Look.label(text, 19, Look.PAPER)
	label.add_theme_stylebox_override("normal", Look.box(Look.DARK, Look.BRONZE, 7, 3))
	label.position = Vector2(5, pixels - 30)
	button.add_child(label)


static func _chest_icon(kind: String) -> Texture2D:
	return KnowUI.art("store", "chest", "chest") if kind in ["wooden", "bronze"] else Look.icon("chest")


static func _chest(ui: Variant, tab: String, page: int, kind: String) -> Control:
	var lg: Legion = ui.lg
	var panel := Look.panel(Look.INSET, 12)
	panel.name = "FortChestPreview"
	var body := VBoxContainer.new()
	panel.add_child(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	body.add_child(row)
	row.add_child(Kit.image(_chest_icon(kind), Vector2(126, 124)))
	var title := Look.label(I18n.t(Legion.CHEST_NAMES[kind]), 30, Look.INK, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	var loot := VBoxContainer.new()
	loot.custom_minimum_size.x = 350
	row.add_child(loot)
	var odds := HBoxContainer.new()
	odds.add_child(Kit.image(KnowUI.art("store", "weapon"), Vector2(34, 34)))
	var chances: Array = Legion.CHEST_RARITY_ODDS[kind]
	for i in chances.size():
		var r: int = [0, 2, 3, 4][i]
		var dot := Look.label("●", 22, Gear.color(r).darkened(0.28))
		dot.tooltip_text = I18n.t(Gear.RARITY[r]).capitalize()
		dot.mouse_filter = Control.MOUSE_FILTER_PASS
		odds.add_child(dot)
		odds.add_child(Look.label("%d%%" % int(chances[i]), 22))
	loot.add_child(odds)
	for res: String in ["rations", "money"]:
		var bounds := Legion.chest_range(kind, res)
		loot.add_child(_pair(Look.resource(res), "%d–%d" % [bounds.x, bounds.y], 32))
	var full := lg.store_count() >= lg.store_cap()
	var open := Look.button(I18n.t("Открыть ×1"), KnowUI.lock_icon() if full else _chest_icon(kind), Look.WINE, Vector2(248, 50))
	open.name = "FortChestOpen"
	open.disabled = full
	open.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	open.pressed.connect(func():
		var got := lg.open_chest(kind)
		if not got.is_empty():
			ui.show_storage(tab, page, "", got)
			ui._refresh())
	body.add_child(open)
	if full:
		var why := Look.label(I18n.t("Склад вещей полон"), 22, Look.WINE)
		why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(why)
	return panel


static func _reward(ui: Variant, reward: Dictionary) -> PanelContainer:
	var panel := Look.panel(Look.INSET, 10)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)
	row.add_child(Kit.image(item_icon(ui, reward["item"]), Vector2(73, 73)))
	for res: String in Legion.STOCK_RESOURCES:
		var value := int(reward.get(res, 0)) - (int(reward.get("money_lost", 0)) if res == "money" else 0)
		if value > 0:
			row.add_child(_pair(Look.resource(res), "+%d" % value, 30))
	return panel


static func _pair(icon: Texture2D, value: String, pixels: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_child(Kit.image(icon, Vector2.ONE * pixels))
	var label := Look.label(value, 22)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	return row


static func item_card(ui: Variant, iid: int, sid: int, back: Callable) -> void:
	var lg: Legion = ui.lg
	var it := lg.item(iid)
	if it.is_empty():
		back.call()
		return
	it["new"] = false
	var body: VBoxContainer = ui._new_modal(790, true)
	ui.modal_panel.name = "FortItemCard"
	ui.dweller_sid = sid
	var head := HBoxContainer.new()
	var title := Look.label(Gear.name_of(it), 34, Look.INK, true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Look.button("×", null, Look.INSET, Vector2(48, 44))
	close.pressed.connect(back)
	head.add_child(close)
	body.add_child(head)
	var is_worn := int(it.get("on", 0)) != 0
	var person := lg.soldier(sid)
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 13)
	body.add_child(choices)
	var old := lg.item(int(person.get("gear", {}).get(it["slot"], 0)))
	if not person.is_empty() and not is_worn:
		choices.add_child(_item_details(ui, old, "Надето"))
	choices.add_child(_item_details(ui, it, "Надето" if is_worn else "Выбранное"))
	if not person.is_empty() and not is_worn:
		var diffs := HBoxContainer.new()
		diffs.alignment = BoxContainer.ALIGNMENT_CENTER
		diffs.add_theme_constant_override("separation", 18)
		body.add_child(diffs)
		if it["slot"] == Gear.OUTFIT_SLOT:
			var kind := Gear.work_kind(it)
			var before := Gear.work_bonus(old, kind)
			var after := Gear.work_bonus(it, kind)
			if before == 0.0 and lg.knows("outfit2"):
				after += 0.05
			_delta(diffs, Look.icon("clothes"), roundi((after - before) * 100.0), "%")
		else:
			var stat := lg.equip_stat_preview(sid, iid)
			for metric: Array in [["atk", "soldier"], ["hp", "need_services"], ["armor", "equip"]]:
				var key: String = metric[0]
				_delta(diffs, Look.icon(metric[1]), roundi(float(stat[1][key]) - float(stat[0][key])), "")
			_delta(diffs, Look.icon("laurels"), Legion.power(stat[1]) - Legion.power(stat[0]), "")
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(actions)
	if sid != 0:
		var equip := Look.button(I18n.t("Снять" if is_worn else "Надеть"), KnowUI.art("store", "armor"), Look.WINE)
		equip.name = "FortItemEquip"
		equip.disabled = lg.store_count() >= lg.store_cap() if is_worn else lg.can_equip(sid, iid) != ""
		equip.pressed.connect(func():
			if is_worn:
				if lg.unequip(sid, String(it["slot"])):
					back.call()
					ui._refresh()
			else:
				ui._equip_dweller(sid, iid))
		actions.add_child(equip)
	else:
		var picker := OptionButton.new()
		picker.add_item(I18n.t("Надеть"))
		for s: Dictionary in lg.soldiers:
			var target := int(s["id"])
			if lg.can_equip(target, iid) == "":
				picker.add_item(String(s["name"]), target)
		picker.disabled = picker.item_count == 1
		picker.item_selected.connect(func(index: int):
			if index > 0:
				item_card(ui, iid, picker.get_item_id(index), back))
		actions.add_child(picker)
	if not is_worn:
		var why := lg.can_smelt(iid)
		var dismantle := Look.button(I18n.t("Разобрать"), KnowUI.node_icon("smelt"), Look.INSET)
		dismantle.disabled = why != ""
		dismantle.tooltip_text = I18n.t(why)
		dismantle.pressed.connect(_smelt.bind(ui, iid, sid, back))
		actions.add_child(dismantle)
	if lg.knows("reforge") and Gear.tier_of(it) < Gear.TIERS:
		var quote := lg.reforge_quote(iid)
		var reforge := Look.button(I18n.t("Перековка") + " · %d → %d" % [Gear.tier_of(it), int(quote["tier"])], KnowUI.node_icon("reforge"), Look.INSET)
		reforge.disabled = quote["why"] != ""
		reforge.tooltip_text = quote["why"]
		reforge.pressed.connect(func():
			if lg.reforge_item(iid, int(quote["tier"])):
				item_card(ui, iid, sid, back)
				ui._refresh())
		var costs: HBoxContainer = ui._cost_icons(quote)
		costs.alignment = BoxContainer.ALIGNMENT_CENTER
		body.add_child(costs)
		actions.add_child(reforge)
	ui._fit_modal.call_deferred()


static func _delta(row: HBoxContainer, icon: Texture2D, amount: int, unit: String) -> void:
	var pair := _pair(icon, "%+d" % amount + unit, 29)
	var text := pair.get_child(1) as Label
	text.add_theme_color_override("font_color", Look.OLIVE if amount > 0 else Look.WINE if amount < 0 else Look.SOFT)
	row.add_child(pair)

static func _item_details(ui: Variant, it: Dictionary, heading: String) -> PanelContainer:
	var panel := Look.panel(Look.INSET, 16)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)
	var title := Look.label(I18n.t(heading), 24, Look.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var image := Kit.image(item_icon(ui, it) if not it.is_empty() else KnowUI.art("store", "all"), Vector2(115, 115))
	image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(image)
	var caption := Look.label("—" if it.is_empty() else Gear.name_of(it) + " · " + str(Gear.tier_of(it)), 23,
		Look.SOFT if it.is_empty() else Gear.color(int(it["rarity"])).darkened(0.38))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(caption)
	if not it.is_empty():
		var stats := Look.label(item_stats(ui.lg, it), 21)
		stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(stats)
	return panel


static func _smelt(ui: Variant, iid: int, sid: int, back: Callable) -> void:
	var lg: Legion = ui.lg
	var it := lg.item(iid)
	var body: VBoxContainer = ui._new_modal(520, true)
	body.add_child(Look.label(I18n.t("Разобрать") + " · " + Gear.name_of(it), 25))
	var row := _pair(ui.lu._gear_tex(Gear.ICON_SHARD), "+1", 32)
	row.add_child(ui._cost_icons({"mats": lg.smelt_preview(iid)}, false))
	body.add_child(row)
	var actions := HBoxContainer.new()
	body.add_child(actions)
	var cancel := Look.button(I18n.t("Назад"), null, Look.INSET)
	cancel.pressed.connect(item_card.bind(ui, iid, sid, back))
	actions.add_child(cancel)
	var confirm := Look.button(I18n.t("Разобрать"), KnowUI.node_icon("smelt"), Look.WINE)
	confirm.pressed.connect(func():
		if lg.smelt(iid):
			back.call()
			ui._refresh())
	actions.add_child(confirm)
	ui._fit_modal.call_deferred()
