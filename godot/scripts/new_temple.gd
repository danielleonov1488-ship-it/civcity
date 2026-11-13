class_name NewTemple
extends RefCounted
## Храм Юпитера (владелец 12.11: «пересобрать на абсолютно новые модельки из того, что есть в Synty, а не
## приукрасить старые»; «под храмом обычная земля»; «двери уходят в абсолютную темноту»; 13.11 о пробном храме
## в 33 м²: «слишком уменьшенный… даже меньше библиотеки и театра»). Собран с нуля из деталей Synty POLYGON Ancient
## Empire по образцу картинки магазина Synty, в размере линейки (SizeLadder): главная постройка площади —
## след 8,7 × 10,4 м (≈ 90 м², 8 домов плебеев) вместе с лестницей и своим мощёным двором, конёк ~6,7 м.
##  - высокий подиум из тёсаного белого камня со ступенчатым цоколем, широкая лестница во весь фасад между щеками;
##    на щеках — бронзовые гоплиты с копьями и жаровни, перед лестницей — два алтаря с огнём, по углам двора —
##    золотые львы;
##  - шесть коринфских колонн фасада, глубокий пронаос (ещё четыре колонны вторым рядом), целла с полуколоннами
##    по бокам и сзади (псевдопериптер), золотые медальоны в простенках;
##  - антаблемент с меандром и расписным фризом, синие фронтоны с золотым рельефом, белые карнизы по скатам,
##    акротерии; синие гирлянды и красные знамёна между колоннами;
##  - своё основание: мощёный двор по всему следу с бордюром, уходящим в землю, — травы и «лесенки» клеток внутри
##    следа не видно; цветники вдоль подиума, кипарисы;
##  - никакой темноты: за бронзовыми вратами целла — мозаика, расписные стены с фресками, золотой Юпитер, алтарь
##    с огнём; всё нутро светится тёплым светом само (remap «glow»), днём и ночью; ночью — два огонька;
##  - бронзовые врата — две створки Synty (Life распахивает их внутрь).
## По следу (Catalog.fit, SizeLadder.old_lot): храм из старого сохранения стоит на прежних клетках (6,3 × 7,6 м) —
## он собирается под них: четыре колонны, лестница уже, но такой же высокий (подиум 1,4 м, колонны 3,3 м, конёк ~6,1 м).
## Чертёж — в метрах города: base делит на масштаб Catalog (тот потом умножит обратно). Прежний храм
## (CatMonuments._temple) остаётся: выключатель ON = false — снова он (снимки «было/стало»: test_perf newtemple=0).

static var ON := true

## Полный след (м): ширина × глубина при yaw 0
const FULL := Vector2(8.7, 10.4)
## Прежний храм (CatMonuments._temple): середина его следа по z — «старое место» встаёт в те же границы
## (замер test_temple_fit: x −3,20…3,18, z −3,12…4,50 — при фасаде к +Z)
const OLD_ZC := 0.69

## Размеры текущей сборки (метры города, начало координат постройки, фасад к +Z) — задаёт _dims по следу
static var Y0 := 0.06            # верх мощёного двора
static var HP := 1.5             # высота подиума
static var YP := 1.56            # пол пронаоса и целлы
static var CX := 4.35            # двор: x ±CX, z CZ0..CZ1
static var CZ0 := -5.2
static var CZ1 := 5.2
static var PX := 3.45            # подиум: x ±PX, z PZ0..PZ1
static var PZ0 := -4.85
static var PZ1 := 1.6
static var CHW := 0.5            # щёки лестницы (заподлицо с боками подиума)
static var SX := 2.95            # лестница: x ±SX, от PZ1 вперёд до SZ1
static var SZ1 := 4.2
static var HC := 3.5             # колонны
static var KC := HC / 6.0        # масштаб колонны Synty (6 м)
static var NCOL := 6
static var COLX: Array[float] = []
static var STEP := 1.18          # шаг колонн
static var CF := 1.2             # передний ряд колонн
static var ROW2 := true          # второй ряд колонн в пронаосе
static var WX := 3.0             # целла снаружи: x ±WX, z WZ0..WZ1
static var WZ0 := -4.55
static var WZ1 := -0.9
const WT := 0.16                 # толщина стен целлы
static var DW := 0.62            # полуширина врат
static var DH := 2.45            # высота врат
static var ENT := 0.75           # антаблемент
static var EX := 3.3             # антаблемент: x ±EX, z EZ0..EZ1
static var EZ0 := -4.8
static var EZ1 := 1.53
static var RH := 3.45            # кровля: полуширина по свесу
static var RZ0 := -4.9
static var RZ1 := 1.65
static var FULL_ON := true       # полная сборка (не «старое место»)

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
const GOLD_STATUE := {"tints": {"Statue_01": GOLD}}


