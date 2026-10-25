class_name CatStory
extends RefCounted
## Награды историй горожан этапа 7b (Defs.B, unlock «s_…»): бочка с вёдрами (пожар у горшечников), прилавок с пряностями
## и с вином (ярмарка), муза с лирой (роща поэта), корзинка с котятами, стол цензора, ларарий (письмо сыну). Как остальные украшения (CatDecor): родной размер Synty, Catalog уменьшает.

const M := Bp.M


static func make(b: Bp, base: String, lk: int) -> void:
	match base:
		"firebarrel": _firebarrel(b)
		"fairstall": _fairstall(b, lk)
		"muse": _muse(b)
		"kittenbasket": _kittenbasket(b)
		"censortable": _censortable(b)
		"lararium": _lararium(b)


## «Бочка с вёдрами» (награда «Пожар у горшечников»): под навесом на двух столбах — бочка с водой, на перекладине висят
## вёдра, у столба — лестница и багор, на земле — ещё ведро и кувшин. Как у вигилов: вода всегда под рукой
static func _firebarrel(b: Bp) -> void:
	for x: float in [-0.95, 0.95]:
		CatShops._pole(b, Vector3(x, 0, -0.45), 1.95)
	CatDecor._sx(b, "SM_Prop_Overhang_01", Vector3(0, 1.98, -0.55), 0.0, Vector3(0.62, 1.0, 0.75))
	# бочка с водой: широкий чан, сверху — вода
	CatShops._vat(b, Vector3(-0.3, 0, -0.3), CatShops.SKY, 1.15)
	CatShops._vat(b, Vector3(0.55, 0, -0.15), CatShops.SKY, 0.8, 0.6)
	# перекладина с вёдрами (кувшины на крюках)
	CatDecor2._beam(b, Vector3(-0.95, 1.45, -0.45), 1.9, 0.0, 0.45)
	for k in 3:
		b.add("SM_Prop_Jug_03", Vector3(0.25 + k * 0.28, 1.06, -0.43), 0.4 * k, 0.55)
	# лестница у столба, багор, ведро и кувшин на земле
	CatDecor._lean(b, "SM_Prop_Ladder_01", Vector3(1.3, 0, 0.05), 0.0, -0.22, 0.72)
	b.add_xf("SM_Wep_Axe_01", Transform3D(Basis(Vector3.UP, 0.3) * Basis(Vector3.RIGHT, -0.18), Vector3(-1.2, 0.0, -0.25)))
	b.add("SM_Prop_Jug_02", Vector3(0.45, 0, 0.35), 0.6, 0.7)
	b.add("SM_Prop_Bowl_02", Vector3(-0.85, 0, 0.35), 0.0, 0.7)
	CatShops._sign(b, Vector3(0.0, 1.62, -0.36), 0.0, "H", CatShops.RED, 0.42)
	b.add("SM_Env_Grass_01", Vector3(-1.15, 0, 0.55), CatDecor._yaw(b), 0.55)
	b.add("SM_Env_Grass_02", Vector3(1.05, 0, 0.6), CatDecor._yaw(b), 0.5)
	CatDecor._ground_fp(b, 2.4, 1.7)
	b.door = Vector3(0, 0, 1.2)


## Прилавок с ярмарки (награда «Ярмарка в нундины»): полосатый навес над столом. Облик 0 — пряности: корзины с перцем,
## шафраном, корицей и травами на столе и перед ним, мешки; облик 1 — вино: навес в лозе, амфоры и кувшины, чаши для проб
static func _fairstall(b: Bp, lk: int) -> void:
	var c: int = CatShops.ORANGE if lk == 0 else CatShops.PURPLE
	for x: float in [-1.15, 1.15]:
		CatShops._pole(b, Vector3(x, 0, -0.7), 2.3)
		CatShops._pole(b, Vector3(x, 0, 0.7), 2.0)
	CatShops._awning(b, -1.25, 1.25, -0.8, 0.8, 2.35, 1.95, c, CatShops.WHITE)
	b.add("SM_Prop_Table_01", Vector3(0, 0, -0.1), 0.0, 1.0)
	if lk == 0:
		# корзины с пряностями: красный перец, жёлтый шафран, бурая корица, зелёные травы — на столе и перед ним
		var tints := [Color(1.3, 0.32, 0.2), Color(1.3, 1.0, 0.25), Color(0.78, 0.42, 0.2), Color(0.6, 1.0, 0.4)]
		for k in 4:
			_spice(b, Vector3(-0.62 + k * 0.41, 0.78, -0.12 + (0.06 if k % 2 == 0 else -0.05)), tints[k], 0.42)
		_spice(b, Vector3(-0.85, 0, 0.55), tints[2], 0.55)
		_spice(b, Vector3(0.85, 0, 0.5), tints[0], 0.55)
		b.add("SM_Prop_Sack_Stack_01", Vector3(-1.0, 0, -0.55), 0.3, 0.42)
		b.add("SM_Prop_Jar_01", Vector3(0.95, 0, -0.5), 0.0, 0.5)
	else:
		# вино: лоза на навесе, амфоры у столба, кувшин и чаши на столе
		for k in 3:
			CatShops._vine_flat(b, Vector3(-0.8 + k * 0.8, 2.25, -0.7), 0.0, k, 0.48)
		b.add("SM_Prop_Jug_01", Vector3(-0.45, 0.78, -0.12), 0.2, 0.6)
		for k in 3:
			b.add("SM_Prop_Goblet_01", Vector3(0.05 + k * 0.22, 0.78, -0.02 - 0.06 * (k % 2)), 0.0, 0.7)
		b.add("SM_Prop_Vase_Pile_03", Vector3(-0.9, 0, 0.5), CatDecor._yaw(b), 0.55)
		for k in 2:
			b.add("SM_Prop_Jug_03", Vector3(0.75 + k * 0.32, 0, 0.5 - k * 0.2), 0.5 * k, 0.75)
	CatDecor._ground_fp(b, 2.5, 1.8)
	b.door = Vector3(0, 0, 1.25)


