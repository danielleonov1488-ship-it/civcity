class_name CatDress
extends RefCounted
## Наполнение домов и лавок деталями, как на картинках Synty (владелец 12.11: «всё на Synty, пересобрать…
## более детальными и живыми»; «детальнее… что-то между нашими сборными и Синти: кирпичики, земля…»):
## ящики цветов под окнами, цветущий плющ, горшки у дверей и на цепях, вывески над дверью и на кронштейне,
## кирпичная кладка там, где отбита штукатурка, каменные блоки на углах, трава и камешки у стен, корзины и мешки
## у лавок. Ставится после сборки облика по стенам Synty из чертежа (снаружи — от середины дома); землю не
## занимает (Bp.free_parts) — след и правила постановки прежние. Свои детали (#bricks_*, #quoin_*, #sign:*, #bsign:*,
## #dress:*) одинаковы во всём городе — каждая рисуется одним MultiMesh (Parts).
## Случайность — от облика здания (_ident: тип, облик, цвет), а не от числа деталей: правка строителя дома не
## перетасовывает наполнение всего города; у каждой стены — своё зерно (её место), соседние стены друг друга не сдвигают.

const WALL_W := 2.5            # стена Synty: 2,5 вдоль (x от 0), 3 в высоту, толщина по z
const FACE := 0.115            # от середины толщины стены до её лица
## Ящики цветов под окнами: свои лёгкие (fbox_mesh — те же цветы Synty в простом ящике: 150 треугольников вместо 330)
const BOXES := ["#dress:fbox1", "#dress:fbox2"]
## Ящиков цветов от прохода на дом — не больше (у фасада свои ставит строитель дома, CatHouses._wbox)
const BOX_MAX := 12
## Окна стен Synty (сняты с картинки стен спереди): подоконник по высоте и окна [середина вдоль стены, ширина]
const WIN := {"SM_Bld_Wall_Window_01": [0.65, [[1.25, 1.2]]], "SM_Bld_Wall_Window_02": [1.4, [[0.55, 0.42], [1.25, 0.42], [1.95, 0.42]]],
	"SM_Bld_Wall_Window_03": [1.4, [[1.25, 0.42]]], "SM_Bld_Wall_Window_04": [1.4, [[1.25, 1.75]]], "SM_Bld_Wall_Window_05": [0.65, [[1.25, 1.2]]]}
## Двери: [начало и конец проёма вдоль стены, верх проёма] (сняты с вершин стен Synty)
const DOOR := {"SM_Bld_Wall_Door_01": [0.7, 1.8, 2.05], "SM_Bld_Wall_Door_02": [0.75, 1.75, 2.85], "SM_Bld_Wall_Door_03": [0.75, 1.75, 2.75],
	"SM_Bld_Wall_Door_04": [0.75, 1.75, 1.97], "SM_Bld_Wall_Door_Double_01": [0.25, 2.25, 1.97], "SM_Bld_Wall_Door_Double_03": [0.25, 2.25, 1.97],
	"SM_Bld_Wall_Door_Large_01": [0.65, 1.85, 2.6], "SM_Bld_Wall_Door_Large_02": [0.6, 1.9, 2.6], "SM_Bld_Wall_Door_Double_Large_01": [0.3, 2.2, 2.47]}
## Каменное обрамление двери выступает из стены дальше её лица
const DOOR_FRAME := {"SM_Bld_Wall_Door_02": 0.13, "SM_Bld_Wall_Door_03": 0.175}
## (05–07 снова в ходу: их листья чернели от изнанки — у листвы «с изнанкой» теперь отсечение задней стороны,
## Synty._two_faced; проверено на стенах лицом на все четыре стороны в 11:00 и 16:30, test_street_synty ivytest=1)
const IVY := ["SM_Env_Ivy_Flowers_01", "SM_Env_Ivy_Flowers_02", "SM_Env_Ivy_Flowers_03", "SM_Env_Ivy_Flowers_04",
	"SM_Env_Ivy_Flowers_05", "SM_Env_Ivy_Flowers_06", "SM_Env_Ivy_Flowers_07"]
## Клетки signs.png (как SIGNS в deploy/kit/kit_houses.py): 6 столбцов × 7 рядов
const SIGNS := ["meat", "bread", "shoes", "dye", "togas", "pots", "oil", "lamps", "wine", "perfume", "jewel", "cloth", "barber", "medic",
	"thermo", "taberna", "fullonica", "mansio", "fruit", "veg", "fish", "fresco", "copper", "grain", "scriptorium", "school", "library",
	"academy", "warehouse", "vigiles", "herbalist", "sculptor", "catshop", "shelter", "balnea", "baths", "prefect", "arch_ins", "relief",
	"puppets", "mimes", "dice"]
## Вывеска над дверью лавки и общественного здания (рисунки Codex)
const TRADE_SIGN := {"butcher": "meat", "bakery": "bread", "cobbler": "shoes", "dyer": "dye", "tailor": "togas", "potter": "pots",
	"oilshop": "oil", "lamps": "lamps", "wineshop": "wine", "perfumer": "perfume", "jeweler": "jewel", "weaver": "cloth", "barber": "barber",
	"medic": "medic", "thermopolium": "thermo", "taberna": "taberna", "fullonica": "fullonica", "mansio": "mansio", "scriptorium": "scriptorium",
	"herbalist": "herbalist", "sculptor": "sculptor", "catshop": "catshop", "shelter": "shelter", "balnea": "balnea", "baths": "baths",
	"prefect": "prefect", "school": "school", "library": "library", "academy": "academy", "warehouse": "warehouse", "vigiles": "vigiles"}
## Товар у входа лавки — вещицы, что жители носят в руках (HandProps): окорока у мясника, сандалии у сапожника, бусы у ювелира
const TRADE_GOODS := {"butcher": "ham", "cobbler": "sandals", "jeweler": "necklace", "wineshop": "grapes"}
## Горшки на верёвках у двери — висят на железном кронштейне (#dress:hook): своего крюка у них нет
const HANG := ["SM_Prop_FlowerPot_Hanging_01", "SM_Prop_FlowerPot_Hanging_02", "SM_Prop_FlowerPot_Hanging_03"]
## Корзины, мешки и кувшины у входа лавки (сбоку от двери, проход свободен)
const STOCK := [["SM_Prop_Basket_Set_01", 0.42], ["SM_Prop_Sack_Stack_01", 0.42], ["SM_Prop_Basket_Set_02", 0.42], ["SM_Prop_Sack_Stack_02", 0.42],
	["SM_Prop_Jar_Pile_01", 0.5]]
const GRASS := ["SM_Env_Grass_01", "SM_Env_Grass_03", "SM_Env_Grass_01"]
const PEBBLES := ["SM_Env_Pebbles_01", "SM_Env_Pebbles_02"]
const BRICK_VARIANTS := 6


static func dress(b: Bp, type: String) -> void:
	var ident := _ident(b, type)                   # до первых деталей прохода: облик дома у земли
	var walls := []
	var ends := []
	var sum := Vector3.ZERO
	for p in b.parts:
		var nm := String(p[0])
		if nm == "SM_Bld_Wall_End_01":
			ends.append(p[1])
			continue
		if not nm.begins_with("SM_Bld_Wall_") or nm.contains("Tiny") or nm.contains("Balcony") or nm.contains("Trim") or nm.contains("Pillar") \
				or nm.contains("End") or nm.contains("Beam"):
			continue
		var xf: Transform3D = p[1]
		if xf.basis.y.length() < 0.9 or xf.basis.x.length() < 0.6:
			continue                                   # низкие парапеты террас и обрезки стен — не трогаем
		var c := xf * Bp.model_aabb(nm).get_center()
		walls.append([nm, xf, c])
		sum += c
	if walls.size() < 2:
		return
	var mid := sum / walls.size()
	# общее у дома (сколько плюща, облупилась ли штукатурка, угловые камни) — из зерна облика; у каждой стены — своё
	var hr := RandomNumberGenerator.new()
	hr.seed = hash([ident, "dress"])
	var shop := not type.begins_with("house_")
	var ivy_left := 2 if hr.randf() < 0.5 else 1
	# насколько у дома облупилась штукатурка: у половины домов — ничуть, у прочих — пара пятен
	var bricky := 0.0 if hr.randf() < 0.45 else hr.randf_range(0.25, 0.5)
	var brick_left := [hr.randi_range(1, 3)]
	var quoins := hr.randf() < 0.6
	var sign_at := []
	var bracket := false
	var boxes := [0]
	for w: Array in walls:
		var nm: String = w[0]
		var xf: Transform3D = w[1]
		var c: Vector3 = w[2]
		var rng := _wrng(ident, nm, xf.origin)
		var along := xf.basis.x.normalized()
		var n := xf.basis.z.normalized()
		var sx := xf.basis.x.length()
		var sy := xf.basis.y.length()
		var out := n if (c - mid).dot(n) > 0.0 else -n
		out.y = 0.0
		if out.length() < 0.5:
			continue
		out = out.normalized()
		var yaw := atan2(out.x, out.z)
		var o := xf.origin
		var ground := o.y < 1.0
		var face := FACE * xf.basis.z.length()
		# along смотрит вдоль стены; если стена повёрнута к нам изнанкой, «вдоль» для глаза снаружи — обратное:
		# у кронштейна и кирпичей это неважно, у вывески над дверью — середина проёма та же
		var at := func(u: float, v: float, d: float) -> Vector3: return o + along * u * sx + Vector3.UP * v * sy + out * (d + face)
		var front := out.z > 0.6
		if nm.contains("Window"):
			# ящики цветов ровно под окнами (у круглых отдушин — нет)
			# (ящиков Synty по 320–340 треугольников у трёхэтажного дома было до 25 — 8 тыс. треугольников. Теперь ящик свой,
			# лёгкий (fbox_mesh), сзади и сбоку чуть реже, на дом не больше BOX_MAX — под тремя окошками все три или ни одного,
			# и не второй ящик под окном, где он уже есть у строителя дома)
			var bp: float = (0.45 if shop else 0.85) * (1.0 if front else 0.9)
			if WIN.has(nm) and int(boxes[0]) + (WIN[nm][1] as Array).size() <= BOX_MAX and rng.randf() < bp:
				var wd: Array = WIN[nm]
				var bx: String = BOXES[rng.randi() % BOXES.size()]
				for e: Array in wd[1]:
					var bpos: Vector3 = at.call(float(e[0]), float(wd[0]) - 0.14, 0.12)
					if _has_box(b, bpos):
						continue
					_put(b, bx, bpos, yaw, Vector3(float(e[1]) * sx / 1.57 * 1.05, 0.4, 0.34))
					boxes[0] = int(boxes[0]) + 1
			# под высоким подоконником — отбитая штукатурка
			if WIN.has(nm) and float(WIN[nm][0]) > 1.0 and rng.randf() < bricky * 0.7:
				_bricks(b, at.call(rng.randf_range(0.6, 1.9), rng.randf_range(0.45, 0.8), 0.0), yaw, rng, 1.0, brick_left)
			if ground and rng.randf() < 0.35:
				_tuft(b, at, yaw, rng, 0.15 if rng.randf() < 0.5 else 2.35)
		elif nm.contains("Door"):
			var dd: Array = DOOR.get(nm, [0.75, 1.75, 1.97])
			var d0 := float(dd[0])
			var d1 := float(dd[1])
			var top := float(dd[2])
			var fr: float = DOOR_FRAME.get(nm, 0.0)
			if shop:
				if front and ground and TRADE_SIGN.has(type):
					var key := String(TRADE_SIGN[type])
					# вывеска над дверью — потом, над самым широким входом, где над проёмом есть место
					if top + 0.47 + 0.44 < 3.0:
						var hooks := []
						for hu: float in [WALL_W * 0.5 - 0.85, WALL_W * 0.5 + 0.85]:
							hooks.append(at.call(hu, minf(top + 0.05, 2.05), 0.2 + fr))
						sign_at.append([d1 - d0, at.call((d0 + d1) * 0.5, top + 0.47, 0.03 + fr), yaw, hooks])
					if not bracket:
						# вывеска на железном кронштейне поперёк стены — видна вдоль улицы
						var bu := d1 + 0.28 if d1 + 0.28 < WALL_W - 0.12 else d0 - 0.28
						if bu > 0.12:
							bracket = true
							_put(b, "#bsign:" + key, at.call(bu, 2.42, 0.0), yaw, Vector3.ONE * 1.1)
					# корзины и мешки сбоку от входа
					for side: float in [d0 - 0.4, d1 + 0.4]:
						if side > 0.25 and side < WALL_W - 0.25 and rng.randf() < 0.7:
							var st: Array = STOCK[rng.randi() % STOCK.size()]
							_put(b, String(st[0]), at.call(side, 0.0, 0.3 + fr), yaw + rng.randf_range(-0.4, 0.4), Vector3.ONE * float(st[1]))
				if ground and rng.randf() < 0.4:
					_tuft(b, at, yaw, rng, 0.12 if d0 > 0.5 else 2.38)
				continue
			if ground and rng.randf() < 0.8 and d0 > 0.5:
				for side: float in [d0 - 0.3, d1 + 0.3]:
					if rng.randf() < 0.8:
						var p0: Vector3 = at.call(side, 0.0, 0.32 + fr)
						_put(b, "SM_Prop_Vase_03", p0, rng.randf() * TAU, Vector3.ONE * 0.62)
						_put(b, CatDecor.BLOOMS[rng.randi() % CatDecor.BLOOMS.size()], p0 + Vector3(0, 0.36, 0), rng.randf() * TAU, Vector3.ONE * 0.22,
							{"tint": CatDecor.TRUE_COLOR})
			if rng.randf() < 0.55 and top < 2.3 and _door_pot(b, _winfo(b, w, mid), rng, d0 * sx, d1 * sx):
				pass
			elif d0 > 0.6 and rng.randf() < bricky * 0.6:
				_bricks(b, at.call(d0 * 0.45 if rng.randf() < 0.5 else (d1 + WALL_W) * 0.5 + 0.05, rng.randf_range(1.05, 1.5), 0.0), yaw, rng, 0.7, brick_left)
		else:
			var ivy := false
			if ivy_left > 0 and rng.randf() < 0.6:
				ivy_left -= 1
				ivy = true
				_put(b, IVY[rng.randi() % IVY.size()], at.call(WALL_W * (0.3 if rng.randf() < 0.5 else 0.7), 0.95, 0.02), yaw, Vector3(0.9, 1.15, 1.0))
			if nm == "SM_Bld_Wall_01" and not ivy and bricky > 0.0 and rng.randf() < bricky + 0.15:
				# кирпич под облупившейся штукатуркой: чаще внизу, у земли, иногда под карнизом
				var v := rng.randf_range(0.45, 1.0) if rng.randf() < 0.6 else rng.randf_range(1.5, 2.3)
				_bricks(b, at.call(rng.randf_range(0.55, 1.95), v, 0.0), yaw, rng, 1.0, brick_left)
				if rng.randf() < 0.3:
					_bricks(b, at.call(rng.randf_range(0.5, 2.0), clampf(3.0 - v, 0.5, 2.3), 0.0), yaw, rng, 0.65, brick_left)
			if ground and rng.randf() < 0.55:
				_tuft(b, at, yaw, rng, rng.randf_range(0.2, 2.3))
	if not sign_at.is_empty():
		sign_at.sort_custom(func(a: Array, c: Array) -> bool: return float(a[0]) > float(c[0]))
		var sg: Array = sign_at[0]
		var key := String(TRADE_SIGN[type])
		# вывеска над дверью, крупно; по бокам — товар на крюках
		_put(b, "#sign:" + key, sg[1], sg[2], Vector3(1.22, 1.22, 1.0))
		if TRADE_GOODS.has(type):
			for hp: Vector3 in sg[3]:
				_put(b, "#hp_" + String(TRADE_GOODS[type]), hp, float(sg[2]) + hr.randf_range(-0.3, 0.3), Vector3.ONE * 0.75)
	# каменные блоки на углах дома (через этаж кладка в перевязку), у части домов
	if quoins:
		for xf: Transform3D in ends:
			var rot := xf.basis.orthonormalized()
			var floors := maxi(1, int(round(xf.basis.y.length())))
			for k in floors:
				var p0 := xf.origin + Vector3.UP * Bp.FL * k
				_put_xf(b, "#quoin_%d" % (0 if p0.y < 1.0 else 1), Transform3D(rot, p0))
	_sides(b, type, walls, mid, ident)


