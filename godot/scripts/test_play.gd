extends Node
## Игровой тест: новый город — улицы, дома, лавки, скрипторий; прогон дней; исследования; снимки

var game
var step := 0
var t := 0.0
var out := "D:/CivCity/.work/gd/"
var cart_shot := false


func _ready() -> void:
	Game.boot = {"new": "1"}
	var sc: PackedScene = load("res://main.tscn")
	game = sc.instantiate()
	add_child(game)


func shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(out + name)
	var c: City = game.city
	var tiers := {}
	for id in c.buildings:
		var b = c.buildings[id]
		if c.is_house(b):
			tiers[b["type"] + str(b["tier"])] = int(tiers.get(b["type"] + str(b["tier"]), 0)) + 1
	print("SHOT ", name, " day=", c.day, " pop=", c.stats["pop"], " happy=", c.stats["happy"], " money=", int(c.money), " rp=", int(c.rp), " lvl=", c.level,
		" people=", game.people.residents.size(), " vis=", game.people.visible_count, " wait=", game.people.waiting_fams.size(), " arr=", c.arrivals.size(), " inc=", c.incoming, " houses=", tiers, " fps=", Engine.get_frames_per_second(), " parts=", game.parts.count())


func try_place(type: String, near: Vector2, r: float, variant := -1) -> Dictionary:
	for k in range(0, int(r * 2) + 1):
		var rr := k * 0.5
		var n := maxi(1, int(rr * 6))
		for a in n:
			var p := near + Vector2(cos(TAU * a / n), sin(TAU * a / n)) * rr
			var pl: Dictionary = game.placement(type, p, variant)
			if pl["err"] == "":
				var b: Dictionary = game.city.place(type, pl["pos"], pl["yaw"], pl["variant"], pl["color"])
				return b
	print("FAILED ", type, " near ", near, " err=", game.placement(type, near, variant)["err"])
	return {}


func road(a: Vector2, b: Vector2, w := 1.3, kd := Land.Kind.ROAD) -> void:
	game.land.paint_line(a, b, w, kd, true)


