extends Node
## Как часто приходят истории (этап 7, проверка без игры — только данные): правила предложения (FIRST_H после обучения,
## GAP_H после конца прошлой, ранг lvl — не ниже, исследования needs, порядок списка) прогоняем по времени рангов бота
## темпа (экономика v2 и Д9, сиды 5/7/11), каждая история — 5 минут игры (и строгий вариант — 12 минут).
## Печатает, на каком ранге какая история предложена, и проверяет:
##  - на каждом ранге 1–6 — хотя бы одна история (первая–третья партии: на «Городе» — пожар, на «Большом городе» — письмо сыну);
##  - на рангах 1–4 без историй подряд не дольше 25 минут (на 5–6 — печатаем: промежутки закроет четвёртая партия);
##  - «урок раньше нужды»: история с teaches предложена на ранг раньше, чем город станет тем рангом, чьи условия она готовит;
##  - очки исследований в награду — 40–60% средней цены исследования её ряда (никаких денег — Д7);
##  - с заказами старосты: минут, когда нет ни истории, ни заказа, — не больше 10% на каждом ранге 1–7;
##  - у каждого заказа место — постройка, которую условия уровня обещают к его рангу, и всё нужное открывается к нему.
## Итог: «CADENCE DONE fails=N».

## Часы игры, когда бот достиг ранга 0…7: экономика v2 + Д9 (Казармы по истории), сборки 35–36 (test_pace -- bot seed=N)
const RANK_H := {5: [0, 17, 42, 120, 205, 306, 437, 603], 7: [0, 17, 45, 132, 217, 309, 440, 612], 11: [0, 17, 45, 125, 208, 316, 434, 610]}
const TUT_H := 6                       # обучение кончается примерно на шестом часу (бот: первое исследование — t=4)
const H_MIN := 25.0 / 60.0             # минут в игровом часе (сутки — 600 с)
const ORDER_H := 9.6                   # заказ старосты делают за ~4 минуты
const STORY_RANKS := [1, 2, 3, 4, 5, 6]   # на каждом из этих рангов — хотя бы одна история (партии 1–3)
const GAP_STORIES_RANKS := [1, 2, 3, 4]   # тут историй хватает подряд, без промежутков дольше 25 минут
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print(("  ok   " if ok else "FAIL ") + what)


func _ready() -> void:
	print("== истории по рангам (5 минут на историю)")
	for seed in RANK_H:
		_run_seed(int(seed), 12.0, true)
	print("== строгий вариант (12 минут на историю) — только для сведения")
	for seed in RANK_H:
		_run_seed(int(seed), 29.0, false)
	_rewards()
	_orders()
	print("CADENCE DONE fails=", fails)
	get_tree().quit()


func _rank_at(rh: Array, h: float) -> int:
	var r := 0
	for i in rh.size():
		if h >= float(rh[i]):
			r = i
	return r


## Когда исследование открыто: ряд L — к середине ранга L (ряд 0 — сразу после обучения)
func _research_h(rh: Array, rid: String) -> float:
	var r := Defs.research(rid)
	if r.is_empty():
		return 0.0
	var L := int(r.get("lvl", 0))
	if L <= 0:
		return TUT_H
	return float(rh[L]) + 0.5 * (float(rh[mini(L + 1, rh.size() - 1)]) - float(rh[L]))


## Когда выполнено условие need_p (ремесленники для свадьбы — к «Посёлку», он их требует)
func _need_p_h(rh: Array, np: Array) -> float:
	var p: Array = np[0]
	if String(p[0]) == "cls" and String(p[1]) == "artisans":
		return float(rh[3])
	if String(p[0]) == "cls" and String(p[1]) == "patricians":
		return float(rh[5])
	return 0.0


func _ready_h(rh: Array, sd: Dictionary) -> float:
	var h := float(rh[int(sd.get("lvl", 0))])
	for r in sd.get("needs", []):
		h = maxf(h, _research_h(rh, String(r)))
	for np: Array in sd.get("need_p", []):
		h = maxf(h, _need_p_h(rh, np))
	return h


