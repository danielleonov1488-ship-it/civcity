class_name NewCivic
extends RefCounted
## Новые театр, одеон, библиотека и большие термы (владелец 13.11: «пересобрать на абсолютно новые модельки из того,
## что есть в Synty», «темноты вообще не должно быть», «под зданием обычная земля», размеры — по линейке SizeLadder).
## Собраны с нуля из деталей Synty POLYGON Ancient Empire в метрах города (base делит на масштаб Catalog, тот потом
## умножает обратно), фасад к +Z, вход — b.door. У каждого здания своё основание: мощёный двор по всему следу с
## бордюром из тёсаного камня, уходящим в землю (травы и «лесенки» клеток внутри следа не видно; Land не стелет под
## ним ни глины, ни мостовой — City.apron_of = 0). Ни одного тёмного проёма: за аркой — светлый проход, освещённый
## зал (тёплое свечение материала, remap «glow» — днём и ночью) или закрытые двери и занавеси.
##  - театр (≈ 79 м², «большие»): полукруглые ряды каменных скамей лицом к сцене, проход к орхестре по оси от
##    главной арки, две лестницы; снаружи — аркада из травертина с карнизом и парапетом, веларий на шестах; сзади —
##    сцена с деревянным полом и скена в два яруса колонн с нишами, статуями, фресками и занавесями;
##  - одеон (≈ 67 м²): малый зал для музыки — те же ряды, но в прямоугольных стенах с окнами, по трём сторонам —
##    галерея под черепичным навесом на колоннах; вход — портик с фронтоном и бронзовыми дверями (Life);
##  - библиотека (≈ 62 м², было 49): фасад в два яруса колонн, как у библиотеки Цельса, — статуи добродетелей
##    в нишах, фронтон; бронзовые двери (Life) и окна открывают тёплый зал: полки со свитками, столы, бюсты, Минерва;
##    ставни (Life) на окнах второго яруса;
##  - большие термы (≈ 112 м², было 154): зал-кальдарий с куполом на барабане и горячим бассейном за большой аркой,
##    крылья с малыми куполами, перед ними — палестра: бассейн под открытым небом, колоннады под черепицей, пальмы;
##    вход — пропилей с бронзовыми дверями (Life).
## Места зрителей и купальщиков (Spectacle) — seats(): по тем же размерам, что и сборка; каждое место проверяется
## лучами по треугольникам (Spectacle._check): таз на скамье, ступни на ступени ниже, над головой пусто.
## Постройка из старого сохранения (Catalog.fit, SizeLadder.old_lot) стоит на своих прежних клетках: библиотека
## собирается под прежний след (неглубокий зал), термы — новые посреди прежнего следа, а мостовая — по всему нему;
## театр и одеон — те же, чуть уже по прежним границам. Прежние сборки (CatCivic, CatGrand) остаются: ON — выключатели
## по типу (снимки «было/стало»); CIVCITY_NEWCIVIC=0 — прежние во всей игре.

static var ON := {"theatre": true, "odeon": true, "library": true, "thermae": true} if OS.get_environment("CIVCITY_NEWCIVIC") != "0" else {}
const TYPES := ["theatre", "odeon", "library", "thermae"]

## Полный след (м, ширина × глубина при yaw 0), середина следа — начало координат
const FULL := {"theatre": Vector2(10.1, 7.8), "odeon": Vector2(9.3, 7.2), "library": Vector2(8.6, 7.2), "thermae": Vector2(12.2, 9.2)}
## Прежний след в осях постройки (замер test_probe_lots по прежним сборкам): x0, x1, z0, z1
const OLD_RECT := {"theatre": [-4.85, 5.45, -3.15, 4.50], "odeon": [-4.43, 4.89, -3.81, 3.35],
	"library": [-4.14, 4.12, -3.87, 2.00], "thermae": [-7.24, 7.35, -6.18, 4.36]}

const Y0 := 0.06                  # верх мощёного основания
## Ряды трибун (м): ступень для ног, скамья, подъём ряда, скамья над своей ступенью (= Crowd.SEAT_DROP)
const DS := 0.22
const DB := 0.20
const RR := 0.27
const BH := 0.19
const AW := 0.17                  # полуширина лестницы между рядами
const CW := 0.42                  # полуширина прохода от главной арки к орхестре

const PAVING := {"Stone_01": "Floor_Tiles_06"}
const MOSAIC := {"Stone_01": "Floor_Tiles_Circle_01"}
const TILES := {"Stone_01": "Floor_Tiles_02"}
const BATH := {"Stone_01": "Floor_Tiles_Bath_01"}
const WOOD := {"Stone_01": "Wood_02"}
const MARBLE := {"Stucco_White_01": "Building_Marble_01", "Building_Large_Brick_01": "Building_Marble_01"}
const RED := {"Stucco_White_01": "Stucco_Red_01"}
const RED_SOFT := {"Stucco_White_01": "Stucco_Red_01", "tints": {"Stucco_Red_01": Color(1.0, 0.86, 0.8)}}
## Терракотовая штукатурка — оттенок белой (Parts: оттенок у экземпляра — общая группа с домами города, без новых вызовов)
const TERRA := {"tints": {"Stucco_White_01": Color(0.93, 0.52, 0.4)}}
## Пол зала в тёплом свете (круглая мозаика) — один на библиотеку и термы
const HALL_FLOOR := {"Stone_01": "Floor_Tiles_Circle_01", "glow": WARM * 0.8}
## Тёплый травертин (кремово-охристый) — стены и аркады театра, одеона, терм: оттенок у экземпляра, одна группа пула
const WARM_STONE := {"tints": {"Building_Large_Brick_01": Color(1.0, 0.88, 0.7)}}
## Тёплая кремовая штукатурка (оттенок белой — общая группа с домами)
const CREAM := {"tints": {"Stucco_White_01": Color(1.0, 0.9, 0.74)}}
## Ниша в тёплом свете за глухой аркой и в окне — та же раскраска, что облицовка залов (_lining, охра)
const OCHRE_GLOW := {"Stucco_White_01": "Stucco_Orange_01", "glow": WARM}
## Расписной фриз (красное с мрамором, как у храма Юпитера)
const FRIEZE := {"Stucco_Blue_01": "Building_Marble_03"}
## Пилястры из белого мрамора
const PIL := {"Building_Large_Brick_01": "Building_Marble_01"}
## Тёсаный камень тёплого травертина (как бордюр основания) — и на мелких деталях со штукатуркой
const STONE := {"Stucco_White_01": "Building_Large_Brick_01", "tints": {"Building_Large_Brick_01": Color(1.0, 0.93, 0.8)}}
const SAND := {"tints": {"Stucco_White_01": Color(1.0, 0.86, 0.66)}}
const WHITE := {"tints": {"Stucco_White_01": Color(1.0, 0.97, 0.92)}}
const TYMPANUM := {"Stone_01": "Stucco_Blue_01", "tints": {"Stucco_Blue_01": Color(0.78, 0.87, 1.0)}}
const DOME := {"Stucco_Blue_01": "Stucco_White_01", "tints": {"Stucco_White_01": Color(0.67, 0.66, 0.62)}}
const CLOTH := {"PolygonAncientEmpire_01_A": "PolygonAncientEmpire_01_C", "tints": {"PolygonAncientEmpire_01_C": Color(1.0, 0.9, 0.7)}}
const SAFFRON := {"PolygonAncientEmpire_01_A": "PolygonAncientEmpire_01_C", "tints": {"PolygonAncientEmpire_01_C": Color(1.25, 0.95, 0.5)}}
const GOLD := Color(1.0, 0.78, 0.36)
const BRONZE := Color(0.7, 0.48, 0.28)
const WARM := Color(0.3, 0.18, 0.09)       # свечение нутра: тёплое, неяркое
const FLAME := {"tint": Color(1.0, 0.55, 0.16), "glow": Color(1.2, 0.46, 0.1)}
const GOLD_STATUE := {"tints": {"Statue_01": GOLD}}
const BRONZE_STATUE := {"tints": {"Statue_01": BRONZE}}
## Лицо стены Synty (+Z) от начала координат детали (у разных стен разная толщина)
const FACE := {"SM_Bld_Wall_01": 0.11, "SM_Bld_Wall_Alcove_01": 0.38, "SM_Bld_Wall_Door_Large_01": 0.30, "SM_Bld_Wall_Window_05": 0.28,
	"SM_Bld_Wall_Window_06": 0.11, "SM_Bld_Wall_Door_Double_01": 0.24, "SM_Bld_Wall_Door_Double_Large_01": 0.22, "SM_Bld_Wall_Large_01": 0.34}


static func covers(type: String) -> bool:
	return bool(ON.get(type, false))


## Прежние сборки этих типов (выключатель ON — снимки «было»)
static func old(b: Bp, type: String) -> void:
	match type:
		"theatre": CatCivic._theatre(b)
		"odeon": CatCivic._odeon(b)
		"library": CatCivic._library(b)
		"thermae": CatGrand.make(b, type)


static func build(b: Bp, type: String) -> void:
	var K := Catalog.scale_of(type)
	b.base = Transform3D(Basis.from_scale(Vector3.ONE / K), Vector3.ZERO)
	b.door = Vector3.ZERO
	match type:
		"theatre": _theatre(b, _theatre_dims(Catalog.fit))
		"odeon": _odeon(b, _odeon_dims(Catalog.fit))
		"library": _library(b, _library_dims(Catalog.fit))
		"thermae": _thermae(b, _thermae_dims(Catalog.fit))
	b.base = Transform3D.IDENTITY
	b.door = b.door / K


## Места Spectacle (зрители театра и одеона, купальщики терм) — по тем же размерам, что и сборка
static func seats(sp, lay: Dictionary, b: Dictionary, tris) -> void:
	var type := String(b["type"])
	var fit: Vector2 = SizeLadder.OLD_LOT.get(type, Vector2.ZERO) if SizeLadder.old_lot(b) else Vector2.ZERO
	match type:
		"theatre":
			var d := _theatre_dims(fit)
			_cavea_seats(sp, lay, tris, d)
			lay["priest"] = {"root": Vector3(-0.35, float(d["Ys"]), float(d["zs"]) + 0.62), "yaw": 0.0, "row": 0, "path": PackedVector3Array(), "far": 0.0, "pose": "actor"}
		"odeon":
			var d := _odeon_dims(fit)
			_cavea_seats(sp, lay, tris, d)
			lay["priest"] = {"root": Vector3(0.55, float(d["Ys"]), float(d["zs"]) + 0.55), "yaw": 0.0, "row": 0, "path": PackedVector3Array(), "far": 0.0, "pose": "actor"}
		"thermae":
			_bath_seats(sp, lay, _thermae_dims(fit))


# =====================================================================
#   помощники
# =====================================================================

## Деталь name: поворот yaw, масштаб s (по осям детали), в точке p (метры города)
static func _p(b: Bp, name: String, p: Vector3, yaw := 0.0, s := Vector3.ONE, rm := {}) -> void:
	b.parts.append([name, b.base * Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(s), p), rm])


static func _box(b: Bp, name: String, c: Vector3, sz: Vector3, yaw := 0.0) -> void:
	b.parts.append([name, b.base * Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(sz), c), {}])


## Ряд деталей шириной pw (родные метры) от a по направлению dir длиной len: куски не длиннее seg, каждый растянут;
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
static func _floor(b: Bp, rm: Dictionary, x0: float, z0: float, x1: float, z1: float, y: float, cell := 2.0) -> void:
	var nx := maxi(1, int(ceil((x1 - x0) / cell - 0.01)))
	var nz := maxi(1, int(ceil((z1 - z0) / cell - 0.01)))
	var w := (x1 - x0) / nx
	var d := (z1 - z0) / nz
	for i in nx:
		for j in nz:
			_p(b, "SM_Bld_Base_Floor_01", Vector3(x0 + i * w, y, z0 + j * d), 0.0, Vector3(w / 2.5, 1, d / 2.5), rm)


## Своё основание: плиты травертина по всему следу, по краю — бордюр из тёсаного камня, уходящий в землю (на склоне
## видна его боковина, а не щель). Бордюр — стена Synty: по ней же и фасад постройки (Bp.front_z) — основание встаёт
## вплотную к дороге, между ним и улицей нет полосы травы
static func _base(b: Bp, x0: float, x1: float, z0: float, z1: float) -> void:
	_floor(b, PAVING, x0, z0, x1, z1, Y0, 2.1)
	var e := 0.055
	_ring(b, "SM_Bld_Wall_Large_01", x0 + e, x1 - e, z0 + e, z1 - e, -0.45, 5.0, (Y0 + 0.47) / 4.51, 0.16, {}, [0, 1, 2, 3], 2.1)


## Огонь в чаше: три язычка, средний выше
static func _fire(b: Bp, c: Vector3, s: float) -> void:
	_p(b, "FX_Candle_Flame_01", c, 0.3, Vector3.ONE * s, FLAME)
	_p(b, "FX_Candle_Flame_01", c + Vector3(-0.012, 0, 0.008) * s, 1.4, Vector3(0.8, 0.7, 0.8) * s, FLAME)
	_p(b, "FX_Candle_Flame_01", c + Vector3(0.011, 0, -0.009) * s, 2.5, Vector3(0.75, 0.62, 0.75) * s, FLAME)


## Чаша огня на столбике или на камне
static func _bowl(b: Bp, p: Vector3, s := 0.42) -> void:
	_p(b, "SM_Prop_Brazier_04", p, 0.0, Vector3.ONE * s)
	_fire(b, p + Vector3(0, 0.1 * s / 0.42, 0), 2.4 * s / 0.42)


static func _dir(t: float) -> Vector3:
	return Vector3(sin(t), 0.0, cos(t))


## Коробка на дуге вокруг c: углы t0..t1 (от +Z к +X), радиусы r0..r1, высота y0..y1. Ширина — по внешнему краю
## (соседние смыкаются без щелей); у нечётных чуть выше верх — общие кромки соседей не мерцают
static func _arc(b: Bp, nm: String, c: Vector3, t0: float, t1: float, r0: float, r1: float, y0: float, y1: float, k: int) -> void:
	var tc := (t0 + t1) * 0.5
	var w := 2.0 * r1 * tan((t1 - t0) * 0.5) + 0.012
	var top := y1 + (0.004 if k % 2 == 1 else 0.0)
	_box(b, nm, c + _dir(tc) * (r0 + r1) * 0.5 + Vector3(0, (y0 + top) * 0.5, 0), Vector3(w, top - y0, r1 - r0), tc)


