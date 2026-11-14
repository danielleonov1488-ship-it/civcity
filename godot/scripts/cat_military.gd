class_name CatMilitary
extends RefCounted
## Облик военных построек Легиона (Казармы, Стрельбище, Лагерь копейщиков, Мастерские баллист и катапульт, Кузница,
## Лазарет, Склад оружия). Здание растёт с уровнем (Д10, _grow): высокие значки легиона, знамёна на фасаде и жаровни,
## золотой орёл на постаменте, портик с колоннами (или легионер на колонне), золотой орёл на коньке крыши.
## Чертёж Bp строится в родных размерах Synty, Catalog.make потом уменьшает его до «кукольного» масштаба (Catalog.ARCH).
## Фасад смотрит на +Z, вход (b.door) — у переднего края участка, к дороге. Участок ~9×9 м (как у школы и склада).
## Чего нет в Synty (палатки, мишени, чучела, значок-аквила, баллиста, онагр, ядра), собрано здесь же из Kit —
## детали "#mil_*" (Parts и Bp спрашивают их через kit_mesh). Их же может брать 3D-бой: CatMilitary.kit_mesh("#mil_ballista").
## Люди при деле (b.actor): легионеры у чучел, лучники на рубеже, мастера у машин — видны днём.

const M := Bp.M
const FL := Bp.FL

const WOOD := Color("8a5a36")
const WOOD_D := Color("5e3d24")
const WOOD_L := Color("b07c4c")
const ROPE := Color("b89a68")
const BRONZE := Color("c09040")
const GOLD := Color("e0b040")
const IRON := Color("5c5c62")
const STRAW := Color("e2c374")
const STRAW_D := Color("c9a55a")
const RED := Color("b23a2a")
const RED_D := Color("8e2a20")
const CREAM := Color("efe3c4")
const LEATHER := Color("c79d6b")
const LEATHER_D := Color("a77f52")
const STONE := Color("a39d92")
const SAND := Color("d9c08e")

static var _meshes := {}


# =====================================================================
#   постройки
# =====================================================================

## tier — облик уровня здания (Legion.vis_tier: 0 — 1-й уровень, как построено): с каждым уровнем прибавляется своё (_grow)
static func make(b: Bp, type: String, tier := 0) -> void:
	match type:
		"barracks": _barracks(b)
		"range": _range(b)
		"spearcamp": _spearcamp(b)
		"ballistae": _ballistae(b)
		"catapults": _catapults(b)
		"forge": _forge(b)
		"infirmary": _infirmary(b)
		"armory": _armory(b)
		"smelter": _smelter(b)
		"sawmill": _sawmill(b)
		"tannery": _tannery(b)
		"principia": _principia(b)
		"mars": _mars(b)
	if tier > 0:
		_grow(b, type, tier)


## Плац: утоптанный песок (плоская плитка), центр снизу p, размер sx×sz
static func _sand(b: Bp, p: Vector3, sx: float, sz: float) -> void:
	b.parts.append(["#mil_sand", b.base * Transform3D(Basis.from_scale(Vector3(sx, 1.0, sz)), p + Vector3(0, 0.01, 0)), {}])


## Стойка с оружием (rack 01 — копья, 02 — мечи): ширина 2,5 м вдоль локального X, yaw — куда смотрит
static func _rack(b: Bp, p: Vector3, yaw: float, kind := 1, s := 0.8) -> void:
	b.add("SM_Prop_Weapon_Rack_0%d" % kind, p, yaw, s)
	b.add("SM_Prop_Weapon_Rack_0%d_Insert_01" % kind, p, yaw, s)


## Щит, прислонённый к чему-то: наклон назад на tilt
static func _lean_shield(b: Bp, p: Vector3, yaw: float, nm := "SM_Wep_Shield_04", tilt := 0.25, s := 0.85) -> void:
	var box := Bp.model_aabb(nm)
	b.add_xf(nm, Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -tilt) * Basis.from_scale(Vector3.ONE * s), p + Vector3(0, -box.position.y * s, 0)))


## Копьё, воткнутое в землю
static func _spear(b: Bp, p: Vector3, yaw := 0.0, tilt := 0.06) -> void:
	b.add_xf("SM_Wep_Spear_0%d" % (1 + b.rng.randi() % 3), Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt), p + Vector3(0, 1.0, 0)))


## Казармы: двухэтажный терракотовый дом под вальмовой черепицей, над дверью — красное знамя, между окнами
## наверху — щиты-скутумы; перед домом — песчаный плац с двумя чучелами и стойками копий и мечей,
## у входа — значки-аквилы. Легионеры отрабатывают удары (−2/+2, 3) лицом к чучелам, у двери — часовой
static func _barracks(b: Bp) -> void:
	b.paint(1, false)
	b.ground_style = "brick"
	b.upper_style = "plain"
	b.roof_tex = "Roof_Tile_03"
	b.remap = b.floor_remap(1)
	var cz := -2.6
	CatCivic._box(b, 0, cz, 3, 2, [
		{0: ["SM_Bld_Wall_Window_06", "SM_Bld_Wall_Door_Double_01", "SM_Bld_Wall_Window_06"], 1: ["SM_Bld_Wall_Window_06", "SM_Bld_Wall_01"],
			2: ["SM_Bld_Wall_01", "SM_Bld_Wall_Window_06", "SM_Bld_Wall_01"], 3: ["SM_Bld_Wall_01", "SM_Bld_Wall_Window_06"]},
		{0: ["SM_Bld_Wall_Window_04", "SM_Bld_Wall_01", "SM_Bld_Wall_Window_04"], 1: ["SM_Bld_Wall_Window_04", "SM_Bld_Wall_Window_04"],
			2: ["SM_Bld_Wall_Window_04", "SM_Bld_Wall_01", "SM_Bld_Wall_Window_04"], 3: ["SM_Bld_Wall_Window_04", "SM_Bld_Wall_Window_04"]}],
		{"trim": "SM_Bld_Trim_04", "plain": [2]})
	CatCivic._leaf(b, 0, cz, 3, 2, 1, "SM_Bld_Door_05", 0.1)
	b.on_wall("SM_Bld_Floor_Trim_01", 0, cz, 3, 2, 0, 1, 0.0, 0.0)
	var ridge := CatCivic._hip(b, -3.75, 3.75, cz - 2.5, cz + 2.5, 2 * FL, 1.5)
	b.add("SM_Bld_Roof_Topper_01", Vector3(-1.25, ridge, cz), 0.0)
	b.add("SM_Bld_Roof_Topper_01", Vector3(1.25, ridge, cz), 0.0)
	CatCivic._chimney(b, Vector3(2.4, 2 * FL + 0.45, cz - 1.3))
	# над дверью — красное знамя легиона, по сторонам наверху — щиты-скутумы
	b.on_wall("SM_Prop_Banner_03_%s" % b.pick(["A", "C", "E"]), 0, cz, 3, 2, 0, 1.5, 2 * FL - 0.3, 0.12)
	for i: float in [1.0, 2.0]:
		b.on_wall("SM_Wep_Shield_04", 0, cz, 3, 2, 0, i, FL + 1.45, 0.2, false, 0.75)
	b.torch_pair(0, cz, 3, 2, 1.5)
	b.on_wall("SM_Env_Ivy_Flowers_0%d" % (1 + b.rng.randi() % 9), 0, cz, 3, 2, 3, 0.4, 3.3, 0.13)
	# плац с чучелами и стойками оружия
	var fz := cz + 2.5
	_sand(b, Vector3(0, 0, fz + 1.85), 8.6, 3.5)
	add_kit(b, "#mil_dummy", Vector3(-2.0, 0, fz + 2.0), 0.15)
	add_kit(b, "#mil_dummy", Vector3(2.0, 0, fz + 2.0), -0.2)
	_rack(b, Vector3(-4.0, 0, fz + 1.8), PI / 2, 1)
	_rack(b, Vector3(4.0, 0, fz + 1.8), -PI / 2, 2)
	add_kit(b, "#mil_standard", Vector3(-1.05, 0, fz + 0.55), 0.0)
	add_kit(b, "#mil_standard", Vector3(1.05, 0, fz + 0.55), 0.0)
	_lean_shield(b, Vector3(-3.1, 0, fz + 0.3), 0.3)
	_lean_shield(b, Vector3(3.15, 0, fz + 0.3), -0.25, "SM_Wep_Shield_0%d" % (1 + b.rng.randi() % 3), 0.3, 0.7)
	b.add("SM_Prop_Seat_Bench_01", Vector3(-2.6, 0, fz + 0.35), 0.0, 0.9)
	CatCivic._jar(b, Vector3(3.6, 0, fz + 3.3))
	b.actor(Vector3(-2.0, 0, fz + 3.05), PI, "Sword_Idle", "soldier")
	b.actor(Vector3(2.0, 0, fz + 3.05), PI, "Sword_Idle", "soldier")
	b.actor(Vector3(0.75, 0, fz + 0.75), 0.0, "Idle", "soldier")
	b.door = Vector3(0, 0, fz + 3.9)


## Стрельбище: песчаное поле с тремя соломенными мишенями на треногах перед стогами (сзади), рубеж стрелков
## впереди (лучники стоят лицом к мишеням), слева — оружейная хижина со стойкой и корзинами стрел, флаг
static func _range(b: Bp) -> void:
	b.paint(9, false)
	b.ground_style = "plain"
	b.roof_tex = "Roof_Tile_12"
	b.remap = b.floor_remap(1)
	# оружейная хижина слева (1×1 модуль) с козырьком
	var hx := -3.25
	var hz := -1.1
	CatCivic._box(b, hx, hz, 1, 1, [{0: ["SM_Bld_Wall_Door_04"], 1: ["SM_Bld_Wall_Window_06"], 2: ["SM_Bld_Wall_01"], 3: ["SM_Bld_Wall_Window_06"]}], {"trim": "SM_Bld_Trim_01"})
	CatCivic._leaf(b, hx, hz, 1, 1, 0, "SM_Bld_Door_03")
	var r := CatCivic._gable2(b, hx - 1.25, hx + 1.25, hz - 1.25, hz + 1.25, FL, 1.8, true)
	b.add("SM_Bld_Roof_Topper_01", Vector3(hx, r - 0.04, hz + 1.15), 0.0)
	b.add("SM_Prop_Overhang_02", Vector3(hx - 0.6, 2.5, hz + 1.37), 0.0)
	b.on_wall("SM_Wep_Shield_0%d" % (1 + b.rng.randi() % 3), hx, hz, 1, 1, 3, 0.5, 1.7, 0.18, false, 0.6)
	_rack(b, Vector3(hx + 0.1, 0, hz - 2.3), 0.0, 2, 0.75)
	add_kit(b, "#mil_quiver", Vector3(hx + 1.6, 0, hz + 1.6), 0.0)
	add_kit(b, "#mil_quiver", Vector3(hx - 0.9, 0, hz + 1.75), 0.8)
	# поле: песок, мишени на треногах, за ними — стога сена
	_sand(b, Vector3(1.35, 0, -0.9), 6.4, 7.6)
	for i in 3:
		var x := -0.75 + i * 2.15
		add_kit(b, "#mil_target", Vector3(x, 0, -3.3 + (0.15 if i == 1 else 0.0)), b.rng.randf_range(-0.12, 0.12))
		b.add("SM_Prop_Straw_Stack_01", Vector3(x + b.rng.randf_range(-0.2, 0.2), 0, -4.35), b.rng.randf() * TAU, 0.62)
	b.add("SM_Prop_Straw_Bundle_01", Vector3(4.3, 0, -3.6), 0.3)
	# рубеж стрелков: колышки с верёвкой, скамья, корзины стрел, флаг
	for x: float in [-0.9, 1.35, 3.6]:
		b.add_xf("SM_Prop_Pole_01", Transform3D(Basis.from_scale(Vector3(0.35, 0.28, 0.35)), Vector3(x, 0, 1.15)))
	add_kit(b, "#mil_rope", Vector3(-0.9, 0.8, 1.15), 0.0)
	add_kit(b, "#mil_rope", Vector3(1.35, 0.8, 1.15), 0.0)
	b.add("SM_Prop_Seat_Bench_02" if Synty.has("SM_Prop_Seat_Bench_02") else "SM_Prop_Seat_Bench_01", Vector3(1.35, 0, 2.95), 0.0, 0.85)
	add_kit(b, "#mil_quiver", Vector3(0.25, 0, 2.3), 0.3)
	add_kit(b, "#mil_quiver", Vector3(2.5, 0, 2.3), 1.1)
	add_kit(b, "#mil_standard", Vector3(4.3, 0, 2.6), 0.0)
	CatCivic._cypress(b, Vector3(-4.4, 0, -4.3), 0.45)
	b.actor(Vector3(0.25, 0, 1.75), PI, "Pistol_Idle", "soldier")
	b.actor(Vector3(2.45, 0, 1.75), PI, "Pistol_Idle", "soldier")
	b.door = Vector3(0, 0, 3.5)


