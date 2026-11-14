extends SceneTree
## Прямоугольники следа домов (occ_footprint) прежних и новых — для перестройки в старых городах:
##   bash .work/py/gpu_run.sh --headless --script res://scripts/test_houses_rects.gd


func _initialize() -> void:
	for newv in [false, true]:
		for k: String in NewHouses.TYPES:
			NewHouses.ON[k] = newv
		Catalog._cache.clear()
		for t: String in ["house_pleb", "house_artisan", "house_patrician"]:
			for v in (4 if t == "house_patrician" else 5):
				var bp := Catalog.make(t, 1, v, 0)
				var rs := []
				for r: Rect2 in bp.occ_footprint():
					rs.append("[%.2f..%.2f, %.2f..%.2f]" % [r.position.x, r.end.x, r.position.y, r.end.y])
				print("RECTS %s %s v%d n=%d %s" % ["new" if newv else "old", t, v, rs.size(), " ".join(rs)])
	print("RECTS DONE")
	quit()
