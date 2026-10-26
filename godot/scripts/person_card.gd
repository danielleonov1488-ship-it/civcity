class_name PersonCard
extends RefCounted
## Карточка жителя и кошки (этапы 6.3–6.5 плана от 24.10) — в окне карточки построек (Hud.info_panel), справа сверху.
## Тестеры: «нельзя отследить каждого жителя, нажать на него, узнать работу, посмотреть имя, узнать уровень довольства».
## Житель: живой портрет (голова крупно), имя и кем он в семье, семья и дом, работа, «Сейчас» — что делает, счастье
## его дома (что прибавляет и что отнимает) и «Желание» — чего ему больше всего не хватает (так город учит через людей).
## Кнопки: «Следовать» (камера ведёт его), «Дом», «Работа», «Внешность» — причёска и одежда из того, что открыли лавки.
## Кошка: портрет, имя, чья она, что делает; «Следовать», «Погладить» (без звука и без пользы — просто приятно).
## Та же карточка, портрет и «Следовать» — для своего героя (Д11); «Внешность» станет его «Гардеробом».

const W := 420.0                       # ширина карточки
const PORTRAIT := 112                  # сторона портрета
const LIST_MAX := 40                   # «Горожане»: строк в списке не больше

static var _vp: SubViewport            # портрет: свой маленький мир с копией жителя (только пока карточка открыта)
static var _vp_key := ""
static var _who: Node3D                # копия в портрете (житель — Citizen, кошка — узел кошки)
static var _face: Array = []           # [камера, скелет, кость головы, сдвиг, даль]
static var _now: Label                 # «Сейчас: …» — обновляется дважды в секунду
static var _now_key := ""
static var _follow_btn: Button
static var _t := 0.0
static var edit := false               # открыт выбор облика («Внешность»)
static var _edit_rid := 0
static var _ed_scroll := 0               # где прокрутка «Внешности» / «Гардероба» (карточка пересобирается после каждого выбора)


# ---------- карточка ----------

## Заполнить карточку (Hud._fill_info_body): sel — {"r": житель} или {"cat": кошка}. false — показывать некого
static func fill(hud: Hud, box: VBoxContainer, sel: Dictionary) -> bool:
	var ppl: People = hud.game.people
	if ppl == null:
		return false
	box.custom_minimum_size = Vector2(W, 0)
	hud.info_panel.custom_minimum_size = Vector2(W + 40.0, 0)
	if sel.has("cat"):
		var ct: Dictionary = sel["cat"]
		if not ppl.cats.has(ct):
			return false
		_fill_cat(hud, box, ct)
		return true
	var r: Dictionary = ppl.by_id.get(int((sel.get("r", {}) as Dictionary).get("id", -1)), {})
	if r.is_empty():
		return false
	if _edit_rid != int(r["id"]):
		edit = false
		_edit_rid = int(r["id"])
	if r.has("hero"):
		_fill_hero(hud, box, r)                 # свой герой (Д11): своя карточка — Легион, снаряжение, «Гардероб»
		return true
	_fill_person(hud, box, r)
	return true


static func _fill_person(hud: Hud, box: VBoxContainer, r: Dictionary) -> void:
	var ppl: People = hud.game.people
	var c: City = hud.game.city
	var m: Dictionary = r.get("m", {})
	var fam := String(r["fam"])
	var h: Dictionary = c.buildings.get(int(r["home"]), {})
	var cls := String(r["cls"])
	var ms: Array = members_of(ppl, r)
	# шапка: портрет, имя, кто в семье
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 10)
	hdr.add_child(_portrait_box(hud, "p:%d" % int(r["id"]), func(vp: SubViewport): _person_subject(vp, ppl, r)))
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 1)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(hud._wrap(hud._label(People.name_of(r), 24, false, Hud.C_INK, hud.font_title), W - PORTRAIT - 60.0))
	var role := Residents.role(m, ms) if not m.is_empty() else ("ребёнок" if r["child"] else "житель")
	tv.add_child(hud._wrap(hud._label("%s · семья %s" % [_cap(role), StoryDefs.fam_gen(fam)], 15, true, Hud.C_SOFT), W - PORTRAIT - 60.0))
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 4)
	chip.add_child(hud._cls_pic(cls, 26))
	chip.add_child(hud._label(String(Defs.CLASSES[cls]["name"]), 15, true, Hud.C_SOFT))
	tv.add_child(chip)
	hdr.add_child(tv)
	var close := hud._bare("close", "Закрыть", 34, func(): hud._hide_info())    # только карточку (совет и другие окна — как были)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hdr.add_child(close)
	box.add_child(hdr)
	box.add_child(hud._divider(16))
	# семья и дом: щелчок — карточка дома; члены семьи — щелчок переключает карточку на него
	if not h.is_empty():
		var fr := hud._row("family", "Семья %s" % StoryDefs.fam_gen(fam), "%d чел." % ms.size())
		box.add_child(hud._clickable(fr, "Карточка дома: счастье, нужды, кто где живёт", func():
			hud.game.select_building(h)
			hud.open_info(h)))
	elif int(r["home"]) == -2:
		box.add_child(hud._row("family", "Семья %s" % StoryDefs.fam_gen(fam), "уезжает из города", Hud.C_BAD))
	else:
		box.add_child(hud._row("family", "Семья %s" % StoryDefs.fam_gen(fam), "ждёт жилья", Hud.C_BAD))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	for o: Dictionary in _family_people(ppl, r):
		if o == r:
			continue
		var om: Dictionary = o.get("m", {})
		var b := Button.new()
		b.text = "%s — %s" % [String(om.get("pn", "?")).get_slice(" ", 0) if int(om.get("sx", 0)) == 0 else String(om.get("pn", "?")), Residents.role(om, ms)]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_stylebox_override("normal", hud._box_pill(20, 4))
		b.add_theme_stylebox_override("hover", hud._box_pill(20, 4, "g_btn_hover"))
		b.add_theme_stylebox_override("pressed", hud._box_pill(20, 4, "g_btn_on"))
		b.tooltip_text = "Открыть карточку: %s" % People.name_of(o)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(func(): hud.game.select_person({"r": o}))
		flow.add_child(b)
	if flow.get_child_count() > 0:
		box.add_child(flow)
	# работа
	var jb: Dictionary = c.buildings.get(int(r["job"]), {})
	if not jb.is_empty():
		var noun := Residents.job_noun(String(jb["type"]), r["female"])
		var jr := hud._row("hammer", _cap(noun) if noun != "" else "Работает", "«%s»" % String(c.def(jb)["name"]))
		box.add_child(hud._clickable(jr, "Карточка места работы", func():
			hud.game.select_building(jb)
			hud.open_info(jb)))
	else:
		box.add_child(hud._row("hammer", "Работа", _no_job(c, r), Hud.C_SOFT if r["child"] or int(r["home"]) <= 0 else Hud.C_BAD))
	# сейчас
	var nr := hud._row("time", "Сейчас", "")
	_now = nr.get_child(2) as Label
	_now_key = "p:%d" % int(r["id"])
	_now.text = activity(ppl, r)
	_now.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_now.custom_minimum_size = Vector2(230, 0)
	_now.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(nr)
	# счастье его дома: что прибавляет больше всего и что отнимает
	if not h.is_empty():
		var hp := int(h["happy"])
		var hcol := Hud.C_GOOD if hp >= 60 else (Hud.C_GOLD if hp >= 40 else Hud.C_BAD)
		box.add_child(hud._row("happy", "Счастье", ("100%% · запас +%d" % (hp - 100)) if hp > 100 else "%d%%" % hp, hcol))
		var plus := []
		var minus := []
		var parts: Array = h.get("happy_parts", [])
		for i in range(1, parts.size()):
			var p: Array = parts[i]
			if int(p[1]) > 0:
				plus.append(p)
			elif int(p[1]) < 0:
				minus.append(p)
		plus.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
		minus.sort_custom(func(a, b): return int(a[1]) < int(b[1]))
		var lines := []
		for p: Array in plus.slice(0, 2):
			lines.append("%s %s" % [hud._pct(int(p[1])), String(p[0])])
		for p: Array in minus.slice(0, 2):
			lines.append("%s %s" % [hud._pct(int(p[1])), String(p[0])])
		if not lines.is_empty():
			box.add_child(hud._wrap(hud._label("   " + "  ·  ".join(lines), 13, false, Hud.C_SOFT), W))
	# желание — чего не хватает больше всего
	var wl := wish(c, r)
	var wr := HBoxContainer.new()
	wr.add_theme_constant_override("separation", 6)
	wr.add_child(hud._icon("pointing", 24))
	var wt := hud._wrap(hud._label("Желание: " + String(wl[0]), 15, true, Hud.C_GOLD if bool(wl[1]) else Hud.C_GOOD), W - 34.0)
	wr.add_child(wt)
	box.add_child(wr)
	# кнопки
	box.add_child(hud._divider(12))
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 6)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	_follow_btn = _btn(hud, "Следовать", "view", "Камера пойдёт за жителем (WASD, Esc или правая кнопка — перестать)", func(): toggle_follow(hud, {"r": r}))
	_follow_btn.toggle_mode = true
	_follow_btn.set_pressed_no_signal(_following(hud, r))
	btns.add_child(_follow_btn)
	if not h.is_empty():
		btns.add_child(_btn(hud, "Дом", "housing", "Показать его дом", func(): _fly(hud, h)))
	if not jb.is_empty():
		btns.add_child(_btn(hud, "Работа", "hammer", "Показать, где он работает", func(): _fly(hud, jb)))
	if not m.is_empty():
		var eb := _btn(hud, "Внешность", "razor", "Причёска и одежда — из того, что открыли лавки города", func():
			edit = not edit
			_ed_scroll = 0
			hud._fill_info())
		eb.toggle_mode = true
		eb.set_pressed_no_signal(edit)
		btns.add_child(eb)
	box.add_child(btns)
	if edit and not m.is_empty():
		_fill_looks(hud, box, r)


