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

const SIZE := 0.72                   # люди «кукольные», ниже дверей — как в Town to City
var anim: AnimationPlayer
var female := false
var meshes := []
var _cur := ""

static var _cache := {}
static var _lib: AnimationLibrary
static var _mats := {}


static func _scene(path: String) -> PackedScene:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


## Движения из библиотеки: одна общая на всех жителей.
## Кроме готовых движений Quaternius — свои, собранные из них: зеркальные (жест другой рукой, «_M»),
## «Listen» (слушает и кивает), «Look_Around» (оглядывается), «Laugh» (смеётся, плечи трясутся)
static func library() -> AnimationLibrary:
	if _lib == null:
		var src := _scene("res://assets/people/UAL1_Standard.glb").instantiate()
		var ap: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
		_lib = AnimationLibrary.new()
		for n in ap.get_animation_list():
			var a := ap.get_animation(n).duplicate() as Animation
			var short := String(n).get_slice("/", String(n).get_slice_count("/") - 1)
			if short.ends_with("_Loop") or short in ["Walk", "Idle", "Idle_Talking", "Sitting_Idle", "Sitting_Talking", "Driving", "Walk_Formal", "Jog_Fwd", "Push", "Crouch_Idle",
					"Fixing_Kneeling", "Interact", "PickUp_Table", "Spell_Simple_Idle", "Sword_Idle", "Dance", "Idle_Torch", "Crouch_Fwd"]:
				a.loop_mode = Animation.LOOP_LINEAR
			_lib.add_animation(short.trim_suffix("_Loop"), a)
		src.free()
		_derive(_lib)
	return _lib


## Плавный горбик: 0 вне [a, b], 1 в середине
static func _bump(t: float, a: float, b: float) -> float:
	if t <= a or t >= b:
		return 0.0
	return sin(PI * (t - a) / (b - a))


## Кусочно-гладкая кривая по точкам [[время, значение], …]
static func _curve(t: float, pts: Array) -> float:
	for i in pts.size() - 1:
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		if t <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), smoothstep(float(a[0]), float(b[0]), t))
	return float(pts[pts.size() - 1][1])


## Зеркальное движение: левое ↔ правое (скелет приведён к общему стандарту — оси костей симметричны)
static func _mirror(src: Animation) -> Animation:
	var a := src.duplicate(true) as Animation
	for t in a.get_track_count():
		var path := String(a.track_get_path(t))
		var node := path.get_slice(":", 0)
		var bone := path.get_slice(":", 1)
		if bone.begins_with("Left"):
			a.track_set_path(t, NodePath(node + ":Right" + bone.substr(4)))
		elif bone.begins_with("Right"):
			a.track_set_path(t, NodePath(node + ":Left" + bone.substr(5)))
		match a.track_get_type(t):
			Animation.TYPE_ROTATION_3D:
				for k in a.track_get_key_count(t):
					var q: Quaternion = a.track_get_key_value(t, k)
					a.track_set_key_value(t, k, Quaternion(q.x, -q.y, -q.z, q.w))
			Animation.TYPE_POSITION_3D:
				for k in a.track_get_key_count(t):
					var p: Vector3 = a.track_get_key_value(t, k)
					a.track_set_key_value(t, k, Vector3(-p.x, p.y, p.z))
	return a


## Новое движение поверх готового: src повторяется reps раз, к поворотам костей из offs (кость → f(t) → Vector3 углов
## вокруг осей кости: x — кивок вниз, y — поворот головы влево, z — наклон) добавляется смещение
static func _layer(src: Animation, reps: int, offs: Dictionary) -> Animation:
	var a := Animation.new()
	var L := src.length * reps
	a.length = L
	a.loop_mode = Animation.LOOP_LINEAR
	var node := "%GeneralSkeleton"
	var done := {}
	for t in src.get_track_count():
		var path := String(src.track_get_path(t))
		node = path.get_slice(":", 0)
		var bone := path.get_slice(":", 1)
		var ty := src.track_get_type(t)
		var nt := a.add_track(ty)
		a.track_set_path(nt, src.track_get_path(t))
		a.track_set_interpolation_type(nt, src.track_get_interpolation_type(t))
		if ty == Animation.TYPE_ROTATION_3D and offs.has(bone):
			done[bone] = true
			var f: Callable = offs[bone]
			var n := int(L * 24.0)
			for i in n + 1:
				var tt := L * i / n
				var q := src.rotation_track_interpolate(t, fmod(tt, src.length))
				var e: Vector3 = f.call(tt)
				a.rotation_track_insert_key(nt, tt, q * Quaternion.from_euler(e))
		else:
			for r in reps:
				for k in src.track_get_key_count(t):
					a.track_insert_key(nt, src.track_get_key_time(t, k) + r * src.length, src.track_get_key_value(t, k))
	# кости, которые в исходном движении не шевелятся (у них дорожки нет): отдых у позвоночника и головы — без поворота
	for bone in offs:
		if done.has(bone):
			continue
		var nt := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(nt, NodePath(node + ":" + bone))
		var f: Callable = offs[bone]
		var n := int(L * 24.0)
		for i in n + 1:
			var tt := L * i / n
			a.rotation_track_insert_key(nt, tt, Quaternion.from_euler(f.call(tt)))
	return a


