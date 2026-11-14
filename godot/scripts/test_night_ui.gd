extends Node
## Снимки и проверки упрощённого интерфейса (отзыв 14.11): верхняя полоса, свиток просьб, уведомления, меню стройки,
## «чистый экран», язык. Снимки — в out=ПАПКА (по умолчанию D:/CivCity/.work/night/ui).
##   bash .work/py/gpu_run.sh res://test_night_ui.tscn -- --sandbox mode=hud [lang=en] [size=1280x720] [out=…] [name=…]
## Режимы: hud (песочница, вид по умолчанию), owner (город владельца), tray (меню стройки с выбранной карточкой),
## settings, menu (главное меню), clean (клавиша H), toast (проверка уведомлений, без снимка), lang (RU↔EN без «залипания»).
## В конце «NIGHT DONE fails=0».

const OWNER := "D:/CivCity/.work/owner_save/city.json"

var game
var hud
var A := {}
var fails := 0
var out := "D:/CivCity/.work/night/ui"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		A[kv[0]] = kv[1] if kv.size() > 1 else "1"
	out = str(A.get("out", out))
	DirAccess.make_dir_recursive_absolute(out)
	var mode := str(A.get("mode", "hud"))
	# настройки (язык) — до запуска игры: она читает файл
	var sp := GamePaths.save_dir().path_join("settings.json")
	var st := {}
	if FileAccess.file_exists(sp):
		var d = JSON.parse_string(FileAccess.get_file_as_string(sp))
		if typeof(d) == TYPE_DICTIONARY:
			st = d
	st["lang"] = str(A.get("lang", "ru"))
	if A.has("folded"):
		st["tasks_folded"] = A["folded"] == "1"
	else:
		st.erase("tasks_folded")
	var f := FileAccess.open(sp, FileAccess.WRITE)
	f.store_string(JSON.stringify(st))
	f.close()
	if mode == "owner" and FileAccess.file_exists(OWNER):
		DirAccess.copy_absolute(OWNER, GamePaths.save_dir().path_join("city.json"))
		Game.boot = {"play": "1", "hour": str(A.get("hour", "11"))}
	elif mode == "menu":
		Game.boot = {"menu": "1"}
	else:
		Game.boot = {"new": "1", "hour": str(A.get("hour", "11"))}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, what: String, extra = null) -> bool:
	print(("NIGHT PASS " if ok else "NIGHT FAIL ") + what + ("" if ok or extra == null else "  " + str(extra)))
	if not ok:
		fails += 1
	return ok


func shot(name: String) -> void:
	await frames(12)
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("SHOT ", name, " ", img.get_size())


