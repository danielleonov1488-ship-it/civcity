extends Node
## Окна онлайна 2.0 с настоящим сервером, на готовом городе (город не сохраняется; docs/ONLINE_V2.md):
##   сервер: PORT=3020 DATA_DIR=<новая папка> node server/index.js;  учётки: node .work/online/setup_ui.js <api> <город> <tokens>
##   bash .work/py/gpu_run.sh res://test_online_ui.tscn -- tokens=<tokens.json> [out=…]
## Вкладка «Друзья» (подарки забраны сами: статуя даром, кошка), «Союз» (вступить, фраза), карточка «Подарок» в стройке,
## подпись над туристами из другого города, плашка «В гости», вкладка «События» и бой подземелья, лига на «Против городов».
var game
var out := "D:/CivCity/.work/online_ui"
var tokens := ""
var fails := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out":
			out = kv[1]
		if kv.size() == 2 and kv[0] == "tokens":
			tokens = kv[1]
	DirAccess.make_dir_recursive_absolute(out)
	Game.boot = {"demo": "1", "hour": "11.0"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	await frames(8)
	await RenderingServer.frame_post_draw
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
	await frames(30)
	var tk = JSON.parse_string(FileAccess.get_file_as_string(tokens))
	if typeof(tk) != TYPE_DICTIONARY:
		print("FAIL нет tokens.json")
		get_tree().quit(2)
		return
	var acc := Account.me()
	acc.api = String(tk["api"])
	acc.token = String(tk["a"])
	var c: City = game.city
	# готовый город — как «новая игра Уютного Рима» с Легионом 2.0
	game.mode = "new"
	game.can_save = false
	c.cozy_v = 1
	c.level = 6
	c.research["legion"] = true
	c.money = 20000.0
	c.legion.sync_v2()
	c.legion.flags["tut"] = "done"
	c.legion.flags["battle_speed"] = 3.0
	c.legion.flags["battle_auto"] = true
	var sn := SocialNet.me()
	sn.force_on = true
	LegionNet.me().force_on = true
	for n in [sn, LegionNet.me()]:
		for t in n.get_children():
			if t is Timer:
				(t as Timer).stop()
	# --- друзья: состояние, подарки сами в город ---
	var st := {}
	sn.refresh(func(e): st["e"] = e)
	await until(func(): return st.has("e"), 20.0)
	check("друзья: состояние с сервера", String(st["e"]) == "" and (sn.state.get("friends", []) as Array).size() == 2, st)
	await until(func(): return c.gift_ready("statue_3"), 10.0)
	check("подарок «статуя» — в городе даром", c.gift_ready("statue_3"))
	check("подарок «кошка» пришла", c.cats.any(func(k): return String(k.get("gift", "")) == String(tk.get("c_name", "Капуя Малая"))))
	game.stories.ui.open_journal("friends")
	await frames(20)
	await shot("01_friends")
	# --- союз: вступить, фраза ---
	var us := {}
	sn.union_refresh(func(e): us["e"] = e)
	await until(func(): return us.has("e"), 20.0)
	var uj := {}
	sn.union_do("join", {"id": int(tk["union"])}, func(e, _d): uj["e"] = e)
	await until(func(): return uj.has("e"), 20.0)
	check("союз: вступили в «Волчью стаю»", String(uj["e"]) == "" and bool((sn.union.get("me", {}) as Dictionary).get("in_union", false)), uj)
	var us2 := {}
	sn.union_do("say", {"phrase": 9}, func(e, _d): us2["e"] = e)
	await until(func(): return us2.has("e"), 20.0)
	game.stories.ui.open_journal("union")
	await frames(20)
	await shot("02_union")
	game.hud.journal_panel.visible = false
	# --- карточка подарка в стройке (раздел украшений, камень) ---
	game.hud.select_build("statue_3")
	await frames(20)
	await shot("03_build_gift")
	game.set_tool("")
	game.hud.tray.visible = false
	await frames(10)
	# --- туристы из другого города: подпись над группой ---
	var tour: Tourism = game.get_node("Tourism")
	var inn := {}
	for id in c.buildings:
		var bb: Dictionary = c.buildings[id]
		if c.is_house(bb) and not Tourism.sights(c, bb)["list"].is_empty() and (Tourism.sights(c, bb)["list"] as Array).size() >= 3:
			inn = bb
			break
	if not inn.is_empty():
		var fake := inn.duplicate()
		fake["type"] = "mansio"
		fake["id"] = -77
		tour._spawn(fake)
		await frames(5)
		var grp: Dictionary = tour.groups[tour.groups.size() - 1] if not tour.groups.is_empty() else {}
		check("туристы: группа из другого города с подписью", grp.has("label") and String((grp["label"] as Label3D).text).begins_with("из «"), grp.get("from"))
		if grp.has("label"):
			grp["d"] = 6.0
			await frames(30)
			var lead = (grp["n"] as Array)[0]
			game.rig.set_view(lead.global_position, 12.0, 35.0, 35.0)
			await frames(40)
			var lb3: Label3D = grp["label"]
			print("label visible=%s pos=%s cam_d=%.1f" % [lb3.visible, str(lb3.global_position), game.rig.cam.global_position.distance_to(lb3.global_position)])
			await shot("04_tourist_label")
	# --- плашка «В гости» ---
	game.hud.visit_banner({"id": 5, "name": "Брундизий", "likes": 3, "liked": false, "card": {"rank": "Большой город", "pop": 704, "title": "Колония", "hero": "Гай Валерий"}})
	await frames(20)
	await shot("05_visit_banner")
	var vb = game.hud.root.find_child("VisitBanner", true, false)
	check("плашка «В гости» на экране", vb != null and (vb as Control).visible)
	if vb != null:
		vb.queue_free()
	for n in [game.hud.bar_left, game.hud.bar_mid, game.hud.bar_right]:
		(n as Control).visible = true
	# --- Легион: «События» и бой подземелья ---
	var lg: Legion = c.legion
	for i in 3:
		c.place(["barracks", "range", "spearcamp"][i], Vector2(150 + i * 16, 205), 0.0, 0, -1, true)
	lg.levels = {"legionary": 10, "spearman": 8, "archer": 9, "ballista": 1, "catapult": 1}
	c.changed.emit()
	await frames(10)
	var ui := LegionUi.of(game.hud)
	ui.open("events")
	var es := {}
	sn.events_refresh(func(e): es["e"] = e)
	await until(func(): return es.has("e"), 20.0)
	ui._rebuild()
	await frames(20)
	await shot("06_events_tab")
	check("события: испытание недели с сервера", not sn.events.is_empty() and (sn.events.get("tiers", []) as Array).size() == 3)
	var what := "raid" if LegionEvents.kind() == "invasion" else "floor"
	var why := LegionEvents.can(lg, what)
	check("событие города можно начать (%s)" % what, why == "", why)
	if why == "":
		LegionEvents.start(lg, what)
		var opened := await until(func(): return LegionBattle.current != null, 10.0)
		check("бой события открылся", opened)
		if opened:
			var b: LegionBattle = LegionBattle.current
			await until(func(): return b.phase == "fight", 30.0)
			await frames(200)
			await shot("07_event_battle")
			await until(func(): return b.phase == "result", 200.0)
			await frames(60)
			await shot("08_event_result")
			check("итог события: награда или строка", (b.out.get("note", "") as String) != "", b.out)
			b._close()
			await frames(30)
	# --- «Против городов»: лига и сезон ---
	var ln := LegionNet.me()
	ln.refresh()
	await until(func(): return ln.me_state.has("arena"), 20.0)
	check("арена: лига с сервера", (ln.me_state.get("arena", {}) as Dictionary).has("league_name"))
	ui.open("pvp")
	await frames(40)
	await shot("09_pvp_arena")
	print("ONLINEUI DONE fails=%d" % fails)
	get_tree().quit(1 if fails else 0)
