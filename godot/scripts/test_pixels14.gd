extends "res://scripts/test_perf.gd"

const STAGE := "D:/CivCity/.work/stage7/perf14e"
const STAGE_E2 := "D:/CivCity/.work/stage7/perf14e2"
const NEW_VIEWS := "center:192:124:15:42:60,wide:192:140:15:50:130,far:192:160:15:55:240"
const LAYERS := "ground,backdrop,forests,meadow,grass,wheat,foliage,water,river_far,flow,foam,lakes,sea,clouds,sky,fog,grade,tonemap,dof,glow,ssao,msaa,fxaa,shadows,particles,smoke,birds,alpha"
const SHADERS := "land,grass_carpet,meadow_foliage,foliage,wheat,water,pool_water,stream_flow,meadow_rock,ground,grade,kit_reveal,cover,citizen_cloth,cat_fur,tint,meadow_spin"
const CANDIDATES := "land_fast,land_textures,land_all,water_fast,grade_fast,dof_near,ssao_medium,shadow_soft,combined"
const FAST := {"land_fast": "land", "land_textures": "land", "land_all": "land", "land_reuse": "land", "water_fast": "water", "grade_fast": "grade"}

var layers: Dictionary
var materials: Dictionary
var layer_members: Dictionary
var shader_cache := {}
var saved: Array[Callable] = []
var geometry: Array[GeometryInstance3D] = []
var grade_rect: ColorRect
var dof_quality := 0
var shadow_quality := 0
var sweep: FileAccess
var inventory: FileAccess
var lights: FileAccess
var variant_dir := ""
var shot_dir := ""
var golden_case := ""


func _run(mode: String) -> void:
	var renderer := RenderingServer.get_current_rendering_method()
	shot_dir = str(A.get("shots", STAGE_E2.path_join("shots").path_join(renderer)))
	variant_dir = str(A.get("variants", STAGE.path_join("variants")))
	if renderer != "forward_plus":
		fail("Forward+ required, got " + renderer)
		_finish()
		return
	if mode == "regress":
		if city_src != OWNER:
			fail("golden_s9d requires the owner city")
			_finish()
			return
		await _candidate_regress()
		_finish()
		return
	if DirAccess.make_dir_recursive_absolute(shot_dir) != OK:
		fail("cannot create " + shot_dir)
		_finish()
		return
	sweep = FileAccess.open(shot_dir.path_join("samples.tsv"), FileAccess.WRITE)
	inventory = FileAccess.open(shot_dir.path_join("coverage.tsv"), FileAccess.WRITE)
	lights = FileAccess.open(shot_dir.path_join("lights.tsv"), FileAccess.WRITE)
	if sweep == null or inventory == null or lights == null:
		fail("cannot open measurement files")
		_finish()
		return
	sweep.store_line("renderer\tcity\tquality\tview\tcase\tgpu\tcpu\trcpu\tframe\tdraws\tshadow_draws\tprimitives\tvram_mib")
	inventory.store_line("city\tquality\tview\tclass\tcoverage_1pct\tcoverage_10pct\tgrid_mean\tgrid_max\tby_shader")
	lights.store_line("city\tquality\tview\thour\tregistered\tall\tvisible\tshadowed\tmin_range\tmax_range\tmax_world_neighbors\tmax_screen_tile\tgroups")
	print("PIXELS14 RENDERER ", renderer, " | ", RenderingServer.get_video_adapter_name())
	var label := "new" if city_src.is_empty() else "owner"
	if label == "new" and str(A.get("city", OWNER)) != "new":
		fail("owner save not found")
		_finish()
		return
	await _city(label, renderer)
	if label == "owner" and A.get("both", "1") == "1":
		var old: Node = game
		old.queue_free()
		await old.tree_exited
		await frames(12)
		city_src = ""
		_boot("new")
		await _city("new", renderer)
	_finish()


