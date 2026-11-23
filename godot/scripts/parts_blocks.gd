extends Node3D
## Квартал хранит исходный пул и готовые меши. Пока новая версия не готова, виден исходный пул.

const DEBOUNCE_MS := 100
const SLICE_US := 2400
const TOTAL_BYTES := 110 * 1024 * 1024
const BLOCK_BYTES := 6 * 1024 * 1024
const GROUP_BYTES := 1024 * 1024
const MAX_VERTICES := 4800
const MAX_SURFACE_VERTICES := 24000
const MAX_LODS := 3
const LOD_SAFETY := 2.0

var size := 48.0
var use_lod := true
var suspended := false
var blocks := {}
var buildings := {}
var holds := {}
var queued := {}
var bytes := 0
var builds := 0
var peak_us := 0
var last_commit_frame := -1

var _sources := {}
var _materials := {}
var _material_keys := {}
var _pools := {}
var _job := {}
var _task := -1


func for_building(id: int, origin: Vector3) -> Dictionary:
	var key := Vector2i(floori(origin.x / size), floori(origin.z / size))
	if not blocks.has(key):
		blocks[key] = {"key": key, "origin": Vector3(key.x * size, 0, key.y * size),
			"groups": {}, "ids": {}, "merged": [], "draw": null,
			"rev": 0, "due": 0, "bytes": 0, "lods": 0, "held": 0}
	var block: Dictionary = blocks[key]
	buildings[id] = block
	block["ids"][id] = true
	if holds.has(id):
		block["held"] += 1
		_visible(block)
	return block


func forget(id: int) -> void:
	var block: Dictionary = buildings.get(id, {})
	if block.is_empty():
		return
	buildings.erase(id)
	block["ids"].erase(id)
	if holds.has(id):
		block["held"] -= 1
		_visible(block)
	if block["ids"].is_empty() and not queued.has(block["key"]):
		changed(block)


## Источники обводки держат квартал в его исходном пуле, пока видна подсветка.
func hold(id: int, reason: int, on: bool) -> void:
	var old: int = holds.get(id, 0)
	var mask := old | reason if on else old & ~reason
	if mask == old:
		return
	if mask == 0:
		holds.erase(id)
	else:
		holds[id] = mask
	if buildings.has(id) and (old == 0 or mask == 0):
		var block: Dictionary = buildings[id]
		block["held"] += 1 if old == 0 else -1
		_visible(block)


func _visible(block: Dictionary) -> void:
	var draw: Node3D = block["draw"]
	var merged: bool = draw != null and int(block["held"]) == 0
	for g: Dictionary in block["merged"]:
		if bool(g["in_mesh"]) == merged:
			continue
		g["in_mesh"] = merged
		for slot: int in g["rows"]:
			if not g["hidden"].has(slot):
				_draw_row(g["pool"], g["rows"][slot], not merged)
	if draw != null:
		draw.visible = merged


## Проверяем весь экземпляр: у него могут быть несколько мешей с разными материалами.
func group(block: Dictionary, template: Dictionary) -> Dictionary:
	if block.is_empty() or template["subs"].is_empty():
		return template
	var key: String = template["key"]
	var groups: Dictionary = block["groups"]
	if groups.has(key):
		return groups[key]
	var cost: int = template.get("block_cost", -1)
	if cost < 0:
		cost = _cost(template["subs"])
		template["block_cost"] = cost
	if cost == 0:
		return template
	var pool := _pool(template)
	var result := {"key": key, "subs": pool["subs"], "used": 0, "free": [],
		"rows": {}, "hidden": {}, "block": block, "cost": cost, "pool": pool, "in_mesh": false}
	groups[key] = result
	return result


func _pool(template: Dictionary) -> Dictionary:
	var key: String = template["key"]
	if _pools.has(key):
		return _pools[key]
	var pool := {"subs": [], "active": [], "cap": 0}
	var colors := template.has("tint")
	for sub: Dictionary in template["subs"]:
		var source: MultiMeshInstance3D = sub["mmi"]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = colors
		mm.mesh = source.multimesh.mesh
		var mmi := MultiMeshInstance3D.new()
		mmi.cast_shadow = source.cast_shadow
		mmi.multimesh = mm
		add_child(mmi)
		pool["subs"].append({"mm": mm, "mmi": mmi, "local": sub["local"]})
	_pools[key] = pool
	return pool


