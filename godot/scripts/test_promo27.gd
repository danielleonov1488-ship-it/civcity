extends "res://scripts/promo27_cam.gd"
## Кадры начала, середины и конца. Всё игровое действие проходит между ними.

var shot_dir := "D:/CivCity/.work/stage7/promo27/shots"


func _ready() -> void:
	args["clip"] = "fruit_stall"
	args["vertical"] = "1"
	await super._ready()


func _rec_start() -> bool:
	pin_cart = false
	shot_dir = str(args.get("shots", shot_dir))
	if DirAccess.make_dir_recursive_absolute(shot_dir) != OK:
		_fail("папка для кадров")
		return false
	return true


func _post_draw() -> void:
	if state != "rec":
		return
	if rec_i in [0, rec_n / 2, rec_n - 1]:
		var img := get_viewport().get_texture().get_image()
		var file := shot_dir.path_join("test_%s_%04d.png" % [clip_name, rec_i])
		if img.is_empty() or img.save_png(file) != OK:
			_fail("сохранение кадра " + file)
			return
		print("PROMO27 SHOT ", file)
	rec_i += 1
	if rec_i >= rec_n:
		state = "done"
		print("PROMO27 DONE")
		get_tree().quit()
