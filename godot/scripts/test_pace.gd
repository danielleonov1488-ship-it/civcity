extends Node
## Темп игры: предел скрипториев, школ, библиотек и академий по уровням города, очки исследований в час (почта на
## станции, ученики писцов), перенос живого сохранения (просьбы 1–10 выполнены, хутор, 51 житель, 97 очков), ряды
## исследований, повозка только в свободные дома, новый уровень по кнопке; и бот — игра до Вечного города при 1×
## (с играми в честь богов и покупкой земли; сами траты этапа 1b проверяет test_sinks.tscn).
##   bash .work/py/gpu_run.sh res://test_pace.tscn             — проверки, в конце «PACE CHECKS fails=0»
##   bash .work/py/gpu_run.sh --headless res://test_pace.tscn -- bot   — бот: «RANK …» по рангам и итог «PACE BOT …»
##     seed=N — другой случай; frugal=1 — бережливый игрок (только условия уровня и нужды: без лишних украшений, этажей,
##     разнообразия лавок и игр); строки ECONREQ / ECONRES / ECONRANK и таблица «ECON TABLE» — очки и деньги по рангам (этап 2.0)
## Время идёт вручную (скорость 0, city.sim_day() по часам); повозку и путь семьи до дома бот
## изображает сам (CART_H, WALK_H).

const OLD10 := ["road1", "houses3", "fam3", "fruit", "scriptorium", "research1", "lights", "fed6", "pop30", "decor5"]
const SEC_H := 25.0                  # секунд в игровом часе при 1× (Game.DAY_LEN / 24)
const CART_H := 1.3                  # повозка от края карты до станции, часов (за кадром втрое быстрее)
const WALK_H := 0.5                  # семья идёт от станции до дома
const STEP_H := 0.25
const MAX_H := 1400.0
## улицы по порядку: следующая кладётся, когда домам не хватает места
const STREETS := [
	[Vector2(192, 128), Vector2(192, 150)], [Vector2(172, 136), Vector2(192, 136)], [Vector2(172, 150), Vector2(192, 150)],
	[Vector2(158, 136), Vector2(172, 136)], [Vector2(158, 150), Vector2(172, 150)], [Vector2(192, 150), Vector2(192, 178)],
	[Vector2(158, 164), Vector2(192, 164)], [Vector2(158, 178), Vector2(192, 178)], [Vector2(158, 122), Vector2(188, 122)],
	[Vector2(158, 192), Vector2(192, 192)], [Vector2(192, 178), Vector2(192, 206)], [Vector2(158, 206), Vector2(192, 206)],
]

var game
var c                                # City (без типа: на старых данных нет новых методов)
var K: Dictionary                    # константы defs.gd по имени
var fails := 0
var cands: Array = []                # точки у проложенных улиц, куда пробовать ставить
var streets := 0                     # сколько улиц из STREETS проложено


func _ready() -> void:
	Game.boot = {"new": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	await frames(6)
	DirAccess.make_dir_recursive_absolute("D:/CivCity/.work/gd")
	get_viewport().get_texture().get_image().save_png("D:/CivCity/.work/gd/" + name)
	print("SHOT ", name)


func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	c = game.city
	K = (load("res://scripts/defs.gd") as Script).get_script_constant_map()
	game.can_save = false
	game.speed = 0.0
	# обучение не мешает: его шаги сами подгоняют повозку и докладывают очки
	game.tutorial.step = Tutorial.STEPS.size()
	game.tutorial.card.visible = false
	c.tips["tut"] = -1
	c.tips["ui"] = 3
	game.hud.apply_reveal(3)
	await frames(5)
	if "bot" in OS.get_cmdline_user_args():
		await _bot()
	else:
		await _checks()
	get_tree().quit()


# ---------- помощники ----------

## Сбросить, что placement() помнит между вызовами (как в test_pave)
func reset() -> void:
	game.last_snap_n = Vector2.ZERO
	game.last_snap_p = Vector2.INF
	game.manual_yaw = false
	game.yaw_set = false
	game.place_lock = {}
	game.tool_yaw = 0.0
	game.snap = true


## Проложить следующую улицу из STREETS (деньги — как за мостовую кистью)
func street() -> bool:
	if streets >= STREETS.size():
		return false
	var a: Vector2 = STREETS[streets][0]
	var b: Vector2 = STREETS[streets][1]
	streets += 1
	var ch: Array = game.land.paint_line(a, b, 1.3, Land.Kind.ROAD, true)
	c.road_cells += ch.size()
	c.money -= ch.size() * float(Defs.ROAD_COST["road"])
	game.people.refresh(game.land.road_chunks.keys())
	var dir := (b - a).normalized()
	var side := Vector2(-dir.y, dir.x)
	for i in int(a.distance_to(b)) + 1:
		for s in [-3.2, 3.2]:
			cands.append(a + dir * i + side * s)
	return true


## Поставить в ближайшей к цели годной точке; дом, лавку, скрипторий — только фасадом к дороге
func put(type: String, target: Vector2, pts: Array, tries := 300) -> Dictionary:
	var d: Dictionary = Defs.B[type]
	pts.sort_custom(func(p, q): return p.distance_squared_to(target) < q.distance_squared_to(target))
	var n := 0
	for p in pts:
		if n >= tries:
			break
		n += 1
		reset()
		var pl: Dictionary = game.placement(type, p)
		if pl["err"] == "" and (d["kind"] == "decor" or pl["sub"] == "road"):
			return c.place(type, pl["pos"], pl["yaw"], pl["variant"], pl["color"])
	return {}


func n_of(type: String) -> int:
	var n := 0
	for id in c.buildings:
		if c.buildings[id]["type"] == type:
			n += 1
	return n


func ids(goals: Array) -> Array:
	return goals.map(func(g): return g["id"])


## Заселить дома, пока жителей не станет pop
func fill(houses: Array, pop: int) -> void:
	var now := 0
	for h in houses:
		now += int(h["pop"])
	var k := 0
	for h in houses:
		var n := mini(c.house_cap(h) - int(h["pop"]), pop - now)
		if n > 0:
			k += 1
			c.settled(int(h["id"]), n, "Проба %d-%d" % [int(h["id"]), k])
			now += n
	c.compute()


# ---------- проверки ----------

func _checks() -> void:
	c.money = 3000.0
	for i in 4:
		street()
	var houses := []
	for i in 14:
		var b := put("house_pleb", Vector2(180, 143), cands)
		if not b.is_empty():
			houses.append(b)
	check(houses.size() == 14, "houses placed: %d" % houses.size())
	c.money = 3000.0
	game.rig.set_view(Vector3(180, 2, 143), 20, 50, 46)
	# 1) Стоянка: один скрипторий можно, второй — нет
	var s1 := put("scriptorium", Vector2(186, 132), cands)
	check(not s1.is_empty(), "scriptorium #1 at «Стоянка»")
	reset()
	var e2: String = game.placement("scriptorium", Vector2(170, 147))["err"]
	check(e2.contains("не больше 1") and e2.contains("«Хутор»"), "scriptorium #2 at «Стоянка» refused: «%s»" % e2)
	check(e2 == c.cap_err("scriptorium"), "same reason from cap_err()")
	game.hud.select_build("scriptorium")
	check(game.tool != "scriptorium", "capped card does not pick the tool (tool «%s»)" % game.tool)
	var tip: String = game.hud._card_tip("scriptorium")
	check(tip.contains("В городе: 1 из 1 (на уровне «Хутор» — 2)"), "card tip: «%s»" % tip.get_slice("\n", tip.get_slice_count("\n") - 1))
	await shot("pace_cap_card.png")
	game.hud.close_panels()
	# 2) очки в час на Стоянке: писцы 2 + почта 1
	fill(houses, 12)
	c.sim_day()
	var rpd := float(c.stats["rp_day"])
	check(is_equal_approx(rpd, 3.0), "rp/h at «Стоянка» = 2 scribes + 1 post: %.2f (scriptorium staff %.2f)" % [rpd, float(s1.get("staff", 0))])
	# 3) живое сохранение: просьбы 1–10 по старому списку (с pop30), хутор, 51 житель, 97 очков
	c.level = 1
	fill(houses, 51)                          # (заселение само проверяет просьбы — список задаём после)
	c.goals_done = OLD10.duplicate()
	c.rp = 97.0
	var w0: Array = ids(c.active_goals())
	check(w0 == ["hamlet", "scriptorium2", "market"], "live save window: %s" % [w0])
	c.sim_day()
	rpd = float(c.stats["rp_day"])
	check(c.goals_done.has("hamlet"), "«Станьте хутором» done after one hour (already «Хутор»)")
	check(is_equal_approx(rpd, 4.5), "rp/h at «Хутор» = 2 + 2.5: %.2f" % rpd)
	var hamlet_rp := float(Defs.request("hamlet")["rp"])
	check(is_equal_approx(float(c.rp), 97.0 + rpd + hamlet_rp), "rp after the hour = 97 + %.1f + %d: %.1f" % [rpd, int(hamlet_rp), float(c.rp)])
	check(c.level == 1 and int(c.stats["pop"]) == 51, "still «Хутор»: pop %d, level %d" % [int(c.stats["pop"]), c.level])
	check(c.can_research("floor2") == "", "«Второй жилой этаж» (%d) affordable: «%s»" % [int(Defs.research("floor2")["cost"]), c.can_research("floor2")])
	var w1: Array = ids(c.active_goals())
	check(w1 == ["scriptorium2", "market", "floor2"], "window after the hour: %s" % [w1])
	# 4) Хутор: второй скрипторий можно, третий — нет; перенос (−3) и готовый город (−2) — без предела
	var s2 := put("scriptorium", Vector2(170, 147), cands)
	check(not s2.is_empty(), "scriptorium #2 at «Хутор»")
	reset()
	var e3: String = game.placement("scriptorium", Vector2(165, 140))["err"]
	check(e3.contains("не больше 2") and e3.contains("«Деревня»"), "scriptorium #3 at «Хутор» refused: «%s»" % e3)
	for mode in [-3, -2]:
		var ef: String = c.check_place("scriptorium", Vector2(150, 230), 0.0, 0, 0, mode)["err"]
		check(not ef.contains("не больше"), "ignore_id %d skips the cap: «%s»" % [mode, ef])
	c.sim_day()
	rpd = float(c.stats["rp_day"])
	check(c.goals_done.has("scriptorium2"), "«Второй скрипторий» done")
	check(is_equal_approx(rpd, 6.5), "rp/h with 2 scriptoria = 2×2 + 2.5: %.2f" % rpd)
	c.research["scribes1"] = true
	c.sim_day()
	rpd = float(c.stats["rp_day"])
	check(is_equal_approx(c.rp_per_hour("scriptorium"), 3.0) and is_equal_approx(rpd, 8.5),
		"«Ученики писцов»: %.1f per scriptorium, %.2f/h (2×3 + 2.5)" % [c.rp_per_hour("scriptorium"), rpd])
	c.research["scribes2"] = true
	check(is_equal_approx(c.rp_per_hour("scriptorium"), 4.0), "«Мастерская писцов»: %.1f per scriptorium" % c.rp_per_hour("scriptorium"))
	var mx := []
	for lv in Defs.LEVELS.size():
		c.level = lv
		mx.append(c.build_max("scriptorium"))
	c.level = 1
	check(mx == [1, 2, 3, 4, 5, 6, 8, 10], "scriptorium cap by level: %s" % [mx])
	check(int(K["ARRIVE_FREE"]) == 7 and float(K["ARRIVE_EVERY"][0]) == 2.0 and int(Defs.LEVELS[1]["pop"]) == 20 and int(Defs.LEVELS[2]["pop"]) == 60,
		"arrivals: 7 free families, cart every 2 h; ranks 20 / 60")
	await _checks_1a(houses)
	print("PACE CHECKS fails=%d" % fails)


# ---------- этап 1a: пределы, очки в час, ряды исследований, повозка, условия уровня, кнопка ----------

## Цель экономики: сколько очков в час даёт богатый город на каждом уровне (все пределы заняты)
const RP_TARGET := [3.0, 8.5, 24.0, 37.5, 66.0, 89.0, 114.0, 152.0]


func _checks_1a(houses: Array) -> void:
	var hud = game.hud
	# 5) пределы школ, библиотек, академий по уровню (решение владельца Д2)
	var caps := {}
	for t in ["scriptorium", "school", "library", "academy"]:
		var a := []
		for lv in Defs.LEVELS.size():
			c.level = lv
			a.append(c.build_max(t))
		caps[t] = a
	c.level = 1
	check(caps["school"] == [0, 0, 2, 4, 5, 6, 7, 8] and caps["library"] == [0, 0, 0, 0, 2, 3, 4, 5] and caps["academy"] == [0, 0, 0, 0, 0, 0, 1, 2],
		"caps by level: school %s, library %s, academy %s" % [caps["school"], caps["library"], caps["academy"]])
	# 6) самые большие очки в час по рангам (всё занято, прибавки писцов изучены, как только можно) — у цели экономики
	var mxr := []
	var worst := 0.0
	for lv in Defs.LEVELS.size():
		var r := float(Defs.LEVELS[lv]["rp_h"])
		for t in caps:
			var rate := float(Defs.B[t]["rp"])
			if t == "scriptorium":
				rate *= 1.0 + (0.5 if lv >= 1 else 0.0) + (0.5 if lv >= 3 else 0.0)
			r += rate * int(caps[t][lv])
		mxr.append(r)
		worst = maxf(worst, absf(r / RP_TARGET[lv] - 1.0))
	check(worst <= 0.1, "max rp/h by rank %s vs target %s (worst %d%%)" % [mxr, RP_TARGET, roundi(worst * 100.0)])
	# 7) ряды исследований: самое дорогое в ряду влезает на полки этого уровня (с «Новыми полками» — вдвое, с Городка)
	var bad := []
	var dear := {}
	var tot := {}
	for rr in Defs.RESEARCH:
		var l := int(rr["lvl"])
		dear[l] = maxi(int(dear.get(l, 0)), int(rr["cost"]))
		tot[l] = int(tot.get(l, 0)) + int(rr["cost"])
	for l in dear:
		var capr := int(Defs.LEVELS[l]["rp"]) * (2 if l >= 4 else 1)
		if int(dear[l]) > capr:
			bad.append("%d: %d > %d" % [l, dear[l], capr])
	check(bad.is_empty(), "dearest research of each tier fits the rp cap %s; tier totals %s" % [bad, tot])
	# 8) условия уровней — только постройки, открытые исследованиями прошлых уровней (без тупика);
	#    у просьб «Станьте …» столько же пунктов, сколько условий
	bad = []
	for lv in range(1, Defs.LEVELS.size()):
		for n: Dictionary in Defs.LEVELS[lv]["need"]:
			var e := _need_err(n["p"], int(n["n"]), lv)
			if e != "":
				bad.append("%s: %s" % [Defs.LEVELS[lv]["name"], e])
	for q in Defs.REQUESTS:
		if String(q["p"][0]) == "rank" and int(q["need"]) != 2 + (Defs.LEVELS[int(q["p"][1])]["need"] as Array).size():
			bad.append("request %s need %d" % [q["id"], int(q["need"])])
	check(bad.is_empty(), "rank conditions are reachable %s" % [bad])
	# 9) повозка — только в свободные дома; мест нет — одна семья «ищет жильё»; счастье ускоряет
	c.level = 1
	c.arrivals = []
	c.pending = {}
	c.incoming = 0
	fill(houses, 9999)
	check(c.free_fit() == 0, "all houses full: free_fit %d" % c.free_fit())
	c.stats["happy"] = 65
	c.arrive_t = 10.0
	c._tick_arrivals()
	check(c.incoming == 1, "no room, nobody waiting: one family comes to look for a home (incoming %d)" % c.incoming)
	var ld: Array = c.make_load(c.incoming)
	check(ld.size() == 1 and bool(ld[0].get("seek", false)), "the cart load is one family «ищет жильё»: %s" % [ld])
	ld[0]["n"] = 2                             # семья из двоих: в пустой дом на 4 места после неё войдёт ещё одна
	c.family_arrived(ld[0])
	check(c.arrivals.size() == 1 and c.incoming == 0, "it waits on the square")
	check(c.arrive_wait().contains("ищет жильё"), "station text: «%s»" % c.arrive_wait())
	c.arrive_t = 10.0
	c.stats["happy"] = 65
	c._tick_arrivals()
	check(c.incoming == 0, "a family is waiting and there is no room: the cart stays (incoming %d)" % c.incoming)
	street()
	c.money = 3000.0
	var nh := put("house_pleb", Vector2(165, 164), cands)
	check(not nh.is_empty(), "new empty house")
	check(c.free_fit() == 1, "one empty pleb house (4 places = 2 families) minus the waiting family: free_fit %d" % c.free_fit())
	c.arrive_t = 10.0
	c.stats["happy"] = 65
	c._tick_arrivals()
	check(c.incoming == 1, "room for one more family: the cart brings one (incoming %d)" % c.incoming)
	# повозка собирает семьи разом и держит место каждой: в 4 места после ждущей семьи из двоих — ровно одна из двоих
	ld = c.make_load(2)
	check(ld.size() == 1 and int(ld[0]["n"]) == 2 and not c.homes_for(ld[0]).is_empty(), "load with a family waiting: %s" % [ld])
	c.arrivals = []
	c.incoming = 0
	check(c.free_fit() == 2, "empty house, nobody waiting: room for 2 families (free_fit %d)" % c.free_fit())
	# первая семья из 3–4 человек — вторая уже не войдёт, и повозка везёт одну
	var over_n := 0
	var same := 0
	var two := 0
	for i in 40:
		ld = c.make_load(2)
		var sum := 0
		for f in ld:
			sum += int(f["n"])
		if sum > 4 or ld.is_empty():
			over_n += 1
		if ld.size() == 2:
			two += 1
			if ld[0]["name"] == ld[1]["name"]:
				same += 1
	check(over_n == 0 and same == 0 and two > 0, "40 loads for 4 places: all fit (%d over the room, %d same names, %d of 2 families)" % [over_n, same, two])
	c.stats["happy"] = 72
	var m72: float = c.arrive_mult()[0]
	c.stats["happy"] = 85
	var e85: float = c.arrive_every()
	c.stats["happy"] = 65
	check(is_equal_approx(m72, 0.8) and is_equal_approx(e85, 2.5 * 0.65) and is_equal_approx(c.arrive_every(), 2.5),
		"happy city calls more often: 72%% ×%.2f, 85%% → every %.2f h, 65%% → %.2f h" % [m72, e85, c.arrive_every()])
	# 10) лишние школы (старые города): работают первые по номеру, остальные — «сверх предела», их не сносим
	c.research["school"] = true
	c.research["artisans"] = true
	c.level = 3
	c.money = 20000.0
	street()
	var schools := []
	for i in 4:
		var s := put("school", Vector2(175, 178), cands)
		if not s.is_empty():
			schools.append(s)
	check(schools.size() == 4, "4 schools at «Посёлок» (cap 4): %d" % schools.size())
	c.level = 2
	c.compute()
	var over := schools.filter(func(s): return bool(s.get("over", false)))
	check(over.size() == 2 and int(over[0]["id"]) == int(schools[2]["id"]) and int(over[1]["id"]) == int(schools[3]["id"]),
		"cap 2: the last two by id do not work (%d over)" % over.size())
	check(c.cap_err("school").contains("не больше 2"), "no more schools: «%s»" % c.cap_err("school"))
	c.level = 3
	c.compute()
	check(over.all(func(s): return not bool(s.get("over", false))), "at «Посёлок» all 4 work again")
	c.level = 2
	c.compute()
	check(c.idle_text(over[0]).contains("сверх предела"), "idle reason: «%s»" % c.idle_text(over[0]))
	hud._update_world_icons()
	check(not hud.world_icons.has(int(over[0]["id"])) and not hud.world_icons.has(int(over[1]["id"])), "no «нет работников» badge over idle schools")
	# перенос работающей школы (и отмена переноса) не делает её «лишней»: порядок постройки едет с ней
	var born0 := int(schools[0]["born"])
	check(game.start_move(schools[0]), "move the first school")
	game.set_tool("")                          # отмена переноса — школа встаёт обратно с новым номером
	var back: Dictionary = {}
	for id in c.buildings:
		if c.buildings[id]["type"] == "school" and int(c.buildings[id].get("born", -1)) == born0:
			back = c.buildings[id]
	check(not back.is_empty() and int(back["id"]) != born0 and not bool(back.get("over", true)) and bool(over[0]["over"]) and bool(over[1]["over"]),
		"after the move it still works (id %d → %d), the same two stay idle" % [born0, int(back.get("id", -1))])
	schools[0] = back
	var s2b: Dictionary = c.save_data()
	var born_saved := false
	for bd in s2b["buildings"]:
		if int(bd["id"]) == int(back["id"]) and int(bd.get("born", -1)) == born0:
			born_saved = true
	check(born_saved, "the build order is saved")
	# «Форум» дороже полок Города без «Новых полок для свитков» — карточка исследования говорит, что делать
	var lv0: int = c.level
	var rp0: float = c.rp
	var had_r1: bool = c.research.has("research1")
	c.research.erase("research1")
	c.level = 5
	c.rp = 100.0
	var why_f: String = c.can_research("forum")
	check(why_f.contains("Не помещается на полки") and why_f.contains("Новые полки для свитков"), "forum without bigger shelves: «%s»" % why_f)
	c.research["research1"] = true
	why_f = c.can_research("forum")
	check(why_f == "Не хватает очков исследований", "with bigger shelves it is just points: «%s»" % why_f)
	if not had_r1:
		c.research.erase("research1")
	c.level = lv0
	c.rp = rp0
	c.compute()
	var note: String = hud.pace_note()
	check(note.contains("Сверх предела у вас: школ — 2"), "migration note names the idle schools")
	print("  note: ", note.replace("\n", " / "))
	hud.open_info(over[0])
	await frames(3)
	var card_txt := _texts(hud.info_box)
	check(card_txt.contains("Сверх предела уровня — не работает"), "school card says it is over the cap")
	game.rig.set_view(Vector3(over[0]["pos"].x, 2, over[0]["pos"].y), 25, 40, 26)
	await shot("pace_overcap_card.png")
	hud.close_panels()
	# лишние ничего не стоят: снесём их — содержание за час не изменится
	c.sim_day()
	var up0 := float(c.stats["upkeep"])
	for s in over:
		c.remove(s, false)
	c.sim_day()
	var up1 := float(c.stats["upkeep"])
	check(is_equal_approx(up0, up1), "idle schools cost nothing: upkeep %.2f with them, %.2f without" % [up0, up1])
	for s in schools:
		if c.buildings.has(s["id"]):
			c.remove(s, false)
	# 11) новый уровень — по кнопке: условия Хутора (20 жителей, счастье 55%, фруктовая лавка, скрипторий)
	c.level = 0
	c.goals_done = OLD10.duplicate()
	c.tips.erase("rank_pressed")
	c.tips.erase("rank_tip")
	c.money = 3000.0
	var fr := put("stall_fruit", Vector2(176, 143), cands)
	check(not fr.is_empty(), "fruit stall")
	c.compute()
	c.stats["happy"] = 60                    # счастье подставляем: проверяем кнопку, а не лавки
	check(c.rank_ok() and c.goal_progress("hamlet") == 4 and not c.goals_done.has("hamlet"),
		"«Хутор» ready: %d of %d conditions, request not done until the press" % [c.rank_met(), c.rank_needs().size()])
	var ev0: int = c.events.size()
	c._update_level()                        # то, что делает час: город сам уровень не поднимает
	check(c.level == 0 and bool(c.stats["rank_ready"]), "the city does not rank up by itself (level %d)" % c.level)
	check(c.events.size() == ev0 + 1 and String(c.events[-1]["text"]).contains("готов стать «Хутор»"), "one quiet bell note: «%s»" % String(c.events[-1]["text"]))
	c._update_level()
	check(c.events.size() == ev0 + 1, "…and only once")
	hud.advisor_panel.visible = false
	hud.refresh()
	check(hud.rank_btn.visible, "button «Перейти на новый уровень» is shown")
	check(hud.advisor_panel.visible and hud.adv_title.text == "Город готов к новому уровню!" and c.tips.has("rank_tip"), "advisor explains it once: «%s»" % hud.adv_title.text)
	check(hud.pointer_target == hud.rank_btn, "the arrow points at the button the first time")
	game.rig.set_view(Vector3(180, 2, 143), 20, 50, 46)
	await shot("pace_rank_btn.png")
	hud.advisor_panel.visible = false
	hud._show_hover(hud.hover_level)
	hud._hover_hold = 30                      # мыши над плашкой нет — подсказку держим для снимка
	await frames(2)
	var tip_txt := _texts(hud.hover_box)
	check(tip_txt.contains("Готово 4 из 4") and tip_txt.contains("Фруктовая лавка") and tip_txt.contains("Всё готово"), "level tooltip: checklist 4 of 4")
	game.rig.set_view(Vector3(180, 2, 143), 20, 50, 46)
	await shot("pace_rank_ready.png")
	hud._hide_hover()
	var got := []
	c.level_up.connect(func(l): got.append(l))
	hud.press_rank()
	check(c.level == 1 and got == [1], "pressed: level %d, level_up %s" % [c.level, got])
	check(c.goals_done.has("hamlet") and c.tips.has("rank_pressed") and not hud.rank_btn.visible, "«Станьте хутором» done, button gone")
	# Деревня — пока не готова: чек-лист с крестиками
	hud._show_hover(hud.hover_level)
	hud._hover_hold = 30                      # мыши над плашкой нет — подсказку держим для снимка
	await frames(2)
	tip_txt = _texts(hud.hover_box)
	check(tip_txt.contains("Следующий уровень — «Деревня»") and tip_txt.contains("Разные лавки еды"), "next checklist: «Деревня»")
	await shot("pace_level_tip.png")
	hud._hide_hover()
	# 12) «Казна полна — доход пропадает», «Полки полны — очки пропадают»
	c.tips.erase("full_money")                # (казна уже переполнялась выше, когда ставили школы)
	c.tips.erase("full_rp")
	c.money = c.money_cap()
	c.rp = c.rp_cap()
	hud.advisor_panel.visible = false
	c.sim_day()                              # (час сам обновляет интерфейс — значки и совет)
	check(float(c.stats["money_lost"]) > 0.0 and hud.full_money.visible, "treasury full: income lost %.1f, mark shown" % float(c.stats["money_lost"]))
	check(float(c.stats["rp_lost"]) > 0.0 and hud.full_rp.visible, "shelves full: rp lost %.1f, mark shown" % float(c.stats["rp_lost"]))
	check(c.tips.has("full_money") and hud.advisor_panel.visible and hud.adv_title.text == "Казна полна", "advisor explains the full treasury once: «%s»" % hud.adv_title.text)
	await shot("pace_full_marks.png")
	hud.advisor_panel.visible = false
	c.money = 500.0
	c.rp = 10.0
	hud.refresh()
	check(not hud.full_money.visible and not hud.full_rp.visible, "marks go away when there is room")
	# 13) карточка станции: условия, повозка, место в домах
	hud.open_info(c.center())
	var ctr: Dictionary = c.center()
	game.rig.set_view(Vector3(ctr["pos"].x, 2, ctr["pos"].y), 25, 40, 30)
	await frames(3)
	var st_txt := _texts(hud.info_box)
	check(st_txt.contains("Повозка с семьями") and st_txt.contains("Место в домах") and st_txt.contains("Склад"), "station card: arrivals and checklist")
	await shot("pace_station_info.png")
	hud.close_panels()


## Условие уровня lv достижимо: всё нужное открывается исследованиями уровня lv − 1 или раньше ("" — да)
func _need_err(p: Array, n: int, lv: int) -> String:
	match String(p[0]):
		"count":
			return "" if _open_by(String(Defs.B[p[1]].get("unlock", "")), lv - 1) else String(p[1])
		"shops":
			var k := 0
			for t in Defs.B:
				if Defs.B[t]["kind"] == "shop" and Defs.B[t].get("sub", "") == p[1] and _open_by(String(Defs.B[t].get("unlock", "")), lv - 1):
					k += 1
			return "" if k >= n else "%s: %d < %d" % [p[1], k, n]
		"floors":
			return "" if _open_by(String(Defs.FLOOR_RESEARCH.get(int(p[1]), "")), lv - 1) else "floors %d" % int(p[1])
		"cls":
			return "" if _open_by(String(Defs.B[Defs.CLASSES[p[1]]["house"]].get("unlock", "")), lv - 1) else String(p[1])
	return "unknown " + String(p[0])


## Исследование u и вся его цепочка «after» открываются на уровне lv или раньше
func _open_by(u: String, lv: int) -> bool:
	var r := Defs.research(u)
	while not r.is_empty():
		if int(r["lvl"]) > lv:
			return false
		r = Defs.research(String(r.get("after", "")))
	return true


## Все надписи внутри узла — одной строкой (проверить, что окно говорит)
func _texts(n: Node) -> String:
	var out := ""
	for l in n.find_children("*", "Label", true, false):
		out += (l as Label).text + " | "
	for b in n.find_children("*", "Button", true, false):
		out += (b as Button).text + " | "
	return out


# ---------- бот: игра до Вечного города ----------
## Бот играет как внимательный игрок при скорости 1× (повозку и путь семьи до дома изображает сам): улицы сеткой —
## жилые ряды через 14 м и «площадные» ряды с местом для больших построек; дома впрок, чтобы повозке было куда
## везти; лавки на все нужды и для разнообразия; склады и поля; писцы, школы, библиотеки и академии до предела
## уровня; сначала — условия следующего уровня (копит на них деньги); украшения, фонтаны, храмы, этажи; с «Посёлка» —
## игры в честь богов, как только можно; улицы на своей земле кончились, а строить негде — покупает участок сбоку.
## Жмёт «Перейти на новый уровень», как только можно. По каждому рангу пишет: минуты, долю ряда исследований
## к переходу, часы с полной казной, пропавшие очки, сколько семей ждало сразу, сколько было игр и куплено участков,
## на что ушли деньги; в конце — таблица «PACE TABLE».

## Ряды улиц вдоль x: [z, площадной, поперечные улицы] — площадной ряд в 24 м от соседей: храм, форум, школа, театр
## встанут. Сначала — своя земля новой игры (x 128–256, z 64–256); у станции и большой дороги (x 178–206 севернее
## z 112) рядов нет. Кончилось место — бот покупает участок сбоку (B_PLOTS) и ведёт ряды дальше (B_EXT_*)
const B_WEST := [134.0, 157.0, 178.0]
const B_EAST := [206.0, 228.0, 250.0]
const B_SOUTH := [134.0, 157.0, 180.0, 203.0, 226.0, 250.0]
const B_EXT_W := [68.0, 89.0, 112.0, 134.0]
const B_EXT_E := [250.0, 272.0, 295.0, 316.0]
const B_ROWS := [[80.0, false, [B_WEST, B_EAST, B_EXT_W, B_EXT_E]], [94.0, false, [B_WEST, B_EAST, B_EXT_W, B_EXT_E]],
	[108.0, false, [B_WEST, B_EAST, B_EXT_W, B_EXT_E]], [122.0, false, [B_SOUTH, B_EXT_W, B_EXT_E]], [136.0, false, [B_SOUTH, B_EXT_W, B_EXT_E]],
	[160.0, true, [B_SOUTH, B_EXT_W, B_EXT_E]], [184.0, false, [B_SOUTH, B_EXT_W, B_EXT_E]], [198.0, false, [B_SOUTH, B_EXT_W, B_EXT_E]],
	[222.0, true, [B_SOUTH, B_EXT_W, B_EXT_E]], [246.0, false, [B_SOUTH, B_EXT_W, B_EXT_E]],
	[270.0, false, [B_SOUTH, B_EXT_W, B_EXT_E]], [284.0, false, [B_SOUTH, B_EXT_W, B_EXT_E]], [308.0, true, [B_SOUTH, B_EXT_W, B_EXT_E]]]
## какие участки бот покупает, когда места нет (по порядку; сначала — к востоку, где нет прудов)
const B_PLOTS := [Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 1),
	Vector2i(3, 4), Vector2i(2, 4), Vector2i(4, 4), Vector2i(1, 4)]
