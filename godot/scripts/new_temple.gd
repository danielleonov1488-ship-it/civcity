class_name NewTemple
extends RefCounted
## Новый храм Юпитера (владелец 12.11: «пересобрать на абсолютно новые модельки из того, что есть в Synty, а не
## приукрасить старые»; «огромные здания не увязываются с городом»; «под храмом обычная земля»; «двери уходят
## в абсолютную темноту»). Собран с нуля из деталей Synty POLYGON Ancient Empire по образцу картинки магазина Synty:
## высокий ступенчатый подиум из белого камня, четыре коринфские колонны портика, мраморная целла, синий фронтон
## с золотым рельефом, бронзовые гоплиты с копьями у лестницы, жаровни с огнём на щеках лестницы, красно-золотые
## знамёна, цветущие кусты по бокам. В масштабе города: след 5 × 6,6 м (как 2–3 дома плебеев), до конька ~4 м.
##  - своё основание: мощёный двор по всему следу (плиты травертина) с бордюром, уходящим в землю, — травы
##    и «лесенки» клеток внутри следа не видно;
##  - никакой темноты: за вратами — целла с мозаичным полом, расписными стенами, золотым Юпитером и алтарём;
##    всё нутро светится тёплым светом само (remap «glow»), днём и ночью; ночью — один огонёк (b.light) у врат;
##  - бронзовые врата — две створки Synty (Life распахивает их внутрь, как у прежнего храма).
## Чертёж — в метрах города: base делит на масштаб Catalog (тот потом умножит обратно). Прежний храм
## (CatMonuments._temple) остаётся: выключатель ON = false — снова он (снимки «было/стало»: test_perf newtemple=0).

static var ON := true

## Высоты и границы (метры города, начало — середина следа, фасад к +Z)
const Y0 := 0.06                 # верх мощёного двора
const HP := 0.72                 # высота подиума
const YP := Y0 + HP              # пол портика и целлы
const CX := 2.45                 # двор: x ±CX, z CZ0..CZ1
const CZ0 := -3.25
const CZ1 := 3.25
const PX := 1.85                 # подиум: x ±PX, z PZ0..PZ1
const PZ0 := -3.0
const PZ1 := 1.55
const SX := 1.2                  # лестница: x ±SX, от PZ1 вперёд до SZ1
const SZ1 := 2.95
const CHW := 0.4                 # щёки лестницы
const HC := 2.1                  # колонны
const KC := HC / 6.0             # масштаб колонны Synty (6 м)
const CFZ := 1.25                # передний ряд колонн
const COL_X := [-1.5, -0.5, 0.5, 1.5]
const WX := 1.6                  # целла снаружи: x ±WX, z WZ0..WZ1
const WZ0 := -2.8
const WZ1 := -0.2
const WT := 0.12                 # толщина стен целлы
const DW := 0.42                 # полуширина врат
const DH := 1.6                  # высота врат
const ENT := 0.56                # антаблемент
const EX := 1.75                 # антаблемент: x ±EX, z EZ0..EZ1
const EZ0 := -2.95
const EZ1 := 1.42
const RH := 1.95                 # кровля: полуширина по свесу
const RZ0 := -3.03
const RZ1 := 1.55

const MARBLE := {"Stucco_White_01": "Building_Marble_01"}
## Стены целлы: белая штукатурка с двумя синими полосами по низу (в тон синему тимпану)
const CELLA := {"Stucco_White_01": "Stucco_White_Pattern_01"}
const PAVING := {"Stone_01": "Floor_Tiles_06"}
const PORCH := {"Stone_01": "Floor_Tiles_02"}
const TYMPANUM := {"Stone_01": "Stucco_Blue_01", "tints": {"Stucco_Blue_01": Color(0.78, 0.87, 1.0)}}
const FRIEZE := {"Stucco_Blue_01": "Building_Marble_03"}
const GOLD := Color(1.0, 0.78, 0.36)
const BRONZE := Color(0.7, 0.48, 0.28)
const WARM := Color(0.3, 0.18, 0.09)       # свечение нутра целлы: тёплое, неяркое
## Огонь: язычки FX_Candle_Flame (белый материал без картинки) — оранжевые и светятся
const FLAME := {"tint": Color(1.0, 0.55, 0.16), "glow": Color(1.2, 0.46, 0.1)}


## Чертёж в метрах города: деталь name с осями — поворот yaw, масштаб s (по осям детали), в точке p
static func _p(b: Bp, name: String, p: Vector3, yaw := 0.0, s := Vector3.ONE, rm := {}) -> void:
	b.parts.append([name, b.base * Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(s), p), rm])


static func _box(b: Bp, name: String, c: Vector3, sz: Vector3) -> void:
	b.parts.append([name, b.base * Transform3D(Basis.from_scale(sz), c), {}])


## Ряд деталей шириной pw (родные метры) от a по направлению dir длиной len: n кусков, каждый растянут по длине;
## sy, sz — масштаб по высоте и толщине. Лицо детали (+Z) — влево от направления (наружу при обходе против часовой)
static func _run(b: Bp, name: String, a: Vector3, dir: Vector3, len: float, pw: float, sy: float, sz: float, rm := {}, seg := 1.25) -> void:
	var yaw := atan2(-dir.z, dir.x)
	var n := maxi(1, int(round(len / seg)))
	var step := len / n
	for i in n:
		_p(b, name, a + dir * step * i, yaw, Vector3(step / pw, sy, sz), rm)


## Обход прямоугольника x0..x1 × z0..z1 лицом наружу (sides: 0 перед, 1 право, 2 зад, 3 лево)
static func _ring(b: Bp, name: String, x0: float, x1: float, z0: float, z1: float, y: float, pw: float, sy: float, sz: float, rm := {}, sides := [0, 1, 2, 3], seg := 1.25) -> void:
	if 0 in sides:
		_run(b, name, Vector3(x0, y, z1), Vector3(1, 0, 0), x1 - x0, pw, sy, sz, rm, seg)
	if 1 in sides:
		_run(b, name, Vector3(x1, y, z1), Vector3(0, 0, -1), z1 - z0, pw, sy, sz, rm, seg)
	if 2 in sides:
		_run(b, name, Vector3(x1, y, z0), Vector3(-1, 0, 0), x1 - x0, pw, sy, sz, rm, seg)
	if 3 in sides:
		_run(b, name, Vector3(x0, y, z0), Vector3(0, 0, 1), z1 - z0, pw, sy, sz, rm, seg)


## Плиты пола (родная 2,5 × 2,5, вверх лицом) на прямоугольник клетками не крупнее cell
static func _floor(b: Bp, rm: Dictionary, x0: float, z0: float, x1: float, z1: float, y: float, cell := 1.3) -> void:
	var nx := maxi(1, int(ceil((x1 - x0) / cell)))
	var nz := maxi(1, int(ceil((z1 - z0) / cell)))
	var w := (x1 - x0) / nx
	var d := (z1 - z0) / nz
	for i in nx:
		for j in nz:
			_p(b, "SM_Bld_Base_Floor_01", Vector3(x0 + i * w, y, z0 + j * d), 0.0, Vector3(w / 2.5, 1, d / 2.5), rm)


## Огонь в чаше: три язычка, средний выше
static func _fire(b: Bp, c: Vector3, s: float) -> void:
	_p(b, "FX_Candle_Flame_01", c, 0.3, Vector3(1.0, 1.0, 1.0) * s * 1.0, FLAME)
	_p(b, "FX_Candle_Flame_01", c + Vector3(-0.012, 0, 0.008) * s, 1.4, Vector3(0.8, 0.7, 0.8) * s, FLAME)
	_p(b, "FX_Candle_Flame_01", c + Vector3(0.011, 0, -0.009) * s, 2.5, Vector3(0.75, 0.62, 0.75) * s, FLAME)