func _candidate_regress() -> void:
	while not game.ready_done:
		await frames(5)
	game.can_save = false
	game.settings["quality_user"] = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	vp = get_viewport().get_viewport_rid()
	await _perf13_wait_icons()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var total := 0
	for key: String in str(A.get("capture", "base,land_fast,land_textures,land_all,water_fast,grade_fast,combined")).split(",", false):
		golden_case = key
		A["out"] = shot_dir.path_join(key)
		print("PIXELS14 REGRESS ", key)
		await super._regress()
		_restore()
		print("PERF DONE fails=%d case=%s" % [fails, key])
		total += fails
		fails = 0
	golden_case = ""
	fails = total


func _quality(q: String) -> void:
	if golden_case != "":
		_restore()
	super._quality(q)
	if golden_case != "" and golden_case != "base":
		_index_scene()
		if not _switch(golden_case):
			fail("cannot apply %s on %s" % [golden_case, q])


func _city(label: String, renderer: String) -> void:
	while not game.ready_done:
		await frames(5)
	game.can_save = false
	game.settings["autosave"] = false
	game.settings["quality_user"] = true
	game.hud.set_speed(0.0)
	game.rig.cine = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _perf13_wait_icons()
	vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	if label == "new":
		# 25 секунд симуляции за один штатный игровой час.
		for i in 12:
			var hour: float = game.hour + 1.0
			game._set_hour(hour)
			await game._sim_hour(hour >= 24.0)
			await frames(8)
		print("PIXELS14 NEW sim_seconds=300")
	game._set_hour(9.0)
	await frames(20)
	print("PIXELS14 READY ", label, " ", get_window().size, " buildings=", game.city.buildings.size())
	if get_window().size != Vector2i(1920, 1080):
		fail("measurement window is not 1920×1080")
	var views := _views(VIEWS_REGRESS if label == "owner" else NEW_VIEWS)
	var qualities := str(A.get("q", "high,verylow")).split(",", false)
	for q: String in qualities:
		_quality(q)
		await frames(8)
		for view: Array in views:
			var name: String = view[0]
			_view(view)
			await frames(18)
			_index_scene()
			_coverage(label, q, name)
			_night_lights(label, q, name, 9)
			var cases: Array[String] = []
			if name != "center":
				cases.assign(str(A.get("layers", LAYERS)).split(",", false))
				for shader: String in str(A.get("shaders", SHADERS)).split(",", false):
					cases.append("shader_" + shader)
			cases.append_array(str(A.get("candidates", CANDIDATES)).split(",", false))
			await _series(renderer, label, q, name, cases)
			if q == "high" and name == "center":
				game._set_hour(22.0)
				await frames(12)
				_night_lights(label, q, name, 22)
				var night_cases: Array[String] = ["night_lights", "combined"]
				await _series(renderer, label, q, name + "_night", night_cases)
				game._set_hour(9.0)
		if A.get("shots_on", "1") == "1":
			await _captures(label, q, views)


func _series(renderer: String, label: String, q: String, view: String, cases: Array[String]) -> void:
	# Контроль до и после каждой группы. Возврат каждого свойства сразу после B.
	var taken := 0
	await _sample(renderer, label, q, view, "base")
	for key: String in cases:
		if not _switch(key):
			continue
		await _sample(renderer, label, q, view, key)
		_restore()
		taken += 1
		if taken % 5 == 0:
			await _sample(renderer, label, q, view, "base")
	if taken % 5 != 0:
		await _sample(renderer, label, q, view, "base")


func _sample(renderer: String, label: String, q: String, view: String, key: String) -> void:
	var r := await _measure("%s %s %s %s" % [label, q, view, key])
	var mem := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0
	sweep.store_line("%s\t%s\t%s\t%s\t%s\t%.3f\t%.3f\t%.3f\t%.3f\t%d\t%d\t%d\t%.2f" % [
		renderer, label, q, view, key, r["gpu"], r["cpu"], r["rcpu"], r["frame"], r["vis_d"], r["sh_d"], r["vis_p"], mem])
	sweep.flush()


