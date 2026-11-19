extends Node2D
## Один прозрачный 3D-слой для персонажей на рисованном фоне.

const Actor = preload("res://scripts/charpilot_actor.gd")
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
var shadows: Array[Vector3] = []
var _tilt := 0.0
static var _outline: ShaderMaterial
static var _shadow: GradientTexture2D


func setup(view_name: String, tilt: float) -> void:
	_tilt = tilt
	viewport = SubViewport.new()
	viewport.name = view_name
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.gui_disable_input = true
	viewport.msaa_3d = Viewport.MSAA_2X
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
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("eadfcd")
	world.environment.ambient_light_energy = 0.65
	viewport.add_child(world)
	_light(Color("ffe0ad"), 1.35, Vector3(-36, -27, 0))
	_light(Color("fff1cf"), 0.85, Vector3(-34, 151, 0))
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
	light.rotation_degrees = angles
	viewport.add_child(light)


func fit(area: Vector2) -> void:
	extent = area.max(Vector2.ONE)
	var factor := minf(1.0, minf(1920.0 / extent.x, 1080.0 / extent.y))
	viewport.size = Vector2i((extent * factor).round()).max(Vector2i.ONE)
	overlay.size = extent


func place(actor: Actor, feet: Vector2, height: float, yaw: float, foreground := false) -> void:
	var units_per_pixel := camera.size / extent.y
	var at := (feet - extent * 0.5) * units_per_pixel
	var depth := 9.0 if foreground else clampf(feet.y / extent.y, 0.0, 1.0) * 4.0
	actor.position = camera.transform * Vector3(at.x, -at.y, depth - 18.0)
	actor.rotation_degrees.y = yaw
	actor.scale = Vector3.ONE * (height * units_per_pixel / (1.79 * cos(deg_to_rad(_tilt))))


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