## Лагерь копейщиков: за плетнём с калиткой — три кожаные палатки-контубернии, значок посреди лагеря,
## жаровня с табуретами, стойка копий, копья и щиты у палаток, впереди — два чучела, у них копейщики
static func _spearcamp(b: Bp) -> void:
	b.paint(9, false)
	b.roof_tex = "Roof_Tile_03"
	b.remap = b.floor_remap(1)
	b.fence(-3.75, -4.6, 3.75, 3.4)
	_sand(b, Vector3(0, 0, -0.6), 7.2, 7.6)
	for i in 3:
		var x := -2.5 + i * 2.5
		add_kit(b, "#mil_tent", Vector3(x, 0, -2.85 + (0.25 if i == 1 else 0.0)), b.rng.randf_range(-0.08, 0.08))
		_spear(b, Vector3(x + 1.0, 0, -1.3), b.rng.randf() * TAU)
		_lean_shield(b, Vector3(x - 0.75, 0, -1.25), b.rng.randf_range(-0.3, 0.3), "SM_Wep_Shield_0%d" % (1 + (i + b.rng.randi()) % 4), 0.3, 0.7)
	add_kit(b, "#mil_standard", Vector3(0, 0, -0.45), 0.0)
	b.brazier(Vector3(-1.9, 0, 0.55))
	b.add("SM_Prop_Seat_Stool_01", Vector3(-2.6, 0, 1.0), 0.6, 0.9)
	b.add("SM_Prop_Seat_Stool_01", Vector3(-1.2, 0, 1.15), -0.4, 0.9)
	_rack(b, Vector3(-3.15, 0, -0.35), PI / 2, 1, 0.7)
	add_kit(b, "#mil_dummy", Vector3(1.55, 0, 0.75), -0.1)
	add_kit(b, "#mil_dummy", Vector3(3.0, 0, 0.6), 0.2)
	b.add("SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 5), Vector3(3.3, 0, -1.2), 0.0, 0.7)
	b.add("SM_Prop_Sack_Stack_01", Vector3(-3.0, 0, 2.6), 0.4, 0.7)
	b.actor(Vector3(1.55, 0, 1.9), PI, "Sword_Idle", "soldier")
	b.actor(Vector3(3.0, 0, 1.75), PI, "Sword_Idle", "soldier")
	b.actor(Vector3(-0.9, 0, 2.2), 0.3, "Idle", "soldier")
	b.door = Vector3(0, 0, 4.1)


## Мастерская баллист: кирпичный дом в два этажа фронтоном к улице (широкие ворота, наверху — балка-подъёмник),
## справа — двор под полотняным навесом: готовая баллиста на треноге, верстак с инструментами, наковальня,
## точило и штабель брусьев. Мастера чинят машину (на коленях) и работают у верстака
static func _ballistae(b: Bp) -> void:
	b.paint(-1, false)
	b.roof_tex = "Roof_Tile_06"
	var brick := CatCivic._skin(b, "Building_Large_Brick_01", Color(1.0, 0.82, 0.66))
	b.remap = brick
	var cx := -2.0
	var cz := -2.4
	CatCivic._box(b, cx, cz, 2, 2, [
		{0: ["SM_Bld_Wall_Door_Double_Large_01", "SM_Bld_Wall_Window_06"], 1: ["SM_Bld_Wall_Window_06", "SM_Bld_Wall_01"],
			2: ["SM_Bld_Wall_01", "SM_Bld_Wall_Window_06"], 3: ["SM_Bld_Wall_01", "SM_Bld_Wall_Window_06"]},
		{0: ["SM_Bld_Wall_Window_04", "SM_Bld_Wall_Door_04"], 1: ["SM_Bld_Wall_Window_04", "SM_Bld_Wall_01"],
			2: ["SM_Bld_Wall_Window_04", "SM_Bld_Wall_01"], 3: ["SM_Bld_Wall_Window_04", "SM_Bld_Wall_Window_04"]}],
		{"trim": "SM_Bld_Trim_04", "skin": brick})
	CatCivic._leaf(b, cx, cz, 2, 2, 0, "SM_Bld_Door_01", 0.05)
	b.remap = brick
	var ridge := CatCivic._gable2(b, cx - 2.5, cx + 2.5, cz - 2.5, cz + 2.5, 2 * FL, 1.6, true)
	b.remap = b.floor_remap(1)
	CatCivic._chimney(b, Vector3(cx - 1.2, ridge - 0.7, cz - 1.4))
	var fz := cz + 2.5
	# подъёмник над верхней дверью, вывеска, факелы
	b.add_xf("SM_Prop_Beam_01", Transform3D(Basis(Vector3.UP, -PI / 2).scaled_local(Vector3(0.62, 1.4, 1.4)), Vector3(cx + 1.25, FL + 2.8, fz - 0.1)))
	b.add("SM_Prop_Basket_02", Vector3(cx + 1.25, FL + 0.86, fz + 1.3), 0.4, 0.95)
	b.on_wall("SM_Prop_Symbol_0%d" % (5 + b.rng.randi() % 4), cx, cz, 2, 2, 0, 1.5, 2.6, 0.16, false, 0.5)
	b.torch_pair(cx, cz, 2, 2, 0.5)
	b.add("SM_Env_Ivy_0%d" % (1 + b.rng.randi() % 4), Vector3(cx - 2.62, 1.6, cz + 0.6), -PI / 2)
	# двор: навес на четырёх столбах, под ним — баллиста
	_sand(b, Vector3(2.35, 0, -1.4), 4.4, 6.4)
	for p: Vector3 in [Vector3(0.6, 0, -4.2), Vector3(4.2, 0, -4.2), Vector3(0.6, 0, -0.6), Vector3(4.2, 0, -0.6)]:
		b.add_xf("SM_Prop_Pole_01", Transform3D(Basis.from_scale(Vector3(0.55, 0.88, 0.55)), p))
	b.add_xf("SM_Prop_Banner_Roof_01", Transform3D(Basis(Vector3.UP, PI / 2).scaled(Vector3(1.4, 1, 1.45)), Vector3(0.55, 2.62, -0.6)))
	b.add("SM_Prop_Table_04", Vector3(2.1, 0, -2.7), 0.3, 0.95)
	b.add("SM_Prop_Tool_Hammer_01", Vector3(2.0, 0.78, -2.75), 0.8)
	b.add("SM_Prop_Tool_Chisel_01", Vector3(2.3, 0.78, -2.6), 2.0)
	b.add("SM_Prop_Anvil_01", Vector3(3.7, 0, -3.5), 0.4, 0.8)
	b.add("SM_Prop_Grinding_Wheel_01", Vector3(1.05, 0.3, -3.6), 1.4, 0.8)
	# готовая баллиста — на виду, во дворе перед навесом
	add_kit(b, "#mil_ballista", Vector3(2.7, 0, 0.75), 0.55, 1.25)
	add_kit(b, "#mil_bolts", Vector3(4.15, 0, -1.2), 1.4)
	for k in 3:
		b.add("SM_Prop_Beam_01", Vector3(-4.4, 0.08 + k * 0.16, 0.9 + k * 0.05 - (0.1 if k == 1 else 0.0)), 0.02 * k, 0.9)
	b.add_xf("SM_Prop_Ladder_01", Transform3D(Basis(Vector3.UP, PI / 2) * Basis(Vector3.RIGHT, -0.2), Vector3(4.6, 0, -3.0)))
	b.actor(Vector3(1.3, 0, 1.9), 2.2, "Fixing_Kneeling", "pleb")
	b.actor(Vector3(2.1, 0, -1.75), PI, "Interact", "pleb")
	b.door = Vector3(0.0, 0, 3.3)


## Мастерская катапульт: белёный дом с вальмовой крышей справа и каменный двор слева: онагр с камнем в ковше,
## груда ядер, мраморные глыбы под тёску, наковальня и горн под навесом. Мастера заряжают машину и тешут камень
static func _catapults(b: Bp) -> void:
	b.paint(6, false)
	b.ground_style = "brick"
	b.upper_style = "plain"
	b.roof_tex = "Roof_Tile_05"
	b.remap = b.floor_remap(1)
	var cx := 2.0
	var cz := -2.4
	CatCivic._box(b, cx, cz, 2, 2, [
		{0: ["SM_Bld_Wall_Window_06", "SM_Bld_Wall_Door_Large_01"], 1: ["SM_Bld_Wall_Window_06", "SM_Bld_Wall_01"],
			2: ["SM_Bld_Wall_01", "SM_Bld_Wall_Window_06"], 3: ["SM_Bld_Wall_01", "SM_Bld_Wall_Window_06"]},
		{0: ["SM_Bld_Wall_Window_04", "SM_Bld_Wall_Window_04"], 1: ["SM_Bld_Wall_Window_04", "SM_Bld_Wall_01"],
			2: ["SM_Bld_Wall_Window_04", "SM_Bld_Wall_01"], 3: ["SM_Bld_Wall_01", "SM_Bld_Wall_Window_04"]}],
		{"trim": "SM_Bld_Trim_02"})
	CatCivic._leaf(b, cx, cz, 2, 2, 1, "SM_Bld_Door_02", 0.05)
	var ridge := CatCivic._hip(b, cx - 2.5, cx + 2.5, cz - 2.5, cz + 2.5, 2 * FL, 1.4)
	b.add("SM_Bld_Roof_Topper_02", Vector3(cx, ridge, cz), 0.0)
	CatCivic._chimney(b, Vector3(cx + 1.3, 2 * FL + 0.4, cz - 1.2))
	var fz := cz + 2.5
	b.on_wall("SM_Prop_Overhang_01", cx, cz, 2, 2, 0, 1.5, 2.85, 0.14)
	b.on_wall("SM_Prop_Banner_01_%s" % b.pick(["B", "D", "F"]), cx, cz, 2, 2, 0, 0.5, 2 * FL - 0.3, 0.12)
	CatCivic._wall_lamp(b, Vector3(cx - 0.05, 2.3, fz + 0.06))
	b.add("SM_Env_Ivy_Flowers_0%d" % (1 + b.rng.randi() % 9), Vector3(cx + 2.62, 1.7, cz - 0.5), PI / 2)
	# каменный двор с онагром
	_sand(b, Vector3(-2.3, 0, -1.0), 4.6, 7.4)
	add_kit(b, "#mil_catapult", Vector3(-2.2, 0, -1.9), 0.35, 1.15)
	add_kit(b, "#mil_stones", Vector3(-3.9, 0, 0.9), 0.0)
	add_kit(b, "#mil_stones", Vector3(-0.6, 0, -4.2), 1.3)
	b.add("SM_Prop_Marble_Block_0%d" % (1 + b.rng.randi() % 4), Vector3(-0.7, 0, 1.4), 0.2, 0.55)
	b.add("SM_Prop_Marble_Rubble_0%d" % (1 + b.rng.randi() % 7), Vector3(-1.6, 0, 1.9), 0.0, 0.8)
	b.add("SM_Prop_Anvil_01", Vector3(-4.1, 0, -3.6), 0.6, 0.8)
	b.add("SM_Prop_Tool_Hammer_01", Vector3(-0.4, 1.07 * 0.55, 1.35), 0.4)
	CatCivic._cypress(b, Vector3(-4.5, 0, 2.7), 0.45)
	b.actor(Vector3(-1.0, 0, -0.6), -0.8, "Fixing_Kneeling", "pleb")
	b.actor(Vector3(-0.7, 0, 2.3), PI, "Interact", "pleb")
	b.door = Vector3(0.0, 0, 3.4)


## Кузница (Д10): кирпичная мастерская слева (широкие ворота, высокая труба с дымом), справа — двор под навесом:
## горн с огнём, наковальня, точило, бочка для закалки, стойка с мечами, кучи угля; кузнец у наковальни
static func _forge(b: Bp) -> void:
	b.paint(-1, false)
	b.roof_tex = "Roof_Tile_06"
	var brick := CatCivic._skin(b, "Building_Large_Brick_01", Color(1.0, 0.8, 0.64))
	b.remap = brick
	var cx := -2.0
	var cz := -2.4
	CatCivic._box(b, cx, cz, 2, 2, [
		{0: ["SM_Bld_Wall_Door_Double_Large_01", "SM_Bld_Wall_Window_06"], 1: ["SM_Bld_Wall_Window_06", "SM_Bld_Wall_01"],
			2: ["SM_Bld_Wall_01", "SM_Bld_Wall_01"], 3: ["SM_Bld_Wall_01", "SM_Bld_Wall_Window_06"]}],
		{"trim": "SM_Bld_Trim_04", "skin": brick})
	b.remap = brick
	var ridge := CatCivic._gable2(b, cx - 2.5, cx + 2.5, cz - 2.5, cz + 2.5, FL, 1.5, true)
	b.remap = b.floor_remap(1)
	CatCivic._chimney(b, Vector3(cx - 1.4, ridge - 0.9, cz - 1.5), 1.25)
	b.on_wall("SM_Prop_Symbol_0%d" % (5 + b.rng.randi() % 4), cx, cz, 2, 2, 0, 1.5, 2.25, 0.16, false, 0.45)
	b.torch_pair(cx, cz, 2, 2, 0.5)
	var fz := cz + 2.5
	# двор: сзади — навес (точило, уголь, мечи на стойке), спереди — горн с огнём и наковальня
	_sand(b, Vector3(2.3, 0, -1.2), 4.4, 7.0)
	_sand(b, Vector3(-2.0, 0, fz + 1.15), 5.0, 2.3)
	for p: Vector3 in [Vector3(0.55, 0, -4.4), Vector3(4.15, 0, -4.4), Vector3(0.55, 0, -2.2), Vector3(4.15, 0, -2.2)]:
		b.add_xf("SM_Prop_Pole_01", Transform3D(Basis.from_scale(Vector3(0.55, 0.92, 0.55)), p))
	b.add_xf("SM_Prop_Banner_Roof_01", Transform3D(Basis(Vector3.UP, PI / 2).scaled(Vector3(0.88, 1, 1.15)), Vector3(0.5, 2.75, -2.2)))
	_rack(b, Vector3(2.35, 0, -4.05), 0.0, 2, 0.75)
	b.add("SM_Prop_Grinding_Wheel_01", Vector3(1.2, 0.3, -3.0), 1.6, 0.8)
	b.add("SM_Prop_Sack_Stack_01", Vector3(3.6, 0, -3.0), -1.4, 0.7)
	b.add("SM_Prop_Forge_01", Vector3(3.35, 0, -0.75), -PI / 2, 0.8)
	b.light(Vector3(2.6, 0.9, -0.75))
	b.smoke.append(b.base * Vector3(3.35, 2.5, -0.75))
	b.add("SM_Prop_Anvil_01", Vector3(1.55, 0, -0.45), 0.3, 0.85)
	b.add("SM_Prop_Tool_Hammer_01", Vector3(1.6, 0.74, -0.45), 1.2)
	CatCivic._jar(b, Vector3(2.4, 0, 1.55), 0.75)
	# у ворот: щиты, брусья железа, корзина
	_lean_shield(b, Vector3(-0.4, 0, fz + 0.4), -0.2, "SM_Wep_Shield_04", 0.25, 0.75)
	_lean_shield(b, Vector3(-1.0, 0, fz + 0.38), 0.15, "SM_Wep_Shield_0%d" % (1 + b.rng.randi() % 4), 0.3, 0.7)
	for k in 3:
		b.add("SM_Prop_Beam_01", Vector3(-3.6, 0.06 + k * 0.12, fz + 1.7 + k * 0.04), 0.03 * k, 0.55)
	b.add("SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 5), Vector3(4.0, 0, 1.6), 0.0, 0.7)
	b.actor(Vector3(1.55, 0, 0.4), PI, "Interact", "pleb")
	b.actor(Vector3(1.6, 0, -2.6), -0.9, "Fixing_Kneeling", "pleb")
	b.door = Vector3(0.0, 0, 3.4)


## Лазарет (Д10): беленый дом под вальмовой крышей, у входа — посох Асклепия; перед домом — полотняный навес на столбах
## с койками для раненых, грядки с травами, стол с чашами и кувшинами; лекарь у койки, раненый легионер на скамье
static func _infirmary(b: Bp) -> void:
	b.paint(0, false)
	b.ground_style = "plain"
	b.upper_style = "plain"
	b.roof_tex = "Roof_Tile_01"
	b.remap = b.floor_remap(1)
	var cz := -2.6
	CatCivic._box(b, 0, cz, 3, 2, [
		{0: ["SM_Bld_Wall_Window_06", "SM_Bld_Wall_Door_Double_01", "SM_Bld_Wall_Window_06"], 1: ["SM_Bld_Wall_Window_06", "SM_Bld_Wall_01"],
			2: ["SM_Bld_Wall_01", "SM_Bld_Wall_Window_06", "SM_Bld_Wall_01"], 3: ["SM_Bld_Wall_01", "SM_Bld_Wall_Window_06"]}],
		{"trim": "SM_Bld_Trim_02", "plain": [2]})
	CatCivic._leaf(b, 0, cz, 3, 2, 1, "SM_Bld_Door_02", 0.1)
	var ridge := CatCivic._hip(b, -3.75, 3.75, cz - 2.5, cz + 2.5, FL, 1.4)
	b.add("SM_Bld_Roof_Topper_02", Vector3(0, ridge, cz), 0.0)
	CatCivic._chimney(b, Vector3(2.4, FL + 0.45, cz - 1.3), 0.9)
	b.on_wall("SM_Prop_Symbol_0%d" % (1 + b.rng.randi() % 4), 0, cz, 3, 2, 0, 1.5, 2.4, 0.16, false, 0.45)
	b.on_wall("SM_Env_Ivy_Flowers_0%d" % (1 + b.rng.randi() % 9), 0, cz, 3, 2, 0, 0.15, 2.4, 0.13)
	CatCivic._wall_lamp(b, Vector3(-1.2, 2.3, cz + 2.56))
	var fz := cz + 2.5
	# навес с койками слева
	_sand(b, Vector3(0, 0, fz + 1.6), 8.4, 3.2)
	for p: Vector3 in [Vector3(-3.95, 0, fz + 0.3), Vector3(-0.45, 0, fz + 0.3), Vector3(-3.95, 0, fz + 3.0), Vector3(-0.45, 0, fz + 3.0)]:
		b.add_xf("SM_Prop_Pole_01", Transform3D(Basis.from_scale(Vector3(0.5, 0.8, 0.5)), p))
	b.add_xf("SM_Prop_Banner_Roof_01", Transform3D(Basis(Vector3.UP, PI / 2).scaled(Vector3(1.04, 1, 1.38)), Vector3(-4.0, 2.4, fz + 3.05)))
	b.add("SM_Prop_Seat_Kline_02", Vector3(-2.2, 0, fz + 0.95), 0.0, 0.85)
	b.add("SM_Prop_Seat_Kline_02", Vector3(-2.2, 0, fz + 2.3), 0.0, 0.85)
	b.add("SM_Prop_Pillow_0%d" % (1 + b.rng.randi() % 8), Vector3(-3.0, 0.55, fz + 0.95), 0.3, 0.8)
	b.add("SM_Prop_Pillow_0%d" % (1 + b.rng.randi() % 8), Vector3(-3.0, 0.55, fz + 2.3), -0.2, 0.8)
	# справа — травы, стол лекаря, кувшины
	b.add("SM_Prop_FlowerBed_0%d" % (1 + b.rng.randi() % 2), Vector3(2.65, 0, fz + 0.75), 0.0, 1.0)
	b.add("SM_Prop_FlowerBed_0%d" % (1 + b.rng.randi() % 2), Vector3(2.65, 0, fz + 1.75), 0.0, 1.0)
	b.add("SM_Prop_Table_04", Vector3(3.6, 0, fz + 2.8), 0.4, 0.85)
	b.add("SM_Prop_Bowl_0%d" % (1 + b.rng.randi() % 4), Vector3(3.6, 0.67, fz + 2.8), 0.0, 0.35)
	b.add("SM_Prop_Jug_0%d" % (1 + b.rng.randi() % 6), Vector3(3.95, 0, fz + 2.2), 0.0, 0.8)
	CatCivic._jar(b, Vector3(3.95, 0, fz + 1.25), 0.65)
	b.add("SM_Prop_Seat_Bench_01", Vector3(2.3, 0, fz + 2.9), 0.0, 0.8)
	b.actor(Vector3(-2.15, 0, fz + 1.62), PI, "Fixing_Kneeling", "female")
	b.actor(Vector3(2.3, 0, fz + 3.0), PI, "Sitting_Idle", "soldier")
	b.door = Vector3(0, 0, fz + 3.9)


## Склад оружия (Д10): каменный склад под двускатной крышей с широкими воротами, над ними — знамя; во дворе — стойки
## копий и мечей, щиты штабелями, корзины и мешки, телега со снаряжением; у ворот — часовой
static func _armory(b: Bp) -> void:
	b.paint(-1, false)
	b.roof_tex = "Roof_Tile_03"
	var stone := CatCivic._skin(b, "Building_Large_Brick_01", Color(0.96, 0.92, 0.84))
	b.remap = stone
	var cz := -2.6
	CatCivic._box(b, 0, cz, 3, 2, [
		{0: ["SM_Bld_Wall_Window_06", "SM_Bld_Wall_Door_Double_Large_01", "SM_Bld_Wall_Window_06"], 1: ["SM_Bld_Wall_01", "SM_Bld_Wall_Window_06"],
			2: ["SM_Bld_Wall_01", "SM_Bld_Wall_01", "SM_Bld_Wall_01"], 3: ["SM_Bld_Wall_Window_06", "SM_Bld_Wall_01"]}],
		{"trim": "SM_Bld_Trim_04", "skin": stone, "plain": [2]})
	CatCivic._leaf(b, 0, cz, 3, 2, 1, "SM_Bld_Door_01", 0.05)
	b.remap = stone
	var ridge := CatCivic._gable2(b, -3.75, 3.75, cz - 2.5, cz + 2.5, FL, 1.6)
	b.remap = b.floor_remap(1)
	b.add("SM_Bld_Roof_Topper_01", Vector3(-1.25, ridge - 0.05, cz), 0.0)
	b.add("SM_Bld_Roof_Topper_01", Vector3(1.25, ridge - 0.05, cz), 0.0)
	b.on_wall("SM_Prop_Banner_01_%s" % b.pick(["A", "C", "E"]), 0, cz, 3, 2, 0, 1.5, FL + 0.55, 0.12)
	b.torch_pair(0, cz, 3, 2, 1.5)
	var fz := cz + 2.5
	_sand(b, Vector3(0, 0, fz + 1.7), 8.4, 3.4)
	_rack(b, Vector3(-3.95, 0, fz + 1.7), PI / 2, 1)
	_rack(b, Vector3(3.95, 0, fz + 1.7), -PI / 2, 2)
	# щиты штабелями у стены и у стоек
	for k in 3:
		_lean_shield(b, Vector3(-2.6 + k * 0.35, 0, fz + 0.35), 0.1 * k, "SM_Wep_Shield_0%d" % (1 + (k + b.rng.randi()) % 4), 0.28, 0.72)
		_lean_shield(b, Vector3(1.9 + k * 0.38, 0, fz + 0.35), -0.1 * k, "SM_Wep_Shield_04", 0.25, 0.75)
	b.add("SM_Prop_Basket_Set_0%d" % (1 + b.rng.randi() % 6), Vector3(-2.3, 0, fz + 2.5), 0.3, 0.75)
	b.add("SM_Prop_Sack_Stack_0%d" % (1 + b.rng.randi() % 2), Vector3(2.4, 0, fz + 2.65), -0.2, 0.7)
	b.actor(Vector3(1.05, 0, fz + 0.6), 0.0, "Sword_Idle", "soldier")
	b.door = Vector3(0, 0, fz + 3.9)


# =====================================================================
#   облик по уровню (Д10): что прибавляется с каждым уровнем здания
# =====================================================================

## Где у здания растёт облик (всё — внутри участка 1-го уровня, проверка test_legion mode=api):
## poles — два высоких значка легиона (2-й уровень); box — фасад [cx, cz, модулей в ширину, в глубину, этажей]
## для знамён на стене (3-й); fire — жаровни у входа (3-й); eagle — золотой орёл на высоком постаменте (4-й);
## porch — портик с колоннами у двери [x0, x1] (5-й: пристройка); statue — легионер на колонне (5-й, где портику
## не место); ridge — золотой орёл на коньке крыши (6-й), tall — у лагеря без крыши: орёл на высоком древке.
## Vector3.INF / [] — этого у здания нет
const NO := Vector3.INF
const GROW := {
	"barracks": {"poles": [Vector3(-4.15, 0, 3.2), Vector3(4.15, 0, 3.2)], "box": [0.0, -2.6, 3, 2, 2], "fire": [Vector3(-1.4, 0, 3.25), Vector3(1.4, 0, 3.25)],
		"eagle": Vector3(-3.1, 0, 2.85), "porch": [-1.25, 1.25], "statue": Vector3(3.1, 0, 2.6), "ridge": Vector3(0, 7.1, -2.6)},
	"range": {"poles": [Vector3(-1.6, 0, 2.6), Vector3(3.45, 0, 2.7)], "box": [-3.25, -1.1, 1, 1, 1], "fire": [Vector3(-1.0, 0, 2.55), Vector3(4.25, 0, 1.75)],
		"eagle": Vector3(-1.45, 0, 0.65), "porch": [], "statue": Vector3(-1.45, 0, -1.5), "ridge": Vector3(-3.25, 4.25, -1.1)},
	"spearcamp": {"poles": [Vector3(-3.35, 0, 3.0), Vector3(3.35, 0, 3.0)], "box": [], "fire": [Vector3(-1.9, 0, 2.85), Vector3(0.6, 0, 2.9)],
		"eagle": Vector3(2.3, 0, 2.85), "porch": [], "statue": Vector3(-3.15, 0, 1.45), "ridge": NO, "tall": Vector3(0, 0, -4.15)},
	"ballistae": {"poles": [Vector3(-4.35, 0, 0.55), Vector3(4.4, 0, 1.55)], "box": [-2.0, -2.4, 2, 2, 2], "fire": [Vector3(-0.35, 0, 0.6), Vector3(-1.95, 0, 0.55)],
		"eagle": Vector3(0.5, 0, 1.45), "porch": [], "statue": NO, "ridge": Vector3(-2.0, 7.25, -2.4)},
	"catapults": {"poles": [Vector3(-3.75, 0, 2.5), Vector3(-0.3, 0, 2.45)], "box": [2.0, -2.4, 2, 2, 2], "fire": [Vector3(-2.9, 0, 2.5)],
		"eagle": Vector3(-1.75, 0, 2.45), "porch": [], "statue": NO, "ridge": Vector3(2.0, 7.05, -2.4)},
	"forge": {"poles": [Vector3(-4.3, 0, 2.15), Vector3(4.3, 0, 2.15)], "box": [-2.0, -2.4, 2, 2, 1], "fire": [Vector3(-4.15, 0, 0.75), Vector3(-1.85, 0, 0.75)],
		"eagle": Vector3(0.55, 0, 1.75), "porch": [-4.5, -2.0], "statue": NO, "ridge": Vector3(-2.0, 4.9, -2.4)},
	"infirmary": {"poles": [Vector3(-4.15, 0, 1.6), Vector3(4.05, 0, 3.0)], "box": [0.0, -2.6, 3, 2, 1], "fire": [Vector3(-1.0, 0, 3.1), Vector3(1.0, 0, 3.1)],
		"eagle": Vector3(3.95, 0, 0.45), "porch": [-1.25, 1.25], "statue": NO, "ridge": Vector3(0, 4.05, -2.6)},
	"armory": {"poles": [Vector3(-4.0, 0, 3.05), Vector3(4.0, 0, 3.05)], "box": [0.0, -2.6, 3, 2, 1], "fire": [Vector3(-1.1, 0, 3.1), Vector3(1.1, 0, 3.1)],
		"eagle": Vector3(-2.75, 0, 1.45), "porch": [-1.25, 1.25], "statue": Vector3(2.7, 0, 1.4), "ridge": Vector3(0, 5.0, -2.6)},
	"mars": {"poles": [Vector3(-2.4, 0, 4.0), Vector3(2.4, 0, 4.0)], "box": [0.0, -2.4, 3, 2, 1], "fire": [Vector3(-3.6, 0, 4.0), Vector3(3.6, 0, 4.0)],
		"eagle": Vector3(-3.7, 0, 2.0), "porch": [], "statue": Vector3(3.7, 0, 2.0), "ridge": Vector3(0, 5.15, -2.4)},
	"principia": {"poles": [Vector3(-4.2, 0, 1.0), Vector3(4.2, 0, 1.0)], "box": [0.0, -2.6, 3, 2, 1], "fire": [Vector3(-3.4, 0, 3.4), Vector3(3.4, 0, 3.4)],
		"eagle": Vector3(-1.9, 0, 3.6), "porch": [], "statue": Vector3(1.9, 0, 3.6), "ridge": Vector3(0, 5.3, -2.6)},
	"smelter": {"poles": [Vector3(-4.3, 0, 2.3), Vector3(4.4, 0, 3.4)], "box": [-2.0, -2.6, 2, 2, 1], "fire": [Vector3(-3.7, 0, 0.5), Vector3(-0.3, 0, 0.5)],
		"eagle": Vector3(2.0, 0, 3.0), "porch": [], "statue": NO, "ridge": Vector3(-2.0, 4.9, -2.6)},
	"sawmill": {"poles": [Vector3(-0.9, 0, 1.7), Vector3(4.6, 0, 1.7)], "box": [-2.6, -2.8, 1, 2, 1], "fire": [Vector3(-3.7, 0, 0.4), Vector3(-1.5, 0, 0.4)],
		"eagle": Vector3(-3.9, 0, 2.6), "porch": [], "statue": NO, "ridge": Vector3(-2.6, 4.3, -2.8)},
	"tannery": {"poles": [Vector3(-4.3, 0, 2.8), Vector3(4.2, 0, 2.0)], "box": [2.0, -2.6, 2, 2, 1], "fire": [Vector3(0.6, 0, 0.5), Vector3(3.4, 0, 0.5)],
		"eagle": Vector3(-1.6, 0, 2.9), "porch": [], "statue": NO, "ridge": Vector3(2.0, 4.7, -2.6)},
}


static func _grow(b: Bp, type: String, t: int) -> void:
	var G: Dictionary = GROW.get(type, {})
	if G.is_empty():
		return
	var gr := RandomNumberGenerator.new()
	gr.seed = hash(type) + 17                       # своё для прибавок: облик уровня не зависит от того, что выпало раньше
	var keep := b.rng
	b.rng = gr
	var box: Array = G["box"]
	# 2-й уровень: два высоких значка легиона (красное полотнище, золотой орёл) у переднего края. Детали прибавок —
	# те же, что уже есть в городе (значок, жаровня, знамя Казарм, база колонны, колонны портика): почти без новых
	# вызовов отрисовки (бюджет квартала — test_legion_ui, D10 DRAWCALLS)
	for p: Vector3 in G["poles"]:
		add_kit(b, "#mil_standard", p, 0.0, 1.35)
	if t >= 2:
		# 3-й: знамёна на фасаде (у дома) и две жаровни с огнём у входа
		if box.size() >= 5:
			var y := float(box[4]) * FL - 0.3
			for i: float in ([0.3, float(box[2]) - 0.3] if int(box[2]) >= 2 else [0.5]):
				b.on_wall("SM_Prop_Banner_03_A", float(box[0]), float(box[1]), int(box[2]), int(box[3]), 0, i, y, 0.12)
		for p: Vector3 in G["fire"]:
			b.brazier(p)
	if t >= 3:
		# 4-й: золотой орёл в венке на высоком мраморном постаменте
		var e: Vector3 = G["eagle"]
		if e != NO:
			b.add("SM_Prop_Pillar_Base_02", e, 0.0, 0.8)
			add_kit(b, "#mil_eagle", e + Vector3(0, 1.2, 0), 0.0, 0.75)
	if t >= 4:
		# 5-й: пристройка — портик с колоннами у двери; где ему не место — бронзовый легионер на колонне
		var pr: Array = G["porch"]
		if pr.size() == 2 and box.size() >= 5:
			var front := float(box[1]) + float(box[3]) * M / 2.0
			b.portico(float(pr[0]), float(pr[1]), front + 1.35, front, 0.92, "SM_Bld_Pillar_02")
		var s: Vector3 = G["statue"]
		if s != NO:
			b.add("SM_Prop_Pillar_Base_02", s, 0.0, 0.8)
			b.add("SM_Prop_Statue_04", s + Vector3(0, 1.2, 0), PI * 0.1, 0.62)
	if t >= 5:
		# 6-й: большой золотой орёл на коньке крыши (у лагеря без крыши — на высоком древке)
		var r: Vector3 = G["ridge"]
		if r != NO:
			add_kit(b, "#mil_eagle", r, 0.0, 1.3)
		else:
			add_kit(b, "#mil_standard", G.get("tall", Vector3()), 0.0, 1.9)
	b.rng = keep


## Деталь Kit в чертёж (имя "#mil_…", положение, поворот)
static func add_kit(b: Bp, name: String, p: Vector3, yaw := 0.0, s := 1.0) -> void:
	b.add(name, p, yaw, s)


# =====================================================================
#   детали из Kit (палитра Synty, плоские грани, цвет в вершинах)
# =====================================================================

## Сетка детали "#mil_…" (кэш). Начало координат — середина основания, «лицо» — к +Z
static func kit_mesh(name: String) -> Mesh:
	if _meshes.has(name):
		return _meshes[name]
	var k := Kit.new()
	match name:
		"#mil_sand": _k_sand(k)
		"#mil_target": _k_target(k)
		"#mil_dummy": _k_dummy(k)
		"#mil_tent": _k_tent(k)
		"#mil_standard": _k_standard(k)
		"#mil_quiver": _k_quiver(k)
		"#mil_rope": _k_rope(k)
		"#mil_ballista": _k_ballista(k)
		"#mil_bolts": _k_bolts(k)
		"#mil_catapult": _k_catapult(k)
		"#mil_stones": _k_stones(k)
		"#mil_eagle": _k_eagle(k)
		"#mil_ore": _k_ore(k)
		"#mil_ingots": _k_ingots(k)
		"#mil_logs": _k_logs(k)
		"#mil_planks": _k_planks(k)
		"#mil_saw": _k_saw(k)
		"#mil_hides": _k_hides(k)
		"#mil_vat": _k_vat(k)
		"#mil_palisade": _k_palisade(k)
		"#mil_tent2": _k_tent2(k)
		"#mil_trophy": _k_trophy(k)
		"#mil_crane": _k_crane(k)
		"#mil_coal": _k_coal(k)
		_: k.boxc(Vector3(0, 0.5, 0), Vector3.ONE, Color.MAGENTA)
	var m := k.mesh()
	if m.get_surface_count() > 0:
		m.surface_set_material(0, Kit.material(0.9))
	_meshes[name] = m
	return m


## Большой золотой орёл в лавровом венке на постаменте (Д10, 6-й уровень: на коньке крыши или на высоком древке).
## Высота ~1 м, крылья вверх, смотрит на +Z
static func _k_eagle(k: Kit) -> void:
	k.cyl(Vector3(0, 0, 0), 0.22, 0.14, 8, BRONZE.darkened(0.1))
	k.cyl(Vector3(0, 0.14, 0), 0.16, 0.08, 8, GOLD)
	k.blob(Vector3(0, 0.42, 0), Vector3(0.14, 0.24, 0.12), GOLD, 8, 0.15)
	k.blob(Vector3(0, 0.74, 0.07), Vector3(0.08, 0.09, 0.1), GOLD, 8, 0.1)
	k.cone(Vector3(0, 0.72, 0.16), 0.035, 0.1, 5, Color("c48a20"))
	for sx: float in [-1.0, 1.0]:
		k.quad_out(Vector3(sx * 0.08, 0.36, 0.0), Vector3(sx * 0.08, 0.6, 0.0), Vector3(sx * 0.52, 0.92, -0.05), Vector3(sx * 0.46, 0.5, -0.05), GOLD, Vector3(0, 0.6, -0.6))
		k.quad_out(Vector3(sx * 0.08, 0.36, 0.0), Vector3(sx * 0.08, 0.6, 0.0), Vector3(sx * 0.52, 0.92, -0.05), Vector3(sx * 0.46, 0.5, -0.05), GOLD.darkened(0.18), Vector3(0, 0.6, 0.6))
		k.quad_out(Vector3(sx * 0.3, 0.55, -0.04), Vector3(sx * 0.46, 0.5, -0.05), Vector3(sx * 0.6, 0.62, -0.06), Vector3(sx * 0.52, 0.92, -0.05), GOLD.lightened(0.1), Vector3(0, 0.6, 0.6))
	# венок под орлом
	for j in 16:
		var a0 := TAU * j / 16.0
		var a1 := TAU * (j + 1) / 16.0
		k.rod(Vector3(cos(a0) * 0.3, 0.42 + sin(a0) * 0.3, -0.06), Vector3(cos(a1) * 0.3, 0.42 + sin(a1) * 0.3, -0.06), 0.045, 4, Color("6f8f3a") if j % 2 else Color("8aa84a"))


## Утоптанный песок плаца: плитка 1×1 м (масштабируется по месту), чуть неровная по краю
static func _k_sand(k: Kit) -> void:
	k.box(Vector3(-0.5, 0.0, -0.5), Vector3(0.5, 0.015, 0.5), SAND, ["bottom"])


## Мишень: соломенный круг с красно-белыми кольцами на деревянной треноге, в ней пара стрел
static func _k_target(k: Kit) -> void:
	for l: Array in [[Vector3(-0.42, 0, 0.22), Vector3(-0.16, 1.55, -0.04)], [Vector3(0.42, 0, 0.22), Vector3(0.16, 1.55, -0.04)], [Vector3(0, 0, -0.62), Vector3(0, 1.35, -0.12)]]:
		k.rod(l[0], l[1], 0.035, 5, WOOD)
	k.rod(Vector3(-0.36, 0.55, 0.15), Vector3(0.36, 0.55, 0.15), 0.03, 5, WOOD_D)
	var c := Vector3(0, 1.05, 0.06)
	k.xf = Transform3D(Basis(Vector3.RIGHT, PI / 2 - 0.12), c)
	k.cyl(Vector3(0, -0.09, 0), 0.56, 0.18, 16, STRAW)
	k.cyl(Vector3(0, -0.095, 0), 0.6, 0.03, 16, STRAW_D)
	k.cyl(Vector3(0, 0.09, 0), 0.45, 0.012, 16, CREAM)
	k.cyl(Vector3(0, 0.1, 0), 0.33, 0.012, 16, RED)
	k.cyl(Vector3(0, 0.11, 0), 0.21, 0.012, 16, CREAM)
	k.cyl(Vector3(0, 0.12, 0), 0.09, 0.012, 12, RED_D)
	k.xf = Transform3D.IDENTITY
	for a: Array in [[Vector3(0.12, 1.12, 0.12), Vector3(0.2, 1.2, 0.62)], [Vector3(-0.2, 0.92, 0.1), Vector3(-0.3, 0.98, 0.58)]]:
		k.rod(a[0], a[1], 0.012, 4, WOOD_L)
		k.boxc((a[1] as Vector3), Vector3(0.05, 0.07, 0.06), CREAM)


## Учебное чучело: столб на крестовине, соломенное тело в кожаной «тунике», голова в бронзовом шлеме, руки-перекладина,
## на одной — круглый щит
static func _k_dummy(k: Kit) -> void:
	k.boxc(Vector3(0, 0.05, 0), Vector3(0.8, 0.1, 0.12), WOOD_D)
	k.boxc(Vector3(0, 0.05, 0), Vector3(0.12, 0.1, 0.8), WOOD_D)
	k.rod(Vector3(0, 0, 0), Vector3(0, 1.72, 0), 0.055, 6, WOOD)
	k.rod(Vector3(-0.55, 1.28, 0), Vector3(0.55, 1.28, 0), 0.04, 5, WOOD)
	k.blob(Vector3(0, 1.08, 0), Vector3(0.27, 0.38, 0.2), STRAW, 11, 0.12)
	k.cyl(Vector3(0, 0.9, 0), 0.3, 0.32, 8, LEATHER_D, 0.27)
	k.cyl(Vector3(0, 1.0, 0), 0.31, 0.05, 8, RED_D)
	k.blob(Vector3(0, 1.6, 0), Vector3(0.14, 0.15, 0.14), STRAW, 12, 0.1)
	k.cyl(Vector3(0, 1.63, 0), 0.16, 0.13, 8, BRONZE, 0.1)
	k.boxc(Vector3(0, 1.82, -0.01), Vector3(0.04, 0.09, 0.22), RED)
	k.xf = Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0.55, 1.12, 0.06))
	k.cyl(Vector3(0, 0, 0), 0.26, 0.05, 12, RED)
	k.cyl(Vector3(0, 0.05, 0), 0.07, 0.04, 8, BRONZE)
	k.xf = Transform3D.IDENTITY


