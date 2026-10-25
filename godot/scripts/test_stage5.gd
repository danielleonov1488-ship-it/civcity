extends Node
## Этап 5 плана от 24.10 (docs/PLAN_2026-10-24_tech.md 5.1–5.5): больше украшений и зданий.
##   bash .work/py/gpu_run.sh res://test_stage5.tscn              — новая игра; в конце «S5 DONE fails=0»; снимки — .work/gd/b/s5_*.png
##   … -- mode=owner                                               — копия города владельца: старые облики открыты, как были
##   … -- shots=0                                                  — без снимков наборов (быстрее)
## 5.1 перепись: облики по уровням (новая игра и живой город), новые виды; на каждом уровне есть что поставить
## 5.2 наборы по исследованию; в новой игре часть прежних обликов — позже (DECOR_LATER), в живом городе — как были
## 5.3 «главные» украшения радуют, как памятник, сверх предела украшений
## 5.4 бонус набора (три разных вида рядом с домом); меню украшений: новые вкладки, ★, недавние, поиск, силуэты
## 5.5 новые здания: огород, приют, кукольный театр, травник, пост вигилов, мастерская скульптора, дом префекта, нимфей —
##     работают (лавки кормят и радуют, памятники радуют округу), животные у коровы, лошади и в приюте

const OWNER := "D:/CivCity/.work/owner_save/city.json"
const SHOTS := "D:/CivCity/.work/gd/b/"
const NEW_B := ["ogorod", "shelter", "puppets", "herbalist", "vigiles", "sculptor", "prefect", "nymphaeum"]
var game
var c: City
var land: Land
var fails := 0
var mode := ""
var shots := true


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("mode="):
			mode = a.trim_prefix("mode=")
		if a == "shots=0":
			shots = false
	if mode == "owner" and FileAccess.file_exists(OWNER):
		DirAccess.copy_absolute(OWNER, GamePaths.save_dir().path_join("city.json"))
		Game.boot = {"play": "1", "hour": "11"}
	else:
		Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, what: String, extra = null) -> bool:
	print(("S5 PASS " if ok else "S5 FAIL ") + what + ("" if ok or extra == null else "  " + str(extra)))
	if not ok:
		fails += 1
	return ok


func shot(name: String) -> void:
	await frames(10)
	DirAccess.make_dir_recursive_absolute(SHOTS)
	get_viewport().get_texture().get_image().save_png(SHOTS + name)
	print("SHOT ", SHOTS + name)


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	c = game.city
	land = game.land
	game.can_save = false
	if mode == "owner":
		await _owner()
	else:
		await _new()
	print("S5 DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


# ---------- перепись ----------

static func rank_of(u: String) -> int:
	if u == "":
		return 0
	var r := Defs.research(u)
	if not r.is_empty():
		return 99 if r.has("story") else int(r["lvl"])
	var rk := 0
	for q in Defs.REQUESTS:
		if String(q.get("unlock", "")) == u:
			return rk
		if String(q["p"][0]) == "rank":
			rk += 1
	return 99


static func is_new_look(t: String) -> bool:
	var u := String(Defs.B[t].get("unlock", ""))
	return u in Defs.DECOR_SETS or u.begins_with("prem_")


static func regular_decor() -> Array:
	var out := []
	for t in Defs.B:
		var d: Dictionary = Defs.B[t]
		if d["kind"] == "decor" and not d.get("story", false) and not d.get("trophy", false):
			out.append(t)
	return out


func _census() -> void:
	var regs := regular_decor()
	var news := regs.filter(func(t): return is_new_look(t))
	var nb := {}
	for t in news:
		nb[Defs.base_of(t)] = true
	var allb := {}
	for t in regs:
		allb[Defs.base_of(t)] = true
	check(news.size() >= 60, "новых обликов украшений: %d (нужно ≥ 60)" % news.size())
	check(nb.size() >= 8, "новых видов украшений: %d (нужно ≥ 8), всего видов %d" % [nb.size(), allb.size()])
	for late: bool in [false, true]:
		var line := "S5 CENSUS %s:" % ("новая игра" if late else "живой город")
		var cum := 0
		for L in Defs.LEVELS.size():
			var n := regs.filter(func(t): return rank_of(Defs.unlock_of(t, late)) == L).size()
			cum += n
			line += " %s +%d=%d (%d%%);" % [Defs.LEVELS[L]["name"], n, cum, roundi(100.0 * cum / regs.size())]
		print(line)
	# на каждом уровне исследования открывают что-то, что можно поставить (новое украшение или здание этапа 5)
	var empty := []
	for L in Defs.LEVELS.size():
		var ok := false
		for r in Defs.RESEARCH:
			if int(r["lvl"]) != L or r.has("story"):
				continue
			for t in Defs.B:
				if Defs.unlock_of(t, true) == r["id"] and (String(Defs.B[t].get("unlock", "")) in Defs.DECOR_SETS or String(r["id"]).begins_with("prem_") or t in NEW_B):
					ok = true
		if not ok:
			empty.append(Defs.LEVELS[L]["name"])
	check(empty.is_empty(), "на каждом уровне (0–7) этап 5 открывает новое украшение или здание", empty)
	# у каждого набора — три-четыре вида (иначе бонус набора не собрать)
	var thin := []
	for s: String in Defs.DECOR_SETS:
		var kb := {}
		for t in regs:
			if Defs.set_of(t, true) == s:
				kb[Defs.base_of(t)] = true
		if kb.size() < Defs.SET_KINDS:
			thin.append("%s:%d" % [s, kb.size()])
	check(thin.is_empty(), "в каждом наборе ≥ %d видов" % Defs.SET_KINDS, thin)
	# каждый облик строится, у наземного есть след на земле; новые здания — с картинкой-значком и описанием
	var broken := []
	for t in news + NEW_B:
		var bp := Catalog.make(t, 0, 0, 0)
		if bp.parts.is_empty() or (not bool(Defs.B[t].get("wall", false)) and bp.footprint().is_empty()):
			broken.append(t)
	check(broken.is_empty(), "все новые облики и здания строятся и занимают землю", broken)
	var ui := []
	for t in NEW_B:
		var d: Dictionary = Defs.B[t]
		var r := Defs.research(String(d.get("unlock", "")))
		if r.is_empty() or String(d.get("desc", "")).length() < 30 or not d.has("icon"):
			ui.append(t)
	check(ui.is_empty(), "у новых зданий — исследование, описание и значок", ui)


# ---------- новая игра ----------

func _settle(b: Dictionary, tier := 1) -> void:
	var cls: String = c.def(b)["cls"]
	b["tier"] = clampi(tier, 1, Defs.floors_max(cls))
	b["pop"] = c.house_cap(b)
	var fams := []
	for f in int(b["tier"]):
		fams.append({"name": Defs.FAMILIES[f % Defs.FAMILIES.size()], "n": int(Defs.CLASSES[cls]["per_floor"])})
	b["families"] = fams


## Поставить постройку у точки (сдвигаясь, если занято), без денег и проверок уровня
func place(type: String, at: Vector2, step := Vector2(0, -0.5), tries := 16) -> Dictionary:
	for k in tries:
		var pl: Dictionary = game.placement(type, at + step * k)
		if pl["err"] == "":
			var b := c.place(type, pl["pos"], pl["yaw"], pl["variant"], pl["color"], true)
			if pl.has("host"):
				b["host"] = pl["host"]
				b["y"] = pl["y"]
				game._show(b)
			return b
	var last: Dictionary = game.placement(type, at)
	print("S5 NOTE не встало %s у %s: %s" % [type, str(at), last.get("err", "")])
	return {}


func _part(h: Dictionary, prefix: String) -> int:
	for e: Array in h.get("happy_parts", []):
		if String(e[0]).begins_with(prefix):
			return int(e[1])
	return 0


func _new() -> void:
	check(c.decor_v == 1 and c.econ == 1, "новая игра: украшения этапа 5 (decor_v 1) и экономика v2")
	await _census()
	# --- переезд прежних обликов (Q17): в новой игре кипарис — в «Южных деревьях», в живом городе — как раньше ---
	var keep: Dictionary = c.research.duplicate()
	c.research = {"deco_trees": true}
	check(not c.unlocked("cypress") and c.unlocked("tree") and c.unlocked("tree"), "новая игра: «Деревья и кусты» открывают дерево, но не кипарис")
	c.research["deco_south"] = true
	check(c.unlocked("cypress") and c.unlocked("bigtree"), "«Южные деревья» открывают кипарис и большие деревья")
	c.decor_v = 0
	c.research = {"deco_trees": true}
	check(c.unlocked("cypress") and not c.unlocked("bigtree"), "живой город: кипарис открыт, как раньше; новые деревья — своим исследованием")
	c.decor_v = 1
	c.research = keep
	for r in Defs.RESEARCH:
		c.research[r["id"]] = true
	c.level = 7
	c.money = 500000
	game.speed = 0.0
	# --- улица с домами ---
	var X0 := 150.0
	var Z0 := 196.0
	game.clear_nature(Vector2(X0 + 30.0, Z0), 46.0)
	land.paint_line(Vector2(X0 - 6.0, Z0), Vector2(X0 + 66.0, Z0), 1.6, Land.Kind.ROAD, true)
	land.paint_line(Vector2(X0 - 6.0, Z0 + 26.0), Vector2(X0 + 66.0, Z0 + 26.0), 1.6, Land.Kind.ROAD, true)
	await frames(6)
	var houses := []
	for k in 6:
		var hb := place("house_pleb" if k < 3 else ("house_artisan" if k < 5 else "house_patrician"), Vector2(X0 + k * 5.5, Z0 - 3.0))
		if not hb.is_empty():
			_settle(hb, 2)
			houses.append(hb)
	c.compute()
	check(houses.size() == 6, "шесть домов у дороги")
	var h0: Dictionary = houses[0]
	# --- 5.4 бонус набора: три разных вида «Сельского двора» рядом с домом ---
	var back: Vector2 = (h0["pos"] as Vector2) - City.facing(float(h0["yaw"])) * 6.0
	var s1 := place("veggies", back + Vector2(-2.0, -1.0), Vector2(-0.6, 0))
	var s2 := place("porch", back + Vector2(1.5, -1.5), Vector2(0.6, 0))
	c.compute()
	check(_part(h0, "Набор") == 0, "два вида набора — бонуса ещё нет")
	var s3 := place("woodpile", back + Vector2(0.0, -4.0), Vector2(0, -0.6))
	c.compute()
	check(not s1.is_empty() and not s2.is_empty() and not s3.is_empty() and _part(h0, "Набор «Сельский двор»") == Defs.SET_BONUS and int(h0.get("set_bonus", 0)) == Defs.SET_BONUS,
		"три разных вида «Сельского двора» рядом — +%d%% (строка в карточке дома)" % Defs.SET_BONUS, h0.get("happy_parts", []))
	var veg2 := place("veggies_2", back + Vector2(-3.5, -2.5), Vector2(-0.6, 0))
	c.compute()
	check(_part(h0, "Набор «Сельский двор»") == Defs.SET_BONUS, "второй облик того же вида бонус не удваивает")
	c.econ = 0
	c.compute()
	check(_part(h0, "Набор") == 0, "живой город (econ 0): бонуса наборов нет — счастье как было")
	c.econ = 1
	for b2: Dictionary in [s1, s2, s3, veg2]:
		if not b2.is_empty():
			c.remove(b2, false)
	# --- 5.3 «главное» украшение: как памятник, сверх предела украшений ---
	var cap := int(Defs.CLASSES["plebs"]["deco_max"])
	var fill_n := 0
	for k in 14:
		var t: String = ["statue", "lion", "column", "pergola", "sundial", "bigvase", "altar", "ruins", "colossus", "eagle", "bigtorch", "torchpost", "incense", "lanterns"][k]
		if not place(t, back + Vector2(-8.0 + (k % 7) * 2.6, -1.0 - (k / 7) * 3.2), Vector2(0, -0.6), 6).is_empty():
			fill_n += 1
	c.compute()
	var deco0 := _part(h0, "Украшения")
	var mon0 := _part(h0, "Экседра")
	var ex := place("exedra", (h0["pos"] as Vector2) + City.facing(float(h0["yaw"])) * 9.0 + Vector2(0, 2.0), Vector2(0, 0.6), 12)
	c.compute()
	check(deco0 == cap and mon0 == 0 and not ex.is_empty() and _part(h0, "Экседра") == int(Defs.B["exedra"]["mon"]),
		"экседра у дома с полными украшениями (+%d из %d): +%d%% сверх предела" % [deco0, cap, _part(h0, "Экседра")], [fill_n, h0.get("happy_parts", [])])
	# --- 5.5 новые здания: лавки торгуют и радуют, памятники радуют округу, работники заняты ---
	# к югу от первой улицы — шесть зданий фасадом к ней; к северу от второй — дом префекта и нимфей
	var at := {"ogorod": Vector2(X0 + 2.0, Z0 + 1.8), "shelter": Vector2(X0 + 10.0, Z0 + 1.8), "puppets": Vector2(X0 + 18.0, Z0 + 1.8),
		"herbalist": Vector2(X0 + 25.0, Z0 + 1.8), "vigiles": Vector2(X0 + 33.0, Z0 + 1.8), "sculptor": Vector2(X0 + 43.0, Z0 + 1.8),
		"prefect": Vector2(X0 + 53.0, Z0 + 21.0), "nymphaeum": Vector2(X0 + 40.0, Z0 + 21.0)}
	var built := {}
	for t: String in NEW_B:
		var south: bool = at[t].y < Z0 + 10.0
		var bb := place(t, at[t], Vector2(0.0, 0.4) if south else Vector2(0.5, 0.0), 24)
		if not bb.is_empty():
			built[t] = bb
	# жители: ещё дома, чтобы всем хватило работников
	for k in 6:
		var hb := place(["house_pleb", "house_artisan", "house_patrician"][k % 3], Vector2(X0 + 2.0 + k * 6.0, Z0 + 29.0), Vector2(0.5, 0), 12)
		if not hb.is_empty():
			_settle(hb, 3)
			houses.append(hb)
	c.compute()
	check(built.size() == NEW_B.size(), "все восемь новых зданий встали у дороги", built.keys())
	var dead := []
	for t: String in built:
		var bb: Dictionary = built[t]
		var d: Dictionary = Defs.B[t]
		if d["kind"] == "shop":
			var fed := houses.filter(func(h): return (h.get("score", {}) as Dictionary).has(t))
			if not bb["active"] or int(bb.get("served", 0)) == 0 or fed.is_empty():
				dead.append("%s active=%s served=%d why=%s" % [t, bb["active"], int(bb.get("served", 0)), bb.get("why", "")])
		else:
			var near := houses.filter(func(h): return (h.get("mon_types", {}) as Dictionary).has(t))
			if not bb["active"] or near.is_empty():
				dead.append("%s active=%s near=%d" % [t, bb["active"], near.size()])
	check(dead.is_empty(), "новые лавки торгуют и радуют дома, новые памятники радуют округу", dead)
	var jobs_ok := true
	for t: String in built:
		if Defs.B[t].has("jobs") and float(built[t].get("staff", 0.0)) < 0.99:
			jobs_ok = false
	check(jobs_ok, "работники во всех новых зданиях на месте")
	# животные: корова, лошадь, кошки и ослик в приюте
	var cow := place("cow", Vector2(X0 + 60.0, Z0 + 8.0), Vector2(0, 0.6), 12)
	var horse := place("horse_2", Vector2(X0 + 60.0, Z0 + 14.0), Vector2(0, 0.6), 12)
	await frames(3)
	var pc := (game.visuals.get(cow.get("id", -1), {}).get("pets", []) as Array).size()
	var ph := (game.visuals.get(horse.get("id", -1), {}).get("pets", []) as Array).size()
	var ps := (game.visuals.get(built.get("shelter", {}).get("id", -1), {}).get("pets", []) as Array).size()
	check(pc == 1 and ph == 1 and ps == 3, "живые животные: корова %d, лошадь %d, в приюте %d (2 кошки и ослик)" % [pc, ph, ps])
	# сохранение — decor_v сохраняется
	var sd := c.save_data()
	check(int(sd.get("decor_v", -1)) == 1, "сохранение новой игры помнит decor_v = 1")
	# --- снимки зданий ---
	game.hud.visible = false
	game.rig.cine = true
	game._set_hour(10.5)
	await _block_cost()
	if shots:
		for t: String in built:
			var bb: Dictionary = built[t]
			var p := Vector3(bb["pos"].x, land.height_at(bb["pos"].x, bb["pos"].y), bb["pos"].y)
			var f := City.facing(float(bb["yaw"]))
			var r := 10.0 if t in ["nymphaeum", "prefect", "sculptor"] else 8.0
			game.rig.cine_look(p + Vector3(f.x * r + f.y * 3.0, r * 0.62, f.y * r - f.x * 3.0), p + Vector3(0, 1.0, 0))
			await frames(25)
			await shot("s5_b_%s.png" % t)
		game.rig.cine_look(Vector3(X0 + 24.0, 19.0, Z0 - 20.0), Vector3(X0 + 24.0, 0.0, Z0 + 5.0))
		await frames(25)
		await shot("s5_b_street.png")
		await _sets_shots()
	game.rig.cine = false
	game.hud.visible = true
	await _tray()


func _rinfo() -> Vector2i:
	var vp := get_viewport().get_viewport_rid()
	var RS := RenderingServer
	return Vector2i(RS.viewport_get_render_info(vp, RS.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RS.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		RS.viewport_get_render_info(vp, RS.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RS.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))


## Бюджет волны (план 5, приёмка): блок из 20 новых украшений (20 разных видов) в кадре — сколько вызовов отрисовки
## прибавилось (видимые и тени)
func _block_cost() -> void:
	var ctr := Vector2(222.0, 236.0)
	game.clear_nature(ctr, 16.0)
	game.rig.cine_look(Vector3(ctr.x, 16.0, ctr.y + 18.0), Vector3(ctr.x, 0.0, ctr.y))
	await frames(40)
	var a := _rinfo()
	# для сравнения — 20 прежних видов (что стоят 20 разных видов украшений вообще)
	var old := []
	for t in regular_decor():
		if not is_new_look(t) and Defs.base_of(t) == t and not bool(Defs.B[t].get("wall", false)) and not bool(Defs.B[t].get("water", false)) and not bool(Defs.B[t].get("seg", false)) and old.size() < 20:
			old.append(t)
	var po := 0
	for k in old.size():
		if not place(old[k], ctr + Vector2(-7.5 + (k % 5) * 3.75, -5.0 + (k / 5) * 3.4), Vector2(0.4, 0), 6).is_empty():
			po += 1
	c.compute()
	await frames(40)
	var o2 := _rinfo()
	print("S5 PERF для сравнения: блок %d прежних видов — +%d видимых, +%d в тенях" % [po, o2.x - a.x, o2.y - a.y])
	for b2 in c.buildings.values().duplicate():
		if (b2["pos"] as Vector2).distance_to(ctr) < 14.0:
			c.remove(b2, false)
	await get_tree().create_timer(2.5).timeout
	await frames(20)
	a = _rinfo()
	var bases := []
	for t in regular_decor():
		if is_new_look(t) and Defs.base_of(t) == t and not bool(Defs.B[t].get("wall", false)) and bases.size() < 20:
			bases.append(t)
	var placed := 0
	for k in bases.size():
		if not place(bases[k], ctr + Vector2(-7.5 + (k % 5) * 3.75, -5.0 + (k / 5) * 3.4), Vector2(0.4, 0), 6).is_empty():
			placed += 1
	c.compute()
	await frames(40)
	var bb := _rinfo()
	var dv := bb.x - a.x
	var ds := bb.y - a.y
	print("S5 PERF блок %d новых украшений: вызовов отрисовки +%d видимых, +%d в тенях (было %d/%d, стало %d/%d)" % [placed, dv, ds, a.x, a.y, bb.x, bb.y])
	check(placed >= 18 and dv <= 80, "бюджет волны: 20 новых украшений в кадре — ≤ +80 видимых вызовов отрисовки (+%d, тени +%d)" % [dv, ds])
	for b2 in c.buildings.values().duplicate():
		if (b2["pos"] as Vector2).distance_to(ctr) < 14.0:
			c.remove(b2, false)


## Наборы — каждый своим рядом у дороги, снимок крупно; настенные — на домах
func _sets_shots() -> void:
	var groups: Array = []
	for s: String in Defs.DECOR_SETS:
		groups.append([s, regular_decor().filter(func(t): return Defs.set_of(t, true) == s and not bool(Defs.B[t].get("wall", false)))])
	groups.append(["premium", regular_decor().filter(func(t): return String(Defs.B[t].get("unlock", "")).begins_with("prem_"))])
	for g: Array in groups:
		var list: Array = g[1]
		if list.is_empty():
			continue
		var big: bool = g[0] in ["premium", "deco_gods", "deco_garden", "deco_farmyard", "deco_water"]
		var step := 4.2 if big else 3.0
		var cols := mini(list.size(), 4 if big else 5)
		var rows := int(ceil(list.size() / float(cols)))
		var ctr := Vector2(166.0, 140.0)
		# своя площадка: убрать прежний набор, дать осесть пыли, поставить сеткой
		for b2 in c.buildings.values().duplicate():
			if b2["type"] != "center" and (b2["pos"] as Vector2).distance_to(ctr) < 34.0:
				c.remove(b2, false)
		game.clear_nature(ctr, 30.0)
		await get_tree().create_timer(2.5).timeout
		for k in list.size():
			var col := k % cols
			var rw := k / cols
			var p := ctr + Vector2((col - (cols - 1) / 2.0) * step, (rw - (rows - 1) / 2.0) * (step + 0.5))
			place(list[k], p, Vector2(0.4, 0.0), 6)
		c.compute()
		await frames(6)
		var span := maxf(cols * step, rows * (step + 0.5))
		var dist := span * 0.8 + 3.0
		var gy := land.height_at(ctr.x, ctr.y)
		game.rig.cine_look(Vector3(ctr.x, gy + dist * 0.6, ctr.y + dist * 0.8), Vector3(ctr.x, gy + 0.5, ctr.y + 0.3))
		await frames(40)
		await shot("s5_set_%s.png" % g[0])
	# настенные «Фрески и мозаики»: на фасады домов
	for b2 in c.buildings.values().duplicate():
		if b2["type"] != "center" and (b2["pos"] as Vector2).distance_to(Vector2(166.0, 140.0)) < 34.0:
			c.remove(b2, false)
	var wl := regular_decor().filter(func(t): return Defs.set_of(t, true) == "deco_mosaic")
	land.paint_line(Vector2(140.0, 146.0), Vector2(194.0, 146.0), 1.6, Land.Kind.ROAD, true)
	await frames(4)
	var hs := []
	for k in 6:
		var hb := place("house_artisan" if k % 2 == 0 else "house_patrician", Vector2(145.0 + k * 8.0, 141.0), Vector2(0.5, 0), 10)
		if not hb.is_empty():
			_settle(hb, 2)
			hs.append(hb)
	var wi := 0
	for hb: Dictionary in hs:
		var bp := c.blueprint(hb)
		for side: float in [-1.0, 1.0]:
			if wi >= wl.size():
				break
			var p: Vector2 = (hb["pos"] as Vector2) + City.facing(hb["yaw"]) * (bp.front_z() + 0.3) + City.axis(hb["yaw"]) * side * 1.1
			var pl: Dictionary = game._wall_place(wl[wi], p, 1.5)
			if pl["err"] == "":
				var w2 := c.place(wl[wi], pl["pos"], pl["yaw"], 0, int(pl["color"]), true)
				w2["host"] = pl["host"]
				w2["y"] = pl["y"]
				game._show(w2)
			wi += 1
	c.compute()
	game.rig.cine_look(Vector3(168.0, 9.0, 160.0), Vector3(168.0, 2.2, 141.0))
	await frames(30)
	await shot("s5_set_deco_mosaic.png")
	game._set_hour(21.5)
	game.rig.cine_look(Vector3(168.0, 9.0, 160.0), Vector3(168.0, 2.2, 141.0))
	await frames(40)
	await shot("s5_night_street.png")
	game._set_hour(10.5)


## Меню украшений: новые вкладки, ★, недавние, поиск, «только открытые», силуэты закрытых; окно 1024 px
func _tray() -> void:
	var hud = game.hud
	game.speed = 0.0
	# часть открыта, часть — на уровнях впереди (силуэты)
	c.level = 2
	c.research = {}
	for r in Defs.RESEARCH:
		if int(r["lvl"]) <= 2:
			c.research[r["id"]] = true
	get_window().size = Vector2i(1024, 700)
	await frames(10)
	hud.select_build("veggies")
	game.set_tool("")
	await frames(8)
	check(hud.tray.visible and hud.open_cat == "decor" and hud.tray_dtools.visible and hud.tray_dtabs.get_child_count() == Defs.DECOR_SUBS.size(),
		"меню украшений: %d вкладок и ряд «★ Избранное · Недавние · поиск»" % Defs.DECOR_SUBS.size())
	var vw: float = hud.root.size.x
	var tr: Rect2 = hud.tray.get_global_rect()
	check(tr.position.x >= 0.0 and tr.end.x <= vw + 1.0, "свиток украшений помещается в окно 1024 px (%d…%d из %d)" % [int(tr.position.x), int(tr.end.x), int(vw)])
	await shot("s5_tray_1024.png")
	# силуэт у украшения уровня впереди
	hud.open_dsub = "stone"
	hud.decor_mode = ""
	hud._fill_cards()
	await frames(4)
	var sil := 0
	for b in hud.tray_grid.get_children():
		if b.has_meta("type") and not c.unlocked(b.get_meta("type")):
			var img := b.find_child("img", true, false) as TextureRect
			if img and img.modulate.r < 0.3:
				sil += 1
	check(sil > 0, "закрытые украшения уровней впереди — тёмным силуэтом (%d)" % sil)
	await shot("s5_tray_locked.png")
	# поиск
	hud.decor_search.text = "пруд"
	hud.decor_search.text_changed.emit("пруд")
	await frames(4)
	var found := []
	for b in hud.tray_grid.get_children():
		if b.has_meta("type"):
			found.append(b.get_meta("type"))
	check(found.has("pond") and found.has("pond_2") and found.size() <= 6, "поиск «пруд» — пруды", found)
	await shot("s5_tray_search.png")
	hud.decor_search.text = ""
	hud.decor_search.text_changed.emit("")
	# избранное и недавние
	hud.toggle_fav("trough")
	hud.toggle_fav("pond_3")
	hud._decor_mode("fav")
	await frames(4)
	var favs := []
	for b in hud.tray_grid.get_children():
		if b.has_meta("type"):
			favs.append(b.get_meta("type"))
	check(favs == ["pond_3", "trough"] or favs == ["trough", "pond_3"], "★ Избранное: отмеченные карточки", favs)
	await shot("s5_tray_fav.png")
	hud.note_recent("bench")
	hud.note_recent("veggies")
	hud.note_recent("bench")
	hud._decor_mode("recent")
	await frames(4)
	var rec := []
	for b in hud.tray_grid.get_children():
		if b.has_meta("type"):
			rec.append(b.get_meta("type"))
	check(rec.size() >= 2 and rec[0] == "bench" and rec[1] == "veggies", "Недавние: последнее — первым, без повторов", rec)
	# только открытые
	hud._decor_mode("recent")
	hud.decor_open_only = true
	hud.open_dsub = "stone"
	hud._fill_cards()
	await frames(3)
	var all_open := true
	for b in hud.tray_grid.get_children():
		if b.has_meta("type") and not c.unlocked(b.get_meta("type")):
			all_open = false
	check(all_open, "«Только открытые» прячет закрытые карточки")
	hud.decor_open_only = false
	hud.toggle_fav("trough")
	hud.toggle_fav("pond_3")
	# исследования: в подсказке набора — его украшения и бонус
	hud._toggle(hud.research_panel)
	hud._fill_research()
	await frames(6)
	var tip := ""
	for b in hud.research_box.find_children("*", "Button", true, false):
		if b.has_meta("rid") and b.get_meta("rid") == "deco_water":
			tip = b.tooltip_text
	check(tip.contains("Открывает украшения:") and tip.contains("Пруд с кувшинками") and tip.contains("Набор:"), "подсказка исследования набора: его украшения и бонус", tip)
	await shot("s5_research_1024.png")
	hud.close_panels()
	get_window().size = Vector2i(1600, 900)
	await frames(4)


# ---------- город владельца ----------

func _owner() -> void:
	check(c.decor_v == 0, "старое сохранение: decor_v 0 — прежние облики открыты, как были")
	var bad := []
	for t: String in Defs.DECOR_LATER:
		var u := String(Defs.B[t].get("unlock", ""))
		var was := u == "" or c.research.has(u)
		if c.unlocked(t) != was:
			bad.append(t)
	check(bad.is_empty(), "все переехавшие облики открыты в живом городе так же, как до обновления", bad)
	var lost := []
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		if Defs.B.has(b["type"]) and String(Defs.B[b["type"]].get("unlock", "")) != "" and not c.unlocked(b["type"]) and not String(Defs.B[b["type"]].get("unlock", "")).begins_with("boss") and not String(Defs.B[b["type"]].get("unlock", "")).begins_with("trophy"):
			lost.append(b["type"])
	check(lost.is_empty(), "ни одна стоящая постройка города не стала закрытой", lost)
	var open_new := []
	for r in Defs.RESEARCH:
		var id: String = r["id"]
		if (id in Defs.DECOR_SETS or id.begins_with("prem_") or id in NEW_B) and int(r["lvl"]) <= c.level:
			if c.research_open(id):
				open_new.append(id)
	check(open_new.size() >= 10, "в свитке города владельца — новые исследования этапа 5 (%d)" % open_new.size(), open_new)
	c.compute()
	var sets_rows := 0
	for id in c.buildings:
		var h: Dictionary = c.buildings[id]
		if c.is_house(h) and _part(h, "Набор") != 0:
			sets_rows += 1
	check(c.econ == 0 and sets_rows == 0, "живой город: бонус наборов не включён (счастье как было)")
	var sd := c.save_data()
	check(int(sd.get("decor_v", -1)) == 0, "сохранение живого города помнит decor_v = 0")
	game.hud.select_build("statue")
	game.set_tool("")
	await frames(10)
	await shot("s5_owner_tray.png")
	game.hud.close_panels()
