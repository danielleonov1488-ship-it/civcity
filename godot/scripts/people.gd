class_name People
extends Node3D
## Жители и повозка. Жители — низкополигональные фигурки в туниках (взрослые и дети), гуляют по улицам и площади,
## машут руками и ногами на ходу, иногда стоят и болтают. Повозка с лошадью выезжает из ворот в скале,
## везёт переселенцев к площади и возвращается.

const TUNICS := ["f1ece0", "d9b46a", "b5503a", "5d7fa3", "6f8f4f", "c98a5a", "8a5a8a", "e8dcc4"]
const SKIN := ["f1c8a4", "dcae86", "c08d66", "a87452"]
const HAIR := ["3a2a1e", "5a3d26", "1f1a17", "8a6a3a", "c9a35a"]

var terrain: Terrain
var walkers := []
var cart := {}
var mat := Kit.material(0.8)
var routes := []


func _ready() -> void:
	# маршруты: дороги и круг вокруг площади
	for r in terrain.roads:
		var pts: Array = []
		for p in r["pts"]:
			pts.append(p)
		routes.append(pts)
	var ring: Array = []
	for i in 13:
		var a := TAU * i / 12.0
		ring.append(Terrain.PLAZA_C + Vector2(cos(a), sin(a)) * 5.0)
	routes.append(ring)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 46:
		var child := rng.randf() < 0.25
		var w := _person(rng, child)
		add_child(w["n"])
		var route: Array = routes[rng.randi() % routes.size()] if rng.randf() < 0.6 else routes[routes.size() - 1]
		w["route"] = route
		w["seg"] = rng.randi() % maxi(1, route.size() - 1)
		w["t"] = rng.randf()
		w["dir"] = 1 if rng.randf() < 0.5 else -1
		w["side"] = rng.randf_range(-0.9, 0.9)
		w["speed"] = rng.randf_range(0.9, 1.3) * (1.25 if child else 1.0)
		w["pause"] = 0.0
		w["ph"] = rng.randf() * TAU
		walkers.append(w)
	_make_cart()


## Фигурка: ноги, туника, пояс, руки, голова, волосы (у части — шляпа или платок)
func _person(rng: RandomNumberGenerator, child: bool) -> Dictionary:
	var s := 0.7 if child else 1.0
	var tunic := Color(TUNICS[rng.randi() % TUNICS.size()])
	var skin := Color(SKIN[rng.randi() % SKIN.size()])
	var hair := Color(HAIR[rng.randi() % HAIR.size()])
	var dress := rng.randf() < 0.45
	var root := Node3D.new()
	var body := Kit.new()
	# туника: у женщин до пят, у мужчин до колен
	var bot := 0.18 if dress else 0.5
	body.box(Vector3(-0.2, bot, -0.13) * s, Vector3(0.2, 1.32, 0.13) * s, tunic, [])
	body.box(Vector3(-0.21, 0.92, -0.14) * s, Vector3(0.21, 0.98, 0.14) * s, tunic.darkened(0.35))
	body.box(Vector3(-0.17, 1.32, -0.11) * s, Vector3(0.17, 1.4, 0.11) * s, tunic.lightened(0.1))
	# голова и волосы
	body.box(Vector3(-0.12, 1.4, -0.12) * s, Vector3(0.12, 1.66, 0.12) * s, skin)
	body.box(Vector3(-0.13, 1.6, -0.13) * s, Vector3(0.13, 1.7, 0.12) * s, hair)
	body.box(Vector3(-0.13, 1.42, -0.13) * s, Vector3(0.13, 1.62, -0.06) * s, hair)
	# глаза
	body.box(Vector3(-0.07, 1.53, 0.12) * s, Vector3(-0.035, 1.57, 0.125) * s, Color("2a2420"))
	body.box(Vector3(0.035, 1.53, 0.12) * s, Vector3(0.07, 1.57, 0.125) * s, Color("2a2420"))
	if rng.randf() < 0.2 and not child:
		# соломенная шляпа
		body.cyl(Vector3(0, 1.68, 0) * s, 0.26 * s, 0.03 * s, 8, Color("d8b86a"))
		body.cyl(Vector3(0, 1.7, 0) * s, 0.14 * s, 0.1 * s, 8, Color("d8b86a"))
	var bm := MeshInstance3D.new()
	bm.mesh = body.mesh()
	bm.material_override = mat
	root.add_child(bm)
	var limbs := {}
	for side: float in [-1.0, 1.0]:
		var leg := Kit.new()
		leg.box(Vector3(-0.07, -0.5, -0.07) * s, Vector3(0.07, 0.0, 0.07) * s, skin.darkened(0.08) if not dress else tunic.darkened(0.1))
		leg.box(Vector3(-0.08, -0.56, -0.08) * s, Vector3(0.08, -0.48, 0.12) * s, Color("6a4a30"))
		var ln := MeshInstance3D.new()
		ln.mesh = leg.mesh()
		ln.material_override = mat
		ln.position = Vector3(side * 0.1, 0.56, 0) * s
		root.add_child(ln)
		var arm := Kit.new()
		arm.box(Vector3(-0.055, -0.5, -0.055) * s, Vector3(0.055, 0.0, 0.055) * s, tunic.darkened(0.05))
		arm.box(Vector3(-0.05, -0.62, -0.05) * s, Vector3(0.05, -0.5, 0.05) * s, skin)
		var an := MeshInstance3D.new()
		an.mesh = arm.mesh()
		an.material_override = mat
		an.position = Vector3(side * 0.26, 1.3, 0) * s
		root.add_child(an)
		limbs["leg" + str(side)] = ln
		limbs["arm" + str(side)] = an
	return {"n": root, "limbs": limbs, "child": child}


