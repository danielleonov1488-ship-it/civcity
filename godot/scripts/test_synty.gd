extends Node3D
## Каталог моделей Synty: аргумент — префикс имени или список через запятую; печатает размеры, делает снимок

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("cfe0ea")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e0d8c8")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.light_energy = 2.0
	add_child(sun)
	var args := OS.get_cmdline_user_args()
	var names := []
	var shot := "D:/CivCity/.work/gd/synty.png"
	for a in args:
		if a.begins_with("--shot="):
			shot = a.trim_prefix("--shot=")
		elif a.begins_with("--"):
			pass
		elif a.contains(","):
			names = a.split(",")
		else:
			names = Synty.names(a)
	var cols := int(ceil(sqrt(names.size() * 1.6)))
	var cell := 1.0
	var boxes := []
	for nm in names:
		var n := Synty.make(nm)
		var b := Artisau.aabb(n)
		boxes.append(b)
		cell = maxf(cell, maxf(b.size.x, b.size.z))
		print("SIZE ", nm, " ", b.size.snapped(Vector3.ONE * 0.01), " at ", b.position.snapped(Vector3.ONE * 0.01))
		n.queue_free()
	cell = minf(cell * 1.1, 14.0)
	var pivot := OS.get_cmdline_user_args().has("--pivot")
	for i in names.size():
		var n := Synty.make(names[i])
		var b: AABB = boxes[i]
		var fit := minf(1.0, cell / maxf(0.01, maxf(b.size.x, b.size.z)))
		n.scale = Vector3.ONE * fit
		var base := Vector3((i % cols) * cell, 0, int(i / cols) * cell * 1.15)
		if pivot:
			n.position = base
			# оси в точке привязки: красная +X, синяя +Z
			for ax: Array in [[Vector3(0.6, 0, 0), Color.RED], [Vector3(0, 0, 0.6), Color.BLUE], [Vector3(0, 0.6, 0), Color.GREEN]]:
				var m := MeshInstance3D.new()
				var bm := BoxMesh.new()
				var v: Vector3 = ax[0]
				bm.size = Vector3(maxf(absf(v.x), 0.05), maxf(absf(v.y), 0.05), maxf(absf(v.z), 0.05))
				m.mesh = bm
				var mt := StandardMaterial3D.new()
				mt.albedo_color = ax[1]
				mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				m.material_override = mt
				m.position = base + v * 0.5
				add_child(m)
		else:
			n.position = base + Vector3(-(b.position.x + b.size.x / 2) * fit, -b.position.y * fit, -(b.position.z + b.size.z / 2) * fit)
		add_child(n)
		var l := Label3D.new()
		l.text = names[i].trim_prefix("SM_Bld_").trim_prefix("SM_")
		l.font_size = 32
		l.pixel_size = cell * 0.003
		l.outline_size = 8
		l.position = base + Vector3(0, 0.05, cell * 0.45)
		l.rotation_degrees = Vector3(-55, 0, 0)
		add_child(l)
	var rows := int(ceil(names.size() / float(cols)))
	var cam := Camera3D.new()
	cam.fov = 45
	add_child(cam)
	var w := cols * cell
	var h := rows * cell * 1.15
	cam.look_at_from_position(Vector3(w * 0.75, maxf(w, h) * 0.55, h + maxf(w, h) * 0.45), Vector3(w / 2 - cell / 2, 0.8, h / 2 - cell / 2), Vector3.UP)
	set_meta("shot", shot)
	if not Synty.unknown.is_empty():
		print("UNKNOWN SLOTS ", Synty.unknown.keys())


var frame := 0
func _process(_dt: float) -> void:
	frame += 1
	if frame == 30:
		get_viewport().get_texture().get_image().save_png(get_meta("shot"))
		get_tree().quit()
