class_name CatExtra
extends RefCounted
## Новые здания этапа 5 (план 24.10, 5.5–5.6): огород, приют для животных, кукольный театр, травник, пост вигилов,
## мастерская скульптора, дом префекта, нимфей. Чертёж в родных размерах Synty (Catalog уменьшает до Catalog.ARCH),
## фасад к +Z, вход — b.door. Люди при деле (b.actor) — места работников по порядку (People: первым приходит первый).

const M := Bp.M
const FL := Bp.FL

## Животные при здании (game._pets2): тип → [[кто, где, поворот, движение, масштаб, облик (−1 — всегда)], …]
## «Кошачья лавка» (Д14): кошка может носить вещицу — седьмое поле (Defs.CAT_ITEMS); «acc» — вещица на витрине
## (движение — её id), «toy» — клубок на нитке качается под навесом (кошка в «Pet» тянется к нему)
const PETS := {
	"shelter": [["cat", Vector3(1.1, 0.5, -3.25), 2.4, "sleep", 1.0, -1], ["cat", Vector3(2.1, 0.5, -3.25), 0.6, "sleep", 1.0, -1],
		["donkey", Vector3(2.7, 0, -1.9), PI / 2 + 0.2, "Eating", 0.95, -1]],
	"catshop": [["cat", Vector3(1.55, 0.97, 1.5), 0.35, "sit", 1.0, -1, "petasos"], ["cat", Vector3(-2.1, 0.14, 1.0), 2.2, "sleep", 0.9, -1, "bow"],
		["cat", Vector3(-0.45, 0.0, 1.05), 0.1, "pet", 1.0, -1, "collar"], ["cat", Vector3(1.0, 1.62, -0.55), 0.2, "sleep", 0.9, -1, "bandana"],
		["toy", Vector3(-0.45, 2.42, 1.42), 0.0, "", 1.0, -1], ["acc", Vector3(0.75, 1.05, 1.42), 0.4, "pileus", 1.6, -1],
		["acc", Vector3(2.0, 1.02, 1.4), -0.3, "wreath", 1.5, -1], ["acc", Vector3(-0.15, 1.0, -0.55), 0.3, "cape", 1.3, -1],
		["acc", Vector3(-0.85, 1.48, -0.55), 0.0, "flower", 1.8, -1]],
}


static func make(b: Bp, type: String) -> void:
	match type:
		"ogorod": _ogorod(b)
		"shelter": _shelter(b)
		"catshop": _catshop(b)
		"puppets": _puppets(b)
		"herbalist": _herbalist(b)
		"vigiles": _vigiles(b)
		"sculptor": _sculptor(b)
		"prefect": _prefect(b)
		"nymphaeum": _nymphaeum(b)


# ---------- помощники ----------

static func _pole(b: Bp, p: Vector3, h: float, thick := 1.0) -> void:
	CatDecor._sx(b, "SM_Prop_Pole_01", p, 0.0, Vector3(thick, h / 3.0, thick))


## Пугало: шест, перекладина, рубаха, корзина-шляпа
static func _scarecrow(b: Bp, p: Vector3) -> void:
	_pole(b, p, 1.75, 0.6)
	CatDecor2._beam(b, p + Vector3(-0.5, 1.35, 0.0), 1.0, 0.0, 0.5)
	CatShops._sheet(b, p + Vector3(0, 1.38, 0.06), 0.6, 0.75, CatShops.MUSTARD)
	b.add("SM_Prop_Basket_04", p + Vector3(0, 1.72, 0), 0.4, 0.55)


# ---------- огород ----------

## Огород за плетнём: три грядки (капуста, лук, бобы на колышках), сарайчик с инструментом, пугало, корзины и кувшин
## (огородник стоит на коленях у грядки в (−0,9; 0; 0,15))
static func _ogorod(b: Bp) -> void:
	b.paint(9, false)
	b.fence(-2.6, -2.4, 2.6, 2.3)
	_beds(b)
	# сарайчик с инструментом
	for x: float in [1.4, 2.4]:
		_pole(b, Vector3(x, 0, -1.9), 1.7, 0.7)
		_pole(b, Vector3(x, 0, -1.1), 1.5, 0.7)
	CatDecor._sx(b, "SM_Prop_Overhang_01", Vector3(1.9, 1.72, -2.05), 0.0, Vector3(0.45, 1.0, 1.4))
	b.add("SM_Prop_Basket_Backpack_01", Vector3(1.7, 0, -1.6), 0.4, 0.9)
	b.add_xf("SM_Prop_Scythe_01", Transform3D(Basis(Vector3.UP, 0.2) * Basis(Vector3.RIGHT, -0.2), Vector3(2.25, 0.7, -1.75)))
	b.add("SM_Prop_Sack_0%d" % (3 + b.rng.randi() % 3), Vector3(2.1, 0, -1.3), 0.4, 0.7)
	_scarecrow(b, Vector3(1.95, 0, 0.35))
	b.add("SM_Prop_Jug_03", Vector3(-2.15, 0, 1.75), 0.0, 0.8)
	CatShops._basket(b, Vector3(1.3, 0, 1.6), "greens", 0.6)
	CatShops._basket(b, Vector3(1.85, 0, 1.75), "beets", 0.55, 0.6)
	b.actor(Vector3(-0.9, 0, 0.15), PI, "Fixing_Kneeling", "pleb")
	b.door = Vector3(0, 0, 2.9)


