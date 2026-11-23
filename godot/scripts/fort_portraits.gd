extends Node
## Один стенд на игру. Читаем кадр один раз и храним маленькие снимки.

const Perf14 = preload("res://scripts/perf14_timers.gd")
const Actor = preload("res://scripts/charpilot_actor.gd")
const PersonLayer = preload("res://scripts/fort_person_layer.gd")
const PIXELS := 128
const CACHE_LIMIT := 64
const PAPER := """
shader_type canvas_item;
void fragment() {
	vec2 p = UV - vec2(0.39, 0.33);
	float light = exp(-5.5 * dot(p, p));
	float wash = sin(UV.x * 19.0 + UV.y * 13.0 + sin(UV.y * 12.0)) * 0.018;
	float grain = fract(sin(dot(floor(UV * 128.0), vec2(12.9898, 78.233))) * 43758.5453);
	vec3 paper = mix(vec3(0.74, 0.57, 0.42), vec3(1.0, 0.91, 0.76), light);
	COLOR = vec4(paper + wash + (grain - 0.5) * 0.026, 1.0);
}
"""
const MASK := """
shader_type canvas_item;
varying vec4 tint;
void vertex() {
	tint = COLOR;
}
void fragment() {
	vec4 picture = texture(TEXTURE, UV) * tint;
	picture.a *= 1.0 - smoothstep(0.487, 0.5, length(UV - vec2(0.5)));
	COLOR = picture;
}
"""

static var _mask: ShaderMaterial
var _cache: Dictionary = {}
var _pending: Dictionary = {}
var _canvas: SubViewport
var _layer: PersonLayer
var _actor: Actor
var _job := ""
var _draw_frame := -1
var _next_frame := 0
var work_usec := 0


static func bind(rect: TextureRect, spec: Dictionary) -> void:
	var key: String = spec["key"]
	if rect.get_meta("person_portrait", "") == key:
		return
	rect.set_meta("person_portrait", key)
	rect.set_meta("portrait_look", spec["look"])
	rect.set_meta("portrait_loadout", spec["clothes"])
	rect.set_meta("portrait_crown", spec["crown"])
	rect.set_meta("portrait_ready", false)
	rect.texture = preload("res://assets/ui/icons/head_adult.svg")
	if _mask == null:
		_mask = _material(MASK)
	rect.material = _mask
	if DisplayServer.get_name() == "headless":
		return
	if rect.is_inside_tree():
		_enqueue(rect, spec)
	else:
		rect.ready.connect(_enqueue.bind(rect, spec), CONNECT_ONE_SHOT)


static func _enqueue(rect: TextureRect, spec: Dictionary) -> void:
	var key: String = spec["key"]
	if rect.get_meta("person_portrait", "") != key:
		return
	var root := rect.get_tree().root
	var service = root.get_meta("fort_portraits", null) if root.has_meta("fort_portraits") else null
	if service == null:
		# ready может прийти, пока главный экран добавляется к корню.
		service = new()
		service.name = "FortPortraits"
		root.add_child.call_deferred(service)
		root.set_meta("fort_portraits", service)
	service._request(rect, spec)


static func _material(code: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _request(rect: TextureRect, spec: Dictionary) -> void:
	var key: String = spec["key"]
	if _cache.has(key):
		var texture: Texture2D = _cache[key]
		_cache.erase(key)
		_cache[key] = texture
		_show(rect, texture)
		return
	var entry: Dictionary = _pending.get_or_add(key, {"spec": spec, "waiters": []})
	entry["waiters"].append(weakref(rect))
	set_process(true)


func _setup() -> void:
	_canvas = SubViewport.new()
	_canvas.size = Vector2i(PIXELS, PIXELS)
	_canvas.disable_3d = true
	_canvas.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_canvas)
	var paper := ColorRect.new()
	paper.size = Vector2(PIXELS, PIXELS)
	paper.material = _material(PAPER)
	_canvas.add_child(paper)
	_layer = PersonLayer.new()
	_canvas.add_child(_layer)
	_layer.setup("FortPortraitStudio", 4.0, false, false)
	_layer.fit(Vector2(PIXELS, PIXELS))
	_layer.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _process(_delta: float) -> void:
	var started := Time.get_ticks_usec()
	_render_step()
	work_usec += Time.get_ticks_usec() - started


func _render_step() -> void:
	var frame := Engine.get_process_frames()
	if _job != "":
		if _draw_frame >= 0 and frame > _draw_frame:
			var started := Perf14.begin()
			_collect()
			Perf14.detail("fort_portrait_readback", started)
		return
	if _pending.is_empty():
		set_process(false)
		return
	if frame < _next_frame:
		return
	var key: String = _pending.keys()[0]
	var entry: Dictionary = _pending[key]
	if not entry["waiters"].any(func(ref: WeakRef): return _waiting(ref, key)):
		_pending.erase(key)
		return
	var started := Perf14.begin()
	if _canvas == null:
		_setup()
	_job = key
	var ready := _stage(entry["spec"])
	Perf14.detail("fort_portrait_stage", started)
	if not ready:
		_discard()
		return
	_layer.render_first_frame()
	RenderingServer.frame_post_draw.connect(_draw_portrait, CONNECT_ONE_SHOT)


func _draw_portrait() -> void:
	_canvas.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.frame_post_draw.connect(_drawn, CONNECT_ONE_SHOT)


func _drawn() -> void:
	_draw_frame = Engine.get_process_frames()


func _stage(spec: Dictionary) -> bool:
	_actor = Actor.new()
	_layer.viewport.add_child(_actor)
	var look: Dictionary = spec["look"]
	var clothes: Dictionary = spec["clothes"]
	if bool(spec["rival"]):
		_actor.build_rival_hero(look, 1)
	else:
		if not _actor.build(1, bool(look["female"]), String(look["skin"]), look, String(clothes["outfit"])):
			return false
		if not _actor.set_loadout(clothes):
			return false
		if int(spec["crown"]) > 0:
			_actor.add_dweller_hero_trim(spec["cape"], spec["crown"])
	var head := _actor._bone_frame(_actor._rig, "Head", false)
	_actor.rotation_degrees.y = 22.0
	_layer.camera.size = 0.72
	_layer.camera.position = _actor.to_global(head.origin + Vector3(0.0, -0.025, 0.03)) + _layer.camera.basis.z * 10.0
	return true


func _collect() -> void:
	var picture := _canvas.get_texture().get_image()
	if picture != null and not picture.is_empty():
		var texture := ImageTexture.create_from_image(picture)
		_cache[_job] = texture
		if _cache.size() > CACHE_LIMIT:
			_cache.erase(_cache.keys()[0])
		for ref: WeakRef in _pending[_job]["waiters"]:
			if _waiting(ref, _job):
				_show(ref.get_ref(), texture)
	_discard()


func _discard() -> void:
	_actor.queue_free()
	_actor = null
	_pending.erase(_job)
	_job = ""
	_draw_frame = -1
	_next_frame = Engine.get_process_frames() + 2


static func _waiting(ref: WeakRef, key: String) -> bool:
	var rect := ref.get_ref() as TextureRect
	return rect != null and rect.is_inside_tree() and rect.get_meta("person_portrait", "") == key


static func _show(rect: TextureRect, texture: Texture2D) -> void:
	rect.texture = texture
	rect.set_meta("portrait_ready", true)
