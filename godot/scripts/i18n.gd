class_name I18n
extends RefCounted
## Языки игры (бета): русский — исходный (все тексты в коде по-русски), английский — словарь res://i18n/en.json
## («русская фраза» → «перевод»). Godot сам переводит тексты надписей и кнопок, если фраза есть в словаре; фразы с
## числами внутри переводятся там, где их собирают: I18n.t("%d жителей") % n. Чего в словаре нет — остаётся по-русски.
## Язык — settings.lang ("ru" | "en"), Настройки → «Язык». Словарь пополняется партиями (.work/i18n, docs/I18N.md).

const LANGS := {"ru": "Русский", "en": "English (beta)"}
static var lang := "ru"
static var _loaded := {}


static func setup(settings: Dictionary) -> void:
	lang = str(settings.get("lang", "ru"))
	if not LANGS.has(lang):
		lang = "ru"
	if lang != "ru" and not _loaded.has(lang):
		_load(lang)
	TranslationServer.set_locale(lang)


static func _load(l: String) -> void:
	var path := "res://i18n/%s.json" % l
	_loaded[l] = true
	if not FileAccess.file_exists(path):
		push_warning("I18n: нет словаря " + path)
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(d) != TYPE_DICTIONARY:
		push_warning("I18n: словарь повреждён " + path)
		return
	var tr := Translation.new()
	tr.locale = l
	for k in d:
		tr.add_message(String(k), String(d[k]))
	TranslationServer.add_translation(tr)


## Перевод фразы (для строк, которые собирают из частей: t("%d жителей") % n); по-русски — как есть
static func t(s: String) -> String:
	if lang == "ru":
		return s
	return String(TranslationServer.translate(s))