## Грядки огорода: земля в дощатых бортиках, капуста, лук рядком, бобы на колышках
static func _beds(b: Bp) -> void:
	for j in 3:
		var z := -1.35 + j * 1.05
		var x0 := -2.1
		var w := 3.0
		CatDecor2._bed(b, w, 0.7, Vector3(x0 + w / 2.0, 0, z))
		for k in 5:
			var x := x0 + 0.35 + k * 0.58
			match j:
				0:
					CatDecor._addr(b, "SM_Env_Crop_Single_02", Vector3(x, 0.08, z), b.rng.randf() * TAU, 0.38, {"tint": Color(0.9, 1.05, 0.75)})
				1:
					CatDecor._addr(b, "SM_Env_Crop_Single_01", Vector3(x, 0.08, z), b.rng.randf() * TAU, 0.42, {})
				_:
					_pole(b, Vector3(x, 0, z), 1.2, 0.4)
					CatDecor._sx(b, "SM_Env_Ivy_Pillar_0%d" % (1 + (k + j) % 3), Vector3(x, 0.05, z), b.rng.randf() * TAU, Vector3(0.28, 0.38, 0.28))


# ---------- приют для животных ----------

## Приют: беленый домик под черепицей, рядом загон за плетнём — сено, корыто с водой, конура; на лавке — корзинки,
## в них спят кошки (game._pets2), в загоне жуёт ослик; миски у порога (смотритель — у мисок)
static func _shelter(b: Bp) -> void:
	b.paint(6, false)
	b.ground_style = "plain"
	b.roof_tex = "Roof_Tile_03"
	b.remap = b.floor_remap(1)
	var cx := -1.6
	var cz := -1.25
	CatCivic._box(b, cx, cz, 1, 1, [{0: ["SM_Bld_Wall_Door_04"], 1: ["SM_Bld_Wall_Window_06"], 3: ["SM_Bld_Wall_Window_06"]}], {"trim": "SM_Bld_Trim_01"})
	CatCivic._leaf(b, cx, cz, 1, 1, 0, "SM_Bld_Door_03")
	var r := CatCivic._gable2(b, cx - 1.25, cx + 1.25, cz - 1.25, cz + 1.25, FL, 1.7, true)
	b.add("SM_Bld_Roof_Topper_01", Vector3(cx, r - 0.04, cz + 1.15), 0.0)
	CatShops._sign(b, Vector3(cx + 0.7, 2.6, 0.14), 0.0, "E", CatShops.SKY, 0.5)
	CatShops._lamp(b, Vector3(cx - 0.75, 2.2, 0.08))
	# загон справа от домика, весь за линией фасада (z ≤ 0): плетень сзади, сбоку и спереди с проходом у домика
	b.add("SM_Env_Fence_Woof_01", Vector3(0.0, 0, -3.8), 0.0, 1.0)
	b.add("SM_Env_Fence_Woof_02", Vector3(2.5, 0, -3.8), 0.0, 0.7)
	b.add("SM_Env_Fence_Woof_03", Vector3(4.25, 0, -3.8), -PI / 2, 1.0)
	b.add("SM_Env_Fence_Woof_01", Vector3(4.25, 0, -1.3), -PI / 2, 0.55)
	b.add("SM_Env_Fence_Woof_02", Vector3(1.65, 0, -0.1), 0.0, 1.04)
	# лавка с корзинками для кошек у заднего плетня
	b.add("SM_Prop_Seat_Bench_03", Vector3(1.6, 0, -3.3), 0.0, 0.9)
	for x: float in [1.1, 2.1]:
		b.add("SM_Prop_Basket_11", Vector3(x, 0.46, -3.25), 0.3, 0.75)
		b.add("SM_Prop_Pillow_06", Vector3(x, 0.5, -3.25), 0.5, 0.6)
	# сено, корыто с водой, конура
	b.add("SM_Prop_Straw_Stack_02", Vector3(3.55, 0, -3.15), 0.3, 0.3)
	CatDecor._sx(b, "SM_Bld_Floor_Trim_02", Vector3(1.0 - 0.155, 0, -1.0 + 0.375), PI / 2, Vector3(0.3, 0.55, 0.3))
	b.parts.append(["#water", b.base * Transform3D(Basis.from_scale(Vector3(0.18, 0.04, 0.62)), Vector3(1.0, 0.22, -1.0)), {}])
	CatDecor2._box(b, "#dark", Vector3(3.55, 0, -1.0), Vector3(0.8, 0.6, 0.7))
	CatDecor._sx(b, "SM_Prop_Overhang_02", Vector3(3.55, 0.95, -1.4), 0.0, Vector3(0.75, 1.0, 1.1))
	CatDecor._sx(b, "SM_Prop_Overhang_02", Vector3(3.55, 0.95, -0.6), PI, Vector3(0.75, 1.0, 1.1))
	# миски у порога
	for x: float in [-1.0, -0.6]:
		b.add("SM_Prop_Bowl_04", Vector3(x, 0, 0.35), 0.0, 0.55)
	b.add("SM_Prop_Sack_0%d" % (3 + b.rng.randi() % 3), Vector3(-2.75, 0, 0.35), 0.5, 0.7)
	b.actor(Vector3(0.6, 0, -0.5), -PI / 2 - 0.4, "Interact", "any")
	b.door = Vector3(cx, 0, 0.9)


