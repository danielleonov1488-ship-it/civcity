class_name Chronicle
extends RefCounted
## «Летопись города» (план 24.10, K-own-27): счётчики города и лавровые венки за вехи — первые сто горожан, первая
## победа Легиона, сотня украшений… Венок даётся тихо: одна строка в колокольчик, без всплывашек (советник один раз
## скажет, где их смотреть). Все венки и счётчики — во вкладке «Летопись» журнала (StoryUi.open_journal).
## Данные — city.chron: {"v", "c": счётчики, которых больше нигде нет, "b": id венка → день}. Остальное берётся из
## города (семьи, мостовая, исследования, истории, победы, участки, кошки, дни).
## Старые сохранения: счётчики — из того, что уже стоит (постройки, этажи, жители), заслуженные венки — разом, одной
## строкой в колокольчик. Проверка венков — раз в игровой час (City.sim_day), только в своём городе (chron_on).

## Строки счётчиков во вкладке: [ключ, подпись, значок]
const ROWS := [
	["people", "Горожан поселилось", "family"], ["fams", "Семей приехало", "housing"], ["peak", "Больше всего жителей разом", "person"],
	["built", "Построено зданий", "hammer"], ["decor", "Поставлено украшений", "flower"], ["floors", "Надстроено этажей", "brick"],
	["upg", "Перестроено домов", "housing"], ["paved", "Вымощено улиц, м²", "road"], ["research", "Изучено", "research"],
	["stories", "Пройдено историй горожан", "scroll"], ["wins", "Побед Легиона", "swords"], ["fests", "Игр в честь богов", "laurels"],
	["plots", "Куплено участков", "keys"], ["cats", "Кошек в городе", "cat"], ["days", "Дней городу", "time"],
]

## Венки: ключ счётчика и сколько нужно; text — за что (строка в колокольчик и подпись во вкладке)
const BADGES := [
	{"id": "fam1", "name": "Первая семья", "text": "в городе поселилась первая семья", "k": "fams", "n": 1},
	{"id": "pop100", "name": "Сто горожан", "text": "в городе живут сто человек", "k": "peak", "n": 100},
	{"id": "pop300", "name": "Шумные улицы", "text": "в городе живут триста человек", "k": "peak", "n": 300},
	{"id": "pop600", "name": "Людный город", "text": "в городе живут шестьсот человек", "k": "peak", "n": 600},
	{"id": "pop1000", "name": "Тысяча горожан", "text": "в городе живёт тысяча человек", "k": "peak", "n": 1000},
	{"id": "built25", "name": "Строитель", "text": "построено 25 зданий", "k": "built", "n": 25},
	{"id": "built120", "name": "Зодчий", "text": "построено 120 зданий", "k": "built", "n": 120},
	{"id": "built400", "name": "Великий зодчий", "text": "построено 400 зданий", "k": "built", "n": 400},
	{"id": "decor50", "name": "Садовник", "text": "поставлено 50 украшений", "k": "decor", "n": 50},
	{"id": "decor300", "name": "Город-сад", "text": "поставлено 300 украшений", "k": "decor", "n": 300},
	{"id": "pave", "name": "Мостильщик", "text": "вымощено 300 м² улиц", "k": "paved", "n": 300},
	{"id": "pave2", "name": "Все дороги ведут в Рим", "text": "вымощено 2000 м² улиц", "k": "paved", "n": 2000},
	{"id": "floors10", "name": "Этаж за этажом", "text": "надстроено 10 этажей", "k": "floors", "n": 10},
	{"id": "upg1", "name": "Новоселье", "text": "перестроен первый дом", "k": "upg", "n": 1},
	{"id": "upg15", "name": "Квартал мастеров", "text": "перестроено 15 домов", "k": "upg", "n": 15},
	{"id": "res10", "name": "Учёный совет", "text": "изучено 10 исследований", "k": "research", "n": 10},
	{"id": "res40", "name": "Мудрость веков", "text": "изучено 40 исследований", "k": "research", "n": 40},
	{"id": "story1", "name": "Добрый градоначальник", "text": "пройдена первая история горожан", "k": "stories", "n": 1},
	{"id": "story6", "name": "Летописец", "text": "пройдено шесть историй горожан", "k": "stories", "n": 6},
	{"id": "win1", "name": "Первая победа", "text": "Легион выиграл первый бой", "k": "wins", "n": 1},
	{"id": "win10", "name": "Триумфатор", "text": "Легион выиграл десять боёв", "k": "wins", "n": 10},
	{"id": "fest1", "name": "Хлеба и зрелищ", "text": "устроены первые игры в честь богов", "k": "fests", "n": 1},
	{"id": "fest5", "name": "Любимец богов", "text": "пять раз устроены игры в честь богов", "k": "fests", "n": 5},
	{"id": "plot1", "name": "Землевладелец", "text": "куплен первый участок земли", "k": "plots", "n": 1},
	{"id": "happy", "name": "Счастливый город", "text": "счастье города — 85% и выше (от 50 жителей)", "k": "happy", "n": 85},
	{"id": "cats5", "name": "Кошачье царство", "text": "в городе пять кошек", "k": "cats", "n": 5},
	{"id": "days100", "name": "Сто дней", "text": "городу сто дней", "k": "days", "n": 100},
	{"id": "rank4", "name": "Настоящий городок", "text": "город стал «Городком»", "k": "rank", "n": 4},
	{"id": "rank7", "name": "Вечный город", "text": "город стал «Вечным городом»", "k": "rank", "n": 7},
]


