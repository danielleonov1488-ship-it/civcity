extends Node
## Спокойный темп, честная казна и сильный герой (решения владельца 26.10):
##  1) «Хутор» не разом: новый ранг — передышка Stories.OFFER_GAP_H часов, новая история или заказ старосты — не в один
##     час с прошлым новым; первый заказ на «Хуторе» — когда «Где Мася?» пройдена (или через ORDER_WAIT_H); «Разбойники
##     у арки» — через свою паузу после «Маси»; сделанную просьбу новая сменяет через REQ_GAP_H; советы — не подряд
##     (Hud.TIP_GAP_MS, только в своей игре); колокольчик: что игрок сделал сам (изучил, надстроил) — без числа на значке,
##     венки летописи за час — одной строкой, обновки кошек за день — одной строкой;
##  2) казна в минус не уходит: жалованье и содержание сверх казны — казна 0, «Жалованье не плачено» в счастье домов,
##     красная строка над казной, строка в «Финансах» и истории денег, советник один раз; траты отказывают, если мало;
##  3) герой не слабее легионера, которого заменил, ни на каком уровне Казарм и города (походы и бои с городами).
##   bash .work/py/gpu_run.sh res://test_calm.tscn [-- shots=1]   — в конце «CALM DONE fails=0»; снимки — .work/gd/a/calm_*.png

const STREETS := [[Vector2(172, 136), Vector2(198, 136)], [Vector2(172, 150), Vector2(198, 150)], [Vector2(172, 164), Vector2(198, 164)]]

var game
var c: City
var hud
var sto
var fails := 0
var cands: Array = []
var houses: Array = []
var shots := false


func shot(name: String) -> void:
	if not shots or DisplayServer.get_name() == "headless":
		return
	await frames(8)
	DirAccess.make_dir_recursive_absolute("D:/CivCity/.work/gd/a")
	var p := "D:/CivCity/.work/gd/a/calm_%s.png" % name
	get_viewport().get_texture().get_image().save_png(p)
	print("CALM SHOT ", p)


func _ready() -> void:
	shots = "shots=1" in OS.get_cmdline_user_args()
	Game.boot = {"new": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, what: String, got: Variant = null) -> void:
	print(("CALM PASS " if ok else "CALM FAIL ") + what + ("" if got == null or ok else "  → %s" % str(got)))
	if not ok:
		fails += 1


func reset() -> void:
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
		reset()
		var pl: Dictionary = game.placement(type, p)
		if pl["err"] == "" and pl["sub"] == "road":
			return c.place(type, pl["pos"], pl["yaw"], pl["variant"], pl["color"])
	return {}


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	c = game.city
	hud = game.hud
	sto = game.stories
	game.can_save = false
	game.speed = 0.0
	game.tutorial.step = Tutorial.STEPS.size()
	game.tutorial.card.visible = false
	c.tips["tut"] = -1
	c.tips["ui"] = 3
	hud.apply_reveal(3)
	await frames(5)
	c.money = 1e5
	for s: Array in STREETS:
		street(s[0], s[1])
	for i in 6:
		var h := put("house_pleb", Vector2(176 + i * 4, 140))
		if not h.is_empty():
			houses.append(h)
			c.settled(int(h["id"]), 4, "Проба %d" % i)
	put("stall_fruit", Vector2(185, 150))
	put("scriptorium", Vector2(190, 160))
	c.compute()
	check(houses.size() >= 5 and int(c.stats["pop"]) >= 20, "город для проверки: %d домов, %d жителей" % [houses.size(), int(c.stats["pop"])])
	await _treasury()
	await _sinks()
	await _pace()
	await _bell()
	_hero()
	print("CALM DONE fails=%d" % fails)
	get_tree().quit()


# ---------- 2) казна в минус не уходит ----------

func _treasury() -> void:
	print("== казна пуста — жалованье не плачено")
	var h: Dictionary = houses[0]
	c.compute()
	var happy0 := int(h["happy"])
	var e00 := c.events.size()
	_broke_hour()
	var hp: Array = h.get("happy_parts", [])
	var line := hp.filter(func(p): return String(p[0]) == "Жалованье не плачено")
	check(c.money >= 0.0 and c.money < 0.01, "казна на нуле, не в минусе (%.2f)" % c.money)
	check(c.unpaid_h == Defs.UNPAID_H and c.unpaid_n == 1 and float(c.stats.get("unpaid", 0.0)) > 0.0, "жалованье не плачено: обида %d ч, не плачено %.1f ден." % [c.unpaid_h, float(c.stats.get("unpaid", 0.0))])
	check(line.size() == 1 and int(line[0][1]) == -Defs.UNPAID_HAPPY, "в карточке дома — «Жалованье не плачено −%d%%»" % Defs.UNPAID_HAPPY, hp)
	check(int(h["happy"]) == maxi(0, happy0 - Defs.UNPAID_HAPPY), "счастье дома −%d%% (%d → %d)" % [Defs.UNPAID_HAPPY, happy0, int(h["happy"])])
	var empt := c.events.slice(e00).filter(func(e): return String(e["text"]).begins_with("Казна пуста"))
	check(empt.size() == 1, "в колокольчике — «Казна пуста…»: «%s»" % (String(empt[0]["text"]).left(90) if not empt.is_empty() else ""))
	check((c.stats["happy_parts"] as Array).any(func(p): return String(p[0]) == "Жалованье не плачено"), "и в счастье города — строка «Жалованье не плачено»")
	var iu := Defs.HIST_KEYS.find("unpaid")
	check(iu >= 0 and int(c.hist[-1][iu]) > 0 and hud.day_line().contains("Не плачено"), "история денег: не плачено %d ден.; «%s»" % [int(c.hist[-1][iu]) if iu >= 0 else -1, hud.day_line()])
	hud.refresh()
	check(hud.empty_money.visible and hud.empty_money.text == "Казна пуста — жалованье не плачено", "над казной красным: «Казна пуста — жалованье не плачено»")
	if shots:
		hud.advisor_panel.visible = false
		game.rig.set_view(Vector3(186, 2, 150), 20, 55, 40)
		game.select_building(h)
		hud.open_info(h)
		await shot("unpaid_house_card")
		hud.close_panels()
	hud.advisor_panel.visible = false
	hud._tip_next = 0
	hud._once_tips()
	check(hud.advisor_panel.visible and hud.adv_title.text == "Казна пуста" and hud.adv_text.text.contains("налог") and c.tips.has("unpaid_tip"),
		"советник объясняет один раз, как поправить: «%s»" % hud.adv_text.text.left(120))
	await shot("unpaid_advisor")
	hud.advisor_panel.visible = false
	hud._fill_finance()
	hud._toggle(hud.finance_panel)
	await frames(2)
	await shot("unpaid_finance")
	var ft := _texts(hud.finance_panel)
	check(ft.contains("Казна пуста — не плачено за час"), "в «Финансах» — строка «Казна пуста — не плачено за час»")
	hud.finance_panel.visible = false
	# второй час без денег — снова 0, строка в колокольчике одна (обида держится)
	var ev0 := c.events.size()
	_broke_hour()
	check(c.money >= 0.0 and c.unpaid_n == 2 and c.events.slice(ev0).filter(func(e): return String(e["text"]).begins_with("Казна пуста")).is_empty(), "второй час — казна снова 0, новой строки «Казна пуста» нет")
	# казна снова платит: красная строка гаснет сразу, обида в домах держится ещё UNPAID_H − 1 ч (как и сказано в текстах)
	c.money = 5000.0
	c.sim_day()
	c.compute()
	hud.refresh()
	check(c.unpaid_h == Defs.UNPAID_H - 1 and not hud.empty_money.visible, "час оплачен — красной строки над казной нет (обида ещё %d ч)" % c.unpaid_h)
	check((h.get("happy_parts", []) as Array).any(func(p): return String(p[0]) == "Жалованье не плачено"), "в карточке дома обида ещё держится")
	hud._fill_finance()
	await frames(1)                          # старые строки «Финансов» уходят в конце кадра
	ft = _texts(hud.finance_panel)
	check(not ft.contains("Казна пуста — не плачено за час") and ft.contains("Жители ещё обижены за жалованье"), "в «Финансах» — не «не плачено: 0», а «Жители ещё обижены»")
	check(hud.unpaid_note().contains("ещё %d ч после того" % (Defs.UNPAID_H - 1)), "советник честно говорит, сколько держится обида")
	for i in Defs.UNPAID_H - 1:
		c.sim_day()
	c.compute()
	check(c.unpaid_h == 0 and not (h.get("happy_parts", []) as Array).any(func(p): return String(p[0]) == "Жалованье не плачено"), "казна платит %d ч — обида прошла" % Defs.UNPAID_H)
	hud.refresh()
	check(not hud.empty_money.visible, "красной строки над казной больше нет")
	# Сатурналии, день отдыха: налогов нет по выбору игрока — казна встаёт на 0, но без обиды и без «поднимите налоги»
	var n_un := c.unpaid_n
	ev0 = c.events.size()
	c.money = 0.01
	c.stories["tax_off"] = 1
	c.sim_day()
	c.compute()
	hud.refresh()
	var since := c.events.slice(ev0)
	check(c.money == 0.0 and c.unpaid_h == 0 and c.unpaid_n == n_un and not hud.empty_money.visible, "день отдыха: казна 0, обиды нет (обида %d ч), красной строки нет" % c.unpaid_h)
	check(not (h.get("happy_parts", []) as Array).any(func(p): return String(p[0]) == "Жалованье не плачено"), "в карточке дома — без «Жалованье не плачено»")
	check(since.filter(func(e): return String(e["text"]).begins_with("Казна пуста")).is_empty() and since.filter(func(e): return String(e["text"]).begins_with("Сатурналии: в день отдыха")).size() == 1,
		"в колокольчике — «Сатурналии: в день отдыха налогов нет…», а не «Казна пуста»")
	# сохранение: обида, счётчик и просьбы по одной — в файле; старое сохранение с долгом — казна с нуля
	c.unpaid_h = 2
	c.goals_vis = 1
	var d: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	var c2 := City.new(Land.new())
	c2.load_data(d)
	check(c2.unpaid_h == 2 and c2.unpaid_n == c.unpaid_n, "обида и счётчик сохраняются (%d, %d)" % [c2.unpaid_h, c2.unpaid_n])
	check(c2.goals_vis == 1 and c2.active_goals(3).size() <= 1, "просьбы по одной — и после загрузки (видно %d)" % c2.active_goals(3).size())
	d["money"] = -509.6
	d.erase("unpaid_h")
	d.erase("goals_vis")
	var c3 := City.new(Land.new())
	c3.load_data(d)
	check(c3.money == 0.0 and c3.unpaid_h == 0, "старое сохранение с долгом −509 — казна 0 (%.1f)" % c3.money)
	check(c3.goals_vis == 3, "старое сохранение — просьбы три сразу, как было")
	c.unpaid_h = 0
	c.goals_vis = 3
	c.compute()


## Час, когда налогов не хватает на жалованье и содержание: казна «ниже нуля» на входе — только так проверка
## получает недоплату, не трогая жителей и постройки (в игре казна в минус не уходит)
func _broke_hour() -> void:
	c.money = -10000.0
	c.sim_day()


func _texts(n: Node) -> String:
	var out := ""
	for l in n.find_children("*", "Label", true, false):
		out += (l as Label).text + "\n"
	return out


## Каждая трата отказывает, если денариев меньше цены (и казна не уходит в минус)
func _sinks() -> void:
	print("== траты при пустой казне")
	c.money = 1.0
	reset()
	var pl: Dictionary = game.placement("stall_fruit", Vector2(186, 158))
	check(String(pl["err"]).begins_with("Не хватает"), "лавка за 1 ден.: «%s»" % pl["err"])
	pl = game.placement("bench", Vector2(186, 158))
	check(String(pl["err"]).begins_with("Не хватает") or float(Defs.B["bench"]["cost"]) <= 1.0, "украшение: «%s»" % pl["err"])
	var h: Dictionary = houses[1]
	var t0 := int(h["tier"])
	c.research["floor2"] = true
	check(not c.buy_floor(h) and int(h["tier"]) == t0 and c.money == 1.0, "этаж за 1 ден. — нет (%s)" % c.can_buy_floor(h))
	c.research["artisans"] = true
	var ty := String(h["type"])
	check(not c.upgrade_house(h) and String(h["type"]) == ty and c.money == 1.0, "«Перестроить» за 1 ден. — нет (%s)" % c.can_upgrade(h))
	var lv := c.level
	c.level = int(Defs.FESTIVAL["lvl"])
	c.fest_cd = 0
	check(c.can_festival().begins_with("Не хватает") and not c.festival() and c.money == 1.0, "игры в честь богов — нет: «%s»" % c.can_festival())
	c.level = lv
	var pp := Vector2i(-99, -99)
	for p: Vector2i in [Vector2i(1, 1), Vector2i(4, 1), Vector2i(1, 2), Vector2i(4, 2), Vector2i(2, 0), Vector2i(3, 4)]:
		if c.can_buy(p):
			pp = p
			break
	check(pp.x > -99 and not c.buy_plot(pp) and c.money == 1.0, "участок земли за 1 ден. — нет")
	check(c.legion._afford_text({"money": 100}) == "Не хватает денариев" and c.legion.can_build_wonder("circus") != "", "Легион: улучшение и чудо — «Не хватает денариев»")
	# провиант после боя: пока шёл бой, казна опустела — платим, сколько есть, не в минус
	var st: Dictionary = c.legion.stage_info(0, 0, 0)
	var su: Dictionary = c.legion.make_battle(st, 7)
	su["food"] = 500
	c.money = 120.0
	c.legion.apply_result(su, {"win": false, "alive": 0, "total": 3, "timeout": false, "time": 30.0, "hp_left": 0.0})
	check(c.money >= 0.0 and c.money < 0.01, "провиант 500 при казне 120 — казна 0, не в минусе (%.1f)" % c.money)
	# кисть мостовой без денариев — ни клетки
	c.money = 0.0
	game.set_tool("road")
	game.painting = true
	game.stroke = []
	game.stroke_cost = 0.0
	game._paint_at(Vector2(205, 180))
	check(game.stroke.is_empty() and c.money == 0.0, "мостовая при пустой казне — не ложится")
	game.painting = false
	game.set_tool("")
	# история просит сбор: денариев мало — не платится
	check(c.money >= 0.0, "казна после всех трат — не в минусе (%.1f)" % c.money)
	c.money = 1e5


