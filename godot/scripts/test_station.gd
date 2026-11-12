extends Node
## Почтовая станция в новой игре на разных уровнях города (свой набор): площадь перед ней, повозка, семьи.
##   bash .work/py/gpu_run.sh res://test_station.tscn -- out=D:/CivCity/.work/kit/station/      → «STA DONE fails=0»

var game
var fails := 0
var out := "D:/CivCity/.work/kit/station/"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.trim_prefix("out=")
	KitHouses.ON = true                       # своя станция — даже когда игра на Synty
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, what: String) -> bool:
	print("STA %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1
	return ok


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(20)
	var c: City = game.city
	game.hud.visible = false
	game.speed = 0.0
	var st := c.center()
	if not check(not st.is_empty(), "станция есть"):
		_end()
		return
	var p: Vector2 = st["pos"]
	var fw := City.facing(float(st["yaw"]))
	for lvl: int in [0, 2, 3, 5, 7]:
		st["tier"] = lvl
		c.level = lvl
		game._show(st)
		await frames(20)
		var bp := c.blueprint(st)
		check(bp.kit_id == "civ_center%d" % lvl, "уровень %d — своя станция (%s)" % [lvl + 1, bp.kit_id])
		var at := p + fw * 1.5
		game.rig.set_view(Vector3(at.x, Land.BASE_Y, at.y), rad_to_deg(float(st["yaw"])) + 25.0, 34.0, 17.0)
		await frames(40)
		DirAccess.make_dir_recursive_absolute(out)
		get_viewport().get_texture().get_image().save_png(out + "station_%d.png" % lvl)
	_end()


func _end() -> void:
	print("STA DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
