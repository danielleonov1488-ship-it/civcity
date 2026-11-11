extends Node3D
## Ролик для владельца: как теперь строится дом (12 с, детали встают по одной). Готовый городок, рядом с домами —
## свободное место; игрок «ставит» дом, камера смотрит, кадры — каждый кадр игры (запускать с --fixed-fps 30:
## время в игре идёт ровно по 1/30 с на кадр, сколько бы ни писался PNG).
##   bash .work/py/gpu_run.sh res://test_build_video.tscn --fixed-fps 30 -- out=D:/CivCity/.work/kit/build_frames [type=house_pleb]
var game
var out := "D:/CivCity/.work/kit/build_frames"
var type := "house_pleb"
var secs := 14.0
var shots := false                      # shots=1 — без стройки: поставить и снять с четырёх сторон (проверка облика)
var dist := 13.0
var town := false                       # town=1 — ещё и общие виды городка (как смотрится улица)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		match kv[0]:
			"out": out = kv[1]
			"type": type = kv[1]
			"secs": secs = float(kv[1])
			"shots": shots = kv[1] == "1"
			"dist": dist = float(kv[1])
			"town": town = kv[1] == "1"
	DirAccess.make_dir_recursive_absolute(out)
	Game.boot = {"demo": "1", "noui": "1", "hour": "10.5"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _free(r: Rect2) -> bool:
	var land: Land = game.land
	var x := r.position.x
	while x < r.end.x:
		var z := r.position.y
		while z < r.end.y:
			var i := int(x / Land.CELL)
			var j := int(z / Land.CELL)
			if not land.inside(i, j) or land.occ[land.idx(i, j)] != 0:
				return false
			z += Land.CELL
		x += Land.CELL
	return absf(land.height_at(r.position.x, r.position.y) - land.height_at(r.end.x, r.end.y)) < 0.6


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(30)
	if game.rig.attrs:
		game.rig.attrs.dof_blur_far_enabled = false
		game.rig.attrs.dof_blur_near_enabled = false
	if town:
		var gyc: float = game.land.height_at(192, 154)
		for k in 4:
			game.rig.set_view(Vector3(192, gyc, 154) + Vector3(0, 0, 0), 20.0 + 90.0 * k, 38.0, 40.0)
			await frames(60)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/town_%d.png" % [out, k])
		for k in 3:
			var c = game.city
			var hs := []
			for id in c.buildings:
				if c.is_house(c.buildings[id]):
					hs.append(c.buildings[id])
			if hs.size() > k * 5:
				var hb: Dictionary = hs[k * 5]
				var hp: Vector2 = hb["pos"]
				game.rig.set_view(Vector3(hp.x, game.land.height_at(hp.x, hp.y) + 1.5, hp.y), 180.0 - rad_to_deg(float(hb["yaw"])) + 25.0, 28.0, 14.0)
				await frames(60)
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s/street_%d.png" % [out, k])
	var c = game.city
	# место у дороги рядом с домами: пробуем точки вокруг существующих домов, пока placement() не скажет «можно»
	for r in Defs.RESEARCH:                 # всё открыто: проверяем облик, а не прогресс
		c.research[r["id"]] = true
	c.level = 7
	var got := {}
	var last_err := ""
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		if not c.is_house(b):
			continue
		var p: Vector2 = b["pos"]
		for off: Vector2 in [Vector2(4.5, 0), Vector2(-4.5, 0), Vector2(0, 5.5), Vector2(0, -5.5), Vector2(6, 3), Vector2(-6, 3),
				Vector2(12, 0), Vector2(-12, 0), Vector2(0, 14), Vector2(0, -14), Vector2(16, 10), Vector2(-16, 10)]:
			var pl: Dictionary = game.placement(type, p + off)
			if pl["err"] == "":
				got = pl
				break
			last_err = str(pl["err"])
		if not got.is_empty():
			break
	if got.is_empty() and shots:
		# большая постройка без дороги рядом: просто чертёж на пустом ровном месте (+ дым и огни, как в игре)
		var base := Vector2(-1, -1)
		for bx in range(40, 360, 6):
			for bz in range(40, 330, 6):
				if _free(Rect2(Vector2(bx - 10, bz - 10), Vector2(20, 20))):
					base = Vector2(bx, bz)
					break
			if base.x >= 0:
				break
		if base.x >= 0:
			var bp := Catalog.make(type, 0, 0, 0)
			var o := Vector3(base.x, game.land.height_at(base.x, base.y), base.y)
			var xf := Transform3D(Basis.IDENTITY, o)
			game.parts.place(bp, xf, {})
			for sp in bp.smoke.slice(0, 1):
				game._smoke(xf * sp)
			for lp in bp.lights:
				game._light(xf * lp, 1.0)
			print("placed blueprint ", type, " at ", base)
			for k in 4:
				game.rig.set_view(o + Vector3(0, 1.6, 0), 35.0 + 90.0 * k, 30.0, dist)
				await frames(40)
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [out, type, k])
			get_tree().quit()
			return
	if got.is_empty():
		print("no spot: ", last_err)
		get_tree().quit(1)
		return
	var pos: Vector2 = got["pos"]
	var gy: float = game.land.height_at(pos.x, pos.y)
	var yaw_face := rad_to_deg(float(got["yaw"]))
	game.rig.set_view(Vector3(pos.x, gy + 1.6, pos.y), 180.0 - yaw_face + 28.0, 26.0, dist)
	await frames(40)
	if shots:
		var b2: Dictionary = c.place(type, got["pos"], got["yaw"], got["variant"], got["color"], true)
		print("placed ", b2.get("id", -1), " ", type)
		for k in 4:
			game.rig.set_view(Vector3(pos.x, gy + 1.6, pos.y), 180.0 - yaw_face + 35.0 + 90.0 * k, 30.0, dist)
			await frames(30)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [out, type, k])
		get_tree().quit()
		return
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
