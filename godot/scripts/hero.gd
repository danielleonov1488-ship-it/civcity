class_name Hero
extends RefCounted
## Свой герой (решение владельца Д11, этап L.3 плана от 24.10). В начале новой игры игрок создаёт своего римлянина
## (HeroScreen: имя, пол, кожа, причёска, борода, наряд и цвета, готовые наборы и «Случайный»); старый город — при первом
## входе после обновления (экран можно отложить — тогда случайный герой, переделать — когда угодно, «Изменить» в карточке).
## Герой живёт в городе (People: ходит по улицам, в лавки, на площади, к форуму и зданиям Легиона, ночует в Казармах
## или на почтовой станции), выделяется лавровым венком и плащом своего цвета, найти его — медальон «Герой» сверху.
## Новые вещи гардероба открывают ранг города, Легион и истории (позже — цирюльня и лавки одежды); вещь открылась —
## строчка в колокольчике. Герой — первый и главный воин Легиона: своё место в отряде (Legion.battle_squad), свой вид
## в бою (лицо, волосы, цвета, плащ, венок) и снаряжение со Склада оружия (KIT), растёт с Казармами и городом.
##
## Запись (сохраняется в городе под ключом "hero", ≈ 0,4 КБ):
##   {v: 1, m: {pn: имя целиком («Гай Валерий»), sx: 0/1, age: 1, sd: зерно, look: облик Citizen + cape (цвет плаща)},
##    made: true — создан игроком (false — случайный, игрок отложил), seen: [id вещей гардероба, о которых уже сказано],
##    kit: ступень снаряжения, о которой уже сказано}
## Облик — тот же, что у жителей (Citizen.roll_look / build / apply_look), плюс cape; венок у героя всегда (знак героя).

const V := 1
const HERO_RID := 900000001                 # номер героя среди жителей (People.by_id): не пересекается с горожанами
const NAME_MIN := 2
const NAME_MAX := 24

## Наряды: модель Synty и название; [мужские], [женские]
const OUTFITS := [
	[["SK_Chr_Upperclass_Male_01", "Тога"], ["SK_Chr_Worker_Male_01", "Туника"], ["SK_Chr_Farmer_Male_01", "Туника с подолом"],
		["SK_Chr_Politician_Male_01", "Тога сенатора"]],
	[["SK_Chr_Upperclass_Female_01", "Стола"], ["SK_Chr_Worker_Female_01", "Платье"], ["SK_Chr_Farmer_Female_01", "Платье в два тона"]],
]
const SKIN_NAMES := {"A": "Светлая", "B": "Смуглая", "C": "Тёплая"}
const HAIR_NAMES := {"A": "Каштановые", "B": "Тёмные", "C": "Светлые", "S": "Седые"}
const COGNOMINA := ["Прима", "Секунда", "Максима", "Луцилла", "Аврелиана", "Фаустина", "Агриппина", "Марцелла"]

