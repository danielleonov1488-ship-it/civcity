class_name Land
extends RefCounted
## Земля игры: карта 256×256 м из клеток по 25 см с уступами по 12,5 см (как в Town to City).
## Мягкие холмы и луга, пруды, на севере — гора с тоннелем: оттуда выезжают повозки с переселенцами,
## рядом почтовая станция — начало города. Земля поделена на участки 32×32 м: четыре свои с начала,
## остальные покупаются. Каждая клетка помнит, какая постройка на ней стоит (occ) — постройки занимают
## землю своей настоящей формой, а не прямоугольником.

const CELL := 0.25
const SIZE := 256.0
const N := 1024
const STEP := 0.125
const BASE_Y := 2.0
const WATER_Y := 1.0
const SEA_Y := WATER_Y
const CH := 64                     # клеток в куске сетки (16 м)
const CHN := N / CH
const PLOT := 32.0                 # участок земли
const PLOTS := 8
const TUNNEL := Vector2(128.0, 33.0)     # портал тоннеля в горе (смотрит на юг)
const GATE := TUNNEL
const CENTER := Vector2(121.5, 45.0)     # почтовая станция
const START := Vector2(128.0, 64.0)      # середина стартовых участков
const PONDS := [[Vector3(151.0, 84.0, 7.5)], [Vector3(66.0, 118.0, 13.0)], [Vector3(196.0, 150.0, 11.0)], [Vector3(112.0, 196.0, 17.0)], [Vector3(36.0, 60.0, 9.0)]]
const SM := 2                      # маска покрытий — по 2×2 клетки

enum Kind { GRASS, DIRT, ROCK, SAND, ROAD, PLAZA, YARD, FIELD }

var h := PackedFloat32Array()
var kind := PackedByteArray()
var tint := PackedByteArray()        # 0…3 — оттенок травы пятнами
var occ := PackedInt32Array()        # id постройки на клетке (0 — свободно)
var base_h := PackedFloat32Array()   # исходная карта — для сохранения только изменений
var base_kind := PackedByteArray()
var owned := {}                      # Vector2i участка → true
var dirty := {}                      # Vector2i куска → true (перестроить сетку)

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


func height_at(x: float, z: float) -> float:
	var c := cell(Vector2(x, z))
	return h[idx(c.x, c.y)]


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
	# мягкие холмы: на стартовых участках почти ровно, дальше — круче
	var ds := maxf(absf(x - START.x) - 34.0, absf(z - START.y) - 34.0)
	var amp := lerpf(0.32, 2.6, smoothstep(0.0, 46.0, ds))
	var y := BASE_Y + 0.4 + n1.get_noise_2d(x, z) * amp + n3.get_noise_2d(x, z) * amp * 0.25
	# гора на севере с тоннелем
	var dh := p.distance_to(Vector2(128.0, 2.0))
	y += (1.0 - smoothstep(12.0, 44.0, dh)) * (11.0 + n2.get_noise_2d(x * 0.5, z * 0.5) * 2.5)
	y += smoothstep(26.0, 2.0, z) * (5.0 + n1.get_noise_2d(x * 1.7, 3.0) * 3.0)
	# по краям карты — холмы, чтобы край не был виден обрывом
	var edge := minf(minf(x, SIZE - x), minf(z, SIZE - z))
	y += smoothstep(26.0, 0.0, edge) * (4.0 + n2.get_noise_2d(x * 0.3, z * 0.3) * 2.0)
	# выход из тоннеля: ровная дорога и обрыв горы за порталом
	var dx := absf(x - TUNNEL.x)
	if z > TUNNEL.y - 0.2 and z < 64.0:
		var corridor := 1.0 - smoothstep(4.0, 9.0, dx)
		y = lerpf(y, BASE_Y + 0.4, corridor * smoothstep(TUNNEL.y - 0.2, TUNNEL.y + 1.0, z))
	elif z <= TUNNEL.y - 0.2 and dx < 16.0:
		# склон горы над порталом: круто вверх, по бокам — плавнее
		var rise := (TUNNEL.y - z) * lerpf(1.6, 0.5, smoothstep(5.0, 16.0, dx))
		y = maxf(y, BASE_Y + lerpf(7.5, 2.0, smoothstep(6.0, 16.0, dx)) + rise)
	# станция и площадь перед ней — ровно
	var flat := 1.0 - smoothstep(9.0, 16.0, p.distance_to(Vector2(124.0, 46.0)))
	y = lerpf(y, BASE_Y + 0.4, flat)
	# пруды
	for pd in PONDS:
		var c: Vector3 = pd[0]
		var r := c.z * (1.0 + n2.get_noise_2d(x * 0.8, z * 0.8) * 0.18)
		var d := p.distance_to(Vector2(c.x, c.y))
		y = lerpf(y, WATER_Y - 0.9, 1.0 - smoothstep(r * 0.55, r, d))
		y = lerpf(y, maxf(minf(y, WATER_Y + 0.35), WATER_Y + 0.15), (1.0 - smoothstep(r, r + 2.5, d)) * smoothstep(r * 0.55, r, d))
	return y


