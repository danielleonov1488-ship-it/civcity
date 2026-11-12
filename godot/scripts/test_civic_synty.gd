extends Node
## Пробная площадка для рабочих и общественных зданий на Synty (владелец 12.11: «склады и подобное пустые, слишком
## пустые места… по бокам ничего»; «не делай большие пробные улицы, а просто десяток домов»): десяток зданий по обе
## стороны короткой улицы с промежутками (видно бока), у каждого — снимки с нескольких сторон и вблизи.
##   bash .work/py/gpu_run.sh res://test_civic_synty.tscn -- out=D:/CivCity/.work/civic_synty/ tag=a [only=warehouse,farm] [street=0] [set=2] [dress=0] [only=street]
## set=2 — второй десяток (библиотека, академия, дом префекта, вигилы, скрипторий, лудус, роща, огород, термы, станция)
## set=mil / mil2 — здания Легиона (mtier=0…5 — облик уровня, Legion.vis_tier); set=grand — амфитеатр, цирк, театр, одеон;
## set=mon — памятники (пантеон, маяк, храм Венеры, арка, фонтан, нимфей, акведук); set=dec / dec2 — украшения;
## station=1 — только почтовая станция на всех уровнях города (stiers=0,3,5,7)

var game
var c: City
var out := "D:/CivCity/.work/civic_synty/"
var tag := "a"
var only := []
var street := true
var hours := [11.0]
var mtier := -1
var station := false
var stiers := [0, 1, 2, 3, 4, 5, 6, 7]
var gap := GAP
var vsel := []                     # views=0,5 — только эти снимки каждого здания
## Северная сторона (фасадом к улице на юг) и южная; между зданиями — промежуток, чтобы видеть бока
var north := ["warehouse", "sculptor", "herbalist", "school", "farm"]
var south := ["balnea", "baths", "temple", "forum", "vineyard"]
const GAP := 4.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"out": out = kv[1]
			"tag": tag = kv[1]
			"only": only = Array(kv[1].split(","))
			"street": street = kv[1] != "0"
			"dress": CatDressCivic.ON = kv[1] != "0"
			"set":
				match kv[1]:
					"2":
						north = ["scriptorium", "vigiles", "library", "prefect", "grove"]
						south = ["ogorod", "academy", "ludus", "thermae"]
					"mil":
						north = ["barracks", "range", "spearcamp", "ballistae", "catapults"]
						south = ["forge", "infirmary", "armory", "principia", "mars"]
					"mil2":
						north = ["smelter", "sawmill", "tannery"]
						south = ["barracks", "forge", "mars"]
					"grand":
						north = ["colosseum", "theatre"]
						south = ["circus_fl", "odeon"]
						gap = 6.0
					"mon":
						north = ["pantheon", "venus", "arch", "fountain"]
						south = ["pharos", "nymphaeum", "temple", "aqua"]
						gap = 5.0
			"list":
				var two := kv[1].split("/")
				north = Array(two[0].split(","))
				south = Array(two[1].split(",")) if two.size() > 1 else []
			"gap": gap = float(kv[1])
			"views":
				for v in kv[1].split(","):
					vsel.append(int(v))
			"mtier": mtier = int(kv[1])
			"station": station = kv[1] != "0"
			"stiers":
				stiers = []
				for t in kv[1].split(","):
					stiers.append(int(t))
			"hours":
				hours = []
				for h in kv[1].split(","):
					hours.append(float(h))
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func put(type: String, at: Vector2) -> Dictionary:
	var err := ""
	for k in 60:
		var p := at + Vector2(cos(k * 2.4), sin(k * 2.4)) * (k * 0.3)
		var pl: Dictionary = game.placement(type, p)
		if pl["err"] == "":
			var b := c.place(type, pl["pos"], pl["yaw"], pl["variant"], pl["color"], true)
			game._show(b)
			return b
		err = pl["err"]
	print("CSY NOTE не встало ", type, " у ", at, " — ", err)
	return {}


