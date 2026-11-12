extends SceneTree
## Справка без окна для «жизни» общественных зданий (Life): у каждой постройки (кроме украшений) — где вход (bp.door),
## какие створки дверей Synty есть рядом и какие из них Life находит, сколько ставен (пар створок) и что ещё висит
## одной деталью «#shutters_*». Запуск: bash .work/py/gpu_run.sh --headless --script res://scripts/test_civic_life_probe.gd
##   [only=temple,library] [doors=1 — габариты створок Synty] [life2=0 — как до «жизни построек 2»]
##   [tris=1 — треугольники здания и разных деталей, след, места работников; сверить «было/стало» с life2=0]


func _init() -> void:
	var only := []
	var tris := false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = Array(a.substr(5).split(","))
		elif a == "life2=0":
			CatDressCivic.LIFE2 = false
		elif a == "tris=1":
			tris = true
		elif a == "doors=1":
			_door_models()
		elif a == "dbg=1":
			CatDressCivic.dbg = true                   # почему кучка не встала
	var types := []
	for t: String in Defs.B.keys():
		var k := String((Defs.B[t] as Dictionary).get("kind", ""))
		if k == "decor" or (k == "house" and only.is_empty()):
			continue
		if not only.is_empty() and not only.has(t):
			continue
		types.append(t)
	for t: String in types:
		var vs := [[1, 0, 0]]
		if t == "house_patrician":
			vs = [[1, 4, 2], [2, 4, 5], [3, 5, 3], [2, 5, 7]]       # городской домус (Defs.PAT_TOWN): облики, этажи, цвета
		for v: Array in vs:
			_one(t, int(v[0]), int(v[1]), int(v[2]), tris)
	quit()


func _one(t: String, tier: int, v: int, col: int, tris: bool) -> void:
	var bp := Catalog.make(t, tier, v, col)
	var doors := []
	for i in bp.parts.size():
		var nm := String(bp.parts[i][0])
		if nm.begins_with("SM_Bld_Door_") or nm.contains("Gate"):
			var xf: Transform3D = bp.parts[i][1]
			var box: AABB = xf * Bp.model_aabb(nm)
			doors.append("%d:%s c=%s sz=%s z=%s" % [i, nm.trim_prefix("SM_Bld_"), box.get_center().snapped(Vector3.ONE * 0.01), box.size.snapped(Vector3.ONE * 0.01),
				Vector3(xf.basis.z.x, 0, xf.basis.z.z).normalized().snapped(Vector3.ONE * 0.01)])
	var found: Array = Life._find_doors(bp)
	var inf := {"shut": [], "pairs": 0}
	Life._find_shutters(bp, inf)
	var sh1 := 0
	for p: Array in bp.parts:
		if String(p[0]).begins_with("#shutters"):
			sh1 += 1
	var fp := Rect2()
	var first := true
	for r: Rect2 in bp.footprint():
		fp = r if first else fp.merge(r)
		first = false
	print("CLP %s t%d v%d door=%s fp=%s found=%s pairs=%d one_piece_shutters=%d parts=%d actors=%d" % [t, tier, v, bp.door.snapped(Vector3.ONE * 0.01), fp,
		str(found.map(func(d): return d[0])), int(inf["pairs"]), sh1, bp.parts.size(), bp.actors.size()])
	for d: String in doors:
		print("CLP   ", d)
	if tris:
		var all := 0
		var kinds := {}
		for p: Array in bp.parts:
			all += _tris(String(p[0]))
			kinds[String(p[0]) + str(p[2])] = true
		print("CLP TRIS %s t%d v%d: треугольников %d, разных деталей %d, след %s" % [t, tier, v, all, kinds.size(), str(bp.footprint())])


func _door_models() -> void:
	# створки Synty: габарит и где по ширине вершины (у двустворчатой одной сеткой — провал посредине)
	for nm: String in Synty.names("SM_Bld_Door_"):
		var bx := Bp.model_aabb(nm)
		var bins := PackedInt32Array()
		bins.resize(10)
		var n := Synty.make(nm)
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				for v: Vector3 in (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
					var k := clampi(int((v.x - bx.position.x) / maxf(bx.size.x, 0.001) * 10.0), 0, 9)
					bins[k] += 1
		n.free()
		print("CLP DOOR %s pos %s size %s x-bins %s" % [nm, bx.position.snapped(Vector3.ONE * 0.01), bx.size.snapped(Vector3.ONE * 0.01), bins])


static var _tc := {}
static func _tris(nm: String) -> int:
	if _tc.has(nm):
		return _tc[nm]
	var t := 0
	if nm.begins_with("#"):
		var m: Mesh = Parts._special_mesh(nm)
		if m:
			for s in m.get_surface_count():
				var ia: Array = m.surface_get_arrays(s)
				var idx = ia[Mesh.ARRAY_INDEX]
				t += (idx.size() if idx != null and idx.size() > 0 else (ia[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	else:
		var n := Synty.make(nm)
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				var ia: Array = mi.mesh.surface_get_arrays(s)
				var idx = ia[Mesh.ARRAY_INDEX]
				t += (idx.size() if idx != null and idx.size() > 0 else (ia[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		n.free()
	_tc[nm] = t
	return t
