class_name Fauna
extends RefCounted
## Утки, лебедь, овцы (этап 4, по просьбе владельца — «модели получше»): бесплатные модели в духе Synty
## (assets/fauna, лицензии — LICENSE.txt рядом; файлы не менялись), переделанные под игру при загрузке:
##  - утка и лебедь — одна сетка с цветом в вершинах (пул деталей Parts: все птицы города рисуются одним MultiMesh),
##    лапы под водой срезаны, начало координат — на воде, клюв — к +Z; у уточки (самки кряквы) свой пёстрый окрас,
##    у лебедя клюв оранжевый;
##  - овца — модель Quaternius (CC0) со скелетом: «пасётся» собрано из её «Idle» (голова к траве, жуёт, поднимает голову).
## Файла нет (не должно быть: папка — в пакете с кодом) — прежние птицы из Kit и прежние овцы.

const DUCK := "res://assets/fauna/Duck.glb"
const SWAN := "res://assets/fauna/Swan.glb"
const SHEEP := "res://assets/fauna/Sheep.glb"
const DUCK_LEN := 0.42
const SWAN_LEN := 0.8
const WATER := {"duck": 0.29, "duck_f": 0.29, "swan": 0.2}   # водная линия — доля высоты птицы от низа (лапы)
## Уточка: материал селезня (имя — его цвет) → пёстро-бурые перья, клюв оранжевый
const HEN := {"455A64": "5b4430", "4CAF50": "86663f", "FFFFFF": "86663f", "795548": "785637", "78909C": "9a7550", "FFEB3B": "d98b2b"}

static var _birds := {}
static var _sheep: PackedScene
static var _sheep_lib: AnimationLibrary


## Сетка птицы: kind — duck, duck_f (уточка), swan; null — модели нет
static func bird_mesh(kind: String) -> Mesh:
	if _birds.has(kind):
		return _birds[kind]
	var path := SWAN if kind == "swan" else DUCK
	var m: Mesh = null
	if ResourceLoader.exists(path):
		var ps := load(path) as PackedScene
		if ps:
			var n := ps.instantiate() as Node3D
			m = _bake(n, kind)
			n.free()
	_birds[kind] = m
	return m


## Все сетки модели — в одну: цвет материала (и его картинки) — в вершины, поворот клювом к +Z, размер, вода
static func _bake(n: Node3D, kind: String) -> Mesh:
	var V := PackedVector3Array()
	var Nn := PackedVector3Array()
	var C := PackedColorArray()
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var xf := Citizen._rel(mi, n)
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var mat := mi.mesh.surface_get_material(s)
			var base := Color.WHITE
			var img: Image = null
			var mname := ""
			if mat is BaseMaterial3D:
				base = (mat as BaseMaterial3D).albedo_color
				mname = mat.resource_name
				var tex := (mat as BaseMaterial3D).albedo_texture
				if tex:
					img = tex.get_image()
					if img and img.is_compressed():
						img.decompress()
			if kind == "duck_f" and HEN.has(mname):
				base = Color(HEN[mname])
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var uv = arr[Mesh.ARRAY_TEX_UV]
			var ix = arr[Mesh.ARRAY_INDEX]
			var order: PackedInt32Array = ix if ix != null else PackedInt32Array(range(v.size()))
			for k in order:
				V.append(xf * v[k])
				Nn.append((xf.basis * nr[k]).normalized())
				var c := base
				if img and uv != null:
					var q: Vector2 = (uv as PackedVector2Array)[k]
					c = base * img.get_pixel(clampi(int(fposmod(q.x, 1.0) * img.get_width()), 0, img.get_width() - 1), clampi(int(fposmod(q.y, 1.0) * img.get_height()), 0, img.get_height() - 1))
				C.append(c)
	if V.is_empty():
		return null
	# куда смотрит: голова — самые высокие точки, от середины к ним (по земле) — вперёд
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for p in V:
		lo = lo.min(p)
		hi = hi.max(p)
	var top := Vector3.ZERO
	var nt := 0
	for p in V:
		if p.y > hi.y - (hi.y - lo.y) * 0.12:
			top += p
			nt += 1
	top /= maxf(1, nt)
	var mid := (lo + hi) * 0.5
	var fw := Vector2(top.x - mid.x, top.z - mid.z)
	if fw.length() < 1e-5:
		fw = Vector2(0, 1)
	var yaw := atan2(fw.x, fw.y)
	var rot := Basis(Vector3.UP, -yaw)
	var lo2 := Vector3(INF, INF, INF)
	var hi2 := -lo2
	for i in V.size():
		V[i] = rot * (V[i] - Vector3(mid.x, lo.y, mid.z))
		Nn[i] = rot * Nn[i]
		lo2 = lo2.min(V[i])
		hi2 = hi2.max(V[i])
	var s := (SWAN_LEN if kind == "swan" else DUCK_LEN) / maxf(0.001, hi2.z - lo2.z)
	var H := hi2.y - lo2.y
	var wl := H * float(WATER.get(kind, 0.3))
	if kind == "swan":
		# шея лебедя — изгибом назад («S»), голова остаётся над грудью
		for i in V.size():
			var u := clampf((V[i].y - H * 0.45) / (H * 0.55), 0.0, 1.0)
			V[i].z -= (hi2.z - lo2.z) * 0.13 * sin(u * PI) * smoothstep(0.0, 0.25, u)
	# низ под водой — по воду (сквозь воду не просвечивает), лапы и всё, что целиком под водой, — прочь
	var out := Kit.new()
	var floor_y := 0.006 / s
	for t in range(0, V.size(), 3):
		var a := V[t] - Vector3(0, wl, 0)
		var b := V[t + 1] - Vector3(0, wl, 0)
		var c := V[t + 2] - Vector3(0, wl, 0)
		if maxf(a.y, maxf(b.y, c.y)) < floor_y:
			continue
		a.y = maxf(a.y, floor_y)
		b.y = maxf(b.y, floor_y)
		c.y = maxf(c.y, floor_y)
		var col := C[t]
		# лебедь: жёлтый клюв — оранжевый, как у лебедя-шипуна
		if kind == "swan" and col.r > 0.7 and col.g > 0.5 and col.b < 0.45:
			col = Color("e0782a")
		out.verts.append_array([a * s, b * s, c * s])
		out.norms.append_array([Nn[t], Nn[t + 1], Nn[t + 2]])
		out.cols.append_array([col, C[t + 1] if kind != "swan" else col, C[t + 2] if kind != "swan" else col])
	var am := out.mesh()
	am.surface_set_material(0, Kit.material(0.65))
	return am


