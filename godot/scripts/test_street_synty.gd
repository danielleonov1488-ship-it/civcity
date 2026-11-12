extends Node
## Пробная улица на Synty (владелец 12.11: «всё на Synty, пересобрать… покажи пробную улицу»; «не делай большие пробные
## улицы, а просто десяток домов»): десять домов и лавок по обе стороны короткой улицы, немного украшений — снимки при
## дневном и вечернем свете для сравнения с картинками Synty.
##   bash .work/py/gpu_run.sh res://test_street_synty.tscn -- out=D:/CivCity/.work/street_synty/ tag=a
##   views=street (по умолчанию: четыре вида улицы) | sides (бока и зады домов, крупные планы) | all; hours=11,17.6;
##   before=1 — без наполнения боков и задов (CatDress.sides_on), для снимков «было»
var game
var c: City
var out := "D:/CivCity/.work/street_synty/"
var tag := "a"
var vset := "street"
var ivytest := false
var hours := [11.0, 17.6]


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv[0] == "out":
			out = kv[1]
		elif kv[0] == "tag":
			tag = kv[1]
		elif kv[0] == "views":
			vset = kv[1]
		elif kv[0] == "ivytest":
			ivytest = kv[1] == "1"             # проверка: все плети плюща Synty в ряд (какие в игре темнеют)
		elif kv[0] == "before":
			CatDress.sides_on = kv[1] != "1"       # снимки «было»: без наполнения боков и задов
		elif kv[0] == "hours":
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


func put(type: String, at: Vector2, tier := 0) -> Dictionary:
	for k in 40:
		var p := at + Vector2(cos(k * 2.4), sin(k * 2.4)) * (k * 0.3)
		var pl: Dictionary = game.placement(type, p)
		if pl["err"] == "":
			var b := c.place(type, pl["pos"], pl["yaw"], pl["variant"], pl["color"], true)
			if tier > 0:
				b["tier"] = tier
			print("STS PUT ", type, " tier=", b.get("tier", 1), " variant=", pl["variant"], " color=", pl["color"])
			game._show(b)
			return b
	print("STS NOTE не встало ", type, " у ", at)
	return {}


