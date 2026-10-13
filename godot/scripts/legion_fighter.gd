class_name LegionFighter
extends Node3D
## Боец 3D-боя Легиона (legion_battle.gd): модель, снаряжение и движения одного бойца на поле.
## Сам ничего не решает — бой считает LegionSim, а боец только показывает: set_motion, attack, hurt, die, cheer, tick.
##
## Люди — персонажи Synty Ancient Empire со скелетом и движениями Quaternius (как жители города, Citizen);
## оружие и щиты Synty — в руках (BoneAttachment3D, хват считается по позе движения, см. _grip).
## У щитоносцев левая рука в любом движении держит щит перед собой («G_…» — движения со стойкой левой руки).
## Звери — анимированные животные Quaternius: волк, бык, свинья (вепрь — с клыками), медведь «вылеплен» из волка
## (толще тело, круглые уши, без хвоста — масштаб костей). Чудовища без скелета (Минотавр, боевой слон — статуи
## Artisau) идут, бьют и падают движениями кода. Машины — модели Kit (баллиста, онагр с отдельным рычагом) и расчёт.
## Модель смотрит вдоль +Z; поворачивает бойца бой.

const HUMAN := 0.86                    # рост человека на поле — около 1,5 м (поле боя крупнее городского)
const ANIMALS := "res://assets/animals/"
const ATT := "res://assets/synty/FBX/Attachments/"
const LEFT_ARM := ["LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand", "LeftIndexProximal", "LeftIndexIntermediate",
	"LeftIndexDistal", "LeftMiddleProximal", "LeftMiddleIntermediate", "LeftMiddleDistal", "LeftThumbMetacarpal", "LeftThumbProximal", "LeftThumbDistal"]
const RIGHT_ARM := ["RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand", "RightIndexProximal", "RightIndexIntermediate",
	"RightIndexDistal", "RightMiddleProximal", "RightMiddleIntermediate", "RightMiddleDistal", "RightThumbMetacarpal", "RightThumbProximal", "RightThumbDistal"]

## Как выглядит каждый боец. model — персонаж Synty, var — палитра Synty: "01"…"04" — цвета одежды (01 — красный
## легион), буква A/B/C — тон кожи и волос (без буквы — случайный у каждого бойца), head — что на голове (шлем, волосы, борода, венок; "hair"/"hair_f"/"beard" — случайные), right/left — что в руках,
## back — за спиной, style — как бьёт (sword | spear | bow | sling | club | throw | axe), tint — оттенок всей модели,
## ghost — призрачный (Тени Аида), crown — венок вождя, eye — один большой глаз (циклоп)
const LOOKS := {
	"legionary": {"model": "SK_Chr_Solider_Male_01", "var": "01", "head": ["SM_Chr_Attach_Helmet_03"], "right": "SM_Wep_Sword_01", "left": "SM_Wep_Shield_04", "style": "sword"},
	"spearman": {"model": "SK_Chr_Solider_Male_01", "var": "01", "head": ["SM_Chr_Attach_Helmet_05"], "right": "SM_Wep_Spear_02", "left": "SM_Wep_Shield_01", "style": "spear"},
	"archer": {"model": "SK_Chr_Soldier_Female_02", "var": "01", "head": ["hair_f"], "left": "#bow", "back": "#quiver", "style": "bow"},
	"bandit": {"model": "SK_Chr_Worker_Male_01", "var": "04", "head": ["hair", "beard"], "right": "SM_Wep_Axe_01", "style": "axe"},
	"slinger": {"model": "SK_Chr_Farmer_Male_01", "var": "02", "head": ["hair"], "right": "#stone", "style": "sling"},
	"gaul": {"model": "SK_Chr_Captain_Male_01", "var": "03", "head": ["SM_Chr_Hair_Male_04", "SM_Chr_Hair_Beard_02"], "right": "SM_Wep_Sword_02", "left": "SM_Wep_Shield_03", "style": "sword"},
	"gaulArcher": {"model": "SK_Chr_Farmer_Male_01", "var": "02", "head": ["hair", "SM_Chr_Hair_Beard_03"], "left": "#bow", "back": "#quiver", "style": "bow"},
	"berserker": {"model": "SK_Chr_Solider_Male_01", "var": "04", "head": ["SM_Chr_Hair_Male_06", "SM_Chr_Hair_Beard_04"], "right": "SM_Wep_Axe_02", "style": "axe", "k": 1.06},
	"pirate": {"model": "SK_Chr_Worker_Male_01", "var": "02", "head": ["hair", "beard"], "right": "SM_Wep_Sword_03", "style": "axe"},
	"mercenary": {"model": "SK_Chr_Solider_Male_01", "var": "02", "head": ["SM_Chr_Attach_Helmet_08"], "right": "SM_Wep_Spear_03", "left": "SM_Wep_Shield_02", "style": "spear"},
	"shade": {"model": "SK_Chr_Solider_Male_01", "var": "01_C", "head": ["SM_Chr_Attach_Helmet_06"], "right": "SM_Wep_Sword_03", "left": "SM_Wep_Shield_02", "style": "sword", "ghost": true},
	"chief": {"model": "SK_Chr_Leader_Male_01", "var": "03_B", "head": ["SM_Chr_Hair_Male_02", "SM_Chr_Hair_Beard_01"], "right": "SM_Wep_Axe_02", "style": "axe"},
	"gaulKing": {"model": "SK_Chr_Captain_Male_01", "var": "03_A", "head": ["SM_Chr_Hair_Male_04", "SM_Chr_Hair_Beard_02", "SM_Chr_Attach_Crown_Leaf_02"], "right": "SM_Wep_Sword_01", "left": "SM_Wep_Shield_03", "style": "sword"},
	"giant": {"model": "SK_Chr_Solider_Male_01", "var": "04_B", "head": ["SM_Chr_Hair_Male_06", "SM_Chr_Hair_Beard_04"], "right": "#club", "style": "club"},
	"cyclops": {"model": "SK_Chr_Solider_Male_01", "var": "04_A", "head": ["SM_Chr_Hair_Beard_04"], "right": "#boulder", "style": "throw", "tint": Color(0.74, 0.8, 0.96), "eye": true},
	"crew": {"model": "SK_Chr_Worker_Male_01", "var": "01", "head": ["hair"], "style": "sling"},
}
## Звери: файл Quaternius, длина тела (м), раскраска поверхностей (по порядку: основной, светлый, глаза, нос …)
const BEASTS := {
	"wolf": {"file": "Wolf_a", "len": 1.35},
	"hellhound": {"file": "Wolf_a", "len": 1.45, "cols": ["2b2326", "7a2a1c", "ff7a1a", "1a1414"], "glow": [2], "embers": true},
	"boar": {"file": "Wolf_a", "len": 1.25, "cols": ["4a3b31", "5e4a3c", "120d0b", "2a1c18"], "sculpt": "boar"},
	"bear": {"file": "Wolf_a", "len": 1.7, "cols": ["5e3d26", "6a4630", "141010", "1a1010"], "sculpt": "bear"},
	"greatbear": {"file": "Wolf_a", "len": 1.7, "cols": ["4e321f", "5a3b27", "141010", "1a1010"], "sculpt": "bear"},
	"bull": {"file": "Bull", "len": 2.0},
	"cerberus": {"file": "Wolf_a", "len": 1.6, "cols": ["2b2326", "7a2a1c", "ff7a1a", "1a1414"], "glow": [2], "embers": true, "heads": 3},
}
## Чудовища без скелета — статуи Artisau: высота (м) при size 1
const STATUES := {
	"minotaur": {"file": "Minotaur", "h": 1.75, "recolor": {Vector2i(9, 0): "7a4b2e", Vector2i(5, 0): "d9cfbc"}},
	"elephant": {"file": "War_Elephant", "h": 2.3, "len": true},
}

