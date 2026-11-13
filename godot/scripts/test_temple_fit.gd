extends Node
## Храм Юпитера по линейке размеров (NewTemple, SizeLadder) без окна: размеры, детали, треугольники и огни прежнего
## храма и нового (полный — в размере линейки, «старое место» — под прежний след); город владельца: храм из старого
## сохранения (без «sz») собирается под свои прежние клетки и не налезает на одеон и библиотеку; новый храм в том же
## городе — полного размера; сохранение и загрузка это помнят.
##   bash .work/py/gpu_run.sh --headless res://test_temple_fit.tscn [-- probe=1]    → «TFIT DONE fails=0»
## probe=1 — только замеры (без проверок нового храма: годится и для прежних сборок)

const OWNER := "D:/CivCity/.work/owner_save/city.json"
var fails := 0


func check(ok: bool, what: String, got = null) -> bool:
	print(("  ok   " if ok else "FAIL ") + what + ("" if got == null or ok else "  → " + str(got)))
	if not ok:
		fails += 1
	return ok


func _ready() -> void:
	var probe := OS.get_cmdline_user_args().has("probe=1")
	var on0 := NewTemple.ON
	NewTemple.ON = false
	Catalog._cache.clear()
	var old := _measure("прежний (CatMonuments)", Catalog.make("temple", 0, 0, 0))
	NewTemple.ON = on0
	Catalog._cache.clear()
	var full := _measure("новый, полный", Catalog.make("temple", 0, 0, 0))
	var fit := _measure("новый, старое место", Catalog.make("temple", 0, 0, 0, false, true))
	if not probe:
		var lot: Rect2 = old["rect"]
		var area: float = full["area"]
		check(area > 80.0 and area < 100.0, "полный храм — главная ступень линейки (8–10 домов): %.0f м² = %.1f дома" % [area, area / SizeLadder.HOUSE])
		check(float(full["ridge"]) > 6.3 and float(full["ridge"]) < 7.3, "конёк полного — выше соседей (6,5–7 м): %.2f м" % float(full["ridge"]))
		check(SizeLadder.SINCE.has("temple"), "храм вписан в SizeLadder.SINCE (новый размер)")
		var fr: Rect2 = fit["rect"]
		check(lot.grow(0.02).encloses(fr), "«старое место» внутри прежнего следа %s: %s" % [lot, fr])
		check(float(fit["ridge"]) > 5.7, "«старое место» тоже высокий: конёк %.2f м" % float(fit["ridge"]))
		check(int(full["lights"]) <= 2 and int(fit["lights"]) <= 2, "огней не больше двух", [full["lights"], fit["lights"]])
		_owner()
	print("TFIT DONE fails=%d" % fails)
	get_tree().quit()


## Размеры, детали, треугольники, огни чертежа (метры города)
func _measure(what: String, bp: Bp) -> Dictionary:
	var r := Rect2()
	var first := true
	for rc: Rect2 in bp.footprint():
		r = rc if first else r.merge(rc)
		first = false
	var tris := 0
	var kinds := {}
	var ridge := 0.0
	for p: Array in bp.parts:
		var nm := String(p[0])
		tris += _tris(nm)
		kinds[nm + str(p[2])] = true
		if nm.begins_with("SM_Bld_Roof_Straight") or nm.begins_with("SM_Bld_Roof_Side"):
			var bx: AABB = (p[1] as Transform3D) * Bp.model_aabb(nm)
			ridge = maxf(ridge, bx.end.y)
	print("TFIT %s: след %.2f × %.2f м = %.1f м² (%.1f дома), x %.2f…%.2f, z %.2f…%.2f; конёк %.2f м, верх %.2f м; деталей %d (разных %d), треугольников %d, огней %d, людей при деле %d, вход %s" % [
		what, r.size.x, r.size.y, r.get_area(), r.get_area() / SizeLadder.HOUSE, r.position.x, r.end.x, r.position.y, r.end.y, ridge, bp.top_y(),
		bp.parts.size(), kinds.size(), tris, bp.lights.size(), bp.actors.size(), bp.door.snapped(Vector3.ONE * 0.01)])
	return {"rect": r, "area": r.get_area(), "ridge": ridge, "top": bp.top_y(), "parts": bp.parts.size(), "tris": tris, "lights": bp.lights.size(), "bp": bp}


