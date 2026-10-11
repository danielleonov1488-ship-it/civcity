class_name SyntyHouse
extends RefCounted
## Римский дом из модульных деталей Synty Ancient Empire — как в промо Synty.
## Стены по 2,5 м, этажи по 3 м; у дома один цвет штукатурки (подмена текстуры), свой карниз,
## внизу — лавки с черепичными навесами и товаром или дверь, выше — окна, деревянный балкон с цветами,
## плющ, горшки; крыша — двускатная черепичная или плоская терраса с перголой.
## Фасад смотрит на +Z, начало координат — середина основания.
## build(params) → Node3D; после сборки: door (точка у двери), smoke (точки отдушин), size (ширина, глубина)

const M := 2.5
const FL := 3.0
const STUCCO := ["Stucco_White_01", "Stucco_Orange_01", "Stucco_Red_01", "Stucco_Blue_01", "Stucco_Coloured_01", "Stucco_White_01", "Stucco_Orange_01"]
const ALL_STUCCO := ["Stucco_White_01", "Stucco_Orange_01", "Stucco_Red_01", "Stucco_Blue_01"]
const WINDOWS := ["SM_Bld_Wall_Window_01", "SM_Bld_Wall_Window_02", "SM_Bld_Wall_Window_03", "SM_Bld_Wall_Window_04", "SM_Bld_Wall_Window_05", "SM_Bld_Wall_Window_06"]
const DOORS := ["SM_Bld_Wall_Door_01", "SM_Bld_Wall_Door_02", "SM_Bld_Wall_Door_03"]
const TRIMS := ["SM_Bld_Trim_01", "SM_Bld_Trim_02", "SM_Bld_Trim_03", "SM_Bld_Trim_04"]

var root := Node3D.new()
var rng := RandomNumberGenerator.new()
var batch: SyntyBatch = null      # если задано — детали идут в общую пачку (по месту place), без отдельных узлов
var place := Transform3D.IDENTITY
var remap := {}
var door := Vector3.ZERO
var smoke: Array[Vector3] = []
var size := Vector2.ZERO


func put(name: String, pos: Vector3, yaw: float, own_colors := false) -> Node3D:
	if batch:
		batch.add(name, place * Transform3D(Basis(Vector3.UP, yaw), pos), {} if own_colors else remap)
		return null
	var n := Synty.make(name, {} if own_colors else remap)
	n.position = pos
	n.rotation.y = yaw
	root.add_child(n)
	return n


## Точка и поворот на стене: сторона side (0 — фасад +Z, 1 — +X, 2 — −Z, 3 — −X), модуль i, высота y, отступ наружу out
func at(w: int, d: int, side: int, i: float, y: float, out := 0.0) -> Array:
	var hw := w * M / 2.0
	var hd := d * M / 2.0
	match side:
		0: return [Vector3(-hw + i * M, y, hd + out), 0.0]
		1: return [Vector3(hw + out, y, hd - i * M), PI / 2]
		2: return [Vector3(hw - i * M, y, -hd - out), PI]
		_: return [Vector3(-hw - out, y, -hd + i * M), -PI / 2]


func on_wall(name: String, w: int, d: int, side: int, i: float, y: float, out := 0.0, own := false) -> Node3D:
	var a := at(w, d, side, i, y, out)
	return put(name, a[0], a[1], own)


