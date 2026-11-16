extends Node3D
## PERF3: очередь поз, фаза, пауза, смена клипа, выход/вход в кадр и близкие снимки.
## Только стенд: сохранения выключены; запускает Claude, не агент редактирования.

var game
var fails := 0
var out := "D:/CivCity/.work/stage5/perf3/shots"
var figures: Array[Citizen] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=")
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	game.can_save = false
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, message: String) -> void:
	if not ok:
		fails += 1
		print("PERF3 FAIL ", message)


func _reset(c: Citizen, clip := "Walk", phase := 0.2) -> void:
	c.batch_acc = 0.0
	c.batch_hidden = false
	c.batch_dirty = false
	c.batch_on = true
	c.batch_steps = 0
	c.anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	c.anim.speed_scale = 1.0
	c.play(clip, 0.0)
	c.anim.seek(phase, true)


func _phase(c: Citizen, expected: float, message: String) -> void:
	var length: float = c.anim.current_animation_length
	var actual: float = c.anim.current_animation_position
	var error := absf(wrapf(actual - fposmod(expected, length), -length * 0.5, length * 0.5))
	check(error < 0.0001, message + " phase error %.6f" % error)


func _clock_tests(c: Citizen) -> void:
	_reset(c)
	for f in 64:
		c.anim.advance(1.0 / 120.0)
	var sk: Skeleton3D = c.hair_att.get_parent() as Skeleton3D
	var poses: Array[Transform3D] = []
	for b in sk.get_bone_count():
		poses.append(sk.get_bone_pose(b))
	for k: int in [1, 2, 4, 8]:
		_reset(c)
		for f in range(1, 65):
			c.batch_step(1.0 / 120.0, k, f, false)
		check(c.batch_steps == 64 / k, "advance count k=%d: %d" % [k, c.batch_steps])
		c.batch_flush()
		_phase(c, 0.2 + 64.0 / 120.0, "round robin k=%d" % k)
		for b in sk.get_bone_count():
			check(sk.get_bone_pose(b).is_equal_approx(poses[b]), "same bone pose k=%d bone=%d" % [k, b])
	_reset(c)
	var expected := 0.2
	for speed: float in [1.0, 3.0, 0.0, 2.0]:
		c.anim.speed_scale = speed
		for f in range(1, 12):
			expected += speed / 120.0
			c.batch_step(1.0 / 120.0, 4, f, false)
	c.batch_flush()
	_phase(c, expected, "speed and pause")
	_reset(c)
	for f in range(1, 65):
		c.batch_step(1.0 / 120.0, 8, f, true)
	check(c.batch_steps == 0, "offscreen must not write skeleton pose")
	_phase(c, 0.2, "offscreen holds pose")
	c.batch_step(0.0, 8, 65, false)
	_phase(c, 0.2 + 64.0 / 120.0, "reentry catches up immediately")
	_reset(c)
	c.batch_step(0.25, 8, 1, true)
	c.play("Idle", 0.0, 0.25)
	check(is_zero_approx(c.batch_acc), "old clip time cleared on hidden clip change")
	c.batch_step(0.0, 8, 1, false)
	_phase(c, c.anim.current_animation_length * 0.25, "new clip phase on reentry")
	check(not c.batch_dirty, "reentry applies new pose even at dt=0")
	c.batch_release()
	check(not c.batch_on and c.anim.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE, "pvat=0 restores automatic player")
	_reset(c)


func _resident_tests() -> void:
	var ppl: People = game.people
	var family: Array = ppl._make_family("PERF3", 8, -1, Land.START, "plebs")
	var old_cap := ppl.max_vis
	ppl.max_vis += 16
	var first: Dictionary = family[0]
	var c: Citizen = ppl._node(first)
	check(c != null, "resident node created")
	if c:
		c.lod_k = 1
	# Время идёт вручную: без расписания и перемещения настоящих жителей.
	for f in 16:
		ppl._sim_time += 1.0 / 60.0
		ppl._far_ph = (ppl._far_ph + 1) % ppl.far_n
		ppl._lod_frame += 1
		ppl._residents_batch(1.0, 1)
	for r: Dictionary in family:
		check(ppl._sim_time - float(r["sim_at"]) < ppl.far_n / 60.0 + 0.0001, "invisible queue catches up")
	# Удаление текущего жителя во время обхода не должно пропускать следующего.
	first["state"] = "walk"
	first["goal"] = "leave"
	first["path"] = PackedVector2Array()
	ppl._sim_time += 1.0 / 60.0
	ppl._residents_batch(1.0, 1)
	check(not ppl.by_id.has(first["id"]), "resident removed inside iteration")
	for r: Dictionary in family:
		if ppl.by_id.has(r["id"]):
			ppl._remove(r)
	ppl.max_vis = old_cap


