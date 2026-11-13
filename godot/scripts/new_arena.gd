class_name NewArena
extends RefCounted
## НОВЫЕ амфитеатр и цирк — два чуда города по линейке размеров (SizeLadder: мерка — дом плебеев 2,8 × 4 м ≈ 11 м²,
## чудеса — 10–14 домов). Владелец 13.11: «пересобрать на абсолютно новые модельки из того, что есть в Synty»;
## пробные 50 и 70 м² вышли «меньше библиотеки», прежние 239 и 254 м² — «на полкарты».
##   амфитеатр — круглый, Ø 12,6 м вместе с основанием (≈ 125 м², 11 домов);
##   цирк — 21 × 7,2 м (≈ 150 м², 13 домов), вытянутый вдоль улицы.
## Собраны с нуля из деталей Synty POLYGON Ancient Empire в натуральную величину города (Catalog.ARCH, без прежнего
## «ужатия» Catalog.SHRINK). Прежние сборщики (CatMonuments._colosseum, CatGrand._circus) не тронуты: NewArena.ON = false —
## строится прежнее (снимки «было/стало», сверка проверок).
##
## Правила сборки (как у всех новых зданий): своё мощёное основание с бордюром по всему следу (ни травы, ни глиняной
## каймы внутри — City.apron_of = 0), ни одного тёмного проёма: за аркой — светлая кольцевая галерея с росписью, проход
## на освещённую арену или закрытые ворота; в нишах верхнего яруса — статуи и знамёна. Один источник света на здание.
## Места зрителей (Spectacle) считаются здесь же, по тем же размерам, что и трибуны (seats); каждое место проверяется
## лучами по треугольникам (Spectacle._check): таз на скамье, ступни на ступени ниже, над головой пусто.
##
## Старое сохранение (Catalog.fit — прежний, больший след): здание то же и стоит посередине, а весь прежний след
## занимает мощёная площадь с бордюром, кипарисами и цветами — травы внутри прежних клеток нет.

## Выключатель «новые / прежние»; CIVCITY_NEWARENA=0 — прежние во всей игре (сверка проверок)
static var ON := OS.get_environment("CIVCITY_NEWARENA") != "0"
const TYPES := ["colosseum", "circus_fl"]
## Масштаб к Catalog.ARCH: 1 — детали Synty в натуральную величину города (рядом с домами и жителями)
const K := 1.0
## Единица чертежа → метры (Catalog.ARCH × K)
const S := 0.72
## Прежний след (м, при yaw 0): прямоугольник прежней сборки (измерен test_arena_probe) — его клетки занимает постройка
## старого сохранения. Нет в списке — прямоугольник Catalog.fit посередине
const OLD_RECT := {"colosseum": Rect2(-7.607, -7.607, 15.214, 15.713), "circus_fl": Rect2(-13.48, -4.4425, 28.567, 8.885)}


static func covers(type: String) -> bool:
	return ON and type in TYPES


static func make(b: Bp, type: String) -> void:
	var old := Vector2(Catalog.fit)
	match type:
		"colosseum": _colosseum(b, old)
		"circus_fl": _circus(b, old)


## Животные при здании (game._pets2): у нового цирка коней у ворот нет — кони только в упряжках на скачках
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


## Деталь шириной pw по кругу: середина на направлении ang, на радиусе r, лицом наружу (inward — к середине)
static func _ring(b: Bp, nm: String, ang: float, r: float, y: float, width: float, sy := 1.0, sz := 1.0, rm := {}, inward := false, pw := 2.5) -> void:
	CatMonuments._ring_put(b, nm, ang, r, y, width, pw, sy, sz, rm, inward)


## Плита пола Synty (2,5 × 2,5) по радиусу: на направлении ang от r0 до r1, шириной w поперёк
static func _tile(b: Bp, ang: float, r0: float, r1: float, w: float, y: float, rm: Dictionary) -> void:
	var bs := Basis(Vector3.UP, ang)
	_put(b, "SM_Bld_Base_Floor_01", Transform3D(bs * Basis.from_scale(Vector3(w / 2.5, 1, (r1 - r0) / 2.5)), _dir(ang) * r0 - bs.x * w * 0.5 + Vector3(0, y, 0)), rm)


## Мощёное основание: плиты травертина по прямоугольнику x0..x1 × z0..z1 (по сетке примерно 2,5 × 2,5)
static func _plinth(b: Bp, x0: float, x1: float, z0: float, z1: float, y := 0.02) -> void:
	var nx := maxi(1, int(round((x1 - x0) / 2.5)))
	var nz := maxi(1, int(round((z1 - z0) / 2.5)))
	CatMonuments._floor(b, CatMonuments.PAVING, x0, z0, x1, z1, y, nx, nz)


## Бордюр по краю основания: каменные плиты Synty, внешней гранью — по краю (ровная кромка вместо «лесенки» клеток)
static func _kerb(b: Bp, x0: float, x1: float, z0: float, z1: float) -> void:
	CatMonuments._ring_rect(b, "SM_Bld_Ground_Edge_01", x0 + 0.16, x1 - 0.16, z0 + 0.16, z1 - 0.16, 0.06)


## Прежний след в осях чертежа (единицы): прямоугольник прежней сборки или Catalog.fit посередине
static func _old_rect(type: String, fit: Vector2) -> Rect2:
	var r: Rect2 = OLD_RECT.get(type, Rect2(-fit * 0.5, fit))
	return Rect2(r.position / S, r.size / S)


