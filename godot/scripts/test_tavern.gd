extends Node3D
## Вечер в таверне вблизи (владелец 11.11: «садились за столы, пили, в тавернах пили»): гости за столами подносят
## чашу ко рту (Crowd «drink»), снимок крупно.
##   bash .work/py/gpu_run.sh res://test_tavern.tscn -- out=D:/CivCity/.work/kit/leisure/      → «TAV DONE fails=0»

var game
var fails := 0
var out := "D:/CivCity/.work/kit/leisure/"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.trim_prefix("out=")
	Game.boot = {"new": "1", "hour": "18"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, what: String) -> bool:
	print("TAV %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1
	return ok


func _place(type: String) -> Dictionary:
	var c: City = game.city
	c.research[Defs.B[type]["unlock"]] = true
	for ring in range(4, 30):
		for k in 16:
			var p := Land.START + Vector2(cos(TAU * k / 16.0), sin(TAU * k / 16.0)) * ring * 4.0
			for yaw: float in [0.0, PI / 2, PI, -PI / 2]:
				var chk := c.check_place(type, p, yaw, 0, 0, -2)
				if chk["err"] == "" or chk["err"] == "Нужна дорога у входа":
					return c.place(type, p, yaw, 0, 0, true)
	return {}


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(30)
	var sp: Spectacle = game.spectacle
	game.city.cozy_v = 1                       # вечер в таверне — в новой игре («Уютный Рим»)
	var c: City = game.city
	for r in Defs.RESEARCH:
		c.research[r["id"]] = true
	c.level = 7
	c.money = 900000
	game.hud.visible = false
	var X0 := 140.0
	var Z0 := 120.0
	game.clear_nature(Vector2(X0 + 10.0, Z0), 20.0)
	game.land.paint_line(Vector2(X0 - 6.0, Z0), Vector2(X0 + 30.0, Z0), 1.6, Land.Kind.ROAD, true)
	await frames(4)
	var tv := {}
	for k in 30:
		var pl: Dictionary = game.placement("taberna", Vector2(X0 + 10.0 + k * 0.4, Z0 + 3.0))
		if pl["err"] == "":
			tv = c.place("taberna", pl["pos"], pl["yaw"], pl["variant"], pl["color"], true)
			game._show(tv)
			break
	await frames(10)
	var TV: Dictionary = sp.venues.get(int(tv.get("id", -1)), {})
	if not check(not TV.is_empty(), "таверна встала"):
		_end()
		return
	sp.force(int(tv["id"]), "show", 1.0, true)
	game._set_hour(18.4)
	var drinking := 0
	for w in 12:                               # гости садятся и меняют занятие — ждём, пока кто-то выпьет
		await frames(40)
		drinking = 0
		for st: Dictionary in TV["who"]:
			if int((st["cp"] as Dictionary).get("clip", -1)) in [Crowd.clip_id("drink"), Crowd.clip_id("drink_m")]:
				drinking += 1
		if drinking >= 2:
			break
	print("TAV гостей ", (TV["who"] as Array).size(), " пьют ", drinking)
	var tp: Vector2 = tv["pos"]
	var fw := City.facing(float(tv["yaw"]))
	var at: Vector2 = tp + fw * 2.4
	for k in 3:
		var gy: float = game.land.height_at(at.x, at.y)
		game.rig.set_view(Vector3(at.x, gy + 0.4, at.y), rad_to_deg(float(tv["yaw"])) + [20.0, -30.0, 0.0][k], [34.0, 34.0, 55.0][k], [6.5, 6.5, 9.0][k])
		await frames(60)
		var img := get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(out)
		img.save_png(out + "tavern_%d.png" % k)
		print("SHOT ", out + "tavern_%d.png" % k)
	check(drinking > 0, "в таверне пьют за столами: %d" % drinking)
	_end()


func _end() -> void:
	print("TAV DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
