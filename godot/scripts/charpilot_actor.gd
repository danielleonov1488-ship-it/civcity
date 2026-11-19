extends Node3D
## Постоянный облик и сменные группы одежды для пилота.

const QUATERNIUS := "res://assets/quaternius/"
const HELMET := "res://assets/synty/FBX/Attachments/SM_Chr_Attach_Helmet_03.fbx"
const KIT := "res://assets/legion_chars/"
const BONE_MAP := preload("res://assets/rig/bonemap_synty.tres")
const A_STYLES := ["peasant", "worker", "legionary"]
const STYLES := ["peasant", "worker", "legionary", "centurion", "patrician", "toga",
	"cook", "smith", "archer", "priest"]
const EXTRA := {
	"legionary": ["outfit_legionary_helmet", "outfit_legionary_cape"],
	"centurion": ["outfit_centurion_skirt", "outfit_centurion_helmet", "outfit_centurion_cape"],
	"cook": ["under_cook", "outfit_cook_apron", "outfit_cook_cap"],
	"smith": ["under_smith", "outfit_smith_apron", "outfit_smith_bracers"],
	"archer": ["under_archer", "outfit_archer_cuirass", "outfit_archer_bracers", "outfit_archer_quiver", "outfit_archer_bow"],
	"priest": ["under_priest", "outfit_priest_veil"],
}
const RIGHT_HAND := ["hand_r", "RightHand"]
const LEFT_HAND := ["hand_l", "LeftHand"]
const HIPS := ["pelvis", "Hips"]
const WORKER := ["SK_Chr_Worker_Male_01", "SK_Chr_Worker_Female_01"]

var identity: Array[MeshInstance3D] = []
var problem := ""
var _plain: Array[MeshInstance3D] = []
var _armor: Array[MeshInstance3D] = []
var _work: Node3D
var _helmet: Node3D
var _sword: Node3D
var _shield: Node3D
var _hammer: Node3D
var _rig: Skeleton3D
var _groups: Dictionary = {}
var _players: Array[AnimationPlayer] = []
var _family := 0
var _female := false
var _outfit := ""
static var _kit_cache: Dictionary = {}


func build(family: int, female: bool, variant: String) -> bool:
	_family = family
	_female = female
	if not (_build_quaternius() if family == 0 else _build_synty(variant)):
		return false
	if identity.is_empty() or (family == 0 and (_plain.is_empty() or _armor.is_empty())):
		return _fail("identity or outfit mesh missing")
	for bone: String in ["Head", HIPS[family], RIGHT_HAND[family], LEFT_HAND[family]]:
		if _rig.find_bone(bone) == -1:
			return _fail("missing bone " + bone)
	if not pose_at("Interact", 0.55) or not _add_work():
		return false
	if not pose_at("Sword_Idle", 0.0) or not _add_gear(variant):
		return false
	return set_outfit("peasant") and pose_at("Idle", 0.0)


func _fail(reason: String) -> bool:
	problem = reason
	return false


func _build_quaternius() -> bool:
	var path := QUATERNIUS + ("PilotFemale.gltf" if _female else "PilotMale.gltf")
	var pack := load(path) as PackedScene
	if pack == null:
		return _fail("cannot load " + path)
	var model := pack.instantiate() as Node3D
	add_child(model)
	for node: Skeleton3D in model.find_children("*", "Skeleton3D", true, false):
		_rig = node
		break
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if _rig == null or players.is_empty():
		return _fail("Quaternius skeleton or clips missing")
	_register_player(players[0] as AnimationPlayer)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var part := String(mesh.name)
		if part.begins_with("Identity_"):
			identity.append(mesh)
		elif part.begins_with("Peasant_"):
			_plain.append(mesh)
		elif part.begins_with("Ranger_"):
			_armor.append(mesh)
	return true


func _build_synty(variant: String) -> bool:
	var path: String = Citizen.DIR + WORKER[int(_female)] + ".fbx"
	if not ResourceLoader.exists(path, "PackedScene"):
		return _fail("local Synty skeleton missing " + path)
	var source := (load(path) as PackedScene).instantiate() as Node3D
	add_child(source)
	var rigs := source.find_children("*", "Skeleton3D", true, false)
	if rigs.is_empty():
		return _fail("Synty skeleton missing")
	_rig = rigs[0] as Skeleton3D
	if _rig.find_bone("Hips") < 0 or _rig.find_bone("Head") < 0:
		return _fail("Synty skeleton is not retargeted")
	for mesh: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		mesh.hide()
	var player := AnimationPlayer.new()
	source.add_child(player)
	player.root_node = NodePath("..")
	player.add_animation_library("", Citizen.library())
	_register_player(player)
	Synty._index()
	var atlas := Citizen._plain(variant)
	if atlas.albedo_texture == null:
		return _fail("local Synty atlas missing")
	var suffix := "_f" if _female else "_m"
	var base := Node3D.new()
	base.name = "Identity"
	_rig.add_child(base)
	if not _add_kit_file("base" + suffix, base, atlas):
		return false
	identity.assign(base.get_children())
	for outfit: String in STYLES:
		var group := Node3D.new()
		group.name = outfit
		_rig.add_child(group)
		_groups[outfit] = group
		if not _add_kit_file("outfit_" + outfit + suffix, group, atlas):
			return false
		for extra: String in EXTRA.get(outfit, []):
			if not _add_kit_file(extra + suffix, group, atlas):
				return false
	return true