static func _cap(s: String) -> String:
	return s.left(1).to_upper() + s.substr(1) if s != "" else s


static func _btn(hud: Hud, text: String, icon: String, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.icon = hud.ico(icon, 26)
	b.expand_icon = false
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_font_override("font", hud.font_bold)
	b.add_theme_stylebox_override("pressed", hud._box_pill(16, 6, "g_btn_on"))
	b.add_theme_stylebox_override("hover_pressed", hud._box_pill(16, 6, "g_btn_on"))
	b.pressed.connect(cb)
	return b


## Члены семьи (записи) — из дома, по пути в выбранный дом (запись в доме появится, когда первый дойдёт до двери)
## или с площади; не нашли — только он сам
static func _members(c: City, r: Dictionary) -> Array:
	var me: Dictionary = r.get("m", {})
	var fam := String(r["fam"])
	var h: Dictionary = c.buildings.get(int(r["home"]), {})
	if not h.is_empty():
		for f: Dictionary in h.get("families", []):
			if String(f.get("name", "")) == fam and (f.get("m", []) as Array).has(me):
				return f["m"]
	var pf: Dictionary = c.pending.get(fam, {})
	if (pf.get("m", []) as Array).has(me):
		return pf["m"]
	for f: Dictionary in c.arrivals:
		if String(f.get("name", "")) == fam and (f.get("m", []) as Array).has(me):
			return f["m"]
	return [me]


## Члены семьи для карточки и «Горожан»: уезжающие (дом −2) записи уже не имеют — по людям семьи на улице
## (номера жителей идут в порядке записей)
static func members_of(ppl: People, r: Dictionary) -> Array:
	var ms := _members(ppl.city, r)
	if ms.size() > 1 or int(r["home"]) != -2:
		return ms
	var out := ppl.residents.filter(func(x): return x["fam"] == r["fam"] and int(x["home"]) == -2 and x.has("m"))
	if out.size() <= 1:
		return ms
	out.sort_custom(func(a, b): return int(a["id"]) < int(b["id"]))
	return out.map(func(x): return x["m"])


## Люди той же семьи (на улице и дома) — по порядку записей
static func _family_people(ppl: People, r: Dictionary) -> Array:
	var out := ppl.residents.filter(func(x): return x["fam"] == r["fam"] and int(x["home"]) == int(r["home"]))
	var ms := members_of(ppl, r)
	out.sort_custom(func(a, b): return ms.find(a.get("m", {})) < ms.find(b.get("m", {})))
	return out


## Почему без работы
static func _no_job(c: City, r: Dictionary) -> String:
	if r["child"]:
		return "ребёнок — играет у дома"
	if int(r["home"]) == -2:
		return "уезжает из города"
	if int(r["home"]) <= 0:
		return "сначала — дом"
	var cl := String(r["cls"])
	var free := int((c.stats.get("jobs", {}) as Dictionary).get(cl, 0)) - int((c.stats.get("workers", {}) as Dictionary).get(cl, 0))
	if free > 0:
		return "ищет работу"
	var dat := {"plebs": "плебеев", "artisans": "ремесленников", "patricians": "патрициев"}
	return "мест для %s нет" % String(dat.get(cl, "его сословия"))


## Что житель делает сейчас — простыми словами
static func activity(ppl: People, r: Dictionary) -> String:
	var c: City = ppl.city
	if r.has("hero"):
		var hh: Dictionary = c.buildings.get(int(r["home"]), {})
		var where := "в Казармах" if String(hh.get("type", "")) == "barracks" else "на почтовой станции"
		if String(r["state"]) == "home":
			return ("спит " if ppl.game.hour >= 21.5 or ppl.game.hour < 5.0 else "отдыхает ") + where
		if String(r["state"]) == "walk" and String(r["goal"]) == "home":
			return "идёт ночевать " + where
	var bn := func(id) -> String:
		var b: Dictionary = c.buildings.get(int(id), {})
		return ("«%s»" % String(c.def(b)["name"])) if not b.is_empty() else ""
	var d: Dictionary = r["dest"]
	var hr: float = ppl.game.hour
	var night := hr >= 21.5 or hr < 5.0
	match String(r["state"]):
		"home":
			return "спит дома" if night else "дома"
		"work":
			return "работает: %s" % bn.call(r["job"])
		"door":
			var dd: Dictionary = r["door"]
			return "входит в дом" if String(dd.get("then", "")) == "home" else "входит: %s" % bn.call(dd.get("bid", -1))
		"walk":
			match String(r["goal"]):
				"work":
					return "идёт на работу: %s" % bn.call(r["job"])
				"home":
					return "идёт домой"
				"settle":
					return "идёт в новый дом"
				"plaza":
					return "идёт на площадь у станции"
				"leave":
					return "уезжает из города"
				"talk":
					return "идёт поговорить с соседями"
			return _act_text(String(d.get("act", "stroll")), d, bn, true)
		"idle":
			if String(r["goal"]) == "arrived":
				return "ждёт жилья на площади" if int(r["home"]) <= 0 else "осматривается на площади"
			var a := String(r["act"])
			if a == "talk":
				var n := 0
				var fem := false
				for id in (r["conv"] as Dictionary).get("m", []):
					if int(id) != int(r["id"]) and ppl.by_id.has(int(id)):
						n += 1
						fem = bool(ppl.by_id[int(id)]["female"])
				return "болтает с соседями" if n > 1 else ("болтает с соседкой" if fem else "болтает с соседом")
			if a == "":
				return "стоит на улице"
			return _act_text(a, d, bn, false)
	return "гуляет"


static func _act_text(a: String, d: Dictionary, bn: Callable, going: bool) -> String:
	var b := String(bn.call(d.get("bid", -1)))
	match a:
		"shop":
			return ("идёт за покупками: %s" if going else "у прилавка: %s") % b
		"enter", "inside":
			return ("идёт: %s" if going else "внутри: %s") % b
		"watch":
			return ("идёт смотреть: %s" if going else "смотрит: %s") % b if b != "" else ("идёт на праздник" if going else "смотрит игры")
		"sit":
			return "идёт посидеть на скамье" if going else "сидит на скамье"
		"well":
			return "идёт к колодцу" if going else "набирает воду у колодца"
		"drink":
			return "идёт к фонтанчику" if going else "пьёт из фонтанчика"
		"look":
			return "идёт полюбоваться статуей" if going else "любуется статуей"
		"cat":
			return "идёт погладить кошку" if going else "гладит кошку"
		"play":
			return "бежит играть" if going else "играет с детьми"
		"solo", "stroll":
			return "гуляет" if going else "стоит на площади, смотрит по сторонам"
	return "гуляет"


## «Желание»: чего жителю не хватает больше всего — [текст, не хватает ли (true) или всё хорошо (false)]
static func wish(c: City, r: Dictionary) -> Array:
	var h: Dictionary = c.buildings.get(int(r["home"]), {})
	var cls := String(r["cls"])
	if int(r["home"]) == -2:
		return ["уехать туда, где живётся лучше — семья покидает город", true]
	if h.is_empty():
		var ht := String(Defs.CLASSES[cls].get("house", "house_pleb"))
		return ["свой дом — поставьте «%s» у дороги и заселите семью" % String(Defs.B.get(ht, {"name": "Дом"})["name"]), true]
	var pen := Defs.MISSING_PENALTY
	for n: String in h.get("missing", []):
		var shop := _shop_for(c, n)
		if shop != "":
			return ["хочу «%s» поближе (−%d%%)" % [_acc(shop), pen], true]
		return ["не хватает: %s (−%d%%) — откроют исследования" % [String(Defs.NEEDS[n]["name"]).to_lower(), pen], true]
	var worst := []
	for p: Array in h.get("happy_parts", []):
		if int(p[1]) < 0 and (worst.is_empty() or int(p[1]) < int(worst[1])):
			worst = p
	if not worst.is_empty():
		var t := String(worst[0])
		if t == "Теснота":
			return ["тесновато — поменьше домов вплотную, побольше украшений (%s)" % _pct(int(worst[1])), true]
		return ["%s (%s)" % [t.to_lower(), _pct(int(worst[1]))], true]
	if int(h["happy"]) < 100:
		# необязательная нужда, которой нет рядом: «было бы славно…»
		for n: String in Defs.NEED_ORDER:
			if n in Defs.CLASSES[cls]["needs"] or (h.get("needs", {}) as Dictionary).has(n):
				continue
			var shop := _shop_for(c, n)
			if shop != "":
				return ["было бы славно, будь рядом «%s»" % shop, true]
		return ["побольше украшений у дома — клумбы, деревья, фонари", true]
	return ["всем доволен — спасибо, градоначальник!", false]


## Название лавки «кого? что?»: «Фруктовую лавку», «Пекарню», «Сапожника»
static func _acc(nm: String) -> String:
	var who := {"Сапожник": "Сапожника", "Лекарь": "Лекаря", "Парфюмер": "Парфюмера", "Ювелир": "Ювелира",
		"Мастер светильников": "Мастера светильников", "Уличные музыканты": "Уличных музыкантов"}
	if who.has(nm):
		return who[nm]
	var out := []
	for w: String in nm.split(" "):
		if w.ends_with("ая"):
			w = w.left(w.length() - 2) + "ую"
		elif w.ends_with("яя"):
			w = w.left(w.length() - 2) + "юю"
		elif w.length() > 2 and w.ends_with("а"):
			w = w.left(w.length() - 1) + "у"
		elif w.length() > 2 and w.ends_with("я"):
			w = w.left(w.length() - 1) + "ю"
		out.append(w)
	return " ".join(out)


static func _pct(v: int) -> String:
	return ("+%d%%" % v) if v > 0 else (("−%d%%" % -v) if v < 0 else "0%")


## Самая доступная открытая лавка, что закрывает нужду n ("" — ещё не открыта)
static func _shop_for(c: City, n: String) -> String:
	var best := ""
	var bc := INF
	for t in Defs.B:
		var d: Dictionary = Defs.B[t]
		if d["kind"] == "shop" and d.get("sub", "") == n and c.unlocked(t) and float(d["cost"]) < bc:
			bc = float(d["cost"])
			best = String(d["name"])
	return best


# ---------- свой герой (Д11) ----------

## Карточка героя: портрет, имя, «Герой города · первый воин Легиона», что делает, место в отряде и числа, снаряжение
## со Склада оружия, гардероб (сколько открыто, что скоро); «Следовать», «Гардероб» (переодеть тут же), «Изменить»
## (экран «Ваш герой»: имя, пол, наборы)
static func _fill_hero(hud: Hud, box: VBoxContainer, r: Dictionary) -> void:
	var ppl: People = hud.game.people
	var c: City = hud.game.city
	var lg: Legion = c.legion
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 10)
	hdr.add_child(_portrait_box(hud, "h:%s" % Citizen.look_key(Hero.look(c)), func(vp: SubViewport): _person_subject(vp, ppl, r)))
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 1)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(hud._wrap(hud._label(Hero.name_of(c), 24, false, Hud.C_INK, hud.font_title), W - PORTRAIT - 60.0))
	var sub := "Герой города" + (" · первый воин Легиона" if lg.window_open() else "")
	tv.add_child(hud._wrap(hud._label(sub, 15, true, Hud.C_SOFT), W - PORTRAIT - 60.0))
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 4)
	chip.add_child(hud._icon("laurels", 24))
	chip.add_child(hud._label("Ваша римлянка" if Hero.female(c) else "Ваш римлянин", 15, true, Hud.C_GOLD))
	tv.add_child(chip)
	hdr.add_child(tv)
	var close := hud._bare("close", "Закрыть", 34, func(): hud._hide_info())
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hdr.add_child(close)
	box.add_child(hdr)
	box.add_child(hud._divider(16))
	# сейчас
	var nr := hud._row("time", "Сейчас", "")
	_now = nr.get_child(2) as Label
	_now_key = "p:%d" % int(r["id"])
	_now.text = activity(ppl, r)
	_now.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_now.custom_minimum_size = Vector2(230, 0)
	_now.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(nr)
	# Легион: своё место в отряде и числа; ещё не собран — какая история его откроет
	if lg.window_open():
		var hs := lg.hero_stats()
		var lr := hud._row("legion", "Легион", "первое место в отряде · %d ур." % int(hs["level"]))
		box.add_child(hud._clickable(lr, "Окно «Легион»: отряд и походы", func():
			var lu := LegionUi.of(hud)
			if lu != null:
				hud._hide_info()
				lu.open("troops")))
		var sr := HBoxContainer.new()
		sr.add_theme_constant_override("separation", 12)
		sr.alignment = BoxContainer.ALIGNMENT_END
		for e: Array in [["medic", "Здоровье", float(hs["hp"])], ["swords", "Урон за удар", float(hs["atk"])], ["shield", "Броня", float(hs["armor"])]]:
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 3)
			h.tooltip_text = String(e[1])
			h.mouse_filter = Control.MOUSE_FILTER_PASS
			h.add_child(hud._icon(String(e[0]), 20))
			h.add_child(hud._label(hud.fmt(float(e[2])), 15, true))
			sr.add_child(h)
		box.add_child(sr)
	else:
		box.add_child(hud._row("legion", "Легион", "ещё не собран", Hud.C_SOFT))
		box.add_child(hud._wrap(hud._label("   Легион откроет история «%s» — герой пойдёт в бой первым" % Legion.story_title(), 13, false, Hud.C_SOFT), W))
	# снаряжение со Склада оружия
	var kl := lg.hero_kit_level()
	var kit := Hero.kit_of(kl)
	box.add_child(hud._row("shield", "Снаряжение", "", Hud.C_INK))
	box.add_child(hud._wrap(hud._label("   " + String(kit["n"]) + ("" if kl > 0 else " — лучшее даст Склад оружия"), 14, true, Hud.C_INK if kl > 0 else Hud.C_SOFT), W))
	# гардероб
	var wc := Hero.wardrobe_count(c, 1 if Hero.female(c) else 0)
	box.add_child(hud._row("cape", "Гардероб", "открыто %d из %d" % [int(wc[0]), int(wc[1])]))
	var nx := Hero.next_item(c, 1 if Hero.female(c) else 0)
	if not nx.is_empty():
		box.add_child(hud._wrap(hud._label("   Скоро: %s — %s" % [String(nx["n"]), String(nx["why"]).trim_prefix("Откроется: ")], 13, false, Hud.C_SOFT), W))
	# кнопки
	box.add_child(hud._divider(12))
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 6)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	_follow_btn = _btn(hud, "Следовать", "view", "Камера пойдёт за героем (WASD, Esc или правая кнопка — перестать)", func(): toggle_follow(hud, {"r": r}))
	_follow_btn.toggle_mode = true
	_follow_btn.set_pressed_no_signal(_following(hud, r))
	btns.add_child(_follow_btn)
	var eb := _btn(hud, "Гардероб", "cape", "Переодеть героя: плащ, цвета, причёска, венок — из того, что открыто", func():
		edit = not edit
		_ed_scroll = 0
		hud._fill_info())
	eb.name = "wardrobe"
	eb.toggle_mode = true
	eb.set_pressed_no_signal(edit)
	btns.add_child(eb)
	var ch := _btn(hud, "Изменить", "person", "Имя, пол и облик целиком — экран «Ваш герой»", func():
		hud._hide_info()
		hud.game.open_hero_screen("edit"))
	ch.name = "change"
	btns.add_child(ch)
	box.add_child(btns)
	if edit:
		_hero_wardrobe(hud, box, r)


