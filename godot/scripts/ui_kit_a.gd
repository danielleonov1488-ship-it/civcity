class_name UiKitA
extends RefCounted
## Общие рамки и кнопки яркого форта. Размеры указаны до масштаба окна.

const ROOT := "res://assets/ui/kitA/"
const RES := "res://assets/fort/cutaway/icons/res_"
const BOLD = preload("res://assets/fonts/AlegreyaSans-ExtraBold.ttf")
const TITLE = preload("res://assets/fonts/Philosopher-Bold.ttf")
const INK := Color("48200b")
const CREAM := Color("fff4d9")
const BUTTON_HEIGHT := 80.0
const RES_BAR_SIZE := Vector2(264, 80)
const RES_BAR_CREAM := Rect2(78, 18, 152, 46)
const RES_BAR_FONT_SIZE := 28
const Ring = preload("res://scripts/fort_ui_ring.gd")
static var _textures: Dictionary = {}
static var _small_textures: Dictionary = {}


class CardPanel extends PanelContainer:
	var plate: NinePatchRect
	var plate_scale := 0.625

	func fit_plate() -> void:
		if is_instance_valid(plate):
			plate.position = Vector2.ZERO
			plate.scale = Vector2.ONE * plate_scale
			plate.size = size / plate_scale


static func texture(id: Variant) -> Texture2D:
	if id is Texture2D:
		return id as Texture2D
	if id == null or String(id) == "":
		return null
	var path := String(id)
	if not path.begins_with("res://"):
		path = ROOT + "icons/" + path + ".png"
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path] as Texture2D


static func resource(id: String) -> Texture2D:
	return texture(RES + ("denarii" if id == "money" else id) + ".png")


static func box(path: String, slice: float, pad := 12.0, draw_height := 0.0) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	var source := texture(ROOT + path + ".png")
	var ratio := minf(1.0, draw_height / source.get_height()) if draw_height > 0.0 else 1.0
	if ratio < 1.0:
		# Крупные рамки уменьшаем до 9-slice; поля остаются внутри кнопки.
		var key := "%s@%d" % [path, roundi(draw_height)]
		if not _small_textures.has(key):
			var pixels := source.get_image()
			if pixels.is_compressed():
				pixels.decompress()
			pixels.resize(maxi(1, roundi(source.get_width() * ratio)), maxi(1, roundi(draw_height)), Image.INTERPOLATE_LANCZOS)
			_small_textures[key] = ImageTexture.create_from_image(pixels)
		style.texture = _small_textures[key] as Texture2D
	else:
		style.texture = source
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, slice * ratio)
		style.set_content_margin(side, pad)
	return style


static func card(dims := Vector2.ZERO) -> PanelContainer:
	var panel := CardPanel.new()
	panel.custom_minimum_size = dims
	panel.set_meta("ui_kit_a", true)
	var margin := StyleBoxEmpty.new()
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		margin.set_content_margin(side, 40.0)
	panel.add_theme_stylebox_override("panel", margin)
	var plate := NinePatchRect.new()
	plate.texture = texture(ROOT + "panels/card_frame.png")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		plate.set_patch_margin(side, 64)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.plate = plate
	# Внутренняя рамка не меняет get_child(0) и минимальный размер содержимого.
	panel.add_child(plate, false, Node.INTERNAL_MODE_FRONT)
	panel.sort_children.connect(panel.fit_plate.call_deferred)
	panel.resized.connect(panel.fit_plate.call_deferred)
	return panel


static func inset() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box("panels/panel_inset", 40, 12))
	return panel


