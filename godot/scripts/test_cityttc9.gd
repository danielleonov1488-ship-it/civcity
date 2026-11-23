extends Node3D
## CITYTTC9: найм по классам, точное увольнение и четыре снимка городских карточек.

var out := "D:/CivCity/.work/stage7/cityttc9/shots/"
var game: Game
var city: City
var hud: Hud
var fails := 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=").trim_suffix("/") + "/"
	var profile := "D:/CivCity/.work/stage7/cityttc9/profiles/run_%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	if check(DirAccess.make_dir_recursive_absolute(profile) == OK and DirAccess.make_dir_recursive_absolute(out) == OK, "output directories"):
		OS.set_environment("CIVCITY_SAVEDIR", profile)
		OS.set_environment("CIVCITY_NOLOGIN", "1")
		OS.set_environment("CIVCITY_NOMINPAUSE", "1")
		OS.set_environment("CIVCITY_HEROSCREEN", "0")
		GamePaths._dir = ""
		Game.sandbox = false
		Game.boot = {"new": "1", "hour": "11", "nologin": "1"}
		game = (load("res://main.tscn") as PackedScene).instantiate() as Game
		game.can_save = false
		add_child(game)
		await run()
	print("CITYTTC9 DONE fails=", fails)
	get_tree().quit(0 if fails == 0 else 1)


func check(ok: bool, reason: String) -> bool:
	if not ok:
		fails += 1
		print("CITYTTC9 FAIL ", reason)
	return ok


func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func shot(file: String) -> void:
	await frames(10)
	await RenderingServer.frame_post_draw
	var path := out + file
	if check(get_viewport().get_texture().get_image().save_png(path) == OK, "save " + file):
		print("CITYTTC9 SHOT ", path)


func place(type: String, at: Vector2, variant := 0) -> Dictionary:
	var b := city.place(type, at, 0.0, variant, 0, true)
	if check(not b.is_empty(), "fixture " + type):
		var door := city.door_point(b)
		game.land.paint_line(door, Vector2(Land.ROAD_X, door.y), 0.9, Land.Kind.ROAD)
	return b


func add_family(home: Dictionary, family_name: String) -> void:
	var cls := String(city.def(home)["cls"])
	var family := {"name": family_name, "n": 3, "cls": cls, "want": "trees"}
	home["families"].append(family)
	home["pop"] += int(family["n"])
	game.people._make_family(family_name, int(family["n"]), int(home["id"]), city.door_point(home), cls, family)


func open_card(b: Dictionary, distance := 41.0) -> void:
	var pos: Vector2 = b["pos"]
	game.rig.set_view(Vector3(pos.x, float(b["y"]), pos.y), 0, 49, distance)
	game.select_building(b)
	hud.open_info(b)
	await frames(8)


