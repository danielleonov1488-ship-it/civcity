class_name Interiors
extends RefCounted
## Нутро построек (владелец 14.11: «чернота почти в каждом здании»). У стен Synty нет внутренностей: за дверью, аркой,
## окном, воротами — чёрная пустота. Общее решение, одним проходом по готовому чертежу (Catalog.make, перед масштабом):
##  1. Тёмные коробки «#dark»/«#lit» (нутро блока) становятся комнатой «#room»/«#room_lit» — коробка, у которой грани
##     смотрят ВНУТРЬ: снаружи, сквозь проём, видны задняя и боковые стены, пол и потолок тёплого цвета, а ближняя
##     стена не рисуется. Многоэтажным — перекрытия «#plate». Тонкие пластины за решётками окон — «#plate» (тёплое стекло).
##  2. Проёмы стен Synty (дверь, арка, лавка, окно, большие ворота) находятся замером самих моделей (holes: где в
##     проекции на стену нет геометрии) — и если за проёмом нет комнаты, за ним встаёт заднник: комната по размеру
##     проёма, а у больших — ещё и стеллаж с горшками.
## Материал один на все комнаты, светит сам (без света: тёплая «лампа» умеренной яркости, не лампочка), поэтому комнаты
## множатся без новых вызовов отрисовки (MultiMesh на «#room»). Ночью яркость меняет игра (set_light): у жилых
## домов с жильцами и у лавок в окнах тёплый огонёк, у пустых — темно, как и было.

const FL := 3.0
const DEPTH := 1.7                      # глубина заднника за проёмом (до масштаба Catalog.ARCH)
const SIDE := 0.15                      # на сколько комната шире проёма с каждой стороны
const MIN_HOLE := 0.28                  # проём меньше — не считается (щели, отдушины)

const WALL := Color(0.80, 0.60, 0.42)
const FLOOR := Color(0.56, 0.40, 0.27)
const CEIL := Color(0.58, 0.45, 0.33)

static var _holes := {}                 # модель → [Rect2(x, y, w, h), …] в осях модели
static var _meshes := {}
static var _mat_dim: StandardMaterial3D
static var _mat_lit: StandardMaterial3D


# ---------- материал и меши ----------

## Материал комнат: без освещения, цвет — в вершинах, общая яркость (albedo_color) меняет игра
static func material(lit: bool) -> StandardMaterial3D:
	if _mat_dim == null:
		for l in [false, true]:
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.vertex_color_use_as_albedo = true
			m.vertex_color_is_srgb = true
			m.cull_mode = BaseMaterial3D.CULL_BACK
			if l:
				_mat_lit = m
			else:
				_mat_dim = m
	return _mat_lit if lit else _mat_dim


## Яркость комнат: lamp — 0 днём, 1 ночью (как у окон «#lit» в Game._sky); deep — глубокая ночь
static func set_light(lamp: float, deep: bool) -> void:
	material(false).albedo_color = Color(1, 1, 1).lerp(Color(0.06, 0.055, 0.05), lamp)
	material(true).albedo_color = Color(1, 1, 1).lerp(Color(0.2, 0.135, 0.075) if deep else Color(0.34, 0.23, 0.12), lamp)


## Меш «#room», «#room_lit» (внутрь), «#plate», «#plate_lit» (наружу): единичная коробка вокруг начала координат
static func mesh(name: String) -> Mesh:
	if _meshes.has(name):
		return _meshes[name]
	var lit := name.ends_with("_lit")
	var inward := name.begins_with("#room")
	var st := {"v": [], "n": [], "c": []}
	var us := [0.0, 0.15, 0.85, 1.0]
	var vs := [0.0, 0.35, 1.0]
	var h := 0.5
	var sgn := -1.0 if inward else 1.0           # нормаль грани: наружу у «#plate», внутрь у «#room»
	# боковые стены: u вдоль грани, v вверх
	for f in [[Vector3(-h, -h, h), Vector3(1, 0, 0), Vector3(0, 0, 1)],        # +Z
			[Vector3(h, -h, h), Vector3(0, 0, -1), Vector3(1, 0, 0)],            # +X
			[Vector3(h, -h, -h), Vector3(-1, 0, 0), Vector3(0, 0, -1)],          # −Z
			[Vector3(-h, -h, -h), Vector3(0, 0, 1), Vector3(-1, 0, 0)]]:         # −X
		_face(st, f[0], f[1], Vector3(0, 1, 0), us, vs, f[2] * sgn, "wall")
	# пол и потолок
	# низ: у комнаты — пол (смотрит вверх), у перекрытия снизу — потолок; верх — наоборот
	_face(st, Vector3(-h, -h, -h), Vector3(1, 0, 0), Vector3(0, 0, 1), us, us, Vector3(0, -sgn, 0), "floor" if inward else "ceil")
	_face(st, Vector3(-h, h, -h), Vector3(1, 0, 0), Vector3(0, 0, 1), us, us, Vector3(0, sgn, 0), "ceil" if inward else "floor")
	var am := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array(st["v"])
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array(st["n"])
	arr[Mesh.ARRAY_COLOR] = PackedColorArray(st["c"])
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	am.surface_set_material(0, material(lit))
	_meshes[name] = am
	return am


