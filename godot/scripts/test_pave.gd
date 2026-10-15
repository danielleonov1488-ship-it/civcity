extends Node
## Свободная постановка (как в Town to City): дом — куда навёл и как повернул (трава, площадь, мостовая); курсор на
## траве вплотную к дороге — фасадом к ней ровно у края, без дёрганья; издалека к дороге не улетает. У входа — мостовая.
## Плюс сетка ходьбы, отмена мазка, большая дорога, повороты, перенос.
## Запуск: bash .work/py/gpu_run.sh res://test_pave.tscn            — всё (печатает PAVE PASS|FAIL …, в конце PAVE DONE fails=N)
##         bash .work/py/gpu_run.sh res://test_pave.tscn -- menu_hash=promo | menu_hash=demo — отпечаток готового города меню
## Снимки — в D:/CivCity/.work/gd/pave*.png

var game
var mask := 0
var fails := 0
var args := {}

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
	game.manual_yaw = false
	game.yaw_set = false
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
	game.can_save = false
	game.city.money = 50000.0
	game.city.tips["intro"] = true
	game.city.tips["cover_tip"] = true          # совет о подсветке охвата (test_cover) не загораживает щелчки по миру
	game.city.research["fountain"] = true
	game.hud.advisor_panel.visible = false
	game.rig.set_view(Vector3(180, 2, 150), 15, 58, 60)
	_paint()
	await frames(40)
	_f1_snap()
	_f2_no_fly()
	_f3_steady()
	_f4_on_paving()
	await _f5_mouse()
	_f6_owner_oval()
	_f7_yaw_kept()
	_f8_rules()
	await _f9_review()
	await _t8_rotate()
	await _t9_move()
	_t10_walk()
	_t11_undo()
	_t12_perf()
	game.rig.set_view(Vector3(200, 2, 175), 15, 55, 75)
	await frames(40)
	shot("pave4_overview.png")
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
	# табличка с названием в готовом городе — просто надпись «Новый Рим», не нажимается (окно «Название города» — только в своём)
	var hud: Hud = game.hud
	if hud.name_plate.mouse_filter != Control.MOUSE_FILTER_IGNORE or hud.lbl_city.text != CityName.PLACEHOLDER:
		print("FAIL табличка города в витрине: %s, нажимается=%s" % [hud.lbl_city.text, str(hud.name_plate.mouse_filter != Control.MOUSE_FILTER_IGNORE)])


func _paint() -> void:
	var L: Land = game.land
	flat_zone(Vector2(183, 160), 46, 62)
	flat_zone(S2, 40, 40)
	flat_zone(Vector2(152, 222), 44, 40)
	L.paint_circle(S1, 6.0, Land.Kind.ROAD, true, true, true)
	for st: Array in STREETS:
		L.paint_line(Vector2(164, st[0]), Vector2(190, st[0]), st[1], Land.Kind.ROAD, true)
	L.paint_line(Vector2(196, 150), Vector2(196, 172), 2.0, Land.Kind.ROAD, true)
	L.paint_circle(S2, 15.0, Land.Kind.PLAZA, true, true, true)
	# как у владельца на снимке: песчаная «площадь» овалом у улицы
	L.paint_line(Vector2(140, 230), Vector2(164, 230), 2.0, Land.Kind.ROAD, true)
	for x in range(144, 162, 2):
		L.paint_circle(Vector2(x, 222), 5.0, Land.Kind.DIRT, true, true, false)


func centre_pos(type: String, c: Vector2, yaw: float) -> Vector2:
	var bb: Array = game._row_bounds(Catalog.make(type, 1 if Defs.B[type]["kind"] == "house" else 0, 0, 0))
	return c - City.axis(yaw) * ((float(bb[0]) + float(bb[1])) * 0.5) - City.facing(yaw) * ((float(bb[2]) + float(bb[3])) * 0.5)


func cam_yaw() -> float:
	return snappedf(game.rig.yaw, PI / 2)


