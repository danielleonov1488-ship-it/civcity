extends Node
## Новые почтовая станция, бани, гостиница и дом префекта (NewCivic2): снимки для владельца и проверки.
##   bash .work/py/gpu_run.sh res://test_new_civic2.tscn -- out=D:/CivCity/.work/rebuild/b3/<папка>/ [types=center,baths,mansio,prefect]
##        [newciv2=0 — прежние] [fit=1 — как из старого сохранения (на прежних клетках)] [hours=11,18.5] [views=0,1,4]
##        [tiers=0,3,5,7 — уровни станции] [show=1 — купальщики в банях] [cart=1 — повозка с семьями приезжает к станции]
##        [city=путь — город владельца: viewsc=x:z:yaw:pitch:dist,…] [place=тип:x:z,… — новые постройки в городе владельца]
## Снимки: <out>/<тип>[_t<уровень>]_<метка>_v<вид>_h<час>.png (метка — new, fit или old); строки «NC2 …», в конце «NC2 DONE fails=N».

var game
var c: City
var out := "D:/CivCity/.work/rebuild/b3/t/"
var hours := [11.0]
var types := ["center", "baths", "mansio", "prefect"]
var tiers := [0, 3, 5, 7]
var fit := false
var show := false
var cart := false
var city_src := ""
var vsel := []
var tagn := "new"
var fails := 0
var A := {}


func check(ok: bool, what: String) -> bool:
	print(("NC2 PASS " if ok else "NC2 FAIL ") + what)
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
			"newciv2":
				NewCivic2.ON = {} if kv[1] == "0" else {"center": true, "baths": true, "mansio": true, "prefect": true}
			"hours":
				hours = []
				for h in kv[1].split(","):
					hours.append(float(h))
			"types": types = Array(kv[1].split(","))
			"tiers":
				tiers = []
				for t in kv[1].split(","):
					tiers.append(int(t))
			"fit": fit = kv[1] != "0"
			"show": show = kv[1] != "0"
			"cart": cart = kv[1] != "0"
			"city": city_src = kv[1]
			"views":
				for v in kv[1].split(","):
					vsel.append(int(v))
	tagn = ("fit" if fit else "new") if not NewCivic2.ON.is_empty() else "old"
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
	print("NC2 NOTE не встало ", type, " у ", at)
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


