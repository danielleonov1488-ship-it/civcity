extends Node3D
## Времена года в живой игре (готовый город demo): в старом городе всегда лето; в «новой игре» листва и трава
## меняются по календарю, осенью с деревьев у взгляда падают листья. Снимки лета, осени, зимы и весны с одной точки.
## Запуск: bash .work/py/gpu_run.sh res://test_seasons.tscn -- [out=D:/CivCity/.work/seasons]
var game
var fails := 0
var out := "D:/CivCity/.work/seasons"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	Game.boot = {"demo": "1", "noui": "1", "seasons": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, what: String) -> void:
	print("SEASONS %s %s" % ["PASS" if ok else "FAIL", what])
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
	var s: Seasons = game.seasons
	check(s != null and s.now == Vector4.ZERO, "времена года заведены, в старом городе — лето")
	check(not Synty.season_mats.is_empty(), "у деревьев материал с временами года (%d)" % Synty.season_mats.size())
	# календарь
	check(Seasons.id_of(0) == "winter" and Seasons.id_of(7) == "spring" and Seasons.id_of(13) == "summer" and Seasons.id_of(19) == "autumn", "календарь: зима, весна, лето, осень")
	var w := Seasons.weights(Seasons.month(19))
	check(w.x > 0.9 and w.y < 0.01 and w.z < 0.01, "середина осени — только осень (%s)" % str(w))
	check(Seasons.weights(Seasons.month(14)) == Vector4.ZERO, "летом всё как было")
	game._set_hour(11.0)
	var at := _tree_spot()
	game.rig.set_view(at, 16.0, 30.0, 32.0)
	await frames(20)
	await shot("summer")
	var grove := _grove()
	game.rig.set_view(grove, 9.0, 35.0, 24.0)
	await frames(12)
	await shot("summer_grove")
	game.rig.set_view(at, 16.0, 30.0, 32.0)
	game.city.cozy_v = 1
	for e: Array in [["autumn", 10.0], ["winter", 0.8], ["spring", 3.8]]:
		s.force_m = float(e[1])
		s._scan_t = 0.0
		await frames(90 if e[0] == "autumn" else 20)
		if e[0] == "autumn":
			var on := 0
			for p: GPUParticles3D in s.leaves:
				if p.emitting:
					on += 1
			check(s.now.x > 0.9 and on > 0, "осень: листва рыжая, листья падают с %d деревьев" % on)
		await shot(String(e[0]))
		game.rig.set_view(grove, 9.0, 35.0, 24.0)
		await frames(12)
		await shot(String(e[0]) + "_grove")
		game.rig.set_view(at, 16.0, 30.0, 32.0)
	s.force_m = -1.0
	game.city.day = 13
	await frames(10)
	check(s.now == Vector4.ZERO, "лето по календарю — всё как было")
	print("SEASONS DONE fails=%d" % fails)
	get_tree().quit()


## Точка у рощи возле города (там видно и деревья, и траву, и дома)
func _tree_spot() -> Vector3:
	var best := Vector3(192, Land.BASE_Y, 124)
	var bd := 1e9
	for key in game.nature:
		for it: Dictionary in game.nature[key]:
			if not String(it["name"]).begins_with("SM_Env_Tree"):
				continue
			var o: Vector3 = (it["xf"] as Transform3D).origin
			var d := Vector2(o.x - 192, o.z - 124).length()
			if d > 18.0 and d < bd:
				bd = d
				best = o
	return best


## Роща лиственных деревьев (где их больше всего на 6 м вокруг) — крупный план листвы
func _grove() -> Vector3:
	var pts := []
	for key in game.nature:
		for it: Dictionary in game.nature[key]:
			var nm := String(it["name"])
			if nm.begins_with("SM_Env_Tree_0") or nm.begins_with("SM_Env_Tree_Large"):
				pts.append((it["xf"] as Transform3D).origin)
	var best := Vector3(192, Land.BASE_Y, 124)
	var bn := -1
	for i in range(0, pts.size(), 3):
		var n := 0
		for q: Vector3 in pts:
			if q.distance_to(pts[i]) < 6.0:
				n += 1
		if n > bn:
			bn = n
			best = pts[i]
	return best
