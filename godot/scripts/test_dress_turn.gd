extends Node3D
## Осмотр наполнения стен (CatDress) со всех сторон: дома и лавки пробной улицы стоят поодиночке, у каждого — снимки
## с четырёх сторон (спереди-слева, сбоку, сзади, с другого бока), крупно — бока и зад, и сверху сзади (сад, двор). Проверка «нейрослопа»:
## висит ли что в воздухе, не торчит ли из стен, не пересекается ли.
##   bash .work/py/gpu_run.sh res://test_dress_turn.tscn -- out=D:/CivCity/.work/street_synty/turn tag=a [before=1] [only=0,3] [pool=0]
var out := "D:/CivCity/.work/street_synty/turn"
var tag := "a"
var only := []
var pool := true                        # pool=0 — каждая деталь отдельным узлом (Parts.ghost), иначе — как в игре, MultiMesh (Parts)
## Десять зданий пробной улицы (тип, этажи, облик, цвет — как их ставит test_street_synty) и ещё восемь обликов
const LIST := [["house_pleb", 2, 0, 1], ["bakery", 0, 0, 1], ["house_artisan", 3, 0, 2], ["wineshop", 0, 0, 2], ["house_pleb", 3, 0, 3],
	["butcher", 0, 0, 3], ["house_artisan", 2, 0, 8], ["taberna", 0, 0, 8], ["house_pleb", 3, 0, 7], ["house_patrician", 2, 0, 9],
	["house_pleb", 2, 3, 5], ["house_artisan", 2, 4, 6], ["house_patrician", 2, 2, 4], ["house_pleb", 1, 1, 0],
	# и ещё: домусы с перголой и колодцем в саду, дома плебеев «балкон» и «фронтон» в два этажа
	["house_patrician", 2, 1, 5], ["house_patrician", 1, 3, 2], ["house_pleb", 2, 1, 4], ["house_pleb", 2, 2, 6]]


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		match kv[0]:
			"out": out = kv[1]
			"tag": tag = kv[1]
			"before": CatDress.sides_on = kv[1] != "1"
			"pool": pool = kv[1] != "0"
			"only":
				for s in kv[1].split(","):
					only.append(int(s))
	DirAccess.make_dir_recursive_absolute(out)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("bcd6e6")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e6dccb")
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-48, 25, 0)
	sun.light_energy = 2.1
	sun.light_color = Color("fff1dc")
	add_child(sun)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 600)
	g.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("8fae4a")
	g.material_override = gm
	add_child(g)
	_run()


func _run() -> void:
	var cam := Camera3D.new()
	cam.fov = 40
	add_child(cam)
	for i in LIST.size():
		if not only.is_empty() and not only.has(i):
			continue
		var e: Array = LIST[i]
		var bp := Catalog.make(e[0], e[1], e[2], e[3])
		var n: Node3D
		var hs := []
		if pool:
			n = Parts.new()
			(n as Parts).tint_split = true
			add_child(n)
			hs = (n as Parts).place(bp, Transform3D.IDENTITY)
		else:
			n = Parts.ghost(bp, "outline")
			for gi: GeometryInstance3D in n.find_children("*", "GeometryInstance3D", true, false):
				gi.material_override = null
				gi.material_overlay = null
				gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			add_child(n)
		var top := bp.top_y()
		var c := Vector3(0, minf(top * 0.45, 2.2), -0.6)
		# четыре стороны: спереди-слева, левый бок, зад, правый бок — и крупно бока и зад пониже
		var shots := [[35.0, 0.42, 1.0], [-80.0, 0.3, 0.85], [180.0, 0.3, 0.85], [80.0, 0.3, 0.85], [-100.0, 0.1, 0.62], [200.0, 0.1, 0.62],
			[100.0, 0.1, 0.62], [-30.0, 0.08, 0.6], [25.0, 2.6, 0.75]]
		for k in shots.size():
			var sh: Array = shots[k]
			var yaw := deg_to_rad(float(sh[0]))
			var d := (6.0 + top) * float(sh[2])
			var dir := Vector3(sin(yaw), float(sh[1]) * 2.0, cos(yaw)).normalized()
			# (k8 — круто сверху со стороны улицы, через крышу: сад домуса, двор ремесленника — как их видно в игре)
			var lk := c if k < 4 else (Vector3(c.x, 0.4, -2.4) if k == 8 else Vector3(c.x, 1.25, c.z))
			cam.look_at_from_position(lk + dir * d, lk)
			for f in 4:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s_%d_%s%d_k%d.png" % [out, tag, i, String(e[0]).trim_prefix("house_"), int(e[1]), k])
		n.queue_free()
		await get_tree().process_frame
	print("TURN DONE")
	get_tree().quit()
