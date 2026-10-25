class_name Residents
extends RefCounted
## Жители с именами (этап 6.1 плана от 24.10). У каждого члена семьи — запись, которая сохраняется:
##   {pn: имя, sx: 0 мужчина / 1 женщина, age: 0 ребёнок / 1 взрослый / 2 старик, sd: зерно облика,
##    job: где работает (id постройки, нет — без работы), look: облик (только если поменялся — этап 6.5)}.
## Запись лежит в семье (дом: b.families[i].m, площадь: city.arrivals[i].m, идут в дом: city.pending[имя].m), её же
## держит житель на улице (r.m) — имя, пол, возраст и облик не меняются при загрузке (раньше сын мог стать дочкой).
## Старые сохранения: записи создаются один раз — по имени семьи и номеру дома (всегда одинаково), потом сохраняются.
## Та же запись и облик (Citizen.roll_look / build) пригодятся своему герою (Д11).

## Мужские имена: те же, что у героев историй (StoryDefs.BOYS), и ещё четыре
const MEN := ["Луций", "Гай", "Марк", "Тит", "Квинт", "Публий", "Авл", "Децим", "Секст", "Гней", "Сервий", "Тиберий", "Спурий", "Нумерий"]
## Дочери — по роду, с прозвищем по порядку: «Юлия Младшая», «Юлия Терция», …
const DAUGHTER := ["Младшая", "Терция", "Кварта", "Квинта"]
const CHILD_P := 0.6                  # третий и следующие в семье — ребёнок с такой долей (как было)
const ELDER_P := 0.5                  # взрослый третий и дальше — старик (дедушка, бабушка) с такой долей

## Кем работает: тип постройки → [он, она]
const JOB := {
	"stall_fruit": ["торговец фруктами", "торговка фруктами"], "stall_veg": ["зеленщик", "зеленщица"],
	"stall_fish": ["рыботорговец", "торговка рыбой"], "butcher": ["мясник", "продавщица мясной лавки"],
	"bakery": ["пекарь", "пекарша"], "thermopolium": ["повар", "повариха"], "taberna": ["трактирщик", "трактирщица"],
	"weaver": ["ткач", "ткачиха"], "cobbler": ["сапожник", "сапожница"], "dyer": ["красильщик", "красильщица"],
	"fullonica": ["сукновал", "прачка"], "tailor": ["портной", "швея"], "musicians": ["уличный музыкант", "уличная музыкантша"],
	"dice": ["хозяин игры в кости", "хозяйка игры в кости"], "mimes": ["мим", "актриса-мим"], "odeon": ["музыкант одеона", "певица одеона"],
	"theatre": ["актёр", "актриса"], "barber": ["цирюльник", "цирюльница"], "balnea": ["банщик", "банщица"],
	"medic": ["лекарь", "травница"], "baths": ["служитель терм", "служительница терм"], "potter": ["гончар", "мастерица-гончар"],
	"oilshop": ["торговец маслом", "торговка маслом"], "lamps": ["мастер светильников", "мастерица светильников"],
	"wineshop": ["виноторговец", "виноторговка"], "perfumer": ["парфюмер", "парфюмерша"], "jeweler": ["ювелир", "мастерица-ювелир"],
	"farm": ["земледелец", "жница"], "grove": ["оливковод", "сборщица олив"], "vineyard": ["виноградарь", "сборщица винограда"],
	"warehouse": ["кладовщик", "кладовщица"], "scriptorium": ["писец", "переписчица"], "school": ["учитель", "учительница"],
	"library": ["библиотекарь", "хранительница свитков"], "academy": ["философ", "наставница"], "temple": ["жрец", "жрица"],
	"forum": ["служитель форума", "служительница форума"], "colosseum": ["служитель амфитеатра", "служительница амфитеатра"],
	"pantheon": ["жрец Пантеона", "жрица Пантеона"], "barracks": ["легионер", "легионер"], "range": ["лучник", "лучница"],
	"forge": ["кузнец", "кузнец"], "infirmary": ["лекарь Легиона", "сестра милосердия"], "armory": ["оружейник", "оружейница"],
}


## Записи семьи fam из n человек класса cls, всегда одинаковые для того же key (номер дома, час приезда…).
## have — уже есть первые записи (семью дополняют): дальше по тем же правилам, имена не повторяются
static func gen(fam: String, n: int, cls: String, key: int, have: Array = []) -> Array:
	var rg := RandomNumberGenerator.new()
	rg.seed = hash([fam, cls, key])
	var out := have.duplicate()
	for i in range(out.size(), n):
		var m := {}
		if i == 0:
			m = {"sx": 0, "age": 1}
		elif i == 1:
			m = {"sx": 1, "age": 1}
		else:
			var child := rg.randf() < CHILD_P
			var sx := 1 if rg.randf() < 0.5 else 0
			var age := 0 if child else (2 if rg.randf() < ELDER_P else 1)
			m = {"sx": sx, "age": age}
		m["sd"] = rg.randi()
		m["pn"] = _name_for(fam, m, out, rg)
		out.append(m)
	return out


