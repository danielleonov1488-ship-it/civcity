class_name LegionNet
extends Node
## Бои с городами по сети: вкладка «Против городов» окна «Легион» ↔ сервер CivCity (/api/pvp/…, server/pvp.js).
## Вход и адрес сервера — у Account (account.gd): тот же токен и тот же api. Один узел на всю игру (LegionNet.me()),
## висит под корнем дерева, как Account, и переживает перезапуск сцены.
##
## Для окна (LegionUi._net находит этот модуль по static me()):
##   pvp_ready() — можно ли сражаться (вошли, идёт настоящая игра, сервер умеет бои); signed_in();
##   pvp_opponents(cb(list, err)) — сначала выставляет отряд обороны, потом список соперников
##       [{id, name, rating, city_level, power, snapshot, bot}] (bot — вольный город сервера);
##   pvp_attack(opp, cb(opp2, err)) — сервер тратит заряд и даёт номер боя: opp2 = {name, rating, city_level, snapshot,
##       battle, seed, stakes {win, loss}, reward {money, glory}, bot} → Legion.start_pvp_battle(opp2);
##   pvp_report(setup, out) — итог боя на сервер (один раз на номер боя; сам модуль докладывает уже по сигналу
##       LegionBattle.finished, не дожидаясь возврата в город); pvp_top(cb(data, err)); pvp_rename(name, cb(err)).
##   me_state — что сервер сказал о нас: name, custom, rating, wins, losses, def_wins, def_losses, charges, next_in…
## Название города (CityName, окно «Название города»): set_city_name(name, cb(err, offline)) — PUT /pvp/name, и без
## Легиона. Имя из каждого ответа сервера (me.name) становится названием города: city.name и табличка вверху слева.
## Сам по себе (раз в 5 с проверяет): выставляет отряд обороны, если он поменялся (Legion.defense_snapshot()),
## раз в 5 минут забирает отчёты о нападениях на наш город (Legion.pvp_defense → летопись боёв, +Слава за оборону)
## и повторяет итоги боёв, которые не ушли из-за связи. Рейтинг, победы и заряды атак берёт с сервера.
## Пока Легиона нет — только раз в 5 минут спрашивает своё состояние (имя города), оборону не выставляет.

signal changed                                # ответ сервера: имя, рейтинг, отчёты — перерисовать окно

const POLL := 5.0
const PUB_GAP := 120.0                        # отряд обороны проверяем не чаще раза в 2 минуты
const PUB_REFRESH := 6 * 3600.0               # и обновляем, даже если не менялся, раз в 6 часов
const STATE_GAP := 300.0                      # отчёты о нападениях — раз в 5 минут
const TIMEOUT := 12.0                         # ответы боёв маленькие; при сбое NetHttp ещё раз пробует (до 10 с)
const BATTLE_TTL := 30 * 60.0                 # сервер ждёт итог боя полчаса (server/pvp.js), потом бой — поражение

var me_state := {}
var last_error := ""                          # почему не вышел последний запрос: dns | connect | tls | timeout | read | код ответа
var last_fail := {}                           # последняя ошибка для окна: title, text, short, code («Код: timeout · 14:32»)
var unsupported := false                      # сервер без /api/pvp (ответил 404) — в окне «скоро»
## Проверки: работать и без настоящей игры (готовый город, тестовая сцена); legion_override — легион без города
var force_on := false
var legion_override: Legion = null

var _pub_hash := ""
var _pub_t := -1.0e9                          # когда отряд обороны в последний раз ушёл на сервер
var _chk_t := -1.0e9                          # когда его в последний раз сверяли (снимок недёшев)
var _state_t := -1.0e9
var _reported := {}                           # номер боя → итог отправлен (или отправляется)
var _retry: Array = []                        # итоги, не ушедшие из-за связи: [тело, соперник, попыток]
var _sending := 0                             # итогов в пути (их ждёт новое нападение)
var _hooked: Legion = null
var _busy := false
var _tok := ""                                # с какой учёткой всё это (вошли другой — начать заново)

static var _inst: LegionNet = null


