class_name CatShops
extends RefCounted
## Облик построек (Лавки, рынок, развлечения на улице). Чертёж Bp строится в родных размерах Synty;
## Catalog.make потом уменьшает его до «кукольного» масштаба (Catalog.ARCH).
## Лавка — маленький римский дом-мастерская, как в Помпеях и Остии: штукатурка в цвет из палитры, крутая черепица,
## портик на колоннах или полосатый навес, расписной прилавок с товаром своего ремесла, полки в глубине проёма,
## вывеска-знамя, лампы. В сумерках нутро лавки разгорается тёплым светом (#lit), как окна жилых домов.
## Фасад смотрит на +Z; люди при деле (Catalog._actors) стоят у прилавка.

const M := Bp.M
const FL := Bp.FL

## Цвета полотна (навесы, ткани, знамёна) — атласы набора Synty
const CLOTH := ["01_A", "01_C", "02_A", "02_B", "02_C", "03_C", "04_A", "04_B", "04_C", "03_B", "03_A", "01_B"]
const RED := 0
const WHITE := 1
const PINK := 2
const SKY := 3
const SAGE := 4
const ORANGE := 5
const MUSTARD := 6
const GREEN := 7
const BLUE := 8
const PURPLE := 9
const MAGENTA := 10
## Цвет полос навеса к цвету стен (индекс Defs.PALETTE): охра — красный, терракота — голубой, розовый — зелёный…
const ACCENT := [RED, SKY, GREEN, BLUE, ORANGE, RED, BLUE, GREEN, MUSTARD, RED]
## Оттенки товара в корзинах
const T_GREEN := Color(0.55, 0.95, 0.35)
const T_ORANGE := Color(1.0, 0.62, 0.28)
const T_GRAPE := Color(0.62, 0.42, 0.85)
const T_APPLE := Color(1.3, 0.42, 0.35)
const T_FISH := Color(0.82, 0.88, 0.98)
const T_BREAD := Color(1.2, 0.82, 0.48)
const T_OLIVE := Color(0.5, 0.62, 0.3)
const T_HAM := Color(0.52, 0.23, 0.16)
const T_MEAT := Color(0.85, 0.3, 0.25)
const BRONZE := {"tints": {"Building_Marble_01": Color(0.86, 0.6, 0.3)}}
const GOLD := {"tints": {"Building_Marble_01": Color(1.0, 0.8, 0.35)}}
const GILT := {"tint": Color(1.0, 0.8, 0.35)}
## Черепица лавок — только терракота (серая и песочная не римские)
const TILES := ["Roof_Tile_01", "Roof_Tile_03", "Roof_Tile_12"]
## Навершия конька: пальметта, урна, шишка — римские акротерии
const TOPPERS := [3, 5, 6]
const W1 := "SM_Bld_Wall_01"
const DOOR := "SM_Bld_Wall_Door_04"
const SHOP := "SM_Bld_Wall_Door_Double_03"

## Лавки уже, как дома (CatHouses._narrow): чертёж собирается в пролётах Synty по 2,5 м, а в конце сжимается вдоль
## фасада (ось X) в SX раз. Стены, карнизы, крыши, двери, прилавки, полосатые навесы и полотна, полки, балки, плющ
## и лоза сжимаются вместе с пролётом; вещи (колонны, столбы, мебель, корзины, амфоры, фонари, трубы, статуи)
## сохраняют пропорции — сдвигается только их середина. Огни, дым и вход — следом. Люди при деле (Catalog._actors)
## стоят в уже сжатых координатах, поэтому то, на чём они сидят, ставится в точку x / SX.
## Сжатие то же, что у домов (одна постоянная): пролёт и проём лавки той же ширины, что у соседнего дома
const SX := CatHouses.SX
const RIGID := ["SM_Bld_Pillar", "SM_Bld_Roof_Topper", "SM_Bld_Ornament", "SM_Bld_Trellis_Pillar", "SM_Env_Ivy_Pillar",
	"SM_Bld_Roof_Base_Pillar", "SM_Bld_Roof_Base_Peak"]
const FLEX := ["SM_Bld_", "#dark", "#lit", "SM_Prop_Overhang", "SM_Prop_Banner_Roof", "SM_Prop_Mural", "SM_Prop_FlowerBed",
	"SM_Prop_Drapery", "SM_Env_Ivy", "SM_Env_Vine", "SM_Prop_Shelf", "SM_Prop_Beam", "SM_Prop_Rug_Drape"]
## Высота сиденья скамьи Synty в родном масштабе — люди при деле садятся ровно на неё (Catalog.ARCH = Citizen.SIZE)
const SEAT := 1.0
## Детали, которые не сжимаются, хоть и гибкие по имени (краска в круглом чане) — индексы в b.parts
static var _hold := {}


# ---------- основа ----------

## Индекс цвета штукатурки в палитре (Catalog.make уже покрасил чертёж: b.tint)
static func _pal(b: Bp) -> int:
	var best := 0
	var bd := INF
	for i in Defs.PALETTE.size():
		var c: Color = Defs.PALETTE[i]["c"]
		var d := absf(c.r - b.tint.r) + absf(c.g - b.tint.g) + absf(c.b - b.tint.b)
		if d < bd:
			bd = d
			best = i
	return best


## Цвет стен из палитры и терракотовая черепица (оттенок — по цвету дома, чтобы соседи различались)
static func _paint(b: Bp, pal: int) -> void:
	b.paint(pal, false)
	b.roof_tex = TILES[pal % 3]
	b.remap = b.floor_remap(1)


static func _topper(pal: int) -> String:
	return "SM_Bld_Roof_Topper_0%d" % TOPPERS[pal % TOPPERS.size()]


## Окно задней стены: ставни или три узких окна — по цвету дома
static func _back_win(pal: int) -> String:
	return ["SM_Bld_Wall_Window_01", "SM_Bld_Wall_Window_02"][pal % 2]


static func _cloth(i: int) -> Dictionary:
	var a: String = CLOTH[posmod(i, CLOTH.size())]
	if a == "01_A":
		return {}
	return {"PolygonAncientEmpire_01_A": "PolygonAncientEmpire_" + a}


## Ковры, стопки тканей, кожи: у них своя часть атласа — цвета землистые (01_A рыжий, 01_B синий, 01_C оливковый,
## 02_A тёмно-бурый, 03_A сливочный с рыжим, 03_B сливочный с синим, 03_C сливочный с оливковым)
static func _rug(a: String) -> Dictionary:
	if a == "01_A":
		return {}
	return {"PolygonAncientEmpire_01_A": "PolygonAncientEmpire_" + a}


## Полотнище, висящее с перекладины: середина верхнего края p, ширина w, длина h, цвет полотна
static func _sheet(b: Bp, p: Vector3, w: float, h: float, col: int, yaw := 0.0) -> void:
	var bs := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI / 2) * Basis.from_scale(Vector3(w / 2.6, 0.25, h / 2.6))
	_put_xf(b, "SM_Prop_Banner_Roof_01", Transform3D(bs, p + Vector3(-w / 2.0, 0, 0).rotated(Vector3.UP, yaw)), _cloth(col))


## Плющ с цветами на стене коробки (сторона side, модуль i — дробный, высота y)
static func _ivy(b: Bp, x0: float, x1: float, z0: float, z1: float, side: int, i: float, y: float, k: int) -> void:
	_on(b, "SM_Env_Ivy_Flowers_0%d" % (1 + posmod(k, 9)), x0, x1, z0, z1, side, i, y, 0.13)


## Цветы в подвесном кашпо под окном (сторона side, модуль i)
static func _pot(b: Bp, x0: float, x1: float, z0: float, z1: float, side: int, i: float, y: float, k: int) -> void:
	_on(b, "SM_Prop_FlowerPot_Hanging_0%d" % (4 + posmod(k, 3)), x0, x1, z0, z1, side, i, y, 0.13, 0.85)


static func _flex(nm: String) -> bool:
	for s: String in RIGID:
		if nm.begins_with(s):
			return false
	for s: String in FLEX:
		if nm.begins_with(s):
			return true
	return false


## Сжать чертёж лавки вдоль фасада (см. SX)
static func _narrow(b: Bp, sx := SX) -> void:
	var S := Basis.from_scale(Vector3(sx, 1, 1))
	var k := Vector3(sx, 1, 1)
	for i in b.parts.size():
		var p: Array = b.parts[i]
		var nm: String = p[0]
		var xf: Transform3D = p[1]
		if _flex(nm) and not _hold.has(i):
			p[1] = Transform3D(S * xf.basis, xf.origin * k)
		else:
			var c := xf * Bp.model_aabb(nm).get_center()
			p[1] = Transform3D(xf.basis, xf.origin + Vector3(c.x * (sx - 1.0), 0, 0))
	for i in b.lights.size():
		b.lights[i] = b.lights[i] * k
	for i in b.smoke.size():
		b.smoke[i] = b.smoke[i] * k
	b.door = b.door * k
	_hold.clear()


## Деталь со своей раскраской (полотно другого цвета, бронза, оттенок товара)
static func _put(b: Bp, name: String, pos: Vector3, yaw := 0.0, s := 1.0, rm := {}) -> void:
	b.parts.append([name, b.base * Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), pos), rm])


static func _put_xf(b: Bp, name: String, xf: Transform3D, rm := {}) -> void:
	b.parts.append([name, b.base * xf, rm])


## Точка на стене коробки x0..x1 × z0..z1: сторона 0 фасад (+Z), 1 → +X, 2 → −Z, 3 → −X; i — модуль (дробный — середина)
static func _bay(x0: float, x1: float, z0: float, z1: float, side: int, i: float, y: float, out := 0.0) -> Array:
	match side:
		0: return [Vector3(x0 + i * M, y, z1 + out), 0.0]
		1: return [Vector3(x1 + out, y, z1 - i * M), PI / 2]
		2: return [Vector3(x1 - i * M, y, z0 - out), PI]
		_: return [Vector3(x0 - out, y, z0 + i * M), -PI / 2]


static func _on(b: Bp, name: String, x0: float, x1: float, z0: float, z1: float, side: int, i: float, y: float, out := 0.0, s := 1.0, rm := {}) -> void:
	var a := _bay(x0, x1, z0, z1, side, i, y, out)
	_put(b, name, a[0], a[1], s, rm)


## Коробка стен x0..x1 × z0..z1 (кратно 2,5 м). fl — этажи: {сторона: [деталь на каждый модуль]}; "" — пропуск,
## нет записи — глухая стена. o: cornice — карниз, top — карниз и над верхним этажом, f0 — с какого этажа,
## dark — отступ нутра от фасада (в открытую лавку видно полки), lit — нутро в сумерках светится (по умолчанию да).
## В каждый проём SM_Bld_Wall_Door_04 сама ставится дверь-створка, у двери первого этажа — каменная ступень
static func _box(b: Bp, x0: float, x1: float, z0: float, z1: float, fl: Array, o := {}) -> void:
	var nx := int(round((x1 - x0) / M))
	var nz := int(round((z1 - z0) / M))
	var cor: String = o.get("cornice", "SM_Bld_Trim_02")
	var f0: int = o.get("f0", 0)
	var top: bool = o.get("top", true)
	var k := _pal(b) + int(round(x0 + z0 * 3.0))
	for f in fl.size():
		var fy := f + f0
		var y := fy * FL
		b.remap = b.floor_remap(fy)
		var spec: Dictionary = fl[f]
		for side in 4:
			var n := nx if side % 2 == 0 else nz
			var names: Array = spec.get(side, [])
			for i in n:
				var nm: String = names[i] if i < names.size() else W1
				if nm == "":
					continue
				var a := _bay(x0, x1, z0, z1, side, i, y)
				var yaw: float = a[1]
				b.add(nm, a[0], yaw, 1.0, true)
				if f < fl.size() - 1 or top:
					b.add(cor, (a[0] as Vector3) + Vector3(0, FL - 0.33, 0), yaw, 1.0, true)
				if fy == 0 and side != 2 and not nm.contains("Door") and not nm.contains("Seat"):
					b.add("SM_Bld_Trim_05", a[0], yaw, 1.0, true)
				if nm == DOOR:
					b.add("SM_Bld_Door_0%d" % (1 + posmod(k + side * 2 + i + fy, 5)), (a[0] as Vector3) + Vector3(0.75, 0, -0.02).rotated(Vector3.UP, yaw), yaw)
					if fy == 0:
						b.add("SM_Bld_Floor_Trim_01", a[0], yaw)
		for c: Array in [[Vector3(x0, y, z1), 0.0], [Vector3(x1, y, z1), PI / 2], [Vector3(x1, y, z0), PI], [Vector3(x0, y, z0), -PI / 2]]:
			b.add("SM_Bld_Wall_End_01", c[0], c[1], 1.0, true)
	b.remap = b.floor_remap(1)
	var inner := "#lit" if o.get("lit", true) else "#dark"
	var dk: float = o.get("dark", 0.25)
	var h := fl.size() * FL - 0.1
	var zf := z1 - dk
	var zb := z0 + 0.25
	b.parts.append([inner, b.base * Transform3D(Basis.IDENTITY.scaled(Vector3(x1 - x0 - 0.5, h, maxf(zf - zb, 0.3))), Vector3((x0 + x1) / 2.0, f0 * FL + h / 2.0, (zf + zb) / 2.0)), {}])
	if f0 == 0 and dk > 0.5:
		# пол открытой лавки — чтобы в проёме не было видно травы
		b.parts.append([inner, b.base * Transform3D(Basis.IDENTITY.scaled(Vector3(x1 - x0 - 0.3, 0.06, z1 - z0 - 0.3)), Vector3((x0 + x1) / 2.0, 0.03, (z0 + z1) / 2.0)), {}])