## Размеры по следу: fit = Vector2.ZERO — полный храм линейки; иначе — прежние клетки (ширина × глубина, м)
static func _dims(fit: Vector2) -> void:
	FULL_ON = fit == Vector2.ZERO or (fit.x >= FULL.x and fit.y >= FULL.y)
	var w := FULL.x
	var d := FULL.y
	var zc := 0.0
	if FULL_ON:
		HP = 1.5
		HC = 3.5
		ENT = 0.75
		NCOL = 6
	else:
		# тот же облик в прежних границах: узкий, но высокий (подиум и колонны почти как у полного)
		w = minf(fit.x, FULL.x) - 0.1
		d = minf(fit.y, FULL.y) - 0.1
		zc = OLD_ZC
		HP = 1.4
		HC = 3.3
		ENT = 0.7
		NCOL = 4
	YP = Y0 + HP
	CX = w / 2.0
	CZ0 = zc - d / 2.0
	CZ1 = zc + d / 2.0
	PX = CX - (0.9 if FULL_ON else 0.6)
	CHW = 0.5
	SX = PX - CHW
	SZ1 = CZ1 - (1.0 if FULL_ON else 0.75)
	PZ1 = SZ1 - (2.6 if FULL_ON else 2.3)
	PZ0 = CZ0 + (0.35 if FULL_ON else 0.25)
	KC = HC / 6.0
	var cx0 := PX - 0.5
	STEP = 2.0 * cx0 / (NCOL - 1)
	COLX = []
	for i in NCOL:
		COLX.append(-cx0 + i * STEP)
	CF = PZ1 - 0.4
	ROW2 = FULL_ON
	WX = cx0 + 0.05
	WZ1 = CF - (2.1 if FULL_ON else 1.0)
	WZ0 = PZ0 + 0.3
	DW = 0.62 if FULL_ON else 0.55
	DH = 2.45 if FULL_ON else 2.3
	EX = cx0 + 0.39 * KC + 0.12
	EZ0 = PZ0 + 0.05
	EZ1 = CF + 0.39 * KC + 0.1
	RH = EX + 0.15
	RZ0 = EZ0 - 0.1
	RZ1 = EZ1 + 0.12


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


## Стена из тёсаного камня (родная 5 × 4,51: блоки в натуральных пропорциях) от y0 до y1 по направлению dir
static func _stone(b: Bp, a: Vector3, dir: Vector3, len: float, y1: float, sz: float) -> void:
	var k := (y1 - a.y) / 4.51
	_run(b, "SM_Bld_Wall_Large_01", a, dir, len, 5.0, k, sz, {}, 5.0 * k)


static func build(b: Bp) -> void:
	_dims(Catalog.fit)
	var K := Catalog.scale_of("temple")
	b.base = Transform3D(Basis.from_scale(Vector3.ONE / K), Vector3.ZERO)
	_court(b)
	_podium(b)
	_stairs(b)
	_porch(b)
	_cella(b)
	_roof(b)
	_dress(b)
	# жрец на пронаосе за верхней ступенью благословляет горожан (на утренней службе перед ним, у самой лестницы, —
	# жрец службы, Spectacle); служитель у правого алтаря перед лестницей (со стороны щеки) поправляет огонь
	b.actor(Vector3(0, YP, CF - 0.55), 0.0, "Spell_Simple_Idle", "rich")
	var ax := _altar_x()
	b.actor(Vector3(ax + 0.45, Y0, _altar_z() - 0.05), -PI / 2, "Interact", "pleb")
	# ночью — два тёплых огонька: у врат (пронаос, колонны и видимая в проём целла) и у алтарей перед лестницей
	b.light(Vector3(0, YP + 1.1, WZ1 + 0.55))
	b.light(Vector3(0, Y0 + 1.0, _altar_z()))
	b.base = Transform3D.IDENTITY
	b.door = Vector3(0, 0, CZ1 + 0.35) / K


## Алтари перед лестницей: по бокам прохода, середина свободна (по ней поднимаются к жрецу)
static func _altar_x() -> float:
	return SX * 0.62


static func _altar_z() -> float:
	return (SZ1 + CZ1) / 2.0


