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
	c.auto_hire = true  # legacy fixture
	var lg: Legion = c.legion
	var ui := LegionUi.of(game.hud)
	# окно проверяется без настоящего 3D-боя (game.gd подключает LegionBattle): «3D-бой» ниже — подделка
	for cn: Dictionary in lg.battle_requested.get_connections():
		lg.battle_requested.disconnect(cn["callable"])
	check("окно создано", ui != null)
	check("медальон виден только с исследованием «Легион»", ui.btn_wrap.visible == lg.window_open())
	# подсказка серого медальона (почему закрыт + что такое Легион) не шире MIN_W: подсказка Godot строки не переносит
	var tf: Font = game.hud.theme_main.get_font("font", "TooltipLabel")
	var tw := 0.0
	var why := lg.lock_text()
	for ln in (why + "\n" + Legion.LOCK_ABOUT).split("\n"):
		tw = maxf(tw, tf.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 32.0)
	check("подсказка серого медальона умещается при крупном интерфейсе: %d из %d точек" % [tw, Hud.MIN_W], tw < Hud.MIN_W)
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
	check("чудеса перенесены в город", not ui.tabs.has("wonders") and not ui.has_method("_wonder_card"))
	await _soldiers(c, lg, ui)
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
		ui._tex["map:" + String(Legion.regions()[r]["id"])] = null
		ui.view_r = r
		ui.sel = {}
		ui._rebuild()
		await shot("placeholder_r%d" % r)
		ui._tex.erase("map:" + String(Legion.regions()[r]["id"]))
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
	check("в раннем Легионе тоже нет чудес", not ui.tabs.has("wonders"))
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
	check("квартал: 8 прежних зданий, Легион не меняет облик %s" % str(tiers), tiers == [0, 0, 0, 0, 0, 0, 0, 0])
	print("D10 DRAWCALLS quality=%s quarter of 8 Legion buildings: empty %d → all level 1 %d (+%d) → levels 2–6 %d (+%d for growth)" % [str(game.settings.get("quality", "?")),
		dc0, dc1, dc1 - dc0, dc2, dc2 - dc1])
	check("облик по уровням стоит не больше 40 вызовов отрисовки на весь квартал (+%d)" % (dc2 - dc1), dc2 - dc1 <= 40)
	game.rig.set_view(Vector3(163.0, 0, 213.5), 12, 46, 42)
	await get_tree().create_timer(2.5).timeout           # облачка нового уровня рассеялись
	await shot("d10_quarter")
	# Старое здание можно осмотреть, военные действия остаются в Легионе.
	var bb: Dictionary = lg.building_rec("barracks")
	game.select_building(bb)
	hud.open_info(bb)
	await frames(8)
	check("городская карточка без военного улучшения", _texts(hud.info_box).contains("Военные постройки — только в форте") and hud.lg_upg_btn == null)
	await shot("d10_card_legacy")
	check("военные цены и эффекты остаются в Легионе", lg.upgrade_info("forge")["to"] == 4 and String(lg.b_effect("forge", 4)[0]).contains("+12%"))
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
	game.tutorial.step = Tutorial.STEPS.size()
	c.tips["tut"] = -1
	game.tutorial.card.hide()
	game.tutorial.camera_keys.hide()
	game.tutorial.next_btn.hide()
	hud.guidance_queue.clear()
	hud._clear(hud.notes_box)
	hud._ptr_shown = {}
	ui.close()
	hud.advisor_panel.visible = false
	c.level = 3
	c.money = 20000.0
	lg.flags = {}
	lg.progress = 0
	lg.upg = {}
	lg.levels["legionary"] = 1
	lg.perks = {"oil": 1, "testudo": 0, "bandage": 0, "volley": 0, "horn": 0}
	c.changed.emit()
	await frames(6)
	check("город не предлагает военное обучение", not ui.advice_pending() and hud._do_target({"kind": "legion"}) == null and not lg.flags.has("advised"))
	if lg.building_rec("barracks").is_empty():
		c.place("barracks", Vector2(166, 205), 0.0, 0, -1, true)
	ui.view_r = -1
	ui.sel = {}
	ui.open("campaign")
	await frames(10)
	check("учебный бой доступен внутри Легиона", ui._fight_btn != null and _texts(ui.content).contains("Учебный бой"))
	var asked := []
	var capture := func(setup: Dictionary):
		asked.append(setup)
		fake.call(setup)
	lg.battle_requested.connect(capture)
	ui._fight(lg.stage_info(0, 0, 0))
	await frames(8)
	lg.battle_requested.disconnect(capture)
	check("учебный бой сохраняет масло и вторую волну", asked.size() == 1 and String(asked[0].get("tutorial", "")) == "oil" and asked[0]["packs"] == [1])
	check("военное улучшение доступно без городской карточки", lg.upgrade("legionary") and lg.upg.has("legionary"))
	ui._update_tut()
	check("обучение Легиона завершается", lg.tut_step() == "" and String(lg.flags.get("tut", "")) == "done")
	await shot("tut_inside_legion")
	ui.close()
	lg.upg = {}
	lg.progress = 0
	lg.flags = {}
	lg.tut_skip()
	check("пропуск сохраняет учебный бой с маслом", lg.tut_step() == "" and not lg.flags.has("tut_oil"))
	var rb: Dictionary = c.place("range", Vector2(186, 205), 0.0, 0, -1, true)
	lg.squad = ["legionary", "archer", "legionary"]
	ui.sel = {}
	ui.open("campaign")
	await frames(8)
	var tx := _texts(ui.content)
	check("предупреждение о лучнике в учебном бою", tx.contains("лучше три легионера") and tx.contains("для трёх легионеров"))
	# Ранний отряд: предыдущие кадры оставили казармы всех родов войск.
	# Они теперь доступны сами по себе, поэтому исключаем их из этой фикстуры.
	var all_buildings := c.buildings
	c.buildings = all_buildings.duplicate()
	for id in c.buildings.keys():
		if String(c.buildings[id]["type"]) in ["spearcamp", "ballistae", "catapults"]:
			c.buildings.erase(id)
	var army_off0 := lg.army_off
	lg.army_off = true
	lg.use_auto_squad()
	check("лучший ранний состав в лесу — три легионера", lg.squad == ["legionary", "legionary", "legionary"])
	lg.army_off = army_off0
	c.buildings = all_buildings
	ui.close()
	c.remove(rb, false)
	await _d10_fixes(c, lg, ui)
	game.mode = mode0
	hud._update_pointer()


