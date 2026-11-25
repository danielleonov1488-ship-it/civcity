extends "res://scripts/promo28_cam.gd"
## Проверка ключевых фаз съёмки на настоящей игровой сцене.


func _ready() -> void:
	args["clip"] = "fruit_stall"
	args["vertical"] = "1"
	args["out"] = SHOT_DIR.path_join("unused.mp4")
	await super._ready()


func _rec_start() -> bool:
	if DirAccess.make_dir_recursive_absolute(_test_dir()) != OK:
		_fail("не удалось открыть папку кадров")
		return false
	return true


func _test_dir() -> String:
	return str(args.get("shots", SHOT_DIR))


func _post_draw() -> void:
	if state != "rec":
		return
	if rec_i in [0, rec_n / 4, rec_n / 2, rec_n * 3 / 4, rec_n - 1]:
		var img := get_viewport().get_texture().get_image()
		var file := _test_dir().path_join("test_%s_%04d.png" % [clip_name, rec_i])
		if img.is_empty() or img.save_png(file) != OK:
			_fail("не удалось сохранить " + file)
			return
		print("PROMO28 SHOT ", file)
	rec_i += 1
	if rec_i < rec_n:
		return
	state = "done"
	if clip_name == "cityrise" and not rise.finished():
		_fail("город не дорос до витрины")
		return
	if clip_name == "battle" and fight_peak < 8:
		_fail("в схватке слишком мало бойцов")
		return
	if clip_name == "fruit_stall":
		var panel_scale := get_window().content_scale_factor * hud.tasks_panel.scale.x
		if not is_equal_approx(panel_scale, PHONE_UI_SCALE):
			_fail("масштаб карточек %.2f вместо %.2f" % [panel_scale, PHONE_UI_SCALE])
			return
		if city.buildings.values().filter(func(b: Dictionary) -> bool: return b["type"] == "stall_fruit").size() != 1:
			_fail("лавка не появилась")
			return
	print("PROMO28 DONE")
	get_tree().quit()