## Деталь по дуге вокруг c: середина — на направлении ang, на радиусе r, шириной width (родная pw), лицом наружу
static func _on_arc(b: Bp, nm: String, c: Vector3, ang: float, r: float, y: float, width: float, pw: float, sy: float, sz: float, rm := {}) -> void:
	var bs := Basis(Vector3.UP, ang)
	var t := bs * Vector3.RIGHT
	b.parts.append([nm, b.base * Transform3D(bs * Basis.from_scale(Vector3(width / pw, sy, sz)), c + _dir(ang) * r + Vector3(0, y, 0) - t * width / 2.0), rm])


## Стена из деталей Synty (имена по модулям) вдоль +X от x0, лицом к +Z, лицо — на z; модуль шириной mw, высотой h
static func _facade(b: Bp, names: Array, x0: float, z: float, y: float, mw: float, h: float, rm := {}, sz := 1.0) -> void:
	for i in names.size():
		var nm: String = names[i]
		if nm == "":
			continue
		_p(b, nm, Vector3(x0 + i * mw, y, z - float(FACE.get(nm, 0.11)) * sz), 0.0, Vector3(mw / 2.5, h / 3.01, sz), rm)


## Двускатная кровля, конёк вдоль X над x0..x1, скаты от z0 до z1 (свес уже включён), низ скатов на высоте y;
## фронтоны на торцах (tym — раскраска). Возвращает высоту конька
static func _gable_x(b: Bp, x0: float, x1: float, z0: float, z1: float, y: float, tym := TYMPANUM, roof := {}) -> float:
	var rh := (z1 - z0) * 0.5
	var zm := (z0 + z1) * 0.5
	var k := rh / 7.5
	var len := x1 - x0
	var n := maxi(1, int(ceil(len / 3.4)))
	var lx := len / n
	for i in n:
		_p(b, "SM_Bld_Roof_Straight_Thin_Large_01", Vector3(x0 + i * lx, y, zm + rh), 0.0, Vector3(lx / 7.5, k, k), roof)
		_p(b, "SM_Bld_Roof_Straight_Thin_Large_01", Vector3(x0 + (i + 1) * lx, y, zm - rh), PI, Vector3(lx / 7.5, k, k), roof)
	for xx: float in [x0 + 0.08, x1 - 0.08]:
		_p(b, "SM_Bld_Roof_Side_Large_01", Vector3(xx, y, zm + rh - 0.05), 0.0, Vector3(0.45, k, k), tym)
		_p(b, "SM_Bld_Roof_Side_Large_01", Vector3(xx, y, zm - rh + 0.05), PI, Vector3(0.45, k, k), tym)
	return y + 1.94 * k


## Двускатная кровля, конёк вдоль Z над z0..z1, скаты от x0 до x1; фронтоны спереди и сзади
static func _gable_z(b: Bp, x0: float, x1: float, z0: float, z1: float, y: float, tym := TYMPANUM, front := true, back := true) -> float:
	var rh := (x1 - x0) * 0.5
	var xm := (x0 + x1) * 0.5
	var k := rh / 7.5
	var len := z1 - z0
	var n := maxi(1, int(ceil(len / 3.4)))
	var lz := len / n
	for i in n:
		_p(b, "SM_Bld_Roof_Straight_Thin_Large_01", Vector3(xm - rh, y, z0 + i * lz), -PI / 2, Vector3(lz / 7.5, k, k))
		_p(b, "SM_Bld_Roof_Straight_Thin_Large_01", Vector3(xm + rh, y, z0 + (i + 1) * lz), PI / 2, Vector3(lz / 7.5, k, k))
	var ends := []
	if front:
		ends.append(z1 - 0.08)
	if back:
		ends.append(z0 + 0.08)
	for zz: float in ends:
		_p(b, "SM_Bld_Roof_Side_Large_01", Vector3(xm - rh + 0.05, y, zz), -PI / 2, Vector3(0.45, k, k), tym)
		_p(b, "SM_Bld_Roof_Side_Large_01", Vector3(xm + rh - 0.05, y, zz), PI / 2, Vector3(0.45, k, k), tym)
	return y + 1.94 * k


## Карниз-плита (родная 5,02 × 0,36 × 0,9) вдоль +X от x0 до x1 на высоте y, по глубине от z0 до z1
static func _ledge(b: Bp, x0: float, x1: float, z0: float, z1: float, y: float, h := 0.26) -> void:
	_run(b, "SM_Bld_Wall_Large_Cap_01", Vector3(x0, y + 0.05 * h / 0.36, (z0 + z1) * 0.5), Vector3(1, 0, 0), x1 - x0, 5.02, h / 0.36, (z1 - z0) / 0.9, {}, 2.6)


## Гирлянда (синяя драпировка) между колоннами x0..x1 на высоте y
static func _garland(b: Bp, x0: float, x1: float, y: float, z: float) -> void:
	_p(b, "SM_Prop_Drapery_03", Vector3((x0 + x1) * 0.5, y, z), 0.0, Vector3(maxf(0.2, x1 - x0 - 0.3) / 2.5, 0.75, 0.8))


## Дерево-кипарис и цветущие кусты
static func _cypress(b: Bp, p: Vector3, s := 0.42) -> void:
	_p(b, "SM_Env_Tree_Thin_0%d" % (1 + b.rng.randi() % 2), p, b.rng.randf() * TAU, Vector3.ONE * s)


static func _bush(b: Bp, p: Vector3, s := 0.4) -> void:
	var nm: String = ["SM_Env_Garden_Plants_03", "SM_Env_Garden_Plants_04", "SM_Env_Garden_Plants_06"][b.rng.randi() % 3]
	_p(b, nm, p, b.rng.randf() * TAU, Vector3.ONE * s, {"tint": Color(1, 1, 1)})


## Нутро зала: облицовка стен изнутри (низ — помпейский красный, выше — охра), всё светится тёплым светом само
static func _lining(b: Bp, x0: float, x1: float, z0: float, z1: float, y: float, h: float, skip_front := [], skip_side := []) -> void:
	var red := {"Stucco_White_01": "Stucco_Red_01", "glow": WARM * 0.9}
	var ochre := OCHRE_GLOW
	var lin := 0.02 / 0.22
	var lo := minf(0.95, h * 0.35)
	for band: Array in [[0.0, lo, red], [lo, h - lo, ochre]]:
		var y0 := y + float(band[0])
		var hh := float(band[1]) / 3.01
		var rm: Dictionary = band[2]
		# боковые стены — кусками между окнами (skip_side: [[z0, z1], …] — окна видно насквозь в зал)
		var zs := [z0]
		for gap: Array in skip_side:
			zs.append(float(gap[0]))
			zs.append(float(gap[1]))
		zs.append(z1)
		for i in range(0, zs.size(), 2):
			var a: float = zs[i]
			var c: float = zs[i + 1]
			if c - a > 0.05:
				_run(b, "SM_Bld_Wall_01", Vector3(x1 - 0.012, y0, a), Vector3(0, 0, 1), c - a, 2.5, hh, lin, rm, 1.8)
				_run(b, "SM_Bld_Wall_01", Vector3(x0 + 0.012, y0, c), Vector3(0, 0, -1), c - a, 2.5, hh, lin, rm, 1.8)
		_run(b, "SM_Bld_Wall_01", Vector3(x0, y0, z0 + 0.012), Vector3(1, 0, 0), x1 - x0, 2.5, hh, lin, rm, 1.8)
		# передняя стена изнутри — кусками между проёмами (skip_front: [[x0, x1], …] — не облицовывать)
		var xs := [x0]
		for gap: Array in skip_front:
			xs.append(float(gap[0]))
			xs.append(float(gap[1]))
		xs.append(x1)
		for i in range(0, xs.size(), 2):
			var a: float = xs[i]
			var c: float = xs[i + 1]
			if c - a > 0.05:
				_run(b, "SM_Bld_Wall_01", Vector3(c, y0, z1 - 0.012), Vector3(-1, 0, 0), c - a, 2.5, hh, lin, rm, 1.8)


## Потолок зала (светится)
static func _ceiling(b: Bp, x0: float, z0: float, x1: float, z1: float, y: float) -> void:
	var rm := {"Stone_01": "Building_Marble_01", "glow": WARM * 0.7}
	var nx := maxi(1, int(ceil((x1 - x0) / 2.5)))
	var nz := maxi(1, int(ceil((z1 - z0) / 2.5)))
	for i in nx:
		for j in nz:
			var w := (x1 - x0) / nx
			var d := (z1 - z0) / nz
			_p(b, "SM_Bld_Base_Ceiling_01", Vector3(x0 + i * w, y, z0 + j * d), 0.0, Vector3(w / 2.5, 1, d / 2.5), rm)


# =====================================================================
#   трибуны театра и одеона (общие)
# =====================================================================
## d: c — середина орхестры (на уровне земли), AR — радиус орхестры, H0 — первая ступень, N — рядов, RW — до куда
## верхний обход (внутренняя грань наружной стены), aisles — лестницы (градусы от оси, по обе стороны), zd — вход
## (место у двери, снаружи), z_gate — главная арка (начало прохода)

static func _row_front(d: Dictionary, k: int) -> float:
	return float(d["AR"]) + DS + k * (DS + DB)


static func _step_y(d: Dictionary, k: int) -> float:
	return float(d["H0"]) + k * RR


static func _walk_y(d: Dictionary) -> float:
	return float(d["H0"]) + int(d["N"]) * RR


## Куски кольца на радиусе r (от прохода до торцов, по обе стороны): [[t0, t1, «seat» | «aisle»]]
static func _bands(d: Dictionary, r: float) -> Array:
	var t := asin(clampf(CW / r, 0.0, 1.0))
	var right := []
	for a_deg: float in d["aisles"]:
		var ta := deg_to_rad(a_deg)
		var da := asin(clampf(AW / r, 0.0, 1.0))
		if ta - da > t + 0.001:
			right.append([t, ta - da, "seat"])
		right.append([maxf(t, ta - da), ta + da, "aisle"])
		t = ta + da
	if t < PI / 2 - 0.001:
		right.append([t, PI / 2, "seat"])
	var out := []
	for e: Array in right:
		out.append(e)
		out.append([-float(e[1]), -float(e[0]), e[2]])
	return out


## Кольцо кусками не шире 9° (у скамьи на радиусе 4 м хорда отходит от дуги на 1 см — место на скамье не сдвигается)
static func _pieces(t0: float, t1: float) -> Array:
	var n := maxi(1, int(ceil((t1 - t0) / deg_to_rad(9.0))))
	var out := []
	for i in n:
		out.append([lerpf(t0, t1, float(i) / n), lerpf(t0, t1, float(i + 1) / n)])
	return out


## Ряды: ступени для ног и скамьи (#bench — каменный блок пула, как у амфитеатра и цирка), в лестницах — полуступени,
## верхний обход; у торцов (по диаметру) — закрывающие блоки ступенчатого профиля; пол орхестры — мозаика
static func _cavea(b: Bp, d: Dictionary) -> void:
	var c: Vector3 = d["c"]
	var AR: float = d["AR"]
	var N: int = d["N"]
	var seg := 0
	var yb := Y0 - 0.02
	for k in N:
		var f := _row_front(d, k)
		var y := _step_y(d, k)
		for e: Array in _bands(d, f - DS * 0.5):
			for pc: Array in _pieces(float(e[0]), float(e[1])):
				_arc(b, "#bench", c, pc[0], pc[1], f - DS, f, yb, y, seg)
				seg += 1
		for e: Array in _bands(d, f + DB * 0.5):
			var top := y + (BH if e[2] == "seat" else RR * 0.5)
			for pc: Array in _pieces(float(e[0]), float(e[1])):
				_arc(b, "#bench", c, pc[0], pc[1], f, f + DB, yb, top, seg)
				seg += 1
	var r0 := _row_front(d, N - 1) + DB
	var rw: float = d["RW"] + float(d.get("RW_OVER", 0.0))
	for e: Array in _bands(d, (r0 + rw) * 0.5):
		for pc: Array in _pieces(float(e[0]), float(e[1])):
			_arc(b, "#bench", c, pc[0], pc[1], r0, rw, yb, _walk_y(d), seg)
			seg += 1
	# низ каждой лестницы — полуступень с пола орхестры на первую ступень
	for a_deg: float in d["aisles"]:
		for sd: float in [-1.0, 1.0]:
			var ta := deg_to_rad(a_deg) * sd
			var da := asin(clampf(AW / AR, 0.0, 1.0))
			_arc(b, "#bench", c, ta - da, ta + da, AR - 0.2, AR, yb, (Y0 + float(d["H0"])) * 0.5, seg)
			seg += 1
	# торцы по диаметру: блоки по профилю рядов (снаружи сечение трибун закрыто)
	for sd: float in [-1.0, 1.0]:
		var prof := []
		for k in N:
			var f := _row_front(d, k)
			prof.append([f - DS, f, _step_y(d, k)])
			prof.append([f, f + DB, _step_y(d, k) + BH])
		prof.append([r0, float(d["RW"]), _walk_y(d)])
		for e: Array in prof:
			var ra: float = e[0]
			var rb: float = e[1]
			var h: float = e[2]
			_box(b, "#bench", c + Vector3(sd * (ra + rb) * 0.5, (yb + h) * 0.5, -0.05), Vector3(rb - ra, h - yb, 0.14))
	# пол орхестры — круглая мозаика (углы квадрата уходят под ряды)
	_floor(b, MOSAIC, -AR, float(d["zp"]), AR, c.z + AR, Y0 + 0.004, 1.6)