func run() -> void:
	for i in 18000:
		if game.ready_done:
			break
		await get_tree().process_frame
	if not check(game.ready_done, "ready_done timeout"):
		return
	game.settings["autosave"] = false
	game.settings["advisor_off"] = true
	game.settings["tasks_folded"] = true
	game.speed = 0.0
	game.build_anim = false
	game.tutorial.finish()
	game.tutorial.set_process(false)
	game.stories.set_process(false)
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1440, 900)
	I18n.set_lang("ru")
	hud = game.hud
	city = game.city
	city.cozy_v = 1
	city.econ = 1
	city.auto_hire = false
	city.level = 5
	city.money = 100000.0
	for tech: String in ["artisans", "patricians", "floor2", "weaver", "temple"]:
		city.research[tech] = true
	hud.apply_reveal(3)
	hud.close_panels()

	check(not Defs.PROF_ON, "profession icons disabled")
	var textures: Array[PackedByteArray] = []
	for cls: String in Defs.CLASS_ORDER:
		var bust := CityStyle.bust(cls)
		var good := CityStyle.bust(cls, "good")
		var bad := CityStyle.bust(cls, "bad")
		if not check(bust != null and good != null and bad != null, "class portraits " + cls):
			continue
		var pixels := bust.get_image().get_data()
		check(bust.get_size() == Vector2(128, 128) and not textures.has(pixels), "distinct 128px bust " + cls)
		textures.append(pixels)
		check(good.get_image().get_data() != bad.get_image().get_data(), "two moods " + cls)

	var plebs := place("house_pleb", Vector2(177, 136))
	var artisan := place("house_artisan", Vector2(177, 116))
	var patrician := place("house_patrician", Vector2(173, 154), Defs.PAT_TOWN)
	var fruit := place("stall_fruit", Vector2(183, 137))
	var workplace := place("weaver", Vector2(165, 151))
	var shrine := place("temple", Vector2(155, 131))
	if [plebs, artisan, patrician, fruit, workplace, shrine].any(func(b: Dictionary) -> bool: return b.is_empty()):
		return
	plebs["tier"] = 2
	add_family(plebs, "Юлии")
	add_family(plebs, "Ливии")
	add_family(artisan, "Фабии")
	patrician["tier"] = 3
	for family_name: String in ["Корнелии", "Клавдии", "Сервилии", "Валерии", "Эмилии"]:
		add_family(patrician, family_name)
	city.compute()
	for home: Dictionary in [plebs, artisan, patrician]:
		home["happy"] = 68
	check(city.hire(fruit, 1, "plebs") == 1, "staff food source")
	check(city.hire(shrine) == 1, "staff faith source")
	city.changed.emit()
	for i in 6000:
		if hud.icons.has("center") and hud.icons.has("house_pleb") and hud.icons.has("house_patrician") and hud.icons.has("stall_fruit") and hud.icons.has("weaver") and hud.icons.has("temple"):
			break
		await get_tree().process_frame
	check(hud.icons.has("weaver") and hud.icons.has("stall_fruit"), "colored building pictures rendered")
	for cls: String in Defs.CLASS_ORDER:
		var has_class := hud.class_box.find_children("*", "TextureRect", true, false).any(func(icon: TextureRect) -> bool:
			return icon.texture == CityStyle.bust(cls))
		check(has_class, "top bar bust " + cls)

	await open_card(workplace)
	var slots := hud.info_box.find_child("worker_slots", true, false) as GridContainer
	if not check(slots != null and slots.get_child_count() == 2, "workplace grid has two slots"):
		return
	for child: Button in slots.get_children():
		var bust := child.get_node_or_null("WorkerBust") as TextureRect
		check(child.disabled and bust != null and bust.texture == CityStyle.bust("plebs") and bust.modulate.a < 0.5, "empty slot shows faded plebs")
	var add := hud.info_box.find_child("hire_plus_artisans", true, false) as Button
	if not check(add != null and not add.disabled, "artisan has an enabled button for a plebeian job"):
		return
	add.pressed.emit()
	var workers := city.staff_members(workplace)
	if not check(workers.size() == 1 and workers[0]["cls"] == "artisans" and workers[0]["m"]["job_class"] == "plebs", "artisan fills plebeian slot"):
		return
	check(city.hire(workplace, 1, "patricians") == 1, "patrician can take a plebeian job")
	workers = city.staff_members(workplace)
	slots = hud.info_box.find_child("worker_slots", true, false) as GridContainer
	if not check(workers.size() == 2 and slots != null, "both workplace slots filled"):
		return
	for i in workers.size():
		var icon := slots.get_child(i).get_node_or_null("WorkerBust") as TextureRect
		check(icon != null and icon.texture == CityStyle.bust(String(workers[i]["cls"])) and is_equal_approx(icon.modulate.a, 1.0), "slot uses actual worker class")
	check(hud.info_box.find_child("hire_minus", true, false) == null, "no general fire button")
	await shot("workplace.png")
	slots = hud.info_box.find_child("worker_slots", true, false) as GridContainer
	var selected: Dictionary = workers[0]["m"]
	var other: Dictionary = workers[1]["m"]
	(slots.get_child(0) as Button).pressed.emit()
	var confirm := hud.info_box.find_child("FireWorker", true, false) as Button
	if check(confirm != null and city.hired_of(workplace) == 2, "clicking a bust requests confirmation"):
		confirm.pressed.emit()
		check(not selected.has("job") and int(other.get("job", -1)) == int(workplace["id"]) and city.hired_of(workplace) == 1, "only the selected worker was fired")
		check(not city.fire_worker(workplace, selected), "stale confirmation cannot fire another worker")

	await open_card(plebs)
	check_house(plebs, false)
	await shot("house_plebs.png")
	await open_card(patrician)
	check_house(patrician, true)
	await shot("house_patricians.png")

	var station := city.center()
	if not check(not station.is_empty(), "post station exists"):
		return
	city.arrivals.clear()
	city.arrivals.append({"name": "Юнии", "n": 2, "cls": "artisans"})
	await open_card(station, 54.0)
	var waiting := hud.info_box.find_child("StationFamily", true, false) as Button
	check(waiting != null and waiting.icon == CityStyle.bust("artisans"), "station shows family class")
	await shot("station.png")


func check_house(home: Dictionary, overflow: bool) -> void:
	var scroll := hud.info_box.find_child("house_scroll", true, false) as ScrollContainer
	if check(scroll != null and hud.info_panel.size.y <= 600.0 and absf(hud.info_panel.size.x - 340.0) <= 1.0, "340px wide compact house card"):
		var bar := scroll.get_v_scroll_bar()
		check(scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_RESERVE, "house has olive scroll area")
		if overflow:
			check(bar.max_value > bar.page, "large family list overflows into scrolling")
			scroll.scroll_vertical = 80
			check(scroll.scroll_vertical > 0, "house content can be scrolled")
			scroll.scroll_vertical = 0
	var cls := String(city.def(home)["cls"])
	var member := hud.info_box.find_child("FamilyMember*", true, false) as Button
	check(member != null and member.icon == CityStyle.bust(cls, "good"), "family shows class and mood")
	var sources := hud.info_box.find_children("SourcePicture*", "TextureRect", true, false)
	check(not sources.is_empty(), "house shows covering-building pictures")
	for picture: TextureRect in sources:
		var type := String(picture.get_meta("building_type", ""))
		var bonus := picture.get_parent().get_node_or_null("SourceBonus") as Label
		check(hud.icons.has(type) and picture.texture == hud.building_icon(type), "actual building thumbnail " + type)
		check(bonus != null and bonus.text.begins_with("+") and bonus.text.ends_with("%"), "covering bonus shown under picture " + type)
