extends Node
## Новые пост вигилов, школа, малые бани, склад и скрипторий (NewSmall): снимки для владельца — «было/стало» (new=0 —
## прежняя сборка), здание на прежних клетках старого сохранения (fit=1), рядом с домами плебеев (houses=1, масштаб),
## разные фасады и цвета рядом (variety=1: по четыре школы и скриптория), двери открыты.
##   bash .work/py/gpu_run.sh res://test_new_small.tscn -- type=school out=D:/CivCity/.work/rebuild/b4/<папка>/ [new=0] [fit=1]
##        [color=N] [hours=11,18.5] [views=0,1,4] [houses=1] [variety=1] [lesson=1]
## Снимки: <out>/<тип>_<метка>_v<вид>_h<час>.png, метка — new, fit или old; variety — variety_<тип>_v<вид>_h<час>.png

var game
var c: City
var out := "D:/CivCity/.work/rebuild/b4/t/"
var type := "school"
var types := []
var hours := [11.0]
var houses := false
var fit := false
var variety := false
var lesson := false
var color := 3
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
		for t: String in types:
			NewSmall.ON[t] = false
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
	game.clear_nature(Vector2(X0 + 6.0, Z0), 52.0)
	game.land.paint_line(Vector2(X0 - 40.0, Z0), Vector2(X0 + 52.0, Z0), 2.2, Land.Kind.ROAD, true)
	await frames(4)
	DirAccess.make_dir_recursive_absolute(out)
	if variety:
		await _variety(X0, Z0)
		return
	# здания в ряд вдоль улицы (каждое — со своими видами)
	# средние — к северу от улицы через 30 м, малые — к югу между ними (боковые виды не заслоняют соседи)
	var placed := []
	var north := [Vector2(X0 - 30.0, Z0 - 5.0), Vector2(X0, Z0 - 5.0), Vector2(X0 + 30.0, Z0 - 5.0)]
	var south := [Vector2(X0 + 15.0, Z0 + 4.0), Vector2(X0 + 45.0, Z0 + 4.0), Vector2(X0 - 15.0, Z0 + 4.0), Vector2(X0 - 45.0, Z0 + 4.0)]
	for ty: String in types:
		var small := ty in ["vigiles", "scriptorium"]
		var at: Vector2 = Vector2(X0, Z0 - 5.0) if types.size() == 1 else (south.pop_front() if small else north.pop_front())
		var t := put(ty, at, 0, color)
		if t.is_empty():
			continue
		if fit:
			t.erase("sz")                        # как из старого сохранения: облик — под прежние клетки (SizeLadder.old_lot)
			game._show(t)
		info(t, "")
		placed.append(t)
	for t: Dictionary in placed:
		await _one(t)
	print("NS DONE")
	get_tree().quit()


## Снимки одного здания: «было/стало», вход, сверху; рядом с домами (houses), урок в школе (lesson)
func _one(t: Dictionary) -> void:
	var ty := String(t["type"])
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
	var D: float = {"vigiles": 11.5, "scriptorium": 11.0, "school": 15.0, "balnea": 15.0, "warehouse": 15.0}.get(ty, 14.0)
	# [поворот от фасада, наклон, даль, цель: 0 — середина, 1 — вход]
	var views := [[28.0, 30.0, D, 0], [90.0, 26.0, D, 0], [200.0, 32.0, D, 0], [-90.0, 26.0, D, 0], [10.0, 18.0, D * 0.55, 1], [-25.0, 62.0, D * 1.25, 0]]
	if ty == "school":
		views[4] = [6.0, 30.0, 8.5, 1]               # вход школы — под перголой: смотреть повыше
	if houses:
		views = [[10.0, 32.0, D * 1.7, 0], [35.0, 24.0, D * 1.1, 0]]
	if lesson:
		views = [[15.0, 34.0, D * 0.85, 0], [-30.0, 48.0, D, 0]]
	await _shots(t, ctr, views, "%s_%s" % [ty, tagn] + ("_scale" if houses else ("_lesson" if lesson else "")))


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


## Разнообразие: по четыре школы и скриптория в ряд — разные цвета (как в городе владельца) и фасады А/Б
func _variety(X0: float, Z0: float) -> void:
	var rows := {"school": [8, 0, 6, 1], "scriptorium": [4, 5, 8, 2]}
	var step := {"school": 7.4, "scriptorium": 4.6}
	var zoff := {"school": -5.0, "scriptorium": 4.0}      # скриптории — по другую сторону улицы, фасадом к ней
	var placed := {}
	for t: String in rows:
		var list := []
		var cols: Array = rows[t]
		for i in cols.size():
			var at := Vector2(X0 + (i - 1.5) * float(step[t]), Z0 + float(zoff[t]))
			var b := put(t, at, 0, int(cols[i]), 40, 0.2)
			if b.is_empty():
				continue
			info(b, "разнообразие")
			list.append(b)
		placed[t] = list
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
			for e: Array in [[0, 12.0, 34.0, 1.05], [1, -28.0, 52.0, 1.0]]:
				game.rig.set_view(Vector3(ctr.x, game.land.height_at(ctr.x, ctr.y) + 1.0, ctr.y), fyd + float(e[1]), float(e[2]), span * float(e[3]) + 4.0)
				await secs(0.8)
				await frames(30)
				get_viewport().get_texture().get_image().save_png(out + "variety_%s_v%d_h%s.png" % [t, int(e[0]), str(h).replace(".", "_")])
	print("NS DONE")
	get_tree().quit()
