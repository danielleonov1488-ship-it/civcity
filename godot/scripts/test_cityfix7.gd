extends "res://scripts/test_uni6_support.gd"
## Доход при заселении, рисунки нужд, перенос жилья и работы, срок стрелки, отметки заданий.


class ZoneProbe:
	extends Stories
	var goal: Dictionary = {}

	func zone_goals() -> Array:
		return [goal]


func _ready() -> void:
	tag = "CITYFIX7"
	out = "D:/CivCity/.work/stage6/cityfix7/shots/city/"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=").trim_suffix("/") + "/"
	var profile := "D:/CivCity/.work/stage6/cityfix7/profiles/city_%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	if not check(DirAccess.make_dir_recursive_absolute(profile) == OK and DirAccess.make_dir_recursive_absolute(out) == OK, "isolated directories"):
		finish_run()
		return
	OS.set_environment("CIVCITY_SAVEDIR", profile)
	OS.set_environment("CIVCITY_NOLOGIN", "1")
	OS.set_environment("CIVCITY_NOMINPAUSE", "1")
	OS.set_environment("CIVCITY_HEROSCREEN", "0")
	GamePaths._dir = ""
	Game.sandbox = false
	Game.boot = {"new": "1", "nologin": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	game.can_save = false
	add_child(game)
	for i in 18000:
		if game.ready_done:
			break
		await get_tree().process_frame
	if not check(game.ready_done, "ready_done timeout"):
		finish_run()
		return
	city = game.city
	hud = game.hud
	game.speed = 0.0
	game.can_save = false
	game.settings["autosave"] = false
	game.settings["advisor_off"] = false
	game.build_anim = false
	game.tutorial.finish()
	game.stories.set_process(false)
	clear_guidance()
	I18n.set_lang("ru")
	get_window().size = Vector2i(1440, 900)
	await run_fixes()
	finish_run()


func run_fixes() -> void:
	var home := place("house_pleb", Vector2(177, 136))
	if home.is_empty():
		return
	city.sim_day()  # До заселения в истории есть час с одним содержанием пустого дома.
	game.speed = 0.0
	var hour_before := city.clock_h
	var history_before := JSON.stringify(city.hist)
	var money_before := city.money
	if not check(city.settled(int(home["id"]), 4, "Теренции") == 4, "first family settles"):
		return
	var family: Dictionary = home["families"][0]
	game.people._make_family(String(family["name"]), 4, int(home["id"]), city.door_point(home), "plebs", family)
	money_before = city.money  # Награды просьб за заселение уже учтены.
	check(city.projected_net() > 0.0 and hud.lbl_income.text.begins_with("+"), "income is positive immediately, before next hour")
	check(city.clock_h == hour_before and JSON.stringify(city.hist) == history_before and city.money == money_before, "forecast does not advance time or award money")
	await shot("01_first_family_income.png")
	city.level = 2
	city.research["ogorod"] = true
	city.research["temple"] = true
	city.money = 100000.0
	city.compute()
	hud.open_info(home)
	await frames(12)
	check_missing(home)
	check(hud.info_box.find_child("HouseLosses", true, false) != null, "two main happiness losses visible without More")
	await shot("02_missing_food_faith.png")
	var garden := place("ogorod", Vector2(185, 136))
	if garden.is_empty():
		return
	if not check(city.hire(garden) == 1, "hire named gardener"):
		return
	var worker: Dictionary = city.staff_members(garden)[0]["m"]
	var seed := int(worker["sd"])
	var temple := place("temple", Vector2(170, 125))
	if temple.is_empty():
		return
	city.hire(temple, 2)
	city.compute()
	city.changed.emit()
	hud.open_info(home)
	await frames(12)
	check_sources()
	await shot("03_source_pictures.png")
	# Повторное применение темы и часовая пересборка раньше возвращали пустые плашки.
	for i in 3:
		CityStyle.apply(hud.info_panel)
		city.changed.emit()
		await frames(4)
		check_sources()
	await move_checks(home, garden, worker)
	var moved_home: Dictionary = city.buildings.values().filter(func(b: Dictionary) -> bool: return city.is_house(b) and int(b["pop"]) > 0)[0]
	hud.open_info(moved_home)
	await frames(12)
	await shot("04_after_house_move.png")
	var loaded := City.new(Land.new())
	loaded.land.load_changes(city.land.save_changes())
	loaded.load_data(JSON.parse_string(JSON.stringify(city.save_data())) as Dictionary)
	check(loaded.workforce().any(func(w: Dictionary) -> bool: return int(w["m"]["sd"]) == seed and int(w["m"].get("job", -1)) == int(worker.get("job", -1))), "moved worker assignment survives save and load")
	for lang: String in ["ru", "en"]:
		I18n.set_lang(lang)
		for resolution: Vector2i in [Vector2i(1440, 900), Vector2i(1180, 700)]:
			get_window().size = resolution
			hud.open_info(moved_home)
			await frames(15)
			check_card_bounds()
			await shot("05_card_%s_%d.png" % [lang, resolution.y])
	I18n.set_lang("ru")
	get_window().size = Vector2i(1440, 900)
	await arrow_checks()
	await decoration_check(moved_home)


func check_missing(home: Dictionary) -> void:
	var block := hud.info_box.find_child("HouseMissing", true, false) as VBoxContainer
	if not check(block != null, "compact missing block"):
		return
	for need: String in Defs.needs_for(String(city.def(home)["cls"]), city.level):
		if int(home["need_coverage"][need]) >= 100:
			continue
		var row := block.find_child("Missing_" + need, true, false) as Control
		if not check(row != null, "missing need " + need):
			continue
		var picture := row.find_child("SuggestedBuilding", true, false) as TextureRect
		var caption := row.find_child("MissingAction", true, false) as Label
		check(picture != null and picture.texture != null and HouseNeeds.category(Defs.B[picture.get_meta("building_type")]) == need, "fitting building picture " + need)
		check(caption != null and caption.text.contains("поставьте рядом"), "visible nearby action " + need)
	var losses := hud.info_box.find_child("HouseLosses", true, false) as VBoxContainer
	if losses != null:
		check(losses.get_child_count() <= 3, "at most two worst losses plus heading")


func check_sources() -> void:
	var pictures := hud.info_box.find_children("SourcePicture*", "TextureRect", true, false)
	check(pictures.size() >= 2, "food and faith source pictures exist")
	for picture: TextureRect in pictures:
		check(picture.texture != null and picture.is_visible_in_tree() and picture.size.x >= 26.0 and picture.size.y >= 26.0, "source picture has visible size")
		var tile := picture.get_parent() as Control
		var overlay := tile.get_parent().get_child(1) as Button
		check(overlay != null and overlay.get_theme_stylebox("normal") is StyleBoxEmpty and overlay.get_theme_stylebox("pressed") is StyleBoxEmpty, "transparent source action after city styling")
		var bonus := tile.get_child(1) as Label
		check(bonus != null and bonus.visible and bonus.text.begins_with("+") and not bonus.clip_text, "source happiness number visible")


func check_card_bounds() -> void:
	check(hud.info_panel.size.x <= 340.5, "house keeps 340 width")
	check(hud.info_panel.get_global_rect().end.y <= hud.bar_right.get_global_rect().position.y + 1.0, "house above bottom bar")
	var body := hud.info_box.find_child("HouseBody", true, false) as Control
	if body != null:
		for node: Control in body.find_children("*", "Control", true, false):
			check(node.get_global_rect().end.x <= hud.info_panel.get_global_rect().end.x + 1.0, "content fits: " + String(node.name))


func move_checks(home: Dictionary, garden: Dictionary, worker: Dictionary) -> void:
	var old_home := int(home["id"])
	var old_garden := int(garden["id"])
	var before_happy := float(home["happy"])
	check(int(worker.get("job", -1)) == old_garden and city.hired_of(garden) == 1, "job before moving home")
	if not check(game.start_move(home), "start actual house move"):
		return
	# Выбираем законное место обычным размещением, перенос завершается _build_here.
	var target := Vector2.INF
	for dz in [12, 20, 28, -12, -20]:
		var candidate: Vector2 = (home["pos"] as Vector2) + Vector2(0, dz)
		var pl: Dictionary = game.placement("house_pleb", candidate)
		if String(pl.get("err", "")) == "":
			target = candidate
			break
	if not check(target != Vector2.INF, "valid destination for home"):
		game.set_tool("")
		return
	game.hover = target
	game._build_here()
	check(game.moving.is_empty() and city.moving_id == -1, "move completed")
	check(city.hired_of(garden) == 1 and float(garden["staff"]) > 0.0, "garden staff restored immediately after home move")
	check(not hud.world_icons.has(old_garden) or hud.world_icons[old_garden][0] != "no_workers", "no stuck worker badge without rehire or manual refresh")
	var live: Array = game.people.residents.filter(func(r: Dictionary) -> bool: return is_same(r.get("m"), worker))
	check(live.size() == 1 and int(live[0]["home"]) != old_home and int(live[0]["job"]) == old_garden, "street resident linked to moved home and original job")
	if not live.is_empty():
		var moved_home: Dictionary = city.buildings[int(live[0]["home"])]
		check(is_equal_approx(float(moved_home["happy"]), before_happy), "home keeps current happiness")
		check(game.start_move(moved_home), "start move to cancel")
		game.set_tool("")
		check(city.hired_of(garden) == 1 and int(live[0]["job"]) == old_garden, "cancelled home move preserves worker")
	# Проверяем также перенос самого рабочего места и его новый id в записи жителя.
	check(game.start_move(garden), "start workplace move")
	game.set_tool("")
	var new_job := int(worker.get("job", -1))
	check(new_job != old_garden and city.buildings.has(new_job), "workplace job id relinked")
	if city.buildings.has(new_job):
		check(city.hired_of(city.buildings[new_job]) == 1 and not hud.world_icons.has(new_job), "moved workplace staff and badge refreshed")


func arrow_checks() -> void:
	clear_guidance()
	hud.close_panels()
	game.set_tool("")
	var goal := Defs.request("fed6")
	hud._clear(hud.tasks_box)
	hud._fill_tasks_body([goal])
	var click: Button = null
	for row: Node in hud.tasks_box.get_children():
		if row is MarginContainer:
			for node: Node in row.get_children():
				if node is Button:
					click = node as Button
	if not check(click != null, "real quest line"):
		return
	click.pressed.emit()
	await frames(4)
	check(not hud._ptr_shown.is_empty(), "quest click shows pointer")
	var until := int(hud._ptr_shown.get("until", 0))
	check(Hud.PTR_SHOW_MS == 6000 and until <= Time.get_ticks_msec() + 6000, "pointer deadline at most six seconds")
	await shot("06_clicked_quest.png")
	while Time.get_ticks_msec() < until + 500:
		hud.refresh()
		await frames(3)
		check(hud._ptr_shown.is_empty() or int(hud._ptr_shown["until"]) == until, "refresh never extends deadline")
	check(hud._ptr_shown.is_empty() and hud.pointer_target == null and not hud.pointer.visible, "arrow expires on real wall clock")
	# Пересборка выбранного горожанина прокручивает строку, но не запускает стрелку.
	hud.stats_tab = "people"
	hud._open_overview("people")
	if not game.people.residents.is_empty():
		var resident: Dictionary = game.people.residents[0]
		hud.people_guidance = {"fam": resident["fam"], "pn": resident["pn"]}
		for i in 4:
			hud._fill_people()
			await frames(4)
			check(is_instance_valid(hud.people_target) and hud.people_target.is_visible_in_tree(), "selected resident focus is actually visible")
			check(hud._ptr_shown.is_empty() and hud.pointer_target == null, "people focus never resurrects expired arrow")
	await shot("07_arrow_expired.png")


func decoration_check(home: Dictionary) -> void:
	hud.close_panels()
	var bench := place("bench", (home["pos"] as Vector2) + Vector2(5, 0))
	if bench.is_empty():
		return
	var probe := ZoneProbe.new()
	probe.city = city
	probe.hud = hud
	probe.game = game
	probe.goal = {"keys": ["*decor"], "hp": home["pos"], "r": 20.0, "after": -1}
	probe.flash_counted(bench)
	var key := "zok%d" % int(bench["id"])
	check(hud.badges.has(key), "quest marks placed decoration")
	if hud.badges.has(key):
		var badge: MapBadge = hud.badges[key]["n"]
		check(badge.texture == MapBadge.badge_texture("match") and badge.texture != MapBadge.badge_texture("collect"), "quest success uses checkmark, never land purchase hand")
	await shot("08_decoration_checkmark.png")
	probe._flash_clear()
	probe.free()