## Гардероб: вид → [{v: значение, n: название, need: {rank: уровень, story: история, legion: barracks|boss1|boss3, shop: тип}}];
## need пуст — есть с начала; несколько условий — хватит любого («город „Деревня“ или Красильня»)
const ITEMS := {
	"cape": [
		{"v": "a3283a", "n": "Красный плащ легионера"}, {"v": "6b4a2e", "n": "Бурый дорожный плащ"},
		{"v": "2f5585", "n": "Синий плащ"}, {"v": "4f6b3a", "n": "Плащ цвета мирта"},
		{"v": "26211f", "n": "Чёрный плащ — в честь кошки", "need": {"story": "cat"}},
		{"v": "3f7f86", "n": "Плащ цвета моря", "need": {"story": "leak"}},
		{"v": "d9a93e", "n": "Шафрановый плащ", "need": {"rank": 3}},
		{"v": "b0202e", "n": "Алый плащ центуриона", "need": {"legion": "boss1"}},
		{"v": "efe9dc", "n": "Белый плащ триумфатора", "need": {"legion": "boss3"}},
		{"v": "5e2350", "n": "Пурпурный плащ", "need": {"rank": 5}},
		{"v": "c99a2e", "n": "Золотой плащ", "need": {"rank": 6}}],
	"main": [
		{"v": "a3283a", "n": "Кермес"}, {"v": "b4432f", "n": "Марена"}, {"v": "c49a4a", "n": "Охра"}, {"v": "d9a93e", "n": "Шафран"},
		{"v": "4d7397", "n": "Вайда"}, {"v": "7fa3be", "n": "Небесный"}, {"v": "6f8a4e", "n": "Мирт"}, {"v": "7a5f45", "n": "Бурая шерсть"},
		{"v": "d8ccb0", "n": "Некрашеная шерсть"}, {"v": "e8e2d6", "n": "Белый лён"},
		{"v": "8c5fa0", "n": "Аметист", "need": {"rank": 2, "shop": "dyer"}}, {"v": "5e9488", "n": "Морская волна", "need": {"rank": 2, "shop": "dyer"}},
		{"v": "c9733a", "n": "Оранжевый", "need": {"rank": 2, "shop": "dyer"}}, {"v": "d59098", "n": "Бледная роза", "need": {"rank": 2, "shop": "dyer"}},
		{"v": "d4a548", "n": "Золото", "need": {"rank": 4, "shop": "jeweler"}}, {"v": "6e2a5a", "n": "Тирский пурпур", "need": {"rank": 5, "shop": "tailor"}}],
	"second": [
		{"v": "f4f1ea", "n": "Белёная мелом"}, {"v": "eee8dc", "n": "Чистая шерсть"}, {"v": "e3d8c3", "n": "Небелёная"},
		{"v": "7ea4c8", "n": "Небесная", "need": {"rank": 3, "shop": "fullonica"}}, {"v": "d8a13c", "n": "Шафрановая", "need": {"rank": 3, "shop": "fullonica"}},
		{"v": "6e2a5a", "n": "Пурпурная тога триумфатора", "need": {"rank": 6}}],
	"trim": [
		{"v": "c49a4a", "n": "Охра"}, {"v": "a9503a", "n": "Марена"}, {"v": "5f7c96", "n": "Вайда"}, {"v": "7a5f45", "n": "Бурая"}, {"v": "d8ccb0", "n": "Светлая"},
		{"v": "d4a548", "n": "Золотая кайма", "need": {"rank": 4, "shop": "tailor"}}, {"v": "a82c3c", "n": "Кермесовая кайма", "need": {"legion": "boss1"}},
		{"v": "6e2a5a", "n": "Пурпурная кайма", "need": {"rank": 5}}],
	"crown": [{"v": 1, "n": "Лавровый венок"}, {"v": 2, "n": "Венок победителя", "need": {"story": "bandits", "legion": "boss1"}}],
	"hc": [{"v": "A", "n": "Каштановые"}, {"v": "B", "n": "Тёмные"}, {"v": "C", "n": "Светлые"}, {"v": "S", "n": "Седина мудреца", "need": {"rank": 4}}],
	"mdl": [
		{"v": "SK_Chr_Upperclass_Male_01", "n": "Тога"}, {"v": "SK_Chr_Worker_Male_01", "n": "Туника"}, {"v": "SK_Chr_Farmer_Male_01", "n": "Туника с подолом"},
		{"v": "SK_Chr_Politician_Male_01", "n": "Тога сенатора", "need": {"rank": 4}},
		{"v": "SK_Chr_Upperclass_Female_01", "n": "Стола"}, {"v": "SK_Chr_Worker_Female_01", "n": "Платье"}, {"v": "SK_Chr_Farmer_Female_01", "n": "Платье в два тона"}],
}
## Чем гардероб открывается — для подсказок «Откроется: …»
const LEGION_NEED := {"barracks": "Казармы", "boss1": "первая победа над боссом похода", "boss3": "третья победа над боссом похода"}

