class_name LegionSim
extends RefCounted
## Бой Легиона без графики (перенос BattleSim из js/army.js). Детерминированный: одна и та же настройка
## с тем же зерном и теми же нажатиями умений в те же шаги даёт тот же бой. 3D-бой (legion_battle.gd)
## крутит ЭТОТ бой фиксированным шагом DT и только рисует его, поэтому исход совпадает с проверками баланса.
##
## Поле: ось x — вдоль поля (наш отряд слева, x < 0, враги выходят справа, x > 0), ось z — поперёк (±2,6).
## Единица — метр поля (3D-бой сам выбирает масштаб). Строй: ближний бой x = −4,6, стрелки −6,0, машины −7,4.
## Враги каждой волны входят справа от x ≈ 12 и выходят на поле до x ≈ 3,5 (стрелки 5,3).
## В боях с городами (setup.enemy_formation) отряд соперника стоит зеркально справа и не «входит».
##
## Как крутить:
##   var sim := LegionSim.new(setup)          # setup — Legion.make_battle(...) или make_pvp_battle(...)
##   while sim.result.is_empty(): sim.step(LegionSim.DT)
##   sim.press("oil")                          # кнопка умения у игрока (true — сработало; нажатие запоминается)
##   sim.set_auto(true)                        # «Авто» у игрока (запоминается)
## Нажатия игрока копятся в sim.inputs ([шаг, умение] и [шаг, "auto", вкл]) и уходят в итог (result.inputs):
## бой с городом сервер повторяет с ними (server/legion_sim.js — копия этого файла, меняйте вместе;
## сверка — scripts/test_sim_dump.gd и node server/test_sim.js).
##   for e in sim.take_events(): ...           # события для рисования (см. ниже)
## Состояние для рисования: sim.units (Unit), sim.shots (Shot), sim.t, sim.wave_idx, sim.perk_ready(id).
##
## События (Dictionary, поле "type"):
##   wave {n, total}                — вышла волна n из total
##   attack {unit, target, ranged}   — боец замахнулся/выстрелил (начало анимации удара)
##   shoot {shot}                    — вылетел снаряд (shot.kind: arrow | sling | bolt | stone | boulder)
##   hit {unit, dmg, crit, from}     — попадание (from — Unit или null для умений и ожога)
##   death {unit}                    — боец пал
##   slam {x, z, r}                  — удар великана/разбег Минотавра по площади
##   boom {x, z, r}                  — камень разорвался
##   charge {unit, target}           — разбег (Минотавр)
##   perk {id, side, x?, z?}         — сработало умение (у масла — точка)
##   heal {unit, amount}             — лечение (Перевязка)
##   end {win}                       — бой окончен (итог — sim.result)

const DT := 1.0 / 30.0
const TIME_LIMIT := 180.0
const WAVE_DELAY := 2.2
const FIELD_X := Vector2(-9.5, 14.0)
const FIELD_Z := 2.6
const LANES := [0.0, -1.1, 1.1, -2.1, 2.1, -0.55, 0.55]
const ENEMY_LANES := [0.0, -1.2, 1.2, -2.2, 2.2, -0.6, 0.6]
## Сила умений: [на 1 уровне, прибавка за уровень]. oil/volley/burn — доля среднего урона отряда (oil, volley — по
## каждому врагу; burn — в секунду 4 с), за уровень ×(1 + прибавка); testudo — насколько меньше урон (доля),
## bandage — доля здоровья, horn — во сколько раз быстрее бьют и ходят. Мягче, чем в старой игре: умения — сильная
## помощь, но без них бой на рекомендованном уровне тоже можно выиграть (проверки — test_legion.gd)
const PERK_K := {"oil": [3.0, 0.15], "burn": [0.4, 0.15], "volley": [1.2, 0.15], "testudo": [0.35, 0.04], "bandage": [0.18, 0.03], "horn": [1.3, 0.05]}


