class_name NewGrand
extends RefCounted
## Новые пантеон, академия, форум и храм Венеры и Ромы (владелец 13.11: «пересобрать модельки» — новые здания из деталей
## Synty POLYGON Ancient Empire, а не украшенные прежние; «темноты вообще не должно быть»; у каждого здания своё
## основание; размеры — по утверждённой линейке SizeLadder, мерка — дом плебеев 2,8 × 4 м). Собраны с нуля в метрах
## города (base делит на масштаб Catalog, тот потом умножает обратно), фасад к +Z, вход — b.door; образец — NewTemple.
##  - пантеон (≈ 100 м², «главные», было 71): кирпичная ротонда с белыми карнизами и пилястрами, в нижнем ярусе —
##    окна с фронтончиками (за ними тёплый свет), в верхнем — медальоны и знамёна; свинцовый купол на трёх
##    ступенчатых кольцах (не выше 7 м — храм Юпитера остаётся главным), портик из восьми коринфских колонн с синим
##    фронтоном и золотым рельефом, промежуточный корпус с нишами Августа и Агриппы и бронзовыми вратами;
##  - академия (≈ 96 м², «главные»): зал философов с ионическим портиком и фронтоном, окна и врата открывают тёплый зал
##    со свитками (окна и сзади); перед ним — сад-перистиль: крытые колоннады с росписями и скамьями (снаружи — окна,
##    фриз, медальоны), деревья в цветниках, солнечные часы, философ и ученики; по фронту — парапет с меандром
##    и ворота-пропилей;
##  - форум (≈ 66 м², «большие»): курия из тёплого травертина на подиуме с ионическим портиком и бронзовыми вратами,
##    перед ней — ростра с бронзовыми медальонами и балюстрадой (оратор речи Spectacle), площадь с мозаикой для
##    слушателей, по бокам — галереи с лавками под черепицей (снаружи — окна, фриз, медальоны над дверями), у входа —
##    постаменты со статуями;
##  - храм Венеры и Ромы (≈ 68 м², «большие»): периптер на трёхступенчатом основании (колонны со всех сторон),
##    розовая целла, золочёная черепица, синие фронтоны с золотом; за бронзовыми вратами — светлый зал с золотой
##    Венерой, сзади — закрытые врата Ромы; у лестницы — алтарь, статуи Венеры и Ромы, розы, кипарисы.
## У каждого — мощёный двор по всему следу с бордюром, уходящим в землю (Land под ним ничего не стелет: City.apron_of = 0);
## за каждой дверью и окном — освещённая комната (тёплое свечение материала, remap «glow»), закрытые двери или открытый
## двор. Академия, форум и храм Венеры — внутри прежних следов (старые сохранения стоят на тех же клетках без правок);
## пантеон из старого сохранения (Catalog.fit, SizeLadder.old_lot) собирается под прежние клетки (7,0 × 9,8 м: шесть
## колонн, ротонда меньше, те же высоты), а City.ladder_grow выращивает его в полный, где есть место.
## Прежние сборки (CatMonuments, CatCivic, CatGrand) остаются: ON — выключатели по типу (снимки «было/стало»);
## CIVCITY_NEWGRAND=0 — прежние во всей игре.

static var ON := {"pantheon": true, "academy": true, "forum": true, "venus": true} if OS.get_environment("CIVCITY_NEWGRAND") != "0" \
	else {"pantheon": false, "academy": false, "forum": false, "venus": false}
const TYPES := ["pantheon", "academy", "forum", "venus"]

const Y0 := 0.06                 # верх мощёного двора
const WT := 0.16                 # толщина стен
## Прежний пантеон (CatMonuments._pantheon, замер test_b2_probe): след в осях постройки — x0, x1, z0, z1
const PAN_OLD := [-3.59, 3.57, -3.27, 6.61]
const PAN_FULL := Vector2(8.9, 11.2)

const PAVING := {"Stone_01": "Floor_Tiles_06"}
const WARM_PAVING := {"Stone_01": "Floor_Tiles_03"}
const PORCH := {"Stone_01": "Floor_Tiles_02"}
const MOSAIC := {"Stone_01": "Floor_Tiles_Circle_01"}
const MARBLE := {"Stucco_White_01": "Building_Marble_01"}
const MARBLE_PIER := {"Building_Large_Brick_01": "Building_Marble_01"}
const MARBLE_BLOCKS := {"Building_Large_Brick_01": "Building_Marble_03"}
const TRAV := {"Stucco_White_01": "Stone_01", "tints": {"Stone_01": Color(1.08, 0.97, 0.82)}}     # тёплый травертин (курия форума)
const TYMPANUM := {"Stone_01": "Stucco_Blue_01", "tints": {"Stucco_Blue_01": Color(0.78, 0.87, 1.0)}}
const FRIEZE := {"Stucco_Blue_01": "Building_Marble_03"}
const GOLD := Color(1.0, 0.78, 0.36)
const BRONZE := Color(0.7, 0.48, 0.28)
const WARM := Color(0.3, 0.18, 0.09)       # свечение нутра: тёплое, неяркое
const FLAME := {"tint": Color(1.0, 0.55, 0.16), "glow": Color(1.2, 0.46, 0.1)}
const GOLD_STATUE := {"tints": {"Statue_01": GOLD}}
const BRONZE_STATUE := {"tints": {"Statue_01": BRONZE}}
const GOLD_RELIEF := {"tints": {"Building_Marble_01": GOLD}}
const GOLD_ROOF := {"Roof_Tile_01": "Roof_Tile_05", "tints": {"Roof_Tile_05": Color(1.25, 1.02, 0.5)}}
const SWAG_RED := {"PolygonAncientEmpire_01_A": "PolygonAncientEmpire_01_B"}
## Пантеон: римский кирпич ротонды, свинцовый купол и кольца
const BRICK := {"Stucco_White_01": "Brick_Brown_Tex", "tints": {"Brick_Brown_Tex": Color(1.32, 1.1, 0.95)}}
const LEAD := {"Stucco_Blue_01": "Stucco_White_01", "tints": {"Stucco_White_01": Color(0.7, 0.71, 0.69)}}
const LEAD_RING := {"Building_Large_Brick_01": "Stucco_White_01", "tints": {"Stucco_White_01": Color(0.76, 0.76, 0.73)}}
const STONE_RING := {"Building_Large_Brick_01": "Stone_01"}
## Академия: кремовая штукатурка (и стена окна Synty — тоже кремовая)
const CREAM := {"Stucco_White_01": "Stucco_White_01", "Stucco_Orange_01": "Stucco_White_01", "tints": {"Stucco_White_01": Color(1.0, 0.94, 0.84)}}
const CREAM_TYM := {"Stone_01": "Stucco_White_01", "tints": {"Stucco_White_01": Color(1.0, 0.94, 0.84)}}
## Свечение за окном (тёплая комната): тонкая стенка сразу за проёмом
const GLOW_PANEL := {"Stucco_White_01": "Stucco_Orange_01", "glow": Color(0.39, 0.23, 0.12)}
## Окно Synty в кирпичной стене ротонды (рама и фронтончик — белые)
const BRICK_WIN := {"Stucco_Orange_01": "Brick_Brown_Tex", "tints": {"Brick_Brown_Tex": Color(1.32, 1.1, 0.95)}}
## Храм Венеры: розовая целла
const ROSE := {"Stucco_White_01": "Stucco_Red_01", "tints": {"Stucco_Red_01": Color(1.3, 1.07, 1.03)}}


static func covers(type: String) -> bool:
	return bool(ON.get(type, false))


static func build(b: Bp, type: String) -> void:
	var K := Catalog.scale_of(type)
	b.base = Transform3D(Basis.from_scale(Vector3.ONE / K), Vector3.ZERO)
	var door := Vector3.ZERO
	match type:
		"pantheon": door = _pantheon(b, _pan_dims(Catalog.fit))
		"academy": door = _academy(b)
		"forum": door = _forum(b)
		"venus": door = _venus(b)
	b.base = Transform3D.IDENTITY
	b.door = door / K


# =====================================================================
#   помощники (метры города, фасад к +Z)
# =====================================================================

static func _p(b: Bp, name: String, p: Vector3, yaw := 0.0, s := Vector3.ONE, rm := {}) -> void:
	b.parts.append([name, b.base * Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(s), p), rm])


static func _u(b: Bp, name: String, p: Vector3, yaw: float, s: float, rm := {}) -> void:
	_p(b, name, p, yaw, Vector3.ONE * s, rm)


static func _box(b: Bp, c: Vector3, sz: Vector3, yaw := 0.0) -> void:
	b.parts.append(["#marble", b.base * Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(sz), c), {}])


## Мраморное ядро; посередине (x ≈ 0) — двумя половинами: у форума широкое ядро посредине одно — ростра (по ней
## Spectacle ищет место оратора)
static func _core(b: Bp, c: Vector3, sz: Vector3) -> void:
	if absf(c.x) < 0.5 and sz.x > 1.2:
		var h := sz.x / 4.0
		_box(b, c - Vector3(h, 0, 0), Vector3(sz.x / 2.0 + 0.01, sz.y, sz.z))
		_box(b, c + Vector3(h, 0, 0), Vector3(sz.x / 2.0 + 0.01, sz.y, sz.z))
	else:
		_box(b, c, sz)


static func _run(b: Bp, name: String, a: Vector3, dir: Vector3, len: float, pw: float, sy: float, sz: float, rm := {}, seg := 1.25) -> void:
	NewTemple._run(b, name, a, dir, len, pw, sy, sz, rm, seg)


static func _ring(b: Bp, name: String, x0: float, x1: float, z0: float, z1: float, y: float, pw: float, sy: float, sz: float, rm := {}, sides := [0, 1, 2, 3], seg := 1.25) -> void:
	NewTemple._ring(b, name, x0, x1, z0, z1, y, pw, sy, sz, rm, sides, seg)


static func _floor(b: Bp, rm: Dictionary, x0: float, z0: float, x1: float, z1: float, y: float, cell := 1.3) -> void:
	NewTemple._floor(b, rm, x0, z0, x1, z1, y, cell)


## Своё основание: мощёный двор по всему следу, по краю — бордюр из тёсаного камня, уходящий в землю
static func _court(b: Bp, x0: float, x1: float, z0: float, z1: float, rm := PAVING, cell := 1.45) -> void:
	_floor(b, rm, x0, z0, x1, z1, Y0, cell)
	var e := 0.055
	_ring(b, "SM_Bld_Wall_Large_01", x0 + e, x1 - e, z0 + e, z1 - e, -0.45, 5.0, (Y0 + 0.47) / 4.51, 0.16, {}, [0, 1, 2, 3], 1.45)


## Тёсаный камень (блоки в натуральных пропорциях) от a.y до y1 вдоль dir
static func _stone(b: Bp, a: Vector3, dir: Vector3, len: float, y1: float, sz: float) -> void:
	NewTemple._stone(b, a, dir, len, y1, sz)


## Подиум x ±px, z z0..z1 высотой до y1: мраморное ядро, тёсаный камень по сторонам sides, карниз по верху
static func _podium(b: Bp, px: float, z0: float, z1: float, y1: float, sides := [1, 2, 3]) -> void:
	_core(b, Vector3(0, (Y0 + y1) / 2.0, (z0 + z1) / 2.0), Vector3(2.0 * px - 0.06, y1 - Y0 - 0.02, z1 - z0 - 0.06))
	var top := y1 - 0.05
	var yb := Y0 - 0.3
	if 0 in sides:
		_stone(b, Vector3(-px, yb, z1), Vector3(1, 0, 0), 2.0 * px, top, 0.22)
	if 1 in sides:
		_stone(b, Vector3(px, yb, z1), Vector3(0, 0, -1), z1 - z0, top, 0.22)
	if 2 in sides:
		_stone(b, Vector3(px, yb, z0), Vector3(-1, 0, 0), 2.0 * px, top, 0.22)
	if 3 in sides:
		_stone(b, Vector3(-px, yb, z0), Vector3(0, 0, 1), z1 - z0, top, 0.22)
	_ring(b, "SM_Bld_Wall_Large_Cap_01", -px - 0.03, px + 0.03, z0 - 0.03, z1 + 0.03, top - 0.01, 5.0, 0.3, 0.22, {}, sides, 1.6)


