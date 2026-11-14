extends SceneTree
## Замеры домов (линия rebuild-houses), без окна:
##   bash .work/py/gpu_run.sh --headless --script res://scripts/test_houses_probe.gd -- [new=0|1] [colors=0,3]
## Для каждого типа дома, облика и этажа: след (прямоугольник деталей), высота, вход, лицо фасада, детали, виды деталей
## (≈ группы пула), треугольники, огни, створки дверей и пары ставен (Life), сиденья, цветы для полива

var _tc := {}


func _initialize() -> void:
	var colors := [0]
	var newv := -1
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"colors":
				colors = []
				for c in kv[1].split(","):
					colors.append(int(c))
			"new": newv = int(kv[1])
	if newv >= 0:
		for k: String in NewHouses.TYPES:
			NewHouses.ON[k] = newv == 1
		Catalog._cache.clear()
	var all_kinds := {}
	var tot_tris := 0
	for t: String in ["house_pleb", "house_artisan", "house_patrician"]:
		var nv := int(Defs.B[t]["variants"])
		var vs := range(nv)
		if t == "house_patrician":
			vs = [0, 1, 2, 3, 4, 5]
		for v: int in vs:
			var fmax := Defs.floors_max(String(Defs.B[t]["cls"]), v)
			for f in range(1, fmax + 1):
				for c: int in colors:
					var bp := Catalog.make(t, f, v, c)
					var res := _lot("%s:v%d:f%d:c%d" % [t, v, f, c], bp)
					for k in res[0]:
						all_kinds[k] = true
					tot_tris += int(res[1])
	print("ALL KINDS %d  tris sum %d" % [all_kinds.size(), tot_tris])
	print("PROBE DONE")
	quit()


func _lot(tn: String, bp: Bp) -> Array:
	var r := Rect2()
	var first := true
	for rc: Rect2 in bp.footprint():
		r = rc if first else r.merge(rc)
		first = false
	var o := Rect2()
	first = true
	for rc: Rect2 in bp.occ_footprint():
		o = rc if first else o.merge(rc)
		first = false
	var tris := 0
	var kinds := {}
	for p: Array in bp.parts:
		tris += _tris(String(p[0]))
		var rm: Dictionary = (p[2] as Dictionary).duplicate()
		rm.erase("tint")
		rm.erase("tints")
		kinds[String(p[0]) + str(rm)] = true
	var inf := {"shut": [], "pairs": 0}
	Life._find_shutters(bp, inf)
	var doors := Life._find_doors(bp)
	var seats := Life._find_seats(bp, "house")
	var water := Life._find_water(bp)
	print("LOT %-26s x %.2f..%.2f z %.2f..%.2f (%.2fx%.2f=%.1f) occ z %.2f..%.2f front %.2f top %.2f door %s parts %d kinds %d tris %d lights %d actors %d doors %d pairs %d seats %d water %d smoke %d" % [
		tn, r.position.x, r.end.x, r.position.y, r.end.y, r.size.x, r.size.y, r.get_area(), o.position.y, o.end.y, bp.front_z(), bp.top_y(), bp.door.snapped(Vector3.ONE * 0.01),
		bp.parts.size(), kinds.size(), tris, bp.lights.size(), bp.actors.size(), doors.size(), int(inf["pairs"]), seats.size(), water.size(), bp.smoke.size()])
	if OS.get_cmdline_user_args().has("tris=1") and tn.contains(":f3:"):
		var per := {}
		for p: Array in bp.parts:
			per[String(p[0])] = int(per.get(String(p[0]), 0)) + _tris(String(p[0]))
		var ks := per.keys()
		ks.sort_custom(func(a1, b1): return int(per[a1]) > int(per[b1]))
		var line := []
		for k2 in ks.slice(0, 14):
			line.append("%s=%d" % [String(k2).trim_prefix("SM_"), int(per[k2])])
		print("   TRIS ", " ".join(line))
	if OS.get_cmdline_user_args().has("why=1"):
		var lim: Rect2 = LIM.get(tn.split(":")[0], Rect2())
		if tn.split(":")[0] == "house_patrician" and int(tn.split(":")[1].substr(1)) >= Defs.PAT_TOWN:
			lim = LIM["town"]
		var fz := bp.front_z()
		for p: Array in bp.parts:
			var nm: String = p[0]
			var xf: Transform3D = p[1]
			var box: AABB = xf * Bp.model_aabb(nm)
			if box.position.y > 1.6:
				continue
			var rr := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
			if not lim.grow(0.01).encloses(rr):
				print("   WHY %s %s low_y %.2f fz %.2f" % [nm, rr, box.position.y, fz])
	return [kinds.keys(), tris]


const LIM := {"house_pleb": Rect2(-1.42, -2.13, 2.84, 4.03), "house_artisan": Rect2(-1.42, -3.04, 2.84, 5.05),
	"house_patrician": Rect2(-1.42, -3.69, 2.84, 7.37), "town": Rect2(-1.42, -3.26, 2.84, 5.27)}


func _tris(nm: String) -> int:
	if _tc.has(nm):
		return _tc[nm]
	var n := 0
	if not nm.begins_with("#"):
		var node := Synty.make(nm)
		for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			var m := mi.mesh
			for s in m.get_surface_count():
				var arr := m.surface_get_arrays(s)
				var idx = arr[Mesh.ARRAY_INDEX]
				n += (idx.size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		node.free()
	_tc[nm] = n
	return n
