extends SceneTree
## Габариты деталей Synty для сборок NewShops2 (родные метры), без окна:
##   bash .work/py/gpu_run.sh --headless --script res://scripts/test_shops2_aabb.gd -- names=a,b,…


func _initialize() -> void:
	var names: Array = []
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "names":
			names = Array(kv[1].split(","))
	for nm: String in names:
		var bx := Bp.model_aabb(nm)
		print("AABB %-36s pos %s size %s" % [nm, bx.position.snapped(Vector3.ONE * 0.01), bx.size.snapped(Vector3.ONE * 0.01)])
	print("AABB DONE")
	quit()
