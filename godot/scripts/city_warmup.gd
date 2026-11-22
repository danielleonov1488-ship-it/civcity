extends RefCounted

const DIRS := [
	"res://assets/synty/FBX", "res://assets/synty_meadow/FBX", "res://assets/kit/houses",
	"res://assets/artisau", "res://assets/people", "res://assets/animals", "res://assets/fauna",
	"res://assets/cat", "res://assets/fort/v2", "res://assets/legion_chars", "res://assets/legion_enemies",
]
const ART := "res://assets/fort/cutaway/rooms"
const EFFECTS := ["citizen_cloth", "foliage", "meadow_foliage", "wheat", "field_cover",
	"water", "stream_flow", "pool_water", "land", "grass_carpet", "cat_fur", "crowd",
	"cover", "outline", "outline_hull", "kit_reveal", "meadow_rock", "meadow_spin"]
const BATCH := 8

static var _assets: Dictionary = {}
static var _prepared := false
static var _rendered := {}


## Оставляем ссылки: иначе кэш ResourceLoader отпустит ресурс до первой постройки.
static func prepare(tree: SceneTree) -> void:
	if _prepared:
		return
	var paths: Array[String] = []
	for dir: String in DIRS:
		_collect(dir, ["fbx", "glb"], paths)
	_collect(ART, ["jpg", "png"], paths)
	_collect("res://shaders", ["gdshader"], paths)
	for start in range(0, paths.size(), BATCH):
		var pending: Array[String] = []
		for path: String in paths.slice(start, start + BATCH):
			if ResourceLoader.load_threaded_request(path) == OK:
				pending.append(path)
		while not pending.is_empty():
			await tree.process_frame
			for i in range(pending.size() - 1, -1, -1):
				var path := pending[i]
				var status := ResourceLoader.load_threaded_get_status(path)
				if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
					continue
				if status == ResourceLoader.THREAD_LOAD_LOADED:
					_assets[path] = ResourceLoader.load_threaded_get(path)
				pending.remove_at(i)
	_prepared = true


static func _collect(dir: String, extensions: Array, paths: Array[String]) -> void:
	for entry: String in ResourceLoader.list_directory(dir):
		if entry.ends_with("/"):
			_collect(dir.path_join(entry.trim_suffix("/")), extensions, paths)
		elif entry.get_extension().to_lower() in extensions:
			paths.append(dir.path_join(entry))


## У картинок построек свой SubViewport. Здесь запускаем проходы городских шейдеров
## с текущим MSAA и тенями, пока над городом ещё виден экран загрузки.
static func render_effects(game: Node3D) -> void:
	var root := game.get_viewport()
	var city_sun: DirectionalLight3D = game.get("sun")
	var shadows := city_sun != null and city_sun.shadow_enabled
	var key := Vector3i(root.msaa_3d, root.screen_space_aa, int(shadows))
	if _rendered.has(key):
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128, 128)
	viewport.own_world_3d = true
	viewport.msaa_3d = root.msaa_3d
	viewport.screen_space_aa = root.screen_space_aa
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
		var shader: Shader = _assets.get("res://shaders/" + EFFECTS[i] + ".gdshader")
		if shader == null:
			continue
		var mat := ShaderMaterial.new()
		mat.shader = shader
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
	_rendered[key] = true
