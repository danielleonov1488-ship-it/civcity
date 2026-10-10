extends Node3D
## Проверка жителей: четыре фигуры с разными движениями, снимок и выход

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("cfe0ea")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d8d0c0")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.light_energy = 2.2
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("ddd1bc")
	ground.material_override = gm
	add_child(ground)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var anims := ["Walk_Loop", "Idle_Talking_Loop", "Idle_Loop", "Walk_Formal_Loop", "Sitting_Talking_Loop", "Push_Loop"]
	for i in 6:
		var c := Citizen.create(rng, i % 2 == 1, i == 5)
		add_child(c)
		c.position = Vector3(-3.75 + i * 1.5, 0, 0)
		c.rotation.y = 0.35
		c.play(anims[i], 0.0)
		if i == 0:
			print("ANIMS ", c.anim.get_animation_list().slice(0, 6))
	var cam := Camera3D.new()
	cam.fov = 35
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.8, 7.5), Vector3(0, 0.95, 0), Vector3.UP)


var frame := 0
func _process(_dt: float) -> void:
	frame += 1
	if frame == 40:
		get_viewport().get_texture().get_image().save_png("D:/CivCity/.work/gd/people.png")
		get_tree().quit()
