extends Node
## Пробная улица на Synty (владелец 12.11: «всё на Synty, пересобрать… покажи пробную улицу»): дома в два-три этажа,
## лавки, прилавки, украшения — снимки при дневном и вечернем свете для сравнения с картинками Synty.
##   bash .work/py/gpu_run.sh res://test_street_synty.tscn -- out=D:/CivCity/.work/street_synty/ tag=a

var game
var c: City
var out := "D:/CivCity/.work/street_synty/"
var tag := "a"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv[0] == "out":
			out = kv[1]
		elif kv[0] == "tag":
			tag = kv[1]
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
	game.clear_nature(Vector2(X0 + 20.0, Z0), 34.0)
	game.land.paint_line(Vector2(X0 - 8.0, Z0), Vector2(X0 + 48.0, Z0), 2.2, Land.Kind.ROAD, true)
	await frames(4)
	# северная сторона: дома и лавки вплотную, южная — дома, прилавки и маленькая площадь с фонтанчиком
	# дома вплотную друг к другу, как улица на картинках Synty (каждый следующий — к краю предыдущего, игра сама
	# ставит его в ряд)
	var north := [["house_pleb", 2], ["bakery", 0], ["house_artisan", 2], ["house_pleb", 3], ["wineshop", 0], ["house_artisan", 3], ["butcher", 0],
		["house_pleb", 2], ["house_artisan", 2], ["house_pleb", 3], ["perfumer", 0], ["house_pleb", 2]]
	var x := X0
	for e: Array in north:
		var b := put(e[0], Vector2(x, Z0 - 2.6), int(e[1]))
		x = _right_edge(b, x) + 0.05
	var south := [["house_artisan", 2], ["house_pleb", 2], ["taberna", 0], ["house_pleb", 3], ["house_artisan", 2], ["house_pleb", 2],
		["house_patrician", 2], ["house_pleb", 3]]
	x = X0 + 1.0
	for e: Array in south:
		var b := put(e[0], Vector2(x, Z0 + 2.6), int(e[1]))
		x = _right_edge(b, x) + 0.05
	# украшения улицы
	for k in 9:                                # клумбы, вазоны, кипарисы и фонари вдоль домов
		put(["planter", "flowers", "lamp_post", "planter_2", "flowers_2", "planter", "lamp_post_2", "flowers", "planter_2"][k], Vector2(X0 + 2.0 + k * 4.4, Z0 - 1.25))
	for k in 6:
		put(["flowers_2", "planter", "lamp_post", "flowers", "planter_2", "palm"][k], Vector2(X0 + 3.0 + k * 5.5, Z0 + 1.25))
	await frames(30)
	var views := [[Vector2(X0 + 12.0, Z0 - 2.0), 20.0, 48.0, 10.0], [Vector2(X0 + 26.0, Z0 - 2.0), 35.0, 42.0, 9.0], [Vector2(X0 + 16.0, Z0 + 2.0), 200.0, 48.0, 10.0],
		[Vector2(X0 + 18.0, Z0), 95.0, 34.0, 20.0], [Vector2(X0 + 18.0, Z0), 90.0, 13.0, 9.0], [Vector2(X0 + 16.0, Z0), 270.0, 13.0, 9.0]]
	DirAccess.make_dir_recursive_absolute(out)
	for h: float in [11.0, 17.6]:
		game._set_hour(h)
		await frames(20)
		for i in views.size():
			var v: Array = views[i]
			var p: Vector2 = v[0]
			game.rig.set_view(Vector3(p.x, Land.BASE_Y, p.y), float(v[1]), float(v[2]), float(v[3]))
			await frames(60)
			get_viewport().get_texture().get_image().save_png(out + "%s_v%d_h%d.png" % [tag, i, int(h)])
	print("STS DONE")
	get_tree().quit()