class Unit:
	var id := 0
	var side := "ally"             # ally | enemy
	var key := ""                  # род войск или враг (Legion.UNITS / Legion.ENEMIES)
	var name := ""
	var level := 0
	var x := 0.0
	var z := 0.0
	var hp := 0.0
	var max_hp := 0.0
	var atk := 0.0
	var armor := 0.0
	var range_m := 1.0            # дальность удара
	var min_range := 0.0
	var rate := 1.0
	var speed := 1.0
	var shot := ""
	var pierce := false
	var splash := 0.0
	var cleave := 0.0
	var charge := false
	var bites := 0
	var prefer := ""
	var vs := {}
	var tags: Array = []
	var boss := false
	var size := 1.0
	var alive := true
	var timer := 0.0
	var target: Unit = null
	var retarget := 0.0
	var testudo := 0.0             # до какого времени сомкнуты щиты
	var testudo_k := 0.0           # насколько меньше урон под черепахой
	var horn := 0.0                # до какого времени трубит рог
	var horn_k := 1.0
	var burn := 0.0                # до какого времени горит
	var burn_dps := 0.0
	var charge_cd := 4.0
	var moving := false
	var attack_t := 0.0            # >0 — идёт удар (для анимации)
	var hit_t := 0.0               # >0 — только что ранен (вспышка)
	var home_x := 0.0
	var home_z := 0.0
	var has_home := false
	var entering := false
	var wave := -1                 # номер волны врага (−1 — свой отряд)

	func ranged() -> bool:
		return range_m > 3.0

	func hp_frac() -> float:
		return clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)


class Shot:
	var kind := ""
	var from: Unit = null
	var target: Unit = null
	var x0 := 0.0
	var z0 := 0.0
	var x1 := 0.0
	var z1 := 0.0
	var t := 0.0
	var dur := 0.25
	var side := "ally"
	var done := false

	## Доля полёта 0…1 (для рисования дуги)
	func k() -> float:
		return clampf(t / maxf(0.001, dur), 0.0, 1.0)


var setup := {}
var rng := RandomNumberGenerator.new()
var t := 0.0
var units: Array[Unit] = []
var shots: Array[Shot] = []
var events: Array = []
var waves: Array = []
var wave_idx := -1
var wave_delay := 0.0
var result := {}
var total := 0
var steps := 0
## умения по сторонам: side → {id: {lvl, ready}}
var perks := {"ally": {}, "enemy": {}}
## кто сам жмёт умения: проверки баланса и оборона соперника в боях с городами; игрок может включить «Авто»
var auto := {"ally": false, "enemy": false}
var avg_atk := {"ally": 1.0, "enemy": 1.0}
## нажатия игрока по шагам: [шаг, умение] / [шаг, "auto", вкл] (шаг — сколько шагов боя уже сделано)
var inputs: Array = []
var _uid := 1
var _formation := false


func _init(s: Dictionary) -> void:
	setup = s
	rng.seed = int(s.get("seed", 1))
	waves = s.get("waves", [])
	_formation = bool(s.get("enemy_formation", false))
	for id in s.get("perks", {}):
		if int(s["perks"][id]) > 0 and Legion.PERKS.has(id):
			perks["ally"][id] = {"lvl": int(s["perks"][id]), "ready": float(Legion.PERKS[id]["cd"]) * 0.5}
	for id in s.get("enemy_perks", {}):
		if int(s["enemy_perks"][id]) > 0 and Legion.PERKS.has(id):
			perks["enemy"][id] = {"lvl": int(s["enemy_perks"][id]), "ready": float(Legion.PERKS[id]["cd"]) * 0.5}
	auto["ally"] = bool(s.get("auto", false))
	auto["enemy"] = bool(s.get("enemy_auto", false))
	var squad: Array = s.get("squad", [])
	_place_formation(squad, "ally")
	total = units.size()
	avg_atk["ally"] = _avg(squad)
	if _formation:
		# бой с городом: отряд соперника стоит зеркально, одной «волной»
		wave_idx = 0
		var foes: Array = waves[0] if not waves.is_empty() else []
		_place_formation(foes, "enemy")
		avg_atk["enemy"] = _avg(foes)
		events.append({"type": "wave", "n": 1, "total": 1})
	else:
		_next_wave()


