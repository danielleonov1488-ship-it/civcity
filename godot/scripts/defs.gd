class_name Defs
extends RefCounted
## Все числа баланса: постройки, уровни домов, потребности, товары, звания города, задания.
## Перенесено из браузерной версии (js/config.js); расстояния — в метрах (1 клетка браузера = 2,5 м).
## Знания пока заменены званием города: постройки открываются, когда город дорастает до звания (rank).

const DAY_SECONDS := 5.0
const START_MONEY := 3000
const START_GOODS := {"wheat": 40.0}
const BASE_STORAGE := 200.0
const WAREHOUSE_STORAGE := 300.0
const WORKER_SHARE := 0.5
const REFUND := 0.5
const BEAUTY_RADIUS := 15.0
const CROWD_RADIUS := 8.0
const ROAD_COST := {"road": 0.4, "plaza": 0.8, "path": 0.1}     # денариев за клетку 25 см
const CONSUMPTION := {"food": 0.06, "oil": 0.03, "bread": 0.04, "wine": 0.04}
const NEED_HAPPY := {"water": 6, "food": 8, "temple": 5, "oil": 4, "bread": 4, "baths": 5, "wine": 4, "theatre": 5, "forum": 4}
const TREASURY_CAPS := [4000, 6000, 10000, 20000, 40000, 80000, 200000]
const RANKS := [[0, "Деревня"], [50, "Посёлок"], [150, "Городок"], [400, "Город"], [900, "Большой город"], [2000, "Столица провинции"], [5000, "Второй Рим"]]
const CENTER_STAGES := ["Лагерь переселенцев", "Дом старосты", "Курия", "Базилика", "Большая базилика", "Дворец наместника", "Императорский дворец"]
const PLOT_PRICE := [0, 400, 700, 1100, 1600, 2300, 3200, 4500, 6000]

const GOODS := {
	"wheat": {"name": "Пшеница", "price": 2.0}, "fish": {"name": "Рыба", "price": 3.0},
	"olives": {"name": "Оливки", "price": 3.0}, "grapes": {"name": "Виноград", "price": 3.0},
	"bread": {"name": "Хлеб", "price": 6.0}, "oil": {"name": "Масло", "price": 7.0}, "wine": {"name": "Вино", "price": 9.0},
	"wood": {"name": "Дерево", "price": 3.0}, "stone": {"name": "Камень", "price": 4.0}, "marble": {"name": "Мрамор", "price": 16.0},
	"iron": {"name": "Железо", "price": 8.0}, "weapons": {"name": "Оружие", "price": 18.0},
}
const SELL := ["wood", "stone", "marble", "iron", "weapons"]       # излишки покупают купцы
const TRADE_RESERVE := 40.0

const CLASSES := {
	"plebs": {"name": "Плебеи", "color": Color("6b8a2f")},
	"citizens": {"name": "Граждане", "color": Color("2f6f9a")},
	"patricians": {"name": "Патриции", "color": Color("7a3f8c")},
}

const NEED_LABELS := {
	"road": "Дорога у входа", "water": "Вода: колодец или фонтан", "food": "Еда: рынок и пшеница",
	"temple": "Храм поблизости", "oil": "Масло на рынке", "bread": "Хлеб на рынке", "baths": "Термы поблизости",
	"wine": "Вино на рынке", "theatre": "Театр поблизости", "forum": "Форум поблизости",
}

