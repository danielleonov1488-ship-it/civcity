extends Node
## Этап 2 (2.1, 2.2): охват без кругов — подсветка домов (решение владельца Д3) и «Обзор» вместо глаза.
##   bash .work/py/gpu_run.sh res://test_cover.tscn   — в конце «COVER DONE fails=0»; снимки — .work/gd/cover_*.png
## Ставим лавку: синие — дома, которые уже снабжает такая же, зелёные — кому новая правда что-то даст (проверяем
## по-честному: ставим и смотрим, кто получил); подпись у курсора с числами; значки над такими же лавками.
## Выбрали лавку: свои дома зелёные, у кого есть и другая такая же — синие; строка в карточке. Памятник, украшение,
## склад — так же. «Обзор»: счастье (цвет и рожица) или одна потребность (✗ и значки лавок), живой, закрывается
## Esc / правой кнопкой / инструментом. Советник один раз. Кругов нет. Большой город — без рывка (пул, по Cover.PER_FRAME домов за кадр).
## Правки по проверке: лавка без склада / сырья — зелёных нет, у курсора предупреждение, значки над складами;
## 1 очко украшения на голом доме — не синий (копится); значок такой же лавки щёлкается; карточка в «Обзоре» не
## закрывает его окно; пул без подсветки — вне сцены и без прежнего пика; подпись у курсора не уезжает за край.

const STREETS := [[Vector2(140, 150), Vector2(236, 150)], [Vector2(140, 172), Vector2(236, 172)]]

var game
var c                                # City
var cover                            # Cover
var hud
var fails := 0
var cands: Array = []
var mask := 0


func _ready() -> void:
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, what: String, extra = null) -> bool:
	print(("COVER PASS " if ok else "COVER FAIL ") + what + ("" if ok or extra == null else "  " + str(extra)))
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
	Input.parse_input_event(e)


