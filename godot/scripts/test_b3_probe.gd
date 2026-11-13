extends SceneTree
## Замер следов (batch 3: станция, бани, гостиница, дом префекта): прямоугольник следа в осях постройки, площадь, верх,
## деталей, огней — по типам и уровням (центр — по уровню города).
##   bash .work/py/gpu_run.sh --headless --script res://scripts/test_b3_probe.gd -- [types=center,baths,mansio,prefect] [tiers=0,3,6,7]
##        [old=1 — как из старого сохранения (Catalog.fit)] [newciv2=0 — прежние сборки]
func _init() -> void:
	var types := "center,baths,mansio,prefect".split(",")
	var tiers := [0, 1, 2, 3, 4, 5, 6, 7]
	var old := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("types="):
			types = a.trim_prefix("types=").split(",")
		elif a.begins_with("tiers="):
			tiers = []
			for t in a.trim_prefix("tiers=").split(","):
				tiers.append(int(t))
		elif a == "old=1":
			old = true
		elif a == "newciv2=0":
			NewCivic2.ON = {}
	for t in types:
		var ts: Array = tiers if t == "center" else [1]
		for tier: int in ts:
			var b := Catalog.make(t, tier, 0, 0, false, old)
			var lot := Rect2()
			var first := true
			for r: Rect2 in b.footprint():
				lot = r if first else lot.merge(r)
				first = false
			var top := 0.0
			for p: Array in b.parts:
				if String(p[0]).begins_with("#"):
					continue
				var bx: AABB = (p[1] as Transform3D) * Bp.model_aabb(String(p[0]))
				top = maxf(top, bx.end.y)
			if NewCivic2.covers(t):
				# детали, что выходят за свой след (NewCivic2.FULL / OLD_RECT) больше чем на 2 см
				var R: Array = NewCivic2.rect_of(t, old and SizeLadder.OLD_LOT.has(t))
				var K := Catalog.scale_of(t)
				for r: Rect2 in b.footprint():
					if r.position.x < float(R[0]) - 0.02 or r.end.x > float(R[1]) + 0.02 or r.position.y < float(R[2]) - 0.02 or r.end.y > float(R[3]) + 0.02:
						for p: Array in b.parts:
							var bx: AABB = (p[1] as Transform3D) * Bp.model_aabb(String(p[0]))
							if is_equal_approx(bx.position.x, r.position.x) and is_equal_approx(bx.position.z, r.position.y):
								print("B3OVER %s %s rect x %.2f..%.2f z %.2f..%.2f" % [t, p[0], r.position.x, r.end.x, r.position.y, r.end.y])
								break
			print("B3SIZE %-8s tier %d old=%s rect x %.2f..%.2f z %.2f..%.2f  lot %.2f x %.2f = %.1f m2  top %.2f  parts %d lights %d door %s" % [
				t, tier, str(old), lot.position.x, lot.end.x, lot.position.y, lot.end.y, lot.size.x, lot.size.y, lot.size.x * lot.size.y, top,
				b.parts.size(), b.lights.size(), str(b.door)])
	quit()
