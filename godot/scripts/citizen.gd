class_name Citizen
extends Node3D
## Житель — персонаж Synty Ancient Empire (рабочие, фермеры, патриции, политик) с движениями из бесплатной
## библиотеки Quaternius. Оба скелета при импорте приведены к общему стандарту (BoneMap → гуманоид),
## поэтому движения подходят без переделки. Текстура — общая палитра Synty; вариант палитры (A/B/C)
## меняет тон кожи и волос. Одежду красит шейдер citizen_cloth: у каждого жителя свои цвета по сословию.

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
static var _cloth: Shader

## Где на модели ткани: полосы атласа (0–13 блок тканей, 14–18 белые, 19 меандр). k — ткань лежит
## в среднем тоне атласа: цвет чуть светлее, чтобы на экране был как в палитре. Солдат тут нет — они в своём красном
const CLOTH := {
	"SK_Chr_Worker_Male_01": {"main": [2], "trim": [19]},                 # туника; узорная кайма
	"SK_Chr_Worker_Female_01": {"main": [10], "trim": [12]},              # платье; поясок
	"SK_Chr_Farmer_Male_01": {"main": [0]},                               # туника с тёмным подолом
	"SK_Chr_Farmer_Female_01": {"main": [1], "k": 1.19},                  # платье в два тона
	"SK_Chr_Upperclass_Male_01": {"main": [9], "second": [8]},            # туника; тога
	"SK_Chr_Upperclass_Female_01": {"main": [2], "second": [16], "trim": [12], "k": 1.19},  # стола; нижняя туника; кайма
	"SK_Chr_Politician_Male_01": {"main": [3], "second": [17]},           # туника сенатора; тога
}
## Римские краски: [цвет, вес]. Плебеи пестрее, чем было в истории, — так веселее улица
const PAL := {
	# некрашеная шерсть (белая, овсяная, серая, бурая, ореховая), марена, охра, резеда, вайда, олива, ржавчина
	"plebs": [["d8ccb0", 8], ["b9a88a", 7], ["9a958a", 5], ["7a5f45", 7], ["5e4836", 3], ["a9503a", 14], ["b8776a", 8],
		["c49a4a", 12], ["d9a93e", 6], ["5f7c96", 11], ["7a7e4c", 8], ["b86b3a", 8]],
	# марена, розовая марена, шафран, резеда, оранжевый, вайда, небесный, морская волна, мирт, охра, сливки, каштан
	"artisans": [["b4432f", 12], ["c9786e", 8], ["d9a93e", 11], ["cdb24e", 6], ["c9733a", 8], ["4d7397", 11], ["7fa3be", 8],
		["5e9488", 7], ["6f8a4e", 7], ["b58a52", 8], ["d9cdb2", 8], ["8a5a3c", 6]],
	# туника патриция под тогой: кермес, тирский пурпур, аметист, золото шафрана, индиго, небесный, морская волна, белая, роза, охра
	"patricians_m": [["a3283a", 14], ["6e2a5a", 10], ["8a5c9a", 8], ["d7a23a", 12], ["2f5585", 12], ["7fa6c6", 8], ["4f8c80", 8],
		["e8e2d6", 14], ["c97c84", 8], ["c08a3e", 6]],
	# стола матроны — цвета из Овидия: шафран, небо, индиго, морская волна, аметист, бледная роза, кермес, пурпур, мирт, миндаль, воск
	"patricians_f": [["d8a13c", 12], ["7ea4c8", 10], ["34588c", 10], ["4e9086", 9], ["8c5fa0", 10], ["d59098", 9], ["a82c3c", 10],
		["6a2858", 8], ["6e8c55", 6], ["d8b98c", 8], ["e0c46a", 8]],
	"senator": [["6e2a5a", 35], ["a3283a", 30], ["8a5c9a", 15], ["aa4638", 20]],   # пурпур, кермес, аметист, марена
	"toga": [["eee8dc", 45], ["f4f1ea", 25], ["e3d8c3", 30]],                     # чистая, белёная мелом, небелёная
	"palla": [["ede6d8", 60], ["f3efe7", 40]],
	"gold_trim": [["d4a548", 55], ["6e2a5a", 25], ["a82c3c", 20]],
	"belt": [["c49a4a", 25], ["a9503a", 25], ["5f7c96", 20], ["7a5f45", 20], ["d8ccb0", 10]],
}


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


