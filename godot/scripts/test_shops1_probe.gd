extends SceneTree
## Ключи групп деталей у зданий волны 5b (ludus, venus, thermae, pharos, circus_fl): какие имена и раскраски
##   bash .work/py/gpu_run.sh --headless --script res://scripts/test_shops1_probe.gd -- names=SM_Prop_Pots_Hanging_01,…
func _init() -> void:
	var names := PackedStringArray()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("names="):
			names = a.trim_prefix("names=").split(",")
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