## Двускатная черепичная крыша, конёк вдоль X (скаты к улице и во двор); ky — крутизна (1 — родные 16,7°)
static func _roof_x(b: Bp, x0: float, x1: float, z0: float, z1: float, top: float, ky := 1.8, topper := "") -> float:
	var nx := int(round((x1 - x0) / M))
	var k := (z1 - z0) / 2.0 / M
	var sc := Vector3(1.0, k * ky, k)
	for i in nx:
		b.add_xf("SM_Bld_Roof_Base_Straight_01", Transform3D(Basis.IDENTITY.scaled(sc), Vector3(x0 + i * M, top, z1)), true)
		b.add_xf("SM_Bld_Roof_Base_Straight_01", Transform3D(Basis(Vector3.UP, PI).scaled(sc), Vector3(x1 - i * M, top, z0)), true)
		b.add("SM_Bld_Roof_Edge_Straight_01", Vector3(x0 + i * M, top, z1), 0.0, 1.0, true)
		b.add("SM_Bld_Roof_Edge_Straight_01", Vector3(x1 - i * M, top, z0), PI, 1.0, true)
	for c: Array in [[Vector3(x0, top, z1), 0.0], [Vector3(x1, top, z0), PI], [Vector3(x1, top, z1), 0.0], [Vector3(x0, top, z0), PI]]:
		b.add_xf("SM_Bld_Roof_Base_Straight_Side_01", Transform3D(Basis(Vector3.UP, c[1]).scaled(sc), c[0]), true)
	var ridge := top + 0.75 * k * ky
	if topper != "":
		b.add(topper, Vector3(x0 + 0.12, ridge, (z0 + z1) / 2.0), 0.0)
		b.add(topper, Vector3(x1 - 0.12, ridge, (z0 + z1) / 2.0), 0.0)
	return ridge


## Двускатная крыша фронтоном к улице (конёк вдоль Z)
static func _roof_z(b: Bp, x0: float, x1: float, z0: float, z1: float, top: float, ky := 1.8, topper := "") -> float:
	var keep := b.base
	b.base = b.base * Transform3D(Basis(Vector3.UP, PI / 2), Vector3((x0 + x1) / 2.0, 0, (z0 + z1) / 2.0))
	var hw := (x1 - x0) / 2.0
	var hd := (z1 - z0) / 2.0
	var r := _roof_x(b, -hd, hd, -hw, hw, top, ky, topper)
	b.base = keep
	return r


## Шатровая крыша из четырёх угловых скатов над прямоугольником 2 модуля × 2·sz модуля (центр cx, cz)
static func _hip(b: Bp, cx: float, cz: float, top: float, ky := 1.7, sz := 1.0) -> float:
	for a in 4:
		var yaw := a * PI / 2
		var off := Vector3(-M, 0, M).rotated(Vector3.UP, yaw) * Vector3(1, 1, sz)
		b.add_xf("SM_Bld_Roof_Base_Corner_01", Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(1, ky, sz)), Vector3(cx, top, cz) + off), true)
	return top + 0.8 * ky


## Плоская кровля-терраса x0..x1 × z0..z1 на высоте top, парапет по сторонам sides
static func _terrace(b: Bp, x0: float, x1: float, z0: float, z1: float, top: float, sides := [0, 1, 3], rail := "SM_Bld_Wall_Balcony_04", floor := true) -> void:
	var nx := int(round((x1 - x0) / M))
	var nz := int(round((z1 - z0) / M))
	for i in nx:
		for j in nz:
			if floor:
				b.add("SM_Bld_Roof_Base_Flat_02", Vector3(x0 + i * M, top - 0.68, z1 - j * M), 0.0)
	for side: int in sides:
		var n := nx if side % 2 == 0 else nz
		for i in n:
			var a := _bay(x0, x1, z0, z1, side, i, top)
			b.add(rail, a[0], a[1], 1.0, true)


## Портик перед фасадом: колонны на линии zc, балка, пологий черепичный скат до стены (z = zw).
## h — высота колонн; wood — деревянные столбы вместо мраморных колонн
static func _porch(b: Bp, x0: float, x1: float, zc: float, zw: float, h := 2.4, cols := 3, wood := false) -> float:
	for i in cols:
		var x := lerpf(x0 + 0.3, x1 - 0.3, float(i) / float(cols - 1))
		if wood:
			b.add_xf("SM_Bld_Trellis_Pillar_01", Transform3D(Basis.from_scale(Vector3(0.8, h / 3.13, 0.8)), Vector3(x, 0, zc)))
		else:
			b.add_xf("SM_Bld_Pillar_06", Transform3D(Basis.from_scale(Vector3(0.85, h / 3.0, 0.85)), Vector3(x, 0, zc)))
	var nx := int(round((x1 - x0) / M))
	var d := zc - zw + 0.35
	var k := d / M
	var y := h + 0.3
	var ky := clampf((FL - 0.05 - y) / (0.75 * k), 0.3, 1.2)
	var sc := Vector3(1.0, k * ky, k)
	for i in nx:
		if wood:
			b.add_xf("SM_Prop_Beam_01", Transform3D(Basis.from_scale(Vector3(1.0, 2.0, 1.3)), Vector3(x0 + i * M, h + 0.15, zc)))
		else:
			b.add("SM_Bld_Wall_Tiny_01", Vector3(x0 + i * M, h, zc), 0.0, 1.0, true)
		b.add_xf("SM_Bld_Roof_Base_Straight_01", Transform3D(Basis.IDENTITY.scaled(sc), Vector3(x0 + i * M, y, zc + 0.35)), true)
		b.add("SM_Bld_Roof_Edge_Straight_01", Vector3(x0 + i * M, y, zc + 0.35), 0.0, 1.0, true)
	b.add_xf("SM_Bld_Roof_Base_Straight_Side_01", Transform3D(Basis.IDENTITY.scaled(sc), Vector3(x0, y, zc + 0.35)), true)
	b.add_xf("SM_Bld_Roof_Base_Straight_Side_01", Transform3D(Basis.IDENTITY.scaled(sc), Vector3(x1, y, zc + 0.35)), true)
	return y


## Полосатый полотняный навес: полосы шириной ~0,45 м, сзади выше (yb), спереди ниже (yf)
static func _awning(b: Bp, x0: float, x1: float, zb: float, zf: float, yb: float, yf: float, ca: int, cb := WHITE) -> void:
	var n := maxi(3, int(round((x1 - x0) / 0.45)))
	var w := (x1 - x0) / n
	var dz := zf - zb
	var dy := yb - yf
	var ln := sqrt(dz * dz + dy * dy)
	var ang := atan2(dy, dz)
	for i in n:
		var bs := Basis(Vector3.RIGHT, ang) * Basis.from_scale(Vector3(w / 2.6, 0.35, ln / 2.6))
		_put_xf(b, "SM_Prop_Banner_Roof_01", Transform3D(bs, Vector3(x0 + i * w, yb, zb)), _cloth(ca if i % 2 == 0 else cb))


## Круглый столик Synty родом 0,55 м — ниже сиденья табурета; вытягиваем до обеденной высоты TABLE7
const TABLE7 := 0.74


static func _table(b: Bp, p: Vector3, s := 1.0) -> void:
	_put_xf(b, "SM_Prop_Table_07", Transform3D(Basis.from_scale(Vector3(s, TABLE7 / 0.55, s)), p))


## Столб навеса высотой h
static func _pole(b: Bp, p: Vector3, h: float) -> void:
	b.add_xf("SM_Prop_Pole_01", Transform3D(Basis.from_scale(Vector3(1.0, h / 3.0, 1.0)), p))


## Корзина с товаром. kind: apples, plums, oranges, greens, beets, grain, olives, bread, fish
static func _basket(b: Bp, p: Vector3, kind: String, s := 0.6, yaw := 0.0, tilt := 0.0) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt) * Basis.from_scale(Vector3.ONE * s), p)
	match kind:
		"bread", "fish":
			_put_xf(b, "SM_Prop_Basket_Set_06", xf)
			_put_xf(b, "SM_Prop_Basket_Set_06_Insert_01", xf, {"tint": T_FISH if kind == "fish" else T_BREAD})
		"oranges", "greens", "beets", "grain":
			_put_xf(b, "SM_Prop_Basket_05", xf)
			var ins := "SM_Prop_Basket_Insert_04" if kind == "beets" else "SM_Prop_Basket_Insert_02"
			var tn: Dictionary = {"oranges": {"tint": T_ORANGE}, "greens": {"tint": T_GREEN}}.get(kind, {})
			_put_xf(b, ins, xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.29, 0)), tn)
		_:
			_put_xf(b, "SM_Prop_Basket_11", xf)
			var tn: Dictionary = {"plums": {"tint": T_GRAPE}, "olives": {"tint": T_OLIVE}, "apples": {"tint": T_APPLE}}.get(kind, {})
			_put_xf(b, "SM_Prop_Basket_Insert_03", xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.12, 0)), tn)


## Поднос с рыбой: серебристые тушки рядком на плоской корзине
static func _fish_tray(b: Bp, p: Vector3, s := 0.6, yaw := 0.0) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, 0.3) * Basis.from_scale(Vector3.ONE * s), p)
	_put_xf(b, "SM_Prop_Basket_11", xf)
	_put_xf(b, "SM_Prop_Basket_Set_06_Insert_01", xf * Transform3D(Basis.from_scale(Vector3(0.95, 0.32, 0.85)), Vector3(0.05, 0.06, 0.02)), {"tint": T_FISH})


## Окорок на верёвке: вытянутый мешочек узлом вверх, цвет вяленого мяса; p — точка подвеса на перекладине
static func _ham(b: Bp, p: Vector3, k: int) -> void:
	var bs := Basis(Vector3.FORWARD, [0.15, -0.12, 0.08][k % 3]) * Basis(Vector3.UP, k * 1.1) * Basis.from_scale(Vector3(0.44, 0.66, 0.36))
	_put_xf(b, "SM_Prop_Sack_03", Transform3D(bs, p - Vector3(0, 0.5, 0)), {"tint": T_HAM})


## Колбаса — длинный тонкий мешочек на верёвке
static func _sausage(b: Bp, p: Vector3, k: int) -> void:
	_put_xf(b, "SM_Prop_Sack_03", Transform3D(Basis(Vector3.UP, k * 0.9) * Basis.from_scale(Vector3(0.14, 0.62, 0.16)), p - Vector3(0, 0.48, 0)), {"tint": Color(0.6, 0.27, 0.2)})


