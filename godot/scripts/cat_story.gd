class_name CatStory
extends RefCounted
## Награды историй горожан этапа 7b (Defs.B, unlock «s_…»): бочка с вёдрами (пожар у горшечников), прилавок с пряностями
## и с вином (ярмарка), муза с лирой (роща поэта), корзинка с котятами, стол цензора, ларарий (письмо сыну); четвёртая
## партия — курульное кресло (сенатор), Минотавр из самшита (лабиринт), статуя гладиатора (три облика), стол Сатурналий.
## Как остальные украшения (CatDecor): родной размер Synty, Catalog уменьшает.

const M := Bp.M


static func make(b: Bp, base: String, lk: int) -> void:
	match base:
		"firebarrel": _firebarrel(b)
		"fairstall": _fairstall(b, lk)
		"muse": _muse(b)
		"kittenbasket": _kittenbasket(b)
		"censortable": _censortable(b)
		"lararium": _lararium(b)
		"curulechair": _curulechair(b)
		"minotaur": _minotaur(b)
		"gladstatue": _gladstatue(b, lk)
		"saturntable": _saturntable(b)


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


# ---------- четвёртая партия: сенатор, лабиринт, школа гладиаторов, Сатурналии ----------

## «Курульное кресло» (награда «Сенатор проездом»): мраморный помост в две ступени, кресло из слоновой кости на
## скрещённых золочёных ножках с пурпурной подушкой, скамеечка для ног; по бокам — ликторские фасции (пучок прутьев
## с топориком), позади — пурпурный полог на двух столбах и золотой орёл
static func _curulechair(b: Bp) -> void:
	CatDecor._slab(b, Vector3.ZERO, Vector3(2.1, 0.16, 1.7))
	CatDecor._slab(b, Vector3(0, 0.16, -0.12), Vector3(1.4, 0.12, 1.15))
	var y0 := 0.28
	# ножки крест-накрест (брусья Synty — 2,5 м вдоль X): по паре с каждой стороны сиденья
	for z: float in [-0.2, 0.2]:
		for k in 2:
			var ang := PI / 4.0 if k == 0 else 3.0 * PI / 4.0
			var start := Vector3(-0.27 if k == 0 else 0.27, y0, z - 0.1)
			b.parts.append(["SM_Prop_Beam_01", b.base * Transform3D(Basis(Vector3.BACK, ang) * Basis.from_scale(Vector3(0.31, 0.22, 0.22)), start), {"tint": CatDecor.GILT}])
	b.parts.append(["#marble", b.base * Transform3D(Basis.from_scale(Vector3(0.74, 0.07, 0.5)), Vector3(0, y0 + 0.58, -0.1)), {}])
	CatShops._put(b, "SM_Prop_Drapery_01", Vector3(0, y0 + 0.62, 0.15), 0.0, 0.22, CatShops._cloth(CatShops.PURPLE))   # пурпурное покрывало свисает с сиденья
	b.add("SM_Prop_Seat_Stool_01", Vector3(0, 0.16, 0.42), 0.0, 0.55)
	# фасции по бокам: пять прутьев, ремешок и топорик наверху
	for x: float in [-0.88, 0.88]:
		for k in 5:
			var a := k * TAU / 5.0
			CatDecor._sx(b, "SM_Prop_Pole_01", Vector3(x + cos(a) * 0.05, 0.16, -0.15 + sin(a) * 0.05), 0.0, Vector3(0.3, 1.25 / 3.0, 0.3))
		b.parts.append(["#marble", b.base * Transform3D(Basis.from_scale(Vector3(0.16, 0.05, 0.16)), Vector3(x, 0.9, -0.15)), {"tint": Color(0.9, 0.3, 0.25)}])
		b.add_xf("SM_Wep_Axe_01", Transform3D(Basis(Vector3.UP, PI / 2.0 if x < 0.0 else -PI / 2.0) * Basis.from_scale(Vector3.ONE * 0.5), Vector3(x, 1.12, -0.15)))
	# пурпурный полог и орёл
	for x: float in [-0.82, 0.82]:
		CatShops._pole(b, Vector3(x, 0.28, -0.62), 2.05)
	CatDecor2._beam(b, Vector3(-0.88, 2.28, -0.62), 1.76, 0.0, 0.5)
	CatShops._put(b, "SM_Prop_Drapery_01", Vector3(0, 2.26, -0.58), 0.0, 0.55, CatShops._cloth(CatShops.PURPLE))
	b.parts.append(["SM_Bld_Ornament_09", b.base * Transform3D(Basis.from_scale(Vector3.ONE * 0.7), Vector3(0, 2.36, -0.62)), {"tint": CatDecor.GILT}])
	CatDecor._bloom(b, Vector3(-0.95, 0, 0.75), 0.2)
	CatDecor._bloom(b, Vector3(0.95, 0, 0.75), 0.2)
	b.door = Vector3(0, 0, 1.3)


## «Минотавр из самшита» (награда «Лабиринт Тесея»): в мраморной кадке — стриженный из самшита бык-великан: ноги,
## могучая грудь, руки подняты, бычья голова с мордой и рогами; по углам кадки — цветы
static func _minotaur(b: Bp) -> void:
	CatDecor2._box(b, "#marble", Vector3.ZERO, Vector3(1.2, 0.4, 1.2))
	CatDecor._sx(b, "#d2_ball", Vector3(0, 0.34, 0), 0.0, Vector3(1.05, 0.26, 1.05))
	for x: float in [-0.17, 0.17]:
		CatDecor._sx(b, "#d2_ball", Vector3(x, 0.44, 0), 0.0, Vector3(0.27, 0.62, 0.3))      # ноги
	CatDecor._sx(b, "#d2_ball", Vector3(0, 0.92, 0), 0.0, Vector3(0.62, 0.74, 0.46))          # грудь
	for sx: float in [-1.0, 1.0]:
		CatDecor._sx(b, "#d2_ball", Vector3(sx * 0.36, 1.3, 0.02), 0.0, Vector3(0.28, 0.3, 0.28))   # плечи
		b.add_xf("#d2_ball", Transform3D(Basis(Vector3.BACK, sx * 0.4) * Basis.from_scale(Vector3(0.2, 0.5, 0.2)), Vector3(sx * 0.4, 0.92, 0.04)))   # руки в боки
	CatDecor._sx(b, "#d2_ball", Vector3(0, 1.52, 0.06), 0.0, Vector3(0.38, 0.36, 0.44))       # голова
	CatDecor._sx(b, "#d2_ball", Vector3(0, 1.56, 0.28), 0.0, Vector3(0.3, 0.22, 0.24))        # бычья морда
	for sx: float in [-1.0, 1.0]:
		CatDecor._sx(b, "#d2_ball", Vector3(sx * 0.24, 1.74, 0.02), 0.0, Vector3(0.16, 0.09, 0.12))   # уши
		b.add_xf("#d2_cone", Transform3D(Basis(Vector3.BACK, -sx * 0.95) * Basis.from_scale(Vector3(0.3, 0.46, 0.3)), Vector3(sx * 0.17, 1.76, 0.06)))   # рога
	for c: Vector3 in [Vector3(-0.48, 0.4, 0.48), Vector3(0.48, 0.4, 0.48), Vector3(-0.48, 0.4, -0.48), Vector3(0.48, 0.4, -0.48)]:
		CatDecor._bloom(b, c, 0.16)
	b.door = Vector3(0, 0, 1.0)


## «Статуя гладиатора» (награда «Школа гладиаторов»): мраморная ступень и постамент, на нём — воин; у постамента — его
## оружие, золочёное: облик 0 — мирмиллон (большой щит и меч), 1 — ретиарий (трезубец и сеть), 2 — фракиец (малый щит
## и кривой меч); спереди на постаменте — золотой венок победителя, по углам — цветы
static func _gladstatue(b: Bp, lk: int) -> void:
	CatDecor._slab(b, Vector3.ZERO, Vector3(1.2, 0.12, 1.2))
	b.add("SM_Prop_Plinth_04", Vector3(0, 0.12, 0), 0.0)
	b.add("SM_Prop_Statue_01", Vector3(0, 0.8, 0), 0.0, 1.0)
	var gilt := {"tint": CatDecor.GILT}
	match lk:
		0:
			b.parts.append(["SM_Wep_Shield_04", b.base * Transform3D(Basis(Vector3.RIGHT, -0.25) * Basis.from_scale(Vector3.ONE * 0.85), Vector3(0.42, 0.12, 0.5)), gilt])
			b.parts.append(["SM_Wep_Sword_01", b.base * Transform3D(Basis(Vector3.UP, 0.6) * Basis(Vector3.BACK, PI / 2.0) * Basis.from_scale(Vector3.ONE * 0.8), Vector3(-0.42, 0.14, 0.5)), gilt])
		1:
			b.parts.append(["SM_Wep_Spear_03", b.base * Transform3D(Basis(Vector3.BACK, 0.18) * Basis.from_scale(Vector3.ONE * 0.8), Vector3(0.5, 0.12, 0.42)), gilt])
			CatShops._put(b, "SM_Prop_Rug_Folded_02", Vector3(-0.42, 0.12, 0.48), 0.5, 0.5, CatShops._rug("02_A"))
		_:
			b.parts.append(["SM_Wep_Shield_02", b.base * Transform3D(Basis(Vector3.RIGHT, -0.3) * Basis.from_scale(Vector3.ONE * 0.7), Vector3(0.42, 0.12, 0.5)), gilt])
			b.parts.append(["SM_Wep_Sword_03", b.base * Transform3D(Basis(Vector3.UP, -0.5) * Basis(Vector3.BACK, PI / 2.0) * Basis.from_scale(Vector3.ONE * 0.8), Vector3(-0.42, 0.14, 0.5)), gilt])
	b.parts.append(["SM_Chr_Attach_Crown_Leaf_01", b.base * Transform3D(Basis(Vector3.RIGHT, PI / 2.0) * Basis.from_scale(Vector3.ONE * 1.7), Vector3(0, 0.46, 0.36)), gilt])   # венок победителя
	CatDecor._bloom(b, Vector3(-0.66, 0, -0.62), 0.2)
	CatDecor._bloom(b, Vector3(0.66, 0, -0.62), 0.2)
	b.door = Vector3(0, 0, 1.25)


## «Стол Сатурналий» (награда «Сатурналии»): стол со свечами (ночью горят), глиняными фигурками-сигилляриями, орехами
## и сладостями в мисках, кубок; позади — гирлянда из зелени и цветов на двух столбах
static func _saturntable(b: Bp) -> void:
	b.add("SM_Prop_Table_01", Vector3(0, 0, 0), 0.0, 1.0)
	var top := 0.78
	for k in 5:
		var p := Vector3(-0.55 + k * 0.27, top, -0.18 + (0.08 if k % 2 == 0 else -0.04))
		b.parts.append(["#marble", b.base * Transform3D(Basis.from_scale(Vector3(0.05, 0.16 + 0.04 * (k % 3), 0.05)), p + Vector3(0, 0.08 + 0.02 * (k % 3), 0)), {}])
		CatDecor._flame(b, p + Vector3(0, 0.17 + 0.04 * (k % 3), 0), 0.035)
	b.light(Vector3(0, top + 0.45, -0.1))
	var terra := {"tint": Color(1.15, 0.62, 0.42)}
	for e: Array in [["SM_Prop_Statue_04", Vector3(-0.42, top, 0.12)], ["SM_Prop_Statue_05", Vector3(0.05, top, 0.16)], ["SM_Prop_Statue_06", Vector3(0.46, top, 0.1)]]:
		b.parts.append([String(e[0]), b.base * Transform3D(Basis(Vector3.UP, b.rng.randf_range(-0.4, 0.4)) * Basis.from_scale(Vector3.ONE * 0.13), e[1]), terra])
	_spice(b, Vector3(-0.2, top, 0.18), Color(0.75, 0.45, 0.22), 0.36)    # орехи
	_spice(b, Vector3(0.3, top, -0.05), Color(1.25, 0.85, 0.45), 0.34)     # медовые лепёшки
	b.add("SM_Prop_Goblet_01", Vector3(0.62, top, -0.12), 0.0, 0.7)
	for x: float in [-1.1, 1.1]:
		CatShops._pole(b, Vector3(x, 0, -0.62), 1.95)
	b.add("SM_Env_Ivy_Draped_Flowers_01", Vector3(0, 1.82, -0.6), 0.0, 0.62)
	b.add("SM_Env_Ivy_Draped_Flowers_02", Vector3(0.62, 1.86, -0.6), 0.0, 0.5)
	b.add("SM_Env_Ivy_Draped_Flowers_02", Vector3(-0.62, 1.86, -0.6), PI, 0.5)
	CatDecor._ground_fp(b, 2.4, 1.6)
	b.door = Vector3(0, 0, 1.2)