## Город владельца: храм из старого сохранения — на своих клетках; новый храм — полный; сохранение и загрузка
func _owner() -> void:
	if not FileAccess.file_exists(OWNER):
		print("TFIT NOTE нет города владельца — пропуск")
		return
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OWNER))
	# 1) земля города не загружена (участки не куплены) — расти некуда: храм остаётся на прежних клетках («старое место»)
	print("TFIT owner: без земли города — расти некуда")
	var c := City.new(Land.new())
	c.load_data(d.duplicate(true))
	var t := {}
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		if b["type"] == "temple":
			t = b
	if not check(not t.is_empty(), "в городе владельца есть храм"):
		return
	check(not t.has("sz") and SizeLadder.old_lot(t), "храм владельца — из старого сохранения (без «sz»): на прежнем месте")
	var bp := c.blueprint(t)
	var own := Catalog.make("temple", int(t["tier"]), int(t.get("variant", 0)), int(t.get("color", 0)), false, true)
	check(bp == own, "его облик — сборка «старого места»")
	var cells := c.land.footprint_cells(bp.occ_footprint(), t["pos"], float(t["yaw"]))
	var mine := {}
	for k in (t["cells"] as PackedInt32Array):
		mine[k] = true
	var outside := 0
	var hit := {}
	for k in cells:
		if not mine.has(k):
			outside += 1
		var o: int = c.land.occ[k]
		if o != 0 and o != int(t["id"]):
			hit[o] = String(c.buildings.get(o, {}).get("type", "?"))
	print("TFIT owner: храм %d в (%.1f, %.1f), клеток прежних %d, новой сборки %d, из них вне прежних %d" % [int(t["id"]), t["pos"].x, t["pos"].y,
		(t["cells"] as PackedInt32Array).size(), cells.size(), outside])
	check(outside == 0, "новая сборка не выходит за прежние клетки храма", outside)
	check(hit.is_empty(), "и не налезает на соседей (одеон, библиотека…)", hit)
	# соседи: зазор до одеона и библиотеки (по клеткам)
	for nb in [[172.5, 157.2, "odeon"], [162.7, 148.7, "library"]]:
		var best := INF
		for id in c.buildings:
			var o: Dictionary = c.buildings[id]
			if o["type"] != nb[2] or (o["pos"] as Vector2).distance_to(Vector2(nb[0], nb[1])) > 1.0:
				continue
			for k in (o["cells"] as PackedInt32Array):
				var q := c.land.cell_center(k % Land.N, k / Land.N)
				for k2 in cells:
					best = minf(best, q.distance_to(c.land.cell_center(k2 % Land.N, k2 / Land.N)))
		print("TFIT owner: до %s — %.2f м (между серединами клеток)" % [nb[2], best])
	# новый храм в этом же городе (даром, на свободном месте) — полного размера
	var nt := c.place("temple", Vector2(120.0, 300.0), 0.0, 0, 0, true)
	check(int(nt.get("sz", 0)) == SizeLadder.REV and not SizeLadder.old_lot(nt), "новый храм помнит ревизию линейки (sz=%d)" % int(nt.get("sz", 0)))
	var nbp := c.blueprint(nt)
	check(nbp == Catalog.make("temple", int(nt["tier"]), 0, int(nt["color"])), "новый храм — полная сборка")
	# сохранение → загрузка: старый остаётся на прежнем месте, новый — полный
	var d2: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	var c2 := City.new(Land.new())
	c2.load_data(d2)
	var t2: Dictionary = c2.buildings.get(int(t["id"]), {})
	var n2: Dictionary = c2.buildings.get(int(nt["id"]), {})
	check(not t2.is_empty() and not t2.has("sz") and c2.blueprint(t2) == own, "после загрузки храм владельца — снова «старое место»")
	check(not n2.is_empty() and int(n2.get("sz", 0)) == SizeLadder.REV and c2.blueprint(n2) == nbp, "после загрузки новый храм — снова полный")
	var a_old := _area(c2.blueprint(t2))
	var a_new := _area(c2.blueprint(n2))
	print("TFIT owner: после загрузки — храм владельца %.1f м², новый %.1f м²" % [a_old, a_new])
	check(a_new > a_old + 30.0, "новый храм заметно больше храма на старом месте")
	_owner_grow(d, int(t["id"]), t["cells"])


