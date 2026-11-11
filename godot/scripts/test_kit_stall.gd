extends Node3D
## Отладка: почему не ставится постройка type (ошибки placement у дорог городка)
var game
var type := "stall_fruit"

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("type="):
			type = a.substr(5)
	Game.boot = {"demo": "1", "noui": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()

func _run() -> void:
	while not game.ready_done:
		await get_tree().process_frame
	var errs := {}
	var ok := 0
	for x in range(150, 240, 2):
		for z in range(110, 200, 2):
			var pl: Dictionary = game.placement(type, Vector2(x, z))
			var e := String(pl["err"])
			if e == "":
				ok += 1
				if ok <= 3:
					print("STALL ok at ", Vector2(x, z), " sub ", pl.get("sub", ""), " pos ", pl["pos"])
			else:
				errs[e] = int(errs.get(e, 0)) + 1
	print("STALL ok ", ok, " errs ", errs)
	get_tree().quit()
