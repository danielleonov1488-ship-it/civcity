class_name People
extends Node3D
## Жители на улицах: ходят только по мостовой, площадям и тропам (сетка проходимости и поиск пути),
## не проходят сквозь друг друга, гуляют, болтают, заходят домой. Переселенцы приезжают на повозке
## из ворот в скале к центру города и сами идут в свои дома — дом заселяется, когда семья дошла.

var land: Land
var city: City
var grid := AStarGrid2D.new()
var walkers := []
var rng := RandomNumberGenerator.new()
var cart := {}
var _spawn_t := 0.0
var max_walkers := 46

const RADIUS := 0.3
const CART_HORSE_Z := 2.05
const CART_SEAT_Y := 0.3


const G := 2                          # клетка сетки ходьбы — 2×2 клетки земли (50 см)
const GN := Land.N / G


func setup(l: Land, c: City) -> void:
	land = l
	city = c
	rng.seed = 21
	grid.region = Rect2i(0, 0, GN, GN)
	grid.cell_size = Vector2(Land.CELL * G, Land.CELL * G)
	grid.offset = Vector2(Land.CELL * G, Land.CELL * G) * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for j in GN:
		for i in GN:
			grid.set_point_solid(Vector2i(i, j), not _walk_g(i, j))
	_make_cart()


## Клетка ходьбы проходима, если хотя бы половина её земли — дорога без построек
func _walk_g(gi: int, gj: int) -> bool:
	var n := 0
	for dj in G:
		for di in G:
			var k := land.idx(gi * G + di, gj * G + dj)
			if Land.walk_kind(land.kind[k]) and land.occ[k] == 0:
				n += 1
	return n * 2 >= G * G


## Земля поменялась в кусках chunks — обновить проходимость
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
	var out := PackedVector2Array([fa])
	var i := 0
	while i < raw.size() - 1:
		var j := mini(raw.size() - 1, i + 40)
		while j > i + 1 and not _clear(out[out.size() - 1], raw[j]):
			j -= 1
		out.append(raw[j])
		i = j
	out.append(b)
	return out


func _clear(a: Vector2, b: Vector2) -> bool:
	var n := int(a.distance_to(b) / 0.2) + 1
	for k in range(1, n):
		if not _free(a.lerp(b, float(k) / n)):
			return false
	return true


# ---------- жители ----------

func _spawn(at: Vector2, female: bool, rich := false, child := false) -> Dictionary:
	var c := Citizen.create(rng, female, child, rich)
	add_child(c)
	var w := {"c": c, "p": at, "yaw": rng.randf() * TAU, "path": PackedVector2Array(), "i": 0, "state": "idle", "t": 0.0,
		"home": -1, "settle": -1, "n": 0, "after": "", "face": Vector2.ZERO, "speed": rng.randf_range(1.0, 1.25)}
	walkers.append(w)
	_place(w)
	return w


func _lived_houses() -> Array:
	var out := []
	for id in city.buildings:
		var h: Dictionary = city.buildings[id]
		if Defs.B[h["type"]]["kind"] == "house" and int(h["pop"]) > 0:
			out.append(h)
	return out


## Сразу населить улицы (готовый город, загрузка): n гуляющих
func prespawn(n: int) -> void:
	for k in n:
		_spawn_wanderer()
		if not walkers.is_empty():
			var w: Dictionary = walkers[walkers.size() - 1]
			var q := _random_road_near(w["p"], 12.0)
			w["p"] = q
			_place(w)
			_next(w)


func _spawn_wanderer() -> void:
	var lived := _lived_houses()
	if lived.is_empty():
		return
	var h: Dictionary = lived[rng.randi() % lived.size()]
	var at := _near_free(city.door_point(h))
	if at == Vector2.INF:
		return
	var rich: bool = h["type"] == "house_patrician"
	var w := _spawn(at, rng.randf() < 0.5, rich, rng.randf() < 0.15)
	w["home"] = h["id"]
	_next(w)


func _random_road_near(p: Vector2, r: float) -> Vector2:
	for k in 30:
		var q := p + Vector2(rng.randf_range(-r, r), rng.randf_range(-r, r))
		if _free(q):
			return q
	return p


func _go(w: Dictionary, to: Vector2, after: String) -> void:
	w["path"] = _path(w["p"], to)
	w["i"] = 1
	w["after"] = after
	if w["path"].size() > 1:
		w["state"] = "walk"
		(w["c"] as Citizen).play("Walk_Loop")
	else:
		w["state"] = "idle"
		w["t"] = 1.0
		if after == "settle":
			_arrive(w)


func _next(w: Dictionary) -> void:
	var r := rng.randf()
	if r < 0.55:
		_go(w, _random_road_near(w["p"], 14.0), "idle" if rng.randf() < 0.6 else "talk")
	elif w["home"] >= 0 and city.buildings.has(w["home"]):
		_go(w, city.door_point(city.buildings[w["home"]]), "home")
	else:
		_go(w, _random_road_near(w["p"], 10.0), "idle")