func generate() -> void:
	h.resize(N * N)
	kind.resize(N * N)
	tint.resize(N * N)
	occ.resize(N * N)
	occ.fill(0)
	# высоты считаем по сетке 50 см и сглаживаем на клетки 25 см — так вчетверо быстрее
	var M2 := N / 2 + 1
	var coarse := PackedFloat32Array()
	coarse.resize(M2 * M2)
	for j in M2:
		for i in M2:
			coarse[j * M2 + i] = raw_height(i * 0.5, j * 0.5)
	for j in N:
		var fj := (j + 0.5) * 0.5
		var j0 := mini(int(fj), M2 - 2)
		var tj := fj - j0
		for i in N:
			var fi := (i + 0.5) * 0.5
			var i0 := mini(int(fi), M2 - 2)
			var ti := fi - i0
			var a := lerpf(coarse[j0 * M2 + i0], coarse[j0 * M2 + i0 + 1], ti)
			var b := lerpf(coarse[(j0 + 1) * M2 + i0], coarse[(j0 + 1) * M2 + i0 + 1], ti)
			var k := idx(i, j)
			h[k] = roundf(lerpf(a, b, tj) / STEP) * STEP
			var t := 0.5 + n2.get_noise_2d(i * 0.11, j * 0.11) * 1.1 + n1.get_noise_2d(i * 0.6, j * 0.6) * 0.35
			tint[k] = clampi(int(t * 4.0), 0, 3)
			kind[k] = Kind.GRASS
	for j in N:
		for i in N:
			var k := idx(i, j)
			var y := h[k]
			if y < WATER_Y + 0.3:
				kind[k] = Kind.SAND
				continue
			var drop := 0.0
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if inside(i + d.x, j + d.y):
					drop = maxf(drop, absf(y - h[idx(i + d.x, j + d.y)]))
			if drop >= 0.5:
				kind[k] = Kind.ROCK
	# дорога из тоннеля мимо станции и площадь перед станцией
	paint_line(TUNNEL + Vector2(0, 0.6), Vector2(128.0, 70.0), 1.7, Kind.ROAD, true)
	for z in range(40, 52):
		paint_line(Vector2(124.0, z + 0.5), Vector2(127.0, z + 0.5), 0.6, Kind.PLAZA, true)
	# свои участки с начала: 2×2 вокруг станции
	for dj in range(1, 3):
		for di in range(3, 5):
			owned[Vector2i(di, dj)] = true
	base_h = h.duplicate()
	base_kind = kind.duplicate()
	dirty.clear()


func _mark(i: int, j: int) -> void:
	dirty[Vector2i(clampi(i / CH, 0, CHN - 1), clampi(j / CH, 0, CHN - 1))] = true
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

## Покрасить клетки в круге (square = квадрат) радиуса r. over — рисовать поверх других дорог.
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
			if kk == Kind.ROCK or kk == Kind.SAND or h[k] < WATER_Y + 0.05 or occ[k] != 0:
				continue
			if kd == Kind.GRASS and not walk_kind(kk):
				continue
			if kd != Kind.GRASS and walk_kind(kk) and kk != kd and not over:
				continue
			if kd != Kind.GRASS and kk == kd and (not flat or absf(h[k] - y0) < 0.01):
				continue
			out.append([Vector2i(i, j), kk, h[k]])
			kind[k] = kd
			if flat and absf(h[k] - y0) <= 0.5:
				h[k] = y0
			_mark(i, j)
	return out


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
		if h[k] != y or (kd >= 0 and kind[k] != kd):
			h[k] = y
			if kd >= 0:
				kind[k] = kd
			_mark(k % N, k / N)


# ---------- маска покрытий для шейдера (плавные края дорог) ----------

func make_surface() -> Image:
	var img := Image.create(N / SM, N / SM, false, Image.FORMAT_RGBA8)
	for ch in range(0, CHN * CHN):
		update_surface(img, Vector2i(ch % CHN, ch / CHN))
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

