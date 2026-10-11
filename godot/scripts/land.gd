class_name Land
extends RefCounted
## Земля игры: карта 384×384 м из клеток по 25 см с уступами по 12,5 см (как в Town to City).
## Середина 256×256 м — своя земля с начала: мягкие холмы, луга, леса пятнами, пруды; на севере —
## небольшой холм с тоннелем, оттуда выезжают повозки, рядом почтовая станция. Вокруг — кольцо дорогих
## участков по 64 м, а дальше до горизонта — просто пейзаж. Каждая клетка помнит, какая постройка на ней
## стоит (occ): постройки занимают землю своей настоящей формой, а не прямоугольником.
## Высоты хранятся «как есть», а читаются ступеньками по 12,5 см (hq).

const CELL := 0.25
const SIZE := 384.0
const N := 1536
const STEP := 0.125
const BASE_Y := 2.0
const WATER_Y := 1.0
const SEA_Y := WATER_Y
const EDGE_Y := 4.5                 # высота на краю карты — там начинается пейзаж до горизонта
const CH := 64                      # клеток в куске сетки (16 м)
const CHN := N / CH
const PLOT := 64.0                  # участок земли
const PLOTS := 6
const TUNNEL := Vector2(192.0, 86.0)     # портал тоннеля в холме (смотрит на юг)
const GATE := TUNNEL
const HILL := Vector2(192.0, 72.0)
const CENTER := Vector2(185.0, 99.0)     # почтовая станция
const START := Vector2(192.0, 150.0)     # середина своей земли
const PONDS := [[Vector3(215.0, 150.0, 7.5)], [Vector3(130.0, 182.0, 13.0)], [Vector3(260.0, 214.0, 11.0)],
	[Vector3(176.0, 262.0, 17.0)], [Vector3(102.0, 124.0, 9.0)], [Vector3(338.0, 300.0, 22.0)], [Vector3(40.0, 250.0, 16.0)]]
const SM := 2                       # маска покрытий — по 2×2 клетки

enum Kind { GRASS, DIRT, ROCK, SAND, ROAD, PLAZA, YARD, FIELD }

var h := PackedFloat32Array()        # высоты (без ступенек)
var kind := PackedByteArray()
var tint := PackedByteArray()        # 0…255 — оттенок травы пятнами
var occ := PackedInt32Array()        # id постройки на клетке (0 — свободно)
var base_h := PackedFloat32Array()   # исходная карта — для сохранения только изменений
var base_kind := PackedByteArray()
var owned := {}                      # Vector2i участка → true
var dirty := {}                      # Vector2i куска → true (перестроить сетку)
var road_chunks := {}                # куски, где есть дороги (для маски покрытий и сетки ходьбы)

var n1 := FastNoiseLite.new()
var n2 := FastNoiseLite.new()
var n3 := FastNoiseLite.new()


func _init() -> void:
	n1.seed = 11
	n1.frequency = 0.011
	n1.fractal_octaves = 4
	n2.seed = 23
	n2.frequency = 0.06
	n3.seed = 37
	n3.frequency = 0.02
	generate()


func idx(i: int, j: int) -> int:
	return j * N + i


func inside(i: int, j: int) -> bool:
	return i >= 0 and j >= 0 and i < N and j < N


func cell(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x / CELL), 0, N - 1), clampi(int(p.y / CELL), 0, N - 1))


func cell_center(i: int, j: int) -> Vector2:
	return Vector2((i + 0.5) * CELL, (j + 0.5) * CELL)


## Высота клетки ступеньками по 12,5 см
func hq(k: int) -> float:
	return roundf(h[k] / STEP) * STEP


func height_at(x: float, z: float) -> float:
	var c := cell(Vector2(x, z))
	return hq(idx(c.x, c.y))


func kind_at(x: float, z: float) -> int:
	var c := cell(Vector2(x, z))
	return kind[idx(c.x, c.y)]


func occ_at(p: Vector2) -> int:
	var c := cell(p)
	return occ[idx(c.x, c.y)]


func plot_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x / PLOT), 0, PLOTS - 1), clampi(int(p.y / PLOT), 0, PLOTS - 1))


func is_owned(p: Vector2) -> bool:
	return owned.has(plot_of(p))


func is_water(p: Vector2) -> bool:
	return height_at(p.x, p.y) < WATER_Y + 0.05


