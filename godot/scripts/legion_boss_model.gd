extends Node3D
## Составные боссы, верховые животные и связанная с ними оснастка.

const ASSETS := "res://assets/legion_enemies/"
const HORSE := "res://assets/animals/Horse_b.glb"
const MODELS := {
	"minotaur": ["minotaur", 2.10, 0.91, 53.0, false, "Walk"],
	"cyclops": ["cyclops", 1.98, 0.94, 45.0, false, "Walk"],
	"elephant": ["elephant", 2.71, 0.78, 65.0, true, "Walk"],
	"chariot": ["chariot", 2.01, 0.82, 73.0, true, "Run"],
	"charioteer": ["charioteer", 2.01, 0.77, 73.0, true, "Run"],
	"horseArcher": ["", 2.43, 0.95, 64.0, true, "Run"],
	"cataphract": ["", 2.54, 0.88, 65.0, true, "Walk"],
}
const CREW := {
	"elephant": [["elephant_driver", "Driver", 0.47, "B"]],
	"chariot": [["chariot_driver", "Driver", 0.72, "A"]],
	"charioteer": [["royal_driver", "Driver", 0.72, "A"], ["royal_guard", "Passenger", 0.71, "B"]],
	"horseArcher": [["horse_archer", "Back", 0.72, "B"]],
	"cataphract": [["cataphract", "Back", 0.75, "A"]],
}
const HORSE_CLIPS := {"Idle": "Idle", "Walk": "Walk", "Run": "Gallop", "Windup": "Idle",
	"Attack": "Attack_Headbutt", "Charge": "Gallop", "Hit": "Idle_HitReact_Left", "Death": "Death"}
const REINS := Color("5a3a25")

static var _packs: Dictionary = {}
static var _leather: StandardMaterial3D

var key: String
var problem := ""
var main_player: AnimationPlayer
var rig: Skeleton3D
var horses: Array[Node3D] = []
var mounts: Array[AnimationPlayer] = []
var riders: Array[AnimationPlayer] = []
var rider_rigs: Array[Skeleton3D] = []
var mouth: Array[Node3D] = []
var wheels: PackedInt32Array = []
var wheel_angle := 0.0
var moving := false
var _wheel_rest: Array[Quaternion] = []
var _seats: Array[Node3D] = []
var _seat_positions: Array[Vector3] = []
var _seat_mounts: Array[BoneAttachment3D] = []
var _rider_scale: Array[float] = []
var _reins := ImmediateMesh.new()
var _reins_view: MeshInstance3D
var _last_horse_clip := ""
var _last_horse_base := 0.0


static func _scene(path: String) -> PackedScene:
	if not _packs.has(path) and ResourceLoader.exists(path, "PackedScene"):
		_packs[path] = load(path)
	return _packs.get(path) as PackedScene


static func _crew_file(part: String) -> String:
	return ASSETS + "local_boss_" + part + ".glb"


static func prewarm(id: String) -> void:
	var profile: Array = MODELS[id]
	if not String(profile[0]).is_empty():
		_scene(ASSETS + String(profile[0]) + ".glb")
	for entry: Array in CREW.get(id, []):
		_scene(_crew_file(String(entry[0])))
	if id in ["chariot", "charioteer", "horseArcher", "cataphract"]:
		_scene(HORSE)
	if id == "cataphract":
		_scene(ASSETS + "horse_scale.glb")
		_scene(ASSETS + "horse_chamfron.glb")


func _fail(reason: String) -> bool:
	problem = reason
	return false


func _first(root: Node, type: String) -> Node:
	var found := root.find_children("*", type, true, false)
	return null if found.is_empty() else found[0]


func _spawn(path: String, parent: Node3D, label: String) -> Node3D:
	var scene := _scene(path)
	if scene == null:
		problem = "missing GLB " + path
		return null
	var node := scene.instantiate() as Node3D
	node.name = label
	parent.add_child(node)
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.custom_aabb = AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))
		var arrays := mesh.mesh as ArrayMesh
		if arrays == null:
			continue
		for surface in arrays.get_surface_count():
			var mat := mesh.get_active_material(surface) as StandardMaterial3D
			if mat != null and (arrays.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR) != 0:
				mat.vertex_color_use_as_albedo = true
	return node


func _player(root: Node3D) -> AnimationPlayer:
	var player := _first(root, "AnimationPlayer") as AnimationPlayer
	if player != null:
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return player


