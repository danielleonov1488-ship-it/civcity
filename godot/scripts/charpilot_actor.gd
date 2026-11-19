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
	"archer": ["under_archer", "outfit_archer_cuirass", "outfit_archer_bracers", "outfit_archer_quiver"],
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
var _extra_helmet: Node3D
var _sword: Node3D
var _shield: Node3D
var _back_shield: Node3D
var _hair: Node3D
var _kit_hair: MeshInstance3D
var _bow: Node3D
var _hammer: Node3D
var _rig: Skeleton3D
var _groups: Dictionary = {}
var _players: Array[AnimationPlayer] = []
var _family := 0
var _female := false
var _outfit := ""
var _atlas: Material
var _clips: Dictionary = {}
var _clip_lengths: Dictionary = {}
var _sample_time := -INF
var _sample_clip := ""
var _faded_meshes: Array[Node] = []
var _fade_materials: Array[Dictionary] = []
var _opacity := 1.0
static var _kit_cache: Dictionary = {}
static var _bound_skins: Dictionary = {}


func build(family: int, female: bool, variant: String, look := {}, outfit := "peasant") -> bool:
	_family = family
	_female = female
	if not (_build_quaternius() if family == 0 else _build_synty(variant, look)):
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
	return set_outfit(outfit) and pose_at("Idle", 0.0)


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


func _build_synty(variant: String, look: Dictionary) -> bool:
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
		mesh.free()
	if not ResourceLoader.exists("res://assets/people/UAL1_Standard.glb", "PackedScene"):
		return _fail("local UAL animations missing")
	var player := AnimationPlayer.new()
	source.add_child(player)
	player.root_node = NodePath("..")
	player.add_animation_library("", Citizen.library())
	_register_player(player)
	Synty._index()
	_atlas = Citizen._plain(variant)
	if (_atlas as StandardMaterial3D).albedo_texture == null:
		return _fail("local Synty atlas missing")
	var base := Node3D.new()
	base.name = "Identity"
	_rig.add_child(base)
	if not _add_kit_file("base" + _suffix(), base, _atlas):
		return false
	identity.assign(base.get_children())
	for part: MeshInstance3D in identity:
		if String(part.name).begins_with("Identity_Hair"):
			_kit_hair = part
			break
	if not look.is_empty():
		_set_hair(look, variant)
	return true


func _suffix() -> String:
	return "_f" if _female else "_m"


func _set_hair(look: Dictionary, variant: String) -> void:
	var hair := int(look["hair"])
	var color := String(look["hair_color"])
	var kit_hair := 1 if _female else 2
	if _kit_hair != null and hair == kit_hair:
		_kit_hair.material_override = Citizen._hair_mat(color, variant)
	else:
		if _kit_hair != null:
			identity.erase(_kit_hair)
			_kit_hair.free()
			_kit_hair = null
		if hair > 0:
			var sex := "Female" if _female else "Male"
			_hair = _head_piece("%s_%02d" % [sex, hair], color, variant)
	var beard := int(look.get("beard", 0))
	if not _female and beard > 0:
		_head_piece("Beard_%02d" % beard, color, variant, true)


func _head_piece(part: String, color: String, variant: String, beard := false) -> Node3D:
	var path := "res://assets/synty/FBX/Attachments/SM_Chr_Hair_" + part + ".fbx"
	if not ResourceLoader.exists(path, "PackedScene"):
		return null
	var piece := (load(path) as PackedScene).instantiate() as Node3D
	# Точка крепления исходной причёски из CHARKIT в общей позе покоя.
	var at := Transform3D(Basis.IDENTITY, Vector3(0.0, 1.5691, -0.0048))
	_mount("Head", piece, _bone_frame(_rig, "Head", true), at)
	Citizen.paint_hair(piece, color, variant, beard)
	for mesh: MeshInstance3D in piece.find_children("*", "MeshInstance3D", true, false):
		identity.append(mesh)
	return piece


func _load_outfit(outfit: String) -> bool:
	if _groups.has(outfit):
		return true
	var group := Node3D.new()
	group.name = outfit
	group.hide()
	_rig.add_child(group)
	if not _add_kit_file("outfit_" + outfit + _suffix(), group, _atlas):
		group.free()
		return false
	for extra: String in EXTRA.get(outfit, []):
		var part := Node3D.new()
		part.name = extra
		group.add_child(part)
		if not _add_kit_file(extra + _suffix(), part, _atlas):
			group.free()
			return false
	_groups[outfit] = group
	_faded_meshes.clear()
	_fade_materials.clear()
	return true


