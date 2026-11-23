extends "res://scripts/test_perf14e3.gd"

const E4_ROOT := "D:/CivCity/.work/stage7/perf14e4"
const LIGHT_PROBES := ["no_receive", "no_pcss", "filter_low", "splits2", "no_ambient",
	"no_specular", "lambert", "no_decals", "no_clouds", "no_fog", "no_ssao", "no_msaa"]
const MATERIAL_PROBES := ["no_surf", "no_surf2", "no_surf3", "no_tiles", "no_far_grass", "no_noise", "rich_on",
	"no_grass_tex", "no_grass_noise", "no_lock_mix", "no_meadow_color"]
const CANDIDATE_CASES := ["F", "G", "H"]
const MODES := {"no_receive": "shadows_disabled", "no_ambient": "ambient_light_disabled",
	"no_specular": "specular_disabled", "lambert": "diffuse_lambert"}
var _e4_clusters: FileAccess
var _e4_shaders := {}
var _e4_settings := {}
var _e4_uniforms := {}
var _e4_report: FileAccess


func _run(_mode: String) -> void:
	shot_dir = str(A.get("out", E4_ROOT.path_join("shots")))
	if DirAccess.make_dir_recursive_absolute(shot_dir) != OK or RenderingServer.get_current_rendering_method() != "forward_plus":
		fail("нужны папка снимков и Forward+")
		_e4_done()
		return
	sweep = FileAccess.open(shot_dir.path_join("samples.tsv"), FileAccess.WRITE)
	_e4_clusters = FileAccess.open(shot_dir.path_join("clusters.tsv"), FileAccess.WRITE)
	_e4_report = FileAccess.open(shot_dir.path_join("geometry.tsv"), FileAccess.WRITE)
	if sweep == null or _e4_clusters == null or _e4_report == null:
		fail("не удалось открыть TSV")
		_e4_done()
		return
	sweep.store_line("city\tquality\tview\tcase\tgpu_ms\tgpu_p10_ms\tprep_ms\tframe_ms\tdraws\tshadow_draws\tvram_mib")
	_e4_clusters.store_line("city\tquality\tview\tkind\tall\tvisible\tprojected\tground_layer\tmean_per_tile\tmax_per_tile")
	_e4_report.store_line("city\tquality\tblock\tmeshes\tmultimeshes\tbuffer_mib\tmesh_surface_mib\ttexture_mib\tvram_mib")
	if not A.has("warm"):
		A["warm"] = "40"
	if not A.has("n"):
		A["n"] = "38"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	print("PERF14E4 GPU ", RenderingServer.get_video_adapter_name(), " | Forward+")
	var cities := str(A.get("cities", "owner,new")).split(",", false)
	var blocks := str(A.get("sets", "probes")).split(",", false)
	var first := true
	for city: String in cities:
		if city == "owner" and not FileAccess.file_exists(OWNER):
			fail("нет сохранения владельца")
			continue
		if city == "owner" and city_src.is_empty():
			if DirAccess.copy_absolute(OWNER, GamePaths.save_dir().path_join("city.json")) != OK:
				fail("не удалось скопировать город владельца")
				continue
		for block: String in blocks:
			var geometry_case := block.trim_suffix("_original")
			Game.perf14_share_meshes = not block.ends_with("_original")
			if not first or (city == "owner") != (not city_src.is_empty()) or geometry_case in ["B", "C"]:
				await _reload(city, geometry_case)
			first = false
			await _e4_bench(city, block)
	_e4_done()


func fail(reason: String) -> void:
	fails += 1
	print("PERF14E4 FAIL ", reason)


func _e4_done() -> void:
	for file: FileAccess in [sweep, _e4_clusters, _e4_report]:
		if file != null:
			file.close()
	print("PERF14E4 DONE fails=", fails)
	get_tree().quit(0 if fails == 0 else 1)


func _e4_bench(city: String, block: String) -> void:
	while not game.ready_done:
		await frames(5)
	game.can_save = false
	game.settings["autosave"] = false
	game.settings["quality_user"] = true
	var weather: Weather = game.weather
	if weather != null:
		weather.force = 0.0
		weather.left_h = 0.0
		weather.level = 0.0
		weather.wet = 0.0
	game.hud.set_speed(0.0)
	game.rig.cine = true
	game._set_hour(9.0)
	await _perf13_wait_icons()
	vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	print("PERF14E4 READY ", city, " ", block, " ", get_window().size, " buildings=", game.city.buildings.size())
	if get_window().size != Vector2i(1920, 1080):
		fail("ожидалось окно 1920×1080")
		return
	var views := _views(VIEWS_REGRESS if city == "owner" else NEW_VIEWS)
	for q: String in str(A.get("q", "high,verylow")).split(",", false):
		_quality(q)
		await frames(16)
		_e4_save_settings(q)
		for v: Array in views:
			_view(v)
			game._set_hour(9.0)
			await frames(8)
			if block == "probes" or (block == "candidates" and A.has("cluster_frames")):
				_e4_inventory(city, q, v[0])
			if block == "candidates" and q == "high" and A.has("cluster_frames"):
				await _e4_cluster_frame(city, v[0])
			var cases := _e4_cases(block, q)
			for key: String in cases:
				_e4_apply(key)
				if key == "F":
					await _e4_wait_bake(city, q)
				await _record(city, q, v[0], key)
				if key == "F" and q == "verylow" and v[0] == "far" and A.has("edits"):
					await _e4_bake_edits(city)
			_e4_apply("base")
		_e4_memory(city, q, block)
		if block == "candidates":
			await _e4_capture(city, views, q, ["base", "F", "G", "H"])
		elif A.has("geometry_shots") and block not in ["low_masks", "grass_cost", "probes"]:
			await _e4_capture(city, [views.back()], q, [block])


func _e4_cases(block: String, q: String) -> Array[String]:
	var cases: Array[String] = []
	if block == "probes":
		cases.append_array(["base", "before_wins", "flat_lit", "flat_unlit"])
		for key: String in LIGHT_PROBES:
			cases.append(key)
			cases.append("flat_" + key)
		if q == "verylow":
			cases.append_array(MATERIAL_PROBES)
		cases.append_array(["flat_lit", "base"])
	elif block == "low_masks":
		if q == "verylow":
			cases.append_array(["mask_base", "no_surf", "mask_base"])
	elif block == "grass_cost":
		if q == "verylow":
			cases.append_array(["grass_base", "no_grass_tex", "no_grass_noise", "no_lock_mix", "no_meadow_color", "grass_base"])
	elif block == "candidates":
		cases.append("base")
		cases.append_array(CANDIDATE_CASES)
		cases.append("base")
	else:
		cases.append(block)
	return cases


func _e4_save_settings(q: String) -> void:
	var sun: DirectionalLight3D = game.sun
	var low := Gfx.is_low(q)
	_e4_settings = {
		"pcss": sun.light_angular_distance, "splits": sun.directional_shadow_mode,
		"filter": RenderingServer.SHADOW_QUALITY_SOFT_LOW if low else RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
		"fog": game.env.fog_enabled, "ssao": game.env.ssao_enabled, "msaa": get_viewport().msaa_3d,
		"rich": not low, "decals": [],
	}
	for node: Decal in game.find_children("*", "Decal", true, false):
		if node.get_viewport() == get_viewport() and node.visible:
			_e4_settings["decals"].append(node)
	var mat: ShaderMaterial = game.land_mat
	_e4_uniforms.clear()
	for uniform: Dictionary in Game.land_shader(false).get_shader_uniform_list():
		var name: String = uniform["name"]
		var value: Variant = mat.get_shader_parameter(name)
		if value != null:
			_e4_uniforms[name] = value