static func label(value: String, sz := 22, light := false) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_override("font", BOLD)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", CREAM if light else INK)
	l.add_theme_color_override("font_outline_color", Color("63320d") if light else Color("fff1c6"))
	l.add_theme_constant_override("outline_size", 3 if light else 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func image(tex: Variant, dims: Vector2) -> TextureRect:
	var pic := TextureRect.new()
	pic.texture = texture(tex)
	pic.custom_minimum_size = dims
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pic


static func ribbon(text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box("panels/ribbon_title", 64, 12, 64))
	panel.custom_minimum_size.y = 64
	var l := label(text, 30)
	l.add_theme_font_override("font", TITLE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(l)
	return panel


static func banner_red(text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box("panels/banner_red", 44, 9, 52))
	panel.custom_minimum_size.y = 52
	var row := HBoxContainer.new()
	row.add_child(image("exclaim", Vector2(40, 40)))
	var l := label(text, 20, true)
	l.name = "Requirement"
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	panel.add_child(row)
	panel.set_meta("label", l)
	return panel


static func progress(value: float, maximum: float, color := "gold", height := 20.0) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = maxf(1, maximum)
	bar.value = value
	bar.step = 0.001
	bar.custom_minimum_size.y = height
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", box("panels/bar_frame", 32, 0, height))
	bar.add_theme_stylebox_override("fill", box("panels/bar_fill_" + color, 20, 0, height))
	return bar


static func res_bar(icon: Variant, value: float, maximum: float, fit_number := false) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "ResourceBar"
	var frame := box("panels/topbar_pill", 32, 0, 80)
	# Медальон и торец не растягиваются вместе с серединой плашки.
	frame.set_texture_margin(SIDE_LEFT, 72)
	frame.set_texture_margin(SIDE_RIGHT, 32)
	panel.add_theme_stylebox_override("panel", frame)
	panel.custom_minimum_size = RES_BAR_SIZE
	# Свободное расположение сохраняет крупный медальон слева.
	var body := Control.new()
	panel.add_child(body)
	var pic := image(icon, Vector2(72, 72))
	pic.position = Vector2(2, 4)
	body.add_child(pic)
	var number := label(str(int(value)) + (" / %d" % int(maximum) if maximum > 0 else ""), RES_BAR_FONT_SIZE)
	number.name = "Value"
	number.clip_text = fit_number
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.add_child(number)
	# Сразу тонкая полоса: до входа в дерево минимум 20 мог остаться в кэше.
	var fill := progress(value / maxf(1, maximum), 1, "green" if maximum <= 0 else "gold", 9)
	fill.name = "Fill"
	body.add_child(fill)
	panel.set_meta("number", number)
	panel.set_meta("fill", fill)
	panel.resized.connect(layout_res_bar.bind(panel))
	number.minimum_size_changed.connect(layout_res_bar.bind(panel))
	layout_res_bar(panel)
	return panel


static func layout_res_bar(panel: PanelContainer) -> void:
	# Все отступы считаем внутри крема; масштаб HUD наследуется один раз.
	var ratio := panel.size.max(RES_BAR_SIZE) / RES_BAR_SIZE
	var cream := Rect2(RES_BAR_CREAM.position * ratio, RES_BAR_CREAM.size * ratio)
	var number: Label = panel.get_meta("number")
	number.position = cream.position + Vector2(4, 2) * ratio
	number.size = Vector2(cream.size.x - 12 * ratio.x, 32 * ratio.y)
	if number.clip_text:
		# Число с потолком подгоняем по ширине строки с обводкой.
		var available := number.size.x - 2.0 * number.get_theme_constant("outline_size")
		var font := number.get_theme_font("font")
		var font_size := RES_BAR_FONT_SIZE
		while font_size > 1 and font.get_string_size(number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available:
			font_size -= 1
		if number.get_theme_font_size("font_size") != font_size:
			number.add_theme_font_size_override("font_size", font_size)
	var fill: ProgressBar = panel.get_meta("fill")
	fill.custom_minimum_size = Vector2(138, 9) * ratio
	# Шрифт может быть выше заданной строки: полоса начинается после числа.
	fill.position = Vector2(cream.position.x + 6 * ratio.x, maxf(cream.position.y + 35 * ratio.y, number.get_rect().end.y))
	fill.size = Vector2(cream.size.x - 14 * ratio.x, 9 * ratio.y)


static func button(kind: String, icon: Variant = null, text := "") -> Button:
	var b := Button.new()
	style_button(b, kind)
	b.disabled = kind == "disabled"
	b.text = text
	b.icon = texture(icon)
	b.tooltip_text = I18n.t(text) if text != "" else I18n.t(String({"plus": "Добавить", "back": "Назад", "swap": "Сменить", "assign": "Назначить", "craft": "Ковать", "collect": "Собрать", "upgrade": "Улучшить", "build": "Строить", "equip": "Снаряжение", "info": "Сведения"}.get(str(icon), "Сведения")))
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 42)
	b.add_theme_constant_override("h_separation", 10)
	b.custom_minimum_size = Vector2(120, BUTTON_HEIGHT)
	b.set_meta("kit_role", "action")
	return b


static func style_button(b: Button, kind := "cream") -> void:
	b.set_meta("ui_kit_a", true)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", BOLD)
	b.add_theme_font_size_override("font_size", 22)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var tint := "disabled" if state == "disabled" else kind
		var suffix := "_pressed" if state in ["pressed", "hover_pressed"] else ""
		var style := box("buttons/btn_" + tint + suffix, 56, 10, 64)
		if state == "hover":
			style.modulate_color = Color(1.12, 1.08, 1.0)
		b.add_theme_stylebox_override(state, style)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("fff1b0")
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(20)
	b.add_theme_stylebox_override("focus", focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, CREAM if kind in ["green", "red"] else INK)
	b.add_theme_color_override("font_outline_color", Color("60330b") if kind in ["green", "red"] else CREAM)
	b.add_theme_constant_override("outline_size", 3)
	b.add_theme_color_override("font_disabled_color", Color("5e4a36"))
	b.add_theme_color_override("icon_disabled_color", Color(0.7, 0.65, 0.58))


static func _round(icon: Variant, pixels: float, frame: String) -> Button:
	var b := button("cream")
	b.set_meta("kit_role", "medallion")
	b.custom_minimum_size = Vector2.ONE * pixels
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := box(frame, 0, 0)
		if state == "pressed":
			style.modulate_color = Color(0.8, 0.72, 0.6)
		elif state == "hover":
			style.modulate_color = Color(1.15, 1.1, 1.0)
		b.add_theme_stylebox_override(state, style)
	var pic := image(icon, Vector2.ZERO)
	pic.name = "ic"
	b.add_child(pic)
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.anchor_left = 0.18
	pic.anchor_top = 0.18
	pic.anchor_right = 0.82
	pic.anchor_bottom = 0.82
	return b


static func round_button(icon: Variant, badge_count := 0) -> Button:
	var b := _round(icon, BUTTON_HEIGHT, "buttons/round_frame")
	var counter := badge(b, str(badge_count))
	counter.visible = badge_count > 0
	return b


static func round_big(icon: Variant) -> Button:
	return _round(icon, 150, "buttons/round_frame_big")


static func close_button() -> Button:
	var b := _round(null, BUTTON_HEIGHT, "buttons/close_btn")
	b.set_meta("kit_role", "close")
	b.tooltip_text = I18n.t("Закрыть")
	return b


static func medallion_state(b: Button, selected: bool, locked := false) -> void:
	b.set_meta("selected", selected)
	b.set_meta("locked", locked)
	b.disabled = locked
	b.self_modulate = Color(0.5, 0.5, 0.5) if locked else Color.WHITE
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(state, CREAM)
	b.add_theme_color_override("font_outline_color", INK)
	var pic := b.get_node("ic") as TextureRect
	pic.modulate = Color(0.55, 0.55, 0.55) if locked else Color.WHITE
	var ring := Ring.new()
	ring.name = "SelectionRing"
	ring.value = 1.0
	ring.tint = Color("ffe781")
	ring.thickness = 5.0
	ring.visible = selected and not locked
	b.add_child(ring)
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var lock := image("lock", Vector2.ZERO)
	lock.name = "MedallionLock"
	lock.visible = locked
	b.add_child(lock)
	lock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	lock.offset_left = -30
	lock.offset_top = -30
	lock.offset_right = -5
	lock.offset_bottom = -5


static func fit_modal(panel: Control, viewport: Vector2, minimum := Vector2.ZERO, max_scale := 1.0) -> void:
	# Размер содержимого задаём до масштаба: дети и фон уменьшаются вместе.
	panel.scale = Vector2.ONE
	panel.size = panel.get_combined_minimum_size().max(minimum)
	var dims := panel.size
	var available := (viewport - Vector2.ONE * 48.0).max(Vector2.ONE)
	var k := minf(max_scale, minf(available.x / maxf(1, dims.x), available.y / maxf(1, dims.y)))
	panel.scale = Vector2.ONE * k
	panel.position = ((viewport - dims * k) * 0.5).floor()


static func badge(parent: Control, text := "") -> Label:
	var l := label(text, 20, true)
	l.name = "Counter"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(32, 32)
	l.add_theme_stylebox_override("normal", box("buttons/badge_counter", 0, 1))
	parent.add_child(l)
	l.position = Vector2(parent.custom_minimum_size.x - 25, -4)
	return l


static func level_badge(n: int) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(76, 76)
	frame.add_theme_stylebox_override("panel", box("buttons/level_badge", 0, 6))
	var l := label(str(n), 36, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	frame.add_child(l)
	return frame


static func slot(icon_or_texture: Variant = null, round := false, pixels := 84.0) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2.ONE * pixels
	panel.add_theme_stylebox_override("panel", box("panels/slot_round" if round else "panels/slot_frame", 0, 9))
	if icon_or_texture != null:
		panel.add_child(image(icon_or_texture, Vector2.ONE * (pixels - 18)))
	return panel


static func time_row(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(image("timer", Vector2(26, 26)))
	row.add_child(label(text, 19))
	return row
