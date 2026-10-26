class_name StoryOrders
extends RefCounted
## «Заказы старосты» (этап 7.4): между историями староста просит украсить уголок города — три фонаря и две скамьи у
## станции, кипарисы у храма… Одна строка в «Просьбах горожан», только по желанию игрока: сама не открывается и камеру
## не двигает. «Взяться» — и в счёт идёт то, что поставлено после этого рядом с нужным местом (у курсора видно, в счёт
## ли украшение; край места светится, пока оно в руках). Награда — очки исследований, Слава, иногда редкий облик украшения
## (не деньги, Д7). Когда заказы уровня сделаны — те же снова, вдвое больше (и награда вдвое, без облика); но тот же
## заказ — не раньше чем через двое суток, а повторы — не чаще раза в 6 ч (не ферма очков и Славы через снос за полцены).
## Ведёт узел Stories (scripts/stories.gd): tick, строка, место для пятна и подписи у курсора.
## Состояние — city.stories["orders"]: {cur, taken, id0, since, last_h, gap, n: {id: сколько раз сделан}, skip: {id: до часа},
## done_h: {id: в какой час сделан последний раз}}.

const GAP_H := 1                       # новый заказ — через час после прошлого
const REPEAT_H := 48                   # тот же заказ снова — не раньше чем через двое суток после того, как его сделали
const REPEAT_GAP_H := 6                # на втором круге повторы — не чаще раза в 6 ч (делали заказ дольше — следующий через час)
const SKIP_H := 48                     # «Другой заказ»: этот — не раньше чем через двое суток
const SHOW_MS := 10000                 # «Показать»: мягкое пятно у места заказа столько мс
const ICON := "laurels"

