class_name ArenaShow
extends RefCounted
## Игры в амфитеатре (Spectacle): на арене бьются две пары гладиаторов. Бойцы — те же, что в боях Легиона
## (LegionFighter: снаряжение Synty в руках, вздрагивание), но в городском росте. Пара выходит из ворот арены,
## встаёт друг против друга и бьётся движениями Quaternius Universal Animation Library 2 (CC0): удары мечом с возвратом
## в стойку, удар с разворотом, серии из трёх ударов и тяжёлая серия, выпад, рывок с ударом щитом и толчок щитом;
## у копейщиков — укол копьём. Защитник на каждый удар либо ставит блок (звон), либо пропускает — его отбрасывает
## (начало Hit_Knockback — шаг назад); пробитый блок тяжёлой серии — щит выбит (Idle_Shield_Break). Иногда оба обходят
## друг друга по кругу. Последний пропущенный удар сбивает с ног; упавший встаёт на колено (сдаётся, без смертей),
## победитель ликует, трибуны кричат; оба уходят в ворота, выходит новая пара. Удары —
## со звоном (Spectacle.sfx), трибуны отвечают хлопками и «ура» (Spectacle.react).

## Пары: [кто, кто] — облики бойцов Легиона (мирмиллон со щитом и мечом, галл, гопломах с копьём)
const PAIRS := [["legionary", "gaul"], ["mercenary", "legionary"], ["gaul", "spearman"], ["legionary", "legionary"]]
const ARENA_R := 6.66 * 0.55             # радиус арены колизея в родных размерах (CatMonuments._colosseum)
const GATES := [3.0 * PI / 8.0, 11.0 * PI / 8.0]
## Удары: [движение, возврат в стойку, вес, рывок вперёд (м)] — у мечника и у копейщика; щитовые — только со щитом
const SWORD_MOVES := [["Sword_Regular_A", "Sword_Regular_A_Rec", 0.22, 0.12], ["Sword_Regular_B", "Sword_Regular_B_Rec", 0.2, 0.12],
	["Sword_Regular_C", "", 0.12, 0.1], ["Sword_Regular_Combo", "", 0.16, 0.18], ["Sword_Heavy_Combo", "", 0.08, 0.2],
	["Sword_Dash", "", 0.1, 0.42], ["Shield_Dash", "", 0.08, 0.4], ["Shield_OneShot", "", 0.05, 0.1], ["Melee_Hook", "Melee_Hook_Rec", 0.04, 0.1]]
const SPEAR_MOVES := [["#jab", "", 0.5, 0.22], ["Shield_Dash", "", 0.22, 0.4], ["Shield_OneShot", "", 0.16, 0.1], ["Melee_Hook", "Melee_Hook_Rec", 0.12, 0.1]]
const GAP := 0.42                        # пол-расстояния между бойцами в стойке (м)

var sp
var V: Dictionary
var rng := RandomNumberGenerator.new()
var pairs := []
var k := 1.0                             # масштаб постройки (Catalog.ARCH)
var floor_y := 0.0
var r_in := 3.0
var next_pair := 0
var on := false
var gates: Array = GATES                 # направления ворот от середины арены (у нового амфитеатра — NewArena.GATES)
var u2 := false                          # движения UAL2 есть (новый амфитеатр и библиотека на месте)
var gap := 0.5


func _init(s, v: Dictionary) -> void:
	sp = s
	V = v
	rng.seed = int(V["id"]) * 31 + 7
	k = Catalog.scale_of(String(V.get("type", "colosseum")))
	r_in = ARENA_R * k
	if NewArena.covers(String(V.get("type", ""))):
		r_in = NewArena.AR * k               # новый амфитеатр: своя арена и свои ворота
		gates = NewArena.GATES
	u2 = LegionFighter.arena_library().has_animation("Sword_Regular_A")
	gap = GAP if u2 else 0.5
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
	var a: float = gates[i % 2]
	return Vector3(sin(a) * r, floor_y, cos(a) * r)


