extends Node3D
## Проверка дома из деталей Synty: несколько домов в ряд, снимок

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
	pm.size = Vector2(60, 60)
	g.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("9bb36a")
	g.material_override = gm
	add_child(g)
	var specs := [{"w": 2, "floors": 2, "shop": true, "beams": true}] if OS.get_cmdline_user_args().has("one") else [
		{"w": 2, "floors": 3, "shop": true}, {"w": 1, "floors": 2, "roof": "flat"}, {"w": 2, "floors": 2, "shop": true, "beams": true}, {"w": 3, "floors": 1, "shop": true}, {"w": 2, "floors": 4, "roof": "flat", "shop": true}]
	var x := -14.0
	for i in specs.size():
		var s: Dictionary = specs[i]
		s["seed"] = i + 11
		var h := SyntyHouse.new().build(s)
		var w: int = s.get("w", 2)
		h.position = Vector3(x + w * 1.25, 0, 0)
		add_child(h)
		x += w * 2.5 + 0.05
	var cam := Camera3D.new()
	cam.fov = 40
	add_child(cam)
	var args := OS.get_cmdline_user_args()
	var yaw := float(args[0]) if args.size() > 0 else 25.0
	var one := OS.get_cmdline_user_args().has("one")
	var c := Vector3(-11.5 if one else -1.0, 3.5, 0)
	cam.look_at_from_position(c + Vector3(sin(deg_to_rad(yaw)), 0.42, cos(deg_to_rad(yaw))) * (12.0 if one else 27.0), c, Vector3.UP)


var frame := 0
func _process(_dt: float) -> void:
	frame += 1
	if frame == 30:
		var a := OS.get_cmdline_user_args()
		get_viewport().get_texture().get_image().save_png(a[1] if a.size() > 1 else "D:/CivCity/.work/gd/shouse.png")
		get_tree().quit()
