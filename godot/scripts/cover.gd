class_name Cover
extends Node3D
## Охват без кругов (решение владельца Д3, docs/PLAN_2026-10-14_decisions.md) — только подсветка домов:
##   ставим или выбрали лавку: синие — дома, которые уже снабжает такая же лавка (вторая такая же им ничего не даст),
##   зелёные — кому эта лавка правда что-то даст; над такими же лавками — их значок, чтобы было видно, где они;
##   памятник — так же, по виду памятника; украшение — зелёным домам станет лучше, синим украшений уже хватает;
##   склад — лавки, которым он нужен: зелёные пока без склада, синие уже со складом.
##   «Обзор» (hud.set_overlay): счастье каждого дома или одна потребность — где она есть, а где нет.
##   Инструмент «Этаж» (U): зелёные — дома, которым можно надстроить этаж; над ними стрелка с ценой.
## Подсветка — свой пул MultiMesh (Pool): меши деталей — у основного пула, цвет — у каждого дома свой.
## Зажигаем не больше PER_FRAME домов за кадр (ближние к курсору — первыми); пока курсор стоит — ничего не считаем.

const GREEN := Color(0.32, 1.0, 0.36)
const BLUE := Color(0.26, 0.58, 1.0)
const GOLD := Color(1.0, 0.76, 0.18)
const RED := Color(1.0, 0.26, 0.2)
const ALPHA := 0.8
const PER_FRAME := 40                 # домов за кадр: ~3 мс, город в 250 домов зажигается за 7 кадров
const FRAME_US := 4000                # и не дольше 4 мс за кадр
const HAPPY_GOOD := 65                # с такого счастья можно второй этаж (Defs.FLOOR_HAPPY)
const HAPPY_BAD := 40
const FAR := 80.0                     # камера дальше — над домами «Обзора» только рожицы, без цифр (не налезают)

## «уже с гончарной»: с чем дом уже (творительный падеж)
const WITH := {"stall_fruit": "с фруктовой лавкой", "stall_veg": "с овощной лавкой", "stall_fish": "с рыбной лавкой",
	"butcher": "с мясной лавкой", "bakery": "с пекарней", "thermopolium": "с термополием", "taberna": "с таверной",
	"weaver": "с ткацкой лавкой", "cobbler": "с сапожником", "dyer": "с красильней", "fullonica": "с фуллоникой",
	"tailor": "с мастерской тог", "musicians": "с уличными музыкантами", "dice": "с игрой в кости", "mimes": "с помостом мимов",
	"odeon": "с одеоном", "theatre": "с театром", "barber": "с цирюльней", "balnea": "с банями", "medic": "с лекарем",
	"baths": "с термами", "potter": "с гончарной", "oilshop": "с масляной лавкой", "lamps": "с мастером светильников",
	"wineshop": "с винной лавкой", "perfumer": "с парфюмером", "jeweler": "с ювелиром", "warehouse": "со складом",
	"fountain": "с фонтаном", "temple": "с храмом", "forum": "с форумом", "arch": "с аркой", "colosseum": "с амфитеатром",
	"pantheon": "с Пантеоном"}


