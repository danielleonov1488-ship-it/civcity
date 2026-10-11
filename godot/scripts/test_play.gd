extends Node
## Игровой тест: новый город, дорога от центра, дома, колодец, поле и рынок; прогон дней; снимки

var game
var step := 0
var t := 0.0
var out := "D:/CivCity/.work/gd/"

func _ready() -> void:
	var sc: PackedScene = load("res://main.tscn")
	game = sc.instantiate()
	add_child(game)

func shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(out + name)
	print("SHOT ", name, " pop=", game.city.stats["pop"], " money=", int(game.city.money), " day=", game.city.day, " walkers=", game.people.walkers.size(), " queue=", game.city.settle_queue.size())

func _process(dt: float) -> void:
	t += dt
	match step:
		0:
			if t > 1.0:
				shot("p0_start.png")
				var c: Vector2 = Land.CENTER
				var ch := []
				game.tool = "road"
				game.brush_r = 1.2
				ch.append_array(game.land.paint_line(c + Vector2(0, 5), c + Vector2(0, 34), 1.2, Land.Kind.ROAD, true))
				ch.append_array(game.land.paint_line(c + Vector2(-16, 22), c + Vector2(16, 22), 1.2, Land.Kind.ROAD, true))
				game.tool = ""
				var placed := 0
				for side: float in [-1.0, 1.0]:
					for k in 5:
						var p := c + Vector2(side * 4.0, 9.0 + k * 5.1)
						var pl: Dictionary = game.placement("house", p)
						if pl["err"] == "":
							game.city.place("house", pl["pos"], pl["yaw"])
							placed += 1
				for k in 4:
					var p := c + Vector2(-12.0 + k * 5.1, 26.0)
					var pl: Dictionary = game.placement("house", p)
					if pl["err"] == "":
						game.city.place("house", pl["pos"], pl["yaw"])
						placed += 1
				var w: Dictionary = game.placement("well", c + Vector2(5.5, 22 + 3.5))
				print("well err=", w["err"])
				if w["err"] == "":
					game.city.place("well", w["pos"], w["yaw"])
				var f: Dictionary = game.placement("farm", c + Vector2(-12, 16))
				print("farm err=", f["err"])
				if f["err"] == "":
					game.city.place("farm", f["pos"], f["yaw"])
				var m: Dictionary = game.placement("market", c + Vector2(12, 16))
				print("market err=", m["err"])
				if m["err"] == "":
					game.city.place("market", m["pos"], m["yaw"])
				print("houses placed ", placed)
				game.rig.set_view(Vector3(c.x, 2, c.y + 20), 200, 44, 34)
				game.speed = 4.0
				step = 1
				t = 0.0
		1:
			if t > 2.0:
				shot("p1_built.png")
				step = 2
				t = 0.0
		2:
			if t > 25.0:
				shot("p2_settled.png")
				step = 3
				t = 0.0
		3:
			if t > 30.0:
				game.rig.set_view(Vector3(Land.CENTER.x, 2, Land.CENTER.y + 18), 160, 30, 20)
				step = 4
				t = 0.0
		4:
			if t > 2.0:
				shot("p3_close.png")
				for id in game.city.buildings:
					var b = game.city.buildings[id]
					if b["type"] == "house":
						print("house tier=", b["tier"], " pop=", b["pop"], " road=", b["road"], " needs=", b["needs"])
						break
				get_tree().quit()
