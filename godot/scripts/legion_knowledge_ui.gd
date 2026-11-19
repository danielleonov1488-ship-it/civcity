extends RefCounted

const Kit = preload("res://scripts/ui_kit_a.gd")
const Look = preload("res://scripts/legion_look.gd")
const Ring = preload("res://scripts/fort_ui_ring.gd")
const Data = preload("res://scripts/legion_knowledge.gd")
const POS := {
	"smith": Vector2(51, 299),
	"bows": Vector2(301, 45), "spears": Vector2(445, 45), "staffs": Vector2(589, 45),
	"weap3": Vector2(301, 155), "weap5": Vector2(445, 155), "weap7": Vector2(589, 155), "weap9": Vector2(733, 155),
	"armor1": Vector2(301, 283), "armor3": Vector2(445, 283), "armor5": Vector2(589, 283),
	"armor7": Vector2(733, 283), "armor9": Vector2(877, 283),
	"outfit": Vector2(301, 415), "outfit2": Vector2(445, 415),
	"smelt": Vector2(301, 554), "luck1": Vector2(445, 554), "luck2": Vector2(589, 554),
	"reforge": Vector2(733, 554), "sets": Vector2(877, 554),
}


static func art(group: String, id: String, fallback := "lock") -> Texture2D:
	var path := "res://assets/legion_ui/%s/%s.png" % [group, id]
	return load(path) as Texture2D if ResourceLoader.exists(path) else Look.icon(fallback)


static func node_icon(id: String) -> Texture2D:
	return art("know", String(Data.NODES[id]["art"]), "book")


static func lock_icon() -> Texture2D:
	return art("store", "lock")


static func build(ui: Variant, selected: String, back: Callable) -> void:
	var lg: Legion = ui.lg
	var body: VBoxContainer = ui._new_modal(1580, true)
	ui.modal_panel.name = "FortKnowledgeTree"
	ui.knowledge_focus = selected
	ui.knowledge_back = back
	ui.knowledge_sig = signature(lg)
	var header := HBoxContainer.new()
	var title := Look.label(I18n.t("Знание снаряжения"), 45, Look.INK, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Look.button("×", null, Look.INSET, Vector2(50, 48))
	close.pressed.connect(back if back.is_valid() else ui._close_modal)
	header.add_child(close)
	body.add_child(header)
	body.add_child(HSeparator.new())
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 26)
	body.add_child(columns)
	var graph := Control.new()
	graph.custom_minimum_size = Vector2(952, 648)
	columns.add_child(graph)
	for id: String in Data.NODES:
		for need: String in Data.NODES[id]["needs"]:
			var a: Vector2 = POS[need]
			var b: Vector2 = POS[id]
			var wire := Line2D.new()
			wire.width = 2.5
			wire.default_color = Look.BRONZE if lg.knows(need) else Look.EDGE.darkened(0.08)
			wire.antialiased = true
			var bend := (a.x + b.x) * 0.5
			if id == "staffs":
				wire.points = PackedVector2Array([a, Vector2(112, a.y), Vector2(112, 0), Vector2(b.x, 0), b])
			elif id in ["sets", "reforge"]:
				bend = b.x + 55.0 if id == "sets" else b.x - 55.0
				var lane := a.y + 53.0
				wire.points = PackedVector2Array([a, Vector2(a.x, lane), Vector2(bend, lane), Vector2(bend, b.y), b])
			else:
				bend = 112 if need == "smith" else bend
				wire.points = PackedVector2Array([a, Vector2(bend, a.y), Vector2(bend, b.y), b])
			graph.add_child(wire)
	for band: Array in [["Оружие", 22], ["Броня", 249], ["Одежда", 381], ["Мастерство", 520]]:
		var label := Look.label(I18n.t(String(band[0])), 24, Look.INK, true)
		label.position = Vector2(123, float(band[1]) - 9)
		graph.add_child(label)
	for id: String in Data.NODES:
		_add_node(ui, graph, id, selected, back)
	columns.add_child(_detail(ui, selected, back))
	ui._fit_modal.call_deferred()


static func _add_node(ui: Variant, graph: Control, id: String, selected: String, back: Callable) -> void:
	var lg: Legion = ui.lg
	var learned := lg.knows(id)
	var learning: bool = lg.knowledge_timer().get("id") == id
	var unlocked := lg.knowledge_gate(id) == ""
	var available := not learned and not learning and unlocked and lg._fort_afford(Data.NODES[id]) == ""
	var tint := Color("efd28b") if learned or learning or available else Look.EDGE
	var fill := Look.WINE if learned or learning or unlocked else Color("625a51")
	var diameter := 104.0 if id == "smith" else 86.0
	var button := Look.button("", node_icon(id), fill, Vector2.ONE * diameter, true)
	button.name = "KnowNode_" + id
	button.position = POS[id] - Vector2.ONE * diameter * 0.5
	button.size = Vector2.ONE * diameter
	button.tooltip_text = I18n.t(Data.NODES[id]["name"])
	button.add_theme_constant_override("icon_max_width", int(diameter - 20))
	button.add_theme_color_override("icon_normal_color", Color("aaa199") if not unlocked and not learned else Color.WHITE)
	for state: String in ["normal", "hover", "pressed"]:
		var style := Look.box(fill.lightened(0.13) if state == "hover" else fill, tint, 64, 8, 5 if available else 2)
		style.set_border_width_all(4 if selected == id or available else 2)
		button.add_theme_stylebox_override(state, style)
	graph.add_child(button)
	button.pressed.connect(ui.show_knowledge.bind(id, back))
	if learned:
		_badge(button, "✓", null, Vector2(diameter - 24, diameter - 21), Look.OLIVE)
	elif learning:
		var ring := Ring.new()
		ring.thickness = 5.0
		ring.tint = Color("ffd368")
		button.add_child(ring)
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var label := _badge(button, "", Kit.texture("time"), Vector2(0, diameter - 1), Look.DARK)
		label.set_meta("know_ring", ring)
		label.add_to_group("legion10_knowledge_clock")
	elif not unlocked:
		_badge(button, str(Data.NODES[id]["hq"]), lock_icon(), Vector2(diameter - 47, diameter - 18), Look.DARK)
	if id.begins_with("weap") or id.begins_with("armor"):
		var caption := Look.label(String(Data.NODES[id]["tiers"]), 17, Look.SOFT)
		caption.position = Vector2(6, diameter + 11)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(caption)


