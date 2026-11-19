extends RefCounted

const Kit = preload("res://scripts/ui_kit_a.gd")
const Look = preload("res://scripts/legion_look.gd")
const Ring = preload("res://scripts/fort_ui_ring.gd")
const Data = preload("res://scripts/legion_knowledge.gd")
const MEDIUM = preload("res://assets/fonts/AlegreyaSans-Medium.ttf")
const POS := {
	"smith": Vector2(64, 350),
	"bows": Vector2(378, 57), "spears": Vector2(514, 57), "staffs": Vector2(650, 57),
	"weap3": Vector2(378, 195), "weap5": Vector2(514, 195), "weap7": Vector2(650, 195), "weap9": Vector2(786, 195),
	"reforge": Vector2(446, 279), "sets": Vector2(582, 279),
	"armor1": Vector2(378, 408), "armor3": Vector2(514, 408), "armor5": Vector2(650, 408),
	"armor7": Vector2(786, 408), "armor9": Vector2(922, 408),
	"outfit": Vector2(378, 546), "outfit2": Vector2(514, 546),
	"smelt": Vector2(378, 684), "luck1": Vector2(514, 684), "luck2": Vector2(650, 684),
}
const BRANCHES := [
	["Оружие", "weapon", "bows"], ["Броня", "armor", "armor1"],
	["Одежда", "outfit", "outfit"], ["Мастерство", "material", "smelt"],
]
const NOTES := {
	"smith": "Открывает изготовление мечей.",
	"bows": "Открывает изготовление луков для лучников.",
	"staffs": "Открывает изготовление посохов для жрецов.",
	"spears": "Открывает изготовление копий для конницы.",
	"outfit": "Открывает пошив рабочей одежды.",
	"outfit2": "Усиливает бонус рабочей одежды.",
	"smelt": "Даёт больше материалов при разборе вещей.",
	"reforge": "Позволяет повысить уровень готовой вещи.",
	"luck1": "Повышает шанс выковать редкую вещь.",
	"luck2": "Повышает шанс выковать редкую вещь.",
	"sets": "Открывает ковку комплектов снаряжения.",
}


static func art(group: String, id: String, fallback := "lock") -> Texture2D:
	var path := "res://assets/legion_ui/%s/%s.png" % [group, id]
	return Kit.texture(path) if ResourceLoader.exists(path) else Look.icon(fallback)


static func node_icon(id: String) -> Texture2D:
	return art("know", String(Data.NODES[id]["art"]), "book")


static func lock_icon() -> Texture2D:
	return art("store", "lock")


static func build(ui: Variant, selected: String, back: Callable) -> void:
	var lg: Legion = ui.lg
	var body: VBoxContainer = ui._new_framed_modal(1664)
	ui.modal_panel.name = "FortKnowledgeTree"
	ui.knowledge_focus = selected
	ui.knowledge_back = back
	ui.knowledge_sig = signature(lg)
	var header := HBoxContainer.new()
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 58.0
	header.add_child(spacer)
	header.add_child(Look.heading(I18n.t("Знание снаряжения"), 47))
	var close := Look.close_button(back if back.is_valid() else ui._close_modal, 58)
	close.name = "FortKnowledgeBack"
	header.add_child(close)
	body.add_child(header)
	body.add_child(Look.divider())
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	body.add_child(columns)
	var graph := Control.new()
	graph.custom_minimum_size = Vector2(985, 779)
	columns.add_child(graph)
	_connections(lg, graph)
	for branch: Array in BRANCHES:
		_branch_plate(graph, String(branch[0]), String(branch[1]), (POS[branch[2]] as Vector2).y)
	for id: String in Data.NODES:
		_add_node(ui, graph, id, selected, back)
	columns.add_child(_detail(ui, selected, back))
	ui._fit_modal.call_deferred()