## p: w (1–3 модуля), d (2), floors (1–4), shop (лавки внизу), roof ("gable" | "flat"), balcony, seed
func build(p: Dictionary) -> Node3D:
	rng.seed = p.get("seed", 1)
	var w: int = p.get("w", 2)
	var d: int = p.get("d", 2)
	var floors: int = p.get("floors", 2)
	var shop: bool = p.get("shop", false)
	var roof: String = p.get("roof", "gable")
	size = Vector2(w * M, d * M)
	# цвет дома: все варианты штукатурки → один; первый этаж иногда с узором
	var col: String = p.get("stucco", STUCCO[rng.randi() % STUCCO.size()])
	for s in ALL_STUCCO:
		remap[s] = col
	var trim: String = TRIMS[rng.randi() % TRIMS.size()]
	var door_i := rng.randi() % w
	var hw := w * M / 2.0
	var hd := d * M / 2.0
	var win: String = WINDOWS[rng.randi() % WINDOWS.size()]
	var win2: String = WINDOWS[rng.randi() % WINDOWS.size()]
	for f in floors:
		var y := f * FL
		for side in 4:
			var n := w if side % 2 == 0 else d
			for i in n:
				var nm := "SM_Bld_Wall_01"
				if f == 0 and side == 0:
					if i == door_i:
						nm = DOORS[rng.randi() % DOORS.size()]
					elif shop:
						nm = "SM_Bld_Wall_Door_Large_01"
					else:
						nm = win2
				elif rng.randf() < (0.8 if side == 0 else 0.5):
					nm = win if f > 0 else win2
				on_wall(nm, w, d, side, i, y)
				if f < floors - 1 or roof == "gable":
					on_wall(trim, w, d, side, i, y + FL - 0.33)
				if f == 0:
					on_wall("SM_Bld_Trim_05", w, d, side, i, 0.0)
				# лавка: черепичный навес над проёмом и товар у входа
				if f == 0 and side == 0 and shop and i != door_i:
					on_wall("SM_Prop_Overhang_01", w, d, side, i + 0.5, 2.75, 0.12, true)
					_goods(at(w, d, side, i + 0.5, 0.0, 0.7))
		# балки перекрытия торчат из фасада у части домов
		if f > 0 and p.get("beams", false):
			for i in w:
				on_wall("SM_Bld_Wall_Beam_Detail_01", w, d, 0, i, y - 0.15, 0.11)
	# дверь в проёме
	var da := at(w, d, 0, door_i + 0.3, 0.0, -0.02)
	put("SM_Bld_Door_0%d" % (1 + rng.randi() % 5), da[0], da[1], true)
	door = (at(w, d, 0, door_i + 0.5, 0.0, 0.9)[0] as Vector3)
	# горшки с цветами у двери, висячие кашпо, плющ
	if rng.randf() < 0.7:
		var pa := at(w, d, 0, door_i + 0.12, 0.0, 0.45)
		put("SM_Prop_FlowerPot_Fancy_01", pa[0], pa[1], true)
	if floors >= 2 and rng.randf() < 0.6:
		var bi := rng.randi() % w
		var ba := at(w, d, 0, bi + 0.5, FL, 0.11)
		put("SM_Bld_Balcony_01", ba[0], ba[1], true)
		var fa := at(w, d, 0, bi + 0.2, FL, 0.75)
		put("SM_Prop_FlowerPot_Fancy_01", fa[0], fa[1], true)
	if rng.randf() < 0.55:
		var side: int = [0, 1, 3][rng.randi() % 3]
		var n := w if side % 2 == 0 else d
		var ia := at(w, d, side, rng.randi() % n + 0.5, rng.randf_range(1.6, maxf(1.8, floors * FL - 1.4)), 0.12)
		put("SM_Env_Ivy_Flowers_0%d" % (1 + rng.randi() % 9), ia[0], ia[1], true)
	if rng.randf() < 0.5:
		var ha := at(w, d, 0, door_i + 0.9, 2.55, 0.35)
		put("SM_Prop_Pots_Hanging_0%d" % (1 + rng.randi() % 2), ha[0], ha[1], true)
	# угловые столбы
	for f in floors:
		for c: Array in [[Vector3(-hw, 0, hd), 0.0], [Vector3(hw, 0, hd), PI / 2], [Vector3(hw, 0, -hd), PI], [Vector3(-hw, 0, -hd), -PI / 2]]:
			put("SM_Bld_Wall_End_01", (c[0] as Vector3) + Vector3(0, f * FL, 0), c[1])
	# тёмное нутро: в проёмы лавок и окна не просвечивает улица с другой стороны
	_interior(w, d, floors)
	var top := floors * FL
	if roof == "flat":
		_flat_roof(w, d, top)
	else:
		_gable_roof(w, d, top)
	return root