func _process(dt: float) -> void:
	if game == null or not game.ready_done:
		return
	t += dt
	# игрок заселяет приезжих в самый счастливый подходящий дом (там, где рядом лавки)
	for f in game.city.arrivals.duplicate():
		var homes: Array = game.city.homes_for(f)
		if not homes.is_empty():
			homes.sort_custom(func(a, b): return int(a["happy"]) > int(b["happy"]))
			game.city.assign(f["name"], homes[0]["id"])
	# и покупает этаж полному счастливому дому, когда можно (этажи больше не растут сами) — как инструментом «Этаж»:
	# мазок по всем готовым домам, итог — одной строкой в колокольчик
	if step >= 3 and step < 6 and game.city.has_method("buy_floor"):
		for id in game.city.buildings.keys():
			var b: Dictionary = game.city.buildings.get(id, {})
			if not b.is_empty() and game.city.is_house(b) and game.city.can_buy_floor(b) == "":
				game._floor_buy(b)
				print("FLOOR bought: house ", id, " tier=", b["tier"], " happy=", b["happy"], " money=", int(game.city.money))
		game._floor_end()
	if step >= 2 and not cart_shot and game.people.cart.get("state", "") == "in" and float(game.people.cart["s"]) > 8.0:
		cart_shot = true
		var keep: float = game.speed
		game.speed = 0.0
		var n: Node3D = game.people.cart["n"]
		game.rig.set_view(n.position, rad_to_deg(n.rotation.y) + 70, 40, 10)
		await get_tree().create_timer(0.5).timeout
		shot("q_cart.png")
		game.rig.set_view(Vector3(192, 2, 138), 15, 44, 46)
		game.speed = keep
	match step:
		0:
			if t > 1.0:
				game.city.money = 6000
				road(Vector2(192, 128), Vector2(192, 152))
				road(Vector2(172, 136), Vector2(214, 136))
				road(Vector2(172, 148), Vector2(214, 148))
				var n := 0
				for z in range(128, 156, 2):
					for x in range(170, 216, 2):
						if n >= 18:
							break
						var p := Vector2(x, z)
						var pl: Dictionary = game.placement("house_pleb", p)
						if pl["err"] == "":
							game.city.place("house_pleb", pl["pos"], pl["yaw"], pl["variant"], pl["color"])
							n += 1
				print("houses ", n)
				game.city.research["stall_veg"] = true      # как будто уже изучены (иначе их не поставить)
				game.city.research["musicians"] = true
				try_place("stall_fruit", Vector2(188, 141), 5)
				try_place("stall_veg", Vector2(198, 141), 5)
				try_place("scriptorium", Vector2(206, 131), 14)
				try_place("musicians", Vector2(182, 142), 5)
				game.rig.set_view(Vector3(192, 2, 142), 15, 46, 46)
				game.speed = 6.0
				step = 1
				t = 0.0
		1:
			if t > 2.0:
				shot("q1_built.png")
				step = 2
				t = 0.0
		2:
			if t > 60.0:
				shot("q2_settled.png")
				var c: City = game.city
				c.rp = 600
				for r in ["floor2", "farm", "warehouse", "butcher", "weaver", "deco_flowers"]:
					c.research[r] = true
				c.level = 1
				try_place("warehouse", Vector2(180, 156), 6)
				try_place("butcher", Vector2(204, 154), 6)
				try_place("weaver", Vector2(182, 154), 6)
				for k in 8:
					try_place("flowers", Vector2(176 + k * 4, 146), 2)
				# фонари и скамьи у обжитых домов — как игрок, которому советник сказал про украшения
				var k2 := 0
				for id in c.buildings.keys():
					var h: Dictionary = c.buildings[id]
					if c.is_house(h) and int(h["pop"]) > 0:
						var back: Vector2 = (h["pos"] as Vector2) - City.facing(float(h["yaw"])) * 5.0
						try_place("lamp_post" if k2 % 2 == 0 else "bench", back, 3)
						try_place("well", back + City.axis(float(h["yaw"])) * 3.0, 3)
						k2 += 1
				c.compute()
				print("after decor: happy=", c.stats["happy"], " tips=", c.stats.get("happy_tips", []))
				step = 3
				t = 0.0
		3:
			if t > 70.0:
				shot("q3_grown.png")
				var c: City = game.city
				for id in c.buildings:
					var b = c.buildings[id]
					if c.is_house(b):
						print("H tier=", b["tier"], " pop=", b["pop"], " happy=", b["happy"], " needs=", b["needs"], " score=", b["score"], " missing=", b["missing"],
							" parts=", b.get("happy_parts", []), " floor: ", c.can_buy_floor(b))
						break
				var hs := []
				for id in c.buildings:
					if c.is_house(c.buildings[id]):
						hs.append(int(c.buildings[id]["happy"]))
				print("HAPPY houses=", hs, " city=", c.stats["happy"], " parts=", c.stats.get("happy_parts", []), " tips=", c.stats.get("happy_tips", []),
					" block='", c.stats.get("arrive_block", ""), "' income=", snappedf(float(c.stats["income"]), 0.1), " upkeep=", snappedf(float(c.stats["upkeep"]), 0.1))
				for id in c.buildings:
					var b = c.buildings[id]
					if not c.is_house(b) and c.def(b)["kind"] != "decor":
						print("B ", b["type"], " active=", b.get("active"), " staff=", b.get("staff"), " served=", b.get("served"), " why=", b.get("why", ""))
				game.speed = 1.0
				game.clock_hours = false
				game._set_hour(10.0)
				for id in c.buildings:
					var b = c.buildings[id]
					if c.is_house(b) and int(b["tier"]) >= 2:
						game.select_building(b)
						game.hud.open_info(b)
						game.rig.set_view(Vector3(b["pos"].x, 2, b["pos"].y), 25, 36, 18)
						break
				game.hud._toggle_cat("commerce")
				step = 4
				t = 0.0
		4:
			if t > 3.0:
				shot("q4_ui.png")
				game.hud.close_panels()
				game.hud._toggle(game.hud.research_panel)
				game.hud._fill_research()
				step = 5
				t = 0.0
		5:
			if t > 2.0:
				shot("q5_research.png")
				game.hud._toggle(game.hud.research_panel)
				game.rig.set_view(Vector3(192, 2, 142), 25, 52, 40)
				step = 6
				t = 0.0
		6:
			if t > 2.0:
				shot("q6_overview.png")
				game.set_tool("floor")                      # инструмент «Этаж» (U): стрелки над готовыми домами
				step = 7
				t = 0.0
		7:
			if t > 2.0:
				shot("q7_floor_tool.png")
				print("FLOOR tool: ready=", game.city.floor_ready(false).size(), " marks=", game.hud.badges.keys().filter(func(k): return String(k).begins_with("fl")).size())
				game.set_tool("")
				game.save()
				get_tree().quit()
