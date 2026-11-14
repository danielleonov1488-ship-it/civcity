extends Node
## Дома вплотную к домусу (как test_stage4 _apron_kerb): где встали, сколько клеток домуса рядом с домами
##   bash .work/py/gpu_run.sh res://test_houses_dom.tscn -- [new=0]
var game


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("new="):
			for t: String in NewHouses.TYPES:
				NewHouses.ON[t] = a.substr(4) != "0"
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	while not game.ready_done:
		await get_tree().process_frame
	for i in 10:
		await get_tree().process_frame
	var c: City = game.city
	var land: Land = game.land
	for r in Defs.RESEARCH:
		c.research[r["id"]] = true
	c.money = 900000
	c.level = 7
	var X1 := 172.0
	var Z1 := 186.0
	game.clear_nature(Vector2(X1, Z1), 28.0)
	land.paint_line(Vector2(X1 - 24.0, Z1), Vector2(X1 + 24.0, Z1), 1.6, Land.Kind.ROAD, true)
	for i in 5:
		await get_tree().process_frame
	var dm := {}
	for k in 16:
		var pl: Dictionary = game.placement("house_patrician", Vector2(X1, Z1 - 2.0) + Vector2(0, -0.5 * k))
		if pl["err"] == "":
			dm = c.place("house_patrician", pl["pos"], pl["yaw"], pl["variant"], pl["color"], true)
			break
	var dset := {}
	for k in (dm["cells"] as PackedInt32Array):
		dset[k] = true
	print("DOM domus pos %s yaw %.3f v%d cells %d" % [dm["pos"], float(dm["yaw"]), int(dm["variant"]), dset.size()])
	for side: float in [1.0, -1.0]:
		for s in 120:
			var pl: Dictionary = game.placement("house_pleb", Vector2((dm["pos"] as Vector2).x + side * 0.25 * s, Z1 - 2.0))
			if pl["err"] == "":
				var h := c.place("house_pleb", pl["pos"], pl["yaw"], pl["variant"], pl["color"], true)
				var reach := {}
				var mind := 99
				for k in (h["cells"] as PackedInt32Array):
					for dy in range(-4, 5):
						for dx in range(-4 + absi(dy), 5 - absi(dy)):
							if dset.has(k + dy * Land.N + dx):
								reach[k + dy * Land.N + dx] = true
								mind = mini(mind, absi(dx) + absi(dy))
				print("DOM house side %+.0f step %d pos %s yaw %.3f v%d cells %d reach %d mind %d dz %.2f" % [side, s, h["pos"], float(h["yaw"]), int(h["variant"]),
					(h["cells"] as PackedInt32Array).size(), reach.size(), mind, ((h["pos"] as Vector2) - (dm["pos"] as Vector2)).dot(City.facing(float(dm["yaw"])))])
				break
	print("DOM DONE")
	get_tree().quit()
