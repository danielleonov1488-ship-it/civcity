extends Node
## Проверка «Историй горожан» (scripts/stories.gd) и первой истории «Где Мурка?»:
## часы историй идут после обучения, первая — через FIRST_H, между историями — GAP_H; ранг; предложение и «Отложить»;
## одна история за раз; ролик просьбы (облачко с портретом, выбор), rank_cine.calm() — false в ролике; место поисков
## теснее через 3 ч, след лапки через 6 ч; щелчок по кошке (34 точки); ролик встречи; награда (украшение, строка счастья
## дома, очки, кошка); пропуск ролика — действие всё равно случилось; сам нашёл (12 ч) — без очков; сохранение посреди шага;
## дом снесли (ждём семью, она заселилась — история идёт; не заселилась — прервалась); виды целей других историй.
## Снимки — .work/gd/story_*.png. Итог: «STORY DONE fails=N».
## mode=owner — город владельца (копия сохранения в CIVCITY_SAVEDIR): загрузка без историй, предложение, кошка находится.
var game
var c: City
var hud
var sto: Stories
var fails := 0
var out := "D:/CivCity/.work/gd/"
var cands := []
var mode := ""
var kid_home := {}
var kid_fam := "Корнелии"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv[0] == "mode" and kv.size() > 1:
			mode = kv[1]
	Game.boot = {"play": "1"} if mode == "owner" else {"new": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print(("  ok   " if ok else "FAIL ") + what)


func shot(name: String) -> void:
	if hud.advisor_panel.visible:
		hud.advisor_panel.visible = false   # чужой совет (семьи не едут…) не заслоняет кадр
		await frames(3)
	DirAccess.make_dir_recursive_absolute(out)
	get_viewport().get_texture().get_image().save_png(out + name)
	print("SHOT ", name)


func reset_place() -> void:
	game.last_snap_n = Vector2.ZERO
	game.last_snap_p = Vector2.INF
	game.manual_yaw = false
	game.yaw_set = false
	game.place_lock = {}
	game.tool_yaw = 0.0
	game.snap = true


func street(a: Vector2, b: Vector2) -> void:
	var ch: Array = game.land.paint_line(a, b, 1.3, Land.Kind.ROAD, true)
	c.road_cells += ch.size()
	game.people.refresh(game.land.road_chunks.keys())
	var dir := (b - a).normalized()
	var side := Vector2(-dir.y, dir.x)
	for i in int(a.distance_to(b)) + 1:
		for s in [-3.2, 3.2]:
			cands.append(a + dir * i + side * s)


func put(type: String, target: Vector2) -> Dictionary:
	cands.sort_custom(func(p, q): return p.distance_squared_to(target) < q.distance_squared_to(target))
	for p in cands.slice(0, 300):
		reset_place()
		var pl: Dictionary = game.placement(type, p)
		if pl["err"] == "" and pl["sub"] == "road":
			var b := c.place(type, pl["pos"], pl["yaw"], pl["variant"], pl["color"])
			game._show(b)
			return b
	return {}


## Украшение где-нибудь у точки (на траве или площади)
func deco(type: String, at: Vector2) -> Dictionary:
	for r in range(0, 8):
		for k in 8:
			var p := at + Vector2(cos(k * 0.8), sin(k * 0.8)) * r
			reset_place()
			var pl: Dictionary = game.placement(type, p)
			if pl["err"] == "":
				var b := c.place(type, pl["pos"], pl["yaw"], pl["variant"], pl["color"])
				game._show(b)
				return b
	return {}


## Семья в дом (как после загрузки): жители, ребёнок — третий
func settle(h: Dictionary, nm: String, kid := false) -> void:
	var n := c.house_cap(h)
	c.settled(int(h["id"]), n, nm)
	var fam: Array = game.people._make_family(nm, n, int(h["id"]), c.door_point(h))
	if kid and fam.size() >= 3:
		fam[2]["child"] = true
		fam[2]["female"] = false


## Кто у Корнелиев (отладка)
func who_kid(tag: String) -> void:
	var rs := []
	for r in game.people.residents:
		if r["fam"] == kid_fam:
			rs.append("%d:%s:%s" % [int(r["home"]), "реб" if r["child"] else "взр", r["state"]])
	print("  [%s] Корнелии: %s; дом %s; семьи в доме: %s; предложение: %s" % [tag, rs, kid_home.get("id"), kid_home.get("families"), c.stories["offer"]])


## Состояние историй с нуля (а город, дома, жители — те же)
func fresh(h := 100) -> void:
	if not sto.cat.is_empty():
		game.people.drop_cat(sto.cat)
		sto.cat = {}
	for cc in game.people.cats.duplicate():
		if cc.has("named") or cc.has("story"):
			game.people.drop_cat(cc)
	c.stories = City.stories_new()
	c.stories["h"] = h
	c.research.erase("s_cat")
	sto._h_seen = -1
	sto._tried = ""
	sto.tick()


## Ждать, пока ролик начнётся / кончится
func wait_kit(on: bool, sec: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while (sto.kit != null) != on and (Time.get_ticks_msec() - t0) / 1000.0 < sec:
		await get_tree().process_frame
	return (sto.kit != null) == on


## Ждать такт ролика вида kind (say, choice…), не дольше sec
func wait_beat(kind: String, sec: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < sec:
		if sto.cine.is_empty():
			return false
		var i := int(sto.cine.get("i", -1))
		var beats: Array = sto.cine.get("beats", [])
		if i >= 0 and i < beats.size() and String(beats[i][0]) == kind:
			return true
		await get_tree().process_frame
	return false


func press_key(k: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.pressed = down
		get_viewport().push_input(ev)


## Досмотреть ролик: «дальше», пока не кончится; на выборе — первая кнопка
func play_through(sec := 30.0, shot_at := "", shot_name := "", shot_at2 := "", shot_name2 := "") -> void:
	var t0 := Time.get_ticks_msec()
	var shot_done := false
	var shot2_done := false
	while sto.kit != null and (Time.get_ticks_msec() - t0) / 1000.0 < sec:
		await frames(8)
		if sto.cine.is_empty():
			continue
		var i := int(sto.cine.get("i", -1))
		var beats: Array = sto.cine.get("beats", [])
		if i < 0 or i >= beats.size():
			continue
		var kind := String(beats[i][0])
		if shot_at != "" and kind == shot_at and not shot_done and not sto.ui.typing():
			shot_done = true
			await frames(20)
			await shot(shot_name)
		if shot_at2 != "" and kind == shot_at2 and not shot2_done:
			shot2_done = true
			sto.ui.finish_typing()
			await frames(30)
			await shot(shot_name2)
		if kind in ["say", "choice"] and sto.cine.get("wait", false):
			sto.ui.finish_typing()
			await frames(4)
			sto._next()
		elif kind == "choice" and sto.ui.choosing():
			sto.ui.finish_typing()
			var b: Button = sto.ui.pills.get_child(0)
			b.pressed.emit()


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	c = game.city
	hud = game.hud
	sto = game.stories
	game.can_save = false                # тест не пишет сохранение
	sto.force = true
	game.rank_cine.force = false
	if mode == "owner":
		await _owner()
		print("STORY DONE fails=", fails)
		get_tree().quit()
		return
	if game.tutorial.active():
		game.tutorial.step = Tutorial.STEPS.size()
		game.tutorial.card.visible = false
	c.tips["tut"] = -1
	c.tips["ui"] = 3
	hud.apply_reveal(3)
	hud.advisor_panel.visible = false
	for t in ["rank_tip", "fest_tip", "floor_tool", "full_money", "full_rp", "name_tip", "v22_pace"]:
		c.tips[t] = true                 # чужие советы не мешают проверить совет историй
	game._set_hour(10.5)
	hud.set_speed(0.0)                   # часы игры стоят (часы историй двигает проверка); ролик сам ставит ×1
	c.money = 5000.0
	for r in ["q_garden", "q_market", "deco_trees", "deco_flowers"]:
		c.research[r] = true
	# ---------- городок: улица, дома с семьями (у Корнелиев — сын), сено и куст в 15–30 м ----------
	street(Vector2(170, 110), Vector2(170, 178))
	street(Vector2(170, 144), Vector2(206, 144))
	kid_home = put("house_pleb", Vector2(172, 124))
	settle(kid_home, kid_fam, true)
	var others := []
	for i in 6:
		var h := put("house_pleb", Vector2(176 + i * 4, 150))
		if not h.is_empty():
			settle(h, "Проба %d" % i)
			others.append(h)
	var hay := deco("hay", Vector2(178, 146))
	var bush := deco("bush", Vector2(160, 150))
	c.compute()
	await frames(10)
	print("kid home ", kid_home.get("id"), " at ", kid_home.get("pos"), " pop=", c.stats["pop"], " hay=", hay.get("pos"), " bush=", bush.get("pos"))
	check(not kid_home.is_empty() and int(c.stats["pop"]) >= 20, "городок: дом Корнелиев и %d жителей" % int(c.stats["pop"]))
	await _timing()
	await _offer_flow()
	await _search_and_find()
	await _journal()
	await _skip_applies()
	await _give_up()
	await _save_mid_step()
	await _demolished()
	await _goal_kinds()
	StoryDefs.extra = []
	print("STORY DONE fails=", fails)
	get_tree().quit()


# ---------- часы, первая история, ранг, промежуток ----------

func _timing() -> void:
	print("== часы и сроки")
	var S := c.stories
	S["h"] = 0
	c.tips["tut"] = 2                    # обучение идёт — часы историй стоят
	for i in 5:
		c._story_hour()
	check(int(S["h"]) == 0, "во время обучения часы историй стоят (h=%d)" % int(S["h"]))
	c.tips["tut"] = -1
	for i in 3:
		c._story_hour()
	check(int(S["h"]) == 3, "после обучения часы идут (h=%d)" % int(S["h"]))
	c.level = 1
	sto.tick()
	check((S["offer"] as Dictionary).is_empty() and not sto.time_ok(), "3 ч после обучения — рано (FIRST_H=%d)" % StoryDefs.FIRST_H)
	c.level = 0
	c._story_hour()
	sto.tick()
	check(sto.time_ok() and (S["offer"] as Dictionary).is_empty(), "4 ч, но ранг 0 (лачуги) — «Где Мурка?» не предлагают")
	c.level = 1
	var bell0: int = hud.bell_count
	var notes0: int = hud.notes_box.get_child_count()
	sto.tick()
	check(String(S["offer"].get("id", "")) == "cat", "ранг «Хутор» — предложение «Где Мурка?» (%s)" % S["offer"])
	check(int(S["offer"].get("home", -1)) == int(kid_home["id"]) and String(S["offer"].get("fam", "")) == kid_fam, "просит сын Корнелиев")
	check(hud.bell_count == bell0 + 1 and hud.notes_box.get_child_count() == notes0, "событие — в колокольчике, всплывашки нет")
	# промежуток после истории: GAP_H
	S["last_h"] = 10
	S["h"] = 25
	check(not sto.time_ok(), "15 ч после прошлой истории — рано")
	S["h"] = 26
	check(sto.time_ok(), "16 ч (GAP_H) — пора")
	S["last_h"] = -1
	S["h"] = 4


# ---------- предложение: свиток, золотая строка, советник, «Отложить», ролик просьбы ----------

func _offer_flow() -> void:
	print("== предложение")
	var S := c.stories
	await frames(30)
	check(hud.badges.has("story"), "свиток над домом просящего")
	var info: Dictionary = sto.row_info()
	check(String(info.get("title", "")) == "Где Мурка?" and (info.get("buttons", []) as Array).size() == 2, "золотая строка: «%s» — %s" % [info.get("title"), info.get("text")])
	hud.refresh()
	await frames(2)
	var has_row := false
	for ch in hud.tasks_box.get_children():
		if ch is PanelContainer:
			has_row = true
	check(hud.tasks_panel.visible and has_row, "золотая строка — наверху «Просьб горожан»")
	if not c.tips.has("story_tip"):
		hud.advisor_panel.visible = false
		sto._advise_once()
	check(c.tips.has("story_tip") and hud.advisor_panel.visible and hud.adv_title.text == "Истории горожан", "советник один раз объяснил истории")
	hud.advisor_panel.visible = false
	# снимок: дом со свитком и строка
	var hp: Vector2 = kid_home["pos"]
	game.rig.set_view(Vector3(hp.x + 2, Land.BASE_Y, hp.y + 3), 215.0, 38.0, 26.0)
	await frames(40)
	await shot("story_offer.png")
	# отложить: снова через сутки
	sto.postpone()
	check((S["offer"] as Dictionary).is_empty() and int(S["later"].get("cat", -1)) == int(S["h"]) + StoryDefs.LATER_H, "«Отложить» — снова через %d ч" % StoryDefs.LATER_H)
	await frames(2)
	check(not hud.badges.has("story"), "свиток убран")
	S["h"] = int(S["h"]) + StoryDefs.LATER_H - 1
	sto.tick()
	check((S["offer"] as Dictionary).is_empty(), "через 23 ч — ещё нет")
	S["h"] = int(S["h"]) + 1
	sto.tick()
	check(String(S["offer"].get("id", "")) == "cat", "через сутки — снова просит")
	# одна история за раз: пока предложена эта, другую не предлагают
	StoryDefs.extra = [{"id": "t_other", "title": "Проба", "icon": "scroll", "lvl": 0, "pop": 0, "cast": {}, "who": "", "role": "",
		"steps": [{"id": "a", "cine": []}, {"id": "b", "goal": ["wait", 1]}]}]
	sto.tick()
	check(String(S["offer"].get("id", "")) == "cat", "одна история за раз")
	StoryDefs.extra = []
	# ролик просьбы: облачко с портретом, выбор
	hud.set_speed(2.0)
	var pose0: Array = game.rig.pose()
	hud._badge_click("story")            # как щелчок по свитку над домом
	check(sto.kit != null and sto.busy(), "щелчок по свитку — ролик")
	check(not game.rank_cine.calm(), "пока идёт ролик истории, rank_cine.calm() — false")
	var said: bool = await wait_beat("say", 6.0)
	check(said, "реплика мальчика")
	await frames(70)
	sto.ui.finish_typing()
	await frames(10)
	check(sto.ui.panel != null and sto.ui.panel.modulate.a > 0.9 and sto.ui.name_lbl.text.begins_with(StoryDefs.boy(kid_fam)), "облачко: «%s», %s" % [sto.ui.name_lbl.text, sto.ui.role_lbl.text])
	check(sto.ui.face_tex.texture is ViewportTexture, "портрет — живая голова (SubViewport)")
	await shot("story_ask.png")
	# дальше до выбора
	var t0 := Time.get_ticks_msec()
	while not sto.ui.choosing() and Time.get_ticks_msec() - t0 < 15000:
		sto.ui.finish_typing()
		await frames(3)
		sto._next()
		await frames(10)
	check(sto.ui.choosing() and sto.ui.pills.get_child_count() == 2, "выбор: «Найдём её вместе!» / «Чуть позже, малыш»")
	await frames(30)
	await shot("story_choice.png")
	(sto.ui.pills.get_child(0) as Button).pressed.emit()
	await frames(5)
	check(String(sto.cine.get("choice", "")) == "go" and sto.ui.text_lbl.text.begins_with("Ура!"), "выбрали помочь — мальчик отвечает")
	await play_through(10.0)
	var ended: bool = await wait_kit(false, 4.0)
	check(ended, "ролик кончился")
	await frames(4)
	check(not game.rig.cine and hud.visible and is_equal_approx(hud.root.modulate.a, 1.0), "камера и интерфейс — снова у игрока")
	check(is_equal_approx(float(game.speed), 2.0), "скорость вернулась (×%s)" % game.speed)
	var p: Array = game.rig.pose()
	check(game.rig.cam.global_position.distance_to(p[0]) < 0.6 and (p[0] as Vector3).distance_to(pose0[0]) < 0.3, "камера там же, где была")
	check(String(S["active"].get("id", "")) == "cat" and int(S["active"].get("step", -1)) == 1 and (S["offer"] as Dictionary).is_empty(), "история идёт: шаг «найти»")
	hud.set_speed(0.0)


# ---------- поиски: место, теснее, след лапки, щелчок, ролик встречи, награда ----------

func _search_and_find() -> void:
	print("== поиски")
	var S := c.stories
	var A: Dictionary = S["active"]
	check(not sto.cat.is_empty() and sto.cat.has("story"), "кошка истории спряталась")
	var door: Vector2 = c.door_point(kid_home)
	var sp: Vector2 = sto.cat["p"]
	var dd := sp.distance_to(door)
	check(dd >= 11.5 and dd <= 41.0, "кошка в %.1f м от двери (12–40)" % dd)
	check(game.people._path(door, sp).size() >= 2, "до неё можно дойти")
	var a0: Array = A["area0"]
	var a1: Array = A["area1"]
	check(is_equal_approx(float(a0[2]), 22.0) and Vector2(float(a0[0]), float(a0[1])).distance_to(sp) <= 22.0 * 0.55, "место поисков 22 м, кошка внутри, не в середине")
	check(is_equal_approx(float(a1[2]), 12.0) and Vector2(float(a1[0]), float(a1[1])).distance_to(sp) <= 12.0 * 0.55, "через 3 ч — 12 м, кошка внутри")
	await frames(20)
	check(sto._glow != null and is_equal_approx(sto._glow.size.x, 44.0), "пятно света на земле (22 м)")
	check(sto._paws.size() >= 2, "следы лапок от дома (%d)" % sto._paws.size())
	check(not hud.badges.has("story_paw"), "следа над кошкой пока нет")
	# мяу: звук в мире и подпись
	sto.meow()
	check(sto.cat["state"] == "sit", "мяукнула — села")
	# снимок: место поисков сверху (между домом мальчика и пятном — видны и следы лапок)
	var ac := (Vector2(float(a0[0]), float(a0[1])) + door) * 0.5
	game.rig.set_view(Vector3(ac.x, Land.BASE_Y, ac.y), 200.0, 55.0, 62.0)
	await frames(40)
	await shot("story_search.png")
	# 3 часа — теснее; 6 — след лапки над кошкой
	S["h"] = int(A["t0"]) + 3
	sto.tick()
	await frames(5)
	check(sto._glow != null and is_equal_approx(sto._glow.size.x, 24.0), "через 3 ч пятно теснее (12 м)")
	check(String(sto.row_info().get("text", "")).contains("тёплые уголки"), "подсказка в строке: «%s»" % sto.row_info().get("text"))
	S["h"] = int(A["t0"]) + 6
	sto.tick()
	await frames(5)
	check(hud.badges.has("story_paw"), "через 6 ч — след лапки над кошкой")
	var ac1 := Vector2(float(a1[0]), float(a1[1]))
	game.rig.set_view(Vector3(ac1.x, Land.BASE_Y, ac1.y), 200.0, 50.0, 40.0)
	await frames(40)
	await shot("story_search_6h.png")
	# щелчок: мимо (40 точек) — нет; рядом (20 точек) — нашли
	var cam: Camera3D = game.rig.cam
	var cp: Vector2 = cam.unproject_position(sto._cat_pos() + Vector3(0, 0.18, 0))
	check(not sto.try_click(cp + Vector2(40, 0)), "щелчок в 40 точках от кошки — мимо")
	check((S["done"] as Dictionary).is_empty(), "ещё не нашли")
	var rp0 := c.rp
	var happy0 := int(kid_home["happy"])
	game._mouse_pos = cp + Vector2(20, 8)
	game._click()                        # щелчок по миру без инструмента (game._click → stories.try_click)
	check((S["done"] as Dictionary).has("cat"), "щелчок в 22 точках — кошка найдена")
	check(sto.kit != null, "ролик встречи")
	check((S["done"] as Dictionary).has("cat") and (S["active"] as Dictionary).is_empty(), "история пройдена сразу (действие — до ролика)")
	check(c.research.has("s_cat") and c.unlocked("catbasket"), "украшение «Кошачья корзинка» открыто")
	check(is_equal_approx(c.rp, minf(c.rp_cap(), rp0 + 20.0)) or c.rp >= rp0 + 19.9, "+20 очков исследований (%.0f → %.0f)" % [rp0, c.rp])
	var line := ""
	for e: Array in kid_home["happy_parts"]:
		if String(e[0]).begins_with("Мурка снова дома"):
			line = "%s %+d" % [e[0], e[1]]
	check(line.contains("+8") and line.contains("ещё 3"), "строка счастья дома: «%s»" % line)
	check(int(kid_home["happy"]) == happy0 + 8 or int(kid_home["happy"]) >= 100, "счастье дома +8 (%d → %d)" % [happy0, int(kid_home["happy"])])
	var crow := false
	for e: Array in c.stats["happy_parts"]:
		if String(e[0]) == "Истории горожан" and int(e[1]) > 0:
			crow = true
	check(crow, "в счастье города — строка «Истории горожан»")
	check((S["pets"] as Array).size() == 1, "кошка-награда записана")
	check(String(S["done"]["cat"].get("text", "")).contains("Кошачья корзинка"), "в журнале — награда: %s" % S["done"]["cat"].get("text"))
	await play_through(30.0, "fx", "story_found.png", "say", "story_found_cat.png")
	var ended: bool = await wait_kit(false, 4.0)
	check(ended, "ролик встречи кончился")
	await frames(4)
	var named := 0
	for cc in game.people.cats:
		if cc.has("named") and not cc.has("story"):
			named += 1
	check(named == 1 and sto.cat.is_empty(), "Мурка теперь живёт у Корнелиев (кошек-наград: %d)" % named)
	check(not hud.badges.has("story_paw") and sto._glow == null, "значки и пятно убраны")
	check(int(S["last_h"]) >= 0 and int(S["h"]) - int(S["last_h"]) <= 1, "часы до следующей истории пошли (last_h=%d, h=%d)" % [int(S["last_h"]), int(S["h"])])
	# корзинка в мире: с кошкой внутри
	var bk := deco("catbasket", Vector2(166, 132))
	await frames(5)
	var vis: Dictionary = game.visuals.get(bk.get("id", -1), {})
	check(not bk.is_empty() and (vis.get("pets", []) as Array).size() == 1, "«Кошачья корзинка» поставлена, в ней спит кошка")
	var bp: Vector2 = bk.get("pos", Vector2.ZERO)
	game.rig.set_view(Vector3(bp.x, Land.BASE_Y, bp.y), 160.0, 28.0, 4.5)
	await frames(40)
	await shot("story_basket.png")
	# бонус тает: через 72 ч строки нет
	for i in 72:
		c._story_hour()
	c.compute()
	var still := false
	for e: Array in kid_home["happy_parts"]:
		if String(e[0]).begins_with("Мурка"):
			still = true
	check(not still and (S["bonus"] as Array).is_empty(), "через 3 дня бонус дома кончился")


func _journal() -> void:
	print("== журнал")
	hud.refresh()
	await frames(3)
	sto.ui.open_journal()
	await frames(30)
	check(hud.journal_panel != null and hud.journal_panel.visible, "журнал открыт")
	var txt := ""
	for l: Label in hud.journal_panel.find_children("*", "Label", true, false):
		txt += l.text + " | "
	check(txt.contains("Где Мурка?") and txt.contains("Кошачья корзинка"), "в журнале — история и награда")
	await shot("story_journal.png")
	var btn: Button = null
	for b: Button in hud.journal_panel.find_children("*", "Button", true, false):
		if b.text == "Пересмотреть":
			btn = b
	check(btn != null, "кнопка «Пересмотреть»")
	if btn != null:
		btn.pressed.emit()
		check(sto.kit != null and not hud.journal_panel.visible, "пересмотр: ролик, журнал закрыт")
		await wait_beat("say", 6.0)
		await frames(30)
		press_key(KEY_ESCAPE)
		var ended: bool = await wait_kit(false, 4.0)
		check(ended and (c.stories["done"] as Dictionary).has("cat"), "Esc — пересмотр кончился, история на месте")


# ---------- пропуск ролика: действие всё равно случилось ----------

func _skip_applies() -> void:
	print("== пропуск")
	who_kid("пропуск")
	fresh(200)
	var S := c.stories
	sto.tick()
	check(String(S["offer"].get("id", "")) == "cat", "предложение снова (после сброса)")
	sto.open_offer()
	await frames(40)
	press_key(KEY_ESCAPE)
	var ended: bool = await wait_kit(false, 4.0)
	check(ended and String(S["active"].get("id", "")) == "cat" and int(S["active"]["step"]) == 1, "Esc в ролике просьбы — согласились помочь (по умолчанию)")
	check(not sto.cat.is_empty(), "кошка спряталась")
	sto.found()
	check(sto.kit != null, "нашли — ролик встречи")
	await frames(40)
	press_key(KEY_ESCAPE)
	ended = await wait_kit(false, 4.0)
	check(ended and (S["done"] as Dictionary).has("cat") and c.research.has("s_cat") and (S["bonus"] as Array).size() == 1, "Esc в ролике встречи — награда всё равно есть")
	await frames(4)
	check(not game.rig.cine and hud.visible, "после пропуска всё вернулось")


# ---------- сам нашёл: 12 ч — без очков ----------

func _give_up() -> void:
	print("== сам нашёл")
	who_kid("сам нашёл")
	fresh(300)
	var S := c.stories
	sto.tick()
	sto.accept()
	var A: Dictionary = S["active"]
	check(int(A.get("step", -1)) == 1, "история идёт")
	var rp0 := c.rp
	var ev0: int = c.events.size()
	S["h"] = int(A["t0"]) + 11
	sto.tick()
	check((S["done"] as Dictionary).is_empty(), "11 ч — ещё ищем")
	S["h"] = int(A["t0"]) + 12
	sto.tick()
	check(String(S["done"].get("cat", {}).get("how", "")) == "self", "12 ч — мальчик нашёл сам")
	check(is_equal_approx(c.rp, rp0), "без очков исследований")
	check(c.research.has("s_cat") and (S["bonus"] as Array).size() == 1, "корзинка и счастье дома — есть")
	check(c.events.size() == ev0 + 1 and String(c.events[-1]["text"]).contains("сам нашёл"), "колокольчик: «%s»" % c.events[-1]["text"])
	check(sto.kit == null, "ролик сам не начался (без всплывашек)")


# ---------- сохранение посреди шага ----------

func _save_mid_step() -> void:
	print("== сохранение посреди шага")
	who_kid("сохранение посреди шага")
	fresh(400)
	var S := c.stories
	sto.tick()
	sto.accept()
	S["h"] = int(S["active"]["t0"]) + 4
	var spot: Array = S["active"]["spot"]
	var d: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	var c2 := City.new(game.land)
	c2.load_data(d)
	var A2: Dictionary = c2.stories["active"]
	check(String(A2.get("id", "")) == "cat" and int(A2.get("step", -1)) == 1 and int(c2.stories["h"]) == int(S["h"]), "после загрузки: та же история, тот же шаг, те же часы")
	check(Vector2(float(A2["spot"][0]), float(A2["spot"][1])).distance_to(Vector2(float(spot[0]), float(spot[1]))) < 0.01, "кошка — там же")
	# «перезапуск»: состояние из сохранения, кошка заново
	game.people.drop_cat(sto.cat)
	sto.cat = {}
	c.stories = City.stories_load(d["stories"])
	sto._restore()
	check(not sto.cat.is_empty() and (sto.cat["p"] as Vector2).distance_to(Vector2(float(spot[0]), float(spot[1]))) < 0.01, "кошка снова спряталась там же")
	sto._h_seen = -1
	sto.tick()
	await frames(5)
	check(sto._glow != null and is_equal_approx(sto._glow.size.x, 24.0), "место поисков — по часам (4 ч — 12 м)")
	sto.found()
	await frames(20)
	press_key(KEY_ESCAPE)
	await wait_kit(false, 4.0)
	check((c.stories["done"] as Dictionary).has("cat"), "после загрузки историю можно пройти")
	# старое сохранение без историй
	d.erase("stories")
	var c3 := City.new(game.land)
	c3.load_data(d)
	check(int(c3.stories["h"]) == 0 and (c3.stories["active"] as Dictionary).is_empty() and (c3.stories["done"] as Dictionary).is_empty(), "старое сохранение: историй нет, часы с нуля")


# ---------- дом снесли ----------

## Семья Корнелиев с площади — в дом h (сразу, без прогулки)
func rehouse(h: Dictionary) -> bool:
	if h.is_empty() or not c.assign(kid_fam, int(h["id"])):
		return false
	c.settled(int(h["id"]), 4, kid_fam)
	return true


func _demolished() -> void:
	print("== дом снесли")
	who_kid("дом снесли")
	var S := c.stories
	# предложение: дом снесли — предложения нет
	fresh(500)
	S = c.stories
	sto.tick()
	check(String(S["offer"].get("id", "")) == "cat", "предложение")
	var spare := put("house_pleb", Vector2(200, 150))
	c.remove(kid_home)
	await frames(3)
	check((S["offer"] as Dictionary).is_empty() and int(S["later"].get("cat", -1)) == int(S["h"]) + StoryDefs.FIRST_H, "дом снесли — предложение убрано (другому — не сразу)")
	var fam_back := false
	for f in c.arrivals:
		if f["name"] == kid_fam:
			fam_back = true
	check(fam_back, "семья Корнелиев ждёт на площади")
	# семья в новом доме — снова просит
	kid_home = put("house_pleb", Vector2(172, 124))
	check(rehouse(kid_home), "семья заселилась в новый дом")
	check(not game.people.child_of(kid_fam, int(kid_home["id"])).is_empty(), "сын с ними")
	S["last_h"] = -1
	S["later"] = {}
	sto._h_seen = -1
	sto.tick()
	check(String(S["offer"].get("fam", "")) == kid_fam and int(S["offer"].get("home", -1)) == int(kid_home["id"]), "предложение снова")
	sto.accept()
	var ev0: int = c.events.size()
	# идёт история — дом снесли: ждём; семья заселилась в другой дом — история идёт дальше
	c.remove(kid_home)
	await frames(2)
	sto.tick()
	check(String(S["active"].get("id", "")) == "cat" and S["active"].has("homeless"), "дом снесли — история ждёт семью")
	check(c.events.size() == ev0 + 1 and String(c.events[-1]["text"]).contains("ждёт"), "колокольчик: «%s»" % c.events[-1]["text"])
	check(String(sto.row_info().get("text", "")).contains("без дома"), "строка: «%s»" % sto.row_info().get("text"))
	check(rehouse(spare), "семья заселилась в другой дом")
	sto.tick()
	check(int(S["active"].get("home", -1)) == int(spare.get("id", -2)) and not S["active"].has("homeless"), "история идёт с семьёй (дом %s)" % S["active"].get("home"))
	# снова снесли и не заселили сутки — история прервалась
	c.remove(spare)
	await frames(2)
	sto.tick()
	check(S["active"].has("homeless"), "снова без дома")
	ev0 = c.events.size()
	S["h"] = int(S["active"].get("homeless", S["h"])) + Stories.WAIT_HOME_H
	sto.tick()
	check((S["active"] as Dictionary).is_empty() and sto.cat.is_empty(), "сутки без дома — история прервалась, кошки нет")
	check(c.events.size() == ev0 + 1 and String(c.events[-1]["text"]).contains("прервалась"), "колокольчик: «%s»" % c.events[-1]["text"])
	check(int(S["last_h"]) == int(S["h"]) and not (S["done"] as Dictionary).has("cat"), "часы до следующей пошли, история не пройдена (её предложат снова)")
	# семья уехала из города — прервалась сразу
	kid_home = put("house_pleb", Vector2(172, 124))
	check(rehouse(kid_home), "семья снова в доме")
	S["last_h"] = -1
	S["h"] = int(S["h"]) + 100
	sto._h_seen = -1
	sto.tick()
	sto.accept()
	check(String(S["active"].get("id", "")) == "cat", "ещё раз")
	c.family_left.emit(int(kid_home["id"]), kid_fam)
	check((S["active"] as Dictionary).is_empty() and String(c.events[-1]["text"]).contains("уехала"), "семья уехала — история прервалась: «%s»" % c.events[-1]["text"])


# ---------- виды целей (для «Скверика» и «Свадьбы»): рядом, построен после, очки, выбор, плата, ожидание ----------

func _goal_kinds() -> void:
	print("== виды целей")
	var S := c.stories
	var hp: Vector2 = kid_home["pos"]
	var a := {"id": "cat", "home": int(kid_home["id"]), "fam": kid_fam, "flags": {}, "t0": int(S["h"]), "id0": c.next_id}
	var g_around := ["around", 15.0, {"bench": 2, "tree": 1}]
	var pr: Dictionary = sto.progress(a, g_around)
	check(not bool(pr["ok"]), "рядом: пока нет (%s)" % pr["txt"])
	for i in 2:
		deco("bench", hp + Vector2(6 + i * 2.5, -6))
	deco("tree", hp + Vector2(-6, -6))
	pr = sto.progress(a, g_around)
	check(bool(pr["ok"]) and int(pr["have"]) == 3, "рядом: две скамьи и дерево в 15 м (%s)" % pr["txt"])
	var g_after := ["built_after", "house_pleb", 30.0]
	pr = sto.progress(a, g_after)
	check(not bool(pr["ok"]), "построен после: старые дома не в счёт")
	var nb := put("house_pleb", hp + Vector2(0, 12))
	pr = sto.progress(a, g_after)
	check(not nb.is_empty() and bool(pr["ok"]), "построен после: новый дом в 30 м")
	var g_score := ["score", "bench", 15.0, [2, 4, 6]]
	pr = sto.progress(a, g_score)
	check(int(pr["tier"]) == 1 and not bool(pr["ok"]), "очки: 2 скамьи — бронза, ждём «Готово» (%s)" % pr["txt"])
	a["flags"]["ready"] = true
	pr = sto.progress(a, g_score)
	check(bool(pr["ok"]), "очки: «Готово» нажато")
	var g_choice := ["choice", [["Сад", "garden"], ["Таверна", "tavern"]]]
	check(not bool(sto.progress(a, g_choice)["ok"]), "выбор: ещё не выбрали")
	a["flags"]["choice"] = "garden"
	check(bool(sto.progress(a, g_choice)["ok"]), "выбор сделан")
	var g_flag := ["flag", "choice", {"garden": ["around", 15.0, {"tree": 1}], "tavern": ["around", 25.0, {"taberna": 1}]}]
	check(bool(sto.progress(a, g_flag)["ok"]), "цель по выбору (сад): дерево рядом")
	a["flags"]["choice"] = "tavern"
	check(not bool(sto.progress(a, g_flag)["ok"]), "цель по выбору (таверна): таверны нет")
	var g_wait := ["wait", 3]
	check(not bool(sto.progress(a, g_wait)["ok"]), "ожидание: только начали")
	S["h"] = int(S["h"]) + 3
	check(bool(sto.progress(a, g_wait)["ok"]), "ожидание: 3 ч прошло")
	var g_p := ["p", ["kind", "house"], 3]
	check(bool(sto.progress(a, g_p)["ok"]), "как у просьб: домов ≥ 3")
	# плата из золотой строки — через историю-пробу
	StoryDefs.extra = [{"id": "t_pay", "title": "Проба платы", "icon": "coins", "lvl": 0, "pop": 0, "cast": {}, "who": "", "role": "",
		"steps": [{"id": "a", "cine": []}, {"id": "b", "text": "Заплатите", "goal": ["pay", "money", 400]}, {"id": "c", "goal": ["wait", 1]}],
		"reward": {"happy_all": [2, 24]}, "line": "Проба"}]
	fresh(900)
	S = c.stories
	S["offer"] = {}
	S["done"]["cat"] = {"day": 0, "h": 1}
	sto._tried = ""
	sto.tick()
	check(String(S["offer"].get("id", "")) == "t_pay", "проба: предложена история без жителя (у станции)")
	sto.accept()
	var m0 := c.money
	var info: Dictionary = sto.row_info()
	check(String((info["buttons"] as Array)[0][0]).begins_with("Заплатить 400"), "кнопка «%s»" % (info["buttons"] as Array)[0][0])
	((info["buttons"] as Array)[0][1] as Callable).call()
	check(is_equal_approx(c.money, m0 - 400.0) and int(S["active"].get("step", -1)) == 2, "заплатили 400 ден. — следующий шаг")
	S["h"] = int(S["h"]) + 1
	sto.tick()
	check((S["done"] as Dictionary).has("t_pay"), "ожидание кончилось — история пройдена")
	c.compute()
	var all_line := false
	for e: Array in kid_home.get("happy_parts", []):
		if String(e[0]).begins_with("Проба"):
			all_line = true
	check(all_line, "награда «всем домам» — строка в счастье дома")


# ---------- город владельца: старое сохранение ----------

func _owner() -> void:
	var S := c.stories
	check(int(S["h"]) == 0 and (S["active"] as Dictionary).is_empty() and (S["offer"] as Dictionary).is_empty() and (S["done"] as Dictionary).is_empty(),
		"сохранение владельца: историй нет, часы с нуля")
	print("owner: level=", c.level, " pop=", c.stats["pop"], " tut=", c.tips.get("tut"), " ui=", hud.ui_level())
	hud.advisor_panel.visible = false
	game._set_hour(10.5)
	hud.set_speed(1.0)
	for i in StoryDefs.FIRST_H - 1:
		c._story_hour()
	sto.tick()
	check((S["offer"] as Dictionary).is_empty(), "3 ч — ещё рано")
	c._story_hour()
	sto.tick()
	var o: Dictionary = S["offer"]
	check(String(o.get("id", "")) == "cat", "4 ч — «Где Мурка?» (%s)" % o)
	if o.is_empty():
		return
	var h: Dictionary = c.buildings[int(o["home"])]
	print("owner: просит ", o["kid"], " из семьи ", o["fam"], " дом ", o["home"], " at ", h["pos"])
	hud.advisor_panel.visible = false
	await frames(30)
	sto.open_offer()
	await wait_beat("say", 6.0)
	await frames(80)
	sto.ui.finish_typing()
	await frames(10)
	await shot("story_owner_ask.png")
	await play_through(20.0)
	await wait_kit(false, 4.0)
	var A: Dictionary = S["active"]
	check(int(A.get("step", -1)) == 1 and not sto.cat.is_empty(), "история идёт, кошка спряталась")
	if sto.cat.is_empty():
		return
	var sp: Vector2 = sto.cat["p"]
	print("owner: кошка в %.1f м от двери, у %s" % [sp.distance_to(c.door_point(h)), sp])
	var a0: Array = A["area0"]
	game.rig.set_view(Vector3(float(a0[0]), Land.BASE_Y, float(a0[1])), 200.0, 55.0, 62.0)
	await frames(40)
	await shot("story_owner_search.png")
	sto.found()
	await play_through(30.0, "fx", "story_owner_found.png")
	await wait_kit(false, 4.0)
	check((S["done"] as Dictionary).has("cat"), "в городе владельца история проходится")
