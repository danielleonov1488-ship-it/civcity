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
const SHALLOW := 0.6                    # заднник в аркаде трибун (одеон, театр): за аркой — верхний обход, глубже — ступени
const SIDE := 0.15                      # на сколько комната шире проёма с каждой стороны
const PROPS := false                    # стеллаж и горшки в заднике: на «Низкой» +0,8 мс видеокарты (замер 15.11) — выключены
const MIN_HOLE := 0.28                  # проём меньше — не считается (щели, отдушины)

const WALL := Color(0.80, 0.60, 0.42)
const FLOOR := Color(0.56, 0.40, 0.27)
const CEIL := Color(0.58, 0.45, 0.33)

static var _holes := {}                 # модель → [Rect2(x, y, w, h), …] в осях модели
## Картинки нутра (15.11, владелец: «во всех зданиях пустые комнаты — заставить, хотя бы для вида», картинки рисовал
## Codex): задняя стена комнаты — картинка по типу постройки (печь в пекарне, столы и амфоры в таверне…), остальное —
## как было. Картинку выбирает Game._show подменой «#room» → «#room~<картинка>»: чертёж не меняется. Один материал
## на картинку — комнаты одной картинки рисуются одной MultiMesh (по вызову отрисовки на картинку на весь город)
const IMAGES := {
	"taberna": "tavern", "thermopolium": "tavern", "mansio": "tavern", "wineshop": "tavern",
	"bakery": "bakery",
	"warehouse": "warehouse", "armory": "warehouse",
	"house_pleb": "home", "house_artisan": "home", "house_patrician": "home",
	"potter": "shop", "lamps": "shop", "perfumer": "shop", "jeweler": "shop", "catshop": "shop", "oilshop": "shop",
	"weaver": "textile", "cobbler": "textile", "dyer": "textile", "tailor": "textile", "fullonica": "textile",
	"herbalist": "infirmary", "medic": "infirmary", "infirmary": "infirmary", "barber": "shop",
	"butcher": "butcher", "stall_fruit": "produce", "stall_veg": "produce", "stall_fish": "produce", "ogorod": "produce",
	"temple": "temple", "venus": "temple", "pantheon": "temple", "mars": "temple",
	"school": "study", "library": "study", "scriptorium": "study", "academy": "study",
	"balnea": "baths", "baths": "baths", "thermae": "baths",
	"forge": "forge", "smelter": "forge", "ballistae": "forge", "catapults": "forge",
	"barracks": "barracks", "spearcamp": "barracks", "range": "barracks", "ludus": "barracks",
	"sawmill": "workshop", "tannery": "workshop", "sculptor": "workshop",
	"center": "office", "prefect": "office", "vigiles": "office", "forum": "office", "principia": "office",
	"theatre": "theatre", "odeon": "theatre", "puppets": "theatre", "mimes": "theatre", "musicians": "theatre",
	"shelter": "shelter",
}
static var _shader: Shader
static var _tex_mats := {}              # "картинка|lit" → ShaderMaterial
static var _tint := [Color(1, 1, 1), Color(1, 1, 1)]     # яркость комнат: [без жильцов, с жильцами]
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


## Картинка комнаты для типа постройки ("" — простая комната): только если файл картинки есть в игре
static func image_for(type: String) -> String:
	var img: String = IMAGES.get(type, "")
	if img != "" and not ResourceLoader.exists("res://assets/rooms/%s.jpg" % img):
		return ""
	return img


