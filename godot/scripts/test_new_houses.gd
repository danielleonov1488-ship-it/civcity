extends Node
## Новые дома (NewHouses): снимки для владельца — облики каждого класса рядом (new=0 — прежние CatHouses), дом из
## старого сохранения (fit=1: без «kw» и «sz»), рост по этажам (grow=1), улица из 12 разных домов (variety=1).
##   bash .work/py/gpu_run.sh res://test_new_houses.tscn -- out=D:/CivCity/.work/rebuild/houses/<папка>/ [type=house_pleb]
##        [new=0] [fit=1] [tier=3] [hours=11,18.5] [views=0,1,4] [grow=1] [variety=1] [apron=0] [vars=0,2]
## Снимки: <out>/<тип>_v<облик>_<метка>_v<вид>_h<час>.png (метка — new, old или fit); grow — grow_v<вид>_h<час>.png;
## variety — variety_v<вид>_h<час>.png; empty=1 — каждый второй дом пустой (ночной свет только у жилых)

var game
var c: City
var out := "D:/CivCity/.work/rebuild/houses/t/"
var types := ["house_pleb", "house_artisan", "house_patrician"]
var hours := [11.0]
var fit := false
var grow := false
var variety := false
var tier := 3
var vsel := []
var vars_sel := []
var empty := false                   # каждый второй дом — пустой (ночью у него темно, как у прежних)
var nput := 0
var tagn := "new"
const VARS := {"house_pleb": [0, 1, 2, 3, 4], "house_artisan": [0, 1, 2, 3, 4], "house_patrician": [0, 1, 2, 3, 4, 5]}
const COLS := [3, 0, 2, 4, 7, 5, 8, 1, 9, 6]


func _ready() -> void:
	var newv := true
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"out": out = kv[1]
			"type": types = [kv[1]]
			"types": types = Array(kv[1].split(","))
			"new": newv = kv[1] != "0"
			"apron": NewHouses.APRON = kv[1] != "0"
			"hours":
				hours = []
				for h in kv[1].split(","):
					hours.append(float(h))
			"fit": fit = kv[1] != "0"
			"empty": empty = kv[1] != "0"
			"grow": grow = kv[1] != "0"
			"variety": variety = kv[1] != "0"
			"tier": tier = int(kv[1])
			"views":
				for v in kv[1].split(","):
					vsel.append(int(v))
			"vars":
				for v in kv[1].split(","):
					vars_sel.append(int(v))
	if not newv:
		for t: String in NewHouses.TYPES:
			NewHouses.ON[t] = false
		NewHouses.APRON = false
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


func put(t: String, at: Vector2, v: int, col: int, fl: int, tries := 60, stepr := 0.25) -> Dictionary:
	for k in tries:
		var p := at + Vector2(cos(k * 2.4), sin(k * 2.4)) * (k * stepr)
		var pl: Dictionary = game.placement(t, p, v, col)
		if pl["err"] == "":
			var b := c.place(t, pl["pos"], pl["yaw"], pl["variant"], pl["color"], true)
			b["tier"] = fl
			b["pop"] = 0 if empty and nput % 2 == 1 else 3
			nput += 1
			if fit:
				b.erase("kw")
				b.erase("sz")
			game._show(b)
			return b
	print("NH NOTE не встало ", t, " у ", at, ": ", (game.placement(t, at, v, col) as Dictionary).get("err", ""))
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
	print("NH BUILD %s v%d f%d %s %s id=%d color=%d foot=%.2f×%.2f z %.2f..%.2f top=%.2f door=%s parts=%d lights=%d doors=%d pairs=%d seats=%d water=%d apron=%d" % [
		t["type"], int(t["variant"]), int(t["tier"]), tagn, what, int(t["id"]), int(t["color"]), r.size.x, r.size.y, r.position.y, r.end.y,
		bp.top_y(), bp.door, bp.parts.size(), bp.lights.size(), (inf["doors"] as Array).size(), int(inf["pairs"]), (inf["seats"] as Array).size(),
		(inf["water"] as Array).size(), c.apron_of(t)])


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
	if game.people:
		game.people.visible = false
	var X0 := 150.0
	var Z0 := 124.0
	game.clear_nature(Vector2(X0, Z0), 75.0)
	DirAccess.make_dir_recursive_absolute(out)
	if variety:
		await _variety(X0, Z0)
		return
	if grow:
		await _grow(X0, Z0)
		return
	# каждый класс — вдоль своей улицы, облики через 8,5 м (боковые виды не заслоняют соседи)
	var rows := []
	for ti in types.size():
		var t: String = types[ti]
		var zr := Z0 - 24.0 + ti * 24.0
		game.land.paint_line(Vector2(X0 - 40.0, zr), Vector2(X0 + 45.0, zr), 2.2, Land.Kind.ROAD, true)
		rows.append([t, zr])
	await frames(4)
	var placed := []
	for e: Array in rows:
		var t: String = e[0]
		var vs: Array = VARS[t]
		for i in vs.size():
			var v: int = vs[i]
			if not vars_sel.is_empty() and not vars_sel.has(v):
				continue
			var b := put(t, Vector2(X0 - 32.0 + i * 13.0, float(e[1]) - 4.5), v, COLS[i], mini(tier, Defs.floors_max(String(Defs.B[t]["cls"]), v)))
			if b.is_empty():
				continue
			info(b, "")
			placed.append(b)
	await frames(30)
	for b: Dictionary in placed:
		# дом снимается один: соседи (дома прилипают друг к другу в ряд) на время прячутся — виды сбоку и сзади чистые
		for o: Dictionary in placed:
			if o != b:
				game._hide(o)
		await frames(5)
		await _one(b)
		for o: Dictionary in placed:
			if o != b:
				game._show(o)
	print("NH DONE")
	get_tree().quit()