func _e4_apply(key: String) -> void:
	var flat := key.begins_with("flat_")
	var op := key.trim_prefix("flat_") if flat else key
	var sun: DirectionalLight3D = game.sun
	sun.light_angular_distance = 0.0 if op == "no_pcss" else float(_e4_settings["pcss"])
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if op == "splits2" else int(_e4_settings["splits"])
	RenderingServer.directional_soft_shadow_filter_set_quality(maxi(0, int(_e4_settings["filter"]) - 1) if op == "filter_low" or (op == "H" and int(_e4_settings["filter"]) == RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM) else int(_e4_settings["filter"]))
	game.env.fog_enabled = op != "no_fog" and bool(_e4_settings["fog"])
	game.env.ssao_enabled = op != "no_ssao" and bool(_e4_settings["ssao"])
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if op == "no_msaa" else int(_e4_settings["msaa"])
	for node: Decal in _e4_settings["decals"]:
		if is_instance_valid(node):
			node.visible = op != "no_decals" and (op != "no_clouds" or node.get_parent() != game.clouds)
	var mat: ShaderMaterial = game.land_mat
	var shader := _e4_shader(op, flat)
	if shader != mat.shader:
		_replace_shader(mat, shader, _e4_uniforms)
	mat.set_shader_parameter("rich", op == "rich_on" or bool(_e4_settings["rich"]))
	if op == "F":
		game.prepare_ground_bake()
	if game.land_bake != null:
		game.land_bake.enabled = op == "F"
		if op == "F":
			game.land_bake.bind_material()


func _e4_wait_bake(city: String, q: String) -> void:
	if game.land_bake == null:
		fail("нет запекания")
		return
	var bake: Node = game.land_bake
	var start := int(bake.completed)
	await frames(2)
	var frames_waited := 0
	var frame_peak := 0.0
	var previous := Time.get_ticks_usec()
	while bake.busy() and frames_waited < 4000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		frame_peak = maxf(frame_peak, (now - previous) / 1000.0)
		previous = now
		frames_waited += 1
	if bake.failed or bake.busy():
		fail("запекание не закончено")
	elif int(bake.completed) > start:
		print("PERF14E4 BAKE ", city, " ", q, " tiles=", int(bake.completed) - start,
			" frames=", frames_waited, " CPU max=", bake.max_cpu_usec / 1000.0,
			" ms, bake GPU max=", bake.max_bake_gpu_ms, " ms, frame max=", frame_peak, " ms")


func _e4_bake_edits(city: String) -> void:
	var bake: Node = game.land_bake
	var land: Land = game.land
	var cell := land.cell(Vector2(195.0, 165.0))
	var index := land.idx(cell.x, cell.y)
	var completed: int = bake.completed
	var original_kind: int = land.kind[index]
	var original_deco: int = land.deco[index]
	land.kind[index] = Land.Kind.PLAZA if original_kind != Land.Kind.PLAZA else Land.Kind.ROAD
	land.set_deco(index, original_deco ^ Land.UP)
	land._mark(cell.x, cell.y, false, true)
	await _e4_wait_bake(city, "правка покрытия")
	var updated: bool = bake.completed > completed
	land.kind[index] = original_kind
	land.set_deco(index, original_deco)
	land._mark(cell.x, cell.y, false, true)
	await _e4_wait_bake(city, "возврат покрытия")
	if not updated:
		fail("изменение покрытия не обновило плитку")

	completed = bake.completed
	var month: float = game.seasons.force_m
	game.seasons.force_m = 11.9
	game.weather.wet = 0.6
	game.weather.force = 0.8
	await frames(12)
	var mat: ShaderMaterial = game.land_mat
	var season: Vector4 = mat.get_shader_parameter("season")
	var wet: float = mat.get_shader_parameter("wet")
	game.seasons.force_m = month
	game.weather.force = 0.0
	game.weather.wet = 0.0
	game.weather.level = 0.0
	await frames(4)
	if season.y < 0.9 or wet < 0.3 or bake.completed != completed:
		fail("сезон или мокрость изменились с пересборкой плиток либо не применились")
	else:
		print("PERF14E4 BAKE ", city, " сезон и мокрость применены, пересчётов 0")