const B_PONDS := [Vector3(215, 150, 7.5), Vector3(130, 182, 13.0), Vector3(260, 214, 11.0), Vector3(102, 124, 9.0), Vector3(176, 262, 17.0)]
const B_HOME := Vector2(185.0, 128.0)            # от станции город растёт вниз по карте
## крупное — сначала у площадных рядов
const B_BIG := ["school", "library", "academy", "temple", "forum", "odeon", "theatre", "baths", "balnea", "fountain",
	"farm", "grove", "vineyard", "warehouse", "taberna"]
## минут на ранге по плану экономики (Стоянка — вместе с обучением; бот его не проходит — прибавляем TUT_MIN)
const B_TARGET := [12.0, 10.0, 30.0, 35.0, 40.0, 55.0, 71.0]
const TUT_MIN := 6.0
## исследования, которые бот берёт в первую очередь (после нужных для следующего уровня); дальше — от дешёвого
const B_KEY := ["stall_veg", "stall_fish", "scribes1", "floor2", "warehouse", "artisans", "school", "weaver", "musicians",
	"fountain", "scribes2", "floor3", "temple", "dice", "patricians", "library", "research1", "barber", "balnea", "vault1",
	"forum", "academy", "odeon", "theatre", "taxes1", "vault2"]
## не берёт: Легион и его чудеса (у бота нет походов и Славы), животных
const B_SKIP := ["legion", "archery", "arch", "colosseum", "pantheon", "animals"]