## Места на скамьях: ряды лицом к сцене; путь каждого — с улицы через главную арку по проходу в орхестру, к ближней
## лестнице, вверх по полуступеням до своего ряда и вдоль ряда к месту (ряды заполняются от дальних мест к лестнице)
static func _cavea_seats(sp, lay: Dictionary, tris, d: Dictionary) -> void:
	var c: Vector3 = d["c"]
	var seats_a: Array = lay["seats"]
	var AR: float = d["AR"]
	var N: int = d["N"]
	var aisles: Array = d["aisles"]
	var zd: float = d["zd"]
	var zg: float = d["z_gate"]
	for k in N:
		var f := _row_front(d, k)
		var top := _step_y(d, k) + BH
		var fy := _step_y(d, k)
		var rw := f - 0.10
		var bands := _bands(d, f + DB * 0.5)
		for bi in bands.size():
			var e: Array = bands[bi]
			if e[2] != "seat":
				continue
			var t0: float = e[0]
			var t1: float = e[1]
			var sgn := 1.0 if t0 + t1 > 0.0 else -1.0
			# ближняя лестница этого куска (по углу)
			var ta := 0.0
			var best := INF
			for a_deg: float in aisles:
				var a := deg_to_rad(a_deg) * sgn
				var dd := minf(absf(a - t0), absf(a - t1))
				if dd < best:
					best = dd
					ta = a
			# поля: у прохода к орхестре и у торцов — шире (там стенки), у лестницы — узко
			var near_corr := absf(minf(absf(t0), absf(t1)) - asin(clampf(CW / (f + DB * 0.5), 0.0, 1.0))) < 0.002
			var near_end := absf(maxf(absf(t0), absf(t1)) - PI / 2) < 0.002
			var m_lo := 0.06
			var m_hi := 0.06
			var lo_is_corr := absf(t0) < absf(t1)
			if near_corr:
				if lo_is_corr:
					m_lo = 0.14
				else:
					m_hi = 0.14
			if near_end:
				if lo_is_corr:
					m_hi = 0.24
				else:
					m_lo = 0.24
			var span := (t1 - t0) * f - m_lo - m_hi
			var n := int(floor(span / Spectacle.SPACING))
			if n <= 0:
				continue
			# путь до ряда: улица → арка → проход → орхестра → низ лестницы → вверх по лестнице
			var via := PackedVector3Array()
			via.append(Vector3(0.0, 0.0, zd))
			via.append(Vector3(0.0, Y0, zg))
			via.append(Vector3(0.0, Y0, c.z + AR - 0.25))
			via.append(c + _dir(ta) * (AR - 0.42) + Vector3(0, Y0, 0))
			via.append(c + _dir(ta) * (AR - 0.1) + Vector3(0, (Y0 + float(d["H0"])) * 0.5, 0))
			for j in k + 1:
				var fj := _row_front(d, j)
				via.append(c + _dir(ta) * (fj - DS * 0.5) + Vector3(0, _step_y(d, j), 0))
				if j < k:
					via.append(c + _dir(ta) * (fj + DB * 0.5) + Vector3(0, _step_y(d, j) + RR * 0.5, 0))
			via.append(c + _dir(ta) * rw + Vector3(0, fy, 0))
			var list := []
			for i in n:
				var th := t0 + (m_lo + (i + 0.5) * span / n) / f
				var D := _dir(th)
				var F := -D
				var E := c + D * f + Vector3(0, top, 0)
				var pelvis := E + D * Spectacle.PELVIS_IN
				var root := pelvis - D * People.SIT_BACK
				var seat_y: float = sp._check(tris, pelvis, root, F, top)
				if seat_y == -INF:
					seat_y = sp._check(tris, pelvis, root, F, top + 0.004)      # у нечётных кусков скамья на 4 мм выше
				if seat_y == -INF:
					lay["dropped"] = int(lay.get("dropped", 0)) + 1
					continue
				root.y = seat_y - Crowd.SEAT_RISE
				var path := via.duplicate()
				var m := maxi(1, int(absf(th - ta) * rw / 0.25))
				for q in range(1, m + 1):
					path.append(c + _dir(lerpf(ta, th, float(q) / m)) * rw + Vector3(0, fy, 0))
				path.append(Vector3(root.x, fy, root.z))
				list.append({"root": root, "yaw": atan2(F.x, F.z), "row": k, "path": path, "far": absf(th - ta) * f})
			list.sort_custom(func(x, y): return x["far"] > y["far"])     # дальние от лестницы — первыми
			var ids := []
			for s in list:
				ids.append(seats_a.size())
				seats_a.append(s)
			lay["groups"]["cav%d|%d" % [k, bi]] = ids


## Веларий: шесты на парапете по углам angs (градусы), между соседними — полотнища к середине
static func _velarium(b: Bp, c: Vector3, rp: float, y: float, angs: Array, depth: float) -> void:
	var tops := []
	for a_deg: float in angs:
		var a := deg_to_rad(a_deg)
		var p := c + _dir(a) * rp + Vector3(0, y, 0)
		_p(b, "SM_Prop_Pole_01", p, 0.0, Vector3(0.7, 0.55, 0.7))
		tops.append(p + Vector3(0, 1.6, 0))
	for i in angs.size() - 1:
		var a0 := deg_to_rad(float(angs[i]))
		var a1 := deg_to_rad(float(angs[i + 1]))
		var am := (a0 + a1) * 0.5
		var L := 2.0 * rp * sin((a1 - a0) * 0.5)
		var t := Vector3(cos(am), 0, -sin(am))
		var n := -_dir(am)
		var bas := Basis(-t, Vector3.UP, n) * Basis(Vector3.RIGHT, 0.22) * Basis.from_scale(Vector3(L / 5.1, 1.0, depth / 2.6))
		var p1: Vector3 = tops[i + 1]
		b.parts.append(["SM_Prop_Banner_Roof_02", b.base * Transform3D(bas, p1), SAFFRON if i == (angs.size() - 1) / 2 else CLOTH])


## Аркада трибун по полукругу (театр, одеон): девять арок из тёплого травертина, средняя — вход (сквозной проход
## к орхестре). В глухих арках — ниша в тёплом свете (свечение материала), в части — статуи на постаментах, в части —
## красные знамёна; на стыках — пилястры высотой ph; над арками — карниз
static func _arcade(b: Bp, d: Dictionary, ah: float, ph: float) -> void:
	var c: Vector3 = d["c"]
	var RO: float = d["RO"]
	var RW: float = d["RW"]
	var rm := (RW + RO) * 0.5
	var w := 2.0 * RO * sin(deg_to_rad(10.0)) + 0.02
	var sx := w / 2.5
	var sy := ah / 3.01
	for i in 9:
		var ang := deg_to_rad(-80.0 + 20.0 * i)
		_on_arc(b, "SM_Bld_Wall_Door_Double_01", c, ang, rm, Y0, w, 2.5, sy, (RO - RW) / 0.47, WARM_STONE)
		_on_arc(b, "SM_Bld_Wall_Large_Cap_01", c, ang, RO - 0.15, Y0 + ah - 0.02, w + 0.06, 5.02, 0.55, 0.5)
		if i == 4:
			continue
		# проём арки Synty — 2,0 × 1,97 родных: за ним ниша в тёплом свете
		_on_arc(b, "SM_Bld_Wall_01", c, ang, RW + 0.03, Y0, 2.0 * sx + 0.06, 2.5, (1.97 * sy + 0.05) / 3.01, 0.2, OCHRE_GLOW)
		var at := c + _dir(ang) * (RO - 0.16)
		if i % 2 == 1:
			_p(b, "SM_Prop_Plinth_03", at + Vector3(0, Y0, 0), ang, Vector3.ONE * 0.5)
			_p(b, "SM_Prop_Statue_0%d" % [3, 5, 6, 7][(i / 2) % 4], at + Vector3(0, Y0 + 0.07, 0), ang, Vector3.ONE * 0.5)
		else:
			_p(b, "SM_Prop_Banner_01_%s" % ["B", "D"][(i / 2) % 2], c + _dir(ang) * (RO + 0.02) + Vector3(0, Y0 + ah - 0.12, 0), ang, Vector3.ONE * 0.55)
	for j in 10:
		var ang := deg_to_rad(-90.0 + 20.0 * j)
		_p(b, "SM_Bld_Wall_Large_Pillar_01", c + _dir(ang) * (RO - 0.08) + Vector3(0, Y0, 0), ang, Vector3(0.24, ph / 4.55, 0.24), WARM_STONE)


## Задний фасад сцены (лицом к −Z, лицо — на zf, от x0 до x1): внизу высотой hl — глухие арки с нишей в тёплом свете,
## между ними (niches) ниши со статуями; пилястры; карниз; выше — стена, расписной фриз под венчающим карнизом
## (низ на ytop − 0,34), золотые медальоны между пилястрами
static func _back_facade(b: Bp, x0: float, x1: float, zf: float, hl: float, ytop: float, niches := true) -> void:
	var n := maxi(3, int(round((x1 - x0) / 1.9)))
	if n % 2 == 0:
		n += 1
	var mw := (x1 - x0) / n
	var sx := mw / 2.5
	var sy := hl / 3.01
	var sz := 1.0 if niches else 0.5
	for i in n:
		var xr := x1 - i * mw
		var xc := xr - mw * 0.5
		var arch := i % 2 == 1 or not niches
		var nm := "SM_Bld_Wall_Door_Double_01" if arch else "SM_Bld_Wall_Alcove_01"
		_p(b, nm, Vector3(xr, Y0, zf + float(FACE[nm]) * sz), PI, Vector3(sx, sy, sz), WARM_STONE if arch else MARBLE)
		if arch:
			_p(b, "SM_Bld_Wall_01", Vector3(xc + sx + 0.03, Y0, zf + 0.3 * sz), PI, Vector3((2.0 * sx + 0.06) / 2.5, (1.97 * sy + 0.05) / 3.01, 0.2), OCHRE_GLOW)
		else:
			_p(b, "SM_Prop_Plinth_03", Vector3(xc, Y0 + 0.02, zf + 0.25), PI, Vector3.ONE * 0.45)
			_p(b, "SM_Prop_Statue_0%d" % [3, 5, 6, 7][(i / 2) % 4], Vector3(xc, Y0 + 0.09, zf + 0.25), PI, Vector3.ONE * minf(0.5, hl * 0.22))
	for i in n + 1:
		_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(x1 - i * mw, Y0, zf - 0.04), 0.0, Vector3(0.2, (ytop - Y0) / 4.55, 0.14), WARM_STONE)
	_ledge(b, x0 - 0.05, x1 + 0.05, zf - 0.28, zf + 0.06, Y0 + hl, 0.2)
	_run(b, "SM_Bld_Trim_Large_Single_02", Vector3(x1, ytop - 0.17, zf), Vector3(-1, 0, 0), x1 - x0, 2.5, 0.34, 0.6, FRIEZE, 2.4)
	var yu := (Y0 + hl + 0.2 + ytop - 0.34) * 0.5
	if ytop - 0.34 - (Y0 + hl + 0.2) > 0.6:
		for i in n:
			_p(b, "SM_Bld_Ornament_02", Vector3(x1 - (i + 0.5) * mw, yu, zf - 0.03), PI, Vector3.ONE * 0.36)


# =====================================================================
#   театр
# =====================================================================

static func _frame(type: String, fit: Vector2) -> Array:
	var full: Vector2 = FULL[type]
	if fit == Vector2.ZERO:
		return [-full.x * 0.5, full.x * 0.5, -full.y * 0.5, full.y * 0.5, true]
	var o: Array = OLD_RECT[type]
	var hw := minf(-float(o[0]), float(o[1]))
	return [-hw, hw, float(o[2]), float(o[3]), false]


static func _theatre_dims(fit: Vector2) -> Dictionary:
	var fr := _frame("theatre", fit)
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	var RO := x1 - 0.3                       # наружная грань аркады
	var zc := z1 - 0.2 - RO                  # середина орхестры
	var AR := 1.45
	var RW := RO - 0.35                      # внутренняя грань аркады — край верхнего обхода
	var N := int(floor((RW - 0.3 - DB - (AR + DS)) / (DS + DB))) + 1
	var H0 := Y0 + 0.26
	var zp := zc - 0.12                      # передний край сцены
	var zs := zp - 1.15                      # скена (лицо стены)
	var HS := 0.5
	return {"x0": fr[0], "x1": x1, "z0": z0, "z1": z1, "full": fr[4], "RO": RO, "c": Vector3(0, 0, zc), "AR": AR, "RW": RW, "N": N,
		"H0": H0, "aisles": [45.0], "zp": zp, "zs": zs, "zb": z0 + 0.25, "HS": HS, "Ys": Y0 + HS, "SX": RO - 0.6,
		"zd": z1 + 0.35, "z_gate": z1 - 0.15}


static func _theatre(b: Bp, d: Dictionary) -> void:
	var c: Vector3 = d["c"]
	var RO: float = d["RO"]
	var RW: float = d["RW"]
	_base(b, d["x0"], d["x1"], d["z0"], d["z1"])
	_cavea(b, d)
	# аркада: девять арок из травертина по полукругу (средняя — главный вход, сквозной проход к орхестре), пилястры,
	# карниз, парапет над верхним обходом. В глухих арках — статуи и красные знамёна (за ними камень обхода, не темнота)
	var wy := _walk_y(d)
	var ah := wy + 0.05 - Y0
	_arcade(b, d, ah, ah + 0.66)
	for i in 9:
		var ang := deg_to_rad(-80.0 + 20.0 * i)
		var w := 2.0 * RO * sin(deg_to_rad(10.0)) + 0.02
		_on_arc(b, "SM_Bld_Wall_Tiny_01", c, ang, RO - 0.2, Y0 + ah + 0.18, w, 2.5, 0.95, 1.3, STONE)
	# веларий: четыре шеста на парапете, три полотнища к середине (средний — шафрановый)
	_velarium(b, c, RO - 0.2, Y0 + ah + 0.47, [-72.0, -24.0, 24.0, 72.0], 1.75)
	_theatre_stage(b, d)
	# у главной арки — колонны с чашами огня, у углов — кипарисы, цветники, статуи
	var z1: float = d["z1"]
	var x1: float = d["x1"]
	for sd: float in [-1.0, 1.0]:
		var q := Vector3(sd * 1.25, Y0, z1 - 0.17)
		_p(b, "SM_Bld_Pillar_06", q, 0.0, Vector3(0.62, 0.55, 0.62))
		_bowl(b, q + Vector3(0, 1.65, 0), 0.34)
		_cypress(b, Vector3(sd * (x1 - 0.42), Y0, z1 - 0.45), 0.4)
		_p(b, "SM_Prop_FlowerBed_01", Vector3(sd * (x1 - 1.45), Y0 + 0.17, z1 - 0.48), 0.0, Vector3.ONE * 0.5)
		_bush(b, Vector3(sd * (x1 - 0.5), Y0, z1 - 1.25), 0.36)
		_bush(b, Vector3(sd * (x1 - 1.15), Y0, z1 - 0.95), 0.32)
	b.light(Vector3(0, 1.9, z1 - 0.2))
	b.actor(Vector3(0.72, Y0, z1 - 0.32), 0.0, "Idle", "pleb")
	b.door = Vector3(0, 0, float(d["zd"]))


