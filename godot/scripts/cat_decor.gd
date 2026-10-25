class_name CatDecor
extends RefCounted
## Облик украшений (Украшения). Чертёж Bp строится в родных размерах Synty;
## Catalog.make потом уменьшает его до «кукольного» масштаба (Catalog.DECOR).
## Каждое украшение — маленькая уютная сценка как в Town to City: клумба в каменном бортике,
## скамья между терракотовыми горшками, колодец под черепичной крышей, телега с товаром, статуя на постаменте.
## Облик (look) — своя карточка в меню стройки (Defs.B: «flowers», «flowers_2»…, поле look): что игрок выбрал,
## то и встанет, где бы он ни поставил. Цвет и место облик не меняют: Catalog.make строит украшение всегда
## с одним и тем же цветом, а мелочи (какой именно кувшин, поворот цветка) берутся из b.rng, который зависит
## только от типа, — поэтому картинка карточки и поставленное украшение одинаковы. Деталей немного (≤ ~22).
## Настенные (wall): начало координат — на поверхности стены, +Z — от стены наружу.

const M := Bp.M
const FL := Bp.FL

## Цветущие кустики (розовые, красные с сиреневым, оранжевые, пёстрые)
const BLOOMS := ["SM_Env_Garden_Plants_03", "SM_Env_Garden_Plants_04", "SM_Env_Garden_Plants_06", "SM_Env_Garden_Plants_03", "SM_Env_Garden_Plants_06"]
## Без зелёной подкраски Synty (она делает розовые и сиреневые цветы рыжими и серыми)
const TRUE_COLOR := Color(1, 1, 1)
## Тёмная бронза/дерево (древко факела), состаренная позолота (лев), зелень листьев кувшинок
const BRONZE := Color(0.62, 0.45, 0.28)
const GILT := Color(1.0, 1.02, 0.56)
const LILY := Color(0.72, 0.93, 0.62)
const HEDGE := Color(0.62, 0.86, 0.5)      # подстриженная изгородь — сочная зелень, а не жёлтый куст


static func _decor(b: Bp, type: String, variant := 0) -> void:
	b.door = Vector3(0, 0, 1.0)
	var lk := int((Defs.B.get(type, {}) as Dictionary).get("look", 0))
	match Defs.base_of(type):
		"flowers": _flowers(b, lk)
		"planter": _planter(b, lk)
		"tree": _tree(b, lk)
		"cypress": _cypress(b, lk)
		"palm": _palm(b, lk)
		"bush": _bush(b, lk)
		"bench": _bench(b, lk)
		"lamp_post": _lamp_post(b, lk)
		"candelabrum": _candelabrum(b, lk)
		"wall_torch": _wall_torch(b, lk)
		"wall_lamp": _wall_lamp(b, lk)
		"wall_flowers": _wall_flowers(b, lk)
		"wall_banner": _wall_banner(b, lk)
		"fence": _fence(b, lk, variant)
		"fence_wood": _fence_wood(b, variant)
		"hedge": _hedge(b, variant)
		"stonewall": _stonewall(b, variant)
		"hay": _hay(b, lk)
		"amphorae": _amphorae(b, lk)
		"goods": _goods(b, lk)
		"well": _well(b, lk)
		"cart": _cart(b, lk)
		"brazier": _brazier(b, lk)
		"bigbrazier": _bigbrazier(b, lk)
		"banner": _banner(b, lk)
		"sheep": _sheep(b, lk)
		"statue": _statue(b, lk)
		"column": _column(b, lk)
		"lion": _lion(b, lk)
		"sundial": _sundial(b, lk)
		"smallfountain": _smallfountain(b, lk)
		"pergola": _pergola(b, lk)
		"duck": _duck(b)
		"swan": _swan(b)
		"trophy_cart": _trophy_cart(b)
		"catbasket": _catbasket(b)
		"latrunc": _latrunc(b)
		"rosearch": _rosearch(b)
		"donkeypost": _donkeypost(b)
		"balcony": _balcony(b)


# ---------- помощники ----------

## Деталь со своей раскраской (remap), равномерный масштаб
static func _addr(b: Bp, name: String, pos: Vector3, yaw: float, s: float, rm: Dictionary) -> void:
	b.parts.append([name, b.base * Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), pos), rm.duplicate()])


## Деталь с неравномерным масштабом (в своих осях)
static func _sx(b: Bp, name: String, pos: Vector3, yaw: float, sv: Vector3, rm := {}) -> void:
	b.parts.append([name, b.base * Transform3D(Basis(Vector3.UP, yaw).scaled_local(sv), pos), rm.duplicate()])


## Наклонённая деталь (прислонена): наклон tilt вокруг своей оси X после поворота yaw
static func _lean(b: Bp, name: String, pos: Vector3, yaw: float, tilt: float, s := 1.0) -> void:
	b.add_xf(name, Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt) * Basis.from_scale(Vector3.ONE * s), pos))


## Мраморная плита (коробка), низ на y0
static func _slab(b: Bp, c: Vector3, size: Vector3) -> void:
	b.parts.append(["#marble", b.base * Transform3D(Basis.from_scale(size), c + Vector3(0, size.y / 2.0, 0)), {}])


## След на земле там, где детали сами следа не дают (клумба из бортиков, лужок овец): плоская коробка под землёй
static func _ground_fp(b: Bp, w: float, d: float, c := Vector3.ZERO) -> void:
	b.parts.append(["#dark", b.base * Transform3D(Basis.from_scale(Vector3(w, 0.04, d)), c + Vector3(0, -0.35, 0)), {}])


## Огонь в чаше: горка маленьких кубиков-«вокселей», утопленных в угли так, что видны только верхушки.
## Днём они тёмные, как угли; в сумерках разгораются вместе с фонарями (#ember — ярче окон домов).
## c — верх углей, spread — радиус горки, n — сколько кубиков, s1..s0 — размер от середины к краю
static func _fire(b: Bp, c: Vector3, spread: float, n: int, s1: float, s0: float) -> void:
	for k in n:
		var a := k * 2.39996 + b.rng.randf_range(-0.3, 0.3)
		var f := sqrt(float(k) / maxf(1.0, n - 1.0))
		var r := spread * f
		var s := lerpf(s1, s0, f) * b.rng.randf_range(0.9, 1.1)
		var p := c + Vector3(cos(a) * r, s * 0.12 - s * 0.35 * f, sin(a) * r)
		var bs := Basis(Vector3.UP, b.rng.randf() * TAU).scaled(Vector3.ONE * s)
		b.parts.append(["#ember", b.base * Transform3D(bs, p), {}])


## Язычок пламени из трёх кубиков, сужается кверху вдоль up (как огонь из вокселей в Town to City)
static func _flame(b: Bp, p: Vector3, s: float, up := Vector3.UP) -> void:
	var yaw := b.rng.randf() * TAU
	for k in 3:
		var sk: float = [1.0, 0.72, 0.45][k] * s
		var off: float = [0.0, 0.72, 1.28][k] * s
		b.parts.append(["#ember", b.base * Transform3D(Basis(Vector3.UP, yaw + k * 0.5).scaled(Vector3.ONE * sk), p + up * off), {}])


## Цветущий кустик в настоящих цветах
static func _bloom(b: Bp, p: Vector3, s: float) -> void:
	_addr(b, b.pick(BLOOMS), p, b.rng.randf() * TAU, s, {"tint": TRUE_COLOR})


## Терракотовый горшок с цветами, низ на p.y
static func _pot(b: Bp, p: Vector3, s: float) -> void:
	b.add("SM_Prop_Vase_03", p, _yaw(b), 0.7 * s)
	_bloom(b, p + Vector3(0, 0.55 * s, 0), 0.32 * s)


## Южное растение-веер (карликовая пальма) в глиняном пифосе, низ на p.y
static func _topiary(b: Bp, p: Vector3, s: float) -> void:
	b.add("SM_Prop_Jar_01", p, _yaw(b), 0.85 * s)
	b.add("SM_Env_Tree_Bush_01", p + Vector3(0, 0.5 * s, 0), _yaw(b), 0.24 * s)


static func _yaw(b: Bp) -> float:
	return b.rng.randf() * TAU


# ---------- цветы и зелень ----------

