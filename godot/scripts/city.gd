class_name City
extends RefCounted
## Жизнь города — как в Town to City: три класса жителей, лавки по видам потребностей обслуживают
## ближайшие дома в своей дальности (сколько потянут рабочие), памятники и украшения радуют всех вокруг,
## теснота огорчает. Этаж полному счастливому дому покупает игрок (buy_floor); новые семьи едут, пока
## город счастлив (arrivals_blocked).
## Деньги — налоги с домов; очки исследований — почта на станции, скрипторий, школа, библиотека. Уровень города растёт
## от числа жителей и их счастья.

signal changed                       # что-то поменялось — перерисовать интерфейс
signal building_added(b)
signal building_removed(b)
signal house_changed(b, up)
signal event(text, icon)             # событие для колокольчика и всплывашки справа
signal family_left(home, name)       # семья уехала из дома (жители уходят по большой дороге)
signal arrivals_changed              # на площади у станции стало больше или меньше семей
signal family_came(f)                # повозка привезла семью
signal family_assigned(name, home)   # игрок выбрал семье дом — жители идут туда
signal arrive_advice(text)           # повозка впервые встала из-за низкого счастья — объясняет советник
signal level_up(lvl)                 # город перешёл на новый уровень — ролик «Новый ранг» (rank_cine.gd)

var land: Land
var money := float(Defs.START_MONEY)
var rp := 0.0
var day := 0
var level := 0
var research := {}                    # id → true
var buildings := {}                   # id → запись постройки
var next_id := 1
## happy_parts — счастье города по слагаемым [[подпись, %], …]; happy_tips — 1–3 подсказки, что поднимет счастье;
## arrive_block — почему не едут новые семьи ("" — едут)
var stats := {"pop": 0, "happy": 0, "income": 0.0, "upkeep": 0.0, "rp_day": 0.0, "residents": {}, "workers": {}, "jobs": {}, "free": {}, "class_happy": {},
	"happy_parts": [], "happy_tips": [], "arrive_block": ""}
var goods := {}                       # сырьё, которое есть в городе: wheat, olives, grapes
## Приезд семей — как поезд в Town to City: повозка привозит семью, она ждёт на площади у станции,
## пока игрок не выберет ей дом. Ждать могут не больше ARRIVAL_MAX семей — тогда новые не едут.
var arrivals: Array = []              # семьи на площади: [{name, n, cls}]
var pending := {}                     # семьи, которым выбран дом, идут туда: имя → {name, n, cls, home}
var incoming := 0                     # сколько семей едет в повозке
var arrive_t := 0.0                   # часов с прошлой повозки
var arrive_block_h := 0               # сколько часов повозка не везёт семьи из-за низкого счастья
var arrive_block_said := -999         # в какой час советник последний раз объяснил, почему семьи не едут
var arrive_block_told := false        # советник сказал «не едут» — когда поедут, скажет «снова едут»
var hour_n := 0                       # игровых часов с начала (с загрузки)
var settled_total := 0                # сколько семей заселено за игру
var moving_id := -1                   # постройку переносят — жильцы не уходят из неё
var tips := {}                        # какие советы и шаги обучения уже показаны
signal rehomed(old, new)              # перенесённый дом получил новый номер
var waiting: int:
	get:
		return arrivals.size()
var goals_done: Array = []
var events: Array = []                # [{day, text, icon}]
var road_cells := 0                   # сколько клеток дорог проложил игрок
var rng := RandomNumberGenerator.new()
var bulk := false                     # place() без пересчёта (витрина Showcase ставит сотни построек, compute — в конце)
var legion := Legion.new()            # армия: походы, Слава, чудеса (legion.gd); сохраняется под ключом "legion"


func _init(l: Land) -> void:
	land = l
	rng.seed = 5
	legion.bind(self)


func def(b: Dictionary) -> Dictionary:
	return Defs.B[b["type"]]


func is_house(b: Dictionary) -> bool:
	return def(b)["kind"] == "house"


func unlocked(type: String) -> bool:
	var u: String = Defs.B[type].get("unlock", "")
	if u.begins_with("boss"):                 # военные постройки: победа Легиона над N-м боссом
		return legion.bosses() >= int(u.substr(4))
	return u == "" or research.has(u) or legion.wonder_unlocks(type)   # чудеса открывает и рейтинг походов


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
	# сначала — украшения на стенах (у них нет клеток на земле)
	for id in buildings:
		var b: Dictionary = buildings[id]
		if b.has("host") and (b["pos"] as Vector2).distance_to(p) < 0.7:
			return b
	var id := land.occ_at(p)
	return buildings.get(id, {})


func money_cap() -> float:
	return money_cap_for(level)


## Сколько вмещает казна на уровне lvl (с уже изученными хранилищами)
func money_cap_for(lvl: int) -> float:
	var c := float(Defs.LEVELS[clampi(lvl, 0, Defs.LEVELS.size() - 1)]["money"])
	if research.has("vault1"):
		c *= 2.0
	if research.has("vault2"):
		c *= 2.0
	return c


func rp_cap() -> float:
	return rp_cap_for(level)


## Предел очков исследований на уровне lvl (с уже изученным «research1»)
func rp_cap_for(lvl: int) -> float:
	return float(Defs.LEVELS[clampi(lvl, 0, Defs.LEVELS.size() - 1)]["rp"]) * (2.0 if research.has("research1") else 1.0)


func house_cap(b: Dictionary) -> int:
	var cls: String = def(b)["cls"]
	return int(Defs.CLASSES[cls]["per_floor"]) * int(b["tier"])


# ---------- стройка ----------

## Можно ли поставить; возвращает {"err": текст или "", "cells": клетки, "y": высота}
func check_place(type: String, pos: Vector2, yaw: float, variant := 0, color := 0, ignore_id := -1) -> Dictionary:
	var d: Dictionary = Defs.B[type]
	var res := {"err": "", "cells": PackedInt32Array(), "y": 0.0}
	if not unlocked(type):
		res["err"] = "Откроется %s" % Defs.unlock_text(d["unlock"])
		return res
	if money < float(d["cost"]) and ignore_id == -1:
		res["err"] = "Не хватает денариев"
		return res
	if ignore_id == -1 and legion.glory + 0.001 < float(d.get("glory", 0)):
		res["err"] = "Не хватает Славы: нужно %d (Слава — за победы Легиона)" % int(d["glory"])
		return res
	if ignore_id == -1 and d.get("unique", false) and _count(func(o): return o["type"] == type) > 0:
		res["err"] = "Такая постройка в городе уже есть"
		return res
	if ignore_id == -1 and cap_err(type) != "":   # предел уровня города (перенос и готовый город — без него)
		res["err"] = cap_err(type)
		return res
	if d.get("wall", false):
		return res                            # украшение на стене: место выбирает игра (стена дома)
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
		# отрицательная занятость — неподвижное (арка у въезда): занято всегда, при любом ignore_id
		# (ignore_id −1/−2/−3 — это режимы проверки, а не номер постройки)
		if o < 0 or (o != 0 and o != ignore_id):
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
		legion.glory = maxf(0.0, legion.glory - float(d.get("glory", 0)))   # чудеса Легиона стоят ещё и Славы
	var cells: PackedInt32Array = b["cells"]
	if not d.get("water", false):
		land.flatten_cells(cells, b["y"], Land.Kind.FIELD if d["kind"] == "farm" else -1)
		if d["kind"] != "decor":
			land.blend_ring(cells, b["y"], 8)
	for k in cells:
		if land.occ[k] >= 0:                   # арку у въезда (занятость < 0) не затираем даже готовым городом
			land.occ[k] = b["id"]
	buildings[b["id"]] = b
	if bulk:                                    # готовый город раскладывается разом — пересчёт один раз в конце
		building_added.emit(b)
		return b
	compute()
	building_added.emit(b)
	_check_goals()
	changed.emit()
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
	for k in (b["cells"] as PackedInt32Array):
		if land.occ[k] == int(b["id"]):        # чужое (арку у въезда, соседа) не освобождаем
			land.occ[k] = 0
	buildings.erase(b["id"])
	# украшения на стенах снесённого дома падают вместе с ним
	for oid in buildings.keys():
		if buildings.has(oid) and int(buildings[oid].get("host", -1)) == int(b["id"]):
			remove(buildings[oid], refund)
	# семьи, которые шли в этот дом, возвращаются на площадь
	for nm in pending.keys():
		if int(pending[nm]["home"]) == int(b["id"]) and int(b["id"]) != moving_id:
			var f: Dictionary = pending[nm]
			pending.erase(nm)
			arrivals.append({"name": f["name"], "n": f["n"], "cls": f["cls"], "back": bool(f.get("back", false))})
	compute()
	building_removed.emit(b)
	arrivals_changed.emit()
	changed.emit()


## Перенесённый дом: те, кто шёл в старый, идут в новый
func rehome(old: int, new: int) -> void:
	if not buildings.has(new):
		return
	var b: Dictionary = buildings[new]
	for nm in pending:
		if int(pending[nm]["home"]) == old:
			pending[nm]["home"] = new
			b["coming"] = int(b.get("coming", 0)) + int(pending[nm]["n"])
	rehomed.emit(old, new)


## Сменить цвет дома (щелчок по значку в карточке)
func recolor(b: Dictionary) -> void:
	b["color"] = (int(b["color"]) + 1) % Defs.PALETTE.size()
	house_changed.emit(b, false)
	changed.emit()


# ---------- работники (как в Town to City: сколько нанять — решает игрок) ----------

const WAGE := 0.3                     # денариев в час за каждого нанятого работника


## Сколько построек этого вида можно держать на нынешнем уровне города (−1 — сколько угодно)
func build_max(type: String) -> int:
	var mx: Array = Defs.B[type].get("max", [])
	if mx.is_empty():
		return -1
	return int(mx[clampi(level, 0, mx.size() - 1)])


func count_type(type: String) -> int:
	return _count(func(o): return o["type"] == type)


## Почему ещё одну такую постройку не поставить из-за предела уровня ("" — можно).
## Лишние, поставленные раньше, остаются и работают
func cap_err(type: String) -> String:
	var mx := build_max(type)
	if mx < 0 or count_type(type) < mx:
		return ""
	var d: Dictionary = Defs.B[type]
	var many := String(d.get("gen", String(d["name"]).to_lower()))
	if level >= Defs.LEVELS.size() - 1:
		return "Больше %s не поставить — это предел" % many
	return "%s на уровне «%s» — не больше %d. Ещё один — на уровне «%s»" % [many.left(1).to_upper() + many.substr(1), Defs.LEVELS[level]["name"], mx, Defs.LEVELS[level + 1]["name"]]


## Очков исследований в час от полностью занятой постройки — с изученными прибавками (ученики писцов…)
func rp_per_hour(type: String) -> float:
	var d: Dictionary = Defs.B[type]
	var rate := float(d.get("rp", 0))
	var out := rate
	var up: Dictionary = d.get("rp_up", {})
	for r in up:
		if research.has(r):
			out += rate * float(up[r])
	return out


func job_max(b: Dictionary) -> int:
	var n := 0
	for c in def(b).get("jobs", {}):
		n += int(def(b)["jobs"][c])
	return n


## Рабочие места постройки с учётом найма: сначала младшие классы
func jobs_of(b: Dictionary) -> Dictionary:
	var d := def(b)
	if not d.has("jobs"):
		return {}
	var h := int(b.get("hire", -1))
	if h < 0 or h >= job_max(b):
		return (d["jobs"] as Dictionary).duplicate()
	var out := {}
	var left := h
	for c in Defs.CLASS_ORDER:
		if d["jobs"].has(c):
			var n := mini(int(d["jobs"][c]), left)
			out[c] = n
			left -= n
	return out


func hired_of(b: Dictionary) -> int:
	var n := 0
	var jb := jobs_of(b)
	for c in jb:
		n += int(jb[c])
	return n


func set_hire(b: Dictionary, n: int) -> void:
	b["hire"] = clampi(n, 0, job_max(b))
	compute()
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
			var jb := jobs_of(b)
			for c in jb:
				jobs[c] += int(jb[c])
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
			var jb := jobs_of(b)
			var hired := 0
			for c in jb:
				hired += int(jb[c])
				if int(jb[c]) > 0:
					st = minf(st, ratio[c])
			b["fill"] = st if b["road"] else 0.0               # хватает ли жителей на нанятые места
			st *= float(hired) / float(maxi(1, job_max(b)))     # наняли меньше — работает слабее
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
				# сначала — дома, где живут (или куда уже идёт семья), потом пустые; среди них — ближние
				var lived := int(h["pop"]) + int(h.get("coming", 0)) > 0
				near.append([dd + (0.0 if lived else 10000.0), h])
		near.sort_custom(func(a, b): return a[0] < b[0])
		var served := 0
		var serves := []
		for e in near:
			if served >= cap:
				break
			var h: Dictionary = e[1]
			serves.append(h["id"])
			var sc: Dictionary = h["score"]
			if int(sc.get(s["type"], 0)) < int(d["bonus"]):
				sc[s["type"]] = int(d["bonus"])
			h["needs"][d["sub"]] = true
			served += 1
		s["served"] = served
		s["serves"] = serves           # какие дома обслуживает (для подсветки охвата)
		s["cap"] = cap                 # сколько домов может обслужить сейчас (с нынешними работниками)
		s["near_n"] = near.size()      # сколько домов в её дальности
	# Счастье дома — сумма слагаемых, как в Town to City (их список — b["happy_parts"], для карточки дома):
	#   основа класса: плебеи 44, ремесленники 41, патриции 38 (Defs.CLASSES base)
	#   + бонус каждой РАЗНОЙ лавки, что обслуживает дом (две фруктовые лавки — один бонус), любые виды
	#   + украшения в радиусе DECOR_RADIUS: +1% за каждые 2 очка украшения, не больше deco_max класса (12/14/16)
	#   + памятники в своей дальности (каждый вид памятника — один раз)
	#   − теснота: −2% за каждого соседа сверх DENSITY_FREE в радиусе DENSITY_RADIUS (не больше −16%)
	#   − 10% за каждый нужный классу вид лавки (еда, одежда…), которой нет рядом
	# Для плебеев: только фруктовая лавка — 49%, с парой фонарей — 52–55%; приезд новых семей (60%) —
	# две лавки еды и украшения; 65% (второй этаж) — три разные лавки и украшения; 75% (третий) — ещё мясо, хлеб, фонтан.
	var happy_sum := 0.0
	var pop := 0
	var sums := {"base": 0.0, "shops": 0.0, "deco": 0.0, "mon": 0.0, "crowd": 0.0, "miss": 0.0, "w": 0.0}
	for h in houses:
		var cls: String = def(h)["cls"]
		var cd: Dictionary = Defs.CLASSES[cls]
		var parts := []
		var base := int(cd.get("base", 40))
		parts.append(["Основа", base])
		var shop_sum := 0
		var types: Array = (h["score"] as Dictionary).keys()
		types.sort_custom(func(a, b): return _shop_rank(a) < _shop_rank(b))
		for t in types:
			parts.append([Defs.B[t]["name"], int(h["score"][t])])
			shop_sum += int(h["score"][t])
		var deco := 0.0
		for o in decor:
			if (h["pos"] as Vector2).distance_to(o["pos"]) <= Defs.DECOR_RADIUS:
				deco += float(def(o).get("deco", 1))
		var deco_b := mini(int(cd.get("deco_max", 12)), int(floor(deco * Defs.DECO_RATE)))
		parts.append(["Украшения", deco_b])
		var mon := {}                   # вид памятника → бонус (одинаковые не складываются)
		for m in monuments:
			var md := def(m)
			if (h["pos"] as Vector2).distance_to(m["pos"]) <= Defs.range_m(md):
				mon[m["type"]] = maxi(int(mon.get(m["type"], 0)), int(md["bonus"]))
		var mon_sum := 0
		for t in mon:
			parts.append([Defs.B[t]["name"], int(mon[t])])
			mon_sum += int(mon[t])
		var lg := legion.city_happy()          # чудеса Легиона без постройки и триумф — всем домам
		if lg > 0:
			parts.append(["Легион: чудеса и триумф", lg])
			mon_sum += lg
		var crowd := 0
		for o in houses:
			if o != h and (h["pos"] as Vector2).distance_to(o["pos"]) <= Defs.DENSITY_RADIUS:
				crowd += 1
		var dens := -mini(Defs.DENSITY_MAX, maxi(0, crowd - Defs.DENSITY_FREE) * Defs.DENSITY_STEP)
		if dens < 0:
			parts.append(["Теснота", dens])
		var missing := []
		for n in cd["needs"]:
			if not h["needs"].has(n):
				missing.append(n)
				parts.append(["Нет лавки: " + String(Defs.NEEDS[n]["name"]).to_lower(), -Defs.MISSING_PENALTY])
		var hp := base + shop_sum + deco_b + mon_sum + dens - missing.size() * Defs.MISSING_PENALTY
		h["deco"] = deco
		h["deco_bonus"] = deco_b
		h["monuments"] = float(mon_sum)
		h["mon_types"] = mon
		h["density"] = dens
		h["missing"] = missing
		h["happy_parts"] = parts
		h["happy"] = clampi(hp, 0, 200)
		happy_sum += clampf(hp, 0.0, 100.0) * int(h["pop"])
		pop += int(h["pop"])
		var w := float(int(h["pop"]))
		sums["w"] += w
		sums["base"] += base * w
		sums["shops"] += shop_sum * w
		sums["deco"] += deco_b * w
		sums["mon"] += mon_sum * w
		sums["crowd"] += dens * w
		sums["miss"] += -missing.size() * Defs.MISSING_PENALTY * w
		sums["clip"] = float(sums.get("clip", 0.0)) + (clampf(hp, 0.0, 100.0) - hp) * w   # счастье дома — от 0 до 100%
	# счастье города — среднее по жителям, округлённое; его слагаемые округляем так, чтобы в сумме вышло
	# ровно оно (заголовок подсказки «Счастье города: N%» и строки под ним всегда сходятся)
	var city_happy := roundi(happy_sum / pop) if pop > 0 else 0
	var cp := []
	if float(sums["w"]) > 0.0:
		var wt: float = sums["w"]
		var rows := [["Основа", "base", true], ["Лавки", "shops", true], ["Украшения", "deco", true], ["Памятники", "mon", false],
				["Теснота", "crowd", false], ["Нет нужных лавок", "miss", false], ["", "clip", false]]
		var fv := []
		var vi := []
		var acc := 0
		for e: Array in rows:
			var f := float(sums.get(e[1], 0.0)) / wt
			fv.append(f)
			vi.append(int(floor(f)))
			acc += int(floor(f))
		var order := range(rows.size())
		order.sort_custom(func(a, b): return fv[a] - floor(fv[a]) > fv[b] - floor(fv[b]))
		var left := city_happy - acc           # остаток — тем, у кого дробная часть больше
		for i in order:
			if left <= 0:
				break
			vi[i] += 1
			left -= 1
		for i in rows.size():
			var v: int = vi[i]
			if v == 0 and not rows[i][2]:
				continue
			var nm: String = rows[i][0]
			if rows[i][1] == "clip":
				nm = "Больше 100% не бывает" if v < 0 else "Меньше 0% не бывает"
			cp.append([nm, v])
	stats["happy_parts"] = cp
	stats["pop"] = pop
	stats["residents"] = residents
	stats["workers"] = workers
	stats["jobs"] = jobs
	stats["free"] = spare
	stats["ratio"] = ratio
	stats["filled"] = filled
	stats["happy"] = city_happy
	# счастье класса — как и счастье города, по жителям (пустые дома не тянут вниз); если в домах класса
	# ещё никто не живёт — просто среднее по его домам (что их ждёт)
	var per_class := {}
	for c in Defs.CLASS_ORDER:
		var hs := 0.0
		var n := 0
		var hs0 := 0.0
		var n0 := 0
		for h in houses:
			if def(h)["cls"] == c:
				var hv := clampf(float(h["happy"]), 0.0, 100.0)
				hs += hv * int(h["pop"])
				n += int(h["pop"])
				hs0 += hv
				n0 += 1
		per_class[c] = roundi(hs / n) if n > 0 else (roundi(hs0 / n0) if n0 > 0 else 0)
	stats["class_happy"] = per_class
	stats["happy_tips"] = _happy_tips(houses, stores)
	stats["arrive_block"] = arrivals_blocked()


