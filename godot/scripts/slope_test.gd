extends Node
## Проверка вблизи: дорога по склону, дома у дороги на склоне, люди на земле
var game

func _ready() -> void:
	Game.boot = {"new": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _run() -> void:
	while not game.ready_done:
		await frames(5)
	game.hud.visible = false
	game.city.money = 50000
	var a := Vector2(250, 120)
	var b := Vector2(290, 175)
	var ch := []
	var n := int(a.distance_to(b) / 0.5) + 1
	game.tool = "road"
	game.brush_r = 1.3
	for k in n + 1:
		game._paint_at(a.lerp(b, float(k) / n))
	game.tool = ""
	var placed := 0
	var dir := (b - a).normalized()
	var nrm := Vector2(-dir.y, dir.x)
	for k in 12:
		for side: float in [-1.0, 1.0]:
			var p := a + dir * (4.0 + k * 5.2) + nrm * side * 5.0
			var pl: Dictionary = game.placement("house_pleb", p, k % 5)
			if pl["err"] == "":
				game.city.place("house_pleb", pl["pos"], pl["yaw"], pl["variant"], pl["color"])
				placed += 1
			else:
				print("err ", pl["err"])
	print("placed ", placed)
	await frames(60)
	var mid := a.lerp(b, 0.5)
	for id in game.city.buildings:
		var bb: Dictionary = game.city.buildings[id]
		if bb["type"] == "house_pleb":
			var dp: Vector2 = game.city.door_point(bb)
			var road_d := 99.0
			for k in 40:
				var q := dp + Vector2(cos(k * TAU / 40.0), sin(k * TAU / 40.0)) * 0.0
			print("house ", bb["pos"], " door ", dp, " door_on_road=", game.land.is_road(dp), " facing ", City.facing(bb["yaw"]))
	game.rig.set_view(Vector3(mid.x, 2, mid.y), 0, 88, 40)
	await frames(90)
	get_viewport().get_texture().get_image().save_png("D:/CivCity/.work/gd/slope0.png")
	game.rig.set_view(Vector3(mid.x, 2, mid.y), rad_to_deg(atan2(nrm.x, nrm.y)) + 30, 24, 26)
	await frames(90)
	get_viewport().get_texture().get_image().save_png("D:/CivCity/.work/gd/slope1.png")
	game.rig.set_view(Vector3(mid.x, 2, mid.y), rad_to_deg(atan2(nrm.x, nrm.y)) + 150, 16, 14)
	await frames(90)
	get_viewport().get_texture().get_image().save_png("D:/CivCity/.work/gd/slope2.png")
	print("done")
	get_tree().quit()
