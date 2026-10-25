extends Node
## Сборка 31, этап 0 плана от 24.10 (docs/PLAN_2026-10-24_tech.md 0.1–0.7) и мелочи владельца (беседка, «Копировать»).
##   bash .work/py/gpu_run.sh res://test_stage0.tscn            — в конце «S0 DONE fails=0»; снимки — .work/gd/a/s0_*.png
##   … -- mode=owner (CIVCITY_SAVEDIR с копией города владельца) — дети без бород в его городе, загрузка и сохранение
##   … -- mode=quit at=2                                         — выход через at секунд после старта (не падает)
## 0.1 просьбы из частей и стрелка к тому, чего не хватает (склад → мясная лавка; закрытое — к исследованиям);
##     у всех просьб подсказка и щелчок; строки условий уровня — тоже со стрелкой и щелчком.
## 0.2 «Скверик»: у курсора «В счёт скверика ✓» / «Далеко от дома — не в счёт» / «Это не дерево — не в счёт»; кусты в счёт;
##     «Ещё 2 дерева стоят дальше 15 м»; чёткий край пятна — только с украшением в руках (Decal и сетка OpenGL); ✓ на 3 с.
## 0.3 дети без бороды, венка и щетины; облик взрослых — как был.
## 0.4 «казна полна — не уместилось»; Esc и правая кнопка посреди мазка — отмена (деньги и мостовая как были).
## 0.5 свиток просьб сворачивается, «✓1», помнится в настройках, при обучении — развёрнут, сам не разворачивается.
## 0.6 «Прямая» у курсора; кольцо ластика красное; «Прямая линия» — своя у дорог и ластика, помнится.
## 0.7 фасад: призрак стоит на месте и меняет облик сразу, панель не пересобирается; цвет не прыгает.
## «Копировать»: кнопка в карточке, F над постройкой, инструмент «Копия» — тип, облик, цвет фасада, поворот.

var game
var c: City
var hud
var fails := 0
var mask := 0
var mode := ""
var cands: Array = []
const SHOTS := "D:/CivCity/.work/gd/a/"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("mode="):
			mode = a.trim_prefix("mode=")
	if mode == "quit":
		_quit_test()
		return
	Game.boot = {"play": "1"} if mode == "owner" else {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, what: String, extra = null) -> bool:
	print(("S0 PASS " if ok else "S0 FAIL ") + what + ("" if ok or extra == null else "  " + str(extra)))
	if not ok:
		fails += 1
	return ok


func shot(name: String) -> void:
	await frames(8)
	DirAccess.make_dir_recursive_absolute(SHOTS)
	get_viewport().get_texture().get_image().save_png(SHOTS + name)
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
	if pressed:
		mask |= 1 << (idx - 1)
	else:
		mask &= ~(1 << (idx - 1))
	e.button_mask = mask
	Input.parse_input_event(e)


