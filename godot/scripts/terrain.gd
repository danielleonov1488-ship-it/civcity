class_name Terrain
extends RefCounted
## Земля витрины: холмы с мелкими уступами (как в Town to City), скала с воротами на севере, морской берег на востоке,
## ровная долина под город посередине. Высота квантуется шагом STEP — на склонах видны тонкие «горизонтали».
## Клетка CELL метра; у каждой — высота, вид покрытия и цвет. Сетка строится одной моделью.

const CELL := 0.25
const N := 320                 # клеток на сторону (80 м)
const STEP := 0.125            # шаг уступа по высоте — мелкий, как в Town to City
const TOWN_Y := 2.0            # высота долины под город
const SEA_Y := 0.0             # уровень моря

enum Kind { GRASS, DIRT, ROCK, SAND, COBBLE, PLAZA }

var h := PackedFloat32Array()      # высота клетки
var kind := PackedByteArray()      # вид покрытия
var tint := PackedFloat32Array()   # 0…1 — оттенок травы (сочная ↔ выгоревшая)

var n1 := FastNoiseLite.new()
var n2 := FastNoiseLite.new()
var n3 := FastNoiseLite.new()

# дорога от ворот в скале к площади и улицы (ломаные), площадь — неровный круг
const GATE := Vector2(40.0, 16.4)
const PLAZA_C := Vector2(38.0, 44.0)
const PLAZA_R := 8.0
const TUNNEL := Rect2(37.9, 9.0, 4.2, 7.6)   # тоннель за воротами: здесь у скалы нет стенок — виден проход
var roads := [
	{"pts": [Vector2(40, 15.0), Vector2(40, 24), Vector2(38.8, 31), Vector2(38.2, 37)], "w": 1.5, "kind": Kind.COBBLE},
	{"pts": [Vector2(31, 44.5), Vector2(22, 45.5), Vector2(11, 47.5)], "w": 1.4, "kind": Kind.COBBLE},
	{"pts": [Vector2(45.5, 45.5), Vector2(53, 47.0), Vector2(60.5, 48.5)], "w": 1.4, "kind": Kind.COBBLE},
	{"pts": [Vector2(36.5, 51.5), Vector2(35.0, 58), Vector2(31, 64)], "w": 1.1, "kind": Kind.COBBLE},
]


func _init() -> void:
	n1.seed = 7
	n1.frequency = 0.035
	n1.fractal_octaves = 4
	n2.seed = 19
	n2.frequency = 0.09
	n3.seed = 31
	n3.frequency = 0.02
	build()


func idx(i: int, j: int) -> int:
	return j * N + i


func inside(i: int, j: int) -> bool:
	return i >= 0 and j >= 0 and i < N and j < N


## Высота в точке мира (метры, x/z от угла карты)
func height_at(x: float, z: float) -> float:
	var i := clampi(int(x / CELL), 0, N - 1)
	var j := clampi(int(z / CELL), 0, N - 1)
	return h[idx(i, j)]


static func seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func road_dist(p: Vector2) -> Array:
	var best := 1e9
	var bk := -1
	var bw := 0.0
	for r in roads:
		var pts: Array = r["pts"]
		for k in pts.size() - 1:
			var d := seg_dist(p, pts[k], pts[k + 1])
			if d - r["w"] < best - bw:
				best = d
				bw = r["w"]
				bk = r["kind"]
	return [best, bw, bk]


func plaza_r(p: Vector2) -> float:
	var a := atan2(p.y - PLAZA_C.y, p.x - PLAZA_C.x)
	return PLAZA_R + sin(a * 3.0 + 0.7) * 0.9 + sin(a * 5.0 + 2.1) * 0.5


## Высота рельефа до квантования
func raw_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var y := TOWN_Y + n1.get_noise_2d(x, z) * 1.1
	# холмы на севере и на западе
	var north := smoothstep(24.0, 6.0, z)
	y += north * (3.6 + n3.get_noise_2d(x * 2.0, z) * 2.2)
	var west := smoothstep(16.0, 2.0, x) * (1.0 - north)
	y += west * (1.8 + n1.get_noise_2d(x * 1.7, z * 1.7) * 1.0)
	# скала: резкий подъём у ворот, с неровным краем
	var cliff_z := 16.8 + n2.get_noise_2d(x, 0.0) * 1.4 + absf(x - GATE.x) * 0.02
	cliff_z = lerpf(16.3, cliff_z, smoothstep(3.5, 7.5, absf(x - GATE.x)))   # у ворот скала ровная
	y += smoothstep(cliff_z + 0.6, cliff_z - 0.6, z) * 4.0
	# город: ровная долина
	var town := 1.0 - smoothstep(19.0, 27.0, p.distance_to(Vector2(38, 46)))
	y = lerpf(y, TOWN_Y + n2.get_noise_2d(x, z) * 0.2, town)
	# дорога от ворот прорезает склон ровной полосой
	var rd: Array = road_dist(p)
	var cut := 1.0 - smoothstep(rd[1] + 0.6, rd[1] + 3.0, rd[0])
	y = lerpf(y, TOWN_Y, cut)
	# море на востоке: берег неровный, пляж пологий
	var coast := 64.0 + n3.get_noise_2d(0.0, z * 3.0) * 5.0
	var sea := smoothstep(coast - 5.0, coast + 4.0, x)
	y = lerpf(y, SEA_Y - 2.4, sea)
	return y