func _index_scene() -> void:
	# Пробы здесь меняют штатные материалы и ищут их по пути исходного шейдера.
	if game.shadow_depth != null:
		game.shadow_depth.enabled = false
		game._update_shadow_depth()
	layers = {}
	materials = {}
	layer_members = {}
	geometry = []
	grade_rect = null
	for ch in game.chunk_nodes.values():
		_layer("ground", ch)
	for tree: Node3D in game.far_forest:
		_layer("forests", tree)
	if game.grass != null:
		_layer("grass", game.grass)
	if game.clouds != null:
		_layer("clouds", game.clouds)
	for group: String in game.parts.groups:
		var key := group.get_slice("|", 0).to_lower()
		var tag := ""
		if key in [CatCivic.WHEAT.to_lower(), CatCivic.WHEAT_DENSE.to_lower()]:
			tag = "wheat"
		elif key.contains("tree") or key.contains("bush") or key.contains("ivy"):
			tag = "foliage"
		elif key.contains("grass") or key.contains("meadow") or key.contains("flower"):
			tag = "meadow"
		if tag != "":
			for sub: Dictionary in game.parts.groups[group]["subs"]:
				_layer(tag, sub["mmi"])
	for n: Node in game.find_children("*", "", true, false):
		if n.get_viewport() != get_viewport():
			continue
		if n is ColorRect and (n as ColorRect).material == game.grade:
			grade_rect = n
			continue
		if n is Birds or n is RoofBirds:
			_layer("birds", n)
		if n is GPUParticles3D or n is CPUParticles3D:
			_layer("particles", n)
			if n.has_meta("smoke") or (n is GPUParticles3D and n.draw_pass_1 == Game._puff_quad() and n.amount == 7):
				_layer("smoke", n)
		if not n is GeometryInstance3D:
			continue
		var g := n as GeometryInstance3D
		geometry.append(g)
		_tag_geometry(g)


func _layer(key: String, node: Node3D) -> void:
	if layer_members.has(node) and key in layer_members[node]:
		return
	if not layers.has(key):
		layers[key] = []
	layers[key].append(node)
	if not layer_members.has(node):
		layer_members[node] = []
	layer_members[node].append(key)


func _tag_geometry(g: GeometryInstance3D) -> void:
	if g.material_override == game.land_mat and not layer_members.has(g):
		_layer("backdrop", g)
	match String(g.name):
		"CityWater":
			_layer("water", g)
			_layer("lakes", g)
		"RiverFar":
			_layer("water", g)
			_layer("river_far", g)
		"StreamFlow":
			_layer("water", g)
			_layer("flow", g)
	for mat: Material in _surface_materials(g):
		var shader := _shader_name(mat)
		if shader != "":
			if not materials.has(shader):
				materials[shader] = {}
			materials[shader][mat] = true
		match shader:
			"grass_carpet":
				_layer("meadow", g)
			"meadow_foliage", "foliage":
				if not layer_members.has(g):
					_layer("foliage", g)
			"pool_water":
				_layer("water", g)
				_layer("lakes", g)
			"water":
				if String(g.name) != "CityWater" and String(g.name) != "RiverFar":
					_layer("water", g)
					_layer("sea", g)
		if _material_class(mat) == "blend":
			_layer("alpha", g)


static func _surface_materials(g: GeometryInstance3D) -> Array[Material]:
	if g.material_override != null:
		return [g.material_override]
	var mesh: Mesh
	var result: Array[Material] = []
	if g is MeshInstance3D:
		mesh = g.mesh
	elif g is MultiMeshInstance3D and g.multimesh != null:
		mesh = g.multimesh.mesh
	elif g is GPUParticles3D:
		mesh = g.draw_pass_1
	elif g is CPUParticles3D:
		mesh = g.mesh
	if mesh != null:
		for i in mesh.get_surface_count():
			var mat := (g as MeshInstance3D).get_active_material(i) if g is MeshInstance3D else mesh.surface_get_material(i)
			result.append(mat)
	if g.material_overlay != null:
		result.append(g.material_overlay)
	return result


static func _shader_name(mat: Material) -> String:
	if mat is ShaderMaterial and mat.shader != null:
		return mat.shader.resource_path.get_file().get_basename()
	return ""