static func me() -> LegionNet:
	if _inst == null or not is_instance_valid(_inst):
		_inst = LegionNet.new()
		_inst.name = "LegionNet"
		(Engine.get_main_loop() as SceneTree).root.add_child(_inst)
	return _inst


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var t := Timer.new()
	t.wait_time = POLL
	t.autostart = true
	t.timeout.connect(_tick)
	add_child(t)


# ---------- когда можно ----------

func _acc() -> Account:
	return Account.me()


func _game():
	var a := _acc()
	return a.game if a.game != null and is_instance_valid(a.game) else null


func _lg() -> Legion:
	if legion_override != null:
		return legion_override
	var g = _game()
	if g == null or g.city == null:
		return null
	return g.city.legion


func signed_in() -> bool:
	return _acc().signed_in()


func pvp_ready() -> bool:
	if unsupported or not signed_in() or _lg() == null:
		return false
	if force_on:
		return true
	var a := _acc()
	var g = _game()
	return a.required() and g != null and String(g.mode) in ["play", "new"] and a.net != "old"


# ---------- для окна ----------

func pvp_opponents(cb: Callable) -> void:
	_check_account()
	_hook()
	var pr := await _publish(false)
	if int(pr.get("status", 200)) == 0:
		cb.call([], _err(pr))                       # связи нет — второй запрос не ждём, говорим сразу
		return
	var r := await _call(HTTPClient.METHOD_GET, "/pvp/opponents")
	if r["status"] != 200:
		cb.call([], _err(r))
		return
	var d: Dictionary = r["data"]
	_apply_reports(d.get("reports", []))
	_apply_me(d.get("me", {}))
	var list := []
	for o in d.get("opponents", []):
		if o is Dictionary and (o as Dictionary).get("snapshot") is Dictionary:
			list.append({"id": String(o.get("id", "")), "name": String(o.get("name", "?")), "rating": int(o.get("rating", 0)),
				"city_level": int(o.get("city_level", 0)), "power": int(o.get("power", 0)), "snapshot": o["snapshot"], "bot": bool(o.get("bot", false))})
	cb.call(list, "")


func pvp_attack(opp: Dictionary, cb: Callable) -> void:
	var lg := _lg()
	if lg == null:
		cb.call({}, "Город ещё не готов")
		return
	_check_account()
	_hook()
	# сначала доложить прежние бои (итог, не ушедший из-за связи, или ещё летящий): новое нападение закрывает
	# недоложенные бои поражением
	await _flush_retry()
	if not _retry.is_empty():
		var wait := "Сначала отправляем итог прошлого боя — как только сервер его примет, можно нападать снова."
		last_fail = {"title": "Итог прошлого боя ещё в пути", "text": wait, "short": wait, "code": ""}
		cb.call({}, wait)
		return
	var r := await _call(HTTPClient.METHOD_POST, "/pvp/attack", {"target": String(opp.get("id", "")), "squad": attack_snapshot(lg)})
	if r["status"] != 200:
		if (r["data"] as Dictionary).get("me") is Dictionary:
			_apply_me(r["data"]["me"])
		cb.call({}, _err(r, true))
		return
	var d: Dictionary = r["data"]
	var o: Dictionary = (d.get("opponent", {}) as Dictionary).duplicate()
	o["id"] = String(opp.get("id", ""))
	o["battle"] = String(d.get("battle", ""))
	o["seed"] = int(d.get("seed", -1))
	o["stakes"] = d.get("stakes", {})
	o["reward"] = d.get("reward", {})
	if d.get("attack") is Dictionary:
		o["attack"] = d["attack"]                   # наш отряд, каким его проверил сервер: воюем им (Legion.make_pvp_battle)
	# сервер уже потратил заряд; бой (apply_pvp_result) спишет его ещё раз у нас — даём на один больше
	_apply_me(d.get("me", {}), 1)
	cb.call(o, "")


