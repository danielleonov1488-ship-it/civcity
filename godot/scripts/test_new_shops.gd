extends Node
## Новые лавки (NewShops): снимки для владельца — «было/стало» (new=0 — прежняя сборка CatShops), каждая лавка со всех
## сторон, вход вблизи и сверху; улица из всех 17 лавок в ряд (street=1); разные цвета и облики одного ремесла рядом
## (variety=1); двери открыты.
##   bash .work/py/gpu_run.sh res://test_new_shops.tscn -- types=butcher,bakery out=D:/CivCity/.work/rebuild/shops1/<папка>/
##        [new=0] [color=N] [hours=11,18.5] [views=0,1,4] [street=1] [variety=1] [people=1]
## Снимки: <out>/<тип>_<метка>_v<вид>_h<час>.png (метка new/old); street_<метка>_v<вид>_h<час>.png; variety_<тип>_v<вид>_h<час>.png

var game
var c: City
var out := "D:/CivCity/.work/rebuild/shops1/t/"
var types := []
var hours := [11.0]
var color := 3
var vsel := []
var tagn := "new"
var street := false
var variety := false
var people := false


func _ready() -> void:
	var newv := true
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"out": out = kv[1]
			"types": types = Array(kv[1].split(","))
			"new": newv = kv[1] != "0"
			"hours":
				hours = []
				for h in kv[1].split(","):
					hours.append(float(h))
			"street": street = kv[1] != "0"
			"variety": variety = kv[1] != "0"
			"people": people = kv[1] != "0"
			"color": color = int(kv[1])
			"views":
				for v in kv[1].split(","):
					vsel.append(int(v))
	if types.is_empty():
		types = NewShops.TYPES.duplicate()
	if not newv:
		for t: String in NewShops.TYPES:
			NewShops.ON[t] = false
	tagn = "new" if newv else "old"
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
	print("NSH NOTE не встало ", t, " у ", at, ": ", (game.placement(t, at) as Dictionary).get("err", ""))
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
	var inf: Dictionary = game.life.info(bp, String(t["type"]))
	print("NSH BUILD %s %s %s id=%d pos=%s yaw=%.2f color=%d foot=%.2f×%.2f=%.1f (x %.2f..%.2f z %.2f..%.2f) top=%.2f door=%s parts=%d lights=%d actors=%d doors=%d shutter_pairs=%d seats=%d apron=%d" % [
		t["type"], tagn, what, int(t["id"]), t["pos"], float(t["yaw"]), int(t["color"]), r.size.x, r.size.y, r.get_area(),
		r.position.x, r.end.x, r.position.y, r.end.y, bp.top_y(), bp.door, bp.parts.size(), bp.lights.size(), bp.actors.size(),
		(inf["doors"] as Array).size(), int(inf["pairs"]), (inf["seats"] as Array).size(), c.apron_of(t)])


