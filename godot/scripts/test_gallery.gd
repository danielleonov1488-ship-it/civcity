extends Node3D
## Выставка построек: аргументы — список "тип:этаж:фасад:цвет" через запятую, поворот камеры и путь снимка

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
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
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
	pm.size = Vector2(400, 400)
	g.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("8fae4a")
	g.material_override = gm
	add_child(g)
	var args := OS.get_cmdline_user_args()
	var list: PackedStringArray = args[0].split(",")
	var yaw := float(args[1]) if args.size() > 1 else 20.0
	var out: String = args[2] if args.size() > 2 else "D:/CivCity/.work/gd/gallery.png"
	var showfp := args.size() > 3 and args[3] == "fp"
	var cols := int(ceil(sqrt(list.size() * 1.5)))
	var x := 0.0
	var row := 0
	var maxd := 0.0
	var i := 0
	var cx := []
	for item in list:
		var p := item.split(":")
		var bp := Catalog.make(p[0], int(p[1]) if p.size() > 1 else 1, int(p[2]) if p.size() > 2 else 0, int(p[3]) if p.size() > 3 else i % 10)
		var fp := bp.footprint()
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for r: Rect2 in fp:
			lo = lo.min(r.position)
			hi = hi.max(r.end)
		if fp.is_empty():
			lo = Vector2(-2, -2)
			hi = Vector2(2, 2)
		var w := hi.x - lo.x
		var n := Parts.ghost(bp, "outline")
		for gi: GeometryInstance3D in n.find_children("*", "GeometryInstance3D", true, false):
			gi.material_override = null
		n.position = Vector3(x - lo.x, 0, row * 16.0)
		add_child(n)
		if showfp:
			for r: Rect2 in fp:
				var m := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(r.size.x, 0.05, r.size.y)
				m.mesh = bm
				var mm := StandardMaterial3D.new()
				mm.albedo_color = Color(1, 0, 0, 0.45)
				mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.material_override = mm
				m.position = n.position + Vector3(r.get_center().x, 0.03, r.get_center().y)
				add_child(m)
		x += w + 2.5
		i += 1
		if i % cols == 0:
			cx.append(x)
			x = 0.0
			row += 1
	cx.append(x)
	var width: float = cx.max()
	var depth := (row + 1) * 16.0
	var cam := Camera3D.new()
	add_child(cam)
	var c := Vector3(width / 2.0, 0, depth / 2.0 - 8.0)
	var dist := maxf(width, depth) * 0.95 + 6.0
	cam.fov = 38
	cam.look_at_from_position(c + Vector3(sin(deg_to_rad(yaw)), 0.75, cos(deg_to_rad(yaw))).normalized() * dist, c)
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(out)
	print("SHOT ", out)
	get_tree().quit()
