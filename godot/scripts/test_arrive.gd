extends Node
## Проверка приезда семей: повозка → значок семьи → подсветка домов → дом выбран → семья вошла
var game
var out := "D:/CivCity/.work/gd/"

func _ready() -> void:
	Game.boot = {"new": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func shot(name: String) -> void:
	await frames(3)
	get_viewport().get_texture().get_image().save_png(out + name)
	var c: City = game.city
	print("SHOT ", name, " hour=", snappedf(game.hour, 0.1), " pop=", c.stats["pop"], " arr=", c.arrivals, " inc=", c.incoming, " pend=", c.pending.keys(), " settled=", c.settled_total, " cart=", game.people.cart["state"])

func _run() -> void:
	while not game.ready_done:
		await frames(5)
	var c: City = game.city
	c.money = 6000
	game.land.paint_line(Vector2(185, 104), Vector2(185, 140), 1.3, Land.Kind.ROAD, true)
	game.people.refresh(game.land.road_chunks.keys())
	var n := 0
	for z in range(112, 140, 2):
		for side in [-4.0, 4.0]:
			if n >= 4:
				break
			var pl: Dictionary = game.placement("house_pleb", Vector2(185 + side, z))
			if pl["err"] == "":
				c.place("house_pleb", pl["pos"], pl["yaw"], pl["variant"], pl["color"])
				n += 1
	print("houses ", n)
	game.rig.set_view(Vector3(186, 2, 112), 20, 48, 40)
	game.speed = 4.0
	var t := 0
	while c.arrivals.is_empty() and t < 3000:
		await frames(10)
		t += 10
	game.speed = 1.0
	await frames(60)
	await shot("a1_arrived.png")
	game.start_settle(c.arrivals[0]["name"])
	await frames(30)
	await shot("a2_settle.png")
	game.settle_auto()
	game.speed = 4.0
	t = 0
	while c.settled_total == 0 and t < 3000:
		await frames(10)
		t += 10
	await frames(30)
	await shot("a3_settled.png")
	# дальше: несколько часов — очередь не больше двух; игрок заселяет всех
	t = 0
	while t < 2400:
		for f in c.arrivals.duplicate():
			var homes: Array = c.homes_for(f)
			if not homes.is_empty():
				c.assign(f["name"], homes[0]["id"])
		await frames(10)
		t += 10
	await shot("a4_queue.png")
	var by := {}
	for r in game.people.residents:
		var k := "%s/%s/%d" % [r["state"], r["goal"], int(r["home"])]
		by[k] = int(by.get(k, 0)) + 1
	print("RES ", by)
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		if c.is_house(b):
			print("HOUSE ", id, " pop=", b["pop"], " coming=", b.get("coming", 0), " fams=", b["families"])
	print("done")
	get_tree().quit()
