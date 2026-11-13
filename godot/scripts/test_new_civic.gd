extends Node
## Новые театр, одеон, библиотека и большие термы (NewCivic): снимки для владельца и проверки.
##   bash .work/py/gpu_run.sh res://test_new_civic.tscn -- out=D:/CivCity/.work/rebuild/b1/<папка>/ [types=theatre,odeon,library,thermae]
##        [newcivic=0 — прежние] [fit=1 — как из старого сохранения (на прежних клетках)] [hours=11,18.5] [views=0,1,4]
##        [show=1 — представление в театре и одеоне, купальщики в термах] [city=путь — город владельца: viewsc=x:z:yaw:pitch:dist,…]
##        [place=тип:x:z,… — новые постройки в городе владельца]
## Снимки: <out>/<тип>_<метка>_v<вид>_h<час>.png (метка — new, fit или old); строки «NC …», в конце «NC DONE fails=N».

var game
var c: City
var out := "D:/CivCity/.work/rebuild/b1/t/"
var hours := [11.0, 18.5]
var types := ["theatre", "odeon", "library", "thermae"]
var fit := false
var show := false
var city_src := ""
var vsel := []
var tagn := "new"
var fails := 0
var A := {}


func check(ok: bool, what: String) -> bool:
	print(("NC PASS " if ok else "NC FAIL ") + what)
	if not ok:
		fails += 1
	return ok


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() < 2:
			continue
		A[kv[0]] = kv[1]
		match kv[0]:
			"out": out = kv[1]
			"newcivic":
				NewCivic.ON = {} if kv[1] == "0" else {"theatre": true, "odeon": true, "library": true, "thermae": true}
			"hours":
				hours = []
				for h in kv[1].split(","):
					hours.append(float(h))
			"types": types = Array(kv[1].split(","))
			"fit": fit = kv[1] != "0"
			"show": show = kv[1] != "0"
			"city": city_src = kv[1]
			"views":
				for v in kv[1].split(","):
					vsel.append(int(v))
	tagn = ("fit" if fit else "new") if not NewCivic.ON.is_empty() else "old"
	if city_src != "":
		# копия города владельца — в папку сохранений этого запуска (gpu_run: своя на каждый запуск), не в настоящую
		DirAccess.copy_absolute(city_src, GamePaths.save_dir().path_join("city.json"))
		Game.boot = {"play": "1", "hour": "11"}
	else:
		Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func secs(t: float) -> void:
	var w := 0.0
	while w < t:
		await get_tree().process_frame
		w += get_process_delta_time()


func put(type: String, at: Vector2, tries := 80, stepr := 0.3) -> Dictionary:
	for k in tries:
		var p := at + Vector2(cos(k * 2.4), sin(k * 2.4)) * (k * stepr)
		var pl: Dictionary = game.placement(type, p)
		if pl["err"] == "":
			var b := c.place(type, pl["pos"], pl["yaw"], pl["variant"], pl["color"], true)
			game._show(b)
			return b
	print("NC NOTE не встало ", type, " у ", at)
	return {}


func bounds(b: Dictionary) -> Array:
	var xf := c.xf(b)
	var r := [INF, -INF, INF, -INF]
	for rc: Rect2 in c.blueprint(b).footprint():
		for q: Vector2 in [rc.position, rc.end, Vector2(rc.position.x, rc.end.y), Vector2(rc.end.x, rc.position.y)]:
			var w := xf * Vector3(q.x, 0, q.y)
			r[0] = minf(r[0], w.x)
			r[1] = maxf(r[1], w.x)
			r[2] = minf(r[2], w.z)
			r[3] = maxf(r[3], w.z)
	return r


## Треугольники одной детали (сетка Synty или коробка пула)
static var _tri := {}
func tris_of(nm: String) -> int:
	if _tri.has(nm):
		return _tri[nm]
	var n := 12
	if not nm.begins_with("#"):
		n = 0
		var node := Synty.make(nm)
		for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh:
				n += mi.mesh.get_faces().size() / 3
		node.free()
	_tri[nm] = n
	return n