## В GLB свои оси костей. Привязываем его вершины к живому скелету по именам и общей позе покоя.
func _add_kit_file(stem: String, group: Node3D, atlas: Material) -> bool:
	var entries := _kit_file(stem)
	if entries.is_empty():
		return _fail("missing or unskinned kit GLB " + stem)
	var rig_from_model := Citizen._rel(_rig, self).affine_inverse()
	for entry: Dictionary in entries:
		var model_from_mesh: Transform3D = entry["transform"]
		var rig_from_mesh := rig_from_model * model_from_mesh
		var names: PackedStringArray = entry["bones"]
		var used: Dictionary = entry["used"]
		var skin := Skin.new()
		skin.set_bind_count(names.size())
		for i in names.size():
			var mapped: StringName = BONE_MAP.find_profile_bone_name(StringName(names[i]))
			var bone := _rig.find_bone(mapped if mapped != &"" else StringName(names[i]))
			if bone < 0:
				if used.has(i):
					return _fail("%s missing weighted bone %s" % [stem, names[i]])
				bone = _rig.find_bone("Hips")
			skin.set_bind_bone(i, bone)
			skin.set_bind_pose(i, _rig.get_bone_global_rest(bone).affine_inverse() * rig_from_mesh)
		var part := MeshInstance3D.new()
		part.name = entry["name"]
		part.mesh = entry["mesh"]
		part.material_override = atlas
		part.skin = skin
		part.custom_aabb = AABB(Vector3(-1.3, -0.4, -1.1), Vector3(2.6, 3.0, 2.2))
		part.skeleton = NodePath("../..")
		group.add_child(part)
	return true


static func _kit_file(stem: String) -> Array:
	if _kit_cache.has(stem):
		return _kit_cache[stem]
	var path := KIT + stem + ".glb"
	var entries: Array = []
	if not ResourceLoader.exists(path, "PackedScene"):
		return entries
	var root := (load(path) as PackedScene).instantiate() as Node3D
	for part: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if part.skin == null or part.mesh == null:
			continue
		var source_rig := part.get_node_or_null(part.skeleton) as Skeleton3D
		var names := PackedStringArray()
		for i in part.skin.get_bind_count():
			var bone := part.skin.get_bind_name(i)
			if bone == &"" and source_rig != null and part.skin.get_bind_bone(i) >= 0:
				bone = source_rig.get_bone_name(part.skin.get_bind_bone(i))
			names.append(String(bone))
		var used := {}
		for surface in part.mesh.get_surface_count():
			var arrays := part.mesh.surface_get_arrays(surface)
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			for i in weights.size():
				if weights[i] > 0.0:
					used[bones[i]] = true
		entries.append({"mesh": part.mesh, "name": part.name, "bones": names,
			"transform": Citizen._rel(part, root), "used": used})
	root.free()
	if not entries.is_empty():
		_kit_cache[stem] = entries
	return entries


func _register_player(player: AnimationPlayer) -> void:
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_players.append(player)


func pose_at(clip: String, elapsed: float) -> bool:
	for player: AnimationPlayer in _players:
		var found := &""
		for key in player.get_animation_list():
			var bare := String(key).get_file().to_lower().trim_suffix("_loop")
			if bare == clip.to_lower():
				found = StringName(key)
				break
		if found == &"":
			return _fail("missing animation " + clip)
		if player.assigned_animation != found or not player.is_playing():
			player.play(found, 0.0)
		player.seek(fposmod(elapsed, player.get_animation(found).length), true)
	return true


func set_outfit(outfit: String) -> bool:
	if outfit == "soldier":
		outfit = "legionary"
	if outfit not in (A_STYLES if _family == 0 else STYLES):
		return _fail("unknown outfit " + outfit)
	_outfit = outfit
	var soldier := outfit in ["legionary", "centurion"]
	if _family == 1:
		for name: String in _groups:
			var group: Node3D = _groups[name]
			group.visible = name == outfit
		_sword.visible = soldier
		_shield.visible = soldier
		_hammer.visible = outfit in ["worker", "smith"]
		return true
	for mesh in _plain:
		mesh.visible = not soldier
	for mesh in _armor:
		mesh.visible = soldier
	for item: Node3D in [_helmet, _sword, _shield]:
		item.visible = soldier
	for item: Node3D in [_work, _hammer]:
		item.visible = outfit == "worker"
	return true