const PLEB_TIERS := [
	{"name": "Пустой участок", "cap": 0, "tax": 0.0, "needs": []},
	{"name": "Хижина", "cls": "plebs", "cap": 4, "tax": 0.12, "needs": ["road"]},
	{"name": "Домик", "cls": "plebs", "cap": 8, "tax": 0.16, "needs": ["road", "water", "food"]},
	{"name": "Инсула", "cls": "citizens", "cap": 16, "tax": 0.3, "needs": ["road", "water", "food", "temple", "oil"], "beauty": 2},
	{"name": "Большая инсула", "cls": "citizens", "cap": 26, "tax": 0.36, "needs": ["road", "water", "food", "temple", "oil", "bread", "baths"], "beauty": 5},
]
const PATRICIAN_TIERS := [
	{"name": "Участок патриция", "cap": 0, "tax": 0.0, "needs": []},
	{"name": "Домус", "cls": "patricians", "cap": 6, "tax": 1.2, "needs": ["road", "water", "food", "temple"], "beauty": 3},
	{"name": "Богатый домус", "cls": "patricians", "cap": 9, "tax": 1.4, "needs": ["road", "water", "food", "temple", "oil", "bread", "baths"], "beauty": 6},
	{"name": "Вилла", "cls": "patricians", "cap": 12, "tax": 1.7, "needs": ["road", "water", "food", "temple", "oil", "bread", "baths", "wine", "theatre"], "beauty": 10},
	{"name": "Дворец", "cls": "patricians", "cap": 16, "tax": 2.2, "needs": ["road", "water", "food", "temple", "oil", "bread", "baths", "wine", "theatre", "forum"], "beauty": 16},
]

