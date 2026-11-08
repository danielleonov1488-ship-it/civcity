extends Node3D
## Лодки на прудах (живая игра, готовый город demo, делаем «новой игрой»): днём плывут, вёсла ходят; ночью их нет;
## в старом городе лодок нет. Снимок лодки. Запуск: bash .work/py/gpu_run.sh res://test_boats.tscn -- [out=D:/CivCity/.work/boats]
var game
var fails := 0
var out := "D:/CivCity/.work/boats"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	Game.boot = {"demo": "1", "noui": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, what: String) -> void:
	print("BOATS %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(20)
	var bs: Boats = game.get_node("Boats")
	check(bs != null and not bs.boats.is_empty(), "лодки на больших прудах: %d" % (bs.boats.size() if bs else 0))
	game._set_hour(10.0)
	await frames(5)
	check(not (bs.boats[0]["n"] as Node3D).visible, "старый город — лодок не видно")
	game.city.cozy_v = 1
	await frames(5)
	var n: Node3D = bs.boats[0]["n"]
	var p0 := n.global_position
	await frames(60)
	check(n.visible and n.global_position.distance_to(p0) > 0.01, "днём лодка плывёт")
	game.rig.set_view(Vector3(n.global_position.x, Land.BASE_Y, n.global_position.z), 40.0, 34.0, 9.0)
	await frames(12)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/boat.png" % out)
	game._set_hour(23.0)
	await frames(5)
	check(not n.visible, "ночью лодки нет")
	print("BOATS DONE fails=%d" % fails)
	get_tree().quit()
