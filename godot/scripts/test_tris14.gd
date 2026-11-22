extends "res://scripts/test_perf.gd"

const STAGE := "D:/CivCity/.work/stage7/perf14c2"
const CASES := {
	"base": [0.0, false, false, 0],
	"tile32": [32.0, false, false, 0], "tile48": [48.0, false, false, 0], "tile64": [64.0, false, false, 0],
	"lod": [0.0, true, false, 0], "small": [0.0, false, false, 1], "proxy": [0.0, false, false, 2],
}

var _lod_models := {}
var _heavy_groups := {}
var _case_started := 0
var _shot_dir := ""


func _ready() -> void:
	Parts.profile_place = true
	var first := "base"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("sets="):
			first = arg.substr(5).get_slice(",", 0)
	_configure(first)
	super._ready()


func _configure(label: String) -> void:
	_case_started = Time.get_ticks_usec()
	if label.begins_with("base"):
		Parts.detail_config = null
		return
	var params: Array = CASES.get(label, [])
	if params.is_empty():
		var flags := label.split("-", false)
		var size := float(label.substr(4) if label.begins_with("tiny") else label.get_slice("-", 1))
		params = [size, label.begins_with("all") or flags.has("lod"), label.begins_with("tiny") or flags.has("tiny"),
			2 if flags.has("proxy") else 1 if flags.has("small") else 0]
	var detail := Parts.Detail.new()
	detail.tile_m = params[0]
	detail.lods = params[1]
	detail.tiny = params[2]
	detail.shadows = params[3]
	if label.begins_with("focus-"):
		detail.area_keys = _heavy_groups
		if detail.area_keys.is_empty():
			fail("cost filter did not select any groups")
	Parts.detail_config = detail


func fail(message: String) -> void:
	fails += 1
	print("TRIS14 FAIL ", message)


func _run(mode: String) -> void:
	if mode == "regress" and A.has("mode"):
		await super._run(mode)
		return
	if city_src.is_empty():
		fail("owner city missing")
		_done()
		return
	_shot_dir = A.get("shots", STAGE + "/shots")
	var cases: PackedStringArray = str(A.get("sets", "base,tile32,tile48,tile64,lod,tiny48,small,proxy,all-48-small")).split(",", false)
	if cases.is_empty() or cases[0] != "base":
		fail("start with base to identify the most expensive models")
		_done()
		return
	for label: String in cases:
		if label != "base":
			var old: Node = game
			old.queue_free()
			await old.tree_exited
			await frames(15)
			_configure(label)
			var next := Parts.detail_config
			if next != null and (next.lods or next.shadows == 2) and Parts.Detail.prepared.is_empty():
				var before := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
				await _prepare_geometry()
				var after := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
				print("TRIS14 CACHE added_mib=%.2f" % (float(after - before) / 1048576.0))
			_case_started = Time.get_ticks_usec()
			_boot("play")
		await _ready_game()
		var pool: Parts = game.parts
		var detail := pool.detail
		print("TRIS14 READY %s %s %s buildings=%d boot_ms=%.1f place_total_ms=%.2f place_max_ms=%.2f place_frame_max_ms=%.2f extra_tiles=%d" % [
			label, RenderingServer.get_video_adapter_name(), get_window().size, game.city.buildings.size(), (Time.get_ticks_usec() - _case_started) / 1000.0,
			pool.place_usec / 1000.0, pool.max_place_usec / 1000.0, pool.max_place_frame_usec / 1000.0, 0 if detail == null else detail.tiles])
		if label == "base":
			await _inventory()
		await _measure_case(label)
		await _capture_case(label)
		if detail != null and detail.tile_m > 0.0:
			_check_slots(detail)
	_done()


func _ready_game() -> void:
	while not game.ready_done:
		await frames(5)
	game.can_save = false
	game.settings["autosave"] = false
	game.settings["quality_user"] = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _perf13_wait_icons()
	vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	Engine.max_fps = 0