## Ручка остаётся в квартале. У видимых строк общий плотный буфер по типу детали.
func place_row(g: Dictionary, xf: Transform3D, color: Color) -> int:
	var free: Array = g["free"]
	var slot: int = g["used"] if free.is_empty() else free.pop_back()
	g["used"] = maxi(int(g["used"]), slot + 1)
	var row := [xf, color, -1]
	g["rows"][slot] = row
	_draw_row(g["pool"], row, not bool(g["in_mesh"]))
	return slot


func remove_row(g: Dictionary, slot: int) -> void:
	_draw_row(g["pool"], g["rows"][slot], false)
	g["rows"].erase(slot)
	g["hidden"].erase(slot)
	g["free"].append(slot)


func hide_row(g: Dictionary, slot: int, hidden: bool) -> void:
	if hidden:
		g["hidden"][slot] = true
	else:
		g["hidden"].erase(slot)
	_draw_row(g["pool"], g["rows"][slot], not hidden and not bool(g["in_mesh"]))
	changed(g["block"])


static func _draw_row(pool: Dictionary, row: Array, show: bool) -> void:
	var i: int = row[2]
	if (i >= 0) == show:
		return
	var active: Array = pool["active"]
	var subs: Array = pool["subs"]
	if show:
		i = active.size()
		active.append(row)
		row[2] = i
		if active.size() > int(pool["cap"]):
			pool["cap"] = maxi(16, int(pool["cap"]) * 2)
			for sub: Dictionary in subs:
				(sub["mm"] as MultiMesh).instance_count = pool["cap"]
			for e: Array in active:
				_put_row(subs, e)
		else:
			_put_row(subs, row)
	else:
		var last: Array = active.pop_back()
		if i < active.size():
			last[2] = i
			active[i] = last
			_put_row(subs, last)
		row[2] = -1
	for sub: Dictionary in subs:
		(sub["mm"] as MultiMesh).visible_instance_count = active.size()


static func _put_row(subs: Array, row: Array) -> void:
	var xf: Transform3D = row[0]
	var slot: int = row[2]
	for sub: Dictionary in subs:
		var mm: MultiMesh = sub["mm"]
		mm.set_instance_transform(slot, xf * (sub["local"] as Transform3D))
		if mm.use_colors:
			mm.set_instance_color(slot, row[1])


static func _cost(subs: Array) -> int:
	var verts := 0
	var indices := 0
	for sub: Dictionary in subs:
		var node: MultiMeshInstance3D = sub["mmi"]
		var mesh := node.multimesh.mesh as ArrayMesh
		var local: Transform3D = sub["local"]
		if mesh == null or mesh.get_blend_shape_count() != 0 or node.visibility_range_end > 0.0 or local.basis.determinant() <= 0.0:
			return 0
		if node.cast_shadow not in [GeometryInstance3D.SHADOW_CASTING_SETTING_ON, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF]:
			return 0
		for s in mesh.get_surface_count():
			var m := mesh.surface_get_material(s) as StandardMaterial3D
			var format := mesh.surface_get_format(s)
			if m == null or m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or m.emission_enabled \
					or m.uv1_triplanar or m.uv2_triplanar or m.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED \
					or m.next_pass != null or m.grow or mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES \
					or (format & (Mesh.ARRAY_FORMAT_CUSTOM0 | Mesh.ARRAY_FORMAT_CUSTOM1 | Mesh.ARRAY_FORMAT_CUSTOM2 \
					| Mesh.ARRAY_FORMAT_CUSTOM3 | Mesh.ARRAY_FORMAT_BONES | Mesh.ARRAY_FORMAT_WEIGHTS)) != 0:
				return 0
			var n := mesh.surface_get_array_len(s)
			verts += n
			indices += maxi(mesh.surface_get_array_index_len(s), n)
	if verts > MAX_VERTICES:
		return 0
	# Запас на полные атрибуты и три индексных LOD с убывающим числом индексов.
	return verts * 64 + indices * 12


func changed(block: Dictionary) -> void:
	block["rev"] += 1
	block["due"] = Time.get_ticks_msec() + DEBOUNCE_MS
	queued[block["key"]] = block
	var old: Node3D = block["draw"]
	if old == null:
		return
	old.hide()
	old.queue_free()
	block["draw"] = null
	_visible(block)
	block["merged"] = []
	bytes -= int(block["bytes"])
	block["bytes"] = 0
	block["lods"] = 0


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	# Группы содержат ссылки на квартал, а квартал — на группы.
	for block: Dictionary in blocks.values():
		(block["groups"] as Dictionary).clear()
		(block["merged"] as Array).clear()
	blocks.clear()
	buildings.clear()
	queued.clear()
	_job.clear()