## F1: курсор на траве у улицы (фасад ближе 0,8 м к краю) — дом у края, фасадом к улице, не на мостовой, не боком
func _f1_snap() -> void:
	var bad := 0
	var n := 0
	for st: Array in STREETS:
		var z0: float = st[0]
		var r: float = st[1]
		for x in range(168, 188, 2):
			for dz: float in [0.3, 1.3, 2.4]:
				for sgn: float in [1.0, -1.0]:
					var p := Vector2(x, z0 + sgn * (r + dz))
					var pl := probe("house_pleb", p)
					n += 1
					var pos: Vector2 = pl["pos"]
					var y := float(pl["yaw"])
					var f := City.facing(y)
					var bb := bounds("house_pleb", pl)
					var front := pos.y + f.y * float(bb[3])
					var edge := z0 + sgn * r
					var good: bool = pl.get("sub", "") == "road" and pl["err"] == "" and not game.land.is_road(pos) \
						and absf(f.x) < 0.02 and signf(f.y) == -sgn and absf(front - edge) <= 0.3
					if not good:
						bad += 1
						if bad <= 6:
							print("PAVE   snap miss p=", p, " sub=", pl.get("sub", ""), " pos=", pos, " yaw=", snappedf(rad_to_deg(y), 0.1), " err=", pl["err"], " front=", snappedf(front, 0.01), " edge=", edge)
	ok("F1 next to a street: house at the edge, facing it", bad == 0, "%d/%d" % [n - bad, n])


## F2: если фасад дальше ~1 м от улицы — дом не улетает к ней, стоит, где курсор
func _f2_no_fly() -> void:
	var bad := 0
	var n := 0
	for st: Array in [STREETS[2]]:          # с севера у широкой улицы других дорог нет
		for x in range(168, 188, 4):
			for dz: float in [3.6, 4.5, 6.0]:
				var p := Vector2(x, float(st[0]) + float(st[1]) + dz)
				if Land.walk_kind(game.land.kind_at(p.x, p.y)):
					continue
				var pl := probe("house_pleb", p)
				n += 1
				if pl.get("sub", "") != "free" or centre("house_pleb", pl).distance_to(p) > 0.05 or not yaw_is(float(pl["yaw"]), cam_yaw(), 0.01):
					bad += 1
					if bad <= 4:
						print("PAVE   fly p=", p, " sub=", pl.get("sub", ""), " c=", centre("house_pleb", pl))
	ok("F2 a few metres away: stays at the cursor", bad == 0, "%d/%d" % [n - bad, n])
	var far := probe("house_pleb", Vector2(176, 125))
	ok("F2 far from any road: needs a road at the door", far["err"] == "Нужна дорога у входа", str(far["err"]))


## F3: вдоль улицы и у границы прилипания — без дёрганья
func _f3_steady() -> void:
	reset()
	var ys := {}
	for i in 40:
		var pl: Dictionary = game.placement("house_pleb", Vector2(168.0 + i * 0.4, 166.0 - 2.0 - 1.0))
		ys[snappedf(float(pl["yaw"]), 0.001)] = true
	ok("F3 sliding along a street: one facing all the way", ys.size() == 1, str(ys.keys()))
	reset()
	var trail := []
	for dz: float in [1.2, 2.0, 2.8, 3.2, 2.9, 2.4, 3.3, 3.0]:
		var pl: Dictionary = game.placement("house_pleb", Vector2(176, 184.0 + dz))
		trail.append(pl.get("sub", ""))
	ok("F3 once at the street it holds on (no flicker at the border)", not ("free" in trail), str(trail))
	var away: Dictionary = game.placement("house_pleb", Vector2(176, 184.0 + 4.4))
	ok("F3 moving well away lets go", away.get("sub", "") == "free", str(away.get("sub", "")))


## F4: курсор на самой мостовой (улица, площадь) — дом там, где курсор
func _f4_on_paving() -> void:
	for p: Vector2 in [Vector2(178, 180), S1 + Vector2(1, 1), S2 + Vector2(-4, 3)]:
		var pl := probe("house_pleb", p)
		ok("F4 on paving at %s: at the cursor" % str(p), pl.get("sub", "") == "free" and pl["err"] == "" and centre("house_pleb", pl).distance_to(p) <= 0.05 and all_paved(pl["cells"]),
			"sub=%s err=%s" % [pl.get("sub", ""), pl["err"]])


