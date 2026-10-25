extends Node
## Этап 1 (1.1, 1.2, 1.3): графика по видеокарте, уровни, счётчик кадров, F3, сторож кадров.
##   bash .work/py/gpu_run.sh res://test_gfx.tscn   — в конце «GFX DONE fails=0»; снимки — .work/gd/b/gfx_*.png
## Таблица видеокарт (в т. ч. ноутбучные на ступень ниже и встроенная); у тех, кто уже играет, уровень не меняется;
## ручной выбор (quality_user) переживает смену видеокарты; настройки: 4 уровня, «Показывать FPS», видеокарта;
## «Очень низкая» и обратно «Высокая» — всё возвращается; сторож предлагает «Низкую» один раз кнопкой у советника;
## проверка в городе после выбора по видеокарте опускает на ступень и объясняет один раз.

const SHOTS := "D:/CivCity/.work/gd/b/"

var game
var fails := 0


func check(ok: bool, what: String, extra = null) -> bool:
	print(("GFX PASS " if ok else "GFX FAIL ") + what + ("" if ok or extra == null else "  " + str(extra)))
	if not ok:
		fails += 1
	return ok


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	await frames(6)
	DirAccess.make_dir_recursive_absolute(SHOTS)
	get_viewport().get_texture().get_image().save_png(SHOTS + name)
	print("SHOT ", SHOTS + name)


func _ready() -> void:
	_table()
	_decide()
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


## Таблица: название видеокарты → уровень
func _table() -> void:
	var D := RenderingDevice.DEVICE_TYPE_DISCRETE_GPU
	var I := RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU
	var cases := [
		["NVIDIA GeForce RTX 3050 Laptop GPU", D, "low"], ["NVIDIA GeForce RTX 3060", D, "medium"],
		["NVIDIA GeForce RTX 3070 Laptop GPU", D, "medium"], ["NVIDIA GeForce RTX 4080 Laptop GPU", D, "high"],
		["Intel(R) Iris(R) Xe Graphics", I, "verylow"], ["Intel(R) UHD Graphics 620", 0, "verylow"],
		["AMD Radeon(TM) Graphics", I, "verylow"], ["NVIDIA GeForce RTX 3060 Laptop GPU", D, "low"],
		["NVIDIA GeForce GTX 1650", D, "low"], ["NVIDIA GeForce GTX 1060 6GB", D, "low"], ["NVIDIA GeForce MX450", D, "low"],
		["NVIDIA GeForce RTX 2050", D, "low"], ["NVIDIA GeForce RTX 4060 Ti", D, "medium"], ["NVIDIA GeForce RTX 2070 SUPER", D, "high"],
		["NVIDIA GeForce RTX 4090", D, "high"], ["AMD Radeon RX 6500 XT", D, "low"], ["AMD Radeon RX 6600", D, "medium"],
		["AMD Radeon RX 7700 XT", D, "high"], ["AMD Radeon RX 6700M", D, "medium"], ["AMD Radeon RX 580 Series", D, "low"],
		["Intel(R) Arc(TM) A380 Graphics", D, "low"], ["Intel(R) Arc(TM) A770 Graphics", D, "medium"],
		["Microsoft Basic Render Driver", 0, "verylow"], ["Some Unknown GPU 9000", D, "medium"]]
	var bad := []
	for c: Array in cases:
		var got := Gfx.tier_for(c[0], c[1])
		if got != c[2]:
			bad.append("%s → %s (ждали %s)" % [c[0], got, c[2]])
	check(bad.is_empty(), "таблица видеокарт: %d названий, ноутбучные на ступень ниже, встроенная — «Очень низкая»" % cases.size(), bad)