## Чан с краской или водой: высокая глиняная чаша, в ней «жидкость» — плоское полотно нужного цвета
static func _vat(b: Bp, p: Vector3, col: int, s := 1.0, yaw := 0.0) -> void:
	var r := Basis(Vector3.UP, yaw)
	_put_xf(b, "SM_Prop_Bowl_02", Transform3D(r * Basis.from_scale(Vector3(0.75, 1.6, 0.75) * s), p))
	_hold[b.parts.size()] = true      # краска круглая, как чан, — при сжатии лавки не сплющивается
	_put_xf(b, "SM_Prop_Banner_Roof_01", Transform3D(r * Basis.from_scale(Vector3(0.22 * s, 0.03, 0.22 * s)), p + Vector3(-0.29 * s, 0.46 * s, -0.29 * s).rotated(Vector3.UP, yaw)), _cloth(col))


## Лоза, уложенная сверху на рейки перголы (p — середина)
static func _vine_flat(b: Bp, p: Vector3, yaw: float, k: int, s := 0.7) -> void:
	var r := Basis(Vector3.UP, yaw)
	_put_xf(b, "SM_Env_Vine_0%d" % (1 + posmod(k, 3)), Transform3D(r * Basis(Vector3.RIGHT, -PI / 2) * Basis.from_scale(Vector3.ONE * s), p + Vector3(0, 0.2 * s, 0) + r * Vector3(0, 0, 0.68 * s)))


## Знамя-вывеска на стене: рисунок (буква: B — виночерпий, C — олива, D — пегас, E — вазы, H — грифон) и цвет полотна
static func _sign(b: Bp, p: Vector3, yaw: float, letter: String, col: int, s := 0.7) -> void:
	_put(b, "SM_Prop_Banner_02_" + letter, p, yaw, s, _cloth(col))


## Фонарь на кронштейне у двери (ночью светится)
static func _lamp(b: Bp, p: Vector3, yaw := 0.0) -> void:
	b.add("#wall_lamp", p, yaw)
	b.light(p + Vector3(0, -0.2, 0.4).rotated(Vector3.UP, yaw))


## Подвесной светильник на цепи (под портиком)
static func _hanging_lamp(b: Bp, p: Vector3, s := 0.6, lit := true) -> void:
	b.add("SM_Prop_Senser_03", p - Vector3(0, 1.25 * s, 0), 0.0, s)
	if lit:
		b.light(p - Vector3(0, 1.1 * s, 0))


## Печная труба на крыше: штукатурный столбик в цвет дома под черепичной шапочкой; дымок из неё
static func _chimney(b: Bp, p: Vector3, smoke := true) -> void:
	b.add_xf("SM_Bld_Roof_Base_Pillar_01", Transform3D(Basis.from_scale(Vector3(1.6, 1.15, 1.6)), p), true)
	b.add_xf("SM_Bld_Roof_Base_Peak_01", Transform3D(Basis.from_scale(Vector3(0.24, 0.3, 0.24)), p + Vector3(-0.3, 0.96, 0.3)), true)
	if smoke:
		b.smoke.append(b.base * (p + Vector3(0, 1.3, 0)))


## Прилавок — низкая стенка в цвет дома (как каменные прилавки Помпей) со столбиками по краям, вдоль x0..x1
## на линии z (лицевая грань); fancy — с расписным меандром. Возвращает высоту столешницы (по пояс человечку)
const CTR := 0.95


static func _counter(b: Bp, x0: float, x1: float, z: float, fancy := true, h := CTR) -> float:
	var nm := "SM_Bld_Wall_Balcony_06" if fancy else "SM_Bld_Wall_Balcony_05"
	var f := 0.22 if fancy else 0.11
	b.add_xf(nm, Transform3D(Basis.from_scale(Vector3((x1 - x0) / 2.5, h / 1.02, 1.0)), Vector3(x0, 0, z - f)), true)
	for x: float in [x0 + 0.09, x1 + 0.09]:
		b.add_xf("SM_Bld_Wall_End_Half_01", Transform3D(Basis.from_scale(Vector3(1.7, (h + 0.02) / 1.51, 1.7)), Vector3(x, 0, z - 0.19)), true)
	return h


## Полки с товаром в глубине открытой лавки: проём SM_Bld_Wall_Door_Double_03 в модуле bx..bx+2,5, фасад на z.
## it — до четырёх [деталь, масштаб, раскраска?]: два на средней полке, два на верхней
const SHELF_SLOTS := [Vector2(-0.5, 0.72), Vector2(0.45, 0.72), Vector2(-0.3, 1.2), Vector2(0.5, 1.2)]


static func _shelf(b: Bp, bx: float, z: float, it: Array, k := 0) -> void:
	var c := Vector3(bx + 1.25, 0, z - 0.6)
	b.add("SM_Prop_Shelf_0%d" % (1 + posmod(k, 2)), c, 0.0, 0.8)
	for j in mini(it.size(), 4):
		var e: Array = it[j]
		var sl: Vector2 = SHELF_SLOTS[j]
		_put(b, e[0], c + Vector3(sl.x, sl.y, 0.0), j * 0.7, e[1], e[2] if e.size() > 2 else {})


# ---------- рынок ----------

## Лавка под полосатым навесом 2,6×2,4 м: прилавок с корзинами товара, мешки и кувшины вокруг
static func _stall(b: Bp, kind: String, v: int) -> void:
	var pal := _pal(b)
	var cols: Array = {"fruit": [RED, ORANGE, MAGENTA], "veg": [GREEN, SAGE, MUSTARD], "fish": [SKY, BLUE, SKY]}[kind]
	var col: int = cols[(pal + v) % 3]
	var col2 := BLUE if kind == "fish" and (pal + v) % 3 == 2 else WHITE
	# навес высоко: покупатель (1,8 м в мерах чертежа) проходит под передним краем с запасом
	var hb := 2.95
	var hf := 2.45
	for x: float in [-1.25, 1.25]:
		_pole(b, Vector3(x, 0, -1.15), hb)
		_pole(b, Vector3(x, 0, 1.1), hf)
	_awning(b, -1.38, 1.38, -1.3, 1.35, hb + 0.05, hf - 0.05, col, col2)
	# прилавок с товаром лицом к покупателю — корзины крупные, как в Town to City; стол в полную высоту (по пояс торговцу),
	# поуже, чтобы влез между столбами
	_put_xf(b, "SM_Prop_Table_08", Transform3D(Basis.from_scale(Vector3(0.85, 1.0, 0.85)), Vector3(0, 0, 0.5)))
	var top := 0.78
	var goods: Array = {"fruit": ["apples", "oranges", "plums"], "veg": ["greens", "beets", "grain"], "fish": ["fish", "olives", "fish"]}[kind]
	for k in 3:
		var g: String = goods[(k + v) % 3]
		if g == "fish":
			_fish_tray(b, Vector3(-0.73 + k * 0.73, top + 0.04, 0.45), 0.76, k * 0.3)
		else:
			_basket(b, Vector3(-0.73 + k * 0.73, top + 0.08, 0.45), g, 0.76, 0.0, 0.32)
	# корзины на мостовой перед лавкой и сбоку
	match kind:
		"fruit":
			b.add("SM_Prop_Basket_Set_01", Vector3(-0.85, 0, 1.6), 0.3, 0.7)
			b.add("SM_Prop_Basket_Set_01_Insert_01", Vector3(-0.85, 0, 1.6), 0.3, 0.7)
			_basket(b, Vector3(0.75, 0, 1.65), "apples", 0.85, 0.5)
			b.add("SM_Prop_Basket_Set_02", Vector3(-0.85, 0, -0.85), 0.0, 0.65)
			b.add("SM_Prop_Basket_Set_02_Insert_01", Vector3(-0.85, 0, -0.85), 0.0, 0.65)
		"veg":
			b.add("SM_Prop_Basket_Set_04", Vector3(-0.8, 0, 1.6), 0.4, 0.72)
			_put(b, "SM_Prop_Basket_Set_04_Insert_01", Vector3(-0.8, 0, 1.6), 0.4, 0.72, {"tint": T_GREEN})
			b.add("SM_Prop_Sack_Stack_02", Vector3(0.8, 0, 1.6), 0.2, 0.62)
			b.add("SM_Prop_Straw_Bundle_01", Vector3(1.0, 0, -0.95), 0.4, 0.75)
			b.add("SM_Prop_Sack_03", Vector3(-0.8, 0, -0.9), 0.6, 0.85)
		_:
			_basket(b, Vector3(-0.75, 0, 1.55), "fish", 0.7, 0.3)
			_basket(b, Vector3(-0.1, 0, 1.75), "fish", 0.55, 1.1)
			b.add("SM_Prop_Vase_02", Vector3(0.95, 0, 1.5), 0.0, 0.68)
			b.add("SM_Prop_Vase_05", Vector3(0.6, 0, 1.65), 0.7, 0.6)
			b.add("SM_Prop_Jar_Pile_01", Vector3(0.75, 0, -0.85), 0.0, 0.55)
			_hanging_lamp(b, Vector3(0.0, hf + 0.25, 1.05), 0.45, false)
	b.door = Vector3(0, 0, 2.2)


# ---------- лавки-домики ----------

## Что продаёт лавка: облик дома, буква знамени-вывески, цвет знамени.
## awning — одноэтажная, во всю ширину полосатый навес над прилавком;
## porch — одноэтажная фронтоном к улице, черепичный портик на колоннах (у сапожника — на деревянных столбах);
## terrace — двухэтажная: второй этаж отступает, впереди терраса с перголой (как дома в Town to City);
## loggia — двухэтажная: верх на колоннах нависает над лавкой; yard — красильня: узкий дом и мастерская с сушильной террасой
const SHOPS := {
	"butcher": ["awning", "H", RED], "potter": ["awning", "E", MUSTARD], "barber": ["awning", "D", BLUE],
	"cobbler": ["porch", "D", ORANGE], "weaver": ["porch", "A", PURPLE], "dyer": ["yard", "A", MAGENTA],
	"bakery": ["terrace", "C", MUSTARD], "wineshop": ["terrace", "B", PURPLE], "oilshop": ["terrace", "C", GREEN],
	"lamps": ["terrace", "D", ORANGE], "medic": ["terrace", "A", SAGE],
	"perfumer": ["loggia", "B", PINK], "jeweler": ["loggia", "H", BLUE], "tailor": ["loggia", "E", PURPLE],
}

## Товар на полках в глубине лавки: [деталь, масштаб, раскраска]
const SHELVES := {
	"butcher": [["SM_Prop_Jug_02", 0.42], ["SM_Prop_Jar_01", 0.5], ["SM_Prop_Jug_05", 0.8], ["SM_Prop_Plate_01", 0.45]],
	"potter": [["SM_Prop_Vase_02", 0.42], ["SM_Prop_Vase_03", 0.4], ["SM_Prop_Jug_03", 0.4], ["SM_Prop_Vase_06", 0.45]],
	"barber": [["SM_Prop_Jug_05", 0.8], ["SM_Prop_Bowl_04", 0.8], ["SM_Prop_Goblet_01", 1.0], ["SM_Prop_Jug_05", 0.7]],
	"cobbler": [["SM_Prop_Basket_06", 0.5], ["SM_Prop_Basket_12", 0.65], ["SM_Prop_Basket_06", 0.45], ["SM_Prop_Basket_07", 0.45]],
	"weaver": [["SM_Prop_Rug_Folded_01", 0.45], ["SM_Prop_Rug_Folded_02", 0.45], ["SM_Prop_Rug_Folded_02", 0.42], ["SM_Prop_Rug_Folded_01", 0.42]],
	"wineshop": [["SM_Prop_Vase_01", 0.4], ["SM_Prop_Jug_03", 0.4], ["SM_Prop_Jug_01", 0.45], ["SM_Prop_Vase_02", 0.4]],
	"oilshop": [["SM_Prop_Jug_06", 0.45], ["SM_Prop_Jar_01", 0.5], ["SM_Prop_Jug_02", 0.42], ["SM_Prop_Jug_06", 0.42]],
	"lamps": [["SM_Prop_Senser_04", 0.75], ["SM_Prop_Senser_04", 0.75], ["SM_Prop_Senser_04", 0.7], ["SM_Prop_Senser_04", 0.7]],
	"medic": [["SM_Prop_Scroll_Pile_02", 0.4], ["SM_Prop_Vase_04", 0.45], ["SM_Prop_Scroll_Pile_04", 0.4], ["SM_Prop_Jug_05", 0.8]],
	"perfumer": [["SM_Prop_Jug_05", 0.8], ["SM_Prop_Goblet_02", 1.0], ["SM_Prop_Vase_04", 0.42], ["SM_Prop_Jug_05", 0.7]],
	"jeweler": [["SM_Prop_Goblet_01", 1.1, GILT], ["SM_Prop_Bowl_04", 0.7, GILT], ["SM_Prop_Plate_02", 0.55, GILT], ["SM_Prop_Goblet_02", 1.1, GILT]],
	"tailor": [["SM_Prop_Rug_Folded_02", 0.45], ["SM_Prop_Rug_Folded_01", 0.45], ["SM_Prop_Rug_Folded_01", 0.42], ["SM_Prop_Rug_Folded_02", 0.42]],
}
## Цвета тканей на полках ткача и портного
const SHELF_CLOTH := ["01_B", "03_C", "01_A", "03_B"]