## Крутой обрыв (скала) — перепад к соседу от 50 см
func is_rock(k: int) -> bool:
	var i := k % N
	var j := k / N
	var y := hq(k)
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if inside(i + d.x, j + d.y) and absf(y - hq(idx(i + d.x, j + d.y))) >= 0.5:
			return true
	return false


static func walk_kind(kd: int) -> bool:
	return kd == Kind.ROAD or kd == Kind.PLAZA or kd == Kind.DIRT


## Дорога (мостовая, площадь, тропа) без построек
func is_road(p: Vector2) -> bool:
	var c := cell(p)
	var k := idx(c.x, c.y)
	return walk_kind(kind[k]) and occ[k] == 0


# ---------- рельеф ----------

func raw_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	# мягкие холмы: на своей земле у станции почти ровно, дальше — выше; за кольцом участков — снова к краю
	var ds := maxf(absf(x - START.x) - 40.0, absf(z - START.y) - 40.0)
	var amp := lerpf(0.3, 2.4, smoothstep(0.0, 70.0, ds))
	var y := BASE_Y + 0.4 + n1.get_noise_2d(x, z) * amp + n3.get_noise_2d(x, z) * amp * 0.25
	y += smoothstep(80.0, 150.0, ds) * (2.0 + n3.get_noise_2d(x * 0.5, z * 0.5) * 3.0)
	# дорога от портала на юг и площадь у станции — ровно (сам холм с тоннелем строится по клеткам в generate)
	var dx := absf(x - TUNNEL.x)
	if z > TUNNEL.y:
		var corridor := (1.0 - smoothstep(4.0, 8.0, dx)) * (1.0 - smoothstep(130.0, 140.0, z))
		y = lerpf(y, BASE_Y + 0.4, corridor)
	y = lerpf(y, BASE_Y + 0.4, 1.0 - smoothstep(10.0, 18.0, p.distance_to(CENTER + Vector2(3, 0))))
	# пруды
	for pd in PONDS:
		var c: Vector3 = pd[0]
		var r := c.z * (1.0 + n2.get_noise_2d(x * 0.8, z * 0.8) * 0.18)
		var d := p.distance_to(Vector2(c.x, c.y))
		if d < r + 3.0:
			y = lerpf(y, WATER_Y - 0.9, 1.0 - smoothstep(r * 0.55, r, d))
			y = lerpf(y, maxf(minf(y, WATER_Y + 0.35), WATER_Y + 0.15), (1.0 - smoothstep(r, r + 2.5, d)) * smoothstep(r * 0.55, r, d))
	# край карты — к общей высоте, дальше пейзаж до горизонта
	var edge := minf(minf(x, SIZE - x), minf(z, SIZE - z))
	y = lerpf(y, EDGE_Y, 1.0 - smoothstep(0.0, 22.0, edge))
	return y


func generate() -> void:
	# высоты — по сетке 1 м, потом растягиваем на клетки 25 см (быстро, средствами движка)
	var M := int(SIZE) + 1
	var coarse := PackedFloat32Array()
	coarse.resize(M * M)
	for j in M:
		for i in M:
			coarse[j * M + i] = raw_height(float(i), float(j))
	var img := Image.create_from_data(M, M, false, Image.FORMAT_RF, coarse.to_byte_array())
	img.resize(N, N, Image.INTERPOLATE_BILINEAR)
	h = img.get_data().to_float32_array()
	_hill()
	kind.resize(N * N)
	kind.fill(Kind.GRASS)
	occ.resize(N * N)
	occ.fill(0)
	var tn := FastNoiseLite.new()
	tn.seed = 5
	tn.frequency = 0.035
	tn.fractal_octaves = 3
	tint = tn.get_image(N, N, false, false, true).get_data()
	# дорога из тоннеля мимо станции и площадь перед станцией
	paint_line(TUNNEL + Vector2(0, 0.6), Vector2(192.0, 128.0), 1.7, Kind.ROAD, true)
	for z in range(92, 106):
		paint_line(Vector2(187.5, z + 0.5), Vector2(190.0, z + 0.5), 0.6, Kind.PLAZA, true)
	# своя земля с начала: середина 4×4 участка (256×256 м)
	for dj in range(1, 5):
		for di in range(1, 5):
			owned[Vector2i(di, dj)] = true
	base_h = h.duplicate()
	base_kind = kind.duplicate()
	dirty.clear()
	touched.clear()


