extends Node3D
func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("cfe0ea")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e0d8c8")
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	add_child(sun)
	var pp := People.new()
	add_child(pp)
	pp._make_cart()
	var root: Node3D = pp.cart["n"]
	root.visible = true
	pp._horse_anim(pp.cart["horse"], "Walk")
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(5.5, 3.2, 3.5)
	cam.look_at(Vector3(0, 0.8, 1.2))
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png("D:/CivCity/.work/gd/horse.png")
	get_tree().quit()