func _switch(key: String) -> bool:
	if key.contains("+"):
		var complete := true
		for member: String in key.split("+", false):
			complete = _switch(member) and complete
		if not complete:
			_restore()
		return complete
	var environment: Environment = game.env
	var attrs: CameraAttributesPractical = game.rig.attrs
	match key:
		"sky": return _set_probe(environment, "background_mode", Environment.BG_CLEAR_COLOR)
		"fog": return _set_probe(environment, "fog_enabled", false)
		"grade": return _set_probe(grade_rect, "visible", false)
		"tonemap": return _set_probe(environment, "tonemap_mode", Environment.TONE_MAPPER_LINEAR)
		"dof":
			var far := _set_probe(attrs, "dof_blur_far_enabled", false)
			var near := _set_probe(attrs, "dof_blur_near_enabled", false)
			return far or near
		"dof_near": return _set_probe(attrs, "dof_blur_near_enabled", false)
		"glow": return _set_probe(environment, "glow_enabled", false)
		"ssao": return _set_probe(environment, "ssao_enabled", false)
		"ssao_medium":
			if not environment.ssao_enabled:
				return false
			_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_MEDIUM)
			var original := int(ProjectSettings.get_setting("rendering/environment/ssao/quality", 3))
			saved.append(_ssao_quality.bind(original))
			return true
		"msaa": return _set_probe(get_viewport(), "msaa_3d", Viewport.MSAA_DISABLED)
		"fxaa": return _set_probe(get_viewport(), "screen_space_aa", Viewport.SCREEN_SPACE_AA_DISABLED)
		"shadows": return _set_probe(game.sun, "shadow_enabled", false)
		"shadow_soft":
			if not game.sun.shadow_enabled:
				return false
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
			var original := RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM if game.settings["quality"] == "high" else RenderingServer.SHADOW_QUALITY_SOFT_LOW
			saved.append(RenderingServer.directional_soft_shadow_filter_set_quality.bind(original))
			return true
		"night_lights": return _hide(game.night_lights)
		"foam": return _swap("water", "foam", false)
		"combined": return _switch("land_all+water_fast+grade_fast")
	if FAST.has(key):
		return _swap(FAST[key], key, false)
	if key.begins_with("shader_"):
		return _swap(key.trim_prefix("shader_"), key, true)
	return _hide(layers.get(key, []))


static func _ssao_quality(quality: int) -> void:
	var prefix := "rendering/environment/ssao/"
	RenderingServer.environment_set_ssao_quality(quality,
		bool(ProjectSettings.get_setting(prefix + "half_size", true)),
		float(ProjectSettings.get_setting(prefix + "adaptive_target", 0.5)),
		int(ProjectSettings.get_setting(prefix + "blur_passes", 2)),
		float(ProjectSettings.get_setting(prefix + "fadeout_from", 50.0)),
		float(ProjectSettings.get_setting(prefix + "fadeout_to", 300.0)))


func _hide(nodes: Array) -> bool:
	var changed := false
	for node in nodes:
		if is_instance_valid(node) and node.is_visible_in_tree():
			changed = _set_probe(node, "visible", false) or changed
	return changed


func _set_probe(target: Object, property: String, value: Variant) -> bool:
	if not is_instance_valid(target):
		return false
	var old: Variant = target.get(property)
	if old == value:
		return false
	saved.append(func():
		if is_instance_valid(target):
			target.set(property, old))
	target.set(property, value)
	return true


func _restore() -> void:
	while not saved.is_empty():
		var restore: Callable = saved.pop_back()
		restore.call()


func _swap(name: String, variant: String, unlit: bool) -> bool:
	var selected: Dictionary = materials.get(name, {})
	if name == "grade":
		selected = {game.grade: true}
	if selected.is_empty():
		return false
	var changed := false
	for mat: ShaderMaterial in selected:
		var original := mat.shader
		var replacement := _shader_variant(original, variant, unlit)
		if replacement == null:
			continue
		var params := {}
		for uniform: Dictionary in original.get_shader_uniform_list():
			var key: String = uniform["name"]
			params[key] = mat.get_shader_parameter(key)
		saved.append(_replace_shader.bind(mat, original, params))
		_replace_shader(mat, replacement, params)
		changed = true
	return changed


