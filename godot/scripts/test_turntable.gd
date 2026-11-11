extends Node3D
## Ролик-«вертушка» для показа людям: модели .glb с диска рядом, каждая медленно крутится на месте, подписи снизу.
## Кадры PNG → потом ffmpeg в .mp4. Свет — тёплое солнце с тенью, небо как в игре.
##   bash .work/py/gpu_run.sh res://test_turntable.tscn -- out=D:/CivCity/.work/house_view/frames
##     a=D:/…/house_artisan.glb an="Наш дом (Synty)" b=D:/…/higgsfield_tripo.glb bn="Higgsfield (Tripo)" secs=12 fps=30
var out := "D:/CivCity/.work/house_view/frames"
var items := [["D:/CivCity/.work/house_view/models/house_artisan.glb", "Наш дом — Synty, как в игре"],
	["D:/CivCity/.work/house_view/models/higgsfield_tripo.glb", "Higgsfield — нейросеть Tripo"]]
var secs := 12.0
var fps := 30
var pivots: Array[Node3D] = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		match kv[0]:
			"out": out = kv[1]
			"a": items[0][0] = kv[1]
			"an": items[0][1] = kv[1]
			"b": items[1][0] = kv[1]
			"bn": items[1][1] = kv[1]
			"secs": secs = float(kv[1])
			"fps": fps = int(kv[1])
	if String(items[1][0]) == "-":            # b=- — одна модель посередине, крупнее
		items.resize(1)
	DirAccess.make_dir_recursive_absolute(out)
	_stage()
	_run()


func _stage() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("9fbad6")
	sm.sky_horizon_color = Color("efe2c8")
	sm.ground_horizon_color = Color("e6d6b8")
	sm.ground_bottom_color = Color("b9a585")
	sky.sky_material = sm
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("e9dfcd")
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.92
	# пол без края: вдали тает в цвет фона
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("e9dfcd")
	env.fog_depth_begin = 16.0
	env.fog_depth_end = 40.0
	env.fog_sky_affect = 0.0
	env.ssao_enabled = true
	env.ssao_radius = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffe6c2")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	sun.rotation_degrees = Vector3(-42, 35, 0)
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	ground.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color("c9b997")
	gmat.roughness = 1.0
	ground.material_override = gmat
	add_child(ground)
	var cam := Camera3D.new()
	cam.fov = 28.0
	add_child(cam)
	cam.position = Vector3(0, 4.6, 10.5)
	cam.look_at(Vector3(0, 1.15, 0))
	var font = load("res://assets/fonts/Philosopher-Bold.ttf")
	var cl := CanvasLayer.new()
	add_child(cl)
	for i in items.size():
		var l := Label.new()
		l.text = String(items[i][1])
		if font:
			l.add_theme_font_override("font", font)
		l.add_theme_font_size_override("font_size", 40)
		l.add_theme_color_override("font_color", Color("2e261f"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.anchor_left = 0.5 * i
		l.anchor_right = 0.5 * (i + 1)
		l.anchor_top = 0.88
		l.anchor_bottom = 0.96
		cl.add_child(l)
	# модели: каждая — высотой 2.2 м, стоит на земле, ось вращения — середина
	for i in items.size():
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(String(items[i][0]), st) != OK:
			print("GLB error ", items[i][0])
			continue
		var m: Node3D = doc.generate_scene(st)
		var pivot := Node3D.new()
		add_child(pivot)
		pivot.position = Vector3(0 if items.size() == 1 else (-2.3 if i == 0 else 2.3), 0, 0)
		pivot.add_child(m)
		var bb := AABB()
		var first := true
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = m.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			bb = b if first else bb.merge(b)
			first = false
		var s := (2.6 if items.size() > 1 else 3.4) / maxf(bb.size.y, maxf(bb.size.x, bb.size.z) * (0.75 if items.size() > 1 else 0.62))
		m.scale = Vector3.ONE * s
		var c := bb.get_center()
		m.position = Vector3(-c.x * s, -bb.position.y * s, -c.z * s)
		pivots.append(pivot)
		print("MODEL ", items[i][0], " aabb ", bb, " scale ", snappedf(s, 0.001))


func _run() -> void:
	for i in 10:
		await get_tree().process_frame
	var n := int(secs * fps)
	for f in n:
		var a := -0.6 + TAU * float(f) / n          # полный оборот за ролик; начало — вполоборота к зрителю
		for p in pivots:
			p.rotation.y = a
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/f_%04d.png" % [out, f])
	print("FRAMES ", n, " → ", out)
	get_tree().quit()
