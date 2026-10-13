class_name GamePaths
extends RefCounted
## Где игра хранит сохранения (city.json) и настройки (settings.json):
##  1) --savedir=ПАПКА в командной строке (после «--»);
##  2) переменная окружения CIVCITY_SAVEDIR — её задаёт программа запуска CivCity (папка saves в её данных);
##  3) в редакторе — D:/CivCity/saves (папка saves рядом с проектом, как раньше);
##  4) иначе (игру открыли без программы запуска) — user://saves, то есть %APPDATA%/CivCity Game/saves.

static var _dir := ""


static func save_dir() -> String:
	if _dir != "":
		return _dir
	var d := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--savedir="):
			d = a.trim_prefix("--savedir=").strip_edges()
	if d == "":
		d = OS.get_environment("CIVCITY_SAVEDIR").strip_edges()
	if d == "" and OS.has_feature("editor") and ProjectSettings.globalize_path("res://") != "":
		d = ProjectSettings.globalize_path("res://").path_join("../saves").simplify_path()
	if d == "":
		d = ProjectSettings.globalize_path("user://saves")
	d = d.replace("\\", "/")
	if DirAccess.make_dir_recursive_absolute(d) != OK and not DirAccess.dir_exists_absolute(d):
		push_warning("GamePaths: нельзя писать в «%s» — сохраняем в user://saves" % d)
		d = ProjectSettings.globalize_path("user://saves")
		DirAccess.make_dir_recursive_absolute(d)
	_dir = d
	return _dir
