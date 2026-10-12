class_name CatMonuments
extends RefCounted
## Облик построек (Памятники: фонтан, храм, форум, арка, амфитеатр, пантеон). Чертёж Bp строится в родных размерах Synty;
## Catalog.make потом уменьшает его до «кукольного» масштаба (Catalog.ARCH).
## Памятники — главные красоты города: мрамор, колонны, фронтоны со статуями, жаровни, знамёна, цветы и кипарисы.

const M := Bp.M
const FL := Bp.FL

## Подмена картинок (раскраска деталей Synty)
const MARBLE_WALL := {"Stucco_White_01": "Building_Marble_01"}        # стена из штукатурки → белый мрамор
const RED_WALL := {"Stucco_White_01": "Stucco_Red_01"}                # помпейский красный
const STONE_WALL := {"Stucco_White_01": "Stone_01"}                   # травертин
const MARBLE_BLOCKS := {"Building_Large_Brick_01": "Building_Marble_03"}
const PAVING := {"Stone_01": "Floor_Tiles_06"}                        # большие плиты травертина
const MOSAIC := {"Stone_01": "Floor_Tiles_Circle_01"}                 # круглая мозаика
const CAP_MARBLE := {"Stucco_Blue_01": "Building_Marble_02"}          # синяя капитель → мрамор
const FRIEZE_RED := {"Stucco_Blue_01": "Building_Marble_03"}          # расписной фриз: красный с мрамором
const DOME_LEAD := {"Stucco_Blue_01": "Stucco_White_01", "tints": {"Stucco_White_01": Color(0.67, 0.66, 0.62)}}
const MARBLE_RAIL := {"Stucco_White_01": "Building_Marble_01", "Stucco_Orange_01": "Building_Marble_03"}
const WARM_PAVING := {"Stone_01": "Floor_Tiles_03"}
const SAND := {"Stone_01": "Stone_01", "tints": {"Stone_01": Color(1.0, 0.86, 0.66)}}
const STONE_ARCH := {"Building_Large_Brick_01": "Stone_01"}
const TYMPANUM := {"Stone_01": "Stucco_Blue_01", "tints": {"Stucco_Blue_01": Color(0.8, 0.88, 1.0)}}   # фронтон расписан синим, как у римлян
const PORCH := {"Stone_01": "Floor_Tiles_02"}                         # узорный пол пронаоса (opus sectile)
const TRAV_BLOCKS := {"Building_Large_Brick_01": "Building_Large_Brick_01", "tints": {"Building_Large_Brick_01": Color(1.0, 0.92, 0.8)}}
const SWAG_RED := {"PolygonAncientEmpire_01_A": "PolygonAncientEmpire_01_B"}   # гирлянды: помпейский красный с золотом
const VELA_SAFFRON := {"PolygonAncientEmpire_01_A": "PolygonAncientEmpire_01_C", "tints": {"PolygonAncientEmpire_01_C": Color(1.28, 1.02, 0.55)}}
const RING_STONE := {"PolygonAncientEmpire_01_A": "Stone_01"}       # гладкий камень без меандра
const RING_LEAD := {"PolygonAncientEmpire_01_A": "Stucco_White_01", "tints": {"Stucco_White_01": Color(0.67, 0.66, 0.62)}}
const BRICK := {"Building_Large_Brick_01": "Brick_Brown_Tex", "tints": {"Brick_Brown_Tex": Color(1.2, 0.98, 0.84)}}   # римский кирпич


# ---------- общие помощники ----------

static func _put(b: Bp, nm: String, xf: Transform3D, rm := {}) -> void:
	b.parts.append([nm, b.base * xf, rm])


static func _at(b: Bp, nm: String, p: Vector3, yaw := 0.0, s := 1.0, rm := {}) -> void:
	_put(b, nm, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), p), rm)


## Особая коробка (#marble, #dark, #water) с центром c и размерами sz
static func _box(b: Bp, nm: String, c: Vector3, sz: Vector3, yaw := 0.0) -> void:
	_put(b, nm, Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(sz), c))


## Мощение: плита пола Synty на прямоугольник x0..x1 × z0..z1
static func _floor(b: Bp, rm: Dictionary, x0: float, z0: float, x1: float, z1: float, y := 0.02, nx := 1, nz := 1) -> void:
	var w := (x1 - x0) / nx
	var d := (z1 - z0) / nz
	for i in nx:
		for j in nz:
			_put(b, "SM_Bld_Base_Floor_01", Transform3D(Basis.from_scale(Vector3(w / 2.5, 1, d / 2.5)), Vector3(x0 + i * w, y, z0 + j * d)), rm)


## Статуя: idx 1..7 — конкретная, −1 — любая, 0 — одна из лёгких (для мелких и дальних фигур)
static func _statue(b: Bp, p: Vector3, yaw := 0.0, s := 1.0, idx := -1) -> void:
	var k := idx
	if idx < 0:
		k = 1 + b.rng.randi() % 7
	elif idx == 0:
		k = [3, 5, 6][b.rng.randi() % 3]
	b.add("SM_Prop_Statue_0%d" % k, p, yaw, s)


## Ряд одинаковых деталей вдоль линии: начало a, направление dir, длина len; деталь шириной pw растягивается по длине.
## Лицо детали смотрит наружу (влево от направления обхода: фасад при обходе против часовой стрелки сверху)
static func _run(b: Bp, nm: String, a: Vector3, dir: Vector3, len: float, pw := 2.5, sy := 1.0, sz := 1.0, rm := {}) -> void:
	var yaw := atan2(-dir.z, dir.x)
	var n := maxi(1, int(round(len / pw)))
	var step := len / n
	for i in n:
		_put(b, nm, Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(step / pw, sy, sz)), a + dir * step * i), rm)


## Обход прямоугольника x0..x1 × z0..z1 (фасад +Z) рядами деталей, лицом наружу
static func _ring_rect(b: Bp, nm: String, x0: float, x1: float, z0: float, z1: float, y: float, pw := 2.5, sy := 1.0, sz := 1.0, rm := {}, sides := [0, 1, 2, 3]) -> void:
	if 0 in sides:
		_run(b, nm, Vector3(x0, y, z1), Vector3(1, 0, 0), x1 - x0, pw, sy, sz, rm)
	if 1 in sides:
		_run(b, nm, Vector3(x1, y, z1), Vector3(0, 0, -1), z1 - z0, pw, sy, sz, rm)
	if 2 in sides:
		_run(b, nm, Vector3(x1, y, z0), Vector3(-1, 0, 0), x1 - x0, pw, sy, sz, rm)
	if 3 in sides:
		_run(b, nm, Vector3(x0, y, z0), Vector3(0, 0, 1), z1 - z0, pw, sy, sz, rm)


## Подиум: мраморное ядро, облицовка тёсаным камнем, карниз по верху
static func _podium(b: Bp, x0: float, x1: float, z0: float, z1: float, h: float, sides := [1, 2, 3]) -> void:
	_box(b, "#marble", Vector3((x0 + x1) / 2.0, h / 2.0, (z0 + z1) / 2.0), Vector3(x1 - x0 - 0.1, h, z1 - z0 - 0.1))
	_ring_rect(b, "SM_Bld_Wall_Large_01", x0 + 0.05, x1 - 0.05, z0 + 0.05, z1 - 0.05, 0.0, 5.0, h / 4.51, 0.5, {}, sides)
	_ring_rect(b, "SM_Bld_Wall_Large_Cap_01", x0, x1, z0, z1, h - 0.28, 5.0, 1.0, 0.8, {}, sides)