## В GLB свои оси костей. Привязываем его вершины к живому скелету по именам и общей позе покоя.
func _add_kit_file(stem: String, group: Node3D, atlas: Material, folder := KIT) -> bool:
	var entries := _kit_file(stem, folder)
	if entries.is_empty():
		return _fail("missing or unskinned kit GLB " + stem)
	var rig_from_model := Citizen._rel(_rig, self).affine_inverse()
	for entry: Dictionary in entries:
		var model_from_mesh: Transform3D = entry["transform"]
		var rig_from_mesh := rig_from_model * model_from_mesh
		var names: PackedStringArray = entry["bones"]
		var key := [_female, names, rig_from_mesh]
		var skin: Skin = _bound_skins.get(key)
		if skin == null:
			var used: Dictionary = entry["used"]
			skin = Skin.new()
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
			_bound_skins[key] = skin
		var part := MeshInstance3D.new()
		part.name = entry["name"]
		part.mesh = entry["mesh"]
		part.material_override = atlas
		part.skin = skin
		part.custom_aabb = AABB(Vector3(-1.3, -0.4, -1.1), Vector3(2.6, 3.0, 2.2))
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.skeleton = NodePath("../..") if group.get_parent() == _rig else NodePath("../../..")
		group.add_child(part)
	return true


static func _kit_file(stem: String, folder := KIT) -> Array:
	var path := folder + stem + ".glb"
	if _kit_cache.has(path):
		return _kit_cache[path]
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
		var mesh: Mesh = part.mesh
		if stem == "base_m" and String(part.name).begins_with("Identity_Head"):
			mesh = _separate_brows(part.mesh)
		entries.append({"mesh": mesh, "name": part.name, "bones": names,
			"transform": Citizen._rel(part, root), "used": used})
	root.free()
	if not entries.is_empty():
		_kit_cache[path] = entries
	return entries


static func _separate_brows(head: Mesh) -> Mesh:
	# В исходной мужской голове обе брови и перемычка используют один образец атласа.
	# Разводим половины этой сетки. Сами глаза, привязки к костям и файлы Synty те же.
	var brow_uv := Vector2(0.05146, 0.81604)
	var surface := SurfaceTool.new()
	surface.create_from(head, 0)
	surface.deindex()
	var arrays := surface.commit_to_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var changed := false
	for i in range(0, vertices.size(), 3):
		if uvs[i].distance_squared_to(brow_uv) > 0.000001:
			continue
		var side := signf(vertices[i].x + vertices[i + 1].x + vertices[i + 2].x)
		for index in range(i, i + 3):
			var v := vertices[index]
			v.x = v.x * 0.49 + side * 0.023
			v.y = 1.695 + (v.y - 1.685) * 0.34
			v.z = 0.127 + (v.z - 0.114) * 0.40
			vertices[index] = v
		changed = true
	if not changed:
		return head
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _register_player(player: AnimationPlayer) -> void:
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for key: String in player.get_animation_list():
		var clip := key.get_file().to_lower().trim_suffix("_loop")
		_clips[clip] = StringName(key)
		_clip_lengths[clip] = player.get_animation(key).length
	_players.append(player)


func pose_at(clip: String, elapsed: float) -> bool:
	var key := clip.to_lower()
	var found := StringName(_clips.get(key, &""))
	if found == &"":
		return _fail("missing animation " + clip)
	for player: AnimationPlayer in _players:
		if player.assigned_animation != found or not player.is_playing():
			player.play(found, 0.0)
		player.seek(fposmod(elapsed, maxf(0.001, float(_clip_lengths[key]))), true)
	return true


func animate(clip: String, elapsed: float) -> void:
	# Видимые позы обновляются с частотой 24 Гц, движение по экрану остаётся плавным.
	var sample := floorf(elapsed * 24.0) / 24.0
	if _sample_clip != clip or _sample_time != sample:
		_sample_clip = clip
		_sample_time = sample
		pose_at(clip, sample)


func clip_length(clip: String) -> float:
	return float(_clip_lengths.get(clip.to_lower(), 0.0))


func set_opacity(value: float) -> void:
	if _opacity == value:
		return
	_opacity = value
	if _faded_meshes.is_empty():
		_faded_meshes = find_children("*", "MeshInstance3D", true, false)
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		for mesh: MeshInstance3D in _faded_meshes:
			mesh.transparency = 1.0 - value
	else:
		_set_material_opacity(value)


func _set_material_opacity(value: float) -> void:
	# На Mobile и Compatibility прозрачность самой сетки не действует.
	if _fade_materials.is_empty():
		for mesh: MeshInstance3D in _faded_meshes:
			if not mesh.is_visible_in_tree():
				continue
			if mesh.material_override != null:
				_add_fade_material(mesh, -1, mesh.material_override, mesh.material_override)
			elif mesh.mesh != null:
				for i in mesh.mesh.get_surface_count():
					_add_fade_material(mesh, i, mesh.get_active_material(i), mesh.get_surface_override_material(i))
	for entry: Dictionary in _fade_materials:
		var mesh: MeshInstance3D = entry["mesh"]
		var material: BaseMaterial3D = entry["fade"]
		var color := material.albedo_color
		color.a = float(entry["alpha"]) * value
		material.albedo_color = color
		var active: Material = entry["original"] if value >= 1.0 else material
		var index := int(entry["surface"])
		if index == -1:
			mesh.material_override = active
		else:
			mesh.set_surface_override_material(index, active)


