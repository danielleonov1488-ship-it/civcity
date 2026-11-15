extends RefCounted
## Статические детали главного Parts. Подсветка этот помощник не создаёт.

const BATCH_TILE := 64.0
const MERGE_MAX := 3
const TILES_PER_FRAME := 2
const MAX_VERTS := 4000
const MAX_LOD_VERTS := 3000
const MEMORY_LIMIT := 140 * 1048576
const ZERO := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3(0, -100, 0))

var pool
var tiles: Dictionary = {}
var dirty: Dictionary = {}
var started := false
var serial := 0
var bytes := 0


func _init(owner_pool) -> void:
	pool = owner_pool


## Цена одной копии: массивы CPU + GPU, с запасом на цвет и индексы.
func _cost(g: Dictionary) -> int:
	g["batch_normal_map"] = false
	var name: String = String(g["key"]).get_slice("|", 0)
	# Meadow меняет и сетки, и видимость по качеству; его материалы могут двигать вершины.
	if name.begins_with("#") or name.begins_with("M:") or name.begins_with("K:common/") or name.contains("@lit"):
		return 0
	if name.begins_with("SM_Bld_Door_") or (name == "SM_Bld_Wall_01" and String(g["key"]).contains("Wood_02")):
		return 0                             # Life и KitShutters пишут прямо в MultiMesh
	if name.contains("Grass") or name.contains("Flowers") or name.contains("Lillies") or name.contains("Pebbles") or name.contains("Garden_Plants") or Meadow.small(name):
		return 0
	var cost := 0
	for sub: Dictionary in g["subs"]:
		var mi: MultiMeshInstance3D = sub["mmi"]
		var mesh: Mesh = (sub["mm"] as MultiMesh).mesh
		if not mesh is ArrayMesh or mi.material_override != null or mi.material_overlay != null or mi.visibility_range_begin != 0.0 or mi.visibility_range_end != 0.0:
			return 0
		var am := mesh as ArrayMesh
		if am.get_blend_shape_count() > 0:
			return 0
		var verts := 0
		var lod := false
		for s in am.get_surface_count():
			var m := am.surface_get_material(s) as StandardMaterial3D
			if m == null or m.next_pass != null or m.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or m.grow or m.use_particle_trails:
				return 0
			if m.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED or m.proximity_fade_enabled or m.uv1_triplanar or m.uv2_triplanar:
				return 0
			if m.transparency not in [BaseMaterial3D.TRANSPARENCY_DISABLED, BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR] or m.heightmap_enabled or m.detail_enabled or m.anisotropy_enabled or m.ao_on_uv2 or m.emission_on_uv2:
				return 0
			if am.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				return 0
			var fmt := am.surface_get_format(s)
			if fmt & (Mesh.ARRAY_FORMAT_BONES | Mesh.ARRAY_FORMAT_WEIGHTS | Mesh.ARRAY_FORMAT_CUSTOM0 | Mesh.ARRAY_FORMAT_CUSTOM1 | Mesh.ARRAY_FORMAT_CUSTOM2 | Mesh.ARRAY_FORMAT_CUSTOM3):
				return 0
			var a := am.surface_get_arrays(s)
			g["batch_normal_map"] = bool(g["batch_normal_map"]) or m.normal_enabled
			var n := am.surface_get_array_len(s)
			if n == 0 or a[Mesh.ARRAY_NORMAL] == null or (m.normal_enabled and a[Mesh.ARRAY_TANGENT] == null):
				return 0
			if (a[Mesh.ARRAY_NORMAL] as PackedVector3Array).size() != n or (m.normal_enabled and (a[Mesh.ARRAY_TANGENT] as PackedFloat32Array).size() != n * 4):
				return 0
			verts += n
			lod = lod or not (RenderingServer.mesh_get_surface(am.get_rid(), s).get("lods", []) as Array).is_empty()
			var indices := maxi(n, am.surface_get_array_index_len(s))
			cost += 2 * (n * (64 if m.normal_enabled else 48) + indices * 4)
		if verts > MAX_VERTS or (lod and verts > MAX_LOD_VERTS):
			return 0
	return cost


func track(g: Dictionary, slot: int, xf: Transform3D, col: Color) -> void:
	if not g.has("batch_cost"):
		g["batch_cost"] = _cost(g)
	if int(g["batch_cost"]) == 0:
		if g.has("batch_slots"):
			_sync_visibility(g)
		return
	if not _can_bake(g, xf):
		_sync_visibility(g)
		return
	if not g.has("batch_slots"):
		g["batch_slots"] = {}
	serial += 1
	var r := {"xf": xf, "col": col, "tile": _tile(xf), "gen": serial, "hidden": false, "merged": false, "safe": true}
	g["batch_slots"][slot] = r
	_link(g, slot, r["tile"])
	_sync_visibility(g)