func _process(_delta: float) -> void:
	if suspended:
		return
	var start := Time.get_ticks_usec()
	_step(start + SLICE_US)
	peak_us = maxi(peak_us, Time.get_ticks_usec() - start)


func _step(deadline: int) -> void:
	if _task >= 0:
		if not WorkerThreadPool.is_task_completed(_task):
			return
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	if not _job.is_empty():
		var block: Dictionary = _job["block"]
		if _job["rev"] != block["rev"]:
			var stale: Node3D = _job.get("draw")
			if stale != null:
				stale.queue_free()
			_job = {}
		elif _job.has("result"):
			_commit_piece()
			return
		else:
			_collect(deadline)
			return
	var now := Time.get_ticks_msec()
	for block: Dictionary in queued.values():
		if int(block["due"]) <= now:
			queued.erase(block["key"])
			_start(block)
			break


func _start(block: Dictionary) -> void:
	var candidates := []
	for g: Dictionary in (block["groups"] as Dictionary).values():
		var count: int = g["rows"].size() - g["hidden"].size()
		var cost: int = g["cost"] * count
		if count > 0 and cost <= GROUP_BYTES and (count < 16 or cost < 192 * 1024):
			candidates.append([g, cost])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) < int(b[1]))
	var budget := mini(BLOCK_BYTES, TOTAL_BYTES - bytes)
	var cost := 0
	var groups := []
	for pair: Array in candidates:
		if cost + int(pair[1]) > budget:
			break
		groups.append(pair[0])
		cost += int(pair[1])
	if groups.is_empty():
		if block["ids"].is_empty():
			(block["groups"] as Dictionary).clear()
			blocks.erase(block["key"])
		return
	_job = {"block": block, "rev": block["rev"], "groups": groups, "bytes": cost,
		"cursor": 0, "rows": [], "lod": use_lod, "origin": block["origin"]}


func _collect(deadline: int) -> void:
	var groups: Array = _job["groups"]
	var cursor: int = _job["cursor"]
	var rows: Array = _job["rows"]
	var origin: Vector3 = _job["origin"]
	while cursor < groups.size() and Time.get_ticks_usec() < deadline:
		var g: Dictionary = groups[cursor]
		for sub: Dictionary in g["subs"]:
			var mmi: MultiMeshInstance3D = sub["mmi"]
			var mesh: ArrayMesh = mmi.multimesh.mesh
			var source := _source(mesh, mmi.cast_shadow)
			var local: Transform3D = sub["local"]
			for slot: int in g["rows"]:
				if g["hidden"].has(slot):
					continue
				var e: Array = g["rows"][slot]
				var xf: Transform3D = (e[0] as Transform3D) * local
				xf.origin -= origin
				rows.append([source, xf, e[1]])
		cursor += 1
	_job["cursor"] = cursor
	if cursor == groups.size():
		# У рабочего свой словарь. Ресурсы материалов он только читает.
		var request := {"rows": rows, "lod": _job["lod"]}
		_job["result"] = request
		_task = WorkerThreadPool.add_task(_build.bind(request), false, "Квартал города")


func _source(mesh: ArrayMesh, shadow: int) -> Array:
	var cache_key := "%d/%d" % [mesh.get_instance_id(), shadow]
	if _sources.has(cache_key):
		return _sources[cache_key]
	var result := []
	for s in mesh.get_surface_count():
		var mat := _shared_material(mesh.surface_get_material(s))
		var arrays := mesh.surface_get_arrays(s)
		var format := mesh.surface_get_format(s) & ((1 << Mesh.ARRAY_MAX) - 1)
		if mat.vertex_color_use_as_albedo:
			format |= Mesh.ARRAY_FORMAT_COLOR
		format |= Mesh.ARRAY_FORMAT_INDEX
		result.append([arrays, mat, shadow, mat.vertex_color_use_as_albedo, "%d/%d" % [mat.get_instance_id(), format]])
	_sources[cache_key] = result
	return result


## Одинаковые параметры материала дают одну поверхность, даже если у деталей разные remap.
func _shared_material(mat: StandardMaterial3D) -> StandardMaterial3D:
	var id := mat.get_instance_id()
	if _material_keys.has(id):
		return _material_keys[id]
	var key := []
	for p: Dictionary in mat.get_property_list():
		var prop: String = p["name"]
		if (int(p["usage"]) & PROPERTY_USAGE_STORAGE) == 0 or prop.begins_with("resource_") or prop.begins_with("metadata/"):
			continue
		# Ключ не владеет текстурой: Gfx может освободить большую версию после смены пресета.
		var value: Variant = mat.get(prop)
		key.append(value.get_instance_id() if value is Resource else value)
	var shared: StandardMaterial3D = _materials.get(key, mat)
	_materials[key] = shared
	_material_keys[id] = shared
	return shared