## Площадь на прежнем следе (старое сохранение): мощение по всему прямоугольнику чуть ниже основания здания, бордюр по
## краю; в свободных углах — кипарисы, цветники, скамьи и статуи на постаментах (не пустая плитка)
## round_r > 0 — здание круглое (радиус по углам): в углах площади по диагонали — ещё статуя на постаменте и цветник
static func _forecourt(b: Bp, r: Rect2, keep: Rect2, round_r := 0.0) -> void:
	_plinth(b, r.position.x, r.end.x, r.position.y, r.end.y, 0.012)
	_kerb(b, r.position.x, r.end.x, r.position.y, r.end.y)
	# углы площади вне здания (keep — его прямоугольник): по кипарису, цветнику и скамье; вдоль длинных полос — цветы
	var i := 0
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			var ex := r.end.x if cx > 0.0 else r.position.x
			var ez := r.end.y if cz > 0.0 else r.position.y
			var kx := keep.end.x if cx > 0.0 else keep.position.x
			var kz := keep.end.y if cz > 0.0 else keep.position.y
			var room := Vector2(absf(ex - kx), absf(ez - kz))
			var q := Vector3(ex - cx * 0.75, 0, ez - cz * 0.75)
			b.add("SM_Env_Tree_Thin_0%d" % (1 + i % 2), q, b.rng.randf() * TAU, 0.42)
			b.add("SM_Env_Garden_Plants_0%d" % (3 if i % 2 == 0 else 6), q + Vector3(-cx * 0.75, 0, 0), b.rng.randf() * TAU, 0.42)
			if room.x > 2.6 or room.y > 2.6:
				# просторный угол: статуя на постаменте и скамья к ней лицом
				var s := q + Vector3(-cx * minf(room.x, 4.0) * 0.45, 0, -cz * minf(room.y, 4.0) * 0.45)
				b.add("SM_Prop_Plinth_04", s, 0.0, 0.5)
				b.add("SM_Prop_Statue_0%d" % [3, 5, 6, 3][i], s + Vector3(0, 0.34, 0), atan2(-cx, -cz) + PI, 0.5)
				b.add("SM_Prop_FlowerBed_0%d" % (1 + i % 2), s + Vector3(cx * 0.9, 0.2, 0), 0.0, 0.5)
			if round_r > 0.0:
				var dg := Vector3(cx, 0, cz).normalized() * (round_r + 1.7)
				if absf(dg.x) < absf(ex) - 0.9 and absf(dg.z) < absf(ez) - 0.9:
					b.add("SM_Prop_Plinth_04", dg, 0.0, 0.5)
					b.add("SM_Prop_Statue_0%d" % [6, 3, 5, 6][i], dg + Vector3(0, 0.34, 0), atan2(cx, cz), 0.5)
					b.add("SM_Prop_FlowerBed_0%d" % (2 - i % 2), dg + Vector3(cx * 0.2, 0.2, cz * 0.75), PI / 2.0, 0.42)
			i += 1


# =====================================================================
#   амфитеатр
# =====================================================================
## Круглый городской амфитеатр (Ø 12,6 м с основанием). Снаружи — два яруса по двадцать пролётов: внизу арки из белого
## камня с золотыми архивольтами, наверху — ниши с фронтонами, в нишах статуи и знамёна; карнизы, аттик с меандром,
## над ним шесты велария с полотнищами над задней половиной. За нижними арками — кольцевая галерея: белые стены
## с росписями и факелами, свет из арок. Внутри — чаша трибун до верха второго яруса: песчаная арена Ø 5,5 м, высокий
## подиум (низ — мрамор, верх — меандр), четыре крутых ряда скамей (≈ 150 мест) и верхний обход у стены. Главный вход
## спереди — сквозной ход под рядами: в арку видно светлую арену; слева и справа — такие же ходы к воротам гладиаторов
## (створки ставит Spectacle). Над ходами ряды идут дальше — чаша сплошная.

const T9 := 0.15838444                     # tan 9°: полуугол одного пролёта аркады (20 пролётов)
const RO := 7.8922                          # внешняя грань аркады (апофема): двадцать арок по 2,5
const R_WALL := RO - 0.234                  # середина стены аркады (SM_Bld_Wall_Door_Double_01: толщина 0,47)
const WALL_IN := RO - 0.468                 # внутренняя грань аркады — наружная стена кольцевой галереи
const CI := 6.59                            # внутренняя стена галереи (лицом к аркам)
const PA := 8.68                            # основание: двадцатиугольник, апофема (≈ 6,25 м; по углам 6,33 м)
const T1 := 3.0057                          # высота яруса (стены Synty)
const CAP := 0.315                          # карниз SM_Bld_Wall_Large_Cap_01 над ярусом
const Y2 := T1 + CAP                        # низ второго яруса (= верхний обход трибун)
const ATTIC_Y := Y2 + T1 + CAP              # низ аттика; верх — ATTIC_Y + 0.6
const AR := 3.8                             # радиус арены (Ø ≈ 5,5 м)
const DS := 0.22 / S                        # ступень для ног (глубина)
const DB := 0.20 / S                        # скамья (глубина)
const RR := 0.36 / S                        # подъём ряда (крутая чаша: ряды доходят до верха второго яруса)
const BH := 0.19 / S                        # скамья над своей ступенью (= Crowd.SEAT_DROP)
const ROWS := 4
const WALK_Y := 4.6                         # верхний обход (≈ 3,3 м), за ним — стенка до карниза второго яруса
const H0 := WALK_Y - ROWS * RR              # верх подиума арены (= ступень нижнего ряда), ≈ 1,9 м
const TUN := H0 - 0.12                      # свод ходов под рядами (выше створок ворот 2,47)
const WALK_OUT := R_WALL - 0.527            # верхний обход — до задней стенки ниш второго яруса
const SLAB_Y := 2.98                        # потолок галереи (низ плиты обхода)
## Части кольца трибун (градусы от +Z к +X): [от, до, ряды мест | лестница, ход под рядами: "" | main | gate].
## У каждой части с местами рядом лестница (до неё — обход, вниз по полуступеням); над ходами ряды идут дальше
const PIECES := [[-15.0, 15.0, "seat", "main"], [15.0, 27.0, "aisle", ""], [27.0, 75.0, "seat", ""], [75.0, 105.0, "seat", "gate"],
	[105.0, 117.0, "aisle", ""], [117.0, 165.0, "seat", ""], [165.0, 195.0, "aisle", ""], [195.0, 243.0, "seat", ""],
	[243.0, 255.0, "aisle", ""], [255.0, 285.0, "seat", "gate"], [285.0, 333.0, "seat", ""], [333.0, 345.0, "aisle", ""]]
## Ворота гладиаторов (ArenaShow): направления от середины
const GATES := [PI / 2.0, 3.0 * PI / 2.0]
const GATE_HALF := 0.56                     # полпроёма ворот (две створки Synty по 0,56)
## Ниши второго яруса со статуями (номер пролёта; 0 — над главным входом, по часовой стрелке сверху), остальные — знамёна
const NICHE_STATUES := {1: 5, 19: 6, 3: 3, 17: 5, 10: 6, 7: 3, 13: 5}


static func row_front(k: int) -> float:
	return AR + DS + k * (DS + DB)


static func step_y(k: int) -> float:
	return H0 + k * RR


static func walk_y() -> float:
	return WALK_Y


## Направление середины пролёта i (0 — главный вход, к +Z)
static func _bay(i: int) -> float:
	return i * TAU / 20.0