# =====================================================================================
#     бока и зады домов и лавок (владелец 12.11: «боковые и задние стены пустые… слишком пустые места»)
# =====================================================================================
## Как на картинках Synty, где обжита каждая стена: сбоку у дома почти всегда плющ от земли или деревянная шпалера
## с цветущим плющом; у земли — амфоры, скамья с кувшином, снопы соломы, корзины и мешки, у задней
## стены тачка; у задней двери черепичный козырёк и фонарик, у окон без ставен — ставни; выше — бельё на верёвке,
## полочка с горшками, цветы на кронштейне; под карнизом верхнего этажа — концы балок. У лавок сбоку — скамья с товаром
## ремесла под черепичным козырьком, мешки и кувшины, знамя с эмблемой. Всё — только на свободное место стены: окна,
## двери, ящики цветов, плющ, балконы, ставни, вывески, лестница и снасть дворов мешают по своим габаритам (_spans).
## Случайность — своя у каждой стены (зерно: облик дома у земли и место стены): дом надстроили — у земли всё как было.
## Наружу сбоку — не дальше SIDE_OUT: между домами ряда 0,6 м (Game.ROW_GAP), вещи соседей не сходятся.
## Детали — небольшой набор Synty, те же во всём городе: вызовов отрисовки почти не прибавляется

const SIDE_OUT := 0.4             # родных метров (×0,72 в игре): у двух соседей вместе меньше промежутка ряда (0,83)
const BACK_OUT := 0.45            # = CatHouses.BACK: полоса за домом плебеев, что уже в его следе
## Уголки у земли: [ширина вдоль стены, высота]
## Вещи Synty — в мерках жителей (Citizen.SIZE 0,61 против Catalog.ARCH 0,72: человек в осях дома ~1,5 м), а не
## меньше: мелочь у огромной стены читается пустотой
## Треугольники дороги (вещи у всех домов города рисуются каждый кадр): плющ, шпалера, балки, ставни — по 20–250,
## поэтому их больше; амфоры, корзины, лавки — по 150–700, их у стены одна-две горки; тяжёлые (полки 3,5 тыс.,
## гирлянды горшков 1,4 тыс., корзины горой 2,9 тыс.) не ставим. На дом выходит ~3–5 тыс. треугольников
const NOOKS := {"jars": [1.1, 1.0], "bench": [1.75, 0.75], "straw": [1.15, 1.3], "baskets": [1.05, 0.75], "tools": [1.0, 1.5],
	"trellis": [1.5, 2.8], "vine": [1.95, 2.8], "cart": [1.6, 1.0], "display": [1.5, 1.35], "stock": [1.2, 0.9]}
## Откуда выбирать уголок: [вид, вес]
const NOOK_PICK := {
	"house_side": [["jars", 3], ["bench", 2], ["straw", 2], ["baskets", 2], ["trellis", 3], ["vine", 3]],
	"house_back": [["jars", 2], ["straw", 2], ["baskets", 2], ["cart", 2], ["bench", 1], ["trellis", 1]],
	"shop_side": [["display", 5], ["stock", 3], ["jars", 1], ["trellis", 1], ["vine", 1]],
	"shop_back": [["stock", 4], ["jars", 2], ["cart", 2], ["straw", 1]]}
## Лавки, что строит CatShops (у общественных зданий и CatExtra — своё убранство)
const DRESS_SHOPS := ["taberna", "mansio", "thermopolium", "fullonica"]
const JARS := ["SM_Prop_Vase_02", "SM_Prop_Vase_05", "SM_Prop_Jar_01", "SM_Prop_Vase_01"]
## Горка у стены: одна высокая амфора, рядом горшки пониже (они и легче: 220–260 треугольников против 360–450)
const JARS_BIG := ["SM_Prop_Vase_02", "SM_Prop_Vase_01", "SM_Prop_Vase_02"]
const JARS_SMALL := ["SM_Prop_Vase_04", "SM_Prop_Vase_06", "SM_Prop_Vase_04"]
## Цветы в подвесных горшках с кронштейном у стены (у 01–03 крюка нет — висели бы в воздухе)
const HOOK_POTS := ["SM_Prop_FlowerPot_Hanging_04", "SM_Prop_FlowerPot_Hanging_05", "SM_Prop_FlowerPot_Hanging_06"]
const SIDE_IVY := ["SM_Env_Ivy_Flowers_03", "SM_Env_Ivy_Flowers_04", "SM_Env_Ivy_Flowers_02", "SM_Env_Ivy_Flowers_06",
	"SM_Env_Ivy_Flowers_07"]
## Плющ от земли до карниза: широкие плети (цветущие и простые)
const CLIMB := ["SM_Env_Ivy_Flowers_08", "SM_Env_Ivy_Flowers_01", "SM_Env_Ivy_08", "SM_Env_Ivy_Flowers_02"]
## Наполнение боков и задов (выключается для снимков «было»: test_street_synty before=1)
static var sides_on := true
## Выключатель всего прохода (снимки «было»: Synty без наполнения — test_perf plain=1)
static var ON := true
## Шпалера — тёплое дерево (у Synty рейки белые: в тени светились, как пластик)
const WOOD := Color(0.78, 0.62, 0.45)
## Товар на полке у лавок без своего списка (CatShops.SHELVES): кувшины, ваза, корзинка
const GOODS := [["SM_Prop_Jug_03", 0.4], ["SM_Prop_Vase_04", 0.45], ["SM_Prop_Basket_06", 0.5], ["SM_Prop_Jug_01", 0.45]]
## Бельё и покрывала на верёвке: ковёр-«на перилах» Synty (76 треугольников), сплющенный в полотно; цвета — части
## атласа ковров (сливочные с узором, синий, рыжий)
const LINEN := ["03_A", "03_B", "03_C", "01_B", "03_A", "01_A"]
## Сколько чего уже у этого дома (бельё — до двух верёвок, у лавок и домусов одна; полочки — до двух)
static var _cnt := {}


static func _sides(b: Bp, type: String, walls: Array, mid: Vector3, ident: int) -> void:
	var shop := not type.begins_with("house_")
	if not sides_on or shop and not (CatShops.SHOPS.has(type) or DRESS_SHOPS.has(type)):
		return
	var infos := []
	for w: Array in walls:
		var wi := _winfo(b, w, mid)
		if not wi.is_empty():
			wi["i"] = infos.size()
			infos.append(wi)
	# сначала нижние стены: что у земли, не зависит от того, что потом встанет на этажах выше
	_fix_ivy(b, infos)
	for wi: Dictionary in infos:
		wi["k"] = int(round(float(wi["y0"]) / Bp.FL)) * 1000 + int(wi["i"])
	infos.sort_custom(func(a: Dictionary, c: Dictionary) -> bool: return int(a["k"]) < int(c["k"]))
	var hr := RandomNumberGenerator.new()
	hr.seed = ident
	var beams := hr.randf() < (0.4 if shop else 0.6)
	_cnt = {}
	for wi: Dictionary in infos:
		if wi["cat"] == "front":
			continue
		var rng := _wrng(ident, String(wi["nm"]) + "|side", wi["o"])
		var side: bool = wi["cat"] == "side"
		if float(wi["y0"]) < 1.0:
			# за домом ремесленника — двор-мастерская, за домусом — сад: там своя снасть
			if side or not type in ["house_artisan", "house_patrician"]:
				_ground(b, wi, rng, ("shop_" if shop else "house_") + String(wi["cat"]), type, SIDE_OUT if side else BACK_OUT)
		else:
			_upper(b, wi, rng, shop, type == "house_patrician")
		if _top(wi, infos):
			if beams:
				_beams(b, wi)
			elif rng.randf() < 0.55:
				_cascade(b, wi, rng)


