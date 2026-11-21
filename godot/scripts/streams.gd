class_name Streams
extends RefCounted
## Ручьи (13.11, владелец: «добавить на карту ручейков»): узкие петляющие ручьи от родника на склоне к пруду, в мягкой
## ложбине с пологими берегами, мокрым песком у воды. Вода — та же, что в прудах (уровень Land.WATER_Y): ручей — это
## ложбина ниже уровня воды. Поэтому всё, что игра знает о воде (нельзя строить, жители обходят, деревья не растут,
## кувшинки и камыши у берега), работает и для ручьёв само.
##
## Сохранения. Земля в сохранении — только отличия от исходной карты (Land.save_changes): ручей нельзя просто дописать
## в исходную карту — у старых городов под домами и дорогами вдруг оказалась бы вода. Поэтому ручьи прокладываются
## ПОСЛЕ того, как город построен или загружен, и только там, где все клетки ложбины (с запасом в 3 м) свободны:
## ни построек, ни дорог игрока, ни правок земли (клетка такая же, как на исходной карте). Какие ручьи легли — пишется
## в сохранение (Land.streams): в следующий раз ложатся ровно они, без новых проверок (под водой построить нельзя,
## а клетки, которые игрок поменял у берега, не трогаются). Новая игра — все ручьи (они не заходят на её первую землю).
## Большую дорогу ручей пересекает под мостом: клетки дороги остаются как были (насыпь), по бокам — арки моста.

const RIVER_IDS := [7, 8]
## Начало реки за краем карты (с севера, z растёт к карте) и выход из озера за восточный край
const RIVER_FAR := [Vector2(104, -1500), Vector2(118, -1150), Vector2(100, -850), Vector2(122, -600), Vector2(110, -420), Vector2(130, -290),
	Vector2(116, -190), Vector2(134, -110), Vector2(124, -50), Vector2(130, -14), Vector2(129, 0)]
const RIVER_OUT := [Vector2(420, 20), Vector2(470, 10), Vector2(540, -6), Vector2(620, -18), Vector2(700, -26), Vector2(820, -32), Vector2(960, -36)]

const LIST := [
	# запад: с холмов у края — в пруд (102, 124)
	{"id": 1, "w": 1.0, "pts": [Vector2(50, 68), Vector2(60, 82), Vector2(73, 95), Vector2(86, 107), Vector2(96, 119)]},
	# юг: от родника за городом — в большой южный пруд (176, 262)
	{"id": 2, "w": 1.2, "pts": [Vector2(236, 336), Vector2(224, 320), Vector2(208, 305), Vector2(196, 291), Vector2(187, 277)]},
	# восток (дальнее кольцо) — в пруд (338, 300)
	{"id": 3, "w": 1.1, "pts": [Vector2(352, 192), Vector2(346, 218), Vector2(351, 244), Vector2(343, 266), Vector2(337, 280)]},
	# дальний запад — в пруд (40, 250)
	{"id": 4, "w": 0.9, "pts": [Vector2(30, 176), Vector2(36, 198), Vector2(31, 219), Vector2(38, 235)]},
	# восточнее первой земли — в пруд (260, 214)
	{"id": 5, "w": 1.0, "pts": [Vector2(318, 148), Vector2(303, 163), Vector2(289, 181), Vector2(277, 197), Vector2(268, 206)]},
	# север: через большую дорогу (под мостом) — в заводь у въезда
	{"id": 6, "w": 1.1, "pts": [Vector2(124, 22), Vector2(144, 29), Vector2(165, 37), Vector2(183, 42), Vector2(201, 44), Vector2(218, 46), Vector2(229, 48)],
		"pool": Vector3(235.0, 49.0, 7.0)},
	# 15.11 РЕКА (владелец: «речка должна идти буквально из бесконечности к нам и в озерце какое-то»): приходит из-за
	# горизонта на севере (за краем карты земля вырезана долиной — Land.far_height → far_carve, вода — полоса far_ribbons),
	# петляет, идёт под большой дорогой (римский мост) и впадает в озеро на северо-востоке; из озера вытекает на восток —
	# за край карты и дальше за горизонт. Два пути: 7 — целиком, 8 — короткий (кончается озером до дороги), если на
	# длинном пути у старого города уже что-то построено. Кладётся только по свободной земле (Streams.safe)
	{"id": 7, "river": true, "w": 3.6, "noise": 2.2, "bed": 0.85, "pts": RIVER_FAR + [Vector2(131, 8), Vector2(138, 18), Vector2(150, 26), Vector2(164, 31),
		Vector2(178, 36), Vector2(192, 40), Vector2(206, 41), Vector2(220, 38), Vector2(236, 33), Vector2(252, 34), Vector2(268, 39), Vector2(284, 38),
		Vector2(300, 34), Vector2(320, 30), Vector2(340, 25), Vector2(362, 24), Vector2(384, 27)] + RIVER_OUT, "pool": Vector3(300.0, 32.0, 19.0)},
	{"id": 8, "river": true, "w": 3.4, "noise": 2.0, "bed": 0.85, "pts": RIVER_FAR + [Vector2(131, 8), Vector2(136, 16), Vector2(142, 24), Vector2(148, 30)],
		"pool": Vector3(150.0, 32.0, 12.0)},
]
const FAR_BED := 0.95      # глубина реки за краем карты
const BED := 0.45          # глубина посередине ручья (под уровнем воды)
const SHORE := 0.7         # полоса мокрого песка у воды, м
const SLOPE := 0.42        # крутизна берега: метров вверх на метр в сторону
const REACH := 12.0        # дальше от середины земля не трогается
const MARGIN := 3.0        # запас вокруг ложбины: там тоже не должно быть построек и дорог игрока
const SOFT := 0.3          # мягкость перехода ложбины в луг (smooth-min)