## Заказы по порядку: lvl — с какого уровня города; anchor — у чего ("center" — станция, иначе тип постройки: ближняя
## к станции; условия уровней обещают, что к этому уровню она уже стоит); r — в скольких метрах; need [[вид, n, подпись]]
## (вид — как у историй: тип, облик, «a|b»; «=тип» — только этот облик); none — этого рядом быть не должно (заменить
## деревянные скамьи мраморными); rp, glory — награда; unlock — редкий облик украшения (первый раз)
const ORDERS := [
	{"id": "o_lamps", "lvl": 1, "title": "3 фонаря и 2 скамьи у станции", "anchor": "center", "r": 25.0,
		"need": [["lamp_post", 3, "Фонари на столбах"], ["bench", 2, "Скамьи"]], "rp": 15, "glory": 1},
	{"id": "o_trees", "lvl": 1, "title": "Все три дерева у скриптория", "anchor": "scriptorium", "r": 20.0,
		"need": [["tree", 1, "Дерево"], ["cypress", 1, "Кипарис"], ["palm", 1, "Пальма"]], "rp": 15, "glory": 1},
	{"id": "o_well", "lvl": 1, "title": "Колодец и 4 клумбы у станции", "anchor": "center", "r": 25.0,
		"need": [["well", 1, "Колодец"], ["flowers|planter", 4, "Клумбы или вазы"]], "rp": 20, "glory": 1, "unlock": "o_well"},
	{"id": "o_market", "lvl": 2, "title": "Рынок у склада: 2 телеги и 3 корзины", "anchor": "warehouse", "r": 20.0,
		"need": [["cart", 2, "Телеги с товаром"], ["goods", 3, "Корзины с товаром"]], "rp": 40, "glory": 2},
	{"id": "o_fountain", "lvl": 2, "title": "Фонтанчик и цветы на стенах у станции", "anchor": "center", "r": 30.0,
		"need": [["smallfountain", 1, "Фонтанчик"], ["wall_flowers", 2, "Цветы на стенах"]], "rp": 40, "glory": 2},
	{"id": "o_yard", "lvl": 2, "title": "Двор с плетнём у станции", "anchor": "center", "r": 30.0,
		"need": [["fence", 6, "Звенья плетня"], ["hay", 1, "Стог сена"]], "rp": 45, "glory": 2, "unlock": "o_yard"},
	{"id": "o_school", "lvl": 3, "title": "Тень у школы: 3 кипариса и солнечные часы", "anchor": "school", "r": 20.0,
		"need": [["cypress", 3, "Кипарисы"], ["sundial", 1, "Солнечные часы"]], "rp": 70, "glory": 3},
	{"id": "o_statues", "lvl": 3, "title": "Колонна и 2 статуи у фонтана", "anchor": "fountain", "r": 25.0,
		"need": [["statue", 2, "Статуи"], ["column", 1, "Колонна со статуей"]], "rp": 70, "glory": 3},
	{"id": "o_benches", "lvl": 3, "title": "Мраморные скамьи вместо деревянных у станции", "anchor": "center", "r": 25.0,
		"need": [["=bench", 3, "Мраморные скамьи"]], "none": ["bench_2"], "rp": 80, "glory": 3, "unlock": "o_benches"},
	{"id": "o_cypress", "lvl": 4, "title": "Кипарисы у храма", "anchor": "temple", "r": 30.0,
		"need": [["cypress", 6, "Кипарисы"]], "rp": 120, "glory": 4},
	{"id": "o_games", "lvl": 4, "title": "Знамёна и огни к играм у станции", "anchor": "center", "r": 30.0,
		"need": [["banner|wall_banner", 4, "Знамёна"], ["brazier|bigbrazier", 2, "Жаровни"]], "rp": 120, "glory": 4},
	{"id": "o_park", "lvl": 4, "title": "Беседка и цветник у фонтана", "anchor": "fountain", "r": 25.0,
		"need": [["pergola", 1, "Беседка"], ["flowers|planter", 6, "Клумбы или вазы"]], "rp": 130, "glory": 4, "unlock": "o_park"},
	{"id": "o_domus", "lvl": 5, "title": "Сад у домусов", "anchor": "house_patrician", "r": 20.0,
		"need": [["tree|cypress|palm", 4, "Деревья"], ["flowers|planter", 4, "Клумбы или вазы"], ["pergola", 1, "Беседка"]], "rp": 200, "glory": 5},
	{"id": "o_lions", "lvl": 5, "title": "Два льва у библиотеки", "anchor": "library", "r": 25.0,
		"need": [["lion", 2, "Золотые львы"]], "rp": 200, "glory": 5},
	{"id": "o_night", "lvl": 5, "title": "Вечерний свет у станции", "anchor": "center", "r": 35.0,
		"need": [["candelabrum|brazier|lamp_post", 6, "Светильники, жаровни или фонари"]], "rp": 220, "glory": 5, "unlock": "o_night"},
	{"id": "o_forum", "lvl": 6, "title": "Статуи у форума", "anchor": "forum", "r": 35.0,
		"need": [["statue", 4, "Статуи"]], "rp": 320, "glory": 6},
	{"id": "o_waters", "lvl": 6, "title": "Три фонтанчика у домусов", "anchor": "house_patrician", "r": 30.0,
		"need": [["smallfountain", 3, "Фонтанчики"]], "rp": 320, "glory": 6},
	{"id": "o_temple", "lvl": 6, "title": "Большие огни у храма", "anchor": "temple", "r": 30.0,
		"need": [["bigbrazier", 4, "Большие жаровни"]], "rp": 350, "glory": 6, "unlock": "o_temple"},
	{"id": "o_grove", "lvl": 7, "title": "Роща у академии", "anchor": "academy", "r": 30.0,
		"need": [["tree|cypress|palm", 8, "Деревья"]], "rp": 500, "glory": 8},
	{"id": "o_triumph", "lvl": 7, "title": "Триумфальная дорога у станции", "anchor": "center", "r": 40.0,
		"need": [["banner", 6, "Знамёна на шестах"], ["statue", 4, "Статуи"]], "rp": 500, "glory": 8},
	{"id": "o_eternal", "lvl": 7, "title": "Вечный сад у форума", "anchor": "forum", "r": 35.0,
		"need": [["pergola", 2, "Беседки"], ["lion", 2, "Золотые львы"], ["column", 1, "Колонна со статуей"]], "rp": 550, "glory": 8, "unlock": "o_eternal"},
]

## «у станции», «у скриптория» — где место заказа (для подписи у курсора и строки)
const AT := {"center": "станции", "scriptorium": "скриптория", "warehouse": "склада", "school": "школы", "fountain": "фонтана",
	"temple": "храма", "house_patrician": "домуса", "library": "библиотеки", "forum": "форума", "academy": "академии"}

var st                                 # Stories
var _show_until := 0


func _init(s) -> void:
	st = s


func city() -> City:
	return st.city


## Состояние заказов (в сохранении — city.stories["orders"]; старые сохранения — пусто)
func S() -> Dictionary:
	var s: Dictionary = st.city.stories
	if typeof(s.get("orders")) != TYPE_DICTIONARY:
		s["orders"] = {}
	var o: Dictionary = s["orders"]
	if typeof(o.get("n")) != TYPE_DICTIONARY:
		o["n"] = {}
	if typeof(o.get("skip")) != TYPE_DICTIONARY:
		o["skip"] = {}
	if typeof(o.get("done_h")) != TYPE_DICTIONARY:
		o["done_h"] = {}
	return o


static func order(id: String) -> Dictionary:
	for o: Dictionary in ORDERS:
		if String(o["id"]) == id:
			return o
	return {}


## Заказ, что сейчас в строке (предложен или взят), или {}
func cur() -> Dictionary:
	return order(String(S().get("cur", "")))


func taken() -> bool:
	return not cur().is_empty() and bool(S().get("taken", false))


func times(id: String) -> int:
	return int((S()["n"] as Dictionary).get(id, 0))


## Во сколько раз больше (и щедрее): первый раз — как есть, потом — вдвое
func mult(id: String) -> int:
	return 1 if times(id) == 0 else 2


## Где место заказа: станция или ближняя к ней постройка нужного типа (Vector2.INF — такой нет)
func anchor_pos(o: Dictionary) -> Vector2:
	var c := city()
	var ctr := c.center()
	var c0: Vector2 = ctr["pos"] if not ctr.is_empty() else Land.CENTER
	var an := String(o.get("anchor", "center"))
	if an == "center":
		return c0
	var best := Vector2.INF
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		if b["type"] == an and (best == Vector2.INF or (b["pos"] as Vector2).distance_to(c0) < best.distance_to(c0)):
			best = b["pos"]
	return best


## Вид из заказа: «=bench» — только этот облик, иначе — как у историй
static func _key(k: String) -> String:
	return k.trim_prefix("=")


## Сколько этого вида в счёт заказа: в r м от места, поставлено после «Взяться» (born ≥ id0); «=тип» — только этот облик
func count(o: Dictionary, key: String, after := -2) -> int:
	var c := city()
	var p := anchor_pos(o)
	if p == Vector2.INF:
		return 0
	if after == -2:
		after = int(S().get("id0", 0))
	if not key.begins_with("="):
		return Stories.count_near(c, key, p, float(o["r"]), after)
	var t := key.substr(1)
	var n := 0
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		if b["type"] == t and (b["pos"] as Vector2).distance_to(p) <= float(o["r"]) and int(b.get("born", id)) >= after:
			n += 1
	return n


## Чего рядом быть не должно, а стоит (деревянные скамьи): сколько
func extra(o: Dictionary) -> int:
	var n := 0
	for t in o.get("none", []):
		n += count(o, "=" + String(t), -1)
	return n


## Хоть один облик этого вида уже открыт (иначе заказ не предлагаем — его нельзя сделать)
func _open(key: String) -> bool:
	for k in _key(key).split("|"):
		for t in Defs.looks_of(k):
			if city().unlocked(t):
				return true
		if Defs.B.has(k) and city().unlocked(k):
			return true
	return false


## Заказ можно предложить: уровень, место стоит, всё нужное открыто
func can(o: Dictionary) -> bool:
	if city().level < int(o["lvl"]) or anchor_pos(o) == Vector2.INF:
		return false
	for e: Array in o["need"]:
		if not _open(String(e[0])):
			return false
	return true


## Следующий заказ: из тех, что можно, — реже всех сделанный, по порядку списка; отложенные («Другой заказ») — позже
func next_order() -> Dictionary:
	var best := {}
	var bt := 1 << 30
	var h := int(st.city.stories.get("h", 0))
	var skip: Dictionary = S()["skip"]
	var dh: Dictionary = S()["done_h"]
	for o: Dictionary in ORDERS:
		if h < int(skip.get(String(o["id"]), -1)) or not can(o):
			continue
		if times(String(o["id"])) > 0 and h < int(dh.get(String(o["id"]), -999)) + REPEAT_H:
			continue                              # этот недавно сделали: не раньше чем через двое суток
		var t := times(String(o["id"]))
		if t < bt:
			bt = t
			best = o
	return best


## Пора ли заказам: после обучения, с «Хутора», когда строка просьб уже видна
func allowed() -> bool:
	var c := city()
	if c == null or not st.allowed() or c.level < 1 or int(c.tips.get("tut", -1)) >= 0 or st.hud.ui_level() < 3:
		return false
	return true


## Раз в полсекунды (из Stories.tick): предложить новый заказ, проверить взятый
func tick() -> void:
	if not allowed():
		return
	var o := S()
	var h := int(st.city.stories.get("h", 0))
	var cu := cur()
	if String(o.get("cur", "")) != "" and (cu.is_empty() or anchor_pos(cu) == Vector2.INF):
		_drop()                                   # места заказа больше нет (снесли храм): заказ снимаем молча
		return
	if cu.is_empty():
		if h - int(o.get("last_h", -999)) < int(o.get("gap", GAP_H)):
			return
		var now := bool(o.get("now", false))      # «Другой заказ»: игрок сам попросил — сразу, без передышки
		if not first_ok(h) or (not now and (not st.pace_ok() or st.story_soon(h))):
			return                                # спокойный темп: не в один час с историей и новым рангом; история вот-вот — уступаем
		var nx := next_order()
		if nx.is_empty():
			o.erase("now")                        # заменить сразу нечем — следующий придёт в спокойном темпе
			return
		o["cur"] = String(nx["id"])
		o["taken"] = false
		o["since"] = h
		o.erase("now")
		st.pace_mark()
		st.hud.refresh()
		_advise_once()
		return
	_advise_once()                            # заказ пришёл в ролик ранга или при другом совете: объясним, когда советник свободен
	if taken() and done():
		complete()


## Первый заказ на «Хуторе» — когда «Где Мася?» пройдена (первые минуты — история, не всё разом), или через
## Stories.ORDER_WAIT_H, если её отложили или не взялись; с «Деревни» (и у городов, где заказы уже были) — как всегда
func first_ok(h: int) -> bool:
	var o := S()
	if not st.pacing() or city().level != 1 or not (o["n"] as Dictionary).is_empty() or bool(o.get("first", false)):
		return true
	if int(o.get("wait0", -1)) < 0:
		o["wait0"] = h
	if (st.S()["done"] as Dictionary).has("cat") or h - int(o["wait0"]) >= Stories.ORDER_WAIT_H:
		o["first"] = true
		return true
	return false


func _drop() -> void:
	var o := S()
	o["cur"] = ""
	o["taken"] = false
	o["last_h"] = int(st.city.stories.get("h", 0))
	o.erase("now")
	st._marks(true)
	st.hud.refresh()


## «Взяться»: с этой минуты в счёт идёт то, что поставлено рядом с местом
func take() -> void:
	var o := S()
	if cur().is_empty():
		return
	o["taken"] = true
	o["id0"] = city().next_id
	st._marks(true)
	st.hud.refresh()


## «Другой заказ»: этот — потом, а сейчас — следующий
func skip() -> void:
	var o := S()
	var id := String(o.get("cur", ""))
	if id == "":
		return
	(o["skip"] as Dictionary)[id] = int(st.city.stories.get("h", 0)) + SKIP_H
	o["cur"] = ""
	o["taken"] = false
	o["last_h"] = int(st.city.stories.get("h", 0)) - int(o.get("gap", GAP_H))     # следующий — сразу
	o["now"] = true
	st._marks(true)
	st.hud.refresh()
	tick()                                    # следующий — по щелчку, раньше истории, что могла бы прийти в этот же час


## Сколько нужно (второй раз и дальше — вдвое): [[вид, n, подпись]]
func need_of(o: Dictionary) -> Array:
	var k := mult(String(o["id"]))
	var out := []
	for e: Array in o["need"]:
		out.append([String(e[0]), int(e[1]) * k, String(e[2])])
	return out


func done() -> bool:
	var o := cur()
	if o.is_empty():
		return false
	for e: Array in need_of(o):
		if count(o, String(e[0])) < int(e[1]):
			return false
	return extra(o) == 0


## Награда (без денег): очки исследований и Слава вдвое со второго раза; облик — только первый раз
func reward_of(o: Dictionary) -> Dictionary:
	var k := mult(String(o["id"]))
	var r := {"rp": int(o.get("rp", 0)) * k, "glory": int(o.get("glory", 0)) * k}
	if times(String(o["id"])) == 0 and o.has("unlock"):
		r["unlock"] = String(o["unlock"])
	return r


static func look_of(unlock: String) -> String:
	for t in Defs.B:
		if String(Defs.B[t].get("unlock", "")) == unlock:
			return t
	return ""


func reward_text(o: Dictionary) -> String:
	var r := reward_of(o)
	var out := ["+%d очков исследований" % int(r["rp"]), "+%d Славы" % int(r["glory"])]
	if r.has("unlock"):
		var t := look_of(String(r["unlock"]))
		if t != "":
			out.append("редкое украшение «%s»" % Defs.B[t]["name"])
	return ", ".join(out)


## Заказ выполнен: награда (рп — сколько уместится на полках, честно), в колокольчик, монетки; следующий — через GAP_H
func complete() -> void:
	var c := city()
	var o := cur()
	var s := S()
	var r := reward_of(o)
	var out := []
	var was := c.rp
	c.rp = maxf(c.rp, minf(c.rp_cap(), c.rp + float(r["rp"])))
	var got := int(round(c.rp - was))
	if got >= int(r["rp"]):
		out.append("+%d очков исследований" % got)
	elif got > 0:
		out.append("+%d очков исследований (больше не уместилось на полках)" % got)
	else:
		out.append("очки исследований не уместились — полки полны")
	c.legion.glory += int(r["glory"])
	out.append("+%d Славы" % int(r["glory"]))
	if r.has("unlock"):
		c.research[String(r["unlock"])] = true
		var t := look_of(String(r["unlock"]))
		if t != "":
			out.append("редкое украшение «%s» (Украшения)" % Defs.B[t]["name"])
	var id := String(o["id"])
	(s["n"] as Dictionary)[id] = times(id) + 1
	var h := int(c.stories.get("h", 0))
	(s["done_h"] as Dictionary)[id] = h
	# повтор: следующий заказ — не раньше чем через REPEAT_GAP_H от появления этого (кто делает за минуту — ждёт;
	# кто строил как обычно, по часам, — через час, как на первом круге)
	s["gap"] = GAP_H if times(id) == 1 else maxi(GAP_H, REPEAT_GAP_H - (h - int(s.get("since", h))))
	s["cur"] = ""
	s["taken"] = false
	s["last_h"] = int(c.stories.get("h", 0))
	c._quiet("Заказ старосты выполнен: %s. Награда: %s." % [String(o["title"]).to_lower().left(1) + String(o["title"]).substr(1), ", ".join(out)], ICON)
	if st.game.sound:
		st.game.sound.ui("coins")       # из звуков интерфейса — только монетки
	c.compute()
	st._marks(true)
	st.hud.refresh()


## Строки заказа с ✓: [{text, ok, do}] — do: что взять (Hud.need_do-вид: «build» с типом), снять лишнее — «Снос»
func parts() -> Array:
	var o := cur()
	if o.is_empty():
		return []
	var out := []
	for e: Array in need_of(o):
		var n := count(o, String(e[0]))
		var ok := n >= int(e[1])
		var t := _pick_type(String(e[0]))
		out.append({"text": "%s %d/%d" % [String(e[2]), mini(n, int(e[1])), int(e[1])], "ok": ok, "type": t,
			"do": {} if ok or t == "" else st.hud._do_type(t)})
	var x := extra(o)
	if x > 0:
		var nm := String(Defs.B.get(String((o.get("none", [""]) as Array)[0]), {}).get("name", "")).to_lower()
		out.append({"text": "Ещё стоит: %s — %d (снесите)" % [nm, x], "ok": false, "type": "", "do": {"kind": "bulldoze", "tip": "Снос"}})
	return out


## Какой облик взять для вида: первый открытый («flowers|planter» → клумба)
func _pick_type(key: String) -> String:
	for k in _key(key).split("|"):
		if key.begins_with("=") and Defs.B.has(k) and city().unlocked(k):
			return k
		for t in Defs.looks_of(k):
			if city().unlocked(t):
				return t
	return ""


## Строка в «Просьбах горожан»: {title, text, icon, tip, buttons, parts, waiting} или {}
func row_info() -> Dictionary:
	if not allowed():
		return {}
	var o := cur()
	if o.is_empty():
		return {}
	var k := mult(String(o["id"]))
	var title := String(o["title"]) + (" — вдвое больше" if k > 1 else "")
	var info := {"title": "Заказ старосты", "icon": ICON, "text": title, "waiting": not taken(),
		"tip": "Староста просит: %s (в %d м от %s).\nНаграда: %s. Денег староста не платит — у него свой интерес: красивый город." \
			% [String(o["title"]).to_lower(), int(o["r"]), String(AT.get(String(o["anchor"]), "места")), reward_text(o)]}
	if not taken():
		info["text"] = title + ". Награда: " + reward_text(o) + "."
		info["buttons"] = [["Взяться", take], ["Другой заказ", skip]]
	else:
		info["parts"] = parts()
		info["buttons"] = [["Показать", show], ["Другой заказ", skip]]
	return info


## Щелчок по строке заказа: взять нужное украшение и показать место
func part_click(p: Dictionary) -> void:
	var w: Dictionary = p.get("do", {})
	if String(w.get("kind", "")) == "bulldoze":
		st.game.set_tool("bulldoze")
	elif not w.is_empty():
		st.hud._do_click(w)
	show()


## «Показать»: камера к месту заказа, мягкое пятно на 10 с (сам заказ камеру не двигает)
func show() -> void:
	var o := cur()
	if o.is_empty():
		return
	var p := anchor_pos(o)
	if p == Vector2.INF:
		return
	st.game.rig.look_at_point(Vector3(p.x, st.game.land.height_at(p.x, p.y), p.y))    # и перестаёт следовать за жителем
	_show_until = Time.get_ticks_msec() + SHOW_MS
	st._marks(true)


## Для подписи у курсора и ✓ над тем, что в счёт (Stories.zone_goals): место взятого заказа или {}.
## «=bench» остаётся точным (только мраморная скамья); none — чего не надо (у курсора: «… — не в счёт»)
func zone() -> Dictionary:
	if not taken():
		return {}
	var o := cur()
	var p := anchor_pos(o)
	if p == Vector2.INF:
		return {}
	var keys := []
	for e: Array in o["need"]:
		keys.append(String(e[0]))
	return {"hp": p, "r": float(o["r"]), "keys": keys, "label": "заказа", "no": "", "none": (o.get("none", []) as Array).duplicate(),
		"after": int(S().get("id0", 0)), "room": 0, "skip": [], "far": "Далеко от %s — не в счёт" % String(AT.get(String(o["anchor"]), "места"))}


## Идёт «Показать» (мягкое пятно у места заказа)
func showing() -> bool:
	return Time.get_ticks_msec() < _show_until


## Пятно у места заказа: [x, z, радиус, яркость, край] — пока в руках то, что идёт в счёт (край), или после «Показать»
func area(edge: bool) -> Array:
	var z := zone()
	if z.is_empty() or not (edge or showing()):
		return []
	var p: Vector2 = z["hp"]
	return [p.x, p.y, float(z["r"]), Stories.BUILD_GLOW, edge]


## Советник один раз: что такое заказы старосты (когда появился первый)
func _advise_once() -> void:
	var c := city()
	if c.tips.has("orders_tip") or not st.hud._tip_free() or st.kit != null:
		return
	c.tips["orders_tip"] = true
	st.hud.advisor("Заказы старосты", "Между историями староста просит украсить уголок города — строка «Заказ старосты» в «Просьбах горожан». Возьмитесь, когда захотите: в счёт пойдёт то, что вы поставите после этого рядом с нужным местом (с украшением в руках у курсора видно, в счёт ли оно). Не нравится заказ — «Другой заказ».\n\nДенег староста не платит, у него свой интерес — красивый город. А благодарит очками исследований, Славой, а иногда и редким украшением, какого нет в лавках.")