## Мощёный двор по всему следу: плиты травертина, по краю — бордюр из тёсаного камня, уходящий в землю
## (на склоне видна его боковина, а не щель); бордюр внутри следа — край двора и есть край следа
static func _court(b: Bp) -> void:
	_floor(b, PAVING, -CX, CZ0, CX, CZ1, Y0, 1.45)
	var e := 0.055
	_ring(b, "SM_Bld_Wall_Large_01", -CX + e, CX - e, CZ0 + e, CZ1 - e, -0.45, 5.0, (Y0 + 0.45 + 0.02) / 4.51, 0.16, {}, [0, 1, 2, 3], 1.45)
	# цветники вдоль подиума и щёк: мраморный бортик с землёй (кусты встают в них), с торцов закрыты
	var bx0 := PX + 0.14
	var bx1 := CX - 0.08
	var pz0 := PZ0 + 0.4
	var pz1 := SZ1 - (0.75 if FULL_ON else 0.5)
	for sd: float in [-1.0, 1.0]:
		var a := Vector3(sd * bx0, Y0, pz1 if sd > 0 else pz0)
		_run(b, "SM_Bld_Floor_Trim_02", a, Vector3(0, 0, -sd), pz1 - pz0, 2.5, 0.42, (bx1 - bx0) / 1.03, {}, 1.6)
		for zz: float in [pz0, pz1]:
			_p(b, "SM_Bld_Wall_Tiny_01", Vector3(bx0 if sd > 0 else -bx1, Y0, zz), 0.0, Vector3((bx1 - bx0) / 2.5, 0.6, 0.35), MARBLE)


## Подиум: тёсаный белый камень (блоки в натуральных пропорциях), карниз по верху, ступенчатый цоколь внизу;
## внутри — мраморное ядро (сплошной объём, без щелей). Спереди его закрывают лестница и щёки
static func _podium(b: Bp) -> void:
	_box(b, "#marble", Vector3(0, Y0 + HP / 2.0, (PZ0 + PZ1) / 2.0), Vector3(2.0 * PX - 0.06, HP - 0.02, PZ1 - PZ0 - 0.06))
	var top := YP - 0.06
	var yb := Y0 - 0.3
	_stone(b, Vector3(PX, yb, PZ1), Vector3(0, 0, -1), PZ1 - PZ0, top, 0.25)
	_stone(b, Vector3(PX, yb, PZ0), Vector3(-1, 0, 0), 2.0 * PX, top, 0.25)
	_stone(b, Vector3(-PX, yb, PZ0), Vector3(0, 0, 1), PZ1 - PZ0, top, 0.25)
	_ring(b, "SM_Bld_Wall_Large_Cap_01", -PX - 0.03, PX + 0.03, PZ0 - 0.03, PZ1, top - 0.01, 5.0, 0.3, 0.25, {}, [1, 2, 3], 1.6)
	# цоколь: низкая выступающая ступень вокруг подиума и щёк (подиум «ступенчатый», как у храма Synty)
	_ring(b, "SM_Bld_Wall_Large_01", -PX - 0.04, PX + 0.04, PZ0 - 0.04, SZ1, Y0 - 0.3, 5.0, 0.46 / 4.51, 0.235, {}, [1, 2, 3], 1.6)
	# поясок посередине высоты (мраморная тяга) — подиум не «гладкая стена»
	var ym := Y0 + HP * 0.42
	_ring(b, "SM_Bld_Trim_05", -PX - 0.005, PX + 0.005, PZ0 - 0.005, SZ1 - 0.005, ym, 2.5, 0.36, 0.5, MARBLE, [1, 2, 3], 1.6)