## Готовые наборы: название, пол, облик (только то, что есть с начала)
const PRESETS := [
	{"n": "Полководец", "sx": 0, "look": {"mdl": "SK_Chr_Upperclass_Male_01", "skin": "A", "hair": 3, "beard": 0, "hc": "B", "main": "a3283a", "second": "f4f1ea", "trim": "c49a4a", "cape": "a3283a", "crown": 1}},
	{"n": "Ветеран", "sx": 0, "look": {"mdl": "SK_Chr_Worker_Male_01", "skin": "B", "hair": 6, "beard": 1, "hc": "B", "main": "7a5f45", "second": "e3d8c3", "trim": "c49a4a", "cape": "6b4a2e", "crown": 1}},
	{"n": "Юный трибун", "sx": 0, "look": {"mdl": "SK_Chr_Upperclass_Male_01", "skin": "C", "hair": 1, "beard": 0, "hc": "C", "main": "4d7397", "second": "eee8dc", "trim": "5f7c96", "cape": "2f5585", "crown": 1}},
	{"n": "Мудрец", "sx": 0, "look": {"mdl": "SK_Chr_Farmer_Male_01", "skin": "A", "hair": 5, "beard": 4, "hc": "A", "main": "c49a4a", "second": "eee8dc", "trim": "7a5f45", "cape": "4f6b3a", "crown": 1}},
	{"n": "Матрона", "sx": 1, "look": {"mdl": "SK_Chr_Upperclass_Female_01", "skin": "A", "hair": 2, "beard": 0, "hc": "B", "main": "d9a93e", "second": "f4f1ea", "trim": "a9503a", "cape": "a3283a", "crown": 1}},
	{"n": "Жрица Весты", "sx": 1, "look": {"mdl": "SK_Chr_Upperclass_Female_01", "skin": "C", "hair": 4, "beard": 0, "hc": "C", "main": "e8e2d6", "second": "f4f1ea", "trim": "5f7c96", "cape": "2f5585", "crown": 1}},
	{"n": "Ремесленница", "sx": 1, "look": {"mdl": "SK_Chr_Worker_Female_01", "skin": "B", "hair": 5, "beard": 0, "hc": "B", "main": "b4432f", "second": "e3d8c3", "trim": "c49a4a", "cape": "6b4a2e", "crown": 1}},
	{"n": "Охотница", "sx": 1, "look": {"mdl": "SK_Chr_Farmer_Female_01", "skin": "A", "hair": 6, "beard": 0, "hc": "A", "main": "6f8a4e", "second": "e3d8c3", "trim": "7a5f45", "cape": "4f6b3a", "crown": 1}},
]

## Снаряжение со Склада оружия (Д10: здание даёт снаряжение героя): ступень по уровню Склада (0 — Склада нет).
## right/left — оружие Synty в руках бойца; броня и урон — только герою, только в походах
const KIT := [
	{"lvl": 0, "n": "Гладиус и деревянный щит", "right": "SM_Wep_Sword_02", "left": "SM_Wep_Shield_03"},
	{"lvl": 1, "n": "Гладиус и скутум легионера", "right": "SM_Wep_Sword_02", "left": "SM_Wep_Shield_04"},
	{"lvl": 4, "n": "Длинный меч и бронзовый щит с орлом", "right": "SM_Wep_Sword_01", "left": "SM_Wep_Shield_02"},
	{"lvl": 7, "n": "Меч легата и щит со львом", "right": "SM_Wep_Sword_01", "left": "SM_Wep_Shield_01"},
]
const KIT_ARMOR := 3.0                 # герою за уровень Склада оружия: столько брони сверх общей прибавки Склада
const KIT_ATK := 0.02                  # и столько урона (доля)


# =====================================================================
#   запись героя
# =====================================================================

static func exists(c: City) -> bool:
	return c != null and typeof(c.hero) == TYPE_DICTIONARY and not (c.hero as Dictionary).is_empty()


## Новый герой: имя, пол, облик; made — создан игроком (false — случайный: игрок отложил выбор)
static func make(pn: String, sx: int, lk: Dictionary, made: bool, sd := 0) -> Dictionary:
	var l := lk.duplicate()
	fix_look(l, sx)
	if sd == 0:
		sd = hash([pn, Time.get_ticks_usec()]) & 0x7fffffff
	return {"v": V, "m": {"pn": clean_name(pn), "sx": sx, "age": 1, "sd": sd, "look": l}, "made": made, "seen": [], "kit": -1}


