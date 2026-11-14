extends Node
## Новые прилавки, уличные зрелища, огород, приют, кошачья лавка, травник, скульптор и лудус (NewShops2): снимки для
## владельца — «было/стало» (new=0 — прежняя сборка), постройка на прежних клетках старого сохранения (fit=1), разные
## облики и цвета рядом (variety=1: рынок из прилавков и зрелищ), двери открыты.
##   bash .work/py/gpu_run.sh res://test_new_shops2.tscn -- types=a,b out=D:/CivCity/.work/rebuild/shops2/<папка>/ [new=0] [fit=1]
##        [color=N] [hours=11,18.5] [views=0,1,4] [variety=1] [people=1]
## Снимки: <out>/<тип>_<метка>_v<вид>_h<час>.png, метка — new, fit или old; variety — variety_<ряд>_v<вид>_h<час>.png

var game
var c: City
var out := "D:/CivCity/.work/rebuild/shops2/t/"
var type := "stall_fruit"
var types := []
var hours := [11.0]
var houses := false
var fit := false
var variety := false
var lesson := false
var color := 3
var vsel := []
var tagn := "new"
var all_placed := []                    # постройки этого запуска: на снимках одной соседние спрятаны


func _ready() -> void:
	var newv := true
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"out": out = kv[1]
			"type": type = kv[1]
			"types": types = Array(kv[1].split(","))
			"new": newv = kv[1] != "0"
			"hours":
				hours = []
				for h in kv[1].split(","):
					hours.append(float(h))
			"houses": houses = kv[1] != "0"
			"fit": fit = kv[1] != "0"
			"variety": variety = kv[1] != "0"
			"lesson": lesson = kv[1] != "0"
			"color": color = int(kv[1])
			"views":
				for v in kv[1].split(","):
					vsel.append(int(v))
	if types.is_empty():
		types = [type]
	if not newv:
		for t: String in NewShops2.TYPES:
			NewShops2.ON[t] = false
	tagn = ("fit" if fit else "new") if newv else "old"
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
	print("NS NOTE не встало ", t, " у ", at, ": ", (game.placement(t, at) as Dictionary).get("err", ""))
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
	print("NS BUILD %s %s %s id=%d pos=%s yaw=%.2f color=%d sz=%s foot=%.2f×%.2f=%.1f top=%.2f door=%s parts=%d lights=%d actors=%d doors=%d shutter_pairs=%d apron=%d" % [
		t["type"], tagn, what, int(t["id"]), t["pos"], float(t["yaw"]), int(t["color"]), str(t.get("sz", "—")), r.size.x, r.size.y, r.get_area(),
		bp.top_y(), bp.door, bp.parts.size(), bp.lights.size(), bp.actors.size(), (inf["doors"] as Array).size(), int(inf["pairs"]), c.apron_of(t)])


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
	game.hud.visible = false
	game.speed = 0.0
	if game.weather:
		game.weather.left_h = 0.0
		game.weather.force = 0.0
	if game.people and not lesson:
		game.people.visible = false
	var X0 := 150.0
	var Z0 := 124.0
	game.clear_nature(Vector2(X0 + 6.0, Z0), 60.0)
	game.land.paint_line(Vector2(X0 - 50.0, Z0), Vector2(X0 + 58.0, Z0), 2.2, Land.Kind.ROAD, true)
	await frames(4)
	DirAccess.make_dir_recursive_absolute(out)
	if variety:
		await _variety(X0, Z0)
		return
	# постройки в ряд вдоль улицы, по очереди к северу и к югу (через 20 м по одной стороне: боковые виды без соседей)
	var placed := []
	for i in types.size():
		var ty: String = types[i]
		var north := i % 2 == 0
		var dz := 3.0 if ty != "ludus" else 4.5
		var at := Vector2(X0 - 28.0 + i * 6.9, Z0 - dz if north else Z0 + dz)
		var t := put(ty, at, 0, color)
		if t.is_empty():
			continue
		if fit:
			t.erase("sz")                        # как из старого сохранения: облик — под прежние клетки (SizeLadder.old_lot)
			game._show(t)
		info(t, "")
		placed.append(t)
	all_placed = placed
	for t: Dictionary in placed:
		await _one(t)
	print("NS DONE")
	get_tree().quit()


