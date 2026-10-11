extends Node3D
## Выставка построек: аргументы — список "тип:уровень" через запятую, камера yaw и путь снимка

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("bcd6e6")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e6dccb")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.ssao_intensity = 2.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-42, 35, 0)
	sun.light_energy = 2.3
	sun.light_color = Color("fff1dc")
	add_child(sun)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(300, 300)
	g.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("93b05c")
	g.material_override = gm
	add_child(g)
	var parts := Parts.new()
	add_child(parts)
	var a := OS.get_cmdline_user_args()
	var list: PackedStringArray = a[0].split(",")
	var cols := int(ceil(sqrt(list.size())))
	var cell := 17.0
	for i in list.size():
		var t := list[i].split(":")
		var tier := int(t[1]) if t.size() > 1 else 0
		var seed_v := int(t[2]) if t.size() > 2 else i
		var bp := Catalog.make(t[0], tier, seed_v)
		var p := Vector3((i % cols) * cell, 0, int(i / cols) * cell)
		parts.place(bp, Transform3D(Basis.IDENTITY, p))
		var l := Label3D.new()
		l.text = list[i]
		l.font_size = 48
		l.pixel_size = 0.02
		l.outline_size = 10
		l.position = p + Vector3(0, 0.1, 8.0)
		l.rotation_degrees = Vector3(-60, 0, 0)
		add_child(l)
	var rows := int(ceil(list.size() / float(cols)))
	var yaw := deg_to_rad(float(a[1]) if a.size() > 1 else 25.0)
	var d := maxf(cols, rows) * cell * 0.62 + 6.0
	var c := Vector3((cols - 1) * cell / 2.0, 2.0, (rows - 1) * cell / 2.0)
	var cam := Camera3D.new()
	cam.fov = 40
	add_child(cam)
	cam.look_at_from_position(c + Vector3(sin(yaw), 0.62, cos(yaw)) * d, c, Vector3.UP)
	set_meta("shot", a[2] if a.size() > 2 else "D:/CivCity/.work/gd/gallery.png")
	print("PARTS ", parts.count(), " groups ", parts.groups.size())

var frame := 0
func _process(_dt: float) -> void:
	frame += 1
	if frame == 20:
		get_viewport().get_texture().get_image().save_png(get_meta("shot"))
		get_tree().quit()
