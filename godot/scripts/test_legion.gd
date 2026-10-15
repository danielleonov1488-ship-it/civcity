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
## mode=tut       — учебный первый бой (0-0-0, шайка кучей): три легионера lvl (1), масло там, где бой замирает,
##                  без масла и с «Авто»; печатает доли побед и сколько врагов накрыло масло
## Состав и умения — как у игрока, дошедшего до боя (места и рода войск открываются боссами); умения жмёт сам бой
## (auto) — как внимательный игрок. noarcher=1 — без лучников (до исследования «Стрельбище»).

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
		"api":
			_api()
		"tut":
			var lv := int(args.get("lvl", "1"))
			for how in ["freeze", "freeze_auto", "none", "auto"]:
				var tr := _tut_rate(how, seeds, lv)
				print("TUT %-11s ур.%d: побед %d%%, масло накрыло в среднем %.1f, здоровья осталось %d%%, время %.0f с" % [how, lv,
					roundi(float(tr["win"]) * 100), float(tr["hit"]), roundi(float(tr["hp"]) * 100), float(tr["time"])])
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
	var plan := ["legionary", "archer", "spearman", "ballista", "legionary", "catapult", "archer", "spearman", "legionary"]
	var sq := []
	for t in plan:
		if sq.size() >= slots:
			break
		if t in have:
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
	for i in seeds:
		var sim := LegionSim.new({"kind": "campaign", "squad": pl["squad"], "waves": waves, "perks": pl["perks"], "seed": 1000 + i * 7919,
			"packs": st.get("packs", [])})
		var r := sim.run(true)
		if r["win"]:
			win += 1
			stars += Legion.stars_for(r)
			hp += float(r["hp_left"])
		tm += float(r["time"])
		if r["timeout"]:
			tout += 1
	return {"win": float(win) / seeds, "stars": stars / maxf(1.0, win), "time": tm / seeds, "hp": hp / maxf(1.0, win), "timeout": float(tout) / seeds}


## Учебный бой 0-0-0 (как в игре: шайка кучей, setup.packs): три легионера уровня lvl с маслом 1 ур.
## how: freeze — масло ровно тогда, когда вторая волна вышла на поле (там 3D-бой замирает), потом умения никто не жмёт;
## freeze_auto — то же, потом «Авто»; none — без масла; auto — «Авто» с начала
func _tut_rate(how: String, seeds: int, lvl: int) -> Dictionary:
	var st := Legion.stage(0, 0, 0)
	var waves := []
	for w: Array in st["waves"]:
		var ws := []
		for k in w:
			ws.append(Legion.foe_stats(st, k))
		waves.append(ws)
	var sq := []
	for i in 3:
		sq.append(Legion.unit_stats("legionary", lvl))
	var win := 0
	var hit := 0
	var hp := 0.0
	var tm := 0.0
	for i in seeds:
		var sim := LegionSim.new({"kind": "campaign", "squad": sq, "waves": waves, "perks": {} if how == "none" else {"oil": 1},
			"seed": 1000 + i * 7919, "packs": st["packs"]})
		sim.set_auto(how == "auto")
		var pressed := false
		while sim.result.is_empty():
			sim.step(LegionSim.DT)
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
	_check(not L.window_open() and L.lock_text().contains("Посёлок"), "окно закрыто до исследования «Легион»: " + L.lock_text())
	# Д5: Легион с «Посёлка» — исследование того же ряда, провинции раньше, предел бойцов не ниже самого трудного боя
	_check(int(Defs.research("legion")["lvl"]) == int(Legion.REGIONS[0]["rank"]) and int(Legion.REGIONS[0]["rank"]) == 3, "«Легион» изучается на «%s» — там же открыт лес" % Defs.LEVELS[int(Defs.research("legion")["lvl"])]["name"])
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
	_check(ranks == [3, 4, 5, 5, 6, 6, 7, 7] and walls.is_empty(), "провинции по уровням города %s, стен нет %s" % [ranks, walls])
	_check(int(L.perks["oil"]) == 1 and L.open_perks().has("oil"), "«Кипящее масло» — с первого дня")
	city.level = 3
	city.research["legion"] = true
	_check(L.window_open(), "окно открыто после «Легиона»")
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
	_check(int(L.levels["legionary"]) == 3 and L.can_upgrade("legionary").begins_with("Предел города"), "предел «Посёлка» — 3 ур.: " + L.can_upgrade("legionary"))
	# провинции за уровнем города
	L.progress = 10
	_check(not L.stage_open(0, 1, 0) and L.region_lock_text(1).contains("Городок"), "вторая провинция ждёт «Городка»: " + L.region_lock_text(1))
	city.level = 4
	_check(L.stage_open(0, 1, 0) and L.cap() == 4, "на «Городке» открыта, предел 4")
	city.level = 6
	_check(L.cap() == 8, "на «Большом городе» предел 8")
	# босс: место в отряде, новая постройка (масло уже было)
	L.progress = 9
	var bst := L.stage_info(0, 0, 9)
	var bout := L.apply_result(L.make_battle(bst, 1), {"win": true, "alive": 2, "total": 3, "timeout": false, "time": 50.0})
	_check(bool(bout["boss_beaten"]) and int(L.perks["oil"]) == 1 and L.slots() == 4 and city.unlocked("spearcamp"), "босс побеждён: %s" % str(bout["unlocks"]))
	# сохранение через JSON
	L.set_slot(3, "legionary")
	L.upg["legionary"] = {"to": 4, "end": Legion.now() + 3600.0, "total": 3600.0}
	var d = JSON.parse_string(JSON.stringify(city.save_data()))
	var city2 := City.new(Land.new())
	city2.load_data(d)
	var L2: Legion = city2.legion
	_check(L2.progress == L.progress and L2.rating == L.rating and is_equal_approx(L2.glory, L.glory) and int(L2.levels["legionary"]) == 3
		and L2.upg.has("legionary") and L2.squad.size() == 4 and int(L2.perks["oil"]) == 1 and L2.stars.size() == L.stars.size()
		and String(L2.flags.get("tut", "")) == "done", "сохранение и загрузка (JSON) — всё на месте")
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
	_check(not L4.tutorial_battle(Legion.stage(0, 0, 0)), "«Пропустить обучение» — без учебного боя")
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
