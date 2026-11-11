extends Node
## Лист движений жителей: по человечку на движение, кадр в момент t (для подбора поз досуга)
##   bash .work/py/gpu_run.sh res://test_anims.tscn -- anims=Smell,Admire t=1.5 out=D:/CivCity/.work/kit/anims.png


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var names: PackedStringArray = String(args.get("anims", "Idle,Smell,Admire,Point,Pray,Feed,Wash,Clap,Stretch,Wave,Arms_Crossed")).split(",")
	var t := float(args.get("t", "1.4"))
	var out := String(args.get("out", "D:/CivCity/.work/kit/anims.png"))
	var vp := SubViewport.new()
	vp.size = Vector2i(200 * names.size(), 340)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("d9e4d0")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("e6dccb")
	we.environment = e
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	vp.add_child(sun)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var cs := []
	for i in names.size():
		var c := Citizen.create(rng, i % 2 == 1)
		vp.add_child(c)
		c.position = Vector3(i * 0.9, 0, 0)
		c.rotation.y = float(args.get("yaw", "0.6"))
		cs.append(c)
	await get_tree().process_frame
	var lib := Citizen.library()
	for i in names.size():
		var nm := names[i]
		if nm.begins_with("@"):                # проба оси: @кость:ось:угол[;кость:ось:угол]
			var acc := {}
			for part in nm.substr(1).split(";"):
				var q := part.split(":")
				var v: Vector3 = acc.get(q[0], Vector3.ZERO)
				v["xyz".find(q[1])] = float(q[2])
				acc[q[0]] = v
			var offs := {}
			for bn: String in acc:
				var vv: Vector3 = acc[bn]
				offs[bn] = func(_t: float) -> Vector3: return vv
			var an := Citizen._layer(lib.get_animation("Idle"), 1, offs)
			lib.add_animation("probe%d" % i, an)
			nm = "probe%d" % i
		(cs[i] as Citizen).play(nm, 0.0, 0.0)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.5
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	vp.add_child(cam)
	var cx := (names.size() - 1) * 0.45
	cam.position = Vector3(cx, 0.6, 6.0)
	cam.look_at(Vector3(cx, 0.55, 0.0))
	var waited := 0.0
	while waited < t:
		await get_tree().process_frame
		waited += get_process_delta_time()
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out)
	print("ANIMS ", out)
	get_tree().quit()
