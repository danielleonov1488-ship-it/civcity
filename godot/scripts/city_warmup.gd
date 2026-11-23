extends RefCounted

const EFFECTS := ["citizen_cloth", "foliage", "meadow_foliage", "wheat", "field_cover",
	"water", "stream_flow", "pool_water", "land", "grass_carpet", "cat_fur", "crowd",
	"cover", "tint", "outline", "outline_hull", "kit_reveal", "meadow_rock", "meadow_spin"]
static var _rendered := {}
static var _materials := {}


## Ссылки принадлежат только тому, кто ждёт загрузку: городу, карточке или переходу.
static func fetch(tree: SceneTree, paths: Dictionary) -> Dictionary:
	var pending: Array[String] = []
	var resources := {}
	var files := paths.keys()
	for start in range(0, files.size(), 8):
		for path: String in files.slice(start, start + 8):
			var cached := ResourceLoader.get_cached_ref(path)
			if cached:
				resources[path] = cached
			elif ResourceLoader.exists(path) and ResourceLoader.load_threaded_request(path) == OK:
				pending.append(path)
		while not pending.is_empty():
			await tree.process_frame
			_poll(pending, resources)
	return resources


static func _poll(pending: Array[String], resources: Dictionary) -> void:
	for i in range(pending.size() - 1, -1, -1):
		var path := pending[i]
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		var resource := ResourceLoader.load_threaded_get(path)
		if resource:
			resources[path] = resource
		pending.remove_at(i)


static func release_sources() -> void:
	Synty._scenes.clear()
	Meadow._scenes.clear()
	KitLib.release_sources()


static func models(bp: Bp, paths: Dictionary, textures := false) -> void:
	for part: Array in bp.parts:
		var name: String = part[0]
		if name.begins_with("#"):
			continue
		var path := model_path(name)
		if path != "":
			paths[path] = true
		if textures and not Gfx._tex_small and not (name.begins_with("M:") or name.begins_with("K:")):
			Synty.texture_paths(name, part[2], paths)


static func model_path(name: String) -> String:
	if name.begins_with("K:"):
		var file := name.substr(2).get_slice("/", 0)
		return KitLib.DIR + file + ".glb"
	if name.begins_with("M:"):
		Meadow._index()
		return Meadow._paths.get(Meadow._base(name), "")
	return Synty._paths.get(name, "")


## У картинок построек свой SubViewport. Здесь запускаем проходы городских шейдеров
## с текущим MSAA и тенями, пока над городом ещё виден экран загрузки.
static func render_effects(game: Node3D) -> void:
	var root := game.get_viewport()
	var city_sun: DirectionalLight3D = game.get("sun")
	var shadows := city_sun != null and city_sun.shadow_enabled
	await _render(game, root.msaa_3d, root.screen_space_aa, shadows)
	if root.msaa_3d != Viewport.MSAA_DISABLED or shadows:
		await _render(game, Viewport.MSAA_DISABLED, root.screen_space_aa, false)


static func _render(game: Node3D, msaa: Viewport.MSAA, aa: Viewport.ScreenSpaceAA, shadows: bool, repeat := false) -> void:
	var key := Vector3i(msaa, aa, int(shadows))
	if _rendered.has(key) and not repeat:
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128, 128)
	viewport.own_world_3d = true
	viewport.positional_shadow_atlas_size = 0
	viewport.msaa_3d = msaa
	viewport.screen_space_aa = aa
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	game.add_child(viewport)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 2, 7)
	viewport.add_child(camera)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.shadow_enabled = shadows
	viewport.add_child(sun)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	for i in EFFECTS.size():
		var effect: String = EFFECTS[i]
		var mat: ShaderMaterial = _materials.get(effect)
		if mat == null:
			var shader := load("res://shaders/" + effect + ".gdshader") as Shader
			if shader == null:
				continue
			mat = ShaderMaterial.new()
			mat.shader = shader
			_materials[effect] = mat
		var instance := MeshInstance3D.new()
		instance.mesh = quad
		instance.material_override = mat
		instance.position = Vector3(float(i % 6) - 2.5, 3.3 - float(i / 6), 0.0)
		viewport.add_child(instance)
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = quad
		multi.instance_count = 1
		multi.set_instance_transform(0, Transform3D.IDENTITY)
		var batch := MultiMeshInstance3D.new()
		batch.multimesh = multi
		batch.material_override = mat
		batch.position = instance.position + Vector3(0.0, 0.0, -0.5)
		viewport.add_child(batch)
	game.call("_smoke", Vector3(0.0, 1.0, 1.0), viewport)
	var weather: Weather = game.get("weather")
	if weather:
		var rain := weather._rain()
		rain.amount = 16
		rain.position = Vector3(0.0, 2.0, 1.0)
		viewport.add_child(rain)
	for i in 3:
		await RenderingServer.frame_post_draw
	viewport.queue_free()
	await game.get_tree().process_frame
	_rendered[key] = true
