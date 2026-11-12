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
const GRAND := ["center", "colosseum", "circus_fl", "theatre", "odeon", "pantheon", "venus", "arch", "fountain", "pharos", "nymphaeum", "aqua"]
## Выключатель для проверок «было/стало» (вместе с CatDressCivic.ON)
static var ON := true


static func handles(type: String) -> bool:
	return ON and (type in MIL or type in GRAND)


static func dress(b: Bp, type: String, tier := 0) -> void:
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
		"circus_fl": _circus(x)
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
static func _circus(x: Dictionary) -> void:
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
