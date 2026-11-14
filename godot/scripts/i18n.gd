class_name I18n
extends RefCounted
## Языки игры: русский — исходный (все тексты в коде по-русски), английский — словарь res://i18n/en.json
## («русская фраза» → «перевод»). Godot сам переводит тексты надписей, кнопок и подсказок, если фраза есть в словаре;
## фразы, собранные кодом с числами и словами внутри («День %d», «%s: %d жителей»), переводятся по образцу: ключ словаря
## с %d / %s становится шаблоном, под который подходит и готовая строка («День 5» → “Day 5”). Многострочный текст
## переводится по строкам, длинный — по предложениям. Чего в словаре нет — остаётся по-русски.
## Язык — settings.lang ("ru" | "en"): кнопки «RU | EN» в главном меню и в «Настройках». Словарь пополняется
## партиями (docs/I18N.md, .work/night/tools/i18n_*.py).

const LANGS := {"ru": "Русский", "en": "English"}
static var lang := "ru"
static var _tr := {}                    # язык → его Translation (чтобы снять, когда язык выключили)


## Перевод по словарю с образцами. Godot зовёт _get_message для каждой строки надписи — результат запоминаем
class Dict extends Translation:
	var exact := {}
	var buckets := {}                   # первые 3 буквы постоянной части образца → [образец, …]
	var generic := []                   # образцы, что начинаются с подстановки
	var prefixes: Array = []            # «Видеокарта: » — начало строки, к которому код приписал имя (склейка «…» + x)
	var suffixes: Array = []            # « (по видеокарте)» — хвост, приписанный к тексту
	var cache := {}
	var _ph := RegEx.create_from_string("%%|%[-+#0]*\\d*(?:\\.\\d+)?[dsfxXo]|\\{[a-z_0-9]+\\}")      # %d, %s, %.1f, %% и {имя} (подстановки историй)
	var _cyr := RegEx.create_from_string("[А-Яа-яЁё]")

	func fill(d: Dictionary) -> void:
		exact = d
		for k: String in d:
			if k.length() >= 3 and not k.contains("%"):
				var lc := k.substr(k.length() - 1)
				var fc := k.substr(0, 1)
				if (lc == " " or lc == ":" or lc == "«" or lc == "(" or lc == "—" or lc == "·") and has_ru(k):
					prefixes.append(k)
				if (fc == " " or fc == "," or fc == "(" or fc == ")" or fc == "»" or fc == "." or fc == ";" or fc == "—") and has_ru(k):
					suffixes.append(k)
			var parts := _split(k)
			if parts[1] == 0 or (parts[0] as Array).all(func(x): return String(x).strip_edges() == ""):
				continue                  # без подстановок — обычная фраза; одни подстановки («%s») — не образец, подошёл бы любой строке
			var lit0: String = parts[0][0]
			var item := {"src": k, "parts": parts[0], "n": parts[1], "toks": parts[2], "re": null}
			if lit0.length() >= 3:
				var key := lit0.substr(0, 3)
				if not buckets.has(key):
					buckets[key] = []
				(buckets[key] as Array).append(item)
			else:
				generic.append(item)
		prefixes.sort_custom(func(a, b): return a.length() > b.length())
		suffixes.sort_custom(func(a, b): return a.length() > b.length())

	## Ключ → [куски постоянного текста (между подстановками), число подстановок, сами подстановки по порядку]
	func _split(k: String) -> Array:
		var lits: Array = []
		var toks: Array = []
		var n := 0
		var last := 0
		var cur := ""
		for m in _ph.search_all(k):
			var tok := m.get_string()
			cur += k.substr(last, m.get_start() - last)
			last = m.get_end()
			if tok == "%%":
				cur += "%"
			else:
				lits.append(cur)
				toks.append(tok)
				cur = ""
				n += 1
		cur += k.substr(last)
		lits.append(cur)
		return [lits, n, toks]

	func _get_message(src: StringName, _ctx: StringName) -> StringName:
		var s := String(src)
		if cache.has(s):
			return StringName(cache[s])
		var r := lookup(s)
		if cache.size() > 30000:
			cache.clear()
		cache[s] = r
		return StringName(r)

	func has_ru(s: String) -> bool:
		return _cyr.search(s) != null

	## Перевести строку целиком; пусто — нечего переводить
	func lookup(s: String) -> String:
		if s == "" or not has_ru(s):
			return ""
		if exact.has(s):
			return String(exact[s])
		var t := _template(s)
		if t != "":
			return t
		# склейка «Видеокарта: » + имя, текст + « (по видеокарте)»: переводим известную часть, остальное — как есть
		for k: String in prefixes:
			if s.length() > k.length() and s.begins_with(k):
				var rest := s.substr(k.length())
				var rr := lookup(rest) if has_ru(rest) else ""
				return String(exact[k]) + (rr if rr != "" else rest)
		for k: String in suffixes:
			if s.length() > k.length() and s.ends_with(k):
				var head := s.substr(0, s.length() - k.length())
				var hr := lookup(head) if has_ru(head) else ""
				return (hr if hr != "" else head) + String(exact[k])
		if s.contains("\n"):
			var lines := s.split("\n")
			var out: PackedStringArray = []
			var any := false
			for ln in lines:
				var r := lookup(ln)
				if r != "":
					any = true
				out.append(r if r != "" else ln)
			return "\n".join(out) if any else ""
		if s.length() > 50 and s.contains(". "):
			var ps := s.split(". ")
			var out2: PackedStringArray = []
			var any2 := false
			for i in ps.size():
				var piece := ps[i]
				var tail := "." if i < ps.size() - 1 else ""
				var r2 := lookup(piece + tail)
				if r2 == "" and tail != "":
					r2 = lookup(piece)
					if r2 != "":
						r2 += tail
				if r2 != "":
					any2 = true
				out2.append(r2 if r2 != "" else piece + tail)
			return " ".join(out2).replace(". .", ".") if any2 else ""
		return ""

	func _template(s: String) -> String:
		var cands: Array = []
		if s.length() >= 3 and buckets.has(s.substr(0, 3)):
			cands.append_array(buckets[s.substr(0, 3)])
		cands.append_array(generic)
		for it: Dictionary in cands:
			if it["re"] == null:
				var pat := "^"
				var parts: Array = it["parts"]
				for i in parts.size():
					pat += _esc(parts[i])
					if i < parts.size() - 1:
						pat += "(.+?)"
				it["re"] = RegEx.create_from_string("(?s)" + pat + "$")
			var m: RegExMatch = (it["re"] as RegEx).search(s)
			if m == null:
				continue
			var en := String(exact[it["src"]])
			var toks: Array = it["toks"]
			var pct: Array = []                   # номера групп для %-подстановок по порядку
			var named := {}                       # {имя} → номер группы
			for ti in toks.size():
				if String(toks[ti]).begins_with("{"):
					if not named.has(toks[ti]):
						named[toks[ti]] = ti + 1
				else:
					pct.append(ti + 1)
			var out := ""
			var pi := 0
			var last := 0
			var ok := true
			for pm in _ph.search_all(en):
				out += en.substr(last, pm.get_start() - last)
				last = pm.get_end()
				var tok := pm.get_string()
				if tok == "%%":
					out += "%"
					continue
				var gi := -1
				if tok.begins_with("{"):
					gi = int(named.get(tok, -1))
				elif pi < pct.size():
					gi = int(pct[pi])
					pi += 1
				if gi < 0:
					ok = false
					break
				var g := m.get_string(gi)
				var tg := lookup(g) if has_ru(g) else ""
				out += tg if tg != "" else g
			if not ok:
				continue
			return out + en.substr(last)
		return ""

	func _esc(t: String) -> String:
		var o := ""
		for ch in t:
			if "\\^$.|?*+()[]{}".contains(ch):
				o += "\\" + ch
			else:
				o += ch
		return o


static func setup(settings: Dictionary) -> void:
	set_lang(str(settings.get("lang", "ru")))


## Включить язык: английский словарь подключается, русский — отключает все словари (иначе Godot по запасному языку
## «en» продолжал бы переводить, и после «выключили English» интерфейс оставался английским)
static func set_lang(l: String) -> void:
	lang = l if LANGS.has(l) else "ru"
	for k: String in _tr:
		TranslationServer.remove_translation(_tr[k])
	if lang != "ru":
		if not _tr.has(lang):
			_load(lang)
		if _tr.has(lang):
			TranslationServer.add_translation(_tr[lang])
	TranslationServer.set_locale(lang)


static func _load(l: String) -> void:
	var path := "res://i18n/%s.json" % l
	if not FileAccess.file_exists(path):
		push_warning("I18n: нет словаря " + path)
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(d) != TYPE_DICTIONARY:
		push_warning("I18n: словарь повреждён " + path)
		return
	var tr := Dict.new()
	tr.locale = l
	var m := {}
	for k in d:
		m[String(k)] = String(d[k])
	tr.fill(m)
	_tr[l] = tr


## Перевод фразы (для строк, которые собирают из частей: t("%d жителей") % n); по-русски — как есть
static func t(s: String) -> String:
	if lang == "ru":
		return s
	var r := String(TranslationServer.translate(s))
	return r


## Перевод готовой строки (шаблон + числа уже подставлены) — для текстов, что не надписи: окна ОС, файлы, имена
static func tr_text(s: String) -> String:
	return t(s)