## Размеры и «цена» постройки: след в осях постройки, площадь, высота, деталей, треугольников, групп пула, огней
func info(b: Dictionary, what := "") -> Dictionary:
	var bp := c.blueprint(b)
	var lot := Rect2()
	var first := true
	for r: Rect2 in bp.footprint():
		lot = r if first else lot.merge(r)
		first = false
	var top := 0.0
	var tri := 0
	var groups := {}
	for p: Array in bp.parts:
		var nm := String(p[0])
		var bx: AABB = (p[1] as Transform3D) * Bp.model_aabb(nm)
		if not nm.begins_with("#"):
			top = maxf(top, bx.end.y)
		tri += tris_of(nm)
		groups[nm + "|" + str(p[2])] = true
	var seats := -1
	if game.spectacle and Spectacle.is_venue(String(b["type"])):
		seats = (game.spectacle.layout(b)["seats"] as Array).size()
	var res := {"w": lot.size.x, "d": lot.size.y, "area": lot.size.x * lot.size.y, "top": top, "parts": bp.parts.size(), "tris": tri,
		"groups": groups.size(), "lights": bp.lights.size(), "seats": seats}
	print("NC INFO %s %s %s: след %.2f × %.2f м = %.1f м² (%.1f дома), верх %.2f м, деталей %d, треугольников %d, групп %d, огней %d, мест %d, sz=%s, door=%s" % [
		b["type"], tagn, what, lot.size.x, lot.size.y, res["area"], float(res["area"]) / SizeLadder.HOUSE, top, bp.parts.size(), tri, groups.size(),
		bp.lights.size(), seats, str(b.get("sz", "—")), bp.door])
	return res


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(10)
	c = game.city
	game.can_save = false
	for r in Defs.RESEARCH:
		c.research[r["id"]] = true
	c.level = 7
	c.money = 900000
	game.hud.visible = false
	game.speed = 0.0
	if game.weather:
		game.weather.left_h = 0.0
		game.weather.force = 0.0
	DirAccess.make_dir_recursive_absolute(out)
	if city_src != "":
		await _owner_city()
		print("NC DONE fails=%d" % fails)
		get_tree().quit()
		return
	if game.people and not show:
		game.people.visible = false
	var X0 := 150.0
	var Z0 := 124.0
	game.clear_nature(Vector2(X0 + 10.0, Z0), 48.0)
	game.land.paint_line(Vector2(X0 - 40.0, Z0), Vector2(X0 + 60.0, Z0), 2.2, Land.Kind.ROAD, true)
	await frames(4)
	var x := X0 - 32.0
	var built := []
	for t: String in types:
		var w: float = (NewCivic.FULL[t] as Vector2).x
		var b := put(t, Vector2(x + w * 0.5 + 1.0, Z0 - 6.0))
		if b.is_empty():
			check(false, "встало: " + t)
			continue
		if fit:
			b.erase("sz")                            # как из старого сохранения: облик — под прежние клетки (SizeLadder.old_lot)
			game._show(b)
		var tb := bounds(b)
		x = float(tb[1]) + 2.5
		built.append(b)
	await frames(30)
	for b: Dictionary in built:
		var inf := info(b)
		var t := String(b["type"])
		if not NewCivic.ON.is_empty():
			_checks(b, inf)
	if show:
		for b: Dictionary in built:
			await _show(b)
	else:
		for b: Dictionary in built:
			await _sheet(b)
	print("NC DONE fails=%d" % fails)
	get_tree().quit()


## Проверки новой сборки: размер по линейке, высота ниже храма, без прежнего наполнения, двери и ставни (Life),
## нет «магенты» (неизвестных деталей), места зрителей и купальщиков
func _checks(b: Dictionary, inf: Dictionary) -> void:
	var t := String(b["type"])
	var want := {"theatre": 79.0, "odeon": 67.0, "library": 62.0, "thermae": 112.0}
	var old := {"theatre": 74.0, "odeon": 63.0, "library": 48.0, "thermae": 154.0}     # термы: новые посреди прежнего следа, мостовая — по всему нему
	var a := float(inf["area"])
	if fit:
		var o: Array = NewCivic.OLD_RECT[t]
		var ow := float(o[1]) - float(o[0]) + 0.05
		var od := float(o[3]) - float(o[2]) + 0.05
		check(float(inf["w"]) <= ow and float(inf["d"]) <= od, "%s на прежних клетках: %.2f × %.2f ≤ %.2f × %.2f" % [t, inf["w"], inf["d"], ow, od])
		check(absf(a - float(old[t])) < 6.0, "%s на прежних клетках: %.1f м² (≈ %.0f)" % [t, a, old[t]])
	else:
		check(absf(a - float(want[t])) < 4.0, "%s по линейке: %.1f м² (≈ %.0f)" % [t, a, want[t]])
	check(float(inf["top"]) < 6.8, "%s ниже конька храма Юпитера (6,8 м): %.2f м" % [t, inf["top"]])
	var bp := c.blueprint(b)
	var bad := 0
	for p: Array in bp.parts:
		var nm := String(p[0])
		if nm.begins_with("#dress") or nm.begins_with("#shutters") or nm.begins_with("#lit") or nm.begins_with("#dark"):
			bad += 1
	check(bad == 0, "%s без прежнего наполнения и тёмных коробок (%d)" % [t, bad])
	check(c.apron_of(b) == 0, "%s без глины и мостовой вокруг: своё основание (apron %d)" % [t, c.apron_of(b)])
	var li: Dictionary = game.life.info(bp, t)
	match t:
		"library":
			check(not (li["doors"] as Array).is_empty(), "библиотека: бронзовые створки входа найдены (Life)")
			check(int(li["pairs"]) >= 1, "библиотека: ставни створками (%d пар)" % int(li["pairs"]))
		"thermae":
			check(not (li["doors"] as Array).is_empty(), "%s: створки входа найдены (Life)" % t)
		"theatre", "odeon":
			check((li["doors"] as Array).is_empty(), "%s: дверей Synty у входа нет (вход — открытая арка с проходом к орхестре)" % t)
	if game.spectacle and Spectacle.is_venue(t):
		var lay: Dictionary = game.spectacle.layout(b)
		var seats: Array = lay["seats"]
		var need := {"theatre": 45, "odeon": 30, "thermae": 20} if fit else {"theatre": 60, "odeon": 40, "thermae": 20}     # прежние: 46 и 32
		check(seats.size() >= int(need[t]), "%s: мест %d (≥ %d), отброшено %d" % [t, seats.size(), need[t], int(lay.get("dropped", 0))])
		if t != "thermae":
			check(lay.has("priest") and absf(float((lay["priest"] as Dictionary)["yaw"])) < 0.01, "%s: актёр на сцене лицом к зрителям" % t)
			# все сидят лицом к сцене (к −Z постройки) и таз — над скамьёй
			var wrong := 0
			for s: Dictionary in seats:
				var yaw := float(s["yaw"])
				if cos(yaw) > -0.05:
					wrong += 1
			check(wrong == 0, "%s: все места лицом к сцене (не так: %d)" % [t, wrong])
		else:
			var wet := 0
			for s: Dictionary in seats:
				if (s["root"] as Vector3).y < 0.0:
					wet += 1
			check(wet == seats.size(), "термы: все купальщики по грудь в воде (%d из %d)" % [wet, seats.size()])


func _cam_for(b: Dictionary, v: Array, tb: Array) -> void:
	var f2 := City.facing(float(b["yaw"]))
	var fyd := rad_to_deg(atan2(f2.x, f2.y))
	var ctr := Vector2((float(tb[0]) + float(tb[1])) * 0.5, (float(tb[2]) + float(tb[3])) * 0.5)
	var tp := ctr
	var ty: float = game.land.height_at(ctr.x, ctr.y) + 1.5
	if int(v[3]) == 1:
		var dp := c.door_point(b)
		tp = dp.lerp(ctr, 0.38)
		ty = float(b["y"]) + 1.2
	elif int(v[3]) == 2:
		# середина рядов театра или одеона (на 2 м перед орхестрой, на высоте средних рядов)
		var d: Dictionary = NewCivic._theatre_dims(Vector2.ZERO) if b["type"] == "theatre" else NewCivic._odeon_dims(Vector2.ZERO)
		var w := c.xf(b) * Vector3(0, 0, (d["c"] as Vector3).z + float(v[4]))
		tp = Vector2(w.x, w.z)
		ty = float(b["y"]) + 0.9
	game.rig.set_view(Vector3(tp.x, ty, tp.y), fyd + float(v[0]), float(v[1]), float(v[2]))


## Лист: четыре стороны, вход вблизи (двери распахнуты), сверху — в два часа
func _sheet(b: Dictionary) -> void:
	var tb := bounds(b)
	var t := String(b["type"])
	var sz := maxf(float(tb[1]) - float(tb[0]), float(tb[3]) - float(tb[2]))
	var k := maxf(1.0, sz / 9.0)
	var views := [[28.0, 30.0, 19.0 * k, 0], [90.0, 26.0, 18.0 * k, 0], [200.0, 32.0, 19.0 * k, 0], [-90.0, 26.0, 18.0 * k, 0],
		[8.0, 16.0, 7.0 * k, 1], [-30.0, 52.0, 24.0 * k, 0]]
	for h: float in hours:
		game._set_hour(h)
		await frames(20)
		for i in views.size():
			if not vsel.is_empty() and not vsel.has(i):
				continue
			var v: Array = views[i]
			_cam_for(b, v, tb)
			await frames(3)
			if int(v[3]) == 1 and not (game.life.info(c.blueprint(b), t)["doors"] as Array).is_empty():
				game.life.door(b, 600.0)
				game.speed = 1.0
				await secs(0.6)
				game.speed = 0.0
			await secs(0.6)
			await frames(30)
			get_viewport().get_texture().get_image().save_png(out + "%s_%s_v%d_h%s.png" % [t, tagn, i, str(h).replace(".", "_")])
			print("NC shot %s %s v%d h%s: вызовов %d, треугольников %d" % [t, tagn, i, h, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])


## Представление: театр и одеон — зрители на скамьях, актёр на сцене; термы — купальщики. Сначала — сбор (люди идут
## с улицы через арку и проход), потом — полный зал
func _show(b: Dictionary) -> void:
	var t := String(b["type"])
	var sp: Spectacle = game.spectacle
	var V: Dictionary = sp.venues.get(int(b["id"]), {})
	if not check(not V.is_empty(), "%s: площадка зрелища заведена" % t):
		return
	var tb := bounds(b)
	var sz := maxf(float(tb[1]) - float(tb[0]), float(tb[3]) - float(tb[2]))
	var k := maxf(1.0, sz / 9.0)
	game._set_hour(17.6 if t != "thermae" else 15.0)
	await frames(10)
	# сбор: идут с улицы
	sp.force(int(b["id"]), "gather", 0.9)
	game.speed = 3.0
	await secs(6.0)
	game.speed = 0.0
	var walking := (V["who"] as Array).filter(func(s): return s["st"] == "walk").size()
	print("NC SHOW %s сбор: на местах %d, идут %d" % [t, (V["who"] as Array).filter(func(s): return s["st"] == "sit").size(), walking])
	_cam_for(b, [16.0, 34.0, 15.0 * k, 0], tb)
	await secs(0.5)
	await frames(20)
	get_viewport().get_texture().get_image().save_png(out + "%s_show_gather.png" % t)
	# полный зал
	sp.force(int(b["id"]), "show", 1.0, true)
	game.speed = 1.0
	await secs(2.0)
	game.speed = 0.0
	var who: Array = V["who"]
	var lay: Dictionary = V["lay"]
	check(who.size() >= int((lay["seats"] as Array).size() * 0.9), "%s: зал полон — %d из %d" % [t, who.size(), (lay["seats"] as Array).size()])
	# сверху из-за сцены (лица зрителей), спереди, «глазами актёра» со сцены, сбоку вблизи (таз на скамье, ступни ниже)
	var views := [[180.0, 64.0, 12.0 * k, 2, 1.8], [20.0, 40.0, 15.0 * k, 0], [180.0, 17.0, 2.5, 2, 1.9], [125.0, 38.0, 4.6, 2, 2.3], [-35.0, 22.0, 9.0 * k, 0]]
	if t == "thermae":
		views = [[12.0, 40.0, 15.0 * k, 0], [-28.0, 22.0, 9.0 * k, 0], [0.0, 18.0, 6.5 * k, 1]]
	for i in views.size():
		_cam_for(b, views[i], tb)
		await secs(0.4)
		await frames(30)
		get_viewport().get_texture().get_image().save_png(out + "%s_show_v%d.png" % [t, i])
	print("NC SHOW %s: мест %d, зрителей %d, актёр %s" % [t, (lay["seats"] as Array).size(), who.size(), str(lay.get("priest", {}).get("root", "—"))])


