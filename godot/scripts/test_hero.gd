extends Node
## Свой герой (решение владельца Д11, этап L.3 плана от 24.10).
##   bash .work/py/gpu_run.sh res://test_hero.tscn               — новый город: экран «Ваш герой» (наборы, «Случайный», имя),
##        герой на улицах (венок, плащ, свои прогулки), щелчок по нему на 34 м, медальон «Герой», карточка и «Гардероб»,
##        вещи гардероба → колокольчик, Легион (своё место; бои с городами и снимки отряда — без героя), 3D-бой с героем
##        (учебный бой с маслом), «Разбойники у арки» — его реплики (уличный герой в ролике спрятан), сохранение и загрузка;
##        постройка на герое и поперёк его пути, Казармы при нём — ночует в них, экран на «Низкой», боец под медальоном
##        героя не в счёт советов и шансов; в конце «HERO DONE fails=0»
##   … -- mode=owner   — копия города владельца: герой создаётся один раз, экран с «Позже»; после «Позже» — случайный герой,
##        после загрузки — тот же, экран больше не открывается; город владельца цел
## Снимки — .work/gd/a/hero_*.png

const OWNER := "D:/CivCity/.work/owner_save/city.json"
const SHOTS := "D:/CivCity/.work/gd/a/"
var game
var c: City
var ppl: People
var hud
var fails := 0
var mode := ""
var cands := []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("mode="):
			mode = a.trim_prefix("mode=")
	if mode == "owner" and FileAccess.file_exists(OWNER):
		DirAccess.copy_absolute(OWNER, GamePaths.save_dir().path_join("city.json"))
		_boot({"play": "1", "hour": "11"})
	else:
		mode = "shot" if mode == "shot" else ""
		if FileAccess.file_exists(GamePaths.save_dir().path_join("city.json")):
			DirAccess.remove_absolute(GamePaths.save_dir().path_join("city.json"))
		_boot({"new": "1", "hour": "10"})
	_run()


func _boot(b: Dictionary, screen := true) -> void:
	Game.boot = b
	game = (load("res://main.tscn") as PackedScene).instantiate()
	game.hero_screen_auto = screen               # экран «Ваш герой» — как у игрока (в проверках он сам не открывается)
	add_child(game)


func _reboot() -> void:
	game.queue_free()
	await frames(5)
	_boot({"play": "1", "hour": "11"})
	while not game.ready_done:
		await frames(5)
	_bind()
	await frames(5)


func _bind() -> void:
	c = game.city
	ppl = game.people
	hud = game.hud


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, what: String, extra = null) -> bool:
	print(("HERO PASS " if ok else "HERO FAIL ") + what + ("" if ok or extra == null else "  " + str(extra)))
	if not ok:
		fails += 1
	return ok


func shot(name: String) -> void:
	if hud != null and hud.advisor_panel != null:
		hud.advisor_panel.visible = false
	await frames(8)
	DirAccess.make_dir_recursive_absolute(SHOTS)
	get_viewport().get_texture().get_image().save_png(SHOTS + name)
	print("SHOT ", name)


func _screen() -> HeroScreen:
	return hud.get_node_or_null("HeroScreen") as HeroScreen


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	_bind()
	await frames(10)
	if mode == "owner":
		await _owner()
	elif mode == "shot":
		var scr := _screen()                      # только снимки экрана «Ваш герой» (подбор света и раскладки)
		for i: int in [0, 4, 1, 6]:
			scr._preset(i)
			await frames(45)
			await shot("hero_create_%d.png" % i)
	else:
		await _new()
	print("HERO DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


# ---------- новый город ----------

func _new() -> void:
	# экран «Ваш герой» — первым делом новой игры; город стоит
	var scr := _screen()
	check(scr != null and scr.mode == "new", "новая игра: экран «Ваш герой»")
	if scr == null:
		return
	check(float(game.speed) == 0.0 and game.rig.cine, "пока выбираем — город стоит, камера не ездит")
	check(Hero.exists(c) and not bool(c.hero["made"]), "до выбора у города уже есть случайный герой (made=false)")
	# готовые наборы: каждый собирается и встаёт на подиум как задан
	var ok_presets := 0
	for i in Hero.PRESETS.size():
		scr._preset(i)
		await frames(3)
		var want: Dictionary = (Hero.PRESETS[i]["look"] as Dictionary).duplicate()
		Hero.fix_look(want, int(Hero.PRESETS[i]["sx"]))
		if scr.who != null and Citizen.look_key(scr.who.look) == Citizen.look_key(want) and not scr.who.kid and scr.who.cape_root != null:
			ok_presets += 1
		# в наборе только то, что открыто с начала
		for k: String in ["main", "second", "trim", "cape", "mdl"]:
			for e: Dictionary in Hero.items(c, k, want):
				if str(e["v"]) == str(want.get(k, "")) and not bool(e["open"]):
					check(false, "набор «%s»: %s закрыт" % [Hero.PRESETS[i]["n"], k])
	check(ok_presets == Hero.PRESETS.size(), "все %d наборов собираются (с плащом и венком)" % Hero.PRESETS.size(), ok_presets)
	scr._preset(4)                                 # «Матрона»
	await frames(40)
	await shot("hero_create_f.png")
	scr._preset(0)                                 # «Полководец»
	await frames(50)
	await shot("hero_create.png")
	# «Случайный»: никогда не ребёнок, венок всегда, модель своего пола, только открытое
	var bad := 0
	for i in 24:
		scr._random()
		var l: Dictionary = scr.lk
		if scr.who == null or scr.who.kid or int(l["crown"]) < 1 or (String(l["mdl"]) in Citizen.FEMALE) != (scr.sx == 1):
			bad += 1
		for k: String in ["main", "second", "trim", "cape", "mdl", "hc"]:
			for e: Dictionary in Hero.items(c, k, l):
				if str(e["v"]) == str(l.get(k, "")) and not bool(e["open"]):
					bad += 1
		if i == 11:
			scr._set_sx(1 - scr.sx)
	check(bad == 0, "«Случайный» ×24: не ребёнок, с венком, свой пол, только открытое", bad)
	# имя: грубое, короткое, не буквы — нельзя; римское — можно
	check(Hero.check_name("А") != "" and Hero.check_name("Хуй Петрович") != "" and Hero.check_name("Гай_123") != "" and Hero.check_name("Гай Валерий") == "",
		"имя героя: проверка длины, букв и грубых слов")
	scr._preset(0)
	scr.pn = "А"
	scr._save()
	await frames(2)
	check(_screen() != null and scr.err_lbl.text != "", "короткое имя — экран не закрылся, под полем — почему", scr.err_lbl.text)
	scr.pn = "Гай Валерий"
	scr._save()
	await frames(5)
	check(_screen() == null, "«В город!» — экран закрылся")
	check(Hero.exists(c) and bool(c.hero["made"]) and Hero.name_of(c) == "Гай Валерий" and c.tips.has("hero_screen"), "герой создан игроком и записан в город")
	check(float(game.speed) > 0.0 and not game.rig.cine, "город снова идёт", [game.speed, game.rig.cine])
	check(not ppl.hero_r.is_empty() and ppl.by_id.has(Hero.HERO_RID) and not ppl.residents.has(ppl.hero_r), "герой на улицах (в by_id, не в счёте жителей)")
	check(int(c.stats.get("pop", 0)) == 0, "герой не входит в число жителей", c.stats.get("pop"))
	# советник один раз: кто он и где его найти
	hud.advisor_panel.visible = false
	hud._once_tips()
	check(c.tips.has("hero_tip") and hud.adv_title.text.contains("ваш герой") and hud.adv_text.text.contains("медальон"), "советник один раз: «… — ваш герой»", hud.adv_title.text)
	hud.advisor_panel.visible = false
	# медальон «Герой» с лицом
	await frames(30)
	check(hud.hero_wrap != null and hud.hero_wrap.visible and (hud.hero_btn.get_node("ic") as TextureRect).material != null, "медальон «Герой» сверху — с лицом героя")
	await _town()
	await _walk_test()
	await _bump_test()
	await _pick_test()
	await _button_test()
	await _card_test()
	await _wardrobe_unlock_test()
	await _low_screen_test()
	await _legion_test()
	await _story_shot()
	await _battle_test()
	_story_test()
	await _save_load_test()


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
	ppl.refresh(game.land.road_chunks.keys())
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
			var b := c.place(type, pl["pos"], pl["yaw"], pl["variant"], pl["color"], true)
			game._show(b)
			return b
	return {}


var shops := {}
var barracks := {}


## Украшение — где встанет (без привязки к дороге)
func put_free(type: String, target: Vector2) -> Dictionary:
	for k in 40:
		var p := target + Vector2(cos(k * 0.7), sin(k * 0.7)) * (k * 0.25)
		reset()
		var pl: Dictionary = game.placement(type, p)
		if pl["err"] == "":
			var b := c.place(type, pl["pos"], pl["yaw"], pl["variant"], pl["color"], true)
			game._show(b)
			return b
	return {}


## Городок: улица, лавки, статуя, скамья, форум — куда герою ходить
func _town() -> void:
	game.speed = 0.0
	c.money = 90000
	c.level = 1
	for r in Defs.RESEARCH:
		c.research[r["id"]] = true
	c.research.erase("legion")
	var o := Land.CENTER + Vector2(0, 14)
	street(o + Vector2(-30, 0), o + Vector2(30, 0))
	street(o + Vector2(-30, 14), o + Vector2(30, 14))
	street(o + Vector2(-30, 0), o + Vector2(-30, 14))
	street(o + Vector2(30, 0), o + Vector2(30, 14))
	for i in 6:
		var h := put("house_pleb", o + Vector2(-24 + i * 5.5, 0))
		if not h.is_empty():
			var nm := "Проба%d" % i
			c.settled(int(h["id"]), c.house_cap(h), nm)
			ppl._make_family(nm, c.house_cap(h), int(h["id"]), c.door_point(h))
	for t: String in ["stall_fruit", "bakery", "weaver", "barber", "butcher"]:
		shops[t] = put(t, o + Vector2(-24 + shops.size() * 5.5, 14))
	put_free("statue", o + Vector2(8, 7))
	put_free("bench", o + Vector2(20, 7))
	shops["forum"] = put("forum", o + Vector2(14, 14))
	c.compute()
	ppl._assign_jobs()
	check(not shops["stall_fruit"].is_empty() and not shops["bakery"].is_empty(), "городок: лавки поставлены", shops.keys())


## Куда герой ходит: лавки (любые, к прилавку), площади и большие постройки, военный квартал, статуи, скамьи
func _walk_test() -> void:
	var kinds := {}
	var keep: RandomNumberGenerator = ppl.rng
	ppl.rng = ppl.hero_rng
	for i in 60:
		var r: Dictionary = ppl.hero_r
		ppl._hero_errand(r)
		var d: Dictionary = r["dest"]
		var t := String((c.buildings.get(int(d.get("bid", -1)), {}) as Dictionary).get("type", ""))
		var kind := String(d.get("act", ""))
		if kind == "shop" or (kind == "watch" and t != ""):
			kind = "shop"
		elif kind == "look" and t in People.HERO_SITES:
			kind = "site"
		elif kind == "look" and t != "" and Defs.base_of(t) in ["statue", "column"]:
			kind = "statue"
		kinds[kind] = int(kinds.get(kind, 0)) + 1
	ppl.rng = keep
	print("  куда ходит герой: ", kinds)
	check(kinds.has("shop") and kinds.has("site") and kinds.has("stroll") and kinds.size() >= 4, "герой ходит в лавки, к форуму, на площади, к статуям и скамьям", kinds)
	# живой день: идёт, приходит, занимается делом, снова идёт (рисуется всегда)
	ppl.hero_r["t"] = 0.0
	game.speed = 3.0
	var states := {}
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 45000 and not (states.has("walk") and (states.has("idle") or states.has("door"))):
		await frames(5)
		states[String(ppl.hero_r["state"])] = true
	print("  герой за день: ", states.keys())
	check(states.has("walk") and (states.has("idle") or states.has("door")), "герой гуляет: идёт и останавливается у дела", states.keys())
	var hn: Citizen = ppl.hero_r["node"]
	var crown := false
	if hn != null and hn.hair_att != null:
		for ch in hn.hair_att.get_children():
			crown = crown or String(ch.name).contains("Crown")
	check(hn != null and crown and hn.cape_root != null and hn.cape_sk != null, "на улице — лавровый венок и плащ", [hn != null, crown])
	# мышь над героем — мягкая золотая обводка, ушла — нет
	if hn != null:
		ppl.hero_hover(true)
		var mi0: MeshInstance3D = hn.find_children("*", "MeshInstance3D", true, false)[0]
		var on := mi0.material_overlay != null
		ppl.hero_hover(false)
		check(on and mi0.material_overlay == null, "мышь над героем — мягкая обводка")
	# снимок: камера близко за героем, он идёт
	game.speed = 1.0
	var r2: Dictionary = ppl.hero_r
	ppl.rng = ppl.hero_rng
	var far := {}
	var fd := 0.0
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		var d0 := (b["pos"] as Vector2).distance_to(r2["p"])
		if d0 > fd and d0 < 60.0 and c.def(b)["kind"] in ["shop", "civic", "monument"]:
			fd = d0
			far = b
	if not far.is_empty():
		ppl._release(r2)
		var d := ppl._front_target(r2, far, "look")
		if not d.is_empty():
			ppl._claim(r2, d)
			ppl._go(r2, d["p"], "errand", true)
	ppl.rng = keep
	await frames(30)
	var hp: Vector3 = ppl.person_pos(ppl.hero_r)
	game.rig.set_view(hp, 205, 30, 9)
	PersonCard.follow(hud, {"r": ppl.hero_r})
	game.rig._dist_t = 9.0
	await frames(90)
	await shot("hero_city.png")
	game.rig.stop_follow()


## Постройку поставили на героя или поперёк его пути: он выходит из-под неё и обходит её (как горожане)
func _bump_test() -> void:
	var sp: float = game.speed
	game.speed = 0.0
	var b: Dictionary = shops["forum"]
	var r: Dictionary = ppl.hero_r
	var id := int(b["id"])
	if not check(not b.is_empty() and not r.is_empty(), "форум и герой есть — проверка «встал на героя»"):
		return
	var p0: Vector2 = r["p"]
	ppl._release(r)
	r["state"] = "idle"
	r["act"] = ""
	r["p"] = b["pos"]
	ppl._on_building_added(b)
	check(game.land.occ_at(r["p"]) != id, "постройка встала на героя — он вышел из-под неё", r["p"])
	# шёл по широкой мостовой — посреди пути поставили дом: обходит его
	var done := false
	for off: Vector2 in [Vector2(-50, -36), Vector2(50, -36), Vector2(-50, 60), Vector2(50, 60), Vector2(0, -50), Vector2(0, 70)]:
		var m: Vector2 = Land.CENTER + off
		var a0: Vector2 = m - Vector2(12, 0)
		var z0: Vector2 = m + Vector2(12, 0)
		if game.land.occ_at(m) != 0 or game.land.occ_at(a0) != 0 or game.land.occ_at(z0) != 0:
			continue
		var ch: Array = game.land.paint_line(m - Vector2(14, 0), m + Vector2(14, 0), 6.0, Land.Kind.ROAD, true)
		c.road_cells += ch.size()
		ppl.refresh(game.land.road_chunks.keys())
		if not ppl._free(a0) or not ppl._free(z0) or not ppl._free(m):
			continue
		ppl._release(r)
		r["state"] = "idle"
		r["act"] = ""
		r["p"] = a0
		var keep: RandomNumberGenerator = ppl.rng
		ppl.rng = ppl.hero_rng
		ppl._go(r, z0, "errand", true)
		ppl.rng = keep
		if r["state"] != "walk":
			continue
		var old: PackedVector2Array = (r["path"] as PackedVector2Array).duplicate()
		var h := c.place("house_pleb", m, 0.0, 0, -1, true)
		var hid := int(h["id"])
		var hit0: bool = ppl._path_hits(a0, old, 1, hid)
		check(hit0 and r["state"] == "walk" and not ppl._path_hits(r["p"], r["path"], int(r["i"]), hid), "шёл сквозь новый дом — идёт в обход", [hit0, r["state"]])
		c.remove(h, false)
		done = true
		break
	check(done, "нашлось место для проверки обхода")
	ppl._release(r)                               # обратно в городок (дальше — щелчок по нему)
	r["state"] = "idle"
	r["act"] = ""
	r["p"] = ppl._near_free(p0, 80) if game.land.occ_at(p0) != 0 else p0
	ppl._place(r)
	r["t"] = 0.0
	game.speed = sp


## Экран «Ваш герой» на «Низкой» графике: мирок меньше и без MSAA, город под ним не рисуется; закрыли — рисуется снова
func _low_screen_test() -> void:
	var q0 = game.settings.get("quality", "high")
	var d0: bool = get_viewport().disable_3d
	game.settings["quality"] = "low"
	game.open_hero_screen("edit")
	await frames(5)
	var scr := _screen()
	if check(scr != null, "«Низкая»: экран открылся"):
		check(get_viewport().disable_3d and scr.vp.size == Vector2i(560, 700) and scr.vp.msaa_3d == Viewport.MSAA_DISABLED,
			"«Низкая»: город за экраном не рисуется, мирок 560×700 без MSAA", [get_viewport().disable_3d, scr.vp.size])
		scr._close(false)
		await frames(3)
	check(get_viewport().disable_3d == d0, "экран закрыт — город рисуется как прежде")
	game.settings["quality"] = q0
	game.open_hero_screen("edit")
	await frames(5)
	scr = _screen()
	check(scr != null and not get_viewport().disable_3d and scr.vp.size == HeroScreen.VP and scr.vp.msaa_3d == Viewport.MSAA_4X,
		"«Высокая»: экран как был (город за ним, 720×900, MSAA 4×)")
	if scr != null:
		scr._close(false)
		await frames(3)


## Щелчок по герою на 34 м: ≥ 95 % из 20 — его карточка
func _pick_test() -> void:
	var cam: Camera3D = game.rig.cam
	var tried := 0
	var hit := 0
	for k in 40:
		if tried >= 20:
			break
		hud.close_panels()
		var hn: Citizen = ppl.hero_r["node"]
		if hn == null or float(ppl.hero_r["fade"]) < 1.0:
			await frames(20)
			continue
		var hp := hn.global_position
		game.rig.set_view(Vector3(hp.x, Land.BASE_Y, hp.z), 200 + k * 23, 42, 34)
		await frames(4)
		hn = ppl.hero_r["node"]
		if hn == null:
			continue
		var p := hn.global_position + Vector3(0, 0.45 * hn.scale.y / Citizen.SIZE, 0)
		var sp := cam.unproject_position(p)
		var h: Dictionary = game._ray_pick(cam.project_ray_origin(sp), cam.project_ray_normal(sp))
		if not h.is_empty() and cam.global_position.distance_to(p) > float(h["t"]) + People.OCC_M and int(h["id"]) != ppl.at_bid(ppl.hero_r):
			await frames(15)
			continue                              # за домом его не видно — честно не считаем
		tried += 1
		game._mouse_pos = sp
		game._click()
		if hud.info_p.has("r") and (hud.info_p["r"] as Dictionary).has("hero") and ppl.focus_rid == Hero.HERO_RID:
			hit += 1
		await frames(12)
	game._mouse_pos = Vector2(5, 5)
	check(tried >= 20 and hit >= int(ceil(tried * 0.95)), "щелчок по герою на 34 м: %d из %d" % [hit, tried])
	hud.close_panels()


## «Герой»: камера идёт за ним, его карточка открыта
func _button_test() -> void:
	game.rig.set_view(Vector3(Land.CENTER.x + 60, Land.BASE_Y, Land.CENTER.y + 60), 200, 42, 50)
	await frames(10)
	hud.find_hero()
	await frames(150)
	var hp: Vector3 = ppl.person_pos(ppl.hero_r)
	var d := Vector2(game.rig.target.x, game.rig.target.z).distance_to(Vector2(hp.x, hp.z))
	check(game.rig.following() and hud.info_p.has("r") and (hud.info_p["r"] as Dictionary).has("hero") and d < 2.5,
		"«Герой»: камера у героя (%.1f м) и следует, его карточка открыта" % d)


## Карточка героя и «Гардероб»: переодеть — сразу на нём и на портрете
func _card_test() -> void:
	game.speed = 0.0
	game.select_person({"r": ppl.hero_r})
	await frames(10)
	var txt := _texts(hud.info_box)
	check(txt.contains("Гай Валерий") and txt.contains("Герой города") and txt.contains("Гардероб") and txt.contains("Снаряжение"),
		"карточка героя: имя, «Герой города», снаряжение, гардероб")
	PersonCard.edit = true
	hud._fill_info()
	await frames(20)
	await shot("hero_card.png")
	# с открытым гардеробом карточка не ниже верха нижних полос (проверка 26.10: закрывала «Этаж», «Перестроить» и казну)
	var ir: Rect2 = hud.info_panel.get_global_rect()
	var br: Rect2 = hud.bar_right.get_global_rect()
	check(hud.info_box.find_child("editor_scroll", true, false) != null and ir.end.y <= br.position.y + 4.0,
		"«Гардероб» — в прокрутке, карточка над полосой инструментов (низ %.0f, полоса с %.0f)" % [ir.end.y, br.position.y])
	var lk: Dictionary = Hero.look(c).duplicate()
	var blue := "2f5585"
	lk["cape"] = blue
	Hero.set_look(c, lk)
	ppl.hero_refresh(true)
	await frames(3)
	var hn: Citizen = ppl.hero_r["node"]
	check(hn != null and String(hn.look.get("cape", "")) == blue and String(Hero.look(c)["cape"]) == blue, "«Гардероб»: плащ сменился на герое")
	# закрытая вещь — серая, с причиной
	var gold := Hero.items(c, "cape", Hero.look(c)).filter(func(e): return String(e["v"]) == "c99a2e")
	check(not gold.is_empty() and not bool(gold[0]["open"]) and String(gold[0]["why"]).contains("Большой город"), "золотой плащ закрыт: «Откроется: город „Большой город“»", gold)
	PersonCard.edit = false
	# «Изменить» в карточке — экран «Ваш герой» в правке: «Отмена» ничего не меняет, «Сохранить» — переодел и переименовал
	var chb: Button = hud.info_box.find_child("change", true, false)
	check(chb != null, "в карточке — «Изменить»")
	if chb != null:
		chb.pressed.emit()
		await frames(5)
		var scr := _screen()
		check(scr != null and scr.mode == "edit" and scr.find_children("cancel", "", true, false).size() == 1, "«Изменить»: экран в правке с «Отменой»")
		if scr != null:
			var k0 := Citizen.look_key(Hero.look(c))
			scr._preset(2)
			scr._close(false)
			await frames(3)
			check(Citizen.look_key(Hero.look(c)) == k0 and Hero.name_of(c) == "Гай Валерий", "«Отмена» — герой как был")
			game.open_hero_screen("edit")
			await frames(5)
			scr = _screen()
			scr._preset(2)
			scr.pn = "Тит Валерий"
			scr._save()
			await frames(5)
			check(_screen() == null and Hero.name_of(c) == "Тит Валерий" and String(Hero.look(c)["main"]) == "4d7397", "«Сохранить» — новое имя и облик", Hero.name_of(c))
			scr = null
			game.open_hero_screen("edit")
			await frames(5)
			_screen().pn = "Гай Валерий"
			_screen()._save()
			await frames(5)
	hud.close_panels()


## Ранг города открыл вещи гардероба — одна строчка в колокольчике на всё, что открылось за час, без всплывашек
func _wardrobe_unlock_test() -> void:
	var b0: int = hud.bell_count
	var n0 := c.events.size()
	c.level = 3
	game._hero_hour()
	var lines := c.events.slice(n0).filter(func(e): return String(e["text"]).begins_with("В гардеробе героя"))
	check(lines.size() == 1 and hud.bell_count > b0 and String(lines[0]["text"]).contains("Шафрановый плащ") and String(lines[0]["text"]).contains("и ещё"),
		"«Посёлок»: семь вещей — одна строчка в колокольчике («Шафрановый плащ, … и ещё 4»)", lines)
	var n1 := c.events.size()
	game._hero_hour()
	check(c.events.size() == n1, "второй раз о той же вещи не говорит")


func _texts(n: Node) -> String:
	var s := ""
	for l in n.find_children("*", "Label", true, false):
		s += (l as Label).text + " | "
	for b in n.find_children("*", "Button", true, false):
		s += (b as Button).text + " | "
	return s


## Легион: герой — на своём месте впереди отряда в походах; в боях с городами и в снимке отряда обороны — без него
func _legion_test() -> void:
	var lg: Legion = c.legion
	check(not lg.hero_ready(), "Легион не открыт — героя в отряде нет")
	c.research["legion"] = true
	barracks = put("barracks", Land.CENTER + Vector2(-26, 22))
	if barracks.is_empty():
		barracks = c.place("barracks", Land.CENTER + Vector2(-40, 40), 0.0, 0, -1, true)
	c.compute()
	lg.perks["oil"] = 1
	check(lg.hero_ready(), "Легион открыт и Казармы стоят — герой в строю")
	var bs := lg.battle_squad()
	check(not bs.is_empty() and String(bs[0]["key"]) == "hero" and bs.size() == lg.squad_stats().size() and String(bs[0]["name"]) == "Гай Валерий",
		"в поход: герой — на первом месте отряда (своё место), остальные места — бойцы", bs.map(func(x): return x["key"]))
	check(not lg.squad_stats().any(func(x): return String(x["key"]) == "hero") and not lg.squad_stats("pvp").any(func(x): return String(x["key"]) == "hero"),
		"отряд для боёв с городами — без героя (Legion.HERO_PVP выключен)")
	var snap := lg.defense_snapshot()
	check(not (snap["squad"] as Array).any(func(x): return String(x.get("type", "")) == "hero"), "снимок отряда обороны на сервер — без героя")
	var pv := lg.make_pvp_battle({"name": "Проба", "rating": 0, "city_level": 3, "snapshot": snap}, 5)
	check(not (pv["squad"] as Array).any(func(x): return String(x["key"]) == "hero") and not pv.has("hero_look"), "бой с городом — без героя")
	var st := lg.stage_info(0, 0, 0)
	var setup := lg.make_battle(st, 7)
	check(String(setup["squad"][0]["key"]) == "hero" and setup.has("hero_look") and String(setup.get("tutorial", "")) == "oil", "учебный бой: герой в отряде, его облик — в бою")
	check(int(ppl.hero_r["home"]) == int(barracks.get("id", -2)), "Казармы поставили при герое — он ночует уже в них, не на станции",
		[ppl.hero_r["home"], barracks.get("id")])
	await _squad_keys_test()
	# Склад оружия: снаряжение героя растёт
	var k0 := Hero.kit_tier(0)
	check(k0 == 0 and Hero.kit_tier(1) == 1 and Hero.kit_tier(7) == 3 and String(lg.b_effect("armory", 4)[1]).contains("щит с орлом"), "Склад оружия выдаёт герою снаряжение по уровню")
	# окно «Легион» → «Войска»: место героя
	var ui := LegionUi.of(hud)
	ui.open("troops")
	await frames(20)
	check(not ui.find_children("hero_slot", "", true, false).is_empty() and not ui.find_children("pvp_slot", "", true, false).is_empty(),
		"«Войска»: место героя в отряде, в его углу — боец этого места для боёв с городами (выбирается)")
	await shot("hero_squad.png")
	ui.close()


## Боец первого места спрятан под медальоном героя: советы, шансы и провиант считают тех, кто пойдёт в бой (герой — за
## легионера); старый город с лучником на первом месте — лучник переходит на видное место
func _squad_keys_test() -> void:
	var lg: Legion = c.legion
	var sq0: Array = lg.squad.duplicate()
	var rg := put("range", Land.CENTER + Vector2(-12, 22))
	if rg.is_empty():
		rg = c.place("range", Land.CENTER + Vector2(-56, 40), 0.0, 0, -1, true)
	c.compute()
	var bow := lg.stage_info(0, 0, 1)                # «Пращники в кустах» — нужен лучник
	if not check(lg.available("archer") and Legion.wants_archer(bow) and lg.slots() == 3, "Стрельбище стоит, бой «Пращники в кустах» — с лучником",
			[lg.available("archer"), Legion.wants_archer(bow), lg.slots()]):
		return
	lg.squad = ["archer", "legionary", "legionary"]
	check(lg.campaign_keys() == ["legionary", "legionary", "legionary"] and lg.squad_off(bow) and lg.squad_hint(bow).contains("лучника"),
		"лучник под медальоном героя в бой не идёт — совет «возьмите лучника»", [lg.campaign_keys(), lg.squad_hint(bow)])
	var wolf := lg.stage_info(0, 0, 2)               # «Волчья тропа»: про спрятанного лучника волки не говорят
	check(not lg.squad_hint(wolf).contains("Волки"), "волчий бой: о спрятанном лучнике не предупреждает", lg.squad_hint(wolf))
	lg.hero_squad_fix()
	check(lg.squad == ["legionary", "archer", "legionary"] and not lg.squad_off(bow) and lg.squad_hint(bow) == "",
		"старый город: лучник с первого места — на видное, отряд под бой; в боях с городами — те же бойцы", lg.squad)
	lg.squad = ["", "legionary", "archer"]
	var job := lg.odds_job(bow)
	var per := Legion.FOOD["base"] + Legion.FOOD["per_d"] * float(bow["D"])
	check(lg.battle_squad().size() == 3 and ((job["cur"] as Array)[0]["squad"] as Array).size() == 3 and lg.food_cost(bow) == roundi(3 * per),
		"пустое первое место: шансы и провиант — на трёх (герой и двое), как в бою", [((job["cur"] as Array)[0]["squad"] as Array).size(), lg.food_cost(bow)])
	lg.squad = sq0


## 3D-бой: герой — своим бойцом (его лицо, цвета, плащ, снаряжение); учебный бой с маслом выигран
func _battle_test() -> void:
	var lg: Legion = c.legion
	var st := lg.stage_info(0, 0, 0)
	check(lg.can_fight(st) == "", "в бой можно", lg.can_fight(st))
	lg.start_battle(st)
	await frames(3)
	var battle: LegionBattle = LegionBattle.current
	if not check(battle != null, "3D-бой открылся"):
		return
	var shot_done := false
	var froze := false
	var t0 := Time.get_ticks_msec()
	while battle.phase != "result" and (Time.get_ticks_msec() - t0) < 120000:
		await frames(1)
		if battle.sim == null:
			continue
		if not shot_done and battle.sim.t > 3.2:
			shot_done = true
			var hv := {}
			for id in battle.views:
				if String(battle.views[id]["u"].key) == "hero":
					hv = battle.views[id]
			check(not hv.is_empty() and (hv["f"] as LegionFighter)._cape_sk != null, "в бою — боец-герой с плащом")
			await shot("hero_battle.png")
		if battle.tut_freeze and not froze:
			froze = true
			await frames(30)
			await shot("hero_battle_oil.png")
			battle.use_perk("oil")
	check(froze, "учебный бой замер на масле и с героем")
	check(battle.phase == "result" and bool(battle.out.get("win", false)), "учебный бой с героем выигран", battle.out.get("win"))
	await frames(40)
	await shot("hero_battle_result.png")
	battle._close()
	await frames(60)


## Ролик «Разбойники у арки» (шаг «Казармы готовы»): герой встаёт рядом с переселенцем и говорит — снимок
func _story_shot() -> void:
	var sd := StoryDefs.story("bandits")
	var beats: Array = ((sd["steps"] as Array)[2] as Dictionary)["cine"]
	var hid := -1
	var fam := ""
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		if String(b["type"]) == "house_pleb" and not (b.get("families", []) as Array).is_empty():
			hid = int(id)
			fam = String(b["families"][0]["name"])
			break
	game.speed = 1.0
	# уличный герой стоит на виду (у Казарм, где встанет герой ролика)
	var hr: Dictionary = ppl.hero_r
	ppl._release(hr)
	hr["state"] = "idle"
	hr["act"] = ""
	hr["t"] = 99.0
	var bp: Vector2 = ppl._near_free(c.door_point(barracks) + Vector2(2, 2), 80) if not barracks.is_empty() else hr["p"]
	if bp != Vector2.INF:
		hr["p"] = bp
	ppl._place(hr)
	await frames(10)
	var hn0 = hr["node"]
	var street_seen := hn0 != null and (hn0 as Node3D).visible
	var twin := false
	game.stories._play(sd, {"id": "bandits", "fam": fam, "home": hid, "seed": 4242, "cls": "plebs", "female": false}, beats.duplicate(true), "replay", Callable())
	var t0 := Time.get_ticks_msec()
	var said := false
	var sto = game.stories
	while sto.kit != null and Time.get_ticks_msec() - t0 < 45000:
		await frames(6)
		if sto.cine.is_empty():
			continue
		var i := int(sto.cine.get("i", -1))
		var bs: Array = sto.cine.get("beats", [])
		if i < 0 or i >= bs.size():
			continue
		var b: Array = bs[i]
		if String(b[0]) == "say" and sto.cine.get("wait", false):
			sto.ui.finish_typing()
			if String(b[1]) == "hero" and not said:
				said = true
				var hn = ppl.hero_r["node"]
				twin = hn != null and (hn as Node3D).visible
				await frames(40)
				await shot("hero_story.png")
			await frames(4)
			sto._next()
	check(said, "«Разбойники у арки»: герой в ролике — рядом с переселенцем, своя реплика")
	check(street_seen and not twin, "в ролике со своим героем уличный спрятан — двух одинаковых в кадре нет", [street_seen, twin])
	await frames(30)
	var hn1 = ppl.hero_r["node"]
	check(hn1 != null and (hn1 as Node3D).visible, "ролик кончился — герой на улице снова виден")
	ppl.hero_r["t"] = 0.0


## «Разбойники у арки»: у героя свои реплики (такты — только если герой есть)
func _story_test() -> void:
	var sd := StoryDefs.story("bandits")
	var n := 0
	for stp: Dictionary in sd["steps"]:
		for b: Array in stp.get("cine", []):
			if String(b[0]) == "if" and String(b[1]) == "hero":
				n += 1
	check(n >= 6 and game.stories._cond("hero"), "«Разбойники у арки»: такты героя (%d)" % n)
	var sp: Dictionary = {}
	game.stories.cine = {"bind": {}, "story": sd}
	sp = game.stories._speaker("hero")
	game.stories.cine = {}
	check(String(sp.get("kind", "")) == "look" and String(sp.get("name", "")) == Hero.name_of(c), "в облачке — герой со своим лицом и именем", sp.get("name"))


## Сохранение и загрузка: тот же герой (имя, облик, «видели»), экран не открывается
func _save_load_test() -> void:
	var key := Citizen.look_key(Hero.look(c))
	var seen := (c.hero["seen"] as Array).size()
	var data: Dictionary = game._save_data()
	var js := JSON.stringify(data.get("hero", {}))
	check(js.length() < 2048, "запись героя в сохранении — %d байт (не больше 2 КБ)" % js.length())
	var f := FileAccess.open(GamePaths.save_dir().path_join("city.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	await _reboot()
	check(Hero.exists(c) and Hero.name_of(c) == "Гай Валерий" and Citizen.look_key(Hero.look(c)) == key and (c.hero["seen"] as Array).size() == seen,
		"после загрузки — тот же герой")
	check(_screen() == null and not ppl.hero_r.is_empty(), "после загрузки экран не открывается, герой на улицах")
	check(c.legion.hero_ready() and String(c.legion.battle_squad()[0]["key"]) == "hero", "после загрузки — герой в отряде")


# ---------- город владельца ----------

func _owner() -> void:
	var scr := _screen()
	check(c.buildings.size() > 300 and int(c.stats.get("pop", 0)) > 500, "город владельца загружен", [c.buildings.size(), c.stats.get("pop")])
	check(Hero.exists(c) and not bool(c.hero["made"]), "старый город: случайный герой создан при первом входе")
	check(scr != null and scr.mode == "old" and scr.find_children("later", "", true, false).size() == 1, "экран «Ваш герой» с кнопкой «Позже»")
	var key := Citizen.look_key(Hero.look(c))
	var nm := Hero.name_of(c)
	await frames(40)
	await shot("hero_owner_screen.png")
	if scr != null:
		scr._later()
	await frames(5)
	check(_screen() == null and c.tips.has("hero_screen") and not bool(c.hero["made"]), "«Позже» — остался случайный герой")
	check(not ppl.hero_r.is_empty() and Citizen.look_key(Hero.look(c)) == key, "случайный герой — на улицах")
	# всё уже открытое в старом городе — «видели», в колокольчик ничего не пришло
	var n0 := c.events.size()
	game._hero_hour()
	check(c.events.size() == n0, "открытое до обновления — не строчки в колокольчике")
	check(c.legion.hero_ready() == c.legion.window_open(), "Легион владельца: герой в строю, если Легион открыт", c.legion.window_open())
	if c.legion.window_open():
		var bs := c.legion.battle_squad()
		var sq: Array = c.legion.squad_stats()
		var same := bs.size() == sq.size()
		for i in range(1, mini(bs.size(), sq.size())):
			same = same and String(bs[i]["key"]) == String(sq[i]["key"])
		check(String(bs[0]["key"]) == "hero" and same, "отряд владельца в походе: герой на первом месте, остальные — как были; бои с городами — прежний отряд",
			[bs.map(func(x): return x["key"]), sq.map(func(x): return x["key"])])
	var data: Dictionary = game._save_data()
	var f := FileAccess.open(GamePaths.save_dir().path_join("city.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	await _reboot()
	check(Hero.exists(c) and Hero.name_of(c) == nm and Citizen.look_key(Hero.look(c)) == key, "после загрузки — тот же случайный герой")
	check(_screen() == null, "экран больше не открывается")
	# медальон «Герой» и карточка в большом городе
	await frames(30)
	hud.find_hero()
	await frames(120)
	check(hud.info_p.has("r") and (hud.info_p["r"] as Dictionary).has("hero"), "«Герой» в городе владельца — карточка героя")
	await shot("hero_owner_card.png")