## Кожаная палатка легионеров (папилион): двускатная, низкие боковые стенки, полог спереди откинут —
## внутри темно; конёк на шестах, растяжки к колышкам
static func _k_tent(k: Kit) -> void:
	var hw := 1.05
	var hl := 1.3
	var wall := 0.35
	var top := 1.7
	var inside := Vector3(0, 0.7, 0)
	for sx: float in [-1.0, 1.0]:
		# скат
		k.quad_out(Vector3(sx * hw, wall, -hl), Vector3(sx * hw, wall, hl), Vector3(0, top, hl), Vector3(0, top, -hl), LEATHER if sx < 0 else LEATHER_D, inside)
		# низкая стенка
		k.quad_out(Vector3(sx * hw, 0, -hl), Vector3(sx * hw, 0, hl), Vector3(sx * hw, wall, hl), Vector3(sx * hw, wall, -hl), LEATHER_D, inside)
		# швы по скату
		for j in 3:
			var z := -hl + (j + 1) * hl * 2.0 / 4.0
			k.quad_out(Vector3(sx * (hw + 0.005), wall, z - 0.025), Vector3(sx * (hw + 0.005), wall, z + 0.025), Vector3(0, top + 0.005, z + 0.025), Vector3(0, top + 0.005, z - 0.025), LEATHER_D.darkened(0.15), inside)
	# задняя стенка
	k.tri_out(Vector3(-hw, wall, -hl), Vector3(hw, wall, -hl), Vector3(0, top, -hl), LEATHER_D, inside)
	k.quad_out(Vector3(-hw, 0, -hl), Vector3(hw, 0, -hl), Vector3(hw, wall, -hl), Vector3(-hw, wall, -hl), LEATHER_D, inside)
	# спереди: тёмный вход и откинутые полы
	k.tri_out(Vector3(-hw * 0.95, 0.02, hl - 0.25), Vector3(hw * 0.95, 0.02, hl - 0.25), Vector3(0, top - 0.05, hl - 0.25), Color("2a2019"), Vector3(0, 0.7, -2.0))
	for sx: float in [-1.0, 1.0]:
		k.tri_out(Vector3(sx * hw * 0.55, 0.0, hl + 0.1), Vector3(sx * hw * 1.05, 0.0, hl - 0.05), Vector3(sx * 0.12, top - 0.1, hl), LEATHER, Vector3(sx * 0.3, 0.6, hl - 1.0))
	# конёк и шесты
	k.rod(Vector3(0, top + 0.03, -hl - 0.1), Vector3(0, top + 0.03, hl + 0.1), 0.035, 5, WOOD)
	k.rod(Vector3(0, 0, hl + 0.05), Vector3(0, top + 0.12, hl + 0.05), 0.03, 5, WOOD)
	k.rod(Vector3(0, 0, -hl - 0.05), Vector3(0, top + 0.12, -hl - 0.05), 0.03, 5, WOOD)
	# растяжки и колышки
	for sz: float in [-1.0, 1.0]:
		k.rod(Vector3(0, top + 0.1, sz * (hl + 0.05)), Vector3(0, 0.05, sz * (hl + 0.75)), 0.008, 3, ROPE)
		k.boxc(Vector3(0, 0.06, sz * (hl + 0.78)), Vector3(0.05, 0.12, 0.05), WOOD_D)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-0.7, 0.7]:
			k.rod(Vector3(sx * hw, wall, sz), Vector3(sx * (hw + 0.5), 0.04, sz), 0.007, 3, ROPE)


