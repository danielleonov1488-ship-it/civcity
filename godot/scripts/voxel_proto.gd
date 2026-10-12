extends RefCounted
## Пробная воксельная графика «как в Town to City» (для сравнения A/B с улицей из Synty).
## Один экземпляр — одна модель: трёхмерная сетка номеров цветов → один ArrayMesh только из видимых граней.
## У каждого вокселя свой лёгкий сдвиг цвета (±5–9 %), в углах и щелях — мягкое затенение (AO по вершинам).
## build_mesh() — простой мешер (цвет в вершинах, StandardMaterial3D), build_greedy() — экономный:
## одинаковые соседние грани сливаются в большие прямоугольники, разброс цвета по вокселям считает шейдер.
## Модели: римские домики с террасой, фонтан, кипарис, олива, скамья, фонарь, мостовая.

const V := 0.2                       # размер вокселя, м (дверь 8 вокселей = 1,6 м, этаж 12–13 = 2,5 м)

enum { AIR, W_WHITE, W_YELLOW, W_BLUE, W_PINK, W_LILAC, STONE, STONE_D, FRAME, DARK, DARK2, DOOR, DOOR_D,
	SHUT_G, SHUT_GD, SHUT_B, SHUT_BD, TILE_A, TILE_B, TILE_C, TILE_D, TERR, POT, LEAF, LEAF_D, FL_RED,
	FL_PINK, FL_WHITE, FL_YEL, WOOD, WOOD_D, CYP_A, CYP_B, CYP_C, OLIVE_A, OLIVE_B, OLIVE_C, BARK, WATER,
	WATER_L, MARBLE, PAVE_A, PAVE_B, PAVE_C, LANTERN, IRON, BAND_R, BRONZE, CLOTH_R, CLOTH_W, GRASS }

## цвет (sRGB) и сила разброса яркости по вокселям
const PAL := [
	["000000", 0.0],    # AIR
	["ebe2d2", 0.07],   # W_WHITE   белёная штукатурка
	["dcb96e", 0.09],   # W_YELLOW  охра
	["86b2d4", 0.09],   # W_BLUE    голубая
	["e3a493", 0.08],   # W_PINK    помпейская розовая
	["c8bddb", 0.08],   # W_LILAC   сиреневая
	["aea48f", 0.09],   # STONE     туф цоколя
	["908671", 0.09],   # STONE_D
	["f4efe4", 0.035],  # FRAME     светлые наличники, карнизы
	["3b2d4f", 0.06],   # DARK      темнота за окном (сиреневая, как в TtC)
	["55406a", 0.06],   # DARK2
	["8e5233", 0.06],   # DOOR
	["6c3b25", 0.06],   # DOOR_D
	["6fc37c", 0.06],   # SHUT_G    зелёные ставни
	["58a867", 0.06],   # SHUT_GD
	["8a5a37", 0.06],   # SHUT_B    коричневые ставни
	["6e452a", 0.06],   # SHUT_BD
	["dc744b", 0.07],   # TILE_A    черепица
	["c9603d", 0.07],   # TILE_B
	["e88c5d", 0.07],   # TILE_C
	["a9492f", 0.07],   # TILE_D    конёк, тёмная черепица
	["ecc8a2", 0.05],   # TERR      пол террасы
	["c4643c", 0.07],   # POT       терракотовый горшок
	["5e9442", 0.12],   # LEAF
	["467530", 0.12],   # LEAF_D
	["d9434a", 0.08],   # FL_RED
	["ef8fb4", 0.08],   # FL_PINK
	["f6f2e8", 0.04],   # FL_WHITE
	["f2c94a", 0.08],   # FL_YEL
	["8c5a36", 0.07],   # WOOD
	["5f3d26", 0.07],   # WOOD_D
	["3c5c33", 0.10],   # CYP_A     кипарис
	["4b6e3e", 0.10],   # CYP_B
	["2f4a2a", 0.10],   # CYP_C
	["889a66", 0.10],   # OLIVE_A   олива — серебристо-зелёная
	["a3ae80", 0.10],   # OLIVE_B
	["6d8152", 0.10],   # OLIVE_C
	["6e5c49", 0.09],   # BARK
	["58aec6", 0.05],   # WATER
	["b0e4ee", 0.04],   # WATER_L
	["ebe6dc", 0.04],   # MARBLE
	["dcc6a2", 0.08],   # PAVE_A    мостовая
	["cbb38e", 0.08],   # PAVE_B
	["e6d4b4", 0.08],   # PAVE_C
	["ffd98a", 0.02],   # LANTERN
	["3d3835", 0.05],   # IRON
	["a8443a", 0.06],   # BAND_R    помпейская красная полоса
	["9a7442", 0.06],   # BRONZE
	["c8473c", 0.05],   # CLOTH_R
	["f1ebdc", 0.04],   # CLOTH_W
	["7f9a4a", 0.10],   # GRASS
]