var key := ""
var kind := "human"                    # human | beast | statue | machine
var style := "sword"
var top := 1.7                         # высота макушки над землёй (м) — над ней полоска здоровья
var anim: AnimationPlayer
var clip := {}                         # idle, walk, run, attack, hit, death, cheer → имя движения
var body: Node3D                       # сама модель (у статуй и машин качается и наклоняется кодом)
var skel: Skeleton3D
var arm: Node3D                        # рычаг онагра
var bolt: Node3D                       # болт на ложе баллисты
var crew: LegionFighter                # расчёт машины
var weapon: Node3D                     # оружие в правой руке (у копейщика выпад — кодом)
var heads: Array[Node3D] = []          # головы Цербера (кивают, когда кусает)
var embers := false
var dead := false
var speed_k := 1.0                     # скорость боя (×1…×3): движения быстрее

var _geo: Array[GeometryInstance3D] = []
var _state := ""
var _atk := 0.0                        # сколько ещё идёт удар (с)
var _atk_len := 0.5
var _hit := 0.0                        # вспышка от удара
var _hit_last := -1.0
var _dead_t := 0.0
var _t := 0.0
var _moving := false
var _run := false
var _base_y := 0.0
var _spear_off := Transform3D.IDENTITY
var _anim_k := 1.0                     # своя скорость движений (у больших — медленнее)

static var _scenes := {}
static var _lib: AnimationLibrary
static var _grips := {}
static var _mats := {}
static var _flash_mat: StandardMaterial3D
static var _kit := {}


static func _scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]


# =====================================================================
#   создание
# =====================================================================

## Боец по ключу рода войск (Legion.UNITS) или врага (Legion.ENEMIES); size — размер из боя (боссы крупнее);
## rival — легион другого города (бой с городом): те же бойцы, но в синих с бронзой одеждах
static func create(k: String, size := 1.0, seed_v := 1, rival := false) -> LegionFighter:
	Synty._index()
	var f := LegionFighter.new()
	f.key = k
	f.name = "F_" + k
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	if LOOKS.has(k):
		var L: Dictionary = LOOKS[k]
		if rival:
			L = L.duplicate()
			L["var"] = "02"
		f._human(L, size, rng)
	elif BEASTS.has(k):
		f._beast(BEASTS[k], size)
	elif STATUES.has(k):
		f._statue(STATUES[k], size)
	elif k == "ballista" or k == "catapult":
		f._machine(k, rng, rival)
	else:
		f._human(LOOKS["bandit"], size, rng)
	f._collect()
	f.set_motion(false)
	return f


func _collect() -> void:
	_geo.clear()
	for g in find_children("*", "GeometryInstance3D", true, false):
		_geo.append(g as GeometryInstance3D)


# ---------- люди ----------

func _human(L: Dictionary, size: float, rng: RandomNumberGenerator) -> void:
	kind = "human"
	style = String(L.get("style", "sword"))
	body = _scene(Citizen.DIR + String(L["model"]) + ".fbx").instantiate() as Node3D
	add_child(body)
	var pal := String(L.get("var", "01"))
	if not pal.contains("_"):
		pal += "_" + ["A", "B", "C"][rng.randi() % 3]
	var mat := _person_mat(pal, L.get("tint", Color.WHITE), bool(L.get("ghost", false)))
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = mat
	skel = body.find_children("*", "Skeleton3D", true, false)[0]
	# голова: шлем, волосы, борода, венок
	var head := BoneAttachment3D.new()
	head.bone_name = "Head"
	skel.add_child(head)
	for h0 in L.get("head", []):
		var h := String(h0)
		match h:
			"hair":
				h = "SM_Chr_Hair_Male_0%d" % (1 + rng.randi() % 7)
			"hair_f":
				h = "SM_Chr_Hair_Female_0%d" % (1 + rng.randi() % 6)
			"beard":
				if rng.randf() < 0.35:
					continue
				h = "SM_Chr_Hair_Beard_0%d" % (1 + rng.randi() % 4)
		var hn := _scene(ATT + h + ".fbx").instantiate() as Node3D
		for mi: MeshInstance3D in hn.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = mat
		head.add_child(hn)
	if bool(L.get("crown", false)):
		var cr := _scene(ATT + "SM_Chr_Attach_Crown_Leaf_01.fbx").instantiate() as Node3D
		for mi: MeshInstance3D in cr.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = _person_mat("A", Color.WHITE, false)
		head.add_child(cr)
	if bool(L.get("eye", false)):
		var eye := MeshInstance3D.new()
		eye.mesh = _kit_mesh("#eye")
		head.add_child(eye)
	# в руках
	var shield := L.has("left") and String(L["left"]).begins_with("SM_Wep_Shield")
	if L.has("right"):
		weapon = _hold(String(L["right"]), "right", L)
	if L.has("left"):
		_hold(String(L["left"]), "left", L)
	if L.has("back"):
		# колчан за спиной, наискось через плечо
		var q := Artisau.make("Carcaj", 0.5)
		var ba := BoneAttachment3D.new()
		ba.bone_name = "UpperChest"
		skel.add_child(ba)
		var gc := _pose(skel, library().get_animation("Bow_Idle"), 0.0, "UpperChest")
		var want := _basis(Vector3(-0.45, 1.0, -0.12), Vector3(0, 0, -1))
		q.transform = gc.affine_inverse() * Transform3D(want, gc.origin + Vector3(0.12, -0.22, -0.2))
		ba.add_child(q)
	# движения: у щитоносцев левая рука всегда держит щит («G_»)
	anim = AnimationPlayer.new()
	body.add_child(anim)
	anim.root_node = NodePath("..")
	anim.add_animation_library("", library())
	var g := "G_" if shield else ""
	match style:
		"sword", "axe":
			clip = {"idle": g + "Sword_Idle" if shield else "Sword_Idle", "walk": g + "Walk", "run": g + "Jog_Fwd", "attack": g + "Sword_Attack",
				"hit": g + "Hit_Chest", "death": "Death01", "cheer": g + "Cheer"}
		"spear":
			# копьё наперевес и на ходу: правая рука держит древко (из стойки), левая — щит
			var sp := "S_" if shield else "R_"
			clip = {"idle": g + "Spear_Idle", "walk": sp + "Walk", "run": sp + "Jog_Fwd", "attack": g + "Spear_Jab", "hit": sp + "Hit_Chest",
				"death": "Death01", "cheer": g + "Cheer"}
		"bow":
			clip = {"idle": "Bow_Idle", "walk": "Walk", "run": "Jog_Fwd", "attack": "Bow_Shoot", "hit": "Hit_Chest", "death": "Death01", "cheer": "Cheer"}
		"sling", "throw":
			clip = {"idle": "Idle", "walk": "Walk", "run": "Jog_Fwd", "attack": "Throw", "hit": "Hit_Chest", "death": "Death01", "cheer": "Cheer"}
		"club":
			clip = {"idle": "Sword_Idle", "walk": "Walk", "run": "Walk", "attack": "Sword_Attack", "hit": "Hit_Chest", "death": "Death01", "cheer": "Cheer"}
	anim.speed_scale = rng.randf_range(0.94, 1.06)
	var s := HUMAN * size * float(L.get("k", 1.0))
	body.scale = Vector3.ONE * s
	top = 1.78 * s + 0.1
	# крупные бьют медленнее
	_anim_k = 1.0 / sqrt(maxf(1.0, size))