static func fresh() -> Dictionary:
	return {"v": 1, "c": {}, "b": {}}


## Из сохранения; нет летописи (старое сохранение) — {} (City.load_data заведёт её по городу: migrate)
static func load_from(d: Variant) -> Dictionary:
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	var out := fresh()
	var cc = (d as Dictionary).get("c", {})
	if typeof(cc) == TYPE_DICTIONARY:
		for k in cc:
			out["c"][String(k)] = maxi(0, int(cc[k]))
	var bb = (d as Dictionary).get("b", {})
	if typeof(bb) == TYPE_DICTIONARY:
		for k in bb:
			if badge(String(k)).size() > 0:
				out["b"][String(k)] = int(bb[k])
	return out


static func badge(id: String) -> Dictionary:
	for b: Dictionary in BADGES:
		if b["id"] == id:
			return b
	return {}


## +n к счётчику (постройки, этажи, перестройки, игры, горожане); −n — отменили постройку (не меньше нуля)
static func add(c: City, k: String, n := 1) -> void:
	var cc: Dictionary = c.chron["c"]
	cc[k] = maxi(0, int(cc.get(k, 0)) + n)


## Значение счётчика: свои — из city.chron, остальные — из города
static func value(c: City, k: String) -> int:
	var cc: Dictionary = c.chron.get("c", {})
	match k:
		"fams":
			return c.settled_total
		"peak":
			return maxi(int(cc.get("peak", 0)), int(c.stats.get("pop", 0)))
		"paved":
			return int(float(c.road_cells) * Land.CELL * Land.CELL)
		"research":
			var n := 0
			for r: Dictionary in Defs.RESEARCH:
				if c.research.has(r["id"]):
					n += 1
			return n
		"stories":
			return (c.stories.get("done", {}) as Dictionary).size()
		"wins":
			return c.legion.wins + c.legion.pvp_wins
		"plots":
			return c.plots_bought
		"happy":
			return int(c.stats.get("happy", 0)) if int(c.stats.get("pop", 0)) >= 50 else 0
		"cats":
			return c.cat_recs().size()
		"days":
			return c.day
		"rank":
			return c.level
	return int(cc.get(k, 0))


## Раз в час: новые венки — по строке в колокольчик (без всплывашек). Возвращает id новых
static func check(c: City) -> Array:
	var cc: Dictionary = c.chron["c"]
	cc["peak"] = value(c, "peak")
	var got: Dictionary = c.chron["b"]
	var out := []
	for b: Dictionary in BADGES:
		if got.has(b["id"]) or value(c, String(b["k"])) < int(b["n"]):
			continue
		got[b["id"]] = c.day
		out.append(b["id"])
		# венки за час — одной строкой (несколько разом — не несколько строк)
		c._quiet_m("chron", "laurels", {"b": ["«%s» — %s" % [b["name"], b["text"]]]}, func(a: Dictionary) -> String:
			var bb: Array = a["b"]
			return ("Летопись города: лавровый венок " if bb.size() == 1 else "Летопись города: лавровые венки ") + "; ".join(PackedStringArray(bb)))
	return out