## Грань сеткой: o — угол, u и v — направления (единичные, на всю грань), us/vs — доли по осям, n — нормаль видимой стороны
static func _face(st: Dictionary, o: Vector3, u: Vector3, v: Vector3, us: Array, vs: Array, n: Vector3, kind: String) -> void:
	var pts := []
	for j in vs.size():
		var row := []
		for i in us.size():
			row.append(o + u * float(us[i]) + v * float(vs[j]))
		pts.append(row)
	var base_col := WALL
	if kind == "floor":
		base_col = FLOOR
	elif kind == "ceil":
		base_col = CEIL
	for j in vs.size() - 1:
		for i in us.size() - 1:
			var q := [pts[j][i], pts[j][i + 1], pts[j + 1][i + 1], pts[j + 1][i]]
			var cs := []
			for k in 4:
				var ii: int = i + (1 if k in [1, 2] else 0)
				var jj: int = j + (1 if k in [2, 3] else 0)
				cs.append(base_col * _shade(kind, float(us[ii]), float(vs[jj])))
			for tri in [[0, 1, 2], [0, 2, 3]]:
				var a: Vector3 = q[tri[0]]
				var b: Vector3 = q[tri[1]]
				var c: Vector3 = q[tri[2]]
				var order: Array = tri
				if (c - a).cross(b - a).dot(n) < 0.0:          # в Godot лицевая сторона — обход по часовой
					order = [tri[0], tri[2], tri[1]]
				for k: int in order:
					(st["v"] as Array).append(q[k])
					(st["n"] as Array).append(n)
					var cc: Color = cs[k]
					cc.a = 1.0
					(st["c"] as Array).append(cc)


## Затенение: по углам и у пола темнее — комната читается объёмом, а не плоской плиткой
static func _shade(kind: String, u: float, v: float) -> float:
	var edge := smoothstep(0.0, 0.17, minf(u, 1.0 - u))
	if kind == "wall":
		return (0.64 + 0.36 * edge) * lerpf(0.66, 1.0, smoothstep(0.0, 0.7, v))
	var e2 := smoothstep(0.0, 0.17, minf(minf(u, 1.0 - u), minf(v, 1.0 - v)))
	return 0.66 + 0.34 * e2


# ---------- проёмы моделей ----------

static func _wall_like(name: String) -> bool:
	if not (name.begins_with("SM_Bld_Wall_") or name.begins_with("SM_Bld_Base_Wall") or name == "SM_Bld_Door_Monument_01"):
		return false
	for w in ["Balcony", "Tiny", "_End", "Beam", "Cap", "Pillar", "Seat", "Collision", "Half", "Quarter"]:
		if name.contains(w):
			return false
	return true


## Проёмы модели стены: Rect2(x, y, ширина, высота) в осях модели — там, где в проекции на плоскость стены нет
## непрозрачной геометрии (решётки и стёкла, как и дверные проёмы, считаются проёмами). Замер один раз на модель
static func holes(name: String) -> Array:
	if _holes.has(name):
		return _holes[name]
	var res := []
	if _wall_like(name) and Synty.has(name):
		res = _measure(name)
	_holes[name] = res
	return res