## Новое движение из застывшего кадра t движения src (длина L); к поворотам костей из offs — смещение по времени (как _layer)
static func _frozen(src: Animation, t: float, L: float, offs: Dictionary) -> Animation:
	var a := Animation.new()
	a.length = L
	a.loop_mode = Animation.LOOP_LINEAR
	var node := "%GeneralSkeleton"
	var done := {}
	for i in src.get_track_count():
		var path := String(src.track_get_path(i))
		node = path.get_slice(":", 0)
		var bone := path.get_slice(":", 1)
		var ty := src.track_get_type(i)
		if ty != Animation.TYPE_ROTATION_3D and ty != Animation.TYPE_POSITION_3D:
			continue
		var nt := a.add_track(ty)
		a.track_set_path(nt, src.track_get_path(i))
		if ty == Animation.TYPE_POSITION_3D:
			a.position_track_insert_key(nt, 0.0, src.position_track_interpolate(i, t))
			continue
		var q := src.rotation_track_interpolate(i, t)
		if not offs.has(bone):
			a.rotation_track_insert_key(nt, 0.0, q)
			continue
		done[bone] = true
		var f: Callable = offs[bone]
		var n := int(L * 24.0)
		for k in n + 1:
			var tt := L * k / n
			a.rotation_track_insert_key(nt, tt, q * Quaternion.from_euler(f.call(tt)))
	for bone in offs:
		if done.has(bone):
			continue
		var nt := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(nt, NodePath(node + ":" + bone))
		var f: Callable = offs[bone]
		var n := int(L * 24.0)
		for k in n + 1:
			var tt := L * k / n
			a.rotation_track_insert_key(nt, tt, Quaternion.from_euler(f.call(tt)))
	return a


## Движение src, в котором кости bones взяты из кадра t движения donor (и лишь на долю swing ходят, как в src)
static func _graft(src: Animation, donor: Animation, t: float, bones: Array, swing := 0.0) -> Animation:
	var a := src.duplicate(true) as Animation
	for i in a.get_track_count():
		var bone := String(a.track_get_path(i)).get_slice(":", 1)
		if a.track_get_type(i) != Animation.TYPE_ROTATION_3D or not (bone in bones):
			continue
		var di := donor.find_track(a.track_get_path(i), Animation.TYPE_ROTATION_3D)
		if di < 0:
			continue
		var q := donor.rotation_track_interpolate(di, t)
		for k in a.track_get_key_count(i):
			var qs: Quaternion = a.track_get_key_value(i, k)
			a.track_set_key_value(i, k, q.slerp(qs, swing))
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
	# играет на лире (уличный музыкант): сидит, как возница (руки перед собой), лира — в левой руке (HandProps),
	# правая перебирает струны, голова и плечи — в такт
	var Lp := 2.4
	var lyre := _frozen(lib.get_animation("Driving"), 0.8, Lp, {
		"RightLowerArm": func(t: float) -> Vector3: return Vector3(0.0, 0.22 * sin(TAU * t / 0.6), 0.1 * sin(TAU * t / 0.6 + 0.6)),
		"RightHand": func(t: float) -> Vector3: return Vector3(0.35 * sin(TAU * t / 0.6 + 0.9), 0.0, 0.0),
		"Head": func(t: float) -> Vector3: return Vector3(0.07 * sin(TAU * t / 1.2), 0.0, 0.05 * sin(TAU * t / Lp)),
		"UpperChest": func(t: float) -> Vector3: return Vector3(0.0, 0.0, 0.035 * sin(TAU * t / Lp))})
	lib.add_animation("Play_Lyre", lyre)
	# несёт покупку: левая рука почти не машет (опущена, как стоя), вещь в ней (HandProps, People.carry)
	lib.add_animation("Walk_Carry", _graft(lib.get_animation("Walk"), idle, 0.4, ["LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand"], 0.25))
	# зеркальные: жест другой рукой, кивок в другую сторону
	for n in ["Idle_Talking", "Interact", "PickUp_Table", "Spell_Simple_Idle", "Sitting_Talking", "Sitting_Idle", "Fixing_Kneeling", "Crouch_Idle", "Listen", "Look_Around"]:
		if lib.has_animation(n):
			lib.add_animation(n + "_M", _mirror(lib.get_animation(n)))