func _measure_case(label: String) -> void:
	game.hud.set_speed(float(A.get("speed", "0")))
	game.rig.cine = true
	for q: String in PRESETS:
		_quality(q)
		await frames(4)
		RenderingServer.viewport_set_measure_render_time(vp, true)
		for view: Array in _views(VIEWS_REGRESS):
			_view(view)
			game._set_hour(9.0)
			var key := q + "/" + String(view[0])
			var r := await _measure("T14 %s %s" % [label, key])
			if float(r["gpu"]) <= 0.0:
				fail("GPU timing unavailable for " + label + "/" + key)
			print("TRIS14 SAMPLE %s %s gpu=%.3f rcpu=%.3f dc=%d shdc=%d vis=%d sh=%d vram=%.2f tex=%d max=%.2f" % [
				label, key, r["gpu"], r["rcpu"], r["vis_d"], r["sh_d"], r["vis_p"], r["sh_p"],
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0, r["tex"], r["max"]])


func _capture_case(label: String) -> void:
	var dir := _shot_dir.path_join(label)
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		fail("cannot create shots folder " + dir)
		return
	_freeze()
	var counts := {}
	for q: String in PRESETS:
		_quality(q)
		for v: Array in _views(VIEWS_REGRESS):
			_view(v)
			game._set_hour(9.0)
			await frames(int(A.get("shot_wait", str(SHOT_WAIT))))
			await _shot(dir.path_join(q + "_" + String(v[0]) + ".png"))
			if q in ["high", "verylow"] and v[0] != "wide":
				_count_parts(label, q + "/" + String(v[0]), counts)
	_quality("high")
	_view(["close", 205.0, 140.0, 30.0, 35.0, 22.0])
	game._set_hour(9.0)
	await frames(100)
	await _shot(dir.path_join("high_close.png"))
	game._set_hour(22.0)
	await frames(100)
	await _shot(dir.path_join("high_night.png"))
	_unfreeze()


func _count_parts(label: String, key: String, counts: Dictionary) -> void:
	var camera: Camera3D = game.rig.cam
	var camera_pos := camera.global_position
	var viewport := get_viewport()
	var proj := camera.get_camera_projection()
	var scale := float(ProjectSettings.get_setting("rendering/scaling_3d/scale", 1.0))
	var factor := 2.0 * viewport.mesh_lod_threshold / (proj.x.x * scale * viewport.get_visible_rect().size.x)
	var planes := camera.get_frustum()
	var total := 0
	var no_lod := 0
	var ranged := 0
	var proxies := 0
	var groups: Dictionary = game.parts.groups
	for group: String in groups:
		var g: Dictionary = groups[group]
		for sub: Dictionary in g["subs"]:
			var mmi: MultiMeshInstance3D = sub["mmi"]
			var mm: MultiMesh = sub["mm"]
			var n := mm.visible_instance_count
			if n < 0:
				n = mm.instance_count
			if n == 0 or not mmi.is_visible_in_tree():
				continue
			if mmi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
				proxies += 1
				continue
			var bounds := mmi.global_transform * (mmi.custom_aabb if mmi.custom_aabb != AABB() else mmi.get_aabb())
			if not _frustum_aabb(planes, bounds):
				continue
			if mmi.visibility_range_end > 0.0 and bounds.get_center().distance_to(camera_pos) > mmi.visibility_range_end + mmi.visibility_range_end_margin:
				if group.begins_with("SM_Prop_"):
					ranged += n
				continue
			var mesh := mm.mesh as ArrayMesh
			if mesh == null:
				continue
			var id := mesh.get_instance_id()
			if not counts.has(id):
				counts[id] = _surface_counts(mesh)
			var error := (bounds.position - camera_pos).max(camera_pos - bounds.end).max(Vector3.ZERO).length() * factor / mmi.lod_bias
			for surface: Array in counts[id]:
				var tris: int = surface[0]
				for level: Array in surface[1]:
					if float(level[0]) > error:
						break
					tris = level[1]
				no_lod += n * int(surface[0])
				total += n * tris
	print("TRIS14 PARTS %s %s vis_est=%d raw=%d offscreen_props=%d proxies=%d" % [label, key, total, no_lod, ranged, proxies])


