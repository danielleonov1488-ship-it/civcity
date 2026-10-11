class_name People
extends Node3D
## Жители — настоящие люди, как в Town to City: каждого жителя города видно, когда он на улице.
## Семьи приезжают на повозке из тоннеля, сходят на площадь у станции, потом идут в свой дом.
## Утром работники выходят из дома и идут на работу (встают за прилавок, к печи, в поле), вечером
## возвращаются домой; остальные ходят по лавкам и на площадь; ночью все спят дома, окна светятся.
## Если жилья нет — семьи ждут на площади. Кошки гуляют по улицам и спят у дверей.

var land: Land
var city: City
var game
var grid := AStarGrid2D.new()
var residents := []                  # все жители города
var by_id := {}
var next_rid := 1
var waiting_fams := []               # семьи без дома на площади: [{name, members: [rid]}]
var slots := {}                      # id постройки → [rid или 0 по местам работы]
var rng := RandomNumberGenerator.new()
var cart := {}
var cats := []
var visible_count := 0
var _tick := 0.0
var _jobs_dirty := true
var _hour := 8.0

const MAX_VIS := 150                 # больше людей на улице не рисуем (остальные идут «невидимо»)
const RADIUS := 0.3
const CART_HORSE_Z := 2.05
const CART_SEAT_Y := 0.3
const G := 2                         # клетка сетки ходьбы — 2×2 клетки земли (50 см)
const GN := Land.N / G
const WALK := 1.45                   # м/с при обычной скорости


func setup(l: Land, c: City, g) -> void:
	land = l
	city = c
	game = g
	rng.seed = 21
	grid.region = Rect2i(0, 0, GN, GN)
	grid.cell_size = Vector2(Land.CELL * G, Land.CELL * G)
	grid.offset = Vector2(Land.CELL * G, Land.CELL * G) * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	grid.fill_solid_region(grid.region, true)
	refresh(land.road_chunks.keys())
	_make_cart()
	city.building_removed.connect(_on_building_removed)
	city.changed.connect(func(): _jobs_dirty = true)
	city.family_left.connect(_on_family_left)
	# жители уже заселённых домов (загрузка, готовый город)
	for id in city.buildings:
		var b: Dictionary = city.buildings[id]
		if city.is_house(b):
			for f in b["families"]:
				_make_family(f["name"], int(f["n"]), id, city.door_point(b))
	_assign_jobs()
	_start_of_day(true)


# ---------- сетка ходьбы ----------

func _walk_g(gi: int, gj: int) -> bool:
	var n := 0
	for dj in G:
		for di in G:
			var k := land.idx(gi * G + di, gj * G + dj)
			if Land.walk_kind(land.kind[k]) and land.occ[k] == 0:
				n += 1
	return n * 2 >= G * G


func refresh(chunks: Array) -> void:
	var s := Land.CH / G
	for ch: Vector2i in chunks:
		for j in range(ch.y * s, ch.y * s + s):
			for i in range(ch.x * s, ch.x * s + s):
				grid.set_point_solid(Vector2i(i, j), not _walk_g(i, j))


func gcell(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x / (Land.CELL * G)), 0, GN - 1), clampi(int(p.y / (Land.CELL * G)), 0, GN - 1))


func _free(p: Vector2) -> bool:
	return not grid.is_point_solid(gcell(p))


func _near_free(p: Vector2, rmax := 14) -> Vector2:
	if _free(p):
		return p
	for r in range(1, rmax):
		for a in 12:
			var q := p + Vector2(cos(TAU * a / 12.0), sin(TAU * a / 12.0)) * r * Land.CELL * G * 0.5
			if _free(q):
				return q
	return Vector2.INF


func _path(a: Vector2, b: Vector2) -> PackedVector2Array:
	var fa := _near_free(a)
	var fb := _near_free(b)
	if fa == Vector2.INF or fb == Vector2.INF:
		return PackedVector2Array()
	var raw := grid.get_point_path(gcell(fa), gcell(fb))
	if raw.is_empty():
		return PackedVector2Array()
	var out := PackedVector2Array([a, fa])
	var i := 0
	while i < raw.size() - 1:
		var j := mini(raw.size() - 1, i + 30)
		while j > i + 1 and not _clear(out[out.size() - 1], raw[j]):
			j -= 1
		out.append(raw[j])
		i = j
	out.append(b)
	return out


