extends Node3D
## Туризм в живой игре (готовый город, режим demo — ничего не сохраняет; город делаем «новой игрой»): ставим гостиницу
## у дороги рядом с храмом, ждём работников — днём из неё выходят гости и гуляют к достопримечательностям.
## Снимки: гостиница и гуляющие гости. Запуск: bash .work/py/gpu_run.sh res://test_tourism.tscn -- [out=D:/CivCity/.work/tourism]
var game
var fails := 0
var out := "D:/CivCity/.work/tourism"


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


func check(ok: bool, what: String) -> bool:
	print("TOUR %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1
	return ok


func _until(f: Callable, secs: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not f.call() and Time.get_ticks_msec() - t0 < secs * 1000.0:
		await frames(5)
	return f.call()


func shot(name: String) -> void:
	await frames(6)
	await RenderingServer.frame_post_draw
	var p := "%s/%s.png" % [out, name]
	get_viewport().get_texture().get_image().save_png(p)
	print("TOUR shot ", p)


## Гостиница у дороги, поближе к памятникам готового города
func _place_inn() -> Dictionary:
	var c: City = game.city
	var best := {}
	var bs := -1.0
	for ring in range(3, 22):
		for k in 20:
			var a := TAU * k / 20.0
			var p := Land.START + Vector2(cos(a), sin(a)) * ring * 4.0
			for yaw: float in [0.0, PI / 2, PI, -PI / 2]:
				var chk := c.check_place("mansio", p, yaw, 0, 0, -2)
				if chk["err"] == "":
					var probe := {"id": -1, "pos": p, "type": "mansio"}
					var sc := float(Tourism.sights(c, probe)["score"])
					if sc > bs:
						bs = sc
						best = {"p": p, "yaw": yaw}
		if bs >= 12.0:
			break
	if best.is_empty():
		return {}
	return c.place("mansio", best["p"], best["yaw"], 0, 0, true)


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(30)
	var c: City = game.city
	c.cozy_v = 1
	c.level = maxi(c.level, 4)
	var inn := _place_inn()
	if not check(not inn.is_empty(), "гостиница встала у дороги"):
		_end()
		return
	var info := Tourism.inn_info(c, inn)
	print("TOUR достопримечательности: ", info["list"])
	game.speed = 2.0
	game._set_hour(9.5)
	var ok := await _until(func(): c.compute(); return bool(inn.get("active", false)), 40.0)
	check(ok, "в гостинице работают (штат %.2f)" % float(inn.get("staff", 0.0)))
	info = Tourism.inn_info(c, inn)
	check(int(info["guests"]) > 0 and float(info["per_h"]) > 0.0, "гостей в сутки %d, доход %.1f в час, звёзды %d" % [int(info["guests"]), float(info["per_h"]), roundi(float(info["score"]))])
	var tour: Tourism = game.get_node("Tourism")
	ok = await _until(func(): return not tour.groups.is_empty() and _first_tourist() != null, 40.0)
	check(ok, "из гостиницы вышли гости")
	# снимок гостиницы
	var ip: Vector2 = inn["pos"]
	game.speed = 0.0
	for k in 4:
		game.rig.set_view(Vector3(ip.x, Land.BASE_Y, ip.y), rad_to_deg(float(inn["yaw"])) + 90.0 * k, 32.0, 16.0)
		await frames(20)
		await shot("inn_%d" % k)
	game.speed = 2.0
	await frames(240)
	var t := _first_tourist()
	if t != null:
		game.rig.set_view(Vector3(t.global_position.x, Land.BASE_Y, t.global_position.z), 30.0, 36.0, 13.0)
		game.speed = 0.0
		await frames(20)
		await shot("tourists")
	_end()


func _first_tourist() -> Node3D:
	var tour: Tourism = game.get_node("Tourism")
	for g: Dictionary in tour.groups:
		for n in g["n"]:
			if is_instance_valid(n) and (n as Node3D).visible:
				return n
	return null


func _end() -> void:
	print("TOUR DONE fails=%d" % fails)
	get_tree().quit()