## Порядок лавок в списке слагаемых: по виду потребности (еда, одежда…), внутри — по бонусу
func _shop_rank(t: String) -> int:
	var d: Dictionary = Defs.B[t]
	return Defs.NEED_ORDER.find(d.get("sub", "")) * 100 - int(d.get("bonus", 0))


static func plural(n: int, one: String, few: String, many: String) -> String:
	var m := n % 100
	if m >= 11 and m <= 14:
		return many
	match n % 10:
		1: return one
		2, 3, 4: return few
	return many


## 1–3 короткие подсказки, что сильнее всего поднимет счастье города (для советника и окна счастья).
## Польза каждой — сколько процентов прибавит в среднем на жителя; берём самые полезные.
func _happy_tips(houses: Array, stores: Array) -> Array:
	if houses.is_empty():
		return []
	var ws := {}
	var tot := 0.0
	for h in houses:
		ws[h["id"]] = float(int(h["pop"]))
		tot += float(int(h["pop"]))
	var nobody := tot <= 0.0             # в городе ещё никто не живёт (первая семья не заселена)
	if nobody:
		for h in houses:
			ws[h["id"]] = 1.0
		tot = float(houses.size())
	var cands := []                     # [польза, текст]
	# нужные виды лавок, которых нет рядом с домами
	for n in Defs.NEED_ORDER:
		var w := 0.0
		var cnt := 0
		for h in houses:
			if n in h["missing"] and float(ws[h["id"]]) > 0.0:     # только дома, где живут
				w += float(ws[h["id"]])
				cnt += 1
		if cnt == 0:
			continue
		var open := false
		for t in Defs.B:
			if Defs.B[t]["kind"] == "shop" and Defs.B[t].get("sub", "") == n and unlocked(t):
				open = true
				break
		var nm: String = Defs.NEEDS[n]["name"]
		var g_need := Defs.MISSING_PENALTY * w / tot + 4.0
		# лавка этого вида уже стоит рядом, но не работает или не успевает ко всем — сказать почему
		# (а не «поставьте ещё одну»: при нехватке работников новая лавка сделает только хуже)
		var iss := _need_shop_issue(n, houses, ws)
		if not iss.is_empty():
			var sb: Dictionary = iss["b"]
			var sn: String = def(sb)["name"]
			var k := int(iss["cnt"])
			if iss["idle"]:
				var g := g_need
				if nobody and String(sb.get("why", "")) == "staff":
					g = 1.0                     # пустой город: заработает сама с первыми жителями
				cands.append([g, "«%s» рядом с %d %s не работает: %s" % [sn, k, plural(k, "домом", "домами", "домами"), idle_text(sb)]])
			elif float(sb.get("fill", 1.0)) < 0.99:
				pass                            # не успевает из-за нехватки работников — об этом совет про работников ниже
			elif hired_of(sb) < job_max(sb):
				cands.append([g_need, "«%s» не успевает ко всем домам рядом — наймите работника кнопкой «+» в карточке постройки" % sn])
			else:
				cands.append([g_need, "«%s» не успевает ко всем домам рядом — поставьте ещё одну лавку «%s» (+%d%%)" % [sn, nm, Defs.MISSING_PENALTY]])
		elif open:
			cands.append([g_need, "У %d %s нет рядом лавки «%s» — поставьте её поближе (+%d%%)" % [cnt, plural(cnt, "дома", "домов", "домов"), nm, Defs.MISSING_PENALTY]])
		else:
			cands.append([Defs.MISSING_PENALTY * w / tot + 2.0, "Изучите лавку вида «%s» — её не хватает %d %s" % [nm, cnt, plural(cnt, "дому", "домам", "домам")]])
	# новая лавка, которой у домов ещё нет (разнообразие)
	var best := [0.0, ""]
	for t in Defs.B:
		var d: Dictionary = Defs.B[t]
		if d["kind"] != "shop" or not unlocked(t):
			continue
		if d.get("store", false) and stores.is_empty():
			continue
		if d.has("needs_good") and not goods.has(d["needs_good"]):
			continue
		if not _staffable(d) or _workers_short(d):
			continue                            # работать в ней некому (или и так не хватает) — стояла бы пустой
		if nobody:
			continue                            # пока никто не живёт, разнообразие не к спеху
		var w := 0.0
		for h in houses:
			if not (h["score"] as Dictionary).has(t):
				w += float(ws[h["id"]])
		var g := float(d["bonus"]) * w / tot
		if g > float(best[0]):
			best = [g, "Новая лавка у домов: «%s» — +%d%% каждому дому рядом" % [d["name"], int(d["bonus"])]]
	if float(best[0]) >= 1.0:
		cands.append(best)
	# исследование новой лавки (если готовые уже стоят)
	var rb := [0.0, ""]
	for r in Defs.RESEARCH:
		if research.has(r["id"]) or int(r["lvl"]) > level or (r.has("after") and not research.has(r["after"])):
			continue
		for t in Defs.B:
			var d: Dictionary = Defs.B[t]
			if d["kind"] == "shop" and d.get("unlock", "") == r["id"] and _staffable(d):
				var g := float(d["bonus"]) * 0.4 - float(r["cost"]) * 0.001
				if g > float(rb[0]):
					rb = [g, "Изучите «%s» — новая лавка даст домам ещё +%d%%" % [r["name"], int(d["bonus"])]]
	if float(rb[0]) > 0.0:
		cands.append(rb)
	# украшения
	var dw := 0.0
	for h in houses:
		dw += float(int(Defs.CLASSES[def(h)["cls"]].get("deco_max", 12)) - int(h["deco_bonus"])) * float(ws[h["id"]])
	dw /= tot
	if dw >= 2.0:
		cands.append([dw * 0.9, "Украшения между домами: можно добавить ещё до +%d%%" % int(roundf(dw))])
	# памятники (фонтан, храм…)
	var mb := [0.0, ""]
	for t in Defs.B:
		var d: Dictionary = Defs.B[t]
		if d["kind"] != "monument" or not unlocked(t) or not _staffable(d) or _workers_short(d):
			continue
		var w := 0.0
		for h in houses:
			if not (h.get("mon_types", {}) as Dictionary).has(t):
				w += float(ws[h["id"]])
		var g := float(d["bonus"]) * w / tot * 0.7
		if g > float(mb[0]):
			mb = [g, "«%s» среди домов: +%d%% всем вокруг" % [d["name"], int(d["bonus"])]]
	if float(mb[0]) >= 1.0:
		cands.append(mb)
	# теснота
	var cw := 0.0
	for h in houses:
		cw += float(h["density"]) * float(ws[h["id"]])
	cw /= tot
	if cw <= -2.0:
		cands.append([-cw, "Дома стоят слишком тесно (%d%%) — оставляйте между ними место" % int(roundf(cw))])
	# работники: лавка уже стоит у домов, но людей на её местах не хватает — и она обслуживает меньше домов,
	# чем могла бы. Польза — счастье, которое эти дома недополучают (а не просто «мест больше, чем людей»)
	if not nobody:
		var lost := 0.0
		var worst := {}
		var worst_g := 0.0
		for id in buildings:
			var s: Dictionary = buildings[id]
			var d := def(s)
			if d["kind"] != "shop" or not s.get("active", false) or float(s.get("fill", 1.0)) >= 0.99:
				continue
			var full := int(Defs.CAPACITY[int(d["cap"])])
			var extra := full - int(s.get("cap", full))
			if extra <= 0 or int(s.get("served", 0)) < int(s.get("cap", 0)):
				continue                        # и с нынешними работниками успевает ко всем
			var r := shop_range(d)
			var near := []
			for h in houses:
				var dd := (h["pos"] as Vector2).distance_to(s["pos"])
				if dd <= r and float(ws[h["id"]]) > 0.0 and int((h["score"] as Dictionary).get(s["type"], 0)) < int(d["bonus"]):
					near.append([dd, h])
			near.sort_custom(func(a, b): return a[0] < b[0])
			var g := 0.0
			for k in mini(extra, near.size()):
				g += float(d["bonus"]) * float(ws[(near[k][1] as Dictionary)["id"]]) / tot
			lost += g
			if g > worst_g:
				worst_g = g
				worst = s
		if lost >= 1.0 and not worst.is_empty():
			# место можно забрать без вреда счастью у скриптория или школы (они дают только очки исследований)
			var cls_need := ""
			for c in def(worst).get("jobs", {}):
				cls_need = c
			var spare_at := ""
			for id in buildings:
				var o: Dictionary = buildings[id]
				if def(o)["kind"] == "rp" and int(jobs_of(o).get(cls_need, 0)) > 0:
					spare_at = def(o)["name"]
					break
			var txt := "Не хватает работников: «%s» обслуживает меньше домов, чем может. Заселите ещё семьи" % def(worst)["name"]
			if spare_at != "":
				txt += " — или уберите одно место у «%s» кнопкой «−» в карточке постройки" % spare_at
			cands.append([lost, txt])
	cands.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
	var out := []
	for c in cands:
		if float(c[0]) >= 1.0 and out.size() < 3:
			out.append(c[1])
	return out