## «Гардероб» героя прямо в карточке: наряд, причёска, борода, волосы, цвета, плащ, венок. Закрытое — серым
## с замочком (почему — в подсказке); выбранное — сразу на герое и на портрете
static func _hero_wardrobe(hud: Hud, box: VBoxContainer, r: Dictionary) -> void:
	var c: City = hud.game.city
	var ppl: People = hud.game.people
	var lk: Dictionary = Hero.look(c).duplicate()
	var fem := Hero.female(c)
	var pan := hud._chip(false, 10.0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pan.add_child(v)
	var apply := func(nl: Dictionary):
		Hero.set_look(c, nl)
		ppl.hero_refresh(true)
		if _who is Citizen:
			(_who as Citizen).apply_look(Hero.look(c).duplicate())
		hud.hero_btn_refresh()
		hud._fill_info()
	var set_k := func(k: String, x):
		var nl := lk.duplicate()
		nl[k] = x
		if k == "main" or (k == "mdl" and String(x) == "SK_Chr_Worker_Male_01"):
			Looks.set_main(nl, String(nl.get("main", "a3283a")))
		apply.call(nl)
	var outfits := Hero.items(c, "mdl", lk).filter(func(e): return bool(e["open"]))
	var oi := 0
	for i in outfits.size():
		if String(outfits[i]["v"]) == String(lk.get("mdl", "")):
			oi = i
	if outfits.size() > 1:
		var orow := _stepper(hud, "Наряд", oi + 1, 1, outfits.size(), "", func(x: int): set_k.call("mdl", outfits[x - 1]["v"]))
		(orow.get_child(2) as Label).text = String(outfits[oi]["n"])     # название наряда, а не номер
		(orow.get_child(2) as Label).custom_minimum_size = Vector2(150, 0)
		v.add_child(orow)
	v.add_child(_stepper(hud, "Причёска", int(lk.get("hair", 1)), 1 if fem else 0, Looks.hair_max(fem), "бритая" if not fem else "", func(x: int): set_k.call("hair", x)))
	if not fem:
		v.add_child(_stepper(hud, "Борода", int(lk.get("beard", 0)), 0, Looks.BEARDS, "нет", func(x: int): set_k.call("beard", x)))
	v.add_child(_item_row(hud, "Волосы", Hero.items(c, "hc", lk), String(lk.get("hc", "A")), func(x): set_k.call("hc", x), HeroScreen.HAIR_COL))
	for e: Array in [["main", "Туника"], ["second", "Тога" if not fem else "Нижняя туника"], ["trim", "Кайма"], ["cape", "Плащ"]]:
		var its := Hero.items(c, String(e[0]), lk)
		if its.is_empty():
			continue
		var k := String(e[0])
		v.add_child(_item_row(hud, String(e[1]), its, String(lk.get(k, "")), func(x): set_k.call(k, x), {}))
	var crowns := Hero.items(c, "crown", lk)
	var cr_open := crowns.filter(func(e): return bool(e["open"]))
	if cr_open.size() > 1:
		v.add_child(_stepper(hud, "Венок", int(lk.get("crown", 1)), 1, cr_open.size(), "", func(x: int): set_k.call("crown", x)))
	else:
		var why := String(crowns[1]["why"]) if crowns.size() > 1 else ""
		v.add_child(hud._wrap(hud._label("Венок: лавровый. «Венок победителя» — %s" % why.trim_prefix("Откроется: "), 13, false, Hud.C_SOFT), W - 40.0))
	_scrolled(hud, box, pan)                  # в прокрутку — когда строки уже внутри: высота сразу настоящая


## «Внешность» и «Гардероб» — в прокрутке: карточка не ниже верха нижних полос (проверка 26.10: с открытым гардеробом
## карточка героя закрывала «Этаж», «Перестроить», «Копию» и казну); прокрутка остаётся, где была, после каждого выбора
static func _scrolled(hud: Hud, box: VBoxContainer, pan: Control) -> void:
	var sc := ScrollContainer.new()
	sc.name = "editor_scroll"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(pan)
	box.add_child(sc)
	hud._fit_house_scroll(sc, pan)
	# прокрутка — на прежнее место ещё до первой отрисовки: всякий раз, как раскладка меняет длину полосы
	# (первая — ещё пустая), пока окно не устоится (_scroll_later)
	var keep := func(): sc.scroll_vertical = _ed_scroll
	sc.get_v_scroll_bar().changed.connect(keep)
	_scroll_later(hud, sc, pan, keep)


## Через кадр (перенос строк посчитан) — высота по настоящей; прокрутку ставим и в этом кадре, и в следующем
## (как карточка дома): после выбора в гардеробе список не прыгает наверх
static func _scroll_later(hud: Hud, sc: ScrollContainer, pan: Control, keep: Callable) -> void:
	await hud.get_tree().process_frame
	if not is_instance_valid(sc) or not is_instance_valid(pan):
		return
	hud._fit_house_scroll(sc, pan)
	hud._snug(hud.info_panel)
	sc.scroll_vertical = _ed_scroll
	await hud.get_tree().process_frame
	if not is_instance_valid(sc):
		return
	sc.scroll_vertical = _ed_scroll
	sc.get_v_scroll_bar().changed.disconnect(keep)
	sc.get_v_scroll_bar().value_changed.connect(func(x: float): _ed_scroll = int(x))


## Открыт выбор облика этого жителя (героя): карточку не пересобирают каждый игровой час — иначе прокрутка мигает
static func editing(sel: Dictionary) -> bool:
	return edit and sel.has("r") and int((sel["r"] as Dictionary).get("id", -1)) == _edit_rid


## Ряд вещей-цветов: открытые — щёлкнуть, закрытые — серые с замочком (почему — в подсказке)
static func _item_row(hud: Hud, title: String, its: Array, cur: String, cb: Callable, cols: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var l := hud._label(title, 16, true)
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for e: Dictionary in its:
		var val = e["v"]
		var col: Color = cols.get(val, Color(String(val)) if String(val).is_valid_html_color() else Color.GRAY)
		var ok := bool(e["open"])
		var b := Button.new()
		b.custom_minimum_size = Vector2(26, 26)
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if ok else Control.CURSOR_FORBIDDEN
		b.tooltip_text = String(e["n"]) + ("" if ok else "\n" + String(e["why"]))
		var sb := StyleBoxFlat.new()
		sb.bg_color = col if ok else col.lerp(Color("9a8f80"), 0.6)
		sb.set_corner_radius_all(13)
		var on := str(val).to_lower() == cur.to_lower()
		sb.set_border_width_all(3 if on else 1)
		sb.border_color = Color("fff3c4") if on else Color("5a4128")
		b.add_theme_stylebox_override("normal", sb)
		var sh := sb.duplicate() as StyleBoxFlat
		sh.border_color = Color("ffe08a")
		sh.set_border_width_all(3)
		b.add_theme_stylebox_override("hover", sh)
		b.add_theme_stylebox_override("pressed", sh)
		if ok:
			b.pressed.connect(func(): cb.call(val))
		else:
			var li := TextureRect.new()
			li.texture = hud.ico("lock", 32)
			li.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			li.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			li.set_anchors_preset(Control.PRESET_FULL_RECT)
			li.offset_left = 6
			li.offset_top = 6
			li.offset_right = -6
			li.offset_bottom = -6
			li.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(li)
		flow.add_child(b)
	row.add_child(flow)
	return row


# ---------- кошка ----------

static func _fill_cat(hud: Hud, box: VBoxContainer, ct: Dictionary) -> void:
	var ppl: People = hud.game.people
	var c: City = hud.game.city
	var nm := People.cat_name(ct)
	var h: Dictionary = c.buildings.get(int(ct.get("home", -1)), {})
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 10)
	# портрет — в надетой вещице (сменили вещь — портрет новый)
	hdr.add_child(_portrait_box(hud, "c:%d:%s" % [ct.get("n").get_instance_id(), String(People.cat_rec(ct).get("wr", ""))], func(vp: SubViewport): _cat_subject(vp, ct)))
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(hud._label(String(nm[0]), 26, false, Hud.C_INK, hud.font_title))
	var whose := "%s без дома" % _cap(String(nm[1]))
	if not h.is_empty():
		var fs: Array = h.get("families", [])
		whose = ("%s семьи %s" % [_cap(String(nm[1])), StoryDefs.fam_gen(String(fs[0]["name"]))]) if not fs.is_empty() else "%s у «%s»" % [_cap(String(nm[1])), String(c.def(h)["name"])]
	tv.add_child(hud._wrap(hud._label(whose, 16, true, Hud.C_SOFT), W - PORTRAIT - 60.0))
	if ct.has("named"):
		tv.add_child(hud._wrap(hud._label("Из истории горожан", 14, false, Hud.C_GOLD), W - PORTRAIT - 60.0))
	hdr.add_child(tv)
	var close := hud._bare("close", "Закрыть", 34, func(): hud._hide_info())    # только карточку
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hdr.add_child(close)
	box.add_child(hdr)
	box.add_child(hud._divider(16))
	var nr := hud._row("time", "Сейчас", "")
	_now = nr.get_child(2) as Label
	_now_key = "c:%d" % ct.get("n").get_instance_id()
	_now.text = cat_activity(ppl, ct)
	_now.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_now.custom_minimum_size = Vector2(240, 0)
	_now.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(nr)
	# вещицы из «Кошачьей лавки» (Д14): что у неё есть и что можно выбрать ей самим
	var rec := People.cat_rec(ct)
	if not rec.is_empty():
		box.add_child(hud._divider(10))
		_cat_items(hud, box, rec)
	box.add_child(hud._divider(12))
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 6)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	_follow_btn = _btn(hud, "Следовать", "view", "Камера пойдёт за кошкой (WASD, Esc или правая кнопка — перестать)", func(): toggle_follow(hud, {"cat": ct}))
	_follow_btn.toggle_mode = true
	_follow_btn.set_pressed_no_signal(hud.game.rig != null and hud.game.rig.following() and is_same(ppl.focus_cat, ct))
	btns.add_child(_follow_btn)
	btns.add_child(_btn(hud, "Погладить", "cat", "Погладить — ей приятно", func():
		ppl.pet_now(ct)
		pet_view(hud, ct)))
	if not h.is_empty():
		btns.add_child(_btn(hud, "Дом", "housing", "Показать, где она живёт", func(): _fly(hud, h)))
	box.add_child(btns)


