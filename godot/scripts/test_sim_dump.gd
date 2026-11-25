extends SceneTree
## Сверка боя на сервере с боем в игре: Godot считает случайные бои с городами (LegionSim, как в 3D-бою:
## Legion.make_pvp_battle с отрядом от сервера, «игрок» жмёт умения и «Авто» в случайные шаги) и пишет их в JSON;
## node server/test_sim.js повторяет каждый на server/legion_sim.js и сравнивает итог до бита.
##   bash .work/py/gpu_run.sh --headless --script res://scripts/test_sim_dump.gd -- n=50 fort=1 out=D:/CivCity/.work/sim_dump.json
##   node server/test_sim.js D:/CivCity/.work/sim_dump.json
## seed=N меняет набор боёв. fort=1 добавляет отряды из сохранений форта и смешанные пары.

const TYPES := ["legionary", "spearman", "archer", "ballista", "catapult"]
const BONUS := [0.0, 0.0, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.35]


func _initialize() -> void:
	var n := 300
	var out_path := "D:/CivCity/.work/sim_dump.json"
	var rs := 20261013
	var fort_cases := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("n="):
			n = int(a.trim_prefix("n="))
		elif a.begins_with("seed="):
			rs = int(a.trim_prefix("seed="))
		elif a.begins_with("out="):
			out_path = a.trim_prefix("out=")
		elif a == "fort=1":
			fort_cases = true
	quit(int(not write_dump(n, out_path, rs, fort_cases)))


static func write_dump(n: int, out_path: String, rs: int, fort_cases: bool) -> bool:
	var r := RandomNumberGenerator.new()
	r.seed = rs
	var lg := Legion.new()
	var old_hero_mode := Legion.pvp_hero_srv
	Legion.pvp_hero_srv = true                 # сервер знает героя (иначе игра убирает героев из отряда соперника)
	var list := []
	var wins := 0
	var heroes := 0
	for i in n:
		var a := _fort_snap(r, i) if fort_cases and i % 5 < 3 else {"snap": _snap(r)}
		var d := _fort_snap(r, i + 1) if fort_cases and i % 5 != 2 and i % 5 != 4 else {"snap": _snap(r)}
		var att: Dictionary = a["snap"]
		var def: Dictionary = d["snap"]
		var sd := r.randi_range(1, 0xfffffe)
		# отряды — как их получает игра от сервера: через JSON (числа — дробные, облик героя — словарь)
		var opp := {"name": "Проба", "rating": 0, "city_level": 6, "snapshot": _wire(def), "attack": _wire(att), "seed": sd}
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
		list.append({"att": att, "def": def, "att_fort": a.get("fort"), "def_fort": d.get("fort"), "seed": sd, "inputs": res["inputs"],
			"win": bool(res["win"]), "alive": int(res["alive"]), "total": int(res["total"]), "steps": sim.steps,
			"timeout": bool(res["timeout"]), "time": _hex(float(res["time"])), "hp_left": _hex(float(res["hp_left"]))})
	Legion.pvp_hero_srv = old_hero_mode
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		print("SIMDUMP FAIL cannot write ", out_path)
		return false
	f.store_string(JSON.stringify(list, "", false, true))
	f.close()
	print("SIMDUMP %d боёв (побед нападающего %d, отрядов с героем %d) → %s" % [n, wins, heroes, out_path])
	return true


## Отряд, как его хранит сервер: рода войск и уровни, умения, бонусы чудес (округлены до тысячных)
static func _snap(r: RandomNumberGenerator) -> Dictionary:
	var sq := []
	var base := r.randi_range(1, 30)
	for i in r.randi_range(1, 7):
		sq.append({"type": TYPES[r.randi_range(0, TYPES.size() - 1)], "level": clampi(base + r.randi_range(-3, 3), 1, 40)})
	var hk := r.randf()
	if hk < 0.45:
		# Старый клиент ставил героя на первое место (вместо бойца этого места).
		var h := {"type": "hero", "level": clampi(base + r.randi_range(-2, 2), 1, 40), "city": r.randi_range(0, 7), "kit": r.randi_range(0, 10),
			"name": "Гай Валерий", "look": {"sx": 0, "mdl": "SK_Chr_Upperclass_Male_01", "skin": "B", "hair": 3, "main": "a3283a", "cape": "2f5585"}}
		if sq.size() >= 2:
			sq[0] = h
		else:
			sq.push_front(h)
	var perks := {}
	for p in Legion.PERK_IDS:
		if r.randf() < 0.5:
			perks[p] = r.randi_range(1, 5)
	return {"v": 1, "squad": sq, "perks": perks, "atk_b": BONUS[r.randi_range(0, BONUS.size() - 1)], "hp_b": BONUS[r.randi_range(0, BONUS.size() - 1)]}


## Клиент считает числа сам, сервер отдельно восстанавливает их из того же состава и предметов.
static func _fort_snap(r: RandomNumberGenerator, case_id: int) -> Dictionary:
	var city := City.new(Land.new())
	city.cozy_v = 1
	city.legion_v = 3
	city.hero = Hero.make("Гай Валерий", 0, {}, true, 77)
	var lg: Legion = city.legion
	lg._fort_init()
	lg.fort["starter_pending"] = false
	lg.fort["know"] = {"smith": true, "weap3": true, "armor1": true, "armor3": true, "outfit": true, "outfit2": true}
	var room := r.randi_range(1, 12)
	lg.fort["plots"] = [{"b": "barracks", "lv": room}, {"b": "hq", "lv": 6}]
	lg.soldiers.clear()
	lg.items.clear()
	lg.squad3 = [1, 2, 3, 4, 5]
	var weapons := ["sword", "bow", "staff", "spear"]
	for place in 5:
		var sid := place + 1
		var is_hero := place == 3
		var weapon: String = weapons[(place + case_id) % weapons.size()]
		var cls: String = Gear.KIND_CLS[weapon]
		var rank := 39 if place == 0 else r.randi_range(10, 49)
		var person := {"id": sid, "name": "Боец", "cls": cls, "stars": r.randi_range(1, 5), "rank": rank, "hero": is_hero,
			"tal": [r.randi_range(0, 1), r.randi_range(0, 1), r.randi_range(0, 1), r.randi_range(0, 1), r.randi_range(0, 1)], "gear": {}}
		lg.soldiers.append(person)
		for kind: String in [weapon, "helmet", "armor", "offhand", "cook"]:
			var tier := 3 if place == 0 else r.randi_range(1, 10)
			var item := Gear.craft_item(kind, tier, r.randi_range(0, 4))
			var iid := lg.items.size() + 1
			item["id"] = iid
			item["on"] = sid
			if place % 2 == 0:
				item["set"] = Gear.SET_IDS[(case_id + place) % Gear.SET_IDS.size()]
			person["gear"][item["slot"]] = iid
			lg.items.append(item)
	lg.perks = {"oil": 2, "bandage": 1, "testudo": 2, "volley": 1, "horn": 2}
	var snap := lg.pvp_snapshot()
	return {"snap": snap, "fort": {"fort": lg.fort, "soldiers": lg.soldiers, "items": lg.items, "squad3": lg.squad3}}


static func _wire(snap: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(snap, "", false, true))


## Точное значение числа (8 байт double) — для сравнения до бита
static func _hex(x: float) -> String:
	return PackedFloat64Array([x]).to_byte_array().hex_encode()
