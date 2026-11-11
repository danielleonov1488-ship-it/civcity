extends Node3D
## Ролик для владельца: как теперь строится дом (12 с, детали встают по одной). Готовый городок, рядом с домами —
## свободное место; игрок «ставит» дом, камера смотрит, кадры — каждый кадр игры (запускать с --fixed-fps 30:
## время в игре идёт ровно по 1/30 с на кадр, сколько бы ни писался PNG).
##   bash .work/py/gpu_run.sh res://test_build_video.tscn --fixed-fps 30 -- out=D:/CivCity/.work/kit/build_frames [type=house_pleb]
var game
var out := "D:/CivCity/.work/kit/build_frames"
var type := "house_pleb"
var secs := 14.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		match kv[0]:
			"out": out = kv[1]
			"type": type = kv[1]
			"secs": secs = float(kv[1])
	DirAccess.make_dir_recursive_absolute(out)
	Game.boot = {"demo": "1", "noui": "1", "hour": "10.5"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(30)
	if game.rig.attrs:
		game.rig.attrs.dof_blur_far_enabled = false
		game.rig.attrs.dof_blur_near_enabled = false
	var c = game.city
	# место у дороги рядом с домами: пробуем точки вокруг существующих домов, пока placement() не скажет «можно»
	var got := {}
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		if not c.is_house(b):
			continue
		var p: Vector2 = b["pos"]
		for off: Vector2 in [Vector2(4.5, 0), Vector2(-4.5, 0), Vector2(0, 5.5), Vector2(0, -5.5), Vector2(6, 3), Vector2(-6, 3)]:
			var pl: Dictionary = game.placement(type, p + off)
			if pl["err"] == "":
				got = pl
				break
		if not got.is_empty():
			break
	if got.is_empty():
		print("no spot")
		get_tree().quit(1)
		return
	var pos: Vector2 = got["pos"]
	var gy: float = game.land.height_at(pos.x, pos.y)
	var yaw_face := rad_to_deg(float(got["yaw"]))
	game.rig.set_view(Vector3(pos.x, gy + 1.6, pos.y), 180.0 - yaw_face + 28.0, 26.0, 13.0)
	await frames(40)
	game.speed = 1.0
	game.build_anim = true
	var nb: Dictionary = c.place(type, got["pos"], got["yaw"], got["variant"], got["color"], true)
	game.build_anim = false
	print("placed ", nb.get("id", -1), " at ", pos)
	var n := int(secs * 30)
	for f in n:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/f_%04d.png" % [out, f])
	print("FRAMES ", n)
	get_tree().quit()