func build() -> void:
	h.resize(N * N)
	kind.resize(N * N)
	tint.resize(N * N)
	for j in N:
		for i in N:
			var x := (i + 0.5) * CELL
			var z := (j + 0.5) * CELL
			var y := raw_height(x, z)
			var k := idx(i, j)
			h[k] = roundf(y / STEP) * STEP
			tint[k] = clampf(0.5 + n2.get_noise_2d(x * 0.6, z * 0.6) * 0.9 + n1.get_noise_2d(x * 3.0, z * 3.0) * 0.3, 0.0, 1.0)
			kind[k] = Kind.GRASS
	# покрытия: мостовая и площадь, песок у моря, скала на обрывах
	for j in N:
		for i in N:
			var k := idx(i, j)
			var p := Vector2((i + 0.5) * CELL, (j + 0.5) * CELL)
			var y := h[k]
			if p.distance_to(PLAZA_C) < plaza_r(p):
				kind[k] = Kind.PLAZA
				h[k] = TOWN_Y
				continue
			var rd: Array = road_dist(p)
			if rd[0] < rd[1] and absf(y - TOWN_Y) < 0.3:
				kind[k] = rd[2]
				h[k] = TOWN_Y
				continue
			if y <= SEA_Y + 0.5 and p.x > 50.0:
				kind[k] = Kind.SAND
				continue
			var drop := 0.0
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if inside(i + d.x, j + d.y):
					drop = maxf(drop, absf(y - h[idx(i + d.x, j + d.y)]))
			if drop >= 0.45:
				kind[k] = Kind.ROCK


# ---------- цвета ----------

const C_GRASS_LUSH := Color("6f9a40")
const C_GRASS := Color("8aa94a")
const C_GRASS_DRY := Color("b3ab58")
const C_DIRT := Color("8c6a47")
const C_ROCK := Color("d2c2ad")
const C_ROCK2 := Color("bba792")
const C_SAND := Color("e3d3a3")
const C_SAND_WET := Color("c7b487")
const C_COBBLE := Color("b8aa93")
const C_PLAZA := Color("ddd1bc")


func top_color(k: int, y: float) -> Color:
	match kind[k]:
		Kind.ROCK:
			return C_ROCK
		Kind.SAND:
			return C_SAND_WET if y < SEA_Y + 0.1 else C_SAND
		Kind.COBBLE:
			return C_COBBLE
		Kind.PLAZA:
			return C_PLAZA
		Kind.DIRT:
			return C_DIRT
	var t := tint[k]
	return C_GRASS_LUSH.lerp(C_GRASS, smoothstep(0.0, 0.5, t)).lerp(C_GRASS_DRY, smoothstep(0.55, 1.0, t))


## Цвет стенки уступа на высоте y: на обрывах — слои скалы, на мелких уступах — земля под травой
func side_color(k: int, y: float, top: float, drop: float) -> Color:
	if drop >= 1.0 or kind[k] == Kind.ROCK:
		var band := 0.5 + 0.5 * sin(y * 4.2 + sin(y * 1.3) * 1.5)
		return C_ROCK.lerp(C_ROCK2, band * 0.8)
	if kind[k] == Kind.SAND:
		return C_SAND_WET
	if kind[k] == Kind.COBBLE or kind[k] == Kind.PLAZA:
		return C_COBBLE.darkened(0.15)
	# у самого верха — край травы, ниже земля
	return top_color(k, top).darkened(0.12) if top - y < 0.08 else C_DIRT


# ---------- модель ----------

func mesh() -> ArrayMesh:
	var v := PackedVector3Array()
	var nr := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var ix := PackedInt32Array()
	var add_quad := func(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, n: Vector3, col: Color, kd: int, top: float) -> void:
		var base := v.size()
		v.append_array([a, b, cc, d])
		nr.append_array([n, n, n, n])
		var lc := col.srgb_to_linear()
		c.append_array([lc, lc, lc, lc])
		var u := Vector2(kd, top)
		uv.append_array([u, u, u, u])
		# по часовой, если смотреть со стороны нормали (так в Godot лицевая сторона)
		ix.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
	for j in N:
		for i in N:
			var k := idx(i, j)
			var y := h[k]
			var x0 := i * CELL
			var z0 := j * CELL
			var x1 := x0 + CELL
			var z1 := z0 + CELL
			add_quad.call(Vector3(x0, y, z0), Vector3(x0, y, z1), Vector3(x1, y, z1), Vector3(x1, y, z0), Vector3.UP, top_color(k, y), kind[k], y)
			# стенки к более низким соседям (по одной клетке высоты — полоска на каждый уровень скалы)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ni := i + d.x
				var nj := j + d.y
				var yn := SEA_Y - 3.0
				if inside(ni, nj):
					yn = h[idx(ni, nj)]
				if yn >= y:
					continue
				if d != Vector2i(0, -1) and TUNNEL.has_point(Vector2(x0 + CELL * 0.5, z0 + CELL * 0.5)):
					continue
				var drop := y - yn
				var n := Vector3(d.x, 0, d.y)
				# точки края клетки
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
				# стенка одним куском: слои скалы и кромку травы рисует видеокарта (по высоте верха в UV.y)
				var rocky := drop >= 0.4 or kind[k] == Kind.ROCK
				var col := C_ROCK if rocky else top_color(k, y)
				add_quad.call(Vector3(b.x, yn, b.z), Vector3(b.x, y, b.z), Vector3(a.x, y, a.z), Vector3(a.x, yn, a.z), n, col, Kind.ROCK if rocky else Kind.DIRT, y)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nr
	arr[Mesh.ARRAY_COLOR] = c
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = ix
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m