func _d10_fixes(c: City, lg: Legion, ui: LegionUi) -> void:
	var hud = game.hud
	ui.close()
	hud.close_panels()
	hud.advisor_panel.visible = false
	lg.flags["tut"] = "done"
	lg.flags["seen"] = true
	lg.flags.erase("advised")
	c.changed.emit()
	check("советы Легиона не занимают город", not ui.advice_pending() and not lg.flags.has("advised"))
	# перенос: улучшение Казарм кончилось «в руках» — отмена переноса
	var bb: Dictionary = lg.building_rec("barracks")
	var saved_tier := int(bb["tier"])
	var lv := lg.b_level("barracks")
	lg.upg["legionary"] = {"to": lv + 1, "end": Legion.now() - 1.0, "total": 60.0}
	var moved: bool = game.start_move(bb)
	lg.tick()
	game._cancel_move()
	var b2: Dictionary = lg.building_rec("barracks")
	check("улучшение кончилось в руках, перенос отменён — облик %d уровня (tier %d)" % [lv + 1, int(b2.get("tier", -1))], moved and lg.b_level("barracks") == lv + 1
		and int(b2.get("tier", -1)) == saved_tier)
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
		and int(b3.get("tier", -1)) == saved_tier)
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
	var was_open := c.unlocked("trophy_cart")
	lg.trophies["forest"] = true
	check("военный трофей не меняет город", c.unlocked("trophy_cart") == was_open)
	c.research["deco_stone"] = true
	check("телега открыта городским исследованием", c.unlocked("trophy_cart"))
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


