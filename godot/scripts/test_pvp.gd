extends SceneTree
## Бои с городами по сети без графики: LegionNet ↔ настоящий сервер (server/index.js + pvp.js) с двумя учётками.
##   node .work/pvp_e2e/setup.js                    — две учётки (A, B) и их города с легионами в облаке → tokens.json
##   Godot_console --headless --path godot --script res://scripts/test_pvp.gd -- tokens=D:/CivCity/.work/pvp_e2e/tokens.json --savedir=D:/CivCity/.work/pvp_e2e/saves
## (сервер: PORT=3010 DATA_DIR=D:/CivCity/.work/srvdata node server/index.js). Печатает ok/FAIL и «ИТОГ».
## Проверяет: сила отряда как на сервере; B выставляет оборону и переименовывает город; A получает соперников,
## нападает (номер боя, зерно, ставки), бой LegionSim с зерном сервера, итог уходит на сервер (рейтинг как на сервере,
## повтор не уходит); подделка «слишком быстрый бой» не засчитана; таблица лучших; B получает отчёт о нападении.

var fails := 0
var checks := 0


func check(name: String, ok: bool, extra = null) -> void:
	checks += 1
	if not ok:
		fails += 1
	print(("ok   " if ok else "FAIL ") + name + ("" if ok or extra == null else "  " + str(extra)))


func _initialize() -> void:
	_run.call_deferred()


func _wait(st: Dictionary) -> void:
	var t0 := Time.get_ticks_msec()
	while not st.has("done") and Time.get_ticks_msec() - t0 < 30000:
		await process_frame