## Клумба: каменный ящик с цветами, круглый бортик из камней с цветочным ковром или высокая цветочница
static func _flowers(b: Bp, lk: int) -> void:
	match lk:
		0:
			var sx := 0.72
			var sz := 0.74
			_sx(b, "SM_Bld_Floor_Trim_02", Vector3(-1.25 * sx, 0, -0.515 * sz), 0.0, Vector3(sx, 0.5, sz))
			var xs := [-0.56, 0.0, 0.56]
			var k0 := b.rng.randi()
			for i in 3:
				_addr(b, BLOOMS[(k0 + i * 2) % BLOOMS.size()], Vector3(xs[i] + b.rng.randf_range(-0.05, 0.05), 0.17, b.rng.randf_range(-0.05, 0.05)), _yaw(b), b.rng.randf_range(0.42, 0.5), {"tint": TRUE_COLOR})
			_addr(b, "SM_Env_Garden_Plants_04", Vector3(b.pick([-0.28, 0.28]), 0.2, -0.1), _yaw(b), 0.34, {"tint": TRUE_COLOR})
			_ground_fp(b, 1.8, 0.76)
		1:
			b.add("SM_Prop_Stone_Border_01", Vector3.ZERO, _yaw(b), 0.46)
			b.add("SM_Env_Flowers_0%d" % (1 + b.rng.randi() % 5), Vector3(0, 0.02, 0), _yaw(b), 1.5)
			_addr(b, "SM_Env_Garden_Plants_04", Vector3(0, 0.03, 0), _yaw(b), 0.42, {"tint": TRUE_COLOR})
			for k in 4:
				var a := k * TAU / 4.0 + b.rng.randf_range(-0.3, 0.3)
				_bloom(b, Vector3(cos(a) * 0.38, 0.04, sin(a) * 0.38), b.rng.randf_range(0.3, 0.36))
		_:
			# высокая каменная цветочница, у края — горшочек
			b.add("SM_Prop_FlowerBed_0%d" % (1 + b.rng.randi() % 2), Vector3(0, 0.33, -0.3), 0.0, 0.75)
			b.add("SM_Prop_Vase_04", Vector3(0.95, 0, 0.12), _yaw(b), 0.5)
			_bloom(b, Vector3(0.95, 0.27, 0.12), 0.16)
			b.add("SM_Env_Grass_01", Vector3(-0.85, 0, 0.15), _yaw(b), 0.5)


## Вазон: терракотовая ваза на круглом камне, пара греческих ваз или пифос с самшитом и горшки
static func _planter(b: Bp, lk: int) -> void:
	match lk:
		0:
			_sx(b, "SM_Prop_Plinth_03", Vector3.ZERO, 0.0, Vector3(0.78, 1.0, 0.78))
			_pot(b, Vector3(0, 0.15, 0), 1.05)
			_bloom(b, Vector3(0.38, 0, 0.22), 0.18)
		1:
			var y := _yaw(b)
			b.add("SM_Prop_Vase_03", Vector3(-0.1, 0, 0), y, 0.95)
			_bloom(b, Vector3(-0.1, 0.72, 0), 0.3)
			b.add("SM_Prop_Vase_04", Vector3(0.42, 0, 0.22), y + 1.0, 0.6)
			_bloom(b, Vector3(0.42, 0.33, 0.22), 0.16)
		3:
			# награда старосты: южная пальма в мраморной кадке на ступени, у подножия — горшочки с цветами
			_slab(b, Vector3.ZERO, Vector3(0.95, 0.1, 0.95))
			_sx(b, "SM_Prop_Plinth_03", Vector3(0, 0.1, 0), 0.0, Vector3(0.62, 2.2, 0.62))
			b.add("SM_Env_Tree_Bush_02", Vector3(0, 0.42, 0), _yaw(b), 0.32)
			for px: float in [-0.36, 0.36]:
				_pot(b, Vector3(px, 0.1, 0.36), 0.5)
		_:
			_topiary(b, Vector3(-0.25, 0, -0.12), 1.0)
			b.add("SM_Prop_Vase_06", Vector3(0.3, 0, 0.0), _yaw(b), 0.75)
			_bloom(b, Vector3(0.3, 0.4, 0.0), 0.22)
			b.add("SM_Prop_Jug_0%d" % (1 + b.rng.randi() % 4), Vector3(0.02, 0, 0.32), _yaw(b), 0.8)


## Дерево: в каменном круге с цветами или раскидистое на лужайке
static func _tree(b: Bp, lk: int) -> void:
	b.add("SM_Env_Tree_01" if lk == 0 else "SM_Env_Tree_02", Vector3.ZERO, _yaw(b), 0.42)
	if lk == 0:
		b.add("SM_Prop_Stone_Border_01", Vector3.ZERO, _yaw(b), 0.34)
		_bloom(b, Vector3(0.25, 0, 0.12), 0.2)
		b.add("SM_Env_Grass_01", Vector3(-0.2, 0, -0.18), _yaw(b), 0.5)
	else:
		b.add("SM_Env_Grass_02", Vector3(0, 0, 0), _yaw(b), 0.45)
		_bloom(b, Vector3(0.45, 0, 0.3), 0.24)


## Кипарис: в траве или в каменном круге с ковром цветов
static func _cypress(b: Bp, lk: int) -> void:
	b.add("SM_Env_Tree_Thin_01" if lk == 0 else "SM_Env_Tree_Thin_02", Vector3.ZERO, _yaw(b), 0.75)
	if lk == 0:
		b.add("SM_Env_Grass_01", Vector3(0.1, 0, 0.05), _yaw(b), 0.6)
		_bloom(b, Vector3(-0.25, 0, 0.25), 0.2)
	else:
		b.add("SM_Prop_Stone_Border_01", Vector3.ZERO, _yaw(b), 0.26)
		b.add("SM_Env_Flowers_0%d" % (1 + b.rng.randi() % 5), Vector3(0, 0.02, 0), _yaw(b), 1.0)


## Пальма: с зеленью у корней или в каменном круге с цветами
static func _palm(b: Bp, lk: int) -> void:
	b.add("SM_Env_Tree_Palm_01" if lk == 0 else "SM_Env_Tree_Palm_02", Vector3.ZERO, _yaw(b), 0.43)
	if lk == 0:
		b.add("SM_Env_Garden_Plants_07", Vector3(0.45, 0, 0.3), _yaw(b), 0.3)
		b.add("SM_Env_Grass_03", Vector3(-0.35, 0, 0.2), _yaw(b), 0.6)
	else:
		b.add("SM_Prop_Stone_Border_01", Vector3.ZERO, _yaw(b), 0.4)
		_bloom(b, Vector3(0.3, 0.03, 0.2), 0.26)
		_bloom(b, Vector3(-0.28, 0.03, -0.18), 0.22)


## Куст: карликовая пальма в пифосе, цветущий куст или южный куст-веер в цветах
static func _bush(b: Bp, lk: int) -> void:
	match lk:
		0:
			_topiary(b, Vector3(0, 0, -0.05), 1.08)
			_bloom(b, Vector3(0.42, 0, 0.25), 0.22)
			b.add("SM_Env_Grass_01", Vector3(-0.4, 0, 0.25), _yaw(b), 0.5)
		1:
			# цветущий куст (как олеандр): большой куст в цветах и два поменьше
			_addr(b, "SM_Env_Garden_Plants_04", Vector3(0, 0, -0.08), _yaw(b), 0.55, {"tint": TRUE_COLOR})
			_bloom(b, Vector3(0.45, 0, 0.25), 0.3)
			_bloom(b, Vector3(-0.42, 0, 0.22), 0.26)
		_:
			b.add("SM_Env_Tree_Bush_01", Vector3(0, 0, -0.1), _yaw(b), 0.45)
			_bloom(b, Vector3(0.32, 0, 0.35), 0.3)
			_bloom(b, Vector3(-0.35, 0, 0.3), 0.26)


# ---------- скамьи и свет ----------