func _tile(xf: Transform3D) -> Vector2i:
	return Vector2i(floori(xf.origin.x / BATCH_TILE), floori(xf.origin.z / BATCH_TILE))


func _can_bake(g: Dictionary, xf: Transform3D) -> bool:
	for sub: Dictionary in g["subs"]:
		var t: Transform3D = xf * (sub["local"] as Transform3D)
		if t.basis.determinant() <= 0.000001:
			return false
		if g.get("batch_normal_map", false):
			# У растянутой сетки Godot MultiMesh даёт неортогональный TBN.
			# ArrayMesh его не хранит: такие детали оставляем в MultiMesh.
			var b := t.basis
			var size := Vector3(b.x.length(), b.y.length(), b.z.length())
			if not is_equal_approx(size.x, size.y) or not is_equal_approx(size.x, size.z):
				return false
			if absf(b.x.normalized().dot(b.y.normalized())) > 0.00001 or absf(b.x.normalized().dot(b.z.normalized())) > 0.00001 or absf(b.y.normalized().dot(b.z.normalized())) > 0.00001:
				return false
	return true


func _link(g: Dictionary, slot: int, tile: Vector2i) -> void:
	if not tiles.has(tile):
		tiles[tile] = {"groups": {}, "nodes": [], "members": [], "bytes": 0, "verts": 0}
	var gs: Dictionary = tiles[tile]["groups"]
	if not gs.has(g["key"]):
		gs[g["key"]] = {}
	gs[g["key"]][slot] = true
	dirty[tile] = true


func record(g: Dictionary, slot: int) -> Dictionary:
	return (g.get("batch_slots", {}) as Dictionary).get(slot, {})


func remove_slot(g: Dictionary, slot: int) -> void:
	var r := record(g, slot)
	if r.is_empty():
		return
	_unlink(g, slot, r["tile"])
	(g["batch_slots"] as Dictionary).erase(slot)


func _unlink(g: Dictionary, slot: int, tile: Vector2i) -> void:
	var gs: Dictionary = tiles[tile]["groups"]
	(gs[g["key"]] as Dictionary).erase(slot)
	# Группу сохраняем до rebuild: её MultiMesh тоже нужно пересчитать после удаления.
	dirty[tile] = true


func set_hidden(g: Dictionary, slot: int, hidden: bool, xf: Transform3D) -> bool:
	var r := record(g, slot)
	if r.is_empty():
		return false
	if not hidden:
		var tile := _tile(xf)
		if tile != r["tile"]:
			_unlink(g, slot, r["tile"])
			r["tile"] = tile
			_link(g, slot, tile)
		r["xf"] = xf
		r["safe"] = _can_bake(g, xf)
	r["hidden"] = hidden
	dirty[r["tile"]] = true
	_write(g, slot, r)
	return true


func _write(g: Dictionary, slot: int, r: Dictionary) -> void:
	for sub: Dictionary in g["subs"]:
		var mm: MultiMesh = sub["mm"]
		mm.set_instance_transform(slot, ZERO if r["hidden"] or r["merged"] else (r["xf"] as Transform3D) * (sub["local"] as Transform3D))


func _sync_visibility(g: Dictionary) -> void:
	var drawn: int = int(g["used"]) - (g["free"] as Array).size()
	for r: Dictionary in (g.get("batch_slots", {}) as Dictionary).values():
		if r["hidden"] or r["merged"]:
			drawn -= 1
	for sub: Dictionary in g["subs"]:
		(sub["mmi"] as MultiMeshInstance3D).visible = drawn > 0 and bool(g.get("batch_visible", true))


func build_all() -> void:
	if started:
		return
	started = true
	for tile: Vector2i in dirty.keys():
		_rebuild(tile)
	var s := stats()
	print("PARTS BATCH tiles=%d meshes=%d verts=%d est_mb=%.2f batched_instances=%d" % [s["tiles"], s["meshes"], s["verts"], bytes / 1048576.0, s["instances"]])


func process() -> void:
	if not started:
		return
	var pending := dirty.keys()
	for i in mini(TILES_PER_FRAME, pending.size()):
		_rebuild(pending[i])