static var _plain_mats := {}


## Обычный материал без перекраски (причёски, бороды, венки; всё — в режиме совместимости для старых видеокарт,
## где место под instance uniform мало)
static func _plain(variant: String) -> StandardMaterial3D:
	if not _plain_mats.has(variant):
		var m := StandardMaterial3D.new()
		m.albedo_texture = Gfx.tex(Synty._tex_path("PolygonAncientEmpire_01_" + variant))   # «Очень низкая» — копия поменьше
		m.roughness = 0.85
		_plain_mats[variant] = m
	return _plain_mats[variant]


## Три общих материала на всех (тон кожи A/B/C); цвета одежды — у каждого жителя свои (instance uniform)
static func _material(variant: String) -> ShaderMaterial:
	if not _mats.has(variant):
		if _cloth == null:
			_cloth = load("res://shaders/citizen_cloth.gdshader")
		var m := ShaderMaterial.new()
		m.shader = _cloth
		m.set_shader_parameter("albedo_tex", Gfx.tex(Synty._tex_path("PolygonAncientEmpire_01_" + variant)))
		_mats[variant] = m
	return _mats[variant]


## Цвет из палитры по весам; avoid — кроме этого цвета (кайма не сливается с одеждой)
static func _pick(cr: RandomNumberGenerator, pal: Array, avoid := Color(-1, 0, 0)) -> Color:
	var opts := pal.filter(func(e): return Color(String(e[0])) != avoid)
	var sum := 0
	for e in opts:
		sum += int(e[1])
	var x := cr.randi() % maxi(sum, 1)
	for e in opts:
		x -= int(e[1])
		if x < 0:
			return Color(String(e[0]))
	return Color(String(pal[0][0]))


static func _bits(cols: Array) -> int:
	var b := 0
	for i: int in cols:
		b |= 1 << i
	return b


## Одежда по сословию: туника/платье — из палитры сословия, тога — белая, кайма и пояс — свои.
## Цвета [основной, второй, кайма] (без поправки k — она при раскраске); у модели без своих тканей — []
static func _cloth_cols(model: String, cls: String, female: bool, child: bool, cr: RandomNumberGenerator) -> Array:
	var map: Dictionary = CLOTH.get(model, {})
	if map.is_empty():
		return []
	var rich := cls == "patricians"
	var pal: Array = PAL.get(cls, PAL["plebs"])
	if model == "SK_Chr_Politician_Male_01":
		pal = PAL["senator"]
	elif rich:
		pal = PAL["patricians_f"] if female else PAL["patricians_m"]
	elif child and cr.randf() < 0.3:
		pal = PAL["artisans"]                     # детям чаще яркое
	var main := _pick(cr, pal)
	var second := _pick(cr, PAL["toga"])
	if model == "SK_Chr_Upperclass_Female_01":
		second = _pick(cr, PAL["palla"]) if cr.randf() < 0.6 else _pick(cr, PAL["patricians_f"], main)
	var trim := _pick(cr, PAL["belt"], main)
	if model == "SK_Chr_Worker_Male_01":
		trim = main.lerp(Color("e8dfcc"), 0.55)   # кайма — светлее той же ткани, как у Synty
	elif model == "SK_Chr_Upperclass_Female_01":
		trim = _pick(cr, PAL["gold_trim"])
	return [main, second, trim]