const DIRS := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
const TU := [Vector3i(0, 1, 0), Vector3i(0, 1, 0), Vector3i(1, 0, 0), Vector3i(1, 0, 0), Vector3i(1, 0, 0), Vector3i(1, 0, 0)]
const TV := [Vector3i(0, 0, 1), Vector3i(0, 0, 1), Vector3i(0, 0, 1), Vector3i(0, 0, 1), Vector3i(0, 1, 0), Vector3i(0, 1, 0)]
const CORN := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]
const AO_CURVE := [0.5, 0.68, 0.85, 1.0]

var sx := 0
var sy := 0
var sz := 0
var data := PackedByteArray()
var off := Vector3i.ZERO             # клетка сетки = координаты модели + off
var pivot := Vector3.ZERO            # точка модели, которая станет (0,0,0) меша
var seed := 1
var tris := 0
var rng := RandomNumberGenerator.new()
var lights: Array[Vector3] = []      # где фонари (в метрах меша)

static var _mat: StandardMaterial3D
static var _gmat: ShaderMaterial
static var _cols: Array[Color] = []


# ---------- сетка ----------

func alloc(lo: Vector3i, hi: Vector3i, s := 1) -> void:
	off = -lo
	sx = hi.x - lo.x + 1
	sy = hi.y - lo.y + 1
	sz = hi.z - lo.z + 1
	data = PackedByteArray()
	data.resize(sx * sy * sz)
	data.fill(0)
	seed = s
	rng.seed = s


func _gi(gx: int, gy: int, gz: int) -> int:
	return (gy * sz + gz) * sx + gx


func put(x: int, y: int, z: int, c: int) -> void:
	var gx := x + off.x
	var gy := y + off.y
	var gz := z + off.z
	if gx < 0 or gy < 0 or gz < 0 or gx >= sx or gy >= sy or gz >= sz:
		return
	data[_gi(gx, gy, gz)] = c


func at(x: int, y: int, z: int) -> int:
	var gx := x + off.x
	var gy := y + off.y
	var gz := z + off.z
	if gx < 0 or gy < 0 or gz < 0 or gx >= sx or gy >= sy or gz >= sz:
		return AIR
	return data[_gi(gx, gy, gz)]


## Прямоугольник включительно; c может быть массивом — тогда цвет случайный из него
func box(x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, c) -> void:
	for y in range(mini(y0, y1), maxi(y0, y1) + 1):
		for z in range(mini(z0, z1), maxi(z0, z1) + 1):
			for x in range(mini(x0, x1), maxi(x0, x1) + 1):
				put(x, y, z, _pick(c))


func _pick(c) -> int:
	if c is Array:
		return c[rng.randi() % c.size()]
	return c


func _solid(gx: int, gy: int, gz: int) -> bool:
	if gx < 0 or gy < 0 or gz < 0 or gx >= sx or gy >= sy or gz >= sz:
		return false
	return data[_gi(gx, gy, gz)] != 0


static func _hash(x: int, y: int, z: int, s: int) -> float:
	var h := x * 374761393 + y * 668265263 + z * 1274126177 + s * 1103515245
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0


static func _palette() -> Array[Color]:
	if _cols.is_empty():
		for p in PAL:
			_cols.append(Color(p[0]))
	return _cols


## Цвет вокселя: основной цвет палитры ± разброс яркости, редкие светлые/тёмные «камешки», лёгкий сдвиг тона
func _vcolor(gx: int, gy: int, gz: int, c: int) -> Color:
	var col: Color = _palette()[c]
	var j: float = PAL[c][1]
	var m := 1.0 + (_hash(gx, gy, gz, seed) - 0.5) * 2.0 * j
	var r2 := _hash(gx + 71, gy + 13, gz + 29, seed)
	if r2 > 0.95:
		m += j * 0.9
	elif r2 < 0.05:
		m -= j * 0.9
	m += (_hash(gx / 3, gy / 3, gz / 3, seed + 77) - 0.5) * j * 0.8   # пятна крупнее вокселя
	var t := (_hash(gx + 5, gy + 97, gz + 41, seed) - 0.5) * j * 0.5
	return Color(clampf(col.r * m + t, 0.0, 1.0), clampf(col.g * m, 0.0, 1.0), clampf(col.b * m - t, 0.0, 1.0))


