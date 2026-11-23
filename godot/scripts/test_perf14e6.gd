extends "res://scripts/test_perf14e5.gd"

const Frustum = preload("res://scripts/test_tris14.gd")
const DEPTH := "rendering/driver/depth_prepass/enable"
const GROUPS := ["parts", "foliage", "citizens", "ground", "horizon", "water", "other"]
const QUALITIES := ["verylow", "low"]

var samples: FileAccess
var geometry: FileAccess
var formats: FileAccess
var surface_cache := {}
var compressed_meshes := {}
var compressed_batches := {}
var city_label := ""
var boot_preset := "verylow"


func _boot(m: String) -> void:
	seed(1406)
	AnimClock.movie = 10.0
	load_quality = boot_preset
	sharing = true
	super._boot(m)


func _run(_mode: String) -> void:
	var depth: bool = ProjectSettings.get_setting(DEPTH)
	if (RenderingServer.get_current_rendering_method() != "forward_plus" or city_src != OWNER
			or depth != (A.get("depth", "1") == "1")):
		fail("нужны Forward+, город владельца и заданный depth prepass")
		_finish_probe()
		return
	output = str(A.get("out", GamePaths.save_dir().path_join("shots")))
	DirAccess.make_dir_recursive_absolute(output)
	samples = _table("samples", "city\tquality\tview\tcase\tgpu_ms\tp10_ms\tframe_ms\tvisible_triangles\tdraws\tshadow_triangles\tshadow_draws\tmodels\tpeople_ms\tanim_ms")
	geometry = _table("geometry", "city\tview\tthreshold\tgroup\ttriangles\treferenced_vertices\tsurfaces_x_instances\tlod_eligible_x_instances\tlod_hits_x_instances\tzero_triangles\toutside_frustum_triangles\tskinned_vertices")
	formats = _table("formats", "city\tmodel\tsurface\tformat\tcompressed\tvertices\tvertex_bytes\tattribute_bytes\tskin_bytes")
	if samples == null or geometry == null or formats == null:
		fail("не удалось открыть таблицы")
		_finish_probe()
		return
	A["warm"] = A.get("warm", "48")
	A["n"] = A.get("n", "90")
	print("PERF14E6 START ", RenderingServer.get_video_adapter_name(), " depth=", depth,
		" user=", OS.get_user_data_dir())
	for town: String in ["owner", "new"]:
		city_label = town
		if town == "new":
			var old: Node = game
			old.queue_free()
			await old.tree_exited
			await frames(12)
			_boot("new")
		await _probe_city()
	if A.has("matched_golden"):
		await _matched_golden()
	_finish_probe()


func _finish_probe() -> void:
	for file: FileAccess in [samples, geometry, formats]:
		if file != null:
			file.close()
	print("PERF14E6 DONE fails=", fails)
	TestSuite.finish(self, int(fails > 0))


func fail(reason: String) -> void:
	fails += 1
	print("PERF14E6 FAIL ", reason)


func _probe_city() -> void:
	while not game.ready_done:
		await frames(5)
	game.can_save = false
	game.settings["autosave"] = false
	game.settings["quality_user"] = true
	game.weather.force = 0.0
	game.weather.left_h = 0.0
	game.weather.level = 0.0
	game.weather.wet = 0.0
	game.hud.set_speed(0.0)
	game.hud.visible = false
	game.rig.cine = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	vp = get_viewport().get_viewport_rid()
	await _perf13_wait_icons()
	while game._clock_busy or game._placement_running:
		await frames(1)
	if get_window().size != Vector2i(1920, 1080):
		fail("размер окна " + str(get_window().size))
	var views := _views(VIEWS_REGRESS if city_label == "owner" else CITY_VIEWS)
	print("PERF14E6 READY ", city_label, " buildings=", game.city.buildings.size(), " residents=", game.people.residents.size())
	for q: String in QUALITIES:
		_quality(q)
		print("PERF14E6 GFX ", city_label, " ", q, " lod=", get_viewport().mesh_lod_threshold,
			" scale=", get_viewport().scaling_3d_scale, " scale_mode=", get_viewport().scaling_3d_mode,
			" glow=", game.env.glow_enabled, " ssao=", game.env.ssao_enabled, " msaa=", get_viewport().msaa_3d)
		for view: Array in views:
			var label: String = view[0]
			_view(view)
			game._set_hour(9.0)
			await _sample(q, label, "base")
			if q == "verylow" and A.has("inventory"):
				_inventory_view(label)
				if label == "far":
					await _skin_probe(q, label)
	if A.has("inventory") or A.has("slots"):
		_prepare_compression()
	_freeze()
	for q: String in QUALITIES:
		_quality(q)
		for view: Array in views:
			_view(view)
			game._set_hour(9.0)
			await frames(SHOT_WAIT)
			var image: Image = await _snap()
			var basename := "%s_%s_%s" % [city_label, q, view[0]]
			_save_image(image, basename + "_golden")
	_unfreeze()
	await _full_shots(views)
	compressed_meshes.clear()
	compressed_batches.clear()
	surface_cache.clear()