## Лестница шириной x0..x1 от переднего края zf назад на depth, высотой h (марш Synty: восемь ступеней)
static func _stairs(b: Bp, x0: float, x1: float, zf: float, depth: float, h: float) -> void:
	var n := maxi(1, int(ceil((x1 - x0) / 2.5)))
	var w := (x1 - x0) / n
	for i in n:
		_p(b, "SM_Bld_Stairs_01", Vector3(x0 + i * w, Y0, zf), 0.0, Vector3(w / 2.5, h / 1.5, depth / 2.5))


static func _fire(b: Bp, c: Vector3, s: float) -> void:
	NewTemple._fire(b, c, s)


## Огонь в бронзовой чаше на мраморной тумбе (верх тумбы — на высоте ph над y)
static func _altar(b: Bp, p: Vector3, ps: float, bs: float, fs: float) -> void:
	_p(b, "SM_Prop_Plinth_04", p, 0.0, Vector3.ONE * ps)
	_u(b, "SM_Prop_Brazier_04", p + Vector3(0, 0.68 * ps, 0), 0.0, bs)
	_fire(b, p + Vector3(0, 0.68 * ps + 0.08 * bs / 0.46, 0), fs)


## Колонны в ряд: детали name высотой hc в точках xs на z
static func _cols(b: Bp, name: String, xs: Array, z: float, y: float, hc: float) -> void:
	var k := hc / 6.0 if name.begins_with("SM_Bld_Pillar_Large") else hc / 3.0
	for x: float in xs:
		_p(b, name, Vector3(x, y, z), 0.0, Vector3(k, k, k))


## Антаблемент x ±ex, z ez0..ez1 от ye высотой ent: мраморное ядро, архитрав с меандром, расписной фриз; углы — где
## сходятся обе стороны
static func _entab(b: Bp, ex: float, ez0: float, ez1: float, ye: float, ent: float, sides := [0, 1, 2, 3]) -> void:
	_core(b, Vector3(0, ye + ent / 2.0, (ez0 + ez1) / 2.0), Vector3(2.0 * ex - 0.06, ent - 0.02, ez1 - ez0 - 0.06))
	var s1 := ent * 0.5
	var s2 := ent * 0.5
	_ring(b, "SM_Bld_Trim_Large_Single_01", -ex + 0.15, ex - 0.15, ez0 + 0.15, ez1 - 0.15, ye + 0.48 * s1, 2.5, s1, 0.3, {}, sides, 1.5)
	_ring(b, "SM_Bld_Trim_Large_Single_02", -ex + 0.1, ex - 0.1, ez0 + 0.1, ez1 - 0.1, ye + 0.96 * s1 + 0.485 * s2, 2.5, s2, 0.3, FRIEZE, sides, 1.5)
	for c: Array in [[-1.0, 1.0, 0.0, 3, 0], [1.0, 1.0, PI / 2, 0, 1], [1.0, -1.0, PI, 1, 2], [-1.0, -1.0, -PI / 2, 2, 3]]:
		if not (int(c[3]) in sides and int(c[4]) in sides):
			continue
		var cx: float = c[0]
		var cz: float = c[1]
		var za := ez1 - 0.15 if cz > 0 else ez0 + 0.15
		var zb := ez1 - 0.1 if cz > 0 else ez0 + 0.1
		_p(b, "SM_Bld_Trim_Large_Corner_01", Vector3(cx * (ex - 0.15), ye + 0.48 * s1, za), float(c[2]), Vector3(0.3, s1, 0.3))
		_p(b, "SM_Bld_Trim_Large_Corner_01", Vector3(cx * (ex - 0.1), ye + 0.96 * s1 + 0.485 * s2, zb), float(c[2]), Vector3(0.2, s2, 0.2))


## Двускатная кровля вдоль z (конёк по оси), фронтоны на концах ends [перед, зад]: тимпан tym, карнизы по скатам.
## pitch — круче ската (1 — как у храма). Возвращает высоту конька
static func _roof_z(b: Bp, rh: float, rz0: float, rz1: float, top: float, roof_rm := {}, tym := TYMPANUM, ends := [true, true], pitch := 1.0) -> float:
	var k := rh / 7.5
	var ky := k * pitch
	var len := rz1 - rz0
	var n := maxi(1, int(ceil(len / 3.4)))
	var lz := len / n
	for i in n:
		var z0 := rz0 + i * lz
		_p(b, "SM_Bld_Roof_Straight_Thin_Large_01", Vector3(-rh, top, z0), -PI / 2, Vector3(lz / 7.5, ky, k), roof_rm)
		_p(b, "SM_Bld_Roof_Straight_Thin_Large_01", Vector3(rh, top, z0 + lz), PI / 2, Vector3(lz / 7.5, ky, k), roof_rm)
	var trm := tym.duplicate(true)
	for kk in roof_rm:
		if kk != "tints":
			trm[kk] = roof_rm[kk]
	if roof_rm.has("tints"):
		var tt: Dictionary = trm.get("tints", {}).duplicate()
		tt.merge(roof_rm["tints"])
		trm["tints"] = tt
	for e: Array in [[rz1, bool(ends[0])], [rz0, bool(ends[1])]]:
		if not bool(e[1]):
			continue
		var zz: float = e[0]
		var zi := zz - 0.1 if zz == rz1 else zz + 0.1
		var zt := zz - 0.02 if zz == rz1 else zz + 0.02
		_p(b, "SM_Bld_Roof_Side_Large_01", Vector3(-rh + 0.05, top, zi), -PI / 2, Vector3(0.45, ky, k), trm)
		_p(b, "SM_Bld_Roof_Side_Large_01", Vector3(rh - 0.05, top, zi), PI / 2, Vector3(0.45, ky, k), trm)
		_p(b, "SM_Bld_Roof_Straight_Thin_Large_01_Trim_01", Vector3(-rh, top, zt), -PI / 2, Vector3(0.3, ky, k))
		_p(b, "SM_Bld_Roof_Straight_Thin_Large_01_Trim_01", Vector3(rh, top, zt), PI / 2, Vector3(0.3, ky, k))
	return top + 1.94 * ky


## Рельеф фронтона: золотые фигуры на синем — посередине сцена, по бокам две фигуры (и львы по углам, если wide)
static func _relief(b: Bp, rh: float, top: float, ridge: float, z: float, yaw: float, wide := true, mid := "SM_Prop_Symbol_05") -> void:
	var h := ridge - top
	var bs := Basis(Vector3.UP, yaw)
	_u(b, mid, Vector3(0, top + 0.04, z), yaw, h * 0.86, GOLD_RELIEF)
	_u(b, "SM_Prop_Symbol_15", bs * Vector3(-rh * 0.33, 0, 0) + Vector3(0, top + 0.04, z), yaw, h * 0.58, GOLD_RELIEF)
	_u(b, "SM_Prop_Symbol_10", bs * Vector3(rh * 0.33, 0, 0) + Vector3(0, top + 0.04, z), yaw, h * 0.58, GOLD_RELIEF)
	if wide:
		_u(b, "SM_Prop_Symbol_20", bs * Vector3(-rh * 0.6, 0, 0) + Vector3(0, top + 0.04, z), yaw, h * 0.36, GOLD_RELIEF)
		_u(b, "SM_Prop_Symbol_20", bs * Vector3(rh * 0.6, 0, 0) + Vector3(0, top + 0.04, z), yaw, h * 0.36, GOLD_RELIEF)


## Акротерии: статуя на коньке (z, yaw), по углам фронтона — розетки на тумбах
static func _acro(b: Bp, rh: float, top: float, ridge: float, z: float, yaw: float, statue: String, s: float, rm := GOLD_STATUE) -> void:
	var dz := -0.14 if yaw == 0.0 else 0.14
	_u(b, statue, Vector3(0, ridge - 0.04, z + dz), yaw, s, rm)
	for sd: float in [-1.0, 1.0]:
		_p(b, "SM_Prop_Plinth_02", Vector3(sd * (rh - 0.14), top, z + dz), 0.0, Vector3(0.32, 0.12, 0.32))
		_u(b, "SM_Bld_Ornament_06", Vector3(sd * (rh - 0.14), top + 0.22, z + dz * 0.3), yaw, 0.3)


## Стена с проёмом двери: от x0 до x1 по линии fz (середина толщины, лицо к +Z), проём cx ± dw высотой dh
static func _door_wall(b: Bp, x0: float, x1: float, fz: float, y: float, h: float, cx: float, dw: float, dh: float, rm: Dictionary, lintel := MARBLE) -> void:
	var sz := WT / 0.22
	if cx - dw - x0 > 0.02:
		_run(b, "SM_Bld_Wall_01", Vector3(x0, y, fz), Vector3(1, 0, 0), cx - dw - x0, 2.5, h / 3.01, sz, rm, 1.25)
	if x1 - cx - dw > 0.02:
		_run(b, "SM_Bld_Wall_01", Vector3(cx + dw, y, fz), Vector3(1, 0, 0), x1 - cx - dw, 2.5, h / 3.01, sz, rm, 1.25)
	_p(b, "SM_Bld_Wall_01", Vector3(cx - dw, y + dh, fz), 0.0, Vector3(2.0 * dw / 2.5, (h - dh) / 3.01, sz), lintel)


## Бронзовые двустворчатые врата в стене с лицом на z = wz (наружная плоскость стены): мраморная рама с карнизом,
## створки Synty (Life распахивает их внутрь, каждую на наружной петле)
static func _gate(b: Bp, cx: float, y: float, wz: float, dw: float, dh: float, leaf := "SM_Bld_Door_Large_Half_03") -> void:
	for sd: float in [-1.0, 1.0]:
		_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(cx + sd * (dw + 0.06), y, wz + 0.02), 0.0, Vector3(0.15 / 0.92, (dh + 0.05) / 4.55, 0.14 / 0.92), MARBLE_PIER)
	_p(b, "SM_Bld_Wall_Large_Cap_01", Vector3(cx - dw - 0.2, y + dh + 0.03, wz + 0.05), 0.0, Vector3((2.0 * dw + 0.4) / 5.02, 0.5, 0.16))
	var fz := wz - WT / 2.0
	var ls := Vector3(dw / 0.56, dh / 2.47, 0.7)
	_p(b, leaf, Vector3(cx - dw, y, fz), 0.0, ls)
	_p(b, leaf, Vector3(cx, y, fz), 0.0, ls)