func pvp_report(setup: Dictionary, out: Dictionary) -> void:
	var opp: Dictionary = setup.get("opponent", {})
	var bid := String(opp.get("battle", ""))
	if bid == "" or _reported.has(bid) or out.is_empty():
		return
	_reported[bid] = true
	# inputs — нажатия умений и «Авто» по шагам боя: по ним сервер повторит бой и проверит победу
	var body := {"battle": bid, "win": bool(out.get("win", false)), "alive": int(out.get("alive", 0)), "total": int(out.get("total", 0)),
		"time": float(out.get("time", 0.0)), "hp_left": float(out.get("hp_left", 0.0)), "retreat": bool(out.get("retreat", false)),
		"inputs": out.get("inputs", [])}
	await _send_result(body, String(opp.get("name", "")))


func pvp_top(cb: Callable) -> void:
	_check_account()
	var r := await _call(HTTPClient.METHOD_GET, "/pvp/top")
	if r["status"] != 200:
		cb.call({}, _err(r))
		return
	if (r["data"] as Dictionary).get("me") is Dictionary:
		_apply_me(r["data"]["me"])
	cb.call(r["data"], "")


## Новое название города (табличка, таблица лучших, летописи соперников). cb(err, offline): err "" — сохранено
## (city.name, табличка, me_state, сохранение и облако — уже), иначе почему нет: текст сервера (занято, не подойдёт)
## или честная причина без связи / без входа (offline — тогда в окне «Повторить»)
func set_city_name(raw: String, cb: Callable) -> void:
	var nm := CityName.clean(raw)
	var why := CityName.check(nm, String(me_state.get("name", "")))
	if why != "":
		cb.call(why, false)
		return
	if not signed_in():
		var t := "Название хранится на сервере CivCity — войдите в аккаунт (Меню → Настройки) и попробуйте снова."
		last_fail = {"title": "Нужно войти", "text": t, "short": t, "code": ""}
		cb.call(t, true)
		return
	_check_account()
	var r := await _call(HTTPClient.METHOD_PUT, "/pvp/name", {"name": nm})
	var d: Dictionary = r["data"]
	if int(r["status"]) == 404 and not d.has("me") and str(d.get("error", "")) in ["Нет такого адреса", ""]:
		r = await _rename_old(nm)                   # сервер ещё без /pvp/name
	var code := int(r["status"])
	if code != 200:
		var f := _err(r, true, "Сервер CivCity")
		# отказ сервера (занято, не подойдёт, слишком часто) — его словами; нет связи, сбой, вход устарел — «Повторить»
		var off := code == 0 or code >= 500 or code == 401
		cb.call(f if off else str(r["error"]), off)
		return
	_apply_me((r["data"] as Dictionary).get("me", {}))
	var g = _game()
	if g != null and g.can_save and g.ready_done and not Account._carrying(g):
		g.save()                                    # сохранение и облако (Account.after_save: meta.city — новое имя)
	cb.call("", false)


## Сервер до PUT /pvp/name (ещё не обновлён): название уходило вместе с отрядом обороны — только с Легионом
func _rename_old(nm: String) -> Dictionary:
	var lg := _lg()
	if lg == null or not lg.window_open():
		return {"status": 409, "data": {}, "error": "Сервер пока не умеет менять название города — загляните чуть позже", "net": ""}
	var snap := lg.defense_snapshot()
	var r := await _call(HTTPClient.METHOD_PUT, "/pvp/defense", {"snapshot": snap, "name": nm, "city_level": int(snap.get("city_level", 0))})
	if r["status"] == 200:
		_pub_hash = JSON.stringify(snap).sha256_text()
		_pub_t = _now()
		_chk_t = _pub_t
	return r


## Название и сразу отряд обороны (если Легион собран) — так проверки выставляют оборону одним вызовом; "" — ок
func pvp_rename(nm: String, cb: Callable) -> void:
	set_city_name(nm, func(err: String, _offline: bool):
		if err != "":
			cb.call(err)
			return
		var lg := _lg()
		if lg != null and lg.window_open():
			await _publish(true)
		cb.call(""))


## Отряд похода — тот, что пойдёт в бой (сервер сверит его с городом в облаке)
static func attack_snapshot(lg: Legion) -> Dictionary:
	var sq := []
	for s: Dictionary in lg.squad_stats():
		sq.append({"type": String(s["key"]), "level": int(s["level"])})
	return {"v": 1, "squad": sq, "perks": lg.open_perks(), "atk_b": lg.bonus("atk"), "hp_b": lg.bonus("hp")}


# ---------- сам по себе ----------

func _tick() -> void:
	if _busy or not pvp_ready():
		return
	if not force_on and not _acc().synced:
		return                                      # сначала город сверяется с облаком
	_check_account()
	if not _lg().window_open():
		# Легиона ещё нет: оборону не выставляем, только своё состояние — в нём имя города (табличка вверху слева)
		if _now() - _state_t >= STATE_GAP:
			_busy = true
			await refresh()
			_busy = false
		return
	_busy = true
	_hook()
	await _flush_retry()
	if _now() - _chk_t >= PUB_GAP:
		await _publish(false)
	if _now() - _state_t >= STATE_GAP:
		await refresh()
	_busy = false


## Свежее состояние и отчёты о нападениях на наш город
func refresh() -> void:
	var lg := _lg()
	if lg == null:
		return
	_check_account()
	_state_t = _now()
	var r := await _call(HTTPClient.METHOD_GET, "/pvp/state?ack=%d" % int(lg.flags.get("pvp_seen", 0)))
	if r["status"] != 200:
		return
	_apply_reports(r["data"].get("reports", []))
	_apply_me(r["data"].get("me", {}))


## Выставить отряд обороны, если он поменялся (или давно не обновлялся). Снимок считать недёшево (обходит все
## постройки города), поэтому сама проверка — не чаще PUB_GAP (_chk_t), а _pub_t — время настоящей отправки
## Ответ сервера — или {}, если отправлять было нечего
func _publish(force: bool) -> Dictionary:
	var lg := _lg()
	if lg == null or not lg.window_open():
		return {}
	_chk_t = _now()
	var snap := lg.defense_snapshot()
	var h := JSON.stringify(snap).sha256_text()
	if not force and h == _pub_hash and _now() - _pub_t < PUB_REFRESH:
		return {}
	_pub_t = _now()
	var r := await _call(HTTPClient.METHOD_PUT, "/pvp/defense", {"snapshot": snap, "city_level": int(snap.get("city_level", 0))})
	if r["status"] == 200:
		_pub_hash = h
		_apply_me(r["data"].get("me", {}))
	return r


## Отправить итоги, не ушедшие из-за связи, и дождаться тех, что ещё в пути (так делает и новое нападение:
## сервер закрывает поражением недоложенные бои, а выигранный бой не должен пропасть из-за мигнувшей связи)
func _flush_retry() -> void:
	var t0 := _now()
	while _sending > 0 and _now() - t0 < TIMEOUT + NetHttp.RETRY_TIMEOUT + 3.0:
		await get_tree().process_frame
	var list := _retry.duplicate()
	_retry.clear()
	for e: Array in list:
		# не ушёл — снова в _retry
		await _send_result(e[0], e[1], int(e[2]) if e.size() > 2 else 0, float(e[3]) if e.size() > 3 else _now())