# ---------- кошачья лавка (Д14) ----------

## «Кошачья лавка»: розовый домик под черепицей, слева дверь, справа широкий открытый проём с полками; перед ним
## розово-белый навес на столбах, под ним прилавок со шляпками и бантиками на подставках. Кошки (game._pets2): на
## прилавке сидит кошка в соломенной шляпке, в корзинке у двери спит кошка с бантиком, под навесом кошка тянется
## к клубку на нитке, на верхней полке дремлет кошка в венке; миски у порога (хозяйка — за прилавком)
static func _catshop(b: Bp) -> void:
	b.paint(2, false)
	b.ground_style = "plain"
	b.upper_style = "plain"
	b.roof_tex = "Roof_Tile_03"
	b.remap = b.floor_remap(1)
	CatShops._box(b, -2.5, 2.5, -2.5, 0.0, [{0: [CatShops.DOOR, CatShops.SHOP], 1: ["SM_Bld_Wall_Window_03"], 3: ["SM_Bld_Wall_Window_03"],
		2: ["SM_Bld_Wall_Window_03", CatShops.DOOR]}], {"cornice": "SM_Bld_Trim_03", "dark": 1.4})
	var ridge := CatShops._roof_z(b, -2.5, 2.5, -2.5, 0.0, FL, 1.9)
	b.add("SM_Bld_Roof_Topper_05", Vector3(0, ridge, 0.1), 0.0)
	CatShops._chimney(b, Vector3(1.4, FL + 0.55, -1.6))
	CatShops._ivy(b, -2.5, 2.5, -2.5, 0.0, 3, 0.4, 1.3, 2)
	# навес в розовую и белую полоску над входом и прилавком
	CatShops._awning(b, -2.55, 2.55, 0.12, 1.72, 2.8, 2.4, CatShops.PINK, CatShops.WHITE)
	for x: float in [-2.35, 0.0, 2.35]:
		CatShops._pole(b, Vector3(x, 0, 1.58), 2.4)
	CatShops._counter(b, 0.25, 2.2, 1.62)
	# подставки для вещиц на прилавке (сами вещицы и кошки — game._pets2)
	for x: float in [0.75, 2.0]:
		b.add("SM_Prop_Bowl_04", Vector3(x, CatShops.CTR, 1.4), 0.0, 0.5)
	# полки в проёме: корзинки, подушки, клубки шерсти в мисках; на верхней — подушка для кошки
	var c := Vector3(1.25, 0, -0.6)
	b.add("SM_Prop_Shelf_02", c, 0.0, 0.8)
	for j in 4:
		var sl: Vector2 = CatShops.SHELF_SLOTS[j]
		b.add(["SM_Prop_Basket_06", "SM_Prop_Pillow_05", "SM_Prop_Basket_12", "SM_Prop_Pillow_06"][j], c + Vector3(sl.x, sl.y, 0.0), j * 0.7, [0.45, 0.42, 0.5, 0.45][j])
	b.add("SM_Prop_Pillow_06", Vector3(1.0, 1.58, -0.55), 0.3, 0.55)
	# у двери: корзинка-лежанка с подушкой (в ней спит кошка), миски с молоком и рыбкой
	b.add("SM_Prop_Basket_11", Vector3(-2.15, 0, 0.95), 0.3, 0.8)
	b.add("SM_Prop_Pillow_06", Vector3(-2.15, 0.06, 0.95), 0.5, 0.65)
	for x: float in [-0.75, -0.45]:
		b.add("SM_Prop_Bowl_04", Vector3(x, 0, 1.15), 0.0, 0.5)
	CatShops._sign(b, Vector3(-1.25, 2.6, 0.14), 0.0, "H", CatShops.PINK, 0.5)
	CatShops._lamp(b, Vector3(-0.3, 2.15, 0.12))
	b.add("SM_Prop_FlowerPot_Fancy_01", Vector3(2.15, 0, 0.62), 0.0, 0.55)
	b.actor(Vector3(1.25, 0, 0.75), 0.0, "Interact", "any")
	b.door = Vector3(-1.25, 0, 2.3)


