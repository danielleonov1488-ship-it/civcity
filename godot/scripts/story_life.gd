class_name StoryLife
extends Node
## Живые сцены историй горожан (scripts/stories.gd):
##  - «Скверик для стариков»: пока его строят и потом всегда — днём (DAY) на скамьи у дома приходят старики, садятся
##    и болтают, к вечеру уходят по домам. Чем больше скамей, тем больше стариков (полтора на скамью, не больше MAX);
##  - «Стол для латрункулов» (награда скверика): по утрам (PLAY) двое стариков садятся за доску (не больше чем за TABLES столами).
## Старики — не жители (в счёте людей их нет), как люди в ролике; седые (Citizen.elder_look). Скамьи делят с жителями:
## место, где сидит житель, старик не берёт, своё помечает в people.spots (MARK) — туда житель не сядет.
## В ролике скверика (force_on) старики сразу сидят на местах, в любой час.

const MAX := 8
const TABLES := 3                      # столов для латрункулов, за которыми играют (у каждого двое стариков), не больше
const DAY := [8.0, 18.0]               # старики в скверике
const PLAY := [7.0, 12.0]              # играют в латрункулы
const WALK := 0.72                     # шаг старика, м/с
const MARK := -7                       # место на скамье занято стариком (в people.spots вместо номера жителя)
const SYNC := 1.0                      # раз в столько секунд — кто должен сидеть

var st                                 # Stories
var game
var city: City
var elders := {}                       # «скамья:место» → {node, bid, k, p, yaw, seat, state, path, i, t, from, yoff, yoff_to}
var _t := 0.0
var _forced := {}                      # ролик: скверик {c, r} — старики сидят сразу, в любой час
var _instant := true                   # первая расстановка (после загрузки) — сразу на местах, без прихода
var _speed := -1.0


func setup(s) -> void:
	st = s
	game = s.game
	city = s.city
	city.building_removed.connect(_on_removed)


## Скверики, где сидят старики: [{c, r}] — тот, что строят (и ждёт ролика), и готовые
func squares() -> Array:
	var out := []
	var S: Dictionary = city.stories
	var a: Dictionary = S["active"]
	if not a.is_empty() and String(a.get("id", "")) == "square":
		var r := Stories._sq_r(StoryDefs.story("square"))
		var at: Array = (a.get("flags", {}) as Dictionary).get("sq_at", [])
		if bool(a.get("ready", false)) and at.size() == 2:
			out.append({"c": Vector2(float(at[0]), float(at[1])), "r": r})   # готов, ждёт ролика: там, где его мерили
		elif (st._goal_kind(a) == "square" or bool(a.get("ready", false))) and not a.has("homeless") \
				and city.buildings.has(int(a.get("home", -1))):
			# строят — у дома просящего; дом снесли (семья без дома) — стариков нет (а не у станции)
			out.append({"c": st._home_pos(a), "r": r})
	var e: Dictionary = (S["done"] as Dictionary).get("square", {})
	var sq: Array = (e.get("flags", {}) as Dictionary).get("sq", [])
	if sq.size() == 2:
		out.append({"c": Vector2(float(sq[0]), float(sq[1])), "r": Stories._sq_r(StoryDefs.story("square"))})
	return out


## Ролик скверика: старики сразу на местах (в любой час)
func force_on(c: Vector2, r: float) -> void:
	_forced = {"c": c, "r": r}
	_sync(true)


func force_off() -> void:
	if _forced.is_empty():
		return
	_forced = {}
	_t = 0.0


func _process(dt: float) -> void:
	if game == null or not game.ready_done:
		return
	if not st.allowed():
		if not elders.is_empty():
			clear()
		_champ_off()
		return
	var sp := float(game.speed)
	if sp != _speed:
		_speed = sp
		for key in elders:
			var n = elders[key]["node"]
			if n != null and is_instance_valid(n):
				(n as Citizen).anim.speed_scale = maxf(0.0, sp)
	var sdt := dt * sp
	for key in elders.keys():
		_step(key, elders[key], sdt, dt)
	_champ_tick(dt)
	_t -= dt
	if _t <= 0.0:
		_t = SYNC
		_sync(_instant)
		_instant = false


## Кто где должен сидеть сейчас: «скамья:место» → {bid, k, p, yaw, seat}
func want() -> Dictionary:
	var out := {}
	var h: float = game.hour
	var day := h >= float(DAY[0]) and h < float(DAY[1])
	var list := squares()
	if not _forced.is_empty():
		list.push_front(_forced)
	var taken := {}
	for q: Dictionary in list:
		if not day and q != _forced:
			continue
		var c: Vector2 = q["c"]
		var benches := []
		for id in city.buildings:
			var b: Dictionary = city.buildings[id]
			if Defs.base_of(b["type"]) == "bench" and not taken.has(int(id)) and (b["pos"] as Vector2).distance_to(c) <= float(q["r"]):
				benches.append(b)
		benches.sort_custom(func(x, y): return (x["pos"] as Vector2).distance_to(c) < (y["pos"] as Vector2).distance_to(c))
		var n := mini(MAX, benches.size() + benches.size() / 2)
		for i in benches.size():
			var b: Dictionary = benches[i]
			taken[int(b["id"])] = true
			var seats: Array = game.people._bench_seats(b)
			var xf := city.xf(b)
			var take := 2 if i % 2 == 0 else 1
			for k in seats.size():
				if n <= 0 or take <= 0:
					break
				var key := "%d:%d" % [int(b["id"]), k]
				if not elders.has(key) and _busy(int(b["id"]), k):
					continue                 # там сидит житель
				var s: Array = seats[k]
				var w: Vector3 = xf * (s[0] as Vector3)
				out[key] = {"bid": int(b["id"]), "k": k, "p": Vector2(w.x, w.z), "yaw": float(b["yaw"]) + float(s[1]), "seat": float(s[2])}
				n -= 1
				take -= 1
	# стол для латрункулов: по утрам двое играют — не больше чем за TABLES столами (живые старики дороги): у ролика —
	# первыми, дальше — самые старые столы (порядок постоянный: камера ходит — старики не меняются)
	var morning := h >= float(PLAY[0]) and h < float(PLAY[1])
	var tables := []
	for id in city.buildings:
		var b: Dictionary = city.buildings[id]
		if b["type"] != "latrunc":
			continue
		var near_cine := not _forced.is_empty() and (b["pos"] as Vector2).distance_to(_forced["c"]) < 30.0
		if morning or near_cine:
			tables.append([0 if near_cine else 1, int(b.get("born", id)), int(id)])
	tables.sort_custom(func(x, y): return x[0] < y[0] or (x[0] == y[0] and (x[1] < y[1] or (x[1] == y[1] and x[2] < y[2]))))
	for t: Array in tables.slice(0, TABLES):
		var id := int(t[2])
		var b: Dictionary = city.buildings[id]
		var xf := city.xf(b)
		for k in CatDecor.LATRUNC_SEATS.size():
			var s: Array = CatDecor.LATRUNC_SEATS[k]
			var w: Vector3 = xf * ((s[0] as Vector3) * Catalog.DECOR)
			out["t%d:%d" % [id, k]] = {"bid": id, "k": -1 - k, "p": Vector2(w.x, w.z), "yaw": float(b["yaw"]) + float(s[1]),
				"seat": float(s[2]) * Catalog.DECOR, "table": true}
	return out


## Место на скамье занято жителем
func _busy(bid: int, k: int) -> bool:
	var sp: Dictionary = game.people.spots.get(bid, {})
	return sp.has(k) and int(sp[k]) != MARK


func _sync(instant: bool) -> void:
	var w := want()
	for key in elders.keys():
		if not w.has(key):
			_leave(elders[key])
	for key in w:
		if elders.has(key):
			var e: Dictionary = elders[key]
			if instant and e["state"] in ["in", "exit", "out"]:
				_seat_now(e)                 # ролик: кто ещё шёл — уже сидит
			continue
		_spawn(String(key), w[key], instant)


## Старик приходит (instant — уже сидит, проявляется на месте)
func _spawn(key: String, d: Dictionary, instant: bool) -> void:
	var rr := RandomNumberGenerator.new()
	rr.seed = hash("старик:" + key)           # на этом месте всегда сидит тот же старик — знакомые лица
	var female := rr.randf() < 0.4
	var c := Citizen.create(rr, female, false, false, "", "plebs")
	Citizen.elder_look(c)
	add_child(c)
	c.anim.speed_scale = maxf(0.0, float(game.speed))
	var e := d.duplicate()
	e["node"] = c
	e["yoff"] = 0.0
	e["yoff_to"] = clampf(float(d["seat"]) - People.SIT_SEAT, -0.05, 0.14)
	e["t"] = 0.0
	e["path"] = PackedVector2Array()
	e["i"] = 0
	if int(d["k"]) >= 0:
		var sp: Dictionary = game.people.spots.get(int(d["bid"]), {})
		sp[int(d["k"])] = MARK
		game.people.spots[int(d["bid"])] = sp
	elders[key] = e
	var from := _from(d["p"], rr)
	e["from"] = from
	var path: PackedVector2Array = PackedVector2Array() if instant or from == Vector2.INF else game.people._path(from, d["p"])
	if path.size() < 2:
		_seat_now(e)
		c.set_alpha(0.0)
		e["fade"] = 0.0
		return
	e["path"] = path
	e["state"] = "in"
	_put(e, path[0], 0.0)
	c.play("Walk", 0.0, rr.randf())


## Откуда старик идёт: дверь одного из домов поблизости (до 40 м)
func _from(p: Vector2, rr: RandomNumberGenerator) -> Vector2:
	var near := []
	for id in city.buildings:
		var b: Dictionary = city.buildings[id]
		if city.is_house(b) and int(b["pop"]) > 0 and (b["pos"] as Vector2).distance_to(p) < 40.0:
			near.append(b)
	if near.is_empty():
		return Vector2.INF
	near.sort_custom(func(x, y): return (x["pos"] as Vector2).distance_to(p) < (y["pos"] as Vector2).distance_to(p))
	return city.door_point(near[rr.randi() % mini(4, near.size())])


func _seat_now(e: Dictionary) -> void:
	e["state"] = "sit"
	e["yoff"] = e["yoff_to"]
	e["t"] = 0.0
	_put(e, e["p"], float(e["yoff"]))
	(e["node"] as Node3D).rotation.y = float(e["yaw"])
	_pick(e)


func _put(e: Dictionary, p: Vector2, yoff: float) -> void:
	(e["node"] as Node3D).position = Vector3(p.x, game.land.height_at(p.x, p.y) + yoff, p.y)


## Встать и уйти домой (или растаять, если идти некуда)
func _leave(e: Dictionary) -> void:
	match String(e["state"]):
		"sit", "enter":
			e["state"] = "exit"
			e["t"] = 1.03
			(e["node"] as Citizen).play("Sitting_Exit", 0.3)
		"in":
			_go_home(e)


func _go_home(e: Dictionary) -> void:
	_free_seat(e)
	var from: Vector2 = e.get("from", Vector2.INF)
	var here := Vector2((e["node"] as Node3D).position.x, (e["node"] as Node3D).position.z)
	var path: PackedVector2Array = PackedVector2Array() if from == Vector2.INF else game.people._path(here, from)
	if path.size() < 2:
		e["state"] = "gone"
		e["t"] = 0.8
		return
	e["path"] = path
	e["i"] = 0
	e["state"] = "out"
	(e["node"] as Citizen).play("Walk", 0.3)


func _free_seat(e: Dictionary) -> void:
	if int(e["k"]) < 0:
		return
	var sp: Dictionary = game.people.spots.get(int(e["bid"]), {})
	if int(sp.get(int(e["k"]), 0)) == MARK:
		sp.erase(int(e["k"]))


## Сидит: рядом на той же скамье другой старик — болтают по очереди (чуть повернувшись друг к другу); за доской —
## думают и говорят; один — сидит, смотрит
func _pick(e: Dictionary) -> void:
	var c := e["node"] as Citizen
	e["t"] = randf_range(3.0, 6.5)
	if e.get("table", false):
		c.play(["Sitting_Idle", "Sitting_Talking", "Sitting_Idle_M", "Sitting_Talking_M"][randi() % 4], 0.4)
		return
	var nb := {}
	for key in elders:
		var o: Dictionary = elders[key]
		if o != e and int(o["bid"]) == int(e["bid"]) and o["state"] == "sit":
			nb = o
	var base := float(e["yaw"])
	if nb.is_empty():
		(e["node"] as Node3D).rotation.y = base
		c.play(["Sitting_Idle", "Sitting_Idle_M"][randi() % 2], 0.4)
		return
	var side := City.axis(base)
	var turn := 0.35 if side.dot((nb["p"] as Vector2) - (e["p"] as Vector2)) > 0.0 else -0.35
	(e["node"] as Node3D).rotation.y = base - turn
	var talking := String((nb["node"] as Citizen)._cur).begins_with("Sitting_Talking")
	c.play("Sitting_Idle" if talking else ("Sitting_Talking" if randf() < 0.5 else "Sitting_Talking_M"), 0.4)


func _step(key: String, e: Dictionary, sdt: float, dt: float) -> void:
	var c = e["node"]
	if c == null or not is_instance_valid(c):
		_free_seat(e)
		elders.erase(key)
		return
	var n := c as Citizen
	if e.has("fade") and float(e["fade"]) < 1.0:
		e["fade"] = minf(1.0, float(e["fade"]) + dt / 1.2)   # проявляется и на паузе (ролик, загрузка)
		n.set_alpha(float(e["fade"]))
	match String(e["state"]):
		"in", "out":
			if _walk(e, sdt):
				if e["state"] == "in":
					e["state"] = "enter"
					e["t"] = 1.3
					n.rotation.y = float(e["yaw"])
					n.play("Sitting_Enter", 0.3)
				else:
					e["state"] = "gone"
					e["t"] = 0.8
		"enter":
			e["t"] = float(e["t"]) - sdt
			e["yoff"] = move_toward(float(e["yoff"]), float(e["yoff_to"]), sdt * 0.12)
			_put(e, e["p"], float(e["yoff"]))
			if float(e["t"]) <= 0.0:
				e["state"] = "sit"
				_pick(e)
		"sit":
			e["t"] = float(e["t"]) - sdt
			if float(e["t"]) <= 0.0:
				_pick(e)
		"exit":
			e["t"] = float(e["t"]) - sdt
			e["yoff"] = move_toward(float(e["yoff"]), 0.0, sdt * 0.12)
			_put(e, e["p"], float(e["yoff"]))
			if float(e["t"]) <= 0.0:
				_go_home(e)
		"gone":
			e["t"] = float(e["t"]) - sdt
			n.set_alpha(clampf(float(e["t"]) / 0.8, 0.0, 1.0))
			if float(e["t"]) <= 0.0:
				_free_seat(e)
				n.queue_free()
				elders.erase(key)


## Шаг по пути; true — дошёл
func _walk(e: Dictionary, sdt: float) -> bool:
	var path: PackedVector2Array = e["path"]
	var i := int(e["i"])
	var n := e["node"] as Node3D
	var p := Vector2(n.position.x, n.position.z)
	var mv := WALK * sdt
	while i < path.size() and mv > 0.0:
		var to := path[i]
		var d := p.distance_to(to)
		if d <= mv:
			p = to
			mv -= d
			i += 1
		else:
			var dir := (to - p) / d
			p += dir * mv
			n.rotation.y = lerp_angle(n.rotation.y, atan2(dir.x, dir.y), 0.3)
			mv = 0.0
	e["i"] = i
	_put(e, p, 0.0)
	return i >= path.size()


func _on_removed(b: Dictionary) -> void:
	for key in elders.keys():
		var e: Dictionary = elders[key]
		if int(e["bid"]) == int(b["id"]):
			var n = e["node"]
			if n != null and is_instance_valid(n):
				(n as Node).queue_free()
			elders.erase(key)
	_t = minf(_t, 0.2)


## Убрать всех (меню, снимок, проверка)
func clear() -> void:
	for key in elders:
		var e: Dictionary = elders[key]
		_free_seat(e)
		var n = e["node"]
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
	elders = {}
	_instant = true


# ---------- «Школа гладиаторов»: на играх в честь богов чемпион школы выходит на площадь у станции ----------

var champ: LegionFighter = null          # чемпион на площади (пока идут игры)
var _champ_t := 0.0
var _champ_said := false                 # подпись «Чемпион школы…» — раз за игры


## Игры идут, школа гладиаторов открыта: чемпион (мирмиллон, ретиарий или фракиец — как выбрали) бьётся с невидимым
## соперником у станции, где собирается город, и ликует; кончились игры — уходит
func _champ_tick(dt: float) -> void:
	var e: Dictionary = (city.stories["done"] as Dictionary).get("gladiators", {})
	if e.is_empty() or city.fest_left <= 0 or st.busy():
		_champ_off()
		if city.fest_left <= 0:
			_champ_said = false
		return
	if champ == null or not is_instance_valid(champ):
		var ctr := city.center()
		if ctr.is_empty():
			return
		var f := City.facing(float(ctr["yaw"]))
		var p: Vector2 = st._open_spot(city.door_point(ctr) + f * 7.5 + Vector2(f.y, -f.x) * 3.0)
		champ = Stories.gladiator(String((e.get("flags", {}) as Dictionary).get("champ", "murmillo")), 21)
		game.add_child(champ)
		champ.position = Vector3(p.x, game.land.height_at(p.x, p.y), p.y)
		champ.rotation.y = atan2(f.x, f.y)
		_champ_t = 1.0
		if not _champ_said:
			_champ_said = true
			st.ui.bubble3d(champ.position + Vector3(0, 2.3, 0), "Чемпион школы гладиаторов!", 3.5, 28)
	champ.tick(dt)
	_champ_t -= dt * maxf(0.0, float(game.speed))
	if _champ_t <= 0.0:
		_champ_t = randf_range(1.6, 3.2)
		if randf() < 0.75:
			champ.attack()
		else:
			champ.cheer()


func _champ_off() -> void:
	if champ != null and is_instance_valid(champ):
		champ.queue_free()
	champ = null