func _lod_tests(c: Citizen) -> void:
	var at := c.global_position
	game.rig.set_view(at, 15.0, 35.0, 9.0)
	await frames(2)
	game.gfx._anims(1.0 / 60.0)
	check(c.lod_k == 1, "large character advances every frame")
	game.rig.set_view(at, 15.0, 35.0, 60.0)
	await frames(2)
	game.gfx._anims(1.0 / 60.0)
	check(c.lod_k >= 2, "small character batches")
	_reset(c)
	var cam: Camera3D = game.rig.cam
	c.global_position = cam.global_position + cam.global_basis.z * 10.0
	for f in 8:
		game.gfx._anims(1.0 / 60.0)
	check(c.batch_hidden and c.batch_steps == 0, "Gfx skips offscreen skeleton")
	c.global_position = at
	game.gfx._anims(0.0)
	check(not c.batch_hidden and c.batch_steps == 1, "Gfx restores pose on return")
	_phase(c, 0.2 + 8.0 / 60.0, "Gfx reentry phase")


func _image() -> Image:
	await frames(240)
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _shots() -> void:
	Engine.time_scale = 0.0
	MeadowNature.freeze(true)
	for view: Array in [["close", 9.0, 1], ["mid", 30.0, 2]]:
		var at := Vector3(Land.START.x, game.land.height_at(Land.START.x, Land.START.y), Land.START.y)
		game.rig.set_view(at, 15.0, 35.0, float(view[1]))
		var before: Image
		for on: bool in [false, true]:
			for c: Citizen in figures:
				_reset(c, c._cur, 0.2)
				for f in range(1, 121):
					if on:
						c.batch_step(1.0 / 60.0, int(view[2]), f, false)
					else:
						c.anim.advance(1.0 / 60.0)
				c.batch_flush()
				c.anim.speed_scale = 0.0
			var img: Image = await _image()
			var path := out.path_join("fixture_%s_pvat%d.png" % [view[0], int(on)])
			check(img.save_png(path) == OK, "save " + path)
			print("PERF3 SHOT ", path)
			if not on:
				before = img
			else:
				var diff: Dictionary = preload("res://scripts/test_perf.gd")._same(before, img)
				print("PERF3 diff %s mean=%.4f limit=1.5" % [view[0], diff["mean"]])
				check(float(diff["mean"]) < 1.5, "close/mid visual equivalence")
	Engine.time_scale = 1.0
	MeadowNature.freeze(false)


func _run() -> void:
	var waited := 0
	while not game.ready_done:
		await frames(5)
		waited += 5
		if waited >= 18000:
			check(false, "ready_done timeout")
			get_tree().quit(1)
			return
	game.can_save = false
	game.settings["autosave"] = false
	game.speed = 0.0
	game.clock_hours = false
	game.hud.visible = false
	game.rig.cine = true
	game.people.set_process(false)
	game.gfx.set_process(false)
	game.settings["quality"] = "high"
	game._apply_quality()
	await frames(30)
	check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory")
	_resident_tests()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7361
	var clips := ["Walk", "Idle", "Idle_Talking", "Push", "Sitting_Idle", "Walk_Carry"]
	var roster_before: int = game.gfx._anim_list.size()
	for i in clips.size():
		var c := Citizen.create(rng, i % 2 == 1, i == 4, i == 2)
		game.actors_root.add_child(c)
		figures.append(c)
		c.position = Vector3(Land.START.x - 2.0 + i * 0.8, 0.0, Land.START.y)
		c.position.y = game.land.height_at(c.position.x, c.position.z)
		c.rotation.y = 0.3
		_reset(c, clips[i])
		if i == 3:
			Citizen.elder_look(c)
	HandProps.hold(figures[5], ["cup"], "Walk_Carry")
	check(game.gfx._anim_list.size() == roster_before + figures.size(), "roster registers added actors")
	_clock_tests(figures[0])
	_reset(figures[0], "Walk")
	await _lod_tests(figures[0])
	await _shots()
	var count: int = game.gfx._anim_list.size()
	figures[0].queue_free()
	await frames(2)
	check(game.gfx._anim_list.size() == count - 1, "roster removes freed actors")
	print("PERF3 DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