static func _shop(b: Bp, type: String, v: int) -> void:
	var spec: Array = SHOPS.get(type, ["porch", "A", RED])
	var pal := _pal(b)
	_hold.clear()
	_paint(b, pal)
	b.ground_style = ["plain", "brick", "plain", "pattern"][(pal + type.length()) % 4]
	b.upper_style = "plain"
	b.remap = b.floor_remap(1)
	match spec[0]:
		"awning": _form_awning(b, type, spec, pal)
		"porch": _form_porch(b, type, spec, pal)
		"terrace": _form_terrace(b, type, spec, pal)
		"loggia": _form_loggia(b, type, spec, pal)
		_: _form_yard(b, type, spec, pal)
	if b.smoke.size() > 1:
		b.smoke.resize(1)
	_narrow(b)


## Полки ремесла в открытом проёме (модуль bx..bx+2,5, фасад z)
static func _trade_shelf(b: Bp, type: String, bx: float, z: float, pal: int) -> void:
	var it: Array = SHELVES.get(type, [])
	if type in ["weaver", "tailor"]:
		var tinted := []
		for j in it.size():
			var e: Array = it[j]
			tinted.append([e[0], e[1], _rug(SHELF_CLOTH[(j + pal) % 4] if type == "weaver" else ["03_A", "01_B", "03_B", "02_B"][(j + pal) % 4])])
		it = tinted
	_shelf(b, bx, z, it, pal)


## Одноэтажная лавка 5×2,5 м; во всю ширину — полосатый навес на столбах, под ним расписной прилавок с товаром.
## Крыша по цвету дома: фронтоном к улице (в нём бронзовая эмблема) или коньком вдоль улицы
static func _form_awning(b: Bp, type: String, spec: Array, pal: int) -> void:
	var front := [DOOR, SHOP]
	if type == "barber":
		front = ["SM_Bld_Wall_Window_01", SHOP]
	_box(b, -2.5, 2.5, -2.5, 0.0, [{0: front, 1: ["SM_Bld_Wall_Window_06"], 3: ["SM_Bld_Wall_Window_03"], 2: [_back_win(pal), DOOR]}],
		{"cornice": "SM_Bld_Trim_03", "dark": 1.4})
	_ivy(b, -2.5, 2.5, -2.5, 0.0, 2, 0.12, 1.5, pal + 3)
	_pot(b, -2.5, 2.5, -2.5, 0.0, 2, 0.5, 0.95, pal)
	if pal % 2 == 0:
		var ridge := _roof_z(b, -2.5, 2.5, -2.5, 0.0, FL, 1.9)
		b.add(_topper(pal), Vector3(0, ridge, 0.1), 0.0)
		_put(b, "SM_Prop_Symbol_%02d" % [19, 17, 16, 18, 15][pal % 5], Vector3(0, FL + 0.16, 0.18), 0.0, 0.55, BRONZE)
	else:
		_roof_x(b, -2.5, 2.5, -2.5, 0.0, FL, 2.3, _topper(pal))
	_chimney(b, Vector3(1.4, FL + 0.55, -1.6), type != "potter")
	# навес над прилавком: передний край на 2,4 — люди проходят под ним, не задевая
	if type == "potter":
		# навес только над входом и прилавком — печь для обжига справа под открытым небом, дым из неё
		_awning(b, -2.55, 1.55, 0.12, 1.72, 2.8, 2.4, ACCENT[pal])
		for x: float in [-2.35, -0.45, 1.45]:
			_pole(b, Vector3(x, 0, 1.58), 2.4)
		_counter(b, 0.2, 1.25, 1.62)
	else:
		_awning(b, -2.55, 2.55, 0.12, 1.72, 2.8, 2.4, ACCENT[pal])
		for x: float in [-2.35, 0.0, 2.35]:
			_pole(b, Vector3(x, 0, 1.58), 2.4)
		if type == "barber":
			_counter(b, -2.2, -0.25, 1.62)
		else:
			_counter(b, 0.25, 2.2, 1.62)
	_lamp(b, Vector3(-0.3, 2.15, 0.12))
	_trade_shelf(b, type, 0.0, 0.0, pal)
	_goods(b, type, Vector3(1.22, 0, 1.42), pal)
	b.door = Vector3(0.1 if type == "barber" else -1.25, 0, 2.3)


## Одноэтажная лавка 5×2,5 м фронтоном к улице (бронзовая эмблема во фронтоне видна над портиком), черепичный портик
## на трёх колоннах или столбах; слева дверь, справа широкий проём, между колоннами — прилавок; вывеска на балке
static func _form_porch(b: Bp, type: String, spec: Array, pal: int) -> void:
	var side_win: String = ["SM_Bld_Wall_Window_06", "SM_Bld_Wall_Window_03"][pal % 2]
	_box(b, -2.5, 2.5, -2.5, 0.0, [{0: [DOOR, SHOP], 1: [side_win], 3: ["SM_Bld_Wall_Window_03"], 2: [_back_win(pal + 1), DOOR]}],
		{"cornice": "SM_Bld_Trim_03", "dark": 1.4})
	_ivy(b, -2.5, 2.5, -2.5, 0.0, 3 if pal % 2 == 0 else 1, 0.5, 1.2, pal + 5)
	_ivy(b, -2.5, 2.5, -2.5, 0.0, 2, 0.12, 1.5, pal + 1)
	_pot(b, -2.5, 2.5, -2.5, 0.0, 2, 0.5, 0.95, pal + 1)
	var ridge := _roof_z(b, -2.5, 2.5, -2.5, 0.0, FL, 1.8)
	b.add(_topper(pal), Vector3(0, ridge, 0.1), 0.0)
	_put(b, "SM_Prop_Symbol_%02d" % [17, 19, 15, 16, 18][pal % 5], Vector3(0, FL + 0.2, 0.18), 0.0, 0.5, BRONZE)
	_chimney(b, Vector3(1.3, FL + 0.5, -1.7))
	var wood := type == "cobbler"
	_porch(b, -2.5, 2.5, 1.3, 0.0, 2.35, 3, wood)
	b.add("SM_Env_Ivy_Pillar_Flowers_0%d" % (1 + pal % 2), Vector3(-2.2, 0, 1.3), pal * 0.8, 0.78)
	_hanging_lamp(b, Vector3(0.0, 2.55, 0.75), 0.45, false)
	if type != "weaver":
		_counter(b, 0.35, 2.15, 1.45)   # лицом чуть впереди столбов: за прилавком место для сапожника (он стоит в z 0,6)
	_sign(b, Vector3(-1.25, 2.62 if not wood else 2.45, 1.47), 0.0, spec[1], spec[2], 0.5)
	_lamp(b, Vector3(-0.35, 2.1, 0.12))
	b.add("SM_Prop_FlowerPot_Fancy_01", Vector3(-2.15, 0, 0.62), 0.0, 0.6)
	_trade_shelf(b, type, 0.0, 0.0, pal)
	_goods(b, type, Vector3(1.25, 0, 1.3), pal)
	b.door = Vector3(-1.25, 0, 2.3)


## Двухэтажная лавка 5×5 м: верхний этаж отступает, впереди терраса с парапетом и перголой (как дома в Town to City);
## внизу — дверь и широкий проём, перед ним полосатый навес и прилавок (у пекаря — черепичный козырёк и печь в проёме).
## Крыша верха по цвету дома: коньком вдоль улицы, фронтоном к улице или шатром
static func _form_terrace(b: Bp, type: String, spec: Array, pal: int) -> void:
	var win: String = ["SM_Bld_Wall_Window_02", "SM_Bld_Wall_Window_05", "SM_Bld_Wall_Window_01"][pal % 3]
	_box(b, -2.5, 2.5, -5.0, 0.0, [{0: [DOOR, SHOP], 1: [W1, "SM_Bld_Wall_Window_06"], 3: ["SM_Bld_Wall_Window_06", W1], 2: [_back_win(pal), _back_win(pal + 1)]}],
		{"cornice": "SM_Bld_Trim_04", "dark": 1.4})
	var rail: String = {"bakery": "SM_Bld_Wall_Balcony_06", "oilshop": "SM_Bld_Wall_Balcony_06", "wineshop": "SM_Bld_Wall_Balcony_03", "lamps": "SM_Bld_Wall_Balcony_03"}.get(type, "SM_Bld_Wall_Balcony_04")
	_terrace(b, -2.5, 2.5, -2.5, 0.0, FL, [0], rail)
	_terrace(b, -2.5, 2.5, -2.5, 0.0, FL, [1, 3], "SM_Bld_Wall_Balcony_03" if rail == "SM_Bld_Wall_Balcony_03" else "SM_Bld_Wall_Balcony_04", false)
	_box(b, -2.5, 2.5, -5.0, -2.5, [{0: [DOOR, win], 1: ["SM_Bld_Wall_Window_06"], 3: ["SM_Bld_Wall_Window_03"], 2: [win, "SM_Bld_Wall_Window_02"]}],
		{"cornice": "SM_Bld_Trim_02", "f0": 1})
	match pal % 3:
		0:
			_roof_x(b, -2.5, 2.5, -5.0, -2.5, 2 * FL, 2.2, _topper(pal))
		1:
			var ridge := _roof_z(b, -2.5, 2.5, -5.0, -2.5, 2 * FL, 1.6)
			b.add(_topper(pal), Vector3(0, ridge, -2.4), 0.0)
		_:
			var peak := _hip(b, 0.0, -3.75, 2 * FL, 1.6, 0.5)
			b.add("SM_Bld_Roof_Topper_05", Vector3(0, peak, -3.75), 0.0)
	_ivy(b, -2.5, 2.5, -5.0, 0.0, 1 if pal % 2 == 0 else 3, 0.5 + pal % 2, 1.2, pal)
	_ivy(b, -2.5, 2.5, -5.0, -2.5, 2, 0.12, FL + 1.4, pal + 4)
	_pot(b, -2.5, 2.5, -5.0, -2.5, 2, 0.5, FL + 1.0, pal + 2)
	_chimney(b, Vector3(1.6, 2 * FL + 0.45, -4.1))
	# терраса: пергола от стены на двух столбах, лоза на рейках, кресло (у врача — ложе), горшок с цветами, плющ свисает с парапета
	var px := 0.0 if pal % 2 == 0 else -2.5
	for c: Vector3 in [Vector3(px + 0.3, FL, -0.3), Vector3(px + 2.2, FL, -0.3)]:
		b.add("SM_Bld_Trellis_Pillar_01", c, 0.0, 0.72)
	b.add("SM_Bld_Trellis_Roof_02", Vector3(px + 2.5, FL + 2.25, -2.5), 0.0)
	_vine_flat(b, Vector3(px + 1.25, FL + 2.5, -1.25), 0.6 + pal * 0.7, pal)
	if type == "medic":
		b.add("SM_Prop_Seat_Kline_01", Vector3(px + 1.25, FL, -1.3), PI / 2, 0.55)
	else:
		b.add("SM_Prop_Seat_Chair_01", Vector3(px + 1.2, FL, -1.3), pal * 1.1, 1.0)
	b.add("SM_Prop_FlowerPot_Fancy_01", Vector3(-1.9 if px == 0.0 else 1.9, FL, -0.5), 0.0, 0.6)
	b.add("SM_Env_Ivy_Draped_Flowers_0%d" % (1 + pal % 3), Vector3(-2.2 if px == 0.0 else 0.4, FL + 0.05, 0.1), 0.0)
	b.window_pots(0, -3.75, 2, 1, 1)
	# внизу: вывеска над дверью, фонарь, навес и прилавок перед проёмом лавки
	_sign(b, Vector3(-1.25, 2.85, 0.14), 0.0, spec[1], spec[2], 0.55)
	_lamp(b, Vector3(-0.3, 2.15, 0.12))
	if type == "bakery":
		# черепичный козырёк вместо навеса — в проёме видна печь-купол, ночью из устья светит огонь
		_on(b, "SM_Prop_Overhang_01", -2.5, 2.5, -5.0, 0.0, 0, 1.5, 2.8, 0.1)
		b.add("SM_Prop_Forge_01", Vector3(1.25, 0, -0.6), 0.0, 0.5)
		b.light(Vector3(1.25, 0.55, 0.1))
		_counter(b, 0.3, 2.2, 1.0)
		_goods(b, type, Vector3(1.25, 0, 0.8), pal)
	else:
		_awning(b, 0.0, 2.5, 0.1, 1.62, 2.8, 2.4, ACCENT[pal])
		for x: float in [0.15, 2.35]:
			_pole(b, Vector3(x, 0, 1.5), 2.4)
		_counter(b, 0.3, 2.2, 1.56)
		_trade_shelf(b, type, 0.0, 0.0, pal)
		_goods(b, type, Vector3(1.25, 0, 1.36), pal)
	b.door = Vector3(-1.25, 0, 2.2)


