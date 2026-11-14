extends Node
## Новые здания Легиона (NewMilitary): снимки для владельца.
##   bash .work/py/gpu_run.sh res://test_new_military.tscn -- out=D:/CivCity/.work/rebuild/legion/<папка>/ [types=barracks,forge]
##        [new=0] [tier=N] [hours=11,18.5] [views=0,1,4]          — по зданию: 4 стороны, вход вблизи, сверху
##        [tiers=0,2,5]                                            — лист роста: три копии рядом на этих уровнях облика
##        [camp=0|5|mix]                                           — военный квартал: все 13 у двух улиц
## Снимки: <out>/<тип>_<метка>_v<вид>_h<час>.png (метка new_t<N> / old_t<N>), tiers_<тип>_v<вид>.png, camp_<облик>_v<вид>_h<час>.png

var game
var c: City
var out := "D:/CivCity/.work/rebuild/legion/t/"
var types := []
var hours := [11.0]
var vsel := []
var tier := 0
var newv := true
var tiers := []
var camp := ""
var fit := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"out": out = kv[1]
			"types": types = Array(kv[1].split(","))
			"new": newv = kv[1] != "0"
			"tier": tier = int(kv[1])
			"camp": camp = kv[1]
			"fit": fit = kv[1] != "0"
			"tiers":
				for s in kv[1].split(","):
					tiers.append(int(s))
			"hours":
				hours = []
				for h in kv[1].split(","):
					hours.append(float(h))
			"views":
				for v in kv[1].split(","):
					vsel.append(int(v))
	if types.is_empty():
		types = NewMilitary.TYPES.duplicate()
	if not newv:
		for t: String in NewMilitary.TYPES:
			NewMilitary.ON[t] = false
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


## Поставить здание type фасадом к улице (улица вдоль X на z = zr; north — по эту сторону, фасадом к +Z)
func put(t: String, x: float, zr: float, north: bool, tr := -1) -> Dictionary:
	var lot: Array = NewMilitary.LOT[t] if NewMilitary.LOT.has(t) else [-3.0, 3.0, -3.5, 2.5]
	var off := float(lot[3]) + 1.25
	var xm := (float(lot[0]) + float(lot[1])) * 0.5
	var pos := Vector2(x - xm, zr - off) if north else Vector2(x + xm, zr + off)
	var chk: Dictionary = c.check_place(t, pos, 0.0 if north else PI, 0, 0, -2)
	var b: Dictionary = c.place(t, pos, 0.0 if north else PI, 0, -1, true)
	if b.is_empty():
		print("NM NOTE не встало ", t)
		return {}
	if String(chk["err"]) != "":
		# место не по правилам (склон, клетки) — высота не посчитана: ставим по земле и выравниваем, как place
		print("NM NOTE место %s: %s — выравниваю" % [t, chk["err"]])
		b["y"] = roundf(game.land.height_at(pos.x, pos.y) / Land.STEP) * Land.STEP
		game.land.flatten_cells(b["cells"], b["y"])
	if tr >= 0:
		b["tier"] = tr
	game._show(b)
	return b


## Сухо ли под участком здания t (без воды в запасе 2,5 м), если поставить его фасадом к улице zr у x
func dry(t: String, x: float, zr: float, north: bool) -> bool:
	var lot: Array = NewMilitary.LOT[t] if NewMilitary.LOT.has(t) else [-3.0, 3.0, -3.5, 2.5]
	var w := float(lot[1]) - float(lot[0])
	var d := float(lot[3]) - float(lot[2])
	var z0 := zr - 1.25 - d if north else zr + 1.25
	var m := 2.5
	var xx := x - w * 0.5 - m
	while xx <= x + w * 0.5 + m:
		var zz := z0 - m
		while zz <= z0 + d + m:
			if game.land.is_water(Vector2(xx, zz)):
				return false
			zz += 0.5
		xx += 0.5
	return true