## Кто получает выбор по видеокарте
func _decide() -> void:
	var D := RenderingDevice.DEVICE_TYPE_DISCRETE_GPU
	var st := {"quality": "high"}
	var w := Gfx.decide(st, false, true, "NVIDIA GeForce RTX 3050 Laptop GPU", D)
	check(w and st["quality"] == "low" and st["quality_auto"] == "low" and st["quality_checked"] == false,
		"новая установка (настроек нет): RTX 3050 Laptop — «Низкая», одна проверка в городе впереди", st)
	st = {"quality": "high"}
	w = Gfx.decide(st, true, true, "NVIDIA GeForce RTX 3050 Laptop GPU", D)
	check(w and st["quality"] == "high" and st["quality_auto"] == "kept", "уже играет (quality: high, без quality_auto) — остаётся «Высокая», отмечено kept", st)
	w = Gfx.decide(st, true, true, "Intel(R) UHD Graphics", RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU)
	check(not w and st["quality"] == "high", "kept: другая видеокарта — всё равно ничего не меняем", st)
	st = {"quality": "medium", "quality_auto": "medium", "adapter": "NVIDIA GeForce RTX 3060", "quality_user": true}
	w = Gfx.decide(st, true, true, "NVIDIA GeForce RTX 3050 Laptop GPU", D)
	check(not w and st["quality"] == "medium", "ручной выбор переживает смену видеокарты", st)
	st = {"quality": "medium", "quality_auto": "medium", "adapter": "NVIDIA GeForce RTX 3060"}
	w = Gfx.decide(st, true, true, "NVIDIA GeForce RTX 3050 Laptop GPU", D)
	check(w and st["quality"] == "low" and st["adapter"] == "NVIDIA GeForce RTX 3050 Laptop GPU",
		"выбрано по видеокарте, видеокарта сменилась — выбрано заново", st)
	st = {"quality": "high"}
	w = Gfx.decide(st, false, false, "NVIDIA GeForce RTX 3050 Laptop GPU", D)
	check(not w and st["quality"] == "high" and not st.has("quality_auto"), "автопроверки (без --autoq) — без выбора, как раньше", st)