const HILL_R := 26.0
const HILL_H := 8.0
const CLIFF_H := 7.5                 # высота отвесной стены с порталом над дорогой
const CLIFF_W := 12.0                # полуширина стены


## Холм с тоннелем: пологий купол, спереди — отвесная каменная стена, в ней портал
func _hill() -> void:
	var i0 := int((HILL.x - HILL_R - 4.0) / CELL)
	var i1 := int((HILL.x + HILL_R + 4.0) / CELL)
	var j0 := int((HILL.y - HILL_R - 4.0) / CELL)
	var j1 := int((TUNNEL.y + 2.0) / CELL)
	var base := BASE_Y + 0.4
	for j in range(maxi(0, j0), mini(N, j1)):
		for i in range(maxi(0, i0), mini(N, i1)):
			var q := cell_center(i, j)
			var k := idx(i, j)
			var d := q.distance_to(HILL) / HILL_R
			var dome := 0.0
			if d < 1.0:
				var t := 1.0 - d
				dome = HILL_H * t * t * (3.0 - 2.0 * t) + n2.get_noise_2d(q.x * 0.6, q.y * 0.6) * 0.5 * t
			var dx := absf(q.x - TUNNEL.x)
			# линия стены слегка выгнута назад к краям
			var face_z := TUNNEL.y - 0.3 - dx * dx * 0.012
			if dx < CLIFF_W and q.y > face_z:
				h[k] = base                      # перед стеной — ровная площадка у портала
				continue
			if dx < 1.5 and q.y > face_z - 1.5:
				h[k] = base                      # ниша под каменный портал
				continue
			if dx < CLIFF_W and q.y <= face_z:
				var wall := base + CLIFF_H * (1.0 - smoothstep(CLIFF_W - 4.0, CLIFF_W, dx))
				h[k] = maxf(maxf(h[k], base + dome), wall + (dome * 0.25))
			else:
				h[k] = maxf(h[k], base + dome)


func _mark(i: int, j: int) -> void:
	dirty[Vector2i(clampi(i / CH, 0, CHN - 1), clampi(j / CH, 0, CHN - 1))] = true
	touched[Vector2i(clampi(i / CH, 0, CHN - 1), clampi(j / CH, 0, CHN - 1))] = true
	# стенки уступов на краю куска рисует соседний кусок
	if i % CH == 0 and i > 0:
		dirty[Vector2i((i - 1) / CH, clampi(j / CH, 0, CHN - 1))] = true
	if j % CH == 0 and j > 0:
		dirty[Vector2i(clampi(i / CH, 0, CHN - 1), (j - 1) / CH)] = true
	if i % CH == CH - 1 and i < N - 1:
		dirty[Vector2i((i + 1) / CH, clampi(j / CH, 0, CHN - 1))] = true
	if j % CH == CH - 1 and j < N - 1:
		dirty[Vector2i(clampi(i / CH, 0, CHN - 1), (j + 1) / CH)] = true


# ---------- кисть дорог ----------

## Покрасить клетки в круге (square — квадрат) радиуса r. over — рисовать поверх других дорог.
func paint_circle(p: Vector2, r: float, kd: int, flat := false, only_owned := true, square := false, over := true) -> Array:
	var out := []
	var c := cell(p)
	var rc := int(ceil(r / CELL))
	var y0 := height_at(p.x, p.y)
	for j in range(c.y - rc, c.y + rc + 1):
		for i in range(c.x - rc, c.x + rc + 1):
			if not inside(i, j):
				continue
			var q := cell_center(i, j)
			if square:
				if absf(q.x - p.x) > r or absf(q.y - p.y) > r:
					continue
			elif q.distance_to(p) > r:
				continue
			if only_owned and not is_owned(q):
				continue
			var k := idx(i, j)
			var kk := kind[k]
			var y := hq(k)
			if y < WATER_Y + 0.05 or occ[k] != 0:
				continue
			if kd == Kind.GRASS and not walk_kind(kk):
				continue
			if kd != Kind.GRASS and walk_kind(kk) and kk != kd and not over:
				continue
			if kd != Kind.GRASS and kk == kd and (not flat or absf(y - y0) < 0.01):
				continue
			if flat and absf(y - y0) > 1.2:
				continue                         # обрыв кисть не срезает
			out.append([Vector2i(i, j), kk, h[k]])
			kind[k] = kd
			if flat and walk_kind(kd):
				# дорога ложится по земле: только сглаживаем мелкие ступеньки вдоль неё, не поднимая над травой
				h[k] = _smooth_at(i, j, 3)
			_mark(i, j)
			if walk_kind(kd):
				road_chunks[Vector2i(i / CH, j / CH)] = true
	return out