## У ImporterMesh свойство материала и имя поверхности определяют, какие сетки можно склеить.
## Одна крупная поверхность разбивается перед загрузкой, чтобы одна команда не заняла весь кадр.
static func _build(request: Dictionary) -> void:
	var buckets := [{}, {}]
	for row: Array in request["rows"]:
		var xf: Transform3D = row[1]
		var color: Color = row[2]
		for surface: Array in row[0]:
			var arrays: Array = surface[0]
			var n: int = arrays[Mesh.ARRAY_VERTEX].size()
			var which := int(int(surface[2]) != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			var key: String = surface[4]
			var by_material: Dictionary = buckets[which]
			var chunks: Array = by_material.get(key, [])
			if chunks.is_empty() or int(chunks.back()["vertices"]) + n > MAX_SURFACE_VERTICES:
				chunks.append({"vertices": 0, "surfaces": []})
				by_material[key] = chunks
			var chunk: Dictionary = chunks.back()
			chunk["vertices"] += n
			chunk["surfaces"].append([surface, xf, color])
	var output := []
	for which in buckets.size():
		for chunks: Array in buckets[which].values():
			for chunk: Dictionary in chunks:
				var sources: Array[ImporterMesh] = []
				var transforms: Array[Transform3D] = []
				for e: Array in chunk["surfaces"]:
					var descriptor: Array = e[0]
					var arrays: Array = (descriptor[0] as Array).duplicate()
					var color: Color = e[2]
					if bool(descriptor[3]):
						_apply_tint(arrays, color)
					if arrays[Mesh.ARRAY_INDEX] == null:
						arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(range(arrays[Mesh.ARRAY_VERTEX].size()))
					var src := ImporterMesh.new()
					src.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, descriptor[1], "block")
					sources.append(src)
					transforms.append(e[1])
				var merged := _merge(sources, transforms)
				if bool(request["lod"]):
					merged.generate_lods(25.0, 0.0, [])
				for s in merged.get_surface_count():
					var lods := {}
					var arrays := merged.get_surface_arrays(s)
					var indices0: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
					var last := indices0.size()
					for i in merged.get_surface_lod_count(s):
						var indices := merged.get_surface_lod_indices(s, i)
						if indices.size() > int(last * 0.6):
							continue
						lods[merged.get_surface_lod_size(s, i) * LOD_SAFETY] = indices
						last = indices.size()
						if lods.size() >= MAX_LODS:
							break
					output.append([arrays, merged.get_surface_material(s), which, lods])
	request["pieces"] = output


static func _apply_tint(arrays: Array, color: Color) -> void:
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	if colors.is_empty():
		colors.resize(arrays[Mesh.ARRAY_VERTEX].size())
		colors.fill(color)
	elif color != Color.WHITE:
		for i in colors.size():
			colors[i] *= color
	arrays[Mesh.ARRAY_COLOR] = colors


static func _merge(meshes: Array[ImporterMesh], transforms: Array[Transform3D]) -> ImporterMesh:
	return ImporterMesh.merge_importer_meshes(meshes, transforms)


func _commit_piece() -> void:
	var block: Dictionary = _job["block"]
	var request: Dictionary = _job["result"]
	var pieces: Array = request.get("pieces", [])
	if pieces.is_empty():
		_job = {}
		return
	var draw: Node3D = _job.get("draw")
	if draw == null:
		draw = Node3D.new()
		draw.hide()
		add_child(draw)
		draw.position = block["origin"]
		_job["draw"] = draw
		_job["next"] = 0
		_job["lods"] = 0
	var i: int = _job["next"]
	if i < pieces.size():
		var e: Array = pieces[i]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, e[0], [], e[3])
		if mesh.get_surface_count() == 0:
			draw.queue_free()
			_job = {}
			return
		mesh.surface_set_material(0, e[1])
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if int(e[2]) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draw.add_child(mi)
		_job["next"] = i + 1
		_job["lods"] += (e[3] as Dictionary).size()
		return
	block["draw"] = draw
	block["merged"] = _job["groups"]
	block["bytes"] = _job["bytes"]
	block["lods"] = _job["lods"]
	bytes += int(block["bytes"])
	builds += 1
	last_commit_frame = Engine.get_process_frames()
	_visible(block)
	_job = {}


func settled() -> bool:
	return queued.is_empty() and _job.is_empty()
