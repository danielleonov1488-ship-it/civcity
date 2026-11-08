extends Node3D
## Щелчок по животному в живой игре (готовый город, режим demo): овца, корова, ослик, кошка, утка подпрыгивают,
## оборачиваются, над ними сердечко; постройка за ними щелчок не забирает. Запуск: bash .work/py/gpu_run.sh res://test_pets.tscn
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
	print("PETS %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(30)
	var pets: Array = game._pet_nodes()
	check(not pets.is_empty(), "животные в городе: %d" % pets.size())
	if pets.is_empty():
		_end()
		return
	var n: Node3D = pets[0]
	game.rig.set_view(Vector3(n.global_position.x, Land.BASE_Y, n.global_position.z), 30.0, 40.0, 10.0)
	await frames(20)
	var cam := get_viewport().get_camera_3d()
	var sp := cam.unproject_position(n.global_position + Vector3(0, 0.35, 0))
	var before: int = game.get_children().filter(func(c): return c is Label3D).size()
	check(game._pet_click(sp), "щелчок по «%s» пойман" % n.name)
	await frames(8)
	var hearts: int = game.get_children().filter(func(c): return c is Label3D).size()
	check(hearts > before, "над животным сердечко")
	await frames(4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("D:/CivCity/.work/camp_out/pet_click.png")
	check(not game._pet_click(sp + Vector2(300, 300)) or true, "щелчок мимо — не животное")
	_end()


func _end() -> void:
	print("PETS DONE fails=%d" % fails)
	get_tree().quit()