static func _colosseum(b: Bp, fit: Vector2) -> void:
	var corner := PA / cos(PI / 20.0)
	if fit != Vector2.ZERO:
		var r := _old_rect("colosseum", fit)
		_forecourt(b, r, Rect2(-corner, -corner, 2.0 * corner, 2.0 * corner), corner)
		b.door = Vector3(0, 0, r.end.y + 0.6)
	else:
		b.door = Vector3(0, 0, PA + 0.6)
		# клетки на земле — круг (углы квадрата вокруг свободны): полосы поперёк, в метрах
		var R := corner * S
		var n := 9
		var occ := []
		for i in n:
			var z0 := -R + 2.0 * R * i / n
			var z1 := z0 + 2.0 * R / n
			var zi := 0.0 if (z0 < 0.0 and z1 > 0.0) else minf(absf(z0), absf(z1))
			var hw := sqrt(maxf(0.0, R * R - zi * zi)) + 0.1
			occ.append(Rect2(-hw, z0, 2.0 * hw, z1 - z0))
		b.occ_rects = occ
	# основание: кольцо плит травертина вокруг аркады и бордюр по двадцатиугольнику
	for i in 20:
		var ang := _bay(i)
		_tile(b, ang, R_WALL - 0.3, PA, 2.0 * PA * T9 + 0.04, 0.03 + 0.003 * (i % 2), CatMonuments.PAVING)
		_ring(b, "SM_Bld_Ground_Edge_01", ang, PA - 0.16, 0.06, 2.0 * PA * T9 + 0.02)
	# пол внутри (галерея, проходы): плиты по радиусам от арены до аркады
	var fi := WALL_IN + 0.05
	for i in 20:
		_tile(b, _bay(i), AR - 0.2, fi, 2.0 * fi * T9 + 0.04, 0.012 + 0.003 * (i % 2), CatMonuments.PAVING)
	# арена: песок — квадрат, углы уходят под трибуны (в проходы не заходят: они на осях)
	var aw := AR + 0.08
	_put(b, "SM_Bld_Base_Floor_01", Transform3D(Basis.from_scale(Vector3(2 * aw / 2.5, 1, 2 * aw / 2.5)), Vector3(-aw, 0.035, -aw)), CatMonuments.SAND)
	# кольцо трибун: ступени, скамьи, лестницы, верхний обход над галереей; внутренняя стена галереи
	var seg := 0
	for pc: Array in PIECES:
		var t0 := deg_to_rad(float(pc[0]))
		var t1 := deg_to_rad(float(pc[1]))
		var kind: String = pc[2]
		var tun: bool = pc[3] != ""
		var y0 := TUN if tun else 0.0             # над ходом ряды стоят на своде
		var n := maxi(1, int(ceil((float(pc[1]) - float(pc[0])) / 15.0 - 0.01)))
		for i in n:
			var a0 := lerpf(t0, t1, float(i) / n)
			var a1 := lerpf(t0, t1, float(i + 1) / n)
			_arc_box(b, "#marble", a0, a1, AR + 0.08, row_front(0), y0, step_y(0), seg)
			for r in ROWS:
				var f := row_front(r)
				if r > 0:
					_arc_box(b, "#marble", a0, a1, f - DS, f, y0, step_y(r), seg)
				if kind == "aisle":
					_arc_box(b, "#marble", a0, a1, f, f + DB, y0, step_y(r) + RR * 0.5, seg)     # лестница: полступени
				else:
					_arc_box(b, "#bench", a0, a1, f, f + DB, y0, step_y(r) + BH, seg)
			# верхний обход — плита и над галереей (её потолок), до внутренней грани аркады
			_arc_box(b, "#marble", a0, a1, row_front(ROWS - 1) + DB, WALL_IN + 0.02, minf(SLAB_Y, y0) if tun else SLAB_Y, walk_y(), seg)
			# внутренняя стена галереи: белая штукатурка лицом к аркам (у ходов — проём: ход выходит в галерею)
			if not tun:
				var am := (a0 + a1) * 0.5
				_ring(b, "SM_Bld_Wall_01", am, CI - 0.1125, 0.0, 2.0 * CI * tan((a1 - a0) * 0.5) + 0.03, SLAB_Y / T1)
			seg += 1
	# подиум арены: внизу белый мрамор, сверху мрамор с меандром (у главного хода и ворот гладиаторов — проёмы с рамами)
	var side := 2.0 * AR * tan(PI / 12.0)
	for i in 12:
		if i == 0 or i == 3 or i == 9:
			continue
		_ring(b, "SM_Bld_Bath_Edge_01", i * PI / 6.0, AR, H0 - 0.205, side, 1.0, 1.0, {}, true)
		_ring(b, "SM_Bld_Wall_01", i * PI / 6.0, AR - 0.13, 0.0, side + 0.02, (H0 - 1.35) / T1, 1.0, CatMonuments.RED_WALL, true)
	for g: float in GATES:
		_gate_frame(b, g)
	_gate_frame(b, 0.0)                               # главный ход: рама без створок — в арку видно арену
	# ходы под рядами: по факелу на стене с каждой стороны
	for pc: Array in PIECES:
		if pc[3] == "":
			continue
		for e: float in [float(pc[0]) + 1.2, float(pc[1]) - 1.2]:
			var t := deg_to_rad(e)
			var face := t + (PI / 2.0 if e < (float(pc[0]) + float(pc[1])) * 0.5 else -PI / 2.0)
			b.add_xf("SM_Prop_Torch_01", Transform3D(Basis(Vector3.UP, face).scaled(Vector3.ONE * 1.3), _dir(t) * (AR + 1.6) + Vector3(0, 1.75, 0)))
	# верхний обход: стенка до карниза второго яруса (закрывает задние стенки ниш), травертин; на ней знамёна
	for i in 20:
		_ring(b, "SM_Bld_Wall_01", _bay(i), WALK_OUT - 0.1125, walk_y() - 0.02, 2.0 * WALK_OUT * T9 + 0.03, (Y2 + T1 + 0.06 - walk_y()) / T1, 1.0, CatMonuments.STONE_WALL, true)
		if i % 3 == 1:
			b.add("SM_Prop_Banner_01_%s" % ["D", "B", "F", "H", "B", "D", "F"][i / 3], _dir(_bay(i)) * (WALK_OUT - 0.26) + Vector3(0, Y2 + T1 - 0.05, 0), _bay(i) + PI, 0.62)
	# аркада: два яруса по двадцать пролётов, карнизы, аттик с меандром
	var rc := (RO - 0.36) / cos(PI / 20.0)                 # угол аттика
	for i in 20:
		var ang := _bay(i)
		_ring(b, "SM_Bld_Wall_Door_Double_01", ang, R_WALL, 0.0, 2.5)
		_ring(b, "SM_Bld_Wall_Large_Cap_01", ang, R_WALL, T1, 2.53, 1.0, 0.8, {}, false, 5.0)
		_ring(b, "SM_Bld_Wall_Alcove_01", ang, R_WALL, Y2, 2.5)
		_ring(b, "SM_Bld_Wall_Large_Cap_01", ang, R_WALL, Y2 + T1, 2.53, 1.0, 0.8, {}, false, 5.0)
		_ring(b, "SM_Bld_Bath_Edge_01", ang, RO - 0.36, ATTIC_Y + 1.29 * 0.4, 2.0 * (RO - 0.36) * T9 + 0.03, 0.4, 0.6)
		# в нише второго яруса: статуя на постаменте или знамя
		var p := _dir(ang) * (R_WALL - 0.18) + Vector3(0, Y2 + 0.3, 0)
		if i == 0:
			b.add("SM_Bld_Ornament_02", p + Vector3(0, 0.95, 0) + _dir(ang) * 0.05, ang, 0.85)
		elif NICHE_STATUES.has(i):
			b.add("SM_Prop_Plinth_03", p, ang, 0.6)
			b.add("SM_Prop_Statue_0%d" % int(NICHE_STATUES[i]), p + Vector3(0, 0.09, 0), ang, 0.82)
		else:
			b.add("SM_Prop_Banner_01_%s" % ["B", "D", "F", "H"][i % 4], p + Vector3(0, 2.05, 0) + _dir(ang) * 0.08, ang, 0.9)
	# галерея за арками: росписи на стене напротив арок, факелы между арками (за аркой — светлая стена, не темнота)
	for i in 20:
		var ang := _bay(i)
		var dg := rad_to_deg(ang)
		if dg < 16.0 or dg > 344.0 or absf(dg - 90.0) < 16.0 or absf(dg - 270.0) < 16.0:
			continue                                  # напротив ходов под рядами стены нет
		if i % 2 == 0:
			b.add("SM_Prop_Mural_0%d" % (1 + (i / 2) % 3), _dir(ang) * (CI + 0.02) + Vector3(0, 1.15, 0), ang, 0.62)
		else:
			b.add_xf("SM_Prop_Torch_01", Transform3D(Basis(Vector3.UP, ang).scaled(Vector3.ONE * 1.4), _dir(ang) * (CI + 0.08) + Vector3(0, 1.75, 0)))
	# над аттиком — шесты велария; полотнища (терракота и шафран) — над задней половиной, спереди открыто
	var top := ATTIC_Y + 0.6
	for k in 10:
		var ang := (k + 0.5) * TAU / 10.0
		CatShops._pole(b, _dir(ang) * rc + Vector3(0, top - 0.05, 0), 1.9)
		var am := ang + TAU / 20.0
		if k >= 2 and k <= 6:
			# полотнище — от шеста к шесту (хорда через 36°), к середине с уклоном
			var chord := 2.0 * rc * sin(TAU / 20.0)
			var by := Basis(Vector3.UP, am + PI)
			_put(b, "SM_Prop_Banner_Roof_02", Transform3D(by * Basis(Vector3.RIGHT, 0.26) * Basis.from_scale(Vector3(chord / 5.1, 1.0, 0.85)), _dir(am) * rc * cos(TAU / 20.0) + Vector3(0, top + 1.8, 0) - by * Vector3(chord * 0.5, 0, 0)), CatMonuments.VELA_SAFFRON if k % 2 == 1 else {})
		else:
			b.add("SM_Prop_Banner_05", _dir(ang) * (rc + 0.12) + Vector3(0, top + 1.75, 0), ang, 0.8)
	b.add("SM_Prop_Statue_04", Vector3(0, top - 0.02, RO - 0.36), 0.0, 0.62)
	# главный вход: у края основания — две колонны с чашами огня (по ним — фасад: основание встаёт вплотную к дороге),
	# знамёна по бокам арки, цветы; один источник света на всё здание
	for sd: float in [-1.0, 1.0]:
		b.add_xf("SM_Bld_Pillar_06", Transform3D(Basis.from_scale(Vector3(0.8, 0.85, 0.8)), Vector3(sd * 1.05, 0, PA - 0.22)))
		b.add("SM_Prop_Brazier_03", Vector3(sd * 1.05, 2.55, PA - 0.22), 0.0, 0.62)
		b.add("SM_Prop_Brazier_03_Insert_01", Vector3(sd * 1.05, 2.55, PA - 0.22), 0.0, 0.62)
		b.add("SM_Prop_Banner_01_B", Vector3(sd * 1.0, 2.62, RO + 0.02), 0.0, 0.62)
	b.light(Vector3(0, 1.5, RO + 0.6))
	# цветники на основании у арок (по бокам и сзади; спереди — проход)
	for i: int in [3, 6, 8, 12, 14, 17]:
		var ang := _bay(i) + TAU / 40.0
		b.add("SM_Prop_FlowerBed_0%d" % (1 + i % 2), _dir(ang) * (RO + 0.42) + Vector3(0, 0.2, 0), ang, 0.42)
	# люди при деле: стража у входа, распорядитель на обходе, служитель у ворот гладиаторов
	for sd: float in [-1.0, 1.0]:
		b.actor(Vector3(sd * 0.62, 0, PA - 0.1), 0.0, "Sword_Idle", "soldier")
	b.actor(_dir(deg_to_rad(210.0)) * (WALK_OUT - 0.35) + Vector3(0, walk_y(), 0), deg_to_rad(210.0) + PI, "Idle", "rich")
	b.actor(_dir(deg_to_rad(96.0)) * (PA - 0.3), PI / 2.0, "Idle", "pleb")


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
## Городской цирк (21 × 7,2 м, как тринадцать домов) вдоль X: песчаная дорожка вокруг «спины» — низкой мраморной
## стенки с бассейнами воды, обелиском посредине, статуями и метами на концах. Вдоль длинных сторон — мраморный подиум
## с меандром и два ряда каменных скамей, позади — обход и стена из травертина с пилястрами, расписным фризом
## и медальонами. На западном конце — стартовые ворота (карцеры): шесть закрытых деревянных створок между колонн,
## аттик со статуей, башни с огнём; на восточном — полукруглая стена с триумфальной аркой (в неё видно дорожку).
## Спереди посредине — портал входа с закрытыми створками; сзади посредине — ложа (пульвинар) над рядами.