## F5: мышью на площади — дом под курсором, второй в ряд, лавка в тот же ряд; совет советника один раз
func _f5_mouse() -> void:
	game.rig.set_view(Vector3(176, 2, 141), 15, 58, 36)
	await frames(60)
	await click(center_of(game.hud.cats["housing"]))
	await frames(5)
	var card: Control = null
	for c in game.hud.tray_grid.get_children():
		if c.get_meta("type", "") == "house_pleb":
			card = c
	if not ok("F5 house card found", card != null):
		return
	await click(center_of(card))
	reset()
	move(scr(S1))
	await frames(10)
	var pl: Dictionary = game.place_info
	ok("F5 ghost at the cursor", pl.get("sub", "") == "free" and pl.get("err", "?") == "" and centre("house_pleb", pl).distance_to(S1) <= 0.06,
		"sub=%s err=%s" % [pl.get("sub", ""), pl.get("err", "?")])
	shot("pave1_ghost.png")
	var before: Dictionary = game.city.buildings.duplicate()
	await click(scr(S1))
	var ids := new_ids(before)
	if not ok("F5 house A built", ids.size() == 1):
		return
	var A: Dictionary = game.city.buildings[ids[0]]
	ok("F5 advisor explains free building once", game.hud.advisor_panel.visible and game.hud.adv_title.text == "Строим где хотите" and game.city.tips.has("free_place"))
	game.hud.advisor_panel.visible = false
	before = game.city.buildings.duplicate()
	await click(scr(S1 + Vector2(3.4, 0)))
	ids = new_ids(before)
	if ok("F5 house B built", ids.size() == 1):
		var B: Dictionary = game.city.buildings[ids[0]]
		var bbA: Array = game._row_bounds(game.city.blueprint(A))
		var bbB: Array = game._row_bounds(game.city.blueprint(B))
		var rel: Vector2 = (B["pos"] as Vector2) - (A["pos"] as Vector2)
		var gap := rel.dot(City.axis(float(A["yaw"]))) + float(bbB[0]) - float(bbA[1])
		ok("F5 house B joins the row (gap 0.6)", yaw_is(float(B["yaw"]), float(A["yaw"]), 0.02)
			and absf(rel.dot(City.facing(float(A["yaw"]))) + float(bbB[3]) - float(bbA[3])) <= 0.05 and absf(gap - Game.ROW_GAP) <= 0.06, "gap=%.2f" % gap)
	game.set_tool("stall_fruit")
	reset()
	before = game.city.buildings.duplicate()
	await click(scr(S1 - Vector2(3.4, 0)))
	ids = new_ids(before)
	if ok("F5 stall built", ids.size() == 1):
		var C: Dictionary = game.city.buildings[ids[0]]
		var bbA2: Array = game._row_bounds(game.city.blueprint(A))
		var bbC: Array = game._row_bounds(game.city.blueprint(C))
		var relc: Vector2 = (C["pos"] as Vector2) - (A["pos"] as Vector2)
		var gapc := float(bbA2[0]) - (relc.dot(City.axis(float(A["yaw"]))) + float(bbC[1]))
		ok("F5 stall in the same row", yaw_is(float(C["yaw"]), float(A["yaw"]), 0.02) and absf(gapc - Game.ROW_GAP) <= 0.06, "gap=%.2f" % gapc)
	await frames(100)
	shot("pave2_row.png")
	game.set_tool("house_pleb")


## F6: как на снимке владельца — песчаная площадь у улицы, внизу ряд домов: лавка ставится везде, где помещается
## (раньше то «перед входом нужно свободное место», то можно — от сдвига мыши на миллиметр)
func _f6_owner_oval() -> void:
	for x: float in [149.0, 152.4, 155.8]:
		var pl := probe("house_pleb", Vector2(x, 227.6))
		if pl["err"] == "":
			game.city.place("house_pleb", pl["pos"], pl["yaw"], int(pl["variant"]), int(pl["color"]))
	var bad := 0
	var n := 0
	var errs := {}
	for i in 30:
		for j in 14:
			var p := Vector2(142.0 + i * 0.73, 217.0 + j * 0.53)
			if not Land.walk_kind(game.land.kind_at(p.x, p.y)):
				continue
			var pl := probe("stall_fruit", p)
			if not all_paved(pl["cells"]):
				continue
			n += 1
			errs[pl["err"]] = int(errs.get(pl["err"], 0)) + 1
			if pl["err"] in ["Нужна дорога у входа", "Перед входом нужно свободное место — поверните постройку (потяните мышью вбок)"]:
				bad += 1
	print("PAVE   oval errors: ", errs)
	ok("F6 a stall on the sandy plaza is never refused for its door", bad == 0 and n > 50, "%d bad of %d" % [bad, n])


## F7: свой поворот держится и для следующих построек
func _f7_yaw_kept() -> void:
	reset()
	game.free_yaw = 0.7
	game.yaw_set = true
	var a: Dictionary = game.placement("house_pleb", S2 + Vector2(6, -6))
	ok("F7 player's rotation is used", a.get("sub", "") == "free" and yaw_is(float(a["yaw"]), 0.7, 0.001))
	game.manual_yaw = false            # как после постройки
	var b: Dictionary = game.placement("house_pleb", S2 + Vector2(-6, 6))
	ok("F7 and kept for the next building", yaw_is(float(b["yaw"]), 0.7, 0.001))
	reset()
	game.manual_yaw = true
	game.tool_yaw = 1.0
	var c: Dictionary = game.placement("house_pleb", Vector2(176, 166.0 - 2.0 - 0.8))
	ok("F7 a rotated house does not snap to the street", c.get("sub", "") == "free" and yaw_is(float(c["yaw"]), 1.0, 0.001))
	reset()
	game.snap = false
	var e: Dictionary = game.placement("house_pleb", Vector2(176, 166.0 - 2.0 - 0.8))
	ok("F7 snap off (R): no sticking to the street", e.get("sub", "") == "free")
	reset()