## Плющ, что повесили раньше (строители дома и первый проход): поверх
## окна или за угол (половина плети в воздухе) — переносится на ближнее свободное место того же лица стены (можно ниже
## подоконника), а если места нет — убирается
static func _fix_ivy(b: Bp, infos: Array) -> void:
	var drop := []
	var faces := {}
	for i in b.parts.size():
		var nm := String(b.parts[i][0])
		if not (nm.begins_with("SM_Env_Ivy_Flowers_") or nm.begins_with("SM_Env_Ivy_0") or nm.begins_with("SM_Env_Ivy_1")):
			continue
		var xf: Transform3D = b.parts[i][1]
		var host := {}
		for w: Dictionary in infos:
			var r := xf.origin - (w["o"] as Vector3)
			var d := r.dot(w["out"]) - float(w["face"])
			var u := r.dot(w["al"])
			if d > -0.1 and d < 0.35 and u > -0.3 and u < float(w["len"]) + 0.3 and r.y > -0.2 and r.y < 3.0 * float(w["sy"]):
				host = w
				break
		if host.is_empty():
			continue
		if not faces.has(host["i"]):
			faces[host["i"]] = _face(host, infos)
		var fc: Dictionary = faces[host["i"]]
		var lh := _wbox(host, nm, xf.basis)
		var lo: Vector3 = lh[0]
		var hi: Vector3 = lh[1]
		var r := xf.origin - (host["o"] as Vector3)
		var rect := Rect2(r.dot(host["al"]) + lo.x, r.y + lo.y, hi.x - lo.x, hi.y - lo.y)
		if _ivy_ok(rect, fc):
			(fc["ivy"] as Array).append(rect)
			continue
		var best := Vector2.INF
		var cost := INF
		var dy := 0.0
		while rect.position.y + dy >= 0.3 or is_zero_approx(dy):
			var du := 0.0
			while du < fc["u1"] - fc["u0"]:
				for sg: float in [1.0, -1.0]:
					var q := Rect2(rect.position + Vector2(du * sg, dy), rect.size)
					var c := du + absf(dy) * 2.0
					if c < cost and _ivy_ok(q, fc):
						best = Vector2(du * sg, dy)
						cost = c
				du += 0.1
			dy -= 0.2
		if best == Vector2.INF:
			drop.append(i)
			continue
		b.parts[i][1] = Transform3D(xf.basis, xf.origin + (host["al"] as Vector3) * best.x + Vector3.UP * best.y)
		(fc["ivy"] as Array).append(Rect2(rect.position + best, rect.size))
	if drop.is_empty():
		return
	drop.reverse()
	for i: int in drop:
		b.parts.remove_at(i)
	var fp := {}
	for k: int in b.free_parts.keys():
		var sh := 0
		for i: int in drop:
			if i < k:
				sh += 1
		if not drop.has(k):
			fp[k - sh] = true
	b.free_parts = fp
	_bx_of = null


## Лицо стены host: все её пролёты той же плоскости на том же этаже — края [u0, u1] и проёмы окон и дверей (с рамой),
## в осях host
static func _face(host: Dictionary, infos: Array) -> Dictionary:
	var o: Vector3 = host["o"]
	var al: Vector3 = host["al"]
	var out: Vector3 = host["out"]
	var u0 := INF
	var u1 := -INF
	var opens := []
	for v: Dictionary in infos:
		if (v["out"] as Vector3).dot(out) < 0.95 or absf(((v["o"] as Vector3) - o).dot(out)) > 0.15 or absf(float(v["y0"]) - float(host["y0"])) > 0.5:
			continue
		var ua := ((v["o"] as Vector3) - o).dot(al)
		var sg := (v["al"] as Vector3).dot(al)
		u0 = minf(u0, minf(ua, ua + float(v["len"]) * sg))
		u1 = maxf(u1, maxf(ua, ua + float(v["len"]) * sg))
		for op: Rect2 in WallDecor.OPEN.get(v["nm"], []):
			var a := ua + op.position.x * float(v["sx"]) * sg
			var e := ua + op.end.x * float(v["sx"]) * sg
			opens.append(Rect2(minf(a, e) - 0.1, op.position.y * float(v["sy"]) - 0.1, absf(e - a) + 0.2, op.size.y * float(v["sy"]) + 0.2))
	return {"u0": u0, "u1": u1, "open": opens, "ivy": [], "top": 2.8 * float(host["sy"])}


static func _ivy_ok(r: Rect2, fc: Dictionary) -> bool:
	if r.position.x < float(fc["u0"]) + 0.03 or r.end.x > float(fc["u1"]) - 0.03 or r.end.y > float(fc["top"]) or r.position.y < -0.05:
		return false
	for op: Rect2 in fc["open"]:
		if op.intersects(r):
			return false
	for iv: Rect2 in fc["ivy"]:
		if iv.grow(-0.15).intersects(r):
			return false
	return true


## Стена из первого прохода: наружу, вдоль, размеры (родные метры чертежа)
static func _winfo(b: Bp, w: Array, mid: Vector3) -> Dictionary:
	var xf: Transform3D = w[1]
	var c: Vector3 = w[2]
	var n := xf.basis.z.normalized()
	n.y = 0.0
	if n.length() < 0.5:
		return {}
	n = n.normalized()
	# наружу — где нет нутра дома (#dark/#lit): у лавки с террасой середина всех стен уходит назад, и стена комнаты
	# наверху к террасе по середине смотрела бы «внутрь»; нутра не нашлось ни с одной стороны — от середины дома
	var pin := _inside(b, c + n * 0.45)
	var nin := _inside(b, c - n * 0.45)
	var out := (-n if pin else n) if pin != nin else (n if (c - mid).dot(n) > 0.0 else -n)
	var sx := xf.basis.x.length()
	return {"nm": String(w[0]), "xf": xf, "o": xf.origin, "al": xf.basis.x.normalized(), "out": out, "yaw": atan2(out.x, out.z), "sx": sx,
		"sy": xf.basis.y.length(), "len": WALL_W * sx, "face": FACE * xf.basis.z.length(), "y0": xf.origin.y,
		"cat": "front" if out.z > 0.6 else ("back" if out.z < -0.6 else "side"),
		# у бока к улице край стены свободнее: у угла фасада свои горшки и ступени, вещи не выходят на линию фасада
		"m0": 0.65 if absf(out.x) > 0.6 and xf.basis.x.z < 0.0 else 0.2, "m1": 0.65 if absf(out.x) > 0.6 and xf.basis.x.z > 0.0 else 0.2}


## Точка p — в нутре дома (в тёмной коробке #dark/#lit за окнами)
static func _inside(b: Bp, p: Vector3) -> bool:
	for q: Array in b.parts:
		var nm := String(q[0])
		if nm != "#dark" and nm != "#lit":
			continue
		var l := (q[1] as Transform3D).affine_inverse() * p
		if absf(l.x) < 0.5 and absf(l.y) < 0.5 and absf(l.z) < 0.5:
			return true
	return false


## Точка у стены w: u — вдоль от её начала, y — от низа стены, d — от лица стены наружу
static func _wpt(w: Dictionary, u: float, y: float, d: float) -> Vector3:
	return (w["o"] as Vector3) + (w["al"] as Vector3) * u + Vector3.UP * y + (w["out"] as Vector3) * (float(w["face"]) + d)


## Габарит детали nm с поворотом bs в осях стены w: [низ-зад-начало, верх-перёд-конец] (x — вдоль, y — вверх, z — наружу)
static func _wbox(w: Dictionary, nm: String, bs: Basis) -> Array:
	var al: Vector3 = w["al"]
	var out: Vector3 = w["out"]
	var box := Bp.model_aabb(nm)
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for k in 8:
		var q := bs * box.get_endpoint(k)
		var v := Vector3(q.dot(al), q.y, q.dot(out))
		lo = lo.min(v)
		hi = hi.max(v)
	return [lo, hi]


## Поворот вещи у стены w: turn — вокруг вертикали (в своих осях), tilt — наклон верхом к стене, s — масштаб
static func _wbasis(w: Dictionary, s: Vector3, turn := 0.0, tilt := 0.0) -> Basis:
	return Basis(Vector3.UP, float(w["yaw"])) * Basis(Vector3.RIGHT, -tilt) * Basis(Vector3.UP, turn) * Basis.from_scale(s)


## Вещь у стены w: середина габарита вдоль стены — в u; по высоте точка ay (0 — низ, 1 — верх) — на y от низа стены;
## по глубине точка ad (0 — задний край, 0,5 — середина) — в d от лица стены. Возвращает габарит (ширина, высота, вынос)
static func _place(b: Bp, w: Dictionary, nm: String, bs: Basis, u: float, y: float, d: float, ay := 0.0, ad := 0.0, remap := {}) -> Vector3:
	var lh := _wbox(w, nm, bs)
	var lo: Vector3 = lh[0]
	var sz: Vector3 = (lh[1] as Vector3) - lo
	_put_xf(b, nm, Transform3D(bs, _wpt(w, u - lo.x - sz.x * 0.5, y - lo.y - sz.y * ay, d - lo.z - sz.z * ad)), remap)
	return sz


## Вещь у земли (или на полке) у стены: низ — на y, задний край — в gap от лица; если выходит дальше maxd — меньше
static func _lean(b: Bp, w: Dictionary, nm: String, u: float, y: float, s: float, turn := 0.0, tilt := 0.0, gap := 0.03, maxd := 9.0,
		remap := {}) -> Vector3:
	var bs := _wbasis(w, Vector3.ONE * s, turn, tilt)
	var lh := _wbox(w, nm, bs)
	var dep: float = (lh[1] as Vector3).z - (lh[0] as Vector3).z
	if gap + dep > maxd:
		bs = _wbasis(w, Vector3.ONE * s * maxf(0.3, (maxd - gap) / dep), turn, tilt)
	return _place(b, w, nm, bs, u, y, gap, 0.0, 0.0, remap)


## Что уже занимает стену w в полосе высот y0…y1 (от низа стены) не дальше dmax от её лица: проёмы окон и дверей
## и все детали перед ней — промежутки вдоль стены [u0, u1]. flat_ok — плющ, роспись и таблички на стене не мешают
## (амфоры и скамья могут стоять перед плющом)
static func _spans(b: Bp, w: Dictionary, y0: float, y1: float, dmax: float, flat_ok := false) -> Array:
	var res := []
	var sx: float = w["sx"]
	var sy: float = w["sy"]
	for r: Rect2 in WallDecor.OPEN.get(w["nm"], []):
		if r.end.y * sy > y0 and r.position.y * sy < y1:
			res.append(Vector2(r.position.x * sx, r.end.x * sx))
	var o: Vector3 = w["o"]
	var al: Vector3 = w["al"]
	var out: Vector3 = w["out"]
	var face: float = w["face"]
	var len: float = w["len"]
	var bxs := _boxes(b)
	for i in b.parts.size():
		var nm := String(b.parts[i][0])
		if _no_block(nm, flat_ok):
			continue
		if nm.begins_with("SM_Bld_Wall_") and not nm.contains("Balcony") and _coplanar(w, b.parts[i][1]):
			continue
		var ab: AABB = bxs[i]
		var c := ab.get_center() - o
		var e := ab.size * 0.5
		var uc := c.dot(al)
		var ue := absf(al.x) * e.x + absf(al.z) * e.z
		var dc := c.dot(out) - face
		var de := absf(out.x) * e.x + absf(out.z) * e.z
		if dc + de < 0.03 or dc - de > dmax or c.y + e.y < y0 or c.y - e.y > y1 or uc + ue < 0.0 or uc - ue > len:
			continue
		res.append(Vector2(uc - ue, uc + ue))
	return res


## Габариты деталей чертежа b (в его осях), по номеру детали; дополняются по мере того, как ставятся новые
static var _bx := []
static var _bx_of: Bp = null
static func _boxes(b: Bp) -> Array:
	if _bx_of != b:
		_bx_of = b
		_bx = []
	for i in range(_bx.size(), b.parts.size()):
		var nm := String(b.parts[i][0])
		# (у вывесок «#sign:», «#bsign:» Bp.model_aabb — кубик 1 м: вывеска заняла бы полстены; у «#dress:» он настоящий)
		var own := nm.begins_with("#sign:") or nm.begins_with("#bsign:")
		_bx.append((b.parts[i][1] as Transform3D) * (kit_aabb(nm) if own else Bp.model_aabb(nm)))
	return _bx