# ---------- овцы ----------

## Сцена овцы: новая модель (или прежняя, если файла нет)
static func sheep_scene() -> PackedScene:
	if _sheep == null:
		_sheep = load(SHEEP) as PackedScene if ResourceLoader.exists(SHEEP) else load("res://assets/animals/Sheep_a.glb") as PackedScene
	return _sheep


## Дать овце движение «Graze» (голова у травы, жуёт, изредка поднимает голову и оглядывается); у прежней модели — её
## «Eating». Возвращает [AnimationPlayer (null — движений нет), имя движения «пасётся»]
static func sheep_anim(sh: Node3D) -> Array:
	var aps := sh.find_children("*", "AnimationPlayer", true, false)
	if aps.is_empty():
		return [null, ""]
	var ap: AnimationPlayer = aps[0]
	var idle := LegionFighter._find(ap, ["Idle"])
	var sks := sh.find_children("*", "Skeleton3D", true, false)
	if idle == "" or sks.is_empty() or (sks[0] as Skeleton3D).find_bone("Neck") < 0:
		for a in ap.get_animation_list():
			if String(a).ends_with("Eating"):
				ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
				return [ap, a]
		return [ap, ""]
	if _sheep_lib == null:
		var sk: Skeleton3D = sks[0]
		var src := ap.get_animation(idle)
		var L := src.length * 2.0
		_sheep_lib = AnimationLibrary.new()
		# в осях скелета модели: вперёд — −y, вбок — x, вверх — z; поворот вокруг x наклоняет голову к земле.
		# Круг ~12 с: голова у травы, жуёт; на пару секунд поднимает голову и оглядывается
		var down := func(t: float) -> float: return 1.0 - Citizen._bump(t, L * 0.6, L * 0.92)
		var graze := {
			"Neck": func(t: float) -> Vector3: return Vector3(0.95 * down.call(t) - 0.08, 0, 0),
			"Head": func(t: float) -> Vector3: return Vector3((0.35 + 0.09 * sin(TAU * t * 2.2)) * down.call(t), 0, 0.4 * (1.0 - down.call(t)) * sin(TAU * t / 2.6))}
		_sheep_lib.add_animation("Graze", People._cat_pose(src, 2, sk, graze, Vector3.ZERO))
	if not ap.has_animation_library("fauna"):
		ap.add_animation_library("fauna", _sheep_lib)
	return [ap, "fauna/Graze"]