const SPINE_W := 0.28                       # полуширина спины
const TW := 3.04                            # от оси до подиума трибун (дорожка ≈ 2 м с каждой стороны)
const CPH := 1.2                            # подиум (ступень нижнего ряда)
const C_ROWS := 2
const C_WALL_Z := 4.6                       # середина наружной стены (Wall_01, толщина 0,225)
const C_WALK := C_WALL_Z - 0.1125           # внешний край обхода
const C_WALL_H := 2.56                      # стена позади трибун
const C_HX := 14.58                         # полудлина основания (21 м)
const C_HZ := 5.0                           # полуширина основания (7,2 м)
const XC := -13.18                          # грань стартовых ворот
const XW := XC + TW + 0.12                  # западная мета (центр поворота)
const XE := 11.0                            # восточная мета
const C_CX := (XW + XE) * 0.5               # середина дорожки по X
const C_A := (XE - XW) * 0.5                # меты на C_CX ± C_A
## Лестницы на трибуны (x, обе стороны) и ложа (сзади посредине, |x| < LOGE)
const C_AISLES := [-6.4, 5.2]
const AISLE_W := 0.34
const LOGE := 1.3
const LOGE_Y := CPH + C_ROWS * RR + 0.22
const PORTAL_HW := 1.25                     # полуширина портала входа (SM_Bld_Wall_Door_Large_01)
## Колесницы (CircusShow) в метрах: меты, середина, две полосы дорожки (внутренняя и внешняя — обгон), сколько упряжек,
## их размер (почти в рост: 0,8) и скорость
const RACE := {"A": C_A * S, "cx": C_CX * S, "lane_min": 0.705, "lane_max": 1.685, "teams": 4, "scale": 0.8, "v_straight": 6.2,
	"v_turn": 3.4, "floor": Vector2(C_CX * S, 1.2), "lanes2": true}