static func _measure(name: String) -> Array:
	var box := Bp.model_aabb(name)
	if box.size.x < 1.2 or box.size.y < 1.4:
		return []
	const CELL := 0.05
	var nx := int(ceil(box.size.x / CELL))
	var ny := int(ceil(box.size.y / CELL))
	var cov := PackedByteArray()
	cov.resize(nx * ny)
	var src := Synty.make(name)
	for mi: MeshInstance3D in src.find_children("*", "MeshInstance3D", true, false):
		var xf := Citizen._rel(mi, src)
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s)
			if m is BaseMaterial3D and (m as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue                       # решётка окна, стекло — не стена
			var ar := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = ar[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = ar[Mesh.ARRAY_INDEX] if ar[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var nt := (idx.size() if idx.size() > 0 else vs.size()) / 3
			for t in nt:
				var ia := idx[t * 3] if idx.size() > 0 else t * 3
				var ib := idx[t * 3 + 1] if idx.size() > 0 else t * 3 + 1
				var ic := idx[t * 3 + 2] if idx.size() > 0 else t * 3 + 2
				var a: Vector3 = xf * vs[ia]
				var b: Vector3 = xf * vs[ib]
				var c: Vector3 = xf * vs[ic]
				var nz := absf((b - a).cross(c - a).normalized().z)
				if nz < 0.2:
					continue                   # грань вдоль стены (откос, подоконник) — в проекции линия
				_raster(cov, nx, ny, box, CELL, a, b, c)
	src.free()
	# связные незакрытые области
	var seen := PackedByteArray()
	seen.resize(nx * ny)
	var out := []
	for s in nx * ny:
		if cov[s] == 1 or seen[s] == 1:
			continue
		var stack := [s]
		seen[s] = 1
		var lo := Vector2i(nx, ny)
		var hi := Vector2i(-1, -1)
		var cnt := 0
		while not stack.is_empty():
			var p: int = stack.pop_back()
			var x := p % nx
			var y := p / nx
			cnt += 1
			lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
			hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var qx := x + d.x
				var qy := y + d.y
				if qx < 0 or qy < 0 or qx >= nx or qy >= ny:
					continue
				var q := qy * nx + qx
				if cov[q] == 0 and seen[q] == 0:
					seen[q] = 1
					stack.append(q)
		var w := (hi.x - lo.x + 1) * CELL
		var h := (hi.y - lo.y + 1) * CELL
		if lo.x == 0 or hi.x == nx - 1 or hi.y == ny - 1:
			continue                           # прилегает к краю модуля — не проём, а пустота рядом со стеной
		if w < MIN_HOLE or h < MIN_HOLE or cnt * CELL * CELL < 0.12:
			continue
		out.append(Rect2(box.position.x + lo.x * CELL, box.position.y + lo.y * CELL, w, h))
	return out


static func _raster(cov: PackedByteArray, nx: int, ny: int, box: AABB, cell: float, a: Vector3, b: Vector3, c: Vector3) -> void:
	var ax := (a.x - box.position.x) / cell
	var ay := (a.y - box.position.y) / cell
	var bx := (b.x - box.position.x) / cell
	var by := (b.y - box.position.y) / cell
	var cx := (c.x - box.position.x) / cell
	var cy := (c.y - box.position.y) / cell
	var x0 := maxi(0, int(floor(minf(ax, minf(bx, cx)))))
	var x1 := mini(nx - 1, int(ceil(maxf(ax, maxf(bx, cx)))))
	var y0 := maxi(0, int(floor(minf(ay, minf(by, cy)))))
	var y1 := mini(ny - 1, int(ceil(maxf(ay, maxf(by, cy)))))
	var den := (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
	if absf(den) < 1e-9:
		return
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var px := x + 0.5
			var py := y + 0.5
			var l1 := ((by - cy) * (px - cx) + (cx - bx) * (py - cy)) / den
			var l2 := ((cy - ay) * (px - cx) + (ax - cx) * (py - cy)) / den
			var l3 := 1.0 - l1 - l2
			if l1 >= 0.0 and l2 >= 0.0 and l3 >= 0.0:
				cov[y * nx + x] = 1


# ---------- проход по чертежу ----------

## Преобразовать нутро чертежа и поставить заднники за проёмами. Вызывать в Catalog.make перед масштабом
static func apply(b: Bp, kind: String) -> void:
	if kind == "decor":
		return
	_drop_balcony_rugs(b)
	var n0 := b.parts.size()
	var rooms := []            # обратные преобразования комнат — проверка «за проёмом уже есть комната»
	var plates := []
	for i in n0:
		var p: Array = b.parts[i]
		var nm: String = p[0]
		if nm != "#dark" and nm != "#lit":
			continue
		var xf: Transform3D = p[1]
		var sx := xf.basis.x.length()
		var sy := xf.basis.y.length()
		var sz := xf.basis.z.length()
		var lit := nm == "#lit"
		if sy >= 1.8 and maxf(sx, sz) >= 1.6 and minf(sx, sz) >= 0.45:      # и узкая полоса за задней стеной — тоже комната
			p[0] = "#room_lit" if lit else "#room"
			rooms.append(xf.affine_inverse())
			var nfl := int(round(sy / FL))
			for k in range(1, nfl):                    # перекрытия многоэтажной коробки
				var yl := -0.5 + (k * FL - 0.05) / sy
				b.parts.append(["#plate_lit" if lit else "#plate", xf * Transform3D(Basis.from_scale(Vector3(1.0, 0.12 / sy, 1.0)), Vector3(0, yl, 0)), {}])
		elif (minf(sx, sz) <= 0.12 and sy >= 0.25 and maxf(sx, sz) >= 0.25) or (sy >= 0.3 and minf(sx, minf(sy, sz)) > 0.12 and maxf(sx, sz) >= 1.2):
			# вертикальная пластина за решёткой окна или низкая тёмная коробка (передок помоста, прилавок): тёплая стена
			p[0] = "#plate_lit" if lit else "#plate"
			plates.append(xf.affine_inverse())
	# заднники за проёмами без комнаты
	var seq := 0
	for i in n0:
		var p: Array = b.parts[i]
		var nm: String = p[0]
		if not nm.begins_with("SM_Bld_"):
			continue
		var hs := holes(nm)
		if hs.is_empty():
			continue
		var xf: Transform3D = p[1]
		var box := Bp.model_aabb(nm)
		var zin := box.position.z
		for r: Rect2 in hs:
			var cxm := r.position.x + r.size.x * 0.5
			var cym := r.position.y + r.size.y * 0.5
			if _covered(xf * Vector3(cxm, cym, zin - 0.4), rooms, 0.05) or _covered(xf * Vector3(cxm, cym, zin - 0.04), plates, 0.45):
				continue
			var w := r.size.x + 2.0 * SIDE
			var hh := box.size.y - 0.1
			var d := DEPTH + 0.013 * float(seq % 5)
			seq += 1
			var lt := Transform3D(Basis.from_scale(Vector3(w, hh, d)), Vector3(cxm, 0.03 + hh * 0.5, zin - d * 0.5 + 0.02))
			b.parts.append(["#room", xf * lt, {}])
			if r.size.x >= 1.0 and r.position.y < 0.12 and r.size.y >= 1.8:
				_props(b, xf, cxm, r, zin - d + 0.04, seq)


## Точка в какой-то из коробок inv (обратные преобразования, коробка — единичный куб); запас margin — в долях куба
static func _covered(pt: Vector3, invs: Array, margin: float) -> bool:
	for inv: Transform3D in invs:
		var l: Vector3 = inv * pt
		var m := margin
		if absf(l.x) <= 0.5 + m and absf(l.y) <= 0.5 + m and absf(l.z) <= 0.5 + m:
			return true
	return false


## Пара вещей в заднике большого проёма (дверь, лавка): стеллаж у задней стены и горшки сбоку — комната обжита
static func _props(b: Bp, xf: Transform3D, cx: float, r: Rect2, z_back: float, seq: int) -> void:
	var shelf := "SM_Prop_Shelf_0%d" % (1 + seq % 2)
	if Synty.has(shelf):
		var sb := Bp.model_aabb(shelf)
		var s := 0.9
		b.parts.append([shelf, xf * Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3(cx - sb.get_center().x * s, 0.03, z_back - sb.position.z * s)), {}])
	var jar := "SM_Prop_Vase_Pile_0%d" % (1 + seq % 6)
	if Synty.has(jar):
		var side := -1.0 if seq % 2 == 0 else 1.0
		b.parts.append([jar, xf * Transform3D(Basis(Vector3.UP, 0.4 * seq).scaled(Vector3.ONE * 0.7), Vector3(cx + side * (r.size.x * 0.5 - 0.3), 0.03, z_back + 0.45)), {}])


## Ковры на перилах балконов (владелец 14.11: «согнут в Г») — убраны: драпировка висит на перилах углом. Ковёр у стены
## ниже этажа (лавка, вывеска) остаётся
static func _drop_balcony_rugs(b: Bp) -> void:
	if not b.free_parts.is_empty() or not b.kit_mov.is_empty():
		return
	var i := b.parts.size() - 1
	while i >= 0:
		var p: Array = b.parts[i]
		if (p[0] as String) == "SM_Prop_Rug_Drape_01":
			var y := (p[1] as Transform3D).origin.y
			if y >= FL - 0.1 and absf(fposmod(y, FL) - 1.0) < 0.35:
				b.parts.remove_at(i)
		i -= 1
