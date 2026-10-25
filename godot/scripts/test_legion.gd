extends SceneTree
## Проверка Легиона без графики (как старые прогоны node для js/army.js):
##   Godot_console.exe --headless --path godot --script res://scripts/test_legion.gd -- mode=… [seeds=20] [cycles=1] [regions=0,1,…] [only=0,4,9]
## mode=api       — весь путь на настоящем городе: исследование, Казармы, прокачка по таймеру, бой, награда, босс,
##                  сохранение через JSON, чудеса, триумф, бой с городом (печатает ok/FAIL и «ИТОГ»)
## mode=target    — доля побед на рекомендованном уровне T и на T−1 (perks=0 — без умений, off=1 — сдвиг уровня)
## mode=calibrate — подгонка Legion.TUNE (cycle=0) или Legion.TUNE_C (cycle=1): печатает строки таблиц
##                  (цель: с умениями ≥need=0.9 на T, без умений ≥need_np=0.4 на T+np_off=1)
## mode=need      — для каждого боя: с какого уровня отряд побеждает в ≥75% боёв
## mode=one       — один бой stage=c-r-s на уровне lvl: доля побед, звёзды, время
## mode=squads    — лес: «Лучший состав» под бой против «не того» отряда, без умений, без лучников, звёзды (check=1 — проверка)
## mode=tut       — учебный первый бой (0-0-0, шайка кучей): три легионера lvl (1), масло там, где бой замирает,
##                  без масла и с «Авто»; печатает доли побед и сколько врагов накрыло масло
## Состав и умения — как у игрока, дошедшего до боя (места и рода войск открываются боссами); умения жмёт сам бой
## (auto) — как внимательный игрок. noarcher=1 — без лучников (до исследования «Стрельбище»); пока мест три
## (лес) — и так три легионера, как собирает «Лучший состав» (bow=1 — с лучником; mode=tut archer=1 — то же в учебном бою).

const WIN_NEED := 0.75
## Обычный уровень бойцов игрока, который подходит к провинции (с учётом предела города: Посёлок → 3, Городок → 4,
## Город → 6, Большой город → 8, Вечный город → 10)
const EXPECT := [2, 4, 5, 6, 7, 8, 9, 10]

