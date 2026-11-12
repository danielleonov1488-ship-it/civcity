class_name NewArena
extends RefCounted
## Пробные НОВЫЕ амфитеатр и цирк (владелец 13.11: «пересобрать на абсолютно новые модельки из того, что есть в Synty»,
## «цирк — модель ужасная, под ней обычная земля», «амфитеатр — вход просто чёрный», «на полкарты цирк… сделаем меньше»).
## Собраны с нуля из деталей Synty POLYGON Ancient Empire в масштабе города: детали в натуральную величину, как у домов
## (Catalog.ARCH, без прежнего «ужатия» Catalog.SHRINK), а сами здания маленькие — амфитеатр как четыре дома плебеев,
## цирк как шесть. Прежние сборщики (CatMonuments._colosseum, CatGrand._circus) не тронуты: NewArena.ON = false —
## строится прежнее (снимки «было/стало»).
##
## Правила сборки (как у всех новых зданий): своё мощёное основание по всему следу (травы и «лесенки» земли внутри не
## видно), ни одного тёмного проёма — за аркой либо освещённая ниша, либо проход на светлую арену, либо закрытые ворота;
## только детали Synty и коробки общего пула (Parts), огонь — без лишних источников света (один на здание).
## Места зрителей (Spectacle) считаются здесь же — по тем же размерам, что и трибуны (seats), и каждое место проверяется
## лучами по треугольникам (Spectacle._check): таз на скамье, ступни на ступени ниже, над головой пусто.

## Выключатель «новые / прежние» (снимки «было/стало», проверки); CIVCITY_NEWARENA=0 — прежние во всей игре (сверка проверок)
static var ON := OS.get_environment("CIVCITY_NEWARENA") != "0"
const TYPES := ["colosseum", "circus_fl"]
## Масштаб к Catalog.ARCH: 1 — детали Synty в натуральную величину города (рядом с домами и жителями)
const K := 1.0
## Единица чертежа → метры (Catalog.ARCH × K)
const S := 0.72


static func covers(type: String) -> bool:
	return ON and type in TYPES


static func make(b: Bp, type: String) -> void:
	match type:
		"colosseum": _colosseum(b)
		"circus_fl": _circus(b)


## Животные при здании (game._pets2): у нового цирка коней у ворот нет — дорожка короткая, кони стояли бы на ней
static func pets(_type: String) -> Array:
	return []


# ---------- общие помощники ----------

static func _put(b: Bp, nm: String, xf: Transform3D, rm := {}) -> void:
	b.parts.append([nm, b.base * xf, rm])


static func _box(b: Bp, nm: String, c: Vector3, sz: Vector3, yaw := 0.0) -> void:
	_put(b, nm, Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(sz), c))


static func _dir(t: float) -> Vector3:
	return Vector3(sin(t), 0.0, cos(t))


## Коробка на дуге: углы t0..t1 (от +Z к +X), радиусы r0..r1 (по середине дуги), высота y0..y1. Ширина — по внешнему
## краю (соседние коробки смыкаются без щелей); у нечётных чуть выше верх — общие кромки соседей не мерцают
static func _arc_box(b: Bp, nm: String, t0: float, t1: float, r0: float, r1: float, y0: float, y1: float, k: int) -> void:
	var tc := (t0 + t1) * 0.5
	var w := 2.0 * r1 * tan((t1 - t0) * 0.5) + 0.02
	var top := y1 + (0.006 if k % 2 == 1 else 0.0)
	_box(b, nm, _dir(tc) * (r0 + r1) * 0.5 + Vector3(0, (y0 + top) * 0.5, 0), Vector3(w, top - y0, r1 - r0), tc)


## Деталь шириной 2,5 по кругу: середина на направлении ang, на радиусе r, лицом наружу (inward — к середине)
static func _ring(b: Bp, nm: String, ang: float, r: float, y: float, width: float, sy := 1.0, sz := 1.0, rm := {}, inward := false, pw := 2.5) -> void:
	CatMonuments._ring_put(b, nm, ang, r, y, width, pw, sy, sz, rm, inward)


## Мощёное основание: плиты травертина по прямоугольнику x0..x1 × z0..z1 (по сетке примерно 2,5 × 2,5)
static func _plinth(b: Bp, x0: float, x1: float, z0: float, z1: float) -> void:
	var nx := maxi(1, int(round((x1 - x0) / 2.5)))
	var nz := maxi(1, int(round((z1 - z0) / 2.5)))
	CatMonuments._floor(b, CatMonuments.PAVING, x0, z0, x1, z1, 0.02, nx, nz)


## Бордюр по краю основания: каменные плиты Synty, внешней гранью — по краю (ровная кромка вместо «лесенки» клеток)
static func _kerb(b: Bp, x0: float, x1: float, z0: float, z1: float) -> void:
	CatMonuments._ring_rect(b, "SM_Bld_Ground_Edge_01", x0 + 0.16, x1 - 0.16, z0 + 0.16, z1 - 0.16, 0.06)


# =====================================================================
#   амфитеатр
# =====================================================================
## Маленький городской амфитеатр (≈ 7 × 7 м, как четыре дома): снаружи — двенадцать арок из белого камня с золотыми
## архивольтами, карниз; внутри — песчаная арена (Ø 3 м), мраморный подиум с меандром и три ряда каменных скамей.
## Главный вход спереди — сквозной проход: в арку видно светлую арену. Слева и справа — ворота гладиаторов (створки
## ставит Spectacle) и проходы к ним. В остальных арках — неглубокие светлые ниши со статуями и знамёнами.

