extends Node3D
## Живая вода в фонтанах (живая игра, готовый город demo): у фонтана — струя из чаши и вода из львиных пастей; с акведуком
## струи гуще; далеко от камеры не бьют. Снимок фонтана. Запуск: bash .work/py/gpu_run.sh res://test_fountains.tscn
var game
var fails := 0


func _ready() -> void:
	Game.boot = {"demo": "1", "noui": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, what: String) -> void:
	print("FOUNT %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(20)
	var f: Fountains = game.get_node("Fountains")
	var fb := {}
	for id in game.city.buildings:
		if String(game.city.buildings[id]["type"]) == "fountain":
			fb = game.city.buildings[id]
			break
	check(not fb.is_empty(), "фонтан в готовом городе")
	var p: Vector2 = fb["pos"]
	game.rig.set_view(Vector3(p.x, Land.BASE_Y, p.y), 25.0, 32.0, 9.0)
	game._set_hour(11.0)
	await frames(150)
	var J: Dictionary = f.jets.get(int(fb["id"]), {})
	check(not J.is_empty() and (J["em"] as Array).size() >= 3, "струи у фонтана: %d (чаша и львиные пасти)" % (0 if J.is_empty() else (J["em"] as Array).size()))
	check(not J.is_empty() and (J["em"][0] as GPUParticles3D).emitting, "у камеры вода бьёт")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("D:/CivCity/.work/camp_out/fountain.png")
	print("FOUNT акведук в городе: ", f._aqua)
	print("FOUNT DONE fails=%d" % fails)
	get_tree().quit()
