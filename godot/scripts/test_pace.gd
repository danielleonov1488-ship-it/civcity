extends Node
## Темп начала игры: предел скрипториев по уровням города, очки исследований в час (почта на станции,
## ученики писцов), перенос живого сохранения (просьбы 1–10 выполнены, хутор, 51 житель, 97 очков)
## и жадный бот — сколько минут при скорости 1× до Хутора, Деревни и Посёлка.
##   bash .work/py/gpu_run.sh res://test_pace.tscn             — проверки, в конце «PACE CHECKS fails=0»
##   bash .work/py/gpu_run.sh res://test_pace.tscn -- bot      — бот: «RANK …», «REQ …», «PACE BOT …»
## Время идёт вручную (скорость 0, city.sim_day() по часам); повозку и путь семьи до дома бот
## изображает сам (CART_H, WALK_H). Новые имена берутся без строгих типов — бот идёт и на старых данных.

const OLD10 := ["road1", "houses3", "fam3", "fruit", "scriptorium", "research1", "lights", "fed6", "pop30", "decor5"]
const SEC_H := 25.0                  # секунд в игровом часе при 1× (Game.DAY_LEN / 24)
const CART_H := 1.3                  # повозка от края карты до станции, часов (за кадром втрое быстрее)
const WALK_H := 0.5                  # семья идёт от станции до дома
const STEP_H := 0.25
const MAX_H := 1400.0
const RESEARCH_ORDER := ["deco_flowers", "stall_veg", "stall_fish", "musicians", "scribes1", "floor2", "fountain",
	"warehouse", "butcher", "deco_trees", "reach1", "weaver", "bakery", "animals", "farm", "cobbler"]
const SHOPS := ["stall_fruit", "stall_veg", "stall_fish", "musicians", "butcher"]
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
	check(c.goals_done.has("hamlet"), "«Хутор: 20 жителей» done after one hour")
	check(is_equal_approx(rpd, 3.5), "rp/h at «Хутор» = 2 + 1.5: %.2f" % rpd)
	check(is_equal_approx(float(c.rp), 97.0 + rpd + 40.0), "rp after the hour = 97 + %.1f + 40: %.1f" % [rpd, float(c.rp)])
	check(c.level == 1 and int(c.stats["pop"]) == 51, "still «Хутор»: pop %d, level %d" % [int(c.stats["pop"]), c.level])
	check(c.can_research("floor2") == "", "«Второй жилой этаж» (100) affordable: «%s»" % c.can_research("floor2"))
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
	check(is_equal_approx(rpd, 5.5), "rp/h with 2 scriptoria = 2×2 + 1.5: %.2f" % rpd)
	c.research["scribes1"] = true
	c.sim_day()
	rpd = float(c.stats["rp_day"])
	check(is_equal_approx(c.rp_per_hour("scriptorium"), 3.0) and is_equal_approx(rpd, 7.5),
		"«Ученики писцов»: %.1f per scriptorium, %.2f/h (2×3 + 1.5)" % [c.rp_per_hour("scriptorium"), rpd])
	c.research["scribes2"] = true
	check(is_equal_approx(c.rp_per_hour("scriptorium"), 4.0), "«Мастерская писцов»: %.1f per scriptorium" % c.rp_per_hour("scriptorium"))
	var mx := []
	for lv in Defs.LEVELS.size():
		c.level = lv
		mx.append(c.build_max("scriptorium"))
	c.level = 1
	check(mx == [1, 2, 3, 4, 5, 6, 8, 10], "scriptorium cap by level: %s" % [mx])
	check(c.build_max("school") == -1 and c.cap_err("school") == "", "school is not capped")
	check(int(K["ARRIVE_FREE"]) == 7 and float(K["ARRIVE_EVERY"][0]) == 2.0 and int(Defs.LEVELS[1]["pop"]) == 20 and int(Defs.LEVELS[2]["pop"]) == 60,
		"arrivals: 7 free families, cart every 2 h; ranks 20 / 60")
	# окна и подсказки с новыми строками
	var v := VBoxContainer.new()
	game.hud._tip_level(v)
	v.free()
	game.hud.open_info(c.center())
	var ctr: Dictionary = c.center()
	game.rig.set_view(Vector3(ctr["pos"].x, 2, ctr["pos"].y), 25, 40, 30)
	await shot("pace_station_info.png")
	game.hud.close_panels()
	print("PACE CHECKS fails=%d" % fails)