## Старое сохранение без летописи: счётчики — из того, что есть в городе; заслуженные венки — разом, одной строкой
static func migrate(c: City) -> void:
	c.chron = fresh()
	var cc: Dictionary = c.chron["c"]
	var people := 0
	var built := 0
	var decor := 0
	var floors := 0
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		var d := c.def(b)
		if d.get("fixed", false):
			continue
		if d["kind"] == "decor":
			decor += 1
		else:
			built += 1
		if d["kind"] == "house":
			people += int(b["pop"])
			floors += maxi(0, int(b["tier"]) - 1)
	cc["people"] = people
	cc["built"] = built
	cc["decor"] = decor
	cc["floors"] = floors
	cc["peak"] = int(c.stats.get("pop", 0))
	var n := 0
	for b: Dictionary in BADGES:
		if value(c, String(b["k"])) >= int(b["n"]):
			c.chron["b"][b["id"]] = c.day
			n += 1
	if n > 0:
		c.events.append({"day": c.day, "icon": "laurels",
			"text": "Летопись города: за прошлые дни город уже заслужил %d %s — они в журнале («Просьбы горожан» → книжка → «Летопись»)" % [n, City.plural(n, "лавровый венок", "лавровых венка", "лавровых венков")]})
		if c.events.size() > 60:
			c.events.pop_front()
		c.unread += 1


static func count(c: City) -> int:
	return (c.chron.get("b", {}) as Dictionary).size()


static func any(c: City) -> bool:
	return c != null and count(c) > 0


# ---------- вкладка «Летопись» журнала ----------

## Счётчики (в два столбца) и все венки: заслуженные — золотые, с днём; остальные — серые, с тем, сколько осталось
static func fill(hud, list: VBoxContainer) -> void:
	var c: City = hud.game.city
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(hud._icon("laurels", 30, hud.C_GOLD))
	head.add_child(hud._label("Лавровые венки: %d из %d" % [count(c), BADGES.size()], 20, false, hud.C_INK, hud.font_title))
	list.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 2)
	for r: Array in ROWS:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		h.custom_minimum_size = Vector2(262, 0)
		h.add_child(hud._icon(String(r[2]), 20, hud.C_SOFT))
		var l: Label = hud._label(String(r[1]), 14, false, hud.C_INK)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		h.add_child(hud._label(hud.fmt(value(c, String(r[0]))), 15, true, hud.C_INK))
		grid.add_child(h)
	list.add_child(grid)
	list.add_child(hud._divider(14))
	var got: Dictionary = c.chron.get("b", {})
	var bg := GridContainer.new()
	bg.columns = 2
	bg.add_theme_constant_override("h_separation", 12)
	bg.add_theme_constant_override("v_separation", 8)
	# заслуженные — сначала (самые новые сверху), потом остальные по порядку
	var order: Array = BADGES.filter(func(b): return got.has(b["id"]))
	order.sort_custom(func(a, b): return int(got[a["id"]]) > int(got[b["id"]]))
	order.append_array(BADGES.filter(func(b): return not got.has(b["id"])))
	for b: Dictionary in order:
		bg.add_child(_badge_row(hud, c, b, got))
	list.add_child(bg)


static func _badge_row(hud, c: City, b: Dictionary, got: Dictionary) -> Control:
	var has := got.has(b["id"])
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.custom_minimum_size = Vector2(266, 0)
	var med := Panel.new()
	med.custom_minimum_size = Vector2(44, 44)
	med.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	med.add_theme_stylebox_override("panel", hud._medal("medal_on" if has else "medal_lock", 44))
	var ic: TextureRect = hud._icon("laurels", 28, hud.C_GOLD if has else hud.C_SOFT)
	ic.position = Vector2(8, 8)
	med.add_child(ic)
	if not has:
		hud._grey(med)
	h.add_child(med)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(hud._label(String(b["name"]), 16, true, hud.C_INK if has else hud.C_SOFT))
	var t := String(b["text"])
	var sub := ("день %d · " % (int(got[b["id"]]) + 1) if has else "") + t
	if not has and String(b["k"]) not in ["rank", "happy"]:
		sub += " (сейчас %s)" % hud.fmt(value(c, String(b["k"])))
	v.add_child(hud._wrap(hud._label(sub, 13, false, hud.C_SOFT), 210))
	h.add_child(v)
	return h
