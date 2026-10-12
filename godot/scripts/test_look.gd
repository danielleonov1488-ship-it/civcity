extends Node
## Стенд облика: готовый город без интерфейса, одни и те же виды в разное время суток — для сравнения с Town to City.
## Аргументы (после --): tag=имя  views=0,1,2  hours=12.5,19.5
var game
var tag := "cur"
var views := [0, 1, 2]
var hours := [12.5, 19.5, 0.5]

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		if kv.size() == 2:
			match kv[0]:
				"tag": tag = kv[1]
				"views": views = Array(kv[1].split(",")).map(func(x): return int(x))
				"hours": hours = Array(kv[1].split(",")).map(func(x): return float(x))
	Game.boot = {"demo": "1", "noui": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func view(i: int) -> void:
	match i:
		0: game.rig.set_view(Vector3(190, 1.5, 150), 20, 40, 46)     # средний план
		1: game.rig.set_view(Vector3(186, 1.5, 142), 205, 30, 20)    # улица вблизи
		2: game.rig.set_view(Vector3(192, 1.5, 154), 20, 52, 90)     # весь город
		3: game.rig.set_view(Vector3(192, 1.5, 148), 0, 36, 30)      # как в Town to City: к тоннелю

func _run() -> void:
	while not game.ready_done:
		await frames(5)
	game.hud.visible = false
	game.speed = 0.0
	game.clock_hours = false
	await frames(30)
	for h in hours:
		game._set_hour(h)
		for v in views:
			view(v)
			await frames(70)
			get_viewport().get_texture().get_image().save_png("D:/CivCity/.work/look/%s_v%d_h%s.png" % [tag, v, str(h).replace(".", "_")])
	print("look done")
	get_tree().quit()