## Предмет в руке: оружие Synty, лук и колчан Artisau, дубина великана, камни пращника и циклопа
func _hold(what: String, hand: String, L: Dictionary) -> Node3D:
	var n: Node3D
	match what:
		"#bow":
			n = Artisau.make("Bow", 1.05)
		"#club":
			n = Artisau.make("Mazo_Grande", 1.5)
		"#stone", "#boulder":
			var mi := MeshInstance3D.new()
			mi.mesh = _kit_mesh(what)
			n = mi
		_:
			n = Synty.make(what)
	var ba := BoneAttachment3D.new()
	ba.bone_name = "RightHand" if hand == "right" else "LeftHand"
	skel.add_child(ba)
	var holder := Node3D.new()
	ba.add_child(holder)
	holder.add_child(n)
	holder.transform = _grip(String(L["model"]), what, hand)
	if what == "#bow" or what == "#club":
		# у моделей Artisau основание на нуле — хват посередине (лук) или у конца рукояти (дубина)
		n.position.y -= 0.52 if what == "#bow" else 0.1
	if hand == "right" and what.begins_with("SM_Wep_Spear"):
		_spear_off = holder.transform
	return holder


## Хват: как предмет лежит в кисти. Для оружия с понятной стойкой — по позе движения (кисть в осях персонажа
## считается из дорожек анимации), чтобы в стойке клинок смотрел вверх, копьё — вперёд, щит — лицом к врагу
func _grip(model: String, what: String, hand: String) -> Transform3D:
	var key2 := model + "|" + what + "|" + hand
	if _grips.has(key2):
		return _grips[key2]
	var xf := Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(0, 0.075, 0))
	var sk := skel
	if what.begins_with("SM_Wep_Shield"):
		# щит перед собой, чуть развёрнут наружу, на уровне кисти; лицом (+Z щита) — вперёд
		var g := _pose(sk, library().get_animation("Sword_Idle"), 0.0, "LeftHand")
		var want := _basis(Vector3(0.0, 1.0, 0.1), Vector3(0.35, 0.0, 1.0))
		var at := g.origin + Vector3(0.06, 0.08 if what == "SM_Wep_Shield_04" else 0.12, 0.12)
		xf = g.affine_inverse() * Transform3D(want, at)
	elif what.begins_with("SM_Wep_Spear"):
		# копьё наперевес: остриё вперёд и чуть вверх, кисть — на трети древка
		var g := _pose(sk, library().get_animation("Spear_Idle"), 0.0, "RightHand")
		var dir := Vector3(0.05, 0.42, 1.0).normalized()
		var want := _basis(dir, Vector3(1, 0, 0))
		xf = g.affine_inverse() * Transform3D(want, g.origin + dir * 0.32)
	elif what == "#bow":
		# лук в вытянутой левой руке, стоймя
		var g := _pose(sk, library().get_animation("Bow_Idle"), 0.2, "LeftHand")
		var want := _basis(Vector3(0.0, 1.0, 0.12), Vector3(-1.0, 0.0, 0.0))
		xf = g.affine_inverse() * Transform3D(want, g.origin + Vector3(0, 0.0, 0.03))
	elif what == "#stone":
		xf = Transform3D(Basis.IDENTITY, Vector3(0, 0.09, 0.03))
	elif what == "#boulder":
		xf = Transform3D(Basis.IDENTITY, Vector3(0, 0.16, 0.08))
	_grips[key2] = xf
	return xf


## Базис по направлению оси Y предмета и куда смотрит его +Z
static func _basis(y: Vector3, z: Vector3) -> Basis:
	var yy := y.normalized()
	var xx := yy.cross(z).normalized()
	var zz := xx.cross(yy).normalized()
	return Basis(xx, yy, zz)


## Положение кости bone в осях скелета на кадре t движения a — без проигрывания (по дорожкам и позам покоя)
static func _pose(sk: Skeleton3D, a: Animation, t: float, bone: String) -> Transform3D:
	var rot := {}
	var pos := {}
	for i in a.get_track_count():
		var bn := String(a.track_get_path(i)).get_slice(":", 1)
		match a.track_get_type(i):
			Animation.TYPE_ROTATION_3D:
				rot[bn] = a.rotation_track_interpolate(i, t)
			Animation.TYPE_POSITION_3D:
				pos[bn] = a.position_track_interpolate(i, t) * sk.motion_scale
	var chain := []
	var idx := sk.find_bone(bone)
	while idx >= 0:
		chain.push_front(idx)
		idx = sk.get_bone_parent(idx)
	var g := Transform3D.IDENTITY
	for i: int in chain:
		var bn := sk.get_bone_name(i)
		var rest := sk.get_bone_rest(i)
		var b: Basis = Basis(rot[bn] as Quaternion) if rot.has(bn) else rest.basis.orthonormalized()
		var o: Vector3 = pos[bn] if pos.has(bn) else rest.origin
		g = g * Transform3D(b, o)
	return g


static func _person_mat(variant: String, tint: Color, ghost: bool) -> Material:
	var k := "%s|%s|%s" % [variant, tint.to_html(), ghost]
	if _mats.has(k):
		return _mats[k]
	# палитра Synty: "A"…"C" — первая (как у жителей), "02_B" и т. п. — другие расцветки одежды
	var pal := variant if variant.contains("_") else "01_" + variant
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(Synty._tex_path("PolygonAncientEmpire_" + pal))
	m.roughness = 0.85
	m.albedo_color = tint
	if ghost:
		# тень Аида: полупрозрачная, светится холодным синим
		m.albedo_color = Color(0.55, 0.72, 1.0, 0.62)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		m.emission_enabled = true
		m.emission = Color(0.25, 0.5, 1.0)
		m.emission_energy_multiplier = 0.9
		m.rim_enabled = true
		m.rim = 0.8
		m.rim_tint = 0.2
	_mats[k] = m
	return m


# ---------- звери ----------

func _beast(B: Dictionary, size: float) -> void:
	kind = "beast"
	style = "beast"
	var n_heads := int(B.get("heads", 1))
	var src := _scene(ANIMALS + String(B["file"]) + ".glb")
	var models: Array[Node3D] = []
	for i in n_heads:
		var n := src.instantiate() as Node3D
		models.append(n)
	body = Node3D.new()
	add_child(body)
	for i in n_heads:
		var n := models[i]
		body.add_child(n)
		if n_heads > 1:
			# Цербер: три пса плечом к плечу — средний впереди, крайние чуть сзади и развёрнуты наружу
			var side := float(i - 1)
			n.position = Vector3(side * 0.38, 0.0, -absf(side) * 0.5) / maxf(0.01, _len_k(n, B, size))
			n.rotation.y = -side * 0.3
			heads.append(n)
	var k := _len_k(models[0], B, size)
	body.scale = Vector3.ONE * k
	# раскраска
	for n in models:
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			if B.has("cols"):
				var cols: Array = B["cols"]
				for s in mi.mesh.get_surface_count():
					if s < cols.size():
						mi.set_surface_override_material(s, _flat_mat(String(cols[s]), s in B.get("glow", [])))
			elif B.has("tint"):
				for s in mi.mesh.get_surface_count():
					var m0 := mi.mesh.surface_get_material(s)
					if m0 is StandardMaterial3D:
						var mm := (m0 as StandardMaterial3D).duplicate() as StandardMaterial3D
						mm.albedo_color = B["tint"]
						mi.set_surface_override_material(s, mm)
	embers = bool(B.get("embers", false))
	var sk: Skeleton3D = models[0].find_children("*", "Skeleton3D", true, false)[0]
	skel = sk
	var drop := 0.0
	if B.has("sculpt"):
		for n in models:
			drop = _sculpt(n.find_children("*", "Skeleton3D", true, false)[0], String(B["sculpt"]))
		# короткие лапы — тело ниже (иначе зверь висит над землёй)
		var ab := Artisau.aabb(models[0])
		for n in models:
			n.position.y -= ab.size.y * drop
	if bool(B.get("tusks", false)):
		for n in models:
			var nose := _nose(n)
			var s2: Skeleton3D = n.find_children("*", "Skeleton3D", true, false)[0]
			var hi := s2.find_bone("Head")
			var ba := BoneAttachment3D.new()
			ba.bone_name = "Head"
			s2.add_child(ba)
			var tk := MeshInstance3D.new()
			tk.mesh = _kit_mesh("#tusks")
			ba.add_child(tk)
			# клыки — у пасти: кончик носа (самая передняя точка сетки в позе покоя), чуть ниже и ближе → в оси кости головы
			var at := nose + Vector3(0.0, -0.1, -0.02) / k
			var want := Transform3D(Basis.from_scale(Vector3.ONE / k), at)
			var head_g := Citizen._rel(s2, n) * s2.get_bone_global_rest(hi)
			tk.transform = head_g.affine_inverse() * want
	# движения: первый из голов ведёт, остальные повторяют
	var aps: Array[AnimationPlayer] = []
	for n in models:
		aps.append(n.find_children("*", "AnimationPlayer", true, false)[0])
	anim = aps[0]
	for i in range(1, aps.size()):
		_followers.append(aps[i])
	clip = {"idle": _find(anim, ["Idle", "Idle_2"]), "walk": _find(anim, ["Walk"]), "run": _find(anim, ["Gallop", "Run"]),
		"attack": _find(anim, ["Attack", "Attack_Headbutt", "Headbutt"]), "hit": _find(anim, ["Idle_HitReact_Left", "Idle_HitReact_Right"]),
		"death": _find(anim, ["Death"]), "cheer": _find(anim, ["Idle_2", "Idle"])}
	for a in [clip["idle"], clip["walk"], clip["run"], clip["cheer"]]:
		if a != "" and anim.has_animation(a):
			anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	var aabb := Artisau.aabb(models[0])
	top = aabb.size.y * k * 0.8 + 0.25
	_anim_k = 1.0 / sqrt(maxf(1.0, size))


var _followers: Array[AnimationPlayer] = []


## Кончик носа зверя в осях модели (самая передняя вершина сетки)
static func _nose(n: Node3D) -> Vector3:
	var best := Vector3(0, 0, -INF)
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var xf := Citizen._rel(mi, n)
		var arr := mi.mesh.surface_get_arrays(0)
		for v: Vector3 in arr[Mesh.ARRAY_VERTEX]:
			var p := xf * v
			if p.z > best.z:
				best = p
	return best


## Масштаб зверя: длина тела модели → нужная длина (м) × размер из боя
static func _len_k(n: Node3D, B: Dictionary, size: float) -> float:
	var aabb := Artisau.aabb(n)
	return float(B["len"]) * size / maxf(0.01, maxf(aabb.size.z, aabb.size.x))


## Движение по короткому имени (у некоторых животных имена с приставкой «AnimalArmature|…|»)
static func _find(ap: AnimationPlayer, names: Array) -> String:
	for want in names:
		for a in ap.get_animation_list():
			var s := String(a)
			if s == want or s.ends_with("|" + String(want)):
				return s
	return ""


## Лепка зверя из волка масштабом костей. Медведь: тело толще и выше, голова крупнее, уши круглые, хвост — пенёк.
## Вепрь: короткие толстые лапы, массивная холка, тяжёлая голова, маленькие уши. Возвращает, на какую долю роста
## опустить тело (короче лапы)
static func _sculpt(sk: Skeleton3D, how: String) -> float:
	var sc := {}
	var drop := 0.0
	if how == "bear":
		sc = {"Body": Vector3(1.25, 1.15, 1.2), "Torso": Vector3(1.2, 1.12, 1.1), "Torso2": Vector3(1.05, 1.0, 1.05),
			"Neck1": Vector3(1.2, 0.8, 1.15), "Head": Vector3(1.12, 0.85, 1.12), "Ear1.L": Vector3(0.75, 0.45, 0.75), "Ear1.R": Vector3(0.75, 0.45, 0.75),
			"Tail1": Vector3(0.6, 0.18, 0.6), "FrontUpperLeg.L": Vector3(1.25, 0.92, 1.25), "FrontUpperLeg.R": Vector3(1.25, 0.92, 1.25),
			"BackUpperLeg.L": Vector3(1.25, 0.92, 1.25), "BackUpperLeg.R": Vector3(1.25, 0.92, 1.25)}
		drop = 0.03
	elif how == "boar":
		sc = {"Body": Vector3(1.35, 1.3, 1.1), "Torso": Vector3(1.3, 1.35, 1.0), "Torso2": Vector3(1.15, 1.15, 1.0),
			"Neck1": Vector3(1.35, 0.7, 1.3), "Head": Vector3(1.2, 0.95, 1.1), "Ear1.L": Vector3(0.7, 0.5, 0.7), "Ear1.R": Vector3(0.7, 0.5, 0.7),
			"Tail1": Vector3(0.5, 0.3, 0.5), "FrontUpperLeg.L": Vector3(1.4, 0.68, 1.4), "FrontUpperLeg.R": Vector3(1.4, 0.68, 1.4),
			"BackUpperLeg.L": Vector3(1.4, 0.68, 1.4), "BackUpperLeg.R": Vector3(1.4, 0.68, 1.4)}
		drop = 0.11
	for bn in sc:
		var i := sk.find_bone(bn)
		if i >= 0:
			sk.set_bone_pose_scale(i, sc[bn])
	return drop


static func _flat_mat(hex: String, glow: bool) -> StandardMaterial3D:
	var k := hex + ("|g" if glow else "")
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.roughness = 0.85
	if glow:
		m.emission_enabled = true
		m.emission = Color(hex)
		m.emission_energy_multiplier = 3.0
	_mats[k] = m
	return m


# ---------- чудовища-статуи ----------

func _statue(S: Dictionary, size: float) -> void:
	kind = "statue"
	style = "statue"
	body = Node3D.new()
	add_child(body)
	var m := Artisau.make(String(S["file"]), float(S["h"]) * size)
	body.add_child(m)
	if S.has("recolor"):
		var mm := _recolor(String(S["file"]), S["recolor"])
		for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = mm
	# Artisau смотрят по-разному: Минотавр — к +Z, слон — к −Z (хобот)
	if String(S["file"]) == "War_Elephant":
		m.rotation.y = PI
	top = float(S["h"]) * size + 0.15
	_anim_k = 1.0 / sqrt(maxf(1.0, size))


## Своя палитра для статуи Artisau: клетки палитры 16×16 перекрашены (Минотавр — бурая шерсть вместо светлой)
static func _recolor(file: String, cells: Dictionary) -> StandardMaterial3D:
	var k := "recolor|" + file
	if _mats.has(k):
		return _mats[k]
	var img := (Artisau.material().albedo_texture as Texture2D).get_image()
	img.decompress()
	for c: Vector2i in cells:
		img.set_pixelv(c, Color(String(cells[c])))
	var m := Artisau.material().duplicate() as StandardMaterial3D
	m.albedo_texture = ImageTexture.create_from_image(img)
	_mats[k] = m
	return m


# ---------- машины ----------

func _machine(k: String, rng: RandomNumberGenerator, rival := false) -> void:
	kind = "machine"
	style = k
	body = Node3D.new()
	add_child(body)
	if k == "ballista":
		var mi := MeshInstance3D.new()
		mi.mesh = _kit_mesh("#ballista")
		body.add_child(mi)
		bolt = MeshInstance3D.new()
		(bolt as MeshInstance3D).mesh = _kit_mesh("#ballista_bolt")
		body.add_child(bolt)
		body.scale = Vector3.ONE * 0.72
		top = 1.55
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = _kit_mesh("#onager")
		body.add_child(mi)
		arm = Node3D.new()
		arm.position = Vector3(0, 0.6, -0.55)
		body.add_child(arm)
		var am := MeshInstance3D.new()
		am.mesh = _kit_mesh("#onager_arm")
		am.position = -arm.position
		arm.add_child(am)
		arm.rotation.x = 0.0
		body.scale = Vector3.ONE * 0.6
		top = 1.4
	# расчёт: мастер в рабочей тунике рядом с машиной
	var c := LegionFighter.new()
	c.key = "crew"
	var cl: Dictionary = LOOKS["crew"]
	if rival:
		cl = cl.duplicate()
		cl["var"] = "02"
	c._human(cl, 0.95, rng)
	c.position = Vector3(0.75, 0, -0.9)
	c.rotation.y = -0.6
	add_child(c)
	crew = c
	crew._collect()
	crew.anim.play("Interact" if k == "ballista" else "Fixing_Kneeling", 0.0)
	crew.anim.seek(rng.randf() * 2.0, true)


# =====================================================================
#   движения
# =====================================================================

## Своя библиотека движений боя: нужные движения жителей и собранные из них — стойка со щитом (левая рука
## держит щит в любом движении), копьё наперевес, лук, бросок, ликование
static func library() -> AnimationLibrary:
	if _lib != null:
		return _lib
	var base := Citizen.library()
	_lib = AnimationLibrary.new()
	for n in ["Idle", "Walk", "Jog_Fwd", "Sprint", "Sword_Idle", "Sword_Attack", "Punch_Jab", "Punch_Cross", "Hit_Chest", "Hit_Head",
			"Death01", "Spell_Simple_Idle", "Spell_Simple_Shoot", "Pistol_Idle", "Pistol_Shoot", "Jump", "Dance", "Interact", "Fixing_Kneeling",
			"Crouch_Idle", "Idle_Talking"]:
		if base.has_animation(n):
			_lib.add_animation(n, base.get_animation(n))
	var sword_idle := base.get_animation("Sword_Idle")
	# копьё: стойка — как с мечом, но правая рука ниже и вперёд (кисть держит древко у пояса)
	var spear_idle := _with_pose(base.get_animation("Idle"), sword_idle, ["Hips", "Spine", "Chest", "UpperChest", "LeftUpperLeg", "LeftLowerLeg",
		"RightUpperLeg", "RightLowerLeg", "LeftFoot", "RightFoot"] + LEFT_ARM, 0.0, true)
	spear_idle.loop_mode = Animation.LOOP_LINEAR
	_lib.add_animation("Spear_Idle", spear_idle)
	var jab := base.get_animation("Punch_Jab").duplicate(true) as Animation
	jab.loop_mode = Animation.LOOP_NONE
	_lib.add_animation("Spear_Jab", jab)
	# лук: вытянутая левая рука (из «простого заклинания»), выстрел — толчок
	var bow_idle := base.get_animation("Spell_Simple_Idle").duplicate(true) as Animation
	bow_idle.loop_mode = Animation.LOOP_LINEAR
	_lib.add_animation("Bow_Idle", bow_idle)
	_lib.add_animation("Bow_Shoot", base.get_animation("Spell_Simple_Shoot"))
	# бросок (праща, камень циклопа): удар мечом сверху без меча — широкий мах правой
	_lib.add_animation("Throw", base.get_animation("Sword_Attack"))
	# ликование после победы: прыжок на месте
	var cheer := base.get_animation("Jump").duplicate(true) as Animation if base.has_animation("Jump") else base.get_animation("Idle").duplicate(true) as Animation
	cheer.loop_mode = Animation.LOOP_LINEAR
	_lib.add_animation("Cheer", cheer)
	# со щитом: левая рука в стойке Sword_Idle
	for n in ["Walk", "Jog_Fwd", "Sword_Attack", "Hit_Chest", "Cheer", "Sword_Idle", "Spear_Idle", "Spear_Jab"]:
		var a := _lib.get_animation(n)
		var g := _with_pose(a, sword_idle, LEFT_ARM, 0.0, false)
		g.loop_mode = a.loop_mode
		_lib.add_animation("G_" + n, g)
	# копейщик на ходу: правая рука держит копьё как в стойке (R_), со щитом — и левая (S_)
	for n in ["Walk", "Jog_Fwd", "Hit_Chest"]:
		var a := _lib.get_animation(n)
		var r := _with_pose(a, spear_idle, RIGHT_ARM, 0.0, false)
		r.loop_mode = a.loop_mode
		_lib.add_animation("R_" + n, r)
		var sg := _with_pose(r, sword_idle, LEFT_ARM, 0.0, false)
		sg.loop_mode = a.loop_mode
		_lib.add_animation("S_" + n, sg)
	return _lib


