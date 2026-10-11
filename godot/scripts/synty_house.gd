class_name SyntyHouse
extends RefCounted
## Дом из модульных деталей Synty Ancient Empire: стены по 2,5 м (окна, двери, балконы), этажи по 3 м,
## карнизы между этажами, угловые столбы, двускатная черепичная крыша. Фасад смотрит на +Z,
## начало координат — середина основания. Цвет штукатурки меняется подменой текстуры стен.

const M := 2.5      # шаг модуля
const FL := 3.0     # высота этажа

var root := Node3D.new()
var rng := RandomNumberGenerator.new()


func put(name: String, pos: Vector3, yaw: float) -> Node3D:
	var n := Synty.make(name)
	n.position = pos
	n.rotation.y = yaw
	root.add_child(n)
	return n


## Стена шириной в модуль: сторона side (0 — фасад +Z, 1 — справа +X, 2 — зад −Z, 3 — слева −X), номер модуля i
func wall(name: String, w: int, d: int, side: int, i: int, y: float) -> Node3D:
	var hw := w * M / 2.0
	var hd := d * M / 2.0
	match side:
		0: return put(name, Vector3(-hw + i * M, y, hd), 0.0)
		1: return put(name, Vector3(hw, y, hd - i * M), PI / 2)
		2: return put(name, Vector3(hw - i * M, y, -hd), PI)
		_: return put(name, Vector3(-hw, y, -hd + i * M), -PI / 2)


func build(w: int, d: int, floors: int, seed_v: int) -> Node3D:
	rng.seed = seed_v
	var windows := ["SM_Bld_Wall_Window_01", "SM_Bld_Wall_Window_02", "SM_Bld_Wall_Window_03", "SM_Bld_Wall_Window_06"]
	var door_i := rng.randi() % w
	for f in floors:
		var y := f * FL
		for side in 4:
			var n := w if side % 2 == 0 else d
			for i in n:
				var nm := "SM_Bld_Wall_01"
				if side == 0 and f == 0 and i == door_i:
					nm = "SM_Bld_Wall_Door_01"
				elif rng.randf() < (0.75 if side == 0 else 0.45):
					nm = windows[rng.randi() % windows.size()]
				wall(nm, w, d, side, i, y)
				# карниз над этажом
				wall("SM_Bld_Trim_02", w, d, side, i, y + FL - 0.33)
				if f == 0:
					wall("SM_Bld_Trim_05", w, d, side, i, 0.0)
	# угловые столбы
	var hw := w * M / 2.0
	var hd := d * M / 2.0
	for f in floors:
		for c: Array in [[Vector3(-hw, 0, hd), 0.0], [Vector3(hw, 0, hd), PI / 2], [Vector3(hw, 0, -hd), PI], [Vector3(-hw, 0, -hd), -PI / 2]]:
			put("SM_Bld_Wall_End_01", (c[0] as Vector3) + Vector3(0, f * FL, 0), c[1])
	# крыша: два ската от карнизов к коньку посередине
	var top := floors * FL
	for i in w:
		put("SM_Bld_Roof_Base_Straight_01", Vector3(-hw + i * M, top, hd), 0.0)
		put("SM_Bld_Roof_Base_Straight_01", Vector3(hw - i * M, top, -hd), PI)
		put("SM_Bld_Roof_Edge_Straight_01", Vector3(-hw + i * M, top, hd), 0.0)
		put("SM_Bld_Roof_Edge_Straight_01", Vector3(hw - i * M, top, -hd), PI)
	# фронтоны по торцам
	put("SM_Bld_Roof_Base_Straight_Side_01", Vector3(-hw, top, hd), 0.0)
	put("SM_Bld_Roof_Base_Straight_Side_01", Vector3(hw, top, -hd), PI)
	put("SM_Bld_Roof_Base_Straight_Side_01", Vector3(hw, top, hd), 0.0)
	put("SM_Bld_Roof_Base_Straight_Side_01", Vector3(-hw, top, -hd), PI)
	return root
