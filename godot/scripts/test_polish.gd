extends Node
## Пул полировки плана 24.10 (раздел D): режим фото (P), тени облаков, «Летопись города», найм «+/−» (6.12),
## «Обзор → Классы» и «Сносить мешающие украшения», перо у часов при сохранении, высота камеры без покачивания.
##   bash .work/py/gpu_run.sh res://test_polish.tscn                  — новая игра; в конце «POL DONE fails=0»; снимки — .work/gd/b/pol_*.png
##   … -- mode=owner                                                   — копия города владельца: перенос летописи, «Классы», снос украшений,
##                                                                        найм, фото за жителем
##   … -- mode=cam tag=before|after                                    — высота камеры: кадр по умолчанию до/после правки
##   … -- mode=clouds                                                  — тени облаков: снимки с облаками и без
##   … -- shots=0                                                      — без снимков

const OWNER := "D:/CivCity/.work/owner_save/city.json"
const SHOTS := "D:/CivCity/.work/gd/b/"
var game
var c: City
var land: Land
var hud
var fails := 0
var mode := ""
var shots := true


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("mode="):
			mode = a.trim_prefix("mode=")
		if a == "shots=0":
			shots = false
	if mode == "owner" and FileAccess.file_exists(OWNER):
		DirAccess.copy_absolute(OWNER, GamePaths.save_dir().path_join("city.json"))
		Game.boot = {"play": "1", "hour": "11"}
	else:
		Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, what: String, extra = null) -> bool:
	print(("POL PASS " if ok else "POL FAIL ") + what + ("" if ok or extra == null else "  " + str(extra)))
	if not ok:
		fails += 1
	return ok


func shot(name: String) -> void:
	if not shots:
		return
	if hud and hud.advisor_panel.visible:
		hud.advisor_panel.visible = false
	await frames(8)
	DirAccess.make_dir_recursive_absolute(SHOTS)
	get_viewport().get_texture().get_image().save_png(SHOTS + name)
	print("SHOT ", SHOTS + name)


func key(k: Key, shift := false) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.pressed = true
	e.shift_pressed = shift
	game._unhandled_input(e)