static func build(b: Bp) -> void:
	var K := Catalog.scale_of("temple")
	b.base = Transform3D(Basis.from_scale(Vector3.ONE / K), Vector3.ZERO)
	_court(b)
	_podium(b)
	_stairs(b)
	_porch(b)
	_cella(b)
	_roof(b)
	_dress(b)
	# жрец на верхней площадке лестницы благословляет горожан; служитель у алтаря в пронаосе поправляет огонь
	b.actor(Vector3(0, YP, 0.95), 0.0, "Spell_Simple_Idle", "rich")
	b.actor(Vector3(0.6, YP, 0.42), PI / 2, "Interact", "pleb")
	# ночью — один тёплый огонёк у врат: освещает пронаос, колонны и видимую в проём целлу
	b.light(Vector3(0, YP + 0.95, 0.15))
	b.base = Transform3D.IDENTITY
	b.door = Vector3(0, 0, CZ1 + 0.35) / K


## Мощёный двор по всему следу: плиты травертина, по краю — бордюр из тёсаного камня, уходящий в землю
## (на склоне видна его боковина, а не щель)
static func _court(b: Bp) -> void:
	_floor(b, PAVING, -CX, CZ0, CX, CZ1, Y0, 1.3)
	_ring(b, "SM_Bld_Wall_Large_01", -CX, CX, CZ0, CZ1, -0.45, 5.0, (Y0 + 0.45 + 0.02) / 4.51, 0.16, {}, [0, 1, 2, 3], 1.4)
	# цветники вдоль подиума: мраморный бортик с землёй (кусты встают в них), с торцов закрыты
	var bx0 := PX + 0.05
	var bx1 := CX - 0.06
	var pz0 := PZ0 + 0.35
	var pz1 := PZ1
	for sd: float in [-1.0, 1.0]:
		var a := Vector3(sd * bx0, Y0, pz1 if sd > 0 else pz0)
		_run(b, "SM_Bld_Floor_Trim_02", a, Vector3(0, 0, -sd), pz1 - pz0, 2.5, 0.42, (bx1 - bx0) / 1.03, {}, 1.2)
		for zz: float in [pz0, pz1]:
			_p(b, "SM_Bld_Wall_Tiny_01", Vector3(bx0 if sd > 0 else -bx1, Y0, zz), 0.0, Vector3((bx1 - bx0) / 2.5, 0.6, 0.35), MARBLE)


## Подиум: тёсаный белый камень (родная стена 5 × 4,5 — блоки в натуральную величину), карниз по верху, плинт внизу;
## внутри — мраморное ядро (сплошной объём, без щелей)
static func _podium(b: Bp) -> void:
	_box(b, "#marble", Vector3(0, Y0 + HP / 2.0, (PZ0 + PZ1) / 2.0), Vector3(2.0 * PX - 0.06, HP - 0.02, PZ1 - PZ0 - 0.06))
	var k := 0.25
	var top := YP - 0.06
	# стена от уровня земли (низ спрятан под плитами двора) до карниза; спереди — по бокам от лестницы
	_ring(b, "SM_Bld_Wall_Large_01", -PX, PX, PZ0, PZ1, top - 4.51 * k, 5.0, k, 0.25, {}, [1, 2, 3], 1.25)
	for sd: float in [-1.0, 1.0]:
		var x0 := SX + CHW if sd > 0 else -PX
		var x1 := PX if sd > 0 else -SX - CHW
		_run(b, "SM_Bld_Wall_Large_01", Vector3(x0, top - 4.51 * k, PZ1), Vector3(1, 0, 0), x1 - x0, 5.0, k, 0.25, {}, 1.0)
	_ring(b, "SM_Bld_Wall_Large_Cap_01", -PX - 0.03, PX + 0.03, PZ0 - 0.03, PZ1 + 0.03, top - 0.01, 5.0, 0.25, 0.22, {}, [1, 2, 3], 1.25)
	# цоколь: низкая выступающая ступень вокруг подиума (подиум «ступенчатый», как у храма Synty)
	_ring(b, "SM_Bld_Wall_Large_01", -PX - 0.05, PX + 0.05, PZ0 - 0.05, PZ1, Y0 - 0.3, 5.0, 0.44 / 4.51, 0.3, {}, [1, 2, 3], 1.25)
	for sd: float in [-1.0, 1.0]:
		var x0 := SX + CHW if sd > 0 else -PX - 0.03
		var x1 := PX + 0.03 if sd > 0 else -SX - CHW
		_run(b, "SM_Bld_Wall_Large_Cap_01", Vector3(x0, top - 0.01, PZ1 + 0.03), Vector3(1, 0, 0), x1 - x0, 5.0, 0.25, 0.22, {}, 1.0)


