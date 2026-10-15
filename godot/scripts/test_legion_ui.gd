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
		lg.stars[Legion.stage_key(cyc, r, k % 10)] = 3 if rng.randf() < 0.6 else 2
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
	await shot("troops")
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
	lg.stars = {"0-0-0": 3, "0-0-1": 2}
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
	print("снимков: ", shots.size())
	get_tree().quit()


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
	# «Легион собран!» ждёт, пока советник свободен (игрок нажал «Понятно» — совет при следующем обновлении города)
	for i in 6:
		if not hud.advisor_panel.visible or hud.adv_title.text == "Легион собран!":
			break
		check("«Легион собран!» не перебил совет «%s» и не потрачен" % hud.adv_title.text, not lg.flags.has("advised"))
		hud.advisor_panel.visible = false
		c.changed.emit()
		await frames(6)
	# шаг 1: советник с «Пропустить обучение», стрелка на раздел «Легион» нижней полосы
	check("обучение, шаг 1 — Казармы", lg.tut_step() == "barracks" and ui.tut_active())
	check("советник шага 1 с «Пропустить обучение»", hud.advisor_panel.visible and hud.adv_skip.visible and hud.adv_title.text == "Легион собран!")
	check("стрелка на раздел «Легион»", hud.pointer_target == hud.cats["military"])
	await shot("tut1_barracks")
	hud.advisor_panel.visible = false
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
	check("стрелка на «Улучшить до 2»", ui._upg_btn != null and hud.pointer_target == ui._upg_btn and ui.tut_lbl.text.begins_with("Шаг 4 из 4"))
	await shot("tut4_upgrade")
	ui._do("upgrade", "legionary")
	await frames(4)
	ui._rebuild()
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
	# окно закрыли через Esc (close_panels) — совет «Легион собран!» появляется через кадр и не гаснет
	hud.advisor_panel.visible = false
	hud.research_panel.visible = true
	c.changed.emit()
	await frames(6)
	check("при открытом окне исследований совета нет и он не потрачен", not hud.advisor_panel.visible and not lg.flags.has("advised"))
	hud.close_panels()
	await frames(6)
	check("окно исследований закрыто (Esc) — снова шаг 1, советник", not hud.research_panel.visible and hud.advisor_panel.visible and hud.adv_skip.visible
		and hud.adv_title.text == "Легион собран!" and lg.flags.has("advised"))
	await shot("tut1_after_research")
	await click(center_of(hud.adv_skip))
	await frames(6)
	check("«Пропустить обучение»: стрелок и полосы нет, учебный бой (масло) один раз остаётся", lg.tut_step() == "" and not lg.flags.has("tut_oil")
		and not hud.advisor_panel.visible and hud.pointer_target != hud.cats["military"]
		and String(lg.make_battle(lg.stage_info(0, 0, 0), 1).get("tutorial", "")) == "oil")
	# старое сохранение: лучник в отряде до первого боя — карточка честно предупреждает (лес посчитан на трёх легионерах)
	c.place("barracks", Vector2(166, 205), 0.0, 0, -1, true)
	var rb: Dictionary = c.place("range", Vector2(186, 205), 0.0, 0, -1, true)
	lg.squad = ["legionary", "archer", "legionary"]
	ui.view_r = -1
	ui.sel = {}
	ui.open("campaign")
	await frames(8)
	var tx := _texts(ui.content)
	check("лучник в лесном отряде: «Лучник в лесу без прикрытия», учебный бой — «для трёх легионеров»", tx.contains("Лучник в лесу без прикрытия")
		and tx.contains("для трёх легионеров") and not tx.contains("лучники быстро"))
	await shot("tut_archer_warn")
	lg.use_auto_squad()
	check("«Лучший состав» в лесу — три легионера", lg.squad == ["legionary", "legionary", "legionary"])
	ui.close()
	c.remove(rb, false)
	game.mode = mode0
	hud._update_pointer()


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
