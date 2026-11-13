extends Node
## Новые пантеон, академия, форум и храм Венеры (NewGrand, SizeLadder) без окна: размеры, высоты, детали, треугольники
## и огни прежних и новых сборок; академия, форум и храм Венеры — внутри прежних следов (старое сохранение стоит на тех
## же клетках); пантеон старого сохранения собирается под прежние клетки, а в городе владельца (земля и город из
## сохранения) сам вырастает в полный, где есть место, и остаётся на прежних клетках, если его обступили дома;
## сохранение и загрузка это помнят.
##   bash .work/py/gpu_run.sh --headless res://test_grand_fit.tscn      → «GFIT DONE fails=0»

const OWNER := "D:/CivCity/.work/owner_save/city.json"
const TEMPLE_RIDGE := 6.8
var fails := 0
static var _tc := {}


func check(ok: bool, what: String, got = null) -> bool:
	print(("  ok   " if ok else "FAIL ") + what + ("" if got == null or ok else "  → " + str(got)))
	if not ok:
		fails += 1
	return ok


func _ready() -> void:
	var m := {}
	for t: String in NewGrand.TYPES:
		NewGrand.ON[t] = false
		Catalog._cache.clear()
		m[t + ":old"] = _measure(t + " прежний", Catalog.make(t, 0, 0, 0))
		NewGrand.ON[t] = true
		Catalog._cache.clear()
		m[t] = _measure(t + " новый", Catalog.make(t, 0, 0, 0))
	m["pantheon:fit"] = _measure("pantheon старое место", Catalog.make("pantheon", 0, 0, 0, false, true))
	m["temple"] = _measure("temple (образец)", Catalog.make("temple", 0, 0, 0))
	var H := SizeLadder.HOUSE
	var ap: float = m["pantheon"]["area"]
	check(ap > 95.0 and ap < 105.0, "пантеон — главная ступень (≈ 100 м²): %.1f м² = %.1f дома" % [ap, ap / H])
	check(float(m["pantheon"]["top"]) <= 7.15, "купол пантеона не выше ~7 м: %.2f м" % float(m["pantheon"]["top"]))
	var aa: float = m["academy"]["area"]
	check(aa > 88.0 and aa < 104.0, "академия — главная ступень (8–10 домов): %.1f м² = %.1f дома" % [aa, aa / H])
	var af: float = m["forum"]["area"]
	check(af > 56.0 and af < 78.0, "форум — большая ступень (5–7 домов): %.1f м² = %.1f дома" % [af, af / H])
	var av: float = m["venus"]["area"]
	check(av > 56.0 and av < 78.0, "храм Венеры — большая ступень (5–7 домов): %.1f м² = %.1f дома" % [av, av / H])
	for t: String in ["academy", "forum"]:
		check(float(m[t]["top"]) < TEMPLE_RIDGE, "%s ниже конька храма Юпитера (%.1f м): %.2f м" % [t, TEMPLE_RIDGE, float(m[t]["top"])])
	check(float(m["venus"]["top"]) < float(m["temple"]["top"]) - 0.8, "храм Венеры заметно ниже храма Юпитера: %.2f м против %.2f" % [float(m["venus"]["top"]), float(m["temple"]["top"])])
	for t: String in ["academy", "forum", "venus"]:
		var o: Rect2 = m[t + ":old"]["rect"]
		var n: Rect2 = m[t]["rect"]
		check(o.grow(0.03).encloses(n), "%s: новая сборка внутри прежнего следа (старое сохранение — те же клетки) %s ⊂ %s" % [t, n, o])
	var po: Rect2 = m["pantheon:old"]["rect"]
	var pf: Rect2 = m["pantheon:fit"]["rect"]
	check(po.grow(0.03).encloses(pf), "пантеон «старое место» внутри прежнего следа %s ⊂ %s" % [pf, po])
	check(float(m["pantheon:fit"]["top"]) > 5.8, "«старое место» тоже с высоким куполом: %.2f м" % float(m["pantheon:fit"]["top"]))
	for t: String in NewGrand.TYPES:
		check(SizeLadder.SINCE.has(t), "%s вписан в SizeLadder.SINCE" % t)
		check(int(m[t]["lights"]) <= 2, "%s: огней не больше двух (%d)" % [t, int(m[t]["lights"])])
	check(SizeLadder.TARGET.has("pantheon") and SizeLadder.grows("pantheon"), "пантеон в TARGET и растёт (SizeLadder.grows)")
	for t: String in ["academy", "forum", "venus"]:
		check(not SizeLadder.grows(t), "%s не растёт (размер прежний)" % t)
	_owner()
	print("GFIT DONE fails=%d" % fails)
	get_tree().quit()


