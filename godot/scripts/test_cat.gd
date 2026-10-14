extends Node3D
## Кошки рядом с жителем в настоящей игре и её свете. Запуск: bash .work/py/gpu_run.sh res://test_cat.tscn
## Слева — прежние кошки из Kit, справа — новые (модель Quaternius) того же окраса и в той же позе:
## идёт, сидит, гладят, спит → cats_day.png, cats_night.png; все окрасы во всех позах → cats_poses_day/night.png;
## крупно новые → cats_close.png, спящие → cats_sleep.png, как видно в игре → cats_zoom.png. Проверки: модель загрузилась, пауза останавливает движение, скорость — как у игры.
var game
var fails := 0
const X0 := 186.0
const Z0 := 140.0
const OUT := "D:/CivCity/.work/gd/"


func _ready() -> void:
	Game.boot = {"new": "1", "noui": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, what: String) -> void:
	print("CAT %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


## Сид, при котором первый rng.randi() даёт нужный окрас (и прежняя, и новая кошка берут окрас первым)
func _seed_for(fur: int) -> int:
	var r := RandomNumberGenerator.new()
	for s in range(1, 1000):
		r.seed = s
		if r.randi() % People.CAT_FURS.size() == fur:
			return s
	return 1


func _cat(home: Dictionary, fur: int, kit: bool, p: Vector2, yaw: float, state: String) -> Dictionary:
	var ppl = game.people
	ppl.rng.seed = _seed_for(fur)
	var c: Dictionary = ppl._make_cat_kit(home) if kit else ppl._make_cat(home)
	c["p"] = p
	c["yaw"] = yaw
	c["state"] = state
	c["walk"] = 1.0 if state == "walk" else 0.0
	ppl._cat_place(c)
	if c.has("anim"):
		c["clip"] = ""
		ppl._cat_anim(c)
		(c["anim"] as AnimationPlayer).seek(0.45, true)
	else:
		for i in 3:
			ppl._cat_kit_anim(c, 1.0, 0.13)
	ppl.cats.append(c)
	return c


func _person(seed: int, p: Vector2, yaw: float, clip: String, child := false) -> Citizen:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var c := Citizen.create(rng, seed % 2 == 0, child)
	game.actors_root.add_child(c)
	c.position = Vector3(p.x, game.land.height_at(p.x, p.y), p.y)
	c.rotation.y = yaw
	c.play(clip, 0.0)
	c.anim.seek(0.8, true)
	c.anim.speed_scale = 0.0
	return c


func _shot(name: String, look: Vector3, off: Vector3) -> void:
	look.y = game.land.height_at(look.x, look.z) + look.y
	game.rig.cine_look(look + off, look)
	await frames(45)
	get_viewport().get_texture().get_image().save_png(OUT + name)
	print("CAT saved ", OUT + name)


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	game.hud.visible = false
	game.speed = 0.0
	game.clock_hours = false
	game.rig.cine = true
	var ppl = game.people
	var city = game.city
	check(People._cat_model_ok(), "модель кошки загрузилась (%s)" % People.CAT_FILE)
	if People._cat_lib:
		print("CAT clips ", People._cat_lib.get_animation_list(), " size ", People._cat_size)
	# дом для кошек и мостовая под ними; деревья и кусты вокруг убрать — не заслоняют
	game.clear_nature(Vector2(X0 + 6.0, Z0 + 2.0), 16.0)
	game.land.paint_line(Vector2(X0 - 5.0, Z0 + 0.3), Vector2(X0 + 17.0, Z0 + 0.3), 3.2, Land.Kind.PLAZA, true)
	var home := {}
	for z in range(int(Z0) - 10, int(Z0) - 4):
		var pl: Dictionary = game.placement("house_pleb", Vector2(X0, z))
		if pl["err"] == "":
			home = city.place("house_pleb", pl["pos"], pl["yaw"], pl["variant"], pl["color"])
			break
	if home.is_empty():
		home = city.buildings.values()[0]
	await frames(5)
	# прежние слева, новые справа, житель посередине; пары одного окраса: идёт, сидит, гладят, спит
	var side := PI / 2 + 0.45                         # три четверти к камере
	var pairs := [[0, "walk"], [1, "sit"], [5, "pet"], [3, "sleep"]]
	for i in pairs.size():
		var fur: int = pairs[i][0]
		var st: String = pairs[i][1]
		_cat(home, fur, true, Vector2(X0 - 4.4 + i * 1.0, Z0 + 0.2), side, st)
		_cat(home, fur, false, Vector2(X0 + 0.8 + i * 0.75, Z0 + 0.2), side, st)
	_person(11, Vector2(X0 - 0.05, Z0 - 0.1), 0.25, "Idle_Loop")
	# гладят: ребёнок присел у кошки (у прежней и у новой)
	_person(12, Vector2(X0 - 4.4 + 2 * 1.0 + 0.05, Z0 - 0.35), -0.1, "Crouch_Idle", true)
	_person(14, Vector2(X0 + 0.8 + 2 * 0.75 + 0.05, Z0 - 0.3), -0.1, "Crouch_Idle", true)
	# все окрасы во всех позах — только новые
	var states := ["walk", "sit", "pet", "sleep"]
	for f in People.CAT_FURS.size():
		for s in states.size():
			_cat(home, f, false, Vector2(X0 + 9.0 + f * 0.75, Z0 - 0.6 + s * 0.75), side, states[s])
	await frames(10)
	# где кости у новой кошки в каждой позе (в единицах модели): для подгонки поз
	for st: String in states:
		var cc: Dictionary = ppl.cats[8 + states.find(st)]
		var sk: Skeleton3D = (cc["n"] as Node3D).find_children("*", "Skeleton3D", true, false)[0]
		var s := ""
		for bn in ["Bone", "Bone.003", "Bone.003_end", "Bone.016", "Bone.010", "Bone.004", "Bone.005", "Bone.006", "Bone.007", "Bone.007_end"]:
			var o := sk.get_bone_global_pose(sk.find_bone(bn)).origin * 100.0
			s += "%s(%.2f,%.2f,%.2f) " % [bn.trim_prefix("Bone"), o.x, o.y, o.z]
		print("CAT bones %s: %s" % [st, s])
	for h: Array in [[12.5, "day"], [22.5, "night"]]:
		game._set_hour(float(h[0]))
		await frames(5)
		await _shot("cats_%s.png" % h[1], Vector3(X0 - 0.85, 0.45, Z0 + 0.2), Vector3(0.0, 1.5, 8.0))
		await _shot("cats_poses_%s.png" % h[1], Vector3(X0 + 10.9, 0.2, Z0 + 0.5), Vector3(0.0, 2.6, 4.6))
	game._set_hour(12.5)
	await _shot("cats_zoom.png", Vector3(X0 - 0.5, 0.3, Z0 + 0.2), Vector3(0.0, 8.0, 12.0))      # обычный крупный план игры
	await _shot("cats_sleep.png", Vector3(X0 + 10.0, 0.08, Z0 + 1.65), Vector3(0.6, 1.1, 2.0))
	await _shot("cats_close.png", Vector3(X0 + 1.9, 0.18, Z0 + 0.2), Vector3(0.0, 0.85, 2.9))
	# пауза: движение стоит; ход — идёт со скоростью игры
	var c: Dictionary = ppl.cats[ppl.cats.size() - 1]
	var ap: AnimationPlayer = c.get("anim")
	if ap:
		game.speed = 1.0
		await frames(20)
		var p0 := ap.current_animation_position
		var k1 := ap.speed_scale
		game.speed = 3.0
		await frames(5)
		check(is_equal_approx(ap.speed_scale, k1 * 3.0) and k1 > 0.0, "скорость движения — как у игры (x1 %.2f, x3 %.2f)" % [k1, ap.speed_scale])
		game.speed = 0.0
		await frames(3)
		p0 = ap.current_animation_position
		await frames(20)
		check(ap.speed_scale == 0.0 and is_equal_approx(p0, ap.current_animation_position), "пауза останавливает кошек")
		# шаг: лапы не скользят — скорость клипа × длина шага = скорость кошки
		var w: Dictionary = ppl.cats[16]
		print("CAT walk k=%.2f clip=%s" % [float(w.get("k", 0.0)), w.get("clip", "")])
	print("CAT DONE fails=%d cats=%d" % [fails, ppl.cats.size()])
	get_tree().quit()