## Лестница во всю ширину между щеками: шестнадцать ступеней по 9 см (житель ростом 1,15 м шагает по ним, как мы —
## по обычной лестнице) — два марша Synty один над другим, под верхним — мраморное ядро; щёки — тёсаный камень
## с карнизом, на передних концах — жаровни с огнём, за ними бронзовые гоплиты
static func _stairs(b: Bp) -> void:
	var depth := SZ1 - PZ1
	var n := maxi(1, int(ceil(2.0 * SX / 2.5)))
	var w := 2.0 * SX / n
	var hz := depth / 2.0
	for i in n:
		var x := -SX + i * w
		_p(b, "SM_Bld_Stairs_01", Vector3(x, Y0, SZ1), 0.0, Vector3(w / 2.5, HP / 2.0 / 1.5, hz / 2.5))
		_p(b, "SM_Bld_Stairs_01", Vector3(x, Y0 + HP / 2.0, SZ1 - hz), 0.0, Vector3(w / 2.5, HP / 2.0 / 1.5, hz / 2.5))
	_box(b, "#marble", Vector3(0, Y0 + HP / 4.0, PZ1 + hz / 2.0), Vector3(2.0 * SX, HP / 2.0, hz))
	var h := HP + 0.16
	for sd: float in [-1.0, 1.0]:
		var xc := sd * (SX + CHW / 2.0)
		_box(b, "#marble", Vector3(xc, Y0 + h / 2.0, PZ1 + depth / 2.0), Vector3(CHW - 0.04, h, depth))
		var yb := Y0 - 0.3
		var top := Y0 + h - 0.06
		for side: float in [-1.0, 1.0]:
			var xw := xc + side * CHW / 2.0
			_stone(b, Vector3(xw, yb, SZ1 if side > 0 else PZ1), Vector3(0, 0, -1) if side > 0 else Vector3(0, 0, 1), depth, top, 0.12)
		_stone(b, Vector3(xc - CHW / 2.0, yb, SZ1), Vector3(1, 0, 0), CHW, top, 0.12)
		_p(b, "SM_Bld_Wall_Large_Pillar_Cap_01", Vector3(xc, top - 0.01, PZ1 + depth / 2.0), 0.0, Vector3((CHW + 0.08) / 1.28, 0.26, (depth + 0.06) / 1.24))
		# жаровня на переднем конце щеки
		var bz := Vector3(xc, top + 0.11, SZ1 - 0.3)
		_p(b, "SM_Prop_Brazier_01", bz, 0.0, Vector3.ONE * 0.3)
		_p(b, "SM_Prop_Brazier_01_Insert_01", bz, 0.0, Vector3.ONE * 0.3)
		_fire(b, bz + Vector3(0, 1.62 * 0.3, 0), 3.2)


## Пронаос: шесть коринфских колонн фасада (у «старого места» — четыре), вторым рядом ещё четыре (у «старого
## места» — по одной по бокам); пол — узорные плиты; у врат — курильницы
static func _porch(b: Bp) -> void:
	var y := YP + 0.003
	_floor(b, PORCH, -PX + 0.02, WZ1, PX - 0.02, PZ1 - 0.02, y, 1.45)
	_floor(b, PORCH, -PX + 0.02, PZ0 + 0.02, -WX, WZ1, y, 1.45)
	_floor(b, PORCH, WX, PZ0 + 0.02, PX - 0.02, WZ1, y, 1.45)
	_floor(b, PORCH, -WX, PZ0 + 0.02, WX, WZ0, y, 1.45)
	for x: float in COLX:
		_p(b, "SM_Bld_Pillar_Large_04", Vector3(x, YP, CF), 0.0, Vector3(KC, KC, KC))
	var second: Array[float] = []
	if ROW2:
		second = [COLX[0], COLX[1], COLX[NCOL - 2], COLX[NCOL - 1]]
	else:
		second = [COLX[0], COLX[NCOL - 1]]
	var z2 := CF - STEP if ROW2 else (CF + WZ1) / 2.0
	for x: float in second:
		_p(b, "SM_Bld_Pillar_Large_04", Vector3(x, YP, z2), 0.0, Vector3(KC, KC, KC))
	# у врат по сторонам прохода — высокие бронзовые курильницы (середина свободна: в проём видна целла)
	for sd: float in [-1.0, 1.0]:
		_p(b, "SM_Prop_Senser_01", Vector3(sd * (DW + 0.55), YP, WZ1 + 0.35), 0.0, Vector3.ONE * 0.62)


## Целла: стены белого мрамора с синей полосой, полуколонны по бокам и сзади (псевдопериптер), золотые медальоны
## в простенках, бронзовые врата в мраморной раме; внутри — расписные красные стены с фресками, мозаика, золотой
## Юпитер на постаменте, алтарь с огнём, курильницы — всё в тёплом свете (свечение материала), ни одного тёмного угла
static func _cella(b: Bp) -> void:
	var y := YP
	var sy := HC / 3.01
	var sz := WT / 0.22
	# снаружи: бока и зад
	_run(b, "SM_Bld_Wall_01", Vector3(WX - WT / 2.0, y, WZ1), Vector3(0, 0, -1), WZ1 - WZ0, 2.5, sy, sz, CELLA, 1.85)
	_run(b, "SM_Bld_Wall_01", Vector3(WX, y, WZ0 + WT / 2.0), Vector3(-1, 0, 0), 2.0 * WX, 2.5, sy, sz, CELLA, 2.0)
	_run(b, "SM_Bld_Wall_01", Vector3(-WX + WT / 2.0, y, WZ0), Vector3(0, 0, 1), WZ1 - WZ0, 2.5, sy, sz, CELLA, 1.85)
	# фасад: по бокам от врат и над ними
	var fz := WZ1 - WT / 2.0
	_run(b, "SM_Bld_Wall_01", Vector3(-WX, y, fz), Vector3(1, 0, 0), WX - DW, 2.5, sy, sz, CELLA, 1.25)
	_run(b, "SM_Bld_Wall_01", Vector3(DW, y, fz), Vector3(1, 0, 0), WX - DW, 2.5, sy, sz, CELLA, 1.25)
	_p(b, "SM_Bld_Wall_01", Vector3(-DW, y + DH, fz), 0.0, Vector3(2.0 * DW / 2.5, (HC - DH) / 3.01, sz), MARBLE)
	# рама врат: мраморные косяки и перемычка с карнизом
	for sd: float in [-1.0, 1.0]:
		_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(sd * (DW + 0.06), y, WZ1 + 0.02), 0.0, Vector3(0.15 / 0.92, (DH + 0.05) / 4.55, 0.14 / 0.92))
	_p(b, "SM_Bld_Wall_Large_Cap_01", Vector3(-DW - 0.2, y + DH + 0.03, WZ1 + 0.05), 0.0, Vector3((2.0 * DW + 0.4) / 5.02, 0.5, 0.16))
	# бронзовые створки (Life распахивает их внутрь, каждую на наружной петле)
	var ls := Vector3(DW / 0.56, DH / 2.47, 0.7)
	_p(b, "SM_Bld_Door_Large_Half_03", Vector3(-DW, y, fz), 0.0, ls)
	_p(b, "SM_Bld_Door_Large_Half_03", Vector3(0.0, y, fz), 0.0, ls)
	# полуколонны: по бокам — от угла до угла с шагом колонн фасада, сзади — против колонн фасада
	var nz := maxi(2, int(round((WZ1 - WZ0) / STEP)) + 1)
	var hk := Vector3(KC * 0.92, KC, KC * 0.92)
	var zs: Array[float] = []
	for k in nz:
		zs.append(lerpf(WZ1, WZ0, k / float(nz - 1)))
	for sd: float in [-1.0, 1.0]:
		for z: float in zs:
			_p(b, "SM_Bld_Pillar_Large_01", Vector3(sd * (WX - 0.05), y, z), 0.0, hk)
	for i in range(1, NCOL - 1):
		_p(b, "SM_Bld_Pillar_Large_01", Vector3(COLX[i], y, WZ0 + 0.05), 0.0, hk)
	# золотые медальоны в простенках (по бокам и сзади)
	var med := HC * 0.66
	for sd: float in [-1.0, 1.0]:
		for k in nz - 1:
			var zc := (zs[k] + zs[k + 1]) / 2.0
			_p(b, "SM_Bld_Ornament_02", Vector3(sd * (WX + 0.01), y + med, zc), sd * PI / 2, Vector3.ONE * 0.5)
	for i in NCOL - 1:
		_p(b, "SM_Bld_Ornament_02", Vector3((COLX[i] + COLX[i + 1]) / 2.0, y + med, WZ0 - 0.01), PI, Vector3.ONE * 0.5)
	# цоколь целлы: профиль по низу стен (бока и зад)
	var o := 0.11 * 0.45 - WT / 2.0 + 0.06
	_ring(b, "SM_Bld_Trim_05", -WX + o, WX - o, WZ0 + o, WZ1, y, 2.5, 0.45, 0.45, MARBLE, [1, 2, 3], 1.3)
	_inside(b)