func key(k: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.pressed = down
		Input.parse_input_event(ev)
	await frames(3)


func scr(w: Vector2) -> Vector2:
	var cam: Camera3D = get_viewport().get_camera_3d()
	return get_viewport().get_final_transform() * cam.unproject_position(Vector3(w.x, game.land.height_at(w.x, w.y), w.y))


func center_of(ct: Control) -> Vector2:
	return ct.get_viewport().get_final_transform() * (ct.get_global_transform_with_canvas() * (ct.size / 2.0))


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
	for p in cands.slice(0, 160):
		reset()
		var pl: Dictionary = game.placement(type, p)
		if pl["err"] == "":
			return c.place(type, pl["pos"], pl["yaw"], pl["variant"], pl["color"])
	return {}


func texts(n: Node) -> String:
	var out := []
	for l in n.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return " | ".join(out)


func last_event(head: String) -> String:
	for i in range(c.events.size() - 1, -1, -1):
		if String(c.events[i]["text"]).begins_with(head):
			return c.events[i]["text"]
	return ""


## Строка просьбы id в свитке (её прозрачная кнопка)
func task_btn(id: String) -> Button:
	var g := Defs.request(id)
	for row in hud.tasks_box.get_children():
		if row is MarginContainer and texts(row).contains(String(g["text"])):
			for b in row.get_children():
				if b is Button:
					return b
	return null


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	c = game.city
	hud = game.hud
	if mode == "owner":
		await _owner()
		print("S0 DONE fails=%d" % fails)
		get_tree().quit()
		return
	game.can_save = false
	game.settings["tasks_folded"] = false        # gpu_run копирует saves/settings.json — начинаем с развёрнутого
	game.settings.erase("line_road")
	game.settings.erase("line_erase")
	game.speed = 0.0
	game.tutorial.step = Tutorial.STEPS.size()
	game.tutorial.card.visible = false
	c.tips["tut"] = -1
	c.tips["ui"] = 3
	c.tips["rank_pressed"] = true
	c.tips["cover_tip"] = true
	c.tips["free_place"] = true
	hud.apply_reveal(3)
	hud.advisor_panel.visible = false
	c.money = 50000.0
	await frames(5)
	street(Vector2(170, 110), Vector2(170, 178))
	street(Vector2(150, 150), Vector2(214, 150))
	await _requests()
	await _all_requests()
	await _rank_rows()
	await _treasury()
	await _kids()
	await _square()
	await _stroke_cancel()
	await _line_mode()
	await _fold()
	await _facade()
	await _copy()
	print("S0 DONE fails=%d" % fails)
	get_tree().quit()


# ---------- 0.1: «Склад и мясная лавка» — стрелка к тому, чего не хватает ----------

func _requests() -> void:
	print("== 0.1 просьбы из частей")
	for g in Defs.REQUESTS:
		if g["id"] == "store":
			break
		if not c.goals_done.has(g["id"]):
			c.goals_done.append(g["id"])
	hud.refresh()
	await frames(2)
	check(String(c.active_goals(1)[0]["id"]) == "store", "первая просьба — «Склад и мясная лавка»")
	# (b) ничего не изучено — стрелка на «Исследования»
	hud._update_pointer()
	check(hud.pointer_target == hud.top_btns["research"] and hud.pointer_text.text == "Исследования", "(b) ничего не изучено → кнопка исследований", hud.pointer_text.text)
	hud._top_action("research")
	await frames(3)
	check(hud.pointer_target == hud._research_card("warehouse"), "(b) окно исследований → карточка «Склад»")
	hud.close_panels()
	c.research["warehouse"] = true
	var wh := put("warehouse", Vector2(174, 125))
	check(not wh.is_empty() and c.goal_progress("store") == 1, "склад построен: 1/2")
	# (e) склад есть, мясная лавка не изучена — к исследованиям, в окне — на карточку мясной лавки
	hud._update_pointer()
	check(hud.pointer_target == hud.top_btns["research"], "(e) мясная лавка закрыта → кнопка исследований")
	hud._top_action("research")
	await frames(3)
	var pt = hud.pointer_target
	check(hud._research_card("butcher") != null and pt == hud._research_card("butcher"), "(e) окно исследований → карточка «Мясная лавка»",
		"стрелка: %s rid=%s, карточка %s, что делать %s" % [pt, pt.get_meta("rid", "") if pt else "", hud._research_card("butcher"), hud.request_do(c.active_goals(1)[0])])
	await shot("s0_ptr_research.png")
	hud.close_panels()
	# (a) мясная лавка изучена, меню закрыто — к «Лавкам» с подписью «Мясная лавка»; открыто — вкладка «Еда», потом карточка
	c.research["butcher"] = true
	hud._close_tray()
	hud._update_pointer()
	check(hud.pointer_target == hud.cats["commerce"] and hud.pointer_text.text == "Мясная лавка", "(a) меню закрыто → «Лавки», подпись «Мясная лавка»", hud.pointer_text.text)
	hud.open_sub = "clothes"
	hud._toggle_cat("commerce")
	await frames(3)
	hud._update_pointer()
	check(hud.pointer_target != null and String(hud.pointer_target.get_meta("sub", "")) == "food", "(a) открыты «Лавки» на «Одежде» → вкладка «Еда»")
	hud.open_sub = "food"
	hud._fill_cards()
	await frames(2)
	hud._update_pointer()
	check(hud.pointer_target != null and String(hud.pointer_target.get_meta("type", "")) == "butcher", "(a) вкладка «Еда» → карточка мясной лавки")
	await shot("s0_ptr_butcher.png")
	hud._close_tray()
	hud.refresh()
	await frames(2)
	# строка: «Склад ✓ · Мясная лавка 0/1»; щелчок — мясная лавка в руках
	var tb := task_btn("store")
	check(tb != null and texts(tb.get_parent()).contains("Склад ✓ · Мясная лавка 0/1"), "строка: «Склад ✓ · Мясная лавка 0/1»", texts(tb.get_parent()) if tb else "нет строки")
	if tb:
		tb.pressed.emit()
		await frames(3)
		check(game.tool == "butcher", "(d) щелчок по строке → мясная лавка в руках (%s)" % game.tool)
		check(hud.advisor_panel.visible and hud.adv_text.text.contains("Мясная лавка берёт мясо со склада"), "у просьбы — подсказка советника")
	await shot("s0_store_row.png")
	game.set_tool("")
	hud.advisor_panel.visible = false


## (c) у всех просьб — подсказка и что делать (стрелка и щелчок) в состоянии, когда просьба открыта
func _all_requests() -> void:
	print("== 0.1 все просьбы")
	var saved: Array = c.goals_done.duplicate()
	var no_hint := []
	var no_do := []
	var no_target := []
	for g in Defs.REQUESTS:
		if String(g.get("hint", "")) == "":
			no_hint.append(g["id"])
		c.goals_done = []
		for g2 in Defs.REQUESTS:
			if g2["id"] == g["id"]:
				break
			c.goals_done.append(g2["id"])
		if String(g["p"][0]) == "fam" and c.arrivals.is_empty():
			c.arrivals.append(c.new_family("plebs"))         # «Заселите три семьи» — семья ждёт на площади
		hud._fill_families()
		hud._update_pointer()
		var rt: Dictionary = hud._request_target(g)
		var w: Dictionary = rt["do"]
		if w.is_empty() or String(w.get("say", "")) == "":
			no_do.append(g["id"])
		if rt["target"] == null:
			no_target.append("%s(%s)" % [g["id"], w.get("kind", "")])
	c.goals_done = saved
	c.arrivals = []
	hud._fill_families()
	check(Defs.REQUESTS.size() == 33 and no_hint.is_empty(), "просьб %d, без подсказки: %s" % [Defs.REQUESTS.size(), no_hint])
	check(no_do.is_empty(), "просьб, где щелчок ничего не делает: %s" % [no_do])
	check(no_target.is_empty(), "просьб без стрелки: %s" % [no_target])


## (f) строки условий уровней 1–7: у каждой — что делать, подпись и куда показать
func _rank_rows() -> void:
	print("== 0.1 условия уровней")
	var bad := []
	var lvl0 := c.level
	for lv in range(1, 8):
		c.level = lv - 1
		for e: Dictionary in c.rank_needs(lv):
			var w: Dictionary = hud.need_do(e["p"], String(e.get("tool", "")))
			var t: Control = hud._do_target(w)
			if w.is_empty() or String(w.get("say", "")) == "" or t == null:
				bad.append("%d:%s(%s)" % [lv, e["text"], w.get("kind", "")])
	c.level = lvl0
	check(bad.is_empty(), "строк условий без цели: %s" % [bad])
	# карточка станции: невыполненное условие нажимается (щелчок — к делу)
	c.level = 1
	hud.open_info(c.center())
	await frames(3)
	var clickable := 0
	for b in hud.info_box.find_children("*", "Button", true, false):
		if (b as Button).tooltip_text.contains("«") and b.get_parent() is MarginContainer:
			clickable += 1
	check(clickable >= 2, "карточка станции: нажимаемых строк условий %d" % clickable)
	await shot("s0_station_rows.png")
	# подсказка уровня: под постройкой условия — «→ что сделать»
	hud.close_panels()
	hud._show_hover(hud.hover_level)
	hud._hover_hold = 30
	await frames(2)
	check(texts(hud.hover_box).contains("→ "), "подсказка уровня: «→ что сделать» под условием")
	await shot("s0_level_tip.png")
	hud._hide_hover()
	c.level = lvl0


# ---------- 0.4: казна полна ----------

func _treasury() -> void:
	print("== 0.4 казна полна")
	c.research["butcher"] = true
	c.money = c.money_cap() - 50.0 + float(Defs.B["butcher"]["cost"])   # после цены лавки в казне место на 50 ден.
	var bt := put("butcher", Vector2(166, 132))
	var ev := last_event("Просьба выполнена: Склад и мясная лавка")
	check(not bt.is_empty() and ev.contains("казна полна — не уместилось"), "просьба при полной казне: «%s»" % ev)
	c.money = c.money_cap()
	var lost: int = c.legion._give({"money": 120.0})
	check(lost == 120, "Легион: награда при полной казне — не уместилось %d" % lost)
	c.money = 50000.0


# ---------- 0.3: дети без бород ----------

## Причёска по-старому (до сборки 31) — для сверки: взрослые не изменились
func _old_hairs(seed_v: int, female: bool, child: bool, rich: bool) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var pool: Array = Citizen.RICH if rich else Citizen.PLEBS
	var choices := pool.filter(func(n): return (n in Citizen.FEMALE) == female)
	if choices.is_empty():
		choices = pool
	var name: String = choices[rng.randi() % choices.size()]
	var fem: bool = name in Citizen.FEMALE
	rng.randi()                                  # вариант палитры
	var hairs: Array = ["SM_Chr_Hair_Female_0%d" % (1 + rng.randi() % 6)] if fem else ["SM_Chr_Hair_Male_0%d" % (1 + rng.randi() % 7)]
	if not fem and rng.randf() < 0.45:
		hairs.append("SM_Chr_Hair_Beard_0%d" % (1 + rng.randi() % 4))
	if rich and rng.randf() < 0.3:
		hairs.append("SM_Chr_Attach_Crown_Leaf_0%d" % (1 + rng.randi() % 2))
	return hairs


func _hairs_of(cz: Node) -> Array:
	var out := []
	for att in cz.find_children("*", "BoneAttachment3D", true, false):
		for ch in att.get_children():
			out.append(String(ch.name))
	return out


## Вершин ребёнка в пятнах щетины атласа
func _stubble(cz: Node) -> int:
	var n := 0
	for mi: MeshInstance3D in cz.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null or not (mi.mesh is ArrayMesh) or mi.mesh.get_surface_count() != 1:
			continue
		var arr := (mi.mesh as ArrayMesh).surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		for i in v.size():
			if v[i].y > 1.45 and uv[i].x < 0.035 and uv[i].y > 0.825 and uv[i].y < 0.845:
				n += 1
	return n


func _kids() -> void:
	print("== 0.3 дети без бород")
	var kids_beard := 0
	var kids_crown := 0
	var kids_stub := 0
	var kids_head := 0
	var adults_bad := 0
	var adults := 0
	var men_beard := 0
	for i in 240:
		var seed_v := 1000 + i * 7919
		var female := i % 3 == 0
		var child := i % 2 == 0
		var rich := i % 5 == 0
		var rr := RandomNumberGenerator.new()
		rr.seed = seed_v
		var cz := Citizen.create(rr, female, child, rich, "", "patricians" if rich else "plebs")
		var hs := _hairs_of(cz)
		var old := _old_hairs(seed_v, female, child, rich)
		if child:
			for h in hs:
				kids_beard += 1 if h.contains("Beard") else 0
				kids_crown += 1 if h.contains("Crown") else 0
			kids_stub += _stubble(cz)
			var sk: Skeleton3D = cz.find_children("*", "Skeleton3D", true, false)[0]
			if not sk.get_bone_pose_scale(sk.find_bone("Head")).is_equal_approx(Vector3.ONE * Citizen.KID_HEAD):
				kids_head += 1
		else:
			adults += 1
			var a1 := hs.duplicate()
			a1.sort()
			var a2 := old.duplicate()
			a2.sort()
			if a1 != a2:
				adults_bad += 1
			for h in hs:
				men_beard += 1 if h.contains("Beard") else 0
		cz.free()
	check(kids_beard == 0 and kids_crown == 0, "детей 120: бород %d, венков %d" % [kids_beard, kids_crown])
	check(kids_stub == 0, "вершин детей в пятнах щетины: %d" % kids_stub)
	check(kids_head == 0, "голова ребёнка ×%.2f у всех (не так — %d)" % [Citizen.KID_HEAD, kids_head])
	check(adults_bad == 0 and men_beard > 0, "взрослых %d: причёски, бороды, венки как раньше (иначе — %d; бород у мужчин %d)" % [adults, adults_bad, men_beard])
	# на улице: дети в городе (крупно)
	var n := 0
	for r: Dictionary in game.people.residents:
		if r["child"] and r["node"] != null:
			var hs := _hairs_of(r["node"])
			n += 1
			check(not str(hs).contains("Beard") and not str(hs).contains("Crown"), "ребёнок на улице без бороды: %s" % [hs])
			if n >= 3:
				break


# ---------- 0.2: «Скверик» ----------

func _square() -> void:
	print("== 0.2 скверик")
	var sto = game.stories
	sto.force = true
	c.tips["story_square"] = true               # советник про скверик уже объяснял — не закрывает снимок
	for r in ["deco_trees", "deco_flowers", "deco_stone", "fountain"]:
		c.research[r] = true
	var house := put("house_pleb", Vector2(200, 154))
	if not check(not house.is_empty(), "дом для скверика"):
		return
	var hid := int(house["id"])
	c.settled(hid, c.house_cap(house), "Проба")
	var sd := StoryDefs.story("square")
	var si := 0
	for i in (sd["steps"] as Array).size():
		if String((sd["steps"][i] as Dictionary).get("id", "")) == "build":
			si = i
	c.stories["active"] = {"id": "square", "step": si, "home": hid, "fam": "Проба", "flags": {}, "t0": int(c.stories["h"]), "id0": c.next_id}
	var hp: Vector2 = house["pos"]
	var z: Dictionary = sto.zone_goal()
	check(not z.is_empty() and is_equal_approx(float(z["r"]), 15.0) and String(z["label"]) == "скверика", "цель «рядом с домом»: 15 м, «скверика»")
	# строка у курсора: в 8 м — в счёт, в 17 м — далеко, ваза — не дерево
	var n8: Array = sto.zone_note("tree", hp + Vector2(8, 0))
	var n17: Array = sto.zone_note("tree", hp + Vector2(17, 0))
	var npl: Array = sto.zone_note("planter", hp + Vector2(5, 0))
	check(not n8.is_empty() and String(n8[0]) == "В счёт скверика ✓", "дерево в 8 м: «%s»" % [n8])
	check(not n17.is_empty() and String(n17[0]) == "Далеко от дома — не в счёт", "дерево в 17 м: «%s»" % [n17])
	check(not npl.is_empty() and String(npl[0]) == "Это не дерево — не в счёт", "ваза: «%s»" % [npl])
	# кусты — в счёт, вазы и горшки — нет
	var bush_bad := []
	for t in Defs.B:
		var base := Defs.base_of(t)
		var zn: Array = sto.zone_note(t, hp + Vector2(5, 0))
		if base.begins_with("bush") and (zn.is_empty() or not bool(zn[1])):
			bush_bad.append(t)
		if base in ["planter", "flowers"] and (zn.is_empty() or bool(zn[1])):
			bush_bad.append(t)
	check(bush_bad.is_empty(), "все кусты в счёт, вазы и клумбы — нет (не так: %s)" % [bush_bad])
	# подпись у курсора — через game (четвёртая строка), в обоих путях рисования (строка от них не зависит)
	game.set_tool("tree")
	game.place_info = {"_t": "tree", "pos": hp + Vector2(8, 0)}
	game.hover = hp + Vector2(8, 0)
	game._tool_note(false)
	check(hud._note == "В счёт скверика ✓", "у курсора: «%s»" % hud._note)
	game.place_info = {"_t": "tree", "pos": hp + Vector2(17, 0)}
	game._tool_note(false)
	check(hud._note == "Далеко от дома — не в счёт", "у курсора далеко: «%s»" % hud._note)
	# чёткий край — только с украшением в руках (Decal)
	sto._marks(true)
	check(sto._glow != null and sto._glow_edge and sto._glow is Decal and (sto._glow as Decal).texture_albedo == StoryUi.edge_tex(15.0, 0.5),
		"с деревом в руках — чёткий край (Decal %.1f м)" % ((sto._glow as Decal).size.x if sto._glow is Decal else -1.0))
	game.rig.set_view(Vector3(hp.x, 2, hp.y), 20, 55, 42)
	hud.advisor_panel.visible = false
	move(scr(hp + Vector2(8, 0)))
	await frames(4)
	game.place_info = {"_t": "tree", "pos": hp + Vector2(8, 0)}
	await shot("s0_square_edge.png")
	game.set_tool("")
	sto._marks(true)
	check(sto._glow != null and not sto._glow_edge, "без украшения в руках — мягкое пятно, как раньше")
	# путь OpenGL (без Decal): сетка по земле
	sto._area_marks([], c.stories["active"])
	sto._no_decals = true
	game.set_tool("tree")
	sto._marks(true)
	var mi := sto._glow as MeshInstance3D
	check(mi != null and sto._glow_edge and (mi.material_override as StandardMaterial3D).albedo_texture == StoryUi.edge_tex(15.0, 0.5), "OpenGL: чёткий край сеткой")
	game.set_tool("")
	sto._marks(true)
	check(sto._glow is MeshInstance3D and not sto._glow_edge, "OpenGL: без украшения — мягкое пятно")
	sto._area_marks([], c.stories["active"])
	sto._no_decals = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	# 3 скамьи + колодец, деревьев нет — строка тестера; деревья в 17 м — «Ещё 2 дерева…»
	var placed := []
	for v: Vector2 in [Vector2(6, 3), Vector2(-6, 3), Vector2(3, -7)]:
		placed.append(c.place("bench", hp + v, 0.0, 0, -1, true))
	placed.append(c.place("well", hp + Vector2(-8, -2), 0.0, 0, -1, true))
	var row := String(sto.row_info().get("text", ""))
	check(row.contains("скамей 3, деревьев и кустов 0/2, колодцев 1/1"), "строка тестера: «%s»" % row)
	var t1 := c.place("tree", hp + Vector2(17, 4), 0.0, 0, -1, true)
	var t2 := c.place("cypress", hp + Vector2(-4, 17), 0.0, 0, -1, true)
	row = String(sto.row_info().get("text", ""))
	check(row.contains("Ещё 2 дерева стоят дальше 15 м — подвиньте их ближе"), "два дерева в 17 м: «%s»" % row)
	c.remove(t1, false)
	var t1b := c.place("tree", hp + Vector2(10, 2), 0.0, 0, -1, true)
	row = String(sto.row_info().get("text", ""))
	check(row.contains("деревьев и кустов 1/2") and row.contains("Ещё 1 дерево стоит дальше 15 м — подвиньте его ближе"), "одно подвинули: «%s»" % row)
	# ✓ на 3 с над тем, что в счёт
	sto.flash_counted(t1b)
	var oks := 0
	for k in hud.badges:
		if String(k).begins_with("zok"):
			oks += 1
	check(oks == 5, "✓ над тем, что в счёт: %d (3 скамьи, колодец, дерево в 10 м)" % oks)
	hud.advisor_panel.visible = false
	await shot("s0_square_flash.png")
	sto._flash_until = 0
	await frames(3)
	var left := 0
	for k in hud.badges:
		if String(k).begins_with("zok"):
			left += 1
	check(left == 0, "✓ погасли")
	for b in placed + [t2, t1b]:
		if c.buildings.has(int(b["id"])):
			c.remove(b, false)
	# «Дом молодым» (свадьба): ✓ только над новым домом ремесленников со свободными местами — старый рядом не в счёт
	var old_a := c.place("house_artisan", hp + Vector2(12, 9), 0.0, 0, -1, true)
	var wsd := StoryDefs.story("wedding")
	var wi := 0
	for i in (wsd["steps"] as Array).size():
		if String((wsd["steps"][i] as Dictionary).get("id", "")) == "house":
			wi = i
	c.stories["active"] = {"id": "wedding", "step": wi, "home": hid, "fam": "Проба", "flags": {"choice": "garden"}, "t0": int(c.stories["h"]), "id0": c.next_id}
	var new_a := c.place("house_artisan", hp + Vector2(-12, 9), 0.0, 0, -1, true)
	sto.flash_counted(new_a)
	var wk := []
	for k in hud.badges:
		if String(k).begins_with("zok"):
			wk.append(String(k))
	check(wk == ["zok%d" % int(new_a["id"])], "дом молодым: ✓ только над новым домом (%s; старый zok%d)" % [wk, int(old_a["id"])])
	sto._flash_clear()
	for b in [old_a, new_a]:
		if c.buildings.has(int(b["id"])):
			c.remove(b, false)
	c.stories["active"] = {}
	sto._marks(true)


# ---------- 0.4: Esc и правая кнопка посреди мазка ----------

func _stroke_cancel() -> void:
	print("== 0.4 отмена мазка")
	game.rig.set_view(Vector3(190, 2, 165), 15, 58, 40)
	await frames(20)
	hud.close_panels()
	hud._close_tray()
	game.set_tool("road")
	await frames(3)
	var kind0: PackedByteArray = game.land.kind.duplicate()
	var h0: PackedFloat32Array = game.land.h.duplicate()
	var m0: float = c.money
	var a := scr(Vector2(180, 160))
	var b := scr(Vector2(200, 168))
	move(a)
	await frames(3)
	btn(a, MOUSE_BUTTON_LEFT, true)
	for k in 20:
		move(a.lerp(b, k / 19.0))
		await frames(1)
	check(game.painting and c.money < m0, "мазок идёт: потрачено %.0f ден." % (m0 - c.money))
	await key(KEY_ESCAPE)
	check(not game.painting and game.tool == "road", "Esc: мазок отменён, мостовая в руках (%s)" % game.tool)
	check(is_equal_approx(c.money, m0), "Esc: деньги как были (%.1f / %.1f)" % [c.money, m0])
	check(game.land.kind == kind0 and game.land.h == h0, "Esc: земля и мостовая как были")
	btn(b, MOUSE_BUTTON_LEFT, false)
	await frames(3)
	check(game.undo_stack.is_empty() or is_equal_approx(c.money, m0), "отпустили кнопку — ничего не проложено")
	await key(KEY_ESCAPE)
	check(game.tool == "", "второй Esc снимает инструмент")
	# правая кнопка посреди мазка — так же
	game.set_tool("road")
	move(a)
	await frames(3)
	btn(a, MOUSE_BUTTON_LEFT, true)
	for k in 12:
		move(a.lerp(b, k / 11.0))
		await frames(1)
	btn(b, MOUSE_BUTTON_RIGHT, true)
	await frames(2)
	btn(b, MOUSE_BUTTON_RIGHT, false)
	await frames(2)
	btn(b, MOUSE_BUTTON_LEFT, false)
	await frames(3)
	check(game.tool == "road" and is_equal_approx(c.money, m0) and game.land.kind == kind0, "правая кнопка посреди мазка: отмена, мостовая в руках")
	# мазок с карты над окном: кисть идёт дальше, отпустили над окном — мазок кончился
	var over := center_of(hud.bar_mid)
	move(a)
	await frames(3)
	btn(a, MOUSE_BUTTON_LEFT, true)
	for k in 10:
		move(a.lerp(over, k / 9.0))
		await frames(1)
	check(game.painting and game.brush_ring.visible, "мазок над окном: кисть ведём дальше")
	btn(over, MOUSE_BUTTON_LEFT, false)
	await frames(3)
	check(not game.painting, "отпустили над окном — мазок кончился")
	if not game.undo_stack.is_empty():
		game._undo()
	game.set_tool("")


# ---------- 0.6: «Прямая» у курсора, цвет кольца, «Прямая линия» у дорог и ластика своя ----------

func _line_mode() -> void:
	print("== 0.6 прямая линия")
	var p := scr(Vector2(190, 172))
	game.set_tool("road")
	move(p)
	await frames(4)
	check(hud._note == "", "свободно — без «Прямая»: «%s»" % hud._note)
	hud._road_opt("linestraight")
	await frames(3)
	check(game.brush_line and hud._note == "Прямая" and bool(game.settings.get("line_road", false)), "мостовая, прямая линия: у курсора «%s»" % hud._note)
	var lt := hud.road_panel.find_child("line_tip", true, false) as Label
	check(lt != null and lt.visible and lt.text.contains("ляжет при отпускании"), "в панели — как работает прямая")
	await shot("s0_line_tag.png")
	game.set_tool("")                          # ролик обучения снимает инструмент — «Прямая» гаснет сразу, до кадра
	check(hud._note == "", "сняли инструмент — «Прямая» у курсора погасла сразу («%s»)" % hud._note)
	for t in ["path", "plaza"]:
		game.set_tool(t)
		await frames(3)
		check(game.brush_line and hud._note == "Прямая", "%s: прямая линия та же, «Прямая» у курсора" % t)
	game.set_tool("erase")
	await frames(3)
	check(not game.brush_line and hud._note == "", "ластик: своя «Прямая линия» (выкл)")
	var rc := (game.brush_ring.material_override as StandardMaterial3D).albedo_color
	check(rc.r > 0.9 and rc.g < 0.45 and rc.b < 0.45, "кольцо ластика красное %s" % rc)
	await shot("s0_erase_ring.png")
	hud._road_opt("linestraight")
	await frames(3)
	check(game.brush_line and hud._note == "Прямая" and bool(game.settings.get("line_erase", false)), "ластик, прямая: «Прямая»")
	game.set_tool("road")
	var rc2 := (game.brush_ring.material_override as StandardMaterial3D).albedo_color
	await frames(3)
	rc2 = (game.brush_ring.material_override as StandardMaterial3D).albedo_color
	check(rc2.g > 0.9, "кольцо мостовой — кремовое %s" % rc2)
	# после перезапуска: настройки в файле
	var f = JSON.parse_string(FileAccess.get_file_as_string(game.settings_path()))
	check(typeof(f) == TYPE_DICTIONARY and bool(f.get("line_road", false)) and bool(f.get("line_erase", false)), "«Прямая линия» дорог и ластика — в файле настроек")
	hud._road_opt("linefree")
	game.set_tool("erase")
	hud._road_opt("linefree")
	game.set_tool("")


# ---------- 0.5: свиток просьб сворачивается ----------

func _fold() -> void:
	print("== 0.5 свиток сворачивается")
	c.goals_done = ["road1", "houses3", "fam3"]
	hud.refresh()
	await frames(3)
	var ws0 := DisplayServer.window_get_size()
	var fb: Button = null
	for b in hud.tasks_box.find_children("fold", "Button", true, false):
		fb = b
	if not check(fb != null, "кнопка «Свернуть свиток» в заголовке"):
		return
	fb.pressed.emit()
	await frames(15)
	check(hud.tasks_folded() and texts(hud.tasks_box).contains("Просьбы · 3"), "свёрнут: «%s»" % texts(hud.tasks_box))
	var f = JSON.parse_string(FileAccess.get_file_as_string(game.settings_path()))
	check(typeof(f) == TYPE_DICTIONARY and bool(f.get("tasks_folded", false)), "свёрнутость — в файле настроек")
	check(DisplayServer.window_get_size() == ws0, "окно не трогали (настройки не применялись заново)")
	await shot("s0_fold.png")
	# выполнили просьбу — «✓1», свиток сам не разворачивается
	c.goals_done.append("fruit")
	hud.refresh()
	await frames(3)
	check(hud.tasks_folded() and texts(hud.tasks_box).contains("✓1") and hud._fold_glow_until > Time.get_ticks_msec(), "выполнена просьба — «✓1» светится, свиток свёрнут")
	await shot("s0_fold_badge.png")
	# смена города: свёрнутость остаётся, счёт «✓» — с нуля
	hud._fold_city = null
	hud.refresh()
	await frames(2)
	check(hud.tasks_folded() and not texts(hud.tasks_box).contains("✓"), "другой город: свёрнут, «✓» с нуля")
	# обучение: свиток развёрнут и без кнопки
	game.tutorial.step = 0
	check(not hud.tasks_folded(), "при обучении свиток не свёрнут")
	game.tutorial.step = Tutorial.STEPS.size()
	game.tutorial.card.visible = false
	# советник про истории и скверик при свёрнутом свитке — как добраться до золотой строки и «Готово»
	c.tips.erase("story_tip")
	hud.advisor_panel.visible = false
	c.stories["offer"] = {"id": "square", "home": -1}
	game.stories._advise_once()
	check(hud.advisor_panel.visible and hud.adv_text.text.contains("на свёрнутом свитке") and hud.adv_text.text.contains("разверните свиток и нажмите «Отложить»"),
		"свиток свёрнут — советник про истории говорит, как его развернуть")
	c.stories["offer"] = {}
	hud.advisor_panel.visible = false
	var sq := put("house_pleb", Vector2(160, 120))
	var sqd := StoryDefs.story("square")
	var sqi := 0
	for i in (sqd["steps"] as Array).size():
		if String((sqd["steps"][i] as Dictionary).get("id", "")) == "build":
			sqi = i
	if check(not sq.is_empty(), "дом для советника про скверик"):
		c.tips.erase("story_square")
		c.stories["active"] = {"id": "square", "step": sqi, "home": int(sq["id"]), "fam": "Проба", "flags": {}, "t0": int(c.stories["h"]), "id0": c.next_id}
		game.stories._advise_square()
		check(hud.advisor_panel.visible and hud.adv_text.text.contains("сейчас свиток свёрнут, разверните его"), "свиток свёрнут — советник про скверик говорит, где «Готово»")
		c.stories["active"] = {}
		c.remove(sq, false)
	hud.advisor_panel.visible = false
	# развернуть щелчком по полоске
	var ub: Button = null
	for b in hud.tasks_box.find_children("unfold", "Button", true, false):
		ub = b
	check(ub != null, "полоска — кнопка «развернуть»")
	if ub:
		ub.pressed.emit()
		await frames(5)
	check(not hud.tasks_folded() and texts(hud.tasks_box).contains("Просьбы горожан"), "развернули")


# ---------- 0.7: фасад меняется сразу ----------

func _facade() -> void:
	print("== 0.7 фасад")
	game.rig.set_view(Vector3(175, 2, 152), 15, 58, 30)
	await frames(15)
	hud.close_panels()
	game.tool_variant = 0
	game.next_variant = 0
	hud.select_build("house_pleb")
	await frames(3)
	hud._close_tray()                      # свиток с карточками закрыт — призрак не под ним
	move(scr(Vector2(180, 154)))
	await frames(8)
	check(game.ghost != null and game.ghost.visible and not hud.mouse_over_ui(), "призрак дома виден")
	var col0: int = int(game.place_info.get("color", -1))
	move(scr(Vector2(170, 154)))           # на 10 м в сторону — цвет «Авто» тот же
	await frames(8)
	check(int(game.place_info.get("color", -2)) == col0, "цвет «Авто» не прыгает (%d / %d)" % [int(game.place_info.get("color", -2)), col0])
	var xf0: Transform3D = game.ghost.transform
	var key0: String = game.ghost_key
	await shot("s0_facade_before.png")
	var b3: Button = null
	for b in hud.variant_box.get_children():
		if b is Button and int(b.get_meta("vi", -1)) == 2:
			b3 = b
	if not check(b3 != null, "кнопка «Фасад 3»"):
		return
	var n0: int = hud.variant_box.get_child_count()
	move(center_of(b3))
	await frames(4)
	xf0 = game.ghost.transform                 # где призрак остался, когда мышь ушла на панель
	await frames(6)
	check(game.ghost != null and game.ghost.visible and game.ghost.transform.is_equal_approx(xf0), "мышь над панелью — призрак виден и стоит на месте")
	btn(center_of(b3), MOUSE_BUTTON_LEFT, true)
	await frames(2)
	btn(center_of(b3), MOUSE_BUTTON_LEFT, false)
	await frames(6)
	var k0 := key0.split(":")
	var k1 := String(game.ghost_key).split(":")
	check(game.ghost.visible and game.ghost.transform.is_equal_approx(xf0), "щёлкнули «3» — призрак на том же месте")
	check(k1.size() == 4 and k1[0] == k0[0] and k1[1] == k0[1] and k1[2] == "2" and k1[3] == k0[3], "в ключе призрака поменялся только фасад: %s → %s" % [key0, game.ghost_key])
	check(is_instance_valid(b3) and not b3.is_queued_for_deletion() and hud.variant_box.get_child_count() == n0, "панель не пересобрана (кнопка та же)")
	await shot("s0_facade_after.png")
	game.set_tool("")


# ---------- «Копировать» ----------

func _copy() -> void:
	print("== Копировать")
	game.set_tool("")
	game.tool_variant = -1                     # игрок выбирал «Случайный» фасад
	var src := put("house_pleb", Vector2(184, 146))
	if not check(not src.is_empty(), "дом-образец"):
		return
	src["variant"] = 2
	src["color"] = 5
	game._hide(src)
	game._show(src)
	hud.open_info(src)
	await frames(4)
	var cb: Button = null
	for b in hud.info_box.find_children("*", "Button", true, false):
		if (b as Button).text == "Копировать":
			cb = b
	if not check(cb != null, "кнопка «Копировать» в карточке дома"):
		return
	await shot("s0_copy_card.png")
	cb.pressed.emit()
	await frames(3)
	check(game.tool == "house_pleb" and game.next_variant == 2 and game.tool_variant == 2 and game.place_color == 5 and is_equal_approx(game.tool_yaw, float(src["yaw"])),
		"копия: тип %s, фасад %d, цвет %d, поворот %.2f" % [game.tool, game.next_variant, game.place_color, game.tool_yaw])
	move(scr(Vector2(204, 146)))
	await frames(6)
	check(int(game.place_info.get("variant", -1)) == 2 and int(game.place_info.get("color", -1)) == 5, "призрак копии — тот же фасад и цвет")
	# украшение под поворотом — F наведением
	game.set_tool("")
	c.research["deco_stone"] = true
	var st := c.place("statue_2", Vector2(196, 160), 0.9, 0, -1, true)
	game._show(st)
	await frames(3)
	move(scr(Vector2(196, 160)))
	await frames(6)
	await key(KEY_F)
	check(game.tool == "statue_2" and is_equal_approx(game.tool_yaw, 0.9), "F над статуей — она в руках, поворот %.2f" % game.tool_yaw)
	move(scr(Vector2(200, 164)))
	await frames(6)
	check(is_equal_approx(float(game.place_info.get("yaw", 0.0)), 0.9), "призрак статуи повёрнут как образец")
	# инструмент «Копия»: щелчок по дому
	game.set_tool("copy")
	move(scr(src["pos"]))
	await frames(6)
	btn(scr(src["pos"]), MOUSE_BUTTON_LEFT, true)
	await frames(2)
	btn(scr(src["pos"]), MOUSE_BUTTON_LEFT, false)
	await frames(4)
	check(game.tool == "house_pleb" and game.place_color == 5 and game.next_variant == 2, "инструмент «Копия» — тот же облик и цвет")
	# ту же карточку взяли из свитка сами — копия кончилась: фасад «Случайный», цвет «Авто»
	hud.select_build("house_pleb")
	check(game.tool == "house_pleb" and not game.copy_color and not game.color_lock and game.tool_variant == -1 and game.place_color == -1,
		"карточка «Дом плебеев» после копии — обычная стройка (фасад %d, цвет %d, копия %s)" % [game.tool_variant, game.place_color, game.copy_color])
	game.set_tool("")
	check(game.tool_variant == -1 and not game.copy_color, "копию отложили — фасад снова «Случайный» (%d)" % game.tool_variant)


# ---------- город владельца: загрузка, дети, сохранение ----------

func _owner() -> void:
	print("== город владельца")
	check(c.buildings.size() > 100 and int(c.stats.get("pop", 0)) > 100, "город загружен: построек %d, жителей %d" % [c.buildings.size(), int(c.stats.get("pop", 0))])
	var kids := 0
	var bad := 0
	var stub := 0
	for r: Dictionary in game.people.residents:
		if not r["child"]:
			continue
		kids += 1
		var rr := RandomNumberGenerator.new()
		rr.seed = int(r["seed"])
		var cz := Citizen.create(rr, r["female"], true, r["rich"], "", r["cls"])
		var hs := str(_hairs_of(cz))
		if hs.contains("Beard") or hs.contains("Crown"):
			bad += 1
		stub += _stubble(cz)
		cz.free()
	check(kids > 0 and bad == 0 and stub == 0, "детей в городе %d: с бородой или венком %d, вершин щетины %d" % [kids, bad, stub])
	game.can_save = true
	game.save()                                  # сохранение города (в копии) — без ругани Marshalls в журнал
	print("S0 OWNER saved")
	game.can_save = false
	await frames(3)


# ---------- выход посреди картинок карточек ----------

func _quit_test() -> void:
	var at := 2.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("at="):
			at = float(a.trim_prefix("at="))
	Game.boot = {"new": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().create_timer(at).timeout
	print("S0 QUIT at=%.1f" % at)
	get_tree().quit()
