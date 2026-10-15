extends Node
## Вкладка «Против городов» с настоящим сервером, на готовом городе (--demo, город не сохраняется):
##   node .work/pvp_e2e/setup.js   (сервер: PORT=3010 DATA_DIR=D:/CivCity/.work/srvdata node server/index.js)
##   bash .work/py/gpu_run.sh res://test_pvp_ui.tscn -- tokens=D:/CivCity/.work/pvp_e2e/tokens.json --savedir=D:/CivCity/.work/pvp_e2e/saves [out=…]
## Учётка B выставляет оборону; учётка A (её легион — в городе) открывает вкладку, видит соперников, таблицу лучших,
## окно названия; настоящим щелчком «Напасть» на B — 3D-бой (×3, авто), итог уходит на сервер сразу по окончании;
## окно снова на вкладке городов с записью в летописи. Потом B забирает отчёт: в городе всплывает «На ваш город напал…».
var game
var out := "D:/CivCity/.work/pvp_ui"
var tokens := "D:/CivCity/.work/pvp_e2e/tokens.json"
var fails := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out":
			out = kv[1]
		if kv.size() == 2 and kv[0] == "tokens":
			tokens = kv[1]
	DirAccess.make_dir_recursive_absolute(out)
	Game.boot = {"demo": "1", "hour": "10.5"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func secs(t: float) -> void:
	await get_tree().create_timer(t).timeout


func click(p: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	Input.parse_input_event(m)
	await frames(3)
	for pressed: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = p
		e.global_position = p
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		Input.parse_input_event(e)
		await frames(3)


func center_of(c: Control) -> Vector2:
	return c.get_viewport().get_final_transform() * (c.get_global_transform_with_canvas() * (c.size / 2.0))


func shot(name: String) -> void:
	await frames(8)
	var p := "%s/%s.png" % [out, name]
	get_viewport().get_texture().get_image().save_png(p)
	print("shot ", p)


func check(name: String, ok: bool, extra = null) -> void:
	if not ok:
		fails += 1
	print(("ok   " if ok else "FAIL ") + name + ("" if ok or extra == null else "  " + str(extra)))


func until(cond: Callable, limit: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > limit * 1000.0:
			return false
		await frames(2)
	return true


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(20)
	var tk = JSON.parse_string(FileAccess.get_file_as_string(tokens))
	if typeof(tk) != TYPE_DICTIONARY:
		print("FAIL нет tokens.json — сначала node .work/pvp_e2e/setup.js")
		get_tree().quit(2)
		return
	var acc := Account.me()
	var net := LegionNet.me()
	acc.api = String(tk["api"])
	net.force_on = true
	for c in net.get_children():
		if c is Timer:
			(c as Timer).stop()
	# --- B выставляет оборону (отдельный легион, без города) ---
	acc.token = String(tk["b"])
	var lb := Legion.new()
	lb.free_mode = true
	lb.levels = {"legionary": 5, "archer": 4}
	lb._ensure()
	lb.squad = ["legionary", "archer", "legionary"]
	net.legion_override = lb
	var name_b := "Тарент %d" % (int(Time.get_unix_time_from_system()) % 100000)
	var st := {}
	net.pvp_rename(name_b, func(e: String):
		st["err"] = e
		st["done"] = true)
	await until(func(): return st.has("done"), 20.0)
	check("B выставил оборону «%s»" % name_b, String(st.get("err", "?")) == "", st)
	# --- город A: «Большой город», военные постройки, легион как в облаке A ---
	acc.token = String(tk["a"])
	net.legion_override = null
	net._pub_hash = ""
	var c: City = game.city
	var lg: Legion = c.legion
	var ui := LegionUi.of(game.hud)
	c.level = 6
	c.research["legion"] = true
	c.research["archery"] = true
	c.money = 18000.0
	var spots := [Vector2(150, 205), Vector2(166, 205), Vector2(182, 205)]
	var i := 0
	for t in ["barracks", "range", "spearcamp"]:
		c.place(t, spots[i], 0.0, 0, -1, true)
		i += 1
	lg.progress = 14
	lg.levels = {"legionary": 6, "spearman": 4, "archer": 5, "ballista": 1, "catapult": 1}
	lg.squad = ["legionary", "legionary", "archer", "spearman"]
	lg.perks = {"oil": 2, "testudo": 0, "bandage": 0, "volley": 0, "horn": 0}
	lg.glory = 40.0
	lg.flags["tut"] = "done"
	lg.flags["battle_speed"] = 3.0
	lg.flags["battle_auto"] = true
	lg.pvp_log = []
	c.changed.emit()
	await frames(10)
	check("вкладка готова к сети (LegionNet)", net.pvp_ready())
	ui.open("pvp")
	var got := await until(func(): return ui._pvp_state == "ok" or ui._pvp_state == "error", 20.0)
	await frames(10)
	check("соперники пришли с сервера", got and ui._pvp_state == "ok" and not ui._pvp_list.is_empty(), [ui._pvp_state, ui._pvp_err])
	await shot("net_list")
	# таблица лучших
	LegionPvpView.top(ui)
	await until(func(): return ui.overlay != null and ui.overlay.find_children("*", "ScrollContainer", true, false).size() > 0, 15.0)
	await frames(6)
	await shot("net_top")
	ui._close_overlay()
	# окно названия
	LegionPvpView.rename(ui)
	await frames(6)
	await shot("net_rename")
	ui._close_overlay()
	await frames(4)
	# «Напасть» на B настоящим щелчком
	var row_btn: Button = null
	for row in ui.content.find_children("*", "PanelContainer", true, false):
		var labels := row.find_children("*", "Label", true, false)
		if labels.any(func(l): return (l as Label).text == name_b):
			for b in row.find_children("*", "Button", true, false):
				if (b as Button).text == "Напасть":
					row_btn = b
	check("в списке есть B и кнопка «Напасть»", row_btn != null)
	if row_btn == null:
		get_tree().quit(1)
		return
	var charges0 := int(net.me_state.get("charges", 0))
	await click(center_of(row_btn))
	var opened := await until(func(): return LegionBattle.current != null, 20.0)
	check("сервер дал бой — открылся 3D-бой с отрядом B", opened and String(LegionBattle.current.setup.get("kind", "")) == "pvp" and
		String((LegionBattle.current.setup["opponent"] as Dictionary).get("battle", "")) != "")
	check("заряд потрачен на сервере", int(net.me_state.get("charges", 0)) == charges0 - 1)
	var b: LegionBattle = LegionBattle.current
	var bid := String((b.setup["opponent"] as Dictionary)["battle"])
	await secs(7.0)
	await shot("net_battle")
	var ended := await until(func(): return not is_instance_valid(b) or b.phase == "result", 240.0)
	check("бой окончен", ended)
	await until(func(): return net._reported.has(bid), 10.0)
	await secs(1.5)
	check("итог ушёл на сервер сразу по окончании боя (ещё на экране итога)", net._reported.has(bid) and is_instance_valid(b) and LegionBattle.current == b)
	await shot("net_result")
	var win := bool(b.out.get("win", false))
	b._close()
	await until(func(): return LegionBattle.current == null and ui.visible, 15.0)
	await until(func(): return ui._pvp_state == "ok", 15.0)
	await frames(10)
	check("окно снова на вкладке городов, в летописи — бой с B (рейтинг как на сервере)", ui.visible and ui.tab == "pvp" and not lg.pvp_log.is_empty() and
		String(lg.pvp_log[0].get("name", "")) == name_b and lg.pvp_rating == int(net.me_state.get("rating", -1)), [lg.pvp_log, net.me_state])
	print("бой с B: ", "победа" if win else "поражение", ", рейтинг A ", lg.pvp_rating)
	await shot("net_after")
	ui.close()
	# --- B забирает отчёт о нападении: всплывает весть в городе ---
	var name_a := String(net.me_state.get("name", ""))
	acc.token = String(tk["b"])
	lg.flags["pvp_seen"] = 0
	await net.refresh()
	await frames(10)
	check("весть о нападении A на город B", lg.pvp_log.any(func(e): return not bool(e.get("attack", true)) and String(e.get("name", "")) == name_a))
	await shot("net_report")
	ui.open("pvp")
	await until(func(): return ui._pvp_state == "ok" or ui._pvp_state == "error", 20.0)
	await frames(10)
	await shot("net_report_tab")
	print("ИТОГ: ошибок %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