func _clear(a: Vector2, b: Vector2) -> bool:
	var n := int(a.distance_to(b) / 0.25) + 1
	for k in range(1, n):
		if not _free(a.lerp(b, float(k) / n)):
			return false
	return true


# ---------- жители ----------

func _make_family(name: String, n: int, home: int, at: Vector2) -> Array:
	var out := []
	var house: Dictionary = city.buildings.get(home, {})
	var cls: String = city.def(house)["cls"] if not house.is_empty() else "plebs"
	for m in n:
		var child := m >= 2 and rng.randf() < 0.6
		var r := {"id": next_rid, "home": home, "fam": name, "female": m == 1 or (m > 1 and rng.randf() < 0.5), "child": child,
			"rich": cls == "patricians", "cls": cls, "job": -1, "state": "home", "p": at, "path": PackedVector2Array(), "i": 0,
			"node": null, "yaw": rng.randf() * TAU, "speed": rng.randf_range(0.92, 1.12) * (0.8 if child else 1.0), "goal": "",
			"t": 0.0, "slot": -1, "seed": rng.randi(), "dep": rng.randf_range(-0.6, 0.6), "ret": rng.randf_range(0.0, 1.2), "done_today": false}
		next_rid += 1
		residents.append(r)
		by_id[r["id"]] = r
		out.append(r)
	return out


func _node(r: Dictionary) -> Citizen:
	if r["node"] != null:
		return r["node"]
	if visible_count >= MAX_VIS:
		return null
	var rr := RandomNumberGenerator.new()
	rr.seed = int(r["seed"])
	var c := Citizen.create(rr, r["female"], r["child"], r["rich"])
	add_child(c)
	c.anim.speed_scale = maxf(0.01, game.speed)
	r["node"] = c
	visible_count += 1
	_place(r)
	return c


func _hide(r: Dictionary) -> void:
	if r["node"] != null:
		(r["node"] as Node).queue_free()
		r["node"] = null
		visible_count -= 1


func _place(r: Dictionary) -> void:
	var c: Citizen = r["node"]
	if c == null:
		return
	var p: Vector2 = r["p"]
	c.position = Vector3(p.x, land.height_at(p.x, p.y), p.y)
	c.rotation.y = float(r["yaw"])


## Начать прогулку к точке to; goal — что будет по приходу
func _go(r: Dictionary, to: Vector2, goal: String) -> void:
	_leave_slot(r)
	r["path"] = _path(r["p"], to)
	r["i"] = 1
	r["goal"] = goal
	if r["path"].size() < 2:
		r["p"] = to
		_arrive(r)
		return
	r["state"] = "walk"
	var c := _node(r)
	if c:
		c.play("Walk_Loop")


func _arrive(r: Dictionary) -> void:
	match r["goal"]:
		"home":
			r["state"] = "home"
			_hide(r)
		"work":
			_enter_work(r)
		"errand", "play", "stroll":
			r["state"] = "idle"
			r["t"] = rng.randf_range(0.8, 2.2) if r["goal"] == "errand" else rng.randf_range(0.6, 1.4)
			var c := _node(r)
			if c:
				c.play("Idle_Talking_Loop" if rng.randf() < 0.6 else "Idle_Loop")
		"plaza":
			# новосёлы стоят на площади у станции и осматриваются
			r["state"] = "idle"
			r["t"] = 0.35 if int(r["home"]) > 0 else 9999.0
			r["goal"] = "arrived"
			var c := _node(r)
			if c:
				c.play("Idle_Loop")
		"settle":
			r["state"] = "home"
			_hide(r)
			var h: Dictionary = city.buildings.get(r["home"], {})
			if not h.is_empty():
				var fam := _fam_members(r["fam"], r["home"])
				var all_in := true
				for m in fam:
					if m["state"] != "home":
						all_in = false
				if all_in and not h.has("_fam_" + str(r["fam"])):
					h["_fam_" + str(r["fam"])] = true
					h["coming"] = maxi(0, int(h.get("coming", 0)) - fam.size())
					var took := city.settled(r["home"], fam.size(), r["fam"])
					_float_text(city.door_point(h), "+ семья %s" % r["fam"])
					# кому не хватило места — уходят ждать на площадь
					for k in range(took, fam.size()):
						var m: Dictionary = fam[k]
						m["home"] = -1
						m["p"] = city.door_point(h)
						_go(m, _plaza_point(), "plaza")
					if took < fam.size():
						waiting_fams.append({"name": r["fam"], "members": fam.slice(took).map(func(x): return x["id"])})
		"leave":
			_remove(r)


