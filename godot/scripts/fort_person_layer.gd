extends Node2D
## Один прозрачный 3D-слой для персонажей на рисованном фоне.

const EDGE := """
shader_type canvas_item;
render_mode blend_premul_alpha;

void fragment() {
	vec4 picture = texture(TEXTURE, UV);
	float mask = picture.a;
	vec2 step_px = TEXTURE_PIXEL_SIZE * 1.25;
	mask = max(mask, texture(TEXTURE, UV + vec2(step_px.x, 0.0)).a);
	mask = max(mask, texture(TEXTURE, UV - vec2(step_px.x, 0.0)).a);
	mask = max(mask, texture(TEXTURE, UV + vec2(0.0, step_px.y)).a);
	mask = max(mask, texture(TEXTURE, UV - vec2(0.0, step_px.y)).a);
	float edge = (mask - picture.a) * 0.82;
	COLOR = vec4(picture.rgb + vec3(0.086, 0.056, 0.047) * edge, picture.a + edge);
}
"""

var viewport: SubViewport
var camera: Camera3D
var overlay: TextureRect
var extent := Vector2.ONE
var shadows := PackedVector3Array()
var _frame := Transform3D.IDENTITY
var _render_rect := Rect2()
var _tilt := 0.0
static var _outline: ShaderMaterial
static var _shadow: GradientTexture2D


func setup(view_name: String, tilt: float, antialias := true) -> void:
	_tilt = tilt
	viewport = SubViewport.new()
	viewport.name = view_name
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.gui_disable_input = true
	viewport.msaa_3d = Viewport.MSAA_2X if antialias else Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.0
	camera.position = Vector3(0.0, 0.0, 18.0)
	camera.rotation_degrees.x = -tilt
	viewport.add_child(camera)
	camera.make_current()
	_frame = camera.transform
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("eadfcd")
	world.environment.ambient_light_energy = 0.55
	viewport.add_child(world)
	_light(Color("ffe0ad"), 1.35, Vector3(-36, -27, 0))
	_light(Color("fff1cf"), 0.75, Vector3(-34, 151, 0))
	if _outline == null:
		var shader := Shader.new()
		shader.code = EDGE
		_outline = ShaderMaterial.new()
		_outline.shader = shader
	overlay = TextureRect.new()
	overlay.texture = viewport.get_texture()
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.material = _outline
	add_child(overlay)


func _light(color: Color, energy: float, angles: Vector3) -> void:
	var light := DirectionalLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.shadow_enabled = false
	light.rotation_degrees = angles
	viewport.add_child(light)


func fit(area: Vector2) -> void:
	extent = area.max(Vector2.ONE)
	_render_rect = Rect2()
	_view_rect(Rect2(Vector2.ZERO, extent))


func crop_to(bounds: Rect2) -> void:
	# Округляем границы, чтобы при анимации не пересоздавать буфер каждый кадр.
	var tile := Vector2(96, 96)
	var start := (bounds.position / tile).floor() * tile
	var end := (bounds.end / tile).ceil() * tile
	var area := Rect2(start, end - start).intersection(Rect2(Vector2.ZERO, extent))
	overlay.visible = area.has_area()
	if overlay.visible:
		_view_rect(area)


func _view_rect(area: Rect2) -> void:
	if _render_rect == area:
		return
	_render_rect = area
	var factor := minf(1.0, minf(1920.0 / area.size.x, 1080.0 / area.size.y))
	viewport.size = Vector2i((area.size * factor).round()).max(Vector2i(2, 2))
	var at := (area.get_center() - extent * 0.5) * (10.0 / extent.y)
	camera.position = _frame * Vector3(at.x, -at.y, 0.0)
	camera.size = 10.0 * area.size.y / extent.y
	overlay.position = area.position
	overlay.size = area.size


func place(actor: Node3D, feet: Vector2, height: float, yaw: float, foreground := false, depth_offset := 0.0) -> void:
	var units_per_pixel := 10.0 / extent.y
	var at := (feet - extent * 0.5) * units_per_pixel
	var depth := 9.0 if foreground else clampf(feet.y / extent.y, 0.0, 1.0) * 4.0
	var origin := _frame * Vector3(at.x, -at.y, depth + depth_offset - 18.0)
	var body_scale := Vector3.ONE * (height * units_per_pixel / (1.79 * cos(deg_to_rad(_tilt))))
	if actor.position != origin:
		actor.position = origin
	if actor.rotation.y != deg_to_rad(yaw):
		actor.rotation.y = deg_to_rad(yaw)
	if actor.scale != body_scale:
		actor.scale = body_scale


func _draw() -> void:
	if shadows.is_empty():
		return
	if _shadow == null:
		_shadow = GradientTexture2D.new()
		_shadow.width = 32
		_shadow.height = 32
		_shadow.gradient = Gradient.new()
		_shadow.gradient.colors = PackedColorArray([Color(0.16, 0.08, 0.04, 0.53), Color(0.16, 0.08, 0.04, 0.0)])
		_shadow.fill = GradientTexture2D.FILL_RADIAL
		_shadow.fill_from = Vector2(0.5, 0.5)
		_shadow.fill_to = Vector2(1.0, 0.5)
	for mark in shadows:
		var dims := Vector2(mark.z * 0.55, mark.z * 0.15)
		draw_texture_rect(_shadow, Rect2(Vector2(mark.x, mark.y) - dims * 0.5, dims), false)