## Средняя высота вокруг клетки (радиус rc клеток) — для мягкой дороги по склону
func _smooth_at(i: int, j: int, rc: int) -> float:
	var sum := 0.0
	var n := 0
	var y0 := h[idx(i, j)]
	for dj in range(-rc, rc + 1):
		for di in range(-rc, rc + 1):
			if inside(i + di, j + dj):
				var y := h[idx(i + di, j + dj)]
				if y >= WATER_Y + 0.05 and absf(y - y0) < 0.5:   # обрывы и стены в среднее не берём
					sum += y
					n += 1
	return sum / n if n > 0 else h[idx(i, j)]


func paint_line(a: Vector2, b: Vector2, r: float, kd: int, flat := false) -> Array:
	var out := []
	var n := int(a.distance_to(b) / (CELL * 2.0)) + 1
	for s in n + 1:
		out.append_array(paint_circle(a.lerp(b, float(s) / n), r, kd, flat, false))
	return out


func undo(changes: Array) -> void:
	for ch in changes:
		var c: Vector2i = ch[0]
		var k := idx(c.x, c.y)
		kind[k] = ch[1]
		h[k] = ch[2]
		_mark(c.x, c.y)
		if walk_kind(ch[1]):
			road_chunks[Vector2i(c.x / CH, c.y / CH)] = true


# ---------- постройки на земле ----------

## Клетки следа постройки: rects — прямоугольники в осях постройки, pos/yaw — где стоит
func footprint_cells(rects: Array, pos: Vector2, yaw: float, pad := 0.0) -> PackedInt32Array:
	var out := PackedInt32Array()
	var ax := Vector2(cos(yaw), -sin(yaw))
	var fw := Vector2(sin(yaw), cos(yaw))
	var seen := {}
	for r: Rect2 in rects:
		var rr := r.grow(pad)
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for cnr: Vector2 in [rr.position, rr.position + Vector2(rr.size.x, 0), rr.position + Vector2(0, rr.size.y), rr.end]:
			var w := pos + ax * cnr.x + fw * cnr.y
			lo = lo.min(w)
			hi = hi.max(w)
		var c0 := cell(lo)
		var c1 := cell(hi)
		for j in range(c0.y, c1.y + 1):
			for i in range(c0.x, c1.x + 1):
				var q := cell_center(i, j) - pos
				var lx := q.dot(ax)
				var lz := q.dot(fw)
				if lx >= rr.position.x and lx <= rr.end.x and lz >= rr.position.y and lz <= rr.end.y:
					var k := idx(i, j)
					if not seen.has(k):
						seen[k] = true
						out.append(k)
	return out


func set_occ(cells: PackedInt32Array, id: int) -> void:
	for k in cells:
		occ[k] = id


## Выровнять клетки под постройкой на высоту y (вокруг остаются уступы — как подпорные стенки)
func flatten_cells(cells: PackedInt32Array, y: float, kd := -1) -> void:
	for k in cells:
		if hq(k) != y or (kd >= 0 and kind[k] != kd):
			h[k] = y
			if kd >= 0:
				kind[k] = kd
			_mark(k % N, k / N)


## Земля вокруг постройки плавно подходит к её полу — без ям и ступенек (rc клеток вокруг)
func blend_ring(cells: PackedInt32Array, y: float, rc := 7) -> void:
	var dist := {}
	var front: Array[int] = []
	for k in cells:
		dist[k] = 0
		front.append(k)
	for step in range(1, rc + 1):
		var nxt: Array[int] = []
		for k in front:
			var i := k % N
			var j := k / N
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not inside(i + d.x, j + d.y):
					continue
				var k2 := idx(i + d.x, j + d.y)
				if dist.has(k2):
					continue
				dist[k2] = step
				nxt.append(k2)
		front = nxt
	for k in dist:
		var st: int = dist[k]
		if st == 0 or occ[k] != 0 or walk_kind(kind[k]) or h[k] < WATER_Y + 0.2:
			continue
		var t := 1.0 - float(st) / float(rc + 1)
		t = t * t * (3.0 - 2.0 * t)
		var ny := lerpf(h[k], y, t)
		if absf(ny - h[k]) > 0.01:
			h[k] = ny
			_mark(k % N, k / N)


