extends Node3D
## Плющ на старых домах (живая игра, готовый город demo, делаем его «новой игрой»): у дома, что стоит дольше
## 3 игровых дней, — лозы у земли, дольше 8 — гуще и выше; молодой дом без плюща; старый город — без плюща.
## Запуск: bash .work/py/gpu_run.sh res://test_ivy.tscn -- [out=D:/CivCity/.work/ivy]
var game
var fails := 0
var out := "D:/CivCity/.work/ivy"


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
	print("IVY %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(20)
	var c: City = game.city
	var house := {}
	for id in c.buildings:
		if c.is_house(c.buildings[id]):
			house = c.buildings[id]
			break
	check(Ivy.stage(c, house) == 0, "старый город — без плюща")
	c.cozy_v = 1
	house["hz"] = c.clock_h
	check(Ivy.stage(c, house) == 0, "новый дом — без плюща")
	house["hz"] = c.clock_h - Ivy.STAGE_H[0]
	check(Ivy.stage(c, house) == 1, "3 игровых дня — первая стадия")
	var bp := c.blueprint(house)
	var n1 := Ivy.blueprint(bp, 1, 7).parts.size()
	var n2 := Ivy.blueprint(bp, 2, 7).parts.size()
	check(n1 >= 1 and n2 > n1, "лоз: %d на первой стадии, %d на второй" % [n1, n2])
	# все дома у точки взгляда — старые: плющ гуще
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		if c.is_house(b):
			b["hz"] = c.clock_h - Ivy.STAGE_H[1]
			game._show(b)
	await frames(10)
	var p: Vector2 = house["pos"]
	for k in 2:
		game.rig.set_view(Vector3(p.x, Land.BASE_Y, p.y), 30.0 + 120.0 * k, 28.0, 16.0)
		await frames(15)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/ivy_%d.png" % [out, k])
	print("IVY DONE fails=%d" % fails)
	get_tree().quit()
