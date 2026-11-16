class_name FortPersonPreview
extends SubViewportContainer
## Один и тот же облик в разрезе и в карточке.


static func civilian(person: Dictionary) -> Citizen:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(person.get("look_seed", person.get("res", {}).get("m", {}).get("sd", int(person.get("id", 1)) * 409)))
	var female := bool(person.get("female", int(person.get("res", {}).get("m", {}).get("sx", 0)) == 1))
	var look: Dictionary = person.get("look", {})
	if look.is_empty():
		look = Citizen.roll_look(rng, female, false, false, "", "plebs")
	var node := Citizen.build(look)
	node.play("Idle", 0.0, 0.0)
	return node


func setup(person: Dictionary) -> void:
	custom_minimum_size = Vector2(210, 240)
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.size = Vector2i(210, 240)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var root := Node3D.new()
	viewport.add_child(root)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.5
	camera.position = Vector3(0, 0.60, 4)
	camera.current = true
	root.add_child(camera)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff1db")
	env.ambient_light_energy = 0.8
	environment.environment = env
	root.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -30, 0)
	light.light_energy = 1.5
	root.add_child(light)
	if ResourceLoader.exists(Citizen.DIR + Citizen.PLEBS[0] + ".fbx") and ResourceLoader.exists("res://assets/people/UAL1_Standard.glb"):
		var citizen := civilian(person)
		root.add_child(citizen)
		citizen.rotation.y = -0.25
