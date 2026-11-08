class_name Soldiers
## Легион 2.0, этап 1 (docs/LEGION_V2.md 3.2 и решения владельца 6–7 ноября): воины — отдельные люди, не жители.
## Каждый день в Казармы приходят новобранцы (3, с Казармами 6 — 4, с 10 — 5): имя, класс, доблесть 1–5★.
## Счастливый и большой город привлекает лучших (звёзды кандидатов растут со счастьем и уровнем города).
## Воин растёт рангами — тренировкой в Казармах (таймер, денарии из казны); потолок ранга — по звёздам.
## Звёзды и ранг прибавляют бойцу урон и здоровье сверх уровня его рода (уровня здания) — так прежние бои и баланс
## походов остаются, а люди добавляют свою силу и заботу. Павший в бою воин ранен: лечится (Лазарет быстрее),
## раненый в бой не идёт — нужен запас. Насмерть никто не гибнет. Механик воюет баллистой или катапультой.
## Только в новой игре «Уютного Рима» (City.cozy_v): старые города и проверки баланса живут как раньше.

const CLASSES := {
	"legionary": {"name": "легионер", "units": ["legionary"], "home": "barracks"},
	"spearman": {"name": "копейщик", "units": ["spearman"], "home": "spearcamp"},
	"archer": {"name": "лучник", "units": ["archer"], "home": "range"},
	"engineer": {"name": "механик", "units": ["ballista", "catapult"], "home": "ballistae"},
}
const CLASS_IDS := ["legionary", "spearman", "archer", "engineer"]
const CLASS_OF := {"legionary": "legionary", "spearman": "spearman", "archer": "archer", "ballista": "engineer", "catapult": "engineer"}

## Звёзды кандидата: обычный город и лучший (счастливый и большой) — между ними плавно
const STAR_P := [50.0, 30.0, 14.0, 5.0, 1.0]
const STAR_P_BEST := [16.0, 32.0, 30.0, 16.0, 6.0]
const STAR_K := 0.05                       # +5% урона и здоровья за звезду сверх первой
const RANK_K := 0.03                       # +3% за ранг
const RANK_MAX := [0, 2, 4, 6, 8, 10]      # потолок ранга по звёздам
const RANKS := ["новобранец", "рядовой", "бывалый", "ветеран", "декан", "знаменосец", "опцион", "центурион", "старший центурион",
	"примипил", "легат"]
const RECRUIT_COST := [0, 40, 90, 200, 450, 1000]   # денарии за кандидата по звёздам
const ROSTER_BASE := 4                     # мест в Легионе: 4 + уровень Казарм, не больше ROSTER_MAX
const ROSTER_MAX := 16
const HEAL_MIN := 20.0                     # лечение: 20 мин × (ранг + 1), Лазарет — на 6% быстрее за уровень
const HEAL_INF_K := 0.06
const BEDS_BASE := 2                       # коек: 2 + ⌊Лазарет / 2⌋; раненым без койки лечиться вдвое дольше
const DAY_SHIFT := 3 * 3600                # новый день — по Москве

const PRAENOMINA := ["Луций", "Гай", "Марк", "Публий", "Квинт", "Тит", "Секст", "Авл", "Децим", "Гней", "Спурий", "Сервий",
	"Тиберий", "Манний", "Нумерий", "Постум", "Кезон", "Вибий"]
const NOMINA := ["Валерий", "Корнелий", "Юлий", "Клавдий", "Фабий", "Эмилий", "Туллий", "Помпоний", "Антоний", "Сульпиций",
	"Флавий", "Цецилий", "Лициний", "Марий", "Порций", "Семпроний", "Октавий", "Варий", "Рутилий", "Кассий", "Петроний",
	"Аврелий", "Домиций", "Фурий"]
const ORIGINS := ["из Капуи", "из Остии", "с Сабинских гор", "из Кампании", "из Этрурии", "из Апулии", "из Умбрии", "из Лация",
	"с берегов Тибра", "из Самния", "из Пицена", "из Бруттия"]