## Нутро целлы: стены изнутри (внизу помпейский красный, выше — охра), фрески, мозаика, потолок, золотой Юпитер,
## алтарь с огнём, курильницы — всё светится тёплым светом само (remap «glow»)
static func _inside(b: Bp) -> void:
	var y := YP
	var ix := WX - WT
	var iz0 := WZ0 + WT
	var iz1 := WZ1 - WT
	var red := {"Stucco_White_01": "Stucco_Red_01", "glow": WARM * 0.9}
	var ochre := {"Stucco_White_01": "Stucco_Orange_01", "glow": WARM}
	var lin := 0.02 / 0.22
	for band: Array in [[0.0, 0.95, red], [0.95, HC - 0.95, ochre]]:
		var y0 := y + float(band[0])
		var hh := float(band[1]) / 3.01
		var rm: Dictionary = band[2]
		_run(b, "SM_Bld_Wall_01", Vector3(ix - 0.012, y0, iz0), Vector3(0, 0, 1), iz1 - iz0, 2.5, hh, lin, rm, 1.7)
		_run(b, "SM_Bld_Wall_01", Vector3(-ix + 0.012, y0, iz1), Vector3(0, 0, -1), iz1 - iz0, 2.5, hh, lin, rm, 1.7)
		_run(b, "SM_Bld_Wall_01", Vector3(-ix, y0, iz0 + 0.012), Vector3(1, 0, 0), 2.0 * ix, 2.5, hh, lin, rm, 1.9)
		for sd: float in [-1.0, 1.0]:
			var x0 := DW if sd > 0 else -ix
			var x1 := ix if sd > 0 else -DW
			_run(b, "SM_Bld_Wall_01", Vector3(x1, y0, iz1 - 0.012), Vector3(-1, 0, 0), x1 - x0, 2.5, hh, lin, rm, 1.3)
	# фрески: по одной на боковых стенах, по бокам от Юпитера — на задней
	var fr := {"glow": WARM * 0.55}
	var ms := minf(0.6, (iz1 - iz0 - 0.3) / 2.53)
	for sd: float in [-1.0, 1.0]:
		_p(b, "SM_Prop_Mural_02", Vector3(sd * (ix - 0.03), y + 1.25 + 0.89 * ms, (iz0 + iz1) / 2.0), -sd * PI / 2, Vector3.ONE * ms, fr)
		_p(b, "SM_Prop_Mural_02", Vector3(sd * ix * 0.62, y + 1.25 + 0.89 * ms, iz0 + 0.03), 0.0, Vector3.ONE * minf(ms, ix * 0.5 / 2.53), fr)
	# мозаика на полу и потолок — тоже в тёплом свете
	var mosaic := {"Stone_01": "Floor_Tiles_Circle_01", "glow": WARM * 0.8}
	_floor(b, mosaic, -ix, iz0, ix, iz1, y + 0.006, 1.6)
	var ceil_rm := {"Stone_01": "Building_Marble_01", "glow": WARM * 0.7}
	var nx := maxi(1, int(ceil(2.0 * ix / 2.5)))
	var nzc := maxi(1, int(ceil((iz1 - iz0) / 2.5)))
	for i in nx:
		for j in nzc:
			var w := 2.0 * ix / nx
			var d := (iz1 - iz0) / nzc
			_p(b, "SM_Bld_Base_Ceiling_01", Vector3(-ix + i * w, y + HC - 0.02, iz0 + j * d), 0.0, Vector3(w / 2.5, 1, d / 2.5), ceil_rm)
	# золотой Юпитер на постаменте в глубине, перед ним алтарь с огнём, по бокам курильницы
	var big := 1.3 if FULL_ON else 1.15
	var jz := iz0 + 0.45
	var ph := 0.75 if FULL_ON else 0.65
	_p(b, "SM_Prop_Plinth_04", Vector3(0, y, jz), 0.0, Vector3(0.82, ph, 0.82), {"glow": WARM * 0.6})
	_p(b, "SM_Prop_Statue_05", Vector3(0, y + 0.68 * ph, jz), 0.0, Vector3.ONE * big, {"tints": {"Statue_01": GOLD}, "glow": WARM * 0.9})
	var az := minf(jz + 1.05, iz1 - 0.55)
	_p(b, "SM_Prop_Plinth_04", Vector3(0, y, az), 0.0, Vector3(0.45, 0.42, 0.45), {"glow": WARM * 0.6})
	_p(b, "SM_Prop_Brazier_04", Vector3(0, y + 0.68 * 0.42, az), 0.0, Vector3.ONE * 0.38, {"glow": WARM * 0.5})
	_fire(b, Vector3(0, y + 0.68 * 0.42 + 0.08, az), 2.1)
	for sd: float in [-1.0, 1.0]:
		_p(b, "SM_Prop_Senser_01", Vector3(sd * 0.85, y, jz + 0.2), 0.0, Vector3.ONE * 0.55, {"glow": WARM * 0.5})


