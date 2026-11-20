extends RefCounted
## Боевые позы поверх UAL Idle (в седле — поверх посадки). Координаты в осях персонажа, +Z вперёд.

const BOW_IDLE := "Bow_Idle"
const BOW := "Bow_Shoot"
const SLING_IDLE := "Sling_Idle"
const SLING := "Sling_Shoot"
const CAST_IDLE := "Cast_Idle"
const CAST := "Staff_Cast"
const BLEND := 0.12
const NOCK := 0.38
const ARROW_LENGTH := 0.97
const LENGTHS := {BOW_IDLE: 1.6, BOW: 1.26, SLING_IDLE: 1.6, SLING: 1.13, CAST_IDLE: 1.6, CAST: 1.18}
const RELEASES := {BOW: 0.91, SLING: 0.84, CAST: 0.70}
const ALIASES := {"UpperChest": "spine_03", "Chest": "spine_02", "Head": "head", "Neck": "neck_01",
	"LeftUpperArm": "upperarm_l", "LeftLowerArm": "lowerarm_l", "LeftHand": "hand_l",
	"RightUpperArm": "upperarm_r", "RightLowerArm": "lowerarm_r", "RightHand": "hand_r",
	"LeftUpperLeg": "thigh_l", "LeftLowerLeg": "calf_l", "LeftFoot": "foot_l"}

var rig: Skeleton3D
var anchor: Node3D
var mode: String
var mounted: bool
var bow: MeshInstance3D
var arrow: MeshInstance3D
var pouch: MeshInstance3D
var stone: MeshInstance3D
var staff: Node3D
var launch := Vector3.ZERO
var _model_from_rig: Transform3D
var _rig_from_model: Transform3D
var _bones: Dictionary = {}
var _bow_grip: Node3D
var _top: MeshInstance3D
var _bottom: MeshInstance3D
var _loose: MeshInstance3D
var _height := 1.0
var _idle: String
var _action: String

static var _props: Dictionary = {}


func _init(skeleton: Skeleton3D, model: Node3D, equipment: String, rear := false, staff_item: Node3D = null) -> void:
	rig = skeleton
	anchor = model
	mode = equipment
	mounted = rear
	staff = staff_item
	_idle = {"bow": BOW_IDLE, "sling": SLING_IDLE, "cast": CAST_IDLE}[mode]
	_action = {"bow": BOW, "sling": SLING, "cast": CAST}[mode]
	_model_from_rig = Citizen._rel(rig, anchor)
	_rig_from_model = _model_from_rig.affine_inverse()
	for id: String in ALIASES:
		var index := rig.find_bone(id)
		_bones[id] = index if index >= 0 else rig.find_bone(ALIASES[id])
	var head := int(_bones["Head"])
	if head >= 0:
		_height = clampf((_model_from_rig * rig.get_bone_global_rest(head).origin).y / 1.54, 0.85, 1.15)
	match mode:
		"bow":
			# Кисть несёт рукоять. Оси лука задаёт линия прицеливания.
			var socket := BoneAttachment3D.new()
			rig.add_child(socket)
			socket.bone_name = rig.get_bone_name(int(_bones["LeftHand"]))
			_bow_grip = Node3D.new()
			socket.add_child(_bow_grip)
			bow = _mesh(_bow_grip, "ArcherBow", "bow")
			_top = _mesh(anchor, "BowStringTop", "cord")
			_bottom = _mesh(anchor, "BowStringBottom", "cord")
			arrow = _mesh(anchor, "NockedArrow", "arrow")
		"sling":
			_top = _mesh(anchor, "SlingCordHeld", "cord")
			_loose = _mesh(anchor, "SlingCordLoose", "cord")
			pouch = _mesh(anchor, "SlingPouch", "pouch")
			stone = _mesh(anchor, "SlingStone", "stone")
		"cast":
			if staff == null:
				staff = _mesh(anchor, "CastingStaff", "staff")
	for prop: Node3D in [arrow, stone]:
		if prop != null:
			prop.hide()


func idle_clip() -> String:
	return _idle


func action_clip() -> String:
	return _action


func set_visible(active: bool) -> void:
	for prop: Node3D in [bow, _top, _bottom, _loose, pouch, staff]:
		if prop != null:
			prop.visible = active
	if not active:
		for prop: Node3D in [arrow, stone]:
			if prop != null:
				prop.hide()


func point(bone: String) -> Vector3:
	return _model_from_rig * _frame(bone).origin


func _frame(bone: String) -> Transform3D:
	return rig.get_bone_global_pose(int(_bones[bone]))