static func _connections(lg: Legion, graph: Control) -> void:
	var root: Vector2 = POS["smith"]
	var bronze := Color("8c5b32")
	var muted := Color("b39b7d")
	var root_color := bronze if lg.knows("smith") else muted
	var first: Vector2 = POS["bows"]
	var last: Vector2 = POS["smelt"]
	_wire(graph, [root, Vector2(137, root.y)], root_color)
	_wire(graph, [Vector2(157, first.y), Vector2(137, first.y), Vector2(137, last.y), Vector2(157, last.y)], root_color)
	for id: String in ["bows", "weap3", "armor1", "outfit", "smelt"]:
		var start: Vector2 = POS[id]
		_wire(graph, [Vector2(137, start.y), start], root_color)
	for id: String in Data.NODES:
		for need: String in Data.NODES[id]["needs"]:
			var a: Vector2 = POS[need]
			var b: Vector2 = POS[id]
			var color := bronze if lg.knows(need) else muted
			if id == "staffs":
				_wire(graph, [Vector2(325, b.y), Vector2(335, b.y), Vector2(335, 6), Vector2(b.x, 6), b], color)
			elif id == "sets" and need == "armor5":
				_wire(graph, [a, Vector2(634, a.y - 45.0), Vector2(634, b.y + 20.0), b + Vector2(18, 20), b], color)
			elif id in ["sets", "reforge"]:
				var elbow := a.x + 57.0
				_wire(graph, [a, Vector2(elbow, a.y), Vector2(elbow, b.y), b], color)
			elif need != "smith":
				_wire(graph, [a, b], color)


static func _wire(graph: Control, points: Array[Vector2], color: Color) -> void:
	var wire := Line2D.new()
	wire.width = 3.0
	wire.default_color = color
	wire.antialiased = true
	var path := Curve2D.new()
	path.add_point(points[0])
	for j in range(1, points.size() - 1):
		var corner := points[j]
		var entry := (points[j - 1] - corner).normalized() * minf(12.0, corner.distance_to(points[j - 1]) * 0.5)
		var exit := (points[j + 1] - corner).normalized() * minf(12.0, corner.distance_to(points[j + 1]) * 0.5)
		path.add_point(corner + entry, Vector2.ZERO, -entry * 0.65)
		path.add_point(corner + exit, -exit * 0.65)
	path.add_point(points[-1])
	wire.points = path.tessellate()
	graph.add_child(wire)


static func _branch_plate(graph: Control, title: String, icon_id: String, y: float) -> void:
	var plate := PanelContainer.new()
	var skin := Kit.box("panels/ribbon_title", 68, 8, 53)
	skin.modulate_color = Color("ead4b1")
	plate.add_theme_stylebox_override("panel", skin)
	plate.position = Vector2(154, y - 26)
	plate.size = Vector2(176, 53)
	graph.add_child(plate)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	plate.add_child(row)
	row.add_child(Kit.image(art("store", icon_id), Vector2.ONE * 27))
	var caption := Look.label(I18n.t(title), 21, Look.INK, true)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(caption)