func _add_fade_material(mesh: MeshInstance3D, index: int, active: Material, original: Material) -> void:
	if active is BaseMaterial3D:
		var faded := active.duplicate() as BaseMaterial3D
		faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_fade_materials.append({"mesh": mesh, "surface": index, "original": original,
			"fade": faded, "alpha": faded.albedo_color.a})


func set_loadout(loadout: Dictionary) -> bool:
	if not set_outfit(String(loadout["outfit"])):
		return false
	var group: Node3D = _groups[_outfit]
	var helmet := group.get_node_or_null("outfit_" + _outfit + "_helmet") as Node3D
	var wants_helmet := bool(loadout.get("helmet", false))
	if helmet != null:
		helmet.visible = wants_helmet
	if wants_helmet and helmet == null and _extra_helmet == null:
		_extra_helmet = Node3D.new()
		_extra_helmet.name = "LegionaryHelmet"
		_rig.add_child(_extra_helmet)
		if not _add_kit_file("outfit_legionary_helmet" + _suffix(), _extra_helmet, _atlas):
			_extra_helmet.free()
			_extra_helmet = null
			return false
		_faded_meshes.clear()
		_fade_materials.clear()
	if _extra_helmet != null:
		_extra_helmet.visible = wants_helmet and helmet == null
	for headwear: String in ["outfit_cook_cap", "outfit_priest_veil"]:
		var part := group.get_node_or_null(headwear) as Node3D
		if part != null:
			part.visible = not wants_helmet
	var hair_visible := not wants_helmet and _outfit not in ["cook", "priest"]
	if _kit_hair != null:
		_kit_hair.visible = hair_visible
	if _hair != null:
		_hair.visible = hair_visible
	_sword.visible = bool(loadout.get("sword", false))
	_hammer.visible = _outfit in ["worker", "smith"] and not _sword.visible
	var shield := bool(loadout.get("shield", false))
	if shield and _outfit == "archer" and _back_shield == null:
		_back_shield = Synty.make("SM_Wep_Shield_04")
		var bone := "UpperChest" if _rig.find_bone("UpperChest") >= 0 else "Hips"
		var grip := LegionFighter._basis(Vector3.UP, Vector3.FORWARD).scaled(Vector3.ONE * 0.66)
		_mount(bone, _back_shield, _bone_frame(_rig, bone, true), Transform3D(grip, Vector3(0.14, 1.08, -0.22)))
		_faded_meshes.clear()
		_fade_materials.clear()
	if _back_shield != null:
		_back_shield.visible = shield and _outfit == "archer"
	_shield.visible = shield and _outfit != "archer"
	return true


func set_outfit(outfit: String) -> bool:
	if outfit == "soldier":
		outfit = "legionary"
	if outfit not in (A_STYLES if _family == 0 else STYLES):
		return _fail("unknown outfit " + outfit)
	if _family == 1 and not _load_outfit(outfit):
		return false
	_outfit = outfit
	var soldier := outfit in ["legionary", "centurion"]
	if _family == 1:
		if _extra_helmet != null:
			_extra_helmet.hide()
		if _back_shield != null:
			_back_shield.hide()
		for name: String in _groups:
			var group: Node3D = _groups[name]
			group.visible = name == outfit
		if outfit == "archer" and _bow == null and not _add_bow():
			return false
		if _bow != null:
			_bow.visible = outfit == "archer"
		var active: Node3D = _groups[outfit]
		var helmet := active.get_node_or_null("outfit_" + outfit + "_helmet") as Node3D
		if helmet != null:
			helmet.show()
		for headwear: String in ["outfit_cook_cap", "outfit_priest_veil"]:
			var part := active.get_node_or_null(headwear) as Node3D
			if part != null:
				part.show()
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
		var loadout: Dictionary = get_meta("loadout", {})
		var shield := _shield.visible or (_back_shield != null and _back_shield.visible)
		return (_sword.visible == bool(loadout.get("sword", soldier)) and shield == bool(loadout.get("shield", soldier))
			and _hammer.visible == (outfit in ["worker", "smith"] and not _sword.visible))
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
	for mesh: MeshInstance3D in item.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if item is MeshInstance3D:
		(item as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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


func _add_bow() -> bool:
	_bow = Artisau.make("Bow", 0.90)
	if not _has_mesh(_bow):
		return _fail("bow missing")
	_bow.name = "ArcherBow"
	_bow.position.y -= 0.45
	var hand: String = LEFT_HAND[_family]
	if not pose_at("Spell_Simple_Idle", 0.2):
		return false
	var frame := _bone_frame(_rig, hand, false)
	var grip := LegionFighter._basis(Vector3(0.0, 1.0, 0.12), Vector3(-1.0, 0.0, 0.0))
	_mount(hand, _bow, frame, Transform3D(grip, frame.origin + Vector3(0, 0.0, 0.03)))
	_faded_meshes.clear()
	_fade_materials.clear()
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