static func _no_block(nm: String, flat_ok: bool) -> bool:
	if nm.begins_with("#dark") or nm.begins_with("#lit") or nm.begins_with("#bricks_") or nm.begins_with("#quoin_"):
		return true
	if nm.begins_with("SM_Bld_Trim") or nm.contains("Grass") or nm.contains("Pebbles"):
		return true
	return flat_ok and (nm.begins_with("SM_Env_Ivy_Flowers") or nm.begins_with("SM_Env_Ivy_0") or nm.begins_with("SM_Env_Ivy_1")
		or nm.begins_with("SM_Prop_Mural") or nm.begins_with("SM_Prop_Symbol"))


## Пролёт той же стены (та же плоскость, то же «наружу»)
static func _coplanar(w: Dictionary, xf: Transform3D) -> bool:
	var out: Vector3 = w["out"]
	return absf(xf.basis.z.normalized().dot(out)) > 0.95 and absf((xf.origin - (w["o"] as Vector3)).dot(out)) < 0.12


## Свободные промежутки стены длиной len: без занятых spans (с зазором gap) и краёв margin
static func _free(len: float, spans: Array, margin: float, gap: float, w := {}) -> Array:
	var fr := [Vector2(maxf(margin, float(w.get("m0", 0.0))), len - maxf(margin, float(w.get("m1", 0.0))))]
	for s: Vector2 in spans:
		var nx := []
		for f: Vector2 in fr:
			if s.y + gap <= f.x or s.x - gap >= f.y:
				nx.append(f)
				continue
			if s.x - gap > f.x:
				nx.append(Vector2(f.x, s.x - gap))
			if s.y + gap < f.y:
				nx.append(Vector2(s.y + gap, f.y))
		fr = nx
	return fr


## Середина свободного места шириной wd (−1 — такого нет)
static func _slot(fr: Array, wd: float, rng: RandomNumberGenerator) -> float:
	var ok := []
	for f: Vector2 in fr:
		if f.y - f.x >= wd:
			ok.append(f)
	if ok.is_empty():
		return -1.0
	var f: Vector2 = ok[rng.randi() % ok.size()]
	return rng.randf_range(f.x + wd * 0.5, f.y - wd * 0.5)


## Каменный цоколь у низа стены: x — насколько выступает (вещи у земли — перед ним), y — его верх (плющ и шпалера
## начинаются над ним, а не сквозь него)
static func _plinth(b: Bp, w: Dictionary) -> Vector2:
	var d := 0.0
	var h := 0.0
	for p: Array in b.parts:
		var nm := String(p[0])
		if nm != "SM_Bld_Trim_05":
			continue
		var lh := _wbox(w, nm, (p[1] as Transform3D).basis)
		var c := (p[1] as Transform3D).origin - (w["o"] as Vector3)
		if absf(c.y) > 0.3 or absf(c.dot(w["out"])) > 0.3:
			continue
		var u0: float = c.dot(w["al"]) + (lh[0] as Vector3).x
		var u1: float = c.dot(w["al"]) + (lh[1] as Vector3).x
		if u1 < 0.05 or u0 > float(w["len"]) - 0.05:
			continue
		d = maxf(d, c.dot(w["out"]) + (lh[1] as Vector3).z - float(w["face"]))
		h = maxf(h, c.y + (lh[1] as Vector3).y)
	return Vector2(clampf(d, 0.0, 0.2), clampf(h, 0.0, 0.6))


## Стена верхняя (над ней нет пролёта той же стены) — под её карнизом концы балок
static func _top(w: Dictionary, infos: Array) -> bool:
	var o: Vector3 = w["o"]
	var al: Vector3 = w["al"]
	var out: Vector3 = w["out"]
	for v: Dictionary in infos:
		if int(v["i"]) == int(w["i"]) or (v["out"] as Vector3).dot(out) < 0.95:
			continue
		var r := (v["o"] as Vector3) - o
		if absf(r.dot(out)) > 0.15:
			continue
		var dy := float(v["y0"]) - float(w["y0"])
		if dy < 1.0 or dy > 3.6:
			continue
		var ua := r.dot(al)
		var ub := ua + float(v["len"]) * (v["al"] as Vector3).dot(al)
		if minf(maxf(ua, ub), float(w["len"])) - maxf(minf(ua, ub), 0.0) > 0.3:
			return false
	return true


## Порядок, в каком пробовать уголки: случайно, по весам [вид, вес]
static func _order(pick: Array, rng: RandomNumberGenerator) -> Array:
	var left := pick.duplicate()
	var res := []
	while not left.is_empty():
		var tot := 0.0
		for e: Array in left:
			tot += float(e[1])
		var r := rng.randf() * tot
		var k := 0
		while k < left.size() - 1 and r > float(left[k][1]):
			r -= float(left[k][1])
			k += 1
		res.append(left[k][0])
		left.remove_at(k)
	return res


## У земли на стене w: один-два уголка (ctx — откуда выбирать, NOOK_PICK), у лавки сбоку иногда ещё знамя
static func _ground(b: Bp, w: Dictionary, rng: RandomNumberGenerator, ctx: String, type: String, maxd: float) -> void:
	var len: float = w["len"]
	var side: bool = w["cat"] == "side"
	var want := 1 if rng.randf() < (0.65 if side and not ctx.begins_with("shop") else 0.88) else 0
	if len > 3.5 and rng.randf() < 0.3:
		want += 1
	var pl := _plinth(b, w)
	var g0 := pl.x + 0.02
	var used := {}
	# сбоку у дома почти всегда что-то в рост — плющ от земли или шпалера (видно издали), потом мелочь у земли
	var tall_p: float = {"house_side": 0.85, "house_back": 0.3, "shop_side": 0.4}.get(ctx, 0.0)
	# (плющ дешёвый — 30–250 треугольников: на длинной стене иногда вторая плеть)
	var tall_n := 0
	if rng.randf() < tall_p:
		tall_n = 2 if len > 3.5 and rng.randf() < 0.45 else 1
	for tt in tall_n:
		for kind: String in (["vine", "trellis"] if rng.randf() < 0.55 else ["trellis", "vine"]):
			var nk: Array = NOOKS[kind]
			var u := _slot(_free(len, _spans(b, w, 0.0, float(nk[1]), maxd + 0.3), 0.2, 0.08, w), float(nk[0]), rng)
			if u >= 0.0:
				_nook(b, w, kind, u, rng, type, maxd, g0, pl.y)
				used["vine"] = true
				used["trellis"] = true
				break
	for t in want:
		for kind: String in _order(NOOK_PICK[ctx], rng):
			if used.has(kind) or (type == "house_patrician" and kind in ["tools", "straw", "cart"]):
				continue
			if (kind == "vine" and used.has("trellis")) or (kind == "trellis" and used.has("vine")):
				continue
			var nk: Array = NOOKS[kind]
			var tall := kind == "trellis" or kind == "vine"
			var u := _slot(_free(len, _spans(b, w, 0.0, float(nk[1]), maxd + 0.3, not tall), 0.2, 0.08, w), float(nk[0]), rng)
			if u < 0.0:
				continue
			_nook(b, w, kind, u, rng, type, maxd, g0, pl.y)
			used[kind] = true
			break
	if ctx == "shop_side" and rng.randf() < 0.55:
		_banner(b, w, rng, type)
	if String(w["nm"]).contains("Door") and w["cat"] == "back":
		if rng.randf() < 0.45:
			_door_canopy(b, w)
		if rng.randf() < 0.7:
			_door_lamp(b, w, rng)
	if String(w["nm"]) == "SM_Bld_Wall_Window_01" and rng.randf() < 0.75:
		_shutters(b, w)
	if rng.randf() < 0.35:
		_hooks(b, w, rng)


## Уголок у земли: kind — из NOOKS, середина вдоль стены u; maxd — насколько можно выйти от стены, g0 — зазор у цоколя
static func _nook(b: Bp, w: Dictionary, kind: String, u: float, rng: RandomNumberGenerator, type: String, maxd: float, g0: float,
		ph := 0.0) -> void:
	match kind:
		"jars":
			# три-четыре амфоры и кувшина у стены: одна большая, прочие поменьше
			var n := 2 + (1 if rng.randf() < 0.4 else 0)
			var big := rng.randi() % n
			var x := u - (n - 1) * 0.19
			for k in n:
				var nm: String = JARS_BIG[rng.randi() % JARS_BIG.size()] if k == big else JARS_SMALL[rng.randi() % JARS_SMALL.size()]
				var s := rng.randf_range(0.92, 1.0) if k == big else rng.randf_range(0.8, 0.95)
				_lean(b, w, nm, x + rng.randf_range(-0.03, 0.03), 0.0, s, rng.randf_range(-0.4, 0.4), 0.0, g0, maxd)
				x += 0.38
		"bench":
			# деревянная скамья, на ней кувшин или корзинка, рядом амфора
			var sz := _place(b, w, "SM_Prop_Seat_Bench_01", _wbasis(w, Vector3(0.78, 0.8, minf(0.8, (maxd - g0) / 0.51))), u, 0.0, g0)
			var e := 1.0 if rng.randf() < 0.5 else -1.0
			var it: Array = [["SM_Prop_Jug_03", 0.55], ["SM_Prop_Basket_12", 0.85], ["SM_Prop_Basket_07", 0.6]][rng.randi() % 3]
			_lean(b, w, it[0], u + e * 0.5, sz.y, float(it[1]), rng.randf_range(-0.5, 0.5), 0.0, g0 + 0.04, g0 + sz.z)
			# у края скамьи — горшок с цветами или амфора
			if rng.randf() < 0.5:
				_lean(b, w, "SM_Prop_FlowerPot_Fancy_01", u - e * 0.82, 0.0, 0.55, 0.0, 0.0, g0, maxd)
			else:
				_lean(b, w, JARS[rng.randi() % JARS.size()], u - e * 0.8, 0.0, 0.85, rng.randf_range(-0.4, 0.4), 0.0, g0, maxd)
		"straw":
			# снопы соломы прислонены к стене, рядом корзина
			_lean(b, w, "SM_Prop_Straw_Bundle_01", u - 0.34, 0.0, 0.66, rng.randf_range(-0.3, 0.3), 0.08, g0, maxd)
			_lean(b, w, "SM_Prop_Straw_Bundle_01", u + 0.02, 0.0, 0.6, rng.randf_range(0.6, 1.2), 0.06, g0, maxd)
			_lean(b, w, "SM_Prop_Basket_12", u + 0.42, 0.0, 0.9, rng.randf_range(-0.4, 0.4), 0.0, g0, maxd)
		"baskets":
			# большая корзина с плоской сверху, мешок
			var sz := _lean(b, w, "SM_Prop_Basket_10", u - 0.38, 0.0, 0.55, rng.randf_range(-0.3, 0.3), 0.0, g0, maxd)
			_lean(b, w, "SM_Prop_Basket_12", u - 0.38, sz.y, 0.72, rng.randf_range(-0.5, 0.5), 0.0, g0 + 0.03, maxd)
			_lean(b, w, "SM_Prop_Sack_05" if rng.randf() < 0.5 else "SM_Prop_Sack_01", u + 0.22, 0.0, 0.85, rng.randf_range(-0.5, 0.5), 0.0, g0, maxd)
		"tools":
			# (не выбирается: серп на гвозде издали — тёмная закорючка на стене, коса — странный столб)
			_lean(b, w, "SM_Prop_Sickle_01", u - 0.2, 1.05, 1.05, PI / 2, 0.0, 0.0, 0.1)
			_lean(b, w, "SM_Prop_Basket_07", u - 0.3, 0.0, 0.7, rng.randf_range(-0.4, 0.4), 0.0, g0, maxd)
			_lean(b, w, "SM_Prop_Sack_05", u + 0.12, 0.0, 0.8, rng.randf_range(-0.6, 0.6), 0.0, g0, maxd)
		"trellis":
			# шпалера из реек (дерево) над цоколем, по ней — плющ с цветами (перед рейками: внутри них листья темнели), у
			# корней трава
			var th := minf(2.6, _cornice(b, w) - 0.15) - ph
			var tsz := _place(b, w, "SM_Bld_Trellis_01", _wbasis(w, Vector3(0.54, th / 3.0, 0.8)), u, ph + 0.02, 0.0, 0.0, 0.0, {"tint": WOOD})
			var iv: String = SIDE_IVY[rng.randi() % SIDE_IVY.size()]
			var ib := Bp.model_aabb(iv)
			_place(b, w, iv, _wbasis(w, Vector3(1.3 / ib.size.x, (th - 0.2) / ib.size.y, 1.0)), u + rng.randf_range(-0.05, 0.05), ph + 0.12, tsz.z)
			if rng.randf() < 0.4:
				_lean(b, w, "SM_Prop_FlowerPot_Fancy_01", u + (0.55 if rng.randf() < 0.5 else -0.55), 0.0, 0.5, 0.0, 0.0, g0 + 0.04, maxd)
		"vine":
			# плющ от земли почти до карниза, у корней трава и камешки
			var iv: String = CLIMB[rng.randi() % CLIMB.size()]
			var ib := Bp.model_aabb(iv)
			var h := minf(2.7, _cornice(b, w) - 0.15) - ph
			_place(b, w, iv, _wbasis(w, Vector3(1.85 / ib.size.x, h / ib.size.y, 1.0)), u, ph + 0.02, 0.02)
			if rng.randf() < 0.6:
				_place(b, w, GRASS[rng.randi() % GRASS.size()], _wbasis(w, Vector3.ONE * 0.48, rng.randf_range(-0.5, 0.5)), u - 0.35, 0.0, g0)
		"cart":
			# тачка у стены, иногда мешок рядом
			var e := 1.0 if rng.randf() < 0.5 else -1.0
			var sz := _lean(b, w, "SM_Prop_Cart_02", u + e * 0.1, 0.0, 0.55, e * PI / 2, 0.0, g0, maxd)
			if rng.randf() < 0.6:
				_lean(b, w, "SM_Prop_Sack_01", u + e * 0.1 - e * (sz.x * 0.5 + 0.2), 0.0, 0.85, rng.randf_range(-0.6, 0.6), 0.0, g0, maxd)
		"display":
			_display(b, w, u, rng, type, maxd, g0)
		"stock":
			# мешки, корзины и кувшины горкой (запас лавки)
			_lean(b, w, "SM_Prop_Sack_05", u - 0.4, 0.0, 0.9, rng.randf_range(-0.3, 0.3), 0.0, g0, maxd)
			_lean(b, w, "SM_Prop_Sack_01", u - 0.05, 0.0, 0.95, rng.randf_range(-0.5, 0.5), 0.0, g0, maxd)
			_lean(b, w, JARS_BIG[rng.randi() % JARS_BIG.size()], u + 0.35, 0.0, 0.95, rng.randf_range(-0.4, 0.4), 0.0, g0, maxd)


