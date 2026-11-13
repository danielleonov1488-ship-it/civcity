extends Node
## Новые пантеон, академия, форум и храм Венеры (NewGrand): снимки для владельца — «было/стало» (new=0 — прежняя
## сборка), пантеон на прежних клетках старого сохранения (fit=1), рядом с домами плебеев (масштаб), речь на форуме
## (service=1), двери открыты; город владельца (city=…): новые здания — на свободных местах рядом с храмом Юпитера.
##   bash .work/py/gpu_run.sh res://test_new_grand.tscn -- type=pantheon out=D:/CivCity/.work/rebuild/b2/<папка>/ [new=0] [fit=1]
##        [hours=11,18.5] [views=0,1,4] [houses=1] [service=1] [city=D:/CivCity/.work/owner_save/city.json [types=pantheon,forum]]
## Снимки: <out>/<метка>_v<вид>_h<час>.png, метка — new, fit или old; город — city_<тип>_v<вид>_h<час>.png, city_all_v<вид>…

var game
var c: City
var out := "D:/CivCity/.work/rebuild/b2/t/"
var type := "pantheon"
var hours := [11.0, 18.5]
var houses := false
var service := false
var fit := false
var city_src := ""
var types := ["pantheon", "academy", "forum", "venus"]
var vsel := []
var tagn := "new"


func _ready() -> void:
	var newv := true
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"out": out = kv[1]
			"type": type = kv[1]
			"new": newv = kv[1] != "0"
			"hours":
				hours = []
				for h in kv[1].split(","):
					hours.append(float(h))
			"houses": houses = kv[1] != "0"
			"service": service = kv[1] != "0"
			"fit": fit = kv[1] != "0"
			"city": city_src = kv[1]
			"types": types = Array(kv[1].split(","))
			"views":
				for v in kv[1].split(","):
					vsel.append(int(v))
	if not newv:
		NewGrand.ON[type] = false
	tagn = ("fit" if fit else "new") if NewGrand.covers(type) else "old"
	if city_src != "":
		# копия города владельца — в папку сохранений этого запуска (gpu_run: своя на каждый запуск), не в настоящую
		DirAccess.copy_absolute(city_src, GamePaths.save_dir().path_join("city.json"))
		Game.boot = {"play": "1", "hour": "11"}
	else:
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


func put(t: String, at: Vector2, v := -1, col := -1, tries := 60, stepr := 0.25) -> Dictionary:
	for k in tries:
		var p := at + Vector2(cos(k * 2.4), sin(k * 2.4)) * (k * stepr)
		var pl: Dictionary = game.placement(t, p, v, col) if v >= 0 else game.placement(t, p)
		if pl["err"] == "":
			var b := c.place(t, pl["pos"], pl["yaw"], pl["variant"], pl["color"], true)
			game._show(b)
			return b
	print("NG NOTE не встало ", t, " у ", at, ": ", (game.placement(t, at) as Dictionary).get("err", ""))
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