## Раскрасить тело: цвета [основной, второй, кайма] по тканям модели (instance uniform — у каждого свои)
static func _paint(body: Node3D, model: String, cols: Array) -> void:
	var map: Dictionary = CLOTH.get(model, {})
	if map.is_empty() or cols.size() < 3:
		return
	var main: Color = cols[0]
	var k: float = map.get("k", 1.0)
	main = Color(minf(main.r * k, 1.0), minf(main.g * k, 1.0), minf(main.b * k, 1.0))
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		mi.set_instance_shader_parameter("cloth_main", main.srgb_to_linear())
		mi.set_instance_shader_parameter("cloth_second", (cols[1] as Color).srgb_to_linear())
		mi.set_instance_shader_parameter("cloth_trim", (cols[2] as Color).srgb_to_linear())
		mi.set_instance_shader_parameter("mask_main", _bits(map.get("main", [])))
		mi.set_instance_shader_parameter("mask_second", _bits(map.get("second", [])))
		mi.set_instance_shader_parameter("mask_trim", _bits(map.get("trim", [])))


static func _dress(body: Node3D, model: String, cls: String, female: bool, child: bool, cr: RandomNumberGenerator) -> void:
	_paint(body, model, _cloth_cols(model, cls, female, child, cr))


## Облик жителя (этап 6.5) — всё явно: mdl (модель Synty), skin (тон кожи A/B/C), hair (причёска; у мужчин 0 — бритая
## голова), beard (борода, 0 — нет), crown (лавровый венок, 0 — нет), main/second/trim (цвета одежды, «rrggbb»),
## hc (цвет волос: "" — свой, A/B/C — тон палитры Synty, S — седые). Из rng тянется ровно то же и в том же порядке,
## что раньше в create: облик по тому же зерну прежний (и у героев историй, и у жителей)
static func roll_look(rng: RandomNumberGenerator, is_female: bool, child := false, rich := false, model := "", cls := "") -> Dictionary:
	var pool: Array = RICH if rich else PLEBS
	var choices := pool.filter(func(n): return (n in FEMALE) == is_female)
	if choices.is_empty():
		choices = pool
	var name: String = model if model != "" else choices[rng.randi() % choices.size()]
	var fem := name in FEMALE
	var variant: String = ["A", "A", "B", "C"][rng.randi() % 4]
	# одежда: свой поток случайностей от СОСТОЯНИЯ rng — rng не сдвигается, лица и причёски прежние,
	# а один и тот же житель всегда в той же одежде (и на повозке, и на улице, и после возврата в кадр)
	var cr := RandomNumberGenerator.new()
	cr.seed = rng.state ^ 0x5DEECE66D
	var cols := _cloth_cols(name, cls if cls != "" else ("patricians" if rich else "plebs"), fem, child, cr)
	# причёска (и борода у части мужчин). Ребёнку — без бороды и венка, и не лысеющая «седьмая»;
	# случайности тянем те же и в том же порядке: взрослые и облик героев историй (по seed) не меняются
	var hm := 1 + rng.randi() % 7 if not fem else 0
	if child and hm == 7:
		hm = (hm % 6) + 1
	var hair := (1 + rng.randi() % 6) if fem else hm
	var beard := 0
	if not fem and rng.randf() < 0.45:
		var bd := 1 + rng.randi() % 4
		if not child:
			beard = bd
	var crown := 0
	if rich and rng.randf() < 0.3:
		var cw := 1 + rng.randi() % 2
		if not child:
			crown = cw
	var lk := {"mdl": name, "skin": variant, "hair": hair, "beard": beard, "crown": crown, "hc": ""}
	if cols.size() == 3:
		lk["main"] = (cols[0] as Color).to_html(false)
		lk["second"] = (cols[1] as Color).to_html(false)
		lk["trim"] = (cols[2] as Color).to_html(false)
	return lk