## Сцена: передний край — красный с росписью, пол — доски; по бокам — выступы-версуры с жаровнями; скена в два
## яруса: ниши со статуями и занавеси в трёх проёмах (не двери — Life их не распахивает), коринфские колонны,
## карнизы, гирлянды, фрески на втором ярусе; над ней — черепичная кровля; сзади и с боков — тёсаный камень
static func _theatre_stage(b: Bp, d: Dictionary) -> void:
	var RO: float = d["RO"]
	var SX: float = d["SX"]
	var zp: float = d["zp"]
	var zs: float = d["zs"]
	var zb: float = d["zb"]
	var Ys: float = d["Ys"]
	var HS: float = d["HS"]
	var S1 := 2.2
	var L1 := 0.26
	var S2 := 1.5
	var y2 := Ys + S1 + L1
	var ytop := y2 + S2
	# передний край сцены и пол
	_run(b, "SM_Bld_Wall_01", Vector3(-SX, Y0, zp - 0.11 * 0.6), Vector3(1, 0, 0), 2.0 * SX, 2.5, HS / 3.01, 0.6, TERRA, 2.2)
	for x: float in [-SX * 0.55, 0.0, SX * 0.55]:
		_p(b, "SM_Prop_Mural_03", Vector3(x, Y0 + HS * 0.5, zp + 0.012), 0.0, Vector3(0.55, 0.62, 1.0))
	_ledge(b, -SX - 0.02, SX + 0.02, zp - 0.2, zp + 0.06, Ys - 0.08, 0.1)
	_floor(b, WOOD, -SX, zs, SX, zp, Ys, 2.2)
	# версуры: каменные выступы по бокам сцены (лицом к зрителям и внутрь, к сцене), на них — чаши огня
	for sd: float in [-1.0, 1.0]:
		var xa := sd * SX
		var xb := sd * RO
		var vh := y2 - Y0 + 0.3
		if sd > 0:
			_run(b, "SM_Bld_Wall_Large_01", Vector3(xa, Y0 - 0.3, zp), Vector3(1, 0, 0), xb - xa, 5.0, vh / 4.51, 0.3, WARM_STONE, 1.0)
			_run(b, "SM_Bld_Wall_Large_01", Vector3(xa, Y0 - 0.3, zs), Vector3(0, 0, 1), zp - zs, 5.0, vh / 4.51, 0.3, WARM_STONE, 1.3)
			_run(b, "SM_Bld_Wall_Large_01", Vector3(xb, Y0 - 0.3, zp), Vector3(0, 0, -1), zp - zb, 5.0, vh / 4.51, 0.3, WARM_STONE, 1.3)
		else:
			_run(b, "SM_Bld_Wall_Large_01", Vector3(xb, Y0 - 0.3, zp), Vector3(1, 0, 0), xa - xb, 5.0, vh / 4.51, 0.3, WARM_STONE, 1.0)
			_run(b, "SM_Bld_Wall_Large_01", Vector3(xa, Y0 - 0.3, zp), Vector3(0, 0, -1), zp - zs, 5.0, vh / 4.51, 0.3, WARM_STONE, 1.3)
			_run(b, "SM_Bld_Wall_Large_01", Vector3(xb, Y0 - 0.3, zb), Vector3(0, 0, 1), zp - zb, 5.0, vh / 4.51, 0.3, WARM_STONE, 1.3)
		var vc := Vector3((xa + xb) * 0.5, Y0 + vh - 0.3, (zs + zp) * 0.5)
		_p(b, "SM_Bld_Wall_Large_Pillar_Cap_01", vc, 0.0, Vector3((RO - SX + 0.1) / 1.28, 0.4, (zp - zs + 0.1) / 1.24))
		_bowl(b, vc + Vector3(0, 0.17, 0.15), 0.4)
		_p(b, "SM_Prop_Banner_03_C", Vector3((xa + xb) * 0.5, Y0 + vh - 0.42, zp + 0.17), 0.0, Vector3(0.5, 0.62, 0.6))
	b.light(Vector3(0, Ys + 1.6, zs + 0.9))
	# скена: нижний ярус — ниша, занавесь, занавесь (средняя — с золотым медальоном), занавесь, ниша
	var mw := 2.0 * SX / 5.0
	var sy1 := S1 / 3.01
	_facade(b, ["SM_Bld_Wall_Alcove_01", "SM_Bld_Wall_Door_Large_01", "SM_Bld_Wall_Door_Large_01", "SM_Bld_Wall_Door_Large_01", "SM_Bld_Wall_Alcove_01"], -SX, zs, Ys, mw, S1, MARBLE)
	var kx := mw / 2.5
	for i: int in [1, 2, 3]:
		var x0 := -SX + i * mw
		# занавесь в проёме (две полосы красной ткани от верха проёма до пола), за ней — закрыто
		for h: float in [0.0, 0.5]:
			_p(b, "SM_Prop_Banner_03_%s" % ("C" if i != 2 else "A"), Vector3(x0 + (0.65 + 0.3 + h * 1.2) * kx, Ys + 2.58 * sy1, zs - 0.15), 0.0, Vector3(0.69 * kx, 1.07 * sy1, 0.5))
	for i: int in [0, 4]:
		var x := -SX + (i + 0.5) * mw
		_p(b, "SM_Prop_Statue_0%d" % [7, 3][i / 4], Vector3(x, Ys + 0.16, zs - 0.22), 0.0, Vector3.ONE * 0.52)
	_p(b, "SM_Bld_Ornament_02", Vector3(0, Ys + 2.72 * sy1, zs + 0.04), 0.0, Vector3.ONE * 0.45)
	# колонны нижнего яруса, карниз, гирлянды
	var cols := [-SX + 0.22]
	for i in range(1, 5):
		cols.append(-SX + i * mw)
	cols.append(SX - 0.22)
	for x: float in cols:
		_p(b, "SM_Prop_Plinth_03", Vector3(x, Ys, zs + 0.4), 0.0, Vector3(0.62, 0.5, 0.62))
		_p(b, "SM_Bld_Pillar_04", Vector3(x, Ys + 0.075, zs + 0.4), 0.0, Vector3(0.62, (S1 - 0.075) / 3.0, 0.62))
	_ledge(b, -SX - 0.08, SX + 0.08, zs - 0.08, zs + 0.72, Ys + S1, L1)
	for i in range(1, 4):
		_garland(b, float(cols[i]), float(cols[i + 1]), Ys + S1 - 0.04, zs + 0.62)
	# верхний ярус: ниша, фреска, ниша (больше), фреска, ниша; тонкие колонны; карниз
	var sy2 := S2 / 3.01
	_facade(b, ["SM_Bld_Wall_Alcove_01", "SM_Bld_Wall_01", "SM_Bld_Wall_Alcove_01", "SM_Bld_Wall_01", "SM_Bld_Wall_Alcove_01"], -SX, zs, y2, mw, S2, MARBLE)
	for i: int in [0, 2, 4]:
		_p(b, "SM_Prop_Statue_0%d" % [5, 4, 6][i / 2], Vector3(-SX + (i + 0.5) * mw, y2 + 0.12, zs - 0.2), 0.0, Vector3.ONE * (0.46 if i == 2 else 0.4))
	for i: int in [1, 3]:
		_p(b, "SM_Prop_Mural_02", Vector3(-SX + (i + 0.5) * mw, y2 + S2 * 0.52, zs + 0.012), 0.0, Vector3.ONE * minf(0.42, mw * 0.82 / 2.53))
	for x: float in cols:
		_p(b, "SM_Bld_Pillar_06", Vector3(x, y2, zs + 0.3), 0.0, Vector3(0.55, S2 / 3.0, 0.55))
	_ledge(b, -SX - 0.08, SX + 0.08, zs - 0.08, zs + 0.5, ytop, 0.28)
	# знамёна между колоннами верхнего яруса
	for i: int in [1, 3]:
		_p(b, "SM_Prop_Banner_04_%s" % ["A", "C"][i / 2], Vector3(-SX + i * mw, ytop - 0.05, zs + 0.34), 0.0, Vector3.ONE * 0.36)
	# сзади и с боков (над версурами) — тёсаный камень до карниза; пилястры по заду; кровля
	# зад: внизу — арки с нишами в тёплом свете и ниши со статуями, выше — стена с фризом и медальонами
	var hl := 2.3
	_run(b, "SM_Bld_Wall_Large_01", Vector3(RO, Y0 + hl, zb), Vector3(-1, 0, 0), 2.0 * RO, 5.0, (ytop + 0.3 - Y0 - hl) / 4.51, 0.3, WARM_STONE, 2.4)
	_run(b, "SM_Bld_Wall_Large_01", Vector3(RO, Y0 - 0.3, zb), Vector3(-1, 0, 0), 2.0 * RO, 5.0, 0.3 / 4.51, 0.3, WARM_STONE, 2.4)
	_back_facade(b, -RO, RO, zb - 0.1, hl, ytop + 0.3)
	for sd: float in [-1.0, 1.0]:
		var x := sd * SX
		if sd > 0:
			_run(b, "SM_Bld_Wall_Large_01", Vector3(RO, y2, zs), Vector3(0, 0, -1), zs - zb, 5.0, (ytop + 0.3 - y2) / 4.51, 0.3, WARM_STONE, 1.4)
		else:
			_run(b, "SM_Bld_Wall_Large_01", Vector3(-RO, y2, zb), Vector3(0, 0, 1), zs - zb, 5.0, (ytop + 0.3 - y2) / 4.51, 0.3, WARM_STONE, 1.4)
		# над версурами — стенка от скены до края (закрывает торец верхнего яруса)
		_run(b, "SM_Bld_Wall_Large_01", Vector3(x if sd > 0 else -RO, y2, zs + 0.06), Vector3(1, 0, 0), RO - SX, 5.0, (ytop + 0.3 - y2) / 4.51, 0.2, WARM_STONE, 1.0)
	# бока: пилястры, карниз на высоте версур, расписной фриз под венчающим карнизом, медальоны, знамёна
	for sd: float in [-1.0, 1.0]:
		for z: float in [zb + 0.12, (zb + zs) * 0.5, zs - 0.05, (zs + zp) * 0.5 + 0.1, zp - 0.06]:
			_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(sd * (RO + 0.07), Y0, z), 0.0, Vector3(0.2, ((ytop if z < zs else y2) - Y0) / 4.55, 0.3), WARM_STONE)
		var xs := sd * (RO + 0.1)
		if sd > 0:
			_run(b, "SM_Bld_Trim_Large_Single_02", Vector3(xs, ytop + 0.13, zs), Vector3(0, 0, -1), zs - zb, 2.5, 0.34, 0.6, FRIEZE, 1.5)
			_run(b, "SM_Bld_Wall_Large_Cap_01", Vector3(xs - 0.1, y2 - 0.04, zp), Vector3(0, 0, -1), zp - zb, 5.02, 0.45, 0.4, {}, 1.5)
		else:
			_run(b, "SM_Bld_Trim_Large_Single_02", Vector3(xs, ytop + 0.13, zb), Vector3(0, 0, 1), zs - zb, 2.5, 0.34, 0.6, FRIEZE, 1.5)
			_run(b, "SM_Bld_Wall_Large_Cap_01", Vector3(xs + 0.1, y2 - 0.04, zb), Vector3(0, 0, 1), zp - zb, 5.02, 0.45, 0.4, {}, 1.5)
		_p(b, "SM_Bld_Ornament_02", Vector3(xs + sd * 0.02, (y2 + ytop) * 0.5, (zb + zs) * 0.5), sd * PI / 2, Vector3.ONE * 0.4)
		_p(b, "SM_Prop_Banner_03_C", Vector3(sd * (RO + 0.13), y2 - 0.25, (zs + zp) * 0.5), sd * PI / 2, Vector3(0.5, 0.62, 0.6))
	_ledge(b, -RO - 0.06, RO + 0.06, zb - 0.2, zs + 0.1, ytop + 0.28, 0.12)
	var ridge := _gable_x(b, -RO - 0.1, RO + 0.1, zb - 0.22, zs + 0.18, ytop + 0.38, {"Stone_01": "Stucco_Red_01"})
	for sd: float in [-1.0, 1.0]:
		_p(b, "SM_Prop_Statue_04", Vector3(sd * (RO - 0.3), ridge - 0.12, (zb + zs) * 0.5), 0.0, Vector3.ONE * 0.24, GOLD_STATUE)
	# на сцене: ковёр, лира на подставке, кресло
	_p(b, "SM_Prop_Rug_02", Vector3(0.4, Ys + 0.005, (zs + zp) * 0.5), PI / 2, Vector3(0.42, 1.0, 0.42))
	_p(b, "SM_Prop_Plinth_02", Vector3(SX * 0.62, Ys, zs + 0.75), 0.0, Vector3(0.6, 0.62, 0.6))
	_p(b, "SM_Prop_Lyre_01", Vector3(SX * 0.62, Ys + 0.66, zs + 0.75), 0.0, Vector3.ONE * 0.5)
	_p(b, "SM_Prop_Seat_Chair_01", Vector3(-SX * 0.6, Ys, zs + 0.7), 0.0, Vector3.ONE * 0.6)
	b.actor(Vector3(1.35, Ys, zs + 0.7), -0.3, "Spell_Simple_Idle", "rich")


# =====================================================================
#   одеон
# =====================================================================

static func _odeon_dims(fit: Vector2) -> Dictionary:
	var fr := _frame("odeon", fit)
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	var RO := x1 - 0.3                       # наружная грань аркады
	var zc := z1 - 0.7 - RO                  # середина орхестры (впереди — портик)
	var AR := 1.3
	var RW := RO - 0.35                      # внутренняя грань аркады — край обхода (на обходе — колонны галереи)
	var N := mini(5, int(floor((RW - 0.45 - DB - (AR + DS)) / (DS + DB))) + 1)
	var H0 := Y0 + 0.26
	var zp := zc - 0.12
	var zs := zp - 1.0
	var HS := 0.45
	return {"x0": fr[0], "x1": x1, "z0": z0, "z1": z1, "full": fr[4], "RO": RO, "EX": RO, "c": Vector3(0, 0, zc), "AR": AR, "RW": RW,
		"N": N, "H0": H0, "aisles": [50.0], "zp": zp, "zs": zs, "zb": z0 + 0.2, "HS": HS, "Ys": Y0 + HS, "SX": RO - 0.5,
		"zd": z1 + 0.35, "z_gate": z1 - 0.15}