func _citizens(t: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var dp := c.door_point(t)
	var f := City.facing(float(t["yaw"]))
	var ax := City.axis(float(t["yaw"]))
	for e: Array in [[-1.0, 0.9, false], [0.8, 1.2, true], [1.6, 0.8, false]]:
		var cn := Citizen.create(rng, rng.randf() < 0.5, false, bool(e[2]))
		game.add_child(cn)
		var p: Vector2 = dp + ax * float(e[0]) + f * float(e[1])
		cn.position = Vector3(p.x, game.land.height_at(p.x, p.y), p.y)
		cn.rotation.y = atan2(-f.x, -f.y) + rng.randf_range(-0.6, 0.6)
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
	c.cozy_v = 1
	game.hud.visible = false
	game.speed = 0.0
	if game.weather:
		game.weather.left_h = 0.0
		game.weather.force = 0.0
	if game.people and not people:
		game.people.visible = false
	var X0 := 150.0
	var Z0 := 124.0
	game.clear_nature(Vector2(X0 + 10.0, Z0), 70.0)
	game.land.paint_line(Vector2(X0 - 30.0, Z0), Vector2(X0 + 76.0, Z0), 2.2, Land.Kind.ROAD, true)
	await frames(4)
	DirAccess.make_dir_recursive_absolute(out)
	if street:
		await _street(X0, Z0)
		return
	if variety:
		await _variety(X0, Z0)
		return
	# по лавке через 12 м, через одну к северу и к югу от улицы (боковые виды не заслоняют соседи)
	var placed := []
	for i in types.size():
		var ty: String = types[i]
		var at := Vector2(X0 - 22.0 + i * 5.6, Z0 + (-4.0 if i % 2 == 0 else 4.0))
		var t := put(ty, at, 0, color)
		if t.is_empty():
			continue
		info(t, "")
		placed.append(t)
	await frames(30)
	for t: Dictionary in placed:
		await _one(t)
	print("NSH DONE")
	get_tree().quit()


## Снимки одной лавки: спереди-сбоку, справа, сзади, слева, вход вблизи, сверху
func _one(t: Dictionary) -> void:
	var ty := String(t["type"])
	var tb := bounds(t)
	if people:
		_citizens(t)
	var ctr := Vector2((float(tb[0]) + float(tb[1])) * 0.5, (float(tb[2]) + float(tb[3])) * 0.5)
	var D: float = 12.0 if ty in ["taberna", "thermopolium", "fullonica"] else 9.5
	var views := [[28.0, 30.0, D, 0], [90.0, 26.0, D, 0], [200.0, 32.0, D, 0], [-90.0, 26.0, D, 0], [12.0, 16.0, D * 0.5, 1], [-25.0, 62.0, D * 1.2, 0]]
	await _shots(t, ctr, views, "%s_%s" % [ty, tagn])


func _shots(t: Dictionary, ctr: Vector2, views: Array, tg: String) -> void:
	var bp := c.blueprint(t)
	var f2 := City.facing(float(t["yaw"]))
	var fyd := rad_to_deg(atan2(f2.x, f2.y))
	var dp2 := c.door_point(t)
	for h: float in hours:
		game._set_hour(h)
		await frames(20)
		for i in views.size():
			if not vsel.is_empty() and not vsel.has(i):
				continue
			var v: Array = views[i]
			var tp := ctr
			var ty: float = game.land.height_at(ctr.x, ctr.y) + 1.3
			if int(v[3]) == 1:
				tp = dp2.lerp(ctr, 0.12 if String(t["type"]) == "taberna" else 0.45)
				ty = float(t["y"]) + 0.9
			game.rig.set_view(Vector3(tp.x, ty, tp.y), fyd + float(v[0]), float(v[1]), float(v[2]))
			await frames(3)
			if int(v[3]) == 1:
				game.life.door(t, 600.0)          # двери в кадре — Life распахивает их
				game.speed = 1.0
				await secs(0.6)
				game.speed = 0.0
			await secs(0.8)
			await frames(30)
			get_viewport().get_texture().get_image().save_png(out + "%s_v%d_h%s.png" % [tg, i, str(h).replace(".", "_")])
			print("NSH shot %s v%d h%s: вызовов %d, треугольников %d" % [tg, i, h, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])


## Улица: все 17 лавок в ряд к северу от улицы, вплотную через 0,6 м (как в городе), снимки по участкам и сверху
func _street(X0: float, Z0: float) -> void:
	var list := []
	var x := X0 - 22.0
	var cols := [3, 0, 7, 2, 5, 8, 1, 4, 6, 9, 3, 0, 7, 2, 5, 8, 1]
	for i in types.size():
		var ty: String = types[i]
		var o: Array = NewShops.RECT.get(ty, [-1.5, 1.5, 0, 0])
		var w := (float(o[1]) - float(o[0])) * 1.0
		var b := put(ty, Vector2(x + w * 0.5, Z0 - 4.0), 0, int(cols[i % cols.size()]), 40, 0.15)
		if not b.is_empty():
			info(b, "улица")
			list.append(b)
			var tb := bounds(b)
			x = float(tb[1]) + 0.6
		else:
			x += w + 0.6
	await frames(30)
	if list.is_empty():
		print("NSH DONE")
		get_tree().quit()
		return
	var f := City.facing(float(list[0]["yaw"]))
	var fyd := rad_to_deg(atan2(f.x, f.y))
	# участки по 4–5 лавок
	var segs := []
	var n := list.size()
	var per := 4
	var i0 := 0
	while i0 < n:
		segs.append(list.slice(i0, mini(n, i0 + per)))
		i0 += per
	for h: float in hours:
		game._set_hour(h)
		await frames(20)
		var k := 0
		for sg: Array in segs:
			var lo := Vector2(INF, INF)
			var hi := Vector2(-INF, -INF)
			for b: Dictionary in sg:
				var tb := bounds(b)
				lo = lo.min(Vector2(tb[0], tb[2]))
				hi = hi.max(Vector2(tb[1], tb[3]))
			var ctr := (lo + hi) * 0.5
			var span := (hi - lo).x
			for e: Array in [[0, 8.0, 36.0, 1.0], [1, -10.0, 58.0, 1.05]]:
				if not vsel.is_empty() and not vsel.has(int(e[0])):
					continue
				game.rig.set_view(Vector3(ctr.x, game.land.height_at(ctr.x, ctr.y) + 1.4, ctr.y), fyd + float(e[1]), float(e[2]), span * float(e[3]) + 3.0)
				await secs(0.8)
				await frames(30)
				get_viewport().get_texture().get_image().save_png(out + "street_%s_s%d_v%d_h%s.png" % [tagn, k, int(e[0]), str(h).replace(".", "_")])
			k += 1
		# вся улица сверху
		var lo2 := Vector2(INF, INF)
		var hi2 := Vector2(-INF, -INF)
		for b: Dictionary in list:
			var tb := bounds(b)
			lo2 = lo2.min(Vector2(tb[0], tb[2]))
			hi2 = hi2.max(Vector2(tb[1], tb[3]))
		var c2 := (lo2 + hi2) * 0.5
		game.rig.set_view(Vector3(c2.x, game.land.height_at(c2.x, c2.y) + 1.0, c2.y), fyd, 55.0, (hi2 - lo2).x * 0.62 + 4.0)
		await secs(0.8)
		await frames(30)
		get_viewport().get_texture().get_image().save_png(out + "street_%s_all_h%s.png" % [tagn, str(h).replace(".", "_")])
	print("NSH DONE")
	get_tree().quit()


## Разнообразие: по четыре лавки одного ремесла в ряд — разные цвета (у владельца variant у всех 0)
func _variety(X0: float, Z0: float) -> void:
	var rows := {}
	for t: String in types:
		rows[t] = [0, 4, 7, 2] if t in ["taberna", "thermopolium", "fullonica"] else [0, 4, 7, 2, 9]
	var placed := {}
	var zi := 0
	for t: String in rows:
		var o: Array = NewShops.RECT.get(t, [-1.5, 1.5, 0, 0])
		var step := float(o[1]) - float(o[0]) + 0.7
		var list := []
		var cols: Array = rows[t]
		for i in cols.size():
			var at := Vector2(X0 - 22.0 + (zi % 3) * 26.0 + i * step, Z0 + (-4.0 if floori(zi / 3.0) % 2 == 0 else 4.0) + floori(zi / 6.0) * 0.0)
			var b := put(t, at, 0, int(cols[i]), 40, 0.15)
			if b.is_empty():
				continue
			info(b, "разнообразие")
			list.append(b)
		placed[t] = list
		zi += 1
		if zi % 6 == 0:
			# новый ряд построек — новая улица севернее (снимаем по шесть ремёсел)
			await _variety_shots(placed)
			for tt: String in placed:
				for b: Dictionary in placed[tt]:
					c.remove(b, false)
			placed = {}
			await frames(10)
	if not placed.is_empty():
		await _variety_shots(placed)
	print("NSH DONE")
	get_tree().quit()


func _variety_shots(placed: Dictionary) -> void:
	await frames(30)
	for t: String in placed:
		var list: Array = placed[t]
		if list.is_empty():
			continue
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for b: Dictionary in list:
			var tb := bounds(b)
			lo = lo.min(Vector2(tb[0], tb[2]))
			hi = hi.max(Vector2(tb[1], tb[3]))
		var ctr := (lo + hi) * 0.5
		var span := (hi - lo).x
		var f := City.facing(float(list[0]["yaw"]))
		var fyd := rad_to_deg(atan2(f.x, f.y))
		for h: float in hours:
			game._set_hour(h)
			await frames(20)
			for e: Array in [[0, 10.0, 34.0, 1.0], [1, -20.0, 58.0, 1.0]]:
				if not vsel.is_empty() and not vsel.has(int(e[0])):
					continue
				game.rig.set_view(Vector3(ctr.x, game.land.height_at(ctr.x, ctr.y) + 1.2, ctr.y), fyd + float(e[1]), float(e[2]), span * float(e[3]) + 3.5)
				await secs(0.8)
				await frames(30)
				get_viewport().get_texture().get_image().save_png(out + "variety_%s_v%d_h%s.png" % [t, int(e[0]), str(h).replace(".", "_")])