func _fam_members(name: String, home: int) -> Array:
	return residents.filter(func(x): return x["fam"] == name and x["home"] == home)


func _remove(r: Dictionary) -> void:
	_leave_slot(r)
	_hide(r)
	residents.erase(r)
	by_id.erase(r["id"])


# ---------- работа ----------

## Раздать работу: на каждое рабочее место — ближайший взрослый житель нужного класса (или выше)
func _assign_jobs() -> void:
	_jobs_dirty = false
	var need := []
	for id in city.buildings:
		var b: Dictionary = city.buildings[id]
		var d := city.def(b)
		if not d.has("jobs") or city.is_house(b) or not b.get("road", true):
			continue
		for c in d["jobs"]:
			for k in int(d["jobs"][c]):
				need.append([id, c])
	var keep := {}
	for r in residents:
		if r["job"] >= 0:
			if not city.buildings.has(r["job"]) or r["child"] or int(r["home"]) <= 0:
				_quit_job(r)
			else:
				keep[r["job"]] = int(keep.get(r["job"], 0)) + 1
	var order := {"plebs": ["plebs", "artisans", "patricians"], "artisans": ["artisans", "patricians"], "patricians": ["patricians"]}
	var count := {}
	for nd in need:
		var bid: int = nd[0]
		count[bid] = int(count.get(bid, 0)) + 1
		if int(keep.get(bid, 0)) >= int(count[bid]):
			continue
		var bp: Vector2 = city.buildings[bid]["pos"]
		var best := {}
		var bd := INF
		for cl in order[nd[1]]:
			for r in residents:
				if r["job"] >= 0 or r["child"] or int(r["home"]) <= 0 or r["cls"] != cl:
					continue
				var dd := (r["p"] as Vector2).distance_squared_to(bp)
				if dd < bd:
					bd = dd
					best = r
			if not best.is_empty():
				break
		if best.is_empty():
			continue
		best["job"] = bid
		keep[bid] = int(keep.get(bid, 0)) + 1


func _quit_job(r: Dictionary) -> void:
	_leave_slot(r)
	r["job"] = -1
	if r["state"] == "work":
		r["state"] = "idle"
		r["t"] = 0.0
		r["goal"] = "errand"


func _enter_work(r: Dictionary) -> void:
	var b: Dictionary = city.buildings.get(r["job"], {})
	if b.is_empty():
		r["state"] = "idle"
		r["t"] = 0.0
		return
	r["state"] = "work"
	var bp := city.blueprint(b)
	var list: Array = slots.get(b["id"], [])
	list.resize(bp.actors.size())
	var free := -1
	for k in list.size():
		if list[k] == null or int(list[k]) == 0:
			free = k
			break
	if free < 0:
		_hide(r)                         # внутри мастерской
		return
	list[free] = r["id"]
	slots[b["id"]] = list
	r["slot"] = free
	var a: Array = bp.actors[free]
	var c := _node(r)
	if c:
		var xf: Transform3D = city.xf(b) * Transform3D(Basis(Vector3.UP, float(a[1])), a[0])
		c.transform = xf
		r["p"] = Vector2(xf.origin.x, xf.origin.z)
		c.play(a[2], 0.3)


func _leave_slot(r: Dictionary) -> void:
	if int(r["slot"]) < 0:
		return
	var list: Array = slots.get(r["job"], [])
	if int(r["slot"]) < list.size():
		list[r["slot"]] = 0
	r["slot"] = -1


func work_door(r: Dictionary) -> Vector2:
	var b: Dictionary = city.buildings.get(r["job"], {})
	if b.is_empty():
		return r["p"]
	var bp := city.blueprint(b)
	if bp.actors.size() > 0:
		var a: Array = bp.actors[0]
		var p3: Vector3 = city.xf(b) * (a[0] as Vector3)
		var q := Vector2(p3.x, p3.z)
		if _free(q):
			return q
	return city.door_point(b)


# ---------- распорядок дня ----------

## В начале игры и после загрузки: кто уже на работе, кто гуляет
func _start_of_day(instant: bool) -> void:
	var h: float = game.hour
	for r in residents:
		if int(r["home"]) <= 0:
			continue
		if r["job"] >= 0 and h >= 8.0 and h < 17.0:
			r["p"] = work_door(r)
			_enter_work(r)
		elif instant and h >= 9.0 and h < 18.0 and not r["child"] and rng.randf() < 0.25:
			var to := _errand_point(r)
			r["p"] = _near_free(to) if _near_free(to) != Vector2.INF else to
			r["goal"] = "errand"
			_arrive(r)