func _press(b: BaseButton) -> void:
	b.emit_signal("pressed")
	await frames(3)


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(30)
	var gfx: Gfx = game.gfx
	var hud = game.hud
	check(gfx != null and str(game.settings.get("quality_auto", "")) == "kept" and game.settings["quality"] == "high",
		"запуск с файлом настроек: «Высокая» осталась, quality_auto = kept", [game.settings.get("quality"), game.settings.get("quality_auto")])
	var f := FileAccess.get_file_as_string(game.settings_path())
	check(f.contains("\"quality_auto\":\"kept\""), "kept записано в settings.json")
	# окно настроек
	hud._open_settings()
	await frames(5)
	var sp: Control = hud.settings_panel
	var names := []
	for k: String in ["high", "medium", "low", "verylow"]:
		var b: Button = sp.find_child("q_" + k, true, false)
		names.append(b.text if b else "—")
	check(names == ["Высокая", "Средняя", "Низкая", "Очень низкая"], "настройки: четыре уровня графики", names)
	var gl: Label = sp.find_child("gpu_name", true, false)
	check(gl != null and gl.text.contains(RenderingServer.get_video_adapter_name()), "настройки: «Видеокарта: …»", gl.text if gl else "")
	var cb: CheckBox = sp.find_child("show_fps", true, false)
	check(cb != null and not cb.button_pressed and not gfx._fps.visible, "«Показывать FPS» есть и выключен по умолчанию")
	await shot("gfx_settings.png")
	# Очень низкая — и обратно
	await _press(sp.find_child("q_verylow", true, false))
	var vp := get_viewport()
	check(game.settings["quality"] == "verylow" and bool(game.settings.get("quality_user", false)), "«Очень низкая» нажата: выбор игрока (quality_user)")
	check(not game.sun.shadow_enabled and game.people.max_vis == 40 and vp.msaa_3d == Viewport.MSAA_DISABLED and is_equal_approx(vp.scaling_3d_scale, 0.5)
		and not (game.far_forest[0] as Node3D).visible and is_equal_approx(vp.mesh_lod_threshold, 4.0),
		"«Очень низкая»: без теней солнца, 40 прохожих, без MSAA, FSR 0.5, без дальних лесов, LOD раньше",
		[game.sun.shadow_enabled, game.people.max_vis, vp.msaa_3d, vp.scaling_3d_scale])
	await frames(40)
	check(game.people.visible_count <= 40, "лишние прохожие убраны", game.people.visible_count)
	await _press(sp.find_child("q_low", true, false))
	check(game.sun.shadow_enabled and is_equal_approx(game.sun.light_angular_distance, 0.0) and game.people.max_vis == 70
		and is_equal_approx(game.sun.directional_shadow_max_distance, 175.0) and vp.msaa_3d == Viewport.MSAA_DISABLED
		and (game.chunk_nodes.values()[0] as GeometryInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"«Низкая»: резкие тени (без PCSS) до 175 м, без MSAA, 70 прохожих, земля без тени")
	await _press(sp.find_child("q_high", true, false))
	var cast_ok := true
	for m: GeometryInstance3D in game.far_near:
		if m.cast_shadow != int(m.get_meta("cast", m.cast_shadow)):
			cast_ok = false
	check(game.sun.shadow_enabled and is_equal_approx(game.sun.light_angular_distance, 2.2) and game.people.max_vis == 150
		and vp.msaa_3d == Viewport.MSAA_4X and is_equal_approx(vp.scaling_3d_scale, 1.0) and (game.far_forest[0] as Node3D).visible
		and is_equal_approx(vp.mesh_lod_threshold, 1.0) and cast_ok and game.env.sdfgi_enabled
		and (game.chunk_nodes.values()[0] as GeometryInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON,
		"снова «Высокая»: всё вернулось (тени, PCSS, MSAA, масштаб, леса, тени пейзажа, SDFGI)")
	# счётчик кадров
	cb.button_pressed = true
	await frames(45)
	check(gfx._fps.visible and gfx._fps.text.ends_with("FPS") and bool(game.settings.get("show_fps", false)), "«Показывать FPS»: счётчик в углу", gfx._fps.text)
	hud._toggle(sp)
	await shot("gfx_fps.png")
	# F3
	var ev := InputEventKey.new()
	ev.keycode = KEY_F3
	ev.pressed = true
	get_viewport().push_input(ev)
	await frames(10)
	check(gfx._dbg != null and gfx._dbg.visible and gfx._dbg_text.text.contains("видеокарта") and gfx._dbg_text.text.contains(RenderingServer.get_video_adapter_name()),
		"F3: подробности (кадры, видеокарта, вызовы, память, название)")
	await shot("gfx_f3.png")
	gfx._toggle_dbg()
	cb.button_pressed = false
	# сторож кадров: 20 с в среднем меньше 40 кадров на «Высокой» — один совет с кнопкой
	game.settings["quality"] = "high"
	game.settings.erase("tip_q_low")
	game._apply_quality()
	gfx.auto_on = true
	hud.advisor_panel.visible = false            # приветствие советника закрыли — совет сторожа ждёт, пока советник свободен
	gfx._watch_t = 0.0
	gfx._watch_n = 0
	for i in 400:
		gfx._watch_step(0.05)                  # 400 кадров за 20 с — 20 кадров в секунду
	await frames(10)
	check(hud.advisor_panel.visible and hud.adv_skip.visible and hud.adv_skip.text == "Включить «Низкую»" and bool(game.settings.get("tip_q_low", false)),
		"сторож: советник предлагает «Низкую» кнопкой (один раз)", [hud.advisor_panel.visible, hud.adv_skip.text])
	await shot("gfx_watchdog.png")
	await _press(hud.adv_skip)
	check(game.settings["quality"] == "low" and bool(game.settings.get("quality_user", false)) and not hud.advisor_panel.visible and game.people.max_vis == 70,
		"«Включить «Низкую»»: включилась, это выбор игрока")
	hud.advisor("Проверка", "обычный совет")
	check(hud.adv_skip.text == "Пропустить обучение" and not hud.adv_skip.visible, "следующий совет — с прежней кнопкой")
	hud.advisor_panel.visible = false
	for i in 400:
		gfx._watch_step(0.05)
	await frames(10)
	check(not hud.advisor_panel.visible, "второй раз сторож не предлагает")
	# проверка в городе после выбора по видеокарте: медленно — на ступень ниже, объяснение один раз
	game.settings["quality"] = "medium"
	game.settings["quality_auto"] = "medium"
	game.settings["quality_checked"] = false
	game.settings["quality_user"] = false
	game.settings.erase("tip_q_auto")
	game._apply_quality()
	check(gfx._check_due(), "выбрано по видеокарте — проверка в городе впереди")
	gfx._check_n = Gfx.CHECK_SKIP + 1
	gfx._check_t = Gfx.CHECK_SEC
	gfx._check_ms = PackedFloat32Array([14.0, 15.0, 16.0, 13.5, 14.2])
	gfx._check_step(0.0)
	await frames(10)
	check(game.settings["quality"] == "low" and game.settings["quality_auto"] == "low" and bool(game.settings["quality_checked"]) and not gfx._check_due(),
		"проверка: видеокарте нужно > 11 мс — на ступень ниже (Средняя → Низкая), больше не проверяем", [game.settings["quality"], game.settings.get("quality_checked")])
	check(hud.advisor_panel.visible and hud.adv_title.text.contains("видеокарт") and hud.adv_text.text.contains("Низкая"),
		"советник один раз: какой уровень выбран и где поменять", hud.adv_text.text)
	await shot("gfx_auto.png")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(game.settings_path()))
	check(typeof(saved) == TYPE_DICTIONARY and saved.get("quality") == "low" and bool(saved.get("tip_q_auto", false)) and bool(saved.get("tip_q_low", false)),
		"всё записано в settings.json (уровень и флаги советов)", saved)
	game.can_save = false
	print("GFX DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
