class_name People
extends Node3D
## Жители города. Ходят только по мостовой и площади, в обход домов, прилавков, фонтана и друг друга
## (сетка проходимости и поиск пути AStarGrid2D, плюс расталкивание соседей на ходу).
## Гуляют, болтают парами, сидят на скамьях, стоят у прилавков, уходят домой.
## Новоселы: повозка выезжает из ворот в скале, высаживает семью у площади, они ждут, оглядываются
## и сами идут в свободный дом — дом оживает: идёт дым из трубы, над дверью «+ семья».

var terrain: Terrain
var houses := []
var footprints := []
var obstacles := []
var benches := []
var stall_spots := []

var grid := AStarGrid2D.new()
var walkers := []
var rng := RandomNumberGenerator.new()
var cart := {}
var bench_used := {}
var _spawn_t := 0.0

const SPEED := 1.05
const RADIUS := 0.32


func _ready() -> void:
	rng.seed = 12
	_build_grid()
	for h in houses:
		_set_lived(h, rng.randf() < 0.6, false)
	for i in 30:
		_spawn_wanderer(true)
	_make_cart()


# ---------- проходимость ----------

func _build_grid() -> void:
	grid.region = Rect2i(0, 0, Terrain.N, Terrain.N)
	grid.cell_size = Vector2(Terrain.CELL, Terrain.CELL)
	grid.offset = Vector2(Terrain.CELL, Terrain.CELL) * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for j in Terrain.N:
		for i in Terrain.N:
			var kd: int = terrain.kind[terrain.idx(i, j)]
			if kd != Terrain.Kind.COBBLE and kd != Terrain.Kind.PLAZA:
				grid.set_point_solid(Vector2i(i, j), true)
	# дома и препятствия — только клетки в их пределах
	for f in footprints:
		var c: Vector2 = f["c"]
		var r: float = float(f["hw"]) + float(f["hd"])
		for j in range(int((c.y - r) / Terrain.CELL), int((c.y + r) / Terrain.CELL) + 1):
			for i in range(int((c.x - r) / Terrain.CELL), int((c.x + r) / Terrain.CELL) + 1):
				if terrain.inside(i, j) and not _walkable_cell(i, j):
					grid.set_point_solid(Vector2i(i, j), true)
	for o in obstacles:
		var c: Vector2 = o[0]
		var r: float = o[1]
		for j in range(int((c.y - r) / Terrain.CELL), int((c.y + r) / Terrain.CELL) + 1):
			for i in range(int((c.x - r) / Terrain.CELL), int((c.x + r) / Terrain.CELL) + 1):
				if terrain.inside(i, j) and Vector2((i + 0.5) * Terrain.CELL, (j + 0.5) * Terrain.CELL).distance_to(c) < r:
					grid.set_point_solid(Vector2i(i, j), true)


func _walkable_cell(i: int, j: int) -> bool:
	var k := terrain.idx(i, j)
	var kd: int = terrain.kind[k]
	if kd != Terrain.Kind.COBBLE and kd != Terrain.Kind.PLAZA:
		return false
	var p := Vector2((i + 0.5) * Terrain.CELL, (j + 0.5) * Terrain.CELL)
	for f in footprints:
		var q: Vector2 = p - (f["c"] as Vector2)
		var ax: Vector2 = f["ax"]
		var az := Vector2(-ax.y, ax.x)
		if absf(q.dot(ax)) < float(f["hw"]) - 0.05 and absf(q.dot(az)) < float(f["hd"]) - 0.2:
			return false
	for o in obstacles:
		if p.distance_to(o[0]) < float(o[1]):
			return false
	return true


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x / Terrain.CELL), 0, Terrain.N - 1), clampi(int(p.y / Terrain.CELL), 0, Terrain.N - 1))


func _free(p: Vector2) -> bool:
	var c := _cell(p)
	return not grid.is_point_solid(c)


## Ближайшая проходимая клетка к точке (по спирали)
func _near_free(p: Vector2) -> Vector2:
	if _free(p):
		return p
	for r in range(1, 12):
		for a in 16:
			var q := p + Vector2(cos(TAU * a / 16.0), sin(TAU * a / 16.0)) * r * Terrain.CELL
			if _free(q):
				return q
	return p


