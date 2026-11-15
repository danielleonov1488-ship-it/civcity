extends Node3D
## Крупные планы построек для проверки правок по обзору владельца (14.11): здание ставится на чистое место с землёй,
## камера смотрит на точку здания под заданным углом. Список снимков: shots="имя,тип,час,поворот,наклон,дальность,ox,oy,oz[,show]; …"
## (ox, oy, oz — смещение цели от середины следа в осях здания, м; show — включить зрелище/людей: 1)
##   bash .work/py/gpu_run.sh res://test_bugs.tscn -- out=D:/CivCity/.work/night/bugs/after/ shots="inn,mansio,11,0,30,12,0,3,0"
var game
var out := "D:/CivCity/.work/night/bugs/after/"
var shots: PackedStringArray = []
var people := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"out": out = kv[1] if kv[1].ends_with("/") else kv[1] + "/"
			"shots": shots = kv[1].split(";")
			"people": people = kv[1] == "1"
	Game.boot = {"new": "1", "hour": "11"}
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
	var c: City = game.city
	for r in Defs.RESEARCH:
		c.research[r["id"]] = true
	c.level = 7
	c.money = 9000000
	game.hud.visible = false
	var X0 := 140.0
	var Z0 := 120.0
	game.clear_nature(Vector2(X0, Z0), 40.0)
	var h0 := snappedf(game.land.height_at(X0, Z0), Land.STEP)
	var cells: PackedInt32Array = game.land.footprint_cells([Rect2(-30, -30, 60, 60)], Vector2(X0, Z0), 0.0)
	if game.grass:
		game.grass.visible = false
	await frames(4)
	DirAccess.make_dir_recursive_absolute(out)
	var cur := ""
	var b := {}
	for sh: String in shots:
		var f := sh.strip_edges().split(",")
		if f.size() < 9:
			continue
		var type := String(f[1])
		var hour := float(f[2])
		if type != cur or float(f[9] if f.size() > 9 else 0.0) > 0.0:
			if not b.is_empty():
				game._hide(b)
				c.remove(b, false, true)
			game.land.flatten_cells(cells, h0)             # землю ровняем заново для каждой постройки (после сноса прежней она «проседает»)
			b = c.place(type, Vector2(X0, Z0), 0.0, 0, 0, true)
			if c.is_house(b):
				b["pop"] = c.house_cap(b)                  # живут — ставни ночью закрываются
				b["families"] = [{"name": Defs.FAMILIES[0], "n": b["pop"]}]
			game._show(b)
			for pn in game.find_children("*", "GPUParticles3D", true, false) + game.find_children("*", "CPUParticles3D", true, false):
				(pn as Node3D).visible = false                # пыль, дым, пыльца — не заслоняют
			for sm in (game.visuals.get(b["id"], {}) as Dictionary).get("smoke", []):
				(sm as Node3D).visible = false                # дым из труб заслоняет вид
			cur = type
			if f.size() > 9 and int(f[9]) > 0 and game.spectacle:
				game.spectacle.force(int(b["id"]), "show", 1.0, true)
		game._set_hour(hour)
		game.hour = hour
		await frames(12)
		var bp: Bp = c.blueprint(b)
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for r: Rect2 in bp.footprint(true):
			lo = lo.min(r.position)
			hi = hi.max(r.end)
		if lo.x == INF:
			lo = Vector2(-3, -3)
			hi = Vector2(3, 3)
		var ctr_l := (lo + hi) * 0.5
		var xf: Transform3D = c.xf(b)
		var ctr: Vector3 = xf * Vector3(ctr_l.x + float(f[6]), float(f[7]), ctr_l.y + float(f[8]))
		game.rig.set_view(ctr, rad_to_deg(float(b["yaw"])) + float(f[3]), float(f[4]), float(f[5]))
		await frames(int(f[10]) if f.size() > 10 else (40 if f.size() > 9 else 8))
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.save_jpg(out + String(f[0]) + ".jpg", 0.9)
		print("SHOT ", out, f[0])
	print("BUGS DONE")
	get_tree().quit(0)