func has_outfit(outfit: String) -> bool:
	if outfit == "soldier":
		outfit = "legionary"
	var soldier := outfit in ["legionary", "centurion"]
	if _family == 1:
		if _outfit != outfit or not _groups.has(outfit):
			return false
		for name: String in _groups:
			var group: Node3D = _groups[name]
			if group.visible != (name == outfit) or group.get_child_count() == 0:
				return false
		return _sword.visible == soldier and _shield.visible == soldier and _hammer.visible == (outfit in ["worker", "smith"])
	var worker := outfit == "worker"
	return (_outfit == outfit
		and _plain[0].visible == (not soldier) and _armor[0].visible == soldier
		and _helmet.visible == soldier and _sword.visible == soldier and _shield.visible == soldier
		and _work.visible == worker and _hammer.visible == worker)


func _bone_frame(rig: Skeleton3D, bone: String, rest: bool) -> Transform3D:
	var index := rig.find_bone(bone)
	var pose := rig.get_bone_global_rest(index) if rest else rig.get_bone_global_pose(index)
	return Citizen._rel(rig, self) * pose


func _mount(bone: String, item: Node3D, frame: Transform3D, target: Transform3D) -> void:
	var socket := BoneAttachment3D.new()
	socket.bone_name = bone
	_rig.add_child(socket)
	var holder := Node3D.new()
	socket.add_child(holder)
	holder.transform = frame.affine_inverse() * target
	holder.add_child(item)


func _add_work() -> bool:
	if _family == 0:
		var apron := MeshInstance3D.new()
		apron.mesh = _apron_mesh()
		_work = apron
		var hips: String = HIPS[_family]
		_mount(hips, apron, _bone_frame(_rig, hips, true), Transform3D.IDENTITY)
	_hammer = Synty.make("SM_Prop_Tool_Hammer_01")
	if not _has_mesh(_hammer):
		return _fail("hammer missing")
	var hand: String = RIGHT_HAND[_family]
	var frame := _bone_frame(_rig, hand, false)
	var direction := Vector3(0.0, 0.55, -0.84).normalized()
	var grip := LegionFighter._basis(Vector3.UP, direction).scaled(Vector3.ONE * 0.85)
	_mount(hand, _hammer, frame, Transform3D(grip, frame.origin - grip.z * 0.17))
	return true


func _add_gear(variant: String) -> bool:
	if _family == 0:
		var pack := load(HELMET) as PackedScene
		if pack == null:
			return _fail("Roman helmet missing")
		_helmet = pack.instantiate() as Node3D
		for mesh: MeshInstance3D in _helmet.find_children("*", "MeshInstance3D", true, false):
			mesh.material_override = Citizen._plain(variant)
		var rest := _bone_frame(_rig, "Head", true)
		var helmet_at := rest.origin + Vector3(0.0, 0.018, 0.02)
		_mount("Head", _helmet, rest, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.72), helmet_at))
	_sword = Synty.make("SM_Wep_Sword_01")
	_shield = Synty.make("SM_Wep_Shield_04")
	if not (_has_mesh(_sword) and _has_mesh(_shield)) or (_family == 0 and not _has_mesh(_helmet)):
		return _fail("Roman gear mesh missing")
	var right: String = RIGHT_HAND[_family]
	var left: String = LEFT_HAND[_family]
	var sword_frame := _bone_frame(_rig, right, false)
	var shield_frame := _bone_frame(_rig, left, false)
	var sword_grip := LegionFighter._basis(Vector3(-0.18, 0.87, 0.46), Vector3.FORWARD).scaled(Vector3.ONE * 0.72)
	var shield_grip := LegionFighter._basis(Vector3(0.0, 1.0, 0.1), Vector3(0.35, 0.0, 1.0)).scaled(Vector3.ONE * 0.72)
	_mount(right, _sword, sword_frame, Transform3D(sword_grip, sword_frame.origin + Vector3(-0.025, 0.015, 0.035)))
	_mount(left, _shield, shield_frame, Transform3D(shield_grip, shield_frame.origin + Vector3(0.13, 0.05, 0.12)))
	return true


static func _has_mesh(item: Node3D) -> bool:
	return item is MeshInstance3D or not item.find_children("*", "MeshInstance3D", true, false).is_empty()


func _apron_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color("467278")
	leather.roughness = 0.9
	leather.cull_mode = BaseMaterial3D.CULL_DISABLED
	tool.set_material(leather)
	var up := 0.04 if not _female else 0.0
	var front := 0.176
	var rows := PackedVector2Array([Vector2(0.11, 1.37 + up), Vector2(0.132, 1.15 + up),
		Vector2(0.203, 1.10 + up), Vector2(0.21, 0.76 + up)])
	for row in rows.size() - 1:
		for side: float in [-1.0, 1.0]:
			var top := rows[row]
			var low := rows[row + 1]
			var a := Vector3(0.0, top.y, front)
			var b := Vector3(side * top.x, top.y, front - 0.055)
			var c := Vector3(side * low.x, low.y, front - 0.055)
			var d := Vector3(0.0, low.y, front)
			var face := [a, b, c, a, c, d] if side > 0.0 else [a, c, b, a, d, c]
			for vertex: Vector3 in face:
				tool.add_vertex(vertex)
	tool.generate_normals()
	return tool.commit()