## Облик из сохранения — с целыми числами и строками (JSON отдаёт дробные)
static func norm_look(lk: Dictionary) -> void:
	for k: String in ["hair", "beard", "crown"]:
		lk[k] = int(lk.get(k, 0))
	for k: String in ["mdl", "skin", "hc", "main", "second", "trim"]:
		if lk.has(k):
			lk[k] = String(lk[k])
	if not (String(lk.get("mdl", "")) in PLEBS + RICH):
		lk["mdl"] = PLEBS[0]
	if not (String(lk.get("skin", "")) in ["A", "B", "C"]):
		lk["skin"] = "A"


## Отпечаток облика (проверки «облик не поменялся»)
static func look_key(lk: Dictionary) -> String:
	return "%s|%s|%d|%d|%d|%s|%s|%s|%s" % [lk.get("mdl", ""), lk.get("skin", ""), int(lk.get("hair", 0)), int(lk.get("beard", 0)),
		int(lk.get("crown", 0)), lk.get("main", ""), lk.get("second", ""), lk.get("trim", ""), lk.get("hc", "")]


## rich — патриций; child — ребёнок (уменьшенный взрослый); cls — сословие для одежды (по умолчанию по rich)
static func create(rng: RandomNumberGenerator, is_female: bool, child := false, rich := false, model := "", cls := "") -> Citizen:
	var c := build(roll_look(rng, is_female, child, rich, model, cls), child)
	c.anim.speed_scale = rng.randf_range(0.92, 1.08)
	return c


var look := {}                         # облик, по которому собран (roll_look)
var hair_att: BoneAttachment3D         # кость головы: причёска, борода, венок
var kid := false


## Житель по облику look (roll_look; свой у героя и у тех, кто сменил причёску и одежду — этап 6.5)
static func build(lk: Dictionary, child := false) -> Citizen:
	Synty._index()
	var c := Citizen.new()
	var name := String(lk.get("mdl", PLEBS[0]))
	c.female = name in FEMALE
	c.kid = child
	var body := _scene(DIR + name + ".fbx").instantiate() as Node3D
	c.add_child(body)
	var variant := String(lk.get("skin", "A"))
	var dyed := RenderingServer.get_current_rendering_method() != "gl_compatibility"
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = _material(variant) if dyed else _plain(variant)
	if dyed:
		_paint(body, name, _cols_of(lk))
	var sk: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	c.hair_att = BoneAttachment3D.new()
	c.hair_att.bone_name = "Head"
	sk.add_child(c.hair_att)
	c.look = lk
	c._put_hair()
	c.anim = AnimationPlayer.new()
	body.add_child(c.anim)
	c.anim.root_node = NodePath("..")
	c.anim.add_animation_library("", library())
	c.scale = Vector3.ONE * SIZE * (0.68 if child else 1.0)
	if child:
		kid_face(c)
	return c


## Цвета одежды облика: [основной, второй, кайма] или [] (облик без цветов)
static func _cols_of(lk: Dictionary) -> Array:
	if not (lk.has("main") and lk.has("second") and lk.has("trim")):
		return []
	return [Color(String(lk["main"])), Color(String(lk["second"])), Color(String(lk["trim"]))]


## Причёска, борода и венок на кости головы — по облику (прежние убираются)
func _put_hair() -> void:
	if hair_att == null:
		return
	for ch in hair_att.get_children():
		hair_att.remove_child(ch)
		ch.free()
	var hairs := []
	var h := int(look.get("hair", 1))
	if female:
		hairs.append("SM_Chr_Hair_Female_0%d" % clampi(h, 1, 6))
	elif h > 0:
		hairs.append("SM_Chr_Hair_Male_0%d" % clampi(h, 1, 7))
	if not female and not kid and int(look.get("beard", 0)) > 0:
		hairs.append("SM_Chr_Hair_Beard_0%d" % clampi(int(look["beard"]), 1, 4))
	var crown := "SM_Chr_Attach_Crown_Leaf_0%d" % clampi(int(look.get("crown", 0)), 1, 2)
	if not kid and int(look.get("crown", 0)) > 0:
		hairs.append(crown)
	var variant := String(look.get("skin", "A"))
	var hc := String(look.get("hc", ""))
	for hn_name: String in hairs:
		var hn := _scene("res://assets/synty/FBX/Attachments/" + hn_name + ".fbx").instantiate() as Node3D
		var mat: Material = _plain(variant)
		if hn_name != crown:
			mat = _hair_mat(hc, variant)
		for mi: MeshInstance3D in hn.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = mat
		hair_att.add_child(hn)
	meshes = []                            # set_alpha заново найдёт сетки (причёска новая)