func _run_seed(seed: int, play_h: float, gate: bool) -> void:
	var rh: Array = RANK_H[seed]
	var end_h := float(rh[7])
	var done := {}
	var last_end := -1.0
	var active_until := -1.0
	var cover := []                       # [от, до) — часы, когда история предложена или идёт
	var offers := {}                      # ранг → [история…]
	var offer_rank := {}
	var h := float(TUT_H)
	while h < end_h:
		if active_until >= 0.0 and h >= active_until:
			last_end = active_until
			active_until = -1.0
		if active_until < 0.0:
			var ok_time := (last_end < 0.0 and h - TUT_H >= StoryDefs.FIRST_H) or (last_end >= 0.0 and h - last_end >= StoryDefs.GAP_H)
			if ok_time:
				for sd: Dictionary in StoryDefs.STORIES:
					var id := String(sd["id"])
					if done.has(id) or _ready_h(rh, sd) > h:
						continue
					done[id] = true
					active_until = h + play_h
					cover.append([h, active_until])
					var rk := _rank_at(rh, h)
					offer_rank[id] = rk
					if not offers.has(rk):
						offers[rk] = []
					(offers[rk] as Array).append(id)
					break
		h += 1.0
	var line := []
	for rk in range(1, 8):
		line.append("%s: %s" % [Defs.LEVELS[rk - 1]["name"] if rk > 0 else "", ", ".join(offers.get(rk - 1, [])) if offers.has(rk - 1) else "—"])
	print("  сид %d: %s" % [seed, " | ".join(line)])
	if not gate:
		return
	# хотя бы одна история на каждом ранге 1–6 и без историй — не дольше 25 минут (ранги 1–4)
	for rk in STORY_RANKS:
		check(offers.has(rk), "сид %d: на ранге «%s» есть история (%s)" % [seed, Defs.LEVELS[rk]["name"], offers.get(rk, [])])
	var t0 := float(rh[GAP_STORIES_RANKS[0]])
	var t1 := float(rh[GAP_STORIES_RANKS[-1] + 1])
	var longest := 0.0
	var t := t0
	var gap := 0.0
	while t < t1:
		var on := false
		for c: Array in cover:
			on = on or (t >= float(c[0]) and t < float(c[1]))
		gap = 0.0 if on else gap + 1.0
		longest = maxf(longest, gap)
		t += 1.0
	check(longest * H_MIN <= 25.0, "сид %d: на рангах 1–4 без истории подряд не дольше 25 мин (%.1f мин)" % [seed, longest * H_MIN])
	# ранги 5–6: самый долгий промежуток — для сведения (его закроют истории четвёртой партии, план 7.3)
	var l56 := 0.0
	var g56 := 0.0
	var t56 := float(rh[5])
	while t56 < float(rh[7]):
		var on56 := false
		for c: Array in cover:
			on56 = on56 or (t56 >= float(c[0]) and t56 < float(c[1]))
		g56 = 0.0 if on56 else g56 + 1.0
		l56 = maxf(l56, g56)
		t56 += 1.0
	print("  info сид %d: на рангах 5–6 без истории подряд до %.0f мин (четвёртая партия закроет)" % [seed, l56 * H_MIN])
	# урок раньше нужды: условия ранга i готовят во время ранга i−1
	for sd: Dictionary in StoryDefs.STORIES:
		for need_rank in sd.get("teaches", []):
			var rk := int(offer_rank.get(String(sd["id"]), 99))
			check(rk < int(need_rank), "сид %d: «%s» — на ранге «%s», раньше условий «%s»" % [seed, sd["title"],
				Defs.LEVELS[mini(rk, 7)]["name"] if rk < 99 else "не предложена", Defs.LEVELS[int(need_rank)]["name"]])
	# с заказами старосты: минут без истории и без заказа ≤ 10% на каждом ранге (заказ — всегда, кроме часа между ними;
	# когда все заказы, открытые к рангу, сделаны по разу, — второй круг: следующий через REPEAT_GAP_H)
	var firsts := 0                       # сколько заказов сделано в первый раз (с прошлых рангов тоже)
	for rk in range(1, 8):
		var a := float(rh[rk])
		var b := float(rh[mini(rk + 1, 7)]) if rk < 7 else a + 60.0
		var avail := 0
		for o: Dictionary in StoryOrders.ORDERS:
			avail += int(int(o["lvl"]) <= rk)
		var idle := 0.0
		var tot := 0.0
		var x := a
		var next_order := a                 # когда появится следующий заказ
		var order_until := -1.0
		var again := false                  # идущий заказ — повтор
		while x < b:
			if order_until >= 0.0 and x >= order_until:
				order_until = -1.0
				next_order = x + (maxf(StoryOrders.GAP_H, StoryOrders.REPEAT_GAP_H - ORDER_H) if again else StoryOrders.GAP_H)
			if order_until < 0.0 and x >= next_order:
				order_until = x + ORDER_H
				again = firsts >= avail
				if not again:
					firsts += 1
			var st_on := false
			for c: Array in cover:
				st_on = st_on or (x >= float(c[0]) and x < float(c[1]))
			if not st_on and order_until < 0.0:
				idle += 1.0
			tot += 1.0
			x += 1.0
		check(idle / maxf(1.0, tot) <= 0.10, "сид %d: ранг «%s»: без истории и заказа %.0f%% минут" % [seed, Defs.LEVELS[rk]["name"], 100.0 * idle / maxf(1.0, tot)])


## Награды историй: очки исследований — 40–60% средней цены исследования своего ряда; денег — никогда
func _rewards() -> void:
	print("== награды историй")
	for sd: Dictionary in StoryDefs.STORIES:
		var r: Dictionary = sd.get("reward", {})
		check(not r.has("money"), "«%s»: награда без денег" % sd["title"])
		if not r.has("rp"):
			continue
		var lvl := int(sd.get("lvl", 0))
		var sum := 0.0
		var n := 0
		for rr: Dictionary in Defs.RESEARCH:
			# наборы украшений этапа 5 (и «главные») — не в счёт: они дешевле основных исследований ряда
			if int(rr["lvl"]) == lvl and String(rr["id"]) != "legion" and String(rr["id"]) != "archery" and not (String(rr["id"]) in Defs.DECOR_SETS or String(rr["id"]).begins_with("prem_")):
				sum += float(rr["cost"])
				n += 1
		var avg := sum / maxf(1.0, n)
		var k := float(r["rp"]) / avg
		check(k >= 0.38 and k <= 0.62, "«%s»: +%d очков — %.0f%% средней цены ряда «%s» (%.0f)" % [sd["title"], int(r["rp"]), k * 100.0, Defs.LEVELS[lvl]["name"], avg])
		check(r.has("unlock") and Defs.unlock_text(String(r["unlock"])) != "", "«%s»: своё украшение в награду (%s)" % [sd["title"], r.get("unlock", "")])


## Заказы старосты: на каждом ранге 1–7 — хотя бы два; место — постройка, которую условия уровня обещают к его рангу;
## всё нужное открывается исследованием не позже его ряда (или наградой просьбы); награда — очки и Слава, без денег
func _orders() -> void:
	print("== заказы старосты")
	var per := {}
	for o: Dictionary in StoryOrders.ORDERS:
		per[int(o["lvl"])] = int(per.get(int(o["lvl"]), 0)) + 1
		var lvl := int(o["lvl"])
		var an := String(o["anchor"])
		var an_ok := an == "center"
		if not an_ok:
			for rk in range(1, lvl + 1):
				for e: Dictionary in Defs.LEVELS[rk]["need"]:
					var p: Array = e["p"]
					an_ok = an_ok or (String(p[0]) == "count" and String(p[1]) == an)
		check(an_ok, "заказ «%s»: место (%s) к рангу «%s» уже стоит" % [o["title"], an, Defs.LEVELS[lvl]["name"]])
		for e: Array in o["need"]:
			var ok := false
			for k in String(e[0]).trim_prefix("=").split("|"):
				for t in Defs.looks_of(k) + [k]:
					if not Defs.B.has(t):
						continue
					var u := String(Defs.B[t].get("unlock", ""))
					var r := Defs.research(u)
					if u == "" or (not r.is_empty() and int(r["lvl"]) <= lvl) or (u.begins_with("q_") and lvl >= 2) or (u == "q_lights" or u == "q_garden"):
						ok = true
			check(ok, "заказ «%s»: «%s» открывается к рангу «%s»" % [o["title"], e[0], Defs.LEVELS[lvl]["name"]])
		check(not o.has("money") and int(o.get("rp", 0)) > 0 and int(o.get("glory", 0)) > 0, "заказ «%s»: награда — очки и Слава, без денег" % o["title"])
		if o.has("unlock"):
			check(StoryOrders.look_of(String(o["unlock"])) != "", "заказ «%s»: редкое украшение %s есть" % [o["title"], o["unlock"]])
	for rk in range(1, 8):
		check(int(per.get(rk, 0)) >= 2, "на ранге «%s» заказов: %d (нужно ≥ 2)" % [Defs.LEVELS[rk]["name"], int(per.get(rk, 0))])