## Что кошка делает: «спит у двери», «её гладит Луций»
static func cat_activity(ppl: People, ct: Dictionary) -> String:
	var her := int(ct.get("sx", 1)) == 1
	match String(ct.get("state", "sit")):
		"walk":
			return "гуляет по улице"
		"sleep":
			return "спит у двери, свернувшись клубком" if _near_home(ppl, ct) else "спит на солнышке"
		"pet":
			var rid := int(ct.get("pet", 0))
			if rid > 0 and ppl.by_id.has(rid):
				return "%s гладит %s" % ["её" if her else "его", People.name_of(ppl.by_id[rid])]
			return "мурлычет — %s гладят" % ("её" if her else "его")
	return "сидит у двери" if _near_home(ppl, ct) else "сидит, смотрит на прохожих"


## «Погладить»: камера близко к кошке — с той стороны, откуда её видно (у двери — со стороны двери, чуть наискосок),
## а не в стену дома; поворот — ближний к нынешнему (без долгого разворота)
static func pet_view(hud: Hud, ct: Dictionary) -> void:
	var rig = hud.game.rig
	var ppl: People = hud.game.people
	if rig == null or ppl == null:
		return
	var p: Vector3 = ppl.cat_pos(ct)
	rig.fly_to(p)
	rig._dist_t = minf(rig._dist_t, 12.0)
	var y0: float = rig._yaw_t
	var yaws := []
	var c: City = hud.game.city
	var h: Dictionary = c.buildings.get(int(ct.get("home", -1)), {})
	if not h.is_empty() and _near_home(ppl, ct):
		var dir: Vector2 = c.door_point(h) - (h["pos"] as Vector2)
		if dir.length() > 0.1:
			var ty := atan2(dir.x, dir.y)
			var a := y0 + wrapf(ty + 0.4 - y0, -PI, PI)
			var b := y0 + wrapf(ty - 0.4 - y0, -PI, PI)
			yaws.append_array([a, b] if absf(a - y0) <= absf(b - y0) else [b, a])
	yaws.append_array([y0, y0 + PI / 2.0, y0 - PI / 2.0, y0 + PI])
	var d: float = rig._dist_t * CameraRig.K
	var pt: float = rig._pitch_t
	var t := Vector3(p.x, maxf(1.0, p.y), p.z)
	var look := p + Vector3(0, 0.2, 0)
	for y: float in yaws:
		var cpos := t + Vector3(sin(y) * cos(pt), sin(pt), cos(y) * cos(pt)) * d
		if not hud.game.view_blocked(cpos, look):
			rig._yaw_t = y
			return
	rig._yaw_t = float(yaws[0])


