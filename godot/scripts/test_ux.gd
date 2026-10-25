extends Node
## Этап 2b: «Этаж» (U), рожицы после стройки, пометки «НОВОЕ» (docs/PLAN_2026-10-14_tech.md 2.3–2.5, решение владельца Д4).
##   bash .work/py/gpu_run.sh res://test_ux.tscn   — в конце «UX DONE fails=0»; снимки — .work/gd/ux_*.png
## «Этаж»: кнопка с числом готовых домов, U и Esc, стрелки с ценой над готовыми домами (зелёные), мазок мышью по улице —
## каждый готовый дом под курсором получает этаж за свою цену, монетки — один раз на мазок, итог — в колокольчик;
## денарии кончились — мазок дальше не надстраивает; над неготовым домом у курсора — почему; кнопки «все разом» нет.
## Правки по проверке: советник про «Этаж» не теряется, если окно исследований закрыли Esc; рывок мыши за кадр не
## пропускает дома; дом не по карману пропускается, а дешёвые дальше по мазку этаж получают; из перекрытых стрелок —
## верхняя; при крупном интерфейсе нижние полосы не наезжают друг на друга.
## Рожицы: поставили лавку — над домами, чьё счастье поменялось, «+N%» волной; не больше 40; не в готовом городе.
## «НОВОЕ»: новая игра — ничего не горит; изучили — горит на разделе, вкладке, карточке; навели / взяли — гаснет;
## исследования нового уровня — на кнопке и в окне; в сохранении; старое сохранение — ничего не новое.

var game
var c: City
var cover                            # Cover
var hud
var fails := 0
var cands: Array = []
var mask := 0
var row1: Array = []                 # дома у лавок (счастливые — готовы к этажу)
var row2: Array = []                 # дома без еды рядом (не готовы)


func _ready() -> void:
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, what: String, extra = null) -> bool:
	print(("UX PASS " if ok else "UX FAIL ") + what + ("" if ok or extra == null else "  " + str(extra)))
	if not ok:
		fails += 1
	return ok


func shot(name: String) -> void:
	await frames(8)
	DirAccess.make_dir_recursive_absolute("D:/CivCity/.work/gd")
	get_viewport().get_texture().get_image().save_png("D:/CivCity/.work/gd/" + name)
	print("SHOT ", name)