static func _avg(list: Array) -> float:
	var a := 0.0
	for s: Dictionary in list:
		a += float(s["atk"])
	return a / maxf(1.0, list.size())


## Строй: ближний бой впереди, стрелки за ними, машины в тылу (у врагов в боях с городами — зеркально)
func _place_formation(list: Array, side: String) -> void:
	var order := list.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ka := (1 if float(a["range"]) > 3.0 else 0) * 2 + (1 if float(a["speed"]) == 0.0 else 0)
		var kb := (1 if float(b["range"]) > 3.0 else 0) * 2 + (1 if float(b["speed"]) == 0.0 else 0)
		return ka < kb)
	var sgn := -1.0 if side == "ally" else 1.0
	for i in order.size():
		var s: Dictionary = order[i]
		var x := 7.4 if float(s["speed"]) == 0.0 else (6.0 if float(s["range"]) > 3.0 else 4.6)
		x += (i % 2) * 0.5
		var u := _add(side, s, sgn * x, float(LANES[i % LANES.size()]))
		u.home_x = u.x
		u.home_z = u.z
		u.has_home = true
		u.wave = -1 if side == "ally" else 0


func _add(side: String, s: Dictionary, x: float, z: float) -> Unit:
	var u := Unit.new()
	u.id = _uid
	_uid += 1
	u.side = side
	u.key = String(s["key"])
	u.name = String(s.get("name", u.key))
	u.level = int(s.get("level", 0))
	u.x = x
	u.z = z
	u.hp = float(s["hp"])
	u.max_hp = u.hp
	u.atk = float(s["atk"])
	u.armor = float(s["armor"])
	u.range_m = float(s["range"])
	u.min_range = float(s.get("min_range", 0.0))
	u.rate = float(s["rate"])
	u.speed = float(s["speed"])
	u.shot = String(s.get("shot", ""))
	u.pierce = bool(s.get("pierce", false))
	u.splash = float(s.get("splash", 0.0))
	u.cleave = float(s.get("cleave", 0.0))
	u.charge = bool(s.get("charge", false))
	u.bites = int(s.get("bites", 0))
	u.prefer = String(s.get("prefer", ""))
	u.vs = s.get("vs", {})
	u.tags = s.get("tags", [])
	u.boss = bool(s.get("boss", false))
	u.size = float(s.get("size", 1.0))
	u.timer = 0.3 + rng.randf() * 0.6
	units.append(u)
	return u


func _next_wave() -> bool:
	wave_idx += 1
	if wave_idx >= waves.size():
		return false
	var wave: Array = waves[wave_idx]
	var sum := 0.0
	# волна-«куча» (только походы: setup.packs; бои с городами её не знают — сервер считает их без неё)
	var packed: bool = wave_idx in (setup.get("packs", []) as Array)
	for i in wave.size():
		var s: Dictionary = wave[i]
		sum += float(s["atk"])
		var rg := float(s["range"]) > 3.0
		var x := 12.0 + (1.5 if rg else 0.0) + (i % 3) * 0.7 + (1.0 if bool(s.get("boss", false)) else 0.0)
		var z := 0.0 if bool(s.get("boss", false)) else float(ENEMY_LANES[i % ENEMY_LANES.size()])
		if packed:
			# тесно: шаг 0,35 м вдоль, ±0,35 м поперёк
			x = 12.0 + i * 0.35
			z = float((i % 3) - 1) * 0.35
		var u := _add("enemy", s, x, z)
		u.entering = true
		u.wave = wave_idx
	avg_atk["enemy"] = sum / maxf(1.0, wave.size())
	events.append({"type": "wave", "n": wave_idx + 1, "total": waves.size()})
	return true


static func _other(side: String) -> String:
	return "enemy" if side == "ally" else "ally"


func foes_of(u: Unit) -> Array[Unit]:
	var out: Array[Unit] = []
	for o in units:
		if o.alive and o.side != u.side:
			out.append(o)
	return out


