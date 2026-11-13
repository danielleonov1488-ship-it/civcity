extends Node
## Храм Юпитера (NewTemple): снимки для владельца — «было/стало» (newtemple=0 — прежний храм), храм на прежних клетках
## старого сохранения (fit=1), храм рядом с домами плебеев и жителями (масштаб), утренняя служба (люди на ступенях),
## врата открыты; город владельца (city=…): храм из старого сохранения на своём месте и новый полный — на свободном.
##   bash .work/py/gpu_run.sh res://test_new_temple.tscn -- out=D:/CivCity/.work/rebuild/temple/<папка>/ [newtemple=0] [fit=1]
##        [hours=11,18.5] [houses=1] [people=1] [service=1] [views=0,1,4] [city=D:/CivCity/.work/owner_save/city.json]
##        [checks=1 — перенос храма старого сохранения: отмена возвращает его как был, новый спот — полный → «NT CHECKS fails=N»]
## Снимки: <out>/<метка>_v<вид>_h<час>.png, метка — new, fit или old. Склейка листов — .work/rebuild/temple/py.

var game
var c: City
var out := "D:/CivCity/.work/rebuild/temple/t/"
var hours := [11.0, 18.5]
var houses := false
var people := false
var service := false
var fit := false
var city_src := ""
var checks := false
var fails := 0
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
			"fit": fit = kv[1] != "0"
			"city": city_src = kv[1]
			"checks": checks = kv[1] != "0"
			"views":
				for v in kv[1].split(","):
					vsel.append(int(v))
	tagn = ("fit" if fit else "new") if NewTemple.ON else "old"
	if city_src != "":
		# копия города владельца — в папку сохранений этого запуска (gpu_run: своя на каждый запуск), не в настоящую
		var dst := GamePaths.save_dir().path_join("city.json")
		DirAccess.copy_absolute(city_src, dst)
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


func put(type: String, at: Vector2, v := -1, col := -1, tries := 60, stepr := 0.25) -> Dictionary:
	for k in tries:
		var p := at + Vector2(cos(k * 2.4), sin(k * 2.4)) * (k * stepr)
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


func info(t: Dictionary, what: String) -> void:
	var tb := bounds(t)
	var bp := c.blueprint(t)
	print("NT TEMPLE %s %s id=%d pos=%s yaw=%.2f sz=%s foot=%.2f×%.2f top=%.2f door=%s parts=%d lights=%d" % [tagn, what, int(t["id"]), t["pos"],
		float(t["yaw"]), str(t.get("sz", "—")), float(tb[1]) - float(tb[0]), float(tb[3]) - float(tb[2]), bp.top_y(), bp.door, bp.parts.size(), bp.lights.size()])


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
	if city_src != "":
		await _owner_city()
		return
	if checks:
		await _move_checks()
		return
	if game.people and not service:
		game.people.visible = false               # своих жителей ставим сами (масштаб), прохожие не мешают кадру (зрители службы — с ними)
	var X0 := 150.0
	var Z0 := 124.0
	game.clear_nature(Vector2(X0, Z0), 38.0)
	game.land.paint_line(Vector2(X0 - 30.0, Z0), Vector2(X0 + 30.0, Z0), 2.2, Land.Kind.ROAD, true)
	await frames(4)
	var t := put("temple", Vector2(X0, Z0 - 7.0))
	if t.is_empty():
		get_tree().quit()
		return
	if fit:
		t.erase("sz")                            # как из старого сохранения: облик — под прежние клетки (SizeLadder.old_lot)
		game._show(t)
	info(t, "")
	var tb := bounds(t)
	var bp := c.blueprint(t)
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
	# одна даль для «было» и «стало» — разница в размере видна сразу; вход — по глубине храма
	var kd := maxf(1.0, (float(tb[3]) - float(tb[2])) / 7.6)
	# [поворот от фасада, наклон, даль, цель: 0 — середина, 1 — врата]
	var views := [[28.0, 30.0, 21.0, 0], [90.0, 26.0, 20.0, 0], [200.0, 32.0, 21.0, 0], [-90.0, 26.0, 20.0, 0],
		[0.0, 10.0, 5.2 * kd, 1], [-35.0, 50.0, 28.0, 0], [30.0, 16.0, 6.0 * kd, 1]]
	if houses:
		views = [[8.0, 30.0, 30.0, 0], [35.0, 22.0, 19.0, 0], [-25.0, 40.0, 34.0, 0]]
	if service:
		views = [[18.0, 24.0, 17.0, 0], [-22.0, 38.0, 26.0, 0], [8.0, 12.0, 9.0, 1]]
	await _shots(t, bp, ctr, views)
	if service and game.spectacle:
		var V: Dictionary = game.spectacle.venues.get(int(t["id"]), {})
		if not V.is_empty():
			var seats: Array = V["lay"]["seats"]
			var on_steps := 0
			var lo := INF
			for s: Dictionary in seats:
				var y := (s["root"] as Vector3).y
				on_steps += 1 if y > 0.15 else 0
				lo = minf(lo, y)
			print("NT SERVICE мест %d (на ступенях %d), стоят %d, жрец %s %s" % [seats.size(), on_steps, (V["who"] as Array).size(),
				str((V["lay"] as Dictionary).has("priest")), str((V["lay"] as Dictionary).get("priest", {}).get("root", "—"))])
	print("NT DONE")
	get_tree().quit()


