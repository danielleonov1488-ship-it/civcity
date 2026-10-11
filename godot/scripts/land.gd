class_name Land
extends RefCounted
## Земля игры: карта 128×128 м из мелких клеток по 25 см с уступами по 12,5 см (как в Town to City).
## Долина посередине, холмы с террасами вокруг, скала с воротами на севере (оттуда приезжают новосёлы),
## море с пляжем на востоке. Земля поделена на участки 16×16 м: часть своя с начала, остальные покупаются.
## Сетка рисуется кусками 16×16 м: мостовая, дома и покупка участков перестраивают только свои куски.

const CELL := 0.25
const SIZE := 128.0
const N := 512
const STEP := 0.125
const BASE_Y := 2.0
const SEA_Y := 0.0
const CH := 64                     # клеток в куске сетки (16 м)
const CHN := N / CH
const PLOT := 16.0                 # участок земли
const PLOTS := 8
const GATE := Vector2(64.0, 15.2)  # ворота в скале
const CENTER := Vector2(64.0, 31.0)    # центр города — у ворот
const VALLEY := Vector2(62.0, 66.0)

enum Kind { GRASS, DIRT, ROCK, SAND, ROAD, PLAZA, YARD, FIELD }

var h := PackedFloat32Array()
var kind := PackedByteArray()
var tint := PackedByteArray()        # 0…3 — оттенок травы пятнами
var owned := {}                      # Vector2i участка → true
var dirty := {}                      # Vector2i куска → true (перестроить сетку)

var n1 := FastNoiseLite.new()
var n2 := FastNoiseLite.new()
var n3 := FastNoiseLite.new()


func _init() -> void:
	n1.seed = 11
	n1.frequency = 0.022
	n1.fractal_octaves = 4
	n2.seed = 23
	n2.frequency = 0.07
	n3.seed = 37
	n3.frequency = 0.012
	generate()


func idx(i: int, j: int) -> int:
	return j * N + i


func inside(i: int, j: int) -> bool:
	return i >= 0 and j >= 0 and i < N and j < N


func cell(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x / CELL), 0, N - 1), clampi(int(p.y / CELL), 0, N - 1))


func height_at(x: float, z: float) -> float:
	var c := cell(Vector2(x, z))
	return h[idx(c.x, c.y)]


func kind_at(x: float, z: float) -> int:
	var c := cell(Vector2(x, z))
	return kind[idx(c.x, c.y)]


func plot_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x / PLOT), 0, PLOTS - 1), clampi(int(p.y / PLOT), 0, PLOTS - 1))


func is_owned(p: Vector2) -> bool:
	return owned.has(plot_of(p))


func is_water(p: Vector2) -> bool:
	return height_at(p.x, p.y) < SEA_Y + 0.05


# ---------- рельеф ----------

func raw_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var y := BASE_Y + n1.get_noise_2d(x, z) * 1.2
	# холмы по краям долины — тем выше, чем дальше от середины
	var dv := p.distance_to(VALLEY)
	var hills := smoothstep(30.0, 56.0, dv)
	y += hills * (4.0 + n3.get_noise_2d(x * 1.5, z * 1.5) * 4.5 + n1.get_noise_2d(x * 2.0, z * 2.0) * 1.5)
	# скала на севере: резкий подъём, у ворот — ровная стена
	var cliff_z := 17.0 + n2.get_noise_2d(x * 0.8, 0.0) * 2.0
	cliff_z = lerpf(16.4, cliff_z, smoothstep(4.0, 9.0, absf(x - GATE.x)))
	y += smoothstep(cliff_z + 0.5, cliff_z - 0.5, z) * (6.0 + n2.get_noise_2d(x, z) * 1.5)
	# долина и место для центра: ровно
	var flat := 1.0 - smoothstep(26.0, 36.0, dv)
	flat = maxf(flat, 1.0 - smoothstep(8.0, 14.0, p.distance_to(CENTER)))
	flat = maxf(flat, 1.0 - smoothstep(3.0, 6.0, absf(x - GATE.x)) if z > 15.0 and z < 34.0 else 0.0)
	y = lerpf(y, BASE_Y + n2.get_noise_2d(x * 0.5, z * 0.5) * 0.15, flat)
	# море на востоке и бухта на юго-востоке
	var coast := 108.0 + n3.get_noise_2d(0.0, z * 2.5) * 7.0 - smoothstep(70.0, 128.0, z) * 14.0
	var sea := smoothstep(coast - 6.0, coast + 5.0, x)
	y = lerpf(y, SEA_Y - 2.6, sea)
	return y


