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
]
const BED := 0.45          # глубина посередине ручья (под уровнем воды)
const SHORE := 0.7         # полоса мокрого песка у воды, м
const SLOPE := 0.42        # крутизна берега: метров вверх на метр в сторону
const REACH := 12.0        # дальше от середины земля не трогается
const MARGIN := 3.0        # запас вокруг ложбины: там тоже не должно быть построек и дорог игрока
const SOFT := 0.3          # мягкость перехода ложбины в луг (smooth-min)

static var _plans := {}


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
		var steps := maxi(2, int(p1.distance_to(p2)))
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
	var acc := 0.0
	var w0 := float(d["w"])
	for i in raw.size():
		if i > 0:
			acc += raw[i].distance_to(raw[i - 1])
		var tan := (raw[mini(i + 1, raw.size() - 1)] - raw[maxi(i - 1, 0)]).normalized()
		var nor := Vector2(-tan.y, tan.x)
		var fade := smoothstep(0.0, 10.0, acc) * smoothstep(0.0, 6.0, total - acc)
		pts.append(raw[i] + nor * fn.get_noise_1d(acc) * 3.2 * fade)
		var w := w0 * (0.78 + 0.44 * (fn.get_noise_1d(acc * 1.9 + 71.0) * 0.5 + 0.5))
		w *= lerpf(0.5, 1.0, smoothstep(0.0, 12.0, acc))            # у родника — тоньше
		w *= 1.0 + 0.5 * smoothstep(total - 10.0, total, acc)          # к устью — шире
		wid.append(w)
	var p := {"id": id, "pts": pts, "w": wid, "len": total, "pool": d.get("pool", Vector3.ZERO)}
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
	_plans[id] = p
	return p


## Профиль ложбины: высота на расстоянии d от середины ручья полушириной w (bed — глубина посередине)
static func profile(d: float, w: float, bed := BED) -> float:
	if d < w:
		var t := d / w
		return Land.WATER_Y - bed + (bed - 0.18) * t * t
	var e := d - w
	if e < SHORE:
		return Land.WATER_Y + 0.08 + e / SHORE * 0.17
	return Land.WATER_Y + 0.25 + (e - SHORE) * SLOPE


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
	var pts: PackedVector2Array = p["pts"]
	var wid: PackedFloat32Array = p["w"]
	var R := REACH + MARGIN + 1.5
	var i := 0
	while i < pts.size() - 1:
		var j := mini(i + 2, pts.size() - 1)
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
		i = j
	var pl: Vector3 = p["pool"]
	var pd := PackedFloat32Array()
	if pl.z > 0.0:
		pd.resize(W * H)
		for y in H:
			for x in W:
				pd[y * W + x] = (lo + Vector2(x, y)).distance_to(Vector2(pl.x, pl.y))
	var fd := {"W": W, "H": H, "d": dist, "w": wd, "pd": pd}
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
	var out := {}
	var road := []
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
			var tmin := profile(maxf(minf(minf(dist[n], dist[n + 1]), minf(dist[n + W], dist[n + W + 1])) - 0.1, 0.0), wmax)
			if pmin < INF:
				tmin = minf(tmin, profile(maxf(pmin - 0.1, 0.0), pl.z, 0.85))
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
						t = profile(dd, _bilerp(fd, "w", lo, q))
					if not pdist.is_empty():
						var dp := _bilerp(fd, "pd", lo, q)
						if dp < pl.z + R:
							t = minf(t, profile(dp, pl.z, 0.85))
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
						continue
					out[k] = y1
	var res := {"cells": out, "road": road, "band": band}
	_cells[id] = res
	return res


## Можно ли проложить ручей в этом городе: все клетки ложбины и запаса — без построек, без дорог игрока,
## без правок земли (как на исходной карте), не под арками акведука
static func safe(land: Land, id: int, cs := {}) -> bool:
	if cs.is_empty():
		cs = cells(land, id)
	for k: int in cs["cells"]:
		if land.occ[k] != 0 or land.kind[k] != land.base_kind[k] or land.h[k] != land.base_h[k] or land.deco[k] != 0:
			return false
		if land.under.has(k):
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
			land.base_h[k] = y
			if mine:
				land.h[k] = y
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
			land.bridges.append(_bridge(land, id, rd))
	land.gen += 1


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


## Какие ручьи проложить в этом городе: из сохранения — ровно те (saved != null), иначе — все, что свободны
static func choose(land: Land, saved) -> Array:
	if saved is Array:
		var out := []
		for v in saved:
			out.append(int(v))
		return out
	var out2 := []
	for id: int in ids():
		if safe(land, id):
			out2.append(id)
	return out2


## Точки вдоль ручья для жизни у воды (камыши, камни, кувшинки): [{p, w, t (доля пути), side}]
static func samples(id: int, step := 1.5) -> Array:
	var p := plan(id)
	var pts: PackedVector2Array = p["pts"]
	var wid: PackedFloat32Array = p["w"]
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
			out.append({"p": a.lerp(b, t), "w": lerpf(wid[i - 1], wid[i], t), "t": next / maxf(total, 1e-4), "dir": dir})
			next += step
		acc += l
	return out