var t := 0.0                         # игровых часов от начала
var cart := "wait"                   # повозка: wait (за краем карты) → in → out → wait
var cart_t := 0.0
var cart_load: Array = []           # семьи в повозке (City.make_load при выезде)
var walks: Array = []                # [час прихода, дом, человек, семья]
var reqs := {}
var segs: Array = []                 # отрезки рядов по порядку прокладки: [от, до, площадной]
var seg_i := 0                       # сколько отрезков проложено
var seg_done := {}                   # номер отрезка → проложен
var side_spent := 0.0                # денарии на мостовые и участки (их не считаем в трату того, что строили)
var land_t := -1.0                   # когда улицы на своей земле кончились впервые
var last_plot_t := -99.0             # когда куплен последний участок
var cols_done := {}                  # проложенные поперечные улицы между рядами
var hc: Array = []                   # точки у жилых рядов
var cc: Array = []                   # точки у площадных рядов
var dead := {}                       # тип → {точка: true}: там этому типу не встать (занято, круто, вода)
var rk := {}                         # счёт текущего ранга
var rows_out: Array = []             # итоги рангов
var headless := false
var frugal := false                  # бережливый игрок: только условия уровня и нужды (frugal=1)
## История «Разбойники у арки» (Д9): бот не играет истории, но как игрок соглашается помочь — Казармы и учебный бой.
## Когда её предложат — по правилам историй: «Где Мурка?» через FIRST_H после обучения на «Хуторе» (~STORY_H на неё),
## эта — через GAP_H после неё
const STORY_H := 12.0                # история — около 5 минут игры
var d9 := {"state": "wait", "t": -1.0}   # wait → cat (идёт «Мурка») → ask (предложена) → build (нужны Казармы) → fight → done
## Здания Легиона (Д10) — главная трата денег середины игры: бот ставит Кузницу, Лазарет и Склад оружия, как только
## откроются, и улучшает здания по таймерам (настоящие часы при 1×: Legion.clock), но только из лишних денег —
## после покупки в казне не меньше LEG_SAVE × запаса на условия уровня (_bsave) и LEG_KEEP предела казны.
## Бои бот не ведёт: Слава только учебного боя (уровни с 6-го просят Славы — до них бот не дойдёт)
const LEG_SAVE := 1.5
const LEG_KEEP := 0.25
var clock0 := 0.0
var leg_keep := LEG_KEEP
var leg_ups := 0                     # сколько улучшений зданий Легиона куплено за игру
var leg_spent := 0.0


func _bot() -> void:
	headless = DisplayServer.get_name() == "headless"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):                # «-- bot seed=7» — другой случай: семьи, цвета (разброс итогов)
			c.rng.seed = int(a.substr(5))
		if a == "frugal=1":
			frugal = true
		if a.begins_with("leg_keep="):            # доля казны, которую бот не тратит на Легион (проверка порога)
			leg_keep = float(a.substr(9))
	print("PACE BOT start: cart %.1f h each way, walk %.1f h, 1 h = %.0f s at 1x; goal «%s»; seed %d%s; start money %d, econ %d" % [CART_H, WALK_H, SEC_H,
		Defs.LEVELS[-1]["name"], int(c.rng.seed), " FRUGAL" if frugal else "", int(c.money), int(c.econ)])
	clock0 = Time.get_unix_time_from_system()
	Legion.clock = clock0
	_bot_layout()
	game.rig.set_view(Vector3(190, 2, 165), 20, 62, 130)
	_rank_start()
	_bstreet()
	_bstreet()
	for i in 3:                               # как в обучении: три дома у дороги — и повозка едет
		_bput("house_pleb", B_HOME, false)
	var lvl := 0
	var wall0 := Time.get_ticks_msec()
	while t < MAX_H and c.level < Defs.LEVELS.size() - 1:
		for k in 8:
			_bot_step()
		if c.level != lvl:
			lvl = c.level
			if lvl in [1, 3, 5, 7] and not headless:
				game.hud.advisor_panel.visible = false
				await shot("pace_bot_rank%d.png" % lvl)
		if int(t) % 20 == 0 and is_equal_approx(t, floorf(t)):
			var left := []
			for e: Dictionary in c.rank_needs():
				if not e["ok"]:
					left.append("%s %d/%d" % [e["text"], int(e["have"]), int(e["need"])])
			print("  .. %d h (%.0f min): lvl %d pop %d happy %d money %d rp %d houses %d buildings %d · wall %.0f s · next needs %s" % [int(t), t * SEC_H / 60.0, c.level,
				int(c.stats["pop"]), int(c.stats["happy"]), int(c.money), int(c.rp), _houses().size(), c.buildings.size(), (Time.get_ticks_msec() - wall0) / 1000.0, left])
		if t - float(rk["t0"]) > 250.0:
			var alive := {}
			for tp in ["house_pleb", "house_artisan", "house_patrician"]:
				var dd: Dictionary = dead.get(tp, {})
				alive[tp] = [hc.filter(func(q): return not dd.has(q)).size(), cc.filter(func(q): return not dd.has(q)).size()]
			print("PACE BOT stalled at «%s»: %d h without a new rank; next needs %s; waiting %s; fit %s; incoming %d; spots alive [rows, civic] %s; block «%s»" % [
				Defs.LEVELS[c.level]["name"], int(t - float(rk["t0"])), c.rank_needs(), c.arrivals, c.fit_by_class(), c.incoming, alive, c.stats.get("arrive_block", "")])
			break
		await frames(1)
	if c.level >= Defs.LEVELS.size() - 1 and not headless:
		game.hud.advisor_panel.visible = false
		game.rig.set_view(Vector3(192, 2, 165), 20, 58, 150)
		await shot("pace_bot_end.png")
	_summary()


## Улицы бота: ряды по отрезкам между поперечными улицами, от станции наружу; не через пруды
func _bot_layout() -> void:
	var all := []
	for r: Array in B_ROWS:
		for cols: Array in r[2]:
			for i in cols.size() - 1:
				var a := Vector2(cols[i], r[0])
				var b := Vector2(cols[i + 1], r[0])
				if not _wet(a, b):
					all.append([a, b, bool(r[1])])
	all.sort_custom(func(x, y): return ((x[0] + x[1]) * 0.5).distance_to(B_HOME) < ((y[0] + y[1]) * 0.5).distance_to(B_HOME))
	segs = all


func _wet(a: Vector2, b: Vector2) -> bool:
	for p: Vector3 in B_PONDS:
		var q := Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.y), a, b)
		if q.distance_to(Vector2(p.x, p.y)) < p.z + 3.0:
			return true
	return false


## Отрезок целиком на своей земле (и дома по обе стороны, и поперечные улицы к ряду выше)
func _seg_owned(s: Array) -> bool:
	var a: Vector2 = s[0]
	var b: Vector2 = s[1]
	for i in int(a.distance_to(b)) + 1:
		var p := a.move_toward(b, float(i))
		for q: Vector2 in [p, p + Vector2(0, 7.0), p - Vector2(0, 7.0)]:
			if not game.land.is_owned(q):
				return false
	return true


## Ещё не проложенные отрезки на своей земле (помним до новой улицы или участка)
var _left_cache := -1


func _streets_left() -> int:
	if _left_cache < 0:
		_left_cache = 0
		for i in segs.size():
			if not seg_done.has(i) and _seg_owned(segs[i]):
				_left_cache += 1
	return _left_cache


## Проложить следующий отрезок ряда на своей земле (и поперечные улицы к соседнему ряду у его концов)
func _bstreet() -> bool:
	var si := -1
	for i in segs.size():
		if not seg_done.has(i) and _seg_owned(segs[i]):
			si = i
			break
	if si < 0:
		return false
	seg_done[si] = true
	seg_i += 1
	_left_cache = -1
	var s: Array = segs[si]
	var a: Vector2 = s[0]
	var b: Vector2 = s[1]
	_paint(a, b)
	# поперечные: к ближнему ряду выше (к станции), если его нет — не надо
	var ri := -1
	for i in B_ROWS.size():
		if is_equal_approx(float(B_ROWS[i][0]), a.y):
			ri = i
	var cols := []
	for cs: Array in B_ROWS[ri][2]:
		cols.append_array(cs)
	for x in [a.x, b.x]:
		if ri > 0 and (x < 178.0 or x > 206.0 or a.y > 112.0):
			var key := "%d:%d" % [int(x), ri]
			var top := Vector2(x, float(B_ROWS[ri - 1][0]))
			var own: bool = game.land.is_owned(top) and game.land.is_owned((top + Vector2(x, a.y)) * 0.5)
			if not cols_done.has(key) and own and not _wet(top, Vector2(x, a.y)):
				cols_done[key] = true
				_paint(top, Vector2(x, a.y))
	var dir := (b - a).normalized()
	var side := Vector2(-dir.y, dir.x)
	for i in int(a.distance_to(b)) + 1:
		var p := a + dir * i
		var near_col := false
		for x in cols:
			if absf(p.x - x) < 2.6:
				near_col = true
		if near_col:
			continue
		for sg in [-3.2, 3.2]:
			(cc if s[2] else hc).append(p + side * sg)
	return true


func _paint(a: Vector2, b: Vector2) -> void:
	var ch: Array = game.land.paint_line(a, b, 1.3, Land.Kind.ROAD, true)
	c.road_cells += ch.size()
	_spent("roads", ch.size() * float(Defs.ROAD_COST["road"]))
	c.money -= ch.size() * float(Defs.ROAD_COST["road"])


## Поставить постройку у дорог бота поближе к цели. big — сперва у площадных рядов. Мест нет — новая улица
func _bput(type: String, target: Vector2, big: bool, tries := 40) -> Dictionary:
	var d: Dictionary = Defs.B[type]
	if c.money < float(d["cost"]) or not c.unlocked(type) or c.cap_err(type) != "":
		return {}
	for attempt in 3:
		var pools := [cc, hc] if big else [hc, cc]
		if type == "house_patrician":
			pools = [cc, hc]                          # домус глубокий — спиной к спине в жилом ряду не встаёт
		elif d["kind"] == "house":
			pools = [hc] if _streets_left() > 0 else [hc, cc]
		for pool: Array in pools:
			var b := _try_pool(type, target, pool, tries)
			if not b.is_empty():
				return b
		# новая улица; на своей земле улицы кончились — купить участок сбоку, как игрок, которому негде строить
		# (не ради украшения; и не ради поля: бот ставит только к дороге, а полю она не нужна — у бота оно не встаёт)
		if not _bstreet() and not (not (d["kind"] in ["decor", "farm"]) and _bland(type) and _bstreet()):
			break
	return {}


## Места на своей земле нет: купить участок сбоку (B_PLOTS по порядку), если хватает сверх запаса на условия уровня
func _bland(why: String) -> bool:
	if land_t < 0.0:
		land_t = t
		print("  .. %d h (%s): all streets on own land are laid" % [int(t), Defs.LEVELS[c.level]["name"]])
	return _buy_plot("no room for «%s»" % why, _bsave(), false)


## Купить следующий участок: сперва те, куда бот ведёт ряды (B_PLOTS), потом (any) любой у своей земли.
## Не больше участка в полсуток (сперва обжить купленный) и не в ущерб запасу на условия уровня
func _buy_plot(why: String, keep: float, any := true) -> bool:
	if t - last_plot_t < 12.0:
		return false
	var opts: Array = B_PLOTS.duplicate()
	if any:
		for j in Land.PLOTS:
			for i in Land.PLOTS:
				opts.append(Vector2i(i, j))
	for p: Vector2i in opts:
		if not c.can_buy(p):
			continue
		var price: int = c.plot_price()
		if c.money - float(price) < keep or not c.buy_plot(p):
			return false
		last_plot_t = t
		_left_cache = -1
		rk["plots"] = int(rk["plots"]) + 1
		_spent("land", float(price))
		print("  .. %d h: %s — bought plot %s for %d" % [int(t), why, p, price])
		return true
	return false


## Казна почти полна, доход вот-вот начнёт пропадать — как советует советник («участки земли за краем своей»):
## купить участок впрок, если хватает сверх запаса на условия уровня
func _bland_rich(save: float) -> void:
	if c.money >= c.money_cap() * 0.9:
		_buy_plot("treasury %d%% full" % roundi(100.0 * c.money / c.money_cap()), save)


func _try_pool(type: String, target: Vector2, pool: Array, tries: int) -> Dictionary:
	var d: Dictionary = Defs.B[type]
	if not dead.has(type):
		dead[type] = {}
	var dt: Dictionary = dead[type]
	var idx := []
	for i in pool.size():
		var key := pool[i] as Vector2
		if not dt.has(key):
			idx.append(i)
	idx.sort_custom(func(x, y): return (pool[x] as Vector2).distance_squared_to(target) < (pool[y] as Vector2).distance_squared_to(target))
	var n := 0
	for i in idx:
		if n >= tries:
			break
		n += 1
		var p: Vector2 = pool[i]
		reset()
		var pl: Dictionary = game.placement(type, p)
		var err: String = pl["err"]
		if err == "" and (d["kind"] == "decor" or pl["sub"] == "road"):
			return c.place(type, pl["pos"], pl["yaw"], pl["variant"], pl["color"])
		# бот ничего не сносит: что мешает здесь сейчас (занято, круто, вода, вход соседа), мешает и потом;
		# временное — только деньги, исследование, предел уровня и некупленная земля
		if not (err.begins_with("Не хватает") or err.begins_with("Откроется") or err.contains("не больше") or err.contains("пока не строят") \
				or err.contains("предел") or err.contains("уже есть") or err.contains("не куплена")):
			dt[p] = true
	return {}


func _houses() -> Array:
	var out := []
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		if c.is_house(b) and int(b["pop"]) + int(b.get("coming", 0)) > 0:
			out.append(b)
	return out


func _mid() -> Vector2:
	var hs := _houses()
	if hs.is_empty():
		return B_HOME
	var m := Vector2.ZERO
	for h in hs:
		m += h["pos"]
	return m / hs.size()


func _bot_step() -> void:
	var h0 := int(floor(t))
	t += STEP_H
	Legion.clock = clock0 + t * SEC_H          # таймеры улучшений Легиона — по «настоящим» часам игры при 1×
	# повозка: стоит за краем карты, пока некого везти; туда и обратно — по CART_H
	match cart:
		"wait":
			if t >= cart_t and c.incoming > 0:
				# как в игре: семьи собираются при выезде, каждой держится место (people._cart_step)
				cart_load = c.make_load(c.incoming)
				c.incoming = cart_load.size()
				if not cart_load.is_empty():
					cart = "in"
					cart_t = t + CART_H
					if bool(cart_load[0].get("seek", false)):
						rk["seek"] = int(rk["seek"]) + 1     # семья «ищет жильё»: места ей нет
		"in":
			if t >= cart_t:
				for f in cart_load:
					c.family_arrived(f)
				cart = "out"
				cart_t = t + 0.12 + CART_H         # разгрузка 3 с — и назад
		"out":
			if t >= cart_t:
				cart = "wait"
				cart_t = t + 0.16
	for w in walks.duplicate():
		if t >= float(w[0]):
			walks.erase(w)
			var b: Dictionary = c.buildings.get(w[1], {})
			if not b.is_empty():
				b["coming"] = maxi(0, int(b.get("coming", 0)) - int(w[2]))
			c.settled(int(w[1]), int(w[2]), String(w[3]))
	_settle()
	rk["max_wait"] = maxi(int(rk["max_wait"]), c.arrivals.size())
	if int(floor(t)) != h0:
		_bplay()
		_fest_back()
		c.sim_day()
		_hour_stats()
		for g in c.goals_done:
			if not reqs.has(g):
				reqs[g] = t
				var gq := Defs.request(g)
				if not gq.is_empty():
					rk["rp_req"] = float(rk["rp_req"]) + float(gq["rp"])
					rk["den_req"] = float(rk.get("den_req", 0.0)) + float(gq["money"])
					print("ECONREQ t=%.1f lvl=%d %s +%d rp +%d den (rp now %d/%d, money %d/%d)" % [t, c.level, g, int(gq["rp"]), int(gq["money"]), int(c.rp), int(c.rp_cap()), int(c.money), int(c.money_cap())])
		_econ_hour()
		_bstory()
		if c.rank_ok():
			_press()


## Семьи с площади — в дома: сперва туда, где уже живут (полный дом можно надстроить), счастливее — раньше.
## Дома нет — построить дом класса семьи
func _settle() -> void:
	for f in c.arrivals.duplicate():
		var homes: Array = c.homes_for(f)
		if homes.is_empty():
			var type: String = Defs.CLASSES[f["cls"]]["house"]
			if c.money >= float(Defs.B[type]["cost"]):
				var m0 := _m0()
				_bput(type, B_HOME, false)
				_spend("houses", m0)
				homes = c.homes_for(f)
		if homes.is_empty():
			continue
		homes.sort_custom(func(x, y): return _home_key(x) > _home_key(y))
		var hb: Dictionary = homes[0]
		if c.assign(f["name"], hb["id"]):
			walks.append([t + WALK_H, hb["id"], int(f["n"]), String(f["name"])])


func _home_key(b: Dictionary) -> int:
	return (1000 if int(b["pop"]) + int(b.get("coming", 0)) > 0 else 0) + int(b["happy"])


# ---------- бот: решения раз в час ----------

func _bplay() -> void:
	_bresearch()
	if _houses().is_empty():
		return
	var save := _bsave()
	var m0 := _m0()
	_bstory_build()
	_spend("legion", m0)
	m0 = _m0()
	_bneed()
	_spend("need", m0)
	m0 = _m0()
	_bfest(save)
	_spend("festivals", m0)
	m0 = _m0()
	_bhouses()
	_spend("houses", m0)
	m0 = _m0()
	_brp(save)
	_spend("rp", m0)
	m0 = _m0()
	_bshops(save)
	_spend("shops", m0)
	m0 = _m0()
	_bmonuments(save)
	_spend("monuments", m0)
	m0 = _m0()
	_bdecor(save)
	_spend("decor", m0)
	m0 = _m0()
	_bfloors(save)
	_spend("floors", m0)
	m0 = _m0()
	_blegion(save)
	_spend("legion", m0)
	_bland_rich(save)
	c.compute()


## Счёт трат по видам: [деньги, побочные траты] до дела; после — разница без мостовых и участков (их считают сами)
func _m0() -> Array:
	return [c.money, side_spent]


func _spend(cat: String, m0: Array) -> void:
	var d: float = float(m0[0]) - c.money - (side_spent - float(m0[1]))
	if d > 0.5:
		var sp: Dictionary = rk["spend"]
		sp[cat] = float(sp.get(cat, 0.0)) + d


func _spent(cat: String, v: float) -> void:
	side_spent += v
	var sp: Dictionary = rk["spend"]
	sp[cat] = float(sp.get(cat, 0.0)) + v


## Игры возвращают часть цены налогами: пока идут, счастье домов +8% (до 100%) — и налог дома больше (как в City.sim_day)
func _fest_back() -> void:
	var fb: int = c.fest_bonus()
	if fb <= 0:
		return
	var x := 0.0
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		if c.is_house(b):
			x += int(b["pop"]) * c.house_tax(b) * (minf(100.0, float(b["happy"])) - minf(100.0, float(b["happy"]) - fb)) / 100.0
	rk["fest_back"] = float(rk["fest_back"]) + x


## Игры в честь богов (с «Посёлка»): как только можно и хватает (запас на условия уровня — как у лавок, наполовину)
func _bfest(save: float) -> void:
	if frugal:
		return
	var pr: int = c.fest_price()
	if c.can_festival() == "" and c.money - float(pr) >= save * (1.0 if _pop_met() else 0.5) and c.festival():
		rk["fests"] = int(rk["fests"]) + 1
		rk["fest_cost"] = float(rk["fest_cost"]) + pr     # точно: в трату «festivals» может влезть награда просьбы


## Жителей на следующий уровень уже хватает — осталось накопить на постройки условий: этажи и игры не трогают запас
func _pop_met() -> bool:
	return c.level < Defs.LEVELS.size() - 1 and int(c.stats.get("pop", 0)) >= int(Defs.LEVELS[c.level + 1]["pop"])


## Исследования: сначала то, что откроет условия следующего уровня, потом ключевое, потом остальное своего ряда
## от дешёвого. Копит на первое по порядку
func _bresearch() -> void:
	var order: Array = _need_research()
	for id in B_KEY:
		if not (id in order):
			order.append(id)
	var rest := []
	for r in Defs.RESEARCH:
		if not (r["id"] in order):
			rest.append(r)
	rest.sort_custom(func(a, b): return int(a["cost"]) < int(b["cost"]))
	for r in rest:
		order.append(r["id"])
	for id in order:
		var r := Defs.research(id)
		if r.is_empty() or c.research.has(id) or int(r["lvl"]) > c.level or id in B_SKIP or r.has("story"):
			continue
		if r.has("after") and not c.research.has(r["after"]):
			continue
		var why: String = c.can_research(id)
		if why == "":
			var rp_before: float = c.rp
			c.do_research(id)
			rk["n_res"] = int(rk.get("n_res", 0)) + 1
			rk["res_rp"] = float(rk.get("res_rp", 0.0)) + float(r["cost"])
			rk["res_max_frac"] = maxf(float(rk.get("res_max_frac", 0.0)), float(r["cost"]) / maxf(1.0, rp_before))
			print("ECONRES t=%.1f lvl=%d %s cost %d (lvl%d) rp before %d -> %d, cap %d, rp/h %.1f" % [t, c.level, id, int(r["cost"]), int(r["lvl"]), int(rp_before), int(c.rp), int(c.rp_cap()), float(c.stats.get("rp_day", 0.0))])
			continue
		if why.begins_with("Не помещается"):
			continue                              # дороже полок — копить бесполезно: сперва другое (полки — в B_KEY)
		break


## Какие исследования открывают невыполненные условия следующего уровня (с цепочкой «after» — сначала первое)
func _need_research() -> Array:
	var out := []
	for e: Dictionary in _needs_left():
		var p: Array = e["p"]
		var ids := []
		match String(p[0]):
			"count":
				ids.append(String(Defs.B[p[1]].get("unlock", "")))
			"shops":
				var opts := []
				for tp in Defs.B:
					var d: Dictionary = Defs.B[tp]
					if d["kind"] == "shop" and d.get("sub", "") == p[1] and not c.unlocked(tp):
						var r := Defs.research(String(d.get("unlock", "")))
						if not r.is_empty() and int(r["lvl"]) <= c.level:
							opts.append(r)
				opts.sort_custom(func(a, b): return int(a["cost"]) < int(b["cost"]))
				var open := 0
				for tp in Defs.B:
					if Defs.B[tp]["kind"] == "shop" and Defs.B[tp].get("sub", "") == p[1] and c.unlocked(tp):
						open += 1
				for k in mini(opts.size(), maxi(0, int(e["n"]) - open)):
					ids.append(String(opts[k]["id"]))
			"floors":
				ids.append(String(Defs.FLOOR_RESEARCH.get(int(p[1]), "")))
			"cls":
				ids.append(String(Defs.B[Defs.CLASSES[p[1]]["house"]].get("unlock", "")))
		for id in ids:
			var chain := []
			var r := Defs.research(id)
			while not r.is_empty():
				chain.push_front(r["id"])
				r = Defs.research(String(r.get("after", "")))
			for x in chain:
				if not (x in out):
					out.append(x)
	return out


## Невыполненные условия следующего уровня (только постройки): [{p, n}]
func _needs_left() -> Array:
	var out := []
	if c.level >= Defs.LEVELS.size() - 1:
		return out
	for n: Dictionary in Defs.LEVELS[c.level + 1]["need"]:
		if c.progress_of(n["p"]) < int(n["n"]):
			out.append(n)
	return out


## Сколько денег держать на постройки условий следующего уровня (уже открытые или открываемые сейчас)
func _bsave() -> float:
	var s := 0.0
	for e: Dictionary in _needs_left():
		var p: Array = e["p"]
		if String(p[0]) == "count" and Defs.B[p[1]]["kind"] != "house":
			var u := String(Defs.B[p[1]].get("unlock", ""))
			var r := Defs.research(u)
			if u == "" or c.research.has(u) or (not r.is_empty() and int(r["lvl"]) <= c.level):
				s += float(Defs.B[p[1]]["cost"]) * (int(e["n"]) - c.progress_of(p))
	return minf(s, c.money_cap() * 0.9)


## Свободные работники для мест класса cl (он сам и те, кто выше: высшие подменяют низших)
func _spare(cl: String) -> int:
	var fr: Dictionary = c.stats.get("free", {})
	var n := 0
	for k in range(Defs.CLASS_ORDER.find(cl), Defs.CLASS_ORDER.size()):
		n += int(fr.get(Defs.CLASS_ORDER[k], 0))
	return n


func _can_staff(type: String) -> bool:
	var jb: Dictionary = Defs.B[type].get("jobs", {})
	for cl in jb:
		if _spare(cl) < int(jb[cl]):
			return false
	return true


## Постройки условий следующего уровня: сразу, как только открыты и хватает денег
func _bneed() -> void:
	for e: Dictionary in _needs_left():
		var p: Array = e["p"]
		match String(p[0]):
			"count":
				var type: String = p[1]
				if Defs.B[type]["kind"] == "house":
					continue                          # дома ремесленников и патрициев — в _bhouses
				if c.unlocked(type) and c.money >= float(Defs.B[type]["cost"]):
					_bput(type, _mid(), type in B_BIG)
			"shops":
				var hs := _houses()
				for tp in _shop_order(String(p[1])):
					if n_of(tp) == 0 and c.money >= float(Defs.B[tp]["cost"]):
						_bshop(tp, hs)
						break


## Лавки вида sub, открытые, — от лучшей к худшей
func _shop_order(sub: String) -> Array:
	var out := []
	for tp in Defs.B:
		var d: Dictionary = Defs.B[tp]
		if d["kind"] == "shop" and (sub == "" or d.get("sub", "") == sub) and c.unlocked(tp):
			out.append(tp)
	out.sort_custom(func(a, b): return int(Defs.B[a]["bonus"]) > int(Defs.B[b]["bonus"]))
	return out


## Класс для нового дома: кого не хватает в работниках; дальше — по долям (больше ремесленников и патрициев,
## когда открыты); условия уровня (дома ремесленников, патриции) — в первую очередь
func _house_class() -> String:
	var open := []
	for cl in Defs.CLASS_ORDER:
		if c.unlocked(Defs.CLASSES[cl]["house"]):
			open.append(cl)
	for e: Dictionary in _needs_left():
		var p: Array = e["p"]
		if String(p[0]) == "count" and p[1] in ["house_artisan", "house_patrician"]:
			var cl := "artisans" if p[1] == "house_artisan" else "patricians"
			if cl in open:
				return cl
		if String(p[0]) == "cls" and p[1] in open:
			return p[1]
	for cl in ["patricians", "artisans"]:
		if cl in open and int(c.stats["jobs"].get(cl, 0)) > int(c.stats["workers"].get(cl, 0)):
			return cl
	var share := {"plebs": 1.0}
	if "patricians" in open:
		share = {"plebs": 0.45, "artisans": 0.35, "patricians": 0.2}
	elif "artisans" in open:
		share = {"plebs": 0.6, "artisans": 0.4}
	var cnt := {}
	var tot := 0
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		if c.is_house(b):
			var cl: String = c.def(b)["cls"]
			cnt[cl] = int(cnt.get(cl, 0)) + 1
			tot += 1
	var best := "plebs"
	var gap := -INF
	for cl in share:
		var g := float(share[cl]) - float(cnt.get(cl, 0)) / maxf(1.0, float(tot))
		if g > gap:
			gap = g
			best = cl
	return best


## Жильё впрок: место хотя бы для двух семей должно быть всегда (иначе повозка встанет)
func _bhouses() -> void:
	for k in 3:
		if c.free_fit() >= 2:
			return
		var cl := _house_class()
		var built := false
		for type: String in [Defs.CLASSES[cl]["house"], "house_artisan", "house_pleb"]:
			if c.unlocked(type) and c.money >= float(Defs.B[type]["cost"]) and not _bput(type, B_HOME, false).is_empty():
				built = true
				break
		if not built:
			return


## Писцы, школы, библиотеки, академии — до предела уровня, если есть кому работать (одна постройка в час)
func _brp(save: float) -> void:
	for type in ["scriptorium", "school", "library", "academy"]:
		if not c.unlocked(type) or c.cap_err(type) != "" or not _can_staff(type):
			continue
		if c.money - float(Defs.B[type]["cost"]) < save * 0.5 + 50.0:
			continue
		if not _bput(type, _mid(), type != "scriptorium").is_empty():
			return


## Лавки: сначала нужды (у домов класса нет лавки нужного вида), потом разнообразие. Не больше трёх в час
func _bshops(save: float) -> void:
	var hs := _houses()
	var placed := 0
	for n in Defs.NEED_ORDER:
		var miss := hs.filter(func(h): return n in h.get("missing", []))
		if miss.is_empty():
			continue
		for tp in _shop_order(n):
			if not _can_staff(tp) or c.money - float(Defs.B[tp]["cost"]) < save * 0.5:
				continue
			if _bshop(tp, miss):
				placed += 1
			break
		if placed >= 3:
			return
	# разнообразие — как у игрока: домам, где счастье ниже 80%, и не больше лавки на дом
	if frugal:
		return
	var shops := 0
	for id in c.buildings:
		if c.def(c.buildings[id])["kind"] == "shop":
			shops += 1
	for tp in _shop_order(""):
		if placed >= 2 or shops >= hs.size():
			return
		if not _can_staff(tp) or c.money - float(Defs.B[tp]["cost"]) < save + 150.0:
			continue
		# новая игра (econ): вторая лавка того же вида даёт вполовину — бот, как игрок, берёт вид, которого у дома ещё нет
		var sub := String(Defs.B[tp].get("sub", ""))
		var un := hs.filter(func(h): return int(h["pop"]) > 0 and int(h["happy"]) < 80 and not (h["score"] as Dictionary).has(tp) and (c.econ < 1 or not (h.get("needs", {}) as Dictionary).has(sub)))
		if un.size() < 6:
			continue
		if _bshop(tp, un):
			placed += 1
			shops += 1


## Лавку — к домам из списка (к первому и соседям в 22 м); нужен склад или сырьё — сперва их
func _bshop(type: String, hs: Array) -> bool:
	if hs.is_empty():
		return false
	var d: Dictionary = Defs.B[type]
	var h0: Vector2 = hs[0]["pos"]
	var m := Vector2.ZERO
	var k := 0
	for h in hs:
		if (h["pos"] as Vector2).distance_to(h0) <= 22.0:
			m += h["pos"]
			k += 1
	var tg := m / maxi(1, k)
	if d.has("needs_good") and not c.goods.has(d["needs_good"]):
		for tp in Defs.B:
			if Defs.B[tp].get("makes", "") == d["needs_good"] and c.unlocked(tp) and _can_staff(tp):
				_bput(tp, tg, true)
		return false
	if d.get("store", false) and not _store_at(tg):
		if c.unlocked("warehouse") and _can_staff("warehouse"):
			_bput("warehouse", tg, true)
		return false
	return not _bput(type, tg, type in B_BIG).is_empty()


func _store_at(p: Vector2) -> bool:
	var r := float(Defs.RANGE[4]) * (2.0 if c.research.has("store1") else 1.0) - 6.0
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		if b["type"] == "warehouse" and (b["pos"] as Vector2).distance_to(p) <= r:
			return true
	return false


## Фонтаны (по одному на 30 домов), храмы (на 90 домов) — когда хватает и на условия уровня
func _bmonuments(save: float) -> void:
	var nh := _houses().size()
	for e: Array in [["fountain", 30], ["temple", 90]]:
		var tp: String = e[0]
		if not c.unlocked(tp) or n_of(tp) >= 1 + nh / int(e[1]) or not _can_staff(tp):
			continue
		if c.money - float(Defs.B[tp]["cost"]) < save + 200.0:
			continue
		# туда, где этого памятника ещё нет
		var far := _houses().filter(func(h): return not (h.get("mon_types", {}) as Dictionary).has(tp))
		if far.size() < 8:
			continue
		_bput(tp, far[0]["pos"], true)
		return


## Украшения: домам, где их меньше всего, — до предела класса; не больше четырёх в час
func _bdecor(save: float) -> void:
	if c.money < save + 120.0:
		return
	if frugal and c.goals_done.has("lights") and c.goals_done.has("decor5") and c.level >= 1:
		return                                    # бережливый: украшения — только для первых просьб
	var hs := _houses()
	hs.sort_custom(func(x, y): return int(x.get("deco_bonus", 0)) < int(y.get("deco_bonus", 0)))
	var k := 0
	for h in hs:
		if k >= 4 or c.money < save + 120.0:
			return
		var cd: Dictionary = Defs.CLASSES[c.def(h)["cls"]]
		if int(h.get("deco_bonus", 0)) >= int(cd.get("deco_max", 12)):
			return
		var type := "lamp_post" if n_of("lamp_post") < 3 else ("flowers" if c.unlocked("flowers") else "bench")
		if k % 2 == 1 and c.unlocked("tree"):
			type = "tree"
		if c.econ >= 1 and n_of("lamp_post") >= 3:
			type = _fresh_decor(h)                # новая игра: одинаковые рядом дают меньше — берёт вид, которого у дома меньше всего
		# только в полосе за задней стеной (между рядами 3 м) — место под дома соседнего ряда не занимаем
		var f := City.facing(float(h["yaw"]))
		var ax := City.axis(float(h["yaw"]))
		var back: Vector2 = (h["pos"] as Vector2) - f * (_depth(h["type"]) * 0.5 + 0.7)
		var ring := []
		for s in [0.0, -1.1, 1.1, -2.2, 2.2]:
			ring.append(back + ax * s)
		if not _try_pool(type, back, ring, 5).is_empty():
			k += 1


## Бережливому игроку этаж нужен: условие следующего уровня (дома в N этажей) или просьба об этажах ещё не выполнены,
## либо повозке некуда везти семьи
func _floor_needed() -> bool:
	for e: Dictionary in _needs_left():
		if String((e["p"] as Array)[0]) == "floors":
			return true
	for g in c.active_goals():
		if String((g["p"] as Array)[0]) == "floors":
			return true
	return c.free_fit() < 2


## История «Разбойники у арки» (Д9) — по правилам предложения историй (StoryDefs.FIRST_H, GAP_H, lvl, «после Мурки»);
## игрок соглашается сразу: Легион открыт, Казармы — как только хватает денариев, потом учебный бой (победа с маслом)
func _bstory() -> void:
	var sh := float(c.stories["h"])
	match String(d9["state"]):
		"wait":
			if c.level >= 1 and sh >= StoryDefs.FIRST_H:
				d9 = {"state": "cat", "t": t}              # «Где Мурка?» — первой
		"cat":
			# «Разбойники» — вскоре после «Мурки» (своя пауза gap_h, владелец: Легион почти со старта)
			if t >= float(d9["t"]) + STORY_H + float(StoryDefs.story("bandits").get("gap_h", StoryDefs.GAP_H)):
				d9 = {"state": "build", "t": t}
				c.research["legion"] = true
				c.legion.flags["advised"] = true
				print("ECOND9 t=%.1f lvl=%d story «Разбойники у арки» offered and accepted: Legion opened (money %d)" % [t, c.level, int(c.money)])
		"fight":
			if t >= float(d9["t"]) + 0.5:
				var lg: Legion = c.legion
				var setup := lg.make_battle(lg.stage_info(0, 0, 0), 1)
				var m0: float = c.money
				var out := lg.apply_result(setup, {"win": true, "alive": 3, "total": 3, "timeout": false, "time": 45.0})
				var r0: float = c.rp
				c.rp = maxf(c.rp, minf(c.rp_cap(), c.rp + float(StoryDefs.story("bandits")["reward"]["rp"])))
				rk["rp_req"] = float(rk["rp_req"]) + (c.rp - r0)
				d9 = {"state": "done", "t": t}
				print("ECOND9 t=%.1f lvl=%d training battle won (%s), money %+d, story done: +%d rp" % [t, c.level, str(out.get("reward", {})), int(c.money - m0), int(c.rp - r0)])


## Казармы для истории: как только хватает (и не в ущерб половине запаса на условия уровня; через 6 ч ждать — хватит и денег)
func _bstory_build() -> void:
	if String(d9["state"]) != "build":
		return
	var cost := float(Defs.B["barracks"]["cost"])
	if c.money < cost or (c.money - cost < _bsave() * 0.5 and t < float(d9["t"]) + 6.0):
		return
	var b := _bput("barracks", Land.GATE + Vector2(13.0, 16.0), true)
	if not b.is_empty():
		var waited := t - float(d9["t"])
		d9 = {"state": "fight", "t": t}
		_d9_lvl = c.level
		print("ECOND9 t=%.1f lvl=%d barracks built for %d (waited %.1f h), money left %d" % [t, c.level, int(cost), waited, int(c.money)])


## Здания Легиона (Д10): поставить открывшееся здание поддержки, иначе начать самое дешёвое доступное улучшение —
## только из лишних денег (LEG_SAVE, LEG_KEEP). Таймеры идут сами (Legion.clock), бот только платит
func _blegion(save: float) -> void:
	var lg: Legion = c.legion
	if not lg.window_open() or String(d9["state"]) in ["wait", "cat", "build"]:
		return
	var keep := maxf(save * LEG_SAVE, c.money_cap() * leg_keep)
	for bt: String in Legion.SUPPORT:
		if c.unlocked(bt) and not lg.b_built(bt) and c.money - float(Defs.B[bt]["cost"]) >= keep:
			var b := _bput(bt, Land.GATE + Vector2(13.0, 16.0), true)
			if not b.is_empty():
				rk["leg_built"] = int(rk.get("leg_built", 0)) + 1
				print("ECONLEG t=%.1f lvl=%d built %s for %d, money left %d" % [t, c.level, bt, int(Defs.B[bt]["cost"]), int(c.money)])
				return
	var best := ""
	var bc := INF
	for bt: String in Legion.BUILDING_IDS:
		var key := Legion.bkey(bt)
		if lg.can_upgrade(key) != "":
			continue
		var cost := float(lg.upgrade_info(key)["cost"].get("money", 0))
		if cost < bc:
			bc = cost
			best = key
	if best != "" and c.money - bc >= keep and lg.upgrade(best):
		leg_ups += 1
		leg_spent += bc
		print("ECONLEG t=%.1f lvl=%d upgrade %s → %d for %d (ready in %.1f h), money left %d" % [t, c.level, Legion.building_of(best), int(lg.upg[best]["to"]), int(bc),
			float(lg.upg[best]["total"]) / SEC_H, int(c.money)])


## Есть ли что изучать (без Легиона) и хватает ли очков хоть на что-то; доля казны и полок
func _econ_hour() -> void:
	var avail := []
	for r in Defs.RESEARCH:
		if c.research.has(r["id"]) or int(r["lvl"]) > c.level or r["id"] in B_SKIP or r.has("story"):
			continue
		if r.has("after") and not c.research.has(r["after"]):
			continue
		avail.append(float(r["cost"]))
	if avail.is_empty():
		rk["idle"] = int(rk.get("idle", 0)) + 1
	elif c.rp < avail.min():
		rk["starved"] = int(rk.get("starved", 0)) + 1
	rk["mfrac"] = float(rk.get("mfrac", 0.0)) + c.money / maxf(1.0, c.money_cap())
	rk["rfrac"] = float(rk.get("rfrac", 0.0)) + c.rp / maxf(1.0, c.rp_cap())


## Виды украшений, которые бот ставит в полосе за домами (небольшие: в полосе 3 м между рядами, не на место домов)
const B_DECOR := ["flowers", "tree", "bench", "planter", "bush", "lamp_post"]


## Вид украшения, которого у дома (в DECOR_RADIUS) меньше всего, — как игрок, который прочёл совет «Разнообразие»
func _fresh_decor(h: Dictionary) -> String:
	var best := "bench"
	var bk := 1 << 20
	for base: String in B_DECOR:
		if not c.unlocked(base):
			continue
		var n := 0
		for id in c.buildings:
			var o: Dictionary = c.buildings[id]
			if Defs.base_of(o["type"]) == base and (o["pos"] as Vector2).distance_to(h["pos"]) <= Defs.DECOR_RADIUS:
				n += 1
		var key := n * 100 - int(Defs.B[base]["deco"])
		if key < bk:
			bk = key
			best = base
	return best


## Глубина постройки (по следу), м
var _depths := {}


func _depth(type: String) -> float:
	if not _depths.has(type):
		var r := Rect2()
		var first := true
		for q: Rect2 in Catalog.make(type, 1, 0, 0).footprint():
			r = q if first else r.merge(q)
			first = false
		_depths[type] = r.size.y
	return float(_depths[type])


## Этажи — всем домам, которым можно (полный дом, счастье от 65% / 75%), пока хватает и на условия уровня
func _bfloors(save: float) -> void:
	if frugal and not _floor_needed():
		return
	for h in _houses():
		if c.can_buy_floor(h) == "" and c.money - float(c.floor_price(h)) >= save * (1.0 if _pop_met() else 0.3):
			c.buy_floor(h)


# ---------- бот: счёт по рангам ----------

func _rank_start() -> void:
	rk = {"t0": t, "hours": 0, "cap_h": 0, "rp_earned": 0.0, "rp_lost": 0.0, "max_wait": 0, "seek": 0, "money_lost": 0.0,
		"poor_h": 0, "money_min": INF, "fests": 0, "plots": 0, "spend": {}, "net": 0.0, "fest_h": 0, "rp_req": 0.0, "fest_back": 0.0, "fest_cost": 0.0}


func _hour_stats() -> void:
	rk["hours"] = int(rk["hours"]) + 1
	rk["net"] = float(rk["net"]) + float(c.stats["income"]) - float(c.stats["upkeep"])
	if c.fest_left > 0:
		rk["fest_h"] = int(rk["fest_h"]) + 1
	if c.money >= c.money_cap() - 1.0:
		rk["cap_h"] = int(rk["cap_h"]) + 1
	if c.money < 150.0:
		rk["poor_h"] = int(rk["poor_h"]) + 1
	rk["money_min"] = minf(float(rk["money_min"]), c.money)
	rk["rp_earned"] = float(rk["rp_earned"]) + float(c.stats["rp_day"])
	rk["rp_lost"] = float(rk["rp_lost"]) + float(c.stats.get("rp_lost", 0.0))
	rk["money_lost"] = float(rk["money_lost"]) + float(c.stats.get("money_lost", 0.0))


