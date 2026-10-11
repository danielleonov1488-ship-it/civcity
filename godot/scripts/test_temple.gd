extends Node3D

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("cfe0ea")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e0d8c8")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 2.2
	add_child(sun)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	g.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("9bb36a")
	g.material_override = gm
	add_child(g)
	add_child(SyntyTemple.new().build())
	var cam := Camera3D.new()
	cam.fov = 40
	add_child(cam)
	var args := OS.get_cmdline_user_args()
	var yaw := float(args[0]) if args.size() > 0 else 25.0
	var c := Vector3(0, 4, -8)
	cam.look_at_from_position(c + Vector3(sin(deg_to_rad(yaw)), 0.45, cos(deg_to_rad(yaw))) * 34.0, c, Vector3.UP)

var frame := 0
func _process(_dt: float) -> void:
	frame += 1
	if frame == 30:
		var a := OS.get_cmdline_user_args()
		get_viewport().get_texture().get_image().save_png(a[1] if a.size() > 1 else "D:/CivCity/.work/gd/temple.png")
		get_tree().quit()