# ---------- маска покрытий для шейдера (плавные края дорог) ----------

func make_surface() -> Image:
	var img := Image.create(N / SM, N / SM, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 1))
	for ch in road_chunks:
		update_surface(img, ch)
	return img


func update_surface(img: Image, ch: Vector2i) -> void:
	if img.has_mipmaps():
		img.clear_mipmaps()
	var s := CH / SM
	for j in range(ch.y * s, ch.y * s + s):
		for i in range(ch.x * s, ch.x * s + s):
			var r := 0.0
			var g := 0.0
			var b := 0.0
			for dj in SM:
				for di in SM:
					var kd := kind[idx(i * SM + di, j * SM + dj)]
					if kd == Kind.ROAD:
						r += 0.25
					elif kd == Kind.PLAZA:
						g += 0.25
					elif kd == Kind.DIRT:
						b += 0.25
			img.set_pixel(i, j, Color(r, g, b, 1.0))


# ---------- цвета и сетка ----------

const C_GRASS := [Color("587f2a"), Color("678d2f"), Color("789a36"), Color("8fa842")]
const C_DIRT := Color("c6a878")
const C_ROCK := Color("d9c7ad")
const C_SAND := Color("e2cf9c")
const C_SAND_WET := Color("bfae84")
const C_YARD := Color("b8a07a")
const C_PAVE := Color("b9a98e")
const C_FIELD := Color("9a7a4e")
const LOCK := Color("c4bb98")


## Что рисовать на клетке: дороги и дворы — как есть; трава у воды — песок, на обрыве — скала
func show_kind(k: int, y: float) -> int:
	var kd := kind[k]
	if kd != Kind.GRASS:
		return kd
	if y < WATER_Y + 0.3:
		return Kind.SAND
	return kd


func top_color(kd: int, k: int, y: float) -> Color:
	match kd:
		Kind.ROCK: return C_ROCK
		Kind.SAND: return C_SAND_WET if y < WATER_Y + 0.12 else C_SAND
		Kind.YARD: return C_YARD
		Kind.FIELD: return C_FIELD
	return C_GRASS[tint[k] >> 6]