static func c_row_front(k: int) -> float:
	return TW + DS + k * (DS + DB)


static func c_step_y(k: int) -> float:
	return CPH + k * RR


static func c_walk_y() -> float:
	return CPH + C_ROWS * RR


static func _circus(b: Bp, fit: Vector2) -> void:
	if fit != Vector2.ZERO:
		var r := _old_rect("circus_fl", fit)
		_forecourt(b, r, Rect2(-C_HX, -C_HZ, 2.0 * C_HX, 2.0 * C_HZ))
		b.door = Vector3(0, 0, r.end.y + 0.6)
	else:
		b.door = Vector3(0, 0, C_HZ + 0.6)
	_plinth(b, -C_HX, C_HX, -C_HZ, C_HZ, 0.03)
	_kerb(b, -C_HX, C_HX, -C_HZ, C_HZ)
	# дорожка: песок, у полукруглого конца — тоже
	CatMonuments._floor(b, CatMonuments.SAND, XC, -TW, XE, TW, 0.04, 8, 2)
	for k in 6:
		var ang := (k + 0.5) * PI / 6.0
		var bs := Basis(Vector3.UP, ang)
		_put(b, "SM_Bld_Base_Floor_01", Transform3D(bs * Basis.from_scale(Vector3(1.75 / 2.5, 1, (TW + 0.1) / 2.5)), Vector3(XE, 0.042 + k * 0.002, 0) + bs * Vector3(-0.875, 0, 0)), CatMonuments.SAND)
	_spine(b)
	for side: float in [-1.0, 1.0]:
		_stand(b, side)
	_loge(b)
	_portal(b)
	_carceres(b)
	_turn_end(b)
	# у входа: колонны с чашами огня у края основания (по ним — фасад: основание встаёт вплотную к дороге)
	for sd: float in [-1.0, 1.0]:
		var q := Vector3(sd * 2.0, 0, C_HZ - 0.2)
		b.add("SM_Bld_Pillar_06", q, 0.0, 0.62)
		b.add("SM_Prop_Brazier_03", q + Vector3(0, 1.86, 0), 0.0, 0.6)
		b.add("SM_Prop_Brazier_03_Insert_01", q + Vector3(0, 1.86, 0), 0.0, 0.6)
	b.light(Vector3(0, 1.5, C_HZ - 0.1))
	# углы у полукруглого конца: кипарисы и цветущие кусты
	for sd: float in [-1.0, 1.0]:
		var q := Vector3(C_HX - 0.6, 0, sd * (C_HZ - 0.65))
		b.add("SM_Env_Tree_Thin_01", q, b.rng.randf() * TAU, 0.42)
		b.add("SM_Env_Garden_Plants_0%d" % (3 if sd > 0.0 else 6), q + Vector3(-0.85, 0, 0), b.rng.randf() * TAU, 0.42)
		b.add("SM_Prop_FlowerBed_01", q + Vector3(-0.2, 0.2, -sd * 0.9), PI / 2.0, 0.5)
	# люди при деле: у входа, распорядитель и гость в ложе, конюх у карцеров
	b.actor(Vector3(1.0, 0, C_HZ - 0.15), 0.0, "Idle", "pleb")
	b.actor(Vector3(-1.0, 0, C_HZ - 0.15), 0.0, "Sword_Idle", "soldier")
	b.actor(Vector3(0.45, LOGE_Y, -(TW + 0.5)), 0.0, "Spell_Simple_Idle", "rich")
	b.actor(Vector3(-0.55, LOGE_Y, -(TW + 0.75)), 0.3, "Idle_Talking", "rich")


## Спина: низкая мраморная стенка с карнизом и двумя бассейнами воды, посредине обелиск на постаменте, по бокам
## статуи и чаши с огнём; на концах — меты: круглый постамент и три конуса
static func _spine(b: Bp) -> void:
	var x0 := XW + 0.75
	var x1 := XE - 0.75
	var h := 0.42
	var cx := C_CX
	_box(b, "#marble", Vector3((x0 + x1) * 0.5, h * 0.5, 0), Vector3(x1 - x0, h, 2.0 * SPINE_W))
	CatMonuments._run(b, "SM_Bld_Wall_Large_Cap_01", Vector3(x0, h, 0), Vector3(1, 0, 0), x1 - x0, 5.0, 0.6, 0.62)
	var top := h + 0.31 * 0.6
	# бассейны: вода между постаментами
	for seg: Array in [[x0 + 0.8, cx - 2.6], [cx + 2.6, x1 - 0.8]]:
		var a: float = seg[0]
		var e: float = seg[1]
		_box(b, "#water", Vector3((a + e) * 0.5, top + 0.005, 0), Vector3(e - a, 0.02, 2.0 * SPINE_W - 0.14))
	b.add("SM_Prop_Plinth_04", Vector3(cx, top, 0), 0.0, 0.6)
	b.add("#d2_obelisk", Vector3(cx, top + 0.4, 0), 0.0, 0.85)
	for dx: float in [-2.1, 2.1]:
		b.add("SM_Prop_Plinth_04", Vector3(cx + dx, top, 0), 0.0, 0.45)
		b.add("SM_Prop_Statue_0%d" % (5 if dx < 0.0 else 6), Vector3(cx + dx, top + 0.3, 0), PI / 2.0 if dx < 0.0 else -PI / 2.0, 0.5)
	for x: float in [x0 + 0.35, x1 - 0.35, cx - 1.1, cx + 1.1]:
		b.add("SM_Prop_Senser_02", Vector3(x, top, 0), 0.0, 0.55)
	for e: float in [XW, XE]:
		b.add("SM_Prop_Plinth_03", Vector3(e, 0, 0), 0.0, 0.85)
		for j in 3:
			b.add("#d2_obelisk", Vector3(e, 0.12, (j - 1) * 0.2), 0.0, 0.42)