## Размеры и «цена» постройки: след, площадь, верх (и верх кровли — без флажков и знамён), деталей, треугольников,
## групп пула, огней
func info(b: Dictionary, what := "") -> Dictionary:
	var bp := c.blueprint(b)
	var lot := Rect2()
	var first := true
	for r: Rect2 in bp.footprint():
		lot = r if first else lot.merge(r)
		first = false
	var top := 0.0
	var roof := 0.0
	var tri := 0
	var groups := {}
	for p: Array in bp.parts:
		var nm := String(p[0])
		var bx: AABB = (p[1] as Transform3D) * Bp.model_aabb(nm)
		if not nm.begins_with("#"):
			top = maxf(top, bx.end.y)
			if not (nm.contains("Banner") or nm.contains("Senser") or nm.contains("Pergola") or nm.contains("Pillar_06") or nm.contains("Plinth_02") or nm.contains("Statue")):
				roof = maxf(roof, bx.end.y)
		tri += tris_of(nm)
		groups[nm + "|" + str(p[2])] = true
	var seats := -1
	if game.spectacle and Spectacle.is_venue(String(b["type"])):
		seats = (game.spectacle.layout(b)["seats"] as Array).size()
	var res := {"w": lot.size.x, "d": lot.size.y, "x0": lot.position.x, "x1": lot.end.x, "z0": lot.position.y, "z1": lot.end.y,
		"area": lot.size.x * lot.size.y, "top": top, "roof": roof, "parts": bp.parts.size(), "tris": tri, "groups": groups.size(), "lights": bp.lights.size(), "seats": seats}
	print("NC2 INFO %s t%d %s %s: след %.2f × %.2f м = %.1f м² (%.1f дома) [x %.2f…%.2f z %.2f…%.2f], верх %.2f м (кровля %.2f), деталей %d, треугольников %d, групп %d, огней %d, мест %d, sz=%s, door=%s" % [
		b["type"], int(b.get("tier", 0)), tagn, what, lot.size.x, lot.size.y, res["area"], float(res["area"]) / SizeLadder.HOUSE, lot.position.x, lot.end.x,
		lot.position.y, lot.end.y, top, roof, bp.parts.size(), tri, groups.size(), bp.lights.size(), seats, str(b.get("sz", "—")), bp.door])
	return res


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(10)
	c = game.city
	game.can_save = false
	for r in Defs.RESEARCH:
		c.research[r["id"]] = true
	c.money = 900000
	game.hud.visible = false
	if game.weather:
		game.weather.left_h = 0.0
		game.weather.force = 0.0
	DirAccess.make_dir_recursive_absolute(out)
	if city_src != "":
		c.level = maxi(c.level, 0)
		game.speed = 0.0
		await _owner_city()
		print("NC2 DONE fails=%d" % fails)
		get_tree().quit()
		return
	if cart:
		await _cart_check()
		print("NC2 DONE fails=%d" % fails)
		get_tree().quit()
		return
	if A.get("grow", "0") == "1":
		await _grow_check()
		print("NC2 DONE fails=%d" % fails)
		get_tree().quit()
		return
	c.level = 7
	game.speed = 0.0
	if game.people and not show:
		game.people.visible = false
	var X0 := 150.0
	var Z0 := 124.0
	game.clear_nature(Vector2(X0 + 10.0, Z0), 48.0)
	game.land.paint_line(Vector2(X0 - 40.0, Z0), Vector2(X0 + 60.0, Z0), 2.2, Land.Kind.ROAD, true)
	await frames(4)
	var x := X0 - 36.0
	var built := []
	for t: String in types:
		var r: Array = NewCivic2.FULL[t]
		var w := float(r[1]) - float(r[0])
		var b := put(t, Vector2(x + w * 0.5 + 1.0, Z0 - 6.0))
		if b.is_empty():
			check(false, "встало: " + t)
			continue
		if fit:
			b.erase("sz")                            # как из старого сохранения: облик — под прежние клетки (SizeLadder.old_lot)
			game._hide(b)
			game._show(b)
		var tb := bounds(b)
		x = float(tb[1]) + float(A.get("gap", "9.0"))     # просторно: на видах сбоку соседей не видно
		built.append(b)
	await frames(30)
	for b: Dictionary in built:
		var ts: Array = tiers if b["type"] == "center" else [int(b.get("tier", 0))]
		for tr: int in ts:
			if b["type"] == "center":
				b["tier"] = tr
				game._hide(b)
				game._show(b)
				await frames(10)
			var inf := info(b)
			if not NewCivic2.ON.is_empty():
				_checks(b, inf)
			if show:
				continue
			await _sheet(b)
	if show:
		for b: Dictionary in built:
			if Spectacle.is_venue(String(b["type"])):
				await _show(b)
	print("NC2 DONE fails=%d" % fails)
	get_tree().quit()


## Проверки новой сборки: размер по линейке, высота, без прежнего наполнения, своё основание, двери и ставни (Life),
## купальщики в бассейнах
func _checks(b: Dictionary, inf: Dictionary) -> void:
	var t := String(b["type"])
	var tr := int(b.get("tier", 0))
	var want := {"center": 62.0, "baths": 68.0, "mansio": 36.0, "prefect": 36.0}
	var a := float(inf["area"])
	var o: Array = NewCivic2.OLD_RECT[t]
	if fit and t != "center":
		var ow := float(o[1]) - float(o[0]) + 0.05
		var od := float(o[3]) - float(o[2]) + 0.05
		check(float(inf["w"]) <= ow and float(inf["d"]) <= od, "%s на прежних клетках: %.2f × %.2f ≤ %.2f × %.2f" % [t, inf["w"], inf["d"], ow, od])
		check(float(inf["x0"]) >= float(o[0]) - 0.05 and float(inf["x1"]) <= float(o[1]) + 0.05 and float(inf["z0"]) >= float(o[2]) - 0.05 and float(inf["z1"]) <= float(o[3]) + 0.05,
			"%s внутри прежнего следа [x %.2f…%.2f z %.2f…%.2f]" % [t, o[0], o[1], o[2], o[3]])
	else:
		check(absf(a - float(want[t])) < 4.5, "%s по линейке: %.1f м² (≈ %.0f)" % [t, a, want[t]])
	var cap := {"center": 6.5, "baths": 6.0, "mansio": 6.0, "prefect": 6.0}
	check(float(inf["roof"]) <= float(cap[t]) + 0.05, "%s: кровля %.2f м ≤ %.1f м (верх с флажком %.2f)" % [t, inf["roof"], cap[t], inf["top"]])
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
	check(not (li["doors"] as Array).is_empty(), "%s t%d: створки входа найдены (Life, %d)" % [t, tr, (li["doors"] as Array).size()])
	if t != "baths" and (t != "center" or tr >= 2):
		check(int(li["pairs"]) >= 2, "%s t%d: ставни створками (%d пар)" % [t, tr, int(li["pairs"])])
	if game.spectacle and Spectacle.is_venue(t):
		var lay: Dictionary = game.spectacle.layout(b)
		var seats: Array = lay["seats"]
		check(seats.size() >= 18, "%s: купальщиков %d (≥ 18)" % [t, seats.size()])
		var wet := 0
		for s: Dictionary in seats:
			if (s["root"] as Vector3).y < 0.0:
				wet += 1
		check(wet == seats.size(), "%s: все купальщики по грудь в воде (%d из %d)" % [t, wet, seats.size()])
	var pets := NewCivic2.pets(b)
	if t in ["center", "mansio"]:
		check(not pets.is_empty(), "%s t%d: лошадь у конюшни (%d)" % [t, tr, pets.size()])


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
	game.rig.set_view(Vector3(tp.x, ty, tp.y), fyd + float(v[0]), float(v[1]), float(v[2]))


