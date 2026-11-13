class_name CatMeadow
extends RefCounted
## Украшения из набора Synty Meadow Forest (13.11): ветряная мельница (владелец: «теперь у нас и мельницы»).
## У римлян мельницы были водяные — эта просто для красоты в полях. Крылья крутятся (shaders/meadow_spin.gdshader).


static func windmill(b: Bp, lk: int) -> void:
	b.door = Vector3(0, 0, 3.4)
	var yaw := 0.0
	b.add("M:SM_Bld_Windmill_0%d" % (1 + lk), Vector3.ZERO, yaw, 0.72)
	# у подножия — мешки с мукой и зерном, груда камней, трава
	b.add("SM_Prop_Sack_0%d" % (3 + b.rng.randi() % 3), Vector3(1.6, 0, 1.9), b.rng.randf() * TAU, 0.9)
	b.add("SM_Prop_Sack_0%d" % (3 + b.rng.randi() % 3), Vector3(1.95, 0, 1.55), b.rng.randf() * TAU, 0.85)
	b.add("M:SM_Env_Rock_Small_Pile_0%d" % (1 + b.rng.randi() % 2), Vector3(-1.9, 0, 1.6), b.rng.randf() * TAU, 1.4)
	b.add("M:SM_Env_Grass_Tall_Clump_0%d" % (1 + b.rng.randi() % 5), Vector3(-1.4, 0, -1.8), b.rng.randf() * TAU, 0.8)
	b.add("M:SM_Env_Grass_Tall_Clump_0%d" % (1 + b.rng.randi() % 5), Vector3(1.7, 0, -1.6), b.rng.randf() * TAU, 0.7)