## Случайный герой (никогда не ребёнок; венок — всегда: знак героя)
static func random(rng: RandomNumberGenerator, sx := -1) -> Dictionary:
	if sx < 0:
		sx = rng.randi() % 2
	return make(random_name(rng, sx), sx, random_look(rng, sx), false, rng.randi() & 0x7fffffff)


## Случайный облик: из того, что есть с начала (гардероб растёт — откроется больше)
static func random_look(rng: RandomNumberGenerator, sx: int) -> Dictionary:
	var lk := {}
	var mdls := (ITEMS["mdl"] as Array).filter(func(e): return not e.has("need") and (String(e["v"]) in Citizen.FEMALE) == (sx == 1))
	lk["mdl"] = String(mdls[rng.randi() % mdls.size()]["v"])
	lk["skin"] = ["A", "B", "C"][rng.randi() % 3]
	lk["hair"] = 1 + rng.randi() % Looks.hair_max(sx == 1)
	if sx == 0 and rng.randf() < 0.15:
		lk["hair"] = 0                                    # бритая голова
	lk["beard"] = (1 + rng.randi() % Looks.BEARDS) if sx == 0 and rng.randf() < 0.5 else 0
	lk["hc"] = ["A", "B", "C"][rng.randi() % 3]
	for k: String in ["main", "second", "trim", "cape"]:
		var base := (ITEMS[k] as Array).filter(func(e): return not e.has("need"))
		lk[k] = String(base[rng.randi() % base.size()]["v"])
	lk["crown"] = 1
	fix_look(lk, sx)
	return lk


## Облик героя приводим к правилам: модель своего пола, венок всегда, у женщин без бороды и с причёской,
## цвета строками; у рабочего кайма — светлее туники (как у Synty)
static func fix_look(lk: Dictionary, sx: int) -> void:
	var fem := sx == 1
	var mdl := String(lk.get("mdl", ""))
	if not (mdl in Citizen.PLEBS + Citizen.RICH) or (mdl in Citizen.FEMALE) != fem:
		lk["mdl"] = String(OUTFITS[sx][0][0])
	for k: String in ["hair", "beard", "crown"]:
		lk[k] = int(lk.get(k, 0))
	if fem:
		lk["beard"] = 0
		lk["hair"] = clampi(int(lk["hair"]), 1, Looks.hair_max(true))
	else:
		lk["hair"] = clampi(int(lk["hair"]), 0, Looks.hair_max(false))
		lk["beard"] = clampi(int(lk["beard"]), 0, Looks.BEARDS)
	lk["crown"] = clampi(int(lk["crown"]), 1, Looks.CROWNS)
	if not (String(lk.get("skin", "")) in ["A", "B", "C"]):
		lk["skin"] = "A"
	if not (String(lk.get("hc", "")) in ["A", "B", "C", "S"]):
		lk["hc"] = String(lk["skin"])
	var defs := {"main": "a3283a", "second": "f4f1ea", "trim": "c49a4a", "cape": "a3283a"}
	for k: String in defs:
		var v := String(lk.get(k, ""))
		lk[k] = v if v.is_valid_html_color() and v.length() == 6 else String(defs[k])
	if String(lk["mdl"]) == "SK_Chr_Worker_Male_01":
		Looks.set_main(lk, String(lk["main"]))


## Запись из сохранения: числа целыми, облик по правилам. Пусто или испорчено — {} (тогда герой создастся заново)
static func norm(d) -> Dictionary:
	if typeof(d) != TYPE_DICTIONARY or typeof((d as Dictionary).get("m")) != TYPE_DICTIONARY:
		return {}
	var m: Dictionary = (d["m"] as Dictionary).duplicate(true)
	var sx := 1 if int(m.get("sx", 0)) == 1 else 0
	var lk: Dictionary = m.get("look", {}) if typeof(m.get("look")) == TYPE_DICTIONARY else {}
	fix_look(lk, sx)
	var pn := clean_name(String(m.get("pn", "")))
	if check_name(pn) != "":
		pn = "Гай Валерий" if sx == 0 else "Валерия Прима"
	var seen := []
	if typeof(d.get("seen")) == TYPE_ARRAY:
		for s in d["seen"]:
			seen.append(String(s))
	return {"v": V, "m": {"pn": pn, "sx": sx, "age": 1, "sd": int(m.get("sd", 1)), "look": lk}, "made": bool(d.get("made", false)),
		"seen": seen, "kit": int(d.get("kit", -1))}


static func clean_name(s: String) -> String:
	return CityName.clean(s)


## Почему такое имя нельзя ("" — можно): длина, буквы, грубые слова (те же списки, что у названия города)
static func check_name(s: String) -> String:
	var t := clean_name(s)
	if t.length() < NAME_MIN or t.length() > NAME_MAX:
		return "Имя — от %d до %d знаков" % [NAME_MIN, NAME_MAX]
	var rx := RegEx.create_from_string("^[\\p{L} '’\\-.]+$")
	if rx.search(t) == null:
		return "В имени — только буквы, пробел и дефис"
	if CityName.rude(t):
		return "Такое имя не подойдёт — придумайте другое"
	return ""


## Случайное римское имя: «Гай Валерий» (мужчины — имя и род), «Валерия Прима» (женщины — род и прозвище)
static func random_name(rng: RandomNumberGenerator, sx: int) -> String:
	var fam: String = Defs.FAMILIES[rng.randi() % Defs.FAMILIES.size()]
	if sx == 1:
		return "%s %s" % [StoryDefs.nomen_f(fam), COGNOMINA[rng.randi() % COGNOMINA.size()]]
	return "%s %s" % [Residents.MEN[rng.randi() % 10], StoryDefs.nomen(fam)]


## Облик героя (для Citizen.build): из записи, всегда с венком и плащом
static func look(c: City) -> Dictionary:
	if not exists(c):
		return {}
	return (c.hero["m"] as Dictionary)["look"]


static func name_of(c: City) -> String:
	return String((c.hero["m"] as Dictionary).get("pn", "Герой")) if exists(c) else "Герой"


static func female(c: City) -> bool:
	return exists(c) and int((c.hero["m"] as Dictionary).get("sx", 0)) == 1


## Новый облик (выбор игрока: «Гардероб», «Изменить»); имя и пол — set_identity
static func set_look(c: City, lk: Dictionary) -> void:
	if not exists(c):
		return
	var m: Dictionary = c.hero["m"]
	var l := lk.duplicate()
	fix_look(l, int(m["sx"]))
	m["look"] = l


# =====================================================================
#   гардероб
# =====================================================================

## Открыта ли вещь (need — условия; хватит любого)
static func open(c: City, need: Dictionary) -> bool:
	if need.is_empty():
		return true
	if c == null:
		return false
	for k in need:
		match String(k):
			"rank":
				if c.level >= int(need[k]):
					return true
			"story":
				if (c.stories.get("done", {}) as Dictionary).has(String(need[k])):
					return true
			"shop":
				for id in c.buildings:
					if String(c.buildings[id]["type"]) == String(need[k]):
						return true
			"legion":
				var lg: Legion = c.legion
				match String(need[k]):
					"barracks":
						if lg.count_type("barracks") > 0:
							return true
					"boss1":
						if lg.bosses() >= 1:
							return true
					"boss3":
						if lg.bosses() >= 3:
							return true
	return false


## «Откроется: город „Посёлок“ или Красильня»
static func need_text(need: Dictionary) -> String:
	var parts := []
	for k in need:
		match String(k):
			"rank":
				parts.append("город «%s»" % String(Defs.LEVELS[clampi(int(need[k]), 0, Defs.LEVELS.size() - 1)]["name"]))
			"story":
				parts.append("история «%s»" % String(StoryDefs.story(String(need[k])).get("title", need[k])))
			"shop":
				parts.append("«%s» в городе" % String(Defs.B.get(String(need[k]), {"name": need[k]})["name"]))
			"legion":
				parts.append(String(LEGION_NEED.get(String(need[k]), need[k])))
	return "Откроется: " + " или ".join(parts)


