extends Node
## Игровой тест: новый город — улицы, дома, колодцы, поле, рынок; прогон дней; снимки повозки, роста, карточек, храма

var game
var step := 0
var t := 0.0
var out := "D:/CivCity/.work/gd/"
var cart_shot := false

func _ready() -> void:
	var sc: PackedScene = load("res://main.tscn")
	game = sc.instantiate()
	add_child(game)

func shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(out + name)
	var tiers := {}
	for id in game.city.buildings:
		var b = game.city.buildings[id]
		if b["type"] == "house":
			tiers[b["tier"]] = int(tiers.get(b["tier"], 0)) + 1
	print("SHOT ", name, " pop=", game.city.stats["pop"], " money=", int(game.city.money), " day=", game.city.day, " walkers=", game.people.walkers.size(), " queue=", game.city.settle_queue.size(), " tiers=", tiers, " fps=", Engine.get_frames_per_second(), " parts=", game.parts.count())

func try_place(type: String, near: Vector2, r: float) -> bool:
	for k in range(0, int(r * 2) + 1):
		var rr := k * 0.5
		var n := maxi(1, int(rr * 6))
		for a in n:
			var p := near + Vector2(cos(TAU * a / n), sin(TAU * a / n)) * rr
			var pl: Dictionary = game.placement(type, p)
			if pl["err"] == "":
				game.city.place(type, pl["pos"], pl["yaw"])
				print("placed ", type, " at ", pl["pos"])
				return true
	print("FAILED ", type, " near ", near, " err=", game.placement(type, near)["err"])
	return false

func road(a: Vector2, b: Vector2, w := 1.2, kd := Land.Kind.ROAD) -> void:
	game.land.paint_line(a, b, w, kd, true)

func _process(dt: float) -> void:
	t += dt
	if step >= 2 and not cart_shot and game.people.cart.get("state", "") == "in" and float(game.people.cart["s"]) > 9.0:
		cart_shot = true
		var keep: float = game.speed
		game.speed = 0.0
		var n: Node3D = game.people.cart["n"]
		game.rig.set_view(n.position, rad_to_deg(n.rotation.y) + 70, 42, 10)
		await get_tree().create_timer(0.5).timeout
		shot("p_cart.png")
		game.rig.set_view(Vector3(66, 2, 46), 200, 44, 40)
		game.speed = keep
	match step:
		0:
			if t > 1.0:
				game.city.money = 30000
				for px in [3, 4, 5]:
					print("buy ", px, " ", game.city.buy_plot(Vector2i(px, 3)))
				var c: Vector2 = Land.CENTER
				road(c + Vector2(0, 5), Vector2(64, 62))
				road(Vector2(46, 44), Vector2(94, 44))
				road(Vector2(80, 44), Vector2(80, 63))
				road(Vector2(48, 50), Vector2(64, 50), 1.0, Land.Kind.DIRT)
				var top := Defs.RANKS.size() - 1
				game.city.max_rank = top
				game.city.rank = top
				game.land.flatten_obb(Vector2(87, 35.5), Vector2(1, 0), 7.0, 9.0, game.land.height_at(87, 42), Land.Kind.GRASS)
				try_place("temple", Vector2(87, 36), 3)
				game.city.max_rank = 0
				game.city.rank = 0
				try_place("farm", Vector2(86, 58), 3)
				try_place("farm", Vector2(57, 57), 3)
				try_place("market", Vector2(72, 38), 4)
				try_place("well", Vector2(58, 47), 4)
				try_place("well", Vector2(74, 50), 4)
				var n := 0
				for z in range(36, 62):
					for x in range(46, 94):
						var pl: Dictionary = game.placement("house", Vector2(x, z))
						if pl["err"] == "":
							game.city.place("house", pl["pos"], pl["yaw"])
							n += 1
				print("houses ", n)
				game.rig.set_view(Vector3(66, 2, 46), 200, 44, 40)
				game.speed = 6.0
				step = 1
				t = 0.0
		1:
			if t > 2.0:
				shot("p1_built.png")
				step = 2
				t = 0.0
		2:
			if t > 40.0:
				shot("p2_grown.png")
				step = 3
				t = 0.0
		3:
			if t > 40.0:
				shot("p3_grown.png")
				print("GOODS ", game.city.goods, " stats ", game.city.stats)
				var hn := 0
				for id in game.city.buildings:
					var b = game.city.buildings[id]
					if b["type"] != "house":
						print("B ", b["type"], " staff=", b.get("staff"), " active=", b.get("active"), " road=", b["road"])
					elif hn < 4:
						hn += 1
						print("H tier=", b["tier"], " target=", b.get("target"), " up=", b.get("up"), " needs=", b["needs"])
				game.speed = 1.0
				game._set_hour(9.0)
				game.clock_hours = false
				game.hud._toggle_cat("housing")
				for id in game.city.buildings:
					var b = game.city.buildings[id]
					if b["type"] == "house" and int(b["tier"]) >= 2:
						game.hud.open_info(b)
						game.rig.set_view(Vector3(b["pos"].x, 2, b["pos"].y), 160, 34, 16)
						break
				step = 4
				t = 0.0
		4:
			if t > 3.0:
				shot("p4_ui.png")
				game.hud.close_panels()
				game.hud._toggle_cat("culture")
				var tb: Dictionary = {}
				for id in game.city.buildings:
					if game.city.buildings[id]["type"] == "temple": tb = game.city.buildings[id]
				if not tb.is_empty(): game.rig.set_view(Vector3(tb["pos"].x, 2, tb["pos"].y), rad_to_deg(tb["yaw"]) + 20, 30, 24)
				step = 5
				t = 0.0
		5:
			if t > 3.0:
				shot("p5_temple.png")
				game.hud._toggle_cat("culture")
				game.rig.set_view(Vector3(64, 2, 44), 160, 55, 14)
				step = 6
				t = 0.0
		6:
			if t > 2.0:
				shot("p6_road.png")
				for id in game.city.buildings:
					var b = game.city.buildings[id]
					if b["type"] == "market":
						game.rig.set_view(Vector3(b["pos"].x, 2, b["pos"].y), rad_to_deg(b["yaw"]) + 25, 38, 13)
				step = 7
				t = 0.0
		7:
			if t > 2.0:
				shot("p7_market.png")
				for id in game.city.buildings:
					var b = game.city.buildings[id]
					if b["type"] == "farm":
						game.rig.set_view(Vector3(b["pos"].x, 2, b["pos"].y), rad_to_deg(b["yaw"]) + 25, 40, 15)
				step = 8
				t = 0.0
		8:
			if t > 2.0:
				shot("p8_farm.png")
				game.save()
				get_tree().quit()