static func _surface_counts(mesh: ArrayMesh) -> Array:
	var info: Array = mesh.get("_surfaces")
	var result := []
	for surface: Dictionary in info:
		if int(surface["primitive"]) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var vertices: int = surface["vertex_count"]
		var lods: Array = surface.get("lods", [])
		var rows := []
		var stride := 2 if vertices <= 65536 else 4
		for i in range(0, lods.size(), 2):
			var indices: PackedByteArray = lods[i + 1]
			rows.append([lods[i], int(float(indices.size()) / (3.0 * stride))])
		rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		result.append([int(float(surface.get("index_count", vertices)) / 3.0), rows])
	return result


func _shot(path: String) -> void:
	var image: Image = await _snap()
	if image.save_png(path) == OK:
		print("TRIS14 SHOT ", path)
	else:
		fail("cannot save " + path)


func _inventory() -> void:
	if DirAccess.make_dir_recursive_absolute(_shot_dir) != OK:
		fail("cannot create inventory folder")
		return
	var file := FileAccess.open(_shot_dir.path_join("groups.tsv"), FileAccess.WRITE)
	if file == null:
		fail("cannot write groups.tsv")
		return
	file.store_line("group\tsub\tsurface\tlive\tvertices\ttriangles\tcenter_max\tfar_max\tlods\tcast\tdraws_max\tshadow_draws_per_split_max\tmaterial\talbedo\tnormal")
	var camera: Camera3D = game.rig.cam
	var views := _views(VIEWS_REGRESS)
	_view(views[0])
	await frames(4)
	var center := camera.get_frustum()
	_view(views[2])
	await frames(4)
	var far_view := camera.get_frustum()
	var rank := [{}, {}]
	var groups: Dictionary = game.parts.groups
	var batch := 0
	for key: String in groups:
		var g: Dictionary = groups[key]
		var n: int = int(g["used"]) - (g["free"] as Array).size()
		if n <= 0:
			continue
		var name := key.get_slice("|", 0)
		var subs: Array = g["subs"]
		var center_tris := 0
		var far_tris := 0
		for i in subs.size():
			var mmi: MultiMeshInstance3D = subs[i]["mmi"]
			var bounds := mmi.global_transform * mmi.get_aabb()
			var near_visible := _frustum_aabb(center, bounds)
			var far_visible := _frustum_aabb(far_view, bounds)
			var mesh := mmi.multimesh.mesh
			var importer := ImporterMesh.from_mesh(mesh) if mesh is ArrayMesh else null
			for s in mesh.get_surface_count():
				var vertices := 0
				var indices := 0
				if mesh is ArrayMesh:
					vertices = (mesh as ArrayMesh).surface_get_array_len(s)
					indices = (mesh as ArrayMesh).surface_get_array_index_len(s)
				else:
					var arrays := mesh.surface_get_arrays(s)
					vertices = arrays[Mesh.ARRAY_VERTEX].size()
					indices = arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null else 0
				var tris := int(float(indices if indices > 0 else vertices) / 3.0)
				center_tris += tris * n if near_visible else 0
				far_tris += tris * n if far_visible else 0
				var lod_count := 0 if importer == null else importer.get_surface_lod_count(s)
				var material := mesh.surface_get_material(s)
				var standard := material as BaseMaterial3D
				var albedo := standard.albedo_texture if standard != null else null
				var normal := standard.normal_texture if standard != null else null
				file.store_line("%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t1\t%d\t%s\t%s\t%s" % [key, i, s, n, vertices, tris,
					tris * n if near_visible else 0, tris * n if far_visible else 0, lod_count, mmi.cast_shadow,
					int(mmi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF),
					"%s:%s" % [material.get_class(), material.resource_name] if material != null else "",
					albedo.resource_path if albedo != null else "", normal.resource_path if normal != null else ""])
				if name.begins_with("SM_") and lod_count == 0 and tris >= 32:
					if near_visible:
						rank[0][name] = int(rank[0].get(name, 0)) + tris * n
					if far_visible:
						rank[1][name] = int(rank[1].get(name, 0)) + tris * n
		if n >= 24 and maxi(center_tris, far_tris) >= 12000 and Parts.Detail.tile_candidate(name):
			_heavy_groups[key] = true
		batch += 1
		if batch % 32 == 0:
			await frames(1)
	for view in rank.size():
		var totals: Dictionary = rank[view]
		var names := totals.keys()
		names.sort_custom(func(a: String, b: String) -> bool: return int(totals[a]) > int(totals[b]))
		for name: String in names.slice(0, 40):
			_lod_models[name] = true
			print("TRIS14 RANK %s %s %d" % ["center" if view == 0 else "far", name, totals[name]])
	print("TRIS14 FOCUS groups=%d" % _heavy_groups.size())
	for key: String in groups:
		var name := key.get_slice("|", 0)
		if Parts.Detail.shadow_candidate(name):
			_lod_models[name] = true