## Постройки. w, d — размер в метрах (вдоль фасада и вглубь); radius — в метрах; rank — с какого звания доступно
const B := {
	"house": {"kind": "house", "cat": "housing", "name": "Дом плебеев", "cost": 20, "w": 5.0, "d": 5.0, "tiers": "pleb",
		"desc": "Растёт из хижины в многоэтажную инсулу, когда рядом есть всё нужное. Хижины и домики дают плебеев, инсулы — граждан."},
	"domus": {"kind": "house", "cat": "housing", "name": "Участок патриция", "cost": 310, "w": 10.0, "d": 10.0, "tiers": "patrician", "rank": 2,
		"desc": "Богатые семьи строят домус, виллу, а потом и дворец. Платят много налогов, любят простор и красоту."},
	"farm": {"kind": "producer", "cat": "food", "name": "Пшеничное поле", "cost": 110, "w": 10.0, "d": 10.0,
		"jobs": {"plebs": 4}, "upkeep": 0.5, "produces": {"wheat": 6.0},
		"desc": "Выращивает пшеницу — основную еду и сырьё для пекарен."},
	"grove": {"kind": "producer", "cat": "food", "name": "Оливковая роща", "cost": 95, "w": 10.0, "d": 10.0, "rank": 1,
		"jobs": {"plebs": 3}, "upkeep": 0.5, "produces": {"olives": 4.0}, "desc": "Даёт оливки для маслодавильни."},
	"vineyard": {"kind": "producer", "cat": "food", "name": "Виноградник", "cost": 130, "w": 10.0, "d": 10.0, "rank": 3,
		"jobs": {"plebs": 3}, "upkeep": 0.5, "produces": {"grapes": 4.0}, "desc": "Даёт виноград для винодельни."},
	"bakery": {"kind": "producer", "cat": "food", "name": "Пекарня", "cost": 260, "w": 5.0, "d": 5.0, "rank": 2,
		"jobs": {"citizens": 3}, "upkeep": 0.8, "consumes": {"wheat": 4.0}, "produces": {"bread": 4.0},
		"desc": "Печёт хлеб из пшеницы. Хлеб нужен большим инсулам и патрициям."},
	"oilpress": {"kind": "producer", "cat": "food", "name": "Маслодавильня", "cost": 230, "w": 5.0, "d": 5.0, "rank": 1,
		"jobs": {"plebs": 3}, "upkeep": 0.8, "consumes": {"olives": 3.0}, "produces": {"oil": 3.0},
		"desc": "Давит оливки в масло. Без масла дом не станет инсулой."},
	"winery": {"kind": "producer", "cat": "food", "name": "Винодельня", "cost": 330, "w": 5.0, "d": 5.0, "rank": 3,
		"jobs": {"citizens": 3}, "upkeep": 1.0, "consumes": {"grapes": 3.0}, "produces": {"wine": 3.0},
		"desc": "Делает вино. Без вина патриции не построят виллу."},
	"market": {"kind": "service", "cat": "food", "name": "Рынок", "cost": 190, "w": 10.0, "d": 7.5,
		"jobs": {"plebs": 3}, "upkeep": 1.0, "radius": 35.0, "provides": "market", "beauty": 1,
		"desc": "Раздаёт еду, масло, хлеб и вино домам вокруг."},
	"lumber": {"kind": "producer", "cat": "industry", "name": "Лесопилка", "cost": 40, "w": 7.5, "d": 5.0,
		"jobs": {"plebs": 3}, "upkeep": 0.3, "produces": {"wood": 4.0}, "desc": "Пилит доски — купцы покупают их со склада."},
	"quarry": {"kind": "producer", "cat": "industry", "name": "Каменоломня", "cost": 85, "w": 7.5, "d": 7.5,
		"jobs": {"plebs": 4}, "upkeep": 0.4, "produces": {"stone": 3.0}, "desc": "Добывает камень — его покупают купцы."},
	"smithy": {"kind": "producer", "cat": "industry", "name": "Кузница", "cost": 440, "w": 7.5, "d": 5.0, "rank": 3,
		"jobs": {"citizens": 3}, "upkeep": 1.0, "consumes": {"wood": 1.0}, "produces": {"weapons": 2.0},
		"desc": "Куёт мечи и щиты — для легиона и на продажу."},
	"warehouse": {"kind": "storage", "cat": "industry", "name": "Склад", "cost": 170, "w": 7.5, "d": 5.0,
		"jobs": {"plebs": 2}, "upkeep": 0.5, "storage": 300.0,
		"desc": "Хранилище: ещё 300 каждого товара. Купцы покупают излишки прямо со склада."},
	"well": {"kind": "service", "cat": "services", "name": "Колодец", "cost": 70, "w": 3.5, "d": 3.0,
		"radius": 18.0, "provides": "water", "upkeep": 0.1, "noroad": true,
		"desc": "Даёт воду домам поблизости. Дорога не нужна."},
	"fountain": {"kind": "service", "cat": "services", "name": "Фонтан", "cost": 270, "w": 5.0, "d": 5.0, "rank": 1,
		"radius": 28.0, "provides": "water", "beauty": 3, "upkeep": 0.3, "noroad": true,
		"desc": "Вода для целого квартала и украшение площади."},
	"temple": {"kind": "service", "cat": "services", "name": "Храм Юпитера", "cost": 520, "w": 10.0, "d": 15.0,
		"jobs": {"plebs": 2}, "upkeep": 1.0, "radius": 40.0, "provides": "temple", "beauty": 3,
		"desc": "Жрецы благословляют дома вокруг. Нужен для инсул."},
	"baths": {"kind": "service", "cat": "culture", "name": "Термы", "cost": 880, "w": 12.5, "d": 10.0, "rank": 2,
		"jobs": {"citizens": 4}, "upkeep": 2.0, "radius": 38.0, "provides": "baths", "beauty": 2,
		"desc": "Римские бани с бассейном. Нужны большим инсулам и патрициям."},
	"theatre": {"kind": "service", "cat": "culture", "name": "Театр", "cost": 1000, "w": 15.0, "d": 15.0, "rank": 3,
		"jobs": {"patricians": 2}, "upkeep": 2.0, "radius": 40.0, "provides": "theatre", "beauty": 3,
		"desc": "Комедии и трагедии. Без театра патриции не построят виллу."},
	"forum": {"kind": "service", "cat": "culture", "name": "Форум", "cost": 3200, "w": 15.0, "d": 15.0, "rank": 4,
		"jobs": {"patricians": 4}, "upkeep": 3.0, "radius": 50.0, "provides": "forum", "beauty": 5,
		"desc": "Сердце города: колоннада, статуи и трибуна. Нужен для дворцов."},
	"center": {"kind": "center", "cat": "", "name": "Центр города", "cost": 0, "w": 10.0, "d": 10.0, "fixed": true,
		"desc": "Сюда приезжают переселенцы. Растёт вместе со званием города: лагерь, дом старосты, курия, базилика…"},
	# украшения
	"tree": {"kind": "decor", "cat": "decor", "name": "Дерево", "cost": 12, "w": 2.0, "d": 2.0, "beauty": 1, "desc": "Тенистое дерево у дома."},
	"cypress": {"kind": "decor", "cat": "decor", "name": "Кипарис", "cost": 8, "w": 1.2, "d": 1.2, "beauty": 1, "desc": "Стройный кипарис — римская классика."},
	"palm": {"kind": "decor", "cat": "decor", "name": "Пальма", "cost": 20, "w": 2.0, "d": 2.0, "beauty": 1, "rank": 1, "desc": "Пальма с юга."},
	"flowers": {"kind": "decor", "cat": "decor", "name": "Клумба", "cost": 10, "w": 2.0, "d": 1.2, "beauty": 1, "desc": "Цветы в каменной клумбе."},
	"bush": {"kind": "decor", "cat": "decor", "name": "Куст", "cost": 6, "w": 1.5, "d": 1.5, "beauty": 1, "desc": "Кудрявый куст."},
	"planter": {"kind": "decor", "cat": "decor", "name": "Вазон", "cost": 18, "w": 1.0, "d": 1.0, "beauty": 1, "desc": "Нарядный вазон с цветами."},
	"bench": {"kind": "decor", "cat": "decor", "name": "Скамья", "cost": 25, "w": 2.0, "d": 1.0, "beauty": 1, "desc": "Мраморная скамья — посидеть и поболтать."},
	"brazier": {"kind": "decor", "cat": "decor", "name": "Жаровня", "cost": 25, "w": 0.8, "d": 0.8, "beauty": 1, "light": true, "desc": "Ночью горит и освещает улицу."},
	"bigbrazier": {"kind": "decor", "cat": "decor", "name": "Большая жаровня", "cost": 90, "w": 2.0, "d": 2.0, "beauty": 2, "light": true, "rank": 1, "desc": "Бронзовая чаша с огнём на треноге."},
	"statue": {"kind": "decor", "cat": "decor", "name": "Статуя", "cost": 290, "w": 1.5, "d": 1.5, "beauty": 4, "rank": 1, "desc": "Мраморная статуя на постаменте."},
	"column": {"kind": "decor", "cat": "decor", "name": "Колонна со статуей", "cost": 380, "w": 1.5, "d": 1.5, "beauty": 5, "rank": 2, "desc": "Колонна, увитая розами, со статуей наверху."},
	"lion": {"kind": "decor", "cat": "decor", "name": "Золотой лев", "cost": 600, "w": 2.0, "d": 3.0, "beauty": 6, "rank": 3, "desc": "Золотой лев на постаменте — гордость форума."},
	"sundial": {"kind": "decor", "cat": "decor", "name": "Солнечные часы", "cost": 120, "w": 1.4, "d": 1.4, "beauty": 2, "desc": "Часы для площади."},
	"smallfountain": {"kind": "decor", "cat": "decor", "name": "Питьевой фонтанчик", "cost": 80, "w": 1.2, "d": 1.2, "beauty": 2, "desc": "Маленький фонтан со львиной головой."},
	"pergola": {"kind": "decor", "cat": "decor", "name": "Беседка", "cost": 260, "w": 5.5, "d": 5.5, "beauty": 4, "rank": 2, "desc": "Беседка с куполом — для отдыха."},
	"banner": {"kind": "decor", "cat": "decor", "name": "Знамя", "cost": 40, "w": 1.0, "d": 1.0, "beauty": 2, "desc": "Знамя на шесте."},
	"cart": {"kind": "decor", "cat": "decor", "name": "Телега", "cost": 45, "w": 2.0, "d": 3.3, "beauty": 1, "desc": "Телега с товаром."},
	"goods": {"kind": "decor", "cat": "decor", "name": "Корзины и амфоры", "cost": 15, "w": 1.5, "d": 1.5, "beauty": 1, "desc": "Товар у лавки."},
}

