extends Node3D
## Носильщики в живой игре (готовый город demo, делаем «новой игрой»): работник поля, рощи, виноградника или склада
## днём несёт мешок, корзину или амфору на склад или в лавку и возвращается на работу; в старом городе — не носят.
## Снимок носильщика с товаром крупно. Запуск: bash .work/py/gpu_run.sh res://test_porters.tscn -- [out=D:/CivCity/.work/porters]
var game
var fails := 0
var out := "D:/CivCity/.work/porters"


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
	print("PORTERS %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func shot(name: String) -> void:
	await frames(4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	game._set_hour(10.0)
	game.people._start_of_day(true)
	await frames(60)
	var pp: People = game.people
	var workers := []
	for r: Dictionary in pp.residents:
		var b: Dictionary = game.city.buildings.get(int(r["job"]), {})
		if r["state"] == "work" and not b.is_empty() and String(b["type"]) in ["farm", "grove", "vineyard", "warehouse"] and (int(r["slot"]) >= 0 or String(b["type"]) == "warehouse"):
			workers.append(r)
	check(not workers.is_empty(), "есть работники полей и складов на местах (%d)" % workers.size())
	if workers.is_empty():
		print("PORTERS DONE fails=%d" % fails)
		get_tree().quit()
		return
	# старый город — не носят
	game.city.cozy_v = 0
	pp._schedule(1000.0)
	var any := false
	for r: Dictionary in workers:
		if r["goal"] == "deliver":
			any = true
	check(not any, "в старом городе носильщиков нет")
	game.city.cozy_v = 1
	var por := {}
	for r: Dictionary in workers:
		pp._porter(r, 1000.0)
		if r["goal"] == "deliver":
			por = r
			break
	check(not por.is_empty() and String(por.get("carry", "")) in ["sack", "basket", "amphora"], "носильщик вышел с товаром: %s" % str(por.get("carry", "")))
	if por.is_empty():
		print("PORTERS DONE fails=%d" % fails)
		get_tree().quit()
		return
	var job := int(por["job"])
	check(int(pp.porters_out.get(job, 0)) == int(por["id"]), "от постройки — один носильщик")
	var c: Citizen = null
	for k in 30:
		var p2: Vector2 = por["p"]
		game.rig.set_view(Vector3(p2.x, Land.BASE_Y, p2.y), 35.0, 68.0, 11.0)
		await frames(4)
		c = por["node"]
		if c != null and HandProps.held(c) != "" and k >= 12:
			break
	if c:
		game.rig.set_view(c.global_position, 35.0, 68.0, 11.0)
		await frames(6)
		game.rig.set_view(c.global_position, 35.0, 68.0, 11.0)
		await shot("porter")
		check(HandProps.held(c) != "", "в руках виден товар (%s)" % HandProps.held(c))
	# дойдёт и вернётся (быстрая игра)
	game.speed = 8.0
	var t0 := Time.get_ticks_msec()
	var delivered := false
	while Time.get_ticks_msec() - t0 < 60000:
		await frames(5)
		if por["goal"] == "work" and not por.has("carry"):
			delivered = true
		if delivered and por["state"] == "work":
			break
	check(delivered and por["state"] == "work" and not pp.porters_out.has(job), "донёс и вернулся на работу налегке (%s / %s)" % [por["state"], por["goal"]])
	print("PORTERS DONE fails=%d" % fails)
	get_tree().quit()
