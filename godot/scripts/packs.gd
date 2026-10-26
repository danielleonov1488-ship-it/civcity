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
## Музыку лаунчер докачивает уже после «Играть» (desktop/updater.js, fetchLater): без неё игра идёт молча, без окна
## об ошибке, и раз в несколько секунд смотрит, не появился ли файл; появился — подключает, и Sound находит треки.

const EXTRA := ["CivCity_models.pck", "CivCity_music.pck", "CivCity_ui.pck"]
const MUSIC := "CivCity_music.pck"
const MUSIC_POLL := 5.0

static var missing: Array[String] = []     # каких файлов не нашли (для окна ошибки и проверок)
var _music_t := 0.0


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
	if missing.size() == 1 and missing[0] == MUSIC:
		print("Packs: музыки пока нет (лаунчер её докачивает) — играем без неё")   # без музыки играть можно, и без окна
	elif not missing.is_empty():
		push_error("Packs: не найдены файлы игры: " + ", ".join(missing))
		OS.alert("Не хватает файлов игры:\n" + "\n".join(missing) +
			"\n\nЗапустите игру через программу CivCity — она скачает недостающее.", "CivCity")
		if not (missing.size() == 1 and missing[0] == MUSIC):   # без музыки играть можно, без моделей — нет
			(Engine.get_main_loop() as SceneTree).quit(1)


func _ready() -> void:
	set_process(MUSIC in missing)              # в редакторе и с музыкой — ждать нечего


## Музыка докачалась, пока идёт игра (лаунчер кладёт файл целиком, переименованием) — подключить. Свой файл кода —
## снова поверх: в наборе музыки есть и служебные списки (как в _init)
func _process(dt: float) -> void:
	_music_t -= dt
	if _music_t > 0.0:
		return
	_music_t = MUSIC_POLL
	var exe := OS.get_executable_path()
	var path := exe.get_base_dir().path_join(MUSIC)
	if not FileAccess.file_exists(path) or not ProjectSettings.load_resource_pack(path, true):
		return
	var main_pack := exe.get_base_dir().path_join(exe.get_file().get_basename() + ".pck")
	if FileAccess.file_exists(main_pack):
		ProjectSettings.load_resource_pack(main_pack, true)
	missing.erase(MUSIC)
	set_process(false)
	print("Packs: музыка докачалась — подключена")