func _turn(bone: String, axis: Vector3, angle: float, weight: float) -> void:
	var index := int(_bones[bone])
	if index < 0:
		return
	var local_axis := _frame(bone).basis.inverse() * (_rig_from_model.basis * axis)
	rig.set_bone_pose_rotation(index, rig.get_bone_pose_rotation(index) * Quaternion(local_axis.normalized(), angle * weight))


func _aim(index: int, child: int, direction: Vector3, weight: float) -> void:
	var frame := rig.get_bone_global_pose(index)
	var current := (frame.basis * rig.get_bone_pose_position(child)).normalized()
	var swung := Quaternion(current, direction.normalized())
	var local := frame.basis.get_rotation_quaternion().inverse() * swung * frame.basis.get_rotation_quaternion()
	var before := rig.get_bone_pose_rotation(index)
	rig.set_bone_pose_rotation(index, before.slerp(before * local, weight))


func _limb(upper: String, lower: String, end: String, at: Vector3, pole: Vector3, weight: float) -> void:
	var a := int(_bones[upper])
	var b := int(_bones[lower])
	var c := int(_bones[end])
	var root := rig.get_bone_global_pose(a).origin
	var offset := _rig_from_model * at - root
	var along := offset.normalized()
	var l1 := rig.get_bone_pose_position(b).length()
	var l2 := rig.get_bone_pose_position(c).length()
	var d := clampf(offset.length(), absf(l1 - l2) + 0.002, l1 + l2 - 0.002)
	var bend := (_rig_from_model * pole - root).slide(along).normalized()
	var adjacent := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var elbow := along * adjacent + bend * sqrt(maxf(0.0, l1 * l1 - adjacent * adjacent))
	_aim(a, b, elbow, weight)
	_aim(b, c, root + along * d - rig.get_bone_global_pose(b).origin, weight)


func _hand(left: bool, direction: Vector3, weight: float) -> void:
	var index := int(_bones["LeftHand" if left else "RightHand"])
	var finger := rig.find_bone("LeftMiddleProximal" if left else "RightMiddleProximal")
	if finger < 0:
		finger = rig.find_bone("middle_01_l" if left else "middle_01_r")
	if finger >= 0:
		_aim(index, finger, _rig_from_model.basis * direction, weight)


func apply(clip: String, t: float, weight := 1.0) -> void:
	set_visible(true)
	var action := clip == _action
	# Отмена возвращает конечности к стойке того же оружия.
	var pose_weight := 1.0 if action else weight
	match mode:
		"bow": _pose_bow(t if action else -1.0, pose_weight, weight)
		"sling": _pose_sling(t if action else -1.0, pose_weight, weight)
		"cast": _pose_cast(t if action else -1.0, pose_weight, weight)


func _pose_bow(t: float, weight: float, amount: float) -> void:
	var reach := smoothstep(0.0, 0.22, t) * (1.0 - smoothstep(0.22, 0.41, t)) * amount
	var raise_bow := smoothstep(0.21, 0.62, t) * (1.0 - smoothstep(0.99, 1.26, t)) * amount
	var nock := smoothstep(0.22, NOCK, t) * (1.0 - smoothstep(0.99, 1.26, t)) * amount
	var draw := smoothstep(0.42, 0.78, t)
	var loose := smoothstep(0.91, 0.995, t) * (1.0 - smoothstep(1.04, 1.24, t))
	var turn := smoothstep(0.18, 0.60, t) * (1.0 - smoothstep(1.01, 1.26, t)) * amount
	var aim := Vector3.FORWARD if mounted else Vector3.BACK
	var side := Vector3.RIGHT if mounted else Vector3.LEFT
	var twist := (1.92 if mounted else -1.09) * turn
	_turn("Chest", Vector3.UP, twist * 0.50, weight)
	_turn("UpperChest", Vector3.UP, twist * 0.50, weight)
	_turn("Head", Vector3.UP, (0.38 if mounted else 0.79) * turn, weight)
	var l := point("LeftUpperArm")
	var r := point("RightUpperArm")
	var jaw := point("Head") - Vector3.UP * 0.01 * _height
	var left_at := l + Vector3(0.15, -0.42, 0.16) * _height
	left_at = left_at.lerp(l + aim * 0.59 * _height + Vector3.UP * (jaw.y - l.y - 0.035), raise_bow)
	_limb("LeftUpperArm", "LeftLowerArm", "LeftHand", left_at, l + Vector3(0.28, -0.52, 0.0), weight)
	_hand(true, aim.lerp(Vector3.DOWN, 0.50), weight)
	var grip := point("LeftHand") + (aim * 0.043 + Vector3.DOWN * 0.026) * _height
	var right_at := r + Vector3(-0.15, -0.45, 0.10) * _height
	right_at = right_at.lerp(jaw + Vector3(-0.22, 0.08, -0.24) * _height, reach)
	var pull_at := jaw - aim * (0.155 + loose * 0.19) * _height + side * 0.09 * _height
	var nock_at := grip - aim * 0.237
	right_at = right_at.lerp(nock_at.lerp(pull_at, draw), nock)
	var right_elbow := (r + Vector3(-0.38, -0.40, 0.0)).lerp(r - aim * 0.60 + side * 0.38 + Vector3.UP * 0.30, maxf(reach, draw * nock))
	_limb("RightUpperArm", "RightLowerArm", "RightHand", right_at, right_elbow, weight)
	_hand(false, aim.lerp(Vector3.DOWN, 1.0 - maxf(reach, nock)).normalized(), weight)
	var up := Vector3(0.13 * (1.0 - raise_bow), 1.0, 0.06).normalized()
	var frame := LegionFighter._basis(up, aim)
	_bow_grip.transform = _frame("LeftHand").affine_inverse() * _rig_from_model * Transform3D(frame, grip)
	var relaxed := grip - aim * 0.18
	var fingers := point("RightHand") + aim * 0.057
	var loaded := t >= NOCK and t < RELEASES[BOW]
	var taut := 1.0 if loaded else 0.0
	var string_at := relaxed.lerp(fingers, taut * amount)
	_rod(_top, grip + frame * Vector3(0, 0.45, -0.18), string_at)
	_rod(_bottom, grip + frame * Vector3(0, -0.45, -0.18), string_at)
	var shaft := (grip - string_at + Vector3.UP * 0.034).normalized() if loaded else aim
	arrow.transform = Transform3D(LegionFighter._basis(Vector3.UP, shaft), string_at)
	arrow.visible = loaded and amount > 0.5
	var release_axis := (grip - fingers + Vector3.UP * 0.034).normalized()
	launch = fingers + release_axis * (ARROW_LENGTH * 0.5)