## Одеон: полукруг рядов (сверху видно), вокруг — аркада из тёплого травертина с нишами в тёплом свете, статуями и
## знамёнами; над ней — кремовая стенка с расписным фризом, а над обходом — галерея: колонны и черепичный навес
## кольцом (рядов не закрывает); вход — открытая средняя арка с портиком и фронтоном; сзади — сцена под черепицей
static func _odeon(b: Bp, d: Dictionary) -> void:
	var c: Vector3 = d["c"]
	var RO: float = d["RO"]
	var RW: float = d["RW"]
	var z1: float = d["z1"]
	var x1: float = d["x1"]
	_base(b, d["x0"], d["x1"], d["z0"], d["z1"])
	_cavea(b, d)
	var wy := _walk_y(d)
	var ah := wy + 0.05 - Y0
	var eh := wy + 1.12                      # верх наружной стены — низ навеса
	_arcade(b, d, ah, eh - Y0)
	var w := 2.0 * RO * sin(deg_to_rad(10.0)) + 0.02
	var rc := RW - 0.4                       # колонны галереи — по краю обхода
	var top_in := eh + 0.28
	var k := (RO + 0.14 - (rc - 0.12)) / 7.5
	var wo := 2.0 * (RO + 0.14) * sin(deg_to_rad(10.0)) + 0.05
	var yband := Y0 + ah + 0.16
	for i in 9:
		var ang := deg_to_rad(-80.0 + 20.0 * i)
		_on_arc(b, "SM_Bld_Wall_01", c, ang, RO - 0.12, yband, w, 2.5, (eh - 0.32 - yband) / 3.01, 1.0, CREAM)
		_on_arc(b, "SM_Bld_Trim_Large_Single_02", c, ang, RO - 0.02, eh - 0.17, w, 2.5, 0.34, 0.6, FRIEZE)
		var bs := Basis(Vector3.UP, ang)
		var t := bs * Vector3.RIGHT
		b.parts.append(["SM_Bld_Roof_Straight_Thin_Large_01", b.base * Transform3D(bs * Basis.from_scale(Vector3(wo / 7.5, k, k)), c + _dir(ang) * (RO + 0.14) + Vector3(0, eh - 0.04, 0) - t * wo * 0.5), {}])
	for j in 10:
		var ang := deg_to_rad(-90.0 + 20.0 * j)
		_p(b, "SM_Bld_Pillar_06", c + _dir(ang) * rc + Vector3(0, wy, 0), 0.0, Vector3(0.45, (top_in - wy) / 3.0, 0.45))
	_odeon_stage(b, d)
	# портик у средней арки: две колонны, антаблемент, фронтон с золотым медальоном и статуей
	var fz := c.z + RO
	var pz := fz + 0.42
	for sd: float in [-1.0, 1.0]:
		_p(b, "SM_Bld_Pillar_02", Vector3(sd * 0.9, Y0, pz), 0.0, Vector3(0.6, 0.72, 0.6))
	_ledge(b, -1.2, 1.2, fz - 0.15, pz + 0.3, Y0 + 2.16, 0.22)
	var pr := _gable_z(b, -1.25, 1.25, fz - 0.2, pz + 0.36, Y0 + 2.4, TYMPANUM, true, false)
	_p(b, "SM_Bld_Ornament_02", Vector3(0, Y0 + 2.4 + (pr - Y0 - 2.4) * 0.4, pz + 0.31), 0.0, Vector3.ONE * 0.3)
	_p(b, "SM_Prop_Statue_04", Vector3(0, pr - 0.08, pz + 0.26), 0.0, Vector3.ONE * 0.22, GOLD_STATUE)
	# углы основания: кипарисы, цветники, статуи на постаментах, кусты
	for sd: float in [-1.0, 1.0]:
		_cypress(b, Vector3(sd * (x1 - 0.35), Y0, z1 - 0.38), 0.38)
		_p(b, "SM_Prop_FlowerBed_01", Vector3(sd * 2.1, Y0 + 0.17, z1 - 0.45), 0.0, Vector3.ONE * 0.46)
		var q := Vector3(sd * (x1 - 0.75), Y0, c.z + RO * 0.78)
		_p(b, "SM_Prop_Plinth_04", q, 0.0, Vector3(0.5, 0.45, 0.5))
		_p(b, "SM_Prop_Statue_0%d" % (5 if sd < 0 else 6), q + Vector3(0, 0.31, 0), -sd * 0.6, Vector3.ONE * 0.46)
		_bush(b, Vector3(sd * (x1 - 0.45), Y0, c.z + RO * 0.45), 0.32)
		_bush(b, Vector3(sd * (x1 - 1.3), Y0, z1 - 0.95), 0.3)
	b.light(Vector3(0, 1.8, pz + 0.2))
	b.actor(Vector3(-0.55, Y0, pz + 0.15), 0.25, "Idle", "pleb")
	b.door = Vector3(0, 0, float(d["zd"]))


## Сцена одеона: один ярус — ниша с музой, закрытые бронзовые двери, ниша; колонны, карниз, аттик со статуями,
## черепичная кровля; на сцене — лира, кресло музыканта, жаровни
static func _odeon_stage(b: Bp, d: Dictionary) -> void:
	var EX: float = d["EX"]
	var SX: float = d["SX"]
	var zp: float = d["zp"]
	var zs: float = d["zs"]
	var zb: float = d["zb"]
	var Ys: float = d["Ys"]
	var HS: float = d["HS"]
	var S1 := 2.25
	var ytop := Ys + S1 + 0.26
	_run(b, "SM_Bld_Wall_01", Vector3(-SX, Y0, zp - 0.11 * 0.6), Vector3(1, 0, 0), 2.0 * SX, 2.5, HS / 3.01, 0.6, TERRA, 2.2)
	for x: float in [-SX * 0.5, SX * 0.5]:
		_p(b, "SM_Prop_Mural_03", Vector3(x, Y0 + HS * 0.5, zp + 0.012), 0.0, Vector3(0.5, 0.56, 1.0))
	_ledge(b, -SX - 0.02, SX + 0.02, zp - 0.2, zp + 0.06, Ys - 0.08, 0.1)
	_floor(b, WOOD, -SX, zs, SX, zp, Ys, 2.2)
	# по бокам сцены — каменные выступы до стен зала
	for sd: float in [-1.0, 1.0]:
		var xa := sd * SX
		var xb := sd * EX
		var vh := ytop - Y0 + 0.3
		var lo := minf(xa, xb)
		var hi := maxf(xa, xb)
		_run(b, "SM_Bld_Wall_Large_01", Vector3(lo, Y0 - 0.3, zp), Vector3(1, 0, 0), hi - lo, 5.0, vh / 4.51, 0.3, WARM_STONE, 1.0)
		if sd > 0:
			_run(b, "SM_Bld_Wall_Large_01", Vector3(xa, Y0 - 0.3, zs), Vector3(0, 0, 1), zp - zs, 5.0, vh / 4.51, 0.3, WARM_STONE, 1.0)
		else:
			_run(b, "SM_Bld_Wall_Large_01", Vector3(xa, Y0 - 0.3, zp), Vector3(0, 0, -1), zp - zs, 5.0, vh / 4.51, 0.3, WARM_STONE, 1.0)
		_run(b, "SM_Bld_Wall_Large_01", Vector3(xb, Y0 - 0.3, zp if sd > 0 else zb), Vector3(0, 0, -1) if sd > 0 else Vector3(0, 0, 1), zp - zb, 5.0, vh / 4.51, 0.3, WARM_STONE, 1.5)
		_p(b, "SM_Prop_Plinth_02", Vector3((xa + xb) * 0.5, Y0 + vh - 0.3, (zs + zp) * 0.5), 0.0, Vector3(0.7, 0.3, 0.7))
		_p(b, "SM_Prop_Statue_0%d" % (5 if sd < 0 else 7), Vector3((xa + xb) * 0.5, Y0 + vh, (zs + zp) * 0.5), 0.0, Vector3.ONE * 0.36)
	var mw := 2.0 * SX / 3.0
	_facade(b, ["SM_Bld_Wall_Alcove_01", "SM_Bld_Wall_Door_Large_01", "SM_Bld_Wall_Alcove_01"], -SX, zs, Ys, mw, S1, MARBLE)
	var kx := mw / 2.5
	var sy1 := S1 / 3.01
	# посредине — занавесь из красной ткани (не створки: Life не распахнёт их в пустое нутро сцены)
	for h: float in [0.0, 0.5]:
		_p(b, "SM_Prop_Banner_03_A", Vector3(-SX + mw + (0.65 + 0.3 + h * 1.2) * kx, Ys + 2.58 * sy1, zs - 0.15), 0.0, Vector3(0.69 * kx, 1.07 * sy1, 0.5))
	for i: int in [0, 2]:
		_p(b, "SM_Prop_Statue_0%d" % [6, 3][i / 2], Vector3(-SX + (i + 0.5) * mw, Ys + 0.16, zs - 0.22), 0.0, Vector3.ONE * 0.5)
	var cols := [-SX + 0.22, -SX + mw, SX - mw, SX - 0.22]
	for x: float in cols:
		_p(b, "SM_Bld_Pillar_04", Vector3(x, Ys, zs + 0.38), 0.0, Vector3(0.6, S1 / 3.0, 0.6))
	_ledge(b, -SX - 0.08, SX + 0.08, zs - 0.08, zs + 0.68, Ys + S1, 0.26)
	_garland(b, float(cols[1]), float(cols[2]), Ys + S1 - 0.04, zs + 0.6)
	_garland(b, float(cols[0]), float(cols[1]), Ys + S1 - 0.04, zs + 0.6)
	_garland(b, float(cols[2]), float(cols[3]), Ys + S1 - 0.04, zs + 0.6)
	# зад и аттик, кровля
	# зад: арки с нишами в тёплом свете, пилястры, карниз, фриз (одеон развёрнут к улице и задом — у части городов)
	var hl := 1.95
	_run(b, "SM_Bld_Wall_Large_01", Vector3(EX, Y0 + hl, zb), Vector3(-1, 0, 0), 2.0 * EX, 5.0, (ytop + 0.3 - Y0 - hl) / 4.51, 0.3, WARM_STONE, 2.4)
	_run(b, "SM_Bld_Wall_Large_01", Vector3(EX, Y0 - 0.3, zb), Vector3(-1, 0, 0), 2.0 * EX, 5.0, 0.3 / 4.51, 0.3, WARM_STONE, 2.4)
	_back_facade(b, -EX, EX, zb - 0.1, hl, ytop + 0.3, false)
	_run(b, "SM_Bld_Wall_Large_01", Vector3(-SX, Ys + S1, zs + 0.05), Vector3(1, 0, 0), 2.0 * SX, 5.0, (ytop + 0.3 - Ys - S1) / 4.51, 0.2, WARM_STONE, 2.4)
	var ridge := _gable_x(b, -EX - 0.1, EX + 0.1, zb - 0.22, zs + 0.3, ytop + 0.3, {"Stone_01": "Stucco_Red_01"})
	_p(b, "SM_Prop_Statue_04", Vector3(0, ridge - 0.1, (zb + zs) * 0.5 + 0.05), 0.0, Vector3.ONE * 0.24, GOLD_STATUE)
	# бока: пилястры, расписной фриз, медальон, знамя
	for sd: float in [-1.0, 1.0]:
		for z: float in [zb + 0.12, (zb + zp) * 0.5, zp - 0.06]:
			_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(sd * (EX + 0.06), Y0, z), 0.0, Vector3(0.2, (ytop - Y0) / 4.55, 0.3), WARM_STONE)
		var xs := sd * (EX + 0.1)
		if sd > 0:
			_run(b, "SM_Bld_Trim_Large_Single_02", Vector3(xs, ytop + 0.13, zp), Vector3(0, 0, -1), zp - zb, 2.5, 0.34, 0.6, FRIEZE, 1.5)
		else:
			_run(b, "SM_Bld_Trim_Large_Single_02", Vector3(xs, ytop + 0.13, zb), Vector3(0, 0, 1), zp - zb, 2.5, 0.34, 0.6, FRIEZE, 1.5)
		_p(b, "SM_Bld_Ornament_02", Vector3(xs + sd * 0.02, Y0 + 1.5, (zb + zp) * 0.5 - 0.3), sd * PI / 2, Vector3.ONE * 0.36)
		_p(b, "SM_Prop_Banner_03_C", Vector3(sd * (EX + 0.13), ytop - 0.1, (zb + zp) * 0.5 + 0.3), sd * PI / 2, Vector3(0.45, 0.6, 0.6))
	# на сцене: лира, кресло, жаровни; ночью — огонёк над сценой
	_p(b, "SM_Prop_Plinth_02", Vector3(1.1, Ys, zs + 0.6), 0.0, Vector3(0.55, 0.62, 0.55))
	_p(b, "SM_Prop_Lyre_01", Vector3(1.1, Ys + 0.64, zs + 0.6), 0.0, Vector3.ONE * 0.48)
	_p(b, "SM_Prop_Seat_Chair_01", Vector3(-0.2, Ys, zs + 0.55), 0.0, Vector3.ONE * 0.6)
	for sd: float in [-1.0, 1.0]:
		_bowl(b, Vector3(sd * (SX - 0.35), Ys, zp - 0.25), 0.36)
	b.light(Vector3(0, Ys + 1.4, zs + 0.8))
	b.actor(Vector3(-0.85, Ys, zs + 0.62), 0.25, "Spell_Simple_Idle", "rich")


# =====================================================================
#   библиотека
# =====================================================================

static func _library_dims(fit: Vector2) -> Dictionary:
	var fr := _frame("library", fit)
	var full: bool = fr[4]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	var HX := x1 - (0.45 if full else 0.35)          # стены зала: x ±HX (наружные грани)
	var court := 0.6 if full else 0.32               # мощёный дворик перед лестницей
	var stairs := 0.75 if full else 0.6
	var porch := 1.3 if full else 1.05               # портик: от края подиума до стены
	var HZ1 := z1 - court - stairs - porch           # фасадная стена (лицо)
	var HZ0 := z0 + (0.3 if full else 0.2)           # задняя стена (лицо)
	return {"x0": fr[0], "x1": x1, "z0": z0, "z1": z1, "full": full, "HX": HX, "HZ0": HZ0, "HZ1": HZ1, "PZ": HZ1 + porch,
		"SZ": HZ1 + porch + stairs, "HP": 0.42, "YP": Y0 + 0.42, "H1": 2.55, "E1": 0.3, "H2": 1.75}