func _rect(bp: Bp) -> Rect2:
	var r := Rect2()
	var first := true
	for rc: Rect2 in bp.footprint():
		r = rc if first else r.merge(rc)
		first = false
	return r


func _measure(what: String, bp: Bp) -> Dictionary:
	var r := _rect(bp)
	var tris := 0
	var kinds := {}
	for p: Array in bp.parts:
		tris += _tris(String(p[0]))
		kinds[String(p[0]) + str(p[2])] = true
	print("GFIT %s: след %.2f × %.2f м = %.1f м² (%.1f дома), x %.2f…%.2f, z %.2f…%.2f; верх %.2f м; деталей %d (разных %d), треугольников %d, огней %d, людей при деле %d, вход %s" % [
		what, r.size.x, r.size.y, r.get_area(), r.get_area() / SizeLadder.HOUSE, r.position.x, r.end.x, r.position.y, r.end.y, bp.top_y(),
		bp.parts.size(), kinds.size(), tris, bp.lights.size(), bp.actors.size(), bp.door.snapped(Vector3.ONE * 0.01)])
	return {"rect": r, "area": r.get_area(), "top": bp.top_y(), "parts": bp.parts.size(), "tris": tris, "lights": bp.lights.size()}


## Город владельца (земля и город из сохранения): пантеон «из старого сохранения» (на клетках прежней сборки, без «sz»)
## рядом с храмом Юпитера. Есть место — после загрузки вырастает в полный (City.ladder_grow); обступили дома — остаётся
## на прежних клетках, облик «старого места»
func _owner() -> void:
	if not FileAccess.file_exists(OWNER):
		print("GFIT NOTE нет города владельца — пропуск")
		return
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OWNER))
	var c := _load(d)
	for r in Defs.RESEARCH:
		c.research[r["id"]] = true
	var tm := {}
	for id in c.buildings:
		if c.buildings[id]["type"] == "temple":
			tm = c.buildings[id]
	var from := Vector2(172.4, 148.7) if tm.is_empty() else (tm["pos"] as Vector2)
	NewGrand.ON["pantheon"] = false
	Catalog._cache.clear()
	var oldbp := Catalog.make("pantheon", 0, 0, 0)
	NewGrand.ON["pantheon"] = true
	Catalog._cache.clear()
	var fullbp := Catalog.make("pantheon", 0, 0, 0)
	var fitbp := Catalog.make("pantheon", 0, 0, 0, false, true)
	# место: прежняя сборка встаёт (как стояла бы в старом городе), и City.ladder_grow находит рядом место полной
	# (та же проверка, что при загрузке: своя земля, не дорога, ровно, до соседей не ближе метра)
	var spot := {}
	var tried := 0
	for k in 2500:
		var p := from + Vector2(cos(k * 2.4), sin(k * 2.4)) * (8.0 + k * 0.03)
		for yaw: float in [0.0, PI / 2, PI, -PI / 2]:
			var oc := c.land.footprint_cells(oldbp.occ_footprint(), p, yaw)
			if oc.is_empty() or String(c.check_place("pantheon", p, yaw, 0, 0, -2, oc)["err"]) != "":
				continue
			var fc := c.land.footprint_cells(fullbp.occ_footprint(), p, yaw)
			if fc.is_empty() or String(c.check_place("pantheon", p, yaw, 0, 0, -2, fc)["err"]) != "":
				continue
			tried += 1
			var probe := c.place("pantheon", p, yaw, 0, 0, true, oc, 0)
			var ok := not c._grow_spot(probe).is_empty()
			c.remove(probe, false, true)
			if ok:
				spot = {"pos": p, "yaw": yaw, "cells": oc}
				break
			if tried >= 60:
				break
		if not spot.is_empty() or tried >= 60:
			break
	if not check(not spot.is_empty(), "в городе владельца есть место для пантеона рядом с храмом"):
		return
	print("GFIT owner: пантеон старого сохранения в (%.1f, %.1f), поворот %.2f, до храма %.1f м, клеток %d" % [spot["pos"].x, spot["pos"].y, spot["yaw"],
		(spot["pos"] as Vector2).distance_to(from), (spot["cells"] as PackedInt32Array).size()])
	# 1) место есть: старое сохранение → загрузка → вырос
	var pb := c.place("pantheon", spot["pos"], spot["yaw"], 0, 0, true, spot["cells"], 0)
	var pid := int(pb["id"])
	check(not pb.has("sz") and SizeLadder.old_lot(pb) and c.blueprint(pb) == fitbp, "пантеон «из старого сохранения»: без sz, облик — старого места")
	var fcells := c.land.footprint_cells(fitbp.occ_footprint(), spot["pos"], spot["yaw"])
	var mine := {}
	for kk in (spot["cells"] as PackedInt32Array):
		mine[kk] = true
	# у прежнего пантеона клетки заняты только под самими деталями (кольцо ротонды, портик, лестница) — углы его
	# прямоугольника 7,2 × 9,9 м и середина ротонды свободны; облик «старого места» стоит в этом прямоугольнике
	# (мощёный двор — по всему нему). Клетки за «кольцом» прежних — только внутри прямоугольника и ничьи
	var out := 0
	var busy := 0
	var outside := 0
	var inv := Transform3D(Basis(Vector3.UP, float(spot["yaw"])), Vector3(spot["pos"].x, 0, spot["pos"].y)).affine_inverse()
	var lot: Rect2 = _rect(oldbp).grow(0.2)
	for kk in fcells:
		if mine.has(kk):
			continue
		out += 1
		var q := c.land.cell_center(kk % Land.N, kk / Land.N)
		var lq := inv * Vector3(q.x, 0, q.y)
		if not lot.has_point(Vector2(lq.x, lq.z)):
			outside += 1
		var o: int = c.land.occ[kk]
		if o != 0 and o != pid:
			busy += 1
	print("GFIT owner: клеток облика «старого места» %d, из них вне прежних занятых %d (углы прямоугольника и середина ротонды)" % [fcells.size(), out])
	check(outside == 0, "облик «старого места» — в прямоугольнике прежнего следа (вне его клеток: %d)" % outside)
	check(busy == 0, "и не налезает на чужие клетки (%d)" % busy)
	var c2 := _reload(c)
	var p2: Dictionary = c2.buildings.get(pid, {})
	check(not p2.is_empty() and int(p2.get("sz", 0)) == SizeLadder.REV and c2.blueprint(p2) == fullbp,
		"после загрузки пантеон вырос в полный (sz=%s, сдвиг %.2f м)" % [str(p2.get("sz", "—")), (p2.get("pos", Vector2.ZERO) as Vector2).distance_to(spot["pos"])])
	var foreign := 0
	for kk in (p2.get("cells", PackedInt32Array()) as PackedInt32Array):
		foreign += 0 if c2.land.occ[kk] == pid else 1
	check(foreign == 0, "все клетки выросшего пантеона — его", foreign)
	var c3 := _reload(c2)
	var p3: Dictionary = c3.buildings.get(pid, {})
	check(not p3.is_empty() and int(p3.get("sz", 0)) == SizeLadder.REV and p3["cells"] == p2["cells"] and c3.blueprint(p3) == fullbp,
		"ещё одно сохранение и загрузка — тот же полный пантеон на том же месте")
	# 2) обступили дома: старое сохранение → загрузка → остаётся на прежних клетках
	var c4 := _load(d)
	for r in Defs.RESEARCH:
		c4.research[r["id"]] = true
	var pb4 := c4.place("pantheon", spot["pos"], spot["yaw"], 0, 0, true, spot["cells"], 0)
	var yaw: float = spot["yaw"]
	var o: Rect2 = _rect(oldbp)
	var houses := 0
	for e: Array in [[o.position.x - 1.9, 0.0], [o.end.x + 1.9, 0.0], [o.position.x - 1.9, -2.6], [o.end.x + 1.9, -2.6],
			[o.position.x - 1.9, 2.6], [o.end.x + 1.9, 2.6], [-1.6, o.position.y - 2.5], [1.6, o.position.y - 2.5]]:
		# точка в осях постройки (x вбок, z вперёд к фасаду) → в мир
		var lp := Transform3D(Basis(Vector3.UP, yaw), Vector3((spot["pos"] as Vector2).x, 0, (spot["pos"] as Vector2).y)) * Vector3(float(e[0]), 0, float(e[1]))
		var w := Vector2(lp.x, lp.z)
		var hb := c4.place("house_pleb", w, yaw, 0, 1, true)
		if not hb.is_empty() and not (hb["cells"] as PackedInt32Array).is_empty():
			houses += 1
	print("GFIT owner: вокруг пантеона поставлено домов %d" % houses)
	var c5 := _reload(c4)
	var p5: Dictionary = c5.buildings.get(int(pb4["id"]), {})
	check(not p5.is_empty() and not p5.has("sz") and p5["cells"] == spot["cells"] and c5.blueprint(p5) == fitbp,
		"обступили дома — остаётся на прежних клетках, облик «старого места» (sz=%s)" % str(p5.get("sz", "—")))


func _load(d: Dictionary) -> City:
	var c := City.new(Land.new())
	c.land.load_changes(d.get("land", {}))
	c.load_data(d.duplicate(true))
	return c


func _reload(c: City) -> City:
	var d2: Dictionary = c.save_data()
	d2["land"] = c.land.save_changes()
	d2 = JSON.parse_string(JSON.stringify(d2))
	return _load(d2)


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