func _e4_shader(op: String, flat: bool) -> Shader:
	if op in ["F", "G"]:
		return Game.ground_shader(false, op == "F", op == "G")
	if op == "unlit":
		return _flat_probe("flat_unlit")
	if not MODES.has(op) and op not in MATERIAL_PROBES and op != "before_wins":
		return _flat_probe("flat_lit") if flat else Game.land_shader(false)
	var id := "%s/%s" % [op, flat]
	if _e4_shaders.has(id):
		return _e4_shaders[id]
	var source: String = _flat_probe("flat_lit").code if flat else Game.land_shader(false).code
	if op == "before_wins":
		source = "#define PERF14_E4_CONTROL\n" + source
	elif MODES.has(op):
		if op == "lambert":
			source = source.replace("diffuse_burley", "diffuse_lambert")
		elif op == "no_specular":
			source = source.replace("specular_schlick_ggx", "specular_disabled")
		else:
			source = source.replace("render_mode ", "render_mode %s, " % MODES[op])
	elif op in ["no_surf", "no_surf2", "no_surf3", "no_tiles"]:
		var re := RegEx.new()
		if op == "no_tiles":
			re.compile("texture\\(tile_\\w+, [^\\n;]+?\\)\\.rgb")
			source = re.sub(source, "vec3(0.23, 0.20, 0.15)", true)
			source = source.replace("texture(tex, uv).rgb", "vec3(0.23, 0.20, 0.15)")
			source = source.replace("texture(tex, vec2(-uv.y, uv.x) + vec2(0.37, 0.61)).rgb", "vec3(0.23, 0.20, 0.15)")
		else:
			re.compile("textureLod\\(%s, wpos\\.xz / map_size, 0\\.7\\)" % op.trim_prefix("no_"))
			# У surf альфа 1 означает нет утоптанной кромки.
			var neutral := "vec4(0.0, 0.0, 0.0, 1.0)" if op == "no_surf" else "vec4(0.0)"
			source = re.sub(source, neutral, true)
	elif op == "no_far_grass":
		source = source.replace("far_grass(wpos)", "far_g1")
	elif op == "no_noise":
		source = source.replace("return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);", "return 0.5;")
		source = source.replace("return fract((p.x + p.y) * p.z);", "return 0.5;")
	elif op in ["no_grass_tex", "no_grass_noise", "no_lock_mix", "no_meadow_color"]:
		if op in ["no_grass_tex", "no_meadow_color"]:
			source = source.replace("lum3(texture(g_tex_a, uv).rgb) / 0.165", "1.0")
		if op in ["no_grass_noise", "no_meadow_color"]:
			source = source.replace("texture(noise_tex, wp.xz / 230.0)", "vec4(0.5)")
			source = source.replace("texture(noise_tex, ROT_A * wp.xz / 67.0 + vec2(0.37, 0.71))", "vec4(0.5)")
		if op in ["no_lock_mix", "no_meadow_color"]:
			var re := RegEx.new()
			re.compile("if \\(lk > 0\\.0\\) c = pow\\([^;]+;")
			source = re.sub(source, "", true)
	var shader := Shader.new()
	shader.code = source
	_e4_shaders[id] = shader
	return shader


func _e4_inventory(city: String, q: String, view: String) -> void:
	var camera: Camera3D = game.rig.cam
	var planes := camera.get_frustum()
	var screen := get_viewport().get_visible_rect().size
	var pixels := screen * get_viewport().scaling_3d_scale
	var grid := Vector2i(ceili(pixels.x / 32.0), ceili(pixels.y / 32.0))
	var combined := PackedInt32Array()
	combined.resize(grid.x * grid.y)
	var visible_total := 0
	var projected_total := 0
	for kind: String in ["Decal", "OmniLight3D", "SpotLight3D", "AreaLight3D", "ReflectionProbe"]:
		var cells := PackedInt32Array()
		cells.resize(combined.size())
		var all := 0
		var visible := 0
		var projected := 0
		var land_count := 0
		for node: VisualInstance3D in game.find_children("*", kind, true, false):
			if node.get_viewport() != get_viewport():
				continue
			all += 1
			if not node.is_visible_in_tree():
				continue
			visible += 1
			if node is Decal and (node as Decal).cull_mask & Game.LAND_LAYER:
				land_count += 1
			var box := node.global_transform * node.get_aabb()
			if node is Decal:
				var half := (node as Decal).size * 0.5
				box = node.global_transform * AABB(-half, half * 2.0)
			var rect := _screen_box(camera, planes, box, screen)
			if rect.has_area():
				projected += 1
				_add_grid(cells, rect, screen, grid)
		for i in cells.size():
			combined[i] += cells[i]
		visible_total += visible
		projected_total += projected
		var stats := _grid_stats(cells)
		_e4_clusters.store_line("%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%.3f\t%d" % [
			city, q, view, kind, all, visible, projected, land_count, stats.x, int(stats.y)])
	var stats := _grid_stats(combined)
	_e4_clusters.store_line("%s\t%s\t%s\tall\t\t%d\t%d\t\t%.3f\t%d" % [
		city, q, view, visible_total, projected_total, stats.x, int(stats.y)])
	_e4_clusters.flush()