## Сетка куска (ci, cj): верх — полосами из одинаковых клеток (меньше треугольников), стенки — к нижним соседям
func chunk_mesh(ci: int, cj: int) -> ArrayMesh:
	var v := PackedVector3Array()
	var nr := PackedVector3Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()
	var ix := PackedInt32Array()
	var i0 := ci * CH
	var j0 := cj * CH
	var plot_cells := int(PLOT / CELL)
	# высоты куска с рамкой в одну клетку — читаем один раз
	var W := CH + 2
	var hy := PackedFloat32Array()
	hy.resize(W * W)
	for j in W:
		for i in W:
			var gi := clampi(i0 + i - 1, 0, N - 1)
			var gj := clampi(j0 + j - 1, 0, N - 1)
			var yy := hq(idx(gi, gj))
			if i0 + i - 1 < 0 or j0 + j - 1 < 0 or i0 + i - 1 >= N or j0 + j - 1 >= N:
				yy = WATER_Y - 3.0
			hy[j * W + i] = yy
	var quad := func(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, n: Vector3, c: Color, kd: int, top: float) -> void:
		var base := v.size()
		v.append_array([a, b, cc, d])
		nr.append_array([n, n, n, n])
		var lc := c.srgb_to_linear()
		col.append_array([lc, lc, lc, lc])
		var u := Vector2(kd, top)
		uv.append_array([u, u, u, u])
		ix.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
	for j in range(j0, j0 + CH):
		var i := i0
		var lj := j - j0 + 1
		while i < i0 + CH:
			var k := idx(i, j)
			var y := hy[lj * W + (i - i0 + 1)]
			var kd := show_kind(k, y)
			var tc := tint[k] >> 6
			var own := is_owned(cell_center(i, j))
			var e := i + 1
			while e < i0 + CH:
				var k2 := idx(e, j)
				var y2 := hy[lj * W + (e - i0 + 1)]
				if y2 != y or show_kind(k2, y2) != kd or (tint[k2] >> 6) != tc:
					break
				if e % plot_cells == 0:
					break                       # граница участка — не сливаем (разный цвет своей и чужой земли)
				e += 1
			var c := top_color(kd, k, y)
			if not own:
				c = c.lerp(LOCK, 0.18)
			var x0 := i * CELL
			var x1 := e * CELL
			var z0 := j * CELL
			var z1 := z0 + CELL
			quad.call(Vector3(x0, y, z0), Vector3(x0, y, z1), Vector3(x1, y, z1), Vector3(x1, y, z0), Vector3.UP, c, kd, y)
			i = e
	# стенки уступов
	for j in range(j0, j0 + CH):
		var lj := j - j0 + 1
		for i in range(i0, i0 + CH):
			var li := i - i0 + 1
			var y := hy[lj * W + li]
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var yn := hy[(lj + d.y) * W + li + d.x]
				if yn >= y:
					continue
				var x0 := i * CELL
				var z0 := j * CELL
				var x1 := x0 + CELL
				var z1 := z0 + CELL
				var a: Vector3
				var b: Vector3
				if d.x == 1:
					a = Vector3(x1, 0, z1); b = Vector3(x1, 0, z0)
				elif d.x == -1:
					a = Vector3(x0, 0, z0); b = Vector3(x0, 0, z1)
				elif d.y == 1:
					a = Vector3(x0, 0, z1); b = Vector3(x1, 0, z1)
				else:
					a = Vector3(x1, 0, z0); b = Vector3(x0, 0, z0)
				var k := idx(i, j)
				var rocky := y - yn >= 0.45
				var skd := show_kind(k, y)
				var paved := skd == Kind.ROAD or skd == Kind.PLAZA
				var c := C_ROCK if rocky else (C_PAVE if paved else top_color(skd, k, y))
				quad.call(Vector3(b.x, yn, b.z), Vector3(b.x, y, b.z), Vector3(a.x, y, a.z), Vector3(a.x, yn, a.z), Vector3(d.x, 0, d.y), c, Kind.ROCK if rocky else (Kind.ROAD if paved else Kind.DIRT), y)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nr
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = ix
	var m := ArrayMesh.new()
	if not v.is_empty():
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


# ---------- сохранение ----------

func save_changes() -> Dictionary:
	# сохраняем только клетки, отличающиеся от исходной карты
	var cells := PackedInt32Array()
	var kinds := PackedByteArray()
	var hs := PackedFloat32Array()
	for ch in _changed_chunks():
		for j in range(ch.y * CH, ch.y * CH + CH):
			for i in range(ch.x * CH, ch.x * CH + CH):
				var k := idx(i, j)
				if kind[k] != base_kind[k] or h[k] != base_h[k]:
					cells.append(k)
					kinds.append(kind[k])
					hs.append(h[k])
	var plots := []
	for p in owned:
		plots.append([p.x, p.y])
	return {"cells": Marshalls.raw_to_base64(cells.to_byte_array()), "kinds": Marshalls.raw_to_base64(kinds),
		"hs": Marshalls.raw_to_base64(hs.to_byte_array()), "plots": plots}


var touched := {}                    # куски, где игрок что-то менял


func _changed_chunks() -> Array:
	return touched.keys()


func load_changes(d: Dictionary) -> void:
	var cells := Marshalls.base64_to_raw(d.get("cells", "")).to_int32_array()
	var kinds := Marshalls.base64_to_raw(d.get("kinds", ""))
	var hs := Marshalls.base64_to_raw(d.get("hs", "")).to_float32_array()
	for n in cells.size():
		var k := cells[n]
		kind[k] = kinds[n]
		h[k] = hs[n]
		var ch := Vector2i((k % N) / CH, (k / N) / CH)
		touched[ch] = true
		if walk_kind(kinds[n]):
			road_chunks[ch] = true
	owned.clear()
	for p in d.get("plots", []):
		owned[Vector2i(int(p[0]), int(p[1]))] = true