const AR := 1.50 / S                       # радиус арены
const DS := 0.22 / S                       # ступень для ног (глубина)
const DB := 0.20 / S                       # скамья (глубина)
const RR := 0.27 / S                       # подъём ряда
const BH := 0.19 / S                       # скамья над своей ступенью (= Crowd.SEAT_DROP)
const H0 := 1.5                            # верх подиума (= ступень нижнего ряда), Bath_Edge в рост
const ROWS := 3
const RO := 4.665                          # внешняя грань аркады (двенадцать арок по 2,5)
const WALL_IN := RO - 0.47                 # внутренняя грань аркады
const WALK_OUT := 4.36                     # верхний обход — под стену (на углах двенадцатиугольника — тоже)
const PL := RO + 0.25                      # полуширина основания
const ATTIC_Y := 3.28                      # низ аттика (над карнизом аркады); верх — ATTIC_Y + 0.6
## Части кольца трибун (градусы от +Z к +X): проход главного входа, лестницы, ряды мест, проходы к воротам гладиаторов
const PIECES := [[-15.0, 15.0, "main"], [15.0, 30.0, "aisle"], [30.0, 75.0, "seat"], [75.0, 105.0, "gate"], [105.0, 172.5, "seat"],
	[172.5, 187.5, "aisle"], [187.5, 255.0, "seat"], [255.0, 285.0, "gate"], [285.0, 330.0, "seat"], [330.0, 345.0, "aisle"]]
## Ворота гладиаторов (ArenaShow): направления от середины
const GATES := [PI / 2.0, 3.0 * PI / 2.0]
const GATE_HALF := 0.56                    # полпроёма ворот (две створки Synty по 0,56)


static func row_front(k: int) -> float:
	return AR + DS + k * (DS + DB)


static func step_y(k: int) -> float:
	return H0 + k * RR


static func walk_y() -> float:
	return H0 + ROWS * RR


static func _colosseum(b: Bp) -> void:
	_plinth(b, -PL, PL, -PL, PL)
	_kerb(b, -PL, PL, -PL, PL)
	# арена: песок — квадрат, углы уходят под трибуны (в проходы не заходят: они на осях)
	var aw := AR + 0.08
	_put(b, "SM_Bld_Base_Floor_01", Transform3D(Basis.from_scale(Vector3(2 * aw / 2.5, 1, 2 * aw / 2.5)), Vector3(-aw, 0.03, -aw)), CatMonuments.SAND)
	# кольцо трибун: ступени, скамьи, лестницы, верхний обход (за арками под обходом — светлая ниша)
	var seg := 0
	for pc: Array in PIECES:
		var t0 := deg_to_rad(float(pc[0]))
		var t1 := deg_to_rad(float(pc[1]))
		var kind: String = pc[2]
		if kind == "main" or kind == "gate":
			continue
		var n := maxi(1, int(ceil((float(pc[1]) - float(pc[0])) / 15.0 - 0.01)))
		for i in n:
			var a0 := lerpf(t0, t1, float(i) / n)
			var a1 := lerpf(t0, t1, float(i + 1) / n)
			_arc_box(b, "#marble", a0, a1, AR + 0.08, row_front(0), 0.0, step_y(0), seg)
			for r in ROWS:
				var f := row_front(r)
				if r > 0:
					_arc_box(b, "#marble", a0, a1, f - DS, f, 0.0, step_y(r), seg)
				if kind == "aisle":
					_arc_box(b, "#marble", a0, a1, f, f + DB, 0.0, step_y(r) + RR * 0.5, seg)     # лестница: полступени
				else:
					_arc_box(b, "#bench", a0, a1, f, f + DB, 0.0, step_y(r) + BH, seg)
			_arc_box(b, "#marble", a0, a1, row_front(ROWS - 1) + DB, WALK_OUT, walk_y() - 0.15, walk_y(), seg)
			seg += 1
	# подиум арены: мрамор с меандром (у ворот гладиаторов — проём с рамой)
	var side := 2.0 * AR * tan(PI / 12.0)
	for i in 12:
		if i == 3 or i == 9:
			continue
		_ring(b, "SM_Bld_Bath_Edge_01", i * PI / 6.0, AR, H0 - 0.21, side, 1.0, 1.0, {}, true)
	for g: float in GATES:
		_gate_frame(b, g)
	# аркада: двенадцать арок из белого камня с золотыми архивольтами, карниз, аттик
	for i in 12:
		var ang := i * PI / 6.0
		_ring(b, "SM_Bld_Wall_Door_Double_01", ang, RO - 0.24, 0.0, 2.5)
		_ring(b, "SM_Bld_Wall_Large_Cap_01", ang, RO - 0.24, 3.01, 2.53, 1.0, 0.8, {}, false, 5.0)
		_ring(b, "SM_Bld_Bath_Edge_01", ang, RO - 0.36, ATTIC_Y + 1.29 * 0.4, 2.5 * (RO - 0.36) / RO + 0.03, 0.4, 0.6)
	# в арках: ниши со статуями, знамёна (у входа и ворот — проходы)
	for i: int in [1, 5, 7, 11]:
		var ang := i * PI / 6.0
		var p := _dir(ang) * (WALL_IN - 0.22)
		b.add("SM_Prop_Plinth_03", p, ang, 0.55)
		b.add("SM_Prop_Statue_0%d" % [5, 6, 3, 5][[1, 5, 7, 11].find(i)], p + Vector3(0, 0.08, 0), ang, 0.72)
	for i: int in [2, 4, 8, 10, 6]:
		var ang := i * PI / 6.0
		b.add("SM_Prop_Banner_01_%s" % ["B", "D", "F", "H", "E"][[2, 4, 8, 10, 6].find(i)], _dir(ang) * (RO - 0.42) + Vector3(0, 2.28, 0), ang, 1.0)
	# над аттиком — шесты с навесами (веларий: терракота и шафран), спереди над входом — статуя
	var rc := (RO - 0.36) / cos(PI / 12.0)               # угол аттика
	var top := ATTIC_Y + 0.6
	for k in 6:
		var ang := PI / 4.0 + k * PI / 3.0
		CatShops._pole(b, _dir(ang) * rc + Vector3(0, top - 0.05, 0), 1.7)
		var am := ang + PI / 6.0
		if k >= 1 and k <= 3:
			# полотнище — от шеста к шесту (хорда через 60°), к середине с уклоном
			var by := Basis(Vector3.UP, am + PI)
			_put(b, "SM_Prop_Banner_Roof_02", Transform3D(by * Basis(Vector3.RIGHT, 0.24) * Basis.from_scale(Vector3(rc / 5.1, 1.0, 0.38)), _dir(am) * rc * cos(PI / 6.0) + Vector3(0, top + 1.6, 0) - by * Vector3(rc * 0.5, 0, 0)), CatMonuments.VELA_SAFFRON if k == 2 else {})
		if k == 0 or k >= 4:
			b.add("SM_Prop_Banner_05", _dir(ang) * (rc + 0.12) + Vector3(0, top + 1.55, 0), ang, 0.8)
	b.add("SM_Prop_Statue_04", Vector3(0, top - 0.02, RO - 0.36), 0.0, 0.6)
	b.add("SM_Bld_Ornament_02", Vector3(0, ATTIC_Y + 0.3, RO - 0.36 + 0.16), 0.0, 0.55)
	# главный вход: у края основания — две колонны с чашами огня (фасад постройки — по ним: основание встаёт
	# вплотную к дороге, между ним и улицей нет полосы травы), знамёна по бокам арки, цветы; один фонарь на всё здание
	for sd: float in [-1.0, 1.0]:
		b.add_xf("SM_Bld_Pillar_06", Transform3D(Basis.from_scale(Vector3(0.8, 0.85, 0.8)), Vector3(sd * 1.75, 0, PL - 0.21)))
		b.add("SM_Prop_Brazier_03", Vector3(sd * 1.75, 2.55, PL - 0.21), 0.0, 0.62)
		b.add("SM_Prop_Brazier_03_Insert_01", Vector3(sd * 1.75, 2.55, PL - 0.21), 0.0, 0.62)
		b.add("SM_Prop_Banner_01_B", Vector3(sd * 1.0, 2.62, RO + 0.02), 0.0, 0.62)
		b.add("SM_Prop_FlowerBed_01", Vector3(sd * 2.95, 0.2, 4.0), -sd * PI / 6.0, 0.62)
	b.light(Vector3(0, 1.5, RO + 0.6))
	# углы основания: кипарисы и цветущие кусты
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			var q := Vector3(cx * (PL - 0.62), 0, cz * (PL - 0.62))
			b.add("SM_Env_Tree_Thin_0%d" % (1 if cz > 0.0 else 2), q, b.rng.randf() * TAU, 0.42)
			if cz < 0.0:
				b.add("SM_Env_Garden_Plants_0%d" % (3 if cx > 0.0 else 6), q + Vector3(-cx * 0.7, 0, cz * 0.1), b.rng.randf() * TAU, 0.42)
			b.add("SM_Env_Garden_Plants_0%d" % (6 if cx * cz > 0.0 else 3), q + Vector3(cx * 0.1, 0, -cz * 0.72), b.rng.randf() * TAU, 0.38)
	# люди при деле: стража у входа, распорядитель на обходе, служитель у ворот гладиаторов
	for sd: float in [-1.0, 1.0]:
		b.actor(Vector3(sd * 0.62, 0, PL - 0.1), 0.0, "Sword_Idle", "soldier")
	b.actor(_dir(deg_to_rad(205.0)) * (WALL_IN - 0.14) + Vector3(0, walk_y(), 0), deg_to_rad(205.0) + PI, "Idle", "rich")
	b.actor(Vector3(RO + 0.12, 0, 0.95), PI / 2.0, "Idle", "pleb")
	b.door = Vector3(0, 0, PL + 0.6)