## Полка с товаром ремесла у боковой стены лавки (товар — как на полках в глубине лавки), над ней — черепичный
## козырёк, если стена выше свободна
static func _display(b: Bp, w: Dictionary, u: float, rng: RandomNumberGenerator, type: String, maxd: float, g0: float) -> void:
	# каменная скамья-прилавок (полки Synty — по 3,5 тыс. треугольников), на ней товар ремесла, как на полках в лавке
	var sz := _place(b, w, "SM_Prop_Seat_Bench_01", _wbasis(w, Vector3(0.8, 1.1, minf(0.85, (maxd + 0.1 - g0) / 0.51))), u, 0.0, g0)
	var it: Array = CatShops.SHELVES.get(type, GOODS)
	var n := mini(it.size(), 2)
	for j in n:
		var e: Array = it[j]
		var ib := _wbasis(w, Vector3.ONE * float(e[1]) * 1.15, j * 0.7)
		_place(b, w, String(e[0]), ib, u + (j - (n - 1) * 0.5) * 0.45, sz.y, g0 + sz.z * 0.5, 0.0, 0.5, e[2] if e.size() > 2 else {})
	# козырёк над полкой — если до 1,8 м над ней стена свободна
	var y := sz.y + 0.18
	if rng.randf() < 0.45:
		return
	var fr := _free(float(w["len"]), _spans(b, w, y, y + 0.55, 0.65), 0.1, 0.03)
	for f: Vector2 in fr:
		if f.x <= u - 0.6 and f.y >= u + 0.6:
			_place(b, w, "SM_Prop_Overhang_02", _wbasis(w, Vector3(0.95, 0.9, 0.75)), u, y, 0.0)
			break


## Знамя с эмблемой ремесла на боковой стене лавки (как вывески-полотнища у дверей)
static func _banner(b: Bp, w: Dictionary, rng: RandomNumberGenerator, type: String) -> void:
	var letter: String = (CatShops.SHOPS.get(type, ["", "A"]) as Array)[1]
	var nm := "SM_Prop_Banner_02_" + letter
	var top := minf(2.55 * float(w["sy"]), _cornice(b, w) - 0.08)
	var bs := _wbasis(w, Vector3.ONE * 0.65)
	var lh := _wbox(w, nm, bs)
	var h: float = (lh[1] as Vector3).y - (lh[0] as Vector3).y
	var u := _slot(_free(float(w["len"]), _spans(b, w, top - h, top, 0.35), 0.25, 0.06), 0.78, rng)
	if u >= 0.0:
		_place(b, w, nm, bs, u, top, 0.0, 1.0)


## Выше первого этажа: ставни, бельё на верёвке, полочка с горшками, цветы на кронштейне
static func _upper(b: Bp, w: Dictionary, rng: RandomNumberGenerator, shop: bool, rich := false) -> void:
	var done := false
	if String(w["nm"]) == "SM_Bld_Wall_Window_01" and rng.randf() < 0.75:
		_shutters(b, w)
	if int(_cnt.get("laundry", 0)) < (1 if shop or rich else 2) and rng.randf() < (0.35 if shop or rich else 0.8):
		done = _laundry(b, w, rng)
		if done:
			_cnt["laundry"] = int(_cnt.get("laundry", 0)) + 1
	if int(_cnt.get("ledge", 0)) < 2 and rng.randf() < (0.35 if done else 0.7):
		if _ledge(b, w, rng):
			_cnt["ledge"] = int(_cnt.get("ledge", 0)) + 1
	if rng.randf() < 0.5:
		_hooks(b, w, rng)


## Каменная полочка под окном или на простенке, на ней два-три горшка с цветами
static func _ledge(b: Bp, w: Dictionary, rng: RandomNumberGenerator) -> bool:
	var y := 1.0 * float(w["sy"])
	var n := 2
	var wd := 0.44 * n + 0.14
	var u := _slot(_free(float(w["len"]), _spans(b, w, y - 0.1, y + 0.8, 0.5), 0.25, 0.06), wd, rng)
	if u < 0.0:
		return false
	var sz := _place(b, w, "SM_Bld_Floor_Trim_01", _wbasis(w, Vector3(wd / 2.5, 0.7, 0.4)), u, y - 0.098, 0.0)
	for k in n:
		_lean(b, w, "SM_Prop_FlowerPot_Fancy_01" if rng.randf() < 0.7 else "SM_Prop_Vase_04", u + (k - (n - 1) * 0.5) * 0.44, y, 0.5,
			rng.randf_range(-0.5, 0.5), 0.0, 0.0, sz.z)
	return true


## Черепичный козырёк над задней дверью (как над входом у домов с навесом)
static func _door_canopy(b: Bp, w: Dictionary) -> void:
	var r: Array = WallDecor.OPEN.get(w["nm"], [])
	if r.is_empty():
		return
	var op: Rect2 = r[0]
	var sx: float = w["sx"]
	var sy: float = w["sy"]
	var uc := op.get_center().x * sx
	var y := op.end.y * sy + 0.12
	var bs := _wbasis(w, Vector3(maxf(0.75, (op.size.x * sx + 0.4) / 1.18), 0.85, 0.7))
	var lh := _wbox(w, "SM_Prop_Overhang_02", bs)
	var hw: float = ((lh[1] as Vector3).x - (lh[0] as Vector3).x) * 0.5
	if uc - hw < 0.05 or uc + hw > float(w["len"]) - 0.05 or y + 0.5 > _cornice(b, w):
		return
	for s: Vector2 in _spans(b, w, y, y + 0.5, 0.6):
		if s.y > uc - hw and s.x < uc + hw and not (s.x >= op.position.x * sx - 0.01 and s.y <= op.end.x * sx + 0.01):
			return
	_place(b, w, "SM_Prop_Overhang_02", bs, uc, y, 0.0)


## Ставни у окна SM_Bld_Wall_Window_01 сбоку или сзади, если их ещё нет (как CatHouses._shutters: доска — стенка Synty
## с текстурой досок, цвет — как у ставен этого дома)
static func _shutters(b: Bp, w: Dictionary) -> void:
	var sx: float = w["sx"]
	var sy: float = w["sy"]
	for s: Vector2 in _spans(b, w, 0.8 * sy, 1.8 * sy, 0.3):
		if (s.y > 0.2 * sx and s.x < 0.58 * sx) or (s.y > 1.92 * sx and s.x < 2.3 * sx):
			return
	var rm := {}
	for p: Array in b.parts:
		var pr: Dictionary = p[2]
		if String(p[0]) == "SM_Bld_Wall_01" and pr.get("Stucco_White_01", "") == "Wood_02":
			rm = pr.duplicate(true)
			break
	if rm.is_empty():
		var col: Color = CatHouses.SHUTTERS[posmod(hash(b.tint.to_html()), CatHouses.SHUTTERS.size())]
		rm = {"Stucco_White_01": "Wood_02", "Stucco_Orange_01": "Wood_02", "tints": {"Wood_02": col}}
	var rot := (w["xf"] as Transform3D).basis.orthonormalized()
	for uu: float in [0.17, 1.89]:
		_put_xf(b, "SM_Bld_Wall_01", Transform3D(rot * Basis.from_scale(Vector3(0.176 * sx, 0.4 * sy, 0.3)), _wpt(w, uu * sx, 0.7 * sy, 0.045)), rm)


## Фонарик у задней двери (днём тёмный, ночью еле теплится, как у входа; своего света нет)
static func _door_lamp(b: Bp, w: Dictionary, rng: RandomNumberGenerator) -> void:
	var sx: float = w["sx"]
	var r: Array = WallDecor.OPEN.get(w["nm"], [])
	if r.is_empty():
		return
	var op: Rect2 = r[0]
	var a := op.position.x * sx
	var e := op.end.x * sx
	var sp := _spans(b, w, 1.7, 2.5, 0.5)
	for u: float in ([e + 0.2, a - 0.2] if rng.randf() < 0.5 else [a - 0.2, e + 0.2]):
		if u < 0.15 or u > float(w["len"]) - 0.15:
			continue
		var hit := false
		for s: Vector2 in sp:
			if s.y > u - 0.15 and s.x < u + 0.15 and not (s.x >= a - 0.01 and s.y <= e + 0.01):
				hit = true
				break
		if not hit:
			_put_xf(b, "#wall_lamp_dim", Transform3D(Basis(Vector3.UP, float(w["yaw"])), _wpt(w, u, 2.2, 0.0)))
			return


