class_name CityStyle
extends RefCounted
## Городские окна: крем, олива, простые силуэты. Легион использует свой комплект.

const MapBadge = preload("res://scripts/map_badge.gd")
const CREAM := Color("f3e6cc")
const OLIVE := Color("4f5b2e")
const INK := Color("4a2c17")
const RIM := Color("9b9468")
const CLASS_ICON := {"plebs": "person", "artisans": "hammer", "patricians": "toga"}
const ALIAS := {"star": "laurels", "upgrade": "level", "up": "level", "floor": "level", "worker": "person", "chest": "coins", "build": "hammer", "craft": "anvil", "map": "view", "soldier": "shield", "tasks": "scroll", "close_btn": "close", "level_badge": "level", "need_services": "services", "need_food": "food", "need_goods": "goods"}


static func icon(key: String) -> Texture2D:
	var id: String = ALIAS.get(key.trim_suffix("_m"), key.trim_suffix("_m"))
	id = String({"trees": "tree", "green": "tree", "flowers": "flower", "quiet": "sleep", "market": "commerce", "square": "plaza", "temple": "faith", "pious": "faith"}.get(id, id))
	if id in ["face_good", "face_mid", "face_bad"]:
		id = "happy"
	if id == "scales":
		return load("res://assets/ui/olive/scales.png") as Texture2D
	return MapBadge.ink_texture(id)


static func pictogram(key: String, side := 26) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = icon(key)
	picture.set_meta("city_icon", key)
	picture.custom_minimum_size = Vector2(side, side)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.modulate = Color.WHITE if key == "scales" else OLIVE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture


static func panel(radius := 12, padding := 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CREAM
	style.border_color = RIM
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, padding)
	return style


static func button(b: Button, disc := false) -> void:
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var style := panel(32 if disc else 16, 4 if disc else 8)
		style.content_margin_top = 3
		style.content_margin_bottom = 3
		if state in ["hover", "pressed", "hover_pressed"]:
			style.bg_color = Color("e5d8b8")
		if state == "focus":
			style.border_color = OLIVE
			style.set_border_width_all(2)
		if state == "disabled":
			style.bg_color = Color("eee5d1")
			style.border_color = Color("bcb79a")
		b.add_theme_stylebox_override(state, style)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, INK)
	for state: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		b.add_theme_color_override(state, OLIVE)
	b.add_theme_color_override("font_disabled_color", Color(INK, 0.45))
	b.add_theme_color_override("icon_disabled_color", Color(OLIVE, 0.35))
	b.add_theme_constant_override("icon_max_width", 24)
	b.add_theme_constant_override("h_separation", 6)
	b.expand_icon = true
	b.set_meta("city_button", true)


## ico() хранит имя даже у ImageTexture: путь картинки не теряется при уменьшении.
static func _key(texture: Texture2D) -> String:
	if texture == null:
		return ""
	if texture.has_meta("icon_key"):
		return String(texture.get_meta("icon_key"))
	var path := texture.resource_path
	if "/icons/" in path:
		return path.get_file().get_basename()
	if path.get_file().begins_with("class_"):
		return String(CLASS_ICON.get(path.get_file().get_basename().trim_prefix("class_"), "person"))
	return ""


## Применяем только к выбранному городскому окну, не к верхней полосе и меню стройки.
static func apply(root: Control) -> void:
	if root == null:
		return
	if root is TextureRect:
		var picture := root as TextureRect
		var key := _key(picture.texture)
		if key != "":
			picture.texture = icon(key)
			picture.modulate = Color(OLIVE, picture.modulate.a)
			picture.set_meta("city_icon", key)
	elif root is Button:
		var b := root as Button
		var key := _key(b.icon)
		if key != "":
			b.icon = icon(key)
		var hit_area: bool = b.text == "" and b.icon == null and not b.has_meta("icon") and b.get_theme_stylebox("normal") is StyleBoxEmpty
		if hit_area:
			pass   # прозрачная кнопка поверх строки не закрывает её рисунок
		elif not b.flat:
			button(b, b.has_meta("icon") or b.has_meta("bare") or b.text == "")
		else:
			for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
				b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
			for state: String in ["font_color", "font_hover_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
				b.add_theme_color_override(state, OLIVE)
	elif root is PanelContainer or root is Panel:
		var old: StyleBox = root.get_theme_stylebox("panel")
		if old is StyleBoxTexture:
			var style := panel()
			for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				style.set_content_margin(side, old.get_content_margin(side))
			root.add_theme_stylebox_override("panel", style)
	elif root is Label:
		var label := root as Label
		# Красное и зелёное число оставляем смысловыми состояниями.
		if label.get_theme_color("font_color") in [INK, Color("7a5a3c"), Color("7a2230"), Color("fff4dc")]:
			label.add_theme_color_override("font_color", INK)
	if root is Button:
		var b := root as Button
		var key := String(b.get_meta("icon", ""))
		if b.icon != null:
			var icon_key := texture_key(b.icon)
			if icon_key != "":
				b.icon = icon(icon_key)
			for state: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
				b.add_theme_color_override(state, OLIVE)
		var transparent_hit_area: bool = b.text == "" and b.icon == null and key == "" and b.get_theme_stylebox("normal") is StyleBoxEmpty
		if not transparent_hit_area and not b.has_meta("city_button") and (key != "" or not b.flat):
			button(b, key != "" or (b.text == "" and b.custom_minimum_size.x == b.custom_minimum_size.y))
		# Рамка уже рисуется кнопкой; значок внутри оставляет поля.
		var face := b.get_node_or_null("ic") as TextureRect
		if face != null and key != "":
			face.texture = icon(key)
			face.set_meta("city_icon", key)
			face.custom_minimum_size = Vector2.ZERO
			face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			face.offset_left = 5
			face.offset_top = 5
			face.offset_right = -5
			face.offset_bottom = -5
	if root is TextureRect:
		var picture := root as TextureRect
		var key := String(picture.get_meta("city_icon", ""))
		if key == "" and picture.texture != null:
			key = texture_key(picture.texture)
		if key != "":
			picture.texture = icon(key)
			picture.modulate = Color(Color.WHITE if key == "scales" else OLIVE, picture.modulate.a)
	for child: Node in root.get_children():
		if child is Control:
			apply(child as Control)


static func texture_key(texture: Texture2D) -> String:
	if texture.has_meta("city_icon"):
		return String(texture.get_meta("city_icon"))
	var path := texture.resource_path
	if path.contains("/icons/"):
		return path.get_file().get_basename()
	if path.get_file().begins_with("class_"):
		return String(CLASS_ICON.get(path.get_file().get_basename().trim_prefix("class_"), "person"))
	return ""