## Город владельца: снимки видов viewsc= (x:z:yaw:pitch:dist), сведения о постройках этих типов; place= — новые постройки
## (тип:x:z — первое место рядом, куда игра даёт поставить)
func _owner_city() -> void:
	if game.people:
		game.people.visible = false
	var mine := []
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		if String(b["type"]) in NewCivic.TYPES:
			print("NC OWNER %s id=%d pos=%s yaw=%.2f old_lot=%s" % [b["type"], int(id), b["pos"], float(b["yaw"]), str(SizeLadder.old_lot(b))])
			info(b, "владельца")
			mine.append(b)
	var fresh := []
	if A.has("place"):
		for e in str(A["place"]).split(","):
			var f := e.split(":")
			var nb := {}
			var from := Vector2(float(f[1]), float(f[2]))
			for kk in 900:
				var p := from + Vector2(cos(kk * 2.4), sin(kk * 2.4)) * (kk * 0.12)
				var pl: Dictionary = game.placement(f[0], p)
				if pl["err"] == "":
					nb = c.place(f[0], pl["pos"], pl["yaw"], pl["variant"], pl["color"], true)
					game._show(nb)
					break
			if nb.is_empty():
				print("NC NOTE в городе владельца не встало ", f[0])
			else:
				print("NC OWNER new %s pos=%s yaw=%.2f" % [f[0], nb["pos"], float(nb["yaw"])])
				info(nb, "новый в городе")
				fresh.append(nb)
	await frames(60)
	var hh := float(A.get("hour", "15.5"))
	game._set_hour(hh)
	await frames(30)
	var vi := 0
	for v in str(A.get("viewsc", "")).split(","):
		if v == "":
			continue
		var f := v.split(":")
		game.rig.set_view(Vector3(float(f[0]), game.land.height_at(float(f[0]), float(f[1])) + 1.0, float(f[1])), float(f[2]), float(f[3]), float(f[4]))
		await secs(0.6)
		await frames(60)
		get_viewport().get_texture().get_image().save_png(out + "city_%s_v%d.png" % [tagn, vi])
		print("NC shot city %s v%d" % [tagn, vi])
		vi += 1
	# каждая постройка этих типов — спереди-сбоку и сверху, в её осях (одинаково «до» и «после»)
	for e: Array in [[mine, "own"], [fresh, "placed"]]:
		for b: Dictionary in e[0]:
			var tb := bounds(b)
			for vv: Array in [[24.0, 36.0, 21.0, 0], [-20.0, 55.0, 30.0, 0]]:
				_cam_for(b, vv, tb)
				await secs(0.6)
				await frames(60)
				var nm := "city_%s_%s_%s%d_%s.png" % [tagn, e[1], b["type"], int(b["id"]), "a" if float(vv[1]) < 50.0 else "b"]
				get_viewport().get_texture().get_image().save_png(out + nm)
				print("NC shot ", nm)