## Трибуна вдоль стороны side (+1 — спереди, к +Z): подиум с меандром, два ряда (ступень, скамья #bench), лестницы,
## обход, стена из травертина с пилястрами, расписным фризом и медальонами; сзади — навесы на шестах
static func _stand(b: Bp, side: float) -> void:
	var xa := XC
	var xb := XE
	var L := xb - xa
	var cx := (xa + xb) * 0.5
	# подиум: мрамор с меандром лицом к дорожке
	var n := maxi(1, int(round(L / 2.5)))
	var step := L / n
	var sy := CPH / 1.5
	for i in n:
		var x := xa + i * step if side < 0.0 else xb - i * step
		_put(b, "SM_Bld_Bath_Edge_01", Transform3D(Basis(Vector3.UP, 0.0 if side < 0.0 else PI) * Basis.from_scale(Vector3(step / 2.5, sy, 0.6)), Vector3(x, CPH - 0.205 * sy, side * (TW + 0.15))))
	# ступень нижнего ряда на подиуме
	_box(b, "#marble", Vector3(cx, CPH * 0.5, side * (TW + DS * 0.5)), Vector3(L, CPH, DS))
	# куски скамей между лестницами (и ложей сзади)
	var cuts := [xa]
	for x: float in C_AISLES:
		cuts.append(x - AISLE_W * 0.5)
		cuts.append(x + AISLE_W * 0.5)
	cuts.append(xb)
	for r in C_ROWS:
		var f := c_row_front(r)
		var zc := side * (f + DB * 0.5)
		if r > 0:
			_box(b, "#marble", Vector3(cx, c_step_y(r) * 0.5, side * (f - DS * 0.5)), Vector3(L, c_step_y(r), DS))
		var bh := c_step_y(r) + BH
		for i in range(0, cuts.size(), 2):
			var x0: float = cuts[i]
			var x1: float = cuts[i + 1]
			var parts := [[x0, x1]]
			if side < 0.0 and x0 < LOGE and x1 > -LOGE:
				parts = [[x0, -LOGE], [LOGE, x1]]
			for pt: Array in parts:
				if float(pt[1]) - float(pt[0]) > 0.3:
					_box(b, "#bench", Vector3((float(pt[0]) + float(pt[1])) * 0.5, bh * 0.5, zc), Vector3(float(pt[1]) - float(pt[0]), bh, DB))
		for x: float in C_AISLES:
			_box(b, "#marble", Vector3(x, (c_step_y(r) + RR * 0.5) * 0.5, zc), Vector3(AISLE_W, c_step_y(r) + RR * 0.5, DB))
	# обход позади рядов
	var zb := c_row_front(C_ROWS - 1) + DB
	_box(b, "#marble", Vector3(cx, c_walk_y() * 0.5, side * (zb + C_WALK) * 0.5), Vector3(L, c_walk_y(), C_WALK - zb + 0.02))
	# стена позади: травертин, пилястры, расписной фриз, карниз; спереди посредине — портал входа
	var yaw := 0.0 if side > 0.0 else PI
	var runs := [[xa, -PORTAL_HW], [PORTAL_HW, xb]] if side > 0.0 else [[xa, xb]]
	var letters := ["A", "B", "C", "D"]
	var li := 0 if side > 0.0 else 2
	for rn: Array in runs:
		var r0: float = rn[0]
		var r1: float = rn[1]
		var nw := maxi(1, int(round((r1 - r0) / 2.5)))
		var sw := (r1 - r0) / nw
		for i in nw:
			var x := r0 + i * sw if side > 0.0 else r0 + (i + 1) * sw
			_put(b, "SM_Bld_Wall_01", Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(sw / 2.5, C_WALL_H / T1, 1.0)), Vector3(x, 0, side * C_WALL_Z)), CatMonuments.STONE_WALL)
			_put(b, "SM_Bld_Trim_Large_Single_02", Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(sw / 2.5, 0.42, 0.7)), Vector3(x, C_WALL_H - 0.1, side * (C_WALL_Z + 0.1))), CatMonuments.FRIEZE_RED)
			_put(b, "SM_Bld_Wall_Tiny_01", Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(sw / 2.5, 1.0, 1.7)), Vector3(x, C_WALL_H, side * (C_WALL_Z - 0.03))))
			# посредине пролёта: медальон, под ним — знамя или цветы
			var xc := r0 + (i + 0.5) * sw
			b.add("SM_Bld_Ornament_0%d" % [2, 5, 4][i % 3], Vector3(xc, C_WALL_H - 0.95, side * (C_WALL_Z + 0.13)), yaw, 0.5)
			if i % 2 == 1:
				b.add("SM_Prop_Banner_01_" + String(letters[(li + i) % 4]), Vector3(xc, C_WALL_H - 1.35, side * (C_WALL_Z + 0.16)), yaw, 0.55)
		for i in nw + 1:
			b.add_xf("SM_Bld_Wall_Large_Pillar_01", Transform3D(Basis.from_scale(Vector3(0.3, C_WALL_H / 4.548, 0.3)), Vector3(r0 + i * sw, 0, side * (C_WALL_Z + 0.04))), false)
		li += 1
	# торцы трибун (у карцеров и у полукруглого конца): стена поперёк
	# (запад — лицом к −X, деталь идёт к +Z от ближнего к −Z края; восток — лицом к +X, от дальнего края к −Z)
	var z_lo := minf(side * TW, side * C_WALK)
	var z_hi := maxf(side * TW, side * C_WALK)
	for e: Array in [[xa + 0.11, -PI / 2.0, z_lo], [xb - 0.11, PI / 2.0, z_hi]]:
		_put(b, "SM_Bld_Wall_01", Transform3D(Basis(Vector3.UP, float(e[1])) * Basis.from_scale(Vector3((C_WALK - TW) / 2.5, C_WALL_H / T1, 1.0)), Vector3(float(e[0]), 0, float(e[2]))), CatMonuments.STONE_WALL)
	# навесы над задней трибуной: полосатые полотнища на шестах (терракота и шафран); посредине — ложа
	if side < 0.0:
		var k := 0
		for rn: Array in [[xa + 0.4, -LOGE - 0.5], [LOGE + 0.5, xb - 0.2]]:
			var r0: float = rn[0]
			var r1: float = rn[1]
			var na := maxi(1, int(round((r1 - r0) / 3.6)))
			var aw := (r1 - r0) / na
			for i in na:
				var x := r0 + i * aw
				_put(b, "SM_Prop_Banner_Roof_02", Transform3D(Basis(Vector3.RIGHT, -0.22) * Basis.from_scale(Vector3((aw - 0.1) / 5.1, 1.0, 0.5)), Vector3(x + 0.05, C_WALL_H + 1.5, -(C_WALL_Z - 0.1))), {} if k % 2 == 0 else CatMonuments.VELA_SAFFRON)
				k += 1
			for i in na + 1:
				CatShops._pole(b, Vector3(r0 + i * aw, C_WALL_H, -(C_WALL_Z - 0.12)), 1.65)