func _right_edge(b: Dictionary, x: float) -> float:
	if b.is_empty():
		return x + 3.0
	var bp := c.blueprint(b)
	var mx := -1e9
	var xf := c.xf(b)
	for r: Rect2 in bp.footprint():
		for q: Vector2 in [r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y)]:
			mx = maxf(mx, (xf * Vector3(q.x, 0, q.y)).x)
	return mx + 0.02


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(10)
	c = game.city
	for r in Defs.RESEARCH:
		c.research[r["id"]] = true
	c.level = 7
	c.money = 900000
	game.hud.visible = false
	game.speed = 0.0
	if game.weather:
		game.weather.left_h = 0.0                  # без дождя на снимках
		game.weather.force = 0.0
	var X0 := 140.0
	var Z0 := 120.0
	game.clear_nature(Vector2(X0 + 10.0, Z0), 22.0)
	game.land.paint_line(Vector2(X0 - 6.0, Z0), Vector2(X0 + 28.0, Z0), 2.2, Land.Kind.ROAD, true)
	await frames(4)
	# северная сторона: дома и лавки вплотную, южная — дома, прилавки и маленькая площадь с фонтанчиком
	# дома вплотную друг к другу, как улица на картинках Synty (каждый следующий — к краю предыдущего, игра сама
	# ставит его в ряд)
	var north := [["house_pleb", 2], ["bakery", 0], ["house_artisan", 3], ["wineshop", 0], ["house_pleb", 3], ["butcher", 0]]
	var x := X0
	for e: Array in north:
		var b := put(e[0], Vector2(x, Z0 - 2.6), int(e[1]))
		x = _right_edge(b, x) + 0.05
	var xn := x
	var south := [["house_artisan", 2], ["taberna", 0], ["house_pleb", 3], ["house_patrician", 2]]
	x = X0 + 1.0
	for e: Array in south:
		var b := put(e[0], Vector2(x, Z0 + 2.6), int(e[1]))
		x = _right_edge(b, x) + 0.05
	var xs := x
	# украшения улицы
	for k in 4:                                # клумбы, вазоны и фонари вдоль домов
		put(["planter", "lamp_post", "flowers", "planter_2"][k], Vector2(X0 + 2.0 + k * 5.5, Z0 - 1.25))
	for k in 3:
		put(["flowers_2", "lamp_post", "planter"][k], Vector2(X0 + 4.0 + k * 6.0, Z0 + 1.25))
	await frames(30)
	var views := [[Vector2(X0 + 8.0, Z0 - 2.0), 20.0, 40.0, 11.0], [Vector2(X0 + 9.0, Z0 + 2.0), 200.0, 40.0, 11.0],
		[Vector2(X0 + 12.0, Z0), 90.0, 13.0, 9.0], [Vector2(X0 + 6.0, Z0), 270.0, 13.0, 9.0]]
	# бока и зады (камерой ролика: [где камера, куда смотрит], высоты — от земли): задние стены северного ряда
	# (смотрим с севера) и южного (с юга), торцы рядов, крупные планы задних стен
	var sides := [[Vector3(X0 + 9.0, 6.0, Z0 - 15.0), Vector3(X0 + 9.0, 1.4, Z0 - 4.5)],
		[Vector3(X0 + 9.0, 6.0, Z0 + 15.0), Vector3(X0 + 9.0, 1.4, Z0 + 4.5)],
		[Vector3(X0 - 7.5, 2.6, Z0 + 0.5), Vector3(X0 - 1.3, 1.7, Z0 - 3.2)],
		[Vector3(xn + 6.5, 2.6, Z0 + 0.5), Vector3(xn, 1.6, Z0 - 3.0)],
		[Vector3(X0 - 6.0, 2.6, Z0 - 0.5), Vector3(X0, 1.7, Z0 + 3.2)],
		[Vector3(xs + 6.5, 2.6, Z0 - 0.5), Vector3(xs, 1.6, Z0 + 3.2)],
		[Vector3(X0 + 2.0, 3.4, Z0 - 13.5), Vector3(X0 + 3.5, 2.0, Z0 - 4.8)],
		[Vector3(X0 + 14.0, 3.4, Z0 - 13.5), Vector3(X0 + 12.5, 2.0, Z0 - 4.8)],
		[Vector3(X0 + 4.0, 3.4, Z0 + 13.5), Vector3(X0 + 5.5, 2.0, Z0 + 4.8)],
		[Vector3(X0 + 12.0, 3.4, Z0 + 13.5), Vector3(X0 + 13.5, 2.0, Z0 + 4.8)]]
	if ivytest:
		# плети плюща Synty с цветами лицом на север (как на задних стенах северного ряда): вверху как есть, внизу —
		# отражённые по толщине (листья те же, нормали наоборот); подписи — номер; два снимка (1–7 и 8–13)
		for k in 13:
			var ix: float = X0 + 18.0 + (k % 7) * 3.2
			var iz: float = Z0 - 2.0 - (k / 7) * 8.0
			var y0: float = game.land.height_at(ix, iz)
			var nm := "SM_Env_Ivy_Flowers_%02d" % (k + 1)
			var ab := Bp.model_aabb(nm)
			var sc := minf(1.0, 2.6 / maxf(ab.size.x, ab.size.y))
			for f in 2:
				var bs := Basis(Vector3.UP, PI) * Basis.from_scale(Vector3(sc, sc, sc * (1.0 if f == 0 else -1.0)))
				game.parts.place_one(nm, Transform3D(bs, Vector3(ix, y0 + 4.3 - f * 2.8, iz)))
			var lb := Label3D.new()
			lb.text = str(k + 1)
			lb.font_size = 96
			lb.pixel_size = 0.01
			lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lb.position = Vector3(ix, y0 + 0.3, iz - 0.3)
			add_child(lb)
		sides.append([Vector3(X0 + 27.6, 4.0, Z0 - 13.0), Vector3(X0 + 27.6, 2.8, Z0 - 2.0)])
		sides.append([Vector3(X0 + 26.0, 4.0, Z0 - 21.0), Vector3(X0 + 26.0, 2.8, Z0 - 10.0)])
	# снимки: <tag>_v<n>_h<час>.png — виды улицы, <tag>_s<n>_h<час>.png — бока и зады
	var shots := []
	if vset != "sides":
		for i in views.size():
			shots.append(["v%d" % i, views[i]])
	if vset != "street":
		for i in sides.size():
			shots.append(["s%d" % i, sides[i]])
	DirAccess.make_dir_recursive_absolute(out)
	for h: float in hours:
		game._set_hour(h)
		await frames(20)
		for sh: Array in shots:
			var v: Array = sh[1]
			if v[0] is Vector3:
				var cp: Vector3 = v[0]
				var lk: Vector3 = v[1]
				game.rig.cine = true
				game.rig.cine_look(cp + Vector3(0, game.land.height_at(cp.x, cp.z), 0), lk + Vector3(0, game.land.height_at(lk.x, lk.z), 0))
			else:
				game.rig.cine = false
				var p: Vector2 = v[0]
				game.rig.set_view(Vector3(p.x, Land.BASE_Y, p.y), float(v[1]), float(v[2]), float(v[3]))
			await frames(60)
			get_viewport().get_texture().get_image().save_png(out + "%s_%s_h%d.png" % [tag, String(sh[0]), int(h)])
	print("STS DONE")
	get_tree().quit()
