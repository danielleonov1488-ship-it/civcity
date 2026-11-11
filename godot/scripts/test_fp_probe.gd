extends SceneTree
## Габариты постройки по чертежу: след (прямоугольники деталей), точки дыма, вход
##   bash tools/godot.sh --headless --path godot --script res://scripts/test_fp_probe.gd -- types=thermae,forge
func _init() -> void:
	var types := ["thermae"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("types="):
			types = a.substr(6).split(",")
	for t in types:
		var bp := Catalog.make(t, 0, 0, 0)
		var mn := Vector2(INF, INF)
		var mx := Vector2(-INF, -INF)
		for r: Rect2 in bp.footprint():
			mn = mn.min(r.position)
			mx = mx.max(r.end)
		print("FP ", t, " x ", snappedf(mn.x, 0.01), "..", snappedf(mx.x, 0.01), " z ", snappedf(mn.y, 0.01), "..", snappedf(mx.y, 0.01),
			" smoke ", bp.smoke, " door ", bp.door, " top ", snappedf(bp.top_y(), 0.01))
	quit()