func _one(t: Dictionary) -> void:
	var tb := bounds(t)
	var ctr := Vector2((float(tb[0]) + float(tb[1])) * 0.5, (float(tb[2]) + float(tb[3])) * 0.5)
	var D := 15.0 if String(t["type"]) == "house_patrician" else 13.5
	var Ds := 9.5 if String(t["type"]) == "house_patrician" else 9.0          # сбоку — ближе соседа (через 13 м)
	# [поворот от фасада, наклон, даль, цель: 0 — середина, 1 — вход]
	var views := [[28.0, 30.0, D, 0], [90.0, 26.0, Ds, 0], [200.0, 32.0, D, 0], [-90.0, 26.0, Ds, 0], [12.0, 16.0, D * 0.3, 1], [-25.0, 62.0, D * 1.25, 0]]
	await _shots(t, ctr, views, "%s_v%d_%s" % [t["type"], int(t["variant"]), tagn])


func _shots(t: Dictionary, ctr: Vector2, views: Array, tg: String) -> void:
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
			var ty: float = game.land.height_at(ctr.x, ctr.y) + 2.3
			if int(v[3]) == 1:
				tp = dp2 - f2 * 0.3
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
	print("NH shot %s" % tg)


## Рост по этажам: у каждого класса облик (и городской домус) — 1, 2, 3 этажа рядом
func _grow(X0: float, Z0: float) -> void:
	game.land.paint_line(Vector2(X0 - 30.0, Z0), Vector2(X0 + 30.0, Z0), 2.2, Land.Kind.ROAD, true)
	await frames(4)
	var list := [["house_pleb", 0], ["house_artisan", 1], ["house_patrician", 0], ["house_patrician", 4]]
	var placed := []
	var i := 0
	for e: Array in list:
		var t: String = e[0]
		var mx := Defs.floors_max(String(Defs.B[t]["cls"]), int(e[1]))
		for fl in range(1, mx + 1):
			var b := put(t, Vector2(X0 - 24.0 + i * 3.6, Z0 - 4.5), int(e[1]), COLS[i % COLS.size()], fl, 30, 0.15)
			if not b.is_empty():
				info(b, "рост")
				placed.append(b)
			i += 1
		i += 1
	await frames(30)
	await _row_shots(placed, "grow")
	print("NH DONE")
	get_tree().quit()


## Улица из 12 домов: классы, облики, цвета и этажи вперемешку (как в городе)
func _variety(X0: float, Z0: float) -> void:
	game.land.paint_line(Vector2(X0 - 30.0, Z0), Vector2(X0 + 30.0, Z0), 2.2, Land.Kind.ROAD, true)
	await frames(4)
	var list := [["house_pleb", 0, 3, 3], ["house_pleb", 3, 2, 0], ["house_artisan", 0, 3, 2], ["house_pleb", 1, 3, 4],
		["house_patrician", 0, 2, 9], ["house_pleb", 4, 3, 7], ["house_artisan", 2, 2, 1], ["house_pleb", 2, 1, 5],
		["house_artisan", 3, 3, 8], ["house_pleb", 0, 2, 6], ["house_patrician", 4, 3, 3], ["house_artisan", 4, 3, 0]]
	var placed := []
	var x := X0 - 18.0
	for e: Array in list:
		var b := put(String(e[0]), Vector2(x, Z0 - 4.5), int(e[1]), int(e[3]), int(e[2]), 40, 0.12)
		if not b.is_empty():
			info(b, "улица")
			placed.append(b)
			x = float(bounds(b)[1]) + 1.75
		else:
			x += 3.2
	await frames(30)
	await _row_shots(placed, "variety")
	print("NH DONE")
	get_tree().quit()


func _row_shots(list: Array, tg: String) -> void:
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
		for e: Array in [[0, 10.0, 30.0, 0.95], [1, 32.0, 24.0, 0.6], [2, -30.0, 50.0, 0.9], [3, 180.0, 36.0, 0.9]]:
			if not vsel.is_empty() and not vsel.has(int(e[0])):
				continue
			game.rig.set_view(Vector3(ctr.x, game.land.height_at(ctr.x, ctr.y) + 2.0, ctr.y), fyd + float(e[1]), float(e[2]), span * float(e[3]) + 4.0)
			await secs(0.8)
			await frames(30)
			get_viewport().get_texture().get_image().save_png(out + "%s_v%d_h%s.png" % [tg, int(e[0]), str(h).replace(".", "_")])