## Двухэтажная лавка с лоджией: верхний этаж 5×5 м на колоннах, лавка утоплена на модуль вглубь.
## Крыша по цвету дома: шатровая, фронтоном к улице (с эмблемой) или коньком вдоль улицы
static func _form_loggia(b: Bp, type: String, spec: Array, pal: int) -> void:
	var win: String = ["SM_Bld_Wall_Window_05", "SM_Bld_Wall_Window_02", "SM_Bld_Wall_Window_01"][pal % 3]
	_box(b, -2.5, 2.5, -3.75, -1.25, [{0: [SHOP, DOOR], 1: ["SM_Bld_Wall_Window_06"], 3: [W1], 2: [_back_win(pal), DOOR]}],
		{"cornice": "SM_Bld_Trim_01", "dark": 1.4})
	_box(b, -2.5, 2.5, -3.75, 1.25, [{0: [win, win], 1: ["SM_Bld_Wall_Window_02", W1], 3: [W1, "SM_Bld_Wall_Window_02"], 2: ["SM_Bld_Wall_Window_02", "SM_Bld_Wall_Window_05"]}],
		{"cornice": "SM_Bld_Trim_04", "f0": 1})
	_ivy(b, -2.5, 2.5, -3.75, -1.25, 1 if pal % 2 == 0 else 3, 0.5, 0.9, pal + 2)
	_pot(b, -2.5, 2.5, -3.75, 1.25, 2, 1.5, FL + 1.0, pal + 1)
	match pal % 3:
		0:
			var peak := _hip(b, 0.0, -1.25, 2 * FL, 1.6)
			b.add("SM_Bld_Roof_Topper_05", Vector3(0, peak, -1.25), 0.0)
		1:
			var ridge := _roof_z(b, -2.5, 2.5, -3.75, 1.25, 2 * FL, 1.3)
			b.add(_topper(pal), Vector3(0, ridge, 1.35), 0.0)
			_put(b, "SM_Prop_Symbol_16", Vector3(0, 2 * FL + 0.2, 1.43), 0.0, 0.6, GOLD if type == "jeweler" else BRONZE)
		_:
			_roof_x(b, -2.5, 2.5, -3.75, 1.25, 2 * FL, 1.9, _topper(pal))
	_chimney(b, Vector3(1.5, 2 * FL + 0.3, -2.6))
	# колоннада и балки перекрытия, гирлянды драпировок
	for x: float in [-2.2, 0.0, 2.2]:
		b.add("SM_Bld_Pillar_06", Vector3(x, 0, 0.95), 0.0)
	for x: float in [-2.5, 0.0]:
		b.add("SM_Bld_Wall_Beam_Detail_01", Vector3(x, FL - 0.15, 1.36), 0.0)
	_put(b, "SM_Prop_Drapery_0%d" % (1 + pal % 3), Vector3(-1.25, 2.95, 1.3), 0.0, 1.0, _cloth(spec[2]))
	_put(b, "SM_Prop_Drapery_0%d" % (1 + (pal + 1) % 3), Vector3(1.25, 2.95, 1.3), 0.0, 1.0, _cloth(spec[2]))
	b.window_pots(0, -1.25, 2, 2, 1)
	_sign(b, Vector3(1.25, 2 * FL - 0.25, 1.4), 0.0, spec[1], spec[2], 0.62)
	_hanging_lamp(b, Vector3(-1.1, 2.95, 0.4), 0.55)
	b.add("SM_Prop_FlowerPot_Fancy_01", Vector3(-2.2, 0, 1.15), 0.0, 0.62)
	_trade_shelf(b, type, -2.5, -1.25, pal)
	_goods(b, type, Vector3(1.25, 0, 0.95), pal)
	b.door = Vector3(0.0, 0, 2.2)


## Красильня 5×2,5 м: слева узкий двухэтажный дом фронтоном к улице (дверь, вывеска, окно с цветами; из окна торчат
## шесты, с них вдоль фасада свисают длинные крашеные полотнища — как на улицах красильщиков), справа одноэтажная
## мастерская с открытым проёмом (в нём чаны с краской), на её крыше — сушильная терраса с яркими тканями над парапетом
static func _form_yard(b: Bp, type: String, spec: Array, pal: int) -> void:
	var cols := [PURPLE, MUSTARD, SKY, RED, GREEN, MAGENTA, ORANGE, BLUE]
	_box(b, -2.5, 0.0, -2.5, 0.0, [{0: [DOOR], 1: [""], 2: [_back_win(pal)], 3: ["SM_Bld_Wall_Window_06"]},
		{0: ["SM_Bld_Wall_Window_05"], 1: [DOOR], 2: ["SM_Bld_Wall_Window_02"], 3: ["SM_Bld_Wall_Window_03"]}], {"cornice": "SM_Bld_Trim_03", "dark": 0.6})
	var ridge := _roof_z(b, -2.5, 0.0, -2.5, 0.0, 2 * FL, 2.3)
	b.add(_topper(pal), Vector3(-1.25, ridge, 0.1), 0.0)
	_chimney(b, Vector3(-0.6, 2 * FL + 0.2, -1.9))
	_ivy(b, -2.5, 0.0, -2.5, 0.0, 3, 0.5, 1.4, pal + 2)
	_pot(b, -2.5, 0.0, -2.5, 0.0, 0, 0.5, FL + 1.0, pal)
	# шесты из окна с полотнищами вдоль фасада
	for k in 2:
		var x: float = [-2.2, -0.3][k]
		b.add_xf("SM_Prop_Pole_01", Transform3D(Basis(Vector3.RIGHT, PI / 2) * Basis.from_scale(Vector3(0.8, 0.42, 0.8)), Vector3(x, FL + 2.15, 0.02)))
		_sheet(b, Vector3(x, FL + 2.1, 0.72), 1.05, 1.55 - k * 0.2, cols[(pal + k * 3) % cols.size()], PI / 2)
	_sign(b, Vector3(-1.25, 2.85, 0.14), 0.0, spec[1], spec[2], 0.5)
	_lamp(b, Vector3(-0.25, 2.2, 0.12))
	# мастерская: открытый проём, в нём два чана с краской; на крыше сушильная терраса
	_box(b, 0.0, 2.5, -2.5, 0.0, [{0: [SHOP], 1: ["SM_Bld_Wall_Window_06"], 2: [_back_win(pal + 1)], 3: [""]}], {"cornice": "SM_Bld_Trim_01", "dark": 1.4})
	_terrace(b, 0.0, 2.5, -2.5, 0.0, FL, [0, 1, 2], "SM_Bld_Wall_Balcony_03")
	for x: float in [0.35, 2.15]:
		_pole(b, Vector3(x, FL, -1.25), 1.9)
	b.add_xf("SM_Prop_Beam_01", Transform3D(Basis.from_scale(Vector3(1.8 / 2.5, 0.7, 0.7)), Vector3(0.35, FL + 1.85, -1.25)))
	for k in 3:
		_sheet(b, Vector3(0.66 + k * 0.6, FL + 1.85, -1.25), 0.55, 1.15 - (k % 2) * 0.2, cols[(pal + k + 5) % cols.size()])
	for k in 2:
		_vat(b, Vector3(0.75 + k * 1.0, 0, -0.55), cols[(pal + k * 2 + 1) % cols.size()], 0.95, k * 0.4)
	b.door = Vector3(-1.25, 0, 1.2)


## Товар и утварь ремесла; t — середина прилавка
static func _goods(b: Bp, type: String, t: Vector3, pal: int) -> void:
	var top := t + Vector3(0, CTR, 0)
	match type:
		"butcher":
			# окорока гроздью и колбасы на перекладине, куски мяса на блюде, колода для рубки, кувшины соли
			b.add_xf("SM_Prop_Beam_01", Transform3D(Basis.from_scale(Vector3(2.3 / 2.5, 0.6, 0.6)), Vector3(0.1, 2.3, 1.45)))
			for k in 3:
				_ham(b, Vector3(1.35 + k * 0.4, 2.28, 1.45), k)
			for k in 2:
				_sausage(b, Vector3(0.5 + k * 0.25, 2.28, 1.45), k)
			b.add("SM_Prop_Plate_02", top + Vector3(-0.5, 0, 0), 0.0, 1.0)
			_put(b, "SM_Prop_Basket_Insert_04", top + Vector3(-0.5, 0.04, 0), 0.2, 0.55, {"tint": T_MEAT})
			_put(b, "SM_Prop_Basket_Insert_04", top + Vector3(0.15, 0.0, 0.03), -0.3, 0.45, {"tint": T_MEAT})
			b.add("SM_Prop_Bowl_04", top + Vector3(0.62, 0, 0), 0.0, 0.8)
			b.add("SM_Prop_Jug_05", top + Vector3(0.88, 0, -0.05), 0.0, 0.75)
			b.add("SM_Prop_Stool_01", Vector3(-0.45, 0, 1.0), 0.4, 1.1)
			b.add("SM_Prop_Jar_Pile_01", Vector3(-2.05, 0, 1.1), 0.0, 0.5)
		"potter":
			# печь для обжига справа от прилавка (дым и огонь в устье), амфоры горой у входа, вазы и миски на прилавке
			# (печь ставится в x / SX: после сжатия лавки она остаётся в 1,64 от середины — гончар у прилавка её не задевает)
			var kx := 1.64 / SX
			b.add("SM_Prop_Kiln_01", Vector3(kx, 0, 0.72), PI, 0.42)
			b.smoke.insert(0, b.base * Vector3(kx, 0.85, 0.72))
			b.light(Vector3(kx, 0.35, 1.25))
			b.add("SM_Prop_Vase_Pile_02", Vector3(-2.1, 0, 1.12), 0.0, 0.42)
			b.add("SM_Prop_Vase_0%d" % (1 + pal % 6), top + Vector3(-0.85, 0, 0), 0.0, 0.4)
			b.add("SM_Prop_Jug_0%d" % (1 + (pal + 2) % 6), top + Vector3(-0.5, 0, 0.0), 0.4, 0.5)
			b.add("SM_Prop_Bowl_04", top + Vector3(-0.15, 0, 0), 0.0, 0.8)
			b.add("SM_Prop_Vase_06", top + Vector3(0.12, 0, 0.02), 0.6, 0.4)
			b.add("SM_Prop_Vase_03", Vector3(-0.35, 0, 1.45), 0.3, 0.5)
			b.add("SM_Prop_Vase_05", Vector3(-0.05, 0, 1.15), 0.9, 0.45)
		"barber":
			# кресло для бритья под навесом (клиент сидит в (1,25; 1,0) уже сжатой лавки), на прилавке таз, кувшин,
			# полотенце, масло и зеркальце; скамья для ждущих — сиденье в рост людей
			b.add("SM_Prop_Seat_Chair_01", Vector3(1.25 / SX, 0, 1.0), PI, 1.0)
			b.add("SM_Prop_Bowl_04", Vector3(-1.75, CTR, 1.42), 0.0, 1.0)
			b.add("SM_Prop_Jug_05", Vector3(-1.3, CTR, 1.42), 0.0, 0.9)
			_put(b, "SM_Prop_Rug_Folded_02", Vector3(-0.9, CTR, 1.42), 0.3, 0.4, _rug("03_A"))
			b.add("SM_Prop_Goblet_01", Vector3(-0.55, CTR, 1.45), 0.0, 1.0)
			_put(b, "SM_Prop_Plate_03", Vector3(-2.0, CTR + 0.01, 1.48), 0.0, 1.0, GILT)
			b.add_xf("SM_Prop_Seat_Bench_05", Transform3D(Basis(Vector3.UP, PI / 2) * Basis.from_scale(Vector3(0.5, SEAT, 0.75)), Vector3(0.3, 0, 0.42)))
			b.add("SM_Prop_FlowerPot_Fancy_01", Vector3(2.2, 0, 0.45), 0.0, 0.55)
		"cobbler":
			# кожи висят на балке, сандалии в корзинах, сложенная кожа и молоток на прилавке, наковальня и табурет
			_put(b, "SM_Prop_Rug_Drape_01", Vector3(2.05, 2.45, 1.38), PI, 0.65, _rug("02_A"))
			_put(b, "SM_Prop_Rug_Drape_01", Vector3(0.75, 2.45, 1.38), PI, 0.6, _rug("01_A"))
			_put(b, "SM_Prop_Rug_Folded_03", top + Vector3(-0.45, 0, 0), 0.2, 0.5, _rug("02_A"))
			b.add("SM_Prop_Basket_06", top + Vector3(0.35, 0, 0), 0.3, 0.55)
			b.add("SM_Prop_Basket_12", top + Vector3(0.75, 0, 0.02), -0.2, 0.7)
			b.add("SM_Prop_Tool_Hammer_01", top + Vector3(-0.05, 0.07, 0.05), 0.8, 1.2)
			b.add("SM_Prop_Anvil_01", Vector3(-0.45, 0, 0.85), 0.4, 0.5)
			b.add("SM_Prop_Seat_Chair_01", Vector3(-0.45, 0, 0.35), 0.3, 0.9)
		"weaver":
			# ткацкий станок между колоннами (ткачиха за ним), стопки тканей, полотна на балке портика
			_put(b, "SM_Prop_Loom_01", Vector3(1.25, 0, 0.92), 0.0, 0.72, _rug(["01_B", "02_B", "01_A", "03_B"][pal % 4]))
			_put(b, "SM_Prop_Rug_Stack_01", Vector3(-0.45, 0, 0.9), 0.2, 0.5, _rug("03_B"))
			_put(b, "SM_Prop_Rug_Stack_02", Vector3(-0.4, 0.4, 0.9), -0.3, 0.45, _rug("03_A"))
			_sheet(b, Vector3(2.1, 2.5, 1.42), 0.7, 0.9, [RED, BLUE, MUSTARD, PURPLE][pal % 4])
			_sheet(b, Vector3(0.4, 2.5, 1.42), 0.7, 0.8, [SKY, MUSTARD, GREEN, RED][pal % 4])
			b.add("SM_Prop_Basket_Set_03", Vector3(-0.2, 0, 0.55), 0.0, 0.4)
		"bakery":
			# хлебы в корзинах на прилавке, мешки муки у входа (печь — в проёме лавки)
			_basket(b, top + Vector3(-0.6, 0, 0), "bread", 0.42)
			_basket(b, top + Vector3(0.0, 0, 0.02), "bread", 0.4, 1.2)
			_basket(b, top + Vector3(0.6, 0, 0), "bread", 0.38, 2.1)
			b.add("SM_Prop_Sack_Stack_01", Vector3(-2.15, 0, 0.6), 1.3, 0.42)
			b.add("SM_Prop_Sack_04", Vector3(-0.35, 0, 0.55), 0.5, 0.75)
		"wineshop":
			# амфоры горкой, кувшины и кубки на прилавке, лоза над входом
			for k in 3:
				b.add("SM_Prop_Jug_0%d" % (1 + (k + pal) % 4), top + Vector3(-0.7 + k * 0.42, 0, 0), k * 0.6, 0.46)
			b.add("SM_Prop_Goblet_01", top + Vector3(0.55, 0, 0.0), 0.0, 0.9)
			b.add("SM_Prop_Goblet_02", top + Vector3(0.78, 0, 0.05), 0.0, 0.9)
			b.add("SM_Prop_Jar_Pile_01", Vector3(-2.0, 0, 1.0), 0.3, 0.5)
			b.add("SM_Prop_Vase_01", Vector3(2.2, 0, 1.65), 0.0, 0.5)
			b.add("SM_Prop_Vase_05", Vector3(1.9, 0, 1.8), 0.6, 0.45)
			b.add("SM_Env_Vine_0%d" % (1 + pal % 3), Vector3(-1.25, 2.95, 0.35), 0.0, 0.45)
		"oilshop":
			# долии с маслом у входа, маслины в корзине и кувшины на прилавке, бронзовая олива, деревце в кадке
			_basket(b, top + Vector3(-0.55, 0, 0), "olives", 0.42)
			b.add("SM_Prop_Jug_02", top + Vector3(0.05, 0, 0), 0.0, 0.46)
			b.add("SM_Prop_Jug_06", top + Vector3(0.45, 0, 0.0), 0.0, 0.46)
			b.add("SM_Prop_Bowl_04", top + Vector3(0.82, 0, 0.0), 0.0, 0.75)
			b.add("SM_Prop_Jar_01", Vector3(-0.45, 0, 0.75), 0.0, 0.85)
			b.add("SM_Prop_Jar_01", Vector3(-2.1, 0, 0.8), 0.8, 0.75)
			_put(b, "SM_Prop_Symbol_18", Vector3(1.25, 2.95, 0.14), 0.0, 0.42, BRONZE)
			b.add("SM_Prop_Vase_04", Vector3(-0.25, 0, 1.3), 0.0, 0.75)
			b.add("SM_Env_Tree_Bush_0%d" % (1 + pal % 3), Vector3(-0.25, 0.4, 1.3), 0.0, 0.22)
		"lamps":
			# светильники рядком под навесом, канделябры у входа, лампы на прилавке — ночью лавка вся светится
			for k in 5:
				b.add("SM_Prop_Senser_04", top + Vector3(-0.8 + k * 0.4, 0, 0), k * 0.5, 0.4)
			for k in 3:
				_hanging_lamp(b, Vector3(0.5 + k * 0.75, 2.42, 1.15), 0.6, k == 1)
			b.add("SM_Prop_Senser_02", Vector3(-0.45, 0, 0.7), 0.0, 1.25)
			b.add("SM_Prop_Senser_01", Vector3(-2.15, 0, 0.8), 0.0, 0.7)
			b.add("SM_Prop_Senser_02", Vector3(-2.25, 0, 1.3), 0.0, 1.0)
		"medic":
			# травы в горшках у входа и сухие пучки под навесом, свитки, чаша, ступка и склянки на прилавке
			b.add("SM_Prop_Scroll_Pile_0%d" % (1 + pal % 6), top + Vector3(-0.55, 0, 0), 0.3, 0.5)
			b.add("SM_Prop_Bowl_04", top + Vector3(0.05, 0, 0), 0.0, 0.7)
			b.add("SM_Prop_Vase_04", top + Vector3(0.45, 0, 0), 0.0, 0.42)
			_put(b, "SM_Env_Garden_Plants_0%d" % (3 + pal % 4), top + Vector3(0.45, 0.22, 0), 0.0, 0.18)
			b.add("SM_Prop_Jug_05", top + Vector3(0.82, 0, 0.02), 0.0, 0.75)
			for k in 2:
				b.add("SM_Prop_Vase_04", Vector3(-0.25 - k * 2.0, 0, 1.3), 0.0, 0.55)
				b.add("SM_Env_Garden_Plants_0%d" % (3 + (pal + k) % 4), Vector3(-0.25 - k * 2.0, 0.32, 1.3), k * 1.3, 0.26)
			for k in 3:
				_put_xf(b, "SM_Prop_Straw_Bundle_01", Transform3D(Basis(Vector3.UP, k * 0.9) * Basis(Vector3.RIGHT, PI) * Basis.from_scale(Vector3.ONE * 0.3), Vector3(0.6 + k * 0.6, 2.28, 1.48)), {"tint": [T_GREEN, T_OLIVE, Color(0.9, 0.8, 0.5)][k]})
		"perfumer":
			# мраморный столик с флаконами, курильница с дымком благовоний, высокие амфоры с маслами,
			# подушки и ковёр для покупательниц, цветник между колоннами
			b.add("SM_Prop_Table_03", t + Vector3(0, 0, -0.2), 0.0, 0.7)
			b.add("SM_Prop_Goblet_01", t + Vector3(-0.2, 0.55, -0.2), 0.0, 1.0)
			b.add("SM_Prop_Jug_05", t + Vector3(0.15, 0.55, -0.1), 0.0, 0.8)
			b.add("SM_Prop_Goblet_02", t + Vector3(0.1, 0.55, -0.4), 0.0, 1.0)
			b.add("SM_Prop_Senser_02", Vector3(-0.35, 0, 0.25), 0.0, 1.1)
			b.light(Vector3(-0.35, 0.95, 0.25))
			_put(b, "SM_Prop_Rug_03", Vector3(-1.25, 0.01, -0.35), 0.0, 0.75, _rug("03_A"))
			_put(b, "SM_Prop_Pillow_Pile_02", Vector3(-1.4, 0.02, -0.45), 0.4, 0.6, _rug("01_A"))
			b.add("SM_Prop_Vase_01", Vector3(-2.15, 0, -0.75), 0.0, 0.55)
			b.add("SM_Prop_Vase_05", Vector3(-1.8, 0, -0.95), 0.6, 0.5)
			b.add("SM_Prop_FlowerBed_0%d" % (1 + pal % 2), Vector3(-1.1, 0.29, 0.95), 0.0, 0.7)
			b.add("SM_Env_Flowers_0%d" % (1 + pal % 5), Vector3(1.1, 0.01, 1.05), 0.0, 1.1)
		"jeweler":
			# столик на золочёных ножках с кубками и золотой чашей, бюст на постаменте, золотые блюда на мраморной тумбе,
			# медальоны на стене, ковёр
			b.add("SM_Prop_Table_04", t + Vector3(0, 0, -0.15), 0.0, 0.9)
			b.add("SM_Prop_Goblet_01", t + Vector3(-0.15, 0.7, -0.15), 0.0, 1.0)
			b.add("SM_Prop_Goblet_02", t + Vector3(0.15, 0.7, -0.05), 0.0, 1.0)
			_put(b, "SM_Prop_Bowl_04", t + Vector3(0.0, 0.7, -0.35), 0.0, 0.6, GILT)
			b.add("SM_Prop_Plinth_02", Vector3(-1.4, 0, 0.35), 0.0, 0.9)
			b.add("SM_Prop_Statue_0%d" % (1 + pal % 7), Vector3(-1.4, 0.9, 0.35), 0.0, 0.32)
			b.add("SM_Prop_Plinth_04", Vector3(-0.55, 0, -0.75), 0.0, 0.75)
			_put(b, "SM_Prop_Plate_02", Vector3(-0.55, 0.52, -0.75), 0.3, 0.6, GILT)
			_put(b, "SM_Prop_Jug_05", Vector3(-0.35, 0.52, -0.65), 0.0, 0.7, GILT)
			for x: float in [-1.85, -0.65]:
				b.add("SM_Bld_Ornament_0%d" % [1, 2, 6][pal % 3], Vector3(x, 2.15, -1.12), 0.0, 0.55)
			_put(b, "SM_Prop_Rug_04", Vector3(1.25, 0.01, 0.2), PI / 2, 0.8, _rug("02_B"))
			b.add("SM_Prop_Seat_Chair_02", Vector3(-2.0, 0, -0.5), 0.6, 0.7)
		"tailor":
			# белые и пурпурные тоги на раме, рулоны тканей на столе, ковёр
			b.add("SM_Prop_Table_05", t + Vector3(0.1, 0, 0), PI / 2, 0.85)
			_put(b, "SM_Prop_Rug_Folded_01", t + Vector3(-0.1, 0.66, 0.0), 0.2, 0.5, _rug("03_A"))
			_put(b, "SM_Prop_Rug_Folded_02", t + Vector3(0.35, 0.66, 0.0), -0.1, 0.45, _rug("03_B"))
			for x: float in [-2.0, -0.45]:
				_pole(b, Vector3(x, 0, -0.55), 2.1)
			b.add_xf("SM_Prop_Beam_01", Transform3D(Basis.from_scale(Vector3(1.55 / 2.5, 0.7, 0.7)), Vector3(-2.0, 2.05, -0.55)))
			_sheet(b, Vector3(-1.6, 2.05, -0.55), 0.65, 1.5, WHITE)
			_sheet(b, Vector3(-0.85, 2.05, -0.55), 0.6, 1.35, PURPLE)
			_put(b, "SM_Prop_Rug_Stack_02", Vector3(2.0, 0, 1.7), 0.3, 0.5, _rug("02_A"))