func _prepare_geometry() -> void:
	var cache := STAGE.path_join("lod_cache")
	if DirAccess.make_dir_recursive_absolute(cache) != OK:
		fail("cannot create LOD cache")
		return
	for name: String in _lod_models:
		var root := Synty.make(name)
		for node: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			var mesh := node.mesh as ArrayMesh
			if mesh != null and mesh.get_blend_shape_count() == 0:
				var stats := Parts.Detail.prepare(mesh, cache)
				if not stats.is_empty():
					print("TRIS14 LOD %s %s missing=%d generated=%d proxy=%d ms=%.2f" % [name, node.name,
						stats["missing"], stats["with_lod"], int(stats["proxy"]), float(stats["us"]) / 1000.0])
				await frames(1)
		root.free()


func _check_slots(settings: Parts.Detail) -> void:
	var pool := Parts.new()
	pool.detail = Parts.Detail.new()
	pool.detail.tile_m = settings.tile_m
	add_child(pool)
	var bp := Bp.new()
	bp.add("SM_Prop_Vase_03", Vector3.ZERO)
	var a := pool.place(bp, Transform3D.IDENTITY)
	var b := pool.place(bp, Transform3D(Basis.IDENTITY, Vector3(settings.tile_m * 0.75, 1, 0)))
	var c := pool.place(bp, Transform3D(Basis.IDENTITY, Vector3(settings.tile_m * 1.5, 1, 0)))
	if not is_same(a[0][0], b[0][0]) or is_same(a[0][0], c[0][0]):
		fail("compact or distant group has the wrong tile")
	var saved := pool.hide_handles(c)
	if not pool.is_hidden(c[0]):
		fail("hide did not reach tile")
	pool.restore(saved)
	if pool.is_hidden(c[0]):
		fail("restore did not reach tile")
	pool.remove(c)
	var d := pool.place(bp, Transform3D(Basis.IDENTITY, Vector3(settings.tile_m * 1.5, 3, 0)))
	if d[0][1] != c[0][1] or pool.is_hidden(d[0]) or pool.count() != 3:
		fail("freed slot did not return to the right tile")
	pool.queue_free()


static func _frustum_aabb(planes: Array[Plane], box: AABB) -> bool:
	for plane: Plane in planes:
		var nearest := box.position
		if plane.normal.x < 0.0:
			nearest.x += box.size.x
		if plane.normal.y < 0.0:
			nearest.y += box.size.y
		if plane.normal.z < 0.0:
			nearest.z += box.size.z
		if plane.is_point_over(nearest):
			return false
	return true


func _done() -> void:
	print("TRIS14 DONE fails=%d" % fails)
	get_tree().quit(0 if fails == 0 else 1)