## Снимки одного здания: «было/стало», вход, сверху; рядом с домами (houses), урок в школе (lesson)
func _one(t: Dictionary) -> void:
	var ty := String(t["type"])
	for o: Dictionary in all_placed:
		if int(o["id"]) != int(t["id"]):
			game._hide(o)
	var Z0 := 124.0
	var tb := bounds(t)
	var hb_list := []
	if houses:
		var hx := [float(tb[0]) - 1.9, float(tb[1]) + 1.9]
		for i in hx.size():
			var hb := put("house_pleb", Vector2(hx[i], Z0 - 3.0), i % 4, (i * 3 + 2) % 6, 30, 0.2)
			if not hb.is_empty():
				hb["pop"] = 3
				game._show(hb)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var dp := c.door_point(t)
		var f := City.facing(float(t["yaw"]))
		var ax := City.axis(float(t["yaw"]))
		for e: Array in [[-1.6, 1.0, false, false], [-0.6, 1.5, true, false], [0.9, 1.2, false, true], [2.0, 1.6, false, false]]:
			_citizen(rng, dp + ax * float(e[0]) + f * float(e[1]), atan2(-f.x, -f.y) + rng.randf_range(-0.6, 0.6), e[2], e[3])
	if lesson and ty == "school" and game.spectacle:
		game.spectacle.force(int(t["id"]), "show", 1.0, true)
	await frames(30)
	var ctr := Vector2((float(tb[0]) + float(tb[1])) * 0.5, (float(tb[2]) + float(tb[3])) * 0.5)
	var D: float = {"ludus": 15.0, "sculptor": 11.0, "shelter": 11.0, "mimes": 10.0, "ogorod": 10.0, "catshop": 10.0, "herbalist": 9.5}.get(ty, 8.0)
	# [поворот от фасада, наклон, даль, цель: 0 — середина, 1 — вход]
	var views := [[28.0, 30.0, D, 0], [90.0, 26.0, D, 0], [200.0, 32.0, D, 0], [-90.0, 26.0, D, 0], [10.0, 18.0, D * 0.55, 1], [-25.0, 62.0, D * 1.25, 0]]
	if ty.begins_with("stall_") or ty in ["musicians", "dice", "puppets", "mimes"]:
		views[4] = [8.0, 22.0, D * 0.55, 0]          # без двери: вблизи — середина
	if houses:
		views = [[10.0, 32.0, D * 1.7, 0], [35.0, 24.0, D * 1.1, 0]]
	if lesson:
		views = [[15.0, 34.0, D * 0.85, 0], [-30.0, 48.0, D, 0]]
	await _shots(t, ctr, views, "%s_%s" % [ty, tagn] + ("_scale" if houses else ("_lesson" if lesson else "")))
	for o: Dictionary in all_placed:
		if int(o["id"]) != int(t["id"]):
			game._show(o)


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
			var ty: float = game.land.height_at(ctr.x, ctr.y) + 1.4
			if int(v[3]) == 1:
				# вход: двери распахнуты (Life), видно освещённое нутро
				var e: Array = (game.life.info(bp, String(t["type"]))["doors"] as Array)
				var aim := ctr
				if not e.is_empty():
					var hm := Vector3.ZERO
					for le: Array in e:
						hm += le[1] as Vector3
					var hw: Vector3 = c.xf(t) * (hm / e.size())
					aim = Vector2(hw.x, hw.z)
				tp = dp2.lerp(aim, 0.7)
				ty = float(t["y"]) + 1.0
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
			print("NS shot %s v%d h%s: вызовов %d, треугольников %d" % [tg, i, h, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])


## Рынок: прилавки вплотную в ряд разных цветов и обликов (А/Б), напротив — зрелища и ещё прилавки (как в городе владельца)
func _variety(X0: float, Z0: float) -> void:
	var rows := {"north": [["stall_fruit", 0], ["stall_veg", 1], ["stall_fish", 2], ["stall_fruit", 3], ["stall_veg", 4], ["stall_fish", 5], ["stall_fruit", 8]],
		"south": [["musicians", 2], ["stall_fish", 9], ["dice", 3], ["stall_veg", 7], ["puppets", 4], ["stall_fruit", 6], ["mimes", 1]]}
	var step := {"north": 2.35, "south": 3.0}
	var zoff := {"north": -2.6, "south": 2.8}
	var placed := {}
	for row: String in rows:
		var list := []
		var items: Array = rows[row]
		var xx := X0 - 8.0
		for i in items.size():
			var e: Array = items[i]
			var t: String = e[0]
			var w := 4.2 if t == "mimes" else (3.2 if t == "puppets" else float(step[row]))
			var at := Vector2(xx + w * 0.5, Z0 + float(zoff[row]))
			xx += w
			var b := put(t, at, 0, int(e[1]), 40, 0.15)
			if b.is_empty():
				continue
			info(b, "рынок")
			list.append(b)
		placed[row] = list
	await frames(30)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for row: String in placed:
		for b: Dictionary in placed[row]:
			var tb := bounds(b)
			lo = lo.min(Vector2(tb[0], tb[2]))
			hi = hi.max(Vector2(tb[1], tb[3]))
	var ctr := (lo + hi) * 0.5
	var span := (hi - lo).x
	for h: float in hours:
		game._set_hour(h)
		await frames(20)
		for e: Array in [[0, 0.0, 36.0, 0.75], [1, -35.0, 50.0, 0.9], [2, 180.0, 36.0, 0.75], [3, 20.0, 24.0, 0.42]]:
			game.rig.set_view(Vector3(ctr.x, game.land.height_at(ctr.x, ctr.y) + 0.8, ctr.y), float(e[1]), float(e[2]), span * float(e[3]) + 3.0)
			await secs(0.8)
			await frames(30)
			get_viewport().get_texture().get_image().save_png(out + "variety_market_v%d_h%s.png" % [int(e[0]), str(h).replace(".", "_")])
	print("NS DONE")
	get_tree().quit()
