extends RefCounted
## Геометрия городских деталей, подготовленная отдельно от кадров игры.

const CACHE_VERSION := 2
const REF_HEIGHT := 1080.0
const PROP_PIXELS := 1.5
const PROP_MAX_SIZE := 0.8
const PROP_KINDS := ["Vase", "Senser", "Censer", "FlowerPot", "Basket", "Seat", "Jar", "Jug", "Stool", "Sack", "Amphora", "Goblet", "Bowl"]

# Модели, у которых PERF14-c2 добавил индексные LOD.
const C2_LOD := [
	"SM_Bld_Door_Half_02", "SM_Bld_Door_Half_03", "SM_Bld_Door_Large_01",
	"SM_Bld_Floor_Trim_01", "SM_Bld_Pillar_06", "SM_Bld_Pillar_Large_04",
	"SM_Bld_Roof_Base_Corner_01", "SM_Bld_Roof_Base_Straight_Side_01", "SM_Bld_Roof_Edge_Straight_01",
	"SM_Bld_Roof_Topper_02", "SM_Bld_Trim_03", "SM_Bld_Trim_04",
	"SM_Bld_Trim_05", "SM_Bld_Trim_Large_Corner_01", "SM_Bld_Trim_Large_Single_01",
	"SM_Bld_Trim_Large_Single_02", "SM_Bld_Wall_Balcony_03", "SM_Bld_Wall_Balcony_06",
	"SM_Bld_Wall_Beam_Detail_01", "SM_Bld_Wall_Door_Double_01", "SM_Bld_Wall_Door_Large_01",
	"SM_Bld_Wall_Window_01", "SM_Bld_Wall_Window_02", "SM_Env_Tree_01",
	"SM_Prop_Basket_02", "SM_Prop_Basket_03", "SM_Prop_Basket_05",
	"SM_Prop_Basket_06", "SM_Prop_Basket_07", "SM_Prop_Basket_08",
	"SM_Prop_Basket_10", "SM_Prop_Basket_12", "SM_Prop_Basket_Insert_02",
	"SM_Prop_Basket_Set_01", "SM_Prop_Basket_Set_03", "SM_Prop_Basket_Set_04",
	"SM_Prop_Bowl_04", "SM_Prop_Bowl_05", "SM_Prop_Brazier_01",
	"SM_Prop_FlowerPot_Fancy_01", "SM_Prop_FlowerPot_Hanging_01", "SM_Prop_FlowerPot_Hanging_02",
	"SM_Prop_FlowerPot_Hanging_03", "SM_Prop_FlowerPot_Hanging_04", "SM_Prop_FlowerPot_Hanging_05",
	"SM_Prop_FlowerPot_Hanging_06", "SM_Prop_Goblet_01", "SM_Prop_Jug_01",
	"SM_Prop_Jug_04", "SM_Prop_Jug_05", "SM_Prop_Rug_Drape_01",
	"SM_Prop_Sack_03", "SM_Prop_Sack_04", "SM_Prop_Sack_05",
	"SM_Prop_Senser_02", "SM_Prop_Senser_04", "SM_Prop_Statue_03",
	"SM_Prop_Stool_01", "SM_Prop_Table_07", "SM_Prop_Vase_01",
	"SM_Prop_Vase_02", "SM_Prop_Vase_03", "SM_Prop_Vase_04",
	"SM_Prop_Vase_06", "SM_Prop_Vase_Pile_04",
]

var tile_m := 0.0
var lods := false
var prepare_c2 := false
var tiny := false
var shadows := 0                   # 1 — мелочь без тени, 2 — отдельная сетка для тени
var area_keys := {}                 # выбор дорогих групп для замера
var tiles := 0

static var prepared := {}          # исходный меш → готовые сетки; заполняется при подготовке моделей


static func prop(name: String) -> bool:
	return name.begins_with("SM_Prop_") and name.get_slice("_", 2) in PROP_KINDS


static func tile_candidate(name: String) -> bool:
	return prop(name) or name.begins_with("SM_Bld_Trim_") or name.begins_with("SM_Bld_Roof_") \
		or name.begins_with("SM_Bld_Wall_Window_") or name.begins_with("SM_Bld_Pillar_") \
		or name.begins_with("SM_Bld_Wall_Door_") or name.begins_with("SM_Prop_Shelf_")


static func shadow_candidate(name: String) -> bool:
	return prop(name) or name.begins_with("SM_Bld_Trim_") or name.begins_with("SM_Bld_Floor_Trim_")


func uses_area(name: String, key: String) -> bool:
	return tile_m > 0.0 and tile_candidate(name) and (area_keys.is_empty() or area_keys.has(key))


static func small_end(diameter: float, radius: float) -> float:
	var tan_y := tan(deg_to_rad(CameraRig.FOV * 0.5))
	var tan_x := tan_y * 16.0 / 9.0
	# Запас для края проекции и ближайшей точки плитки.
	return radius + diameter * REF_HEIGHT / (2.0 * tan_y * PROP_PIXELS) * (1.0 + tan_x * tan_x + tan_y * tan_y)


func copy_mesh(source: Mesh, tile: Vector2i, name := "") -> Mesh:
	if lods and tile.x < 0:
		if prepare_c2 and name in C2_LOD:
			return with_missing_lods(source).duplicate() as Mesh
		var entry: Dictionary = prepared.get(source.get_instance_id(), {})
		var ready: ArrayMesh = entry.get("lod")
		if ready != null:
			return ready.duplicate() as Mesh
	return source.duplicate() as Mesh


func add_shadow(pool: Node3D, g: Dictionary, sub: Dictionary, name: String, source: Mesh) -> void:
	var mmi: MultiMeshInstance3D = sub["mmi"]
	if shadows == 0 or not shadow_candidate(name) or mmi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
		return
	if shadows == 1:
		sub["casts"] = true
		return
	var entry: Dictionary = prepared.get(source.get_instance_id(), {})
	var proxy: ArrayMesh = entry.get("proxy")
	if proxy == null:
		return
	var mesh: Mesh = (sub["mm"] as MultiMesh).mesh
	for s in mesh.get_surface_count():
		var mat := mesh.surface_get_material(s) as StandardMaterial3D
		if mat == null or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
				or mat.cull_mode != BaseMaterial3D.CULL_BACK or mat.next_pass != null:
			return
	var extra: Dictionary = pool._sub(proxy, sub["local"])
	(extra["mmi"] as MultiMeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g["subs"].append(extra)


func area_group(pool: Node3D, groups: Dictionary, g: Dictionary, world_pos: Vector3) -> Dictionary:
	var pos := Vector2(world_pos.x, world_pos.z)
	if not g.has("area"):
		g["area"] = true
		g["areas"] = {}
	if not g.has("area_anchor"):
		var footprint: Rect2 = g.get("footprint", Rect2(pos, Vector2.ZERO))
		var next := footprint.expand(pos)
		if maxf(next.size.x, next.size.y) <= tile_m:
			g["footprint"] = next
			return g
		# Компактная группа остаётся целиком. После первого выхода за плитку её центр фиксируется.
		g["area_anchor"] = footprint.get_center()
		g.erase("footprint")
	var anchor: Vector2 = g["area_anchor"]
	var relative := (pos - anchor) / tile_m + Vector2(0.5, 0.5)
	if relative.x >= 0.0 and relative.x <= 1.0 and relative.y >= 0.0 and relative.y <= 1.0:
		return g
	var tile := Vector2i(floori(relative.x), floori(relative.y))
	var areas: Dictionary = g["areas"]
	if areas.has(tile):
		return areas[tile]
	var key := "%s|area:%d,%d" % [g["key"], tile.x, tile.y]
	var area := {"subs": [], "free": [], "used": 0, "cap": 0, "key": key, "area": true}
	if g.has("tint"):
		area["tint"] = true
	for sub: Dictionary in g["subs"]:
		var mm: MultiMesh = sub["mm"]
		var mmi: MultiMeshInstance3D = sub["mmi"]
		var copy: Dictionary = pool._sub(mm.mesh, sub["local"], mm.use_colors)
		(copy["mmi"] as MultiMeshInstance3D).cast_shadow = mmi.cast_shadow
		if sub.has("casts"):
			copy["casts"] = true
		area["subs"].append(copy)
	groups[key] = area
	areas[tile] = area
	tiles += 1
	return area


func bounds(sub: Dictionary, xf: Transform3D, area: bool, use_range: bool) -> void:
	var mmi: MultiMeshInstance3D = sub["mmi"]
	var mesh: Mesh = (sub["mm"] as MultiMesh).mesh
	var box: AABB = xf * mesh.get_aabb()
	if area:
		var old: AABB = mmi.custom_aabb
		if not old.encloses(box):
			mmi.custom_aabb = box if old == AABB() else old.merge(box)
	if not use_range and (shadows != 1 or not sub.has("casts")):
		return
	var diameter := maxf(box.size.length(), float(sub.get("diameter", 0.0)))
	sub["diameter"] = diameter
	if shadows == 1 and sub.has("casts"):
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if diameter < 1.2 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if use_range:
		mmi.visibility_range_end = small_end(diameter, mmi.custom_aabb.size.length() * 0.5) \
			if diameter <= PROP_MAX_SIZE and mmi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF else 0.0


static func with_missing_lods(source: Mesh) -> Mesh:
	if not source is ArrayMesh or (source as ArrayMesh).get_blend_shape_count() != 0:
		return source
	prepare(source, "", false)
	var entry: Dictionary = prepared[source.get_instance_id()]
	var ready: ArrayMesh = entry["lod"]
	return source if ready == null else ready


static func prepare(source: ArrayMesh, cache_dir: String, make_proxy := true) -> Dictionary:
	var id := source.get_instance_id()
	if prepared.has(id):
		return {}
	var start := Time.get_ticks_usec()
	var importer := ImporterMesh.from_mesh(source)
	var missing := PackedInt32Array()
	var signatures := []
	for s in importer.get_surface_count():
		var arrays := importer.get_surface_arrays(s)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if not cache_dir.is_empty():
			signatures.append([hash(arrays[Mesh.ARRAY_VERTEX]), hash(arrays[Mesh.ARRAY_NORMAL]), hash(arrays[Mesh.ARRAY_COLOR]), hash(indices)])
		if importer.get_surface_lod_count(s) == 0 and indices.size() >= 96 and importer.get_surface_primitive_type(s) == Mesh.PRIMITIVE_TRIANGLES:
			missing.append(s)
	var path := "" if cache_dir.is_empty() else cache_dir.path_join("%d_%s.lod" % [CACHE_VERSION, var_to_bytes(signatures).hex_encode().sha256_text()])
	var indexed := {}
	var cached := FileAccess.open(path, FileAccess.READ) if not cache_dir.is_empty() else null
	if cached != null:
		var value: Variant = cached.get_var()
		if value is Dictionary:
			indexed = value
		cached = null
	elif not missing.is_empty():
		# У более широкого угла меньше искусственных швов. Базовые вершины и индексы не меняются.
		importer.generate_lods(80.0, 0.0, [])
		for s: int in missing:
			var variants := {}
			for level in importer.get_surface_lod_count(s):
				variants[importer.get_surface_lod_size(s, level)] = importer.get_surface_lod_indices(s, level)
			if not variants.is_empty():
				indexed[s] = variants
		var file := FileAccess.open(path, FileAccess.WRITE) if not cache_dir.is_empty() else null
		if file != null:
			file.store_var(indexed)
	var original := ImporterMesh.from_mesh(source) if not missing.is_empty() else importer
	var with_lods: ArrayMesh
	if not indexed.is_empty():
		with_lods = _with_lods(source, original, indexed)
	var proxy := _shadow_proxy(original, indexed) if make_proxy else null
	prepared[id] = {"source": source, "lod": with_lods, "proxy": proxy}
	return {"missing": missing.size(), "with_lod": indexed.size(), "proxy": proxy != null, "us": Time.get_ticks_usec() - start}


static func _with_lods(source: ArrayMesh, original: ImporterMesh, indexed: Dictionary) -> ArrayMesh:
	var surfaces: Array = source.get("_surfaces")
	var shadow := ArrayMesh.new()
	for s in original.get_surface_count():
		var surface: Dictionary = surfaces[s]
		var levels: Dictionary = indexed.get(s, {})
		if not levels.is_empty():
			var packed := []
			for distance: float in levels:
				packed.append(distance)
				packed.append(_index_bytes(levels[distance], int(surface["vertex_count"])))
			surface["lods"] = packed
		else:
			for level in original.get_surface_lod_count(s):
				levels[original.get_surface_lod_size(s, level)] = original.get_surface_lod_indices(s, level)
		if source.shadow_mesh != null:
			_add_shadow_surface(shadow, original, s, levels, false)
	var mesh := ArrayMesh.new()
	# Оставляем исходные сжатые атрибуты, меняем лишь индексные LOD.
	mesh.set("_surfaces", surfaces)
	mesh.custom_aabb = source.custom_aabb
	mesh.resource_name = source.resource_name
	for s in mesh.get_surface_count():
		mesh.surface_set_material(s, source.surface_get_material(s))
	if shadow.get_surface_count() == surfaces.size():
		mesh.shadow_mesh = shadow
	return mesh


static func _index_bytes(indices: PackedInt32Array, vertices: int) -> PackedByteArray:
	if vertices > 65536:
		return indices.to_byte_array()
	var bytes := PackedByteArray()
	bytes.resize(indices.size() * 2)
	for i in indices.size():
		bytes.encode_u16(i * 2, indices[i])
	return bytes


static func _shadow_proxy(original: ImporterMesh, indexed: Dictionary) -> ArrayMesh:
	var proxy := ArrayMesh.new()
	var simplified := false
	for s in original.get_surface_count():
		if original.get_surface_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			return null
		var levels: Dictionary = indexed.get(s, {})
		if levels.is_empty():
			for level in original.get_surface_lod_count(s):
				levels[original.get_surface_lod_size(s, level)] = original.get_surface_lod_indices(s, level)
		simplified = simplified or not levels.is_empty()
		_add_shadow_surface(proxy, original, s, levels, true)
	return proxy if simplified else null


static func _add_shadow_surface(mesh: ArrayMesh, original: ImporterMesh, s: int, levels: Dictionary, lowest: bool) -> void:
	var src := original.get_surface_arrays(s)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = src[Mesh.ARRAY_VERTEX]
	arrays[Mesh.ARRAY_INDEX] = src[Mesh.ARRAY_INDEX]
	if lowest and not levels.is_empty():
		arrays[Mesh.ARRAY_INDEX] = levels[levels.keys().max()]
	mesh.add_surface_from_arrays(original.get_surface_primitive_type(s), arrays, [], {} if lowest else levels)
