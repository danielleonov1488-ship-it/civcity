extends Node3D
## Проверка жителей. Аргументы (после --):
##   (нет)        — шесть фигур с разными движениями на простом фоне → people.png
##   mode=same    — те же шесть, позы заморожены (снимки можно сравнивать попиксельно) → people_<tag>.png;
##                  mask0=1 — одежда без перекраски (как атлас Synty)
##   mode=grid    — настоящая игра и её свет: ряды жителей по сословиям, полдень и вечер → togas_*.png
##   mode=fps     — настоящая игра, 150 жителей в кадре: время кадра GPU/CPU
##   mode=uv      — какие места атласа занимает одежда каждой модели (проверка полос тканей)
##   mode=pal     — частоты цветов у 4000 жителей против весов палитры (одежда — от состояния rng)
var mode := ""
var tag := "same"
var mask0 := false
var game


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv.size() == 2:
			match kv[0]:
				"mode": mode = kv[1]
				"tag": tag = kv[1]
				"mask0": mask0 = kv[1] == "1"
	match mode:
		"grid", "fps":
			Game.boot = {"new": "1", "noui": "1"}
			game = (load("res://main.tscn") as PackedScene).instantiate()
			add_child(game)
			if mode == "grid":
				_grid()
			else:
				_fps()
		"uv":
			_uv()
			get_tree().quit()
		"pal":
			_pal()
			get_tree().quit()
		_:
			_simple()


## Житель; cls передаётся, только если задан (так стенд работает и со старой версией Citizen.create)
func _mk(rng: RandomNumberGenerator, female: bool, child := false, rich := false, model := "", cls := "") -> Citizen:
	var c: Citizen
	if cls == "":
		c = Citizen.create(rng, female, child, rich, model)
	else:
		var s: GDScript = load("res://scripts/citizen.gd")
		c = s.callv("create", [rng, female, child, rich, model, cls])
	if mask0:
		for mi: MeshInstance3D in c.find_children("*", "MeshInstance3D", true, false):
			for p in ["mask_main", "mask_second", "mask_trim"]:
				mi.set_instance_shader_parameter(p, 0)
	return c


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


# ---------- простой стенд ----------

func _simple() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("cfe0ea")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d8d0c0")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.light_energy = 2.2
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("ddd1bc")
	ground.material_override = gm
	add_child(ground)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var anims := ["Walk_Loop", "Idle_Talking_Loop", "Idle_Loop", "Walk_Formal_Loop", "Sitting_Talking_Loop", "Push_Loop"]
	for i in 6:
		var c := _mk(rng, i % 2 == 1, i == 5, i == 2 or i == 3)
		add_child(c)
		c.position = Vector3(-3.75 + i * 1.5, 0, 0)
		c.rotation.y = 0.35
		c.play(anims[i], 0.0)
		if mode == "same":
			c.anim.seek(0.4, true)
			c.anim.speed_scale = 0.0
		if i == 0:
			print("ANIMS ", c.anim.get_animation_list().slice(0, 12))
	var cam := Camera3D.new()
	cam.fov = 35
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.8, 7.5), Vector3(0, 0.95, 0), Vector3.UP)
	await frames(40)
	var out := "D:/CivCity/.work/gd/people.png" if mode == "" else "D:/CivCity/.work/gd/people_%s.png" % tag
	get_viewport().get_texture().get_image().save_png(out)
	print("PEOPLE saved ", out)
	get_tree().quit()


# ---------- ряды по сословиям в настоящей игре ----------

const ROWS := [
	["plebs", ["SK_Chr_Worker_Male_01", "SK_Chr_Worker_Female_01", "SK_Chr_Farmer_Male_01", "SK_Chr_Farmer_Female_01"], false],
	["artisans", ["SK_Chr_Worker_Male_01", "SK_Chr_Worker_Female_01", "SK_Chr_Farmer_Male_01", "SK_Chr_Farmer_Female_01"], false],
	["patricians", ["SK_Chr_Upperclass_Male_01", "SK_Chr_Upperclass_Female_01", "SK_Chr_Politician_Male_01"], false],
	["kids", ["SK_Chr_Worker_Male_01", "SK_Chr_Worker_Female_01", "SK_Chr_Farmer_Male_01", "SK_Chr_Farmer_Female_01", "SK_Chr_Upperclass_Male_01", "SK_Chr_Upperclass_Female_01"], true],
]
const X0 := 186.0
const Z0 := 140.0

