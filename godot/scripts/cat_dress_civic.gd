class_name CatDressCivic
extends RefCounted
## Наполнение рабочих и общественных зданий деталями Synty (владелец 12.11: склады и подобное «пустые, слишком
## пустые места», «по бокам ничего»; образец — картинки Synty POLYGON Ancient Empire, где обжит каждый двор и
## каждая стена): у склада — мешки, амфоры, корзины, дрова и доски вдоль стен; у мастерской — заготовки, инструмент,
## готовый товар; у поля — сено, корыто, корзины урожая, инструмент; у храма — дары, курильницы, цветы и знамёна;
## у бань — дрова для печи, полотенца, кувшины масла…
## Ставится после сборки облика (Catalog.make, рядом с CatDress.dress) в родных размерах Synty, до уменьшения.
## Каждая кучка проверяется целиком: не выходит за участок (рамка следа; за боковой стеной — не дальше SIDE_M:
## соседи в ряд встают через промежуток Game.ROW_GAP; сзади — BACK_M; спереди — полоса у фасада для мелочи, как
## горшки у домов), ни во что не врезается (стены, колонны, ступени, деревья, другие кучки), не загораживает вход,
## дорожку к нему, нишу со статуей и людей при деле (Catalog._actors); на мостовой, подиуме, столе — встаёт на верх.
## Землю не занимает (Bp.free_parts): след и правила постановки прежние. Только детали, что и так есть в городе.

const TYPES := ["warehouse", "sculptor", "herbalist", "vigiles", "scriptorium", "farm", "grove", "vineyard", "ogorod", "forum",
	"school", "library", "academy", "balnea", "baths", "temple", "prefect", "ludus", "thermae"]
## Поля и сады за изгородью: за изгородь ничего не выносим
const FENCED := ["farm", "grove", "vineyard", "ogorod"]
## Мягкое (трава, цветы, плющ, вывески, ткань, кирпичная кладка на стенах) — в него можно ставить
const SOFT := ["Grass", "SM_Env_Flowers", "Lillies", "Pebbles", "Ivy", "Vine", "SM_Prop_Rug_0", "#sign", "#bsign", "#bricks", "#quoin",
	"#hp_", "Crop_", "Straw_Field", "Banner", "Drapery", "Symbol", "Mural", "Overhang", "Trellis_Roof", "_Roof_", "Trim_0", "Trim_Large",
	"#lit", "Topper", "Ornament", "FlowerPot_Hanging", "Pots_Hanging", "#wall_lamp", "Rug_Drape", "Torch"]
## На что можно поставить сверху (ровный верх)
const SUPPORT := ["#marble", "SM_Bld_Base_Floor", "SM_Bld_Ground_01", "SM_Prop_Table_0", "SM_Prop_Plinth_0", "#sand", "SM_Bld_Floor_0"]
const SIDE_M := 0.41           # за боковой стеной (родные метры): соседи в ряд — через 0,6 м игры (0,83 родных), обоим хватит
const BACK_M := 1.1            # за задней стеной (0,8 м игры)
const HANG_M := 0.25           # висящее на стене (кашпо) — высоко: может выступать чуть дальше
const FRONT_M := 0.95          # полоса у фасада (как горшки и скамьи у домов)
const LOW := 1.4               # за рамкой следа — только невысокое
const CAP := 56                # деталей на здание (бюджет отрисовки)
const FACE := 0.115            # от середины стены Synty до её лица
## Что висит на стенах (на это второй проход не вешает): плющ, знамёна, кашпо, вывески, фонари, росписи, карнизы…
const WALL_DECOR := ["Ivy", "Banner", "FlowerPot_Hanging", "Pots_Hanging", "#wall_lamp", "Symbol", "Mural", "#sign", "#bsign", "#bricks",
	"Overhang", "FlowerBed", "#window_box", "Torch", "Rug_Drape", "Drapery", "Ornament", "Trim_0", "Balcony", "#quoin", "Trellis_0",
	"#shutters", "Beam_Detail", "SM_Prop_Beam", "SM_Bld_Door_0", "Statue", "Shield", "Lion"]
## Второй проход (стены и крыши): не больше стольких деталей на здание
const CAP2 := 40
## Цветущие кусты (как CatDecor.BLOOMS) — своим цветом, без зелёной подкраски
const BLOOM := ["SM_Env_Garden_Plants_03", "SM_Env_Garden_Plants_04", "SM_Env_Garden_Plants_06"]
## Выключатель (проверки «было/стало»: test_civic_synty dress=0)
static var ON := true
static var dbg := false        # печатать, почему кучка не встала (отладка: .work/civic_synty/dbg2.gd)


static func dress(b: Bp, type: String, _tier := 0) -> void:
	if not ON or not type in TYPES:
		return
	var x := _ctx(b, type)
	_walls_and_roofs(x, type)        # второй проход: стены и крыши (раньше кучек — кучки обходят шпалеры)
	match type:
		"warehouse": _warehouse(x)
		"sculptor": _sculptor(x)
		"herbalist": _herbalist(x)
		"vigiles": _vigiles(x)
		"scriptorium": _scriptorium(x)
		"farm": _farm(x)
		"grove": _grove(x)
		"vineyard": _vineyard(x)
		"ogorod": _ogorod(x)
		"forum": _forum(x)
		"school": _school(x)
		"library": _library(x)
		"academy": _academy(x)
		"balnea": _balnea(x)
		"baths": _baths(x)
		"temple": _temple(x)
		"prefect": _prefect(x)
		"ludus": _ludus(x)
		"thermae": _thermae(x)
	b._fp.clear()                 # след считали до наполнения (и до уменьшения) — пусть посчитается заново


# =====================================================================
#   проверка места
# =====================================================================

## Габариты детали в осях здания; core — у деревьев и кустов только ствол и низ кроны (как Bp.footprint)
static func _box_of(nm: String, xf: Transform3D, core := true) -> AABB:
	var bx: AABB
	if nm in ["#dark", "#marble", "#water", "#lit", "#sand"]:
		bx = AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
	elif nm in ["#wall_lamp", "#laundry", "#window_box"] or nm.begins_with("#shutters"):
		bx = Parts._special_mesh(nm).get_aabb()     # свои мелочи (фонарь, ставни, бельё) — по настоящим габаритам
	elif nm.begins_with("#quoin_") or nm.begins_with("#bricks_") or nm.begins_with("#sign:") or nm.begins_with("#bsign:"):
		bx = CatDress.kit_mesh(nm).get_aabb()       # угловые камни, кладка, вывески CatDress
	elif nm.begins_with("#hp_"):
		bx = AABB(Vector3(-0.15, -0.3, -0.05), Vector3(0.3, 0.35, 0.2))   # товар на крюке у лавки
	else:
		bx = Bp.model_aabb(nm)
		if nm.begins_with("SM_Env_Tree") or nm.begins_with("SM_Env_Bush"):
			var c := bx.get_center()
			bx = AABB(Vector3(c.x - bx.size.x * 0.15, bx.position.y, c.z - bx.size.z * 0.15), Vector3(bx.size.x * 0.3, minf(bx.size.y, 1.8), bx.size.z * 0.3))
		elif nm.begins_with("SM_Env_Garden"):
			var c := bx.get_center()
			var k := 0.3 if core else 0.7          # листва по краю редкая: свой куст — почти целиком
			bx = AABB(Vector3(c.x - bx.size.x * k * 0.5, maxf(bx.position.y, 0.0), c.z - bx.size.z * k * 0.5), Vector3(bx.size.x * k, bx.size.y, bx.size.z * k))
	return xf * bx


static func _soft(nm: String) -> bool:
	for w: String in SOFT:
		if nm.contains(w):
			return true
	return false