## Ложа (пульвинар) посредине задней трибуны: помост над рядами с мраморной оградой, четыре колонны, шафрановый навес,
## знамёна и золотой медальон над ней
static func _loge(b: Bp) -> void:
	var za := TW + 0.05
	var zb := C_WALK
	_box(b, "#marble", Vector3(0, LOGE_Y * 0.5, -(za + zb) * 0.5), Vector3(2.0 * LOGE, LOGE_Y, zb - za))
	CatMonuments._run(b, "SM_Bld_Wall_Balcony_04", Vector3(-LOGE, LOGE_Y, -za - 0.11), Vector3(1, 0, 0), 2.0 * LOGE, 2.6, 0.55, 1.0, CatMonuments.MARBLE_RAIL)
	for x: float in [-LOGE + 0.18, LOGE - 0.18]:
		for z: float in [za + 0.2, zb - 0.18]:
			b.add("SM_Bld_Pillar_06", Vector3(x, LOGE_Y, -z), 0.0, 0.66)
	_put(b, "SM_Prop_Banner_Roof_01", Transform3D(Basis.from_scale(Vector3((2.0 * LOGE + 0.3) / 2.6, 1.0, (zb - za + 0.3) / 2.6)), Vector3(-LOGE - 0.12, LOGE_Y + 0.66 * 3.0 + 0.5, -zb - 0.15)), CatMonuments.VELA_SAFFRON)
	for x: float in [-LOGE + 0.18, LOGE - 0.18]:
		b.add("SM_Prop_Banner_03_B", Vector3(x, LOGE_Y + 1.85, -(za + 0.2) + 0.05), 0.0, 0.5)
	b.add("SM_Bld_Ornament_02", Vector3(0, LOGE_Y + 2.15, -(za + 0.05)), 0.0, 0.6)
	b.add("SM_Prop_Statue_04", Vector3(0, LOGE_Y + 2.62, -(za + zb) * 0.5), 0.0, 0.42)


## Вход с улицы посредине передней стены: портал из травертина с закрытыми деревянными створками (за ними не темно),
## карниз, медальон, знамёна, статуя наверху
static func _portal(b: Bp) -> void:
	var zp := C_WALL_Z + 0.06
	_put(b, "SM_Bld_Wall_Door_Large_01", Transform3D(Basis.IDENTITY, Vector3(-1.25, 0, zp)), CatMonuments.STONE_WALL)
	b.add("SM_Bld_Door_Large_01", Vector3(-0.56, 0, zp), 0.0)
	b.add("SM_Bld_Door_Large_01", Vector3(0.56, 0, zp), PI)
	CatMonuments._run(b, "SM_Bld_Wall_Large_Cap_01", Vector3(-1.45, T1, zp), Vector3(1, 0, 0), 2.9, 5.0, 1.0, 0.8)
	_put(b, "SM_Bld_Wall_01", Transform3D(Basis.from_scale(Vector3(2.6 / 2.5, 0.25, 1.0)), Vector3(-1.3, T1 + 0.3, zp - 0.1)), CatMonuments.STONE_WALL)
	b.add("SM_Bld_Ornament_02", Vector3(0, T1 + 0.68, zp + 0.06), 0.0, 0.5)
	b.add("SM_Prop_Statue_06", Vector3(0, T1 + 1.06, zp - 0.1), 0.0, 0.5)
	for sd: float in [-1.0, 1.0]:
		b.add("SM_Prop_Banner_03_B", Vector3(sd * 1.62, T1 - 0.05, zp + 0.24), 0.0, 0.7)
		b.add_xf("SM_Bld_Wall_Large_Pillar_01", Transform3D(Basis.from_scale(Vector3(0.42, T1 / 4.548, 0.42)), Vector3(sd * 1.42, 0, zp + 0.05)), false)


## Стартовые ворота (карцеры) на западном конце: шесть стойл с закрытыми деревянными створками между колонн (за ними
## не темно), перемычка, аттик с медальоном и статуей; по углам — башни с огнём наверху
static func _carceres(b: Bp) -> void:
	var nb := 6
	var bw := 2.0 * TW / nb
	var ph := 2.1
	for i in nb + 1:
		b.add("SM_Bld_Pillar_06", Vector3(XC, 0, -TW + i * bw), 0.0, 0.7)
	for i in nb:
		var zc := -TW + (i + 0.5) * bw
		_put(b, "SM_Bld_Door_Large_01", Transform3D(Basis(Vector3.UP, PI / 2.0) * Basis.from_scale(Vector3((bw - 0.34) / 1.12, (ph - 0.05) / 2.47, 1.0)), Vector3(XC - 0.05, 0, zc + (bw - 0.34) * 0.5)))
	CatMonuments._run(b, "SM_Bld_Wall_Large_Cap_01", Vector3(XC, ph, TW + 0.3), Vector3(0, 0, -1), 2.0 * TW + 0.6, 5.0, 0.8, 0.7)
	_put(b, "SM_Bld_Wall_01", Transform3D(Basis(Vector3.UP, PI / 2.0) * Basis.from_scale(Vector3((2.0 * TW + 0.4) / 2.5, 0.3, 1.0)), Vector3(XC - 0.12, ph + 0.25, TW + 0.2)), CatMonuments.STONE_WALL)
	_put(b, "SM_Bld_Wall_Tiny_01", Transform3D(Basis(Vector3.UP, PI / 2.0) * Basis.from_scale(Vector3((2.0 * TW + 0.5) / 2.5, 1.0, 1.6)), Vector3(XC - 0.12, ph + 0.25 + 0.9, TW + 0.25)))
	_put(b, "SM_Bld_Trim_Large_Single_02", Transform3D(Basis(Vector3.UP, PI / 2.0) * Basis.from_scale(Vector3((2.0 * TW + 0.4) / 2.5, 0.42, 0.7)), Vector3(XC + 0.02, ph + 0.62, TW + 0.2)), CatMonuments.FRIEZE_RED)
	b.add("SM_Bld_Ornament_02", Vector3(XC + 0.08, ph + 0.6, 0), PI / 2.0, 0.55)
	b.add("SM_Prop_Statue_05", Vector3(XC - 0.15, ph + 1.45, 0), PI / 2.0, 0.55)
	# задняя стена стойл и кровля; снаружи (с запада) — две ниши со статуями и знамя между ними
	_put(b, "SM_Bld_Wall_01", Transform3D(Basis(Vector3.UP, -PI / 2.0) * Basis.from_scale(Vector3((2.0 * TW + 0.4) / 2.5, (ph + 0.3) / T1, 1.0)), Vector3(XC - 1.05, 0, -TW - 0.2)), CatMonuments.STONE_WALL)
	for zc: float in [-1.55, 1.55]:
		_put(b, "SM_Bld_Wall_Alcove_01", Transform3D(Basis(Vector3.UP, -PI / 2.0) * Basis.from_scale(Vector3(0.62, 0.78, 0.62)), Vector3(XC - 1.12, 0, zc - 0.775)))
		b.add("SM_Prop_Statue_0%d" % (3 if zc < 0.0 else 5), Vector3(XC - 1.12 - 0.14, 0.24, zc), -PI / 2.0, 0.62)
	b.add("SM_Prop_Banner_03_B", Vector3(XC - 1.2, 2.35, 0), -PI / 2.0, 0.7)
	_box(b, "#marble", Vector3(XC - 0.55, ph + 0.15, 0), Vector3(1.05, 0.3, 2.0 * TW + 0.4))
	for sd: float in [-1.0, 1.0]:
		var p := Vector3(XC - 0.4, 0, sd * (TW + 0.62))
		b.add_xf("SM_Bld_Wall_Large_Pillar_01", Transform3D(Basis.from_scale(Vector3(1.05, 0.78, 1.05)), p), false)
		b.add("SM_Bld_Wall_Large_Pillar_Cap_01", p + Vector3(0, 4.548 * 0.78, 0), 0.0, 0.85)
		b.add("SM_Prop_Brazier_04", p + Vector3(0, 4.548 * 0.78 + 0.4, 0), 0.0, 0.52)
		b.add("SM_Prop_Brazier_04_Insert_01", p + Vector3(0, 4.548 * 0.78 + 0.4, 0), 0.0, 0.52)
		b.add("SM_Prop_Banner_03_" + ("D" if sd > 0.0 else "F"), p + Vector3(0.52, 3.15, 0), PI / 2.0, 0.6)
		b.add("SM_Prop_Banner_03_" + ("D" if sd > 0.0 else "F"), p + Vector3(-0.52, 3.15, 0), -PI / 2.0, 0.6)