func key(k: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.physical_keycode = k
		ev.pressed = down
		Input.parse_input_event(ev)
		await frames(2)
	await frames(3)


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	hud = game.hud
	hud.quiet_tips = 1                       # как в настоящей игре: советы второго плана — тихо, в колокольчик
	game.can_save = false
	var sz := str(A.get("size", ""))
	if sz != "":
		var w := sz.split("x")
		get_window().size = Vector2i(int(w[0]), int(w[1]))
		await frames(10)
	await frames(30)
	var nm := str(A.get("name", ""))
	match str(A.get("mode", "hud")):
		"hud":
			hud.refresh()
			await frames(20)
			await _hud_checks()
			await shot(nm if nm != "" else "hud")
		"owner":
			hud.refresh()
			await frames(20)
			await shot(nm if nm != "" else "owner")
		"tray":
			await _tray(nm if nm != "" else "tray")
		"settings":
			hud._toggle(hud.settings_panel)
			hud._open_settings(true)
			await shot(nm if nm != "" else "settings")
		"menu":
			await shot(nm if nm != "" else "menu")
		"clean":
			await key(KEY_H)
			check(hud.clean and not hud.root.visible, "H — интерфейс спрятан")
			await shot(nm if nm != "" else "clean")
			await key(KEY_H)
			check(not hud.clean and hud.root.visible, "H ещё раз — интерфейс вернулся")
		"toast":
			await _toast()
		"lang":
			await _lang()
		"untr":
			await _untr_run()
		"dbg":
			await _dbg()
	print("NIGHT DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _hud_checks() -> void:
	var tp: Rect2 = hud.top_panel.get_global_rect()
	var cb: Rect2 = hud.city_card.get_global_rect()
	var vw: float = hud.root.size.x
	check(cb.end.x <= tp.position.x + 1.0, "верхняя полоса не наезжает на медальоны справа: %s / %s" % [cb, tp])
	check(cb.size.y < 60.0, "верхняя полоса тонкая: высота %.0f" % cb.size.y)
	check(hud.tasks_folded() and hud.tasks_box.find_child("unfold", true, false) != null, "просьбы свёрнуты в значок-свиток")
	check(hud.tasks_panel.get_global_rect().size.x < 90.0, "значок просьб маленький: %s" % hud.tasks_panel.get_global_rect().size)
	var cr: Rect2 = hud.tasks_panel.get_global_rect()
	print("INFO root.w=%.0f bar=%s tasks=%s" % [vw, cb, cr])


func _tray(name: String) -> void:
	var cat: String = str(A.get("cat", Defs.CATS[0][0]))
	hud._toggle_cat(cat)
	await frames(20)
	var list: Array = hud._decor_list() if cat == "decor" else hud._types_in(cat, hud.open_sub if cat == "commerce" else "")
	var last := ""
	for ty in list:
		last = String(ty)
	hud.select_build(last, true)
	await frames(30)
	var sc := hud.tray.find_child("scroll", true, false) as Control
	var tray_r: Rect2 = hud.tray.get_global_rect()
	var tool_r: Rect2 = hud.tool_panel.get_global_rect()
	check(hud.tool_panel.visible and hud.tray.visible, "и свиток, и окно выбранной постройки открыты (%s)" % last)
	check(tray_r.end.x <= tool_r.position.x + 1.0, "окно постройки не закрывает свиток: свиток %s окно %s" % [tray_r, tool_r])
	check(tray_r.position.x >= 0.0, "свиток не уехал за левый край: %s" % tray_r)
	# последняя карточка достижима прокруткой
	var scr := sc as ScrollContainer
	scr.scroll_horizontal = 100000
	await frames(5)
	var lastb: Control = hud.tray_grid.get_child(hud.tray_grid.get_child_count() - 1)
	var vis := lastb.get_global_rect().end.x <= tray_r.end.x + 1.0 and lastb.get_global_rect().end.x <= tool_r.position.x + 1.0
	check(vis, "последняя карточка видна целиком при прокрутке: %s / свиток %s" % [lastb.get_global_rect(), tray_r])
	scr.scroll_horizontal = 0
	await shot(name)


func _toast() -> void:
	var c: City = game.city
	hud.advisor_panel.visible = false
	var n0: int = hud.notes_box.get_child_count()
	c._event("Просьба выполнена: проба (+10 ден.)", "check")
	await frames(5)
	check(hud.notes_box.get_child_count() == n0, "обычное событие — без плашки, только колокольчик (%d)" % hud.bell_count)
	check(hud.bell_count >= 1, "колокольчик посчитал событие: %d" % hud.bell_count)
	c._event("Город теперь — «Хутор»! Открылись новые исследования, казна вмещает 100 ден.", "level")
	await frames(5)
	check(hud.notes_box.get_child_count() == n0 + 1, "новый уровень — плашка")
	await get_tree().create_timer(3.6).timeout
	check(hud.notes_box.get_child_count() == n0, "плашка исчезла за ~3 секунды (%d)" % hud.notes_box.get_child_count())
	c._event("Город теперь — «Хутор»! Открылись новые исследования, казна вмещает 100 ден.", "level")
	await frames(5)
	check(hud.notes_box.get_child_count() == n0, "то же сообщение в те же сутки — плашки нет")
	c._event("Сегодня Сатурналии! Город празднует сутки", "laurels")
	await frames(5)
	check(hud.notes_box.get_child_count() == n0 + 1, "праздник — плашка")
	# советы второго плана — не окном
	hud.advisor_panel.visible = false
	hud.quiet_tips = 1
	hud.advisor("Налоги по классам", "Тест. Подробности.")
	check(not hud.advisor_panel.visible, "совет второго плана («Налоги по классам») — без окна")
	hud.advisor("Казна пуста", "Тест.")
	check(hud.advisor_panel.visible and hud.adv_never.visible, "«Казна пуста» — окном, с «Больше не показывать»")
	hud.adv_never.pressed.emit()
	check(not hud.advisor_panel.visible and not hud.advisor_on(), "«Больше не показывать» — советы выключены")
	hud.advisor("Казна пуста", "Тест.")
	check(not hud.advisor_panel.visible, "после «Больше не показывать» окон нет")
	game.settings["advisor_off"] = false
	# заказов старосты нет
	var sto = game.get("stories")
	check(sto.orders.row_info().is_empty() and not StoryOrders.ENABLED, "«Заказы старосты» отключены")


func _lang() -> void:
	# RU → EN → RU: после «выключили English» интерфейс снова русский
	I18n.set_lang("en")
	hud._fill_events()
	check(I18n.t("Настройки") == "Settings", "EN: «Настройки» → %s" % I18n.t("Настройки"))
	check(I18n.t("День 5") != "День 5", "EN: шаблон «День N» → %s" % I18n.t("День 5"))
	I18n.set_lang("ru")
	check(I18n.t("Настройки") == "Настройки", "RU: «Настройки» — как есть")
	check(String(TranslationServer.translate("Настройки")) == "Настройки", "RU: Godot больше не переводит (запасной язык не держит словарь): %s" % TranslationServer.translate("Настройки"))


## Все видимые надписи интерфейса, которые в английском режиме остались по-русски (текст, кнопки, подсказки)
func _untranslated(tag: String, acc: Dictionary) -> void:
	var cyr := RegEx.create_from_string("[А-Яа-яЁё]")
	var stack: Array = [hud]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			stack.append(ch)
		if not (n is Control) or not (n as Control).is_visible_in_tree():
			continue
		var c: Control = n
		for prop in ["text", "tooltip_text", "placeholder_text"]:
			if not (prop in c):
				continue
			var s := String(c.get(prop))
			if s == "" or cyr.search(s) == null:
				continue
			var tr_s := String(TranslationServer.translate(s))
			if cyr.search(tr_s) != null:
				# по строкам: что осталось по-русски (целиком или в части)
				var left: PackedStringArray = []
				for ln in tr_s.split("\n"):
					if cyr.search(ln) != null:
						left.append(ln)
				if not acc.has(s):
					acc[s] = tag + "] [" + " // ".join(left).left(300)


func _untr_run() -> void:
	var acc := {}
	hud.refresh()
	await frames(20)
	_untranslated("hud", acc)
	# разделы стройки
	for cat in Defs.CATS:
		hud._toggle_cat(String(cat[0]))
		await frames(12)
		_untranslated("tray:" + String(cat[0]), acc)
		var ls: Array = hud._types_in(String(cat[0]), hud.open_sub if String(cat[0]) == "commerce" else "")
		if not ls.is_empty():
			hud.select_build(String(ls[0]), true)
			await frames(10)
			_untranslated("tool:" + String(cat[0]), acc)
			game.set_tool("")
		hud._close_tray()
	for pn in ["research_panel", "finance_panel", "stats_panel", "events_panel", "pause_panel", "settings_panel", "credits_panel"]:
		var panel: Control = hud.get(pn)
		hud._close_windows()
		match pn:
			"research_panel":
				hud._top_action("research")
			"finance_panel":
				hud._top_action("finance")
			"stats_panel":
				hud._top_action("stats")
			"events_panel":
				hud._fill_events()
				hud._toggle(panel)
			"pause_panel":
				hud._top_action("menu")
			"settings_panel":
				hud._open_settings()
			"credits_panel":
				hud.open_credits()
		await frames(12)
		_untranslated(pn, acc)
	hud._close_windows()
	# карточка почтовой станции и дома
	for id in game.city.buildings:
		var b: Dictionary = game.city.buildings[id]
		if String(b.get("type", "")) in ["center", "house_plebs"]:
			hud.open_info(b)
			await frames(12)
			_untranslated("info:" + String(b.get("type", "")), acc)
	hud._hide_info()
	var f := FileAccess.open(out.path_join("untranslated_%s.txt" % str(A.get("name", "x"))), FileAccess.WRITE)
	for s in acc:
		f.store_line("[%s] <= %s" % [acc[s], String(s).replace(char(10), " | ").left(120)])
	f.close()
	print("UNTR count=%d" % acc.size())


## Отладка свитка стройки (проверка macinput): сколько листается вбок
func _dbg() -> void:
	hud._toggle_cat("housing")
	await frames(10)
	await get_tree().create_timer(0.6).timeout
	var sc: ScrollContainer = hud.tray.find_child("scroll", true, false)
	var hs := sc.get_h_scroll_bar()
	print("DBG1 sc.size=%s min=%s tray=%s grid_min=%s hs max=%.0f page=%.0f cards=%d" % [sc.size, sc.custom_minimum_size, hud.tray.size, hud.tray_grid.get_combined_minimum_size(), hs.max_value, hs.page, hud.tray_grid.get_child_count()])
	sc.custom_minimum_size.x = 0
	sc.size.x = 200
	(sc.get_parent() as Control).custom_minimum_size.x = 0
	await frames(3)
	print("DBG2 sc.size=%s min=%s tray=%s grid_min=%s hs max=%.0f page=%.0f vis=%s mode=%d" % [sc.size, sc.custom_minimum_size, hud.tray.size, hud.tray_grid.get_combined_minimum_size(), hs.max_value, hs.page, str(hs.visible), sc.horizontal_scroll_mode])
