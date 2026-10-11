class_name Parts
extends Node3D
## Пул деталей: все одинаковые детали Synty (одной раскраски) по всему городу рисуются одним MultiMesh.
## place(чертёж, где) возвращает ручку; remove(ручка) убирает детали этой постройки.
## Свободные места переиспользуются, буфер растёт удвоением.

var groups := {}          # ключ → {subs: [{mm, mmi, local}], free: [], used: int, cap: int}
static var _special := {}


func _group(name: String, remap: Dictionary) -> Dictionary:
	var key := name + "|" + str(remap)
	if groups.has(key):
		return groups[key]
	var g := {"subs": [], "free": [], "used": 0, "cap": 0, "key": key}
	if name.begins_with("#"):
		g["subs"].append(_sub(_special_mesh(name), Transform3D.IDENTITY))
	else:
		var src := Synty.make(name, remap)
		for mi: MeshInstance3D in src.find_children("*", "MeshInstance3D", true, false):
			var mesh := mi.mesh.duplicate() as Mesh
			for s in mesh.get_surface_count():
				var m := mi.get_surface_override_material(s)
				if m:
					mesh.surface_set_material(s, m)
			g["subs"].append(_sub(mesh, Citizen._rel(mi, src)))
		src.free()
	groups[key] = g
	return g


func _sub(mesh: Mesh, local: Transform3D) -> Dictionary:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	return {"mm": mm, "mmi": mmi, "local": local}


static func _special_mesh(name: String) -> Mesh:
	if _special.has(name):
		return _special[name]
	var bm := BoxMesh.new()
	var m := StandardMaterial3D.new()
	match name:
		"#dark":
			m.albedo_color = Color("2a2019")
			m.roughness = 1.0
		"#marble":
			m = Synty.material("Marble_01").duplicate()
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(0.4, 0.4, 0.4)
		"#water":
			m.albedo_color = Color(0.32, 0.72, 0.74, 0.85)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.08
			m.metallic_specular = 0.7
		_:
			m.albedo_color = Color.MAGENTA
	bm.material = m
	_special[name] = bm
	return bm


func _grow(g: Dictionary) -> void:
	var cap: int = maxi(16, int(g["cap"]) * 2)
	for sub in g["subs"]:
		var mm: MultiMesh = sub["mm"]
		var old := mm.buffer
		mm.instance_count = cap
		var buf := mm.buffer
		for i in old.size():
			buf[i] = old[i]
		# новые места — пустые (нулевой масштаб)
		for i in range(old.size(), buf.size()):
			buf[i] = 0.0
		mm.buffer = buf
	g["cap"] = cap


func _alloc(g: Dictionary) -> int:
	var free: Array = g["free"]
	if not free.is_empty():
		return free.pop_back()
	if int(g["used"]) >= int(g["cap"]):
		_grow(g)
	var i: int = g["used"]
	g["used"] = i + 1
	for sub in g["subs"]:
		(sub["mm"] as MultiMesh).visible_instance_count = i + 1
	return i


## Поставить чертёж; xf — где стоит постройка. Возвращает ручку [[группа, место], …]
func place(bp: Bp, xf: Transform3D) -> Array:
	var handles := []
	for p in bp.parts:
		var g := _group(p[0], p[2])
		var slot := _alloc(g)
		var t: Transform3D = xf * (p[1] as Transform3D)
		for sub in g["subs"]:
			(sub["mm"] as MultiMesh).set_instance_transform(slot, t * (sub["local"] as Transform3D))
		handles.append([g, slot])
	return handles


func place_one(name: String, xf: Transform3D, remap := {}) -> Array:
	var g := _group(name, remap)
	var slot := _alloc(g)
	for sub in g["subs"]:
		(sub["mm"] as MultiMesh).set_instance_transform(slot, xf * (sub["local"] as Transform3D))
	return [[g, slot]]


func remove(handles: Array) -> void:
	var zero := Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3(0, -100, 0))
	for h in handles:
		var g: Dictionary = h[0]
		var slot: int = h[1]
		for sub in g["subs"]:
			(sub["mm"] as MultiMesh).set_instance_transform(slot, zero)
		(g["free"] as Array).append(slot)


func count() -> int:
	var n := 0
	for k in groups:
		n += int(groups[k]["used"]) - (groups[k]["free"] as Array).size()
	return n


## Призрак постройки: обычные узлы, полупрозрачные (для предпросмотра при установке)
static func ghost(bp: Bp) -> Node3D:
	var root := Node3D.new()
	for p in bp.parts:
		var n: Node3D
		if (p[0] as String).begins_with("#"):
			var mi := MeshInstance3D.new()
			mi.mesh = _special_mesh(p[0])
			n = mi
		else:
			n = Synty.make(p[0], p[2])
		n.transform = p[1]
		root.add_child(n)
	for mi: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
		mi.transparency = 0.35
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root