## Рама ворот гладиаторов у арены (направление g): два столба, перемычка, щит и факелы; створки — Spectacle
static func _gate_frame(b: Bp, g: float) -> void:
	var c := _dir(g) * AR
	var t := Vector3(cos(g), 0, -sin(g))
	var bs := Basis(Vector3.UP, g + PI)                  # лицом к арене
	for sd: float in [-1.0, 1.0]:
		b.add_xf("SM_Bld_Base_Pillar_02", Transform3D(Basis(Vector3.UP, g).scaled(Vector3(1.0, 0.86, 1.0)), c + t * sd * (GATE_HALF + 0.22)))
		b.add_xf("SM_Prop_Torch_01", Transform3D(bs, c + t * sd * (GATE_HALF + 0.22) - _dir(g) * 0.24 + Vector3(0, 1.75, 0)))
	_put(b, "SM_Bld_Wall_Large_Cap_01", Transform3D(Basis(Vector3.UP, g) * Basis.from_scale(Vector3(2.0 / 5.02, 1.0, 0.6)), c + Vector3(0, 2.6, 0) - t * 1.0))
	_put(b, "SM_Wep_Shield_01", Transform3D(bs * Basis.from_scale(Vector3.ONE * 0.6), c - _dir(g) * 0.28 + Vector3(0, 2.55, 0)))


## Рамы ворот для створок Spectacle (в метрах, оси постройки): как у SM_Bld_Wall_Door_Large_01 — проём от 0,69 до 1,81
## вдоль оси x, лицо (z) — к арене
static func gate_frames() -> Array:
	var out := []
	for g: float in GATES:
		var zin := -_dir(g)
		var xa := Vector3.UP.cross(zin)
		var c := _dir(g) * AR
		out.append(Transform3D(Basis(xa, Vector3.UP, zin).scaled(Vector3.ONE * S), (c - xa * 1.25) * S))
	return out