func build(id: String) -> bool:
	key = id
	var profile: Array = MODELS[id]
	var stem := String(profile[0])
	if not stem.is_empty():
		var body := _spawn(ASSETS + stem + ".glb", self, "BossBody")
		if body == null:
			return false
		main_player = _player(body)
		rig = _first(body, "Skeleton3D") as Skeleton3D
		if main_player == null or rig == null:
			return _fail("boss animation or skeleton missing")
		for bone: String in ["WheelL", "WheelR"]:
			var joint := rig.find_bone(bone)
			if joint >= 0:
				wheels.append(joint)
				_wheel_rest.append(rig.get_bone_rest(joint).basis.get_rotation_quaternion())
	match id:
		"chariot":
			if not _add_horse(Vector3(0, 0, 1.77), 0.41):
				return false
		"charioteer":
			if not _add_horse(Vector3(-0.43, 0, 1.79), 0.41) or not _add_horse(Vector3(0.43, 0, 1.79), 0.41):
				return false
		"horseArcher", "cataphract":
			if not _add_horse(Vector3.ZERO, 0.50):
				return false
	var carrier := rig
	if id in ["horseArcher", "cataphract"]:
		carrier = _first(horses[0], "Skeleton3D") as Skeleton3D
	for entry: Array in CREW.get(id, []):
		if not _add_rider(carrier, entry):
			return false
	if id == "cataphract":
		if not _add_armor(carrier, "Back", "horse_scale") or not _add_armor(carrier, "Head", "horse_chamfron"):
			return false
	if id in ["chariot", "charioteer"]:
		_reins_view = MeshInstance3D.new()
		_reins_view.name = "LeatherReins"
		_reins_view.mesh = _reins
		_reins_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_reins_view)
	return true


func _add_horse(at: Vector3, size: float) -> bool:
	var horse := _spawn(HORSE, self, "Horse%d" % horses.size())
	if horse == null:
		return false
	horse.position = at
	horse.scale = Vector3.ONE * size
	var player := _player(horse)
	var skeleton := _first(horse, "Skeleton3D") as Skeleton3D
	if player == null or skeleton == null:
		return _fail("horse animation or skeleton missing")
	var anchor := _anchor(skeleton, "Head")
	if anchor == null:
		return false
	var bit := Node3D.new()
	bit.name = "Bit"
	anchor.add_child(bit)
	bit.transform = _local_rest(skeleton, anchor.bone_idx, Transform3D(Basis.IDENTITY,
		at + Vector3(0, 3.64, 3.30) * size))
	mouth.append(bit)
	horses.append(horse)
	mounts.append(player)
	return true


func _anchor(skeleton: Skeleton3D, bone: String) -> BoneAttachment3D:
	if skeleton == null or skeleton.find_bone(bone) < 0:
		problem = "missing socket " + bone
		return null
	var anchor := BoneAttachment3D.new()
	anchor.name = bone + "Socket"
	skeleton.add_child(anchor)
	anchor.bone_name = bone
	return anchor


func _local_rest(skeleton: Skeleton3D, joint: int, desired: Transform3D) -> Transform3D:
	var rest := Citizen._rel(skeleton, self) * skeleton.get_bone_global_rest(joint)
	return rest.affine_inverse() * desired


func _add_rider(skeleton: Skeleton3D, entry: Array) -> bool:
	var joint := String(entry[1])
	var socket := _anchor(skeleton, joint)
	if socket == null:
		return false
	var scale := float(entry[2])
	var seat := Node3D.new()
	seat.name = "Seat"
	socket.add_child(seat)
	var rest := Citizen._rel(skeleton, self) * skeleton.get_bone_global_rest(socket.bone_idx)
	var at := rest.origin
	if joint == "Back":
		at = Vector3(0, 1.72 - 0.876 * scale, -0.21)
	elif key == "elephant":
		at += Vector3(0, -0.876 * scale, 0.015)
	seat.transform = rest.affine_inverse() * Transform3D(Basis.from_scale(Vector3.ONE * scale), at)
	var crew := _spawn(_crew_file(String(entry[0])), seat, "Rider")
	if crew == null:
		return false
	var atlas := Citizen._plain(String(entry[3]))
	for mesh: MeshInstance3D in crew.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = atlas
	var player := _player(crew)
	var sk := _first(crew, "Skeleton3D") as Skeleton3D
	if player == null or sk == null:
		return _fail("rider animation or skeleton missing")
	_seats.append(seat)
	_seat_positions.append(at)
	_seat_mounts.append(socket)
	_rider_scale.append(scale)
	riders.append(player)
	rider_rigs.append(sk)
	return true


func _add_armor(skeleton: Skeleton3D, joint: String, model: String) -> bool:
	var socket := _anchor(skeleton, joint)
	if socket == null:
		return false
	var armor := _spawn(ASSETS + model + ".glb", socket, model)
	if armor == null:
		return false
	armor.transform = _local_rest(skeleton, socket.bone_idx, Transform3D.IDENTITY)
	return true


func clip_length(clip: String) -> float:
	var player: AnimationPlayer = main_player if main_player != null else riders[0]
	return player.get_animation(clip).length if player.has_animation(clip) else 0.0


