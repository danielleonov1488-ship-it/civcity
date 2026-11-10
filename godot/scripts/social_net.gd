class_name SocialNet
extends Node
## Друзья и гости по сети («Уютный Рим», этап 6 — онлайн-уют; сервер — server/social.js, docs/ONLINE_V2.md).
## Вход и адрес сервера — у Account (тот же токен и api). Один узел на всю игру (SocialNet.me()), висит под корнем
## дерева, как Account и LegionNet, и переживает перезапуск сцены.
##
## Сам по себе (раз в POLL с проверяет), только в настоящей игре (свой город, новая игра «Уютного Рима»):
##   - выставляет карточку города (население, ранг, титул, известность, достопримечательности, имя героя), если поменялась;
##   - раз в STATE_GAP забирает state: друзья, подарки (забирает и раздаёт городу сам — украшения даром, кошки),
##     гости (города, откуда едут туристы: Tourism одевает по ним гостей и платит за них больше);
##   - раз в VISIT_GAP сообщает, из каких городов гости у нас побывали (им — известность).
## Для окна «Друзья» (FriendsUi): state, refresh(cb), find(name, cb), add_friend(name_or_id, cb), unfriend(id, cb),
##   gift(id, kind, cb), visit(id, cb) — открыть чужой город (Game.visit_city), like(id, cb).

signal changed

const POLL := 10.0
const STATE_GAP := 300.0
const CARD_GAP := 600.0
const VISIT_GAP := 300.0
const TIMEOUT := 12.0
const VISIT_TIMEOUT := 40.0                   # город целиком — до мегабайта
## Подарки: вид → [тип постройки, сколько штук даром] (cat — кошка приходит в дом); названия — от сервера
const GIFT_BUILD := {"flowers": ["flowers", 3], "bench": ["bench", 2], "amphorae": ["amphorae", 3], "statue": ["statue_3", 1], "fountain": ["fountain", 1]}
const GIFT_ICON := {"cat": "cat", "flowers": "flower", "bench": "decor", "amphorae": "amphora", "statue": "caesar", "fountain": "water"}
## Туристы из других городов: за каждый город-друг в списке гостей +6% дохода гостиниц, за прочий +3%, не больше +40%
const BONUS_FRIEND := 0.06
const BONUS_OTHER := 0.03
const BONUS_MAX := 0.4

var state := {}                               # последний ответ /social/state: me, friends, inbox, guests, gifts
var unsupported := false                      # старый сервер без /api/social (404)
var last_fail := ""
var force_on := false                         # проверки: и без настоящей игры
var visited := {}                             # id города → гости из него побывали у нас (ещё не сообщили)

var _state_t := -1.0e9
var _card_t := -1.0e9
var _visit_t := -1.0e9
var _card_hash := ""
var _tok := ""
var _busy := false
var _claiming := false

static var _inst: SocialNet = null


static func me() -> SocialNet:
	if _inst == null or not is_instance_valid(_inst):
		_inst = SocialNet.new()
		_inst.name = "SocialNet"
		(Engine.get_main_loop() as SceneTree).root.add_child(_inst)
	return _inst


## Есть ли узел и знает ли он гостей (City.sim_day и Tourism зовут без создания узла)
static func live() -> SocialNet:
	return _inst if _inst != null and is_instance_valid(_inst) else null


## Прибавка к доходу гостиниц за туристов из других городов (0 — без входа, без сервера, в старой игре)
static func tour_bonus(city) -> float:
	var s := live()
	if s == null or city == null or int(city.get("cozy_v")) < 1 or not s.ready_now():
		return 0.0
	var k := 0.0
	for g: Dictionary in s.state.get("guests", []):
		k += BONUS_FRIEND if bool(g.get("friend", false)) else BONUS_OTHER
	return minf(BONUS_MAX, k)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var t := Timer.new()
	t.wait_time = POLL
	t.autostart = true
	t.timeout.connect(_tick)
	add_child(t)


func _acc() -> Account:
	return Account.me()


func _game():
	var a := _acc()
	return a.game if a.game != null and is_instance_valid(a.game) else null


func signed_in() -> bool:
	return _acc().signed_in()


## Можно ли дружить и принимать гостей: вошли, идёт свой город «Уютного Рима», сервер умеет
func ready_now() -> bool:
	if unsupported or not signed_in():
		return false
	if force_on:
		return true
	var g = _game()
	var a := _acc()
	return a.required() and g != null and String(g.mode) in ["play", "new"] and g.city != null and int(g.city.cozy_v) >= 1 \
		and g.ready_done and a.net != "old"


func _check_account() -> void:
	var t := _acc().token
	if t == _tok:
		return
	_tok = t
	state = {}
	visited = {}
	_card_hash = ""
	_state_t = -1.0e9
	_card_t = -1.0e9
	_visit_t = -1.0e9
	unsupported = false


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _tick() -> void:
	_check_account()
	if _busy or not ready_now():
		return
	_busy = true
	var now := _now()
	if now - _card_t > CARD_GAP:
		await _publish_card()
	if not unsupported and now - _state_t > STATE_GAP:
		await refresh()
	if not unsupported and now - _visit_t > VISIT_GAP and not visited.is_empty():
		await _send_visits()
	_busy = false