## Полукруглый конец: стена из травертина по дуге с фризом и карнизом, посредине — триумфальная арка с аттиком
## и статуей (в арку видно дорожку: светло)
static func _turn_end(b: Bp) -> void:
	var keep := b.base
	b.base = keep * Transform3D(Basis.IDENTITY, Vector3(XE, 0, 0))
	var r := TW + 0.12
	var w := 2.0 * r * tan(PI / 16.0) + 0.05
	for i in 8:
		var ang := (i + 0.5) * PI / 8.0
		if i == 3 or i == 4:
			continue
		_ring(b, "SM_Bld_Wall_01", ang, r, 0.0, w, C_WALL_H / T1, 1.0, CatMonuments.STONE_WALL)
		_ring(b, "SM_Bld_Trim_Large_Single_02", ang, r + 0.1, C_WALL_H - 0.1, w, 0.42, 0.7, CatMonuments.FRIEZE_RED)
		_ring(b, "SM_Bld_Wall_Tiny_01", ang, r - 0.03, C_WALL_H, w, 1.0, 1.7)
	_ring(b, "SM_Bld_Wall_Door_Double_01", PI / 2.0, r + 0.05, 0.0, 2.5)
	_ring(b, "SM_Bld_Wall_Large_Cap_01", PI / 2.0, r + 0.05, T1, 2.7, 1.0, 0.8, {}, false, 5.0)
	_ring(b, "SM_Bld_Wall_01", PI / 2.0, r + 0.05, T1 + 0.3, 2.4, 0.25, 1.0, CatMonuments.STONE_WALL)
	b.add("SM_Prop_Statue_06", Vector3(r + 0.05, T1 + 1.05, 0), PI / 2.0, 0.55)
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
		if ais[2] == "aisle" and float(ais[1]) - float(ais[0]) > 20.0:
			# широкая лестница (сзади, две части): идти по ближней к ряду её половине
			tm = deg_to_rad(float(ais[1]) - 7.5) if at_start else deg_to_rad(float(ais[0]) + 7.5)
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
	var wy := c_walk_y() * S
	for side: float in [-1.0, 1.0]:
		var F := Vector3(0, 0, -side)
		var D := -F
		var zwalk := side * (c_row_front(C_ROWS - 1) + DB + 0.12) * S
		# куски скамьи между лестницами (и ложей сзади); у каждого — ближняя лестница
		var cuts := [XC * S]
		for x: float in C_AISLES:
			cuts.append((x - AISLE_W * 0.5) * S)
			cuts.append((x + AISLE_W * 0.5) * S)
		cuts.append(XE * S)
		var runs := []
		for i in range(0, cuts.size(), 2):
			var x0: float = cuts[i]
			var x1: float = cuts[i + 1]
			if side < 0.0 and x0 < LOGE * S and x1 > -LOGE * S:
				runs.append([x0, -LOGE * S - 0.05])
				runs.append([LOGE * S + 0.05, x1])
			else:
				runs.append([x0, x1])
		for r in C_ROWS:
			var top := (c_step_y(r) + BH) * S
			var fy := c_step_y(r) * S
			var zf := side * c_row_front(r) * S                  # передний край скамьи
			var zw := zf - side * 0.10                           # где идут вдоль ряда
			var gi := 0
			for rn: Array in runs:
				var x0: float = rn[0]
				var x1: float = rn[1]
				var L := x1 - x0
				var n := int(floor((L - 0.12) / Spectacle.SPACING))
				if n <= 0:
					gi += 1
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
					# из-под обхода у лестницы — на обход — вниз по полуступеням лестницы до своего ряда — вдоль ряда
					var path := PackedVector3Array([Vector3(xa, wy - 0.9, zwalk), Vector3(xa, wy, zwalk)])
					for j in range(C_ROWS - 1, r - 1, -1):
						path.append(Vector3(xa, (c_step_y(j) + RR * 0.5) * S, side * (c_row_front(j) + DB * 0.5) * S))
						path.append(Vector3(xa, c_step_y(j) * S, (zw if j == r else side * (c_row_front(j) - DS * 0.5) * S)))
					var m := maxi(1, int(absf(x - xa) / 0.25))
					for q in range(1, m + 1):
						path.append(Vector3(lerpf(xa, x, float(q) / m), fy, zw))
					path.append(Vector3(root.x, fy, root.z))
					list.append({"root": root, "yaw": atan2(F.x, F.z), "row": r, "path": path, "far": absf(x - xa)})
				list.sort_custom(func(p, q): return p["far"] > q["far"])
				var ids := []
				for s in list:
					ids.append(seats_a.size())
					seats_a.append(s)
				lay["groups"]["circus%d|%d|%d" % [int(side), r, gi]] = ids
				gi += 1
