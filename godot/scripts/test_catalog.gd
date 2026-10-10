extends Node3D
## Каталог моделей Artisau: ряды с подписями, снимок

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("cfe0ea")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e0d8c8")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 2.0
	add_child(sun)
	var names := []
	var want := OS.get_cmdline_user_args()
	if want.size() > 0:
		names = want[0].split(",")
	else:
		for f in DirAccess.get_files_at("res://assets/artisau"):
			if f.ends_with(".fbx"):
				names.append(f.trim_suffix(".fbx"))
		names.sort()
	var cols := mini(10, names.size())
	for i in names.size():
		var n := Artisau.make(names[i])
		var box := Artisau.aabb(n.get_child(0))
		print("SIZE ", names[i], " ", box.size.snapped(Vector3.ONE * 0.01))
		var fit := 2.6 / maxf(box.size.x, maxf(box.size.y, box.size.z))
		n.scale = Vector3.ONE * fit
		n.position = Vector3((i % cols) * 3.2, 0, int(i / cols) * 3.6)
		add_child(n)
		var l := Label3D.new()
		l.text = names[i]
		l.font_size = 28
		l.pixel_size = 0.008
		l.outline_size = 6
		l.position = n.position + Vector3(0, 0.05, 1.5)
		l.rotation_degrees = Vector3(-60, 0, 0)
		add_child(l)
	var cam := Camera3D.new()
	cam.fov = 50
	add_child(cam)
	var rows := int(ceil(names.size() / float(cols)))
	var cx := (cols - 1) * 3.2 / 2.0
	cam.look_at_from_position(Vector3(cx, 3.5 + rows * 2.0, rows * 3.6 / 2.0 + 3.0 + cols * 1.1), Vector3(cx, 1.0, rows * 3.6 / 2.0 - 1.5), Vector3.UP)


var frame := 0
func _process(_dt: float) -> void:
	frame += 1
	if frame == 30:
		get_viewport().get_texture().get_image().save_png("D:/CivCity/.work/gd/catalog.png")
		get_tree().quit()