## Доля ряда исследований lvl (по цене), изученная к этому часу; skip — без Легиона и чудес (боту они не нужны)
func _tier_pct(lvl: int, skip := true) -> float:
	var all := 0
	var got := 0
	for r in Defs.RESEARCH:
		if int(r["lvl"]) == lvl and not (skip and r["id"] in B_SKIP):
			all += int(r["cost"])
			if c.research.has(r["id"]):
				got += int(r["cost"])
	return 100.0 * got / maxf(1.0, float(all))


func _press() -> void:
	var L: int = c.level
	var mins := (t - float(rk["t0"])) * SEC_H / 60.0
	var hrs := maxi(1, int(rk["hours"]))
	var row := {"lvl": L, "min": mins, "tier": _tier_pct(L), "tier_all": _tier_pct(L, false), "cap": 100.0 * int(rk["cap_h"]) / hrs,
		"lost": 100.0 * float(rk["rp_lost"]) / maxf(1.0, float(rk["rp_earned"]) + float(rk["rp_lost"])), "wait": int(rk["max_wait"]),
		"seek": int(rk["seek"]), "poor": 100.0 * int(rk["poor_h"]) / hrs, "mlost": float(rk["money_lost"]), "fests": int(rk["fests"]),
		"plots": int(rk["plots"]), "earned": float(rk["rp_earned"]), "net": float(rk["net"]),
		"fnet": float(rk["fest_cost"]) - float(rk["fest_back"])}
	var hh := maxf(1.0, float(rk["hours"]))
	var tot_rp := float(rk["rp_earned"]) + float(rk["rp_req"])
	row["rp_req_pct"] = 100.0 * float(rk["rp_req"]) / maxf(1.0, tot_rp)
	row["den_req_pct"] = 100.0 * float(rk.get("den_req", 0.0)) / maxf(1.0, float(rk["net"]) + float(rk.get("den_req", 0.0)))
	row["n_res"] = int(rk.get("n_res", 0))
	row["h_res"] = hh / maxf(1.0, float(rk.get("n_res", 0)))
	row["idle"] = 100.0 * float(rk.get("idle", 0)) / hh
	row["starved"] = 100.0 * float(rk.get("starved", 0)) / hh
	row["max_frac"] = 100.0 * float(rk.get("res_max_frac", 0.0))
	rows_out.append(row)
	print("ECONRANK %s | hours %d | rp passive %d, requests %d (%d%% of rp) | money requests %d vs net taxes %d (%d%%) | researches %d (%.1f h apart) rp spent %d | starved h %d%% | idle-research h %d%% | avg money/cap %d%% | avg rp/cap %d%% | below 150 den %d%% | at cap %d%%" % [Defs.LEVELS[L]["name"], int(hh),
		int(rk["rp_earned"]), int(rk["rp_req"]), roundi(row["rp_req_pct"]), int(rk.get("den_req", 0.0)), int(rk["net"]), roundi(row["den_req_pct"]),
		int(rk.get("n_res", 0)), float(row["h_res"]), int(rk.get("res_rp", 0.0)), roundi(row["starved"]), roundi(row["idle"]),
		roundi(100.0 * float(rk.get("mfrac", 0.0)) / hh), roundi(100.0 * float(rk.get("rfrac", 0.0)) / hh), roundi(row["poor"]), roundi(row["cap"])])
	var sp: Dictionary = rk["spend"]
	var parts := []
	var tot := 0.0
	for k in sp:
		tot += float(sp[k])
	var keys := sp.keys()
	keys.sort_custom(func(a, b): return float(sp[a]) > float(sp[b]))
	for k in keys:
		parts.append("%s %d" % [k, int(sp[k])])
	var fsp := float(rk["fest_cost"])
	print("  «%s» money: net income %d, spent %d (%s), lost to the cap %d; festivals %d (%d h on; cost %d, back in taxes %d, net sink %d), plots %d; rp earned %d" % [Defs.LEVELS[L]["name"],
		int(rk["net"]), int(tot), ", ".join(parts), int(rk["money_lost"]), int(rk["fests"]), int(rk["fest_h"]), int(fsp), int(rk["fest_back"]),
		int(fsp - float(rk["fest_back"])), int(rk["plots"]), int(rk["rp_earned"])])
	print("RANK %d «%s» at %.1f h = %.1f min (1x) | «%s» lasted %.1f min | tier %d researched %d%% (%d%% counting Legion/wonders) | treasury at cap %d%% of %d h, money lost %d, below 150 den %d%% | rp lost %d%% | max waiting %d | seekers %d | pop=%d happy=%d money=%d/%d rp=%d/%d houses=%d buildings=%d | rp/h %.1f, net den/h %d" % [
		L + 1, Defs.LEVELS[L + 1]["name"], t, t * SEC_H / 60.0, Defs.LEVELS[L]["name"], mins, L, roundi(row["tier"]), roundi(row["tier_all"]), roundi(row["cap"]), hrs,
		int(row["mlost"]), roundi(row["poor"]), roundi(row["lost"]), row["wait"], row["seek"], int(c.stats["pop"]), int(c.stats["happy"]), int(c.money),
		int(c.money_cap()), int(c.rp), int(c.rp_cap()), _houses().size(), c.buildings.size(), float(c.stats["rp_day"]),
		int(float(c.stats["income"]) - float(c.stats["upkeep"]))])
	c.rank_up()
	_rank_start()


## На каком ранге бот поставил Казармы для истории Д9 (−1 — не поставил)
var _d9_lvl := -1


func _d9_rank() -> int:
	return _d9_lvl


## Итог: минуты по рангам против плана, доля ряда к переходу, казна у предела, пропавшие очки, ожидание семей
func _summary() -> void:
	var line := "PACE BOT minutes at rank (1x, Стоянка +%d min tutorial):" % int(TUT_MIN)
	var acc := []
	for row: Dictionary in rows_out:
		var L: int = row["lvl"]
		var m: float = float(row["min"]) + (TUT_MIN if L == 0 else 0.0)
		line += " %s %.1f;" % [Defs.LEVELS[L]["name"], m]
		if L < B_TARGET.size():
			var ok := absf(m / B_TARGET[L] - 1.0) <= 0.25
			acc.append("%s %.0f/%.0f %s" % [Defs.LEVELS[L]["name"], m, B_TARGET[L], "ok" if ok else "MISS"])
	print(line)
	print("PACE BOT vs plan (±25%%): %s" % ", ".join(acc))
	var tiers := []
	var caps := []
	var lost := []
	var waits := []
	for row: Dictionary in rows_out:
		var L: int = row["lvl"]
		tiers.append("%d:%d%%%s" % [L, roundi(row["tier"]), "" if L == 0 or (row["tier"] >= 70.0 and row["tier"] <= 90.0) else "!"] +
			(" (%d%% with Legion/wonders)" % roundi(row["tier_all"]) if absf(float(row["tier_all"]) - float(row["tier"])) > 0.5 else ""))
		caps.append("%d:%d%%%s" % [L, roundi(row["cap"]), "" if L < 2 or row["cap"] < 20.0 else "!"])
		lost.append("%d:%d%%%s" % [L, roundi(row["lost"]), "" if row["lost"] < 10.0 else "!"])
		waits.append("%d:%d" % [L, int(row["wait"])])
	print("PACE BOT tier researched at rank-up (want 70-90%%; the bot skips Legion and its wonders): %s" % ", ".join(tiers))
	print("PACE BOT treasury at cap, %% of hours (want <20%% from Деревня): %s" % ", ".join(caps))
	print("PACE BOT rp overflow (want <10%%): %s" % ", ".join(lost))
	print("PACE BOT max families waiting (want ≤3): %s" % ", ".join(waits))
	# одна таблица по рангам (как в отчёте этапа 1a) — и сколько игр и участков
	print("PACE TABLE | rank | min (1x) | plan | tier researched | treasury at cap | rp lost | max waiting | festivals | festivals net sink (den) | plots bought |")
	for row: Dictionary in rows_out:
		var L: int = row["lvl"]
		var m: float = float(row["min"]) + (TUT_MIN if L == 0 else 0.0)
		print("PACE TABLE | %s | %.1f | %s | %d%% | %d%% | %d%% | %d | %d | %d | %d |" % [Defs.LEVELS[L]["name"], m, ("%.0f" % B_TARGET[L]) if L < B_TARGET.size() else "-",
			roundi(row["tier"]), roundi(row["cap"]), roundi(row["lost"]), int(row["wait"]), int(row["fests"]), int(row["fnet"]), int(row["plots"])])
	# очки и деньги по рангам (этап 2.0): доля очков и денег от просьб, часов между исследованиями, без дела, казна
	print("ECON TABLE | rank | min | h between researches | researches | rp from requests | idle-research h | money from requests | below 150 den | treasury at cap | dearest research / rp before |")
	for row: Dictionary in rows_out:
		var L: int = row["lvl"]
		print("ECON TABLE | %s | %.1f | %.1f | %d | %d%% | %d%% | %d%% | %d%% | %d%% | %d%% |" % [Defs.LEVELS[L]["name"], float(row["min"]) + (TUT_MIN if L == 0 else 0.0),
			float(row.get("h_res", 0.0)), int(row.get("n_res", 0)), roundi(float(row.get("rp_req_pct", 0.0))), roundi(float(row.get("idle", 0.0))),
			roundi(float(row.get("den_req_pct", 0.0))), roundi(row["poor"]), roundi(row["cap"]), roundi(float(row.get("max_frac", 0.0)))])
	print("ECON D9 | state %s at %.1f h | barracks on rank %s" % [d9["state"], float(d9["t"]), Defs.LEVELS[int(_d9_rank())]["name"] if _d9_rank() >= 0 else "—"])
	var lgs := []
	for bt: String in Legion.BUILDING_IDS:
		if c.legion.b_built(bt):
			lgs.append("%s %d" % [Defs.B[bt]["name"], c.legion.b_level(bt)])
	print("ECON LEGION | buildings %s | upgrades bought %d, spent %d den" % [", ".join(lgs) if not lgs.is_empty() else "—", leg_ups, int(leg_spent)])
	print("PACE BOT end at %.1f h = %.1f min: level %d «%s» pop=%d happy=%d money=%d rp=%d research=%d houses=%d buildings=%d" % [t, t * SEC_H / 60.0,
		c.level, Defs.LEVELS[c.level]["name"], int(c.stats["pop"]), int(c.stats["happy"]), int(c.money), int(c.rp), c.research.size(), _houses().size(), c.buildings.size()])
	var kinds := {}
	for id in c.buildings:
		var kd: String = c.def(c.buildings[id])["kind"]
		kinds[kd] = int(kinds.get(kd, 0)) + 1
	var alive := 0
	for p in hc:
		if not (dead.get("house_pleb", {}) as Dictionary).has(p):
			alive += 1
	print("PACE BOT built %s; streets %d of %d; house spots left %d of %d" % [kinds, seg_i, segs.size(), alive, hc.size()])
	check(c.level == Defs.LEVELS.size() - 1, "bot reached «%s»" % Defs.LEVELS[-1]["name"])
	var w := 0
	for row: Dictionary in rows_out:
		w = maxi(w, int(row["wait"]))
	check(w <= 3, "families waiting at once ≤ 3 (max %d)" % w)
	print("PACE BOT fails=%d" % fails)