static func _library(b: Bp, d: Dictionary) -> void:
	var HX: float = d["HX"]
	var HZ0: float = d["HZ0"]
	var HZ1: float = d["HZ1"]
	var PZ: float = d["PZ"]
	var SZ: float = d["SZ"]
	var YP: float = d["YP"]
	var HP: float = d["HP"]
	var H1: float = d["H1"]
	var E1: float = d["E1"]
	var H2: float = d["H2"]
	var z1: float = d["z1"]
	var y2 := YP + H1 + E1
	var ytop := y2 + H2
	_base(b, d["x0"], d["x1"], d["z0"], d["z1"])
	# подиум: тёсаный камень по бокам и сзади, сверху — узорные плиты портика; лестница во всю ширину
	_ring(b, "SM_Bld_Wall_Large_01", -HX - 0.05, HX + 0.05, HZ0 - 0.05, PZ, Y0 - 0.3, 5.0, (HP + 0.3) / 4.51, 0.3, {}, [1, 2, 3], 2.0)
	_floor(b, TILES, -HX - 0.05, HZ1, HX + 0.05, PZ, YP + 0.003, 1.6)
	var ns := maxi(1, int(ceil(2.0 * (HX + 0.05) / 2.5)))
	var sw := 2.0 * (HX + 0.05) / ns
	for i in ns:
		_p(b, "SM_Bld_Stairs_01", Vector3(-HX - 0.05 + i * sw, Y0, SZ), 0.0, Vector3(sw / 2.5, HP / 1.5, (SZ - PZ) / 2.5))
	# зал: стены — тёплый песок, фасад — мрамор
	var mw := 2.0 * HX / 3.0
	var sy1 := H1 / 3.01
	_facade(b, ["SM_Bld_Wall_Window_05", "SM_Bld_Wall_Door_Large_01", "SM_Bld_Wall_Window_05"], -HX, HZ1, YP, mw, H1, MARBLE)
	_facade(b, ["SM_Bld_Wall_Alcove_01", "SM_Bld_Wall_Window_05", "SM_Bld_Wall_Alcove_01"], -HX, HZ1, y2, mw, H2, MARBLE)
	# между ярусами снаружи — пояс (мраморная плита по всему периметру)
	var depth := HZ1 - HZ0
	var nside := maxi(2, int(round(depth / 1.6)))
	var sm := depth / nside
	for sd: float in [-1.0, 1.0]:
		var x := sd * HX
		for i in nside:
			var z := (HZ0 + i * sm) if sd < 0 else (HZ1 - i * sm)
			var yw := PI / 2 * sd
			# низ — окна в тёплый зал (под ними ящики с цветами), пояс, верх — окна со ставнями
			_p(b, "SM_Bld_Wall_Window_05", Vector3(x - sd * 0.28, YP, z), yw, Vector3(sm / 2.5, sy1, 1.0), SAND)
			var wc := z - 1.25 * sm / 2.5 if sd > 0 else z + 1.25 * sm / 2.5
			var kb := minf(0.9, 1.25 * sm / 2.5)
			_p(b, "#window_box", Vector3(x, YP + 0.62 * sy1, wc), yw, Vector3(kb, kb, 0.5))
			_p(b, "SM_Bld_Wall_01", Vector3(x - sd * 0.11, YP + H1, z), yw, Vector3(sm / 2.5, E1 / 3.01, 1.0), MARBLE)
			_p(b, "SM_Bld_Wall_Window_05", Vector3(x - sd * 0.28, y2, z), yw, Vector3(sm / 2.5, H2 / 3.01, 1.0), SAND)
			_shutters(b, x, z, sm, sd, y2, H2)
	var nb := 3
	var bm := 2.0 * HX / nb
	for i in nb:
		var x := HX - i * bm
		# зад: внизу — ниши со статуями мудрецов (неглубокие: за ними полки), пояс, вверху — окна со ставнями
		_p(b, "SM_Bld_Wall_Alcove_01", Vector3(x, YP, HZ0 + 0.38 * 0.5), PI, Vector3(bm / 2.5, sy1, 0.5), MARBLE)
		_p(b, "SM_Prop_Statue_0%d" % [7, 5, 3][i], Vector3(x - bm * 0.5, YP + 0.16, HZ0 + 0.12), PI, Vector3.ONE * 0.48)
		_p(b, "SM_Bld_Wall_01", Vector3(x, YP + H1, HZ0 + 0.11), PI, Vector3(bm / 2.5, E1 / 3.01, 1.0), MARBLE)
		_p(b, "SM_Bld_Wall_Window_05", Vector3(x, y2, HZ0 + 0.28), PI, Vector3(bm / 2.5, H2 / 3.01, 1.0), SAND)
		_shutters_back(b, x, HZ0, bm, y2, H2)
	# расписной фриз под карнизом по бокам и сзади, плющ у задних углов, цветы в кадках по углам зала
	var fy := ytop - 0.17
	_run(b, "SM_Bld_Trim_Large_Single_02", Vector3(HX, fy, HZ1), Vector3(0, 0, -1), depth, 2.5, 0.34, 0.6, FRIEZE, 1.6)
	_run(b, "SM_Bld_Trim_Large_Single_02", Vector3(-HX, fy, HZ0), Vector3(0, 0, 1), depth, 2.5, 0.34, 0.6, FRIEZE, 1.6)
	_run(b, "SM_Bld_Trim_Large_Single_02", Vector3(HX, fy, HZ0), Vector3(-1, 0, 0), 2.0 * HX, 2.5, 0.34, 0.6, FRIEZE, 1.6)
	for sd: float in [-1.0, 1.0]:
		_p(b, "SM_Env_Ivy_Flowers_0%d" % (1 if sd < 0 else 3), Vector3(sd * (HX + 0.03), YP + 1.3, HZ0 + 0.55), sd * PI / 2, Vector3.ONE * 0.62)
		_p(b, "SM_Env_Ivy_Flowers_0%d" % (2 if sd < 0 else 4), Vector3(sd * (HX - 0.6), YP + 1.1, HZ0 - 0.03), PI, Vector3.ONE * 0.55)
		for zz: float in [HZ0 + 0.05, HZ1 - 0.05]:
			_p(b, "SM_Prop_FlowerPot_Fancy_01", Vector3(sd * (HX + 0.08), Y0 + 0.57 * 0.24, zz), b.rng.randf() * TAU, Vector3.ONE * 0.24)   # кадка у угла — в следе и при любом повороте
	# пилястры из белого мрамора по углам и между окнами (бока и зад), мраморный пояс между ярусами — не «гладкая коробка»
	var pil := PIL
	for sd: float in [-1.0, 1.0]:
		for i in nside + 1:
			var z := HZ0 + i * sm
			_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(sd * (HX + 0.02), YP, clampf(z, HZ0 + 0.12, HZ1 - 0.05)), 0.0, Vector3(0.24, (ytop - YP) / 4.55, 0.24), pil)
	for i in range(1, nb):
		_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(HX - i * bm, YP, HZ0 - 0.02), 0.0, Vector3(0.24, (ytop - YP) / 4.55, 0.24), pil)
	# фасадная стена между ярусами (за карнизом-портиком)
	_p(b, "SM_Bld_Wall_01", Vector3(-HX, YP + H1, HZ1 - 0.11), 0.0, Vector3(2.0 * HX / 2.5, E1 / 3.01, 1.0), MARBLE)
	# бронзовые створки (Life распахивает их внутрь, в тёплый зал)
	var kx := mw / 2.5
	var lw := 1.2 * kx * 0.5
	var ls := Vector3(lw / 0.56, 2.45 * sy1 / 2.47, 0.8)
	_p(b, "SM_Bld_Door_Large_Half_03", Vector3(-HX + mw + 0.65 * kx, YP, HZ1 - 0.26), 0.0, ls)
	_p(b, "SM_Bld_Door_Large_Half_03", Vector3(-HX + mw + 0.65 * kx + lw, YP, HZ1 - 0.26), 0.0, ls)
	# колонны нижнего яруса: пары у простенков у двери и по одной у углов, на постаментах; карниз-навес портика
	var pier := -HX + mw                                 # середина простенка между окном и дверью
	var cz := PZ - 0.32
	var low := [[pier - 0.28, pier + 0.28], [-pier - 0.28, -pier + 0.28], [-HX + 0.32], [HX - 0.32]]
	var colx := []
	for g: Array in low:
		for x: float in g:
			colx.append(x)
	for x: float in colx:
		_p(b, "SM_Prop_Plinth_04", Vector3(x, YP, cz), 0.0, Vector3(0.52, 0.5, 0.52))
		_p(b, "SM_Bld_Pillar_04", Vector3(x, YP + 0.34, cz), 0.0, Vector3(0.56, (H1 - 0.34) / 3.0, 0.56))
	_ledge(b, -HX - 0.12, HX + 0.12, HZ1 - 0.05, cz + 0.36, YP + H1, E1)
	# верхний ярус: тонкие колонны над нижними, у края карниза; статуи добродетелей в нишах; карниз, аттик
	for x: float in colx:
		_p(b, "SM_Bld_Pillar_06", Vector3(x, y2, HZ1 + 0.42), 0.0, Vector3(0.52, H2 / 3.0, 0.52))
	for i: int in [0, 2]:
		_p(b, "SM_Prop_Statue_0%d" % [7, 5][i / 2], Vector3(-HX + (i + 0.5) * mw, y2 + 0.1, HZ1 - 0.22), 0.0, Vector3.ONE * 0.5)
	_ledge(b, -HX - 0.12, HX + 0.12, HZ0 - 0.12, HZ1 + 0.62, ytop, 0.28)
	_ring(b, "SM_Bld_Wall_Tiny_01", -HX + 0.05, HX - 0.05, HZ0 + 0.05, HZ1 + 0.42, ytop + 0.28, 2.5, 1.2, 1.2, MARBLE, [0, 1, 2, 3], 2.0)
	# фронтон над серединой фасада (синий тимпан, золотой медальон) и плоская кровля зала за аттиком (черепица)
	var pr := _gable_z(b, -mw * 0.62, mw * 0.62, HZ1 - 0.35, HZ1 + 0.6, ytop + 0.28, TYMPANUM, true, true)
	_p(b, "SM_Bld_Ornament_02", Vector3(0, ytop + 0.28 + (pr - ytop - 0.28) * 0.4, HZ1 + 0.56), 0.0, Vector3.ONE * 0.32)
	_p(b, "SM_Prop_Statue_04", Vector3(0, pr - 0.08, HZ1 + 0.5), 0.0, Vector3.ONE * 0.24, GOLD_STATUE)
	for sd: float in [-1.0, 1.0]:
		_p(b, "SM_Prop_Statue_0%d" % (3 if sd < 0 else 6), Vector3(sd * (HX - 0.2), ytop + 0.28, HZ1 + 0.3), 0.0, Vector3.ONE * 0.3)
	_gable_x(b, -HX + 0.1, HX - 0.1, HZ0 + 0.1, HZ1 - 0.35, ytop + 0.12, {"Stone_01": "Stucco_Orange_01"})
	_library_hall(b, d)
	# дворик: цветники у лестницы, мраморные скамьи (на них присаживаются жители), фонари
	var x1: float = d["x1"]
	for sd: float in [-1.0, 1.0]:
		if bool(d["full"]):
			_p(b, "SM_Prop_FlowerBed_01", Vector3(sd * (x1 - 1.15), Y0 + 0.17, z1 - 0.44), 0.0, Vector3.ONE * 0.46)
			_p(b, "SM_Prop_Seat_Bench_03", Vector3(sd * 2.1, Y0, z1 - 0.32), 0.0, Vector3.ONE * 0.5)
			_cypress(b, Vector3(sd * (x1 - 0.28), Y0, z1 - 0.3), 0.36)
		else:
			_p(b, "SM_Prop_FlowerPot_Fancy_01", Vector3(sd * (x1 - 0.3), Y0 + 0.57 * 0.3, SZ - 0.2), b.rng.randf() * TAU, Vector3.ONE * 0.3)
		_bush(b, Vector3(sd * (x1 - 0.34), Y0, (HZ0 + HZ1) * 0.5), 0.26)       # куст — внутри следа (у старого места бок — 0,35 м)
	b.door = Vector3(0, 0, z1 + 0.35)


## Ставни (Life): две дощатые створки по бокам окна второго яруса на боковой стене (sd — какая сторона)
static func _shutters(b: Bp, x: float, z: float, sm: float, sd: float, y2: float, H2: float) -> void:
	var sx := sm / 2.5
	var sy := H2 / 3.01
	var yw := PI / 2 * sd
	var bs := Basis(Vector3.UP, yw)
	for e: Array in CatDressCivic._shutter_pair("#shutters_green", sx, sy):
		var lx: Transform3D = e[1]
		# окно Synty: середина на 1,25 вдоль стены, подоконник на 0,65 (CatDress.WIN) — створки на лице стены
		var at := Vector3(x + sd * 0.012, y2 + 0.7 * sy, z) + bs * Vector3(1.25 * sx + lx.origin.x, 0, 0.0)
		b.parts.append([e[0], b.base * Transform3D(bs * lx.basis, at), e[2]])


## Ставни на окне второго яруса задней стены (лицом к −Z): окно — модуль bm от x вниз по X
static func _shutters_back(b: Bp, x: float, z: float, bm: float, y2: float, H2: float) -> void:
	var sx := bm / 2.5
	var sy := H2 / 3.01
	var bs := Basis(Vector3.UP, PI)
	for e: Array in CatDressCivic._shutter_pair("#shutters_green", sx, sy):
		var lx: Transform3D = e[1]
		var at := Vector3(x, y2 + 0.7 * sy, z - 0.012) + bs * Vector3(1.25 * sx + lx.origin.x, 0, 0.0)
		b.parts.append([e[0], b.base * Transform3D(bs * lx.basis, at), e[2]])