## Движение src, у которого кости bones весь клип стоят в позе из pose (кадр t). keep_pos — дорожки положения
## этих костей тоже из pose
static func _with_pose(src: Animation, pose: Animation, bones: Array, t: float, keep_pos: bool) -> Animation:
	var a := src.duplicate(true) as Animation
	for i in range(a.get_track_count() - 1, -1, -1):
		var bn := String(a.track_get_path(i)).get_slice(":", 1)
		var ty := a.track_get_type(i)
		if bn in bones and (ty == Animation.TYPE_ROTATION_3D or (keep_pos and ty == Animation.TYPE_POSITION_3D)):
			a.remove_track(i)
	for i in pose.get_track_count():
		var path := pose.track_get_path(i)
		var bn := String(path).get_slice(":", 1)
		var ty := pose.track_get_type(i)
		if not bn in bones:
			continue
		if ty == Animation.TYPE_ROTATION_3D:
			var nt := a.add_track(ty)
			a.track_set_path(nt, path)
			a.rotation_track_insert_key(nt, 0.0, pose.rotation_track_interpolate(i, t))
		elif keep_pos and ty == Animation.TYPE_POSITION_3D:
			var nt := a.add_track(ty)
			a.track_set_path(nt, path)
			a.position_track_insert_key(nt, 0.0, pose.position_track_interpolate(i, t))
	return a


func _play(state: String, blend := 0.2, from := 0.0) -> void:
	if anim == null:
		_state = state
		return
	var n: String = clip.get(state, "")
	if n == "" or not anim.has_animation(n):
		n = clip.get("idle", "")
	if n == "" or not anim.has_animation(n):
		return
	if state == _state and anim.current_animation == n and state != "attack" and state != "hit":
		return
	_state = state
	anim.play(n, blend)
	if from > 0.0:
		anim.seek(from, true)
	for ap in _followers:
		ap.play(n, blend)
		if from > 0.0:
			ap.seek(from, true)


func _speed() -> void:
	if anim:
		var s := speed_k * _anim_k
		if _state == "walk" or _state == "run":
			s *= _walk_k
		anim.speed_scale = s
		for ap in _followers:
			ap.speed_scale = s
	if crew:
		crew.speed_k = speed_k
		crew._speed()


var _walk_k := 1.0


## Идёт или стоит; pace — скорость шага в м/с (подбирает шаг или бег и темп ног)
func set_motion(moving: bool, pace := 1.5) -> void:
	_moving = moving
	if dead or _atk > 0.0:
		return
	if kind == "statue" or kind == "machine":
		return
	if moving:
		_run = pace > 2.0 or kind == "beast" and pace > 1.8
		_walk_k = clampf(pace / (3.0 if _run else 1.3), 0.6, 1.6)
		_play("run" if _run else "walk", 0.2)
	else:
		_walk_k = 1.0
		_play("idle", 0.25)
	_speed()


## Удар или выстрел; dur — сколько длится замах в бою (сек) — движение подгоняется
func attack() -> void:
	if dead:
		return
	_atk_len = 0.55
	if kind == "statue":
		_atk = 0.6
		_atk_len = 0.6
		return
	if kind == "machine":
		_atk = 1.2
		_atk_len = 1.2
		if bolt:
			bolt.visible = false
		return
	var n: String = clip.get("attack", "")
	if anim == null or n == "" or not anim.has_animation(n):
		return
	var a := anim.get_animation(n)
	# удар мечом длинный (1,5 с): начинаем с замаха, чтобы удар пришёлся сразу
	var from := 0.0
	if n.ends_with("Sword_Attack") or n == "Throw":
		from = 0.32
	_state = ""
	_play("attack", 0.08, from)
	_speed()
	_atk = (a.length - from) / maxf(0.1, anim.speed_scale)
	_atk_len = _atk


## Попадание по бойцу: вспышка и, если стоит, вздрагивает
func hurt() -> void:
	if dead:
		return
	# короткая вспышка, не чаще раза в 0,35 с (иначе под градом ударов боец «светится» всё время)
	if _t - _hit_last > 0.35:
		_hit = 0.09
		_hit_last = _t
	if kind == "statue":
		return
	if _atk <= 0.0 and not _moving and anim and clip.get("hit", "") != "" and randf() < 0.5:
		_state = ""
		_play("hit", 0.06)
		_atk = 0.3
		_atk_len = 0.3


func die() -> void:
	if dead:
		return
	dead = true
	_dead_t = 0.0
	_atk = 0.0
	if anim:
		_state = ""
		_play("death", 0.12)
		_speed()
	if crew:
		crew.die()
	_set_overlay(null)


## После победы: живые радуются
func cheer() -> void:
	if dead:
		return
	_atk = 0.0
	_moving = false
	if anim:
		_play("cheer", 0.3)
		_speed()
	if crew:
		crew.anim.play("Cheer", 0.3)