# ---------- кукольный театр ----------

## Кукольный театр: ширма на столбах — внизу и сверху занавес, посредине окно сцены с куклами; полосатый навес
## над ширмой, факелы по бокам, скамьи для зрителей, ковёр (кукольник — у ширмы сбоку)
static func _puppets(b: Bp) -> void:
	var pal := CatShops._pal(b)
	var acc: int = CatShops.ACCENT[pal]
	for x: float in [-1.2, 1.2]:
		CatShops._pole(b, Vector3(x, 0, -0.9), 2.6)
		CatShops._pole(b, Vector3(x, 0, -0.1), 2.6)
	# занавес снизу (до окна сцены) и сверху; окно — от 1,25 до 2,05 м
	CatShops._sheet(b, Vector3(0, 1.25, -0.08), 2.4, 1.25, acc)
	CatShops._sheet(b, Vector3(0, 2.55, -0.08), 2.4, 0.5, CatShops.WHITE)
	CatShops._sheet(b, Vector3(0, 2.05, -0.9), 2.4, 2.05, CatShops.PURPLE)
	CatDecor2._beam(b, Vector3(-1.25, 1.25, -0.05), 2.5, 0.0, 0.8)
	CatShops._awning(b, -1.35, 1.35, -1.05, 0.2, 2.75, 2.5, acc, CatShops.WHITE)
	# куклы в окне сцены: рыцарь и купчиха, покрашенные
	b.parts.append(["SM_Prop_Statue_02", b.base * Transform3D(Basis(Vector3.UP, 0.4).scaled(Vector3.ONE * 0.24), Vector3(-0.35, 1.32, -0.15)), {"tint": Color(1.2, 0.55, 0.45)}])
	b.parts.append(["SM_Prop_Statue_06", b.base * Transform3D(Basis(Vector3.UP, -0.5).scaled(Vector3.ONE * 0.22), Vector3(0.35, 1.32, -0.15)), {"tint": Color(0.55, 0.75, 1.2)}])
	for x: float in [-1.55, 1.55]:
		b.add("SM_Prop_Torch_01", Vector3(x, 1.9, -0.05), 0.0, 1.4)
		CatDecor._flame(b, Vector3(x, 2.12, -0.05), 0.08)
		b.light(Vector3(x, 2.35, 0.1))
	CatShops._put(b, "SM_Prop_Rug_0%d" % (1 + pal % 4), Vector3(0, 0.01, 0.9), PI / 2, 0.6, CatShops._rug(["01_A", "01_B", "03_A", "02_B"][pal % 4]))
	for c: Vector3 in [Vector3(-0.8, 0, 1.75), Vector3(0.8, 0, 1.75)]:
		CatShops._put_xf(b, "SM_Prop_Seat_Bench_05", Transform3D(Basis.from_scale(Vector3(0.7, CatShops.SEAT, 0.85)), c))
	b.add("SM_Prop_Basket_10", Vector3(1.75, 0, -0.6), 0.3, 0.55)
	b.actor(Vector3(1.75, 0, 0.25), -0.6, "Spell_Simple_Idle", "any")
	b.door = Vector3(0, 0, 2.5)


# ---------- травник ----------