## Читальный зал: облицовка в тёплом свете, полки со свитками по задней и боковым стенам, Минерва посредине задней
## стены, два стола со свитками и стульями, бюсты на постаментах, светильники; ночью — огонёк
static func _library_hall(b: Bp, d: Dictionary) -> void:
	var HX: float = d["HX"]
	var HZ0: float = d["HZ0"]
	var HZ1: float = d["HZ1"]
	var YP: float = d["YP"]
	var H1: float = d["H1"]
	var E1: float = d["E1"]
	var H2: float = d["H2"]
	var ix := HX - 0.25
	var iz0 := HZ0 + 0.25
	var iz1 := HZ1 - 0.62
	var h := H1 + E1 + H2
	var mw := 2.0 * HX / 3.0
	var kx := mw / 2.5
	var door := [-0.6 * kx * 1.0 - 0.02, 0.6 * kx + 0.02]
	var win := [[-HX + (1.25 - 0.62) * kx, -HX + (1.25 + 0.62) * kx], door, [HX - (1.25 + 0.62) * kx, HX - (1.25 - 0.62) * kx]]
	var depth := HZ1 - HZ0
	var nside := maxi(2, int(round(depth / 1.6)))
	var sm := depth / nside
	var side := []
	for i in nside:
		var zc := HZ0 + (i + 0.5) * sm
		var hw := 0.6 * sm / 2.5 + 0.02
		if zc - hw > iz0 and zc + hw < iz1:
			side.append([zc - hw, zc + hw])
	_lining(b, -ix, ix, iz0, iz1, YP, h, win, side)
	_floor(b, HALL_FLOOR, -ix, iz0, ix, iz1, YP + 0.006, 1.9)
	_ceiling(b, -ix, iz0, ix, iz1, YP + h - 0.04)
	# полки со свитками: по задней стене — две по бокам от Минервы, по боковым — по одной
	var shelf := {"glow": WARM * 0.45}
	var sw := minf(2.3, (2.0 * ix - 1.4) * 0.5)
	var sh := 0.78
	for sd: float in [-1.0, 1.0]:
		var x0 := sd * 0.7 if sd > 0 else -0.7 - sw
		_p(b, "SM_Bld_Shelf_Scroll_01", Vector3(x0, YP, iz0 + 0.23), 0.0, Vector3(sw / 2.5, sh, 0.6), shelf)
		_p(b, "SM_Bld_Shelf_Scroll_01_Insert_0%d" % (1 if sd < 0 else 2), Vector3(x0, YP, iz0 + 0.23), 0.0, Vector3(sw / 2.5, sh, 0.6), shelf)
	# Минерва на постаменте между полками
	_p(b, "SM_Prop_Plinth_04", Vector3(0, YP, iz0 + 0.6), 0.0, Vector3(0.62, 0.6, 0.62), {"glow": WARM * 0.5})
	_p(b, "SM_Prop_Statue_07", Vector3(0, YP + 0.41, iz0 + 0.6), 0.0, Vector3.ONE * 0.72, {"tints": {"Statue_01": GOLD}, "glow": WARM * 0.8})
	# столы со свитками и стулья
	var tz := (iz0 + iz1) * 0.5 + 0.15
	for sd: float in [-1.0, 1.0]:
		var tx := sd * minf(1.45, ix * 0.42)
		_p(b, "SM_Prop_Table_01", Vector3(tx, YP, tz), 0.0, Vector3(0.62, 0.62, 0.62), {"glow": WARM * 0.4})
		_p(b, "SM_Prop_Scroll_Pile_0%d" % (1 if sd < 0 else 3), Vector3(tx - 0.18, YP + 0.48, tz), 0.4, Vector3.ONE * 0.36, {"glow": WARM * 0.4})
		_p(b, "SM_Prop_Scroll_01", Vector3(tx + 0.25, YP + 0.49, tz + 0.04), 1.3, Vector3.ONE * 0.6, {"glow": WARM * 0.4})
		for cz: float in [-0.42, 0.42]:
			_p(b, "SM_Prop_Seat_Chair_01", Vector3(tx + 0.1, YP, tz + cz), 0.0 if cz < 0 else PI, Vector3.ONE * 0.55, {"glow": WARM * 0.4})
	# бюсты на постаментах у передней стены, светильники-курильницы
	for sd: float in [-1.0, 1.0]:
		var bx := sd * (ix - 0.32)
		_p(b, "SM_Prop_Plinth_02", Vector3(bx, YP, iz1 - 0.35), 0.0, Vector3(0.6, 0.72, 0.6), {"glow": WARM * 0.5})
		_p(b, "SM_Prop_Statue_05", Vector3(bx, YP + 0.72, iz1 - 0.35), PI, Vector3.ONE * 0.3, {"glow": WARM * 0.6})
		_p(b, "SM_Prop_Senser_01", Vector3(sd * 0.75, YP, iz1 - 0.3), 0.0, Vector3.ONE * 0.5, {"glow": WARM * 0.6})
	b.light(Vector3(0, YP + 1.6, (iz0 + iz1) * 0.5))
	b.actor(Vector3(-0.45, YP, tz - 0.42), 0.0, "Sitting_Idle", "rich")


# =====================================================================
#   большие термы
# =====================================================================

static func _thermae_dims(fit: Vector2) -> Dictionary:
	var full: Vector2 = FULL["thermae"]
	var dz := 0.0
	var pave := [-full.x * 0.5, full.x * 0.5, -full.y * 0.5, full.y * 0.5]
	if fit != Vector2.ZERO:
		var o: Array = OLD_RECT["thermae"]
		dz = (float(o[2]) + float(o[3])) * 0.5           # новые термы — посреди прежнего следа
		pave = o.duplicate()
	var x1 := full.x * 0.5
	var z0 := dz - full.y * 0.5
	var z1 := dz + full.y * 0.5
	var BZ0 := z0 + 0.3                       # банный корпус: задняя грань
	var BZ1 := dz - 0.5                       # передняя грань (к палестре)
	var FZ := z1 - 0.28                       # передняя стенка палестры (лицо)
	var s := 0.8                              # бортики бассейнов (Synty Bath_Edge) — в 0,8 натуры: модуль 2 м
	var pools := [[-3.0, 3.0, dz + 0.75, dz + 2.75, "out"], [-2.0, 2.0, BZ0 + 1.0, BZ0 + 3.0, "in"]]
	return {"x1": x1, "z0": z0, "z1": z1, "dz": dz, "pave": pave, "full": fit == Vector2.ZERO, "BZ0": BZ0, "BZ1": BZ1, "FZ": FZ,
		"CX": 2.4, "HC": 3.0, "WX": 5.7, "HW": 2.3, "s": s, "pools": pools, "wy": Y0 + 0.1, "zd": float(pave[3]) + 0.35}


static func _thermae(b: Bp, d: Dictionary) -> void:
	var pv: Array = d["pave"]
	_base(b, pv[0], pv[1], pv[2], pv[3])
	_thermae_block(b, d)
	_palaestra(b, d)
	var x1: float = d["x1"]
	var BZ0: float = d["BZ0"]
	# топка у задней стены: дым из печи, поленья
	var fx := 3.2
	b.free_parts[b.parts.size()] = true
	_p(b, "SM_Prop_Kiln_01", Vector3(fx, Y0, BZ0 - 0.05), PI, Vector3.ONE * 0.5)
	b.smoke.append(b.base * Vector3(fx, 1.6, BZ0 - 0.1))
	for k in 2:
		b.free_parts[b.parts.size()] = true
		_p(b, "SM_Prop_Beam_01", Vector3(fx - 0.9, Y0 + 0.04 + k * 0.08, BZ0 - 0.12 + k * 0.03), PI / 2 + 0.05 * k, Vector3.ONE * 0.32)
	for sd: float in [-1.0, 1.0]:
		_p(b, "SM_Env_Tree_Palm_0%d" % (1 if sd < 0 else 2), Vector3(sd * (x1 - 0.35), Y0, BZ0 + 0.1), b.rng.randf() * TAU, Vector3.ONE * 0.3)
	b.door = Vector3(0, 0, float(d["zd"]))


## Банный корпус: кальдарий — зал из римского кирпича с большой аркой к палестре, за ней тёплое нутро с горячим
## бассейном и паром; над залом — барабан и свинцовый купол; по бокам — крылья (красный низ, белый верх) с окнами
## в тёплые комнаты и малыми куполами на плоских крышах
static func _thermae_block(b: Bp, d: Dictionary) -> void:
	var BZ0: float = d["BZ0"]
	var BZ1: float = d["BZ1"]
	var CX: float = d["CX"]
	var HC: float = d["HC"]
	var WX: float = d["WX"]
	var HW: float = d["HW"]
	# раскраски — те же, что у других построек города (общие группы пула: меньше вызовов отрисовки, Parts)
	var brick := {}
	var white := MARBLE
	var depth := BZ1 - BZ0
	# кальдарий: фасад — большая арка во всю ширину, бока и зад — кирпич
	var aw := 2.0 * CX
	_p(b, "SM_Bld_Wall_Door_Double_Large_01", Vector3(-CX, Y0, BZ1 - 0.22 * 0.6), 0.0, Vector3(aw / 2.5, HC / 3.01, 0.6), brick)
	# зад кальдария: две высокие арки — за ними тёплый зал (облицовка в свете), пилястры по краям и посредине
	for i in 2:
		_p(b, "SM_Bld_Wall_Door_Double_01", Vector3(CX - i * CX, Y0, BZ0 + 0.12), PI, Vector3(CX / 2.5, HC / 3.01, 0.5), WARM_STONE)
		_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(CX - i * CX, Y0, BZ0 - 0.03), 0.0, Vector3(0.22, HC / 4.55, 0.16), PIL)
	_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(-CX, Y0, BZ0 - 0.03), 0.0, Vector3(0.22, HC / 4.55, 0.16), PIL)
	for sd: float in [-1.0, 1.0]:
		_run(b, "SM_Bld_Wall_Large_01", Vector3(sd * CX, Y0 - 0.3, BZ1 if sd > 0 else BZ0), Vector3(0, 0, -1) if sd > 0 else Vector3(0, 0, 1), BZ1 - BZ0, 5.0, (HC + 0.3) / 4.51, 0.3, WARM_STONE, 2.4)
	_ring(b, "SM_Bld_Wall_Large_Cap_01", -CX - 0.06, CX + 0.06, BZ0 - 0.06, BZ1 + 0.06, Y0 + HC - 0.02, 5.02, 0.6, 0.45, {}, [0, 1, 2, 3], 2.4)
	_floor(b, PAVING, -CX, BZ0, CX, BZ1, Y0 + HC + 0.1, 2.4)
	# нутро кальдария: облицовка, мозаика, потолок — в тёплом свете; горячий бассейн, статуя, светильники
	var ix := CX - 0.18
	_lining(b, -ix, ix, BZ0 + 0.3, BZ1 - 0.16, Y0, HC - 0.06, [[-CX + 0.15, CX - 0.15]])
	_floor(b, HALL_FLOOR, -ix, BZ0 + 0.18, ix, BZ1 - 0.1, Y0 + 0.006, 1.7)
	_ceiling(b, -ix, BZ0 + 0.18, ix, BZ1 - 0.1, Y0 + HC - 0.1)
	_p(b, "SM_Prop_Plinth_04", Vector3(0, Y0, BZ0 + 0.56), 0.0, Vector3(0.55, 0.5, 0.55), {"glow": WARM * 0.5})
	_p(b, "SM_Prop_Statue_06", Vector3(0, Y0 + 0.34, BZ0 + 0.56), 0.0, Vector3.ONE * 0.62)
	for sd: float in [-1.0, 1.0]:
		_p(b, "SM_Prop_Senser_01", Vector3(sd * (ix - 0.3), Y0, BZ1 - 0.45), 0.0, Vector3.ONE * 0.55, {"glow": WARM * 0.6})
	b.light(Vector3(0, 1.6, BZ1 - 0.9))
	# барабан и купол (свинец); колонны беседки Synty спрятаны в барабане
	var dr := minf(CX, depth * 0.5) - 0.35
	var zc := (BZ0 + BZ1) * 0.5
	var ky := 0.42
	var yd := Y0 + HC + 0.1
	var hd := 3.6 * ky + 0.1
	for i in 10:
		var ang := i * TAU / 10.0
		_on_arc(b, "SM_Bld_Wall_Tiny_01", Vector3(0, 0, zc), ang, dr, yd, 2.0 * dr * tan(PI / 10.0) + 0.06, 2.5, hd / 0.31, 1.2, white)
	_on_arc_ring_cap(b, Vector3(0, 0, zc), dr + 0.05, yd + hd - 0.02, 10)
	var ks := (2.0 * dr + 0.2) / 5.12
	_p(b, "SM_Prop_Pergola_01", Vector3(0, yd + hd - 3.6 * ky, zc), 0.0, Vector3(ks, ky, ks), DOME)
	# крылья
	for sd: float in [-1.0, 1.0]:
		var xa := sd * CX
		var xb := sd * WX
		var lo := minf(xa, xb)
		var hi := maxf(xa, xb)
		var w := hi - lo
		var wz0 := BZ0 + 0.3
		var wz1 := BZ1 - 0.25
		var red := TERRA
		# фасад крыла: окно, окно (за ними — тёплые комнаты), низ красный
		_facade(b, ["SM_Bld_Wall_Window_05", "SM_Bld_Wall_Window_05"], lo, wz1, Y0, w * 0.5, HW, red)
		# наружный бок и зад крыла — окна в тёплые комнаты, пилястры по углам и между окнами
		var sl := (wz1 - wz0) * 0.5
		for i in 2:
			var zz := (wz1 - i * sl) if sd > 0 else (wz0 + i * sl)
			_p(b, "SM_Bld_Wall_Window_05", Vector3(xb + sd * (0.11 - 0.28 * 0.6), Y0, zz), PI / 2 * sd, Vector3(sl / 2.5, HW / 3.01, 0.6), red)
			_p(b, "SM_Bld_Wall_Window_05", Vector3(hi - i * w * 0.5, Y0, wz0 + 0.28 * 0.6), PI, Vector3(w * 0.5 / 2.5, HW / 3.01, 0.6), red)
		for zz: float in [wz0 + 0.04, (wz0 + wz1) * 0.5, wz1 - 0.04]:
			_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(xb + sd * 0.13, Y0, zz), 0.0, Vector3(0.16, HW / 4.55, 0.2), PIL)
		for xx: float in [lo + 0.04, (lo + hi) * 0.5, hi - 0.04]:
			_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(xx, Y0, wz0 - 0.03), 0.0, Vector3(0.2, HW / 4.55, 0.16), PIL)
		_ring(b, "SM_Bld_Wall_Large_Cap_01", lo - 0.04, hi + 0.04, wz0 - 0.06, wz1 + 0.06, Y0 + HW - 0.02, 5.02, 0.45, 0.4, {}, [0, 1, 2, 3], 2.0)
		_floor(b, PAVING, lo, wz0, hi, wz1, Y0 + HW + 0.1, 2.0)
		_lining(b, lo + 0.15, hi - 0.15, wz0 + 0.15, wz1 - 0.12, Y0, HW - 0.05, [[lo + 0.2, hi - 0.2]])
		_floor(b, HALL_FLOOR, lo + 0.15, wz0 + 0.15, hi - 0.15, wz1 - 0.1, Y0 + 0.006, 1.8)
		_ceiling(b, lo + 0.15, wz0 + 0.15, hi - 0.15, wz1 - 0.1, Y0 + HW - 0.08)
		_p(b, "SM_Prop_Seat_Bench_03", Vector3((lo + hi) * 0.5, Y0, wz0 + 0.45), 0.0, Vector3.ONE * 0.5)
		_p(b, "SM_Prop_Vase_Pile_02", Vector3((lo + hi) * 0.5 + sd * 0.9, Y0, wz0 + 0.4), 0.0, Vector3.ONE * 0.4)
		# малый купол на барабане
		var mc := Vector3((lo + hi) * 0.5, 0, (wz0 + wz1) * 0.5)
		var mr := 0.62
		var mky := 0.2
		var ymd := Y0 + HW + 0.1
		var mh := 3.6 * mky + 0.06
		for i in 8:
			_on_arc(b, "SM_Bld_Wall_Tiny_01", mc, i * TAU / 8.0, mr, ymd, 2.0 * mr * tan(PI / 8.0) + 0.05, 2.5, mh / 0.31, 1.0, white)
		var mks := (2.0 * mr + 0.14) / 5.12
		_p(b, "SM_Prop_Pergola_01", mc + Vector3(0, ymd + mh - 3.6 * mky, 0), 0.0, Vector3(mks, mky, mks), DOME)
		# парапет по краю плоской крыши
		_ring(b, "SM_Bld_Wall_Tiny_01", lo + 0.05, hi - 0.05, wz0 + 0.05, wz1 - 0.05, Y0 + HW + 0.1, 2.5, 1.0, 1.0, white, [0, 1, 2] if sd > 0 else [0, 2, 3], 2.0)


