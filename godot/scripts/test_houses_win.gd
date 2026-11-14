extends SceneTree
## Окна Synty с разными решётками (для новых домов), один снимок: bash .work/py/gpu_run.sh --script res://scripts/test_houses_win.gd -- out=<png>


func _initialize() -> void:
	var out := "D:/CivCity/.work/rebuild/houses/props/windows.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	_run.call_deferred(out)


func _run(out: String) -> void:
	root.size = Vector2i(1800, 700)
	var w3 := Node3D.new()
	root.add_child(w3)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("6b4a33")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e6dccb")
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	w3.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 25, 0)
	sun.light_energy = 1.6
	w3.add_child(sun)
	var t := Color(1.0, 0.82, 0.64)
	var win := {"Stucco_White_01": "Building_Marble_01", "Stucco_Orange_01": "Stucco_White_01", "tints": {"Stucco_White_01": t}}
	var list := [["SM_Bld_Wall_Window_01", {}], ["SM_Bld_Wall_Window_01", {"Window_01": "Window_02"}], ["SM_Bld_Wall_Window_01", {"Window_01": "Window_03"}],
		["SM_Bld_Wall_Window_01", {"Window_01": "Window_04"}], ["SM_Bld_Wall_Window_05", {}], ["SM_Bld_Wall_Window_06", {}], ["SM_Bld_Wall_Window_03", {}],
		["SM_Bld_Wall_Window_02", {}], ["SM_Bld_Wall_Window_04", {}]]
	for i in list.size():
		var rm: Dictionary = win.duplicate(true)
		rm.merge(list[i][1], true)
		var n := Synty.make(String(list[i][0]), rm)
		n.position = Vector3(i * 2.8, 0, 0)
		w3.add_child(n)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 9.0
	w3.add_child(cam)
	cam.look_at_from_position(Vector3(12.4, 1.5, 20), Vector3(12.4, 1.5, 0))
	for k in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("WIN DONE")
	quit()