## Лестница во всю ширину между щеками: восемь ступеней по 9 см (житель ростом 1,15 м шагает по ним, как мы — по
## обычной лестнице); щёки — тёсаный камень с карнизом, на передних концах — золотые жаровни с огнём
static func _stairs(b: Bp) -> void:
	var depth := SZ1 - PZ1
	_p(b, "SM_Bld_Stairs_01", Vector3(-SX, Y0, SZ1), 0.0, Vector3(2.0 * SX / 2.5, HP / 1.5, depth / 2.5))
	for sd: float in [-1.0, 1.0]:
		var xc := sd * (SX + CHW / 2.0)
		var h := HP + 0.14
		_box(b, "#marble", Vector3(xc, Y0 + h / 2.0, PZ1 + depth / 2.0), Vector3(CHW - 0.04, h, depth))
		for side: float in [-1.0, 1.0]:
			var xw := xc + side * CHW / 2.0
			var dir := Vector3(0, 0, -1) if side > 0 else Vector3(0, 0, 1)
			var a := Vector3(xw, Y0 + h - 4.51 * 0.25, SZ1 if side > 0 else PZ1)
			_run(b, "SM_Bld_Wall_Large_01", a, dir, depth, 5.0, 0.25, 0.12, {}, 1.4)
		_run(b, "SM_Bld_Wall_Large_01", Vector3(xc - CHW / 2.0, Y0 + h - 4.51 * 0.25, SZ1), Vector3(1, 0, 0), CHW, 5.0, 0.25, 0.12, {}, 1.0)
		_p(b, "SM_Bld_Wall_Large_Pillar_Cap_01", Vector3(xc, Y0 + h, PZ1 + depth / 2.0), 0.0, Vector3((CHW + 0.08) / 1.28, 0.22, (depth + 0.06) / 1.24))
		var bz := Vector3(xc, Y0 + h + 0.09, SZ1 - 0.26)
		_p(b, "SM_Prop_Brazier_01", bz, 0.0, Vector3.ONE * 0.28)
		_p(b, "SM_Prop_Brazier_01_Insert_01", bz, 0.0, Vector3.ONE * 0.28)
		_fire(b, bz + Vector3(0, 1.62 * 0.28, 0), 3.0)