static func _on_arc_ring_cap(b: Bp, c: Vector3, r: float, y: float, n: int) -> void:
	for i in n:
		_on_arc(b, "SM_Bld_Wall_Large_Cap_01", c, i * TAU / n, r, y, 2.0 * r * tan(PI / n) + 0.08, 5.02, 0.5, 0.4)


## Палестра: бассейн под открытым небом с бортиками и ступенями, вокруг мозаика; по бокам — колоннады под черепицей
## со скамьями; спереди — низкая стена и пропилей: две колонны, фронтон, бронзовые двери (Life распахивает их во двор);
## статуи у бассейна, пальмы, цветы, чаши огня
static func _palaestra(b: Bp, d: Dictionary) -> void:
	var dz: float = d["dz"]
	var x1: float = d["x1"]
	var BZ1: float = d["BZ1"]
	var FZ: float = d["FZ"]
	var s: float = d["s"]
	var wy: float = d["wy"]
	for pl: Array in d["pools"]:
		_pool(b, pl[0], pl[1], pl[2], pl[3], s, wy, String(pl[4]) == "out")
	var po: Array = (d["pools"] as Array)[0]
	_floor(b, MOSAIC, float(po[0]) - 0.6, float(po[2]) - 0.6, float(po[1]) + 0.6, float(po[3]) + 0.6, Y0 + 0.003, 2.0)
	# колоннады по бокам
	var cx := x1 - 0.85
	var z_a := BZ1 + 0.35
	var z_b := FZ - 0.35
	for sd: float in [-1.0, 1.0]:
		for i in 4:
			_p(b, "SM_Bld_Pillar_02", Vector3(sd * cx, Y0, lerpf(z_a, z_b, i / 3.0)), 0.0, Vector3(0.62, 0.75, 0.62))
		var wx := sd * (x1 - 0.15)
		# наружная стена колоннады: ниша со статуей — окно — ниша со статуей, пилястры между ними
		var L := z_b - z_a + 0.4
		var cm := L / 3.0
		var xf := sd * (x1 - 0.04)
		for i in 3:
			var zz := (z_b + 0.2 - i * cm) if sd > 0 else (z_a - 0.2 + i * cm)
			var nm := "SM_Bld_Wall_Window_05" if i == 1 else "SM_Bld_Wall_Alcove_01"
			var szk := 0.6 if i == 1 else 0.5
			_p(b, nm, Vector3(xf - sd * float(FACE[nm]) * szk, Y0, zz), PI / 2 * sd, Vector3(cm / 2.5, 2.6 / 3.01, szk), TERRA if i == 1 else MARBLE)
			if i != 1:
				var zc := zz - cm * 0.5 if sd > 0 else zz + cm * 0.5
				_p(b, "SM_Prop_Statue_0%d" % ([6, 7][i / 2] if sd > 0 else [3, 5][i / 2]), Vector3(xf - sd * 0.12, Y0 + 0.14, zc), PI / 2 * sd, Vector3.ONE * 0.5)
		for i in 4:
			var zz := lerpf(z_a - 0.2, z_b + 0.2, i / 3.0)
			_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(xf + sd * 0.02, Y0, clampf(zz, z_a - 0.12, z_b + 0.12)), 0.0, Vector3(0.16, 2.6 / 4.55, 0.2), PIL)
		_run(b, "SM_Bld_Wall_Large_Cap_01", Vector3(xf - sd * 0.12, Y0 + 2.58, z_b + 0.2) if sd > 0 else Vector3(xf - sd * 0.12, Y0 + 2.58, z_a - 0.2), Vector3(0, 0, -1) if sd > 0 else Vector3(0, 0, 1), L, 5.02, 0.4, 0.4, {}, 2.2)
		var kr := (x1 + 0.1 - cx + 0.25) / 7.5
		var eave := Y0 + 2.25
		if sd > 0:
			_p(b, "SM_Bld_Roof_Straight_Thin_Large_01", Vector3(cx - 0.25, eave, z_a - 0.25), -PI / 2, Vector3((z_b - z_a + 0.5) / 7.5, kr, kr))
		else:
			_p(b, "SM_Bld_Roof_Straight_Thin_Large_01", Vector3(-cx + 0.25, eave, z_b + 0.25), PI / 2, Vector3((z_b - z_a + 0.5) / 7.5, kr, kr))
		_p(b, "SM_Prop_Seat_Bench_03", Vector3(sd * (x1 - 0.5), Y0, (z_a + z_b) * 0.5), -sd * PI / 2, Vector3.ONE * 0.5)
		# статуи у углов бассейна, чаши огня, пальмы и цветы
		_p(b, "SM_Prop_Plinth_04", Vector3(sd * (float(po[1]) + 0.45), Y0, float(po[3]) + 0.45), 0.0, Vector3(0.5, 0.45, 0.5))
		_p(b, "SM_Prop_Statue_0%d" % (3 if sd < 0 else 5), Vector3(sd * (float(po[1]) + 0.45), Y0 + 0.31, float(po[3]) + 0.45), 0.0, Vector3.ONE * 0.5)
		_p(b, "SM_Env_Tree_Palm_0%d" % (3 if sd < 0 else 1), Vector3(sd * (cx - 0.75), Y0, z_a + 0.1), b.rng.randf() * TAU, Vector3.ONE * 0.27)
		_bush(b, Vector3(sd * (cx - 0.6), Y0, z_b - 0.1), 0.34)
		_p(b, "SM_Prop_FlowerPot_Fancy_01", Vector3(sd * 1.8, Y0 + 0.57 * 0.4, float(po[2]) - 0.5), b.rng.randf() * TAU, Vector3.ONE * 0.4)
	# передняя стенка и пропилей
	var gw := 2.5
	for sd: float in [-1.0, 1.0]:
		var xa := sd * gw * 0.5
		var xb := sd * (x1 - 0.15)
		var lo := minf(xa, xb)
		var hi := maxf(xa, xb)
		_run(b, "SM_Bld_Wall_Large_01", Vector3(lo, Y0 - 0.3, FZ - 0.34 * 0.3), Vector3(1, 0, 0), hi - lo, 5.0, 1.45 / 4.51, 0.3, {}, 2.2)
		_run(b, "SM_Bld_Wall_Large_Cap_01", Vector3(lo, Y0 + 1.1, FZ - 0.1), Vector3(1, 0, 0), hi - lo, 5.02, 0.5, 0.4, {}, 2.2)
		_p(b, "SM_Prop_FlowerPot_Fancy_01", Vector3(sd * (gw * 0.5 + 1.6), Y0 + 0.57 * 0.26, FZ + 0.13), b.rng.randf() * TAU, Vector3.ONE * 0.26)
	var syd := 2.5 / 3.01
	_p(b, "SM_Bld_Wall_Door_Large_01", Vector3(-gw * 0.5, Y0, FZ - 0.3 * 0.5), 0.0, Vector3(gw / 2.5, syd, 0.5), WHITE)
	var lw := 1.2 * (gw / 2.5) * 0.5
	var ls := Vector3(lw / 0.56, 2.45 * syd / 2.47, 0.8)
	_p(b, "SM_Bld_Door_Large_Half_03", Vector3(-gw * 0.5 + 0.65 * gw / 2.5, Y0, FZ - 0.05), 0.0, ls)
	_p(b, "SM_Bld_Door_Large_Half_03", Vector3(-gw * 0.5 + 0.65 * gw / 2.5 + lw, Y0, FZ - 0.05), 0.0, ls)
	var pz := FZ + 0.08
	for sd: float in [-1.0, 1.0]:
		_p(b, "SM_Bld_Pillar_02", Vector3(sd * 1.45, Y0, pz), 0.0, Vector3(0.62, 0.86, 0.62))
	_ledge(b, -1.75, 1.75, FZ - 0.35, pz + 0.32, Y0 + 2.58, 0.26)
	var pr := _gable_z(b, -1.8, 1.8, FZ - 0.4, pz + 0.38, Y0 + 2.86, TYMPANUM, true, true)
	_p(b, "SM_Bld_Ornament_02", Vector3(0, Y0 + 2.86 + (pr - Y0 - 2.86) * 0.4, pz + 0.34), 0.0, Vector3.ONE * 0.34)
	_p(b, "SM_Prop_Statue_04", Vector3(0, pr - 0.08, pz + 0.3), 0.0, Vector3.ONE * 0.24, GOLD_STATUE)
	_bowl(b, Vector3(-2.0, Y0, FZ + 0.12), 0.32)
	_bowl(b, Vector3(2.0, Y0, FZ + 0.12), 0.32)
	b.light(Vector3(0, 1.6, FZ + 0.4))
	# люди при деле: служитель у входа, банщик с полотенцами у бассейна, атлет в палестре
	b.actor(Vector3(0.9, Y0, FZ + 0.35), 0.0, "Idle", "pleb")
	_p(b, "SM_Prop_Rug_Folded_03", Vector3(float(po[1]) - 0.4, Y0 + 0.003, float(po[3]) + 0.42), 0.0, Vector3.ONE * 0.45)
	b.actor(Vector3(float(po[1]) - 0.4, Y0, float(po[3]) + 0.75), PI, "Interact", "any")
	b.actor(Vector3(-cx + 0.7, Y0, (z_a + z_b) * 0.5), PI / 2, "Idle_Talking", "any")


## Бассейн x0..x1 × z0..z1 (кратно 2,5·s): вода «#water» (верх — wy), бортики, углы; stairs — ступени у переднего края
static func _pool(b: Bp, x0: float, x1: float, z0: float, z1: float, s: float, wy: float, stairs: bool) -> void:
	var m := 2.5 * s
	var nx := int(round((x1 - x0) / m))
	var nz := int(round((z1 - z0) / m))
	b.parts.append(["#water", b.base * Transform3D(Basis.from_scale(Vector3(x1 - x0, 0.12, z1 - z0)), Vector3((x0 + x1) * 0.5, wy - 0.06, (z0 + z1) * 0.5)), {}])
	var ks := Vector3.ONE * s
	for i in nx:
		_p(b, "SM_Bld_Bath_Edge_01", Vector3(x0 + i * m, Y0, z1), 0.0, ks)
		_p(b, "SM_Bld_Bath_Edge_01", Vector3(x0 + (i + 1) * m, Y0, z0), PI, ks)
	for j in nz:
		_p(b, "SM_Bld_Bath_Edge_01", Vector3(x1, Y0, z1 - j * m), PI / 2, ks)
		_p(b, "SM_Bld_Bath_Edge_01", Vector3(x0, Y0, z0 + j * m), -PI / 2, ks)
	for c: Vector3 in [Vector3(x0, Y0, z0), Vector3(x1, Y0, z0), Vector3(x0, Y0, z1), Vector3(x1, Y0, z1)]:
		_p(b, "SM_Bld_Bath_Corner_01", c, 0.0, ks)
	if stairs:
		_p(b, "SM_Bld_Bath_Stairs_01", Vector3((x0 + x1) * 0.5, Y0, z1 - 0.08), PI, ks)


## Купальщики (Spectacle «bath»): в каждом бассейне — по грудь в воде; путь — с улицы через пропилей во двор, к своему
## бассейну (во внутренний — мимо открытого бассейна, через большую арку кальдария), у края — вниз в воду
static func _bath_seats(sp, lay: Dictionary, d: Dictionary) -> void:
	var seats_a: Array = lay["seats"]
	var wy: float = d["wy"]
	var FZ: float = d["FZ"]
	var BZ1: float = d["BZ1"]
	var zd: float = d["zd"]
	var po: Array = (d["pools"] as Array)[0]
	if not lay.has("fx"):
		lay["fx"] = []
	var list := []
	for pl: Array in d["pools"]:
		var x0: float = pl[0]
		var x1: float = pl[1]
		var z0: float = pl[2]
		var z1: float = pl[3]
		var inner := String(pl[4]) == "in"
		var sx := x1 - x0
		var sz := z1 - z0
		var c := Vector3((x0 + x1) * 0.5, 0, (z0 + z1) * 0.5)
		(lay["fx"] as Array).append(["steam", Vector3(c.x, wy + 0.05, c.z), Vector3(sx, 0, sz)])
		var nx := maxi(1, int(floor((sx - 0.5) / 0.5)))
		var nz := maxi(1, int(floor((sz - 0.5) / 0.55)))
		for i in nx:
			for j in nz:
				var w := Vector3(x0 + 0.25 + (i + 0.5) * (sx - 0.5) / nx, 0, z0 + 0.25 + (j + 0.5) * (sz - 0.5) / nz)
				var root := Vector3(w.x, wy - Spectacle.BATH_DEPTH, w.z)
				var path := PackedVector3Array([Vector3(0, 0, zd), Vector3(0, Y0, FZ + 0.1), Vector3(0, Y0, FZ - 0.5)])
				var side := -1.0 if w.x < 0.0 else 1.0
				if inner:
					# мимо открытого бассейна сбоку, к арке кальдария
					path.append(Vector3(side * (float(po[1]) + 0.9), Y0, float(po[3]) + 0.4))
					path.append(Vector3(side * (float(po[1]) + 0.9), Y0, float(po[2]) - 0.5))
					path.append(Vector3(side * 0.9, Y0, BZ1 + 0.3))
					path.append(Vector3(side * 0.9, Y0, BZ1 - 0.4))
				path.append(Vector3(w.x, Y0, z1 + 0.35))
				path.append(Vector3(w.x, wy - Spectacle.BATH_DEPTH * 0.5, z1 - 0.3))
				path.append(root)
				var yaw: float = atan2(c.x - w.x + 0.01, c.z - w.z) + sp.rng.randf_range(-0.6, 0.6)
				list.append({"root": root, "yaw": yaw, "row": 0, "path": path, "far": sp.rng.randf(), "pose": "bath"})
	list.sort_custom(func(a, b): return a["far"] < b["far"])
	var ids := []
	for s in list:
		ids.append(seats_a.size())
		seats_a.append(s)
	lay["groups"]["bath"] = ids
