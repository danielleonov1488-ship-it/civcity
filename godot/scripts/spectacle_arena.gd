class_name ArenaShow
extends RefCounted
## Игры в амфитеатре (Spectacle): на арене бьются две пары гладиаторов. Бойцы — те же, что в боях Легиона
## (LegionFighter: снаряжение Synty в руках, удары, вздрагивание), но в городском росте. Пара выходит из ворот арены,
## встаёт друг против друга и бьётся: стойка, выпад и удар, второй вздрагивает или принимает удар на щит; иногда
## оба обходят друг друга по кругу. Пропустил много — опускается на колено (сдаётся, без смертей), победитель
## ликует, трибуны кричат; оба уходят в ворота, выходит новая пара. Удары — со звоном (Spectacle.sfx), трибуны
## отвечают хлопками и «ура» (Spectacle.react).

## Пары: [кто, кто] — облики бойцов Легиона (мирмиллон со щитом и мечом, галл, гопломах с копьём)
const PAIRS := [["legionary", "gaul"], ["mercenary", "legionary"], ["gaul", "spearman"], ["legionary", "legionary"]]
const ARENA_R := 6.66 * 0.55             # радиус арены колизея в родных размерах (CatMonuments._colosseum)
const GATES := [3.0 * PI / 8.0, 11.0 * PI / 8.0]

var sp
var V: Dictionary
var rng := RandomNumberGenerator.new()
var pairs := []
var k := 1.0                             # масштаб постройки (Catalog.ARCH)
var floor_y := 0.0
var r_in := 3.0
var next_pair := 0
var on := false


func _init(s, v: Dictionary) -> void:
	sp = s
	V = v
	rng.seed = int(V["id"]) * 31 + 7
	k = Catalog.scale_of(String(V.get("type", "colosseum")))
	r_in = ARENA_R * k
	var tris = V["lay"]["tris"]
	var h: float = tris.surface(r_in * 0.55, 0.0, 1.0)
	floor_y = h if h > -INF else 0.03


func phase(ph: String) -> void:
	on = ph == "show"
	if ph == "idle" or ph == "gather":
		free_all()


func free_all() -> void:
	for p: Dictionary in pairs:
		for f in p["f"]:
			if is_instance_valid(f):
				(f as Node).queue_free()
	pairs = []


func _gate_pt(i: int, r: float) -> Vector3:
	var a: float = GATES[i % 2]
	return Vector3(sin(a) * r, floor_y, cos(a) * r)


## Новая пара выходит из своих ворот (за створками — проход): места на арене — по сторонам от оси ворот
func _spawn(slot: int) -> void:
	var kinds: Array = PAIRS[next_pair % PAIRS.size()]
	next_pair += 1
	var gate := slot % 2
	var ax := GATES[0] + PI / 2.0 + slot * PI           # середина пары — поперёк оси ворот
	var c := Vector3(sin(ax), 0, cos(ax)) * r_in * 0.48
	c.y = floor_y
	var u := Vector3(cos(ax), 0, -sin(ax))              # бойцы стоят по касательной
	var fs := []
	for j in 2:
		var f := LegionFighter.create(kinds[j], Citizen.SIZE / LegionFighter.HUMAN, rng.randi(), j == 1)
		(V["root"] as Node3D).add_child(f)
		var start: Vector3 = sp.gate_point(V, gate, 0.75 + j * 0.55)
		f.position = Vector3(start.x, floor_y, start.z)
		f.set_ground(floor_y)
		fs.append(f)
	sp.gate_open(V, gate, true)
	var p := {"f": fs, "c": c, "u": u, "st": "in", "t": 0.0, "hp": [rng.randi_range(3, 5), rng.randi_range(3, 5)],
		"ex": 0, "slot": slot, "gate": gate, "mark": [c - u * 0.5, c + u * 0.5], "atk": -1, "lunge": 0.0, "circle": 0.0, "ang": 0.0}
	pairs.append(p)


func tick(dt: float, ph: String) -> void:
	if on:
		for slot in 2:
			if pairs.filter(func(p): return p["slot"] == slot).is_empty():
				_spawn(slot)
	for p: Dictionary in pairs.duplicate():
		_pair_step(p, dt)
		for f: LegionFighter in p["f"]:
			if is_instance_valid(f):
				f.tick(dt)


func _walk_to(f: LegionFighter, to: Vector3, dt: float, pace := 1.0) -> bool:
	var d := to - f.position
	d.y = 0.0
	var dist := d.length()
	if dist < 0.04:
		f.set_motion(false)
		return true
	f.set_motion(true, pace)
	var step := minf(dist, pace * dt)
	f.position += d / dist * step
	f.face(atan2(d.x, d.z), dt)
	return false


func _face_other(p: Dictionary, dt: float) -> void:
	var a: LegionFighter = p["f"][0]
	var b: LegionFighter = p["f"][1]
	var d := b.position - a.position
	a.face(atan2(d.x, d.z), dt)
	b.face(atan2(-d.x, -d.z), dt)