## Антаблемент (мраморное ядро, архитрав с меандром и расписной фриз), пологая черепичная кровля, фронтоны с синим
## тимпаном и золотым рельефом, белые карнизы по скатам, акротерии
static func _roof(b: Bp) -> void:
	var ye := YP + HC
	var top := ye + ENT
	_box(b, "#marble", Vector3(0, ye + ENT / 2.0, (EZ0 + EZ1) / 2.0), Vector3(2.0 * EX - 0.06, ENT - 0.02, EZ1 - EZ0 - 0.06))
	var s1 := ENT * 0.5
	var s2 := ENT * 0.5
	_ring(b, "SM_Bld_Trim_Large_Single_01", -EX + 0.15, EX - 0.15, EZ0 + 0.15, EZ1 - 0.15, ye + 0.48 * s1, 2.5, s1, 0.3, {}, [0, 1, 2, 3], 1.5)
	_ring(b, "SM_Bld_Trim_Large_Single_02", -EX + 0.1, EX - 0.1, EZ0 + 0.1, EZ1 - 0.1, ye + 0.96 * s1 + 0.485 * s2, 2.5, s2, 0.3, FRIEZE, [0, 1, 2, 3], 1.5)
	for c: Array in [[-1.0, 1.0, 0.0], [1.0, 1.0, PI / 2], [1.0, -1.0, PI], [-1.0, -1.0, -PI / 2]]:
		var cx: float = c[0]
		var cz: float = c[1]
		var ya: float = c[2]
		var za := EZ1 - 0.15 if cz > 0 else EZ0 + 0.15
		var zb := EZ1 - 0.1 if cz > 0 else EZ0 + 0.1
		_p(b, "SM_Bld_Trim_Large_Corner_01", Vector3(cx * (EX - 0.15), ye + 0.48 * s1, za), ya, Vector3(0.3, s1, 0.3))
		_p(b, "SM_Bld_Trim_Large_Corner_01", Vector3(cx * (EX - 0.1), ye + 0.96 * s1 + 0.485 * s2, zb), ya, Vector3(0.2, s2, 0.2))
	# кровля: два ската по всей длине, фронтоны спереди и сзади
	var k := RH / 7.5
	var len := RZ1 - RZ0
	var n := maxi(1, int(ceil(len / 3.4)))
	var lz := len / n
	for i in n:
		var z0 := RZ0 + i * lz
		_p(b, "SM_Bld_Roof_Straight_Thin_Large_01", Vector3(-RH, top, z0), -PI / 2, Vector3(lz / 7.5, k, k))
		_p(b, "SM_Bld_Roof_Straight_Thin_Large_01", Vector3(RH, top, z0 + lz), PI / 2, Vector3(lz / 7.5, k, k))
	for zz: float in [RZ1 - 0.1, RZ0 + 0.1]:
		_p(b, "SM_Bld_Roof_Side_Large_01", Vector3(-RH + 0.05, top, zz), -PI / 2, Vector3(0.45, k, k), TYMPANUM)
		_p(b, "SM_Bld_Roof_Side_Large_01", Vector3(RH - 0.05, top, zz), PI / 2, Vector3(0.45, k, k), TYMPANUM)
	# белые карнизы по скатам фронтонов (рама тимпана)
	for zz: float in [RZ1 - 0.02, RZ0 + 0.02]:
		_p(b, "SM_Bld_Roof_Straight_Thin_Large_01_Trim_01", Vector3(-RH, top, zz), -PI / 2, Vector3(0.3, k, k))
		_p(b, "SM_Bld_Roof_Straight_Thin_Large_01_Trim_01", Vector3(RH, top, zz), PI / 2, Vector3(0.3, k, k))
	var ridge := top + 1.94 * k
	# рельеф фронтона: золотые фигуры на синем — посередине сцена, по бокам всадник и воин, у углов львы
	var rel := {"tints": {"Building_Marble_01": GOLD}}
	var h := ridge - top
	for e: Array in [[RZ1 - 0.03, 0.0], [RZ0 + 0.03, PI]]:
		var zr: float = e[0]
		var yw: float = e[1]
		var bs := Basis(Vector3.UP, yw)
		_p(b, "SM_Prop_Symbol_05", Vector3(0, top + 0.04, zr), yw, Vector3.ONE * h * 0.86, rel)
		_p(b, "SM_Prop_Symbol_15", bs * Vector3(-RH * 0.33, 0, 0) + Vector3(0, top + 0.04, zr), yw, Vector3.ONE * h * 0.58, rel)
		_p(b, "SM_Prop_Symbol_10", bs * Vector3(RH * 0.33, 0, 0) + Vector3(0, top + 0.04, zr), yw, Vector3.ONE * h * 0.58, rel)
		if FULL_ON:
			_p(b, "SM_Prop_Symbol_20", bs * Vector3(-RH * 0.6, 0, 0) + Vector3(0, top + 0.04, zr), yw, Vector3.ONE * h * 0.36, rel)
			_p(b, "SM_Prop_Symbol_20", bs * Vector3(RH * 0.6, 0, 0) + Vector3(0, top + 0.04, zr), yw, Vector3.ONE * h * 0.36, rel)
	# акротерии: золотая статуя на коньке спереди и сзади, по углам — золотые розетки на тумбах
	for e: Array in [[RZ1 - 0.14, 0.0], [RZ0 + 0.14, PI]]:
		_p(b, "SM_Prop_Statue_04", Vector3(0, ridge - 0.04, float(e[0])), float(e[1]), Vector3.ONE * 0.26, GOLD_STATUE)
	for sd: float in [-1.0, 1.0]:
		for zz: float in [RZ1 - 0.14, RZ0 + 0.14]:
			_p(b, "SM_Prop_Plinth_02", Vector3(sd * (RH - 0.14), top, zz), 0.0, Vector3(0.36, 0.14, 0.36))
		_p(b, "SM_Bld_Ornament_06", Vector3(sd * (RH - 0.14), top + 0.255, RZ1 - 0.1), 0.0, Vector3.ONE * 0.36)