func _e4_cluster_frame(city: String, view: String) -> void:
	_index_scene()
	var hud_visible: bool = game.hud.visible
	var grade_visible := grade_rect != null and grade_rect.visible
	var env: Environment = game.env
	var tone := env.tonemap_mode
	var exposure := env.tonemap_exposure
	var glow := env.glow_enabled
	game.hud.hide()
	if grade_rect != null:
		grade_rect.hide()
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.glow_enabled = false
	var main_view := get_viewport()
	var debug := main_view.debug_draw
	main_view.debug_draw = Viewport.DEBUG_DRAW_CLUSTER_DECALS
	await frames(12)
	await _e4_snap(city, "cluster_decals", "high_" + view)
	main_view.debug_draw = debug
	env.tonemap_mode = tone
	env.tonemap_exposure = exposure
	env.glow_enabled = glow
	game.hud.visible = hud_visible
	if grade_rect != null:
		grade_rect.visible = grade_visible
	await frames(12)


func _e4_memory(city: String, q: String, block: String) -> void:
	var meshes := {}
	var multimeshes := {}
	for mmi: MultiMeshInstance3D in game.find_children("*", "MultiMeshInstance3D", true, false):
		if mmi.multimesh != null and mmi.multimesh.mesh != null:
			multimeshes[mmi.multimesh.get_rid()] = true
			meshes[mmi.multimesh.mesh.get_rid()] = mmi.multimesh.mesh
	var mesh_bytes := 0
	if block in ["memory_base", "B", "C", "B_original", "C_original"]:
		for mesh: Mesh in meshes.values():
			if mesh is ArrayMesh:
				for surface: Dictionary in mesh.get("_surfaces"):
					for channel: String in ["vertex_data", "attribute_data", "skin_data", "index_data"]:
						mesh_bytes += surface.get(channel, PackedByteArray()).size()
					for item: Variant in surface.get("lods", []):
						if item is PackedByteArray:
							mesh_bytes += item.size()
	_e4_report.store_line("%s\t%s\t%s\t%d\t%d\t%.2f\t%.2f\t%.2f\t%.2f" % [city, q, block,
		meshes.size(), multimeshes.size(), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED) / 1048576.0,
		mesh_bytes / 1048576.0,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0])
	_e4_report.flush()


func _e4_capture(city: String, views: Array, q: String, cases: Array) -> void:
	A["water"] = "1"
	_freeze()
	await frames(3)
	_index_scene()
	for shader: String in ["water", "pool_water", "stream_flow"]:
		_freeze_shader_time(shader)
	_e4_save_settings(q)
	for v: Array in views:
		_view(v)
		game._set_hour(9.0)
		for key: String in cases:
			_e4_apply(key)
			if key == "F":
				await _e4_wait_bake(city, q)
			await frames(int(A.get("shot_wait", "60")))
			await _e4_snap(city, key, q + "_" + v[0])
	_e4_apply("base")
	_restore()
	_unfreeze()
	game.hud.set_speed(0.0)
	game.rig.cine = true
	A.erase("water")


func _e4_snap(city: String, key: String, view: String) -> void:
	var dir := shot_dir.path_join(city).path_join(key)
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		fail("не удалось создать " + dir)
		return
	var path := dir.path_join(view + ".png")
	var image := await _snap()
	if image == null or image.get_size() != Vector2i(1920, 1080) or image.save_png(path) != OK:
		fail("не удалось снять кадр " + path)
	else:
		print("PERF14E4 SHOT ", path)