## Значок легиона: древко, перекладина с красным полотнищем (золотая бахрома), наверху золотой орёл в венке,
## на древке — бронзовые фалеры
static func _k_standard(k: Kit) -> void:
	k.rod(Vector3(0, 0, 0), Vector3(0, 3.1, 0), 0.04, 6, WOOD_D)
	k.cone(Vector3(0, -0.02, 0), 0.06, 0.25, 6, IRON)
	k.rod(Vector3(-0.42, 2.45, 0.03), Vector3(0.42, 2.45, 0.03), 0.025, 5, WOOD)
	k.boxc(Vector3(0, 1.98, 0.06), Vector3(0.78, 0.9, 0.025), RED)
	k.boxc(Vector3(0, 1.98, 0.075), Vector3(0.6, 0.06, 0.02), GOLD)
	k.boxc(Vector3(0, 2.2, 0.075), Vector3(0.12, 0.3, 0.02), GOLD)
	k.boxc(Vector3(0, 1.5, 0.06), Vector3(0.8, 0.06, 0.03), GOLD)
	for x: float in [-0.39, 0.39]:
		k.blob(Vector3(x, 2.45, 0.03), Vector3(0.04, 0.04, 0.04), GOLD, 3, 0.05)
	for j in 3:
		k.xf = Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 1.0 - j * 0.22, 0.04))
		k.cyl(Vector3(0, 0, 0), 0.07, 0.02, 10, BRONZE)
	k.xf = Transform3D.IDENTITY
	# орёл: тело, крылья вверх, голова; под ним — венок
	k.cyl(Vector3(0, 3.1, 0), 0.07, 0.05, 8, GOLD)
	k.blob(Vector3(0, 3.27, 0), Vector3(0.07, 0.12, 0.06), GOLD, 7, 0.08)
	k.blob(Vector3(0, 3.42, 0.03), Vector3(0.04, 0.045, 0.05), GOLD, 8, 0.05)
	for sx: float in [-1.0, 1.0]:
		k.quad_out(Vector3(sx * 0.04, 3.24, 0.0), Vector3(sx * 0.04, 3.36, 0.0), Vector3(sx * 0.24, 3.5, -0.02), Vector3(sx * 0.22, 3.3, -0.02), GOLD, Vector3(0, 3.3, -0.3))
		k.quad_out(Vector3(sx * 0.04, 3.24, 0.0), Vector3(sx * 0.04, 3.36, 0.0), Vector3(sx * 0.24, 3.5, -0.02), Vector3(sx * 0.22, 3.3, -0.02), GOLD.darkened(0.15), Vector3(0, 3.3, 0.3))
	# лавровый венок — кольцо из листочков
	for j in 12:
		var a0 := TAU * j / 12.0
		var a1 := TAU * (j + 1) / 12.0
		k.rod(Vector3(cos(a0) * 0.15, 2.85 + sin(a0) * 0.15, 0.03), Vector3(cos(a1) * 0.15, 2.85 + sin(a1) * 0.15, 0.03), 0.025, 4, Color("6f8f3a") if j % 2 else Color("8aa84a"))