## Вещи гардероба вида kind для облика lk (пол — по модели): [{v, n, open, why}]; наряды — только своего пола,
## ткани — только если у модели такая есть
static func items(c: City, kind: String, lk: Dictionary) -> Array:
	var out := []
	var fem := String(lk.get("mdl", "")) in Citizen.FEMALE
	var mdl := String(lk.get("mdl", ""))
	if kind in ["second", "trim"] and not Looks.has_part(mdl, kind):
		return out
	if kind == "trim" and mdl == "SK_Chr_Worker_Male_01":
		return out                                        # у рабочего кайма — светлее туники сама
	for e: Dictionary in ITEMS.get(kind, []):
		if kind == "mdl" and (String(e["v"]) in Citizen.FEMALE) != fem:
			continue
		var need: Dictionary = e.get("need", {})
		var ok := open(c, need)
		out.append({"v": e["v"], "n": String(e["n"]), "open": ok, "why": "" if ok else need_text(need), "id": item_id(kind, e["v"])})
	return out


static func item_id(kind: String, v) -> String:
	return "%s:%s" % [kind, str(v)]


## Сколько вещей открыто и всего (карточка героя: «Гардероб — 31 из 46»)
static func wardrobe_count(c: City, sx: int) -> Array:
	var n := 0
	var all := 0
	for kind in ITEMS:
		for e: Dictionary in ITEMS[kind]:
			if kind == "mdl" and (String(e["v"]) in Citizen.FEMALE) != (sx == 1):
				continue
			all += 1
			if open(c, e.get("need", {})):
				n += 1
	return [n, all]


## Ближайшая закрытая вещь (подсказка «Скоро: …»): {n, why} или {}
static func next_item(c: City, sx: int) -> Dictionary:
	var best := {}
	var br := 99
	for kind in ITEMS:
		for e: Dictionary in ITEMS[kind]:
			if kind == "mdl" and (String(e["v"]) in Citizen.FEMALE) != (sx == 1):
				continue
			var need: Dictionary = e.get("need", {})
			if need.is_empty() or open(c, need):
				continue
			var r := int(need.get("rank", 50 if need.has("legion") else 40))
			if r < br:
				br = r
				best = {"n": String(e["n"]), "why": need_text(need)}
	return best


## Открывшиеся вещи, о которых ещё не сказано: [название]; пометить сказанными. first — первый раз (старый город,
## новая игра): всё уже открытое — «видели», без строчек в колокольчике
static func take_new(c: City, first := false) -> Array:
	if not exists(c):
		return []
	var seen: Array = c.hero["seen"]
	var out := []
	var sx := int((c.hero["m"] as Dictionary)["sx"])
	for kind in ITEMS:
		for e: Dictionary in ITEMS[kind]:
			var need: Dictionary = e.get("need", {})
			if need.is_empty():
				continue
			if kind == "mdl" and (String(e["v"]) in Citizen.FEMALE) != (sx == 1):
				continue
			var id := item_id(kind, e["v"])
			if seen.has(id) or not open(c, need):
				continue
			seen.append(id)
			if not first:
				out.append(String(e["n"]))
	return out


# =====================================================================
#   снаряжение и бой
# =====================================================================

## Ступень снаряжения по уровню Склада оружия (0 — Склада нет)
static func kit_of(armory_lvl: int) -> Dictionary:
	var best: Dictionary = KIT[0]
	for k: Dictionary in KIT:
		if armory_lvl >= int(k["lvl"]):
			best = k
	return best


static func kit_tier(armory_lvl: int) -> int:
	var t := 0
	for i in KIT.size():
		if armory_lvl >= int(KIT[i]["lvl"]):
			t = i
	return t


## Облик героя в бою: его облик и снаряжение (LegionFighter.create_hero)
static func battle_look(c: City, armory_lvl: int) -> Dictionary:
	var lk := look(c).duplicate()
	var k := kit_of(armory_lvl)
	lk["right"] = k["right"]
	lk["left"] = k["left"]
	lk["sx"] = 1 if female(c) else 0
	return lk


## Слово о герое для строк интерфейса: «он» / «она»
static func he(c: City) -> String:
	return "она" if female(c) else "он"
