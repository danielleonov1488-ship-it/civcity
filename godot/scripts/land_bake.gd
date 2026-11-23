extends Node

const TILE_PIXELS := 144
const MAP_TILES := 6
const MAP_COUNT := MAP_TILES * MAP_TILES
const EDGE_TILES := 9
const TILE_COUNT := MAP_COUNT + EDGE_TILES * EDGE_TILES
const EDGE_ORIGIN := -1536.0
const EDGE_TILE_M := 384.0
const READY_SIZE := 16
const CHUNK_M := Land.CH * Land.CELL

var game
var enabled := true
var tiles := Texture2DArray.new()
var readiness: ImageTexture
var completed := 0
var failed := false
var max_cpu_usec := 0
var max_bake_gpu_ms := 0.0
var _valid: Image
var _pending := {}
var _revisions := PackedInt32Array()
var _ready_dirty := false
var _inflight := -1
var _scratch: SubViewport
var _camera: Camera3D
var _material: ShaderMaterial
var _pool: Array[MeshInstance3D] = []
var _used := 0
var _uniforms := PackedStringArray()
var _rich: Variant
var _worker := -1
var _packed: Image
var _copy_revision := 0


func _ready() -> void:
	var empty := Image.create(TILE_PIXELS, TILE_PIXELS, false, Image.FORMAT_RGBA8)
	empty.generate_mipmaps()
	var layers: Array[Image] = []
	layers.resize(TILE_COUNT)
	layers.fill(empty)
	if tiles.create_from_images(layers) != OK:
		_failed("не создан массив текстур")
		return
	_valid = Image.create(READY_SIZE, READY_SIZE, false, Image.FORMAT_R8)
	readiness = ImageTexture.create_from_image(_valid)
	_revisions.resize(TILE_COUNT)
	for id in TILE_COUNT:
		_pending[id] = true
	var baseline: Shader = load("res://shaders/land.gdshader")
	var source := baseline.code.replace("render_mode cull_back", "render_mode unshaded, fog_disabled, cull_back")
	var shader := Shader.new()
	shader.code = "#define PERF14_BAKE_CAPTURE\n" + source
	_material = ShaderMaterial.new()
	_material.shader = shader
	for uniform: Dictionary in baseline.get_shader_uniform_list():
		var name: String = uniform["name"]
		if name not in ["season", "wet", "prev_mode"]:
			_uniforms.append(name)
	_scratch = SubViewport.new()
	_scratch.size = Vector2i(TILE_PIXELS * 2, TILE_PIXELS)
	_scratch.own_world_3d = true
	_scratch.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_scratch.positional_shadow_atlas_size = 0
	add_child(_scratch)
	RenderingServer.viewport_set_measure_render_time(_scratch.get_viewport_rid(), true)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.far = 2048.0
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	_camera.environment = env
	_scratch.add_child(_camera)
	_camera.make_current()
	bind_material()


func prime() -> void:
	if failed:
		return
	var mat: ShaderMaterial = game.land_mat
	_rich = mat.get_shader_parameter("rich")
	_start_tile(mat)
	await RenderingServer.frame_post_draw


func bind_material() -> void:
	if readiness == null:
		return
	var mat: ShaderMaterial = game.land_mat
	mat.set_shader_parameter("baked_land", tiles)
	mat.set_shader_parameter("baked_ready", readiness)
	mat.set_shader_parameter("bake_enabled", enabled and not failed)


func busy() -> bool:
	return not failed and (_inflight >= 0 or not _pending.is_empty())


func invalidate_mask(lo: Vector2i, hi: Vector2i) -> void:
	if hi.x >= 0:
		var pixel_m := Land.CELL * Land.SM
		invalidate(Rect2(Vector2(lo) * pixel_m, Vector2(hi - lo + Vector2i.ONE) * pixel_m).grow(2.0))


func invalidate(rect: Rect2) -> void:
	if readiness == null:
		return
	for id in MAP_COUNT:
		if _tile_rect(id).grow(4.0).intersects(rect):
			_invalidate_tile(id)


func _invalidate_tile(id: int) -> void:
	_pending[id] = true
	_revisions[id] += 1
	_mark_ready(id, false)


func _mark_ready(id: int, ready: bool) -> void:
	var p := Vector2i(id % READY_SIZE, id / READY_SIZE)
	var value := 1.0 if ready else 0.0
	if _valid.get_pixelv(p).r != value:
		_valid.set_pixelv(p, Color(value, 0.0, 0.0))
		_ready_dirty = true


func _tile_rect(id: int) -> Rect2:
	if id < MAP_COUNT:
		return Rect2(Vector2(id % MAP_TILES, id / MAP_TILES) * 64.0, Vector2.ONE * 64.0)
	var tile := id - MAP_COUNT
	return Rect2(Vector2(tile % EDGE_TILES, tile / EDGE_TILES) * EDGE_TILE_M + Vector2.ONE * EDGE_ORIGIN, Vector2.ONE * EDGE_TILE_M)


