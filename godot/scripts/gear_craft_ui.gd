extends RefCounted
## Один состав окна на рецепт; значения и таймеры обновляются на месте.

const Kit = preload("res://scripts/ui_kit_a.gd")
const Ring = preload("res://scripts/fort_ui_ring.gd")


static func build(ui: Variant) -> void:
	var lg: Legion = ui.lg
	var plot_id: int = ui._craft_plot
	var p := lg.fort_plot(plot_id)
	if p.is_empty() or not p["b"] in ["forge", "arsenal"]:
		ui.close()
		return
	lg.fort_finish()
	var room := String(p["b"])
	var kinds: Array = ["sword", "bow", "staff", "spear"] if room == "forge" else ["helmet", "armor", "offhand"]
	if not ui._craft_kind in kinds:
		ui._craft_kind = String(kinds[0])
	var unlocked := lg.craft_tier_max(plot_id)
	ui._craft_tier = clampi(ui._craft_tier, 1, maxi(1, unlocked))
	var queue := lg.craft_queue(plot_id)
	var jobs := []
	for job: Dictionary in queue:
		jobs.append([job["kind"], job["tier"], job["total"]])
	var signature := str([plot_id, room, p["lv"], ui._craft_kind, ui._craft_tier, jobs])
	var cached: PanelContainer = ui.get_meta("craft_panel", null) as PanelContainer
	if is_instance_valid(cached) and is_instance_valid(ui.overlay) and cached.get_parent() == ui.overlay and not ui.overlay.is_queued_for_deletion() and cached.get_meta("signature", "") == signature:
		ui._live = (cached.get_meta("live") as Array).duplicate()
		for entry: Dictionary in ui._live:
			if entry.get("kind") == "craft":
				refresh(ui, entry)
		return
	ui._live.clear()
	var panel: PanelContainer = ui._modal(760)
	panel.name = "CraftPanel"
	panel.set_meta("signature", signature)
	ui.set_meta("craft_panel", panel)
	var v: VBoxContainer = panel.get_child(0)
	var header := HBoxContainer.new()
	header.add_child(Kit.level_badge(int(p["lv"])))
	var title := Kit.ribbon(I18n.t("Кузница" if room == "forge" else "Оружейная"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	v.add_child(header)
	var choices := HBoxContainer.new()
	choices.name = "CraftKinds"
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	choices.add_theme_constant_override("separation", 12)
	for kind: String in kinds:
		var probe := Gear.craft_item(kind, 1)
		var b := Kit.round_button(ui._gear_tex(Gear.icon_of(probe), String(probe["slot"])))
		b.name = "CraftKind_" + kind
		b.tooltip_text = I18n.t(String(Gear.CRAFT_TYPES[kind]))
		b.modulate = Color.WHITE if kind == ui._craft_kind else Color(0.78, 0.70, 0.58)
		b.pressed.connect(func(): ui._craft_kind = kind; ui._craft_win())
		choices.add_child(b)
	v.add_child(choices)
	var tiers := HBoxContainer.new()
	tiers.name = "CraftTiers"
	tiers.alignment = BoxContainer.ALIGNMENT_CENTER
	for tier in range(1, Gear.TIERS + 1):
		var b := Kit.round_button(null)
		b.name = "CraftTier_%d" % tier
		b.custom_minimum_size = Vector2(48, 48)
		b.text = str(tier)
		b.disabled = tier > unlocked
		b.modulate = Color.WHITE if tier == ui._craft_tier else Color(0.8, 0.72, 0.6)
		b.tooltip_text = I18n.t("Тир") + " %d" % tier if not b.disabled else I18n.t("Для тира %d нужен уровень комнаты %d") % [tier, Gear.tier_room_level(tier)]
		b.pressed.connect(func(): ui._craft_tier = tier; ui._craft_win())
		tiers.add_child(b)
	v.add_child(tiers)
	var probe := Gear.craft_item(ui._craft_kind, ui._craft_tier)
	var preview := HBoxContainer.new()
	preview.name = "CraftPreview"
	preview.add_theme_constant_override("separation", 22)
	preview.add_child(CampUI.attach(ui.hud)._dweller_item_icon(probe, 124))
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.add_child(details)
	details.add_child(Kit.label(I18n.t(String(Gear.CRAFT_TYPES[ui._craft_kind])), 25))
	var g := Gear.tier_stats(probe)
	var cls := Gear.weapon_class(probe) if probe["slot"] == "weapon" else "legionary"
	var before := Legion.power(Legion.gear_unit_stats(cls, 1))
	var after := Legion.power(Legion.gear_unit_stats(cls, 1, float(g["atk"]), float(g["hp"]), float(g["armor"])))
	var power := HBoxContainer.new()
	power.add_child(Kit.image("star", Vector2(30, 30)))
	power.add_child(Kit.label("+%d" % (after - before), 28))
	power.tooltip_text = I18n.t("Без других вещей; редкость добавит силу.") + "\n" + Gear.stats_text(probe)
	details.add_child(power)
	var costs := CampUI.attach(ui.hud)._cost_icons({"mats": Gear.craft_mats(ui._craft_kind, ui._craft_tier)})
	details.add_child(costs)
	details.add_child(Kit.time_row(CampUI.duration_text(float(Gear.TIER_TIME[ui._craft_tier - 1]) / maxf(0.001, lg.time_k))))
	v.add_child(preview)
	var odds := HBoxContainer.new()
	odds.name = "CraftRarityOdds"
	odds.alignment = BoxContainer.ALIGNMENT_CENTER
	odds.add_theme_constant_override("separation", 10)
	for r in 5:
		var chip := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Gear.color(r).darkened(0.35)
		style.set_corner_radius_all(12)
		style.content_margin_left = 13
		style.content_margin_right = 13
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		chip.add_theme_stylebox_override("panel", style)
		chip.add_child(Kit.label(str(Gear.CRAFT_ODDS[r]) + "%", 19, true))
		chip.tooltip_text = I18n.t("Шансы редкости при сборе") + "\n" + I18n.t(String(Gear.RARITY[r])).capitalize()
		odds.add_child(chip)
	v.add_child(odds)
	var requirement := Kit.banner_red("")
	requirement.name = "CraftRequirement"
	v.add_child(requirement)
	var start := Kit.button("green", "craft")
	start.name = "CraftStart"
	start.tooltip_text = I18n.t("Начать")
	start.pressed.connect(func(): lg.craft_start(plot_id, ui._craft_kind, ui._craft_tier); ui._craft_win())
	v.add_child(start)
	var summary := Kit.label("", 20)
	summary.name = "CraftQueueCount"
	v.add_child(summary)
	var queue_row := HBoxContainer.new()
	queue_row.name = "CraftQueue"
	queue_row.alignment = BoxContainer.ALIGNMENT_CENTER
	queue_row.add_theme_constant_override("separation", 16)
	v.add_child(queue_row)
	for i in lg.craft_capacity(plot_id):
		var column := VBoxContainer.new()
		queue_row.add_child(column)
		if i >= queue.size():
			var empty := Kit.slot("plus", false, 100)
			empty.tooltip_text = I18n.t("Очередь пуста. Выберите вещь и нажмите «Начать».")
			column.add_child(empty)
			continue
		var job: Dictionary = queue[i]
		var item := Gear.craft_item(String(job["kind"]), int(job["tier"]))
		var slot := Kit.slot(ui._gear_tex(Gear.icon_of(item), String(item["slot"])), false, 100)
		slot.tooltip_text = I18n.t(String(Gear.CRAFT_TYPES[job["kind"]]))
		column.add_child(slot)
		var ring := Ring.new()
		slot.add_child(ring)
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var status := Kit.label("", 18)
		column.add_child(status)
		var collect := Kit.button("green", "collect")
		collect.custom_minimum_size.x = 100
		collect.tooltip_text = I18n.t("Собрать")
		collect.pressed.connect(func(): lg.craft_collect(plot_id); ui._craft_win())
		column.add_child(collect)
		var entry := {"kind": "craft", "plot": plot_id, "index": i, "label": status, "collect": collect, "ring": ring}
		ui._live.append(entry)
		refresh(ui, entry)
		CampUI.attach(ui.hud)._add_speed(column, "craft_%d_%d" % [plot_id, i])
	var controls := {"kind": "craft", "plot": plot_id, "index": -1, "label": summary, "start": start, "requirement": requirement, "costs": costs}
	ui._live.append(controls)
	refresh(ui, controls)
	var store := Kit.button("cream", "equip")
	store.tooltip_text = I18n.t("Снаряжение")
	store.pressed.connect(func(): ui.open_camp_window("store"))
	v.add_child(store)
	panel.set_meta("live", ui._live.duplicate())
	ui._center_later(panel)


static func refresh(ui: Variant, entry: Dictionary) -> void:
	var queue: Array = ui.lg.craft_queue(int(entry["plot"]))
	var i := int(entry["index"])
	if i < 0:
		var why: String = ui.lg.can_craft(int(entry["plot"]), ui._craft_kind, ui._craft_tier)
		(entry["start"] as Button).disabled = why != ""
		(entry["start"] as Button).tooltip_text = I18n.t("Начать") + ("\n" + I18n.t(why) if why != "" else "")
		var requirement: PanelContainer = entry["requirement"]
		requirement.visible = why != ""
		(requirement.get_meta("label") as Label).text = I18n.t(why)
		(entry["label"] as Label).text = "%d / %d" % [queue.size(), ui.lg.craft_capacity(int(entry["plot"]))]
		CampUI.attach(ui.hud)._refresh_costs(entry["costs"])
		return
	if i >= queue.size():
		return
	var job: Dictionary = queue[i]
	var ready := float(job["left"]) <= 0.0
	var state := I18n.t("Готово") if ready else CampUI.clock_text(float(job["left"]))
	var tip := state
	if not ready:
		if not ui.lg.craft_working(int(entry["plot"])):
			tip += " · " + I18n.t("Пауза: нужен работник и готовая комната")
		else:
			for previous in i:
				if float(queue[previous]["left"]) > 0.0:
					tip += " · " + I18n.t("В очереди")
					break
	(entry["label"] as Label).text = state
	(entry["label"] as Label).tooltip_text = tip
	(entry["label"] as Label).mouse_filter = Control.MOUSE_FILTER_PASS
	entry["ring"].set("value", 1.0 - float(job["left"]) / maxf(1, float(job["total"])))
	var b: Button = entry["collect"]
	b.visible = ready
	b.disabled = ui.lg.store_count() >= ui.lg.store_cap()
	b.tooltip_text = I18n.t("Склад полон. Продайте или наденьте лишние вещи.") if b.disabled else I18n.t("Собрать")