## Материалы те же ресурсы, поэтому Gfx.small_textures обновляет их без копий.
## Пересборка также подхватывает замену материала и режим теней источника.
func quality_changed() -> void:
	for g: Dictionary in pool.groups.values():
		if g.has("batch_slots"):
			g["batch_cost"] = _cost(g)
			for r: Dictionary in (g["batch_slots"] as Dictionary).values():
				r["safe"] = _can_bake(g, r["xf"])
	for tile: Vector2i in tiles:
		dirty[tile] = true


func _rebuild(tile: Vector2i) -> void:
	dirty.erase(tile)
	var td: Dictionary = tiles[tile]
	bytes -= int(td["bytes"])
	# До конца кадра старые сетки уже не участвуют в отрисовке.
	for node: MeshInstance3D in td["nodes"]:
		node.visible = false
		node.mesh = null
		node.queue_free()
	td["nodes"] = []
	td["members"] = []
	td["bytes"] = 0
	td["verts"] = 0
	var buckets: Dictionary = {}
	var origin := Vector3(tile.x * BATCH_TILE, 0, tile.y * BATCH_TILE)
	var gs: Dictionary = td["groups"]
	for key: String in gs.keys():
		var g: Dictionary = pool.groups[key]
		var slots: Dictionary = gs[key]
		var live := 0
		var safe := true
		for slot: int in slots:
			if not record(g, slot)["hidden"]:
				live += 1
				safe = safe and bool(record(g, slot)["safe"])
		var cost := int(g["batch_cost"])
		var merge := safe and live > 0 and live <= MERGE_MAX and cost > 0 and bool(g.get("batch_visible", true)) and bytes + int(td["bytes"]) + live * cost <= MEMORY_LIMIT
		for slot: int in slots:
			var r := record(g, slot)
			r["merged"] = merge and not r["hidden"]
			if r["merged"]:
				_append(buckets, g, r, origin)
				td["members"].append([key, slot, r["gen"]])
				td["bytes"] += cost
			_write(g, slot, r)
		_sync_visibility(g)
		if slots.is_empty():
			gs.erase(key)
	for bucket: Dictionary in buckets.values():
		var arrays: Array = bucket["arrays"]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, bucket["mat"])
		var mi := MeshInstance3D.new()
		mi.name = "StaticBatch_%d_%d_%d" % [tile.x, tile.y, (td["nodes"] as Array).size()]
		mi.mesh = mesh
		mi.position = origin
		mi.cast_shadow = bucket["shadow"]
		pool.add_child(mi)
		td["nodes"].append(mi)
		td["verts"] += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	bytes += int(td["bytes"])
	if gs.is_empty():
		tiles.erase(tile)