## 2) как в игре: земля из сохранения, потом город — храм старого сохранения сам встаёт в полный размер, если рядом
## есть место (City.ladder_grow): не на дороге, не на соседях, до чужих построек не ближе метра, у входа — площадь
func _owner_grow(d: Dictionary, tid: int, old_cells: PackedInt32Array) -> void:
	print("TFIT owner: как в игре — земля и город из сохранения")
	var t0: Dictionary = {}
	for bd: Dictionary in d["buildings"]:
		if int(bd["id"]) == tid:
			t0 = bd
	var c := City.new(Land.new())
	c.land.load_changes(d.get("land", {}))
	var ms := Time.get_ticks_msec()
	c.load_data(d.duplicate(true))
	print("TFIT owner: загрузка с ростом — %d мс" % (Time.get_ticks_msec() - ms))
	var t: Dictionary = c.buildings.get(tid, {})
	if not check(not t.is_empty(), "храм владельца на месте после загрузки"):
		return
	if not t.has("sz"):
		_grow_why(c, t)
	var full := Catalog.make("temple", int(t["tier"]), int(t.get("variant", 0)), int(t.get("color", 0)))
	check(int(t.get("sz", 0)) == SizeLadder.REV and not SizeLadder.old_lot(t), "храм вырос: ревизия линейки записана (sz=%s)" % str(t.get("sz", "—")))
	check(c.blueprint(t) == full, "его облик — полный храм")
	var yaw := float(t["yaw"])
	var dp: Vector2 = (t["pos"] as Vector2) - Vector2(float(t0["x"]), float(t0["z"]))
	print("TFIT owner: сдвиг %.2f м — вбок %.2f, вперёд %.2f; клеток %d (было %d)" % [dp.length(), dp.dot(City.axis(yaw)), dp.dot(City.facing(yaw)),
		(t["cells"] as PackedInt32Array).size(), old_cells.size()])
	check(dp.length() <= City.GROW_SHIFT + 0.01, "сдвиг не больше %.0f м" % City.GROW_SHIFT, dp.length())
	var mine := {}
	for k in old_cells:
		mine[k] = true
	var road := 0
	var foreign := 0
	for k in (t["cells"] as PackedInt32Array):
		if c.land.occ[k] != tid:
			foreign += 1
		if not mine.has(k) and c.land.kind[k] == Land.Kind.ROAD:
			road += 1
	check(foreign == 0, "все клетки храма — его (ни одной чужой)", foreign)
	check(road == 0, "на дорогу не встал", road)
	check(bool(t.get("road", false)), "у входа — площадь или дорога (жители доходят)")
	# зазор до чужих построек (кроме украшений) и до одеона с библиотекой — по клеткам
	var cells: PackedInt32Array = t["cells"]
	var best := INF
	var near := {}
	for id in c.buildings:
		var o: Dictionary = c.buildings[id]
		if int(id) == tid or String(c.def(o)["kind"]) == "decor":
			continue
		var oc := c.land.cell_center(int((o["pos"] as Vector2).x / Land.CELL), int((o["pos"] as Vector2).y / Land.CELL))
		if oc.distance_to(t["pos"]) > 30.0:
			continue
		var m := INF
		for k in (o["cells"] as PackedInt32Array):
			var q := c.land.cell_center(k % Land.N, k / Land.N)
			if q.distance_to(t["pos"]) > 14.0:
				continue
			for k2 in cells:
				m = minf(m, q.distance_to(c.land.cell_center(k2 % Land.N, k2 / Land.N)))
		if m < INF:
			near[String(o["type"]) + "#" + str(id)] = snappedf(m, 0.01)
		best = minf(best, m)
	print("TFIT owner: до соседей (между серединами клеток, м): %s" % str(near))
	check(best >= City.GROW_GAP - 0.01, "до любой соседней постройки не меньше %.0f м (%.2f)" % [City.GROW_GAP, best])
	# украшения с пути отодвинуты, а не убраны: все постройки на месте, сдвинуты только мелкие украшения и недалеко
	check(c.buildings.size() == (d["buildings"] as Array).size(), "ни одна постройка не пропала (%d)" % c.buildings.size())
	var moved := []
	var bad := 0
	for bd: Dictionary in d["buildings"]:
		var o: Dictionary = c.buildings.get(int(bd["id"]), {})
		if o.is_empty() or int(bd["id"]) == tid:
			continue
		var dd := (o["pos"] as Vector2).distance_to(Vector2(float(bd["x"]), float(bd["z"])))
		if dd < 0.001:
			continue
		var mine_o := 0
		for k in (o["cells"] as PackedInt32Array):
			mine_o += 1 if c.land.occ[k] == int(o["id"]) else 0
		moved.append("%s#%d %.2f м (клеток своих %d/%d)" % [o["type"], int(o["id"]), dd, mine_o, (o["cells"] as PackedInt32Array).size()])
		# другие типы, что по линейке тоже растут (NewSmall: вигилы, бани, склад, скрипторий), сами встают в полный размер
		# со сдвигом до GROW_SHIFT — это их рост, а не «отодвинули с пути храма»
		var grew := SizeLadder.grows(String(o["type"])) and int(o.get("sz", 0)) >= int(SizeLadder.SINCE.get(String(o["type"]), 99)) 			and dd <= City.GROW_SHIFT + 0.01 and mine_o == (o["cells"] as PackedInt32Array).size()
		if not grew and (String(c.def(o)["kind"]) != "decor" or dd > City.GROW_NUDGE + 0.01 or mine_o != (o["cells"] as PackedInt32Array).size()):
			bad += 1
	print("TFIT owner: отодвинуты украшения: %s" % str(moved))
	check(bad == 0, "сдвинуты только мелкие украшения, не дальше %.0f м, на свои свободные клетки" % City.GROW_NUDGE, moved)
	# сохранение → загрузка: вырос один раз и таким остаётся (на том же месте, полный)
	var d2: Dictionary = c.save_data()
	d2["land"] = c.land.save_changes()
	d2 = JSON.parse_string(JSON.stringify(d2))
	var c2 := City.new(Land.new())
	c2.land.load_changes(d2["land"])
	c2.load_data(d2)
	var t2: Dictionary = c2.buildings.get(tid, {})
	check(not t2.is_empty() and int(t2.get("sz", 0)) == SizeLadder.REV and (t2["pos"] as Vector2).distance_to(t["pos"]) < 0.001
		and t2["cells"] == t["cells"] and c2.blueprint(t2) == full, "после сохранения и загрузки — тот же полный храм на том же месте")


