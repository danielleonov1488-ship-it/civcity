extends Node3D
## Плашки форта: свежий 720p, смена размера и обновление значений.

const Kit = preload("res://scripts/ui_kit_a.gd")
const Fixture = preload("res://scripts/test_fort_fixture.gd")
var out := "D:/CivCity/.work/stage5/fort6b/shots/"
var fails := 0
var game: Game
var camp: CampUI
var lg: Legion
var saved_clock := -1.0
var saved_lang := "ru"
var reference_rects: Dictionary = {}


func check(ok: bool, reason: String) -> bool:
	if not ok:
		fails += 1
		print("FORT6B FAIL " + reason)
	return ok


func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func shot(file: String) -> void:
	await frames(8)
	await RenderingServer.frame_post_draw
	if check(get_viewport().get_texture().get_image().save_png(out + file) == OK, "save " + file):
		print("FORT6B SHOT " + out + file)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4).trim_suffix("/") + "/"
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1280, 720)
	saved_clock = Legion.clock
	saved_lang = I18n.lang
	Legion.clock = 2000000.0
	I18n.set_lang("ru")
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	game.can_save = false
	add_child(game)
	_run()


func _finish() -> void:
	if is_instance_valid(camp):
		camp.close()
	Legion.clock = saved_clock
	I18n.set_lang(saved_lang)
	print("FORT6B DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _run() -> void:
	var waited := 0
	while not game.ready_done:
		await frames(5)
		waited += 5
		if not check(waited < 18000, "ready_done timeout"):
			_finish()
			return
	game.can_save = false
	game.settings["autosave"] = false
	game.set_process(false)
	if not check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory"):
		_finish()
		return
	await _factory_checks()
	game.city.cozy_v = 1
	game.city.legion_v = 3
	lg = game.city.legion
	lg.flags["camp_open"] = true
	lg.flags["camp_told"] = true
	lg.flags["camp3d_guide"] = 4
	lg.army_tick()
	for entry: Array in [["hq", 3], ["kitchen", 1], ["store", 1], ["treasury", 1]]:
		Fixture.set_level(lg, String(entry[0]), int(entry[1]))
	camp = CampUI.of(game.hud)
	if not check(camp != null, "CampUI attached"):
		_finish()
		return
	camp.open()
	camp.set_process(false)
	if not check(camp.visible, "fort opened"):
		_finish()
		return
	# Два возврата ловят накопление координат после смены масштаба.
	var sizes: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(1920, 1080)]
	for index in sizes.size():
		get_window().size = sizes[index]
		await frames(16)
		check(Vector2i(get_viewport().get_visible_rect().size) == sizes[index], "requested viewport %s" % sizes[index])
		for fresh: bool in [false, true]:
			lg.fort["money"] = 1740.0 if fresh else 2500.0
			lg.rations = lg.ration_cap() if fresh else 28
			lg.glory = 0 if fresh else 3850
			lg.ingots = 0 if fresh else 120
			camp._refresh()
			await frames(4)
			var tag := "%d_%dx%d_%s" % [index, sizes[index].x, sizes[index].y, "fresh" if fresh else "stock"]
			_hud_checks(tag)
			if sizes[index] == Vector2i(1920, 1080):
				_reference_checks(tag)
			await shot(tag + ".png")
	_finish()


func _factory_checks() -> void:
	var holder := Control.new()
	holder.hide()
	add_child(holder)
	var regular := Kit.progress(0.5, 1)
	holder.add_child(regular)
	check(is_equal_approx(regular.custom_minimum_size.y, 20.0), "ordinary progress keeps height 20")
	for maximum: float in [0.0, 25.0]:
		var probe := Kit.res_bar(Kit.resource("rations"), 12, maximum)
		var fill: ProgressBar = probe.get_meta("fill")
		check(is_equal_approx(fill.size.y, 9.0), "thin factory before tree maximum=%s" % maximum)
		holder.add_child(probe)
		await frames(3)
		check(is_equal_approx(fill.size.y, 9.0), "thin factory after tree maximum=%s" % maximum)
		# Проверяем и локальный размер плашки, не только масштаб всего HUD.
		probe.size = Vector2(330, 100)
		await frames(3)
		var number: Label = probe.get_meta("number")
		check(number.position.is_equal_approx(Vector2(102.5, 25)), "number follows enlarged cream")
		check(fill.position.is_equal_approx(Vector2(105, 66.25)) and fill.size.is_equal_approx(Vector2(172.5, 11.25)), "fill follows enlarged cream")
		probe.size = Vector2(264, 80)
		await frames(3)
		check(is_equal_approx(fill.size.y, 9.0), "thin factory after local resize")


func _hud_checks(tag: String) -> void:
	check(camp.resource_bars.size() == 4, tag + " four resources")
	for resource: String in camp.resource_bars:
		var panel: Control = camp.resource_bars[resource]["panel"]
		var number: Label = camp.resource_chips[resource]
		var fill: ProgressBar = camp.resource_bars[resource]["fill"]
		var pill := panel.get_global_rect()
		var drawn_scale := panel.get_global_transform().get_scale().abs()
		var cream := Rect2(pill.position + Vector2(78, 18) * drawn_scale, Vector2(panel.size.x - 112, 46) * drawn_scale)
		var value_rect := number.get_global_rect()
		var fill_rect := fill.get_global_rect()
		var outline := number.get_theme_constant("outline_size")
		check(pill.encloses(value_rect) and pill.encloses(fill_rect), tag + "/" + resource + " contents inside pill")
		check(cream.grow(0.1).encloses(value_rect.grow(outline * drawn_scale.y)), tag + "/" + resource + " outlined number inside cream")
		check(number.vertical_alignment == VERTICAL_ALIGNMENT_CENTER, tag + "/" + resource + " centered number")
		check(cream.grow(0.1).encloses(fill_rect) and fill_rect.position.y >= value_rect.end.y, tag + "/" + resource + " thin fill below number inside cream")
		check(is_equal_approx(fill.size.y, 9.0), tag + "/" + resource + " nine-unit fill after tree entry")
		for state: String in ["background", "fill"]:
			var style := fill.get_theme_stylebox(state) as StyleBoxTexture
			check(style != null and style.get_texture_margin(SIDE_TOP) + style.get_texture_margin(SIDE_BOTTOM) <= fill.size.y, tag + "/" + resource + " fill slices " + state)


func _reference_checks(tag: String) -> void:
	for resource: String in camp.resource_bars:
		var panel: Control = camp.resource_bars[resource]["panel"]
		var number: Label = camp.resource_chips[resource]
		var plus: Control = camp.resource_bars[resource]["plus"]
		var pic := panel.get_child(0).get_child(0) as TextureRect
		check(panel.size == Vector2(264, 80), tag + "/" + resource + " original pill size")
		check(number.position == Vector2(82, 20) and number.size.x == 140 and number.get_theme_font_size("font_size") == 28, tag + "/" + resource + " original number geometry and font")
		check(pic.position == Vector2(2, 4) and pic.size == Vector2(72, 72) and plus.position == Vector2(228, 24), tag + "/" + resource + " original icon and plus")
		for part: Control in [panel, number, plus, pic, camp.resource_bars[resource]["fill"]]:
			var key := resource + "/" + String(part.name)
			if not reference_rects.has(key):
				reference_rects[key] = part.get_global_rect()
			else:
				var previous: Rect2 = reference_rects[key]
				check(previous.is_equal_approx(part.get_global_rect()), tag + "/" + key + " no resize drift")
