extends SceneTree
## Место для настенных украшений игрока на стенах домов (WallDecor): размеры украшений и свободные места по стенам
##   bash .work/py/gpu_run.sh --headless --script res://scripts/test_houses_wall.gd


func _initialize() -> void:
	for wt: String in ["wall_lamp", "wall_flowers", "wall_banner", "wall_torch"]:
		print("WRECT %s %s" % [wt, WallDecor.rect_of(wt)])
	for t: String in ["house_pleb", "house_artisan"]:
		for v in 5:
			for col in [0, 3]:
				var bp := Catalog.make(t, 2, v, col)
				var line := []
				for f: Dictionary in WallDecor.faces(bp):
					var n: Vector3 = f["n"]
					var free := []
					for wt: String in ["wall_lamp", "wall_flowers", "wall_banner", "wall_torch"]:
						var rect := WallDecor.rect_of(wt)
						var bd: Rect2 = f["bound"]
						var cnt := 0
						var ys := {}
						var u := bd.position.x
						while u < bd.end.x:
							var y := bd.position.y
							while y < bd.end.y:
								if WallDecor.fits(f, rect, u - rect.position.x, y - rect.position.y, []):
									cnt += 1
									ys[int(y / 1.9)] = true
								y += 0.1
							u += 0.1
						free.append("%s:%d%s" % [wt.substr(5, 3), cnt, str(ys.keys())])
					line.append("n(%.0f,%.0f) %s" % [n.x, n.z, " ".join(free)])
				print("WALL %s v%d c%d | %s" % [t, v, col, " | ".join(line)])
	print("WALL DONE")
	quit()