## Лист: четыре стороны, вход вблизи (двери распахнуты), сверху
func _sheet(b: Dictionary) -> void:
	var tb := bounds(b)
	var t := String(b["type"])
	var nm0 := t if t != "center" else "%s_t%d" % [t, int(b["tier"])]
	var sz := maxf(float(tb[1]) - float(tb[0]), float(tb[3]) - float(tb[2]))
	var k := maxf(1.0, sz / 9.0)
	var views := [[28.0, 30.0, 17.0 * k, 0], [90.0, 26.0, 16.0 * k, 0], [200.0, 32.0, 17.0 * k, 0], [-90.0, 26.0, 16.0 * k, 0],
		[8.0, 16.0, 6.5 * k, 1], [-30.0, 62.0, 22.0 * k, 0]]
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
			get_viewport().get_texture().get_image().save_png(out + "%s_%s_v%d_h%s.png" % [nm0, tagn, i, str(h).replace(".", "_")])
			print("NC2 shot %s %s v%d h%s: вызовов %d, треугольников %d" % [nm0, tagn, i, h, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])


## Купальщики в банях: сбор (идут с улицы через пропилей), потом полные бассейны
func _show(b: Dictionary) -> void:
	var t := String(b["type"])
	var sp: Spectacle = game.spectacle
	var V: Dictionary = sp.venues.get(int(b["id"]), {})
	if not check(not V.is_empty(), "%s: площадка зрелища заведена" % t):
		return
	var tb := bounds(b)
	var sz := maxf(float(tb[1]) - float(tb[0]), float(tb[3]) - float(tb[2]))
	var k := maxf(1.0, sz / 9.0)
	game._set_hour(15.0)
	await frames(10)
	sp.force(int(b["id"]), "gather", 0.9)
	game.speed = 3.0
	await secs(6.0)
	game.speed = 0.0
	print("NC2 SHOW %s сбор: в воде %d, идут %d" % [t, (V["who"] as Array).filter(func(s): return s["st"] == "sit").size(), (V["who"] as Array).filter(func(s): return s["st"] == "walk").size()])
	_cam_for(b, [16.0, 34.0, 14.0 * k, 0], tb)
	await secs(0.5)
	await frames(20)
	get_viewport().get_texture().get_image().save_png(out + "%s_show_gather.png" % t)
	sp.force(int(b["id"]), "show", 1.0, true)
	game.speed = 1.0
	await secs(2.0)
	game.speed = 0.0
	var who: Array = V["who"]
	var lay: Dictionary = V["lay"]
	check(who.size() >= int((lay["seats"] as Array).size() * 0.9), "%s: бассейны полны — %d из %d" % [t, who.size(), (lay["seats"] as Array).size()])
	var views := [[12.0, 40.0, 13.0 * k, 0], [-28.0, 22.0, 8.0 * k, 0], [0.0, 18.0, 5.5 * k, 1]]
	for i in views.size():
		_cam_for(b, views[i], tb)
		await secs(0.4)
		await frames(30)
		get_viewport().get_texture().get_image().save_png(out + "%s_show_v%d.png" % [t, i])


## Повозка с семьями приезжает к станции: дома рядом, ускоренное время — снимки, пока повозка стоит у станции
## и семьи сходят на площадь; проверка — повозка доехала до площади перед входом станции
func _cart_check() -> void:
	var lv := int(A.get("level", "5"))
	c.level = lv
	var st := c.center()
	if not check(not st.is_empty(), "станция есть"):
		return
	st["tier"] = lv
	game._hide(st)
	game._show(st)
	c.money = 60000
	var dp := c.door_point(st)
	var f := City.facing(float(st["yaw"]))
	print("NC2 CART станция pos=%s yaw=%.2f вход %s уровень %d" % [st["pos"], float(st["yaw"]), dp, lv])
	info(st, "станция")
	# дорога от входа вперёд и дома вдоль неё (как test_arrive)
	var a := dp + f * 3.0
	var e2 := dp + f * 40.0
	game.land.paint_line(a, e2, 1.3, Land.Kind.ROAD, true)
	game.people.refresh(game.land.road_chunks.keys())
	var ax := City.axis(float(st["yaw"]))
	var n := 0
	for kk in range(6, 40, 2):
		for side: float in [-4.0, 4.0]:
			if n >= 4:
				break
			var q: Vector2 = dp + f * float(kk) + ax * side
			var pl: Dictionary = game.placement("house_pleb", q)
			if pl["err"] == "":
				c.place("house_pleb", pl["pos"], pl["yaw"], pl["variant"], pl["color"])
				n += 1
	print("NC2 CART домов ", n)
	var cam_at := Vector3(dp.x, float(st["y"]) + 1.0, dp.y)
	var fyd := rad_to_deg(atan2(f.x, f.y))
	game.rig.set_view(cam_at, fyd + 25.0, 40.0, 26.0)
	game.speed = 4.0
	var t := 0
	var saw_in := false
	var shots := 0
	while t < 6000:
		await frames(10)
		t += 10
		var cs: String = game.people.cart["state"]
		if cs == "in":
			saw_in = true
			var cn: Node3D = game.people.cart["n"]
			var cp := Vector2(cn.position.x, cn.position.z)
			if cp.distance_to(dp) < 9.0 and shots == 0:
				game.speed = 0.0
				await frames(20)
				get_viewport().get_texture().get_image().save_png(out + "cart_arriving.png")
				print("NC2 CART shot прибывает: повозка %s, до входа %.1f м" % [cp, cp.distance_to(dp)])
				shots = 1
				game.speed = 2.0
		elif cs == "unload" and shots < 3:
			game.speed = 0.0
			var cn2: Node3D = game.people.cart["n"]
			var cp2 := Vector2(cn2.position.x, cn2.position.z)
			check(cp2.distance_to(dp) < 6.0, "повозка остановилась у входа станции: %.1f м" % cp2.distance_to(dp))
			await frames(30)
			get_viewport().get_texture().get_image().save_png(out + "cart_unload_a.png")
			game.rig.set_view(Vector3(cp2.x, float(st["y"]) + 1.0, cp2.y), fyd - 35.0, 28.0, 14.0)
			await secs(0.5)
			await frames(30)
			get_viewport().get_texture().get_image().save_png(out + "cart_unload_b.png")
			game.speed = 1.0
			await secs(2.5)
			game.speed = 0.0
			game.rig.set_view(cam_at, fyd + 10.0, 46.0, 22.0)
			await secs(0.4)
			await frames(30)
			get_viewport().get_texture().get_image().save_png(out + "cart_families.png")
			print("NC2 CART семьи на площади: ждут %d, прибыло %d" % [c.waiting, c.arrivals.size()])
			shots = 3
			break
	check(saw_in, "повозка выехала к станции")
	check(shots == 3, "повозка доехала и разгрузилась")


## Город владельца: снимки видов viewsc= (x:z:yaw:pitch:dist), сведения о постройках этих типов; place= — новые постройки
## (тип:x:z — первое место рядом, куда игра даёт поставить)
func _owner_city() -> void:
	if game.people:
		game.people.visible = false
	var mine := []
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		if String(b["type"]) in NewCivic2.TYPES:
			print("NC2 OWNER %s id=%d pos=%s yaw=%.2f tier=%d old_lot=%s" % [b["type"], int(id), b["pos"], float(b["yaw"]), int(b.get("tier", 0)), str(SizeLadder.old_lot(b))])
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
				print("NC2 NOTE в городе владельца не встало ", f[0])
			else:
				print("NC2 OWNER new %s pos=%s yaw=%.2f" % [f[0], nb["pos"], float(nb["yaw"])])
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
		print("NC2 shot city %s v%d" % [tagn, vi])
		vi += 1
	for e: Array in [[mine, "own"], [fresh, "placed"]]:
		for b: Dictionary in e[0]:
			var tb := bounds(b)
			for vv: Array in [[24.0, 36.0, 19.0, 0], [-20.0, 55.0, 26.0, 0]]:
				_cam_for(b, vv, tb)
				await secs(0.6)
				await frames(60)
				var nm := "city_%s_%s_%s%d_%s.png" % [tagn, e[1], b["type"], int(b["id"]), "a" if float(vv[1]) < 50.0 else "b"]
				get_viewport().get_texture().get_image().save_png(out + nm)
				print("NC2 shot ", nm)


