extends Node3D
## Снимки нижней левой панели инструментов (15.11, владелец: «слишком большая менюшка дорог»): закрыто, «Дороги»,
## «Трава», «Земля». bash .work/py/gpu_run.sh res://test_roads_ui.tscn -- out=D:/CivCity/.work/stage1/roads/shots/
##   → «ROADSUI DONE»

var out := "D:/CivCity/.work/stage1/roads/shots/"
var game


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out":
			out = kv[1] if kv[1].ends_with("/") else kv[1] + "/"
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(nm: String) -> void:
	await frames(8)
	get_viewport().get_texture().get_image().save_png(out + nm + ".png")
	print("ROADSUI SHOT ", nm)


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(30)
	DirAccess.make_dir_recursive_absolute(out)
	for r in Defs.RESEARCH:
		game.city.research[r["id"]] = true
	game.hud.refresh_tools()
	await shot("0_closed")
	game.hud._toggle_road_group("roads")
	await shot("1_roads")
	game.hud._toggle_road_group("grass")
	await shot("2_grass")
	game.hud._toggle_road_group("ground")
	await shot("3_ground")
	game.hud._toggle_road_group("ground")
	await shot("4_closed_again")
	print("ROADSUI DONE")
	get_tree().quit()