## Травник: зелёный домик с открытой лавкой и прилавком; под навесом сушатся пучки трав; на полке — банки с мазями;
## у входа — травы в горшках и грядка с мятой (травник — за прилавком)
static func _herbalist(b: Bp) -> void:
	b.paint(5, false)
	b.ground_style = "plain"
	b.roof_tex = "Roof_Tile_12"
	b.remap = b.floor_remap(1)
	var cz := -1.25
	CatCivic._box(b, 0, cz, 2, 1, [{0: ["SM_Bld_Wall_Door_Double_03", "SM_Bld_Wall_Door_04"], 1: ["SM_Bld_Wall_Window_06"], 3: ["SM_Bld_Wall_01"]}], {"trim": "SM_Bld_Trim_02"})
	CatCivic._leaf(b, 0, cz, 2, 1, 1, "SM_Bld_Door_04")
	var ridge := CatCivic._gable2(b, -2.5, 2.5, cz - 1.25, cz + 1.25, FL, 1.6)
	b.add("SM_Bld_Roof_Topper_05", Vector3(0, ridge - 0.05, cz), PI / 2)
	CatCivic._chimney(b, Vector3(1.6, ridge - 0.7, cz - 0.5), 0.8)
	# лавка: прилавок, полка с банками
	var top := CatShops._counter(b, -2.3, -0.2, 0.25, false)
	b.add("SM_Prop_Shelf_02", Vector3(-1.25, 0, -0.55), 0.0, 0.7)
	for k in 4:
		var sl: Vector2 = CatShops.SHELF_SLOTS[k]
		b.add(["SM_Prop_Jar_01", "SM_Prop_Vase_06", "SM_Prop_Jug_05", "SM_Prop_Bowl_04"][k], Vector3(-1.25 + sl.x * 0.9, sl.y * 0.88, -0.55), 0.0, 0.4)
	b.add("SM_Prop_Bowl_06", Vector3(-1.6, top, 0.15), 0.0, 0.45)
	b.add("SM_Prop_Jar_01", Vector3(-0.8, top, 0.15), 0.0, 0.45)
	# навес и пучки трав сохнут на брусе
	b.add("SM_Prop_Overhang_01", Vector3(-2.5, 2.75, 0.14), 0.0, 1.0)
	CatDecor2._beam(b, Vector3(-2.3, 2.3, 0.55), 2.1, 0.0, 0.5)
	for k in 5:
		b.add_xf("SM_Env_Grass_0%d" % (1 + k % 3), Transform3D(Basis(Vector3.RIGHT, PI).scaled(Vector3(0.35, 0.45, 0.35)), Vector3(-2.05 + k * 0.42, 2.3, 0.55)))
	# горшки с травами и грядка мяты у входа
	for x: float in [0.45, 0.95]:
		b.add("SM_Prop_Vase_03", Vector3(x, 0, 0.55), b.rng.randf() * TAU, 0.6)
		CatDecor._addr(b, "SM_Env_Garden_Plants_0%d" % [1, 5][int(x > 0.6)], Vector3(x, 0.5, 0.55), b.rng.randf() * TAU, 0.3, {})
	for k in 2:
		b.add("SM_Prop_Vase_06", Vector3(2.0 + k * 0.4, 0, 0.35), b.rng.randf() * TAU, 0.55)
		CatDecor._addr(b, "SM_Env_Garden_Plants_0%d" % [2, 7][k], Vector3(2.0 + k * 0.4, 0.32, 0.35), b.rng.randf() * TAU, 0.22, {})
	CatShops._sign(b, Vector3(1.25, 2.55, 0.14), 0.0, "C", CatShops.GREEN, 0.5)
	b.actor(Vector3(-1.25, 0, -0.05), 0.0, "Interact", "any")
	b.door = Vector3(1.25, 0, 0.9)


# ---------- пост вигилов ----------