## Новая пара выходит из своих ворот (за створками — проход): места на арене — по сторонам от оси ворот
func _spawn(slot: int) -> void:
	var kinds: Array = PAIRS[next_pair % PAIRS.size()]
	next_pair += 1
	var gate := slot % 2
	var ax := float(gates[0]) + PI / 2.0 + slot * PI    # середина пары — поперёк оси ворот
	var c := Vector3(sin(ax), 0, cos(ax)) * r_in * 0.46
	c.y = floor_y
	var u := Vector3(cos(ax), 0, -sin(ax))              # бойцы стоят по касательной
	var fs := []
	for j in 2:
		var f := LegionFighter.create(kinds[j], Citizen.SIZE / LegionFighter.HUMAN, rng.randi(), j == 1)
		(V["root"] as Node3D).add_child(f)
		if u2:
			f.arena_moves()
		var start: Vector3 = sp.gate_point(V, gate, 0.75 + j * 0.55)
		f.position = Vector3(start.x, floor_y, start.z)
		f.set_ground(floor_y)
		fs.append(f)
	sp.gate_open(V, gate, true)
	var p := {"f": fs, "c": c, "u": u, "st": "in", "t": 0.0, "hp": [rng.randi_range(4, 6), rng.randi_range(4, 6)],
		"ex": 0, "slot": slot, "gate": gate, "mark": [c - u * gap, c + u * gap], "atk": -1, "circle": 0.0, "ang": 0.0}
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


## Выбрать удар бойцу f: по его оружию (меч или копьё), щитовые — только со щитом
func _pick(f: LegionFighter) -> Array:
	var list: Array = SPEAR_MOVES if f.style == "spear" else SWORD_MOVES
	var cand := []
	var tot := 0.0
	for m: Array in list:
		var n: String = m[0]
		if n.begins_with("Shield") and not f.shielded:
			continue
		if n != "#jab" and not f.has_move(n):
			continue
		cand.append(m)
		tot += float(m[2])
	var r := rng.randf() * tot
	for m: Array in cand:
		r -= float(m[2])
		if r <= 0.0:
			return m
	return cand[0] if not cand.is_empty() else ["#jab", "", 1.0, 0.2]


## Начать удар: атакующий играет движение, на каждый пик скорости его кисти — удар по защитнику (блок или пропуск)
func _start_attack(p: Dictionary) -> void:
	var fs: Array = p["f"]
	var ai: int = p["atk"]
	var at: LegionFighter = fs[ai]
	var m := _pick(at) if u2 else ["#jab", "", 1.0, 0.22]
	var times := []
	var total := 1.0
	if m[0] == "#jab":
		at.attack()                                      # прежний удар (копьё — укол, меч — Sword_Attack)
		total = 1.0
		times = [0.32]
	else:
		var lens: Array = at.arena_move(String(m[0]), String(m[1]))
		total = maxf(0.4, float(lens[0]))
		for fr: float in at.strikes(String(m[0])):
			times.append(fr * float(lens[1]))
	p["move"] = String(m[0])
	p["dash"] = float(m[3])
	p["dur"] = total
	p["hits"] = times
	p["hi"] = 0
	p["blk"] = false


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
				p["wait"] = rng.randf_range(0.6, 1.2)
				sp.react(V, 0.25, 2.0)
		"guard":
			_face_other(p, dt)
			# к своим местам (после отброса и рывка)
			for j in 2:
				var f: LegionFighter = fs[j]
				var home: Vector3 = p["mark"][j]
				if f.position.distance_to(home) > 0.05:
					f.position = f.position.move_toward(home, dt * 0.5)
			if float(p["t"]) >= float(p["wait"]):
				p["t"] = 0.0
				p["ex"] = int(p["ex"]) + 1
				if int(p["ex"]) % 5 == 0:
					p["st"] = "circle"
					p["ang"] = 0.0
					p["dir"] = 1.0 if rng.randf() < 0.5 else -1.0
				else:
					p["st"] = "atk"
					# чаще бьёт тот, кто бил реже; иногда — ответная серия
					p["atk"] = 0 if rng.randf() < 0.5 else 1
					_start_attack(p)
		"atk":
			var at: LegionFighter = fs[p["atk"]]
			var df: LegionFighter = fs[1 - int(p["atk"])]
			var home: Vector3 = p["mark"][p["atk"]]
			var dhome: Vector3 = p["mark"][1 - int(p["atk"])]
			var to := dhome - home
			to.y = 0.0
			var t: float = p["t"]
			var dur: float = p["dur"]
			# рывок: вперёд к первому удару, назад к концу движения
			var hits: Array = p["hits"]
			var t_hit: float = float(hits[0]) if not hits.is_empty() else dur * 0.4
			var out := float(p["dash"]) * (smoothstep(0.0, maxf(0.05, t_hit), t) - smoothstep(dur * 0.7, dur, t))
			at.position = home + to.normalized() * out
			_face_other(p, dt)
			var hi: int = p["hi"]
			if hi < hits.size():
				var th: float = hits[hi]
				# защитник решает за мгновение до удара: блок (успевает поднять меч или щит) или пропуск
				if t >= th - 0.22 and not p.has("dec%d" % hi):
					p["dec%d" % hi] = true
					p["blk"] = rng.randf() < (0.4 if String(p["move"]).begins_with("Sword_Heavy") else 0.48)
					if bool(p["blk"]) and u2:
						if df.has_move("Sword_Block") and df.style != "spear":
							df.arena_move("Sword_Block", "", 0.06)
						elif df.shielded and df.has_move("Shield_OneShot"):
							df.arena_move("Shield_OneShot", "", 0.06)
				if t >= th:
					p["hi"] = hi + 1
					var mid := (at.position + df.position) * 0.5 + Vector3(0, 0.6, 0)
					var wpos: Vector3 = (V["root"] as Node3D).to_global(mid)
					if bool(p["blk"]):
						sp.sfx.emit("clang", wpos, 1.0)
						sp.react(V, 0.12, 1.8, mid)
						# последний удар тяжёлой серии пробивает блок: щит выбит, защитник отшатнулся
						if u2 and hi == hits.size() - 1 and String(p["move"]) == "Sword_Heavy_Combo" and df.has_move("Idle_Shield_Break"):
							df.arena_move("Idle_Shield_Break", "", 0.06)
					else:
						df.hurt()
						var di := 1 - int(p["atk"])
						p["hp"][di] = int(p["hp"][di]) - 1
						var ko := int(p["hp"][di]) <= 0
						if u2:
							# пропустил: отшатнулся (начало отброса) и снова в стойку; последний удар — сбит с ног
							df.arena_move("Hit_Knockback", "", 0.05, 0.0 if ko else 0.34)
						# отброс: шаг назад от удара (в guard вернётся на место)
						var push := (df.position - at.position)
						push.y = 0.0
						df.position += push.normalized() * (0.22 if ko else 0.1)
						sp.sfx.emit("hit", wpos, 1.0)
						sp.react(V, 0.35, 2.6, mid)
						if ko:
							p["ko"] = true
							at.position = home + to.normalized() * float(p["dash"]) * 0.3
							_finish(p, di)
							return
			if t >= dur:
				at.position = home
				var lose := -1
				for j in 2:
					if int(p["hp"][j]) <= 0:
						lose = j
				if lose >= 0 or int(p["ex"]) >= 14:
					if lose < 0:
						lose = 0 if int(p["hp"][0]) < int(p["hp"][1]) else 1
					_finish(p, lose)
				else:
					p["st"] = "guard"
					p["t"] = 0.0
					p["wait"] = rng.randf_range(0.35, 1.0)
		"circle":
			# обходят друг друга: пара поворачивается вокруг середины на 50°
			var w := deg_to_rad(50.0) / 1.6
			var ang: float = p["ang"] + w * dt * float(p["dir"])
			p["ang"] = ang
			var c: Vector3 = p["c"]
			var u: Vector3 = p["u"]
			var ru := u.rotated(Vector3.UP, ang)
			var ma := c - ru * gap
			var mb := c + ru * gap
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
			var loser: LegionFighter = fs[p["lose"]]
			if t > 1.25 and not p.has("knelt"):
				p["knelt"] = true
				loser.anim.play("Crouch_Idle", 0.45)
				loser.hold(9.0)
			if t > 4.2:
				p["st"] = "out"
				p["t"] = 0.0
				sp.gate_open(V, int(p["gate"]), true)
				loser.hold(0.0)
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


## Бой окончен: у проигравшего пробит щит (или выбит из сил) — он опускается на колено, победитель ликует, трибуны кричат
func _finish(p: Dictionary, lose: int) -> void:
	var fs: Array = p["f"]
	var loser: LegionFighter = fs[lose]
	var win: LegionFighter = fs[1 - lose]
	p["st"] = "end"
	p["t"] = 0.0
	p["lose"] = lose
	loser.set_motion(false)
	if p.has("ko"):
		loser.hold(9.0)                                  # сбит с ног: лежит, потом встаёт на колено
	elif u2 and loser.has_move("Idle_Shield_Break"):
		loser.arena_move("Idle_Shield_Break", "", 0.1)
		loser.hold(9.0)
	else:
		p["knelt"] = true
		loser.anim.play("Crouch_Idle", 0.35)
		loser.hold(9.0)
	win.cheer()
	var wpos: Vector3 = (V["root"] as Node3D).to_global(win.position + Vector3(0, 1.0, 0))
	sp.sfx.emit("roar", wpos, 1.0)
	sp.react(V, 0.85, 4.5)