## F8: правила — большая дорога к станции, чужая дверь, склон на мостовой, фонтан
func _f8_rules() -> void:
	game.land.paint_circle(Vector2(186, 116), 6.0, Land.Kind.ROAD, true, true, true)
	var r := probe("house_pleb", Vector2(191.5, 116))
	ok("F8 no buildings on the big road to the station", r["err"] == "По большой дороге ездят повозки — здесь не строят", str(r["err"]))
	var H: Dictionary = game.city.place("house_pleb", centre_pos("house_pleb", S2, 0.0), 0.0)
	var dp: Vector2 = game.city.door_point(H)
	reset()
	game.manual_yaw = true
	game.tool_yaw = PI / 2
	var k2: Dictionary = game.placement("house_pleb", dp + Vector2(0, 1.4))
	ok("F8 covering a neighbour's door is refused", k2["err"] == "Так загородится вход соседней постройки", str(k2["err"]))
	game.city.remove(H, false)
	var g := probe("fountain", S2 + Vector2(8, 8))
	ok("F8 fountain stands where the cursor is", g["err"] == "" and centre("fountain", g).distance_to(S2 + Vector2(8, 8)) <= 0.1, "err=%s" % g["err"])
	var L: Land = game.land
	var c := Vector2(214, 182)
	var cells: PackedInt32Array = L.footprint_cells([Rect2(-6, -6, 12, 12)], c, 0.0)
	var y0 := L.height_at(c.x, c.y)
	for k in cells:
		var cc := L.cell_center(k % Land.N, k / Land.N)
		L.h[k] = y0 + 0.3 * (cc.x - (c.x - 6.0))
		L._mark(k % Land.N, k / Land.N)
	L.paint_circle(c, 6.0, Land.Kind.ROAD, false, true, true)
	var sl := probe("house_pleb", c)
	ok("F8 steep paving refused with a reason", sl["err"] == "Мостовая здесь слишком наклонная — найдите место ровнее", str(sl["err"]))
	reset()


## F9: по независимой проверке — край дороги без прыжка, Z/X на месте, поворот не сбивается переносом, поле не на большую дорогу
func _f9_review() -> void:
	# курсор с травы заехал на дорогу у самого края — постройка не прыгает на мостовую
	reset()
	var a: Dictionary = game.placement("house_pleb", Vector2(176, 168.0 + 0.3))
	var b: Dictionary = game.placement("house_pleb", Vector2(176, 168.0 - 0.5))
	ok("F9 cursor slips onto the street edge: still snapped, no jump", a.get("sub", "") == "road" and b.get("sub", "") == "road"
		and (a["pos"] as Vector2).distance_to(b["pos"]) <= 0.05 and yaw_is(float(a["yaw"]), float(b["yaw"]), 0.001), "a=%s b=%s %s" % [a.get("sub", ""), b.get("sub", ""), (a["pos"] as Vector2).distance_to(b["pos"])])
	var c: Dictionary = game.placement("house_pleb", Vector2(176, 168.0 - 1.6))
	ok("F9 deeper into the street: free on the paving", c.get("sub", "") == "free")
	# Z у дороги — поворачивается на месте (середина остаётся)
	reset()
	var p := Vector2(176, 168.0 + 0.6)
	var s0: Dictionary = game.placement("house_pleb", p)
	game.place_info = s0
	game.hover = p
	game._rot_keep()
	game.tool_yaw = float(s0["yaw"]) + deg_to_rad(15)
	game.manual_yaw = true
	var s1: Dictionary = game.placement("house_pleb", p)
	ok("F9 Z/X next to a road turns it in place", centre("house_pleb", s1).distance_to(centre("house_pleb", s0)) <= 0.05 and yaw_is(float(s1["yaw"]), float(s0["yaw"]) + deg_to_rad(15), 0.002),
		"moved %.2f" % centre("house_pleb", s1).distance_to(centre("house_pleb", s0)))
	# свой поворот не сбивается переносом дома
	reset()
	game.yaw_set = true
	game.free_yaw = 0.7
	var src: Dictionary = {}
	for id in game.city.buildings:
		if game.city.buildings[id]["type"] == "house_pleb":
			src = game.city.buildings[id]
	if not src.is_empty():
		game.start_move(src)
		game.set_tool("")                    # отменили перенос
		game.set_tool("house_pleb")
	game.yaw_set = true
	var k: Dictionary = game.placement("house_pleb", S2 + Vector2(9, -9))
	ok("F9 remembered rotation survives moving a house", yaw_is(float(k["yaw"]), 0.7, 0.001), "yaw=%.3f" % float(k["yaw"]))
	# новая постройка не отрезает соседа от дороги (его дверь не накрыта, но мостовая у входа закрыта вся)
	reset()
	var st: Dictionary = game.city.place("stall_fruit", centre_pos("stall_fruit", Vector2(176, 186.6), PI), PI)
	game.city.compute()
	var cut := false
	if bool(st.get("road", false)):
		var sdp: Vector2 = game.city.door_point(st)
		for dx: float in [-1.5, -0.75, 0.0, 0.75, 1.5]:
			for dz: float in [-1.5, -0.75]:
				var q := probe("house_pleb", sdp + Vector2(dx, dz))
				if q["err"] == "":
					var own := {}
					for kk in (q["cells"] as PackedInt32Array):
						own[kk] = true
					if not game._road_free_near(sdp, 1.7, own):
						cut = true
	ok("F9 a building never cuts a neighbour off the road", bool(st.get("road", false)) and not cut)
	game.city.remove(st, false)
	# поле — не на большую дорогу к станции
	reset()
	var ft := _a_farm()
	if Defs.B[ft].has("unlock"):
		game.city.research[Defs.B[ft]["unlock"]] = true
	game.city.research[ft] = true
	var f: Dictionary = game.placement(ft, Vector2(192, 100))
	ok("F9 a farm cannot cover the big road", f["err"] == "По большой дороге ездят повозки — здесь не строят", str(f["err"]))
	reset()