func _run() -> void:
	var path := "D:/CivCity/.work/pvp_e2e/tokens.json"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tokens="):
			path = a.trim_prefix("tokens=")
	var tk = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(tk) != TYPE_DICTIONARY:
		print("FAIL нет tokens.json — сначала node .work/pvp_e2e/setup.js")
		quit(2)
		return
	var acc := Account.me()
	var net := LegionNet.me()
	await process_frame
	acc.api = String(tk["api"])
	net.force_on = true
	for c in net.get_children():
		if c is Timer:
			(c as Timer).stop()                     # фоновая проверка не мешает сменам учёток

	# --- сила отряда: та же формула, что у сервера (server/pvp.js, проверка test_pvp.js) ---
	check("сила бойцов как на сервере (142, 540, 308, 849, 1949)",
		Legion.power(Legion.unit_stats("legionary", 1)) == 142 and Legion.power(Legion.unit_stats("ballista", 12, 0.1, 0.05)) == 540 and
		Legion.power(Legion.unit_stats("catapult", 7, 0.0, 0.3)) == 308 and Legion.power(Legion.unit_stats("archer", 25, 0.35, 0.3)) == 849 and
		Legion.power(Legion.unit_stats("spearman", 40)) == 1949)

	# --- B: оборона и название ---
	acc.token = String(tk["b"])
	var lb := Legion.new()
	lb.free_mode = true
	lb.levels = {"legionary": 5, "archer": 4}
	lb._ensure()
	lb.squad = ["legionary", "archer", "legionary"]
	lb.progress = 6
	net.legion_override = lb
	var st := {}
	net.pvp_rename("x", func(e: String):
		st["err"] = e
		st["done"] = true)
	await _wait(st)
	check("слишком короткое название не принято", String(st.get("err", "")) != "", st)
	var name_b := "Тарент %s %d" % [Legion.roman(1 + randi() % 30), int(Time.get_unix_time_from_system()) % 100000]
	st = {}
	net.pvp_rename(name_b, func(e: String):
		st["err"] = e
		st["done"] = true)
	await _wait(st)
	var snap_b := lb.defense_snapshot()
	check("B: оборона выставлена, город назван «%s»" % name_b, String(st.get("err", "?")) == "" and String(net.me_state.get("name", "")) == name_b and bool(net.me_state.get("published", false)), [st, net.me_state])
	check("B: сила обороны на сервере = Legion.snapshot_power (%d)" % Legion.snapshot_power(snap_b), int(net.me_state.get("power", -1)) == Legion.snapshot_power(snap_b), net.me_state)

	# --- A: соперники, нападение, бой, итог ---
	acc.token = String(tk["a"])
	var la := Legion.new()
	la.free_mode = true
	la.levels = {"legionary": 6, "archer": 5, "spearman": 4}
	la._ensure()
	la.perks["oil"] = 2
	la.progress = 14
	la.squad = ["legionary", "legionary", "archer", "spearman"]
	net.legion_override = la
	net._pub_hash = ""
	st = {}
	net.pvp_opponents(func(list: Array, e: String):
		st["list"] = list
		st["err"] = e
		st["done"] = true)
	await _wait(st)
	var list: Array = st.get("list", [])
	var name_a := String(net.me_state.get("name", ""))
	var ob := {}
	for o: Dictionary in list:
		if String(o["name"]) == name_b:
			ob = o
	var nbots := list.filter(func(o): return bool(o["bot"])).size()
	print("соперники A (%s): " % name_a, ", ".join(list.map(func(o): return "%s%s сила %d" % [o["name"], " (вольный)" if o["bot"] else "", o["power"]])))
	# вольные города добирают список, если живых подходящих соперников меньше четырёх (на общем сервере их может хватать)
	check("A: список соперников пришёл, в нём B, нет себя, не меньше четырёх", String(st.get("err", "?")) == "" and not ob.is_empty() and
		list.size() >= 4 and (nbots >= 1 or list.size() - nbots >= 4) and not list.any(func(o): return String(o["name"]) == name_a), st.get("err"))
	check("A: сила B в списке = Legion.snapshot_power", not ob.is_empty() and int(ob["power"]) == Legion.snapshot_power(ob["snapshot"]))
	check("A: рейтинг и заряды взяты с сервера", la.pvp_rating == int(net.me_state.get("rating", -1)) and la.pvp_charges_now() == int(net.me_state.get("charges", -1)))
	st = {}
	net.pvp_attack(ob, func(o2: Dictionary, e: String):
		st["opp"] = o2
		st["err"] = e
		st["done"] = true)
	await _wait(st)
	var o2: Dictionary = st.get("opp", {})
	check("A: нападение принято: номер боя, зерно, ставки, добыча", String(st.get("err", "?")) == "" and String(o2.get("battle", "")) != "" and int(o2.get("seed", -1)) > 0 and
		(o2.get("stakes", {}) as Dictionary).has("win") and (o2.get("reward", {}) as Dictionary).has("money"), st)
	check("A: заряд потрачен на сервере (у нас ещё спишет бой)", int(net.me_state.get("charges", -1)) == 4 and la.pvp_charges_now() == 5, [net.me_state, la.pvp_charges])
	var setup := la.make_pvp_battle(o2)
	check("бой с зерном сервера", int(setup["seed"]) == int(o2["seed"]))
	var t0 := Time.get_ticks_msec()
	var sim := LegionSim.new(setup)
	var res := sim.run(true)
	sim.dispose()
	var out := la.apply_pvp_result(setup, res)
	var win := bool(res["win"])
	check("итог у нас: рейтинг по ставке сервера (%s, %+d)" % ["победа" if win else "поражение", int(out["delta"])],
		int(out["delta"]) == int(o2["stakes"]["win" if win else "loss"]) and la.pvp_charges_now() == 4 and (not win or int(out["reward"]["money"]) == int(o2["reward"]["money"])))
	# бой смотрят на скорости ×3 — ждём, сколько он шёл бы на экране (иначе сервер не засчитает победу;
	# сервер повторяет бой сам и берёт время повтора, запас у него — 2 с)
	var wait_s := float(res["time"]) / 3.0 - 1.0 - float(Time.get_ticks_msec() - t0) / 1000.0
	print("бой %.1f с (сим), ждём %.1f с" % [float(res["time"]), maxf(0.0, wait_s)])
	if wait_s > 0.0:
		await create_timer(wait_s).timeout
	var rating_before := la.pvp_rating
	await net.pvp_report(setup, out)
	check("итог на сервере: рейтинг как на сервере (%d), запись летописи с номером боя" % int(net.me_state.get("rating", -1)),
		la.pvp_rating == int(net.me_state.get("rating", -2)) and String(la.pvp_log[0].get("battle", "")) == String(o2["battle"]) and not la.pvp_log[0].has("void"),
		[rating_before, la.pvp_rating, net.me_state, la.pvp_log[0]])
	var reported := net._reported.size()
	net.pvp_report(setup, out)
	check("повторный итог того же боя не уходит", net._reported.size() == reported)

	# --- подделка: «победа» (над вольным городом) быстрее, чем бой можно досмотреть ---
	st = {}
	net.pvp_opponents(func(l2: Array, e: String):
		st["list"] = l2
		st["done"] = true)
	await _wait(st)
	var bot := {}
	for o: Dictionary in st.get("list", []):
		if bot.is_empty() or bool(o["bot"]):
			bot = o                                 # вольный город, а если их нет — любой соперник
		if bool(o["bot"]):
			break
	check("A: B больше не в списке (на него недавно нападали)", not (st.get("list", []) as Array).any(func(o): return String(o["name"]) == name_b))
	st = {}
	net.pvp_attack(bot, func(o3: Dictionary, e: String):
		st["opp"] = o3
		st["err"] = e
		st["done"] = true)
	await _wait(st)
	var o3: Dictionary = st.get("opp", {})
	var setup3 := la.make_pvp_battle(o3)
	var fake := {"win": true, "alive": setup3["squad"].size(), "total": setup3["squad"].size(), "timeout": false, "time": 120.0, "hp_left": 1.0}
	var r_before := int(net.me_state.get("rating", 0))
	var out3 := la.apply_pvp_result(setup3, fake)
	await net.pvp_report(setup3, out3)
	check("слишком быстрая «победа» не засчитана: рейтинг как был, в летописи — «не засчитан»",
		int(net.me_state.get("rating", -1)) == r_before and la.pvp_rating == r_before and bool(la.pvp_log[0].get("void", false)), [r_before, net.me_state, la.pvp_log[0]])

	# --- таблица лучших ---
	st = {}
	net.pvp_top(func(d: Dictionary, e: String):
		st["d"] = d
		st["err"] = e
		st["done"] = true)
	await _wait(st)
	var top: Array = (st.get("d", {}) as Dictionary).get("top", [])
	var me_a := top.filter(func(r): return bool(r["me"]))
	check("таблица лучших: есть A (я) и B", top.any(func(r): return String(r["name"]) == name_b) and me_a.size() == 1 and String(me_a[0]["name"]) == name_a and
		int(st["d"]["me"]["place"]) == int(me_a[0]["place"]), st.get("err"))

	# --- B: отчёт о нападении ---
	acc.token = String(tk["b"])
	net.legion_override = lb
	var glory0 := lb.glory
	await net.refresh()
	var rep := {}
	for e: Dictionary in lb.pvp_log:
		if not bool(e.get("attack", true)) and String(e.get("name", "")) == name_a:
			rep = e
	check("B: отчёт «На вас напал %s» в летописи, рейтинг как на сервере" % name_a, not rep.is_empty() and lb.pvp_rating == int(net.me_state.get("rating", -1)) and
		int(lb.flags.get("pvp_seen", 0)) > 0, [lb.pvp_log, net.me_state])
	if not rep.is_empty():
		var held := bool(rep["win"])
		check("B: %s — рейтинг %+d, Слава +%d" % ["отбились" if held else "не устояли", int(rep["delta"]), int(lb.glory - glory0)],
			(held and int(rep["delta"]) > 0 and is_equal_approx(lb.glory - glory0, 1.0)) or (not held and int(rep["delta"]) < 0 and is_equal_approx(lb.glory, glory0)))
	var n_log := lb.pvp_log.size()
	await net.refresh()
	check("B: отчёт не приходит второй раз", lb.pvp_log.size() == n_log)
	print("ИТОГ: %d проверок, ошибок %d" % [checks, fails])
	quit(1 if fails > 0 else 0)
