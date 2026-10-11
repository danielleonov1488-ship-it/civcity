class_name City
extends RefCounted
## Жизнь города — как в Town to City: три класса жителей, лавки по видам потребностей обслуживают
## ближайшие дома в своей дальности (сколько потянут рабочие), памятники и украшения радуют всех вокруг,
## теснота огорчает. Счастливые дома сами надстраивают этажи, в свободные места приезжают семьи.
## Деньги — налоги с домов; очки исследований — скрипторий, школа, библиотека. Уровень города растёт
## от числа жителей и их счастья.

signal changed                       # что-то поменялось — перерисовать интерфейс
signal building_added(b)
signal building_removed(b)
signal house_changed(b, up)
signal event(text, icon)             # событие для колокольчика и всплывашки справа
signal family_left(home, name)       # семья уехала из дома (жители уходят в тоннель)

var land: Land
var money := float(Defs.START_MONEY)
var rp := 0.0
var day := 0
var level := 0
var research := {}                    # id → true
var buildings := {}                   # id → запись постройки
var next_id := 1
var stats := {"pop": 0, "happy": 0, "income": 0.0, "upkeep": 0.0, "rp_day": 0.0, "residents": {}, "workers": {}, "jobs": {}, "free": {}, "class_happy": {}}
var goods := {}                       # сырьё, которое есть в городе: wheat, olives, grapes
var settle_queue: Array = []          # [id дома, сколько человек]
var waiting := 0                      # семьи на станции, которым не хватило жилья
var goals_done: Array = []
var events: Array = []                # [{day, text, icon}]
var road_cells := 0                   # сколько клеток дорог проложил игрок
var rng := RandomNumberGenerator.new()


func _init(l: Land) -> void:
	land = l
	rng.seed = 5


func def(b: Dictionary) -> Dictionary:
	return Defs.B[b["type"]]


func is_house(b: Dictionary) -> bool:
	return def(b)["kind"] == "house"


func unlocked(type: String) -> bool:
	var u: String = Defs.B[type].get("unlock", "")
	return u == "" or research.has(u)


func blueprint(b: Dictionary) -> Bp:
	return Catalog.make(b["type"], int(b["tier"]), int(b.get("variant", 0)), int(b.get("color", 0)))


func xf(b: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, b["yaw"]), Vector3(b["pos"].x, b["y"], b["pos"].y))


static func facing(yaw: float) -> Vector2:
	return Vector2(sin(yaw), cos(yaw))


static func axis(yaw: float) -> Vector2:
	return Vector2(cos(yaw), -sin(yaw))


func door_point(b: Dictionary) -> Vector2:
	var p3: Vector3 = Transform3D(Basis(Vector3.UP, b["yaw"]), Vector3(b["pos"].x, 0, b["pos"].y)) * blueprint(b).door
	return Vector2(p3.x, p3.z)


func center() -> Dictionary:
	for id in buildings:
		if buildings[id]["type"] == "center":
			return buildings[id]
	return {}


func building_at(p: Vector2) -> Dictionary:
	var id := land.occ_at(p)
	return buildings.get(id, {})


func money_cap() -> float:
	var c := float(Defs.LEVELS[level]["money"])
	if research.has("vault1"):
		c *= 2.0
	if research.has("vault2"):
		c *= 2.0
	return c


func rp_cap() -> float:
	return float(Defs.LEVELS[level]["rp"]) * (2.0 if research.has("research1") else 1.0)


func house_cap(b: Dictionary) -> int:
	var cls: String = def(b)["cls"]
	return int(Defs.CLASSES[cls]["per_floor"]) * int(b["tier"])


# ---------- стройка ----------