func _arrive(w: Dictionary) -> void:
	var c: Citizen = w["c"]
	match w["after"]:
		"idle":
			w["state"] = "idle"
			w["t"] = rng.randf_range(2.0, 5.0)
			c.play("Idle_Loop")
		"talk":
			w["state"] = "idle"
			w["t"] = rng.randf_range(4.0, 8.0)
			c.play("Idle_Talking_Loop")
			for o in walkers:
				if o != w and o["state"] == "idle" and (o["p"] as Vector2).distance_to(w["p"]) < 2.5:
					w["face"] = ((o["p"] as Vector2) - (w["p"] as Vector2)).normalized()
					o["face"] = -w["face"]
					(o["c"] as Citizen).play("Idle_Talking_Loop")
					break
		"home":
			_remove(w)
		"settle":
			var hid: int = w["settle"]
			if city.buildings.has(hid):
				var h: Dictionary = city.buildings[hid]
				h["coming"] = maxi(0, int(h.get("coming", 0)) - int(w["n"]))
				if int(w["n"]) > 0:
					city.settled(hid, int(w["n"]))
					_float_text(city.door_point(h), "+ семья")
			_remove(w)


func _remove(w: Dictionary) -> void:
	(w["c"] as Node).queue_free()
	walkers.erase(w)


func _process(dt: float) -> void:
	if city == null or land == null:
		return
	dt = minf(dt, 0.05)
	var speed: float = get_meta("speed", 1.0)
	if speed <= 0.0:
		for w in walkers:
			(w["c"] as Citizen).anim.speed_scale = 0.0
		return
	_spawn_t -= dt * speed
	if _spawn_t <= 0.0:
		_spawn_t = 1.5
		var wanderers := walkers.filter(func(x): return x["settle"] < 0).size()
		if wanderers < mini(max_walkers, 4 + int(city.stats["pop"]) / 4):
			_spawn_wanderer()
	for w in walkers.duplicate():
		(w["c"] as Citizen).anim.speed_scale = speed
		_step(w, dt * speed)
	_cart_step(dt * speed)


func _step(w: Dictionary, dt: float) -> void:
	var st: String = w["state"]
	if st == "walk":
		var path: PackedVector2Array = w["path"]
		var i: int = w["i"]
		if i >= path.size():
			_arrive(w)
			return
		var p: Vector2 = w["p"]
		var to := path[i] - p
		var dist := to.length()
		if dist < 0.25:
			w["i"] = i + 1
			return
		var dir := to / dist
		var push := Vector2.ZERO
		for o in walkers:
			if o == w:
				continue
			var d := p - (o["p"] as Vector2)
			var l := d.length()
			if l < RADIUS * 2.0 and l > 0.001:
				push += d / l * (RADIUS * 2.0 - l)
				if o["state"] == "walk":
					push += Vector2(-dir.y, dir.x) * -0.15
		var mv := (dir * float(w["speed"]) + push * 2.5) * dt
		var np := p + mv
		if not _free(np):
			np = p + dir * float(w["speed"]) * dt
		w["p"] = np
		w["yaw"] = lerp_angle(float(w["yaw"]), atan2(dir.x, dir.y), minf(1.0, dt * 8.0))
	else:
		w["t"] = float(w["t"]) - dt
		var f: Vector2 = w["face"]
		if f != Vector2.ZERO:
			w["yaw"] = lerp_angle(float(w["yaw"]), atan2(f.x, f.y), minf(1.0, dt * 4.0))
		for o in walkers:
			if o != w:
				var d: Vector2 = (w["p"] as Vector2) - (o["p"] as Vector2)
				var l := d.length()
				if l < RADIUS * 1.8 and l > 0.001:
					var np: Vector2 = (w["p"] as Vector2) + d / l * (RADIUS * 1.8 - l) * 0.5
					if _free(np):
						w["p"] = np
		if float(w["t"]) <= 0.0:
			_next(w)
			return
	_place(w)


func _place(w: Dictionary) -> void:
	var c: Citizen = w["c"]
	var p: Vector2 = w["p"]
	c.position = Vector3(p.x, land.height_at(p.x, p.y), p.y)
	c.rotation.y = float(w["yaw"])


func _float_text(p: Vector2, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 52
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
	# переселенцы едут в кузове, на мешках
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
			if float(c["t"]) <= 0.0 and not city.settle_queue.is_empty() and not city.center().is_empty():
				# собрать до трёх семей и ехать от ворот к центру
				var cen := city.center()
				var to := city.door_point(cen)
				c["path"] = _path(Land.TUNNEL + Vector2(0, 0.8), to)
				if c["path"].size() < 2:
					c["t"] = 4.0
					return
				c["load"] = []
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
			c["s"] = float(c["s"]) + 2.2 * dt
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


## Семьи выходят из повозки и идут к своим домам
func _drop() -> void:
	var n: Node3D = cart["n"]
	var base := Vector2(n.position.x, n.position.z)
	for q in cart["load"]:
		var hid: int = q[0]
		if not city.buildings.has(hid):
			continue
		var h: Dictionary = city.buildings[hid]
		var members := mini(int(q[1]), 2)
		for m in members:
			var at := _near_free(base + Vector2(rng.randf_range(-1.2, 1.2), rng.randf_range(-1.2, 1.2)))
			if at == Vector2.INF:
				at = base
			var w := _spawn(at, m == 1, h["type"] == "house_patrician")
			w["settle"] = hid
			w["n"] = int(q[1]) if m == 0 else 0
			_go(w, city.door_point(h), "settle")
	cart["load"] = []
	for r: Node3D in cart["riders"]:
		r.visible = false