func _errand_point(r: Dictionary) -> Vector2:
	var h: Dictionary = city.buildings.get(r["home"], {})
	var opts := []
	if not h.is_empty():
		for t in h.get("score", {}):
			for id in city.buildings:
				var b: Dictionary = city.buildings[id]
				if b["type"] == t and (b["pos"] as Vector2).distance_to(h["pos"]) < 60.0:
					opts.append(city.door_point(b))
	for id in city.buildings:
		var b: Dictionary = city.buildings[id]
		if b["type"] in ["fountain", "temple", "forum"] or (city.def(b)["kind"] == "decor" and b["type"] in ["bench", "well", "statue"]):
			if not h.is_empty() and (b["pos"] as Vector2).distance_to(h["pos"]) < 70.0:
				opts.append(city.door_point(b) + Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5)))
	if opts.is_empty():
		var c := city.center()
		if not c.is_empty():
			return city.door_point(c) + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
		return r["p"]
	return opts[rng.randi() % opts.size()]


func _hours_to(a: Vector2, b: Vector2) -> float:
	var mph := WALK * Game.DAY_LEN / 24.0
	return a.distance_to(b) * 1.3 / mph


## Раз в четверть секунды: кому куда идти по часам
func _schedule(dh: float) -> void:
	var h: float = game.hour
	var night := h >= 21.5 or h < 5.0
	for r in residents.duplicate():
		match r["state"]:
			"home":
				if int(r["home"]) <= 0:
					continue
				if r["job"] >= 0:
					var b: Dictionary = city.buildings.get(r["job"], {})
					if b.is_empty():
						continue
					var dep := 8.0 - _hours_to(r["p"], work_door(r)) + float(r["dep"])
					if h >= dep and h < 16.5 and not r["done_today"]:
						r["done_today"] = true
						_go(r, work_door(r), "work")
				elif not night and h >= 8.5 and h < 19.0:
					var chance := 0.04 if r["child"] else 0.025
					if rng.randf() < chance * dh * 4.0 * 10.0:
						if r["child"]:
							_go(r, _near_road(r["p"], 9.0), "play")
						else:
							_go(r, _errand_point(r), "errand" if h < 18.0 else "stroll")
			"work":
				if h >= 17.0 + float(r["ret"]) or h < 6.0:
					var hp: Dictionary = city.buildings.get(r["home"], {})
					if hp.is_empty():
						continue
					if rng.randf() < 0.3 and h < 19.0:
						_go(r, _errand_point(r), "errand")
					else:
						_go(r, city.door_point(hp), "home")
			"idle":
				r["t"] = float(r["t"]) - dh
				if r["goal"] == "arrived":
					if float(r["t"]) <= 0.0 and int(r["home"]) > 0:
						var hb: Dictionary = city.buildings.get(r["home"], {})
						if hb.is_empty():
							r["home"] = -1
						else:
							_go(r, city.door_point(hb), "settle")
					continue
				if float(r["t"]) <= 0.0 or night:
					var hp: Dictionary = city.buildings.get(r["home"], {})
					if hp.is_empty():
						continue
					_go(r, city.door_point(hp), "home")
	# новый день — снова можно на работу
	if h < _hour - 12.0:
		for r in residents:
			r["done_today"] = false
	_hour = h


func _near_road(p: Vector2, r: float) -> Vector2:
	for k in 24:
		var q := p + Vector2(rng.randf_range(-r, r), rng.randf_range(-r, r))
		if _free(q):
			return q
	return p


# ---------- кадр ----------

func _process(dt: float) -> void:
	if city == null or land == null:
		return
	dt = minf(dt, 0.05)
	var speed: float = game.speed
	_tick += dt
	if _tick >= 0.25:
		var dh: float = _tick * speed * 24.0 / Game.DAY_LEN
		_tick = 0.0
		if _jobs_dirty:
			_assign_jobs()
		if speed > 0.0:
			_schedule(dh)
			_settle_waiting()
	if speed <= 0.0:
		for r in residents:
			if r["node"] != null:
				(r["node"] as Citizen).anim.speed_scale = 0.0
		for c in cats:
			c["walk"] = 0.0
		return
	for r in residents:
		if r["state"] == "walk":
			_step(r, dt * speed)
		elif r["node"] != null:
			(r["node"] as Citizen).anim.speed_scale = speed
	_cart_step(dt * speed)
	_cats_step(dt * speed)


func _step(r: Dictionary, dt: float) -> void:
	var path: PackedVector2Array = r["path"]
	var i: int = r["i"]
	if i >= path.size():
		_arrive(r)
		return
	var c: Citizen = r["node"]
	if c == null and visible_count < MAX_VIS and (r["p"] as Vector2).distance_to(path[path.size() - 1]) > 3.0:
		c = _node(r)
		if c:
			c.play("Walk_Loop")
	if c:
		c.anim.speed_scale = game.speed * float(r["speed"])
	var p: Vector2 = r["p"]
	var to := path[i] - p
	var dist := to.length()
	var mv := WALK * float(r["speed"]) * dt
	while dist <= mv and i < path.size() - 1:
		p = path[i]
		mv -= dist
		i += 1
		to = path[i] - p
		dist = to.length()
	r["i"] = i
	if dist <= mv:
		r["p"] = path[path.size() - 1]
		r["i"] = path.size()
		_arrive(r)
		return
	var dir := to / dist
	r["p"] = p + dir * mv
	r["yaw"] = lerp_angle(float(r["yaw"]), atan2(dir.x, dir.y), minf(1.0, dt * 8.0))
	_place(r)


func _float_text(p: Vector2, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = game.hud.font_bold if game.hud else null
	l.font_size = 44
	l.outline_size = 12
	l.modulate = Color("ffe08a")
	l.outline_modulate = Color("5a3a1a")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.pixel_size = 0.008
	var y := land.height_at(p.x, p.y)
	l.position = Vector3(p.x, y + 2.6, p.y)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", y + 4.2, 2.6)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 2.6).set_delay(0.8)
	tw.tween_callback(l.queue_free)


# ---------- события города ----------

func _on_building_removed(b: Dictionary) -> void:
	slots.erase(b["id"])
	if city.def(b)["kind"] == "house":
		# жильцы снесённого дома выходят и ждут нового жилья на площади
		var fams := {}
		for r in residents:
			if r["home"] == b["id"]:
				r["home"] = -1
				fams[r["fam"]] = true
				r["p"] = city.door_point(b) if r["state"] == "home" else r["p"]
				_go(r, _plaza_point(), "plaza")
		for f in fams:
			waiting_fams.append({"name": f, "members": residents.filter(func(x): return x["fam"] == f and int(x["home"]) <= 0).map(func(x): return x["id"])})
	for r in residents:
		if r["job"] == b["id"]:
			_quit_job(r)
	_jobs_dirty = true
	city.waiting = waiting_fams.size()


func _on_family_left(home: int, name: String) -> void:
	var tun := Land.TUNNEL + Vector2(0, 1.0)
	for r in residents.duplicate():
		if r["fam"] == name and r["home"] == home:
			r["home"] = -2
			_quit_job(r)
			if r["state"] == "home":
				var h: Dictionary = city.buildings.get(home, {})
				r["p"] = city.door_point(h) if not h.is_empty() else r["p"]
			_go(r, tun, "leave")


func _plaza_point() -> Vector2:
	var c := city.center()
	if c.is_empty():
		return Land.CENTER
	var base := city.door_point(c)
	for k in 20:
		var q := base + Vector2(rng.randf_range(-3.5, 3.5), rng.randf_range(-4.5, 4.5))
		if _free(q):
			return q
	return base


## Семьи на площади занимают освободившиеся дома
func _settle_waiting() -> void:
	if waiting_fams.is_empty():
		return
	for f in waiting_fams.duplicate():
		var members: Array = f["members"].filter(func(id): return by_id.has(id))
		if members.is_empty():
			waiting_fams.erase(f)
			continue
		var house := _free_house(members.size())
		if house.is_empty():
			continue
		house["coming"] = int(house.get("coming", 0)) + members.size()
		for id in members:
			var r: Dictionary = by_id[id]
			r["home"] = house["id"]
			r["cls"] = city.def(house)["cls"]
			_go(r, city.door_point(house), "settle")
		waiting_fams.erase(f)
	city.waiting = waiting_fams.size()


func _free_house(n: int) -> Dictionary:
	var queued := {}
	for q in city.settle_queue:
		queued[q[0]] = int(queued.get(q[0], 0)) + int(q[1])
	for id in city.buildings:
		var b: Dictionary = city.buildings[id]
		if not city.is_house(b):
			continue
		var room := city.house_cap(b) - int(b["pop"]) - int(b.get("coming", 0)) - int(queued.get(id, 0))
		if room >= n:
			return b
	return {}


# ---------- повозка с переселенцами ----------

func _make_cart() -> void:
	var root := Node3D.new()
	root.add_child(Synty.make("SM_Prop_Cart_01"))
	root.add_child(Synty.make("SM_Prop_Cart_01_Insert_01"))
	var horse := (load("res://assets/animals/Horse_b.glb") as PackedScene).instantiate() as Node3D
	root.add_child(horse)
	var aabb := Artisau.aabb(horse)
	var s := 2.1 / maxf(aabb.size.z, aabb.size.x)
	horse.scale = Vector3.ONE * s
	horse.position = Vector3(0, 0, CART_HORSE_Z)
	var hanim: AnimationPlayer = horse.find_children("*", "AnimationPlayer", true, false)[0]
	var driver := Citizen.create(rng, false)
	root.add_child(driver)
	driver.position = Vector3(0, CART_SEAT_Y, 0.55)
	driver.play("Driving_Loop", 0.0)
	var riders := []
	for k in 3:
		var r := Citizen.create(rng, k != 1, k == 2)
		root.add_child(r)
		r.position = Vector3(-0.28 if k != 1 else 0.28, CART_SEAT_Y, -0.35 - 0.45 * (k % 2))
		r.rotation.y = PI / 2 if k != 1 else -PI / 2
		r.play("Sitting_Idle_Loop", 0.0)
		riders.append(r)
	add_child(root)
	root.visible = false
	cart = {"n": root, "horse": hanim, "path": PackedVector2Array(), "s": 0.0, "state": "wait", "t": 3.0, "load": [], "driver": driver, "riders": riders}


func _cart_path_len(path: PackedVector2Array) -> float:
	var t := 0.0
	for i in path.size() - 1:
		t += path[i].distance_to(path[i + 1])
	return t


func _cart_step(dt: float) -> void:
	if cart.is_empty():
		return
	var c := cart
	var n: Node3D = c["n"]
	match c["state"]:
		"wait":
			c["t"] = float(c["t"]) - dt
			if float(c["t"]) > 0.0 or city.center().is_empty():
				return
			var want_waiting := city.settle_queue.is_empty() and city.wants_waiting() and waiting_fams.size() < 3
			if city.settle_queue.is_empty() and not want_waiting:
				return
			var to := _plaza_point()
			c["path"] = _path(Land.TUNNEL + Vector2(0, 0.8), to)
			if c["path"].size() < 2:
				c["t"] = 4.0
				return
			c["load"] = []
			if want_waiting:
				c["load"].append([-1, rng.randi_range(2, 4)])
			for k in 3:
				if city.settle_queue.is_empty():
					break
				var q: Array = city.settle_queue.pop_front()
				if city.buildings.has(q[0]):
					var h: Dictionary = city.buildings[q[0]]
					h["coming"] = int(h.get("coming", 0)) + int(q[1])
					c["load"].append(q)
			if c["load"].is_empty():
				c["t"] = 3.0
				return
			c["state"] = "in"
			c["s"] = 0.0
			n.visible = true
			for r: Node3D in c["riders"]:
				r.visible = true
		"in", "out":
			var path: PackedVector2Array = c["path"]
			var total := _cart_path_len(path)
			c["s"] = float(c["s"]) + 2.4 * dt
			var s: float = c["s"] if c["state"] == "in" else total - float(c["s"])
			var p := path[0]
			var dir := Vector2(0, 1)
			var acc := 0.0
			for i in path.size() - 1:
				var l := path[i].distance_to(path[i + 1])
				if s <= acc + l or i == path.size() - 2:
					p = path[i].lerp(path[i + 1], clampf((s - acc) / maxf(l, 0.001), 0.0, 1.0))
					dir = (path[i + 1] - path[i]).normalized()
					break
				acc += l
			if c["state"] == "out":
				dir = -dir
			n.position = Vector3(p.x, land.height_at(p.x, p.y), p.y)
			n.rotation.y = lerp_angle(n.rotation.y, atan2(dir.x, dir.y), minf(1.0, dt * 4.0))
			_horse_anim(c["horse"], "Walk")
			if float(c["s"]) >= total:
				if c["state"] == "in":
					_drop()
					c["state"] = "unload"
					c["t"] = 3.0
				else:
					n.visible = false
					c["state"] = "wait"
					c["t"] = 4.0
		"unload":
			_horse_anim(c["horse"], "Idle")
			c["t"] = float(c["t"]) - dt
			if float(c["t"]) <= 0.0:
				c["state"] = "out"
				c["s"] = 0.0


func _horse_anim(ap: AnimationPlayer, name: String) -> void:
	for a in ap.get_animation_list():
		if a == name or a.ends_with("|" + name):
			if ap.current_animation != a:
				ap.play(a, 0.3)
			return


## Семьи сходят с повозки на площадь, стоят, осматриваются и идут в свои дома (или ждут жилья)
func _drop() -> void:
	var n: Node3D = cart["n"]
	var base := Vector2(n.position.x, n.position.z)
	for q in cart["load"]:
		var hid: int = q[0]
		var name: String = Defs.FAMILIES[rng.randi() % Defs.FAMILIES.size()]
		var fam := _make_family(name, int(q[1]), hid if city.buildings.has(hid) else -1, base)
		for r in fam:
			r["p"] = _near_free(base + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)))
			if r["p"] == Vector2.INF:
				r["p"] = base
			_go(r, _plaza_point(), "plaza")
		if hid < 0 or not city.buildings.has(hid):
			waiting_fams.append({"name": name, "members": fam.map(func(x): return x["id"])})
	cart["load"] = []
	for r: Node3D in cart["riders"]:
		r.visible = false
	city.waiting = waiting_fams.size()
	_jobs_dirty = true


# ---------- кошки ----------

static var _cat_parts := {}


static func _cat_mesh(fur: Color, belly: Color) -> Array:
	var key := fur.to_html() + belly.to_html()
	if _cat_parts.has(key):
		return _cat_parts[key]
	var body := Kit.new()
	body.blob(Vector3(0, 0.17, 0), Vector3(0.14, 0.13, 0.32), fur, 3, 0.06)
	body.blob(Vector3(0, 0.13, 0.03), Vector3(0.11, 0.08, 0.22), belly, 4, 0.05)
	var head := Kit.new()
	head.blob(Vector3(0, 0, 0), Vector3(0.12, 0.11, 0.11), fur, 5, 0.05)
	head.blob(Vector3(0, -0.02, 0.05), Vector3(0.07, 0.05, 0.05), belly, 6, 0.04)
	head.cone(Vector3(-0.04, 0.04, -0.005), 0.025, 0.05, 4, fur)
	head.cone(Vector3(0.04, 0.04, -0.005), 0.025, 0.05, 4, fur)
	head.boxc(Vector3(-0.025, 0.012, 0.055), Vector3(0.018, 0.015, 0.01), Color("2c3a1c"))
	head.boxc(Vector3(0.025, 0.012, 0.055), Vector3(0.018, 0.015, 0.01), Color("2c3a1c"))
	head.boxc(Vector3(0, -0.012, 0.062), Vector3(0.014, 0.01, 0.008), Color("d98a8a"))
	var tail := Kit.new()
	tail.rod(Vector3(0, 0, 0), Vector3(0, 0.1, -0.2), 0.022, 5, fur)
	tail.rod(Vector3(0, 0.1, -0.2), Vector3(0, 0.22, -0.24), 0.02, 5, fur)
	var leg := Kit.new()
	leg.rod(Vector3(0, 0, 0), Vector3(0, -0.11, 0), 0.022, 5, fur)
	var out := [body.mesh(), head.mesh(), tail.mesh(), leg.mesh()]
	_cat_parts[key] = out
	return out


func _make_cat(home: Dictionary) -> Dictionary:
	var furs := [[Color("e0913f"), Color("f6dcb4")], [Color("7d7a76"), Color("d9d4cc")], [Color("2c2724"), Color("4a423c")],
		[Color("f2ede4"), Color("ffffff")], [Color("a87447"), Color("efe0c8")], [Color("4a4440"), Color("f2ede4")]]
	var f: Array = furs[rng.randi() % furs.size()]
	var meshes := _cat_mesh(f[0], f[1])
	var mat := Kit.material(0.9)
	var root := Node3D.new()
	var mk := func(m: Mesh, pos: Vector3) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = mat
		mi.position = pos
		root.add_child(mi)
		return mi
	mk.call(meshes[0], Vector3.ZERO)
	var head: MeshInstance3D = mk.call(meshes[1], Vector3(0, 0.28, 0.3))
	var tail: MeshInstance3D = mk.call(meshes[2], Vector3(0, 0.22, -0.3))
	var legs := []
	for lp: Vector3 in [Vector3(-0.07, 0.12, 0.2), Vector3(0.07, 0.12, 0.2), Vector3(-0.07, 0.12, -0.2), Vector3(0.07, 0.12, -0.2)]:
		legs.append(mk.call(meshes[3], lp))
	var s := rng.randf_range(0.85, 1.05)
	root.scale = Vector3.ONE * s
	add_child(root)
	var p: Vector2 = _near_free(city.door_point(home))
	if p == Vector2.INF:
		p = city.door_point(home)
	var snd := AudioStreamPlayer3D.new()
	snd.max_distance = 30.0
	snd.unit_size = 4.0
	snd.volume_db = -8.0
	snd.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	root.add_child(snd)
	var cat := {"n": root, "head": head, "tail": tail, "legs": legs, "p": p, "path": PackedVector2Array(), "i": 0, "state": "sit", "t": rng.randf_range(2, 6),
		"home": home["id"], "yaw": rng.randf() * TAU, "walk": 0.0, "ph": rng.randf() * TAU, "snd": snd, "meow_t": rng.randf_range(10, 60)}
	_cat_place(cat)
	return cat


