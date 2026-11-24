extends "res://scripts/parts_detail.gd"

var exact_shadow_keys := {}
var exact_shadows := 0
var _exact_meshes := {}
var _shadow_meshes := {}


func uses_area(_name: String, key: String) -> bool:
	return tile_m > 0.0 and area_keys.has(key)


func add_shadow(_pool: Node3D, _group: Dictionary, sub: Dictionary, name: String, source: Mesh) -> void:
	var mmi: MultiMeshInstance3D = sub["mmi"]
	if mmi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON and exact_shadow_keys.has(name):
		var mm: MultiMesh = sub["mm"]
		mm.mesh = _exact_shadow(source, mm.mesh)


static func _opaque_area(g: Dictionary) -> bool:
	for sub: Dictionary in g["subs"]:
		var mesh := (sub["mm"] as MultiMesh).mesh as ArrayMesh
		if mesh == null or not _opaque(mesh):
			return false
		for surface: Dictionary in mesh.get("_surfaces"):
			if not surface.get("lods", []).is_empty():
				return false
	return not g["subs"].is_empty()


static func _opaque(mesh: ArrayMesh) -> bool:
	if mesh.get_blend_shape_count() != 0:
		return false
	for s in mesh.get_surface_count():
		var mat := mesh.surface_get_material(s) as StandardMaterial3D
		if mat == null or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
				or mat.cull_mode != BaseMaterial3D.CULL_BACK or mat.next_pass != null \
				or mat.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED \
				or mat.grow or mat.proximity_fade_enabled or mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			return false
	return mesh.get_surface_count() > 0


func _exact_shadow(source: Mesh, visible_mesh: Mesh) -> Mesh:
	if not source is ArrayMesh or not visible_mesh is ArrayMesh:
		return visible_mesh
	var id := visible_mesh.get_instance_id()
	if not _exact_meshes.has(id):
		var mesh := visible_mesh as ArrayMesh
		var shadow: ArrayMesh
		if _opaque(mesh):
			var source_id := source.get_instance_id()
			if not _shadow_meshes.has(source_id):
				_shadow_meshes[source_id] = _weld_shadow(source as ArrayMesh)
			shadow = _shadow_meshes[source_id]
		var copy := mesh
		if shadow != null:
			copy = mesh.duplicate() as ArrayMesh
			copy.shadow_mesh = shadow
			exact_shadows += 1
		_exact_meshes[id] = [visible_mesh, copy]
	return _exact_meshes[id][1]


static func _weld_shadow(source: ArrayMesh) -> ArrayMesh:
	# Если импортёр уже создал сетку тени, сохраняем её координаты и уровни детализации.
	var original := source.shadow_mesh if source.shadow_mesh != null else source
	var importer := ImporterMesh.from_mesh(original)
	var shadow := ArrayMesh.new()
	var cheaper := source.shadow_mesh == null
	for s in original.get_surface_count():
		var src := original.surface_get_arrays(s)
		var vertices: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
		var positions := PackedVector3Array()
		var lookup := {}
		var remap := PackedInt32Array()
		remap.resize(vertices.size())
		for i in vertices.size():
			var pos := vertices[i]
			if not lookup.has(pos):
				lookup[pos] = positions.size()
				positions.append(pos)
			remap[i] = lookup[pos]
		var indices: PackedInt32Array = src[Mesh.ARRAY_INDEX] if src[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			indices.resize(vertices.size())
			for i in vertices.size():
				indices[i] = i
		var base := _weld_indices(indices, remap)
		if base.is_empty():
			return null
		cheaper = cheaper or positions.size() < vertices.size() or base.size() < indices.size()
		var levels := {}
		for level in importer.get_surface_lod_count(s):
			var lod := importer.get_surface_lod_indices(s, level)
			var welded := _weld_indices(lod, remap)
			if welded.is_empty():
				return null
			cheaper = cheaper or welded.size() < lod.size()
			levels[importer.get_surface_lod_size(s, level)] = welded
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = positions
		arrays[Mesh.ARRAY_INDEX] = base
		shadow.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], levels)
	return shadow if cheaper else null


static func _weld_indices(indices: PackedInt32Array, remap: PackedInt32Array) -> PackedInt32Array:
	var output := PackedInt32Array()
	var seen := {}
	for i in range(0, indices.size(), 3):
		var a := remap[indices[i]]
		var b := remap[indices[i + 1]]
		var c := remap[indices[i + 2]]
		if a == b or b == c or c == a:
			continue
		# Порядок обхода важен для отсечения обратных граней.
		var face := Vector3i(a, b, c)
		if b < a and b < c:
			face = Vector3i(b, c, a)
		elif c < a and c < b:
			face = Vector3i(c, a, b)
		if not seen.has(face):
			seen[face] = true
			output.append(a)
			output.append(b)
			output.append(c)
	return output