## «Муза с лирой» (награда «Роща поэта»): мраморная ступень, постамент, муза в длинных одеждах; у её ног на постаменте —
## золочёная лира, у подножия — свитки, по углам — цветы
static func _muse(b: Bp) -> void:
	CatDecor._slab(b, Vector3.ZERO, Vector3(1.3, 0.14, 1.3))
	b.add("SM_Prop_Plinth_04", Vector3(0, 0.14, 0), 0.0)
	b.add("SM_Prop_Statue_05", Vector3(0, 0.82, 0), 0.0, 1.0)
	b.parts.append(["SM_Prop_Lyre_01", b.base * Transform3D(Basis(Vector3.UP, -0.4) * Basis(Vector3.RIGHT, -0.28) * Basis.from_scale(Vector3.ONE * 0.62), Vector3(0.3, 0.82, 0.24)), {"tint": CatDecor.GILT}])
	b.add("SM_Prop_Scroll_Pile_02", Vector3(-0.42, 0.14, 0.5), 0.4, 0.45)
	CatDecor._bloom(b, Vector3(-0.74, 0, 0.72), 0.26)
	CatDecor._bloom(b, Vector3(0.76, 0, 0.7), 0.24)
	CatDecor._bloom(b, Vector3(0.75, 0, -0.66), 0.2)
	CatDecor._bloom(b, Vector3(-0.72, 0, -0.68), 0.2)
	b.door = Vector3(0, 0, 1.3)

## Корзина с пряностью цвета tint (горка в корзине — как товар у лавок, CatShops._basket)
static func _spice(b: Bp, p: Vector3, tint: Color, s: float) -> void:
	var xf := Transform3D(Basis.from_scale(Vector3.ONE * s), p)
	CatShops._put_xf(b, "SM_Prop_Basket_05", xf)
	CatShops._put_xf(b, "SM_Prop_Basket_Insert_02", xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.29, 0)), {"tint": tint})


## Кошки у украшений (game._pets2): тип → [[кто, где, поворот, движение, масштаб, облик (−1 — всегда), окрас], …]
## «Корзинка с котятами»: в корзинке спит чёрная Мася, вокруг — трое котят (чёрный, серенький, «во фраке»)
const PETS := {
	"kittenbasket": [["cat", Vector3(-0.1, 0.12, 0.0), 0.4, "sleep", 1.0, -1, People.CAT_MASYA],
		["cat", Vector3(0.55, 0, 0.42), 2.4, "sit", 0.55, -1, People.CAT_MASYA], ["cat", Vector3(-0.62, 0, 0.45), -0.6, "sit", 0.55, -1, 1],
		["cat", Vector3(0.2, 0, 0.62), 3.4, "sleep", 0.5, -1, 5]],
}


## «Корзинка с котятами» (награда «Мася и котята»): большая корзина с подушкой, миска молока, клубок и ковёр
static func _kittenbasket(b: Bp) -> void:
	b.add("SM_Env_Grass_01", Vector3(-0.8, 0, -0.5), CatDecor._yaw(b), 0.6)
	b.add("SM_Prop_Basket_11", Vector3(-0.1, 0, 0.0), 0.3, 1.25)
	b.add("SM_Prop_Pillow_06", Vector3(-0.1, 0.08, 0.0), 0.5, 1.0)
	b.add("SM_Prop_Rug_Folded_01", Vector3(0.62, 0, -0.42), 0.4, 0.62)
	b.add("SM_Prop_Bowl_04", Vector3(0.78, 0, 0.0), 0.0, 0.8)
	b.parts.append(["#marble", b.base * Transform3D(Basis.from_scale(Vector3(0.16, 0.02, 0.16)), Vector3(0.78, 0.07, 0.0)), {}])   # молоко
	b.add("SM_Prop_Pillow_03", Vector3(-0.75, 0, 0.0), 0.8, 0.6)
	b.add("SM_Env_Flowers_0%d" % (1 + b.rng.randi() % 5), Vector3(-0.85, 0, 0.62), CatDecor._yaw(b), 1.1)
	CatDecor._ground_fp(b, 2.0, 1.6)
	b.door = Vector3(0, 0, 1.0)


