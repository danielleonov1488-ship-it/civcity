extends Control
## Один узел на значок; подпись — единственный необязательный ребёнок.

const INK := Color("4a2c17")
const CREAM := Color("fff4dc")
const RIM := Color("967557")
const BAD := Color("b0402a")
const GOOD := Color("4f7a2a")
const CLASS_RING := {"plebs": Color("71855b"), "artisans": Color("648494"), "patricians": Color("94708d")}
static var textures: Dictionary = {}
var icon := ""
var texture: Texture2D
var preference_texture: Texture2D
var ring := RIM
var warn := false
var matches := false
var label: Label
var pill: StyleBoxFlat


static func ink_texture(key: String) -> Texture2D:
	var alias: String = {"up": "arrow", "floor": "arrow", "face_good": "happy", "face_mid": "happy", "face_bad": "happy"}.get(key, key)
	if key.begins_with("upc"):
		alias = "arrow"
	if textures.has(alias):
		return textures[alias]
	var path := "res://assets/ui/icons/%s.svg" % alias
	if not ResourceLoader.exists(path):
		path = "res://assets/ui/icons/info.svg"
	var tex: Texture2D = load(path)
	textures[alias] = tex
	return tex


func setup(key: String, warning: bool, text: String, face_font: Font) -> void:
	icon = key
	texture = ink_texture(key)
	warn = warning
	size = Vector2(30, 30)
	if text != "":
		label = Label.new()
		label.text = text
		label.add_theme_font_override("font", face_font)
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", BAD if warning else INK)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		label.position = Vector2(30, 0)
		label.size = Vector2(label.get_minimum_size().x, 30)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		size.x = 39 + label.size.x
		pill = StyleBoxFlat.new()
		pill.bg_color = CREAM
		pill.border_color = BAD if warning else RIM
		pill.set_border_width_all(1)
		pill.set_corner_radius_all(15)
		pill.shadow_color = Color(0.19, 0.12, 0.07, 0.16)
		pill.shadow_size = 3
		pill.shadow_offset = Vector2(0, 2)
	queue_redraw()


func family(cls: String, preference: String) -> void:
	var next_ring: Color = CLASS_RING.get(cls, RIM)
	var next_texture: Texture2D = ink_texture(preference) if preference != "" else null
	if ring == next_ring and preference_texture == next_texture:
		return
	ring = next_ring
	preference_texture = next_texture
	size.x = 55 if preference_texture != null else 30
	queue_redraw()


func set_match(value: bool) -> void:
	if matches != value:
		matches = value
		queue_redraw()


func _disc(at: Vector2, radius: float, edge: Color) -> void:
	for i in range(3, 0, -1):
		draw_circle(at + Vector2(0, 2), radius + i, Color(0.19, 0.12, 0.07, 0.025), true, -1, true)
	draw_circle(at, radius, CREAM, true, -1, true)
	draw_arc(at, radius - 0.6, 0, TAU, 48, edge, 1.2, true)


func _draw() -> void:
	if pill != null:
		draw_style_box(pill, Rect2(Vector2.ZERO, size))
	else:
		_disc(Vector2(15, 15), 15, ring)
	# Рожицы и стрелка сохраняют смысл «Обзора» и «Этажа», но рисуются теми же чернилами.
	if icon.begins_with("face_"):
		draw_circle(Vector2(11, 12), 1.2, INK, true, -1, true)
		draw_circle(Vector2(19, 12), 1.2, INK, true, -1, true)
		if icon == "face_mid":
			draw_line(Vector2(10, 19), Vector2(20, 19), INK, 1.5, true)
		elif icon == "face_bad":
			draw_arc(Vector2(15, 23), 6, PI * 1.15, PI * 1.85, 16, INK, 1.5, true)
		else:
			draw_arc(Vector2(15, 15), 6, PI * 0.15, PI * 0.85, 16, INK, 1.5, true)
	elif icon == "up" or icon.begins_with("upc"):
		draw_line(Vector2(15, 23), Vector2(15, 8), INK, 2, true)
		draw_polyline(PackedVector2Array([Vector2(9, 14), Vector2(15, 8), Vector2(21, 14)]), INK, 2, true)
		if icon.begins_with("upc"):
			draw_polyline(PackedVector2Array([Vector2(9, 19), Vector2(15, 13), Vector2(21, 19)]), INK, 2, true)
	elif icon == "work_half":
		draw_arc(Vector2(15, 15), 7, -PI * 0.5, PI * 1.5, 32, RIM, 2, true)
		draw_arc(Vector2(15, 15), 7, -PI * 0.5, PI * 0.5, 16, GOOD, 5, true)
	elif texture != null:
		draw_texture_rect(texture, Rect2(6, 6, 18, 18), false, INK)
	if preference_texture != null:
		_disc(Vector2(44, 17), 11, RIM)
		draw_texture_rect(preference_texture, Rect2(37, 10, 14, 14), false, INK)
	if warn or matches:
		var at := Vector2(size.x - 3, 4)
		draw_circle(at, 4.5, CREAM, true, -1, true)
		draw_circle(at, 3.5, BAD if warn else GOOD, true, -1, true)
		if matches and not warn:
			draw_polyline(PackedVector2Array([at + Vector2(-2, 0), at + Vector2(-0.5, 1.5), at + Vector2(2, -1.5)]), CREAM, 1.1, true)