## Тёплое нутро комнаты x0..x1 × z0..z1 (внутренние плоскости стен) от y высотой h: облицовка стен изнутри (низ rm_lo,
## верх rm_hi — оба светятся), проём двери в передней стене (cx ± dw, высота dh; dw = 0 — без проёма), пол-мозаика
## и потолок — тоже в тёплом свете. sides — какие стены облицевать (0 перед, 1 право, 2 зад, 3 лево)
static func _room(b: Bp, x0: float, x1: float, z0: float, z1: float, y: float, h: float, cx: float, dw: float, dh: float, rm_lo: Dictionary, rm_hi: Dictionary,
		sides := [0, 1, 2, 3], band := 0.9) -> void:
	var lin := 0.02 / 0.22
	var e := 0.012
	for bd: Array in [[0.0, band, rm_lo], [band, h - band, rm_hi]]:
		var y0 := y + float(bd[0])
		var hh := float(bd[1]) / 3.01
		var rm: Dictionary = bd[2]
		if 3 in sides:
			_run(b, "SM_Bld_Wall_01", Vector3(x0 + e, y0, z1), Vector3(0, 0, -1), z1 - z0, 2.5, hh, lin, rm, 1.7)
		if 1 in sides:
			_run(b, "SM_Bld_Wall_01", Vector3(x1 - e, y0, z0), Vector3(0, 0, 1), z1 - z0, 2.5, hh, lin, rm, 1.7)
		if 2 in sides:
			_run(b, "SM_Bld_Wall_01", Vector3(x0, y0, z0 + e), Vector3(1, 0, 0), x1 - x0, 2.5, hh, lin, rm, 1.9)
		if 0 in sides:
			if dw <= 0.0:
				_run(b, "SM_Bld_Wall_01", Vector3(x1, y0, z1 - e), Vector3(-1, 0, 0), x1 - x0, 2.5, hh, lin, rm, 1.9)
			else:
				for sd: float in [-1.0, 1.0]:
					var a0 := cx + dw if sd > 0 else x0
					var a1 := x1 if sd > 0 else cx - dw
					if a1 - a0 > 0.02:
						_run(b, "SM_Bld_Wall_01", Vector3(a1, y0, z1 - e), Vector3(-1, 0, 0), a1 - a0, 2.5, hh, lin, rm, 1.3)
	if 0 in sides and dw > 0.0 and h - dh > 0.05:
		_p(b, "SM_Bld_Wall_01", Vector3(cx + dw, y + dh, z1 - e), PI, Vector3(2.0 * dw / 2.5, (h - dh) / 3.01, lin), rm_hi)
	var mosaic := {"Stone_01": "Floor_Tiles_Circle_01", "glow": WARM * 0.8}
	_floor(b, mosaic, x0, z0, x1, z1, y + 0.006, 1.6)
	var crm := {"Stone_01": "Building_Marble_01", "glow": WARM * 0.7}
	var nx := maxi(1, int(ceil((x1 - x0) / 2.5)))
	var nz := maxi(1, int(ceil((z1 - z0) / 2.5)))
	for i in nx:
		for j in nz:
			var w := (x1 - x0) / nx
			var d := (z1 - z0) / nz
			_p(b, "SM_Bld_Base_Ceiling_01", Vector3(x0 + i * w, y + h - 0.02, z0 + j * d), 0.0, Vector3(w / 2.5, 1, d / 2.5), crm)


static func _glow(k: float) -> Dictionary:
	return {"glow": WARM * k}


## Полосы на лицевой стороне прямой стены от a вдоль dir длиной len (лицо — влево от dir, как у _run): фриз
## с меандром под карнизом на высоте yf и мраморный цоколь у земли на y0
static func _bands(b: Bp, a: Vector3, dir: Vector3, len: float, yf: float, y0: float) -> void:
	var n := Vector3(-dir.z, 0, dir.x) * 0.01
	_run(b, "SM_Bld_Trim_Large_Single_02", Vector3(a.x, yf, a.z) + n, dir, len, 2.5, 0.3, 0.3, FRIEZE, 1.6)
	_run(b, "SM_Bld_Trim_05", Vector3(a.x, y0, a.z) + n, dir, len, 2.5, 0.42, 0.45, MARBLE, 1.6)


## Цветник: мраморный бортик с землёй x0..x1 × z0..z1, цветущие кусты (и, если tree, олива посередине)
static func _bed(b: Bp, x0: float, x1: float, z0: float, z1: float, n := 0, tree := "") -> void:
	var w := x1 - x0
	var d := z1 - z0
	if d >= w:
		_run(b, "SM_Bld_Floor_Trim_02", Vector3(x0, Y0, z1), Vector3(0, 0, -1), d, 2.5, 0.42, w / 1.03, {}, 1.6)
		for zz: float in [z0, z1]:
			_p(b, "SM_Bld_Wall_Tiny_01", Vector3(x0, Y0, zz), 0.0, Vector3(w / 2.5, 0.6, 0.35), MARBLE)
	else:
		_run(b, "SM_Bld_Floor_Trim_02", Vector3(x0, Y0, z0), Vector3(1, 0, 0), w, 2.5, 0.42, d / 1.03, {}, 1.6)
		for xx: float in [x0, x1]:
			_p(b, "SM_Bld_Wall_Tiny_01", Vector3(xx, Y0, z1), PI / 2, Vector3(d / 2.5, 0.6, 0.35), MARBLE)
	var cnt := n if n > 0 else maxi(2, int(maxf(w, d) / 0.62))
	var ks := clampf(minf(w, d) * 0.6, 0.3, 0.5)
	var c := Vector3((x0 + x1) / 2.0, Y0 + 0.14, (z0 + z1) / 2.0)
	for k in cnt:
		var t := (k + 0.5) / cnt
		var p := Vector3(c.x, c.y, lerpf(z1 - 0.15, z0 + 0.15, t)) if d >= w else Vector3(lerpf(x0 + 0.15, x1 - 0.15, t), c.y, c.z)
		if tree != "" and absf(t - 0.5) < 0.5 / cnt + 0.01:
			continue
		var nm: String = ["SM_Env_Garden_Plants_03", "SM_Env_Garden_Plants_04", "SM_Env_Garden_Plants_06"][k % 3]
		_p(b, nm, p, b.rng.randf() * TAU, Vector3.ONE * b.rng.randf_range(ks * 0.9, ks), {"tint": Color(1, 1, 1)})
	if tree != "":
		b.parts.append([tree, b.base * Transform3D(Basis(Vector3.UP, b.rng.randf() * TAU).scaled(Vector3.ONE * 0.36), c + Vector3(0, 0.06, 0)), {"tint": Color(0.86, 0.96, 0.78)}])


## Двускатная кровля над боковой галереей: колонны на x = xc, наружная стена у края следа xe (оба — со знаком стороны),
## от z0 до z1, свес над колоннами и до края следа; щипцы с концов (tym). Возвращает высоту конька
static func _gallery_roof(b: Bp, xc: float, xe: float, z0: float, z1: float, top: float, tym: Dictionary) -> float:
	var sd := signf(xe)
	var a := xc - sd * 0.3
	var cxm := (a + xe) / 2.0
	var rh := absf(xe - a) / 2.0
	var keep := b.base
	b.base = keep * Transform3D(Basis.IDENTITY, Vector3(cxm, 0, 0))
	var ridge := _roof_z(b, rh, z0, z1, top, {}, tym, [true, true], 1.4)
	b.base = keep
	return ridge


static func _cypress(b: Bp, p: Vector3, s := 0.42) -> void:
	_u(b, "SM_Env_Tree_Thin_0%d" % (1 + b.rng.randi() % 2), p, b.rng.randf() * TAU, s)


## Правильный многоугольник стен (ротонда): n граней по окружности радиуса r вокруг c, от y высотой h, лицом наружу
## (inward — внутрь); стена name шириной pw (родные метры), толщиной sz
static func _poly(b: Bp, name: String, c: Vector3, r: float, n: int, y: float, h: float, pw: float, ph: float, sz: float, rm := {}, inward := false, a0 := 0.0, skip := [], only := []) -> void:
	for i in n:
		if i in skip or (not only.is_empty() and not (i in only)):
			continue
		var t0 := a0 + i * TAU / n
		var t1 := a0 + (i + 1) * TAU / n
		var p0 := c + Vector3(sin(t0), 0, cos(t0)) * r
		var p1 := c + Vector3(sin(t1), 0, cos(t1)) * r
		var d := p1 - p0
		var out := Vector3(-d.z, 0, d.x)
		var mid := (p0 + p1) * 0.5 - c
		if (out.dot(mid) > 0.0) == inward:
			var tmp := p0
			p0 = p1
			p1 = tmp
			d = -d
		var yaw := atan2(-d.z, d.x)
		_p(b, name, Vector3(p0.x, y, p0.z), yaw, Vector3(d.length() / pw, h / ph, sz), rm)


# =====================================================================
#   пантеон
# =====================================================================

## Размеры по следу: fit = Vector2.ZERO — полный (линейка, ≈ 100 м²); иначе — прежние клетки старого сохранения
static func _pan_dims(fit: Vector2) -> Dictionary:
	var full := fit == Vector2.ZERO or (fit.x >= PAN_FULL.x and fit.y >= PAN_FULL.y)
	var d := {"full": full}
	if full:
		d["X"] = PAN_FULL.x / 2.0
		d["Z0"] = -4.6
		d["Z1"] = 6.6
		d["R"] = 3.4
		d["ncol"] = 8
		d["step"] = 0.8
		d["HC"] = 3.0
		d["BW"] = 2.55
		d["deep"] = 1.75
	else:
		d["X"] = minf(fit.x, PAN_OLD[1] - PAN_OLD[0]) / 2.0 - 0.06
		d["Z0"] = float(PAN_OLD[2]) + 0.05
		d["Z1"] = float(PAN_OLD[3]) - 0.06
		d["R"] = 2.9
		d["ncol"] = 6
		d["step"] = 0.9
		d["HC"] = 2.9
		d["BW"] = 2.15
		d["deep"] = 1.3
	d["HP"] = 0.54
	d["YP"] = Y0 + 0.54
	d["SZ1"] = float(d["Z1"]) - 0.75           # передний край лестницы
	d["PF"] = float(d["SZ1"]) - 0.8            # передний край подиума портика
	d["CF"] = float(d["PF"]) - 0.3             # передний ряд колонн
	d["BF"] = float(d["CF"]) - float(d["deep"]) # лицо промежуточного корпуса (врата)
	d["ZR"] = float(d["BF"]) - 0.45 - float(d["R"])   # середина ротонды
	var cols: Array[float] = []
	var n: int = d["ncol"]
	for i in n:
		cols.append((i - (n - 1) / 2.0) * float(d["step"]))
	d["cols"] = cols
	d["PX"] = cols[n - 1] + 0.45
	d["HD"] = float(d["YP"]) + 3.7             # верх стен ротонды
	return d


static func _pantheon(b: Bp, d: Dictionary) -> Vector3:
	var X: float = d["X"]
	var Z0: float = d["Z0"]
	var Z1: float = d["Z1"]
	var R: float = d["R"]
	var ZR: float = d["ZR"]
	var YP: float = d["YP"]
	var HC: float = d["HC"]
	var KC := HC / 6.0
	var BF: float = d["BF"]
	var CF: float = d["CF"]
	var PF: float = d["PF"]
	var SZ1: float = d["SZ1"]
	var PX: float = d["PX"]
	var BW: float = d["BW"]
	var HD: float = d["HD"]
	var cols: Array[float] = d["cols"]
	var full: bool = d["full"]
	var c := Vector3(0, 0, ZR)
	_court(b, -X, X, Z0, Z1, PAVING)
	# --- ротонда: цоколь из травертина, два яруса кирпича с белыми поясами и пилястрами, карниз
	var N := 16
	# грани и углы, что спрятаны в промежуточном корпусе (спереди, в его ширину), — не ставим: там сени за вратами
	var hid := []
	for i in N:
		if absf(sin(i * TAU / N)) * R < BW + 0.05 and absf(sin((i + 1) * TAU / N)) * R < BW + 0.05 and cos((i + 0.5) * TAU / N) > 0.0:
			hid.append(i)
	_poly(b, "SM_Bld_Wall_Large_01", c, R + 0.1, N, Y0 - 0.3, YP - Y0 + 0.28, 5.0, 4.51, 0.4, STONE_RING)
	# нижний ярус: через грань — окна с фронтончиком (за ними — тёплая комната), между ними кирпич
	var win := []
	for i in N:
		if not (i in hid) and i % 2 == 1:
			win.append(i)
	_poly(b, "SM_Bld_Wall_01", c, R, N, YP - 0.02, 2.1, 2.5, 3.01, 1.6, BRICK, false, 0.0, hid + win)
	_poly(b, "SM_Bld_Wall_Window_05", c, R, N, YP - 0.02, 2.1, 2.5, 3.01, 0.7, BRICK_WIN, false, 0.0, [], win)
	_poly(b, "SM_Bld_Wall_01", c, R - 0.3, N, YP + 0.1, 1.9, 2.5, 3.01, 0.1, GLOW_PANEL, false, 0.0, [], win)
	_poly(b, "SM_Bld_Wall_01", c, R, N, YP + 2.08, HD - YP - 2.08, 2.5, 3.01, 1.6, BRICK, false, 0.0, hid)
	_poly(b, "SM_Bld_Trim_05", c, R + 0.03, N, YP + 1.95, 0.5 * 0.5, 2.5, 0.5, 0.8, MARBLE, false, 0.0, hid)
	_poly(b, "SM_Bld_Wall_Large_Cap_01", c, R + 0.1, N, HD - 0.06, 0.36 * 0.75, 5.02, 0.36, 0.42, {}, false, 0.0, hid)
	_poly(b, "SM_Bld_Wall_Large_Cap_01", c, R + 0.06, N, YP - 0.06, 0.36 * 0.5, 5.02, 0.36, 0.3, {}, false, 0.0, hid)
	for i in N:
		var t := i * TAU / N
		if absf(sin(t)) * R < BW + 0.05 and cos(t) > 0.0:
			continue
		var q := c + Vector3(sin(t), 0, cos(t)) * (R + 0.06)
		_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(q.x, YP + 0.12, q.z), t, Vector3(0.34 / 0.92, (1.83) / 4.55, 0.2 / 0.92), MARBLE_PIER)
		_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(q.x, YP + 2.33, q.z), t, Vector3(0.3 / 0.92, (HD - YP - 2.45) / 4.55, 0.18 / 0.92), MARBLE_PIER)
	# медальоны в верхнем ярусе (через грань, кроме спрятанных за корпусом)
	for i in N:
		var t := (i + 0.5) * TAU / N
		if absf(wrapf(t, -PI, PI)) < 0.75:
			continue
		if i % 2 == 0:
			var q := c + Vector3(sin(t), 0, cos(t)) * (R * cos(PI / N) + 0.13)
			_u(b, "SM_Bld_Ornament_04", Vector3(q.x, YP + 2.95, q.z), t, 0.42)
		elif i in win:
			# красные знамёна над окнами, с карниза
			var q := c + Vector3(sin(t), 0, cos(t)) * (R * cos(PI / N) + 0.2)
			_u(b, "SM_Prop_Banner_03_C", Vector3(q.x, HD - 0.08, q.z), t, 0.42)
	# --- купол: три ступенчатых свинцовых кольца, купол с рёбрами (беседка Synty — её колонны спрятаны в ротонде)
	var rings := [[R - 0.18, HD + 0.2, 0.3], [R - 0.52, HD + 0.44, 0.28], [R - 0.86, HD + 0.66, 0.24]]
	for k in rings.size():
		var rr: Array = rings[k]
		var yb: float = float(rr[1]) - float(rr[2]) - (0.22 if k == 0 else 0.06)
		_poly(b, "SM_Bld_Wall_Large_01", c, float(rr[0]), N, yb, float(rr[1]) - yb, 5.0, 4.51, 0.62, LEAD_RING if k > 0 else STONE_RING, false, PI / N)
	var rd := R - 0.9                                  # радиус основания купола
	var kx := rd / 2.56
	var ky := 0.85 if full else 0.75
	var yd := HD + 0.6
	_p(b, "SM_Prop_Pergola_01", Vector3(0, yd - 3.6 * ky, ZR), 0.0, Vector3(kx, ky, kx), LEAD)
	# окулюс: бронзовое кольцо вокруг вершины
	var ytop := yd + (5.25 - 3.6) * ky
	_poly(b, "SM_Bld_Wall_Large_01", Vector3(0, 0, ZR), 0.5 * kx / 0.95, 8, ytop - 0.1, 0.16, 5.0, 4.51, 0.3, {"Building_Large_Brick_01": "Stucco_White_01", "tints": {"Stucco_White_01": BRONZE}})
	# --- промежуточный корпус: ниши Августа и Агриппы, бронзовые врата, сзади уходит в ротонду
	var bz0 := ZR + R * 0.55
	var fzc := BF - WT / 2.0
	var DW := 0.62 if full else 0.55
	var DH := 2.5 if full else 2.35
	var vx := DW + 0.3                                 # сени за вратами: x ±vx, глубина vd
	var vd := 1.2
	for sd: float in [-1.0, 1.0]:
		_run(b, "SM_Bld_Wall_01", Vector3(sd * BW, YP, BF if sd > 0 else bz0), Vector3(0, 0, -sd), BF - bz0, 2.5, (HD - YP) / 3.01, WT / 0.22, BRICK, 1.6)
	# фасад корпуса: ниши по бокам, между ними и вратами — простенки, над всем — стена до карниза
	var aw := BW - vx - 0.12                           # ширина ниши
	var ah := minf(2.95, HD - YP - 0.5)
	for sd: float in [-1.0, 1.0]:
		var x0 := -BW if sd < 0 else vx + 0.12
		_p(b, "SM_Bld_Wall_Alcove_Large_01", Vector3(x0, YP, fzc), 0.0, Vector3(aw / 2.5, ah / 4.51, 0.6))
		var st := "SM_Prop_Statue_06" if sd < 0 else "SM_Prop_Statue_05"
		_u(b, st, Vector3(x0 + aw / 2.0, YP + 0.3 * ah / 4.51, fzc - 0.12), 0.0, minf(0.82, (ah - 0.75) / 1.85))
	for sd: float in [-1.0, 1.0]:
		var a0 := -vx - 0.12 if sd < 0 else DW
		var a1 := -DW if sd < 0 else vx + 0.12
		_p(b, "SM_Bld_Wall_01", Vector3(a0, YP, fzc), 0.0, Vector3((a1 - a0) / 2.5, ah / 3.01, WT / 0.22), BRICK)
	_p(b, "SM_Bld_Wall_01", Vector3(-DW, YP + DH, fzc), 0.0, Vector3(2.0 * DW / 2.5, (ah - DH) / 3.01, WT / 0.22), MARBLE)
	_run(b, "SM_Bld_Wall_01", Vector3(-BW, YP + ah, fzc), Vector3(1, 0, 0), 2.0 * BW, 2.5, (HD - YP - ah) / 3.01, WT / 0.22, BRICK, 1.7)
	_run(b, "SM_Bld_Trim_Large_Single_02", Vector3(-BW + 0.05, HD - 0.3, BF - 0.02), Vector3(1, 0, 0), 2.0 * BW - 0.1, 2.5, 0.4, 0.3, FRIEZE, 1.7)
	_ring(b, "SM_Bld_Wall_Large_Cap_01", -BW - 0.03, BW + 0.03, bz0, BF + 0.03, HD - 0.06, 5.0, 0.75, 0.42, {}, [0, 1, 3], 1.7)
	_gate(b, 0.0, YP, BF, DW, DH)
	# ядро корпуса: над сенями, по бокам от них и за ними
	var top := HD - 0.02
	_core(b, Vector3(0, (YP + DH + 0.35 + top) / 2.0, (bz0 + BF - WT) / 2.0), Vector3(2.0 * BW - 0.1, top - YP - DH - 0.35, BF - WT - bz0))
	for sd: float in [-1.0, 1.0]:
		var xa := vx + WT
		var xb := BW - 0.05
		_box(b, Vector3(sd * (xa + xb) / 2.0, (YP + top) / 2.0, (bz0 + BF - WT - 0.45) / 2.0), Vector3(xb - xa, top - YP, BF - WT - 0.45 - bz0))
	_box(b, Vector3(0, (YP + DH + 0.35) / 2.0, (bz0 + BF - WT - vd) / 2.0), Vector3(2.0 * vx + 0.1, DH + 0.35, BF - WT - vd - bz0))
	# сени за вратами: тёплый мрамор и роспись, в глубине — золотая статуя всех богов в нише, по бокам курильницы
	var vz1 := BF - WT
	var vz0 := vz1 - vd
	_room(b, -vx, vx, vz0, vz1, YP, DH + 0.35, 0.0, DW, DH, {"Stucco_White_01": "Stucco_Red_01", "glow": WARM * 0.9}, {"Stucco_White_01": "Building_Marble_01", "glow": WARM * 0.8})
	_p(b, "SM_Prop_Plinth_04", Vector3(0, YP, vz0 + 0.35), 0.0, Vector3(0.7, 0.62, 0.62), _glow(0.6))
	_u(b, "SM_Prop_Statue_04", Vector3(0, YP + 0.68 * 0.62, vz0 + 0.32), 0.0, minf(0.9, (DH - 0.55) / 2.18), {"tints": {"Statue_01": GOLD}, "glow": WARM * 0.9})
	for sd: float in [-1.0, 1.0]:
		_u(b, "SM_Prop_Senser_01", Vector3(sd * (vx - 0.3), YP, vz0 + 0.45), 0.0, 0.5, _glow(0.5))
		_u(b, "SM_Prop_Mural_02", Vector3(sd * (vx - 0.03), YP + 1.35, (vz0 + vz1) / 2.0), -sd * PI / 2, minf(0.42, (vd - 0.2) / 2.53), _glow(0.55))
	# --- подиум портика (и под корпусом), лестница, пол
	_podium(b, PX, BF - 0.1, PF, YP, [1, 2, 3])
	_podium(b, BW + 0.08, bz0, BF - 0.1, YP, [1, 3])
	_floor(b, PORCH, -PX + 0.02, BF - 0.08, PX - 0.02, PF - 0.02, YP + 0.003, 1.45)
	_stairs(b, -PX + 0.25, PX - 0.25, SZ1, SZ1 - PF, d["HP"])
	for sd: float in [-1.0, 1.0]:
		var xc := sd * (PX - 0.125)
		_box(b, Vector3(xc, Y0 + (YP - Y0) / 2.0, (SZ1 + PF) / 2.0), Vector3(0.25, YP - Y0, SZ1 - PF))
		_p(b, "SM_Bld_Wall_Large_Pillar_Cap_01", Vector3(xc, YP - 0.04, (SZ1 + PF) / 2.0), 0.0, Vector3(0.34 / 1.28, 0.2, (SZ1 - PF + 0.04) / 1.24))
	# --- портик: восемь коринфских колонн (у старого места — шесть), второй ряд гладких, пилястры у корпуса
	_cols(b, "SM_Bld_Pillar_Large_04", cols, CF, YP, HC)
	var n: int = d["ncol"]
	var row2: Array = [cols[0], cols[2], cols[n - 3], cols[n - 1]] if full else [cols[0], cols[n - 1]]
	_cols(b, "SM_Bld_Pillar_Large_01", row2, CF - (0.85 if full else 0.7), YP, HC)
	for sd: float in [-1.0, 1.0]:
		_p(b, "SM_Bld_Pillar_Large_01", Vector3(sd * (BW - 0.18), YP, BF + 0.12), 0.0, Vector3(KC * 0.9, KC, KC * 0.6))
	var ex: float = cols[n - 1] + 0.39 * KC + 0.12
	var ez0 := BF - 0.15
	var ez1 := CF + 0.39 * KC + 0.1
	var ye := YP + HC
	var ent := 0.5
	_entab(b, ex, ez0, ez1, ye, ent, [0, 1, 3])
	var rh := ex + 0.15
	var etop := ye + ent
	var ridge := _roof_z(b, rh, ez0 - 0.1, ez1 + 0.12, etop)
	_relief(b, rh, etop, ridge, ez1 + 0.09, 0.0, full)
	_acro(b, rh, etop, ridge, ez1 + 0.12, 0.0, "SM_Prop_Statue_04", 0.24)
	# красная гирлянда в среднем пролёте, бронзовые курильницы у врат
	var cm := cols[n / 2] - cols[n / 2 - 1]
	_p(b, "SM_Prop_Drapery_03", Vector3(-cm / 2.0 + 0.19, ye - 0.03, CF + 0.05), 0.0, Vector3((cm - 0.38) / 2.5, 0.8, 0.8), SWAG_RED)
	for sd: float in [-1.0, 1.0]:
		_u(b, "SM_Prop_Senser_01", Vector3(sd * (DW + 0.5), YP, BF + 0.35), 0.0, 0.6)
		_p(b, "SM_Prop_Banner_03_C", Vector3(sd * (cols[n - 1] + cols[n - 2]) / 2.0, ye - 0.02, CF + 0.04), 0.0, Vector3(0.55, 0.62, 0.6))
	# --- двор: жаровни у лестницы, львы на постаментах, цветники вдоль портика, кипарисы и лавры у ротонды
	for sd: float in [-1.0, 1.0]:
		_altar(b, Vector3(sd * (PX + 0.38), Y0, SZ1 + 0.3), 0.55, 0.4, 2.2)
		var bx0 := PX + 0.14
		var bx1 := X - 0.1
		if bx1 - bx0 > 0.3:
			_bed(b, minf(bx0, bx1) if sd > 0 else -bx1, bx1 if sd > 0 else -bx0, BF + 0.1, SZ1 - 0.15)
		_cypress(b, Vector3(sd * (X - 0.45), Y0, Z0 + 0.45), 0.42 if full else 0.36)
		var side_room := X - R - 0.2
		if side_room > 0.55:
			# цветник вдоль ротонды, по его концам — кипарис и лавр
			var bx := R + 0.32
			_bed(b, minf(sd * bx, sd * (X - 0.1)), maxf(sd * bx, sd * (X - 0.1)), ZR - 1.45, ZR + 0.95)
			_cypress(b, Vector3(sd * (X - 0.45), Y0, ZR + 1.4), 0.38)
			_u(b, "SM_Env_Tree_Bush_0%d" % (1 + b.rng.randi() % 2), Vector3(sd * (X - 0.5), Y0, ZR - 1.95), b.rng.randf() * TAU, 0.34)
		_u(b, "SM_Env_Garden_Plants_0%d" % (3 + b.rng.randi() % 4), Vector3(sd * (X - 0.45), Y0, BF - 0.5), b.rng.randf() * TAU, 0.4, {"tint": Color(1, 1, 1)})
	# жрец у врат; ночью — огонёк у врат и у жаровен перед лестницей
	b.actor(Vector3(0.0, YP, BF + 0.6), 0.0, "Spell_Simple_Idle", "rich")
	b.light(Vector3(0, YP + 1.2, BF + 0.7))
	b.light(Vector3(0, Y0 + 1.0, SZ1 + 0.35))
	return Vector3(0, 0, Z1 + 0.35)


# =====================================================================
#   форум
# =====================================================================

static func _forum(b: Bp) -> Vector3:
	var X := 4.1
	var Z0 := -4.5
	var Z1 := 3.5
	_court(b, -X, X, Z0, Z1, WARM_PAVING, 1.4)
	_floor(b, MOSAIC, -1.6, -0.25, 1.6, 2.35, Y0 + 0.004, 1.6)
	# --- курия на подиуме: ионический портик, стены из тёплого травертина с пилястрами и медальонами, бронзовые врата,
	# фронтон с золотым рельефом
	var CP := 0.45
	var cy := Y0 + CP
	var cx := 3.0
	var cz0 := Z0 + 0.18
	var cz1 := -2.45
	_podium(b, cx, cz0, cz1, cy, [0, 1, 2, 3])
	_floor(b, PORCH, -cx + 0.02, cz0 + 0.02, cx - 0.02, cz1 - 0.02, cy + 0.003, 1.5)
	for sd: float in [-1.0, 1.0]:
		_stairs(b, 1.95 if sd > 0 else -2.95, 2.95 if sd > 0 else -1.95, cz1 + 0.6, 0.6, CP)
	var HC := 2.9
	var KC := HC / 6.0
	var colz := cz1 - 0.3
	var cols := [-2.55, -0.85, 0.85, 2.55]
	var wx := 2.7
	var wz0 := cz0 + 0.12
	var wz1 := -3.25
	var DW := 0.55
	var DH := 2.15
	_run(b, "SM_Bld_Wall_01", Vector3(wx - WT / 2.0, cy, wz1), Vector3(0, 0, -1), wz1 - wz0, 2.5, HC / 3.01, WT / 0.22, TRAV, 1.3)
	_run(b, "SM_Bld_Wall_01", Vector3(wx, cy, wz0 + WT / 2.0), Vector3(-1, 0, 0), 2.0 * wx, 2.5, HC / 3.01, WT / 0.22, TRAV, 1.8)
	_run(b, "SM_Bld_Wall_01", Vector3(-wx + WT / 2.0, cy, wz0), Vector3(0, 0, 1), wz1 - wz0, 2.5, HC / 3.01, WT / 0.22, TRAV, 1.3)
	_door_wall(b, -wx, wx, wz1 - WT / 2.0, cy, HC, 0.0, DW, DH, TRAV)
	for xx: float in [-2.6, -1.35, 1.35, 2.6]:
		_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(xx, cy, wz0 - 0.03), 0.0, Vector3(0.26 / 0.92, HC / 4.55, 0.16 / 0.92), MARBLE_PIER)
	for xx: float in [-1.98, 0.0, 1.98]:
		_u(b, "SM_Bld_Ornament_04", Vector3(xx, cy + HC * 0.62, wz0 - 0.03), PI, 0.42)
	for sd: float in [-1.0, 1.0]:
		_u(b, "SM_Bld_Ornament_04", Vector3(sd * (wx + 0.02), cy + HC * 0.62, (wz0 + wz1) / 2.0), sd * PI / 2, 0.38)
	_gate(b, 0.0, cy, wz1, DW, DH)
	for sd: float in [-1.0, 1.0]:
		_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(sd * (wx - 0.1), cy, wz1 + 0.04), 0.0, Vector3(0.3 / 0.92, HC / 4.55, 0.2 / 0.92), MARBLE_PIER)
		_u(b, "SM_Bld_Ornament_02", Vector3(sd * 1.65, cy + HC * 0.68, wz1 + 0.02), 0.0, 0.42)
	_ring(b, "SM_Bld_Trim_05", -wx + 0.03, wx - 0.03, wz0 + 0.03, wz1, cy, 2.5, 0.42, 0.45, MARBLE, [1, 2, 3], 1.3)
	_room(b, -wx + WT, wx - WT, wz0 + WT, wz1 - WT, cy, HC, 0.0, DW, DH, {"Stucco_White_01": "Stucco_Red_01", "glow": WARM * 0.9}, {"Stucco_White_01": "Stucco_Orange_01", "glow": WARM})
	var iz0 := wz0 + WT
	_u(b, "SM_Prop_Mural_01", Vector3(1.55, cy + 1.45, iz0 + 0.03), 0.0, 0.44, _glow(0.55))
	_u(b, "SM_Prop_Mural_01", Vector3(-1.55, cy + 1.45, iz0 + 0.03), 0.0, 0.44, _glow(0.55))
	_p(b, "SM_Prop_Plinth_04", Vector3(0, cy, iz0 + 0.35), 0.0, Vector3(0.6, 0.5, 0.5), _glow(0.6))
	_u(b, "SM_Prop_Statue_02", Vector3(0, cy + 0.34, iz0 + 0.4), 0.0, 0.72, {"tints": {"Statue_01": GOLD}, "glow": WARM * 0.9})
	_cols(b, "SM_Bld_Pillar_Large_03", cols, colz, cy, HC)
	var ex := 2.55 + 0.39 * KC + 0.12
	var ez0 := wz0 - 0.06
	var ez1 := colz + 0.39 * KC + 0.1
	var ye := cy + HC
	var ent := 0.45
	_entab(b, ex, ez0, ez1, ye, ent)
	var rh := ex + 0.15
	var etop := ye + ent
	var ridge := _roof_z(b, rh, ez0 - 0.1, ez1 + 0.12, etop)
	_relief(b, rh, etop, ridge, ez1 + 0.09, 0.0, true, "SM_Prop_Symbol_18")
	_acro(b, rh, etop, ridge, ez1 + 0.12, 0.0, "SM_Prop_Statue_06", 0.22)
	for i in [0, 2]:
		var x0: float = cols[i]
		var x1: float = cols[i + 1]
		_p(b, "SM_Prop_Drapery_03", Vector3(x0 + 0.19, ye - 0.03, colz + 0.05), 0.0, Vector3((x1 - x0 - 0.38) / 2.5, 0.8, 0.8), SWAG_RED)
	# --- ростра: помост из мраморных блоков, бронзовые медальоны, балюстрада с меандром, огни по углам
	var rx := 1.9
	var rz0 := cz1
	var rz1 := -1.05
	var rhh := 0.95
	var rtop := Y0 + rhh
	_box(b, Vector3(0, Y0 + rhh / 2.0, (rz0 + rz1) / 2.0), Vector3(2.0 * rx, rhh, rz1 - rz0))   # единственное широкое ядро посредине — ростра
	_run(b, "SM_Bld_Wall_Large_01", Vector3(-rx, Y0 - 0.3, rz1), Vector3(1, 0, 0), 2.0 * rx, 5.0, (rhh + 0.27) / 4.51, 0.3, MARBLE_BLOCKS, 1.9)
	_run(b, "SM_Bld_Wall_Large_01", Vector3(rx, Y0 - 0.3, rz1), Vector3(0, 0, -1), rz1 - rz0, 5.0, (rhh + 0.27) / 4.51, 0.3, MARBLE_BLOCKS, 1.4)
	_run(b, "SM_Bld_Wall_Large_01", Vector3(-rx, Y0 - 0.3, rz0), Vector3(0, 0, 1), rz1 - rz0, 5.0, (rhh + 0.27) / 4.51, 0.3, MARBLE_BLOCKS, 1.4)
	_ring(b, "SM_Bld_Wall_Large_Cap_01", -rx - 0.03, rx + 0.03, rz0, rz1 + 0.03, rtop - 0.05, 5.0, 0.3, 0.3, {}, [0, 1, 3], 1.4)
	_floor(b, PORCH, -rx + 0.02, rz0, rx - 0.02, rz1 - 0.02, rtop + 0.003, 1.3)
	for x: float in [-1.25, 0.0, 1.25]:
		_u(b, "SM_Bld_Ornament_02", Vector3(x, Y0 + rhh * 0.5, rz1 + 0.12), 0.0, 0.5)
	for sd: float in [-1.0, 1.0]:
		_u(b, "SM_Prop_Marble_LionHead_01", Vector3(sd * 0.62, Y0 + rhh * 0.52, rz1 + 0.12), 0.0, 0.42)
		_run(b, "SM_Bld_Wall_Balcony_06", Vector3(sd * 0.55 if sd > 0 else -rx + 0.12, rtop, rz1 - 0.14), Vector3(1, 0, 0), rx - 0.12 - 0.55, 2.5, 0.52, 0.5, {}, 1.4)
		_altar(b, Vector3(sd * (rx - 0.28), rtop, rz1 - 0.38), 0.36, 0.28, 1.7)
		_p(b, "SM_Prop_Banner_03_C" if sd < 0 else "SM_Prop_Banner_03_B", Vector3(sd * 0.95, rtop - 0.06, rz1 + 0.16), 0.0, Vector3(0.42, 0.34, 0.5))
	# --- портики с лавками по бокам площади: колонны, черепичный навес к стене, двери лавок, товар
	var pz0 := -2.3
	var pz1 := 2.45
	var PH := 2.55
	var PW := 3.95                      # середина задней стены
	var PC := 2.95                      # колонны
	var ry := Y0 + PH + 0.29            # свес кровли галереи
	var wall_h := PH + 0.27
	var doors := [-1.3, 0.95]
	var fw := [1.4, 2.4]                # окно у входа (за ним — светлая галерея)
	for sd: float in [-1.0, 1.0]:
		var wxs := sd * PW
		# задняя стена (снаружи — бок форума): стена, двери двух лавок, наружные пилястры и карниз
		var zs := [pz0]
		for dz: float in doors:
			zs.append(dz - 0.38)
			zs.append(dz + 0.38)
		zs.append(fw[0])
		zs.append(fw[1])
		zs.append(pz1)
		_p(b, "SM_Bld_Wall_Window_05", Vector3(wxs, Y0, fw[1] if sd > 0 else fw[0]), PI / 2 if sd > 0 else -PI / 2, Vector3((fw[1] - fw[0]) / 2.5, wall_h / 3.01, 0.5), CREAM)
		for i in range(0, zs.size(), 2):
			var za: float = zs[i]
			var zb: float = zs[i + 1]
			if sd > 0:
				_run(b, "SM_Bld_Wall_01", Vector3(wxs, Y0, za), Vector3(0, 0, 1), zb - za, 2.5, wall_h / 3.01, WT / 0.22, CREAM, 1.25)
			else:
				_run(b, "SM_Bld_Wall_01", Vector3(wxs, Y0, zb), Vector3(0, 0, -1), zb - za, 2.5, wall_h / 3.01, WT / 0.22, CREAM, 1.25)
		for dz: float in doors:
			var dh := 1.5
			var yaw := -PI / 2 if sd > 0 else PI / 2
			_p(b, "SM_Bld_Wall_01", Vector3(wxs, Y0 + dh, dz - 0.38 * sd), yaw, Vector3(0.76 / 2.5, (wall_h - dh) / 3.01, WT / 0.22), CREAM)
			_p(b, "SM_Bld_Door_0%d" % (1 + posmod(int(dz * 10.0) + int(sd > 0), 2) * 4), Vector3(wxs, Y0, dz - 0.36 * sd), yaw, Vector3(0.72 / 1.0, dh / 1.97, 0.6))
			_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(wxs - sd * 0.1, Y0, dz - 0.44 * sd), yaw, Vector3(0.09 / 0.92, (dh + 0.1) / 4.55, 0.12 / 0.92), MARBLE_PIER)
			_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(wxs - sd * 0.1, Y0, dz + 0.44 * sd), yaw, Vector3(0.09 / 0.92, (dh + 0.1) / 4.55, 0.12 / 0.92), MARBLE_PIER)
			_p(b, "SM_Bld_Wall_Large_Cap_01", Vector3(wxs - sd * 0.1, Y0 + dh, dz - 0.52 * sd), yaw, Vector3(1.04 / 5.02, 0.4, 0.16))
		_bands(b, Vector3(sd * (PW + WT / 2.0), 0, pz1 if sd > 0 else pz0), Vector3(0, 0, -sd), pz1 - pz0, Y0 + wall_h - 0.2, Y0)
		for zz: float in [-2.05, -0.17, 1.3]:
			_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(sd * (PW + WT / 2.0 + 0.03), Y0, zz), PI / 2, Vector3(0.22 / 0.92, (wall_h - 0.45) / 4.55, 0.08 / 0.92), MARBLE_PIER)
		for dz: float in doors:
			_u(b, "SM_Bld_Ornament_04", Vector3(sd * (PW + WT / 2.0 + 0.02), Y0 + 2.05, dz), sd * PI / 2, 0.36)
		# колонны и балка
		for i in 5:
			var z := lerpf(pz0 + 0.15, pz1 - 0.15, i / 4.0)
			_p(b, "SM_Bld_Pillar_01", Vector3(sd * PC, Y0, z), 0.0, Vector3.ONE * (PH / 3.0))
		if sd < 0:
			_run(b, "SM_Bld_Trim_Large_Single_01", Vector3(-PC + 0.02, Y0 + PH + 0.145, pz1), Vector3(0, 0, -1), pz1 - pz0, 2.5, 0.3, 0.3, {}, 1.6)
		else:
			_run(b, "SM_Bld_Trim_Large_Single_01", Vector3(PC - 0.02, Y0 + PH + 0.145, pz0), Vector3(0, 0, 1), pz1 - pz0, 2.5, 0.3, 0.3, {}, 1.6)
		# кровля галереи: два ската вдоль площади, свес над колоннами и над наружной стеной, щипцы с торцов
		_gallery_roof(b, sd * PC, sd * (X - 0.02), pz0 - 0.05, pz1 + 0.05, ry, CREAM_TYM)
		# пол портика — узорные плиты; лавка: прилавок с товаром, у колонн — знамёна
		_floor(b, PORCH, minf(sd * (PC - 0.3), sd * (PW - WT / 2.0)), pz0, maxf(sd * (PC - 0.3), sd * (PW - WT / 2.0)), pz1, Y0 + 0.003, 1.6)
		var gx := sd * (PW - 0.45)
		if sd < 0:
			_u(b, "SM_Prop_Vase_Pile_0%d" % (1 + b.rng.randi() % 3), Vector3(gx, Y0, -0.2), PI / 2, 0.42)
			_u(b, "SM_Prop_Table_08", Vector3(gx + 0.05, Y0, 1.9), PI / 2, 0.42)
			_u(b, "SM_Prop_Jug_01", Vector3(gx + 0.05, Y0 + 0.33, 1.75), 0.3, 0.5)
			_u(b, "SM_Prop_Bowl_03", Vector3(gx + 0.05, Y0 + 0.33, 2.15), 0.0, 0.4)
			_u(b, "SM_Prop_Basket_Set_01", Vector3(gx, Y0, -2.0), 0.4, 0.4)
		else:
			_u(b, "SM_Prop_Table_08", Vector3(gx - 0.05, Y0, -0.2), -PI / 2, 0.42)
			_u(b, "SM_Prop_Scroll_Pile_05", Vector3(gx - 0.05, Y0 + 0.33, -0.3), 0.2, 0.42)
			_u(b, "SM_Prop_Scroll_Pile_02", Vector3(gx - 0.05, Y0 + 0.33, 0.05), 1.3, 0.5)
			_u(b, "SM_Prop_Jar_Pile_01", Vector3(gx, Y0, 1.95), 0.0, 0.42)
			_u(b, "SM_Prop_Sack_Stack_01", Vector3(gx, Y0, -2.0), PI / 2, 0.42)
		var bz := lerpf(pz0 + 0.15, pz1 - 0.15, 0.625)
		_p(b, "SM_Prop_Banner_03_%s" % ("D" if sd < 0 else "A"), Vector3(sd * (PC - 0.12), Y0 + PH + 0.05, bz), -sd * PI / 2, Vector3(0.42, 0.5, 0.5))
	# --- вход: постаменты со статуями (Август-оратор позолочен, центурион бронзовый), курильницы
	for sd: float in [-1.0, 1.0]:
		var p := Vector3(sd * 3.45, Y0, 2.92)
		_u(b, "SM_Prop_Plinth_05", p, 0.0 if sd < 0 else PI, 0.4)
		_u(b, "SM_Prop_Statue_06" if sd < 0 else "SM_Prop_Statue_07", p + Vector3(0, 2.59 * 0.4, 0), 0.0, 0.6, GOLD_STATUE if sd < 0 else BRONZE_STATUE)
		_u(b, "SM_Prop_Senser_01", Vector3(sd * 2.45, Y0, 3.15), 0.0, 0.6)
		_u(b, "SM_Env_Garden_Plants_0%d" % (3 + b.rng.randi() % 3), Vector3(sd * 2.45, Y0, -1.75), b.rng.randf() * TAU, 0.4, {"tint": Color(1, 1, 1)})
	# магистрат на портике курии; стражник у входа
	b.actor(Vector3(-1.7, cy, colz - 0.2), 0.3, "Idle", "rich")
	b.actor(Vector3(2.4, Y0, 2.6), 0.0, "Sword_Idle", "soldier")
	b.light(Vector3(0, cy + 1.3, wz1 + 0.6))
	b.light(Vector3(0, Y0 + 1.1, 2.9))
	return Vector3(0, 0, Z1 + 0.35)


# =====================================================================
#   храм Венеры и Ромы
# =====================================================================

static func _venus(b: Bp) -> Vector3:
	var X := 3.72
	var Z0 := -4.48
	var Z1 := 4.64
	_court(b, -X, X, Z0, Z1, PAVING)
	# --- основание в три ступени со всех сторон, спереди — лестница во всю ширину
	var YS := Y0 + 0.45
	var sx := 2.75
	var sz0 := -3.75
	var sz1 := 3.05
	for i in 3:
		var o := 0.22 * (2 - i)
		var t := YS - 0.15 * (2 - i)
		_box(b, Vector3(0, (Y0 - 0.12 + t) / 2.0, (sz0 - o + sz1 + o) / 2.0), Vector3(2.0 * (sx + o), t - Y0 + 0.12, sz1 - sz0 + 2.0 * o))
	_ring(b, "SM_Bld_Trim_05", -sx - 0.44, sx + 0.44, sz0 - 0.44, sz1 + 0.44, Y0 - 0.02, 2.5, 0.2, 0.4, MARBLE, [1, 2, 3], 1.6)
	_floor(b, PORCH, -sx, sz0, sx, sz1, YS + 0.003, 1.45)
	_stairs(b, -2.3, 2.3, sz1 + 0.95, 0.95, YS - Y0)
	# --- колоннада: спереди шесть коринфских, по бокам и сзади — гладкие (легче; те же, что полуколонны храма Юпитера)
	var HC := 3.1
	var KC := HC / 6.0
	var CF := sz1 - 0.3
	var CB := sz0 + 0.3
	var cx := 2.45
	var xs := []
	for i in 6:
		xs.append(-cx + i * 2.0 * cx / 5.0)
	_cols(b, "SM_Bld_Pillar_Large_04", xs, CF, YS, HC)
	_cols(b, "SM_Bld_Pillar_Large_01", xs, CB, YS, HC)
	for kz in range(1, 6):
		var z := lerpf(CF, CB, kz / 6.0)
		_cols(b, "SM_Bld_Pillar_Large_01", [-cx, cx], z, YS, HC)
	# --- целла: розовые стены с мраморным цоколем и пилястрами, бронзовые врата Венеры спереди и Ромы сзади
	var wx := 1.75
	var wz0 := CB + 0.75
	var wz1 := CF - 1.15
	var DW := 0.5
	var DH := 2.25
	var sz := WT / 0.22
	_run(b, "SM_Bld_Wall_01", Vector3(wx - WT / 2.0, YS, wz1), Vector3(0, 0, -1), wz1 - wz0, 2.5, HC / 3.01, sz, ROSE, 1.5)
	_run(b, "SM_Bld_Wall_01", Vector3(-wx + WT / 2.0, YS, wz0), Vector3(0, 0, 1), wz1 - wz0, 2.5, HC / 3.01, sz, ROSE, 1.5)
	_door_wall(b, -wx, wx, wz1 - WT / 2.0, YS, HC, 0.0, DW, DH, ROSE)
	_gate(b, 0.0, YS, wz1, DW, DH)
	# задняя стена с закрытыми вратами Ромы (лицом назад)
	var keep := b.base
	b.base = keep * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, 2.0 * wz0))
	_door_wall(b, -wx, wx, wz0 - WT / 2.0, YS, HC, 0.0, DW, DH, ROSE)
	_gate(b, 0.0, YS, wz0, DW, DH)
	b.base = keep
	for c: Array in [[-1.0, 1.0], [1.0, 1.0], [-1.0, -1.0], [1.0, -1.0]]:
		var zc := wz1 + 0.04 if float(c[1]) > 0 else wz0 - 0.04
		_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(float(c[0]) * (wx - 0.1), YS, zc), 0.0, Vector3(0.28 / 0.92, HC / 4.55, 0.2 / 0.92), MARBLE_PIER)
	_ring(b, "SM_Bld_Trim_05", -wx + 0.03, wx - 0.03, wz0 - 0.03, wz1 + 0.03, YS, 2.5, 0.42, 0.45, MARBLE, [0, 1, 2, 3], 1.4)
	for sd: float in [-1.0, 1.0]:
		for zz: float in [lerpf(wz0, wz1, 0.25), lerpf(wz0, wz1, 0.75)]:
			_u(b, "SM_Bld_Ornament_02", Vector3(sd * (wx + 0.01), YS + HC * 0.66, zz), sd * PI / 2, 0.42)
	# зал Венеры: розовые стены с росписью, мозаика, золотая Венера на постаменте, курильницы, цветы; за перегородкой — Рома
	var iz1 := wz1 - WT
	var iz0 := iz1 - 2.15
	var ix := wx - WT
	_room(b, -ix, ix, iz0, iz1, YS, HC, 0.0, DW, DH, {"Stucco_White_01": "Stucco_Red_01", "glow": WARM * 0.9}, {"Stucco_White_01": "Stucco_Orange_01", "glow": WARM})
	_box(b, Vector3(0, YS + HC / 2.0, (wz0 + WT + iz0) / 2.0 - 0.01), Vector3(2.0 * ix, HC, iz0 - wz0 - WT - 0.02))
	_u(b, "SM_Prop_Mural_02", Vector3(0, YS + 1.95, iz0 + 0.03), 0.0, 0.5, _glow(0.55))
	for sd: float in [-1.0, 1.0]:
		_u(b, "SM_Prop_Mural_02", Vector3(sd * (ix - 0.03), YS + 1.35, (iz0 + iz1) / 2.0), -sd * PI / 2, 0.55, _glow(0.55))
		_u(b, "SM_Prop_Senser_01", Vector3(sd * 0.75, YS, iz0 + 0.5), 0.0, 0.5, _glow(0.5))
		_u(b, "SM_Prop_Vase_0%d" % (1 + b.rng.randi() % 3), Vector3(sd * (ix - 0.3), YS, iz1 - 0.35), 0.0, 0.5, _glow(0.5))
	_p(b, "SM_Prop_Plinth_04", Vector3(0, YS, iz0 + 0.42), 0.0, Vector3(0.7, 0.6, 0.6), _glow(0.6))
	_u(b, "SM_Prop_Statue_03", Vector3(0, YS + 0.68 * 0.6, iz0 + 0.42), 0.0, 0.9, {"tints": {"Statue_01": GOLD}, "glow": WARM * 0.9})
	# --- антаблемент, золочёная кровля, синие фронтоны с золотым рельефом спереди и сзади, акротерии
	var ex := cx + 0.39 * KC + 0.12
	var ez0 := CB - 0.39 * KC - 0.1
	var ez1 := CF + 0.39 * KC + 0.1
	var ye := YS + HC
	var ent := 0.6
	_entab(b, ex, ez0, ez1, ye, ent)
	var rh := ex + 0.15
	var etop := ye + ent
	var ridge := _roof_z(b, rh, ez0 - 0.1, ez1 + 0.12, etop, GOLD_ROOF)
	_relief(b, rh, etop, ridge, ez1 + 0.09, 0.0, true)
	_relief(b, rh, etop, ridge, ez0 - 0.09, PI, true)
	_acro(b, rh, etop, ridge, ez1 + 0.12, 0.0, "SM_Prop_Statue_04", 0.24)
	_acro(b, rh, etop, ridge, ez0 - 0.12, PI, "SM_Prop_Statue_04", 0.24)
	for i in [1, 2, 3]:
		var x0: float = xs[i]
		var x1: float = xs[i + 1]
		_p(b, "SM_Prop_Drapery_03", Vector3(x0 + 0.19, ye - 0.03, CF + 0.05), 0.0, Vector3((x1 - x0 - 0.38) / 2.5, 0.8, 0.8))
	# --- двор: алтарь перед лестницей, статуи Венеры и Ромы, розы вдоль ступеней, кипарисы и мирты сзади
	_altar(b, Vector3(0, Y0, 4.3), 0.55, 0.42, 2.4)
	for sd: float in [-1.0, 1.0]:
		var p := Vector3(sd * 3.33, Y0, 4.05)
		_p(b, "SM_Prop_Pillar_Base_02", p, 0.0, Vector3(0.44, 0.42, 0.44))
		if sd < 0:
			_u(b, "SM_Prop_Statue_03", p + Vector3(0, 1.5 * 0.42, 0), 0.25, 0.62)
		else:
			_u(b, "SM_Prop_Statue_01", p + Vector3(0, 1.5 * 0.42, 0), -0.25, 0.52, BRONZE_STATUE)
		_bed(b, minf(sd * 3.27, sd * (X - 0.09)), maxf(sd * 3.27, sd * (X - 0.09)), -3.85, 3.55)
		_cypress(b, Vector3(sd * 3.3, Y0, Z0 + 0.4), 0.4)
		_u(b, "SM_Env_Tree_Bush_0%d" % (1 + b.rng.randi() % 2), Vector3(sd * 1.6, Y0, Z0 + 0.38), b.rng.randf() * TAU, 0.3)
	# жрица с курильницей в пронаосе, служитель у алтаря
	b.actor(Vector3(0, YS, CF - 0.55), 0.0, "Spell_Simple_Idle", "rich")
	b.actor(Vector3(0.55, Y0, 4.3), -PI / 2, "Interact", "pleb")
	b.light(Vector3(0, YS + 1.1, wz1 + 0.5))
	b.light(Vector3(0, Y0 + 1.0, 4.3))
	return Vector3(0, 0, Z1 + 0.3)