func _pose_sling(t: float, weight: float, amount: float) -> void:
	var rise := smoothstep(0.0, 0.25, t) * amount
	var swing := smoothstep(0.69, 0.86, t) * amount
	var settle := smoothstep(0.91, 1.13, t)
	var angle := TAU * clampf((t - 0.23) / 0.55, 0.0, 1.0)
	_turn("Chest", Vector3.UP, (-0.38 * rise + 0.83 * swing) * (1.0 - settle), weight)
	var shoulder := point("RightUpperArm")
	var hand := shoulder + Vector3(-0.10, -0.45, 0.14) * _height
	var overhead := point("Head") + Vector3(-0.25 + 0.08 * cos(angle), 0.32, 0.11 * sin(angle)) * _height
	hand = hand.lerp(overhead, rise * (1.0 - settle))
	hand = hand.lerp(shoulder + Vector3(-0.03, 0.11, 0.52) * _height, swing * (1.0 - settle))
	_limb("RightUpperArm", "RightLowerArm", "RightHand", hand, shoulder + Vector3(-0.55, 0.15, -0.08), weight)
	_hand(false, Vector3(0, -0.6 + rise, 0.8), weight)
	var step := smoothstep(0.62, 0.86, t) * (1.0 - settle) * amount
	if step > 0.0:
		var foot := point("LeftFoot")
		_limb("LeftUpperLeg", "LeftLowerLeg", "LeftFoot", foot + Vector3(0.035, 0.09, 0.25) * step, foot + Vector3(0, 0.3, 0.6), weight)
	var grip := point("RightHand") + Vector3(0, -0.035, 0.035)
	var trail := Vector3.DOWN.lerp(Vector3(-cos(angle), 0.10, sin(angle)), rise * (1.0 - settle))
	trail = trail.lerp(Vector3.BACK, swing * (1.0 - settle)).normalized()
	var pocket := grip + trail * 0.42 * _height
	_rod(_top, grip, pocket)
	var loose_end := grip + Vector3(0.025, 0.0, -0.02)
	if t >= RELEASES[SLING]:
		loose_end = pocket + trail * 0.28 - Vector3.UP * 0.10
	_rod(_loose, pocket, loose_end)
	pouch.position = pocket
	stone.position = pocket + Vector3.UP * 0.023
	stone.visible = t < RELEASES[SLING]
	launch = stone.position