func _grid() -> void:
	while not game.ready_done:
		await frames(5)
	game.hud.visible = false
	game.speed = 0.0
	game.clock_hours = false
	game.rig.cine = true
	# четыре группы вдоль улицы: плебеи, ремесленники, патриции, дети; в группе два ряда по шесть
	game.land.paint_line(Vector2(X0 - 2.0, Z0 + 0.3), Vector2(X0 + 30.0, Z0 + 0.3), 2.6, Land.Kind.PLAZA, true)
	var n := 0
	var centers := []
	for ri in ROWS.size():
		var row: Array = ROWS[ri]
		var models: Array = row[1]
		var per := 12 / models.size() if not row[2] else 2
		var bx := X0 + ri * 7.5
		centers.append(Vector3(bx + 2.7, 0.0, Z0 + 0.35))
		var j := 0
		for m: String in models:
			for k in per:
				var cls: String = row[0]
				if row[2]:
					cls = ["plebs", "artisans", "patricians"][k % 3] if not m.begins_with("SK_Chr_Upperclass") else "patricians"
				var rng := RandomNumberGenerator.new()
				rng.seed = 1000 + n * 17
				n += 1
				var c := _mk(rng, false, row[2], cls == "patricians", m, cls)
				game.actors_root.add_child(c)
				var x := bx + (j / 2) * 1.0 + (0.5 if j % 2 == 1 else 0.0)
				var z := Z0 + (0.0 if j % 2 == 1 else 0.75)
				c.position = Vector3(x, game.land.height_at(x, z), z)
				c.rotation.y = 0.2
				c.play("Idle_Loop", 0.0)
				c.anim.seek(0.6, true)
				c.anim.speed_scale = 0.0
				# «тает в двери»: последний из плебеев — полупрозрачный
				if ri == 0 and j == 11:
					c.set_alpha(0.45)
				j += 1
	var names := ["_plebs", "_artisans", "_rich", "_kids"]
	for h: Array in [[12.5, "noon"], [18.5, "evening"]]:
		game._set_hour(float(h[0]))
		var shots := [["", Vector3(X0 + 13.5, 0.0, Z0 + 0.3), Vector3(0.0, 13.0, 25.0)]]
		for i in 4:
			shots.append([names[i], centers[i], Vector3(0.0, 1.5, 6.4)])
		for s: Array in shots:
			var look: Vector3 = s[1]
			look.y = game.land.height_at(look.x, look.z) + 0.55
			game.rig.cine_look(look + (s[2] as Vector3), look)
			await frames(60)
			var out := "D:/CivCity/.work/gd/togas_%s%s%s.png" % [h[1], s[0], "_mask0" if mask0 else ""]
			get_viewport().get_texture().get_image().save_png(out)
			print("TOGAS saved ", out)
	print("TOGAS DONE citizens=", n)
	get_tree().quit()


# ---------- время кадра со 150 жителями ----------

