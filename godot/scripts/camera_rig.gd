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
var cine := false                    # камеру ведёт вступительный ролик: ввод и плавный ход выключены
var ground_pick: Callable            # точка земли под курсором (game.gd): колёсико приближает к ней, а не к середине экрана
var follow: Callable                # «Следовать» (карточка жителя, этап 6.3): где он сейчас (Vector3; не Vector3 — перестать)
signal follow_ended                 # камера перестала следовать (WASD, тянут карту, Esc, правая кнопка)

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


## Кадр ролика: камера в pos смотрит на look; резкость миниатюры — на look
func cine_look(pos: Vector3, look: Vector3) -> void:
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)
	var d := pos.distance_to(look)
	attrs.dof_blur_far_distance = d * 1.12
	attrs.dof_blur_far_transition = d * 0.9
	attrs.dof_blur_near_distance = d * 0.6
	attrs.dof_blur_near_transition = d * 0.35


## Где камера игрока и куда смотрит — [положение, цель] (куда вернуться после ролика)
func pose() -> Array:
	var d := dist * K
	return [target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * d, target]


func _unhandled_input(e: InputEvent) -> void:
	if cine:
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_orbit = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_pan = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(0.88)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.0 / 0.88)
	elif e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		if _orbit:
			_yaw_t -= mm.relative.x * 0.006
			_pitch_t = clampf(_pitch_t + mm.relative.y * 0.005, deg_to_rad(8), deg_to_rad(80))
		elif _pan:
			if mm.relative.length() > 2.0:
				stop_follow()                # потянули карту — сами ведём камеру
			var k := _dist_t * 0.0016
			var right := Vector3(cos(_yaw_t), 0, -sin(_yaw_t))
			var fwd := Vector3(sin(_yaw_t), 0, cos(_yaw_t))
			_target_t -= right * mm.relative.x * k + fwd * mm.relative.y * k


## Колёсико: ближе или дальше к точке земли под курсором (как в Town to City) — она остаётся под курсором:
## камера и её цель сдвигаются подобием относительно этой точки
func _zoom(k: float) -> void:
	var d1 := clampf(_dist_t * k, DIST_MIN, DIST_MAX)
	var r := d1 / _dist_t
	if ground_pick.is_valid() and absf(r - 1.0) > 1e-4:
		var p = ground_pick.call()
		if p is Vector2 and (p as Vector2).is_finite():
			var g := Vector3((p as Vector2).x, _target_t.y, (p as Vector2).y)
			_target_t = g + (_target_t - g) * r
	_dist_t = d1


## Следовать за жителем (кошкой): f() — где он; камера чуть ближе, ведёт его, пока игрок сам не сдвинет
func start_follow(f: Callable) -> void:
	follow = f
	_dist_t = minf(_dist_t, 26.0)


func stop_follow() -> void:
	if follow.is_valid():
		follow = Callable()
		follow_ended.emit()


func following() -> bool:
	return follow.is_valid()


## Двойной щелчок по постройке: камера плавно летит к ней (3.8); за жителем больше не идёт
func fly_to(p: Vector3) -> void:
	stop_follow()
	_target_t = Vector3(p.x, _target_t.y, p.z)
	_dist_t = minf(_dist_t, 30.0)


## «Показать» (история, заказ): камера к точке p, даль — в пределах [dmin, dmax]; за жителем больше не идёт
func look_at_point(p: Vector3, dmin := 30.0, dmax := 55.0) -> void:
	stop_follow()
	_target_t = p
	_dist_t = clampf(_dist_t, dmin, dmax)


func _process(dt: float) -> void:
	if cine:
		return
	var mv := Vector2.ZERO
	var typing := get_viewport().gui_get_focus_owner() is LineEdit     # печатают почту или название — камера стоит
	if not typing:
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): mv.y -= 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): mv.y += 1
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): mv.x -= 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): mv.x += 1
		if Input.is_key_pressed(KEY_Q): _yaw_t += dt * 1.4
		if Input.is_key_pressed(KEY_E): _yaw_t -= dt * 1.4
	if mv != Vector2.ZERO:
		stop_follow()
		var right := Vector3(cos(_yaw_t), 0, -sin(_yaw_t))
		var fwd := Vector3(sin(_yaw_t), 0, cos(_yaw_t))
		_target_t += (right * mv.x + fwd * mv.y) * _dist_t * 0.9 * dt
	if follow.is_valid():
		var fp = follow.call()
		if fp is Vector3 and (fp as Vector3).is_finite():
			_target_t = Vector3(fp.x, _target_t.y, fp.z)
		else:
			stop_follow()
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