## Пост вигилов: терракотовый дом с большими воротами (там бочка на колёсах), у стены лестницы, вёдра, топор и крюк,
## бочки с водой; сбоку — дозорная вышка с жаровней (ночью видно издалека). Вигилы — у ворот и у бочек
static func _vigiles(b: Bp) -> void:
	b.paint(1, false)
	b.ground_style = "brick"
	b.roof_tex = "Roof_Tile_01"
	b.remap = b.floor_remap(1)
	var cz := -1.4
	CatCivic._box(b, -1.25, cz, 2, 1, [{0: ["SM_Bld_Wall_Door_Large_01", "SM_Bld_Wall_Window_06"], 1: ["SM_Bld_Wall_01"], 3: ["SM_Bld_Wall_Window_06"]}], {"trim": "SM_Bld_Trim_04"})
	var ridge := CatCivic._gable2(b, -3.75, 1.25, cz - 1.25, cz + 1.25, FL, 1.5)
	b.add("SM_Bld_Roof_Topper_03", Vector3(-1.25, ridge - 0.05, cz), PI / 2, 0.8)
	var fz := cz + 1.25
	# в воротах — бочка на колёсах (водовозка)
	b.add("SM_Prop_Cart_01", Vector3(-2.5, 0, fz - 0.9), PI / 2 + 0.05, 0.62)
	CatShops._vat(b, Vector3(-2.5, 0.55, fz - 0.95), CatShops.SKY, 0.75)
	# у стены: лестницы, вёдра, топор и крюк, бочки
	CatDecor._lean(b, "SM_Prop_Ladder_01", Vector3(-0.55, 0, fz + 0.18), 0.0, -0.22, 0.85)
	CatDecor._lean(b, "SM_Prop_Ladder_01", Vector3(0.15, 0, fz + 0.15), 0.0, -0.2, 0.7)
	b.add_xf("SM_Wep_Axe_01", Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(0.75, 0.0, fz + 0.12)))
	for k in 4:
		b.add("SM_Prop_Jug_03", Vector3(-3.4 + k * 0.32, 0, fz + 0.35), b.rng.randf() * TAU, 0.6)
	for x: float in [0.9, 1.45]:
		CatShops._vat(b, Vector3(x, 0, fz + 0.55), CatShops.SKY, 0.65, x)
	CatShops._sign(b, Vector3(0.0, 2.6, fz + 0.14), 0.0, "H", CatShops.RED, 0.55)
	CatShops._lamp(b, Vector3(-3.2, 2.2, fz + 0.08))
	# дозорная вышка справа: четыре столба, помост, перила, жаровня с огнём, навес
	var tx := 2.75
	var tz := -1.0
	var ph := 3.0
	for c: Vector2 in [Vector2(-0.6, -0.6), Vector2(0.6, -0.6), Vector2(-0.6, 0.6), Vector2(0.6, 0.6)]:
		_pole(b, Vector3(tx + c.x, 0, tz + c.y), ph + 1.6, 1.0)
	b.add("SM_Bld_Trellis_Roof_01", Vector3(tx - 0.75, ph, tz - 0.75), 0.0, 0.6)
	for z: float in [tz - 0.62, tz + 0.62]:
		CatDecor2._beam(b, Vector3(tx - 0.65, ph + 0.75, z), 1.3, 0.0, 0.5)
	CatDecor._lean(b, "SM_Prop_Ladder_01", Vector3(tx - 0.2, 0, tz + 0.8), 0.0, -0.22, 1.1)
	b.add("SM_Prop_Brazier_03", Vector3(tx, ph + 0.05, tz), 0.0, 0.55)
	b.add("SM_Prop_Brazier_03_Insert_01", Vector3(tx, ph + 0.05, tz), 0.0, 0.55)
	CatDecor._fire(b, Vector3(tx, ph + 0.52, tz), 0.06, 5, 0.07, 0.045)
	b.light(Vector3(tx, ph + 0.8, tz))
	b.smoke.append(Vector3(tx, ph + 0.9, tz))
	CatDecor._sx(b, "SM_Prop_Overhang_01", Vector3(tx, ph + 1.62, tz - 0.8), 0.0, Vector3(0.6, 1.0, 1.25))
	CatDecor._sx(b, "SM_Prop_Overhang_01", Vector3(tx, ph + 1.62, tz + 0.8), PI, Vector3(0.6, 1.0, 1.25))
	b.actor(Vector3(-2.5, 0, fz + 0.7), 0.0, "Idle", "pleb")
	b.actor(Vector3(1.2, 0, fz + 1.1), PI + 0.5, "Interact", "pleb")
	b.door = Vector3(-1.25, 0, fz + 1.3)


# ---------- мастерская скульптора ----------