func _process(_dt: float) -> void:
	if failed or not enabled or not game.ready_done or game.legion_city_hidden():
		return
	var start := Time.get_ticks_usec()
	var mat: ShaderMaterial = game.land_mat
	var rich: Variant = mat.get_shader_parameter("rich")
	if rich != _rich:
		_rich = rich
		for id in TILE_COUNT:
			_invalidate_tile(id)
	if _worker >= 0 and WorkerThreadPool.is_task_completed(_worker):
		WorkerThreadPool.wait_for_task_completion(_worker)
		_worker = -1
		if _revisions[_inflight] == _copy_revision:
			tiles.update_layer(_packed, _inflight)
			_mark_ready(_inflight, true)
			_pending.erase(_inflight)
			completed += 1
		_packed = null
		_inflight = -1
		max_bake_gpu_ms = maxf(max_bake_gpu_ms, RenderingServer.viewport_get_measured_render_time_gpu(_scratch.get_viewport_rid()))
	if _ready_dirty:
		readiness.update(_valid)
		_ready_dirty = false
	if _inflight < 0 and not _pending.is_empty():
		_start_tile(mat)
	max_cpu_usec = maxi(max_cpu_usec, Time.get_ticks_usec() - start)


func _start_tile(mat: ShaderMaterial) -> void:
	var focus3: Vector3 = game.rig.target
	var focus := Vector2(focus3.x, focus3.z)
	var best := INF
	for id: int in _pending:
		var score := _tile_rect(id).get_center().distance_squared_to(focus)
		if score < best:
			best = score
			_inflight = id
	_copy_revision = _revisions[_inflight]
	var rect := _tile_rect(_inflight)
	var span := rect.size.x * float(TILE_PIXELS) / 128.0
	var center := rect.get_center()
	_camera.size = span
	_camera.transform = Transform3D(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP,
		Vector3(center.x + span * 0.5, 512.0, center.y))
	_material.set_shader_parameter("bake_span", span)
	_material.set_shader_parameter("bake_center", center)
	for name: String in _uniforms:
		_material.set_shader_parameter(name, mat.get_shader_parameter(name))
	_used = 0
	if _inflight < MAP_COUNT:
		var expanded := rect.grow(4.0)
		var lo := Vector2i((expanded.position / CHUNK_M).floor()).max(Vector2i.ZERO)
		var hi := Vector2i((expanded.end / CHUNK_M).ceil()).min(Vector2i.ONE * Land.CHN)
		for z in range(lo.y, hi.y):
			for x in range(lo.x, hi.x):
				var node: MeshInstance3D = game.chunk_nodes.get(Vector2i(x, z))
				if node != null:
					_place(node, 0.0)
					_place(node, span)
	else:
		var horizon: MeshInstance3D = game._horizon_ground
		_place(horizon, 0.0)
		_place(horizon, span)
	for i in range(_used, _pool.size()):
		_pool[i].hide()
		_pool[i].mesh = null
	_scratch.render_target_update_mode = SubViewport.UPDATE_ONCE
	_copy_tile()


func _place(source: MeshInstance3D, shift: float) -> void:
	if _used == _pool.size():
		var instance := MeshInstance3D.new()
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.material_override = _material
		_scratch.add_child(instance)
		_pool.append(instance)
	var instance := _pool[_used]
	_used += 1
	instance.transform = source.global_transform.translated(Vector3.RIGHT * shift)
	instance.mesh = source.mesh
	instance.set_instance_shader_parameter("bake_shift", shift)
	instance.show()


func _copy_tile() -> void:
	await RenderingServer.frame_post_draw
	max_bake_gpu_ms = maxf(max_bake_gpu_ms, RenderingServer.viewport_get_measured_render_time_gpu(_scratch.get_viewport_rid()))
	RenderingServer.call_on_render_thread(_read_tile.bind(_scratch.get_texture().get_rid()))


func _read_tile(viewport_texture: RID) -> void:
	var rd := RenderingServer.get_rendering_device()
	var texture := RenderingServer.texture_get_rd_texture(viewport_texture)
	if not texture.is_valid():
		_failed.call_deferred("нет текстуры для чтения")
		return
	var format := rd.texture_get_format(texture)
	if format.format != RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM and format.format != RenderingDevice.DATA_FORMAT_R8G8B8A8_SRGB:
		_failed.call_deferred("неожиданный формат плитки %d" % format.format)
		return
	var err := rd.texture_get_data_async(texture, 0, _tile_read)
	if err != OK:
		_failed.call_deferred("чтение плитки с GPU: %d" % err)


func _tile_read(data: PackedByteArray) -> void:
	_pack_async.call_deferred(data)


func _pack_async(data: PackedByteArray) -> void:
	if data.size() != TILE_PIXELS * TILE_PIXELS * 8:
		_failed("неверный размер плитки")
		return
	_worker = WorkerThreadPool.add_task(_pack_tile.bind(data))


func _pack_tile(data: PackedByteArray) -> void:
	var linear := PackedByteArray()
	linear.resize(256)
	for value in 256:
		var v := float(value) / 255.0
		linear[value] = roundi(255.0 * pow((v + 0.055) / 1.055, 2.4)) if v > 0.04045 else roundi(value / 12.92)
	var packed := PackedByteArray()
	for y in TILE_PIXELS:
		var start := y * TILE_PIXELS * 8
		var middle := start + TILE_PIXELS * 4
		var row := data.slice(start, middle)
		for x in TILE_PIXELS:
			row[x * 4 + 3] = linear[data[middle + x * 4]]
		packed.append_array(row)
	_packed = Image.create_from_data(TILE_PIXELS, TILE_PIXELS, false, Image.FORMAT_RGBA8, packed)
	_packed.generate_mipmaps()


func _failed(reason: String) -> void:
	failed = true
	bind_material()
	push_warning("Запекание земли: " + reason)


func _exit_tree() -> void:
	if _worker >= 0:
		WorkerThreadPool.wait_for_task_completion(_worker)
