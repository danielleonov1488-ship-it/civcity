class_name Kerb
extends RefCounted
## Каменный бордюр вокруг домуса и храма (у домов и лавок — глина, Land.wear): ряд тёсаных камней по контуру
## постройки в её же осях (повёрнут вместе с ней, без лесенки клеток), вдоль боков и задней стены; у фасада —
## нет (там ступени и улица). Камни — детали пула Parts («#kerb0…2», три оттенка травертина), все бордюры города
## рисуются тремя MultiMesh. Чертёж бордюра считается один раз на чертёж постройки.

const G := 0.25                      # шаг сетки контура, м (в осях постройки)
const W := 0.3                       # ширина камня
const TOP := 0.07                    # верх камня над полом постройки
const DEPTH := 0.4                   # низ уходит в землю (на склоне видна боковина, а не щель)
const COLS := ["ddd3bf", "d0c5ae", "c4b79e"]
const CLOSE := 3                     # щели уже 2·CLOSE клеток (калитка, проход в сад) — внутрь бордюр не заходит

static var _cache := {}              # id чертежа → чертёж бордюра (Bp)


## Чертёж бордюра для чертежа постройки (те же оси: начало — середина основания, фасад к +Z)
static func blueprint(bp: Bp) -> Bp:
	var key := bp.get_instance_id()
	if _cache.has(key):
		return _cache[key]
	var out := Bp.new(key)
	var rects: Array = []
	for r: Rect2 in bp.footprint(false):
		if r.size.x * r.size.y >= 0.08:          # мелочь у стен (горшки, столбики) контур не ломает
			rects.append(r)
	if rects.is_empty():
		_cache[key] = out
		return out
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for r: Rect2 in rects:
		lo = lo.min(r.position)
		hi = hi.max(r.end)
	var fz := hi.y                         # передняя кромка следа (фасад) — там камней нет
	lo -= Vector2(G, G) * (CLOSE + 2)
	hi += Vector2(G, G) * (CLOSE + 2)
	var nx := int(ceil((hi.x - lo.x) / G))
	var nz := int(ceil((hi.y - lo.y) / G))
	# сплошное: клетки, чья середина под прямоугольником следа (каждый прямоугольник — сразу своим диапазоном клеток)
	var solid := PackedByteArray()
	solid.resize(nx * nz)
	for r: Rect2 in rects:
		var rr := r.grow(0.02)
		var i0 := maxi(0, int(ceil((rr.position.x - lo.x) / G - 0.5)))
		var i1 := mini(nx - 1, int(floor((rr.end.x - lo.x) / G - 0.5)))
		var j0 := maxi(0, int(ceil((rr.position.y - lo.y) / G - 0.5)))
		var j1 := mini(nz - 1, int(floor((rr.end.y - lo.y) / G - 0.5)))
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				solid[j * nx + i] = 1
	# снаружи — то, куда можно дойти от края, не протискиваясь в щели уже ~1,5 м (калитка сада): заливка по
	# «раздутому» на CLOSE клеток следу, потом снаружи — всё в CLOSE клетках от залитого (кроме самого следа)
	var fat := _dilate(solid, nx, nz, CLOSE)
	var far := PackedByteArray()
	far.resize(nx * nz)
	var stack: Array[int] = []
	for i in nx:
		stack.append(i)
		stack.append((nz - 1) * nx + i)
	for j in nz:
		stack.append(j * nx)
		stack.append(j * nx + nx - 1)
	while not stack.is_empty():
		var k: int = stack.pop_back()
		if far[k] == 1 or fat[k] == 1:
			continue
		far[k] = 1
		var i := k % nx
		var j := k / nx
		if i > 0: stack.append(k - 1)
		if i < nx - 1: stack.append(k + 1)
		if j > 0: stack.append(k - nx)
		if j < nz - 1: stack.append(k + nx)
	var outside := _dilate(far, nx, nz, CLOSE)
	for k in nx * nz:
		if solid[k] == 1:
			outside[k] = 0
	var ring := PackedByteArray()          # клетки вокруг (8 соседей), снаружи
	ring.resize(nx * nz)
	for j in nz:
		for i in nx:
			var k := j * nx + i
			if outside[k] == 0:
				continue
			var near := false
			for dj in range(-1, 2):
				for di in range(-1, 2):
					var ii := i + di
					var jj := j + dj
					if ii >= 0 and jj >= 0 and ii < nx and jj < nz and outside[jj * nx + ii] == 0:
						near = true
			var cz := lo.y + (j + 0.5) * G
			if near and cz < fz - 0.05:
				ring[k] = 1
	# ряды по x (вместе с углами), потом оставшееся — столбцами по z; длинные ряды — камнями по 2–3 клетки
	var used := PackedByteArray()
	used.resize(nx * nz)
	var rng := RandomNumberGenerator.new()
	rng.seed = key
	for j in nz:
		var i := 0
		while i < nx:
			if ring[j * nx + i] == 1 and used[j * nx + i] == 0:
				var e := i
				while e + 1 < nx and ring[j * nx + e + 1] == 1:
					e += 1
				if e - i >= 2:
					for t in range(i, e + 1):
						used[j * nx + t] = 1
					_run(out, rng, lo + Vector2(i * G, j * G), Vector2(1, 0), e - i + 1)
				i = e + 1
			else:
				i += 1
	for i in nx:
		var j := 0
		while j < nz:
			if ring[j * nx + i] == 1 and used[j * nx + i] == 0:
				var e := j
				while e + 1 < nz and ring[(e + 1) * nx + i] == 1 and used[(e + 1) * nx + i] == 0:
					e += 1
				_run(out, rng, lo + Vector2(i * G, j * G), Vector2(0, 1), e - j + 1)
				j = e + 1
			else:
				j += 1
	_cache[key] = out
	return out