## Материал волос: свой тон палитры (A/B/C) или седые
static func _hair_mat(hc: String, variant: String) -> Material:
	if hc == "S":
		if _silver == null:
			_silver = StandardMaterial3D.new()
			_silver.albedo_color = Color("d2cdc4")
			_silver.roughness = 0.9
		return _silver
	return _plain(hc if hc in ["A", "B", "C"] else variant)


## Сменить облик на ходу (причёска, борода, венок, цвета одежды, цвет волос) — без новой модели: модель и тон кожи
## у жителя свои навсегда. false — нужна другая модель (такой облик собирать заново)
func apply_look(lk: Dictionary) -> bool:
	if String(lk.get("mdl", "")) != String(look.get("mdl", "")) or String(lk.get("skin", "")) != String(look.get("skin", "")):
		return false
	look = lk
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		var body := get_child(0) as Node3D
		if body:
			_paint(body, String(lk["mdl"]), _cols_of(lk))
	_put_hair()
	return true


const KID_HEAD := 1.22                  # голова ребёнка крупнее (как было у детей в роликах)


## Ребёнок — на улице, в повозке, в ролике и на портрете одинаково: без щетины на подбородке и бритой голове
## (пятно щетины атласа → кожа), брови тоньше, голова крупнее. Дети у нас — уменьшенные взрослые Synty; одна копия
## сетки на модель тела, в кадре ничего не считается. Повторно — ничего не меняет
static func kid_face(c: Node) -> void:
	for mi: MeshInstance3D in c.find_children("*", "MeshInstance3D", true, false):
		if mi.skin != null and mi.mesh is ArrayMesh:
			mi.mesh = _face_mesh(mi.mesh, false, true)
	for sk: Skeleton3D in c.find_children("*", "Skeleton3D", true, false):
		var hb := sk.find_bone("Head")
		if hb >= 0:
			sk.set_bone_pose_scale(hb, Vector3.ONE * KID_HEAD)


## phase ≥ 0 — начать с этой доли движения (чтобы соседи не двигались в такт)
func play(name: String, blend := 0.25, phase := -1.0) -> void:
	if carry_walk and (name == "Walk_Loop" or name == "Walk"):
		name = "Walk_Carry"                  # несёт покупку — левая рука с вещью почти не машет
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


var carry_walk := false


## Несёт покупку (People: вещь в левой руке) — шаг с опущенной рукой; перестал — обычный шаг
func set_carry(on: bool) -> void:
	if carry_walk == on:
		return
	carry_walk = on
	if on and _cur in ["Walk_Loop", "Walk"]:
		_cur = ""
		play("Walk_Loop", 0.2)
	elif not on and _cur == "Walk_Carry":
		_cur = ""
		play("Walk_Loop", 0.2)


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


static var _face_meshes := {}          # «сетка тела Synty:старик» → её копия с поправленными бровями (для роликов и портретов)
static var _silver: StandardMaterial3D
const BROW_UV := Vector2(0.0515, 0.816) # брови на атласе — пятно цвета волос
const GREY_UV := Vector2(0.3896, 0.9912) # светло-серая полоса атласа (её шейдер одежды не перекрашивает) — седые брови
const STUBBLE_UV := Vector2(0.0186, 0.835) # щетина на подбородке (и бритая голова) у мужчин Synty
const SKIN_UV := Vector2(0.0204, 0.8139)   # кожа лица
const FACE_LAYER := 1 << 10            # слой «лица вблизи»: свет-заполнение в роликах историй светит только на них
static var plain_faces := false        # проверка «до/после»: лица вблизи как раньше (без правки бровей и света спереди)