## Ближайшее к x сухое место вдоль улицы (вправо от x, не дальше 40 м)
func dry_x(t: String, x: float, zr: float, north: bool) -> float:
	for k in 81:
		if dry(t, x + k * 0.5, zr, north):
			return x + k * 0.5
	return x


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
	print("NM BUILD %s %s tier=%d id=%d pos=%s foot=%.2f×%.2f=%.1f top=%.2f door=%s parts=%d lights=%d actors=%d doors=%d apron=%d" % [
		t["type"], what, int(t["tier"]), int(t["id"]), t["pos"], r.size.x, r.size.y, r.get_area(), bp.top_y(), bp.door, bp.parts.size(), bp.lights.size(),
		bp.actors.size(), (inf["doors"] as Array).size(), c.apron_of(t)])


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
	c.legion.progress = 50                     # все здания Легиона открыты (место считается без «Откроется победой…»)
	game.hud.visible = false
	game.speed = 0.0
	if game.weather:
		game.weather.left_h = 0.0
		game.weather.force = 0.0
	if game.people:
		game.people.visible = false
	# место: к югу от стартового посёлка (Land.CENTER — 185, 99): чужие постройки и деревья — прочь
	var X0 := 150.0
	var Z0 := 124.0
	for id in c.buildings.keys():
		var o: Dictionary = c.buildings[id]
		var q: Vector2 = o["pos"]
		if q.x > X0 - 95.0 and q.x < X0 + 115.0 and q.y > Z0 - 20.0 and q.y < Z0 + 110.0 and not bool(Defs.B[o["type"]].get("fixed", false)):
			c.remove(o, false)
	for cz: float in [Z0 + 12.0, Z0 + 70.0]:
		game.clear_nature(Vector2(X0 - 45.0, cz), 55.0)
		game.clear_nature(Vector2(X0 + 45.0, cz), 55.0)
		game.clear_nature(Vector2(X0 + 85.0, cz), 40.0)
	DirAccess.make_dir_recursive_absolute(out)
	if camp != "":
		await _camp(X0, Z0)
	elif not tiers.is_empty():
		await _tiers(X0, Z0)
	else:
		await _singles(X0, Z0)
	print("NM DONE")
	get_tree().quit()


## По зданию: по семь в ряд вдоль двух улиц через 24 м (боковые виды не заслоняют соседи)
func _singles(X0: float, Z0: float) -> void:
	for k in 2:
		game.land.paint_line(Vector2(X0 - 40.0, Z0 + k * 36.0), Vector2(X0 + 110.0, Z0 + k * 36.0), 2.2, Land.Kind.ROAD, true)
	await frames(4)
	var placed := []
	var xs := [X0 - 30.0, X0 - 30.0]
	for i in types.size():
		var row := i / 7
		var zr := Z0 + row * 36.0
		var x := dry_x(String(types[i]), float(xs[row]), zr, true)        # мимо прудов
		xs[row] = x + 22.0
		var t := put(String(types[i]), x, zr, true, tier)
		if fit and not t.is_empty():
			t.erase("sz")                        # как из старого сохранения: SizeLadder.old_lot (облик — тот же: след прежний)
			game._show(t)
		if not t.is_empty():
			info(t, "new" if newv else "old")
			placed.append(t)
	await frames(30)
	for t: Dictionary in placed:
		var tb := bounds(t)
		var ctr := Vector2((float(tb[0]) + float(tb[1])) * 0.5, (float(tb[2]) + float(tb[3])) * 0.5)
		var D := 14.0
		# [поворот от фасада, наклон, даль, цель: 0 — середина, 1 — вход]
		var views := [[28.0, 30.0, D, 0], [90.0, 26.0, D, 0], [200.0, 32.0, D, 0], [-90.0, 26.0, D, 0], [10.0, 18.0, D * 0.55, 1], [-25.0, 62.0, D * 1.25, 0]]
		await _shots(t, ctr, views, "%s_%s_t%d" % [t["type"], ("fit" if fit else "new") if newv else "old", tier])


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
				var e: Array = (game.life.info(bp, String(t["type"]))["doors"] as Array)
				var aim := ctr
				if not e.is_empty():
					var hm := Vector3.ZERO
					for le: Array in e:
						hm += le[1] as Vector3
					var hw: Vector3 = c.xf(t) * (hm / e.size())
					aim = Vector2(hw.x, hw.z)
				tp = dp2.lerp(aim, 0.75)
				ty = float(t["y"]) + 1.0
			game.rig.set_view(Vector3(tp.x, ty, tp.y), fyd + float(v[0]), float(v[1]), float(v[2]))
			await frames(3)
			if int(v[3]) == 1:
				game.life.door(t, 600.0)
				game.speed = 1.0
				await secs(0.6)
				game.speed = 0.0
			await secs(0.8)
			await frames(30)
			get_viewport().get_texture().get_image().save_png(out + "%s_v%d_h%s.png" % [tg, i, str(h).replace(".", "_")])
			print("NM shot %s v%d h%s: вызовов %d, треугольников %d" % [tg, i, h, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])