## Клетки в r шагах (квадратом) от отмеченных: сначала по рядам, потом по столбцам
static func _dilate(src: PackedByteArray, nx: int, nz: int, r: int) -> PackedByteArray:
	var tmp := PackedByteArray()
	tmp.resize(nx * nz)
	for j in nz:
		var row := j * nx
		var last := -1000
		for i in nx:
			if src[row + i] == 1:
				last = i
			if i - last <= r:
				tmp[row + i] = 1
		last = 1000000
		for i in range(nx - 1, -1, -1):
			if src[row + i] == 1:
				last = i
			if last - i <= r:
				tmp[row + i] = 1
	var out := PackedByteArray()
	out.resize(nx * nz)
	for i in nx:
		var last := -1000
		for j in nz:
			if tmp[j * nx + i] == 1:
				last = j
			if j - last <= r:
				out[j * nx + i] = 1
		last = 1000000
		for j in range(nz - 1, -1, -1):
			if tmp[j * nx + i] == 1:
				last = j
			if last - j <= r:
				out[j * nx + i] = 1
	return out


## Ряд из n клеток от угла a (угол клетки) вдоль d: камни по 2–3 клетки с узким швом
static func _run(out: Bp, rng: RandomNumberGenerator, a: Vector2, d: Vector2, n: int) -> void:
	var t := 0
	while t < n:
		var len := mini(n - t, 2 + rng.randi() % 2)
		if n - t - len == 1:
			len += 1                         # хвост в одну клетку — к этому камню
		var c := a + d * ((t + len * 0.5) * G) + Vector2(d.y, d.x) * (G * 0.5)
		var sx := len * G - 0.025 if d.x > 0.5 else W
		var sz := len * G - 0.025 if d.y > 0.5 else W
		var h := TOP + DEPTH + rng.randf_range(-0.015, 0.015)
		out.parts.append(["#kerb%d" % (rng.randi() % COLS.size()), Transform3D(Basis.from_scale(Vector3(sx, h, sz)), Vector3(c.x, TOP - h, c.y)), {}])
		t += len


## Камень: кубик 1×1×1 (низ на нуле) со скошенными верхними кромками, плоские грани, цвет — в вершинах
static func mesh(name: String) -> Mesh:
	var col := Color(COLS[clampi(int(name.substr(5)), 0, COLS.size() - 1)])
	var k := Kit.new()
	var b := 0.08                            # скос (доля размера)
	var y1 := 1.0
	var y0 := 1.0 - b
	var top := [Vector3(-0.5 + b, y1, -0.5 + b), Vector3(0.5 - b, y1, -0.5 + b), Vector3(0.5 - b, y1, 0.5 - b), Vector3(-0.5 + b, y1, 0.5 - b)]
	var mid := [Vector3(-0.5, y0, -0.5), Vector3(0.5, y0, -0.5), Vector3(0.5, y0, 0.5), Vector3(-0.5, y0, 0.5)]
	var bot := [Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(0.5, 0, 0.5), Vector3(-0.5, 0, 0.5)]
	var c := Vector3(0, 0.5, 0)
	k.quad_out(top[0], top[1], top[2], top[3], col.lightened(0.04), c)
	for s in 4:
		var s2 := (s + 1) % 4
		k.quad_out(top[s], top[s2], mid[s2], mid[s], col, c)
		k.quad_out(mid[s], mid[s2], bot[s2], bot[s], col.darkened(0.06), c)
	var am := k.mesh()
	am.surface_set_material(0, Kit.material(0.9))
	return am
