extends Node
## Снимки окна «Легион» на готовом городе (--demo, город не сохраняется):
##   bash .work/py/gpu_run.sh res://test_legion_ui.tscn -- [out=D:/CivCity/.work/legion_ui] [only=map,troops,…]
## Ставит военные постройки, прогресс походов (Крит, бой 4), уровни, умения, Славу; открывает медальон настоящим
## щелчком мыши и снимает каждую вкладку, выбор бойца, итог боя (без 3D-боя окно считает бой само),
## свою карту для провинций без картинки, раннюю игру («Посёлок», первый бой) и обучение Легиону в 4 шага (tut*.png).
var game
var out := "D:/CivCity/.work/legion_ui"
var only := []
var shots := []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out":
			out = kv[1]
		if kv.size() == 2 and kv[0] == "only":
			only = Array(kv[1].split(","))
	DirAccess.make_dir_recursive_absolute(out)
	Game.boot = {"demo": "1", "hour": "10.5"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


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
	if not only.is_empty() and not name in only:
		return
	await frames(8)
	var p := "%s/%s.png" % [out, name]
	get_viewport().get_texture().get_image().save_png(p)
	shots.append(name)
	print("shot ", p)


func check(name: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + name)


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(20)
	var c: City = game.city
	var lg: Legion = c.legion
	var ui := LegionUi.of(game.hud)
	# окно проверяется без настоящего 3D-боя (game.gd подключает LegionBattle): «3D-бой» ниже — подделка
	for cn: Dictionary in lg.battle_requested.get_connections():
		lg.battle_requested.disconnect(cn["callable"])
	check("окно создано", ui != null)
	check("медальон виден только с исследованием «Легион»", ui.btn_wrap.visible == lg.window_open())
	# --- середина игры: «Большой город», Крит, бой 4 ---
	c.level = 6
	c.research["legion"] = true
	c.research["archery"] = true
	c.money = 18000.0
	var spots := [Vector2(150, 205), Vector2(166, 205), Vector2(182, 205), Vector2(198, 205)]
	var i := 0
	for t in ["barracks", "range", "spearcamp", "ballistae"]:
		c.place(t, spots[i], 0.0, 0, -1, true)
		i += 1
	lg.progress = 43
	lg.levels = {"legionary": 6, "spearman": 6, "archer": 6, "ballista": 5, "catapult": 1}
	lg.squad = ["legionary", "spearman", "archer", "ballista", "legionary"]
	lg.perks = {"oil": 3, "testudo": 2, "bandage": 1, "volley": 1, "horn": 0}
	lg.glory = 64.0
	lg.rating = 160
	lg.wins = 47
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in lg.progress:
		var cyc := k / 80
		var r := (k % 80) / 10
		lg.stars[Legion.stage_key(cyc, r, k % 10)] = Legion.STAR_ALL if rng.randf() < 0.6 else Legion.STAR_WIN | Legion.STAR_SAFE
	lg.upg["legionary"] = {"to": 7, "end": Legion.now() + 754.0, "total": 1200.0}
	lg.pvp_log = [{"t": Legion.now() - 5400.0, "name": "Аквилея", "win": true, "delta": 22, "money": 640, "attack": true},
		{"t": Legion.now() - 86000.0, "name": "Новый Карфаген", "win": false, "delta": -6, "money": 0, "attack": false}]
	lg.pvp_rating = 64
	lg.pvp_wins = 3
	lg.pvp_losses = 1
	lg.flags["tut"] = "done"
	c.changed.emit()
	await frames(10)
	check("медальон виден после исследования", ui.btn_wrap.visible)
	await shot("hud_button")
	# настоящий щелчок по медальону
	await click(center_of(ui.btn))
	await frames(10)
	check("окно открылось щелчком", ui.visible)
	await shot("map_crete")
	# щелчок по вкладке «Войска» мышью
	await click(center_of(ui.tabs["troops"]))
	await frames(10)
	check("вкладка «Войска» щелчком", ui.tab == "troops")
	check("«Войска»: 8 зданий Легиона, у Казарм — «На карте»", _texts(ui.content).contains("Здания Легиона в городе") and _texts(ui.content).contains("Склад оружия")
		and ui._upg_btn != null and ui._upg_btn.text == "На карте")
	await shot("troops")
	await _d10(c, lg, ui)
	ui.open("troops")
	await frames(6)
	# выбор бойца на 2-е место
	var slot_btn: Button = null
	for b in ui.content.find_children("*", "Button", true, false):
		if (b as Button).tooltip_text.begins_with("Копейщик"):
			slot_btn = b
			break
	if slot_btn:
		await click(center_of(slot_btn))
		await frames(6)
		check("выбор бойца открыт", ui.overlay != null)
		await shot("troops_pick")
		ui._close_overlay()
	ui._select_tab("pvp")
	await shot("pvp")
	ui._select_tab("wonders")
	await shot("wonders")
	# босс Крита
	ui._select_tab("campaign")
	ui.sel = {"c": 0, "r": 4, "s": 9}
	ui._rebuild()
	await shot("map_crete_boss")
	# прошлые провинции: своя карта, пока нет картинки
	for r in [0, 1, 2, 3]:
		ui.view_r = r
		ui.sel = {}
		ui._rebuild()
		await shot("map_r%d" % r)
	# провинции дальше по пути — закрыты
	for r in [5, 6, 7]:
		ui.view_r = r
		ui.sel = {}
		ui._rebuild()
		await shot("map_r%d" % r)
	# своя нарисованная карта — если картинки провинции нет (кэш картинок «без файла»)
	for r in [0, 3]:
		ui._tex["map:" + String(Legion.REGIONS[r]["id"])] = null
		ui.view_r = r
		ui.sel = {}
		ui._rebuild()
		await shot("placeholder_r%d" % r)
		ui._tex.erase("map:" + String(Legion.REGIONS[r]["id"]))
	# бой без 3D: окно считает само и показывает итог
	ui.view_r = 4
	ui.sel = {}
	ui._rebuild()
	var st := lg.stage_info(0, 4, 3)
	var p0 := lg.progress
	ui._fight(st)
	await frames(6)
	check("итог боя показан", ui.overlay != null)
	print("бой: прогресс ", p0, " → ", lg.progress)
	await shot("result")
	ui._close_overlay()
	# ESC/правая кнопка закрывают окно (hud.close_panels)
	var was: bool = game.hud.close_panels()
	check("close_panels закрыл окно", was and not ui.visible)
	# --- ранняя игра: «Посёлок», Казармы, первые бои (масло — с первого дня) ---
	c.level = 3
	lg.progress = 2
	lg.stars = {"0-0-0": Legion.STAR_ALL, "0-0-1": Legion.STAR_WIN | Legion.STAR_TASK}
	lg.levels = {"legionary": 2, "spearman": 1, "archer": 1, "ballista": 1, "catapult": 1}
	lg.upg = {}
	lg.squad = ["legionary", "legionary", "legionary"]
	lg.perks = {"oil": 1, "testudo": 0, "bandage": 0, "volley": 0, "horn": 0}
	lg.glory = 3.0
	lg.rating = 6
	for id in c.buildings.keys():
		var t: String = c.buildings[id]["type"]
		if t in ["range", "spearcamp", "ballistae"]:
			c.remove(c.buildings[id], false)
	c.changed.emit()
	ui.view_r = -1
	ui.sel = {}
	ui.open("campaign")
	await shot("early_map")
	ui._select_tab("troops")
	await shot("early_troops")
	ui._select_tab("wonders")
	await shot("early_wonders")
	ui.view_r = 1
	ui._select_tab("campaign")
	await shot("early_locked")
	await _card_puzzle(c, lg, ui)
	# --- 3D-бой (подделка): окно просит бой сигналом, «бой» зовёт apply_result и battle_closed — окно открывается снова ---
	var asked := []
	var fake := func(setup: Dictionary):
		asked.append(setup)
		var sim := LegionSim.new(setup)
		var res := sim.run(true)
		var o: Dictionary = lg.apply_result(setup, res) if setup["kind"] == "campaign" else lg.apply_pvp_result(setup, res)
		lg.battle_closed.emit.call_deferred(o)
	lg.battle_requested.connect(fake)
	ui.view_r = 0
	ui.sel = {}
	ui._select_tab("campaign")
	var p1 := lg.progress
	ui._fight(lg.stage_info(0, 0, 2))
	check("при 3D-бое окно закрывается", not ui.visible)
	await frames(6)
	check("бой запрошен сигналом battle_requested", asked.size() == 1)
	check("после battle_closed окно снова открыто", ui.visible and ui.tab == "campaign")
	print("3D-бой: прогресс ", p1, " → ", lg.progress, ", выбран бой ", ui.sel)
	await shot("after_3d")
	# --- бои с городами: сеть (подделка) отдаёт соперников ---
	var net := FakeNet.new()
	ui._net_obj = net
	ui._net_checked = true
	# Легион с «Хутора», бои с городами — с «Посёлка»: в «Деревне» вкладка объясняет, без списка соперников и добычи
	var lv_was: int = c.level
	c.level = 2
	ui._select_tab("pvp")
	await frames(4)
	var ptx := _texts(ui.content)
	check("«Деревня»: бои с городами — с «Посёлка», соперников нет", ptx.contains("Бои с городами — впереди") and ptx.contains("станет «Посёлок»") and not ptx.contains("Соперники") and not ptx.contains("· рейтинг ") and lg.pvp_can_attack().contains("Посёлок"))
	await shot("pvp_closed")
	c.level = lv_was
	ui._select_tab("pvp")
	await frames(4)
	await shot("pvp_list")
	ui._attack(net.list[1])
	await frames(6)
	check("бой с городом: заряд потрачен, итог отправлен, окно на вкладке городов", net.reports == 1 and lg.pvp_charges_now() == int(Legion.PVP["charges"]) - 1 and ui.visible and ui.tab == "pvp")
	await shot("pvp_after")
	lg.battle_requested.disconnect(fake)
	# без 3D-боя бой с городом считается в окне и показывает итог
	ui._attack(net.list[0])
	await frames(4)
	check("бой с городом без 3D: итог показан", ui.overlay != null and net.reports == 2)
	await shot("pvp_result")
	ui._close_overlay()
	# крупный интерфейс (настройка «Размер интерфейса»): окно ужимается, чтобы целиком влезть на экран
	game.hud.apply_scale(1.3)
	await frames(6)
	ui.open("troops")
	await frames(6)
	var fits: bool = ui.win.get_global_rect().end.y <= ui.size.y + 1.0 and ui.win.get_global_rect().end.x <= ui.size.x + 1.0
	check("крупный интерфейс: окно целиком на экране", fits)
	for b in ui.content.find_children("*", "Button", true, false):
		if (b as Button).tooltip_text.begins_with("Легионер"):
			await click(center_of(b))
			break
	await frames(6)
	await shot("scaled_pick")
	ui._close_overlay()
	game.hud.apply_scale(1.0)
	await _tutorial(c, lg, ui, fake)
	await _trophy(c, lg)
	print("снимков: ", shots.size())
	get_tree().quit()


## Д10: здания Легиона на карте — военный квартал (здания разных уровней), карточка здания: идущее улучшение и кнопка
## «Улучшить — N ден., M Славы, время», «На карте» из «Войск», облик одного здания на 1, 2 и 3 уровне
func _d10(c: City, lg: Legion, ui: LegionUi) -> void:
	var hud = game.hud
	ui.close()
	hud.advisor_panel.visible = false
	# квартал: две улицы, вдоль каждой — четыре здания Легиона фасадом к улице, как поставил бы игрок
	# (место расчищено: постройки и деревья готового города меню убраны)
	var rows := [[Vector2(151, 205), "barracks"], [Vector2(158.6, 205), "range"], [Vector2(166.2, 205), "spearcamp"], [Vector2(173.8, 205), "ballistae"],
		[Vector2(151, 219), "forge"], [Vector2(158.6, 219), "infirmary"], [Vector2(166.2, 219), "armory"], [Vector2(173.8, 219), "catapults"]]
	for id in c.buildings.keys():
		var o: Dictionary = c.buildings[id]
		var q: Vector2 = o["pos"]
		if q.x > 138.0 and q.x < 210.0 and q.y > 196.0 and q.y < 230.0 and not bool(Defs.B[o["type"]].get("fixed", false)):
			c.remove(o, false)
	for kz in range(97, 116):
		for kx in range(68, 106):
			for it in (game.nature.get(Vector2i(kx, kz), []) as Array).duplicate():
				if not String(it["name"]).contains("Grass"):
					game.remove_nature(it)
	for zr: float in [209.2, 223.2]:
		game.land.paint_line(Vector2(144, zr), Vector2(182, zr), 1.3, Land.Kind.ROAD, true)
	game.people.refresh(game.land.road_chunks.keys())
	game.hour = 10.5
	# облик одного здания на 1, 2 и 3 уровне: три Казармы рядом у улицы (только для снимка)
	var extra := []
	for k in 3:
		var b3: Dictionary = c.place("barracks", Vector2(151 + k * 8.6, 205), 0.0, 0, -1, true)
		b3["tier"] = k
		game._show(b3)
		extra.append(b3)
	game.rig.set_view(Vector3(160.2, 0, 206.5), 15, 40, 25)
	await frames(24)
	await shot("d10_levels_123")
	for b3: Dictionary in extra:
		c.remove(b3, false)
	game.rig.set_view(Vector3(162.5, 0, 214), 12, 48, 50)
	await frames(20)
	var vp := get_viewport()
	var dc0 := vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	lg.levels = {"legionary": 1, "spearman": 1, "archer": 1, "ballista": 1, "catapult": 1}
	lg.blevels = {"forge": 1, "infirmary": 1, "armory": 1}
	var pg0 := lg.progress
	lg.progress = 50                               # Мастерская катапульт открыта (5-й босс): закрытую place() кладёт без участка
	for e: Array in rows:
		c.place(String(e[1]), e[0], 0.0, 0, -1, true)
	lg.progress = pg0
	await frames(20)
	var dc1 := vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	lg.levels = {"legionary": 6, "spearman": 5, "archer": 4, "ballista": 3, "catapult": 2}
	lg.blevels = {"forge": 3, "infirmary": 2, "armory": 5}
	lg.sync_tiers(true)
	c.changed.emit()
	await frames(20)
	var dc2 := vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var tiers := []
	for e: Array in rows:
		tiers.append(int(lg.building_rec(String(e[1])).get("tier", -1)))
	check("квартал: 8 зданий, облик по уровням %s" % str(tiers), tiers == [5, 3, 4, 2, 2, 1, 4, 1])
	print("D10 DRAWCALLS quality=%s quarter of 8 Legion buildings: empty %d → all level 1 %d (+%d) → levels 2–6 %d (+%d for growth)" % [str(game.settings.get("quality", "?")),
		dc0, dc1, dc1 - dc0, dc2, dc2 - dc1])
	check("облик по уровням стоит не больше 40 вызовов отрисовки на весь квартал (+%d)" % (dc2 - dc1), dc2 - dc1 <= 40)
	game.rig.set_view(Vector3(163.0, 0, 213.5), 12, 46, 42)
	await get_tree().create_timer(2.5).timeout           # облачка нового уровня рассеялись
	await shot("d10_quarter")
	# карточка Казарм: улучшение идёт — полоска и минуты
	var bb: Dictionary = lg.building_rec("barracks")
	lg.upg["legionary"] = {"to": 7, "end": Legion.now() + 754.0, "total": 4000.0}
	game.select_building(bb)
	hud.open_info(bb)
	await frames(8)
	var tx := _texts(hud.info_box)
	check("карточка Казарм: уровень, что даёт, «Улучшается до 7 уровня», полоска", tx.contains("Здание Легиона · 6 уровень") and tx.contains("Легионеры 6 уровня")
		and tx.contains("Улучшается до 7 уровня") and not hud._lg_live.is_empty())
	await shot("d10_card_upgrading")
	# Кузница 3 ур. на «Большом городе»: можно улучшить — «Улучшить — N ден., время»; на 6-м уровне — ещё и Слава
	var fb: Dictionary = lg.building_rec("forge")
	c.money = 40000.0
	game.select_building(fb)
	hud.open_info(fb)
	await frames(8)
	var ub: Button = hud.lg_upg_btn
	check("карточка Кузницы: «%s»" % (ub.text if ub else "—"), ub != null and ub.text.begins_with("Улучшить — ") and ub.text.contains(" ден., ") and not ub.disabled
		and _texts(hud.info_box).contains("На 4 уровне") and _texts(hud.info_box).contains("+12% урона и здоровья"))
	game.rig.set_view(Vector3(151, 0, 219), 25, 50, 26)
	await frames(10)
	await shot("d10_card_upgrade")
	lg.blevels["forge"] = 5
	hud.open_info(fb)
	await frames(6)
	var ub6: Button = hud.lg_upg_btn
	check("6-й уровень просит Славы: «%s»" % (ub6.text if ub6 else "—"), ub6 != null and ub6.text.contains(" Славы, "))
	hud.close_panels()
	# «На карте» из «Войск»: камера к зданию, карточка открыта
	ui.open("troops")
	await frames(6)
	ui.show_building("armory")
	await frames(8)
	check("«На карте» → карточка Склада оружия", not ui.visible and hud.info_panel.visible and String(hud.info_b.get("type", "")) == "armory")
	hud.close_panels()
	lg.upg = {"legionary": {"to": 7, "end": Legion.now() + 754.0, "total": 1200.0}}
	c.changed.emit()
	await frames(4)


## Обучение Легиону в 4 шага: Казармы → окно → учебный бой → улучшение; и «Пропустить обучение».
## Стрелки и советник — только в настоящей игре: на время проверки город считается игрой (сохранять его всё равно нельзя)
func _tutorial(c: City, lg: Legion, ui: LegionUi, fake: Callable) -> void:
	var hud = game.hud
	var mode0: String = game.mode
	game.mode = "play"
	ui.close()
	hud.advisor_panel.visible = false
	for id in c.buildings.keys():
		if String(c.buildings[id]["type"]) in ["barracks", "range", "spearcamp", "ballistae", "catapults"]:
			c.remove(c.buildings[id], false)
	c.level = 3
	c.money = 20000.0
	c.tips["rank_pressed"] = true                  # стрелка «новый уровень» не перебивает обучение Легиону
	c.tips["tax_tip"] = true                       # и советы экономики (налоги по классам с «Деревни») — тоже
	lg.progress = 0
	lg.stars = {}
	lg.upg = {}
	lg.levels = {"legionary": 1, "spearman": 1, "archer": 1, "ballista": 1, "catapult": 1}
	lg.squad = ["legionary", "legionary", "legionary"]
	lg.perks = {"oil": 1, "testudo": 0, "bandage": 0, "volley": 0, "horn": 0}
	lg.flags = {}
	ui.view_r = -1
	ui.sel = {}
	c.changed.emit()
	await frames(6)
	# другие советы города (готовый город стал «Посёлком»: «новый уровень» и т.п.) не перебиваются:
	# совет «Легион открыт — теперь его нужно построить» ждёт, пока советник свободен (игрок нажал «Понятно» — совет при следующем обновлении города)
	for i in 6:
		if not hud.advisor_panel.visible or hud.adv_title.text == StoryDefs.ADV_LEGION:
			break
		check("совет о Легионе не перебил совет «%s» и не потрачен" % hud.adv_title.text, not lg.flags.has("advised"))
		hud.advisor_panel.visible = false
		c.changed.emit()
		await frames(6)
	# шаг 1: советник с «Пропустить обучение», стрелка на раздел «Легион» нижней полосы
	check("обучение, шаг 1 — Казармы", lg.tut_step() == "barracks" and ui.tut_active())
	check("советник шага 1 с «Пропустить обучение»", hud.advisor_panel.visible and hud.adv_skip.visible and hud.adv_title.text == StoryDefs.ADV_LEGION
		and hud.adv_text.text.contains("Готового Легиона нет"))
	check("стрелка на раздел «Легион»", hud.pointer_target == hud.cats["military"])
	await shot("tut1_barracks")
	hud.advisor_panel.visible = false
	# Д10: военный квартал и вне истории — здание Легиона в руках: «В военном квартале ✓» / «Можно и здесь» (совет, не правило)
	var sto = game.stories
	var f0: bool = sto.force
	sto.force = true
	lg.flags["quarter"] = [166.0, 205.0, 11.0]
	var t0: String = game.tool
	game.tool = "forge"
	var zin: Array = sto.zone_note("forge", Vector2(171.0, 208.0))
	var zfar: Array = sto.zone_note("forge", Vector2(120.0, 150.0))
	var zno: Array = sto.zone_note("bench", Vector2(171.0, 208.0))
	game.tool = t0
	sto.force = f0
	check("квартал вне истории: «%s» / «%s», украшения — без подписи" % [str(zin), str(zfar)], not zin.is_empty() and String(zin[0]) == "В военном квартале ✓" and bool(zin[1])
		and not zfar.is_empty() and String(zfar[0]).begins_with("Можно и здесь") and zno.is_empty())
	# шаг 2: Казармы стоят — стрелка на медальон
	c.place("barracks", Vector2(166, 205), 0.0, 0, -1, true)
	c.changed.emit()
	await frames(6)
	check("шаг 2 — медальон: стрелка на «Легион»", lg.tut_step() == "medal" and hud.pointer_target == ui.btn)
	hud.advisor_panel.visible = false               # советы города (готовый город стал «игрой» на «Посёлке») — не про Легион
	await shot("tut2_medal")
	# шаг 3: окно открыто — полоса «Шаг 3 из 4», стрелка на «В бой!»
	await click(center_of(ui.btn))
	await frames(10)
	check("шаг 3 — учебный бой: полоса в окне", lg.tut_step() == "fight" and ui.tut_bar.visible and ui.tut_lbl.text.begins_with("Шаг 3 из 4"))
	check("стрелка на «В бой!»", ui._fight_btn != null and hud.pointer_target == ui._fight_btn)
	check("карточка: учебный бой", _texts(ui.content).contains("Учебный бой"))
	await shot("tut3_fight")
	# «бой» (подделка 3D-боя): после него шаг 4 — вкладка «Войска», потом «Улучшить до 2»
	var asked := []
	var f2 := func(setup: Dictionary):
		asked.append(setup)
		fake.call(setup)
	lg.battle_requested.connect(f2)
	ui._fight(lg.stage_info(0, 0, 0))
	await frames(8)
	lg.battle_requested.disconnect(f2)
	check("первый бой — учебный (tutorial=oil, куча во 2-й волне)", asked.size() == 1 and String(asked[0].get("tutorial", "")) == "oil" and asked[0]["packs"] == [1])
	check("шаг 4 — стрелка на вкладку «Войска»", ui.visible and lg.tut_step() == "troops" and hud.pointer_target == ui.tabs["troops"])
	await shot("tut4_troops_tab")
	ui._select_tab("troops")
	await frames(6)
	check("стрелка на «На карте» у Казарм", ui._upg_btn != null and hud.pointer_target == ui._upg_btn and ui.tut_lbl.text.begins_with("Шаг 4 из 4"))
	await shot("tut4_upgrade")
	# Д10: улучшения — в карточке здания: «На карте» → карточка Казарм, стрелка на «Улучшить — …»
	await click(center_of(ui._upg_btn))
	await frames(10)
	check("«На карте»: окно закрыто, карточка Казарм, стрелка на «Улучшить»", not ui.visible and hud.info_panel.visible and String(hud.info_b.get("type", "")) == "barracks"
		and hud.lg_upg_btn != null and hud.pointer_target == hud.lg_upg_btn and hud.lg_upg_btn.text.begins_with("Улучшить — 700 ден."))
	await shot("tut4_card")
	# стрелка шага 4 — только у Казарм: у Кузницы своя «Улучшить» (доступная), стрелка на ней не стоит — она на медальоне
	var fbk: Dictionary = lg.building_rec("forge")
	var bbk: Dictionary = lg.building_rec("barracks")
	var fl0 := int(lg.blevels.get("forge", 1))
	lg.blevels["forge"] = 1
	game.select_building(fbk)
	hud.open_info(fbk)
	await frames(6)
	hud._update_pointer()
	check("шаг 4, карточка Кузницы: стрелка не на её «Улучшить» (%s)" % (hud.pointer_target.name if hud.pointer_target else "—"), not fbk.is_empty()
		and String(hud.info_b.get("type", "")) == "forge" and hud.lg_upg_btn != null and not hud.lg_upg_btn.disabled and hud.pointer_target != hud.lg_upg_btn)
	lg.blevels["forge"] = fl0
	game.select_building(bbk)
	hud.open_info(bbk)
	await frames(6)
	hud._update_pointer()
	check("снова карточка Казарм — стрелка на «Улучшить»", String(hud.info_b.get("type", "")) == "barracks" and hud.pointer_target == hud.lg_upg_btn)
	await click(center_of(hud.lg_upg_btn))
	await frames(6)
	check("улучшение Казарм началось из карточки: полоска", lg.upg.has("legionary") and not hud._lg_live.is_empty())
	hud.close_panels()
	ui._update_tut()
	await frames(4)
	var pt = hud.pointer_target
	check("обучение пройдено: полосы и стрелки нет", lg.tut_step() == "" and String(lg.flags.get("tut", "")) == "done" and not ui.tut_bar.visible
		and (pt == null or (not ui.is_ancestor_of(pt) and pt != ui.btn)))
	await shot("tut_done")
	# «Пропустить обучение» у советника: ни стрелок, ни учебного боя
	ui.close()
	for id in c.buildings.keys():
		if String(c.buildings[id]["type"]) == "barracks":
			c.remove(c.buildings[id], false)
	lg.flags = {}
	lg.upg = {}
	lg.levels["legionary"] = 1
	lg.progress = 0
	# «Легион» изучили в окне исследований: пока оно открыто, совета нет (Esc закрыл бы его вместе с окном);
	# окно закрыли через Esc (close_panels) — совет о Легионе появляется через кадр и не гаснет
	hud.advisor_panel.visible = false
	hud.research_panel.visible = true
	c.changed.emit()
	await frames(6)
	check("при открытом окне исследований совета нет и он не потрачен", not hud.advisor_panel.visible and not lg.flags.has("advised"))
	hud.close_panels()
	await frames(6)
	check("окно исследований закрыто (Esc) — снова шаг 1, советник", not hud.research_panel.visible and hud.advisor_panel.visible and hud.adv_skip.visible
		and hud.adv_title.text == StoryDefs.ADV_LEGION and lg.flags.has("advised"))
	await shot("tut1_after_research")
	await click(center_of(hud.adv_skip))
	await frames(6)
	check("«Пропустить обучение»: стрелок и полосы нет, учебный бой (масло) один раз остаётся", lg.tut_step() == "" and not lg.flags.has("tut_oil")
		and not hud.advisor_panel.visible and hud.pointer_target != hud.cats["military"]
		and String(lg.make_battle(lg.stage_info(0, 0, 0), 1).get("tutorial", "")) == "oil")
	# старое сохранение: лучник в отряде до первого боя — карточка честно предупреждает (учебный бой — на трёх легионерах)
	c.place("barracks", Vector2(166, 205), 0.0, 0, -1, true)
	var rb: Dictionary = c.place("range", Vector2(186, 205), 0.0, 0, -1, true)
	lg.squad = ["legionary", "archer", "legionary"]
	ui.view_r = -1
	ui.sel = {}
	ui.open("campaign")
	await frames(8)
	var tx := _texts(ui.content)
	check("лучник в лесном отряде: «лучше три легионера», учебный бой — «для трёх легионеров»", tx.contains("лучше три легионера")
		and tx.contains("для трёх легионеров") and not tx.contains("лучники быстро"))
	await shot("tut_archer_warn")
	lg.use_auto_squad()
	check("«Лучший состав» в лесу — три легионера", lg.squad == ["legionary", "legionary", "legionary"])
	ui.close()
	c.remove(rb, false)
	await _d10_fixes(c, lg, ui)
	game.mode = mode0
	hud._update_pointer()


## Правки Д10 (в «игре»): совет о новом здании Легиона ждёт ролик «Новый ранг» (город вырос — сначала ролик);
## улучшение кончилось, пока здание переносят, — на новом месте и при отмене оно в облике нового уровня
func _d10_fixes(c: City, lg: Legion, ui: LegionUi) -> void:
	var hud = game.hud
	ui.close()
	hud.close_panels()
	hud.advisor_panel.visible = false
	lg.flags["tut"] = "done"
	lg.flags["seen"] = true
	# город только что вырос (ролик ждёт), Кузницы в городе нет — совета о ней пока нет
	var rc = game.rank_cine
	rc.pending = {"from": 2, "to": 3, "late": true}
	lg.flags.erase("new_forge")
	lg.flags.erase("d10_new")
	for id in c.buildings.keys():
		if String(c.buildings[id]["type"]) == "forge":
			c.remove(c.buildings[id], false)
	c.changed.emit()
	var during: bool = hud.advisor_panel.visible
	var spent := lg.flags.has("new_forge")
	rc.pending = {}
	check("ролик ранга ждёт: совета о Кузнице нет и он не потрачен", not during and not spent)
	c.changed.emit()
	check("ролик позади — «%s»" % hud.adv_title.text, hud.advisor_panel.visible and hud.adv_title.text == "Новое здание Легиона: Кузница" and lg.flags.has("new_forge"))
	await shot("d10_tip_forge")
	hud.advisor_panel.visible = false
	# перенос: улучшение Казарм кончилось «в руках» — отмена переноса
	var bb: Dictionary = lg.building_rec("barracks")
	var lv := lg.b_level("barracks")
	lg.upg["legionary"] = {"to": lv + 1, "end": Legion.now() - 1.0, "total": 60.0}
	var moved: bool = game.start_move(bb)
	lg.tick()
	game._cancel_move()
	var b2: Dictionary = lg.building_rec("barracks")
	check("улучшение кончилось в руках, перенос отменён — облик %d уровня (tier %d)" % [lv + 1, int(b2.get("tier", -1))], moved and lg.b_level("barracks") == lv + 1
		and int(b2.get("tier", -1)) == Legion.vis_tier(lv + 1))
	# и постановка на место (_build_here)
	var lv2 := lg.b_level("barracks")
	lg.upg["legionary"] = {"to": lv2 + 1, "end": Legion.now() - 1.0, "total": 60.0}
	var pos: Vector2 = b2["pos"]
	game.start_move(b2)
	lg.tick()
	var err := String(game.placement("barracks", pos)["err"])
	game.hover = pos
	game._build_here()
	var b3: Dictionary = lg.building_rec("barracks")
	check("улучшение кончилось в руках, поставили — облик %d уровня (tier %d) %s" % [lv2 + 1, int(b3.get("tier", -1)), err], game.moving.is_empty() and lg.b_level("barracks") == lv2 + 1
		and int(b3.get("tier", -1)) == Legion.vis_tier(lv2 + 1))
	if not game.moving.is_empty():
		game._cancel_move()


## Лес — загадка на выбор отряда: «Пращники в кустах» тремя легионерами — карточка советует лучника, шансы прикидкой
## прогоном боёв («Победа ~0% · с лучником ~100%»), кнопка «Под бой» ставит лучника; условия трёх звёзд на карточке
func _card_puzzle(c: City, lg: Legion, ui: LegionUi) -> void:
	var rb: Dictionary = c.place("range", Vector2(186, 205), 0.0, 0, -1, true)
	var p0 := lg.progress
	var st0: Dictionary = lg.stars.duplicate()
	var lv0: Dictionary = lg.levels.duplicate()
	lg.levels = {"legionary": 1, "spearman": 1, "archer": 1, "ballista": 1, "catapult": 1}   # на уровне боя (T=1)
	lg.progress = 1
	lg.stars = {"0-0-0": Legion.STAR_WIN | Legion.STAR_TASK}
	lg.squad = ["legionary", "legionary", "legionary"]
	ui.view_r = 0
	ui.sel = {}
	ui._select_tab("campaign")
	for i in 240:
		if not ui.odds_busy():
			break
		await frames(2)
	await frames(16)                               # _tick_live обновил надпись шансов
	var tx := _texts(ui.content)
	check("карточка «Пращники в кустах»: совет лучника, шансы прикидкой, условия звёзд", tx.contains("Пращники в кустах") and tx.contains("возьмите лучника")
		and tx.contains("с лучником ~") and tx.contains("Победа быстрее 20 с") and tx.contains("Все вернулись из боя"))
	await shot("card_slingers")
	var ab: Button = null
	for b in ui.content.find_children("*", "Button", true, false):
		if (b as Button).text == "Под бой":
			ab = b
	if ab:
		await click(center_of(ab))
		await frames(8)
	check("«Под бой» ставит лучника", lg.squad.has("archer") and not _texts(ui.content).contains("возьмите лучника"))
	for i in 240:
		if not ui.odds_busy():
			break
		await frames(2)
	await frames(16)
	await shot("card_slingers_bow")
	# «Волчья тропа» с лучником: советует трёх легионеров
	lg.progress = 2
	ui.sel = {}
	ui._rebuild()
	await frames(6)
	check("«Волчья тропа» с лучником — «загрызут»", _texts(ui.content).contains("Волки загрызут лучника"))
	lg.squad = ["legionary", "legionary", "legionary"]
	c.remove(rb, false)
	lg.progress = p0
	lg.stars = st0
	lg.levels = lv0
	ui.view_r = 0
	ui.sel = {}
	ui._rebuild()


## Трофей «Телега атамана» в городе (все 30 звёзд леса): открыт, ставится бесплатно, кадр вблизи
func _trophy(c: City, lg: Legion) -> void:
	lg.trophies["forest"] = true
	check("трофей открыт в городе", c.unlocked("trophy_cart"))
	var put := {}
	for p: Vector2 in [Vector2(176, 186), Vector2(170, 180), Vector2(196, 184), Vector2(160, 176), Vector2(204, 196), Vector2(150, 190)]:
		var pl: Dictionary = game.placement("trophy_cart", p)
		if String(pl["err"]) == "":
			put = c.place("trophy_cart", pl["pos"], pl["yaw"], pl["variant"], pl["color"])
			break
	check("трофей поставлен", not put.is_empty())
	if put.is_empty():
		return
	var pos: Vector2 = put["pos"]
	game.hud.visible = false
	game.rig.set_view(Vector3(pos.x, 1.0, pos.y), 200, 26, 10)
	await frames(70)
	await shot("trophy_city")
	game.rig.set_view(Vector3(pos.x, 1.0, pos.y), 160, 38, 24)
	await frames(50)
	await shot("trophy_city_far")
	game.hud.visible = true


## Все надписи внутри узла — одной строкой
func _texts(n: Node) -> String:
	var out := ""
	for l in n.find_children("*", "Label", true, false):
		out += (l as Label).text + " | "
	return out


## Сеть боёв с городами для проверки: то, что должен уметь настоящий модуль (Account или scripts/legion_net.gd)
class FakeNet extends RefCounted:
	var reports := 0
	var list := [
		{"name": "Аквилея", "rating": 120, "city_level": 5, "snapshot": {"v": 1, "squad": [{"type": "legionary", "level": 2}, {"type": "archer", "level": 2}, {"type": "legionary", "level": 2}], "perks": {"oil": 1}}},
		{"name": "Новый Карфаген", "rating": 80, "city_level": 4, "snapshot": {"v": 1, "squad": [{"type": "legionary", "level": 1}, {"type": "legionary", "level": 1}]}},
		{"name": "Сиракузы", "rating": 260, "city_level": 6, "snapshot": {"v": 1, "squad": [{"type": "legionary", "level": 6}, {"type": "spearman", "level": 5}, {"type": "archer", "level": 6}, {"type": "ballista", "level": 5}]}},
	]

	func pvp_ready() -> bool:
		return true

	func pvp_opponents(cb: Callable) -> void:
		cb.call(list, "")

	func pvp_report(_setup: Dictionary, _out: Dictionary) -> void:
		reports += 1
