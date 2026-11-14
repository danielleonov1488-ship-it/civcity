extends SceneTree
## Замеры для новых прилавков, уличных зрелищ, огорода, приюта, кошачьей лавки, травника, скульптора и лудуса (NewShops2, линия rebuild-shops2), без окна:
##   bash .work/py/gpu_run.sh --headless --script res://scripts/test_shops2_probe.gd -- [names=a,b,…] [fv=1]
## Для каждого типа: прежняя сборка (old), новая полная (new), новая на прежнем следе (fit) — след, высота, вход, детали,
## виды деталей (≈ группы пула), треугольники, огни, люди при деле, створки дверей и пары ставен (Life)

var _tc := {}


func _initialize() -> void:
	var names := ["stall_fruit", "stall_veg", "stall_fish", "musicians", "dice", "mimes", "puppets", "ogorod", "shelter", "catshop", "herbalist", "sculptor", "ludus", "house_pleb"]
	var colors := [0, 3]
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"names": names = Array(kv[1].split(","))
			"colors":
				colors = []
				for c in kv[1].split(","):
					colors.append(int(c))
	for t: String in names:
		var tier := 1 if t.begins_with("house") else 0
		if NewShops2.ON.has(t):
			NewShops2.ON[t] = false
			Catalog._cache.clear()
			_lot(t + ":old", Catalog.make(t, tier, 0, 0))
			NewShops2.ON[t] = true
		Catalog._cache.clear()
		for c: int in colors:
			_lot("%s:new:c%d" % [t, c], Catalog.make(t, tier, 0, c))
			if SizeLadder.SINCE.has(t):
				_lot("%s:fit:c%d" % [t, c], Catalog.make(t, tier, 0, c, false, true))
	print("PROBE DONE")
	quit()


func _lot(tn: String, bp: Bp) -> void:
	var t := tn.split(":")[0]
	var r := Rect2()
	var first := true
	for rc: Rect2 in bp.footprint():
		r = rc if first else r.merge(rc)
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
	print("LOT %-22s x %.2f .. %.2f  z %.2f .. %.2f  (%.2f x %.2f = %.1f m2)  top %.2f  door %s  parts %d (kinds %d)  tris %d  lights %d  actors %d  doors %d  shutter_pairs %d" % [
		tn, r.position.x, r.end.x, r.position.y, r.end.y, r.size.x, r.size.y, r.get_area(), bp.top_y(), bp.door.snapped(Vector3.ONE * 0.01),
		bp.parts.size(), kinds.size(), tris, bp.lights.size(), bp.actors.size(), doors.size(), int(inf["pairs"])])
	for a: Array in bp.actors:
		print("   actor %s yaw %.2f %s %s" % [(a[0] as Vector3).snapped(Vector3.ONE * 0.01), float(a[1]), a[2], a[3]])
	# детали, что вылезают за след (рамку NewShops2.frame) — как их считает Bp.footprint
	if NewShops2.covers(t) and not tn.contains(":old"):
		var fr: Array = NewShops2.frame(t, SizeLadder.OLD_LOT.get(t, Vector2.ZERO) if tn.contains(":fit") else Vector2.ZERO)
		var fz := bp.front_z()
		for p: Array in bp.parts:
			var nm: String = p[0]
			var skip := false
			for w in Bp.NONSOLID:
				if nm.contains(w):
					skip = true
			if skip:
				continue
			var box: AABB = (p[1] as Transform3D) * Bp.model_aabb(nm)
			if box.position.y > 1.6:
				continue
			if box.position.z > fz - 0.05 and box.size.z < 1.0 and box.size.x < 1.6:
				continue
			var lo := Vector2(box.position.x, box.position.z)
			var hi := Vector2(box.end.x, box.end.z)
			if lo.x < float(fr[0]) - 0.03 or hi.x > float(fr[1]) + 0.03 or lo.y < float(fr[2]) - 0.03 or hi.y > float(fr[3]) + 0.03:
				print("   OUT %s %s .. %s" % [nm, lo.snapped(Vector2.ONE * 0.01), hi.snapped(Vector2.ONE * 0.01)])


func _tris(nm: String) -> int:
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
			var arr := m.surface_get_arrays(s)
			var idx = arr[Mesh.ARRAY_INDEX]
			if idx != null and (idx as PackedInt32Array).size() > 0:
				t += (idx as PackedInt32Array).size() / 3
			else:
				t += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	if n:
		n.free()
	_tc[nm] = t
	return t
