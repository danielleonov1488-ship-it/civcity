extends SceneTree
## Проверки лавок (NewShops):
##  - names=… — ключи групп деталей у зданий волны 5b (ludus, venus, thermae, pharos, circus_fl): имена и раскраски;
##  - stairs=1 — нет ли у лавок (17 типов × 10 цветов) лестниц, стремянок, ступеней на крыше (владелец: «рандомные лестницы»)
##   bash .work/py/gpu_run.sh --headless --script res://scripts/test_shops1_probe.gd -- names=SM_Prop_Pots_Hanging_01,…
##   bash .work/py/gpu_run.sh --headless --script res://scripts/test_shops1_probe.gd -- stairs=1
func _init() -> void:
	var names := PackedStringArray()
	var stairs := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("names="):
			names = a.trim_prefix("names=").split(",")
		if a == "stairs=1":
			stairs = true
	if stairs:
		var bad := 0
		for t: String in NewShops.TYPES:
			for col in 10:
				var b := Catalog.make(t, 1, 0, col)
				for p: Array in b.parts:
					var nm := String(p[0])
					if nm.contains("Stair") or nm.contains("Ladder") or nm.contains("Steps"):
						var bx: AABB = (p[1] as Transform3D) * Bp.model_aabb(nm)
						print("STAIR %s c%d %s y %.2f..%.2f" % [t, col, nm, bx.position.y, bx.end.y])
						bad += 1
		print("STAIRS DONE found=%d" % bad)
		quit()
		return
	var seen := {}
	for t: String in ["ludus", "venus", "thermae", "pharos", "circus_fl"]:
		var b := Catalog.make(t, 1, 0, 0)
		for p: Array in b.parts:
			var nm := String(p[0])
			if not names.has(nm):
				continue
			var rm: Dictionary = p[2]
			var sp := Parts._split(nm, rm)
			var key := "%s | %s | split=%s" % [nm, str(rm), str(sp.slice(1)) if not sp.is_empty() else "-"]
			if not seen.has(key):
				seen[key] = true
				print("KEY %s %s" % [t, key])
	quit()