func generate() -> void:
	h.resize(N * N)
	kind.resize(N * N)
	tint.resize(N * N)
	for j in N:
		for i in N:
			var x := (i + 0.5) * CELL
			var z := (j + 0.5) * CELL
			var k := idx(i, j)
			h[k] = roundf(raw_height(x, z) / STEP) * STEP
			var t := 0.5 + n2.get_noise_2d(x * 0.45, z * 0.45) * 1.1 + n1.get_noise_2d(x * 2.5, z * 2.5) * 0.35
			tint[k] = clampi(int(t * 4.0), 0, 3)
			kind[k] = Kind.GRASS
	for j in N:
		for i in N:
			var k := idx(i, j)
			var y := h[k]
			if y <= SEA_Y + 0.4 and i > N / 2:
				kind[k] = Kind.SAND
				continue
			var drop := 0.0
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if inside(i + d.x, j + d.y):
					drop = maxf(drop, absf(y - h[idx(i + d.x, j + d.y)]))
			if drop >= 0.45:
				kind[k] = Kind.ROCK
	# дорога от ворот к центру и площадка центра
	paint_line(GATE + Vector2(0, 1.0), CENTER + Vector2(0, -4.0), 1.6, Kind.ROAD, true)
	# свои участки с начала: 3×3 вокруг центра
	var cp := plot_of(CENTER + Vector2(0, 8))
	for dj in range(-1, 2):
		for di in range(-1, 2):
			owned[cp + Vector2i(di, dj)] = true
	dirty.clear()


# ---------- правка земли ----------

func _mark(i: int, j: int) -> void:
	dirty[Vector2i(clampi(i / CH, 0, CHN - 1), clampi(j / CH, 0, CHN - 1))] = true
	# стенки уступов на краю куска рисует соседний кусок
	if i % CH == 0 and i > 0:
		dirty[Vector2i((i - 1) / CH, clampi(j / CH, 0, CHN - 1))] = true
	if j % CH == 0 and j > 0:
		dirty[Vector2i(clampi(i / CH, 0, CHN - 1), (j - 1) / CH)] = true


## Покрасить клетки в круге (дорога, площадь, тропа; GRASS — стереть). flat — выровнять по середине.
## Возвращает [[клетка, было_вид, была_высота], …] для отмены
func paint_circle(p: Vector2, r: float, kd: int, flat := false, only_owned := true) -> Array:
	var out := []
	var c := cell(p)
	var rc := int(ceil(r / CELL))
	var y0 := height_at(p.x, p.y)
	for j in range(c.y - rc, c.y + rc + 1):
		for i in range(c.x - rc, c.x + rc + 1):
			if not inside(i, j):
				continue
			var q := Vector2((i + 0.5) * CELL, (j + 0.5) * CELL)
			if q.distance_to(p) > r:
				continue
			if only_owned and not is_owned(q):
				continue
			var k := idx(i, j)
			var kk := kind[k]
			if kk == Kind.ROCK or kk == Kind.SAND or kk == Kind.YARD or h[k] < SEA_Y + 0.05:
				continue
			if kd == Kind.GRASS and kk == Kind.GRASS:
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


## Клетки под постройкой (повёрнутый прямоугольник): выровнять и засыпать утоптанной землёй
func flatten_obb(c: Vector2, ax: Vector2, hw: float, hd: float, y: float, kd: int = Kind.YARD, keep: Array = []) -> Array:
	var out := []
	var az := Vector2(-ax.y, ax.x)
	var r := hw + hd
	var c0 := cell(c - Vector2(r, r))
	var c1 := cell(c + Vector2(r, r))
	for j in range(c0.y, c1.y + 1):
		for i in range(c0.x, c1.x + 1):
			var q := Vector2((i + 0.5) * CELL, (j + 0.5) * CELL) - c
			if absf(q.dot(ax)) <= hw and absf(q.dot(az)) <= hd:
				var k := idx(i, j)
				if kind[k] in keep:
					continue                    # кромку мостовой не трогаем — дорога не рвётся
				out.append([Vector2i(i, j), kind[k], h[k]])
				h[k] = y
				kind[k] = kd
				_mark(i, j)
	return out