# =====================================================================
#   цирк
# =====================================================================
## Маленький городской цирк (≈ 13 × 5 м, как шесть домов) вдоль X: песчаная дорожка вокруг «спины» — низкой мраморной
## стенки с водой, обелиском, статуями и метами на концах; вдоль длинных сторон — мраморный подиум с меандром и ряд
## каменных скамей, позади — обход и низкая стена. На западном конце — стартовые ворота (карцеры) с деревянными
## створками между колонн и две башенки, на восточном — полукруглая стена с триумфальной аркой. Спереди посредине —
## вход по лестнице в ложу.

const CA := 4.6 / S                        # меты (центры поворотов) на ±CA
const TW := 1.6 / S                        # от оси до подиума трибун
const SPINE_W := 0.22 / S                  # полуширина спины
const CPH := 0.55 / S                      # подиум (ступень ряда)
const C_BACK := TW + DS + DB + 0.2 / S     # задний край обхода
const C_OUT := C_BACK + 0.18 / S           # внешняя грань стены трибун
const CX0 := -CA - TW                      # грань стартовых ворот
const CX_STAND := CX0 + 0.25 / S           # трибуны: от ворот…
const CPLX0 := CX0 - 0.5 / S               # основание
const CPLX1 := CA + TW + 0.3 / S
const CPLZ := C_OUT + 0.08 / S            # основание сзади…
const CPLZF := C_OUT + 0.4 / S             # …и спереди (у входа — жаровни)
const C_WALL_H := 1.0 / S                  # стена позади трибун (верх рядов видно с улицы)
## Лестницы на трибуны (x, обе стороны) и ложа (сзади посредине, |x| < LOGE): помост на высоте LOGE_Y
const C_AISLES := [-3.2 / S, 1.7 / S]
const AISLE_W := 0.32 / S
const LOGE := 0.9 / S
const LOGE_Y := (0.55 + 0.27 + 0.15) / S
const PORTAL_HW := 1.25                    # полуширина портала входа (SM_Bld_Wall_Door_Large_01)
## Колесницы (CircusShow) в метрах: меты, полосы дорожки, сколько упряжек, их размер и скорость
const RACE := {"A": 4.6, "lane_min": 0.74, "lane_max": 1.1, "teams": 4, "scale": 0.8, "v_straight": 4.6, "v_turn": 2.9, "floor": Vector2(0.0, 1.0)}


static func _circus(b: Bp) -> void:
	_plinth(b, CPLX0, CPLX1, -CPLZ, CPLZF)
	_kerb(b, CPLX0, CPLX1, -CPLZ, CPLZF)
	# дорожка: песок, у полукруглого конца — тоже
	CatMonuments._floor(b, CatMonuments.SAND, CX0, -TW, CA, TW, 0.03, 4, 1)
	for k in 5:
		var ang := (k + 0.5) * PI / 5.0
		var bs := Basis(Vector3.UP, ang)
		_put(b, "SM_Bld_Base_Floor_01", Transform3D(bs * Basis.from_scale(Vector3(1.8 / 2.5, 1, TW / 2.5)), Vector3(CA, 0.032 + k * 0.002, 0) + bs * Vector3(-0.9, 0, 0)), CatMonuments.SAND)
	_spine(b)
	for side: float in [-1.0, 1.0]:
		_stand(b, side)
	_loge(b)
	_portal(b)
	_carceres(b)
	_turn_end(b)
	# у входа: жаровни на постаментах, цветы; один фонарь на всё здание
	var zf := C_OUT
	for sd: float in [-1.0, 1.0]:
		# колонны с чашами огня у края основания: по ним — фасад, основание встаёт вплотную к дороге
		var q := Vector3(sd * 1.15, 0, CPLZF - 0.15)
		b.add("SM_Bld_Pillar_06", q, 0.0, 0.55)
		b.add("SM_Prop_Brazier_03", q + Vector3(0, 1.65, 0), 0.0, 0.6)
		b.add("SM_Prop_Brazier_03_Insert_01", q + Vector3(0, 1.65, 0), 0.0, 0.6)
	b.light(Vector3(0, 1.5, zf + 0.5))
	# углы у полукруглого конца: кипарисы и цветущие кусты
	for sd: float in [-1.0, 1.0]:
		var q := Vector3(CPLX1 - 0.5, 0, sd * (CPLZ - 0.5))
		b.add("SM_Env_Tree_Thin_01", q, b.rng.randf() * TAU, 0.4)
		b.add("SM_Env_Garden_Plants_0%d" % (3 if sd > 0.0 else 6), q + Vector3(-0.75, 0, 0), b.rng.randf() * TAU, 0.4)
	# люди при деле: у входа, распорядитель и гость в ложе
	b.actor(Vector3(1.75, 0, zf + 0.5), 0.0, "Idle", "pleb")
	b.actor(Vector3(-1.75, 0, zf + 0.5), 0.0, "Sword_Idle", "soldier")
	b.actor(Vector3(0.35, LOGE_Y, -(TW + 0.42)), 0.0, "Spell_Simple_Idle", "rich")
	b.actor(Vector3(-0.45, LOGE_Y, -(TW + 0.55)), 0.3, "Idle_Talking", "rich")
	b.door = Vector3(0, 0, CPLZF + 0.6)