## Имя нового члена семьи: отец — StoryDefs.father, первый сын — StoryDefs.boy (тот же, что в историях),
## дед — StoryDefs.elder; женщины — по роду («Юлия»), дочери — «Юлия Младшая», бабушка — «Юлия Старшая»
static func _name_for(fam: String, m: Dictionary, have: Array, rg: RandomNumberGenerator) -> String:
	var used := {}
	for o: Dictionary in have:
		used[String(o.get("pn", ""))] = true
	var nf := StoryDefs.nomen_f(fam)
	if int(m["sx"]) == 1:
		if int(m["age"]) == 2:
			return _free(nf + " Старшая", used)
		if not used.has(nf) and int(m["age"]) == 1 and have.size() <= 1:
			return nf
		for t: String in DAUGHTER:
			if not used.has(nf + " " + t):
				return nf + " " + t
		return _free(nf, used)
	# имя мальчика из историй — только маленькому сыну (первому); взрослый сын его не занимает и случайно из MEN
	var boy := StoryDefs.boy(fam)
	var want := ""
	if have.is_empty():
		want = StoryDefs.father(fam)
	elif int(m["age"]) == 2:
		want = StoryDefs.elder(fam)
	elif int(m["age"]) == 0:
		want = boy
	if want != "" and not used.has(want):
		return want
	var k0 := rg.randi() % MEN.size()
	for k in MEN.size():
		var nm: String = MEN[(k0 + k) % MEN.size()]
		if not used.has(nm) and (int(m["age"]) == 0 or nm != boy):
			return nm
	return want if want != "" else boy


static func _free(nm: String, used: Dictionary) -> String:
	if not used.has(nm):
		return nm
	for k in range(2, 9):
		var v := "%s %d" % [nm, k]
		if not used.has(v):
			return v
	return nm


## Семья f ({name, n, cls?, m?}): записей ровно n (нет — создать, мало — дополнить, много — лишние ушли);
## числа из сохранения (JSON отдаёт дробные) — целыми. Вернёт f.m
static func fit(f: Dictionary, key: int, cls := "") -> Array:
	var n := int(f.get("n", 0))
	var ms: Array = f.get("m", []) if typeof(f.get("m", [])) == TYPE_ARRAY else []
	for m in ms:
		norm(m)
	if ms.size() > n:
		ms = ms.slice(0, n)
	elif ms.size() < n:
		ms = gen(String(f.get("name", "")), n, cls if cls != "" else String(f.get("cls", "plebs")), key, ms)
	f["m"] = ms
	return ms


## Запись из сохранения — с целыми числами
static func norm(m: Dictionary) -> void:
	for k: String in ["sx", "age", "sd"]:
		m[k] = int(m.get(k, 0))
	if m.has("job"):
		m["job"] = int(m["job"])
	m["pn"] = String(m.get("pn", ""))
	if m.has("look") and typeof(m["look"]) == TYPE_DICTIONARY:
		Citizen.norm_look(m["look"])
	elif m.has("look"):
		m.erase("look")


## Ключ для новой семьи (имя, класс, номер приезда) — чтобы одна и та же семья в той же игре вышла той же
static func key_new(city: City, fam: String) -> int:
	return hash([fam, city.day, city.hour_n, city.settled_total, city.arrivals.size()])


## Облик члена семьи (этап 6.5): свой, если менялся, иначе — из зерна по прежним правилам (как раньше на улице)
static func look_of(m: Dictionary, cls: String) -> Dictionary:
	if m.has("look"):
		return m["look"]
	var rr := RandomNumberGenerator.new()
	rr.seed = int(m.get("sd", 1))
	var lk := Citizen.roll_look(rr, int(m.get("sx", 0)) == 1, int(m.get("age", 1)) == 0, cls == "patricians", "", cls)
	if int(m.get("age", 1)) == 2:
		lk["hc"] = "S"                     # старик — седой
	return lk


## «Гай Юлий» (мужчины — имя и род), «Юлия Младшая» (женщины — по роду, как у римлян)
static func full_name(m: Dictionary, fam: String) -> String:
	var pn := String(m.get("pn", ""))
	if int(m.get("sx", 0)) == 1:
		return pn
	return "%s %s" % [pn, StoryDefs.nomen(fam)]


## Кто в семье: «отец семьи», «мать», «сын», «дочь», «дедушка», «бабушка», «взрослый сын»…
static func role(m: Dictionary, ms: Array) -> String:
	var i := ms.find(m)
	var sx := int(m.get("sx", 0))
	var age := int(m.get("age", 1))
	if age == 2:
		return "бабушка" if sx == 1 else "дедушка"
	if age == 0:
		return "дочь" if sx == 1 else "сын"
	if i < 0:
		return "жительница" if sx == 1 else "житель"     # семьи не нашли — главой и сыном не называем
	var kids := false
	for o: Dictionary in ms:
		kids = kids or int(o.get("age", 1)) == 0
	if i == 0:
		return "отец семьи" if ms.size() > 1 else "глава семьи"
	if i == 1 and sx == 1 and age == 1:
		return "мать семьи" if kids else "жена"
	return "взрослая дочь" if sx == 1 else "взрослый сын"


## Кем работает в постройке типа t: «пекарь», «ткачиха»; неизвестный тип — пусто
static func job_noun(t: String, female: bool) -> String:
	var e: Array = JOB.get(t, [])
	if e.is_empty():
		return ""
	return String(e[1] if female else e[0])


## Отпечаток записей семей (проверки: две загрузки подряд — то же самое)
static func members_hash(city: City) -> String:
	var ids: Array = city.buildings.keys()
	ids.sort()
	var s := ""
	for id in ids:
		for f: Dictionary in city.buildings[id].get("families", []):
			s += "%d:%s:" % [int(id), String(f.get("name", ""))]
			for m: Dictionary in f.get("m", []):
				s += "%s,%d,%d,%d;" % [String(m.get("pn", "")), int(m.get("sx", 0)), int(m.get("age", 0)), int(m.get("sd", 0))]
	for f: Dictionary in city.arrivals:
		s += "a:%s:" % String(f.get("name", ""))
		for m: Dictionary in f.get("m", []):
			s += "%s,%d,%d,%d;" % [String(m.get("pn", "")), int(m.get("sx", 0)), int(m.get("age", 0)), int(m.get("sd", 0))]
	return s.sha256_text()