## Каждый кадр: вспышка, конец удара, движения статуй и машин, падение павших. dt — с учётом скорости боя
func tick(dt: float) -> void:
	_t += dt
	if crew:
		crew.tick(dt)
	if _hit > 0.0:
		_hit -= dt
		_set_overlay(_flash() if _hit > 0.0 else null)
	if _atk > 0.0:
		_atk -= dt
		if _atk <= 0.0 and not dead:
			_state = ""
			set_motion(_moving)
			if bolt:
				bolt.visible = true
	if kind == "statue":
		_tick_statue(dt)
	elif kind == "machine":
		_tick_machine(dt)
	if dead:
		_dead_t += dt
		# лежит, потом медленно уходит в землю и тает
		if _dead_t > 2.6:
			var k := clampf((_dead_t - 2.6) / 1.4, 0.0, 1.0)
			position.y = _base_y - k * 0.35
			for g in _geo:
				if is_instance_valid(g):
					g.transparency = k
			if k >= 1.0:
				visible = false


## Статуя-чудовище: качается на ходу, бросается вперёд при ударе, падает набок
func _tick_statue(dt: float) -> void:
	var b := body
	if dead:
		var k := clampf(_dead_t / 0.9, 0.0, 1.0)
		b.rotation = Vector3(0.0, 0.0, -k * k * 1.35)
		b.position.y = -k * 0.05
		return
	var bob := 0.0
	var roll := 0.0
	var pitch := 0.0
	if _moving:
		var f := _t * 7.0 * speed_k * _anim_k
		bob = absf(sin(f)) * 0.07
		roll = sin(f) * 0.05
		pitch = 0.05
	else:
		bob = sin(_t * 2.0) * 0.012
	if _atk > 0.0:
		var k := 1.0 - _atk / maxf(0.01, _atk_len)
		var swing := sin(clampf(k, 0.0, 1.0) * PI)
		pitch += swing * 0.28
		b.position.z = swing * 0.25
	else:
		b.position.z = lerpf(b.position.z, 0.0, minf(1.0, dt * 8.0))
	b.position.y = bob
	b.rotation = Vector3(pitch, 0.0, roll)


## Машина: рычаг онагра бьёт вперёд и медленно взводится, баллиста вздрагивает при выстреле
func _tick_machine(dt: float) -> void:
	if dead:
		var k := clampf(_dead_t / 0.8, 0.0, 1.0)
		body.rotation = Vector3(0.0, 0.0, -k * 0.35)
		body.position.y = -k * 0.25
		return
	if arm:
		if _atk > 0.0:
			var k := 1.0 - _atk / maxf(0.01, _atk_len)
			# 0…0,15 — удар вперёд до упора, дальше медленно назад
			var a := 0.0
			if k < 0.15:
				a = ease(k / 0.15, 0.35) * 1.75
			else:
				a = 1.75 * (1.0 - smoothstep(0.15, 1.0, k))
			arm.rotation.x = a
		else:
			arm.rotation.x = 0.0
	if bolt:
		var kick := 0.0
		if _atk > 0.0:
			var k := 1.0 - _atk / maxf(0.01, _atk_len)
			kick = sin(clampf(k / 0.2, 0.0, 1.0) * PI) * 0.06
		body.position.z = -kick


func _set_overlay(m: Material) -> void:
	for g in _geo:
		if is_instance_valid(g):
			g.material_overlay = m


static func _flash() -> StandardMaterial3D:
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.albedo_color = Color(1.0, 0.75, 0.6, 0.16)
		_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return _flash_mat


## Скорость боя (×1…×3)
func set_speed(k: float) -> void:
	speed_k = k
	_speed()


## Куда смотреть: угол поворота (рад) вокруг вертикали
func face(yaw: float, dt: float) -> void:
	if dead:
		return
	rotation.y = lerp_angle(rotation.y, yaw, minf(1.0, dt * 8.0))


func set_ground(y: float) -> void:
	_base_y = y
	if not dead:
		position.y = y


# =====================================================================
#   свои детали Kit (палитра Synty, плоские грани)
# =====================================================================

static func _kit_mesh(name: String) -> Mesh:
	if _kit.has(name):
		return _kit[name]
	var k := Kit.new()
	match name:
		"#stone":
			k.blob(Vector3.ZERO, Vector3(0.045, 0.04, 0.045), Color("8e8a80"), 3, 0.15)
		"#boulder":
			k.blob(Vector3.ZERO, Vector3(0.2, 0.18, 0.2), Color("8a8478"), 5, 0.22)
		"#eye":
			# один большой глаз циклопа — на лбу, смотрит вперёд (+Z головы)
			k.blob(Vector3(0, 0.12, 0.1), Vector3(0.075, 0.06, 0.035), Color("f2ede2"), 9, 0.04)
			k.blob(Vector3(0, 0.12, 0.13), Vector3(0.032, 0.032, 0.012), Color("3a2a1c"), 4, 0.02)
		"#tusks":
			for sx: float in [-1.0, 1.0]:
				k.rod(Vector3(sx * 0.06, -0.02, 0.0), Vector3(sx * 0.1, 0.08, 0.06), 0.022, 4, Color("f2ead6"))
		"#ballista":
			_k_ballista(k)
		"#ballista_bolt":
			var y := 1.12
			k.rod(Vector3(0, y + 0.13, -0.45), Vector3(0, y + 0.13, 1.05), 0.024, 5, CatMilitary.WOOD_L)
			k.xf = Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, y + 0.13, 1.05))
			k.cone(Vector3(0, 0, 0), 0.045, 0.17, 5, CatMilitary.BRONZE)
			k.xf = Transform3D.IDENTITY
		"#onager":
			_k_onager(k)
		"#onager_arm":
			_k_onager_arm(k)
		"#arrow":
			k.rod(Vector3(0, 0, -0.32), Vector3(0, 0, 0.28), 0.012, 4, CatMilitary.WOOD_L)
			k.xf = Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0, 0.28))
			k.cone(Vector3.ZERO, 0.025, 0.07, 4, CatMilitary.IRON)
			k.xf = Transform3D.IDENTITY
			k.boxc(Vector3(0, -0.02, -0.28), Vector3(0.006, 0.07, 0.1), CatMilitary.CREAM)
			k.boxc(Vector3(0, -0.02, -0.28), Vector3(0.07, 0.006, 0.1), CatMilitary.CREAM)
		"#bolt":
			k.rod(Vector3(0, 0, -0.55), Vector3(0, 0, 0.45), 0.03, 5, CatMilitary.WOOD_L)
			k.xf = Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0, 0.45))
			k.cone(Vector3.ZERO, 0.055, 0.18, 5, CatMilitary.BRONZE)
			k.xf = Transform3D.IDENTITY
			k.boxc(Vector3(0, 0, -0.5), Vector3(0.012, 0.13, 0.16), CatMilitary.RED)
		"#rock":
			k.blob(Vector3.ZERO, Vector3(0.2, 0.18, 0.2), Color("958f84"), 6, 0.2)
		"#rock_big":
			k.blob(Vector3.ZERO, Vector3(0.36, 0.32, 0.36), Color("8a8478"), 8, 0.24)
		"#pebble":
			k.blob(Vector3.ZERO, Vector3(0.06, 0.055, 0.06), Color("7d786e"), 2, 0.15)
		"#cauldron":
			# котёл с маслом на перекладине (умение «Кипящее масло»)
			k.cyl(Vector3(0, -0.4, 0), 0.5, 0.55, 12, Color("4a3a30"), 0.62)
			k.cyl(Vector3(0, 0.12, 0), 0.6, 0.06, 12, CatMilitary.BRONZE)
			k.cyl(Vector3(0, 0.08, 0), 0.52, 0.02, 12, Color("e8a43a"))
			k.rod(Vector3(-0.75, 0.15, 0), Vector3(0.75, 0.15, 0), 0.045, 6, CatMilitary.WOOD_D)
		_:
			k.boxc(Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 0.5), Color.MAGENTA)
	var m := k.mesh()
	if m.get_surface_count() > 0:
		m.surface_set_material(0, Kit.material(0.9))
	_kit[name] = m
	return m