## Портик: четыре коринфские колонны с золотыми капителями спереди, по одной по бокам — вглубь; пол — узорные плиты
static func _porch(b: Bp) -> void:
	_floor(b, PORCH, -PX + 0.02, WZ1, PX - 0.02, PZ1 - 0.02, YP + 0.003, 1.3)
	_floor(b, PORCH, -PX + 0.02, PZ0 + 0.02, -WX, WZ1, YP + 0.003, 1.3)
	_floor(b, PORCH, WX, PZ0 + 0.02, PX - 0.02, WZ1, YP + 0.003, 1.3)
	_floor(b, PORCH, -WX, PZ0 + 0.02, WX, WZ0, YP + 0.003, 1.3)
	var cap := {"tints": {"": GOLD}}
	for x: float in COL_X:
		_p(b, "SM_Bld_Pillar_Large_04", Vector3(x, YP, CFZ), 0.0, Vector3(KC, KC, KC), cap)
	for x: float in [-1.5, 1.5]:
		_p(b, "SM_Bld_Pillar_Large_04", Vector3(x, YP, CFZ - 1.0), 0.0, Vector3(KC, KC, KC), cap)
	# у врат по сторонам прохода — два алтаря с огнём (у правого — служитель); середина свободна: в проём видна целла
	for sd: float in [-1.0, 1.0]:
		var ap := Vector3(sd * 0.95, YP, 0.4)
		_p(b, "SM_Prop_Plinth_04", ap, 0.0, Vector3(0.4, 0.42, 0.4))
		_p(b, "SM_Prop_Brazier_04", ap + Vector3(0, 0.68 * 0.42, 0), 0.0, Vector3.ONE * 0.34)
		_fire(b, ap + Vector3(0, 0.68 * 0.42 + 0.07, 0), 1.9)


