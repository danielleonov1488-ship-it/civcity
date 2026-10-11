class_name SyntyTemple
extends RefCounted
## Римский храм из деталей Synty: подиум со ступенями спереди, колоннада (6 колонн по фасаду),
## антаблемент, двускатная черепичная крыша с фронтоном, внутри — целла с большой дверью.
## Строится в «родном» масштабе Synty (колонны 6 м), потом масштабируется. Фасад смотрит на +Z,
## начало координат — середина передней кромки подиума.

const COLS := 6          # колонн по фасаду (шаг 2,5 м → ширина 12,5 м)
const DEPTH_BAYS := 6    # шагов колонн вглубь
const STEP := 2.5
const POD := 1.5         # высота подиума
const COL_H := 6.0

var root := Node3D.new()
var batch: SyntyBatch = null
var place := Transform3D.IDENTITY
var marble: Material


func put(name: String, pos: Vector3, yaw: float) -> void:
	if batch:
		batch.add(name, place * Transform3D(Basis(Vector3.UP, yaw), pos))
		return
	var n := Synty.make(name)
	n.position = pos
	n.rotation.y = yaw
	root.add_child(n)


func box(lo: Vector3, hi: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = hi - lo
	mi.mesh = bm
	mi.material_override = marble
	mi.transform = place * Transform3D(Basis.IDENTITY, (lo + hi) / 2.0) if batch else Transform3D(Basis.IDENTITY, (lo + hi) / 2.0)
	extra.append(mi)
	if not batch:
		root.add_child(mi)


var extra: Array[MeshInstance3D] = []


func build() -> Node3D:
	marble = Synty.material("Marble_01")
	var w := (COLS - 1) * STEP           # между осями крайних колонн
	var d := DEPTH_BAYS * STEP
	var hw := w / 2.0 + 1.0
	# подиум: мраморная платформа, спереди — лестница во всю ширину
	box(Vector3(-hw, 0, -d - 1.0), Vector3(hw, POD, -STEP * 1.2))
	var nst := int(ceil(hw * 2 / STEP))
	for i in nst:
		put("SM_Bld_Stairs_01", Vector3(-hw + i * STEP, 0, 0), 0.0)
	# колоннада: фасад, бока, зад
	var zc0 := -STEP * 1.6
	for i in COLS:
		var x := -w / 2.0 + i * STEP
		put("SM_Bld_Pillar_Large_01", Vector3(x, POD, zc0), 0.0)
		put("SM_Bld_Pillar_Large_01", Vector3(x, POD, zc0 - d + STEP), 0.0)
	for j in range(1, DEPTH_BAYS - 1):
		for x: float in [-w / 2.0, w / 2.0]:
			put("SM_Bld_Pillar_Large_01", Vector3(x, POD, zc0 - j * STEP), 0.0)
	# целла: стены внутри колоннады, большая дверь по оси
	var cw := w - STEP * 2
	var cz0 := zc0 - STEP
	var cz1 := zc0 - d + STEP * 2
	for i in int(cw / STEP):
		var x := -cw / 2.0 + i * STEP
		var front := "SM_Bld_Wall_Door_Double_Large_01" if i == int(cw / STEP) / 2 - (1 if int(cw / STEP) % 2 == 0 else 0) else "SM_Bld_Wall_01"
		put(front, Vector3(x, POD, cz0), 0.0)
		put("SM_Bld_Wall_01", Vector3(x, POD + 3.0, cz0), 0.0)
		put("SM_Bld_Wall_01", Vector3(x + STEP, POD, cz1), PI)
		put("SM_Bld_Wall_01", Vector3(x + STEP, POD + 3.0, cz1), PI)
	for j in int((cz0 - cz1) / STEP):
		for f in 2:
			put("SM_Bld_Wall_01", Vector3(cw / 2.0, POD + f * 3.0, cz0 - j * STEP), PI / 2)
			put("SM_Bld_Wall_01", Vector3(-cw / 2.0, POD + f * 3.0, cz0 - (j + 1) * STEP), -PI / 2)
	# антаблемент над колоннами — фасад, зад и бока
	var ye := POD + COL_H + 0.48
	var zf := zc0 + 0.4
	var zb := zc0 - d + STEP - 0.4
	var span := w + 0.8
	_trim_run(Vector3(-span / 2.0, ye, zf), Vector3(1, 0, 0), span)
	_trim_run(Vector3(span / 2.0, ye, zb), Vector3(-1, 0, 0), span)
	_trim_run(Vector3(span / 2.0, ye, zf), Vector3(0, 0, -1), zf - zb)
	_trim_run(Vector3(-span / 2.0, ye, zb), Vector3(0, 0, 1), zf - zb)
	# крыша: два ската вдоль оси храма (конёк по оси Z), пластины по 7,5 м
	var eave := ye + 0.48
	var half := span / 2.0
	var k := half / 7.5            # скаты подгоняем по ширине
	var len := zf - zb + 0.6
	var n := int(ceil(len / 7.5))
	for i in n:
		var z := zb - 0.3 + i * 7.5
		_roof("SM_Bld_Roof_Straight_Thin_Large_01", Vector3(-half, eave, z), -PI / 2, k)
		_roof("SM_Bld_Roof_Straight_Thin_Large_01", Vector3(half, eave, z + 7.5), PI / 2, k)
	# фронтон спереди и сзади
	for zz: float in [zf, zb]:
		_roof("SM_Bld_Roof_Side_Large_01", Vector3(-half, eave, zz), -PI / 2, k)
		_roof("SM_Bld_Roof_Side_Large_01", Vector3(half, eave, zz), PI / 2, k)
	return root


## Полоса антаблемента от точки a в направлении dir длиной len (детали по 7,5 и 2,5 м)
func _trim_run(a: Vector3, dir: Vector3, len: float) -> void:
	var yaw := atan2(-dir.z, dir.x)
	var t := 0.0
	while t < len - 0.1:
		var piece := "SM_Bld_Trim_Large_01" if len - t >= 7.5 else "SM_Bld_Trim_Large_Single_01"
		put(piece, a + dir * t, yaw)
		t += 7.5 if piece == "SM_Bld_Trim_Large_01" else 2.5


func _roof(name: String, pos: Vector3, yaw: float, k: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw).scaled_local(Vector3(1.0, k, k)), pos)
	if batch:
		batch.add(name, place * xf)
		return
	var nd := Synty.make(name)
	nd.transform = xf
	root.add_child(nd)
