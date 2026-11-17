extends Control
## Один значок, один рисунок: без раскладки в неподвижном кадре.

const INK := Color("4a2c17")
const CREAM := Color("fff4dc")
const RIM := Color("967557")
const BAD := Color("b0402a")
const GOOD := Color("4f7a2a")
const CLASS_RING := {"plebs": Color("71855b"), "artisans": Color("648494"), "patricians": Color("94708d")}
const BADGES := "res://assets/ui/badges3/"
const ALIASES := {"keys": "home_room", "house_problem": "sad", "road": "no_road", "up": "floor_up", "floor": "floor_up",
	"face_good": "family", "face_mid": "family", "face_bad": "sad", "happy": "sad", "scroll": "request",
	"check": "collect", "hammer": "building", "coins": "collect", "arrow_down": "request"}
const WANTS := {"trees": "trees", "tree": "trees", "green": "trees", "water": "water", "flowers": "flowers", "flower": "flowers",
	"quiet": "quiet", "sleep": "quiet", "market": "market", "commerce": "market", "temple": "temple", "faith": "temple",
	"laurels": "temple", "pious": "temple", "plaza": "square", "road": "square", "square": "square"}
static var textures: Dictionary = {}
var icon := ""
var kind := ""
var texture: Texture2D
var preference_texture: Texture2D
var match_texture: Texture2D
var ring := RIM
var warn := false
var matches := false
var label: Label
var pill: StyleBoxFlat
var arrow := false


## Чернильные иконки остаются в обычных строках интерфейса, не на карте.
static func ink_texture(key: String) -> Texture2D:
	var alias: String = {"family": "badge_family", "road": "badge_road", "no_workers": "badge_no_workers"}.get(key, key)
	var cache_key := "ink/" + alias
	if not textures.has(cache_key):
		var path := "res://assets/ui/icons/%s.svg" % alias
		textures[cache_key] = load(path if ResourceLoader.exists(path) else "res://assets/ui/icons/info.svg")
	return textures[cache_key]


static func badge_texture(key: String) -> Texture2D:
	var alias: String = ALIASES.get(key, key)
	if key.begins_with("upc"):
		alias = "floor_up"
	var cache_key := "badge/" + alias
	if not textures.has(cache_key):
		var path := BADGES + alias + ".png"
		textures[cache_key] = load(path if ResourceLoader.exists(path) else BADGES + "building.png")
	return textures[cache_key]


static func want_texture(key: String) -> Texture2D:
	return badge_texture("want_" + String(WANTS[key])) if WANTS.has(key) else badge_texture("request")


func setup(key: String, warning: bool, text: String, face_font: Font) -> void:
	icon = key
	kind = {"family": "family_waiting", "house_problem": "house_problem", "sad": "house_problem", "up": "floor_ready", "road": "no_road", "no_workers": "no_workers"}.get(key, "tool")
	texture = badge_texture(key)
	match_texture = badge_texture("match")
	warn = warning
	arrow = key in ["up", "floor_up"] or key.begins_with("upc")
	size = Vector2(44, 44)
	# Цену передаёт только «Этаж», под кружком отдельная плашка.
	if arrow and text != "":
		label = Label.new()
		label.name = "FloorPrice"
		label.text = text.left(12)
		label.add_theme_font_override("font", face_font)
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", BAD if warning else INK)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(label)
		# Плашка не меняет область нажатия 44×44 и центр рисунка.
		var label_width := face_font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var pill_width := clampf(label_width + 12.0, 44.0, 96.0) if is_finite(label_width) else 44.0
		label.clip_text = true
		label.position = Vector2((44.0 - pill_width) * 0.5, 46)
		label.size = Vector2(pill_width, 20)
		pill = StyleBoxFlat.new()
		pill.bg_color = CREAM
		pill.border_color = RIM
		pill.set_border_width_all(1)
		pill.set_corner_radius_all(10)
		pill.shadow_color = Color(0.19, 0.12, 0.07, 0.16)
		pill.shadow_size = 2
		pill.shadow_offset = Vector2(0, 2)
	queue_redraw()


## Нехватка денег меняет только чернила, не узел и не его раскладку.
func set_warning(value: bool) -> void:
	warn = value
	if label != null:
		label.add_theme_color_override("font_color", BAD if warn else INK)
	queue_redraw()


func family(cls: String, preference: String) -> void:
	var next_texture: Texture2D = want_texture(preference) if preference != "" else null
	if preference_texture == next_texture:
		return
	ring = CLASS_RING.get(cls, RIM) # Поле оставлено для старых вызывающих.
	preference_texture = next_texture
	queue_redraw()


func set_match(value: bool) -> void:
	if matches != value:
		matches = value
		queue_redraw()


func _draw() -> void:
	if not size.is_finite() or not scale.is_finite() or not position.is_finite() or not get_global_transform().is_finite():
		return
	if size.x <= 0.0 or size.y <= 0.0 or size.x > 512.0 or size.y > 512.0 or scale.x < 0.5 or scale.y < 0.5 or scale.x > 1.5 or scale.y > 1.5:
		return
	if texture != null:
		draw_texture_rect(texture, Rect2((size.x - 40.0) * 0.5, 2, 40, 40), false)
	if icon == "family" and preference_texture != null:
		draw_texture_rect(preference_texture, Rect2(22, 22, 22, 22), false)
	if matches and match_texture != null:
		draw_texture_rect(match_texture, Rect2(26, 26, 18, 18), false)
	if pill != null:
		if pill.shadow_size < 0 or pill.shadow_size > 4 or not pill.shadow_offset.is_finite() or pill.shadow_offset.length_squared() > 16.0:
			return
		draw_style_box(pill, label.get_rect())
