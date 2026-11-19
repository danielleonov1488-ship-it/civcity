extends RefCounted
## Один состав окна на рецепт; значения и таймеры обновляются на месте.

const Kit = preload("res://scripts/ui_kit_a.gd")
const Ring = preload("res://scripts/fort_ui_ring.gd")
const KnowUI = preload("res://scripts/legion_knowledge_ui.gd")
const StoreUI = preload("res://scripts/legion_store_ui.gd")
const OUTFIT_ICONS := {"cook": "need_food", "smith": "craft", "scribe": "research",
	"priest": "need_faith", "builder": "build"}


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
	if not ui._craft_kind in kinds and not (room == "forge" and ui._craft_kind in Gear.WORK_OUTFITS):
		ui._craft_kind = String(kinds[0])
	var unlocked := lg.craft_tier_max(plot_id)
	ui._craft_tier = clampi(ui._craft_tier, 1, Gear.TIERS)
	var queue := lg.craft_queue(plot_id)
	var jobs := []
	for job: Dictionary in queue:
		jobs.append([job["kind"], job["tier"], job["total"]])
	var signature := str([plot_id, room, p["lv"], ui._craft_kind, ui._craft_tier, lg.fort.get("know", {}), jobs])
	var cached_v: Variant = ui.get_meta("craft_panel") if ui.has_meta("craft_panel") else null
	var cached: PanelContainer = cached_v as PanelContainer if is_instance_valid(cached_v) else null   # окно могли уже освободить
	if is_instance_valid(cached) and is_instance_valid(ui.overlay) and cached.get_parent() == ui.overlay and not ui.overlay.is_queued_for_deletion() and cached.get_meta("signature", "") == signature:
		ui._live = (cached.get_meta("live") as Array).duplicate()
		for entry: Dictionary in ui._live:
			if entry.get("kind") == "craft":
				refresh(ui, entry)
		return
	ui._live.clear()
	var panel: PanelContainer = ui._modal(960)
	panel.name = "CraftPanel"
	panel.set_meta("signature", signature)
	ui.set_meta("craft_panel", panel)
	var v: VBoxContainer = panel.get_child(0)
	var header := HBoxContainer.new()
	header.add_child(Kit.level_badge(int(p["lv"])))
	var title := Kit.ribbon(I18n.t("Кузница" if room == "forge" else "Оружейная"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var back := v.find_child("CampModalBack", false, false) as Button
	if back != null:
		v.remove_child(back)
		header.add_child(back)
	v.add_child(header)
	var recipes := HBoxContainer.new()
	recipes.alignment = BoxContainer.ALIGNMENT_CENTER
	recipes.add_theme_constant_override("separation", 24)
	v.add_child(recipes)
	var choices := HBoxContainer.new()
	choices.name = "CraftKinds"
	recipes.add_child(choices)
	for kind: String in kinds:
		var probe := Gear.craft_item(kind, ui._craft_tier)
		choices.add_child(_recipe(ui, kind, StoreUI.item_icon(CampUI.attach(ui.hud), probe)))
	if room == "forge":
		var clothes := HBoxContainer.new()
		clothes.name = "CraftOutfits"
		recipes.add_child(clothes)
		for kind: String in Gear.WORK_OUTFITS:
			clothes.add_child(_recipe(ui, kind, Kit.texture(OUTFIT_ICONS[kind])))
	var tiers := HBoxContainer.new()
	tiers.name = "CraftTiers"
	tiers.alignment = BoxContainer.ALIGNMENT_CENTER
	for tier in range(1, Gear.TIERS + 1):
		var b := Kit.round_button(null)
		b.name = "CraftTier_%d" % tier
		b.text = str(tier)
		var needed := lg.craft_knowledge(ui._craft_kind, tier)
		Kit.medallion_state(b, tier == ui._craft_tier)
		if needed != "":
			_recipe_lock(b, needed, 22)
			b.tooltip_text = lg.knowledge_requirement(needed)
		else:
			b.tooltip_text = I18n.t("Тир") + " %d" % tier if tier <= unlocked else I18n.t("Для тира %d нужен уровень комнаты %d") % [tier, Gear.tier_room_level(tier)]
		b.pressed.connect(func():
			ui._craft_tier = tier
			if needed != "":
				_open_tree(ui, plot_id, needed)
			else:
				ui._craft_win())
		tiers.add_child(b)
	v.add_child(tiers)
	var probe := Gear.craft_item(ui._craft_kind, ui._craft_tier)
	var preview := HBoxContainer.new()
	preview.name = "CraftPreview"
	preview.add_theme_constant_override("separation", 22)
	preview.add_child(CampUI.attach(ui.hud)._dweller_item_icon(probe, 108))
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.add_child(details)
	details.add_child(Kit.label(I18n.t(String(Gear.CRAFT_TYPES[ui._craft_kind])), 25))
	var work_outfit: bool = probe["slot"] == Gear.OUTFIT_SLOT
	if work_outfit:
		details.add_child(Kit.label(StoreUI.item_stats(lg, probe), 20))
	else:
		var g := Gear.tier_stats(probe)
		var cls: String = Gear.weapon_class(probe) if probe["slot"] == "weapon" else "legionary"
		var before := Legion.power(Legion.gear_unit_stats(cls, 1))
		var after := Legion.power(Legion.gear_unit_stats(cls, 1, float(g["atk"]), float(g["hp"]), float(g["armor"])))
		var power := HBoxContainer.new()
		power.add_child(Kit.image("star", Vector2(30, 30)))
		power.add_child(Kit.label("+%d" % (after - before), 28))
		power.tooltip_text = I18n.t("Без других вещей; редкость добавит силу.") + "\n" + Gear.stats_text(probe)
		details.add_child(power)
	var costs := CampUI.attach(ui.hud)._cost_icons({"mats": Gear.craft_mats(ui._craft_kind, ui._craft_tier)})
	details.add_child(costs)
	details.add_child(Kit.time_row(CampUI.duration_text(float(Gear.TIER_TIME[ui._craft_tier - 1]) / (maxf(0.001, lg.time_k) * lg.fort_work_speed(plot_id, room)))))
	v.add_child(preview)
	var odds := HBoxContainer.new()
	odds.name = "CraftRarityOdds"
	odds.alignment = BoxContainer.ALIGNMENT_CENTER
	odds.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	odds.add_theme_constant_override("separation", 10)
	var base_odds := lg.craft_odds()
	var rarity_odds: Array = [base_odds[0] + base_odds[1], 0,
		base_odds[2] + base_odds[3] + base_odds[4]] if work_outfit else base_odds
	for r in rarity_odds.size():
		if int(rarity_odds[r]) == 0:
			continue
		var chip := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Gear.color(r).darkened(0.35)
		style.set_corner_radius_all(12)
		style.content_margin_left = 13
		style.content_margin_right = 13
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		chip.add_theme_stylebox_override("panel", style)
		chip.add_child(Kit.label(str(rarity_odds[r]) + "%", 19, true))
		chip.tooltip_text = I18n.t("Шансы редкости при сборе") + "\n" + I18n.t(String(Gear.RARITY[r])).capitalize()
		odds.add_child(chip)
	preview.add_child(odds)
	var requirement := Kit.banner_red("")
	requirement.name = "CraftRequirement"
	v.add_child(requirement)
	var missing := lg.craft_knowledge(ui._craft_kind, ui._craft_tier)
	if missing != "":
		var lock := Kit.button("gold", KnowUI.node_icon(missing), lg.knowledge_requirement(missing))
		lock.name = "CraftLearnSmith" if missing == "smith" else "CraftKnowledgeLock"
		_recipe_lock(lock, missing, 26)
		lock.pressed.connect(_open_tree.bind(ui, plot_id, missing))
		v.add_child(lock)
	var materials := PackedStringArray()
	var need := Gear.craft_mats(ui._craft_kind, ui._craft_tier)
	for material: String in need:
		var phrase := String({"iron": "железо: %d", "wood": "дерево: %d", "leather": "кожа: %d"}[material])
		materials.append(I18n.t(phrase) % int(need[material]))
	var start := Kit.button("green", "craft", I18n.t("Ковать · %s") % " · ".join(materials))
	start.name = "CraftStart"
	start.tooltip_text = I18n.t("Ковать")
	start.pressed.connect(func():
		lg.craft_start(plot_id, ui._craft_kind, ui._craft_tier)
		ui._craft_win()
		var camp := CampUI.of(ui.hud)
		if camp != null:
			camp._layout_guide.call_deferred())
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(start)
	v.add_child(actions)
	var summary := Kit.label("", 20)
	summary.name = "CraftQueueCount"
	var queue_row := HBoxContainer.new()
	queue_row.name = "CraftQueue"
	queue_row.alignment = BoxContainer.ALIGNMENT_CENTER
	queue_row.add_theme_constant_override("separation", 16)
	summary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	queue_row.add_child(summary)
	v.add_child(queue_row)
	for i in lg.craft_capacity(plot_id):
		if i >= queue.size():
			var empty := Kit.slot("plus", false, 88)
			empty.tooltip_text = I18n.t("Очередь пуста. Выберите вещь и нажмите «Начать».")
			queue_row.add_child(empty)
			continue
		var job_row := HBoxContainer.new()
		job_row.add_theme_constant_override("separation", 12)
		queue_row.add_child(job_row)
		var job: Dictionary = queue[i]
		var item := Gear.craft_item(String(job["kind"]), int(job["tier"]))
		var slot := Kit.slot(StoreUI.item_icon(CampUI.attach(ui.hud), item), false, 88)
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot.tooltip_text = I18n.t(String(Gear.CRAFT_TYPES[job["kind"]]))
		job_row.add_child(slot)
		var ring := Ring.new()
		ring.name = "CraftTimerRing"
		ring.thickness = 5.0
		ring.tint = Color("ffcf56")
		slot.add_child(ring)
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var column := VBoxContainer.new()
		job_row.add_child(column)
		var status := Kit.label("", 18)
		status.name = "CraftTimer"
		column.add_child(status)
		var collect := Kit.button("gold", "collect", I18n.t("Собрать · %d") % 1)
		collect.name = "CraftCollect_%d" % i
		collect.tooltip_text = I18n.t("Собрать")
		collect.pressed.connect(func(): lg.craft_collect(plot_id); ui._craft_win())
		column.add_child(collect)
		var entry := {"kind": "craft", "plot": plot_id, "index": i, "label": status, "collect": collect, "ring": ring}
		ui._live.append(entry)
		refresh(ui, entry)
	var controls := {"kind": "craft", "plot": plot_id, "index": -1, "label": summary, "start": start, "requirement": requirement, "costs": costs}
	ui._live.append(controls)
	refresh(ui, controls)
	var store := Kit.button("cream", "equip", I18n.t("Снаряжение"))
	store.name = "CraftEquipment"
	store.custom_minimum_size.x = 190.0
	store.tooltip_text = I18n.t("Снаряжение")
	store.pressed.connect(func(): ui.close(); CampUI.attach(ui.hud).show_storage())
	actions.add_child(store)
	if room == "forge":
		var sets := Kit.round_button(KnowUI.node_icon("sets"))
		sets.tooltip_text = I18n.t("Реликвии легионов")
		if not lg.knows("sets"):
			_recipe_lock(sets, "sets", 24)
			sets.pressed.connect(_open_tree.bind(ui, plot_id, "sets"))
		else:
			sets.pressed.connect(_open_sets.bind(ui, plot_id))
		actions.add_child(sets)
	panel.set_meta("live", ui._live.duplicate())
	ui._center_later(panel)


static func _recipe(ui: Variant, kind: String, icon: Texture2D) -> Button:
	var button := Kit.round_button(icon)
	button.name = "CraftKind_" + kind
	button.tooltip_text = I18n.t(String(Gear.CRAFT_TYPES[kind]))
	Kit.medallion_state(button, kind == ui._craft_kind)
	var needed: String = ui.lg.craft_knowledge(kind, ui._craft_tier)
	if needed != "":
		_recipe_lock(button, needed, 25)
		button.tooltip_text += "\n" + ui.lg.knowledge_requirement(needed)
		button.pressed.connect(func():
			ui._craft_kind = kind
			_open_tree(ui, ui._craft_plot, needed))
	else:
		button.pressed.connect(func():
			ui._craft_kind = kind
			if kind == "sword" and ui.lg.fort_lesson() == "knowledge":
				ui.lg.flags["fort_lesson_recipe"] = true
				var camp := CampUI.of(ui.hud)
				if camp != null:
					camp._layout_guide.call_deferred()
			ui._craft_win())
	return button


static func _recipe_lock(button: Button, id: String, pixels: int) -> void:
	var chip := Kit.image(KnowUI.node_icon(id), Vector2.ONE * pixels)
	chip.position = Vector2(4, 4)
	button.add_child(chip)
	var lock := Kit.image(KnowUI.lock_icon(), Vector2(17, 17))
	lock.name = "CraftRecipeLock"
	button.add_child(lock)
	lock.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	lock.offset_left = -20
	lock.offset_top = 3
	lock.offset_right = -3
	lock.offset_bottom = 20


static func _open_tree(ui: Variant, plot: int, id: String) -> void:
	var camp := CampUI.attach(ui.hud)
	ui.close()
	camp.show_knowledge(id, func(): camp._close_modal(); ui.open_craft(plot))


static func _open_sets(ui: Variant, plot: int, kind := "sword") -> void:
	var lg: Legion = ui.lg
	var camp := CampUI.attach(ui.hud)
	ui.close()
	var body: VBoxContainer = camp._new_modal(700, true)
	var header := HBoxContainer.new()
	var title := Kit.label(I18n.t("Реликвии легионов"), 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(camp._button("×", func(): camp._close_modal(); ui.open_craft(plot)))
	body.add_child(header)
	var kinds := HBoxContainer.new()
	body.add_child(kinds)
	for key: String in ["sword", "bow", "staff", "spear", "helmet", "offhand", "armor"]:
		var it := Gear.craft_item(key, 1)
		var choice := Kit.round_button(StoreUI.item_icon(camp, it))
		Kit.medallion_state(choice, key == kind)
		choice.tooltip_text = I18n.t(Gear.CRAFT_TYPES[key])
		choice.pressed.connect(_open_sets.bind(ui, plot, key))
		kinds.add_child(choice)
	var slot := Gear.craft_slot(kind)
	var cls := String(Gear.KIND_CLS.get(kind, "legionary"))
	body.add_child(camp._cost_icons({"money": Gear.SET_FORGE["money"], "mats": lg.set_mats(slot)}))
	for set_id: String in Gear.SET_IDS:
		var name_text := I18n.t(Gear.SETS[set_id]["name"])
		var row := HBoxContainer.new()
		var label := Kit.label(name_text + " · " + str(lg.relics.get(set_id, 0)), 22)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var action := Kit.button("cream", "craft", I18n.t("Ковать"))
		var why := lg.can_forge_set(set_id, slot, cls)
		action.disabled = why != ""
		action.tooltip_text = I18n.t(why)
		action.pressed.connect(func():
			if lg.forge_set(set_id, slot, cls):
				camp._close_modal()
				ui.open_craft(plot))
		row.add_child(action)
		body.add_child(row)
	camp._fit_modal.call_deferred()


static func refresh(ui: Variant, entry: Dictionary) -> void:
	var queue: Array = ui.lg.craft_queue(int(entry["plot"]))
	var i := int(entry["index"])
	if i < 0:
		var why: String = ui.lg.can_craft(int(entry["plot"]), ui._craft_kind, ui._craft_tier)
		(entry["start"] as Button).disabled = why != ""
		(entry["start"] as Button).tooltip_text = I18n.t("Ковать") + ("\n" + I18n.t(why) if why != "" else "")
		var requirement: PanelContainer = entry["requirement"]
		requirement.visible = why != "" and ui.lg.craft_knowledge(ui._craft_kind, ui._craft_tier) == ""
		(requirement.get_meta("label") as Label).text = I18n.t(why)
		(entry["label"] as Label).text = "%d / %d" % [queue.size(), ui.lg.craft_capacity(int(entry["plot"]))]
		CampUI.attach(ui.hud)._refresh_costs(entry["costs"])
		var panel: Control = ui.get_meta("craft_panel") if ui.has_meta("craft_panel") else null
		if is_instance_valid(panel):
			ui._center_later(panel)
		return
	if i >= queue.size():
		return
	var job: Dictionary = queue[i]
	var ready := float(job["left"]) <= 0.0
	var plot_id := int(entry["plot"])
	var lg: Legion = ui.lg
	var speed := lg.fort_work_speed(plot_id, String(lg.fort_plot(plot_id).get("b", "")))
	var state := I18n.t("Готово") if ready else CampUI.clock_text(float(job["left"]) / speed)
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