# ---------- 1) спокойный темп ----------

func _pace() -> void:
	print("== «Хутор» не разом")
	sto.force = true
	sto.pace_on = true                       # спокойный темп — как в своей игре (игра здесь не главная сцена)
	var S: Dictionary = c.stories
	S["done"] = {}
	S["offer"] = {}
	S["active"] = {}
	S["later"] = {}
	S["last_h"] = -1
	S["pace"] = {}
	S["orders"] = {}
	S["h"] = 20
	c.level = 1
	c.level_up.emit(1)                     # новый ранг — передышка
	check(int(sto.pace().get("h", -1)) == 20 and not sto.pace_ok(), "новый ранг: новое — не сразу (pace %s)" % sto.pace())
	check(not sto.time_ok(), "история сразу после нового ранга — не предлагается")
	sto._tried = ""
	sto.tick()
	check((S["offer"] as Dictionary).is_empty() and String((S["orders"] as Dictionary).get("cur", "")) == "", "в час нового ранга — ни истории, ни заказа")
	S["h"] = 20 + Stories.OFFER_GAP_H
	check(sto.pace_ok() and sto.time_ok(), "через %d ч после ранга — история может прийти" % Stories.OFFER_GAP_H)
	# первый заказ на «Хуторе» ждёт «Масю»
	var od: StoryOrders = sto.orders
	S["orders"] = {}
	check(not od.first_ok(int(S["h"])), "первый заказ на «Хуторе» — пока «Где Мася?» не пройдена, нет")
	check(not od.first_ok(int(S["h"]) + Stories.ORDER_WAIT_H - 1), "…и через %d ч ещё нет" % (Stories.ORDER_WAIT_H - 1))
	check(od.first_ok(int(S["h"]) + Stories.ORDER_WAIT_H), "через %d ч — заказ придёт, даже если «Масю» отложили" % Stories.ORDER_WAIT_H)
	S["orders"] = {}
	S["done"]["cat"] = {"h": int(S["h"]), "day": c.day}
	S["last_h"] = int(S["h"])
	check(od.first_ok(int(S["h"])), "«Где Мася?» пройдена — первый заказ можно")
	# заказ пришёл — история не в тот же час
	sto.pace_mark()
	check(not sto.time_ok(), "в час нового заказа — история не приходит")
	# «Разбойники у арки» — своей паузой после «Маси»
	check(sto.gap_now() == mini(StoryDefs.GAP_H, int(StoryDefs.story("bandits").get("gap_h", 99))), "после «Маси» — своя пауза «Разбойников» (%d ч)" % sto.gap_now())
	S["h"] = int(S["h"]) + maxi(sto.gap_now(), Stories.OFFER_GAP_H)
	check(sto.time_ok(), "«Разбойники у арки» — когда пауза прошла (на «Хуторе»)")
	# «Другой заказ» — следующий сразу, по щелчку, даже когда история вот-вот (и не в один час с ней)
	(S["orders"] as Dictionary)["cur"] = "o_lamps"
	sto.pace_mark()
	var lh0 := int(S["last_h"])
	S["last_h"] = int(S["h"]) - sto.gap_now() + 1      # история — через час
	check(sto.story_soon(int(S["h"])), "история вот-вот придёт")
	od.skip()
	var cur_o := String((S["orders"] as Dictionary).get("cur", ""))
	if cur_o != "":
		check((S["offer"] as Dictionary).is_empty() and not (S["orders"] as Dictionary).has("now"), "«Другой заказ» — следующий сразу, по щелчку: «%s»" % od.cur().get("title", ""))
	else:
		check(not (S["orders"] as Dictionary).has("now"), "«Другой заказ»: заменить нечем — следующий придёт в спокойном темпе (флаг снят)")
	sto._tried = ""
	sto.tick()
	check((S["offer"] as Dictionary).is_empty(), "история — не в один час с заказом (заказ «%s»)" % cur_o)
	S["last_h"] = lh0
	S["orders"] = {}
	# просьбы — по одной
	print("== просьбы по одной")
	c.goals_done = []
	c.goals_vis = 3
	sto._pace_requests()
	check(c.goal_pace, "своя игра с «Хутора» — просьбы по одной")
	var before: Array = c.active_goals(3).map(func(g): return String(g["id"]))
	c._check_goals()
	var done_n := c.goals_done.size()
	check(done_n >= 1 and c.goals_vis == maxi(1, 3 - done_n), "сделали %d — на их место новые не сразу (видно %d)" % [done_n, c.goals_vis])
	check(c.active_goals(3).size() == c.goals_vis, "в свитке просьб — %d строк" % c.active_goals(3).size())
	var h0 := int(S["h"])
	sto._pace_requests()
	check(c.goals_vis == maxi(1, 3 - done_n), "в тот же час новой просьбы нет")
	S["h"] = h0 + Stories.REQ_GAP_H
	sto.pace_mark()
	var v0: int = c.goals_vis
	sto._pace_requests()
	check(c.goals_vis == v0, "в час истории или заказа — новой просьбы нет")
	S["h"] = h0 + Stories.REQ_GAP_H + 1
	var d0 := c.goals_done.size()
	sto._pace_requests()
	# новая просьба пришла (или сразу засчиталась — уже сделана — и её место снова ждёт)
	check(c.goals_vis >= v0 + 1 or c.goals_vis == 3 or c.goals_done.size() > d0, "через %d ч — новая просьба (видно %d, сделано ещё %d)" % [Stories.REQ_GAP_H, c.goals_vis, c.goals_done.size() - d0])
	print("  было %s, сделано %d, видно теперь %s" % [before, done_n, c.active_goals(3).map(func(g): return String(g["id"]))])
	# не своя игра — сразу три
	sto.force = false
	sto.tick()
	check(not c.goal_pace and c.goals_vis == 3, "автопроверка (истории выключены) — просьбы как раньше, три сразу")
	sto.force = true
	# советы — не подряд
	print("== советы не подряд")
	hud.tip_gap = true
	hud.advisor("Проба", "первый совет")
	hud.advisor_panel.visible = false
	check(not hud._tip_free(), "закрыли совет — следующий сам не приходит сразу")
	check(hud._tip_free(false), "совет по действию игрока (взял инструмент, открыл «Обзор») — сразу")
	hud._tip_next = Time.get_ticks_msec() - 1
	check(hud._tip_free(), "через %d с — можно" % (Hud.TIP_GAP_MS / 1000))
	hud.tip_gap = false
	hud.advisor("Проба", "второй")
	hud.advisor_panel.visible = false
	check(hud._tip_free(), "в автопроверках — советы подряд, как раньше")
	sto.pace_on = false
	S["pace"] = {"h": int(S["h"])}
	check(sto.pace_ok() and sto.orders.first_ok(int(S["h"])), "в автопроверках историй — без передышек, как раньше")
	sto.force = false