func _append(buckets: Dictionary, g: Dictionary, r: Dictionary, origin: Vector3) -> void:
	for sub: Dictionary in g["subs"]:
		var mm: MultiMesh = sub["mm"]
		var mesh := mm.mesh as ArrayMesh
		var xf: Transform3D = (r["xf"] as Transform3D) * (sub["local"] as Transform3D)
		xf.origin -= origin
		# Как shader MultiMesh: нормаль экземпляра умножается на basis (не inverse transpose).
		var normal_xf := xf.basis
		var shadow: int = (sub["mmi"] as MultiMeshInstance3D).cast_shadow
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s) as StandardMaterial3D
			var key := "%d|%d" % [mat.get_instance_id(), shadow]
			if not buckets.has(key):
				var fresh: Array = []
				fresh.resize(Mesh.ARRAY_MAX)
				fresh[Mesh.ARRAY_VERTEX] = PackedVector3Array()
				fresh[Mesh.ARRAY_NORMAL] = PackedVector3Array()
				fresh[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
				fresh[Mesh.ARRAY_COLOR] = PackedColorArray()
				fresh[Mesh.ARRAY_INDEX] = PackedInt32Array()
				if mat.normal_enabled:
					fresh[Mesh.ARRAY_TANGENT] = PackedFloat32Array()
				buckets[key] = {"arrays": fresh, "mat": mat, "shadow": shadow}
			var a := mesh.surface_get_arrays(s)
			var out: Array = buckets[key]["arrays"]
			var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var cs: PackedColorArray = a[Mesh.ARRAY_COLOR] if a[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var points: PackedVector3Array = out[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = out[Mesh.ARRAY_NORMAL]
			var uvs: PackedVector2Array = out[Mesh.ARRAY_TEX_UV]
			var colors: PackedColorArray = out[Mesh.ARRAY_COLOR]
			var indices: PackedInt32Array = out[Mesh.ARRAY_INDEX]
			var tangents := PackedFloat32Array()
			if mat.normal_enabled:
				tangents = out[Mesh.ARRAY_TANGENT]
			var base := points.size()
			var col: Color = r["col"] if mm.use_colors else Color.WHITE
			for i in vs.size():
				points.append(xf * vs[i])
				normals.append((normal_xf * ns[i]).normalized())
				uvs.append(uv[i] if not uv.is_empty() else Vector2.ZERO)
				# COLOR сначала умножается на цвет MultiMesh, затем материал переводит sRGB.
				colors.append((cs[i] if not cs.is_empty() else Color.WHITE) * col)
				if mat.normal_enabled:
					var ts: PackedFloat32Array = a[Mesh.ARRAY_TANGENT]
					var tangent := (xf.basis * Vector3(ts[i * 4], ts[i * 4 + 1], ts[i * 4 + 2])).normalized()
					tangents.append_array(PackedFloat32Array([tangent.x, tangent.y, tangent.z, ts[i * 4 + 3]]))
			var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if ix.is_empty():
				for i in vs.size():
					indices.append(base + i)
			else:
				for i in ix:
					indices.append(base + i)
			out[Mesh.ARRAY_VERTEX] = points
			out[Mesh.ARRAY_NORMAL] = normals
			out[Mesh.ARRAY_TEX_UV] = uvs
			out[Mesh.ARRAY_COLOR] = colors
			out[Mesh.ARRAY_INDEX] = indices
			if mat.normal_enabled:
				out[Mesh.ARRAY_TANGENT] = tangents


func stats() -> Dictionary:
	var out := {"tiles": tiles.size(), "meshes": 0, "verts": 0, "instances": 0, "bytes": bytes, "dirty": dirty.size()}
	for td: Dictionary in tiles.values():
		out["meshes"] += (td["nodes"] as Array).size()
		out["verts"] += int(td["verts"])
		out["instances"] += (td["members"] as Array).size()
	return out


## Проверка владения геометрией: одна запись на живой слот, без старых поколений.
func audit() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen: Dictionary = {}
	for tile: Vector2i in tiles:
		var expected: Dictionary = {}
		for member: Array in tiles[tile]["members"]:
			var key := "%s:%d" % [member[0], member[1]]
			var g: Dictionary = pool.groups[member[0]]
			var r := record(g, member[1])
			if seen.has(key) or r.is_empty() or r.get("gen", -1) != member[2] or r.get("tile") != tile or r.get("hidden", true) or not r.get("merged", false):
				errors.append("orphan/duplicate " + key)
			seen[key] = true
			for sub: Dictionary in g["subs"]:
				var mesh := (sub["mm"] as MultiMesh).mesh as ArrayMesh
				for s in mesh.get_surface_count():
					var mk := "%d|%d" % [mesh.surface_get_material(s).get_instance_id(), (sub["mmi"] as MultiMeshInstance3D).cast_shadow]
					var n: Vector2i = expected.get(mk, Vector2i.ZERO)
					var ic := mesh.surface_get_array_index_len(s)
					expected[mk] = n + Vector2i(mesh.surface_get_array_len(s), ic if ic > 0 else mesh.surface_get_array_len(s))
		for mi: MeshInstance3D in tiles[tile]["nodes"]:
			var mesh := mi.mesh as ArrayMesh
			var mk := "%d|%d" % [mesh.surface_get_material(0).get_instance_id(), mi.cast_shadow]
			var actual := Vector2i(mesh.surface_get_array_len(0), mesh.surface_get_array_index_len(0))
			if expected.get(mk, Vector2i.ZERO) != actual or not mi.visible or mesh.get_surface_count() != 1:
				errors.append("geometry/material/shadow " + mk)
			expected.erase(mk)
		if not expected.is_empty():
			errors.append("missing mesh tile=%s" % tile)
	for g: Dictionary in pool.groups.values():
		for slot: int in g.get("batch_slots", {}):
			var r := record(g, slot)
			var key := "%s:%d" % [g["key"], slot]
			if (g["free"] as Array).has(slot) or bool(r["merged"]) != seen.has(key):
				errors.append("missing/free " + key)
			for sub: Dictionary in g["subs"]:
				var mm: MultiMesh = sub["mm"]
				var xf := mm.get_instance_transform(slot)
				var zero := xf.basis.get_scale().length() < 0.000001
				if zero != (bool(r["hidden"]) or bool(r["merged"])):
					errors.append("slot transform " + key)
				if not zero and (not xf.is_equal_approx((r["xf"] as Transform3D) * (sub["local"] as Transform3D)) or not (sub["mmi"] as MultiMeshInstance3D).visible):
					errors.append("undrawn MultiMesh " + key)
	if not dirty.is_empty():
		errors.append("dirty tiles=%d" % dirty.size())
	return errors
