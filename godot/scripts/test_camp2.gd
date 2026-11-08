extends SceneTree
## Поход Легиона 2.0 (10 провинций × 15 боёв): проверка без графики.
##   Godot_console.exe --headless --path godot --script res://scripts/test_camp2.gd -- [mode=check] [seeds=8]
## mode=check — устройство похода (150 боёв, младшие и главные боссы, Принципия открывает провинции) и приёмы
##              боссов: каждый приём в бою срабатывает (события боя), «обычный игрок» на рекомендованном уровне
##              побеждает босса хотя бы в половине боёв (печатает «CAMP2 DONE fails=N»)
## mode=events — для каждого босса: какие события и сколько раз (для наладки)

var args := {}
var fails := 0


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	Legion.V2 = true
	var seeds := int(args.get("seeds", "8"))
	_check(Legion.regions().size() == 10 and Legion.stages() == 15, "10 провинций по 15 боёв")
	var bosses := 0
	var juniors := 0
	for r in 10:
		for s in 15:
			var st := Legion.stage(0, r, s)
			bosses += 1 if bool(st["boss"]) else 0
			juniors += 1 if bool(st["junior"]) else 0
			for w: Array in st["waves"]:
				for k in w:
					_check(Legion.ENEMIES.has(k), "враг %s есть" % k)
	_check(bosses == 10 and juniors == 10, "10 главных и 10 младших боссов (%d / %d)" % [bosses, juniors])
	_check(Legion.stage_index(0, 9, 14) == 149, "последний бой — 150-й")
	# какие события ждём от каждого босса
	var want := {"spartacus": "summon", "salassi": "avalanche", "vercingetorix": "cry|interrupt", "arminius": "summon", "boudicca": "chariot",
		"viriathus": "immune", "hannibal": "ward", "pharaoh": "poison", "surena": "summon", "decebalus": "hit",
		"druidBoss": "heal", "setPriest": "storm", "zalPriest": "heal", "chief": "summon"}
	for r in 10:
		for s: int in [Legion.JUNIOR2, 14]:
			var st := Legion.stage(0, r, s)
			var bk := String(Legion.REGIONS2[r]["boss" if s == 14 else "junior"])
			var ev := {}
			var win := 0
			var tsum := 0.0
			for i in seeds:
				var res := _fight(st, Legion.target_level(0, r, s), 1000 + i * 7919, ev)
				win += 1 if bool(res["win"]) else 0
				tsum += float(res["time"])
			var keys := ev.keys()
			keys.sort()
			var line := ""
			for k in keys:
				line += " %s:%d" % [k, int(ev[k])]
			print("BOSS %d-%2d %-20s побед %3d%% t≈%3.0f |%s" % [r, s, bk, roundi(100.0 * win / seeds), tsum / seeds, line])
			if want.has(bk):
				var ok := false
				for w in String(want[bk]).split("|"):
					ok = ok or int(ev.get(w, 0)) > 0
				_check(ok, "%s: приём сработал (%s)" % [bk, want[bk]])
			if not Legion.TUNE2.is_empty():
				_check(win * 2 >= seeds, "%s: обычный игрок на T побеждает хотя бы в половине боёв (%d из %d)" % [bk, win, seeds])
	print("CAMP2 DONE fails=%d" % fails)
	quit()


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", what)
	elif args.get("v", "0") == "1":
		print("ok ", what)


## Бой «обычного игрока» (как test_legion mode=calibrate v2=1): состав под бой, уровень lvl, вещи и ранги — exp2
func _fight(st: Dictionary, lvl: int, seed_v: int, ev: Dictionary) -> Dictionary:
	var b := int(st["idx"]) / Legion.stages()
	var slots := Legion.SQUAD_BASE
	for sb in Legion.SLOT_BOSSES:
		if b >= int(sb):
			slots += 1
	var have := ["legionary", "archer"]
	if b >= 1:
		have.append("spearman")
	if b >= 3:
		have.append("ballista")
	if b >= 5:
		have.append("catapult")
	var types := Legion.counter_squad(st, have, slots)
	var e := Legion.exp2(int(st["r"]), int(st["s"]))
	var sq := []
	for t in types:
		sq.append(Legion.unit_stats(t, lvl, float(e["atk"]), float(e["hp"]), float(e["armor"])))
	var perks := {}
	for p in Legion.PERK_IDS:
		var since := b - int(Legion.PERKS[p]["boss"])
		if since >= 0:
			perks[p] = clampi(1 + since / 2 + (lvl - 1) / 3, 1, Legion.PERK_MAX)
	var waves := []
	for w: Array in st["waves"]:
		var ws := []
		for k in w:
			ws.append(Legion.foe_stats(st, k))
		waves.append(ws)
	var sim := LegionSim.new({"kind": "campaign", "squad": sq, "waves": waves, "perks": perks, "seed": seed_v,
		"packs": st.get("packs", []), "heal_wave": float(e["heal"])})
	sim.set_auto(true)
	while sim.result.is_empty():
		sim.step(LegionSim.DT)
		for x: Dictionary in sim.take_events():
			var ty := String(x["type"])
			if ty == "warn":
				ty = "warn_" + String(x.get("kind", ""))
			ev[ty] = int(ev.get(ty, 0)) + 1
		for u in sim.units:
			if u.alive and not u.poison.is_empty():
				ev["poison"] = int(ev.get("poison", 0)) + 1
				break
	return sim.result