static func _near_home(ppl: People, ct: Dictionary) -> bool:
	var h: Dictionary = ppl.city.buildings.get(int(ct.get("home", -1)), {})
	return not h.is_empty() and (ct["p"] as Vector2).distance_to(ppl.city.door_point(h)) < 2.5


# ---------- вещицы кошки из «Кошачьей лавки» (Д14) ----------

## Цвет вещицы — кружок на её кнопке
const ITEM_COL := {"bow": Color("f07fa6"), "wreath": Color("5c9a3a"), "pileus": Color("c8432f"), "petasos": Color("e2bd62"),
	"flower": Color("ffd6e2"), "collar": Color("b8322a"), "bandana": Color("3d74c4"), "bowtie": Color("c22f4a"), "cape": Color("b52a2a")}
static var _dots := {}


static func _dot(item: String) -> Texture2D:
	if _dots.has(item):
		return _dots[item]
	var n := 18
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var col: Color = ITEM_COL.get(item, Color("c9a46a"))
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length()
			if d <= n * 0.5 - 0.5:
				img.set_pixel(x, y, Color("3a2412") if d > n * 0.5 - 2.2 else col)
	var t := ImageTexture.create_from_image(img)
	_dots[item] = t
	return t


## Карточка кошки: её вещи (надетая подсвечена; щелчок — надеть или снять) и что можно выбрать ей в лавке
static func _cat_items(hud: Hud, box: VBoxContainer, rec: Dictionary) -> void:
	var c: City = hud.game.city
	var it: Array = rec.get("it", [])
	var wr := String(rec.get("wr", ""))
	box.add_child(hud._label("Вещи · %d" % it.size() if not it.is_empty() else "Вещи", 16, true, Hud.C_SOFT))
	if it.is_empty():
		box.add_child(hud._wrap(hud._label("Пока без обновок: их покупают хозяева в «Кошачьей лавке»", 14, false, Hud.C_SOFT), W - 20.0))
	else:
		var fl := HFlowContainer.new()
		fl.add_theme_constant_override("h_separation", 6)
		fl.add_theme_constant_override("v_separation", 6)
		for x in Defs.CAT_ITEM_ORDER:
			if not it.has(x):
				continue
			var item := String(x)
			var bt := Button.new()
			bt.focus_mode = Control.FOCUS_NONE
			bt.toggle_mode = true
			bt.text = String(Defs.CAT_ITEMS[item]["name"])
			bt.icon = _dot(item)
			bt.set_pressed_no_signal(item == wr)
			bt.tooltip_text = "Снять" if item == wr else "Надеть"
			bt.pressed.connect(func():
				c.wear_cat_item(rec, "" if String(rec.get("wr", "")) == item else item)
				hud._fill_info())
			fl.add_child(bt)
		box.add_child(fl)
	# лавка: что ещё можно выбрать кошке (за денарии города)
	var left: Array = Defs.CAT_ITEM_ORDER.filter(func(x): return not it.has(x))
	if left.is_empty():
		return
	if not c.cat_shop_open():
		for id in c.buildings:
			var sb: Dictionary = c.buildings[id]
			if String(sb["type"]) == "catshop":
				# лавка есть, но стоит — почему (а не «постройте» вторую)
				box.add_child(hud._wrap(hud._label("«Кошачья лавка» пока не работает: %s" % c.idle_text(sb), 13, false, Hud.C_SOFT), W - 20.0))
				return
		var why := "Постройте «Кошачью лавку» — там можно выбрать кошке шляпку, бантик или ошейник с колокольчиком" if c.unlocked("catshop") \
			else "Шляпки и бантики продаёт «Кошачья лавка» — её откроет исследование «%s»" % Defs.research("catshop")["name"]
		box.add_child(hud._wrap(hud._label(why, 13, false, Hud.C_SOFT), W - 20.0))
		return
	box.add_child(hud._label("Выбрать в «Кошачьей лавке»", 15, true, Hud.C_SOFT))
	var sf := HFlowContainer.new()
	sf.add_theme_constant_override("h_separation", 6)
	sf.add_theme_constant_override("v_separation", 6)
	for x in left:
		var item := String(x)
		var price := int(Defs.CAT_ITEMS[item]["price"])
		var bt := Button.new()
		bt.focus_mode = Control.FOCUS_NONE
		bt.text = "%s · %d ден." % [String(Defs.CAT_ITEMS[item]["name"]), price]
		bt.icon = _dot(item)
		bt.disabled = c.money < float(price)
		bt.tooltip_text = "Не хватает денариев" if bt.disabled else "Купить и сразу надеть"
		bt.pressed.connect(func():
			if c.buy_cat_item(rec, item):
				if hud.game.sound:
					hud.game.sound.ui("coins")
				hud._fill_info())
		sf.add_child(bt)
	box.add_child(sf)