func _a_farm() -> String:
	for t in Defs.B:
		if Defs.B[t]["kind"] == "farm":
			return t
	return ""


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
			mid_ok = pl.get("sub", "") == "lock" and pl.get("err", "?") == ""
	print("PAVE   T8 before release: pressing=", game.pressing, " rot_drag=", game.rot_drag, " lock=", game.place_lock, " info=", game.place_info.get("mode", ""), "/", game.place_info.get("sub", ""), " err=", game.place_info.get("err", ""), " ui=", game.hud.mouse_over_ui(), " n=", game.city.buildings.size() - n0)
	btn(a + Vector2(114, 0), MOUSE_BUTTON_LEFT, false)
	await frames(5)
	print("PAVE   T8 after release: manual=", game.manual_yaw, " lock=", game.place_lock, " n=", game.city.buildings.size() - n0, " tool=", game.tool)
	ok("T8 rotating keeps the ghost in place", mid_ok)
	ok("T8 release after rotating does not build", game.city.buildings.size() == n0 and game.place_lock.is_empty() and game.manual_yaw)
	var ty: float = game.tool_yaw
	var b := scr(Vector2(222, 240))
	move(b)
	await frames(8)
	var pl2: Dictionary = game.place_info
	ok("T8 rotated ghost follows the mouse", pl2.get("sub", "") == "free" and yaw_is(float(pl2["yaw"]), ty, 0.002) and pl2["err"] == "",
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
	ok("T9 moving keeps the old yaw", pl.get("sub", "") == "free" and pl["err"] == "" and yaw_is(float(pl["yaw"]), y0, 0.02), "sub=%s err=%s" % [pl.get("sub", ""), pl["err"]])
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


## T12: скорость placement(): свободно на площади и у улицы
func _t12_perf() -> void:
	var res := {}
	for name: String in ["free", "street"]:
		var tot := 0
		var mx := 0
		reset()
		for i in 200:
			var p: Vector2 = S2 + Vector2(-10 + (i % 20), -10 + (i / 20) * 2.0) if name == "free" else Vector2(168 + (i % 20), 166.0 - 2.0 - 0.6 - ((i / 20) % 3) * 0.3)
			var t0 := Time.get_ticks_usec()
			game.placement("house_pleb", p)
			var dt := Time.get_ticks_usec() - t0
			tot += dt
			mx = maxi(mx, dt)
		res[name] = [tot / 200, mx]
		print("PAVE PERF %s avg=%d max=%d us" % [name, tot / 200, mx])
	ok("T12 placement fast enough", int(res["free"][0]) < 3000 and int(res["street"][0]) < 3000, str(res))
