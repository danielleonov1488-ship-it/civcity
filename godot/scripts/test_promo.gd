extends Node
## Снимки витрины (режим --promo) для сайта и ролика: геройские виды Showcase.VIEWS в разное время суток, без интерфейса.
## Запуск: bash .work/py/gpu_run.sh res://test_promo.tscn -- views=all hours=hero tag=v1
## Аргументы (после --): views=overview,market | all   hours=8,17.5,20.5,22.5 | hero (у каждого вида свой час)
##   tag=имя   out=D:/CivCity/.work/promo   size=1920x1080   wait=90 (кадров до снимка)
##   cams=имя:x:z:yaw:pitch:dist,… — свои виды (для проверки)   mode=demo — старый готовый город
##   stats=1 — какие детали дают больше всего треугольников   probe=1 — где тратится видеокарта   verbose — время этапов
## Печатает fps на каждом виде (в среднем за секунду) и время постройки города.
var game
var tag := "promo"
var views := []
var hours := []
var out := "D:/CivCity/.work/promo"
var wait := 90
var boot_mode := "promo"
var cams := {}
var view_arg := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv.size() != 2:
			continue
		match kv[0]:
			"tag": tag = kv[1]
			"views": view_arg = kv[1]
			"hours": hours = Array(kv[1].split(",")).map(func(x): return float(x)) if kv[1] != "hero" else []
			"out": out = kv[1]
			"wait": wait = int(kv[1])
			"mode": boot_mode = kv[1]
			"cams":
				# свои виды для проверки: имя:x:z:yaw:pitch:dist,…
				for c in kv[1].split(","):
					var f := c.split(":")
					cams[f[0]] = [float(f[1]), float(f[2]), float(f[3]), float(f[4]), float(f[5])]
			"size":
				var s := kv[1].split("x")
				get_window().size = Vector2i(int(s[0]), int(s[1]))
	if view_arg == "all" or (view_arg == "" and cams.is_empty()):
		views = Showcase.VIEWS.keys()
	elif view_arg != "":
		views = Array(view_arg.split(",")).filter(func(v): return Showcase.VIEWS.has(v))
	views.append_array(cams.keys())
	DirAccess.make_dir_recursive_absolute(out)
	Game.boot = {boot_mode: "1", "noui": "1", "hour": "9"}
	if OS.get_cmdline_user_args().has("verbose"):
		Game.boot["verbose"] = "1"
	var t0 := Time.get_ticks_msec()
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	while not game.ready_done:
		await frames(5)
	print("PROMO ready in %d ms" % (Time.get_ticks_msec() - t0))
	game.hud.visible = false
	await frames(30)
	var sc: Showcase = game.get_node_or_null("Showcase")
	if sc == null:
		sc = Showcase.new()
		sc.g = game
		sc.land = game.land
		sc.city = game.city
		sc._started = true
	var vp_rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	if OS.get_cmdline_user_args().has("stats=1"):
		_stats()
	var hs: Array = hours if not hours.is_empty() else [-1.0]
	for h: float in hs:
		for v in views:
			if cams.has(v):
				var cv: Array = cams[v]
				game.rig.set_view(Vector3(cv[0], game.land.height_at(cv[0], cv[1]), cv[1]), cv[2], cv[3], cv[4])
				if h < 0.0:
					game._set_hour(9.5)
			else:
				sc.view(v, h < 0.0)
			if h >= 0.0:
				game._set_hour(h)
			await frames(wait)
			var fps := Engine.get_frames_per_second()
			var gpu := RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
			var cpu := RenderingServer.viewport_get_measured_render_time_cpu(vp_rid)
			var prim := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
			var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			var proc := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			print("  view %s: gpu %.1f ms, render cpu %.1f ms, process %.1f ms, %.2fM tris, %d draws, %d people shown" % [v, gpu, cpu, proc, prim / 1.0e6, dc, game.people.visible_count])
			var name := "%s_%s_h%s.png" % [tag, v, str(snappedf(game.hour, 0.1)).replace(".", "_")]
			get_viewport().get_texture().get_image().save_png(out.path_join(name))
			print("SHOT %s fps=%d" % [name, fps])
			if OS.get_cmdline_user_args().has("probe=1"):
				await _probe(vp_rid)
	print("promo done")
	get_tree().quit()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Сколько треугольников дают группы деталей (по всему городу), самые тяжёлые — сверху
func _stats() -> void:
	var rows := []
	var total := 0
	var inst := 0
	for key in game.parts.groups:
		var gr: Dictionary = game.parts.groups[key]
		var used: int = gr["used"] - (gr["free"] as Array).size()
		var tris := 0
		for sub in gr["subs"]:
			var m: Mesh = (sub["mm"] as MultiMesh).mesh
			for si in m.get_surface_count():
				var arr := m.surface_get_arrays(si)
				var idx = arr[Mesh.ARRAY_INDEX]
				tris += (idx.size() / 3) if idx != null else ((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3)
		rows.append([tris * used, key, used, tris])
		total += tris * used
		inst += used
	rows.sort_custom(func(a, b): return a[0] > b[0])
	print("PARTS: %d groups, %d instances, %.2fM tris total" % [rows.size(), inst, total / 1.0e6])
	for r in rows.slice(0, 40):
		print("  %8d tris  x%5d  (%5d each)  %s" % [r[0], r[2], r[3], str(r[1]).left(90)])
	var by := {}
	for r in rows:
		var nm: String = str(r[1]).split("|")[0]
		var cat := nm.substr(0, 12)
		by[cat] = int(by.get(cat, 0)) + int(r[0])
	var cats := by.keys()
	cats.sort_custom(func(a, b): return by[a] > by[b])
	for c in cats.slice(0, 25):
		print("  cat %-14s %8d" % [c, by[c]])


func _gpu(vp_rid: RID) -> String:
	await frames(40)
	var acc := 0.0
	for i in 20:
		await frames(1)
		acc += RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
	var prim := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	return "gpu %.1f ms, %.2fM tris, %d draws" % [acc / 20.0, prim / 1.0e6, dc]


## Где тратится видеокарта: всё / без людей / без природы / без теней / без SDFGI
func _probe(vp_rid: RID) -> void:
	print("   all: ", await _gpu(vp_rid))
	game.people.visible = false
	print("   no people: ", await _gpu(vp_rid))
	var nat := []
	for key in game.parts.groups:
		var nm: String = str(key)
		if nm.begins_with("SM_Env_Tree") or nm.begins_with("SM_Env_Grass") or nm.begins_with("SM_Env_Flowers") or nm.begins_with("SM_Env_Bush") or nm.begins_with("SM_Env_Rock"):
			for sub in game.parts.groups[key]["subs"]:
				(sub["mmi"] as Node3D).visible = false
				nat.append(sub["mmi"])
	print("   + no nature: ", await _gpu(vp_rid))
	game.sun.shadow_enabled = false
	print("   + no sun shadow: ", await _gpu(vp_rid))
	game.env.sdfgi_enabled = false
	game.env.ssil_enabled = false
	print("   + no sdfgi/ssil: ", await _gpu(vp_rid))
	game.sun.shadow_enabled = true
	print("   only shadows back: ", await _gpu(vp_rid))
	game.env.sdfgi_enabled = true
	game.env.ssil_enabled = true
	for n in nat:
		(n as Node3D).visible = true
	game.people.visible = true
