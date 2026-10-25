extends Node3D
## Этап 0 — поломки из замечаний 14.10. Запуск: bash .work/py/gpu_run.sh res://test_fixes.tscn → «FIX DONE fails=0».
## Связь (NetHttp): настоящая причина сбоя, повтор с забытым адресом, во вкладке «Против городов» — заголовок, объяснение,
## «Повторить» и код, сам повторяет через 5 с (один раз); таблица лучших — так же; честный текст, пока итог прошлого боя в пути;
## итог, не ушедший за полчаса, брошен. Значок «нет связи с облаком» (через 2 минуты) и советник один раз.
## Пауза, когда окно свёрнуто (бой кампании ждёт, бой с городом — нет). Охват лавок с «Большим охватом» (подсветка домов).
## Возврат очков за убранное «Площади из плитки» — и ни час, ни награда Легиона не срезают их до полок.
## В живой сервер не ходит: «нет связи» — закрытый порт 127.0.0.1:9 (на Windows он не отказывает, а молчит: вид сбоя
## тогда timeout, а не connect — поэтому ждём ответа не дольше 2 с, NetHttp.test_timeout). Снимки — D:/CivCity/.work/gd/fix_*.png
var game
var fails := 0
const OUT := "D:/CivCity/.work/gd/"
const DEAD := "https://127.0.0.1:9/api"