static var _plans := {}
## CIVCITY_RIVER=0 — без реки (снимки «было/стало» в одной сборке)
static var river_on := OS.get_environment("CIVCITY_RIVER") != "0"


static func def_of(id: int) -> Dictionary:
	for d: Dictionary in LIST:
		if int(d["id"]) == id:
			return d
	return {}


static func ids() -> Array:
	var out := []
	for d: Dictionary in LIST:
		out.append(int(d["id"]))
	return out


static func _cr(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


## Линия ручья (точки через ~1 м, от родника к устью) и полуширина воды в каждой точке
static func plan(id: int) -> Dictionary:
	if _plans.has(id):
		return _plans[id]
	var d := def_of(id)
	var cps: Array = d["pts"]
	var raw := PackedVector2Array()
	for i in cps.size() - 1:
		var p0: Vector2 = cps[maxi(i - 1, 0)]
		var p1: Vector2 = cps[i]
		var p2: Vector2 = cps[i + 1]
		var p3: Vector2 = cps[mini(i + 2, cps.size() - 1)]
		var far := (p1.y < -30.0 and p2.y < -30.0) or (p1.x > Land.SIZE + 30.0 and p2.x > Land.SIZE + 30.0)
		var steps := maxi(2, int(p1.distance_to(p2) / (4.0 if far else 1.0)))        # за краем карты точки через 4 м
		for s in steps:
			raw.append(_cr(p0, p1, p2, p3, float(s) / steps))
	raw.append(cps[cps.size() - 1])
	var total := 0.0
	for i in range(1, raw.size()):
		total += raw[i].distance_to(raw[i - 1])
	var fn := FastNoiseLite.new()
	fn.seed = 100 + id
	fn.frequency = 0.05
	var pts := PackedVector2Array()
	var wid := PackedFloat32Array()
	var shr := PackedFloat32Array()                          # ширина полосы мокрого песка (у реки — то уже, то отмелью шире)
	var acc := 0.0
	var w0 := float(d["w"])
	var amp := float(d.get("noise", 3.2))                     # на сколько шум уводит русло вбок
	var river := bool(d.get("river", false))
	for i in raw.size():
		if i > 0:
			acc += raw[i].distance_to(raw[i - 1])
		var tan := (raw[mini(i + 1, raw.size() - 1)] - raw[maxi(i - 1, 0)]).normalized()
		var nor := Vector2(-tan.y, tan.x)
		var fade := smoothstep(0.0, 10.0, acc) * smoothstep(0.0, 6.0, total - acc)
		pts.append(raw[i] + nor * fn.get_noise_1d(acc) * amp * fade)
		var w := w0 * (0.78 + 0.44 * (fn.get_noise_1d(acc * 1.9 + 71.0) * 0.5 + 0.5))
		if not river:
			w *= lerpf(0.5, 1.0, smoothstep(0.0, 12.0, acc))            # у родника — тоньше
			w *= 1.0 + 0.5 * smoothstep(total - 10.0, total, acc)          # к устью — шире
		wid.append(w)
		shr.append(lerpf(0.7, 3.0, smoothstep(-0.15, 0.55, fn.get_noise_1d(acc * 0.7 + 311.0))) if river else SHORE)
	var p := {"id": id, "sh": shr, "pts": pts, "w": wid, "len": total, "pool": d.get("pool", Vector3.ZERO), "river": river}
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for q in pts:
		lo = lo.min(q)
		hi = hi.max(q)
	var pl: Vector3 = p["pool"]
	if pl.z > 0.0:
		lo = lo.min(Vector2(pl.x, pl.y) - Vector2.ONE * pl.z)
		hi = hi.max(Vector2(pl.x, pl.y) + Vector2.ONE * pl.z)
	var pad := REACH + MARGIN + 1.0
	p["lo"] = (lo - Vector2.ONE * pad).floor().max(Vector2.ZERO)
	p["hi"] = (hi + Vector2.ONE * pad).ceil().min(Vector2.ONE * Land.SIZE)
	if river:
		_legs(p)
	_plans[id] = p
	return p


## Участки реки за краем карты: «w» — с севера (по z вверх до края), «e» — выход из озера на восток (по x). Для каждого:
## a — координата вдоль (растёт), b — поперёк, w — полуширина, s — путь от края карты, м (долина и вода считаются по ним)
static func _legs(p: Dictionary) -> void:
	var pts: PackedVector2Array = p["pts"]
	var wid: PackedFloat32Array = p["w"]
	var n := pts.size()
	var iw := 0
	while iw < n and pts[iw].y < 3.0:
		iw += 1
	var ie := n - 1
	while ie > 0 and pts[ie].x > Land.SIZE - 3.0:
		ie -= 1
	var legs := {}
	var la := PackedFloat32Array()
	var lb := PackedFloat32Array()
	var lw := PackedFloat32Array()
	var ls := PackedFloat32Array()
	var amax := -INF
	for i in range(0, mini(iw + 1, n)):
		amax = maxf(amax, pts[i].y)
		la.append(amax)
		lb.append(pts[i].x)
		lw.append(wid[i])
		ls.append(maxf(-pts[i].y, 0.0))
	legs["w"] = {"a": la, "b": lb, "w": lw, "s": ls, "axis": 1}
	if ie < n - 2:
		var ea := PackedFloat32Array()
		var eb := PackedFloat32Array()
		var ew := PackedFloat32Array()
		var es := PackedFloat32Array()
		amax = -INF
		for i in range(ie, n):
			amax = maxf(amax, pts[i].x)
			ea.append(amax)
			eb.append(pts[i].y)
			ew.append(wid[i])
			es.append(maxf(pts[i].x - Land.SIZE, 0.0))
		legs["e"] = {"a": ea, "b": eb, "w": ew, "s": es, "axis": 0}
	p["legs"] = legs


## Профиль ложбины: высота на расстоянии d от середины ручья полушириной w (bed — глубина посередине)
static func profile(d: float, w: float, bed := BED, shore := SHORE) -> float:
	if d < w:
		var t := d / w
		return Land.WATER_Y - bed + (bed - 0.18) * t * t
	var e := d - w
	if e < shore:
		return Land.WATER_Y + 0.08 + e / shore * 0.17
	return Land.WATER_Y + 0.25 + (e - shore) * SLOPE


## Расстояние до середины ручья и полуширина в ближайшей точке (по отрезкам рядом — корзины 8 м)
static func _buckets(p: Dictionary) -> Dictionary:
	if p.has("bk"):
		return p["bk"]
	var bk := {}
	var pts: PackedVector2Array = p["pts"]
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var c0 := Vector2i(int(floor(minf(a.x, b.x) / 8.0)), int(floor(minf(a.y, b.y) / 8.0)))
		var c1 := Vector2i(int(floor(maxf(a.x, b.x) / 8.0)), int(floor(maxf(a.y, b.y) / 8.0)))
		for cy in range(c0.y, c1.y + 1):
			for cx in range(c0.x, c1.x + 1):
				var key := Vector2i(cx, cy)
				if not bk.has(key):
					bk[key] = PackedInt32Array()
				var arr: PackedInt32Array = bk[key]
				arr.append(i)
				bk[key] = arr
	p["bk"] = bk
	return bk


## [расстояние, полуширина, номер отрезка] до линии ручья от точки q (дальше REACH + MARGIN + 8 — INF)
static func nearest(p: Dictionary, q: Vector2) -> Array:
	var bk := _buckets(p)
	var pts: PackedVector2Array = p["pts"]
	var wid: PackedFloat32Array = p["w"]
	var best := INF
	var bw := 1.0
	var bi := -1
	var c := Vector2i(int(floor(q.x / 8.0)), int(floor(q.y / 8.0)))
	var r := int(ceil((REACH + MARGIN) / 8.0))
	var seen := {}
	for cy in range(c.y - r, c.y + r + 1):
		for cx in range(c.x - r, c.x + r + 1):
			var key := Vector2i(cx, cy)
			if not bk.has(key):
				continue
			for i: int in bk[key]:
				if seen.has(i):
					continue
				seen[i] = true
				var a := pts[i]
				var b := pts[i + 1]
				var ab := b - a
				var t := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
				var dd := q.distance_to(a + ab * t)
				if dd < best:
					best = dd
					bw = lerpf(wid[i], wid[i + 1], t)
					bi = i
	return [best, bw, bi]


## Высота ложбины в точке q (INF — далеко от ручья): ручей и заводь в конце
static func target_at(p: Dictionary, q: Vector2) -> float:
	var nr := nearest(p, q)
	var t := INF
	if float(nr[0]) < REACH + MARGIN:
		t = profile(float(nr[0]), float(nr[1]))
	var pl: Vector3 = p["pool"]
	if pl.z > 0.0:
		var dp := q.distance_to(Vector2(pl.x, pl.y))
		if dp < pl.z + REACH:
			t = minf(t, profile(dp, pl.z, 0.85))
	return t


## Грубое поле (узлы через 1 м в рамке ручья): расстояние до середины ручья и полуширина воды в ближайшей точке.
## Считается раскладкой отрезков (через ~2 м) по узлам рядом с каждым — быстро; клетки 25 см берут его билинейно
static func _field(p: Dictionary) -> Dictionary:
	if p.has("field"):
		return p["field"]
	var lo: Vector2 = p["lo"]
	var hi: Vector2 = p["hi"]
	var W := int(hi.x - lo.x) + 1
	var H := int(hi.y - lo.y) + 1
	var dist := PackedFloat32Array()
	dist.resize(W * H)
	dist.fill(1.0e6)
	var wd := PackedFloat32Array()
	wd.resize(W * H)
	wd.fill(1.0)
	var shf := PackedFloat32Array()
	shf.resize(W * H)
	shf.fill(SHORE)
	var pts: PackedVector2Array = p["pts"]
	var wid: PackedFloat32Array = p["w"]
	var shr: PackedFloat32Array = p["sh"]
	var R := REACH + MARGIN + 1.5
	var i := 0
	var stp := 3 if bool(p.get("river", false)) else 2          # хорда: реку считаем через 3 точки (быстрее, она длинная)
	while i < pts.size() - 1:
		var j := mini(i + stp, pts.size() - 1)
		var a := pts[i]
		var b := pts[j]
		var ab := b - a
		var l2 := maxf(ab.length_squared(), 1e-6)
		var x0 := maxi(int(floor(minf(a.x, b.x) - R - lo.x)), 0)
		var x1 := mini(int(ceil(maxf(a.x, b.x) + R - lo.x)), W - 1)
		var y0 := maxi(int(floor(minf(a.y, b.y) - R - lo.y)), 0)
		var y1 := mini(int(ceil(maxf(a.y, b.y) + R - lo.y)), H - 1)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var q := lo + Vector2(x, y)
				var t := clampf((q - a).dot(ab) / l2, 0.0, 1.0)
				var dd := q.distance_to(a + ab * t)
				var n := y * W + x
				if dd < dist[n]:
					dist[n] = dd
					wd[n] = lerpf(wid[i], wid[j], t)
					shf[n] = lerpf(shr[i], shr[j], t)
		i = j
	var pl: Vector3 = p["pool"]
	var pd := PackedFloat32Array()
	var fnp := FastNoiseLite.new()
	fnp.seed = 900 + int(p["id"])
	fnp.frequency = 0.05
	if pl.z > 0.0:
		pd.resize(W * H)
		for y in H:
			for x in W:
				var qp := lo + Vector2(x, y)
				var dd := qp.distance_to(Vector2(pl.x, pl.y))
				if bool(p.get("river", false)):
					dd /= 1.0 + 0.2 * fnp.get_noise_2d(qp.x, qp.y)          # берег озера — неровный, не круг
				pd[y * W + x] = dd
	var fd := {"W": W, "H": H, "d": dist, "w": wd, "sh": shf, "pd": pd}
	p["field"] = fd
	return fd


static func _bilerp(fd: Dictionary, key: String, lo: Vector2, q: Vector2) -> float:
	var W: int = fd["W"]
	var H: int = fd["H"]
	var a: PackedFloat32Array = fd[key]
	var u := clampf(q.x - lo.x, 0.0, W - 1.001)
	var v := clampf(q.y - lo.y, 0.0, H - 1.001)
	var i := int(u)
	var j := int(v)
	var fu := u - i
	var fv := v - j
	var a00 := a[j * W + i]
	var a10 := a[j * W + i + 1]
	var a01 := a[(j + 1) * W + i]
	var a11 := a[(j + 1) * W + i + 1]
	return lerpf(lerpf(a00, a10, fu), lerpf(a01, a11, fu), fv)


static func smin(a: float, b: float, k: float) -> float:
	var hh := maxf(k - absf(a - b), 0.0) / k
	return minf(a, b) - hh * hh * k * 0.25


## Клетки ручья на карте: {k: новая высота} — только где земля опускается; клетки дорог исходной карты (насыпь
## под мостом) — отдельно в "road"; "band" — квадраты 1 м всей полосы с запасом (для проверки «свободно ли»).
## Исходная карта у всех городов одна (Land.generate) — посчитанное держим (до прокладки этого ручья)
static var _cells := {}
static func cells(land: Land, id: int) -> Dictionary:
	if _cells.has(id):
		return _cells[id]
	var p := plan(id)
	var fd := _field(p)
	var lo: Vector2 = p["lo"]
	var W: int = fd["W"]
	var H: int = fd["H"]
	var dist: PackedFloat32Array = fd["d"]
	var wd: PackedFloat32Array = fd["w"]
	var pdist: PackedFloat32Array = fd["pd"]
	var pl: Vector3 = p["pool"]
	var shd: PackedFloat32Array = fd["sh"]
	var bedr := float(def_of(id).get("bed", BED))              # у реки глубже
	var river := bool(p["river"])
	var pbed := 1.4 if river else 0.85
	var psh := 1.8 if river else SHORE
	var out := {}
	var road := []
	var rvis := {}                                  # высота ложбины под дорогой (для видимой земли под мостом)
	var band := PackedInt32Array()                  # клетки (i, j) левого верхнего угла квадратов 1 м полосы ручья — для проверки «свободно»
	var R := REACH + MARGIN
	var per := int(round(1.0 / Land.CELL))
	for y in H - 1:
		for x in W - 1:
			var n := y * W + x
			var dmin := minf(minf(dist[n], dist[n + 1]), minf(dist[n + W], dist[n + W + 1]))
			var pmin := INF
			if not pdist.is_empty():
				pmin = minf(minf(pdist[n], pdist[n + 1]), minf(pdist[n + W], pdist[n + W + 1]))
				dmin = minf(dmin, pmin - pl.z)
			if dmin > R:
				continue
			var ci := int((lo.x + x) / Land.CELL)
			var cj := int((lo.y + y) / Land.CELL)
			if not land.inside(ci, cj) or not land.inside(ci + per - 1, cj + per - 1):
				continue
			band.append(land.idx(ci, cj))
			# квадрат целиком выше ложбины (самое низкое дно в нём — выше земли) — клетки не трогаем
			var wmax := maxf(maxf(wd[n], wd[n + 1]), maxf(wd[n + W], wd[n + W + 1]))
			var shmax := maxf(maxf(shd[n], shd[n + 1]), maxf(shd[n + W], shd[n + W + 1]))
			var tmin := profile(maxf(minf(minf(dist[n], dist[n + 1]), minf(dist[n + W], dist[n + W + 1])) - 0.1, 0.0), wmax, bedr, shmax)
			if pmin < INF:
				tmin = minf(tmin, profile(maxf(pmin - 0.1, 0.0), pl.z, pbed, psh))
			var bmax := maxf(maxf(land.base_h[land.idx(ci, cj)], land.base_h[land.idx(ci + per - 1, cj)]),
				maxf(land.base_h[land.idx(ci, cj + per - 1)], land.base_h[land.idx(ci + per - 1, cj + per - 1)]))
			if tmin > bmax + SOFT + 0.2:
				continue
			for sj in per:
				for si in per:
					var i := ci + si
					var j := cj + sj
					var q := land.cell_center(i, j)
					var dd := _bilerp(fd, "d", lo, q)
					var t := INF
					if dd < R:
						t = profile(dd, _bilerp(fd, "w", lo, q), bedr, _bilerp(fd, "sh", lo, q))
					if not pdist.is_empty():
						var dp := _bilerp(fd, "pd", lo, q)
						if dp < pl.z + R:
							t = minf(t, profile(dp, pl.z, pbed, psh))
					var k := land.idx(i, j)
					var y0 := land.base_h[k]
					if t > y0 + SOFT:
						continue
					var y1 := smin(y0, t, SOFT)
					if y1 > y0 - 0.004:
						continue
					if Land.walk_kind(land.base_kind[k]):
						if y1 < Land.WATER_Y + 0.3:
							road.append(k)                    # дорога исходной карты над ручьём — насыпь под мостом
							rvis[k] = y1
						continue
					out[k] = y1
	var res := {"cells": out, "road": road, "band": band, "rvis": rvis}
	_cells[id] = res
	return res


## Можно ли проложить ручей в этом городе: все клетки ложбины и запаса — без построек, без дорог игрока,
## без правок земли (как на исходной карте), не под арками акведука
static func safe(land: Land, id: int, cs := {}) -> bool:
	if cs.is_empty():
		cs = cells(land, id)
	var river := bool(def_of(id).get("river", false))
	for k: int in cs["cells"]:
		if land.occ[k] != 0 or land.kind[k] != land.base_kind[k] or land.h[k] != land.base_h[k] or land.deco[k] != 0:
			return false
		if land.under.has(k):
			return false
		# река не заходит на землю игрока: она не должна резать его участки и отрезать их от дороги
		if river and land.is_owned(land.cell_center(k % Land.N, k / Land.N)):
			return false
	var per := int(round(1.0 / Land.CELL))
	for k0: int in cs["band"]:
		for sj in per:
			for si in per:
				var k := k0 + sj * Land.N + si
				if land.occ[k] != 0 or (Land.walk_kind(land.kind[k]) and land.kind[k] != land.base_kind[k]) or land.under.has(k):
					return false
	for k: int in cs["road"]:
		if land.occ[k] > 0:
			return false
	return true


## Проложить ручьи ids: опустить землю ложбины (и в исходной карте — чтобы сохранение хранило только правки игрока).
## Клетки, которые игрок уже поменял (не как на исходной карте), не трогаются. Сетку кусков и ходьбы — пометить
static func apply(land: Land, list: Array) -> void:
	land.bridges = []
	for id: int in list:
		if def_of(id).is_empty():
			continue
		var cs := cells(land, id)
		var dirty := {}
		var cd: Dictionary = cs["cells"]
		for k: int in cd:
			var y: float = cd[k]
			var mine := land.h[k] == land.base_h[k] and land.kind[k] == land.base_kind[k]
			if y >= land.base_h[k]:
				continue                                  # уже ниже (другая вода тут прошла)
			land.base_h[k] = y
			if mine:
				land.h[k] = y
			dirty[Vector2i((k % Land.N) / Land.CH, (k / Land.N) / Land.CH)] = true
		var rv: Dictionary = cs["rvis"]
		if bool(def_of(id).get("river", false)):
			for k: int in rv:
				land.set_vis(k, rv[k])                    # под мостом видимая земля — дно реки (дорога остаётся насыпью для ходьбы)
				dirty[Vector2i((k % Land.N) / Land.CH, (k / Land.N) / Land.CH)] = true
		for ch: Vector2i in dirty:
			land.dirty[ch] = true
			land.dirty_walk[ch] = true
			# стенки уступов на краю куска рисует соседний кусок
			for dch: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n2 := ch + dch
				if n2.x >= 0 and n2.y >= 0 and n2.x < Land.CHN and n2.y < Land.CHN:
					land.dirty[n2] = true
		if not land.streams.has(id):
			land.streams.append(id)
		var rd: Array = cs["road"]
		if not rd.is_empty():
			var br := _bridge(land, id, rd)
			if bool(def_of(id).get("river", false)):
				br["river"] = true
				br["cells"] = rd
			land.bridges.append(br)
	land.gen += 1


## Видимое русло под мостом, с плавным переходом к прежним берегам.
static func _open_bridge_bed(land: Land, center: Vector2, road_dir: Vector2, half: float, river: bool) -> void:
	var cross := Vector2(road_dir.y, -road_dir.x)
	var wet_edge := Land.ROAD_R + 0.75
	var bank_edge := wet_edge + (3.0 if river else 0.9)
	var reach := cross.abs() * bank_edge + road_dir.abs() * (half + 0.8)
	var lo := land.cell(center - reach)
	var hi := land.cell(center + reach)
	for j in range(lo.y, hi.y + 1):
		for i in range(lo.x, hi.x + 1):
			var delta := land.cell_center(i, j) - center
			var weight := (1.0 - smoothstep(wet_edge, bank_edge, absf(delta.dot(cross))))
			weight *= 1.0 - smoothstep(half, half + 0.8, absf(delta.dot(road_dir)))
			var k := land.idx(i, j)
			if is_zero_approx(weight) or land.occ[k] != 0:
				continue
			if not Land.walk_kind(land.base_kind[k]) and (land.h[k] != land.base_h[k] or land.kind[k] != land.base_kind[k]):
				continue
			var y := land._vh(k)
			if y > Land.WATER_Y - 0.42:
				land.set_vis(k, lerpf(y, Land.WATER_Y - 0.42, weight))
	if not river:
		var ch0 := (lo - Vector2i.ONE * Land.RS) / Land.CH
		var ch1 := (hi + Vector2i.ONE * Land.RS) / Land.CH
		for j in range(ch0.y, ch1.y + 1):
			for i in range(ch0.x, ch1.x + 1):
				land.bridge_road_chunks[Vector2i(i, j)] = true


## Мост там, где ручей проходит под дорогой исходной карты: середина, направление ручья, высота дороги, пролёт
static func _bridge(land: Land, id: int, road: Array) -> Dictionary:
	var c := Vector2.ZERO
	var y := 0.0
	for k: int in road:
		c += land.cell_center(k % Land.N, k / Land.N)
		y += land.hq(k)
	c /= road.size()
	y /= road.size()
	var p := plan(id)
	var nr := nearest(p, c)
	var pts: PackedVector2Array = p["pts"]
	var i: int = maxi(int(nr[2]), 0)
	var dir := (pts[mini(i + 1, pts.size() - 1)] - pts[i]).normalized()
	return {"id": id, "pos": c, "dir": dir, "y": y, "w": float(nr[1])}


## Какие ручьи проложить в этом городе: из сохранения — ровно те (saved != null), иначе — все, что свободны.
## Река (15.11): новая игра — целиком; в сохранении без реки — первый путь, где всё свободно (длинный, потом короткий);
## есть река — северный ручей (6) не нужен: у реки свой путь под дорогой
static func choose(land: Land, saved) -> Array:
	var out := []
	if saved is Array:
		for v in saved:
			out.append(int(v))
	else:
		for id: int in ids():
			if not RIVER_IDS.has(id) and safe(land, id):
				out.append(id)
	var has_river := false
	for rid: int in RIVER_IDS:
		if not river_on:
			out.erase(rid)
		has_river = has_river or out.has(rid)
	if not has_river and river_on:
		for rid: int in RIVER_IDS:
			if safe(land, rid):
				out.append(rid)
				has_river = true
				break
	if has_river:
		out.erase(6)
	return out


# ---------- река за краем карты ----------

static var _far_id := 0                  # какой путь реки проложен (0 — реки нет: за краем карты обычные холмы)


static func set_far(list: Array) -> void:
	_far_id = 0
	for rid: int in RIVER_IDS:
		if list.has(rid):
			_far_id = rid


static func far_on() -> bool:
	return _far_id != 0


static func _leg_at(leg: Dictionary, a: float) -> Array:
	var A: PackedFloat32Array = leg["a"]
	if A.size() < 2 or a < A[0] or a > A[A.size() - 1]:
		return []
	var i := clampi(A.bsearch(a) - 1, 0, A.size() - 2)
	var t := clampf((a - A[i]) / maxf(A[i + 1] - A[i], 1e-4), 0.0, 1.0)
	var B: PackedFloat32Array = leg["b"]
	var W: PackedFloat32Array = leg["w"]
	var S: PackedFloat32Array = leg["s"]
	return [lerpf(B[i], B[i + 1], t), lerpf(W[i], W[i + 1], t), lerpf(S[i], S[i + 1], t), (B[i + 1] - B[i]) / maxf(A[i + 1] - A[i], 1e-4)]


## Уровень воды реки на пути s от края карты: у края — как везде, дальше медленно поднимается (река течёт с гор)
static func far_level(s: float) -> float:
	return Land.WATER_Y + minf(0.011 * maxf(s - 20.0, 0.0), 7.0)


## Полуширина воды реки на пути s от края карты: вдали шире (сетка пейзажа там крупнее — узкую реку не нарисовать)
static func far_width(w: float, s: float) -> float:
	return w * (1.0 + 0.8 * smoothstep(80.0, 500.0, s))


## Что за краем карты у реки в точке (x, z): [расстояние до середины, полуширина воды, уровень, путь от края] или []
static func _far_probe(x: float, z: float) -> Array:
	if _far_id == 0:
		return []
	var legs: Dictionary = plan(_far_id)["legs"]
	var best := []
	var bd := INF
	for key: String in legs:
		if (key == "w" and z > 1.0) or (key == "e" and x < Land.SIZE - 1.0):
			continue
		var leg: Dictionary = legs[key]
		var vert := int(leg["axis"]) == 1
		var r := _leg_at(leg, z if vert else x)
		if r.is_empty():
			continue
		var dd := absf((x if vert else z) - float(r[0])) / sqrt(1.0 + float(r[3]) * float(r[3]))
		if dd < bd and dd < 170.0:
			bd = dd
			var s: float = r[2]
			best = [dd, far_width(float(r[1]), s), far_level(s), s]
	return best


## Высота земли за краем карты с долиной реки: русло, пологие берега, а низкие места у реки подняты над водой
static func far_carve(y: float, x: float, z: float) -> float:
	var pr := _far_probe(x, z)
	if pr.is_empty():
		return y
	var d: float = pr[0]
	var wv: float = pr[1]
	var lv: float = pr[2]
	var slope := lerpf(SLOPE, 0.26, smoothstep(0.0, 200.0, float(pr[3])))
	var v: float
	if d < wv:
		var t := d / wv
		v = lv - FAR_BED + (FAR_BED - 0.18) * t * t
	else:
		var e := d - wv
		if e < SHORE:
			v = lv + 0.08 + e / SHORE * 0.17
		else:
			v = lv + 0.25 + (e - SHORE) * slope
	var base_y := lerpf(y, maxf(y, lv + 0.3), 1.0 - smoothstep(wv + 20.0, wv + 90.0, d))
	return smin(base_y, v, 1.5)


## Расстояние от края воды реки за краем карты (отрицательное — в воде); INF — реки рядом нет (деревья там не растут)
static func far_bank_dist(x: float, z: float) -> float:
	var pr := _far_probe(x, z)
	if pr.is_empty():
		return INF
	return float(pr[0]) - float(pr[1])


## Вода реки за краем карты: полосы по уровню (ширина — полуширина воды + 0,45 м под берег)
static func far_ribbon_mesh() -> ArrayMesh:
	var v := PackedVector3Array()
	var nr := PackedVector3Array()
	var ix := PackedInt32Array()
	if _far_id != 0:
		var legs: Dictionary = plan(_far_id)["legs"]
		for key: String in legs:
			var leg: Dictionary = legs[key]
			var vert := int(leg["axis"]) == 1
			var A: PackedFloat32Array = leg["a"]
			var B: PackedFloat32Array = leg["b"]
			var W: PackedFloat32Array = leg["w"]
			var S: PackedFloat32Array = leg["s"]
			var base := v.size()
			var cnt := 0
			var prev_a := -INF
			for i in A.size():
				if i != 0 and i != A.size() - 1 and A[i] - prev_a < 5.0:
					continue
				prev_a = A[i]
				var i2 := mini(i + 1, A.size() - 1)
				var i1 := maxi(i - 1, 0)
				var da := A[i2] - A[i1]
				var db := B[i2] - B[i1]
				var tan := (Vector2(db, da) if vert else Vector2(da, db)).normalized()      # направление в плане (x, z)
				var nor := Vector2(-tan.y, tan.x)
				var c := Vector2(B[i], A[i]) if vert else Vector2(A[i], B[i])
				var ww := far_width(W[i], S[i]) + 0.45
				var y := far_level(S[i])
				v.append(Vector3(c.x - nor.x * ww, y, c.y - nor.y * ww))
				v.append(Vector3(c.x + nor.x * ww, y, c.y + nor.y * ww))
				nr.append(Vector3.UP)
				nr.append(Vector3.UP)
				cnt += 1
			for q in range(0, cnt - 1):
				var a0 := base + q * 2
				ix.append_array([a0, a0 + 1, a0 + 3, a0, a0 + 3, a0 + 2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nr
	arr[Mesh.ARRAY_INDEX] = ix
	var m := ArrayMesh.new()
	if not v.is_empty():
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Где за краем карты нужны частые линии сетки пейзажа (шаг 2 м) — вдоль реки: [[от, до]] по x и по z
static func far_fine() -> Dictionary:
	var out := {"x": [], "z": []}
	if _far_id == 0:
		return out
	var legs: Dictionary = plan(_far_id)["legs"]
	for key: String in legs:
		var leg: Dictionary = legs[key]
		var B: PackedFloat32Array = leg["b"]
		var lo := INF
		var hi := -INF
		for b in B:
			lo = minf(lo, b)
			hi = maxf(hi, b)
		var pad := 44.0
		(out["x"] if int(leg["axis"]) == 1 else out["z"]).append([floorf((lo - pad) / 2.0) * 2.0, ceilf((hi + pad) / 2.0) * 2.0])
	return out


## Точки вдоль ручья для жизни у воды (камыши, камни, кувшинки): [{p, w, t (доля пути), side}]
static func samples(id: int, step := 1.5) -> Array:
	var p := plan(id)
	var pts: PackedVector2Array = p["pts"]
	var wid: PackedFloat32Array = p["w"]
	var shr: PackedFloat32Array = p["sh"]
	var out := []
	var acc := 0.0
	var next := 0.0
	var total: float = p["len"]
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var l := a.distance_to(b)
		while next <= acc + l:
			var t := (next - acc) / maxf(l, 1e-4)
			var dir := (b - a).normalized()
			var q := a.lerp(b, t)
			# за краем карты (у реки) жизни у воды не заводим; у реки — и там, где её закрывает озеро
			if q.x > 1.0 and q.y > 1.0 and q.x < Land.SIZE - 1.0 and q.y < Land.SIZE - 1.0:
				var pl: Vector3 = p["pool"]
				if not (pl.z > 0.0 and bool(p["river"]) and q.distance_to(Vector2(pl.x, pl.y)) < pl.z * 0.95):
					out.append({"p": q, "w": lerpf(wid[i - 1], wid[i], t), "t": next / maxf(total, 1e-4), "dir": dir, "sh": lerpf(shr[i - 1], shr[i], t)})
			next += step
		acc += l
	return out