## Пул подсветки: те же детали, что у построек (меши берём у основного пула — без копий), поверх — цветная
## оболочка (shaders/cover.gdshader); цвет каждого дома — в INSTANCE_CUSTOM, одинаковые детали — один MultiMesh
class Pool extends Parts:
	var src: Parts
	var mat: ShaderMaterial

	func _group(name: String, remap: Dictionary, tile := Vector2i(-1, -1)) -> Dictionary:
		var key := name + "|" + str(remap)
		if groups.has(key):
			return groups[key]
		var s: Dictionary = src.groups.get(key, {}) if src != null else {}
		if s.is_empty():
			return super._group(name, remap, tile)
		var g := {"subs": [], "free": [], "used": 0, "cap": 0, "key": key}
		for sub in s["subs"]:
			g["subs"].append(_sub((sub["mm"] as MultiMesh).mesh, sub["local"]))
		groups[key] = g
		return g

	func _sub(mesh: Mesh, local: Transform3D) -> Dictionary:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = 0
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		return {"mm": mm, "mmi": mmi, "local": local}

	var _bp_groups := {}      # чертёж → [[группа, где деталь]…]: без строк-ключей на каждую деталь каждого дома

	func _groups_of(bp: Bp) -> Array:
		var key := bp.get_instance_id()
		var gs: Array = _bp_groups.get(key, [])
		if gs.is_empty():
			for p in bp.parts:
				gs.append([_group(p[0], p[2]), p[1]])
			_bp_groups[key] = gs
		return gs

	## Сколько мест нужно каждому виду деталей под чертежи bps (одинаковые чертежи считаем один раз)
	func need_of(bps: Array) -> Dictionary:
		var per := {}
		for bp: Bp in bps:
			var e: Array = per.get(bp.get_instance_id(), [bp, 0])
			e[1] = int(e[1]) + 1
			per[bp.get_instance_id()] = e
		var need := {}
		for k in per:
			var n: int = per[k][1]
			for e in _groups_of(per[k][0]):
				var gk: String = (e[0] as Dictionary)["key"]
				need[gk] = int(need.get(gk, 0)) + n
		return need

	## Виды деталей, которым не хватит свободных мест под need
	func short(need: Dictionary) -> Dictionary:
		var out := {}
		for k in need:
			var g: Dictionary = groups[k]
			if int(need[k]) > int(g["cap"]) - int(g["used"]) + (g["free"] as Array).size():
				out[k] = true
		return out

	## Эти виды деталей — заново, под need мест: старое содержимое выбрасываем и буфер из видеокарты не читаем
	## (Parts._grow читает его при каждом удвоении — на сотнях домов это долгие остановки)
	func regrow(keys: Dictionary, need: Dictionary) -> void:
		for k in keys:
			var g: Dictionary = groups[k]
			g["used"] = 0
			g["free"] = []
			var cap: int = maxi(16, int(g["cap"]))
			# с запасом в четверть: надстроили один дом — места есть, остальные дома этого вида не гаснут заново
			while cap < int(float(need.get(k, 0)) * 1.25) + 4:
				cap *= 2
			g["cap"] = cap
			for sub in g["subs"]:
				var mm: MultiMesh = sub["mm"]
				if mm.instance_count != cap:
					mm.instance_count = cap
				mm.visible_instance_count = 0

	## Как Parts.place, но группы деталей чертежа помним и цвет ставим сразу
	func place_tinted(bp: Bp, xf: Transform3D, col: Color) -> Array:
		var handles := []
		for e in _groups_of(bp):
			var g: Dictionary = e[0]
			var slot := _alloc(g)
			var t: Transform3D = xf * (e[1] as Transform3D)
			for sub in g["subs"]:
				var mm: MultiMesh = sub["mm"]
				mm.set_instance_transform(slot, t * (sub["local"] as Transform3D))
				mm.set_instance_custom_data(slot, col)
			handles.append([g, slot])
		return handles

	func paint(handles: Array, col: Color) -> void:
		for e in handles:
			for sub in (e[0] as Dictionary)["subs"]:
				(sub["mm"] as MultiMesh).set_instance_custom_data(e[1], col)

	## Вид деталей пуст (ни одной живой ручки): места с нуля, видимых — ноль. Иначе MultiMesh так и рисует
	## прежний пик пустых мест (Parts.remove только обнуляет детали, а число видимых не уменьшает)
	func reset_group(g: Dictionary) -> void:
		g["used"] = 0
		g["free"] = []
		for sub in g["subs"]:
			(sub["mm"] as MultiMesh).visible_instance_count = 0

	func reset_all() -> void:
		for k in groups:
			if int(groups[k]["used"]) > 0:
				reset_group(groups[k])


var game
var pool: Pool
var lit := {}                 # id → {h: ручки в пуле, col: цвет, tier, variant, color, pos, yaw — облик, с которым зажгли}
var want := {}                # id → цвет: что должно светиться
var todo: Array = []          # кого ещё зажечь (ближние — в конце: берём pop_back)
var marks := {}               # ключ значка → true: такие же постройки, рожицы и ✗ «Обзора»
var state := ""               # "" | "place" | "sel" | "ov" — что сейчас подсвечено
var sets := {}                # последние наборы — для подписи у курсора, легенды «Обзора» и проверок
var cap := ["", "", ""]       # подпись у курсора: [зелёная строка, синяя строка, предупреждение / заметка]
var _type := ""
var _cell := Vector2i(1 << 30, 0)
var _near := Vector2.INF
var _shown := false           # подпись у курсора видна
var _far := false             # «Обзор» счастья построен для дальней камеры (рожицы без цифр)