## Мастерская скульптора: двор за низкой каменной стенкой, под навесом — верстак с резцами; глыбы и штабель мрамора,
## статуя в лесах, вторая — почти готова, готовая — на постаменте у входа (мастера — у статуй)
static func _sculptor(b: Bp) -> void:
	b.paint(9, false)
	b.ground_style = "plain"
	b.roof_tex = "Roof_Tile_03"
	b.remap = b.floor_remap(1)
	# мастерская-навес у задней стенки: стена, черепичный скат на столбах
	b.add("SM_Bld_Wall_01", Vector3(-3.75, 0, -2.7), 0.0, 1.0, true)
	b.add("SM_Bld_Wall_Window_06", Vector3(-1.25, 0, -2.7), 0.0, 1.0, true)
	CatCivic._shed(b, -3.75, 1.25, -1.2, -2.7, 2.6, "SM_Bld_Pillar_06", 0.8, true, 0.85)
	# низкая каменная стенка вокруг двора; спереди — с проходом посередине (по ней — линия фасада)
	var low := {"Stucco_White_01": "Brick_Grey_Tex"}
	for sx: float in [-1.0, 1.0]:
		b.parts.append(["SM_Bld_Wall_01", b.base * Transform3D(Basis(Vector3.UP, PI / 2).scaled_local(Vector3(1.85, 0.3, 1.0)), Vector3(sx * 3.85, 0, 2.1)), low.duplicate()])
		b.parts.append(["SM_Bld_Wall_01", b.base * Transform3D(Basis.IDENTITY.scaled_local(Vector3(1.1, 0.3, 1.0)), Vector3(-3.85 if sx < 0.0 else 1.1, 0, 2.1)), low.duplicate()])
	b.add("SM_Prop_Table_05", Vector3(-2.6, 0, -1.8), PI / 2, 0.95)
	for e: Array in [["SM_Prop_Tool_Hammer_01", Vector3(-2.9, 0.75, -1.85)], ["SM_Prop_Tool_Chisel_01", Vector3(-2.55, 0.75, -1.7)], ["SM_Prop_Tool_Compass_01", Vector3(-2.2, 0.75, -1.9)]]:
		b.add_xf(e[0], Transform3D(Basis(Vector3.UP, b.rng.randf() * TAU), e[1]))
	b.add("SM_Prop_Marble_Stack_01", Vector3(1.6, 0, -1.9), 0.0, 0.42)
	# статуя в лесах и почти готовая
	b.add("SM_Prop_Statue_Unfinished_01", Vector3(-0.6, 0, -0.4), 0.2, 0.9)
	for x: float in [-1.35, 0.15]:
		_pole(b, Vector3(x, 0, -0.85), 2.4, 0.7)
	CatDecor2._beam(b, Vector3(-1.45, 1.3, -0.85), 1.7, 0.0, 0.6)
	CatDecor2._beam(b, Vector3(-1.45, 2.3, -0.85), 1.7, 0.0, 0.6)
	b.add("SM_Prop_Statue_Unfinished_02", Vector3(1.6, 0, -0.3), -0.4, 0.95)
	b.add("SM_Prop_Marble_Block_01", Vector3(2.7, 0, 0.6), 0.6, 0.6)
	b.add("SM_Prop_Marble_Block_03", Vector3(-2.6, 0, 0.7), -0.3, 0.6)
	b.add("SM_Prop_Marble_Rubble_07", Vector3(0.6, 0, 0.5), b.rng.randf() * TAU, 0.6)
	b.add("SM_Prop_Marble_Rubble_04", Vector3(-1.4, 0, 0.75), b.rng.randf() * TAU, 0.45)
	# готовая статуя у входа
	b.add("SM_Prop_Plinth_04", Vector3(3.0, 0, 1.45), 0.0, 0.85)
	b.add("SM_Prop_Statue_06", Vector3(3.0, 0.58, 1.45), -0.3, 0.7)
	CatShops._sign(b, Vector3(-0.0, 2.25, -0.85), 0.0, "E", CatShops.WHITE, 0.5)
	b.actor(Vector3(-0.6, 0, 0.45), PI, "Interact", "any")
	b.actor(Vector3(1.0, 0, 0.35), PI - 0.6, "Interact", "any")
	b.door = Vector3(0, 0, 2.8)


# ---------- дом префекта ----------

## Дом префекта: белый двухэтажный дом с красным цоколем, портик в четыре колонны с фронтоном, у дверей — фасции
## (пучок прутьев с топором), знамёна, статуи на постаментах у ступеней, фонари, кипарисы в кадках
static func _prefect(b: Bp) -> void:
	b.paint(6, false)
	b.ground_style = "pattern"
	b.upper_style = "plain"
	b.roof_tex = "Roof_Tile_01"
	b.remap = b.floor_remap(1)
	var cz := -2.0
	CatCivic._box(b, 0, cz, 3, 2, [
		{0: ["SM_Bld_Wall_Window_05", "SM_Bld_Wall_Door_Large_02", "SM_Bld_Wall_Window_05"], 1: ["SM_Bld_Wall_Window_06", "SM_Bld_Wall_01"], 2: [], 3: ["SM_Bld_Wall_01", "SM_Bld_Wall_Window_06"]},
		{0: ["SM_Bld_Wall_Window_04", "SM_Bld_Wall_Window_02", "SM_Bld_Wall_Window_04"], 1: ["SM_Bld_Wall_Window_04", "SM_Bld_Wall_Window_04"], 2: [], 3: ["SM_Bld_Wall_Window_04", "SM_Bld_Wall_Window_04"]}],
		{"trim": "SM_Bld_Trim_04"})
	CatCivic._leaf(b, 0, cz, 3, 2, 1, "SM_Bld_Door_01", 0.05)
	var ridge := CatCivic._hip(b, -3.75, 3.75, cz - 2.5, cz + 2.5, 2 * FL, 1.4)
	b.add("SM_Bld_Roof_Topper_04", Vector3(0, ridge - 0.05, cz), 0.0, 0.9, true)
	var fz := cz + 2.5
	CatCivic._marble(b, Vector3(0, 0, fz + 0.75), Vector3(5.2, 0.16, 1.6))
	CatCivic._pediment(b, -2.0, 2.0, fz + 1.35, fz, "SM_Bld_Pillar_02", 3.0, 0.82, 4, 1.0, 0.16)
	# фасции у дверей: пучок прутьев с топором
	for sx: float in [-1.0, 1.0]:
		var p := Vector3(sx * 0.95, 0.16, fz + 0.2)
		for k in 5:
			CatDecor._sx(b, "SM_Prop_Pole_01", p + Vector3(cos(k * 1.26) * 0.05, 0, sin(k * 1.26) * 0.05), 0.0, Vector3(0.25, 0.55, 0.25), {"tint": Color(0.75, 0.55, 0.35)})
		b.add_xf("SM_Wep_Axe_01", Transform3D(Basis(Vector3.UP, sx * 0.3), p + Vector3(0, 0.95, 0.05)))
		CatShops._sign(b, Vector3(sx * 2.5, 2.7, fz + 0.14), 0.0, "D", CatShops.RED, 0.62)
		b.add("SM_Prop_Plinth_04", Vector3(sx * 3.1, 0, fz + 1.1), 0.0, 0.85)
		b.add(["SM_Prop_Statue_04", "SM_Prop_Statue_02"][int(sx > 0.0)], Vector3(sx * 3.1, 0.58, fz + 1.1), 0.0, 0.62)
		CatCivic._lamp_post(b, Vector3(sx * 2.4, 0.16, fz + 1.4), 0.0 if sx > 0.0 else PI)
		CatCivic._cypress(b, Vector3(sx * 3.4, 0, cz - 1.0), 0.5)
	CatCivic._hanging_lamp(b, Vector3(0, 2.62, fz + 0.75), 0.55)
	b.actor(Vector3(-0.8, 0.16, fz + 0.95), 0.4, "Idle", "rich")
	b.actor(Vector3(0.9, 0.16, fz + 1.1), -0.6, "Idle", "rich")
	b.door = Vector3(0, 0, fz + 2.1)