func _gable_roof(w: int, d: int, top: float) -> void:
	var hw := w * M / 2.0
	var hd := d * M / 2.0
	for i in w:
		put("SM_Bld_Roof_Base_Straight_01", Vector3(-hw + i * M, top, hd), 0.0)
		put("SM_Bld_Roof_Base_Straight_01", Vector3(hw - i * M, top, -hd), PI)
		put("SM_Bld_Roof_Edge_Straight_01", Vector3(-hw + i * M, top, hd), 0.0)
		put("SM_Bld_Roof_Edge_Straight_01", Vector3(hw - i * M, top, -hd), PI)
	put("SM_Bld_Roof_Base_Straight_Side_01", Vector3(-hw, top, hd), 0.0)
	put("SM_Bld_Roof_Base_Straight_Side_01", Vector3(hw, top, -hd), PI)
	put("SM_Bld_Roof_Base_Straight_Side_01", Vector3(hw, top, hd), 0.0)
	put("SM_Bld_Roof_Base_Straight_Side_01", Vector3(-hw, top, -hd), PI)
	# фигурки-акротерии на концах конька
	var ridge := top + 0.75 * d / 2.0 * 0.5 + 0.35
	if rng.randf() < 0.6:
		var tp := "SM_Bld_Roof_Topper_0%d" % (1 + rng.randi() % 6)
		put(tp, Vector3(-hw + 0.1, ridge, 0), 0.0, true)
		put(tp, Vector3(hw - 0.1, ridge, 0), 0.0, true)
	smoke.append(Vector3(hw * 0.4, ridge + 0.2, -0.3))


## Плоская крыша-терраса: плиты, низкий парапет, деревянная пергола с плющом, кадки
func _flat_roof(w: int, d: int, top: float) -> void:
	var hw := w * M / 2.0
	var hd := d * M / 2.0
	for i in w:
		for j in d:
			put("SM_Bld_Roof_Base_Flat_02", Vector3(-hw + i * M, top - 0.68, hd - j * M), 0.0)
	for side in 4:
		var n := w if side % 2 == 0 else d
		for i in n:
			on_wall("SM_Bld_Wall_Balcony_04", w, d, side, i, top)
	if rng.randf() < 0.7:
		put("SM_Bld_Trellis_Roof_01", Vector3(-hw + M, top + 2.2, -hd + M * 0.0), 0.0, true)
		for c: Vector3 in [Vector3(-hw + 0.3, top, -hd + 0.3), Vector3(-hw + M - 0.3, top, -hd + 0.3), Vector3(-hw + 0.3, top, -hd + M - 0.3), Vector3(-hw + M - 0.3, top, -hd + M - 0.3)]:
			put("SM_Bld_Trellis_Pillar_01", c, 0.0, true)
	for k in 2:
		put("SM_Prop_FlowerPot_Fancy_01", Vector3(rng.randf_range(-hw + 0.6, hw - 0.6), top, rng.randf_range(0.2, hd - 0.6)), rng.randf() * TAU, true)
	smoke.append(Vector3(hw * 0.5, top + 0.3, -hd * 0.5))


static var _dark: StandardMaterial3D


func _interior(w: int, d: int, floors: int) -> void:
	if _dark == null:
		_dark = StandardMaterial3D.new()
		_dark.albedo_color = Color("2a2019")
		_dark.roughness = 1.0
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w * M - 0.6, floors * FL - 0.1, d * M - 0.6)
	mi.mesh = bm
	mi.material_override = _dark
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = place * Transform3D(Basis.IDENTITY, Vector3(0, floors * FL / 2.0, 0)) if batch else Transform3D(Basis.IDENTITY, Vector3(0, floors * FL / 2.0, 0))
	interior = mi
	if not batch:
		root.add_child(mi)


var interior: MeshInstance3D = null


## Товар у лавки: корзины, амфоры, мешки, ящики
func _goods(a: Array) -> void:
	var base: Vector3 = a[0]
	var yaw: float = a[1]
	var items := ["SM_Prop_Basket_Set_01", "SM_Prop_Jar_Pile_01", "SM_Prop_Sack_Stack_01", "SM_Prop_Vase_Pile_01", "SM_Prop_Basket_01", "SM_Prop_Jar_01", "SM_Prop_Table_01"]
	for k in 2:
		var nm: String = items[rng.randi() % items.size()]
		if not Synty.has(nm):
			continue
		var off := Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.15, 0.15)).rotated(Vector3.UP, yaw)
		put(nm, base + off, yaw + rng.randf_range(-0.4, 0.4), true)
