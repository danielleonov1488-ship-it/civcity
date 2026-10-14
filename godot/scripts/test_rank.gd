extends Node
## Проверка ролика «Новый ранг» (scripts/rank_cine.gd): станция по уровням 0/1/2; обычный путь; пропуск по Esc;
## ролик позже (открыто меню); сразу два ранга. Снимки — в .work/gd/rank_*.png и station_t*.png
var game
var out := "D:/CivCity/.work/gd/"
var fails := 0
var t0 := 0


func _ready() -> void:
	Game.boot = {"new": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func now() -> float:
	return (Time.get_ticks_msec() - t0) / 1000.0


func until(sec: float) -> void:
	while now() < sec:
		await get_tree().process_frame


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print(("  ok   " if ok else "  FAIL ") + what)


func shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(out + name)
	var rc = game.rank_cine
	print("SHOT ", name, " t=%.2f" % now(), " phase=", rc.cine.get("phase", "-"), " lvl=", game.city.level, " fps=", Engine.get_frames_per_second())


## Ждать, пока ролик начнётся / кончится (не дольше sec)
func wait_cine(on: bool, sec: float) -> bool:
	var start := now()
	while (game.rank_cine.cine.is_empty() == on) and now() - start < sec:
		await get_tree().process_frame
	return game.rank_cine.cine.is_empty() != on


func rank_up(pop: int, happy: int) -> void:
	var c: City = game.city
	c.stats["pop"] = pop
	c.stats["happy"] = happy
	c._update_level()


## Всё вернулось как было до ролика
func check_after(what: String, pose0: Array, speed0: float, want_lvl: int) -> void:
	await frames(4)
	var c: City = game.city
	var rig = game.rig
	var hud = game.hud
	check(hud.visible and is_equal_approx(hud.root.modulate.a, 1.0), what + ": интерфейс виден, непрозрачен")
	check(not rig.cine, what + ": камера снова у игрока")
	check(is_equal_approx(float(game.speed), speed0), what + ": скорость вернулась (%s)" % game.speed)
	check(int(c.tips.get("rank_cine", -1)) == want_lvl, what + ": tips.rank_cine == %d (%s)" % [want_lvl, c.tips.get("rank_cine")])
	var ctr := c.center()
	check(int(ctr["tier"]) == want_lvl and game.visuals.has(ctr["id"]), what + ": станция на уровне %d и нарисована" % want_lvl)
	check(game.rank_cine.ui == null, what + ": полосы и табличка убраны")
	var p: Array = rig.pose()
	check((p[0] as Vector3).distance_to(pose0[0]) < 0.3 and rig.cam.global_position.distance_to(p[0]) < 0.6,
		what + ": камера там же, где была (%.2f м)" % rig.cam.global_position.distance_to(p[0]))
	check(not hud.pause_panel.visible, what + ": меню паузы не открылось")


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	var c: City = game.city
	var hud = game.hud
	var rc = game.rank_cine
	var rig = game.rig
	game.can_save = false                # тест не пишет сохранение
	if game.tutorial.active():           # обучение не нужно (finish() записал бы настройки игрока)
		game.tutorial.step = Tutorial.STEPS.size()
		game.tutorial.card.visible = false
		c.tips["tut"] = -1
		c.tips["ui"] = 3
		hud.apply_reveal(3)
	hud.advisor_panel.visible = false
	game._set_hour(10.5)
	hud.set_speed(0.0)
	await frames(20)
	var ctr := c.center()
	var cid: int = ctr["id"]
	check(int(c.tips.get("rank_cine", -1)) == 0, "новая игра: tips.rank_cine = 0")
	# ---------- станция по уровням: 0, 1, 2 ----------
	var sp: Vector2 = ctr["pos"]
	hud.visible = false
	for t in 3:
		ctr["tier"] = t
		game._show(ctr)
		rig.set_view(Vector3(sp.x, float(ctr["y"]) + 2.0, sp.y), rad_to_deg(float(ctr["yaw"])) - 28.0, 22.0, 24.0)
		await frames(12)
		print("station tier ", t, " top=%.2f" % c.blueprint(ctr).top_y())
		shot("station_t%d.png" % t)
	ctr["tier"] = 0
	game._show(ctr)
	hud.visible = true
	# ---------- старые сохранения: уже полученный ранг не показываем; недосмотренный — покажем ----------
	c.level = 1
	c.tips.erase("rank_cine")
	var m1 = Game.RankCineScript.new()
	m1.setup(game)
	check(int(c.tips.get("rank_cine", -1)) == 1 and m1.pending.is_empty(), "старое сохранение на хуторе: ролик не повторяется")
	c.tips["rank_cine"] = 0
	var m2 = Game.RankCineScript.new()
	m2.setup(game)
	check(m2.pending == {"from": 0, "to": 1, "late": true}, "вышли, не досмотрев: ролик в очереди (%s)" % m2.pending)
	m1.free()
	m2.free()
	c.level = 0
	c.tips["rank_cine"] = 0
	rc.force = true
	rig.set_view(Vector3(sp.x + 14.0, Land.BASE_Y, sp.y + 30.0), 15.0, 42.0, 40.0)
	hud.set_speed(2.0)
	await frames(20)
	var pose0: Array = rig.pose()

	# ---------- 1. обычный путь ----------
	print("== обычный путь")
	var vis0 = game.visuals[cid]
	var notes0: int = hud.notes_box.get_child_count()
	var bell0: int = hud.bell_count
	t0 = Time.get_ticks_msec()
	rank_up(40, 60)
	check(c.level == 1, "уровень 1 (Хутор)")
	check(rc.holds_station(), "станция придержана до ролика")
	check(is_same(game.visuals[cid], vis0), "старая станция ещё стоит")
	check(hud.notes_box.get_child_count() == notes0 and hud.bell_count == bell0 + 1, "всплывашки нет, событие в колокольчике")
	var started: bool = await wait_cine(true, 0.6)
	check(started and rc.cine.get("phase", "") == "glide", "ролик начался с подлёта (через %.2f с)" % now())
	var ghost = rc.cine.get("ghost")
	check(ghost != null and not (ghost as Node3D).visible, "призрак новой станции собран заранее и спрятан")
	# снимки — по часам ролика: сохранение снимка тормозит кадр, а шаг ролика не больше 0,05 с
	var d0 := now()
	var phase := ""
	var last_t := 0.0
	var marks := [0.8, 1.9, 2.8, 4.3, 6.0, 9.0]
	for i in marks.size():
		while not rc.cine.is_empty() and d0 + float(rc.cine["t"]) < marks[i]:
			last_t = float(rc.cine["t"])
			var ph: String = rc.cine["phase"]
			if ph != phase:
				print("  phase ", ph, " at %.2f" % (d0 + last_t))
				phase = ph
			await get_tree().process_frame
		if rc.cine.is_empty():
			await frames(3)
		shot("rank_%d_%.1f.png" % [i + 1, marks[i]])
		if i == 3:
			check(rc.cine.get("shown", false) and float((rc.cine["head"] as Control).modulate.a) > 0.5, "к 4,3 с станция встала, табличка видна")
	var done_ok: bool = await wait_cine(false, 4.0)
	check(done_ok and d0 + last_t <= 9.0, "ролик кончился к 9 с (по часам ролика %.2f с)" % (d0 + last_t))
	check(ghost == null or not is_instance_valid(ghost), "призрака не осталось")
	await check_after("обычный путь", pose0, 2.0, 1)
	check(hud.advisor_panel.visible and hud.adv_title.text == "Город стал хутором!", "советник: «%s»" % hud.adv_title.text)
	print("  advisor: ", hud.adv_text.text.replace("\n", " / "))
	shot("rank_7_advisor.png")
	hud.advisor_panel.visible = false

	# ---------- 2. пропуск по Esc ----------
	print("== пропуск по Esc")
	t0 = Time.get_ticks_msec()
	rank_up(60, 60)
	check(c.level == 2, "уровень 2 (Деревня)")
	started = await wait_cine(true, 0.6)
	check(started, "ролик начался")
	await until(now() + 1.0)
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	var t_esc := now()
	get_viewport().push_input(ev)
	var ev2 := InputEventKey.new()
	ev2.keycode = KEY_ESCAPE
	ev2.pressed = false
	get_viewport().push_input(ev2)
	check(rc.cine.get("phase", "") == "back", "Esc — сразу возврат")
	var ended: bool = await wait_cine(false, 3.0)
	check(ended and now() - t_esc <= 1.2, "ролик кончился через %.2f с после Esc" % (now() - t_esc))
	await check_after("пропуск", pose0, 2.0, 2)
	hud.advisor_panel.visible = false

	# ---------- 3. ролик позже: открыто меню паузы ----------
	print("== открыто меню")
	hud._toggle(hud.pause_panel)
	check(hud.pause_panel.visible, "меню паузы открыто")
	notes0 = hud.notes_box.get_child_count()
	vis0 = game.visuals[cid]
	t0 = Time.get_ticks_msec()
	rank_up(180, 60)
	check(c.level == 3, "уровень 3 (Посёлок)")
	check(not rc.holds_station() and bool(rc.pending.get("late", false)), "ролик отложен, станцию не держит")
	check(not is_same(game.visuals[cid], vis0) and int(c.center()["tier"]) == 3, "станция сразу стала новой")
	check(hud.notes_box.get_child_count() == notes0, "всплывашки нет и тут")
	await until(1.5)
	check(rc.cine.is_empty(), "пока меню открыто — ролика нет")
	hud._toggle(hud.pause_panel)
	var t_close := now()
	started = await wait_cine(true, 1.0)
	check(started and now() - t_close <= 0.5 and rc.cine.get("phase", "") == "fade",
		"меню закрыли — ролик с затемнения через %.2f с" % (now() - t_close))
	for m in [0.3, 1.2, 3.6, 5.2]:
		while not rc.cine.is_empty() and float(rc.cine["t"]) < m:
			await get_tree().process_frame
		shot("rank_late_%.1f.png" % m)
	ended = await wait_cine(false, 8.0)
	check(ended, "поздний ролик кончился")
	await check_after("поздний ролик", pose0, 2.0, 3)

	# ---------- 4. сразу два ранга ----------
	print("== сразу два ранга")
	c.level = 0
	c.tips["rank_cine"] = 0
	ctr["tier"] = 0
	game._show(ctr)
	await frames(5)
	t0 = Time.get_ticks_msec()
	rank_up(60, 60)
	check(c.level == 2 and int(rc.pending.get("from", -1)) == 0 and int(rc.pending.get("to", -1)) == 2, "0 → 2: один ролик в очереди")
	started = await wait_cine(true, 0.6)
	check(started and int(rc.cine["from"]) == 0 and int(rc.cine["to"]) == 2, "ролик 0 → 2")
	while not rc.cine.is_empty() and not rc.cine.get("said", false):
		await get_tree().process_frame
	var said: String = (rc.cine["sub"] as Label).text if not rc.cine.is_empty() else ""
	check(said.contains("сразу 2 ранга"), "подпись: «%s»" % said)
	await until(now() + 0.8)
	shot("rank_double.png")
	ended = await wait_cine(false, 8.0)
	check(ended, "ролик кончился")
	await check_after("два ранга", pose0, 2.0, 2)
	check(hud.advisor_panel.visible and hud.adv_title.text == "Город стал деревней!", "советник: «%s»" % hud.adv_title.text)
	print("  advisor: ", hud.adv_text.text.replace("\n", " / "))
	print("RANK DONE fails=", fails)
	get_tree().quit()