func _ready() -> void:
	Game.boot = {"new": "1", "hour": "10.5"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func secs(t: float) -> void:
	await get_tree().create_timer(t).timeout


func until(cond: Callable, limit: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > limit * 1000.0:
			return false
		await frames(2)
	return true


func check(ok: bool, what: String, extra = null) -> void:
	print("FIX %s %s%s" % ["PASS" if ok else "FAIL", what, "" if ok or extra == null else "  " + str(extra)])
	if not ok:
		fails += 1


func shot(name: String) -> void:
	await frames(8)
	get_viewport().get_texture().get_image().save_png(OUT + name)
	print("FIX shot ", OUT + name)


func _labels(n: Node) -> String:
	var s := ""
	if n != null:
		for l in n.find_children("*", "Label", true, false):
			s += (l as Label).text + " | "
	return s


func _no_internet_words(s: String) -> bool:
	return not s.to_lower().contains("проверьте интернет")


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(20)
	var c: City = game.city
	var hud = game.hud
	game.can_save = false                # тест не пишет сохранение
	if game.tutorial.active():           # обучение не нужно (finish() записал бы настройки игрока)
		game.tutorial.step = Tutorial.STEPS.size()
		game.tutorial.card.visible = false
		c.tips["tut"] = -1
		c.tips["ui"] = 3
		hud.apply_reveal(3)
	hud.advisor_panel.visible = false
	NetHttp.test_timeout = 2.0
	var net := LegionNet.me()
	for t in net.get_children():
		if t is Timer:
			(t as Timer).stop()             # фоновые запросы боёв не мешают

	# ---------- 0.1 NetHttp: виды сбоев и тексты ----------
	check(NetHttp.kind_of(HTTPRequest.RESULT_CANT_RESOLVE) == "dns" and NetHttp.kind_of(HTTPRequest.RESULT_CANT_CONNECT) == "connect"
		and NetHttp.kind_of(HTTPRequest.RESULT_NO_RESPONSE) == "connect" and NetHttp.kind_of(HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR) == "tls"
		and NetHttp.kind_of(HTTPRequest.RESULT_TIMEOUT) == "timeout" and NetHttp.kind_of(HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED) == "read"
		and NetHttp.kind_of(HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH) == "read", "коды HTTPRequest → dns / connect / tls / timeout / read")
	check(NetHttp.host_of("https://civcity.ru/api") == "civcity.ru" and NetHttp.host_of("http://127.0.0.1:3010/api") == "127.0.0.1",
		"имя сервера из адреса api")
	var all_ok := true
	for k in ["dns", "connect", "tls", "timeout", "read", "local:ERR_X"]:
		var x := NetHttp.explain({"status": 0, "net": k, "at": "14:32"}, "Сервер боёв", NetHttp.AGAIN)
		all_ok = all_ok and _no_internet_words(x["text"]) and _no_internet_words(x["short"]) and String(x["code"]) == "Код: %s · 14:32" % k
	var x5 := NetHttp.explain({"status": 503})
	check(all_ok and String(x5["text"]).contains("идёт обновление") and String(x5["code"]) == "Код: 503", "тексты по видам сбоя, без «проверьте интернет», с кодом")

	# запрос в закрытый порт: «connect», адрес забыт и повторён один раз
	var r: Dictionary = await NetHttp.fetch(self, DEAD, HTTPClient.METHOD_GET, "/health", null, "", {"timeout": 5.0})
	var dead_kind := String(r["net"])
	print("FIX note: закрытый порт на этом компьютере — ", dead_kind, ", ", r["ms"], " мс")
	check(int(r["status"]) == 0 and dead_kind in ["connect", "timeout"] and bool(r.get("retried", false)), "закрытый порт → %s, адрес забыт, повтор был" % dead_kind, r)
	r = await NetHttp.fetch(self, DEAD, HTTPClient.METHOD_PUT, "/save", {"x": 1}, "t", {"timeout": 5.0, "safe": false})
	check(int(r["status"]) == 0 and bool(r.get("retried", false)) == bool(r.get("unsent", false)),
		"небезопасный запрос повторяется, только если точно не ушёл (%s)" % String(r["net"]), r)

	# ---------- 0.4 «Площади из плитки» убраны, очки вернулись ----------
	var has_r2 := false
	for it in Defs.RESEARCH:
		has_r2 = has_r2 or String(it["id"]) == "roads2"
	check(not has_r2, "исследования «Площади из плитки» больше нет")
	var d = JSON.parse_string(JSON.stringify(c.save_data()))
	(d["research"] as Array).append("roads2")
	d["rp"] = 50.0
	var n_ev: int = (d.get("events", []) as Array).size()
	var c2 := City.new(Land.new())
	c2.load_data(d)
	var last: Dictionary = c2.events[-1] if not c2.events.is_empty() else {}
	check(not c2.research.has("roads2") and is_equal_approx(c2.rp, 50.0 + City.ROADS2_RP) and c2.unread == 1 and c2.events.size() == n_ev + 1
		and String(last.get("text", "")).contains("Площади из плитки"), "старое сохранение: флаг снят, +%d очков, одна запись в колокольчике" % City.ROADS2_RP,
		[c2.rp, c2.unread, last])
	var d2 = JSON.parse_string(JSON.stringify(c2.save_data()))
	var c3 := City.new(Land.new())
	c3.load_data(d2)
	check(c3.unread == 0 and c3.events.size() == c2.events.size() and is_equal_approx(c3.rp, c2.rp), "второй раз не возвращается")
	c.rp = c.rp_cap() + 100.0
	var over := c.rp
	c.sim_day()
	check(c.rp >= over - 0.01, "очки сверх полок не срезаются следующим часом", [over, c.rp, c.rp_cap()])
	c.rp = c.rp_cap() + 160.0
	over = c.rp
	c.legion._give({"rp": 50.0, "money": 0.0})
	check(c.rp >= over - 0.01, "награда Легиона очками не срезает их до полок", [over, c.rp, c.rp_cap()])
	c.rp = 0.0

	# ---------- 0.3 охват с «Большим охватом» — как в расчёте (кругов больше нет: подсветка домов, cover.gd) ----------
	c.research["stall_veg"] = true
	c.research["reach1"] = true
	var want := Defs.range_m(Defs.B["stall_veg"]) * 1.33
	var far := c.place("house_pleb", Vector2(176 + Defs.range_m(Defs.B["stall_veg"]) * 1.2, 150), PI * 0.5, 0, -1, true)
	var sets := Cover.place_sets(c, "stall_veg", Vector2(176, 150))
	check(is_equal_approx(c.shop_range(Defs.B["stall_veg"]), want) and not far.is_empty() and (sets["green"] as Array).has(int(far["id"])),
		"охват лавки с едой — на треть дальше (%.1f м): дом на 1,2 дальности подсвечен" % want, sets)
	check(game.get("range_ring") == null and not hud.has_method("_toggle_reach"), "кругов охвата больше нет")
	if not far.is_empty():
		c.remove(far, false)
	await frames(5)

	# ---------- 0.1 вкладка «Против городов» без связи ----------
	var acc := Account.me()
	var api0 := acc.api
	acc.api = DEAD
	acc.token = "test-token"
	net.force_on = true
	net.unsupported = false
	c.level = 4
	c.research["legion"] = true
	c.money = 20000.0
	c.legion.flags["tut"] = "done"
	c.changed.emit()
	await frames(5)
	var ui := LegionUi.of(hud)
	check(net.pvp_ready(), "вкладка готова к сети")
	ui.open("pvp")
	var got := await until(func(): return ui._pvp_state == "error", 25.0)
	await frames(6)
	var blk: Node = ui.content.find_child("NetError", true, false)
	var retry: Button = ui.content.find_child("Retry", true, false) as Button
	var texts := ""
	if blk != null:
		for l in blk.find_children("*", "Label", true, false):
			texts += (l as Label).text + " | "
	check(got and net.last_error in ["connect", "timeout"] and blk != null and retry != null and retry.text == "Повторить" and texts.contains("Сервер боёв")
		and texts.contains("не отвечает") and texts.contains("Код: %s · " % net.last_error) and texts.contains("VPN") and _no_internet_words(texts),
		"ошибка — блок: «Сервер боёв не отвечает», объяснение, «Повторить», «Код: %s · ЧЧ:ММ»" % net.last_error, [ui._pvp_state, net.last_error, texts])
	check(ui._pvp_auto and ui._pvp_auto_wait, "через 5 с попробует снова сам")
	await shot("fix_pvp_error.png")
	var again := await until(func(): return ui._pvp_state == "loading", 8.0)
	await until(func(): return ui._pvp_state == "error", 25.0)
	check(again and not ui._pvp_auto_wait and ui._pvp_state == "error", "сам повторил один раз и снова честно показал ошибку")
	retry = ui.content.find_child("Retry", true, false) as Button
	if retry != null:
		retry.pressed.emit()
	await frames(2)
	check(ui._pvp_state == "loading", "«Повторить» — снова ищет соперников")
	await until(func(): return ui._pvp_state == "error", 25.0)
	# таблица лучших — тот же блок
	LegionPvpView.top(ui)
	var top_err := await until(func(): return ui.overlay != null and ui.overlay.find_child("NetError", true, false) != null, 25.0)
	check(top_err and ui.overlay.find_child("Retry", true, false) != null and _labels(ui.overlay.find_child("NetError", true, false)).contains("пробуем снова сами"),
		"«Лучшие города» без связи — та же ошибка с «Повторить» и «пробуем снова сами…»")
	await shot("fix_top_error.png")
	var top_again := await until(func(): return ui.overlay != null and ui.overlay.find_child("NetError", true, false) == null, 8.0)
	await until(func(): return ui.overlay != null and ui.overlay.find_child("NetError", true, false) != null, 25.0)
	var blk2: Node = ui.overlay.find_child("NetError", true, false) if ui.overlay != null else null
	var once := blk2 != null and not _labels(blk2).contains("пробуем снова сами")
	await secs(6.0)
	check(top_again and once and is_instance_valid(blk2) and blk2.is_inside_tree(), "«Лучшие города» сами повторили один раз и больше не повторяют")
	ui._close_overlay()
	# нападение, пока итог прошлого боя в пути — честный текст, не «нет связи»
	var lg: Legion = c.legion
	lg.pvp_log = [{"battle": "bt-old", "win": true, "attack": true, "name": "Тарент", "delta": 12, "t": Legion.now()}]
	net._retry = [[{"battle": "bt-new", "win": true}, "Капуя", 0]]
	var st := {}
	net.pvp_attack({"id": "x"}, func(o, e):
		st["e"] = e
		st["done"] = true)
	await until(func(): return st.has("done"), 30.0)
	check(String(st.get("e", "")).begins_with("Сначала отправляем итог прошлого боя"), "нападение ждёт итог прошлого боя — так и сказано", st)
	# итог, не ушедший за полчаса: сервер уже засчитал поражение — бросаем, в летописи «не засчитан»
	net._retry = [[{"battle": "bt-old", "win": true}, "Тарент", 5, net._now() - LegionNet.BATTLE_TTL - 5.0]]
	await net._flush_retry()
	check(net._retry.is_empty() and bool(lg.pvp_log[0].get("void", false)), "итог старше получаса брошен, бой в летописи — не засчитан")
	lg.pvp_log = []
	ui.close()
	net.force_on = false
	await frames(5)

	# ---------- 0.1 значок «нет связи с облаком» ----------
	acc.force_on = true                  # как в настоящей игре со входом
	acc.synced = false
	acc.net = "idle"
	acc._last_sync = -1.0e9
	acc.sync()
	await until(func(): return acc.net == "offline" and not acc.syncing, 25.0)
	check(acc.net == "offline" and acc.last_net in ["connect", "timeout"] and acc.off_since > 0.0, "облако: нет связи, причина %s" % acc.last_net, [acc.net, acc.last_net])
	await secs(1.5)
	check(not hud.cloud_off.holder.visible, "первые 2 минуты значка нет")
	acc.off_since = Time.get_unix_time_from_system() - CloudBadge.AFTER - 1.0
	var shown := await until(func(): return hud.cloud_off.holder.visible, 3.0)
	check(shown and hud.cloud_off.tooltip_text.contains("Нет связи с облаком") and hud.cloud_off.tooltip_text.contains("Код: " + acc.last_net),
		"через 2 минуты — перечёркнутое облачко, подсказка с причиной", hud.cloud_off.tooltip_text)
	hud.advisor_panel.visible = false     # советник не перебивает другой совет — убрать прежний
	var told := await until(func(): return hud.advisor_panel.visible and hud.adv_title.text == "Нет связи с облаком", 4.0)
	check(told and acc.off_told, "советник объяснил один раз")
	await shot("fix_cloud_advisor.png")
	hud.advisor_panel.visible = false
	await secs(1.5)
	check(not hud.advisor_panel.visible, "второй раз советник молчит")
	var win := get_window()
	var size0 := win.size
	await shot("fix_cloud_top.png")
	for sz: Vector2i in [Vector2i(1280, 720), Vector2i(1024, 640)]:
		win.size = sz
		await frames(12)
		var rr: Rect2 = hud.top_panel.get_global_rect()
		check(rr.position.x >= 0.0 and rr.end.x <= float(hud.root.size.x) + 1.0, "верхняя правая полоса со значком влезает в %dx%d" % [sz.x, sz.y], rr)
		await shot("fix_cloud_%d.png" % sz.x)
	win.size = size0
	await frames(10)
	hud.cloud_off.pressed.emit()
	await frames(2)
	check(acc.syncing or acc.net == "checking" or acc.off_since > 0.0, "щелчок по облачку — пробует снова")
	await until(func(): return not acc.syncing, 25.0)
	acc.force_on = false
	acc.token = ""
	acc.off_since = 0.0
	acc.net = "idle"
	acc.api = api0
	await secs(1.5)
	check(not hud.cloud_off.holder.visible, "связь есть (или нет входа) — значка нет")

	# ---------- 0.2 пауза, когда окно свёрнуто ----------
	hud.set_speed(2.0)
	await frames(3)
	game.real_min_pause = true                # под gpu_run.sh настоящая пауза при сворачивании выключена — здесь её и проверяем
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var real := await until(func(): return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED, 3.0)
	if not real:
		print("FIX note: окно не свернулось по-настоящему — проверяем через minimized_test")
		game.minimized_test = true
	await frames(5)
	check(game.speed == 0.0 and is_equal_approx(hud.paused_speed, 2.0), "свернули — город на паузе", [game.speed, real])
	var day0: float = game.hour
	await frames(30)
	check(is_equal_approx(game.hour, day0), "пока свёрнуто, время стоит")
	game.minimized_test = false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await until(func(): return DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_MINIMIZED, 3.0)
	await frames(5)
	check(is_equal_approx(game.speed, 2.0), "развернули — прежняя скорость ×2", game.speed)
	# был на паузе до сворачивания — так и остаётся
	hud.set_speed(0.0)
	game.minimized_test = true
	await frames(5)
	game.minimized_test = false
	await frames(5)
	check(game.speed == 0.0, "пауза до сворачивания не снимается")
	hud.set_speed(1.0)
	# бой кампании ждёт, бой с городом идёт дальше: сервер ждёт его итог только полчаса
	for is_pvp in [false, true]:
		var fb := LegionBattle.new()         # без сцены: только то, что смотрит пауза
		fb.pvp = is_pvp
		fb.phase = "fight"
		fb.pause_lbl = Label.new()
		LegionBattle.current = fb
		game.minimized_test = true
		await frames(3)
		var held: bool = game._min_battle == fb
		var stopped := fb.paused
		game.minimized_test = false
		await frames(3)
		check(held != is_pvp and stopped != is_pvp and not fb.paused and game._min_battle == null and is_equal_approx(game.speed, 1.0),
			"свернули во время боя %s — %s" % ["с городом" if is_pvp else "кампании", "бой идёт дальше" if is_pvp else "бой на паузе, потом дальше"],
			[held, stopped, fb.paused, game.speed])
		LegionBattle.current = null
		fb.pause_lbl.free()
		fb.free()

	NetHttp.test_timeout = 0.0

	# ---------- 0.4 настоящая загрузка старого города (своя папка .work/fix_save): очки и число на колокольчике ----------
	var dir := "D:/CivCity/.work/fix_save"
	DirAccess.make_dir_recursive_absolute(dir)
	var sd := c.save_data()
	sd["land"] = game.land.save_changes()
	sd["hour"] = 10.5
	sd["version"] = 2
	(sd["research"] as Array).append("roads2")
	sd["rp"] = 10.0
	sd["tips"]["rank_cine"] = c.level
	var f := FileAccess.open(dir + "/city.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(sd))
	f.close()
	game.queue_free()
	await frames(5)
	GamePaths._dir = dir
	Game.boot = {"play": "1", "hour": "10.5"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	while not game.ready_done:
		await frames(5)
	game.can_save = false
	await frames(10)
	var gc: City = game.city
	var ev_ok: bool = gc.events.any(func(e): return String(e.get("text", "")).contains("Площади из плитки"))
	check(not gc.research.has("roads2") and is_equal_approx(gc.rp, 10.0 + City.ROADS2_RP) and ev_ok and game.hud.bell_count >= 1 and gc.unread == 0,
		"загрузили город с «Площадями из плитки»: очки вернулись, запись в колокольчике, на нём число", [gc.rp, game.hud.bell_count])
	DirAccess.remove_absolute(dir + "/city.json")
	_unlockable(false)
	_unlockable(true)

	print("FIX DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


# ---------- этап 5.2: всё, что просят, открыто к тому уровню, где просят (и в живых городах, и в новой игре) ----------

## С какого уровня открыто исследованием или просьбой u (истории и заказы — 99: их награду никто не обещает)
func _rank_of(u: String) -> int:
	if u == "":
		return 0
	var r := Defs.research(u)
	if not r.is_empty():
		var lv := int(r["lvl"])
		while r.has("after"):
			r = Defs.research(String(r["after"]))
			lv = maxi(lv, int(r.get("lvl", 0)))
		return 99 if r.has("story") else lv
	var rk := 0
	for q in Defs.REQUESTS:
		if String(q.get("unlock", "")) == u:
			return rk
		if String(q["p"][0]) == "rank":
			rk += 1
	return 99


## Вид (тип, облик или «a|b») можно поставить на уровне lv: хоть один его обычный облик открыт к этому уровню
func _kind_by(key: String, lv: int, late: bool) -> bool:
	for k in key.trim_prefix("=").split("|"):
		if not Defs.B.has(k):
			continue
		var looks: Array = [k] if key.begins_with("=") else Defs.looks_of(k)
		if not looks.has(k):
			looks.append(k)
		for t: String in looks:
			if bool(Defs.B[t].get("story", false)):
				continue
			if _rank_of(Defs.unlock_of(t, late)) <= lv:
				return true
	return false


## Все строки-виды украшений в цели истории (словари {вид: n}, «a|b», вложенные цели)
func _goal_kinds(g, out: Array) -> void:
	if g is Array:
		for x in g:
			_goal_kinds(x, out)
	elif g is Dictionary:
		for k in g:
			if String(k).split("|")[0] in Defs.B and String(Defs.B[String(k).split("|")[0]].get("kind", "")) == "decor":
				out.append(String(k))
			_goal_kinds(g[k], out)


func _unlockable(late: bool) -> void:
	var bad := []
	var rk := 0
	for q in Defs.REQUESTS:
		var pp: Array = q["p"]
		if String(pp[0]) == "count" and Defs.B.has(String(pp[1])) and String(Defs.B[pp[1]]["kind"]) == "decor" and not _kind_by(String(pp[1]), rk, late):
			bad.append("просьба %s" % q["id"])
		if String(pp[0]) == "rank":
			rk += 1
	for o: Dictionary in StoryOrders.ORDERS:
		for e: Array in o["need"]:
			if not _kind_by(String(e[0]), int(o["lvl"]), late):
				bad.append("заказ %s: %s" % [o["id"], e[0]])
	for s: Dictionary in StoryDefs.STORIES:
		var ks := []
		var granted := []                    # что история открывает сама (ларарий в «Письме сыну»)
		for st: Dictionary in s.get("steps", []):
			_goal_kinds(st.get("goal", []), ks)
			granted.append_array(st.get("grant", []))
		for k: String in ks:
			var by_story := false
			for t in k.trim_prefix("=").split("|"):
				by_story = by_story or (Defs.B.has(t) and String(Defs.B[t].get("unlock", "")) in granted)
			if not _kind_by(k, int(s.get("lvl", 0)), late) and not by_story:
				bad.append("история %s: %s" % [s["id"], k])
	# прятки Мурки — на «Хуторе» хоть один вид из укрытий
	var hide_ok := false
	for k: String in ["hay", "cart", "amphorae", "goods", "bush", "well", "tree", "cypress", "planter", "fence", "palm"]:
		hide_ok = hide_ok or _kind_by(k, 1, late)
	if not hide_ok:
		bad.append("укрытия Мурки")
	# «decor5» — пять украшений на «Стоянке»: хоть пять видов открыто с начала
	var n0 := 0
	for t in Defs.B:
		if String(Defs.B[t]["kind"]) == "decor" and Defs.base_of(t) == t and not bool(Defs.B[t].get("story", false)) and _rank_of(Defs.unlock_of(t, late)) == 0:
			n0 += 1
	if n0 < 5:
		bad.append("на Стоянке видов украшений %d < 5" % n0)
	check(bad.is_empty(), "%s: всё, что просят просьбы, заказы и истории, открыто к своему уровню (видов на Стоянке %d)" % ["новая игра" if late else "живой город", n0], bad)