## Плетёная корзина со стрелами (оперение белое)
static func _k_quiver(k: Kit) -> void:
	k.cyl(Vector3(0, 0, 0), 0.2, 0.55, 8, Color("a8834f"), 0.24)
	k.cyl(Vector3(0, 0.5, 0), 0.25, 0.05, 8, Color("8a6a3e"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 9:
		var a := TAU * i / 9.0
		var p := Vector3(cos(a) * 0.12, 0.3, sin(a) * 0.12)
		var tip := p + Vector3(cos(a) * 0.08 + rng.randf_range(-0.03, 0.03), 0.62, sin(a) * 0.08)
		k.rod(p, tip, 0.012, 4, WOOD_L)
		k.boxc(tip - Vector3(0, 0.04, 0), Vector3(0.05, 0.1, 0.05), CREAM)


## Верёвка рубежа между колышками (2,25 м вдоль X)
static func _k_rope(k: Kit) -> void:
	k.rod(Vector3(0, 0, 0), Vector3(1.12, -0.12, 0), 0.012, 4, ROPE)
	k.rod(Vector3(1.12, -0.12, 0), Vector3(2.25, 0, 0), 0.012, 4, ROPE)
	k.boxc(Vector3(1.12, -0.2, 0), Vector3(0.12, 0.14, 0.02), RED)


## Баллиста-скорпион на треноге: ложе с жёлобом и болтом (бронзовый наконечник вперёд, +Z), торсионная рама
## с двумя пучками жил, плечи и тетива, ворот сзади, бронзовый щиток. Длина ~2,4 м, высота ~1,6 м
static func _k_ballista(k: Kit) -> void:
	var y := 1.12
	# тренога и поворотная ось
	for l: Vector3 in [Vector3(-0.62, 0, 0.5), Vector3(0.62, 0, 0.5), Vector3(0, 0, -0.75)]:
		k.rod(Vector3(0, y - 0.1, 0), l, 0.045, 5, WOOD_D)
	k.cyl(Vector3(0, y - 0.22, 0), 0.09, 0.2, 8, IRON)
	# ложе
	k.boxc(Vector3(0, y, -0.15), Vector3(0.18, 0.14, 2.0), WOOD)
	k.boxc(Vector3(0, y + 0.08, -0.15), Vector3(0.08, 0.03, 1.95), WOOD_D)
	# рама с пучками жил
	k.boxc(Vector3(0, y + 0.04, 0.62), Vector3(0.95, 0.12, 0.2), WOOD_D)
	k.boxc(Vector3(0, y + 0.52, 0.62), Vector3(0.95, 0.12, 0.2), WOOD_D)
	for sx: float in [-1.0, 1.0]:
		k.boxc(Vector3(sx * 0.46, y + 0.28, 0.62), Vector3(0.06, 0.5, 0.2), WOOD_D)
		k.cyl(Vector3(sx * 0.27, y + 0.1, 0.62), 0.085, 0.38, 8, ROPE)
		k.cyl(Vector3(sx * 0.27, y + 0.08, 0.62), 0.11, 0.05, 8, BRONZE)
		k.cyl(Vector3(sx * 0.27, y + 0.47, 0.62), 0.11, 0.05, 8, BRONZE)
		# плечи и тетива
		k.rod(Vector3(sx * 0.27, y + 0.28, 0.66), Vector3(sx * 0.85, y + 0.28, 0.25), 0.035, 5, WOOD)
		k.rod(Vector3(sx * 0.85, y + 0.28, 0.25), Vector3(0, y + 0.13, -0.45), 0.008, 3, CREAM)
	# щиток с бронзой
	k.boxc(Vector3(0, y + 0.28, 0.75), Vector3(0.36, 0.42, 0.03), RED_D)
	k.cyl(Vector3(0, y + 0.28, 0.76), 0.07, 0.03, 8, BRONZE)
	# болт и наконечник
	k.rod(Vector3(0, y + 0.13, -0.45), Vector3(0, y + 0.13, 1.05), 0.022, 5, WOOD_L)
	k.xf = Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, y + 0.13, 1.05))
	k.cone(Vector3(0, 0, 0), 0.04, 0.16, 5, BRONZE)
	k.xf = Transform3D.IDENTITY
	k.boxc(Vector3(0, y + 0.13, -0.35), Vector3(0.12, 0.02, 0.1), RED)
	# ворот сзади
	k.rod(Vector3(-0.2, y - 0.02, -1.05), Vector3(0.2, y - 0.02, -1.05), 0.06, 8, WOOD)
	for sx: float in [-1.0, 1.0]:
		k.rod(Vector3(sx * 0.21, y - 0.02, -1.05), Vector3(sx * 0.21, y + 0.2, -1.15), 0.02, 4, IRON)