## Баллиста как в мастерской (CatMilitary), но болт — отдельной деталью (исчезает при выстреле)
static func _k_ballista(k: Kit) -> void:
	var y := 1.12
	var W := CatMilitary.WOOD
	var WD := CatMilitary.WOOD_D
	for l: Vector3 in [Vector3(-0.62, 0, 0.5), Vector3(0.62, 0, 0.5), Vector3(0, 0, -0.75)]:
		k.rod(Vector3(0, y - 0.1, 0), l, 0.045, 5, WD)
	k.cyl(Vector3(0, y - 0.22, 0), 0.09, 0.2, 8, CatMilitary.IRON)
	k.boxc(Vector3(0, y, -0.15), Vector3(0.18, 0.14, 2.0), W)
	k.boxc(Vector3(0, y + 0.08, -0.15), Vector3(0.08, 0.03, 1.95), WD)
	k.boxc(Vector3(0, y + 0.04, 0.62), Vector3(0.95, 0.12, 0.2), WD)
	k.boxc(Vector3(0, y + 0.52, 0.62), Vector3(0.95, 0.12, 0.2), WD)
	for sx: float in [-1.0, 1.0]:
		k.boxc(Vector3(sx * 0.46, y + 0.28, 0.62), Vector3(0.06, 0.5, 0.2), WD)
		k.cyl(Vector3(sx * 0.27, y + 0.1, 0.62), 0.085, 0.38, 8, CatMilitary.ROPE)
		k.cyl(Vector3(sx * 0.27, y + 0.08, 0.62), 0.11, 0.05, 8, CatMilitary.BRONZE)
		k.cyl(Vector3(sx * 0.27, y + 0.47, 0.62), 0.11, 0.05, 8, CatMilitary.BRONZE)
		k.rod(Vector3(sx * 0.27, y + 0.28, 0.66), Vector3(sx * 0.85, y + 0.28, 0.25), 0.035, 5, W)
		k.rod(Vector3(sx * 0.85, y + 0.28, 0.25), Vector3(0, y + 0.13, -0.45), 0.008, 3, CatMilitary.CREAM)
	k.boxc(Vector3(0, y + 0.28, 0.75), Vector3(0.36, 0.42, 0.03), CatMilitary.RED_D)
	k.cyl(Vector3(0, y + 0.28, 0.76), 0.07, 0.03, 8, CatMilitary.BRONZE)
	k.boxc(Vector3(0, y + 0.13, -0.35), Vector3(0.12, 0.02, 0.1), CatMilitary.RED)
	k.rod(Vector3(-0.2, y - 0.02, -1.05), Vector3(0.2, y - 0.02, -1.05), 0.06, 8, W)
	for sx: float in [-1.0, 1.0]:
		k.rod(Vector3(sx * 0.21, y - 0.02, -1.05), Vector3(sx * 0.21, y + 0.2, -1.15), 0.02, 4, CatMilitary.IRON)


## Онагр как в мастерской (CatMilitary), но без рычага — рычаг отдельно (бьёт при выстреле)
static func _k_onager(k: Kit) -> void:
	var W := CatMilitary.WOOD
	var WD := CatMilitary.WOOD_D
	for sx: float in [-1.0, 1.0]:
		k.boxc(Vector3(sx * 0.62, 0.42, 0), Vector3(0.2, 0.22, 3.0), W)
		for sz: float in [-1.05, 1.05]:
			k.rod(Vector3(sx * 0.74, 0.36, sz), Vector3(sx * 0.88, 0.36, sz), 0.36, 10, WD)
			k.rod(Vector3(sx * 0.73, 0.36, sz), Vector3(sx * 0.9, 0.36, sz), 0.08, 6, CatMilitary.IRON)
	for z: float in [-1.3, -0.55, 0.5, 1.3]:
		k.boxc(Vector3(0, 0.44, z), Vector3(1.44, 0.16, 0.18), WD)
	k.rod(Vector3(-0.52, 0.55, -0.55), Vector3(0.52, 0.55, -0.55), 0.15, 8, CatMilitary.ROPE)
	for sx: float in [-1.0, 1.0]:
		k.rod(Vector3(sx * 0.5, 0.55, -0.55), Vector3(sx * 0.6, 0.55, -0.55), 0.2, 8, CatMilitary.BRONZE)
		k.rod(Vector3(sx * 0.62, 0.5, 0.75), Vector3(sx * 0.5, 1.62, 0.35), 0.07, 6, W)
		k.rod(Vector3(sx * 0.62, 0.5, -0.2), Vector3(sx * 0.5, 1.62, 0.35), 0.06, 6, W)
	k.rod(Vector3(-0.62, 1.62, 0.35), Vector3(0.62, 1.62, 0.35), 0.09, 6, WD)
	k.blob(Vector3(0, 1.62, 0.45), Vector3(0.28, 0.13, 0.12), CatMilitary.STRAW, 21, 0.1)
	k.rod(Vector3(-0.62, 0.62, -1.3), Vector3(0.62, 0.62, -1.3), 0.08, 8, W)
	for sx: float in [-1.0, 1.0]:
		for j in 4:
			var ang := j * PI / 2.0
			k.rod(Vector3(sx * 0.66, 0.62, -1.3), Vector3(sx * 0.66, 0.62 + cos(ang) * 0.32, -1.3 + sin(ang) * 0.32), 0.02, 4, WD)


## Рычаг онагра, взведённый назад, с ковшом и камнем (координаты как у онагра — ось вращения у пучка)
static func _k_onager_arm(k: Kit) -> void:
	var a := Vector3(0, 0.6, -0.55)
	var e := Vector3(0, 1.05, -2.05)
	k.rod(a, e, 0.075, 6, CatMilitary.WOOD_L)
	k.boxc(e + Vector3(0, 0.02, 0), Vector3(0.38, 0.12, 0.38), CatMilitary.WOOD_D)
	k.blob(e + Vector3(0, 0.2, 0), Vector3(0.17, 0.15, 0.17), CatMilitary.STONE, 31, 0.12)