## Лестница во всю ширину x0..x1 от верха подиума (z_top) вперёд на 2,5 м и щёки по бокам. Возвращает передний край
static func _front_stairs(b: Bp, x0: float, x1: float, z_top: float, h: float) -> float:
	var n := maxi(1, int(round((x1 - x0) / 2.5)))
	var sx := (x1 - x0) / (n * 2.5)
	for i in n:
		_put(b, "SM_Bld_Stairs_01", Transform3D(Basis.from_scale(Vector3(sx, h / 1.5, 1)), Vector3(x0 + i * 2.5 * sx, 0, z_top + 2.5)))
	for x: float in [x0 - 0.42, x1 + 0.42]:
		_put(b, "SM_Bld_Wall_Large_01", Transform3D(Basis(Vector3.UP, -PI / 2) * Basis.from_scale(Vector3(2.7 / 5.0, (h + 0.35) / 4.51, 0.84 / 0.68)), Vector3(x, 0, z_top)))
		_put(b, "SM_Bld_Wall_Large_Pillar_Cap_01", Transform3D(Basis.from_scale(Vector3(0.75, 0.8, 2.3)), Vector3(x, h + 0.35, z_top + 1.4)))
	return z_top + 2.7


## Антаблемент: архитрав из мрамора и расписной фриз (красный с мрамором) по периметру x0..x1 × z0..z1, низ на высоте y.
## Возвращает высоту верха
static func _entablature(b: Bp, x0: float, x1: float, z0: float, z1: float, y: float, sides := [0, 1, 2, 3]) -> float:
	var s1 := 0.8
	var s2 := 0.75
	_box(b, "#marble", Vector3((x0 + x1) / 2.0, y + (0.96 * s1 + 0.97 * s2) / 2.0, (z0 + z1) / 2.0), Vector3(x1 - x0 - 0.2, 0.96 * s1 + 0.97 * s2 - 0.05, z1 - z0 - 0.2))
	# трим выступает вперёд от линии на 0,53 — сдвигаем линию внутрь
	var d := 0.5
	_ring_rect(b, "SM_Bld_Trim_Large_Single_01", x0 + d, x1 - d, z0 + d, z1 - d, y + 0.48 * s1, 2.5, s1, 1.0, {}, sides)
	_ring_rect(b, "SM_Bld_Trim_Large_Single_02", x0 + d, x1 - d, z0 + d, z1 - d, y + 0.96 * s1 + 0.485 * s2, 2.5, s2, 1.15, FRIEZE_RED, sides)
	for c: Array in [[Vector3(x0 + d, 0, z1 - d), 0.0, 0, 3], [Vector3(x1 - d, 0, z1 - d), PI / 2, 0, 1], [Vector3(x1 - d, 0, z0 + d), PI, 1, 2], [Vector3(x0 + d, 0, z0 + d), -PI / 2, 2, 3]]:
		if c[2] in sides and c[3] in sides:
			var p: Vector3 = c[0]
			_put(b, "SM_Bld_Trim_Large_Corner_01", Transform3D(Basis(Vector3.UP, c[1]) * Basis.from_scale(Vector3(1, s1, 1)), p + Vector3(0, y + 0.48 * s1, 0)))
			_put(b, "SM_Bld_Trim_Large_Corner_01", Transform3D(Basis(Vector3.UP, c[1]) * Basis.from_scale(Vector3(1, s2, 1.15)), p + Vector3(0, y + 0.96 * s1 + 0.485 * s2, 0)))
	return y + 0.96 * s1 + 0.97 * s2


## Пологая черепичная кровля храма: конёк вдоль Z над x −half..half, от z_back до z_front, фронтоны по торцам
## (tym — раскраска тимпанов). Возвращает высоту конька
static func _temple_roof(b: Bp, half: float, z_front: float, z_back: float, eave: float, front := true, back := true, tym := {}) -> float:
	var k := half / 7.5
	var len := z_front - z_back
	var n := maxi(1, int(ceil(len / 7.5)))
	var lz := len / n
	for i in n:
		var z0 := z_back + i * lz
		_put(b, "SM_Bld_Roof_Straight_Thin_Large_01", Transform3D(Basis(Vector3.UP, -PI / 2).scaled_local(Vector3(lz / 7.5, k, k)), Vector3(-half, eave, z0)))
		_put(b, "SM_Bld_Roof_Straight_Thin_Large_01", Transform3D(Basis(Vector3.UP, PI / 2).scaled_local(Vector3(lz / 7.5, k, k)), Vector3(half, eave, z0 + lz)))
	var ends := []
	if front:
		ends.append(z_front)
	if back:
		ends.append(z_back)
	for zz: float in ends:
		_put(b, "SM_Bld_Roof_Side_Large_01", Transform3D(Basis(Vector3.UP, -PI / 2).scaled_local(Vector3(1, k, k)), Vector3(-half, eave, zz)), tym)
		_put(b, "SM_Bld_Roof_Side_Large_01", Transform3D(Basis(Vector3.UP, PI / 2).scaled_local(Vector3(1, k, k)), Vector3(half, eave, zz)), tym)
	return eave + 1.94 * k


## Скульптура фронтона: крупный золотой медальон на синем тимпане (zb — то же на заднем фронтоне);
## акротерии — статуи на коньке и по углам
static func _pediment(b: Bp, half: float, eave: float, zp: float, ridge: float, zb := INF) -> void:
	var h := ridge - eave
	b.add("SM_Bld_Ornament_02", Vector3(0, eave + h * 0.42, zp + 0.15), 0.0, h * 0.95)
	if zb < INF:
		b.add("SM_Bld_Ornament_02", Vector3(0, eave + h * 0.42, zb - 0.15), PI, h * 0.95)
	for sd: float in [-1.0, 1.0]:
		_statue(b, Vector3(sd * (half - 0.35), eave + 0.02, zp - 0.1), 0.0, 0.62, 0)
	_statue(b, Vector3(0, ridge - 0.12, zp - 0.15), 0.0, 0.85, 4)


## Деталь по кругу: направление ang (0 — к +Z), радиус r, ширина width (деталь шириной pw растягивается); лицом наружу или внутрь
static func _ring_put(b: Bp, nm: String, ang: float, r: float, y: float, width: float, pw := 2.5, sy := 1.0, sz := 1.0, rm := {}, inward := false) -> void:
	var bs := Basis(Vector3.UP, ang + (PI if inward else 0.0))
	var t := bs * Vector3.RIGHT
	var c := Vector3(sin(ang) * r, y, cos(ang) * r)
	_put(b, nm, Transform3D(bs * Basis.from_scale(Vector3(width / pw, sy, sz)), c - t * width / 2.0), rm)


static func _big_brazier(b: Bp, p: Vector3, s := 0.75) -> void:
	b.add("SM_Prop_Brazier_01", p, 0.0, s)
	b.add("SM_Prop_Brazier_01_Insert_01", p, 0.0, s)
	b.light(p + Vector3(0, 2.0 * s, 0))


static func _fire_bowl(b: Bp, p: Vector3, s := 1.0) -> void:
	b.add("SM_Prop_Brazier_04", p, 0.0, s)
	b.add("SM_Prop_Brazier_04_Insert_01", p, 0.0, s)
	b.light(p + Vector3(0, 0.6 * s, 0))


static func _cypress(b: Bp, p: Vector3, s := 0.6) -> void:
	b.add("SM_Env_Tree_Thin_0%d" % (1 + b.rng.randi() % 2), p, b.rng.randf() * TAU, s)


static func _pot(b: Bp, p: Vector3, s := 0.6) -> void:
	b.add("SM_Prop_FlowerPot_Fancy_01", p + Vector3(0, 0.57 * s, 0), b.rng.randf() * TAU, s)


## Плющ для стен — только варианты без тёмных изнанок листьев (05 и 07 выглядят чёрными)
static func _ivy_flat(b: Bp) -> String:
	return "SM_Env_Ivy_Flowers_0%d" % [1, 2, 3, 4, 8][b.rng.randi() % 5]


## Надпись из бронзовых римских цифр-букв (есть только C D I L M V X); c — середина низа строки, лицом по yaw
static func _inscription(b: Bp, text: String, c: Vector3, s := 1.0, yaw := 0.0) -> void:
	var w := {"C": 0.35, "D": 0.41, "I": 0.13, "L": 0.35, "M": 0.5, "V": 0.41, "X": 0.41, " ": 0.3, ".": 0.2}
	var total := -0.08
	for ch in text:
		total += (w.get(ch, 0.3) as float) + 0.08
	var bs := Basis(Vector3.UP, yaw)
	var x := -total * s / 2.0
	for ch in text:
		var cw: float = w.get(ch, 0.3)
		var p := c + bs * Vector3(x + cw * s / 2.0, 0, 0)
		if ch in ["C", "D", "I", "L", "M", "V", "X"]:
			b.add("SM_Prop_Numeral_%s_01" % ch, p, yaw, s)
		elif ch == ".":
			b.add("SM_Bld_Ornament_09", p + Vector3(0, 0.25 * s, 0), yaw, 0.5 * s)
		x += (cw + 0.08) * s


## Трофей: щит-скутум на двух скрещённых копьях; c — точка на лицевой стене, лицом по yaw
static func _tropaeum(b: Bp, c: Vector3, yaw := 0.0, s := 1.0) -> void:
	var bs := Basis(Vector3.UP, yaw)
	for sd: float in [-1.0, 1.0]:
		_put(b, "SM_Wep_Spear_02", Transform3D(bs * Basis(Vector3(0, 0, 1), sd * 0.6) * Basis.from_scale(Vector3.ONE * s), c + bs * Vector3(0, 0, 0.06 * s)))
	_put(b, "SM_Wep_Shield_04", Transform3D(bs * Basis.from_scale(Vector3.ONE * s), c + bs * Vector3(0, 0, 0.17 * s)))


# ---------- фонтан ----------

## Квадратная чаша из мраморного бортика с меандром, в воде — двухъярусный фонтан со статуей, львиные маски-водомёты,
## кувшинки и утка; по углам тумбы с цветами, кругом мозаика, по бокам скамейки, у входа два фонаря, сзади кипарисы
static func _fountain(b: Bp) -> void:
	_floor(b, MOSAIC, -2.6, -2.6, 2.6, 2.6, 0.02)
	var h := 1.8
	var ey := 0.4
	for i in 4:
		var bs := Basis(Vector3.UP, i * PI / 2)
		_put(b, "SM_Bld_Bath_Edge_01", Transform3D(bs * Basis.from_scale(Vector3(2.0 * h / 2.5, 1, 1)), bs * Vector3(-h, ey, h)))
	_box(b, "#water", Vector3(0, 0.25, 0), Vector3(2.0 * h - 0.3, 0.26, 2.0 * h - 0.3))
	for c: Vector3 in [Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(-h, 0, h), Vector3(h, 0, h)]:
		b.add("SM_Prop_Pillar_Base_01", c, 0.0, 0.9)
		_pot(b, c + Vector3(0, 0.9, 0), 0.5)
	b.add("SM_Prop_Fountain_04", Vector3(0, 0.05, 0), PI / 8, 0.72)
	b.add("SM_Prop_Fountain_04_Insert_01", Vector3(0, 0.05, 0), PI / 8, 0.72)
	_statue(b, Vector3(0, 0.05 + 1.81 * 0.72 - 0.05, 0), 0.0, 0.42, 5)
	# львиные маски на внутренней стороне бортика — сзади и по бокам
	var ri := h - 0.24
	b.add("SM_Prop_Marble_LionHead_01", Vector3(0, 0.46, -ri), 0.0, 0.55)
	for sd: float in [-1.0, 1.0]:
		b.add("SM_Prop_Marble_LionHead_01", Vector3(sd * ri, 0.46, -0.1), -sd * PI / 2, 0.55)
	b.add("SM_Env_Lillies_02", Vector3(-0.95, 0.37, 1.0), 0.6, 0.45)
	b.add("SM_Env_Lillies_01", Vector3(1.05, 0.37, -0.9), 2.0, 0.6)
	b.add("SM_Env_Lillies_01", Vector3(-1.1, 0.37, -1.05), 4.0, 0.5)
	b.add("#duck", Vector3(1.0, 0.38, 1.05), -2.4, 1.0)
	for sd: float in [-1.0, 1.0]:
		b.add("#lamp_post", Vector3(sd * 2.45, 0, 2.3), PI / 2 - sd * PI / 2, 1.0)
		b.light(Vector3(sd * 2.45 + sd * 0.42, 2.1, 2.3))
		_cypress(b, Vector3(sd * 2.3, 0, -2.45), 0.42)
		b.add("SM_Prop_Seat_Bench_03", Vector3(sd * 2.25, 0, 0.2), -sd * PI / 2, 0.8)
	b.door = Vector3(0, 0, 2.6)


# ---------- храм ----------