## Связка болтов для баллисты на козлах
static func _k_bolts(k: Kit) -> void:
	for sx: float in [-0.35, 0.35]:
		k.rod(Vector3(sx, 0, -0.2), Vector3(sx, 0.5, 0), 0.03, 4, WOOD_D)
		k.rod(Vector3(sx, 0, 0.2), Vector3(sx, 0.5, 0), 0.03, 4, WOOD_D)
	for i in 5:
		var z := -0.12 + i * 0.06
		k.rod(Vector3(-0.6, 0.5 + (i % 2) * 0.04, z), Vector3(0.6, 0.5 + (i % 2) * 0.04, z), 0.02, 4, WOOD_L)
		k.xf = Transform3D(Basis(Vector3.BACK, -PI / 2), Vector3(0.6, 0.5 + (i % 2) * 0.04, z))
		k.cone(Vector3(0, 0, 0), 0.035, 0.12, 4, BRONZE)
		k.xf = Transform3D.IDENTITY


## Онагр на колёсах: рама из двух брусьев, четыре колеса, торсионный пучок поперёк, рычаг взведён назад —
## в ковше камень; впереди — стойки с перекладиной-упором (с соломенной подушкой), сзади — ворот.
## Стреляет вперёд (+Z). Длина ~3,2 м
static func _k_catapult(k: Kit) -> void:
	for sx: float in [-1.0, 1.0]:
		k.boxc(Vector3(sx * 0.62, 0.42, 0), Vector3(0.2, 0.22, 3.0), WOOD)
		for sz: float in [-1.05, 1.05]:
			k.rod(Vector3(sx * 0.74, 0.36, sz), Vector3(sx * 0.88, 0.36, sz), 0.36, 10, WOOD_D)
			k.rod(Vector3(sx * 0.73, 0.36, sz), Vector3(sx * 0.9, 0.36, sz), 0.08, 6, IRON)
	for z: float in [-1.3, -0.55, 0.5, 1.3]:
		k.boxc(Vector3(0, 0.44, z), Vector3(1.44, 0.16, 0.18), WOOD_D)
	# торсионный пучок и бронзовые втулки
	k.rod(Vector3(-0.52, 0.55, -0.55), Vector3(0.52, 0.55, -0.55), 0.15, 8, ROPE)
	for sx: float in [-1.0, 1.0]:
		k.rod(Vector3(sx * 0.5, 0.55, -0.55), Vector3(sx * 0.6, 0.55, -0.55), 0.2, 8, BRONZE)
	# стойки и упор
	for sx: float in [-1.0, 1.0]:
		k.rod(Vector3(sx * 0.62, 0.5, 0.75), Vector3(sx * 0.5, 1.62, 0.35), 0.07, 6, WOOD)
		k.rod(Vector3(sx * 0.62, 0.5, -0.2), Vector3(sx * 0.5, 1.62, 0.35), 0.06, 6, WOOD)
	k.rod(Vector3(-0.62, 1.62, 0.35), Vector3(0.62, 1.62, 0.35), 0.09, 6, WOOD_D)
	k.blob(Vector3(0, 1.62, 0.45), Vector3(0.28, 0.13, 0.12), STRAW, 21, 0.1)
	# рычаг, взведённый назад, ковш с камнем
	var a := Vector3(0, 0.6, -0.55)
	var e := Vector3(0, 1.05, -2.05)
	k.rod(a, e, 0.075, 6, WOOD_L)
	k.boxc(e + Vector3(0, 0.02, 0), Vector3(0.38, 0.12, 0.38), WOOD_D)
	k.blob(e + Vector3(0, 0.2, 0), Vector3(0.17, 0.15, 0.17), STONE, 31, 0.12)
	# ворот сзади
	k.rod(Vector3(-0.62, 0.62, -1.3), Vector3(0.62, 0.62, -1.3), 0.08, 8, WOOD)
	for sx: float in [-1.0, 1.0]:
		for j in 4:
			var ang := j * PI / 2.0
			k.rod(Vector3(sx * 0.66, 0.62, -1.3), Vector3(sx * 0.66, 0.62 + cos(ang) * 0.32, -1.3 + sin(ang) * 0.32), 0.02, 4, WOOD_D)
	k.rod(Vector3(0, 0.62, -1.25), e + Vector3(0, 0.0, 0.1), 0.01, 3, ROPE)


## Груда каменных ядер
static func _k_stones(k: Kit) -> void:
	var pts := [Vector3(0, 0.17, 0), Vector3(0.36, 0.16, 0.05), Vector3(-0.33, 0.16, 0.1), Vector3(0.05, 0.16, 0.36), Vector3(0.0, 0.16, -0.34),
		Vector3(0.12, 0.44, 0.08), Vector3(-0.15, 0.42, -0.08), Vector3(0.0, 0.66, 0.0)]
	for i in pts.size():
		var r := 0.17 + (i % 3) * 0.015
		k.blob(pts[i], Vector3(r, r * 0.95, r), STONE.darkened(0.08 * (i % 3)), 40 + i, 0.1)

# =====================================================================
#   мастерские Легиона 2.0 (этап 3): Плавильня, Лесопилка, Дубильня — маленькие, уютные, люди при деле
# =====================================================================

## Плавильня: каменный домик с трубой; во дворе — печь с огнём и дымом, куча руды, бруски железа, наковальня, тачка
static func _smelter(b: Bp) -> void:
	b.paint(-1, false)
	b.roof_tex = "Roof_Tile_06"
	var stone := CatCivic._skin(b, "Building_Large_Brick_01", Color(0.9, 0.84, 0.78))
	b.remap = stone
	var cx := -2.0
	var cz := -2.6
	CatCivic._box(b, cx, cz, 2, 2, [
		{0: ["SM_Bld_Wall_Door_Double_Large_01", "SM_Bld_Wall_Window_06"], 1: ["SM_Bld_Wall_01", "SM_Bld_Wall_01"],
			2: ["SM_Bld_Wall_01", "SM_Bld_Wall_01"], 3: ["SM_Bld_Wall_01", "SM_Bld_Wall_Window_06"]}],
		{"trim": "SM_Bld_Trim_04", "skin": stone})
	b.remap = stone
	var ridge := CatCivic._gable2(b, cx - 2.5, cx + 2.5, cz - 2.5, cz + 2.5, FL, 1.5, true)
	b.remap = b.floor_remap(1)
	CatCivic._chimney(b, Vector3(cx + 1.3, ridge - 0.9, cz - 1.4), 1.3)
	b.torch_pair(cx, cz, 2, 2, 0.5)
	var fz := cz + 2.5
	_sand(b, Vector3(2.4, 0, -0.6), 4.6, 7.6)
	_sand(b, Vector3(-2.0, 0, fz + 1.2), 5.0, 2.4)
	# печь: обжиговая печь Synty, огонь и дым; рядом мехи (мешки) и уголь
	b.add("SM_Prop_Kiln_01", Vector3(2.6, 0, -2.6), PI, 0.85)
	b.light(Vector3(2.6, 0.8, -1.6))
	b.smoke.append(b.base * Vector3(2.6, 3.0, -2.8))
	add_kit(b, "#mil_ore", Vector3(4.0, 0, -0.6), 0.4, 1.0)
	add_kit(b, "#mil_ore", Vector3(3.6, 0, 0.6), 2.1, 0.75)
	add_kit(b, "#mil_ingots", Vector3(1.2, 0, 1.2), 0.2, 1.0)
	add_kit(b, "#mil_ingots", Vector3(-3.6, 0, fz + 1.6), -0.3, 0.9)
	b.add("SM_Prop_Anvil_01", Vector3(1.0, 0, -0.6), 0.5, 0.8)
	b.add("SM_Prop_Tool_Hammer_01", Vector3(1.05, 0.7, -0.6), 1.0)
	b.add("SM_Prop_Cart_01", Vector3(3.9, 0, 2.6), -PI / 2 + 0.2, 0.7)
	b.add("SM_Prop_Sack_Stack_01", Vector3(-0.3, 0, fz + 0.5), 0.6, 0.65)
	b.actor(Vector3(2.5, 0, -1.2), PI, "Interact", "pleb")
	b.actor(Vector3(1.0, 0, 0.2), PI + 0.4, "Fixing_Kneeling", "pleb")
	b.door = Vector3(0.0, 0, 3.6)