## Рабочий набор: что уже стоит (твёрдое, опоры), участок, запретные места, стены первого этажа
static func _ctx(b: Bp, type: String) -> Dictionary:
	var solid := []
	var sup := []
	var walls := []
	var sum := Vector3.ZERO
	var keep := []
	var ivy := []
	var wsolid := []              # что уже висит на стенах (плющ, знамёна, кашпо, вывески, карнизы) — на это не вешаем
	var ground := 0
	for p: Array in b.parts:
		var nm: String = p[0]
		var xf: Transform3D = p[1]
		for s: String in SUPPORT:
			if nm.begins_with(s):
				sup.append(_box_of(nm, xf))
				break
		if nm.begins_with("SM_Bld_Wall_") and not (nm.contains("Tiny") or nm.contains("Balcony") or nm.contains("Trim") or nm.contains("Pillar")
				or nm.contains("End") or nm.contains("Beam") or nm.begins_with("SM_Bld_Wall_Large")) \
				and xf.basis.y.length() > 0.9 and xf.basis.x.length() > 0.6:
			var c := xf * Bp.model_aabb(nm).get_center()
			walls.append([nm, xf, c])
			if xf.origin.y < 0.6:
				sum += c
				ground += 1
		if nm.begins_with("SM_Bld_Wall_Alcove"):
			# ниша со статуей: перед ней пусто
			var a := xf * Vector3(1.25, 0, 0.6)
			keep.append(Rect2(a.x - 1.0, a.z - 1.0, 2.0, 2.0))
		if nm.contains("Ivy") and not nm.contains("Pillar"):
			ivy.append(xf.origin)
		for wd: String in WALL_DECOR:
			if nm.contains(wd):
				wsolid.append(_box_of(nm, xf))
				break
		if _soft(nm):
			continue
		var bx := _box_of(nm, xf)
		if bx.position.y > 2.6:
			continue                              # висит высоко: внизу не мешает
		solid.append(bx)
	var mid := sum / maxf(1.0, ground)
	# участок — рамка следа (до наполнения)
	var lot := Rect2()
	var first := true
	for r: Rect2 in b.footprint():
		lot = r if first else lot.merge(r)
		first = false
	var fenced := type in FENCED
	var fz := b.front_z()
	var front := maxf(lot.end.y, fz + FRONT_M) if fz > -INF and not fenced else lot.end.y
	var sm := 0.0 if fenced else SIDE_M
	var bm := 0.0 if fenced else BACK_M
	var outer := Rect2(lot.position.x - sm, lot.position.y - bm, lot.size.x + 2.0 * sm, front - lot.position.y + bm)
	# вход и дорожка к нему от улицы
	var d := b.door
	keep.append(Rect2(d.x - 0.95, d.z - 1.9, 1.9, 4.2))
	for a: Array in b.actors:
		var q: Vector3 = a[0]
		keep.append(Rect2(q.x - 0.6, q.z - 0.6, 1.2, 1.2))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["civic", type, b.parts.size()])
	var wl := []
	for w: Array in walls:
		var xf: Transform3D = w[1]
		var n := xf.basis.z.normalized()
		var out := n if ((w[2] as Vector3) - mid).dot(n) > 0.0 else -n
		out.y = 0.0
		if out.length() < 0.5:
			continue
		out = out.normalized()
		var side := "front" if out.z > 0.7 else ("back" if out.z < -0.7 else ("left" if out.x < 0.0 else "right"))
		wl.append({"nm": w[0], "xf": xf, "out": out, "side": side, "f": int(round(xf.origin.y / Bp.FL))})
	return {"b": b, "solid": solid, "sup": sup, "lot": lot, "outer": outer, "front": front, "keep": keep, "rng": rng, "n": 0,
		"type": type, "walls": wl, "ivy": ivy, "wsolid": wsolid, "n2": 0}


## Можно ли поставить кучку с габаритами bx (низ — на земле, если не hang): на участке, не в запретном месте,
## ни во что не врезается. Возвращает подъём (верх мостовой, подиума, стола под ней) или −1, если нельзя
static func _fits(x: Dictionary, bx: AABB, hang := false, hang_out := Vector3.ZERO) -> float:
	var lot: Rect2 = x["lot"]
	var r2 := Rect2(bx.position.x, bx.position.z, bx.size.x, bx.size.z)
	if not lot.grow(0.02).encloses(r2):
		# за рамкой следа — только невысокое; спереди — только мелочь у фасада
		if bx.size.y > LOW and not hang:
			return _no("высоко за рамкой", bx)
		if not (x["outer"] as Rect2).grow(0.02 + (HANG_M if hang else 0.0)).encloses(r2):
			return _no("за участком %s" % [x["outer"]], bx)
		if r2.end.y > lot.end.y + 0.05 and (r2.size.y > 1.0 or r2.size.x > 1.8):
			return _no("крупное у фасада", bx)
	for k: Rect2 in x["keep"]:
		if k.intersects(r2):
			return _no("вход/люди", bx)
	var lift := 0.0
	if not hang:
		var inner := r2.grow(-0.06).abs() if r2.size.x > 0.13 and r2.size.y > 0.13 else r2
		for s: AABB in x["sup"]:
			if s.end.y < 1.25 and Rect2(s.position.x, s.position.z, s.size.x, s.size.z).encloses(inner):
				lift = maxf(lift, s.end.y)
	var sh := AABB(bx.position + Vector3(0.04, lift + 0.07, 0.04), (bx.size - Vector3(0.08, 0.1, 0.08)).max(Vector3.ONE * 0.01))
	if hang:
		# висит на стене: задняя часть (крюк, кронштейн) касается стены — её не проверяем
		var cut := Vector3(absf(hang_out.x), 0, absf(hang_out.z)) * 0.14
		sh = AABB(sh.position + Vector3(maxf(hang_out.x, 0.0), 0, maxf(hang_out.z, 0.0)) * 0.14, (sh.size - cut).max(Vector3.ONE * 0.01))
	for s: AABB in x["solid"]:
		if s.intersects(sh):
			return _no("задевает %s" % [s], bx)
	return lift


static func _no(why: String, bx: AABB) -> float:
	if dbg:
		print("CDC нет: ", why, " — ", bx)
	return -1.0


## Габариты кучки items ([[имя, Transform3D, раскраска], …]) в осях g
static func _items_box(items: Array, g: Transform3D) -> AABB:
	var bx := AABB()
	var first := true
	for it: Array in items:
		var ib := _box_of(String(it[0]), g * (it[1] as Transform3D), false)
		bx = ib if first else bx.merge(ib)
		first = false
	return bx


## Поставить кучку в точку p с поворотом yaw; slide — куда сдвигать, если место занято (по шагу в обе стороны,
## до трёх шагов). true — встала
static func _group(x: Dictionary, items: Array, p: Vector3, yaw := 0.0, slide := Vector3.ZERO, hang := false, hang_out := Vector3.ZERO) -> bool:
	if items.is_empty() or int(x["n"]) + items.size() > CAP:
		return false
	for k in 7:
		var off := Vector3.ZERO
		if k > 0:
			if slide == Vector3.ZERO:
				break
			off = slide * float((k + 1) / 2) * (1.0 if k % 2 == 1 else -1.0)
		var g := Transform3D(Basis(Vector3.UP, yaw), p + off)
		var bx := _items_box(items, g)
		var lift := _fits(x, bx, hang, hang_out)
		if lift < 0.0:
			continue
		_commit(x, items, Transform3D(Basis.IDENTITY, Vector3(0, lift, 0)) * g, AABB(bx.position + Vector3(0, lift, 0), bx.size))
		return true
	return false


static func _commit(x: Dictionary, items: Array, g: Transform3D, bx: AABB) -> void:
	var b: Bp = x["b"]
	for it: Array in items:
		b.free_parts[b.parts.size()] = true
		b.parts.append([String(it[0]), g * (it[1] as Transform3D), it[2] if it.size() > 2 else {}])
	(x["solid"] as Array).append(bx)
	x["n"] = int(x["n"]) + items.size()


## Одна деталь: имя, точка, поворот, масштаб
static func _put(x: Dictionary, nm: String, p: Vector3, yaw := 0.0, s := 1.0, slide := Vector3.ZERO, rm := {}) -> bool:
	return _group(x, [_it(nm, s, 0.0, Vector3.ZERO, rm)], p, yaw, slide)


static func _it(nm: String, s := 1.0, yaw := 0.0, off := Vector3.ZERO, rm := {}) -> Array:
	return [nm, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), off), rm]


static func _one(x: Dictionary, a: Array) -> Variant:
	return a[(x["rng"] as RandomNumberGenerator).randi() % a.size()]


static func _rf(x: Dictionary, a: float, c: float) -> float:
	return (x["rng"] as RandomNumberGenerator).randf_range(a, c)


static func _ch(x: Dictionary, p: float) -> bool:
	return (x["rng"] as RandomNumberGenerator).randf() < p


## Кучка из помощника, что строит прямо в чертёж (CatExtra._scarecrow, CatShops._basket…): строим во временный
## чертёж в начале координат и берём его детали как кучку
static func _from(f: Callable) -> Array:
	var t := Bp.new(1)
	f.call(t)
	var out := []
	for p: Array in t.parts:
		out.append([p[0], p[1], p[2]])
	return out


# =====================================================================
#   кучки (одинаковые во всём городе — те же детали Synty)
# =====================================================================

