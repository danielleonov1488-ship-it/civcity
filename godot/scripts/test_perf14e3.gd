extends "res://scripts/test_pixels14.gd"

const ROOT := "D:/CivCity/.work/stage7/perf14e3"
const MATRIX := {
	"base": ["base", "flat_lit", "flat_unlit", "A", "D", "E", "base"],
	"B": ["B"], "C": ["C"], "all": ["all"],
}
const ALPHA_SAMPLES := [Vector3(1, 1, 1) / 3.0, Vector3(4, 1, 1) / 6.0,
	Vector3(1, 4, 1) / 6.0, Vector3(1, 1, 4) / 6.0]

var _mesh_rows: FileAccess
var _tile_rows: FileAccess
var _alpha_images := {}
var _flat := {}


func _run(_mode: String) -> void:
	if RenderingServer.get_current_rendering_method() != "forward_plus" or (city_src.is_empty() and A.get("city", OWNER) != "new"):
		fail("нужны Forward+ и сохранение владельца")
		_done_e3()
		return
	shot_dir = str(A.get("out", ROOT.path_join("shots")))
	if DirAccess.make_dir_recursive_absolute(shot_dir) != OK:
		fail("не удалось создать папку снимков")
		_done_e3()
		return
	sweep = FileAccess.open(shot_dir.path_join("samples.tsv"), FileAccess.WRITE)
	_mesh_rows = FileAccess.open(shot_dir.path_join("foliage_meshes.tsv"), FileAccess.WRITE)
	_tile_rows = FileAccess.open(shot_dir.path_join("foliage_tiles.tsv"), FileAccess.WRITE)
	if sweep == null or _mesh_rows == null or _tile_rows == null:
		fail("не удалось открыть TSV")
		_done_e3()
		return
	sweep.store_line("city\tquality\tview\tcase\tgpu_ms\tgpu_p10_ms\tprep_ms\tframe_ms\tdraws\tshadow_draws\tvram_mib")
	_mesh_rows.store_line("city\tquality\tcase\tzone\tmodel\tmesh\tpart\ttriangles\tlod_triangles_by_surface\talpha_card_m2\talpha_covered_m2")
	_tile_rows.store_line("city\tquality\tcase\tzone\tmodel\tpart\ttile_x\ttile_z\tinstances")
	if not A.has("n"):
		A["n"] = "56"
	if not A.has("warm"):
		A["warm"] = "25"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	print("PERF14E3 GPU ", RenderingServer.get_video_adapter_name(), " | Forward+")
	var cities := [("new" if city_src.is_empty() else "owner")]
	if A.get("both", "1") == "1":
		cities.append("owner" if city_src.is_empty() else "new")
	var first := true
	for city: String in cities:
		if city == "owner" and city_src.is_empty():
			var dst := GamePaths.save_dir().path_join("city.json")
			if DirAccess.copy_absolute(OWNER, dst) != OK:
				fail("не удалось скопировать город владельца")
				continue
		for block: String in str(A.get("sets", "base,B,C,all,base_repeat")).split(",", false):
			if not MATRIX.has(block) and block != "base_repeat":
				fail("неизвестный вариант " + block)
				continue
			if not first or block != "base":
				await _reload(city, block)
			first = false
			await _bench_city(city, block)
	_done_e3()


func _reload(city: String, block: String) -> void:
	var old: Node = game
	old.queue_free()
	await old.tree_exited
	layers.clear()
	materials.clear()
	layer_members.clear()
	geometry.clear()
	_alpha_images.clear()
	Parts.Detail.prepared.clear()
	await frames(12)
	Game.perf14_foliage = block in ["B", "all"]
	Game.perf14_parts = block in ["C", "all"]
	_boot("new" if city == "new" else "play")


func _bench_city(city: String, block: String) -> void:
	while not game.ready_done:
		await frames(5)
	game.can_save = false
	game.settings["autosave"] = false
	game.settings["quality_user"] = true
	# В новом городе погода случайна уже при загрузке. Для всех проб оставляем сухое утро.
	var weather: Weather = game.weather
	if weather != null:
		weather.force = 0.0
		weather.left_h = 0.0
		weather.level = 0.0
		weather.wet = 0.0
	game.hud.set_speed(0.0)
	game.rig.cine = true
	await _perf13_wait_icons()
	vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	print("PERF14E3 READY ", city, " ", block, " ", get_window().size,
		" buildings=", game.city.buildings.size(), " residents=", game.people.residents.size())
	if get_window().size != Vector2i(1920, 1080):
		fail("ожидалось окно 1920×1080")
		return
	var views := _views(VIEWS_REGRESS if city == "owner" else NEW_VIEWS)
	var qualities := str(A.get("q", "high,verylow")).split(",", false)
	for q: String in qualities:
		_quality(q)
		if block in ["base", "B"]:
			_foliage_inventory(city, q, block)
		for v: Array in views:
			_view(v)
			game._set_hour(9.0)
			var cases: Array = MATRIX.get(block, ["base_repeat"])
			for key: String in cases:
				_activate(key, q)
				await _record(city, q, v[0], key)
		_activate("base", q)
	if block == "base" and A.get("medium", "1") == "1":
		_quality("medium")
		for v: Array in views:
			_view(v)
			for key: String in ["base", "D", "base"]:
				_activate(key, "medium")
				await _record(city, "medium", v[0], key)
	if A.get("shots_on", "1") == "1":
		await _capture_frames(city, block, qualities, views)