func setup(g) -> void:
	game = g
	pool = Pool.new()
	pool.src = g.parts
	pool.mat = ShaderMaterial.new()
	pool.mat.shader = load("res://shaders/cover.gdshader")
	add_child(pool)


## Постройка, охват которой показываем подсветкой: shop, monument, decor, store; иначе ""
static func kind_of(type: String) -> String:
	if not Defs.B.has(type):
		return ""
	var k: String = Defs.B[type]["kind"]
	return k if k in ["shop", "monument", "decor", "store"] else ""


static func with_name(type: String) -> String:
	return WITH.get(type, "с такой же постройкой")


# ---------- наборы (город не меняют; их же проверяют тесты) ----------

## Если поставить type в pos: green — кому постройка правда что-то даст; blue — у кого такое уже есть
## (у лавок, памятников и складов — по всему городу, у украшений — в их радиусе, кому больше не прибавится);
## new / dup — для подписи: сколько новых и сколько из её охвата уже с такой же. pos = INF — только синие
## why — лавка тут не заработает: "store" (нет склада рядом), "good" (нет сырья); тогда зелёных нет.
## half — украшение: дома, где его очки копятся (прибавит вместе со следующим), — без цвета
static func place_sets(c: City, type: String, pos: Vector2) -> Dictionary:
	var d: Dictionary = Defs.B[type]
	var green := []
	var blue := []
	var dup := 0
	var half := 0
	var why := ""
	var at := pos.is_finite()
	match d["kind"]:
		"shop":
			for id in c.buildings:
				var h: Dictionary = c.buildings[id]
				if c.is_house(h) and (h.get("score", {}) as Dictionary).has(type):
					blue.append(id)
			# как в City.compute: без склада рядом или без сырья лавка стоит — никому ничего не даст
			if at and d.get("store", false) and not _store_near({"pos": pos}, _stores(c, -1), _store_r(c)):
				why = "store"
			elif at and d.has("needs_good") and not c.goods.has(d["needs_good"]):
				why = "good"
			if at and why == "":
				# как в City.compute: ближайшие дома в дальности, сначала жилые, сколько потянет при полном найме
				for id in _nearest(c, pos, c.shop_range(d), int(Defs.CAPACITY[int(d["cap"])])):
					if (c.buildings[id].get("score", {}) as Dictionary).has(type):
						dup += 1
					else:
						green.append(id)
		"monument":
			var r := Defs.range_m(d)
			for id in c.buildings:
				var h: Dictionary = c.buildings[id]
				if not c.is_house(h):
					continue
				var has := (h.get("mon_types", {}) as Dictionary).has(type)     # одинаковые памятники не складываются
				if has:
					blue.append(id)
				if at and (h["pos"] as Vector2).distance_to(pos) <= r:
					if has:
						dup += 1
					else:
						green.append(id)
		"decor":
			if at:
				var pts := float(d.get("deco", 1))
				for id in c.buildings:
					var h: Dictionary = c.buildings[id]
					if not c.is_house(h) or (h["pos"] as Vector2).distance_to(pos) > Defs.DECOR_RADIUS:
						continue
					if _deco_gain(c, h, pts) > 0:
						green.append(id)
					elif _deco_capped(c, h):
						blue.append(id)              # украшений уже сколько можно — больше не прибавится
						dup += 1
					else:
						half += 1                    # очки копятся: +1% придёт со следующим украшением
		"store":
			var stores := _stores(c, -1)
			var r := _store_r(c)
			for id in c.buildings:
				var s: Dictionary = c.buildings[id]
				if not _needs_store(c, s):
					continue
				var has := _store_near(s, stores, r)
				if has:
					blue.append(id)
				if at and (s["pos"] as Vector2).distance_to(pos) <= r:
					if has:
						dup += 1
					else:
						green.append(id)
	return {"green": green, "blue": blue, "new": green.size(), "dup": dup, "why": why, "half": half}


