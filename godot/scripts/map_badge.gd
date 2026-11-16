extends Control
## Крупные значки: один Control, без раскладки в неподвижном кадре.

const INK := Color("4a2c17")
const CREAM := Color("fff4dc")
const RIM := Color("967557")
const BAD := Color("b0402a")
const GOOD := Color("4f7a2a")
const CLASS_RING := {"plebs": Color("71855b"), "artisans": Color("648494"), "patricians": Color("94708d")}
static var textures: Dictionary = {}
var icon := ""
var kind := ""
var texture: Texture2D
var preference_texture: Texture2D
var ring := RIM
var warn := false
var matches := false
var label: Label
var pill: StyleBoxFlat
var arrow := false


static func ink_texture(key: String) -> Texture2D:
	var alias: String = {"up": "arrow", "floor": "arrow", "face_good": "happy", "face_mid": "happy", "face_bad": "happy", "family": "badge_family", "road": "badge_road", "no_workers": "badge_no_workers"}.get(key, key)
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
	kind = {"family": "family_waiting", "house_problem": "house_problem", "up": "floor_ready", "road": "no_road", "no_workers": "no_workers"}.get(key, "tool")
	texture = ink_texture(key)
	warn = warning
	arrow = key == "up" or key.begins_with("upc")
	size = Vector2(30, 30) if arrow else Vector2(44, 50 if key == "house_problem" else 44)
	# Стрелка с ценой сохраняет прежний рисунок.
	if text != "":
		label = Label.new()
		label.text = text.left(64)
		label.add_theme_font_override("font", face_font)
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", BAD if warning else INK)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		var side := 30.0 if arrow else 44.0
		label.position = Vector2(side, 0)
		var label_width := label.get_minimum_size().x
		label.size = Vector2(clampf(label_width, 1.0, 400.0) if is_finite(label_width) else 1.0, side)
		label.clip_text = true
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		size.x = side + 9 + label.size.x
		pill = StyleBoxFlat.new()
		pill.bg_color = CREAM
		pill.border_color = BAD if warning else (RIM if arrow else INK)
		pill.set_border_width_all(1 if arrow else 3)
		pill.set_corner_radius_all(15 if arrow else 22)
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
	# Предпочтение — в подсказке, без мелкого пузыря.
	preference_texture = next_texture
	queue_redraw()


func set_match(value: bool) -> void:
	if matches != value:
		matches = value
		queue_redraw()


func _disc(at: Vector2, radius: float, fill: Color) -> void:
	if not at.is_finite() or not is_finite(radius) or absf(at.x) > 512.0 or absf(at.y) > 512.0:
		return
	radius = clampf(radius, 3.0, 32.0)
	for i in range(4, 0, -1):
		draw_circle(at + Vector2(0, 3), radius + i, Color(0.19, 0.12, 0.07, 0.035), true, -1, true)
	draw_circle(at, radius, fill, true, -1, true)
	draw_arc(at, radius - 1.5, 0, TAU, 64, INK, 3, true)


func _face(at: Vector2, sad: bool, col: Color, r := 1.0) -> void:
	if not at.is_finite() or not is_finite(r) or absf(at.x) > 512.0 or absf(at.y) > 512.0:
		return
	r = clampf(r, 0.5, 1.5)
	draw_circle(at + Vector2(-7, -5) * r, 2 * r, col, true, -1, true)
	draw_circle(at + Vector2(7, -5) * r, 2 * r, col, true, -1, true)
	if icon == "face_mid":
		draw_line(at + Vector2(-7, 6) * r, at + Vector2(7, 6) * r, col, 2.5 * r, true)
	elif sad:
		draw_arc(at + Vector2(0, 13) * r, 9 * r, PI * 1.17, PI * 1.83, 24, col, 2.5 * r, true)
	else:
		draw_arc(at + Vector2(0, 0) * r, 9 * r, PI * 0.17, PI * 0.83, 24, col, 2.5 * r, true)


func _draw() -> void:
	if not size.is_finite() or not scale.is_finite() or not position.is_finite() or not get_global_transform().is_finite():
		return
	if size.x <= 0.0 or size.y <= 0.0 or size.x > 512.0 or size.y > 512.0 or scale.x < 0.5 or scale.y < 0.5 or scale.x > 1.5 or scale.y > 1.5:
		return
	if pill != null:
		# Тень всегда в пикселях значка, не в расстоянии до камеры.
		if pill.shadow_size < 0 or pill.shadow_size > 4 or not pill.shadow_offset.is_finite() or pill.shadow_offset.length_squared() > 16.0:
			return
		draw_style_box(pill, Rect2(Vector2.ZERO, size))
	elif icon == "house_problem":
		var pin := PackedVector2Array([Vector2(13, 35), Vector2(22, 50), Vector2(31, 35)])
		draw_colored_polygon(pin, BAD)
		draw_polyline(PackedVector2Array([pin[0], pin[1], pin[2]]), INK, 3, true)
		_disc(Vector2(22, 22), 22, BAD)
	elif arrow:
		# Прежний маленький круг стрелки без цены.
		for i in range(3, 0, -1):
			draw_circle(Vector2(15, 17), 15 + i, Color(0.19, 0.12, 0.07, 0.025), true, -1, true)
		draw_circle(Vector2(15, 15), 15, CREAM, true, -1, true)
		draw_arc(Vector2(15, 15), 14.4, 0, TAU, 48, RIM, 1.2, true)
	else:
		_disc(Vector2(22, 22), 22, CREAM)
	if arrow:
		draw_line(Vector2(15, 23), Vector2(15, 8), INK, 2, true)
		draw_polyline(PackedVector2Array([Vector2(9, 14), Vector2(15, 8), Vector2(21, 14)]), INK, 2, true)
		if icon.begins_with("upc"):
			draw_polyline(PackedVector2Array([Vector2(9, 19), Vector2(15, 13), Vector2(21, 19)]), INK, 2, true)
	elif icon == "house_problem" or icon.begins_with("face_"):
		_face(Vector2(22, 22), icon in ["house_problem", "face_bad"], CREAM if icon == "house_problem" else INK)
	elif texture != null:
		var colored := icon in ["family", "road", "no_workers"]
		draw_texture_rect(texture, Rect2(6, 6, 32, 32), false, Color.WHITE if colored else (BAD if warn else INK))
	if icon == "family":
		draw_arc(Vector2(22, 22), 17.8, 0, TAU, 64, ring, 2, true)
	if arrow and warn:
		var at := Vector2(size.x - 3, 4)
		draw_circle(at, 4.5, CREAM, true, -1, true)
		draw_circle(at, 3.5, BAD, true, -1, true)
	if matches:
		var at := Vector2(39, 5)
		draw_circle(at, 7, GOOD, true, -1, true)
		draw_polyline(PackedVector2Array([at + Vector2(-4, 0), at + Vector2(-1, 3), at + Vector2(4, -3)]), CREAM, 2, true)
