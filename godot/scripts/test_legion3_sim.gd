extends Node3D
## Легион 3.0, этап L3.2: проверки боя (ряды, жрец, всадник, противовесы, прежний бой без изменений) и кадры 3D-боя.
##   bash .work/py/gpu_run.sh res://test_legion3_sim.tscn --headless             → «L3S DONE fails=N»
##   bash .work/py/gpu_run.sh res://test_legion3_sim.tscn --headless -- legacy=1  → только подписи прежних боёв (для сверки)
##   bash .work/py/gpu_run.sh res://test_legion3_sim.tscn -- shots=1 out=D:/CivCity/.work/stage1/legion/sim_shots
var fails := 0
var args := {}

# Подписи прежних боёв (сняты ДО правок боя): "победа выжило/всего время_мс остаток_здоровья×1e6"
const LEGACY := {
	"A:1": "true 6/6 21200 875878", "A:7": "true 6/6 21700 843677", "A:42": "true 6/6 22400 842506",
	"B:3": "true 2/4 22500 408240", "B:11": "true 2/4 25467 327091", "C:5": "false 0/3 24000 0",
}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("shots"):
		_shots()
		return
	if args.has("fighters"):
		_fighters()
		return
	if args.has("legacy"):
		for k in LEGACY:
			print("L3S SIG ", k, " = ", _sig(k))
		get_tree().quit()
		return
	_t_rows()
	_t_priest()
	_t_cavalry_target()
	_t_counters()
	_t_legacy()
	print("L3S DONE fails=", fails)
	get_tree().quit(1 if fails > 0 else 0)


func _ok(name: String, cond: bool, info := "") -> void:
	if cond:
		print("L3S PASS ", name, " ", info)
	else:
		fails += 1
		print("L3S FAIL ", name, " ", info)


# ---------- статы (числа как у Legion.unit_stats, 1 уровень) ----------

static func _legionary(extra := {}) -> Dictionary:
	var d := Legion.unit_stats("legionary", 1)
	d["tags"] = ["human", "armored"]
	d["vs"] = {"human": 1.3, "swift": 1.3, "cavalry": 1.3}
	d.merge(extra, true)
	return d


static func _archer(extra := {}) -> Dictionary:
	var d := Legion.unit_stats("archer", 1)
	d["vs"] = {"armored": 1.3}
	d.merge(extra, true)
	return d


static func _priest(extra := {}) -> Dictionary:
	var d := {"key": "priest", "name": "Жрец", "level": 1, "hp": 160, "atk": 14, "armor": 6.0, "range": 6.0, "min_range": 0.0, "rate": 1.6,
		"speed": 1.4, "shot": "sling", "pierce": false, "splash": 0.0, "vs": {}, "tags": ["human"], "size": 1.0, "boss": false, "heal": 2.2}
	d.merge(extra, true)
	return d


static func _cavalry(extra := {}) -> Dictionary:
	var d := {"key": "cavalry", "name": "Всадник", "level": 1, "hp": 240, "atk": 21, "armor": 20.0, "range": 1.2, "min_range": 0.0, "rate": 1.0,
		"speed": 2.8, "shot": "", "pierce": false, "splash": 0.0, "vs": {"ranged": 1.3}, "tags": ["cavalry", "swift"], "size": 1.1,
		"boss": false, "backline": true}
	d.merge(extra, true)
	return d


static func _setup(squad: Array, foes: Array, seed_v: int) -> Dictionary:
	return {"kind": "test", "squad": squad, "waves": [foes], "perks": {}, "seed": seed_v, "enemy_formation": true}


static func _dup(d: Dictionary, n: int) -> Array:
	var out := []
	for i in n:
		out.append(d.duplicate(true))
	return out


# ---------- 1. ряды ----------

