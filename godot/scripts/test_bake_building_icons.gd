extends Node


func _ready() -> void:
	_bake.call_deferred()


func _bake() -> void:
	var out := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=")
	if out == "" or DirAccess.make_dir_recursive_absolute(out) != OK:
		_fail("Нужна папка out=…")
		return
	var game := Game.new()
	var hud := Hud.new()
	hud.game = game
	add_child(hud)
	Synty._index()
	Synty.season_on = true
	var error := await hud._icons_async(out)
	if error != OK:
		game.free()
		_fail("Рендер: %s" % error_string(error))
		return
	var path := out.path_join("v%d.zip" % Hud.ICON_V)
	if FileAccess.file_exists(path):
		game.free()
		_fail("Архив уже существует: " + path)
		return
	var pack := ZIPPacker.new()
	error = pack.open(path)
	var count := 0
	if error == OK:
		for file: String in DirAccess.get_files_at(out):
			if file.get_extension() != "png":
				continue
			error = pack.start_file(file)
			if error == OK:
				error = pack.write_file(FileAccess.get_file_as_bytes(out.path_join(file)))
			if error == OK:
				error = pack.close_file()
			if error != OK:
				break
			count += 1
		var close_error := pack.close()
		if error == OK:
			error = close_error
	hud.queue_free()
	game.free()
	if error != OK or count == 0:
		_fail("Архив: %s, значков %d" % [error_string(error), count])
		return
	print("ICONBAKE DONE %d %s" % [count, path])
	get_tree().quit()


func _fail(reason: String) -> void:
	print("ICONBAKE FAIL ", reason)
	get_tree().quit(1)