## Храм Юпитера в духе Мезон Карре: высокий подиум, лестница со щеками и жаровнями, шесть коринфских колонн в три ряда
## с ровным шагом до целлы, целла из мрамора с полуколоннами, красным цоколем и золотыми медальонами, бронзовые врата
## и ниши со статуями, расписной фриз, синий фронтон с медальоном и статуями
static func _temple(b: Bp) -> void:
	var s := 0.62
	b.base = Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3(0, 0, 5.6))
	var pod := 1.5
	var hw := 6.25                       # оси крайних колонн
	var zc0 := -1.0                      # первый ряд колонн
	var zcf := -8.5                      # передняя стена целлы (шаг колонн 2,5 м сохраняется вдоль всего бока)
	var zcb := -16.0                     # задняя стена целлы
	var px := hw + 0.85                  # край подиума
	_podium(b, -px, px, zcb - 0.9, 0.0, pod)
	_floor(b, PAVING, -px, zcb - 0.9, px, zcf, pod + 0.02, 3, 2)
	_floor(b, PORCH, -px, zcf, px, 0.0, pod + 0.02, 3, 2)
	var zfront := _front_stairs(b, -hw, hw, 0.0, pod)
	# жаровни на щеках лестницы
	for sd: float in [-1.0, 1.0]:
		_big_brazier(b, Vector3(sd * (hw + 0.42), pod + 0.72, 1.6), 0.62)
	# колонны одного коринфского ордера: фасад из шести, за ними ещё ряд из 4 и пара по бокам пронаоса
	for i in 6:
		b.add("SM_Bld_Pillar_Large_04", Vector3(-hw + i * M, pod, zc0))
	for x: float in [-hw, -hw + M, hw - M, hw]:
		b.add("SM_Bld_Pillar_Large_04", Vector3(x, pod, zc0 - M))
	for x: float in [-hw, hw]:
		b.add("SM_Bld_Pillar_Large_04", Vector3(x, pod, zc0 - 2 * M))
	# целла: мраморные стены в два яруса, полуколонны по бокам и сзади
	var keep := b.remap
	b.remap = MARBLE_WALL
	var cz := (zcf + zcb) / 2.0
	for f in 2:
		var y := pod + f * FL
		for i in 3:
			b.on_wall("SM_Bld_Wall_01", 0, cz, 5, 3, 1, i, y, 0.0, true)
			b.on_wall("SM_Bld_Wall_01", 0, cz, 5, 3, 3, i, y, 0.0, true)
		for i in 5:
			b.on_wall("SM_Bld_Wall_01", 0, cz, 5, 3, 2, i, y, 0.0, true)
		for i: int in [0, 4]:
			b.on_wall("SM_Bld_Wall_01", 0, cz, 5, 3, 0, i, y, 0.0, true)
		if f == 1:
			for i: int in [1, 3]:
				b.on_wall("SM_Bld_Wall_01", 0, cz, 5, 3, 0, i, y, 0.0, true)
	b.remap = keep
	# помпейский красный цоколь и золотые медальоны в каждом пролёте боковых и задней стен
	for side: int in [1, 2, 3]:
		for i in (5 if side == 2 else 3):
			var a := b.wall_at(0, cz, 5, 3, side, i, pod, 0.07)
			_put(b, "SM_Bld_Wall_01", Transform3D(Basis(Vector3.UP, a[1]) * Basis.from_scale(Vector3(1, 0.3, 1)), a[0]), RED_WALL)
			b.on_wall("SM_Bld_Ornament_02", 0, cz, 5, 3, side, i + 0.5, pod + 4.5, 0.14, false, 1.3)
	# у врат — ниши со статуями богов
	for i: int in [1, 3]:
		b.on_wall("SM_Bld_Wall_Alcove_01", 0, cz, 5, 3, 0, i, pod)
		_statue(b, Vector3(-hw + i * M + 1.25, pod + 0.22, zcf - 0.15), 0.0, 0.78, 3 if i == 1 else 6)
	_put(b, "SM_Bld_Door_Monument_01", Transform3D(Basis.from_scale(Vector3(0.56, 0.667, 0.56)), Vector3(-1.42, pod, zcf + 0.08)))
	for z: float in [zcf, zcf - M, zcf - 2 * M, zcb]:
		for x: float in [-hw, hw]:
			b.add("SM_Bld_Pillar_Large_01", Vector3(x, pod, z))
	for x: float in [-hw + M, -hw + 2 * M, hw - 2 * M, hw - M]:
		b.add("SM_Bld_Pillar_Large_01", Vector3(x, pod, zcb))
	# антаблемент, кровля, фронтоны
	var x0 := -hw - 0.45
	var x1 := hw + 0.45
	var zf := zc0 + 0.45
	var zb := zcb - 0.45
	var eave := _entablature(b, x0, x1, zb, zf, pod + 6.0)
	var half := x1 + 0.15
	var ridge := _temple_roof(b, half, zf + 0.35, zb - 0.35, eave, true, true, TYMPANUM)
	_pediment(b, half, eave, zf + 0.35, ridge, zb - 0.35)
	# красные гирлянды над тремя средними пролётами
	for i: int in [1, 2, 3]:
		_at(b, "SM_Prop_Drapery_03", Vector3(-hw + M * 0.5 + i * M, pod + 5.95, zc0 + 0.42), 0.0, 1.0, SWAG_RED)
	# алтарь с огнём и курильницы в пронаосе
	b.add("SM_Prop_Plinth_04", Vector3(0, pod, zc0 - M * 1.5), 0.0, 1.2)
	_fire_bowl(b, Vector3(0, pod + 0.82, zc0 - M * 1.5), 0.9)
	for sd: float in [-1.0, 1.0]:
		b.add("SM_Prop_Senser_01", Vector3(sd * 2.0, pod, zcf + 0.7), 0.0, 1.0)
		_pot(b, Vector3(sd * (hw + 0.3), pod, zc0 + 0.55), 0.55)
		# плющ на углах и кипарисы за храмом
		b.add("SM_Env_Ivy_Pillar_Flowers_04", Vector3(sd * hw, pod, zcb), b.rng.randf() * TAU, 1.0)
		b.add(_ivy_flat(b), Vector3(sd * (px + 0.18), pod * 0.55, zcb + 3.0), sd * PI / 2, 1.0)
		_cypress(b, Vector3(sd * (px + 0.9), 0, zcb - 0.2), 1.25)
		_cypress(b, Vector3(sd * (px + 0.8), 0, zcf + 1.5), 1.05)
	b.base = Transform3D.IDENTITY
	b.door = Vector3(0, 0, 5.6 + (zfront + 0.7) * s)


# ---------- форум ----------