## Материал комнаты с картинкой на задней стене (шейдер — один на все картинки): картинка 3 × 3 м, пол у нижнего края
static func tex_material(img: String, lit: bool) -> ShaderMaterial:
	var key := "%s|%s" % [img, lit]
	if _tex_mats.has(key):
		return _tex_mats[key]
	if _shader == null:
		_shader = Shader.new()
		_shader.code = "shader_type spatial;\nrender_mode unshaded, cull_back;\n// Комната с картинкой на задней стене (interiors.gd): задняя стена (нормаль смотрит к проёму, +Z) — картинка\n// IMG_M x IMG_M м, пол у нижнего края, по ширине — от середины, дальше зеркально; выше IMG_M — повтор (этажи).\n// Остальные грани — тёплый цвет из вершин, как у простых комнат. Светится сама; яркость — tint (Interiors.set_light)\nuniform sampler2D img : source_color, filter_linear_mipmap, repeat_disable;\nuniform vec4 tint : source_color = vec4(1.0);\nvarying float back;\nvarying vec2 wuv;\nvec3 lin(vec3 c) {\n\treturn mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));\n}\nvoid vertex() {\n\tback = step(0.5, NORMAL.z);\n\tfloat sx = length(MODEL_MATRIX[0].xyz);\n\tfloat sy = length(MODEL_MATRIX[1].xyz);\n\twuv = vec2(VERTEX.x * sx / 3.0, (VERTEX.y + 0.5) * sy / 3.0);\n}\nvoid fragment() {\n\tvec3 c = lin(COLOR.rgb);\n\tfloat t = mod(wuv.x + 0.5, 2.0);\n\tvec2 uv = vec2(t <= 1.0 ? t : 2.0 - t, 1.0 - fract(wuv.y));\n\tvec3 pic = texture(img, uv).rgb * lin(vec3(COLOR.r / 0.80));\n\tALBEDO = mix(c, pic, back) * tint.rgb;\n}\n"
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("img", load("res://assets/rooms/%s.jpg" % img))
	m.set_shader_parameter("tint", _tint[1 if lit else 0])
	_tex_mats[key] = m
	return m


## Яркость комнат: lamp — 0 днём, 1 ночью (как у окон «#lit» в Game._sky); deep — глубокая ночь
static func set_light(lamp: float, deep: bool) -> void:
	_tint[0] = Color(1, 1, 1).lerp(Color(0.17, 0.13, 0.095), lamp)    # 15.11: ночью приглушённо, не чёрная дыра
	_tint[1] = Color(1, 1, 1).lerp(Color(0.2, 0.135, 0.075) if deep else Color(0.34, 0.23, 0.12), lamp)
	material(false).albedo_color = _tint[0]
	material(true).albedo_color = _tint[1]
	for key: String in _tex_mats:
		(_tex_mats[key] as ShaderMaterial).set_shader_parameter("tint", _tint[1 if key.ends_with("true") else 0])


## Меш «#room», «#room_lit» (внутрь), «#plate», «#plate_lit» (наружу): единичная коробка вокруг начала координат
static func mesh(name: String) -> Mesh:
	if _meshes.has(name):
		return _meshes[name]
	var img := name.get_slice("~", 1) if name.contains("~") else ""     # «#room~tavern» — с картинкой на задней стене
	var base := name.get_slice("~", 0)
	var lit := base.ends_with("_lit")
	var inward := base.begins_with("#room")
	var st := {"v": [], "n": [], "c": []}
	var us := [0.0, 0.15, 0.85, 1.0]
	var vs := [0.0, 0.35, 1.0]
	if base.begins_with("#room1"):                  # лёгкая: по одному четырёхугольнику на грань (Низкая и Очень низкая)
		us = [0.0, 1.0]
		vs = [0.0, 1.0]
	elif base.begins_with("#plate"):
		us = [0.0, 1.0]
		vs = [0.0, 1.0]
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
	am.surface_set_material(0, tex_material(img, lit) if img != "" else material(lit))
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
	_clear_signs(b)
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
		elif sy <= 0.12 and minf(sx, sz) >= 0.6:
			p[0] = "#plate_lit" if lit else "#plate"     # плоская тёмная коробка — пол открытой лавки (таверна): тёплый пол
		elif (minf(sx, sz) <= 0.06 and sy >= 0.25 and maxf(sx, sz) >= 0.25) or (sy >= 0.3 and minf(sx, minf(sy, sz)) > 0.12 and maxf(sx, sz) >= 1.2):
			# вертикальная пластина за решёткой окна или низкая тёмная коробка (передок помоста, прилавок): тёплая стена
			p[0] = "#plate_lit" if lit else "#plate"
			plates.append(xf.affine_inverse())
	# стены здания — «за проёмом должна быть стена»: иначе модуль смотрит внутрь двора (боковые портики форума,
	# академии), и заднник торчал бы наружу плоским ящиком
	var walls := []
	var cen := Vector3.ZERO
	for i in n0:
		var wn: String = b.parts[i][0]
		if wn.begins_with("SM_Bld_Wall") or wn.begins_with("SM_Bld_Base_Wall") or wn == "#room" or wn == "#room_lit":
			var wbox: AABB = (b.parts[i][1] as Transform3D) * (Bp.model_aabb(wn) if not wn.begins_with("#") else AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE))
			walls.append(wbox)
			cen += wbox.get_center()
	if not walls.is_empty():
		cen /= float(walls.size())
	cen.y = 0.0
	# трибуны (амфитеатр): за аркой аркады сразу ступени — заднник там мелкий, иначе торчит из рядов и занимает места
	var stands := []
	for i in n0:
		var an: String = b.parts[i][0]
		if an.begins_with("SM_Bld_Amphitheatre"):
			stands.append((b.parts[i][1] as Transform3D) * Bp.model_aabb(an))
	# заднники за проёмами без комнаты
	var seq := 0
	for i in n0:
		var p: Array = b.parts[i]
		var nm: String = p[0]
		if not nm.begins_with("SM_Bld_") or b.free_parts.has(i):
			continue                               # арки, под которыми ходят (акведук), — сквозные: за ними улица, не комната
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
			# «за проёмом» — в сторону середины здания: модуль смотрит во двор (боковые портики форума, академии) —
			# его «за» ушло бы наружу плоским ящиком
			var pw: Vector3 = xf * Vector3(cxm, 0.0, 0.0)
			var behind := (xf.basis * Vector3(0, 0, -1)).normalized()
			if behind.dot((cen - pw).normalized()) < -0.2 and (cen - pw).length() > 1.5:
				continue
			var w := r.size.x + 2.0 * SIDE
			var hh := box.size.y - 0.1
			var d := DEPTH + 0.013 * float(seq % 5)
			var deep_pt: Vector3 = xf * Vector3(cxm, cym, zin - DEPTH * 0.5)
			for st: AABB in stands:
				if st.has_point(deep_pt):
					d = SHALLOW + 0.013 * float(seq % 5)
					break
			seq += 1
			var lt := Transform3D(Basis.from_scale(Vector3(w, hh, d)), Vector3(cxm, 0.03 + hh * 0.5, zin - d * 0.5 + 0.02))
			b.free_parts[b.parts.size()] = true             # заднник земли не занимает (след — по стенам, не по нутру)
			b.parts.append(["#room", xf * lt, {}])
			if PROPS and r.size.x >= 1.0 and r.position.y < 0.12 and r.size.y >= 1.8:
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
		b.free_parts[b.parts.size()] = true
		b.parts.append([shelf, xf * Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3(cx - sb.get_center().x * s, 0.03, z_back - sb.position.z * s)), {}])
	var jar := "SM_Prop_Vase_Pile_0%d" % (1 + seq % 6)
	if Synty.has(jar):
		var side := -1.0 if seq % 2 == 0 else 1.0
		b.free_parts[b.parts.size()] = true
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