## Дальность лавки (еда — дальше после исследования «reach1»), как в compute()
func shop_range(d: Dictionary) -> float:
	var r := Defs.range_m(d)
	if d.get("sub", "") == "food" and research.has("reach1"):
		r *= 1.33
	return r


## Есть ли кому работать в постройке: на каждое её место нужен житель этого класса или выше
## (высшие подменяют низших, не наоборот). Пустой город — первыми приедут плебеи
func _staffable(d: Dictionary) -> bool:
	var res: Dictionary = stats.get("residents", {})
	var total := 0
	for c in res:
		total += int(res[c])
	var jb: Dictionary = d.get("jobs", {})
	for c in jb:
		if int(jb[c]) <= 0:
			continue
		var i := Defs.CLASS_ORDER.find(c)
		var have := 0
		for k in range(maxi(0, i), Defs.CLASS_ORDER.size()):
			have += int(res.get(Defs.CLASS_ORDER[k], 0))
		if have == 0 and not (total == 0 and i == 0):
			return false
	return true


## На места этой постройки уже сейчас не хватает людей (в её классе работников меньше, чем мест):
## новая такая постройка только растащит работников у тех, что стоят
func _workers_short(d: Dictionary) -> bool:
	var ratio: Dictionary = stats.get("ratio", {})
	for c in d.get("jobs", {}):
		if int(d["jobs"][c]) > 0 and float(ratio.get(c, 1.0)) < 0.99:
			return true
	return false


## Лавка вида n стоит рядом с домами, где этой нужды нет: не работает или уже обслуживает всех, кого может.
## {b, cnt (сколько таких домов в её дальности), idle} или {} — тогда лавки рядом просто нет
func _need_shop_issue(n: String, houses: Array, ws: Dictionary) -> Dictionary:
	var best := {}
	var best_key := -1
	for id in buildings:
		var s: Dictionary = buildings[id]
		var d := def(s)
		if d["kind"] != "shop" or d.get("sub", "") != n:
			continue
		var idle := not bool(s.get("active", true))
		if not idle and int(s.get("served", 0)) < int(s.get("cap", 0)):
			continue                    # работает и силы ещё есть — эти дома просто вне её дальности
		var r := shop_range(d)
		var cnt := 0
		for h in houses:
			if n in h["missing"] and float(ws.get(h["id"], 0.0)) > 0.0 and (h["pos"] as Vector2).distance_to(s["pos"]) <= r:
				cnt += 1
		if cnt == 0:
			continue
		var key := cnt + (1000 if idle else 0)     # неработающая важнее переполненной
		if key > best_key:
			best_key = key
			best = {"b": s, "cnt": cnt, "idle": idle}
	return best


## Почему лавка не работает — коротко, со строчной буквы (для советов и карточки дома)
func idle_text(b: Dictionary) -> String:
	var d := def(b)
	match String(b.get("why", "")):
		"road":
			return "нет дороги у входа"
		"store":
			return "нет склада рядом — нечем торговать"
		"good":
			for t in Defs.B:
				if Defs.B[t].get("makes", "") == d.get("needs_good", "-"):
					return "нет сырья — нужно «%s»" % Defs.B[t]["name"]
			return "нет сырья"
		"staff":
			if int(stats.get("pop", 0)) <= 0:
				return "заработает, когда заселятся жители"
			if not _staffable(d):
				var who := []
				for c in d.get("jobs", {}):
					who.append(String(Defs.CLASSES[c]["name"]).to_lower())
				return "работать некому — нужны %s" % ", ".join(who)
			if float(b.get("fill", 1.0)) < 0.99:
				return "не хватает работников — нужно больше жителей"
			return "мало работников — наймите кнопкой «+» в карточке постройки"
	return "не работает"


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
				rpd += rp_per_hour(b["type"]) * float(b["staff"])
				upkeep += float(d["cost"]) * 0.0025 + WAGE * hired_of(b)     # писцам и учителям тоже платят
			"shop", "monument", "store", "farm", "military":
				upkeep += float(d["cost"]) * 0.0025 + WAGE * hired_of(b)
	if not center().is_empty():
		rpd += float(Defs.LEVELS[level].get("rp_h", 0.0))   # почта привозит на станцию свитки
	hour_n += 1
	money = minf(money_cap(), money + income - upkeep)
	rp = minf(rp_cap(), rp + rpd)
	stats["income"] = income
	stats["upkeep"] = upkeep
	stats["rp_day"] = rpd
	for ev: Array in legion.on_hour():           # Легион: таймеры улучшений (настоящие часы), Слава чудес, триумф
		_event(ev[0], ev[1])
	_tick_arrivals()
	_update_level()
	_check_goals()
	changed.emit()


## Час жизни дома. Сам дом больше не растёт: этаж покупает игрок (buy_floor), а несчастные семьи уезжают
func _grow_house(b: Dictionary) -> void:
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


# ---------- этажи: покупает игрок в карточке дома (как в Town to City) ----------

## Цена следующего этажа (0 — надстраивать некуда)
func floor_price(b: Dictionary) -> int:
	if b.is_empty() or not is_house(b):
		return 0
	var cls: String = def(b)["cls"]
	var nx := int(b["tier"]) + 1
	if nx > Defs.floors_max(cls):
		return 0
	return int((Defs.FLOOR_PRICE[cls] as Dictionary).get(nx, 0))


## С какого счастья дома можно надстроить следующий этаж
func floor_need(b: Dictionary) -> int:
	return int(Defs.FLOOR_HAPPY.get(int(b.get("tier", 1)) + 1, 100))


## "" — этаж можно купить; иначе — почему нельзя (для подсказки у кнопки)
func can_buy_floor(b: Dictionary) -> String:
	if b.is_empty() or not buildings.has(b.get("id", -1)) or not is_house(b):
		return "Этаж можно надстроить только жилому дому"
	var h: Dictionary = buildings[b["id"]]
	var nx := int(h["tier"]) + 1
	if nx > Defs.floors_max(def(h)["cls"]):
		return "Это последний этаж"
	var rid: String = Defs.FLOOR_RESEARCH.get(nx, "")
	if rid != "" and not research.has(rid):
		return "Сначала изучите «%s»" % Defs.research(rid)["name"]
	# «дом полон» — когда в него не влезет ни одна семья его класса (семьи по 2–4 человека, и одно
	# свободное место у плебеев так и осталось бы пустым навсегда)
	var left := house_cap(h) - int(h["pop"]) - int(h.get("coming", 0))
	if int(h["pop"]) <= 0:
		return "Дом пока пустой — сначала заселите в него семью"
	if int(h.get("coming", 0)) > 0:
		return "Семья ещё идёт в этот дом — подождите, пока она заселится"
	if left >= int(Defs.FAMILY_SIZE[String(def(h)["cls"])][0]):
		return "В доме есть место ещё для семьи (%d %s) — сначала заселите её" % [left, plural(left, "место", "места", "мест")]
	if int(h["happy"]) < floor_need(h):
		return "Счастье дома ниже %d%%" % floor_need(h)
	if money < float(floor_price(h)):
		return "Не хватает денариев"
	return ""


## Купить этаж: деньги списываются, дом растёт, в него может въехать ещё семья
func buy_floor(b: Dictionary) -> bool:
	if can_buy_floor(b) != "":
		return false
	var h: Dictionary = buildings[b["id"]]
	money -= float(floor_price(h))
	h["tier"] = int(h["tier"]) + 1
	compute()
	house_changed.emit(h, true)
	_event("Дому семьи %s надстроили %d-й этаж — место ещё для %d жителей" % [_fam_name(h), int(h["tier"]), int(Defs.CLASSES[def(h)["cls"]]["per_floor"])], "housing")
	_check_goals()
	changed.emit()
	return true


# ---------- приезд семей ----------

## Сколько семей уже приехало (заселены, ждут на площади, идут к дому, едут в повозке)
func families_came() -> int:
	# семьи «back» уже жили в городе (их дом снесли или в дом влезли не все) — они уже в settled_total
	var n := settled_total + incoming
	for f in arrivals:
		if not bool(f.get("back", false)):
			n += 1
	for nm in pending:
		if not bool((pending[nm] as Dictionary).get("back", false)):
			n += 1
	return n


## Почему повозка не везёт новые семьи ("" — везёт): первые Defs.ARRIVE_FREE семей едут всегда,
## дальше — только пока счастье города не ниже Defs.ARRIVE_HAPPY (как поезд в Town to City)
func arrivals_blocked() -> String:
	if families_came() < Defs.ARRIVE_FREE or int(stats.get("pop", 0)) <= 0:
		return ""
	if int(stats.get("happy", 0)) < Defs.ARRIVE_HAPPY:
		return "Новые семьи приедут, когда счастье города будет не ниже %d%% (сейчас %d%%)" % [Defs.ARRIVE_HAPPY, int(stats["happy"])]
	return ""