# ---------- меш: простой ----------

static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.vertex_color_is_srgb = true
		_mat.roughness = 0.9
		_mat.metallic_specular = 0.25
	return _mat


## Каждая видимая грань — свой квадрат; цвет вокселя × затенение в вершинах
func build_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var ids := PackedInt32Array()
	var pv := Vector3(off) + pivot
	for gy in sy:
		for gz in sz:
			for gx in sx:
				var c := data[_gi(gx, gy, gz)]
				if c == 0:
					continue
				var base := _vcolor(gx, gy, gz, c)
				for d in 6:
					if d == 3 and gy == 0:
						continue                                  # низ нижнего слоя не виден никогда
					var n: Vector3i = DIRS[d]
					var qx := gx + n.x
					var qy := gy + n.y
					var qz := gz + n.z
					if _solid(qx, qy, qz):
						continue
					var u: Vector3i = TU[d]
					var v: Vector3i = TV[d]
					var ao := [0, 0, 0, 0]
					var i0 := verts.size()
					var o := Vector3(gx + maxi(n.x, 0), gy + maxi(n.y, 0), gz + maxi(n.z, 0))
					for k in 4:
						var du: int = CORN[k].x
						var dv: int = CORN[k].y
						var su := u * (2 * du - 1)
						var sv := v * (2 * dv - 1)
						var s1 := _solid(qx + su.x, qy + su.y, qz + su.z)
						var s2 := _solid(qx + sv.x, qy + sv.y, qz + sv.z)
						var s3 := _solid(qx + su.x + sv.x, qy + su.y + sv.y, qz + su.z + sv.z)
						var a := 0 if (s1 and s2) else 3 - (int(s1) + int(s2) + int(s3))
						ao[k] = a
						verts.append((o + Vector3(u) * du + Vector3(v) * dv - pv) * V)
						norms.append(Vector3(n))
						var f: float = AO_CURVE[a]
						cols.append(Color(base.r * f, base.g * f, base.b * f))
					_quad(ids, i0, ao, Vector3(u).cross(Vector3(v)).dot(Vector3(n)) > 0.0)
	tris = ids.size() / 3
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = ids
	var m := ArrayMesh.new()
	if verts.is_empty():
		return m
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, material())
	return m


## Два треугольника квадрата: диагональ выбирается по затенению (без «полос»), обход — по часовой (лицевая в Godot)
static func _quad(ids: PackedInt32Array, i0: int, ao: Array, ccw: bool) -> void:
	var q: Array
	if ao[0] + ao[2] > ao[1] + ao[3]:
		q = [1, 2, 3, 1, 3, 0]
	else:
		q = [0, 1, 2, 0, 2, 3]
	if ccw:
		q = [q[0], q[2], q[1], q[3], q[5], q[4]]
	for k in q:
		ids.append(i0 + k)


# ---------- меш: экономный (жадное слияние граней) ----------

static func greedy_material() -> ShaderMaterial:
	if _gmat == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform float vox = 0.2;