## Спина: низкая мраморная стенка с карнизом, посредине обелиск, по бокам статуи на постаментах и чаши с огнём;
## на концах — меты: круглый постамент и три конуса
static func _spine(b: Bp) -> void:
	var sl := CA - 0.4 / S
	var h := 0.36 / S
	_box(b, "#marble", Vector3(0, h * 0.5, 0), Vector3(2.0 * sl, h, 2.0 * SPINE_W))
	CatMonuments._run(b, "SM_Bld_Wall_Large_Cap_01", Vector3(-sl, h, 0), Vector3(1, 0, 0), 2.0 * sl, 5.0, 0.6, 0.72)
	var top := h + 0.31 * 0.6
	b.add("SM_Prop_Plinth_04", Vector3(0, top, 0), 0.0, 0.55)
	b.add("#d2_obelisk", Vector3(0, top + 0.37, 0), 0.0, 0.62)
	for x: float in [-2.1 / S, 2.1 / S]:
		b.add("SM_Prop_Plinth_04", Vector3(x, top, 0), 0.0, 0.45)
		b.add("SM_Prop_Statue_0%d" % (5 if x < 0.0 else 6), Vector3(x, top + 0.3, 0), PI / 2.0 if x < 0.0 else -PI / 2.0, 0.5)
	for x: float in [-1.0 / S, 1.0 / S]:
		b.add("SM_Prop_Senser_02", Vector3(x, top, 0), 0.0, 0.55)
	for e: float in [-CA, CA]:
		b.add("SM_Prop_Plinth_03", Vector3(e, 0, 0), 0.0, 0.85)
		for j in 3:
			b.add("#d2_obelisk", Vector3(e, 0.12, (j - 1) * 0.2), 0.0, 0.42)


## Трибуна вдоль стороны side (+1 — спереди, к +Z): подиум с меандром, ступень, скамья (#bench), лестницы, обход,
## стена из травертина с пилястрами, навесы на шестах, снаружи — длинные знамёна
static func _stand(b: Bp, side: float) -> void:
	var xa := CX_STAND
	var xb := CA
	var zf := side * TW
	var cuts := [xa]
	for x: float in C_AISLES:
		cuts.append(x - AISLE_W * 0.5)
		cuts.append(x + AISLE_W * 0.5)
	cuts.append(xb)
	var L := xb - xa
	var cx := (xa + xb) * 0.5
	# подиум: мрамор с меандром лицом к дорожке
	var n := maxi(1, int(round(L / 2.5)))
	var step := L / n
	var sy := CPH / 1.5
	for i in n:
		var x := xa + i * step if side < 0.0 else xb - i * step
		_put(b, "SM_Bld_Bath_Edge_01", Transform3D(Basis(Vector3.UP, 0.0 if side < 0.0 else PI) * Basis.from_scale(Vector3(step / 2.5, sy, 0.6)), Vector3(x, CPH - 0.21 * sy, zf + side * 0.15)))
	_box(b, "#marble", Vector3(cx, CPH * 0.5, zf + side * DS * 0.5), Vector3(L, CPH, DS))
	_box(b, "#marble", Vector3(cx, (CPH + RR) * 0.5, side * (TW + DS + DB + C_BACK) * 0.5), Vector3(L, CPH + RR, C_BACK - TW - DS - DB))
	for i in range(0, cuts.size(), 2):
		var x0: float = cuts[i]
		var x1: float = cuts[i + 1]
		if side < 0.0 and x0 < LOGE and x1 > -LOGE:
			for part: Array in [[x0, -LOGE], [LOGE, x1]]:
				if float(part[1]) - float(part[0]) > 0.3:
					_box(b, "#bench", Vector3((float(part[0]) + float(part[1])) * 0.5, (CPH + BH) * 0.5, zf + side * (DS + DB * 0.5)), Vector3(float(part[1]) - float(part[0]), CPH + BH, DB))
			continue
		_box(b, "#bench", Vector3((x0 + x1) * 0.5, (CPH + BH) * 0.5, zf + side * (DS + DB * 0.5)), Vector3(x1 - x0, CPH + BH, DB))
	for x: float in C_AISLES:
		_box(b, "#marble", Vector3(x, (CPH + RR * 0.5) * 0.5, zf + side * (DS + DB * 0.5)), Vector3(AISLE_W, CPH + RR * 0.5, DB))
	# стена позади: травертин, пилястры, карниз (спереди посредине — портал входа); снаружи — длинные знамёна и цветы
	var wh := C_WALL_H
	var yaw := 0.0 if side > 0.0 else PI
	var runs := [[xa, -PORTAL_HW], [PORTAL_HW, xb]] if side > 0.0 else [[xa, xb]]
	var letters := ["A", "B", "C", "D"]
	var li := 0 if side > 0.0 else 2
	for rn: Array in runs:
		var r0: float = rn[0]
		var r1: float = rn[1]
		var nw := maxi(1, int(round((r1 - r0) / 2.4)))
		var sw := (r1 - r0) / nw
		for i in nw:
			var x := r0 + i * sw if side > 0.0 else r0 + (i + 1) * sw
			_put(b, "SM_Bld_Wall_01", Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(sw / 2.5, wh / 3.01, 1.0)), Vector3(x, 0, side * (C_OUT - 0.11))), CatMonuments.STONE_WALL)
			_put(b, "SM_Bld_Wall_Tiny_01", Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(sw / 2.5, 1.0, 1.6)), Vector3(x, wh, side * (C_OUT - 0.14))))
		for i in nw + 1:
			b.add_xf("SM_Bld_Wall_Large_Pillar_01", Transform3D(Basis.from_scale(Vector3(0.3, wh / 4.55, 0.3)), Vector3(r0 + i * sw, 0, side * (C_OUT - 0.08))), false)
		# знамя — посредине ближнего к середине пролёта; цветы — у каждого пролёта спереди
		var im := clampi(int(nw / 2.0), 0, nw - 1)
		var xm := r0 + (im + 0.5) * sw
		b.add("SM_Prop_Banner_04_" + String(letters[li % 4]), Vector3(xm, wh - 0.06, side * C_OUT), yaw, minf(0.42, (sw - 0.4) / 4.87))
		li += 1
		if side > 0.0:
			for i in nw:
				var xc := r0 + (i + 0.5) * sw
				if absf(xc) > 1.7:
					b.add("SM_Prop_FlowerBed_0%d" % (1 + i % 2), Vector3(xc, 0.2, C_OUT + 0.06), 0.0, 0.6)
	# навесы над скамьями: полосатые полотнища на шестах (терракота и шафран); посредине — портал и ложа
	var k := 0
	for rn: Array in ([[xa, -2.0], [2.0, xb]] if side < 0.0 else []):
		var r0: float = rn[0]
		var r1: float = rn[1]
		var na := maxi(1, int(round((r1 - r0) / 3.4)))
		var aw := (r1 - r0) / na
		for i in na:
			var x := r0 + i * aw
			var by := Basis(Vector3.UP, 0.0 if side < 0.0 else PI)
			var x_from := x + aw if side > 0.0 else x
			_put(b, "SM_Prop_Banner_Roof_02", Transform3D(by * Basis(Vector3.RIGHT, -0.22) * Basis.from_scale(Vector3((aw - 0.1) / 5.1, 1.0, 0.42)), Vector3(x_from - side * 0.05, wh + 1.35, side * (C_OUT - 0.1))), {} if k % 2 == 0 else CatMonuments.VELA_SAFFRON)
			k += 1
		for i in na + 1:
			CatShops._pole(b, Vector3(r0 + i * aw, wh, side * (C_OUT - 0.12)), 1.5)