func _t_rows() -> void:
	var sq := []
	for i in 3:
		sq.append(_legionary({"row": 0}))
	for i in 2:
		sq.append(_archer({"row": 1}))
	var sim := LegionSim.new(_setup(sq, [Legion.enemy_stats("bandit", 1.0)], 1))
	var xs := {}
	var zs := {0: [], 1: []}
	for u in sim.units:
		if u.side == "ally":
			xs[snappedf(u.x, 0.01)] = true
			zs[u.row].append(u.z)
	var kx: Array = xs.keys()
	kx.sort()
	_ok("rows_two_depths", kx.size() == 2 and is_equal_approx(float(kx[1]), -4.6) and is_equal_approx(float(kx[0]), -6.0), str(kx))
	var z0: Array = zs[0]
	var z1: Array = zs[1]
	z0.sort()
	z1.sort()
	_ok("rows_lanes_even", z0.size() == 3 and z1.size() == 2 and is_equal_approx(z0[1] - z0[0], z0[2] - z0[1]) and is_equal_approx(z1[0], -z1[1]), str(z0, z1))
	# ряд выбирает игрок, а не роль: лучник в переднем, легионер в заднем
	var sim2 := LegionSim.new(_setup([_archer({"row": 0}), _legionary({"row": 1})], [Legion.enemy_stats("bandit", 1.0)], 1))
	var ok2 := true
	for u in sim2.units:
		if u.side == "ally":
			ok2 = ok2 and ((u.key == "archer" and is_equal_approx(u.x, -4.6)) or (u.key == "legionary" and is_equal_approx(u.x, -6.0)))
	_ok("rows_player_choice", ok2)
	# без row — прежний строй по ролям (ближний −4,6; стрелок −6,0 / −6,5 со сдвигом)
	var sim3 := LegionSim.new(_setup([_legionary(), _archer()], [Legion.enemy_stats("bandit", 1.0)], 1))
	var ax := 0.0
	for u in sim3.units:
		if u.side == "ally" and u.key == "archer":
			ax = u.x
	_ok("rows_absent_legacy_depth", is_equal_approx(ax, -6.5) or is_equal_approx(ax, -6.0), str(ax))


# ---------- 2. жрец ----------

## Потеря здоровья отрядом за бой (доля) по нескольким зёрнам; with_priest — жрец стоит на месте второго легионера заднего ряда
func _priest_loss(with_priest: bool) -> Array:
	var lost := 0.0
	var wins := 0
	var heals := 0
	for sd in range(1, 9):
		var sq := [_legionary({"row": 0}), _legionary({"row": 0}), _legionary({"row": 0}),
			_priest({"row": 1}) if with_priest else _legionary({"row": 1}), _archer({"row": 1})]
		var foes := []
		for i in 5:
			foes.append(Legion.enemy_stats("gaul", 1.2))
		var sim := LegionSim.new(_setup(sq, foes, sd))
		while sim.result.is_empty():
			sim.step(LegionSim.DT)
			for e in sim.take_events():
				if e["type"] == "heal" and e.has("from"):
					heals += 1
		var r := sim.result
		lost += 1.0 - float(r["hp_left"])
		wins += 1 if r["win"] else 0
	return [lost / 8.0, wins, heals]


func _t_priest() -> void:
	var a := _priest_loss(true)
	var b := _priest_loss(false)
	_ok("priest_heals_events", int(a[2]) > 0 and int(b[2]) == 0, "heals=%d vs %d" % [a[2], b[2]])
	_ok("priest_less_hp_lost", float(a[0]) < float(b[0]), "lost %.3f (priest) vs %.3f (legionary)" % [a[0], b[0]])
	# одна порция лечения: 25…35 здоровья у жреца ATK 14 × 2,2
	var sq := [_legionary({"row": 0, "hp": 1000}), _priest({"row": 1})]
	var sim := LegionSim.new(_setup(sq, [Legion.enemy_stats("bandit", 1.0)], 3))
	sim.units[0].hp = 100.0
	var amount := 0
	for i in 200:
		sim.step(LegionSim.DT)
		for e in sim.take_events():
			if e["type"] == "heal" and amount == 0:
				amount = int(e["amount"])
	_ok("priest_heal_amount", amount >= 25 and amount <= 35, "amount=%d" % amount)
	# лечит самого раненого, а не первого
	var sq2 := [_legionary({"row": 0}), _legionary({"row": 0}), _priest({"row": 1})]
	var sim2 := LegionSim.new(_setup(sq2, [Legion.enemy_stats("bandit", 0.2)], 3))
	sim2.units[0].hp = 200.0
	sim2.units[1].hp = 90.0
	var who := -1
	for i in 150:
		sim2.step(LegionSim.DT)
		for e in sim2.take_events():
			if e["type"] == "heal" and who < 0:
				who = (e["unit"] as LegionSim.Unit).id
	_ok("priest_heals_most_wounded", who == sim2.units[1].id, "who=%d want=%d" % [who, sim2.units[1].id])
	# слишком далеко — не лечит
	var sq3 := [_legionary({"row": 0, "hp": 1000}), _priest({"row": 1, "range": 2.0})]
	var sim3 := LegionSim.new(_setup(sq3, [Legion.enemy_stats("bandit", 0.1)], 3))
	sim3.units[0].hp = 100.0
	sim3.units[0].z = -2.4
	sim3.units[1].z = 2.4
	var far := 0
	for i in 60:
		sim3.step(LegionSim.DT)
		for e in sim3.take_events():
			far += 1 if e["type"] == "heal" else 0
	_ok("priest_range_limit", far == 0, "heals=%d" % far)


# ---------- 3. всадник бьёт задний ряд ----------

func _t_cavalry_target() -> void:
	# враги: два бойца в переднем ряду (ближе) и стрелок / боец заднего ряда (дальше)
	var foes := [_legionary({"row": 0}), _legionary({"row": 0}), _archer({"row": 1}), _legionary({"row": 1})]
	var sim := LegionSim.new(_setup([_cavalry({"row": 0})], foes, 5))
	var cav: LegionSim.Unit = sim.units[0]
	sim.step(LegionSim.DT)
	var t1: LegionSim.Unit = cav.target
	_ok("cavalry_prefers_backrow", t1 != null and (t1.row == 1 or t1.ranged()), "target=%s row=%d" % [t1.key if t1 else "-", t1.row if t1 else -1])
	# у врагов без рядов (поход) — стрелок раньше ближних
	var sim2 := LegionSim.new(_setup([_cavalry()], [Legion.enemy_stats("gaul", 1.0), Legion.enemy_stats("gaul", 1.0), Legion.enemy_stats("slinger", 1.0)], 5))
	sim2.step(LegionSim.DT)
	var t2: LegionSim.Unit = sim2.units[0].target
	_ok("cavalry_prefers_ranged", t2 != null and t2.key == "slinger", "target=%s" % (t2.key if t2 else "-"))
	# обычный легионер бьёт ближайшего
	var sim3 := LegionSim.new(_setup([_legionary({"row": 0})], foes, 5))
	sim3.step(LegionSim.DT)
	var t3: LegionSim.Unit = sim3.units[0].target
	_ok("legionary_nearest", t3 != null and t3.row == 0, "row=%d" % (t3.row if t3 else -1))
	# всадники доскакивают: первым из врагов падает стрелок
	var first_dead := ""
	var sim4 := LegionSim.new(_setup([_cavalry({"row": 0, "hp": 700, "atk": 40}), _cavalry({"row": 0, "hp": 700, "atk": 40})],
		[_legionary({"row": 0}), _legionary({"row": 0}), _archer({"row": 1}), _archer({"row": 1})], 9))
	while sim4.result.is_empty() and first_dead == "":
		sim4.step(LegionSim.DT)
		for e in sim4.take_events():
			if e["type"] == "death" and first_dead == "" and (e["unit"] as LegionSim.Unit).side == "enemy":
				first_dead = (e["unit"] as LegionSim.Unit).key
	_ok("cavalry_kills_archer_first", first_dead == "archer", first_dead)


# ---------- 4. противовесы ----------

## Доля побед и средняя доля здоровья A против B по зёрнам; a и b — функции, собирающие отряд
func _duel(a: Callable, b: Callable, n := 16) -> Array:
	var wins := 0
	var hp := 0.0
	for sd in range(1, n + 1):
		var sim := LegionSim.new(_setup(a.call(), b.call(), sd * 17))
		while sim.result.is_empty():
			sim.step(LegionSim.DT)
			sim.events.clear()
		wins += 1 if sim.result["win"] else 0
		# перевес: доля здоровья нашего отряда минус доля здоровья врага (не упирается в ноль у проигравших)
		var fh := 0.0
		var fm := 0.0
		for u in sim.units:
			if u.side == "enemy":
				fm += u.max_hp
				fh += maxf(0.0, u.hp)
		hp += float(sim.result["hp_left"]) - fh / maxf(1.0, fm)
	return [float(wins) / n, hp / n]


func _t_counters() -> void:
	var lv := {"human": 1.3, "swift": 1.3, "cavalry": 1.3}
	var cav := func(vs: Dictionary) -> Array: return _dup(_cavalry({"row": 0, "vs": vs}), 3)
	var arc := func(vs: Dictionary) -> Array: return _dup(_archer({"row": 1, "vs": vs}), 3)
	var leg := func(vs: Dictionary) -> Array: return _dup(_legionary({"row": 0, "vs": vs}), 3)
	# всадники против лучников
	var cav_on := _duel(func(): return cav.call({"ranged": 1.3}), func(): return arc.call({"armored": 1.3}))
	var cav_off := _duel(func(): return cav.call({}), func(): return arc.call({"armored": 1.3}))
	_ok("counter_cav_beats_archers", float(cav_on[0]) > 1.0 - float(cav_on[0]) and float(cav_on[1]) > float(cav_off[1]),
		"cav win=%.2f перевес=%.3f (без противовеса %.3f)" % [cav_on[0], cav_on[1], cav_off[1]])
	# лучники против легионеров («armored» в тегах легионера)
	var arc_on := _duel(func(): return arc.call({"armored": 1.3}), func(): return leg.call(lv))
	var arc_off := _duel(func(): return arc.call({}), func(): return leg.call(lv))
	_ok("counter_archers_vs_legionaries", float(arc_on[1]) > float(arc_off[1]),
		"перевес=%.3f win=%.2f (без противовеса %.3f, win=%.2f)" % [arc_on[1], arc_on[0], arc_off[1], arc_off[0]])
	# легионеры против всадников
	var leg_on := _duel(func(): return leg.call(lv), func(): return cav.call({"ranged": 1.3}))
	var leg_off := _duel(func(): return leg.call({}), func(): return cav.call({"ranged": 1.3}))
	_ok("counter_legionaries_vs_cavalry", float(leg_on[1]) > float(leg_off[1]),
		"перевес=%.3f win=%.2f (без противовеса %.3f, win=%.2f)" % [leg_on[1], leg_on[0], leg_off[1], leg_off[0]])
	print("L3S INFO win rates: cav>arc %.2f, arc>leg %.2f, leg>cav %.2f" % [cav_on[0], arc_on[0], leg_on[0]])


# ---------- 5. прежний бой без изменений ----------

## Подпись боя: победа, выжило, время и остаток здоровья (точные числа) — прежние настройки, без ключей Легиона 3.0
func _sig(k: String) -> String:
	var kind := k.get_slice(":", 0)
	var sd := int(k.get_slice(":", 1))
	var setup: Dictionary
	match kind:
		"A":
			var sq := [Legion.unit_stats("legionary", 3), Legion.unit_stats("legionary", 3), Legion.unit_stats("archer", 3),
				Legion.unit_stats("archer", 3), Legion.unit_stats("ballista", 2), Legion.unit_stats("catapult", 2)]
			var w1 := []
			for e in ["bandit", "bandit", "slinger", "wolf", "gaul", "gaulArcher"]:
				w1.append(Legion.enemy_stats(e, 1.1))
			var w2 := []
			for e in ["boar", "bear", "berserker", "slinger"]:
				w2.append(Legion.enemy_stats(e, 1.3))
			setup = {"kind": "campaign", "squad": sq, "waves": [w1, w2], "perks": {"oil": 2, "volley": 1, "bandage": 1, "testudo": 1, "horn": 1}, "seed": sd}
		"B":
			var sq := [Legion.unit_stats("spearman", 4), Legion.unit_stats("legionary", 4), Legion.unit_stats("archer", 4), Legion.unit_stats("legionary", 4)]
			var w1 := []
			for e in ["mercenary", "pirate", "bull", "gaul", "shade"]:
				w1.append(Legion.enemy_stats(e, 1.4))
			setup = {"kind": "campaign", "squad": sq, "waves": [w1], "perks": {}, "seed": sd}
		_:
			var sq := [Legion.unit_stats("legionary", 5), Legion.unit_stats("archer", 5), Legion.unit_stats("spearman", 5)]
			var foes := [Legion.unit_stats("legionary", 5), Legion.unit_stats("archer", 5), Legion.unit_stats("catapult", 4), Legion.unit_stats("spearman", 5)]
			setup = {"kind": "pvp", "squad": sq, "waves": [foes], "perks": {"oil": 1}, "enemy_perks": {"bandage": 1}, "enemy_auto": true, "enemy_formation": true, "seed": sd}
	var sim := LegionSim.new(setup)
	var r := sim.run(true)
	return "%s %d/%d %d %d" % [r["win"], r["alive"], r["total"], roundi(float(r["time"]) * 1000.0), roundi(float(r["hp_left"]) * 1000000.0)]


func _t_legacy() -> void:
	for k in LEGACY:
		var got := _sig(k)
		_ok("legacy_" + k, got == String(LEGACY[k]), "%s (ждали %s)" % [got, LEGACY[k]])


# ---------- кадры 3D-боя (жрец и всадник в отряде) ----------

var battle: LegionBattle
var t_all := 0.0
var shot_list := []
var shot_i := 0
var out_dir := "D:/CivCity/.work/stage1/legion/sim_shots"


func _shots() -> void:
	out_dir = String(args.get("out", out_dir))
	DirAccess.make_dir_recursive_absolute(out_dir)
	for s in String(args.get("at", "2,5,8,12")).split(",", false):
		shot_list.append(float(s))
	var sq := [_legionary({"row": 0, "hp": 900, "atk": 24}), _cavalry({"row": 0, "hp": 700}), _legionary({"row": 0, "hp": 900, "atk": 24}),
		_priest({"row": 1, "hp": 500}), _archer({"row": 1, "hp": 400})]
	var w1 := []
	for e in ["gaul", "gaul", "gaulArcher", "slinger", "bandit", "gaul"]:
		w1.append(Legion.enemy_stats(e, 2.2))
	var legion := Legion.new()
	legion.free_mode = true
	var setup := legion.make_battle(legion.stage_info(0, 0, 2), 7)
	setup["squad"] = sq
	setup["waves"] = [w1]
	battle = LegionBattle.open(self, setup, func(_o): pass, {"legion": legion, "speed": 1.0, "auto": false, "quality": "high"})


func _process(dt: float) -> void:
	if battle == null:
		return
	t_all += dt
	if not is_instance_valid(battle) or battle.sim == null:
		return
	var st: float = battle.sim.t
	if shot_i < shot_list.size() and st >= float(shot_list[shot_i]):
		var p := "%s/l3s_%02d.png" % [out_dir, int(shot_list[shot_i])]
		get_viewport().get_texture().get_image().save_png(p)
		print("L3S SHOT ", p, " units=", battle.views.size())
		shot_i += 1
	if shot_i >= shot_list.size() or battle.phase == "result" or t_all > 120.0:
		battle.abort()
		get_tree().quit()


# ---------- витрина бойцов: жрец и всадник вблизи (fighters=1) ----------

func _fighters() -> void:
	out_dir = String(args.get("out", out_dir))
	DirAccess.make_dir_recursive_absolute(out_dir)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.7, 0.85)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	env.environment.ambient_light_energy = 0.7
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.45, 0.55, 0.3)
	floor_mi.material_override = fm
	add_child(floor_mi)
	var fl := []
	var i := 0
	for k in ["legionary", "archer", "legionPriest", "cavalry"]:
		var f := LegionFighter.create(k, 1.1 if k == "cavalry" else 1.0, 3 + i)
		f.position = Vector3(-2.6 + i * 1.75, 0, 0)
		f.rotation.y = float(args.get("yaw", "0.5"))
		add_child(f)
		fl.append(f)
		i += 1
	var cam := Camera3D.new()
	cam.position = Vector3(float(args.get("cx", "0")), 1.7, float(args.get("cz", "6.5")))
	cam.current = true
	add_child(cam)
	cam.look_at(Vector3(float(args.get("lx", "0")), 0.9, 0.0))
	cam.fov = 45.0
	var seq := [["idle", 1.0], ["run", 1.0], ["attack", 0.25], ["cast", 0.2], ["attack2", 0.3], ["death", 1.4]]
	for st: Array in seq:
		var name := String(st[0])
		for f: LegionFighter in fl:
			match name:
				"idle":
					f.set_motion(false)
				"run":
					f.set_motion(true, 2.8)
				"attack", "attack2":
					f.attack()
				"cast":
					f.cast()
				"death":
					if f.key == "cavalry" or f.key == "legionPriest":
						f.die()
		var t0 := 0.0
		while t0 < float(st[1]):
			await get_tree().process_frame
			var d := get_process_delta_time()
			t0 += d
			for f: LegionFighter in fl:
				f.tick(d)
		var p := "%s/fighters_%s.png" % [out_dir, name]
		get_viewport().get_texture().get_image().save_png(p)
		print("L3S SHOT ", p)
	get_tree().quit()