func info(t: Dictionary, what: String) -> void:
	var bp := c.blueprint(t)
	var r := Rect2()
	var first := true
	for rc: Rect2 in bp.footprint():
		r = rc if first else r.merge(rc)
		first = false
	var doors: Array = game.life.info(bp, String(t["type"]))["doors"]
	print("NG BUILD %s %s %s id=%d pos=%s yaw=%.2f sz=%s foot=%.2f×%.2f=%.1f top=%.2f door=%s parts=%d lights=%d actors=%d doors=%d" % [t["type"], tagn, what,
		int(t["id"]), t["pos"], float(t["yaw"]), str(t.get("sz", "—")), r.size.x, r.size.y, r.get_area(), bp.top_y(), bp.door, bp.parts.size(),
		bp.lights.size(), bp.actors.size(), doors.size()])


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
	game.can_save = false
	for r in Defs.RESEARCH:
		c.research[r["id"]] = true
	c.level = 7
	c.money = 900000
	c.legion.glory = 9999.0                       # пантеон и храм Венеры просят Славу Легиона
	game.hud.visible = false
	game.speed = 0.0
	if game.weather:
		game.weather.left_h = 0.0
		game.weather.force = 0.0
	if city_src != "":
		await _owner_city()
		return
	if game.people and not service:
		game.people.visible = false               # прохожие не мешают кадру (слушатели речи на форуме — с ними)
	var X0 := 150.0
	var Z0 := 124.0
	game.clear_nature(Vector2(X0, Z0), 38.0)
	game.land.paint_line(Vector2(X0 - 30.0, Z0), Vector2(X0 + 30.0, Z0), 2.2, Land.Kind.ROAD, true)
	await frames(4)
	var t := put(type, Vector2(X0, Z0 - 7.0))
	if t.is_empty():
		get_tree().quit()
		return
	if fit:
		t.erase("sz")                            # как из старого сохранения: облик — под прежние клетки (SizeLadder.old_lot)
		game._show(t)
	info(t, "")
	var tb := bounds(t)
	if houses:
		var hx := [float(tb[0]) - 2.6, float(tb[0]) - 6.3, float(tb[1]) + 2.6, float(tb[1]) + 6.3]
		for i in hx.size():
			var hb := put("house_pleb", Vector2(hx[i], Z0 - 4.0), i % 4, (i * 3) % 6)
			if not hb.is_empty():
				hb["pop"] = 3
				game._show(hb)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var dp := c.door_point(t)
		var f := City.facing(float(t["yaw"]))
		var ax := City.axis(float(t["yaw"]))
		for e: Array in [[-2.2, 1.2, false, false], [-1.4, 1.6, true, false], [-0.8, 2.6, false, true], [1.1, 1.3, false, false],
				[2.0, 2.2, true, false], [3.6, 0.9, false, false]]:
			_citizen(rng, dp + ax * float(e[0]) + f * float(e[1]), atan2(-f.x, -f.y) + rng.randf_range(-0.6, 0.6), e[2], e[3])
	await frames(30)
	DirAccess.make_dir_recursive_absolute(out)
	var ctr := Vector2((float(tb[0]) + float(tb[1])) * 0.5, (float(tb[2]) + float(tb[3])) * 0.5)
	# одна даль для «было» и «стало» — по типу, не по сборке: разница в размере видна сразу
	var D: float = {"pantheon": 21.0, "academy": 21.0, "forum": 19.0, "venus": 19.5}.get(type, 20.0)
	# [поворот от фасада, наклон, даль, цель: 0 — середина, 1 — вход]
	var views := [[28.0, 30.0, D, 0], [90.0, 26.0, D, 0], [200.0, 32.0, D, 0], [-90.0, 26.0, D, 0], [12.0, 12.0, 7.5, 1], [-35.0, 50.0, D * 1.3, 0]]
	if houses:
		views = [[8.0, 30.0, 30.0, 0], [35.0, 22.0, 19.0, 0]]
	if service:
		views = [[18.0, 28.0, 16.0, 0], [-25.0, 40.0, 22.0, 0], [6.0, 14.0, 9.0, 1]]
	await _shots(t, ctr, views)
	if service and game.spectacle:
		var V: Dictionary = game.spectacle.venues.get(int(t["id"]), {})
		if not V.is_empty():
			print("NG SERVICE мест %d, стоят %d, оратор %s" % [(V["lay"]["seats"] as Array).size(), (V["who"] as Array).size(),
				str((V["lay"] as Dictionary).get("priest", {}).get("root", "—"))])
	print("NG DONE")
	get_tree().quit()