func _process(dt: float) -> void:
	for w in walkers:
		var route: Array = w["route"]
		var n: Node3D = w["n"]
		var moving := true
		if w["pause"] > 0.0:
			w["pause"] -= dt
			moving = false
		else:
			var a: Vector2 = route[w["seg"]]
			var b: Vector2 = route[w["seg"] + 1]
			var len := maxf(a.distance_to(b), 0.01)
			w["t"] += w["dir"] * w["speed"] * dt / len
			if w["t"] > 1.0 or w["t"] < 0.0:
				w["seg"] += w["dir"]
				if w["seg"] < 0 or w["seg"] >= route.size() - 1:
					w["dir"] = -w["dir"]
					w["seg"] = clampi(w["seg"], 0, route.size() - 2)
				w["t"] = 0.0 if w["dir"] > 0 else 1.0
				if randf() < 0.15:
					w["pause"] = randf_range(2.0, 6.0)
		var a2: Vector2 = route[w["seg"]]
		var b2: Vector2 = route[w["seg"] + 1]
		var dir: Vector2 = (b2 - a2).normalized() * float(w["dir"])
		var p: Vector2 = a2.lerp(b2, clampf(w["t"], 0.0, 1.0)) + Vector2(-dir.y, dir.x) * float(w["side"])
		var y := terrain.height_at(p.x, p.y)
		n.position = Vector3(p.x, y, p.y)
		n.rotation.y = atan2(dir.x, dir.y)
		if moving:
			w["ph"] += dt * 7.0 * w["speed"]
		var sw: float = sin(w["ph"]) * (0.55 if moving else 0.0)
		var lim: Dictionary = w["limbs"]
		(lim["leg-1.0"] as Node3D).rotation.x = sw
		(lim["leg1.0"] as Node3D).rotation.x = -sw
		(lim["arm-1.0"] as Node3D).rotation.x = -sw * 0.8
		(lim["arm1.0"] as Node3D).rotation.x = sw * 0.8
		n.position.y += absf(cos(w["ph"])) * 0.03 if moving else 0.0
	_cart_step(dt)


# ---------- повозка ----------

func _make_cart() -> void:
	var root := Node3D.new()
	var k := Kit.new()
	var wood := Color("8a5a36")
	# телега: кузов с бортами, дышло, мешки и амфоры, возница
	k.box(Vector3(-0.75, 0.55, -1.0), Vector3(0.75, 0.65, 1.0), wood)
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(s * 0.75 - 0.05, 0.65, -1.0), Vector3(s * 0.75 + 0.05, 1.0, 1.0), wood.darkened(0.1))
	k.box(Vector3(-0.75, 0.65, -1.05), Vector3(0.75, 1.0, -0.95), wood.darkened(0.1))
	k.rod(Vector3(0, 0.55, 1.0), Vector3(0, 0.75, 2.6), 0.05, 5, wood.darkened(0.2))
	for i in 3:
		k.blob(Vector3(-0.35 + i * 0.35, 0.9, -0.5), Vector3(0.2, 0.18, 0.25), Color("d9c49a"), i, 0.15)
	Props.amphora(k, Vector3(0.3, 0.65, 0.3), 1)
	Props.amphora(k, Vector3(-0.3, 0.65, 0.4), 2)
	var cm := MeshInstance3D.new()
	cm.mesh = k.mesh()
	cm.material_override = mat
	root.add_child(cm)
	# колёса
	var wheels := []
	for s: float in [-1.0, 1.0]:
		var wk := Kit.new()
		var n := 10
		for i in n:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			wk.quad_out(Vector3(-0.05, cos(a0) * 0.5, sin(a0) * 0.5), Vector3(0.05, cos(a0) * 0.5, sin(a0) * 0.5), Vector3(0.05, cos(a1) * 0.5, sin(a1) * 0.5), Vector3(-0.05, cos(a1) * 0.5, sin(a1) * 0.5), Color("5a3d26"), Vector3.ZERO)
		wk.box(Vector3(-0.07, -0.08, -0.08), Vector3(0.07, 0.08, 0.08), Color("3a2a1e"), [])
		for i in 4:
			var a := TAU * i / 8.0
			wk.rod(Vector3(0, cos(a) * 0.46, sin(a) * 0.46), Vector3(0, -cos(a) * 0.46, -sin(a) * 0.46), 0.025, 4, Color("6a4a30"))
		var wm := MeshInstance3D.new()
		wm.mesh = wk.mesh()
		wm.material_override = mat
		wm.position = Vector3(s * 0.85, 0.5, 0)
		root.add_child(wm)
		wheels.append(wm)
	# лошадь
	var hk := Kit.new()
	var coat := Color("8a5a3a")
	hk.box(Vector3(-0.28, 0.85, -0.7), Vector3(0.28, 1.45, 0.7), coat)
	hk.box(Vector3(-0.15, 1.3, 0.55), Vector3(0.15, 1.95, 0.85), coat)
	hk.box(Vector3(-0.13, 1.7, 0.8), Vector3(0.13, 1.95, 1.3), coat)
	hk.box(Vector3(-0.06, 1.45, 0.45), Vector3(0.06, 2.0, 0.75), Color("2a1f18"))
	hk.box(Vector3(-0.05, 1.0, -0.85), Vector3(0.05, 1.4, -0.7), Color("2a1f18"))
	hk.box(Vector3(-0.1, 1.8, 1.29), Vector3(0.1, 1.9, 1.31), Color("1f1a17"))
	var hm := MeshInstance3D.new()
	hm.mesh = hk.mesh()
	hm.material_override = mat
	hm.position = Vector3(0, 0, 2.7)
	root.add_child(hm)
	var legs := []
	for lp: Vector3 in [Vector3(-0.18, 0.9, 0.5), Vector3(0.18, 0.9, 0.5), Vector3(-0.18, 0.9, -0.5), Vector3(0.18, 0.9, -0.5)]:
		var lk := Kit.new()
		lk.box(Vector3(-0.07, -0.9, -0.07), Vector3(0.07, 0.0, 0.07), coat.darkened(0.1))
		lk.box(Vector3(-0.08, -0.9, -0.08), Vector3(0.08, -0.78, 0.08), Color("2a1f18"))
		var lm := MeshInstance3D.new()
		lm.mesh = lk.mesh()
		lm.material_override = mat
		lm.position = lp + Vector3(0, 0, 2.7)
		root.add_child(lm)
		legs.append(lm)
	# возница
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var driver := _person(rng, false)
	(driver["n"] as Node3D).position = Vector3(0, 0.55, 0.75)
	root.add_child(driver["n"])
	add_child(root)
	var path: Array = terrain.roads[0]["pts"].duplicate()
	path[0] = Vector2(40, 12.0)            # выезжает из глубины тоннеля
	cart = {"n": root, "wheels": wheels, "legs": legs, "path": path, "s": 0.0, "dir": 1.0, "pause": 0.0}


func _cart_step(dt: float) -> void:
	var c := cart
	if c.is_empty():
		return
	var path: Array = c["path"]
	var total := 0.0
	for i in path.size() - 1:
		total += (path[i] as Vector2).distance_to(path[i + 1])
	var moving := true
	if c["pause"] > 0.0:
		c["pause"] -= dt
		moving = false
	else:
		c["s"] += c["dir"] * 1.6 * dt
		if c["s"] >= total or c["s"] <= 0.0:
			c["s"] = clampf(c["s"], 0.0, total)
			c["dir"] = -c["dir"]
			c["pause"] = 6.0
	# точка на пути
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
	n.position = Vector3(p.x, Terrain.TOWN_Y, p.y) - Vector3(dir.x, 0, dir.y) * 1.2
	n.rotation.y = atan2(dir.x, dir.y)
	if moving:
		for wm in c["wheels"]:
			(wm as Node3D).rotation.x += 1.6 * dt / 0.5
		var t := Time.get_ticks_msec() / 1000.0
		for i in 4:
			(c["legs"][i] as Node3D).rotation.x = sin(t * 6.0 + (PI if i % 3 == 0 else 0.0)) * 0.4