## Площадь, мощённая травертином. В глубине — курия: высокий портик из четырёх ионических колонн с синим фронтоном,
## по бокам — крылья галереи с нишами и статуями; перед курией — ростры с бронзовыми щитами, балюстрадой и жаровнями,
## две почётные колонны со статуями; по бокам — портики с лавками; в центре — мозаика и статуя полководца;
## у входа — пилоны со статуями и знамёна на шестах
static func _forum(b: Bp) -> void:
	b.paint(0, false)
	var zw := -7.1                       # задняя стена
	var zc := -4.5                       # колонны задней галереи
	var hx := 6.6                        # половина ширины
	var zfr := 6.2                       # передний край площади
	_floor(b, WARM_PAVING, -hx, zw, hx, zfr - 0.1, 0.02, 3, 3)
	_floor(b, MOSAIC, -2.2, -2.4, 2.2, 2.0, 0.035)
	var hc := 1.3
	var top := 3.0 * hc
	# задняя стена: ниши со статуями, красный пояс, каменная облицовка снаружи, плющ
	for i in 5:
		_put(b, "SM_Bld_Wall_Alcove_01", Transform3D(Basis.from_scale(Vector3(1, hc, 1)), Vector3(-6.25 + i * M, 0, zw)))
		_statue(b, Vector3(-5.0 + i * M, 0.28, zw - 0.3), 0.0, 0.9, [3, 5, 6, 5, 3][i])
	_run(b, "SM_Bld_Wall_01", Vector3(-6.25, top, zw), Vector3(1, 0, 0), 12.5, 2.5, 0.55, 1.0, RED_WALL)
	_run(b, "SM_Bld_Wall_Large_01", Vector3(6.25, 0, zw - 0.62), Vector3(-1, 0, 0), 12.5, 5.0, (top + 1.65) / 4.51, 0.5)
	for k in 3:
		b.add(_ivy_flat(b), Vector3(-4.2 + k * 4.0 + b.rng.randf_range(-0.6, 0.6), b.rng.randf_range(1.2, 3.2), zw - 1.0), PI, b.rng.randf_range(1.2, 1.6))
	# крылья галереи: колонна с плющом, черепичный навес, расписной фриз, статуя и лев на кровле
	for sd: float in [-1.0, 1.0]:
		var xo := sd * 6.25
		var xb := -6.25 if sd < 0 else 3.75
		b.add("SM_Bld_Pillar_02", Vector3(xo, 0, zc), 0.0, hc)
		b.add("SM_Env_Ivy_Pillar_Flowers_0%d" % (1 + b.rng.randi() % 2), Vector3(xo, 0, zc), b.rng.randf() * TAU, hc)
		b.add("SM_Bld_Wall_Tiny_01", Vector3(xb, top, zc), 0.0, 1.0, true)
		b.add_xf("SM_Bld_Roof_Base_Straight_01", Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 0.55, 3.0 / 2.5)), Vector3(xb, top + 0.3, zc + 0.4)), true)
		_put(b, "SM_Bld_Trim_Large_Single_02", Transform3D(Basis.from_scale(Vector3(1, 0.75, 1)), Vector3(xb, top + 0.36, zc - 0.1)), FRIEZE_RED)
		_statue(b, Vector3(sd * 5.0, top + 0.72, zc - 0.05), 0.0, 0.62, 0)
		b.add("SM_Prop_Statue_Lion_01", Vector3(sd * 6.25, top + 0.72, zc - 0.3), 0.0, 0.3)
	# курия: четыре высокие ионические колонны, антаблемент, кровля и фронтон, красные гирлянды
	var cs := 0.9
	var ch := 6.0 * cs
	for i in 4:
		b.add("SM_Bld_Pillar_Large_03", Vector3(-3.75 + i * M, 0, zc), 0.0, cs)
	var eave := _entablature(b, -4.2, 4.2, zw + 0.1, zc + 0.45, ch)
	var half := 4.35
	var ridge := _temple_roof(b, half, zc + 0.8, zw - 0.2, eave, true, true, TYMPANUM)
	_pediment(b, half, eave, zc + 0.8, ridge)
	for i in 3:
		_at(b, "SM_Prop_Drapery_03", Vector3(-2.5 + i * M, ch - 0.05, zc + 0.42), 0.0, 1.0, SWAG_RED)
	# ростры: помост с балюстрадой, мощёный верх, бронзовые щиты на фасаде, жаровни по углам
	var rz0 := zc + 0.75
	var rz1 := rz0 + 2.0
	var rh := 1.2
	_box(b, "#marble", Vector3(0, rh / 2.0, (rz0 + rz1) / 2.0), Vector3(5.4, rh, rz1 - rz0))
	_floor(b, PAVING, -2.7, rz0, 2.7, rz1, rh + 0.01)
	_run(b, "SM_Bld_Wall_Large_01", Vector3(-2.75, 0, rz1), Vector3(1, 0, 0), 5.5, 5.0, rh / 4.51, 0.6, MARBLE_BLOCKS)
	for sd: float in [-1.0, 1.0]:
		_run(b, "SM_Bld_Wall_Large_01", Vector3(sd * 2.75, 0, rz1 if sd > 0 else rz0), Vector3(0, 0, -sd), rz1 - rz0, 5.0, rh / 4.51, 0.6, MARBLE_BLOCKS)
	_run(b, "SM_Bld_Wall_Large_Cap_01", Vector3(-2.8, rh - 0.25, rz1 + 0.05), Vector3(1, 0, 0), 5.6, 5.0, 1.0, 0.8)
	for i in 2:
		_at(b, "SM_Bld_Wall_Balcony_05", Vector3(-2.5 + i * 2.5, rh, rz1 - 0.25), 0.0, 1.0, MARBLE_RAIL)
	for x: float in [-2.15, 0.0, 2.15]:
		b.add("SM_Wep_Shield_03", Vector3(x, 0.58, rz1 + 0.27), 0.0, 0.62)
	for sd: float in [-1.0, 1.0]:
		_fire_bowl(b, Vector3(sd * 2.25, rh + 1.02, rz1 - 0.25), 0.7)
		b.add("SM_Prop_Banner_03_%s" % ["A", "D"][int(sd > 0)], Vector3(sd * 1.1, rh - 0.05, rz1 + 0.37), 0.0, 0.5)
	# почётные колонны со статуями
	for sd: float in [-1.0, 1.0]:
		var p := Vector3(sd * 3.6, 0, rz1 + 0.9)
		b.add("SM_Bld_Pillar_Monument_Trim_01", p + Vector3(0, 0.2, 0), 0.0, 0.62)
		_put(b, "SM_Bld_Pillar_Monument_02", Transform3D(Basis.from_scale(Vector3.ONE * 0.42), p + Vector3(0, 0.3, 0)), CAP_MARBLE)
		_statue(b, p + Vector3(0, 0.3 + 12.0 * 0.42, 0), 0.0, 0.62, 4 if sd < 0 else 6)
	# боковые портики с лавками (тавернами)
	for sd: float in [-1.0, 1.0]:
		var keep := b.base
		b.base = Transform3D(Basis(Vector3.UP, sd * PI / 2), Vector3.ZERO)
		b.portico(-4.0 if sd > 0 else -3.5, 3.5 if sd > 0 else 4.0, 4.4, hx, 1.0, "SM_Bld_Pillar_01", sd < 0)
		b.base = keep
		for j in 3:
			var z := 3.0 - j * 2.6
			var nm: String = ["SM_Bld_Wall_Door_04", "SM_Bld_Wall_Door_Large_01", "SM_Bld_Wall_Window_06"][(j + int(sd > 0)) % 3]
			var p := Vector3(sd * hx, 0, z - sd * 1.25)
			b.add(nm, p, -sd * PI / 2, 1.0, true)
			b.add("SM_Bld_Wall_Tiny_01", p + Vector3(0, 2.9, 0), -sd * PI / 2, 1.0, true)
			if nm == "SM_Bld_Wall_Door_04":
				b.add("SM_Bld_Door_0%d" % (1 + b.rng.randi() % 5), Vector3(sd * (hx - 0.02), 0, z - sd * 0.45), -sd * PI / 2)
			elif nm == "SM_Bld_Wall_Door_Large_01":
				# лавка: тёмное нутро закрыто снаружи стеной в цвет здания
				_box(b, "#dark", Vector3(sd * (hx + 0.36), 1.5, z), Vector3(0.12, 3.0, 2.4))
				_put(b, "SM_Bld_Wall_01", Transform3D(Basis(Vector3.UP, sd * PI / 2) * Basis.from_scale(Vector3(1, 1.07, 1)), Vector3(sd * (hx + 0.5), 0, z + sd * 1.25)), b.remap.duplicate())
				b.add("SM_Prop_Vase_0%d" % (1 + b.rng.randi() % 6), Vector3(sd * (hx - 0.8), 0, z - 0.5), 0.0, 0.8)
				b.add("SM_Prop_Vase_0%d" % (1 + b.rng.randi() % 6), Vector3(sd * (hx - 0.75), 0, z + 0.55), 0.0, 0.7)
				b.add("SM_Prop_Sack_0%d" % (1 + b.rng.randi() % 5), Vector3(sd * (hx - 1.1), 0, z + 0.05), b.rng.randf() * TAU, 0.8)
		b.add("SM_Prop_Seat_Bench_03", Vector3(sd * 5.55, 0, -1.6), -sd * PI / 2, 0.9)
		b.add("SM_Prop_Banner_0%d_%s" % [1 + int(sd > 0), ["B", "E"][int(sd > 0)]], Vector3(sd * (hx - 0.12), 2.75, 1.7), -sd * PI / 2, 0.8)
	# центр: статуя полководца на постаменте, жаровни, цветы
	var ps := 0.58
	b.add("SM_Prop_Plinth_05", Vector3(0, 0.03, -0.2), 0.0, ps)
	_statue(b, Vector3(0, 0.03 + 2.59 * ps, -0.2), 0.0, 0.95, 1)
	for c: Vector3 in [Vector3(-1.9, 0.03, -2.4), Vector3(1.9, 0.03, -2.4)]:
		_pot(b, c, 0.55)
	for sd: float in [-1.0, 1.0]:
		_big_brazier(b, Vector3(sd * 1.75, 0.03, 0.9), 0.55)
	# вход: пилоны со статуями, знамёна на шестах, львы
	for sd: float in [-1.0, 1.0]:
		var p := Vector3(sd * 5.7, 0, zfr - 0.55)
		_put(b, "SM_Bld_Wall_Large_Pillar_01", Transform3D(Basis.from_scale(Vector3(1.0, 0.75, 1.0)), p))
		b.add("SM_Bld_Wall_Large_Pillar_Cap_01", p + Vector3(0, 4.55 * 0.75, 0))
		_statue(b, p + Vector3(0, 4.55 * 0.75 + 0.42, 0), 0.0, 0.75, 0)
		b.add("SM_Prop_Pole_01", p + Vector3(-sd * 1.3, 0, 0.1), 0.0, 1.25)
		b.add("SM_Prop_Banner_03_%s" % ["B", "C"][int(sd > 0)], p + Vector3(-sd * 1.3, 3.7, 0.12), 0.0, 0.6)
		b.add("SM_Prop_Statue_Lion_01", p + Vector3(-sd * 2.6, 0, -0.45), 0.0, 0.42)
		b.add("SM_Env_Garden_Plants_0%d" % (3 + b.rng.randi() % 4), p + Vector3(sd * 0.1, 0, -1.2), b.rng.randf() * TAU, 0.6)
	b.door = Vector3(0, 0, zfr + 1.0)


# ---------- триумфальная арка ----------