func _area(bp: Bp) -> float:
	var r := Rect2()
	var first := true
	for rc: Rect2 in bp.footprint():
		r = rc if first else r.merge(rc)
		first = false
	return r.get_area()


static var _tc := {}
static func _tris(nm: String) -> int:
	if _tc.has(nm):
		return _tc[nm]
	var t := 0
	var meshes := []
	var n: Node = null
	if nm.begins_with("#"):
		var m: Mesh = Parts._special_mesh(nm)
		if m:
			meshes.append(m)
	else:
		n = Synty.make(nm)
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			meshes.append(mi.mesh)
	for m: Mesh in meshes:
		for s in m.get_surface_count():
			var ia: Array = m.surface_get_arrays(s)
			var idx = ia[Mesh.ARRAY_INDEX]
			t += (idx.size() if idx != null and idx.size() > 0 else (ia[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	if n:
		n.free()
	_tc[nm] = t
	return t


## Почему не вырос: по каждому сдвигу — что помешало (ошибка check_place или проверка City._grow_ok), сводка и ближние
func _grow_why(c: City, t: Dictionary) -> void:
	var yaw := float(t["yaw"])
	var f := City.facing(yaw)
	var ax := City.axis(yaw)
	var mine := {}
	for k in (t["cells"] as PackedInt32Array):
		mine[k] = true
	var why := {}
	var shown := 0
	var n := int(round(City.GROW_SHIFT / City.GROW_STEP))
	for i in range(-n, n + 1):
		for j in range(-n, n + 1):
			var sh := Vector2(i, j) * City.GROW_STEP
			if sh.length() > City.GROW_SHIFT + 0.001:
				continue
			var pos: Vector2 = (t["pos"] as Vector2) + ax * sh.x + f * sh.y
			var chk := c.check_place("temple", pos, yaw, int(t.get("variant", 0)), int(t.get("color", 0)), int(t["id"]))
			var e := String(chk["err"])
			if e == "":
				e = "зазор/дорога/перепад" if not c._grow_ok(t, chk["cells"], mine) else "годится"
			if e == "Место занято":
				var who := {}
				for k in (chk["cells"] as PackedInt32Array):
					var o: int = c.land.occ[k]
					if o != 0 and o != int(t["id"]):
						who[String(c.buildings.get(o, {}).get("type", str(o)))] = true
				e += " " + str(who.keys())
			why[e] = int(why.get(e, 0)) + 1
	print("TFIT why: %s" % str(why))
