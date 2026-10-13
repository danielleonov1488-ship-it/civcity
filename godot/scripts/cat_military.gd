class_name CatMilitary
extends RefCounted
## Облик военных построек Легиона (Казармы, Стрельбище, Лагерь копейщиков, Мастерские баллист и катапульт).
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

static func make(b: Bp, type: String) -> void:
	match type:
		"barracks": _barracks(b)
		"range": _range(b)
		"spearcamp": _spearcamp(b)
		"ballistae": _ballistae(b)
		"catapults": _catapults(b)


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
		_: k.boxc(Vector3(0, 0.5, 0), Vector3.ONE, Color.MAGENTA)
	var m := k.mesh()
	if m.get_surface_count() > 0:
		m.surface_set_material(0, Kit.material(0.9))
	_meshes[name] = m
	return m


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