## Портрет кошки «Кошачьей лавки» (её карточка): кошка окраса fur в вещице item
static func shop_cat_subject(vp: SubViewport, fur: int, item: String) -> void:
	var cn := People.cat_node(fur, "Pet", 11)
	People.cat_wear(cn, item)
	cn.name = "who"
	cn.rotation.y = 0.35
	vp.add_child(cn)
	_who = cn
	var sk = null
	var bone := -1
	var sks := cn.find_children("*", "Skeleton3D", true, false)
	if not sks.is_empty():
		sk = sks[0]
		bone = (sk as Skeleton3D).find_bone("Bone.003")
	_face = [vp.get_node("cam"), sk, bone, Vector3(0, 0.06, 0.03), 0.5]


## Портрет для карточки постройки (у «Кошачьей лавки»): тот же мирок, что у кошки
static func portrait(hud: Hud, key: String, make: Callable) -> Control:
	return _portrait_box(hud, key, make)


# ---------- «Следовать», камера к дому ----------

static func _following(hud: Hud, r: Dictionary) -> bool:
	var rig = hud.game.rig
	return rig != null and rig.following() and hud.game.people.focus_rid == int(r["id"])


static func toggle_follow(hud: Hud, sel: Dictionary) -> void:
	var rig = hud.game.rig
	var ppl: People = hud.game.people
	if rig == null:
		return
	if rig.following():
		rig.stop_follow()
	else:
		follow(hud, sel)
	if is_instance_valid(_follow_btn):
		_follow_btn.set_pressed_no_signal(rig.following())


## Камера ведёт жителя (кошку); вошёл в дом или лавку — ждёт у двери
static func follow(hud: Hud, sel: Dictionary) -> void:
	var rig = hud.game.rig
	var ppl: People = hud.game.people
	if rig == null or ppl == null:
		return
	if hud.game.tool != "":
		hud.game.set_tool("")                    # с инструментом в руках камера не ездит (мостовая не тянулась бы за жителем)
	if sel.has("cat"):
		var ct: Dictionary = sel["cat"]
		rig.start_follow(func():
			return ppl.cat_pos(ct) if ppl.cats.has(ct) else null)
	else:
		var rid := int((sel.get("r", {}) as Dictionary).get("id", -1))
		rig.start_follow(func():
			var r: Dictionary = ppl.by_id.get(rid, {})
			return ppl.person_pos(r) if not r.is_empty() else null)


static func _fly(hud: Hud, b: Dictionary) -> void:
	var rig = hud.game.rig
	if rig == null:
		return
	rig.stop_follow()
	rig.fly_to(Vector3((b["pos"] as Vector2).x, float(b["y"]), (b["pos"] as Vector2).y))


# ---------- «Внешность»: причёска и одежда (этап 6.5) ----------

