extends SceneTree
## Замер створок и проёмов дверей Synty (справка для scripts/doors.gd): AABB моделей и проёмы стен.
## Запуск: bash .work/py/gpu_run.sh --headless --script res://scripts/test_doors_probe.gd


func _init() -> void:
	for nm in ["SM_Bld_Door_01", "SM_Bld_Door_02", "SM_Bld_Door_03", "SM_Bld_Door_04", "SM_Bld_Door_05", "SM_Bld_Door_Half_01", "SM_Bld_Door_Half_02", "SM_Bld_Door_Half_03",
			"SM_Bld_Door_Half_04", "SM_Bld_Door_Half_05", "SM_Bld_Door_Large_01", "SM_Bld_Door_Large_02", "SM_Bld_Door_Large_Half_01", "SM_Bld_Door_Large_Half_02",
			"SM_Bld_Door_Large_Half_03", "SM_Bld_Door_Large_Half_04", "SM_Bld_Door_Large_Half_05", "SM_Bld_Base_Door_01", "SM_Bld_Base_Door_Large_01"]:
		print("AABB ", nm, " ", Synty.has(nm), " ", Bp.model_aabb(nm))
	for nm in ["SM_Bld_Wall_Door_01", "SM_Bld_Wall_Door_02", "SM_Bld_Wall_Door_03", "SM_Bld_Wall_Door_04", "SM_Bld_Wall_Door_Double_01", "SM_Bld_Wall_Door_Double_02",
			"SM_Bld_Wall_Door_Double_03", "SM_Bld_Wall_Door_Double_Large_01", "SM_Bld_Wall_Door_Double_Large_02", "SM_Bld_Wall_Door_Large_01", "SM_Bld_Wall_Door_Large_02",
			"SM_Bld_Base_Wall_Door_01", "SM_Bld_Base_Wall_Door_Double_01", "SM_Bld_Base_Wall_Door_Double_Large_01", "SM_Bld_Base_Wall_Door_Large_01"]:
		print("WALL ", nm, " ", Bp.model_aabb(nm), " holes ", Interiors.holes(nm))
	quit()