## Ложа посредине задней трибуны (видна с улицы через дорожку): помост над рядом с мраморной оградой, четыре колонны,
## шафрановый навес, ложе и знамёна
static func _loge(b: Bp) -> void:
	var za := TW
	var zb := C_OUT - 0.22
	_box(b, "#marble", Vector3(0, LOGE_Y * 0.5, -(za + zb) * 0.5), Vector3(2.0 * LOGE, LOGE_Y, zb - za))
	CatMonuments._run(b, "SM_Bld_Wall_Balcony_04", Vector3(-LOGE, LOGE_Y, -za - 0.11), Vector3(1, 0, 0), 2.0 * LOGE, 2.5, 0.55, 1.0, CatMonuments.MARBLE_RAIL)
	for x: float in [-LOGE + 0.18, LOGE - 0.18]:
		for z: float in [za + 0.2, zb - 0.16]:
			b.add("SM_Bld_Pillar_06", Vector3(x, LOGE_Y, -z), 0.0, 0.62)
	_put(b, "SM_Prop_Banner_Roof_01", Transform3D(Basis.from_scale(Vector3((2.0 * LOGE + 0.3) / 2.6, 1.0, (zb - za + 0.3) / 2.6)), Vector3(-LOGE - 0.12, LOGE_Y + 0.62 * 3.0 + 0.48, -zb - 0.15)), CatMonuments.VELA_SAFFRON)
	for x: float in [-LOGE + 0.18, LOGE - 0.18]:
		b.add("SM_Prop_Banner_03_B", Vector3(x, LOGE_Y + 1.75, -(za + 0.2) + 0.05), 0.0, 0.5)


## Вход с улицы посредине передней стены: портал из травертина с закрытыми деревянными створками (за ними не темно),
## карниз, медальон, знамёна
static func _portal(b: Bp) -> void:
	var zp := C_OUT - 0.22
	_put(b, "SM_Bld_Wall_Door_Large_01", Transform3D(Basis.IDENTITY, Vector3(-1.25, 0, zp)), CatMonuments.STONE_WALL)
	b.add("SM_Bld_Door_Large_01", Vector3(-0.56, 0, zp), 0.0)
	CatMonuments._run(b, "SM_Bld_Wall_Large_Cap_01", Vector3(-1.4, 3.0, zp), Vector3(1, 0, 0), 2.8, 5.0, 1.0, 0.8)
	b.add("SM_Bld_Ornament_02", Vector3(0, 2.62, zp + 0.32), 0.0, 0.5)
	for sd: float in [-1.0, 1.0]:
		b.add("SM_Prop_Banner_03_B", Vector3(sd * 1.6, 3.0, zp + 0.22), 0.0, 0.7)


