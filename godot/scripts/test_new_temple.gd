extends Node
## Пробный новый храм Юпитера (NewTemple): снимки для владельца — «было/стало» (newtemple=0 — прежний храм),
## храм рядом с домами плебеев и жителями (масштаб), утренняя служба (люди на ступенях), врата открыты.
##   bash .work/py/gpu_run.sh res://test_new_temple.tscn -- out=D:/CivCity/.work/pilot/temple/<папка>/ [newtemple=0] [hours=11,18.5]
##        [houses=1] [people=1] [service=1] [views=0,1,4]
## Снимки: <out>/<метка>_v<вид>_h<час>.png, метка — new или old. Склейка листов — .work/pilot/temple/py.

var game
var c: City
var out := "D:/CivCity/.work/pilot/temple/t/"
var hours := [11.0, 18.5]
var houses := false
var people := false
var service := false
var vsel := []
var tagn := "new"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"out": out = kv[1]
			"newtemple":
				NewTemple.ON = kv[1] != "0"
			"hours":
				hours = []
				for h in kv[1].split(","):
					hours.append(float(h))
			"houses": houses = kv[1] != "0"
			"people": people = kv[1] != "0"
			"service": service = kv[1] != "0"
			"views":
				for v in kv[1].split(","):
					vsel.append(int(v))
	tagn = "new" if NewTemple.ON else "old"
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func secs(t: float) -> void:
	var w := 0.0
	while w < t:
		await get_tree().process_frame
		w += get_process_delta_time()


func put(type: String, at: Vector2, v := -1, col := -1) -> Dictionary:
	for k in 60:
		var p := at + Vector2(cos(k * 2.4), sin(k * 2.4)) * (k * 0.25)
		var pl: Dictionary = game.placement(type, p, v, col) if v >= 0 else game.placement(type, p)
		if pl["err"] == "":
			var b := c.place(type, pl["pos"], pl["yaw"], pl["variant"], pl["color"], true)
			game._show(b)
			return b
	print("NT NOTE не встало ", type, " у ", at)
	return {}


func bounds(b: Dictionary) -> Array:
	var xf := c.xf(b)
	var r := [INF, -INF, INF, -INF]
	for rc: Rect2 in c.blueprint(b).footprint():
		for q: Vector2 in [rc.position, rc.end, Vector2(rc.position.x, rc.end.y), Vector2(rc.end.x, rc.position.y)]:
			var w := xf * Vector3(q.x, 0, q.y)
			r[0] = minf(r[0], w.x)
			r[1] = maxf(r[1], w.x)
			r[2] = minf(r[2], w.z)
			r[3] = maxf(r[3], w.z)
	return r