# ---------- жадный бот ----------

var t := 0.0                         # игровых часов от начала
var cart := "wait"                   # повозка: wait (за краем карты) → in → out → wait
var cart_t := 0.0
var cart_load := 0
var walks: Array = []                # [час прихода, дом, человек, семья]
var reqs := {}
var old := false


func _bot() -> void:
	old = not c.has_method("build_max")
	print("PACE BOT start (%s data): cart %.1f h each way, walk %.1f h, 1 h = %.0f s at 1x" % ["old" if old else "new", CART_H, WALK_H, SEC_H])
	game.rig.set_view(Vector3(178, 2, 152), 20, 54, 80)
	street()
	street()
	for i in 3:                               # как в обучении: три дома у дороги — и повозка едет
		put("house_pleb", Vector2(182, 143), cands)
	var lvl := 0
	var ranks := {}
	while t < MAX_H and c.level < 3:
		for k in 8:
			_bot_step()
		if c.level != lvl:
			for L in range(lvl + 1, c.level + 1):
				ranks[L] = t
				print("RANK %d «%s» at %.1f h = %.1f min (1x): pop=%d happy=%d rp=%d money=%d houses=%d scriptoria=%d" % [L, Defs.LEVELS[L]["name"], t,
					t * SEC_H / 60.0, int(c.stats["pop"]), int(c.stats["happy"]), int(c.rp), int(c.money), _houses().size(), n_of("scriptorium")])
			lvl = c.level
			if lvl <= 2:
				await shot("pace_rank%d_%s.png" % [lvl, "old" if old else "new"])
		await frames(1)
	var line := "PACE BOT (%s data, 1x minutes, no tutorial):" % ("old" if old else "new")
	for L in [1, 2, 3]:
		line += " %s %s;" % [Defs.LEVELS[L]["name"], ("%.1f" % (float(ranks[L]) * SEC_H / 60.0)) if ranks.has(L) else "not reached"]
	print(line)
	print("PACE BOT end at %.1f h: pop=%d happy=%d rp=%d research=%s" % [t, int(c.stats["pop"]), int(c.stats["happy"]), int(c.rp), c.research.keys()])
	if not old:
		# цель плана: Хутор ≤ 13 мин, Деревня ≤ 35 мин — вместе с обучением (~6 мин)
		check(ranks.has(1) and float(ranks[1]) * SEC_H / 60.0 + 6.0 <= 13.0, "Хутор with tutorial ≤ 13 min")
		check(ranks.has(2) and float(ranks[2]) * SEC_H / 60.0 + 6.0 <= 35.0, "Деревня with tutorial ≤ 35 min")
		print("PACE BOT fails=%d" % fails)


func _houses() -> Array:
	var out := []
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		if c.is_house(b) and int(b["pop"]) + int(b.get("coming", 0)) > 0:
			out.append(b)
	return out


func _bot_step() -> void:
	var h0 := int(floor(t))
	t += STEP_H
	# повозка: стоит за краем карты, пока некого везти; туда и обратно — по CART_H
	match cart:
		"wait":
			if t >= cart_t and c.incoming > 0:
				cart = "in"
				cart_load = c.incoming
				cart_t = t + CART_H
		"in":
			if t >= cart_t:
				for k in cart_load:
					c.family_arrived(c.new_family(c.pick_class()))
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
	if int(floor(t)) != h0:
		_build()
		c.sim_day()
		for g in c.goals_done:
			if not reqs.has(g):
				reqs[g] = t
				print("REQ %s at %.1f h = %.1f min" % [g, t, t * SEC_H / 60.0])


## Семьи с площади — в дома: сперва туда, где уже живут (полный дом можно надстроить), счастливее — раньше
func _settle() -> void:
	for f in c.arrivals.duplicate():
		var homes: Array = c.homes_for(f)
		if homes.is_empty() and c.money >= 100.0:
			var b := put("house_pleb", Vector2(182, 143), cands)
			while b.is_empty() and street():
				b = put("house_pleb", Vector2(182, 143), cands)
			homes = c.homes_for(f)
		if homes.is_empty():
			continue
		homes.sort_custom(func(x, y): return _home_key(x) > _home_key(y))
		var hb: Dictionary = homes[0]
		if c.assign(f["name"], hb["id"]):
			walks.append([t + WALK_H, hb["id"], int(f["n"]), String(f["name"])])


func _home_key(b: Dictionary) -> int:
	return (1000 if int(b["pop"]) + int(b.get("coming", 0)) > 0 else 0) + int(b["happy"])


## Раз в час: исследования, скрипторий, лавки, украшения, этажи
func _build() -> void:
	for id in RESEARCH_ORDER:
		var r := Defs.research(id)
		if r.is_empty() or c.research.has(id) or int(r["lvl"]) > c.level or (r.has("after") and not c.research.has(r["after"])):
			continue
		if c.can_research(id) == "":
			c.do_research(id)
		break                                 # ждём очков на первое по порядку
	var houses := _houses()
	if houses.is_empty():
		return
	var mid := Vector2.ZERO
	for h in houses:
		mid += h["pos"]
	mid /= houses.size()
	var free_w := int((c.stats["free"] as Dictionary).get("plebs", 0))
	var mx: int = int(c.call("build_max", "scriptorium")) if not old else c.level + 1
	if n_of("scriptorium") < mx and c.money >= 300.0 and (free_w >= 2 or n_of("scriptorium") == 0):
		if not put("scriptorium", mid + Vector2(0, -8), cands).is_empty():
			free_w -= 2
	for type in SHOPS:
		if not c.unlocked(type) or (type == "butcher" and n_of("warehouse") == 0):
			continue
		var un := houses.filter(func(h): return not (h["score"] as Dictionary).has(type))
		if un.is_empty() or c.money < float(Defs.B[type]["cost"]) + 100.0:
			continue
		if n_of(type) > 0 and (free_w < 1 or n_of(type) * 6 > houses.size() + 6):
			continue
		var m2 := Vector2.ZERO
		for h in un:
			m2 += h["pos"]
		if not put(type, m2 / un.size(), cands).is_empty():
			free_w -= 1
	for type in ["warehouse", "fountain"]:
		if c.unlocked(type) and n_of(type) == 0 and c.money >= float(Defs.B[type]["cost"]) + 200.0 and (type != "warehouse" or free_w >= 2):
			put(type, mid, cands)
	# украшения: дому — до 12 очков (+6% счастья); первые три — фонари (просьба горожан)
	houses.sort_custom(func(x, y): return float(x.get("deco", 0.0)) < float(y.get("deco", 0.0)))
	var k := 0
	for h in houses:
		if k >= 3 or float(h.get("deco", 0.0)) >= 12.0 or c.money < 150.0:
			break
		var type := "lamp_post" if n_of("lamp_post") < 3 else ("flowers" if c.unlocked("flowers") else "bench")
		var back: Vector2 = (h["pos"] as Vector2) - City.facing(float(h["yaw"])) * 4.0
		var ring := []
		for r in [2.0, 3.5, 5.0, 6.5]:
			for a in 12:
				var p: Vector2 = back + Vector2(cos(TAU * a / 12.0), sin(TAU * a / 12.0)) * r
				if not game.land.is_road(p):
					ring.append(p)
		if not put(type, back, ring, 24).is_empty():
			k += 1
	for h in houses:
		if c.can_buy_floor(h) == "":
			c.buy_floor(h)
	c.compute()
