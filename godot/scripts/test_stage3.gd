extends Node
## Этап 3 плана от 24.10 (docs/PLAN_2026-10-24_tech.md 3.1–3.10) и дополнения владельца: заборы мышью, настенные украшения.
##   bash .work/py/gpu_run.sh res://test_stage3.tscn            — в конце «S3 DONE fails=0»; снимки — .work/gd/b/s3_*.png
##   … -- mode=owner (CIVCITY_SAVEDIR с копией города владельца) — старые украшения на стенах и заборы, сохранение,
##        скорость мазка на «Низкой» (3.3: кадры мазка ≤ покоя + 6 мс, кадр отпускания ≤ 40 мс)
## 3.1 прямая дорога видна с нажатия, цена у курсора, «денег хватит до сюда», при отпускании — ровно показанное и по той же цене
## 3.2 ластик: красным только дорога, убирает при отпускании, Esc — ничего не убрано, одна отмена
## 3.3 мазок: высоты и пересчёт города — после отпускания, сетка — только где поменялись уступы
## 3.4 живая картинка и ряд цветов; 3.5 ошибка у курсора, стрелка у входа, вспышка у дороги, значок «Z/X» 3 раза
## 3.6 отмена постройки 30 с; 3.7 деревья сквозь призрак; 3.8 подпись при наведении, колёсико к курсору, двойной щелчок
## 3.9 склад и лавки; 3.10 выключен (владелец 12.10: без превращений) — фонарь у стены остаётся фонарём на столбе;
## заборы; настенные украшения (этаж, перенос, окна)

var game
var c: City
var hud
var land: Land
var fails := 0
var mask := 0
var mode := ""
var cands: Array = []
const SHOTS := "D:/CivCity/.work/gd/b/"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("mode="):
			mode = a.trim_prefix("mode=")
	Game.boot = {"play": "1", "hour": "11"} if mode == "owner" else {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func check(ok: bool, what: String, extra = null) -> bool:
	print(("S3 PASS " if ok else "S3 FAIL ") + what + ("" if ok or extra == null else "  " + str(extra)))
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


func btn(p: Vector2, idx: int, pressed: bool, dbl := false) -> void:
	var e := InputEventMouseButton.new()
	e.position = p
	e.global_position = p
	e.button_index = idx
	e.pressed = pressed
	e.double_click = dbl
	if pressed:
		mask |= 1 << (idx - 1)
	else:
		mask &= ~(1 << (idx - 1))
	e.button_mask = mask
	Input.parse_input_event(e)


func click(p: Vector2) -> void:
	move(p)
	await frames(3)
	btn(p, MOUSE_BUTTON_LEFT, true)
	await frames(2)
	btn(p, MOUSE_BUTTON_LEFT, false)
	await frames(3)


func key(k: Key, ctrl := false, shift := false) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.pressed = down
		ev.ctrl_pressed = ctrl
		ev.shift_pressed = shift
		Input.parse_input_event(ev)
	await frames(3)


func scr(w: Vector2) -> Vector2:
	return scr3(Vector3(w.x, land.height_at(w.x, w.y), w.y))


func scr3(w: Vector3) -> Vector2:
	var cam: Camera3D = get_viewport().get_camera_3d()
	return get_viewport().get_final_transform() * cam.unproject_position(w)


func center_of(ct: Control) -> Vector2:
	return ct.get_viewport().get_final_transform() * (ct.get_global_transform_with_canvas() * (ct.size / 2.0))


## Тянуть с зажатой кнопкой от a до b (экран) за n кадров; release — отпустить в конце
func drag(a: Vector2, b: Vector2, n := 20, release := true) -> void:
	move(a)
	await frames(3)
	btn(a, MOUSE_BUTTON_LEFT, true)
	await frames(2)
	for k in n:
		move(a.lerp(b, float(k + 1) / n))
		await frames(1)
	await frames(2)
	if release:
		btn(b, MOUSE_BUTTON_LEFT, false)
		await frames(3)


## Время главного потока за кадр (как test_perf): от начала кадра (process_frame) до начала отрисовки (frame_pre_draw)
var _t_frame := 0
var _last_ms := 0.0


func _on_frame() -> void:
	_t_frame = Time.get_ticks_usec()


func _on_pre_draw() -> void:
	if _t_frame > 0:
		_last_ms = (Time.get_ticks_usec() - _t_frame) / 1000.0


func frame_ms() -> float:
	return _last_ms


func reset() -> void:
	game.last_snap_n = Vector2.ZERO
	game.last_snap_p = Vector2.INF
	game.manual_yaw = false
	game.yaw_set = false
	game.place_lock = {}
	game.tool_yaw = 0.0
	game.snap = true


func street(a: Vector2, b: Vector2, r := 1.3) -> void:
	var ch: Array = land.paint_line(a, b, r, Land.Kind.ROAD, true)
	c.road_cells += ch.size()
	game.people.refresh(land.road_chunks.keys())
	var dir := (b - a).normalized()
	var side := Vector2(-dir.y, dir.x)
	for i in int(a.distance_to(b)) + 1:
		for s in [-3.2, 3.2]:
			cands.append(a + dir * i + side * s)


## Поставить у дороги в ближайшей к цели годной точке
func put(type: String, target: Vector2) -> Dictionary:
	cands.sort_custom(func(p, q): return p.distance_squared_to(target) < q.distance_squared_to(target))
	for p in cands.slice(0, 200):
		reset()
		var pl: Dictionary = game.placement(type, p)
		if pl["err"] == "":
			return c.place(type, pl["pos"], pl["yaw"], pl["variant"], pl["color"])
	return {}


## Поставить игроком (как щелчком — _build_here, с отменой 30 с) у дороги в ближайшей к цели годной точке
func build_at(type: String, target: Vector2) -> Dictionary:
	game.set_tool(type)
	cands.sort_custom(func(p, q): return p.distance_squared_to(target) < q.distance_squared_to(target))
	for p in cands.slice(0, 200):
		reset()
		var pl: Dictionary = game.placement(type, p)
		if pl["err"] != "":
			continue
		game.place_lock = {"p": pl["pos"]}
		game.tool_yaw = float(pl["yaw"])
		if game.placement(type, p)["err"] != "":
			continue
		var n0: int = c.next_id
		game._build_here()
		reset()
		return c.buildings.get(n0, {})
	reset()
	return {}


func texts(n: Node) -> String:
	var out := []
	for l in n.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return " | ".join(out)


## Пиксель маски показа мазка (R — ляжет / уберёт, G — денег не хватит) под клеткой k
func prev_px(k: int) -> Color:
	if game.prev_img == null:
		return Color(0, 0, 0, 0)
	return game.prev_img.get_pixel((k % Land.N) / Land.SM, (k / Land.N) / Land.SM)


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	c = game.city
	hud = game.hud
	land = game.land
	get_tree().process_frame.connect(_on_frame)
	RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	# картинки карточек дорисовываются в первые кадры (после правок облика — все) — замеры кадров только после них
	var t0 := Time.get_ticks_msec()
	while hud.icons.size() < Defs.B.size() - 1 and Time.get_ticks_msec() - t0 < 180000:
		await frames(10)
	await frames(30)
	if mode == "owner":
		await _owner()
		print("S3 DONE fails=%d" % fails)
		get_tree().quit()
		return
	game.can_save = false
	game.settings["tasks_folded"] = false
	game.settings.erase("line_road")
	game.settings.erase("line_erase")
	game.settings.erase("rot_hint")
	game.settings["tip_fence"] = true          # советы об этом — не в проверке (окно советника под курсором)
	game.settings["tip_wall"] = true
	game.speed = 0.0
	game.tutorial.step = Tutorial.STEPS.size()
	game.tutorial.card.visible = false
	c.tips["tut"] = -1
	c.tips["ui"] = 3
	c.tips["rank_pressed"] = true
	c.tips["cover_tip"] = true
	c.tips["free_place"] = true
	c.tips["floor_tool"] = true
	# советы экономики v2 — тоже не в проверке: «Разнообразие радует больше» (второй такой же факел у дома) вставал
	# свитком посреди экрана, прямо над верхним этажом, куда наводим украшения
	for t in ["dim_tip", "floor_money", "tax_tip"]:
		c.tips[t] = true
	hud.apply_reveal(3)
	hud.advisor_panel.visible = false
	for r in ["q_garden", "q_lights", "deco_metal", "deco_flowers", "deco_trees", "warehouse", "butcher", "bakery", "floor2", "floor3"]:
		c.research[r] = true
	for t in ["house_artisan", "house_patrician", "taberna"]:
		if String(Defs.B[t].get("unlock", "")) != "":
			c.research[String(Defs.B[t]["unlock"])] = true
	for g in Defs.REQUESTS:
		if not c.goals_done.has(g["id"]):
			c.goals_done.append(g["id"])        # без наград просьб: казна не упирается в предел посреди проверок
	c.money = 50000.0
	await frames(5)
	street(Vector2(160, 110), Vector2(160, 200))
	street(Vector2(150, 150), Vector2(240, 150))
	street(Vector2(220, 120), Vector2(220, 200))
	await frames(10)
	await _line()
	await _eraser()
	await _stroke_cost()
	await _square_line()
	await _thumb_color()
	await _cursor_feedback()
	await _undo_place()
	await _trees()
	await _hover_camera()
	await _warehouse()
	await _fences()
	await _wall_decor()
	await _wall_forms()
	print("S3 DONE fails=%d" % fails)
	get_tree().quit()


# ---------- 3.1: прямая видна с нажатия, цена, «денег хватит до сюда» ----------

func _line() -> void:
	print("== 3.1 прямая дорога")
	game.rig.set_view(Vector3(196, 2, 178), 0, 62, 34)
	await frames(20)
	hud.close_panels()
	game.set_tool("road")
	hud._road_opt("linestraight")
	game.brush_r = 1.0
	await frames(3)
	var A := Vector2(186, 176)
	var B := Vector2(206, 176)
	var kind0: PackedByteArray = land.kind.duplicate()
	var m0: float = c.money
	move(scr(A))
	await frames(3)
	btn(scr(A), MOUSE_BUTTON_LEFT, true)
	await frames(2)
	check(game.painting and not game.line_plan.is_empty() and game._prev_mode == 1 and (game.line_plan["cells"] as PackedInt32Array).size() > 20,
		"прямая видна с нажатия: %d клеток" % (game.line_plan.get("cells", PackedInt32Array()) as PackedInt32Array).size())
	for k in 12:
		move(scr(A).lerp(scr(B), 0.5 * (k + 1) / 12.0))
		await frames(1)
	await frames(3)
	# на полпути: показ покрывает ≥ 95% клеток, которые лягут (до 0 из 41 — было)
	var lc: Dictionary = land.line_cells(game.line_from, game._prev_at, game.brush_r, Land.Kind.ROAD, false, true)
	var tot := 0
	var cov := 0
	for n in (lc["cells"] as PackedInt32Array).size():
		if int(lc["fresh"][n]) == 1:
			tot += 1
			if prev_px(int(lc["cells"][n])).r > 0.2:
				cov += 1
	check(tot > 50 and cov >= tot * 0.95, "на полпути показ покрывает клеток %d из %d" % [cov, tot])
	check(land.kind == kind0 and is_equal_approx(c.money, m0), "пока тянут — земля и казна не тронуты")
	var lbl: String = hud._stroke_lbl.text if hud._stroke_lbl else ""
	check(lbl.contains(" м · ") and lbl.ends_with("ден."), "у курсора «%s»" % lbl)
	await shot("s3_line_mid.png")
	for k in 12:
		move(scr(A).lerp(scr(B), 0.5 + 0.5 * (k + 1) / 12.0))
		await frames(1)
	await frames(3)
	var cost: float = game.line_plan["cost"]
	var upto: int = game.line_plan["upto"]
	var cells: PackedInt32Array = (game.line_plan["cells"] as PackedInt32Array).slice(0, upto)
	btn(scr(B), MOUSE_BUTTON_LEFT, false)
	await frames(3)
	check(absf((m0 - c.money) - cost) < 0.001 and cost > 0.0, "при отпускании списано ровно показанное: %.2f / %.2f" % [m0 - c.money, cost])
	var paved := 0
	for k in cells:
		if land.kind[k] == Land.Kind.ROAD:
			paved += 1
	check(paved == cells.size(), "легло ровно показанное: %d из %d" % [paved, cells.size()])
	check(game._prev_mode == 0 and not game.painting, "показ погас, мазок окончен")
	# денег мало: дальше — красным, «денег хватит до сюда»
	c.money = 4.0
	var A2 := Vector2(186, 182)
	var B2 := Vector2(206, 182)
	var kind1: PackedByteArray = land.kind.duplicate()
	await drag(scr(A2), scr(B2), 20, false)
	var pl: Dictionary = game.line_plan
	var gpx := 0
	for n in (pl["cells"] as PackedInt32Array).size():
		if n >= int(pl["upto"]) and int(pl["fresh"][n]) == 1 and prev_px(int(pl["cells"][n])).g > 0.2:
			gpx += 1
	var warn: String = hud._stroke_warn.text if hud._stroke_warn and hud._stroke_warn.visible else ""
	check(int(pl["upto"]) < (pl["cells"] as PackedInt32Array).size() and gpx > 20 and warn.contains("Денег хватит до сюда"),
		"денег 4: ляжет %d из %d, красных %d, «%s»" % [int(pl["upto"]), (pl["cells"] as PackedInt32Array).size(), gpx, warn])
	await shot("s3_line_money.png")
	var cost2: float = pl["cost"]
	btn(scr(B2), MOUSE_BUTTON_LEFT, false)
	await frames(3)
	check(absf((4.0 - c.money) - cost2) < 0.001 and c.money >= -0.001, "списано %.2f из 4 (показано %.2f)" % [4.0 - c.money, cost2])
	var far := land.idx(land.cell(B2).x, land.cell(B2).y)
	check(land.kind[far] == kind1[far], "за красным — не легло")
	# Esc посреди — ничего
	c.money = 50000.0
	var kind2: PackedByteArray = land.kind.duplicate()
	var m2: float = c.money
	await drag(scr(Vector2(186, 188)), scr(Vector2(204, 188)), 12, false)
	await key(KEY_ESCAPE)
	btn(scr(Vector2(204, 188)), MOUSE_BUTTON_LEFT, false)
	await frames(3)
	check(land.kind == kind2 and is_equal_approx(c.money, m2) and game._prev_mode == 0 and game.tool == "road", "Esc посреди прямой: ничего не легло, показ погас")
	hud._road_opt("linefree")
	game.set_tool("")


# ---------- 3.2: ластик красным, убирает при отпускании ----------

func _eraser() -> void:
	print("== 3.2 ластик")
	game.set_tool("erase")
	game.brush_r = 2.0
	await frames(2)
	check(not game.brush_line, "ластик — свободной кистью")
	var p := Vector2(196, 176)
	move(scr(p))
	await frames(4)
	check(game._prev_mode == 2, "ластик над дорогой: красная подсветка")
	var road_k := land.idx(land.cell(p).x, land.cell(p).y)
	var grass_k := land.idx(land.cell(p + Vector2(0, 1.8)).x, land.cell(p + Vector2(0, 1.8)).y)
	check(Land.walk_kind(land.kind[road_k]) and prev_px(road_k).r > 0.2, "дорога под ластиком — красная")
	check(not Land.walk_kind(land.kind[grass_k]) and prev_px(grass_k).r < 0.01, "трава под ластиком — без подсветки")
	await shot("s3_erase_hover.png")
	# тянем — земля не меняется; Esc — ничего не убрано
	var kind0: PackedByteArray = land.kind.duplicate()
	await drag(scr(Vector2(192, 173)), scr(Vector2(200, 179)), 14, false)
	check(land.kind == kind0 and game.erase_cells.size() > 30, "тянем: убрать %d клеток, земля пока та же" % game.erase_cells.size())
	var lbl: String = hud._stroke_lbl.text if hud._stroke_lbl else ""
	check(lbl.begins_with("Убрать ") and lbl.contains("дороги · бесплатно"), "у курсора «%s»" % lbl)
	await shot("s3_erase_drag.png")
	await key(KEY_ESCAPE)
	btn(scr(Vector2(200, 179)), MOUSE_BUTTON_LEFT, false)
	await frames(3)
	check(land.kind == kind0 and game.tool == "erase" and game.erase_cells.is_empty() and not game.painting, "Esc посреди ластика: убрано 0 клеток")
	# отпустили — убрано разом, одна отмена
	var u0: int = game.undo_stack.size()
	await drag(scr(Vector2(192, 173)), scr(Vector2(200, 179)), 14, true)
	var gone := 0
	for k in land.kind.size():
		if kind0[k] != land.kind[k]:
			gone += 1
	check(gone > 30 and game.undo_stack.size() == u0 + 1, "отпустили: убрано %d клеток, одна запись в отмене" % gone)
	game._undo()
	await frames(2)
	check(land.kind == kind0, "Ctrl+Z вернул дорогу")
	game.set_tool("")


# ---------- 3.3: мазок без рывков ----------

func _stroke_cost() -> void:
	print("== 3.3 цена мазка")
	game.set_tool("road")
	game.brush_r = 2.0
	game.rig.set_view(Vector3(196, 2, 192), 0, 62, 34)
	await frames(12)
	var h0: PackedFloat32Array = land.h.duplicate()
	land.dirty.clear()
	var idle := []
	for k in 30:
		await frames(1)
		idle.append(frame_ms())
	var a := scr(Vector2(184, 192))
	var b := scr(Vector2(208, 194))
	move(a)
	await frames(3)
	btn(a, MOUSE_BUTTON_LEFT, true)
	var st := []
	for k in 40:
		move(a.lerp(b, (k + 1) / 40.0))
		await frames(1)
		st.append(frame_ms())
	check(game.painting and land.h == h0, "посреди мазка высоты не сглаживаются (это — при отпускании)")
	check(land.dirty.is_empty() and not land.dirty_soft.is_empty(), "посреди мазка сетка кусков не перестраивается (только маска): мешей %d, отложено %d" % [land.dirty.size(), land.dirty_soft.size()])
	btn(b, MOUSE_BUTTON_LEFT, false)
	await frames(1)
	check(land.h != h0, "отпустили — высоты дороги сглажены")
	await frames(30)
	check(land.dirty_soft.is_empty() and land.dirty.is_empty(), "после мазка куски перестроены")
	idle.sort()
	st.sort()
	var im: float = idle[idle.size() / 2]
	var sm: float = st[st.size() / 2]
	print("S3 STROKE idle=%.1f мс мазок=%.1f мс (медиана, кадр скриптов)" % [im, sm])
	check(sm <= im + 12.0, "кадр мазка ≤ покой + 12 мс (%.1f / %.1f)" % [sm, im])
	# пересчёт города — в следующем кадре
	game.painting = true
	game.stroke = []
	game.stroke_cost = 0.0
	for k in 10:
		game._paint_at(Vector2(184, 198) + Vector2(k * 0.5, 0))
	game._release()
	check(game._compute_due, "отпустили: пересчёт города отложен на кадр")
	await frames(2)
	check(not game._compute_due, "…и сделан")
	game.set_tool("")


## Клетки прямой квадратной кистью перебором всей рамки линии (как до сужения рядов): {клетка: 1 — платная, 0 — нет}
func _line_ref(a: Vector2, b: Vector2, r: float, kd: int) -> Dictionary:
	var ab := b - a
	var out := {}
	var c0 := land.cell(a.min(b) - Vector2(r, r))
	var c1 := land.cell(a.max(b) + Vector2(r, r))
	var flat := kd != Land.Kind.GRASS
	for j in range(c0.y, c1.y + 1):
		for i in range(c0.x, c1.x + 1):
			if not land.inside(i, j):
				continue
			var q := Vector2((i + 0.5) * Land.CELL, (j + 0.5) * Land.CELL)
			var tl := 0.0
			var th := 1.0
			var ok := true
			for ax in 2:
				var qa: float = q[ax]
				var aa: float = a[ax]
				var da: float = ab[ax]
				if absf(da) < 1e-6:
					if absf(qa - aa) > r:
						ok = false
				else:
					tl = maxf(tl, minf((qa - r - aa) / da, (qa + r - aa) / da))
					th = minf(th, maxf((qa - r - aa) / da, (qa + r - aa) / da))
			if not ok or tl > th or not land.is_owned(q):
				continue
			var k := j * Land.N + i
			var kk: int = land.kind[k]
			var y: float = land.hq(k)
			if y < Land.WATER_Y + 0.05 or land.occ[k] != 0:
				continue
			if not flat and not Land.walk_kind(kk):
				continue
			if flat:
				var pt := a + ab * ((tl + th) * 0.5)
				var y0 := land.height_at(pt.x, pt.y)
				if absf(y - y0) > 1.2 or (kk == kd and absf(y - y0) < 0.01):
					continue
			out[k] = 1 if kk != kd else 0
	return out


func _line_set(lc: Dictionary) -> Dictionary:
	var out := {}
	for n in (lc["cells"] as PackedInt32Array).size():
		out[int(lc["cells"][n])] = int(lc["fresh"][n])
	return out


# ---------- 3.3: прямая квадратной кистью — только полоса линии, а не вся её рамка ----------

func _square_line() -> void:
	print("== 3.3 прямая квадратной кистью")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2410
	var bad := []
	for n in 40:
		var a := Vector2(rng.randf_range(160, 225), rng.randf_range(115, 195))
		var b := a + Vector2.from_angle(rng.randf() * TAU) * (rng.randf_range(0, 45) if n % 5 else 0.0)
		if n % 7 == 3:
			b = Vector2(b.x, a.y)                   # и ровно вдоль осей
		elif n % 7 == 5:
			b = Vector2(a.x, b.y)
		var r: float = [0.5, 1.0, 2.0, 3.0][n % 4]
		var kd: int = Land.Kind.GRASS if n % 3 == 0 else Land.Kind.ROAD
		if _line_set(land.line_cells(a, b, r, kd, true, true)) != _line_ref(a, b, r, kd):
			bad.append([a, b, r, kd])
	check(bad.is_empty(), "квадратная кисть: клетки и цена те же, что перебором всей рамки (40 линий)", bad)
	# диагональ 80 м: раньше — ~51 тыс. клеток рамки на каждые 0,25 м мыши; теперь — как круглой кистью (полоса
	# квадрата по диагонали шире круга в √2 раз). Время — лучшее из трёх (вторая линия может грузить машину)
	var a := Vector2(150, 112)
	var b := a + Vector2(56.5, 56.5)
	var ms := INF
	var round_ms := INF
	var ref_ms := INF
	var lc: Dictionary = {}
	var ref := {}
	for k in 3:
		var t0 := Time.get_ticks_usec()
		lc = land.line_cells(a, b, 2.0, Land.Kind.ROAD, true, true)
		ms = minf(ms, (Time.get_ticks_usec() - t0) / 1000.0)
		t0 = Time.get_ticks_usec()
		land.line_cells(a, b, 2.0, Land.Kind.ROAD, false, true)
		round_ms = minf(round_ms, (Time.get_ticks_usec() - t0) / 1000.0)
		t0 = Time.get_ticks_usec()
		ref = _line_ref(a, b, 2.0, Land.Kind.ROAD)
		ref_ms = minf(ref_ms, (Time.get_ticks_usec() - t0) / 1000.0)
	print("S3 SQUARE диагональ 80 м: квадрат %.1f мс, круг %.1f мс, перебор рамки %.1f мс, клеток %d" % [ms, round_ms, ref_ms, (lc["cells"] as PackedInt32Array).size()])
	check(_line_set(lc) == ref, "диагональ 80 м квадратной кистью — те же клетки, что перебором рамки")
	check(ms < ref_ms and ms <= round_ms * 1.8 + 2.0, "…и почти как круглой: %.1f мс (круг %.1f, перебор рамки %.1f)" % [ms, round_ms, ref_ms])


# ---------- 3.4: живая картинка и цвета ----------

func _thumb_color() -> void:
	print("== 3.4 картинка и цвет")
	game.rig.set_view(Vector3(196, 2, 158), 0, 58, 34)
	await frames(12)
	reset()
	game.set_tool("house_pleb")
	var p := Vector2(196, 152.3)
	move(scr(p))
	await frames(8)
	check(hud.thumb_rect.visible and hud.thumb_rect.texture is ViewportTexture, "живая картинка в панели")
	check(hud.color_box.visible and hud.color_box.get_child_count() == 12, "ряд цветов: «Авто» и 10 цветов")
	var gx: Transform3D = game.ghost.transform
	var vb: Button = null
	for b in hud.variant_box.get_children():
		if b is Button and b.has_meta("vi") and int(b.get_meta("vi")) == 2:
			vb = b
	move(center_of(vb))
	await frames(4)
	vb.pressed.emit()
	check(String(hud._thumb_key).contains(":2:"), "щелчок по фасаду 3 — картинка тем же щелчком (%s)" % hud._thumb_key)
	await frames(3)
	check(game.ghost.visible and game.ghost.transform.origin.distance_to(gx.origin) < 0.01 and String(game.ghost_key).contains(":2:"), "призрак на том же месте, фасад 3")
	var sw: Button = null
	for b in hud.color_box.get_children():
		if b is Button and int(b.get_meta("ci", -9)) == 4:
			sw = b
	sw.pressed.emit()
	await frames(2)
	check(game.color_user == 4 and String(hud._thumb_key).ends_with(":4"), "цвет 5 «%s» — в панели и на картинке" % Defs.PALETTE[4]["name"])
	await shot("s3_thumb_color.png")
	move(scr(p))
	await frames(5)
	check(int(game.place_info["color"]) == 4, "призрак этого цвета")
	await key(KEY_C, false, true)
	check(game.color_user == 5, "Shift+C — следующий цвет (%d)" % game.color_user)
	await key(KEY_C, false, true)
	game.set_color(4)
	await frames(3)
	var n0: int = c.buildings.size()
	await click(scr(p))
	var nb: Dictionary = {}
	for id in c.buildings:
		if int(id) >= c.next_id - 1 and c.buildings[id]["type"] == "house_pleb":
			nb = c.buildings[id]
	check(c.buildings.size() == n0 + 1 and not nb.is_empty() and int(nb["color"]) == 4 and int(nb["variant"]) == 2, "дом встал с фасадом 3 и цветом 5",
		"построек +%d, дом %s, место «%s»" % [c.buildings.size() - n0, [nb.get("variant", -1), nb.get("color", -1)], game.place_info.get("err", "")])
	check(game.color_user == 4, "цвет держится для следующих")
	for b in hud.color_box.get_children():
		if b is Button and int(b.get_meta("ci", -9)) == -1:
			b.pressed.emit()
	check(game.color_user == -1, "«Авто» — снова цвет не как у соседей")
	game.set_tool("")


# ---------- 3.5: ошибка у курсора, стрелка у входа, вспышка, «Z/X» ----------

func _cursor_feedback() -> void:
	print("== 3.5 у курсора")
	game.rig.set_view(Vector3(196, 2, 168), 0, 58, 34)
	await frames(12)
	reset()
	game.set_tool("house_pleb")
	var far := Vector2(198, 168)                 # трава, до дорог далеко
	move(scr(far))
	await frames(4)
	check(game.place_info.get("err", "") != "" and hud._err == hud.tool_err.text.substr(0, hud.tool_err.text.find(" (") if hud.tool_err.text.find(" (") > 0 else 999),
		"ошибка у курсора тем же кадром: «%s» / «%s»" % [hud._err, hud.tool_err.text])
	await shot("s3_cursor_err.png")
	# стрелка у входа: мостовая в 1,5 м — зелёная, в 2,0 м — красная
	var pl: Dictionary = game.placement("house_pleb", far)
	var bp := Catalog.make("house_pleb", int(pl["tier"]), int(pl["variant"]), int(pl["color"]))
	var yaw := float(pl["yaw"])
	var dp: Vector2 = (pl["pos"] as Vector2) + City.axis(yaw) * bp.door.x + City.facing(yaw) * bp.door.z
	var f := City.facing(yaw)
	var res := []
	for dist: float in [1.5, 2.0]:
		var k := land.idx(land.cell(dp + f * dist).x, land.cell(dp + f * dist).y)
		var old := land.kind[k]
		land.kind[k] = Land.Kind.ROAD
		game._door_arrow(pl)
		res.append([game.door_ok, (game.door_arrow.material_override as StandardMaterial3D).albedo_color])
		land.kind[k] = old
	check(bool(res[0][0]) and (res[0][1] as Color).g > 0.8 and not bool(res[1][0]) and (res[1][1] as Color).r > 0.8, "стрелка у входа: 1,5 м — зелёная, 2,0 м — красная %s" % [res])
	# вспышка обводки, когда призрак прилип к дороге
	game.rig.set_view(Vector3(200, 2, 156), 0, 52, 18)
	await frames(20)
	var s0: int = game.snap_pulses
	move(scr(Vector2(200, 158)))
	await frames(4)
	move(scr(Vector2(200, 152.3)))
	await frames(4)
	check(game.snap_pulses > s0 and game.place_info.get("sub", "") == "road", "прилип к дороге — одна мягкая вспышка (%d)" % (game.snap_pulses - s0))
	check(game.door_arrow.visible and game.door_ok, "у дороги стрелка входа зелёная")
	game.rig.set_view(Vector3(200, 2, 152), 180, 50, 16)       # с улицы — видно вход
	await frames(25)
	move(scr(Vector2(200, 152.3)))
	await frames(6)
	await shot("s3_door_arrow.png")
	# значок поворота — первые 3 постановки за установку
	check(hud._hint, "значок «Z / X» у курсора (постановок 0)")
	game.rig.set_view(Vector3(178, 2, 156), 0, 55, 30)
	await frames(20)
	for k in 3:
		reset()
		var q := Vector2(170 + k * 7.0, 152.3)
		move(scr(q))
		await frames(4)
		if game.place_info.get("err", "x") == "":
			game._build_here()
		else:
			game._rot_hint_count()
		await frames(2)
	move(scr(Vector2(200, 158)))
	await frames(4)
	check(not hud._hint and int(game.settings.get("rot_hint", 0)) == 3, "после 3 постановок значка нет")
	var fs = JSON.parse_string(FileAccess.get_file_as_string(game.settings_path()))
	check(typeof(fs) == TYPE_DICTIONARY and int(fs.get("rot_hint", 0)) == 3, "и после перезапуска (в файле настроек rot_hint 3)")
	game.set_tool("")


# ---------- 3.6: отмена постройки 30 с ----------

func _undo_place() -> void:
	print("== 3.6 отмена постройки")
	game.rig.set_view(Vector3(232, 2, 144), 0, 58, 30)
	await frames(15)
	game.undo_stack.clear()                      # дома прошлых проверок (им меньше 30 с) — не в счёт
	reset()
	game.set_tool("house_pleb")
	var p := Vector2(230, 147.7)
	move(scr(p))
	await frames(5)
	var m0: float = c.money
	var n0: int = c.buildings.size()
	await click(scr(p))
	check(c.buildings.size() == n0 + 1, "дом поставили")
	hud.refresh_undo()
	var u: Dictionary = game.undo_place_info()
	check(not u.is_empty() and not hud.undo_btn.disabled and hud.undo_btn.tooltip_text == "Отменить: Дом плебеев, вернётся %s ден." % hud.fmt(float(Defs.B["house_pleb"]["cost"])),
		"медаль «Отменить»: «%s»" % hud.undo_btn.tooltip_text)
	await shot("s3_undo_medal.png")
	await key(KEY_Z, true)
	check(c.buildings.size() == n0 and is_equal_approx(c.money, m0), "Ctrl+Z: дома нет, вернулось 100%% (%.1f / %.1f)" % [c.money, m0])
	hud.refresh_undo()
	check(hud.undo_btn.disabled, "отменять нечего — медаль серая")
	# с семьёй — нельзя
	move(scr(p))
	await frames(4)
	await click(scr(p))
	var h: Dictionary = c.buildings.get(c.next_id - 1, {})
	if not check(not h.is_empty() and h["type"] == "house_pleb", "дом поставили снова"):
		game.set_tool("")
		return
	h["pop"] = 2
	h["families"] = [{"name": "Проба", "n": 2}]
	game._undo("place")
	check(c.buildings.has(int(h["id"])), "в доме живут — отмена не сносит")
	h["pop"] = 0
	h["families"] = []
	# через 30 с — нельзя
	move(scr(p + Vector2(7, 0)))
	await frames(4)
	await click(scr(p + Vector2(7, 0)))
	var h2: Dictionary = c.buildings.get(c.next_id - 1, {})
	if not check(not h2.is_empty() and h2["type"] == "house_pleb", "и третий"):
		game.set_tool("")
		return
	(game.undo_stack.back() as Dictionary)["ms"] = Time.get_ticks_msec() - 31000
	game._undo("place")
	check(c.buildings.has(int(h2["id"])), "через 30 с отмена не сносит")
	# постройка выполнила просьбу — награда уже выдана: полного возврата нет (снимок — до постановки)
	game.undo_stack.clear()
	c.goals_done.erase("fruit")
	var st := build_at("stall_fruit", Vector2(200, 158))
	check(not st.is_empty() and c.goals_done.has("fruit"), "фруктовая лавка выполнила просьбу «%s»" % Defs.REQUESTS.filter(func(g): return g["id"] == "fruit")[0]["text"])
	check(game.undo_place_info().is_empty(), "просьба выполнена — медаль «Отменить» пуста")
	var mf: float = c.money
	await key(KEY_Z, true)
	check(not st.is_empty() and c.buildings.has(int(st["id"])) and is_equal_approx(c.money, mf), "Ctrl+Z: лавка стоит, денег не вернулось")
	c.money = 50000.0
	# новый ранг за эти 30 с и выполненный заказ старосты — тоже
	var hr := build_at("house_pleb", Vector2(176, 158))
	check(not hr.is_empty() and not game.undo_place_info().is_empty(), "дом — отменить можно")
	c.level += 1
	check(game.undo_place_info().is_empty(), "город получил новый ранг — отмены с полным возвратом нет")
	c.level -= 1
	var ho := build_at("house_pleb", Vector2(184, 158))
	c.stories["orders"] = {"n": {"lights": 1}}
	check(not ho.is_empty() and game.undo_place_info().is_empty(), "выполнен заказ старосты — отмены с полным возвратом нет")
	c.stories.erase("orders")
	# казна у предела: доход дополнил её, пока дом стоял — отмена не поднимает казну выше предела
	c.money = c.money_cap() - 5.0
	var hm := build_at("house_pleb", Vector2(192, 158))
	c.money = c.money_cap()
	await key(KEY_Z, true)
	check(not hm.is_empty() and not c.buildings.has(int(hm["id"])) and is_equal_approx(c.money, c.money_cap()), "отмена у полной казны: дом убран, казна %.0f из %.0f" % [c.money, c.money_cap()])
	c.money = 50000.0
	# памятник Легиона: вместе с денариями возвращается и Слава
	c.research["arch"] = true
	c.legion.glory = 100.0
	game.undo_stack.clear()
	var ma: float = c.money
	var arch := build_at("arch", Vector2(196, 166))
	check(not arch.is_empty() and is_equal_approx(c.legion.glory, 75.0), "арка поставлена: Славы %.0f из 100" % c.legion.glory)
	hud.refresh_undo()
	check(hud.undo_btn.tooltip_text == "Отменить: Триумфальная арка, вернётся %s ден. и 25 Славы" % hud.fmt(float(Defs.B["arch"]["cost"])), "медаль: «%s»" % hud.undo_btn.tooltip_text)
	await key(KEY_Z, true)
	check(not arch.is_empty() and not c.buildings.has(int(arch["id"])) and is_equal_approx(c.money, ma) and is_equal_approx(c.legion.glory, 100.0),
		"Ctrl+Z: арки нет, вернулись %.0f ден. и Слава (%.0f)" % [c.money - (ma - float(Defs.B["arch"]["cost"])), c.legion.glory])
	game.set_tool("road")
	await frames(2)
	game.undo_stack.clear()
	game.redo_stack.clear()
	hud.refresh_undo()
	check((hud.road_btns["undo"] as Button).disabled and (hud.road_btns["redo"] as Button).disabled, "у дорог «Отменить» и «Вернуть» серые, когда отменять нечего")
	game.set_tool("")


# ---------- 3.7: деревья сквозь призрак ----------

func _trees() -> void:
	print("== 3.7 деревья сквозь призрак")
	var tree := {}
	for key in game.nature:
		for it in game.nature[key]:
			var tp: Vector2 = it["p"]
			if String(it["name"]).contains("Tree") and land.is_owned(tp) and tp.distance_to(Vector2(200, 140)) < 60 and land.occ_at(tp) == 0 \
					and not land.is_road(tp) and land.height_at(tp.x, tp.y) > Land.WATER_Y + 0.3:
				var gp: Dictionary = game.placement("bush", tp)
				if gp["err"] == "":
					tree = it
					break
		if not tree.is_empty():
			break
	if not check(not tree.is_empty(), "дерево для проверки"):
		return
	var tp: Vector2 = tree["p"]
	game.rig.set_view(Vector3(tp.x, 2, tp.y), 20, 55, 22)
	await frames(15)
	game.set_tool("bush")
	move(scr(tp))
	await frames(3)
	var mm := (tree["h"][0][0]["subs"][0]["mm"] as MultiMesh)
	var slot: int = tree["h"][0][1]
	await wait(0.4)
	await frames(2)
	check(game.tree_hidden.has(tree) and mm.get_instance_transform(slot).basis.determinant() < 1e-6, "призрак на дереве 0,3 с — дерево спряталось")
	await shot("s3_tree_ghost.png")
	var sd: Dictionary = game._save_data()
	check(game.nature_at(tp) == tree and not JSON.stringify(sd).contains("tree_hidden"), "сохранение тем временем — дерево в городе")
	move(scr(tp + Vector2(6, 6)))
	await frames(4)
	check(game.tree_hidden.is_empty() and mm.get_instance_transform(slot).basis.determinant() > 1e-6, "призрак ушёл — дерево на месте")
	move(scr(tp))
	await wait(0.4)
	game.set_tool("")
	await frames(2)
	check(mm.get_instance_transform(slot).basis.determinant() > 1e-6, "инструмент убрали — дерево на месте")


# ---------- 3.8: подпись при наведении, колёсико к курсору, двойной щелчок ----------

func _hover_camera() -> void:
	print("== 3.8 наведение и камера")
	var h := put("house_pleb", Vector2(190, 145))
	c.settled(int(h["id"]), 2, "Ливии")
	game.rig.set_view(Vector3(196, 2, 150), 0, 58, 34)
	await frames(15)
	game.set_tool("")
	move(scr3(Vector3(h["pos"].x, float(h["y"]) + 1.0, h["pos"].y)))
	await frames(3)
	check(hud._note == "", "сразу — без подписи")
	await wait(0.5)
	await frames(2)
	check(hud._note.begins_with("Дом плебеев · Ливии") and hud._note.contains("этаж 1/"), "через 0,4 с: «%s»" % hud._note)
	await shot("s3_hover.png")
	game.set_tool("house_pleb")
	await wait(0.5)
	check(not hud._note.begins_with("Дом плебеев"), "с инструментом — подписи нет")
	game.set_tool("")
	# колёсико: точка под курсором остаётся под курсором
	var sp := Vector2(get_viewport().get_visible_rect().size) * Vector2(0.28, 0.66)
	move(sp)
	await frames(3)
	var g0: Vector2 = game.ground_at_mouse()
	for k in 3:
		btn(sp, MOUSE_BUTTON_WHEEL_UP, true)
		btn(sp, MOUSE_BUTTON_WHEEL_UP, false)
		await frames(2)
	await frames(90)
	var g1: Vector2 = game.ground_at_mouse()
	check(g0.is_finite() and g1.is_finite() and g0.distance_to(g1) <= 0.5, "колёсико: точка под курсором сдвинулась на %.2f м" % g0.distance_to(g1))
	# двойной щелчок — к постройке
	var hs := scr3(Vector3(h["pos"].x, float(h["y"]) + 1.0, h["pos"].y))
	move(hs)
	await frames(2)
	btn(hs, MOUSE_BUTTON_LEFT, true, true)
	await frames(1)
	btn(hs, MOUSE_BUTTON_LEFT, false)
	await frames(2)
	var tt: Vector3 = game.rig._target_t
	check(Vector2(tt.x, tt.z).distance_to(h["pos"]) < 0.5, "двойной щелчок — камера летит к дому")
	hud.close_panels()
	game.select_building({})


# ---------- 3.9: склад и лавки ----------

func _warehouse() -> void:
	print("== 3.9 склад")
	var w := put("warehouse", Vector2(226, 160))
	var near := put("butcher", Vector2(226, 176))
	var far_b := put("butcher", Vector2(163, 118))
	c.compute()
	if not check(not w.is_empty() and not near.is_empty() and not far_b.is_empty(), "склад и две мясные лавки"):
		return
	hud.open_info(near)
	await frames(3)
	check(texts(hud.info_box).contains("Склад рядом не работает"), "склад без работников: «Склад рядом не работает: …»")
	w["active"] = true                           # работники на складе (жителей в проверке нет)
	hud.open_info(near)
	await frames(3)
	check(texts(hud.info_box).contains("Товар со склада"), "лавка у склада: «Товар со склада · N м»")
	await shot("s3_shop_store.png")
	hud.open_info(far_b)
	await frames(3)
	check(texts(hud.info_box).contains("Нет склада рядом — товар не идёт"), "далёкая лавка: «Нет склада рядом — товар не идёт»")
	var sb := hud.info_box.find_child("show_store", true, false) as Button
	check(sb != null, "кнопка «Показать склад»")
	if sb:
		sb.pressed.emit()
		await frames(3)
		check(int(game.selected.get("id", -1)) == int(w["id"]), "«Показать склад» — выбран склад")
	var s := Cover.selected_sets(c, w)
	var mine := 0
	var r := float(Defs.RANGE[4]) * (2.0 if c.research.has("store1") else 1.0)
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		if c.def(b)["kind"] == "shop" and c.def(b).get("store", false) and (b["pos"] as Vector2).distance_to(w["pos"]) <= r:
			mine += 1
	check(int(s["own"]) == mine and (s["green"] as Array).has(int(near["id"])) and not (s["green"] as Array).has(int(far_b["id"])), "склад подсвечивает ровно свои лавки: %d из %d" % [int(s["own"]), mine])
	hud.close_panels()
	game.select_building({})


# ---------- заборы мышью, как дорогу ----------

func _fences() -> void:
	print("== заборы")
	game.rig.set_view(Vector3(206, 2, 130), 0, 60, 32)
	await frames(15)
	hud.close_panels()
	game.set_tool("fence")
	game.fence_gate = false
	await frames(2)
	var A := Vector2(200, 122)
	var n0: int = c.next_id
	var m0: float = c.money
	await drag(scr(A), scr(A + Vector2(6.2, 0)), 15, false)
	var lbl: String = hud._stroke_lbl.text if hud._stroke_lbl else ""
	check(game.fence_drag and game.fence_plan.size() == 3 and lbl.contains("3 звена") and lbl.ends_with("ден."), "тянем плетень: 3 звена, у курсора «%s»" % lbl)
	await shot("s3_fence_drag.png")
	btn(scr(A + Vector2(6.2, 0)), MOUSE_BUTTON_LEFT, false)
	await frames(3)
	var run1 := []
	for id in c.buildings:
		if c.buildings[id]["type"] == "fence" and int(id) >= n0:
			run1.append(c.buildings[id])
	check(run1.size() == 3 and is_equal_approx(m0 - c.money, 3.0 * float(Defs.B["fence"]["cost"])), "встало 3 звена за %.0f ден." % (m0 - c.money))
	var ok_gap := run1.size() == 3
	for i in range(1, run1.size()):
		ok_gap = ok_gap and absf((run1[i]["pos"] as Vector2).distance_to(run1[i - 1]["pos"]) - Defs.FENCE_PITCH) < 0.01
	check(ok_gap, "звенья через %.2f м по линии" % Defs.FENCE_PITCH)
	# угол: от конца протянутого — без щели
	var end: Vector2 = (run1[-1]["pos"] as Vector2) + City.axis(float(run1[-1]["yaw"])) * Defs.FENCE_PITCH * 0.5
	var n1: int = c.next_id
	await drag(scr(end + Vector2(0.25, 0.2)), scr(end + Vector2(0, 4.2)), 12, true)
	var run2 := []
	for id in c.buildings:
		if c.buildings[id]["type"] == "fence" and int(id) >= n1:
			run2.append(c.buildings[id])
	var start2: Vector2 = (run2[0]["pos"] as Vector2) - City.axis(float(run2[0]["yaw"])) * Defs.FENCE_PITCH * 0.5 if not run2.is_empty() else Vector2.INF
	check(run2.size() == 2 and start2.distance_to(end) < 0.01, "угол: второй ряд от конца первого (щель %.3f м)" % start2.distance_to(end))
	# калитка посередине
	game.fence_gate = true
	game.set_tool("fence_wood")
	game.fence_gate = true
	await frames(2)
	var n2: int = c.next_id
	await drag(scr(Vector2(200, 132)), scr(Vector2(210.2, 132)), 15, true)
	var run3 := []
	for id in c.buildings:
		if int(id) >= n2:
			run3.append(c.buildings[id])
	check(run3.size() == 5 and int(run3[2]["variant"]) == 1 and int(run3[0]["variant"]) == 0, "ограда 5 звеньев, калитка посередине")
	await shot("s3_fence_gate.png")
	var sd: Dictionary = c.save_data()
	var gate_saved := false
	for bd in sd["buildings"]:
		if bd["type"] == "fence_wood" and int(bd["variant"]) == 1:
			gate_saved = true
	check(gate_saved, "калитка — в сохранении (variant 1)")
	# Ctrl+Z — весь забор с полным возвратом
	var m3: float = c.money
	await key(KEY_Z, true)
	var left := 0
	for b in run3:
		if c.buildings.has(int(b["id"])):
			left += 1
	check(left == 0 and is_equal_approx(c.money, m3 + 5.0 * float(Defs.B["fence_wood"]["cost"])), "Ctrl+Z: ограды нет, вернулось 100%")
	# Esc посреди — ничего
	game.set_tool("hedge")
	await frames(2)
	var n4: int = c.buildings.size()
	await drag(scr(Vector2(200, 136)), scr(Vector2(208, 136)), 10, false)
	await key(KEY_ESCAPE)
	btn(scr(Vector2(208, 136)), MOUSE_BUTTON_LEFT, false)
	await frames(3)
	check(c.buildings.size() == n4, "Esc посреди изгороди — ничего не встало")
	# изгородь и каменная стенка — для снимка
	await drag(scr(Vector2(200, 136)), scr(Vector2(208, 136)), 10, true)
	game.set_tool("stonewall")
	await frames(2)
	game.rig.set_view(Vector3(205, 2, 138), 0, 60, 30)
	await frames(15)
	await drag(scr(Vector2(200, 140)), scr(Vector2(208, 140)), 10, true)
	await drag(scr(Vector2(207.8, 140)), scr(Vector2(207.8, 144.2)), 10, true)
	var sw := 0
	for id in c.buildings:
		if c.buildings[id]["type"] == "stonewall":
			sw += 1
	check(sw == 6, "каменная стенка: 4 звена и угол из 2 (встало %d)" % sw, game.fence_plan.map(func(x): return x["err"]))
	game.set_tool("")
	# перенос калитки — остаётся калиткой
	var gate := {}
	for id in c.buildings:
		if c.buildings[id]["type"] == "stonewall" and int(c.buildings[id]["variant"]) == 1:
			gate = c.buildings[id]
	if check(not gate.is_empty(), "в каменной стенке есть калитка"):
		game.start_move(gate)
		game.place_lock = {"p": (gate["pos"] as Vector2) + Vector2(0, 3.0)}
		game.tool_yaw = float(gate["yaw"])
		game._build_here()
		var moved: Dictionary = c.buildings.get(c.next_id - 1, {})
		check(String(moved.get("type", "")) == "stonewall" and int(moved.get("variant", -1)) == 1 and game.moving.is_empty(), "перенесли калитку — осталась калиткой")
		game.place_lock = {}
		game.set_tool("")
	game.rig.set_view(Vector3(205, 2, 134), 15, 48, 21)
	await frames(100)
	await shot("s3_fences.png")
	game.rig.set_view(Vector3(206, 2, 130), 0, 60, 32)
	await frames(20)
	# ластик — по звену
	game.set_tool("erase")
	game.brush_r = 0.5
	var mid: Dictionary = run1[1]
	move(scr(mid["pos"]))
	await frames(4)
	check(game.erase_fences.size() == 1 and game.erase_fences.has(int(mid["id"])), "ластик над звеном — подсвечено одно (%d)" % game.erase_fences.size())
	var m5: float = c.money
	await click(scr(mid["pos"]))
	check(not c.buildings.has(int(mid["id"])) and c.buildings.has(int(run1[0]["id"])) and c.buildings.has(int(run1[2]["id"])), "ластик убрал одно звено, соседние стоят")
	check(is_equal_approx(c.money, m5 + float(Defs.B["fence"]["cost"]) * Defs.REFUND), "вернулась половина цены звена")
	game._undo()
	await frames(2)
	var back := false
	for id in c.buildings:
		if c.buildings[id]["type"] == "fence" and (c.buildings[id]["pos"] as Vector2).distance_to(mid["pos"]) < 0.01:
			back = true
	check(back, "Ctrl+Z — звено снова на месте")
	game.brush_r = 2.0
	# до нажатия видно ровно то звено, которое поставит щелчок (от курсора, а не серединой на нём)
	game.set_tool("fence")
	game.fence_gate = false
	reset()
	var P := Vector2(212.3, 125.4)
	move(scr(P))
	await frames(4)
	var shown: Vector2 = game.fence_plan[0]["pos"] if game.fence_plan.size() == 1 else Vector2.INF
	var n6: int = c.next_id
	await click(scr(P))
	var one: Dictionary = c.buildings.get(n6, {})
	check(not one.is_empty() and (one["pos"] as Vector2).distance_to(shown) < 0.05, "щелчок — звено там же, где было показано (сдвиг %.2f м)" % ((one.get("pos", Vector2.INF) as Vector2).distance_to(shown)))
	if not one.is_empty():
		# у конца звена: показ — от его конца, без ложного «Место занято»
		var e1: Vector2 = (one["pos"] as Vector2) + City.axis(float(one["yaw"])) * Defs.FENCE_PITCH * 0.5
		move(scr(e1 + Vector2(0.12, 0.15)))
		await frames(4)
		var s0: Dictionary = game.fence_plan[0] if game.fence_plan.size() == 1 else {}
		check(not s0.is_empty() and s0["err"] == "" and hud._err == "" and ((s0["pos"] as Vector2) - City.axis(float(s0["yaw"])) * Defs.FENCE_PITCH * 0.5).distance_to(e1) < 0.01,
			"у конца звена — звено от его конца, у курсора без ошибки («%s», «%s»)" % [s0.get("err", "?"), hud._err])
		# над серединой звена — «Место занято»; нажали и тянем — у курсора прежней красной строки нет (что не так — под ценой)
		move(scr(one["pos"]))
		await frames(4)
		var was: String = hud._err
		await drag(scr(one["pos"]), scr((one["pos"] as Vector2) + Vector2(0, 5.8)), 10, false)
		check(was != "" and game.fence_drag and hud._err == "", "тянем забор: красная строка у курсора погасла («%s» → «%s»)" % [was, hud._err])
		await key(KEY_ESCAPE)
		btn(scr((one["pos"] as Vector2) + Vector2(0, 5.8)), MOUSE_BUTTON_LEFT, false)
		await frames(3)
	# Z/X с забором — от его поворота, а не от поворота прошлой постройки
	game.set_tool("fence")
	game.tool_yaw = 0.0
	game.place_info = {"yaw": PI * 0.5, "pos": P, "tier": 1, "variant": 0, "color": 0, "_t": "house_pleb"}   # как после дома у дороги
	move(scr(P + Vector2(0, 2)))
	await frames(4)
	await key(KEY_Z)
	check(absf(game.tool_yaw - deg_to_rad(-15.0)) < 0.001, "Z с забором: −15° от его поворота, а не от дома (%.0f°)" % rad_to_deg(game.tool_yaw))
	game.set_tool("")


# ---------- настенные украшения как в Town to City ----------

## Проёмы окон и дверей стены f чертежа bp — заново, только по таблице замеров (без «прочего» WallDecor)
func _openings(bp: Bp, f: Dictionary) -> Array:
	var out := []
	var n: Vector3 = f["n"]
	var a: Vector3 = f["a"]
	for p in bp.parts:
		var nm: String = p[0]
		var xf: Transform3D = p[1]
		if not WallDecor.is_wall(nm, xf):
			continue
		var sx := xf.basis.x.length()
		var sy := xf.basis.y.length()
		var sz := xf.basis.z.length()
		if xf.basis.z.normalized().dot(n) < 0.99:
			continue
		var box := Bp.model_aabb(nm)
		if absf(xf.origin.dot(n) + WallDecor.SURF * sz - float(f["d"])) > 0.06 and absf(xf.origin.dot(n) + WallDecor.SURF_LARGE * sz - float(f["d"])) > 0.06:
			continue
		var u0 := xf.origin.dot(a) + box.position.x * sx
		for r: Rect2 in WallDecor._openings(nm):
			out.append(Rect2(u0 + r.position.x * sx, xf.origin.y + r.position.y * sy, r.size.x * sx, r.size.y * sy))
	return out


## Стена чертежа bp, на которой висит украшение (точка lp, смотрит по nd)
func _face_at(bp: Bp, lp: Vector3, nd: Vector3) -> Dictionary:
	var best := {}
	var bd := 0.3
	for f: Dictionary in WallDecor.faces(bp):
		if (f["n"] as Vector3).dot(nd) < 0.99:
			continue
		var dist := absf(lp.dot(f["n"]) - float(f["d"]) - WallDecor.OUT)
		if dist < bd:
			bd = dist
			best = f
	return best


## Украшения o на постройке h: сколько не на стене или на окне/двери
func _decor_bad(h: Dictionary, list: Array) -> Array:
	var bp := c.blueprint(h)
	var hx := c.xf(h)
	var bad := []
	for o in list:
		if not c.buildings.has(int(o["id"])):
			continue
		var lp := hx.affine_inverse() * Vector3(o["pos"].x, float(o["y"]), o["pos"].y)
		var ly := float(o["yaw"]) - float(h["yaw"])
		var f := _face_at(bp, lp, Vector3(sin(ly), 0, cos(ly)))
		if f.is_empty():
			bad.append("не на стене %s" % [lp])
			continue
		var rr := WallDecor.rect_of(String(o["type"]))
		var r := Rect2(lp.dot(f["a"]) + rr.position.x, lp.y + rr.position.y, rr.size.x, rr.size.y)
		for op: Rect2 in _openings(bp, f):
			if op.intersects(r.grow(-0.02)):
				bad.append("на проёме %s" % [op])
	return bad


func _sweep() -> void:
	var bad := 0
	var placed := 0
	var types := [["house_pleb", 2], ["house_artisan", 2], ["house_patrician", 2], ["bakery", 0], ["taberna", 0]]
	for tt: Array in types:
		var tp: String = tt[0]
		for v in int(Defs.B[tp].get("variants", 1)):
			var bp := Catalog.make(tp, int(tt[1]), v, 2)
			for f: Dictionary in WallDecor.faces(bp):
				var ops := _openings(bp, f)
				var bd: Rect2 = f["bound"]
				for deco: String in ["wall_torch", "wall_flowers", "wall_banner_3"]:
					var rect := WallDecor.rect_of(deco)
					for iu in 7:
						for iy in 6:
							var hu := bd.position.x + bd.size.x * (iu + 0.5) / 7.0
							var hy := bd.position.y + bd.size.y * (iy + 0.5) / 6.0
							var hit: Vector3 = (f["a"] as Vector3) * hu + (f["n"] as Vector3) * float(f["d"])
							hit.y = hy
							var s := WallDecor.solve(bp, hit, -(f["n"] as Vector3), deco, [])
							if s.is_empty() or s["err"] != "":
								continue
							placed += 1
							var r := Rect2(float(s["u"]) + rect.position.x, float(s["y"]) + rect.position.y, rect.size.x, rect.size.y)
							for o: Rect2 in ops:
								if o.intersects(r.grow(-0.02)):
									bad += 1
									break
	check(placed > 300 and bad == 0, "обход 5 видов построек: повешено %d, на окнах и дверях — %d" % [placed, bad])


## Фасад постройки (стена, смотрящая как дверь), самый большой
func _front(bp: Bp) -> Dictionary:
	var best := {}
	for f: Dictionary in WallDecor.faces(bp):
		if (f["n"] as Vector3).dot(Vector3(0, 0, 1)) > 0.99 and (best.is_empty() or (f["bound"] as Rect2).get_area() > (best["bound"] as Rect2).get_area()):
			best = f
	return best


## Свободное место на стене f для украшения rect поближе к (u, y), с запасом 4 см во все стороны (курсор — не точнее
## пикселя); Vector2.INF — нет
func roomy(f: Dictionary, rect: Rect2, u: float, y: float, extra: Array) -> Vector2:
	var best := Vector2.INF
	var bd := INF
	var bnd: Rect2 = f["bound"]
	var nu := int(bnd.size.x / 0.05)
	var ny := int(bnd.size.y / 0.05)
	for i in nu + 1:
		for j in ny + 1:
			var cu := bnd.position.x + i * 0.05
			var cy := bnd.position.y + j * 0.05
			var dd := Vector2(cu - u, cy - y).length_squared()
			if dd >= bd:
				continue
			var ok := true
			for o: Vector2 in [Vector2.ZERO, Vector2(0.04, 0), Vector2(-0.04, 0), Vector2(0, 0.04), Vector2(0, -0.04)]:
				if not WallDecor.fits(f, rect, cu + o.x, cy + o.y, extra):
					ok = false
					break
			if ok:
				bd = dd
				best = Vector2(cu, cy)
	return best


## Камера прямо перед стеной постройки h (по умолчанию — фасадом; side — поворот стены относительно фасада)
func _look_front(h: Dictionary, side := 0.0) -> void:
	var f := City.facing(float(h["yaw"]) + side)
	game.rig.set_view(Vector3(h["pos"].x, float(h["y"]) + 2.2, h["pos"].y) + Vector3(f.x, 0, f.y) * 2.0, rad_to_deg(float(h["yaw"]) + side), 8, 16)
	await frames(90)                             # камера тянется к земле (высота цели) — ждём, пока встанет


## Навести курсор на точку w (мир) — дважды: камера могла чуть сдвинуться
func aim(w: Vector3) -> void:
	move(scr3(w))
	await frames(3)
	move(scr3(w))
	await frames(4)
	if hud.mouse_over_ui():
		print("S3 note: курсор над окном интерфейса ", scr3(w))


func _wall_decor() -> void:
	print("== настенные украшения")
	await _sweep()
	var h := put("house_pleb", Vector2(214, 186))
	if not check(not h.is_empty(), "дом для украшений"):
		return
	h["tier"] = 2
	game._show(h)
	await _look_front(h)
	var bp := c.blueprint(h)
	var front := _front(bp)
	if not check(not front.is_empty(), "у дома есть фасад"):
		return
	game.set_tool("wall_torch")
	await frames(2)
	var hx := c.xf(h)
	var bd: Rect2 = front["bound"]
	var rect := WallDecor.rect_of("wall_torch")
	# куда навести: свободные места стены рядом с четырьмя точками (на обоих этажах) — украшение встаёт там, где курсор
	var spots := [[0.15, 0.3], [0.85, 0.3], [0.5, 0.78], [0.15, 0.85]]
	var hung := []
	for sp: Array in spots:
		var u0 := bd.position.x + bd.size.x * float(sp[0])
		var y0 := bd.position.y + bd.size.y * float(sp[1])
		var at := roomy(front, rect, u0 - rect.get_center().x, y0 - rect.get_center().y, WallDecor._extra_on(front, WallDecor.hosted(c, h)))
		if at == Vector2.INF:
			print("S3 note: у точки (%.2f, %.2f) свободного места нет" % [sp[0], sp[1]])
			continue
		var lp: Vector3 = (front["a"] as Vector3) * (at.x + rect.get_center().x) + (front["n"] as Vector3) * float(front["d"])
		lp.y = at.y + rect.get_center().y
		var wp := hx * lp
		await aim(wp)
		var pl: Dictionary = game.place_info
		var got := hx.affine_inverse() * Vector3((pl["pos"] as Vector2).x, float(pl["y"]), (pl["pos"] as Vector2).y)
		var okp: bool = int(pl.get("host", -1)) == int(h["id"]) and pl["err"] == "" and absf(got.dot(front["a"]) - at.x) < 0.25 and absf(got.y - at.y) < 0.25
		check(okp, "курсор на стене (%.2f, %.2f): факел там, где курсор" % [sp[0], sp[1]], "host %d/%d, err «%s», где %s, ждали %s" % [int(pl.get("host", -1)), int(h["id"]), pl.get("err", ""), Vector2(got.dot(front["a"]), got.y), at])
		if okp:
			var n1: int = c.buildings.size()
			btn(scr3(wp), MOUSE_BUTTON_LEFT, true)
			await frames(2)
			btn(scr3(wp), MOUSE_BUTTON_LEFT, false)
			await frames(3)
			if c.buildings.size() == n1 + 1:
				hung.append(c.buildings[c.next_id - 1])
	check(hung.size() >= 3, "повешено факелов: %d" % hung.size())
	var ys := []
	for o in hung:
		ys.append(snappedf(float(o["y"]) - float(h["y"]), 0.1))
	check(ys.size() >= 3 and ys.max() - ys.min() > 1.0, "на разной высоте, на обоих этажах: %s" % [ys])
	# навели на окно — на окно не встаёт (сдвинется на свободное место или скажет, что нельзя)
	var ops0 := _openings(bp, front)
	if not ops0.is_empty():
		var op: Rect2 = ops0[ops0.size() - 1]
		var lp: Vector3 = (front["a"] as Vector3) * op.get_center().x + (front["n"] as Vector3) * float(front["d"])
		lp.y = op.get_center().y
		move(scr3(hx * lp))
		await frames(4)
		var pl: Dictionary = game.place_info
		if pl["err"] == "":
			var got := hx.affine_inverse() * Vector3((pl["pos"] as Vector2).x, float(pl["y"]), (pl["pos"] as Vector2).y)
			var r := Rect2(got.dot(front["a"]) + rect.position.x, got.y + rect.position.y, rect.size.x, rect.size.y)
			check(not op.intersects(r.grow(-0.02)), "навели на окно — факел рядом, не на окне")
		else:
			check(String(pl["err"]).contains("окна"), "навели на окно — «%s»" % pl["err"])
	var over := _decor_bad(h, hung)
	check(over.is_empty(), "ни один факел не на окне и не на двери", over)
	await shot("s3_wall_decor.png")
	# надстроили этаж — украшения на тех же стенах, мимо окон нового облика
	h["tier"] = 3
	c.house_changed.emit(h, true)
	await frames(3)
	var still := 0
	for o in hung:
		if c.buildings.has(int(o["id"])) and int(o.get("host", -1)) == int(h["id"]):
			still += 1
	var bad3 := _decor_bad(h, hung)
	check(still == hung.size() and bad3.is_empty(), "этаж надстроили: украшения на стене (%d), не на окнах" % still, bad3)
	await _look_front(h)
	await shot("s3_wall_floor3.png")
	# перенос дома — украшения с ним
	game.set_tool("")
	var n0 := 0
	for id in c.buildings:
		if int(c.buildings[id].get("host", -1)) == int(h["id"]):
			n0 += 1
	game.start_move(h)
	var mpl: Dictionary = {}
	cands.sort_custom(func(p, q): return p.distance_squared_to(Vector2(216.8, 198)) < q.distance_squared_to(Vector2(216.8, 198)))
	for cp: Vector2 in cands.slice(0, 120):
		reset()
		mpl = game.placement("house_pleb", cp)
		if mpl["err"] == "" and (mpl["pos"] as Vector2).distance_to(h["pos"]) > 6.0:
			break
	var moved_ok := false
	if mpl.get("err", "x") == "":
		game.place_lock = {"p": mpl["pos"]}
		game.tool_yaw = float(mpl["yaw"])
		game._build_here()
		var host_id := -1
		for id in c.buildings:
			if c.buildings[id]["type"] == "house_pleb" and int(c.buildings[id]["tier"]) == 3:
				host_id = int(id)
		var cnt := 0
		for id in c.buildings:
			if int(c.buildings[id].get("host", -1)) == host_id:
				cnt += 1
		moved_ok = cnt == n0 and n0 > 0
	else:
		game.set_tool("")
	check(moved_ok, "перенесли дом — украшения с ним (%d)" % n0, "место «%s», переносим ли ещё: %s" % [mpl.get("err", "?"), not game.moving.is_empty()])
	game.place_lock = {}
	# старое украшение (прежним способом, как в старых сохранениях) — висит и тоже переезжает на этаж
	var h2 := put("house_artisan", Vector2(214, 172))
	if not h2.is_empty():
		var bp2 := c.blueprint(h2)
		var p2: Vector2 = (h2["pos"] as Vector2) + City.facing(h2["yaw"]) * (bp2.front_z() + 0.3)
		var opl: Dictionary = game._wall_place("wall_flowers", p2, 1.0)
		if check(opl["err"] == "" and opl.has("host"), "украшение по-старому (как в готовом городе меню)"):
			var od := c.place("wall_flowers", opl["pos"], opl["yaw"], 0, int(opl["color"]), true)
			od["host"] = opl["host"]
			od["y"] = opl["y"]
			game._show(od)
			h2["tier"] = 2
			c.house_changed.emit(h2, true)
			await frames(2)
			check(c.buildings.has(int(od["id"])) and int(od["host"]) == int(h2["id"]) and _decor_bad(h2, [od]).is_empty(), "украшение по-старому: на месте после этажа, мимо окон", _decor_bad(h2, [od]))
	game.set_tool("")


# ---------- у стены украшение не превращается (решение владельца 12.10); настенные — свои карточки ----------

func _wall_forms() -> void:
	print("== у стены — без превращений")
	var h := put("house_pleb", Vector2(232, 154))
	if not check(not h.is_empty(), "дом для фонаря"):
		return
	h["tier"] = 2
	game._show(h)
	var hp: Vector2 = h["pos"]
	var bp := c.blueprint(h)
	# стена с местом для всех трёх настенных (у узкого фасада окна и двери почти везде — берём боковую, если там просторнее)
	var wall := {}
	for f: Dictionary in WallDecor.faces(bp):
		var room := true
		for wt: String in ["wall_lamp", "wall_flowers", "wall_banner"]:
			if roomy(f, WallDecor.rect_of(wt), (f["bound"] as Rect2).get_center().x, (f["bound"] as Rect2).get_center().y, []) == Vector2.INF:
				room = false
		if room and (wall.is_empty() or (f["bound"] as Rect2).get_area() > (wall["bound"] as Rect2).get_area()):
			wall = f
	if not check(not wall.is_empty(), "у дома есть стена с местом"):
		return
	var side := atan2((wall["n"] as Vector3).x, (wall["n"] as Vector3).z)
	await _look_front(h, side)
	var bd: Rect2 = wall["bound"]
	var lamp_wp := Vector3.INF
	for pair: Array in [["lamp_post", "wall_lamp"], ["flowers", "wall_flowers"], ["banner", "wall_banner"]]:
		var t: String = pair[0]
		var wt: String = pair[1]
		var rect := WallDecor.rect_of(wt)
		var at := roomy(wall, rect, bd.get_center().x, bd.get_center().y, WallDecor._extra_on(wall, WallDecor.hosted(c, h)))
		if at == Vector2.INF:
			print("S3 note: на стене нет места для «%s»" % wt)
			at = bd.get_center()
		var lp: Vector3 = (wall["a"] as Vector3) * (at.x + rect.get_center().x) + (wall["n"] as Vector3) * float(wall["d"])
		lp.y = at.y + rect.get_center().y
		var wp := c.xf(h) * lp
		if t == "lamp_post":
			lamp_wp = wp
		# наземное украшение, наведённое на стену, — собой: ни настенного облика, ни стены
		game.set_tool(t)
		await aim(wp)
		var pl: Dictionary = game.place_info
		var ok: bool = String(pl.get("_t", "")) == t and not pl.has("form") and not pl.has("host")
		var why := "для «%s», host %d, err «%s»" % [pl.get("_t", ""), int(pl.get("host", -1)), pl.get("err", "")]
		if ok and pl["err"] == "":
			var n1: int = c.buildings.size()
			await click(scr3(wp))
			var nb: Dictionary = c.buildings.get(c.next_id - 1, {})
			ok = c.buildings.size() == n1 + 1 and String(nb.get("type", "")) == t and not nb.has("host")
			why += ", построек +%d, новая «%s» host %d, место «%s»" % [c.buildings.size() - n1, nb.get("type", ""), int(nb.get("host", -1)), game.place_info.get("err", "")]
			if ok:
				c.remove(nb, false)
		check(ok, "«%s» у стены — так и остаётся «%s»" % [Defs.B[t]["name"], Defs.B[t]["name"]], why)
		# настенная карточка — на стене, там, где курсор
		game.set_tool(wt)
		await aim(wp)
		pl = game.place_info
		var ok2: bool = int(pl.get("host", -1)) == int(h["id"]) and pl["err"] == ""
		if ok2:
			var n2: int = c.buildings.size()
			await click(scr3(wp))
			var nw: Dictionary = c.buildings.get(c.next_id - 1, {})
			ok2 = c.buildings.size() == n2 + 1 and String(nw.get("type", "")) == wt and int(nw.get("host", -1)) == int(h["id"])
			if ok2 and t == "flowers":
				await shot("s3_wall_card.png")
			if ok2:
				c.remove(nw, false)                  # стена снова свободна — следующему есть место
		check(ok2, "«%s» — на стене дома" % Defs.B[wt]["name"], "host %d/%d, err «%s»" % [int(pl.get("host", -1)), int(h["id"]), pl.get("err", "")])
	# перенос фонаря на стену дома: на стену он не встаёт, клетки и высоты дома не трогаются
	var lamp := put("lamp_post", hp - City.facing(h["yaw"]) * 6.5)
	if check(not lamp.is_empty() and lamp_wp.is_finite(), "фонарь для переноса"):
		var cells: PackedInt32Array = h["cells"]
		var occ0 := []
		var hh0 := []
		for k in cells:
			occ0.append(land.occ[k])
			hh0.append(land.h[k])
		game.start_move(lamp)
		await aim(lamp_wp)
		var mp: Dictionary = game.place_info
		check(not mp.has("form") and not mp.has("host"), "перенос фонаря к стене — без настенного облика («%s»)" % mp.get("err", ""))
		var n3: int = c.next_id
		game._build_here()
		var same := true
		for i in cells.size():
			if land.occ[cells[i]] != int(occ0[i]) or absf(land.h[cells[i]] - float(hh0[i])) > 1e-4:
				same = false
		var nl: Dictionary = c.buildings.get(n3, {})
		check(same and (nl.is_empty() or (String(nl["type"]) == "lamp_post" and not nl.has("host"))), "клетки и высоты дома не тронуты, фонарь — на земле", nl.get("type", ""))
		game.set_tool("")
	# на земле — как был
	game.set_tool("lamp_post")
	game.rig.set_view(Vector3(hp.x, 2, hp.y), rad_to_deg(float(h["yaw"])) + 180.0, 60, 22)
	await frames(20)
	move(scr(hp - City.facing(h["yaw"]) * 6.5))
	await frames(4)
	check(not game.place_info.has("form") and not game.place_info.has("host"), "на земле — фонарь на столбе", game._pick_hit)
	game.set_tool("")


# ---------- город владельца: старые украшения, заборы, скорость мазка на «Низкой» ----------

func _owner() -> void:
	print("== город владельца")
	var src = JSON.parse_string(FileAccess.get_file_as_string("D:/CivCity/.work/owner_save/city.json"))
	var want := {}
	var fence3 := 0
	for bd in src["buildings"]:
		if int(bd.get("host", -1)) >= 0:
			want[int(bd["id"])] = [float(bd["x"]), float(bd["z"]), float(bd["y"]), String(bd["type"])]
		if bd["type"] == "fence_3":
			fence3 += 1
	var have := 0
	var same := 0
	var f3 := 0
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		if b["type"] == "fence_3":
			f3 += 1
		if want.has(int(id)):
			have += 1
			var w: Array = want[int(id)]
			if absf(b["pos"].x - w[0]) < 0.001 and absf(b["pos"].y - w[1]) < 0.001 and absf(float(b["y"]) - w[2]) < 0.001 and int(b["host"]) >= 0:
				same += 1
	check(have == want.size() and same == want.size() and want.size() == 10, "украшения на стенах из сохранения: %d из %d, на тех же местах %d" % [have, want.size(), same])
	check(f3 == fence3 and fence3 == 17, "садовые стенки: %d из %d" % [f3, fence3])
	var vis := 0
	for id in want:
		if game.visuals.has(id):
			vis += 1
	check(vis == want.size(), "и все видны (%d)" % vis)
	# сохранение и обратно — те же
	var sd: Dictionary = game._save_data()
	var back := 0
	for bd in sd["buildings"]:
		if want.has(int(bd["id"])) and int(bd["host"]) >= 0:
			back += 1
	check(back == want.size(), "в новом сохранении: %d" % back)
	# скорость мазка на «Низкой» (3.3)
	game.can_save = false
	game.speed = 0.0
	game.settings["quality"] = "low"
	game._apply_quality()
	hud.advisor_panel.visible = false
	hud.close_panels()
	game.rig.set_view(Vector3(210, 2, 145), 15, 42, 60)
	await frames(60)
	c.money = 50000.0
	game.set_tool("road")
	game.brush_r = 2.0
	await frames(20)
	var idle := []
	for k in 90:
		await frames(1)
		idle.append(frame_ms())
	# мазок по пустому месту своей земли
	var spot := Vector2.INF
	for z in range(80, 250, 4):
		for x in range(140, 250, 4):
			var ok := true
			for dx in range(0, 25, 2):
				var p := Vector2(x + dx, z)
				if not land.is_owned(p) or land.occ_at(p) != 0 or land.is_water(p) or land.is_road(p):
					ok = false
					break
			if ok:
				spot = Vector2(x, z)
				break
		if spot != Vector2.INF:
			break
	if not check(spot != Vector2.INF, "место для мазка"):
		return
	game.rig.set_view(Vector3(spot.x + 12, 2, spot.y), 15, 42, 60)
	await frames(30)
	var a := scr(spot)
	var b := scr(spot + Vector2(24, 0))
	move(a)
	await frames(3)
	btn(a, MOUSE_BUTTON_LEFT, true)
	var st := []
	for k in 60:
		move(a.lerp(b, (k + 1) / 60.0))
		await frames(1)
		st.append(frame_ms())
	btn(b, MOUSE_BUTTON_LEFT, false)
	var rel := []
	for k in 12:
		await frames(1)
		rel.append(frame_ms())
	idle.sort()
	var st2 := st.duplicate()
	st2.sort()
	var im: float = idle[idle.size() / 2]
	var sm: float = st2[st2.size() / 2]
	var s90: float = st2[int(st2.size() * 0.9)]
	print("S3 PERF low: покой %.1f мс, мазок медиана %.1f / 90%% %.1f мс, отпускание и 11 кадров после %s мс" % [im, sm, s90, str(rel.map(func(x): return snappedf(x, 0.1)))])
	check(sm <= im + 6.0, "кадры мазка ≤ покой + 6 мс (медиана %.1f / %.1f)" % [sm, im])
	check(rel.max() <= 40.0, "кадр отпускания и следующие ≤ 40 мс (%.1f)" % rel.max())