# ---------- карточка города ----------

## Карточка: то, что видят друзья (окно «Друзья», «В гости»)
static func card_of(g) -> Dictionary:
	var c = g.city
	var sights := []
	var seen := {}
	var mons := []
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		var t := String(b["type"])
		var d: Dictionary = Defs.B.get(t, {})
		if String(d.get("kind", "")) != "monument" or seen.has(Defs.base_of(t)):
			continue
		seen[Defs.base_of(t)] = true
		mons.append([float(d.get("cost", 0)), String(d.get("name", t))])
	mons.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
	for m: Array in mons.slice(0, 6):
		sights.append(String(m[1]))
	var inns := 0
	for id in c.buildings:
		if String(c.buildings[id]["type"]) == "mansio":
			inns += 1
	var lv := clampi(int(c.level), 0, Defs.LEVELS.size() - 1)
	return {"pop": int(c.stats.get("pop", 0)), "level": int(c.level), "rank": String(Defs.LEVELS[lv]["name"]),
		"title": Renown.title_of(float(c.renown)) if Renown.on(c) else "", "fame": int(c.renown), "day": int(c.day),
		"hero": Hero.name_of(c) if Hero.exists(c) else "", "cats": c.cat_recs().size(), "inns": inns, "sights": sights}


func _publish_card() -> void:
	var g = _game()
	if g == null or g.city == null:
		return
	var card := card_of(g)
	var h := str(hash(JSON.stringify(card)))
	if h == _card_hash:
		_card_t = _now()
		return
	var r := await _call(HTTPClient.METHOD_PUT, "/social/card", {"card": card})
	if int(r["status"]) == 200:
		_card_hash = h
		_card_t = _now()
	elif not unsupported:
		_card_t = _now() - CARD_GAP + 60.0          # не вышло — ещё раз через минуту


# ---------- состояние, подарки ----------

func refresh(cb := Callable(), ack := false) -> void:
	var r := await _call(HTTPClient.METHOD_GET, "/social/state" + ("?ack=1" if ack else ""))
	if int(r["status"]) == 200:
		state = r["data"]
		_state_t = _now()
		_greet()
		_take_gifts()
		changed.emit()
		if cb.is_valid():
			cb.call("")
	else:
		_state_t = _now() - STATE_GAP + 60.0
		if cb.is_valid():
			cb.call(_err(r))


## Новые «нравится» и гости из нашего города у других — строкой в колокольчик (и подтвердить, что увидели)
func _greet() -> void:
	var m: Dictionary = state.get("me", {})
	var nl := int(m.get("new_likes", 0))
	var nv := int(m.get("new_visits", 0))
	if nl <= 0 and nv <= 0:
		return
	var g = _game()
	if g == null or g.city == null:
		return
	var parts := []
	if nv > 0:
		parts.append("горожане съездили в гости в %d %s" % [nv, _word(nv, "город", "города", "городов")])
	if nl > 0:
		parts.append("ваш город понравился %d %s" % [nl, _word(nl, "гостю", "гостям", "гостям")])
	# известность: за гостей из нашего города у других и за «нравится»
	if Renown.on(g.city):
		g.city.renown += 4.0 * nv + 6.0 * nl
	g.city._quiet("Друзья: %s" % ", ".join(PackedStringArray(parts)), "laurels")
	_call(HTTPClient.METHOD_GET, "/social/state?ack=1")


## Подарки из ящика — забрать и раздать городу (украшения даром, кошки приходят)
func _take_gifts() -> void:
	var inbox: Array = state.get("inbox", [])
	var g = _game()
	if inbox.is_empty() or _claiming or g == null or g.city == null or not (String(g.mode) in ["play", "new"]):
		return
	_claiming = true
	var ids := inbox.map(func(e): return int(e["id"]))
	var r := await _call(HTTPClient.METHOD_POST, "/social/claim", {"ids": ids})
	_claiming = false
	if int(r["status"]) != 200:
		return
	state["inbox"] = []
	for e: Dictionary in (r["data"] as Dictionary).get("claimed", []):
		apply_gift(g, String(e.get("kind", "")), String(e.get("from", "друг")), String(e.get("name", "")))
	changed.emit()


## Подарок городу: кошка приходит в дом, украшение — n штук даром (City.gifts)
static func apply_gift(g, kind: String, from: String, nm: String) -> void:
	var c = g.city
	if kind == "cat":
		var cat: Dictionary = g.people._new_cat() if g.people != null else {}
		if not cat.is_empty():
			var rec: Dictionary = c.cats[c.cats.size() - 1]
			rec["gift"] = from
			c._quiet("Подарок из «%s»: кошка %s пришла в город" % [from, String(rec["nm"])], "cat")
		else:
			c._quiet("Подарок из «%s»: кошка придёт, когда в городе будут жители" % from, "cat")
			c.gifts["@cat"] = (c.gifts.get("@cat", []) as Array) + [from]
		return
	if not GIFT_BUILD.has(kind):
		return
	var t := String(GIFT_BUILD[kind][0])
	var n := int(GIFT_BUILD[kind][1])
	var list: Array = c.gifts.get(t, [])
	for i in n:
		list.append(from)
	c.gifts[t] = list
	var dn := String((Defs.B.get(t, {}) as Dictionary).get("name", nm))
	c._quiet("Подарок из «%s»: %s — %s даром — найдите в стройке, он отмечен «Подарок»" % [from, dn.to_lower(), "%d шт." % n if n > 1 else "одна"], "mail")
	c.changed.emit()


# ---------- для окна ----------

func find(nm: String, cb: Callable) -> void:
	var r := await _call(HTTPClient.METHOD_GET, "/social/find?name=" + nm.uri_encode())
	cb.call((r["data"] as Dictionary).get("list", []) if int(r["status"]) == 200 else [], "" if int(r["status"]) == 200 else _err(r))


func add_friend(who, cb: Callable) -> void:
	var body := {"id": int(who)} if typeof(who) == TYPE_INT else {"name": String(who)}
	var r := await _call(HTTPClient.METHOD_POST, "/social/friend", body)
	if int(r["status"]) == 200:
		state = r["data"]
		changed.emit()
	cb.call("" if int(r["status"]) == 200 else _err(r))


func unfriend(id: int, cb: Callable) -> void:
	var r := await _call(HTTPClient.METHOD_POST, "/social/unfriend", {"id": id})
	if int(r["status"]) == 200:
		state = r["data"]
		changed.emit()
	cb.call("" if int(r["status"]) == 200 else _err(r))


func gift(id: int, kind: String, cb: Callable) -> void:
	var r := await _call(HTTPClient.METHOD_POST, "/social/gift", {"id": id, "kind": kind})
	if int(r["status"]) == 200:
		(state.get("me", {}) as Dictionary)["gifts_left"] = int((r["data"] as Dictionary).get("gifts_left", 0))
		changed.emit()
	cb.call("" if int(r["status"]) == 200 else _err(r))


func like(id: int, cb: Callable) -> void:
	var r := await _call(HTTPClient.METHOD_POST, "/social/like", {"id": id})
	cb.call(r["data"] if int(r["status"]) == 200 else {}, "" if int(r["status"]) == 200 else _err(r))


## Чужой город целиком (посмотреть): cb(data: {id, name, card, likes, friend, liked, data}, err)
func visit(id: int, cb: Callable) -> void:
	var r := await _call(HTTPClient.METHOD_GET, "/social/city?id=%d" % id, null, VISIT_TIMEOUT)
	cb.call(r["data"] if int(r["status"]) == 200 else {}, "" if int(r["status"]) == 200 else _err(r))


## Гости этого города побывали у нас (Tourism — когда выходит группа гостей из этого города)
func mark_visit(id: int) -> void:
	if id > 0:
		visited[id] = true


func _send_visits() -> void:
	var ids := visited.keys()
	visited = {}
	_visit_t = _now()
	await _call(HTTPClient.METHOD_POST, "/social/visited", {"ids": ids})


## Город-гость для группы туристов: {id, name, hero, friend} или {} (по кругу, друзья чаще)
func guest_pick(rng: RandomNumberGenerator) -> Dictionary:
	var gl: Array = state.get("guests", [])
	if gl.is_empty() or not ready_now():
		return {}
	var w := []
	for gg: Dictionary in gl:
		w.append(2.0 if bool(gg.get("friend", false)) else 1.0)
	var sum := 0.0
	for x in w:
		sum += float(x)
	var r := rng.randf() * sum
	for i in gl.size():
		r -= float(w[i])
		if r <= 0.0:
			return gl[i]
	return gl[gl.size() - 1]


# ---------- запросы ----------

func _err(r: Dictionary) -> String:
	var code := int(r["status"])
	if code == 401:
		last_fail = "Вход устарел — войдите в аккаунт снова (Меню → Настройки)."
	elif code == 404 and unsupported:
		last_fail = "Сервер ещё не умеет друзей — загляните позже."
	else:
		last_fail = String(NetHttp.explain(r, "Сервер друзей", NetHttp.AGAIN)["short"])
	return last_fail


func _call(method: int, path: String, body = null, timeout := TIMEOUT) -> Dictionary:
	var a := _acc()
	if a.token == "":
		return {"status": 401, "data": {}, "error": "Нужно войти", "net": ""}
	var r: Dictionary = await NetHttp.fetch(self, a.api, method, path, body, a.token, {"timeout": timeout, "accept_gzip": path.begins_with("/social/city")})
	var code := int(r["status"])
	var d: Dictionary = r["data"] if typeof(r["data"]) == TYPE_DICTIONARY else {}
	if code == 404 and path.begins_with("/social/state") and (str(d.get("error", "")) in ["Нет такого адреса", ""]):
		unsupported = true                          # старый сервер без друзей
	if code == 401 and a.required() and a.has_method("_session_lost"):
		a._session_lost()
	return r


static func _word(n: int, one: String, few: String, many: String) -> String:
	var m := n % 100
	if m >= 11 and m <= 14:
		return many
	match n % 10:
		1:
			return one
		2, 3, 4:
			return few
	return many