func _matched_golden() -> void:
	var old: Node = game
	old.queue_free()
	await old.tree_exited
	await frames(12)
	boot_preset = "high"
	_boot("play")
	while not game.ready_done:
		await frames(5)
	game.can_save = false
	await _settle()
	while game._clock_busy or game._placement_running:
		await frames(1)
	_freeze()
	var shots := await _shots(QUALITIES, _views(VIEWS_REGRESS), "matched_golden")
	for key: String in shots:
		var name := key.replace("/", "_")
		var image: Image = shots[key]
		_save_image(image, "owner_" + name + "_matched_golden")
		_regress_image(key, image, Image.load_from_file(GOLDEN.path_join(name + ".png")), false)
	_unfreeze()


func _full_shots(views: Array) -> void:
	var water := _freeze_water()
	A["water"] = "1"
	_freeze()
	var grass_shader := preload("res://shaders/grass_carpet.gdshader")
	var grass_code := grass_shader.code
	grass_shader.code = grass_code.replace("TIME", "10.0")
	for node: Node3D in _hidden:
		if node is Decal:
			node.show()
	for q: String in QUALITIES:
		_quality(q)
		for view: Array in views:
			_view(view)
			game._set_hour(9.0)
			await frames(100)
			var basename := "%s_%s_%s" % [city_label, q, view[0]]
			var original: Image = await _snap()
			_save_image(original, basename + "_full")
			if A.has("slots") and q == "verylow":
				await _frustum_probe(basename, str(view[0]))
				if view[0] == "center":
					await _slot_probe(basename)
				elif view[0] == "far":
					await _fsr_probe()
			if compressed_batches.is_empty():
				continue
			_set_compressed(true)
			await _sample(q, str(view[0]), "compressed")
			_save_image(await _snap(), basename + "_compressed")
			_set_compressed(false)
			await _sample(q, str(view[0]), "frozen_repeat")
			_save_image(await _snap(), basename + "_repeat")
	grass_shader.code = grass_code
	for shader: Shader in water:
		shader.code = water[shader]
	A.erase("water")
	_unfreeze()


func _save_image(im: Image, name: String) -> void:
	var path := output.path_join(name + ".png")
	if im.save_png(path) == OK:
		print("PERF14E6 SHOT ", path)
	else:
		fail("не удалось записать " + path)


func _sample(q: String, label: String, kind: String) -> void:
	print("PERF14E6 SAMPLE ", city_label, " ", q, " ", label, " ", kind)
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var row := await _measure(city_label + "/" + q + "/" + label + "/" + kind)
	if float(row["gpu"]) <= 0.0:
		fail("нет замера GPU")
	samples.store_line("%s\t%s\t%s\t%s\t%.4f\t%.4f\t%.4f\t%d\t%d\t%d\t%d\t%d\t%.5f\t%.5f" % [
		city_label, q, label, kind, row["gpu"], row["p10"], row["frame"], row["vis_p"], row["vis_d"],
		row["sh_p"], row["sh_d"], row["people"], row["ppl"], row["anims"]])
	samples.flush()


func _group_nodes() -> Dictionary:
	var tag := {}
	var pool: Parts = game.parts
	for key: String in pool.groups:
		var name := key.get_slice("|", 0)
		for sub: Dictionary in pool.groups[key]["subs"]:
			tag[sub["mmi"]] = "foliage" if Parts.is_foliage(name) else "parts"
	for node: Node in game.far_near + game.far_forest:
		tag[node] = "foliage"
	for node: Node in game.chunk_nodes.values():
		tag[node] = "ground"
	return tag


func _category(node: GeometryInstance3D, tags: Dictionary) -> String:
	if tags.has(node):
		return tags[node]
	if node.name in [&"CityWater", &"RiverFar"] or node.name.begins_with("StreamFlow"):
		return "water"
	if node is MeshInstance3D and node.material_override == game.land_mat:
		return "horizon"
	if game.people.is_ancestor_of(node) or game.actors_root.is_ancestor_of(node):
		return "citizens"
	if game.grass.is_ancestor_of(node):
		return "foliage"
	return "other"


