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
		var b := Catalog.make(t, 1, 0, 0, false, fit_on)
		var lot := Rect2()
		var first := true
		for r: Rect2 in b.footprint():
			lot = r if first else lot.merge(r)
			first = false
		var top := 0.0
		for p: Array in b.parts:
			var bx: AABB = (p[1] as Transform3D) * Bp.model_aabb(String(p[0]))
			top = maxf(top, bx.end.y)
		print("LOT %-10s x %.2f .. %.2f  z %.2f .. %.2f  (%.2f x %.2f = %.1f m2)  top %.2f  door %s  front %.2f  parts %d  lights %d" % [t,
			lot.position.x, lot.end.x, lot.position.y, lot.end.y, lot.size.x, lot.size.y, lot.size.x * lot.size.y, top, b.door, b.row_front(), b.parts.size(), b.lights.size()])
	quit()