static func _replace_shader(mat: ShaderMaterial, shader: Shader, params: Dictionary) -> void:
	mat.shader = shader
	for key: String in params:
		if params[key] != null:
			mat.set_shader_parameter(key, params[key])


func _shader_variant(original: Shader, variant: String, unlit: bool) -> Shader:
	var key := original.resource_path + "|" + variant
	if shader_cache.has(key):
		return shader_cache[key]
	var code := original.code
	if variant == "foam":
		var start := code.find("\n", code.find("	vec3 col = mix(")) + 1
		var end := code.find("	ALBEDO", start)
		if start == 0 or end < 0:
			return null
		code = code.substr(0, start) + "	float foam = 0.0;\n" + code.substr(end)
	elif unlit:
		var start := code.find("void fragment()")
		if start < 0:
			return null
		var end := code.find("{", start)
		var depth := 1
		while depth > 0:
			end += 1
			if code[end] == "{":
				depth += 1
			elif code[end] == "}":
				depth -= 1
		var body := code.substr(start, end - start + 1)
		var flat := "void fragment() { ALBEDO = vec3(0.35);"
		if body.contains("ALPHA ="):
			flat += " ALPHA = 0.8;"
		if body.contains("ALPHA_SCISSOR_THRESHOLD"):
			flat += " ALPHA_SCISSOR_THRESHOLD = 0.5;"
		code = code.substr(0, start) + flat + " }" + code.substr(end + 1)
		if code.contains("shader_type canvas_item"):
			code = "shader_type canvas_item;\nvoid fragment() { COLOR = vec4(0.35, 0.35, 0.35, 1.0); }"
		elif not code.contains("unshaded"):
			code = code.replace("render_mode ", "render_mode unshaded, ") if code.contains("render_mode ") else code.replace("shader_type spatial;", "shader_type spatial;\nrender_mode unshaded;")
	else:
		var path := variant_dir.path_join(variant + ".gdshader")
		if not FileAccess.file_exists(path):
			path = STAGE_E2.path_join("variants").path_join(variant + ".gdshader")
		if not FileAccess.file_exists(path):
			return null
		code = FileAccess.get_file_as_string(path)
	var shader := Shader.new()
	shader.code = code
	shader_cache[key] = shader
	return shader


func _captures(label: String, q: String, views: Array) -> void:
	# Дневные виды повторяют маски штатного golden. Для воды отдельная пара с одинаковой фазой.
	var old_visible := {}
	for node: Node in game.find_children("*", "Node3D", true, false):
		old_visible[node] = node.visible
	_freeze()
	var cases: Array[String] = ["base"]
	cases.append_array(str(A.get("capture", CANDIDATES)).split(",", false))
	for view: Array in views:
		_view(view)
		game._set_hour(9.0)
		await frames(int(A.get("shot_wait", "120")))
		await _capture_cases(label, q + "_" + String(view[0]), cases)
	if q == "high":
		_view(views[0])
		game._set_hour(22.0)
		await frames(60)
		var night_cases: Array[String] = ["base", "combined"]
		await _capture_cases(label, q + "_night", night_cases)
	_unfreeze()
	for node in old_visible:
		if is_instance_valid(node) and node.visible != old_visible[node]:
			node.visible = old_visible[node]
	game.hud.set_speed(0.0)
	game.rig.cine = true
	game._set_hour(9.0)
	if q == "high":
		A["water"] = "1"
		_freeze()
		_view(views[2])
		_freeze_shader_time("water")
		_freeze_shader_time("stream_flow")
		await frames(60)
		await _save_shot(label, "base", "high_water")
		_restore()
		if _freeze_shader_time("water", "water_fast"):
			_freeze_shader_time("stream_flow")
			await frames(60)
			await _save_shot(label, "water_fast", "high_water")
			_restore()
		A.erase("water")
		_unfreeze()
		for node in old_visible:
			if is_instance_valid(node) and node.visible != old_visible[node]:
				node.visible = old_visible[node]
		game.hud.set_speed(0.0)
		game.rig.cine = true


