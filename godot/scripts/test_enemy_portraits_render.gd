extends Node
## Офлайн-рендер портретов из тех же моделей, что в бою. Аргументы: out=, ids=.

const Enemy = preload("res://scripts/legion_enemy_actor.gd")
const PersonLayer = preload("res://scripts/fort_person_layer.gd")
const SIZE := 256
const RENDER := 480
const PAPER := """
shader_type canvas_item;

void fragment() {
	vec2 p = UV - vec2(0.40, 0.36);
	float glow = exp(-8.5 * dot(p, p));
	float wash = sin(UV.x * 17.0 + UV.y * 11.0 + sin(UV.y * 12.0)) * 0.014;
	wash += sin(UV.x * 39.0 - UV.y * 32.0) * 0.005;
	float grain = fract(sin(dot(floor(UV * 440.0), vec2(12.9898, 78.233))) * 43758.5453);
	vec3 paper = mix(vec3(0.58, 0.40, 0.27), vec3(0.95, 0.83, 0.64), glow);
	COLOR = vec4(paper + wash + (grain - 0.5) * 0.018, 1.0);
}
"""

const VARIANT_ONE := ["chief", "gaulArcher", "germArcher", "giant", "druidBoss", "nileArcher", "arminius",
	"decebalus", "vercingetorix", "surena", "viriathus", "salassi", "setPriest"]

var canvas: SubViewport
var layer: PersonLayer
var out := "res://assets/legion_enemies/portraits"


func _ready() -> void:
	call_deferred("_render_all")


func _render_all() -> void:
	var only := PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=")
		elif arg.begins_with("ids="):
			only = arg.trim_prefix("ids=").split(",", false)
	if DisplayServer.get_name() == "headless" or DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out)) != OK:
		print("PORTRAITS FAIL output " + out)
		get_tree().quit(1)
		return
	_setup()
	var rendered := 0
	var expected := Legion.ENEMIES.size() if only.is_empty() else only.size()
	for id: String in Legion.ENEMIES:
		if only.is_empty() or id in only:
			rendered += int(await _render(id))
	print("PORTRAITS DONE ", rendered, "/", expected)
	get_tree().quit(int(rendered != expected))


func _setup() -> void:
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(512, 512)
	canvas = SubViewport.new()
	canvas.size = Vector2i(RENDER, RENDER)
	canvas.disable_3d = true
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(canvas)
	var background := ColorRect.new()
	background.size = Vector2(RENDER, RENDER)
	var shader := Shader.new()
	shader.code = PAPER
	var material := ShaderMaterial.new()
	material.shader = shader
	background.material = material
	canvas.add_child(background)
	layer = PersonLayer.new()
	canvas.add_child(layer)
	layer.setup("PortraitPeople", 4.0)
	layer.fit(Vector2(RENDER, RENDER))
	layer.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _render(id: String) -> bool:
	var actor := Enemy.new()
	layer.viewport.add_child(actor)
	var variant := int(id in VARIANT_ONE)
	if not actor.build_enemy(id, 0, variant):
		print("PORTRAITS FAIL ", id, " ", actor.problem)
		actor.free()
		return false
	var pose := "Idle" if Enemy.HUMANS.has(id) else actor.idle
	actor.pose_at(pose, 0.08 + float(posmod(id.hash(), 5)) * 0.095)
	_frame(actor, id)
	for i in 3:
		await RenderingServer.frame_post_draw
	var picture := canvas.get_texture().get_image()
	actor.free()
	if picture == null or picture.is_empty():
		print("PORTRAITS FAIL read ", id)
		return false
	picture.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	picture.convert(Image.FORMAT_RGBA8)
	_medallion(picture)
	var path := out.path_join(id + ".png")
	if picture.save_png(path) != OK:
		print("PORTRAITS FAIL save ", path)
		return false
	print("PORTRAITS SHOT ", path)
	return true


func _frame(actor: Enemy, id: String) -> void:
	var point := Vector3.ZERO
	var span := 0.89 + (actor.stature - 1.79) * 0.84
	var yaw := 35.0
	match id:
		"minotaur":
			point = Vector3(0.02, 1.56, 0.11)
			span = 1.47
			yaw = 26.0
		"cyclops":
			point = Vector3(0.0, 1.56, 0.08)
			span = 1.23
			yaw = 21.0
		"elephant":
			point = Vector3(0.0, 1.41, 1.02)
			span = 2.58
			yaw = 21.0
		"chariot", "charioteer":
			point = Vector3(-0.04, 1.55, 1.15)
			span = 2.21
			yaw = 22.0
		"horseArcher", "cataphract":
			point = Vector3(-0.03, 1.88, 0.64)
			span = 1.85
			yaw = 44.0
		"bull", "bullLeader":
			point = Vector3(0.0, 1.10, 0.93)
			span = 1.50
			yaw = 19.0 if id == "bullLeader" else 29.0
		"boar":
			point = Vector3(0.0, 0.73, 0.75)
			span = 1.31
			yaw = 38.0
		_:
			if Enemy.BEASTS.has(id):
				point = Vector3(0.0, 0.91, 0.66)
				span = 1.43
				yaw = 24.0 if id == "hadesGuardian" else 37.0
			else:
				var head := actor._bone_frame(actor._rig, "Head", false)
				point = head.origin + Vector3(-0.015, 0.035 + (actor.stature - 1.79) * 0.36, 0.025)
	actor.rotation_degrees.y = yaw
	layer.camera.size = span
	layer.camera.position = actor.to_global(point) + layer.camera.basis.z * 10.0


func _medallion(picture: Image) -> void:
	var center := Vector2.ONE * (SIZE - 1) * 0.5
	for y in SIZE:
		for x in SIZE:
			var radius := Vector2(x, y).distance_to(center)
			var alpha := 1.0 - smoothstep(124.8, 126.0, radius)
			if alpha <= 0.0:
				picture.set_pixel(x, y, Color.TRANSPARENT)
				continue
			var color := picture.get_pixel(x, y)
			var metal := smoothstep(120.0, 121.2, radius)
			var brass := Color("98663b").lerp(Color("eac588"), (1.0 - float(y) / SIZE) * 0.83)
			brass = brass.lerp(Color("674126"), smoothstep(123.6, 125.5, radius) * 0.60)
			color = color.lerp(brass, metal)
			color.a = alpha
			picture.set_pixel(x, y, color)
