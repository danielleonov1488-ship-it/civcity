extends Node
## Проверка обучения: шаги по порядку, постепенный интерфейс, стрелка
var game
var out := "D:/CivCity/.work/gd/"

func _ready() -> void:
	Game.boot = {"new": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func shot(name: String) -> void:
	await frames(3)
	get_viewport().get_texture().get_image().save_png(out + name)
	print("SHOT ", name, " step=", game.tutorial.cur_id(), " ui=", game.city.tips.get("ui"), " pop=", game.city.stats["pop"])

func wait_step(id: String, maxf := 3000) -> void:
	var t := 0
	while game.tutorial.cur_id() != id and t < maxf:
		await frames(5)
		t += 5
	if game.tutorial.cur_id() != id:
		print("STUCK want ", id, " at ", game.tutorial.cur_id())

func put(type: String, near: Vector2) -> void:
	for k in 40:
		var p := near + Vector2(randf_range(-6, 6), randf_range(-6, 6))
		var pl: Dictionary = game.placement(type, p)
		if pl["err"] == "":
			game.city.place(type, pl["pos"], pl["yaw"], pl["variant"], pl["color"])
			return
	print("FAILED ", type)

func _run() -> void:
	while not game.ready_done:
		await frames(5)
	var c: City = game.city
	Tutorial.start_new(c)
	game.tutorial._enter(0)
	game.hud.advisor_panel.visible = false
	await frames(30)
	await shot("t1_move.png")
	game.rig._target_t += Vector3(10, 0, 4)
	await wait_step("turn")
	game.rig._yaw_t += 1.0
	await wait_step("road")
	await frames(20)
	await shot("t2_road.png")
	var ctr := c.center()
	var dp: Vector2 = c.door_point(ctr)
	game.set_tool("road")
	game.painting = true
	game.stroke = []
	game.stroke_cost = 0.0
	game.brush_line = false
	for k in 60:
		game._paint_at(dp + Vector2(0, 2 + k * 0.5))
	game._release()
	game.people.refresh(game.land.road_chunks.keys())
	game.set_tool("")
	await wait_step("houses")
	await frames(10)
	await shot("t3_houses.png")
	for k in 3:
		put("house_pleb", dp + Vector2(4, 10 + k * 6))
	await wait_step("cart")
	# окно свернули посреди ролика с повозкой: ролик ждёт, развернули — идёт дальше
	var tut = game.tutorial
	var w := 0
	while tut.cine.is_empty() and w < 600:
		await frames(5)
		w += 5
	if tut.cine.is_empty():
		print("CINE MIN FAIL ролик с повозкой не начался")
	else:
		await frames(20)
		game.minimized_test = true
		await frames(3)
		var ct := float(tut.cine.get("t", -1.0))
		await frames(40)
		var frozen: bool = not tut.cine.is_empty() and is_equal_approx(float(tut.cine["t"]), ct) and game.speed == 0.0
		game.minimized_test = false
		await frames(5)
		var goes: bool = tut.cine.is_empty() or float(tut.cine["t"]) > ct
		print("CINE MIN ", "PASS" if frozen and goes else "FAIL", " frozen=", frozen, " goes=", goes, " speed=", game.speed)
	await frames(60)
	await shot("t4_cart.png")
	await wait_step("settle")
	await frames(30)
	await shot("t5_settle.png")
	game.start_settle(c.arrivals[0]["name"])
	await frames(10)
	game.settle_auto()
	await wait_step("house")
	await frames(30)
	await shot("t6_house.png")
	for id in c.buildings:
		if c.is_house(c.buildings[id]):
			game.select_building(c.buildings[id])
			game.hud.open_info(c.buildings[id])
			break
	await wait_step("food")
	game.hud.close_panels()
	await frames(10)
	await shot("t7_food.png")
	put("stall_fruit", dp + Vector2(-4, 14))
	await wait_step("workers")
	await frames(10)
	await shot("t8_workers.png")
	game.tutorial.next_btn.emit_signal("pressed")
	await wait_step("script")
	put("scriptorium", dp + Vector2(-5, 24))
	await wait_step("research")
	await frames(10)
	await shot("t9_research.png")
	c.rp = maxf(c.rp, 50)
	c.do_research("deco_flowers")
	await wait_step("done")
	await frames(10)
	await shot("t10_done.png")
	game.tutorial.next_btn.emit_signal("pressed")
	await frames(60)
	await shot("t11_full.png")
	await _arrow_after()
	print("done tut=", c.tips, " arrivals=", c.arrivals, " pending=", c.pending.keys(), " incoming=", c.incoming, " settled=", c.settled_total)
	get_tree().quit()


func check(ok: bool, what: String) -> void:
	print(("PTR PASS " if ok else "FAIL ") + what)


## Отзывы игроков 27.10: после обучения стрелка сама показывает только первые просьбы (до «Хутора» включительно);
## город стал хутором — сама больше не показывает; щелчок по строке просьбы — стрелка на несколько секунд, потом гаснет
func _arrow_after() -> void:
	var c: City = game.city
	var hud = game.hud
	game.set_tool("")
	hud.advisor_panel.visible = false
	var g0: Dictionary = c.active_goals(1)[0] if not c.active_goals(1).is_empty() else {}
	hud._update_pointer()
	var want = hud._request_target(g0)["target"] if not g0.is_empty() else null
	check(c.level == 0 and not g0.is_empty() and hud.early_request(g0) and hud.pointer_target == want,
		"после обучения, до «Хутора»: стрелка к просьбе «%s» сама (%s)" % [g0.get("text", ""), hud.pointer_target])
	# стал хутором
	c.level = 1
	for g in Defs.REQUESTS:
		if not c.goals_done.has(g["id"]):
			c.goals_done.append(g["id"])
		if g["id"] == "hamlet":
			break
	hud.refresh()
	await frames(5)
	hud._update_pointer()
	var g1: Dictionary = c.active_goals(1)[0]
	check(hud.pointer_target == null and not hud.pointer.visible, "«Хутор»: просьба «%s» — стрелка сама не показывает (%s)" % [g1["text"], hud.pointer_target])
	# щелчок по строке просьбы — стрелка на несколько секунд
	var tb: Button = null
	for row in hud.tasks_box.get_children():
		if row is MarginContainer:
			for l in row.find_children("*", "Label", true, false):
				if (l as Label).text == String(g1["text"]):
					for b in row.get_children():
						if b is Button:
							tb = b
	check(tb != null, "строка «%s» в свитке" % g1["text"])
	if tb == null:
		return
	tb.pressed.emit()
	var t0 := Time.get_ticks_msec()
	await frames(5)
	check(hud.pointer_target != null and hud.pointer.visible, "щелчок по строке — стрелка показалась (%s)" % hud.pointer_target)
	await shot("t12_arrow_click.png")
	while hud.pointer_target != null and Time.get_ticks_msec() - t0 < Hud.PTR_SHOW_MS + 3000:
		await frames(5)
	var dt := (Time.get_ticks_msec() - t0) / 1000.0
	check(hud.pointer_target == null and dt >= Hud.PTR_SHOW_MS / 1000.0 - 0.5 and dt <= Hud.PTR_SHOW_MS / 1000.0 + 1.5,
		"стрелка по щелчку погасла сама через %.1f с" % dt)
	game.set_tool("")
	hud.advisor_panel.visible = false