## Советник объясняет, почему повозка стоит, — один раз, без повторов (и снова не раньше чем через сутки)
func _arrive_gate(why: String) -> void:
	if why != "":
		if arrive_block_h == 0 and hour_n - arrive_block_said >= 24:
			arrive_block_said = hour_n
			arrive_block_told = true
			var tip := ""
			var ht: Array = stats.get("happy_tips", [])
			if not ht.is_empty():
				tip = " Совет: " + String(ht[0]) + "."
			var msg := "Новые семьи не едут: в город переселяются, только если счастье не ниже %d%%, а сейчас %d%%.%s" % [Defs.ARRIVE_HAPPY, int(stats["happy"]), tip]
			if not tips.has("arrive_block") and not arrive_advice.get_connections().is_empty():
				# в первый раз объясняет советник (окно с текстом), а не всплывашка; в колокольчик — как обычно
				tips["arrive_block"] = true
				events.append({"day": day, "text": msg, "icon": "happy"})
				if events.size() > 60:
					events.pop_front()
				arrive_advice.emit(msg)
			else:
				_event(msg, "happy")
		arrive_block_h += 1
	else:
		if arrive_block_told:              # «снова едут» — только в ответ на «не едут»
			_event("Счастье города %d%% — повозка снова везёт новые семьи" % int(stats["happy"]), "family")
		arrive_block_told = false
		arrive_block_h = 0


## Раз в час: не пора ли повозке привезти новую семью
func _tick_arrivals() -> void:
	if center().is_empty() or _count(func(b): return is_house(b)) == 0:
		return
	var why := arrivals_blocked()
	stats["arrive_block"] = why
	_arrive_gate(why)
	if why != "":
		arrive_t = minf(arrive_t + 1.0, 99.0)     # как только счастье поднимется — повозка поедет сразу
		return
	var room: int = int(Defs.ARRIVAL_MAX[level]) - arrivals.size() - incoming
	if room <= 0:
		arrive_t = 0.0
		return
	arrive_t += 1.0
	var every: float = Defs.ARRIVE_EVERY[clampi(level, 0, Defs.ARRIVE_EVERY.size() - 1)]
	var first := settled_total == 0 and arrivals.is_empty() and incoming == 0 and pending.is_empty()
	if arrive_t >= every or first:
		arrive_t = 0.0
		var n := mini(room, 2 + level / 3)    # семьи приезжают по двое
		if int(stats["happy"]) < Defs.ARRIVE_HAPPY and int(stats["pop"]) > 0:
			n = mini(n, maxi(0, Defs.ARRIVE_FREE - families_came()))   # без счастья — только первые ARRIVE_FREE семей
		incoming += n


## Кого везёт повозка: семьи тех классов, для которых открыты дома (чаще — те, для кого есть место)
func pick_class() -> String:
	var opts := []
	var total := 0.0
	for cl in Defs.CLASS_ORDER:
		if not unlocked(Defs.CLASSES[cl]["house"]):
			continue
		var free := 0
		for id in buildings:
			var b: Dictionary = buildings[id]
			if is_house(b) and def(b)["cls"] == cl:
				var lf := house_cap(b) - int(b["pop"]) - int(b.get("coming", 0))
				if lf >= int(Defs.FAMILY_SIZE[cl][0]):       # одно место у плебеев — не место: семьи от двух
					free += lf
		for f in arrivals:
			if f["cls"] == cl:
				free -= int(f["n"])
		var w := 3.0 if free > 0 else (1.0 if cl == "plebs" else 0.5)
		opts.append([cl, w])
		total += w
	var x := rng.randf() * total
	for o in opts:
		x -= float(o[1])
		if x <= 0.0:
			return o[0]
	return "plebs"


## Новая семья: родовое имя, которого ещё нет в городе
func new_family(cls: String) -> Dictionary:
	var used := {}
	for f in arrivals:
		used[f["name"]] = true
	for nm in pending:
		used[nm] = true
	for id in buildings:
		for f in buildings[id].get("families", []):
			used[f["name"]] = true
	var name := ""
	for k in 60:
		var nm: String = Defs.FAMILIES[rng.randi() % Defs.FAMILIES.size()]
		if k >= 20:
			nm += " " + Defs.COGNOMENS[rng.randi() % Defs.COGNOMENS.size()]
		if not used.has(nm):
			name = nm
			break
	if name == "":
		name = "%s %d" % [Defs.FAMILIES[rng.randi() % Defs.FAMILIES.size()], rng.randi() % 1000]
	var sz: Array = Defs.FAMILY_SIZE[cls]
	return {"name": name, "n": rng.randi_range(int(sz[0]), int(sz[1])), "cls": cls}


## Семья сошла с повозки (или осталась без дома) и ждёт на площади
func family_arrived(f: Dictionary, from_cart := true) -> void:
	if from_cart:
		incoming = maxi(0, incoming - 1)
	# вернулась семья, что уже жила в городе (дом снесли, или в дом влезли не все): второй раз её не считаем
	var back := not from_cart and (bool(f.get("back", false)) or bool((pending.get(f["name"], {}) as Dictionary).get("back", false)) \
		or _lives_here(String(f["name"])))
	pending.erase(f["name"])
	for a in arrivals:
		if a["name"] == f["name"]:
			return
	arrivals.append({"name": f["name"], "n": int(f["n"]), "cls": f["cls"], "back": back})
	arrivals_changed.emit()
	changed.emit()
	if from_cart:
		family_came.emit(arrivals[-1])


## Есть ли в городе дом, где уже живёт семья с этим именем
func _lives_here(name: String) -> bool:
	for id in buildings:
		for f in buildings[id].get("families", []):
			if String(f["name"]) == name:
				return true
	return false


func arrival(name: String) -> Dictionary:
	for a in arrivals:
		if a["name"] == name:
			return a
	return {}


## Подходит ли дом семье: её класса и хватает места
func can_host(b: Dictionary, f: Dictionary) -> bool:
	return is_house(b) and def(b)["cls"] == f["cls"] and house_cap(b) - int(b["pop"]) - int(b.get("coming", 0)) >= int(f["n"])


func homes_for(f: Dictionary) -> Array:
	var out := []
	for id in buildings:
		if can_host(buildings[id], f):
			out.append(buildings[id])
	return out


## Игрок выбрал семье дом
func assign(name: String, home: int) -> bool:
	var f := arrival(name)
	if f.is_empty() or not buildings.has(home) or not can_host(buildings[home], f):
		return false
	arrivals.erase(f)
	var b: Dictionary = buildings[home]
	b["coming"] = int(b.get("coming", 0)) + int(f["n"])
	pending[name] = {"name": name, "n": f["n"], "cls": f["cls"], "home": home, "back": bool(f.get("back", false))}
	family_assigned.emit(name, home)
	arrivals_changed.emit()
	changed.emit()
	return true


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
	var back := bool((pending.get(name, {}) as Dictionary).get("back", false))
	pending.erase(name)
	if not back:
		settled_total += 1                 # семья, что уже жила в городе и переезжает снова, — не новая
	(b["families"] as Array).append({"name": name, "n": n})
	b["pop"] = int(b["pop"]) + n
	compute()
	_check_goals()
	house_changed.emit(b, false)
	changed.emit()
	return n


