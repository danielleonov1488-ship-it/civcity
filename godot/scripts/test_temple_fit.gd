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
	var c := City.new(Land.new())
	c.load_data(d)
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