# ---------- колокольчик ----------

func _bell() -> void:
	print("== колокольчик без лишнего")
	for g in Defs.REQUESTS:
		if String(g["id"]) == "research1" and not c.goals_done.has("research1"):
			c.goals_done.append("research1")   # просьба «Изучите что-нибудь» — не в счёт этой проверки
	var b0: int = hud.bell_count
	var n0 := c.events.size()
	c.rp = 5000.0
	var rid := ""
	for r: Dictionary in Defs.RESEARCH:
		if not c.research.has(String(r["id"])) and c.can_research(String(r["id"])) == "":
			rid = String(r["id"])
			break
	var ok_r := rid != "" and c.do_research(rid)
	var since := c.events.slice(n0)
	var learned := since.filter(func(e): return String(e["text"]).begins_with("Изучено:"))
	var others := since.size() - learned.size()          # просьбы, что засчитались от исследования, — их число на значке есть
	check(ok_r and learned.size() == 1 and hud.bell_count == b0 + others, "изучил сам — строка «%s», число на значке не выросло от неё (%d → %d, других строк %d)" % [
		String(learned[0]["text"]).left(60) if not learned.is_empty() else "", b0, hud.bell_count, others])
	# венки летописи за час — одной строкой
	n0 = c.events.size()
	b0 = hud.bell_count
	var fmt := func(a: Dictionary) -> String:
		var bb: Array = a["b"]
		return ("Летопись города: лавровый венок " if bb.size() == 1 else "Летопись города: лавровые венки ") + "; ".join(PackedStringArray(bb))
	c._quiet_m("chron", "laurels", {"b": ["«Первый» — проба"]}, fmt)
	c._quiet_m("chron", "laurels", {"b": ["«Второй» — проба"]}, fmt)
	check(c.events.size() == n0 + 1 and String(c.events[-1]["text"]).contains("«Первый»") and String(c.events[-1]["text"]).contains("«Второй»") and hud.bell_count == b0 + 1,
		"два венка за час — одна строка, +1 на значке: «%s»" % String(c.events[-1]["text"]))
	c.hour_n += 1
	c._quiet_m("chron", "laurels", {"b": ["«Третий» — проба"]}, fmt)
	check(c.events.size() == n0 + 2, "в другой час — своя строка")
	# этаж мазком — строка есть, числа на значке нет
	b0 = hud.bell_count
	c.floors_done([int(houses[2]["id"])], 200)
	check(String(c.events[-1]["text"]).contains("надстроили") and hud.bell_count == b0, "этаж мазком — строка в колокольчике, число то же")