## Трёхпролётная арка (как арка Константина): тёсаный камень, коринфские колонны на пьедесталах, медальоны над малыми
## пролётами, гирлянда, аттик с бронзовой надписью DIVI IVLI с обеих сторон и трофеями (щит на скрещённых копьях),
## на аттике статуи, львы и жаровни
static func _arch(b: Bp) -> void:
	var sc := 0.72
	b.base = Transform3D(Basis.from_scale(Vector3.ONE * sc), Vector3.ZERO)
	var hx := 4.75
	var zf := 1.25
	var ht := 6.0
	# лицевые и задние стены с арками
	for face: float in [1.0, -1.0]:
		var yaw := 0.0 if face > 0 else PI
		var z := zf * face
		var o := func(x: float) -> float: return x if face > 0 else -x
		_put(b, "SM_Bld_Wall_Door_Double_01", Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(1.8, 2.0, 1.0)), Vector3(o.call(-2.25), 0, z)))
		for sd: float in [-1.0, 1.0]:
			var x0 := -hx if sd < 0 else 2.25
			_put(b, "SM_Bld_Wall_Door_Double_01", Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(1.0, 1.2, 1.0)), Vector3(o.call(x0), 0, z)))
			_put(b, "SM_Bld_Wall_Large_01", Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(0.5, (ht - 3.61) / 4.51, 0.75)), Vector3(o.call(x0), 3.61, z)))
			b.add("SM_Bld_Ornament_02", Vector3(sd * 3.5, 4.8, z + face * 0.3), yaw, 1.5)
		# колонны на пьедесталах
		for x: float in [-hx, -2.25, 2.25, hx]:
			var p := Vector3(x, 0, z + face * 0.62)
			_put(b, "SM_Prop_Pillar_Base_01", Transform3D(Basis.from_scale(Vector3(1.05, 0.6, 1.05)), p))
			_put(b, "SM_Bld_Pillar_Large_04" if face > 0 else "SM_Bld_Pillar_Large_03", Transform3D(Basis.from_scale(Vector3(0.9, (ht - 0.6) / 6.0, 0.9)), p + Vector3(0, 0.6, 0)))
	# боковые стены и толща пилонов, своды проходов
	for sd: float in [-1.0, 1.0]:
		_put(b, "SM_Bld_Wall_Large_01", Transform3D(Basis(Vector3.UP, sd * PI / 2) * Basis.from_scale(Vector3(0.5, ht / 4.51, 1.0)), Vector3(sd * hx, 0, zf * sd)))
		_box(b, "#marble", Vector3(sd * 2.13, ht / 2.0, 0), Vector3(0.9, ht, 2.3))
		_box(b, "#marble", Vector3(sd * 3.5, 4.5, 0), Vector3(2.0, 3.0, 2.3))
	_box(b, "#marble", Vector3(0, 5.5, 0), Vector3(3.5, 1.0, 2.3))
	_floor(b, PAVING, -hx, -zf - 0.6, hx, zf + 0.6, 0.02, 2, 1)
	# антаблемент и аттик
	var top := _entablature(b, -hx - 0.5, hx + 0.5, -zf - 1.15, zf + 1.15, ht)
	var ah := 1.4
	_box(b, "#marble", Vector3(0, top + ah / 2.0, 0), Vector3(2 * hx - 0.1, ah, 2 * zf + 0.5))
	_ring_rect(b, "SM_Bld_Wall_Large_01", -hx + 0.1, hx - 0.1, -zf - 0.35, zf + 0.35, top, 5.0, ah / 4.51, 0.5, MARBLE_BLOCKS)
	_ring_rect(b, "SM_Bld_Wall_Large_Cap_01", -hx, hx, -zf - 0.45, zf + 0.45, top + ah - 0.05, 5.0, 1.3, 1.0)
	# верх аттика вымощен вровень с карнизом
	var ay := top + ah + 0.34
	_floor(b, PAVING, -hx + 0.4, -zf - 0.05, hx - 0.4, zf + 0.05, ay - 0.01, 2, 1)
	# надпись «Божественному Юлию» и трофеи — на обеих сторонах аттика
	for face: float in [1.0, -1.0]:
		var yaw := 0.0 if face > 0 else PI
		var zface := face * (zf + 0.53)
		_inscription(b, "DIVI . IVLI", Vector3(0, top + (ah - 0.46 * 1.45) / 2.0, zface + face * 0.01), 1.45, yaw)
		for sd: float in [-1.0, 1.0]:
			_tropaeum(b, Vector3(sd * 3.85, top + ah / 2.0, zface), yaw, 0.75)
	# на аттике: статуя в центре, по бокам статуи, львы и жаровни
	_statue(b, Vector3(0, ay, 0.2), 0.0, 1.25, 4)
	for sd: float in [-1.0, 1.0]:
		_statue(b, Vector3(sd * 2.0, ay, 0.4), 0.0, 0.95, 6 if sd < 0 else 5)
		b.add("SM_Prop_Statue_Lion_01", Vector3(sd * 3.3, ay, -0.3), 0.0, 0.42)
		_big_brazier(b, Vector3(sd * (hx - 0.55), ay, 0.75), 0.5)
		# цветы у пьедесталов и кипарисы
		_pot(b, Vector3(sd * (hx + 0.85), 0, zf + 0.6), 0.6)
		_cypress(b, Vector3(sd * (hx + 0.95), 0, -zf - 0.5), 0.7)
	_at(b, "SM_Prop_Drapery_01", Vector3(0, ht - 0.75, zf + 0.42), 0.0, 1.3, SWAG_RED)
	b.base = Transform3D.IDENTITY
	b.door = Vector3(0, 0, (zf + 1.9) * sc)


# ---------- амфитеатр ----------

