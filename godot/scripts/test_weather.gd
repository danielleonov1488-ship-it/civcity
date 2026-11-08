extends Node3D
## Дождь в живой игре (готовый город demo, делаем «новой игрой»): струи вокруг камеры, земля мокнет (wet) и потом
## сохнет, цвета мягче; в старом городе дождь сам не начинается. Снимки до и во время дождя.
## Запуск: bash .work/py/gpu_run.sh res://test_weather.tscn -- [out=D:/CivCity/.work/weather]
var game
var fails := 0
var out := "D:/CivCity/.work/weather"


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
	print("WEATHER %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func shot(name: String) -> void:
	await frames(4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(30)
	var w: Weather = game.weather
	check(w != null and not w.raining(), "погода заведена, в старом городе дождя нет")
	game._set_hour(11.0)
	game.rig.set_view(Vector3(192, Land.BASE_Y, 124), 20.0, 30.0, 26.0)
	await frames(10)
	await shot("dry")
	game.city.cozy_v = 1
	w.force = 1.0
	var t0 := Time.get_ticks_msec()
	while w.wet < 0.95 and Time.get_ticks_msec() - t0 < 15000:
		await frames(5)
	check(w.level > 0.8 and w.wet > 0.9 and w.rain.emitting, "дождь идёт: сила %.2f, земля мокрая %.2f" % [w.level, w.wet])
	await shot("rain")
	w.force = 0.0
	await frames(240)
	check(w.level < 0.5 and w.wet > 0.3, "дождь кончился, земля ещё сохнет (%.2f / %.2f)" % [w.level, w.wet])
	await shot("after")
	print("WEATHER DONE fails=%d" % fails)
	get_tree().quit()
