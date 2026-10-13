extends Node
## Автозагрузка «Packs» (первой в списке): собранная игра лежит в нескольких файлах рядом с CivCity.exe,
## чтобы обновления были маленькими. Обычно меняется только код — CivCity.pck (несколько МБ),
## а модели, музыка и рисованный интерфейс лежат отдельно и скачиваются заново, только когда изменились сами:
##   CivCity.pck         — код, сцены, шейдеры (Godot открывает его сам, по имени exe)
##   CivCity_ui.pck      — рисованный интерфейс, шрифты, звуки
##   CivCity_models.pck  — модели и текстуры (Synty, жители, животные, реквизит)
##   CivCity_music.pck   — музыка
## Состав файлов задаёт tools/build_game.sh (группы PACKS там и список EXTRA здесь — одни и те же).
## В редакторе ничего не делает: там все файлы и так на месте.

const EXTRA := ["CivCity_models.pck", "CivCity_music.pck", "CivCity_ui.pck"]

static var missing: Array[String] = []     # каких файлов не нашли (для окна ошибки и проверок)


func _init() -> void:
	if OS.has_feature("editor"):
		return
	var exe := OS.get_executable_path()
	var dir := exe.get_base_dir()
	for p: String in EXTRA:
		var path := dir.path_join(p)
		if not FileAccess.file_exists(path) or not ProjectSettings.load_resource_pack(path, true):
			missing.append(p)
	# Свой файл кода — снова поверх всех: в каждом наборе есть служебные списки (классы скриптов, UID, настройки),
	# главными должны остаться списки из свежего кода. UID моделей и картинок к этому времени уже подхвачены.
	var main_pack := dir.path_join(exe.get_file().get_basename() + ".pck")
	if FileAccess.file_exists(main_pack):
		ProjectSettings.load_resource_pack(main_pack, true)
	if not missing.is_empty():
		push_error("Packs: не найдены файлы игры: " + ", ".join(missing))
		OS.alert("Не хватает файлов игры:\n" + "\n".join(missing) +
			"\n\nЗапустите игру через программу CivCity — она скачает недостающее.", "CivCity")
		if not (missing.size() == 1 and missing[0] == "CivCity_music.pck"):   # без музыки играть можно, без моделей — нет
			(Engine.get_main_loop() as SceneTree).quit(1)
