class_name Artisau
extends RefCounted
## Модели из набора Artisau (CC0): статуи, храмы, акведук, колодцы, амфоры. Все красятся одной
## палитрой 16×16 — подменяем материал на свой (палитра без сглаживания, как задумано автором).
## Размер приводим к нужной высоте в метрах.

static var _mat: StandardMaterial3D
static var _cache := {}


static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.albedo_texture = load("res://assets/artisau/TexturaLowPoly.png")
		_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_mat.roughness = 0.85
	return _mat


## Модель name высотой height метров (0 — как есть). Возвращает узел, стоящий основанием на нуле
static func make(name: String, height := 0.0) -> Node3D:
	if not _cache.has(name):
		_cache[name] = load("res://assets/artisau/" + name.replace(" ", "_").replace(".", "_") + ".fbx")
	var ps: PackedScene = _cache[name]
	var root := Node3D.new()
	var n := ps.instantiate() as Node3D
	root.add_child(n)
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = material()
	var box := aabb(n)
	if height > 0.0 and box.size.y > 0.0:
		var s := height / box.size.y
		n.scale *= s
		box = aabb(n)
	n.position.y -= box.position.y
	n.position.x -= box.position.x + box.size.x * 0.5
	n.position.z -= box.position.z + box.size.z * 0.5
	return root


## Габариты модели в координатах её корня
static func aabb(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var xf := Citizen._rel(mi, n.get_parent()) if n.get_parent() else mi.transform
		var b := xf * mi.mesh.get_aabb()
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	return box