varying vec3 lp;
varying vec3 ln;
float h3(vec3 p) { p = fract(p * vec3(0.1031, 0.1030, 0.0973)); p += dot(p, p.yxz + 33.33); return fract((p.x + p.y) * p.z); }
void vertex() { lp = VERTEX / vox; ln = NORMAL; }
void fragment() {
	vec3 cell = floor(lp - ln * 0.5 + 0.0001);
	float r = h3(cell);
	float r2 = h3(cell + 17.3);
	float r3 = h3(cell + 41.7) - 0.5;
	float j = COLOR.a;
	float m = 1.0 + (r - 0.5) * 2.0 * j + (r2 > 0.95 ? j * 0.9 : (r2 < 0.05 ? -j * 0.9 : 0.0));
	vec3 c = COLOR.rgb * m + vec3(r3, 0.0, -r3) * j * 0.5;
	ALBEDO = clamp(c, 0.0, 1.0);
	ROUGHNESS = 0.9;
	SPECULAR = 0.25;
}
"""
		_gmat = ShaderMaterial.new()
		_gmat.shader = sh
		_gmat.set_shader_parameter("vox", V)
	return _gmat


## Грани одного цвета и с ровным затенением сливаются в прямоугольники; разброс по вокселям — в шейдере
## (в альфе вершины — сила разброса этого цвета). Цвет в вершинах переводится в линейный заранее.
func build_greedy() -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var ids := PackedInt32Array()
	var pv := Vector3(off) + pivot
	var pal := _palette()
	var dims := [sx, sy, sz]
	for d in 6:
		var n: Vector3i = DIRS[d]
		var u: Vector3i = TU[d]
		var v: Vector3i = TV[d]
		var ax := 0 if n.x != 0 else (1 if n.y != 0 else 2)
		var au := 0 if u.x != 0 else (1 if u.y != 0 else 2)
		var av := 0 if v.x != 0 else (1 if v.y != 0 else 2)
		var nu: int = dims[au]
		var nv: int = dims[av]
		var ccw := Vector3(u).cross(Vector3(v)).dot(Vector3(n)) > 0.0
		for s in dims[ax]:
			# маска слоя: ключ = цвет | затенение 4 углов << 8; -1 — нет грани
			var mask := PackedInt32Array()
			mask.resize(nu * nv)
			mask.fill(-1)
			var any := false
			for b in nv:
				for a in nu:
					var p := Vector3i.ZERO
					p[ax] = s
					p[au] = a
					p[av] = b
					var c := data[_gi(p.x, p.y, p.z)]
					if c == 0 or (d == 3 and p.y == 0):
						continue
					var q := p + n
					if _solid(q.x, q.y, q.z):
						continue
					var key := c
					for k in 4:
						var su: Vector3i = u * (2 * CORN[k].x - 1)
						var sv: Vector3i = v * (2 * CORN[k].y - 1)
						var s1 := _solid(q.x + su.x, q.y + su.y, q.z + su.z)
						var s2 := _solid(q.x + sv.x, q.y + sv.y, q.z + sv.z)
						var s3 := _solid(q.x + su.x + sv.x, q.y + su.y + sv.y, q.z + su.z + sv.z)
						var aov := 0 if (s1 and s2) else 3 - (int(s1) + int(s2) + int(s3))
						key |= aov << (8 + 2 * k)
					mask[b * nu + a] = key
					any = true
			if not any:
				continue
			for b in nv:
				var a := 0
				while a < nu:
					var key := mask[b * nu + a]
					if key < 0:
						a += 1
						continue
					var aos := [(key >> 8) & 3, (key >> 10) & 3, (key >> 12) & 3, (key >> 14) & 3]
					var flat: bool = aos[0] == aos[1] and aos[1] == aos[2] and aos[2] == aos[3]
					var w := 1
					var h := 1
					if flat:
						while a + w < nu and mask[b * nu + a + w] == key:
							w += 1
						var ok := true
						while b + h < nv and ok:
							for k in w:
								if mask[(b + h) * nu + a + k] != key:
									ok = false
									break
							if ok:
								h += 1
					for hb in h:
						for k in w:
							mask[(b + hb) * nu + a + k] = -1
					var c := key & 255
					var lin: Color = pal[c].srgb_to_linear()
					var p0 := Vector3.ZERO
					p0[ax] = s + maxi(n[ax], 0)
					p0[au] = a
					p0[av] = b
					var i0 := verts.size()
					for k in 4:
						var f: float = AO_CURVE[aos[k]]
						var pp: Vector3 = p0 + Vector3(u) * (CORN[k].x * w) + Vector3(v) * (CORN[k].y * h)
						verts.append((pp - pv) * V)
						norms.append(Vector3(n))
						cols.append(Color(lin.r * f, lin.g * f, lin.b * f, PAL[c][1]))
					_quad(ids, i0, aos, ccw)
					a += w
	tris = ids.size() / 3
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = ids
	var m := ArrayMesh.new()
	if verts.is_empty():
		return m
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, greedy_material())
	return m


# ---------- римский домик как в Town to City ----------
## Нижний этаж во всю глубину, сверху — терраса с парапетом; второй этаж отступает назад, над ним двускатная
## черепичная крыша коньком вдоль улицы, труба. Фасад смотрит на +Z, левый край x=0, фасад — плоскость z=0 меша.
## o: w (ширина в вокселях), d (глубина), t (глубина террасы), wall, shut (цвета), low/up (окна и двери
## фасада по порядку: "win", "door", "winf" — окно с ящиком цветов), back (окна сзади), chim (x трубы),
## pergola, band (красная полоса), canopy (навес над дверью), pots, seed
var wall_lamp := false


func house(o: Dictionary) -> void:
	wall_lamp = o.get("wall_lamp", false)
	var w: int = o.get("w", 22)
	var d: int = o.get("d", 26)
	var t: int = o.get("t", 8)
	var wall: int = o.get("wall", W_WHITE)
	var shut: int = o.get("shut", SHUT_G)
	var du := d - t                  # глубина второго этажа
	alloc(Vector3i(-2, -2, -3), Vector3i(w + 1, 38, d + 3), o.get("seed", 1))
	pivot = Vector3(0, 0, d)
	var fz := d - 1                  # передний слой стены
	# нижний этаж: y 0..12 (верхний слой — пол террасы), цоколь y -2..1
	box(0, -2, 0, w - 1, 12, d - 1, wall)
	box(0, -2, 0, w - 1, 1, d - 1, [STONE, STONE, STONE_D])
	if o.get("band", false):
		box(0, 2, 0, w - 1, 2, d - 1, BAND_R)      # помпейская полоса над цоколем
		box(0, 11, 0, w - 1, 11, d - 1, BAND_R)    # и под террасой
	# терраса и парапет (светлый выступающий поручень)
	box(1, 12, du, w - 2, 12, fz - 1, TERR)
	box(0, 13, fz, w - 1, 14, fz, wall)
	box(0, 13, du, 0, 14, fz, wall)
	box(w - 1, 13, du, w - 1, 14, fz, wall)
	box(0, 15, fz, w - 1, 15, fz + 1, FRAME)
	box(0, 15, du, 0, 15, fz, FRAME)
	box(w - 1, 15, du, w - 1, 15, fz, FRAME)
	# второй этаж y 13..24
	box(0, 13, 0, w - 1, 24, du - 1, wall)
	box(0, 23, du, w - 1, 23, du, FRAME)           # карниз под свесом
	box(0, 23, -1, w - 1, 23, -1, FRAME)
	# крыша как в Town to City: ступени 2:1 от свеса до конька; поверх — выпуклые ряды черепицы-калиптеров
	# (2 вокселя шириной, через 3), каждая черепица своим тоном, концы рядов нависают над свесом
	var z0 := -2
	var z1 := du + 1
	var ridge := 0
	for z in range(z0, z1 + 1):
		var e := mini(z - z0, z1 - z)
		var top := 25 + e / 2
		ridge = maxi(ridge, top)
		if z >= 0 and z < du and top - 2 >= 25:
			box(0, 25, z, w - 1, top - 2, z, wall)  # фронтон
		var course := e / 2
		for x in range(-1, w + 1):
			var k := posmod(x + 1, 5)
			var col := (x + 1) / 5
			put(x, top - 1, z, TILE_D if e == 0 else TILE_B)
			if k < 2:
				# калиптер: светлый ряд вниз по скату; ступеньки у соседних рядов вразбежку (не «сетка кубиков»)
				var ct := 25 + mini(e + (col % 2), (z1 - z0) / 2) / 2
				ct = maxi(ct, top)
				var tid := _hash(col, (e + (col % 2)) / 2, 7, seed)
				box(x, top, z, x, ct, z, TILE_B)
				put(x, ct + 1, z, TILE_C if tid < 0.65 else TILE_A)
			else:
				var pid := _hash(col * 3 + k, course, 9, seed)
				put(x, top, z, TILE_B if pid < 0.6 else TILE_D)
	for x in range(-1, w + 1):
		if posmod(x + 1, 5) < 2:
			for zz in [z0 - 1, z1 + 1]:
				put(x, 25, zz, TILE_C)
				put(x, 24, zz, TILE_B)
	var zc := (z0 + z1) / 2
	box(-1, ridge + 1, zc, w, ridge + 1, zc + 1, TILE_D)  # конёк
	box(-1, ridge + 2, zc, w, ridge + 2, zc + 1, AIR)
	# труба у конька
	var cx: int = o.get("chim", w - 6)
	var cz := zc - 1
	box(cx, 25, cz, cx + 2, ridge + 4, cz + 2, wall)
	box(cx - 1, ridge + 5, cz - 1, cx + 3, ridge + 5, cz + 3, TILE_D)
	box(cx, ridge + 6, cz, cx + 2, ridge + 6, cz + 2, TILE_B)
	put(cx + 1, ridge + 6, cz + 1, DARK)
	# фасад: окна и двери
	_row(o.get("low", ["win", "door", "win"]), w, fz, 1, 0, shut)
	_row(o.get("up", ["win", "door"]), w, du - 1, 1, 13, shut)
	_row(o.get("back", ["win", "win"]), w, 0, -1, 0, shut)
	_row(o.get("back_up", ["win"]), w, 0, -1, 13, shut)
	# навес над дверью
	if o.get("canopy", false):
		var dx := _elem_x(o.get("low", []), w, "door")
		if dx >= 0:
			box(dx - 4, 9, fz + 1, dx + 3, 9, fz + 2, [TILE_A, TILE_C])
			box(dx - 4, 10, fz + 1, dx + 3, 10, fz + 1, TILE_B)
			put(dx - 4, 8, fz + 2, WOOD_D)
			put(dx + 3, 8, fz + 2, WOOD_D)
	# горшки с цветами на террасе
	for p in o.get("pots", []):
		_pot(p, 13, fz - 2)
	if o.get("pergola", false):
		_pergola(w, du, fz)
	# у двери — горшок или амфора
	var low: Array = o.get("low", [])
	var di := low.find("door")
	if di >= 0 and o.get("door_pot", true):
		var ddx: int = _layout(low, w)[di]
		var right_ok: bool = (di == low.size() - 1 and ddx + 6 < w) or (di < low.size() - 1 and low[di + 1] != "winf")
		var left_ok: bool = (di == 0 and ddx - 6 >= 0) or (di > 0 and low[di - 1] != "winf")
		if right_ok:
			_pot(ddx + 3, 0, fz + 1)
		elif left_ok:
			_pot(ddx - 5, 0, fz + 1)


## Ширина элемента фасада
static func _ew(e: String) -> int:
	return 6 if e == "door" else 8


## Расставить элементы ряда по ширине: равные промежутки
static func _layout(list: Array, w: int) -> Array:
	var total := 0
	for e in list:
		total += _ew(e)
	var gap := float(w - total) / float(list.size() + 1)
	var out := []
	var x := gap
	for e in list:
		out.append(int(round(x)) + _ew(e) / 2)
		x += _ew(e) + gap
	return out


func _elem_x(list: Array, w: int, kind: String) -> int:
	var xs := _layout(list, w)
	for i in list.size():
		if list[i] == kind:
			return xs[i]
	return -1


## Ряд окон/дверей на стене z=fz (наружу — s: +1 вперёд, -1 назад), низ этажа на высоте y0
func _row(list: Array, w: int, fz: int, s: int, y0: int, shut: int) -> void:
	var xs := _layout(list, w)
	for i in list.size():
		var e: String = list[i]
		var cx: int = xs[i]
		if e == "door":
			_door(cx, fz, s, y0)
		else:
			_window(cx, fz, s, y0 + 4, shut, e == "winf")


## Окно 4×4: светлый наличник, тёмная глубина, подоконник, ставни по бокам
func _window(cx: int, fz: int, s: int, y: int, shut: int, flowers: bool) -> void:
	box(cx - 3, y - 1, fz, cx + 2, y + 4, fz, FRAME)
	box(cx - 2, y, fz, cx + 1, y + 3, fz, AIR)
	box(cx - 2, y, fz - s, cx + 1, y + 3, fz - s, [DARK, DARK, DARK2])
	box(cx - 2, y + 1, fz - s, cx + 1, y + 1, fz - s, DARK2)
	box(cx - 3, y - 1, fz + s, cx + 2, y - 1, fz + s, FRAME)
	var sd := SHUT_GD if shut == SHUT_G else SHUT_BD
	box(cx - 4, y, fz + s, cx - 3, y + 3, fz + s, shut)
	box(cx + 2, y, fz + s, cx + 3, y + 3, fz + s, shut)
	put(cx - 4, y + 1, fz + s, sd)
	put(cx + 3, y + 1, fz + s, sd)
	put(cx - 3, y + 3, fz + s, sd)
	put(cx + 2, y + 3, fz + s, sd)
	if flowers:
		box(cx - 3, y - 1, fz + s, cx + 2, y - 1, fz + 2 * s, WOOD)
		box(cx - 3, y - 2, fz + 2 * s, cx + 2, y - 2, fz + 2 * s, WOOD_D)
		for x in range(cx - 3, cx + 3):
			put(x, y, fz + 2 * s, _pick([LEAF, LEAF_D, FL_RED, FL_PINK, LEAF, FL_RED]))
			if rng.randf() < 0.22:
				put(x, y + 1, fz + 2 * s, _pick([LEAF, FL_RED, FL_PINK]))
		put(cx + 2, y - 2, fz + 2 * s, LEAF)               # плющ свисает


## Дверь 4×8 в глубине стены, наличник и каменная ступенька
func _door(cx: int, fz: int, s: int, y: int) -> void:
	box(cx - 3, y, fz, cx + 2, y + 8, fz, FRAME)
	box(cx - 2, y, fz, cx + 1, y + 7, fz - s, AIR)
	box(cx - 2, y, fz - 2 * s, cx + 1, y + 7, fz - 2 * s, DOOR)
	box(cx - 1, y, fz - 2 * s, cx - 1, y + 7, fz - 2 * s, DOOR_D)
	box(cx - 2, y + 6, fz - 2 * s, cx + 1, y + 6, fz - 2 * s, DOOR_D)
	put(cx, y + 3, fz - 2 * s, BRONZE)
	box(cx - 3, y + 8, fz + s, cx + 2, y + 8, fz + s, FRAME)     # выступающая перемычка
	if y == 0:
		box(cx - 3, 0, fz + s, cx + 2, 0, fz + s, [STONE, STONE_D])  # ступенька
		if s > 0 and wall_lamp:
			put(cx + 3, 8, fz + 1, IRON)                  # настенный фонарь у двери
			put(cx + 3, 7, fz + 1, LANTERN)
			put(cx + 3, 6, fz + 1, IRON)
			lights.append((Vector3(cx + 3.5, 7.5, fz + 1.5) - pivot) * V)


## Терракотовый горшок 2×2×2 с кустом и цветами
func _pot(x: int, y: int, z: int) -> void:
	box(x, y, z, x + 1, y + 1, z + 1, POT)
	box(x, y + 2, z, x + 1, y + 3, z + 1, [LEAF, LEAF, LEAF_D])
	put(x + rng.randi() % 2, y + 4, z + rng.randi() % 2, LEAF)
	for k in 3:
		put(x + rng.randi() % 2, y + 2 + rng.randi() % 3, z + 1 + (k % 2), _pick([FL_RED, FL_PINK, FL_WHITE]))


## Пергола с виноградом над террасой
func _pergola(w: int, du: int, fz: int) -> void:
	for px in [1, w - 2]:
		box(px, 13, fz - 1, px, 21, fz - 1, WOOD)
	box(0, 22, fz - 1, w - 1, 22, fz - 1, WOOD_D)
	for x in range(1, w - 1, 3):
		box(x, 22, du, x, 22, fz - 1, WOOD)
	for z in range(du, fz):
		for x in range(0, w):
			if rng.randf() < 0.55:
				put(x, 23, z, _pick([LEAF, LEAF, LEAF_D]))
	for px in [1, w - 2]:
		for y in range(15, 22):
			if rng.randf() < 0.6:
				put(px + (1 if px == 1 else -1), y, fz - 1, _pick([LEAF, LEAF_D]))
	for k in 6:
		put(rng.randi_range(1, w - 2), 21, rng.randi_range(du, fz - 1), _pick([LEAF_D, FL_RED]))


# ---------- прочее ----------

## Римский уличный фонтан (как в Помпеях): чаша из каменных плит, столб с бронзовой головой и струёй
func fountain() -> void:
	alloc(Vector3i(-1, -1, -1), Vector3i(9, 9, 9), 11)
	pivot = Vector3(4.5, 0, 4.5)
	box(-1, -1, -1, 9, 0, 9, [PAVE_B, PAVE_A, STONE])  # площадка
	box(0, 0, 0, 8, 1, 8, [STONE, STONE, STONE_D])
	box(0, 2, 0, 8, 2, 8, MARBLE)
	box(1, 1, 1, 7, 2, 7, AIR)
	box(1, 1, 1, 7, 1, 7, [WATER, WATER, WATER_L])
	box(3, 1, 0, 5, 7, 1, [PAVE_C, PAVE_A, STONE])   # травертиновый столб у задней стенки
	box(2, 8, 0, 6, 8, 2, MARBLE)
	box(3, 9, 0, 5, 9, 1, PAVE_C)
	put(3, 6, 2, STONE_D)
	put(5, 6, 2, STONE_D)
	put(4, 5, 2, BRONZE)                              # голова-рожок
	put(4, 6, 2, BRONZE)
	put(4, 4, 3, WATER_L)
	put(4, 3, 3, WATER_L)
	put(4, 2, 3, WATER_L)
	box(3, 1, 3, 5, 1, 4, WATER_L)


## Кипарис: узкая тёмная свеча с рваным краем
func cypress(h := 28, s := 3) -> void:
	alloc(Vector3i(-4, -1, -4), Vector3i(4, h + 2, 4), s)
	pivot = Vector3(0.5, 0, 0.5)
	box(0, -1, 0, 0, 2, 0, BARK)
	for y in range(2, h + 1):
		var t := float(y - 2) / float(h - 2)
		var r := 2.9 * sin(clampf(t * 1.25 + 0.12, 0.0, 1.0) * PI * 0.5) * (1.0 - pow(t, 1.6)) + 0.6
		for z in range(-4, 5):
			for x in range(-4, 5):
				var dd := sqrt(float(x * x + z * z))
				var nz := (_hash(x, y, z, s) - 0.5) * 1.1
				if dd < r + nz:
					var c := CYP_A
					var hv := _hash(x + 3, y, z + 9, s)
					if hv > 0.72:
						c = CYP_B
					elif hv < 0.2 or dd < r - 1.4:
						c = CYP_C
					put(x, y, z, c)
	put(0, h + 1, 0, CYP_B)


## Олива: кривой ствол, серебристая раскидистая крона клочьями
func olive(s := 5) -> void:
	alloc(Vector3i(-9, -1, -9), Vector3i(9, 20, 9), s)
	pivot = Vector3(0.5, 0, 0.5)
	box(0, -1, 0, 1, 3, 1, BARK)
	box(1, 4, 0, 2, 6, 1, BARK)
	box(-1, 5, 1, 0, 8, 1, BARK)
	box(2, 7, 0, 3, 9, 0, BARK)
	box(-2, 8, 1, -1, 10, 2, BARK)
	box(1, 7, -1, 1, 10, -1, BARK)
	var blobs := [Vector4(3, 11, 0, 4.2), Vector4(-3, 12, 2, 4.0), Vector4(0, 14, -2, 3.8), Vector4(1, 13, 3, 3.6), Vector4(-1, 15, 0, 3.2), Vector4(5, 12, -3, 2.8)]
	for z in range(-9, 10):
		for y in range(6, 20):
			for x in range(-9, 10):
				var inside := false
				for b: Vector4 in blobs:
					var dv := Vector3(x - b.x, (y - b.y) * 1.25, z - b.z)
					if dv.length() < b.w + (_hash(x, y, z, s) - 0.5) * 1.6:
						inside = true
						break
				if inside:
					var hv := _hash(x + 7, y + 1, z + 3, s)
					var c := OLIVE_A
					if hv > 0.68:
						c = OLIVE_B
					elif hv < 0.25:
						c = OLIVE_C
					if at(x, y, z) == AIR:
						put(x, y, z, c)


## Деревянная скамья (ножки и спинка темнее)
func bench() -> void:
	alloc(Vector3i(0, 0, 0), Vector3i(8, 3, 2), 21)
	pivot = Vector3(4.5, 0, 1.5)
	for x in [0, 7]:
		box(x, 0, 0, x, 0, 1, WOOD_D)
		box(x, 1, 0, x, 3, 0, WOOD_D)
	box(0, 1, 0, 7, 1, 1, WOOD)
	box(0, 2, 0, 7, 3, 0, WOOD)
	box(1, 2, 0, 6, 2, 0, AIR)
	box(0, 1, 2, 7, 1, 2, AIR)


## Уличный фонарь: каменная тумба, деревянный столб, фонарь 3×3 со светлыми стёклами и шапкой
func lamp() -> void:
	alloc(Vector3i(-1, 0, -1), Vector3i(1, 16, 1), 31)
	pivot = Vector3(0.5, 0, 0.5)
	box(-1, 0, -1, 1, 0, 1, [STONE, STONE_D])
	box(0, 1, 0, 0, 10, 0, WOOD_D)
	box(-1, 11, -1, 1, 13, 1, IRON)
	for p in [Vector3i(0, 0, -1), Vector3i(0, 0, 1), Vector3i(-1, 0, 0), Vector3i(1, 0, 0)]:
		put(p.x, 11, p.z, LANTERN)
		put(p.x, 12, p.z, LANTERN)
	box(-1, 14, -1, 1, 14, 1, TILE_D)
	put(0, 15, 0, IRON)
	lights.append((Vector3(0.5, 12.0, 0.5) - pivot) * V)


## Мостовая из плит 2×2 с разным тоном, один слой (верх на +V над низом меша)
func pavement(lx: int, lz: int) -> void:
	alloc(Vector3i(0, 0, 0), Vector3i(lx - 1, 0, lz - 1), 41)
	pivot = Vector3(0, 0, 0)
	for z in lz:
		var row := z / 2
		for x in lx:
			var stone := (x + (row % 2)) / 2
			var hv := _hash(stone, row, 3, seed)
			put(x, 0, z, PAVE_A if hv < 0.45 else (PAVE_B if hv < 0.75 else PAVE_C))