## Бельё на верёвке вдоль стены: два железных крюка, верёвка, на ней 2–4 полотна разной длины и цвета —
## над пустым простенком, а если там нет места — под подоконником (где под окном нет ящика цветов)
static func _laundry(b: Bp, w: Dictionary, rng: RandomNumberGenerator) -> bool:
	var sy: float = w["sy"]
	var d := 0.27
	for yr: float in [minf(2.3 * sy, _cornice(b, w) - 0.12), 1.24 * sy]:
		var fr := _free(float(w["len"]), _spans(b, w, yr - 1.02, yr + 0.12, 0.5), 0.2, 0.05)
		var wd := rng.randf_range(1.5, 2.1)
		var u := _slot(fr, wd, rng)
		if u < 0.0:
			wd = 1.2
			u = _slot(fr, wd, rng)
		if u < 0.0:
			continue
		var a := u - wd * 0.5
		var e := u + wd * 0.5
		for x: float in [a, e]:
			_place(b, w, "SM_Prop_Bracket_01", _wbasis(w, Vector3(1.6, 1.2, (d + 0.02) / 0.2)), x, yr + 0.03, 0.0, 1.0)
		_place(b, w, "SM_Prop_Beam_01", _wbasis(w, Vector3(wd / 2.5, 0.13, 0.12)), u, yr, d, 0.5, 0.5)
		var x := a + rng.randf_range(0.08, 0.14)
		while true:
			var wc := rng.randf_range(0.42, 0.72)
			if x + wc > e - 0.06:
				break
			var hc := rng.randf_range(0.55, 0.95)
			var rm := CatShops._rug(String(LINEN[rng.randi() % LINEN.size()]))
			_place(b, w, "SM_Prop_Rug_Drape_01", _wbasis(w, Vector3(wc / 1.14, hc / 0.8, 0.12)), x + wc * 0.5, yr + 0.04, d, 1.0, 0.5, rm)
			x += wc + rng.randf_range(0.04, 0.1)
		return true
	return false


## Цветы в подвесном горшке на кронштейне под карнизом
static func _hooks(b: Bp, w: Dictionary, rng: RandomNumberGenerator) -> void:
	var top := minf(2.45 * float(w["sy"]), _cornice(b, w) - 0.06)
	var u := _slot(_free(float(w["len"]), _spans(b, w, top - 1.1, top + 0.05, 0.6), 0.25, 0.08), 0.6, rng)
	if u >= 0.0:
		_place(b, w, HOOK_POTS[rng.randi() % HOOK_POTS.size()], _wbasis(w, Vector3.ONE * 0.72), u, top, 0.0, 1.0)


## Низ карниза над стеной w (от низа стены); нет карниза — под самым верхом стены
static func _cornice(b: Bp, w: Dictionary) -> float:
	var sy: float = w["sy"]
	var best := 2.95 * sy
	var o: Vector3 = w["o"]
	for p: Array in b.parts:
		var nm := String(p[0])
		if not nm.begins_with("SM_Bld_Trim_0") or nm == "SM_Bld_Trim_05":
			continue
		var xf: Transform3D = p[1]
		var lh := _wbox(w, nm, xf.basis)
		var c := xf.origin - o
		var lo: Vector3 = (lh[0] as Vector3) + Vector3(c.dot(w["al"]), c.y, c.dot(w["out"]) - float(w["face"]))
		var hi: Vector3 = (lh[1] as Vector3) + Vector3(c.dot(w["al"]), c.y, c.dot(w["out"]) - float(w["face"]))
		if hi.z < -0.05 or lo.z > 0.6 or hi.x < 0.1 or lo.x > float(w["len"]) - 0.1 or lo.y < 1.6 * sy or lo.y > 3.2 * sy:
			continue
		best = minf(best, lo.y)
	return best


## Плющ свешивается из-под карниза верхнего этажа (у домов без концов балок); плеть Synty «на парапете» — её
## верх уходит под карниз, видна свисающая часть; окна под ней не закрывает
const CASCADE := ["SM_Env_Ivy_Draped_Flowers_01", "SM_Env_Ivy_Draped_Flowers_03", "SM_Env_Ivy_Draped_Flowers_02", "SM_Env_Ivy_Draped_01"]
static func _cascade(b: Bp, w: Dictionary, rng: RandomNumberGenerator) -> void:
	if w["cat"] == "front":
		return
	var cb := _cornice(b, w)
	var nm: String = CASCADE[rng.randi() % CASCADE.size()]
	var bs := _wbasis(w, Vector3(0.75, 0.85, 0.8))
	var lh := _wbox(w, nm, bs)
	var sz: Vector3 = (lh[1] as Vector3) - (lh[0] as Vector3)
	var u := _slot(_free(float(w["len"]), _spans(b, w, cb - sz.y, cb - 0.02, 0.5), 0.15, 0.05), sz.x, rng)
	if u >= 0.0:
		_place(b, w, nm, bs, u, cb + 0.04, 0.14, 1.0, 1.0)


## Концы балок перекрытия под карнизом верхнего этажа (Wall_Beam_Detail: четыре торца на пролёт 2,5 м)
static func _beams(b: Bp, w: Dictionary) -> void:
	if w["cat"] == "front":
		return
	var len: float = w["len"]
	var cb := _cornice(b, w)
	var bh := 0.16
	var y := cb - 0.02 - bh
	var n := maxi(1, int(round(len / WALL_W)))
	var seg := len / n
	var sp := _spans(b, w, y - 0.04, cb - 0.01, 0.45)
	for k in n:
		var a := k * seg + 0.2
		var e := (k + 1) * seg - 0.2
		var hit := false
		for s: Vector2 in sp:
			if s.y > a and s.x < e:
				hit = true
				break
		if not hit:
			_place(b, w, "SM_Bld_Wall_Beam_Detail_01", _wbasis(w, Vector3(seg / WALL_W, 1.0, 1.0)), (k + 0.5) * seg, y, 0.0)


## Зерно случайности прохода — облик здания, а не его детали: свой поток случайности чертежа (Bp.rng). У жилья это
## поток «g» CatHouses (класс, облик, цвет — без этажности: дом надстроили — у нижних стен всё как было), у лавок —
## ключ Catalog (тип, этажи, облик, цвет). Строитель дома добавил горшок или ступень — наполнение не перетасовывается
static func _ident(b: Bp, type: String) -> int:
	return hash([type, b.rng.seed])


## Случайность стены: зерно облика и место стены (родные метры, с точностью 5 см) — другие стены её не сдвигают
static func _wrng(ident: int, nm: String, o: Vector3) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([ident, nm, o.snapped(Vector3.ONE * 0.05)])
	return r


## Под этим окном уже стоит ящик цветов (строитель дома ставит свои под окнами фасада)
static func _has_box(b: Bp, p: Vector3) -> bool:
	for q: Array in b.parts:
		if (String(q[0]).begins_with("SM_Prop_FlowerBed") or String(q[0]).begins_with("#dress:fbox")) \
				and (q[1] as Transform3D).origin.distance_to(p) < 0.45:
			return true
	return false


## Трава и камешки у подножия стены (u — место вдоль стены)
static func _tuft(b: Bp, at: Callable, yaw: float, rng: RandomNumberGenerator, u: float) -> void:
	_put(b, GRASS[rng.randi() % GRASS.size()], at.call(u, 0.0, 0.06), yaw + rng.randf_range(-0.5, 0.5), Vector3.ONE * rng.randf_range(0.28, 0.42))
	if rng.randf() < 0.35:
		_put(b, PEBBLES[rng.randi() % PEBBLES.size()], at.call(u + rng.randf_range(-0.3, 0.3), 0.0, 0.12), rng.randf() * TAU, Vector3.ONE * rng.randf_range(0.14, 0.22))


static func _bricks(b: Bp, p: Vector3, yaw: float, rng: RandomNumberGenerator, s := 1.0, left := [1]) -> void:
	if int(left[0]) <= 0:
		return
	left[0] = int(left[0]) - 1
	_put(b, "#bricks_%d" % (rng.randi() % BRICK_VARIANTS), p, yaw, Vector3.ONE * s * rng.randf_range(0.85, 1.15))


static func _put(b: Bp, nm: String, p: Vector3, yaw: float, s: Vector3, remap := {}) -> void:
	b.free_parts[b.parts.size()] = true
	b.parts.append([nm, Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(s), p), remap])


static func _put_xf(b: Bp, nm: String, xf: Transform3D, remap := {}) -> void:
	b.free_parts[b.parts.size()] = true
	b.parts.append([nm, xf, remap])


## Свои детали (Parts._special_mesh): #sign:<клетка>, #bsign:<клетка>, #bricks_<n>, #quoin_<0|1>, #dress:<имя> (dress_mesh)
static func kit_mesh(name: String) -> Mesh:
	if name.begins_with("#sign:"):
		return sign_mesh(name.substr(6))
	if name.begins_with("#dress:"):
		return dress_mesh(name.substr(7))
	if name.begins_with("#bsign:"):
		return bracket_sign_mesh(name.substr(7))
	if name.begins_with("#bricks_"):
		return bricks_mesh(int(name.substr(8)))
	if name.begins_with("#quoin_"):
		return quoin_mesh(int(name.substr(7)))
	return null


## Детали наполнения «#dress:<имя>» (габарит — настоящий, Bp.model_aabb): hook — железный кронштейн для горшка,
## fbox1/fbox2 — лёгкий ящик цветов
static func dress_mesh(nm: String) -> Mesh:
	if nm == "hook":
		return hook_mesh()
	if nm.begins_with("fbox"):
		return fbox_mesh(int(nm.substr(4)))
	if nm == "lantern":
		return lantern_mesh()
	if nm == "cord":
		return cord_mesh()
	if nm.begins_with("awning:"):
		var a := nm.split(":")
		return awning_mesh(int(a[1]), int(a[2]), int(a[3]))
	if nm == "garlic" or nm == "herbs":
		return bunch_mesh(nm == "garlic")
	if nm in ["boat", "oars", "coil", "net"]:
		return tackle_mesh(nm)
	push_warning("CatDress: нет детали #dress:" + nm)
	return null


## Лодочные снасти у маяка (в Synty их нет): boat — лодка вверх дном на двух колодах (корпус — как у лодок на прудах,
## Boats.hull_mesh; длина 2,45 вдоль Z), oars — пара вёсел стоймя (прислонить — наклоном), coil — бухта каната,
## net — сеть сушится на двух жердях с перекладиной (ячея — тонкие жерди, по низу — поплавки). Низ — у земли, лицом к +Z
static var _tackle := {}
static func tackle_mesh(nm: String) -> Mesh:
	if _tackle.has(nm):
		return _tackle[nm]
	var k := Kit.new()
	var wood := Color("8a6238")
	var rope := Color("b39a6a")
	match nm:
		"boat":
			for z: float in [-0.7, 0.75]:
				k.boxc(Vector3(0, 0.07, z), Vector3(0.9, 0.14, 0.22), Color("6e5a44"))
		"oars":
			for sx: float in [-0.09, 0.09]:
				k.boxc(Vector3(sx, 1.05, 0), Vector3(0.045, 1.6, 0.045), wood)                    # вальки
				k.boxc(Vector3(sx, 0.27, 0.0), Vector3(0.15, 0.54, 0.025), wood.darkened(0.1))    # лопасти внизу
		"coil":
			k.cyl(Vector3.ZERO, 0.24, 0.1, 9, rope)
			k.cyl(Vector3(0, 0.1, 0), 0.2, 0.05, 9, rope.darkened(0.08), 0.15)
			k.cyl(Vector3(0, 0.148, 0), 0.08, 0.004, 6, Color("4a3b28"))                   # дыра посредине
			k.rod(Vector3(0.22, 0.12, 0.05), Vector3(0.42, 0.02, 0.2), 0.022, 4, rope)        # конец каната
		"net":
			for sx: float in [-0.7, 0.7]:
				k.rod(Vector3(sx, 0, 0), Vector3(sx, 1.65, 0), 0.035, 4, wood)
			k.rod(Vector3(-0.78, 1.55, 0), Vector3(0.78, 1.55, 0), 0.03, 4, wood)
			var net := Color("5d5446")
			for i in 7:
				var x := -0.6 + i * 0.2
				k.rod(Vector3(x, 1.52, 0.0), Vector3(x + 0.03, 0.3 + absf(x) * 0.15, 0.03), 0.013, 3, net)
			for j in 5:
				var y := 0.42 + j * 0.25
				k.rod(Vector3(-0.62, y + 0.05, 0.02), Vector3(0.0, y - 0.06, 0.03), 0.013, 3, net)
				k.rod(Vector3(0.0, y - 0.06, 0.03), Vector3(0.62, y + 0.05, 0.02), 0.013, 3, net)
			for i in 4:
				k.boxc(Vector3(-0.45 + i * 0.3, 0.33 + absf(-0.45 + i * 0.3) * 0.12, 0.04), Vector3(0.07, 0.05, 0.05), Color("c9a25c"))
	var m := k.mesh()
	m.surface_set_material(0, Kit.material(0.9))
	if nm == "boat":
		# корпус вверх дном на колодах: Boats.hull_mesh, повёрнутый вокруг оси лодки
		var src := Boats.hull_mesh()
		var a: Array = src.surface_get_arrays(0)
		var R := Transform3D(Basis(Vector3(0, 0, 1), PI), Vector3(0, 0.14 + 0.42, 0))
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		for i in vs.size():
			vs[i] = R * vs[i]
			ns[i] = R.basis * ns[i]
		a[Mesh.ARRAY_VERTEX] = vs
		a[Mesh.ARRAY_NORMAL] = ns
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		m.surface_set_material(1, src.surface_get_material(0))
	_tackle[nm] = m
	return m


