extends RefCounted

const SAFETY := 2.0
const HYSTERESIS := 4.0

class Materials:
	var regular: ShaderMaterial
	var distant: ShaderMaterial
	var shader: Shader
	var params: Array[StringName] = []
	var values: Dictionary[StringName, Variant] = {}
	var active := 0
	var compatible := true

	func sync() -> void:
		for param in params:
			var value: Variant = regular.get_shader_parameter(param)
			if value != values.get(param):
				distant.set_shader_parameter(param, value)
				values[param] = value


class Receiver:
	var node: GeometryInstance3D
	var materials: Materials
	var original_override: Material
	var center: Vector3
	var half_size: Vector3
	var distant := false

	func set_bounds(bounds: AABB) -> void:
		center = bounds.get_center()
		half_size = bounds.size * 0.5


static var _shaders := {}
var enabled := true
var swapped := 0
var profile := false
var update_usec := 0
var switches := 0
var receivers: Dictionary[GeometryInstance3D, Receiver] = {}
var _materials: Dictionary[ShaderMaterial, Materials] = {}
var _dirty := true
var _forward := Vector3.ZERO
var _origin_depth := 0.0
var _limit := INF


func add(node: GeometryInstance3D, material: ShaderMaterial, padding := 0.0) -> void:
	var receiver: Receiver = receivers.get(node)
	if receiver == null:
		var pair: Materials = _materials.get(material)
		if pair == null:
			pair = Materials.new()
			pair.regular = material
			pair.shader = material.shader
			if not _shaders.has(pair.shader):
				var shader := Shader.new()
				shader.code = "#define CIVCITY_NO_SHADOWS\n" + pair.shader.code
				_shaders[pair.shader] = shader
			pair.distant = ShaderMaterial.new()
			pair.distant.shader = _shaders[pair.shader]
			pair.distant.render_priority = material.render_priority
			for uniform: Dictionary in pair.shader.get_shader_uniform_list():
				pair.params.append(StringName(uniform["name"]))
			_materials[material] = pair
		receiver = Receiver.new()
		receiver.node = node
		receiver.materials = pair
		receiver.original_override = node.material_override
		receivers[node] = receiver
	receiver.set_bounds(node.global_transform * node.get_aabb().grow(padding))
	_dirty = true


func set_priority(material: ShaderMaterial, priority: int) -> void:
	material.render_priority = priority
	var pair: Materials = _materials.get(material)
	if pair != null:
		pair.distant.render_priority = priority


func update(camera: Camera3D, sun: DirectionalLight3D) -> void:
	var start := Time.get_ticks_usec() if profile else 0
	switches = 0
	var depth_limit := INF
	var forward := Vector3.ZERO
	var origin_depth := 0.0
	if enabled and camera != null and sun.shadow_enabled and camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		var transform := camera.get_camera_transform()
		forward = -transform.basis.z
		origin_depth = forward.dot(transform.origin)
		var shadow_max := sun.directional_shadow_max_distance
		if shadow_max > 0.0:
			depth_limit = maxf(camera.near + 0.001, minf(camera.far, shadow_max)) + SAFETY
	for material: ShaderMaterial in _materials:
		var pair: Materials = _materials[material]
		var compatible := pair.regular.shader == pair.shader
		if compatible != pair.compatible:
			pair.compatible = compatible
			_dirty = true
	if _dirty or forward != _forward or origin_depth != _origin_depth or depth_limit != _limit:
		var abs_forward := forward.abs()
		for node: GeometryInstance3D in receivers:
			var receiver: Receiver = receivers[node]
			var nearest := forward.dot(receiver.center) - abs_forward.dot(receiver.half_size) - origin_depth
			var threshold := depth_limit if receiver.distant else depth_limit + HYSTERESIS
			var distant := nearest > threshold and receiver.materials.compatible
			if distant != receiver.distant:
				receiver.distant = distant
				receiver.node.material_override = receiver.materials.distant if distant else receiver.original_override
				var change := 1 if distant else -1
				receiver.materials.active += change
				swapped += change
				switches += 1
		_forward = forward
		_origin_depth = origin_depth
		_limit = depth_limit
		_dirty = false
	if swapped > 0:
		for material: ShaderMaterial in _materials:
			var pair: Materials = _materials[material]
			if pair.active > 0:
				pair.sync()
	if profile:
		update_usec = Time.get_ticks_usec() - start