## Убранство: бронзовые гоплиты с копьями на щеках лестницы, алтари с огнём перед ней, золотые львы по углам двора,
## синие гирлянды и красные знамёна между колоннами, цветущие кусты вдоль подиума, кипарисы сзади
static func _dress(b: Bp) -> void:
	var bronze := {"tints": {"Statue_01": BRONZE}}
	var depth := SZ1 - PZ1
	var hs := 0.74 if FULL_ON else 0.66
	for sd: float in [-1.0, 1.0]:
		# гоплит на щеке за жаровней (как бронзовые воины у входа на картинке Synty) — повернулся к лестнице
		var p := Vector3(sd * (SX + CHW / 2.0), YP + 0.16 + 0.07, PZ1 + depth * 0.38)
		_p(b, "SM_Prop_Statue_01", p, -sd * 0.35, Vector3.ONE * hs, bronze)
		# алтарь с огнём перед лестницей
		var ap := Vector3(sd * _altar_x(), Y0, _altar_z())
		_p(b, "SM_Prop_Plinth_04", ap, 0.0, Vector3(0.62, 0.62, 0.62))
		_p(b, "SM_Prop_Brazier_04", ap + Vector3(0, 0.68 * 0.62, 0), 0.0, Vector3.ONE * 0.46)
		_fire(b, ap + Vector3(0, 0.68 * 0.62 + 0.08, 0), 2.6)
		# золотой лев на постаменте в переднем углу двора, смотрит вперёд
		var lf := 1.0 if FULL_ON else 0.72
		var lp := Vector3(sd * (CX - 0.5 * lf), Y0, CZ1 - 0.5 * lf)
		var ls := 0.3 * lf
		var pls := Vector3(0.75, 0.5, 1.05) * lf
		_p(b, "SM_Prop_Plinth_04", lp, 0.0, pls)
		_p(b, "SM_Prop_Statue_Lion_01", lp + Vector3(0, 0.68 * pls.y, -0.275 * ls), -sd * 0.25, Vector3.ONE * ls, GOLD_STATUE)
		# красное знамя в крайнем пролёте фасада
		var bx := (COLX[0] + COLX[1]) / 2.0 * -sd
		_p(b, "SM_Prop_Banner_03_C", Vector3(bx, YP + HC - 0.02, CF + 0.04), 0.0, Vector3(0.62, 0.66, 0.6))
		# цветущие кусты вдоль подиума
		var bx0 := PX + 0.14
		var bx1 := CX - 0.08
		var bc := (bx0 + bx1) / 2.0
		var pz0 := PZ0 + 0.4
		var pz1 := SZ1 - (0.75 if FULL_ON else 0.5)
		var nk := maxi(4, int((pz1 - pz0) / 0.62))
		var ks := clampf((bx1 - bx0) * 0.6, 0.3, 0.5)
		for kk in nk:
			var z := lerpf(pz1 - 0.3, pz0 + 0.3, kk / float(nk - 1))
			var nm: String = ["SM_Env_Garden_Plants_03", "SM_Env_Garden_Plants_04", "SM_Env_Garden_Plants_06"][(kk + (1 if sd > 0 else 0)) % 3]
			_p(b, nm, Vector3(sd * bc, Y0 + 0.14, z), b.rng.randf() * TAU, Vector3.ONE * b.rng.randf_range(ks * 0.9, ks), {"tint": Color(1, 1, 1)})
		# кипарисы в задних углах двора
		_p(b, "SM_Env_Tree_Thin_0%d" % (1 + b.rng.randi() % 2), Vector3(sd * (CX - 0.4), Y0, CZ0 + 0.3), b.rng.randf() * TAU, Vector3.ONE * (0.44 if FULL_ON else 0.38))
	# синие гирлянды в средних пролётах фасада (под архитравом)
	for i in range(1, NCOL - 2):
		var x0: float = COLX[i]
		var x1: float = COLX[i + 1]
		_p(b, "SM_Prop_Drapery_03", Vector3((x0 + x1) / 2.0, YP + HC - 0.03, CF + 0.05), 0.0, Vector3((x1 - x0 - 0.38) / 2.5, 0.8, 0.8))
