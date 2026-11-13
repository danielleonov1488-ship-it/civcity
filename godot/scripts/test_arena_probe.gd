extends SceneTree
## Проба для новых амфитеатра и цирка: габариты деталей Synty, прежние следы и цена в треугольниках
## (NewArena.ON = false — прежние, true — новые; pilot=… не нужен: пилот — в истории git).
##   bash .work/py/gpu_run.sh --headless --script res://scripts/test_arena_probe.gd -- [names=A,B,…]

var _tris := {}


var pilot := ""


func _init() -> void:
	var names := []
	for a: String in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv[0] == "names":
			names = Array(kv[1].split(","))
		elif kv[0] == "pilot":
			pilot = kv[1]
	_run.call_deferred(names)


func _rect(bp: Bp) -> Rect2:
	var r := Rect2()
	var first := true
	for rc: Rect2 in bp.footprint():
		r = rc if first else r.merge(rc)
		first = false
	return r


func _tri(nm: String) -> int:
	if _tris.has(nm):
		return _tris[nm]
	var t := 12
	if not nm.begins_with("#"):
		var n := Synty.make(nm)
		t = 0
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh:
				for s in mi.mesh.get_surface_count():
					var arr := mi.mesh.surface_get_arrays(s)
					var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
					t += idx.size() / 3 if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		n.free()
	elif nm.begins_with("#d2_"):
		var m := CatDecor2.kit_mesh(nm)
		t = 0
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			t += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if arr[Mesh.ARRAY_INDEX] != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	_tris[nm] = t
	return t


func _run(names: Array) -> void:
	for nm: String in names:
		var bx := Bp.model_aabb(nm)
		print("AABB %-40s pos %s size %s" % [nm, bx.position, bx.size])
	for on: bool in [false, true]:
		NewArena.ON = on
		Catalog._cache.clear()
		for t: String in ["colosseum", "circus_fl"]:
			for old: bool in ([false, true] if on else [false]):
				var bp: Bp
				if old:
					bp = Catalog.make(t, 0, 0, 0, false, true)
				else:
					bp = Catalog.make(t, 0, 0, 0)
				var r := _rect(bp)
				var tri := 0
				var kinds := {}
				for p in bp.parts:
					tri += _tri(String(p[0]))
					kinds[p[0]] = true
				var occ := Rect2()
				var first := true
				for rc: Rect2 in bp.occ_footprint():
					occ = rc if first else occ.merge(rc)
					first = false
				var occ_a := 0.0
				for rc: Rect2 in bp.occ_footprint():
					occ_a += rc.get_area()
				print("LOT new=%s old_lot=%s %-10s rect %s size %.2f x %.2f area %.0f | occ area %.0f | door %s row_front %.2f top %.2f | parts %d kinds %d tris %d lights %d actors %d" % [on, old, t, r, r.size.x, r.size.y, r.get_area(), occ_a, bp.door, bp.row_front(), bp.top_y(), bp.parts.size(), kinds.size(), tri, bp.lights.size(), bp.actors.size()])
	if pilot != "":
		# пилот 13.11 (исходник из git, без имени класса): та же сборка — для сравнения цены
		var scr := GDScript.new()
		scr.source_code = FileAccess.get_file_as_string(pilot)
		scr.reload()
		for t: String in ["colosseum", "circus_fl"]:
			var bp := Bp.new(1)
			scr.call("make", bp, t)
			Catalog._scale(bp, 0.72)
			var r := _rect(bp)
			var tri := 0
			var kinds := {}
			for p in bp.parts:
				tri += _tri(String(p[0]))
				kinds[p[0]] = true
			print("LOT pilot %-10s size %.2f x %.2f area %.0f | top %.2f | parts %d kinds %d tris %d lights %d" % [t, r.size.x, r.size.y, r.get_area(), bp.top_y(), bp.parts.size(), kinds.size(), tri, bp.lights.size()])
	quit()