func _inventory_view(label: String) -> void:
	var tags := _group_nodes()
	var cam: Camera3D = game.rig.cam
	var planes := cam.get_frustum()
	var position := cam.global_position
	var current := get_viewport().mesh_lod_threshold
	var totals := {}
	for threshold: float in [4.0, current]:
		totals[threshold] = {}
		for group: String in GROUPS:
			totals[threshold][group] = PackedInt64Array([0, 0, 0, 0, 0, 0, 0, 0])
	for node: GeometryInstance3D in game.find_children("*", "GeometryInstance3D", true, false):
		if (not node.is_visible_in_tree() or node.get_viewport() != get_viewport()
				or node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY):
			continue
		var box := node.global_transform * (node.custom_aabb if node.custom_aabb != AABB() else node.get_aabb())
		if not Frustum._frustum_aabb(planes, box):
			continue
		if node.visibility_range_end > 0.0 and position.distance_to(box.get_center()) > node.visibility_range_end + node.visibility_range_end_margin:
			continue
		var mesh: Mesh
		var instances := 1
		var zero := 0
		var outside := 0
		var skinned := false
		if node is MultiMeshInstance3D:
			var mm: MultiMesh = node.multimesh
			if mm == null or mm.visible_instance_count == 0:
				continue
			instances = mm.instance_count if mm.visible_instance_count < 0 else mm.visible_instance_count
			mesh = mm.mesh
			if mesh == null:
				continue
			for i in instances:
				var pose := mm.get_instance_transform(i)
				if pose.basis == Basis.from_scale(Vector3.ZERO):
					zero += 1
				elif not Frustum._frustum_aabb(planes, node.global_transform * pose * mesh.get_aabb()):
					outside += 1
		elif node is MeshInstance3D:
			mesh = node.mesh
			skinned = node.get_skin_reference() != null
		if not mesh is ArrayMesh:
			continue
		var group := _category(node, tags)
		var surface_distance := (box.position - position).max(position - box.end).max(Vector3.ZERO).length()
		var projection := cam.get_camera_projection()
		var scale := node.global_basis.get_scale().abs()
		for threshold: float in totals:
			var error := 2.0 * threshold * surface_distance / (projection.x.x * get_viewport().get_visible_rect().size.x * node.lod_bias * scale[scale.max_axis_index()])
			var row: PackedInt64Array = totals[threshold][group]
			for surface: Array in _surfaces(mesh):
				var count: Vector2i = surface[0]
				var levels: Dictionary = surface[1]
				var chosen := false
				for edge: float in levels:
					if edge > error:
						break
					count = levels[edge]
					chosen = true
				row[0] += instances * count.x
				row[1] += instances * count.y
				row[2] += instances
				row[3] += instances if not levels.is_empty() else 0
				row[4] += instances if chosen else 0
				row[5] += zero * count.x
				row[6] += outside * count.x
				row[7] += instances * int(surface[2]) if skinned else 0
			totals[threshold][group] = row
	for threshold: float in totals:
		for group: String in GROUPS:
			var fields := PackedStringArray([city_label, label, str(threshold), group])
			for value: int in totals[threshold][group]:
				fields.append(str(value))
			geometry.store_line("\t".join(fields))
	geometry.flush()


func _surfaces(mesh: ArrayMesh) -> Array:
	var id := mesh.get_instance_id()
	if surface_cache.has(id):
		return surface_cache[id]
	var result := []
	var importer := ImporterMesh.from_mesh(mesh)
	for s in mesh.get_surface_count():
		if importer.get_surface_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var n := mesh.surface_get_array_len(s)
		var count := _index_counts(importer.get_surface_arrays(s)[Mesh.ARRAY_INDEX], n)
		var levels := {}
		for l in importer.get_surface_lod_count(s):
			levels[importer.get_surface_lod_size(s, l)] = _index_counts(importer.get_surface_lod_indices(s, l), n)
		result.append([count, levels, n])
	surface_cache[id] = result
	return result


static func _index_counts(indices: Variant, vertices: int) -> Vector2i:
	if indices == null or indices.is_empty():
		return Vector2i(int(vertices / 3.0), vertices)
	var seen := PackedByteArray()
	seen.resize(vertices)
	var unique := 0
	for i: int in indices:
		if seen[i] == 0:
			seen[i] = 1
			unique += 1
	return Vector2i(int(indices.size() / 3.0), unique)