func _freeze_shader_time(name: String, variant := "") -> bool:
	var changed := false
	for mat: ShaderMaterial in materials.get(name, {}):
		var original := mat.shader
		var shader := original if variant == "" else _shader_variant(original, variant, false)
		if shader == null:
			continue
		var frozen := Shader.new()
		frozen.code = shader.code.replace("TIME", "10.0")
		var params := {}
		for uniform: Dictionary in original.get_shader_uniform_list():
			var key: String = uniform["name"]
			params[key] = mat.get_shader_parameter(key)
		saved.append(_replace_shader.bind(mat, original, params))
		_replace_shader(mat, frozen, params)
		changed = true
	return changed


func _capture_cases(label: String, view: String, cases: Array[String]) -> void:
	for key: String in cases:
		if key != "base" and not _switch(key):
			continue
		await frames(24)
		await _save_shot(label, key, view)
		_restore()


func _save_shot(label: String, key: String, view: String) -> void:
	var dir := shot_dir.path_join(label).path_join(key)
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		fail("cannot create " + dir)
		return
	var path := dir.path_join(view + ".png")
	var shot: Image = await _snap()
	if shot == null or shot.is_empty() or shot.save_png(path) != OK:
		fail("cannot save " + path)
	else:
		print("PIXELS14 SHOT ", path)


func _coverage(label: String, q: String, view: String) -> void:
	var camera: Camera3D = game.rig.cam
	var grid := Vector2i(20, 12)
	var screen := get_viewport().get_visible_rect().size
	var planes := camera.get_frustum()
	var rows := {}
	for g in geometry:
		if not is_instance_valid(g) or not g.is_visible_in_tree() or g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		if g is MultiMeshInstance3D and (g.multimesh == null or g.multimesh.visible_instance_count == 0):
			continue
		var box: AABB = g.global_transform * g.get_aabb()
		if g.visibility_range_end > 0.0 and box.get_center().distance_to(camera.global_position) > g.visibility_range_end + g.visibility_range_end_margin:
			continue
		var rect := _screen_box(camera, planes, box, screen)
		if not rect.has_area():
			continue
		for mat: Material in _surface_materials(g):
			var bucket := _material_class(mat)
			if bucket == "":
				continue
			if not rows.has(bucket):
				var cells := PackedInt32Array()
				cells.resize(grid.x * grid.y)
				rows[bucket] = [0, 0, cells, {}]
			var row: Array = rows[bucket]
			var coverage := rect.get_area() / (screen.x * screen.y)
			if coverage >= 0.01:
				row[0] += 1
				var shader := _shader_name(mat)
				if shader == "":
					shader = "material"
				row[3][shader] = int(row[3].get(shader, 0)) + 1
			if coverage >= 0.10:
				row[1] += 1
			_add_grid(row[2], rect, screen, grid)
	for key: String in rows:
		var row: Array = rows[key]
		var bounds := _grid_stats(row[2])
		inventory.store_line("%s\t%s\t%s\t%s\t%d\t%d\t%.3f\t%d\t%s" % [label, q, view, key, row[0], row[1], bounds.x, int(bounds.y), JSON.stringify(row[3])])
	if is_instance_valid(grade_rect) and grade_rect.is_visible_in_tree():
		inventory.store_line("%s\t%s\t%s\tcanvas\t1\t1\t1.0\t1\t{\"grade\":1}" % [label, q, view])
	inventory.flush()


static func _material_class(mat: Material) -> String:
	if mat is BaseMaterial3D:
		match mat.transparency:
			BaseMaterial3D.TRANSPARENCY_DISABLED: return ""
			BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR: return "scissor"
			BaseMaterial3D.TRANSPARENCY_ALPHA_HASH: return "hash"
			_: return "blend"
	var shader := mat as ShaderMaterial
	if shader == null or shader.shader == null:
		return ""
	var code := shader.shader.code
	if code.contains("discard"):
		return "discard"
	if code.contains("ALPHA_SCISSOR_THRESHOLD"):
		return "scissor"
	return "blend" if code.contains("ALPHA =") else ""