## Фонарь на цепи под балкой портика: начало — крюк вверху, цепь вниз, под ней фонарь, как у фонаря на кронштейне
## (то же стекло Parts: ночью светится вместе с фонарями города; своего света нет). Высота 0,6
static var _lantern: Mesh
static func lantern_mesh() -> Mesh:
	if _lantern != null:
		return _lantern
	var k := Kit.new()
	var glass := Kit.new()
	var bronze := Color("9a6a2c")
	var iron := Color("2b2622")
	k.boxc(Vector3(0, -0.012, 0), Vector3(0.09, 0.024, 0.09), iron, [])           # накладка на балке
	k.rod(Vector3(0, -0.02, 0), Vector3(0, -0.25, 0), 0.008, 4, iron)             # цепь
	var ly := -0.45
	k.cone(Vector3(0, ly + 0.1, 0), 0.13, 0.12, 4, bronze)                         # крышка
	k.cyl(Vector3(0, ly + 0.21, 0), 0.025, 0.04, 4, bronze)                        # кольцо
	k.boxc(Vector3(0, ly - 0.12, 0), Vector3(0.2, 0.03, 0.2), bronze, [])          # донце
	for c: Vector2 in [Vector2(-0.085, -0.085), Vector2(0.085, -0.085), Vector2(-0.085, 0.085), Vector2(0.085, 0.085)]:
		k.boxc(Vector3(c.x, ly - 0.01, c.y), Vector3(0.025, 0.2, 0.025), bronze, [])
	glass.boxc(Vector3(0, ly - 0.01, 0), Vector3(0.16, 0.18, 0.16), Color("ffd48a"), [])
	var m := k.mesh()
	m.surface_set_material(0, Kit.material(0.6))
	var g := glass.mesh()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, g.surface_get_arrays(0))
	m.surface_set_material(1, Parts._glass_material())
	_lantern = m
	return m


## Верёвка: тонкий шнур от начала вниз на 1 (длина — масштаб по y), на нём висит товар у края навеса
static var _cord: Mesh
static func cord_mesh() -> Mesh:
	if _cord == null:
		var k := Kit.new()
		k.rod(Vector3.ZERO, Vector3(0, -1, 0), 0.01, 4, Color("8a7350"))
		_cord = k.mesh()
		_cord.surface_set_material(0, Kit.material(0.9))
	return _cord


## Связка на верёвке: чеснок (круглые головки косой, по две на ряд) или пучок сушёных трав (стебли веером вниз,
## на концах — метёлки цветов); начало — узел вверху, длина ~0,4
static var _bunch := {}
static func bunch_mesh(garlic: bool) -> Mesh:
	if _bunch.has(garlic):
		return _bunch[garlic]
	var k := Kit.new()
	var twine := Color("8a7350")
	k.rod(Vector3.ZERO, Vector3(0, -0.06, 0), 0.01, 4, twine)
	if garlic:
		k.rod(Vector3(0, -0.06, 0), Vector3(0, -0.38, 0), 0.012, 4, Color("b9a77c"))    # коса из сухих стеблей
		for i in 4:
			var y := -0.1 - i * 0.08
			for sx: float in ([-0.035, 0.035] if i < 3 else [0.0]):
				var c := Color("f1ebdf") if (i + int(sx > 0.0)) % 2 == 0 else Color("e6d9de")
				# головка: снизу шире, кверху сужается в хвостик — две усечённые призмы
				k.cyl(Vector3(sx, y - 0.035, 0), 0.016, 0.03, 6, c, 0.042)
				k.cyl(Vector3(sx, y - 0.005, 0), 0.042, 0.035, 6, c, 0.01)
	else:
		var tie := Vector3(0, -0.08, 0)
		k.cyl(tie - Vector3(0, 0.02, 0), 0.022, 0.04, 5, twine)                    # перевязь
		for i in 5:
			var a := TAU * i / 5.0
			var end := tie + Vector3(cos(a) * 0.05, -0.24 - (i % 2) * 0.04, sin(a) * 0.05)
			k.rod(tie, end, 0.008, 4, Color("6f7a3e"))                                # стебель
			k.cone(end - Vector3(0, 0.07, 0), 0.028, 0.08, 4, Color("9a8fb5") if i % 2 == 0 else Color("b5a95e"))
	var m := k.mesh()
	m.surface_set_material(0, Kit.material(0.9))
	_bunch[garlic] = m
	return m


## Полосатый полотняный навес одним куском (полосами Synty — по 370 треугольников на полосу, навес лавки — до 4 тыс.;
## этот — ~14 на полосу): n полос двух цветов CatShops.CLOTH ca/cb, скат с лёгким провисом, спереди подзор с зубцом
## у каждой полосы, у края ската — светлый рубец. Обе стороны (снизу навес видят прохожие). Единичный: x 0…1 вдоль
## фасада, z 0…1 от стены к краю, y 0 у стены … −1 у края ската (масштаб — ширина, вынос, перепад); подзор — ещё
## AWN_VAL перепада вниз
const AWN_SAG := 0.14
const AWN_VAL := 0.45
static var _awn := {}
static func awning_mesh(n: int, ca: int, cb: int) -> Mesh:
	var key := "%d:%d:%d" % [n, ca, cb]
	if _awn.has(key):
		return _awn[key]
	n = clampi(n, 1, 24)
	var k := Kit.new()
	var cols := [cloth_color(ca), cloth_color(cb)]
	var hem := Color(CLOTH_HEM)
	var zs := [0.0, 0.45, 0.85, 1.0]
	var y_at := func(z: float) -> float: return -z - AWN_SAG * sin(PI * z)
	for i in n:
		var x0 := float(i) / n
		var x1 := float(i + 1) / n
		var xm := (x0 + x1) * 0.5
		var col: Color = cols[i % 2]
		for j in zs.size() - 1:
			var za: float = zs[j]
			var zb: float = zs[j + 1]
			_two(k, Vector3(x0, y_at.call(za), za), Vector3(x1, y_at.call(za), za), Vector3(x1, y_at.call(zb), zb), Vector3(x0, y_at.call(zb), zb), col)
		# подзор: полоса вниз от края ската, внизу зубец; по верху — светлый рубец
		var yt := -1.0
		var yh := yt - AWN_VAL * 0.18
		var yl := yt - AWN_VAL * 0.62
		var yp := yt - AWN_VAL
		_two(k, Vector3(x0, yt, 1.0), Vector3(x0, yh, 1.0), Vector3(x1, yh, 1.0), Vector3(x1, yt, 1.0), hem)
		_two(k, Vector3(x0, yh, 1.0), Vector3(x0, yl, 1.0), Vector3(x1, yl, 1.0), Vector3(x1, yh, 1.0), col)
		k.tri(Vector3(x0, yl, 1.0), Vector3(xm, yp, 1.0), Vector3(x1, yl, 1.0), col)
		k.tri(Vector3(x0, yl, 1.0), Vector3(x1, yl, 1.0), Vector3(xm, yp, 1.0), col)
	var m := k.mesh()
	m.surface_set_material(0, Kit.material(0.95))
	_awn[key] = m
	return m


## Четырёхугольник с обеих сторон (полотно)
static func _two(k: Kit, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	k.quad(a, b, c, d, col)
	k.quad(a, d, c, b, col)


## Цвет полотна CatShops.CLOTH[i] — главный цвет навеса Synty SM_Prop_Banner_Roof_01 с этой раскраской (снят с атласа:
## test_dress_probe cloth=1)
const CLOTH_COL := {0: "8e3a2e", 1: "a9a5a2", 2: "b887b0", 3: "6c8aa9", 4: "668b77", 5: "b06f24", 6: "b09024", 7: "46943b",
	8: "33669d", 9: "583c9c", 10: "9d3282", 11: "35383b"}
const CLOTH_HEM := "e9b069"            # рубец по краю навеса Synty
static func cloth_color(i: int) -> Color:
	var h: String = CLOTH_COL.get(posmod(i, 12), "c8553d")
	return Color(h)


static func _cell_uv(key: String) -> Rect2:
	var i := maxi(0, SIGNS.find(key))
	var cx := i % 6
	var cy := i / 6
	return Rect2(cx / 6.0 + 0.002, cy / 7.0 + 0.002, 1.0 / 6.0 - 0.004, 1.0 / 7.0 - 0.004)


## Картинка-четырёхугольник: углы a-b-c-d против часовой, если смотреть снаружи; ua… — их UV.
## В Godot лицевая сторона — по часовой, поэтому вершины идут в обратном порядке (как Kit.tri).
static func _pic(st: SurfaceTool, q: Array, uv: Array, nrm: Vector3) -> void:
	st.set_normal(nrm)
	for i: int in [0, 2, 1, 0, 3, 2]:
		st.set_uv(uv[i])
		st.add_vertex(q[i])


static var _sign_mat: StandardMaterial3D
static func _sign_material() -> StandardMaterial3D:
	if _sign_mat == null:
		_sign_mat = StandardMaterial3D.new()
		_sign_mat.albedo_texture = load("res://assets/kit/tex/signs.png")
		_sign_mat.roughness = 0.8
	return _sign_mat


## Вывеска на стене: доска из тёмного дерева, на лицевой стороне (+Z) — клетка signs.png; 1 × 0,67 (единицы чертежа)
static func sign_mesh(key: String) -> Mesh:
	var r := _cell_uv(key)
	var k := Kit.new()
	k.boxc(Vector3(0, 0, 0.0), Vector3(1.08, 0.74, 0.05), Color("5a3a22"), [])
	var am := k.mesh()
	am.surface_set_material(0, Kit.material(0.85))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.5
	var h := 0.335
	var z := 0.027
	_pic(st, [Vector3(-w, -h, z), Vector3(w, -h, z), Vector3(w, h, z), Vector3(-w, h, z)],
		[Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.position.y)], Vector3(0, 0, 1))
	st.commit(am)
	am.surface_set_material(1, _sign_material())
	return am


## Вывеска на кронштейне: железный прут из стены (+Z — от стены), под ним на кольцах доска поперёк стены,
## рисунок с обеих сторон (видно вдоль улицы). Начало — точка крепления на лице стены.
static func bracket_sign_mesh(key: String) -> Mesh:
	var r := _cell_uv(key)
	var k := Kit.new()
	var iron := Color("2b2622")
	k.rod(Vector3(0, 0, -0.02), Vector3(0, 0, 0.98), 0.022, 6, iron)
	k.rod(Vector3(0, -0.42, -0.02), Vector3(0, -0.02, 0.6), 0.016, 5, iron)            # подкос
	k.boxc(Vector3(0, 0, 0.0), Vector3(0.08, 0.1, 0.04), iron, [])                     # накладка на стене
	k.boxc(Vector3(0, -0.42, 0.0), Vector3(0.07, 0.08, 0.04), iron, [])
	k.cyl(Vector3(0, -0.035, 0.98), 0.035, 0.07, 6, iron)                              # шарик на конце
	for z: float in [0.25, 0.85]:
		k.rod(Vector3(0, 0, z), Vector3(0, -0.1, z), 0.008, 4, iron)                    # кольца
	var bh := 0.5
	var y0 := -0.1
	k.box(Vector3(-0.026, y0 - bh, 0.17), Vector3(0.026, y0, 0.93), Color("5a3a22"), [])
	k.box(Vector3(-0.03, y0 - 0.035, 0.15), Vector3(0.03, y0, 0.95), Color("3e2716"), [])    # верхняя планка
	var am := k.mesh()
	am.surface_set_material(0, Kit.material(0.8))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ya := y0 - bh + 0.03
	var yb := y0 - 0.05
	var za := 0.2
	var zb := 0.9
	var uvl := [Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.position.y)]
	# сторона +X: смотрящему «вправо» — это −Z
	_pic(st, [Vector3(0.028, ya, zb), Vector3(0.028, ya, za), Vector3(0.028, yb, za), Vector3(0.028, yb, zb)], uvl, Vector3(1, 0, 0))
	# сторона −X: «вправо» — это +Z
	_pic(st, [Vector3(-0.028, ya, za), Vector3(-0.028, ya, zb), Vector3(-0.028, yb, zb), Vector3(-0.028, yb, za)], uvl, Vector3(-1, 0, 0))
	st.commit(am)
	am.surface_set_material(1, _sign_material())
	return am