# ---------- 3) герой не слабее легионера ----------

func _hero() -> void:
	print("== герой не слабее легионера, которого заменил")
	var worst := ""
	var weak := 0
	var min_gain := INF
	for lvl in range(1, Legion.MAX_LEVEL + 1):
		for cl in range(0, Legion.HERO_CITY_MAX + 1):
			for bon: Array in [[0.0, 0.0], [0.05, 0.0], [0.15, 0.15]]:
				var hs := Legion.hero_unit_stats(lvl, cl, 0, bon[0], bon[1])
				var ls := Legion.unit_stats("legionary", lvl, bon[0], bon[1])
				var ph := Legion.snap_hero({"level": lvl, "city": cl, "kit": 0}, bon[0], bon[1])
				var ok := int(hs["hp"]) >= int(ls["hp"]) and int(hs["atk"]) >= int(ls["atk"]) and float(hs["armor"]) >= float(ls["armor"]) \
					and float(hs["speed"]) >= float(ls["speed"]) and float(hs["rate"]) <= float(ls["rate"]) and Legion.power(hs) > Legion.power(ls)
				ok = ok and int(ph["hp"]) >= int(ls["hp"]) and int(ph["atk"]) >= int(ls["atk"]) and float(ph["armor"]) >= float(ls["armor"]) and Legion.power(ph) > Legion.power(ls)
				min_gain = minf(min_gain, float(Legion.power(hs)) / float(Legion.power(ls)))
				if not ok:
					weak += 1
					worst = "ур.%d город %d бонус %s: герой %s / легионер %s" % [lvl, cl, bon, [hs["hp"], hs["atk"], hs["armor"]], [ls["hp"], ls["atk"], ls["armor"]]]
	check(weak == 0, "на всех уровнях Казарм 1–%d и города 0–%d герой не слабее легионера (сила ×%.2f и больше)" % [Legion.MAX_LEVEL, Legion.HERO_CITY_MAX, min_gain], worst)
	# с городом герой растёт: «Город» — заметно сильнее легионера того же уровня
	var g1 := float(Legion.power(Legion.hero_unit_stats(2, 1, 0))) / Legion.power(Legion.unit_stats("legionary", 2))
	var g5 := float(Legion.power(Legion.hero_unit_stats(2, 5, 0))) / Legion.power(Legion.unit_stats("legionary", 2))
	check(g5 > g1 and g1 > 1.0, "растёт с городом: «Хутор» ×%.2f, «Город» ×%.2f" % [g1, g5])
	# уровень героя — ровно уровень легионера (Казармы), даже если тот выше нынешнего предела
	var lg: Legion = c.legion
	var lv0 := int(lg.levels.get("legionary", 1))
	lg.levels["legionary"] = lg.cap() + 2
	check(lg.hero_level() == int(lg.levels["legionary"]), "легионер выше предела города (%d) — герой того же уровня (%d)" % [lg.levels["legionary"], lg.hero_level()])
	lg.levels["legionary"] = lv0