## Легион 2.0, этап 1: вкладка «Воины» (только новая игра «Уютного Рима»): свои воины — готов, тренируется, ранен;
## новобранцы дня с ценой; в старом городе вкладки нет
func _soldiers(c: City, lg: Legion, ui) -> void:
	check("«Воины» в старом городе не видно", not (ui.tabs["soldiers"] as Button).visible or c.cozy_v >= 1)
	var cv := c.cozy_v
	var prog0 := lg.progress                 # поход 2.0 переводит продвижение (flags.camp2) — после снимков вернём как было
	c.cozy_v = 1
	lg.army_tick()
	for i in 3:
		lg.recruit(0)
	var a: Dictionary = lg.soldiers[0]
	lg.train(int(a["id"]))
	(lg.soldiers[2] as Dictionary)["rank"] = 3
	(lg.soldiers[3] as Dictionary)["wound_end"] = Legion.now() + 1500.0
	lg.recruit_day = -1
	lg.army_tick()
	# вещи разной редкости: на втором воине — меч, доспех, шлем, знак; на Складе — ещё несколько
	var s0: Dictionary = lg.soldiers[1]
	for e in [{"slot": "weapon", "cls": String(s0["cls"]), "rarity": 3, "ilvl": 6}, {"slot": "armor", "cls": "", "rarity": 2, "ilvl": 5},
			{"slot": "helmet", "cls": "", "rarity": 4, "ilvl": 7}, {"slot": "badge", "cls": "", "rarity": 1, "ilvl": 4}]:
		lg.equip(int(s0["id"]), int(lg.add_item(e)["id"]))
	for e in [{"slot": "weapon", "cls": String(s0["cls"]), "rarity": 1, "ilvl": 6}, {"slot": "weapon", "cls": String(s0["cls"]), "rarity": 0, "ilvl": 3},
			{"slot": "offhand", "cls": String(s0["cls"]), "rarity": 2, "ilvl": 5}, {"slot": "armor", "cls": "", "rarity": 0, "ilvl": 2}]:
		lg.add_item(e)
	# этап 6: две вещи Галльского набора на втором воине — строка набора в карточке
	for e in [{"slot": "offhand", "cls": String(s0["cls"]), "rarity": 3, "ilvl": 6, "set": "gallic"}, {"slot": "helmet", "cls": "", "rarity": 3, "ilvl": 6, "set": "gallic"}]:
		lg.equip(int(s0["id"]), int(lg.add_item(e)["id"]))
	lg.relics = {"gallic": 2, "british": 1}
	ui._select_tab("soldiers")
	await frames(6)
	var tx := _texts(ui.content)
	check("«Воины»: видна вкладка, воины и новобранцы", (ui.tabs["soldiers"] as Button).visible and tx.contains("Ваши воины") and tx.contains("Новобранцы сегодня")
		and tx.contains("Тренируется") and tx.contains("Ранен"))
	check("«Воины»: строка набора «Галльский 2/4»", tx.contains("Галльский 2/4"))
	await shot("soldiers")
	# этап 6: таланты — у воина 3-го ранга открыт первый; «Рубака» (+8% урона) у легионера или первый вариант у других
	var s2: Dictionary = lg.soldiers[2]
	check("таланты: у воина 3-го ранга можно выбрать один", Soldiers.talent_free(s2) == 1 and lg.can_talent(int(s2["id"]), 1, 0) != "")
	var tt := String(Soldiers.CLASS_IDS[0]) if not Soldiers.TALENTS.has(String(s2["cls"])) else String(s2["cls"])
	var a0 := float(lg.soldier_stats(s2, String(Soldiers.CLASSES[tt]["units"][0]))["atk"])
	check("таланты: выбран", lg.set_talent(int(s2["id"]), 0, 1 if tt == "legionary" else 0) and Soldiers.talents_of(s2).size() == 1)
	if tt == "legionary":
		var a1 := float(lg.soldier_stats(s2, "legionary")["atk"])
		check("таланты: «Рубака» прибавил урон (%d → %d)" % [a0, a1], a1 > a0)
	ui._talents_win(int(s2["id"]))
	await frames(6)
	check("окно талантов: пять ступеней", ui.overlay != null and _texts(ui.overlay).contains("Ранг 10") and _texts(ui.overlay).contains("Таланты:"))
	await shot("soldiers_talents")
	ui._close_overlay()
	ui._daily_win()
	await frames(6)
	check("задания дня: окно с пятью делами", ui.overlay != null and _texts(ui.overlay).contains("Задания дня"))
	await shot("soldiers_daily")
	ui._close_overlay()
	ui._gear_pick(int(s0["id"]), "weapon")
	await frames(6)
	check("выбор вещи: надетая и запасные", ui.overlay != null and _texts(ui.overlay).contains("Надето") and _texts(ui.overlay).contains("Добротный"))
	await shot("soldiers_gear")
	ui._store()
	await frames(6)
	check("Склад: продать", ui.overlay != null and _texts(ui.overlay).contains("Склад:") and _texts(ui.overlay).contains("урона"))
	await shot("soldiers_store")
	lg.shards = [6, 3, 1, 0, 0]
	lg.forging = {"slot": "weapon", "cls": "legionary", "rarity": 2, "ilvl": 6, "end": Legion.now() + 3000.0, "total": 14400.0}
	ui._forge_win()
	await frames(6)
	check("Кузница: обломки, ковка, редкости", ui.overlay != null and _texts(ui.overlay).contains("Обломки") and _texts(ui.overlay).contains("Куётся")
		and _texts(ui.overlay).contains("Легендарный"))
	check("Кузница: вещи наборов и реликвии", _texts(ui.overlay).contains("Вещи наборов") and _texts(ui.overlay).contains("Галльский · реликвий 2"))
	await shot("soldiers_forge")
	lg.forging = {}
	ui._close_overlay()
	# мастерские: плитки на «Войсках» (только новая игра), материалы в шапке «Воинов»
	check("мастерские есть в новой игре", Legion.BUILDING_IDS.has("smelter") and c.unlocked("smelter") == (c.level >= 2))
	ui._select_tab("troops")
	await frames(6)
	check("«Войска»: мастерских в сетке нет — окно не растёт", not _texts(ui).contains("Плавильня"))
	await shot("troops_cozy")
	await _camp2(c, lg, ui)
	ui._select_tab("soldiers")
	await frames(4)
	c.cozy_v = cv
	lg.progress = prog0
	lg.flags.erase("camp2")
	lg.sync_v2()
	ui._select_tab("campaign")


