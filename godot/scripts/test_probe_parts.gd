extends SceneTree
## Габариты деталей Synty в родных метрах (для сборки новых зданий): AABB каждой детали
##   bash .work/py/gpu_run.sh --headless --script res://scripts/test_probe_parts.gd -- names=SM_Bld_Wall_01,SM_Prop_Statue_01
func _init() -> void:
	var names := PackedStringArray()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("names="):
			names = a.trim_prefix("names=").split(",")
	for n in names:
		var bx := Bp.model_aabb(n)
		print("AABB %-40s pos (%.2f, %.2f, %.2f)  size (%.2f, %.2f, %.2f)" % [n, bx.position.x, bx.position.y, bx.position.z, bx.size.x, bx.size.y, bx.size.z])
	quit()
