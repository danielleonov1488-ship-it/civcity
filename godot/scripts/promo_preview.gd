extends Node
## Короткий облёт улицы на Synty для поста о разработке (владелец 12.11: «гифку… в ТГК»): десяток домов и лавок,
## камера медленно облетает улицу в вечернем свете; кадры PNG → ffmpeg в .mp4 и .gif.
##   bash .work/py/gpu_run.sh res://promo_preview.tscn -- out=D:/CivCity/.work/promo_tg/frames secs=8 fps=30

var game
var c: City
var out := "D:/CivCity/.work/promo_tg/frames"
var secs := 8.0
var fps := 30


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		match kv[0]:
			"out": out = kv[1]
			"secs": secs = float(kv[1])
			"fps": fps = int(kv[1])
	Game.boot = {"new": "1", "hour": "16.5"}
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
	if game.weather:
		game.weather.left_h = 0.0
		game.weather.force = 0.0
	var X0 := 140.0
	var Z0 := 120.0
	game.clear_nature(Vector2(X0 + 10.0, Z0), 24.0)
	game.land.paint_line(Vector2(X0 - 8.0, Z0), Vector2(X0 + 30.0, Z0), 2.2, Land.Kind.ROAD, true)
	await frames(4)
	var north := [["house_pleb", 2], ["bakery", 0], ["house_artisan", 3], ["wineshop", 0], ["house_pleb", 3], ["butcher", 0]]
	var x := X0
	for e: Array in north:
		var b := put(e[0], Vector2(x, Z0 - 2.6), int(e[1]))
		x = _right_edge(b, x) + 0.05
	var south := [["house_artisan", 2], ["taberna", 0], ["house_pleb", 3], ["house_patrician", 2]]
	x = X0 + 1.0
	for e: Array in south:
		var b := put(e[0], Vector2(x, Z0 + 2.6), int(e[1]))
		x = _right_edge(b, x) + 0.05
	for k in 4:
		put(["planter", "lamp_post", "flowers", "planter_2"][k], Vector2(X0 + 2.0 + k * 5.5, Z0 - 1.25))
	for k in 3:
		put(["flowers_2", "lamp_post", "planter"][k], Vector2(X0 + 4.0 + k * 6.0, Z0 + 1.25))
	game.speed = 0.0
	game._set_hour(16.5)
	await frames(60)
	DirAccess.make_dir_recursive_absolute(out)
	var n := int(secs * fps)
	var ctr := Vector3(X0 + 11.0, Land.BASE_Y, Z0)
	# облёт: от вида вдоль улицы — к виду сверху сбоку, плавно (без рывков в начале и в конце)
	for i in n:
		var t := float(i) / float(n - 1)
		var e := t * t * (3.0 - 2.0 * t)
		var yaw := lerpf(70.0, 112.0, e)
		var pitch := lerpf(12.0, 24.0, e)
		var dist := lerpf(10.0, 14.0, e)
		game.rig.set_view(ctr, yaw, pitch, dist)
		await frames(2 if i > 0 else 30)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out + "/f%04d.png" % i)
	print("PROMO DONE frames=", n)
	get_tree().quit()
