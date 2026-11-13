extends SceneTree
## След построек в осях постройки (м): прямоугольник вокруг деталей (x0..x1, z0..z1), высота, вход — для «старого места»
##   bash .work/py/gpu_run.sh --headless --script res://scripts/test_probe_lots.gd -- types=library,thermae [old=1]
func _init() -> void:
	var types := "theatre,odeon,library,thermae".split(",")
	var fit_on := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("types="):
			types = a.trim_prefix("types=").split(",")
		if a == "old=1":
			NewCivic.ON = {}
		if a == "fit=1":
			fit_on = true
	for t in types:
		var col := 0
		for a2 in OS.get_cmdline_user_args():
			if a2.begins_with("color="):
				col = int(a2.trim_prefix("color="))
		var b := Catalog.make(t, 1, 0, col, false, fit_on)
		var lot := Rect2()
		var first := true
		for r: Rect2 in b.footprint():
			lot = r if first else lot.merge(r)
			first = false
		var top := 0.0
		for p: Array in b.parts:
			var bx: AABB = (p[1] as Transform3D) * Bp.model_aabb(String(p[0]))
			top = maxf(top, bx.end.y)
		if OS.get_cmdline_user_args().has("who=1"):
			# какие детали дальше всех по x и z (кто раздвигает след)
			var ext := []
			for pi in b.parts.size():
				var pp: Array = b.parts[pi]
				for r: Rect2 in [_rect_of(b, pi)]:
					if r.size != Vector2.ZERO:
						ext.append([maxf(absf(r.position.x), absf(r.end.x)), String(pp[0]), r])
			ext.sort_custom(func(x, y): return x[0] > y[0])
			for e in ext.slice(0, 6):
				print("WHO %s x %.2f %s %s" % [t, e[0], e[1], e[2]])
		print("LOT %-10s x %.2f .. %.2f  z %.2f .. %.2f  (%.2f x %.2f = %.1f m2)  top %.2f  door %s  front %.2f  parts %d  lights %d" % [t,
			lot.position.x, lot.end.x, lot.position.y, lot.end.y, lot.size.x, lot.size.y, lot.size.x * lot.size.y, top, b.door, b.row_front(), b.parts.size(), b.lights.size()])
	quit()


## Прямоугольник следа одной детали (как Bp.footprint, без пропусков мелочи) — для «кто раздвигает след»
func _rect_of(b: Bp, pi: int) -> Rect2:
	var p: Array = b.parts[pi]
	var nm: String = p[0]
	for w in Bp.NONSOLID:
		if nm.contains(w):
			return Rect2()
	var box := Bp.model_aabb(nm)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var low_y := INF
	for i in 8:
		var q: Vector3 = (p[1] as Transform3D) * box.get_endpoint(i)
		lo = lo.min(Vector2(q.x, q.z))
		hi = hi.max(Vector2(q.x, q.z))
		low_y = minf(low_y, q.y)
	if low_y > 1.6:
		return Rect2()
	return Rect2(lo, hi - lo)