## Можно ли поставить; возвращает {"err": текст или "", "cells": клетки, "y": высота}
func check_place(type: String, pos: Vector2, yaw: float, variant := 0, color := 0, ignore_id := -1) -> Dictionary:
	var d: Dictionary = Defs.B[type]
	var res := {"err": "", "cells": PackedInt32Array(), "y": 0.0}
	if not unlocked(type):
		res["err"] = "Откроется исследованием «%s»" % Defs.research(d["unlock"]).get("name", "")
		return res
	if money < float(d["cost"]) and ignore_id == -1:
		res["err"] = "Не хватает денариев"
		return res
	var tier := 1 if d["kind"] == "house" else (6 if type == "center" else 0)   # станция занимает место на вырост
	var bp := Catalog.make(type, tier, variant, color)
	var cells := land.footprint_cells(bp.footprint(), pos, yaw)
	if cells.is_empty():
		cells = land.footprint_cells([Rect2(-0.4, -0.4, 0.8, 0.8)], pos, yaw)
	res["cells"] = cells
	var lo := INF
	var hi := -INF
	var on_water := 0
	for k in cells:
		var q := land.cell_center(k % Land.N, k / Land.N)
		if q.x < 1.0 or q.y < 1.0 or q.x > Land.SIZE - 1.0 or q.y > Land.SIZE - 1.0:
			res["err"] = "Край карты"
			return res
		if not land.is_owned(q) and ignore_id != -2:
			res["err"] = "Эта земля ещё не куплена"
			return res
		var o := land.occ[k]
		if o != 0 and o != ignore_id:
			res["err"] = "Место занято"
			return res
		var y := land.hq(k)
		if y < Land.WATER_Y + 0.05:
			on_water += 1
		lo = minf(lo, y)
		hi = maxf(hi, y)
	if d.get("water", false):
		if on_water < cells.size():
			res["err"] = "Ставится только на воду"
			return res
		res["y"] = Land.WATER_Y - 0.02
		return res
	if on_water > 0:
		res["err"] = "Здесь вода"
		return res
	if hi - lo > 1.3:
		res["err"] = "Слишком круто"
		return res
	res["y"] = roundf((lo + hi) * 0.5 / Land.STEP) * Land.STEP
	if d["kind"] != "decor" and d["kind"] != "farm" and type != "center":
		var dp3: Vector3 = Transform3D(Basis(Vector3.UP, yaw), Vector3(pos.x, 0, pos.y)) * bp.door
		if not _road_near(Vector2(dp3.x, dp3.z), 1.7, cells):
			res["err"] = "Нужна дорога у входа"
			return res
	return res


func _road_near(p: Vector2, r: float, own_cells: PackedInt32Array) -> bool:
	var c := land.cell(p)
	var rc := int(ceil(r / Land.CELL))
	for j in range(c.y - rc, c.y + rc + 1):
		for i in range(c.x - rc, c.x + rc + 1):
			if not land.inside(i, j):
				continue
			var k := land.idx(i, j)
			if Land.walk_kind(land.kind[k]) and land.occ[k] == 0 and land.cell_center(i, j).distance_to(p) <= r:
				return true
	return false


## Поставить постройку (деньги списываются); возвращает запись. free — даром и без проверок (готовый город)
func place(type: String, pos: Vector2, yaw: float, variant := 0, color := -1, free := false) -> Dictionary:
	var d: Dictionary = Defs.B[type]
	if color < 0:
		color = pick_color(pos)
	var chk := check_place(type, pos, yaw, variant, color, -2 if free else -1)
	var b := {"id": next_id, "type": type, "tier": 1 if d["kind"] == "house" else (level if type == "center" else 0),
		"pos": pos, "yaw": yaw, "variant": variant, "color": color, "y": float(chk["y"]), "cells": chk["cells"],
		"pop": 0, "families": [], "happy": 50, "up": 0, "down": 0, "staff": 1.0, "active": true, "road": true,
		"needs": {}, "served": 0, "score": {}, "missing": [], "coming": 0}
	next_id += 1
	if not free:
		money -= float(d["cost"])
	var cells: PackedInt32Array = b["cells"]
	if not d.get("water", false):
		land.flatten_cells(cells, b["y"], Land.Kind.FIELD if d["kind"] == "farm" else -1)
	land.set_occ(cells, b["id"])
	buildings[b["id"]] = b
	compute()
	building_added.emit(b)
	changed.emit()
	_check_goals()
	return b


## Цвет новой постройки: не такой, как у соседей
func pick_color(pos: Vector2) -> int:
	var used := {}
	for id in buildings:
		var o: Dictionary = buildings[id]
		if (o["pos"] as Vector2).distance_to(pos) < 11.0:
			used[int(o.get("color", 0))] = true
	var opts := []
	for i in Defs.PALETTE.size():
		if not used.has(i):
			opts.append(i)
	if opts.is_empty():
		return rng.randi() % Defs.PALETTE.size()
	return opts[rng.randi() % opts.size()]


func remove(b: Dictionary, refund := true) -> void:
	if def(b).get("fixed", false):
		return
	if refund:
		money += float(def(b)["cost"]) * Defs.REFUND
	land.set_occ(b["cells"], 0)
	buildings.erase(b["id"])
	settle_queue = settle_queue.filter(func(q): return q[0] != b["id"])
	compute()
	building_removed.emit(b)
	changed.emit()


## Сменить цвет дома (щелчок по значку в карточке)
func recolor(b: Dictionary) -> void:
	b["color"] = (int(b["color"]) + 1) % Defs.PALETTE.size()
	house_changed.emit(b, false)
	changed.emit()


# ---------- расчёт: обслуживание, счастье ----------

func compute() -> void:
	var houses := []
	var residents := {}
	var jobs := {}
	for c in Defs.CLASS_ORDER:
		residents[c] = 0
		jobs[c] = 0
	var shops := []
	var monuments := []
	var decor := []
	var stores := []
	for id in buildings:
		var b: Dictionary = buildings[id]
		var d := def(b)
		match d["kind"]:
			"house":
				houses.append(b)
				residents[d["cls"]] += int(b["pop"])
			"decor":
				decor.append(b)
				continue
		b["road"] = d["kind"] in ["farm", "center"] or _road_near(door_point(b), 1.7, b["cells"])
		if d.has("jobs") and b["road"]:
			for c in d["jobs"]:
				jobs[c] += int(d["jobs"][c])
	# работники: у каждого класса свои, лишние высшего класса идут на работу классом ниже
	var workers := {}
	var spare := {}
	var filled := {}
	for c in Defs.CLASS_ORDER:
		workers[c] = int(floor(residents[c] * float(Defs.CLASSES[c]["work"])))
		filled[c] = mini(jobs[c], workers[c])
		spare[c] = workers[c] - filled[c]
	for pair: Array in [["patricians", "artisans"], ["artisans", "plebs"]]:
		var take := mini(jobs[pair[1]] - filled[pair[1]], spare[pair[0]])
		if take > 0:
			filled[pair[1]] += take
			spare[pair[0]] -= take
	var ratio := {}
	for c in Defs.CLASS_ORDER:
		ratio[c] = float(filled[c]) / jobs[c] if jobs[c] > 0 else 1.0
	goods = {}
	for id in buildings:
		var b: Dictionary = buildings[id]
		var d := def(b)
		if d["kind"] == "decor" or d["kind"] == "house":
			continue
		var st := 1.0
		if d.has("jobs"):
			for c in d["jobs"]:
				st = minf(st, ratio[c])
		b["staff"] = st if b["road"] else 0.0
		b["active"] = b["road"] and (not d.has("jobs") or float(b["staff"]) >= 0.25)
		if d["kind"] == "farm" and b["active"]:
			goods[d["makes"]] = true
		elif d["kind"] == "store" and b["active"]:
			stores.append(b)
	for id in buildings:
		var b: Dictionary = buildings[id]
		var d := def(b)
		if d["kind"] == "shop":
			b["why"] = "" if b["active"] else ("road" if not b["road"] else "staff")
			if b["active"] and d.get("store", false) and not _store_near(b, stores):
				b["active"] = false
				b["why"] = "store"
			if b["active"] and d.has("needs_good") and not goods.has(d["needs_good"]):
				b["active"] = false
				b["why"] = "good"
			if b["active"]:
				shops.append(b)
		elif d["kind"] == "monument" and b["active"]:
			monuments.append(b)
	# лавки обслуживают ближайшие дома в своей дальности, сколько хватит сил
	for h in houses:
		h["score"] = {}            # тип лавки → бонус
		h["needs"] = {}            # вид потребности → true
		h["monuments"] = 0.0
	for s in shops:
		var d := def(s)
		var r := Defs.range_m(d)
		if d["sub"] == "food" and research.has("reach1"):
			r *= 1.33
		var cap := int(ceil(float(Defs.CAPACITY[int(d["cap"])]) * float(s["staff"])))
		var near := []
		for h in houses:
			var dd := (h["pos"] as Vector2).distance_to(s["pos"])
			if dd <= r:
				near.append([dd, h])
		near.sort_custom(func(a, b): return a[0] < b[0])
		var served := 0
		for e in near:
			if served >= cap:
				break
			var h: Dictionary = e[1]
			var sc: Dictionary = h["score"]
			if int(sc.get(s["type"], 0)) < int(d["bonus"]):
				sc[s["type"]] = int(d["bonus"])
			h["needs"][d["sub"]] = true
			served += 1
		s["served"] = served
	var happy_sum := 0.0
	var pop := 0
	for h in houses:
		var cls: String = def(h)["cls"]
		var hp := 40.0
		for t in h["score"]:
			hp += float(h["score"][t])
		for m in monuments:
			var md := def(m)
			if (h["pos"] as Vector2).distance_to(m["pos"]) <= Defs.range_m(md):
				hp += float(md["bonus"])
				h["monuments"] = float(h["monuments"]) + float(md["bonus"])
		var deco := 0.0
		for o in decor:
			if (h["pos"] as Vector2).distance_to(o["pos"]) <= Defs.DECOR_RADIUS:
				deco += float(def(o).get("deco", 1))
		var deco_b := minf(30.0, deco * 0.6)
		hp += deco_b
		var crowd := 0
		for o in houses:
			if o != h and (h["pos"] as Vector2).distance_to(o["pos"]) <= Defs.DENSITY_RADIUS:
				crowd += 1
		var dens := -float(maxi(0, crowd - Defs.DENSITY_FREE)) * 2.0
		hp += dens
		var missing := []
		for n in Defs.CLASSES[cls]["needs"]:
			if not h["needs"].has(n):
				missing.append(n)
		hp -= missing.size() * 10.0
		h["deco"] = deco
		h["deco_bonus"] = deco_b
		h["density"] = dens
		h["missing"] = missing
		h["happy"] = clampi(int(hp), 0, 200)
		happy_sum += minf(100.0, hp) * int(h["pop"])
		pop += int(h["pop"])
	stats["pop"] = pop
	stats["residents"] = residents
	stats["workers"] = workers
	stats["jobs"] = jobs
	stats["free"] = spare
	stats["ratio"] = ratio
	stats["happy"] = int(happy_sum / pop) if pop > 0 else 0
	var per_class := {}
	for c in Defs.CLASS_ORDER:
		var hs := 0.0
		var n := 0
		for h in houses:
			if def(h)["cls"] == c:
				hs += minf(100.0, float(h["happy"])) * maxi(1, int(h["pop"]))
				n += maxi(1, int(h["pop"]))
		per_class[c] = int(hs / n) if n > 0 else 0
	stats["class_happy"] = per_class


func _store_near(s: Dictionary, stores: Array) -> bool:
	var r := float(Defs.RANGE[4]) * (2.0 if research.has("store1") else 1.0)
	for w in stores:
		if (w["pos"] as Vector2).distance_to(s["pos"]) <= r:
			return true
	return false


# ---------- час ----------

## Раз в игровой час: налоги, очки исследований, рост домов, переселенцы, уровень города
func sim_day() -> void:
	compute()
	var income := 0.0
	var upkeep := 0.0
	var rpd := 0.0
	for id in buildings.keys():
		var b: Dictionary = buildings[id]
		var d := def(b)
		match d["kind"]:
			"house":
				var cls: String = d["cls"]
				var tax := float(Defs.CLASSES[cls]["tax"])
				if cls == "patricians" and research.has("taxes1"):
					tax *= 1.25
				income += int(b["pop"]) * tax * (0.5 + minf(100.0, float(b["happy"])) / 100.0)
				_grow_house(b)
			"rp":
				rpd += float(d["rp"]) * float(b["staff"])
			"shop", "monument", "store", "farm":
				upkeep += float(d["cost"]) * 0.0035
	money = minf(money_cap(), money + income - upkeep)
	rp = minf(rp_cap(), rp + rpd)
	stats["income"] = income
	stats["upkeep"] = upkeep
	stats["rp_day"] = rpd
	_request_settlers()
	_update_level()
	_check_goals()
	changed.emit()


## Дом надстраивает этаж, когда жители довольны, дом полон и этаж открыт исследованием
func _grow_house(b: Dictionary) -> void:
	var d := def(b)
	var floors := int(b["tier"])
	var unlocked_floor := 1
	if research.has("floor2"):
		unlocked_floor = 2
	if research.has("floor3"):
		unlocked_floor = 3
	unlocked_floor = mini(unlocked_floor, Defs.floors_max(d["cls"]))
	var need := 55 + 12 * (floors - 1)
	var full := int(b["pop"]) >= house_cap(b)
	if full and floors < unlocked_floor and int(b["happy"]) >= need:
		b["up"] = int(b["up"]) + 1
		if int(b["up"]) >= 3:
			b["up"] = 0
			b["tier"] = floors + 1
			house_changed.emit(b, true)
			_event("Дом семьи %s надстроил %d-й этаж" % [_fam_name(b), floors + 1], "housing")
	else:
		b["up"] = 0
	# несчастные уезжают
	if int(b["happy"]) < 25 and int(b["pop"]) > 0:
		b["down"] = int(b["down"]) + 1
		if int(b["down"]) >= 20:
			b["down"] = 0
			var fams: Array = b["families"]
			if not fams.is_empty():
				var f: Dictionary = fams.pop_back()
				b["pop"] = maxi(0, int(b["pop"]) - int(f["n"]))
				b.erase("_fam_" + str(f["name"]))
				_event("Семья %s уехала: им плохо живётся" % f["name"], "person")
				family_left.emit(b["id"], f["name"])
				house_changed.emit(b, false)
	else:
		b["down"] = 0


func _fam_name(b: Dictionary) -> String:
	var fams: Array = b["families"]
	return fams[0]["name"] if not fams.is_empty() else "без имени"


## Свободные места в домах ждут семьи — повозка привезёт их из тоннеля
func _request_settlers() -> void:
	var queued := {}
	for q in settle_queue:
		queued[q[0]] = int(queued.get(q[0], 0)) + int(q[1])
	var city_ok := int(stats["pop"]) < 12 or int(stats["happy"]) >= 45
	for id in buildings:
		var b: Dictionary = buildings[id]
		if not is_house(b):
			continue
		var free := house_cap(b) - int(b["pop"]) - int(queued.get(id, 0)) - int(b.get("coming", 0))
		if free <= 0 or not city_ok:
			continue
		if waiting > 0:
			continue                          # сначала заселятся те, кто ждёт на площади
		if rng.randf() < 0.75:
			var n := mini(free, rng.randi_range(2, 4))
			settle_queue.append([id, n])


## Привезти семью, которой пока негде жить (будет ждать на площади, как у вокзала в Town to City)
func wants_waiting() -> bool:
	if int(stats["pop"]) < 10 or int(stats["happy"]) < 55:
		return false
	for id in buildings:
		var b: Dictionary = buildings[id]
		if is_house(b) and house_cap(b) - int(b["pop"]) - int(b.get("coming", 0)) > 0:
			return false
	return rng.randf() < 0.01


## Семья дошла до дома
func settled(id: int, n: int, name := "") -> int:
	if not buildings.has(id):
		return 0
	var b: Dictionary = buildings[id]
	var room := house_cap(b) - int(b["pop"])
	n = mini(n, room)
	if n <= 0:
		return 0
	if name == "":
		name = Defs.FAMILIES[rng.randi() % Defs.FAMILIES.size()]
	(b["families"] as Array).append({"name": name, "n": n})
	b["pop"] = int(b["pop"]) + n
	compute()
	house_changed.emit(b, false)
	changed.emit()
	return n


func _update_level() -> void:
	while level < Defs.LEVELS.size() - 1:
		var nx: Dictionary = Defs.LEVELS[level + 1]
		if int(stats["pop"]) >= int(nx["pop"]) and int(stats["happy"]) >= int(nx["happy"]):
			level += 1
			_event("Город теперь — «%s»! Открылись новые исследования, казна вмещает %d ден." % [nx["name"], int(money_cap())], "level")
			var c := center()
			if not c.is_empty():
				c["tier"] = level
				house_changed.emit(c, true)
		else:
			break


func next_level() -> Dictionary:
	return Defs.LEVELS[level + 1] if level < Defs.LEVELS.size() - 1 else {}


# ---------- исследования ----------

func can_research(id: String) -> String:
	var r := Defs.research(id)
	if r.is_empty() or research.has(id):
		return "Уже изучено"
	if int(r["lvl"]) > level:
		return "Нужен уровень «%s»" % Defs.LEVELS[int(r["lvl"])]["name"]
	if r.has("after") and not research.has(r["after"]):
		return "Сначала — «%s»" % Defs.research(r["after"])["name"]
	if rp < float(r["cost"]):
		return "Не хватает очков исследований"
	return ""


func do_research(id: String) -> bool:
	if can_research(id) != "":
		return false
	var r := Defs.research(id)
	rp -= float(r["cost"])
	research[id] = true
	_event("Изучено: %s" % r["name"], "research")
	compute()
	_check_goals()
	changed.emit()
	return true


# ---------- участки ----------

const PLOT_PRICE := [0, 25000, 35000, 50000, 70000, 95000, 125000, 160000, 200000, 250000, 300000, 360000, 430000, 500000, 600000, 700000, 800000, 900000, 1000000, 1200000, 1500000]


func plot_price() -> int:
	var bought := land.owned.size() - 16
	return int(PLOT_PRICE[clampi(bought + 1, 1, PLOT_PRICE.size() - 1)])


func can_buy(p: Vector2i) -> bool:
	if land.owned.has(p):
		return false
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if land.owned.has(p + d):
			return true
	return false


func buy_plot(p: Vector2i) -> bool:
	if not can_buy(p) or money < plot_price():
		return false
	money -= plot_price()
	land.owned[p] = true
	var c := int(Land.PLOT / Land.CELL)
	for j in range(p.y * c, p.y * c + c, Land.CH):
		for i in range(p.x * c, p.x * c + c, Land.CH):
			land._mark(i + 1, j + 1)
	_event("Куплен новый участок земли", "keys")
	_check_goals()
	changed.emit()
	return true


# ---------- задания ----------

const GOALS := [
	{"id": "road1", "text": "Проложите мостовую от станции", "need": 40, "money": 100, "rp": 10, "icon": "road",
		"hint": "Выберите «Мостовую» слева внизу и ведите кисть с зажатой левой кнопкой мыши от площади у станции."},
	{"id": "houses3", "text": "Постройте 3 дома у дороги", "need": 3, "money": 150, "rp": 20, "tool": "house_pleb", "icon": "housing",
		"hint": "Дом ставится фасадом к дороге. Повозка привезёт семьи из тоннеля."},
	{"id": "fruit", "text": "Поставьте фруктовую лавку", "need": 1, "money": 100, "rp": 20, "tool": "stall_fruit", "icon": "food",
		"hint": "Лавка кормит ближайшие дома в своей дальности. Чем больше разных лавок рядом, тем счастливее дом."},
	{"id": "scriptorium", "text": "Постройте скрипторий", "need": 1, "money": 100, "rp": 30, "tool": "scriptorium", "icon": "quill",
		"hint": "Скрипторий даёт очки исследований — за них открываются новые постройки."},
	{"id": "pop30", "text": "Соберите 30 жителей", "need": 30, "money": 200, "rp": 40},
	{"id": "research1", "text": "Изучите что-нибудь", "need": 1, "money": 150, "rp": 0, "icon": "research",
		"hint": "Нажмите на свиток вверху справа — откроется меню исследований. Очки исследований дают скрипторий, школа и библиотека."},
	{"id": "decor5", "text": "Поставьте 5 украшений", "need": 5, "money": 120, "rp": 20, "icon": "flower",
		"hint": "Украшения дают дому очки красоты — до +30% счастья."},
	{"id": "floor2", "text": "Дорастите дом до 2 этажей", "need": 1, "money": 250, "rp": 40,
		"hint": "Изучите «Второй жилой этаж». Довольный полный дом надстроит его сам."},
	{"id": "store", "text": "Склад и мясная лавка", "need": 2, "money": 200, "rp": 40},
	{"id": "pop100", "text": "Соберите 100 жителей", "need": 100, "money": 400, "rp": 80},
	{"id": "artisan", "text": "Постройте дом ремесленников", "need": 1, "money": 300, "rp": 60},
	{"id": "temple", "text": "Постройте храм", "need": 1, "money": 500, "rp": 100},
	{"id": "pop300", "text": "Соберите 300 жителей", "need": 300, "money": 900, "rp": 150},
	{"id": "patrician", "text": "Постройте домус патрициев", "need": 1, "money": 800, "rp": 150},
	{"id": "pop600", "text": "Соберите 600 жителей", "need": 600, "money": 1500, "rp": 300},
]


func _count(pred: Callable) -> int:
	var n := 0
	for id in buildings:
		if pred.call(buildings[id]):
			n += 1
	return n


func goal_progress(id: String) -> int:
	match id:
		"road1": return road_cells
		"houses3": return _count(func(b): return is_house(b))
		"fruit": return _count(func(b): return b["type"] == "stall_fruit")
		"scriptorium": return _count(func(b): return b["type"] == "scriptorium")
		"pop30", "pop100", "pop300", "pop600": return int(stats["pop"])
		"research1": return research.size()
		"decor5": return _count(func(b): return def(b)["kind"] == "decor")
		"floor2": return _count(func(b): return is_house(b) and int(b["tier"]) >= 2)
		"store": return mini(1, _count(func(b): return b["type"] == "warehouse")) + mini(1, _count(func(b): return b["type"] == "butcher"))
		"artisan": return _count(func(b): return b["type"] == "house_artisan")
		"temple": return _count(func(b): return b["type"] == "temple")
		"patrician": return _count(func(b): return b["type"] == "house_patrician")
	return 0


func active_goals(n := 3) -> Array:
	var out := []
	for g in GOALS:
		if not goals_done.has(g["id"]):
			out.append(g)
			if out.size() >= n:
				break
	return out


func _check_goals() -> void:
	for g in active_goals():
		if goal_progress(g["id"]) >= int(g["need"]):
			goals_done.append(g["id"])
			money = minf(money_cap(), money + float(g["money"]))
			rp = minf(rp_cap(), rp + float(g["rp"]))
			_event("Задание выполнено: %s (+%d ден.%s)" % [g["text"], g["money"], (", +%d оч." % g["rp"]) if int(g["rp"]) > 0 else ""], "check")


func _event(text: String, icon: String) -> void:
	events.append({"day": day, "text": text, "icon": icon})
	if events.size() > 60:
		events.pop_front()
	event.emit(text, icon)


# ---------- сохранение ----------

func save_data() -> Dictionary:
	var bl := []
	for id in buildings:
		var b: Dictionary = buildings[id]
		bl.append({"id": id, "type": b["type"], "tier": b["tier"], "x": b["pos"].x, "z": b["pos"].y, "yaw": b["yaw"], "variant": b["variant"],
			"color": b["color"], "y": b["y"], "pop": b["pop"], "families": b["families"],
			"cells": Marshalls.raw_to_base64((b["cells"] as PackedInt32Array).to_byte_array())})
	return {"money": money, "rp": rp, "day": day, "level": level, "research": research.keys(), "buildings": bl, "next_id": next_id,
		"goals": goals_done, "waiting": waiting, "events": events, "road_cells": road_cells}


func load_data(d: Dictionary) -> void:
	money = float(d.get("money", Defs.START_MONEY))
	rp = float(d.get("rp", 0))
	day = int(d.get("day", 0))
	level = int(d.get("level", 0))
	research = {}
	for r in d.get("research", []):
		research[r] = true
	goals_done = d.get("goals", [])
	waiting = int(d.get("waiting", 0))
	road_cells = int(d.get("road_cells", 0))
	events = d.get("events", [])
	next_id = int(d.get("next_id", 1))
	buildings = {}
	for bd in d.get("buildings", []):
		var cells := Marshalls.base64_to_raw(bd.get("cells", "")).to_int32_array()
		var b := {"id": int(bd["id"]), "type": bd["type"], "tier": int(bd["tier"]), "pos": Vector2(float(bd["x"]), float(bd["z"])),
			"yaw": float(bd["yaw"]), "variant": int(bd.get("variant", 0)), "color": int(bd.get("color", 0)), "y": float(bd.get("y", Land.BASE_Y)),
			"cells": cells, "pop": int(bd["pop"]), "families": bd.get("families", []), "happy": 50, "up": 0, "down": 0, "staff": 1.0,
			"active": true, "road": true, "needs": {}, "served": 0, "score": {}, "missing": [], "coming": 0}
		buildings[b["id"]] = b
		land.set_occ(cells, b["id"])
		next_id = maxi(next_id, int(b["id"]) + 1)
	compute()
