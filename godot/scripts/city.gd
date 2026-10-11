class_name City
extends RefCounted
## Жизнь города (перенос браузерной версии): казна с пределом, налоги и содержание, товары на складах,
## работники, обслуживание домов (вода, рынок, храм, термы…), красота, рост и упадок домов,
## переселенцы, звания города, центр города, участки земли, задания.

signal changed            # что-то поменялось — перерисовать интерфейс
signal building_added(b)
signal building_removed(b)
signal house_changed(b, up)
signal message(text, kind)

var land: Land
var money := float(Defs.START_MONEY)
var day := 0
var goods := {}
var buildings := {}              # id → запись постройки
var next_id := 1
var rank := 0
var max_rank := 0
var stats := {"pop": 0, "happy": 0, "taxes": 0.0, "upkeep": 0.0, "trade": 0.0, "income": 0.0, "lost": 0.0, "cap": Defs.BASE_STORAGE,
	"residents": {}, "jobs": {}, "staff": {}, "short": {}}
var goals_done: Array = []
var settle_queue: Array = []      # дома, ждущие переселенцев: [id, сколько]
var plots_bought := 0
var tips_seen: Array = []


func _init(l: Land) -> void:
	land = l
	for g in Defs.GOODS:
		goods[g] = float(Defs.START_GOODS.get(g, 0.0))


# ---------- постройки ----------

static func facing(yaw: float) -> Vector2:
	return Vector2(sin(yaw), cos(yaw))


static func axis(yaw: float) -> Vector2:
	return Vector2(cos(yaw), -sin(yaw))


func def(b: Dictionary) -> Dictionary:
	return Defs.B[b["type"]]


func obb(b: Dictionary, pad := 0.0) -> Dictionary:
	var d := def(b)
	return {"c": b["pos"], "ax": axis(b["yaw"]), "hw": float(d["w"]) / 2.0 + pad, "hd": float(d["d"]) / 2.0 + pad}


static func obb_hit(a: Dictionary, b: Dictionary) -> bool:
	for f in [a, b]:
		var ax: Vector2 = f["ax"]
		for ax2: Vector2 in [ax, Vector2(-ax.y, ax.x)]:
			var pa := _proj(a, ax2)
			var pb := _proj(b, ax2)
			if pa.y <= pb.x or pb.y <= pa.x:
				return false
	return true


static func _proj(f: Dictionary, axis2: Vector2) -> Vector2:
	var c: Vector2 = f["c"]
	var ax: Vector2 = f["ax"]
	var az := Vector2(-ax.y, ax.x)
	var r: float = absf(ax.dot(axis2)) * float(f["hw"]) + absf(az.dot(axis2)) * float(f["hd"])
	var m := c.dot(axis2)
	return Vector2(m - r, m + r)


static func obb_has(f: Dictionary, p: Vector2) -> bool:
	var q: Vector2 = p - (f["c"] as Vector2)
	var ax: Vector2 = f["ax"]
	var az := Vector2(-ax.y, ax.x)
	return absf(q.dot(ax)) <= float(f["hw"]) and absf(q.dot(az)) <= float(f["hd"])


func building_at(p: Vector2) -> Dictionary:
	for id in buildings:
		var b: Dictionary = buildings[id]
		if obb_has(obb(b), p):
			return b
	return {}


func unlocked(type: String) -> bool:
	return max_rank >= int(Defs.B[type].get("rank", 0))


## Почему здесь нельзя строить (пусто — можно)
func check_place(type: String, pos: Vector2, yaw: float, ignore_id := -1) -> String:
	var d: Dictionary = Defs.B[type]
	if not unlocked(type):
		return "Откроется со званием «%s»" % Defs.RANKS[int(d.get("rank", 0))][1]
	if money < float(d["cost"]) and ignore_id < 0:
		return "Не хватает денариев"
	var f := {"c": pos, "ax": axis(yaw), "hw": float(d["w"]) / 2.0, "hd": float(d["d"]) / 2.0}
	var s := land.survey(pos, f["ax"], f["hw"], f["hd"])
	if s[3]:
		return "Эта земля ещё не куплена"
	if s[2]:
		return "Здесь вода"
	if s[4]:
		return "Здесь скалы"
	if float(s[1]) - float(s[0]) > (0.6 if d["kind"] != "decor" else 0.3):
		return "Слишком круто — нужна ровная земля"
	var tight := f.duplicate()
	tight["hw"] = float(tight["hw"]) - 0.05
	tight["hd"] = float(tight["hd"]) - 0.05
	for id in buildings:
		if id == ignore_id:
			continue
		if obb_hit(tight, obb(buildings[id], -0.05)):
			return "Место занято"
	if d["kind"] != "decor" and d["kind"] != "house":
		# большие постройки нельзя ставить поверх дороги
		var on_road := 0
		for u in 5:
			for v in 5:
				var q: Vector2 = pos + (f["ax"] as Vector2) * (u / 2.0 - 1.0) * (float(f["hw"]) - 0.3) + Vector2(-f["ax"].y, f["ax"].x) * (v / 2.0 - 1.0) * (float(f["hd"]) - 0.3)
				if land.kind_at(q.x, q.y) == Land.Kind.ROAD:
					on_road += 1
		if on_road > 3:
			return "Мешает дорога"
	return ""


## Поставить постройку (деньги списываются); возвращает запись
func place(type: String, pos: Vector2, yaw: float, free := false, seed_v := -1) -> Dictionary:
	var d: Dictionary = Defs.B[type]
	var b := {"id": next_id, "type": type, "tier": 0, "pos": pos, "yaw": yaw, "seed": seed_v if seed_v >= 0 else randi() % 6,
		"pop": 0, "up": 0, "down": 0, "needs": {}, "happy": 50, "beauty": 0.0, "road": true, "staff": 1.0, "active": true}
	if d["kind"] == "house":
		b["tier"] = 1 if type == "house" else 0
	next_id += 1
	if not free:
		money -= float(d["cost"])
	# земля под постройкой: выровнять и засыпать (поле — пашня, площади — плитка)
	var f := obb(b)
	var s := land.survey(pos, f["ax"], f["hw"], f["hd"])
	var y: float = roundf((float(s[0]) + float(s[1])) * 0.5 / Land.STEP) * Land.STEP
	b["y"] = y
	var kd := Land.Kind.YARD
	if type in ["farm", "grove", "vineyard"]:
		kd = Land.Kind.FIELD
	elif type in ["market", "forum", "fountain", "center", "theatre"]:
		kd = Land.Kind.PLAZA
	if d["kind"] != "decor":
		land.flatten_obb(pos, f["ax"], f["hw"] + 0.1, f["hd"] + 0.1, y, kd)
	else:
		b["y"] = land.height_at(pos.x, pos.y)
	buildings[b["id"]] = b
	compute()
	building_added.emit(b)
	changed.emit()
	return b


func remove(b: Dictionary, refund := true) -> void:
	if def(b).get("fixed", false):
		return
	if refund:
		money += float(def(b)["cost"]) * Defs.REFUND
	buildings.erase(b["id"])
	if def(b)["kind"] != "decor":
		var f := obb(b)
		land.flatten_obb(b["pos"], f["ax"], f["hw"] + 0.1, f["hd"] + 0.1, b["y"], Land.Kind.GRASS)
	compute()
	building_removed.emit(b)
	changed.emit()


func center() -> Dictionary:
	for id in buildings:
		if buildings[id]["type"] == "center":
			return buildings[id]
	return {}


## Дорога у входа: перед фасадом есть мостовая, площадь или тропа
func has_road(b: Dictionary) -> bool:
	var d := def(b)
	if d.get("noroad", false) or d["kind"] == "decor":
		return true
	var f := facing(b["yaw"])
	var ax := axis(b["yaw"])
	var hw := float(d["w"]) / 2.0
	var hd := float(d["d"]) / 2.0
	for k in 9:
		var t := lerpf(-hw + 0.3, hw - 0.3, k / 8.0)
		for out: float in [0.35, 0.7, 1.1]:
			var p: Vector2 = b["pos"] + f * (hd + out) + ax * t
			var kd := land.kind_at(p.x, p.y)
			if kd == Land.Kind.ROAD or kd == Land.Kind.PLAZA or kd == Land.Kind.DIRT:
				return true
	return false


func door_point(b: Dictionary) -> Vector2:
	var bp := Catalog.make(b["type"], b["tier"], b["seed"])
	var p3: Vector3 = Transform3D(Basis(Vector3.UP, b["yaw"]), Vector3(b["pos"].x, 0, b["pos"].y)) * bp.door
	return Vector2(p3.x, p3.z)


# ---------- расчёт обслуживания ----------

func treasury_cap() -> float:
	return float(Defs.TREASURY_CAPS[mini(max_rank, Defs.TREASURY_CAPS.size() - 1)])


func storage_cap() -> float:
	var c := Defs.BASE_STORAGE
	for id in buildings:
		if buildings[id]["type"] == "warehouse" and buildings[id]["active"]:
			c += Defs.WAREHOUSE_STORAGE
	return c


func compute() -> void:
	var houses := []
	var residents := {"plebs": 0, "citizens": 0, "patricians": 0}
	var jobs := {"plebs": 0, "citizens": 0, "patricians": 0}
	var providers := {"water": [], "market": [], "temple": [], "baths": [], "theatre": [], "forum": []}
	var beauty_src := []
	for id in buildings:
		var b: Dictionary = buildings[id]
		var d := def(b)
		b["road"] = has_road(b)
		if d["kind"] == "house":
			houses.append(b)
			var T: Dictionary = Defs.tiers(b["type"])[b["tier"]]
			if T.has("cls"):
				residents[T["cls"]] += int(b["pop"])
			continue
		if d.has("jobs") and b["road"]:
			for c in d["jobs"]:
				jobs[c] += int(d["jobs"][c])
		if d.get("beauty", 0) > 0:
			beauty_src.append(b)
	var workers := {}
	var filled := {}
	var spare := {}
	for c in residents:
		workers[c] = int(floor(residents[c] * Defs.WORKER_SHARE))
		filled[c] = mini(jobs[c], workers[c])
		spare[c] = workers[c] - filled[c]
	for pair: Array in [["patricians", "citizens"], ["citizens", "plebs"]]:
		var take := mini(jobs[pair[1]] - filled[pair[1]], spare[pair[0]])
		if take > 0:
			filled[pair[1]] += take
			spare[pair[0]] -= take
	var staff := {}
	for c in residents:
		staff[c] = float(filled[c]) / jobs[c] if jobs[c] > 0 else 1.0
	for id in buildings:
		var b: Dictionary = buildings[id]
		var d := def(b)
		if d["kind"] == "house" or d["kind"] == "decor":
			continue
		var st := 1.0
		if d.has("jobs"):
			for c in d["jobs"]:
				st = minf(st, staff[c])
		b["staff"] = st if b["road"] else 0.0
		b["active"] = b["road"] and (not d.has("jobs") or b["staff"] >= 0.25)
		if d.has("provides") and b["active"]:
			providers[d["provides"]].append(b)
	var food := float(goods["wheat"]) + float(goods["fish"])
	var happy_sum := 0.0
	for h in houses:
		var n := {"road": h["road"]}
		for kind in providers:
			n[kind] = false
			for p in providers[kind]:
				var r := float(def(p)["radius"])
				if (h["pos"] as Vector2).distance_squared_to(p["pos"]) <= r * r:
					n[kind] = true
					break
		n["food"] = n["market"] and food > 0.5
		for g in ["oil", "bread", "wine"]:
			n[g] = n["market"] and float(goods[g]) > 0.5
		h["needs"] = n
		var beauty := 0.0
		for s in beauty_src:
			if (h["pos"] as Vector2).distance_to(s["pos"]) <= Defs.BEAUTY_RADIUS:
				beauty += float(def(s)["beauty"])
		h["beauty"] = snappedf(beauty, 0.1)
		var crowd := 0
		for o in houses:
			if o != h and int(o["tier"]) > 0 and (h["pos"] as Vector2).distance_to(o["pos"]) <= Defs.CROWD_RADIUS:
				crowd += 1
		h["crowd"] = crowd
		var tiers := Defs.tiers(h["type"])
		var target := 0
		for t in range(1, tiers.size()):
			if meets(h, t):
				target = t
			else:
				break
		h["target"] = target
		var hp := 40.0
		for need in Defs.NEED_HAPPY:
			if n.get(need, false):
				hp += Defs.NEED_HAPPY[need]
		hp += minf(20.0, h["beauty"] * 2.0)
		hp -= maxf(0, crowd - (2 if h["type"] == "domus" else 4)) * (6 if h["type"] == "domus" else 3)
		h["happy"] = clampi(int(hp), 0, 100)
		happy_sum += h["happy"] * int(h["pop"])
	var pop := 0
	for c in residents:
		pop += residents[c]
	stats["pop"] = pop
	stats["residents"] = residents
	stats["jobs"] = jobs
	stats["workers"] = workers
	stats["staff"] = staff
	stats["happy"] = int(happy_sum / pop) if pop > 0 else 0
	stats["cap"] = storage_cap()


func meets(h: Dictionary, t: int) -> bool:
	var T: Dictionary = Defs.tiers(h["type"])[t]
	for need in T["needs"]:
		if not h["needs"].get(need, false):
			return false
	if T.has("beauty") and float(h["beauty"]) < float(T["beauty"]):
		return false
	return true


# ---------- день ----------

func sim_day() -> void:
	day += 1
	compute()
	var cap := storage_cap()
	var upkeep := 0.0
	for id in buildings:
		var b: Dictionary = buildings[id]
		var d := def(b)
		upkeep += float(d.get("upkeep", 0.0))
		if not d.has("produces"):
			continue
		var k := float(b["staff"]) if b["active"] else 0.0
		if d.has("consumes"):
			for g in d["consumes"]:
				k = minf(k, float(goods[g]) / float(d["consumes"][g]))
		for g in d["produces"]:
			k = minf(k, maxf(0.0, cap - float(goods[g])) / float(d["produces"][g]))
		k = maxf(0.0, k)
		if d.has("consumes"):
			for g in d["consumes"]:
				goods[g] = float(goods[g]) - float(d["consumes"][g]) * k
		for g in d["produces"]:
			goods[g] = float(goods[g]) + float(d["produces"][g]) * k
		b["working"] = k > 0.01
	var taxes := 0.0
	var short := {}
	for id in buildings:
		var h: Dictionary = buildings[id]
		if def(h)["kind"] != "house":
			continue
		var T: Dictionary = Defs.tiers(h["type"])[h["tier"]]
		if h["needs"].get("market", false) and int(h["pop"]) > 0:
			var need := int(h["pop"]) * float(Defs.CONSUMPTION["food"])
			var total := float(goods["wheat"]) + float(goods["fish"])
			if total > 0:
				var take := minf(need, total)
				var fw := float(goods["wheat"]) / total
				goods["wheat"] = float(goods["wheat"]) - take * fw
				goods["fish"] = float(goods["fish"]) - take * (1.0 - fw)
				if take < need:
					short["food"] = true
			else:
				short["food"] = true
			for g in ["oil", "bread", "wine"]:
				if not g in T["needs"]:
					continue
				var want := int(h["pop"]) * float(Defs.CONSUMPTION[g])
				var take := minf(want, float(goods[g]))
				goods[g] = float(goods[g]) - take
				if take < want:
					short[g] = true
		taxes += int(h["pop"]) * float(T["tax"]) * (0.7 + float(h["happy"]) / 200.0)
	for g in goods:
		goods[g] = clampf(float(goods[g]), 0.0, cap)
	# купцы покупают излишки со склада (без торгового поста — за ¾ цены)
	var trade := 0.0
	if _count("warehouse") > 0:
		for g in Defs.SELL:
			var extra := float(goods[g]) - Defs.TRADE_RESERVE
			if extra > 1.0:
				trade += extra * float(Defs.GOODS[g]["price"]) * 0.75
				goods[g] = Defs.TRADE_RESERVE
	var net := taxes + trade - upkeep
	var before := money
	money = minf(money + net, maxf(treasury_cap(), money)) if net > 0 else money + net
	stats["lost"] = net - (money - before)
	stats["taxes"] = taxes
	stats["upkeep"] = upkeep
	stats["trade"] = trade
	stats["income"] = net
	stats["short"] = short
	# рост и упадок домов
	for id in buildings.keys():
		var h: Dictionary = buildings[id]
		if def(h)["kind"] != "house":
			continue
		var tiers := Defs.tiers(h["type"])
		var target: int = h.get("target", 0)
		if target > int(h["tier"]):
			h["up"] = int(h["up"]) + 1
			h["down"] = 0
			if int(h["up"]) >= (2 if int(h["tier"]) == 0 else 3):
				h["tier"] = int(h["tier"]) + 1
				h["up"] = 0
				house_changed.emit(h, true)
		elif target < int(h["tier"]) and int(h["tier"]) > 1:
			h["down"] = int(h["down"]) + 1
			h["up"] = 0
			if int(h["down"]) >= 12:
				h["tier"] = int(h["tier"]) - 1
				h["down"] = 0
				house_changed.emit(h, false)
		else:
			h["up"] = 0
			h["down"] = 0
		var capp: int = tiers[h["tier"]]["cap"]
		if int(h["pop"]) > capp:
			h["pop"] = maxi(capp, int(h["pop"]) - 2)
	_request_settlers()
	_update_rank()
	compute()
	_check_goals()
	changed.emit()


func _count(type: String) -> int:
	var n := 0
	for id in buildings:
		if buildings[id]["type"] == type:
			n += 1
	return n


## Дома с местами зовут переселенцев (если до них есть дорога от центра)
func _request_settlers() -> void:
	var waiting := {}
	for q in settle_queue:
		waiting[q[0]] = int(waiting.get(q[0], 0)) + int(q[1])
	for id in buildings:
		var h: Dictionary = buildings[id]
		if def(h)["kind"] != "house" or int(h["tier"]) == 0 or not h["road"]:
			continue
		var capp: int = Defs.tiers(h["type"])[h["tier"]]["cap"]
		var free: int = capp - int(h["pop"]) - int(waiting.get(id, 0)) - int(h.get("coming", 0))
		if free > 0:
			settle_queue.append([id, mini(free, 4)])


func settled(id: int, n: int) -> void:
	if not buildings.has(id):
		return
	var h: Dictionary = buildings[id]
	var capp: int = Defs.tiers(h["type"])[h["tier"]]["cap"]
	h["pop"] = mini(capp, int(h["pop"]) + n)
	compute()
	changed.emit()


func _update_rank() -> void:
	rank = Defs.rank_of(int(stats["pop"]))
	if rank > max_rank:
		max_rank = rank
		var c := center()
		if not c.is_empty():
			c["tier"] = mini(max_rank, Defs.CENTER_STAGES.size() - 1)
			house_changed.emit(c, true)
		message.emit("Город теперь — «%s»! Казна вмещает %d денариев, открылись новые постройки." % [Defs.RANKS[max_rank][1], int(treasury_cap())], "rank")


# ---------- участки ----------

func plot_price() -> int:
	return int(Defs.PLOT_PRICE[mini(plots_bought + 1, Defs.PLOT_PRICE.size() - 1)])


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
	plots_bought += 1
	land.owned[p] = true
	for j in range(p.y * 64, p.y * 64 + 64):
		for i in range(p.x * 64, p.x * 64 + 64):
			land._mark(i, j)
	_check_goals()
	changed.emit()
	return true


# ---------- задания ----------

func goal_progress(id: String) -> int:
	match id:
		"houses3":
			var n := 0
			for i in buildings:
				if buildings[i]["type"] == "house" and buildings[i]["road"]:
					n += 1
			return n
		"well": return _count("well") + _count("fountain")
		"farm_market": return mini(1, _count("farm")) + mini(1, _count("market"))
		"domik3": return _houses_at("house", 2)
		"temple": return _count("temple")
		"oil": return mini(1, _count("grove")) + mini(1, _count("oilpress"))
		"insula": return _houses_at("house", 3)
		"pop100", "pop400": return int(stats["pop"])
		"plot": return plots_bought
		"warehouse": return mini(1, _count("lumber")) + mini(1, _count("quarry")) + mini(1, _count("warehouse"))
		"baths": return _count("baths")
		"big_insula": return _houses_at("house", 4)
		"domus": return _houses_at("domus", 1)
	return 0


func _houses_at(type: String, tier: int) -> int:
	var n := 0
	for i in buildings:
		if buildings[i]["type"] == type and int(buildings[i]["tier"]) >= tier:
			n += 1
	return n


func active_goals(n := 3) -> Array:
	var out := []
	for g in Defs.GOALS:
		if not g["id"] in goals_done:
			out.append(g)
			if out.size() >= n:
				break
	return out


func _check_goals() -> void:
	for g in active_goals():
		if goal_progress(g["id"]) >= int(g["need"]):
			goals_done.append(g["id"])
			money += float(g["reward"])
			message.emit("Задание выполнено: %s. Награда — %d денариев." % [g["text"], g["reward"]], "goal")


# ---------- сохранение ----------

func save_data() -> Dictionary:
	var bl := []
	for id in buildings:
		var b: Dictionary = buildings[id]
		bl.append({"type": b["type"], "tier": b["tier"], "x": b["pos"].x, "z": b["pos"].y, "yaw": b["yaw"], "seed": b["seed"], "pop": b["pop"], "y": b["y"]})
	return {"money": money, "day": day, "goods": goods, "buildings": bl, "max_rank": max_rank, "goals": goals_done, "plots_bought": plots_bought, "tips": tips_seen}