## Железный кронштейн для подвесного горшка у двери: накладка на стене, прут от стены (+Z) с подкосом, на конце
## шарик и крюк вниз. Начало — точка крепления прута на лице стены; горшок висит кольцом верёвок на крюке (HOOK_TIP).
## Один на весь город — одна сетка (MultiMesh), меньше 0,9 м — без тени
const HOOK_TIP := Vector3(0, -0.075, 0.36)
static var _hook: Mesh
static func hook_mesh() -> Mesh:
	if _hook != null:
		return _hook
	var k := Kit.new()
	var iron := Color("2b2622")
	k.boxc(Vector3(0, -0.07, 0.012), Vector3(0.07, 0.21, 0.024), iron, [])         # накладка на стене
	k.rod(Vector3(0, 0, 0.0), Vector3(0, 0, 0.42), 0.016, 6, iron)                   # прут
	k.rod(Vector3(0, -0.16, 0.012), Vector3(0, -0.012, 0.27), 0.011, 5, iron)         # подкос
	k.rod(Vector3(0, 0.0, HOOK_TIP.z), Vector3(0, HOOK_TIP.y - 0.01, HOOK_TIP.z), 0.008, 4, iron)   # крюк
	k.cyl(Vector3(0, -0.022, 0.42), 0.026, 0.044, 6, iron)                           # шарик на конце
	var am := k.mesh()
	am.surface_set_material(0, Kit.material(0.75))
	_hook = am
	return am


## Лёгкий ящик цветов (v: 1 — терракотовый, 2 — каменный): цветы и листья — те же поверхности, что у ящика Synty
## SM_Prop_FlowerBed_0<v> (та же картинка листвы, тот же материал), а сам ящик — простое корыто (20 треугольников
## вместо 200 у Synty: под цветами его почти не видно). Размеры и начало — как у ящика Synty: ставится так же
const FBOX_COL := [Color("b4643f"), Color("d6d0c3")]
static var _fbox := {}
static func fbox_mesh(v: int) -> Mesh:
	v = clampi(v, 1, 2)
	if _fbox.has(v):
		return _fbox[v]
	var src := Synty.make("SM_Prop_FlowerBed_0%d" % v)
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	var plants := {}                                # материал → [[сетка, поверхность, к началу модели]]
	for mi: MeshInstance3D in src.find_children("*", "MeshInstance3D", true, false):
		var rel := Citizen._rel(mi, src)
		for si in mi.mesh.get_surface_count():
			var mat := mi.get_surface_override_material(si)
			if mat != null and str(mat.get_meta("alb", "")).begins_with("PolygonAncientEmpire"):
				for q: Vector3 in mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
					lo = lo.min(rel * q)
					hi = hi.max(rel * q)
				continue
			if not plants.has(mat):
				plants[mat] = []
			(plants[mat] as Array).append([mi.mesh, si, rel])
	# корыто: дно уже верха, края с бортиком, сверху земля (её почти не видно за цветами)
	var k := Kit.new()
	var col: Color = FBOX_COL[v - 1]
	var dk := col.darkened(0.18)
	var e := Vector3(0.06, 0.0, 0.05)
	var b0 := Vector3(lo.x + e.x, lo.y, lo.z + e.z)
	var b1 := Vector3(hi.x - e.x, lo.y, hi.z - e.z)
	var t0 := Vector3(lo.x, hi.y, lo.z)
	var t1 := Vector3(hi.x, hi.y, hi.z)
	var c := [Vector3(b0.x, b0.y, b0.z), Vector3(b1.x, b0.y, b0.z), Vector3(b1.x, b0.y, b1.z), Vector3(b0.x, b0.y, b1.z)]
	var u := [Vector3(t0.x, t0.y, t0.z), Vector3(t1.x, t0.y, t0.z), Vector3(t1.x, t0.y, t1.z), Vector3(t0.x, t0.y, t1.z)]
	var mid := (lo + hi) * 0.5
	for i in 4:
		var j := (i + 1) % 4
		k.quad_out(c[i], c[j], u[j], u[i], col if i % 2 == 0 else dk, mid)
	k.quad_out(c[0], c[1], c[2], c[3], dk, mid)
	var sy := hi.y - 0.06
	k.quad_out(Vector3(t0.x + 0.05, sy, t0.z + 0.05), Vector3(t1.x - 0.05, sy, t0.z + 0.05), Vector3(t1.x - 0.05, sy, t1.z - 0.05),
		Vector3(t0.x + 0.05, sy, t1.z - 0.05), Color("4a3424"), mid - Vector3(0, 1, 0))
	var am := k.mesh()
	am.surface_set_material(0, Kit.material(0.9))
	for mat: Material in plants.keys():
		var st := SurfaceTool.new()
		for e2: Array in plants[mat]:
			st.append_from(e2[0], e2[1], e2[2])
		st.commit(am)
		am.surface_set_material(am.get_surface_count() - 1, mat)
	src.free()
	_fbox[v] = am
	return am


## Габарит своей детали по её сетке (у Bp.model_aabb для «#sign:», «#bsign:» — кубик 1 м)
static var _kab := {}
static func kit_aabb(nm: String) -> AABB:
	if not _kab.has(nm):
		var m := kit_mesh(nm)
		_kab[nm] = m.get_aabb() if m else AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE)
	return _kab[nm]


## Горшок на верёвках (HANG) на кронштейне у двери дома: сбоку от проёма, где на высоте горшка стена свободна (фонарь,
## табличка, горшки строителя дома, плющ мешают — _spans). Нашлось место — true
static func _door_pot(b: Bp, w: Dictionary, rng: RandomNumberGenerator, d0: float, d1: float) -> bool:
	if w.is_empty():
		return false
	var y := minf(2.5 * float(w["sy"]), _cornice(b, w) - 0.12)
	var nm: String = HANG[rng.randi() % HANG.size()]
	var s := 0.42
	var bs := _wbasis(w, Vector3.ONE * s, rng.randf() * TAU)
	var pb := Bp.model_aabb(nm)
	var top := Vector3(pb.get_center().x, pb.end.y, pb.get_center().z)
	var lh := _wbox(w, nm, bs)
	var hw: float = ((lh[1] as Vector3).x - (lh[0] as Vector3).x) * 0.5
	var low := y + HOOK_TIP.y - pb.size.y * s
	# (стена сжата вдоль фасада: у двери по бокам ~0,55 м — горшок встаёт вплотную к проёму, до края стены)
	var fr := _free(float(w["len"]), _spans(b, w, low - 0.04, y + 0.05, 0.7), 0.02, 0.03)
	var cands := [d1 + hw + 0.05, d0 - hw - 0.05]
	if rng.randf() < 0.5:
		cands.reverse()
	for u0: float in cands:
		for f: Vector2 in fr:
			# ближе к проёму — насколько позволяет свободное место с этой стороны двери
			if f.y - f.x < hw * 2.0 or (u0 > d1 and f.y < d1) or (u0 < d0 and f.x > d0):
				continue
			var u := clampf(u0, f.x + hw, f.y - hw)
			if absf(u - u0) < 0.3:
				var al: Vector3 = w["al"]
				var hook := _wpt(w, u, y, 0.0)
				_put_xf(b, "#dress:hook", Transform3D(Basis(Vector3.UP, float(w["yaw"])), hook))
				var tip := hook + Vector3.UP * HOOK_TIP.y + (w["out"] as Vector3) * HOOK_TIP.z + al * 0.0
				_put_xf(b, nm, Transform3D(bs, tip - bs * top + Vector3.UP * 0.01))
				return true
	return false


## Отбитая штукатурка: рваное пятно кирпичной кладки на лице стены (+Z — наружу), середина — начало координат.
## Тонкие римские кирпичи рядами вперевязку на светлом растворе, вокруг — тёмный край штукатурки.
const BRICK_COLS := ["a8634a", "9a5842", "b5715a", "8f5240", "b07d64", "9e6450", "a96e55"]
static func bricks_mesh(variant: int) -> Mesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7151 + variant * 97
	var k := Kit.new()
	var rows := rng.randi_range(5, 8)
	var bh := 0.062
	var gap := 0.016
	var pitch := bh + gap
	var bl := 0.24
	var hw := rng.randf_range(0.34, 0.5)
	var y_lo := -rows * pitch * 0.5
	var cx := 0.0
	for r in rows:
		var t := (r + 0.5) / rows * 2.0 - 1.0
		var w := hw * sqrt(maxf(0.0, 1.0 - t * t * 0.85)) * rng.randf_range(0.72, 1.12)
		cx = clampf(cx + rng.randf_range(-0.06, 0.06), -0.08, 0.08)
		var x0 := cx - w
		var x1 := cx + w
		var y := y_lo + r * pitch
		# край штукатурки и раствор (ступеньками по рядам, как отваливается штукатурка)
		k.box(Vector3(x0 - 0.03, y - 0.015, 0.0), Vector3(x1 + 0.03, y + pitch + 0.015, 0.004), Color("86664f"), ["bottom", "z-"])
		k.box(Vector3(x0 - 0.01, y, 0.0), Vector3(x1 + 0.01, y + pitch, 0.008), Color("bfae92"), ["bottom", "z-"])
		var off := (bl + gap) * 0.5 if r % 2 == 1 else 0.0
		var bx := x0 - off
		while bx < x1:
			var a := maxf(bx, x0)
			var e := minf(bx + bl, x1)
			if e - a > 0.05:
				var col := Color(BRICK_COLS[rng.randi() % BRICK_COLS.size()]).lerp(Color("6e3a26"), rng.randf() * 0.15)
				k.box(Vector3(a, y + gap * 0.5, 0.008), Vector3(e, y + gap * 0.5 + bh, rng.randf_range(0.018, 0.026)), col, ["bottom", "z-"])
			bx += bl + gap
	var am := k.mesh()
	am.surface_set_material(0, Kit.material(0.92))
	return am


## Угловые камни (кладка в перевязку): начало — середина торца угла Synty (SM_Bld_Wall_End_01), наружу — −X и +Z;
## 0 — первый этаж (над цоколем), 1 — верхние этажи (под карнизом)
static func quoin_mesh(variant: int) -> Mesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 911 + variant
	var k := Kit.new()
	var cx := -FACE
	var cz := FACE
	var t := 0.032
	var y := 0.48 if variant == 0 else 0.12
	var y_end := 2.62
	var n := int((y_end - y) / 0.36)
	var pitch := (y_end - y) / n
	var hgt := pitch - 0.035
	for i in n:
		var col := Color("dccfb6").lerp(Color("bfae92"), rng.randf() * 0.6)
		var long_a := i % 2 == 0
		var la := 0.46 if long_a else 0.28
		var lb := 0.28 if long_a else 0.46
		var y0 := y + i * pitch
		k.box(Vector3(cx - t, y0, cz), Vector3(cx + la, y0 + hgt, cz + t), col)            # по лицу +Z
		k.box(Vector3(cx - t, y0, cz - lb), Vector3(cx, y0 + hgt, cz), col)                # по лицу −X
	var am := k.mesh()
	am.surface_set_material(0, Kit.material(0.9))
	return am