## Лицо вблизи (ролики историй, портреты в облачке). У мужчин Synty одна широкая бровь-брусок, она нависает над глазами
## и закрывает их верхнюю половину; у тёмных вариантов палитры (B, C) бровь почти чёрная — вблизи, да ещё в тени
## от бруска, выходит сплошная чёрная полоса, как тёмные очки. Это рисунок Synty (тот же брусок с их же материалом),
## не наш материал. Тем, кого показываем вблизи, даём копию сетки: бровь тоньше и выше (над глазами — полоска кожи),
## середина бруска уходит в лоб — выходят две брови. У женщин брови и так две — их чуть тоньше и выше.
## Толпа на улицах — как была (там лицо — пара точек), и сетки общие: одна копия на модель.
## old — старик: брови седые; young — ребёнок: без щетины (дети у нас — уменьшенные взрослые Synty).
## Ещё — слой FACE_LAYER: в ролике на лица светит мягкий свет спереди (Stories)
static func face_fix(n: Node, old := false, young := false) -> void:
	if plain_faces:
		return
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.skin != null and mi.mesh is ArrayMesh:
			mi.mesh = _face_mesh(mi.mesh, old, young)
		mi.layers |= FACE_LAYER


## Старик: волосы и борода седые, брови светлые
static func elder_look(n: Node) -> void:
	if _silver == null:
		_silver = StandardMaterial3D.new()
		_silver.albedo_color = Color("d2cdc4")
		_silver.roughness = 0.9
	for att in n.find_children("*", "BoneAttachment3D", true, false):
		for mi: MeshInstance3D in att.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = _silver
	face_fix(n, true)


static func _face_mesh(m: ArrayMesh, old := false, young := false) -> ArrayMesh:
	var key := "%d:%s:%s" % [m.get_instance_id(), old, young]
	if _face_meshes.has(key):
		return _face_meshes[key]
	_face_meshes[key] = m
	if m.get_surface_count() != 1 or m.get_blend_shape_count() > 0:
		return m
	var arr := m.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var brow := []
	var y1 := -INF
	var one := false                     # брусок через всё лицо (есть вершины посередине)
	for i in v.size():
		if v[i].y > 1.55 and absf(uv[i].x - BROW_UV.x) < 0.01 and absf(uv[i].y - BROW_UV.y) < 0.01:
			brow.append(i)
			y1 = maxf(y1, v[i].y)
			one = one or absf(v[i].x) < 0.004
	if brow.is_empty():
		return m
	var k := 0.6 if one else 0.8         # толщина брови (доля прежней)
	var lift := 0.006 if one else 0.003  # и выше на столько
	for i: int in brow:
		var p := v[i]
		p.y = y1 + lift - (y1 - p.y) * k
		if not one:
			p.y += 0.006 * (1.0 - clampf(absf(p.x) / 0.06, 0.0, 1.0))   # у переносицы — повыше: взгляд добрее, не хмурый
		if one and absf(p.x) < 0.004:
			p.z -= 0.014                     # середина бруска — в лоб: две брови, сходятся к переносице
		v[i] = p
		if old:
			uv[i] = GREY_UV
	if young:
		# щетина у мужчин Synty — два пятна атласа: бритая голова (STUBBLE_UV) и подбородок (≈0,022–0,028; 0,833)
		for i in v.size():
			if v[i].y > 1.45 and uv[i].x < 0.035 and uv[i].y > 0.825 and uv[i].y < 0.845:
				uv[i] = SKIN_UV
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	var fmt := m.surface_get_format(0)
	var flags := fmt & (Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS | (((1 << 12) - 1) << Mesh.ARRAY_FORMAT_CUSTOM_BASE))
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
	out.surface_set_material(0, m.surface_get_material(0))
	_face_meshes[key] = out
	_face_meshes["%d:%s:%s" % [out.get_instance_id(), old, young]] = out   # копию ещё раз — та же (ребёнок в ролике)
	return out


## Совместимость со старым кодом: относительное преобразование узла внутри предка top
static func _rel(n: Node3D, top: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var p: Node = n
	while p != top and p is Node3D:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf
