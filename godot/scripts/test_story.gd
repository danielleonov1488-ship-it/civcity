extends Node
## Проверка «Историй горожан» (scripts/stories.gd) и первой истории «Где Мася?» (Д15: чёрная Мася, ищет девушка Мария):
## часы историй идут после обучения, первая — через FIRST_H, между историями — GAP_H; ранг; предложение и «Отложить»;
## одна история за раз; ролик просьбы (облачко с портретом, выбор), rank_cine.calm() — false в ролике; место поисков
## теснее через 3 ч, след лапки через 6 ч; щелчок по кошке (34 точки); ролик встречи; награда (украшение, строка счастья
## дома, очки, кошка); пропуск ролика — действие всё равно случилось; сам нашёл (12 ч) — без очков; сохранение посреди шага;
## дом снесли (ждём семью, она заселилась — история идёт; не заселилась — прервалась); виды целей других историй.
## Снимки — .work/gd/story_*.png. Итог: «STORY DONE fails=N».
## «Скверик для стариков»: ранг и исследования, старик просит (седой, лицо для крупного плана), советник, пороги по скамьям
## (бронза / серебро / золото с часами), старики приходят — скамей больше, стариков больше; сохранение посреди шага; «Готово» —
## ролик и «памятник» +7% в 15 м (строки счастья рядом, у дальних нет); стол для латрункулов — утром двое играют; вечером уходят.
## «Свадьба Юлии»: ранг, ремесленники, жених из другого дома; таверна в выборе — только если её можно построить; сад —
## арка из роз сразу; ветка таверны; дом невесты перенесли; новый дом: плебейский и занятый не в счёт; молодые — семья в новом
## доме; ролик: вечер, шествие, жаровни; +6% в 20 м на 3 дня; «Пересмотреть»; сохранение посреди шага.
## Правки по проверке: «Отложить» — пауза для всех историй (скверик сутки не просят); «Бронза — 3 скамьи»; столов
## латрункулов с игроками — не больше StoryLife.TABLES; «Пересмотреть» скверик — дед взрослый (и по старой записи);
## «памятник» скверика — пока скверик стоит (убрали часы — серебро, колодец — бонуса нет); дом деда снесли — стариков нет;
## свадьба: дом, построенный сразу после выбора (до пира), — в счёт; свадьба готова, дом невесты снесли, семья уехала —
## награда есть; семья без дома — ни пир, ни новый дом не меряем от станции; дом самой семьи молодым — не в счёт.
## mode=owner — город владельца (копия сохранения в CIVCITY_SAVEDIR): загрузка без историй, предложение, кошка находится,
## потом — течь (лужи, мастер), скверик, ослик в его городе, заказ старосты ждёт. mode=faces — лица в ролике до и после правки.
## Этап 7 (учебные истории): каркас — новые цели (красота, игры, победы Легиона, «всё сразу»), шаг с исследованием и стрелкой
## на «Этаж», строки с ✓ и стрелка к невыполненной, такт «если» помнит прошлые истории; «Течь в водопроводе» — лужи вдоль улицы,
## значки через 4 ч, сохранение посреди шага, мастер идёт к трубе, фонтан у 6 домов и «Обзор → Вода», «Фонтан с нимфой»;
## «Ослик возчика» — ослик прячется и находится, лавка без склада («нет склада рядом», стрелка к складу), ослик везёт товар,
## коновязь с осликом; «Тесно у Валериев» — строки счастья и этажа, «не хватает: …», красота дома у курсора, третий этаж,
## выбор про деда (награда по выбору, журнал), балкон только на дом в 2–3 этажа; «Заказы старосты» — с «Хутора», сами не
## открываются (30 ч — камера на месте), точка на свёрнутом свитке, в счёт — после «Взяться», награда без денег, редкий облик,
## второй круг вдвое, «Другой заказ», заменить деревянные скамьи.
## Д9 «Разбойники у арки»: первой остаётся «Мася», в обучении — нет; медальон «Легион» серый с подсказкой; ролик у арки
## с телегой; шаг открывает «Легион» без очков, военный квартал подсвечен (в квартале ✓ / можно и здесь), одна стрелка;
## Казармы; «В бой!» из строки — учебный бой; награда без денег — «Сторожевой пост»; старый город с Легионом — без истории.
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
		if kv[0] == "out" and kv.size() > 1:
			out = kv[1].trim_suffix("/") + "/"   # куда снимки (проверка под OpenGL — в свою папку)
	if mode == "owner_old":
		_old_cat_save()
	Game.boot = {"play": "1"} if mode in ["owner", "owner_old"] else {"new": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


## Часы роликов. Ролик за кадр продвигается не больше чем на 0,05 с (Stories._process и RankCine — minf(dt, 0.05):
## рывок не проматывает ролик). Под нагрузкой (4 кадра/с — несколько проверок на одной видеокарте) ролик идёт в
## 4–5 раз медленнее настенных часов: Esc возвращает камеру за 0,9 с ролика — это 18 кадров, 4,5 с настоящих. Сроки
## ожидания роликов поэтому — по этим часам (при 20+ кадрах/с они совпадают с настоящими)
var cine_t := 0.0


func _process(dt: float) -> void:
	cine_t += minf(dt, 0.05)


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


## Семья в дом (как после загрузки): жители; kid — третья взрослая дочь (Мария из «Где Мася?»)
func settle(h: Dictionary, nm: String, kid := false) -> void:
	var n := c.house_cap(h)
	c.settled(int(h["id"]), n, nm)
	var fam: Array = game.people._make_family(nm, n, int(h["id"]), c.door_point(h))
	if kid and fam.size() >= 3:
		fam[2]["child"] = false
		fam[2]["female"] = true


## Взрослая жительница семьи fam в доме home (Мария) — или {}
func woman_of(fam: String, home: int) -> Dictionary:
	for r in game.people.residents:
		if r["fam"] == fam and int(r["home"]) == home and bool(r["female"]) and not bool(r["child"]):
			return r
	return {}


## Кто у Корнелиев (отладка)
func who_kid(tag: String) -> void:
	var rs := []
	for r in game.people.residents:
		if r["fam"] == kid_fam:
			rs.append("%d:%s:%s" % [int(r["home"]), "реб" if r["child"] else "взр", r["state"]])
	print("  [%s] Корнелии: %s; дом %s; семьи в доме: %s; предложение: %s" % [tag, rs, kid_home.get("id"), kid_home.get("families"), c.stories["offer"]])


## Состояние историй с нуля (а город, дома, жители — те же); done — эти истории уже пройдены
func fresh(h := 100, done := []) -> void:
	if not sto.cat.is_empty():
		game.people.drop_cat(sto.cat)
		sto.cat = {}
	for cc in game.people.cats.duplicate():
		if cc.has("named") or cc.has("story"):
			game.people.drop_cat(cc)
	c.stories = City.stories_new()
	c.stories["h"] = h
	for id in done:
		c.stories["done"][id] = {"day": 0, "h": 1}
	c.research.erase("s_cat")
	sto._h_seen = -1
	sto._tried = ""
	sto.tick()


## Ждать, пока ролик начнётся / кончится (sec — по часам роликов)
func wait_kit(on: bool, sec: float) -> bool:
	var t0 := cine_t
	while (sto.kit != null) != on and cine_t - t0 < sec:
		await get_tree().process_frame
	return (sto.kit != null) == on


## Ждать такт ролика вида kind (say, choice…), не дольше sec (по часам роликов)
func wait_beat(kind: String, sec: float) -> bool:
	var t0 := cine_t
	while cine_t - t0 < sec:
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
	var t0 := cine_t
	var shot_done := false
	var shot2_done := false
	while sto.kit != null and cine_t - t0 < sec:
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
	game.settings["tasks_folded"] = false   # gpu_run копирует saves/settings.json: свиток просьб — развёрнут
	sto.force = true
	game.rank_cine.force = false
	if mode == "owner":
		await _owner()
		print("STORY DONE fails=", fails)
		get_tree().quit()
		return
	if mode == "owner_old":
		await _owner_old()
		print("STORY DONE fails=", fails)
		get_tree().quit()
		return
	await _new_game_no_legion()
	if game.tutorial.active():
		game.tutorial.step = Tutorial.STEPS.size()
		game.tutorial.card.visible = false
	c.tips["tut"] = -1
	c.tips["ui"] = 3
	hud.apply_reveal(3)
	hud.advisor_panel.visible = false
	for t in ["rank_tip", "fest_tip", "floor_tool", "full_money", "full_rp", "name_tip", "v22_pace", "orders_tip", "tax_tip", "dim_tip", "floor_money"]:
		c.tips[t] = true                 # чужие советы не мешают проверить совет историй
	# Легион уже открыт (как в старом городе): «Разбойники у арки» не встают между прежними историями — их проверяет _bandits
	c.research["legion"] = true
	c.legion.flags["tut"] = "done"
	game._set_hour(10.5)
	hud.set_speed(0.0)                   # часы игры стоят (часы историй двигает проверка); ролик сам ставит ×1
	c.money = 5000.0
	c.tips["set_tip"] = true                # совет о наборах украшений (этап 5) — не в этой проверке
	for r in ["q_garden", "q_market", "deco_trees", "deco_flowers", "deco_south"]:   # «Южные деревья» — кипарис и пальма в новой игре (этап 5)
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
	if mode == "faces":
		await _faces()
		print("STORY DONE fails=", fails)
		get_tree().quit()
		return
	if mode == "stage7":
		# только этап 7: каркас, течь, ослик, тесно, заказы (быстрее, чем весь набор)
		_block()
		for f: Callable in [_framework, _leak, _donkey, _crowded, _orders, _bandits]:
			c.money = 50000.0
			await f.call()
		StoryDefs.extra = []
		print("STORY DONE fails=", fails)
		get_tree().quit()
		return
	await _timing()
	await _offer_flow()
	await _search_and_find()
	await _journal()
	await _migrate_old()
	await _skip_applies()
	await _give_up()
	await _save_mid_step()
	await _demolished()
	await _goal_kinds()
	c.money = 50000.0
	await _square()
	c.money = 50000.0
	await _wedding()
	c.money = 50000.0
	await _wedding_more()
	c.money = 50000.0
	await _framework()
	c.money = 50000.0
	await _leak()
	c.money = 50000.0
	await _donkey()
	c.money = 50000.0
	await _crowded()
	c.money = 50000.0
	await _orders()
	c.money = 50000.0
	await _bandits()
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
	check(sto.time_ok() and (S["offer"] as Dictionary).is_empty(), "4 ч, но ранг 0 (лачуги) — «Где Мася?» не предлагают")
	c.level = 1
	var bell0: int = hud.bell_count
	var notes0: int = hud.notes_box.get_child_count()
	sto.tick()
	check(String(S["offer"].get("id", "")) == "cat", "ранг «Хутор» — предложение «Где Мася?» (%s)" % S["offer"])
	check(int(S["offer"].get("home", -1)) == int(kid_home["id"]) and String(S["offer"].get("fam", "")) == kid_fam and String(S["offer"].get("kid", "")) == "Мария"
		and bool(S["offer"].get("female", false)) and not bool(S["offer"].get("child", true)), "просит Мария из семьи Корнелиев (девушка, не ребёнок): %s" % S["offer"])
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
	check(String(info.get("title", "")) == "Где Мася?" and (info.get("buttons", []) as Array).size() == 2, "золотая строка: «%s» — %s" % [info.get("title"), info.get("text")])
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
	var said: bool = await wait_beat("say", 12.0)     # первый ролик игры: под нагрузкой (картинки построек) — дольше
	check(said, "реплика Марии")
	await frames(70)
	sto.ui.finish_typing()
	await frames(10)
	check(sto.ui.panel != null and sto.ui.panel.modulate.a > 0.9 and sto.ui.name_lbl.text == "Мария" and sto.ui.role_lbl.text == "дочь семьи Корнелиев",
		"облачко: «%s», %s" % [sto.ui.name_lbl.text, sto.ui.role_lbl.text])
	var ro: Dictionary = sto._role(sto.cine["bind"], "maria")
	var act = sto.cine.get("actors", {}).get("maria")
	check(bool(ro.get("female", false)) and not bool(ro.get("child", true)) and act is Citizen and (act as Citizen).scale.y > Citizen.SIZE * 0.9,
		"в ролике и на портрете — девушка, не ребёнок (%s)" % ro)
	check(String(sto.ui.text_lbl.text).contains("Мася") and String(sto.ui.text_lbl.text).contains("Чёрная"), "Мария: «%s»" % sto.ui.text_lbl.text)
	check(sto.ui.face_tex.texture is ViewportTexture, "портрет — живая голова (SubViewport)")
	await shot("story_ask.png")
	# дальше до выбора
	var t0 := cine_t
	while not sto.ui.choosing() and cine_t - t0 < 15.0:
		sto.ui.finish_typing()
		await frames(3)
		sto._next()
		await frames(10)
	check(sto.ui.choosing() and sto.ui.pills.get_child_count() == 2, "выбор: «Найдём её вместе!» / «Чуть позже, Мария»")
	await frames(30)
	await shot("story_choice.png")
	(sto.ui.pills.get_child(0) as Button).pressed.emit()
	await frames(5)
	check(String(sto.cine.get("choice", "")) == "go" and sto.ui.text_lbl.text.begins_with("Спасибо тебе!"), "выбрали помочь — Мария отвечает: «%s»" % sto.ui.text_lbl.text)
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
	var fm: ShaderMaterial = sto.cat.get("mat")
	check(int(A.get("fur", -1)) == People.CAT_MASYA and String(A.get("cat_name", "")) == "Мася" and fm != null
		and (fm.get_shader_parameter("fur") as Color).get_luminance() < 0.15 and float(fm.get_shader_parameter("sheen")) > 0.0,
		"прячется чёрная Мася с отливом по краю (окрас %d, %s)" % [int(A.get("fur", -1)), A.get("cat_name", "")])
	var door: Vector2 = c.door_point(kid_home)
	var sp: Vector2 = sto.cat["p"]
	var dd := sp.distance_to(door)
	check(dd >= 11.5 and dd <= 41.0, "кошка в %.1f м от двери (12–40)" % dd)
	check(game.people._path(door, sp).size() >= 2, "до неё можно дойти")
	var s0: Array = A.get("spot0", [])
	check(s0.size() == 2 and Vector2(float(s0[0]), float(s0[1])).distance_to(sp) < 0.01, "кошка там, где проверяли при предложении (%s / %s)" % [s0, sp])
	var a0: Array = A["area0"]
	var a1: Array = A["area1"]
	check(is_equal_approx(float(a0[2]), 22.0) and Vector2(float(a0[0]), float(a0[1])).distance_to(sp) <= 22.0 * 0.55, "место поисков 22 м, кошка внутри, не в середине")
	check(is_equal_approx(float(a1[2]), 12.0) and Vector2(float(a1[0]), float(a1[1])).distance_to(sp) <= 12.0 * 0.55, "через 3 ч — 12 м, кошка внутри")
	await frames(20)
	check(sto._glow != null and is_equal_approx(sto._glow_r, 22.0), "пятно света на земле (22 м)")
	check(sto._paws.size() >= 2, "следы лапок от дома (%d)" % sto._paws.size())
	check(not hud.badges.has("story_paw"), "следа над кошкой пока нет")
	# мяу: звук в мире и подпись
	sto.meow()
	check(sto.cat["state"] == "sit", "мяукнула — села")
	# снимок: место поисков сверху (между домом Марии и пятном — видны и следы лапок)
	var ac := (Vector2(float(a0[0]), float(a0[1])) + door) * 0.5
	game.rig.set_view(Vector3(ac.x, Land.BASE_Y, ac.y), 200.0, 55.0, 62.0)
	await frames(40)
	await shot("story_search.png")
	# 3 часа — теснее; 6 — след лапки над кошкой
	S["h"] = int(A["t0"]) + 3
	sto.tick()
	await frames(5)
	check(sto._glow != null and is_equal_approx(sto._glow_r, 12.0), "через 3 ч пятно теснее (12 м)")
	check(String(sto.row_info().get("text", "")).contains("тёплые уголки"), "подсказка в строке: «%s»" % sto.row_info().get("text"))
	S["h"] = int(A["t0"]) + 6
	sto.tick()
	await frames(5)
	check(hud.badges.has("story_paw"), "через 6 ч — след лапки над кошкой")
	var ac1 := Vector2(float(a1[0]), float(a1[1]))
	game.rig.set_view(Vector3(ac1.x, Land.BASE_Y, ac1.y), 200.0, 50.0, 40.0)
	await frames(40)
	await shot("story_search_6h.png")
	# крупно: чёрная Мася спит в укрытии (отлив по краю), потом мяукнула и села — жёлтые глаза
	var cpos: Vector3 = sto._cat_pos()
	game.rig.set_view(Vector3(cpos.x, Land.BASE_Y, cpos.z), 200.0, 34.0, 6.5)
	await frames(40)
	await shot("story_masya_hidden.png")
	sto.meow()
	await frames(30)
	await shot("story_masya_meow.png")
	game.rig.set_view(Vector3(ac1.x, Land.BASE_Y, ac1.y), 200.0, 50.0, 40.0)
	await frames(10)
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
	check(is_equal_approx(c.rp, minf(c.rp_cap(), rp0 + 25.0)) or c.rp >= rp0 + 24.9, "+25 очков исследований (%.0f → %.0f)" % [rp0, c.rp])
	if rp0 + 25.0 <= c.rp_cap():
		check(String(S["done"]["cat"].get("text", "")).contains("+25 очков исследований"), "в награде — +25 очков")
	var line := ""
	for e: Array in kid_home["happy_parts"]:
		if String(e[0]).begins_with("Мася снова дома"):
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
	await play_through(60.0, "fx", "story_found.png", "say", "story_found_cat.png")   # с запасом: под нагрузкой ролик идёт дольше
	var ended: bool = await wait_kit(false, 8.0)
	check(ended, "ролик встречи кончился")
	await frames(4)
	var named := 0
	for cc in game.people.cats:
		if cc.has("named") and not cc.has("story"):
			named += 1
	check(named == 1 and sto.cat.is_empty(), "Мася теперь живёт у Корнелиев (кошек-наград: %d)" % named)
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
		if String(e[0]).begins_with("Мася"):
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
	check(txt.contains("Где Мася?") and txt.contains("Кошачья корзинка"), "в журнале — история и награда")
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


# ---------- Д15: старое сохранение с «Где Мурка?» ----------

## Строки колокольчика старого города с «Где Мурка?» (последняя — чужая, с тем же значком: её не трогаем)
const OLD_BELL := [
	{"day": 2, "icon": "cat", "text": "Маленький Луций из семьи Корнелиев чем-то расстроен — над их домом свиток с просьбой."},
	{"day": 3, "icon": "cat", "text": "Луций сам нашёл Мурку — она дремала в укромном уголке. Кошка снова дома."},
	{"day": 3, "icon": "cat", "text": "История «Где Мурка?» завершена. Луций сам нашёл Мурку — она дремала в укромном уголке. Кошка снова дома. Награда: украшение «Кошачья корзинка» (Украшения), дому Корнелиев +8% счастья на 3 дня, ещё одна кошка в городе."},
	{"day": 3, "icon": "decor", "text": "Открыто украшение «Кошачья корзинка» (Украшения) — для истории «Где Мурка?»."},
	{"day": 4, "icon": "cat", "text": "У дома семьи Юлиев теперь живёт кошка."}]

## Пройденная и идущая история «cat», кошка-награда и строка счастья из старого сохранения — с новыми именами
## (Мария, чёрная Мася), в журнале и «Пересмотреть» — тоже; второй раз загрузка ничего не меняет
func _migrate_old() -> void:
	print("== старое сохранение: «Где Мурка?» → «Где Мася?»")
	var hid := int(kid_home["id"])
	var old := {"h": 50, "last_h": 40,
		"done": {"cat": {"day": 3, "h": 40, "home": hid, "fam": kid_fam, "kid": "Луций", "seed": 7, "cls": "plebs", "how": "self",
			"cat_name": "Мурка", "fur": 0, "child": true, "female": false,
			"text": "Луций сам нашёл Мурку — она дремала в укромном уголке. Кошка снова дома. Награда: украшение «Кошачья корзинка» (Украшения), дому Корнелиев +8% счастья на 3 дня, ещё одна кошка в городе."}},
		"pets": [{"home": hid, "fur": 0, "name": "Мурка", "seed": 5}],
		"bonus": [{"id": "cat", "line": "Мурка снова дома", "pct": 8, "left": 30, "fam": kid_fam}]}
	var s := City.stories_load(JSON.parse_string(JSON.stringify(old)))
	var e: Dictionary = s["done"]["cat"]
	check(String(e["kid"]) == "Мария" and bool(e["female"]) and not bool(e["child"]) and String(e["cat_name"]) == "Мася" and int(e["fur"]) == People.CAT_MASYA
		and String(e["text"]).begins_with("Мария сама нашла Масю") and String(e["text"]).contains("Награда: украшение «Кошачья корзинка»") and not String(e["text"]).contains("Мурк"),
		"пройденная история — с новыми именами: «%s»" % e["text"])
	var p0: Dictionary = s["pets"][0]
	check(String(p0["name"]) == "Мася" and int(p0["fur"]) == People.CAT_MASYA, "кошка-награда «Мурка» стала чёрной Масей (%s)" % p0)
	check(String(s["bonus"][0]["line"]) == "Мася снова дома", "строка счастья дома: «%s»" % s["bonus"][0]["line"])
	var s2 := City.stories_load(JSON.parse_string(JSON.stringify(s)))
	var e2: Dictionary = s2["done"]["cat"]
	var p2: Dictionary = s2["pets"][0]
	check(String(e2["kid"]) == String(e["kid"]) and String(e2["cat_name"]) == String(e["cat_name"]) and int(e2["fur"]) == int(e["fur"]) and String(e2["text"]) == String(e["text"])
		and bool(e2["female"]) and String(p2["name"]) == String(p0["name"]) and int(p2["fur"]) == int(p0["fur"]) and String(s2["bonus"][0]["line"]) == String(s["bonus"][0]["line"]),
		"вторая загрузка ничего не меняет")
	# идущая история: искали Мурку — теперь ищут чёрную Масю, просит Мария
	var act := {"id": "cat", "step": 1, "t0": 45, "home": hid, "fam": kid_fam, "kid": "Луций", "seed": 7, "cls": "plebs", "child": true, "female": false,
		"cat_name": "Мурка", "fur": 0, "flags": {}}
	var sa := City.stories_load(JSON.parse_string(JSON.stringify({"h": 50, "active": act, "offer": {}})))
	var a2: Dictionary = sa["active"]
	check(String(a2.get("kid", "")) == "Мария" and String(a2.get("cat_name", "")) == "Мася" and int(a2.get("fur", -1)) == People.CAT_MASYA and bool(a2.get("female", false))
		and not bool(a2.get("child", true)), "идущая история — ищем Масю, просит Мария (%s)" % a2)
	var hint := StoryDefs.fill(String((StoryDefs.goal_step(StoryDefs.story("cat"), "find")["hints"] as Array)[0][1]), a2)
	check(hint.begins_with("Мария:"), "подсказка — от Марии: «%s»" % hint)
	# колокольчик старого города: просьба, «сам нашёл», «завершена», «для истории» — с новыми именами; чужое не трогаем
	var evs: Array = JSON.parse_string(JSON.stringify(OLD_BELL))
	StoryDefs.migrate_events(evs)
	var bell := ""
	for ev: Dictionary in evs:
		bell += String(ev["text"]) + " | "
	check(not bell.contains("Мурк") and not bell.contains("Маленький") and String(evs[0]["text"]).begins_with("Мария из семьи Корнелиев чем-то расстроена — над их домом свиток")
		and String(evs[1]["text"]) == "Мария сама нашла Масю — та дремала в укромном уголке. Кошка снова дома."
		and String(evs[2]["text"]).begins_with("История «Где Мася?» завершена. Мария сама нашла Масю — та дремала") and String(evs[2]["text"]).contains("Награда: украшение")
		and String(evs[3]["text"]).ends_with("для истории «Где Мася?».") and String(evs[3]["icon"]) == "decor"
		and String(evs[0]["icon"]) == "cat_black" and String(evs[2]["icon"]) == "cat_black"
		and String(evs[4]["text"]) == String(OLD_BELL[4]["text"]) and String(evs[4]["icon"]) == "cat", "колокольчик старого города: %s" % bell)
	var evs2: Array = evs.duplicate(true)
	StoryDefs.migrate_events(evs2)
	check(evs2 == evs, "колокольчик: вторая загрузка ничего не меняет")
	# в городе: кошка-награда — чёрная Мася; журнал и «Пересмотреть» — по-новому
	var keep: Dictionary = c.stories
	c.stories = s
	var n0: int = game.people.cats.size()
	sto._restore()
	var pet: Dictionary = game.people.cats[-1] if game.people.cats.size() > n0 else {}
	var pm: ShaderMaterial = pet.get("mat")
	check(String(pet.get("named", "")) == "Мася" and pm != null and (pm.get_shader_parameter("fur") as Color).get_luminance() < 0.15,
		"после загрузки у дома гуляет чёрная Мася (%s)" % pet.get("named", ""))
	# портрет в карточке кошки — по номеру окраса (cat_node(cat_fi)): чёрная Мася, а не рыжая (и у кошки без «fi» — по цвету)
	var pf := People.cat_fi(pet)
	var pn := People.cat_node(pf, "Pet", 7)
	var pmats := pn.find_children("*", "MeshInstance3D", true, false).map(func(mi): return (mi as MeshInstance3D).get_active_material(0)) \
		.filter(func(mt): return mt is ShaderMaterial)
	var pcol: Color = (pmats[0] as ShaderMaterial).get_shader_parameter("fur") if not pmats.is_empty() else Color.WHITE
	check(pf == People.CAT_MASYA and int(pet.get("fi", -1)) == People.CAT_MASYA and People.cat_fi({"fur": pet["fur"]}) == People.CAT_MASYA
		and pcol.is_equal_approx(People.CAT_MASYA_FUR[0]), "портрет Маси — чёрный (окрас %d, шерсть %s)" % [pf, pcol.to_html(false)])
	pn.free()
	hud.refresh()
	sto.ui.open_journal()
	await frames(20)
	var txt := ""
	for l: Label in hud.journal_panel.find_children("*", "Label", true, false):
		txt += l.text + " | "
	check(txt.contains("Где Мася?") and txt.contains("Мария сама нашла Масю") and not txt.contains("Мурк"), "журнал старого города: «Где Мася?», Мария и Мася")
	await shot("story_migrated_journal.png")
	hud.journal_panel.visible = false
	# ролик начнётся, когда мир свободен (can_start: прошлый ролик закрылся) — под нагрузкой всего набора это не сразу
	var t0 := cine_t
	while not sto.can_start() and cine_t - t0 < 5.0:
		await get_tree().process_frame
	sto.replay("cat")
	var started := not sto.cine.is_empty()
	var said: bool = await wait_beat("say", 12.0)
	var who: Dictionary = sto._speaker("maria") if not sto.cine.is_empty() else {}
	var cw: Dictionary = sto._speaker("cat") if not sto.cine.is_empty() else {}
	check(said and String(who.get("name", "")) == "Мария" and bool(who.get("female", false)) and not bool(who.get("child", true))
		and String(cw.get("name", "")) == "Мася" and int(cw.get("fur", -1)) == People.CAT_MASYA,
		"«Пересмотреть»: Мария (девушка) и чёрная Мася (ролик %s, реплика %s, %s / %s)" % [started, said, who.get("name", ""), cw.get("name", "")])
	press_key(KEY_ESCAPE)
	await wait_kit(false, 4.0)
	for cc in game.people.cats.duplicate():
		if cc.has("named"):
			game.people.drop_cat(cc)
	c.stories = keep


const OWNER := "D:/CivCity/.work/owner_save/city.json"


## Город владельца со старой «Где Мурка?» (пройдена, кошка-награда «Мурка», бонус дома) — в папку сохранений
## этого запуска (у каждого запуска gpu_run — своя)
func _old_cat_save() -> void:
	if not FileAccess.file_exists(OWNER):
		return
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OWNER))
	var home := -1
	var fam := ""
	for b: Dictionary in d.get("buildings", []):
		if String(b.get("type", "")).begins_with("house") and not (b.get("families", []) as Array).is_empty():
			home = int(b["id"])
			fam = String(b["families"][0]["name"])
			break
	d["stories"] = {"v": 1, "h": 120, "last_h": 110, "active": {}, "offer": {}, "later": {}, "orders": {}, "granted": {},
		"done": {"cat": {"day": 3, "h": 40, "home": home, "fam": fam, "kid": "Луций", "seed": 7, "cls": "plebs", "how": "found",
			"cat_name": "Мурка", "fur": 0, "text": "Награда: украшение «Кошачья корзинка» (Украшения), дому семьи +8% счастья на 3 дня, +25 очков исследований, ещё одна кошка в городе."}},
		"bonus": [{"id": "cat", "line": "Мурка снова дома", "pct": 8, "left": 30, "fam": fam}],
		"pets": [{"home": home, "fur": 0, "name": "Мурка", "seed": 5}]}
	var evs: Array = d.get("events", [])
	evs.append_array(OLD_BELL)                 # и в колокольчике — старые строки «Где Мурка?»
	d["events"] = evs
	DirAccess.make_dir_recursive_absolute(GamePaths.save_dir())
	var f := FileAccess.open(GamePaths.save_dir().path_join("city.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "", false, true))
	f.close()


## mode=owner_old — город владельца, в сохранение которого вписана старая «Где Мурка?» (пройдена, кошка-награда
## «Мурка», бонус дома): после загрузки с диска — Мария и чёрная Мася в журнале, у дома гуляет чёрная Мася
func _owner_old() -> void:
	var S := c.stories
	var e: Dictionary = (S["done"] as Dictionary).get("cat", {})
	check(String(e.get("kid", "")) == "Мария" and String(e.get("cat_name", "")) == "Мася" and int(e.get("fur", -1)) == People.CAT_MASYA
		and not String(e.get("text", "")).contains("Мурк"), "город владельца со старой «Мурка»: %s" % e)
	var pet := {}
	for cc in game.people.cats:
		if String(cc.get("named", "")) != "":
			pet = cc
	var pm: ShaderMaterial = pet.get("mat")
	check(String(pet.get("named", "")) == "Мася" and pm != null and (pm.get_shader_parameter("fur") as Color).get_luminance() < 0.15,
		"у дома гуляет чёрная Мася (%s)" % pet.get("named", ""))
	var line := ""
	for b: Dictionary in S["bonus"]:
		line += String(b.get("line", ""))
	check(line == "Мася снова дома", "строка счастья: «%s»" % line)
	var bell := ""
	var fin := ""
	for ev: Dictionary in c.events:
		bell += String(ev.get("text", "")) + " | "
		if String(ev.get("text", "")).begins_with("История «Где Мася?» завершена"):
			fin = String(ev["text"]) + " [" + String(ev.get("icon", "")) + "]"
	check(not bell.contains("Мурк") and fin.contains("Мария сама нашла Масю") and fin.ends_with("[cat_black]"), "колокольчик города владельца: «%s»" % fin)
	hud.advisor_panel.visible = false
	sto.ui.open_journal()
	await frames(20)
	var txt := ""
	for l: Label in hud.journal_panel.find_children("*", "Label", true, false):
		txt += l.text + " | "
	check(txt.contains("Где Мася?") and txt.contains("Мария") and not txt.contains("Мурк"), "журнал: «Где Мася?», Мария")
	await shot("story_owner_old_journal.png")
	hud.journal_panel.visible = false
	if not pet.is_empty():
		var pp: Vector2 = pet["p"]
		game.rig.set_view(Vector3(pp.x, Land.BASE_Y, pp.y), 200.0, 34.0, 7.0)
		await frames(40)
		await shot("story_owner_old_masya.png")


# ---------- Д13: в новой игре Легиона нет ----------

## Новая игра: ни зданий Легиона, ни бойцов в строю, окно закрыто; медальон серый — подсказка, что такое Легион
## и что его строят сами (история «Разбойники у арки» откроет его)
func _new_game_no_legion() -> void:
	print("== новая игра: готового Легиона нет (Д13)")
	var lg: Legion = c.legion
	var mil := []
	for id in c.buildings:
		if String(c.def(c.buildings[id])["kind"]) == "military":
			mil.append(String(c.buildings[id]["type"]))
	var units := []
	for t in Legion.UNIT_IDS:
		if lg.available(t):
			units.append(t)
	await frames(3)
	check(mil.is_empty() and units.is_empty() and not lg.window_open() and not c.research.has("legion") and lg.progress == 0 and lg.auto_squad().is_empty(),
		"новая игра: зданий Легиона %s, бойцов в строю %s, окно закрыто — готового Легиона нет" % [mil, units])
	var lu := LegionUi.of(hud)
	var tip := lu.btn.tooltip_text if lu != null else ""
	check(lu != null and lu.btn_wrap.visible and tip.contains("Разбойники у арки") and tip.contains("Готового Легиона нет") and tip.contains("построите"),
		"медальон серый: «%s»" % tip)


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
	c.rp = c.rp_cap()                    # полки полны: очков не прибавится — и награда не обещает их
	sto.found()
	check(sto.kit != null, "нашли — ролик встречи")
	var rtxt := String(S["done"].get("cat", {}).get("text", ""))
	check(is_equal_approx(c.rp, c.rp_cap()) and not rtxt.contains("+25 очков") and rtxt.contains("полки полны"), "полки полны — в награде честно: «%s»" % rtxt)
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
	check(String(S["done"].get("cat", {}).get("how", "")) == "self", "12 ч — Мария нашла сама")
	check(is_equal_approx(c.rp, rp0), "без очков исследований")
	check(c.research.has("s_cat") and (S["bonus"] as Array).size() == 1, "корзинка и счастье дома — есть")
	check(c.events.size() == ev0 + 1 and String(c.events[-1]["text"]).contains("сама нашла Масю"), "колокольчик: «%s»" % c.events[-1]["text"])
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
	check(sto._glow != null and is_equal_approx(sto._glow_r, 12.0), "место поисков — по часам (4 ч — 12 м)")
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
	# нашли, а ролик встречи ждёт (игра на паузе, ждёт ролик ранга) — сохранили, загрузили: кошка на месте, ролик снимает её
	fresh(450)
	S = c.stories
	sto.tick()
	sto.accept()
	var spot2: Array = S["active"]["spot"]
	var sp2 := Vector2(float(spot2[0]), float(spot2[1]))
	game.rank_cine.pending = {"from": c.level, "to": c.level + 1, "late": true}   # (без кадров: rank_cine вне игры его снимет)
	sto.found()
	check(sto.kit == null and bool(S["active"].get("ready", false)) and (S["done"] as Dictionary).is_empty(), "ролик ранга ждёт — встреча ждёт щелчка («Готово»)")
	var d2: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	game.people.drop_cat(sto.cat)
	sto.cat = {}
	c.stories = City.stories_load(d2["stories"])
	S = c.stories
	sto._restore()
	check(not sto.cat.is_empty() and (sto.cat["p"] as Vector2).distance_to(sp2) < 0.01, "после загрузки кошка там же (ждёт Марию)")
	check(not sto.try_click(game.rig.cam.unproject_position(sto._cat_pos())), "найденную кошку второй раз не находят")
	game.rank_cine.pending = {}
	sto.play_ready()
	var flew: bool = await wait_beat("fly", 6.0)
	var foc: Vector2 = sto.cine.get("focus", Vector2.INF)
	check(flew and foc.distance_to(sp2) < 1.0, "ролик встречи — у кошки (%s / %s)" % [foc, sp2])
	press_key(KEY_ESCAPE)
	await wait_kit(false, 4.0)
	await frames(4)
	var home_cat := false
	for cc in game.people.cats:
		if cc.has("named") and not cc.has("story") and String(cc.get("named", "")) != "":
			home_cat = true
	check((S["done"] as Dictionary).has("cat") and sto.cat.is_empty() and home_cat, "кошка — домой к семье")


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
	check(not woman_of(kid_fam, int(kid_home["id"])).is_empty(), "Мария с ними")
	S["last_h"] = -1
	S["later"] = {}
	sto._h_seen = -1
	sto.tick()
	check(String(S["offer"].get("fam", "")) == kid_fam and int(S["offer"].get("home", -1)) == int(kid_home["id"]), "предложение снова")
	# дом переносят: предложение не пропадает, едет за домом
	var old_id := int(kid_home["id"])
	check(game.start_move(kid_home), "дом Корнелиев подняли (перенос)")
	for i in 4:
		sto.tick()
	await frames(45)
	check(String(S["offer"].get("id", "")) == "cat" and not (S["later"] as Dictionary).has("cat"), "пока дом в руках — предложение ждёт")
	check(not hud.badges.has("story"), "свиток пока не висит")
	var moved := false
	cands.sort_custom(func(p, q): return p.distance_squared_to(Vector2(174, 118)) < q.distance_squared_to(Vector2(174, 118)))
	for p in cands.slice(0, 300):
		reset_place()
		var pl: Dictionary = game.placement("house_pleb", p)
		if pl["err"] == "" and pl["sub"] == "road":
			game.hover = p
			game._build_here()
			moved = game.moving.is_empty()
			break
	var nid := int(S["offer"].get("home", -1))
	check(moved and nid != old_id and c.buildings.has(nid) and String(S["offer"].get("fam", "")) == kid_fam, "дом поставили — предложение у него (дом %d → %d)" % [old_id, nid])
	if c.buildings.has(nid):
		kid_home = c.buildings[nid]
	sto.tick()
	await frames(3)
	check(hud.badges.has("story") and not (S["later"] as Dictionary).has("cat"), "свиток снова над домом")
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
	check(String(o.get("id", "")) == "cat", "4 ч — «Где Мася?» (%s)" % o)
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
	# потом — «Течь в водопроводе» (у владельца изучены фонтаны): через GAP_H после кошки
	for i in StoryDefs.GAP_H:
		c._story_hour()
	sto._tried = ""
	sto.tick()
	check(String(S["offer"].get("id", "")) == "leak", "через %d ч — «Течь в водопроводе» (%s)" % [StoryDefs.GAP_H, S["offer"].get("fam")])
	if String(S["offer"].get("id", "")) == "leak":
		await _owner_leak()
	# потом — скверик (у владельца «Деревня»): через GAP_H после течи
	for i in StoryDefs.GAP_H:
		c._story_hour()
	sto._tried = ""
	sto.tick()
	o = S["offer"]
	check(String(o.get("id", "")) == "square", "через %d ч — «Скверик для стариков» (%s)" % [StoryDefs.GAP_H, o.get("fam")])
	if o.is_empty():
		return
	h = c.buildings[int(o["home"])]
	var hp: Vector2 = h["pos"]
	print("owner: скверик просит ", StoryDefs.elder(String(o["fam"])), " из семьи ", o["fam"], " дом ", o["home"], " at ", hp, " свободно ", sto.free_near(hp, 15.0), " м²")
	hud.advisor_panel.visible = false
	game.rig.set_view(Vector3(hp.x + 2, Land.BASE_Y, hp.y + 3), 215.0, 40.0, 34.0)
	await frames(40)
	await shot("story_owner_square_offer.png")
	sto.open_offer()
	await wait_beat("say", 6.0)
	await frames(80)
	sto.ui.finish_typing()
	await frames(10)
	await shot("story_owner_square_ask.png")
	await play_through(25.0)
	await wait_kit(false, 4.0)
	var A2: Dictionary = S["active"]
	check(sto._goal_kind(A2) == "square", "скверик строят")
	if sto._goal_kind(A2) != "square":
		return
	var g: Array = sto._step(A2)["goal"]
	print("owner: рядом уже ", sto.progress(A2, g)["parts"])
	var k := 0
	while int(sto.progress(A2, g)["benches"]) < 3 and k < 12:
		deco("bench", hp + Vector2(cos(k * 1.1), sin(k * 1.1)) * 7.0)
		k += 1
	k = 0
	while int(sto.progress(A2, g)["parts"][1][1]) < 2 and k < 8:
		deco("tree", hp + Vector2(cos(k * 1.7 + 0.5), sin(k * 1.7 + 0.5)) * 9.0)
		k += 1
	k = 0
	while int(sto.progress(A2, g)["parts"][2][1]) < 1 and k < 6:
		deco("well", hp + Vector2(cos(k * 2.1 + 1.0), sin(k * 2.1 + 1.0)) * 8.0)
		k += 1
	sto.tick()
	var pr: Dictionary = sto.progress(A2, g)
	check(bool(pr["min"]), "в городе владельца скверик собирается: %s" % [pr["parts"]])
	hud.advisor_panel.visible = false
	sto.life._sync(true)
	game.rig.set_view(Vector3(hp.x, Land.BASE_Y, hp.y), 200.0, 45.0, 26.0)
	await frames(90)
	await shot("story_owner_square.png")
	if not bool(pr["min"]):
		return
	sto.press("ready")
	await play_through(40.0, "reward", "story_owner_square_open.png")
	await wait_kit(false, 4.0)
	check((S["done"] as Dictionary).has("square"), "в городе владельца скверик готов: %s" % S["done"].get("square", {}).get("text", ""))
	# потом — «Ослик возчика»
	for i in StoryDefs.GAP_H:
		c._story_hour()
	sto._tried = ""
	sto.tick()
	check(String(S["offer"].get("id", "")) == "donkey", "через %d ч — «Ослик возчика» (%s)" % [StoryDefs.GAP_H, S["offer"].get("fam")])
	if String(S["offer"].get("id", "")) == "donkey":
		await _owner_donkey()
	# дальше — «Тесно у …» (если есть дом в два этажа) или свадьба: предложение складывается
	for i in StoryDefs.GAP_H:
		c._story_hour()
	sto._tried = ""
	sto.tick()
	var nx := String(S["offer"].get("id", ""))
	print("owner: следующая история — ", nx, " ", S["offer"].get("fam", ""))
	check(nx in ["crowded", "wedding", ""], "дальше — «Тесно» или свадьба (%s)" % nx)
	# заказы старосты: у владельца появились сами (строка ждёт), денег за них нет
	check(not sto.orders.row_info().is_empty() and bool(sto.orders.row_info().get("waiting", false)), "в городе владельца ждёт заказ старосты: «%s»" % sto.orders.row_info().get("text", ""))


## Город владельца: «Течь в водопроводе» — лужи, мастер у трубы, фонтаны у домов (у владельца их, верно, хватает)
func _owner_leak() -> void:
	var S := c.stories
	var o: Dictionary = S["offer"]
	print("owner: течь — ", StoryDefs.nomen_f(String(o["fam"])), " из семьи ", o["fam"], " дом ", o["home"])
	hud.advisor_panel.visible = false
	sto.open_offer()
	await play_through(25.0)
	await wait_kit(false, 4.0)
	var A: Dictionary = S["active"]
	check(sto._goal_kind(A) == "click" and (A.get("clicks", []) as Array).size() == 3, "в городе владельца: три лужи вдоль улицы")
	if sto._goal_kind(A) != "click":
		return
	var cl: Array = A["clicks"]
	var mid := (Vector2(float(cl[0][0]), float(cl[0][1])) + Vector2(float(cl[2][0]), float(cl[2][1]))) * 0.5
	await look_at_pt(mid, 24.0)
	await frames(30)
	await shot("story_owner_leak_puddles.png")
	for i in cl.size():
		sto.click_target(i)
		await frames(3)
	check(sto.kit != null, "в городе владельца: все лужи найдены — ролик с мастером")
	if await drive_until("walk", 20.0):
		await get_tree().create_timer(1.0).timeout
		await shot("story_owner_leak_walk.png")
	await play_through(40.0)
	await wait_kit(false, 4.0)
	sto.tick()
	print("owner: домов плебеев у фонтанов: ", c.progress_of(["near", "fountain", "plebs"]), ", шаг ", A.get("step"), " ready=", A.get("ready", false))
	if bool(A.get("ready", false)):
		sto.play_ready()
		await play_through(40.0)
		await wait_kit(false, 4.0)
	check((S["done"] as Dictionary).has("leak"), "в городе владельца течь заделана: %s" % S["done"].get("leak", {}).get("text", ""))


## Город владельца: «Ослик возчика» — найти ослика; лавка у дома возчика (если торгует) — ослик везёт товар
func _owner_donkey() -> void:
	var S := c.stories
	sto.accept()
	var A: Dictionary = S["active"]
	check(sto._goal_kind(A) == "find" and not sto.beast.is_empty(), "в городе владельца ослик спрятался")
	if sto.beast.is_empty():
		return
	await look_at_pt(sto.beast["p"], 14.0)
	await frames(30)
	await shot("story_owner_donkey.png")
	sto.found()
	await play_through(30.0)
	await wait_kit(false, 4.0)
	sto.tick()
	var w: Dictionary = sto.works_eval(A, sto._step(A).get("goal", [])) if sto._goal_kind(A) == "works" else {}
	print("owner: у дома возчика лавки: ", w.get("shops", "торгует сразу"), " шаг ", A.get("step"), " ready=", A.get("ready", false))
	check(sto._goal_kind(A) == "works" or bool(A.get("ready", false)), "в городе владельца — шаг «лавка у дома»")
	if bool(A.get("ready", false)):
		sto.play_ready()
		if await drive_until("walk", 20.0):
			await get_tree().create_timer(1.2).timeout
			await shot("story_owner_donkey_haul.png")
		await play_through(40.0)
		await wait_kit(false, 4.0)
		check((S["done"] as Dictionary).has("donkey"), "в городе владельца ослик возит товар: %s" % S["done"].get("donkey", {}).get("text", ""))


# ---------- «Скверик для стариков» ----------

## Сколько стариков сидит (или идёт сесть) в скверике
func elders_n(state := "") -> int:
	var n := 0
	for k in sto.life.elders:
		var e: Dictionary = sto.life.elders[k]
		if not e.get("table", false) and (state == "" or String(e["state"]) == state):
			n += 1
	return n


## Новый квартал для проверок скверика и свадьбы (там просторно)
func _block() -> void:
	street(Vector2(170, 178), Vector2(170, 206))
	street(Vector2(160, 206), Vector2(212, 206))
	for i in 9:
		var h := put("house_pleb", Vector2(161 + i * 5.5, 209))
		if not h.is_empty():
			settle(h, "Квартал %d" % i)
	c.compute()


func _square() -> void:
	print("== скверик для стариков")
	StoryDefs.extra = []
	_block()
	game._set_hour(10.5)
	# «Отложить» — пауза для всех историй: отложили кошку — и скверик сутки не просят; потом первой — снова кошка
	c.level = 2
	fresh(950)
	var S0 := c.stories
	sto._tried = ""
	sto.tick()
	var sq_can := not sto.can_offer(StoryDefs.story("square")).is_empty()
	check(String(S0["offer"].get("id", "")) == "cat" and sq_can, "«Деревня»: просят «Где Мася?», скверик тоже можно предложить")
	sto.postpone()
	var h0 := int(S0["h"])
	var quiet := true
	for dh in [0, 1, 6, 12, StoryDefs.LATER_H - 1]:
		S0["h"] = h0 + dh
		sto._tried = ""
		sto.tick()
		quiet = quiet and (S0["offer"] as Dictionary).is_empty()
	check(quiet, "после «Отложить» сутки — ни одной просьбы (и скверик ждёт)")
	S0["h"] = h0 + StoryDefs.LATER_H
	sto._tried = ""
	sto.tick()
	check(String(S0["offer"].get("id", "")) == "cat", "через сутки — снова «Где Мася?» (та, что отложили)")
	c.level = 1
	fresh(1000, ["cat"])
	var S := c.stories
	sto._tried = ""
	sto.tick()
	check((S["offer"] as Dictionary).is_empty(), "ранг «Хутор» — скверик не предлагают (с «Деревни»)")
	c.level = 2
	c.research.erase("deco_trees")
	sto._tried = ""
	sto.tick()
	check((S["offer"] as Dictionary).is_empty(), "деревья не изучены — скверик не предлагают (не пройти)")
	c.research["deco_trees"] = true
	sto._tried = ""
	sto.tick()
	var o: Dictionary = S["offer"]
	check(String(o.get("id", "")) == "square" and int(c.stats["pop"]) >= 60, "«Деревня», %d жителей — просят скверик (%s)" % [int(c.stats["pop"]), o.get("fam")])
	if o.is_empty():
		return
	var home: Dictionary = c.buildings[int(o["home"])]
	var hp: Vector2 = home["pos"]
	check(bool(o.get("old", false)) and sto.free_near(hp, 15.0) >= 40, "просит старик; вокруг дома есть где разбить скверик (%d м²)" % sto.free_near(hp, 15.0))
	var info: Dictionary = sto.row_info()
	check(String(info.get("text", "")).contains("просит о помощи") and String(info.get("title", "")) == "Скверик для стариков", "золотая строка: «%s»" % info.get("text"))
	await frames(20)
	check(hud.badges.has("story"), "свиток над домом старика")
	game.rig.set_view(Vector3(hp.x + 2, Land.BASE_Y, hp.y + 3), 215.0, 40.0, 30.0)
	await frames(40)
	await shot("story_square_offer.png")
	# ролик просьбы: старик седой, лицо — для крупного плана
	hud._badge_click("story")
	check(sto.kit != null, "щелчок по свитку — ролик")
	var said: bool = await wait_beat("say", 8.0)
	await frames(60)
	sto.ui.finish_typing()
	await frames(10)
	var act = sto.cine["actors"].get("elder")
	check(said and act != null and sto.ui.name_lbl.text.ends_with(StoryDefs.nomen(String(o["fam"]))) and sto.ui.role_lbl.text.begins_with("дед"),
		"облачко: «%s», %s" % [sto.ui.name_lbl.text, sto.ui.role_lbl.text])
	if act != null:
		var silver := false
		var lay := true
		for mi: MeshInstance3D in (act as Node).find_children("*", "MeshInstance3D", true, false):
			lay = lay and (mi.layers & Citizen.FACE_LAYER) != 0
			silver = silver or mi.material_override == Citizen._silver
		check(silver and lay, "старик седой, лицо — на свету для крупного плана")
	await shot("story_square_ask.png")
	var t0 := cine_t
	while not sto.ui.choosing() and cine_t - t0 < 15.0:
		sto.ui.finish_typing()
		await frames(3)
		sto._next()
		await frames(10)
	check(sto.ui.choosing() and sto.ui.pills.get_child_count() == 2, "выбор: «Будет вам скверик!» / «Чуть позже, отец»")
	(sto.ui.pills.get_child(0) as Button).pressed.emit()
	await play_through(12.0)
	await wait_kit(false, 4.0)
	var A: Dictionary = S["active"]
	check(String(A.get("id", "")) == "square" and sto._goal_kind(A) == "square", "история идёт: шаг «скверик»")
	if sto._goal_kind(A) != "square":
		return
	# советник объясняет пороги один раз (мог успеть сам, пока ролик закрывался)
	if not (hud.advisor_panel.visible and hud.adv_title.text == "Скверик для стариков"):
		hud.advisor_panel.visible = false
		sto.tick()
	check(c.tips.has("story_square") and hud.advisor_panel.visible and hud.adv_title.text == "Скверик для стариков", "советник один раз объяснил скверик и «Готово»")
	hud.advisor_panel.visible = false
	await frames(5)
	check(sto._glow != null and is_equal_approx(sto._glow_r, 15.0), "место скверика подсвечено (15 м)")
	# ставим самое нужное: скамьи, деревья, колодец
	var g: Array = sto._step(A)["goal"]
	var pr: Dictionary = sto.progress(A, g)
	print("  было рядом: ", pr["parts"])
	if int(pr["tier"]) == 0:
		var t0txt := String(sto.row_info()["text"])
		check(t0txt.contains("Бронза — 3 скамьи.") and t0txt.contains("деревьев и кустов"), "строка в начале: «%s»" % t0txt)
	var dirs := [Vector2(6, 2), Vector2(-6, 3), Vector2(2, 7), Vector2(-3, -7), Vector2(7, -4), Vector2(-7, -3), Vector2(4, 8), Vector2(-5, 7), Vector2(8, 5)]
	var di := 0
	while int(sto.progress(A, g)["benches"]) < 3 and di < 9:
		deco("bench", hp + dirs[di])
		di += 1
	for t in 3:
		if int(sto.progress(A, g)["parts"][1][1]) < 2:
			deco("tree", hp + dirs[(di + t) % 9] * 1.15)
	if int(sto.progress(A, g)["parts"][2][1]) < 1:
		deco("well", hp + Vector2(-8, 0))
	sto.tick()
	pr = sto.progress(A, g)
	check(bool(pr["min"]) and int(pr["tier"]) == 1 and int(pr["benches"]) == 3, "3 скамьи, 2 дерева, колодец — бронза (%s)" % [pr["parts"]])
	info = sto.row_info()
	var btn0 := String((info["buttons"] as Array)[0][0])
	check(btn0 == "Готово (бронза)" and String(info["text"]).contains("+3%") and String(info["text"]).contains("Серебро — 5 скамей"),
		"строка: «%s» [%s]" % [info["text"], btn0])
	# старики приходят: скамей больше — стариков больше
	sto.life._sync(false)
	var n3 := elders_n()
	var busy := 0                        # места, где уже сидят жители (их старики не занимают)
	for id in game.people.spots:
		if c.buildings.has(id) and Defs.base_of(c.buildings[id]["type"]) == "bench" and (c.buildings[id]["pos"] as Vector2).distance_to(hp) <= 15.0:
			for k in game.people.spots[id]:
				if int(game.people.spots[id][k]) != StoryLife.MARK:
					busy += 1
	check(n3 >= 2 and n3 <= 4 and n3 + busy >= 3, "три скамьи — пришли старики (%d, жители сидят на %d местах)" % [n3, busy])
	var walker := {}
	for k in sto.life.elders:
		if String(sto.life.elders[k]["state"]) == "in":
			walker = sto.life.elders[k]
	if not walker.is_empty():
		var p0: Vector3 = (walker["node"] as Node3D).position
		game.speed = 1.0
		await frames(90)
		game.speed = 0.0
		check((walker["node"] as Node3D).position.distance_to(p0) > 0.3, "старик идёт к скамье от дома (%.1f м)" % (walker["node"] as Node3D).position.distance_to(p0))
	# сохранение посреди шага
	var d: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	var c2 := City.new(game.land)
	c2.load_data(d)
	check(String(c2.stories["active"].get("id", "")) == "square" and int(c2.stories["active"].get("step", -1)) == 1, "после загрузки — тот же шаг скверика")
	# ещё скамьи: серебро, потом семь — всё ещё серебро без часов, с часами — золото
	while int(sto.progress(A, g)["benches"]) < 5 and di < 9:
		deco("bench", hp + dirs[di])
		di += 1
	pr = sto.progress(A, g)
	check(int(pr["tier"]) == 2, "5 скамей — серебро (%d)" % int(pr["benches"]))
	sto.life._sync(false)
	var n5 := elders_n()
	check(n5 > n3, "скамей больше — и стариков больше (%d → %d)" % [n3, n5])
	while int(sto.progress(A, g)["benches"]) < 7 and di < 9:
		deco("bench", hp + dirs[di])
		di += 1
	pr = sto.progress(A, g)
	check(int(pr["benches"]) >= 7 and int(pr["tier"]) == 2 and String(sto.row_info()["text"]).contains("солнечные часы"), "7 скамей без часов — серебро, строка зовёт к часам")
	c.research["deco_stone"] = true
	var sun_b := deco("sundial", hp + Vector2(0, -4))
	pr = sto.progress(A, g)
	check(int(pr["tier"]) == 3, "7 скамей и солнечные часы — золото")
	sto.life._sync(true)
	var n7 := elders_n("sit")
	check(n7 >= 6, "старики сидят на скамьях (%d)" % n7)
	var sc := sto.square_center(A, 15.0)
	game.rig.set_view(Vector3(sc.x, Land.BASE_Y, sc.y), 200.0, 34.0, 15.0)
	await frames(50)
	await shot("story_square_elders.png")
	game.rig.set_view(Vector3(hp.x, Land.BASE_Y, hp.y), 200.0, 50.0, 40.0)
	hud.refresh()
	await frames(30)
	await shot("story_square_ready.png")
	# «Готово» — сразу ролик и награда
	var houses_near := []
	var house_far := {}
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		if c.is_house(b) and int(b["pop"]) > 0:
			if (b["pos"] as Vector2).distance_to(sc) <= 15.0:
				houses_near.append(b)
			elif (b["pos"] as Vector2).distance_to(sc) > 25.0:
				house_far = b
	info = sto.row_info()
	check(String((info["buttons"] as Array)[0][0]) == "Готово (золото)", "кнопка «Готово (золото)»")
	((info["buttons"] as Array)[0][1] as Callable).call()
	check(sto.kit != null and (S["done"] as Dictionary).has("square"), "«Готово» — ролик сразу, история пройдена")
	var e: Dictionary = S["done"].get("square", {})
	check(c.research.has("s_square") and c.unlocked("latrunc"), "украшение «Стол для латрункулов» открыто")
	var mon := {}
	for bb: Dictionary in S["bonus"]:
		if String(bb.get("id", "")) == "square":
			mon = bb
	check(int(mon.get("pct", 0)) == 7 and is_equal_approx(float(mon.get("r", 0)), 15.0) and int(mon.get("left", 0)) == -1, "памятник: +7%% в 15 м навсегда (%s)" % mon)
	check(String(e.get("text", "")).contains("+7% счастья — пока стоит скверик"), "в журнале: %s" % e.get("text"))
	c.compute()
	var line_ok := not houses_near.is_empty()
	for hb: Dictionary in houses_near:
		var has := false
		for pp: Array in hb["happy_parts"]:
			if String(pp[0]) == "Скверик для стариков" and int(pp[1]) == 7:
				has = true
		line_ok = line_ok and has
	var far_has := false
	for pp: Array in house_far.get("happy_parts", []):
		if String(pp[0]) == "Скверик для стариков":
			far_has = true
	check(line_ok and not far_has, "строка «Скверик для стариков» +7 у %d домов рядом, у дальних — нет" % houses_near.size())
	await play_through(40.0, "anim", "story_square_open.png", "reward", "story_square_reward.png")
	var ended: bool = await wait_kit(false, 4.0)
	check(ended and not game.rig.cine, "ролик скверика кончился")
	await frames(5)
	sto.life._sync(false)
	check(elders_n() >= 6, "и потом днём старики сидят в скверике (%d)" % elders_n())
	# стол для латрункулов: по утрам двое играют
	var lt := deco("latrunc", sc + Vector2(3, -9))
	check(not lt.is_empty(), "«Стол для латрункулов» поставлен")
	game._set_hour(8.0)
	sto.life._sync(true)
	var players := 0
	for k in sto.life.elders:
		if sto.life.elders[k].get("table", false):
			players += 1
	check(players == 2, "утром за доской двое стариков")
	if not lt.is_empty():
		var lp: Vector2 = lt["pos"]
		game.rig.set_view(Vector3(lp.x, Land.BASE_Y, lp.y), 150.0, 30.0, 6.0)
		await frames(110)
		await shot("story_latrunc.png")
	# вечер: расходятся по домам
	game._set_hour(19.0)
	sto.life._sync(false)
	var sitting := elders_n("sit")
	check(sitting == 0, "вечером старики встают и уходят")
	game._set_hour(10.5)
	sto.life.clear()
	# стол для латрункулов: играют не больше чем за StoryLife.TABLES столами (живые старики дороги)
	game._set_hour(8.0)
	var lts := [lt]
	for i in StoryLife.TABLES + 1:
		var t2 := deco("latrunc", sc + Vector2(-12 + i * 4, 12))
		if not t2.is_empty():
			lts.append(t2)
	sto.life._sync(true)
	var tabs := {}
	for k in sto.life.elders:
		if sto.life.elders[k].get("table", false):
			tabs[int(sto.life.elders[k]["bid"])] = true
	check(lts.size() > StoryLife.TABLES and tabs.size() == StoryLife.TABLES and tabs.has(int(lt.get("id", -1))),
		"столов %d — играют за %d (первый поставленный — среди них)" % [lts.size(), tabs.size()])
	game._set_hour(10.5)
	sto.life.clear()
	for t2: Dictionary in lts.slice(1):
		c.remove(t2)
	# «Пересмотреть» скверик: дед — взрослый и седой, не ребёнок; и по записи старой версии (без «ребёнок ли» и пола)
	for old_rec in [false, true]:
		if old_rec:
			(S["done"]["square"] as Dictionary).erase("child")
			(S["done"]["square"] as Dictionary).erase("female")
		sto.replay("square")
		var got: bool = await wait_beat("say", 8.0)
		var ea = sto.cine.get("actors", {}).get("elder")
		var spk: Dictionary = sto._speaker("elder") if not sto.cine.is_empty() else {}
		var k_sz := (ea as Node3D).scale.x / Citizen.SIZE if ea != null else 0.0
		check(got and is_equal_approx(k_sz, 1.0) and not bool(spk.get("child", true)) and bool(spk.get("old", false)),
			"«Пересмотреть» скверик%s: дед взрослый (рост ×%.2f) и седой, на портрете — не ребёнок" % [" (старая запись)" if old_rec else "", k_sz])
		if old_rec:
			await frames(20)
			sto.ui.finish_typing()
			await frames(10)
			await shot("story_square_replay.png")
		press_key(KEY_ESCAPE)
		await wait_kit(false, 5.0)
		await frames(3)
	# «памятник» — пока скверик стоит: часы убрали — серебро (+5%), колодец убрали — бонуса нет, поставили — снова +7%
	var hn: Dictionary = houses_near[0] if not houses_near.is_empty() else {}
	var mat: Array = mon.get("at", [])
	check(mat.size() == 2 and Vector2(float(mat[0]), float(mat[1])).distance_to(hp) < 0.01, "памятник помнит, где мерили скверик")
	var sun_pos: Vector2 = sun_b.get("pos", hp)
	if not sun_b.is_empty():
		c.remove(sun_b)
	c.compute()
	check(sq_pct(hn) == 5, "солнечные часы убрали — скверик серебряный: +%d%%" % sq_pct(hn))
	sun_b = deco("sundial", sun_pos)
	c.compute()
	check(sq_pct(hn) == 7, "часы вернули — снова +%d%%" % sq_pct(hn))
	var wells := []
	for id in c.buildings:
		var wb: Dictionary = c.buildings[id]
		if Stories._is(wb, "well|smallfountain") and (wb["pos"] as Vector2).distance_to(hp) <= 15.0:
			wells.append(wb)
	var well_pos: Vector2 = wells[0]["pos"] if not wells.is_empty() else hp
	for wb: Dictionary in wells:
		c.remove(wb)
	c.compute()
	check(not wells.is_empty() and sq_pct(hn) == 0, "колодец снесли — скверика нет, и строки счастья нет (+%d%%)" % sq_pct(hn))
	deco("well", well_pos)
	c.compute()
	check(sq_pct(hn) == 7, "колодец поставили — скверик снова золотой: +%d%%" % sq_pct(hn))
	# скверик строят, а дом деда снесли: стариков нет (и у станции тоже); семья заселилась — скверик у её нового дома
	fresh(1500, ["cat"])
	S = c.stories
	c.level = 2
	sto._tried = ""
	sto.tick()
	var o2: Dictionary = S["offer"]
	check(String(o2.get("id", "")) == "square", "скверик предложен снова (проверка «без дома»)")
	if o2.is_empty():
		return
	sto.accept()
	var A3: Dictionary = S["active"]
	# просит семья из квартала (её люди дома: снесут дом — выйдут на площадь)
	var efam := "Квартал 4"
	var eh := {}
	for id in c.buildings:
		for f: Dictionary in c.buildings[id].get("families", []):
			if String(f["name"]) == efam:
				eh = c.buildings[id]
	if eh.is_empty():
		check(false, "нет семьи «%s»" % efam)
		return
	A3["home"] = int(eh["id"])
	A3["fam"] = efam
	sto.tick()
	var sq0: Array = sto.life.squares()
	check(sq0.size() == 1 and (sq0[0]["c"] as Vector2).distance_to(eh["pos"]) < 0.01, "скверик строят — старики идут к дому деда")
	c.remove(eh)
	await frames(3)
	sto.tick()
	check(A3.has("homeless") and sto.life.squares().is_empty() and int(A3["step"]) == 1, "дом деда снесли — история ждёт, стариков нет (у станции тоже)")
	var eh2 := put(String(eh["type"]), eh["pos"])
	check(rehouse_fam(eh2, efam), "семья деда заселилась в новый дом")
	sto.tick()
	var sqs: Array = sto.life.squares()
	check(not A3.has("homeless") and sqs.size() == 1 and (sqs[0]["c"] as Vector2).distance_to(eh2.get("pos", Vector2.INF)) < 0.01,
		"скверик — у нового дома семьи")


## «Скверик для стариков» в счастье дома h: % (0 — строки нет)
func sq_pct(h: Dictionary) -> int:
	for pp: Array in h.get("happy_parts", []):
		if String(pp[0]) == "Скверик для стариков":
			return int(pp[1])
	return 0


## Семья fam с площади — в дом h (сразу, без прогулки)
func rehouse_fam(h: Dictionary, fam: String) -> bool:
	var f: Dictionary = c.arrival(fam)
	if h.is_empty() or f.is_empty() or not c.assign(fam, int(h["id"])):
		print("  rehouse_fam: нет — дом %s, на площади %s" % [h.get("id"), f])
		return false
	for ff: Dictionary in h.get("families", []):
		if String(ff["name"]) == fam:
			return true                      # люди стояли у самой двери — дошли сразу (People сам вызвал settled)
	return c.settled(int(h["id"]), int(f["n"]), fam) > 0


# ---------- «Свадьба Юлии» ----------

func _wedding() -> void:
	print("== свадьба Юлии")
	c.level = 2
	fresh(2000, ["cat", "square"])
	var S := c.stories
	c.research["artisans"] = true
	c.research["deco_flowers"] = true
	c.research["thermopolium"] = true
	var arts := []
	for i in 5:
		var h := put("house_artisan", Vector2(184 + i * 6, 202))
		if not h.is_empty():
			settle(h, ["Юлии", "Валерии", "Фабии", "Ливии", "Флавии"][i])
			arts.append(h)
	c.compute()
	c.level = 2
	sto._tried = ""
	sto.tick()
	check((S["offer"] as Dictionary).is_empty(), "ранг «Деревня» — свадьбу не предлагают (с «Посёлка»)")
	c.level = 3
	sto._tried = ""
	sto.tick()
	var o: Dictionary = S["offer"]
	check(String(o.get("id", "")) == "wedding" and int(c.progress_of(["cls", "artisans"])) >= 12, "«Посёлок», ремесленников %d — свадьба (%s)" % [c.progress_of(["cls", "artisans"]), o.get("fam")])
	if o.is_empty():
		return
	var roles: Dictionary = o.get("roles", {})
	check(roles.has("bride") and roles.has("groom") and roles.has("mother") and String(o.get("fam2", "")) != String(o["fam"]) and c.buildings.has(int(o.get("home2", -1))),
		"невеста из семьи %s, жених Марк из семьи %s (другой дом)" % [o["fam"], o.get("fam2")])
	check(String(sto.row_info().get("text", "")) == "Юлия и Марк ждут градоначальника", "строка: «%s»" % sto.row_info().get("text"))
	# таверна в выборе — только если её можно построить
	var opts: Array = StoryDefs.story("wedding")["steps"][0]["cine"][-1][3]
	c.research.erase("thermopolium")
	check(sto._avail(opts).size() == 2, "термополий не изучен — «Пир в таверне» не предлагают")
	c.research["thermopolium"] = true
	check(sto._avail(opts).size() == 3, "изучен — предлагают")
	var bride_h: Dictionary = c.buildings[int(o["home"])]
	var bp: Vector2 = bride_h["pos"]
	hud._badge_click("story")
	var ch: bool = await drive_until("choice", 30.0)
	await frames(10)
	sto.ui.finish_typing()
	check(sto.cine["actors"].has("bride") and sto.cine["actors"].has("groom"), "в ролике Юлия и Марк")
	check(sto.ui.choosing() and sto.ui.pills.get_child_count() == 3, "выбор: сад / таверна / позже")
	await frames(30)
	await shot("story_wedding_choice.png")
	(sto.ui.pills.get_child(0) as Button).pressed.emit()
	await play_through(12.0)
	await wait_kit(false, 4.0)
	var A: Dictionary = S["active"]
	check(String(A.get("id", "")) == "wedding" and String(A["flags"].get("choice", "")) == "garden" and int(A["step"]) == 1, "выбрали сад — шаг «пир»")
	if String(A.get("id", "")) != "wedding" or int(A["step"]) != 1:
		return
	check(c.research.has("s_wedding") and c.unlocked("rosearch") and String(c.events[-1]["text"]).contains("Арка из роз"), "арка из роз открыта сразу: «%s»" % c.events[-1]["text"])
	var info: Dictionary = sto.row_info()
	check(String(info["text"]).contains("8 цветов") and String((info["buttons"] as Array)[-1][0]) == "Лучше: пир в таверне", "строка сада и «Лучше: пир в таверне»: %s" % [info["buttons"].map(func(x): return x[0])])
	# ветка таверны (на копии): термополий в 25 м
	var g: Array = sto._step(A)["goal"]
	var a2 := A.duplicate(true)
	a2["flags"]["choice"] = "tavern"
	check(not bool(sto.progress(a2, g)["ok"]), "таверна: пока нет")
	var th := put("thermopolium", bp + Vector2(10, 4))
	check(not th.is_empty() and bool(sto.progress(a2, g)["ok"]), "таверна: термополий в 25 м — пир есть")
	check(not bool(sto.progress(A, g)["ok"]), "сад: ещё не готов")
	# сад: 8 цветов и арка
	var fl := ["flowers", "planter", "bush", "flowers_2", "planter_2", "bush_2", "flowers", "planter"]   # третьи облики — в «Саду» (этап 5)
	for i in 8:
		deco(fl[i], bp + Vector2(cos(i * 0.8), sin(i * 0.8)) * 6.0)
	sto.tick()
	check(int(A["step"]) == 1 and String(sto.row_info()["text"]).contains("Сейчас:"), "8 цветов, беседки нет — ждём (%s)" % sto.row_info()["text"])
	var ra := deco("rosearch", bp + Vector2(-7, 2))
	sto.tick()
	check(int(A["step"]) == 2, "арка из роз поставлена — шаг «дом молодым»")
	if not ra.is_empty():
		var rp0: Vector2 = ra["pos"]
		game.rig.set_view(Vector3(rp0.x, Land.BASE_Y, rp0.y), 20.0, 38.0, 9.0)
		await frames(50)
		await shot("story_rosearch.png")
	await frames(5)
	check(sto._glow != null and is_equal_approx(sto._glow_r, 30.0), "где строить новый дом — подсвечено (30 м)")
	# сохранение посреди шага
	var d: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	var c2 := City.new(game.land)
	c2.load_data(d)
	var A2: Dictionary = c2.stories["active"]
	check(String(A2.get("id", "")) == "wedding" and int(A2.get("step", -1)) == 2 and String(A2["flags"].get("choice", "")) == "garden" and A2.has("roles"),
		"после загрузки: свадьба, шаг «дом», выбран сад, роли на месте")
	# дом невесты перенесли — история с ним
	var old_id := int(bride_h["id"])
	check(game.start_move(bride_h), "дом невесты подняли")
	await frames(30)
	var moved := false
	cands.sort_custom(func(p, q): return p.distance_squared_to(bp + Vector2(0, -4)) < q.distance_squared_to(bp + Vector2(0, -4)))
	for p in cands.slice(0, 300):
		reset_place()
		var pl: Dictionary = game.placement("house_artisan", p)
		if pl["err"] == "" and pl["sub"] == "road":
			game.hover = p
			game._build_here()
			moved = game.moving.is_empty()
			break
	check(moved and int(A["home"]) != old_id and c.buildings.has(int(A["home"])), "дом поставили — история у нового места (%d → %d)" % [old_id, int(A["home"])])
	bride_h = c.buildings.get(int(A["home"]), bride_h)
	bp = bride_h["pos"]
	# новый дом: старые и плебейские не в счёт; заселённый — тоже
	var pl_h := put("house_pleb", bp + Vector2(-10, 6))
	sto.tick()
	check(int(A["step"]) == 2, "новый дом плебеев не в счёт")
	var full := put("house_artisan", bp + Vector2(12, -2))
	if not full.is_empty():
		settle(full, "Проба 9")
	sto.tick()
	check(int(A["step"]) == 2 and String(sto.row_info()["text"]).contains("заняли"), "новый дом заняли — нужен другой: «%s»" % sto.row_info()["text"])
	var nh := put("house_artisan", bp + Vector2(-12, -3))
	sto.tick()
	var nm := String(A.get("couple", ""))
	check(not nh.is_empty() and int(A["flags"].get("built", -1)) == int(nh["id"]) and int(nh["pop"]) == 2 and nm != "", "молодые поселились в новом доме: семья «%s»" % nm)
	var mem := []
	for r in game.people.residents:
		if r["fam"] == nm:
			mem.append(r)
	check(mem.size() == 2 and int(mem[0]["seed"]) == int(roles["groom"]["seed"]) and int(mem[1]["seed"]) == int(roles["bride"]["seed"]),
		"в городе — Марк и Юлия (тот же облик, что в роликах)")
	check(bool(A.get("ready", false)) and String(c.events[-1]["text"]).contains("поселились"), "колокольчик: «%s»" % c.events[-1]["text"])
	await frames(5)
	check(hud.badges.has("story"), "над домом невесты — «Готово»: посмотреть свадьбу")
	# свадьба: награда сразу, шествие вечером
	var happy0 := {}
	for id in c.buildings:
		if c.is_house(c.buildings[id]):
			happy0[id] = int(c.buildings[id]["happy"])
	hud.set_speed(2.0)
	var nl0: int = game.night_lights.size()
	hud._badge_click("story")
	check(sto.kit != null and (S["done"] as Dictionary).has("wedding"), "ролик свадьбы, история пройдена")
	var bon := {}
	for bb: Dictionary in S["bonus"]:
		if String(bb.get("id", "")) == "wedding":
			bon = bb
	var np: Vector2 = nh["pos"]
	check(int(bon.get("pct", 0)) == 6 and is_equal_approx(float(bon.get("r", 0)), 20.0) and int(bon.get("left", 0)) == 72
		and Vector2(float(bon.get("x", 0)), float(bon.get("z", 0))).distance_to(np) < 0.01, "домам в 20 м от нового дома +6%% на 3 дня (%s)" % bon)
	var wt := String(S["done"]["wedding"].get("text", ""))
	check(wt.contains("Арка из роз") and wt.contains("семья"), "в журнале: %s" % wt)
	c.compute()
	var wl := ""
	for pp: Array in nh["happy_parts"]:
		if String(pp[0]).begins_with("Свадьба Юлии и Марка"):
			wl = "%s %+d" % [pp[0], pp[1]]
	check(wl.contains("+6") and wl.contains("ещё 3"), "строка счастья: «%s»" % wl)
	var walked: bool = await wait_walk(12.0)
	check(walked and is_equal_approx(game.look_hour, Stories.DUSK) and sto.cine["actors"].size() == Stories.PROC.size(), "шествие: вечер, %d человек" % sto.cine.get("actors", {}).size())
	check((sto.cine.get("props", []) as Array).size() >= 1 and game.night_lights.size() > nl0, "у двери нового дома горят жаровни")
	# этап 4 (4.8): дерево между камерой шествия и парой прячется на время ролика (после ролика — на месте)
	var kc: Vector3 = sto.kit.pos
	var kl: Vector3 = sto.kit.look
	var tree_p := Vector2(lerpf(kc.x, kl.x, 0.45), lerpf(kc.z, kl.z, 0.45))
	game._add_nature("SM_Env_Tree_01", Transform3D(Basis.IDENTITY, Vector3(tree_p.x, game.land.height_at(tree_p.x, tree_p.y), tree_p.y)), tree_p)
	var tit: Dictionary = (game.nature[Vector2i(int(tree_p.x / 2.0), int(tree_p.y / 2.0))] as Array)[-1]
	var tree_h: Array = tit["h"]
	var t_scale := func() -> float: return ((tree_h[0][0]["subs"][0]["mm"]) as MultiMesh).get_instance_transform(int(tree_h[0][1])).basis.get_scale().length()
	# фонарь на луче камеры прячется вместе со своим светом (пятно света без фонаря не висит)
	var lamp_p := Vector2.INF
	for k in range(90, 40, -2):
		var t := k / 100.0
		var q := Vector2(lerpf(kc.x, kl.x, t), lerpf(kc.z, kl.z, t))
		var gy: float = game.land.height_at(q.x, q.y)
		var ry := lerpf(kc.y, kl.y, t)
		if q.distance_to(Vector2(kl.x, kl.z)) > 1.6 and ry > gy + 0.3 and ry < gy + 2.2 and game.land.occ_at(q) == 0:
			lamp_p = q
			break
	var lamp := {}
	var lamp_l: Array = []
	if lamp_p != Vector2.INF:
		lamp = c.place("lamp_post", lamp_p, 0.0, 0, 0, true)
		lamp_l = (game.visuals.get(int(lamp["id"]), {}) as Dictionary).get("lights", [])
		sto._trees_clear()                # сразу, пока камера шествия там же (через 0,2 с она уже сдвинется)
	await frames(30)
	check(t_scale.call() < 1e-6, "дерево между камерой шествия и парой спрятано на время ролика")
	var lamp_dark := not lamp_l.is_empty()
	for l in lamp_l:
		if game.night_lights.has(l) or (l as Node3D).visible:
			lamp_dark = false
	check(lamp_dark, "фонарь на луче камеры спрятан вместе со своим светом (огней: %d)" % lamp_l.size())
	await frames(150)
	await shot("story_wedding_proc.png")
	var oh: float = game.land.height_at(208.0, 116.0)
	print("  камера шествия: вариант ", sto.cine.get("proc", {}).get("cam_i"), " из ", Stories.PROC_CAMS.size(),
		"; луч в чистом поле: ", sto._clear_view3(Vector3(203, oh + 2.3, 116), Vector3(209, oh + 1.0, 116)), " occ=", game.land.occ_at(Vector2(206, 116)))
	var pr: Dictionary = sto.cine.get("proc", {})
	var s_mid := float(pr.get("s", 0))
	await frames(30)
	check(float(sto.cine.get("proc", {}).get("s", 0)) > s_mid, "шествие идёт к дому")
	var door_at: bool = await wait_beat("fx", 30.0)
	check(door_at, "дошли до двери")
	await frames(40)
	await shot("story_wedding_door.png")
	await play_through(30.0, "say", "story_wedding_say.png")
	var ended: bool = await wait_kit(false, 5.0)
	await frames(4)
	check(ended and is_equal_approx(game.look_hour, -1.0) and game.night_lights.size() == nl0 + lamp_l.size(), "ролик кончился: свет как был, жаровни убраны")
	check(t_scale.call() > 0.1, "ролик кончился — спрятанное дерево снова на месте")
	var lamp_back := not lamp_l.is_empty()
	for l in lamp_l:
		if not game.night_lights.has(l):
			lamp_back = false
	check(lamp_back, "и фонарь снова светит в свой час")
	game.remove_nature(tit)
	if not lamp.is_empty():
		c.remove(lamp, false)
	check(is_equal_approx(float(game.speed), 2.0), "скорость вернулась (×%s)" % game.speed)
	hud.set_speed(0.0)
	# пересмотр из журнала
	sto.replay("wedding")
	var rp: bool = await drive_until("proc", 40.0)
	await frames(20)
	press_key(KEY_ESCAPE)
	var rend: bool = await wait_kit(false, 5.0)
	check(rp and rend and is_equal_approx(game.look_hour, -1.0), "«Пересмотреть» свадьбу — шествие, Esc — всё как было")
	# через 3 дня бонус кончился
	for i in 72:
		c._story_hour()
	var still := false
	for bb: Dictionary in S["bonus"]:
		if String(bb.get("id", "")) == "wedding":
			still = true
	check(not still, "через 3 дня свадебный бонус кончился")


## Свадьба ещё раз: дом молодым построили сразу после выбора (до пира) — он в счёт; свадьба готова, а дом невесты снесли
## и семья уехала — награда не пропала; семья без дома — цели не меряем (ни пир, ни новый дом — от станции)
func _wedding_more() -> void:
	print("== свадьба: дом до пира, «Готово» не отнять, семья без дома")
	street(Vector2(212, 178), Vector2(212, 206))   # место под дома у квартала ремесленников
	c.level = 3
	fresh(2600, ["cat", "square"])
	var S := c.stories
	sto._tried = ""
	sto.tick()
	var o: Dictionary = S["offer"]
	check(String(o.get("id", "")) == "wedding", "свадьба предложена снова (невеста из семьи %s)" % o.get("fam"))
	if o.is_empty():
		return
	var n0: int = c.next_id
	sto.accept("garden")
	var A: Dictionary = S["active"]
	check(int(A["flags"].get("after", -1)) == n0 and int(A["step"]) == 1, "выбрали сад — «новый дом» считается с этой минуты")
	var bh: Dictionary = c.buildings[int(A["home"])]
	var bp: Vector2 = bh["pos"]
	# дом молодым — сразу, ещё до пира
	var nh := put("house_artisan", bp)
	var nd: float = (nh.get("pos", Vector2.INF) as Vector2).distance_to(bp)
	sto.tick()
	print("  дом до пира: %s в %.1f м, шаг %d" % [nh.get("id"), nd, int(A["step"])])
	var fl := ["flowers", "planter", "bush", "flowers_2", "planter_2", "bush_2", "flowers", "planter"]   # третьи облики — в «Саду» (этап 5)
	for i in 8:
		deco(fl[i], bp + Vector2(cos(i * 0.8 + 0.3), sin(i * 0.8 + 0.3)) * 6.5)
	deco("pergola" if c.unlocked("pergola") else "rosearch", bp + Vector2(-6, -4))
	sto.tick()
	sto.tick()
	check(not nh.is_empty() and nd <= 30.0 and int(A["flags"].get("built", -1)) == int(nh["id"]) and String(A.get("couple", "")) != "" and bool(A.get("ready", false)),
		"пир готов — молодые сразу в доме, построенном до пира (семья «%s»)" % A.get("couple", ""))
	# всё готово, ролик ещё не смотрели: дом невесты снесли — «Посмотреть» на месте, сутки ждать не нужно
	var fam := String(A["fam"])
	c.remove(bh)
	await frames(3)
	sto.tick()
	await frames(3)
	var info: Dictionary = sto.row_info()
	var b0 := String((info.get("buttons", []) as Array)[0][0]) if not (info.get("buttons", []) as Array).is_empty() else ""
	check(not A.has("homeless") and b0 == "Посмотреть" and hud.badges.has("story"), "дом невесты снесли после свадебных хлопот — «Посмотреть» на месте («%s»), значок — над домом молодых" % b0)
	S["h"] = int(S["h"]) + Stories.WAIT_HOME_H + 1
	sto.tick()
	check(String(S["active"].get("id", "")) == "wedding" and bool(S["active"].get("ready", false)), "и через сутки свадьба ждёт, не прервалась")
	# семья невесты уехала из города, ролик так и не посмотрели — история всё равно пройдена, награда есть
	c.family_left.emit(int(bh["id"]), fam)
	var wb := false
	for bb: Dictionary in S["bonus"]:
		wb = wb or String(bb.get("id", "")) == "wedding"
	check((S["active"] as Dictionary).is_empty() and (S["done"] as Dictionary).has("wedding") and wb and String(c.events[-1]["text"]).contains("завершена"),
		"семья уехала до ролика — свадьба пройдена, +6%% у нового дома: «%s»" % c.events[-1]["text"])
	# семья без дома: пир и новый дом не меряем от станции (там таверна и новые дома) — ждём, пока семья заселится
	for id in c.buildings.keys():
		if String(c.buildings[id]["type"]) in ["thermopolium", "taberna"]:
			c.remove(c.buildings[id])        # прежние таверны — прочь: пир — только у станции
	street(Vector2(200, 86), Vector2(200, 122))
	c.level = 3
	fresh(2800, ["cat", "square"])
	S = c.stories
	sto._tried = ""
	sto.tick()
	o = S["offer"]
	check(String(o.get("id", "")) == "wedding", "свадьба ещё раз (семья %s)" % o.get("fam"))
	if o.is_empty():
		return
	sto.accept("tavern")
	A = S["active"]
	bh = c.buildings[int(A["home"])]
	fam = String(A["fam"])
	var st_p: Vector2 = c.center()["pos"]
	var th := put("thermopolium", st_p + Vector2(12, 4))
	var tp: Vector2 = th.get("pos", Vector2.INF)
	sto.tick()
	check(not th.is_empty() and tp.distance_to(st_p) <= 25.0 and tp.distance_to(bh["pos"]) > 25.0 and int(A["step"]) == 1,
		"термополий у станции (%.1f м), а дом невесты далеко — пир ещё не готов" % tp.distance_to(st_p))
	c.remove(bh)
	await frames(3)
	sto.tick()
	check(A.has("homeless") and int(A["step"]) == 1, "дом невесты снесли — пир у станции не засчитан (шаг %d)" % int(A["step"]))
	var h1 := put("house_artisan", tp + Vector2(0, 9))
	check(rehouse_fam(h1, fam), "семья заселилась в дом у термополия")
	sto.tick()
	check(not A.has("homeless") and int(A["home"]) == int(h1.get("id", -2)) and int(A["step"]) == 2, "история идёт: пир — в термополии рядом с новым домом, шаг «дом»")
	c.remove(h1)
	await frames(3)
	sto.tick()
	var nh2 := put("house_artisan", st_p + Vector2(18, 16))
	sto.tick()
	check(A.has("homeless") and not A.has("couple") and not (A["flags"] as Dictionary).has("built"), "семья снова без дома — новый дом у станции не засчитан, молодые не заселились")
	var h2 := put("house_artisan", tp + Vector2(0, -2))
	check(rehouse_fam(h2, fam), "семья заселилась снова")
	sto.tick()
	var built := int(A["flags"].get("built", -1))
	check(built == int(nh2.get("id", -2)) and built != int(h2.get("id", -3)) and String(A.get("couple", "")) != "",
		"история идёт: молодые — в новый дом %d (не в дом семьи невесты %d)" % [built, int(h2.get("id", -3))])


# ---------- лица вблизи: до и после ----------

func _faces() -> void:
	print("== лица: до и после")
	for k in [true, false]:
		Citizen.plain_faces = k
		fresh(3000 + (100 if k else 0))
		c.level = 1
		sto._tried = ""
		sto.tick()
		if (c.stories["offer"] as Dictionary).is_empty():
			check(false, "лица: нет предложения")
			break
		var hp: Vector2 = c.buildings[int(c.stories["offer"]["home"])]["pos"]
		game.rig.set_view(Vector3(hp.x + 2, Land.BASE_Y, hp.y + 3), 215.0, 38.0, 26.0)
		await frames(20)
		sto.open_offer()
		await wait_beat("say", 8.0)
		await frames(70)
		sto.ui.finish_typing()
		await frames(10)
		await shot("story_face_%s.png" % ("before" if k else "after"))
		press_key(KEY_ESCAPE)
		await wait_kit(false, 4.0)
		await frames(5)
	Citizen.plain_faces = false


## Ждать, пока шествие пойдёт (такт ["proc", "walk"]; sec — по часам роликов)
func wait_walk(sec: float) -> bool:
	var t0 := cine_t
	while cine_t - t0 < sec:
		if sto.cine.is_empty():
			return false
		var i := int(sto.cine.get("i", -1))
		var beats: Array = sto.cine.get("beats", [])
		if i >= 0 and i < beats.size() and String(beats[i][0]) == "proc" and String(beats[i][1]) == "walk":
			return true
		await get_tree().process_frame
	return false


## Вести ролик (реплики дальше, на выборе — первая кнопка), пока не дойдёт до такта kind
func drive_until(kind: String, sec: float) -> bool:
	var t0 := cine_t
	while sto.kit != null and cine_t - t0 < sec:
		await frames(6)
		if sto.cine.is_empty():
			continue
		var i := int(sto.cine.get("i", -1))
		var beats: Array = sto.cine.get("beats", [])
		if i < 0 or i >= beats.size():
			continue
		var bk := String(beats[i][0])
		if bk == kind:
			return true
		if bk in ["say", "choice"] and sto.cine.get("wait", false):
			sto.ui.finish_typing()
			await frames(3)
			sto._next()
		elif bk == "choice" and sto.ui.choosing():
			sto.ui.finish_typing()
			(sto.ui.pills.get_child(0) as Button).pressed.emit()
	return false


# ---------- этап 7: каркас учебных историй — новые цели и такты, стрелка, строки с ✓ ----------

## Состояние историй с нуля и без ослика и луж прежней истории
func fresh7(h: int, done := []) -> void:
	sto._drop_beast()
	sto.orders.S()
	fresh(h, done)
	sto._clicks_key = "-"
	sto._sync_clicks()


## Куда смотрит камера, чтобы щёлкнуть по точке мира (и где она на экране)
func screen_of(p: Vector2, y_up := 0.1) -> Vector2:
	var y: float = game.land.height_at(p.x, p.y)
	return game.rig.cam.unproject_position(Vector3(p.x, y + y_up, p.y))


func look_at_pt(p: Vector2, dist := 26.0) -> void:
	game.rig.set_view(Vector3(p.x, Land.BASE_Y, p.y), 200.0, 50.0, dist)
	await frames(12)


func _framework() -> void:
	print("== этап 7: каркас (новые цели, такты, стрелка)")
	var S := c.stories
	StoryDefs.extra = []
	# имена и название с семьёй
	check(StoryDefs.nomen_f("Корнелии") == "Корнелия" and StoryDefs.nomen_f("Помпеи") == "Помпея", "женское родовое имя: Корнелия, Помпея")
	check(StoryDefs.title_of(StoryDefs.story("crowded"), {"fam": "Фабии"}) == "Тесно у Фабиев" and StoryDefs.title_of(StoryDefs.story("crowded")) == "Тесно в доме" and Defs.unlock_text("s_crowded").contains("«Тесно в доме»"),
		"название с семьёй: «%s»" % StoryDefs.title_of(StoryDefs.story("crowded"), {"fam": "Фабии"}))
	check(StoryDefs.fill("{ref.crowded.elder}", {"refs": {"crowded": StoryDefs.ref_of({"fam": "Фабии"})}}) == "%s Фабий" % StoryDefs.elder("Фабии"),
		"имя из прошлой истории: «%s»" % StoryDefs.fill("{ref.crowded.elder}", {"refs": {"crowded": StoryDefs.ref_of({"fam": "Фабии"})}}))
	# порядок списка — порядок предложения (план 7.3): Мася, течь, скверик, ослик, тесно, свадьба
	var ids := []
	for sd: Dictionary in StoryDefs.STORIES:
		ids.append(String(sd["id"]))
	check(ids == ["cat", "bandits", "leak", "square", "donkey", "crowded", "wedding"], "порядок историй: %s" % [ids])
	for sd: Dictionary in StoryDefs.STORIES:
		check(String(sd.get("lesson", "")) != "", "«%s» говорит, чему учит (журнал): %s" % [sd["title"], sd.get("lesson", "")])
	# цели «красота», «игры», «победы Легиона» — на пробной записи истории
	var hp: Vector2 = kid_home["pos"]
	var a := {"id": "cat", "home": int(kid_home["id"]), "fam": kid_fam, "flags": {}, "t0": int(S["h"]), "id0": c.next_id}
	var bn := sto.beauty_near(hp, 15.0)
	var pr: Dictionary = sto.progress(a, ["beauty", 15.0, [bn + 1, bn + 6, bn + 12]])
	check(int(pr["tier"]) == 0 and int(pr["have"]) == bn, "красота: %d очков — ещё не бронза" % bn)
	c.research["deco_stone"] = true
	deco("statue", hp + Vector2(-8, 3))
	pr = sto.progress(a, ["beauty", 15.0, [bn + 1, bn + 6, bn + 12]])
	check(int(pr["tier"]) >= 1 and not bool(pr["ok"]), "красота: статуя рядом — %s, ждём «Готово»" % pr["txt"])
	var lw0: int = c.legion.progress
	c.legion.progress = 3
	check(sto.legion_wins(0) == 3 and bool(sto.progress(a, ["legion_win", 0, 2])["ok"]), "победы Легиона в первой провинции: %d" % sto.legion_wins(0))
	c.legion.progress = lw0
	# история-проба: шаг с открытием исследования (grant), стрелка на «Этаж» (point), потом «игры в честь богов»
	StoryDefs.extra = [{"id": "t_frame", "title": "Проба каркаса", "icon": "scroll", "lvl": 0, "pop": 0, "cast": {}, "who": "", "role": "",
		"steps": [{"id": "a", "cine": []},
			{"id": "b", "text": "Этаж", "goal": ["wait", 2], "point": ["tool", "floor"], "grant": ["floor2"]},
			{"id": "c", "text": "Игры", "goal": ["fest", 1]},
			{"id": "d", "text": "Жители", "goal": ["p", ["pop"], 99999], "label": "Жителей"}],
		"reward": {"rp": 1}, "line": "Проба"}]
	c.research.erase("floor2")
	fresh7(3200, ["cat", "leak", "square", "donkey", "crowded", "wedding"])
	S = c.stories
	sto._tried = ""
	sto.tick()
	check(String(S["offer"].get("id", "")) == "t_frame", "проба каркаса предложена (%s)" % S["offer"].get("id"))
	sto.accept()
	var A: Dictionary = S["active"]
	check(c.research.has("floor2") and String(c.events[-1]["text"]).contains("Открыто"), "шаг открыл исследование «Второй жилой этаж» (в колокольчике)")
	game.set_tool("")
	hud._update_pointer()
	check(sto.pointer_do().get("kind", "") == "floor" and hud.pointer_target == hud.tool_btns.get("floor"), "стрелка истории — на «Этаж»")
	S["h"] = int(S["h"]) + 2
	sto.tick()
	check(int(A["step"]) == 2, "ожидание кончилось — шаг «игры»")
	c.festival_changed.emit(true)
	sto.tick()
	check(int(A["step"]) == 3, "игры прошли — шаг засчитан")
	# строки с ✓ в золотой строке и стрелка к первой невыполненной (как у просьб горожан)
	var info: Dictionary = sto.row_info()
	var parts: Array = info.get("parts", [])
	check(parts.size() == 1 and String(parts[0]["text"]).begins_with("Жителей") and not bool(parts[0]["ok"]), "строка цели: «%s»" % (parts[0]["text"] if not parts.is_empty() else ""))
	hud.refresh()
	await frames(3)
	var row: Node = hud.tasks_box.find_child("story_row", true, false)
	var pv: Node = row.find_child("parts", true, false) if row != null else null
	check(pv != null and pv.get_child_count() == 1 and String((pv.get_child(0) as Button).text).begins_with("· Жителей"), "в свитке — строка с точкой (не выполнено)")
	hud._update_pointer()
	check(sto.pointer_do().get("kind", "") in ["build", "fam", "view"], "стрелка — к тому, что поднимет жителей (%s)" % sto.pointer_do().get("kind", ""))
	S["active"] = {}
	StoryDefs.extra = []
	# такт «если» помнит прошлые истории
	S["done"]["crowded"] = {"day": 0, "h": 1, "fam": "Фабии", "flags": {"choice": "neighbours"}}
	check(sto._cond("crowded") and sto._cond("crowded=neighbours") and not sto._cond("crowded=stay") and not sto._cond("t_none"),
		"«если»: тесно у Фабиев пройдено, дед у соседей")
	(S["done"] as Dictionary).erase("crowded")


# ---------- Д9 «Разбойники у арки»: телега у арки → «Легион» → Казармы в военном квартале → учебный бой → пост ----------

func _bandits() -> void:
	print("== разбойники у арки (Д9)")
	StoryDefs.extra = []
	var lg: Legion = c.legion
	var lu := LegionUi.of(hud)
	# город без Легиона, Хутор
	for id in c.buildings.keys():
		if String(c.buildings[id]["type"]) in sto.MILITARY:
			c.remove(c.buildings[id], false)
	c.research.erase("legion")
	c.research.erase("archery")
	c.research.erase("s_bandits")
	lg.flags = {}
	lg.progress = 0
	lg.stars = {}
	lg.upg = {}
	c.level = 1
	c.changed.emit()
	await frames(3)
	check(lu != null and lu.btn_wrap.visible and not lg.window_open() and lu.btn.tooltip_text.contains("Разбойники у арки") and lu.btn.get_node("ic").material != null,
		"медальон «Легион» виден с начала — серый, подсказка: «%s»" % (lu.btn.tooltip_text if lu != null else ""))
	check(Defs.unlock_text("legion").contains("Разбойники у арки") and c.can_research("legion").contains("Разбойники у арки") and not c.research_open("legion"),
		"Казармы и «Легион» — «%s»; в свитке за очки не изучить" % Defs.unlock_text("legion"))
	# первой — «Мася»; в обучении — ничего
	fresh7(4200, [])
	var S := c.stories
	sto._tried = ""
	sto.tick()
	check(String(S["offer"].get("id", "")) == "cat", "на «Хуторе» первой — «Где Мася?» (%s)" % S["offer"].get("id", ""))
	c.tips["tut"] = 4
	fresh7(4300, ["cat"])
	S = c.stories
	sto._tried = ""
	sto.tick()
	check((S["offer"] as Dictionary).is_empty(), "пока идёт обучение — историю не предлагают")
	c.tips["tut"] = -1
	# своя пауза после «Маси» (gap_h, владелец: Легион почти со старта): «Разбойники» — вскоре, а не через GAP_H
	var gh := int(StoryDefs.story("bandits")["gap_h"])
	var h0 := int(S["h"])
	var l0 := int(S["last_h"])
	S["h"] = maxi(h0, l0 + StoryDefs.GAP_H)
	S["last_h"] = int(S["h"]) - gh + 1
	var early := sto.time_ok()
	S["last_h"] = int(S["h"]) - gh
	var due := sto.time_ok()
	S["h"] = h0
	S["last_h"] = l0
	check(gh < StoryDefs.GAP_H and sto.gap_now() == gh and not early and due, "«Разбойники» — через %d ч после «Маси» (не %d): раньше нельзя, потом — пора" % [gh, StoryDefs.GAP_H])
	sto._tried = ""
	sto.tick()
	var o: Dictionary = S["offer"]
	check(String(o.get("id", "")) == "bandits", "после «Маси» — «Разбойники у арки» (%s)" % o.get("id", ""))
	if o.is_empty():
		return
	# ролик у арки: телега на обочине, переселенец рядом
	hud.advisor_panel.visible = false
	sto.open_offer()
	var said: bool = await wait_beat("say", 8.0)
	await frames(50)
	sto.ui.finish_typing()
	await frames(8)
	var act = sto.cine.get("actors", {}).get("settler")
	var ap := Vector2((act as Node3D).position.x, (act as Node3D).position.z) if act != null else Vector2.INF
	check(said and (sto.cine.get("props", []) as Array).size() >= 1 and ap.distance_to(Land.GATE) < 20.0,
		"ролик у арки: телега поставлена (%d), переселенец в %.1f м от арки" % [(sto.cine.get("props", []) as Array).size(), ap.distance_to(Land.GATE)])
	check(sto.ui.role_lbl.text.begins_with("переселенец"), "просит переселенец: %s, %s" % [sto.ui.name_lbl.text, sto.ui.role_lbl.text])
	await shot("story_bandits_ask.png")
	await play_through(25.0, "", "", "choice", "story_bandits_choice.png")
	await wait_kit(false, 4.0)
	await frames(4)
	var A: Dictionary = S["active"]
	check(String(A.get("id", "")) == "bandits" and int(A.get("step", -1)) == 1, "история идёт: шаг «Казармы»")
	check(c.research.has("legion") and lg.window_open() and bool(lg.flags.get("advised", false)), "шаг открыл «Легион» без очков; окно Легиона своего совета не скажет")
	check(String((S.get("granted", {}) as Dictionary).get("legion", "")) == "bandits", "записано, что «Легион» открыла эта история (%s)" % [S.get("granted")])
	var q: Array = lg.quarter()
	var qc := Vector2(float(q[0]), float(q[1])) if q.size() == 3 else Vector2.INF
	check(q.size() == 3 and qc.distance_to(Land.GATE) < 70.0 and game.land.is_owned(qc), "военный квартал у арки: %s (%.0f м от арки)" % [q, qc.distance_to(Land.GATE)])
	var ga: Array = sto._goal_area(A)
	check(ga.size() >= 3 and Vector2(float(ga[0]), float(ga[1])).distance_to(qc) < 0.1, "квартал подсвечен на земле (пятно, не кольцо)")
	# одна стрелка: обучение Легиону и история показывают на одно и то же — Казармы
	await frames(3)
	hud._update_pointer()
	var tut_t = lu.tut_pointer()[0]
	check(lu.tut_active() and hud.pointer_target != null and hud.pointer_target == tut_t and String(sto.pointer_do().get("type", "")) == "barracks",
		"одна стрелка — на Казармы (обучение Легиону; история показала бы туда же)")
	# советник: военный квартал, один раз
	hud.advisor_panel.visible = false
	sto.tick()
	check(c.tips.has("story_adv_bandits_barracks") and hud.adv_title.text == StoryDefs.ADV_LEGION and hud.adv_text.text.contains("Готового Легиона нет")
		and hud.adv_text.text.contains("Стрельбище") and hud.adv_text.text.contains("Улучшить") and hud.adv_text.text.contains("других городов"),
		"советник: «%s» — что такое Легион и что его строят сами" % hud.adv_title.text)
	await frames(10)
	get_viewport().get_texture().get_image().save_png(out + "story_bandits_advice.png")   # с советником (shot() его прячет)
	print("SHOT story_bandits_advice.png")
	hud.advisor_panel.visible = false
	# с Казармами в руках: в квартале ✓, вне его — можно и здесь
	game.set_tool("barracks")
	var zin: Array = sto.zone_note("barracks", qc)
	var zout: Array = sto.zone_note("barracks", qc + Vector2(60, 60))
	check(not zin.is_empty() and bool(zin[1]) and String(zin[0]).contains("военном квартале") and not zout.is_empty() and String(zout[0]).contains("здесь"),
		"у курсора: «%s» / «%s»" % [zin[0] if not zin.is_empty() else "", zout[0] if not zout.is_empty() else ""])
	await look_at_pt(qc, 38.0)
	sto._marks(true)
	await frames(30)
	await shot("story_bandits_quarter.png")
	game.set_tool("")
	# Казармы — прямо в середине квартала (там они встают: дорога у входа)
	c.money = 5000.0
	var bar := {}
	for yaw: float in [0.0, PI / 2.0, PI, -PI / 2.0]:
		if String(c.check_place("barracks", qc, yaw)["err"]) == "":
			bar = c.place("barracks", qc, yaw)
			game._show(bar)
			break
	check(not bar.is_empty() and float(Defs.B["barracks"]["cost"]) <= 600.0, "Казармы встают в середине квартала (%s), стоят %d ден." % [bar.get("pos"), int(Defs.B["barracks"]["cost"])])
	if bar.is_empty():
		bar = put("barracks", qc)
	await look_at_pt(qc, 30.0)
	await frames(20)
	await shot("story_bandits_barracks.png")
	sto.tick()
	check(bool(A.get("ready", false)) and int(A["step"]) == 2, "Казармы есть — ролик ждёт «Посмотреть»")
	sto.play_ready()
	await play_through(25.0)
	await wait_kit(false, 4.0)
	await frames(4)
	check(sto._goal_kind(A) == "legion_win", "шаг «учебный бой»")
	var info: Dictionary = sto.row_info()
	var bts: Array = info.get("buttons", [])
	check(not bts.is_empty() and String(bts[0][0]) == "В бой!", "в строке истории — «В бой!» (%s)" % [bts])
	# «В бой!» — учебный бой леса (3D-бой подделан: ловим сигнал)
	var got := []
	var cons: Array = lg.battle_requested.get_connections()
	for cn: Dictionary in cons:
		lg.battle_requested.disconnect(cn["callable"])
	var catch := func(s: Dictionary) -> void: got.append(s)
	lg.battle_requested.connect(catch)
	sto.press("battle")
	lg.battle_requested.disconnect(catch)
	for cn: Dictionary in cons:
		lg.battle_requested.connect(cn["callable"])
	check(got.size() == 1 and String(got[0].get("tutorial", "")) == "oil" and int(got[0]["stage"]["idx"]) == 0, "«В бой!» — учебный бой с маслом (бой 0-0-0)")
	if got.size() == 1:
		var m0 := c.money
		lg.apply_result(got[0], {"win": true, "alive": 3, "total": 3, "timeout": false, "time": 40.0})
		check(lg.progress == 1, "учебный бой выигран (деньги за бой: %+d)" % int(c.money - m0))
	sto.tick()
	check(bool(A.get("ready", false)), "бой выигран — последний ролик ждёт")
	c.rp = minf(c.rp, c.rp_cap() - 100.0)
	var rp0 := c.rp
	var gl0 := lg.glory
	var mon0 := c.money
	sto.play_ready()
	await play_through(30.0, "reward", "story_bandits_final.png")
	await wait_kit(false, 4.0)
	var et := String((S["done"] as Dictionary).get("bandits", {}).get("text", ""))
	check((S["done"] as Dictionary).has("bandits") and c.unlocked("legionpost") and c.rp >= rp0 + 29.0 and lg.glory >= gl0 + 4.9 and is_equal_approx(c.money, mon0) and not et.contains("ден"),
		"история пройдена: «Сторожевой пост», +очки, +Слава, денег нет (%s)" % et)
	var lp := deco("legionpost", qc + Vector2(0, -10))
	check(not lp.is_empty(), "сторожевой пост ставится")
	if not lp.is_empty():
		game._set_hour(19.5)
		game.rig.set_view(Vector3(lp["pos"].x, Land.BASE_Y, lp["pos"].y), 160.0, 32.0, 8.0)
		await frames(40)
		await shot("story_bandits_post.png")
		game._set_hour(10.5)
	# обучение Легиону, шаг 4 «Войска»: пока на улучшение не хватает денариев, стрелка не держит медальон — она у просьб
	lg.flags["seen"] = true
	lg.flags["tut_fought"] = true
	lg.flags.erase("tut")
	lg.upg = {}
	lg.levels["legionary"] = 1
	lu.visible = false
	c.money = 100.0
	var p_poor = lu.tut_pointer()[0]
	hud._update_pointer()
	var hp_poor = hud.pointer_target
	c.money = 5000.0
	var p_rich = lu.tut_pointer()[0]
	check(lg.tut_step() == "troops" and p_poor == null and hp_poor != lu.btn and p_rich == lu.btn,
		"шаг «Войска»: без денариев стрелка у просьб (%s), с денариями — на медальоне" % [hp_poor])
	lg.flags["tut"] = "done"
	# старый город с изученным Легионом — история не нужна
	fresh7(4400, ["cat"])
	S = c.stories
	sto._tried = ""
	sto.tick()
	check(String(S["offer"].get("id", "")) != "bandits", "Легион уже открыт — «Разбойников» не предлагают (%s)" % S["offer"].get("id", ""))
	# «Легион» открыла сама история, а потом она прервалась (семья уехала) — её предложат снова: Казармы и бой уже
	# засчитаны, награда («Сторожевой пост», очки, Слава) не пропадёт
	fresh7(4500, ["cat"])
	S = c.stories
	S["granted"] = {"legion": "bandits"}
	S["active"] = {"id": "bandits", "step": 3, "flags": {}, "home": -1}
	sto._cancel("Семья уехала из города.")
	check((S["active"] as Dictionary).is_empty() and not (S["done"] as Dictionary).has("bandits"), "история прервалась после «Легиона»")
	S["h"] = int(S["h"]) + StoryDefs.GAP_H
	sto._tried = ""
	sto.tick()
	check(String(S["offer"].get("id", "")) == "bandits", "прерванных «Разбойников» предлагают снова (%s)" % S["offer"].get("id", ""))
	var dj: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	check(String((City.stories_load(dj["stories"])["granted"] as Dictionary).get("legion", "")) == "bandits", "кто открыл «Легион» — сохраняется")
	S["offer"] = {}
	sto._marks(true)


# ---------- «Течь в водопроводе»: лужи вдоль улицы → мастер идёт к трубе → фонтан у 6 домов ----------

func _leak() -> void:
	print("== течь в водопроводе")
	StoryDefs.extra = []
	c.level = 2
	c.research["fountain"] = true
	fresh7(3400, ["cat"])
	var S := c.stories
	sto._tried = ""
	sto.tick()
	var o: Dictionary = S["offer"]
	check(String(o.get("id", "")) == "leak", "Деревня, изучены фонтаны — «Течь в водопроводе» (%s)" % o.get("id"))
	if o.is_empty():
		return
	var info: Dictionary = sto.row_info()
	check(String(info.get("text", "")).begins_with(StoryDefs.nomen_f(String(o["fam"]))), "золотая строка: «%s»" % info.get("text"))
	hud.advisor_panel.visible = false
	sto.open_offer()
	var said: bool = await wait_beat("say", 6.0)
	await frames(60)
	sto.ui.finish_typing()
	await frames(8)
	check(said and sto.ui.name_lbl.text == StoryDefs.nomen_f(String(o["fam"])) and sto.ui.role_lbl.text.begins_with("хозяйка"), "просит хозяйка: %s, %s" % [sto.ui.name_lbl.text, sto.ui.role_lbl.text])
	await shot("story_leak_ask.png")
	await play_through(20.0)
	await wait_kit(false, 4.0)
	var A: Dictionary = S["active"]
	check(sto._goal_kind(A) == "click" and (A.get("clicks", []) as Array).size() == 3 and (A.get("at", []) as Array).size() == 2, "шаг «лужи»: три лужи, последняя — у трубы")
	if sto._goal_kind(A) != "click":
		return
	await frames(5)
	check(sto._clicks.size() == 3, "лужи и труба — в мире (%d)" % sto._clicks.size())
	var cl: Array = A["clicks"]
	var door: Vector2 = c.door_point(c.buildings[int(A["home"])])
	var d0 := Vector2(float(cl[0][0]), float(cl[0][1])).distance_to(door)
	var d2 := Vector2(float(cl[2][0]), float(cl[2][1])).distance_to(door)
	check(d2 > d0 and game.land.is_road(Vector2(float(cl[2][0]), float(cl[2][1]))), "лужи уводят вдоль улицы от дома: %.1f → %.1f м" % [d0, d2])
	var mid := (Vector2(float(cl[0][0]), float(cl[0][1])) + Vector2(float(cl[2][0]), float(cl[2][1]))) * 0.5
	await look_at_pt(mid, 22.0)
	await frames(30)
	await shot("story_leak_puddles.png")
	# через 4 часа — значки над лужами
	S["h"] = int(S["h"]) + 4
	sto.tick()
	await frames(3)
	check(hud.badges.has(Stories.CLICK_HINT + "0") and hud.badges.has(Stories.CLICK_HINT + "2"), "через 4 ч над лужами — значки с каплей")
	# щелчки по двум лужам
	for i in 2:
		var mp := screen_of(Vector2(float(cl[i][0]), float(cl[i][1])))
		check(sto.near_cat(mp), "лужа %d под курсором — «рука»" % i)
		check(sto.try_click(mp), "щелчок по луже %d засчитан" % i)
		await frames(4)
	check(int(sto.progress(A, sto._step(A)["goal"])["have"]) == 2 and sto._goal_kind(A) == "click", "найдено 2 из 3 — ищем дальше")
	# сохранение посреди шага: лужи помнят, какие найдены
	var data = JSON.parse_string(JSON.stringify(c.save_data()))
	var ld := City.stories_load(data["stories"])
	var lcl: Array = ld["active"].get("clicks", [])
	check(lcl.size() == 3 and int(lcl[0][2]) == 1 and int(lcl[2][2]) == 0, "после сохранения: найдены первые две, труба — нет")
	# труба: ролик — мастер идёт к ней настоящими улицами
	var mp2 := screen_of(Vector2(float(cl[2][0]), float(cl[2][1])))
	check(sto.try_click(mp2) and sto.kit != null, "нашли трубу — ролик с мастером")
	var snap = JSON.parse_string(JSON.stringify(c.save_data()))   # окно закрыли посреди ролика (автосохранение то же)
	var walking: bool = await drive_until("walk", 20.0)
	check(walking, "мастер пошёл к трубе")
	if walking:
		var pl = sto.cine["actors"].get("plumber")
		var spot := Vector2(float(cl[2][0]), float(cl[2][1]))
		var dw0: float = Vector2((pl as Node3D).position.x, (pl as Node3D).position.z).distance_to(spot)
		await get_tree().create_timer(1.2).timeout
		await shot("story_leak_walk.png")
		var dw1: float = Vector2((pl as Node3D).position.x, (pl as Node3D).position.z).distance_to(spot)
		check(dw1 < dw0 - 0.5, "мастер идёт к трубе: %.1f → %.1f м" % [dw0, dw1])
	await play_through(40.0, "fx", "story_leak_fix.png")
	await wait_kit(false, 4.0)
	await frames(4)
	check(bool(A.get("fixed", false)) and sto._clicks.is_empty() and sto._goal_kind(A) == "p", "течь заделана: лужи ушли, шаг «фонтан у 6 домов»")
	# загрузка сохранения посреди ролика с мастером: ролик снова ждёт щелчка (значок над домом, «Посмотреть»), лужи на месте
	var lst := City.stories_load(snap["stories"])
	check(sto._step(lst["active"]).has("cine") and not bool(lst["active"].get("ready", false)), "сохранено посреди ролика: шаг-ролик (%s)" % lst["active"].get("step"))
	c.stories = lst
	S = c.stories
	A = S["active"]
	sto._restore()
	sto._clicks_key = "-"
	sto._sync_clicks()
	info = sto.row_info()
	var bts: Array = info.get("buttons", [])
	check(bool(A.get("ready", false)) and not bts.is_empty() and String(bts[0][0]) == "Посмотреть" and sto._clicks.size() == 3,
		"после загрузки — «Посмотреть», лужи и труба снова в мире (%s, луж %d)" % [bts, sto._clicks.size()])
	sto._marks(true)
	check(hud.badges.has("story"), "после загрузки над домом — значок «Готово»")
	# ролик пропустили Esc до «заделал»: течь всё равно заделана, лужи не вернутся
	sto.play_ready()
	var restarted: bool = await wait_kit(true, 3.0)
	await frames(10)
	sto._skip()
	await wait_kit(false, 6.0)
	await frames(4)
	check(restarted and sto._goal_kind(A) == "p" and bool(A.get("fixed", false)) and sto._clicks.is_empty(), "ролик пропущен — течь заделана, лужи ушли, шаг «фонтан»")
	# стрелка и строка: фонтана нет — карточка фонтана; советник объяснил воду один раз
	hud.advisor_panel.visible = false
	sto.tick()
	check(c.tips.has("story_adv_leak_water") and hud.adv_title.text == "Фонтаны и вода", "советник: «%s»" % hud.adv_title.text)
	hud.advisor_panel.visible = false
	var pdo := sto.pointer_do()
	check(String(pdo.get("type", "")) == "fountain", "стрелка — к фонтану (%s)" % pdo)
	info = sto.row_info()
	check(not (info.get("parts", []) as Array).is_empty() and String(info["parts"][0]["text"]).begins_with("Дома плебеев у фонтана"), "строка: «%s»" % info.get("parts", [{}])[0].get("text", ""))
	# фонтан посреди домов плебеев
	var fp := Vector2(186, 147)
	var f := put("fountain", fp)
	c.compute()
	var near: int = c.progress_of(["near", "fountain", "plebs"])
	check(not f.is_empty() and near >= 6, "фонтан поставлен — у фонтана %d домов плебеев" % near)
	hud.set_overlay("water")
	await frames(6)
	var ns: Array = game.cover.sets.get("n", [0, 0, 0])
	check(int(ns[0]) >= 6 and hud._ov_title.text == "Вода", "«Обзор → Вода»: с водой %d домов, без — %d" % [int(ns[0]), int(ns[2])])
	await look_at_pt(fp, 40.0)
	await frames(20)
	await shot("story_leak_water.png")
	hud.set_overlay("")
	sto.tick()
	check(bool(A.get("ready", false)), "шаг выполнен — ждём «Посмотреть»")
	await frames(3)
	check(sto._clicks.is_empty(), "последний ролик ждёт — лужи и труба не вернулись")
	c.rp = minf(c.rp, c.rp_cap() - 200.0)
	var rp0 := c.rp
	sto.play_ready()
	var rp1 := c.rp                        # награда — сразу, как начался последний ролик
	await play_through(40.0, "reward", "story_leak_final.png")
	await wait_kit(false, 4.0)
	var et := String((S["done"] as Dictionary).get("leak", {}).get("text", ""))
	check((S["done"] as Dictionary).has("leak") and c.research.has("s_leak") and c.unlocked("nymphfountain"), "история пройдена — открыт «Фонтан с нимфой»")
	check(rp1 >= rp0 + 109.0 and not et.contains("ден"), "награда без денег: %s" % et)
	var nf := deco("nymphfountain", fp + Vector2(0, -9))
	check(not nf.is_empty(), "фонтан с нимфой ставится")


# ---------- «Ослик возчика»: найти ослика → лавка у дома торгует (склад рядом) → ослик везёт товар ----------

func _donkey() -> void:
	print("== ослик возчика")
	c.level = 2
	c.research["warehouse"] = true
	c.research["butcher"] = true
	for id in c.buildings.keys():
		if String(c.buildings[id]["type"]) in ["butcher", "bakery", "warehouse"]:
			c.remove(c.buildings[id])
	fresh7(3600, ["cat", "leak", "square"])
	var S := c.stories
	sto._tried = ""
	sto.tick()
	var o: Dictionary = S["offer"]
	check(String(o.get("id", "")) == "donkey", "изучен склад — «Ослик возчика» (%s)" % o.get("id"))
	if o.is_empty():
		return
	# у дома возчика ни мясной лавки, ни пекарни и места под них нет — историю не предлагаем (её не пройти без сноса);
	# лавка рядом уже стоит — предлагаем и в тесноте
	var hp0: Vector2 = c.buildings[int(o["home"])]["pos"]
	sto.works_room = 1 << 30               # «вокруг всё застроено»
	check(sto.can_offer(StoryDefs.story("donkey")).is_empty(), "негде поставить лавку у дома возчика — ослика не предлагаем")
	var bu0 := put("butcher", hp0 + Vector2(6, 4))
	var ok0 := not sto.can_offer(StoryDefs.story("donkey")).is_empty()
	if not bu0.is_empty():
		c.remove(bu0)
	c.compute()
	sto.works_room = 40
	check(not bu0.is_empty() and ok0, "мясная лавка у дома уже стоит — ослика предлагаем и в тесноте")
	sto.accept()
	var A: Dictionary = S["active"]
	check(sto._goal_kind(A) == "find" and not sto.beast.is_empty() and sto.cat.is_empty(), "ослик спрятался (не кошка)")
	if sto.beast.is_empty():
		return
	var bp: Vector2 = sto.beast["p"]
	var dd := bp.distance_to(c.door_point(c.buildings[int(A["home"])]))
	check(dd >= 11.5 and dd <= 41.0, "ослик в %.1f м от двери" % dd)
	sto.meow()
	await look_at_pt(bp, 14.0)
	await frames(30)
	await shot("story_donkey_hide.png")
	# сохранение и загрузка: ослик снова на месте
	sto._drop_beast()
	sto._restore()
	check(not sto.beast.is_empty() and (sto.beast["p"] as Vector2).distance_to(bp) < 0.01, "после загрузки ослик там же")
	var mp := screen_of(bp, 0.55)
	check(sto.near_cat(mp), "над осликом — «рука»")
	check(sto.try_click(mp) and sto.kit != null, "щёлкнули по ослику — ролик встречи")
	var snap = JSON.parse_string(JSON.stringify(c.save_data()))   # окно закрыли посреди ролика встречи
	# «И-а!» — в медальоне сам Пузан (ослик в три четверти), не рисунок плебея
	var said: bool = await wait_beat("say", 10.0)
	await frames(40)
	sto.ui.finish_typing()
	await frames(10)
	check(said and sto.ui.name_lbl.text == "Пузан" and sto.ui.face_tex.texture is ViewportTexture, "говорит Пузан — в медальоне ослик (%s, %s)" % [sto.ui.name_lbl.text, sto.ui.face_tex.texture])
	await shot("story_donkey_face.png")
	await play_through(30.0, "fx", "story_donkey_found.png")
	await wait_kit(false, 4.0)
	await frames(3)
	sto.tick()
	check(sto._goal_kind(A) == "works" and sto.beast.is_empty(), "встретились — ослик ушёл с хозяином, шаг «лавка у дома»")
	# загрузка сохранения посреди встречи: ролик ждёт «Посмотреть», ослик снова в мире; пропуск — шаг «лавка у дома»
	var lst := City.stories_load(snap["stories"])
	c.stories = lst
	S = c.stories
	A = S["active"]
	sto._drop_beast()
	sto._restore()
	var bts: Array = sto.row_info().get("buttons", [])
	check(bool(A.get("ready", false)) and not bts.is_empty() and String(bts[0][0]) == "Посмотреть" and not sto.beast.is_empty(),
		"после загрузки — «Посмотреть», Пузан на месте (%s)" % [bts])
	sto.play_ready()
	var restarted: bool = await wait_kit(true, 3.0)
	await frames(10)
	sto._skip()
	await wait_kit(false, 6.0)
	await frames(3)
	sto.tick()
	check(restarted and sto._goal_kind(A) == "works" and sto.beast.is_empty(), "ролик пропущен — шаг «лавка у дома», ослик ушёл с хозяином")
	# лавки нет — строка и стрелка к мясной лавке
	var info: Dictionary = sto.row_info()
	var parts: Array = info.get("parts", [])
	check(parts.size() == 1 and String(parts[0]["text"]) == "Мясная лавка или пекарня у дома (в 30 м): нет", "строка: «%s»" % (parts[0]["text"] if not parts.is_empty() else ""))
	check(String(sto.pointer_do().get("type", "")) == "butcher", "стрелка — к мясной лавке")
	# у истории своё место (лавка у дома), а взят заказ старосты: с фонарём в руках у курсора — «в счёт заказа»,
	# светится место заказа, следов лапок к нему нет
	var ord: StoryOrders = sto.orders
	var oc0: Dictionary = (S["orders"] as Dictionary).duplicate(true)
	S["orders"]["cur"] = "o_lamps"
	S["orders"]["taken"] = false
	ord.take()
	var oan: Vector2 = ord.anchor_pos(ord.cur())
	game.set_tool("lamp_post")
	var zl: Array = sto.zone_note("lamp_post", oan + Vector2(6, 0))
	sto._marks(true)
	check(not zl.is_empty() and String(zl[0]) == "В счёт заказа ✓" and sto._glow != null and sto._glow_edge and is_equal_approx(sto._glow_r, 25.0) and sto._paws.is_empty(),
		"шаг «лавка», заказ взят: у курсора «%s», светится место заказа (r=%.0f), следов лапок нет (%d)" % [zl, sto._glow_r, sto._paws.size()])
	game.set_tool("")
	S["orders"] = oc0
	sto._marks(true)
	# мясная лавка у дома, склада нет — «нет склада рядом», стрелка — к складу
	var hp: Vector2 = c.buildings[int(A["home"])]["pos"]
	var bu := put("butcher", hp + Vector2(6, 4))
	c.compute()
	sto.tick()
	info = sto.row_info()
	parts = info.get("parts", [])
	var bdist: float = (bu.get("pos", Vector2.INF) as Vector2).distance_to(hp)
	check(not bu.is_empty() and bdist <= 30.0 and not parts.is_empty() and String(parts[0]["text"]).contains("нет склада рядом"), "лавка в %.1f м — «%s»" % [bdist, parts[0]["text"] if not parts.is_empty() else ""])
	check(String(sto.pointer_do().get("type", "")) == "warehouse", "стрелка — к складу (%s)" % sto.pointer_do())
	await frames(3)
	hud.refresh()
	await frames(3)
	await shot("story_donkey_row.png")
	# склад рядом с лавкой — лавка торгует
	var wh := put("warehouse", (bu.get("pos", hp) as Vector2) + Vector2(-8, 6))
	c.compute()
	sto.tick()
	check(not wh.is_empty() and String(c.buildings.get(int(bu.get("id", -1)), {}).get("why", "?")) == "" and bool(A.get("ready", false)),
		"склад рядом — лавка торгует, ждём «Посмотреть» (почему нет: «%s»)" % c.buildings.get(int(bu.get("id", -1)), {}).get("why", "?"))
	check(int(A["flags"].get("shop", -1)) == int(bu.get("id", -2)), "ослик повезёт товар к этой лавке")
	sto.play_ready()
	var walking: bool = await drive_until("walk", 20.0)
	check(walking and sto.cine["actors"].has("donkey"), "ослик с поклажей идёт со склада к лавке")
	if walking:
		await get_tree().create_timer(1.5).timeout
		await shot("story_donkey_haul.png")
	await play_through(40.0)
	await wait_kit(false, 4.0)
	check((S["done"] as Dictionary).has("donkey") and c.unlocked("donkeypost"), "история пройдена — открыт «Ослик у коновязи»")
	var dp := deco("donkeypost", hp + Vector2(0, -16))
	await frames(4)
	var pets: Array = (game.visuals.get(int(dp.get("id", -1)), {}) as Dictionary).get("pets", [])
	check(not dp.is_empty() and pets.size() == 1 and pets[0] is Stories.Beast, "у коновязи жуёт ослик")
	if not dp.is_empty():
		game.rig.set_view(Vector3(dp["pos"].x, Land.BASE_Y, dp["pos"].y), 160.0, 35.0, 7.0)
		await frames(40)
		await shot("story_donkeypost.png")


# ---------- «Тесно у Валериев»: счастье 75% и третий этаж → выбор про деда → балкон с бельём ----------

func _crowded() -> void:
	print("== тесно у валериев")
	c.level = 3
	c.research["floor2"] = true
	c.research["floor3"] = true
	# дом в два этажа, полный, — его семья попросит
	var h := put("house_pleb", Vector2(176, 168))
	if h.is_empty():
		check(false, "дом для «Тесно» не поставился")
		return
	h["tier"] = 2
	settle(h, "Валерии")
	game._show(h)
	c.compute()
	fresh7(3800, ["cat", "leak", "square", "donkey"])
	var S := c.stories
	sto._tried = ""
	sto.tick()
	var o: Dictionary = S["offer"]
	check(String(o.get("id", "")) == "crowded" and int(o.get("home", -1)) == int(h["id"]), "Посёлок, третий этаж изучен — «Тесно у Валериев» у дома в 2 этажа (%s, %s)" % [o.get("id"), o.get("fam")])
	if String(o.get("id", "")) != "crowded":
		return
	check(String(sto.row_info().get("title", "")) == "Тесно у Валериев", "название с семьёй: «%s»" % sto.row_info().get("title"))
	sto.accept()
	var A: Dictionary = S["active"]
	sto.tick()
	var info: Dictionary = sto.row_info()
	var parts: Array = info.get("parts", [])
	check(parts.size() == 2 and String(parts[0]["text"]).begins_with("Счастье дома") and String(parts[1]["text"]).begins_with("Этажей 2/3"),
		"строки: «%s» · «%s»" % [parts[0]["text"] if parts.size() > 0 else "", parts[1]["text"] if parts.size() > 1 else ""])
	var hv := int(c.buildings[int(h["id"])].get("happy", 0))
	if hv < 75:
		check(String(parts[0]["text"]).contains("не хватает"), "чего не хватает до 75%%: «%s»" % parts[0]["text"])
		game.set_tool("")
		sto.part_click(parts[0])
		check(game.tool != "" or hud.overlay != "" or hud.research_panel.visible, "щелчок по строке — нужное в руках (%s)" % game.tool)
		game.set_tool("")
		hud.set_overlay("")
		hud.close_panels()
	hud.advisor_panel.visible = false
	hud.refresh()
	await frames(3)
	await look_at_pt(h["pos"], 26.0)
	await frames(20)
	await shot("story_crowded_row.png")
	# счастье: украшения вокруг (зона красоты дома, у курсора — «В счёт красоты дома ✓»)
	game.set_tool("flowers")
	var zn: Array = sto.zone_note("flowers", (h["pos"] as Vector2) + Vector2(5, 0))
	check(not zn.is_empty() and String(zn[0]) == "В счёт красоты дома ✓", "у курсора: «%s»" % [zn])
	# у истории своя цель (красота дома — любое украшение), а взят заказ старосты: фонарь у станции — «в счёт заказа»
	var oc0: Dictionary = (S["orders"] as Dictionary).duplicate(true)
	S["orders"]["cur"] = "o_lamps"
	S["orders"]["taken"] = false
	sto.orders.take()
	var oan: Vector2 = sto.orders.anchor_pos(sto.orders.cur())
	var zo: Array = sto.zone_note("lamp_post", oan + Vector2(6, 0))
	var zh: Array = sto.zone_note("flowers", (h["pos"] as Vector2) + Vector2(5, 0))
	check(not zo.is_empty() and String(zo[0]) == "В счёт заказа ✓" and not zh.is_empty() and String(zh[0]) == "В счёт красоты дома ✓",
		"история и заказ разом: фонарь у станции — «%s», клумба у дома — «%s»" % [zo, zh])
	S["orders"] = oc0
	game.set_tool("")
	for i in 6:
		deco(["flowers", "tree", "bush", "planter", "flowers_2", "tree_2"][i], (h["pos"] as Vector2) + Vector2(cos(i * 1.05), sin(i * 1.05)) * 6.0)
	c.compute()
	if int(c.buildings[int(h["id"])]["happy"]) < 75:
		# не хватило — праздник у дома (как награда истории): проверке нужно 75%
		(S["bonus"] as Array).append({"id": "t_happy", "line": "Проба", "pct": 75 - int(c.buildings[int(h["id"])]["happy"]) + 2, "home": int(h["id"]), "left": 200})
		c.compute()
	sto.tick()
	parts = sto.row_info().get("parts", [])
	check(parts.size() == 2 and bool(parts[0]["ok"]) and not bool(parts[1]["ok"]), "счастье ≥ 75%% ✓, этаж — ещё нет (%d%%)" % int(c.buildings[int(h["id"])]["happy"]))
	var why := c.can_buy_floor(c.buildings[int(h["id"])])
	check(why == "", "третий этаж можно надстроить (%s)" % why)
	c.buy_floor(c.buildings[int(h["id"])])
	c.compute()
	sto.tick()
	check(bool(A.get("ready", false)), "дом в 3 этажа — ждём «Посмотреть»")
	# последний ролик: выбор — дед к соседям
	sto.play_ready()
	var chose: bool = await drive_until("choice", 25.0)
	while chose and not sto.ui.choosing():
		sto.ui.finish_typing()
		await frames(3)
	check(chose and sto.ui.pills.get_child_count() == 2, "выбор про деда: остаться или к соседям")
	if chose:
		await frames(20)
		await shot("story_crowded_choice.png")
		(sto.ui.pills.get_child(1) as Button).pressed.emit()
	await play_through(30.0)
	await wait_kit(false, 4.0)
	var e: Dictionary = (S["done"] as Dictionary).get("crowded", {})
	check(String((e.get("flags", {}) as Dictionary).get("choice", "")) == "neighbours", "выбор запомнен: дед у соседей")
	var area := false
	for b: Dictionary in S["bonus"]:
		area = area or (String(b.get("id", "")) == "crowded" and b.has("x"))
	check(area and String(e.get("text", "")).contains("домам в 18 м") and c.unlocked("balcony"), "награда по выбору: соседям +3%% (%s), открыт балкон с бельём" % e.get("text", ""))
	sto.ui.open_journal()
	await frames(3)
	var jt := ""
	for l: Label in hud.journal_panel.find_children("*", "Label", true, false):
		jt += l.text + "\n"
	check(jt.contains("Дед перебрался к соседям") and jt.contains("Урок: Этажи"), "в журнале — выбор и урок")
	hud.close_panels()
	check(sto._cond("crowded=neighbours"), "свадьба вспомнит деда (такт «если»)")
	# балкон с бельём — на дом в 2–3 этажа (одноэтажный — нельзя)
	var one := put("house_pleb", Vector2(184, 176))
	var pl1: Dictionary = game._wall_place("balcony", (one.get("pos", Vector2.ZERO) as Vector2) + City.facing(float(one.get("yaw", 0.0))) * 1.5)
	var pl3: Dictionary = game._wall_place("balcony", (h["pos"] as Vector2) + City.facing(float(h["yaw"])) * 1.5)
	check(String(pl1.get("err", "")) == "Балкон вешается на дом в 2–3 этажа" and String(pl3.get("err", "?")) == "",
		"балкон: на одноэтажный — «%s», на дом в 3 этажа — можно («%s»)" % [pl1.get("err", ""), pl3.get("err", "?")])
	if String(pl3.get("err", "?")) == "":
		var bb := c.place("balcony", pl3["pos"], pl3["yaw"], pl3["variant"], pl3["color"])
		bb["host"] = pl3["host"]
		bb["y"] = pl3["y"]
		game._show(bb)
		await look_at_pt(h["pos"], 12.0)
		await frames(30)
		await shot("story_balcony.png")


# ---------- «Заказы старосты»: строка по желанию, в счёт — поставленное после «Взяться», награда без денег ----------

func _orders() -> void:
	print("== заказы старосты")
	var S := c.stories
	fresh7(4000, ["cat", "leak", "square", "donkey", "crowded", "wedding"])
	S = c.stories
	var ord: StoryOrders = sto.orders
	c.level = 0
	S["orders"] = {}                       # fresh() уже тикнул на «Посёлке» — заказы с нуля
	sto.tick()
	check(ord.row_info().is_empty(), "на «Стоянке» заказов нет")
	if c.count_type("scriptorium") == 0:
		put("scriptorium", c.center()["pos"] + Vector2(-14, 10))   # место заказа «Все три дерева у скриптория»
	c.level = 1
	c.tips.erase("orders_tip")
	# первый заказ приходит, когда советник занят (совет «Город стал Хутором!» после ролика ранга): объяснение — потом
	hud.advisor("Проба", "Советник занят другим.")
	sto.tick()
	var info: Dictionary = ord.row_info()
	check(String(S["orders"].get("cur", "")) == "o_lamps" and bool(info.get("waiting", false)) and String((info["buttons"] as Array)[0][0]) == "Взяться",
		"«Хутор»: заказ «%s» ждёт, кнопка «Взяться»" % info.get("text", ""))
	check(not c.tips.has("orders_tip"), "советник был занят — объяснение заказов ждёт")
	hud.advisor_panel.visible = false
	print("  советник свободен=", hud._tip_free(), " ролик=", sto.kit != null)
	sto.tick()
	check(c.tips.has("orders_tip") and hud.adv_title.text == "Заказы старосты", "советник освободился — один раз объяснил заказы («%s»)" % hud.adv_title.text)
	hud.advisor_panel.visible = false
	hud.refresh()
	await frames(3)
	check(hud.tasks_box.find_child("order_row", true, false) != null, "строка заказа — в «Просьбах горожан»")
	# сам не открывается: 30 игровых часов — камера на месте, окон нет, заказ не взят
	var pose0: Array = game.rig.pose()
	for i in 30:
		c._story_hour()
		sto.tick()
	await frames(3)
	var pose1: Array = game.rig.pose()
	check((pose1[0] as Vector3).distance_to(pose0[0]) < 0.3 and not ord.taken() and not hud.info_panel.visible and not hud.research_panel.visible and not hud.advisor_panel.visible
		and String(S["orders"].get("cur", "")) == "o_lamps", "30 ч без щелчка — камера не двигалась, окон нет, заказ ждёт (камера %.2f, взят %s, карточка %s, исследования %s, советник «%s» %s, заказ %s)" 		% [(pose1[0] as Vector3).distance_to(pose0[0]), ord.taken(), hud.info_panel.visible, hud.research_panel.visible, hud.adv_title.text, hud.advisor_panel.visible, S["orders"].get("cur", "")])
	# свёрнутый свиток — золотая точка
	game.settings["tasks_folded"] = true
	hud._fill_tasks()
	check(hud.tasks_box.find_child("story_dot", true, false) != null, "свиток свёрнут — на нём золотая точка (заказ ждёт)")
	game.settings["tasks_folded"] = false
	hud._fill_tasks()
	# «Взяться»: в счёт — поставленное после; у курсора — в счёт ли
	var anchor: Vector2 = ord.anchor_pos(ord.cur())
	deco("lamp_post", anchor + Vector2(8, 8))
	ord.take()
	var parts: Array = ord.row_info().get("parts", [])
	check(ord.taken() and parts.size() == 2 and String(parts[0]["text"]) == "Фонари на столбах 0/3", "взялись: «%s» (фонарь до «Взяться» не в счёт)" % (parts[0]["text"] if parts.size() > 0 else ""))
	game.set_tool("lamp_post")
	var zn: Array = sto.zone_note("lamp_post", anchor + Vector2(6, 0))
	var zf: Array = sto.zone_note("lamp_post", anchor + Vector2(40, 0))
	check(not zn.is_empty() and String(zn[0]) == "В счёт заказа ✓" and not zf.is_empty() and String(zf[0]) == "Далеко от станции — не в счёт", "у курсора: «%s» / «%s»" % [zn, zf])
	sto._marks(true)
	check(sto._glow != null and sto._glow_edge, "с фонарём в руках — край места заказа светится")
	game.set_tool("")
	# щелчок по строке — фонарь в руках и камера к месту
	ord.part_click(parts[0])
	check(game.tool == "lamp_post", "щелчок по строке заказа — фонарь в руках")
	game.set_tool("")
	await frames(10)
	await shot("story_order_taken.png")
	var m0 := c.money
	for i in 3:
		deco("lamp_post", anchor + Vector2(cos(i * 2.0 + 0.4), sin(i * 2.0 + 0.4)) * 9.0)
	for i in 2:
		deco("bench", anchor + Vector2(cos(i * 2.5 + 1.2), sin(i * 2.5 + 1.2)) * 11.0)
	c.compute()
	var m1 := c.money
	c.rp = minf(c.rp, c.rp_cap() - 100.0)
	var rp0 := c.rp
	var gl0: int = c.legion.glory
	sto.tick()
	check(String(S["orders"].get("cur", "")) == "" and int(S["orders"]["n"].get("o_lamps", 0)) == 1, "заказ выполнен")
	check(is_equal_approx(c.money, m1) and c.rp >= rp0 + 14.0 and c.legion.glory == gl0 + 1, "награда: +%d очков, +%d Славы, денег — 0 (стройка стоила %d)" % [int(c.rp - rp0), c.legion.glory - gl0, int(m0 - m1)])
	check(String(c.events[-1]["text"]).begins_with("Заказ старосты выполнен"), "в колокольчике: «%s»" % c.events[-1]["text"])
	# следующий — через час
	sto.tick()
	check(String(S["orders"].get("cur", "")) == "", "сразу следующего нет")
	S["h"] = int(S["h"]) + StoryOrders.GAP_H
	sto.tick()
	check(String(S["orders"].get("cur", "")) == "o_trees", "через час — следующий: «%s»" % ord.cur().get("title", ""))
	# «Другой заказ» — следующий сразу, этот — потом
	ord.skip()
	sto.tick()
	check(String(S["orders"].get("cur", "")) == "o_well", "«Другой заказ» — «%s»" % ord.cur().get("title", ""))
	# первый раз за этот заказ — редкий облик
	ord.take()
	deco("well", anchor + Vector2(-9, 6))
	for i in 4:
		deco("flowers", anchor + Vector2(-6 + i * 1.6, -9))
	c.compute()
	sto.tick()
	check(c.research.has("o_well") and c.unlocked("lamp_post_4") and String(c.events[-1]["text"]).contains("Фонарь с двумя кашпо"), "награда — редкое украшение «Фонарь с двумя кашпо»")
	# второй круг — вдвое больше и вдвое щедрее, без облика
	S["orders"]["n"] = {"o_lamps": 1, "o_trees": 1, "o_well": 1}
	S["orders"]["skip"] = {}
	S["orders"]["done_h"] = {}             # с прошлого раза прошло больше двух суток
	S["orders"]["cur"] = ""
	S["h"] = int(S["h"]) + 2
	sto.tick()
	var cu := ord.cur()
	var need: Array = ord.need_of(cu)
	var rw := ord.reward_of(cu)
	check(String(cu.get("id", "")) == "o_lamps" and int(need[0][1]) == 6 and int(rw["rp"]) == 30 and int(rw["glory"]) == 2 and not rw.has("unlock"),
		"второй круг: «%s» — фонарей %d, +%d очков, +%d Славы" % [ord.row_info().get("text", ""), int(need[0][1]), int(rw["rp"]), int(rw["glory"])])
	# повтор не ферма: сделанный заказ снова — не раньше чем через двое суток, на втором круге следующий — через 6 ч
	ord.complete()
	var h1 := int(S["h"])
	check(int(S["orders"]["done_h"].get("o_lamps", -1)) == h1 and int(S["orders"].get("gap", 0)) == StoryOrders.REPEAT_GAP_H,
		"повтор сделан: следующий заказ — через %d ч" % int(S["orders"].get("gap", 0)))
	S["h"] = h1 + StoryOrders.GAP_H
	sto.tick()
	check(String(S["orders"].get("cur", "")) == "", "через час после повтора — заказа ещё нет")
	S["h"] = h1 + StoryOrders.REPEAT_GAP_H
	sto.tick()
	check(String(S["orders"].get("cur", "")) == "o_trees", "через 6 ч — другой заказ: «%s» (сделанный только что — не он)" % ord.cur().get("title", ""))
	S["h"] = h1 + StoryOrders.REPEAT_GAP_H + 10
	ord.complete()                         # повтор делали 10 ч, как обычно, — следующий через час
	check(int(S["orders"].get("gap", 0)) == StoryOrders.GAP_H, "повтор строили 10 ч — следующий через %d ч" % int(S["orders"].get("gap", 0)))
	S["orders"]["cur"] = ""
	S["orders"]["done_h"] = {"o_lamps": h1, "o_trees": h1, "o_well": h1}
	check(ord.next_order().is_empty(), "все заказы «Хутора» сделаны только что — нового нет")
	S["h"] = h1 + StoryOrders.REPEAT_H
	check(not ord.next_order().is_empty(), "через двое суток — заказы снова есть («%s»)" % ord.next_order().get("title", ""))
	# заменить деревянные скамьи мраморными: пока стоит деревянная — не выполнено
	c.level = 3
	S["orders"]["cur"] = "o_benches"
	S["orders"]["taken"] = false
	deco("bench_2", anchor + Vector2(10, -6))
	ord.take()
	for i in 3:
		deco("bench", anchor + Vector2(-10 + i * 3.0, 10))
	c.compute()
	check(not ord.done() and ord.extra(ord.cur()) >= 1, "деревянная скамья ещё стоит — не выполнено")
	# у курсора: мраморная — в счёт, деревянная — «не в счёт» (она мешает), полукруглая — ни к чему
	var zb: Array = sto.zone_note("bench", anchor + Vector2(6, 0))
	var zw: Array = sto.zone_note("bench_2", anchor + Vector2(6, 0))
	var zs: Array = sto.zone_note("bench_3", anchor + Vector2(6, 0))
	check(not zb.is_empty() and String(zb[0]) == "В счёт заказа ✓" and not zw.is_empty() and not bool(zw[1]) and String(zw[0]) == "Деревянная скамья — не в счёт"
		and (zs.is_empty() or not bool(zs[1])), "скамьи у курсора: мраморная «%s», деревянная «%s», полукруглая %s" % [zb, zw, zs])
	sto._flash_clear()
	var wb := deco("bench_2", anchor + Vector2(12, 4))
	sto.flash_counted(wb)
	var zoks := 0
	for k in hud.badges:
		if String(k).begins_with("zok"):
			zoks += 1
	check(zoks == 0, "поставили деревянную — ✓ не мигают (%d)" % zoks)
	sto._flash_clear()
	if not wb.is_empty():
		c.remove(wb)
	parts = ord.row_info().get("parts", [])
	check(String(parts[-1]["text"]).contains("снесите"), "строка: «%s»" % parts[-1]["text"])
	S["orders"]["cur"] = ""
	S["orders"]["taken"] = false
	# старое сохранение без заказов грузится
	var old := {"h": 5, "last_h": -1, "done": {}, "active": {}, "offer": {}, "later": {}, "bonus": [], "pets": []}
	var ld := City.stories_load(old)
	check(typeof(ld.get("orders")) == TYPE_DICTIONARY and (ld["orders"] as Dictionary).is_empty(), "старое сохранение: заказов нет — появятся сами")
