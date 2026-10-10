class_name Kit
extends RefCounted
## Сборщик низкополигональных моделей в духе Synty: коробки, призмы, цилиндры, «капли» листвы,
## ряды черепицы. Плоские грани (у каждой своя нормаль), цвет — в вершинах.
## Всё, что добавлено, проходит через текущее преобразование `xf` — так детали ставятся и поворачиваются.

var verts := PackedVector3Array()
var norms := PackedVector3Array()
var cols := PackedColorArray()
var xf := Transform3D.IDENTITY


static func srgb(hex: String) -> Color:
	return Color(hex)


# ---------- базовые грани ----------

## Треугольник; нормаль — по правилу правой руки (a→b→c против часовой, если смотреть снаружи).
## В Godot лицевая сторона — по часовой, поэтому в буфер вершины идут в обратном порядке.
func tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	a = xf * a
	b = xf * b
	c = xf * c
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	verts.append_array([a, c, b])
	norms.append_array([n, n, n])
	cols.append_array([col, col, col])


## Треугольник, повёрнутый лицом от точки inside (для округлых деталей)
func tri_out(a: Vector3, b: Vector3, c: Vector3, col: Color, inside: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.dot((a + b + c) / 3.0 - inside) < 0.0:
		tri(a, c, b, col)
	else:
		tri(a, b, c, col)


func quad_out(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, inside: Vector3) -> void:
	tri_out(a, b, c, col, inside)
	tri_out(a, c, d, col, inside)


## Четырёхугольник, повёрнутый лицом к точке center (внутренние стенки тоннеля, свод арки)
func quad_in(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, center: Vector3) -> void:
	var m := (a + b + c + d) * 0.25
	quad_out(a, b, c, d, col, m * 2.0 - center)


## Четырёхугольник a-b-c-d (против часовой стрелки, если смотреть снаружи)
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	tri(a, b, c, col)
	tri(a, c, d, col)


## Коробка между углами lo и hi; skip — какие грани не рисовать ("top", "bottom", "x-", "x+", "z-", "z+")
func box(lo: Vector3, hi: Vector3, col: Color, skip: Array = ["bottom"]) -> void:
	var p := [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z),
		Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]
	if not "top" in skip: quad(p[4], p[7], p[6], p[5], col)
	if not "bottom" in skip: quad(p[0], p[1], p[2], p[3], col)
	if not "z-" in skip: quad(p[0], p[4], p[5], p[1], col)
	if not "z+" in skip: quad(p[2], p[6], p[7], p[3], col)
	if not "x-" in skip: quad(p[3], p[7], p[4], p[0], col)
	if not "x+" in skip: quad(p[1], p[5], p[6], p[2], col)


## Коробка по центру и размеру
func boxc(center: Vector3, size: Vector3, col: Color, skip: Array = ["bottom"]) -> void:
	box(center - size * 0.5, center + size * 0.5, col, skip)


## Цилиндр (или призма при малом числе сторон) от точки base вверх
func cyl(base: Vector3, r: float, h: float, sides: int, col: Color, r_top: float = -1.0, caps := true) -> void:
	if r_top < 0.0:
		r_top = r
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p0 := base + Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1 := base + Vector3(cos(a1) * r, 0, sin(a1) * r)
		var q0 := base + Vector3(cos(a0) * r_top, h, sin(a0) * r_top)
		var q1 := base + Vector3(cos(a1) * r_top, h, sin(a1) * r_top)
		quad(p0, q0, q1, p1, col)
		if caps and r_top > 0.001:
			tri(base + Vector3(0, h, 0), q1, q0, col)


func cone(base: Vector3, r: float, h: float, sides: int, col: Color) -> void:
	cyl(base, r, h, sides, col, 0.0)


## Цилиндр вдоль отрезка a→b (бревно, жердь, труба)
func rod(a: Vector3, b: Vector3, r: float, sides: int, col: Color) -> void:
	var axis := b - a
	var len := axis.length()
	if len < 1e-5:
		return
	var up := axis / len
	var side := up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
	var fwd := side.cross(up)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var o0 := (side * cos(a0) + fwd * sin(a0)) * r
		var o1 := (side * cos(a1) + fwd * sin(a1)) * r
		quad_out(a + o0, a + o1, b + o1, b + o0, col, (a + b) * 0.5)


## Полуцилиндр-черепица вдоль a→b, выпуклостью вверх (римская черепица-имбрекс)
func half_tube(a: Vector3, b: Vector3, r: float, sides: int, col: Color, up_hint := Vector3.UP) -> void:
	var axis := (b - a).normalized()
	var side := axis.cross(up_hint).normalized()
	var up := side.cross(axis).normalized()
	for i in sides:
		var a0 := PI * i / sides
		var a1 := PI * (i + 1) / sides
		var o0 := (side * cos(a0) + up * sin(a0)) * r
		var o1 := (side * cos(a1) + up * sin(a1)) * r
		quad_out(a + o0, b + o0, b + o1, a + o1, col, a + (b - a) * 0.5 - up * r * 0.01)
	# торец у нижнего края
	for i in sides:
		var a0 := PI * i / sides
		var a1 := PI * (i + 1) / sides
		tri_out(a, a + (side * cos(a1) + up * sin(a1)) * r, a + (side * cos(a0) + up * sin(a0)) * r, col.darkened(0.25), a + axis)


## «Капля» листвы: приплюснутый многогранник со случайными выпуклостями
func blob(center: Vector3, size: Vector3, col: Color, seed_v: int = 0, rough := 0.18) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	# икосаэдр, один раз подразделённый
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v: Array[Vector3] = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	for i in v.size():
		v[i] = v[i].normalized()
	var f := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var mid := {}
	var faces := []
	for tri_i in f:
		var m := []
		for k in 3:
			var a: int = tri_i[k]
			var b: int = tri_i[(k + 1) % 3]
			var key := Vector2i(mini(a, b), maxi(a, b))
			if not mid.has(key):
				v.append(((v[a] + v[b]) * 0.5).normalized())
				mid[key] = v.size() - 1
			m.append(mid[key])
		faces.append([tri_i[0], m[0], m[2]])
		faces.append([tri_i[1], m[1], m[0]])
		faces.append([tri_i[2], m[2], m[1]])
		faces.append([m[0], m[1], m[2]])
	var pts: Array[Vector3] = []
	for p in v:
		var k := 1.0 + rng.randf_range(-rough, rough)
		pts.append(center + Vector3(p.x * size.x, p.y * size.y, p.z * size.z) * k)
	for fc in faces:
		var a: Vector3 = pts[fc[0]]
		var b: Vector3 = pts[fc[1]]
		var c: Vector3 = pts[fc[2]]
		# снизу листва темнее, сверху светлее — как запечённый свет у Synty
		var hgt := clampf(((a.y + b.y + c.y) / 3.0 - center.y) / size.y * 0.5 + 0.5, 0.0, 1.0)
		var cc := col.darkened(0.22 * (1.0 - hgt)).lightened(0.06 * hgt)
		tri_out(a, b, c, cc, center)


# ---------- сборка ----------

func is_empty() -> bool:
	return verts.is_empty()


func mesh() -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	var m := ArrayMesh.new()
	if not verts.is_empty():
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


static func material(rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = rough
	m.metallic_specular = 0.25
	return m