func _prepare_compression() -> void:
	for key: String in game.parts.groups:
		var name := key.get_slice("|", 0)
		if not name.begins_with("SM_"):
			continue
		for sub: Dictionary in game.parts.groups[key]["subs"]:
			var mm: MultiMesh = sub["mm"]
			var mesh := mm.mesh as ArrayMesh
			if mesh == null or mesh.get_blend_shape_count() > 0:
				continue
			if not compressed_meshes.has(mesh):
				compressed_meshes[mesh] = _compressed(mesh, name)
			if compressed_meshes[mesh] != mesh:
				compressed_batches[mm] = mesh
	formats.flush()
	print("PERF14E6 COMPRESS ", city_label, " meshes=", compressed_meshes.size(), " batches=", compressed_batches.size())


func _compressed(mesh: ArrayMesh, model: String) -> ArrayMesh:
	var flag := Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES
	var packed: Array = mesh.get("_surfaces")
	var needs_compression := false
	for s in mesh.get_surface_count():
		var fmt := mesh.surface_get_format(s)
		var surface: Dictionary = packed[s]
		formats.store_line("%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d" % [city_label, model, s, fmt,
			int(bool(fmt & flag)), mesh.surface_get_array_len(s), surface.get("vertex_data", PackedByteArray()).size(),
			surface.get("attribute_data", PackedByteArray()).size(), surface.get("skin_data", PackedByteArray()).size()])
		needs_compression = needs_compression or not bool(fmt & flag)
	if not needs_compression:
		return mesh
	var result := _pack_attributes(mesh)
	if mesh.shadow_mesh != null:
		result.shadow_mesh = _pack_attributes(mesh.shadow_mesh)
	return result


