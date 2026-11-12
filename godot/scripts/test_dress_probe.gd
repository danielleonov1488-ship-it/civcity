extends SceneTree
## Проверка наполнения стен (CatDress) без окна: сколько деталей добавил проход у домов и лавок пробной улицы
## и каких. Запуск: bash .work/py/gpu_run.sh --headless --script res://scripts/test_dress_probe.gd


func _init() -> void:
	# norms=, names=, cloth=1, aabb= — только справки (можно несколько сразу), без замера улицы
	var only := false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("norms="):
			# листья «наизнанку»: у скольких треугольников нормаль вершин против лица (по обходу) и куда они смотрят
			# (+Z модели — от стены наружу, как ставит CatDress)
			for nm in a.substr(6).split(","):
				_norms(nm)
			only = true
		if a.begins_with("names="):
			for nm in a.substr(6).split(","):
				print("TRI ", nm, " ", _tris(nm))
			only = true
		if a == "cloth=1":
			# цвета полотен CatShops.CLOTH на навесе Synty (по UV его вершин в атласе): частые цвета — для своих навесов
			for i in CatShops.CLOTH.size():
				var n := Synty.make("SM_Prop_Banner_Roof_01", CatShops._cloth(i))
				var hist := {}
				for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
					var mat := mi.get_surface_override_material(0) as StandardMaterial3D
					var img := Image.load_from_file(ProjectSettings.globalize_path(Synty._tex_path(str(mat.get_meta("alb", "")))))
					for uv: Vector2 in mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]:
						var px := Vector2i(clampi(int(uv.x * img.get_width()), 0, img.get_width() - 1), clampi(int(uv.y * img.get_height()), 0, img.get_height() - 1))
						var h := img.get_pixelv(px).to_html(false)
						hist[h] = int(hist.get(h, 0)) + 1
				n.free()
				var ks := hist.keys()
				ks.sort_custom(func(x, y): return int(hist[x]) > int(hist[y]))
				var s := ""
				for k in ks.slice(0, 4):
					s += "%s×%d " % [k, hist[k]]
				print("CLOTH %d %s: %s" % [i, CatShops.CLOTH[i], s])
			only = true
		if a.begins_with("aabb="):
			# габарит и треугольники моделей (подбор вещей): aabb=SM_Prop_Plinth_*,SM_Prop_Table_01
			for pat in a.substr(5).split(","):
				var list: Array = Synty.names(pat.trim_suffix("*")) if pat.ends_with("*") else [pat]
				for nm: String in list:
					var bx := Bp.model_aabb(nm)
					print("AABB %s pos %s size %s tris %d" % [nm, bx.position.snapped(Vector3.ONE * 0.01), bx.size.snapped(Vector3.ONE * 0.01), _tris(nm)])
			only = true
	if only:
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
		# ящики цветов (и свои, и строителей дома): сколько их и треугольников
		var nbox := 0
		var tbox := 0
		for i in b.parts.size():
			var pn := String(b.parts[i][0])
			if pn.begins_with("SM_Prop_FlowerBed") or pn.begins_with("#dress:fbox"):
				nbox += 1
				tbox += _tris(pn)
				if OS.get_cmdline_user_args().has("boxes=%d" % list.find(e)):
					var bt: Transform3D = b.parts[i][1]
					print("  BOX %s at %s s %s free=%s" % [pn, bt.origin.snapped(Vector3.ONE * 0.01), bt.basis.get_scale().snapped(Vector3.ONE * 0.01), b.free_parts.has(i)])
		print("BOXES %s t%d v%d: ящиков %d, треугольников %d" % [e[0], e[1], e[2], nbox, tbox])
		if OS.get_cmdline_user_args().has("top=1"):
			# что тяжелее всего в доме целиком (по имени детали): треугольники × сколько раз
			var by := {}
			for i in b.parts.size():
				var pn := String(b.parts[i][0])
				by[pn] = int(by.get(pn, 0)) + _tris(pn)
			var ks := by.keys()
			ks.sort_custom(func(a, c): return int(by[a]) > int(by[c]))
			var s2 := ""
			for k in ks.slice(0, 10):
				s2 += "%s=%d " % [String(k).trim_prefix("SM_"), by[k]]
			print("  TOP ", s2)
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


## Нормали модели nm: по каждому треугольнику — лицо по обходу (в Godot лицевая сторона — по часовой) и средняя
## нормаль вершин; печатает доли: нормаль против лица, нормаль к +Z, лицо к +Z (по поверхностям)
static func _norms(nm: String) -> void:
	var n := Synty.make(nm)
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var rel := Citizen._rel(mi, n)
		for s in mi.mesh.get_surface_count():
			var ia: Array = mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = ia[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = ia[Mesh.ARRAY_NORMAL]
			var idx = ia[Mesh.ARRAY_INDEX]
			var tri := []
			if idx != null and idx.size() > 0:
				tri = Array(idx)
			else:
				tri = range(vs.size())
			var cnt := 0
			var against := 0
			var nz := 0
			var gz := 0
			for t in range(0, tri.size(), 3):
				var a := rel * vs[tri[t]]
				var b2 := rel * vs[tri[t + 1]]
				var c := rel * vs[tri[t + 2]]
				var g := -(b2 - a).cross(c - a)
				if g.length() < 1e-9:
					continue
				g = g.normalized()
				var vn := (rel.basis * (ns[tri[t]] + ns[tri[t + 1]] + ns[tri[t + 2]])).normalized()
				cnt += 1
				if g.dot(vn) < 0.0:
					against += 1
				if vn.z > 0.0:
					nz += 1
				if g.z > 0.0:
					gz += 1
			var mat := mi.get_surface_override_material(s)
			var slot := String(mat.resource_name) if mat else ""
			if mat is StandardMaterial3D:
				slot = "%s cull=%d alb=%s" % [slot, (mat as StandardMaterial3D).cull_mode, str(mat.get_meta("alb", ""))]
			print("NORM %s/%s s%d: треуг %d, нормаль против лица %d%%, нормаль к +Z %d%%, лицо к +Z %d%% [%s]" % [nm, mi.name, s, cnt,
				against * 100 / maxi(1, cnt), nz * 100 / maxi(1, cnt), gz * 100 / maxi(1, cnt), slot])
	n.free()