static func _derive(lib: AnimationLibrary) -> void:
	var idle := lib.get_animation("Idle")
	# слушает: дважды кивает, голова чуть набок
	var Ll := idle.length * 2.0
	var listen := _layer(idle, 2, {
		"Head": func(t: float) -> Vector3: return Vector3(0.2 * (_bump(t, 0.9, 1.6) + _bump(t, 1.75, 2.35) * 0.7 + _bump(t, 3.3, 4.0)), 0.0, 0.1 * (0.5 - 0.5 * cos(TAU * t / Ll))),
		"Neck": func(t: float) -> Vector3: return Vector3(0.06 * (_bump(t, 0.9, 1.6) + _bump(t, 3.3, 4.0)), 0.0, 0.0)})
	lib.add_animation("Listen", listen)
	# оглядывается: голова и плечи — налево, потом направо, обратно
	var look := [[0.0, 0.0], [1.0, 0.0], [1.9, 0.75], [3.3, 0.75], [4.5, -0.6], [5.8, -0.6], [6.8, 0.0], [7.5, 0.0]]
	var la := _layer(idle, 3, {
		"Head": func(t: float) -> Vector3: return Vector3(-0.08 * absf(_curve(t, look)), 0.6 * _curve(t, look), 0.0),
		"Neck": func(t: float) -> Vector3: return Vector3(0.0, 0.25 * _curve(t, look), 0.0),
		"UpperChest": func(t: float) -> Vector3: return Vector3(0.0, 0.2 * _curve(t, look), 0.0)})
	lib.add_animation("Look_Around", la)
	# смеётся: откидывается назад, плечи часто подрагивают
	var Lg := idle.length
	var env := func(t: float) -> float: return _curve(t, [[0.0, 0.0], [0.35, 1.0], [Lg - 0.5, 1.0], [Lg, 0.0]])
	var laugh := _layer(idle, 1, {
		"UpperChest": func(t: float) -> Vector3: return Vector3(-(0.14 + 0.07 * sin(TAU * 6.0 * t)) * env.call(t), 0.0, 0.0),
		"Chest": func(t: float) -> Vector3: return Vector3(-0.08 * env.call(t), 0.0, 0.0),
		"Head": func(t: float) -> Vector3: return Vector3(-(0.22 + 0.06 * sin(TAU * 6.0 * t + 1.0)) * env.call(t), 0.0, 0.06 * env.call(t))})
	lib.add_animation("Laugh", laugh)
	# зеркальные: жест другой рукой, кивок в другую сторону
	for n in ["Idle_Talking", "Interact", "PickUp_Table", "Spell_Simple_Idle", "Sitting_Talking", "Sitting_Idle", "Fixing_Kneeling", "Crouch_Idle", "Listen", "Look_Around"]:
		if lib.has_animation(n):
			lib.add_animation(n + "_M", _mirror(lib.get_animation(n)))


static func _material(variant: String) -> StandardMaterial3D:
	if not _mats.has(variant):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(Synty._tex_path("PolygonAncientEmpire_01_" + variant))
		m.roughness = 0.85
		_mats[variant] = m
	return _mats[variant]


## rich — патриций; child — ребёнок (уменьшенный взрослый)
static func create(rng: RandomNumberGenerator, is_female: bool, child := false, rich := false, model := "") -> Citizen:
	Synty._index()
	var c := Citizen.new()
	var pool: Array = RICH if rich else PLEBS
	var choices := pool.filter(func(n): return (n in FEMALE) == is_female)
	if choices.is_empty():
		choices = pool
	var name: String = model if model != "" else choices[rng.randi() % choices.size()]
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
	c.scale = Vector3.ONE * SIZE * (0.68 if child else 1.0)
	return c


## phase ≥ 0 — начать с этой доли движения (чтобы соседи не двигались в такт)
func play(name: String, blend := 0.25, phase := -1.0) -> void:
	if name == _cur:
		return
	_cur = name
	var short := name.trim_suffix("_Loop")
	if not anim.has_animation(short):
		short = name
	if anim.has_animation(short):
		anim.play(short, blend)
		if phase >= 0.0:
			anim.seek(fposmod(phase, 1.0) * anim.get_animation(short).length, true)


## Видимость 0…1 (входит в дверь — тает, выходит — проявляется)
func set_alpha(a: float) -> void:
	if meshes.is_empty():
		meshes = find_children("*", "MeshInstance3D", true, false)
	for m: MeshInstance3D in meshes:
		m.transparency = clampf(1.0 - a, 0.0, 1.0)


## Длина движения в секундах (0 — нет такого)
func anim_len(name: String) -> float:
	var short := name.trim_suffix("_Loop")
	if anim.has_animation(short):
		return anim.get_animation(short).length
	return 0.0


## Совместимость со старым кодом: относительное преобразование узла внутри предка top
static func _rel(n: Node3D, top: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var p: Node = n
	while p != top and p is Node3D:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf
