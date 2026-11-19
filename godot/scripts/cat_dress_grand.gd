class_name CatDressGrand
extends RefCounted
## Наполнение военных зданий Легиона, почтовой станции, памятников и больших зданий деталями Synty (владелец 12.11:
## «давай дальше переделывай все модельки!» — каждое здание живое и подробное, как на картинках Synty POLYGON
## Ancient Empire, и при этом быстрое на слабых компьютерах).
## Работает на тех же правилах, что CatDressCivic (кучки проверяются целиком: на участке, ни во что не врезаются, вход,
## дорожка и люди при деле свободны, след и правила постановки прежние), и берёт оттуда кучки, стены и крыши.
## Свои правила:
##  - здания Легиона растут с уровнем (CatMilitary._grow: значки, жаровни, орёл, портик, статуя, знамёна на фасаде) —
##    места прибавок заняты заранее, а случай не зависит от уровня: на всех уровнях наполнение одно и то же;
##  - почтовая станция, амфитеатр, цирк, театр, одеон, пантеон и другие неровные и круглые — только там, где земля
##    занята следом (Bp.footprint): ни соседний дом, ни ждущие на площади семьи, ни прохожие туда не встанут;
##  - на трибуны и сцену ничего не ставим: места зрителей (Spectacle) те же.
## Только детали, что и так есть в городе; огней и дыма не добавляем (жаровни — без света).

const MIL := ["barracks", "range", "spearcamp", "ballistae", "catapults", "forge", "infirmary", "armory", "smelter", "sawmill",
	"tannery", "principia", "mars"]
const GRAND := ["center", "colosseum", "circus_fl", "theatre", "odeon", "pantheon", "venus", "arch", "fountain", "pharos", "nymphaeum", "aqua", "trajan", "circus", "aqueduct", "caracalla", "jupiter"]
const REBUILT := ["trajan", "circus", "aqueduct", "caracalla", "jupiter"]
const CIRCUS_TURN := 11.25
const CIRCUS_SAND_RADIUS := 4.19
const GABLE_MARBLE := {"Stone_01": "Building_Marble_02"}
const CORNICE_MARBLE := {"PolygonAncientEmpire_01_A": "Building_Marble_02"}
const GABLE_FRIEZE := {"PolygonAncientEmpire_01_A": "Stucco_Red_01", "tints": {"Stucco_Red_01": Color(0.64, 0.39, 0.31)}}
## Выключатель для проверок «было/стало» (вместе с CatDressCivic.ON)
static var ON := true


static func handles(type: String) -> bool:
	return ON and (type in MIL or type in GRAND)


static func dress(b: Bp, type: String, tier := 0) -> void:
	if type in REBUILT:
		return                                 # вся новая сборка уже сделана в Catalog.make
	var x := CatDressCivic._ctx(b, type)
	if type in MIL:
		(x["rng"] as RandomNumberGenerator).seed = hash(["mil", type])      # одно и то же на всех уровнях здания
		_reserve_grow(x, type)
		_mil(x, type)
	else:
		_grand(x, type, tier)
	b._fp.clear()


# =====================================================================
#   общее: кучки Легиона
# =====================================================================

## Прислонённое к стене (стена — за −Z): верх наклонён к стене на tilt, низ — на земле
static func _lean(nm: String, s: float, tilt: float, off := Vector3.ZERO, yaw := 0.0) -> Array:
	var bas := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -tilt) * Basis.from_scale(Vector3.ONE * s)
	var bx := Bp.model_aabb(nm)
	var lo := INF
	for i in 8:
		lo = minf(lo, (bas * bx.get_endpoint(i)).y)
	return [nm, Transform3D(bas, off + Vector3(0, -lo, 0)), {}]


## Стоящее на земле (низ модели — на земле)
static func _stand(nm: String, s: float, yaw := 0.0, off := Vector3.ZERO, rm := {}) -> Array:
	var bx := Bp.model_aabb(nm)
	return [nm, Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * s), off + Vector3(0, -bx.position.y * s, 0)), rm]


## Кучка Легиона по имени (лицом к +Z, к стене — задом, длинная сторона вдоль X); иначе — кучка CatDressCivic
static func _mi(x: Dictionary, key: String) -> Array:
	var C := CatDressCivic
	match key:
		"spears":                                  # три копья, прислонённые к стене
			var out := []
			for k in 3:
				out.append(_lean("SM_Wep_Spear_02", 0.9, C._rf(x, 0.11, 0.16), Vector3((k - 1) * 0.16, 0, 0.34 + C._rf(x, -0.02, 0.02)), C._rf(x, -0.3, 0.3)))
			return out
		"shields2":                                # скутум и круглый щит у стены, один перед другим
			return [_lean("SM_Wep_Shield_04", 0.72, 0.22, Vector3(-0.2, 0, 0.12)),
				_lean("SM_Wep_Shield_0%d" % C._one(x, [1, 3]), 0.62, 0.3, Vector3(0.28, 0, 0.26), C._rf(x, -0.2, 0.2))]
		"shieldS":                                 # тонкое — для боков: два скутума в ряд
			return [_lean("SM_Wep_Shield_04", 0.7, 0.2, Vector3(-0.27, 0, 0.12)), _lean("SM_Wep_Shield_04", 0.7, 0.24, Vector3(0.27, 0, 0.14), 0.1)]
		"shieldstack":                             # стопка скутумов у стены (каждый — перед прежним)
			var out := []
			for k in 3:
				out.append(_lean("SM_Wep_Shield_04", 0.72, 0.18 + k * 0.03, Vector3(k * 0.06, 0, 0.12 + k * 0.13), C._rf(x, -0.08, 0.08)))
			return out
		"helmbench":                               # скамья, на ней шлемы
			var hb := Bp.model_aabb("SM_Chr_Attach_Helmet_01")
			var top := Bp.model_aabb("SM_Prop_Seat_Bench_01").end.y * 0.85
			return [_it("SM_Prop_Seat_Bench_01", 0.85), _it("SM_Chr_Attach_Helmet_01", 0.95, C._rf(x, -0.4, 0.4) + PI, Vector3(-0.38, top - hb.position.y * 0.95, 0)),
				_it("SM_Chr_Attach_Helmet_01", 0.95, C._rf(x, -0.4, 0.4) + PI, Vector3(0.3, top - hb.position.y * 0.95, 0.02))]
		"supplyM":                                 # припасы: мешки, амфора, корзина
			return C._item(x, String(C._one(x, ["store", "sacks", "amphpile", "jarpile"])))
		"brazier":                                 # жаровня с углями (без света: огонь — только у прибавок уровня)
			return [_it("SM_Prop_Brazier_03", 0.95), _it("SM_Prop_Brazier_03_Insert_01", 0.95)]
		"standard":                                # значок легиона
			return [_it("#mil_standard", 1.0)]
		"bannerpole":                              # знамя на шесте
			return [_it("SM_Prop_Pole_02", 0.95), _it("SM_Prop_Banner_03_A", 0.62, 0.0, Vector3(0, 2.75, 0.1))]
		"quivers":                                 # корзины со стрелами
			return [_it("#mil_quiver", 0.9, C._rf(x, 0.0, TAU), Vector3(-0.22, 0, 0)), _it("#mil_quiver", 0.8, C._rf(x, 0.0, TAU), Vector3(0.3, 0, 0.04))]
		"strawT":                                  # снопы соломы для мишеней и запасная мишень у стены
			return [_lean("#mil_target", 0.8, 0.18, Vector3(0, 0, 0.3)), _it("SM_Prop_Straw_Bundle_01", 0.55, C._rf(x, 0.0, TAU), Vector3(0.75, 0, 0.1))]
		"anvil":                                   # наковальня с молотом на колоде
			var top := Bp.model_aabb("SM_Prop_Anvil_01").end.y * 0.8
			return [_it("SM_Prop_Anvil_01", 0.8, C._rf(x, -0.3, 0.3)), _it("SM_Prop_Tool_Hammer_01", 1.0, C._rf(x, 0.0, TAU), Vector3(0.05, top + 0.02, 0.0))]
		"ingots":                                  # бруски железа и мешок угля
			return [_it("#mil_ingots", 1.0, C._rf(x, -0.3, 0.3)), _it("SM_Prop_Sack_04", 0.8, C._rf(x, -0.3, 0.3), Vector3(0.62, 0, 0.0))]
		"stones":                                  # каменные ядра
			return [_it("#mil_stones", 0.85, C._rf(x, 0.0, TAU))]
		"bandage":                                 # корзины с полотном для перевязок и кувшины
			return [_it("SM_Prop_Basket_Set_04", 0.62, C._rf(x, -0.2, 0.2)), _it("SM_Prop_Basket_Set_04_Insert_01", 0.62, 0.0),
				_it("SM_Prop_Jug_03", 0.6, PI, Vector3(0.68, 0, 0.0))]
		"bandageS":                                # тонкое — для боков: корзина с полотном и кувшин
			return [_it("SM_Prop_Basket_06", 0.66, 0.0), _it("SM_Prop_Basket_Insert_02", 0.66, 0.0), _it("SM_Prop_Jug_03", 0.62, PI, Vector3(0.45, 0, 0.0))]
		"offer":                                   # дары богу: корзина фруктов, ваза с цветами, курильница
			return [_it("SM_Prop_Vase_03", 0.6, C._rf(x, 0.0, TAU), Vector3(-0.42, 0, 0)),
				_it(String(C._one(x, C.BLOOM)), 0.22, C._rf(x, 0.0, TAU), Vector3(-0.42, 0.35, 0), {"tint": CatDecor.TRUE_COLOR}),
				_it("SM_Prop_Senser_04", 1.0, 0.0, Vector3(0.12, 0, 0.05))] + _shift(C._item(x, "apples"), Vector3(0.62, 0, 0))
		"luggage":                                 # багаж приезжих: короб с крышкой, скатка, мешок, заплечная корзина
			var bt := Bp.model_aabb("SM_Prop_Basket_02").end.y * 0.8
			return [_it("SM_Prop_Basket_02", 0.8, C._rf(x, -0.2, 0.2), Vector3(-0.4, 0, 0)), _it("SM_Prop_Basket_Lid_01", 0.8, C._rf(x, -0.2, 0.2), Vector3(-0.4, bt - 0.02, 0)),
				_it("SM_Prop_Rug_Folded_02", 0.5, C._rf(x, -0.3, 0.3), Vector3(-0.4, bt + 0.06, 0)), _it("SM_Prop_Sack_03", 0.8, C._rf(x, -0.4, 0.4), Vector3(0.2, 0, 0.02)),
				_it("SM_Prop_Basket_Backpack_01", 0.85, C._rf(x, 0.2, 0.6), Vector3(0.68, 0, 0.04))]
		"luggS":                                   # тонкое — для боков: мешок и заплечная корзина
			return [_it("SM_Prop_Sack_03", 0.75, C._rf(x, -0.4, 0.4), Vector3(-0.2, 0, 0)), _it("SM_Prop_Basket_Backpack_01", 0.75, C._rf(x, -0.2, 0.2), Vector3(0.24, 0, 0.0))]
		"armsoffer":                               # трофейное оружие в дар: щиты у стены, шлем на земле
			var hb := Bp.model_aabb("SM_Chr_Attach_Helmet_01")
			return [_lean("SM_Wep_Shield_04", 0.7, 0.22, Vector3(-0.15, 0, 0.12)), _lean("SM_Wep_Shield_03", 0.58, 0.3, Vector3(0.35, 0, 0.24), 0.2),
				_it("SM_Chr_Attach_Helmet_01", 0.95, 0.4 + PI, Vector3(0.0, -hb.position.y * 0.95, 0.5))]
	return C._item(x, key)


## Сдвинуть кучку
static func _shift(items: Array, d: Vector3) -> Array:
	var out := []
	for it: Array in items:
		out.append([it[0], Transform3D(Basis.IDENTITY, d) * (it[1] as Transform3D), it[2] if it.size() > 2 else {}])
	return out


## Разложить вдоль стен (как CatDressCivic._along) — с кучками Легиона
static func _along(x: Dictionary, sides: Array, pal: Array, dens := 0.6, max_n := 99) -> int:
	# CatDressCivic._along берёт кучки из CatDressCivic._item: свои кучки подменяем на время (ключ «@имя»)
	x["mi"] = true
	var n := CatDressCivic._along(x, sides, pal, dens, max_n)
	x.erase("mi")
	return n


## Поставить кучку key в точку p (поворот yaw, сдвиг при занятости slide)
static func _g(x: Dictionary, key: String, p: Vector3, yaw := 0.0, slide := Vector3.ZERO) -> bool:
	return CatDressCivic._group(x, _mi(x, key), p, yaw, slide)


# =====================================================================
#   Легион: места прибавок уровня заняты заранее
# =====================================================================

## Всё, что прибавляется с уровнем (CatMilitary.GROW): значки, жаровни, орёл и статуя на постаментах, портик,
## знамёна на фасаде — их места заняты на всех уровнях (на 1-м там пусто, но и наполнение туда не встаёт)
static func _reserve_grow(x: Dictionary, type: String) -> void:
	var G: Dictionary = CatMilitary.GROW.get(type, {})
	if G.is_empty():
		return
	var b: Bp = x["b"]
	var boxes := []
	for p: Vector3 in G["poles"]:
		boxes.append(AABB(p + Vector3(-0.7, 0, -0.3), Vector3(1.4, 4.9, 0.6)))
	for p: Vector3 in G["fire"]:
		boxes.append(AABB(p + Vector3(-0.45, 0, -0.45), Vector3(0.9, 1.3, 0.9)))
	for k: String in ["eagle", "statue"]:
		var p: Vector3 = G.get(k, CatMilitary.NO)
		if p != CatMilitary.NO:
			boxes.append(AABB(p + Vector3(-0.6, 0, -0.6), Vector3(1.2, 2.9, 1.2)))
	if G.has("tall"):
		var p: Vector3 = G["tall"]
		boxes.append(AABB(p + Vector3(-1.0, 0, -0.35), Vector3(2.0, 6.8, 0.7)))
	var box: Array = G["box"]
	var pr: Array = G["porch"]
	if pr.size() == 2 and box.size() >= 5:
		var front := float(box[1]) + float(box[3]) * Bp.M / 2.0
		boxes.append(AABB(Vector3(float(pr[0]) - 0.5, 0, front - 0.05), Vector3(float(pr[1]) - float(pr[0]) + 1.0, 3.9, 1.95)))
	for bx: AABB in boxes:
		(x["solid"] as Array).append(bx)
		(x["wsolid"] as Array).append(bx)
		(x["keep"] as Array).append(Rect2(bx.position.x, bx.position.z, bx.size.x, bx.size.z))
	# знамёна на фасаде (3-й уровень): на стене и у её низа — перед ними кучка встать может (дары перед знаменем)
	if box.size() >= 5:
		var y := float(box[4]) * Bp.FL - 0.3
		for i: float in ([0.3, float(box[2]) - 0.3] if int(box[2]) >= 2 else [0.5]):
			var a := b.wall_at(float(box[0]), float(box[1]), int(box[2]), int(box[3]), 0, i, y, 0.12)
			var q: Vector3 = a[0]
			var bx := AABB(q + Vector3(-0.55, -2.55, -0.25), Vector3(1.1, 2.65, 0.55))
			(x["solid"] as Array).append(bx)
			(x["wsolid"] as Array).append(bx)


## Стены зданий Легиона: тип → набор для CatDressCivic._wallart (щиты, трофеи, шлемы на полке, знамёна, фонари…)
const MIL_WALLS := {
	"barracks": {"g": ["trophy", "shield", "lamp", "helms", "shields"], "u": ["shield", "banner", "trophy"], "sides": ["left", "right", "back"]},
	"range": {"g": ["shield", "lamp", "hooks"], "u": [], "sides": ["left", "back", "right"], "beams": true},
	"spearcamp": {},
	"ballistae": {"beams": true, "g": ["hooks", "shelf", "shield", "lamp"], "u": ["hooks", "shield"], "sides": ["left", "right", "back"]},
	"catapults": {"g": ["hooks", "shield", "lamp", "shelf"], "u": ["banner", "shield"], "sides": ["left", "right", "back"]},
	"forge": {"beams": true, "g": ["shield", "hooks", "trophy", "lamp"], "u": [], "sides": ["left", "right", "back"]},
	"infirmary": {"g": ["herbs", "trellis", "pot", "lamp", "plaque"], "u": [], "sides": ["left", "right", "back"]},
	"armory": {"g": ["helms", "trophy", "shield", "shields", "lamp"], "u": [], "sides": ["left", "right", "back"]},
	"principia": {"g": ["trophy", "plaque", "lamp", "shields"], "u": [], "sides": ["left", "right", "back"]},
	"mars": {"g": ["trophy", "shields", "plaque", "trophy"], "u": [], "sides": ["left", "right", "back", "front"]},
	"smelter": {"beams": true, "g": ["hooks", "shelf", "lamp"], "u": [], "sides": ["left", "right", "back"]},
	"sawmill": {"beams": true, "g": ["hooks", "shelf"], "u": [], "sides": ["left", "right", "back"]},
	"tannery": {"g": ["hooks", "trellis", "lamp", "pot"], "u": [], "sides": ["left", "right", "back"]},
}


static func _mil(x: Dictionary, type: String) -> void:
	var kit: Dictionary = MIL_WALLS.get(type, {})
	if not kit.is_empty():
		CatDressCivic._wallart(x, kit)
	CatDressCivic._roofs(x)
	match type:
		"barracks": _barracks(x)
		"range": _range(x)
		"spearcamp": _spearcamp(x)
		"ballistae": _ballistae(x)
		"catapults": _catapults(x)
		"forge": _forge(x)
		"infirmary": _infirmary(x)
		"armory": _armory(x)
		"principia": _principia(x)
		"mars": _mars(x)
		"smelter": _smelter(x)
		"sawmill": _sawmill(x)
		"tannery": _tannery(x)


## Казармы: за домом — склад лагеря (мешки, амфоры, дрова) под черепичным козырьком, у задней стены — копья и щиты;
## у боков — копья, щиты, амфоры; на скамье у двери — шлемы; на глухих стенах — трофеи, щиты, полка со шлемами
static func _barracks(x: Dictionary) -> void:
	_along(x, ["back"], ["supplyM", "spears", "wood", "shieldstack", "amphpile", "spears", "jarpile"], 1.0)
	CatDressCivic._awning(x, "back")
	_along(x, ["left", "right"], ["spears", "shieldS", "amphS", "sackS", "spears"], 0.95)
	# шлемы на скамье у двери (скамья Казарм: −2,6; −0,1 + 0,35)
	var hb := Bp.model_aabb("SM_Chr_Attach_Helmet_01")
	var top := Bp.model_aabb("SM_Prop_Seat_Bench_01").end.y * 0.9
	_force(x, [_it("SM_Chr_Attach_Helmet_01", 0.95, PI + 0.3, Vector3(-3.05, top - hb.position.y * 0.95, 0.27)),
		_it("SM_Chr_Attach_Helmet_01", 0.95, PI - 0.5, Vector3(-2.35, top - hb.position.y * 0.95, 0.24))])
	CatDressCivic._ivy(x, ["left", "right", "back"], 2, 0.6)


## Стрельбище: у хижины — запасная мишень и снопы, корзины стрел; по краю поля — снопы; полоса стрельбы пустая
static func _range(x: Dictionary) -> void:
	_along(x, ["left"], ["quivers", "sackS", "amphS"], 0.9)
	_along(x, ["back"], ["straw", "quivers"], 0.8)
	# по правому краю поля (за линией стрельбы) — снопы и корзины стрел
	_g(x, "straw", Vector3(4.3, 0, -0.6), PI / 2, Vector3(0, 0, 0.35))
	_g(x, "quivers", Vector3(4.25, 0, 0.7), PI / 2, Vector3(0, 0, 0.3))
	_g(x, "strawT", Vector3(-1.3, 0, -3.7), 0.3, Vector3(0.3, 0, 0))


## Лагерь копейщиков: у плетня — копья и щиты, припасы, жаровня с котлом уже есть; шлемы у табуретов
static func _spearcamp(x: Dictionary) -> void:
	_g(x, "spears", Vector3(3.3, 0, 2.1), -PI / 2, Vector3(0, 0, 0.3))
	_g(x, "shields2", Vector3(-3.25, 0, 1.0), PI / 2, Vector3(0, 0, 0.3))
	_g(x, "amph2", Vector3(3.3, 0, -0.3), -PI / 2, Vector3(0, 0, 0.3))
	_g(x, "sack2", Vector3(-1.3, 0, 2.6), 0.2, Vector3(0.3, 0, 0))


## Мастерская баллист: за домом — брёвна, доски, мешки; у бока — доски и болты; на стенах — крюки, полки, щиты
static func _ballistae(x: Dictionary) -> void:
	_along(x, ["back"], ["timber", "logs", "planks", "sacks", "goods"], 1.0)
	_along(x, ["left"], ["sackS", "amphS", "basketS"], 0.9)
	_along(x, ["front"], ["sack1", "basket"], 0.7)
	_g(x, "planks", Vector3(2.4, 0, -4.35), 0.0, Vector3(0.3, 0, 0))


## Мастерская катапульт: за домом — ядра, брёвна, мешки; у бока — корзины и амфоры
static func _catapults(x: Dictionary) -> void:
	_along(x, ["back"], ["stones", "logs", "sacks", "stones", "timber"], 1.0)
	_along(x, ["right"], ["sackS", "amphS", "basketS"], 0.9)
	_along(x, ["front"], ["stones", "basket", "sack1"], 0.7)
	_g(x, "stones", Vector3(-4.0, 0, -4.1), 0.0, Vector3(0.3, 0, 0))


## Кузница: за домом — уголь и дрова, у бока — бруски железа; во дворе — бруски, вторая наковальня, корыто для закалки
static func _forge(x: Dictionary) -> void:
	_along(x, ["back"], ["ingots", "wood", "sacks", "logs"], 1.0)
	_along(x, ["left"], ["sackS", "amphS"], 0.9)
	_g(x, "ingots", Vector3(2.7, 0, -3.05), 0.0, Vector3(0.3, 0, 0))
	_g(x, "trough", Vector3(3.6, 0, 1.0), 0.0, Vector3(0, 0, 0.3))
	CatDressCivic._ivy(x, ["left", "back"], 1, 0.6)


## Лазарет: за домом — грядки трав и кувшины, у боков — корзины с полотном; у коек — корзина для перевязок
static func _infirmary(x: Dictionary) -> void:
	_along(x, ["back"], ["herbbed", "bandage", "herbs", "jarpile", "herbbed"], 1.0)
	_along(x, ["left", "right"], ["bandageS", "herbs", "vaseS", "sideA"], 0.95)
	_g(x, "bandage", Vector3(-3.55, 0, 2.3), PI / 2, Vector3(0, 0, 0.3))
	CatDressCivic._hang(x, ["left", "right", "back"], ["SM_Prop_FlowerPot_Hanging_04", "SM_Prop_FlowerPot_Hanging_06"], 1.2, 0.6, 0.6)
	CatDressCivic._ivy(x, ["left", "right", "back"], 2, 0.7)


## Склад оружия: за домом — стопки щитов, копья, мешки; у боков — щиты и копья; на стенах — полки со шлемами, трофеи
static func _armory(x: Dictionary) -> void:
	_along(x, ["back"], ["shieldstack", "spears", "supplyM", "shieldstack", "spears", "sacks"], 1.0)
	_along(x, ["left", "right"], ["spears", "shieldS", "sackS"], 0.95)


## Принципия: за домом — припасы, свитки; у фасада — вазы с цветами; у боков — амфоры и цветы
static func _principia(x: Dictionary) -> void:
	_along(x, ["back"], ["supplyM", "scrolls", "amphpile", "vasebloom"], 0.95)
	_along(x, ["left", "right"], ["amphS", "vaseS", "shieldS"], 0.9)
	_along(x, ["front"], ["vasebloom", "amph2"], 0.9)
	CatDressCivic._ivy(x, ["left", "right", "back"], 2, 0.6)


## Храм Марса: под портиком у глухих стен — дары (фрукты, цветы, курильницы) и трофейное оружие; за храмом — сад
static func _mars(x: Dictionary) -> void:
	# под портиком: у стены возле двери — трофейное оружие, у крайних модулей — дары (перед знамёнами 3-го уровня)
	for sd: float in [-1.0, 1.0]:
		_g(x, "armsoffer", Vector3(sd * 1.95, 0, 0.24), 0.0, Vector3(0.12 * sd, 0, 0))
		_g(x, "offer", Vector3(sd * 3.0, 0, 0.95), 0.0, Vector3(0.15 * sd, 0, 0))
	_along(x, ["back"], ["bloom", "vasebloom", "bloom", "senser"], 0.9)
	_along(x, ["left", "right"], ["vaseS", "amphS"], 0.8)
	CatDressCivic._ivy(x, ["left", "right", "back"], 2, 0.6)


static func _smelter(x: Dictionary) -> void:
	_along(x, ["back"], ["logs", "sacks", "wood"], 0.9)
	_along(x, ["left"], ["sackS", "amphS"], 0.85)


static func _sawmill(x: Dictionary) -> void:
	_along(x, ["back"], ["sacks", "basket"], 0.8)
	_along(x, ["left"], ["sackS", "basketS"], 0.85)


static func _tannery(x: Dictionary) -> void:
	_along(x, ["back"], ["jarpile", "amphpile", "sacks"], 0.9)
	_along(x, ["right"], ["amphS", "sackS"], 0.85)


# =====================================================================
#   почтовая станция
# =====================================================================

## Станция: на стенах — ставни, кашпо с цветами, фонари, шпалеры с плющом, знамёна; за станцией — сено, мешки,
## амфоры и цветы; по бокам — багаж приезжих (короба, мешки, скатки), доска объявлений со свитками под черепичным
## козырьком, цветущие кусты. Площадь перед станцией свободна — там ждут семьи (People._plaza_point: до 4,5 м по
## сторонам от двери и 3,5 м вперёд-назад), и дорожка к двери тоже: спереди — только вплотную к стенам крыльев
static func _center(x: Dictionary, tier: int) -> void:
	var b: Bp = x["b"]
	var keep: Array = x["keep"]
	keep.append(Rect2(-6.4, 0.55, 12.8, 20.0))       # площадь для семей
	keep.append(Rect2(-4.6, -0.4, 9.2, 21.0))        # крыльцо, скамьи и дорожка к двери
	CatDressCivic._wallart(x, {"shut": "#shutters_green", "g": ["trellis", "pot", "lamp", "plaque", "pot"], "u": ["pots", "banner", "pots"],
		"sides": ["left", "right", "back", "front"]})
	CatDressCivic._roofs(x)
	CatDressCivic._ivy(x, ["left", "right", "back"], 3, 0.8)
	# доска объявлений и багаж — у боков (слева — к городу), иначе у крыла спереди; потом — кучки вдоль стен
	var lot: Rect2 = x["lot"]
	var xl := lot.position.x + 0.42                  # доска высокая — только внутри рамки следа
	var xr := lot.end.x - 0.42
	for e: Array in [[Vector3(xl, 0, -1.2), -PI / 2], [Vector3(xl, 0, -3.3), -PI / 2], [Vector3(xr, 0, -1.2), PI / 2], [Vector3(xr, 0, -3.3), PI / 2],
			[Vector3(-5.6, 0, 0.12), 0.0], [Vector3(5.6, 0, 0.12), 0.0]]:
		if CatDressCivic._group(x, _notice(x), e[0], e[1], Vector3(0, 0, 0.3) if absf(float(e[1])) > 0.1 else Vector3(0.3, 0, 0)):
			break
	for e: Array in [[Vector3(6.75, 0, -1.4), PI / 2], [Vector3(-6.75, 0, -4.4), -PI / 2], [Vector3(5.5, 0, 0.1), 0.0], [Vector3(-5.5, 0, 0.1), 0.0]]:
		CatDressCivic._group(x, _mi(x, "luggage"), e[0], e[1], Vector3(0, 0, 0.3) if absf(float(e[1])) > 0.1 else Vector3(0.3, 0, 0))
	if tier >= 2:
		for e: Array in [[Vector3(-6.8, 0, -2.4), -PI / 2], [Vector3(6.8, 0, -3.4), PI / 2]]:
			_g(x, "bloom", e[0], e[1], Vector3(0, 0, 0.3))
	_along(x, ["back"], ["store", "luggage", "amphpile", "wood", "bloom", "goods", "vasebloom"], 0.95)
	_along(x, ["left", "right"], ["luggS", "vaseS", "sideA", "luggS", "sideB"], 0.95)
	b._fp.clear()


## Доска объявлений: два столбика, доска с рисунком постоялого двора, черепичный козырёк, у ног — корзина со свитками
static func _notice(x: Dictionary) -> Array:
	var out := []
	for sx: float in [-0.56, 0.56]:
		out.append(["SM_Prop_Pole_01", Transform3D(Basis.from_scale(Vector3(0.5, 0.66, 0.5)), Vector3(sx, 0, 0)), {}])
	out.append(["#sign:mansio", Transform3D(Basis.IDENTITY, Vector3(0, 1.32, 0.09)), {}])
	out.append(["SM_Prop_Overhang_02", Transform3D(Basis.IDENTITY, Vector3(0, 2.02, -0.4)), {}])
	return out + _shift(CatDressCivic._item(x, "scrolls"), Vector3(0.95, 0, 0.12))


# =====================================================================
#   памятники и большие здания
# =====================================================================

static func _grand(x: Dictionary, type: String, tier: int) -> void:
	if type != "center":
		var b: Bp = x["b"]
		x["cover"] = b.footprint()           # крупное — только на занятой следом земле
		x["cover_low"] = [x["outer"]]        # невысокое и тонкое — и в уголках участка, и в полосе у фасада
	match type:
		"center": _center(x, tier)
		"colosseum": _colosseum(x)
		"theatre": _theatre(x)
		"odeon": _odeon(x)
		"pantheon": _pantheon(x)
		"circus_fl": _circus_fl_dress(x)
		"venus": _venus(x)
		"arch": _arch(x)
		"fountain": _fountain(x)
		"pharos": _pharos(x)
		"nymphaeum": _nymphaeum(x)
		"aqua": _aqua(x)


## Столик торговца у входа: стол, на нём кувшины, миски, корзины; под ним корзина (CatDressCivic._market_table),
## низкий столик с подушками для зрителей (подушки напрокат — на каменных ступенях сидеть мягче) или с хлебом
static func _stall(x: Dictionary, kind := "goods") -> Array:
	var C := CatDressCivic
	match kind:
		"cushions":
			var top := Bp.model_aabb("SM_Prop_Table_07").end.y * 0.95
			var out := [_it("SM_Prop_Table_07", 0.95)]
			for k in 3:
				out.append(_it("SM_Prop_Pillow_0%d" % [1, 3, 1][k], 0.75, C._rf(x, 0.0, TAU), Vector3(C._rf(x, -0.04, 0.04), top + 0.05 + k * 0.1, C._rf(x, -0.04, 0.04))))
			out.append(_it("SM_Prop_Pillow_0%d" % C._one(x, [1, 3]), 0.75, C._rf(x, 0.0, TAU), Vector3(0.62, 0.05, 0.05)))
			return out
		"bread":
			var top := Bp.model_aabb("SM_Prop_Table_07").end.y * 0.95
			return [_it("SM_Prop_Table_07", 0.95)] + _shift(C._item(x, "apples"), Vector3(-0.12, top, 0)) + _shift(C._item(x, "bgoods"), Vector3(0.95, 0, 0.05))
	return C._market_table(x)


## Амфитеатр: знамёна на аттике над каждой второй аркой (такие же, как есть), у главного входа — знамёна на шестах,
## по уголкам участка перед аркадой — торговцы: подушки для зрителей, хлеб и фрукты, вино в амфорах, цветы.
## Трибуны и арену не трогаем (места зрителей Spectacle — те же)
static func _colosseum(x: Dictionary) -> void:
	var R := 22.5 * 0.55 + 0.5
	var combos := {4: "02_C", 8: "01_D", 12: "02_F", 16: "01_G", 20: "02_B", 24: "01_E"}
	for j: int in combos:
		var ang := j * TAU / 28.0
		_force(x, [_it("SM_Prop_Banner_" + String(combos[j]), 0.75, ang, Vector3(sin(ang), 0, cos(ang)) * (R + 0.1) + Vector3(0, 7.45, 0))])
	# снаружи аркады — по лучам от середины (наклонные стены аркады занимают коробками почти всё у самого кольца):
	# [угол от фасада, радиус, что]. Спереди — у главного входа, сзади — по уголкам участка
	var spots := [[19.0, 14.2, "bannerpole"], [27.0, 14.7, "cushions"], [36.0, 14.9, "stall"], [45.0, 14.8, "amph3"], [52.0, 14.6, "bloom"],
		[60.0, 14.3, "vasebloom"], [135.0, 15.2, "amphpile"], [150.0, 14.6, "bloom"], [120.0, 14.6, "vasebloom"]]
	for sd: float in [-1.0, 1.0]:
		for e: Array in spots:
			var th := deg_to_rad(float(e[0])) * sd
			var p := Vector3(sin(th), 0, cos(th)) * float(e[1])
			var k := String(e[2])
			var items: Array
			match k:
				"cushions": items = _stall(x, "cushions")
				"stall": items = _stall(x, "bread" if sd < 0.0 else "goods")
				_: items = _mi(x, k)
			CatDressCivic._group(x, items, p, th, Vector3(cos(th), 0, -sin(th)) * 0.3 * sd)


## Театр: у фасада скены к улице — вазы с цветами между арками, у ниш — корзины торговцев, по углам — цветы;
## на сцену и трибуны ничего не ставим
static func _theatre(x: Dictionary) -> void:
	for sd: float in [-1.0, 1.0]:
		_g(x, "vasebloom", Vector3(sd * 3.75, 0, 7.85), 0.0, Vector3(0.15 * sd, 0, 0))
		_g(x, "bgoods", Vector3(sd * 5.0, 0, 7.95), 0.0, Vector3(0.2 * sd, 0, 0))
		_g(x, "vasebloom", Vector3(sd * 6.7, 0, 7.85), 0.0, Vector3(0.2 * sd, 0, 0))
		_g(x, "bloom", Vector3(sd * 7.9, 0, 5.4), 0.0, Vector3(0, 0, -0.3))
		_g(x, "amph2", Vector3(sd * 8.0, 0, 3.6), sd * PI / 2, Vector3(0, 0, -0.3))


## Одеон: перед сценой к улице — вазы с цветами и корзины торговцев, по углам — цветущие кусты
static func _odeon(x: Dictionary) -> void:
	for sd: float in [-1.0, 1.0]:
		_g(x, "vasebloom", Vector3(sd * 2.1, 0, 4.95), 0.0, Vector3(0.15 * sd, 0, 0))
		_g(x, "bgoods", Vector3(sd * 3.5, 0, 5.0), 0.0, Vector3(0.2 * sd, 0, 0))
		_g(x, "bloom", Vector3(sd * 5.85, 0, 1.4), 0.0, Vector3(0, 0, -0.3))
		_g(x, "amph2", Vector3(sd * 5.9, 0, -0.6), sd * PI / 2, Vector3(0, 0, -0.3))


## Пантеон: знамёна в крайних пролётах портика, у лестницы по бокам — торговцы, вокруг ротонды — цветущие кусты и вазы
static func _pantheon(x: Dictionary) -> void:
	var pod := 1.5
	for sd: float in [-1.0, 1.0]:
		var bx := sd * (6.125 - 0.875)
		_force(x, [_it("SM_Prop_Banner_03_%s" % ("A" if sd < 0.0 else "E"), 0.8, 0.0, Vector3(bx, pod + 5.75, 10.62))])
		CatDressCivic._group(x, _stall(x, "goods" if sd < 0.0 else "bread"), Vector3(sd * 7.0, 0, 13.2), sd * PI / 2, Vector3(0, 0, 0.2))
		for a: float in [1.25, 1.75, 2.35]:
			var p := Vector3(sin(sd * a), 0, cos(sd * a)) * 7.35
			_g(x, "bloom" if a != 1.75 else "vasebloom", p, sd * a, Vector3(0, 0, 0.2))


## Цирк: у передней аркады — торговцы (подушки для зрителей, хлеб), вазы с цветами, амфоры; дорожку и трибуны не трогаем
static func _circus_fl_dress(x: Dictionary) -> void:
	var z := 8.8                         # на мостовой перед цоколем аркады (не на его краю)
	for e: Array in [[-17.0, "cushions"], [-10.0, "bread"], [-5.2, "vasebloom"], [5.2, "vasebloom"], [10.0, "cushions"], [17.0, "bread"]]:
		var k := String(e[1])
		var items := _mi(x, k) if k == "vasebloom" else _stall(x, k)
		CatDressCivic._group(x, items, Vector3(float(e[0]), 0, z), 0.0, Vector3(0.4, 0, 0))
	for xx: float in [-13.5, 13.5]:
		_g(x, "amph2", Vector3(xx, 0, z), 0.0, Vector3(0.3, 0, 0))


## Храм Венеры и Ромы: цветущие кусты вдоль подиума
static func _venus(x: Dictionary) -> void:
	var s := 0.66
	for sd: float in [-1.0, 1.0]:
		for z: float in [-4.0, -9.5, -15.5]:
			_g(x, "bloom", Vector3(sd * (9.6 + 0.6) * s, 0, 7.4 + z * s), 0.0, Vector3(0, 0, 0.3))


## Арка: цветущие кусты у опор
static func _arch(x: Dictionary) -> void:
	var lot: Rect2 = x["lot"]
	for sd: float in [-1.0, 1.0]:
		CatDressCivic._group(x, CatDressCivic._bloom(x, 0.45), Vector3(sd * (lot.size.x * 0.5 - 0.3), 0, lot.get_center().y), 0.0, Vector3(0, 0, 0.3))


## Колонна Траяна: вся сборка из Synty, площадь ровно 6 × 6 м после Catalog.ARCH.
## Растягиваем детали по их настоящим габаритам: ступени соприкасаются, у статуи родные пропорции.
static func _piece(b: Bp, nm: String, p: Vector3, size: Vector3, rm := {}, yaw := 0.0, roll := 0.0) -> float:
	var box := Bp.model_aabb(nm)
	var sy := size.y / maxf(0.001, box.size.y)
	var scale := Vector3(size.x / maxf(0.001, box.size.x), sy, size.z / maxf(0.001, box.size.z)) if size.x > 0.0 else Vector3.ONE * sy
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, roll) * Basis.from_scale(scale)
	var center := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	b.parts.append([nm, b.base * Transform3D(basis, p - basis * center), rm])
	return p.y + size.y


static func _trajan(x: Dictionary) -> void:
	var b: Bp = x["b"]
	var marble := {"Stone_01": "Building_Marble_02", "Stucco_Blue_01": "Building_Marble_02"}
	var tile := 6.0 / Catalog.ARCH / 3.0
	# Невысокая мощёная площадь, три широкие ступени и квадратный пьедестал.
	for ix in 3:
		for iz in 3:
			_piece(b, "SM_Bld_Base_Floor_01", Vector3((ix - 1) * tile, -0.04, (iz - 1) * tile), Vector3(tile, 0.14, tile), marble)
	var top := 0.10
	for width: float in [5.4, 4.8, 4.2]:
		top = _piece(b, "SM_Bld_Base_Floor_01", Vector3(0, top, 0), Vector3(width, 0.22, width), marble)
	top = _piece(b, "SM_Bld_Base_Pillar_03", Vector3(0, top, 0), Vector3(2.0, 1.35, 2.0), marble)
	# Три мраморных барабана с рельефом и тонкими поясами между ними.
	for i in 3:
		top = _piece(b, "SM_Bld_Pillar_Monument_01" if i != 1 else "SM_Bld_Pillar_Monument_02",
			Vector3(0, top - 0.03, 0), Vector3(1.45, 4.6, 1.45), marble, i * PI / 2.0)
		top = _piece(b, "SM_Bld_Pillar_Monument_Trim_01", Vector3(0, top - 0.03, 0), Vector3(1.65, 0.22, 1.65), marble)
	if Synty.has("SM_Prop_Statue_02"):
		_piece(b, "SM_Prop_Statue_02", Vector3(0, top, 0), Vector3(0, 2.2, 0))
	# Две жаровни у передних углов, две скамьи сзади. Вход посредине свободен.
	for side: float in [-1.0, 1.0]:
		b.brazier(Vector3(side * 3.25, 0.10, 3.25))
		var bench := _stand("SM_Prop_Seat_Bench_03", 0.75, PI, Vector3(side * 2.5, 0.10, -3.3))
		b.parts.append([bench[0], b.base * (bench[1] as Transform3D), {}])
	b.door = Vector3(0, 0.10, 4.15)


## Новые чудеса задаём в метрах. След занимает всю площадь, включая дворы и арки.
static func _wonder_square(b: Bp, lot: Vector2, tiles: Vector2i, pattern := CatMonuments.PAVING) -> void:
	b.base = Transform3D(Basis.from_scale(Vector3.ONE / Catalog.ARCH), Vector3.ZERO)
	b.fp_override = [Rect2(-lot * 0.5, lot)]
	var tile := lot / Vector2(tiles)
	for i in tiles.x:
		for j in tiles.y:
			var p := (Vector2(i, j) + Vector2(0.5, 0.5)) * tile - lot * 0.5
			_piece(b, "SM_Bld_Base_Floor_01", Vector3(p.x, -0.08, p.y), Vector3(tile.x, 0.18, tile.y), pattern)


## За аркой — улица, камень или створки. Автоматический задник комнаты здесь лишний.
static func _wonder_arch(b: Bp, p: Vector3, size: Vector3, rm := CatMonuments.TRAV_BLOCKS, yaw := 0.0) -> void:
	b.free_parts[b.parts.size()] = true
	_piece(b, "SM_Bld_Wall_Door_Double_01", p, size, rm, yaw)


static func _wonder_door(b: Bp, p: Vector3, width: float, height: float, yaw := 0.0) -> void:
	var front := Basis(Vector3.UP, yaw).z
	_wonder_arch(b, p, Vector3(width, height, 0.34), CatMonuments.TRAV_BLOCKS, yaw)
	_piece(b, "SM_Bld_Door_Large_01", p + front * 0.12, Vector3(width * 0.73, height * 0.89, 0.14), {}, yaw)


static func _circus(b: Bp) -> void:
	_wonder_square(b, Vector2(36, 14), Vector2i(9, 4), CatMonuments.WARM_PAVING)
	b.add("#mil_race_sand", Vector3(0, 0.135, 0))
	CatMonuments._box(b, "#marble", Vector3(0, 0.33, 0), Vector3(20.1, 0.48, 1.38))
	for i in 4:
		_piece(b, "SM_Bld_Wall_Large_Cap_01", Vector3((i - 1.5) * 5.04, 0.51, 0),
			Vector3(5.055, 0.095, 1.52), CatMonuments.CAP_MARBLE)
	_piece(b, "SM_Bld_Base_Pillar_03", Vector3(0, 0.59, 0), Vector3(1.25, 0.56, 1.22))
	b.add("#d2_obelisk", Vector3(0, 1.13, 0), 0.0, 1.46)
	for side: float in [-1.0, 1.0]:
		for distance: float in [3.8, 8.9]:
			var x := side * distance
			var y := _piece(b, "SM_Prop_Plinth_04", Vector3(x, 0.59, 0), Vector3(0.94, 0.54, 0.86))
			_piece(b, "SM_Prop_Statue_04" if distance < 5.0 else "SM_Prop_Statue_Lion_01",
				Vector3(x, y - 0.02, 0), Vector3(0, 1.35 if distance < 5.0 else 0.78, 0), {}, side * PI / 2)
	for i in 7:
		var x := 4.85 + i * 0.44
		_piece(b, "SM_Bld_Pillar_02", Vector3(x, 0.59, 0), Vector3(0.22, 0.89, 0.22))
		_piece(b, "SM_Prop_Senser_01", Vector3(x, 1.46, 0), Vector3(0.26, 0.34, 0.26))
	# Четыре сектора с каменными сиденьями и ступенями. Аркада видна с улицы.
	for side: float in [-1.0, 1.0]:
		var inward := Vector3(0, 0, -side)
		var along := Vector3(-side, 0, 0)
		for row in 3:
			var z := side * (4.19 + row * 0.72)
			var y := 0.48 + row * 0.37
			for x: float in [-8.1, -2.7, 2.7, 8.1]:
				CatGrand._row(b, x - 2.38, x + 2.38, z, side, y, 0.36, 0.72, Crowd.SEAT_DROP, along, inward)
			for x: float in [-10.9, -5.4, 0.0, 5.4, 10.9]:
				CatMonuments._box(b, "#marble", Vector3(x, y * 0.5, z + side * 0.36), Vector3(0.67, y, 0.72))
		for i in 8:
			var x := (i - 3.5) * 2.74
			_wonder_arch(b, Vector3(x, 0.10, side * 6.59), Vector3(2.75, 1.82, 0.52),
				CatMonuments.TRAV_BLOCKS, 0.0 if side > 0.0 else PI)
		_piece(b, "SM_Bld_Wall_Large_Cap_01", Vector3(0, 1.82, side * 6.59), Vector3(22.4, 0.24, 0.68))
		for x: float in [-10.2, -6.1, 6.1, 10.2]:
			_piece(b, "SM_Bld_Pillar_03", Vector3(x, 1.96, side * 6.53), Vector3(0.23, 1.58, 0.23))
		for x: float in [-8.15, 8.15]:
			_piece(b, "SM_Prop_Banner_Roof_02", Vector3(x, 3.37, side * 5.58), Vector3(4.24, 0.48, 2.35),
				CatMonuments.VELA_SAFFRON if side < 0.0 else {}, 0.0 if side < 0.0 else PI)
		for x: float in [-9.7, 0.0, 9.7]:
			var z := side * 6.52
			_piece(b, "SM_Prop_Banner_03_B", Vector3(x, 1.40, z + side * 0.28), Vector3(0, 1.06, 0), {}, 0.0 if side > 0.0 else PI)
		b.brazier(Vector3(-13.15, 0.10, side * 5.30))
		b.brazier(Vector3(13.32, 0.10, side * 5.15))
		b.brazier(Vector3(0, 2.05, side * 6.54))
	# Карцеры и две башенки на западе, полукруглая стенка и арка на востоке.
	for i in 6:
		_wonder_door(b, Vector3(-16.1, 0.10, (i - 2.5) * 1.32), 1.34, 2.44, PI / 2)
	_piece(b, "SM_Bld_Wall_Large_Cap_01", Vector3(-16.12, 2.42, 0), Vector3(8.2, 0.27, 0.74), {}, PI / 2)
	for side: float in [-1.0, 1.0]:
		_piece(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(-16.15, 0.08, side * 4.63), Vector3(1.65, 3.38, 1.5), CatMonuments.TRAV_BLOCKS)
		_piece(b, "SM_Bld_Wall_Large_Pillar_Cap_01", Vector3(-16.15, 3.40, side * 4.63), Vector3(1.78, 0.31, 1.66))
		for i in 4:
			var ang := (i + 0.72) * 0.37 * side
			var p := Vector3(CIRCUS_TURN + cos(ang) * 4.45, 0.10, sin(ang) * 4.45)
			_piece(b, "SM_Bld_Wall_01", p, Vector3(1.67, 1.36, 0.47), CatMonuments.STONE_WALL, PI / 2 - ang)
			_piece(b, "SM_Bld_Wall_Large_Cap_01", p + Vector3.UP * 1.26, Vector3(1.78, 0.19, 0.59), {}, PI / 2 - ang)
	_wonder_arch(b, Vector3(15.92, 0.10, 0), Vector3(2.38, 3.09, 0.91), CatMonuments.TRAV_BLOCKS, PI / 2)
	_piece(b, "SM_Bld_Wall_Large_Cap_01", Vector3(15.92, 3.10, 0), Vector3(2.65, 0.27, 1.05), {}, PI / 2)
	_piece(b, "SM_Prop_Statue_02", Vector3(15.92, 3.37, 0), Vector3(0, 0.99, 0), {}, -PI / 2)
	b.door = b.base * Vector3(0, 0.1, 7.0)


static func _aqueduct(b: Bp) -> void:
	_wonder_square(b, Vector2(24, 6), Vector2i(6, 2))
	var trav := CatMonuments.TRAV_BLOCKS
	for i in 4:
		var x := -9.0 + i * 4.45
		_wonder_arch(b, Vector3(x, 0.38, -0.71), Vector3(4.46, 4.12, 1.80), trav)
	for i in 5:
		var x := -11.23 + i * 4.45
		_piece(b, "SM_Bld_Base_Pillar_03", Vector3(x, 0.10, -0.71), Vector3(0.91, 0.54, 2.18))
		_piece(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(x, 0.62, -0.71), Vector3(0.64, 3.78, 1.94), trav)
	for i in 8:
		var x := -10.1125 + i * 2.225
		_wonder_arch(b, Vector3(x, 4.54, -0.71), Vector3(2.23, 2.02, 1.21), trav)
	for i in 4:
		var x := -9.0 + i * 4.45
		for level: float in [4.39, 6.53]:
			_piece(b, "SM_Bld_Wall_Large_Cap_01", Vector3(x, level, -0.715), Vector3(4.45, 0.20, 2.06 if level < 5.0 else 1.65))
	# Открытый жёлоб, чуть утопленный между каменными стенками.
	CatMonuments._box(b, "#water", Vector3(-1.48, 6.75, -0.71), Vector3(19.8, 0.04, 0.86))
	for z: float in [-1.27, -0.15]:
		_piece(b, "SM_Bld_Wall_Large_Cap_01", Vector3(-1.5, 6.67, z), Vector3(19.8, 0.31, 0.29))
	_piece(b, "SM_Bld_Base_Pillar_03", Vector3(-11.34, 6.69, -0.71), Vector3(0.35, 0.28, 1.34))
	# Кастеллум: светлый фасад, черепица и львиная пасть над чашей.
	_piece(b, "SM_Bld_Wall_Large_01", Vector3(8.81, 0.10, -0.80), Vector3(5.22, 5.22, 3.70), trav)
	_wonder_arch(b, Vector3(8.81, 0.15, 1.11), Vector3(4.62, 4.30, 0.41), CatMonuments.MARBLE_BLOCKS)
	_piece(b, "SM_Prop_Marble_LionHead_01", Vector3(8.81, 1.35, 1.46), Vector3(0, 0.79, 0))
	_piece(b, "SM_Bld_Wall_Large_Cap_01", Vector3(8.81, 5.17, -0.81), Vector3(5.48, 0.34, 4.0))
	for x: float in [6.52, 11.10]:
		_piece(b, "SM_Bld_Pillar_Large_02", Vector3(x, 0.10, 1.28), Vector3(0.48, 5.12, 0.46))
	_piece(b, "SM_Bld_Wall_Large_01", Vector3(9.40, 5.46, -0.79), Vector3(3.87, 1.57, 2.84), trav)
	var square := b.base
	b.base = square.translated_local(Vector3(9.40, 0, 0))
	CatGrand._roof(b, 1.61, 0.84, -2.44, 6.99, {}, CatMonuments.TYMPANUM)
	b.base = square
	_piece(b, "SM_Bld_Base_Floor_01", Vector3(8.80, 0.10, 1.99), Vector3(4.2, 0.23, 1.76), CatMonuments.MOSAIC)
	CatMonuments._box(b, "#water", Vector3(8.8, 0.45, 1.99), Vector3(3.68, 0.045, 1.27))
	for x: float in [6.82, 10.78]:
		_piece(b, "SM_Bld_Bath_Edge_01", Vector3(x, 0.24, 1.99), Vector3(1.76, 0.40, 0.26), {}, PI / 2)
	_piece(b, "SM_Bld_Bath_Edge_01", Vector3(8.8, 0.24, 2.76), Vector3(4.02, 0.40, 0.27))
	for x: float in [-9.2, -4.8, 0.1, 4.4]:
		b.brazier(Vector3(x, 0.10, 1.57))
	b.light(Vector3(8.8, 1.95, 2.06))
	b.door = b.base * Vector3(8.8, 0.10, 3.0)


## ??? ??????? ????????? ??????. ?????????? ???????? ? ??????, ????????? ????? ?? ??????.
static func _sculpted_pediment(b: Bp, half: float, eave: float, ridge: float, z: float, temple: bool) -> void:
	var rise := ridge - eave
	var cap := "SM_Bld_Wall_Large_Cap_01"
	var face := z + 0.04
	_piece(b, cap, Vector3(0, eave - 0.20, face + 0.06), Vector3(half * 2.0 + 0.12, 0.24, 0.47), CORNICE_MARBLE)
	_piece(b, cap, Vector3(0, eave - 0.34, face + 0.03), Vector3(half * 2.0 - 0.06, 0.14, 0.38), GABLE_FRIEZE)
	var slope := Vector2(half, rise)
	for side: float in [-1.0, 1.0]:
		_piece(b, cap, Vector3(side * half * 0.5, eave + rise * 0.5 - 0.075, face),
			Vector3(slope.length() + 0.10, 0.18, 0.42), CORNICE_MARBLE, 0.0, -side * slope.angle())
		_piece(b, "SM_Bld_Ornament_04", Vector3(side * half * 0.49, eave + rise * 0.12, face + 0.085),
			Vector3(rise * 0.48, rise * 0.32, 0.15))
		_piece(b, "SM_Prop_Statue_05", Vector3(side * half * 0.24, eave + rise * 0.11, face + 0.08),
			Vector3(rise * 0.24, rise * 0.52, 0.21), {}, -side * 0.39)
		var ledge := _piece(b, cap, Vector3(side * (half - 0.29), eave + 0.095, z - 0.12),
			Vector3(0.58, 0.17, 0.57), CORNICE_MARBLE)
		_piece(b, "SM_Prop_Statue_05", Vector3(side * (half - 0.29), ledge, z - 0.12),
			Vector3(0, 0.79 if temple else 0.68, 0), {}, -side * 0.24)
	_piece(b, "SM_Prop_Statue_04" if temple else "SM_Prop_Statue_06", Vector3(0, eave + rise * 0.12, face + 0.115),
		Vector3(rise * 0.58, rise * 0.72, 0.30))
	var top := _piece(b, "SM_Prop_Plinth_04", Vector3(0, ridge - 0.055, z - 0.22), Vector3(0.79, 0.31, 0.68))
	if temple:
		b.add("#mil_eagle", Vector3(0, top - 0.025, z - 0.22), 0.0, 1.32)
	else:
		_piece(b, "SM_Prop_Statue_06", Vector3(0, top, z - 0.22), Vector3(0, 0.98, 0))


## ??????? ???? Synty ? ?????? ?????? ? ??????? ??????.
static func _bath_window(b: Bp, p: Vector3, width: float, height: float, yaw := 0.0) -> void:
	var frame := CatMonuments.BRICK.duplicate()
	frame["PolygonAncientEmpire_01_A"] = "Building_Marble_02"
	b.free_parts[b.parts.size()] = true
	_piece(b, "SM_Bld_Wall_Door_Double_01", p, Vector3(width, height, 0.43), frame, yaw)
	var front := Basis(Vector3.UP, yaw).z
	CatMonuments._box(b, "#plate_lit", p - front * 0.16 + Vector3.UP * (height * 0.5),
		Vector3(width * 0.96, height, 0.075), yaw)
	_piece(b, "SM_Bld_Wall_Large_Cap_01", p - Vector3.UP * 0.12,
		Vector3(width, 0.14, 0.53), CORNICE_MARBLE, yaw)


static func _bath_hall(b: Bp) -> void:
	var brick := CatMonuments.BRICK
	var marble := CatMonuments.MARBLE_BLOCKS
	var rear := -7.40
	var facade := -1.66
	var mid_z := (rear + facade) * 0.5
	var half := 4.28
	var window_y := 4.43
	var roof_y := 6.49
	for side: float in [-1.0, 1.0]:
		_piece(b, "SM_Bld_Wall_Large_01", Vector3(side * 2.82, 0.42, facade), Vector3(2.94, 4.05, 0.43), brick)
		_piece(b, "SM_Bld_Wall_Large_01", Vector3(side * half, 0.42, mid_z), Vector3(5.75, 4.05, 0.43), brick, side * PI / 2)
		for z: float in [mid_z - 1.45, mid_z + 1.45]:
			_bath_window(b, Vector3(side * half, window_y, z), 2.91, roof_y - window_y, side * PI / 2)
		b.smoke.append(b.base * Vector3(side * 2.82, 5.43, facade + 0.36))
		b.light(Vector3(side * 2.82, 5.28, facade + 0.35))
	_piece(b, "SM_Bld_Wall_Large_01", Vector3(0, 0.42, rear), Vector3(8.57, 4.05, 0.43), brick, PI)
	for x: float in [-2.86, 0.0, 2.86]:
		_bath_window(b, Vector3(x, window_y, facade), 2.87, roof_y - window_y)
		_bath_window(b, Vector3(x, window_y, rear), 2.87, roof_y - window_y, PI)
	_wonder_door(b, Vector3(0, 0.42, facade), 2.72, 3.48)
	_piece(b, "SM_Bld_Wall_Large_01", Vector3(0, 3.89, facade), Vector3(2.74, 0.57, 0.43), marble)
	_piece(b, "SM_Bld_Base_Floor_01", Vector3(0, roof_y - 0.07, mid_z), Vector3(8.96, 0.34, 6.24), CatMonuments.PORCH)
	for z: float in [rear, facade]:
		_piece(b, "SM_Bld_Wall_Large_Cap_01", Vector3(0, roof_y - 0.10, z), Vector3(8.97, 0.34, 0.77), CORNICE_MARBLE)
	for side: float in [-1.0, 1.0]:
		_piece(b, "SM_Bld_Wall_Large_Cap_01", Vector3(side * half, roof_y - 0.10, mid_z),
			Vector3(5.83, 0.34, 0.74), CORNICE_MARBLE, side * PI / 2)
	# ??????? ?????? ????? ?????? ???????, ??? ? ????????.
	const DRUM_SIDES := 12
	const DRUM_R := 2.84
	var span := 2.0 * DRUM_R * tan(PI / DRUM_SIDES)
	for i in DRUM_SIDES:
		var angle := (i + 0.5) * TAU / DRUM_SIDES
		var rim := Vector3(sin(angle) * DRUM_R, roof_y + 0.20, mid_z + cos(angle) * DRUM_R)
		_piece(b, "SM_Bld_Wall_Large_01", rim, Vector3(span + 0.04, 0.69, 0.39), marble, angle)
		_piece(b, "SM_Bld_Wall_Large_Cap_01", rim + Vector3.UP * 0.54, Vector3(span + 0.13, 0.21, 0.47), CORNICE_MARBLE, angle)
	var dome_mat := {"Stucco_Blue_01": "Stucco_White_01", "tints": {"Stucco_White_01": Color(0.68, 0.75, 0.71)}}
	CatMonuments._put(b, "SM_Prop_Pergola_01", Transform3D(Basis.from_scale(Vector3(1.29, 1.16, 1.19)),
		Vector3(0, roof_y + 0.38 - 3.6 * 1.16, mid_z)), dome_mat)


static func _bath_wing(b: Bp, side: float) -> void:
	var x := side * 5.72
	var outer := side * 7.13
	var brick := CatMonuments.BRICK
	var marble := CatMonuments.MARBLE_BLOCKS
	for end: float in [-1.0, 1.0]:
		var z := -3.94 + end * 3.02
		var yaw := 0.0 if end > 0.0 else PI
		_piece(b, "SM_Bld_Wall_Large_01", Vector3(x, 0.40, z), Vector3(2.92, 0.82, 0.44), marble, yaw)
		_bath_window(b, Vector3(x, 1.18, z), 2.92, 2.15, yaw)
		_piece(b, "SM_Bld_Wall_Large_Cap_01", Vector3(x, 3.28, z), Vector3(3.14, 0.39, 0.69), CORNICE_MARBLE, yaw)
	for z: float in [-5.45, -2.43]:
		_piece(b, "SM_Bld_Wall_Large_01", Vector3(outer, 0.40, z), Vector3(3.03, 0.82, 0.44), marble, side * PI / 2)
		_bath_window(b, Vector3(outer, 1.18, z), 3.03, 2.15, side * PI / 2)
	_piece(b, "SM_Bld_Wall_Large_01", Vector3(side * 4.31, 0.40, -3.94), Vector3(6.06, 2.97, 0.43), brick, side * -PI / 2)
	_piece(b, "SM_Bld_Wall_Large_Cap_01", Vector3(outer, 3.28, -3.94), Vector3(6.32, 0.39, 0.69), CORNICE_MARBLE, side * PI / 2)
	for z: float in [-5.44, -2.44]:
		_piece(b, "SM_Bld_Roof_Base_Flat_02", Vector3(x, 3.56, z), Vector3(2.94, 0.14, 3.01))
	b.light(Vector3(x, 2.28, -0.55))


static func _caracalla(b: Bp) -> void:
	_wonder_square(b, Vector2(16, 16), Vector2i(4, 4), CatMonuments.WARM_PAVING)
	_piece(b, "SM_Bld_Base_Floor_01", Vector3(0, 0.10, -3.57), Vector3(15.14, 0.32, 8.42), CatMonuments.PORCH)
	_bath_hall(b)
	for side: float in [-1.0, 1.0]:
		_bath_wing(b, side)
	# ?????? ???? ? ?????? ??????? ????????? ????? ? ?????????.
	for i in 6:
		_piece(b, "SM_Bld_Pillar_Large_04", Vector3((i - 2.5) * 1.48, 0.40, 0.17), Vector3(0.60, 3.75, 0.60))
	for z: float in [-1.58, 0.19]:
		_piece(b, "SM_Bld_Wall_Large_Cap_01", Vector3(0, 4.11, z), Vector3(8.22, 0.38, 0.76), CORNICE_MARBLE)
	for side: float in [-1.0, 1.0]:
		_piece(b, "SM_Bld_Wall_Large_Cap_01", Vector3(side * 3.94, 4.11, -0.71), Vector3(2.18, 0.38, 0.62), CORNICE_MARBLE, PI / 2)
		b.brazier(Vector3(side * 2.87, 0.42, -0.64))
	var ridge := CatGrand._roof(b, 4.08, 0.56, -1.88, 4.45, {}, GABLE_MARBLE)
	_sculpted_pediment(b, 4.08, 4.45, ridge, 0.56, false)
	# ???????: ???????, ???????, ????????? ? ?????? ?????? ?? ?????.
	_piece(b, "SM_Bld_Base_Floor_01", Vector3(0, 0.10, 4.04), Vector3(8.10, 0.19, 5.06), CatMonuments.MOSAIC)
	CatMonuments._box(b, "#water_bath", Vector3(0, 0.52, 4.04), Vector3(7.29, 0.05, 4.59))
	for side: float in [-1.0, 1.0]:
		_piece(b, "SM_Bld_Bath_Edge_01", Vector3(side * 3.81, 0.19, 4.04), Vector3(4.90, 0.58, 0.33), {}, side * PI / 2)
		for z: float in [1.59, 6.49]:
			var yaw := (0.0 if side > 0.0 else PI / 2) + (0.0 if z > 4.0 else side * PI / 2)
			_piece(b, "SM_Bld_Bath_Corner_01", Vector3(side * 3.81, 0.19, z), Vector3(0.42, 0.58, 0.42), {}, yaw)
		_piece(b, "SM_Bld_Bath_Edge_01", Vector3(side * 2.47, 0.19, 6.49), Vector3(2.30, 0.58, 0.32))
		for z: float in [1.17, 2.96, 4.75, 6.54]:
			_piece(b, "SM_Bld_Pillar_03", Vector3(side * 5.65, 0.10, z), Vector3(0.52, 2.77, 0.52))
		_piece(b, "SM_Bld_Wall_Large_Cap_01", Vector3(side * 5.65, 2.82, 3.85), Vector3(6.05, 0.34, 0.92), CORNICE_MARBLE, PI / 2)
		for z: float in [1.54, 6.57]:
			var y := _piece(b, "SM_Prop_Plinth_04", Vector3(side * 4.65, 0.10, z), Vector3(0.76, 0.54, 0.78))
			_piece(b, "SM_Prop_Statue_05" if z > 4.0 else "SM_Prop_Statue_04", Vector3(side * 4.65, y, z),
				Vector3(0, 1.37, 0), {}, -side * (0.45 if z > 4.0 else 1.14))
		CatMonuments._big_brazier(b, Vector3(side * 6.58, 0.10, 6.29), 0.67)
		b.smoke.append(b.base * Vector3(side * 2.21, 0.60, 3.48 if side > 0.0 else 5.11))
	_piece(b, "SM_Bld_Bath_Edge_01", Vector3(0, 0.19, 1.59), Vector3(7.26, 0.58, 0.32), {}, PI)
	_piece(b, "SM_Bld_Bath_Stairs_01", Vector3(0, 0.19, 6.34), Vector3(2.70, 0.58, 1.22), {}, PI)
	b.door = b.base * Vector3(0, 0.10, 8.0)


static func _jupiter(b: Bp) -> void:
	_wonder_square(b, Vector2(12, 18), Vector2i(3, 4), CatMonuments.PAVING)
	var marble := CatMonuments.MARBLE_BLOCKS
	_piece(b, "SM_Bld_Base_Floor_01", Vector3(0, 0.10, -2.4), Vector3(11.04, 0.42, 12.1), CatMonuments.PORCH)
	_piece(b, "SM_Bld_Wall_Large_01", Vector3(0, 0.46, -2.40), Vector3(10.60, 1.09, 11.72), marble)
	_piece(b, "SM_Bld_Base_Floor_01", Vector3(0, 1.54, -2.40), Vector3(11.06, 0.28, 12.12), CatMonuments.PORCH)
	for i in 4:
		_piece(b, "SM_Bld_Stairs_01", Vector3((i - 1.5) * 1.91, 0.10, 5.15), Vector3(1.91, 1.73, 3.06))
	for z: float in [3.21, 1.19]:
		for i in 6:
			_piece(b, "SM_Bld_Pillar_Large_04", Vector3((i - 2.5) * 1.83, 1.81, z), Vector3(0.78, 4.59, 0.78), CatMonuments.CAP_MARBLE)
	for side: float in [-1.0, 1.0]:
		_piece(b, "SM_Bld_Wall_Large_01", Vector3(side * 4.49, 1.81, -3.93), Vector3(7.53, 4.61, 0.54),
			CatMonuments.MARBLE_WALL, side * PI / 2)
		_piece(b, "SM_Bld_Wall_Large_01", Vector3(side * 2.80, 1.81, -0.21), Vector3(3.41, 4.61, 0.54), CatMonuments.MARBLE_WALL)
		_piece(b, "SM_Bld_Ornament_02", Vector3(side * 2.83, 3.66, 0.12), Vector3(1.32, 1.19, 0.20))
		b.brazier(Vector3(side * 1.66, 1.81, 0.57))
		_piece(b, "SM_Prop_Plinth_04", Vector3(side * 4.91, 0.10, 5.84), Vector3(0.91, 0.75, 0.92))
		_piece(b, "SM_Prop_Statue_05", Vector3(side * 4.91, 0.84, 5.84), Vector3(0, 1.72, 0), {}, -side * 0.35)
	_piece(b, "SM_Bld_Wall_Large_01", Vector3(0, 1.81, -7.72), Vector3(9.53, 4.61, 0.50), CatMonuments.MARBLE_WALL, PI)
	_piece(b, "SM_Bld_Wall_Large_01", Vector3(0, 4.69, -0.22), Vector3(2.54, 1.75, 0.54), CatMonuments.MARBLE_WALL)
	_wonder_door(b, Vector3(0, 1.81, -0.20), 2.55, 2.97)
	b.light(Vector3(0, 3.04, 0.81))
	var eave := CatMonuments._entablature(b, -5.12, 5.12, -7.87, 3.59, 6.32)
	var ridge := CatGrand._roof(b, 5.37, 3.80, -8.06, eave, CatGrand.GOLD_ROOF, GABLE_MARBLE)
	_sculpted_pediment(b, 5.37, eave, ridge, 3.80, true)
	var altar := _piece(b, "SM_Prop_Plinth_04", Vector3(0, 0.10, 7.38), Vector3(1.75, 0.93, 1.57))
	CatMonuments._fire_bowl(b, Vector3(0, altar, 7.38), 0.94)
	CatDecor._flame(b, Vector3(0, altar + 0.32, 7.38), 0.15)
	for x: float in [-3.6, 3.6]:
		b.brazier(Vector3(x, 0.10, 7.75))
	b.door = b.base * Vector3(0, 0.10, 9.0)



## Фонтан: вазы с цветами у задних углов чаши
static func _fountain(x: Dictionary) -> void:
	var lot: Rect2 = x["lot"]
	for sd: float in [-1.0, 1.0]:
		_g(x, "vasebloom", Vector3(sd * (lot.size.x * 0.5 - 0.35), 0, lot.position.y + 0.4), 0.0, Vector3(0, 0, 0.25))


## Маяк (владелец 12.11: «пересобирай всё в более детальное»): на площадке у башни — лодочные снасти (лодка вверх
## дном на колодах, вёсла у стены, бухты каната, сеть сушится на жердях), амфоры и вазы с цветами за башней,
## на глухих стенах башни — кашпо и цветущий плющ. Лестница, проход к двери и люди при деле свободны
static func _pharos(x: Dictionary) -> void:
	if not CatDressCivic.LIFE2:
		return
	var C := CatDressCivic
	# слева: лодка вверх дном вдоль башни, бухта каната у кормы, вёсла прислонены к башне
	C._group(x, [_it("#dress:boat", 1.0)], Vector3(-3.55, 0, -0.2), 0.0, Vector3(0, 0, 0.3))
	C._group(x, [_it("#dress:coil", 1.5, C._rf(x, 0.0, TAU))], Vector3(-3.45, 0, 1.75), 0.0, Vector3(0, 0, 0.25))
	C._group(x, [_lean("#dress:oars", 1.0, 0.17, Vector3(0, 0, 0.36))], Vector3(-2.62, 0, -1.9), -PI / 2, Vector3(0, 0, 0.3))
	# справа: сеть на жердях вдоль башни, бухта каната, амфоры
	C._group(x, [_it("#dress:net", 1.0)], Vector3(3.6, 0, -0.4), PI / 2, Vector3(0, 0, 0.3))
	C._group(x, [_it("#dress:coil", 1.35, C._rf(x, 0.0, TAU))], Vector3(3.4, 0, 1.6), 0.0, Vector3(0, 0, 0.25))
	_g(x, "amph2", Vector3(3.65, 0, -2.25), PI / 2, Vector3(0, 0, 0.25))
	# за башней: вазы с цветами и амфоры
	for e: Array in [[Vector3(-1.7, 0, -3.65), "vasebloom"], [Vector3(0.0, 0, -3.7), "amph3"], [Vector3(1.7, 0, -3.65), "vasebloom"]]:
		_g(x, String(e[1]), e[0], 0.0, Vector3(0.3, 0, 0))
	C._hang(x, ["left", "right", "back"], ["SM_Prop_FlowerPot_Hanging_04", "SM_Prop_FlowerPot_Hanging_05", "SM_Prop_FlowerPot_Hanging_06"], 1.25, 0.8, 0.6, 0.13, 3)
	C._ivy(x, ["back", "left", "right"], 2, 0.8)


## Нимфей: по бокам бассейна — вазы с цветущими кустами, за стеной с нишами — цветы и вазы, с её верха на зады свисает
## цветущий плющ. Перед бассейном пусто: там умываются и любуются (People: досуг у фонтанов)
static func _nymphaeum(x: Dictionary) -> void:
	if not CatDressCivic.LIFE2:
		return
	var C := CatDressCivic
	var wz := -1.6
	for sd: float in [-1.0, 1.0]:
		_g(x, "vasebloom", Vector3(sd * 4.3, 0, 0.15), 0.0, Vector3(0, 0, 0.25))
	for e: Array in [[-3.2, "bloom"], [-1.6, "pot"], [0.0, "vasebloom"], [1.6, "pot"], [3.2, "bloom"]]:
		var items: Array = C._bloom(x, 0.5) if e[1] == "bloom" else _mi(x, String(e[1]))
		C._group(x, items, Vector3(float(e[0]), 0, wz - 1.2), 0.0, Vector3(0.25, 0, 0))     # вплотную к краю мраморного основания
	# плющ с верха стены — на её задней стороне (лицом назад), у средней и крайних ниш
	# (на верх стены — без проверки места: под плющом сама стена; верх малой стенки над нишами — 3,62)
	for xx: float in [-2.9, 1.3]:
		_force(x, [_it("SM_Env_Ivy_Draped_Flowers_0%d" % C._one(x, [1, 3]), 0.85, PI, Vector3(xx, 3.6, wz - 0.1))])


## Акведук: у подножий опор — кусты и камни, вплотную к опоре и не шире её (под арками ходят и проводят улицы: проёмы
## свободны), у средней опоры — только с задней стороны (спереди — проход к нему), у крайних полуопор — по разные
## стороны (соседний кусок встаёт вплотную — его полуопора с другой стороны). Ставится без проверки места: короб арки
## Synty занимает весь пролёт целиком, вместе с проёмом, — по нему не понять, где свободно; места рассчитаны по опорам
static func _aqua(x: Dictionary) -> void:
	if not CatDressCivic.LIFE2:
		return
	var C := CatDressCivic
	var f := CatGrand.AQ_T                  # лицо опоры
	var h := CatGrand.AQ_HALF - CatGrand.AQ_PIER * 0.25     # середина крайней полуопоры
	_force(x, [_it("SM_Env_Garden_Plants_02", 0.55, 0.0, Vector3(-0.05, 0, -f - 0.55), {}), _it("SM_Prop_Marble_Rubble_07", 0.6, 0.0, Vector3(0.22, 0, -f - 0.25)),
		_it("SM_Env_Grass_01", 0.45, C._rf(x, 0.0, TAU), Vector3(-0.35, 0, -f - 0.15))])
	_force(x, [_it("SM_Env_Garden_Plants_05", 0.42, 0.0, Vector3(-h, 0, f + 0.45), {}), _it("SM_Env_Grass_01", 0.42, C._rf(x, 0.0, TAU), Vector3(-h + 0.12, 0, f + 0.12))])
	_force(x, [_it("SM_Prop_Marble_Rubble_07", 0.55, 0.0, Vector3(-h, 0, -f - 0.22)), _it("SM_Env_Grass_01", 0.4, C._rf(x, 0.0, TAU), Vector3(-h - 0.1, 0, -f - 0.35))])
	_force(x, [_it("SM_Env_Garden_Plants_05", 0.42, PI, Vector3(h, 0, -f - 0.45), {}), _it("SM_Env_Grass_01", 0.42, C._rf(x, 0.0, TAU), Vector3(h - 0.12, 0, -f - 0.12))])
	_force(x, [_it("SM_Prop_Marble_Rubble_03", 0.58, 0.0, Vector3(h, 0, f + 0.24)), _it("SM_Env_Grass_01", 0.4, C._rf(x, 0.0, TAU), Vector3(h + 0.05, 0, f + 0.4))])


# =====================================================================
#   мелочи
# =====================================================================

static func _it(nm: String, s := 1.0, yaw := 0.0, off := Vector3.ZERO, rm := {}) -> Array:
	return CatDressCivic._it(nm, s, yaw, off, rm)


## Поставить детали без проверки места (точно рассчитанное положение: шлемы на скамье, знамя на шесте)
static func _force(x: Dictionary, items: Array, g := Transform3D.IDENTITY) -> void:
	var b: Bp = x["b"]
	for it: Array in items:
		b.free_parts[b.parts.size()] = true
		b.parts.append([String(it[0]), g * (it[1] as Transform3D), it[2] if it.size() > 2 else {}])
	x["n"] = int(x["n"]) + items.size()
