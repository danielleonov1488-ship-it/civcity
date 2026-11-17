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

func put(type: String, near: Vector2) -> bool:
	for z in range(-4, 7, 2):
		for x in range(-4, 7, 2):
			var pl: Dictionary = game.placement(type, near + Vector2(x, z))
			if pl["err"] != "" or type != "house_pleb" and bool(pl.get("noroad", false)):
				continue
			var b: Dictionary = game.city.place(type, pl["pos"], pl["yaw"], pl["variant"], pl["color"])
			if not b.is_empty():
				return true
	print("FAIL не удалось поставить ", type)
	return false

func _run() -> void:
	while not game.ready_done:
		await frames(5)
	var c: City = game.city
	game.can_save = false
	game.settings["autosave"] = false
	game.settings["advisor_off"] = true
	Tutorial.start_new(c)
	game.tutorial._enter(0)
	game.hud.advisor_panel.visible = false
	await frames(30)
	await shot("t1_move.png")
	game.rig._pan_by(Vector3(13, 0, 0))
	game.rig._zoom(0.88)
	await get_tree().create_timer(3.1).timeout
	await wait_step("houses")
	await frames(20)
	await shot("t2_houses.png")
	var ctr := c.center()
	var dp: Vector2 = c.door_point(ctr)
	for k in 3:
		if not put("house_pleb", dp + Vector2(-13, 12 + k * 8)):
			get_tree().quit(1)
			return
	await wait_step("road")
	var tut: Tutorial = game.tutorial
	c._tick_arrivals()
	if c.has_connected_house() or c.incoming > 0 or not c.arrivals.is_empty() or not tut.cine.is_empty():
		print("FAIL повозка ждёт дорогу к первому дому")
		get_tree().quit(1)
		return
	await frames(10)
	await shot("t3_road.png")
	game.set_tool("road")
	game.painting = true
	game.stroke = []
	game.stroke_cost = 0.0
	game.brush_line = false
	for k in 90:
		game._paint_at(dp + Vector2(0, k * 0.5))
	for home: Dictionary in c.buildings.values():
		if not c.is_house(home):
			continue
		var door := c.door_point(home)
		for k in 50:
			game._paint_at(Vector2(dp.x, door.y).lerp(door, float(k) / 49.0))
	game._release()
	c.compute()
	game.people.refresh(game.land.road_chunks.keys())
	game.set_tool("")
	if not c.has_connected_house():
		print("FAIL мостовая должна соединить дома с площадью")
		get_tree().quit(1)
		return
	# Повозка может тронуться ещё на шаге дороги. Смотрим каждый кадр сразу после мазка.
	var w := 0
	while tut.cine.is_empty() and w < 1800:
		await get_tree().process_frame
		w += 1
	if tut.cine.is_empty():
		print("CINE MIN FAIL ролик с повозкой не начался")
		get_tree().quit(1)
		return
	else:
		check(tut.cur_id() in ["road", "cart"] and c.has_connected_house(), "ролик начался после подключения дома")
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
	while c.settled_total == 0:
		await frames(5)
	for id in c.buildings:
		if c.is_house(c.buildings[id]) and int(c.buildings[id].get("pop", 0)) > 0:
			game.select_building(c.buildings[id])
			game.hud.open_info(c.buildings[id])
			break
	await frames(10)
	game.tutorial.next_btn.pressed.emit()
	await wait_step("food")
	game.hud.close_panels()
	await frames(10)
	await shot("t7_food.png")
	put("stall_fruit", dp + Vector2(-4, 14))
	await wait_step("workers")
	await frames(10)
	await shot("t8_workers.png")
	for b: Dictionary in c.buildings.values():
		if b["type"] == "stall_fruit":
			c.hire(b)
	await wait_step("script")
	put("scriptorium", dp + Vector2(-5, 24))
	for b: Dictionary in c.buildings.values():
		if b["type"] == "scriptorium":
			c.hire(b)
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


## После обучения стрелка — только по щелчку строки, в том числе до «Хутора».
func _arrow_after() -> void:
	var c: City = game.city
	var hud = game.hud
	game.set_tool("")
	hud.advisor_panel.visible = false
	var g0: Dictionary = c.active_goals(1)[0] if not c.active_goals(1).is_empty() else {}
	hud._update_pointer()
	await frames(2)
	check(c.level == 0 and not g0.is_empty() and hud.pointer_target == null and not hud.pointer.visible,
		"после обучения, до «Хутора»: нет автоматической стрелки к просьбе «%s»" % g0.get("text", ""))
	# стал хутором
	c.level = 1
	for g in Defs.REQUESTS:
		if not c.goals_done.has(g["id"]):
			c.goals_done.append(g["id"])
		if g["id"] == "hamlet":
			break
	game.settings["tasks_folded"] = false      # свиток просьб по умолчанию свёрнут в значок (отзыв 14.11); проверка щёлкает по строке — разворачиваем
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