func alive_of(side: String) -> Array[Unit]:
	var out: Array[Unit] = []
	for o in units:
		if o.alive and o.side == side:
			out.append(o)
	return out


static func dist(a: Unit, b: Unit) -> float:
	return Vector2(a.x - b.x, (a.z - b.z) * 0.8).length()


func _pick_target(u: Unit) -> Unit:
	var foes := foes_of(u)
	if foes.is_empty():
		return null
	var pool := foes
	if u.prefer == "ranged":
		var r: Array[Unit] = []
		for o in foes:
			if o.ranged():
				r.append(o)
		if not r.is_empty():
			pool = r
	if u.pierce:
		var big: Array[Unit] = []
		for o in foes:
			if o.boss or "armored" in o.tags or "giant" in o.tags:
				big.append(o)
		if not big.is_empty():
			pool = big
	if u.splash > 0.0 and u.shot == "stone":
		# катапульта метит в гущу врагов
		var best: Unit = null
		var bn := -1
		for o in foes:
			var n := 0
			for p in foes:
				if dist(o, p) < u.splash:
					n += 1
			if n > bn:
				bn = n
				best = o
		return best
	var best2: Unit = null
	var bd := INF
	for o in pool:
		var d := dist(u, o)
		if d < bd:
			bd = d
			best2 = o
	return best2


static func _mult(vs: Dictionary, tg: Unit) -> float:
	var m := 1.0
	for tag in tg.tags:
		if vs.has(tag):
			m = maxf(m, float(vs[tag]))
	return m


## Урон по цели: atk атакующего, его vs; from — кто бил (null — умение); k — доля
func _damage(atk: float, vs: Dictionary, from: Unit, tg: Unit, k := 1.0) -> void:
	if not tg.alive:
		return
	var crit := rng.randf() < 0.08
	var d := atk * _mult(vs, tg) * (0.9 + rng.randf() * 0.2) * k * (1.6 if crit else 1.0)
	d *= 1.0 - tg.armor / (tg.armor + 100.0)
	if tg.testudo > t:
		d *= 1.0 - tg.testudo_k
	var dmg := maxi(1, roundi(d))
	tg.hp -= dmg
	tg.hit_t = 0.25
	events.append({"type": "hit", "unit": tg, "dmg": dmg, "crit": crit, "from": from})
	if tg.hp <= 0.0:
		_kill(tg)


func _kill(tg: Unit) -> void:
	if not tg.alive:
		return
	tg.alive = false
	tg.hp = 0.0
	tg.target = null
	events.append({"type": "death", "unit": tg})


func _attack(u: Unit, tg: Unit) -> void:
	u.attack_t = 0.35
	events.append({"type": "attack", "unit": u, "target": tg, "ranged": u.shot != ""})
	if u.shot != "":
		var d := absf(tg.x - u.x)
		var speed := 9.0 if u.shot == "stone" or u.shot == "boulder" else (24.0 if u.shot == "bolt" else 16.0)
		var s := Shot.new()
		s.kind = u.shot
		s.from = u
		s.target = tg
		s.x0 = u.x
		s.z0 = u.z
		s.x1 = tg.x
		s.z1 = tg.z
		s.dur = maxf(0.25, d / speed)
		s.side = u.side
		shots.append(s)
		events.append({"type": "shoot", "shot": s})
		return
	if u.bites > 0:
		# Цербер кусает тремя головами сразу трёх ближайших
		var near := foes_of(u)
		near.sort_custom(func(a: Unit, b: Unit) -> bool: return dist(u, a) < dist(u, b))
		for i in mini(u.bites, near.size()):
			if dist(u, near[i]) < u.range_m + 1.2:
				_damage(u.atk, u.vs, u, near[i], 0.75)
		return
	if u.cleave > 0.0:
		# удар великана задевает всех рядом с целью
		for o in foes_of(u):
			if o == tg or dist(o, tg) < u.cleave:
				_damage(u.atk, u.vs, u, o, 1.0 if o == tg else 0.6)
		events.append({"type": "slam", "x": tg.x, "z": tg.z, "r": u.cleave})
		return
	_damage(u.atk, u.vs, u, tg)


func _land(s: Shot) -> void:
	var u := s.from
	if s.kind == "bolt":
		# болт летит дальше и пробивает всех на линии (до четырёх, каждый следующий слабее)
		var hit: Array[Unit] = []
		for o in units:
			if o.alive and o.side != s.side and absf(o.z - s.z1) < 0.7 and (o.x >= s.x0 if s.side == "ally" else o.x <= s.x0):
				hit.append(o)
		hit.sort_custom(func(a: Unit, b: Unit) -> bool: return absf(a.x - s.x0) < absf(b.x - s.x0))
		var k := 1.0
		for i in mini(4, hit.size()):
			_damage(u.atk, u.vs, u, hit[i], k)
			k *= 0.7
		return
	if s.kind == "stone" or s.kind == "boulder":
		var r := u.splash if u.splash > 0.0 else 1.4
		for o in units:
			if o.alive and o.side != s.side and Vector2(o.x - s.x1, o.z - s.z1).length() < r:
				_damage(u.atk, u.vs, u, o, 1.0 if o == s.target else 0.7)
		events.append({"type": "boom", "x": s.x1, "z": s.z1, "r": r})
		return
	if s.target.alive:
		_damage(u.atk, u.vs, u, s.target)


# =====================================================================
#   умения
# =====================================================================

## Секунд до готовности умения (−1 — умения нет у этой стороны)
func perk_ready(id: String, side := "ally") -> float:
	var p: Dictionary = perks[side].get(id, {})
	if p.is_empty():
		return -1.0
	return float(p["ready"])


## Доля перезарядки 0…1 (1 — готово)
func perk_charge(id: String, side := "ally") -> float:
	var p: Dictionary = perks[side].get(id, {})
	if p.is_empty():
		return 0.0
	return clampf(1.0 - float(p["ready"]) / float(Legion.PERKS[id]["cd"]), 0.0, 1.0)


## Нажать умение; true — сработало
func use_perk(id: String, side := "ally") -> bool:
	var p: Dictionary = perks[side].get(id, {})
	if p.is_empty() or float(p["ready"]) > 0.0 or not result.is_empty():
		return false
	var foes := alive_of(_other(side))
	var allies := alive_of(side)
	var lvl := int(p["lvl"])
	var a := float(avg_atk[side])
	match id:
		"oil":
			if foes.is_empty():
				return false
			var c := foes[0]
			var bn := -1
			for o in foes:
				var n := 0
				for q in foes:
					if Vector2(q.x - o.x, q.z - o.z).length() < 2.0:
						n += 1
				if n > bn:
					bn = n
					c = o
			var cx := c.x
			var cz := c.z
			for o in foes:
				if Vector2(o.x - cx, o.z - cz).length() < 2.2:
					_damage(a * PERK_K["oil"][0] * (1.0 + PERK_K["oil"][1] * (lvl - 1)), {}, null, o)
					o.burn = t + 4.0
					o.burn_dps = a * PERK_K["burn"][0] * (1.0 + PERK_K["burn"][1] * (lvl - 1))
			events.append({"type": "perk", "id": id, "side": side, "x": cx, "z": cz})
		"volley":
			if foes.is_empty():
				return false
			for o in foes:
				_damage(a * PERK_K["volley"][0] * (1.0 + PERK_K["volley"][1] * (lvl - 1)), {}, null, o)
			events.append({"type": "perk", "id": id, "side": side})
		"testudo":
			for u in allies:
				u.testudo = t + 5.0 + lvl
				u.testudo_k = PERK_K["testudo"][0] + PERK_K["testudo"][1] * (lvl - 1)
			events.append({"type": "perk", "id": id, "side": side})
		"bandage":
			for u in allies:
				var h := roundi(u.max_hp * (PERK_K["bandage"][0] + PERK_K["bandage"][1] * (lvl - 1)))
				u.hp = minf(u.max_hp, u.hp + h)
				events.append({"type": "heal", "unit": u, "amount": h})
			events.append({"type": "perk", "id": id, "side": side})
		"horn":
			for u in allies:
				u.horn = t + 8.0
				u.horn_k = PERK_K["horn"][0] + PERK_K["horn"][1] * (lvl - 1)
			events.append({"type": "perk", "id": id, "side": side})
		_:
			return false
	p["ready"] = float(Legion.PERKS[id]["cd"])
	return true