## Скамья: мраморная между двумя терракотовыми горшками, деревянная с вазой и корзиной или полукруглая у куста
static func _bench(b: Bp, lk: int) -> void:
	match lk:
		0:
			b.add("SM_Prop_Seat_Bench_01", Vector3.ZERO, 0.0)
			for sx: float in [-1.15, 1.15]:
				_pot(b, Vector3(sx, 0, 0.0), 0.9)
		1:
			b.add("SM_Prop_Seat_Bench_03", Vector3(0, 0, 0.04), 0.0, 0.88)
			b.add("SM_Prop_Vase_04", Vector3(1.32, 0, 0.0), _yaw(b), 0.62)
			_bloom(b, Vector3(1.32, 0.34, 0.0), 0.17)
			b.add("SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 8), Vector3(-1.3, 0, 0.08), _yaw(b), 0.7)
		_:
			b.add("SM_Prop_Seat_Bench_02", Vector3(0, 0, -0.2), 0.0, 0.9)
			b.add("SM_Env_Tree_Bush_01", Vector3(0, 0, -0.75), _yaw(b), 0.34)
			_bloom(b, Vector3(-0.98, 0, 0.28), 0.22)
			_bloom(b, Vector3(0.98, 0, 0.28), 0.22)
	b.door = Vector3(0, 0, 0.95)


## Фонарь на столбе: с корзинкой цветов на перекладине, с горшком у подножия или с цветочным кругом.
## Столб в LAMP_K раз выше родного: фонарь висит выше прохожих, макушка — у карниза одноэтажного дома (как в Town to City)
const LAMP_K := 1.2


static func _lamp_post(b: Bp, lk: int) -> void:
	var k := LAMP_K
	b.add("#lamp_post", Vector3.ZERO, 0.0, k)
	b.light(Vector3(0.42, 2.12, 0.0) * k)
	match lk:
		3:
			# награда старосты: перекладина в обе стороны, на ней два кашпо с цветами; у подножия — цветочный круг
			_sx(b, "SM_Prop_Beam_01", Vector3(-0.62, 2.25, 0.0) * k, 0.0, Vector3(0.3, 0.28, 0.28) * k)
			b.add("SM_Prop_FlowerPot_Hanging_04", Vector3(-0.5, 2.23, 0.0) * k, 0.0, 0.42 * k)
			b.add("SM_Prop_FlowerPot_Hanging_06", Vector3(-0.2, 2.23, 0.0) * k, PI, 0.38 * k)
			b.add("SM_Prop_Stone_Border_01", Vector3.ZERO, _yaw(b), 0.3)
			_bloom(b, Vector3(0.2, 0.02, 0.15), 0.2)
			_bloom(b, Vector3(-0.2, 0.02, -0.12), 0.18)
		0:
			_sx(b, "SM_Prop_Beam_01", Vector3(-0.44, 2.25, 0.0) * k, 0.0, Vector3(0.18, 0.28, 0.28) * k)
			b.add("SM_Prop_FlowerPot_Hanging_0%d" % (4 + b.rng.randi() % 3), Vector3(-0.36, 2.23, -0.0) * k, 0.0, 0.42 * k)
			b.add("SM_Env_Grass_01", Vector3(0.05, 0, 0.12), _yaw(b), 0.45)
			_bloom(b, Vector3(-0.18, 0, 0.1), 0.17)
		1:
			_pot(b, Vector3(-0.42, 0, 0.12), 0.75)
			b.add("SM_Env_Grass_01", Vector3(0.12, 0, 0.18), _yaw(b), 0.4)
		_:
			b.add("SM_Env_Flowers_0%d" % (1 + b.rng.randi() % 5), Vector3(0, 0.01, 0), _yaw(b), 1.2)
			_bloom(b, Vector3(0.2, 0, 0.16), 0.17)
			_bloom(b, Vector3(-0.2, 0, -0.14), 0.15)


## Светильник: высокий бронзовый канделябр на мраморном круге или огненная чаша на высокой мраморной подставке
static func _candelabrum(b: Bp, lk: int) -> void:
	if lk == 0:
		b.add("SM_Prop_Plinth_03", Vector3.ZERO, 0.0, 1.0)
		b.add("SM_Prop_Senser_01", Vector3(0, 0.15, 0), 0.0, 1.15)
		_fire(b, Vector3(0, 2.0, 0), 0.05, 3, 0.07, 0.05)
		b.light(Vector3(0, 2.2, 0))
	else:
		# стройная мраморная колонна на круглом камне, наверху огненная чаша (не путать с жаровней на тумбе)
		var y0 := 0.12
		b.add("SM_Prop_Plinth_03", Vector3.ZERO, 0.0, 0.8)
		_sx(b, "SM_Bld_Pillar_02", Vector3(0, y0, 0), 0.0, Vector3(0.3, 0.45, 0.3))
		var h := y0 + 3.0 * 0.45
		b.add("SM_Prop_Brazier_04", Vector3(0, h, 0), 0.0, 0.42)
		b.add("SM_Prop_Brazier_04_Insert_01", Vector3(0, h, 0), 0.0, 0.42)
		_fire(b, Vector3(0, h + 0.2, 0), 0.085, 4, 0.08, 0.055)
		b.light(Vector3(0, h + 0.38, 0))


# ---------- на стене ----------

## Факел на стене: тёмное древко в кольце, за ним — золотая бляха или львиная маска; огонь — язычок из кубиков
static func _wall_torch(b: Bp, lk: int) -> void:
	if lk == 0:
		b.add("SM_Bld_Ornament_09", Vector3(0, 0.02, 0.0), 0.0, 1.1)
		b.add("SM_Prop_Bracket_01", Vector3(0, -0.12, 0.0), 0.0, 2.2)
	else:
		b.add("SM_Prop_Marble_LionHead_01", Vector3(0, 0.12, 0.0), 0.0, 0.42)
		b.add("SM_Prop_Bracket_01", Vector3(0, -0.16, 0.0), 0.0, 2.2)
	var tilt := 0.32
	b.parts.append(["SM_Prop_Torch_02", b.base * Transform3D(Basis(Vector3.RIGHT, tilt).scaled(Vector3.ONE * 1.35), Vector3(0, 0.1, 0.22)), {"tint": BRONZE}])
	var up := Vector3(0, cos(tilt), sin(tilt))
	_flame(b, Vector3(0, 0.1, 0.22) + up * 0.42, 0.1, up)
	b.light(Vector3(0, 0.62, 0.36))


## Фонарь на стене: фонарь со стеклом на кронштейне или римский бронзовый светильник на цепочке
static func _wall_lamp(b: Bp, lk: int) -> void:
	if lk == 0:
		b.add("#wall_lamp", Vector3.ZERO, 0.0)
		b.light(Vector3(0, -0.2, 0.4))
	else:
		for bx: float in [-0.05, 0.05]:
			b.add("SM_Prop_Bracket_01", Vector3(bx, 0.12, 0.0), 0.0, 2.0)
		b.add("SM_Prop_Senser_03", Vector3(0, 0.2 - 1.25 * 0.55, 0.34), 0.0, 0.55)
		b.light(Vector3(0, -0.45, 0.4))


## Цветы на стене: ящик с цветами под окном, подвесное кашпо или два кашпо
static func _wall_flowers(b: Bp, lk: int) -> void:
	match lk:
		0:
			# каменный ящик с цветами, как под окнами в Town to City (низ окна первого этажа)
			# верх ящика ~0,83 м над землёй (под подоконником), снизу — два кронштейна
			b.add("SM_Prop_FlowerBed_0%d" % (1 + b.rng.randi() % 2), Vector3(0, -0.42, 0.04), 0.0, 0.6)
			for bx: float in [-0.3, 0.3]:
				b.add("SM_Prop_Bracket_01", Vector3(bx, -0.775, 0.0), 0.0, 1.5)
		1:
			b.add("SM_Prop_FlowerPot_Hanging_0%d" % (4 + b.rng.randi() % 3), Vector3(0, 0.3, 0.1), 0.0, 0.85)
		_:
			b.add("SM_Prop_FlowerPot_Hanging_0%d" % (4 + b.rng.randi() % 3), Vector3(-0.3, 0.3, 0.1), 0.0, 0.62)
			b.add("SM_Prop_FlowerPot_Hanging_0%d" % (4 + b.rng.randi() % 3), Vector3(0.3, 0.42, 0.1), 0.0, 0.62)


## Знамя на стене: полотнище на перекладине, другое по форме или два узких полотнища рядом
## Рисунок на полотнищах у каждого облика свой и постоянный (буква модели Synty — какой рисунок)
static func _wall_banner(b: Bp, lk: int) -> void:
	match lk:
		0:
			b.add("SM_Prop_Banner_01_E", Vector3(0, 0.5, 0.03), 0.0)
		1:
			b.add("SM_Prop_Banner_02_D", Vector3(0, 0.5, 0.03), 0.0)
		_:
			b.add("SM_Prop_Banner_02_C", Vector3(-0.42, 0.45, 0.03), 0.0, 0.72)
			b.add("SM_Prop_Banner_02_H", Vector3(0.42, 0.45, 0.03), 0.0, 0.72)


# ---------- двор и хозяйство ----------

## Плетень: чистый жердяной забор (ставится рядами), калитка между каменными столбиками с вазами
## или низкая оштукатуренная садовая стенка в цвет дома с вазонами (как в Помпеях)
static func _fence(b: Bp, lk: int, gate := 0) -> void:
	if gate == 1 and lk != 1:
		_fence_gate(b, lk)
		return
	match lk:
		0:
			b.add("SM_Env_Fence_Woof_0%d" % (1 + b.rng.randi() % 3), Vector3(-1.25, 0, 0), 0.0)
			b.add("SM_Env_Grass_03", Vector3(-0.55, 0, 0.14), 0.0, 0.6)
			b.add("SM_Env_Grass_01", Vector3(0.7, 0, 0.12), _yaw(b), 0.45)
		1:
			_sx(b, "SM_Env_Fence_Woof_Gate_01", Vector3(-1.08, 0, 0), 0.0, Vector3(0.86, 1.0, 1.0))
			for px: float in [-1.3, 1.3]:
				b.add("SM_Prop_Plinth_02", Vector3(px, 0, 0), 0.0, 0.9)
				b.add("SM_Prop_Vase_04", Vector3(px, 0.91, 0), _yaw(b), 0.5)
				_bloom(b, Vector3(px, 0.91 + 0.26, 0), 0.15)
		_:
			b.add("SM_Bld_Wall_Balcony_05", Vector3(-1.25, 0, 0.12), 0.0, 1.0, true)
			b.add("SM_Env_Ivy_Draped_Flowers_02", Vector3(b.pick([-0.3, 0.35]), 1.0, 0.3), 0.0, 0.55)
			for px: float in [-0.8, 0.8]:
				b.add("SM_Prop_Vase_04", Vector3(px, 1.02, 0.0), _yaw(b), 0.5)
				_bloom(b, Vector3(px, 1.02 + 0.26, 0.0), 0.15)
			_ground_fp(b, 2.5, 0.45)


## Калитка в заборе, протянутом мышью (variant 1): в плетне — плетёная калитка, в садовой стенке — калитка
## между каменными столбиками с вазами (как карточка «Калитка»). Длина та же, что у звена
static func _fence_gate(b: Bp, lk: int) -> void:
	if lk == 0:
		b.add("SM_Env_Fence_Woof_Gate_01", Vector3(-1.25, 0, 0), 0.0)
		b.add("SM_Env_Grass_03", Vector3(-1.05, 0, 0.16), 0.0, 0.55)
		b.add("SM_Env_Grass_01", Vector3(1.0, 0, 0.14), _yaw(b), 0.45)
		return
	_sx(b, "SM_Env_Fence_Woof_Gate_01", Vector3(-1.08, 0, 0), 0.0, Vector3(0.86, 1.0, 1.0))
	for px: float in [-1.3, 1.3]:
		b.add("SM_Prop_Plinth_02", Vector3(px, 0, 0), 0.0, 0.9)
		b.add("SM_Prop_Vase_04", Vector3(px, 0.91, 0), _yaw(b), 0.5)
		_bloom(b, Vector3(px, 0.91 + 0.26, 0), 0.15)


## Ограда: две деревянные жерди между каменными столбиками (на углу столбики двух звеньев совпадают)
## или дощатая калитка между столбиками
static func _fence_wood(b: Bp, gate: int) -> void:
	for px: float in [-1.25, 1.25]:
		b.add("SM_Prop_Plinth_02", Vector3(px, 0, 0), 0.0, 0.9)
	if gate == 1:
		_sx(b, "SM_Env_Fence_Wood_Gate_01", Vector3(-1.08, 0, 0), 0.0, Vector3(0.86, 0.8, 1.0))
	else:
		for ry: float in [0.42, 0.76]:
			_sx(b, "SM_Prop_Beam_01", Vector3(-1.25, ry, 0), 0.0, Vector3(1.0, 0.7, 0.45))
	b.add("SM_Env_Grass_02", Vector3(b.rng.randf_range(-0.9, 0.9), 0, 0.15), _yaw(b), 0.5)


## Живая изгородь: кусты, подстриженные в ровный зелёный ряд, в нём редкие цветы; калитка — дощатая между двумя
## короткими кусками изгороди. Концы звена чуть заходят за его длину — на углу изгородь сходится без щели
static func _hedge(b: Bp, gate: int) -> void:
	var green := {"tint": HEDGE}
	if gate == 1:
		for px: float in [-1.05, -0.75, 0.75, 1.05]:
			_sx(b, "SM_Env_Bush_Cluster_0%d" % (1 + b.rng.randi() % 3), Vector3(px, 0.3, 0), b.rng.randf() * PI, Vector3(0.05, 0.15, 0.075), green)
		_sx(b, "SM_Env_Fence_Wood_Gate_01", Vector3(-0.62, 0, 0), 0.0, Vector3(0.5, 0.85, 1.0))
		return
	for k in 5:
		_sx(b, "SM_Env_Bush_Cluster_0%d" % (1 + (k + b.rng.randi()) % 3), Vector3(-1.0 + k * 0.5, 0.3, 0), b.rng.randf() * PI, Vector3(0.08, 0.15, 0.075), green)
	if b.chance(0.6):
		_bloom(b, Vector3(b.rng.randf_range(-0.8, 0.8), 0.66, 0.24), 0.17)


## Каменная стенка: низкая кладка из серого камня под мраморными плитами, на концах — каменные столбики
## (на углу столбики двух звеньев совпадают); калитка — дощатая между столбиками
static func _stonewall(b: Bp, gate: int) -> void:
	if gate == 1:
		_sx(b, "SM_Env_Fence_Wood_Gate_01", Vector3(-1.08, 0, 0), 0.0, Vector3(0.86, 0.85, 1.0))
	else:
		b.parts.append(["SM_Bld_Wall_01", b.base * Transform3D(Basis.from_scale(Vector3(1.0, 0.28, 1.6)), Vector3(-1.25, 0, 0)), {"Stucco_White_01": "Brick_Grey_Tex"}])
		b.parts.append(["SM_Bld_Wall_Tiny_01", b.base * Transform3D(Basis.from_scale(Vector3(1.0, 0.5, 2.0)), Vector3(-1.25, 0.84, 0)), {"Stucco_White_01": "Building_Marble_01"}])
		if b.chance(0.35):
			b.add("SM_Env_Grass_03", Vector3(b.rng.randf_range(-0.9, 0.9), 0, 0.3), _yaw(b), 0.5)
	for px: float in [-1.25, 1.25]:
		b.add("SM_Prop_Plinth_02", Vector3(px, 0, 0), 0.0, 1.05)


## Стог сена: копна, прислонённый сноп, мешок и коса; или большая копна с корзиной и мешками
static func _hay(b: Bp, lk: int) -> void:
	if lk == 0:
		b.add("SM_Prop_Straw_Stack_01", Vector3(-0.15, 0, -0.1), _yaw(b), 0.58)
		_lean(b, "SM_Prop_Straw_Bundle_01", Vector3(0.62, 0, 0.18), _yaw(b), 0.18, 0.55)
		b.add("SM_Prop_Sack_0%d" % (3 + b.rng.randi() % 3), Vector3(0.5, 0, -0.45), _yaw(b), 0.75)
		# коса прислонена к копне лезвием вверх (у модели начало координат посередине)
		var tilt := -0.22
		b.add_xf("SM_Prop_Scythe_01", Transform3D(Basis(Vector3.UP, 0.5) * Basis(Vector3.RIGHT, tilt) * Basis.from_scale(Vector3.ONE * 0.8), Vector3(-0.72, 0.72 * 0.8 * cos(tilt), 0.42)))
	else:
		b.add("SM_Prop_Straw_Stack_02", Vector3(0, 0, -0.15), _yaw(b), 0.48)
		b.add("SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 8), Vector3(0.62, 0, 0.42), _yaw(b), 0.7)
		b.add("SM_Prop_Sack_0%d" % (3 + b.rng.randi() % 3), Vector3(-0.6, 0, 0.45), _yaw(b), 0.75)
		_lean(b, "SM_Prop_Straw_Bundle_01", Vector3(-0.72, 0, -0.1), _yaw(b), -0.16, 0.5)


static func _amphorae(b: Bp, lk: int) -> void:
	match lk:
		0:
			b.add("SM_Prop_Vase_Pile_02", Vector3(-0.15, 0, 0), _yaw(b), 0.72)
			b.add("SM_Prop_Vase_02", Vector3(0.62, 0, 0.3), _yaw(b), 0.85)
			b.add("SM_Prop_Jug_0%d" % (1 + b.rng.randi() % 6), Vector3(0.3, 0, 0.55), _yaw(b), 0.8)
		1:
			b.add("SM_Prop_Jar_Pile_01", Vector3(-0.1, 0, -0.05), _yaw(b), 0.85)
			b.add("SM_Prop_Vase_01", Vector3(0.62, 0, 0.25), _yaw(b), 0.8)
			b.add("SM_Prop_Sack_0%d" % (3 + b.rng.randi() % 3), Vector3(-0.6, 0, 0.45), _yaw(b), 0.7)
		_:
			b.add("SM_Prop_Vase_Pile_04", Vector3(0, 0, -0.05), _yaw(b), 0.6)
			b.add("SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 8), Vector3(0.55, 0, 0.5), _yaw(b), 0.7)


static func _goods(b: Bp, lk: int) -> void:
	match lk:
		0:
			b.add("SM_Prop_Basket_Set_01", Vector3(0, 0, -0.1), 0.0, 0.72)
			b.add("SM_Prop_Basket_Set_01_Insert_01", Vector3(0, 0, -0.1), 0.0, 0.72)
			b.add("SM_Prop_Sack_0%d" % (3 + b.rng.randi() % 3), Vector3(0.75, 0, 0.35), _yaw(b), 0.75)
			b.add("SM_Prop_Jug_0%d" % (1 + b.rng.randi() % 6), Vector3(-0.6, 0, 0.45), _yaw(b), 0.8)
		1:
			b.add("SM_Prop_Basket_Set_06", Vector3(-0.1, 0, 0), 0.0, 0.85)
			b.add("SM_Prop_Basket_Set_06_Insert_01", Vector3(-0.1, 0, 0), 0.0, 0.85)
			b.add("SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 8), Vector3(0.62, 0, 0.3), _yaw(b), 0.75)
			b.add("SM_Prop_Vase_04", Vector3(-0.65, 0, 0.35), _yaw(b), 0.7)
		_:
			b.add("SM_Prop_Sack_Stack_01", Vector3(0, 0, -0.15), 0.0, 0.72)
			b.add("SM_Prop_Basket_Set_04", Vector3(0.1, 0, 0.45), 0.3, 0.55)
			b.add("SM_Prop_Basket_Set_04_Insert_01", Vector3(0.1, 0, 0.45), 0.3, 0.55)
			b.add("SM_Prop_Jar_01", Vector3(-0.7, 0, 0.35), _yaw(b), 0.75)


## Колодец: каменный сруб с воротом под черепичной крышей, под дощатым навесом или открытый; кувшины и корзина
static func _well(b: Bp, lk: int) -> void:
	var s := 0.62
	b.add("SM_Prop_Well_01", Vector3(0.08, 0, 0.0), 0.0, s)
	if lk < 2:
		var h := 2.02
		for px: float in [-1.08, 1.08]:
			_sx(b, "SM_Bld_Trellis_Pillar_01", Vector3(px, 0, -0.05), 0.0, Vector3(0.55, 0.64, 0.55))
		if lk == 0:
			# черепичная двускатная крыша с закрытыми торцами и антефиксами, как у колодцев Town to City
			var sy := 0.8
			var sz := 0.36
			var xf := func(pos: Vector3, yaw: float) -> Transform3D:
				return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(0.98, sy, sz)), pos)
			var hw := 1.225
			var hd := 2.5 * sz
			var z0 := -0.05
			# черепица всегда терракотовая, торцы — в цвет штукатурки
			var rm: Dictionary = b.remap.duplicate(true)
			rm.erase("Roof_Tile_01")
			b.parts.append(["SM_Bld_Roof_Base_Straight_01", b.base * xf.call(Vector3(-hw, h, z0 + hd), 0.0), rm])
			b.parts.append(["SM_Bld_Roof_Base_Straight_01", b.base * xf.call(Vector3(hw, h, z0 - hd), PI), rm])
			for c: Array in [[Vector3(-hw, h, z0 + hd), 0.0], [Vector3(hw, h, z0 - hd), PI], [Vector3(hw, h, z0 + hd), 0.0], [Vector3(-hw, h, z0 - hd), PI]]:
				b.parts.append(["SM_Bld_Roof_Base_Straight_Side_01", b.base * xf.call(c[0], c[1]), rm])
			var ridge := h + 0.75 * sy
			for px: float in [-hw + 0.08, hw - 0.08]:
				b.add("SM_Bld_Roof_Topper_03", Vector3(px, ridge - 0.02, z0), PI / 2, 0.6)
		else:
			# дощатый навес из двух скатов, конёк — брус
			_sx(b, "SM_Prop_Overhang_01", Vector3(0, h, -0.06), 0.0, Vector3(0.96, 1.0, 1.3))
			_sx(b, "SM_Prop_Overhang_01", Vector3(0, h, -0.04), PI, Vector3(0.96, 1.0, 1.3))
			_sx(b, "SM_Prop_Beam_01", Vector3(-1.28, h + 0.08, -0.05), 0.0, Vector3(1.02, 0.75, 0.75))
	b.add("SM_Prop_Jug_0%d" % (1 + b.rng.randi() % 4), Vector3(0.95, 0, 0.62), _yaw(b), 0.9)
	b.add("SM_Prop_Vase_02", Vector3(-1.0, 0, 0.55), _yaw(b), 0.7)
	b.add("SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 8), Vector3(-0.55, 0, 0.9), _yaw(b), 0.6)
	b.door = Vector3(0, 0, 1.5)


## Телега с товаром стоит вдоль улицы (оглоблями влево или вправо), рядом мешки или амфоры
static func _cart(b: Bp, lk: int) -> void:
	var s := 0.82
	var yaw := -PI / 2 if lk == 0 else PI / 2
	var c := Basis(Vector3.UP, yaw) * Vector3(0, 0, -0.69 * s)
	b.add("SM_Prop_Cart_01", c, yaw, s)
	b.add("SM_Prop_Cart_01_Insert_0%d" % (1 + b.rng.randi() % 3), c, yaw, s)
	if lk == 0:
		b.add("SM_Prop_Sack_Stack_02" if b.chance(0.5) else "SM_Prop_Sack_Stack_01", Vector3(0.35, 0, 0.95), 0.1, 0.55)
		b.add("SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 8), Vector3(-0.55, 0, 1.0), _yaw(b), 0.65)
	else:
		b.add("SM_Prop_Vase_02", Vector3(-0.5, 0, 1.12), _yaw(b), 0.8)
		b.add("SM_Prop_Vase_01", Vector3(-0.1, 0, 1.18), _yaw(b), 0.75)
		b.add("SM_Prop_Sack_0%d" % (3 + b.rng.randi() % 3), Vector3(0.45, 0, 1.1), _yaw(b), 0.7)
	b.door = Vector3(0, 0, 1.6)


## Трофей Легиона «Телега атамана» (все 30 звёзд «Леса разбойников»): телега шайки на мраморной плите, в ней добыча,
## к колесу прислонены щиты разбойников, рядом стойка с их копьями и знамя атамана на шесте
static func _trophy_cart(b: Bp) -> void:
	_slab(b, Vector3(0, 0, -0.1), Vector3(3.3, 0.12, 2.1))
	var s := 0.82
	var yaw := -PI / 2
	var c := Basis(Vector3.UP, yaw) * Vector3(0, 0, -0.69 * s) + Vector3(0.15, 0.12, -0.25)
	b.add("SM_Prop_Cart_01", c, yaw, s)
	# в телеге — добыча шайки: мешки и кувшины
	b.add("SM_Prop_Sack_Stack_02", c + Vector3(0.05, 0.6, 0.0), 0.2, 0.78)
	b.add("SM_Prop_Jar_Pile_01", Vector3(-0.85, 0.12, -0.75), 0.6, 0.7)
	CatMilitary._lean_shield(b, Vector3(-0.35, 0.12, 0.62), 0.15, "SM_Wep_Shield_01", 0.32, 0.62)
	CatMilitary._lean_shield(b, Vector3(0.45, 0.12, 0.66), -0.2, "SM_Wep_Shield_03", 0.3, 0.6)
	CatMilitary._rack(b, Vector3(1.25, 0.12, -0.55), -PI / 2, 1, 0.5)
	# знамя атамана: шест, перекладина, красное полотнище, наверху — золотое навершие
	_sx(b, "SM_Prop_Pole_02", Vector3(-1.35, 0.12, -0.45), 0.0, Vector3(0.9, 0.95, 0.9))
	_sx(b, "SM_Prop_Beam_01", Vector3(-1.85, 2.66, -0.38), 0.0, Vector3(0.42, 0.55, 0.55))
	b.add("SM_Prop_Banner_01_C", Vector3(-1.35, 2.62, -0.47), 0.0, 0.85)
	b.add("SM_Bld_Ornament_09", Vector3(-1.35, 3.12, -0.45), 0.0, 0.9)
	b.add("SM_Prop_Sack_Stack_01", Vector3(1.15, 0.12, 0.55), 0.3, 0.5)
	b.door = Vector3(0, 0, 1.4)


# ---------- огонь, знамёна ----------

## Жаровня: железный треножник на каменном круге или огненная чаша на мраморной базе; дымок
static func _brazier(b: Bp, lk: int) -> void:
	if lk == 0:
		b.add("SM_Prop_Plinth_03", Vector3.ZERO, 0.0, 0.9)
		b.add("SM_Prop_Brazier_03", Vector3(0, 0.13, 0), 0.0)
		b.add("SM_Prop_Brazier_03_Insert_01", Vector3(0, 0.13, 0), 0.0)
		_fire(b, Vector3(0, 0.99, 0), 0.09, 5, 0.1, 0.06)
		b.light(Vector3(0, 1.15, 0))
		b.smoke.append(Vector3(0, 1.15, 0))
	else:
		b.add("SM_Prop_Pillar_Base_01", Vector3.ZERO, 0.0, 0.8)
		b.add("SM_Prop_Brazier_04", Vector3(0, 0.8, 0), 0.0, 0.6)
		b.add("SM_Prop_Brazier_04_Insert_01", Vector3(0, 0.8, 0), 0.0, 0.6)
		_fire(b, Vector3(0, 1.09, 0), 0.13, 5, 0.1, 0.065)
		b.light(Vector3(0, 1.25, 0))
		b.smoke.append(Vector3(0, 1.2, 0))


## Большая жаровня: бронзовая чаша на ножке или широкая низкая чаша на мраморной плите; дымок
static func _bigbrazier(b: Bp, lk: int) -> void:
	_slab(b, Vector3.ZERO, Vector3(1.55, 0.12, 1.55))
	if lk == 0:
		b.add("SM_Prop_Brazier_01", Vector3(0, 0.12, 0), 0.0, 0.75)
		b.add("SM_Prop_Brazier_01_Insert_01", Vector3(0, 0.12, 0), 0.0, 0.75)
		_fire(b, Vector3(0, 1.56, 0), 0.3, 7, 0.14, 0.08)
		b.light(Vector3(0, 1.75, 0))
		b.smoke.append(Vector3(0, 1.8, 0))
	else:
		b.add("SM_Prop_Brazier_02", Vector3(0, 0.12, 0), 0.0, 0.62)
		b.add("SM_Prop_Brazier_02_Insert_01", Vector3(0, 0.12, 0), 0.0, 0.62)
		_fire(b, Vector3(0, 0.98, 0), 0.32, 7, 0.14, 0.08)
		b.light(Vector3(0, 1.2, 0))
		b.smoke.append(Vector3(0, 1.25, 0))


## Знамя на шесте: римский значок — полотнище на перекладине, золотые бляхи на древке;
## или на мраморном постаменте с полотнищем другой формы
static func _banner(b: Bp, lk: int) -> void:
	if lk == 2:
		# награда старосты: пурпурное полотнище на высоком шесте, бляхи и навершие в золоте, у подножия — вазоны
		_slab(b, Vector3.ZERO, Vector3(1.1, 0.12, 1.1))
		b.add("SM_Prop_Plinth_03", Vector3(0, 0.12, 0), 0.0, 0.75)
		_sx(b, "SM_Prop_Pole_02", Vector3(0, 0.22, 0), 0.0, Vector3(1.0, 1.25, 1.0))
		_sx(b, "SM_Prop_Beam_01", Vector3(-0.62, 3.5, 0.08), 0.0, Vector3(0.5, 0.6, 0.6))
		b.add("SM_Prop_Banner_03_B", Vector3(0, 3.45, -0.02), 0.0)
		for k in 3:
			b.parts.append(["SM_Bld_Ornament_07", b.base * Transform3D(Basis.from_scale(Vector3.ONE * 0.36), Vector3(0, 1.5 - k * 0.32, 0.11)), {"tint": GILT}])
		b.parts.append(["SM_Bld_Ornament_09", b.base * Transform3D(Basis.from_scale(Vector3.ONE * 1.1), Vector3(0, 4.0, 0.0)), {"tint": GILT}])
		for px: float in [-0.42, 0.42]:
			_pot(b, Vector3(px, 0.12, 0.42), 0.55)
		return
	if lk == 0:
		b.add("SM_Prop_Plinth_03", Vector3.ZERO, 0.0, 0.75)
		_sx(b, "SM_Prop_Pole_02", Vector3(0, 0.1, 0), 0.0, Vector3(1.0, 1.15, 1.0))
		_sx(b, "SM_Prop_Beam_01", Vector3(-0.56, 3.1, 0.08), 0.0, Vector3(0.45, 0.6, 0.6))
		b.add("SM_Prop_Banner_01_B", Vector3(0, 3.05, -0.02), 0.0)
		for k in 2:
			b.add("SM_Bld_Ornament_0%d" % b.pick([1, 4, 7]), Vector3(0, 1.28 - k * 0.42, 0.11), 0.0, 0.42)
		b.add("SM_Bld_Ornament_09", Vector3(0, 3.62, 0.0), 0.0, 1.0)
	else:
		b.add("SM_Prop_Plinth_04", Vector3.ZERO, 0.0, 0.8)
		var py := 0.68 * 0.8
		_sx(b, "SM_Prop_Pole_02", Vector3(0, py, 0), 0.0, Vector3(1.0, 1.0, 1.0))
		_sx(b, "SM_Prop_Beam_01", Vector3(-0.62, py + 2.62, 0.08), 0.0, Vector3(0.5, 0.6, 0.6))
		b.add("SM_Prop_Banner_02_F", Vector3(0, py + 2.58, 0.06), 0.0)
		for k in 3:
			b.add("SM_Bld_Ornament_07", Vector3(0, py + 0.95 - k * 0.3, 0.11), 0.0, 0.34)
		b.add("SM_Bld_Ornament_09", Vector3(0, py + 3.12, 0.0), 0.0, 1.0)


# ---------- живность ----------

## Лужок для пары овец (самих овец добавляет игра, они бродят в пределах ±0,8 м):
## загон с плетнём и корытцем или открытый луг с копёшкой в углу
static func _sheep(b: Bp, lk: int) -> void:
	b.add("SM_Env_Grass_02", Vector3(0.3, 0, -0.2), 0.0, 0.6)
	b.add("SM_Env_Grass_01", Vector3(-0.65, 0, 0.5), _yaw(b), 0.8)
	b.add("SM_Env_Flowers_0%d" % (1 + b.rng.randi() % 5), Vector3(-0.3, 0, 0.1), _yaw(b), 1.3)
	if lk == 0:
		b.add("SM_Env_Fence_Woof_0%d" % (1 + b.rng.randi() % 3), Vector3(-1.03, 0, -1.05), 0.0, 0.8)
		_sx(b, "SM_Bld_Floor_Trim_02", Vector3(0.95 - 0.155, 0, 0.375), PI / 2, Vector3(0.3, 0.55, 0.3))
		b.parts.append(["#water", b.base * Transform3D(Basis.from_scale(Vector3(0.18, 0.04, 0.62)), Vector3(0.95, 0.22, 0)), {}])
		b.add("SM_Env_Grass_03", Vector3(0.75, 0, 0.75), _yaw(b), 0.6)
	else:
		b.add("SM_Env_Grass_03", Vector3(0.7, 0, 0.65), _yaw(b), 0.7)
		b.add("SM_Prop_Straw_Stack_01", Vector3(-1.0, 0, -1.0), _yaw(b), 0.3)
	_ground_fp(b, 2.0, 2.0)


## Награда истории «Где Мурка?»: широкая плоская корзинка с подушкой, рядом миска и свёрнутое покрывальце.
## Саму кошку (спит в корзинке) ставит game._show — CATBED_AT: где у неё середина (в осях украшения, без масштаба)
const CATBED_AT := Vector3(-0.08, 0.13, 0.02)


static func _catbasket(b: Bp) -> void:
	b.add("SM_Env_Grass_01", Vector3(-0.75, 0, -0.45), _yaw(b), 0.6)
	b.add("SM_Prop_Basket_11", Vector3(-0.08, 0, 0.02), 0.3, 1.0)
	b.add("SM_Prop_Pillow_06", Vector3(-0.08, 0.07, 0.02), 0.5, 0.8)
	b.add("SM_Prop_Bowl_04", Vector3(0.7, 0, 0.45), 0.0, 0.85)
	b.add("SM_Prop_Rug_Folded_01", Vector3(0.5, 0, -0.42), 0.4, 0.62)
	b.add("SM_Env_Flowers_0%d" % (1 + b.rng.randi() % 5), Vector3(-0.72, 0, 0.55), _yaw(b), 1.1)
	b.door = Vector3(0, 0, 1.0)


## Стол для латрункулов (награда «Скверика для стариков»): низкий столик с доской и фишками, два табурета друг против
## друга, кувшин и чаши. Где сидят игроки (StoryLife): [ступни, поворот, высота сиденья] в осях украшения, без масштаба
const LATRUNC_SEATS := [[Vector3(-0.35, 0, 0.0), PI / 2, 0.42], [Vector3(0.35, 0, 0.0), -PI / 2, 0.42]]


static func _latrunc(b: Bp) -> void:
	b.add("SM_Prop_Table_07", Vector3.ZERO, 0.0, 1.0)
	var top := 0.552
	b.parts.append(["#dark", b.base * Transform3D(Basis.from_scale(Vector3(0.5, 0.025, 0.5)), Vector3(0, top + 0.012, 0)), {}])
	b.parts.append(["#marble", b.base * Transform3D(Basis.from_scale(Vector3(0.42, 0.012, 0.42)), Vector3(0, top + 0.03, 0)), {}])
	# фишки: свои плоские, у соперника высокие — посреди партии
	for f: Vector3 in [Vector3(-0.14, 0, -0.1), Vector3(-0.14, 0, 0.06), Vector3(-0.04, 0, 0.13), Vector3(0.02, 0, -0.04)]:
		b.parts.append(["#dark", b.base * Transform3D(Basis(Vector3.UP, 0.3).scaled(Vector3(0.055, 0.022, 0.055)), f + Vector3(0, top + 0.047, 0)), {}])
	for f: Vector3 in [Vector3(0.14, 0, 0.1), Vector3(0.12, 0, -0.12), Vector3(0.06, 0, 0.02)]:
		b.parts.append(["#dark", b.base * Transform3D(Basis.from_scale(Vector3(0.04, 0.06, 0.04)), f + Vector3(0, top + 0.066, 0)), {}])
	for s: Array in LATRUNC_SEATS:
		var p: Vector3 = s[0]
		b.add("SM_Prop_Seat_Stool_02", Vector3(signf(p.x) * 0.62, 0, 0), 0.0, 0.9)
	b.add("SM_Prop_Goblet_01", Vector3(-0.27, top, 0.27), 0.0, 0.55)
	b.add("SM_Prop_Goblet_01", Vector3(0.27, top, -0.26), 0.0, 0.55)
	b.add("SM_Prop_Jug_0%d" % (1 + b.rng.randi() % 4), Vector3(0.1, 0, 0.62), _yaw(b), 0.62)
	_pot(b, Vector3(-0.75, 0, -0.62), 0.75)
	b.add("SM_Env_Grass_01", Vector3(0.78, 0, -0.55), _yaw(b), 0.5)
	b.door = Vector3(0, 0, 1.0)


## Арка из роз (награда «Свадьбы Юлии»): два столба садовой решётки, перекладина в цветущих розах, по столбам вьётся
## цветущий плющ, у подножия — вазоны с цветами. Под ней свободно проходят люди
static func _rosearch(b: Bp) -> void:
	var h := 3.13 * 0.75
	for sx: float in [-1.0, 1.0]:
		b.add("SM_Bld_Trellis_Pillar_01", Vector3(sx * 0.95, 0, 0), 0.0, 0.75)
		b.add("SM_Env_Ivy_Pillar_Flowers_0%d" % (1 + b.rng.randi() % 2), Vector3(sx * 0.95, 0, 0.02), _yaw(b), 0.85)
		_pot(b, Vector3(sx * 1.5, 0, 0.42), 0.8)
		_bloom(b, Vector3(sx * 0.95, 0, 0.42), 0.24)
	b.add("SM_Bld_Trellis_Roof_End_01", Vector3(-1.25, h - 0.08, 0), PI / 2, 1.0)
	b.add("SM_Env_Ivy_Draped_Flowers_03", Vector3(0, h + 0.2, 0.06), 0.0, 0.66)
	b.add("SM_Env_Ivy_Draped_Flowers_03", Vector3(0, h + 0.18, -0.06), PI, 0.62)
	_ground_fp(b, 3.6, 1.2)
	b.door = Vector3(0, 0, 1.1)


static func _duck(b: Bp) -> void:
	for k in 3:
		b.add("#duck", Vector3(cos(k * 2.1) * 0.7, 0, sin(k * 2.1) * 0.6), k * 1.7, 1.0 - k * 0.15)
	_lilies(b, Vector3(-0.9, 0, -0.5), 0.8)
	_lilies(b, Vector3(0.8, 0, 0.7), 0.6)


static func _swan(b: Bp) -> void:
	b.add("#swan", Vector3.ZERO, _yaw(b), 1.0)
	_lilies(b, Vector3(0.9, 0, -0.6), 0.7)


## Кувшинки: листья плоско лежат на воде (у модели стебли уходят вниз — сплющиваем, чтобы не просвечивали)
static func _lilies(b: Bp, p: Vector3, s: float) -> void:
	# листья у модели — на верхушках стеблей (до +0,24 м); сплющиваем и ставим так, чтобы листья легли
	# на гладь (украшение на воде стоит на 2 см ниже воды), а стебли почти исчезли
	var k := 0.18
	var bs := Basis(Vector3.UP, _yaw(b)).scaled(Vector3(s, k * s, s))
	b.parts.append(["SM_Env_Lillies_0%d" % (1 + b.rng.randi() % 2), b.base * Transform3D(bs, p + Vector3(0, 0.045 - 0.24 * k * s, 0)), {"tint": LILY}])


# ---------- камень: статуи, колонна, лев, часы, фонтанчик, беседка ----------

## Статуя на мраморной ступени: у каждого облика своя фигура — воин с копьём и щитом, полководец в плаще,
## девушка с амфорой, мудрец в тоге; чётные — на квадратном постаменте в цветах, нечётные — на круглом с вазонами
const STATUES := ["SM_Prop_Statue_01", "SM_Prop_Statue_02", "SM_Prop_Statue_04", "SM_Prop_Statue_05", "SM_Prop_Statue_06"]


static func _statue(b: Bp, lk: int) -> void:
	var st: String = STATUES[posmod(lk, STATUES.size())]
	_slab(b, Vector3.ZERO, Vector3(1.08, 0.12, 1.08))
	if lk % 2 == 0:
		b.add("SM_Prop_Plinth_04", Vector3(0, 0.12, 0), 0.0)
		b.add(st, Vector3(0, 0.8, 0), 0.0, 1.0)
		_bloom(b, Vector3(-0.68, 0, 0.62), 0.2)
		_bloom(b, Vector3(0.68, 0, 0.62), 0.2)
	else:
		b.add("SM_Prop_Pillar_Base_01", Vector3(0, 0.12, 0), 0.0, 0.85)
		b.add(st, Vector3(0, 0.97, 0), 0.0, 0.88)
		for px: float in [-0.4, 0.4]:
			b.add("SM_Prop_Vase_04", Vector3(px, 0.12, 0.38), _yaw(b), 0.36)
			_bloom(b, Vector3(px, 0.12 + 0.19, 0.38), 0.11)
	b.door = Vector3(0, 0, 1.2)


## Колонна со статуей: мраморная ступень, постамент, ионическая колонна в розах, статуя наверху
## (второй облик — награда старосты: наверху позолоченное навершие, как у знамён легиона)
static func _column(b: Bp, lk := 0) -> void:
	_slab(b, Vector3.ZERO, Vector3(1.12, 0.14, 1.12))
	b.add("SM_Prop_Plinth_04", Vector3(0, 0.14, 0), 0.0)
	var top := 0.82
	_sx(b, "SM_Bld_Pillar_02", Vector3(0, top, 0), 0.0, Vector3(0.62, 0.75, 0.62))
	_sx(b, "SM_Env_Ivy_Pillar_Flowers_01", Vector3(0, top, 0), _yaw(b), Vector3(0.66, 0.9, 0.66))
	b.add("SM_Prop_Pillar_Top_01", Vector3(0, top + 2.25, 0), 0.0, 0.62)
	if lk == 1:
		b.parts.append(["SM_Bld_Ornament_09", b.base * Transform3D(Basis.from_scale(Vector3.ONE * 2.1), Vector3(0, top + 2.25 + 0.16, 0)), {"tint": GILT}])
	else:
		b.add("SM_Prop_Statue_07", Vector3(0, top + 2.25 + 0.155, 0), 0.0, 0.62)
	_bloom(b, Vector3(0.7, 0, 0.64), 0.2)
	_bloom(b, Vector3(-0.7, 0, 0.6), 0.17)


## Золотой лев (состаренная позолота): на высоком постаменте или на мраморной плите с вазонами по углам
static func _lion(b: Bp, lk: int) -> void:
	if lk == 0:
		var s := 0.45
		b.add("SM_Prop_Plinth_05", Vector3.ZERO, 0.0, s)
		var ls := 0.43
		b.parts.append(["SM_Prop_Statue_Lion_01", b.base * Transform3D(Basis.from_scale(Vector3.ONE * ls), Vector3(-0.12 * ls, 2.59 * s, -0.27 * ls)), {"tint": GILT}])
		_bloom(b, Vector3(0.78, 0, 0.75), 0.2)
	else:
		_slab(b, Vector3.ZERO, Vector3(1.9, 0.14, 1.9))
		var s := 0.38
		b.add("SM_Prop_Plinth_05", Vector3(0, 0.14, -0.05), 0.0, s)
		var ls := 0.38
		b.parts.append(["SM_Prop_Statue_Lion_01", b.base * Transform3D(Basis.from_scale(Vector3.ONE * ls), Vector3(-0.12 * ls, 0.14 + 2.59 * s, -0.05 - 0.27 * ls)), {"tint": GILT}])
		for px: float in [-0.7, 0.7]:
			_pot(b, Vector3(px, 0.14, 0.68), 0.62)
	b.door = Vector3(0, 0, 1.5)


static func _sundial(b: Bp, lk: int) -> void:
	if lk == 2:
		# награда старосты: часы на колонне, под ними — позолоченный венец, вокруг четыре вазона
		_slab(b, Vector3.ZERO, Vector3(1.3, 0.12, 1.3))
		b.add("SM_Prop_Pillar_Base_01", Vector3(0, 0.12, 0), 0.0, 0.9)
		b.parts.append(["SM_Bld_Ornament_04", b.base * Transform3D(Basis.from_scale(Vector3.ONE * 0.55), Vector3(0, 0.78, 0.32)), {"tint": GILT}])
		b.add("SM_Prop_Sundial_02", Vector3(0, 1.02, 0.04), 0.0, 0.95)
		for k in 4:
			var a := k * TAU / 4.0 + PI / 4.0
			_pot(b, Vector3(cos(a) * 0.58, 0.12, sin(a) * 0.58), 0.48)
		return
	if lk == 0:
		_sx(b, "SM_Prop_Plinth_03", Vector3.ZERO, 0.0, Vector3(1.75, 1.0, 1.75))
		b.add("SM_Prop_Sundial_01", Vector3(0, 0.15, 0), 0.0)
	else:
		_slab(b, Vector3.ZERO, Vector3(1.0, 0.12, 1.0))
		b.add("SM_Prop_Pillar_Base_01", Vector3(0, 0.12, 0), 0.0, 0.8)
		b.add("SM_Prop_Sundial_02", Vector3(0, 0.92, 0.04), 0.0, 0.85)
	_bloom(b, Vector3(-0.78, 0, 0.6), 0.2)
	_bloom(b, Vector3(0.78, 0, 0.6), 0.2)


## Фонтанчик: уличный фонтан как в Помпеях (каменное корыто, столбик с львиной головой, струя) или настенный фонтан Synty
static func _smallfountain(b: Bp, lk: int) -> void:
	if lk == 2:
		# награда старосты «Фонтан-раковина»: низкая круглая чаша с водой, посреди — подставка, на ней золотая раковина,
		# из раковины стекает вода
		var s := 0.34
		b.add("SM_Prop_Fountain_04", Vector3.ZERO, 0.0, s)
		b.add("SM_Prop_Fountain_04_Insert_01", Vector3.ZERO, 0.0, s)
		b.add("SM_Prop_Plinth_02", Vector3(0, 0.3, 0), 0.0, 0.62)
		b.add("SM_Prop_Fountain_03", Vector3(0, 0.3 + 0.62 + 0.3, 0), 0.0, 0.9)
		b.parts.append(["#water", b.base * Transform3D(Basis.from_scale(Vector3(0.05, 0.42, 0.05)), Vector3(0, 0.82, 0.24)), {}])
		_bloom(b, Vector3(0.75, 0, 0.55), 0.2)
		b.door = Vector3(0, 0, 1.2)
		return
	if lk == 3:
		_nymph(b)
		return
	if lk == 0:
		var sx := 0.56
		var sz := 0.8
		_sx(b, "SM_Bld_Floor_Trim_02", Vector3(-1.25 * sx, 0, -0.515 * sz), 0.0, Vector3(sx, 1.0, sz))
		b.parts.append(["#water", b.base * Transform3D(Basis.from_scale(Vector3(2.5 * sx - 0.26, 0.08, 1.03 * sz - 0.24)), Vector3(0, 0.41, 0)), {}])
		var zb := -0.515 * sz - 0.2
		b.add("SM_Prop_Plinth_02", Vector3(0, 0, zb), 0.0, 1.05)
		b.add("SM_Prop_Marble_LionHead_01", Vector3(0, 0.8, zb + 0.27), 0.0, 0.42)
		b.parts.append(["#water", b.base * Transform3D(Basis.from_scale(Vector3(0.05, 0.36, 0.05)), Vector3(0, 0.6, zb + 0.4)), {}])
		b.add("SM_Prop_Jug_0%d" % (1 + b.rng.randi() % 4), Vector3(0.82, 0, 0.3), _yaw(b), 0.8)
		_ground_fp(b, 1.45, 0.85)
	else:
		var s := 0.48
		b.add("SM_Prop_Fountain_02", Vector3(0, 0, -0.95 * s), 0.0, s)
		b.add("SM_Prop_Fountain_02_Insert_01", Vector3(0, 0, -0.95 * s), 0.0, s)
		b.add("SM_Prop_Jug_0%d" % (1 + b.rng.randi() % 4), Vector3(0.95, 0, 0.35), _yaw(b), 0.8)
	b.door = Vector3(0, 0, 1.2)


## Беседка: помпейская пергола с виноградом — шесть столбиков, решётка с лозой, ложе, столик с кувшином,
## вазоны у входа. Второй облик — круглая беседка-толос с черепичным куполом
static func _pergola(b: Bp, lk: int) -> void:
	if lk == 1:
		_tholos(b)
		return
	var h := 3.13 * 0.85
	for px: float in [-1.9, 0.0, 1.9]:
		for pz: float in [-1.1, 1.1]:
			b.add("SM_Bld_Trellis_Pillar_01", Vector3(px, 0, pz), 0.0, 0.85)
	for px: float in [0.0, 2.0]:
		_sx(b, "SM_Bld_Trellis_Roof_01", Vector3(px, h - 0.05, -1.125), 0.0, Vector3(0.8, 1.0, 0.9))
	# лоза лежит на решётке ковром (модель — тонкая стенка листьев, кладём её плашмя)
	for v: Array in [[Vector3(-0.9, h + 0.16, 1.05), 0.08, 0.85], [Vector3(1.0, h + 0.16, -1.05), PI - 0.06, 0.82]]:
		b.add_xf("SM_Env_Vine_0%d" % (1 + b.rng.randi() % 3), Transform3D(Basis(Vector3.UP, v[1]) * Basis(Vector3.RIGHT, -PI / 2) * Basis.from_scale(Vector3.ONE * float(v[2])), v[0]))
	b.add("SM_Env_Ivy_Draped_Flowers_03", Vector3(0, h + 0.14, 1.12), 0.0, 1.0)
	for px: float in [-1.9, 1.9]:
		b.add("SM_Env_Ivy_Pillar_Flowers_0%d" % (1 + b.rng.randi() % 2), Vector3(px, 0, 1.1), _yaw(b), 0.85)
	b.add("SM_Prop_Seat_Kline_0%d" % (1 + b.rng.randi() % 3), Vector3(0, 0, -0.55), 0.0, 0.8)
	b.add("SM_Prop_Table_01", Vector3(0, 0, 0.35), 0.0, 0.6)
	b.add("SM_Prop_Jug_0%d" % (1 + b.rng.randi() % 4), Vector3(-0.22, 0.47, 0.35), _yaw(b), 0.55)
	b.add("SM_Prop_Bowl_04", Vector3(0.2, 0.47, 0.36), 0.0, 0.7)
	for px: float in [-2.25, 2.25]:
		_pot(b, Vector3(px, 0, 1.35), 0.85)
	_ground_fp(b, 4.9, 3.0, Vector3(0, 0, 0.1))
	b.door = Vector3(0, 0, 1.9)


## Толос: круглая беседка на ступени, купол под черепицей; внутри полукруглая скамья, колонны в розах
static func _tholos(b: Bp) -> void:
	var s := 0.8
	_addr(b, "SM_Prop_Pergola_01", Vector3(0, 0.36 * s, 0), 0.0, s, {"Stucco_Blue_01": "Roof_Tile_03"})
	# пол беседки (замер лучом вниз по сетке SM_Prop_Pergola_01) — на уровне её начала, т. е. 0,36·s: скамья
	# стоит на нём (раньше была на 0,3 м выше — висела в воздухе)
	var fy := 0.36 * s
	b.add("SM_Prop_Seat_Bench_02", Vector3(0, fy, -0.7), 0.0, 0.85)
	# сетка плюща _01 начинается на 15,3 см выше своей точки (·0,85 ≈ 0,13): опускаем — листья до пола;
	# у _03 сетка и так уходит ниже точки
	var ivy_l := "SM_Env_Ivy_Pillar_Flowers_0%d" % b.pick([1, 3])
	b.add(ivy_l, Vector3(-1.55, fy - (0.13 if ivy_l.ends_with("01") else 0.0), -0.65), _yaw(b), 0.85)
	b.add("SM_Env_Ivy_Pillar_Flowers_01", Vector3(1.55, fy - 0.13, -0.65), _yaw(b), 0.85)
	for sx: float in [-1.0, 1.0]:
		_pot(b, Vector3(sx * 0.95, 0, 2.2), 0.85)
	_bloom(b, Vector3(-2.0, 0, 1.3), 0.3)
	_bloom(b, Vector3(2.0, 0, 1.3), 0.3)
	_ground_fp(b, 4.6, 4.9, Vector3(0, 0, 0.1))    # земля под вазонами у входа тоже ровная
	b.door = Vector3(0, 0, 2.7)


# ---------- награды новых историй (этап 7): фонтан с нимфой, ослик у коновязи, балкон с бельём ----------

## «Фонтан с нимфой» (награда «Течи в водопроводе»): круглая чаша фонтана в два яруса с водой, на верхней чаше —
## мраморная нимфа льёт воду из кувшина; по краю — цветы
static func _nymph(b: Bp) -> void:
	var s := 0.48
	b.add("SM_Prop_Fountain_04", Vector3.ZERO, 0.0, s)
	b.add("SM_Prop_Fountain_04_Insert_01", Vector3.ZERO, 0.0, s)
	var top := 1.81 * s
	b.add("SM_Prop_Statue_03", Vector3(0, top - 0.04, 0), PI, 0.5)
	# струя из кувшина нимфы — в верхнюю чашу
	b.parts.append(["#water", b.base * Transform3D(Basis.from_scale(Vector3(0.05, 0.5, 0.05)), Vector3(0.12, top + 0.25, -0.2)), {}])
	for k in 4:
		var a := k * TAU / 4.0 + PI / 4.0
		_bloom(b, Vector3(cos(a) * 0.95, 0, sin(a) * 0.95), 0.22)
	b.door = Vector3(0, 0, 1.3)


## «Ослик у коновязи» (награда «Ослика возчика»): два столбика с перекладиной, корыто с водой, охапка сена, мешок.
## Самого ослика (жуёт у коновязи) ставит game._show — DONKEY_AT: где он стоит (в осях украшения, без масштаба)
const DONKEY_AT := Vector3(0.0, 0.0, 0.62)


static func _donkeypost(b: Bp) -> void:
	for px: float in [-0.95, 0.95]:
		_sx(b, "SM_Prop_Pole_01", Vector3(px, 0, -0.25), 0.0, Vector3(1.0, 0.42, 1.0))
	_sx(b, "SM_Prop_Beam_01", Vector3(-1.05, 0.95, -0.25), 0.0, Vector3(0.85, 0.5, 0.5))
	# корыто с водой у столбика (как у овец: каменный бортик, в нём вода)
	_sx(b, "SM_Bld_Floor_Trim_02", Vector3(0.55 - 0.155, 0, -0.8 + 0.375), PI / 2, Vector3(0.3, 0.55, 0.3))
	b.parts.append(["#water", b.base * Transform3D(Basis.from_scale(Vector3(0.18, 0.04, 0.62)), Vector3(0.55, 0.22, -0.8)), {}])
	b.add("SM_Prop_Straw_Stack_02", Vector3(-0.75, 0, -0.75), _yaw(b), 0.3)
	_lean(b, "SM_Prop_Straw_Bundle_01", Vector3(-1.25, 0, -0.3), _yaw(b), 0.18, 0.42)
	b.add("SM_Prop_Sack_0%d" % (3 + b.rng.randi() % 3), Vector3(1.25, 0, -0.55), _yaw(b), 0.65)
	b.add("SM_Env_Grass_01", Vector3(-0.3, 0, 0.9), _yaw(b), 0.6)
	b.add("SM_Env_Grass_03", Vector3(0.9, 0, 0.7), _yaw(b), 0.5)
	_ground_fp(b, 2.6, 2.0, Vector3(0, 0, 0.1))
	b.door = Vector3(0, 0, 1.3)


## «Балкон с бельём» (награда «Тесно у Валериев»), на стене второго этажа: деревянный балкон, на верёвке между
## столбиками сохнут туники и простыни, на перилах — ковёр, в углу — цветы в вазоне
static func _balcony(b: Bp) -> void:
	b.add("SM_Bld_Balcony_01", Vector3(0, 0, 0.11), 0.0)
	b.add("#laundry", Vector3(0, 0, 0.0), 0.0)
	b.add("SM_Prop_Rug_Drape_01", Vector3(0.45, 0.95, 1.12), PI, 0.85)
	b.add("SM_Prop_FlowerPot_Fancy_01", Vector3(-0.85, 0.02, 0.62), 0.0, 0.8)