# =====================================================================
#   академия
# =====================================================================

static func _academy(b: Bp) -> Vector3:
	var X := 4.85
	var Z0 := -5.55
	var Z1 := 4.35
	_court(b, -X, X, Z0, Z1, PAVING)
	# --- зал философов на низком подиуме
	var YP := Y0 + 0.3
	var hx := 4.3                     # стены зала снаружи: x ±hx, z hz0..hz1
	var hz0 := -5.25
	var hz1 := -2.3
	var HW := 3.5
	var sz := WT / 0.22
	_podium(b, hx + 0.12, hz0 - 0.12, hz1, YP, [1, 2, 3])
	var DW := 0.55
	var DH := 2.3
	# фасад зала: стена, два окна (за ними — светлый зал), бронзовые врата посредине
	var fz := hz1 - WT / 2.0
	var segs := [[-hx, -3.0, "w"], [-3.0, -1.6, "o"], [-1.6, -DW, "w"], [DW, 1.6, "w"], [1.6, 3.0, "o"], [3.0, hx, "w"]]
	for s: Array in segs:
		var a0: float = s[0]
		var a1: float = s[1]
		if String(s[2]) == "o":
			_p(b, "SM_Bld_Wall_Window_05", Vector3(a0, YP, fz), 0.0, Vector3((a1 - a0) / 2.5, HW / 3.01, sz), CREAM)
		else:
			_run(b, "SM_Bld_Wall_01", Vector3(a0, YP, fz), Vector3(1, 0, 0), a1 - a0, 2.5, HW / 3.01, sz, CREAM, 1.3)
	_p(b, "SM_Bld_Wall_01", Vector3(-DW, YP + DH, fz), 0.0, Vector3(2.0 * DW / 2.5, (HW - DH) / 3.01, sz), CREAM)
	_gate(b, 0.0, YP, hz1, DW, DH)
	# бока: окно посередине; зад — глухой
	for sd: float in [-1.0, 1.0]:
		var xw := sd * (hx - WT / 2.0)
		var za := hz1 if sd > 0 else hz0
		var dir := Vector3(0, 0, -sd)
		var len := hz1 - hz0
		var w0 := 0.85
		_run(b, "SM_Bld_Wall_01", Vector3(xw, YP, za), dir, w0, 2.5, HW / 3.01, sz, CREAM, 1.3)
		_p(b, "SM_Bld_Wall_Window_05", Vector3(xw, YP, za + dir.z * w0), atan2(-dir.z, dir.x), Vector3(1.3 / 2.5, HW / 3.01, sz), CREAM)
		_run(b, "SM_Bld_Wall_01", Vector3(xw, YP, za + dir.z * (w0 + 1.3)), dir, len - w0 - 1.3, 2.5, HW / 3.01, sz, CREAM, 1.3)
	# задний фасад: два окна (за ними — светлый зал), фриз под карнизом, медальоны
	var bz := hz0 + WT / 2.0
	for sg: Array in [[-hx, -3.85, "w"], [-3.85, -2.55, "o"], [-2.55, 2.55, "w"], [2.55, 3.85, "o"], [3.85, hx, "w"]]:
		var a0: float = sg[0]
		var a1: float = sg[1]
		if String(sg[2]) == "o":
			_p(b, "SM_Bld_Wall_Window_05", Vector3(a1, YP, bz), PI, Vector3((a1 - a0) / 2.5, HW / 3.01, sz), CREAM)
		else:
			_run(b, "SM_Bld_Wall_01", Vector3(a1, YP, bz), Vector3(-1, 0, 0), a1 - a0, 2.5, HW / 3.01, sz, CREAM, 1.8)
	_run(b, "SM_Bld_Trim_Large_Single_02", Vector3(hx - 0.05, YP + HW - 0.42, hz0 - 0.01), Vector3(-1, 0, 0), 2.0 * hx - 0.1, 2.5, 0.3, 0.3, FRIEZE, 1.7)
	for xx: float in [-1.1, 1.1]:
		_u(b, "SM_Bld_Ornament_04", Vector3(xx, YP + 2.25, hz0 - 0.03), PI, 0.42)
	for c: Array in [[-1.0, hz1 + 0.03], [1.0, hz1 + 0.03], [-1.0, hz0 - 0.03], [1.0, hz0 - 0.03]]:
		_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(float(c[0]) * (hx - 0.12), YP, float(c[1])), 0.0, Vector3(0.3 / 0.92, HW / 4.55, 0.3 / 0.92), MARBLE_PIER)
	for xx: float in [-2.2, 0.0, 2.2]:
		_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(xx, YP, hz0 - 0.03), 0.0, Vector3(0.24 / 0.92, HW / 4.55, 0.16 / 0.92), MARBLE_PIER)
	_ring(b, "SM_Bld_Trim_05", -hx + 0.03, hx - 0.03, hz0 - 0.03, hz1 + 0.03, YP, 2.5, 0.42, 0.45, MARBLE, [0, 1, 2, 3], 1.4)
	var ht := YP + HW
	_ring(b, "SM_Bld_Wall_Large_Cap_01", -hx - 0.03, hx + 0.03, hz0 - 0.03, hz1 + 0.03, ht - 0.05, 5.0, 0.7, 0.42, {}, [0, 1, 2, 3], 1.6)
	# кровля зала: конёк вдоль фасада, щипцы по бокам
	var keep := b.base
	b.base = keep * Transform3D(Basis(Vector3.UP, PI / 2), Vector3(0, 0, (hz0 + hz1) / 2.0))
	var rh := (hz1 - hz0) / 2.0 + 0.22
	_roof_z(b, rh, -hx - 0.2, hx + 0.2, ht + 0.2, {}, CREAM_TYM, [true, true], 1.45)
	b.base = keep
	_box(b, Vector3(0, ht + 0.1, (hz0 + hz1) / 2.0), Vector3(2.0 * hx, 0.2, hz1 - hz0))
	# нутро зала: полки со свитками у задней стены, стол со свитками, бюст философа — всё в тёплом свете
	var ix := hx - WT
	var iz0 := hz0 + WT
	var iz1 := hz1 - WT
	_room(b, -ix, ix, iz0, iz1, YP, HW, 0.0, DW, DH, {"Stucco_White_01": "Stucco_Red_01", "glow": WARM * 1.1}, {"Stucco_White_01": "Stucco_Orange_01", "glow": WARM * 1.2})
	for xx: float in [-1.95, 0.45]:
		_p(b, "SM_Bld_Shelf_Scroll_01", Vector3(xx - 0.6, YP, iz0 + 0.02), 0.0, Vector3(0.78, 0.8, 0.6), _glow(0.55))
		_p(b, "SM_Bld_Shelf_Scroll_01_Insert_0%d" % (1 + int(xx > 0)), Vector3(xx - 0.6, YP, iz0 + 0.02), 0.0, Vector3(0.78, 0.8, 0.6), _glow(0.55))
	_u(b, "SM_Prop_Table_01", Vector3(0, YP, (iz0 + iz1) / 2.0 + 0.1), 0.0, 0.62, _glow(0.5))
	_u(b, "SM_Prop_Scroll_Pile_01", Vector3(-0.2, YP + 0.48, (iz0 + iz1) / 2.0 + 0.1), 0.4, 0.55, _glow(0.5))
	for sd: float in [-1.0, 1.0]:
		_p(b, "SM_Prop_Plinth_04", Vector3(sd * 1.6, YP, (iz0 + iz1) / 2.0), 0.0, Vector3(0.5, 0.75, 0.5), _glow(0.55))
		_u(b, "SM_Prop_Statue_05", Vector3(sd * 1.6, YP + 0.51, (iz0 + iz1) / 2.0), 0.0, 0.62, _glow(0.75))
	# --- портик: четыре ионические колонны, фронтон с золотым рельефом, статуя Афины на коньке
	var PZ := -0.8                    # передний край пола портика
	var colz := PZ - 0.25
	var cols := [-2.6, -0.87, 0.87, 2.6]
	var HC := HW - 0.05 + 0.0
	var KC := HC / 6.0
	_podium(b, 2.95, hz1 - 0.05, PZ, YP, [1, 3])
	_floor(b, PORCH, -2.93, hz1, 2.93, PZ - 0.02, YP + 0.003, 1.5)
	_stairs(b, -2.6, 2.6, PZ + 0.5, 0.5, YP - Y0)
	_cols(b, "SM_Bld_Pillar_Large_03", cols, colz, YP, HC)
	var ex := 2.6 + 0.39 * KC + 0.12
	var ez0 := hz1 - 0.15
	var ez1 := colz + 0.39 * KC + 0.1
	var ye := YP + HC
	var ent := 0.5
	_entab(b, ex, ez0, ez1, ye, ent, [0, 1, 3])
	var prh := ex + 0.15
	var etop := ye + ent
	var pr := _roof_z(b, prh, ez0 - 0.1, ez1 + 0.12, etop)
	_relief(b, prh, etop, pr, ez1 + 0.09, 0.0, true, "SM_Prop_Symbol_21")
	_acro(b, prh, etop, pr, ez1 + 0.12, 0.0, "SM_Prop_Statue_04", 0.22)
	for i in [0, 1, 2]:
		var x0: float = cols[i]
		var x1: float = cols[i + 1]
		if i != 1:
			_p(b, "SM_Prop_Drapery_03", Vector3(x0 + 0.19, ye - 0.03, colz + 0.05), 0.0, Vector3((x1 - x0 - 0.38) / 2.5, 0.8, 0.8))
	# --- крытые колоннады сада (стоа): роспись на стене, скамьи, статуи; черепичный навес к наружной стене
	var sz0 := hz1
	var sz1 := 3.55
	var SW := X - 0.2                 # середина наружной стены
	var SC := 3.55                    # колонны
	var PH := 2.55
	var ry := Y0 + PH + 0.29
	var wall_h := PH + 0.27
	for sd: float in [-1.0, 1.0]:
		var wxs := sd * SW
		# наружная стена стоа: два окна с фронтончиком (за ними — светлая галерея), между ними — стена с медальонами
		for sg: Array in [[sz0, -2.25, "w"], [-2.25, -0.95, "o"], [-0.95, 2.25, "w"], [2.25, sz1, "o"]]:
			var za: float = sg[0]
			var zb: float = sg[1]
			if String(sg[2]) == "o":
				_p(b, "SM_Bld_Wall_Window_05", Vector3(wxs, Y0, zb if sd > 0 else za), PI / 2 if sd > 0 else -PI / 2, Vector3((zb - za) / 2.5, wall_h / 3.01, 0.5), CREAM)
			elif sd > 0:
				_run(b, "SM_Bld_Wall_01", Vector3(wxs, Y0, za), Vector3(0, 0, 1), zb - za, 2.5, wall_h / 3.01, sz, CREAM, 1.6)
			else:
				_run(b, "SM_Bld_Wall_01", Vector3(wxs, Y0, zb), Vector3(0, 0, -1), zb - za, 2.5, wall_h / 3.01, sz, CREAM, 1.6)
		var wo := sd * (SW + WT / 2.0)
		_bands(b, Vector3(wo, 0, sz1 if sd > 0 else sz0), Vector3(0, 0, -sd), sz1 - sz0, Y0 + wall_h - 0.2, Y0)
		for zz: float in [-0.85, 0.65, 2.15]:
			_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(sd * (SW + WT / 2.0 + 0.03), Y0, zz), PI / 2, Vector3(0.22 / 0.92, (wall_h - 0.45) / 4.55, 0.08 / 0.92), MARBLE_PIER)
		for zz: float in [-0.1, 1.4]:
			_u(b, "SM_Bld_Ornament_04", Vector3(sd * (SW + WT / 2.0 + 0.02), Y0 + 1.95, zz), sd * PI / 2, 0.42)
		# роспись стоа (как «Пёстрая стоя»)
		for zz: float in [-0.35, 1.45]:
			_u(b, "SM_Prop_Mural_02", Vector3(sd * (SW - WT / 2.0 - 0.02), Y0 + 1.4, zz), -sd * PI / 2, 0.5)
		for i in 5:
			var z := lerpf(sz0 + 0.45, sz1 - 0.15, i / 4.0)
			_p(b, "SM_Bld_Pillar_01", Vector3(sd * SC, Y0, z), 0.0, Vector3.ONE * (PH / 3.0))
		if sd < 0:
			_run(b, "SM_Bld_Trim_Large_Single_01", Vector3(-SC + 0.02, Y0 + PH + 0.145, sz1), Vector3(0, 0, -1), sz1 - sz0, 2.5, 0.3, 0.3, {}, 1.6)
		else:
			_run(b, "SM_Bld_Trim_Large_Single_01", Vector3(SC - 0.02, Y0 + PH + 0.145, sz0), Vector3(0, 0, 1), sz1 - sz0, 2.5, 0.3, 0.3, {}, 1.6)
		_gallery_roof(b, sd * SC, sd * (X - 0.02), sz0, sz1 + WT + 0.05, ry, CREAM_TYM)
		_floor(b, PORCH, minf(sd * (SC - 0.3), sd * (SW - WT / 2.0)), sz0, maxf(sd * (SC - 0.3), sd * (SW - WT / 2.0)), sz1, Y0 + 0.003, 1.6)
		# скамьи у стены (на них присаживаются жители), между ними — бюсты на постаментах
		for zz: float in [-0.35, 1.45]:
			_u(b, "SM_Prop_Seat_Bench_01", Vector3(sd * (SW - 0.4), Y0, zz), -sd * PI / 2, 0.72)
		_p(b, "SM_Prop_Plinth_04", Vector3(sd * (SW - 0.35), Y0, 0.55), 0.0, Vector3(0.5, 0.9, 0.5))
		_u(b, "SM_Prop_Statue_05" if sd < 0 else "SM_Prop_Statue_04", Vector3(sd * (SW - 0.35), Y0 + 0.61, 0.55), -sd * PI / 2, 0.5)
		_u(b, "SM_Prop_Scroll_Pile_06", Vector3(sd * (SW - 0.4), Y0, 2.9), 0.3, 0.45)
	# --- сад: дорожка от ворот к залу и поперечная, четыре цветника с оливами, солнечные часы, скамьи учеников
	_floor(b, PORCH, -0.65, -0.3, 0.65, 3.6, Y0 + 0.005, 1.3)
	_floor(b, PORCH, -3.2, 1.0, 3.2, 2.3, Y0 + 0.006, 1.3)
	for sx: float in [-1.0, 1.0]:
		var x0 := 0.85 if sx > 0 else -3.25
		var x1 := 3.25 if sx > 0 else -0.85
		_bed(b, x0, x1, -0.15, 0.85, 0, "SM_Env_Tree_Bush_01")
		_bed(b, x0, x1, 2.45, 3.45, 0, "SM_Env_Tree_Bush_02" if sx < 0 else "")
	_p(b, "SM_Prop_Plinth_03", Vector3(0, Y0, 1.65), 0.0, Vector3(1.3, 1.2, 1.3))
	_u(b, "SM_Prop_Sundial_01", Vector3(0, Y0 + 0.17, 1.65), 0.4, 0.5)
	for sx: float in [-1.0, 1.0]:
		_u(b, "SM_Prop_Seat_Bench_01", Vector3(sx * 1.7, Y0, 1.65), -sx * PI / 2 if sx > 0 else PI / 2, 0.72)
	# --- фасад: угловые столбы, парапет с меандром, ворота-пропилей с фронтончиком, фонари
	for sd: float in [-1.0, 1.0]:
		var xa := sd * 3.35
		var xb := sd * (X - 0.07)
		_run(b, "SM_Bld_Wall_01", Vector3(minf(xa, xb), Y0, sz1 + WT / 2.0), Vector3(1, 0, 0), absf(xb - xa), 2.5, wall_h / 3.01, sz, CREAM, 1.5)
		_u(b, "SM_Prop_Banner_03_%s" % ("C" if sd < 0 else "B"), Vector3(sd * 4.0, Y0 + wall_h - 0.12, sz1 + WT + 0.02), 0.0, 0.5)
		_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(sd * (X - 0.3), Y0, sz1 + 0.42), 0.0, Vector3(0.42 / 0.92, (wall_h + 0.1) / 4.55, 0.4 / 0.92), MARBLE_PIER)
		_p(b, "SM_Bld_Wall_Large_Pillar_Cap_01", Vector3(sd * (X - 0.3), Y0 + wall_h + 0.08, sz1 + 0.42), 0.0, Vector3(0.6 / 1.28, 0.4, 0.58 / 1.24))
		_u(b, "SM_Prop_FlowerPot_Fancy_01", Vector3(sd * (X - 0.3), Y0 + wall_h + 0.2 + 0.57 * 0.4, sz1 + 0.42), b.rng.randf() * TAU, 0.4)
		var p0 := sd * 1.05
		var p1 := sd * 3.35
		_run(b, "SM_Bld_Wall_Balcony_06", Vector3(minf(p0, p1), Y0, 3.95), Vector3(1, 0, 0), absf(p1 - p0), 2.5, 0.78, 0.6, {}, 1.2)
		_u(b, "SM_Prop_FlowerPot_Fancy_01", Vector3(sd * 2.2, Y0 + 0.8 + 0.57 * 0.36, 3.95), b.rng.randf() * TAU, 0.36)
		b.add("#wall_lamp", Vector3(sd * 4.0, Y0 + 2.1, sz1 + WT + 0.01), 0.0)
	var gh := 2.6
	_cols(b, "SM_Bld_Pillar_03", [-0.85, 0.85], 3.95, Y0, gh)
	var gex := 0.85 + 0.39 * gh / 3.0 * 0.5 + 0.2
	_entab(b, gex, 3.6, 4.28, Y0 + gh, 0.32)
	var gr := _roof_z(b, gex + 0.12, 3.52, 4.33, Y0 + gh + 0.32, {}, TYMPANUM, [true, true])
	_u(b, "SM_Bld_Ornament_04", Vector3(0, Y0 + gh + 0.32 + (gr - Y0 - gh - 0.32) * 0.33, 4.3), 0.0, 0.3)
	_p(b, "SM_Prop_Drapery_03", Vector3(-0.85 + 0.19, Y0 + gh - 0.03, 4.0), 0.0, Vector3((1.7 - 0.38) / 2.5, 0.8, 0.8))
	# философ у солнечных часов (со свитком — HandProps), двое учеников на скамьях слушают
	b.actor(Vector3(0.0, Y0, 1.05), 0.0, "Idle", "rich")
	b.actor(Vector3(-1.7, Y0, 1.65), PI / 2, "Sitting_Talking", "rich")
	b.actor(Vector3(1.7, Y0, 1.65), -PI / 2, "Sitting_Idle", "rich")
	b.light(Vector3(0, YP + 1.2, hz1 + 0.6))
	b.light(Vector3(0, Y0 + 2.0, 3.7))
	return Vector3(0, 0, Z1 + 0.3)