## Целла: стены белого мрамора с полуколоннами по углам и посередине боков, бронзовые врата в мраморной раме;
## внутри — расписные красные стены, мозаика, золотой Юпитер на постаменте, алтарь с огнём, курильницы — всё
## в тёплом свете (свечение материала), ни одного тёмного угла
static func _cella(b: Bp) -> void:
	var y := YP
	var sy := HC / 3.01
	var sz := WT / 0.22
	# снаружи: бока и зад
	_run(b, "SM_Bld_Wall_01", Vector3(WX - WT / 2.0, y, WZ1), Vector3(0, 0, -1), WZ1 - WZ0, 2.5, sy, sz, CELLA, 1.35)
	_run(b, "SM_Bld_Wall_01", Vector3(WX, y, WZ0 + WT / 2.0), Vector3(-1, 0, 0), 2.0 * WX, 2.5, sy, sz, CELLA, 1.1)
	_run(b, "SM_Bld_Wall_01", Vector3(-WX + WT / 2.0, y, WZ0), Vector3(0, 0, 1), WZ1 - WZ0, 2.5, sy, sz, CELLA, 1.35)
	# фасад: по бокам от врат и над ними
	var fz := WZ1 - WT / 2.0
	_run(b, "SM_Bld_Wall_01", Vector3(-WX, y, fz), Vector3(1, 0, 0), WX - DW, 2.5, sy, sz, CELLA, 1.2)
	_run(b, "SM_Bld_Wall_01", Vector3(DW, y, fz), Vector3(1, 0, 0), WX - DW, 2.5, sy, sz, CELLA, 1.2)
	_p(b, "SM_Bld_Wall_01", Vector3(-DW, y + DH, fz), 0.0, Vector3(2.0 * DW / 2.5, (HC - DH) / 3.01, sz), MARBLE)
	# рама врат: мраморные косяки и перемычка с карнизом
	for sd: float in [-1.0, 1.0]:
		_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(sd * (DW + 0.05), y, WZ1 + 0.02), 0.0, Vector3(0.13 / 0.92, (DH + 0.04) / 4.55, 0.12 / 0.92))
	_p(b, "SM_Bld_Wall_Large_Cap_01", Vector3(-DW - 0.16, y + DH + 0.02, WZ1 + 0.04), 0.0, Vector3((2.0 * DW + 0.32) / 5.02, 0.4, 0.14))
	# бронзовые створки (Life распахивает их внутрь, каждую на наружной петле)
	var ls := Vector3(DW / 0.56, DH / 2.47, 0.7)
	_p(b, "SM_Bld_Door_Large_Half_03", Vector3(-DW, y, fz), 0.0, ls)
	_p(b, "SM_Bld_Door_Large_Half_03", Vector3(0.0, y, fz), 0.0, ls)
	# полуколонны по углам и посередине боков
	var half := {"tints": {"": GOLD}}
	var hcs: Array[Vector3] = []
	for sd: float in [-1.0, 1.0]:
		for k in 4:
			hcs.append(Vector3(sd * WX, y, lerpf(WZ1, WZ0, k / 3.0)))
		hcs.append(Vector3(sd * WX / 3.0, y, WZ0))
	for c: Vector3 in hcs:
		_p(b, "SM_Bld_Pillar_Large_01", c, 0.0, Vector3(KC * 0.9, KC, KC * 0.9), half)
	# бронзовые щиты-клипеи в простенках между полуколоннами (по бокам и сзади)
	for sd: float in [-1.0, 1.0]:
		for k in 3:
			var zc := lerpf(WZ1, WZ0, (k + 0.5) / 3.0)
			_p(b, "SM_Wep_Shield_01", Vector3(sd * (WX + 0.035), y + 1.42, zc), sd * PI / 2, Vector3.ONE * 0.34)
	for xb: float in [-2.0 * WX / 3.0, 0.0, 2.0 * WX / 3.0]:
		_p(b, "SM_Wep_Shield_01", Vector3(xb, y + 1.42, WZ0 - 0.035), PI, Vector3.ONE * 0.34)
	# цоколь целлы: профиль по низу стен (бока и зад)
	var o := 0.11 * 0.45 - WT / 2.0 + 0.06
	_ring(b, "SM_Bld_Trim_05", -WX + o, WX - o, WZ0 + o, WZ1, y, 2.5, 0.4, 0.45, MARBLE, [1, 2, 3], 0.9)
	# ---- нутро ----
	var ix := WX - WT
	var iz0 := WZ0 + WT
	var iz1 := WZ1 - WT
	var red := {"Stucco_White_01": "Stucco_Red_01", "glow": WARM * 0.9}
	var ochre := {"Stucco_White_01": "Stucco_Orange_01", "glow": WARM}
	var lin := 0.02 / 0.22
	# стены изнутри: внизу помпейский красный, выше — охра (лицом внутрь)
	for band: Array in [[0.0, 0.85, red], [0.85, HC - 0.85, ochre]]:
		var y0 := y + float(band[0])
		var hh := float(band[1]) / 3.01
		var rm: Dictionary = band[2]
		_run(b, "SM_Bld_Wall_01", Vector3(ix - 0.012, y0, iz0), Vector3(0, 0, 1), iz1 - iz0, 2.5, hh, lin, rm, 1.3)
		_run(b, "SM_Bld_Wall_01", Vector3(-ix + 0.012, y0, iz1), Vector3(0, 0, -1), iz1 - iz0, 2.5, hh, lin, rm, 1.3)
		_run(b, "SM_Bld_Wall_01", Vector3(-ix, y0, iz0 + 0.012), Vector3(1, 0, 0), 2.0 * ix, 2.5, hh, lin, rm, 1.1)
		for sd: float in [-1.0, 1.0]:
			var x0 := DW if sd > 0 else -ix
			var x1 := ix if sd > 0 else -DW
			_run(b, "SM_Bld_Wall_01", Vector3(x1, y0, iz1 - 0.012), Vector3(-1, 0, 0), x1 - x0, 2.5, hh, lin, rm, 1.2)
	# мозаика на полу и потолок — тоже в тёплом свете
	var mosaic := {"Stone_01": "Floor_Tiles_Circle_01", "glow": WARM * 0.8}
	_floor(b, mosaic, -ix, iz0, ix, iz1, y + 0.006, 1.5)
	var ceil_rm := {"Stone_01": "Building_Marble_01", "glow": WARM * 0.7}
	var nz := 2
	for j in nz:
		var d := (iz1 - iz0) / nz
		_p(b, "SM_Bld_Base_Ceiling_01", Vector3(-ix, y + HC - 0.02, iz0 + j * d), 0.0, Vector3(2.0 * ix / 2.5, 1, d / 2.5), ceil_rm)
	# золотой Юпитер на постаменте в глубине, перед ним алтарь с огнём, по бокам курильницы
	var jz := iz0 + 0.42
	_p(b, "SM_Prop_Plinth_04", Vector3(0, y, jz), 0.0, Vector3(0.62, 0.55, 0.62), {"glow": WARM * 0.6})
	_p(b, "SM_Prop_Statue_05", Vector3(0, y + 0.68 * 0.55, jz), 0.0, Vector3.ONE * 0.8, {"tints": {"Statue_01": GOLD}, "glow": WARM * 0.9})
	var az := jz + 0.95
	_p(b, "SM_Prop_Plinth_04", Vector3(0, y, az), 0.0, Vector3(0.42, 0.4, 0.42), {"glow": WARM * 0.6})
	_p(b, "SM_Prop_Brazier_04", Vector3(0, y + 0.68 * 0.4, az), 0.0, Vector3.ONE * 0.36, {"glow": WARM * 0.5})
	_fire(b, Vector3(0, y + 0.68 * 0.4 + 0.08, az), 2.0)
	for sd: float in [-1.0, 1.0]:
		_p(b, "SM_Prop_Senser_01", Vector3(sd * 0.72, y, jz + 0.15), 0.0, Vector3.ONE * 0.5, {"glow": WARM * 0.5})