static func _add_node(ui: Variant, graph: Control, id: String, selected: String, back: Callable) -> void:
	var lg: Legion = ui.lg
	var node: Dictionary = Data.NODES[id]
	var learned := lg.knows(id)
	var timer := lg.knowledge_timer()
	var learning: bool = timer.get("id") == id
	var locked := not learned and not learning and lg.knowledge_gate(id) != ""
	var ready := not learned and not learning and not locked and lg._fort_afford(node) == ""
	var diameter := 117.0 if id == "smith" else (58.0 if id in ["sets", "reforge"] else 89.0)
	var center: Vector2 = POS[id]
	var corner := center - Vector2.ONE * diameter * 0.5
	if ready:
		var halo := Panel.new()
		var glow := Look.box(Color("ffe794"), Color("fff0a9"), 64, 0, 6)
		glow.shadow_color = Color("ffbd427f")
		glow.shadow_offset = Vector2.ZERO
		halo.add_theme_stylebox_override("panel", glow)
		halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		halo.position = corner - Vector2.ONE * 2
		halo.size = Vector2.ONE * (diameter + 4)
		graph.add_child(halo)
	var button := Kit.round_button(node_icon(id))
	button.name = "KnowNode_" + id
	button.custom_minimum_size = Vector2.ONE * diameter
	button.size = Vector2.ONE * diameter
	button.position = corner
	button.tooltip_text = I18n.t(node["name"])
	graph.add_child(button)
	button.pressed.connect(ui.show_knowledge.bind(id, back))
	if locked:
		for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
			var tone := Color("786956") if state == "hover" else Color("665846")
			var skin := Look.box(tone, Color("ac926d"), 64, 0, 2)
			skin.set_border_width_all(3)
			button.add_theme_stylebox_override(state, skin)
		(button.get_node("ic") as TextureRect).modulate = Color("b9ab98")
	if learning or selected == id or ready:
		var ring := Ring.new()
		ring.thickness = 4.0 if learning else 3.0
		ring.tint = Color("ffdc76") if not locked else Color("dfc7a5")
		button.add_child(ring)
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ring.value = _progress(timer) if learning else 1.0
		if learning:
			var clock := _badge(graph, center + Vector2(0, diameter * 0.5 + 24), CampUI.clock_text(float(timer["end"]) - Legion.now()),
				Kit.texture("timer"), Look.DARK, Look.PAPER, 98, "KnowledgeClock_" + id)
			clock.set_meta("know_ring", ring)
			clock.add_to_group("legion10_knowledge_clock")
	if learned:
		var marker := Look.panel(Color("916020"), 0)
		var rim := Look.box(Color("916020"), Color("f5d277"), 18, 0, 2)
		rim.set_border_width_all(2)
		marker.add_theme_stylebox_override("panel", rim)
		marker.size = Vector2.ONE * 26
		marker.position = corner + Vector2.ONE * (diameter - 25.0) + Vector2(0, -6)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		graph.add_child(marker)
		marker.add_child(Kit.image(Look.icon("check"), Vector2.ONE * 20))
	elif locked:
		_badge(graph, center + Vector2(0, diameter * 0.5 + 24), I18n.t("Штаб %d") % int(node["hq"]),
			lock_icon(), Color("dcc4a1"), Look.INK, 75, "KnowledgeLock_" + id)
	var tier: String = node["tiers"]
	_badge(graph, center + Vector2(0, diameter * 0.5 + 1), I18n.t(tier) if tier != "" else "—",
		null, Color("f1dcb9"), Look.INK, 64, "KnowledgeTier_" + id)


static func _badge(graph: Control, center_top: Vector2, value: String, icon: Texture2D,
		fill: Color, ink: Color, width: float, node_name: String) -> Label:
	var chip := Look.panel(fill, 0)
	chip.add_theme_stylebox_override("panel", Look.box(fill, Look.BRONZE, 6, 0))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.name = node_name
	graph.add_child(chip)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 3)
	chip.add_child(row)
	if icon != null:
		row.add_child(Kit.image(icon, Vector2(16, 16)))
	var label := Look.label(value, 15 if icon != null else 16, ink)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var fitted_width := maxf(width, row.get_combined_minimum_size().x + 8.0)
	chip.size = Vector2(fitted_width, 21)
	chip.position = center_top - Vector2(fitted_width * 0.5, 0)
	return label


