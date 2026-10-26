extends SceneTree
## Сверка боя на сервере с боем в игре: Godot считает случайные бои с городами (LegionSim, как в 3D-бою:
## Legion.make_pvp_battle с отрядом от сервера, «игрок» жмёт умения и «Авто» в случайные шаги) и пишет их в JSON;
## node server/test_sim.js повторяет каждый на server/legion_sim.js и сравнивает итог до бита.
##   Godot_console --headless --path godot --script res://scripts/test_sim_dump.gd -- n=300 out=D:/CivCity/.work/sim_dump.json
##   node server/test_sim.js D:/CivCity/.work/sim_dump.json
## (seed=N — другой набор случайных боёв). В части отрядов — свой герой (Д11) на первом месте (уровень, город, Склад оружия,
## имя и облик, как их кладёт сервер), изредка — «герой» не на первом месте (его обе стороны не берут в бой)
## Без графики, замок видеокарты не нужен.

const TYPES := ["legionary", "spearman", "archer", "ballista", "catapult"]
const BONUS := [0.0, 0.0, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.35]


func _initialize() -> void:
	var n := 300
	var out_path := "D:/CivCity/.work/sim_dump.json"
	var rs := 20261013
	for a in OS.get_cmdline_user_args():
		if a.begins_with("n="):
			n = int(a.trim_prefix("n="))
		elif a.begins_with("seed="):
			rs = int(a.trim_prefix("seed="))
		elif a.begins_with("out="):
			out_path = a.trim_prefix("out=")
	var r := RandomNumberGenerator.new()
	r.seed = rs
	var lg := Legion.new()
	Legion.pvp_hero_srv = true                 # сервер знает героя (иначе игра убирает героев из отряда соперника)
	var list := []
	var wins := 0
	var heroes := 0
	for i in n:
		var att := _snap(r)
		var def := _snap(r)
		var sd := r.randi_range(1, 0xfffffe)
		# отряды — как их получает игра от сервера: через JSON (числа — дробные, облик героя — словарь)
		var opp := {"name": "Проба", "rating": 0, "city_level": 6, "snapshot": JSON.parse_string(JSON.stringify(def)), "attack": JSON.parse_string(JSON.stringify(att)), "seed": sd}
		var setup := lg.make_pvp_battle(opp)
		heroes += int(not Legion.snap_hero_entry(att).is_empty()) + int(not Legion.snap_hero_entry(def).is_empty())
		var sim := LegionSim.new(setup)
		# «игрок»: «Авто» с начала в части боёв; умения — в случайные шаги (часть нажатий не срабатывает — так и в игре)
		if r.randf() < 0.3:
			sim.set_auto(true)
		var press_p: float = [0.0, 0.004, 0.02, 0.08][r.randi_range(0, 3)]
		while sim.result.is_empty():
			if r.randf() < press_p:
				sim.press(String(Legion.PERK_IDS[r.randi_range(0, Legion.PERK_IDS.size() - 1)]))
			if r.randf() < 0.002:
				sim.set_auto(not bool(sim.auto["ally"]))
			sim.step(LegionSim.DT)
			sim.events.clear()
		var res := sim.result
		if bool(res["win"]):
			wins += 1
		list.append({"att": att, "def": def, "seed": sd, "inputs": res["inputs"], "win": bool(res["win"]), "alive": int(res["alive"]),
			"total": int(res["total"]), "steps": sim.steps, "time": _hex(float(res["time"])), "hp_left": _hex(float(res["hp_left"]))})
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(list))
	f.close()
	print("SIMDUMP %d боёв (побед нападающего %d, отрядов с героем %d) → %s" % [n, wins, heroes, out_path])
	quit()


## Отряд, как его хранит сервер: рода войск и уровни, умения, бонусы чудес (округлены до тысячных)
func _snap(r: RandomNumberGenerator) -> Dictionary:
	var sq := []
	var base := r.randi_range(1, 30)
	for i in r.randi_range(1, 7):
		sq.append({"type": TYPES[r.randi_range(0, TYPES.size() - 1)], "level": clampi(base + r.randi_range(-3, 3), 1, 40)})
	var hk := r.randf()
	if hk < 0.45:
		# свой герой на первом месте (вместо бойца этого места)
		var h := {"type": "hero", "level": clampi(base + r.randi_range(-2, 2), 1, 40), "city": r.randi_range(0, 7), "kit": r.randi_range(0, 10),
			"name": "Гай Валерий", "look": {"sx": 0, "mdl": "SK_Chr_Upperclass_Male_01", "skin": "B", "hair": 3, "main": "a3283a", "cape": "2f5585"}}
		if sq.size() >= 2:
			sq[0] = h
		else:
			sq.push_front(h)
	elif hk < 0.5:
		sq.insert(mini(1, sq.size()), {"type": "hero", "level": 30, "city": 7, "kit": 10})   # не на первом месте — не в счёт
	var perks := {}
	for p in Legion.PERK_IDS:
		if r.randf() < 0.5:
			perks[p] = r.randi_range(1, 5)
	return {"v": 1, "squad": sq, "perks": perks, "atk_b": BONUS[r.randi_range(0, BONUS.size() - 1)], "hp_b": BONUS[r.randi_range(0, BONUS.size() - 1)]}


## Точное значение числа (8 байт double) — для сравнения до бита
static func _hex(x: float) -> String:
	return PackedFloat64Array([x]).to_byte_array().hex_encode()
