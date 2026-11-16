extends RefCounted
## Панель мастерской использует оформление нынешнего окна Легиона.


static func build(ui: Variant) -> void:
	var lg: Legion = ui.lg
	var plot_id: int = ui._craft_plot
	var p := lg.fort_plot(plot_id)
	if p.is_empty() or not p["b"] in ["forge", "arsenal"]:
		ui.close()
		return
	lg.fort_finish()
	ui._live.clear()
	var panel: PanelContainer = ui._modal(640)
	panel.name = "CraftPanel"
	var v: VBoxContainer = panel.get_child(0)
	var room := String(p["b"])
	v.add_child(ui._title(I18n.t("Кузница" if room == "forge" else "Оружейная") + " · " + str(int(p["lv"])), 24))
	var kinds: Array = ["sword", "bow", "staff", "spear"] if room == "forge" else ["helmet", "armor", "offhand"]
	if not ui._craft_kind in kinds:
		ui._craft_kind = String(kinds[0])
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 8)
	for kind: String in kinds:
		var b: Button = ui._btn(String(Gear.CRAFT_TYPES[kind]), 90, 15, null, "", func(): ui._craft_kind = kind; ui._craft_win())
		if kind == ui._craft_kind:
			b.add_theme_stylebox_override("normal", ui.hud._box_pill(16, 6, "g_btn_on"))
		choices.add_child(b)
	v.add_child(choices)
	var unlocked := lg.craft_tier_max(plot_id)
	ui._craft_tier = clampi(ui._craft_tier, 1, maxi(1, unlocked))
	var tiers := HBoxContainer.new()
	tiers.add_child(ui._l(I18n.t("Тир"), 16, true))
	for tier in range(1, unlocked + 1):
		var b: Button = ui._btn(str(tier), 42, 15, null, "", func(): ui._craft_tier = tier; ui._craft_win())
		if tier == ui._craft_tier:
			b.add_theme_stylebox_override("normal", ui.hud._box_pill(16, 6, "g_btn_on"))
		tiers.add_child(b)
	v.add_child(tiers)
	if unlocked < Gear.TIERS:
		v.add_child(ui._l(I18n.t("Для тира %d нужен уровень комнаты %d") % [unlocked + 1, Gear.tier_room_level(unlocked + 1)], 13, false, ui.C_SOFT))
	var probe := Gear.craft_item(ui._craft_kind, ui._craft_tier)
	var preview := HBoxContainer.new()
	preview.add_theme_constant_override("separation", 10)
	preview.add_child(ui._item_ic(probe, 48))
	var details := VBoxContainer.new()
	preview.add_child(details)
	details.add_child(ui._l(I18n.t("Обычная вещь · тир %d") % ui._craft_tier, 16, true))
	var g := Gear.tier_stats(probe)
	var cls := Gear.weapon_class(probe) if probe["slot"] == "weapon" else "legionary"
	var before := Legion.power(Legion.gear_unit_stats(cls, 1))
	var after := Legion.power(Legion.gear_unit_stats(cls, 1, float(g["atk"]), float(g["hp"]), float(g["armor"])))
	details.add_child(ui._l(I18n.t("+%d силы") % (after - before), 18, true, ui.C_GOOD))
	details.add_child(ui._l(I18n.t("Без других вещей; редкость добавит силу."), 12, false, ui.C_SOFT))
	v.add_child(preview)
	v.add_child(ui._wl(Gear.stats_text(probe), 590, 14, ui.C_INK))
	var cost: Label = ui.hud._label(I18n.t("Материалы и время"), 15, true)
	v.add_child(cost)
	v.add_child(CampUI.attach(ui.hud)._cost_icons({"mats": Gear.craft_mats(ui._craft_kind, ui._craft_tier)}))
	v.add_child(ui._l(CampUI.duration_text(float(Gear.TIER_TIME[ui._craft_tier - 1]) / maxf(0.001, lg.time_k)), 15, true))
	v.add_child(ui._l(I18n.t("Шансы редкости при сборе"), 15, true))
	var odds := HBoxContainer.new()
	odds.add_theme_constant_override("separation", 12)
	for r in 5:
		odds.add_child(ui._l(I18n.t(String(Gear.RARITY[r])).capitalize() + " " + str(Gear.CRAFT_ODDS[r]) + "%", 12, true, Gear.color(r)))
	v.add_child(odds)
	var why := lg.can_craft(plot_id, ui._craft_kind, ui._craft_tier)
	v.add_child(ui._btn("Начать", 160, 17, null, why, func(): lg.craft_start(plot_id, ui._craft_kind, ui._craft_tier); ui._craft_win()))
	if why != "":
		v.add_child(ui._wl(I18n.t(why), 590, 13, ui.C_BAD))
	v.add_child(ui._hdiv(8))
	var queue := lg.craft_queue(plot_id)
	v.add_child(ui._l(I18n.t("Очередь: %d из %d") % [queue.size(), lg.craft_capacity(plot_id)], 18, true))
	if queue.is_empty():
		v.add_child(ui._l(I18n.t("Очередь пуста. Выберите вещь и нажмите «Начать»."), 14, false, ui.C_SOFT))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(590, minf(230, queue.size() * 116))
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
	for i in queue.size():
		var job: Dictionary = queue[i]
		var row := VBoxContainer.new()
		body.add_child(row)
		row.add_child(ui._l(I18n.t("%s · тир %d") % [I18n.t(String(Gear.CRAFT_TYPES[job["kind"]])), int(job["tier"])], 15, true))
		var status: Label = ui._l("", 14)
		row.add_child(status)
		var collect: Button = ui._btn("Собрать", 140, 14, null, "", func(): lg.craft_collect(plot_id); ui._craft_win())
		row.add_child(collect)
		var entry := {"kind": "craft", "plot": plot_id, "index": i, "label": status, "collect": collect}
		ui._live.append(entry)
		refresh(ui, entry)
		CampUI.attach(ui.hud)._add_speed(row, "craft_%d_%d" % [plot_id, i])
	v.add_child(ui._btn("Снаряжение", 160, 15, null, "", func(): ui.open_camp_window("store")))
	ui._center_later(panel)


static func refresh(ui: Variant, entry: Dictionary) -> void:
	var queue: Array = ui.lg.craft_queue(int(entry["plot"]))
	var i := int(entry["index"])
	if i >= queue.size():
		return
	var job: Dictionary = queue[i]
	var ready := float(job["left"]) <= 0.0
	var state := I18n.t("Готово") if ready else CampUI.clock_text(float(job["left"]))
	if not ready:
		if not ui.lg.craft_working(int(entry["plot"])):
			state += " · " + I18n.t("Пауза: нужен работник и готовая комната")
		else:
			for previous in i:
				if float(queue[previous]["left"]) > 0.0:
					state += " · " + I18n.t("В очереди")
					break
	(entry["label"] as Label).text = state
	var button: Button = entry["collect"]
	button.visible = ready
	button.disabled = ui.lg.store_count() >= ui.lg.store_cap()
	button.tooltip_text = I18n.t("Склад полон. Продайте или наденьте лишние вещи.") if button.disabled else ""