func _labels(n: Node) -> String:
	var out := []
	for l in n.find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree():
			out.append((l as Label).text)
	for bt in n.find_children("*", "Button", true, false):
		if (bt as Button).is_visible_in_tree():
			out.append((bt as Button).text)
	return " | ".join(out)


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	c = game.city
	land = game.land
	hud = game.hud
	game.can_save = false
	if mode == "cam":
		await _cam()
	elif mode == "clouds":
		await _clouds()
	elif mode == "owner":
		await _owner()
	else:
		await _new()
	print("POL DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


## Обучение и советы один раз — не мешают
func _calm() -> void:
	game.tutorial.step = Tutorial.STEPS.size()
	game.tutorial.card.visible = false
	c.tips["tut"] = -1
	c.tips["ui"] = 3
	hud.apply_reveal(3)
	for t in ["upgrade_tool", "floor_tool", "cat_item_tip", "tax_tip", "set_tip", "prem_tip", "dim_tip", "fest_tip", "rank_tip", "full_money", "full_rp", "name_tip"]:
		c.tips[t] = true
	hud.advisor_panel.visible = false


func place(type: String, at: Vector2, step := Vector2(0, -0.5), tries := 16, variant := -1) -> Dictionary:
	for k in tries:
		var pl: Dictionary = game.placement(type, at + step * k, variant)
		if pl["err"] == "":
			return c.place(type, pl["pos"], pl["yaw"], pl["variant"], pl["color"])
	print("POL NOTE не встало %s у %s: %s" % [type, str(at), game.placement(type, at).get("err", "")])
	return {}


# ---------- новая игра ----------

func _new() -> void:
	_calm()
	c.money = 20000.0
	for r in ["artisans", "floor2"]:
		c.research[r] = true
	await _quill()
	await _photo_basic()
	await _clouds_quality()
	await _chron_new()
	await _hire_new()
	_cam_steady()


## Перо у часов: сохранение — видно, потом тает; без всплывашки
func _quill() -> void:
	print("== перо у часов")
	check(hud.save_quill != null and not hud.save_quill.visible, "перо спрятано, пока не сохраняем")
	game._autosave()                          # can_save = false: файл не пишется, перо — видно
	check(hud.save_quill.visible and hud.save_quill.modulate.a > 0.9, "автосохранение — перо у часов")
	await shot("pol_quill.png")
	var t0 := Time.get_ticks_msec()
	while hud.save_quill.visible and Time.get_ticks_msec() - t0 < 5000:
		await frames(5)
	check(not hud.save_quill.visible, "перо растаяло (%.1f с)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	check(hud.notes_box.get_child_count() == 0, "без всплывашки")


## Режим фото: P, всё спрятано, наклон до земли, время суток, размытие, снимок в «Снимки», выход — всё как было
func _photo_basic() -> void:
	print("== режим фото")
	var rig: CameraRig = game.rig
	rig.set_view(Vector3(192, Land.BASE_Y, 140), 15, 42, 40)
	await frames(10)
	game.set_tool("road")
	key(KEY_P)
	var ph: PhotoMode = game.photo
	check(ph != null and ph.on and game.tool == "" and rig.photo, "P — режим фото, инструмент убран")
	check(not hud.root.visible and not hud.badge_layer.visible and ph.root.visible and ph.bar.visible, "интерфейс и значки спрятаны, видна панель фото")
	check(hud.hidden_ui and not hud._tip_free(), "советник в режиме фото молчит")
	check(ph.hint.visible and c.tips.has("photo_tip"), "подсказка — в первый раз")
	ph.sl_pitch.value = 4.0
	check(absf(rig.pitch_deg() - 4.0) < 0.1 and rig.pitch_min() <= 2.0, "наклон почти до горизонта (4°)")
	ph.sl_time.value = 19.0
	check(is_equal_approx(game.look_hour, 19.0) and ph.lbl_time.text == "19:00", "время суток — свет как в 19:00, часы города идут как шли")
	ph.sl_blur.value = 80.0
	await frames(30)
	check(is_equal_approx(rig.blur, 0.8) and rig.attrs.dof_blur_far_enabled and rig.attrs.dof_blur_amount > 0.2, "размытие 80%%: глубина резкости %.2f" % rig.attrs.dof_blur_amount)
	await shot("pol_photo_ui.png")
	# клавиши инструментов в режиме фото не действуют
	key(KEY_U)
	key(KEY_DELETE)
	check(game.tool == "", "U и Delete в режиме фото — ничего")
	var path: String = await ph.snap()
	var img: Image = Image.load_from_file(path) if path != "" else null
	var good := path != "" and path.get_base_dir().get_file() == PhotoMode.DIR_NAME and path.begins_with(GamePaths.save_dir())
	var vs: Vector2i = get_viewport().get_texture().get_image().get_size()
	check(good and img != null and img.get_size() == vs, "снимок: %s (%s, кадр %s)" % [path, str(img.get_size()) if img else "—", str(vs)])
	check(ph.root.visible and ph.btn_folder.visible and ph.lbl_saved.text.contains(PhotoMode.DIR_NAME) and hud.notes_box.get_child_count() == 0,
		"после снимка — панель снова видна, подпись «%s», без всплывашек" % ph.lbl_saved.text)
	if img:
		img.resize(img.get_width() / 2, img.get_height() / 2)
		DirAccess.make_dir_recursive_absolute(SHOTS)
		img.save_png(SHOTS + "pol_photo_snapshot.png")
	ph.sl_time.value = 11.0
	ph.sl_blur.value = 19.0
	rig.set_pitch_deg(14.0)
	key(KEY_ESCAPE)
	await frames(10)
	check(not ph.on and hud.root.visible and hud.badge_layer.visible and not rig.photo and not hud.hidden_ui, "Esc — режим фото выключен, интерфейс вернулся")
	check(is_equal_approx(game.look_hour, -1.0) and rig.pitch_deg() >= 8.0 - 0.01 and is_equal_approx(rig.attrs.dof_blur_amount, 0.09),
		"свет по часам, наклон в обычных пределах (%.1f°), размытие игры (%.2f)" % [rig.pitch_deg(), rig.attrs.dof_blur_amount])
	key(KEY_P)
	check(ph.on and not ph.hint.visible, "второй раз — без подсказки")
	hud._top_action("photo")
	check(not ph.on, "кнопка «Фото» тоже выключает")


## Тени облаков: «Высокая»/«Средняя» — есть, «Низкая»/«Очень низкая» — нет; ночью нет; плывут
func _clouds_quality() -> void:
	print("== тени облаков")
	var cl: Clouds = game.clouds
	game.hud.set_speed(1.0)
	game._set_hour(11.0)
	check(cl != null and cl.enabled and cl.visible and cl.tiles.size() == 9, "«Высокая»: облака есть")
	var o0 := cl.off
	await frames(20)
	check(cl.off != o0, "облака плывут (сдвиг %s → %s)" % [str(o0), str(cl.off)])
	for q: String in ["medium", "low", "verylow", "high"]:
		game.settings["quality"] = q
		game._apply_quality()
		check(cl.enabled == (q in ["high", "medium"]) and cl.visible == cl.enabled, "«%s»: облака %s" % [Gfx.NAMES[q], "есть" if cl.enabled else "нет"])
	game._set_hour(1.0)
	check(not cl.visible, "ночью теней облаков нет")
	game._set_hour(11.0)
	check(cl.visible and cl.tiles[0].modulate.a > 0.2, "днём есть (сила %.2f)" % cl.tiles[0].modulate.a)
	await frames(2)
	var t: Vector3 = game.rig.target
	var inside := false
	for d: Decal in cl.tiles:
		var p := d.global_position
		inside = inside or (absf(p.x - t.x) <= Clouds.TILE * 0.5 + 0.01 and absf(p.z - t.z) <= Clouds.TILE * 0.5 + 0.01)
	check(inside, "камера над серединой плиток")
	# test_perf прячет Decal на снимках — облака на сверку с эталоном не попадут
	var dec: Array = game.find_children("*", "Decal", true, false)
	check(dec.size() >= 9, "облака — Decal (снимки test_perf их прячут): %d" % dec.size())


## «Летопись города»: счётчики, венок — строка в колокольчик (без всплывашки), сохранение, старое сохранение, журнал
func _chron_new() -> void:
	print("== летопись")
	check(c.chron_on and Chronicle.count(c) == 0, "новая игра: летопись пустая, венки проверяются")
	var built0 := Chronicle.value(c, "built")
	var X0 := 150.0
	var Z0 := 196.0
	game.clear_nature(Vector2(X0 + 20.0, Z0 + 6.0), 40.0)
	land.paint_line(Vector2(X0 - 6.0, Z0), Vector2(X0 + 52.0, Z0), 1.6, Land.Kind.ROAD, true)
	await frames(4)
	var houses := []
	for k in 6:
		var hb := place("house_pleb", Vector2(X0 + k * 5.0, Z0 - 3.0), Vector2(0.3, 0), 8, k % 5)
		if not hb.is_empty():
			houses.append(hb)
	check(houses.size() == 6 and Chronicle.value(c, "built") == built0 + 6, "построено домов: +%d" % (Chronicle.value(c, "built") - built0))
	if houses.size() < 6:
		return
	var p0 := Chronicle.value(c, "people")
	c.settled(int(houses[0]["id"]), 4, "Летописцы")
	check(Chronicle.value(c, "people") == p0 + 4 and Chronicle.value(c, "fams") >= 1, "горожан поселилось: +4")
	var ev0 := c.events.size()
	var bell0: int = hud.bell_count
	var notes0: int = hud.notes_box.get_child_count()
	c.sim_day()
	var got: Array = (c.chron["b"] as Dictionary).keys()
	var lines := c.events.slice(ev0).filter(func(e): return String(e["text"]).begins_with("Летопись города: лавровый венок"))
	check(got.has("fam1") and lines.size() == got.size() and hud.bell_count >= bell0 + lines.size() and hud.notes_box.get_child_count() == notes0,
		"венок «Первая семья» — строка в колокольчик, без всплывашки: %s" % [lines.map(func(e): return e["text"])])
	var n1 := Chronicle.count(c)
	c.sim_day()
	check(Chronicle.count(c) == n1 and c.events.slice(ev0).filter(func(e): return String(e["text"]).contains("«Первая семья»")).size() == 1, "второй раз тот же венок не даётся")
	Chronicle.add(c, "floors", 10)
	c.sim_day()
	check((c.chron["b"] as Dictionary).has("floors10"), "10 этажей — венок «Этаж за этажом»")
	# советник — один раз, где смотреть
	c.tips.erase("chron_tip")
	hud.advisor_panel.visible = false
	hud._close_windows()
	hud._once_tips()
	check(not (hud.advisor_panel.visible and hud.adv_title.text == "Летопись города"), "на «Стоянке» советник про летопись молчит (первые минуты)")
	c.level = 1
	hud._once_tips()
	check(hud.advisor_panel.visible and hud.adv_title.text == "Летопись города" and hud.adv_text.text.contains("«Летопись»"), "советник один раз: «%s»" % hud.adv_title.text)
	hud.advisor_panel.visible = false
	hud._once_tips()
	check(not (hud.advisor_panel.visible and hud.adv_title.text == "Летопись города"), "…и только один раз")
	hud.advisor_panel.visible = false
	c.level = 0
	# сохранение и загрузка
	var d = JSON.parse_string(JSON.stringify(c.save_data()))
	var c2 := City.new(Land.new())
	c2.load_data(d)
	check(Chronicle.count(c2) == Chronicle.count(c) and Chronicle.value(c2, "built") == Chronicle.value(c, "built") and Chronicle.value(c2, "people") == Chronicle.value(c, "people"),
		"летопись сохраняется: %d венков, построено %d" % [Chronicle.count(c2), Chronicle.value(c2, "built")])
	# старое сохранение — без летописи: счётчики из города, венки разом, одна строка
	var d3 = JSON.parse_string(JSON.stringify(c.save_data()))
	(d3 as Dictionary).erase("chron")
	var n_ev: int = (d3["events"] as Array).size()
	var c3 := City.new(Land.new())
	c3.load_data(d3)
	var last: Dictionary = c3.events[-1] if not c3.events.is_empty() else {}
	check(Chronicle.count(c3) >= 1 and c3.unread == 1 and c3.events.size() == mini(60, n_ev + 1) and String(last.get("text", "")).contains("уже заслужил"),
		"старое сохранение: %d венков разом, одна строка «%s»" % [Chronicle.count(c3), last.get("text", "")])
	check(Chronicle.value(c3, "built") >= 6 and Chronicle.value(c3, "people") >= 4, "счётчики старого города — из построек (%d зданий, %d горожан)" % [Chronicle.value(c3, "built"), Chronicle.value(c3, "people")])
	# журнал: вкладка «Летопись»
	hud.refresh()
	await frames(3)
	var book := false
	for bt: Button in hud.tasks_box.find_children("*", "Button", true, false):
		book = book or String(bt.get_meta("icon", "")) == "bookshelf"
	check(book, "книжка журнала в свитке просьб — есть венки")
	game.stories.ui.open_journal("chron")
	await frames(6)
	var txt := _labels(hud.journal_panel)
	check(hud.journal_panel.visible and txt.contains("Лавровые венки: %d из %d" % [Chronicle.count(c), Chronicle.BADGES.size()]) and txt.contains("Первая семья") and txt.contains("Построено зданий"),
		"вкладка «Летопись»: венки и счётчики")
	await shot("pol_chronicle.png")
	(hud.journal_panel.find_child("tab_stories", true, false) as Button).pressed.emit()
	await frames(3)
	check(not _labels(hud.journal_panel).contains("Лавровые венки"), "вкладка «Истории горожан» — без венков")
	hud.close_panels()
	check(Chronicle.BADGES.size() >= 25, "венков в летописи: %d" % Chronicle.BADGES.size())


## 6.12 найм «+/−»: меньше работников в одной постройке — места освобождаются, город это видит; сохранение
func _hire_new() -> void:
	print("== найм +/−")
	c.research[String(Defs.B["bakery"].get("unlock", ""))] = true
	var shop := place("bakery", Vector2(154.0, 199.4), Vector2(0.3, -0.12), 16)
	if not check(not shop.is_empty(), "пекарня встала"):
		return
	c.compute()
	var mx := c.job_max(shop)
	var cls := ""
	for k in c.def(shop)["jobs"]:
		cls = String(k)
	var jobs0 := int(c.stats["jobs"][cls])
	check(int(shop.get("hire", -1)) == -1 and c.hired_of(shop) == mx, "по умолчанию — все места (%d), как раньше" % mx)
	c.set_hire(shop, 1)
	check(c.hired_of(shop) == 1 and int(c.stats["jobs"][cls]) == jobs0 - (mx - 1), "1 из %d: мест в городе меньше на %d" % [mx, mx - 1])
	c.set_hire(shop, -5)
	check(c.hired_of(shop) == 0, "не меньше нуля")
	c.set_hire(shop, 99)
	check(c.hired_of(shop) == mx, "не больше мест постройки")
	c.set_hire(shop, 1)
	var d = JSON.parse_string(JSON.stringify(c.save_data()))
	var c2 := City.new(Land.new())
	c2.load_data(d)
	check(c2.hired_of(c2.buildings[int(shop["id"])]) == 1, "сохранение помнит найм")
	hud.open_info(shop)
	await frames(4)
	var txt := _labels(hud.info_panel)
	check(txt.contains("Работники") and txt.contains("1 / %d" % mx), "в карточке пекарни — «Работники 1 / %d»" % mx)
	await shot("pol_hire_card.png")
	hud.close_panels()
	c.set_hire(shop, mx)
	# совет один раз: работников меньше, чем мест (6.12)
	for k in 3:
		place("stall_fruit", Vector2(166.0 + k * 4.0, 199.4), Vector2(0.3, -0.12), 16)
	c.tips.erase("hire_tip")
	c.stats["ratio"] = {"plebs": 0.5, "artisans": 1.0, "patricians": 1.0}
	c.stats["pop"] = 40
	var many := 0
	for id in c.buildings:
		if int(c.jobs_of(c.buildings[id]).get("plebs", 0)) > 0:
			many += 1
	hud.advisor_panel.visible = false
	hud._close_windows()
	hud._once_tips()
	if many >= 3:
		check(hud.advisor_panel.visible and hud.adv_title.text == "Кому работать" and hud.adv_text.text.contains("«−»"), "совет про «−» у работников — один раз: «%s»" % hud.adv_title.text)
	else:
		print("POL NOTE построек с местами плебеев %d — совет не проверяем" % many)
	hud.advisor_panel.visible = false
	c.compute()


## Высота камеры не зависит от частоты кадров (шаги _process вручную)
func _cam_steady() -> void:
	var rig: CameraRig = game.rig
	var ys := {}
	for hz: int in [30, 60, 144]:
		rig.set_view(Vector3(132, Land.BASE_Y, 236), 15, 42, 40)
		for k in hz * 6:
			rig._process(1.0 / float(hz))
		ys[hz] = rig.target.y
	check(absf(float(ys[30]) - float(ys[60])) < 0.01 and absf(float(ys[144]) - float(ys[60])) < 0.01,
		"камера не покачивается: высота цели при 30/60/144 кадрах — %.3f / %.3f / %.3f" % [ys[30], ys[60], ys[144]])


# ---------- город владельца ----------

func _owner() -> void:
	if not FileAccess.file_exists(OWNER):
		print("POL NOTE нет города владельца — пропуск")
		return
	print("== город владельца: %d построек, %d жителей" % [c.buildings.size(), int(c.stats["pop"])])
	var ev_chron := c.events.filter(func(e): return String(e["text"]).begins_with("Летопись города: за прошлые дни"))
	check(Chronicle.count(c) >= 5 and ev_chron.size() == 1 and Chronicle.value(c, "built") > 100,
		"перенос: %d венков разом, одна строка; построено %d, этажей %d, горожан %d" % [Chronicle.count(c), Chronicle.value(c, "built"), Chronicle.value(c, "floors"), Chronicle.value(c, "people")])
	_calm()
	c.tips["chron_tip"] = true
	c.tips["hire_tip"] = true
	await frames(30)
	await _classes_owner()
	await _hire_owner()
	await _photo_owner()
	await _clouds_owner()


## «Обзор → Классы»: кто готов к перестройке, что мешает остальным; «Сносить мешающие украшения»
func _classes_owner() -> void:
	print("== Обзор → Классы")
	hud.set_overlay("classes")
	await frames(10)
	var s: Dictionary = game.cover.sets
	var n: Array = s.get("n", [0, 0, 0])
	var tot := 0
	for id in c.buildings:
		var h: Dictionary = c.buildings[id]
		if c.is_house(h) and int(h["pop"]) > 0 and c.upgrade_to(h) != "" and c.unlocked(c.upgrade_to(h)):
			tot += 1
	check(int(n[0]) + int(n[1]) + int(n[2]) == tot and tot > 0, "все жилые дома ниже домуса подсвечены: %d готовы, %d ждут денариев, %d — мешает (из %d)" % [n[0], n[1], n[2], tot])
	var ready: Array = c.upgrade_ready(false)
	check(int(n[0]) + int(n[1]) == ready.size(), "готовые — те же, что у «Перестроить» (%d)" % ready.size())
	var why: Dictionary = s.get("why", {})
	var kinds := {}
	for id in why:
		kinds[String(why[id][0])] = int(kinds.get(String(why[id][0]), 0)) + 1
	print("POL note помехи: %s" % str(kinds))
	var txt := _labels(hud.overlay_panel)
	check(txt.contains("Классы") and txt.contains("Перестроить (Shift+U)"), "легенда «Классы» с кнопкой «Перестроить»")
	game.rig.set_view(Vector3(205, Land.BASE_Y, 140), 30, 48, 55)
	await frames(30)
	await shot("pol_classes.png")
	var tb: Button = hud.overlay_panel.find_child("classes_tool", true, false)
	if tb:
		tb.pressed.emit()
	check(game.tool == "upgrade" and hud.overlay == "", "кнопка в легенде — инструмент «Перестроить»")
	# снос мешающих украшений: дом, которому мешают одни украшения позади
	var dh := {}
	for id in c.buildings:
		var h: Dictionary = c.buildings[id]
		if c.is_house(h) and int(h["pop"]) > 0 and c.upgrade_to(h) != "" and not c.upgrade_decor_blockers(h).is_empty() and c.can_upgrade(h, false) == c.upgrade_room(h):
			dh = h
			break
	if dh.is_empty():
		print("POL NOTE в городе нет дома, которому мешают одни украшения — снос не проверяем")
	else:
		var dec: Array = c.upgrade_decor_blockers(dh)
		var why_clear := c.can_upgrade_clearing(dh)
		print("POL note дом %d: мешают %d украшений, без них — «%s»" % [int(dh["id"]), dec.size(), why_clear])
		game.upg_decor = false
		game.cover.refresh()
		var in0: bool = (game.cover.sets.get("ready", []) as Array).has(int(dh["id"])) or (game.cover.sets.get("short", []) as Array).has(int(dh["id"]))
		hud.upg_decor_check.button_pressed = true
		check(game.upg_decor and hud.upg_decor_check.visible, "галочка «Сносить мешающие украшения» в панели «Перестроить»")
		var in1: bool = (game.cover.sets.get("ready", []) as Array).has(int(dh["id"])) or (game.cover.sets.get("short", []) as Array).has(int(dh["id"]))
		if why_clear == "":
			check(not in0 and in1, "с галочкой дом с украшениями позади — в готовых")
			game.rig.set_view(Vector3((dh["pos"] as Vector2).x, Land.BASE_Y, (dh["pos"] as Vector2).y), 30, 48, 30)
			await frames(30)
			await shot("pol_upgrade_clearing.png")
			var m0 := c.money
			var price := c.upgrade_price(dh)
			var back := c.upgrade_decor_refund(dh)
			var t0 := String(dh["type"])
			var ok := c.upgrade_clearing(dh)
			var gone := dec.all(func(i): return not c.buildings.has(i))
			check(ok and gone and String(dh["type"]) != t0, "перестроили (%s → %s), украшения снесены" % [t0, dh["type"]])
			check(absf(c.money - (m0 - price + back)) < 0.6, "деньги: −%d за перестройку, +%d за украшения" % [price, back])
		else:
			check(not in1, "без места и с галочкой дом не готов: «%s»" % why_clear)
		hud.upg_decor_check.button_pressed = false
	game.set_tool("")


## 6.12 в живом городе: лавка на одного — её места уходят из города (в лавке работает не больше одного)
func _hire_owner() -> void:
	print("== найм в городе владельца")
	var shop := {}
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		if c.def(b)["kind"] == "shop" and c.job_max(b) >= 3 and bool(b.get("active", false)) and int(b.get("hire", -1)) < 0:
			shop = b
			break
	if not check(not shop.is_empty(), "лавка с 3+ местами"):
		return
	var cls := ""
	for k in c.def(shop)["jobs"]:
		cls = String(k)
	var jobs0 := int(c.stats["jobs"][cls])
	var ratio0 := float(c.stats["ratio"][cls])
	c.set_hire(shop, 1)
	game.people._assign_jobs()
	var inside := 0
	for r in game.people.residents:
		if int(r["job"]) == int(shop["id"]):
			inside += 1
	check(int(c.stats["jobs"][cls]) == jobs0 - (c.job_max(shop) - 1) and float(c.stats["ratio"][cls]) >= ratio0 and inside <= 1,
		"«%s» на одного: мест в городе %d → %d, доля занятых %.2f → %.2f, в лавке работает %d" % [c.def(shop)["name"], jobs0, int(c.stats["jobs"][cls]), ratio0, float(c.stats["ratio"][cls]), inside])
	c.set_hire(shop, c.job_max(shop))
	shop.erase("hire")
	c.compute()


## Фото в живом городе: за жителем (камера близко, сзади), снимок, «Другой житель», выход
func _photo_owner() -> void:
	print("== фото в городе владельца")
	game.rig.set_view(Vector3(205, Land.BASE_Y, 140), 30, 42, 40)
	await frames(60)
	key(KEY_P)
	var ph: PhotoMode = game.photo
	var rid := ph.pick_walker()
	check(ph.on and rid >= 0, "житель на улице для «За жителем»: %d" % rid)
	if rid < 0:
		key(KEY_P)
		return
	ph.btn_follow.pressed.emit()
	await frames(5)
	check(ph.follow_rid >= 0 and game.rig.following() and game.people.focus_rid == ph.follow_rid and ph.btn_follow.text == "Остановиться", "камера идёт за жителем")
	var r: Dictionary = game.people.by_id[ph.follow_rid]
	var outl := false
	if r["node"] != null:
		for mi: MeshInstance3D in (r["node"] as Node).find_children("*", "MeshInstance3D", true, false):
			outl = outl or mi.material_overlay != null
	check(not outl, "без обводки в кадре")
	await frames(150)
	var p: Vector3 = game.people.person_pos(game.people.by_id.get(ph.follow_rid, r))
	var t: Vector3 = game.rig.target
	check(Vector2(p.x - t.x, p.z - t.z).length() < 3.0 and game.rig.dist < 10.0, "камера рядом с жителем (%.1f м, даль %.1f)" % [Vector2(p.x - t.x, p.z - t.z).length(), game.rig.dist])
	ph.sl_time.value = 18.5
	await frames(30)
	var path: String = await ph.snap()
	check(path != "" and FileAccess.file_exists(path), "снимок за жителем: %s" % path)
	if path != "":
		var img := Image.load_from_file(path)
		img.resize(img.get_width() / 2, img.get_height() / 2)
		img.save_png(SHOTS + "pol_photo_follow.png")
	var r0 := ph.follow_rid
	ph.btn_next.pressed.emit()
	await frames(3)
	check((ph.follow_rid >= 0 and ph.follow_rid != r0) or ph.pick_walker() < 0, "«Другой житель» (%d → %d)" % [r0, ph.follow_rid])
	# WASD или правая кнопка — камера больше не идёт следом
	game.rig.stop_follow()
	await frames(2)
	check(ph.follow_rid < 0 and ph.btn_follow.text == "За жителем" and game.people.focus_rid == 0, "камеру сдвинули — следом больше не идём")
	key(KEY_P)
	await frames(5)
	check(not ph.on and hud.root.visible and is_equal_approx(game.look_hour, -1.0), "выход — всё как было")


func _clouds_owner() -> void:
	game.hud.visible = false
	game._set_hour(10.5)
	game.rig.set_view(Vector3(205, Land.BASE_Y, 150), 25, 50, 95)
	await frames(90)
	await shot("pol_clouds_city.png")
	game.clouds.set_enabled(false)
	await frames(20)
	await shot("pol_clouds_city_off.png")
	game.clouds.set_enabled(true)
	game.hud.visible = true


# ---------- камера: высота цели не качается от частоты кадров ----------

func _cam() -> void:
	var rig: CameraRig = game.rig
	var tag: String = "cam"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.trim_prefix("tag=")
	Engine.max_fps = 60
	game.hud.visible = false
	# 1) вид по умолчанию, как в новой игре (game._ready), — 4 секунды при 60 кадрах
	rig.set_view(Vector3(192, Land.BASE_Y, 124), 15, 42, 60)
	await frames(240)
	var g0: float = game.land.height_at(rig.target.x, rig.target.z)
	print("CAM default target %s cam %s ground %.3f" % [str(rig.target), str(rig.cam.global_position), g0])
	await shot("%s_default.png" % tag)
	# 2) место, где земля не на высоте вида: пруд или склон
	var best := Vector2(192, 124)
	var bd := 0.0
	for j in range(80, 240, 4):
		for i in range(120, 260, 4):
			var h: float = game.land.height_at(float(i), float(j))
			if absf(h - Land.BASE_Y) > bd and h > Land.WATER_Y + 0.2:
				bd = absf(h - Land.BASE_Y)
				best = Vector2(i, j)
	rig.set_view(Vector3(best.x, Land.BASE_Y, best.y), 15, 42, 40)
	await frames(240)
	print("CAM slope at %s ground %.3f target %s cam %s" % [str(best), game.land.height_at(best.x, best.y), str(rig.target), str(rig.cam.global_position)])
	await shot("%s_slope.png" % tag)
	# 3) та же цель при разной частоте кадров: шаги _process вручную (без отрисовки) — высота цели должна совпасть
	var ys := {}
	for hz: int in [30, 60, 144]:
		rig.set_view(Vector3(best.x, Land.BASE_Y, best.y), 15, 42, 40)
		var dt := 1.0 / float(hz)
		for k in hz * 6:
			rig._process(dt)
		ys[hz] = rig.target.y
	print("CAM steady target.y by fps: 30 → %.4f, 60 → %.4f, 144 → %.4f" % [ys[30], ys[60], ys[144]])
	if tag != "before":
		check(absf(float(ys[30]) - float(ys[60])) < 0.01 and absf(float(ys[144]) - float(ys[60])) < 0.01,
			"высота цели камеры не зависит от частоты кадров (30/60/144: %.3f / %.3f / %.3f)" % [ys[30], ys[60], ys[144]])
	game.hud.visible = true


# ---------- тени облаков: снимки ----------

func _clouds() -> void:
	var cl: Clouds = game.clouds
	game.hud.visible = false
	game.hud.set_speed(0.0)
	game.rig.set_view(Vector3(192, Land.BASE_Y, 140), 15, 42, 70)
	game._set_hour(11.0)
	await frames(120)
	check(cl != null and cl.enabled and cl.visible and cl.tiles.size() == 9, "облака: 9 плиток, на «Высокой» включены")
	await shot("clouds_on.png")
	cl.set_enabled(false)
	await frames(30)
	await shot("clouds_off.png")
	cl.set_enabled(true)
	game.rig.set_view(Vector3(192, Land.BASE_Y, 150), 25, 55, 130)
	await frames(90)
	await shot("clouds_far.png")
	game.hud.visible = true