## Путь по мостовой от a до b, спрямлённый там, где видно напрямую
func _path(a: Vector2, b: Vector2) -> PackedVector2Array:
	var ca := _cell(_near_free(a))
	var cb := _cell(_near_free(b))
	var raw := grid.get_point_path(ca, cb)
	if raw.is_empty():
		return PackedVector2Array()
	var out := PackedVector2Array([a])
	var i := 0
	while i < raw.size() - 1:
		var j := raw.size() - 1
		while j > i + 1 and not _clear(out[out.size() - 1], raw[j]):
			j -= 1
		out.append(raw[j])
		i = j
	out.append(b)
	return out


func _clear(a: Vector2, b: Vector2) -> bool:
	var n := int(a.distance_to(b) / 0.15) + 1
	for k in range(1, n):
		if not _free(a.lerp(b, float(k) / n)):
			return false
	return true


# ---------- жители ----------

func _spawn(at: Vector2, female: bool) -> Dictionary:
	var c := Citizen.create(rng, female, rng.randf() < 0.15)
	add_child(c)
	var w := {"c": c, "p": at, "yaw": rng.randf() * TAU, "path": PackedVector2Array(), "i": 0, "state": "idle", "t": 0.0,
		"home": null, "settler": false, "after": "", "face": Vector2.ZERO, "speed": SPEED * rng.randf_range(0.9, 1.1)}
	walkers.append(w)
	_place(w)
	return w


func _spawn_wanderer(anywhere := false) -> void:
	var lived := houses.filter(func(h): return h["lived"])
	if lived.is_empty():
		return
	var h: Dictionary = lived[rng.randi() % lived.size()]
	var at := Vector2(h["door"].x, h["door"].z)
	if anywhere:
		at = _random_spot()
	var w := _spawn(_near_free(at), rng.randf() < 0.5)
	w["home"] = h
	_next(w)


func _random_spot() -> Vector2:
	for k in 40:
		var p := Terrain.PLAZA_C + Vector2(rng.randf_range(-9, 9), rng.randf_range(-9, 9))
		if rng.randf() < 0.35:
			var r: Dictionary = terrain.roads[rng.randi() % terrain.roads.size()]
			var pts: Array = r["pts"]
			var s := rng.randi() % (pts.size() - 1)
			p = (pts[s] as Vector2).lerp(pts[s + 1], rng.randf())
		if _free(p):
			return p
	return Terrain.PLAZA_C + Vector2(0, 4)


func _go(w: Dictionary, to: Vector2, after: String) -> void:
	w["path"] = _path(w["p"], to)
	w["i"] = 1
	w["after"] = after
	w["state"] = "walk" if w["path"].size() > 1 else "idle"
	w["t"] = 2.0
	(w["c"] as Citizen).play("Walk_Loop")


## Чем заняться дальше
func _next(w: Dictionary) -> void:
	var r := rng.randf()
	var c: Citizen = w["c"]
	if r < 0.3:
		_go(w, _random_spot(), "idle")
	elif r < 0.5 and not stall_spots.is_empty():
		var s: Array = stall_spots[rng.randi() % stall_spots.size()]
		w["face"] = s[1]
		_go(w, (s[0] as Vector2) + Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.3, 0.3)), "shop")
	elif r < 0.66 and not benches.is_empty():
		var bi := rng.randi() % benches.size()
		if not bench_used.get(bi, false):
			bench_used[bi] = true
			w["bench"] = bi
			var b: Array = benches[bi]
			w["face"] = b[1]
			_go(w, (b[0] as Vector2) + (b[1] as Vector2) * 0.75, "sit")
		else:
			_go(w, _random_spot(), "idle")
	elif r < 0.82:
		_go(w, _random_spot(), "talk")
	elif w["home"] != null:
		var h: Dictionary = w["home"]
		_go(w, Vector2(h["door"].x, h["door"].z), "home")
	else:
		c.play("Idle_Loop")
		w["state"] = "idle"
		w["t"] = rng.randf_range(2, 5)


func _arrive(w: Dictionary) -> void:
	var c: Citizen = w["c"]
	match w["after"]:
		"idle":
			w["state"] = "idle"
			w["t"] = rng.randf_range(2.0, 6.0)
			c.play("Idle_Loop")
		"talk":
			w["state"] = "idle"
			w["t"] = rng.randf_range(4.0, 9.0)
			c.play("Idle_Talking_Loop")
			# собеседник: ближайший стоящий — поворачиваются друг к другу
			for o in walkers:
				if o != w and o["state"] == "idle" and (o["p"] as Vector2).distance_to(w["p"]) < 2.5:
					w["face"] = ((o["p"] as Vector2) - (w["p"] as Vector2)).normalized()
					o["face"] = -w["face"]
					(o["c"] as Citizen).play("Idle_Talking_Loop")
					break
		"shop":
			w["state"] = "idle"
			w["t"] = rng.randf_range(3.0, 7.0)
			c.play("Idle_Loop" if rng.randf() < 0.5 else "Interact")
		"sit":
			var b: Array = benches[w["bench"]]
			w["p"] = (b[0] as Vector2) + (b[1] as Vector2) * 0.12
			w["state"] = "sit"
			w["t"] = rng.randf_range(8.0, 16.0)
			c.play("Sitting_Idle_Loop" if rng.randf() < 0.5 else "Sitting_Talking_Loop")
		"home":
			_remove(w)
		"square":
			# новосёлы ждут на площади, оглядываются
			w["state"] = "wait"
			w["t"] = rng.randf_range(4.0, 7.0)
			w["face"] = ((Terrain.PLAZA_C) - (w["p"] as Vector2)).normalized()
			c.play("Idle_Loop")
		"settle":
			var h: Dictionary = w["home"]
			_set_lived(h, true, true)
			_remove(w)


func _remove(w: Dictionary) -> void:
	if w.has("bench"):
		bench_used.erase(w["bench"])
	(w["c"] as Node).queue_free()
	walkers.erase(w)


func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	# новые прохожие выходят из домов, пока жителей немного
	_spawn_t -= dt
	if _spawn_t <= 0.0:
		_spawn_t = 3.0
		if walkers.size() < 34:
			_spawn_wanderer()
	for w in walkers.duplicate():
		_step(w, dt)
	_cart_step(dt)


func _step(w: Dictionary, dt: float) -> void:
	var c: Citizen = w["c"]
	var st: String = w["state"]
	if st == "walk":
		var path: PackedVector2Array = w["path"]
		var i: int = w["i"]
		if i >= path.size():
			_arrive(w)
			return
		var p: Vector2 = w["p"]
		var tgt := path[i]
		var to := tgt - p
		var dist := to.length()
		if dist < 0.25:
			w["i"] = i + 1
			return
		var dir := to / dist
		# расталкивание: не проходить сквозь соседей
		var push := Vector2.ZERO
		for o in walkers:
			if o == w:
				continue
			var d := p - (o["p"] as Vector2)
			var l := d.length()
			if l < RADIUS * 2.0 and l > 0.001:
				push += d / l * (RADIUS * 2.0 - l)
				# идут навстречу — оба берут правее
				if o["state"] == "walk":
					push += Vector2(-dir.y, dir.x) * -0.15
		var mv := (dir * float(w["speed"]) + push * 2.5) * dt
		var np := p + mv
		if not _free(np):
			np = p + Vector2(mv.x, 0)
			if not _free(np):
				np = p + Vector2(0, mv.y)
				if not _free(np):
					np = p + dir * float(w["speed"]) * dt     # толкаться некуда — просто по пути
		w["p"] = np
		var want := atan2(dir.x, dir.y)
		w["yaw"] = lerp_angle(float(w["yaw"]), want, minf(1.0, dt * 8.0))
		w["t"] = float(w["t"]) - dt
	else:
		w["t"] = float(w["t"]) - dt
		var f: Vector2 = w["face"]
		if f != Vector2.ZERO:
			w["yaw"] = lerp_angle(float(w["yaw"]), atan2(f.x, f.y), minf(1.0, dt * 4.0))
		# стоящих тоже слегка расталкивают, чтобы не стояли друг в друге
		if st != "sit":
			for o in walkers:
				if o != w and o["state"] != "sit":
					var d: Vector2 = (w["p"] as Vector2) - (o["p"] as Vector2)
					var l := d.length()
					if l < RADIUS * 1.8 and l > 0.001:
						var np: Vector2 = (w["p"] as Vector2) + d / l * (RADIUS * 1.8 - l) * 0.5
						if _free(np):
							w["p"] = np
		if float(w["t"]) <= 0.0:
			if st == "sit":
				bench_used.erase(w["bench"])
				w.erase("bench")
			if st == "wait":
				_settle(w)
			else:
				_next(w)
			return
	_place(w)


func _place(w: Dictionary) -> void:
	var c: Citizen = w["c"]
	var p: Vector2 = w["p"]
	c.position = Vector3(p.x, terrain.height_at(p.x, p.y), p.y)
	c.rotation.y = float(w["yaw"])


# ---------- дома и заселение ----------

func _set_lived(h: Dictionary, on: bool, show: bool) -> void:
	h["lived"] = on
	for s in h["smoke"]:
		(s as GPUParticles3D).emitting = on
	if h.has("sign"):
		(h["sign"] as Node).queue_free()
		h.erase("sign")
	var door: Vector3 = h["door"]
	if not on:
		# над пустым домом — табличка «Свободно»
		var l := Label3D.new()
		l.text = "Свободно"
		l.font_size = 64
		l.outline_size = 16
		l.modulate = Color("fff6dc")
		l.outline_modulate = Color("6a4a2a")
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = false
		l.pixel_size = 0.009
		l.position = door + Vector3(0, 3.6, 0)
		add_child(l)
		h["sign"] = l
	elif show:
		var l := Label3D.new()
		l.text = "+ семья"
		l.font_size = 48
		l.outline_size = 12
		l.modulate = Color("ffe08a")
		l.outline_modulate = Color("5a3a1a")
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.pixel_size = 0.007
		l.position = door + Vector3(0, 2.8, 0)
		add_child(l)
		var tw := create_tween()
		tw.tween_property(l, "position:y", door.y + 4.2, 2.6)
		tw.parallel().tween_property(l, "modulate:a", 0.0, 2.6).set_delay(0.8)
		tw.tween_callback(l.queue_free)


## Новосёл, постояв на площади, идёт в свободный дом (сам, без игрока)
func _settle(w: Dictionary) -> void:
	var free := houses.filter(func(h): return not h["lived"] and not h.get("taken", false))
	if free.is_empty():
		w["settler"] = false
		_next(w)
		return
	free.sort_custom(func(a, b): return (a["door"] as Vector3).distance_to(Vector3(w["p"].x, 0, w["p"].y)) < (b["door"] as Vector3).distance_to(Vector3(w["p"].x, 0, w["p"].y)))
	var h: Dictionary = free[rng.randi() % mini(3, free.size())]
	h["taken"] = true
	w["home"] = h
	_go(w, Vector2(h["door"].x, h["door"].z), "settle")


# ---------- повозка с новосёлами ----------

func _make_cart() -> void:
	var root := Node3D.new()
	var k := Kit.new()
	var wood := Color("8a5a36")
	# телега: кузов с бортами из досок, дышло, мешки и амфоры
	k.box(Vector3(-0.75, 0.55, -1.0), Vector3(0.75, 0.63, 1.0), wood)
	for s: float in [-1.0, 1.0]:
		for q in 3:
			k.box(Vector3(s * 0.75 - 0.04, 0.66 + q * 0.11, -1.0), Vector3(s * 0.75 + 0.04, 0.75 + q * 0.11, 1.0), wood.darkened(0.08 * q))
	k.box(Vector3(-0.75, 0.63, -1.04), Vector3(0.75, 0.98, -0.96), wood.darkened(0.12))
	k.box(Vector3(-0.6, 0.85, 0.75), Vector3(0.6, 0.95, 1.05), wood.lightened(0.05))        # козлы
	k.rod(Vector3(-0.3, 0.55, 1.0), Vector3(-0.32, 0.8, 2.8), 0.04, 6, wood.darkened(0.2))
	k.rod(Vector3(0.3, 0.55, 1.0), Vector3(0.32, 0.8, 2.8), 0.04, 6, wood.darkened(0.2))
	for i in 3:
		k.blob(Vector3(-0.35 + i * 0.35, 0.82, -0.55), Vector3(0.2, 0.17, 0.26), Color("d9c49a"), i, 0.12)
	Props.amphora(k, Vector3(0.35, 0.63, 0.1), 1)
	Props.amphora(k, Vector3(-0.35, 0.63, 0.2), 2)
	Props.crate(k, Vector3(0.0, 0.63, -0.1), 0.4)
	var cm := MeshInstance3D.new()
	cm.mesh = k.mesh()
	cm.material_override = Kit.material()
	root.add_child(cm)
	var wheels := []
	for s: float in [-1.0, 1.0]:
		var wk := Kit.new()
		var n := 16
		for i in n:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			wk.quad_out(Vector3(-0.06, cos(a0) * 0.5, sin(a0) * 0.5), Vector3(0.06, cos(a0) * 0.5, sin(a0) * 0.5), Vector3(0.06, cos(a1) * 0.5, sin(a1) * 0.5), Vector3(-0.06, cos(a1) * 0.5, sin(a1) * 0.5), Color("5a3d26"), Vector3.ZERO)
			wk.quad_out(Vector3(s * 0.065, cos(a0) * 0.5, sin(a0) * 0.5), Vector3(s * 0.065, cos(a1) * 0.5, sin(a1) * 0.5), Vector3(s * 0.065, cos(a1) * 0.42, sin(a1) * 0.42), Vector3(s * 0.065, cos(a0) * 0.42, sin(a0) * 0.42), Color("6a4a30"), Vector3(-s, 0, 0))
		wk.cyl(Vector3(-0.08, 0, 0), 0.09, 0.16, 8, Color("3a2a1e"))
		for i in 4:
			var a := TAU * i / 8.0
			wk.rod(Vector3(0, cos(a) * 0.43, sin(a) * 0.43), Vector3(0, -cos(a) * 0.43, -sin(a) * 0.43), 0.025, 5, Color("6a4a30"))
		var wm := MeshInstance3D.new()
		wm.mesh = wk.mesh()
		wm.material_override = Kit.material()
		wm.position = Vector3(s * 0.85, 0.5, 0)
		root.add_child(wm)
		wheels.append(wm)
	# лошадь (анимированная модель Quaternius, CC0)
	var horse := (load("res://assets/animals/Horse_b.glb") as PackedScene).instantiate() as Node3D
	root.add_child(horse)
	var aabb := _aabb(horse)
	var s := 2.3 / maxf(aabb.size.z, aabb.size.x)
	horse.scale = Vector3.ONE * s
	if aabb.size.x > aabb.size.z:
		horse.rotation.y = PI / 2
	horse.position = Vector3(0, 0, 3.2)
	var hanim: AnimationPlayer = horse.find_children("*", "AnimationPlayer", true, false)[0]
	# возница сидит на козлах
	var driver := Citizen.create(rng, false)
	root.add_child(driver)
	driver.position = Vector3(0, 0.5, 0.75)
	driver.play("Driving_Loop", 0.0)
	add_child(root)
	var path: Array = terrain.roads[0]["pts"].duplicate()
	path[0] = Vector2(40, 11.0)                       # из глубины тоннеля
	path[path.size() - 1] = Vector2(38.5, 34.5)       # остановка у площади
	cart = {"n": root, "wheels": wheels, "horse": hanim, "path": path, "s": 0.0, "dir": 1.0, "pause": 3.0, "dropped": false}