func _cat_place(c: Dictionary) -> void:
	var n: Node3D = c["n"]
	var p: Vector2 = c["p"]
	n.position = Vector3(p.x, land.height_at(p.x, p.y), p.y)
	n.rotation.y = float(c["yaw"])


func _cats_step(dt: float) -> void:
	var want := clampi(int(city.stats["pop"]) / 14, 0, 12)
	if cats.size() < want and rng.randf() < 0.02:
		var houses := city.buildings.values().filter(func(b): return city.is_house(b) and int(b["pop"]) > 0)
		if not houses.is_empty():
			cats.append(_make_cat(houses[rng.randi() % houses.size()]))
	var night: bool = game.hour >= 21.0 or game.hour < 6.0
	var t := Time.get_ticks_msec() / 1000.0
	for c in cats:
		var n: Node3D = c["n"]
		c["t"] = float(c["t"]) - dt
		match c["state"]:
			"walk":
				var path: PackedVector2Array = c["path"]
				var i: int = c["i"]
				if i >= path.size():
					c["state"] = "sleep" if night else "sit"
					c["t"] = rng.randf_range(4, 14)
				else:
					var to := path[i] - (c["p"] as Vector2)
					var d := to.length()
					var mv := 0.9 * dt
					if d <= mv:
						c["p"] = path[i]
						c["i"] = i + 1
					else:
						var dir := to / d
						c["p"] = (c["p"] as Vector2) + dir * mv
						c["yaw"] = lerp_angle(float(c["yaw"]), atan2(dir.x, dir.y), minf(1.0, dt * 8.0))
					c["walk"] = 1.0
			_:
				c["walk"] = 0.0
				if float(c["t"]) <= 0.0:
					var home: Dictionary = city.buildings.get(c["home"], {})
					var base: Vector2 = city.door_point(home) if not home.is_empty() else c["p"]
					var to: Vector2 = base if night else _near_road(base, 12.0)
					var path := _path(c["p"], to)
					if path.size() >= 2:
						c["path"] = path
						c["i"] = 1
						c["state"] = "walk"
					else:
						c["t"] = rng.randf_range(3, 8)
		_cat_place(c)
		# лапы, хвост, голова
		var w: float = c["walk"]
		var ph: float = c["ph"] + t * 9.0
		var legs: Array = c["legs"]
		for k in 4:
			(legs[k] as Node3D).rotation.x = sin(ph + (PI if k % 3 == 0 else 0.0)) * 0.6 * w
		(c["tail"] as Node3D).rotation.y = sin(t * 2.2 + float(c["ph"])) * 0.35
		var body_y := 0.0
		if c["state"] == "sit":
			body_y = -0.04
		elif c["state"] == "sleep":
			body_y = -0.09
		n.get_child(0).position.y = lerpf(n.get_child(0).position.y, body_y, minf(1.0, dt * 4.0))
		(c["head"] as Node3D).position.y = 0.28 + body_y * 1.6
		# изредка мяукает, если камера рядом
		c["meow_t"] = float(c["meow_t"]) - dt
		if float(c["meow_t"]) <= 0.0:
			c["meow_t"] = rng.randf_range(25, 90)
			if c["state"] != "sleep" and game.sound:
				game.sound.cat(c["snd"])