## Вывески над дверью («#sign:…») — на поверхности стены, чуть впереди неё, а не в стене или карнизе (владелец 14.11:
## «вывеска врезана в стену»): спинка вывески выдвигается вперёд до самой выступающей детали здания под ней
static func _clear_signs(b: Bp) -> void:
	var boxes := []
	for p in b.parts:
		var nm: String = p[0]
		if nm.begins_with("SM_Bld_Wall") or nm.begins_with("SM_Bld_Trim") or nm.begins_with("SM_Bld_Door") or nm.begins_with("SM_Bld_Pillar") or nm.begins_with("SM_Bld_Floor_Trim"):
			boxes.append((p[1] as Transform3D) * Bp.model_aabb(nm))
	for p in b.parts:
		var nm: String = p[0]
		if not nm.begins_with("#sign:"):
			continue
		var m := CatDress.kit_mesh(nm)
		if m == null:
			continue
		var xf: Transform3D = p[1]
		var f := xf.basis.z.normalized()
		if absf(f.y) > 0.3:
			continue
		var sb: AABB = xf * m.get_aabb()
		var back := INF
		for i in 8:
			back = minf(back, f.dot(xf * m.get_aabb().get_endpoint(i)))
		var need := back
		for bx: AABB in boxes:
			# совпадает ли по ширине и высоте (вдоль стены и вверх): ось вдоль f — глубина
			var ax := 0 if absf(f.x) > absf(f.z) else 2
			var lat := 2 if ax == 0 else 0
			var ov_l := minf(sb.end[lat], bx.end[lat]) - maxf(sb.position[lat], bx.position[lat])
			var ov_y := minf(sb.end.y, bx.end.y) - maxf(sb.position.y, bx.position.y)
			if ov_l <= 0.02 or ov_y <= 0.02:
				continue
			var fr := -INF
			for i in 8:
				fr = maxf(fr, f.dot(bx.get_endpoint(i)))
			if fr - back < 0.5:
				need = maxf(need, fr)
		var push := clampf(need + 0.03 - back, 0.0, 0.4)
		if push > 0.001:
			xf.origin += f * push
			p[1] = xf