static func _detail(ui: Variant, id: String, back: Callable) -> PanelContainer:
	var lg: Legion = ui.lg
	var node: Dictionary = Data.NODES[id]
	var panel := Kit.inset()
	panel.add_theme_stylebox_override("panel", Kit.box("panels/panel_inset", 40, 24))
	panel.name = "KnowledgeNodeCard"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 21)
	panel.add_child(body)
	var intro := HBoxContainer.new()
	intro.add_theme_constant_override("separation", 20)
	body.add_child(intro)
	var medal := PanelContainer.new()
	medal.custom_minimum_size = Vector2(146, 146)
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	medal.add_theme_stylebox_override("panel", Kit.box("buttons/round_frame", 0, 24))
	medal.add_child(Kit.image(node_icon(id), Vector2(94, 94)))
	intro.add_child(medal)
	var summary := VBoxContainer.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.alignment = BoxContainer.ALIGNMENT_CENTER
	summary.add_theme_constant_override("separation", 9)
	intro.add_child(summary)
	var title := Look.label(I18n.t(node["name"]), 34, Look.INK, true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_child(title)
	summary.add_child(_unlocks(ui, id, node))
	var note := Look.label(I18n.t(String(NOTES.get(id, "Открывает ковку снаряжения этих уровней."))), 21, Look.SOFT)
	note.add_theme_font_override("font", MEDIUM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_child(note)
	_detail_space(body)
	body.add_child(Look.divider())
	body.add_child(Look.label(I18n.t("Стоимость изучения"), 26, Look.INK, true))
	body.add_child(_cost_tiles(ui, node))
	body.add_child(Look.divider())
	var timer := lg.knowledge_timer()
	var learning: bool = timer.get("id") == id
	var seconds := lg.knowledge_seconds(id)
	var duration := CampUI.duration_text(seconds) if seconds > 0.0 else I18n.t("Мгновенно")
	if seconds >= 3600.0 and seconds < 86400.0 and is_zero_approx(fmod(seconds, 3600.0)):
		duration = I18n.t("%d ч") % roundi(seconds / 3600.0)
	var time := Kit.time_row(CampUI.clock_text(float(timer["end"]) - Legion.now()) if learning else duration)
	var time_value := time.get_child(1) as Label
	time_value.add_theme_font_size_override("font_size", 27)
	body.add_child(time)
	_detail_space(body)
	if learning:
		time_value.add_to_group("legion10_knowledge_clock")
		var price := lg.knowledge_instant_price()
		var finish := Kit.button("red", Look.resource("ingots"), I18n.t("Мгновенно") + " · " + str(price))
		finish.name = "FortFinishKnowledge"
		finish.disabled = lg.ingots < price
		finish.pressed.connect(func():
			if lg.finish_knowledge_now(id):
				ui.show_knowledge(id, back))
		body.add_child(finish)
	else:
		var why := lg.can_learn(id)
		if why != "":
			var reason := Look.label(why, 22, Look.OLIVE if lg.knows(id) else Look.WINE)
			var status := HBoxContainer.new()
			status.alignment = BoxContainer.ALIGNMENT_CENTER
			status.add_child(Kit.image(Look.icon("check") if lg.knows(id) else lock_icon(), Vector2(26, 26)))
			status.add_child(reason)
			body.add_child(status)
		var action := _learn_button(why != "")
		action.name = "FortLearnSmith" if id == "smith" else "FortLearnKnowledge"
		action.tooltip_text = why
		action.pressed.connect(func():
			if not lg.learn(id):
				return
			if id == "smith" and lg.fort_lesson() == "knowledge" and back.is_valid():
				back.call()
			else:
				ui.show_knowledge(id, back))
		body.add_child(action)
	return panel


static func _detail_space(body: VBoxContainer) -> void:
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(space)


static func _unlocks(ui: Variant, id: String, node: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	for kind: String in node["opens"]:
		var icon: Texture2D = node_icon(id)
		if Gear.WORK_OUTFITS.has(kind):
			icon = Look.icon({"cook": "bread", "smith": "hammer", "scribe": "quests", "priest": "laurels", "builder": "build"}[kind])
		elif kind not in ["staff", "spear", "bow"]:
			var probe := Gear.craft_item(kind, 1)
			icon = ui.lu._gear_tex(Gear.icon_of(probe), String(probe["slot"]))
		var chip := Look.panel(Color("f1e1c7"), 3)
		chip.add_child(Kit.image(icon, Vector2.ONE * 34))
		row.add_child(chip)
	var tier: String = node["tiers"]
	if tier.contains("–"):
		var bounds := tier.split("–")
		row.add_child(_value_chip(bounds[0]))
		var arrow := Look.label("→", 24, Look.BRONZE, true)
		arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(arrow)
		row.add_child(_value_chip(bounds[1], true))
	elif tier != "":
		row.add_child(_value_chip(I18n.t(tier)))
	return row


static func _value_chip(value: String, accent := false) -> PanelContainer:
	var chip := Look.panel(Look.WINE if accent else Color("f1e1c7"), 5)
	chip.custom_minimum_size = Vector2(37, 0)
	var number := Look.label(value, 22, Look.PAPER if accent else Look.INK, true)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(number)
	return chip


static func _cost_tiles(ui: Variant, node: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	var amounts: Dictionary = node["mats"].duplicate()
	amounts["money"] = node["money"]
	var labels := {}
	for resource: String in ["money", "iron", "wood", "leather"]:
		if not amounts.has(resource):
			continue
		var tile := Look.panel(Color("ead5b4"), 8)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tile)
		var pair := HBoxContainer.new()
		pair.alignment = BoxContainer.ALIGNMENT_CENTER
		pair.add_child(Kit.image(Look.resource(resource), Vector2.ONE * 42))
		var number := Look.label(ui.hud.fmt(float(amounts[resource])), 27)
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pair.add_child(number)
		tile.add_child(pair)
		labels[resource] = number
	row.set_meta("cost", amounts)
	row.set_meta("cost_labels", labels)
	ui._refresh_costs(row)
	return row


static func _learn_button(disabled: bool) -> Button:
	var action := Kit.button("red", null, I18n.t("Изучить"))
	action.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action.custom_minimum_size = Vector2(0, 79)
	action.add_theme_font_override("font", Kit.TITLE)
	action.add_theme_font_size_override("font_size", 33)
	action.add_theme_color_override("font_disabled_color", Color("352b22"))
	action.add_theme_constant_override("outline_size", 0)
	action.disabled = disabled
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		var style := action.get_theme_stylebox(state).duplicate() as StyleBoxTexture
		style.modulate_color *= Color("be9c99")
		action.add_theme_stylebox_override(state, style)
	for right: bool in [false, true]:
		var sprig := Look.sprig(41, right)
		if disabled:
			sprig.modulate = Color("a39990")
		action.add_child(sprig)
		sprig.set_anchors_preset(Control.PRESET_CENTER_RIGHT if right else Control.PRESET_CENTER_LEFT)
		sprig.offset_left = -66.0 if right else 25.0
		sprig.offset_right = -25.0 if right else 66.0
		sprig.offset_top = -21.0
		sprig.offset_bottom = 20.0
	return action


static func _progress(timer: Dictionary) -> float:
	return 1.0 - (float(timer["end"]) - Legion.now()) / maxf(1.0, float(timer["total"]))


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
	var panel: Control = ui.modal_panel
	ui._refresh_costs(panel)
	var timer := lg.knowledge_timer()
	if timer.is_empty():
		return
	var left := float(timer["end"]) - Legion.now()
	for label: Label in ui.get_tree().get_nodes_in_group("legion10_knowledge_clock"):
		if not panel.is_ancestor_of(label):
			continue
		label.text = CampUI.clock_text(left)
		if label.has_meta("know_ring"):
			label.get_meta("know_ring").set("value", _progress(timer))
	var finish := panel.find_child("FortFinishKnowledge", true, false) as Button
	if finish != null:
		var price := lg.knowledge_instant_price()
		finish.text = I18n.t("Мгновенно") + " · " + str(price)
		finish.disabled = lg.ingots < price