func _shots(t: Dictionary, bp: Bp, ctr: Vector2, views: Array, tag := "") -> void:
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
				# вход: врата распахнуты (Life), видно освещённую целлу
				var e: Array = (game.life.info(bp, "temple")["doors"] as Array)
				if not e.is_empty():
					var hm := Vector3.ZERO
					for le: Array in e:
						hm += le[1] as Vector3
					var hw: Vector3 = c.xf(t) * (hm / e.size())
					tp = dp2.lerp(Vector2(hw.x, hw.z), 0.8)
				ty = float(t["y"]) + 1.3
			game.rig.set_view(Vector3(tp.x, ty, tp.y), fyd + float(v[0]), float(v[1]), float(v[2]))
			await frames(3)
			if int(v[3]) == 1:
				game.life.door(t, 600.0)          # врата в кадре — Life распахивает их (вне кадра двери не шевелятся)
				game.speed = 1.0                  # створки движутся со скоростью игры
				await secs(0.6)
				game.speed = 0.0
			await secs(0.8)
			await frames(30)
			get_viewport().get_texture().get_image().save_png(out + "%s_v%d_h%s.png" % [tg, i, str(h).replace(".", "_")])
			print("NT shot %s v%d h%s: вызовов %d, треугольников %d" % [tg, i, h, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])


## Город владельца: храм из старого сохранения — на прежнем месте (сборка «старого места»), новый — полный, на свободном
func _owner_city() -> void:
	var t := {}
	for id in c.buildings:
		if c.buildings[id]["type"] == "temple":
			t = c.buildings[id]
	DirAccess.make_dir_recursive_absolute(out)
	if not t.is_empty():
		info(t, "владельца")
	# свободное место для нового храма: по спирали от площади храма — первое, куда игра даёт поставить
	var nt := {}
	var from := Vector2(172.4, 148.7) if t.is_empty() else (t["pos"] as Vector2)
	for k in 900:
		var p := from + Vector2(cos(k * 2.4), sin(k * 2.4)) * (6.0 + k * 0.12)
		var pl: Dictionary = game.placement("temple", p)
		if pl["err"] == "":
			nt = c.place("temple", pl["pos"], pl["yaw"], pl["variant"], pl["color"], true)
			game._show(nt)
			break
	if nt.is_empty():
		print("NT NOTE новый храм в городе владельца не встал")
		print("NT DONE")
		get_tree().quit()
		return
	info(nt, "новый в городе")
	await frames(40)
	for e: Array in [[t, "cityold"], [nt, "citynew"]]:
		var b: Dictionary = e[0]
		if b.is_empty():
			continue
		var tb := bounds(b)
		var ctr := Vector2((float(tb[0]) + float(tb[1])) * 0.5, (float(tb[2]) + float(tb[3])) * 0.5)
		await _shots(b, c.blueprint(b), ctr, [[28.0, 34.0, 24.0, 0], [-30.0, 48.0, 40.0, 0]], String(e[1]))
	print("NT DONE")
	get_tree().quit()


func check(ok: bool, what: String, got = null) -> bool:
	print(("NT PASS " if ok else "NT FAIL ") + what + ("" if got == null or ok else "  → " + str(got)))
	if not ok:
		fails += 1
	return ok


func _temple_rec() -> Dictionary:
	for id in c.buildings:
		if c.buildings[id]["type"] == "temple":
			return c.buildings[id]
	return {}


