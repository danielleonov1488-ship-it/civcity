extends SceneTree
## Габариты деталей Synty для новых домов (линия rebuild-houses), без окна:
##   bash .work/py/gpu_run.sh --headless --script res://scripts/test_houses_parts.gd -- names=a,b,…


func _initialize() -> void:
	var names := []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("names="):
			names = Array(a.substr(6).split(","))
	for nm: String in names:
		var bx := Bp.model_aabb(nm)
		var n := Synty.make(nm)
		var t := 0
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				var ia: Array = mi.mesh.surface_get_arrays(s)
				var idx = ia[Mesh.ARRAY_INDEX]
				t += (idx.size() if idx != null and idx.size() > 0 else (ia[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		n.free()
		print("AABB %-36s pos %s size %s tris %d" % [nm, bx.position.snapped(Vector3.ONE * 0.01), bx.size.snapped(Vector3.ONE * 0.01), t])
	print("PARTS DONE")
	quit()