func _shots(t: Dictionary, ctr: Vector2, views: Array, tag := "") -> void:
	var bp := c.blueprint(t)
	var f2 := City.facing(float(t["yaw"]))
	var fyd := rad_to_deg(atan2(f2.x, f2.y))
	var dp2 := c.door_point(t)
	var tg := tagn if tag == "" else tag
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
			var ty: float = game.land.height_at(ctr.x, ctr.y) + 1.6
			if int(v[3]) == 1:
				# вход: двери распахнуты (Life), видно освещённое нутро; дверей нет — середина между входом и серединой
				var e: Array = (game.life.info(bp, String(t["type"]))["doors"] as Array)
				var aim := ctr
				if not e.is_empty():
					var hm := Vector3.ZERO
					for le: Array in e:
						hm += le[1] as Vector3
					var hw: Vector3 = c.xf(t) * (hm / e.size())
					aim = Vector2(hw.x, hw.z)
				tp = dp2.lerp(aim, 0.75)
				ty = float(t["y"]) + 1.3
			game.rig.set_view(Vector3(tp.x, ty, tp.y), fyd + float(v[0]), float(v[1]), float(v[2]))
			await frames(3)
			if int(v[3]) == 1:
				game.life.door(t, 600.0)          # двери в кадре — Life распахивает их (вне кадра двери не шевелятся)
				game.speed = 1.0
				await secs(0.6)
				game.speed = 0.0
			await secs(0.8)
			await frames(30)
			get_viewport().get_texture().get_image().save_png(out + "%s_v%d_h%s.png" % [tg, i, str(h).replace(".", "_")])
			print("NG shot %s v%d h%s: вызовов %d, треугольников %d" % [tg, i, h, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])


## Город владельца: этих зданий в нём нет — новые встают на свободные места рядом с храмом Юпитера (как поставил бы игрок)
func _owner_city() -> void:
	var tm := {}
	for id in c.buildings:
		if c.buildings[id]["type"] == "temple":
			tm = c.buildings[id]
	DirAccess.make_dir_recursive_absolute(out)
	var from := Vector2(172.4, 148.7) if tm.is_empty() else (tm["pos"] as Vector2)
	if not tm.is_empty():
		info(tm, "храм владельца")
	var placed := []
	for t: String in types:
		var nb := {}
		for k in 1400:
			var p := from + Vector2(cos(k * 2.4), sin(k * 2.4)) * (7.0 + k * 0.1)
			var pl: Dictionary = game.placement(t, p)
			if pl["err"] == "":
				nb = c.place(t, pl["pos"], pl["yaw"], pl["variant"], pl["color"], true)
				game._show(nb)
				break
		if nb.is_empty():
			print("NG NOTE %s в городе владельца не встал" % t)
			continue
		tagn = "new"
		info(nb, "в городе, до храма %.1f м" % (nb["pos"] as Vector2).distance_to(from))
		placed.append(nb)
	await frames(40)
	for nb: Dictionary in placed:
		var tb := bounds(nb)
		var ctr := Vector2((float(tb[0]) + float(tb[1])) * 0.5, (float(tb[2]) + float(tb[3])) * 0.5)
		await _shots(nb, ctr, [[28.0, 34.0, 26.0, 0], [-30.0, 48.0, 42.0, 0]], "city_" + String(nb["type"]))
	# общий вид: храм и новые здания вместе
	if not placed.is_empty():
		var lo := from
		var hi := from
		for nb: Dictionary in placed:
			lo = lo.min(nb["pos"])
			hi = hi.max(nb["pos"])
		var ctr := (lo + hi) * 0.5
		var span := maxf((hi - lo).length(), 20.0)
		for h: float in hours:
			game._set_hour(h)
			await frames(20)
			for e: Array in [[0, 20.0, 46.0, 1.25], [1, 200.0, 40.0, 1.15]]:
				game.rig.set_view(Vector3(ctr.x, game.land.height_at(ctr.x, ctr.y) + 1.0, ctr.y), float(e[1]), float(e[2]), span * float(e[3]) + 14.0)
				await secs(0.8)
				await frames(30)
				get_viewport().get_texture().get_image().save_png(out + "city_all_v%d_h%s.png" % [int(e[0]), str(h).replace(".", "_")])
	print("NG DONE")
	get_tree().quit()