## «Стол цензора» (награда «Перепись»): стол со свитками и табличками, табурет, полка со свитками, знамя с орлом
static func _censortable(b: Bp) -> void:
	b.add("SM_Prop_Table_05", Vector3(0, 0, 0.05), 0.0, 0.9)
	b.add("SM_Prop_Scroll_Pile_03", Vector3(-0.35, 0.74, 0.05), 0.3, 0.5)
	b.add("SM_Prop_Scroll_01", Vector3(0.25, 0.76, 0.12), 1.2, 0.8)
	b.add("SM_Prop_Scroll_Pile_05", Vector3(0.75, 0, 0.45), 0.6, 0.5)
	b.add("SM_Prop_Seat_Stool_01", Vector3(0.05, 0, 0.75), 0.0, 0.85)
	b.add("SM_Prop_Shelf_Scroll_01", Vector3(0, 0, -0.75), 0.0, 0.7)
	b.add("SM_Prop_Shelf_Scroll_01_Insert_01", Vector3(0, 0, -0.75), 0.0, 0.7)
	CatShops._pole(b, Vector3(-1.05, 0, -0.55), 2.2)
	b.add("SM_Prop_Banner_01_C", Vector3(-1.05, 2.0, -0.57), 0.0, 0.6)
	b.parts.append(["SM_Bld_Ornament_09", b.base * Transform3D(Basis.from_scale(Vector3.ONE * 0.6), Vector3(-1.05, 2.3, -0.55)), {"tint": CatDecor.GILT}])
	CatDecor._ground_fp(b, 2.4, 1.9)
	b.door = Vector3(0, 0, 1.2)


## «Ларарий» (награда «Письмо сыну в Легион»): домашний алтарь — мраморная ниша под фронтоном на двух колонках,
## в ней фигурки Ларов, перед нишей — курильница с огоньком (ночью светится), цветы и чаша с подношением
static func _lararium(b: Bp) -> void:
	CatDecor._slab(b, Vector3.ZERO, Vector3(1.1, 0.12, 0.8))
	b.parts.append(["#marble", b.base * Transform3D(Basis.from_scale(Vector3(0.9, 0.55, 0.18)), Vector3(0, 0.12 + 0.55 + 0.275, -0.28)), {}])   # задняя стенка ниши
	b.parts.append(["#marble", b.base * Transform3D(Basis.from_scale(Vector3(0.96, 0.55, 0.42)), Vector3(0, 0.12 + 0.275, -0.18)), {}])      # подножие
	for x: float in [-0.38, 0.38]:
		CatDecor._sx(b, "SM_Bld_Pillar_02", Vector3(x, 0.67, 0.0), 0.0, Vector3(0.14, 0.18, 0.14))
	b.parts.append(["#marble", b.base * Transform3D(Basis.from_scale(Vector3(1.0, 0.08, 0.5)), Vector3(0, 1.26, -0.12)), {}])                 # карниз
	b.parts.append(["#marble", b.base * Transform3D(Basis(Vector3.FORWARD, PI / 4).scaled(Vector3(0.5, 0.5, 0.46)), Vector3(0, 1.3, -0.12)), {}])  # фронтон
	# фигурки Ларов в нише — расписные
	b.parts.append(["SM_Prop_Statue_04", b.base * Transform3D(Basis(Vector3.UP, 0.3).scaled(Vector3.ONE * 0.2), Vector3(-0.17, 0.67, -0.12)), {"tint": Color(1.15, 0.7, 0.5)}])
	b.parts.append(["SM_Prop_Statue_06", b.base * Transform3D(Basis(Vector3.UP, -0.3).scaled(Vector3.ONE * 0.2), Vector3(0.17, 0.67, -0.12)), {"tint": Color(1.15, 0.7, 0.5)}])
	# курильница с огоньком, чаша, цветы
	b.add("SM_Prop_Senser_01", Vector3(0, 0.67, 0.12), 0.0, 0.5)
	CatDecor._fire(b, Vector3(0, 0.83, 0.12), 0.03, 4, 0.04, 0.03)
	b.light(Vector3(0, 0.95, 0.15))
	b.add("SM_Prop_Bowl_01", Vector3(-0.3, 0.67, 0.14), 0.0, 0.3)
	CatDecor._bloom(b, Vector3(-0.48, 0.12, 0.3), 0.14)
	CatDecor._bloom(b, Vector3(0.48, 0.12, 0.3), 0.14)
	b.add("SM_Env_Flowers_0%d" % (1 + b.rng.randi() % 5), Vector3(0.6, 0, 0.52), CatDecor._yaw(b), 1.0)
	b.door = Vector3(0, 0, 1.0)
