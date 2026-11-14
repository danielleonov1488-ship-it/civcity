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
	var _num := RegEx.create_from_string("^(\\d[\\d,.]*) (.+)$")

	func fill(d0: Dictionary) -> void:
		# многострочный ключ — ещё и по строкам: карточки собирают текст из таких кусков («Счастье домам: +%d%%», «Дальность: %s»…)
		var d := d0.duplicate()
		for k: String in d0:
			var lk := k.lstrip("\n")           # «\nПривязка к дороге (R): » — склейка без перевода строки впереди
			if lk != k and lk != "" and not d.has(lk):
				d[lk] = String(d0[k]).lstrip("\n")
		for k: String in d0:
			if k.contains("\n"):
				var kl := k.split("\n")
				var vl := String(d0[k]).split("\n")
				if kl.size() == vl.size():
					for i in kl.size():
						var a := kl[i].strip_edges()
						if a != "" and has_ru(a) and not d.has(a):
							d[a] = vl[i].strip_edges()
		exact = d.duplicate()
		# ключи с пробелами и переносами по краям («…дальности.\n\n» перед склейкой с другим абзацем) — ещё и без них
		for k: String in d:
			var sk := k.strip_edges()
			if sk != k and sk != "" and not exact.has(sk):
				exact[sk] = String(d[k]).strip_edges()
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
			# слишком «рыхлые» образцы («%s в %s») хватали бы любое предложение с «в» и коверкали его: берём только такие,
			# где постоянного текста достаточно (с числами — любые: число узнаётся по виду)
			var lit_len := 0
			for x in parts[0]:
				lit_len += String(x).strip_edges().length()
			var numeric := true
			for tk in parts[2]:
				if not (String(tk).begins_with("%") and "dfxXo".contains(String(tk).substr(String(tk).length() - 1))):
					numeric = false
			var anchored: bool = String(parts[0][0]).strip_edges() != "" or String(parts[0][(parts[0] as Array).size() - 1]).strip_edges() != ""
			if not numeric and lit_len < (3 if anchored else 10):
				continue
			if numeric and lit_len < 1:
				continue
			var item := {"src": k, "parts": parts[0], "n": parts[1], "toks": parts[2], "re": null, "lit": lit_len}
			if lit0.length() >= 3:
				var key := lit0.substr(0, 3)
				if not buckets.has(key):
					buckets[key] = []
				(buckets[key] as Array).append(item)
			else:
				generic.append(item)
		for bk in buckets:
			(buckets[bk] as Array).sort_custom(func(a, b): return int(a["lit"]) > int(b["lit"]))      # сначала самые точные образцы
		generic.sort_custom(func(a, b): return int(a["lit"]) > int(b["lit"]))
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
		# склейка «Видеокарта: » + имя, текст + « (по видеокарте)»: переводим известную часть, остальное — как есть
		for k: String in prefixes:
			if s.length() > k.length() and s.begins_with(k):
				var rest := s.substr(k.length())
				if not has_ru(rest):
					return String(exact[k]) + rest             # «Видеокарта: » + «NVIDIA GeForce»
				var rr := lookup(rest)
				if rr != "":
					return String(exact[k]) + rr
		for k: String in suffixes:
			if s.length() > k.length() and s.ends_with(k):
				var head := s.substr(0, s.length() - k.length())
				if not has_ru(head):
					return head + String(exact[k])
				var hr := lookup(head)
				if hr != "":
					return hr + String(exact[k])
		# ЗАГЛАВНЫМИ («ДОМУС ПАТРИЦИЕВ» в карточке): переводим обычным регистром и поднимаем результат
		if s == s.to_upper() and s.length() > 2:
			var sl := s.substr(0, 1) + s.substr(1).to_lower()
			var rl := lookup(sl)
			if rl == "":
				rl = lookup(" ".join(Array(s.to_lower().split(" ")).map(func(w): return String(w).capitalize() if String(w).length() > 2 else String(w))))      # «Цирк Фламиния», «Храм Венеры и Ромы»
			if rl != "":
				return rl.to_upper()
		# «Поселение · 0», «День 1 · зима»: части через « · » переводим по отдельности
		if s.contains(" · "):
			var segs := s.split(" · ")
			var outs: PackedStringArray = []
			var anys := false
			for sg in segs:
				var rs := lookup(sg) if has_ru(sg) else ""
				if rs != "":
					anys = true
				outs.append(rs if rs != "" else sg)
			if anys:
				return " · ".join(outs)
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
		# список через запятую: «2 плебеи, 1 ремесленники» — по частям
		if s.contains(", "):
			var ls := s.split(", ")
			var outl: PackedStringArray = []
			var anyl := false
			for pc in ls:
				var rl2 := lookup(pc) if has_ru(pc) else ""
				if rl2 != "":
					anyl = true
				outl.append(rl2 if rl2 != "" else pc)
			if anyl:
				return ", ".join(outl)
		# «3 плебеи»: число и слово
		var nm := _num.search(s)
		if nm != null:
			var wr := lookup(nm.get_string(2))
			if wr != "":
				return nm.get_string(1) + " " + wr
		# слово с маленькой буквы («плебеи», «ремесленники»): ищем с большой и опускаем
		var c0 := s.substr(0, 1)
		if c0 != c0.to_upper() and s.length() > 2:
			var rc := lookup(c0.to_upper() + s.substr(1))
			if rc != "":
				return rc.substr(0, 1).to_lower() + rc.substr(1)
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
						var tk := String((it["toks"] as Array)[i])
						pat += "(-?[\\d\\s\u00a0\u202f,.]+?)" if (tk.begins_with("%") and "dfxXo".contains(tk.substr(tk.length() - 1))) else "(.+?)"
				it["re"] = RegEx.create_from_string(("(?s)" if String(it["src"]).contains("\n") else "") + pat + "$")      # «.» через строки — только у многострочных образцов
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
