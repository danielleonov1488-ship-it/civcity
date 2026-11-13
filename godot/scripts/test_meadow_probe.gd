extends SceneTree
## Проба набора Meadow Forest (без окна): какие узлы и сетки в моделях, сколько вершин, размеры, какие материалы
##   bash .work/py/gpu_run.sh --headless --script res://scripts/test_meadow_probe.gd -- names=SM_Env_Tree_Birch_01,…


func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var names: Array = str(args.get("names", "")).split(",", false)
	if names.is_empty():
		names = Meadow.names("SM_")
	print("MEADOW on=", Meadow.on, " models=", Meadow.names("SM_").size() + Meadow.names("FX_").size())
	for nm0 in names:
		var nm := str(nm0)
		if not nm.begins_with("M:"):
			nm = "M:" + nm
		var n := Meadow.make(nm)
		var verts := 0
		var lines := []
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			var v := 0
			for s in mi.mesh.get_surface_count():
				var arr := mi.mesh.surface_get_arrays(s)
				v += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			verts += v
			var mats := []
			for s in mi.mesh.get_surface_count():
				var m := mi.get_surface_override_material(s)
				mats.append(("S:" + str((m as ShaderMaterial).shader.resource_path.get_file())) if m is ShaderMaterial else ("M:" + str(m.get_meta("alb", "?")) if m else "null"))
			var xf := Citizen._rel(mi, n)
			var a0 := mi.mesh.surface_get_arrays(0)
			var cols = a0[Mesh.ARRAY_COLOR]
			if cols == null:
				lines.append("   (нет цвета вершин)")
			else:
				var hist := {}
				for c: Color in cols:
					var key := "%.1f,%.1f,%.1f" % [c.r, c.g, c.b]
					hist[key] = int(hist.get(key, 0)) + 1
				lines.append("   цвета вершин: " + str(hist).left(300))
			lines.append("   %s v=%d aabb=%s pos=%s mats=%s" % [mi.name, v, str(xf * mi.mesh.get_aabb()), str(xf.origin), str(mats)])
		print("MEADOW %s verts=%d" % [nm, verts])
		for l in lines:
			print(l)
		n.free()
	print("MEADOW unknown slots: ", Synty.unknown.keys())
	quit()