static func _pack_attributes(mesh: ArrayMesh) -> ArrayMesh:
	var importer := ImporterMesh.from_mesh(mesh)
	var result := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var levels := {}
		for l in importer.get_surface_lod_count(s):
			levels[importer.get_surface_lod_size(s, l)] = importer.get_surface_lod_indices(s, l)
		result.add_surface_from_arrays(importer.get_surface_primitive_type(s), importer.get_surface_arrays(s), [], levels,
			mesh.surface_get_format(s) | Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
		result.surface_set_material(s, mesh.surface_get_material(s))
	result.custom_aabb = mesh.custom_aabb
	return result


func _set_compressed(on: bool) -> void:
	for mm: MultiMesh in compressed_batches:
		var original: ArrayMesh = compressed_batches[mm]
		mm.mesh = compressed_meshes[original] if on else original


func _skin_probe(q: String, label: String) -> void:
	await _sample(q, label, "skin_before")
	game.gfx.set_process(false)
	await _sample(q, label, "fixed_pose")
	game.gfx.set_process(true)
	await _sample(q, label, "skin_after")
	game.people.hide()
	await _sample(q, label, "no_people")
	game.people.show()


func _fsr_probe() -> void:
	var viewport := get_viewport()
	var original := viewport.scaling_3d_mode
	await _sample("verylow", "far", "fsr_before")
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	await _sample("verylow", "far", "bilinear")
	viewport.scaling_3d_mode = original
	await _sample("verylow", "far", "fsr_repeat")


func _slot_probe(basename: String) -> void:
	var pool := Parts.new()
	game.add_child(pool)
	var bp := Bp.new()
	bp.add("SM_Env_Tree_01", Vector3.ZERO)
	var pos := Vector3(206.0, game.land.height_at(206.0, 140.0), 140.0)
	var pose := Transform3D(Basis.IDENTITY, pos)
	var live := pool.place(bp, pose)
	var duplicates := []
	for i in 256:
		duplicates.append_array(pool.place(bp, pose))
	var g: Dictionary = live[0][0]
	var mm: MultiMesh = g["subs"][0]["mm"]
	var hidden := pool.hide_handles(live)
	if mm.visible_instance_count != 257 or not pool.is_hidden(live[0]):
		fail("скрытие первого места изменило живой хвост")
	pool.remove(duplicates)
	if mm.visible_instance_count != 0:
		fail("в пустом пуле ещё есть видимые места")
	pool.restore(hidden)
	if mm.visible_instance_count != 2 or pool.is_hidden(live[0]) or pool.count() != 1:
		fail("после возврата нужен оригинальный экземпляр и один нулевой")
	var reuse := pool.place(bp, pose.translated(Vector3(4.0, 0.0, 0.0)))
	if reuse[0][1] != duplicates.back()[1] or mm.visible_instance_count != 257:
		fail("сохраняются номера и порядок повторного выделения")
	var stale := pool.hide_handles(reuse)
	pool.remove(reuse)
	var replacement := pool.place(bp, pose.translated(Vector3(5.0, 0.0, 0.0)))
	pool.set_hidden(replacement, true)
	pool.restore(stale)
	if not pool.is_hidden(replacement[0]):
		fail("старый снимок восстановил освобождённое место")
	pool.set_hidden(replacement, false, pose)
	if pool.is_hidden(replacement[0]):
		fail("не вернулось дерево под призраком")
	pool.remove(replacement)
	Parts.trim_freed_slots = false
	pool._sync_draw_prefix(g)
	await _sample("verylow", "center", "slots_before")
	var before: Image = await _snap()
	_save_image(before, basename + "_slots_before")
	Parts.trim_freed_slots = true
	pool._sync_draw_prefix(g)
	await _sample("verylow", "center", "slots_after")
	var after: Image = await _snap()
	_save_image(after, basename + "_slots_after")
	if before.get_data() != after.get_data():
		fail("пиксели при сокращении хвоста " + city_label)
	pool.queue_free()
	await pool.tree_exited


func _frustum_probe(basename: String, label: String) -> void:
	var cam: Camera3D = game.rig.cam
	var planes := cam.get_frustum()
	var pairs := []
	var saved := 0
	var started := Time.get_ticks_usec()
	for node: GeometryInstance3D in _group_nodes():
		var mmi := node as MultiMeshInstance3D
		if mmi == null or not mmi.is_visible_in_tree():
			continue
		var mm: MultiMesh = mmi.multimesh
		if mm == null or not _static_materials(mmi, mm.mesh):
			continue
		var bounds := mmi.get_aabb()
		if not Frustum._frustum_aabb(planes, mmi.global_transform * bounds):
			continue
		var count := mm.instance_count if mm.visible_instance_count < 0 else mm.visible_instance_count
		if count < 2:
			continue
		var stride := 12 + 4 * int(mm.use_colors) + 4 * int(mm.use_custom_data)
		var keep := PackedInt32Array()
		for i in count:
			var pose := mmi.global_transform * mm.get_instance_transform(i)
			if Frustum._frustum_aabb(planes, (pose * mm.mesh.get_aabb()).grow(0.25)):
				keep.append(i)
		if keep.size() == count:
			continue
		var clipped := MultiMesh.new()
		clipped.transform_format = MultiMesh.TRANSFORM_3D
		clipped.use_colors = mm.use_colors
		clipped.use_custom_data = mm.use_custom_data
		clipped.mesh = mm.mesh
		clipped.instance_count = keep.size()
		clipped.custom_aabb = bounds
		var old_buffer := mm.buffer
		var buffer := PackedFloat32Array()
		for i in keep:
			buffer.append_array(old_buffer.slice(i * stride, (i + 1) * stride))
		if not buffer.is_empty():
			clipped.buffer = buffer
		pairs.append([mmi, mm, clipped])
		saved += count - keep.size()
	print("PERF14E6 FRUSTUM ", city_label, " ", label, " batches=", pairs.size(), " removed=", saved,
		" prepare_ms=", (Time.get_ticks_usec() - started) / 1000.0)
	await _sample("verylow", label, "frustum_before")
	var before: Image = await _snap()
	_save_image(before, basename + "_frustum_before")
	for pair: Array in pairs:
		(pair[0] as MultiMeshInstance3D).multimesh = pair[2]
	await _sample("verylow", label, "frustum")
	_save_image(await _snap(), basename + "_frustum")
	for pair: Array in pairs:
		(pair[0] as MultiMeshInstance3D).multimesh = pair[1]
	await _sample("verylow", label, "frustum_repeat")
	_save_image(await _snap(), basename + "_frustum_repeat")


static func _static_materials(node: MultiMeshInstance3D, mesh: Mesh) -> bool:
	if mesh == null or node.material_override != null or node.material_overlay != null:
		return false
	for s in mesh.get_surface_count():
		var mat := mesh.surface_get_material(s)
		if mat is BaseMaterial3D:
			if mat.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or mat.grow or mat.next_pass != null:
				return false
		elif not (mat is ShaderMaterial and mat.shader.resource_path == "res://shaders/foliage.gdshader" and mat.next_pass == null):
			return false
	return true