func _view(v: Array) -> void:
	super._view(v)
	# Сравниваем готовый ковёр травы: при смене ракурса он обычно достраивается по кадрам.
	if game.grass != null:
		game.grass.fill_now()


func _activate(key: String, q: String) -> void:
	var use_ssao := key in ["D", "all"]
	var use_shadows := key in ["E", "all"]
	if use_ssao != Gfx.perf14_ssao or use_shadows != Gfx.perf14_shadows:
		Gfx.perf14_ssao = use_ssao
		Gfx.perf14_shadows = use_shadows
		_quality(q)
	var shader := _flat_probe(key) if key.begins_with("flat_") else Game.land_shader(key in ["A", "all"])
	var mat: ShaderMaterial = game.land_mat
	if shader != mat.shader:
		var params := {}
		# Берём список базовых параметров и при возврате с плоского пробника.
		for uniform: Dictionary in Game.land_shader(false).get_shader_uniform_list():
			var id: String = uniform["name"]
			params[id] = mat.get_shader_parameter(id)
		_replace_shader(mat, shader, params)


func _flat_probe(key: String) -> Shader:
	if not _flat.has(key):
		var source := Game.land_shader(false).code.split("void fragment()", false, 1)[0]
		if key == "flat_unlit":
			source = source.replace("render_mode cull_back", "render_mode unshaded, cull_back")
		var shader := Shader.new()
		shader.code = source + """
void fragment() {
	ALBEDO = vec3(0.15, 0.19, 0.06) * (1.0 - 0.28 * wet);
	float k = floor(kind + 0.5);
	if (sm2.y <= 0.5 && abs(wnrm.y) <= 0.5 && k == 1.0 && meadow_on && top_y - wpos.y < 0.14) {
		NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	}
	ROUGHNESS = mix(k == 3.0 ? 0.9 : 0.95, 0.32, wet);
	SPECULAR = mix(0.3, 0.55, wet);
}
"""
		_flat[key] = shader
	return _flat[key]


func _record(city: String, q: String, view: String, key: String) -> void:
	var r := await _measure("%s %s %s %s" % [city, q, view, key])
	var mib := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0
	if float(r["gpu"]) <= 0.0:
		fail("нет замера GPU для " + key)
	sweep.store_line("%s\t%s\t%s\t%s\t%.3f\t%.3f\t%.3f\t%.3f\t%d\t%d\t%.2f" % [
		city, q, view, key, r["gpu"], r["p10"], r["rcpu"], r["frame"], r["vis_d"], r["sh_d"], mib])
	sweep.flush()


func _capture_frames(city: String, block: String, qualities: PackedStringArray, views: Array) -> void:
	A["water"] = "1"
	_freeze()
	var cases: Array = ["base", "A", "D", "E"] if block == "base" else [block]
	for q: String in qualities:
		_quality(q)
		await frames(3)
		_index_scene()
		for shader: String in ["water", "pool_water", "stream_flow"]:
			_freeze_shader_time(shader)
		for v: Array in views:
			var view: String = v[0]
			if view == "wide":
				continue
			_view(v)
			game._set_hour(9.0)
			for key: String in cases:
				_activate(key, q)
				await frames(int(A.get("shot_wait", "90")))
				await _capture_e3(city, key, q + "_" + view)
		_restore()
		_activate("base", q)
	_unfreeze()
	A.erase("water")


func _capture_e3(city: String, key: String, view: String) -> void:
	var dir := shot_dir.path_join(city).path_join(key)
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		fail("не удалось создать " + dir)
		return
	var path := dir.path_join(view + ".png")
	var img := await _snap()
	if img == null or img.get_size() != Vector2i(1920, 1080) or img.save_png(path) != OK:
		fail("не удалось снять кадр 1920×1080 " + path)
	else:
		print("PERF14E3 SHOT ", path)


func _foliage_inventory(city: String, q: String, block: String) -> void:
	var models := {}
	var tiles := {}
	for key: String in game.parts.groups:
		var model := key.get_slice("|", 0)
		if not Parts.is_foliage(model):
			continue
		var group: Dictionary = game.parts.groups[key]
		var subs: Array = group["subs"]
		for i in subs.size():
			var mmi: MultiMeshInstance3D = subs[i]["mmi"]
			_tally(mmi, "map", model, i, models, tiles, group["free"])
	for zone: String in ["edge", "forest"]:
		var batches: Array = game.far_near if zone == "edge" else game.far_forest
		for mmi: MultiMeshInstance3D in batches:
			var model := str(mmi.get_meta("batch_model", ""))
			if Parts.is_foliage(model):
				_tally(mmi, zone, model, int(mmi.get_meta("batch_part", 0)), models, tiles, [])
	var prefix := "%s\t%s\t%s\t" % [city, q, block]
	for id: String in models:
		var row: Array = models[id]
		_mesh_rows.store_line(prefix + "%s\t%d\t%s\t%.5f\t%.5f" % [
			id, row[0], JSON.stringify(row[1]), row[2], row[3]])
	for id: String in tiles:
		_tile_rows.store_line(prefix + "%s\t%d" % [id, tiles[id]])
	_mesh_rows.flush()
	_tile_rows.flush()