## Старое сохранение: гостиница и дом префекта на прежних клетках (без «sz») растут в полный размер, где есть место
## (City.ladder_grow); стиснутые соседями — остаются в облике старого места; бани (стали меньше) не растут
func _grow_check() -> void:
	c.level = 7
	game.speed = 0.0
	var X0 := 150.0
	var Z0 := 124.0
	game.clear_nature(Vector2(X0 + 10.0, Z0), 48.0)
	game.land.paint_line(Vector2(X0 - 40.0, Z0), Vector2(X0 + 60.0, Z0), 2.2, Land.Kind.ROAD, true)
	await frames(4)
	var cases := []
	var x := X0 - 30.0
	for t: String in ["mansio", "prefect", "baths"]:
		var b := put(t, Vector2(x, Z0 - 6.0))
		if b.is_empty():
			check(false, "встало: " + t)
			continue
		b.erase("sz")
		_old_cells(b)
		var n0 := (b["cells"] as PackedInt32Array).size()
		cases.append([b, n0, true])
		x += 16.0
	# стиснутая гостиница: вплотную дома по бокам и сзади — расти некуда
	var tight := put("mansio", Vector2(x + 4.0, Z0 - 6.0))
	if not tight.is_empty():
		tight.erase("sz")
		_old_cells(tight)
		game._hide(tight)
		game._show(tight)
		var tb := bounds(tight)
		for q: Vector2 in [Vector2(float(tb[0]) - 1.6, (float(tb[2]) + float(tb[3])) * 0.5), Vector2(float(tb[1]) + 1.6, (float(tb[2]) + float(tb[3])) * 0.5),
				Vector2((float(tb[0]) + float(tb[1])) * 0.5, float(tb[2]) - 2.2)]:
			var hb := put("house_pleb", q, 40, 0.2)
			if hb.is_empty():
				print("NC2 NOTE дом-сосед не встал у ", q)
		cases.append([tight, (tight["cells"] as PackedInt32Array).size(), false])
	for e: Array in cases:
		var b: Dictionary = e[0]
		game._hide(b)
		game._show(b)
		print("NC2 GROW до: %s id=%d old_lot=%s клеток %d" % [b["type"], int(b["id"]), str(SizeLadder.old_lot(b)), (b["cells"] as PackedInt32Array).size()])
	c.ladder_grow()
	await frames(10)
	for e: Array in cases:
		var b: Dictionary = e[0]
		var t := String(b["type"])
		game._hide(b)
		game._show(b)
		var grown := not SizeLadder.old_lot(b)
		info(b, "после роста" if grown else "на прежних клетках")
		if t == "baths":
			check(not grown, "бани старого сохранения не растут (стали меньше): облик посреди прежнего следа")
		elif bool(e[2]):
			check(grown, "%s старого сохранения выросла в полный размер, где есть место (клеток %d → %d)" % [t, int(e[1]), (b["cells"] as PackedInt32Array).size()])
		else:
			check(not grown, "%s, стиснутая соседями, осталась в облике старого места" % t)
	await frames(30)
	game._set_hour(11.0)
	await frames(10)
	for e: Array in cases:
		var b: Dictionary = e[0]
		var tb := bounds(b)
		_cam_for(b, [28.0, 34.0, 16.0, 0], tb)
		await secs(0.5)
		await frames(30)
		get_viewport().get_texture().get_image().save_png(out + "grow_%s%d_%s.png" % [b["type"], int(b["id"]), "full" if not SizeLadder.old_lot(b) else "fit"])


## Как из старого сохранения: постройка занимает клетки прежнего следа (облик старого места), а не полного
func _old_cells(b: Dictionary) -> void:
	var id := int(b["id"])
	for k in (b["cells"] as PackedInt32Array):
		if game.land.occ[k] == id:
			game.land.occ[k] = 0
	var oc: PackedInt32Array = game.land.footprint_cells(c.blueprint(b).occ_footprint(), b["pos"], float(b["yaw"]))
	for k in oc:
		game.land.occ[k] = id
	b["cells"] = oc