## Категории меню стройки (как в Town to City: снизу посередине)
const CATS := [
	["housing", "Жильё"], ["food", "Еда и рынок"], ["industry", "Ремёсла"], ["services", "Службы"], ["culture", "Культура"], ["decor", "Красота"],
]

## Задания: прогресс считает City.goal_progress(id)
const GOALS := [
	{"id": "houses3", "text": "Поставьте 3 дома у дороги", "need": 3, "reward": 150, "tool": "house",
		"hint": "Подведите дом к дороге — он сам встанет фасадом к ней. Переселенцы приедут из ворот и заселятся."},
	{"id": "well", "text": "Постройте колодец рядом с домами", "need": 1, "reward": 100, "tool": "well",
		"hint": "Без воды хижины не растут. Колодец поит дома внутри круга, который виден при установке."},
	{"id": "farm_market", "text": "Пшеничное поле и рынок", "need": 2, "reward": 200, "tool": "farm",
		"hint": "Поле растит пшеницу, рынок раздаёт её домам вокруг. Ставьте у дороги."},
	{"id": "domik3", "text": "Дождитесь трёх Домиков", "need": 3, "reward": 200,
		"hint": "Хижина станет Домиком, когда у неё есть вода и еда. Нажмите на дом — он покажет, чего не хватает."},
	{"id": "temple", "text": "Постройте Храм Юпитера", "need": 1, "reward": 250, "tool": "temple",
		"hint": "Храм нужен для роста домов в инсулы."},
	{"id": "oil", "text": "Оливковая роща и маслодавильня", "need": 2, "reward": 250, "tool": "grove",
		"hint": "Роща растит оливки, маслодавильня делает из них масло. Дома получают масло через рынок."},
	{"id": "insula", "text": "Вырастите первую Инсулу", "need": 1, "reward": 300, "tool": "flowers",
		"hint": "Инсуле нужны вода, еда, храм, масло и немного красоты: клумбы и деревья рядом."},
	{"id": "pop100", "text": "Соберите 100 жителей", "need": 100, "reward": 400, "tool": "house",
		"hint": "Больше домов — больше налогов. Следите, чтобы хватало еды."},
	{"id": "plot", "text": "Купите соседний участок", "need": 1, "reward": 300,
		"hint": "Нажмите на табличку «Купить» на соседней земле."},
	{"id": "warehouse", "text": "Лесопилка, каменоломня и склад", "need": 3, "reward": 300, "tool": "lumber",
		"hint": "Дерево и камень покупают купцы — прямо со склада, каждый день."},
	{"id": "baths", "text": "Постройте термы", "need": 1, "reward": 400, "tool": "baths",
		"hint": "Термы нужны большим инсулам и патрициям."},
	{"id": "big_insula", "text": "Вырастите Большую инсулу", "need": 1, "reward": 500, "tool": "bakery",
		"hint": "Большой инсуле нужны хлеб и термы рядом. Пекарня печёт хлеб из пшеницы."},
	{"id": "domus", "text": "Поселите патрициев", "need": 1, "reward": 600, "tool": "domus",
		"hint": "Участок патриция 10×10 м растёт в домус, виллу и дворец."},
	{"id": "pop400", "text": "Соберите 400 жителей", "need": 400, "reward": 1000,
		"hint": "Город растёт — покупайте новые участки и украшайте улицы."},
]


static func tiers(type: String) -> Array:
	var t: String = B[type].get("tiers", "")
	return PLEB_TIERS if t == "pleb" else PATRICIAN_TIERS if t == "patrician" else []


static func rank_of(pop: int) -> int:
	var r := 0
	for i in RANKS.size():
		if pop >= int(RANKS[i][0]):
			r = i
	return r