func _update_level() -> void:
	while level < Defs.LEVELS.size() - 1:
		var nx: Dictionary = Defs.LEVELS[level + 1]
		if int(stats["pop"]) >= int(nx["pop"]) and int(stats["happy"]) >= int(nx["happy"]):
			level += 1
			level_up.emit(level)         # раньше всплывашки: ролик её заменяет и придерживает новую станцию
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

func _count(pred: Callable) -> int:
	var n := 0
	for id in buildings:
		if pred.call(buildings[id]):
			n += 1
	return n


func goal_progress(id: String) -> int:
	var g := Defs.request(id)
	if g.is_empty():
		return 0
	var pp: Array = g["p"]
	var arg = pp[1] if pp.size() > 1 else null
	match pp[0]:
		"road": return road_cells
		"houses": return _count(func(b): return is_house(b))
		"fam": return settled_total
		"count": return _count(func(b): return b["type"] == arg or Defs.base_of(b["type"]) == arg)   # любой облик украшения
		"kind": return _count(func(b): return def(b)["kind"] == arg)
		"pop": return int(stats["pop"])
		"happy": return int(stats["happy"]) if int(stats["pop"]) >= 10 else 0
		"cls": return int(stats["residents"].get(arg, 0))
		"floors": return _count(func(b): return is_house(b) and int(b["tier"]) >= int(arg))
		"fed": return _count(func(b): return is_house(b) and bool((b.get("needs", {}) as Dictionary).get(arg, false)))
		"research": return research.keys().filter(func(k): return not String(k).begins_with("q_")).size()
		"shops":
			var kinds := {}
			for id2 in buildings:
				if def(buildings[id2])["kind"] == "shop":
					kinds[buildings[id2]["type"]] = true
			return kinds.size()
		"near":
			var cls: String = pp[2]
			var n := 0
			for id2 in buildings:
				var h: Dictionary = buildings[id2]
				if not is_house(h) or def(h)["cls"] != cls:
					continue
				for id3 in buildings:
					var o: Dictionary = buildings[id3]
					if o["type"] == arg and (o["pos"] as Vector2).distance_to(h["pos"]) <= maxf(18.0, Defs.range_m(def(o))):
						n += 1
						break
			return n
		"store": return mini(1, _count(func(b): return b["type"] == "warehouse")) + mini(1, _count(func(b): return b["type"] == "butcher"))
		"light": return _count(func(b): return def(b).get("light", false))
	return 0


func active_goals(n := 3) -> Array:
	var out := []
	for g in Defs.REQUESTS:
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
			var extra := ""
			if g.has("unlock"):
				research[g["unlock"]] = true
				extra = ". Открыто: %s" % g.get("reward", "новые украшения")
			_event("Просьба выполнена: %s (+%d ден.%s)%s" % [g["text"], g["money"], (", +%d оч." % g["rp"]) if int(g["rp"]) > 0 else "", extra], "check")


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
			"color": b["color"], "y": b["y"], "pop": b["pop"], "families": b["families"], "host": b.get("host", -1), "hire": b.get("hire", -1),
			"cells": Marshalls.raw_to_base64((b["cells"] as PackedInt32Array).to_byte_array())})
	return {"money": money, "rp": rp, "day": day, "level": level, "research": research.keys(), "buildings": bl, "next_id": next_id,
		"goals": goals_done, "arrivals": arrivals + pending.values().map(func(f): return {"name": f["name"], "n": f["n"], "cls": f["cls"], "back": bool(f.get("back", false))}),
		# семьи в повозке (и те, за кем она едет) — числом: после загрузки повозка привезёт их заново
		"incoming": incoming,
		"arrive_t": arrive_t, "settled_total": settled_total, "tips": tips, "events": events, "road_cells": road_cells,
		"legion": legion.to_dict()}


func load_data(d: Dictionary) -> void:
	money = float(d.get("money", Defs.START_MONEY))
	rp = float(d.get("rp", 0))
	day = int(d.get("day", 0))
	level = int(d.get("level", 0))
	research = {}
	for r in d.get("research", []):
		research[r] = true
	goals_done = d.get("goals", [])
	for g in Defs.REQUESTS:
		if goals_done.has(g["id"]) and g.has("unlock"):
			research[g["unlock"]] = true
	arrivals = []
	for f in d.get("arrivals", []):
		arrivals.append({"name": f["name"], "n": int(f["n"]), "cls": f.get("cls", "plebs"), "back": bool(f.get("back", false))})
	pending = {}
	incoming = maxi(0, int(d.get("incoming", 0)))
	arrive_t = float(d.get("arrive_t", 0.0))
	settled_total = int(d.get("settled_total", 0))
	tips = d.get("tips", {})
	road_cells = int(d.get("road_cells", 0))
	events = d.get("events", [])
	legion.from_dict(d.get("legion", {}))
	next_id = int(d.get("next_id", 1))
	buildings = {}
	for bd in d.get("buildings", []):
		var cells := Marshalls.base64_to_raw(bd.get("cells", "")).to_int32_array()
		var b := {"id": int(bd["id"]), "type": bd["type"], "tier": int(bd["tier"]), "pos": Vector2(float(bd["x"]), float(bd["z"])),
			"yaw": float(bd["yaw"]), "variant": int(bd.get("variant", 0)), "color": int(bd.get("color", 0)), "y": float(bd.get("y", Land.BASE_Y)),
			"cells": cells, "pop": int(bd["pop"]), "families": bd.get("families", []), "happy": 50, "up": 0, "down": 0, "staff": 1.0,
			"active": true, "road": true, "needs": {}, "served": 0, "score": {}, "missing": [], "coming": 0}
		if int(bd.get("host", -1)) >= 0:
			b["host"] = int(bd["host"])
		if int(bd.get("hire", -1)) >= 0:
			b["hire"] = int(bd["hire"])
		buildings[b["id"]] = b
		for k in cells:
			if land.occ[k] >= 0:               # арка у въезда остаётся занятой, даже если старое сохранение залезло на неё
				land.occ[k] = b["id"]
		next_id = maxi(next_id, int(b["id"]) + 1)
	compute()