## tries — сколько раз уже не ушёл, t0 — когда не ушёл впервые (первая отправка — сейчас)
func _send_result(body: Dictionary, opp_name: String, tries := 0, t0 := 0.0) -> void:
	if tries == 0:
		t0 = _now()
	_sending += 1
	var r := await _call(HTTPClient.METHOD_POST, "/pvp/result", body)
	_sending -= 1
	var code := int(r["status"])
	# нет связи или сервер перезапускается (502/503 — выкладка) — повторим, пока сервер держит бой (BATTLE_TTL)
	if code == 0 or code >= 500:
		if _now() - t0 < BATTLE_TTL and (code == 0 or tries < 60):
			_retry.append([body, opp_name, tries + 1, t0])
			return
		# так и не ушёл: сервер уже засчитал бой поражением — бросаем, чтобы он не держал новые нападения
		push_warning("LegionNet: итог боя %s не ушёл на сервер (%s)" % [String(body.get("battle", "")), last_error])
		_mark_void(String(body.get("battle", "")))
		return
	if r["status"] != 200:
		push_warning("LegionNet: итог боя не принят: %d %s" % [int(r["status"]), str(r["error"])])
		return
	var d: Dictionary = r["data"]
	var lg := _lg()
	if lg != null:
		# летопись: изменение рейтинга — как засчитал сервер
		for e in lg.pvp_log:
			if e is Dictionary and String(e.get("battle", "")) == String(body["battle"]):
				e["delta"] = int(d.get("delta", e.get("delta", 0)))
				if not bool(d.get("accepted", true)):
					e["void"] = true
				break
	_apply_me(d.get("me", {}))
	if not bool(d.get("accepted", true)) and String(d.get("reason", "")) != "":
		_note(String(d["reason"]), "info")
	print("LegionNet: бой %s — %s, рейтинг %+d → %d" % [opp_name, String(d.get("status", "")), int(d.get("delta", 0)), int(d.get("rating", 0))])


## Итог боя так и не дошёл до сервера — в летописи «сервер бой не засчитал»
func _mark_void(bid: String) -> void:
	var lg := _lg()
	if lg == null or bid == "":
		return
	for e in lg.pvp_log:
		if e is Dictionary and String(e.get("battle", "")) == bid:
			e["void"] = true
			lg.changed.emit()
			break


## Что сервер сказал о нас: рейтинг, победы и заряды атак — как на сервере (extra — заряд, который ещё спишет бой)
func _apply_me(m: Dictionary, extra := 0) -> void:
	if m.is_empty():
		return
	me_state = m
	_apply_name(String(m.get("name", "")))
	var lg := _lg()
	if lg != null:
		var before := [lg.pvp_rating, lg.pvp_wins, lg.pvp_losses, lg.pvp_charges]
		lg.pvp_rating = int(m.get("rating", lg.pvp_rating))
		lg.pvp_wins = int(m.get("wins", lg.pvp_wins))
		lg.pvp_losses = int(m.get("losses", lg.pvp_losses))
		var mx := int(Legion.PVP["charges"])
		var n := mini(mx, int(m.get("charges", lg.pvp_charges)) + extra)
		lg.pvp_charges = n
		if n >= mx:
			lg.pvp_charge_t = Legion.now()
		else:
			var regen := float(m.get("regen", Legion.PVP["regen"]))
			lg.pvp_charge_t = Legion.now() - maxf(0.0, regen - float(m.get("next_in", regen)))
		if before != [lg.pvp_rating, lg.pvp_wins, lg.pvp_losses, lg.pvp_charges]:
			lg.changed.emit()
	changed.emit()


## Имя с сервера — название города: в сохранение (city.name) и на табличку. Только в своём городе (не в меню,
## не в готовом городе витрины)
func _apply_name(nm: String) -> void:
	var g = _game()
	if nm == "" or g == null or g.city == null or not (String(g.mode) in ["play", "new"]):
		return
	if String(g.city.name) == nm:
		return
	g.city.name = nm
	if g.hud != null:
		g.hud.show_city_name()


## Отчёты о нападениях на наш город → летопись боёв; потом сказать серверу «прочитано»
func _apply_reports(list: Array) -> void:
	var lg := _lg()
	if lg == null or list.is_empty():
		return
	var seen := int(lg.flags.get("pvp_seen", 0))
	var fresh := []
	var held := 0
	for r in list:
		if not (r is Dictionary) or int(r.get("id", 0)) <= seen:
			continue
		fresh.append({"name": String(r.get("name", "?")), "win": bool(r.get("win", false)), "delta": int(r.get("delta", 0)),
			"t": float(r.get("t", Legion.now())), "glory": float(r.get("glory", 0))})
		seen = maxi(seen, int(r["id"]))
		if not bool(r.get("win", false)):
			held += 1
	if fresh.is_empty():
		return
	lg.pvp_defense(fresh)
	lg.flags["pvp_seen"] = seen
	_call(HTTPClient.METHOD_POST, "/pvp/ack", {"upto": seen})
	var n := fresh.size()
	var txt := ("На ваш город напали: %s" % _times(n)) if n > 1 else ("На ваш город напал «%s»" % fresh[0]["name"])
	if held == n:
		txt += " — отряд обороны отбился" + ("!" if n == 1 else " каждый раз!")
	elif held > 0:
		txt += ", отбились %s" % _times(held)
	else:
		txt += " — отряд обороны не устоял"
	_note(txt + ". Подробности — в «Легионе», вкладка «Против городов».", "shield")


