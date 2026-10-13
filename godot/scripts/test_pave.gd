extends Node
## Стройка на площади и у улиц: на мостовой шире 9 м дом встаёт прямо на плитку, на улице — как раньше у её
## края (фасадом к ней, не боком). Плюс сетка ходьбы, отмена мазка, большая дорога, повороты, перенос.
## Запуск: bash .work/py/gpu_run.sh res://test_pave.tscn            — всё (печатает PAVE PASS|FAIL …, в конце PAVE DONE fails=N)
##         bash .work/py/gpu_run.sh res://test_pave.tscn -- menu_hash=promo | menu_hash=demo — отпечаток готового города меню
## Снимки — в D:/CivCity/.work/gd/pave*.png

var game
var mask := 0
var fails := 0
var args := {}
var plaza := false                    # в игре уже есть стройка на площади (до исправления — только улицы и отпечаток)

const S1 := Vector2(176, 140)         # площадь 12×12 м
const S2 := Vector2(230, 232)         # площадь 30×30 м
const STREETS := [[156.0, 1.0], [166.0, 2.0], [180.0, 4.0]]     # улицы вдоль x: [z, радиус кисти] — 2, 4 и 8 м


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("menu_hash"):
		Game.boot = {str(args["menu_hash"]): "1", "noui": "1", "hour": "9"}
	else:
		Game.boot = {"new": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func ok(name: String, cond: bool, info := "") -> bool:
	if not cond:
		fails += 1
	print("PAVE ", "PASS " if cond else "FAIL ", name, (" " + info) if info != "" else "")
	return cond


# ---------- мышь (как в test_input) ----------

func move(p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	e.button_mask = mask
	Input.parse_input_event(e)


func btn(p: Vector2, idx: int, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = p
	e.global_position = p
	e.button_index = idx
	e.pressed = pressed
	if pressed:
		mask |= 1 << (idx - 1)
	else:
		mask &= ~(1 << (idx - 1))
	e.button_mask = mask
	Input.parse_input_event(e)


func click(p: Vector2, idx := MOUSE_BUTTON_LEFT) -> void:
	move(p)
	await frames(3)
	btn(p, idx, true)
	await frames(2)
	btn(p, idx, false)
	await frames(3)


func scr(w: Vector2) -> Vector2:
	var cam: Camera3D = get_viewport().get_camera_3d()
	return get_viewport().get_final_transform() * cam.unproject_position(Vector3(w.x, game.land.height_at(w.x, w.y), w.y))


func center_of(c: Control) -> Vector2:
	return c.get_viewport().get_final_transform() * (c.get_global_transform_with_canvas() * (c.size / 2.0))


func shot(name: String) -> void:
	DirAccess.make_dir_recursive_absolute("D:/CivCity/.work/gd")
	get_viewport().get_texture().get_image().save_png("D:/CivCity/.work/gd/" + name)
	print("SHOT ", name)


# ---------- помощники ----------

## Сбросить всё, что placement() помнит между вызовами
func reset() -> void:
	game.last_snap_n = Vector2.ZERO
	game.last_snap_p = Vector2.INF
	if plaza:
		game.last_pave_p = Vector2.INF
		game.last_pave_n = Vector2.ZERO
		game.last_pave_sub = ""
	game.manual_yaw = false
	game.place_lock = {}
	game.tool_yaw = 0.0
	game.snap = true


func probe(type: String, p: Vector2) -> Dictionary:
	reset()
	return game.placement(type, p)


func bounds(type: String, pl: Dictionary) -> Array:
	return game._row_bounds(Catalog.make(type, int(pl["tier"]), int(pl["variant"]), int(pl["color"])))


func all_paved(cells: PackedInt32Array) -> bool:
	if cells.is_empty():
		return false
	for k in cells:
		if not Land.walk_kind(game.land.kind[k]):
			return false
	return true


func centre(type: String, pl: Dictionary) -> Vector2:
	var bb := bounds(type, pl)
	var y := float(pl["yaw"])
	return (pl["pos"] as Vector2) + City.axis(y) * ((float(bb[0]) + float(bb[1])) * 0.5) + City.facing(y) * ((float(bb[2]) + float(bb[3])) * 0.5)


func yaw_is(a: float, b: float, tol := 0.01) -> bool:
	return absf(angle_difference(a, b)) <= tol


## Ровная площадка под испытания (без склонов и деревьев)
func flat_zone(c: Vector2, w: float, h: float) -> void:
	var cells: PackedInt32Array = game.land.footprint_cells([Rect2(-w / 2, -h / 2, w, h)], c, 0.0)
	game.land.flatten_cells(cells, snappedf(game.land.height_at(c.x, c.y), Land.STEP))
	game.clear_nature(c, maxf(w, h) * 0.75)


func new_ids(before: Dictionary) -> Array:
	var out := []
	for id in game.city.buildings:
		if not before.has(id):
			out.append(id)
	return out


# ---------- ход испытаний ----------

func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(30)
	if args.has("menu_hash"):
		_menu_hash()
		get_tree().quit()
		return
	plaza = "last_pave_p" in game
	print("PAVE plaza code: ", plaza)
	game.can_save = false
	game.city.money = 50000.0
	game.city.tips["intro"] = true
	game.city.research["fountain"] = true
	game.hud.advisor_panel.visible = false
	game.rig.set_view(Vector3(180, 2, 150), 15, 58, 60)
	_paint()
	await frames(40)
	_t2_streets()
	if plaza:
		_t1_detect()
		_t3_rim()
		_t3b_edges()
		await _t4_mouse()
		_t5_s2()
		_t6_big_road()
		_t7_slope()
		await _t8_rotate()
		await _t9_move()
		_t10_walk()
		_t11_undo()
		_t12_perf()
		game.rig.set_view(Vector3(200, 2, 175), 15, 55, 75)
		await frames(40)
		shot("pave4_overview.png")
		game.rig.set_view(Vector3(S2.x, 2, S2.y), 15, 55, 48)
		await frames(40)
		shot("pave5_s2.png")
	print("PAVE DONE fails=", fails)
	get_tree().quit()


## Отпечаток готового города меню (витрина или старый городок): тип, место, поворот каждой постройки
func _menu_hash() -> void:
	var ids: Array = game.city.buildings.keys()
	ids.sort()
	var s := ""
	for id in ids:
		var b: Dictionary = game.city.buildings[id]
		var p: Vector2 = (b["pos"] as Vector2).snapped(Vector2(0.01, 0.01))
		s += "%s:%.2f,%.2f:%.3f;" % [b["type"], p.x, p.y, snappedf(float(b["yaw"]), 0.001)]
	print("PAVE MENUHASH mode=", args["menu_hash"], " n=", ids.size(), " h=", s.sha256_text())


func _paint() -> void:
	var L: Land = game.land
	flat_zone(Vector2(183, 160), 46, 62)
	flat_zone(S2, 40, 40)
	flat_zone(Vector2(96, 236), 44, 40)
	L.paint_circle(S1, 6.0, Land.Kind.ROAD, true, true, true)
	for st: Array in STREETS:
		L.paint_line(Vector2(164, st[0]), Vector2(190, st[0]), st[1], Land.Kind.ROAD, true)
	L.paint_line(Vector2(196, 150), Vector2(196, 172), 2.0, Land.Kind.ROAD, true)
	L.paint_circle(S2, 15.0, Land.Kind.PLAZA, true, true, true)
	L.paint_line(Vector2(84, 212), Vector2(108, 236), 2.0, Land.Kind.ROAD, true)
	L.paint_line(Vector2(84, 236), Vector2(108, 212), 2.0, Land.Kind.ROAD, true)
	L.paint_line(Vector2(84, 248.5), Vector2(108, 248.5), 4.0, Land.Kind.ROAD, true)
	L.paint_line(Vector2(84, 250.5), Vector2(108, 250.5), 4.0, Land.Kind.ROAD, true)


## T2: улицы 2, 4 и 8 м — дом у края, фасадом к улице, не на мостовой (как после 2a53222), отпечаток прежний
func _t2_streets() -> void:
	var s := ""
	var bad := 0
	var n := 0
	for st: Array in STREETS:
		var z0: float = st[0]
		var r: float = st[1]
		var offs := [0.0, 0.5, -0.5, 0.9, -0.9]
		if r >= 2.0:
			offs.append_array([1.8, -1.8])
		if r >= 4.0:
			offs.append_array([2.0, -2.0, 3.5, -3.5])
		offs.append_array([r + 1.0, -(r + 1.0)])        # курсор на траве у улицы
		for x in range(168, 188, 2):
			for dz: float in offs:
				var p := Vector2(x, z0 + dz)
				var pl := probe("house_pleb", p)
				n += 1
				var pos: Vector2 = pl["pos"]
				var y := float(pl["yaw"])
				s += "%.2f,%.2f:%.3f:%s;" % [pos.x, pos.y, snappedf(y, 0.001), pl["err"]]
				var f := City.facing(y)
				var bb := bounds("house_pleb", pl)
				var front := pos.y + f.y * float(bb[3])
				var edge := z0 - r if pos.y < z0 else z0 + r
				var deep := false
				for k in (pl["cells"] as PackedInt32Array):
					if Land.walk_kind(game.land.kind[k]) and (game.land.cell_center(k % Land.N, k / Land.N) - pos).dot(f) < float(bb[3]) - 0.45:
						deep = true
				var good: bool = str(pl.get("mode", "")) != "plaza" and pl["err"] == "" and not game.land.is_road(pos) \
					and absf(f.x) < 0.02 and signf(f.y) == signf(z0 - pos.y) and absf(front - edge) <= 0.3 and not deep
				if not good:
					bad += 1
					if bad <= 6 or args.has("verbose"):
						print("PAVE   street miss p=", p, " pos=", pos, " yaw=", snappedf(rad_to_deg(y), 0.1), " err=", pl["err"], " mode=", pl.get("mode", ""), " front=", snappedf(front, 0.01), " edge=", edge)
	ok("T2 streets: houses at the roadside, facing the street", bad == 0, "%d/%d" % [n - bad, n])
	print("PAVE HASH street ", s.sha256_text())


## T1: что считается площадью
func _t1_detect() -> void:
	var inside := 0
	var tot := 0
	for dx in range(-5, 6):
		for dz in range(-5, 6):
			tot += 1
			if game._plaza_at(S1 + Vector2(dx, dz), 19):
				inside += 1
	ok("T1 square 12x12 is a plaza everywhere inside", inside == tot, "%d/%d" % [inside, tot])
	var corners := 0
	for c: Vector2 in [Vector2(-5.5, -5.5), Vector2(5.5, -5.5), Vector2(-5.5, 5.5), Vector2(5.5, 5.5)]:
		if game._plaza_at(S1 + c, 19):
			corners += 1
	ok("T1 square corners are plaza too", corners == 4, str(corners))
	var street_hits := 0
	for st: Array in STREETS:
		for x in range(166, 190, 2):
			for dz: float in [0.0, 0.5, -0.5, 0.9, -0.9, 1.8, -1.8, 3.5, -3.5]:
				var p := Vector2(x, float(st[0]) + dz)
				if Land.walk_kind(game.land.kind_at(p.x, p.y)) and game._plaza_at(p, 19):
					street_hits += 1
	for p: Vector2 in [Vector2(196, 156), Vector2(196, 166), Vector2(196, 180), Vector2(96, 224), Vector2(90, 218), Vector2(102, 230), Vector2(90, 230), Vector2(102, 218)]:
		if Land.walk_kind(game.land.kind_at(p.x, p.y)) and game._plaza_at(p, 19):
			street_hits += 1
			print("PAVE   plaza at ", p)
	ok("T1 streets, junctions and the diagonal cross are never a plaza", street_hits == 0, str(street_hits))
	ok("T1 two 8 m strokes side by side (10 m) make a plaza", game._plaza_at(Vector2(96, 249.5), 19))


## T3: у края пустой площади дом встаёт на мостовую спиной к краю
func _t3_rim() -> void:
	for c: Array in [[Vector2(176, 135.5), 0.0, "z", 134.02], [Vector2(181, 140), -PI / 2, "x", 181.98], [Vector2(171, 140), PI / 2, "x", 170.02]]:
		var pl := probe("house_pleb", c[0])
		var y := float(pl["yaw"])
		var bb := bounds("house_pleb", pl)
		var back: Vector2 = (pl["pos"] as Vector2) + City.facing(y) * float(bb[2])
		var bv: float = back.y if c[2] == "z" else back.x
		ok("T3 rim %s" % str(c[0]), pl.get("mode", "") == "plaza" and pl.get("sub", "") == "rim" and yaw_is(y, c[1], 0.02) \
			and absf(bv - float(c[3])) <= 0.08 and pl["err"] == "" and all_paved(pl["cells"]),
			"sub=%s yaw=%.1f back=%.2f err=%s" % [pl.get("sub", ""), rad_to_deg(y), bv, pl["err"]])


## T3b: у каждого из четырёх краёв площади на любой глубине — ровно спиной к краю (раньше у края +z косило на 5–20°)
func _t3b_edges() -> void:
	var bad := 0
	var n := 0
	# [точка у края, направление внутрь, ожидаемый поворот]
	for e: Array in [[Vector2(176, 134), Vector2(0, 1), 0.0], [Vector2(176, 146), Vector2(0, -1), PI], [Vector2(170, 140), Vector2(1, 0), PI / 2], [Vector2(182, 140), Vector2(-1, 0), -PI / 2]]:
		for i in 23:
			var depth := 0.4 + 0.2 * i
			for side: float in [-1.5, 0.0, 1.5]:
				var inward: Vector2 = e[1]
				var p: Vector2 = (e[0] as Vector2) + inward * depth + Vector2(inward.y, -inward.x) * side
				var dists := [p.y - 134.0, 146.0 - p.y, p.x - 170.0, 182.0 - p.x]
				var mine := depth
				var others := 99.0
				for dd: float in dists:
					if absf(dd - mine) > 0.01:
						others = minf(others, dd)
				if others < mine + 0.8:            # 0,5 м — равные края + шаг лучей 0,25 м
					continue                      # у угла: другой край почти так же близко — тогда решает камера
				var pl := probe("house_pleb", p)
				n += 1
				if pl.get("mode", "") != "plaza" or not yaw_is(float(pl["yaw"]), e[2], deg_to_rad(0.6)):
					bad += 1
					if bad <= 5:
						print("PAVE   edge miss p=", p, " sub=", pl.get("sub", ""), " yaw=", snappedf(rad_to_deg(float(pl["yaw"])), 0.1), " want=", rad_to_deg(e[2]))
	ok("T3b every edge, every depth: back square to the edge", bad == 0, "%d/%d" % [n - bad, n])


## T4: мышью на площади 12×12 — дом посередине, второй в ряд, лавка в тот же ряд; рядом на траве — как раньше
func _t4_mouse() -> void:
	game.rig.set_view(Vector3(176, 2, 141), 15, 58, 36)
	await frames(20)
	await click(center_of(game.hud.cats["housing"]))
	await frames(5)
	var card: Control = null
	for c in game.hud.tray_grid.get_children():
		if c.get_meta("type", "") == "house_pleb":
			card = c
	if not ok("T4 house card found", card != null):
		return
	await click(center_of(card))
	reset()
	move(scr(S1))
	await frames(10)
	var pl: Dictionary = game.place_info
	ok("T4 ghost in the middle of the square", pl.get("mode", "") == "plaza" and pl.get("err", "?") == "" and yaw_is(float(pl["yaw"]), 0.0, 0.02)
		and centre("house_pleb", pl).distance_to(S1) <= 0.06, "sub=%s yaw=%.1f err=%s c=%s" % [pl.get("sub", ""), rad_to_deg(float(pl.get("yaw", 0))), pl.get("err", "?"), centre("house_pleb", pl)])
	shot("pave1_ghost.png")
	var before: Dictionary = game.city.buildings.duplicate()
	await click(scr(S1))
	var ids := new_ids(before)
	if not ok("T4 house A built on the square", ids.size() == 1):
		return
	var A: Dictionary = game.city.buildings[ids[0]]
	ok("T4 house A stands on paving", all_paved(A["cells"]))
	ok("T4 advisor explains the plaza once", game.hud.advisor_panel.visible and game.hud.adv_title.text == "Стройка на площади" and game.city.tips.has("plaza"))
	game.hud.advisor_panel.visible = false
	before = game.city.buildings.duplicate()
	await click(scr(S1 + Vector2(3.4, 0)))
	ids = new_ids(before)
	if ok("T4 house B built", ids.size() == 1):
		var B: Dictionary = game.city.buildings[ids[0]]
		var bbA: Array = game._row_bounds(game.city.blueprint(A))
		var bbB: Array = game._row_bounds(game.city.blueprint(B))
		var rel: Vector2 = (B["pos"] as Vector2) - (A["pos"] as Vector2)
		var fa := City.facing(float(A["yaw"]))
		var gap := rel.dot(City.axis(float(A["yaw"]))) + float(bbB[0]) - float(bbA[1])
		ok("T4 house B joins the row (same yaw and facade, gap 0.6)", yaw_is(float(B["yaw"]), float(A["yaw"]), 0.02)
			and absf(rel.dot(fa) + float(bbB[3]) - float(bbA[3])) <= 0.05 and absf(gap - Game.ROW_GAP) <= 0.06, "gap=%.2f" % gap)
	game.set_tool("stall_fruit")
	reset()
	move(scr(S1 - Vector2(3.4, 0)))
	await frames(8)
	var sp: Dictionary = game.place_info
	var pr0 := probe("stall_fruit", S1 - Vector2(3.4, 0))
	print("PAVE   shop probe sub=", pr0.get("sub", ""), " err=", pr0["err"], " pos=", pr0["pos"], " bb=", bounds("stall_fruit", pr0), " hover=", game.hover)
	print("PAVE   shop ghost tool=", game.tool, " mode=", sp.get("mode", ""), " sub=", sp.get("sub", ""), " err=", sp.get("err", "?"), " pos=", sp.get("pos", Vector2.ZERO), " yaw=", rad_to_deg(float(sp.get("yaw", 0.0))))
	before = game.city.buildings.duplicate()
	await click(scr(S1 - Vector2(3.4, 0)))
	ids = new_ids(before)
	if ok("T4 shop built on the square", ids.size() == 1, "money=%d" % int(game.city.money)):
		var C: Dictionary = game.city.buildings[ids[0]]
		var bbA2: Array = game._row_bounds(game.city.blueprint(A))
		var bbC: Array = game._row_bounds(game.city.blueprint(C))
		var relc: Vector2 = (C["pos"] as Vector2) - (A["pos"] as Vector2)
		var gapc := float(bbA2[0]) - (relc.dot(City.axis(float(A["yaw"]))) + float(bbC[1]))
		ok("T4 shop in the same row", yaw_is(float(C["yaw"]), float(A["yaw"]), 0.02) and all_paved(C["cells"])
			and absf(relc.dot(City.facing(float(A["yaw"]))) + float(bbC[3]) - float(bbA2[3])) <= 0.05 and absf(gapc - Game.ROW_GAP) <= 0.06, "gap=%.2f" % gapc)
	await frames(100)
	shot("pave2_row.png")
	var g := probe("house_pleb", Vector2(176, 147))
	var fg := City.facing(float(g["yaw"]))
	var bbg := bounds("house_pleb", g)
	ok("T4 cursor on the grass beside the square: house outside, facing it", g.get("mode", "") != "plaza" and g["err"] == "" and fg.y < -0.98
		and absf((g["pos"] as Vector2).y + fg.y * float(bbg[3]) - 146.0) <= 0.15, "pos=%s yaw=%.1f" % [g["pos"], rad_to_deg(float(g["yaw"]))])
	game.set_tool("house_pleb")


## T5: большая площадь 30×30 — по камере, у края, напротив соседа, проверки входа
func _t5_s2() -> void:
	var d := probe("house_pleb", S2)
	ok("T5 empty plaza: faces the camera", d.get("sub", "") == "default" and yaw_is(float(d["yaw"]), 0.0, 0.02) and d["err"] == "", "sub=%s yaw=%.1f" % [d.get("sub", ""), rad_to_deg(float(d["yaw"]))])
	game.rig.yaw = deg_to_rad(100.0)
	d = probe("house_pleb", S2)
	ok("T5 camera turned: faces it again", yaw_is(float(d["yaw"]), PI / 2, 0.02), "yaw=%.1f" % rad_to_deg(float(d["yaw"])))
	game.rig.yaw = deg_to_rad(15.0)
	var e := probe("house_pleb", S2 + Vector2(0, -10))
	ok("T5 near the edge: back to the edge", e.get("sub", "") in ["edge", "rim"] and yaw_is(float(e["yaw"]), 0.0, 0.02) and e["err"] == "", "sub=%s yaw=%.1f" % [e.get("sub", ""), rad_to_deg(float(e["yaw"]))])
	var H: Dictionary = game.city.place("house_pleb", centre_pos("house_pleb", S2, 0.0), 0.0)
	var f1 := probe("house_pleb", S2 + Vector2(0, 6))
	ok("T5 in front of a house: faces it", f1.get("sub", "") == "align" and yaw_is(float(f1["yaw"]), PI, 0.02) and f1["err"] == "", "sub=%s yaw=%.1f err=%s" % [f1.get("sub", ""), rad_to_deg(float(f1["yaw"])), f1["err"]])
	var f2 := probe("house_pleb", S2 + Vector2(0, -6))
	ok("T5 behind a house: back to back", yaw_is(float(f2["yaw"]), PI, 0.02), "yaw=%.1f" % rad_to_deg(float(f2["yaw"])))
	reset()
	game.manual_yaw = true
	game.tool_yaw = PI
	var k1: Dictionary = game.placement("house_pleb", S2 + Vector2(0, 4.0))
	ok("T5 door against a wall is refused", str(k1["err"]).begins_with("Перед входом нужно свободное место"), str(k1["err"]))
	var dp: Vector2 = game.city.door_point(H)
	reset()
	game.manual_yaw = true
	game.tool_yaw = PI / 2
	var k2: Dictionary = game.placement("house_pleb", dp + Vector2(0, 1.4))
	ok("T5 covering a neighbour's door is refused", k2["err"] == "Так загородится вход соседней постройки", str(k2["err"]))
	var g := probe("fountain", S2 + Vector2(8, 8))
	ok("T5 fountain stays on the plaza", g.get("mode", "") == "plaza" and g["err"] == "" and centre("fountain", g).distance_to(S2 + Vector2(8, 8)) <= 0.1, "err=%s" % g["err"])
	reset()
	game.snap = false
	game.tool_yaw = 0.3
	var so: Dictionary = game.placement("house_pleb", S2 + Vector2(-6, -6))
	ok("T5 snap off on a plaza: free at the cursor", so.get("sub", "") == "manual" and yaw_is(float(so["yaw"]), 0.3, 0.001) and so["err"] == "", "sub=%s err=%s" % [so.get("sub", ""), so["err"]])
	reset()
	game.snap = false
	var ss: Dictionary = game.placement("house_pleb", Vector2(178, 166))
	ok("T5 snap off on a street: still refused", ss["err"] == game.STREET_MSG, str(ss["err"]))
	game.city.remove(H, false)
	reset()


func centre_pos(type: String, c: Vector2, yaw: float) -> Vector2:
	var bb: Array = game._row_bounds(Catalog.make(type, 1 if Defs.B[type]["kind"] == "house" else 0, 0, 0))
	return c - City.axis(yaw) * ((float(bb[0]) + float(bb[1])) * 0.5) - City.facing(yaw) * ((float(bb[2]) + float(bb[3])) * 0.5)


## T6: на большую дорогу от арки к станции не строят (по ней едет повозка с новыми семьями)
func _t6_big_road() -> void:
	game.land.paint_circle(Vector2(186, 116), 6.0, Land.Kind.ROAD, true, true, true)
	var p := Vector2(191.5, 116)
	ok("T6 the widened big road is a plaza", game._plaza_at(p, 19))
	var r := probe("house_pleb", p)
	ok("T6 no houses on the big road", r["err"] == "По большой дороге ездят повозки — здесь не строят", str(r["err"]))
	var bad := 0
	for x: float in [184.0, 186.0, 188.0, 190.0, 191.5, 193.0]:
		var q := probe("house_pleb", Vector2(x, 116))
		if q["err"] == "":
			for k in (q["cells"] as PackedInt32Array):
				if Land.walk_kind(game.land.base_kind[k]):
					bad += 1
	ok("T6 nothing allowed touches the big road", bad == 0, str(bad))


## T7: на крутой мостовой — отказ с понятной причиной
func _t7_slope() -> void:
	var L: Land = game.land
	var c := Vector2(214, 182)
	var cells: PackedInt32Array = L.footprint_cells([Rect2(-6, -6, 12, 12)], c, 0.0)
	var y0 := L.height_at(c.x, c.y)
	for k in cells:
		var cc := L.cell_center(k % Land.N, k / Land.N)
		L.h[k] = y0 + 0.3 * (cc.x - (c.x - 6.0))
		L._mark(k % Land.N, k / Land.N)
	L.paint_circle(c, 6.0, Land.Kind.ROAD, false, true, true)
	var r := probe("house_pleb", c)
	var chk: Dictionary = game.city.check_place("house_pleb", r["pos"], r["yaw"])
	ok("T7 sloped paving refused", r["err"] == "Мостовая здесь слишком наклонная — найдите место ровнее", "err=%s check=%s" % [r["err"], chk["err"]])


## T8: поворот на площади — зажать и вести вбок; отпустить — не строит; щелчок — строит повёрнутым
func _t8_rotate() -> void:
	game.rig.set_view(Vector3(S2.x, 2, S2.y), 15, 58, 40)
	await frames(20)
	game.set_tool("house_pleb")
	reset()
	var n0: int = game.city.buildings.size()
	var a := scr(Vector2(236, 226))
	move(a)
	await frames(5)
	btn(a, MOUSE_BUTTON_LEFT, true)
	var mid_ok := false
	for k in 20:
		move(a + Vector2(k * 6.0, 0))
		await frames(1)
		if k == 10:
			var pl: Dictionary = game.place_info
			mid_ok = pl.get("mode", "") == "plaza" and pl.get("err", "?") == "" and str(game.place_lock.get("mode", "")) == "plaza"
	print("PAVE   T8 before release: pressing=", game.pressing, " rot_drag=", game.rot_drag, " lock=", game.place_lock, " info=", game.place_info.get("mode", ""), "/", game.place_info.get("sub", ""), " err=", game.place_info.get("err", ""), " ui=", game.hud.mouse_over_ui(), " n=", game.city.buildings.size() - n0)
	btn(a + Vector2(114, 0), MOUSE_BUTTON_LEFT, false)
	await frames(5)
	print("PAVE   T8 after release: manual=", game.manual_yaw, " lock=", game.place_lock, " n=", game.city.buildings.size() - n0, " tool=", game.tool)
	ok("T8 rotating on the plaza keeps it on the plaza", mid_ok)
	ok("T8 release after rotating does not build", game.city.buildings.size() == n0 and game.place_lock.is_empty() and game.manual_yaw)
	var ty: float = game.tool_yaw
	var b := scr(Vector2(222, 240))
	move(b)
	await frames(8)
	var pl2: Dictionary = game.place_info
	ok("T8 rotated ghost follows the mouse on the plaza", pl2.get("mode", "") == "plaza" and pl2.get("sub", "") == "manual" and yaw_is(float(pl2["yaw"]), ty, 0.002) and pl2["err"] == "",
		"sub=%s err=%s" % [pl2.get("sub", ""), pl2.get("err", "")])
	var before: Dictionary = game.city.buildings.duplicate()
	await click(b)
	var ids := new_ids(before)
	ok("T8 click builds it rotated, on paving", ids.size() == 1 and yaw_is(float(game.city.buildings[ids[0]]["yaw"]), ty, 0.002) and all_paved(game.city.buildings[ids[0]]["cells"]))
	# короткое движение (меньше 4°) — это щелчок: строит там, где была тень до нажатия
	reset()
	game.rig.set_view(Vector3(238, 2, 234), 15, 58, 40)
	await frames(90)                      # камера доезжает плавно — ждём, пока встанет
	var c := scr(Vector2(238, 234))
	for tr in 5:
		move(c)
		await frames(8)
		if game.hover.distance_to(Vector2(238, 234)) < 0.3:
			break
	var pre: Dictionary = game.place_info.duplicate()
	var hc = get_viewport().gui_get_hovered_control()
	if hc:
		var txt := ""
		for l in hc.find_children("*", "Label", true, false):
			txt += (l as Label).text.substr(0, 40) + " | "
		print("PAVE   T8 panel rect=", hc.get_global_rect(), " visible=", hc.is_visible_in_tree(), " parent=", hc.get_parent().name, " text=", txt)
	print("PAVE   T8 tiny: c=", c, " mouse=", get_viewport().get_mouse_position(), " hover=", game.hover, " ui=", game.hud.mouse_over_ui(), " hovered=", hc.name if hc else "-", " ", hc.get_path() if hc else "")
	before = game.city.buildings.duplicate()
	btn(c, MOUSE_BUTTON_LEFT, true)
	await frames(2)
	# 18 точек экрана игры (окно может быть крупнее — пересчёт): поворот начался (порог 14), но меньше 4° — это щелчок
	var px := 18.0 * get_viewport().get_final_transform().get_scale().x
	for k in 6:
		move(c + Vector2(px * minf(k + 1, 4) / 4.0, 0))
		await frames(2)
	var rot_started: bool = game.rot_drag
	btn(c + Vector2(px, 0), MOUSE_BUTTON_LEFT, false)
	await frames(5)
	ids = new_ids(before)
	print("PAVE   T8 tiny: pre sub=", pre.get("sub", ""), " err=", pre.get("err", ""), " pos=", pre.get("pos", Vector2.ZERO), " now err=", game.place_info.get("err", ""), " lock=", game.place_lock, " yaw0=", rad_to_deg(game.rot_yaw0), " yaw=", rad_to_deg(game.tool_yaw))
	var bpos: Vector2 = game.city.buildings[ids[0]]["pos"] if ids.size() == 1 else Vector2.INF
	ok("T8 tiny drag counts as a click", rot_started and ids.size() == 1 and bpos.distance_to(pre["pos"]) <= 0.05, "new=%d built=%s yaw=%.1f pre=%s" % [ids.size(), bpos, rad_to_deg(float(game.city.buildings[ids[0]]["yaw"])) if ids.size() == 1 else 0.0, pre["pos"]])


## T9: перенос дома на площадь — на мостовую, со старым поворотом; отмена — на место
func _t9_move() -> void:
	var src: Dictionary = {}
	for id in game.city.buildings:
		var b: Dictionary = game.city.buildings[id]
		if b["type"] == "house_pleb" and (b["pos"] as Vector2).distance_to(S1) < 8.0:
			src = b
	if not ok("T9 a house to move", not src.is_empty()):
		return
	var y0 := float(src["yaw"])
	var n0: int = game.city.buildings.size()
	game.start_move(src)
	reset()
	game.tool_yaw = y0
	var to := Vector2(222, 224)
	var pl: Dictionary = game.placement("house_pleb", to)
	ok("T9 moving onto the plaza keeps the old yaw", pl.get("mode", "") == "plaza" and pl["err"] == "" and yaw_is(float(pl["yaw"]), y0, 0.02), "sub=%s err=%s" % [pl.get("sub", ""), pl["err"]])
	game.hover = to
	game._build_here()
	await frames(5)
	var moved := false
	for id in game.city.buildings:
		var b: Dictionary = game.city.buildings[id]
		if b["type"] == "house_pleb" and (b["pos"] as Vector2).distance_to(pl["pos"]) < 0.05:
			moved = true
	ok("T9 moved, count unchanged", moved and game.city.buildings.size() == n0)


## T10: сетка ходьбы сразу под новым домом и после сноса; идущий мимо обходит
func _t10_walk() -> void:
	var P = game.people
	var c := S2 + Vector2(-8, 8)
	var H: Dictionary = game.city.place("house_pleb", centre_pos("house_pleb", c, 0.0), 0.0)
	ok("T10 walk grid solid under a new plaza house at once", P.grid.is_point_solid(P.gcell(c)))
	game.city.remove(H, false)
	ok("T10 and free again after demolition", not P.grid.is_point_solid(P.gcell(c)))
	var fam: Array = P._make_family("Проверка", 1, -1, Vector2(218, 236))
	var r: Dictionary = fam[0]
	P._go(r, Vector2(242, 236), "plaza")
	if not ok("T10 walker on the way", r["state"] == "walk"):
		return
	var H2: Dictionary = game.city.place("house_pleb", centre_pos("house_pleb", Vector2(230, 236), 0.0), 0.0)
	ok("T10 walker goes around the new house", r["state"] == "walk" and not P._path_hits(r["p"], r["path"], int(r["i"]), int(H2["id"])))
	game.city.remove(H2, false)


## T11: отмена мазка не трогает землю под домом и возвращает деньги только за откаченное
func _t11_undo() -> void:
	var L: Land = game.land
	var c := Vector2(198, 140)
	flat_zone(c, 14, 14)
	var ch: Array = L.paint_circle(c, 6.0, Land.Kind.ROAD, true, true, true)
	var cost := 0.0
	for e in ch:
		if int(e[1]) != Land.Kind.ROAD:
			cost += float(Defs.ROAD_COST["road"])
	game.city.money -= cost
	game.undo_stack.append({"ch": ch, "cost": cost})
	game.redo_stack.clear()
	var H: Dictionary = game.city.place("house_pleb", centre_pos("house_pleb", c, 0.0), 0.0)
	var m0: float = game.city.money
	game._undo()
	var kept := true
	for k in (H["cells"] as PackedInt32Array):
		if not Land.walk_kind(L.kind[k]) or absf(L.hq(k) - float(H["y"])) > 0.01:
			kept = false
	var corner := L.idx(L.cell(c + Vector2(5, 5)).x, L.cell(c + Vector2(5, 5)).y)
	ok("T11 undo keeps paving and height under the house", kept)
	ok("T11 undo reverts the rest", not Land.walk_kind(L.kind[corner]))
	ok("T11 refund only for what was reverted", game.city.money - m0 > 0.0 and game.city.money - m0 < cost, "refund=%.1f of %.1f" % [game.city.money - m0, cost])
	game._redo()
	ok("T11 redo charges it back", absf(game.city.money - m0) <= 0.05 and Land.walk_kind(L.kind[corner]), "money diff=%.2f" % (game.city.money - m0))
	game.city.remove(H, false)
	# мазок по склону записывает клетку дважды — отмена в обратном порядке возвращает траву
	var c2 := Vector2(214, 160)
	var before := 0
	var zone: PackedInt32Array = L.footprint_cells([Rect2(-5, -5, 10, 10)], c2, 0.0)
	for k in zone:
		L.h[k] = L.h[k] + 0.06 * (L.cell_center(k % Land.N, k / Land.N).x - c2.x)
		L._mark(k % Land.N, k / Land.N)
	for k in zone:
		if Land.walk_kind(L.kind[k]):
			before += 1
	var ch2: Array = L.paint_line(c2 - Vector2(4, 0), c2 + Vector2(4, 0), 1.5, Land.Kind.ROAD, true)
	game.undo_stack.append({"ch": ch2, "cost": 0.0})
	game._undo()
	var after := 0
	for k in zone:
		if Land.walk_kind(L.kind[k]):
			after += 1
	ok("T11 undo of a stroke on a slope leaves no paving behind", after == before, "%d vs %d" % [after, before])


## T12: скорость placement() на площади и на улице
func _t12_perf() -> void:
	var res := {}
	for name: String in ["plaza", "rim", "street", "mouth"]:
		var pts := []
		for i in 200:
			match name:
				"plaza": pts.append(S2 + Vector2(-10 + (i % 20), -10 + (i / 20) * 2.0))
				"rim": pts.append(Vector2(171.0 + (i % 10) * 1.0, 135.0 + (i / 10) * 0.3))
				"street": pts.append(Vector2(168 + (i % 20), 166 + ((i / 20) % 3 - 1) * 0.8))
				"mouth": pts.append(Vector2(194 + (i % 5), 150 + (i / 5) * 0.5))
		var tot := 0
		var mx := 0
		for p: Vector2 in pts:
			var t0 := Time.get_ticks_usec()
			game.placement("house_pleb", p)
			var dt := Time.get_ticks_usec() - t0
			tot += dt
			mx = maxi(mx, dt)
		res[name] = [tot / pts.size(), mx]
		print("PAVE PERF %s avg=%d max=%d us" % [name, tot / pts.size(), mx])
	# сравнение с улицей в том же прогоне (машина то свободна, то занята): площадь — не больше чем вдвое с небольшим
	var lim := float(res["street"][0]) * 2.2 + 300.0
	ok("T12 plaza placement fast enough", float(res["plaza"][0]) < lim and float(res["rim"][0]) < lim, "plaza=%s rim=%s limit=%d" % [res["plaza"], res["rim"], int(lim)])