## Игрок нажал умение (кнопка или клавиша в 3D-бою): то же, что use_perk, но нажатие запоминается в inputs
func press(id: String) -> bool:
	if not use_perk(id, "ally"):
		return false
	inputs.append([steps, id])
	return true


## Игрок включил или выключил «Авто» (тоже запоминается)
func set_auto(on: bool) -> void:
	if bool(auto["ally"]) == on:
		return
	auto["ally"] = on
	inputs.append([steps, "auto", on])


## Сам жмёт умения с умом (проверки баланса, оборона соперника, кнопка «Авто»)
func _auto_perks(side: String) -> void:
	var ps: Dictionary = perks[side]
	if ps.is_empty():
		return
	var foes := alive_of(_other(side))
	var allies := alive_of(side)
	if foes.is_empty() or allies.is_empty():
		return
	var boss := false
	for o in foes:
		if o.boss:
			boss = true
	var engaged := false
	var low := 1.0
	var avg := 0.0
	for u in allies:
		low = minf(low, u.hp_frac())
		avg += u.hp_frac()
		if u.target != null and u.target.alive and dist(u, u.target) <= u.range_m + 0.6:
			engaged = true
	avg /= allies.size()
	if ps.has("bandage") and float(ps["bandage"]["ready"]) <= 0.0 and (avg < 0.6 or low < 0.35):
		use_perk("bandage", side)
	if ps.has("testudo") and float(ps["testudo"]["ready"]) <= 0.0 and engaged and (boss or low < 0.55 or foes.size() >= 4):
		use_perk("testudo", side)
	if ps.has("horn") and float(ps["horn"]["ready"]) <= 0.0 and engaged:
		use_perk("horn", side)
	if ps.has("volley") and float(ps["volley"]["ready"]) <= 0.0 and (foes.size() >= 3 or boss):
		use_perk("volley", side)
	if ps.has("oil") and float(ps["oil"]["ready"]) <= 0.0:
		var bn := 0
		for o in foes:
			var n := 0
			for q in foes:
				if Vector2(q.x - o.x, q.z - o.z).length() < 2.0:
					n += 1
			bn = maxi(bn, n)
		if bn >= 3 or boss or foes.size() == 1:
			use_perk("oil", side)


# =====================================================================
#   шаг боя
# =====================================================================

## Забрать накопленные события (для рисования)
func take_events() -> Array:
	var e := events
	events = []
	return e