func key(k: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.pressed = down
		get_viewport().push_input(ev)
	await frames(3)


func scr(w: Vector2) -> Vector2:
	var cam: Camera3D = get_viewport().get_camera_3d()
	return get_viewport().get_final_transform() * cam.unproject_position(Vector3(w.x, game.land.height_at(w.x, w.y), w.y))


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


## Поставить у дороги в ближайшей к цели годной точке
func put(type: String, target: Vector2) -> Dictionary:
	cands.sort_custom(func(p, q): return p.distance_squared_to(target) < q.distance_squared_to(target))
	for p in cands.slice(0, 300):
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
	reset()
	var pe: Dictionary = game.placement(type, cands[0])
	print("COVER note: нет места для %s у %s: «%s» (%s)" % [type, target, pe["err"], pe.get("sub", "")])
	return {}


func houses() -> Array:
	var out := []
	for id in c.buildings:
		if c.is_house(c.buildings[id]):
			out.append(int(id))
	return out


## Дома, у которых есть лавка type (score) — до и после постройки: кто получил
func with_shop(type: String) -> Dictionary:
	var out := {}
	for id in houses():
		if (c.buildings[id]["score"] as Dictionary).has(type):
			out[id] = true
	return out


func sorted(a: Array) -> Array:
	var b := a.duplicate()
	b.sort()
	return b


func colors_of(col: Color) -> Array:
	var out := []
	for id in cover.want:
		if cover.want[id] == col:
			out.append(int(id))
	out.sort()
	return out


## Все надписи в узле (карточка, легенда)
func texts(n: Node) -> Array:
	var out := []
	for l in n.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return out


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
	hud.apply_reveal(3)
	await frames(5)
	await _no_rings()
	await _town()
	await _tip()
	await _shop_place()
	await _shop_selected()
	await _monument()
	await _decor()
	await _store()
	await _overview()
	await _big_city()
	print("COVER DONE fails=%d" % fails)
	get_tree().quit()


# ---------- кругов нет ----------

func _no_rings() -> void:
	check(game.get("range_ring") == null and game.get("cover_nodes") == null, "у игры нет кольца дальности и старых «призраков» охвата")
	check(not hud.has_method("_toggle_reach") and hud.get("reach_rings") == null, "кнопки «показать радиусы всех лавок» нет")
	var tb: Button = hud.top_btns.get("view")
	check(tb != null and tb.tooltip_text.begins_with("Обзор"), "на месте глаза — «Обзор»: «%s»" % (tb.tooltip_text if tb else ""))
	check(hud.top_btns.has("photo"), "фото (спрятать интерфейс) осталось")


# ---------- город: две улицы, дома, жители ----------

func _town() -> void:
	c.money = 500000.0
	for s in STREETS:
		street(s[0], s[1])
	var n := 0
	# дома — на внутренних сторонах улиц (лицом друг к другу), лавки и памятники — на внешних
	for x in range(144, 234, 4):
		for z in [154.0, 168.0]:
			if not put("house_pleb", Vector2(x, z)).is_empty():
				n += 1
	check(n >= 30, "домов поставлено: %d" % n)
	for id in houses():
		c.settled(id, c.house_cap(c.buildings[id]), "Проба %d" % id)
	c.compute()
	check(int(c.stats["pop"]) > 100, "жителей: %d" % int(c.stats["pop"]))


# ---------- советник один раз ----------

func _tip() -> void:
	c.tips.erase("cover_tip")
	hud.advisor_panel.visible = false
	game.set_tool("stall_fruit")
	await frames(2)
	check(hud.advisor_panel.visible and hud.adv_title.text == "Кому достанется лавка" and c.tips.has("cover_tip"),
		"советник объясняет подсветку и «Обзор»: «%s»" % hud.adv_title.text)
	check(hud.adv_text.text.contains("зелёные") and hud.adv_text.text.contains("синие") and hud.adv_text.text.contains("«Обзор»"), "в совете — зелёные, синие и «Обзор»")
	hud.advisor_panel.visible = false
	game.set_tool("")
	game.set_tool("stall_fruit")
	hud.set_overlay("happy")
	hud.set_overlay("")
	await frames(2)
	check(not hud.advisor_panel.visible, "второй раз советник молчит")
	game.set_tool("")


# ---------- лавка: ставим ----------

var s1 := {}
var s2 := {}


func _shop_place() -> void:
	s1 = put("stall_fruit", Vector2(158, 146))
	if not check(not s1.is_empty() and bool(s1["active"]), "первая фруктовая лавка работает"):
		return
	var had := with_shop("stall_fruit")
	check(had.size() == int(s1["served"]) and had.size() > 0, "её дома: %d" % had.size())
	# стройка выбрана, курсор ещё не на земле: синие — все дома с фруктовой лавкой, значок над первой
	game.set_tool("stall_fruit")
	await frames(2)
	check(cover.state == "place" and colors_of(Cover.BLUE) == sorted(had.keys()) and colors_of(Cover.GREEN).is_empty(),
		"взяли лавку: синие — %d домов с фруктовой лавкой, зелёных пока нет" % colors_of(Cover.BLUE).size())
	check(cover.marks.has("same%d" % int(s1["id"])) and hud.badges.has("same%d" % int(s1["id"])), "над такой же лавкой — значок")
	# вторая лавка чуть дальше: часть домов уже с фруктовой (синие), часть — новые (зелёные)
	var pl := spot("stall_fruit", Vector2(178, 146))
	if not check(not pl.is_empty(), "место для второй лавки"):
		return
	var P: Vector2 = pl["pos"]
	cover.preview("stall_fruit", P)
	var g := colors_of(Cover.GREEN)
	var dup: int = cover.sets["dup"]
	check(not g.is_empty() and dup > 0, "под второй лавкой: зелёных %d, уже с фруктовой %d" % [g.size(), dup])
	var cap := int(Defs.CAPACITY[int(Defs.B["stall_fruit"]["cap"])])
	check(g.size() + dup == mini(cap, Cover._nearest(c, P, c.shop_range(Defs.B["stall_fruit"]), 999).size()), "зелёные + уже с ней = сколько лавка потянет (%d)" % cap)
	for id in g:
		if had.has(id):
			check(false, "зелёный дом %d уже с фруктовой лавкой" % id)
	check(cover.cap == ["Новых домов: %d" % g.size(), "Уже с фруктовой лавкой: %d" % dup, ""], "подпись: %s" % [cover.cap])
	# тот же метр — ничего не пересчитываем
	var same: Dictionary = cover.sets
	cover.preview("stall_fruit", P + Vector2(0.1, 0.1) if floori(P.x + 0.1) == floori(P.x) and floori(P.y + 0.1) == floori(P.y) else P)
	check(is_same(same, cover.sets), "курсор стоит — наборы не пересчитываются")
	# по-настоящему: мышь над местом — призрак, подсветка и подпись у курсора; снимок
	game.rig.set_view(Vector3(170, 2, 156), 0, 55, 58)
	await frames(10)
	game.set_tool("")
	game.set_tool("stall_fruit")
	move(scr(P))
	await frames(12)
	var near: Vector2 = game.place_info.get("pos", Vector2.INF)
	check(cover.state == "place" and not colors_of(Cover.GREEN).is_empty() and not colors_of(Cover.BLUE).is_empty(), "мышью: зелёные %d, синие %d (лавка у %s)" % [colors_of(Cover.GREEN).size(), colors_of(Cover.BLUE).size(), near])
	var cb: VBoxContainer = hud.cover_box
	check(cb != null and cb.visible and (cb.get_child(0) as Label).text.begins_with("Новых домов:"), "подпись у курсора: «%s»" % ((cb.get_child(0) as Label).text if cb else ""))
	await frames(20)
	check(cover.todo.is_empty() and cover.lit.size() == cover.want.size(), "все подсвеченные дома зажглись: %d" % cover.lit.size())
	await shot("cover_place_shop.png")
	# вечером подсветка так же читается (она без света и тени)
	game._set_hour(20.5)
	await shot("cover_place_shop_evening.png")
	game._set_hour(11.0)
	# сверка с городом: ставим туда, где был призрак, — фруктовую лавку получили ровно зелёные
	var g2 := colors_of(Cover.GREEN)
	var d2: int = cover.sets["dup"]
	var pl2: Dictionary = game.place_info
	game.set_tool("")
	s2 = c.place("stall_fruit", pl2["pos"], pl2["yaw"], pl2["variant"], pl2["color"])
	var now := with_shop("stall_fruit")
	var gained := []
	for id in now:
		if not had.has(id):
			gained.append(int(id))
	gained.sort()
	check(gained == g2, "получили фруктовую лавку ровно зелёные: %s / %s" % [gained, g2])
	check(int(s2["served"]) == g2.size() + d2, "вторая обслуживает %d = зелёные %d + синие %d" % [int(s2["served"]), g2.size(), d2])
	# без домов рядом и «все уже с ней»
	check(Cover.caption("stall_fruit", {"new": 0, "dup": 0})[1].begins_with("Рядом нет домов"), "нет домов рядом — так и сказано")
	check(Cover.caption("potter", {"new": 0, "dup": 3})[1] == "Тут все дома уже с гончарной — поставьте дальше", "все уже с гончарной — «поставьте дальше»")
	check(Cover.caption("potter", {"new": 6, "dup": 3}) == ["Новых домов: 6", "Уже с гончарной: 3", ""], "как просил владелец: «новых домов: 6, уже с гончарной: 3»")
	await _caption_edge()


## Подпись у курсора у правого / нижнего края — целиком на экране (по другую сторону курсора)
func _caption_edge() -> void:
	var rs: Vector2 = hud.root.size
	var long := Cover.caption("musicians", {"new": 0, "dup": 4})
	var mp0: Vector2 = game._mouse_pos
	for at in [Vector2(rs.x - 40, 300), Vector2(rs.x - 40, rs.y - 30), Vector2(rs.x * 0.5, rs.y - 20)]:
		game._mouse_pos = at
		hud.cover_caption(long[0], long[1], long[2])
		var r: Rect2 = hud.cover_box.get_global_rect()
		var fit := r.position.x >= 0.0 and r.end.x <= rs.x and r.position.y >= 0.0 and r.end.y <= rs.y and r.size.x > 200.0
		check(fit, "подпись «%s» у курсора %s — на экране: %s (экран %s)" % [long[1], at, r, rs])
	game._mouse_pos = mp0
	hud.cover_caption("", "", "")
	check(not hud.cover_box.visible, "пустая подпись спрятана")


# ---------- лавка: выбрали ----------

func _shop_selected() -> void:
	if s2.is_empty():
		return
	game.set_tool("")
	game.select_building(s2)
	hud.open_info(s2)
	await frames(3)
	var own: Array = s2["serves"]
	var other := {}
	for hid in s1["serves"]:
		other[int(hid)] = true
	var g := []
	var k := 0
	for id in own:
		if other.has(int(id)):
			k += 1
		else:
			g.append(int(id))
	g.sort()
	check(cover.state == "sel" and colors_of(Cover.GREEN) == g, "выбрали лавку: зелёные — только её (%d)" % g.size())
	check(colors_of(Cover.BLUE) == sorted(other.keys()), "синие — дома другой фруктовой лавки (%d)" % other.size())
	check(int(cover.sets["dup"]) == k and k > 0, "из её домов есть и у другой: %d" % k)
	check(cover.marks.has("same%d" % int(s1["id"])) and not cover.marks.has("same%d" % int(s2["id"])), "значок — над другой такой же, не над выбранной")
	check((hud.badges["same%d" % int(s1["id"])]["cb"] as Callable).is_valid(), "у значка такой же лавки есть действие")
	var tx := texts(hud.info_box)
	var at := tx.find("Из них уже с такой же лавкой")
	check(at >= 0 and at + 1 < tx.size() and tx[at + 1] == str(k), "в карточке: «Из них уже с такой же лавкой: %d»" % k, tx)
	game.rig.set_view(Vector3(170, 2, 156), 0, 55, 58)
	await frames(25)
	await shot("cover_selected.png")
	# неработающая лавка ничего не снабжает: её дома не зелёные
	var r := Cover.selected_sets(c, s2.merged({"active": false}, true))
	check((r["green"] as Array).is_empty() and int(r["own"]) == 0, "неработающая лавка — зелёных нет")
	# щёлкнуть мышью медальон над другой фруктовой лавкой — выбрана она и открыта её карточка
	var key := "same%d" % int(s1["id"])
	var bn: Control = hud.badges[key]["n"]
	if check(bn.visible and bn.mouse_filter == Control.MOUSE_FILTER_PASS, "медальон виден и ловит мышь (без стройки в руках)"):
		var mp: Vector2 = get_viewport().get_final_transform() * bn.get_global_rect().get_center()
		move(mp)
		await frames(2)
		btn(mp, MOUSE_BUTTON_LEFT, true)
		await frames(1)
		btn(mp, MOUSE_BUTTON_LEFT, false)
		await frames(3)
		check(int(game.selected.get("id", -1)) == int(s1["id"]) and int(hud.info_b.get("id", -1)) == int(s1["id"]) and hud.info_panel.visible,
			"щёлкнули медальон — выбрана та лавка и открыта её карточка (выбрано %s)" % game.selected.get("id", -1))
		check(cover.state == "sel" and cover.marks.has("same%d" % int(s2["id"])) and not cover.marks.has(key), "подсветка и медальоны — теперь от неё")
	hud.close_panels()
	await frames(2)
	check(cover.state == "" and cover.want.is_empty(), "сняли выбор — подсветка гаснет")


# ---------- памятник ----------

func _monument() -> void:
	c.research["fountain"] = true
	c.money = 20000.0
	var pl0 := spot("fountain", Vector2(150, 176))
	if not check(not pl0.is_empty(), "место для фонтана"):
		return
	var P: Vector2 = pl0["pos"]
	var r := Defs.range_m(Defs.B["fountain"])
	var s0 := Cover.place_sets(c, "fountain", P)
	var ing := []
	for id in houses():
		if (c.buildings[id]["pos"] as Vector2).distance_to(P) <= r:
			ing.append(id)
	check(sorted(s0["green"]) == sorted(ing) and int(s0["dup"]) == 0, "фонтан, первый: зелёные — все дома в его дальности (%d)" % ing.size())
	var f1: Dictionary = c.place("fountain", P, pl0["yaw"], pl0["variant"], pl0["color"])
	c.compute()
	check(bool(f1["active"]), "фонтан у дороги работает")
	c.money = 20000.0
	var pl1 := spot("fountain", P + Vector2(24, 0))
	if not check(not pl1.is_empty(), "место для второго фонтана"):
		return
	var Q: Vector2 = pl1["pos"]
	var s1m := Cover.place_sets(c, "fountain", Q)
	var had := {}
	for id in houses():
		if (c.buildings[id]["mon_types"] as Dictionary).has("fountain"):
			had[id] = true
	check(sorted(s1m["blue"]) == sorted(had.keys()) and int(s1m["dup"]) > 0 and not (s1m["green"] as Array).is_empty(),
		"второй фонтан: синие — дома первого (%d), из них в его дальности %d, новых %d" % [had.size(), int(s1m["dup"]), (s1m["green"] as Array).size()])
	var f2: Dictionary = c.place("fountain", Q, pl1["yaw"], pl1["variant"], pl1["color"])
	c.compute()
	var gained := []
	for id in houses():
		if (c.buildings[id]["mon_types"] as Dictionary).has("fountain") and not had.has(id):
			gained.append(id)
	check(sorted(gained) == sorted(s1m["green"]), "радость фонтана получили ровно зелёные (%d)" % gained.size())
	check(Cover.caption("fountain", s1m)[0] == "Порадует домов: %d" % (s1m["green"] as Array).size() and Cover.caption("fountain", s1m)[1].begins_with("Уже с фонтаном:"), "подпись фонтана: %s" % [Cover.caption("fountain", s1m)])
	var sel := Cover.selected_sets(c, f2)
	check(int(sel["own"]) == (s1m["green"] as Array).size() + int(s1m["dup"]) and int(sel["dup"]) == int(s1m["dup"]), "выбранный фонтан: своих %d, из них и у первого %d" % [int(sel["own"]), int(sel["dup"])])
	# фонтаны остаются — в «Обзоре» рядом с ними будут счастливые (зелёные) дома


# ---------- украшение ----------

func _decor() -> void:
	c.research["deco_stone"] = true
	# плетень (1 очко) у домов без украшений: +1% только со вторым очком — дома не синие, «уже хватает» не пишем
	var F := Vector2(200, 161)
	var bare := 0
	var deco_any := 0
	for id in houses():
		var h: Dictionary = c.buildings[id]
		if (h["pos"] as Vector2).distance_to(F) <= Defs.DECOR_RADIUS:
			bare += 1
			deco_any += int(h["deco_bonus"])
	var sf := Cover.place_sets(c, "fence", F)
	check(bare > 0 and deco_any == 0, "у плетня %d домов, украшений у них нет" % bare)
	check((sf["blue"] as Array).is_empty() and int(sf["dup"]) == 0 and int(sf["half"]) == bare,
		"плетень у голых домов: синих %d, «уже хватает» %d, копится у %d" % [(sf["blue"] as Array).size(), int(sf["dup"]), int(sf["half"])])
	var cf := Cover.caption("fence", sf)
	check(cf == ["", "", "Со следующим украшением прибавит домам: %d" % bare], "подпись плетня: %s" % [cf])
	# второй плетень рядом — теперь прибавит им всем (зелёные)
	var f1: Dictionary = c.place("fence", F, 0.0, 0, -1, true)
	c.compute()
	var sf2 := Cover.place_sets(c, "fence", F + Vector2(1.5, 0))
	check((sf2["green"] as Array).size() > 0 and (sf2["blue"] as Array).is_empty(), "второй плетень: зелёных %d, синих нет" % (sf2["green"] as Array).size())
	var sel_f := Cover.selected_sets(c, f1)
	check((sel_f["blue"] as Array).is_empty() and int(sel_f["dup"]) == 0 and int(sel_f["half"]) > 0, "выбранный плетень: не синие, копится у %d" % int(sel_f["half"]))
	game.select_building(f1)
	hud.open_info(f1)
	await frames(2)
	var tf := texts(hud.info_box)
	var has_half := false
	for t in tf:
		has_half = has_half or String(t).contains("прибавит вместе со следующим украшением")
	check(has_half and not tf.has("Синим домам украшений уже хватает — больше не прибавится."), "в карточке плетня — «прибавит вместе со следующим», не «уже хватает»")
	hud.close_panels()
	c.remove(f1, false)
	c.compute()
	# три статуи в конце улицы — домам рядом украшений уже хватает (у плебеев до +12%)
	var st := []
	for x in [144.0, 148.0, 152.0]:
		st.append(c.place("statue", Vector2(x, 161), 0.0, 0, -1, true))
	c.compute()
	var P := Vector2(160, 161)
	var s := Cover.place_sets(c, "lamp_post", P)
	check(not (s["green"] as Array).is_empty() and not (s["blue"] as Array).is_empty(), "фонарь: зелёных %d, «уже хватает» %d" % [(s["green"] as Array).size(), (s["blue"] as Array).size()])
	var capped := true
	for id in s["blue"]:
		var h: Dictionary = c.buildings[id]
		capped = capped and int(h["deco_bonus"]) >= int(Defs.CLASSES[c.def(h)["cls"]]["deco_max"])
	check(capped, "синие у фонаря — только дома, где украшений уже сколько можно (+%d%%)" % int(Defs.CLASSES["plebs"]["deco_max"]))
	var sf3 := Cover.place_sets(c, "fence", Vector2(146, 161))
	check(not (sf3["blue"] as Array).is_empty(), "плетень у статуй: дома с полным украшением — синие (%d)" % (sf3["blue"] as Array).size())
	var before := {}
	for id in houses():
		before[id] = int(c.buildings[id]["deco_bonus"])
	var lamp: Dictionary = c.place("lamp_post", P, 0.0, 0, -1, true)
	c.compute()
	var up := []
	for id in houses():
		if int(c.buildings[id]["deco_bonus"]) > int(before[id]):
			up.append(id)
	check(sorted(up) == sorted(s["green"]), "стало лучше ровно зелёным (%d), синим — нет" % up.size())
	var sel := Cover.selected_sets(c, lamp)
	check(sorted(sel["green"]) == sorted(up), "выбранный фонарь: зелёные — кому он что-то даёт")
	# мышью: снимок фонаря у статуй
	game.rig.set_view(Vector3(158, 2, 161), 0, 55, 46)
	await frames(8)
	game.set_tool("lamp_post")
	move(scr(Vector2(160, 161)))
	await frames(30)
	check(cover.state == "place" and (hud.cover_box as Control).visible, "фонарь мышью: подпись «%s / %s»" % [cover.cap[0], cover.cap[1]])
	await shot("cover_place_decor.png")
	game.set_tool("")
	c.remove(lamp, false)
	for b in st:
		c.remove(b, false)


# ---------- склад ----------

func _store() -> void:
	c.research["butcher"] = true
	c.research["warehouse"] = true
	c.money = 20000.0
	# склада нет: зелёных нет, у курсора — предупреждение (лавка всё равно не заработала бы)
	var pb := spot("butcher", Vector2(176, 176))
	if check(not pb.is_empty(), "место для мясной лавки"):
		var sb := Cover.place_sets(c, "butcher", pb["pos"])
		check((sb["green"] as Array).is_empty() and int(sb["dup"]) == 0 and sb["why"] == "store", "мясная без склада: зелёных %d, why «%s»" % [(sb["green"] as Array).size(), sb["why"]])
		check(Cover.caption("butcher", sb) == ["", "", "Нет склада рядом — лавка не заработает"], "подпись: %s" % [Cover.caption("butcher", sb)])
	var bt: Dictionary = put("butcher", Vector2(176, 176))
	c.compute()
	if not check(not bt.is_empty() and bt["why"] == "store", "мясная лавка без склада не работает: «%s»" % bt.get("why", "?")):
		return
	c.money = 20000.0
	var pl := spot("warehouse", Vector2(186, 176))
	if not check(not pl.is_empty(), "место для склада"):
		c.remove(bt, false)
		return
	var s := Cover.place_sets(c, "warehouse", pl["pos"])
	check((s["green"] as Array).has(int(bt["id"])), "склад рядом: мясная лавка зелёная")
	check(Cover.caption("warehouse", s)[0] == "Склад получат лавки: %d" % (s["green"] as Array).size(), "подпись склада: %s" % [Cover.caption("warehouse", s)])
	var w: Dictionary = c.place("warehouse", pl["pos"], pl["yaw"], pl["variant"], pl["color"])
	c.compute()
	check(bt["why"] != "store", "со складом мясная лавка дождалась товара (why «%s»)" % bt["why"])
	var s2s := Cover.place_sets(c, "warehouse", pl["pos"])
	check((s2s["blue"] as Array).has(int(bt["id"])) and int(s2s["dup"]) >= 1, "второй склад туда же: мясная лавка уже со складом (синяя)")
	var sel := Cover.selected_sets(c, w)
	check((sel["green"] as Array).has(int(bt["id"])), "выбранный склад: мясная лавка — его (зелёная)")
	# взяли мясную лавку — значки и над складами (где она заработает), не только над такими же
	game.set_tool("butcher")
	await frames(2)
	check(cover.marks.has("wh%d" % int(w["id"])) and hud.badges.has("wh%d" % int(w["id"])) and cover.marks.has("same%d" % int(bt["id"])), "мясная в руках: значок над складом и над другой мясной")
	game.set_tool("stall_fruit")
	await frames(2)
	check(not cover.marks.has("wh%d" % int(w["id"])), "фруктовой лавке склад не нужен — значка над складом нет")
	# мышью вдали от склада: зелёных нет, у курсора предупреждение, медальон над складом; снимок
	game.set_tool("")
	game.rig.set_view(Vector3(166, 2, 166), 0, 58, 80)
	await frames(6)
	game.set_tool("butcher")
	move(scr(Vector2(142, 146)))
	await frames(14)
	var wp: Vector2 = game.place_info.get("pos", Vector2.INF)
	check(cover.cap[2] == "Нет склада рядом — лавка не заработает" and colors_of(Cover.GREEN).is_empty() and (hud.cover_box as Control).visible,
		"мышью в %s (до склада %.0f м): «%s», зелёных %d" % [wp, wp.distance_to(w["pos"]), cover.cap[2], colors_of(Cover.GREEN).size()])
	await shot("cover_place_no_store.png")
	game.set_tool("")
	# сырья нет: пекарня у склада без пшеничного поля — зелёных нет, подсказка, что нужно
	if not c.goods.has("wheat"):
		var sk := Cover.place_sets(c, "bakery", pl["pos"] + Vector2(6, 0))
		check((sk["green"] as Array).is_empty() and sk["why"] == "good", "пекарня без пшеницы: зелёных нет (why «%s»)" % sk["why"])
		check(Cover.caption("bakery", sk)[2] == "Нет сырья — нужно «%s»" % Defs.B["farm"]["name"], "подпись: %s" % [Cover.caption("bakery", sk)])
	# со складом рядом: зелёные — ровно кто получит мясную лавку на деле
	var bpos: Vector2 = bt["pos"]
	var byaw: float = bt["yaw"]
	var bvar: int = int(bt.get("variant", 0))
	var bcol: int = int(bt.get("color", 0))
	c.remove(bt, false)
	c.compute()
	var had := with_shop("butcher")
	var sg := Cover.place_sets(c, "butcher", bpos)
	check(sg["why"] == "" and not (sg["green"] as Array).is_empty(), "у склада: мясная лавка правда даст мясо — зелёных %d" % (sg["green"] as Array).size())
	c.money = 20000.0
	var bt2: Dictionary = c.place("butcher", bpos, byaw, bvar, bcol)
	c.compute()
	var gained := []
	for id in with_shop("butcher"):
		if not had.has(id):
			gained.append(int(id))
	check(bool(bt2["active"]) and sorted(gained) == sorted(sg["green"]), "мясо получили ровно зелёные: %s / %s" % [sorted(gained), sorted(sg["green"])])
	check(Cover.caption("butcher", sg)[0] == "Новых домов: %d" % (sg["green"] as Array).size(), "подпись: %s" % [Cover.caption("butcher", sg)])
	c.remove(w, false)
	c.remove(bt2, false)


# ---------- «Обзор» ----------

func _overview() -> void:
	game.set_tool("")
	hud.close_panels()
	game.rig.set_view(Vector3(186, 2, 161), 0, 58, 100)
	await frames(5)
	# немного украшений, чтобы были и зелёные, и золотые, и красные дома
	var dec := []
	for x in [160.0, 164.0, 168.0]:
		dec.append(c.place("statue", Vector2(x, 161), 0.0, 0, -1, true))
	c.compute()
	hud._top_action("view")
	await frames(3)
	check(hud.overlay == "happy" and hud.overlay_panel.visible and cover.state == "ov", "глаз открывает «Обзор» — счастье")
	var lived := []
	var want_col := {}
	var n := [0, 0, 0]
	for id in houses():
		var h: Dictionary = c.buildings[id]
		if int(h["pop"]) > 0:
			lived.append(id)
			var hp := clampi(int(h["happy"]), 0, 100)
			var k := 0 if hp >= 65 else (1 if hp >= 40 else 2)
			want_col[id] = [Cover.GREEN, Cover.GOLD, Cover.RED][k]
			n[k] += 1
	var ok: bool = cover.want.size() == lived.size()
	for id in want_col:
		ok = ok and cover.want.get(id) == want_col[id]
	check(ok, "счастье: дома с жильцами подсвечены по порогам 65 / 40 (%s)" % [n])
	check(n[0] > 0 and n[1] > 0 and n[2] > 0, "есть и зелёные, и золотые, и красные: %s" % [n])
	var faces := 0
	for id in lived:
		if hud.badges.has("ov%d" % id) and String(hud.badges["ov%d" % id]["icon"]).begins_with("face_") and hud.badges["ov%d" % id]["text"] == "":
			faces += 1
	check(faces == lived.size(), "камера далеко: над каждым жилым домом — рожица без цифры: %d из %d" % [faces, lived.size()])
	var lt := texts(hud.overlay_panel)
	check(lt.has("%d %s" % [n[0], hud._plural(n[0], "дом", "дома", "домов")]) and hud._ov_title.text == "Счастье каждого дома", "в легенде — сколько домов: %s" % [lt])
	await frames(20)
	await shot("cover_overview_happy_far.png")
	# ближе — рожица и цифра
	game.rig.set_view(Vector3(166, 2, 161), 0, 56, 52)
	await frames(4)
	faces = 0
	for id in lived:
		if hud.badges.has("ov%d" % id) and hud.badges["ov%d" % id]["text"] == "%d%%" % clampi(int(c.buildings[id]["happy"]), 0, 100):
			faces += 1
	check(faces == lived.size(), "камера близко: рожица и цифра у %d из %d" % [faces, lived.size()])
	await frames(20)
	await shot("cover_overview_happy.png")
	await _overview_card(lived)
	game.rig.set_view(Vector3(186, 2, 161), 0, 58, 100)
	await frames(4)
	# одна потребность: еда
	hud.set_overlay("food")
	await frames(3)
	var miss := []
	var fed := 0
	for id in lived:
		if (c.buildings[id]["needs"] as Dictionary).has("food"):
			fed += 1
			ok = ok and cover.want.get(id) == Cover.GREEN
		else:
			miss.append(id)
			ok = ok and cover.want.get(id) == Cover.RED
	check(ok and fed > 0 and miss.size() > 0, "еда: сытые зелёные (%d), без еды красные (%d)" % [fed, miss.size()])
	var xs := 0
	for id in miss:
		if hud.badges.has("ov%d" % id) and hud.badges["ov%d" % id]["icon"] == "close":
			xs += 1
	check(xs == miss.size(), "над домами без еды — ✗ (%d)" % xs)
	check(hud.badges.has("ovs%d" % int(s1["id"])) and hud.badges.has("ovs%d" % int(s2["id"])), "над лавками с едой — их значки")
	check(not hud.badges.has("ov%d" % int(lived[0])) or miss.has(lived[0]), "у сытых домов значка нет")
	await frames(20)
	await shot("cover_overview_food.png")
	# живой: убрали лавку — дома покраснели сами
	var red0: int = colors_of(Cover.RED).size()
	c.remove(s1, false)
	await frames(3)
	check(colors_of(Cover.RED).size() > red0, "убрали лавку — без еды стало %d (было %d)" % [colors_of(Cover.RED).size(), red0])
	# Esc и правая кнопка закрывают; инструмент тоже
	await key(KEY_ESCAPE)
	check(hud.overlay == "" and not hud.overlay_panel.visible and cover.want.is_empty(), "Esc закрывает «Обзор»")
	await frames(2)
	var idle: bool = not cover.pool.visible
	for k in cover.pool.groups:
		for sub in cover.pool.groups[k]["subs"]:
			idle = idle and (sub["mm"] as MultiMesh).visible_instance_count == 0
	check(idle, "подсветки нет — пул вне сцены, MultiMesh не рисуют ни одного места")
	var badge_left := false
	for k in hud.badges:
		badge_left = badge_left or String(k).begins_with("ov")
	check(not badge_left, "значков «Обзора» не осталось")
	check(not hud.pause_panel.visible, "Esc с открытым «Обзором» меню не открывает")
	hud.set_overlay("food")
	await frames(2)
	var mp: Vector2 = scr(Vector2(186, 186))
	move(mp)
	await frames(2)
	btn(mp, MOUSE_BUTTON_RIGHT, true)
	await frames(2)
	btn(mp, MOUSE_BUTTON_RIGHT, false)
	await frames(3)
	check(hud.overlay == "", "правая кнопка закрывает «Обзор»")
	hud.set_overlay("happy")
	game.set_tool("road")
	await frames(2)
	check(hud.overlay == "" and not hud.overlay_panel.visible, "взяли инструмент — «Обзор» закрылся")
	game.set_tool("")
	for b in dec:
		c.remove(b, false)


## Щёлкнули по дому в «Обзоре» — карточка не закрывает окно «Обзора» (режимы, легенду, ✕); и при крупном интерфейсе
func _overview_card(lived: Array) -> void:
	var hid: int = lived[lived.size() / 2]
	var sc0: float = game.settings.get("ui_scale", 1.0)
	for sc in [1.0, 1.4]:
		game.settings["ui_scale"] = sc         # как из настроек: окно, меняя размер, применяет его заново
		hud.apply_scale(sc)
		await frames(3)
		cover._open(hid)
		await frames(4)
		var o: Rect2 = hud.overlay_panel.get_global_rect()
		var i: Rect2 = hud.info_panel.get_global_rect()
		var rs: Vector2 = hud.root.size
		check(hud.info_panel.visible and hud.overlay_panel.visible and hud.overlay == "happy", "карточка дома открыта, «Обзор» на месте (размер %.1f)" % sc)
		check(not o.intersects(i) and o.position.x >= 0.0 and o.end.y <= rs.y, "окно «Обзора» %s не под карточкой %s (размер %.1f → %.2f, экран %s)" % [o, i, sc, get_window().content_scale_factor, rs])
		if sc == 1.0:
			await shot("cover_overview_card.png")
		hud._hide_info()
		await frames(3)
		check(is_equal_approx(hud.overlay_panel.get_global_rect().end.x, hud.root.size.x - 10.0), "карточку закрыли — «Обзор» снова справа (размер %.1f)" % sc)
	game.settings["ui_scale"] = sc0
	hud.apply_scale(sc0)
	await frames(3)


# ---------- большой город: пул, а не призраки ----------

func _big_city() -> void:
	game.set_tool("")
	c.bulk = true
	var add := []
	for i in 16:
		for j in 14:
			add.append(c.place("house_pleb", Vector2(132 + i * 7.5, 196 + j * 4.2), 0.0, i % 5, -1, true))
	c.bulk = false
	c.compute()
	var all := houses()
	check(all.size() >= 250, "домов в городе: %d" % all.size())
	var w := {}
	for id in all:
		w[id] = Cover.BLUE
	var t0 := Time.get_ticks_usec()
	cover._apply(w, Vector2(186, 220))
	var t1 := Time.get_ticks_usec() - t0
	check(cover.lit.size() <= Cover.PER_FRAME and cover.todo.size() > 0 and t1 < 45000, "за кадр зажигается не больше %d домов (сразу %d, %.1f мс — разовый рывок: первые виды деталей)" % [Cover.PER_FRAME, cover.lit.size(), t1 / 1000.0])
	var fr := 0
	while not cover.todo.is_empty() and fr < 100:
		await frames(1)
		fr += 1
	check(cover.lit.size() == all.size() and fr <= 20, "весь город зажёгся за %d кадров" % fr)
	check(cover.pool.get_child_count() < 600, "узлов подсветки: %d (по одному на вид детали, не на дом)" % cover.pool.get_child_count())
	# второй раз (виды деталей уже есть): сколько стоит кадр, в котором зажигаются PER_FRAME домов
	cover._apply({}, Vector2.INF)
	var tf := []
	t0 = Time.get_ticks_usec()
	cover._apply(w, Vector2(186, 220))
	tf.append(Time.get_ticks_usec() - t0)
	while not cover.todo.is_empty():
		t0 = Time.get_ticks_usec()
		cover._light_some()
		tf.append(Time.get_ticks_usec() - t0)
	tf.sort()
	check(tf[tf.size() / 2] < 12000, "кадр зажигания %d домов: середина %.1f мс, худший %.1f мс" % [Cover.PER_FRAME, tf[tf.size() / 2] / 1000.0, tf[-1] / 1000.0])
	# перекрасить десять домов — дёшево
	var w2 := w.duplicate()
	for id in all.slice(0, 10):
		w2[id] = Cover.GREEN
	t0 = Time.get_ticks_usec()
	cover._apply(w2, Vector2.INF)
	var t2 := Time.get_ticks_usec() - t0
	check(t2 < 15000, "перекрасить 10 из %d домов: %.1f мс" % [all.size(), t2 / 1000.0])
	t0 = Time.get_ticks_usec()
	for k in 10:
		Cover.place_sets(c, "stall_fruit", Vector2(150 + k * 7, 186))
	var t3 := (Time.get_ticks_usec() - t0) / 10
	check(t3 < 8000, "наборы для курсора при %d домах: %.2f мс" % [all.size(), t3 / 1000.0])
	# дом перестроили (этаж) — его оболочка заново
	var hid: int = all[0]
	c.buildings[hid]["tier"] = 2
	cover._apply(w2, Vector2.INF)
	var lit_now: int = cover.lit.size()
	await frames(3)
	check(cover.lit.has(hid) and int(cover.lit[hid]["tier"]) == 2 and lit_now >= all.size() - 1, "надстроили этаж — подсветка по новому дому, остальные не гасли (%d)" % lit_now)
	game.rig.set_view(Vector3(186, 2, 215), 0, 60, 150)
	await frames(10)
	await shot("cover_big_city.png")
	# после всего города — подсветить пять домов: пул заново, MultiMesh не рисуют прежний пик пустых мест
	var w5 := {}
	for id in all.slice(0, 5):
		w5[id] = Cover.GREEN
	cover._apply(w5, Vector2.INF)
	var fr5 := 0
	while not cover.todo.is_empty() and fr5 < 10:   # под нагрузкой за первый кадр может зажечься не всё
		await frames(1)
		fr5 += 1
	var drawn := 0
	for k in cover.pool.groups:
		var g: Dictionary = cover.pool.groups[k]
		if not (g["subs"] as Array).is_empty():
			drawn += (g["subs"][0]["mm"] as MultiMesh).visible_instance_count
	check(cover.lit.size() == 5 and cover.todo.is_empty() and drawn <= cover.pool.count() + 8, "после всего города пять домов: рисуется мест %d, живых %d" % [drawn, cover.pool.count()])
	cover.clear()
	await frames(2)
	check(cover.lit.is_empty() and cover.want.is_empty() and not cover.pool.visible, "погасили — пул пуст и вне сцены")
