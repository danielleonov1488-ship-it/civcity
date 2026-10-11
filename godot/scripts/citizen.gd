class_name Citizen
extends Node3D
## Житель — персонаж Synty Ancient Empire (рабочие, фермеры, патриции, политик) с движениями из бесплатной
## библиотеки Quaternius. Оба скелета при импорте приведены к общему стандарту (BoneMap → гуманоид),
## поэтому движения подходят без переделки. Текстура — общая палитра Synty; вариант палитры (A/B/C)
## меняет цвета одежды.

const DIR := "res://assets/synty/FBX/Characters/Unreal_Characters/"
const PLEBS := ["SK_Chr_Worker_Male_01", "SK_Chr_Worker_Female_01", "SK_Chr_Farmer_Male_01", "SK_Chr_Farmer_Female_01"]
const RICH := ["SK_Chr_Upperclass_Male_01", "SK_Chr_Upperclass_Female_01", "SK_Chr_Politician_Male_01"]
const FEMALE := ["SK_Chr_Worker_Female_01", "SK_Chr_Farmer_Female_01", "SK_Chr_Upperclass_Female_01", "SK_Chr_Soldier_Female_02"]

var anim: AnimationPlayer
var female := false
var _cur := ""

static var _cache := {}
static var _lib: AnimationLibrary
static var _mats := {}


static func _scene(path: String) -> PackedScene:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


## Движения из библиотеки: одна общая на всех жителей
static func library() -> AnimationLibrary:
	if _lib == null:
		var src := _scene("res://assets/people/UAL1_Standard.glb").instantiate()
		var ap: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
		_lib = AnimationLibrary.new()
		for n in ap.get_animation_list():
			var a := ap.get_animation(n).duplicate() as Animation
			var short := String(n).get_slice("/", String(n).get_slice_count("/") - 1)
			if short.ends_with("_Loop") or short in ["Walk", "Idle", "Idle_Talking", "Sitting_Idle", "Sitting_Talking", "Driving", "Walk_Formal", "Jog_Fwd", "Push", "Crouch_Idle"]:
				a.loop_mode = Animation.LOOP_LINEAR
			_lib.add_animation(short.trim_suffix("_Loop"), a)
		src.free()
	return _lib


static func _material(variant: String) -> StandardMaterial3D:
	if not _mats.has(variant):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(Synty._tex_path("PolygonAncientEmpire_01_" + variant))
		m.roughness = 0.85
		_mats[variant] = m
	return _mats[variant]


## rich — патриций; child — ребёнок (уменьшенный взрослый)
static func create(rng: RandomNumberGenerator, is_female: bool, child := false, rich := false) -> Citizen:
	Synty._index()
	var c := Citizen.new()
	var pool: Array = RICH if rich else PLEBS
	var choices := pool.filter(func(n): return (n in FEMALE) == is_female)
	if choices.is_empty():
		choices = pool
	var name: String = choices[rng.randi() % choices.size()]
	c.female = name in FEMALE
	var body := _scene(DIR + name + ".fbx").instantiate() as Node3D
	c.add_child(body)
	var variant: String = ["A", "A", "B", "C"][rng.randi() % 4]
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = _material(variant)
	# причёска (и борода у части мужчин) — на кости головы
	var sk: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	var hairs: Array = ["SM_Chr_Hair_Female_0%d" % (1 + rng.randi() % 6)] if c.female else ["SM_Chr_Hair_Male_0%d" % (1 + rng.randi() % 7)]
	if not c.female and rng.randf() < 0.45:
		hairs.append("SM_Chr_Hair_Beard_0%d" % (1 + rng.randi() % 4))
	if rich and rng.randf() < 0.3:
		hairs.append("SM_Chr_Attach_Crown_Leaf_0%d" % (1 + rng.randi() % 2))
	var att := BoneAttachment3D.new()
	att.bone_name = "Head"
	sk.add_child(att)
	for h in hairs:
		var hn := _scene("res://assets/synty/FBX/Attachments/" + h + ".fbx").instantiate() as Node3D
		for mi: MeshInstance3D in hn.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = _material(variant)
		att.add_child(hn)
	c.anim = AnimationPlayer.new()
	body.add_child(c.anim)
	c.anim.root_node = NodePath("..")
	c.anim.add_animation_library("", library())
	c.anim.speed_scale = rng.randf_range(0.92, 1.08)
	if child:
		c.scale = Vector3.ONE * 0.68
	return c


func play(name: String, blend := 0.25) -> void:
	if name == _cur:
		return
	_cur = name
	var short := name.trim_suffix("_Loop")
	if anim.has_animation(short):
		anim.play(short, blend)
	elif anim.has_animation(name):
		anim.play(name, blend)


## Совместимость со старым кодом: относительное преобразование узла внутри предка top
static func _rel(n: Node3D, top: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var p: Node = n
	while p != top and p is Node3D:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf
