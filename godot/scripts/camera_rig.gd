class_name CameraRig
extends Node3D
## Камера как в Town to City: зажатое колёсико — вращать под любым углом, колёсико — ближе/дальше,
## правая кнопка или WASD — двигать, Q/E — поворот. Ближе к земле камера сама наклоняется ниже.

var yaw := deg_to_rad(200.0)
var pitch := deg_to_rad(38.0)
var dist := 34.0
var target := Vector3(38, 2, 44)
var cam: Camera3D
var attrs: CameraAttributesPractical
var terrain = null
var land = null                      # что-то с height_at(x, z): земля игры
var _yaw_t := yaw
var _pitch_t := pitch
var _dist_t := dist
var _target_t := target
var _orbit := false
var _pan := false

const DIST_MIN := 4.0
const DIST_MAX := 130.0
const FOV := 30.0                    # узкий объектив — город как игрушечная миниатюра (Town to City)
## dist — «масштаб кадра» (как при прежнем объективе 40°), камера отъезжает дальше, чтобы кадр был тот же
static var K := tan(deg_to_rad(20.0)) / tan(deg_to_rad(FOV / 2.0))


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = FOV
	cam.near = 0.15
	cam.far = 800.0
	attrs = CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_near_enabled = true
	attrs.dof_blur_amount = 0.09
	cam.attributes = attrs
	add_child(cam)
	_update(true)


func set_view(t: Vector3, yaw_deg: float, pitch_deg: float, d: float) -> void:
	target = t
	_target_t = t
	yaw = deg_to_rad(yaw_deg)
	_yaw_t = yaw
	pitch = deg_to_rad(pitch_deg)
	_pitch_t = pitch
	dist = d
	_dist_t = d
	_update(true)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_orbit = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_pan = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist_t = clampf(_dist_t * 0.88, DIST_MIN, DIST_MAX)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist_t = clampf(_dist_t / 0.88, DIST_MIN, DIST_MAX)
	elif e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		if _orbit:
			_yaw_t -= mm.relative.x * 0.006
			_pitch_t = clampf(_pitch_t + mm.relative.y * 0.005, deg_to_rad(8), deg_to_rad(80))
		elif _pan:
			var k := _dist_t * 0.0016
			var right := Vector3(cos(_yaw_t), 0, -sin(_yaw_t))
			var fwd := Vector3(sin(_yaw_t), 0, cos(_yaw_t))
			_target_t -= right * mm.relative.x * k + fwd * mm.relative.y * k


func _process(dt: float) -> void:
	var mv := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): mv.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): mv.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): mv.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): mv.x += 1
	if Input.is_key_pressed(KEY_Q): _yaw_t += dt * 1.4
	if Input.is_key_pressed(KEY_E): _yaw_t -= dt * 1.4
	if mv != Vector2.ZERO:
		var right := Vector3(cos(_yaw_t), 0, -sin(_yaw_t))
		var fwd := Vector3(sin(_yaw_t), 0, cos(_yaw_t))
		_target_t += (right * mv.x + fwd * mv.y) * _dist_t * 0.9 * dt
	_target_t.x = clampf(_target_t.x, 4.0, Land.SIZE - 4.0)
	_target_t.z = clampf(_target_t.z, 4.0, Land.SIZE - 4.0)
	var a := 1.0 - pow(0.0008, dt)
	yaw = lerpf(yaw, _yaw_t, a)
	pitch = lerpf(pitch, _pitch_t, a)
	dist = lerpf(dist, _dist_t, a)
	target = target.lerp(_target_t, a)
	_update(false)


func _update(_snap: bool) -> void:
	var hsrc = land if land != null else terrain
	if hsrc != null:
		target.y = lerpf(target.y, maxf(1.0, hsrc.height_at(target.x, target.z)), 0.1 if not _snap else 1.0)
	var d := dist * K
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * d
	if cam:
		cam.global_position = target + off
		cam.look_at(target, Vector3.UP)
		# размытие как у миниатюры: резко там, куда смотрим, мягко вдали и у самой камеры
		attrs.dof_blur_far_distance = d * 1.12
		attrs.dof_blur_far_transition = d * 0.9
		attrs.dof_blur_near_distance = d * 0.6
		attrs.dof_blur_near_transition = d * 0.35