func move(p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	e.button_mask = mask
	Input.parse_input_event(e)


func btn(p: Vector2, idx: int, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = p
	e.global_position = p
	e.button_index = idx
	e.pressed = pressed
	if idx == MOUSE_BUTTON_LEFT:
		mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	e.button_mask = mask
	Input.parse_input_event(e)


func key(k: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.pressed = down
		get_viewport().push_input(ev)
	await frames(3)


## Точка мира → экран (как события мыши)
func scr3(w: Vector3) -> Vector2:
	var cam: Camera3D = get_viewport().get_camera_3d()
	return get_viewport().get_final_transform() * cam.unproject_position(w)


## Середина значка над миром → экран
func badge_scr(key: String) -> Vector2:
	var n: Control = hud.badges[key]["n"]
	return get_viewport().get_final_transform() * n.get_global_rect().get_center()


## Середина дома (на половине высоты) → экран
func house_scr(id: int) -> Vector2:
	var h: Dictionary = c.buildings[id]
	return scr3(Vector3(h["pos"].x, float(h["y"]) + c.blueprint(h).top_y() * 0.45, h["pos"].y))


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


## Поставить у дороги в ближайшей к цели годной точке (не дальше 3 м от неё)
func put(type: String, target: Vector2) -> Dictionary:
	cands.sort_custom(func(p, q): return p.distance_squared_to(target) < q.distance_squared_to(target))
	for p in cands.slice(0, 120):
		if p.distance_to(target) > 3.0:
			break
		reset()
		var pl: Dictionary = game.placement(type, p)
		if pl["err"] == "" and (Defs.B[type]["kind"] == "decor" or pl["sub"] == "road"):
			return c.place(type, pl["pos"], pl["yaw"], pl["variant"], pl["color"])
	return {}


## Годное место у дороги рядом с целью (ничего не ставим)
func spot(type: String, target: Vector2) -> Dictionary:
	cands.sort_custom(func(p, q): return p.distance_squared_to(target) < q.distance_squared_to(target))
	for p in cands.slice(0, 300):
		reset()
		var pl: Dictionary = game.placement(type, p)
		if pl["err"] == "" and pl["sub"] == "road":
			return pl
	return {}


func houses() -> Array:
	var out := []
	for id in c.buildings:
		if c.is_house(c.buildings[id]):
			out.append(int(id))
	return out


func texts(n: Node) -> Array:
	var out := []
	for l in n.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return out


## Последнее событие, что начинается с head
func last_event(head: String) -> String:
	for i in range(c.events.size() - 1, -1, -1):
		if String(c.events[i]["text"]).begins_with(head):
			return c.events[i]["text"]
	return ""


func pill_on(b: Control) -> bool:
	var p := b.get_node_or_null("new_mark") as Control
	return p != null and p.visible


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	c = game.city
	cover = game.cover
	hud = game.hud
	game.can_save = false
	game.speed = 0.0
	game.tutorial.step = Tutorial.STEPS.size()
	game.tutorial.card.visible = false
	c.tips["tut"] = -1
	c.tips["ui"] = 3
	c.tips["cover_tip"] = true
	hud.apply_reveal(3)
	await frames(5)
	await _new_fresh()
	await _town()
	await _floor_locked()
	await _floor_tool()
	await _floor_stroke()
	await _floor_broke()
	await _floor_why()
	await _floor_mixed()
	await _badge_top()
	await _floor_exit()
	await _pops()
	await _new_marks()
	await _new_research()
	await _new_save()
	await _bars_scale()
	print("UX DONE fails=%d" % fails)
	get_tree().quit()


# ---------- «НОВОЕ»: новая игра — ничего не горит ----------

func _new_fresh() -> void:
	var any := 0
	for cat: Array in Defs.CATS:
		any += c.new_count(cat[0])
	check(c.tips.has("seen") and any == 0 and c.new_research() == 0 and not c.is_new("@floor"), "новая игра: новых карточек %d, исследований %d" % [any, c.new_research()])
	hud.refresh()
	var lit := 0
	for cid in hud.cats:
		lit += 1 if pill_on(hud.cats[cid]) else 0
	check(lit == 0 and not pill_on(hud.top_btns["research"]) and not pill_on(hud.tool_btns["floor"]), "пометок «НОВОЕ» на кнопках нет")


# ---------- город: улица с лавками (счастливые дома) и улицы без еды ----------

func _town() -> void:
	# просьбы горожан — уже выполнены: их награда упирает казну в предел, а свиток просьб закрыл бы левые дома
	for g in Defs.REQUESTS:
		if not c.goals_done.has(g["id"]):
			c.goals_done.append(g["id"])
		if g.has("unlock"):
			c.research[g["unlock"]] = true    # как в игре: награда просьбы открывает постройку
	c.money = 500000.0
	c.econ = 0                                # этажи проверяем на прежних правилах счастья (повторы лавок — test_econ)
	for r in ["stall_veg", "stall_fish", "deco_flowers"]:
		c.research[r] = true
	street(Vector2(150, 150), Vector2(214, 150))
	street(Vector2(150, 180), Vector2(214, 180))
	street(Vector2(150, 200), Vector2(214, 200))
	# ряд 1 — южная сторона первой улицы; лавки и фонари — напротив, на северной
	for x in range(152, 214, 4):
		var h := put("house_pleb", Vector2(x, 154))
		if not h.is_empty():
			row1.append(int(h["id"]))
	for e: Array in [["stall_fruit", 156], ["stall_veg", 164], ["stall_fish", 172], ["stall_fruit", 190], ["stall_veg", 198], ["stall_fish", 206]]:
		put(e[0], Vector2(e[1], 146))
	for x in [160.0, 168.0, 181.0, 194.0, 202.0, 211.0]:
		put("lamp_post", Vector2(x, 146))
	# ряд 2 — южная сторона второй улицы (северная свободна — для лавки с рожицами); третья улица — с двух сторон
	for x in range(152, 214, 4):
		var h := put("house_pleb", Vector2(x, 184))
		if not h.is_empty():
			row2.append(int(h["id"]))
	for z in [196.0, 204.0]:
		for x in range(152, 214, 4):
			put("house_pleb", Vector2(x, z))
	check(row1.size() >= 12 and row2.size() >= 12 and houses().size() >= 48, "домов: ряд 1 — %d, ряд 2 — %d, всего %d" % [row1.size(), row2.size(), houses().size()])
	# жильцы — во все дома, кроме одного в ряду 1 (пустой — «сначала заселите»)
	for id in houses():
		if id != row1[1]:
			c.settled(id, c.house_cap(c.buildings[id]), "Проба %d" % id)
	c.fest_left = 100000                      # игры в честь богов: +8% всем (иначе на 65% нужно больше лавок)
	c.compute()
	var ready: Array = c.floor_ready()
	print("UX note: счастье ряда 1 — ", row1.map(func(id): return int(c.buildings[id]["happy"])), ", ряда 2 — ", row2.map(func(id): return int(c.buildings[id]["happy"])))
	check(ready.is_empty(), "до «Второго жилого этажа» готовых нет (исследования нет)")


# ---------- «Этаж» до исследования ----------

func _floor_locked() -> void:
	hud.refresh()
	var fb: Button = hud.tool_btns["floor"]
	check(fb != null and hud.tool_btns.keys()[0] == "floor", "кнопка «Этаж» — первая справа внизу")
	check((fb.get_node("ic") as CanvasItem).material != null and fb.tooltip_text.contains("Второй жилой этаж"), "до исследования серая, в подсказке — чем откроется: «%s»" % fb.tooltip_text)
	await key(KEY_U)
	check(game.tool == "floor" and hud.tool_panel.visible and hud.tool_err.text.contains("Второй жилой этаж"), "U берёт «Этаж»; в окне — что его откроет: «%s»" % hud.tool_err.text)
	check(cover.state == "floor" and cover.want.is_empty(), "до исследования стрелок и подсветки нет")
	await key(KEY_U)
	check(game.tool == "", "U ещё раз — «Этаж» убран")


# ---------- «Этаж»: стрелки, подсветка, число на кнопке, советник ----------

func _floor_tool() -> void:
	c.level = 1
	c.rp = 500.0
	check(c.do_research("floor2"), "изучили «Второй жилой этаж»")
	var ev := last_event("Изучено:")
	check(ev == "Изучено: Второй жилой этаж — инструмент «Этаж» справа внизу (клавиша U)", "событие говорит, где искать: «%s»" % ev)
	var ready: Array = c.floor_ready()
	check(ready.size() >= 8, "готовы к этажу: %d домов" % ready.size())
	for id in ready:
		if not row1.has(id):
			check(false, "готов дом не из ряда 1: %d" % id)
	hud.refresh()
	var fb: Button = hud.tool_btns["floor"]
	check((fb.get_node("ic") as CanvasItem).material == null, "после исследования кнопка цветная")
	check(c.is_new("@floor") and pill_on(fb) and not hud.floor_badge.visible, "на кнопке «НОВОЕ» (число готовых — под ним спрятано)")
	await shot("ux_floor_btn_new.png")
	# советник один раз; пока открыто окно исследований (только что изучили) — ждёт, пока его закроют
	c.tips.erase("floor_tool")
	hud.advisor_panel.visible = false
	hud._top_action("research")
	await frames(2)
	hud.refresh()
	check(hud.research_panel.visible and not hud.advisor_panel.visible and not c.tips.has("floor_tool"), "окно исследований открыто — советник про «Этаж» ждёт")
	hud._top_action("research")
	await frames(2)
	check(hud.advisor_panel.visible and hud.adv_title.text == "Этаж — без карточки дома", "окно закрыли — советник рассказал про «Этаж»: «%s»" % hud.adv_title.text)
	# закрыли Esc (close_panels гасит и советника): совет не теряется — он показан после закрытия окна
	c.tips.erase("floor_tool")
	hud.advisor_panel.visible = false
	hud._top_action("research")
	await frames(2)
	check(hud.research_panel.visible and not hud.advisor_panel.visible, "окно исследований открыто снова")
	await key(KEY_ESCAPE)
	await frames(2)
	check(not hud.research_panel.visible and hud.advisor_panel.visible and hud.adv_title.text == "Этаж — без карточки дома" and c.tips.has("floor_tool"), "окно закрыли Esc — советник про «Этаж» на экране: «%s»" % hud.adv_title.text)
	# и щелчком по карте (тоже close_panels)
	c.tips.erase("floor_tool")
	hud.advisor_panel.visible = false
	hud._top_action("research")
	await frames(2)
	hud.close_panels()
	await frames(2)
	check(hud.advisor_panel.visible and hud.adv_title.text == "Этаж — без карточки дома", "окно закрыли щелчком мимо — советник на экране: «%s»" % hud.adv_title.text)
	c.tips.erase("floor_tool")
	hud.advisor_panel.visible = false
	game.rig.set_view(Vector3(182, 2, 160), 0, 52, 62)
	await frames(10)
	game.set_tool("floor")
	await frames(3)
	check(hud.advisor_panel.visible and hud.adv_title.text == "Этаж — без карточки дома" and c.tips.has("floor_tool"), "советник объясняет «Этаж» один раз: «%s»" % hud.adv_title.text)
	check(hud.adv_text.text.contains("U") and hud.adv_text.text.contains("зажатой"), "в совете — клавиша U и мазок с зажатой кнопкой")
	hud.advisor_panel.visible = false
	check(not c.is_new("@floor") and not pill_on(fb) and hud.floor_badge.visible, "взяли «Этаж» — «НОВОЕ» снято")
	check(hud.floor_badge.text == str(c.floor_ready(false).size()), "число на кнопке — сколько домов готовы: «%s»" % hud.floor_badge.text)
	game.set_tool("")
	game.set_tool("floor")
	await frames(3)
	check(not hud.advisor_panel.visible, "второй раз советник молчит")
	# стрелки с ценой над готовыми, готовые зелёные
	var ok := true
	for id in ready:
		var k := "fl%d" % id
		ok = ok and hud.badges.has(k) and hud.badges[k]["icon"] == "up" and hud.badges[k]["text"] == hud.fmt(c.floor_price(c.buildings[id])) and not hud.badges[k]["warn"]
		ok = ok and cover.want.get(id) == Cover.GREEN
	var extra := 0
	for k in hud.badges:
		if String(k).begins_with("fl") and not ready.has(int(String(k).substr(2))):
			extra += 1
	check(ok and extra == 0 and cover.want.size() == ready.size(), "над каждым готовым домом стрелка с ценой (%d), он зелёный; у других стрелок нет" % ready.size())
	check(hud.tool_title.text == "Этаж · готовы домов: %d" % ready.size(), "окно инструмента: «%s»" % hud.tool_title.text)
	var btns: Array = hud.tool_panel.find_children("*", "Button", true, false).filter(func(x): return (x as Control).is_visible_in_tree())
	check(btns.is_empty(), "кнопки «надстроить все готовые разом» нет (решение Д4): видимых кнопок в окне %d" % btns.size())
	await frames(20)
	await shot("ux_floor_tool.png")


# ---------- мазок: щелчок по стрелке и ведение вдоль улицы ----------

## Провести мышью с зажатой левой кнопкой по точкам (шагами по 8 точек экрана, кадр на шаг)
func drag(pts: Array) -> void:
	move(pts[0])
	await frames(2)
	btn(pts[0], MOUSE_BUTTON_LEFT, true)
	await frames(2)
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var n := maxi(1, int(a.distance_to(b) / 8.0))
		for s in range(1, n + 1):
			move(a.lerp(b, float(s) / n))
			await frames(1)
	await frames(2)
	btn(pts[-1], MOUSE_BUTTON_LEFT, false)
	await frames(3)


## Готовые дома ряда 1 слева направо
func ready_row() -> Array:
	var r := []
	for id in row1:
		if c.can_buy_floor(c.buildings[id]) == "":
			r.append(id)
	r.sort_custom(func(a, b): return (c.buildings[a]["pos"] as Vector2).x < (c.buildings[b]["pos"] as Vector2).x)
	return r


func _floor_stroke() -> void:
	var r := ready_row()
	if not check(r.size() >= 8, "готовых домов в ряду: %d" % r.size()):
		return
	# щелчок по стрелке над одним домом
	var one: int = r[0]
	var m0: float = c.money
	var p0 := c.floor_price(c.buildings[one])
	var coins0 := int(game.sound.played.get("coins", 0))
	var ev0: int = c.events.size()
	var bell0: int = hud.bell_count
	var at := badge_scr("fl%d" % one)
	move(at)
	await frames(3)
	check(game.floor_hover == 1 and hud._cursor_world() == "build", "над стрелкой — курсор «строить»")
	check(String(cover.cap[0]).begins_with("Дом семьи Проба %d: 2-й этаж · %s ден. · +4 места" % [one, hud.fmt(p0)]), "у курсора: «%s»" % cover.cap[0])
	btn(at, MOUSE_BUTTON_LEFT, true)
	await frames(2)
	btn(at, MOUSE_BUTTON_LEFT, false)
	await frames(3)
	check(int(c.buildings[one]["tier"]) == 2 and is_equal_approx(c.money, m0 - p0), "щелчок по стрелке — дому этаж за %d ден." % p0)
	check(int(game.sound.played.get("coins", 0)) == coins0 + 1, "монетки звякнули один раз")
	check(not hud.badges.has("fl%d" % one) and not cover.want.has(one), "у надстроенного стрелки и подсветки больше нет")
	var last: Dictionary = c.events[-1]
	check(c.events.size() > ev0 and String(last["text"]).begins_with("Дому семьи Проба %d надстроили 2-й этаж за %d ден." % [one, p0]) and hud.bell_count > bell0, "итог — в колокольчик: «%s»" % last["text"])
	# мазок вдоль улицы по стрелкам: этаж — каждому готовому дому под курсором, монетки — один раз
	var seg: Array = r.slice(1, 6)
	var pts := []
	for id in seg:
		pts.append(badge_scr("fl%d" % id))
	var cost := 0
	for id in seg:
		cost += c.floor_price(c.buildings[id])
	m0 = c.money
	coins0 = int(game.sound.played.get("coins", 0))
	var tiers0 := {}
	for id in houses():
		tiers0[id] = int(c.buildings[id]["tier"])
	var notes0: int = hud.notes_box.get_child_count()
	# снимок посреди мазка: подпись «Этот мазок»
	move(pts[0])
	await frames(2)
	btn(pts[0], MOUSE_BUTTON_LEFT, true)
	await frames(2)
	var mid: int = pts.size() / 2
	for i in range(1, mid + 1):
		var n := maxi(1, int(pts[i - 1].distance_to(pts[i]) / 8.0))
		for s in range(1, n + 1):
			move(pts[i - 1].lerp(pts[i], float(s) / n))
			await frames(1)
	check(game.floor_drag and game.floor_done.size() == mid + 1 and String(cover.cap[1]).begins_with("Этот мазок: %d" % (mid + 1)), "посреди мазка: надстроено %d, у курсора «%s»" % [game.floor_done.size(), cover.cap[1]])
	await shot("ux_floor_stroke.png")
	# дальше — рывком через дом за один кадр (быстрая мышь, слабый ноутбук): дом на пути тоже получает этаж
	var jump: float = (pts[mid] as Vector2).distance_to(pts[-1])
	move(pts[-1])
	await frames(2)
	check(game.floor_done.size() == pts.size(), "рывок на %d точек за кадр — дом между кадрами не пропущен: надстроено %d из %d" % [int(jump), game.floor_done.size(), pts.size()])
	await frames(2)
	btn(pts[-1], MOUSE_BUTTON_LEFT, false)
	await frames(3)
	var got := []
	var twice := 0
	for id in houses():
		var d := int(c.buildings[id]["tier"]) - int(tiers0[id])
		if d > 0:
			got.append(id)
		if d > 1:
			twice += 1
	got.sort()
	var want := seg.duplicate()
	want.sort()
	check(got == want and twice == 0, "мазок по %d стрелкам — этаж получили ровно они, каждый один раз: %s" % [seg.size(), got])
	check(is_equal_approx(c.money, m0 - cost), "денарии: ушло %d = сумма цен этажей %d" % [int(m0 - c.money), cost])
	check(int(game.sound.played.get("coins", 0)) == coins0 + 1, "монетки — один раз на мазок (а не %d)" % seg.size())
	var tx: String = c.events[-1]["text"]
	check(tx.begins_with("Надстроили %d этажей за %d ден." % [seg.size(), cost]) and tx.contains("Проба"), "итог мазка — одной строкой в колокольчик: «%s»" % tx)
	var toast := false
	for n in hud.notes_box.get_children().slice(notes0):
		for l in texts(n):
			toast = toast or String(l).contains("этаж")
	check(not toast, "всплывашек про этажи нет")
	check(not game.floor_drag and game.floor_done.is_empty(), "мазок окончен")
	# ведём по самим домам (луч по модели), а не по стрелкам
	var r2 := ready_row()
	if r2.size() >= 2:
		var hp := [house_scr(r2[0]), house_scr(r2[1])]
		var t0a := int(c.buildings[r2[0]]["tier"])
		await drag(hp)
		check(int(c.buildings[r2[0]]["tier"]) == t0a + 1 and int(c.buildings[r2[1]]["tier"]) == int(tiers0[r2[1]]) + 1, "мазок по стенам домов — тоже этажи")


# ---------- денарии кончились посреди мазка ----------

func _floor_broke() -> void:
	# новые готовые дома: заселяем надстроенные — у них снова полно (а этаж 3 ещё не изучен)
	var r := ready_row()
	if not check(r.size() >= 3, "готовых домов ещё %d" % r.size()):
		return
	var price := c.floor_price(c.buildings[r[0]])
	c.money = price * 2 + 30.0
	var tiers0 := {}
	for id in r:
		tiers0[id] = int(c.buildings[id]["tier"])
	var pts := []
	for id in r:
		pts.append(badge_scr("fl%d" % id))
	var coins0 := int(game.sound.played.get("coins", 0))
	move(pts[0])
	await frames(2)
	btn(pts[0], MOUSE_BUTTON_LEFT, true)
	await frames(2)
	for i in range(1, pts.size()):
		var n := maxi(1, int(pts[i - 1].distance_to(pts[i]) / 8.0))
		for s in range(1, n + 1):
			move(pts[i - 1].lerp(pts[i], float(s) / n))
			await frames(1)
	await frames(2)
	check(game.floor_broke and String(cover.cap[2]).begins_with("Не хватает денариев"), "денарии кончились — у курсора «%s»" % cover.cap[2])
	await shot("ux_floor_broke.png")
	btn(pts[-1], MOUSE_BUTTON_LEFT, false)
	await frames(3)
	var got := 0
	for id in r:
		if int(c.buildings[id]["tier"]) > int(tiers0[id]):
			got += 1
	check(got == 2 and c.money >= 0.0 and c.money < float(price), "денариев на два этажа — надстроено %d, в казне %d" % [got, int(c.money)])
	check(int(game.sound.played.get("coins", 0)) == coins0 + 1, "монетки — один раз")
	# стрелки остальных — с красной ценой (денариев мало), подсветки у них нет
	var red := 0
	for id in r:
		if int(c.buildings[id]["tier"]) == int(tiers0[id]) and hud.badges.has("fl%d" % id) and hud.badges["fl%d" % id]["warn"] and not cover.want.has(id):
			red += 1
	check(red == r.size() - 2, "у недостроенных — красная цена без подсветки: %d" % red)
	c.money = 500000.0


# ---------- над неготовым домом — почему ----------

func _floor_why() -> void:
	game.rig.set_view(Vector3(182, 2, 170), 0, 50, 66)
	await frames(8)
	# ряд 2: без еды рядом счастье ниже 65%
	var h2: int = row2[row2.size() / 2]
	move(house_scr(h2))
	await frames(4)
	var want := c.can_buy_floor(c.buildings[h2])
	check(want.begins_with("Счастье дома ") and cover.cap[2] == want and cover.cap[0] == "", "дом без еды: у курсора «%s»" % cover.cap[2])
	check(game.floor_hover == 0 and hud._cursor_world() == "arrow_red", "курсор — красная стрелка")
	await shot("ux_floor_why.png")
	# пустой дом
	game.rig.set_view(Vector3(170, 2, 156), 0, 50, 46)
	await frames(8)
	move(house_scr(row1[1]))
	await frames(4)
	check(cover.cap[2] == "Дом пока пустой — сначала заселите в него семью", "пустой дом: «%s»" % cover.cap[2])
	# надстроенный (в доме снова место) — «сначала заселите»
	var up := -1
	for id in row1:
		if int(c.buildings[id]["tier"]) == 2 and int(c.buildings[id]["pop"]) < c.house_cap(c.buildings[id]):
			up = id
			break
	if up >= 0:
		# камера — на этот дом: у края экрана его закрыла бы нижняя правая полоса (казна с «+N/ч» шире)
		game.rig.set_view(Vector3(c.buildings[up]["pos"].x, 2, c.buildings[up]["pos"].y), 0, 50, 46)
		await frames(8)
		move(house_scr(up))
		await frames(4)
		check(cover.cap[2] == "Сначала изучите «Третий жилой этаж»", "надстроенный дом (3-й этаж не изучен): «%s»" % cover.cap[2])
	# карточка дома: кнопка этажа осталась, рядом подсказка про «Этаж»
	game.set_tool("")
	var rr := ready_row()
	if not rr.is_empty():
		game.select_building(c.buildings[rr[0]])
		hud.open_info(c.buildings[rr[0]])
		await frames(3)
		var fbtn := false
		for b in hud.info_box.find_children("*", "Button", true, false):
			fbtn = fbtn or (b as Button).text.begins_with("Надстроить этаж")
		var tip := false
		for l in texts(hud.info_box):
			tip = tip or String(l).contains("инструментом «Этаж»")
		check(fbtn and tip, "в карточке дома кнопка «Надстроить этаж» осталась, рядом — подсказка про инструмент")
		hud.close_panels()
		await frames(2)


# ---------- дом не по карману посреди мазка — пропускается, а дешёвые дальше получают этаж ----------

func _floor_mixed() -> void:
	game.set_tool("")
	c.money = 500000.0
	# дорогой: надстроенный дом ряда 1 — полный и счастливый, «Третий жилой этаж» изучен — этаж 3 за 450 ден.
	c.research["floor3"] = true
	var dear := -1
	for id in row1:
		var h: Dictionary = c.buildings[id]
		if int(h["tier"]) == 2:
			dear = id
			c.settled(id, c.house_cap(h) - int(h["pop"]), "Дорогой %d" % id)
			if int(h["happy"]) < int(Defs.FLOOR_HAPPY[3]):
				h["happy"] = int(Defs.FLOOR_HAPPY[3]) + 5        # для пробы: счастье на третий этаж
			break
	if not check(dear >= 0 and c.can_buy_floor(c.buildings[dear], false) == "", "дорогой дом готов к 3-му этажу"):
		c.research.erase("floor3")
		return
	# дешёвые: готовы ко 2-му этажу (200 ден.); мазок ведём от дорогого к ближнему из них
	var dx: float = (c.buildings[dear]["pos"] as Vector2).x
	var cheap := []
	for id in houses():
		if int(c.buildings[id]["tier"]) == 1 and c.can_buy_floor(c.buildings[id]) == "":
			cheap.append(id)
	cheap.sort_custom(func(p, q): return absf((c.buildings[p]["pos"] as Vector2).x - dx) < absf((c.buildings[q]["pos"] as Vector2).x - dx))
	if not check(not cheap.is_empty(), "дешёвых готовых домов: %d" % cheap.size()):
		c.research.erase("floor3")
		return
	var low: int = cheap[0]
	var p_dear := c.floor_price(c.buildings[dear])
	var p_cheap := c.floor_price(c.buildings[low])
	c.money = float(p_cheap) + 100.0                  # на дешёвый хватает, на дорогой — нет
	check(p_dear > int(c.money) and p_cheap <= int(c.money), "этаж дорогому — %d ден., дешёвому — %d, в казне %d" % [p_dear, p_cheap, int(c.money)])
	game.rig.set_view(Vector3(182, 2, 160), 0, 52, 62)
	await frames(10)
	game.set_tool("floor")
	await frames(6)
	hud.advisor_panel.visible = false
	var tiers0 := {}
	for id in houses():
		tiers0[id] = int(c.buildings[id]["tier"])
	check(hud.badges.has("fl%d" % dear) and hud.badges["fl%d" % dear]["warn"] and hud.badges.has("fl%d" % low) and not hud.badges["fl%d" % low]["warn"], "над дорогим — красная цена, над дешёвым — обычная")
	# нажали на красную стрелку дорогого — он пропущен, мазок не кончился
	var a := badge_scr("fl%d" % dear)
	var b := badge_scr("fl%d" % low)
	move(a)
	await frames(3)
	btn(a, MOUSE_BUTTON_LEFT, true)
	await frames(3)
	check(game.floor_drag and game.floor_done.is_empty() and not game.floor_broke and String(cover.cap[2]).begins_with("Не хватает денариев: этаж стоит %s" % hud.fmt(p_dear)), "дорогой не по карману — у курсора «%s», мазок идёт дальше" % cover.cap[2])
	var n := maxi(1, int(a.distance_to(b) / 8.0))
	for s in range(1, n + 1):
		move(a.lerp(b, float(s) / n))
		await frames(1)
	await frames(2)
	btn(b, MOUSE_BUTTON_LEFT, false)
	await frames(3)
	var got := []
	for id in houses():
		if int(c.buildings[id]["tier"]) > int(tiers0[id]):
			got.append(id)
	check(got.size() == 1 and not got.has(dear) and cheap.has(got[0]) and is_equal_approx(c.money, 100.0), "дорогой пропущен, дешёвый на пути получил этаж: %s, в казне %d" % [got, int(c.money)])
	game.set_tool("")
	c.research.erase("floor3")
	c.money = 500000.0
	c.compute()


## Две стрелки друг на друге: под мышью — верхняя (её и видно); красные в мазке не в счёт
func _badge_top() -> void:
	game.set_tool("")
	var w := Vector3(182, game.land.height_at(182, 160) + 3.0, 160)
	hud.set_badge("flt1", w, "up", false, "111")
	hud.set_badge("flt2", w + Vector3(0.4, 0, 0), "up", true, "222")
	await frames(3)
	var r1: Rect2 = (hud.badges["flt1"]["n"] as Control).get_global_rect()
	var r2: Rect2 = (hud.badges["flt2"]["n"] as Control).get_global_rect()
	var p := r1.intersection(r2).get_center()
	check(r1.intersects(r2) and hud.badge_at(p, "flt") == "flt2", "стрелки перекрылись — под мышью верхняя: «%s»" % hud.badge_at(p, "flt"))
	check(hud.badge_at(p, "flt", true) == "flt1", "красная не в счёт — та, что под ней")
	hud.clear_badge("flt1")
	hud.clear_badge("flt2")


# ---------- выйти: Esc, правая кнопка, U ----------

func _floor_exit() -> void:
	game.set_tool("floor")
	await frames(2)
	await key(KEY_ESCAPE)
	check(game.tool == "" and cover.state == "" and not hud.badges.keys().any(func(k): return String(k).begins_with("fl")), "Esc — «Этаж» убран, стрелок нет")
	check(not hud.pause_panel.visible, "Esc с «Этажом» в руках меню не открывает")
	await key(KEY_U)
	check(game.tool == "floor", "U — снова «Этаж»")
	var mp := scr3(Vector3(182, game.land.height_at(182, 166), 166))
	move(mp)
	await frames(2)
	btn(mp, MOUSE_BUTTON_RIGHT, true)
	await frames(2)
	btn(mp, MOUSE_BUTTON_RIGHT, false)
	await frames(3)
	check(game.tool == "" and cover.state == "", "правая кнопка — «Этаж» убран")


# ---------- рожицы после стройки ----------

func _pops() -> void:
	game.set_tool("")
	await get_tree().create_timer(2.5).timeout
	check(hud.pops_active() == 0, "рожиц пока нет")
	# фруктовая лавка напротив ряда 2 (у него еды нет): мышью — как игрок
	var pl := spot("stall_fruit", Vector2(182, 176))
	if not check(not pl.is_empty(), "место для лавки у ряда 2"):
		return
	game.rig.set_view(Vector3(182, 2, 184), 0, 50, 52)
	await frames(8)
	var before: Dictionary = c.happy_map()
	game.set_tool("stall_fruit")
	reset()
	var at := scr3(Vector3(pl["pos"].x, game.land.height_at(pl["pos"].x, pl["pos"].y), pl["pos"].y))
	move(at)
	await frames(4)
	var n0: int = c.buildings.size()
	btn(at, MOUSE_BUTTON_LEFT, true)
	await frames(2)
	btn(at, MOUSE_BUTTON_LEFT, false)
	await frames(2)
	if not check(c.buildings.size() == n0 + 1, "лавка поставлена мышью"):
		return
	var after: Dictionary = c.happy_map()
	var ch := {}
	for id in after:
		if before.has(id) and int(after[id]) != int(before[id]):
			ch[id] = int(after[id]) - int(before[id])
	check(ch.size() > 0 and hud.pops_active() == mini(Game.POPS_MAX, ch.size()), "рожиц %d — над каждым домом, где счастье поменялось (%d)" % [hud.pops_active(), ch.size()])
	var ok := true
	var shop_pos: Vector2 = c.buildings[c.next_id - 1]["pos"]
	for p: Dictionary in hud._pops:
		if not p["on"]:
			continue
		var l: Label = p["lbl"]
		var f = p["face"]
		var hid := -1
		for id in ch:
			var h: Dictionary = c.buildings[id]
			if (p["pos"] as Vector3).distance_to(Vector3(h["pos"].x, float(h["y"]) + c.blueprint(h).top_y() + 1.0, h["pos"].y)) < 0.01:
				hid = id
		ok = ok and hid >= 0 and l.text == hud._pct(ch[hid]) and int(f.mood) == (1 if ch[hid] > 0 else -1)
	check(ok, "у каждой рожицы — свой дом, «+N%%» и улыбка (или грусть) по знаку: %s" % [ch.values()])
	# волна: ближний к лавке дом всплывает раньше дальнего
	var near_t := INF
	var far_t := -INF
	var near_d := INF
	var far_d := -INF
	for p: Dictionary in hud._pops:
		if p["on"]:
			var d := Vector2(p["pos"].x, p["pos"].z).distance_to(shop_pos)
			if d < near_d:
				near_d = d
				near_t = float(p["t0"])
			if d > far_d:
				far_d = d
				far_t = float(p["t0"])
	check(far_d > near_d and far_t > near_t, "волна от лавки: ближний всплыл раньше дальнего (%.0f м / %.0f м)" % [near_d, far_d])
	game.set_tool("")
	await get_tree().create_timer(0.7).timeout
	await shot("ux_pops.png")
	await get_tree().create_timer(3.0).timeout
	check(hud.pops_active() == 0, "через 2–3 с рожицы погасли")
	# больше 40 перемен — 40 самых больших
	var big := {}
	var hm: Dictionary = c.happy_map()
	var i := 0
	for id in hm:
		big[id] = int(hm[id]) - (1 + i % 50)
		i += 1
	check(hm.size() > Game.POPS_MAX, "жилых домов %d — больше %d" % [hm.size(), Game.POPS_MAX])
	game._happy_pops(big, Vector2(182, 180))
	var shown := []
	for p: Dictionary in hud._pops:
		if p["on"]:
			shown.append(int(String((p["lbl"] as Label).text).trim_prefix("+").trim_suffix("%")))
	var all_d := []
	for id in hm:
		all_d.append(int(hm[id]) - int(big[id]))
	all_d.sort()
	all_d.reverse()
	shown.sort()
	shown.reverse()
	check(shown.size() == Game.POPS_MAX and shown == all_d.slice(0, Game.POPS_MAX), "рожиц не больше %d — самые большие перемены (%d…%d)" % [Game.POPS_MAX, shown[0] if not shown.is_empty() else 0, shown[-1] if not shown.is_empty() else 0])
	await get_tree().create_timer(3.6).timeout
	# готовый город (меню, витрина) — без рожиц
	game.mode = "demo"
	game._happy_pops(big, Vector2(182, 180))
	game.mode = "new"
	check(hud.pops_active() == 0, "в готовом городе рожиц нет")
	check(not game.sound.played.has("happy") and not game.sound.played.has("pop"), "рожицы без звука")


# ---------- «НОВОЕ»: разделы, вкладки, карточки ----------

func _new_marks() -> void:
	game.set_tool("")
	hud.close_panels()
	await frames(2)
	# лавки и цветы открыты в начале теста напрямую — они новые
	check(c.is_new("stall_veg") and c.is_new("stall_fish") and c.is_new("flowers"), "открытые исследованием карточки — новые")
	check(pill_on(hud.cats["commerce"]) and pill_on(hud.cats["decor"]) and not pill_on(hud.cats["housing"]), "«НОВОЕ» на разделах «Лавки» и «Украшения», на «Жильё» — нет")
	# событие говорит, где искать
	c.rp = 500.0
	c.research.erase("deco_trees")
	check(c.do_research("deco_trees"), "изучили деревья")
	var ev := last_event("Изучено:")
	check(ev == "Изучено: Деревья и кусты — карточки в «Украшения · Цветы, Деревья»", "событие: «%s»" % ev)
	c.research.erase("musicians")
	c.do_research("musicians")
	check(last_event("Изучено:") == "Изучено: Уличные музыканты — карточка в «Лавки · Развлечения»", "событие: «%s»" % last_event("Изучено:"))
	# свиток «Лавки · Еда»: карточки овощной и рыбной — с пометкой, вкладка «Развлечения» — с точкой
	hud._toggle_cat("commerce")
	hud.open_sub = "food"
	hud._fill_cards()
	await frames(12)
	var veg: Control = null
	var fruit: Control = null
	for b in hud.tray_grid.get_children():
		if b.get_meta("type", "") == "stall_veg":
			veg = b
		if b.get_meta("type", "") == "stall_fruit":
			fruit = b
	check(veg != null and pill_on(veg) and fruit != null and not pill_on(fruit), "карточка овощной лавки — «НОВОЕ», фруктовой — нет")
	var fun_tab: Control = null
	for t in hud.tray_tabs.get_children():
		if t.get_meta("sub", "") == "fun":
			fun_tab = t
	check(fun_tab != null and pill_on(fun_tab), "на вкладке «Развлечения» — точка (там новые музыканты)")
	await shot("ux_new_cards.png")
	# навели мышь на 0,4 с — посмотрели
	var vp := get_viewport().get_final_transform() * veg.get_global_rect().get_center()
	move(vp)
	await get_tree().create_timer(0.6).timeout
	await frames(2)
	check(not c.is_new("stall_veg") and not pill_on(veg), "навели на карточку — «НОВОЕ» снято")
	move(vp + Vector2(0, -400))
	await frames(2)
	# взяли — тоже
	hud.select_build("stall_fish")
	await frames(2)
	check(not c.is_new("stall_fish"), "взяли карточку — «НОВОЕ» снято")
	game.set_tool("")
	hud.open_sub = "fun"
	hud._fill_cards()
	await frames(3)
	hud.select_build("musicians")
	game.set_tool("")
	await frames(2)
	check(c.new_count("commerce") == 0 and not pill_on(hud.cats["commerce"]), "раздел «Лавки» без пометки")
	hud._close_tray()


# ---------- «НОВОЕ»: исследования нового уровня ----------

func _new_research() -> void:
	c.level = 2
	c.compute()
	hud.refresh()
	var n := c.new_research()
	check(n > 0 and c.is_new_r("artisans") and pill_on(hud.top_btns["research"]), "новый уровень — новые исследования (%d), на кнопке «НОВОЕ»" % n)
	hud._top_action("research")
	await frames(6)
	var marks := 0
	for p in hud.research_box.find_children("new_mark", "", true, false):
		if (p as Control).visible:
			marks += 1
	check(marks == n, "в окне исследований пометок «НОВОЕ»: %d из %d" % [marks, n])
	await shot("ux_new_research.png")
	hud._top_action("research")
	await frames(3)
	check(not hud.research_panel.visible and c.new_research() == 0 and not pill_on(hud.top_btns["research"]), "окно закрыли — исследования посмотрели, пометок нет")


# ---------- «НОВОЕ» в сохранении; старое сохранение — ничего не новое ----------

func _new_save() -> void:
	c.research["deco_stone"] = true            # новое, ещё не видели
	check(c.is_new("statue") or c.new_count("decor") > 0, "каменные украшения — новые")
	var data = JSON.parse_string(JSON.stringify(c.save_data()))
	var c2 := City.new(game.land)
	c2.load_data(data)
	var same := true
	for t in Defs.B:
		same = same and c2.is_new(t) == c.is_new(t)
	check(same and c2.new_count("decor") == c.new_count("decor") and c2.new_count("decor") > 0, "после сохранения и загрузки новое то же (украшений новых %d)" % c2.new_count("decor"))
	check(c2.is_new("stall_veg") == false and c2.new_research() == c.new_research(), "посмотренное осталось посмотренным")
	# старое сохранение: пометок не было — всё открытое считается посмотренным
	var old: Dictionary = (data as Dictionary).duplicate(true)
	(old["tips"] as Dictionary).erase("seen")
	(old["tips"] as Dictionary).erase("seen_r")
	var c3 := City.new(game.land)
	c3.load_data(old)
	var any := 0
	for cat: Array in Defs.CATS:
		any += c3.new_count(cat[0])
	check(c3.tips.has("seen") and any == 0 and c3.new_research() == 0 and not c3.is_new("@floor"), "старое сохранение: новых карточек %d, исследований %d — ничего не горит" % [any, c3.new_research()])
	# а что откроется потом — уже новое
	c3.research.erase("dice")
	c3.level = maxi(c3.level, 2)
	c3.research["dice"] = true
	check(c3.is_new("dice"), "в старом городе новое после обновления — с пометкой")


# ---------- крупный интерфейс: кнопка «Этаж» не загоняет правую полосу на разделы ----------

func _bars_scale() -> void:
	var sc0: float = game.settings.get("ui_scale", 1.0)
	var m0: float = c.money
	var rp0: float = c.rp
	game.settings["ui_scale"] = 1.4          # как из настроек: окно, меняя размер, применяет его заново
	hud.apply_scale(1.4)
	c.money = c.money_cap()
	c.rp = c.rp_cap()                         # «Полки полны» и «Казна полна» — правая полоса шире всего
	var st0: Dictionary = c.stats.duplicate()
	c.stats["rp_day"] = 12.5
	c.stats["income"] = float(c.stats.get("upkeep", 0.0)) + 1234.0
	hud.refresh()
	await frames(6)
	var l: Rect2 = hud.bar_left.get_global_rect()
	var m: Rect2 = hud.bar_mid.get_global_rect()
	var r: Rect2 = hud.bar_right.get_global_rect()
	check(get_window().content_scale_factor > 1.1 and hud.full_rp.visible and hud.full_money.visible, "крупный интерфейс (%.2f), «Полки полны» и «Казна полна» видно" % get_window().content_scale_factor)
	check(not m.intersects(r) and m.position.x > l.end.x, "нижние полосы не наезжают: дороги %s, разделы %s, инструменты %s" % [l, m, r])
	await shot("ux_bars_scale14.png")
	game.settings["ui_scale"] = sc0
	hud.apply_scale(sc0)
	c.money = m0
	c.rp = rp0
	c.stats = st0
	hud.refresh()
	await frames(6)
	var mc: float = hud.bar_mid.get_global_rect().get_center().x
	check(absf(mc - hud.root.size.x * 0.5) < 1.0, "обычный размер — разделы снова посередине (%.0f из %.0f)" % [mc, hud.root.size.x])
