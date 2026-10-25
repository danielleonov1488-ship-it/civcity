extends Node
## Этап 5, волна 2 (docs/PLAN_2026-10-24_tech.md 5.5–5.8): лудус и большие постройки веб-версии, улучшение дорог,
## кисти «Земля».
##   bash .work/py/gpu_run.sh res://test_stage5b.tscn              — новая игра; в конце «S5B DONE fails=0»; снимки — .work/gd/a/s5b_*.png
##   … -- mode=owner                                               — копия города владельца: узора нет, всё как было
##   … -- shots=0                                                  — без снимков (быстрее)
## 5.5–5.6: шесть новых зданий (лудус, акведук, храм Венеры и Ромы, большие термы, маяк, цирк) — у каждого исследование,
##          описание, значок, работа в городе; вместе с волной 1 — не меньше 12 и на каждом уровне 1–7; акведук кусками
##          (кусок у конца встаёт следом, под арками свободная земля), маяк — только у воды, Слава каждый день,
##          на «Низкой» — лёгкие колонны
## 5.7: «Улучшить»: тропа → мостовая, мостовая → плиты, площадь → травертин; цена, отмена, «ухоженная улица» +2%
## 5.8: «Земля»: узор на траве, ластик и «Трава» стирают, прямая линия, сохранение

const OWNER := "D:/CivCity/.work/owner_save/city.json"
const SHOTS := "D:/CivCity/.work/gd/a/"
const W1 := ["ogorod", "shelter", "puppets", "herbalist", "vigiles", "sculptor", "prefect", "nymphaeum"]
const W2 := ["ludus", "aqua", "venus", "thermae", "pharos", "circus_fl"]
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
	print(("S5B PASS " if ok else "S5B FAIL ") + what + ("" if ok or extra == null else "  " + str(extra)))
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
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	if mode == "owner":
		await _owner()
	else:
		await _new()
	print("S5B DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


# ---------- данные ----------

func _census() -> void:
	var ranks := {}
	var bad := []
	for t: String in W1 + W2:
		var d: Dictionary = Defs.B[t]
		var r := Defs.research(String(d.get("unlock", "")))
		if r.is_empty() or r.has("story") or String(d.get("desc", "")).length() < 30 or not d.has("icon"):
			bad.append(t)
			continue
		ranks[int(r["lvl"])] = int(ranks.get(int(r["lvl"]), 0)) + 1
	check(bad.is_empty(), "у новых зданий — исследование, описание и значок", bad)
	var miss := []
	for L in range(1, 8):
		if not ranks.has(L):
			miss.append(Defs.LEVELS[L]["name"])
	check((W1 + W2).size() >= 12 and miss.is_empty(), "новых зданий %d (нужно ≥ 12), на каждом уровне 1–7 — хотя бы одно; по уровням %s" % [(W1 + W2).size(), str(ranks)], miss)
	# дороже полок своего уровня быть не может (иначе не изучить)
	var dear := []
	for t: String in W2 + [Defs.ROAD_UP_RES]:
		var r := Defs.research(String(Defs.B[t].get("unlock", "")) if Defs.B.has(t) else t)
		var cap := float(Defs.LEVELS[int(r["lvl"])]["rp"]) * (2.0 if int(r["lvl"]) >= 4 else 1.0)
		if float(r["cost"]) > cap:
			dear.append("%s %d > %d" % [r["id"], int(r["cost"]), int(cap)])
	check(dear.is_empty(), "новые исследования помещаются на полки своего уровня", dear)
	# каждое строится и занимает землю; у акведука землю занимают только опоры
	var broken := []
	for t: String in W2:
		var bp := Catalog.make(t, 0, 0, 0)
		if bp.parts.is_empty() or bp.footprint().is_empty():
			broken.append(t)
	check(broken.is_empty(), "все новые здания строятся и занимают землю", broken)
	var tri := {}
	for t: String in W2:
		var n := 0
		var by := {}
		for pr: Array in Catalog.make(t, 0, 0, 0).parts:
			var tn := _tris(String(pr[0]))
			n += tn
			by[String(pr[0])] = int(by.get(String(pr[0]), 0)) + tn
		tri[t] = n
		var keys := by.keys()
		keys.sort_custom(func(x, y): return int(by[x]) > int(by[y]))
		print("S5B TRIS %s %d: %s" % [t, n, ", ".join(keys.slice(0, 8).map(func(k): return "%s %d" % [k, by[k]]))])
	print("S5B TRIS треугольников в облике (без упрощения вдали): %s" % str(tri))
	var aq := Catalog.make("aqua", 0, 0, 0)
	var rects: Array = aq.footprint()
	var wide := rects.filter(func(r: Rect2): return r.size.x > CatGrand.AQ_PIER * Catalog.ARCH + 0.05)
	check(rects.size() == 3 and wide.is_empty(), "акведук: землю занимают только три опоры (под арками свободно)", rects)


# ---------- новая игра ----------

func _settle(b: Dictionary, tier := 1) -> void:
	var cls: String = c.def(b)["cls"]
	b["tier"] = clampi(tier, 1, Defs.floors_max(cls))
	b["pop"] = c.house_cap(b)
	var fams := []
	for f in int(b["tier"]):
		fams.append({"name": Defs.FAMILIES[f % Defs.FAMILIES.size()], "n": int(Defs.CLASSES[cls]["per_floor"])})
	b["families"] = fams
	# жители этих семей — на улицах и на работе (гладиаторы в лудусе, служители терм)
	for fm: Dictionary in fams:
		game.people._make_family(fm["name"], int(fm["n"]), int(b["id"]), c.door_point(b), "", fm)
	game.people._jobs_dirty = true


## Поставить постройку у точки (сдвигаясь, если занято), без денег и проверок уровня
func place(type: String, at: Vector2, step := Vector2(0, -0.5), tries := 16) -> Dictionary:
	var last := ""
	for k in tries:
		var pl: Dictionary = game.placement(type, at + step * k)
		if pl["err"] == "":
			return c.place(type, pl["pos"], pl["yaw"], pl["variant"], pl["color"], true)
		last = pl["err"]
	print("S5B NOTE не встало %s у %s: %s" % [type, str(at), last])
	return {}


## Мазок кистью игрока по точкам (как мышью): нажатие, ведение, отпускание
func stroke(tool: String, pts: Array, line := false) -> void:
	game.set_tool(tool)
	game.brush_line = line
	game.hover = pts[0]
	game._click()
	for p: Vector2 in pts.slice(1):
		game.hover = p
		if line:
			game._line_update(true)
		else:
			game._paint_to(p)
	game._release()
	await frames(2)


func _count(pred: Callable, cells: Array) -> int:
	var n := 0
	for k: int in cells:
		if pred.call(k):
			n += 1
	return n


func _new() -> void:
	await _census()
	for r in Defs.RESEARCH:
		c.research[r["id"]] = true
	c.level = 7
	c.money = 900000
	c.legion.glory = 1000.0
	game.speed = 0.0
	await _perf()
	var X0 := 140.0
	var Z0 := 120.0
	game.clear_nature(Vector2(X0 + 40.0, Z0 + 20.0), 70.0)
	land.paint_line(Vector2(X0 - 6.0, Z0), Vector2(X0 + 96.0, Z0), 1.6, Land.Kind.ROAD, true)
	land.paint_line(Vector2(X0 - 6.0, Z0 + 40.0), Vector2(X0 + 96.0, Z0 + 40.0), 1.6, Land.Kind.ROAD, true)
	await frames(6)
	var houses := []
	for k in 10:
		var hb := place(["house_pleb", "house_artisan", "house_patrician"][k % 3], Vector2(X0 + 2.0 + k * 6.0, Z0 + 37.0), Vector2(0.5, 0), 12)
		if not hb.is_empty():
			_settle(hb, 3)
			houses.append(hb)
	# --- 5.5–5.6: здания у дороги (к северу от первой улицы — фасадом к ней) ---
	var at := {"ludus": Vector2(X0 + 4.0, Z0 + 2.6), "thermae": Vector2(X0 + 22.0, Z0 + 2.6), "venus": Vector2(X0 + 41.0, Z0 + 2.6),
		"circus_fl": Vector2(X0 + 76.0, Z0 + 2.6)}
	var built := {}
	for t: String in at:
		var bb := place(t, at[t], Vector2(0.5, 0.0), 30)
		if not bb.is_empty():
			built[t] = bb
	# маяк — у пруда (215, 150): вдали от воды не встаёт
	var far: Dictionary = game.placement("pharos", Vector2(X0 + 30.0, Z0 + 25.0))
	check(String(far["err"]).contains("воды"), "маяк вдали от воды не встаёт: «%s»" % far["err"])
	var pc := Vector2(215.0, 150.0)
	game.clear_nature(pc + Vector2(14.0, 0.0), 10.0)
	var ph := {}
	var perr := ""
	for k in 12:
		# улица — всё ближе к пруду, маяк — вплотную к ней фасадом (сзади — вода)
		var rx := pc.x + 19.0 - k * 0.5
		var ch := land.paint_line(Vector2(rx, pc.y - 9.0), Vector2(rx, pc.y + 9.0), 1.4, Land.Kind.ROAD, true)
		var pl: Dictionary = game.placement("pharos", Vector2(rx - 2.4, pc.y))
		if pl["err"] == "":
			ph = c.place("pharos", pl["pos"], pl["yaw"], pl["variant"], pl["color"], true)
			break
		perr = pl["err"]
		land.undo(ch)
	if check(not ph.is_empty(), "маяк встал у пруда", perr):
		built["pharos"] = ph
	# акведук: первый кусок поперёк дороги (между первой и второй улицей), второй — следом, по снимку курсора у конца
	land.paint_line(Vector2(X0 + 58.0, Z0 + 12.0), Vector2(X0 + 58.0, Z0 + 32.0), 1.0, Land.Kind.ROAD, true)
	await frames(3)
	game.tool_yaw = 0.0
	game.manual_yaw = true
	var a1 := {}
	for k in 12:
		var pl1: Dictionary = game.placement("aqua", Vector2(X0 + 58.0 + 0.5 * CatGrand.AQ_HALF * Catalog.ARCH, Z0 + 22.0 + k * 0.3))
		if pl1["err"] == "":
			a1 = c.place("aqua", pl1["pos"], pl1["yaw"], 0, 0, true)
			break
	var a2 := {}
	if check(not a1.is_empty(), "кусок акведука встал над улицей (дорога у входа не нужна)"):
		var ax := City.axis(float(a1["yaw"]))
		var end: Vector2 = (a1["pos"] as Vector2) + ax * CatGrand.AQ_HALF * Catalog.ARCH
		var pl2: Dictionary = game.placement("aqua", end + ax * 0.8 + Vector2(0.4, 0.3))
		var want: Vector2 = (a1["pos"] as Vector2) + ax * 2.0 * CatGrand.AQ_HALF * Catalog.ARCH
		check(pl2["err"] == "" and (pl2["pos"] as Vector2).distance_to(want) < 0.01 and is_equal_approx(float(pl2["yaw"]), float(a1["yaw"])),
			"второй кусок у конца первого встаёт вплотную следом, по той же линии", [pl2["err"], pl2["pos"], want])
		if pl2["err"] == "":
			a2 = c.place("aqua", pl2["pos"], pl2["yaw"], 0, 0, true)
			built["aqua"] = a1
		# под арками — свободная мостовая: жители проходят
		var free_road := 0
		var under := 0
		for k in land.footprint_cells([Rect2(-CatGrand.AQ_HALF * Catalog.ARCH, -0.3, 2.0 * CatGrand.AQ_HALF * Catalog.ARCH, 0.6)], a1["pos"], float(a1["yaw"])):
			if Land.walk_kind(land.kind[k]):
				under += 1
				if land.occ[k] == 0:
					free_road += 1
		check(under > 0 and free_road * 10 >= under * 7, "под арками акведука улица свободна: %d из %d клеток мостовой" % [free_road, under])
		# арки землю не занимают, но постройка сквозь них не встаёт: скамья в пролёте, акведук поперёк (правка по проверке)
		var sp: Vector2 = (a1["pos"] as Vector2) + ax * 0.5 * CatGrand.AQ_HALF * Catalog.ARCH
		var nrm := Vector2(-ax.y, ax.x)
		var bch: Dictionary = c.check_place("bench", sp, float(a1["yaw"]))
		check(String(bch["err"]).contains("арки"), "скамья под аркой акведука не встаёт: «%s»" % bch["err"])
		var cross: Dictionary = c.check_place("aqua", sp + nrm * 0.5 * CatGrand.AQ_HALF * Catalog.ARCH, float(a1["yaw"]) + PI / 2)
		check(String(cross["err"]) == "Место занято", "акведук поперёк, сквозь арки другого, не встаёт: «%s»" % cross["err"])
		var spk := land.idx(land.cell(sp).x, land.cell(sp).y)
		land.paint_line(sp - nrm * 1.5, sp + nrm * 1.5, 0.6, Land.Kind.ROAD, true)
		check(land.kind[spk] == Land.Kind.ROAD and land.occ[spk] == 0 and land.under.has(spk),
			"улицу под аркой можно провести и после постройки (клетка под аркой — мостовая, свободна)")
	for k in 8:
		var hb := place(["house_pleb", "house_artisan"][k % 2], Vector2(X0 + 50.0 + k * 6.0, Z0 + 37.0), Vector2(0.5, 0), 12)
		if not hb.is_empty():
			_settle(hb, 3)
			houses.append(hb)
	c.compute()
	check(built.size() == W2.size(), "все шесть новых зданий встали", built.keys())
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
			if not bb["active"] or (near.is_empty() and t != "pharos"):
				dead.append("%s active=%s near=%d" % [t, bb["active"], near.size()])
	check(dead.is_empty(), "новые лавки торгуют, новые памятники радуют округу", dead)
	var jobs_ok := []
	for t: String in built:
		if Defs.B[t].has("jobs") and float(built[t].get("staff", 0.0)) < 0.99:
			jobs_ok.append(t)
	check(jobs_ok.is_empty(), "работники во всех новых зданиях на месте", jobs_ok)
	var uq: Dictionary = game.placement("ludus", Vector2(X0 + 80.0, Z0 + 3.0))
	check(String(uq["err"]).contains("уже есть"), "лудус — один на город: «%s»" % uq["err"])
	# Слава каждый день: лудус, маяк и цирк — по 0,5 в день
	var want := 0.0
	for t: String in ["ludus", "pharos", "circus_fl"]:
		if bool(built.get(t, {}).get("active", false)):
			want += float(Defs.B[t]["glory_day"])
	var g0: float = c.legion.glory + c.legion.glory_acc
	for h in 24:
		c.sim_day()
	var g1: float = c.legion.glory + c.legion.glory_acc
	check(is_equal_approx(want, 1.5) and absf((g1 - g0) - want) < 0.05, "Слава от лудуса, маяка и цирка: +%.2f за день (ждём %.1f из 1,5)" % [g1 - g0, want])
	# --- «Низкая»: у храма Венеры коринфские колонны — гладкие (облик заново при смене уровня) ---
	var q0: String = game.settings.get("quality", "high")
	var corin0 := _used("SM_Bld_Pillar_Large_04")
	game.settings["quality"] = "low"
	Gfx.apply(game)
	await frames(2)
	var corin1 := _used("SM_Bld_Pillar_Large_04")
	game.settings["quality"] = q0
	Gfx.apply(game)
	await frames(2)
	var corin2 := _used("SM_Bld_Pillar_Large_04")
	check(built.has("venus") and corin1 == corin0 - 8 and corin2 == corin0, "«Низкая»: у храма Венеры 8 коринфских колонн подменяются лёгкими и возвращаются (%d → %d → %d)" % [corin0, corin1, corin2])
	# --- 5.7: «Улучшить» ---
	await _upgrade(X0, Z0, houses)
	await _street_cache(X0, Z0)
	# --- 5.8: «Земля» ---
	await _ground(X0, Z0)
	await _brush_line_perf(X0, Z0)
	_deco_save_perf()
	# --- сохранение и загрузка узора ---
	var sd: Dictionary = game._save_data()
	var ld: Dictionary = sd["land"]
	var l2 := Land.new()
	l2.load_changes(ld)
	check(ld.has("deco") and l2.deco_cells.size() == land.deco_cells.size() and l2.up_n == land.up_n and l2.ground_n == land.ground_n,
		"узор земли и плиты сохраняются и загружаются (%d клеток, плит %d, узора %d)" % [l2.deco_cells.size(), l2.up_n, l2.ground_n])
	if shots:
		await _shots(built, X0, Z0)
	await _arch_nature(built)


func _used(prefix: String) -> int:
	var n := 0
	for k: String in game.parts.groups:
		if k.begins_with(prefix + "|"):
			var g: Dictionary = game.parts.groups[k]
			n += int(g["used"]) - (g["free"] as Array).size()
	return n


## «Улучшить» (5.7): тропа → мостовая, мостовая → плиты, площадь → травертин; цена; отмена; «ухоженная улица» у дома
func _upgrade(X0: float, Z0: float, houses: Array) -> void:
	var y := Z0 + 60.0
	game.brush_square = true
	game.brush_r = 0.9
	game.clear_nature(Vector2(X0 + 20.0, y), 26.0)
	land.paint_line(Vector2(X0, y), Vector2(X0 + 12.0, y), 1.0, Land.Kind.DIRT, true)
	land.paint_line(Vector2(X0 + 14.0, y), Vector2(X0 + 26.0, y), 1.0, Land.Kind.ROAD, true)
	land.paint_line(Vector2(X0 + 28.0, y), Vector2(X0 + 40.0, y), 1.0, Land.Kind.PLAZA, true)
	await frames(3)
	var cells := land.brush_cells(Vector2(X0 + 6.0, y), 0.9, true, -1, {})
	var path_n := _count(func(k): return land.kind[k] == Land.Kind.DIRT, cells)
	var m0 := c.money
	await stroke("upgrade", [Vector2(X0 + 6.0, y)])
	var now_road := _count(func(k): return land.kind[k] == Land.Kind.ROAD, cells)
	check(path_n > 0 and now_road == path_n and absf((m0 - c.money) - path_n * float(Defs.ROAD_UP["path"])) < 0.01,
		"«Улучшить» по тропе: тропа стала мостовой (%d клеток), цена — %s за клетку" % [now_road, Defs.ROAD_UP["path"]], [path_n, m0 - c.money])
	# по мостовой — плиты, по площади — травертин (своя цена)
	m0 = c.money
	await stroke("upgrade", [Vector2(X0 + 15.0, y), Vector2(X0 + 25.0, y)])
	var rc := land.brush_cells(Vector2(X0 + 20.0, y), 0.9, true, -1, {})
	var up_road := 0
	for k in land.deco_cells:
		if land.is_up(k) and land.kind[k] == Land.Kind.ROAD:
			up_road += 1
	check(up_road > 0 and rc.is_empty(), "по мостовой — каменные плиты (%d клеток), второй раз там улучшать нечего" % up_road)
	var spent_road := m0 - c.money
	m0 = c.money
	await stroke("upgrade", [Vector2(X0 + 29.0, y), Vector2(X0 + 39.0, y)])
	var up_pl := 0
	for k in land.deco_cells:
		if land.is_up(k) and land.kind[k] == Land.Kind.PLAZA:
			up_pl += 1
	check(up_pl > 0 and absf((m0 - c.money) - up_pl * float(Defs.ROAD_UP["plaza"])) < 0.05 and absf(spent_road - up_road * float(Defs.ROAD_UP["road"])) < 0.05,
		"по площади — травертин (%d клеток); цены: плиты %s, травертин %s за клетку" % [up_pl, Defs.ROAD_UP["road"], Defs.ROAD_UP["plaza"]])
	check(game.land_mat.get_shader_parameter("deco_on") == true, "шейдер земли рисует улучшения (deco_on)")
	# отмена и повтор
	var n_up := land.up_n
	m0 = c.money
	game._undo("road")
	var n_after := land.up_n
	game._redo()
	check(n_after < n_up and land.up_n == n_up and absf(c.money - m0) < 0.05, "Ctrl+Z снимает травертин (и возвращает деньги), Ctrl+Y кладёт снова: %d → %d → %d" % [n_up, n_after, land.up_n])
	# прямой линией
	land.paint_line(Vector2(X0, y + 6.0), Vector2(X0 + 20.0, y + 6.0), 1.0, Land.Kind.ROAD, true)
	await frames(2)
	game.brush_r = 1.0
	m0 = c.money
	await stroke("upgrade", [Vector2(X0 + 1.0, y + 6.0), Vector2(X0 + 19.0, y + 6.0)], true)
	var lc := land.brush_cells(Vector2(X0 + 10.0, y + 6.0), 0.9, false, -1, {})
	check(lc.is_empty() and c.money < m0, "«Улучшить» прямой линией: вся улица в плитах, списано %s ден." % str(snappedf(m0 - c.money, 0.1)))
	# ухоженная улица: дом у плит счастливее на 2%
	var h := place("house_pleb", Vector2(X0 + 10.0, y + 9.0), Vector2(0, 0.5), 10)
	if check(not h.is_empty(), "дом у улицы в плитах"):
		_settle(h, 2)
		c.compute()
		var sb := int(h.get("street", 0))
		var part := false
		for e: Array in h.get("happy_parts", []):
			if String(e[0]) == "Ухоженная улица" and int(e[1]) == Defs.STREET_BONUS:
				part = true
		check(sb == Defs.STREET_BONUS and part, "дом у улучшенной улицы: «Ухоженная улица» +%d%% в карточке" % Defs.STREET_BONUS, h.get("happy_parts", []))
		var bare := 0
		for hh: Dictionary in houses:
			bare += int(hh.get("street", 0))
		check(bare == 0, "дома у простой мостовой — без бонуса")
	# ластик убирает дорогу вместе с плитами; Ctrl+Z — снова плиты
	var n0 := land.up_n
	await stroke("erase", [Vector2(X0 + 18.0, y + 6.0)])
	var n1 := land.up_n
	game._undo("road")
	check(n1 < n0 and land.up_n == n0, "ластик убирает плиты вместе с дорогой, отмена возвращает их: %d → %d → %d" % [n0, n1, land.up_n])
	# мостовая поверх плит другим покрытием — плит больше нет (не даром)
	await stroke("plaza", [Vector2(X0 + 2.0, y + 6.0)])
	var left := 0
	for k in land.brush_cells(Vector2(X0 + 2.0, y + 6.0), 0.4, false, -1, {}):
		left += 1
	check(left > 0, "площадь поверх плит — простая площадь (улучшать заново, %d клеток)" % left)


## «Земля» (5.8): узор на траве, не на дороге; «Трава» и ластик стирают; прямая линия; цена
func _ground(X0: float, Z0: float) -> void:
	var p := Vector2(X0 + 60.0, Z0 + 62.0)
	game.clear_nature(p, 16.0)
	land.paint_line(p + Vector2(-8.0, 4.0), p + Vector2(8.0, 4.0), 0.75, Land.Kind.ROAD, true)
	await frames(2)
	game.brush_r = 2.0
	var g0 := land.ground_n
	var m0 := c.money
	game.ground_kind = 2
	await stroke("ground", [p, p + Vector2(4.0, 0.0)])
	var got := land.ground_n - g0
	var on_road := 0
	for k: int in land.deco_cells:
		if (land.deco[k] & Land.GMASK) != 0 and Land.walk_kind(land.kind[k]):
			on_road += 1
	check(got > 0 and on_road == 0 and absf((m0 - c.money) - got * Defs.GROUND_COST) < 0.01,
		"«Земля»: луг в цветах на %d клетках травы, на дорогу не ложится, цена %s за клетку" % [got, Defs.GROUND_COST])
	# каждый вид узора
	var kinds := {}
	for gk in range(1, Defs.GROUND.size()):
		game.ground_kind = gk
		await stroke("ground", [p + Vector2(-8.0 + gk * 2.5, -6.0)])
		kinds[gk] = true
	var seen := {}
	for k: int in land.deco_cells:
		seen[land.deco[k] & Land.GMASK] = true
	check(range(1, Defs.GROUND.size()).all(func(g): return seen.has(g)), "все пять видов узора кладутся", seen.keys())
	# «Трава» стирает
	var g1 := land.ground_n
	game.ground_kind = 0
	await stroke("ground", [p + Vector2(-5.5, -6.0)])
	check(land.ground_n < g1, "кружок «Трава» стирает узор (%d → %d)" % [g1, land.ground_n])
	# ластик: узор красным и стирается; отмена возвращает
	var g2 := land.ground_n
	await stroke("erase", [p + Vector2(2.0, 0.0)])
	var g3 := land.ground_n
	game._undo("road")
	check(g3 < g2 and land.ground_n == g2, "ластик стирает узор, Ctrl+Z возвращает (%d → %d → %d)" % [g2, g3, land.ground_n])
	# дорога поверх узора — узора под ней нет
	await stroke("path", [p + Vector2(0.0, 0.0)])
	var under := 0
	for k in land.erase_cells(p, 0.5, false, {}):
		if (land.deco[k] & Land.GMASK) != 0:
			under += 1
	check(under == 0, "тропа поверх луга — под тропой узора нет")
	# прямой линией — гравием
	game.ground_kind = 5
	game.brush_r = 0.75
	var g4 := land.ground_n
	m0 = c.money
	await stroke("ground", [p + Vector2(-8.0, 9.0), p + Vector2(8.0, 9.0)], true)
	check(land.ground_n > g4 and c.money < m0, "«Земля» прямой линией: гравийная дорожка (%d клеток)" % (land.ground_n - g4))
	game.set_tool("")


## «Ухоженная улица» знает и о простой мостовой у входа (правка по проверке): плит ровно половина — бонус есть;
## дорисовали две клетки обычной мостовой — плит меньше половины, бонуса нет сразу; отмена — бонус снова
func _street_cache(X0: float, Z0: float) -> void:
	# сухое ровное свободное место своей земли
	var x := X0 + 24.0
	var y := Z0 + 86.0
	var found := false
	for yy in range(84, 130, 6):
		for xx in range(10, 100, 8):
			var lo := INF
			var hi := -INF
			var ok := true
			for dz in range(-3, 7):
				for dx in range(-9, 10):
					var q := Vector2(X0 + xx + dx, Z0 + yy + dz)
					var cq := land.cell(q)
					var kq := land.idx(cq.x, cq.y)
					if not land.is_owned(q) or land.occ[kq] != 0 or land.under.has(kq) or land.kind[kq] != Land.Kind.GRASS:
						ok = false
					lo = minf(lo, land.hq(kq))
					hi = maxf(hi, land.hq(kq))
			if ok and lo > Land.WATER_Y + 0.3 and hi - lo < 0.8:
				x = X0 + xx
				y = Z0 + yy
				found = true
				break
		if found:
			break
	game.clear_nature(Vector2(x, y), 12.0)
	land.paint_line(Vector2(x - 8.0, y), Vector2(x + 8.0, y), 0.5, Land.Kind.ROAD, true)
	await frames(2)
	var h := place("house_pleb", Vector2(x, y + 2.6), Vector2(0.5, 0), 12)
	if not check(not h.is_empty(), "дом у новой улицы (кэш «ухоженной улицы»)"):
		return
	var cc := land.cell(c.door_point(h))
	var walk := PackedInt32Array()
	var grass := PackedInt32Array()
	for dj in range(-8, 9, 2):                # те же клетки, что смотрит City.street_bonus
		for di in range(-8, 9, 2):
			if di * di + dj * dj > 64 or not land.inside(cc.x + di, cc.y + dj):
				continue
			var k := land.idx(cc.x + di, cc.y + dj)
			if land.occ[k] != 0 or land.is_up(k):
				continue
			if Land.walk_kind(land.kind[k]):
				walk.append(k)
			elif land.kind[k] == Land.Kind.GRASS and land.hq(k) > Land.WATER_Y + 0.05:
				grass.append(k)
	if not check(walk.size() >= 7 and grass.size() >= 2, "у входа есть мостовая и трава", [walk.size(), grass.size()]):
		return
	land.brush_apply(walk.slice(0, (walk.size() + 1) / 2), -1)
	var b1 := c.street_bonus(h)
	var ch := land.apply_cells(grass.slice(0, 2), Land.Kind.ROAD)
	var b2 := c.street_bonus(h)
	land.undo(ch)
	var b3 := c.street_bonus(h)
	check(b1 == Defs.STREET_BONUS and b2 == 0 and b3 == Defs.STREET_BONUS,
		"«ухоженная улица»: дорисовали простую мостовую у входа — бонус ушёл, отменили — вернулся (%d → %d → %d)" % [b1, b2, b3])


## Прямая «Улучшить» / «Земли» — за один проход по полосе (правка по проверке): длинная широкая прямая считается быстро,
## клетки — те же, что у штампов свободной кисти
func _brush_line_perf(X0: float, Z0: float) -> void:
	game.set_tool("ground")
	game.ground_kind = 3
	var a := Vector2(X0, Z0 + 100.0)
	var b := a + Vector2(60.0, 4.0)
	game.brush_square = false
	game.brush_r = 4.0
	var t0 := Time.get_ticks_usec()
	var bl: Dictionary = game._brush_line_cells(a, b)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	var t1 := Time.get_ticks_usec()
	var old := _stamps(a, b, 4.0, false, 3)
	var ms_old := (Time.get_ticks_usec() - t1) / 1000.0
	var ts: PackedFloat32Array = bl["t"]
	var sorted := true
	for n in range(1, ts.size()):
		if ts[n] < ts[n - 1]:
			sorted = false
	print("S5B PERF прямая «Земли» 60 м, кисть 4 м: %.1f мс за пересчёт (штампами было %.1f мс), клеток %d / %d" % [ms, ms_old, (bl["cells"] as PackedInt32Array).size(), old.size()])
	check(ms < 150.0 and ms * 5.0 < ms_old and sorted and absi((bl["cells"] as PackedInt32Array).size() - old.size()) * 100 <= old.size() * 2,
		"прямая «Земли» 60 м кистью 4 м: %.0f мс за пересчёт (было %.0f), клетки по порядку вдоль линии" % [ms, ms_old])
	# те же клетки, что у штампов: круг и квадрат, наискосок
	var bad := []
	for sq: bool in [false, true]:
		game.brush_square = sq
		game.brush_r = 2.0
		var a2 := Vector2(X0 + 4.0, Z0 + 108.0)
		var b2 := a2 + Vector2(7.0, 5.0)
		var nw := {}
		for k in (game._brush_line_cells(a2, b2)["cells"] as PackedInt32Array):
			nw[k] = true
		var st := {}
		for k in _stamps(a2, b2, 2.0, sq, 3):
			st[k] = true
		var diff := 0
		for k in nw:
			if not st.has(k):
				diff += 1
		for k in st:
			if not nw.has(k):
				diff += 1
		if st.is_empty() or diff * 100 > st.size() * 3:
			bad.append([sq, diff, st.size()])
	check(bad.is_empty(), "прямая кисти — те же клетки, что штампы свободного мазка (разница ≤ 3%)", bad)
	game.brush_square = false
	game.set_tool("")


## Прежний способ прямой (для сравнения): штампы кисти через 0,25 м
func _stamps(a: Vector2, b: Vector2, r: float, sq: bool, gk: int) -> PackedInt32Array:
	var seen := {}
	var out := PackedInt32Array()
	var n := int(a.distance_to(b) / Land.CELL) + 1
	for s in n + 1:
		out.append_array(land.brush_cells(a.lerp(b, float(s) / n), r, sq, gk, seen))
	return out


## Сохранение большого узора (правка по проверке): куски узора считаются заранее понемногу (save_warm), в кадре снимка
## автосохранения — только готовое; строки те же (клетки и значения)
func _deco_save_perf() -> void:
	var l3 := Land.new()
	for j in range(300, 1300):
		for i in range(300, 450):
			l3.set_deco(j * Land.N + i, Land.UP if (i + j) % 3 != 0 else 2)
	l3.set_deco(300 * Land.N + 300, 0)
	var t0 := Time.get_ticks_usec()
	var old_c := PackedInt32Array()
	var old_v := PackedByteArray()
	for k: int in l3.deco_cells:                 # прежний способ: перебор всех клеток узора в кадре снимка
		old_c.append(k)
		old_v.append(l3.deco[k])
	var old_s := [Marshalls.raw_to_base64(old_c.to_byte_array()), Marshalls.raw_to_base64(old_v)]
	var ms_old := (Time.get_ticks_usec() - t0) / 1000.0
	var worst := 0.0
	var calls := 0
	while (not l3._dc_dirty.is_empty() or l3._deco_enc.is_empty() or not l3._save_dirty.is_empty()) and calls < 3000:
		var t1 := Time.get_ticks_usec()
		l3.save_warm()
		worst = maxf(worst, (Time.get_ticks_usec() - t1) / 1000.0)
		calls += 1
	var sd := {}
	var snap := INF
	for rep in 3:                                # меньшее из трёх: соседняя линия может отнять у процесса квант
		var t2 := Time.get_ticks_usec()
		sd = l3.save_changes()
		snap = minf(snap, (Time.get_ticks_usec() - t2) / 1000.0)
	var dc := Marshalls.base64_to_raw(sd.get("deco", "")).to_int32_array()
	var dv := Marshalls.base64_to_raw(sd.get("deco_v", ""))
	var same: bool = dc.size() == l3.deco_cells.size() and dv.size() == dc.size() and String(old_s[0]).length() == String(sd.get("deco", "")).length()
	for n in dc.size():
		if l3.deco[dc[n]] != dv[n] or dv[n] == 0:
			same = false
			break
	print("S5B PERF узор %d клеток: снимок %.2f мс (прежде перебор %.1f мс), заранее — %d кадров, самый долгий %.2f мс" % [dc.size(), snap, ms_old, calls, worst])
	check(same and snap < 8.0 and worst < 12.0, "узор 150 тыс. клеток: в кадре снимка %.1f мс, заранее — не дольше %.1f мс за кадр, строки — те же клетки и значения" % [snap, worst])


## Деревья под арками и у концов больших зданий (правки по проверке): природа растёт заново (как при загрузке); акведук
## через рощу — под арками и у жёлоба ни ствола, ни куста (и призрак прячет их же); после «загрузки» — снова нет;
## цирк убирает деревья по всему своему следу (он длиннее 28 м)
func _arch_nature(built: Dictionary) -> void:
	var cb: Dictionary = built.get("circus_fl", {})
	var cpl := {}
	if not cb.is_empty():
		cpl = {"pos": cb["pos"], "yaw": cb["yaw"], "variant": cb["variant"], "color": cb["color"]}
		c.remove(cb, false)
	_regrow()
	var hl := CatGrand.AQ_HALF * Catalog.ARCH
	# самое лесистое место своей земли, где кусок встаёт
	var cand := []
	for zz in range(70, 252, 3):
		for xx in range(132, 252, 3):
			var p := Vector2(xx, zz)
			var n := _axis_nature(p - Vector2(hl, 0), p + Vector2(hl, 0), 1.2).size()
			if n > 0:
				cand.append([n, p])
	cand.sort_custom(func(u, v): return int(u[0]) > int(v[0]))
	var at := Vector2.INF
	var before := 0
	for e: Array in cand.slice(0, 40):
		if String(c.check_place("aqua", e[1], 0.0)["err"]) == "":
			at = e[1]
			before = int(e[0])
			break
	if check(at != Vector2.INF, "акведук встаёт в роще (деревьев у оси до постройки: %d)" % before):
		var axn := _axis_nature(at - Vector2(hl, 0), at + Vector2(hl, 0), 1.2)
		# призрак: прячутся те же деревья, что уберёт постройка
		game.set_tool("aqua")
		var pl := {"pos": at, "yaw": 0.0, "cells": c.check_place("aqua", at, 0.0)["cells"]}
		game._ghost_trees(true, pl)
		game._tree_ms = Time.get_ticks_msec() - 1000
		game._ghost_trees(true, pl)
		var hid := 0
		for it in axn:
			if game.tree_hidden.any(func(o): return is_same(o, it)):
				hid += 1
		check(hid == axn.size(), "призрак акведука прячет все деревья у оси (%d из %d)" % [hid, axn.size()])
		game.set_tool("")
		var aq := c.place("aqua", at, 0.0, 0, 0, true)
		var left := _axis_nature(at - Vector2(hl, 0), at + Vector2(hl, 0), 1.2).size()
		check(left == 0, "акведук через рощу: у оси ни дерева, ни куста (было %d, осталось %d)" % [before, left])
		_regrow(false)
		var grown := _axis_nature(at - Vector2(hl, 0), at + Vector2(hl, 0), 1.2).size()
		game._nature_arches()
		var after := _axis_nature(at - Vector2(hl, 0), at + Vector2(hl, 0), 1.2).size()
		check(after == 0, "после загрузки под арками снова пусто (выросло бы %d, осталось %d)" % [grown, after])
		c.remove(aq, false)
		check(not land.under.values().has(int(aq["id"])), "снесли акведук — полоса под арками свободна")
	# цирк: деревья по всему следу, и у дальних концов (за 14 м от середины)
	if not cpl.is_empty():
		var chk: Dictionary = c.check_place("circus_fl", cpl["pos"], float(cpl["yaw"]), int(cpl["variant"]), int(cpl["color"]), -2)
		var cells := {}
		for k in (chk["cells"] as PackedInt32Array):
			cells[k] = true
		var far0 := _in_cells(cells, cpl["pos"], 14.0)
		var nb := c.place("circus_fl", cpl["pos"], float(cpl["yaw"]), int(cpl["variant"]), int(cpl["color"]), true)
		var far1 := _in_cells(cells, cpl["pos"], 14.0)
		var all1 := _in_cells(cells, cpl["pos"], 0.0)
		check(not nb.is_empty() and all1 == 0, "цирк убирает деревья по всему следу: у концов дальше 14 м было %d, осталось %d (всего в следе %d)" % [far0, far1, all1])


## Вся природа заново, как при загрузке (природа не сохраняется)
func _regrow(arches := true) -> void:
	game._trees_restore()
	for key in game.nature:
		for it in game.nature[key]:
			game.parts.remove(it["h"])
	game.nature.clear()
	game._nature()
	if arches:
		game._nature_arches()


## Деревья и кусты ближе r к отрезку a–b
func _axis_nature(a: Vector2, b: Vector2, r: float) -> Array:
	var out := []
	var ab := b - a
	for kz in range(int((minf(a.y, b.y) - r) / 2.0) - 1, int((maxf(a.y, b.y) + r) / 2.0) + 2):
		for kx in range(int((minf(a.x, b.x) - r) / 2.0) - 1, int((maxf(a.x, b.x) + r) / 2.0) + 2):
			for it in game.nature.get(Vector2i(kx, kz), []):
				var nm: String = it["name"]
				if not (nm.begins_with("SM_Env_Tree") or nm.begins_with("SM_Env_Bush")):
					continue
				var p: Vector2 = it["p"]
				var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
				if p.distance_to(a + ab * t) < r:
					out.append(it)
	return out


## Природа (любая) на клетках следа — дальше d от середины постройки
func _in_cells(cells: Dictionary, at: Vector2, d: float) -> int:
	var n := 0
	for key in game.nature:
		for it in game.nature[key]:
			var p: Vector2 = it["p"]
			if p.distance_to(at) < d:
				continue
			var q := land.cell(p)
			if cells.has(land.idx(q.x, q.y)):
				n += 1
	return n


var _tri_c := {}


func _tris(nm: String) -> int:
	if nm.begins_with("#"):
		return 12
	if not _tri_c.has(nm):
		var n := 0
		var node := Synty.make(nm)
		for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			for si in mi.mesh.get_surface_count():
				var arr := mi.mesh.surface_get_arrays(si)
				var ix = arr[Mesh.ARRAY_INDEX]
				n += (ix.size() / 3) if ix != null else (arr[Mesh.ARRAY_VERTEX].size() / 3)
		node.free()
		_tri_c[nm] = n
	return int(_tri_c[nm])


func _rinfo() -> Vector3i:
	var vp := get_viewport().get_viewport_rid()
	var RS := RenderingServer
	return Vector3i(RS.viewport_get_render_info(vp, RS.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RS.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		RS.viewport_get_render_info(vp, RS.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RS.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		RS.viewport_get_render_info(vp, RS.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RS.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME))


## Шесть новых зданий рядом (пустое место на краю своей земли, до остальных проверок): общий снимок; вызовы отрисовки
## здесь — почти все детали впервые в городе (бюджет волны сверяется в городе владельца, _owner_perf)
func _perf() -> void:
	game.hud.visible = false
	game.rig.cine = true
	var ctr := Vector2(165.0, 205.0)
	game.clear_nature(ctr, 34.0)
	game.rig.cine_look(Vector3(ctr.x, 62.0, ctr.y + 58.0), Vector3(ctr.x, 0.0, ctr.y))
	await frames(40)
	var a := _rinfo()
	var spots := {"ludus": Vector2(-16, -12), "aqua": Vector2(0, -14), "venus": Vector2(16, -12), "thermae": Vector2(-16, 8), "pharos": Vector2(0, 6), "circus_fl": Vector2(8, 24)}
	var tmp := []
	for t: String in spots:
		tmp.append(c.place(t, ctr + spots[t], 0.0, 0, 0, true))
	await frames(40)
	var b2 := _rinfo()
	print("S5B PERF новая игра, шесть новых зданий в пустом городе: вызовов отрисовки +%d видимых, +%d в тенях, треугольников +%d (было %s, стало %s)" % [b2.x - a.x, b2.y - a.y, b2.z - a.z, a, b2])
	if shots:
		await shot("s5b_block.png")
	for b: Dictionary in tmp:
		c.remove(b, false)
	await frames(10)
	game.rig.cine = false
	game.hud.visible = true


func _look(p: Vector3, yaw: float, dist: float, pitch := 0.62) -> void:
	game.rig.cine_look(p + Vector3(sin(yaw) * dist, dist * pitch, cos(yaw) * dist), p + Vector3(0, 1.0, 0))
	await frames(30)


func _shots(built: Dictionary, X0: float, Z0: float) -> void:
	game.hud.visible = false
	game.rig.cine = true
	# работники приходят на работу (гладиаторы в лудусе, служители терм): утро идёт быстро, потом время стоит
	game._set_hour(8.5)
	game.speed = 4.0
	await frames(600)
	game.speed = 0.0
	await frames(5)
	var dist := {"ludus": 13.0, "aqua": 14.0, "venus": 22.0, "thermae": 18.0, "pharos": 22.0, "circus_fl": 40.0}
	for t: String in built:
		var bb: Dictionary = built[t]
		var p := Vector3(bb["pos"].x, land.height_at(bb["pos"].x, bb["pos"].y), bb["pos"].y)
		var f := City.facing(float(bb["yaw"]))
		var yaw := atan2(f.x, f.y) + 0.55
		await _look(p, yaw, float(dist[t]))
		await shot("s5b_%s.png" % t)
	# лудус крупно: гладиаторы на арене
	var lu: Dictionary = built.get("ludus", {})
	if not lu.is_empty():
		var lp := Vector3(lu["pos"].x, land.height_at(lu["pos"].x, lu["pos"].y), lu["pos"].y)
		await _look(lp, atan2(City.facing(float(lu["yaw"])).x, City.facing(float(lu["yaw"])).y), 7.0, 0.7)
		await shot("s5b_ludus_close.png")
	# акведук над улицей
	var aq: Dictionary = built.get("aqua", {})
	if not aq.is_empty():
		var ap := Vector3(aq["pos"].x, land.height_at(aq["pos"].x, aq["pos"].y), aq["pos"].y)
		await _look(ap, float(aq["yaw"]) + 0.9, 16.0, 0.35)
		await shot("s5b_aqua_street.png")
	# маяк ночью
	var ph: Dictionary = built.get("pharos", {})
	if not ph.is_empty():
		game._set_hour(22.0)
		await frames(30)
		var pp := Vector3(ph["pos"].x, land.height_at(ph["pos"].x, ph["pos"].y), ph["pos"].y)
		await _look(pp + Vector3(0, 5.0, 0), 2.3, 26.0, 0.25)
		await shot("s5b_pharos_night.png")
		game._set_hour(10.5)
	# улучшение дорог: тропа → мостовая → плиты, площадь → травертин
	await _look(Vector3(X0 + 20.0, land.height_at(X0 + 20.0, Z0 + 63.0), Z0 + 63.0), 0.2, 20.0, 0.75)
	await shot("s5b_road_upgrade.png")
	await _look(Vector3(X0 + 33.0, land.height_at(X0 + 33.0, Z0 + 60.0), Z0 + 60.0), 0.4, 7.0, 0.7)
	await shot("s5b_road_upgrade_close.png")
	# кисти «Земля»: где проверяли — и пять узоров рядком (для снимка)
	await _look(Vector3(X0 + 60.0, land.height_at(X0 + 60.0, Z0 + 62.0), Z0 + 62.0), 0.3, 16.0, 0.8)
	await shot("s5b_ground.png")
	var gp := Vector2(X0 + 10.0, Z0 + 76.0)
	game.clear_nature(gp + Vector2(10.0, 0.0), 14.0)
	game.brush_square = false
	game.brush_r = 1.6
	for gk in range(1, Defs.GROUND.size()):
		game.ground_kind = gk
		await stroke("ground", [gp + Vector2(gk * 4.2, -1.0), gp + Vector2(gk * 4.2, 1.0)])
	game.set_tool("")
	game.speed = 0.0
	await frames(5)
	await _look(Vector3(gp.x + 12.6, land.height_at(gp.x + 12.6, gp.y), gp.y), 0.0, 17.0, 0.95)
	await shot("s5b_ground_close.png")
	game.speed = 0.0
	game.rig.cine = false
	game.hud.visible = true


# ---------- город владельца ----------

func _gpu(n: int) -> float:
	var vp := get_viewport().get_viewport_rid()
	var v := []
	for i in n:
		await get_tree().process_frame
		v.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
	v.sort()
	return float(v[int(v.size() * 0.5)])


## Бюджет волны (план 5, приёмка): в городе владельца, в виде по умолчанию, шесть новых зданий и ещё три куска акведука
## в кадре — ≤ +80 видимых вызовов отрисовки; время видеокарты — для отчёта (соседняя линия может грузить видеокарту)
func _owner_perf() -> void:
	game.hud.visible = false
	game.people.visible = false               # считаем сами здания: жители и животные — не в счёт (они ходят по всему городу)
	game.actors_root.visible = false
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	await frames(30)
	var ctr := Vector2(210.0, 145.0)
	game.rig.set_view(Vector3(ctr.x, Land.BASE_Y, ctr.y), 15.0, 42.0, 60.0)
	await frames(90)
	var a := _rinfo()
	var ga := await _gpu(90)
	var spots := {"ludus": Vector2(-14, -8), "venus": Vector2(14, -8), "thermae": Vector2(-14, 10), "pharos": Vector2(0, 2), "circus_fl": Vector2(0, 22)}
	var tmp := []
	var g0 := {}
	for k: String in game.parts.groups:
		g0[k] = true
	var per := {}
	for t: String in spots:
		var n0: int = game.parts.groups.size()
		tmp.append(c.place(t, ctr + spots[t], 0.0, 0, 0, true))
		per[t] = game.parts.groups.size() - n0
	for k in 4:
		tmp.append(c.place("aqua", ctr + Vector2(-14.4 + k * 2.0 * CatGrand.AQ_HALF * Catalog.ARCH, -20.0), 0.0, 0, 0, true))
	var fresh := []
	var subs := 0
	for k: String in game.parts.groups:
		if not g0.has(k):
			fresh.append(k.get_slice("|", 0) + ("" if k.get_slice("|", 1) == "{}" else "*") + "(%d)" % (game.parts.groups[k]["subs"] as Array).size())
			subs += (game.parts.groups[k]["subs"] as Array).size()
	print("S5B PERF новых групп деталей %d (сеток %d), по зданиям %s: %s" % [fresh.size(), subs, per, ", ".join(fresh)])
	await frames(90)
	var b2 := _rinfo()
	var gb := await _gpu(90)
	print("S5B PERF город владельца, шесть новых зданий и 4 куска акведука в кадре: вызовов отрисовки +%d видимых, +%d в тенях, треугольников +%d; видеокарта %.2f → %.2f мс (%+.2f)" % [
		b2.x - a.x, b2.y - a.y, b2.z - a.z, ga, gb, gb - ga])
	check(b2.x - a.x <= 80, "бюджет волны: новые здания в кадре города владельца — ≤ +80 видимых вызовов отрисовки (+%d)" % (b2.x - a.x))
	if shots:
		await shot("s5b_owner_block.png")
	for b: Dictionary in tmp:
		c.remove(b, false)
	game.people.visible = true
	game.actors_root.visible = true
	game.hud.visible = true


func _owner() -> void:
	check(land.deco_cells.is_empty() and land.up_n == 0 and land.ground_n == 0, "город владельца: узора земли и плит нет")
	check(game.deco_imgs.is_empty() and game.land_mat.get_shader_parameter("deco_on") != true, "маски узора не заведены, шейдер земли — как был")
	var sd: Dictionary = game._save_data()
	check(not (sd["land"] as Dictionary).has("deco"), "сохранение без узора — как прежде (ключа deco нет)")
	var street := 0
	for id in c.buildings:
		street += int(c.buildings[id].get("street", 0))
	check(street == 0, "«ухоженной улицы» нет ни у одного дома")
	var newr := W2.filter(func(t): return c.research.has(String(Defs.B[t]["unlock"])))
	check(newr.is_empty() and not c.research.has(Defs.ROAD_UP_RES), "новые исследования не изучены сами (их изучает игрок)")
	var ub = game.hud.bar_left.find_child("upgrade_box", true, false)
	check(ub != null and not ub.visible, "кисти «Улучшить» до исследования не видно")
	var gb = game.hud.road_btns.get("ground")
	check(gb != null and (gb as Control).is_visible_in_tree(), "кнопка «Земля» — слева внизу")
	# в живом городе всё работает как раньше: новое здание открывается исследованием
	c.research["aqua"] = true
	check(c.unlocked("aqua"), "исследование «Акведук» открывает акведук")
	c.research.erase("aqua")
	# первая прямая «Улучшить» в городе без плит (правка по проверке): показ — плитками, текстура плит уже привязана;
	# недотянутая прямая (сменили инструмент) не ложится
	c.research[Defs.ROAD_UP_RES] = true
	var rp := _owner_road()
	if check(rp != Vector2.INF, "в городе владельца есть улица у середины"):
		var m0 := c.money
		var ts0 = game.land_mat.get_shader_parameter("tile_slab")
		game.set_tool("upgrade")
		game.brush_line = true
		game.hover = rp
		game._click()
		game.hover = rp + Vector2(5.0, 0.0)
		game._line_update(true)
		var ts1 = game.land_mat.get_shader_parameter("tile_slab")
		var pm: int = game._prev_mode
		game.set_tool("")
		check(ts0 == null and ts1 != null and pm == 1, "первая прямая «Улучшить»: показ плитками (текстура плит привязана к показу, до того — нет)", [ts0, ts1, pm])
		check(land.up_n == 0 and land.deco_cells.is_empty() and absf(c.money - m0) < 0.01, "недотянутая прямая не легла: плит нет, деньги на месте")
	c.research.erase(Defs.ROAD_UP_RES)
	await _owner_perf()


## Свободная мостовая своей земли поближе к середине города
func _owner_road() -> Vector2:
	for r in range(0, 120, 2):
		for k in 24:
			var p := Land.START + Vector2(cos(k * TAU / 24.0), sin(k * TAU / 24.0)) * r
			var cc := land.cell(p)
			if not land.inside(cc.x, cc.y):
				continue
			var kk := land.idx(cc.x, cc.y)
			if land.kind[kk] == Land.Kind.ROAD and land.occ[kk] == 0 and land.is_owned(p):
				return p
	return Vector2.INF