## Самая высокая и низкая точки под прямоугольником (можно ли ставить), [min, max, вода, чужая, скала]
func survey(c: Vector2, ax: Vector2, hw: float, hd: float) -> Array:
	var az := Vector2(-ax.y, ax.x)
	var lo := 1e9
	var hi := -1e9
	var water := false
	var foreign := false
	var rock := false
	for u in 5:
		for v in 5:
			var q := c + ax * (u / 2.0 - 1.0) * (hw - 0.1) + az * (v / 2.0 - 1.0) * (hd - 0.1)
			var y := height_at(q.x, q.y)
			lo = minf(lo, y)
			hi = maxf(hi, y)
			if y < SEA_Y + 0.05:
				water = true
			if not is_owned(q):
				foreign = true
			if kind_at(q.x, q.y) == Kind.ROCK:
				rock = true
	return [lo, hi, water, foreign, rock]


# ---------- цвета и сетка ----------

const C_GRASS := [Color("78a046"), Color("86ab4c"), Color("97b457"), Color("aab35e")]
const C_DIRT := Color("c6a878")
const C_ROCK := Color("d6c8b2")
const C_SAND := Color("e6d6a6")
const C_SAND_WET := Color("cbb98d")
const C_ROAD := Color("c9bba0")
const C_PLAZA := Color("d8c9b0")
const C_YARD := Color("b8a07a")
const C_FIELD := Color("9a7a4e")
const LOCK := Color("b9b39a")


func top_color(k: int) -> Color:
	var c: Color
	match kind[k]:
		Kind.ROCK: c = C_ROCK
		Kind.SAND: c = C_SAND_WET if h[k] < SEA_Y + 0.15 else C_SAND
		Kind.YARD: c = C_YARD
		Kind.FIELD: c = C_FIELD
		_: c = C_GRASS[tint[k]]
	return c


## Маска покрытий для шейдера земли: R — мостовая, G — площадь, B — тропа. Шейдер читает её
## с плавной выборкой, поэтому края дорог выходят скруглёнными, а не ступеньками по клеткам
func make_surface() -> Image:
	var data := PackedByteArray()
	data.resize(N * N * 4)
	for k in N * N:
		var kd := kind[k]
		data[k * 4] = 255 if kd == Kind.ROAD else 0
		data[k * 4 + 1] = 255 if kd == Kind.PLAZA else 0
		data[k * 4 + 2] = 255 if kd == Kind.DIRT else 0
		data[k * 4 + 3] = 255
	return Image.create_from_data(N, N, false, Image.FORMAT_RGBA8, data)


func update_surface(img: Image, ch: Vector2i) -> void:
	if img.has_mipmaps():
		img.clear_mipmaps()
	for j in range(ch.y * CH, ch.y * CH + CH):
		for i in range(ch.x * CH, ch.x * CH + CH):
			var kd := kind[idx(i, j)]
			img.set_pixel(i, j, Color(1.0 if kd == Kind.ROAD else 0.0, 1.0 if kd == Kind.PLAZA else 0.0, 1.0 if kd == Kind.DIRT else 0.0, 1.0))


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
	for j in range(j0, j0 + CH):
		var i := i0
		while i < i0 + CH:
			var k := idx(i, j)
			var y := h[k]
			var kd := kind[k]
			var tc := tint[k]
			var own := is_owned(Vector2((i + 0.5) * CELL, (j + 0.5) * CELL))
			var e := i + 1
			while e < i0 + CH:
				var k2 := idx(e, j)
				if h[k2] != y or kind[k2] != kd or tint[k2] != tc:
					break
				if e % int(PLOT / CELL) == 0:
					break                       # граница участка — не сливаем (разный цвет своей и чужой земли)
				e += 1
			var c := top_color(k)
			if not own:
				c = c.lerp(LOCK, 0.45)
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
				var yn := SEA_Y - 3.0
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
				var rocky := y - yn >= 0.4 or kind[k] == Kind.ROCK
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

func save_changes(base: Land) -> Dictionary:
	# сохраняем только клетки, отличающиеся от исходной карты
	var cells := PackedInt32Array()
	var kinds := PackedByteArray()
	var hs := PackedFloat32Array()
	for k in N * N:
		if kind[k] != base.kind[k] or h[k] != base.h[k]:
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