# ---------- еда и вино ----------

## Термополий: закусочная 7,5×2,5 м в два этажа. Внизу Г-образная расписная стойка с вделанными кувшинами под
## черепичным портиком на колоннах; наверху окна с фронтонами, дверь на балкончик с перилами, цветы
static func _thermopolium(b: Bp) -> void:
	var pal := _pal(b)
	_hold.clear()
	_paint(b, pal)
	b.ground_style = "plain"
	var bw := _back_win(pal)
	_box(b, -3.75, 3.75, -2.5, 0.0, [
		{0: [SHOP, SHOP, DOOR], 1: ["SM_Bld_Wall_Window_06"], 3: ["SM_Bld_Wall_Window_06"], 2: [bw, DOOR, bw]},
		{0: ["SM_Bld_Wall_Window_05", DOOR, "SM_Bld_Wall_Window_05"], 1: ["SM_Bld_Wall_Window_02"], 3: ["SM_Bld_Wall_Window_02"], 2: ["SM_Bld_Wall_Window_02", W1, "SM_Bld_Wall_Window_02"]}],
		{"cornice": "SM_Bld_Trim_04", "dark": 1.4})
	_ivy(b, -3.75, 3.75, -2.5, 0.0, 2, 0.12, 1.4, pal)
	_roof_x(b, -3.75, 3.75, -2.5, 0.0, 2 * FL, 2.0, _topper(pal))
	_chimney(b, Vector3(-2.6, 2 * FL + 0.6, -1.9))
	_porch(b, -3.75, 3.75, 1.6, 0.0, 2.35, 4)
	# верх: балкончик-перила у двери, цветы под окнами
	b.add("SM_Bld_Wall_Balcony_03", Vector3(-1.25, FL, 0.16), 0.0, 1.0, true)
	for i: float in [0.5, 2.5]:
		_pot(b, -3.75, 3.75, -2.5, 0.0, 0, i, FL + 1.0, pal + int(i))
	# стойка: длинная вдоль улицы и колено к стене, расписная, в столешнице — кувшины с горячей едой
	# (стойка отодвинута от стены на 0,56 — за ней помещается продавец)
	var ctop := _counter(b, -3.4, 0.2, 1.15, true)
	b.add_xf("SM_Bld_Wall_Balcony_06", Transform3D(Basis(Vector3.UP, -PI / 2) * Basis.from_scale(Vector3(0.6 / 2.5, ctop / 1.02, 1.0)), Vector3(-3.4, 0, 0.0)), true)
	for k in 4:
		b.add("SM_Prop_Jar_01", Vector3(-2.95 + k * 0.8, ctop - 0.2, 0.86), k * 0.9, 0.42)
	b.add("SM_Prop_Brazier_04", Vector3(-0.15, ctop, 0.86), 0.0, 0.4)
	b.add("SM_Prop_Brazier_04_Insert_01", Vector3(-0.15, ctop, 0.86), 0.0, 0.4)
	b.light(Vector3(-0.15, ctop + 0.4, 1.0))
	for k in 2:
		b.add("SM_Prop_Pots_Hanging_0%d" % (1 + k % 2), Vector3(-2.6 + k * 1.7, 2.3, 1.45), k * 0.8)
	# роспись-ларарий на стене за стойкой, знамя-вывеска, табуреты для посетителей, столик у двери
	_put(b, "SM_Prop_Mural_02", Vector3(-1.25, 1.75, 0.13), 0.0, 0.42, {"Mural_01": "mural_08"})
	_sign(b, Vector3(1.25, 2.8, 0.14), 0.0, "B", ACCENT[pal], 0.62)
	_lamp(b, Vector3(3.35, 2.15, 0.12))
	# табуреты у стойки — между колоннами портика, не задевая их; столик в полную высоту
	for k in 2:
		b.add("SM_Prop_Seat_Chair_01", Vector3([-2.3, -0.55][k], 0, 1.42), k * 0.5 - 0.3, 0.95)
	_table(b, Vector3(3.3, 0, 1.0))
	b.add("SM_Prop_Seat_Chair_01", Vector3(3.3, 0, 0.4), 0.0, 0.95)
	b.add("SM_Prop_Jug_0%d" % (1 + pal % 4), Vector3(3.2, TABLE7, 1.0), 0.0, 0.42)
	b.add("SM_Prop_Bowl_04", Vector3(3.45, TABLE7, 0.92), 0.0, 0.6)
	b.door = Vector3(-1.0, 0, 2.5)
	_narrow(b)


## Таверна 7,5×5 м в два этажа с балконом; перед ней дворик под перголой с прямыми рейками — лоза на рейках,
## цветущий плющ свисает с балки, столы, лампы, жаровня
static func _taberna(b: Bp) -> void:
	var pal := _pal(b)
	_hold.clear()
	_paint(b, pal)
	b.ground_style = "brick"
	var bw := _back_win(pal)
	_box(b, -3.75, 3.75, -5.0, -2.5, [
		{0: [SHOP, "SM_Bld_Wall_Door_Double_01", SHOP], 1: ["SM_Bld_Wall_Window_06"], 3: ["SM_Bld_Wall_Window_06"], 2: [bw, DOOR, bw]},
		{0: ["SM_Bld_Wall_Window_05", DOOR, "SM_Bld_Wall_Window_05"], 1: ["SM_Bld_Wall_Window_02"], 3: ["SM_Bld_Wall_Window_02"], 2: ["SM_Bld_Wall_Window_02", "SM_Bld_Wall_Window_05", "SM_Bld_Wall_Window_02"]}],
		{"cornice": "SM_Bld_Trim_04", "dark": 1.0})
	_roof_x(b, -3.75, 3.75, -5.0, -2.5, 2 * FL, 2.2, _topper(pal + 1))
	_chimney(b, Vector3(2.4, 2 * FL + 0.5, -4.2))
	b.add("SM_Bld_Balcony_01", Vector3(0.0, FL, -2.39), 0.0)
	_put(b, "SM_Prop_Rug_Drape_01", Vector3(0.5, FL + 0.95, -1.5), PI, 0.8, _rug(["01_B", "03_A", "01_C"][pal % 3]))
	b.add("SM_Prop_FlowerPot_Hanging_0%d" % (4 + pal % 3), Vector3(-2.5, FL + 1.0, -2.37), 0.0, 0.6)
	b.add("SM_Prop_FlowerPot_Hanging_0%d" % (4 + (pal + 1) % 3), Vector3(2.5, FL + 1.0, -2.37), 0.0, 0.6)
	# дворик: колонны, балка, пергола из прямых реек от дома к колоннам, лоза поверх реек, плющ с балки
	for c: Vector3 in [Vector3(-3.5, 0, 2.1), Vector3(0.0, 0, 2.1), Vector3(3.5, 0, 2.1)]:
		b.add_xf("SM_Bld_Pillar_06", Transform3D(Basis.from_scale(Vector3(0.85, 0.9, 0.85)), c))
	b.add_xf("SM_Prop_Beam_01", Transform3D(Basis.from_scale(Vector3(3.0, 1.6, 1.6)), Vector3(-3.75, 2.62, 2.1)))
	for i in 3:
		b.add_xf("SM_Bld_Trellis_Roof_02", Transform3D(Basis(Vector3.UP, PI / 2) * Basis.from_scale(Vector3(2.0, 1.0, 1.0)), Vector3(-3.75 + i * M, 2.72, -2.5)))
	for k in 4:
		_vine_flat(b, Vector3([-2.5, -0.7, 1.1, 2.7][k], 3.0, [-1.3, 1.0, -0.9, 1.1][k]), [0.4, 2.2, 1.1, 3.6][k] + pal * 0.3, pal + k, 0.85)
	for x: float in [-1.9, 1.9]:
		b.add("SM_Env_Ivy_Draped_Flowers_03", Vector3(x, 2.78, 2.12), 0.0)
	for s: float in [-1.0, 1.0]:
		b.add("SM_Env_Ivy_Draped_Flowers_01", Vector3(3.72 * s, 2.86, 0.0), PI / 2, 0.85)
	b.add("SM_Env_Ivy_Pillar_Flowers_0%d" % (1 + pal % 2), Vector3(-3.5, 0, 2.1), 0.5, 0.9)
	b.add("SM_Env_Ivy_Pillar_Flowers_0%d" % (1 + (pal + 1) % 2), Vector3(3.5, 0, 2.1), 1.5, 0.9)
	# круглые деревянные столики со складными табуретами и длинный стол со скамьями — в рост посетителей
	# (табуреты ставятся в x / SX: после сжатия двора они остаются в 0,65 от столика, а не врезаются в него)
	for c: Vector3 in [Vector3(-2.2, 0, -0.9), Vector3(1.9, 0, -1.1)]:
		_table(b, c)
		b.add("SM_Prop_Seat_Chair_01", c + Vector3(-0.65 / SX, 0, 0.05), PI / 2, 0.95)
		b.add("SM_Prop_Seat_Chair_01", c + Vector3(0.65 / SX, 0, -0.05), PI / 2, 0.95)
		b.add("SM_Prop_Jug_0%d" % (1 + b.rng.randi() % 4), c + Vector3(0.1, TABLE7, 0), 0.0, 0.42)
	_put_xf(b, "SM_Prop_Table_08", Transform3D(Basis.from_scale(Vector3(0.62, 0.95, 0.75)), Vector3(-0.3, 0, 0.55)))
	for z: float in [-0.08, 1.18]:
		_put_xf(b, "SM_Prop_Seat_Bench_05", Transform3D(Basis.from_scale(Vector3(0.6, SEAT, 0.8)), Vector3(-0.3, 0, z)))
	var lt := 0.78 * 0.95
	b.add("SM_Prop_Plate_02", Vector3(-0.7, lt, 0.55), 0.0, 0.6)
	b.add("SM_Prop_Jug_05", Vector3(-0.2, lt, 0.5), 0.0, 0.8)
	b.add("SM_Prop_Goblet_02", Vector3(0.25, lt, 0.6), 0.0, 0.9)
	b.add("SM_Prop_Vase_Pile_02", Vector3(3.0, 0, -2.0), 0.6, 0.55)
	b.add("SM_Prop_Jar_Pile_01", Vector3(-3.1, 0, -1.9), 0.0, 0.55)
	_hanging_lamp(b, Vector3(-1.8, 2.7, -0.3), 0.5)
	_hanging_lamp(b, Vector3(1.8, 2.7, 0.3), 0.5, false)
	b.brazier(Vector3(-3.0, 0, 1.0))
	_sign(b, Vector3(-2.5, 2.8, -2.36), 0.0, "B", ACCENT[pal], 0.62)
	b.door = Vector3(0, 0, 3.2)
	_narrow(b)