static func _badge(parent: Control, value: String, icon: Texture2D, at: Vector2, fill: Color) -> Label:
	var chip := Look.panel(fill, 3)
	chip.position = at
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(chip)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	if icon != null:
		row.add_child(Kit.image(icon, Vector2(18, 18)))
	var label := Look.label(value, 17, Look.PAPER)
	row.add_child(label)
	return label


static func _detail(ui: Variant, id: String, back: Callable) -> PanelContainer:
	var lg: Legion = ui.lg
	var node: Dictionary = Data.NODES[id]
	var panel := Look.panel(Look.INSET, 26)
	panel.name = "KnowledgeNodeCard"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body := VBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 22)
	panel.add_child(body)
	var icon := Kit.image(node_icon(id), Vector2(126, 126))
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(icon)
	var title := Look.label(I18n.t(node["name"]), 34, Look.INK, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(title)
	body.add_child(HSeparator.new())
	var unlocks := HBoxContainer.new()
	unlocks.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(unlocks)
	for kind: String in node["opens"]:
		var probe := Gear.craft_item(kind, 1)
		var art_icon: Texture2D
		if kind in ["staff", "spear"]:
			art_icon = node_icon(id)
		elif Gear.WORK_OUTFITS.has(kind):
			art_icon = Look.icon({"cook": "bread", "smith": "hammer", "scribe": "quests", "priest": "laurels", "builder": "build"}[kind])
		else:
			art_icon = ui.lu._gear_tex(Gear.icon_of(probe), String(probe["slot"]))
		unlocks.add_child(Kit.image(art_icon, Vector2(54, 54)))
	if unlocks.get_child_count() == 0:
		unlocks.add_child(Kit.image(node_icon(id), Vector2(48, 48)))
	if node["tiers"] != "":
		unlocks.add_child(Look.label(node["tiers"], 26))
	var cost: HBoxContainer = ui._cost_icons(node)
	cost.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(cost)
	var timer: Dictionary = lg.knowledge_timer()
	if timer.get("id") == id:
		var time := Look.label("", 27, Look.WINE)
		time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(time)
		time.add_to_group("legion10_knowledge_clock")
		var finish := Look.button("", Look.resource("ingots"), Look.WINE)
		finish.name = "FortFinishKnowledge"
		finish.pressed.connect(func():
			if lg.finish_knowledge_now(id):
				ui.show_knowledge(id, back))
		body.add_child(finish)
	else:
		var duration := Kit.time_row(CampUI.duration_text(lg.knowledge_seconds(id))) if int(node["hours"]) > 0 else Kit.time_row(I18n.t("Мгновенно"))
		duration.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		body.add_child(duration)
		var why := lg.can_learn(id)
		if why != "":
			var reason := Look.label(why, 24, Look.OLIVE if lg.knows(id) else Look.WINE)
			reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var row := HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_child(Kit.image(Look.icon("check") if lg.knows(id) else lock_icon(), Vector2(28, 28)))
			row.add_child(reason)
			body.add_child(row)
		else:
			var action := Look.button(I18n.t("Изучить"), node_icon(id), Look.WINE)
			action.name = "FortLearnSmith" if id == "smith" else "FortLearnKnowledge"
			action.pressed.connect(func():
				if lg.learn(id):
					ui.show_knowledge(id, back))
			body.add_child(action)
	return panel


static func signature(lg: Legion) -> String:
	var afford := []
	for id: String in Data.NODES:
		afford.append(lg.can_learn(id))
	return str([lg.fort.get("know", {}), lg.knowledge_timer().get("id", ""), lg.camp_level("hq"), afford])


static func refresh(ui: Variant) -> void:
	var lg: Legion = ui.lg
	if ui.knowledge_focus == "":
		return
	if ui.knowledge_sig != signature(lg):
		ui.show_knowledge(ui.knowledge_focus, ui.knowledge_back)
	var timer := lg.knowledge_timer()
	if timer.is_empty():
		return
	var left := float(timer["end"]) - Legion.now()
	var panel: Control = ui.modal_panel
	for label: Label in ui.get_tree().get_nodes_in_group("legion10_knowledge_clock"):
		if not panel.is_ancestor_of(label):
			continue
		label.text = CampUI.clock_text(left)
		if label.has_meta("know_ring"):
			label.get_meta("know_ring").set("value", 1.0 - left / maxf(1.0, float(timer["total"])))
	var finish := panel.find_child("FortFinishKnowledge", true, false) as Button
	if finish != null:
		var price := lg.knowledge_instant_price()
		finish.text = I18n.t("Мгновенно") + " · " + str(price)
		finish.disabled = lg.ingots < price