static func _fill_looks(hud: Hud, box: VBoxContainer, r: Dictionary) -> void:
	var ppl: People = hud.game.people
	var c: City = hud.game.city
	var lk: Dictionary = ppl.look_of(r).duplicate()
	var fem: bool = r["female"]
	var child: bool = r["child"]
	var cls := String(r["cls"])
	var o := Looks.options(c, lk, fem, child, cls)
	var pan := hud._chip(false, 10.0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pan.add_child(v)
	var apply := func(nl: Dictionary):
		ppl.set_look(r, nl)
		if _who is Citizen:
			(_who as Citizen).apply_look(nl)
		hud._fill_info()
	if bool(o["hair"]):
		var hm := Looks.hair_max(fem)
		var lo := 0 if not fem else 1                   # мужчинам — и бритая голова
		v.add_child(_stepper(hud, "Причёска", int(lk["hair"]), lo, hm, "бритая" if not fem else "", func(x: int):
			var nl := lk.duplicate()
			nl["hair"] = x
			apply.call(nl)))
		if bool(o["beard"]):
			v.add_child(_stepper(hud, "Борода", int(lk.get("beard", 0)), 0, Looks.BEARDS, "нет", func(x: int):
				var nl := lk.duplicate()
				nl["beard"] = x
				apply.call(nl)))
		if bool(o["tone"]) and String(lk.get("hc", "")) != "S":
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			var tl := hud._label("Волосы", 16, true)
			tl.custom_minimum_size = Vector2(110, 0)
			row.add_child(tl)
			for t: String in Looks.TONES:
				row.add_child(_tone_btn(hud, t, String(lk.get("hc", "")) == t or (String(lk.get("hc", "")) == "" and t == String(lk.get("skin", "A"))), func():
					var nl := lk.duplicate()
					nl["hc"] = t
					apply.call(nl)))
			v.add_child(row)
	else:
		v.add_child(hud._wrap(hud._label("Причёски и бороды — в «Цирюльне»: постройте её, и жители сами начнут стричься", 14, false, Hud.C_SOFT), W - 40.0))
	if not (o["cols"] as Array).is_empty():
		v.add_child(_swatch_row(hud, "Одежда", o["cols"], String(lk.get("main", "")), func(x: String):
			var nl := lk.duplicate()
			Looks.set_main(nl, x)
			apply.call(nl)))
	if not (o["second"] as Array).is_empty():
		v.add_child(_swatch_row(hud, "Тога", o["second"], String(lk.get("second", "")), func(x: String):
			var nl := lk.duplicate()
			nl["second"] = x
			apply.call(nl)))
	if not (o["trim"] as Array).is_empty():
		v.add_child(_swatch_row(hud, "Кайма", o["trim"], String(lk.get("trim", "")), func(x: String):
			var nl := lk.duplicate()
			nl["trim"] = x
			apply.call(nl)))
	if bool(o["crown"]):
		v.add_child(_stepper(hud, "Венок", int(lk.get("crown", 0)), 0, Looks.CROWNS, "нет", func(x: int):
			var nl := lk.duplicate()
			nl["crown"] = x
			apply.call(nl)))
	var need: Dictionary = o["need"]
	var hints := []
	if need.has("cols"):
		hints.append("цвета одежды откроет «%s»" % need["cols"])
	if need.has("dyes"):
		hints.append("яркие краски откроет «%s»" % need["dyes"])
	if not hints.is_empty():
		v.add_child(hud._wrap(hud._label(_cap(", ".join(hints)) + ".", 13, false, Hud.C_SOFT), W - 40.0))
	_scrolled(hud, box, pan)                  # в прокрутку — когда строки уже внутри: высота сразу настоящая


## «Причёска  ◄ 3 из 7 ►»
static func _stepper(hud: Hud, title: String, cur: int, lo: int, hi: int, zero: String, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var l := hud._label(title, 16, true)
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var prev := Button.new()
	prev.text = "◄"
	hud._small(prev, 32)
	prev.tooltip_text = "Предыдущая"
	prev.pressed.connect(func(): cb.call(hi if cur <= lo else cur - 1))
	row.add_child(prev)
	var val := hud._label((zero if cur == 0 and zero != "" else "%d из %d" % [cur, hi]), 16, true, Hud.C_INK)
	val.custom_minimum_size = Vector2(90, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(val)
	var nxt := Button.new()
	nxt.text = "►"
	hud._small(nxt, 32)
	nxt.tooltip_text = "Следующая"
	nxt.pressed.connect(func(): cb.call(lo if cur >= hi else cur + 1))
	row.add_child(nxt)
	return row


## Ряд образцов цвета (выбранный — в рамке)
static func _swatch_row(hud: Hud, title: String, cols: Array, cur: String, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var l := hud._label(title, 16, true)
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for hx: String in cols:
		var b := Button.new()
		b.custom_minimum_size = Vector2(26, 26)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = "Этот цвет"
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(hx)
		sb.set_corner_radius_all(13)
		var on := hx.to_lower() == cur.to_lower()
		sb.set_border_width_all(3 if on else 1)
		sb.border_color = Color("fff3c4") if on else Color("5a4128")
		b.add_theme_stylebox_override("normal", sb)
		var sh := sb.duplicate() as StyleBoxFlat
		sh.border_color = Color("ffe08a")
		sh.set_border_width_all(3)
		b.add_theme_stylebox_override("hover", sh)
		b.add_theme_stylebox_override("pressed", sh)
		b.pressed.connect(func(): cb.call(hx))
		flow.add_child(b)
	row.add_child(flow)
	return row


## Образец тона волос (тон палитры Synty — цвет пятна волос на атласе)
static func _tone_btn(hud: Hud, t: String, on: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(26, 26)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = {"A": "Каштановые", "B": "Тёмные", "C": "Светлые"}.get(t, "")
	var sb := StyleBoxFlat.new()
	sb.bg_color = {"A": Color("6b4a2e"), "B": Color("2e241c"), "C": Color("b08850")}.get(t, Color.GRAY)
	sb.set_corner_radius_all(13)
	sb.set_border_width_all(3 if on else 1)
	sb.border_color = Color("fff3c4") if on else Color("5a4128")
	b.add_theme_stylebox_override("normal", sb)
	var sh := sb.duplicate() as StyleBoxFlat
	sh.border_color = Color("ffe08a")
	sh.set_border_width_all(3)
	b.add_theme_stylebox_override("hover", sh)
	b.pressed.connect(cb)
	return b


# ---------- портрет ----------

## Портрет в бронзовом медальоне: свой маленький мир (SubViewport) с копией; make(vp) кладёт в него того, кого рисуем
static func _portrait_box(hud: Hud, key: String, make: Callable) -> Control:
	if _vp == null or not is_instance_valid(_vp) or _vp_key != key:
		close()
		_vp = _make_vp(hud)
		_vp_key = key
		make.call(_vp)
		_aim()
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring := Panel.new()
	ring.add_theme_stylebox_override("panel", hud._medal("medal", PORTRAIT))
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(ring)
	var tr := TextureRect.new()
	tr.texture = _vp.get_texture()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.material = StoryUi._mask_mat()
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	var o := PORTRAIT * 0.1
	tr.offset_left = o
	tr.offset_top = o
	tr.offset_right = -o
	tr.offset_bottom = -o
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(tr)
	return holder


static func _make_vp(hud: Hud) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(192, 192)
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	hud.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("e8d3a6")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff1d8")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 35, 0)
	key.light_energy = 1.25
	key.light_color = Color("fff0d6")
	vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, -140, 0)
	fill.light_energy = 0.45
	fill.light_color = Color("cfe0ff")
	vp.add_child(fill)
	var front := DirectionalLight3D.new()
	front.look_at_from_position(Vector3.ZERO, -StoryUi.FACE_DIR + Vector3(0, -0.25, 0), Vector3.UP)
	front.light_energy = 0.5
	front.light_color = Color("fff4e6")
	vp.add_child(front)
	var cam := Camera3D.new()
	cam.fov = 24.0
	cam.near = 0.02
	cam.name = "cam"
	vp.add_child(cam)
	return vp


static func _person_subject(vp: SubViewport, ppl: People, r: Dictionary) -> void:
	var child: bool = r["child"]
	var c := Citizen.build(ppl.look_of(r), child)
	c.name = "who"
	vp.add_child(c)
	if child:
		People.kid_look(c)
	if bool(r.get("old", false)):
		Citizen.elder_look(c)
	else:
		Citizen.face_fix(c, false, child)
	c.play("Idle")
	_who = c
	var sk: Skeleton3D = c.find_children("*", "Skeleton3D", true, false)[0]
	_face = [vp.get_node("cam"), sk, sk.find_bone("Head"), Vector3(0, 0.05, 0) * c.scale.y / Citizen.SIZE, 1.0 * c.scale.y / Citizen.SIZE]


static func _cat_subject(vp: SubViewport, ct: Dictionary) -> void:
	var fur := People.cat_fi(ct)                # окрас (и чёрная Мася — свой номер, не по таблице CAT_FURS)
	var cn := People.cat_node(fur, "Pet", 7)
	People.cat_wear(cn, String(People.cat_rec(ct).get("wr", "")))
	cn.name = "who"
	cn.rotation.y = 0.35
	vp.add_child(cn)
	_who = cn
	var sk = null
	var bone := -1
	var sks := cn.find_children("*", "Skeleton3D", true, false)
	if not sks.is_empty():
		sk = sks[0]
		bone = (sk as Skeleton3D).find_bone("Bone.003")
	_face = [vp.get_node("cam"), sk, bone, Vector3(0, 0.06, 0.03), 0.46]


## Камера портрета — на голову (голова движется: каждый кадр, пока карточка открыта)
static func _aim() -> void:
	if _face.is_empty():
		return
	var cam: Camera3D = _face[0]
	var sk = _face[1]
	if not is_instance_valid(cam):
		return
	var head := Vector3(0, 0.3, 0.15)
	if sk != null and is_instance_valid(sk) and int(_face[2]) >= 0:
		head = ((sk as Skeleton3D).global_transform * (sk as Skeleton3D).get_bone_global_pose(int(_face[2]))).origin
	head += _face[3]
	cam.position = head + StoryUi.FACE_DIR * float(_face[4])
	cam.look_at(head - Vector3(0, 0.02, 0), Vector3.UP)


## Карточку закрыли: мирок портрета — долой
static func close() -> void:
	if _vp != null and is_instance_valid(_vp):
		_vp.queue_free()
	_vp = null
	_vp_key = ""
	_who = null
	_face = []
	_now = null
	_now_key = ""


## Каждый кадр, пока открыта карточка: портрет следит за головой; дважды в секунду — «Сейчас», кнопка «Следовать»
static func tick(hud: Hud, sel: Dictionary, dt: float) -> void:
	_aim()
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.5
	var ppl: People = hud.game.people
	if ppl == null or not is_instance_valid(_now):
		return
	if sel.has("cat"):
		if ppl.cats.has(sel["cat"]):
			_now.text = cat_activity(ppl, sel["cat"])
	else:
		var r: Dictionary = ppl.by_id.get(int((sel.get("r", {}) as Dictionary).get("id", -1)), {})
		if r.is_empty():
			hud._hide_info()                    # уехал из города — закрыть только карточку (совет и другие окна — как были)
			return
		_now.text = activity(ppl, r)
		# сходил к цирюльнику, пока карточка открыта, — портрет в новом облике
		if _who is Citizen and Citizen.look_key((_who as Citizen).look) != Citizen.look_key(ppl.look_of(r)):
			(_who as Citizen).apply_look(ppl.look_of(r))
	if is_instance_valid(_follow_btn) and hud.game.rig:
		_follow_btn.set_pressed_no_signal(hud.game.rig.following())


# ---------- кто в семье — в карточке дома (этап 6.2) ----------

## Члены семьи f дома b строками: «Гай — пекарь», «Юлия — ткачиха», «Луций, сын»; щелчок — карточка жителя. null — некого
static func family_chips(hud: Hud, b: Dictionary, f: Dictionary, w: float) -> Control:
	var ppl: People = hud.game.people
	var ms: Array = f.get("m", [])
	if ppl == null or ms.is_empty():
		return null
	var c: City = hud.game.city
	var live := {}
	for r in ppl.residents:
		if int(r["home"]) == int(b["id"]) and r.has("m"):
			live["%s|%d" % [String(r["m"].get("pn", "")), int(r["m"].get("sd", 0))]] = r
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	for m: Dictionary in ms:
		var r: Dictionary = live.get("%s|%d" % [String(m.get("pn", "")), int(m.get("sd", 0))], {})
		var nm := String(m.get("pn", "?"))
		var job := int(r.get("job", m.get("job", -1)))
		var jb: Dictionary = c.buildings.get(job, {})
		var t := ""
		if not jb.is_empty():
			var noun := Residents.job_noun(String(jb["type"]), int(m.get("sx", 0)) == 1)
			t = "%s — %s" % [nm, noun if noun != "" else String(c.def(jb)["name"]).to_lower()]
		elif int(m.get("age", 1)) == 1 and Residents.role(m, ms) in ["отец семьи", "глава семьи", "мать семьи", "жена"]:
			t = "%s — %s" % [nm, Residents.role(m, ms)]
		else:
			t = "%s, %s" % [nm, Residents.role(m, ms)]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.add_child(hud._icon("person", 18, Hud.C_SOFT))
		var l := hud._label(t, 14, false, Hud.C_INK if not r.is_empty() else Hud.C_SOFT)
		l.clip_text = true
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.custom_minimum_size = Vector2(w - 8.0, 0)
		if r.is_empty():
			row.tooltip_text = "Сейчас не в городе"
			box.add_child(row)
		else:
			var rr := r
			var cl := hud._clickable(row, "Карточка жителя: %s" % People.name_of(r), func(): hud.game.select_person({"r": rr}))
			cl.name = "m_" + nm
			box.add_child(cl)
	return box


# ---------- «Горожане» (этап 6.9): поиск по имени и семье ----------

## Жители по запросу q (имя или семья) и фильтру f ("" все, "nojob" без работы, "sad" несчастные, "kids" дети):
## не больше LIST_MAX строк; info.total — сколько нашлось всего (в «Горожанах» — «Показаны 40 из …»)
static func search(ppl: People, q: String, f: String, info: Dictionary = {}) -> Array:
	var c: City = ppl.city
	q = q.strip_edges().to_lower()
	var out := []
	var total := 0
	for r in ppl.residents:
		if int(r["home"]) == -2:
			continue                            # уезжает
		match f:
			"nojob":
				if r["child"] or int(r["job"]) >= 0 or int(r["home"]) <= 0:
					continue
			"sad":
				var h: Dictionary = c.buildings.get(int(r["home"]), {})
				if h.is_empty() or int(h["happy"]) >= 50:
					continue
			"kids":
				if not r["child"]:
					continue
		if q != "":
			var nm := People.name_of(r).to_lower()
			if not (nm.contains(q) or String(r["fam"]).to_lower().contains(q) or StoryDefs.fam_gen(String(r["fam"])).to_lower().contains(q)):
				continue
		total += 1
		if out.size() < LIST_MAX:
			out.append(r)
	info["total"] = total
	return out