# ---------- нимфей ----------

## Нимфей: мраморная стена в три ниши (в каждой — статуя), между нишами колонны, сверху карниз и фронтон, из львиных
## масок бьют струи в длинный бассейн; по краям — кипарисы, вазоны и жаровни
static func _nymphaeum(b: Bp) -> void:
	b.paint(6, false)
	var marble := CatCivic._skin(b, "Building_Marble_01")
	var wz := -1.6
	CatCivic._marble(b, Vector3(0, 0, wz - 0.25), Vector3(8.6, 0.14, 1.3))
	for i in 3:
		b.remap = marble
		b.add("SM_Bld_Wall_Alcove_01", Vector3(-3.75 + i * M, 0.14, wz), 0.0, 1.0, true)
		b.add("SM_Bld_Wall_Tiny_01", Vector3(-3.75 + i * M, 3.14, wz), 0.0, 1.0, true)
		b.add(["SM_Prop_Statue_03", "SM_Prop_Statue_04", "SM_Prop_Statue_06"][i], Vector3(-2.5 + i * M, 0.14 + 0.5, wz - 0.25), 0.0, 0.62)
	b.remap = marble
	Catalog._trim_run(b, Vector3(-3.95, 3.62, wz + 0.15), Vector3(1, 0, 0), 7.9)
	for i in 4:
		b.add("SM_Bld_Pillar_02", Vector3(-3.75 + i * M, 0.14, wz + 0.45), 0.0, 1.05)
	# фронтон над серединой
	b.add("SM_Bld_Ornament_04", Vector3(0, 3.95, wz + 0.3), 0.0, 0.9)
	b.remap = b.floor_remap(1)
	# бассейн перед стеной; струи из львиных масок
	CatCivic._pool(b, -3.75, 3.75, wz + 0.6, wz + 3.1, false)
	for i in 3:
		var x := -2.5 + i * M
		b.add("SM_Prop_Marble_LionHead_01", Vector3(x, 1.0, wz + 0.62), 0.0, 0.5)
		b.parts.append(["#water", b.base * Transform3D(Basis.from_scale(Vector3(0.06, 0.62, 0.06)), Vector3(x, 0.55, wz + 0.82)), {}])
	b.add("SM_Env_Lillies_01", Vector3(-1.2, 0.08, wz + 1.9), 0.4, 0.6)
	b.add("SM_Env_Lillies_02", Vector3(1.6, 0.08, wz + 2.3), 2.0, 0.5)
	for sx: float in [-1.0, 1.0]:
		CatCivic._cypress(b, Vector3(sx * 4.3, 0, wz + 0.4), 0.55)
		b.add_xf("SM_Bld_Pillar_06", Transform3D(Basis.from_scale(Vector3(0.75, 0.3, 0.75)), Vector3(sx * 4.2, 0, wz + 3.05)))
		CatMonuments._pot(b, Vector3(sx * 4.2, 0.9, wz + 3.05), 0.55)
		b.add("SM_Env_Ivy_Pillar_Flowers_0%d" % (1 + b.rng.randi() % 3), Vector3(sx * 3.75, 0.14, wz + 0.45), b.rng.randf() * TAU, 1.0)
	b.door = Vector3(0, 0, wz + 4.0)