const C_GRASS := [Color("6c9636"), Color("7aa13c"), Color("88aa42"), Color("9fb24c")]
const C_DIRT := Color("c6a878")
const C_ROCK := Color("d9c7ad")
const C_SAND := Color("e2cf9c")
const C_SAND_WET := Color("bfae84")
const C_ROAD := Color("c9bba0")
const C_PLAZA := Color("d8c9b0")
const C_YARD := Color("b8a07a")
const C_FIELD := Color("9a7a4e")
const LOCK := Color("c4bb98")


func top_color(k: int) -> Color:
	var c: Color
	match kind[k]:
		Kind.ROCK: c = C_ROCK
		Kind.SAND: c = C_SAND_WET if h[k] < WATER_Y + 0.12 else C_SAND
		Kind.YARD: c = C_YARD
		Kind.FIELD: c = C_FIELD
		_: c = C_GRASS[tint[k]]
	return c


## Сетка куска (ci, cj): верх — полосами из одинаковых клеток (меньше треугольников), стенки — к нижним соседям
func chunk_mesh(ci: int, cj: int) -> ArrayMesh:
	var v := PackedVector3Array()
	var nr := PackedVector3Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()
	var ix := PackedInt32Array()
	var quad := func(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, n: Vector3, c: Color, kd: int, top: float) -> void:
		var base := v.size()
		v.append_array([a, b, cc, d])
		nr.append_array([n, n, n, n])
		var lc := c.srgb_to_linear()
		col.append_array([lc, lc, lc, lc])
		var u := Vector2(kd, top)
		uv.append_array([u, u, u, u])
		ix.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
	var i0 := ci * CH
	var j0 := cj * CH
	var plot_cells := int(PLOT / CELL)
	for j in range(j0, j0 + CH):
		var i := i0
		while i < i0 + CH:
			var k := idx(i, j)
			var y := h[k]
			var kd := kind[k]
			var tc := tint[k]
			var own := is_owned(cell_center(i, j))
			var e := i + 1
			while e < i0 + CH:
				var k2 := idx(e, j)
				if h[k2] != y or kind[k2] != kd or tint[k2] != tc:
					break
				if e % plot_cells == 0:
					break                       # граница участка — не сливаем (разный цвет своей и чужой земли)
				e += 1
			var c := top_color(k)
			if not own:
				c = c.lerp(LOCK, 0.2)
			var x0 := i * CELL
			var x1 := e * CELL
			var z0 := j * CELL
			var z1 := z0 + CELL
			quad.call(Vector3(x0, y, z0), Vector3(x0, y, z1), Vector3(x1, y, z1), Vector3(x1, y, z0), Vector3.UP, c, kd, y)
			i = e
	# стенки уступов
	for j in range(j0, j0 + CH):
		for i in range(i0, i0 + CH):
			var k := idx(i, j)
			var y := h[k]
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ni := i + d.x
				var nj := j + d.y
				var yn := WATER_Y - 3.0
				if inside(ni, nj):
					yn = h[idx(ni, nj)]
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
				var rocky := y - yn >= 0.45 or kind[k] == Kind.ROCK
				var c := C_ROCK if rocky else top_color(k)
				quad.call(Vector3(b.x, yn, b.z), Vector3(b.x, y, b.z), Vector3(a.x, y, a.z), Vector3(a.x, yn, a.z), Vector3(d.x, 0, d.y), c, Kind.ROCK if rocky else Kind.DIRT, y)
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
	for k in N * N:
		if kind[k] != base_kind[k] or h[k] != base_h[k]:
			cells.append(k)
			kinds.append(kind[k])
			hs.append(h[k])
	var plots := []
	for p in owned:
		plots.append([p.x, p.y])
	return {"cells": Marshalls.raw_to_base64(cells.to_byte_array()), "kinds": Marshalls.raw_to_base64(kinds),
		"hs": Marshalls.raw_to_base64(hs.to_byte_array()), "plots": plots}


func load_changes(d: Dictionary) -> void:
	var cells := Marshalls.base64_to_raw(d.get("cells", "")).to_int32_array()
	var kinds := Marshalls.base64_to_raw(d.get("kinds", ""))
	var hs := Marshalls.base64_to_raw(d.get("hs", "")).to_float32_array()
	for n in cells.size():
		kind[cells[n]] = kinds[n]
		h[cells[n]] = hs[n]
	owned.clear()
	for p in d.get("plots", []):
		owned[Vector2i(int(p[0]), int(p[1]))] = true