## Колизей: кольцо арок в два яруса из травертина (между арками пилястры), аттик со знамёнами и жаровнями, по верху —
## полосатый веларий; за арками первого яруса — светлая обходная галерея с проходами к арене; внутри — ряды сидений над
## высоким красным подиумом, песчаная арена с воротами и алтарём; главный вход — портик с колоннами, аттиком «LXXX» и статуями
static func _colosseum(b: Bp) -> void:
	var S := 0.55
	var raise := 3.5                     # сиденья подняты: верх рядов вровень с верхом второго яруса
	var r_in := 6.66 * S
	var r_out := 22.5 * S
	var R := r_out + 0.5                 # кольцо аркад
	var n := 28                          # арок в ярусе
	var TH := 3.01                       # высота яруса
	for i in 8:
		_put(b, "SM_Bld_Amphitheatre_01", Transform3D(Basis(Vector3.UP, i * PI / 4).scaled(Vector3.ONE * S), Vector3(0, raise, 0)))
	# сплошное ядро под рядами (скрыто подиумом, сиденьями и стеной галереи): постройка занимает землю целиком
	for i in 16:
		var a := i * PI / 8
		_box(b, "#dark", Vector3(sin(a), 0, cos(a)) * 7.75 + Vector3(0, 1.55, 0), Vector3(2.0 * 11.5 * tan(PI / 16) + 0.1, 3.1, 7.5), a)
	# арена: песок, красный подиум с воротами, алтарь с огнём
	var aw := r_in + 0.15
	for k in 2:
		var bs := Basis(Vector3.UP, k * PI / 4)
		_put(b, "SM_Bld_Base_Floor_01", Transform3D(bs * Basis.from_scale(Vector3(2 * aw / 2.5, 1, 2 * aw / 2.5)), bs * Vector3(-aw, 0.03 + k * 0.005, -aw)), SAND)
	var side := 2.0 * r_in * tan(PI / 8)
	for i in 8:
		var ang := 7.0 * PI / 8.0 + i * PI / 4.0
		var gate := i == 2 or i == 6
		if gate:
			_ring_put(b, "SM_Bld_Wall_Door_Large_01", ang, r_in, 0.0, side, 2.5, raise / 3.01, 1.0, {}, true)
		else:
			_ring_put(b, "SM_Bld_Wall_01", ang, r_in, 0.0, side, 2.5, raise / 3.01, 1.0, RED_WALL, true)
	b.add("SM_Prop_Plinth_04", Vector3(0, 0.03, 0), 0.0, 1.1)
	_fire_bowl(b, Vector3(0, 0.78, 0), 0.8)
	b.add("SM_Prop_Weapon_Rack_01", Vector3(sin(9.0 * PI / 8) * (r_in - 0.5), 0, cos(9.0 * PI / 8) * (r_in - 0.5)), 9.0 * PI / 8 + PI, 0.8)
	# обходная галерея первого яруса: светлая травертиновая стена с проходами к арене на четырёх осях, мощёный пол
	var ri := 11.85
	var iw := 2.0 * ri * tan(PI / 16.0)
	var wf := 2.0 * (R + 0.05) * tan(PI / 16.0) + 0.05
	var ww := 2.0 * 12.7 * tan(PI / 16.0) + 0.05
	var ap := r_out + 0.08
	for k in 16:
		var ang := k * TAU / 16.0
		var bs := Basis(Vector3.UP, ang)
		var dir := Vector3(sin(ang), 0, cos(ang))
		_ring_put(b, "SM_Bld_Wall_Door_Large_01" if k % 4 == 0 else "SM_Bld_Wall_01", ang, ri, 0.0, iw, 2.5, (raise - 0.25) / 3.01, 1.0, STONE_WALL)
		_put(b, "SM_Bld_Base_Floor_01", Transform3D(bs * Basis.from_scale(Vector3(wf / 2.5, 1, 1.2 / 2.5)), dir * 11.75 + Vector3(0, 0.025, 0) - bs * Vector3(wf / 2.0, 0, 0)), PAVING)
		# тёмная галерея за арками второго яруса и над ней — верхний обход (закрывает её сверху)
		_box(b, "#dark", dir * ap + Vector3(0, 4.5, 0), Vector3(2.0 * ap * tan(PI / 16) + 0.05, 3.0, 0.15), ang)
		_put(b, "SM_Bld_Base_Floor_01", Transform3D(bs * Basis.from_scale(Vector3(ww / 2.5, 1, 0.7 / 2.5)), dir * 12.0 + Vector3(0, raise + 4.58 * S + 0.04, 0) - bs * Vector3(ww / 2.0, 0, 0)))
	# аркады: два яруса арок, пилястры и колонны, карнизы, аттик
	var bw := 2.0 * R * tan(PI / n)
	for j in n:
		var ang := j * TAU / n
		var ab := ang + PI / n
		var cp := Vector3(sin(ab), 0, cos(ab)) * (R + 0.2)
		for f in 2:
			_ring_put(b, "SM_Bld_Wall_Door_Double_01", ang, R, f * TH, bw, 2.5, 1.0, 0.7, STONE_ARCH)
			_ring_put(b, "SM_Bld_Wall_Tiny_01", ang, R + 0.1, f * TH + 2.75, bw, 2.5, 1.0, 1.0, STONE_WALL)
		_put(b, "SM_Bld_Wall_Large_Pillar_01", Transform3D(Basis(Vector3.UP, ab) * Basis.from_scale(Vector3(0.42, 2.75 / 4.55, 0.42)), cp), TRAV_BLOCKS)
		b.add("SM_Bld_Base_Pillar_02", cp + Vector3(0, TH, 0), ab, 0.9)
		_ring_put(b, "SM_Bld_Base_Wall_01", ang, R, 2.0 * TH, bw, 2.5, 0.5, 1.0)
		if j % 4 == 2:
			b.add("SM_Prop_Banner_0%d_%s" % [1 + int(j / 4.0) % 2, ["A", "C", "D", "F", "G", "B", "E"][int(j / 4.0)]], Vector3(sin(ang), 0, cos(ang)) * (R + 0.1) + Vector3(0, 7.45, 0), ang, 0.75)
		_ring_put(b, "SM_Bld_Wall_Tiny_01", ang, R + 0.08, 7.5, bw, 2.5, 1.0, 1.0, STONE_WALL)
	# статуи в арках второго яруса через одну по передней половине (лёгкие модели) и жаровни на аттике
	for j: int in [22, 24, 26, 2, 4, 6]:
		var ang := j * TAU / n
		_statue(b, Vector3(sin(ang), 0, cos(ang)) * (R - 0.05) + Vector3(0, TH + 0.04, 0), ang, 0.82, 6 if j % 4 == 2 else 5)
	for k in 4:
		var ang := PI / 4.0 + k * PI / 2.0
		b.add("SM_Prop_Brazier_03", Vector3(sin(ang), 0, cos(ang)) * (R - 0.25) + Vector3(0, 7.55, 0), 0.0, 1.5)
		b.add("SM_Prop_Brazier_03_Insert_01", Vector3(sin(ang), 0, cos(ang)) * (R - 0.25) + Vector3(0, 7.55, 0), 0.0, 1.5)
		b.light(Vector3(sin(ang), 0, cos(ang)) * (R - 0.25) + Vector3(0, 9.0, 0))
	# веларий: сплошной венец навесов в две полосы — терракота и шафран
	var wv := 2.0 * (R - 0.15) * tan(PI / 16.0) + 0.05
	for j in 16:
		var ang := (j + 0.5) * TAU / 16.0
		var by := Basis(Vector3.UP, ang + PI)
		var t := by * Vector3.RIGHT
		_put(b, "SM_Prop_Banner_Roof_02", Transform3D(by * Basis(Vector3.RIGHT, 0.3) * Basis.from_scale(Vector3(wv / 5.1, 1, 1)), Vector3(sin(ang), 0, cos(ang)) * (R - 0.15) + Vector3(0, 7.75, 0) - t * wv / 2.0), {} if j % 2 == 0 else VELA_SAFFRON)
	# главный вход: портик с колоннами, низкий аттик с надписью и статуями, жаровни
	var zp := R + 0.85
	for sd: float in [-1.0, 1.0]:
		b.add("SM_Bld_Pillar_Large_03", Vector3(sd * 1.75, 0, zp))
		_big_brazier(b, Vector3(sd * 3.3, 0, R + 0.62), 0.6)
	_box(b, "#marble", Vector3(0, 6.45, (R + zp) / 2.0), Vector3(4.2, 0.9, zp - R + 0.6))
	_run(b, "SM_Bld_Trim_Large_Single_01", Vector3(-2.3, 6.0 + 0.48 * 0.9, zp - 0.15), Vector3(1, 0, 0), 4.6, 2.5, 0.9)
	_put(b, "SM_Bld_Wall_Large_01", Transform3D(Basis.from_scale(Vector3(0.94, 1.0 / 4.51, 0.8)), Vector3(-2.35, 6.86, zp - 0.3)), MARBLE_BLOCKS)
	_box(b, "#marble", Vector3(0, 7.35, R + 0.2), Vector3(4.6, 1.0, 1.0))
	_run(b, "SM_Bld_Wall_Large_Cap_01", Vector3(-2.45, 7.82, zp - 0.3), Vector3(1, 0, 0), 4.9, 5.0, 1.0, 0.9)
	_inscription(b, "LXXX", Vector3(0, 7.06, zp), 1.3)
	_statue(b, Vector3(0, 8.12, zp - 0.5), 0.0, 1.0, 4)
	for sd: float in [-1.0, 1.0]:
		b.add("SM_Prop_Statue_Lion_01", Vector3(sd * 1.75, 8.12, zp - 0.9), 0.0, 0.36)
		b.add("SM_Prop_Banner_03_%s" % ["E", "B"][int(sd > 0)], Vector3(sd * 1.0, 6.0, zp + 0.25), 0.0, 0.6)
	b.door = Vector3(0, 0, zp + 1.0)