## Антаблемент (мраморное ядро, архитрав и расписной фриз), пологая черепичная кровля, фронтоны с синим тимпаном
## и золотым рельефом, акротерии
static func _roof(b: Bp) -> void:
	var ye := YP + HC
	var top := ye + ENT
	_box(b, "#marble", Vector3(0, ye + ENT / 2.0, (EZ0 + EZ1) / 2.0), Vector3(2.0 * EX - 0.06, ENT - 0.02, EZ1 - EZ0 - 0.06))
	var s1 := 0.28
	_ring(b, "SM_Bld_Trim_Large_Single_01", -EX + 0.15, EX - 0.15, EZ0 + 0.15, EZ1 - 0.15, ye + 0.48 * s1, 2.5, s1, 0.3, {}, [0, 1, 2, 3], 1.2)
	_ring(b, "SM_Bld_Trim_Large_Single_02", -EX + 0.1, EX - 0.1, EZ0 + 0.1, EZ1 - 0.1, ye + 0.96 * s1 + 0.485 * s1, 2.5, s1, 0.3, FRIEZE, [0, 1, 2, 3], 1.2)
	for c: Array in [[-1.0, 1.0, 0.0], [1.0, 1.0, PI / 2], [1.0, -1.0, PI], [-1.0, -1.0, -PI / 2]]:
		var cx: float = c[0]
		var cz: float = c[1]
		var ya: float = c[2]
		var za := EZ1 - 0.15 if cz > 0 else EZ0 + 0.15
		var zb := EZ1 - 0.1 if cz > 0 else EZ0 + 0.1
		_p(b, "SM_Bld_Trim_Large_Corner_01", Vector3(cx * (EX - 0.15), ye + 0.48 * s1, za), ya, Vector3(0.3, s1, 0.3))
		_p(b, "SM_Bld_Trim_Large_Corner_01", Vector3(cx * (EX - 0.1), ye + 0.96 * s1 + 0.485 * s1, zb), ya, Vector3(0.2, s1, 0.2))
	# кровля: два ската и фронтоны
	var k := RH / 7.5
	var len := RZ1 - RZ0
	var n := 2
	var lz := len / n
	var tile := {}
	for i in n:
		var z0 := RZ0 + i * lz
		_p(b, "SM_Bld_Roof_Straight_Thin_Large_01", Vector3(-RH, top, z0), -PI / 2, Vector3(lz / 7.5, k, k), tile)
		_p(b, "SM_Bld_Roof_Straight_Thin_Large_01", Vector3(RH, top, z0 + lz), PI / 2, Vector3(lz / 7.5, k, k), tile)
	for zz: float in [RZ1 - 0.08, RZ0 + 0.08]:
		_p(b, "SM_Bld_Roof_Side_Large_01", Vector3(-RH + 0.05, top, zz), -PI / 2, Vector3(0.4, k, k), TYMPANUM)
		_p(b, "SM_Bld_Roof_Side_Large_01", Vector3(RH - 0.05, top, zz), PI / 2, Vector3(0.4, k, k), TYMPANUM)
	var ridge := top + 1.94 * k
	# рельеф фронтона: золотые фигуры на синем
	var rel := {"tints": {"Building_Marble_01": GOLD}}
	var h := ridge - top
	for e: Array in [[RZ1 - 0.035, 0.0], [RZ0 + 0.035, PI]]:
		var zr: float = e[0]
		var yw: float = e[1]
		var bs := Basis(Vector3.UP, yw)
		_p(b, "SM_Prop_Symbol_05", Vector3(0, top + 0.03, zr), yw, Vector3.ONE * h * 0.82, rel)
		_p(b, "SM_Prop_Symbol_15", bs * Vector3(-0.78, 0, 0) + Vector3(0, top + 0.03, zr), yw, Vector3.ONE * h * 0.5, rel)
		_p(b, "SM_Prop_Symbol_10", bs * Vector3(0.78, 0, 0) + Vector3(0, top + 0.03, zr), yw, Vector3.ONE * h * 0.5, rel)
	# акротерии: золотая статуя на коньке, по углам — золотые розетки на тумбах
	_p(b, "SM_Prop_Statue_04", Vector3(0, ridge - 0.03, RZ1 - 0.12), 0.0, Vector3.ONE * 0.2, {"tints": {"Statue_01": GOLD}})
	for sd: float in [-1.0, 1.0]:
		_p(b, "SM_Prop_Plinth_02", Vector3(sd * (RH - 0.12), top, RZ1 - 0.12), 0.0, Vector3(0.3, 0.12, 0.3))
		_p(b, "SM_Bld_Ornament_06", Vector3(sd * (RH - 0.12), top + 0.25, RZ1 - 0.08), 0.0, Vector3.ONE * 0.3)


