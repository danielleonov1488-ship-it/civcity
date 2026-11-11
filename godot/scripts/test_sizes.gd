extends SceneTree
## Размеры построек (след на земле и высота) — для заданий на новые модели. Без окна:
##   bash tools/godot.sh --headless --path godot --script res://scripts/test_sizes.gd
func _init() -> void:
	for t in ["house_pleb", "house_artisan", "house_patrician", "colosseum", "circus_fl"]:
		for tier in ([1, 2, 3] if t.begins_with("house") else [0]):
			var bp: Bp = Catalog.make(t, tier, 0, 0)
			var mn := Vector2(1e9, 1e9)
			var mx := Vector2(-1e9, -1e9)
			for r in bp.footprint(true):
				var rr: Rect2 = r if r is Rect2 else Rect2()
				mn = mn.min(rr.position)
				mx = mx.max(rr.end)
			print("SIZE ", t, " tier ", tier, " foot ", snapped(mx - mn, Vector2(0.01, 0.01)), " top ", snappedf(bp.top_y(), 0.01), " door ", bp.door)
	quit()