## Время шага ранга r → r+1, часов (тренировка): 0,5 ч, 1,4 ч, 2,6 ч … 15,8 ч
static func train_h(r: int) -> float:
	return 0.5 * pow(r + 1.0, 1.5)


## Цена шага ранга r → r+1, денариев
static func train_cost(r: int) -> int:
	return int(round(60.0 * pow(r + 1.0, 1.4) / 10.0)) * 10


## Прибавка урона и здоровья воина (доля): звёзды и ранг
static func bonus(s: Dictionary) -> float:
	return STAR_K * (int(s.get("stars", 1)) - 1) + RANK_K * int(s.get("rank", 0))


## Таланты (Легион 2.0, этап 6): на рангах TALENT_RANKS воин выбирает один из двух талантов своего класса.
## Свойства: atk / hp — доли, armor — броня, rate — быстрее удар (доля), range — дальше (м), vs — урон по виду врага,
## set — свойство как у 4 вещей набора (stun, rage, reflect, revive, kite; legion_sim.gd). Сброс — за Славу (TALENT_RESET)
const TALENT_RANKS := [2, 4, 6, 8, 10]
const TALENT_RESET := 10
const TALENTS := {
	"legionary": [
		[{"name": "Щитоносец", "armor": 6.0, "d": "+6 брони"}, {"name": "Рубака", "atk": 0.08, "d": "+8% урона"}],
		[{"name": "Выносливый", "hp": 0.1, "d": "+10% здоровья"}, {"name": "Быстрый клинок", "rate": 0.08, "d": "бьёт на 8% чаще"}],
		[{"name": "Гроза разбойников", "vs": {"human": 1.15}, "d": "+15% урона по людям"}, {"name": "Охотник", "vs": {"beast": 1.15}, "d": "+15% урона по зверям"}],
		[{"name": "Стена щитов", "set": "reflect", "d": "щит отражает 10% урона"}, {"name": "Ярость", "set": "rage", "d": "ниже 30% здоровья +25% урона"}],
		[{"name": "Старый солдат", "set": "revive", "d": "первый раз пав — встаёт с 30%"}, {"name": "Оглушающий удар", "set": "stun", "d": "первый удар оглушает на 1 с"}],
	],
	"spearman": [
		[{"name": "Стойкий", "armor": 6.0, "d": "+6 брони"}, {"name": "Острое копьё", "atk": 0.08, "d": "+8% урона"}],
		[{"name": "Выносливый", "hp": 0.1, "d": "+10% здоровья"}, {"name": "Убийца великанов", "vs": {"giant": 1.2}, "d": "+20% урона по великанам"}],
		[{"name": "Зверолов", "vs": {"beast": 1.2}, "d": "+20% урона по зверям"}, {"name": "Быстрый выпад", "rate": 0.08, "d": "бьёт на 8% чаще"}],
		[{"name": "Ёж", "set": "reflect", "d": "отражает 10% урона"}, {"name": "Ярость", "set": "rage", "d": "ниже 30% здоровья +25% урона"}],
		[{"name": "Старый солдат", "set": "revive", "d": "первый раз пав — встаёт с 30%"}, {"name": "Удар древком", "set": "stun", "d": "первый удар оглушает на 1 с"}],
	],
	"archer": [
		[{"name": "Тугой лук", "atk": 0.08, "d": "+8% урона"}, {"name": "Зоркий", "range": 0.8, "d": "стреляет на 0,8 м дальше"}],
		[{"name": "Выносливый", "hp": 0.1, "d": "+10% здоровья"}, {"name": "Быстрая рука", "rate": 0.08, "d": "стреляет на 8% чаще"}],
		[{"name": "Охотник", "vs": {"beast": 1.15}, "d": "+15% урона по зверям"}, {"name": "Снайпер", "vs": {"ranged": 1.15}, "d": "+15% урона по стрелкам"}],
		[{"name": "Парфянская выучка", "set": "kite", "d": "отходит от мечей и стреляет"}, {"name": "Огненные стрелы", "atk": 0.12, "d": "+12% урона"}],
		[{"name": "Старый солдат", "set": "revive", "d": "первый раз пав — встаёт с 30%"}, {"name": "Меткий глаз", "vs": {"giant": 1.2, "armored": 1.2}, "d": "+20% урона по великанам и латникам"}],
	],
	"engineer": [
		[{"name": "Сильный ворот", "atk": 0.08, "d": "+8% урона"}, {"name": "Щит у станка", "armor": 6.0, "d": "+6 брони"}],
		[{"name": "Быстрая зарядка", "rate": 0.08, "d": "стреляет на 8% чаще"}, {"name": "Выносливый", "hp": 0.1, "d": "+10% здоровья"}],
		[{"name": "Пробивной болт", "vs": {"armored": 1.2}, "d": "+20% урона по латникам"}, {"name": "Гроза великанов", "vs": {"giant": 1.2}, "d": "+20% урона по великанам"}],
		[{"name": "Тяжёлые снаряды", "atk": 0.12, "d": "+12% урона"}, {"name": "Частокол", "set": "reflect", "d": "отражает 10% урона"}],
		[{"name": "Старый солдат", "set": "revive", "d": "первый раз пав — встаёт с 30%"}, {"name": "Мастер осад", "atk": 0.15, "d": "+15% урона"}],
	],
}