## Лесопилка: домик пильщиков слева, справа — навес на столбах: козлы с бревном и большой пилой, штабеля брёвен и досок
static func _sawmill(b: Bp) -> void:
	b.paint(-1, false)
	b.roof_tex = "Roof_Tile_06"
	var wall := CatCivic._skin(b, "Building_Large_Brick_01", Color(1.0, 0.9, 0.74))
	b.remap = wall
	var cx := -2.6
	var cz := -2.8
	CatCivic._box(b, cx, cz, 1, 2, [
		{0: ["SM_Bld_Wall_Door_01"], 1: ["SM_Bld_Wall_01", "SM_Bld_Wall_Window_06"], 2: ["SM_Bld_Wall_01"], 3: ["SM_Bld_Wall_Window_06", "SM_Bld_Wall_01"]}],
		{"trim": "SM_Bld_Trim_04", "skin": wall})
	b.remap = wall
	CatCivic._gable2(b, cx - 1.25, cx + 1.25, cz - 2.5, cz + 2.5, FL, 1.4, true)
	b.remap = b.floor_remap(1)
	# навес: столбы спереди, крыша скатом назад к низкой стенке из досок
	CatCivic._shed(b, -0.8, 4.2, -0.2, -4.6, 2.5, "SM_Prop_Pole_01", 0.7, true, 0.7)
	for x: float in [-0.4, 1.4, 3.2]:
		b.add_xf("SM_Prop_Beam_01", Transform3D(Basis(Vector3.UP, 0.0).scaled_local(Vector3(0.75, 1.2, 1.2)), Vector3(x + 0.55, 0.45, -4.4)))
	_sand(b, Vector3(1.8, 0, -1.4), 6.4, 6.8)
	_sand(b, Vector3(-2.6, 0, 1.3), 2.8, 3.0)
	add_kit(b, "#mil_saw", Vector3(1.6, 0, -2.0), 0.0, 1.0)
	add_kit(b, "#mil_logs", Vector3(3.6, 0, -3.4), PI / 2, 1.0)
	add_kit(b, "#mil_logs", Vector3(3.9, 0, 1.4), 0.15, 0.85)
	add_kit(b, "#mil_planks", Vector3(-0.2, 0, -3.6), 0.0, 1.0)
	add_kit(b, "#mil_planks", Vector3(-2.6, 0, 1.0), PI / 2, 0.9)
	b.add("SM_Prop_Cart_01", Vector3(1.6, 0, 2.2), PI / 2 - 0.15, 0.7)
	b.add("SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 5), Vector3(-1.2, 0, 2.6), 0.0, 0.65)
	b.actor(Vector3(0.75, 0, -2.0), PI / 2, "Interact", "pleb")
	b.actor(Vector3(2.45, 0, -2.0), -PI / 2, "Interact", "pleb")
	b.door = Vector3(0.0, 0, 3.6)


## Дубильня: беленый домик, во дворе — рамы с растянутыми шкурами, чаны с отваром, кувшины, сушка на верёвке
static func _tannery(b: Bp) -> void:
	b.paint(0, false)
	b.ground_style = "plain"
	b.upper_style = "plain"
	b.roof_tex = "Roof_Tile_01"
	var cx := 2.0
	var cz := -2.6
	b.block(cx, cz, 2, 2, 1, {"door_i": 0, "win_p": 0.6})
	b.gable(cx, cz, 2, 2, FL, false)
	b.torch_pair(cx, cz, 2, 2, 0.5)
	var fz := cz + 2.5
	_sand(b, Vector3(-2.2, 0, -0.8), 5.2, 7.2)
	_sand(b, Vector3(2.0, 0, fz + 1.2), 5.0, 2.4)
	add_kit(b, "#mil_hides", Vector3(-3.4, 0, -3.0), 0.3, 1.0)
	add_kit(b, "#mil_hides", Vector3(-1.4, 0, -3.5), -0.15, 0.95)
	add_kit(b, "#mil_vat", Vector3(-3.3, 0, -0.6), 0.0, 1.0)
	add_kit(b, "#mil_vat", Vector3(-1.7, 0, -0.2), 0.7, 0.9)
	add_kit(b, "#mil_vat", Vector3(-2.6, 0, 1.2), 1.3, 0.8)
	CatCivic._jar(b, Vector3(-0.5, 0, 1.4), 0.7)
	CatCivic._jar(b, Vector3(-0.1, 0, 1.0), 0.6)
	add_kit(b, "#mil_hides", Vector3(3.8, 0, fz + 1.4), -PI / 2, 0.8)
	b.add("SM_Prop_Rug_Folded_0%d" % (1 + b.rng.randi() % 3), Vector3(0.6, 0, fz + 0.7), 0.2, 0.7)
	b.actor(Vector3(-2.4, 0, -0.6), -PI / 2, "Interact", "pleb")
	b.actor(Vector3(-2.4, 0, -2.4), PI, "Fixing_Kneeling", "pleb")
	b.door = Vector3(2.0, 0, 3.6)


## Куча руды: тёмные камни с рыжими прожилками, ~1,2 м
static func _k_ore(k: Kit) -> void:
	var pts := [Vector3(0, 0.16, 0), Vector3(0.32, 0.14, 0.08), Vector3(-0.3, 0.14, 0.1), Vector3(0.06, 0.14, 0.32), Vector3(0.0, 0.14, -0.3),
		Vector3(0.1, 0.38, 0.06), Vector3(-0.12, 0.36, -0.06), Vector3(0.24, 0.3, -0.18)]
	for i in pts.size():
		var r := 0.15 + (i % 3) * 0.02
		var c := Color("4a4440").lerp(Color("8a4a2a"), 0.25 * (i % 3))
		k.blob(pts[i], Vector3(r, r * 0.85, r), c, 70 + i, 0.2)


## Бруски железа штабелем (3 ряда крест-накрест), ~0,6 м
static func _k_ingots(k: Kit) -> void:
	for row in 3:
		for j in 3:
			var y := row * 0.09
			var off := (j - 1) * 0.16
			var c := IRON.lightened(0.08 * ((row + j) % 2))
			if row % 2 == 0:
				k.boxc(Vector3(off, y, 0), Vector3(0.13, 0.08, 0.42), c, [])
			else:
				k.boxc(Vector3(0, y, off), Vector3(0.42, 0.08, 0.13), c, [])


## Брёвна пирамидой (3–2–1), длина 2 м вдоль X
static func _k_logs(k: Kit) -> void:
	var r := 0.15
	var rows := [[-0.32, 0.0, 0.32], [-0.16, 0.16], [0.0]]
	for i in rows.size():
		for z: float in rows[i]:
			var y := r + i * r * 1.7
			var c := WOOD.lerp(WOOD_D, 0.3 * ((i + int(z * 10)) % 2))
			k.rod(Vector3(-1.0, y, z), Vector3(1.0, y, z), r, 7, c)
	# светлые торцы: тонкие диски
	for i in rows.size():
		for z: float in rows[i]:
			var y := r + i * r * 1.7
			for sx: float in [-1.0, 1.0]:
				k.xf = Transform3D(Basis(Vector3.BACK, PI / 2 * sx), Vector3(sx * 1.0, y, z))
				k.cyl(Vector3(0, 0, 0), r * 0.92, 0.015, 7, WOOD_L.lightened(0.15))
				k.xf = Transform3D.IDENTITY


## Доски штабелем, 2,2 × 0,7 м
static func _k_planks(k: Kit) -> void:
	for row in 5:
		for j in 3:
			k.boxc(Vector3(0, 0.05 + row * 0.07, (j - 1) * 0.24), Vector3(2.2, 0.06, 0.22), WOOD_L.lerp(WOOD, 0.25 * ((row + j) % 3)), [])
	k.boxc(Vector3(-0.8, 0.0, 0), Vector3(0.1, 0.05, 0.8), WOOD_D, [])
	k.boxc(Vector3(0.8, 0.0, 0), Vector3(0.1, 0.05, 0.8), WOOD_D, [])


## Козлы с бревном и большой двуручной пилой (пилят двое, по сторонам X)
static func _k_saw(k: Kit) -> void:
	for sz: float in [-0.7, 0.7]:
		k.rod(Vector3(-0.35, 0, sz), Vector3(0.0, 0.85, sz), 0.04, 5, WOOD_D)
		k.rod(Vector3(0.35, 0, sz), Vector3(0.0, 0.85, sz), 0.04, 5, WOOD_D)
	k.rod(Vector3(0, 0.95, -1.2), Vector3(0, 0.95, 1.2), 0.16, 8, WOOD)
	for sz: float in [-1.2, 1.2]:
		k.xf = Transform3D(Basis(Vector3.RIGHT, PI / 2 * signf(sz)), Vector3(0, 0.95, sz))
		k.cyl(Vector3(0, 0, 0), 0.15, 0.015, 8, WOOD_L.lightened(0.15))
		k.xf = Transform3D.IDENTITY
	# полотно пилы поперёк бревна (наклонно), ручки на концах
	k.boxc(Vector3(0, 0.95, 0.15), Vector3(1.5, 0.16, 0.012), Color("b8b8bc"), [])
	for sx: float in [-0.8, 0.8]:
		k.rod(Vector3(sx, 0.85, 0.15), Vector3(sx, 1.12, 0.15), 0.025, 5, WOOD_D)
	# опилки
	k.blob(Vector3(0, 0.03, 0.15), Vector3(0.45, 0.04, 0.35), Color("d8b47a"), 91, 0.1)


## Рама со шкурой: два столба, перекладины, кожа на шнуровке; ширина ~1,6 м, высота ~1,7 м
static func _k_hides(k: Kit) -> void:
	for sx: float in [-0.8, 0.8]:
		k.rod(Vector3(sx, 0, 0), Vector3(sx, 1.75, 0), 0.04, 5, WOOD_D)
	k.rod(Vector3(-0.85, 1.6, 0), Vector3(0.85, 1.6, 0), 0.035, 5, WOOD)
	k.rod(Vector3(-0.85, 0.35, 0), Vector3(0.85, 0.35, 0), 0.035, 5, WOOD)
	var a := Vector3(-0.6, 1.5, 0.0)
	var b2 := Vector3(0.62, 1.48, 0.0)
	var c := Vector3(0.55, 0.45, 0.0)
	var d := Vector3(-0.58, 0.48, 0.0)
	k.quad_out(a, b2, c, d, LEATHER, Vector3(0, 1.0, -0.5))
	k.quad_out(a, b2, c, d, LEATHER_D, Vector3(0, 1.0, 0.5))
	for p: Vector3 in [a, b2, c, d]:
		var q := Vector3(signf(p.x) * 0.8, 1.6 if p.y > 1.0 else 0.35, 0.0)
		k.rod(p, q, 0.008, 3, ROPE)


## Чан с дубильным отваром: деревянная кадка с обручами, внутри тёмная жидкость
static func _k_vat(k: Kit) -> void:
	k.cyl(Vector3(0, 0, 0), 0.5, 0.7, 12, WOOD, 0.55, false)
	k.cyl(Vector3(0, 0.62, 0), 0.52, 0.02, 12, Color("5a3a1e"))
	for y: float in [0.15, 0.5]:
		k.cyl(Vector3(0, y, 0), 0.525 + y * 0.07, 0.05, 12, IRON, -1.0, false)


## Принципия: штаб — большой дом под черепицей с портиком, перед ним площадь, шатёр полководца, значки и орёл
## Храм Марса (Легион 2.0): небольшой храм — черепица, четыре колонны портика, статуя воина на постаменте между
## двумя жаровнями, по бокам знамёна легионов; у портика — жрец
static func _mars(b: Bp) -> void:
	b.paint(-1, false)
	b.roof_tex = "Roof_Tile_06"
	var stone := CatCivic._skin(b, "Building_Large_Brick_01", Color(1.0, 0.93, 0.84))
	b.remap = stone
	var cz := -2.4
	CatCivic._box(b, 0, cz, 3, 2, [
		{0: ["SM_Bld_Wall_01", "SM_Bld_Wall_Door_Double_Large_01", "SM_Bld_Wall_01"], 1: ["SM_Bld_Wall_01", "SM_Bld_Wall_01"],
			2: ["SM_Bld_Wall_01", "SM_Bld_Wall_01", "SM_Bld_Wall_01"], 3: ["SM_Bld_Wall_01", "SM_Bld_Wall_01"]}],
		{"trim": "SM_Bld_Trim_04", "skin": stone, "plain": [1, 2, 3]})
	CatCivic._leaf(b, 0, cz, 3, 2, 1, "SM_Bld_Door_01", 0.05)
	b.remap = stone
	var ridge := CatCivic._gable2(b, -3.75, 3.75, cz - 2.5, cz + 2.5, FL, 1.6)
	b.remap = b.floor_remap(1)
	b.add("SM_Bld_Roof_Topper_01", Vector3(0, ridge - 0.05, cz), 0.0)
	var fz := cz + 2.5
	b.portico(-3.75, 3.75, fz + 1.6, fz, 0.92, "SM_Bld_Pillar_02")
	_sand(b, Vector3(0, 0, fz + 2.9), 8.0, 2.6)
	b.add("SM_Prop_Pillar_Base_02", Vector3(0, 0, fz + 3.0), 0.0, 0.8)
	b.add("SM_Prop_Statue_01", Vector3(0, 0.95, fz + 3.0), 0.0, 0.62)          # воин с копьём и щитом — Марс
	b.brazier(Vector3(-1.4, 0, fz + 2.8))
	b.brazier(Vector3(1.4, 0, fz + 2.8))
	add_kit(b, "#mil_standard", Vector3(-3.4, 0, fz + 3.0), 0.0, 1.15)
	add_kit(b, "#mil_standard", Vector3(3.4, 0, fz + 3.0), 0.0, 1.15)
	b.actor(Vector3(0.8, 0, fz + 2.0), PI, "Spell_Simple_Idle", "rich")
	b.door = Vector3(0, 0, fz + 4.4)


static func _principia(b: Bp) -> void:
	b.paint(-1, false)
	b.roof_tex = "Roof_Tile_06"
	var stone := CatCivic._skin(b, "Building_Large_Brick_01", Color(1.0, 0.95, 0.86))
	b.remap = stone
	var cz := -2.6
	CatCivic._box(b, 0, cz, 3, 2, [
		{0: ["SM_Bld_Wall_Window_06", "SM_Bld_Wall_Door_Double_Large_01", "SM_Bld_Wall_Window_06"], 1: ["SM_Bld_Wall_01", "SM_Bld_Wall_Window_06"],
			2: ["SM_Bld_Wall_01", "SM_Bld_Wall_01", "SM_Bld_Wall_01"], 3: ["SM_Bld_Wall_Window_06", "SM_Bld_Wall_01"]}],
		{"trim": "SM_Bld_Trim_04", "skin": stone, "plain": [2]})
	CatCivic._leaf(b, 0, cz, 3, 2, 1, "SM_Bld_Door_01", 0.05)
	b.remap = stone
	var ridge := CatCivic._gable2(b, -3.75, 3.75, cz - 2.5, cz + 2.5, FL, 1.7)
	b.remap = b.floor_remap(1)
	b.add("SM_Bld_Roof_Topper_01", Vector3(0, ridge - 0.05, cz), 0.0)
	b.on_wall("SM_Prop_Banner_01_A", 0, cz, 3, 2, 0, 0.45, FL + 0.55, 0.12)
	b.on_wall("SM_Prop_Banner_01_A", 0, cz, 3, 2, 0, 2.55, FL + 0.55, 0.12)
	var fz := cz + 2.5
	b.portico(-1.25, 1.25, fz + 1.35, fz, 0.92, "SM_Bld_Pillar_02")
	_sand(b, Vector3(0, 0, fz + 2.3), 8.6, 4.4)
	add_kit(b, "#mil_standard", Vector3(-3.4, 0, fz + 2.4), 0.0, 1.2)
	add_kit(b, "#mil_standard", Vector3(3.4, 0, fz + 2.4), 0.0, 1.2)
	b.add("SM_Prop_Pillar_Base_02", Vector3(0, 0, fz + 3.2), 0.0, 0.7)
	add_kit(b, "#mil_eagle", Vector3(0, 1.05, fz + 3.2), 0.0, 0.6)
	b.brazier(Vector3(-1.9, 0, fz + 1.5))
	b.brazier(Vector3(1.9, 0, fz + 1.5))
	b.actor(Vector3(-2.4, 0, fz + 1.2), 0.0, "Sword_Idle", "soldier")
	b.actor(Vector3(2.4, 0, fz + 1.2), 0.0, "Sword_Idle", "soldier")
	b.door = Vector3(0, 0, fz + 4.3)


# =====================================================================
#   детали новых зданий Легиона (NewMilitary) — в метрах города (ставятся без масштаба Catalog.ARCH)
# =====================================================================

## Частокол: звено 1 м вдоль +X (от 0 до 1), брёвна с заострёнными верхушками на двух поперечинах с внутренней стороны;
## высота ~1,4 м (люди города ~1,1 м)
static func _k_palisade(k: Kit) -> void:
	var n := 6
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in n:
		var x := (i + 0.5) / n
		var h := 1.28 + rng.randf_range(-0.06, 0.08)
		var r := 0.072 + rng.randf_range(-0.008, 0.008)
		var c := Color("6f5034").lerp(Color("57402b"), 0.5 * (i % 2))
		if i % 3 == 2:
			c = c.lerp(Color("8a6a48"), 0.35)
		k.cyl(Vector3(x, 0, 0), r, h, 7, c)
		k.cone(Vector3(x, h, 0), r, 0.17, 7, c.darkened(0.12))
	for y: float in [0.32, 0.98]:
		k.rod(Vector3(0.0, y, -0.1), Vector3(1.0, y, -0.1), 0.035, 5, WOOD_D)


## Палатка контубернии: кожаная, двускатная, полы спереди откинуты треугольником (за ним NewMilitary ставит тёплую
## светящуюся стенку — внутри горит лампа, не тёмная дыра); конёк на шестах, растяжки, колышки. 1,5 × 1,9 × 1,2 м
static func _k_tent2(k: Kit) -> void:
	var hw := 0.75
	var hl := 0.95
	var wall := 0.24
	var top := 1.2
	var inside := Vector3(0, 0.5, 0)
	for sx: float in [-1.0, 1.0]:
		k.quad_out(Vector3(sx * hw, wall, -hl), Vector3(sx * hw, wall, hl), Vector3(0, top, hl), Vector3(0, top, -hl), LEATHER if sx < 0 else LEATHER_D, inside)
		k.quad_out(Vector3(sx * hw, 0, -hl), Vector3(sx * hw, 0, hl), Vector3(sx * hw, wall, hl), Vector3(sx * hw, wall, -hl), LEATHER_D, inside)
		for j in 3:
			var z := -hl + (j + 1) * hl * 2.0 / 4.0
			k.quad_out(Vector3(sx * (hw + 0.004), wall, z - 0.02), Vector3(sx * (hw + 0.004), wall, z + 0.02), Vector3(0, top + 0.004, z + 0.02), Vector3(0, top + 0.004, z - 0.02), LEATHER_D.darkened(0.15), inside)
		# откинутые полы спереди: от угла к коньку, край — скатка
		k.tri_out(Vector3(sx * hw, 0, hl), Vector3(sx * 0.2, 0, hl + 0.01), Vector3(0, top, hl), LEATHER, Vector3(sx * 0.4, 0.4, 0.0))
		k.tri_out(Vector3(sx * hw, 0, hl), Vector3(0, top, hl), Vector3(sx * hw, wall, hl), LEATHER, Vector3(sx * 0.4, 0.3, 0.0))
		k.rod(Vector3(sx * 0.2, 0.02, hl + 0.03), Vector3(sx * 0.02, top - 0.08, hl + 0.03), 0.035, 5, LEATHER_D)
	k.tri_out(Vector3(-hw, wall, -hl), Vector3(hw, wall, -hl), Vector3(0, top, -hl), LEATHER_D, inside)
	k.quad_out(Vector3(-hw, 0, -hl), Vector3(hw, 0, -hl), Vector3(hw, wall, -hl), Vector3(-hw, wall, -hl), LEATHER_D, inside)
	k.rod(Vector3(0, top + 0.02, -hl - 0.08), Vector3(0, top + 0.02, hl + 0.08), 0.03, 5, WOOD)
	k.rod(Vector3(0, 0, hl + 0.05), Vector3(0, top + 0.1, hl + 0.05), 0.025, 5, WOOD)
	k.rod(Vector3(0, 0, -hl - 0.05), Vector3(0, top + 0.1, -hl - 0.05), 0.025, 5, WOOD)
	for sz: float in [-1.0, 1.0]:
		k.rod(Vector3(0, top + 0.08, sz * (hl + 0.05)), Vector3(0, 0.04, sz * (hl + 0.5)), 0.007, 3, ROPE)
		k.boxc(Vector3(0, 0.05, sz * (hl + 0.52)), Vector3(0.04, 0.1, 0.04), WOOD_D)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-0.55, 0.55]:
			k.rod(Vector3(sx * hw, wall, sz), Vector3(sx * (hw + 0.35), 0.03, sz), 0.006, 3, ROPE)


