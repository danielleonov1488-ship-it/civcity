extends Node3D
## Снимки облика меню и экрана загрузки (15.11: логотип 4 — венок, фон меню 2 — рисунок городка на закате):
## bash .work/py/gpu_run.sh res://test_menu_look.tscn -- out=D:/CivCity/.work/stage1/look/  → «LOOK DONE fps=…»

var out := "D:/CivCity/.work/stage1/look/"
var game


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out":
			out = kv[1] if kv[1].ends_with("/") else kv[1] + "/"
	Game.boot = {"menu": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(nm: String) -> void:
	await frames(10)
	get_viewport().get_texture().get_image().save_png(out + nm + ".png")
	print("LOOK SHOT ", nm)


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	DirAccess.make_dir_recursive_absolute(out)
	await frames(120)
	await shot("menu")
	var fps := Engine.get_frames_per_second()
	game._loading_show()
	await game._step("Город", 0.42)
	await shot("loading")
	game._loading_hide()
	print("LOOK DONE fps=%d 3d_off=%s" % [fps, str(get_viewport().disable_3d)])
	get_tree().quit()