static func _times(n: int) -> String:
	var w := "раз"
	if n % 10 in [2, 3, 4] and not (n % 100 in [12, 13, 14]):
		w = "раза"
	return "%d %s" % [n, w]


func _note(text: String, icon: String) -> void:
	var g = _game()
	if g != null and g.hud != null and String(g.mode) != "menu":
		g.hud.notify(text, icon)


## Вошли другой учёткой — всё, что знали о прежней, забыть
func _check_account() -> void:
	var t := _acc().token
	if t == _tok:
		return
	_tok = t
	me_state = {}
	_pub_hash = ""
	_pub_t = -1.0e9
	_chk_t = -1.0e9
	_state_t = -1.0e9
	_retry = []
	unsupported = false


## Итог боя с городом из 3D-боя — сразу по окончании (вдруг игру закроют на экране итога)
func _hook() -> void:
	var lg := _lg()
	if lg == null or lg == _hooked:
		return
	_hooked = lg
	lg.battle_requested.connect(_on_battle_requested)


func _on_battle_requested(setup: Dictionary) -> void:
	if String(setup.get("kind", "")) != "pvp":
		return
	await get_tree().process_frame
	var b = LegionBattle.current
	if b != null and is_instance_valid(b) and b.setup == setup:
		b.finished.connect(func(out: Dictionary): pvp_report(setup, out), CONNECT_ONE_SHOT)


# ---------- запросы ----------

## Понятная фраза об ошибке (целая — окно показывает её как есть); last_fail — она же с заголовком и кодом для окна.
## short — коротко, для строки внизу окна (нападение, название города); иначе — с советом нажать «Повторить»
func _err(r: Dictionary, short := false, who := "Сервер боёв") -> String:
	var code := int(r["status"])
	var f := NetHttp.explain(r, who, NetHttp.AGAIN)
	if code == 401:
		f["title"] = "Вход устарел"
		f["text"] = "Вход устарел — войдите в аккаунт снова (Меню → Настройки)."
		f["short"] = f["text"]
	elif code == 404 and unsupported:
		f["title"] = "Бои с городами — скоро"
		f["text"] = "Сервер ещё не умеет бои с городами — загляните позже."
		f["short"] = f["text"]
	elif code != 0 and not (code in [502, 503, 504]):
		f["title"] = "Не получилось"
	last_fail = f
	return String(f["short"] if short else f["text"])


func _call(method: int, path: String, body = null) -> Dictionary:
	var a := _acc()
	if a.token == "":
		return {"status": 401, "data": {}, "error": "Нужно войти", "net": ""}
	# ответы боёв небольшие — без сжатия: сжатый ответ сервер шлёт кусками, а это лишний повод для сбоя в пути.
	# Повтор при сбое связи (NetHttp) тут безопасен: итог боя сервер принимает один раз, нападение на ту же цель — тоже
	var r: Dictionary = await NetHttp.fetch(self, a.api, method, path, body, a.token, {"timeout": TIMEOUT, "accept_gzip": false})
	var code := int(r["status"])
	var d: Dictionary = r["data"]
	if code == 404 and path.begins_with("/pvp/") and path != "/pvp/name" and not d.has("me"):
		var e := str(d.get("error", ""))
		if e == "Нет такого адреса" or e == "":
			unsupported = true                      # старый сервер без боёв с городами
	if code == 401 and a.required() and a.has_method("_session_lost"):
		a._session_lost()                           # вход устарел — Account покажет окно входа (только в настоящей игре)
	last_error = "" if code == 200 else (String(r["net"]) if code == 0 else str(code))
	return r


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
