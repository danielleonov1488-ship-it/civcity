extends Node
## Стенд «улица»: настоящая игра с её светом; вдоль дороги в ряд ставятся постройки из списка, рядом люди для масштаба.
## Аргументы (после --): items=тип:этаж:фасад:цвет,…  tag=имя  hour=12.5  [south=тип:…,…]  [views=0,1,2,3]
## Снимки: D:/CivCity/.work/street/<tag>_v<N>.png
var game
var items := []
var south := []
var tag := "street"
var hour := 12.5
var views := [0, 1, 2, 3]

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv.size() == 2:
			match kv[0]:
				"items": items = Array(kv[1].split(","))
				"south": south = Array(kv[1].split(","))
				"tag": tag = kv[1]
				"hour": hour = float(kv[1])
				"views": views = Array(kv[1].split(",")).map(func(x): return int(x))
	Game.boot = {"new": "1", "noui": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func put_row(list: Array, z: float, side: float) -> Array:
	var placed := []
	var x := 168.0
	for it: String in list:
		var p := it.split(":")
		var type: String = p[0]
		var tier := int(p[1]) if p.size() > 1 else 1
		var variant := int(p[2]) if p.size() > 2 else 0
		var color := int(p[3]) if p.size() > 3 else placed.size() % 10
		if not Defs.B.has(type):
			print("UNKNOWN ", type)
			continue
		var ok := false
		for k in 80:
			var q := Vector2(x + k * 0.5, z + side * 4.0)
			var pl: Dictionary = game.placement(type, q, variant, color)
			if pl["err"] == "":
				var b: Dictionary = game.city.place(type, pl["pos"], pl["yaw"], int(pl["variant"]), int(pl["color"]), true)
				if Defs.B[type]["kind"] == "house":
					b["tier"] = tier
					b["pop"] = 1
					game._show(b)
				var bb: Array = game._bounds(game.city.blueprint(b))
				x = float(pl["pos"].x) + float(bb[1]) + 1.0
				placed.append(b)
				ok = true
				break
		if not ok:
			print("FAILED ", it, " err=", game.placement(type, Vector2(x, z + side * 4.0), variant)["err"])
			x += 6.0
	return placed

func _run() -> void:
	while not game.ready_done:
		await frames(5)
	game.hud.visible = false
	game.city.money = 1e7
	for r in Defs.RESEARCH:
		game.city.research[r["id"]] = true
	for q in Defs.REQUESTS:
		if q.has("unlock"):
			game.city.research[q["unlock"]] = true
	game.city.level = Defs.LEVELS.size() - 1
	var z := 140.0
	game.land.paint_line(Vector2(162, z), Vector2(262, z), 1.4, Land.Kind.ROAD, true)
	game.people.refresh(game.land.road_chunks.keys())
	var a := put_row(items, z, -1.0)
	put_row(south, z, 1.0)
	var mx := 168.0
	if not a.is_empty():
		mx = ((a[0]["pos"] as Vector2).x + (a[a.size() - 1]["pos"] as Vector2).x) / 2.0
	# люди для масштаба
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for k in 10:
		var c := Citizen.create(rng, k % 2 == 0, k % 4 == 3)
		game.actors_root.add_child(c)
		var px := mx - 12.0 + k * 2.7
		c.position = Vector3(px, game.land.height_at(px, z + 0.4 * (k % 3) - 0.4), z + 0.4 * (k % 3) - 0.4)
		c.rotation.y = rng.randf() * TAU
		c.play("Idle_Loop" if k % 3 else "Walk_Loop", 0.0)
	game.speed = 0.0
	game.clock_hours = false
	game._set_hour(hour)
	await frames(20)
	for v in views:
		match v:
			0: game.rig.set_view(Vector3(mx, 1.5, z - 3), 15, 34, 22)     # три четверти спереди
			1: game.rig.set_view(Vector3(mx - 6, 1.5, z - 3), 35, 24, 11)  # вблизи
			2: game.rig.set_view(Vector3(mx, 1.5, z - 2), 10, 46, 40)     # как играют в Town to City
			3: game.rig.set_view(Vector3(mx, 1.5, z - 4), 200, 32, 22)    # сзади-сбоку
		await frames(70)
		get_viewport().get_texture().get_image().save_png("D:/CivCity/.work/street/%s_v%d.png" % [tag, v])
	print("street done ", tag)
	get_tree().quit()