func _citizen(rng: RandomNumberGenerator, p: Vector2, yaw: float, rich := false, child := false) -> void:
	var cn := Citizen.create(rng, rng.randf() < 0.5, child, rich)
	game.add_child(cn)
	cn.position = Vector3(p.x, game.land.height_at(p.x, p.y), p.y)
	cn.rotation.y = yaw
	cn.play("Idle_Loop", 0.0, rng.randf())


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(10)
	c = game.city
	for r in Defs.RESEARCH:
		c.research[r["id"]] = true
	c.level = 7
	c.money = 900000
	game.hud.visible = false
	game.speed = 0.0
	if game.weather:
		game.weather.left_h = 0.0
		game.weather.force = 0.0
	if game.people and not service:
		game.people.visible = false               # своих жителей ставим сами (масштаб), прохожие не мешают кадру (зрители службы — с ними)
	var X0 := 150.0
	var Z0 := 124.0
	game.clear_nature(Vector2(X0, Z0), 34.0)
	game.land.paint_line(Vector2(X0 - 26.0, Z0), Vector2(X0 + 26.0, Z0), 2.2, Land.Kind.ROAD, true)
	await frames(4)
	var t := put("temple", Vector2(X0, Z0 - 6.0))
	if t.is_empty():
		get_tree().quit()
		return
	var tb := bounds(t)
	var bp := c.blueprint(t)
	print("NT TEMPLE %s pos=%s yaw=%.2f foot=%.2f×%.2f top=%.2f door=%s parts=%d" % [tagn, t["pos"], float(t["yaw"]), float(tb[1]) - float(tb[0]), float(tb[3]) - float(tb[2]), bp.top_y(), bp.door, bp.parts.size()])
	if houses:
		# дома плебеев в ряд с храмом: два слева, два справа (с промежутком, как ставит игрок)
		var hx := [float(tb[0]) - 2.6, float(tb[0]) - 6.3, float(tb[1]) + 2.6, float(tb[1]) + 6.3]
		for i in hx.size():
			var hb := put("house_pleb", Vector2(hx[i], Z0 - 4.0), i % 4, (i * 3) % 6)
			if not hb.is_empty():
				hb["pop"] = 3
				game._show(hb)
	if people:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var dp := c.door_point(t)
		var f := City.facing(float(t["yaw"]))
		var ax := City.axis(float(t["yaw"]))
		var fy := atan2(-f.x, -f.y)
		for e: Array in [[-2.2, 1.2, false, false], [-1.4, 1.6, true, false], [-0.8, 2.6, false, true], [1.1, 1.3, false, false],
				[2.0, 2.2, true, false], [3.6, 0.9, false, false], [-3.9, 1.4, false, false], [0.4, 3.2, false, false]]:
			var p: Vector2 = dp + ax * float(e[0]) + f * float(e[1])
			_citizen(rng, p, fy + rng.randf_range(-0.6, 0.6), e[2], e[3])
	await frames(30)
	DirAccess.make_dir_recursive_absolute(out)
	var ctr := Vector2((float(tb[0]) + float(tb[1])) * 0.5, (float(tb[2]) + float(tb[3])) * 0.5)
	var f2 := City.facing(float(t["yaw"]))
	var fyd := rad_to_deg(atan2(f2.x, f2.y))
	var dp2 := c.door_point(t)
	# [поворот от фасада, наклон, даль, цель: 0 — середина, 1 — врата]
	var views := [[28.0, 30.0, 15.0, 0], [90.0, 28.0, 14.0, 0], [200.0, 34.0, 15.0, 0], [-90.0, 28.0, 14.0, 0],
		[0.0, 10.0, 5.2, 1], [-35.0, 45.0, 20.0, 0], [30.0, 16.0, 6.0, 1]]
	if houses:
		views = [[8.0, 30.0, 22.0, 0], [35.0, 22.0, 14.0, 0], [-25.0, 40.0, 26.0, 0]]
	for h: float in hours:
		game._set_hour(h)
		await frames(20)
		if service and game.spectacle:
			game.spectacle.force(int(t["id"]), "show", 1.0, true)
			await secs(1.0)
		for i in views.size():
			if not vsel.is_empty() and not vsel.has(i):
				continue
			var v: Array = views[i]
			var tp := ctr
			var ty: float = game.land.height_at(ctr.x, ctr.y) + 1.4
			if int(v[3]) == 1:
				# вход: врата распахнуты (Life), видно освещённую целлу
				var e: Array = (game.life.info(bp, "temple")["doors"] as Array)
				if not e.is_empty():
					var hm := Vector3.ZERO
					for le: Array in e:
						hm += le[1] as Vector3
					var hw: Vector3 = c.xf(t) * (hm / e.size())
					tp = dp2.lerp(Vector2(hw.x, hw.z), 0.8)
				ty = float(t["y"]) + 1.1
			game.rig.set_view(Vector3(tp.x, ty, tp.y), fyd + float(v[0]), float(v[1]), float(v[2]))
			await frames(3)
			if int(v[3]) == 1:
				game.life.door(t, 600.0)          # врата в кадре — Life распахивает их (вне кадра двери не шевелятся)
				game.speed = 1.0                  # створки движутся со скоростью игры
				await secs(0.6)
				game.speed = 0.0
			await secs(0.8)
			await frames(30)
			get_viewport().get_texture().get_image().save_png(out + "%s_v%d_h%s.png" % [tagn, i, str(h).replace(".", "_")])
			print("NT shot %s v%d h%s: вызовов %d, треугольников %d" % [tagn, i, h, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	if service and game.spectacle:
		var V: Dictionary = game.spectacle.venues.get(int(t["id"]), {})
		if not V.is_empty():
			print("NT SERVICE мест %d, стоят %d, жрец %s" % [(V["lay"]["seats"] as Array).size(), (V["who"] as Array).size(), str((V["lay"] as Dictionary).has("priest"))])
	print("NT DONE")
	get_tree().quit()