func _fps() -> void:
	while not game.ready_done:
		await frames(5)
	game.hud.visible = false
	game.speed = 0.0
	game.clock_hours = false
	game._set_hour(12.5)
	var n := 0
	for i in 15:
		for j in 10:
			var rng := RandomNumberGenerator.new()
			rng.seed = 500 + n * 31
			var cls: String = ["plebs", "plebs", "artisans", "patricians"][n % 4]
			var c := _mk(rng, n % 2 == 0, n % 5 == 4, cls == "patricians", "", cls if tag == "new" else "")
			game.actors_root.add_child(c)
			var p := Vector3(X0 + i * 0.9, 0, Z0 + j * 0.9)
			p.y = game.land.height_at(p.x, p.z)
			c.position = p
			c.rotation.y = n * 0.7
			c.play("Walk_Loop", 0.0, float(n % 7) / 7.0)
			n += 1
	game.rig.set_view(Vector3(X0 + 6.5, 0.8, Z0 + 4.0), 10, 32, 13)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	await frames(90)
	var gpu := 0.0
	var cpu := 0.0
	var t0 := Time.get_ticks_usec()
	var N := 400
	for f in N:
		await get_tree().process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
	var wall := (Time.get_ticks_usec() - t0) / 1000.0 / N
	get_viewport().get_texture().get_image().save_png("D:/CivCity/.work/gd/togas_fps_%s.png" % tag)
	print("FPS %s citizens=%d gpu_ms=%.3f cpu_ms=%.3f frame_ms=%.3f fps=%.1f draws=%d" % [tag, n, gpu / N, cpu / N, wall, 1000.0 / wall,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	get_tree().quit()


# ---------- полосы атласа под одеждой ----------

func _region(uv: Vector2) -> Array:
	var p := Vector2(fposmod(uv.x, 1.0), fposmod(uv.y, 1.0)) * 4096.0
	if p.x >= 1435.0 and p.x < 2047.0 and p.y >= 3788.0 and p.y < 4032.0:
		return ["c%d" % mini(int((p.x - 1435.0) / 43.714), 13), mini(int((p.y - 3788.0) / 81.333), 2), p]
	if p.y >= 4032.0 and p.x >= 1404.0 and p.x < 2044.0:
		return ["w%d" % int((p.x - 1404.0) / 128.0), 0, p]
	if p.x >= 3840.0 and p.y >= 2878.0 and p.y < 3698.0:
		return ["meander", 0, p]
	return ["other", 0, p]


func _uv() -> void:
	var edges := [1435, 1478, 1521, 1565, 1609, 1653, 1697, 1741, 1785, 1828, 1872, 1916, 1960, 2003, 2047]
	for m in Citizen.PLEBS + Citizen.RICH + ["SK_Chr_Solider_Male_01"]:
		var body := (load(Citizen.DIR + m + ".fbx") as PackedScene).instantiate()
		var area := {}
		var tot := 0.0
		var near := 0
		var span := 0
		var others := {}
		for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				var arr := mi.mesh.surface_get_arrays(s)
				var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				for t in range(0, idx.size(), 3):
					var a := (vs[idx[t + 1]] - vs[idx[t]]).cross(vs[idx[t + 2]] - vs[idx[t]]).length() * 0.5
					var rs := [_region(uvs[idx[t]]), _region(uvs[idx[t + 1]]), _region(uvs[idx[t + 2]])]
					var cen := _region((uvs[idx[t]] + uvs[idx[t + 1]] + uvs[idx[t + 2]]) / 3.0)
					var key := "%s/%d" % [cen[0], cen[1]]
					area[key] = float(area.get(key, 0.0)) + a
					tot += a
					if rs[0][0] != rs[1][0] or rs[1][0] != rs[2][0]:
						span += 1
					for r in rs:
						if String(r[0]).begins_with("c"):
							for e in edges:
								if absf((r[2] as Vector2).x - e) < 2.0:
									near += 1
					if cen[0] == "other":
						var q := (cen[2] as Vector2) / 64.0
						var ok := "%d,%d" % [int(q.x) * 64, int(q.y) * 64]
						others[ok] = float(others.get(ok, 0.0)) + a
		var keys := area.keys()
		keys.sort_custom(func(x, y): return area[x] > area[y])
		var parts := []
		for k in keys:
			parts.append("%s %.1f%%" % [k, 100.0 * area[k] / tot])
		print("UV ", m.trim_prefix("SK_Chr_").trim_suffix("_01"), ": ", ", ".join(parts), " | spanning tris ", span, ", verts within 2px of a column edge ", near)
		var ok2 := others.keys()
		ok2.sort_custom(func(x, y): return others[x] > others[y])
		var op := []
		for k in ok2.slice(0, 6):
			op.append("%s %.1f%%" % [k, 100.0 * others[k] / tot])
		print("   other blocks: ", ", ".join(op))
		body.free()


# ---------- частоты цветов ----------

func _pal() -> void:
	var src := RandomNumberGenerator.new()
	src.seed = 77
	for pal_name in ["plebs", "artisans"]:
		var pal: Array = Citizen.PAL[pal_name]
		var sum := 0
		for e in pal:
			sum += int(e[1])
		var got := {}
		var N := 4000
		for i in N:
			# как у жителя: семя от rng игры, затем модель и тон кожи, потом поток одежды
			var rr := RandomNumberGenerator.new()
			rr.seed = src.randi()
			rr.randi()
			rr.randi()
			var cr := RandomNumberGenerator.new()
			cr.seed = rr.state ^ 0x5DEECE66D
			var h := Citizen._pick(cr, pal).to_html(false)
			got[h] = int(got.get(h, 0)) + 1
		var worst := 0.0
		var parts := []
		for e in pal:
			var want := float(e[1]) / sum
			var have := float(got.get(String(e[0]), 0)) / N
			worst = maxf(worst, absf(have - want))
			parts.append("%s %.1f/%.1f" % [e[0], 100.0 * have, 100.0 * want])
		print("PAL %s worst=%.1f%% : %s" % [pal_name, 100.0 * worst, ", ".join(parts)])