# ---------- пантеон ----------

## Пантеон: кирпичная ротонда с белыми карнизами и пилястрами, пологий свинцово-серый купол со ступенчатыми кольцами
## и окулюсом, портик из восьми коринфских колонн с синим фронтоном, бронзовые врата между двумя большими нишами
## со статуями Августа и Агриппы
static func _pantheon(b: Bp) -> void:
	var R := 6.5
	var n := 16
	var sw := 2.0 * R * tan(PI / n)
	var cw := 2.0 * (R + 0.6) * tan(PI / n)
	var rp := (R + 0.34) / cos(PI / n) - 0.1
	for i in n:
		var ang := i * TAU / n
		var aj := ang + PI / n
		for f in 2:
			_ring_put(b, "SM_Bld_Wall_Large_01", ang, R, f * 4.51, sw, 5.0, 1.0, 1.0, BRICK)
			_ring_put(b, "SM_Bld_Wall_Large_Cap_01", ang, R + 0.12, f * 4.51 + 4.4, cw, 5.0, 1.0, 1.0)
			# пилястра на каждом стыке граней (и закрывает щели между ними)
			_put(b, "SM_Bld_Wall_Large_Pillar_01", Transform3D(Basis(Vector3.UP, aj) * Basis.from_scale(Vector3(0.45, 4.4 / 4.55, 0.45)), Vector3(sin(aj), 0, cos(aj)) * rp + Vector3(0, f * 4.51, 0)))
	var top := 9.02
	# купол: три гладких ступенчатых кольца из травертина и пологая свинцовая чаша (как у настоящего Пантеона)
	for i in n:
		var ang := (i + 0.5) * TAU / n
		for rr: Array in [[R - 0.5, 0.3], [R - 0.95, 0.77], [R - 1.36, 1.27]]:   # кольца заходят друг за друга (у детали нет задней стенки)
			var r: float = rr[0]
			_ring_put(b, "SM_Bld_Bath_Edge_01", ang, r, top + (rr[1] as float), 2.0 * r * tan(PI / n) + 0.06, 2.5, 1.0, 1.0, RING_STONE)
	var kx := 2.45
	var ky := 1.3
	var by := top + 0.9 - 3.6 * ky
	_put(b, "SM_Prop_Pergola_01", Transform3D(Basis.from_scale(Vector3(kx, ky, kx)), Vector3(0, by, 0)), DOME_LEAD)
	# окулюс: две свинцовые ступени вокруг вершины (прячут навершие беседки), внутри — тёмный проём
	var tip := by + 6.02 * ky
	for i in 8:
		var ang := i * PI / 4.0
		_ring_put(b, "SM_Bld_Bath_Edge_01", ang, 1.6, by + 5.25 * ky + 0.07, 2.0 * 1.84 * tan(PI / 8.0) + 0.04, 2.5, 1.0, 1.0, RING_LEAD)
		_ring_put(b, "SM_Bld_Bath_Edge_01", ang, 1.2, tip + 0.05 - 0.21 * 0.75, 2.0 * 1.39 * tan(PI / 8.0) + 0.04, 2.5, 0.75, 0.8, RING_LEAD)
	for k in 2:
		_box(b, "#dark", Vector3(0, tip + 0.01, 0), Vector3(1.96, 0.04, 1.96), k * PI / 4.0)
	# промежуточный корпус с вратами и нишами
	var pod := 1.5
	var bz := 7.6                        # передняя стена корпуса
	var bx := 4.5
	for sd: float in [-1.0, 1.0]:
		for f in 2:
			_run(b, "SM_Bld_Wall_Large_01", Vector3(sd * bx, f * 4.51, bz if sd > 0 else 4.4), Vector3(0, 0, -sd), bz - 4.4, 5.0, 1.0, 1.0)
		_put(b, "SM_Bld_Wall_Large_01", Transform3D(Basis.from_scale(Vector3(2.52 / 5.0, (top - pod - 4.51) / 4.51, 1)), Vector3(sd * 1.98 + (0.0 if sd > 0 else -2.52), pod + 4.51, bz)))
		b.add("SM_Bld_Wall_Alcove_Large_01", Vector3(sd * 1.98 + (0.0 if sd > 0 else -2.5), pod, bz))
		_statue(b, Vector3(sd * 3.23, pod + 0.3, bz - 0.25), 0.0, 1.15, 4 if sd < 0 else 6)
	_put(b, "SM_Bld_Door_Monument_01", Transform3D(Basis.from_scale(Vector3(0.76, 0.75, 0.76)), Vector3(-1.98 + 0.08, pod, bz)))
	_put(b, "SM_Bld_Wall_Large_01", Transform3D(Basis.from_scale(Vector3(3.96 / 5.0, (top - pod - 6.84) / 4.51, 1)), Vector3(-1.98, pod + 6.84, bz)))
	_box(b, "#marble", Vector3(0, top / 2.0, (bz + 4.4) / 2.0), Vector3(2.0 * bx - 0.4, top, bz - 4.4))
	# портик на подиуме, пол вымощен плитами
	var hx := 6.6
	var zc0 := 10.6
	var zfp := 11.3
	_podium(b, -hx, hx, bz - 0.2, zfp, pod, [1, 3])
	_floor(b, PORCH, -hx, bz - 0.2, hx, zfp, pod + 0.02, 3, 1)
	var zfront := _front_stairs(b, -6.25, 6.25, zfp, pod)
	for sd: float in [-1.0, 1.0]:
		_big_brazier(b, Vector3(sd * 6.67, pod + 0.72, zfp + 1.6), 0.62)
	for i in 8:
		b.add("SM_Bld_Pillar_Large_04", Vector3(-6.125 + i * 1.75, pod, zc0))
	for sd: float in [-1.0, 1.0]:
		_big_brazier(b, Vector3(sd * 4.4, pod, bz + 1.2), 0.55)
	for x: float in [-6.125, -2.625, 2.625, 6.125]:
		b.add("SM_Bld_Pillar_Large_03", Vector3(x, pod, zc0 - 1.75))     # второй ряд почти не виден — лёгкая модель
	for x: float in [-6.125, 6.125]:
		b.add("SM_Bld_Pillar_Large_01", Vector3(x, pod, bz + 0.35))
	var eave := _entablature(b, -hx - 0.05, hx + 0.05, bz - 0.1, zc0 + 0.45, pod + 6.0, [0, 1, 3])
	var half := hx + 0.2
	var ridge := _temple_roof(b, half, zc0 + 0.8, bz - 0.4, eave, true, true, TYMPANUM)
	_pediment(b, half, eave, zc0 + 0.8, ridge)
	_at(b, "SM_Prop_Drapery_03", Vector3(0, pod + 5.95, zc0 + 0.4), 0.0, 0.7, SWAG_RED)
	# кипарисы, лавры и цветы вокруг
	for sd: float in [-1.0, 1.0]:
		_cypress(b, Vector3(sd * 6.2, 0, -5.4), 0.95)
		_cypress(b, Vector3(sd * 7.4, 0, 2.6), 0.85)
		b.add("SM_Env_Tree_Bush_0%d" % (1 + b.rng.randi() % 2), Vector3(sd * 7.2, 0, 5.6), b.rng.randf() * TAU, 0.6)
		_pot(b, Vector3(sd * (hx - 0.25), pod, zfp - 0.35), 0.55)
		b.add(_ivy_flat(b), Vector3(sin(sd * 2.2) * (R + 0.4), 1.6, cos(sd * 2.2) * (R + 0.4)), sd * 2.2, 1.3)
	b.door = Vector3(0, 0, zfront + 0.7)