## Стартовые ворота (карцеры) на западном конце: колонны, между ними деревянные створки (закрыты — за ними не темно),
## перемычка, аттик с медальоном и статуей; по углам — башенки-пилоны с огнём наверху
static func _carceres(b: Bp) -> void:
	var nb := 4
	var bw := 2.0 * TW / nb
	var ph := 2.1
	for i in nb + 1:
		b.add("SM_Bld_Pillar_06", Vector3(CX0, 0, -TW + i * bw), 0.0, 0.7)
	for i in nb:
		var zc := -TW + (i + 0.5) * bw
		_put(b, "SM_Bld_Door_Large_01", Transform3D(Basis(Vector3.UP, PI / 2.0) * Basis.from_scale(Vector3((bw - 0.34) / 1.12, (ph - 0.05) / 2.47, 1.0)), Vector3(CX0 - 0.05, 0, zc + (bw - 0.34) * 0.5)))
	CatMonuments._run(b, "SM_Bld_Wall_Large_Cap_01", Vector3(CX0, ph, TW + 0.3), Vector3(0, 0, -1), 2.0 * TW + 0.6, 5.0, 0.8, 0.7)
	_put(b, "SM_Bld_Wall_01", Transform3D(Basis(Vector3.UP, PI / 2.0) * Basis.from_scale(Vector3((2.0 * TW + 0.4) / 2.5, 0.3, 1.0)), Vector3(CX0 - 0.12, ph + 0.25, TW + 0.2)), CatMonuments.STONE_WALL)
	_put(b, "SM_Bld_Wall_Tiny_01", Transform3D(Basis(Vector3.UP, PI / 2.0) * Basis.from_scale(Vector3((2.0 * TW + 0.5) / 2.5, 1.0, 1.6)), Vector3(CX0 - 0.12, ph + 0.25 + 0.9, TW + 0.25)))
	b.add("SM_Bld_Ornament_02", Vector3(CX0 + 0.02, ph + 0.7, 0), PI / 2.0, 0.55)
	b.add("SM_Prop_Statue_05", Vector3(CX0 - 0.15, ph + 1.45, 0), PI / 2.0, 0.55)
	# задняя стена стойл и кровля
	_put(b, "SM_Bld_Wall_01", Transform3D(Basis(Vector3.UP, -PI / 2.0) * Basis.from_scale(Vector3((2.0 * TW + 0.4) / 2.5, (ph + 0.3) / 3.01, 1.0)), Vector3(CX0 - 0.55, 0, -TW - 0.2)), CatMonuments.STONE_WALL)
	_box(b, "#marble", Vector3(CX0 - 0.3, ph + 0.15, 0), Vector3(0.55, 0.3, 2.0 * TW + 0.4))
	for sd: float in [-1.0, 1.0]:
		var p := Vector3(CX0 - 0.15, 0, sd * (TW + 0.48))
		b.add_xf("SM_Bld_Wall_Large_Pillar_01", Transform3D(Basis.from_scale(Vector3(0.95, 0.72, 0.95)), p), false)
		b.add("SM_Bld_Wall_Large_Pillar_Cap_01", p + Vector3(0, 4.55 * 0.72, 0), 0.0, 0.8)
		b.add("SM_Prop_Brazier_04", p + Vector3(0, 4.55 * 0.72 + 0.38, 0), 0.0, 0.5)
		b.add("SM_Prop_Brazier_04_Insert_01", p + Vector3(0, 4.55 * 0.72 + 0.38, 0), 0.0, 0.5)
		b.add("SM_Prop_Banner_03_" + ("D" if sd > 0.0 else "F"), p + Vector3(0.48, 3.0, 0), PI / 2.0, 0.6)


## Полукруглый конец: стена из травертина по дуге с карнизом, посредине — триумфальная арка с аттиком и статуей
## (в арку видно улицу: светло)
static func _turn_end(b: Bp) -> void:
	var keep := b.base
	b.base = keep * Transform3D(Basis.IDENTITY, Vector3(CA, 0, 0))
	var r := TW + 0.12
	var w := 2.0 * r * tan(PI / 16.0) + 0.05
	for i in 8:
		var ang := (i + 0.5) * PI / 8.0
		if i == 3 or i == 4:
			continue
		_ring(b, "SM_Bld_Wall_01", ang, r, 0.0, w, C_WALL_H / 3.01, 1.0, CatMonuments.STONE_WALL)
		_ring(b, "SM_Bld_Wall_Tiny_01", ang, r - 0.03, C_WALL_H, w, 1.0, 1.6)
	_ring(b, "SM_Bld_Wall_Door_Double_01", PI / 2.0, r + 0.05, 0.0, 2.5)
	_ring(b, "SM_Bld_Wall_Large_Cap_01", PI / 2.0, r + 0.05, 3.01, 2.7, 1.0, 0.8, {}, false, 5.0)
	_ring(b, "SM_Bld_Wall_01", PI / 2.0, r + 0.05, 3.3, 2.4, 0.25, 1.0, CatMonuments.STONE_WALL)
	b.add("SM_Prop_Statue_06", Vector3(r + 0.05, 4.05, 0), PI / 2.0, 0.55)
	for sd: float in [-1.0, 1.0]:
		b.add("SM_Prop_Banner_01_" + ("D" if sd > 0.0 else "H"), Vector3(r + 0.45, 2.85, sd * 1.75), PI / 2.0, 0.7)
	b.base = keep


# =====================================================================
#   места зрителей (Spectacle.layout)
# =====================================================================

## Места и пути зрителей: в осях постройки, в метрах (чертёж уже в масштабе). Каждое место проверяет Spectacle._check
## (таз на скамье, ступни на ступени ниже ровно на Crowd.SEAT_DROP, над головой и перед коленями пусто)
static func seats(sp, lay: Dictionary, tris, type: String) -> void:
	match type:
		"colosseum": _arena_seats(sp, lay, tris)
		"circus_fl": _circus_seats(sp, lay, tris)


## Середина отрезка кольца трибун, в который попадает угол th (как их режет _colosseum)
static func _seg_center(th: float) -> float:
	var d := fposmod(rad_to_deg(th) + 15.0, 360.0) - 15.0
	for pc: Array in PIECES:
		var p0 := float(pc[0])
		var p1 := float(pc[1])
		if d >= p0 - 1e-4 and d <= p1 + 1e-4:
			var n := maxi(1, int(ceil((p1 - p0) / 15.0 - 0.01)))
			var i := clampi(int(floor((d - p0) / ((p1 - p0) / n))), 0, n - 1)
			return deg_to_rad(p0 + (i + 0.5) * (p1 - p0) / n)
	return th


## Точка на кольце с апофемой a (метры) по направлению th — на прямой стороне своего отрезка
static func _ring_pt(th: float, a: float, y: float) -> Vector3:
	var p := _dir(th) * (a / cos(th - _seg_center(th)))
	p.y = y
	return p