# ---------- ремёсла и забавы ----------

## Фуллоника (прачечная): двухэтажный дом с черепичной крышей и пристройка с кровлей-сушилкой (деревянные перила,
## тоги на перекладине); перед пристройкой верёвка с бельём, перед домом чаны в низкой каменной ванне
static func _fullonica(b: Bp) -> void:
	var pal := _pal(b)
	_hold.clear()
	_paint(b, pal)
	b.ground_style = "plain"
	# основной дом 5×2,5 м, два этажа, фронтоном к улице
	_box(b, -3.75, 1.25, -2.5, 0.0, [{0: [DOOR, SHOP], 1: [W1], 3: ["SM_Bld_Wall_Window_06"], 2: [_back_win(pal), DOOR]},
		{0: ["SM_Bld_Wall_Window_05", "SM_Bld_Wall_Window_02"], 1: ["SM_Bld_Wall_Window_06"], 3: ["SM_Bld_Wall_Window_02"], 2: ["SM_Bld_Wall_Window_02", "SM_Bld_Wall_Window_01"]}],
		{"cornice": "SM_Bld_Trim_03", "dark": 1.4})
	var ridge := _roof_z(b, -3.75, 1.25, -2.5, 0.0, 2 * FL, 1.6)
	b.add(_topper(pal), Vector3(-1.25, ridge, 0.1), 0.0)
	_chimney(b, Vector3(-0.1, 2 * FL + 0.2, -1.9))
	b.window_pots(-1.25, -1.25, 2, 1, 1)
	_ivy(b, -3.75, 1.25, -2.5, 0.0, 2, 1.88, 1.5, pal + 2)
	# пристройка 2,5×2,5 м: кровля-сушилка с деревянными перилами, окно с цветами
	_box(b, 1.25, 3.75, -2.5, 0.0, [{0: ["SM_Bld_Wall_Window_01"], 1: [W1], 2: [W1], 3: [""]}], {"cornice": "SM_Bld_Trim_01", "top": false, "dark": 0.3})
	_pot(b, 1.25, 3.75, -2.5, 0.0, 0, 0.5, 0.95, pal)
	_terrace(b, 1.25, 3.75, -2.5, 0.0, FL, [0, 1, 2], "SM_Bld_Wall_Balcony_03")
	for x: float in [1.55, 3.45]:
		_pole(b, Vector3(x, FL, -1.25), 1.9)
	b.add_xf("SM_Prop_Beam_01", Transform3D(Basis.from_scale(Vector3(1.9 / 2.5, 0.7, 0.7)), Vector3(1.55, FL + 1.85, -1.25)))
	_sheet(b, Vector3(2.05, FL + 1.85, -1.25), 0.8, 1.2, WHITE)
	_sheet(b, Vector3(2.95, FL + 1.85, -1.25), 0.75, 1.05, [MUSTARD, WHITE, SKY][pal % 3])
	b.add("SM_Env_Ivy_Draped_Flowers_0%d" % (1 + pal % 3), Vector3(1.6, FL + 0.05, 0.1), 0.0, 0.9)
	# двор: верёвка с бельём перед пристройкой (двери свободны), каменная ванна с тремя чанами, корзины белья
	for x: float in [1.05, 3.5]:
		_pole(b, Vector3(x, 0, 0.42), 2.1)
	b.add_xf("SM_Prop_Beam_01", Transform3D(Basis.from_scale(Vector3(2.45 / 2.5, 0.7, 0.7)), Vector3(1.05, 2.05, 0.42)))
	for k in 3:
		_sheet(b, Vector3(1.5 + k * 0.78, 2.05, 0.42), 0.68, 1.1 - (k % 2) * 0.15, [WHITE, [SKY, PINK, MUSTARD][pal % 3], WHITE][k])
	_counter(b, -0.75, 3.65, 1.75, false, 0.42)
	for k in 3:
		_vat(b, Vector3(-0.05 + k * 1.3, 0.0, 1.05), [SKY, WHITE, SKY][k], 0.95, k * 0.6)
	b.add("SM_Prop_Basket_Set_02", Vector3(-0.9, 0, 0.45), 0.4, 0.45)
	b.add("SM_Prop_Basket_08", Vector3(-0.35, 0, 0.5), 0.0, 0.7)
	_trade_shelf(b, "tailor", -1.25, 0.0, pal + 1)
	_sign(b, Vector3(-0.75, 2.85, 0.14), 0.0, "A", SKY, 0.55)
	_lamp(b, Vector3(-1.6, 2.2, 0.12))
	b.door = Vector3(-2.5, 0, 2.2)
	_narrow(b)


## Уличные музыканты: скамья под деревом, лира, корзина для монет, коврик
static func _musicians(b: Bp) -> void:
	var pal := _pal(b)
	_put_xf(b, "SM_Prop_Seat_Bench_05", Transform3D(Basis.from_scale(Vector3(0.75, SEAT, 0.85)), Vector3(-0.3, 0, -0.65)))
	_put(b, "SM_Prop_Rug_0%d" % (1 + pal % 4), Vector3(0.1, 0.01, 0.2), PI / 2, 0.55, _rug(["01_A", "01_B", "03_A", "02_B"][pal % 4]))
	b.add("SM_Prop_Basket_0%d" % (1 + pal % 4), Vector3(0.0, 0, 0.95), 0.0, 0.5)
	b.add_xf("SM_Prop_Lyre_01", Transform3D(Basis(Vector3.UP, 0.4) * Basis(Vector3.RIGHT, -0.25), Vector3(0.45, 0.42, -0.75)))
	b.add("SM_Env_Tree_0%d" % (1 + pal % 4), Vector3(-1.2, 0, -1.3), pal * 0.9, 0.33)
	b.add("SM_Prop_FlowerPot_Fancy_01", Vector3(1.25, 0, -1.05), 0.0, 0.55)
	b.add("SM_Prop_Stool_01", Vector3(-1.25, 0, 0.1), 0.6, 0.9)
	b.add("SM_Prop_Jug_0%d" % (1 + pal % 4), Vector3(-1.3, 0.3, 0.05), 0.0, 0.4)
	b.add("SM_Prop_Goblet_01", Vector3(-1.1, 0.3, 0.2), 0.0, 0.8)
	b.add("SM_Prop_Senser_02", Vector3(1.15, 0, 0.35), 0.0, 1.2)
	b.light(Vector3(1.15, 1.0, 0.35))
	b.door = Vector3(0, 0, 1.4)


## Игра в кости: столик под полосатым навесом (цвет с белым, как у рыночных лавок), табуреты вокруг, кубок и кувшин
static func _dice(b: Bp) -> void:
	var pal := _pal(b)
	var hb := 2.8
	var hf := 2.4
	for x: float in [-1.2, 1.2]:
		_pole(b, Vector3(x, 0, -1.15), hb)
		_pole(b, Vector3(x, 0, 1.15), hf)
	_awning(b, -1.32, 1.32, -1.3, 1.3, hb + 0.05, hf - 0.05, [RED, BLUE, PURPLE, GREEN][pal % 4], WHITE)
	_table(b, Vector3.ZERO, 1.15)
	for a in 4:
		var q := Vector3(cos(a * PI / 2), 0, sin(a * PI / 2)) * 0.95
		b.add("SM_Prop_Seat_Chair_01", q, a * PI / 2, 0.92)
	b.add("SM_Prop_Goblet_01", Vector3(0.15, TABLE7, 0.1), 0.0, 0.9)
	b.add("SM_Prop_Plate_03", Vector3(-0.15, TABLE7, -0.1), 0.0, 0.6)
	b.add("SM_Prop_Bowl_04", Vector3(0.0, TABLE7, -0.2), 0.0, 0.45)
	b.add("SM_Prop_Jug_02", Vector3(1.6, 0, 1.0), 0.0, 0.55)
	b.add("SM_Prop_Vase_04", Vector3(-1.6, 0, 0.9), 0.0, 0.6)
	b.door = Vector3(0, 0, 1.9)


## Помост мимов: деревянная сцена с ковром и гирляндой-занавесом по краю, задник — большое знамя на шестах с факелами,
## по краям жаровни, перед сценой скамьи для зрителей
static func _mimes(b: Bp) -> void:
	var pal := _pal(b)
	# сцена 5×2,5 м на высоте 0,7: дощатый настил на тёмном основании, ковёр посередине, спереди гирлянда
	b.parts.append(["#dark", Transform3D(Basis.IDENTITY.scaled(Vector3(4.9, 0.66, 2.4)), Vector3(0, 0.33, -1.7)), {}])
	for k in 2:
		b.add("SM_Bld_Trellis_Roof_01", Vector3(k * M, 0.42, -2.9), 0.0)
	_put(b, "SM_Prop_Rug_01", Vector3(0, 0.71, -1.65), PI / 2, 1.0, _rug(["01_A", "03_A", "01_B", "02_B"][pal % 4]))
	for k in 2:
		_put(b, "SM_Prop_Drapery_0%d" % (1 + (k + pal) % 3), Vector3(-1.25 + k * M, 0.68, -0.42), 0.0, 1.0, _cloth(ACCENT[pal]))
	# задник: знамя на двух шестах, на шестах факелы
	for x: float in [-2.4, 2.4]:
		_pole(b, Vector3(x, 0, -2.9), 3.8)
		b.add("SM_Prop_Torch_01", Vector3(x, 2.75, -2.76), 0.0, 1.5)
		b.light(Vector3(x, 3.1, -2.6))
	_put(b, "SM_Prop_Banner_04_A", Vector3(0, 3.55, -2.95), 0.0, 0.98, _cloth(ACCENT[pal]))
	_put(b, "SM_Prop_Drapery_0%d" % (1 + pal % 3), Vector3(-1.25, 3.75, -2.9), 0.0, 1.0, _cloth(ACCENT[(pal + 2) % ACCENT.size()]))
	_put(b, "SM_Prop_Drapery_0%d" % (1 + pal % 3), Vector3(1.25, 3.75, -2.9), 0.0, 1.0, _cloth(ACCENT[(pal + 2) % ACCENT.size()]))
	# реквизит на сцене: сундук-корзина, амфора, лира
	b.add("SM_Prop_Basket_10", Vector3(-1.8, 0.7, -2.4), 0.3, 0.6)
	b.add("SM_Prop_Vase_02", Vector3(1.9, 0.7, -2.5), 0.0, 0.6)
	b.add_xf("SM_Prop_Lyre_01", Transform3D(Basis(Vector3.UP, -0.3) * Basis(Vector3.RIGHT, -0.2), Vector3(-1.45, 1.1, -2.6)))
	# зрители; жаровни по краям (свет от факелов на заднике)
	for c: Vector3 in [Vector3(-1.3, 0, 1.3), Vector3(1.3, 0, 1.3), Vector3(0, 0, 2.4)]:
		_put_xf(b, "SM_Prop_Seat_Bench_05", Transform3D(Basis.from_scale(Vector3(0.75, SEAT, 0.9)), c))
	for x: float in [-2.75, 2.75]:
		b.add("SM_Prop_Brazier_03", Vector3(x, 0, 0.1), 0.0)
		b.add("SM_Prop_Brazier_03_Insert_01", Vector3(x, 0, 0.1), 0.0)
	b.door = Vector3(0, 0, 3.2)