static func _sample(player: AnimationPlayer, clip: String, time: float, wrapped: bool) -> void:
	if not player.has_animation(clip):
		return
	var length := player.get_animation(clip).length
	if player.assigned_animation != clip or not player.is_playing():
		player.play(clip, 0.0)
	player.seek(fposmod(time, length) if wrapped else clampf(time, 0.0, length), true)


func _sync_rider_seat(i: int, clip: String, phase: float) -> void:
	var socket := _seat_mounts[i]
	var seat := _seats[i]
	if socket.bone_name != "Back" or clip != "Death":
		return
	# Седло следует коню. Всадник при падении уходит вбок от него.
	var k := smoothstep(0.17, 0.83, phase)
	var drop := _seat_positions[i] + Vector3(-0.86 * k, -0.94 * k, -0.24 * k)
	seat.transform = socket.global_transform.affine_inverse() * global_transform * Transform3D(
		Basis(Vector3.FORWARD, 1.46 * k).scaled(Vector3.ONE * _rider_scale[i]), drop)
	seat.set_meta("fallen", true)


func pose_at(clip: String, elapsed: float) -> bool:
	var length := clip_length(clip)
	if length <= 0.0:
		return false
	var looping := clip in ["Idle", "Walk", "Run"]
	var phase := (fposmod(elapsed, length) if looping else minf(elapsed, length)) / length
	if main_player != null:
		_sample(main_player, clip, elapsed, looping)
	if not mounts.is_empty():
		var horse_clip: String = HORSE_CLIPS[clip]
		var horse_time := elapsed
		if key == "horseArcher" and clip in ["Windup", "Attack"]:
			horse_clip = "Gallop" if moving else "Idle"
			if _last_horse_clip != clip:
				_last_horse_base = mounts[0].current_animation_position
			horse_time = _last_horse_base + elapsed
		for i in mounts.size():
			var player := mounts[i]
			if not player.has_animation(horse_clip):
				horse_clip = "Idle"
			var cycle := horse_clip in ["Idle", "Walk", "Gallop"]
			var t := horse_time * (0.87 + float(i) * 0.02) + i * 0.16 if cycle else phase * player.get_animation(horse_clip).length
			_sample(player, horse_clip, t, cycle)
		_last_horse_clip = clip
	for i in riders.size():
		var player := riders[i]
		_sample(player, clip, phase * player.get_animation(clip).length, looping)
		_sync_rider_seat(i, clip, phase)
		if clip != "Death" and _seats[i].has_meta("fallen"):
			_seats[i].remove_meta("fallen")
			var socket := _seat_mounts[i]
			_seats[i].transform = _local_rest(socket.get_parent() as Skeleton3D, socket.bone_idx,
				Transform3D(Basis.from_scale(Vector3.ONE * _rider_scale[i]), _seat_positions[i]))
	_turn_wheels()
	if _reins_view != null:
		_draw_reins(clip != "Death" or phase < 0.27)
	return true


func roll(distance: float) -> void:
	if wheels.is_empty() or is_zero_approx(distance):
		return
	wheel_angle = fposmod(wheel_angle + distance / 0.522, TAU)
	_turn_wheels()


func _turn_wheels() -> void:
	for i in wheels.size():
		rig.set_bone_pose_rotation(wheels[i], _wheel_rest[i] * Quaternion(Vector3.RIGHT, -wheel_angle))


func _bone_global(skeleton: Skeleton3D, joint: String) -> Vector3:
	var bone := skeleton.find_bone(joint)
	return skeleton.global_position if bone < 0 else skeleton.to_global(skeleton.get_bone_global_pose(bone).origin)


func launch_point() -> Vector3:
	if key == "cyclops":
		return _bone_global(rig, "Rock")
	return _bone_global(rider_rigs[0], "hand_l")


func _draw_reins(held: bool) -> void:
	_reins.clear_surfaces()
	if not held:
		return
	if _leather == null:
		_leather = StandardMaterial3D.new()
		_leather.albedo_color = REINS
		_leather.cull_mode = BaseMaterial3D.CULL_DISABLED
		_leather.roughness = 1.0
	var hand := to_local(_bone_global(rider_rigs[0], "hand_l"))
	_reins.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _leather)
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var bit := to_local(mouth[mini(i, mouth.size() - 1)].global_position) + Vector3(s * 0.075, 0, 0)
		var last := hand + Vector3(s * 0.026, 0, 0)
		for n in range(1, 7):
			var k := float(n) / 6.0
			var point := hand.lerp(bit, k) - Vector3.UP * (0.12 * sin(k * PI))
			for edge: Vector3 in [Vector3(0.012, 0, 0), Vector3(0, 0.012, 0)]:
				for v: Vector3 in [last-edge, last+edge, point+edge, last-edge, point+edge, point-edge]:
					_reins.surface_add_vertex(v)
			last = point
	_reins.surface_end()