var args := {}


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var seeds := int(args.get("seeds", "12"))
	var cycles := int(args.get("cycles", "1"))
	var mode: String = args.get("mode", "need")
	if args.has("growth"):
		Legion.STAGE_GROWTH = float(args["growth"])
	if args.has("bgrowth"):
		Legion.BOSS_GROWTH = float(args["bgrowth"])
	if args.has("wr"):
		Legion.WAVE_R = float(args["wr"])
	if args.has("wd"):
		Legion.WAVE_DIV = float(args["wd"])
	if args.has("wm"):
		Legion.WAVE_MAX = int(args["wm"])
	if args.has("bite"):
		Legion.BITE = float(args["bite"])
	if args.has("kite"):
		Legion.KITE = float(args["kite"])
	if args.has("bush"):
		Legion.BUSH = float(args["bush"])
	if args.has("bshot"):
		Legion.BUSH_SHOT = float(args["bshot"])
	var only: Array = []
	if args.has("only"):
		for x in String(args["only"]).split(","):
			only.append(int(x))
	var t0 := Time.get_ticks_msec()
	var regions: Array = []
	for x in String(args.get("regions", "0,1,2,3,4,5,6,7")).split(","):
		regions.append(int(x))
	if args.has("notune"):
		Legion.TUNE = []
	if args.has("set"):
		# set=r,s,множитель — подменить одну клетку TUNE (подбор вручную)
		var sv: PackedStringArray = String(args["set"]).split(",")
		Legion.TUNE[int(sv[0])][int(sv[1])] = float(sv[2])
	match mode:
		"calibrate":
			# множитель силы врагов, при котором отряд на уровне target_level побеждает в ≥80% боёв
			var cyc := int(args.get("cycle", "0"))
			if cyc == 0:
				Legion.TUNE = []
			elif cyc == 1:
				Legion.TUNE_C = []
			for r: int in regions:
				var row := []
				var info := ""
				for s in Legion.STAGES:
					if not only.is_empty() and not s in only:
						continue
					var T := Legion.target_level(cyc, r, s)
					var lo := 0.12
					var hi := 8.0
					for it in 10:
						var mid := sqrt(lo * hi)
						if _ok_m(cyc, r, s, T, mid, seeds):
							lo = mid
						else:
							hi = mid
					row.append(snappedf(lo, 0.01))
					info += " %d:%d%%/%d%%/%d%%" % [T, roundi(float(_rate_m(cyc, r, s, T, lo, seeds)["win"]) * 100), roundi(float(_rate_m(cyc, r, s, maxi(1, T - 1), lo, seeds)["win"]) * 100),
					roundi(float(_rate_m(cyc, r, s, T + int(args.get("np_off", "1")), lo, seeds, false)["win"]) * 100)]
				print("	%s,   # %s %s" % [str(row), Legion.REGIONS[r]["name"], info])
		"target":
			# доля побед на целевом уровне и на уровень ниже (с подгонкой TUNE)
			for c in range(int(args.get("from", "0")), cycles):
				for r: int in regions:
					var line := "%-22s|" % (Legion.REGIONS[r]["name"] + (" " + Legion.roman(c + 1) if c > 0 else ""))
					for s in Legion.STAGES:
						if not only.is_empty() and not s in only:
							continue
						var T := Legion.target_level(c, r, s)
						var st := Legion.stage(c, r, s)
						var pk: bool = args.get("perks", "1") == "1"
						T += int(args.get("off", "0"))
						var a := roundi(float(_rate(st, mini(Legion.MAX_LEVEL, T), seeds, pk)["win"]) * 100)
						var b := roundi(float(_rate(st, maxi(1, T - 1), seeds, pk)["win"]) * 100)
						line += " %2d:%3d/%3d" % [T, a, b]
					print(line)
		"squads":
			# лес — загадка на выбор отряда: на уровне T с «Лучшим составом» (с умениями и без), «не тем» отрядом
			# (лучник ⇄ легионер), без лучников вовсе; звёзды: все вернулись, задание, масло, время и здоровье (медианы).
			# check=1 — проверка (regress.sh): «Лучший состав» с умениями ≥90%, в боях-загадках (squad bow/leg) «не тот» ≤60%
			var sq_fails := 0
			for r: int in regions:
				for s in Legion.STAGES:
					if not only.is_empty() and not s in only:
						continue
					var cyc := int(args.get("cycle", "0"))
					var T := Legion.target_level(cyc, r, s) + int(args.get("off", "0"))
					var st := Legion.stage(cyc, r, s)
					var good := _rate(st, T, seeds, true)
					var np := _rate(st, T, seeds, false)
					args["wrong"] = "1"
					var bad := _rate(st, T, seeds, true)
					args.erase("wrong")
					args["noarcher"] = "1"
					var nob := _rate(st, T, seeds, true)
					args.erase("noarcher")
					var bow := "лук" if Legion.wants_archer(st) else "лег"
					print("SQ %d-%d %-22s T%d %s | верно %3d%% без умений %3d%% | не тот %3d%% | без лучников %3d%% | ★%.1f все %3d%% задание %3d%% (%s %d) масло %.1f t50 %.0f hp50 %d%%" % [
						r, s, String(st["theme"]) if String(st["theme"]) != "" else String(st["name"]), T, bow, roundi(float(good["win"]) * 100),
						roundi(float(np["win"]) * 100), roundi(float(bad["win"]) * 100), roundi(float(nob["win"]) * 100), float(good["stars"]),
						roundi(float(good["safe"]) * 100), roundi(float(good["task"]) * 100), String(Legion.task_of(st)[0]), int(Legion.task_of(st)[1]),
						float(good["oil"]), float(good["t50"]), roundi(float(good["hp50"]) * 100)])
					if args.get("check", "0") == "1":
						var puzzle := String(st.get("squad", "")) in ["bow", "leg"] and s > 0
						if float(good["win"]) < 0.9 or (puzzle and float(bad["win"]) > 0.6):
							sq_fails += 1
							print("FAIL SQ %d-%d: верно %d%%, не тот %d%%" % [r, s, roundi(float(good["win"]) * 100), roundi(float(bad["win"]) * 100)])
			if args.get("check", "0") == "1":
				print("SQUADS DONE fails=%d" % sq_fails)
		"tasks":
			# задание на третью звезду выполнимо (иначе сундук провинции за 30 звёзд не открыть): «масло N+» — терпеливый
			# игрок бережёт масло, пока враги не собьются в кучу (бой без масла, после первой готовности котла хоть раз
			# N+ врагов под котлом), «здоровье N%» и «быстрее N с» — на уровне выше рекомендованного (T+up, up=2, не выше
			# предела города), с умениями. check=1 — проверка: в каждом бою задание даётся хотя бы в half=0.5 боёв
			var tk_fails := 0
			var cyc := int(args.get("cycle", "0"))
			var up := int(args.get("up", "2"))
			for r: int in regions:
				var line := "%-22s|" % Legion.REGIONS[r]["name"]
				for s in Legion.STAGES:
					if not only.is_empty() and not s in only:
						continue
					var st := Legion.stage(cyc, r, s)
					var t := Legion.task_of(st)
					var T := Legion.target_level(cyc, r, s)
					var p := 0.0
					if String(t[0]) == "oil":
						p = _oil_room(st, T, seeds, int(t[1]))
					else:
						var lv := mini(T + up, int(Legion.CAP_BY_CITY[int(Legion.REGIONS[r]["rank"])]) + cyc * Legion.CYCLE_CAP)
						var rr := _rate(st, mini(Legion.MAX_LEVEL, lv), seeds, true)
						p = float(rr["task"]) * float(rr["win"])
					line += " %s%d:%3d" % [String(t[0]).left(1), int(t[1]), roundi(p * 100)]
					if p < float(args.get("half", "0.5")):
						tk_fails += 1
						print("FAIL TASK %d-%d-%d %s: %d%%" % [cyc, r, s, str(t), roundi(p * 100)])
				print(line)
			print("TASKS DONE fails=%d" % tk_fails)
		"api":
			_api()
		"tut":
			var lv := int(args.get("lvl", "1"))
			var arch: bool = args.get("archer", "0") == "1"
			for how in ["freeze", "freeze_early", "freeze_auto", "early", "none", "auto"]:
				var tr := _tut_rate(how, seeds, lv, arch)
				print("TUT %-12s ур.%d%s: побед %d%%, масло накрыло в среднем %.1f, здоровья осталось %d%%, время %.0f с" % [how, lv,
					" с лучником" if arch else "", roundi(float(tr["win"]) * 100), float(tr["hit"]), roundi(float(tr["hp"]) * 100), float(tr["time"])])
		"one":
			var p: PackedStringArray = String(args.get("stage", "0-0-0")).split("-")
			var st := Legion.stage(int(p[0]), int(p[1]), int(p[2]))
			var lvl := int(args.get("lvl", "1"))
			var r := _rate(st, lvl, seeds, args.get("perks", "1") == "1")
			print("%s %s: ур.%d — побед %d%%, звёзды %.1f, время %.0f с, здоровья осталось %d%%, не успели %d%%" % [st["key"], st["name"], lvl, roundi(r["win"] * 100), r["stars"], r["time"], roundi(r["hp"] * 100), roundi(r["timeout"] * 100)])
		"table":
			for c in cycles:
				for r in Legion.REGIONS.size():
					var line := "%-22s" % (Legion.REGIONS[r]["name"] + (" " + Legion.roman(c + 1) if c > 0 else ""))
					var lvl: int = mini(Legion.MAX_LEVEL, int(EXPECT[r]) + c * 2)
					line += " ур.%2d |" % lvl
					for s in Legion.STAGES:
						var st := Legion.stage(c, r, s)
						var rr := _rate(st, lvl, seeds, true)
						line += " %3d" % roundi(rr["win"] * 100)
					print(line)
		_:
			print("Бой: уровень, с которого побед ≥%d%% (n=%d боёв на точку). Ниже — сила отряда/врага на этом уровне." % [roundi(WIN_NEED * 100), seeds])
			for c in cycles:
				for r in Legion.REGIONS.size():
					var line := "%-22s|" % (Legion.REGIONS[r]["name"] + (" " + Legion.roman(c + 1) if c > 0 else ""))
					var lo := 1
					for s in Legion.STAGES:
						if not only.is_empty() and not s in only:
							continue
						var st := Legion.stage(c, r, s)
						var need := 0
						for lvl in range(lo, Legion.MAX_LEVEL + 1):
							var rr := _rate(st, lvl, seeds, true)
							if float(rr["win"]) >= WIN_NEED:
								need = lvl
								break
						line += (" %2d" % need) if need > 0 else "  -"
						if need > 0:
							lo = maxi(1, need - 2)
					print(line)
	print("(%.1f с)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit()


## Состав и умения игрока, который дошёл до боя st: места и рода войск открываются боссами (как в игре)
func _player(st: Dictionary, lvl: int, with_perks: bool) -> Dictionary:
	var idx: int = st["idx"]
	var b := idx / Legion.STAGES                   # боссов побеждено до этого боя
	var slots := Legion.SQUAD_BASE
	for sb in Legion.SLOT_BOSSES:
		if b >= int(sb):
			slots += 1
	var have := ["legionary"] if args.get("noarcher", "0") == "1" else ["legionary", "archer"]
	if b >= 1:
		have.append("spearman")
	if b >= 3:
		have.append("ballista")
	if b >= 5:
		have.append("catapult")
	# как Legion.auto_squad («Лучший состав» под бой); пока мест три — нарочно «не тот» отряд: wrong=1 (лучник против
	# волков, три легионера против пращников), bow=1 — всегда с лучником, leg3=1 — всегда три легионера
	var types := Legion.counter_squad(st, have, slots)
	if slots <= Legion.SQUAD_BASE:
		var with_bow := "archer" in types
		if args.get("wrong", "0") == "1":
			with_bow = not with_bow
		if args.get("bow", "0") == "1":
			with_bow = true
		if args.get("leg3", "0") == "1":
			with_bow = false
		types = ["legionary", "archer", "legionary"] if with_bow else ["legionary", "legionary", "legionary"]
	var sq := []
	for t in types:
		sq.append(Legion.unit_stats(t, lvl))
	var perks := {}
	if with_perks:
		for p in Legion.PERK_IDS:
			var since := b - int(Legion.PERKS[p]["boss"])
			if since >= 0:
				perks[p] = clampi(1 + since / 2 + (lvl - 1) / 3, 1, Legion.PERK_MAX)
	return {"squad": sq, "perks": perks}


## Доля побед в бою (c, r, s) на уровне lvl, если силу врагов умножить на m (без подгонки TUNE)
func _rate_m(c: int, r: int, s: int, lvl: int, m: float, seeds: int, perks := true) -> Dictionary:
	var st := Legion.stage(c, r, s)
	var bs := Legion.base_scales(c, r, s, c > 0)
	st["scale"] = float(bs[0]) * m
	st["boss_scale"] = float(bs[1]) * m
	return _rate(st, lvl, seeds, perks)


## Подгонка: на рекомендованном уровне с умениями побед ≥ need (90%), без умений на уровень выше (np_off) — ≥ need_np (40%)
func _ok_m(c: int, r: int, s: int, T: int, m: float, seeds: int) -> bool:
	if float(_rate_m(c, r, s, T + int(args.get("np_off", "1")), m, seeds, false)["win"]) < float(args.get("need_np", "0.4")):
		return false
	return float(_rate_m(c, r, s, T, m, seeds)["win"]) >= float(args.get("need", "0.9"))


func _rate(st: Dictionary, lvl: int, seeds: int, with_perks: bool) -> Dictionary:
	var pl := _player(st, lvl, with_perks)
	var waves := []
	for w: Array in st["waves"]:
		var ws := []
		for k in w:
			ws.append(Legion.foe_stats(st, k))
		waves.append(ws)
	var win := 0
	var stars := 0.0
	var tm := 0.0
	var hp := 0.0
	var tout := 0
	var safe := 0
	var task := 0
	var oil := 0.0
	var wtimes := []
	var whp := []
	for i in seeds:
		var sim := LegionSim.new({"kind": "campaign", "squad": pl["squad"], "waves": waves, "perks": pl["perks"], "seed": 1000 + i * 7919,
			"packs": st.get("packs", [])})
		var r := sim.run(true)
		if r["win"]:
			win += 1
			var m := Legion.star_mask(r, st)
			stars += Legion.star_count(m)
			safe += 1 if (m & Legion.STAR_SAFE) != 0 else 0
			task += 1 if (m & Legion.STAR_TASK) != 0 else 0
			hp += float(r["hp_left"])
			oil += float(r["oil_best"])
			wtimes.append(float(r["time"]))
			whp.append(float(r["hp_left"]))
		tm += float(r["time"])
		if r["timeout"]:
			tout += 1
	wtimes.sort()
	whp.sort()
	return {"win": float(win) / seeds, "stars": stars / maxf(1.0, win), "time": tm / seeds, "hp": hp / maxf(1.0, win), "timeout": float(tout) / seeds,
		"safe": float(safe) / maxf(1.0, win), "task": float(task) / maxf(1.0, win), "oil": oil / maxf(1.0, win),
		"t50": float(wtimes[wtimes.size() / 2]) if not wtimes.is_empty() else 0.0, "hp50": float(whp[whp.size() / 2]) if not whp.is_empty() else 0.0}


## Доля боёв, где терпеливый игрок может накрыть маслом n+ врагов разом: бой без масла (остальные умения — «Авто»),
## после первой готовности котла хоть раз n+ врагов в куче (как считает котёл: в 2 м от одного из них)
func _oil_room(st: Dictionary, lvl: int, seeds: int, n: int) -> float:
	var pl := _player(st, lvl, true)
	var pk: Dictionary = pl["perks"]
	pk.erase("oil")
	var waves := []
	for w: Array in st["waves"]:
		var ws := []
		for k in w:
			ws.append(Legion.foe_stats(st, k))
		waves.append(ws)
	var t_ready := float(Legion.PERKS["oil"]["cd"]) * 0.5
	var ok := 0
	for i in seeds:
		var sim := LegionSim.new({"kind": "campaign", "squad": pl["squad"], "waves": waves, "perks": pk, "seed": 1000 + i * 7919,
			"packs": st.get("packs", [])})
		sim.set_auto(true)
		var best := 0
		while sim.result.is_empty() and best < n:
			sim.step(LegionSim.DT)
			sim.events.clear()
			if sim.t < t_ready:
				continue
			var foes := sim.alive_of("enemy")
			for o in foes:
				var c := 0
				for q in foes:
					if Vector2(q.x - o.x, q.z - o.z).length() < 2.0:
						c += 1
				best = maxi(best, c)
		sim.dispose()
		if best >= n:
			ok += 1
	return float(ok) / seeds


## Учебный бой 0-0-0 (как в игре: шайка кучей, setup.packs): три легионера уровня lvl с маслом 1 ур.
## (arch — легионер, лучник, легионер: старое сохранение со Стрельбищем).
## how: freeze — масло ровно тогда, когда вторая волна вышла на поле (там 3D-бой замирает), потом умения никто не жмёт;
## freeze_early — масло сразу, как засветилось (~7 с, первая волна), потом всё равно замирание (оно заново кипятит котёл);
## freeze_auto — замирание, потом «Авто»; early — без замирания: жмёт масло всякий раз, как засветится;
## none — без масла; auto — «Авто» с начала (повтор пройденного боя)
func _tut_rate(how: String, seeds: int, lvl: int, arch := false) -> Dictionary:
	var st := Legion.stage(0, 0, 0)
	var waves := []
	for w: Array in st["waves"]:
		var ws := []
		for k in w:
			ws.append(Legion.foe_stats(st, k))
		waves.append(ws)
	var sq := []
	for t in (["legionary", "archer", "legionary"] if arch else ["legionary", "legionary", "legionary"]):
		sq.append(Legion.unit_stats(t, lvl))
	var win := 0
	var hit := 0
	var hp := 0.0
	var tm := 0.0
	for i in seeds:
		var sim := LegionSim.new({"kind": "campaign", "squad": sq, "waves": waves, "perks": {} if how == "none" else {"oil": 1},
			"seed": 1000 + i * 7919, "packs": st["packs"]})
		sim.set_auto(how == "auto")
		var pressed := false
		var early := false
		while sim.result.is_empty():
			sim.step(LegionSim.DT)
			sim.events.clear()
			if (how == "early" or (how == "freeze_early" and not early)) and float(sim.perks["ally"]["oil"]["ready"]) <= 0.0:
				sim.press("oil")
				early = true
				for e: Dictionary in sim.events:
					if String(e["type"]) == "hit" and e.get("from") == null:
						hit += 1
				sim.events.clear()
			if how.begins_with("freeze") and not pressed and sim.wave_idx >= 1:
				var n := 0
				var all_in := true
				for u in sim.units:
					if u.side == "enemy" and u.wave == sim.wave_idx and u.alive:
						n += 1
						if u.entering:
							all_in = false
				if all_in and n > 0:
					sim.perks["ally"]["oil"]["ready"] = 0.0
					sim.press("oil")
					for e: Dictionary in sim.events:
						if String(e["type"]) == "hit" and e.get("from") == null:
							hit += 1
					pressed = true
					if how == "freeze_auto":
						sim.set_auto(true)
		if sim.result["win"]:
			win += 1
			hp += float(sim.result["hp_left"])
		tm += float(sim.result["time"])
	return {"win": float(win) / seeds, "hit": float(hit) / seeds, "hp": hp / maxf(1.0, win), "time": tm / seeds}


# =====================================================================
#   проверка API на настоящем городе (mode=api)
# =====================================================================

var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _api() -> void:
	var land := Land.new()
	var city := City.new(land)
	city.place("center", Land.CENTER, PI / 2, 0, 0, true)
	var L: Legion = city.legion
	_check(not L.window_open() and L.lock_text().contains("Разбойники у арки") and L.lock_text().contains("Хутор"), "окно закрыто, пока Легион не открыт историей: " + L.lock_text())
	# Д9: Легион с «Хутора» через историю «Разбойники у арки» (без очков), лес — там же, предел бойцов не ниже самого трудного боя
	_check(int(Defs.research("legion")["lvl"]) == int(Legion.REGIONS[0]["rank"]) and int(Legion.REGIONS[0]["rank"]) == 1 and Defs.research("legion").has("story")
		and city.can_research("legion").contains("Разбойники у арки"), "«Легион» — история на «%s», там же открыт лес; за очки не изучить: «%s»" % [
		Defs.LEVELS[int(Defs.research("legion")["lvl"])]["name"], city.can_research("legion")])
	var ranks := []
	var walls := []
	for r in Legion.REGIONS.size():
		var rk := int(Legion.REGIONS[r]["rank"])
		ranks.append(rk)
		var mx := 0
		for s in Legion.STAGES:
			mx = maxi(mx, Legion.target_level(0, r, s))
		if mx > int(Legion.CAP_BY_CITY[rk]):
			walls.append("%s: бой %d ур. > предел %d" % [Legion.REGIONS[r]["name"], mx, int(Legion.CAP_BY_CITY[rk])])
	_check(ranks == [1, 3, 5, 5, 6, 6, 7, 7] and walls.is_empty(), "провинции по уровням города %s, стен нет %s" % [ranks, walls])
	_check(int(L.perks["oil"]) == 1 and L.open_perks().has("oil"), "«Кипящее масло» — с первого дня")
	city.level = 1
	city.research["legion"] = true
	_check(L.window_open(), "окно открыто после «Легиона»")
	# «Стрельбище» — в ряду «Деревни», после «Легиона» из истории (прежние 480 очков не нужны)
	city.level = 2
	city.rp = 500.0
	_check(city.can_research("archery") == "" and int(Defs.research("archery")["lvl"]) == 2, "«Стрельбище» можно изучить после истории: «%s»" % city.can_research("archery"))
	city.level = 1
	_check(city.unlocked("barracks") and not city.unlocked("range"), "Казармы — исследованием «Легион», Стрельбище — «Стрельбищем»")
	_check(not city.unlocked("spearcamp") and Defs.unlock_text("boss1").contains("Атаман"), "Лагерь копейщиков закрыт до первого босса: " + Defs.unlock_text("boss1"))
	# обучение: шаги выводятся из состояния игры
	_check(L.tut_step() == "barracks", "обучение, шаг 1 — Казармы: «%s»" % L.tut_step())
	var p := Land.CENTER + Vector2(14, 12)
	city.place("barracks", p, 0.0, 0, -1, true)
	_check(L.tut_step() == "medal", "шаг 2 — медальон: «%s»" % L.tut_step())
	L.flags["seen"] = true
	_check(L.tut_step() == "fight", "шаг 3 — учебный бой: «%s»" % L.tut_step())
	_check(L.available("legionary") and not L.available("archer"), "легионеры доступны с Казармами, лучники — нет: " + L.unit_lock_text("archer"))
	var chk := city.check_place("barracks", p + Vector2(30, 0), 0.0)
	_check(String(chk["err"]) == "Такая постройка в городе уже есть", "вторые Казармы нельзя: " + String(chk["err"]))
	# лес, три места — загадка на выбор отряда: «Лучший состав» под бой — с лучником против пращников, три легионера
	# против волков и шайки (учебный бой — на трёх легионерах); «не тот» отряд — честное предупреждение в шансах и совет
	_check(L.squad_hint(L.stage_info(0, 0, 1)).contains("Стрельбище"), "без Стрельбища: «%s»" % L.squad_hint(L.stage_info(0, 0, 1)))
	var rng_b := city.place("range", p + Vector2(0, 26), 0.0, 0, -1, true)
	var sq0 := L.auto_squad(L.stage_info(0, 0, 0))
	var sq1 := L.auto_squad(L.stage_info(0, 0, 1))
	var sq2 := L.auto_squad(L.stage_info(0, 0, 2))
	_check(L.available("archer") and sq0 == ["legionary", "legionary", "legionary"] and sq1 == ["legionary", "archer", "legionary"]
		and sq2 == ["legionary", "legionary", "legionary"], "«Лучший состав» под бой: учебный %s, пращники %s, волки %s" % [str(sq0), str(sq1), str(sq2)])
	L.squad = ["legionary", "legionary", "legionary"]
	var od1 := L.odds(L.stage_info(0, 0, 1))
	var h1 := L.squad_hint(L.stage_info(0, 0, 1))
	var e1 := L.odds_estimate(L.stage_info(0, 0, 1))
	var oe1 := L.odds(L.stage_info(0, 0, 1), e1)
	L.squad = ["legionary", "archer", "legionary"]
	L.levels["legionary"] = 2                      # волчья тропа — на её уровне (2)
	L.levels["archer"] = 2
	var h2 := L.squad_hint(L.stage_info(0, 0, 2))
	var e2 := L.odds_estimate(L.stage_info(0, 0, 2))
	var oe2 := L.odds(L.stage_info(0, 0, 2), e2)
	L.levels["legionary"] = 1
	L.levels["archer"] = 1
	L.squad = ["legionary", "legionary", "legionary"]
	_check(String(od1[1]).contains("не под этот бой") and h1.contains("лучника") and h2.contains("загрызут") and L.squad_hint(L.stage_info(0, 0, 0)) == "",
		"«не тот» отряд: шансы «%s», советы «%s» / «%s»" % [String(od1[1]), h1, h2])
	_check(e1.has("best") and float(e1["best"]) > float(e1["cur"]) and String(oe1[1]).contains("с лучником")
		and e2.has("best") and float(e2["best"]) > float(e2["cur"]) and String(oe2[1]).contains("тремя легионерами"),
		"оценка шансов прогоном боёв: пращники «%s», волки с лучником «%s»" % [String(oe1[1]), String(oe2[1])])
	# советы не зовут тех, кого ещё нет: копейщики и катапульты — после боссов
	var tp := L.tips(Legion.stage(0, 0, 3)) + " " + L.tips(Legion.stage(0, 0, 7)) + " " + L.tips(Legion.stage(0, 0, 9))
	_check(not tp.contains("копейщик") and not tp.contains("катапульт") and Legion.counter_tips(Legion.stage(0, 1, 2)).contains("копейщики"),
		"советы леса без копейщиков и катапульт: «%s»" % tp)
	city.remove(rng_b, false)
	# первый бой похода — учебный: шайка кучей во второй волне, бой замирает на масле (3D-бой)
	var st := L.stage_info(0, 0, 0)
	_check(bool(st["open"]) and bool(st["first"]) and L.can_fight(st) == "", "первый бой открыт, можно в бой")
	var setup := L.make_battle(st, 42)
	_check(String(setup.get("tutorial", "")) == "oil" and setup["packs"] == [1] and (setup["waves"] as Array).size() == 2
		and (setup["waves"][0] as Array).size() == 2 and (setup["waves"][1] as Array).size() == 5, "учебный бой: tutorial=oil, packs=[1], волны 2 + 5")
	var sim0 := LegionSim.new(setup)
	while sim0.wave_idx < 1 and sim0.result.is_empty():
		sim0.step(LegionSim.DT)
	var zs := []
	var xs := []
	for u in sim0.units:
		if u.side == "enemy" and u.wave == 1:
			zs.append(u.z)
			xs.append(u.x)
	if xs.is_empty():
		xs = [0.0]
		zs = [0.0]
	_check(sim0.wave_idx == 1 and xs.size() == 5 and xs.max() - xs.min() < 1.5 and zs.max() - zs.min() <= 0.71, "вторая волна выходит кучей: x %.2f…%.2f, z %.2f…%.2f" % [xs.min(), xs.max(), zs.min(), zs.max()])
	var r1 := LegionSim.new(setup).run(true)
	var r2 := LegionSim.new(setup).run(true)
	_check(r1["win"] == r2["win"] and is_equal_approx(float(r1["time"]), float(r2["time"])), "бой с тем же зерном идёт одинаково (%.2f с)" % float(r1["time"]))
	L.flags["tut_fought"] = true
	_check(L.tut_step() == "troops", "шаг 4 — улучшить бойцов: «%s»" % L.tut_step())
	var g0 := L.glory
	var out := L.apply_result(setup, r1)
	_check(bool(out["win"]) and L.progress == 1 and L.rating == 3 and L.glory > g0 and int(out["stars"]) >= 1, "победа: прогресс 1, рейтинг 3, Слава %.0f, звёзд %d, добыча %s" % [L.glory, int(out["stars"]), str(out["reward"])])
	_check(not (out["next"] as Dictionary).is_empty(), "открылся следующий бой")
	_check(not L.make_battle(L.stage_info(0, 0, 0), 1).has("tutorial") and not L.make_battle(L.stage_info(0, 0, 1), 1).has("tutorial"), "повтор и следующие бои — не учебные")
	# прокачка по настоящим часам (ускорено): 5 минут до 2-го уровня, 30 минут до 3-го
	_check(is_equal_approx(L.upgrade_info("legionary")["time"], 300.0) and Legion.UPGRADE_TIME[3] == 1800, "улучшение до 2 ур. — 5 мин, до 3-го — 30 мин")
	city.money = 5000.0
	L.time_k = 20000.0
	_check(L.can_upgrade("legionary") == "", "можно улучшить легионеров")
	var m0 := city.money
	_check(L.upgrade("legionary") and is_equal_approx(m0 - city.money, 700.0), "улучшение до 2 ур. стоит 700 ден.")
	_check(L.can_upgrade("legionary") == "Уже улучшается", "второй раз — «Уже улучшается»")
	_check(L.tut_step() == "" and String(L.flags.get("tut", "")) == "done", "обучение пройдено: улучшение началось")
	OS.delay_msec(120)
	var ev := L.tick()
	_check(int(L.levels["legionary"]) == 2 and ev.size() == 1, "таймер прошёл — 2 уровень: " + str(ev))
	L.upgrade("legionary")
	OS.delay_msec(300)
	L.tick()
	_check(int(L.levels["legionary"]) == 3 and L.can_upgrade("legionary").begins_with("Предел города"), "предел «Хутора» — 3 ур.: " + L.can_upgrade("legionary"))
	# провинции за уровнем города
	L.progress = 10
	_check(not L.stage_open(0, 1, 0) and L.region_lock_text(1).contains("Посёлок"), "вторая провинция ждёт «Посёлка»: " + L.region_lock_text(1))
	city.level = 3
	_check(L.stage_open(0, 1, 0) and L.cap() == 4, "на «Посёлке» открыта, предел 4")
	city.level = 6
	_check(L.cap() == 8, "на «Большом городе» предел 8")
	# босс: место в отряде, новая постройка (масло уже было)
	L.progress = 9
	var bst := L.stage_info(0, 0, 9)
	var bout := L.apply_result(L.make_battle(bst, 1), {"win": true, "alive": 2, "total": 3, "timeout": false, "time": 50.0})
	_check(bool(bout["boss_beaten"]) and int(L.perks["oil"]) == 1 and L.slots() == 4 and city.unlocked("spearcamp"), "босс побеждён: %s" % str(bout["unlocks"]))
	_slots4_api(city, L, p)
	_tasks_api()
	_stars_api(city, L)
	_threats_api(L)
	# сохранение через JSON
	L.set_slot(3, "legionary")
	L.upg["legionary"] = {"to": 4, "end": Legion.now() + 3600.0, "total": 3600.0}
	var d = JSON.parse_string(JSON.stringify(city.save_data()))
	var city2 := City.new(Land.new())
	city2.load_data(d)
	var L2: Legion = city2.legion
	_check(L2.progress == L.progress and L2.rating == L.rating and is_equal_approx(L2.glory, L.glory) and int(L2.levels["legionary"]) == 3
		and L2.upg.has("legionary") and L2.squad.size() == 4 and int(L2.perks["oil"]) == 1 and L2.stars == L.stars
		and L2.trophies.has("forest") and L2.chests.size() == L.chests.size() and city2.unlocked("trophy_cart")
		and String(L2.flags.get("tut", "")) == "done", "сохранение и загрузка (JSON) — всё на месте, звёзды-биты, сундук и трофей")
	# старые звёзды (v1 — число по выжившим): честно — победа и «все вернулись» (3), задание боя заново
	var L5 := Legion.new()
	L5.from_dict({"v": 1, "stars": {"0-0-0": 3, "0-0-1": 2, "0-0-2": 1}, "progress": 3})
	_check(L5.stars["0-0-0"] == Legion.STAR_WIN | Legion.STAR_SAFE and L5.stars["0-0-1"] == Legion.STAR_WIN and L5.stars["0-0-2"] == Legion.STAR_WIN
		and L5.region_stars(0, 0) == 4 and L5.trophies.is_empty() and L5.progress == 3, "старые звёзды v1 → биты: %s (звёзд %d)" % [str(L5.stars), L5.region_stars(0, 0)])
	# старое сохранение (до этапа 3): масла не было, флагов обучения нет — после загрузки масло есть, обучение позади
	var old := {"levels": {"legionary": 3}, "squad": ["legionary", "legionary", "legionary"], "perks": {"oil": 0}, "progress": 4, "flags": {"seen": true, "advised": true}}
	var L3 := Legion.new()
	L3.from_dict(old)
	_check(int(L3.perks["oil"]) == 1 and String(L3.flags.get("tut", "")) == "done" and L3.flags.has("tut_oil") and L3.progress == 4 and L3.flags.has("seen"),
		"старое сохранение после 1-го боя: масло 1, обучение и учебный бой позади, прогресс и флаги целы")
	var L4 := Legion.new()
	L4.from_dict({"perks": {"oil": 0}, "progress": 0, "flags": {"seen": true}})
	_check(int(L4.perks["oil"]) == 1 and not L4.flags.has("tut") and L4.tutorial_battle(Legion.stage(0, 0, 0).merged({"idx": 0})), "старое сохранение без боёв: учебный бой ещё впереди")
	L4.tut_skip()
	_check(L4.tut_step() == "" and L4.tutorial_battle(Legion.stage(0, 0, 0)) and not L4.flags.has("tut_oil"),
		"«Пропустить обучение» — без стрелок и полосы, но учебный бой (масло) один раз остаётся")
	# чудеса: арка открывается рейтингом походов, стоит Славы
	L.rating = 10
	_check(not city.unlocked("arch"), "арка закрыта без исследования и рейтинга")
	L.rating = 30
	L.glory = 3.0
	city.money = 20000.0                           # арка дороже денариев после прокачки (6000 с этапа 1b) — проверяем именно Славу
	_check(city.unlocked("arch") and L.wonder_state("arch") == "open", "рейтинг 30 открывает Триумфальную арку")
	var ca := city.check_place("arch", p + Vector2(30, 0), 0.0)
	_check(String(ca["err"]).begins_with("Не хватает Славы"), "без Славы арку не поставить: " + String(ca["err"]))
	# триумф и счастье
	L.glory = 20.0
	_check(L.triumph() and L.city_happy() == int(Legion.TRIUMPH["happy"]) and is_equal_approx(L.glory, 5.0), "триумф: +%d%% счастья, Слава 5" % L.city_happy())
	for i in int(Legion.TRIUMPH["hours"]):
		L.on_hour()
	_check(L.city_happy() == 0, "триумф закончился через %d игровых часов" % int(Legion.TRIUMPH["hours"]))
	# чудо без постройки (за рейтинг побед над городами)
	L.pvp_rating = 250
	L.glory = 500.0
	city.money = 50000.0
	_check(L.can_build_wonder("circus") == "" and L.build_wonder("circus") and L.city_happy() == 4, "Большой цирк возведён: +4% счастья городу")
	# бой с городом
	var opp := {"name": "Город Марка", "rating": 300, "city_level": 5, "snapshot": {"v": 1, "squad": [{"type": "legionary", "level": 1}, {"type": "archer", "level": 1}], "perks": {}}}
	var ps := L.make_pvp_battle(opp, 7)
	var pr := LegionSim.new(ps).run(true)
	var c0 := L.pvp_charges_now()
	var r0 := L.pvp_rating
	var po := L.apply_pvp_result(ps, pr)
	_check(L.pvp_charges_now() == c0 - 1 and L.pvp_rating == r0 + int(po["delta"]) and int(po["delta"]) != 0, "бой с городом: победа=%s, рейтинг %+d, добыча %s, зарядов %d" % [str(pr["win"]), int(po["delta"]), str(po["reward"]), L.pvp_charges_now()])
	var snap := L.defense_snapshot()
	_check((snap["squad"] as Array).size() == L.squad_stats().size() and int(snap["power"]) > 0, "снимок обороны: %d бойцов, сила %d" % [(snap["squad"] as Array).size(), int(snap["power"])])
	print("ИТОГ: %s" % ("всё в порядке" if fails == 0 else "%d ошибок" % fails))


## Этап 3b: звёзды за мастерство (биты), +Слава за первые три, все 30 — сундук Славы и трофей «Телега атамана» в город
func _stars_api(city: City, L: Legion) -> void:
	var s1 := L.stage_info(0, 0, 1)
	var m_all := Legion.star_mask({"win": true, "alive": 3, "total": 3, "time": 15.0, "hp_left": 0.5}, s1)
	var m_win := Legion.star_mask({"win": true, "alive": 2, "total": 3, "time": 40.0, "hp_left": 0.5}, s1)
	var tx := Legion.star_texts(s1)
	_check(m_all == Legion.STAR_ALL and m_win == Legion.STAR_WIN and Legion.star_mask({"win": false}, s1) == 0
		and String(tx[0]) == "Победа" and String(tx[1]) == "Все вернулись из боя" and String(tx[2]) == "Победа быстрее 20 с"
		and Legion.star_miss(1, {"alive": 2, "total": 3}, s1) == "пали 1 из 3" and Legion.star_miss(2, {"time": 40.2}, s1) == "бой шёл 41 с",
		"звёзды боя: %s; недобытые — «пали 1 из 3», «бой шёл 41 с»" % str(tx))
	var s0 := L.stage_info(0, 0, 0)
	_check(String(Legion.star_texts(s0)[2]) == "Масло накрыло 4+ врагов разом" and Legion.task_done({"oil_best": 4}, s0) and not Legion.task_done({"oil_best": 3}, s0)
		and Legion.star_miss(2, {"oil_best": 0, "perks_used": 0}, s0) == "масло не жали", "задание учебного боя — масло накрыло 4+ разом")
	# звёзды копятся по битам: сначала «все вернулись», потом «задание» — три звезды, +2 Славы один раз
	L.stars.erase(String(s1["key"]))
	var o1 := L.apply_result(L.make_battle(s1, 3), {"win": true, "alive": 3, "total": 3, "timeout": false, "time": 40.0, "hp_left": 0.6, "oil_best": 1})
	var g1 := L.glory
	var o2 := L.apply_result(L.make_battle(s1, 3), {"win": true, "alive": 2, "total": 3, "timeout": false, "time": 15.0, "hp_left": 0.4, "oil_best": 1})
	var o3 := L.apply_result(L.make_battle(s1, 3), {"win": true, "alive": 3, "total": 3, "timeout": false, "time": 15.0, "hp_left": 0.7, "oil_best": 1})
	_check(int(o1["stars"]) == 2 and int(o1["star_glory"]) == 0 and int(o2["stars"]) == 2 and int(o2["star_best"]) == 3 and int(o2["star_glory"]) == Legion.STAR_GLORY
		and int(o2["reward"]["glory"]) >= Legion.STAR_GLORY and L.glory - g1 >= Legion.STAR_GLORY and int(o3["star_glory"]) == 0 and int(L.stars[String(s1["key"])]) == Legion.STAR_ALL,
		"звёзды копятся: 2★ (все вернулись), потом задание — лучшее 3★, +%d Славы один раз" % Legion.STAR_GLORY)
	# все 30 звёзд леса: сундук Славы и трофей в город (украшение бесплатно, одно на город); второй раз — ничего
	_check(not city.unlocked("trophy_cart") and Defs.unlock_text("trophy:forest").contains("30 звёздами"), "трофей закрыт: открывается " + Defs.unlock_text("trophy:forest"))
	for s in Legion.STAGES:
		L.stars[Legion.stage_key(0, 0, s)] = Legion.STAR_ALL
	var s9 := L.stage_info(0, 0, 9)
	L.stars[String(s9["key"])] = Legion.STAR_WIN
	var g2 := L.glory
	var o4 := L.apply_result(L.make_battle(s9, 3), {"win": true, "alive": 3, "total": 3, "timeout": false, "time": 30.0, "hp_left": 0.7, "oil_best": 5})
	var ch: Dictionary = o4["chest"]
	var cp := city.check_place("trophy_cart", Land.CENTER + Vector2(-16, 14), 0.0)
	_check(not ch.is_empty() and int(ch["glory"]) == int(Legion.CHEST[0]) and String(ch["trophy"]) == "trophy_cart" and L.region_stars(0, 0) == 30
		and L.glory - g2 >= float(Legion.CHEST[0]) and city.unlocked("trophy_cart") and String(cp["err"]) == "" and float(Defs.B["trophy_cart"]["cost"]) == 0.0,
		"все 30 звёзд: сундук +%d Славы, трофей «%s» открыт и ставится бесплатно" % [int(ch.get("glory", 0)), Defs.B["trophy_cart"]["name"]])
	var o5 := L.apply_result(L.make_battle(s9, 3), {"win": true, "alive": 3, "total": 3, "timeout": false, "time": 30.0, "hp_left": 0.7, "oil_best": 5})
	_check((o5["chest"] as Dictionary).is_empty(), "сундук — один раз")


## Четыре места (после Атамана): «Лучший состав» в волчьем бою леса — без лучника, как велит совет на карточке;
## прочим отрядам нет красного «есть состав лучше» (с четырёх мест «Лучший состав» — не ответ на бой); лучник
## в волчьем бою — «загрызут» при любом числе мест
func _slots4_api(city: City, L: Legion, p: Vector2) -> void:
	var keep := L.squad.duplicate()
	var rb := city.place("range", p + Vector2(0, 26), 0.0, 0, -1, true)
	var w2 := L.stage_info(0, 0, 2)
	var w7 := L.stage_info(0, 0, 7)
	var best2 := L.auto_squad(w2)
	var best7 := L.auto_squad(w7)
	var best1 := L.auto_squad(L.stage_info(0, 0, 1))
	L.squad = ["legionary", "legionary", "legionary", "legionary"]
	var h_leg := L.squad_hint(w2) + L.squad_hint(w7)
	var h_other := L.squad_hint(L.stage_info(0, 0, 1)) + L.squad_hint(L.stage_info(0, 1, 2)) + L.squad_hint(L.stage_info(0, 2, 5))
	var off_leg := L.squad_off(w2) or L.squad_off(L.stage_info(0, 0, 1)) or L.squad_off(L.stage_info(0, 1, 2))
	L.squad = ["legionary", "archer", "legionary", "legionary"]
	var h_bow := L.squad_hint(w2)
	var off_bow := L.squad_off(w2)
	var h_bow_hill := L.squad_hint(L.stage_info(0, 1, 2))
	var arch := L.available("archer")
	city.remove(rb, false)
	L.squad = keep
	_check(arch and L.slots() == 4 and best2.size() == 4 and not "archer" in best2 and not "archer" in best7 and "archer" in best1,
		"4 места: «Лучший состав» волкам %s, «Волчьей ночи» %s, пращникам %s" % [str(best2), str(best7), str(best1)])
	_check(h_leg == "" and h_other == "" and not off_leg and h_bow.contains("загрызут") and off_bow and h_bow_hill == "",
		"4 места: четыре легионера — без красного совета («%s»), с лучником против волков — «%s»" % [h_leg + h_other, h_bow])


## Задание на третью звезду выполнимо в каждом бою (иначе сундук провинции за 30 звёзд не открыть): «масло накрыло
## N+» — не больше самой большой кучи врагов (волна; у босса с созывом — вместе с подмогой); бои по двое — «здоровье»
func _tasks_api() -> void:
	var bad := []
	var hp := []
	for c in 2:
		for r in Legion.REGIONS.size():
			for s in Legion.STAGES:
				var st := Legion.stage(c, r, s)
				var t := Legion.task_of(st)
				if String(t[0]) == "hp" and c == 0 and not bool(st["fixed"]):
					hp.append("%d-%d" % [r, s])
				if String(t[0]) != "oil":
					continue
				var big := 0
				for w: Array in st["waves"]:
					var n := w.size()
					for k in w:
						if Legion.ENEMIES[k].has("summon"):
							n += (Legion.ENEMIES[k]["summon"]["foes"] as Array).size()
					big = maxi(big, n)
				if int(t[1]) > big:
					bad.append("%s: масло %d+ при %d врагах" % [st["key"], int(t[1]), big])
	_check(bad.is_empty() and hp.has("1-0") and hp.has("1-2") and hp.has("2-1") and hp.has("2-2") and hp.has("7-0") and not hp.has("1-3")
		and Legion.task_of({"waves": [["wolf", "boar"]]}) == ["hp", 50],
		"задание на третью звезду по силам во всех боях %s; бои по двое и без кучи — «здоровье»: %s" % [str(bad), str(hp)])


## Этап 3b: угрозы — Атаман созывает шайку (рог за 3 с), волна-«куча», лучник выцеливает пращников в кустах
func _threats_api(L: Legion) -> void:
	var bs := L.make_battle(L.stage_info(0, 0, 9), 5)
	var sim := LegionSim.new(bs)
	sim.set_auto(true)
	var warn_t := -1.0
	var sum_t := -1.0
	var fresh: Array = []
	while sim.result.is_empty() and sum_t < 0.0:
		sim.step(LegionSim.DT)
		for e: Dictionary in sim.take_events():
			if String(e["type"]) == "warn" and warn_t < 0.0:
				warn_t = sim.t
			if String(e["type"]) == "summon":
				sum_t = sim.t
				fresh = e["units"]
	sim.dispose()
	var xs := []
	var zs := []
	for u: LegionSim.Unit in fresh:
		xs.append(u.x)
		zs.append(u.z)
	if xs.is_empty():
		xs = [0.0]
		zs = [0.0]
	_check(warn_t > 0.0 and sum_t - warn_t >= 2.9 and fresh.size() == 3 and xs.max() - xs.min() < 1.0 and zs.max() - zs.min() <= 0.71,
		"Атаман: рог на %.1f с, шайка из %d вбегает кучей на %.1f с" % [warn_t, fresh.size(), sum_t])
	# стрелки в кустах: лучник сначала бьёт пращника (поверх спин разбойников), легионер — ближнего
	var st6 := L.stage_info(0, 0, 6)
	var w6 := []
	for w: Array in st6["waves"]:
		var ws := []
		for k in w:
			ws.append(Legion.foe_stats(st6, k))
		w6.append(ws)
	var s6 := LegionSim.new({"kind": "campaign", "squad": [Legion.unit_stats("legionary", 3), Legion.unit_stats("archer", 3), Legion.unit_stats("legionary", 3)],
		"waves": w6, "perks": {}, "seed": 9})
	var arch_first := ""
	for i in 300:
		s6.step(LegionSim.DT)
		s6.take_events()
		for u in s6.units:
			if u.key == "archer" and u.target != null and arch_first == "":
				arch_first = u.target.key
	var bush := 0
	for u in s6.units:
		if u.side == "enemy" and u.kite_k:
			bush += 1
	s6.dispose()
	_check(arch_first == "slinger" and bush == 3, "пращники «в кустах» (%d): лучник целит в «%s»" % [bush, arch_first])
	# бои с городами этих особенностей не знают (сервер считает без них)
	var ps := L.make_pvp_battle({"name": "Проба", "rating": 100, "city_level": 4, "snapshot": {"v": 1, "squad": [{"type": "archer", "level": 2}], "perks": {}}}, 3)
	var plain := true
	for w: Array in ps["waves"]:
		for s: Dictionary in w:
			plain = plain and not s.has("kite") and not s.has("summon") and not s.has("bush")
	_check(plain and not ps.has("packs"), "бой с городом — без «кустов», созыва и кучи")