## Выбранные таланты воина: [{name, …}, …]
static func talents_of(s: Dictionary) -> Array:
	var out := []
	var tl: Array = s.get("tal", [])
	var tab: Array = TALENTS.get(String(s.get("cls", "")), [])
	for i in mini(tl.size(), tab.size()):
		var c := int(tl[i])
		if c == 0 or c == 1:
			out.append(tab[i][c])
	return out


## Сколько талантов можно выбрать сейчас и не выбрано
static func talent_free(s: Dictionary) -> int:
	var tl: Array = s.get("tal", [])
	var n := 0
	for i in TALENT_RANKS.size():
		if int(s.get("rank", 0)) >= int(TALENT_RANKS[i]) and (i >= tl.size() or int(tl[i]) < 0):
			n += 1
	return n


static func rank_max(s: Dictionary) -> int:
	return int(RANK_MAX[clampi(int(s.get("stars", 1)), 1, 5)])


static func rank_name(r: int) -> String:
	return String(RANKS[clampi(r, 0, RANKS.size() - 1)])


static func stars_text(n: int) -> String:
	return "★".repeat(clampi(n, 0, 5)) + "☆".repeat(5 - clampi(n, 0, 5))


static func class_name_of(cls: String) -> String:
	return String(CLASSES.get(cls, {}).get("name", cls))


## Доля «лучшего города» 0…1: счастье выше 50% и уровень города
static func quality(happy: int, city_lvl: int) -> float:
	return clampf((happy - 50.0) / 40.0, 0.0, 1.0) * 0.6 + clampf(city_lvl / 7.0, 0.0, 1.0) * 0.4


## Вероятности 1–5★ при доле q (сумма 100)
static func star_odds(q: float) -> Array:
	var out := []
	for i in 5:
		out.append(lerpf(float(STAR_P[i]), float(STAR_P_BEST[i]), clampf(q, 0.0, 1.0)))
	return out


static func roll_stars(rng: RandomNumberGenerator, q: float) -> int:
	var p := star_odds(q)
	var x := rng.randf() * 100.0
	for i in 5:
		x -= float(p[i])
		if x <= 0.0:
			return i + 1
	return 1


static func roll_name(rng: RandomNumberGenerator) -> String:
	return "%s %s" % [PRAENOMINA[rng.randi() % PRAENOMINA.size()], NOMINA[rng.randi() % NOMINA.size()]]


## Номер дня (по Москве) для смены новобранцев
static func day_of(t: float) -> int:
	return int(floor((t + DAY_SHIFT) / 86400.0))