## Выбранная постройка: green — кому она одна это даёт; blue — кого снабжают (радуют) другие такие же;
## own — сколько домов (лавок у склада) у неё, dup — сколько из них есть и у других таких же
static func selected_sets(c: City, b: Dictionary) -> Dictionary:
	var d := c.def(b)
	var type: String = b["type"]
	var bid := int(b["id"])
	var on := bool(b.get("active", true))
	var own := []
	var other := {}
	var green := []
	var blue := []
	var dup := 0
	match d["kind"]:
		"shop":
			if on:
				own = b.get("serves", [])
			for id in c.buildings:
				var s: Dictionary = c.buildings[id]
				if s["type"] == type and int(id) != bid and bool(s.get("active", false)):
					for hid in s.get("serves", []):
						other[int(hid)] = true
		"monument":
			var r := Defs.range_m(d)
			var mons := []
			for id in c.buildings:
				var m: Dictionary = c.buildings[id]
				if m["type"] == type and int(id) != bid and bool(m.get("active", false)):
					mons.append(m)
			for id in c.buildings:
				var h: Dictionary = c.buildings[id]
				if not c.is_house(h):
					continue
				if on and (h["pos"] as Vector2).distance_to(b["pos"]) <= r:
					own.append(id)
				for m in mons:
					if (h["pos"] as Vector2).distance_to(m["pos"]) <= r:
						other[int(id)] = true
						break
		"decor":
			# украшения складываются: зелёным без него станет хуже, синим украшений и так сколько можно;
			# half — его очки копятся (прибавят вместе со следующим украшением), такие дома без цвета
			var pts := float(d.get("deco", 1))
			var half := 0
			for id in c.buildings:
				var h: Dictionary = c.buildings[id]
				if not c.is_house(h) or (h["pos"] as Vector2).distance_to(b["pos"]) > Defs.DECOR_RADIUS:
					continue
				own.append(id)
				if _deco_gain(c, h, -pts) < 0:
					green.append(id)
				elif _deco_capped(c, h):
					blue.append(id)
					dup += 1
				else:
					half += 1
			return {"green": green, "blue": blue, "own": own.size(), "dup": dup, "half": half}
		"store":
			var r := _store_r(c)
			var stores := _stores(c, bid)
			for id in c.buildings:
				var s: Dictionary = c.buildings[id]
				if not _needs_store(c, s):
					continue
				if on and (s["pos"] as Vector2).distance_to(b["pos"]) <= r:
					own.append(id)
				if _store_near(s, stores, r):
					other[int(id)] = true
		_:
			return {"green": [], "blue": [], "own": 0, "dup": 0}
	for id in own:
		if other.has(int(id)):
			dup += 1
		else:
			green.append(int(id))
	for id in other:
		if c.buildings.has(id):
			blue.append(id)
	return {"green": green, "blue": blue, "own": own.size(), "dup": dup}


## «Обзор»: mode — "happy" или вид потребности (food, clothes…). Только дома, где живут (или куда идёт семья).
## tint — id → цвет; faces — id → счастье (рожицы); miss — дома, где этого нет (значок ✗);
## shops — лавки этой потребности (их значки); n — [хорошо / есть, так себе, плохо / нет]
static func overview_sets(c: City, mode: String) -> Dictionary:
	var tint := {}
	var faces := {}
	var miss := []
	var shops := []
	var n := [0, 0, 0]
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		var d := c.def(b)
		if d["kind"] == "shop":
			if d.get("sub", "") == mode:
				shops.append(id)
			continue
		if d["kind"] != "house" or int(b["pop"]) + int(b.get("coming", 0)) <= 0:
			continue
		if mode == "happy":
			var hp := clampi(int(b.get("happy", 0)), 0, 100)
			var k := 0 if hp >= HAPPY_GOOD else (1 if hp >= HAPPY_BAD else 2)
			tint[id] = [GREEN, GOLD, RED][k]
			faces[id] = hp
			n[k] += 1
		elif (Defs.CLASSES[d["cls"]]["needs"] as Array).has(mode):
			if (b.get("needs", {}) as Dictionary).has(mode):
				tint[id] = GREEN
				n[0] += 1
			else:
				tint[id] = RED
				miss.append(id)
				n[2] += 1
	return {"tint": tint, "faces": faces, "miss": miss, "shops": shops, "n": n}


## Инструмент «Этаж» (U): ready — дома, которым можно надстроить этаж прямо сейчас (зелёные, над крышей стрелка с ценой);
## short — готовы, но не хватает денариев (стрелка с красной ценой, без подсветки); price — id → цена следующего этажа
static func floor_sets(c: City) -> Dictionary:
	var ready := []
	var short := []
	var price := {}
	if c.research.has("floor2"):
		for id in c.buildings:
			var h: Dictionary = c.buildings[id]
			if not c.is_house(h) or c.can_buy_floor(h, false) != "":
				continue
			price[id] = c.floor_price(h)
			if c.money >= float(price[id]):
				ready.append(id)
			else:
				short.append(id)
	return {"ready": ready, "short": short, "price": price}


## Подпись у курсора: [сколько новых (зелёным), сколько уже с такой же (синим), третья строка — предупреждение
## (лавка тут не заработает) или у украшения — скольким прибавит вместе со следующим]
static func caption(type: String, s: Dictionary) -> Array:
	var n: int = s.get("new", 0)
	var k: int = s.get("dup", 0)
	var w := with_name(type)
	match Defs.B[type]["kind"]:
		"shop":
			match String(s.get("why", "")):
				"store":
					return ["", "", "Нет склада рядом — лавка не заработает"]
				"good":
					return ["", "", "Нет сырья — нужно «%s»" % _farm_name(String(Defs.B[type].get("needs_good", "")))]
			if n == 0 and k == 0:
				return ["", "Рядом нет домов — лавке некого снабжать", ""]
			if n == 0:
				return ["", "Тут все дома уже %s — поставьте дальше" % w, ""]
			return ["Новых домов: %d" % n, ("Уже %s: %d" % [w, k]) if k > 0 else "", ""]
		"monument":
			if n == 0 and k == 0:
				return ["", "Рядом нет домов", ""]
			if n == 0:
				return ["", "Тут все дома уже %s — поставьте дальше" % w, ""]
			return ["Порадует домов: %d" % n, ("Уже %s: %d" % [w, k]) if k > 0 else "", ""]
		"decor":
			var hf: int = s.get("half", 0)
			if n == 0 and k == 0 and hf == 0:
				return ["", "Рядом нет домов", ""]
			return [("Украсит домов: %d" % n) if n > 0 else "", ("Украшений уже хватает: %d" % k) if k > 0 else "",
				("Со следующим украшением прибавит домам: %d" % hf) if hf > 0 else ""]
		"store":
			if n == 0 and k == 0:
				return ["", "Рядом нет лавок, которым нужен склад", ""]
			return [("Склад получат лавки: %d" % n) if n > 0 else "", ("Уже со складом: %d" % k) if k > 0 else "", ""]
	return ["", "", ""]


## Откуда сырьё good: имя поля или рощи, что его даёт (как в City.idle_text)
static func _farm_name(good: String) -> String:
	for t in Defs.B:
		if Defs.B[t].get("makes", "") == good:
			return String(Defs.B[t]["name"])
	return "поле"


static func _nearest(c: City, pos: Vector2, r: float, n: int) -> Array:
	var near := []
	for id in c.buildings:
		var h: Dictionary = c.buildings[id]
		if not c.is_house(h):
			continue
		var dd := (h["pos"] as Vector2).distance_to(pos)
		if dd <= r:
			var lived := int(h["pop"]) + int(h.get("coming", 0)) > 0
			near.append([dd + (0.0 if lived else 10000.0), id])
	near.sort_custom(func(a, b): return a[0] < b[0])
	var out := []
	for i in mini(n, near.size()):
		out.append(near[i][1])
	return out


## На сколько процентов изменится украшение дома, если рядом прибавить (или убрать) pts очков (как в City.compute)
static func _deco_gain(c: City, h: Dictionary, pts: float) -> int:
	var cd: Dictionary = Defs.CLASSES[c.def(h)["cls"]]
	var now := int(h.get("deco_bonus", 0))
	return mini(int(cd.get("deco_max", 12)), int(floor(maxf(0.0, float(h.get("deco", 0.0)) + pts) * Defs.DECO_RATE))) - now


## Украшений у дома уже сколько можно (deco_max класса): больше не прибавится. Не путать с «не прибавилось из-за
## округления» — +1% за каждые 2 очка, одно очко ждёт следующего
static func _deco_capped(c: City, h: Dictionary) -> bool:
	return int(h.get("deco_bonus", 0)) >= int(Defs.CLASSES[c.def(h)["cls"]].get("deco_max", 12))


static func _store_r(c: City) -> float:
	return float(Defs.RANGE[4]) * (2.0 if c.research.has("store1") else 1.0)     # как City._store_near


static func _stores(c: City, skip: int) -> Array:
	var out := []
	for id in c.buildings:
		var w: Dictionary = c.buildings[id]
		if int(id) != skip and c.def(w)["kind"] == "store" and bool(w.get("active", false)):
			out.append(w)
	return out


static func _needs_store(c: City, s: Dictionary) -> bool:
	var d := c.def(s)
	return d["kind"] == "shop" and d.get("store", false)


static func _store_near(s: Dictionary, stores: Array, r: float) -> bool:
	for w in stores:
		if (w["pos"] as Vector2).distance_to(s["pos"]) <= r:
			return true
	return false


# ---------- что сейчас подсвечено ----------

## Всё заново: сменился инструмент, выбор, режим «Обзора» или город (city.changed)
func refresh() -> void:
	if game == null or game.city == null:
		return
	_cell = Vector2i(1 << 30, 0)
	var c: City = game.city
	var t: String = game.tool
	var hud = game.hud
	if t == "" and hud != null and hud.overlay != "":
		_overview(hud.overlay)
	elif t == "floor":
		_floor()
	elif kind_of(t) != "":
		if t != _type:
			_near = Vector2.INF                  # новая стройка: зелёные — когда курсор встанет на землю
		_type = t
		_place(t, _near)
	elif t == "" and not game.selected.is_empty() and c.buildings.has(int(game.selected.get("id", -1))) \
			and kind_of(String(game.selected["type"])) != "":
		_selected(c.buildings[int(game.selected["id"])])
	else:
		clear()


## Курсор со стройкой над землёй (каждый кадр из game._update_tool): пересчёт, только если сдвинулись на метр
func preview(type: String, pos: Vector2) -> void:
	var cell := Vector2i(floori(pos.x), floori(pos.y))
	if cell != _cell or type != _type:
		_cell = cell
		_type = type
		_near = pos
		_place(type, pos)
	if game.hud:
		game.hud.cover_caption(cap[0], cap[1], cap[2])
		_shown = true


## Курсор ушёл с земли или на окно: подпись прячем (подсветка остаётся)
func preview_off() -> void:
	if _shown:
		_shown = false
		if game.hud:
			game.hud.cover_caption("", "", "")


func clear() -> void:
	state = ""
	sets = {}
	cap = ["", "", ""]
	_type = ""
	_near = Vector2.INF
	preview_off()
	_apply({}, Vector2.INF)
	_marks({})


func _place(type: String, pos: Vector2) -> void:
	var c: City = game.city
	sets = place_sets(c, type, pos)
	state = "place"
	var w := {}
	for id in sets["blue"]:
		w[id] = BLUE
	for id in sets["green"]:
		w[id] = GREEN
	_apply(w, pos)
	_marks(_wh_marks(type, _same_marks(type, -1)))
	cap = caption(type, sets) if pos.is_finite() else ["", "", ""]


func _selected(b: Dictionary) -> void:
	var c: City = game.city
	sets = selected_sets(c, b)
	state = "sel"
	cap = ["", "", ""]
	var w := {}
	for id in sets["blue"]:
		w[id] = BLUE
	for id in sets["green"]:
		w[id] = GREEN
	_apply(w, b["pos"])
	_marks(_wh_marks(String(b["type"]), _same_marks(String(b["type"]), int(b["id"]))))


func _overview(mode: String) -> void:
	var c: City = game.city
	sets = overview_sets(c, mode)
	state = "ov"
	cap = ["", "", ""]
	_apply(sets["tint"], Vector2.INF)
	var mk := {}
	_far = game.rig != null and float(game.rig.dist) > FAR
	if mode == "happy":
		for id in sets["faces"]:
			var hp: int = sets["faces"][id]
			var face := "face_good" if hp >= HAPPY_GOOD else ("face_mid" if hp >= HAPPY_BAD else "face_bad")
			mk["ov%d" % id] = [id, face, false, "", "plain"] if _far else [id, face, false, "%d%%" % hp]
	else:
		for id in sets["miss"]:
			mk["ov%d" % id] = [id, "close", true, "", "plain"]
		for id in sets["shops"]:
			var s: Dictionary = c.buildings[id]
			mk["ovs%d" % id] = [id, String(c.def(s).get("icon", "info")), not bool(s.get("active", true)), "", "mark"]
	_marks(mk)
	if game.hud:
		game.hud.fill_overlay()


## Инструмент «Этаж»: готовые дома зелёные, над каждым готовым — стрелка с ценой этажа (не хватает денариев — цена красная)
func _floor() -> void:
	var c: City = game.city
	sets = floor_sets(c)
	state = "floor"
	var w := {}
	for id in sets["ready"]:
		w[id] = GREEN
	_apply(w, game.hover)
	var mk := {}
	for k in ["ready", "short"]:
		for id in sets[k]:
			var price := int(sets["price"][id])
			mk["fl%d" % id] = [id, "up", k == "short", game.hud.fmt(price) if game.hud else str(price), ""]
	_marks(mk)


## Подпись у курсора от инструмента «Этаж» (game._floor_hover): [зелёная, синяя, кремовая строка]
func say(lines: Array) -> void:
	cap = lines
	if game.hud:
		game.hud.cover_caption(cap[0], cap[1], cap[2])
		_shown = true


## Значки над такими же постройками (лавки, памятники, склады): где они уже стоят. Неработающие — красным
func _same_marks(type: String, skip: int) -> Dictionary:
	var mk := {}
	if Defs.B[type]["kind"] == "decor":
		return mk
	var c: City = game.city
	var icon := String(Defs.B[type].get("icon", "info"))
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		if b["type"] == type and int(id) != skip:
			mk["same%d" % id] = [id, icon, not bool(b.get("active", true)), "", "mark"]
	return mk


## Лавке нужен склад — значки и над складами: видно, где лавка заработает (кругов дальности нет)
func _wh_marks(type: String, mk: Dictionary) -> Dictionary:
	if not Defs.B[type].get("store", false):
		return mk
	var c: City = game.city
	for id in c.buildings:
		var w: Dictionary = c.buildings[id]
		if c.def(w)["kind"] == "store":
			mk["wh%d" % id] = [id, String(c.def(w).get("icon", "warehouse")), not bool(w.get("active", false)), "", "mark"]
	return mk


## Значки: mk — ключ → [id постройки, значок, красный ли, надпись, вид (hud.set_badge)]; лишние убираем, новые ставим
func _marks(mk: Dictionary) -> void:
	var hud = game.hud
	if hud == null:
		return
	for k in marks.keys():
		if not mk.has(k):
			hud.clear_badge(k)
			marks.erase(k)
	var c: City = game.city
	for k in mk:
		var e: Array = mk[k]
		var id: int = e[0]
		if not c.buildings.has(id):
			continue
		var b: Dictionary = c.buildings[id]
		# над бедой постройки (нет работников, склада…) свой пузырь — наш значок выше него
		var top: float = c.blueprint(b).top_y() + (3.0 if hud.world_icons.has(id) else 1.2)
		var cb := func(): _open(id)               # щёлкнуть значок (без стройки в руках) — карточка этой постройки
		hud.set_badge(k, Vector3(b["pos"].x, float(b["y"]) + top, b["pos"].y), e[1], e[2], e[3] if e.size() > 3 else "", cb, e[4] if e.size() > 4 else "")
		marks[k] = true


func _open(id: int) -> void:
	var c: City = game.city
	if c.buildings.has(id):
		game.select_building(c.buildings[id])
		game.hud.open_info(c.buildings[id])


# ---------- пул подсветки ----------

## Подсветить дома w (id → цвет): погасить лишние, перекрасить оставшиеся, новые — в очередь (ближние к near первыми)
func _apply(w: Dictionary, near: Vector2) -> void:
	var c: City = game.city
	var t0 := Time.get_ticks_usec()
	want = w
	todo.clear()
	if w.is_empty():
		lit.clear()                          # гасим всё разом: места с нуля (пул уйдёт из сцены в _process)
		pool.reset_all()
		return
	var hi := 0
	for k in pool.groups:
		hi += int(pool.groups[k]["used"])
	if hi > 1024 and w.size() <= PER_FRAME and lit.size() > w.size() * 4:
		# из многих домов (после «Обзора» на весь город) светиться останется мало — весь пул заново: эти дома
		# зажгутся сразу, а прежний пик пустых мест MultiMesh рисовать не будут (и не гасим сотни домов по одному)
		lit.clear()
		pool.reset_all()
	else:
		for id in lit.keys():
			var e: Dictionary = lit[id]
			var b: Dictionary = c.buildings.get(id, {})
			if not w.has(id) or b.is_empty() or not _same_look(e, b):
				pool.remove(e["h"])
				lit.erase(id)
		# виды деталей, где никого не осталось, — с нуля
		for k in pool.groups:
			var g: Dictionary = pool.groups[k]
			if int(g["used"]) > 0 and (g["free"] as Array).size() >= int(g["used"]):
				pool.reset_group(g)
	for id in w:
		if lit.has(id):
			var e: Dictionary = lit[id]
			if e["col"] != w[id]:
				pool.paint(e["h"], _gpu(w[id]))
				e["col"] = w[id]
		elif c.buildings.has(id):
			todo.append(id)
	if not todo.is_empty():
		_reserve(c)
	if todo.size() > PER_FRAME and near.is_finite():
		todo.sort_custom(func(a, b): return (c.buildings[a]["pos"] as Vector2).distance_squared_to(near) > (c.buildings[b]["pos"] as Vector2).distance_squared_to(near))
	_light_some(t0)


