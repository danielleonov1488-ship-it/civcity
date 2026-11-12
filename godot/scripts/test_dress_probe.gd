extends SceneTree
## Проверка наполнения стен (CatDress) без окна: сколько деталей добавил проход у домов и лавок пробной улицы
## и каких. Запуск: bash .work/py/gpu_run.sh --headless --script res://scripts/test_dress_probe.gd


func _init() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("names="):
			for nm in a.substr(6).split(","):
				print("TRI ", nm, " ", _tris(nm))
			quit()
			return
	if OS.get_cmdline_user_args().has("before=1"):
		CatDress.sides_on = false
	var heavy := {}
	var list: Array = (load("res://scripts/test_dress_turn.gd") as GDScript).get_script_constant_map()["LIST"]
	for e: Array in list:
		var b := Catalog.make(e[0], e[1], e[2], e[3])
		var cnt := {}
		for i: int in b.free_parts.keys():
			var nm := String(b.parts[i][0])
			cnt[nm] = int(cnt.get(nm, 0)) + 1
		var keys := cnt.keys()
		keys.sort()
		var s := ""
		for k in keys:
			s += "%s×%d " % [String(k).trim_prefix("SM_"), cnt[k]]
		if OS.get_cmdline_user_args().has("ivy=" + String(e[0])):
			for i in b.parts.size():
				if String(b.parts[i][0]).begins_with("SM_Env_Ivy"):
					var t: Transform3D = b.parts[i][1]
					print("  IVY %s at %s fwd %s det %.2f free=%s" % [b.parts[i][0], t.origin.snapped(Vector3.ONE * 0.01), t.basis.z.snapped(Vector3.ONE * 0.01), t.basis.determinant(), b.free_parts.has(i)])
		if OS.get_cmdline_user_args().has("pos=" + String(e[0])):
			for i: int in b.free_parts.keys():
				var o: Vector3 = (b.parts[i][1] as Transform3D).origin
				print("  POS ", String(b.parts[i][0]).trim_prefix("SM_"), " ", o.snapped(Vector3.ONE * 0.01))
		for a: String in OS.get_cmdline_user_args():
			if a.begins_with("near=") and a.get_slice("=", 1).get_slice(":", 0) == "%d" % list.find(e):
				var xz := a.get_slice(":", 1).split(",")
				var q := Vector2(float(xz[0]), float(xz[1]))
				for i in b.parts.size():
					var o: Vector3 = (b.parts[i][1] as Transform3D).origin
					if Vector2(o.x, o.z).distance_to(q) < 0.9:
						print("  NEAR %d %s %s free=%s" % [i, b.parts[i][0], o.snapped(Vector3.ONE * 0.01), b.free_parts.has(i)])
		var tri_all := 0
		var tri_free := 0
		var kinds := {}
		for i in b.parts.size():
			var t := _tris(String(b.parts[i][0]))
			tri_all += t
			if b.free_parts.has(i):
				tri_free += t
				heavy[String(b.parts[i][0])] = [t, int((heavy.get(String(b.parts[i][0]), [0, 0]) as Array)[1]) + 1]
				kinds[String(b.parts[i][0]) + str(b.parts[i][2])] = true
		print("TRIS %s t%d v%d c%d: всего %d, наполнение %d (%d деталей, %d видов)" % [e[0], e[1], e[2], e[3], tri_all, tri_free, b.free_parts.size(), kinds.size()])
		print("DRESS %s t%d v%d: деталей %d, наполнение %d — %s" % [e[0], e[1], e[2], b.parts.size(), b.free_parts.size(), s])
	var hk := heavy.keys()
	hk.sort_custom(func(a, c): return int(heavy[a][0]) * int(heavy[a][1]) > int(heavy[c][0]) * int(heavy[c][1]))
	for k in hk.slice(0, 30):
		print("HEAVY %s: %d треуг. × %d" % [k, heavy[k][0], heavy[k][1]])
	quit()


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