## Трофей (тропей): столб с перекладиной, на нём красная туника, бронзовый панцирь и шлем с гребнем, круглый щит,
## два копья накрест; высота ~1,75 м
static func _k_trophy(k: Kit) -> void:
	k.boxc(Vector3(0, 0.06, 0), Vector3(0.5, 0.12, 0.5), STONE.darkened(0.05))
	k.rod(Vector3(0, 0.1, 0), Vector3(0, 1.45, 0), 0.04, 6, WOOD_D)
	k.rod(Vector3(-0.42, 1.12, 0), Vector3(0.42, 1.12, 0), 0.03, 5, WOOD_D)
	for sx: float in [-1.0, 1.0]:
		k.rod(Vector3(sx * 0.55, 0.1, 0.12), Vector3(-sx * 0.3, 1.72, 0.1), 0.016, 4, WOOD_L)
		k.xf = Transform3D(Basis(Vector3.BACK, sx * -0.5), Vector3(-sx * 0.32, 1.72, 0.1))
		k.cone(Vector3(0, 0, 0), 0.03, 0.14, 4, IRON.lightened(0.2))
		k.xf = Transform3D.IDENTITY
	k.cyl(Vector3(0, 0.62, 0), 0.24, 0.22, 8, RED_D, 0.2)
	k.cyl(Vector3(0, 0.8, 0), 0.2, 0.38, 8, BRONZE, 0.23)
	k.boxc(Vector3(0, 1.0, 0.0), Vector3(0.5, 0.08, 0.26), BRONZE.darkened(0.1))
	k.blob(Vector3(0, 1.3, 0), Vector3(0.13, 0.14, 0.13), BRONZE, 5, 0.06)
	k.boxc(Vector3(0, 1.46, -0.01), Vector3(0.04, 0.12, 0.26), RED)
	k.xf = Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0.0, 0.86, 0.2))
	k.cyl(Vector3(0, 0, 0), 0.24, 0.04, 12, RED)
	k.cyl(Vector3(0, 0.035, 0), 0.07, 0.03, 8, GOLD)
	k.xf = Transform3D.IDENTITY


## Подъёмник мастерской машин: две А-образные ноги, верхний брус 2,6 м (вдоль X) на высоте 2,3 м, блок, канат,
## на нём висит брус ложа; ворот у ноги
static func _k_crane(k: Kit) -> void:
	var y := 2.3
	for sx: float in [-1.15, 1.15]:
		k.rod(Vector3(sx, 0, -0.45), Vector3(sx, y, 0), 0.05, 6, WOOD)
		k.rod(Vector3(sx, 0, 0.45), Vector3(sx, y, 0), 0.05, 6, WOOD)
		k.rod(Vector3(sx, 0.7, -0.33), Vector3(sx, 0.7, 0.33), 0.03, 5, WOOD_D)
	k.rod(Vector3(-1.3, y + 0.04, 0), Vector3(1.3, y + 0.04, 0), 0.07, 6, WOOD_D)
	k.cyl(Vector3(0.2, y - 0.2, 0), 0.08, 0.14, 8, IRON)
	k.rod(Vector3(0.2, y - 0.08, 0), Vector3(0.2, 1.25, 0), 0.01, 3, ROPE)
	k.rod(Vector3(0.2, y - 0.08, 0), Vector3(1.1, 0.75, 0.3), 0.01, 3, ROPE)
	k.boxc(Vector3(0.2, 1.15, 0), Vector3(1.3, 0.14, 0.16), WOOD_L)
	k.rod(Vector3(0.2, 1.25, 0), Vector3(-0.35, 1.22, 0), 0.008, 3, ROPE)
	k.rod(Vector3(0.2, 1.25, 0), Vector3(0.75, 1.22, 0), 0.008, 3, ROPE)
	k.rod(Vector3(1.15, 0.75, 0.25), Vector3(1.15, 0.75, 0.6), 0.06, 8, WOOD)
	for j in 4:
		var a := j * PI / 2.0
		k.rod(Vector3(1.15, 0.75, 0.62), Vector3(1.15, 0.75 + cos(a) * 0.22, 0.62 + sin(a) * 0.05), 0.015, 4, WOOD_D)


## Куча угля: чёрные комья, ~0,8 м
static func _k_coal(k: Kit) -> void:
	var pts := [Vector3(0, 0.12, 0), Vector3(0.22, 0.1, 0.06), Vector3(-0.2, 0.1, 0.08), Vector3(0.04, 0.1, 0.22), Vector3(0.0, 0.1, -0.2), Vector3(0.06, 0.26, 0.02)]
	for i in pts.size():
		var r := 0.11 + (i % 3) * 0.015
		k.blob(pts[i], Vector3(r, r * 0.8, r), Color("2a2624").lerp(Color("4a3a30"), 0.3 * (i % 2)), 90 + i, 0.25)