func _pair_step(p: Dictionary, dt: float) -> void:
	p["t"] = float(p["t"]) + dt
	var fs: Array = p["f"]
	var a: LegionFighter = fs[0]
	var b: LegionFighter = fs[1]
	match p["st"]:
		"in":
			# створки открываются — потом выходят по одному
			var t: float = p["t"]
			var da := t > 0.9 and _walk_to(a, p["mark"][0], dt, 0.9)
			var db := t > 1.5 and _walk_to(b, p["mark"][1], dt, 0.9)
			if t <= 0.9:
				a.set_motion(false)
			if t <= 1.5:
				b.set_motion(false)
			if t > 4.0 and not p.has("shut"):
				p["shut"] = true
				sp.gate_open(V, int(p["gate"]), false)
			if da and db:
				p["st"] = "guard"
				p["t"] = 0.0
				p["wait"] = rng.randf_range(0.8, 1.4)
				sp.react(V, 0.25, 2.0)
		"guard":
			_face_other(p, dt)
			if float(p["t"]) >= float(p["wait"]):
				p["t"] = 0.0
				p["ex"] = int(p["ex"]) + 1
				if int(p["ex"]) % 4 == 0:
					p["st"] = "circle"
					p["ang"] = 0.0
					p["dir"] = 1.0 if rng.randf() < 0.5 else -1.0
				else:
					p["st"] = "lunge"
					p["atk"] = 0 if rng.randf() < 0.5 else 1
					p["hit"] = false
					(fs[p["atk"]] as LegionFighter).attack()
		"lunge":
			# выпад: атакующий шагает вперёд и бьёт; на 0,32 с — удар достиг цели
			var at: LegionFighter = fs[p["atk"]]
			var df: LegionFighter = fs[1 - int(p["atk"])]
			var home: Vector3 = p["mark"][p["atk"]]
			var to := df.position - home
			to.y = 0.0
			var t: float = p["t"]
			var out := sin(clampf(t / 0.7, 0.0, 1.0) * PI) * 0.22
			at.position = home + to.normalized() * out
			_face_other(p, dt)
			if t >= 0.32 and not bool(p["hit"]):
				p["hit"] = true
				var mid := (at.position + df.position) * 0.5 + Vector3(0, 0.6, 0)
				var wpos: Vector3 = (V["root"] as Node3D).to_global(mid)
				if rng.randf() < 0.62:
					df.hurt()
					p["hp"][1 - int(p["atk"])] = int(p["hp"][1 - int(p["atk"])]) - 1
					sp.sfx.emit("hit", wpos, 1.0)
					sp.react(V, 0.35, 2.6, mid)
				else:
					sp.sfx.emit("clang", wpos, 1.0)
					sp.react(V, 0.12, 1.8, mid)
			if t >= 1.0:
				at.position = home
				var lose := -1
				for j in 2:
					if int(p["hp"][j]) <= 0:
						lose = j
				if lose >= 0 or int(p["ex"]) >= 12:
					if lose < 0:
						lose = 0 if int(p["hp"][0]) < int(p["hp"][1]) else 1
					_finish(p, lose)
				else:
					p["st"] = "guard"
					p["t"] = 0.0
					p["wait"] = rng.randf_range(0.5, 1.3)
		"circle":
			# обходят друг друга: пара поворачивается вокруг середины на 50°
			var w := deg_to_rad(50.0) / 1.6
			var ang: float = p["ang"] + w * dt * float(p["dir"])
			p["ang"] = ang
			var c: Vector3 = p["c"]
			var u: Vector3 = p["u"]
			var ru := u.rotated(Vector3.UP, ang)
			var ma := c - ru * 0.5
			var mb := c + ru * 0.5
			for j in 2:
				var f: LegionFighter = fs[j]
				var to: Vector3 = ma if j == 0 else mb
				var d := to - f.position
				f.position = to
				if d.length() > 1e-4:
					f.set_motion(true, 0.6)
			_face_other(p, dt * 0.5)
			if absf(ang) >= deg_to_rad(50.0):
				p["u"] = ru
				p["mark"] = [ma, mb]
				for f: LegionFighter in fs:
					f.set_motion(false)
				p["st"] = "guard"
				p["t"] = 0.0
				p["wait"] = rng.randf_range(0.4, 0.9)
		"end":
			var t: float = p["t"]
			if t > 4.2:
				p["st"] = "out"
				p["t"] = 0.0
				sp.gate_open(V, int(p["gate"]), true)
				var loser: LegionFighter = fs[p["lose"]]
				loser.anim.play(loser.clip.get("walk", "Walk"), 0.4)
		"out":
			# уходят в свои ворота: сначала к проёму, потом в проход; за ними створки закрываются
			var done := true
			for j in 2:
				var f: LegionFighter = fs[j]
				if float(p["t"]) < 0.6 + j * 0.6:
					done = false
					continue
				var key := "leg%d" % j
				var g: Vector3 = sp.gate_point(V, int(p["gate"]), -0.35 if not p.has(key) else 1.4)
				g.y = floor_y
				if _walk_to(f, g, dt, 0.85):
					if not p.has(key):
						p[key] = true
						done = false
					elif f.visible:
						f.visible = false
				else:
					done = false
			if done:
				sp.gate_open(V, int(p["gate"]), false)
				for f in fs:
					(f as Node).queue_free()
				pairs.erase(p)


## Бой окончен: проигравший опускается на колено, победитель ликует, трибуны встают… то есть кричат
func _finish(p: Dictionary, lose: int) -> void:
	var fs: Array = p["f"]
	var loser: LegionFighter = fs[lose]
	var win: LegionFighter = fs[1 - lose]
	p["st"] = "end"
	p["t"] = 0.0
	p["lose"] = lose
	loser.set_motion(false)
	loser.anim.play("Crouch_Idle", 0.35)
	win.cheer()
	var wpos: Vector3 = (V["root"] as Node3D).to_global(win.position + Vector3(0, 1.0, 0))
	sp.sfx.emit("roar", wpos, 1.0)
	sp.react(V, 0.85, 4.5)