## Лист роста: у каждого типа три копии рядом (уровни облика tiers), два вида; по четыре типа на сторону улицы
func _tiers(X0: float, Z0: float) -> void:
	# три улицы, группы только по северной стороне (ряды не смотрят друг на друга), каждая — на сухом месте
	var rows := [Z0, Z0 + 36.0, Z0 + 72.0]
	for z: float in rows:
		game.land.paint_line(Vector2(X0 - 40.0, z), Vector2(X0 + 115.0, z), 2.2, Land.Kind.ROAD, true)
	await frames(4)
	var groups := []
	var ptr := [X0 - 30.0, X0 - 30.0, X0 - 30.0]
	for i in types.size():
		var t := String(types[i])
		var list := []
		var row := i % 3
		var zr: float = rows[row]
		var bx: float = ptr[row]
		for k in 80:
			if dry(t, bx, zr, true) and dry(t, bx + 8.2, zr, true) and dry(t, bx + 16.4, zr, true):
				break
			bx += 0.5
		ptr[row] = bx + 16.4 + 11.0
		for k in tiers.size():
			var b := put(t, bx + k * 8.2, zr, true, int(tiers[k]))
			if not b.is_empty():
				info(b, "лист роста")
				list.append(b)
		groups.append(list)
	await frames(40)
	for list: Array in groups:
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
		for h: float in hours:
			game._set_hour(h)
			await frames(20)
			var f2 := City.facing(float(list[0]["yaw"]))
			var fyd := rad_to_deg(atan2(f2.x, f2.y))
			for e: Array in [[0, 10.0, 30.0, 0.95], [1, -24.0, 55.0, 1.0]]:
				game.rig.set_view(Vector3(ctr.x, game.land.height_at(ctr.x, ctr.y) + 1.2, ctr.y), fyd + float(e[1]), float(e[2]), span * float(e[3]) + 3.0)
				await secs(0.8)
				await frames(30)
				get_viewport().get_texture().get_image().save_png(out + "tiers_%s_v%d_h%s.png" % [list[0]["type"], int(e[0]), str(h).replace(".", "_")])
				print("NM tiers %s v%d: вызовов %d" % [list[0]["type"], int(e[0]), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])


## Военный квартал: все 13 вплотную вдоль двух улиц (по обе стороны первой и второй), облик camp (0, 5 или mix)
func _camp(X0: float, Z0: float) -> void:
	# весь квартал — на сухом месте: сдвиг вдоль улиц, пока под всеми участками нет воды
	for k in 40:
		var ok := true
		for e: Array in [["principia", X0 - 12.0, Z0, true], ["mars", X0 + 12.0, Z0, true], ["range", X0 - 8.0, Z0, false], ["forge", X0 + 8.0, Z0, false],
				["infirmary", X0 - 8.0, Z0 + 18.0, true], ["catapults", X0 + 8.0, Z0 + 18.0, true], ["smelter", X0 - 8.0, Z0 + 18.0, false], ["tannery", X0 + 8.0, Z0 + 18.0, false]]:
			if not dry(String(e[0]), float(e[1]), float(e[2]), bool(e[3])):
				ok = false
				break
		if ok:
			break
		X0 += 2.0
	print("NM camp X0=%.1f" % X0)
	var zr := [Z0, Z0 + 18.0]
	for z: float in zr:
		game.land.paint_line(Vector2(X0 - 22.0, z), Vector2(X0 + 22.0, z), 2.2, Land.Kind.ROAD, true)
	game.land.paint_line(Vector2(X0 + 20.5, zr[0]), Vector2(X0 + 20.5, zr[1]), 2.2, Land.Kind.ROAD, true)
	await frames(4)
	var order := ["principia", "barracks", "armory", "mars", "range", "spearcamp", "forge", "infirmary", "ballistae", "catapults", "smelter", "sawmill", "tannery"]
	var mix := [5, 4, 4, 3, 3, 3, 2, 2, 1, 1, 2, 1, 0]
	var slots := [[X0 - 12.0, 0, true], [X0 - 4.0, 0, true], [X0 + 4.0, 0, true], [X0 + 12.0, 0, true],
		[X0 - 8.0, 0, false], [X0, 0, false], [X0 + 8.0, 0, false],
		[X0 - 8.0, 1, true], [X0, 1, true], [X0 + 8.0, 1, true],
		[X0 - 8.0, 1, false], [X0, 1, false], [X0 + 8.0, 1, false]]
	var placed := []
	for i in order.size():
		var s: Array = slots[i]
		var tr := 0
		if camp == "5":
			tr = 5
		elif camp == "mix":
			tr = int(mix[i])
		var b := put(String(order[i]), float(s[0]), float(zr[int(s[1])]), bool(s[2]), tr)
		if not b.is_empty():
			info(b, "квартал")
			placed.append(b)
	await frames(60)
	var ctr := Vector2(X0, (float(zr[0]) + float(zr[1])) * 0.5)
	for h: float in hours:
		game._set_hour(h)
		await frames(30)
		for e: Array in [[0, 0.0, 44.0, 44.0, Vector2.ZERO], [1, -30.0, 62.0, 52.0, Vector2.ZERO], [2, 18.0, 34.0, 26.0, Vector2(-5.0, -9.0)], [3, -18.0, 34.0, 26.0, Vector2(4.0, 9.0)]]:
			var p: Vector2 = ctr + (e[4] as Vector2)
			game.rig.set_view(Vector3(p.x, game.land.height_at(p.x, p.y) + 1.0, p.y), float(e[1]), float(e[2]), float(e[3]))
			await secs(0.9)
			await frames(30)
			get_viewport().get_texture().get_image().save_png(out + "camp_%s_v%d_h%s.png" % [camp, int(e[0]), str(h).replace(".", "_")])
			print("NM camp %s v%d h%s: вызовов %d, треугольников %d" % [camp, int(e[0]), h, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
