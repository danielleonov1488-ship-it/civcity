extends RefCounted
## Общие цвета и расписные значки Легиона.

const Kit = preload("res://scripts/ui_kit_a.gd")
const BOLD = preload("res://assets/fonts/AlegreyaSans-Bold.ttf")
const WINE := Color("783d34")
const BRONZE := Color("ba8f54")
const OLIVE := Color("4d6044")
const SLATE := Color("485f66")
const INK := Color("292621")
const SOFT := Color("5c5248")
const DARK := Color("302a24")
const PAPER := Color("f3ebdd")
const INSET := Color("e6dbca")
const EDGE := Color("a49785")
const DIM := Color(0.09, 0.065, 0.045, 0.53)
const ICONS := {"money": "denarii", "rations": "rations", "glory": "glory", "ingots": "gold",
	"quests": "quests", "chest": "chest", "trophy": "trophy", "squad": "squad", "map": "map",
	"build": "build", "market": "market"}
const ALIASES := {"coins": "money", "bread": "rations", "laurels": "glory", "hammer": "build",
	"arena": "trophy", "tasks": "quests", "commerce": "market", "scroll": "map", "swords": "squad"}
static var textures: Dictionary = {}
static var frame_material: ShaderMaterial


static func icon(id: String) -> Texture2D:
	var key := String(ALIASES.get(id, id))
	if not ICONS.has(key):
		return Kit.texture(key)
	if not textures.has(key):
		var path := "res://assets/legion_ui/icons/%s.png" % ICONS[key]
		textures[key] = load(path) if ResourceLoader.exists(path) else Kit.texture(id)
	return textures[key] as Texture2D


static func resource(id: String) -> Texture2D:
	return icon(id) if ICONS.has(id) else Kit.resource(id)


static func box(fill: Color, edge: Color, radius: int, pad: float, depth := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.anti_aliasing_size = 1.0
	style.shadow_color = Color(0.13, 0.08, 0.05, 0.75)
	style.shadow_size = depth
	style.shadow_offset = Vector2(0, depth)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, pad)
	return style


static func panel(fill := PAPER, pad := 16.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(fill, BRONZE, 12, pad))
	return p


static func bronze_frame(panel: UiKitA.CardPanel) -> void:
	# На мраморной рамке меняем винный кант на бронзу.
	panel.plate_scale = 0.47
	if frame_material == null:
		var shader := Shader.new()
		shader.code = """
shader_type canvas_item;
void fragment() {
	vec4 stone = COLOR;
	float rim = smoothstep(0.15, 0.42, stone.r - stone.g)
		* (1.0 - smoothstep(0.12, 0.32, stone.g - stone.b));
	vec3 bronze = vec3(0.14, 0.085, 0.04) + stone.r * vec3(0.93, 0.69, 0.47);
	float gold = smoothstep(0.40, 0.72, stone.r - stone.b) * smoothstep(0.12, 0.31, stone.g - stone.b);
	vec3 brass = stone.rgb * vec3(0.83, 0.75, 0.78) + vec3(0.09, 0.13, 0.18);
	COLOR = vec4(mix(mix(stone.rgb, brass, gold), bronze, rim), stone.a);
}
"""
		frame_material = ShaderMaterial.new()
		frame_material.shader = shader
	panel.plate.material = frame_material


static func close_button(action: Callable, pixels := 54.0) -> Button:
	var close := Kit.close_button()
	close.custom_minimum_size = Vector2.ONE * pixels
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(action)
	return close


static func sprig(pixels: float, flipped: bool) -> TextureRect:
	var leaf := AtlasTexture.new()
	leaf.atlas = icon("glory")
	leaf.region = Rect2(7, 2, 55, 99)
	var art := Kit.image(leaf, Vector2(pixels, pixels))
	art.flip_h = flipped
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return art


static func heading(value: String, pixels: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 13)
	row.add_child(sprig(float(pixels), false))
	var title := label(value, pixels, INK, true)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	row.add_child(sprig(float(pixels), true))
	return row


static func divider() -> TextureRect:
	var line := Kit.image("res://assets/ui/marble/divider.png", Vector2(0, 11))
	line.stretch_mode = TextureRect.STRETCH_SCALE
	return line


static func label(value: String, pixels := 22, color := INK, title := false) -> Label:
	var l := Kit.label(value, pixels)
	l.add_theme_font_override("font", BOLD)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 0)
	if title:
		l.add_theme_font_override("font", Kit.TITLE)
	return l


static func button(value: String, tex: Texture2D = null, fill := PAPER, dims := Vector2(132, 54), round_shape := false) -> Button:
	var b := Button.new()
	var bright := fill in [DARK, WINE, SLATE, OLIVE]
	var ink := PAPER if bright else INK
	var radius := 40 if round_shape else 10
	var pad := 6.0 if round_shape else 10.0
	b.text = value
	b.icon = tex
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if value == "" else HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", BOLD)
	b.add_theme_font_size_override("font_size", 23)
	b.add_theme_constant_override("icon_max_width", 42)
	b.add_theme_constant_override("h_separation", 7)
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		var tone := fill.lightened(0.10) if state == "hover" else fill.darkened(0.08) if state.contains("pressed") else fill
		b.add_theme_stylebox_override(state, box(tone, BRONZE, radius, pad, 2 if state in ["normal", "hover"] else 0))
		b.add_theme_color_override("font_color" if state == "normal" else "font_" + state + "_color", ink)
	b.add_theme_stylebox_override("disabled", box(Color("d9cfc1"), EDGE, radius, pad))
	b.add_theme_color_override("font_disabled_color", SOFT)
	var focus := box(Color.TRANSPARENT, PAPER if bright else WINE, radius, 0)
	focus.set_border_width_all(2)
	b.add_theme_stylebox_override("focus", focus)
	b.custom_minimum_size = dims
	return b


static func meter(current: float, maximum: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = maxf(1.0, maximum)
	bar.value = current
	bar.custom_minimum_size.y = 22
	bar.add_theme_stylebox_override("background", box(INSET, INSET, 6, 0))
	bar.add_theme_stylebox_override("fill", box(OLIVE, OLIVE, 6, 0))
	return bar


const CHIP_NUMBER_SIZE := 30


static func set_chip_value(number: Label, value: String) -> void:
	if number.text == value:
		return
	number.text = value
	_fit_chip_number(number)


static func _fit_chip_number(number: Label) -> void:
	if number.size.x <= 0.0:
		return
	var font := number.get_theme_font("font")
	var pixels := CHIP_NUMBER_SIZE
	while pixels > 1 and font.get_string_size(number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x > number.size.x:
		pixels -= 1
	if number.get_theme_font_size("font_size") != pixels:
		number.add_theme_font_size_override("font_size", pixels)


static func chip(resource_id: String, value: String, action := Callable(), compact := false) -> PanelContainer:
	var p := panel(DARK, 5)
	p.custom_minimum_size = Vector2(138, 52) if compact else Vector2(150, 62)
	if compact:
		p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	var image := Kit.image(resource(resource_id), Vector2.ONE * (42 if compact else 50))
	image.name = "ResourceIcon"
	image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(image)
	var number := label(value, CHIP_NUMBER_SIZE, PAPER)
	number.clip_text = true
	number.name = "ResourceNumber"
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(number)
	number.resized.connect(func(): _fit_chip_number(number))
	p.set_meta("number", number)
	if action.is_valid():
		var hit := Button.new()
		hit.flat = true
		hit.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, PAPER, 7, 0))
		hit.pressed.connect(action)
		p.add_child(hit)
		p.set_meta("hit", hit)
	return p