## Кучка по имени (лицом к +Z, длинная сторона — вдоль X)
static func _item(x: Dictionary, key: String) -> Array:
	match key:
		# ---- кучки-«уголки» для задней стены и дворов: разной высоты, не больше метра вглубь ----
		"store":                                   # мешки горой, сверху мешок, рядом корзина и амфора
			return [_it("SM_Prop_Sack_Stack_01", 0.85, _rf(x, -0.08, 0.08)),
				_it("SM_Prop_Sack_05", 0.8, _rf(x, -0.5, 0.5), Vector3(_rf(x, -0.2, 0.3), 0.6, 0.0)),
				_it("SM_Prop_Basket_0%d" % _one(x, [6, 7]), 0.8, _rf(x, 0.0, TAU), Vector3(1.0, 0, 0.04)),
				_it("SM_Prop_Vase_02", 0.85, _rf(x, 0.0, TAU), Vector3(-0.92, 0, 0.0))]
		"amphpile":                                # штабель амфор и амфоры с кувшином рядом
			return [_it("SM_Prop_Vase_Pile_04", 0.43, 0.0),
				_it("SM_Prop_Vase_02", 0.9, 0.0, Vector3(0.74, 0, 0.0)),
				_it("SM_Prop_Jug_03", 0.8, PI, Vector3(-0.7, 0, 0.0))]
		"jarpile":                                 # гора кувшинов, амфора, мешок
			return [_it("SM_Prop_Jar_Pile_01", 0.72, _rf(x, 0.0, TAU)),
				_it("SM_Prop_Vase_05", 0.8, _rf(x, 0.0, TAU), Vector3(0.72, 0, 0.0)),
				_it("SM_Prop_Sack_04", 0.82, _rf(x, -0.3, 0.3), Vector3(-0.68, 0, 0.05))]
		"wood":                                    # поленница, сноп, корзина
			return [_it("#mil_logs", 0.78), _it("SM_Prop_Straw_Bundle_01", 0.6, _rf(x, 0.0, TAU), Vector3(1.05, 0, 0.0)),
				_it("SM_Prop_Basket_01", 0.75, _rf(x, 0.0, TAU), Vector3(-1.0, 0, 0.05))]
		"goods":                                   # корзины с товаром, мешки стопкой
			return [_it("SM_Prop_Basket_Set_06", 0.8), _it("SM_Prop_Basket_Set_06_Insert_01", 0.8),
				_it("SM_Prop_Sack_Stack_02", 0.68, _rf(x, -0.1, 0.1), Vector3(1.05, 0, 0.0))]
		"timber":                                  # доски, бревно, лестница к стене
			return [_it("#mil_planks", 0.62), _it("#mil_logs", 0.55, 0.0, Vector3(1.25, 0, 0.0))]
		"herbbed":                                 # грядка трав у стены: три кустика и кувшин
			return [_it("SM_Env_Garden_Plants_02", 0.3, _rf(x, 0.0, TAU), Vector3(-0.5, 0, 0), {}),
				_it("SM_Env_Garden_Plants_05", 0.28, _rf(x, 0.0, TAU), Vector3(0.0, 0, 0.02), {}),
				_it("SM_Env_Garden_Plants_02", 0.26, _rf(x, 0.0, TAU), Vector3(0.5, 0, 0), {}),
				_it("SM_Prop_Jug_03", 0.6, 0.0, Vector3(0.85, 0, 0.05))]
		# ---- для боков: не глубже 0,38 (за боковой стеной мало места), разной высоты ----
		"sideA":
			return [_it("SM_Prop_Vase_02", 0.8, 0.0), _it("SM_Prop_Jar_01", 0.62, 0.0, Vector3(0.4, 0, 0.0)),
				_it("SM_Prop_Jug_03", 0.7, PI, Vector3(0.76, 0, 0.0))]
		"sideB":
			return [_it("SM_Prop_Sack_04", 0.8, 0.0), _it("SM_Prop_Sack_04", 0.74, PI + 0.2, Vector3(0.05, 0.36, 0.0)),
				_it("SM_Prop_Vase_05", 0.62, 0.0, Vector3(0.48, 0, 0.0))]
		"sideC":
			return [_it("SM_Prop_Basket_07", 0.7, 0.0), _it("SM_Prop_Vase_02", 0.78, 0.0, Vector3(0.42, 0, 0.0)),
				_it("SM_Prop_Basket_06", 0.62, 0.4, Vector3(0.0, Bp.model_aabb("SM_Prop_Basket_07").end.y * 0.7 - 0.02, 0.0))]
		"sacks":                                   # стопка мешков и сверху ещё мешок
			return [_it("SM_Prop_Sack_Stack_0%d" % (1 + int(_ch(x, 0.4))), 0.7, _rf(x, -0.1, 0.1)),
				_it("SM_Prop_Sack_0%d" % _one(x, [4, 5]), 0.65, _rf(x, -0.5, 0.5), Vector3(_rf(x, -0.25, 0.25), 0.5, 0.0))]
		"sack2":                                   # два мешка, прислонены друг к другу
			return [_it("SM_Prop_Sack_05", 0.75, _rf(x, -0.3, 0.3), Vector3(-0.25, 0, 0)),
				_it("SM_Prop_Sack_04", 0.75, _rf(x, -0.3, 0.3), Vector3(0.25, 0, 0.02))]
		"sack1":
			return [_it("SM_Prop_Sack_0%d" % _one(x, [4, 5]), 0.75, _rf(x, -0.4, 0.4))]
		"sackS":                                   # тонкое — для боков (за боковой стеной мало места)
			return [_it("SM_Prop_Sack_04", 0.72, 0.0, Vector3(-0.2, 0, 0)), _it("SM_Prop_Sack_04", 0.68, PI, Vector3(0.22, 0, 0.0))]
		"amphS":                                   # амфоры для боков: круглые, ровно
			var out := []
			var n := 2 + int(_ch(x, 0.5))
			for k in n:
				out.append(_it(String(_one(x, ["SM_Prop_Vase_02", "SM_Prop_Jar_01", "SM_Prop_Vase_05", "SM_Prop_Vase_02"])), 0.62, 0.0, Vector3((k - (n - 1) * 0.5) * 0.37, 0, 0)))
			return out
		"vaseS":                                   # ваза с цветами для боков
			return [_it("SM_Prop_Vase_03", 0.52, 0.0), _it(String(_one(x, BLOOM)), 0.18, _rf(x, 0.0, TAU), Vector3(0, 0.3, 0), {"tint": CatDecor.TRUE_COLOR})]
		"basketS":
			return [_it("SM_Prop_Basket_0%d" % _one(x, [6, 7]), 0.7, 0.0)]
		"amph2", "amph3":                          # амфоры рядком
			var n := 2 if key == "amph2" else 3
			var out := []
			for k in n:
				out.append(_it(String(_one(x, ["SM_Prop_Vase_05", "SM_Prop_Vase_02", "SM_Prop_Vase_05", "SM_Prop_Jar_01"])), 0.7 * _rf(x, 0.92, 1.05),
					_rf(x, 0.0, TAU), Vector3((k - (n - 1) * 0.5) * 0.4, 0, _rf(x, -0.04, 0.04))))
			return out
		"jars":
			return [_it("SM_Prop_Jar_Pile_01", 0.6, _rf(x, 0.0, TAU))]
		"vpile":                                   # штабель амфор
			return [_it("SM_Prop_Vase_Pile_02", 0.55, PI / 2)]
		"baskets":
			return [_it("SM_Prop_Basket_Set_02", 0.55, _rf(x, -0.3, 0.3))]
		"bgoods":                                  # корзины с товаром
			var s := 0.6
			return [_it("SM_Prop_Basket_Set_06", s), _it("SM_Prop_Basket_Set_06_Insert_01", s)]
		"bset":
			return [_it("SM_Prop_Basket_Set_01", 0.5), _it("SM_Prop_Basket_Set_01_Insert_01", 0.5)]
		"basket":
			return [_it("SM_Prop_Basket_0%d" % _one(x, [1, 6, 7]), 0.7, _rf(x, 0.0, TAU))]
		"logs":                                    # поленница
			return [_it("#mil_logs", 0.62)]
		"planks":
			return [_it("#mil_planks", 0.62)]
		"straw":                                   # снопы
			return [_it("SM_Prop_Straw_Bundle_01", 0.6, _rf(x, 0.0, TAU), Vector3(-0.17, 0, 0)),
				_it("SM_Prop_Straw_Bundle_01", 0.55, _rf(x, 0.0, TAU), Vector3(0.17, 0, 0.03))]
		"hay":                                     # копна сена
			return [_it("SM_Prop_Straw_Stack_01", 0.5, _rf(x, 0.0, TAU))]
		"ladder":                                  # лестница прислонена к стене (верх — к −Z)
			return [["SM_Prop_Ladder_01", Transform3D(Basis(Vector3.RIGHT, -0.2) * Basis.from_scale(Vector3.ONE * 0.72), Vector3(0, 0, 0.42)), {}]]
		"pot":                                     # горшок с цветами
			return [_it("SM_Prop_FlowerPot_Fancy_01", 0.62, _rf(x, 0.0, TAU), Vector3(0, 0.57 * 0.62, -0.26))]
		"vasebloom":                               # ваза с цветущим кустиком (как у дверей домов, CatDress)
			return [_it("SM_Prop_Vase_03", 0.72, _rf(x, 0.0, TAU)),
				_it(String(_one(x, BLOOM)), 0.27, _rf(x, 0.0, TAU), Vector3(0, 0.42, 0), {"tint": CatDecor.TRUE_COLOR})]
		"bloom":                                   # цветущий куст
			return [_it(String(_one(x, BLOOM)), _rf(x, 0.55, 0.66), _rf(x, 0.0, TAU), Vector3.ZERO, {"tint": CatDecor.TRUE_COLOR})]
		"herbs":                                   # травы в горшках
			var out := []
			for k in 2:
				var px := (k - 0.5) * 0.42
				out.append(_it("SM_Prop_Vase_06", 0.55, _rf(x, 0.0, TAU), Vector3(px, 0, 0)))
				out.append(_it("SM_Env_Garden_Plants_0%d" % _one(x, [2, 5]), 0.2, _rf(x, 0.0, TAU), Vector3(px, 0.32, 0), {}))
			return out
		"greens", "grapes", "olives", "apples", "grain":     # корзина с урожаем
			var kind := {"grapes": "plums", "grain": "grain"}.get(key, key) as String
			var r := _from(func(t: Bp) -> void: CatShops._basket(t, Vector3.ZERO, kind, 0.8))
			return r
		"jugs":
			var out := []
			for k in 3:
				out.append(_it("SM_Prop_Jug_03", 0.72 * _rf(x, 0.85, 1.05), float(_one(x, [0.0, PI])) + _rf(x, -0.25, 0.25), Vector3((k - 1) * 0.3, 0, 0)))
			return out
		"towels":                                  # корзины со сложенными полотенцами
			return [_it("SM_Prop_Basket_Set_04", 0.62, _rf(x, -0.2, 0.2)), _it("SM_Prop_Basket_Set_04_Insert_01", 0.62, 0.0)]
		"rugs":
			return [_it("SM_Prop_Rug_Stack_01", 0.6, _rf(x, -0.3, 0.3))]
		"marble":                                  # глыба мрамора
			return [_it("SM_Prop_Marble_Block_03", 0.62, _rf(x, -0.3, 0.3))]
		"rubble":
			return [_it("SM_Prop_Marble_Rubble_0%d" % _one(x, [4, 7]), 0.75, _rf(x, 0.0, TAU))]
		"broken":                                  # обломки статуй (брак скульптора)
			return [_it("SM_Prop_Statue_Broken_0%d" % _one(x, [3, 8]), 0.75, _rf(x, 0.0, TAU))]
		"scrolls":                                 # корзина со свитками
			var bn := "SM_Prop_Basket_0%d" % _one(x, [1, 6])
			var h := Bp.model_aabb(bn).end.y * 0.62
			return [_it(bn, 0.62), _it("SM_Prop_Scroll_Pile_0%d" % _one(x, [2, 6]), 0.55, _rf(x, -0.4, 0.4), Vector3(0, h - 0.06, 0))]
		"senser":                                  # курильница с благовониями
			return [_it("SM_Prop_Senser_04", 1.1, _rf(x, 0.0, TAU))]
		"trough":                                  # корыто с водой
			return [_it("SM_Prop_Bowl_07", 0.95, PI / 2), ["#water", Transform3D(Basis.from_scale(Vector3(0.7, 0.14, 0.86)), Vector3(0, 0.12 + 0.07, 0)), {}]]
	return []


## Цветущий куст заданной величины
static func _bloom(x: Dictionary, s: float) -> Array:
	return [_it(String(_one(x, BLOOM)), s * _rf(x, 0.9, 1.08), _rf(x, 0.0, TAU), Vector3.ZERO, {"tint": CatDecor.TRUE_COLOR})]


## Цветущий плющ на глухих модулях стен (стороны sides), где плюща ещё нет (CatDress ставит свой) — как на картинках Synty
static func _ivy(x: Dictionary, sides: Array, max_n := 2, dens := 0.7) -> int:
	var put := 0
	var b: Bp = x["b"]
	for w: Dictionary in x["walls"]:
		if put >= max_n or not String(w["side"]) in sides or String(w["nm"]) != "SM_Bld_Wall_01" or int(w["f"]) != 0 or not _ch(x, dens):
			continue
		var xf: Transform3D = w["xf"]
		var out: Vector3 = w["out"]
		var c := xf.origin + xf.basis.x * 1.25
		var near := false
		for q: Vector3 in x["ivy"]:
			if Vector2(q.x - c.x, q.z - c.z).length() < 1.8:
				near = true
				break
		if near:
			continue
		var u := 0.3 if _ch(x, 0.5) else 0.7
		var p := xf.origin + xf.basis.x * (2.5 * u) + out * (FACE * xf.basis.z.length() + 0.02) + Vector3.UP * 0.95 * xf.basis.y.length()
		var nm := "SM_Env_Ivy_Flowers_0%d" % _one(x, [1, 2, 3, 4])
		b.free_parts[b.parts.size()] = true
		b.parts.append([nm, Transform3D(Basis(Vector3.UP, atan2(out.x, out.z)) * Basis.from_scale(Vector3(0.9, 1.15, 1.0)), p), {}])
		(x["ivy"] as Array).append(p)
		x["n"] = int(x["n"]) + 1
		put += 1
	return put


## Черепичный козырёк на кронштейнах над глухим модулем стены (сторона side) — навес над кучками у стены
static func _awning(x: Dictionary, side: String) -> bool:
	for w: Dictionary in x["walls"]:
		if String(w["side"]) != side or String(w["nm"]) != "SM_Bld_Wall_01" or int(w["f"]) != 0 or not _ch(x, 0.7):
			continue
		var xf: Transform3D = w["xf"]
		var out: Vector3 = w["out"]
		var yaw := atan2(out.x, out.z)
		var mid := xf.origin + xf.basis.x * 1.25
		var p := mid + out * (FACE * xf.basis.z.length() + 0.02) + Vector3.UP * 2.45
		var items := [["SM_Prop_Overhang_01", Transform3D.IDENTITY, {}]]
		if _group(x, items, p, yaw, Vector3.ZERO, true, out):
			return true
	return false


## Разложить вдоль стен первого этажа (стороны sides: front/back/left/right) кучки из pal — вплотную друг за
## другом по модулю стены (2,5 м); dens — насколько густо (иначе — пропуск). У двери — только рядом с проёмом,
## под окном — ниже подоконника; за угол дома не выходит
static func _along(x: Dictionary, sides: Array, pal: Array, dens := 0.6, max_n := 99) -> int:
	var put := 0
	var last := ""
	for w: Dictionary in x["walls"]:
		if not String(w["side"]) in sides or int(w["f"]) != 0:
			continue
		var nm: String = w["nm"]
		var xf: Transform3D = w["xf"]
		var out: Vector3 = w["out"]
		var along := xf.basis.x.normalized()
		var sx := xf.basis.x.length()
		# лицо стены — по её настоящим габаритам (наличники, подоконники, карниз цоколя выступают)
		var wb := _box_of(nm, xf)
		var face := FACE * xf.basis.z.length()
		for i in 8:
			face = maxf(face, (wb.get_endpoint(i) - xf.origin).dot(out))
		face = minf(face, 0.42)
		var yaw := atan2(out.x, out.z)
		var ax := Basis(Vector3.UP, yaw) * Vector3.RIGHT
		var d0 := INF
		var d1 := -INF
		if nm.contains("Door"):
			var dd: Array = CatDress.DOOR.get(nm, [0.6, 1.9, 2.0])
			d0 = (float(dd[0]) - 0.15) * sx
			d1 = (float(dd[1]) + 0.15) * sx
		var sill := 9.0
		if nm.contains("Window"):
			sill = float((CatDress.WIN[nm] as Array)[0]) - 0.08 if CatDress.WIN.has(nm) else 1.15
		var gaps := [0.03, 0.08] if String(w["side"]) in ["left", "right"] else [0.08, 0.16, 0.26]
		var L := 2.5 * sx
		var cur := _rf(x, 0.02, 0.25)
		var tries := 0
		while cur < L - 0.25 and put < max_n and tries < 10:
			tries += 1
			if cur > d0 - 0.2 and cur < d1:
				cur = d1 + 0.02                   # проём двери — перешагнуть
				continue
			if not _ch(x, dens):
				cur += _rf(x, 0.35, 0.8)
				continue
			var key := String(_one(x, pal))
			if key == last and pal.size() > 1:
				key = String(_one(x, pal))       # не две одинаковые кучки подряд
			var items := _item(x, key)
			if items.is_empty():
				continue
			# габариты кучки в её осях: +Z — от стены, X — вдоль стены
			var lb := _items_box(items, Transform3D.IDENTITY)
			var wdt := lb.size.x
			var u := cur + wdt * 0.5
			if cur + wdt > L - 0.02 or (cur + wdt > d0 and cur < d1) or (sill < 9.0 and lb.end.y > sill):
				cur += 0.25
				continue
			var ok := false
			for gap: float in gaps:
				# задом к лицу стены, серединой — в место u (вдоль стены от её начала)
				var p := xf.origin + along * u + out * (face + gap - lb.position.z) - ax * lb.get_center().x
				p.y = 0.0
				if _group(x, items, p, yaw):
					ok = true
					break
			if ok:
				put += 1
				last = key
				cur += wdt + _rf(x, 0.04, 0.22)
			else:
				cur += 0.3
	return put


## Повесить на стену (сторона sides) деталь на высоте y (цветы в кашпо, знамёна): на глухие модули, по одному
static func _hang(x: Dictionary, sides: Array, names: Array, y: float, dens := 0.5, s := 0.6, out_d := 0.13, max_n := 4) -> int:
	var put := 0
	for w: Dictionary in x["walls"]:
		if put >= max_n or not String(w["side"]) in sides or String(w["nm"]) != "SM_Bld_Wall_01" or int(w["f"]) != 0 or not _ch(x, dens):
			continue
		var xf: Transform3D = w["xf"]
		var out: Vector3 = w["out"]
		var along := xf.basis.x.normalized()
		var items := [_it(String(_one(x, names)), s)]
		var lb := _items_box(items, Transform3D.IDENTITY)
		var p := xf.origin + along * 1.25 * xf.basis.x.length() + out * (FACE * xf.basis.z.length() + maxf(0.02, out_d - 0.13) - lb.position.z) + Vector3.UP * y
		if _group(x, items, p, atan2(out.x, out.z), Vector3.ZERO, true, out):
			put += 1
	return put


# =====================================================================
#   склад и мастерские
# =====================================================================

## Склад: вдоль боков и задней стены — открытый склад (мешки горкой, амфоры, корзины, поленница, доски),
## у фасада — товар у входа; у погрузочного двора справа — ещё мешки и корзины
static func _warehouse(x: Dictionary) -> void:
	_along(x, ["back"], ["store", "amphpile", "wood", "jarpile", "goods", "timber"], 1.0)
	_awning(x, "back")
	_along(x, ["left"], ["sideA", "sideB", "sideC"], 0.95)
	_along(x, ["right"], ["sideA", "sideB", "sideC"], 0.95)
	_along(x, ["front"], ["sack2", "amph2", "bgoods", "sack1"], 0.8)
	# погрузочный двор: мешки и корзины у повозки
	for p: Vector3 in [Vector3(4.6, 0, 0.35), Vector3(5.0, 0, -3.0), Vector3(4.2, 0, -4.3)]:
		_group(x, _item(x, String(_one(x, ["sack2", "bgoods", "basket", "amph2"]))), p, _rf(x, -0.4, 0.4), Vector3(0, 0, 0.25))


## Мастерская скульптора: во дворе — ещё глыбы, обломки и щебень, штабель мрамора у задней стенки, второй верстак
## с инструментом; за мастерской — запас камня
static func _sculptor(x: Dictionary) -> void:
	_put(x, "SM_Prop_Marble_Pile_01", Vector3(2.85, 0, -2.0), 0.4, 0.42, Vector3(0.0, 0, 0.25))
	_group(x, [_it("SM_Prop_Table_05", 0.9), _it("SM_Prop_Tool_Hammer_01", 1.0, 0.6, Vector3(0.05, 0.71, -0.3)),
		_it("SM_Prop_Tool_Chisel_01", 1.0, -0.4, Vector3(-0.05, 0.71, 0.1)), _it("SM_Prop_Tool_Compass_01", 1.0, 1.2, Vector3(0.0, 0.71, 0.4))],
		Vector3(3.25, 0, -0.5), 0.0, Vector3(0, 0, 0.3))
	for p: Vector3 in [Vector3(-3.1, 0, 1.45), Vector3(2.1, 0, 1.5), Vector3(-1.7, 0, -0.2), Vector3(0.6, 0, -1.1), Vector3(-3.2, 0, -0.4)]:
		_group(x, _item(x, String(_one(x, ["rubble", "broken", "marble", "rubble"]))), p, _rf(x, 0.0, TAU), Vector3(0.3, 0, 0))
	_along(x, ["back"], ["marble", "rubble", "timber", "marble"], 0.85)


## Травник: у боковых и задней стены — травы в горшках, корзины зелени, цветущие кусты; на глухих стенах — кашпо
static func _herbalist(x: Dictionary) -> void:
	_along(x, ["left", "right"], ["herbs", "vaseS", "sideC", "herbs"], 0.95)
	_along(x, ["back"], ["herbbed", "herbs", "greens", "herbbed", "vasebloom"], 0.95)
	_hang(x, ["left", "right", "back"], ["SM_Prop_FlowerPot_Hanging_04", "SM_Prop_FlowerPot_Hanging_05", "SM_Prop_FlowerPot_Hanging_06"], 1.2, 0.7, 0.6)
	_ivy(x, ["left", "right", "back"], 2)


## Пост вигилов: у стен — вёдра, лестницы, мешки с песком, амфоры с водой
static func _vigiles(x: Dictionary) -> void:
	_along(x, ["back"], ["timber", "store", "jugs", "amphpile"], 0.85)
	_along(x, ["left"], ["sideA", "sideB"], 0.8)
	_put(x, "SM_Prop_Straw_Bundle_01", Vector3(2.75, 0, -1.0), 0.0, 0.55)


## Скрипторий: у стен — корзины со свитками, амфоры с чернилами, горшки с цветами
static func _scriptorium(x: Dictionary) -> void:
	_along(x, ["back"], ["scrolls", "amphpile", "vasebloom"], 0.8)
	_along(x, ["left", "right"], ["scrolls", "sideA", "vaseS"], 0.8)
	_ivy(x, ["left", "right", "back"], 2)


# =====================================================================
#   поля, сады, рынок
# =====================================================================

## Пшеничное поле: копны и снопы, корыто с водой, мешки и корзины урожая, повозка с сеном, пугало в пшенице.
## Хижина то справа, то слева (CatCivic._farm: m) — сторону узнаём по двери хижины
static func _farm(x: Dictionary) -> void:
	var m := 1.0
	for p: Array in (x["b"] as Bp).parts:
		if String(p[0]) == "SM_Bld_Wall_Door_04":
			m = signf((p[1] as Transform3D).origin.x)
			break
	# пугало в пшенице (сзади, напротив хижины)
	_group(x, _from(func(t: Bp) -> void: CatExtra._scarecrow(t, Vector3.ZERO)), Vector3(-3.3 * m, 0, -3.5), 0.3, Vector3(0.4 * m, 0, 0))
	# повозка с сеном у изгороди напротив хижины
	_group(x, [_it("SM_Prop_Cart_01", 0.72), _it("SM_Prop_Cart_01_Insert_03", 0.72)], Vector3(-4.0 * m, 0, 0.9), PI + 0.08 * m, Vector3(0, 0, 0.3))
	# корыто с водой у колодца, копны и снопы
	_group(x, _item(x, "trough"), Vector3(2.6 * m, 0, 3.6), 0.0, Vector3(0.3 * m, 0, 0))
	for p: Vector3 in [Vector3(-4.3 * m, 0, 2.6), Vector3(-1.3 * m, 0, 4.3), Vector3(4.2 * m, 0, -1.9)]:
		_group(x, _item(x, String(_one(x, ["hay", "straw"]))), p, _rf(x, 0.0, TAU), Vector3(0, 0, 0.3))
	# урожай: мешки зерна, корзины зелени — у хижины и у ворот
	for p: Vector3 in [Vector3(1.4 * m, 0, 4.3), Vector3(4.3 * m, 0, 1.9), Vector3(1.95 * m, 0, -1.95), Vector3(-2.2 * m, 0, 2.6)]:
		_group(x, _item(x, String(_one(x, ["sack2", "greens", "grain", "sack1", "greens"]))), p, _rf(x, -0.5, 0.5), Vector3(0.3, 0, 0))
	# у хижины — корзина-заплечник и кувшин
	_group(x, _item(x, "jugs"), Vector3(4.15 * m, 0, -1.75), PI / 2 * m, Vector3(0, 0, 0.3))


## Оливковая роща: корзины с оливками под деревьями, амфоры масла у давильни, мешки, вторая лестница
static func _grove(x: Dictionary) -> void:
	for p: Vector3 in [Vector3(1.0, 0, -2.4), Vector3(-2.4, 0, -2.2), Vector3(2.4, 0, 0.9), Vector3(-0.6, 0, 3.9), Vector3(-4.2, 0, -0.4)]:
		_group(x, _item(x, String(_one(x, ["olives", "olives", "basket", "sack1"]))), p, _rf(x, 0.0, TAU), Vector3(0.3, 0, 0))
	_group(x, _item(x, "amph3"), Vector3(3.4, 0, 1.75), 0.0, Vector3(0.3, 0, 0))
	_group(x, _item(x, "jars"), Vector3(4.2, 0, 0.6), 0.0, Vector3(0, 0, 0.3))
	_group(x, [["SM_Prop_Ladder_01", Transform3D(Basis(Vector3.RIGHT, -0.32) * Basis.from_scale(Vector3.ONE * 0.85), Vector3.ZERO), {}]], Vector3(3.2, 0, -2.4), 0.4)


## Виноградник: корзины винограда у рядов, повозка с амфорами, стол для пробы вина с кувшинами, амфоры у давильни
static func _vineyard(x: Dictionary) -> void:
	for p: Vector3 in [Vector3(3.7, 0, -2.85), Vector3(-3.7, 0, -0.95), Vector3(0.9, 0, -0.95), Vector3(-3.0, 0, 1.0), Vector3(2.0, 0, 1.0)]:
		_group(x, _item(x, String(_one(x, ["grapes", "grapes", "basket"]))), p, _rf(x, 0.0, TAU), Vector3(0.3, 0, 0))
	_group(x, [_it("SM_Prop_Cart_01", 0.7), _it("SM_Prop_Cart_01_Insert_03", 0.7)], Vector3(4.0, 0, 1.4), 0.06, Vector3(0, 0, 0.3))
	# стол для пробы: кувшин и кубки, два табурета
	var tb := [_it("SM_Prop_Table_04", 0.8), _it("SM_Prop_Jug_03", 0.5, 0.4, Vector3(-0.15, 0.62, 0.05)),
		_it("SM_Prop_Goblet_01", 0.8, 0.0, Vector3(0.18, 0.62, -0.12)), _it("SM_Prop_Goblet_01", 0.8, 0.5, Vector3(0.15, 0.62, 0.18)),
		_it("SM_Prop_Seat_Stool_02", 0.9, 0.0, Vector3(-0.72, 0, 0)), _it("SM_Prop_Seat_Stool_02", 0.9, 0.3, Vector3(0.72, 0, 0))]
	_group(x, tb, Vector3(-0.9, 0, 1.35), 0.0, Vector3(0.4, 0, 0))
	_group(x, _item(x, "amph3"), Vector3(1.0, 0, 4.4), 0.0, Vector3(0.3, 0, 0))
	_group(x, _item(x, "amph2"), Vector3(-4.3, 0, 1.4), PI / 2, Vector3(0, 0, 0.3))


## Огород: лейки-кувшины, корзина зелени, мешок у сарайчика
static func _ogorod(x: Dictionary) -> void:
	_group(x, _item(x, "greens"), Vector3(-1.9, 0, 1.8), 0.4, Vector3(0.3, 0, 0))
	_group(x, _item(x, "jugs"), Vector3(1.2, 0, -2.0), 0.0, Vector3(0.25, 0, 0))
	_group(x, _item(x, "sack1"), Vector3(0.4, 0, 1.85), 0.3, Vector3(0.3, 0, 0))


## Форум — он же рынок: под боковыми портиками у лавок — столы с товаром, корзины, ковры, амфоры, мешки;
## на площади ничего не ставим (там слушают оратора, Spectacle); за задней стеной — цветущие кусты
static func _forum(x: Dictionary) -> void:
	for sd: float in [-1.0, 1.0]:
		var yaw := -sd * PI / 2
		for z: float in [3.55, 1.75, -0.95, -3.0]:
			var k := String(_one(x, ["table", "bgoods", "rugs", "jars", "sacks", "vpile", "bset"]))
			var items := _market_table(x) if k == "table" else _item(x, k)
			_group(x, items, Vector3(sd * 5.35, 0, z), yaw, Vector3(0, 0, 0.35))
	# за задней стеной (за облицовкой) — цветущие кусты
	for xx: float in [-5.0, -2.5, 0.0, 2.5, 5.0]:
		_group(x, _bloom(x, 0.6), Vector3(xx + _rf(x, -0.3, 0.3), 0, -8.45), 0.0, Vector3(0.3, 0, 0))


## Стол торговца: на столе кувшины, миски, корзины (как CatShops._stall), под столом — корзина
static func _market_table(x: Dictionary) -> Array:
	var out := [_it("SM_Prop_Table_01", 0.8)]
	var tops := ["SM_Prop_Vase_0%d", "SM_Prop_Jug_0%d", "SM_Prop_Bowl_0%d", "SM_Prop_Basket_0%d"]
	for k in 3:
		var nm := String(_one(x, tops)) % (1 + (x["rng"] as RandomNumberGenerator).randi() % 4)
		out.append(_it(nm, 0.5, _rf(x, 0.0, TAU), Vector3(-0.42 + k * 0.42, 0.62, _rf(x, -0.1, 0.1))))
	out.append(_it("SM_Prop_Basket_0%d" % _one(x, [1, 6]), 0.55, _rf(x, 0.0, TAU), Vector3(0.35, 0, 0.55)))
	return out


# =====================================================================
#   общественные здания
# =====================================================================

## Школа: у боковых стен — корзины со свитками, вазы с цветами; за домом — садик с цветущими кустами; на глухих
## стенах — кашпо. Скамей и стульев не добавляем: на них Spectacle сажает учеников
static func _school(x: Dictionary) -> void:
	_along(x, ["left", "right"], ["scrolls", "vaseS", "sideA", "scrolls"], 0.85)
	_along(x, ["back"], ["bloom", "vasebloom", "bloom", "pot"], 0.7)
	_group(x, _item(x, "scrolls"), Vector3(3.15, 0, 2.3), 0.0, Vector3(0, 0, 0.3))
	_group(x, _item(x, "vasebloom"), Vector3(-3.15, 0, 2.45), 0.0, Vector3(0, 0, 0.3))
	_hang(x, ["left", "right"], ["SM_Prop_FlowerPot_Hanging_04", "SM_Prop_FlowerPot_Hanging_05", "SM_Prop_FlowerPot_Hanging_06"], 1.2, 0.8, 0.6)
	_ivy(x, ["left", "right", "back"], 3)


## Библиотека: у боков и сзади — цветы, корзины со свитками; на глухих стенах — кашпо
static func _library(x: Dictionary) -> void:
	_along(x, ["left", "right"], ["vaseS", "scrolls", "sideA"], 0.85)
	_along(x, ["back"], ["bloom", "vasebloom", "bloom"], 0.6)
	_hang(x, ["left", "right"], ["SM_Prop_FlowerPot_Hanging_04", "SM_Prop_FlowerPot_Hanging_06"], 1.2, 0.7, 0.6)
	_ivy(x, ["left", "right", "back"], 3)


## Академия: в саду — цветущие кусты у дорожек, корзины со свитками у скамей; у боков зала — вазы с цветами
static func _academy(x: Dictionary) -> void:
	for p: Vector3 in [Vector3(-2.0, 0, 3.6), Vector3(2.0, 0, 3.6), Vector3(-3.9, 0, 4.7), Vector3(3.9, 0, 4.7), Vector3(-1.2, 0, 1.8), Vector3(1.2, 0, 1.8)]:
		_group(x, _item(x, String(_one(x, ["bloom", "bloom", "vasebloom"]))), p, _rf(x, 0.0, TAU), Vector3(0.3, 0, 0))
	for p: Vector3 in [Vector3(-3.4, 0, 2.4), Vector3(3.4, 0, 2.4)]:
		_group(x, _item(x, "scrolls"), p, 0.0, Vector3(0, 0, 0.3))
	_along(x, ["back"], ["bloom", "vasebloom", "bloom"], 0.5)


## Бани квартала: за баней — дрова для печи и амфоры масла; у боков — корзины с полотенцами, кувшины
static func _balnea(x: Dictionary) -> void:
	_along(x, ["back"], ["wood", "wood", "amphpile", "jarpile"], 0.9)
	_awning(x, "back")
	_along(x, ["left", "right"], ["sideA", "jugs", "sideC"], 0.85)
	_ivy(x, ["left", "right", "back"], 2)
	for p: Vector3 in [Vector3(4.4, 0, 1.0), Vector3(-4.4, 0, -0.5)]:
		_group(x, _item(x, String(_one(x, ["towels", "jugs", "amph2"]))), p, PI / 2 * signf(p.x), Vector3(0, 0, 0.3))


## Термы: за залом — поленницы для печей и амфоры; между бассейнами и колоннадами — корзины с полотенцами,
## кувшины, цветущие кусты; у колоннад снаружи — амфоры. Перед бассейнами пусто: там купальщики идут к воде (Spectacle)
static func _baths(x: Dictionary) -> void:
	_along(x, ["back"], ["wood", "amphpile", "wood", "jarpile", "store"], 0.9)
	for sd: float in [-1.0, 1.0]:
		for z: float in [-1.3, 0.5, 2.2]:
			_group(x, _item(x, String(_one(x, ["towels", "jugs", "vasebloom", "towels"]))), Vector3(sd * 4.35, 0, z), -sd * PI / 2, Vector3(0, 0, 0.3))
		_group(x, _item(x, "vasebloom"), Vector3(sd * 5.6, 0, 3.45), 0.0, Vector3(0.3 * sd, 0, 0))
	_along(x, ["left", "right"], ["sideA", "jugs", "sideC"], 0.8)


## Храм: на подиуме у алтаря — корзины с дарами (фрукты, виноград), вазы с цветами, курильницы; у лестницы —
## высокие знамёна на шестах; вдоль подиума и за храмом — цветущие кусты (как на картинках Synty).
## Середина лестницы и пронаоса свободна: там идёт жрец, на лестнице и перед храмом стоят молящиеся (Spectacle)
static func _temple(x: Dictionary) -> void:
	(x["keep"] as Array).append(Rect2(-0.8, 3.1, 1.6, 2.8))
	# дары у алтаря и между колоннами
	for p: Vector3 in [Vector3(-0.85, 0, 2.65), Vector3(0.85, 0, 2.65)]:
		_group(x, _item(x, String(_one(x, ["apples", "grapes", "grain"]))), p, _rf(x, 0.0, TAU), Vector3(0, 0, 0.2))
	for p: Vector3 in [Vector3(-1.55, 0, 4.2), Vector3(1.55, 0, 4.2)]:
		_group(x, _item(x, "vasebloom"), p, 0.0, Vector3(0, 0, 0.2))
	for p: Vector3 in [Vector3(-3.1, 0, 4.25), Vector3(3.1, 0, 4.25), Vector3(-3.1, 0, 2.65), Vector3(3.1, 0, 2.65)]:
		_group(x, _item(x, String(_one(x, ["senser", "apples", "senser"]))), p, 0.0, Vector3(0, 0, 0.2))
	# знамёна на шестах у лестницы
	var bl := String(_one(x, ["A", "C"]))
	for sd: float in [-1.0, 1.0]:
		_group(x, [_it("SM_Prop_Pole_02", 0.95), _it("SM_Prop_Banner_03_" + bl, 0.62, 0.0, Vector3(0, 2.75, 0.1))], Vector3(sd * 4.75, 0, 6.75), 0.0, Vector3(0, 0, 0.25))
		_group(x, _item(x, "vasebloom"), Vector3(sd * 4.8, 0, 5.75), 0.0, Vector3(0, 0, 0.2))
	# цветущие кусты вдоль подиума и за храмом
	for sd: float in [-1.0, 1.0]:
		for z: float in [-3.4, -1.3, 0.3, 2.4, 4.3]:
			_group(x, _bloom(x, 0.68), Vector3(sd * 4.98, 0, z), 0.0, Vector3(0, 0, 0.3))
	for xx: float in [-3.0, -1.0, 1.0, 3.0]:
		_group(x, _bloom(x, 0.72), Vector3(xx, 0, -5.6), 0.0, Vector3(0.3, 0, 0))


## Дом префекта: у боков и сзади — цветы в вазах, кусты, амфоры
static func _prefect(x: Dictionary) -> void:
	_along(x, ["left", "right"], ["vaseS", "sideA", "sideC"], 0.85)
	_along(x, ["back"], ["bloom", "amphpile", "vasebloom"], 0.75)
	_ivy(x, ["left", "right", "back"], 3)


## Лудус: за казармой — дрова и мешки, у боков колоннад — кувшины с водой, снопы соломы для чучел
static func _ludus(x: Dictionary) -> void:
	_along(x, ["back"], ["wood", "store", "jarpile", "wood"], 0.85)
	_along(x, ["left", "right"], ["jugs", "sideA"], 0.8)


## Большие термы: за ними — поленницы и амфоры; у боков — корзины с полотенцами, кувшины, цветы
static func _thermae(x: Dictionary) -> void:
	_along(x, ["back"], ["wood", "amphpile", "wood", "jarpile"], 0.85)
	_along(x, ["left", "right"], ["jugs", "vaseS", "sideA"], 0.8)
	_ivy(x, ["left", "right", "back"], 2)



# =====================================================================
#   второй проход: стены и крыши (владелец: «пустые бока и стены»; координатор 12.11: на каждой длинной стене 3–5
#   заметных деталей, видных с обычного отдаления; крыши — самое заметное с высоты камеры)
# =====================================================================

## Что вешать на стены: тип → {beams — торцы балок под верхним карнизом, shut — ставни на большие окна,
## g — на глухой модуль первого этажа, u — на глухой модуль верхних этажей, sides — какие стены}
const WALL_KIT := {
	"warehouse": {"beams": true, "g": ["shelf", "hooks", "lamp", "shelf"], "u": ["hooks", "drape"], "sides": ["left", "right", "back"]},
	"vigiles": {"beams": true, "g": ["hooks", "lamp", "shelf"], "u": [], "sides": ["left", "right", "back"]},
	"sculptor": {"beams": true, "g": ["plaque", "shelf"], "u": [], "sides": ["back", "left", "right"]},
	"herbalist": {"beams": true, "g": ["trellis", "herbs", "lamp", "pot"], "u": [], "sides": ["left", "right", "back"]},
	"scriptorium": {"beams": false, "shut": "#shutters_blue", "g": ["trellis", "scrolls", "pot", "lamp"], "u": ["pots", "band"], "sides": ["left", "right", "back"]},
	"farm": {"beams": true, "g": ["hooks", "shelf"], "u": [], "sides": ["left", "right", "back", "front"]},
	"school": {"shut": "#shutters_green", "g": ["trellis", "fresco", "lamp", "pot"], "u": ["band", "banner", "pots"], "sides": ["left", "right", "back"]},
	"library": {"shut": "#shutters_brown", "g": ["trellis", "plaque", "lamp"], "u": ["banner", "band"], "sides": ["left", "right", "back"]},
	"academy": {"g": ["trellis", "plaque", "lamp"], "u": ["banner", "band"], "sides": ["left", "right", "back"]},
	"prefect": {"shut": "#shutters_green", "g": ["trellis", "plaque", "lamp"], "u": ["banner", "band"], "sides": ["left", "right", "back"]},
	"balnea": {"g": ["trellis", "lamp", "pot", "fresco"], "u": [], "sides": ["left", "right", "back"]},
	"baths": {"shut": "#shutters_blue", "g": ["trellis", "plaque", "lamp", "fresco"], "u": ["banner", "band"], "sides": ["left", "right", "back"]},
	"thermae": {"g": ["trellis", "plaque", "lamp"], "u": ["banner", "band"], "sides": ["left", "right", "back"]},
	"ludus": {"g": ["lamp", "hooks"], "u": ["banner"], "sides": ["left", "right", "back"]},
}
const SHUT_WIN := ["SM_Bld_Wall_Window_01", "SM_Bld_Wall_Window_05"]
## Здания со вторым проходом
const PASS2 := ["warehouse", "vigiles", "sculptor", "herbalist", "scriptorium", "farm", "grove", "vineyard", "ogorod", "forum"]


static func _walls_and_roofs(x: Dictionary, type: String) -> void:
	if not type in PASS2:
		return
	if WALL_KIT.has(type):
		_wallart(x, WALL_KIT[type])
	_roofs(x)
	match type:
		"balnea", "baths": _flat_roof(x, type)
		"temple": _temple_walls(x)


## Деталь (кучка items, +Z — от стены) на лице модуля стены w: середина — в u метрах вдоль стены от её начала,
## высота y от низа модуля, вынос d от лица. Не залезает на то, что уже висит на стене, и на твёрдое рядом
static func _face(x: Dictionary, w: Dictionary, items: Array, u: float, y: float, d := 0.0) -> bool:
	if items.is_empty() or int(x["n2"]) + items.size() > CAP2:
		return false
	var xf: Transform3D = w["xf"]
	var out: Vector3 = w["out"]
	var yaw := atan2(out.x, out.z)
	var ax := Basis(Vector3.UP, yaw) * Vector3.RIGHT
	var lb := _items_box(items, Transform3D.IDENTITY)
	var p := xf.origin + xf.basis.x.normalized() * u + out * (FACE * xf.basis.z.length() + d - lb.position.z) - ax * lb.get_center().x + Vector3.UP * y
	var g := Transform3D(Basis(Vector3.UP, yaw), p)
	var bx := _items_box(items, g)
	var r2 := Rect2(bx.position.x, bx.position.z, bx.size.x, bx.size.z)
	if not (x["outer"] as Rect2).grow(0.02 + HANG_M).encloses(r2):
		return _no("стена: за участком", bx) >= 0.0
	var sh := AABB(bx.position + Vector3(0.03, 0.03, 0.03), (bx.size - Vector3(0.06, 0.06, 0.06)).max(Vector3.ONE * 0.01))
	for s: AABB in x["wsolid"]:
		if s.intersects(sh):
			return _no("стена: занято %s" % [s], bx) >= 0.0
	# твёрдое (колонны, кучки у стены, соседние стены) — кроме самой стены: проверяем то, что выступает от лица
	var cut := Vector3(absf(out.x), 0, absf(out.z)) * 0.08
	var sh2 := AABB(sh.position + Vector3(maxf(out.x, 0.0), 0, maxf(out.z, 0.0)) * 0.08, (sh.size - cut).max(Vector3.ONE * 0.01))
	for s: AABB in x["solid"]:
		if s.intersects(sh2):
			return _no("стена: задевает %s" % [s], bx) >= 0.0
	var b: Bp = x["b"]
	for it: Array in items:
		b.free_parts[b.parts.size()] = true
		b.parts.append([String(it[0]), g * (it[1] as Transform3D), it[2] if it.size() > 2 else {}])
	(x["wsolid"] as Array).append(bx)
	if bx.position.y < 2.6:
		(x["solid"] as Array).append(bx)       # кучки у стены (первый проход) обходят шпалеры и полки
	x["n2"] = int(x["n2"]) + items.size()
	return true


## Высота проёма двери модуля (0 — не дверь)
static func _door_top(nm: String) -> float:
	if not nm.contains("Door"):
		return 0.0
	return float((CatDress.DOOR.get(nm, [0.6, 1.9, 2.6]) as Array)[2])


## Стены по набору kit: торцы балок под верхним карнизом, ставни на больших окнах, на глухих модулях — шпалеры
## с плющом, полки с товаром, крюки, фонари, таблички, росписи (внизу), знамёна и полосы росписи (наверху)
static func _wallart(x: Dictionary, kit: Dictionary) -> void:
	var sides: Array = kit.get("sides", ["left", "right", "back"])
	var top := 0
	for w: Dictionary in x["walls"]:
		top = maxi(top, int(w["f"]))
	var g_last := ""
	var u_last := ""
	var lamps := 0
	var shut: String = kit.get("shut", "")
	var shut_n := 0
	# сначала ставни (на всех сторонах) — потом всё прочее (чтобы прочее обходило ставни)
	if shut != "":
		for w: Dictionary in x["walls"]:
			var nm: String = w["nm"]
			if not nm in SHUT_WIN or shut_n >= 8:
				continue
			var sx := (w["xf"] as Transform3D).basis.x.length()
			var sill := float((CatDress.WIN[nm] as Array)[0])
			if _face(x, w, [[shut, Transform3D(Basis.from_scale(Vector3(1.05, 1.25, 1.0)), Vector3.ZERO), {}]], 1.25 * sx, sill + 0.72, 0.005):
				shut_n += 1
	for w: Dictionary in x["walls"]:
		if not String(w["side"]) in sides:
			continue
		var nm: String = w["nm"]
		var xf: Transform3D = w["xf"]
		var sx := xf.basis.x.length()
		var f := int(w["f"])
		var dt := _door_top(nm)
		# торцы балок под верхним карнизом (деревянные дома и мастерские)
		if kit.get("beams", false) and f == top and (dt == 0.0 or dt < 2.3) and not nm.contains("Alcove"):
			_face(x, w, [_it("SM_Bld_Wall_Beam_Detail_01", 1.0)], 1.25 * sx, Bp.FL - 0.33 - 0.31, 0.0)
		if nm != "SM_Bld_Wall_01":
			continue
		var pal: Array = kit.get("g", []) if f == 0 else kit.get("u", [])
		if pal.is_empty():
			continue
		for t in 3:
			var key := String(_one(x, pal))
			if key == (g_last if f == 0 else u_last) and pal.size() > 1:
				continue
			if key == "lamp" and lamps >= 2:
				continue
			if _wall_item(x, w, key, f):
				if f == 0:
					g_last = key
				else:
					u_last = key
				if key == "lamp":
					lamps += 1
				break


## Одна деталь на глухой модуль: true — встала
static func _wall_item(x: Dictionary, w: Dictionary, key: String, f: int) -> bool:
	var sx := (w["xf"] as Transform3D).basis.x.length()
	var c := 1.25 * sx
	var side_u := c + (0.62 if _ch(x, 0.5) else -0.62) * sx
	match key:
		"trellis":                                   # шпалера с цветущим плющом во всю высоту этажа
			var items := [["SM_Bld_Trellis_01", Transform3D(Basis.from_scale(Vector3(0.78, 0.72, 1.0)), Vector3(0.975, 0, 0.06)), {}],
				_it("SM_Env_Ivy_Flowers_0%d" % _one(x, [1, 2]), 0.82, 0.0, Vector3(0.0, 1.2, 0.14))]
			return _face(x, w, items, c, 0.18, 0.0)
		"shelf", "herbs", "scrolls":                 # полка на кронштейнах, на ней товар
			var items := [["SM_Prop_Beam_01", Transform3D(Basis.from_scale(Vector3(0.6, 1.3, 1.5)), Vector3(-0.75, 0, 0.17)), {}]]
			for sxk: float in [-0.55, 0.55]:
				items.append(["SM_Prop_Bracket_01", Transform3D(Basis.from_scale(Vector3(2.0, 1.6, 1.6)), Vector3(sxk, -0.13, 0.0)), {}])
			var goods: Array = {"shelf": ["SM_Prop_Jug_03", "SM_Prop_Vase_02", "SM_Prop_Basket_06"], "herbs": ["SM_Prop_Vase_06", "SM_Prop_Jug_03", "SM_Prop_Vase_06"],
				"scrolls": ["SM_Prop_Scroll_Pile_02", "SM_Prop_Vase_02", "SM_Prop_Scroll_Pile_02"]}[key]
			for k in 3:
				var gn: String = goods[k]
				var gs := 0.42 if gn.contains("Vase") or gn.contains("Jug") else 0.5
				items.append(_it(gn, gs, _rf(x, -0.4, 0.4), Vector3(-0.45 + k * 0.45, 0.1, 0.17)))
				if key == "herbs" and gn == "SM_Prop_Vase_06":
					items.append(_it("SM_Env_Garden_Plants_02", 0.16, _rf(x, 0.0, TAU), Vector3(-0.45 + k * 0.45, 0.36, 0.17), {}))
			return _face(x, w, items, c, 1.55, 0.0)
		"hooks":                                     # крюки: связки кувшинов и горшков на цепях
			var items := [_it("SM_Prop_Pots_Hanging_01", 1.0, 0.0, Vector3(-0.32, 0, 0.0)), _it("SM_Prop_Pots_Hanging_02", 0.9, 0.0, Vector3(0.32, 0, 0.0))]
			return _face(x, w, items, side_u, 2.4, 0.0)
		"lamp":                                      # фонарь на кронштейне
			return _face(x, w, [_it("#wall_lamp", 0.95)], side_u, 2.25, 0.0)
		"pot", "pots":                               # кашпо с цветами
			return _face(x, w, [_it("SM_Prop_FlowerPot_Hanging_0%d" % _one(x, [4, 6]), 0.55)], side_u, 1.25 if f == 0 else 1.15, 0.0)
		"plaque":                                    # табличка-рельеф
			return _face(x, w, [_it("SM_Prop_Symbol_%02d" % _one(x, [5, 9, 12]), 0.7)], c, 1.45 if f == 0 else 1.3, 0.0)
		"fresco":                                    # роспись на стене
			return _face(x, w, [_it("SM_Prop_Mural_0%d" % _one(x, [1, 2]), 0.62)], c, 1.45, 0.0)
		"drape":                                     # флажок на кронштейне
			return _face(x, w, [_it("SM_Prop_Banner_Drape_02", 1.0)], side_u, 2.3, 0.0)
		"banner":                                    # знамя под карнизом
			return _face(x, w, [_it("SM_Prop_Banner_0%d_%s" % [int(_one(x, [1, 2])), String(_one(x, ["A", "B", "E"]))], 0.82)], c, Bp.FL - 0.42, 0.0)
		"band":                                      # полоса росписи под карнизом
			return _face(x, w, [["SM_Prop_Mural_0%d" % _one(x, [3, 4]), Transform3D(Basis.from_scale(Vector3(0.96, 0.9, 1.0)), Vector3.ZERO), {}]], c, Bp.FL - 0.75, 0.0)
	return false


## Крыши: черепичные навершия на концах конька (где их нет) и пара сдвинутых черепиц на скате
static func _roofs(x: Dictionary) -> void:
	var b: Bp = x["b"]
	var ends := []
	var slopes := []
	var marks := []
	for p: Array in b.parts:
		var nm: String = p[0]
		if nm == "SM_Bld_Roof_Base_Straight_Side_01":
			ends.append(_box_of(nm, p[1]))
		elif nm == "SM_Bld_Roof_Base_Straight_01":
			slopes.append(p[1])
		elif nm.contains("Topper") or nm.contains("Statue") or nm.contains("Ornament") or nm.contains("Eagle"):
			marks.append((p[1] as Transform3D).origin)
	# пары половинок фронтона — конец конька: середина их общей рамки, верх
	var used := {}
	for i in ends.size():
		if used.has(i):
			continue
		var bx: AABB = ends[i]
		for j in range(i + 1, ends.size()):
			if not used.has(j) and (ends[j] as AABB).grow(0.05).intersects(bx):
				bx = bx.merge(ends[j])
				used[j] = true
		var tip := Vector3(bx.get_center().x, bx.end.y - 0.02, bx.get_center().z)
		var free := true
		for q: Vector3 in marks:
			if q.distance_to(tip) < 1.0:
				free = false
				break
		if free and int(x["n2"]) < CAP2:
			b.free_parts[b.parts.size()] = true
			b.parts.append(["SM_Bld_Roof_Topper_0%d" % (2 if (x["type"] as String) in ["warehouse", "vigiles", "farm", "sculptor"] else 5),
				Transform3D(Basis.IDENTITY, tip), {}])
			marks.append(tip)
			x["n2"] = int(x["n2"]) + 1
	# сдвинутые черепицы на одном-двух скатах (та же рамка, что у ската, — ложатся на черепицу)
	for k in mini(2, slopes.size()):
		if int(x["n2"]) >= CAP2 or not _ch(x, 0.7):
			continue
		var xf: Transform3D = slopes[(x["rng"] as RandomNumberGenerator).randi() % slopes.size()]
		b.free_parts[b.parts.size()] = true
		b.parts.append(["SM_Bld_Roof_Detail_0%d" % (1 + k % 2), xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.015, 0)), {}])
		x["n2"] = int(x["n2"]) + 1


## Плоские крыши бань и терм: горшки с цветами и амфоры у парапета, на верёвке сохнут полотенца
static func _flat_roof(x: Dictionary, type: String) -> void:
	var b: Bp = x["b"]
	var spots := []
	match type:
		"balnea":
			spots = [[Vector3(-3.3, Bp.FL, -1.75), "pot"], [Vector3(3.3, Bp.FL, -3.3), "pot"], [Vector3(-3.35, Bp.FL, -3.3), "amph"],
				[Vector3(1.8, Bp.FL, -3.25), "laundry"]]
		"baths":
			# купола-перголы стоят в x 0 и ±3,75 — между ними
			spots = [[Vector3(5.6, 2 * Bp.FL, -5.0), "pot"], [Vector3(-2.05, 2 * Bp.FL, -5.0), "pot"], [Vector3(2.05, 2 * Bp.FL, -4.15), "laundry"],
				[Vector3(-5.5, 2 * Bp.FL, -5.0), "amph"]]
	for e: Array in spots:
		var p: Vector3 = e[0]
		var items: Array = []
		match String(e[1]):
			"pot": items = [_it("SM_Prop_FlowerPot_Fancy_01", 0.55, _rf(x, 0.0, TAU), Vector3(0, 0.57 * 0.55, 0))]
			"amph": items = [_it("SM_Prop_Vase_02", 0.75, 0.0, Vector3(-0.2, 0, 0)), _it("SM_Prop_Jar_01", 0.62, 0.0, Vector3(0.2, 0, 0))]
			"laundry": items = [["#laundry", Transform3D(Basis.from_scale(Vector3(0.62, 0.72, 0.62)), Vector3(0, 0, -0.63)), {}]]
		if int(x["n2"]) + items.size() > CAP2:
			break
		var g := Transform3D(Basis.IDENTITY, p)
		var bx := _items_box(items, g)
		var ok := true
		var sb := AABB(bx.position + Vector3.ONE * 0.04, (bx.size - Vector3.ONE * 0.08).max(Vector3.ONE * 0.01))
		for s: AABB in x["wsolid"]:
			if s.intersects(sb):
				ok = false
				break
		for q: Array in b.parts:
			var qn := String(q[0])
			if ok and (qn.contains("Pergola") or qn.contains("Vase") or qn.contains("FlowerPot")) and (q[1] as Transform3D).origin.distance_to(p) < 0.9:
				ok = false
		if not ok:
			continue
		for it: Array in items:
			b.free_parts[b.parts.size()] = true
			b.parts.append([String(it[0]), g * (it[1] as Transform3D), it[2] if it.size() > 2 else {}])
		(x["wsolid"] as Array).append(bx)
		x["n2"] = int(x["n2"]) + items.size()


## Храм: красные знамёна между полуколоннами на боковых и задней стенах целлы (стены на подиуме, в масштабе храма)
static func _temple_walls(x: Dictionary) -> void:
	var b: Bp = x["b"]
	var k := 0.62
	var pod := 1.5 * k
	var hx := 6.25 * k + 0.115 * k + 0.02
	var letter := String(_one(x, ["A", "B"]))
	var spots := []
	for sd: float in [-1.0, 1.0]:
		for i: int in [0, 2]:
			spots.append([Vector3(sd * hx, pod + 3.55 * k, k * (-8.5 - (i + 0.5) * 2.5) + 5.6), sd * PI / 2])
	for i: int in [1, 3]:
		spots.append([Vector3(-6.25 * k + (i + 0.5) * 2.5 * k, pod + 3.55 * k, k * -16.0 + 5.6 - 0.115 * k - 0.02), PI])
	for e: Array in spots:
		if int(x["n2"]) >= CAP2:
			break
		b.free_parts[b.parts.size()] = true
		b.parts.append(["SM_Prop_Banner_01_" + letter, Transform3D(Basis(Vector3.UP, float(e[1])) * Basis.from_scale(Vector3.ONE * 1.15 * k), e[0]), {}])
		x["n2"] = int(x["n2"]) + 1