## Поход Легиона 2.0 (новая игра): 10 провинций по 15 боёв — на старой карте 9 площадок, ещё 5 встают между ними;
## младший босс на 8-м бою, провиант — очки; карточка главного босса с советом о его приёме
func _camp2(c: City, lg: Legion, ui) -> void:
	check("поход 2.0 включён в новой игре", Legion.V2 and Legion.regions().size() == 10 and Legion.stages() == 15)
	var fm: bool = lg.free_mode
	lg.free_mode = true
	lg.progress = 4 * 15 + 7
	ui._select_tab("campaign")
	ui.view_r = 4
	ui.view_c = 0
	ui.sel = {"c": 0, "r": 4, "s": 7}
	ui._rebuild()
	await frames(6)
	var tx := _texts(ui.content)
	check("поход 2.0: Британия, бой 8 из 15 — младший босс", tx.contains("Британия") and tx.contains("Колесничий"))
	check("поход 2.0: провиант — очки", tx.contains("есть") and tx.contains("из %d" % lg.food_cap()))
	await shot("camp2_junior")
	ui.sel = {"c": 0, "r": 4, "s": 14}
	ui._rebuild()
	await frames(6)
	check("поход 2.0: Боудикка и её колесницы", _texts(ui.content).contains("Боудикка") and _texts(ui.content).contains("олесниц"))
	await shot("camp2_boss")
	ui.view_r = 0
	ui.sel = {"c": 0, "r": 0, "s": 14}
	lg.progress = 14
	ui._rebuild()
	await frames(6)
	check("поход 2.0: Италия — Спартак", _texts(ui.content).contains("Спартак"))
	await shot("camp2_italy")
	# ветеранский поход: после Дакии те же провинции, у врагов особенности
	lg.progress = 10 * 15 + 3
	ui.view_c = 1
	ui.view_r = 0
	ui.sel = {"c": 1, "r": 0, "s": 3}
	ui._rebuild()
	await frames(6)
	check("ветеранский поход: особенности врагов в карточке", _texts(ui.content).contains("Ветераны:") and _texts(ui.content).contains("ветераны"))
	await shot("camp2_vet")
	ui.view_c = 0
	lg.free_mode = fm
	# Храм Марса: умения до 10; «Знамя орла» и «Огненные стрелы» (провинции 5 и 8)
	lg.perks["eagle"] = 1
	lg.perks["fire"] = 2
	var mb: Dictionary = c.place("mars", Vector2(206, 205), 0.0, 0, -1, true)
	lg.blevels["mars"] = 3
	ui._select_tab("troops")
	await frames(6)
	var mt := _texts(ui.content)
	check("Храм Марса: умения до 8, новые умения в списке", mt.contains("Знамя орла") and mt.contains("Огненные стрелы") and lg.perk_max() == 8)
	await shot("troops_mars")
	ui.close()
	await frames(4)
	if not mb.is_empty():
		var mp := c.door_point(mb)
		game.rig.set_view(Vector3(mp.x, Land.BASE_Y, mp.y - 1.0), 15.0, 24.0, 15.0)
		await frames(20)
		await shot("mars_temple")
		c.remove(mb, false, true)
	ui.open("soldiers")
	await frames(4)
