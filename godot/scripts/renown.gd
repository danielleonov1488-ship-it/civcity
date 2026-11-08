class_name Renown
## Известность города («Уютный Рим», бесконечная игра, docs/PLAN_COZY.md раздел 8): шкала без конца — растёт каждый
## игровой час от туристов, зрелищ, красоты, достопримечательностей и счастья. За неё — почётные титулы города
## (каждый — +1% счастья всем домам). После «Вечного города» есть куда расти вглубь, а не вширь.
## Только в новой игре (City.cozy_v ≥ 1). Не путать со Славой Легиона (её дают победы).

const TITLES := [
	[0, "Поселение"], [300, "Муниципий"], [1200, "Колония"], [3500, "Город латинского права"],
	[8000, "Друг римского народа"], [16000, "Жемчужина провинции"], [30000, "Светоч империи"], [60000, "Второй Рим"],
]
## Источники в час: гость гостиницы (за сутки) / TOUR_DIV, зрелищная постройка, очки украшений / DECO_DIV (не больше
## DECO_MAX), очки достопримечательностей / SIGHT_DIV, счастье выше HAPPY_FROM — по (счастье − HAPPY_FROM) / HAPPY_DIV
const TOUR_DIV := 6.0
const SHOW_H := 1.5
const DECO_DIV := 60.0
const DECO_MAX := 15.0
const SIGHT_DIV := 20.0
const HAPPY_FROM := 60.0
const HAPPY_DIV := 4.0
const SHOW_TYPES := ["theatre", "odeon", "colosseum", "circus_fl", "arena", "ludus", "thermae", "baths"]


## Римские праздники по игровому календарю (год — CAL_YEAR игровых дней): в свой день город сам празднует сутки —
## наряд улиц и сбор горожан, как на «Играх в честь богов», счастье, известность ×FEST_RENOWN; у каждого праздника —
## своя добавка (bonus): Луперкалии — повозка с семьями чаще, Флоралии — красота считается вдвое, Виналии — туристы
## платят больше, Сатурналии — подарок казне
const CAL_YEAR := 24
const CAL_FESTS := [
	{"day": 3, "id": "lupercalia", "name": "Луперкалии", "bonus": "Повозка с новыми семьями приходит чаще."},
	{"day": 9, "id": "floralia", "name": "Флоралии", "bonus": "Праздник цветов: украшения дают вдвое больше известности."},
	{"day": 15, "id": "vinalia", "name": "Виналии", "bonus": "Праздник молодого вина: гости гостиниц платят на треть больше."},
	{"day": 21, "id": "saturnalia", "name": "Сатурналии", "bonus": "Время подарков: казна получает подарок от горожан."},
]
const FEST_RENOWN := 1.5


## Праздник календаря в день d ({} — обычный день)
static func cal_fest(d: int) -> Dictionary:
	for f: Dictionary in CAL_FESTS:
		if posmod(d, CAL_YEAR) == int(f["day"]):
			return f
	return {}


## Ближайший праздник после дня d: [праздник, через сколько дней]
static func next_fest(d: int) -> Array:
	for k in range(1, CAL_YEAR + 1):
		var f := cal_fest(d + k)
		if not f.is_empty():
			return [f, k]
	return [{}, 0]


static func on(city) -> bool:
	return city != null and int(city.get("cozy_v")) >= 1


## Номер титула при известности v
static func title_idx(v: float) -> int:
	var i := 0
	for k in TITLES.size():
		if v >= float(TITLES[k][0]):
			i = k
	return i


static func title_of(v: float) -> String:
	return String(TITLES[title_idx(v)][1])


## Сколько до следующего титула: [название, нужно] или [] — титулов больше нет
static func next_title(v: float) -> Array:
	var i := title_idx(v)
	return [] if i + 1 >= TITLES.size() else [String(TITLES[i + 1][1]), int(TITLES[i + 1][0])]


## Прибавка счастья всем домам от титула (%)
static func title_happy(city) -> int:
	return title_idx(float(city.renown)) if on(city) else 0


## Известность за час и из чего: [[что, сколько], …]
static func hour_parts(city) -> Array:
	if not on(city):
		return []
	var tour := 0.0
	var show := 0.0
	var deco := 0.0
	var sights := 0.0
	for id in city.buildings:
		var b: Dictionary = city.buildings[id]
		var t := String(b["type"])
		var base := Defs.base_of(t)
		var d: Dictionary = Defs.B.get(t, {})
		if t == "mansio":
			tour += float(Tourism.inn_info(city, b)["guests"]) / TOUR_DIV
		if base in SHOW_TYPES and bool(b.get("active", true)):
			show += SHOW_H
		if String(d.get("kind", "")) == "decor":
			deco += float(d.get("deco", 0))
		if Tourism.SIGHTS.has(base):
			sights += float(Tourism.SIGHTS[base])
	var happy := maxf(0.0, (float(city.stats.get("happy", 0)) - HAPPY_FROM) / HAPPY_DIV)
	var out := []
	var fid := String(city.cal_fest_id) if city.fest_left > 0 else ""
	var deco_k := 2.0 if fid == "floralia" else 1.0
	for e: Array in [["Туристы", tour], ["Зрелища", show], ["Красота", minf(DECO_MAX * deco_k, deco * deco_k / DECO_DIV)], ["Достопримечательности", sights / SIGHT_DIV], ["Счастье горожан", happy]]:
		if float(e[1]) > 0.005:
			out.append(e)
	if fid != "":
		var s := 0.0
		for e: Array in out:
			s += float(e[1])
		out.append(["Праздник: %s" % cal_fest_name(fid), s * (FEST_RENOWN - 1.0)])
	return out


static func cal_fest_name(id: String) -> String:
	for f: Dictionary in CAL_FESTS:
		if String(f["id"]) == id:
			return String(f["name"])
	return ""


static func hour_gain(city) -> float:
	var s := 0.0
	for e: Array in hour_parts(city):
		s += float(e[1])
	return s
