extends Node
## Проверка украшений: фонари, факелы и цветы на стенах, овцы; ночь и день
var game

func _ready() -> void:
	Game.boot = {"new": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func put(type: String, p: Vector2) -> Dictionary:
	var pl: Dictionary = game.placement(type, p)
	if pl["err"] != "":
		print("ERR ", type, " ", p, " ", pl["err"])
		return {}
	var b: Dictionary = game.city.place(type, pl["pos"], pl["yaw"], pl["variant"], pl["color"])
	if pl.has("host"):
		b["host"] = pl["host"]
		b["y"] = pl["y"]
		game._show(b)
	return b

func _run() -> void:
	while not game.ready_done:
		await frames(5)
	game.hud.visible = false
	game.city.money = 90000
	for r in Defs.RESEARCH:
		game.city.research[r["id"]] = true
	for t in Defs.B:                      # и всё, что открывают награды за просьбы
		var u: String = Defs.B[t].get("unlock", "")
		if u != "":
			game.city.research[u] = true
	var shs: PackedScene = load("res://assets/animals/Sheep_a.glb")
	var sh := shs.instantiate()
	for ap in sh.find_children("*", "AnimationPlayer", true, false):
		print("SHEEP ANIMS ", ap.get_animation_list())
	sh.free()
	var a := Vector2(176, 132)
	var b := Vector2(208, 132)
	game.tool = "road"
	game.brush_r = 1.3
	var n := int(a.distance_to(b) / 0.5)
	for k in n + 1:
		game._paint_at(a.lerp(b, float(k) / n))
	game.tool = ""
	var houses := []
	for k in 6:
		var hb := put("house_pleb", Vector2(179 + k * 5.0, 136))
		if not hb.is_empty():
			houses.append(hb)
	await frames(10)
	for hb: Dictionary in houses:
		var f := City.facing(hb["yaw"])
		var ax := City.axis(hb["yaw"])
		var front: Vector2 = (hb["pos"] as Vector2) + f * 3.0
		put(["wall_torch", "wall_lamp", "wall_flowers", "wall_banner"][houses.find(hb) % 4], front + ax * 0.8)
		put("wall_flowers", front - ax * 0.8)
	for k in 5:
		put("lamp_post", Vector2(178 + k * 7.0, 129.6))
	put("candelabrum", Vector2(186, 126))
	put("sheep", Vector2(196, 124))
	put("fence", Vector2(200, 124))
	put("hay", Vector2(203, 125))
	put("amphorae", Vector2(190, 126))
	await frames(30)
	game.clock_hours = false
	game.speed = 0.0
	for hh in [[22.0, "decor_night.png"], [12.0, "decor_day.png"], [19.6, "decor_eve.png"]]:
		game._set_hour(hh[0])
		game.rig.set_view(Vector3(191, 1.5, 132), 200, 26, 24)
		await frames(60)
		get_viewport().get_texture().get_image().save_png("D:/CivCity/.work/gd/" + hh[1])
	game._set_hour(12.0)
	game.rig.set_view(Vector3(198, 1, 125), 160, 30, 9)
	await frames(60)
	get_viewport().get_texture().get_image().save_png("D:/CivCity/.work/gd/decor_sheep.png")
	print("done")
	get_tree().quit()