func _night_lights(label: String, q: String, view: String, hour: int) -> void:
	var camera: Camera3D = game.rig.cam
	var screen := get_viewport().get_visible_rect().size
	var grid := Vector2i(ceili(screen.x / 16.0), ceili(screen.y / 16.0))
	var cells := PackedInt32Array()
	cells.resize(grid.x * grid.y)
	var planes := camera.get_frustum()
	var all: Array[Node] = game.find_children("*", "OmniLight3D", true, false)
	var visible: Array[OmniLight3D] = []
	var groups := {}
	var minimum := INF
	var maximum := 0.0
	var shadowed := 0
	var leaked := 0
	for node: OmniLight3D in all:
		if node.get_viewport() != get_viewport():
			continue
		var kind := "registered" if node in game.night_lights else String(node.get_parent().name)
		var entry: Array = groups.get(kind, [0, 0, 0])
		entry[0] += 1
		groups[kind] = entry
		if node.shadow_enabled:
			entry[2] += 1
			shadowed += 1
		if not node.is_visible_in_tree():
			continue
		if hour == 9 and kind == "registered":
			leaked += 1
		entry[1] += 1
		visible.append(node)
		minimum = minf(minimum, node.omni_range)
		maximum = maxf(maximum, node.omni_range)
		var radius := Vector3.ONE * node.omni_range
		var rect := _screen_box(camera, planes, AABB(node.global_position - radius, radius * 2.0), screen)
		_add_grid(cells, rect, screen, grid)
	if leaked > 0:
		fail("%d registered day lights visible at %s/%s/%s" % [leaked, label, q, view])
	var neighbors := 0
	for a: OmniLight3D in visible:
		var count := 0
		for b: OmniLight3D in visible:
			if a.global_position.distance_squared_to(b.global_position) < pow(a.omni_range + b.omni_range, 2.0):
				count += 1
		neighbors = maxi(neighbors, count)
	var upper := _grid_stats(cells)
	lights.store_line("%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%.2f\t%.2f\t%d\t%d\t%s" % [
		label, q, view, hour, game.night_lights.size(), all.size(), visible.size(), shadowed,
		0.0 if is_inf(minimum) else minimum, maximum, neighbors, int(upper.y), JSON.stringify(groups)])
	lights.flush()


static func _screen_box(camera: Camera3D, planes: Array[Plane], box: AABB, screen: Vector2) -> Rect2:
	var viewport := Rect2(Vector2.ZERO, screen)
	for plane: Plane in planes:
		var nearest := box.position
		if plane.normal.x < 0.0:
			nearest.x += box.size.x
		if plane.normal.y < 0.0:
			nearest.y += box.size.y
		if plane.normal.z < 0.0:
			nearest.z += box.size.z
		if plane.is_point_over(nearest):
			return Rect2()
	var lo := Vector2(INF, INF)
	var hi := -lo
	for i in 8:
		var corner := box.get_endpoint(i)
		if camera.is_position_behind(corner):
			return viewport
		var p := camera.unproject_position(corner)
		lo = lo.min(p)
		hi = hi.max(p)
	return Rect2(lo, hi - lo).intersection(viewport)


static func _add_grid(cells: PackedInt32Array, rect: Rect2, screen: Vector2, grid: Vector2i) -> void:
	if not rect.has_area():
		return
	var tile := screen / Vector2(grid)
	var lo := Vector2i((rect.position / tile).floor()).clamp(Vector2i.ZERO, grid)
	var hi := Vector2i((rect.end / tile).ceil()).clamp(Vector2i.ZERO, grid)
	for y in range(lo.y, hi.y):
		for x in range(lo.x, hi.x):
			cells[y * grid.x + x] += 1


static func _grid_stats(cells: PackedInt32Array) -> Vector2:
	var total := 0
	var peak := 0
	for count: int in cells:
		total += count
		peak = maxi(peak, count)
	return Vector2(float(total) / cells.size(), peak)


func fail(message: String) -> void:
	fails += 1
	print("PIXELS14 FAIL ", message)


func _finish() -> void:
	_restore()
	for file: FileAccess in [sweep, inventory, lights]:
		if file != null:
			file.close()
	print("PIXELS14 DONE fails=%d" % fails)
	get_tree().quit(0 if fails == 0 else 1)