func step(dt := DT) -> void:
	if not result.is_empty():
		return
	t += dt
	steps += 1
	for side in perks:
		for id in perks[side]:
			var p: Dictionary = perks[side][id]
			p["ready"] = maxf(0.0, float(p["ready"]) - dt)
	for side: String in ["ally", "enemy"]:
		if auto[side]:
			_auto_perks(side)

	for u in units:
		if not u.alive:
			continue
		u.attack_t = maxf(0.0, u.attack_t - dt)
		u.hit_t = maxf(0.0, u.hit_t - dt)
		if u.burn > t:
			u.hp -= u.burn_dps * dt
			if u.hp <= 0.0:
				_kill(u)
				continue
		# враги новой волны сначала выходят на поле
		if u.entering:
			u.x -= u.speed * 1.4 * dt
			u.moving = true
			if u.x < 3.5 + (1.8 if u.ranged() else 0.0):
				u.entering = false
			continue
		u.retarget -= dt
		if u.target == null or not u.target.alive or u.retarget <= 0.0:
			u.target = _pick_target(u)
			u.retarget = 0.6
		var tg := u.target
		if tg == null:
			# врагов нет — отряд возвращается в строй и ждёт следующую волну
			if u.has_home and u.speed > 0.0 and absf(u.x - u.home_x) > 0.15:
				u.x += signf(u.home_x - u.x) * minf(u.speed * 1.3 * dt, absf(u.home_x - u.x))
				u.z += (u.home_z - u.z) * dt * 2.0
				u.moving = true
			else:
				u.moving = false
			continue
		var fast := u.horn_k if u.horn > t else 1.0
		var reach := u.range_m + 0.35 * (u.size + tg.size - 2.0)
		var d := dist(u, tg)
		if d > reach and u.speed > 0.0:
			var dir := signf(tg.x - u.x)
			if dir == 0.0:
				dir = 1.0
			u.x += dir * minf(u.speed * fast * dt, d - reach + 0.01)
			u.z += clampf(tg.z - u.z, -1.0, 1.0) * dt * 0.8
			u.moving = true
			# Минотавр с разбега бьёт сильнее и отбрасывает
			if u.charge and d < 4.0 and u.charge_cd <= 0.0:
				u.charge_cd = 7.0
				events.append({"type": "charge", "unit": u, "target": tg})
				_damage(u.atk, u.vs, u, tg, 1.8)
				tg.x += signf(tg.x - u.x) * 1.2
				events.append({"type": "slam", "x": tg.x, "z": tg.z, "r": 1.0})
		else:
			u.moving = false
			if u.min_range > 0.0 and d < u.min_range:
				u.timer = maxf(u.timer, 0.2)
			u.timer -= dt * fast
			if u.timer <= 0.0 and d <= reach + 0.05:
				_attack(u, tg)
				u.timer = u.rate * (0.92 + rng.randf() * 0.16)
		u.charge_cd -= dt

	# бойцы одной стороны не стоят друг в друге
	for a in units:
		if not a.alive:
			continue
		for b in units:
			if b == a or not b.alive or b.side != a.side:
				continue
			var dx := a.x - b.x
			var dz := a.z - b.z
			var mn := 0.7 * (a.size + b.size) / 2.0
			if absf(dx) < mn and absf(dz) < mn:
				a.z += (1.0 if dz >= 0.0 else -1.0) * dt * 1.2
		a.z = clampf(a.z, -FIELD_Z, FIELD_Z)
		a.x = clampf(a.x, FIELD_X.x, FIELD_X.y)

	for s in shots:
		s.t += dt
		if s.target.alive:
			s.x1 = s.target.x
			s.z1 = s.target.z
		if s.t >= s.dur:
			s.done = true
			_land(s)
	var keep: Array[Shot] = []
	for s in shots:
		if not s.done:
			keep.append(s)
	shots = keep

	var allies := alive_of("ally").size()
	var foes := alive_of("enemy").size()
	if allies == 0:
		_end(false, 0)
		return
	if foes == 0 and shots.is_empty():
		if not _formation and wave_idx + 1 < waves.size():
			wave_delay += dt
			if wave_delay > WAVE_DELAY:
				wave_delay = 0.0
				_next_wave()
		else:
			_end(true, allies)
			return
	if t > TIME_LIMIT:
		_end(false, allies, true)


func _end(win: bool, alive: int, timeout := false) -> void:
	var hp := 0.0
	var mx := 0.0
	for u in units:
		if u.side == "ally":
			mx += u.max_hp
			if u.alive:
				hp += u.hp
	result = {"win": win, "alive": alive, "total": total, "timeout": timeout, "time": t, "hp_left": hp / maxf(1.0, mx),
		"inputs": inputs.duplicate(true)}
	events.append({"type": "end", "win": win})
	dispose()


## Разорвать ссылки бойцов друг на друга (цели), иначе они не освобождаются из памяти.
## Бой сам зовёт это в конце; если бой бросили посередине — позовите вручную
func dispose() -> void:
	for u in units:
		u.target = null


## Досчитать бой до конца без графики (проверки баланса, бои обороны). auto_ally — сам жмёт умения
func run(auto_ally := true) -> Dictionary:
	set_auto(auto_ally)
	while result.is_empty():
		step(DT)
		events.clear()
	return result