## Убранство: бронзовые гоплиты с копьями на постаментах по углам двора спереди, знамёна между колоннами,
## цветущие кусты вдоль подиума, кипарисы сзади
static func _dress(b: Bp) -> void:
	var bronze := {"tints": {"Statue_01": BRONZE}}
	for sd: float in [-1.0, 1.0]:
		# гоплит стоит на щеке лестницы выше жаровни (как бронзовые воины у входа на картинке Synty); двор у щёк
		# свободен — там на утренней службе стоят горожане
		var p := Vector3(sd * (SX + CHW / 2.0), Y0 + HP + 0.14 + 0.1, PZ1 + 0.36)
		_p(b, "SM_Prop_Statue_01", p, -sd * 0.3, Vector3.ONE * 0.55, bronze)
		# знамя между крайними колоннами
		_p(b, "SM_Prop_Banner_03_C", Vector3(sd * 1.0, YP + HC - 0.02, CFZ + 0.05), 0.0, Vector3(0.62, 0.5, 0.6))
		# цветущие кусты вдоль подиума
		var nk := 7
		for k in nk:
			var z := lerpf(1.3, -2.42, k / float(nk - 1))
			var nm: String = ["SM_Env_Garden_Plants_03", "SM_Env_Garden_Plants_04", "SM_Env_Garden_Plants_06"][(k + (1 if sd > 0 else 0)) % 3]
			_p(b, nm, Vector3(sd * 2.145, Y0 + 0.14, z), b.rng.randf() * TAU, Vector3.ONE * b.rng.randf_range(0.42, 0.5), {"tint": Color(1, 1, 1)})
		_p(b, "SM_Env_Tree_Thin_0%d" % (1 + b.rng.randi() % 2), Vector3(sd * 2.15, Y0, -3.0), b.rng.randf() * TAU, Vector3.ONE * 0.36)