## Границы следа в мировых осях: [minx, maxx, minz, maxz]
func _world_bounds(b: Dictionary) -> Array:
	var bp := c.blueprint(b)
	var xf := c.xf(b)
	var r := [INF, -INF, INF, -INF]
	for rc: Rect2 in bp.footprint():
		for q: Vector2 in [rc.position, rc.end, Vector2(rc.position.x, rc.end.y), Vector2(rc.end.x, rc.position.y)]:
			var w := xf * Vector3(q.x, 0, q.y)
			r[0] = minf(r[0], w.x)
			r[1] = maxf(r[1], w.x)
			r[2] = minf(r[2], w.z)
			r[3] = maxf(r[3], w.z)
	return r


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(10)
	c = game.city
	for r in Defs.RESEARCH:
		c.research[r["id"]] = true
	for t: String in north + south:
		if not c.unlocked(t):
			c.gifts[t] = ["Проба", "Проба"]     # здания Легиона за победы над боссами — подарком (только снимки)
	c.level = 7
	c.money = 900000
	c.legion.glory = 99999.0                       # чудеса Легиона (амфитеатр, цирк) — за Славу
	game.hud.visible = false
	game.speed = 0.0
	if game.weather:
		game.weather.left_h = 0.0                  # без дождя на снимках
		game.weather.force = 0.0
	var X0 := 136.0
	var Z0 := 124.0
	if station:
		await _station()
		return
	game.clear_nature(Vector2(X0 + 38.0, Z0), 52.0)
	game.land.paint_line(Vector2(X0 - 8.0, Z0), Vector2(X0 + 86.0, Z0), 2.2, Land.Kind.ROAD, true)
	await frames(4)
	var placed := []
	for side: int in 2:
		var list: Array = north if side == 0 else south
		var x := X0
		for t: String in list:
			var b := put(t, Vector2(x + 4.0, Z0 + (-6.0 if side == 0 else 6.0)))
			if b.is_empty():
				x += 8.0
				continue
			if mtier >= 0 and String(c.def(b)["kind"]) == "military":
				b["tier"] = mtier                  # облик уровня здания Легиона
				game._show(b)
			var wb := _world_bounds(b)
			# если встало не там, где ждали (ушло влево) — следующее ставим правее его края
			x = maxf(x, wb[1]) + gap
			placed.append(b)
	await frames(30)
	DirAccess.make_dir_recursive_absolute(out)
	for h: float in hours:
		game._set_hour(h)
		await frames(20)
		if street and (only.is_empty() or only.has("street")):      # only=street — только общие виды (и замер отрисовки)
			var sd := 42.0 if gap <= GAP else 70.0
			var sv := [[Vector2(X0 + 34.0, Z0), 25.0, 42.0, sd], [Vector2(X0 + 34.0, Z0), 205.0, 42.0, sd]]
			for i in sv.size():
				var v: Array = sv[i]
				var p: Vector2 = v[0]
				game.rig.set_view(Vector3(p.x, Land.BASE_Y, p.y), float(v[1]), float(v[2]), float(v[3]))
				await frames(45)
				get_viewport().get_texture().get_image().save_png(out + "%s_street%d_h%d.png" % [tag, i, int(h)])
				# сколько стоит отрисовка (сравнить dress=0 и dress=1)
				print("CSY PERF вид %d: вызовов %d, треугольников %d, объектов %d" % [i, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
					Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
		for b: Dictionary in placed:
			var t := String(b["type"])
			if not only.is_empty() and not only.has(t):
				continue
			var wb := _world_bounds(b)
			var ctr := Vector2((wb[0] + wb[1]) * 0.5, (wb[2] + wb[3]) * 0.5)
			var rad := maxf(wb[1] - wb[0], wb[3] - wb[2]) * 0.5
			var f := City.facing(float(b["yaw"]))
			var fy := rad_to_deg(atan2(f.x, f.y))
			var ax := City.axis(float(b["yaw"]))
			# [поворот от фасада, наклон, даль (в радиусах), сдвиг цели вдоль фасада, вперёд (в радиусах)]
			var views := [[-38.0, 34.0, 3.4, 0.0, 0.0], [38.0, 34.0, 3.4, 0.0, 0.0], [180.0 + 40.0, 38.0, 3.4, 0.0, 0.0],
				[-90.0, 32.0, 2.8, 0.0, 0.0], [90.0, 32.0, 2.8, 0.0, 0.0],
				[-25.0, 22.0, 1.7, -0.35, 0.2], [25.0, 22.0, 1.7, 0.35, 0.2],
				[-90.0, 30.0, 1.9, -0.55, -0.1], [90.0, 30.0, 1.9, 0.55, -0.1], [180.0, 32.0, 2.0, 0.0, -0.55]]     # ближе: бока и зады
			if rad > 7.0:
				# большие здания — ещё вблизи уголки у фасада (торговцы, цветы, знамёна у входа)
				views.append_array([[-35.0, 28.0, 12.0 / rad, -0.5, 0.8], [35.0, 28.0, 12.0 / rad, 0.5, 0.8]])
			for i in views.size():
				if not vsel.is_empty() and not vsel.has(i):
					continue
				var v: Array = views[i]
				var tp := ctr + ax * float(v[3]) * rad + f * float(v[4]) * rad
				var y: float = game.land.height_at(tp.x, tp.y) + 0.6
				game.rig.set_view(Vector3(tp.x, y, tp.y), fy + float(v[0]), float(v[1]), maxf(5.0, rad * float(v[2])))
				await frames(40)
				get_viewport().get_texture().get_image().save_png(out + "%s_%s_v%d_h%d.png" % [tag, t, i, int(h)])
	print("CSY DONE ", placed.size())
	get_tree().quit()


## Почтовая станция на уровнях stiers: общий вид спереди, с боков, сзади и вблизи (площадь для семей — перед ней)
func _station() -> void:
	var st := c.center()
	if st.is_empty():
		print("CSY NOTE нет станции")
		get_tree().quit()
		return
	DirAccess.make_dir_recursive_absolute(out)
	var p: Vector2 = st["pos"]
	var f := City.facing(float(st["yaw"]))
	var ax := City.axis(float(st["yaw"]))
	var fy := rad_to_deg(atan2(f.x, f.y))
	game._set_hour(hours[0])
	for lvl: int in stiers:
		st["tier"] = lvl
		c.level = lvl
		game._show(st)
		await frames(20)
		var bp := c.blueprint(st)
		print("CSY STATION %d: деталей %d, след %d" % [lvl, bp.parts.size(), bp.footprint().size()])
		var views := [[0.0, 34.0, 17.0, 0.0, 1.5], [-40.0, 30.0, 15.0, 0.0, 1.0], [40.0, 30.0, 15.0, 0.0, 1.0], [-95.0, 30.0, 13.0, 0.0, 0.0],
			[95.0, 30.0, 13.0, 0.0, 0.0], [180.0, 36.0, 15.0, 0.0, 0.0], [-20.0, 20.0, 8.0, -3.0, 2.0], [20.0, 20.0, 8.0, 3.0, 2.0]]
		for i in views.size():
			var v: Array = views[i]
			var tp := p + ax * float(v[3]) + f * float(v[4])
			game.rig.set_view(Vector3(tp.x, game.land.height_at(tp.x, tp.y) + 0.6, tp.y), fy + float(v[0]), float(v[1]), float(v[2]))
			await frames(40)
			get_viewport().get_texture().get_image().save_png(out + "%s_station%d_v%d.png" % [tag, lvl, i])
	print("CSY DONE station")
	get_tree().quit()