static func _aabb(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var b := mi.mesh.get_aabb()
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	return box


func _anim(ap: AnimationPlayer, name: String) -> void:
	for n in ap.get_animation_list():
		if n == name or n.ends_with("|" + name):
			if ap.current_animation != n:
				ap.play(n, 0.3)
			return


func _cart_step(dt: float) -> void:
	if cart.is_empty():
		return
	var c := cart
	var path: Array = c["path"]
	var total := 0.0
	for i in path.size() - 1:
		total += (path[i] as Vector2).distance_to(path[i + 1])
	var moving := false
	if c["pause"] > 0.0:
		c["pause"] -= dt
	else:
		moving = true
		c["s"] += c["dir"] * 1.5 * dt
		if c["s"] >= total:
			c["s"] = total
			c["dir"] = -1.0
			c["pause"] = 7.0
			_drop_settlers()
		elif c["s"] <= 0.0:
			c["s"] = 0.0
			c["dir"] = 1.0
			c["pause"] = 14.0                         # следующая семья — через время
	var s: float = c["s"]
	var p := Vector2.ZERO
	var dir := Vector2(0, 1)
	for i in path.size() - 1:
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var l := a.distance_to(b)
		if s <= l or i == path.size() - 2:
			p = a.lerp(b, clampf(s / l, 0.0, 1.0))
			dir = (b - a).normalized()
			break
		s -= l
	if c["dir"] < 0:
		dir = -dir
	var n: Node3D = c["n"]
	n.position = Vector3(p.x, Terrain.TOWN_Y, p.y)
	n.rotation.y = lerp_angle(n.rotation.y, atan2(dir.x, dir.y), minf(1.0, dt * 3.0))
	_anim(c["horse"], "Walk" if moving else "Idle")
	if moving:
		for wm in c["wheels"]:
			(wm as Node3D).rotation.x += 1.5 * dt / 0.5


## Семья выходит из повозки у площади и идёт ждать на площадь
func _drop_settlers() -> void:
	var n: Node3D = cart["n"]
	var base := Vector2(n.position.x, n.position.z)
	var count := 2 + rng.randi() % 3
	for i in count:
		var at := _near_free(base + Vector2(1.2 + i * 0.5, rng.randf_range(-0.8, 0.8)))
		var w := _spawn(at, i % 2 == 1)
		w["settler"] = true
		var spot := Terrain.PLAZA_C + Vector2(rng.randf_range(-2.5, 2.5), -4.2 + rng.randf_range(-0.8, 0.8))
		_go(w, spot, "square")