func _pose_cast(t: float, weight: float, amount: float) -> void:
	var k := smoothstep(0.0, 0.61, t) * (1.0 - smoothstep(0.79, 1.18, t)) * amount
	_turn("Chest", Vector3.UP, -0.14 * k, weight)
	_turn("Head", Vector3.RIGHT, -0.18 * k, weight)
	var r := point("RightUpperArm")
	var l := point("LeftUpperArm")
	_limb("RightUpperArm", "RightLowerArm", "RightHand", r + Vector3(-0.13, -0.37, 0.29).lerp(Vector3(-0.24, 0.32, 0.21), k) * _height,
		r + Vector3(-0.43, -0.18, 0.09), weight)
	_limb("LeftUpperArm", "LeftLowerArm", "LeftHand", l + Vector3(0.11, -0.43, 0.13).lerp(Vector3(0.24, 0.24, 0.32), k) * _height,
		l + Vector3(0.38, -0.28, 0.06), weight)
	_hand(false, Vector3(0, -0.12, 1), weight)
	_hand(true, Vector3(0.10, 0.75, 0.6), weight * k)
	var at := point("RightHand") + Vector3(0, -0.025, 0.045)
	staff.transform = Transform3D(LegionFighter._basis(Vector3(-0.04, 1.0, 0.10 - 0.10 * k), Vector3.BACK), at)
	launch = staff.transform * Vector3(0, 0.50, 0)


static func _rod(mesh: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var line := b - a
	var axis := line.normalized()
	var cross := Vector3.RIGHT if absf(axis.x) < 0.9 else Vector3.BACK
	var frame := LegionFighter._basis(axis, cross)
	frame.y *= maxf(0.001, line.length())
	mesh.transform = Transform3D(frame, (a + b) * 0.5)


static func _mesh(parent: Node3D, label: String, id: String) -> MeshInstance3D:
	if not _props.has(id):
		_props[id] = _build_prop(id)
	var result := MeshInstance3D.new()
	result.name = label
	result.mesh = _props[id]
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(result)
	return result


static func _build_prop(id: String) -> Mesh:
	var colors := {"bow": "a16731", "cord": "a38458", "arrow": "af875d", "pouch": "704634", "stone": "847c6e", "staff": "8b5837"}
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(String(colors[id]))
	material.roughness = 0.88
	if id in ["pouch", "stone"]:
		var pebble := SphereMesh.new()
		pebble.radial_segments = 7
		pebble.rings = 4
		pebble.radius = 0.040 if id == "pouch" else 0.029
		pebble.height = 0.046
		pebble.material = material
		return pebble
	var tube := SurfaceTool.new()
	tube.begin(Mesh.PRIMITIVE_TRIANGLES)
	tube.set_material(material)
	match id:
		"bow":
			var points := PackedVector3Array([Vector3(0, -0.45, -0.18), Vector3(0, -0.365, -0.075), Vector3(0, -0.265, -0.015),
				Vector3(0, -0.13, 0.027), Vector3.ZERO, Vector3(0, 0.13, 0.027), Vector3(0, 0.265, -0.015),
				Vector3(0, 0.365, -0.075), Vector3(0, 0.45, -0.18)])
			for i in range(points.size() - 1):
				_tube(tube, points[i], points[i + 1], 0.009 + 0.003 * mini(i, 8 - i), 0.009 + 0.003 * mini(i + 1, 7 - i))
		"cord": _tube(tube, Vector3.DOWN * 0.5, Vector3.UP * 0.5, 0.007, 0.007)
		"staff":
			_tube(tube, Vector3(0, -0.58, 0), Vector3(0, 0.45, 0), 0.022, 0.023)
			_tube(tube, Vector3(0, 0.45, 0), Vector3(0, 0.50, 0), 0.042, 0.044)
			_tube(tube, Vector3(0, 0.50, 0), Vector3(0, 0.55, 0), 0.044, 0.018)
		"arrow":
			_tube(tube, Vector3.ZERO, Vector3.BACK * (ARROW_LENGTH - 0.065), 0.009, 0.009)
			_tube(tube, Vector3.BACK * 0.056, Vector3.BACK * 0.125, 0.023, 0.009)
			_tube(tube, Vector3.BACK * (ARROW_LENGTH - 0.075), Vector3.BACK * ARROW_LENGTH, 0.021, 0.002)
	tube.generate_normals()
	return tube.commit()


static func _tube(surface: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float) -> void:
	var axis := (b - a).normalized()
	var cross := Vector3.RIGHT if absf(axis.x) < 0.9 else Vector3.BACK
	var frame := LegionFighter._basis(axis, cross)
	for i in 6:
		var u := frame.x.rotated(axis, i * TAU / 6.0)
		var v := frame.x.rotated(axis, (i + 1) * TAU / 6.0)
		for vertex: Vector3 in [a + u * r0, a + v * r0, b + v * r1, a + u * r0, b + v * r1, b + u * r1]:
			surface.add_vertex(vertex)
