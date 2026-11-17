extends SceneTree
## Опись створок по всем постройкам (scripts/doors.gd): сколько проёмов, сколько исправлено.
## Запуск: bash .work/py/gpu_run.sh --headless --script res://scripts/test_doors.gd


func _init() -> void:
	var tot := {}
	for t in Defs.B.keys():
		var kind := String(Defs.B[t].get("kind", ""))
		if kind == "decor" or bool(Defs.B[t].get("hidden", false)):
			continue
		for tier in [1, 3]:
			Catalog.make(t, tier)
			var l: Dictionary = Doors.last
			print("DOORS %-14s tier%d holes=%d ok=%d fixed=%d dbl=%d single=%d replaced=%d added=%d %s" % [t, tier, l["holes"], l["ok"], l["fixed"], l["dbl"], l["single"], l["replaced"], l["added"], ""])
			if tier == 1:
				for k in l:
					if k != "names":
						tot[k] = int(tot.get(k, 0)) + int(l[k])
	print("DOORS TOTAL ", tot)
	quit()