func _tally(mmi: MultiMeshInstance3D, zone: String, model: String, part: int, models: Dictionary, tiles: Dictionary, free: Array) -> void:
	if not mmi.visible or mmi.multimesh == null or not mmi.multimesh.mesh is ArrayMesh:
		return
	var mm := mmi.multimesh
	var count := mm.instance_count if mm.visible_instance_count < 0 else mm.visible_instance_count
	if count <= free.size():
		return
	var mesh := mm.mesh as ArrayMesh
	var label := "%s\t%s\t%s\t%d" % [zone, model, mesh.resource_name, part]
	if not models.has(label):
		models[label] = _model_stats(mesh)
	var skip := {}
	for i: int in free:
		skip[i] = true
	for i in count:
		if skip.has(i):
			continue
		var p := (mmi.global_transform * mm.get_instance_transform(i)).origin
		var tile := "%s\t%s\t%d\t%d\t%d" % [zone, model, part, floori(p.x / 48.0), floori(p.z / 48.0)]
		tiles[tile] = int(tiles.get(tile, 0)) + 1


func _model_stats(mesh: ArrayMesh) -> Array:
	var importer := ImporterMesh.from_mesh(mesh)
	var lods := []
	var triangles := 0
	var cards := Vector2.ZERO
	for s in importer.get_surface_count():
		var levels := []
		if importer.get_surface_primitive_type(s) == Mesh.PRIMITIVE_TRIANGLES:
			var arr := importer.get_surface_arrays(s)
			var indices: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			triangles += (verts.size() if indices.is_empty() else indices.size()) / 3
			for i in importer.get_surface_lod_count(s):
				levels.append(importer.get_surface_lod_indices(s, i).size() / 3)
			cards += _card_area(mesh.surface_get_material(s), arr, verts, indices)
		lods.append(levels)
	return [triangles, lods, cards.x, cards.y]


func _card_area(mat: Material, arr: Array, verts: PackedVector3Array, indices: PackedInt32Array) -> Vector2:
	var tex: Texture2D
	var threshold := 0.4
	var opacity := 1.0
	var leaf_only := true
	if mat is BaseMaterial3D and mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		tex = mat.albedo_texture
		threshold = mat.alpha_scissor_threshold
		opacity = mat.albedo_color.a
	elif _shader_name(mat) == "meadow_foliage" and mat.get_shader_parameter("leaf_cut"):
		tex = mat.get_shader_parameter("leaf_tex")
		leaf_only = bool(mat.get_shader_parameter("leaf_only"))
	if tex == null or arr[Mesh.ARRAY_TEX_UV] == null:
		return Vector2.ZERO
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var colors: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var id := tex.get_instance_id()
	if not _alpha_images.has(id):
		var img := tex.get_image()
		if img != null and img.is_compressed() and img.decompress() != OK:
			img = null
		_alpha_images[id] = img
	var image: Image = _alpha_images[id]
	if image == null or image.is_empty():
		return Vector2.ZERO
	var area := Vector2.ZERO
	var n := verts.size() if indices.is_empty() else indices.size()
	for i in range(0, n - 2, 3):
		var a := i if indices.is_empty() else indices[i]
		var b := i + 1 if indices.is_empty() else indices[i + 1]
		var c := i + 2 if indices.is_empty() else indices[i + 2]
		var unit := (verts[b] - verts[a]).cross(verts[c] - verts[a]).length() * (0.5 / ALPHA_SAMPLES.size())
		for w: Vector3 in ALPHA_SAMPLES:
			if not leaf_only and (colors.is_empty() or colors[a].b * w.x + colors[b].b * w.y + colors[c].b * w.z < 0.5):
				continue
			var p := uv[a] * w.x + uv[b] * w.y + uv[c] * w.z
			var px := int(fposmod(p.x, 1.0) * image.get_width())
			var py := int(fposmod(p.y, 1.0) * image.get_height())
			area.x += unit
			if image.get_pixel(px, py).a * opacity >= threshold:
				area.y += unit
	return area


func fail(message: String) -> void:
	fails += 1
	print("PERF14E3 FAIL ", message)


func _done_e3() -> void:
	for file: FileAccess in [sweep, _mesh_rows, _tile_rows]:
		if file != null:
			file.close()
	print("PERF14E3 DONE fails=", fails)
	get_tree().quit(1 if fails else 0)