static func _arena_seats(sp, lay: Dictionary, tris) -> void:
	var seats_a: Array = lay["seats"]
	var wy := walk_y() * S
	for pi in PIECES.size():
		var pc: Array = PIECES[pi]
		if pc[2] != "seat":
			continue
		var t0 := deg_to_rad(float(pc[0]))
		var t1 := deg_to_rad(float(pc[1]))
		# лестница — соседняя часть (перед рядами или после них)
		var prev: Array = PIECES[(pi - 1 + PIECES.size()) % PIECES.size()]
		var next: Array = PIECES[(pi + 1) % PIECES.size()]
		var at_start: bool = prev[2] == "aisle"
		var ais: Array = prev if at_start else next
		var tm := deg_to_rad((float(ais[0]) + float(ais[1])) * 0.5)
		var edge := t0 if at_start else t1
		var sgn := 1.0 if at_start else -1.0
		for r in ROWS:
			var a := row_front(r) * S
			var top := (step_y(r) + BH) * S
			var fy := step_y(r) * S
			var rw := a - 0.10
			# спуск: из-под обхода (внутри лестницы, снаружи не видно) — на обход — по полуступеням вниз до своего ряда
			var down := PackedVector3Array()
			down.append(_ring_pt(tm, (row_front(ROWS - 1) + DB * 0.4) * S, wy - 0.9))
			down.append(_ring_pt(tm, (row_front(ROWS - 1) + DB) * S + 0.1, wy))
			for j in range(ROWS - 1, r - 1, -1):
				down.append(_ring_pt(tm, (row_front(j) + DB * 0.5) * S, (step_y(j) + RR * 0.5) * S))
				down.append(_ring_pt(tm, rw if j == r else (row_front(j) - DS * 0.5) * S, step_y(j) * S))
			var span := (t1 - t0) * a
			var n := int(floor((span - 0.12) / Spectacle.SPACING))
			if n <= 0:
				continue
			var list := []
			for i in n:
				var dist := 0.06 + (i + 0.5) * (span - 0.12) / n
				var th := edge + sgn * dist / a
				var D := _dir(th)
				var F := -D
				var E := _ring_pt(th, a, top)
				var pelvis := E + D * Spectacle.PELVIS_IN
				var root := pelvis - D * People.SIT_BACK
				var seat_y: float = sp._check(tris, pelvis, root, F, top)
				if seat_y == -INF:
					lay["dropped"] = int(lay.get("dropped", 0)) + 1
					continue
				root.y = seat_y - Crowd.SEAT_RISE
				var path := down.duplicate()
				var m := maxi(1, int(absf(th - tm) * rw / 0.25))
				for q in range(1, m + 1):
					path.append(_ring_pt(lerpf(tm, th, float(q) / m), rw, fy))
				path.append(Vector3(root.x, fy, root.z))
				list.append({"root": root, "yaw": atan2(F.x, F.z), "row": r, "path": path, "far": dist})
			list.sort_custom(func(x, y): return x["far"] > y["far"])     # дальние от лестницы — первыми
			var ids := []
			for s in list:
				ids.append(seats_a.size())
				seats_a.append(s)
			lay["groups"]["arena%d|%d" % [pi, r]] = ids


static func _circus_seats(sp, lay: Dictionary, tris) -> void:
	var seats_a: Array = lay["seats"]
	var top := (CPH + BH) * S
	var fy := CPH * S
	var wy := (CPH + RR) * S
	for side: float in [-1.0, 1.0]:
		var F := Vector3(0, 0, -side)
		var D := -F
		var zf := side * (TW + DS) * S                       # передний край скамьи
		var zw := zf - side * 0.10                           # где идут вдоль ряда
		var zwalk := side * (TW + DS + DB + (C_BACK - TW - DS - DB) * 0.5) * S
		# куски скамьи между лестницами (и ложей спереди); у каждого — ближняя лестница
		var cuts := [CX_STAND * S]
		for x: float in C_AISLES:
			cuts.append((x - AISLE_W * 0.5) * S)
			cuts.append((x + AISLE_W * 0.5) * S)
		cuts.append(CA * S)
		var runs := []
		for i in range(0, cuts.size(), 2):
			var x0: float = cuts[i]
			var x1: float = cuts[i + 1]
			if side < 0.0 and x0 < LOGE * S and x1 > -LOGE * S:
				runs.append([x0, -LOGE * S - 0.05])
				runs.append([LOGE * S + 0.05, x1])
			else:
				runs.append([x0, x1])
		var gi := 0
		for rn: Array in runs:
			var x0: float = rn[0]
			var x1: float = rn[1]
			var L := x1 - x0
			var n := int(floor((L - 0.12) / Spectacle.SPACING))
			if n <= 0:
				continue
			var list := []
			for i in n:
				var x := x0 + 0.06 + (i + 0.5) * (L - 0.12) / n
				# ближняя лестница
				var xa := 1e9
				for ax: float in C_AISLES:
					if absf(ax * S - x) < absf(xa - x):
						xa = ax * S
				var E := Vector3(x, top, zf)
				var pelvis := E + D * Spectacle.PELVIS_IN
				var root := pelvis - D * People.SIT_BACK
				var seat_y: float = sp._check(tris, pelvis, root, F, top)
				if seat_y == -INF:
					lay["dropped"] = int(lay.get("dropped", 0)) + 1
					continue
				root.y = seat_y - Crowd.SEAT_RISE
				var path := PackedVector3Array([Vector3(xa, wy - 0.9, zwalk), Vector3(xa, wy, zwalk),
					Vector3(xa, (CPH + RR * 0.5) * S, side * (TW + DS + DB * 0.5) * S), Vector3(xa, fy, zw)])
				var m := maxi(1, int(absf(x - xa) / 0.25))
				for q in range(1, m + 1):
					path.append(Vector3(lerpf(xa, x, float(q) / m), fy, zw))
				path.append(Vector3(root.x, fy, root.z))
				list.append({"root": root, "yaw": atan2(F.x, F.z), "row": 0, "path": path, "far": absf(x - xa)})
			list.sort_custom(func(p, q): return p["far"] > q["far"])
			var ids := []
			for s in list:
				ids.append(seats_a.size())
				seats_a.append(s)
			lay["groups"]["circus%d|%d" % [int(side), gi]] = ids
			gi += 1