## Мест в пуле не хватит (новые виды деталей или домов больше, чем светилось раньше): эти виды растут разом,
## без чтения из видеокарты; дома, у которых в них были детали, гаснут и зажигаются заново вместе с новыми
func _reserve(c: City) -> void:
	var bps := []
	for id in todo:
		bps.append(c.blueprint(c.buildings[id]))
	var sh := pool.short(pool.need_of(bps))
	if sh.is_empty():
		return
	for id in lit.keys():
		var h: Array = lit[id]["h"]
		var hit := false
		for hd in h:
			if sh.has((hd[0] as Dictionary)["key"]):
				hit = true
				break
		if not hit:
			continue
		var keep := []
		for hd in h:
			if not sh.has((hd[0] as Dictionary)["key"]):
				keep.append(hd)
		pool.remove(keep)
		lit.erase(id)
		todo.append(id)
		bps.append(c.blueprint(c.buildings[id]))
	pool.regrow(sh, pool.need_of(bps))


func _process(_dt: float) -> void:
	if game == null or pool == null:
		return
	if state == "ov" and game.rig != null and game.hud != null and game.hud.overlay == "happy" and (float(game.rig.dist) > FAR) != _far:
		_overview("happy")                   # камеру отдалили или приблизили — рожицы с цифрами или без
	if not todo.is_empty():
		_light_some()
	_vis()


## Пул в сцене, только когда есть что подсветить: без подсветки — ни вызовов отрисовки, ни копии экрана для шейдера.
## В ролике нового ранга и на фото без интерфейса подсветки тоже нет
func _vis() -> void:
	var show: bool = not lit.is_empty() and not (game.rig != null and game.rig.cine) and not (game.hud != null and game.hud.hidden_ui)
	if pool.visible != show:
		pool.visible = show


func _light_some(t0 := -1) -> void:
	var c: City = game.city
	var n := 0
	if t0 < 0:
		t0 = Time.get_ticks_usec()
	# не больше PER_FRAME домов и не дольше ~4 мс от начала (t0 — вместе с подготовкой мест в пуле); один дом — всегда
	while n < PER_FRAME and not todo.is_empty() and (n == 0 or Time.get_ticks_usec() - t0 < FRAME_US):
		var id: int = todo.pop_back()
		if lit.has(id) or not want.has(id) or not c.buildings.has(id):
			continue
		var b: Dictionary = c.buildings[id]
		var h := pool.place_tinted(c.blueprint(b), c.xf(b), _gpu(want[id]))
		lit[id] = {"h": h, "col": want[id], "tier": int(b["tier"]), "variant": int(b.get("variant", 0)), "color": int(b.get("color", 0)),
			"pos": b["pos"], "yaw": float(b["yaw"])}
		n += 1


## Дом с тех пор не перестроили (этаж, цвет, перенос) — его оболочка всё ещё по нему
static func _same_look(e: Dictionary, b: Dictionary) -> bool:
	return int(e["tier"]) == int(b["tier"]) and int(e["variant"]) == int(b.get("variant", 0)) and int(e["color"]) == int(b.get("color", 0)) \
		and e["pos"] == b["pos"] and is_equal_approx(float(e["yaw"]), float(b["yaw"]))


## Цвет для шейдера: INSTANCE_CUSTOM идёт как есть — переводим в линейный, прозрачность общая
static func _gpu(col: Color) -> Color:
	var g := col.srgb_to_linear()
	g.a = ALPHA
	return g