## Перенос храма из старого сохранения (на клетках «старого места», без ревизии линейки): отмена переноса возвращает его
## ровно как был — те же клетки, без «sz», облик «старого места», сосед вплотную не задет; перенос на новое свободное
## место — полный храм (ревизия линейки записана)
func _move_checks() -> void:
	var X0 := 150.0
	var Z0 := 124.0
	game.clear_nature(Vector2(X0 + 10.0, Z0), 45.0)
	game.land.paint_line(Vector2(X0 - 30.0, Z0), Vector2(X0 + 60.0, Z0), 2.2, Land.Kind.ROAD, true)
	await frames(4)
	var t := put("temple", Vector2(X0, Z0 - 7.0))
	if not check(not t.is_empty(), "храм встал"):
		_end_checks()
		return
	var pos: Vector2 = t["pos"]
	var yaw := float(t["yaw"])
	var v := int(t.get("variant", 0))
	var col := int(t.get("color", 0))
	# как из старого сохранения: на клетках прежнего следа, без ревизии линейки
	var fitbp := Catalog.make("temple", int(t["tier"]), v, col, false, true)
	var fcells := c.land.footprint_cells(fitbp.occ_footprint(), pos, yaw)
	c.remove(t, false)
	var o := c.place("temple", pos, yaw, v, col, true, fcells, 0)
	check(not o.has("sz") and SizeLadder.old_lot(o) and o["cells"] == fcells and c.blueprint(o) == fitbp,
		"храм «из старого сохранения»: без sz, на клетках прежнего следа (%d), облик старого места" % fcells.size())
	# сосед вплотную к прежнему следу — там, куда встал бы полный храм
	var ax := City.axis(yaw)
	var fw := City.facing(yaw)
	var hp := pos + ax * (3.1 + 1.55) + fw * (-1.0)
	var h := c.place("house_pleb", hp, yaw, 0, 1, true)
	var mine := {}
	for k in fcells:
		mine[k] = true
	var touch := 0
	for k in (h["cells"] as PackedInt32Array):
		touch += 1 if mine.has(k) else 0
	var full_cells := c.land.footprint_cells(Catalog.make("temple", int(t["tier"]), v, col).occ_footprint(), pos, yaw)
	var fullset := {}
	for k in full_cells:
		fullset[k] = true
	var inside := 0
	for k in (h["cells"] as PackedInt32Array):
		inside += 1 if fullset.has(k) else 0
	check(touch == 0 and inside > 0, "дом вплотную: на клетки храма не залез (%d), но стоит там, где был бы полный храм (%d клеток)" % [touch, inside])
	await frames(10)
	# поднять и отменить перенос
	check(game.start_move(o), "храм подняли (перенос)")
	await frames(5)
	game._cancel_move()
	await frames(5)
	var t2 := _temple_rec()
	check(not t2.is_empty() and not t2.has("sz") and SizeLadder.old_lot(t2), "отмена переноса: храм снова «из старого сохранения» (sz нет)", t2.get("sz", "—"))
	check(not t2.is_empty() and t2["cells"] == fcells and (t2["pos"] as Vector2).distance_to(pos) < 0.001, "те же клетки и то же место")
	check(not t2.is_empty() and c.blueprint(t2) == fitbp, "облик — старого места (не полный поверх соседа)")
	var hurt := 0
	for k in (h["cells"] as PackedInt32Array):
		hurt += 0 if c.land.occ[k] == int(h["id"]) else 1
	var own := 0
	for k in fcells:
		own += 1 if c.land.occ[k] == int(t2.get("id", -1)) else 0
	check(hurt == 0, "клетки соседа — по-прежнему его", hurt)
	check(own == fcells.size(), "клетки храма заняты храмом (%d из %d)" % [own, fcells.size()])
	# перенос на новое свободное место — полный храм
	check(game.start_move(t2), "храм подняли снова")
	await frames(5)
	var moved := false
	for k in 200:
		var p := Vector2(X0 + 32.0, Z0 - 7.0) + Vector2(cos(k * 2.4), sin(k * 2.4)) * (k * 0.2)
		var pl: Dictionary = game.placement("temple", p)
		if pl["err"] == "":
			game.hover = p
			game._build_here()
			moved = game.moving.is_empty()
			break
	if not moved and not game.moving.is_empty():
		game._cancel_move()
	var t3 := _temple_rec()
	check(moved and not t3.is_empty() and int(t3.get("sz", 0)) == SizeLadder.REV and c.blueprint(t3) == Catalog.make("temple", int(t3["tier"]), v, col),
		"перенос на новое место — полный храм (sz=%s)" % str(t3.get("sz", "—")))
	_end_checks()


func _end_checks() -> void:
	print("NT CHECKS fails=%d" % fails)
	print("NT DONE")
	get_tree().quit()
