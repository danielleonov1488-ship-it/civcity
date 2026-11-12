extends SceneTree
## Лист деталей Synty для подбора наполнения (CatDress): каждая модель — отдельным снимком спереди-сбоку, на сером
## фоне, рядом печатается число треугольников. Склейка с подписями — PIL (.work/street_synty/py).
##   bash .work/py/gpu_run.sh --script res://scripts/test_prop_sheet.gd -- names=SM_Prop_Bracket_01,… out=D:/CivCity/.work/street_synty/props [yaw=35] [pitch=20]
## names= можно и с «*» в конце: SM_Prop_FlowerPot_* — все модели с таким началом


func _init() -> void:
	var names := []
	var out := "D:/CivCity/.work/street_synty/props"
	var yaw := 35.0
	var pitch := 18.0
	for a: String in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		match kv[0]:
			"out": out = kv[1]
			"yaw": yaw = float(kv[1])
			"pitch": pitch = float(kv[1])
			"names":
				for nm in kv[1].split(","):
					if nm.ends_with("*"):
						names.append_array(Synty.names(nm.trim_suffix("*")))
					else:
						names.append(nm)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred(names, out, yaw, pitch)


func _run(names: Array, out: String, yaw: float, pitch: float) -> void:
	root.size = Vector2i(512, 512)
	var w3 := Node3D.new()
	root.add_child(w3)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("b9c3c9")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e6dccb")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var we := WorldEnvironment.new()
	we.environment = env
	w3.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 2.0
	sun.shadow_enabled = true
	w3.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 30
	w3.add_child(cam)
	var f := FileAccess.open(out + "/tris.txt", FileAccess.WRITE)
	for nm: String in names:
		var n := Synty.make(nm)
		w3.add_child(n)
		var box := Artisau.aabb(n)
		var t := 0
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				var ia: Array = mi.mesh.surface_get_arrays(s)
				var idx = ia[Mesh.ARRAY_INDEX]
				t += (idx.size() if idx != null and idx.size() > 0 else (ia[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		var c := box.get_center()
		var r := maxf(0.2, box.size.length() * 0.5)
		var dir := Vector3(sin(deg_to_rad(yaw)) * cos(deg_to_rad(pitch)), sin(deg_to_rad(pitch)), cos(deg_to_rad(yaw)) * cos(deg_to_rad(pitch)))
		cam.look_at_from_position(c + dir * r / tan(deg_to_rad(15.0)) * 1.05, c)
		for k in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [out, nm])
		f.store_line("%s %d %.2f %.2f %.2f" % [nm, t, box.size.x, box.size.y, box.size.z])
		print("PROP ", nm, " ", t, " ", box.size.snapped(Vector3.ONE * 0.01))
		n.queue_free()
		await process_frame
	f.close()
	quit()
