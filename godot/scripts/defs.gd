class_name Defs
extends RefCounted
## Все числа и названия игры — устроено как в Town to City, только Рим:
## три класса жителей (у каждого свой дом), лавки по видам потребностей с дальностью, рабочими и
## производительностью, исследования за отдельную валюту, уровни города от Стоянки до Вечного города.

const DAY_SECONDS := 15.0         # игровой час
const START_MONEY := 2500
const REFUND := 0.5
const ROAD_COST := {"road": 0.25, "plaza": 0.5, "path": 0.06}     # денариев за клетку 25 см
const DECOR_RADIUS := 14.0            # украшения радуют дома в этом радиусе
const DENSITY_RADIUS := 9.0           # теснота: слишком много домов рядом
const DENSITY_FREE := 6

# ---------- жители ----------

const CLASSES := {
	"plebs": {"name": "Плебеи", "one": "Плебеи", "icon": "person", "house": "house_pleb", "tax": 1.4, "per_floor": 4, "work": 0.5,
		"needs": ["food"]},
	"artisans": {"name": "Ремесленники", "one": "Ремесленники", "icon": "hammer", "house": "house_artisan", "tax": 3.1, "per_floor": 3, "work": 0.5,
		"needs": ["food", "clothes", "fun"]},
	"patricians": {"name": "Патриции", "one": "Патриции", "icon": "toga", "house": "house_patrician", "tax": 8.0, "per_floor": 3, "work": 0.35,
		"needs": ["food", "clothes", "fun", "services", "goods"]},
}
const CLASS_ORDER := ["plebs", "artisans", "patricians"]

## Виды потребностей (как вкладки коммерции в Town to City)
const NEEDS := {
	"food": {"name": "Еда", "icon": "food"},
	"clothes": {"name": "Одежда", "icon": "clothes"},
	"fun": {"name": "Развлечения", "icon": "fun"},
	"services": {"name": "Услуги", "icon": "services"},
	"goods": {"name": "Товары", "icon": "goods"},
}
const NEED_ORDER := ["food", "clothes", "fun", "services", "goods"]

## Римские семьи (родовые имена) — у каждой семьи в доме своё имя
const FAMILIES := ["Юлии", "Корнелии", "Клавдии", "Валерии", "Фабии", "Эмилии", "Ливии", "Туллии", "Флавии", "Антонии", "Юнии",
	"Сервилии", "Сульпиции", "Помпеи", "Лицинии", "Порции", "Октавии", "Аврелии", "Кассии", "Марции", "Постумии", "Манлии",
	"Семпронии", "Теренции", "Фурии", "Горации", "Квинкции", "Секстии", "Вибии", "Плавтии", "Петронии", "Домиции"]

# ---------- уровни города ----------

const LEVELS := [
	{"name": "Стоянка", "pop": 0, "happy": 0, "money": 3000, "rp": 300},
	{"name": "Хутор", "pop": 35, "happy": 55, "money": 5000, "rp": 500},
	{"name": "Деревня", "pop": 90, "happy": 58, "money": 8000, "rp": 800},
	{"name": "Посёлок", "pop": 180, "happy": 60, "money": 12000, "rp": 1200},
	{"name": "Городок", "pop": 320, "happy": 62, "money": 20000, "rp": 1600},
	{"name": "Город", "pop": 520, "happy": 64, "money": 30000, "rp": 2000},
	{"name": "Большой город", "pop": 800, "happy": 66, "money": 50000, "rp": 3000},
	{"name": "Вечный город", "pop": 1200, "happy": 68, "money": 100000, "rp": 5000},
]

# ---------- слова для свойств лавок (как в подсказках Town to City) ----------

const RANGE := {1: 13.0, 2: 19.0, 3: 26.0, 4: 36.0, 5: 50.0}          # дальность обслуживания, м
const CAPACITY := {1: 4, 2: 7, 3: 11, 4: 16, 5: 24}                   # сколько домов обслуживает
const WORD := {1: "очень низкая", 2: "низкая", 3: "средняя", 4: "высокая", 5: "очень высокая"}

# ---------- постройки ----------
## kind: house | shop | farm | rp | store | monument | decor | center
## cat: housing | commerce | farming | decor | special;  sub — вкладка коммерции (вид потребности)
## range/cap — уровни 1…5 (см. RANGE, CAPACITY); jobs — {класс: число}; bonus — % счастья домам, которые обслужены
## store — нужен склад рядом (иначе лавке нечем торговать); needs_good — сырьё с полей; unlock — исследование
const B := {
	# жильё: дом растёт этажами сам, когда жителям хорошо
	"house_pleb": {"kind": "house", "cat": "housing", "cls": "plebs", "name": "Дом плебеев", "cost": 100, "variants": 5,
		"desc": "Скромный дом для простых римлян. Растёт на этаж, когда жителям хорошо и открыт новый этаж."},
	"house_artisan": {"kind": "house", "cat": "housing", "cls": "artisans", "name": "Дом ремесленников", "cost": 250, "variants": 5, "unlock": "artisans",
		"desc": "Дом с мастерской внизу. Ремесленникам нужны еда, одежда и развлечения."},
	"house_patrician": {"kind": "house", "cat": "housing", "cls": "patricians", "name": "Домус патрициев", "cost": 600, "variants": 4, "unlock": "patricians",
		"desc": "Богатый дом с портиком и садом. Патриции платят много, но хотят всего и лучшего."},

	# еда
	"stall_fruit": {"kind": "shop", "cat": "commerce", "sub": "food", "name": "Фруктовая лавка", "cost": 45, "bonus": 5, "range": 2, "cap": 3,
		"jobs": {"plebs": 1}, "icon": "food", "desc": "Яблоки, груши и инжир под полотняным навесом."},
	"stall_veg": {"kind": "shop", "cat": "commerce", "sub": "food", "name": "Овощная лавка", "cost": 45, "bonus": 5, "range": 2, "cap": 3,
		"jobs": {"plebs": 1}, "unlock": "stall_veg", "icon": "veg", "desc": "Капуста, лук, бобы и чеснок."},
	"stall_fish": {"kind": "shop", "cat": "commerce", "sub": "food", "name": "Рыбная лавка", "cost": 45, "bonus": 5, "range": 2, "cap": 3,
		"jobs": {"plebs": 1}, "unlock": "stall_fish", "icon": "fish", "desc": "Свежая рыба и гарум — римский соус."},
	"butcher": {"kind": "shop", "cat": "commerce", "sub": "food", "name": "Мясная лавка", "cost": 200, "bonus": 7, "range": 2, "cap": 3,
		"jobs": {"plebs": 2}, "store": true, "unlock": "butcher", "icon": "meat", "desc": "Колбасы и окорока. Товар берёт со склада."},
	"bakery": {"kind": "shop", "cat": "commerce", "sub": "food", "name": "Пекарня", "cost": 450, "bonus": 8, "range": 3, "cap": 4,
		"jobs": {"plebs": 3}, "store": true, "needs_good": "wheat", "unlock": "bakery", "icon": "bread",
		"desc": "Печёт хлеб из пшеницы с полей. Нужны склад рядом и пшеничное поле."},
	"thermopolium": {"kind": "shop", "cat": "commerce", "sub": "food", "name": "Термополий", "cost": 580, "bonus": 9, "range": 4, "cap": 4,
		"jobs": {"artisans": 2}, "store": true, "unlock": "thermopolium", "icon": "meal", "desc": "Римская закусочная: горячая похлёбка из кувшинов в прилавке."},
	"taberna": {"kind": "shop", "cat": "commerce", "sub": "food", "name": "Таверна", "cost": 1100, "bonus": 11, "range": 5, "cap": 5,
		"jobs": {"artisans": 3}, "store": true, "unlock": "taberna", "icon": "mug", "desc": "Столы под навесом, вино и жаркое. Любимое место горожан."},
	# одежда
	"weaver": {"kind": "shop", "cat": "commerce", "sub": "clothes", "name": "Ткацкая лавка", "cost": 150, "bonus": 6, "range": 2, "cap": 3,
		"jobs": {"plebs": 2}, "unlock": "weaver", "icon": "wool", "desc": "Шерсть и лён прямо со станка."},
	"cobbler": {"kind": "shop", "cat": "commerce", "sub": "clothes", "name": "Сапожник", "cost": 220, "bonus": 6, "range": 2, "cap": 3,
		"jobs": {"plebs": 2}, "store": true, "unlock": "cobbler", "icon": "boots", "desc": "Сандалии и калиги на любой вкус."},
	"dyer": {"kind": "shop", "cat": "commerce", "sub": "clothes", "name": "Красильня", "cost": 420, "bonus": 8, "range": 3, "cap": 4,
		"jobs": {"artisans": 2}, "store": true, "unlock": "dyer", "icon": "cape", "desc": "Чаны с краской: шафран, марена и вайда."},
	"fullonica": {"kind": "shop", "cat": "commerce", "sub": "clothes", "name": "Фуллоника", "cost": 520, "bonus": 7, "range": 4, "cap": 5,
		"jobs": {"plebs": 3}, "unlock": "fullonica", "icon": "tshirt", "desc": "Римская прачечная: стирают и сушат тоги всего квартала."},
	"tailor": {"kind": "shop", "cat": "commerce", "sub": "clothes", "name": "Мастерская тог", "cost": 950, "bonus": 10, "range": 4, "cap": 4,
		"jobs": {"artisans": 3}, "store": true, "unlock": "tailor", "icon": "toga", "desc": "Белоснежные тоги с пурпурной каймой."},
	# развлечения
	"musicians": {"kind": "shop", "cat": "commerce", "sub": "fun", "name": "Уличные музыканты", "cost": 90, "bonus": 5, "range": 1, "cap": 2,
		"jobs": {"plebs": 1}, "unlock": "musicians", "icon": "lyre", "desc": "Лира и флейта на углу улицы."},
	"dice": {"kind": "shop", "cat": "commerce", "sub": "fun", "name": "Игра в кости", "cost": 180, "bonus": 6, "range": 2, "cap": 3,
		"jobs": {"plebs": 1}, "unlock": "dice", "icon": "dice", "desc": "Стол под навесом, где кидают кости и спорят."},
	"mimes": {"kind": "shop", "cat": "commerce", "sub": "fun", "name": "Помост мимов", "cost": 360, "bonus": 8, "range": 3, "cap": 4,
		"jobs": {"artisans": 2}, "unlock": "mimes", "icon": "puppet", "desc": "Весёлые сценки на деревянном помосте."},
	"odeon": {"kind": "shop", "cat": "commerce", "sub": "fun", "name": "Одеон", "cost": 900, "bonus": 10, "range": 4, "cap": 5,
		"jobs": {"artisans": 2}, "unlock": "odeon", "icon": "harp", "desc": "Малый театр для музыки и стихов."},
	"theatre": {"kind": "shop", "cat": "commerce", "sub": "fun", "name": "Театр", "cost": 2600, "bonus": 13, "range": 5, "cap": 5,
		"jobs": {"patricians": 2}, "unlock": "theatre", "icon": "fun", "desc": "Комедии и трагедии под открытым небом."},
	# услуги
	"barber": {"kind": "shop", "cat": "commerce", "sub": "services", "name": "Цирюльня", "cost": 250, "bonus": 6, "range": 2, "cap": 3,
		"jobs": {"artisans": 1}, "unlock": "barber", "icon": "razor", "desc": "Бритьё, стрижка и свежие сплетни."},
	"balnea": {"kind": "shop", "cat": "commerce", "sub": "services", "name": "Бани", "cost": 650, "bonus": 8, "range": 3, "cap": 4,
		"jobs": {"plebs": 2}, "unlock": "balnea", "icon": "bath", "desc": "Маленькие бани квартала с тёплым бассейном."},
	"medic": {"kind": "shop", "cat": "commerce", "sub": "services", "name": "Лекарь", "cost": 700, "bonus": 8, "range": 4, "cap": 4,
		"jobs": {"artisans": 2}, "store": true, "unlock": "medic", "icon": "medic", "desc": "Травы, мази и мудрый совет."},
	"baths": {"kind": "shop", "cat": "commerce", "sub": "services", "name": "Термы", "cost": 1800, "bonus": 12, "range": 5, "cap": 5,
		"jobs": {"artisans": 3}, "unlock": "baths", "icon": "water", "desc": "Большие римские бани с колоннами и бассейном."},
	# товары
	"potter": {"kind": "shop", "cat": "commerce", "sub": "goods", "name": "Гончарная", "cost": 300, "bonus": 6, "range": 2, "cap": 3,
		"jobs": {"plebs": 2}, "unlock": "potter", "icon": "pottery", "desc": "Амфоры, кувшины и миски из обожжённой глины."},
	"oilshop": {"kind": "shop", "cat": "commerce", "sub": "goods", "name": "Масляная лавка", "cost": 380, "bonus": 7, "range": 3, "cap": 4,
		"jobs": {"plebs": 2}, "store": true, "needs_good": "olives", "unlock": "oilshop", "icon": "olive",
		"desc": "Оливковое масло для кухни и светильников. Нужна оливковая роща."},
	"lamps": {"kind": "shop", "cat": "commerce", "sub": "goods", "name": "Мастер светильников", "cost": 520, "bonus": 7, "range": 3, "cap": 4,
		"jobs": {"artisans": 2}, "store": true, "unlock": "lamps", "icon": "candle", "desc": "Глиняные и бронзовые лампы."},
	"wineshop": {"kind": "shop", "cat": "commerce", "sub": "goods", "name": "Винная лавка", "cost": 600, "bonus": 9, "range": 3, "cap": 4,
		"jobs": {"artisans": 2}, "store": true, "needs_good": "grapes", "unlock": "wineshop", "icon": "wine",
		"desc": "Фалернское и местное вино. Нужен виноградник."},
	"perfumer": {"kind": "shop", "cat": "commerce", "sub": "goods", "name": "Парфюмер", "cost": 800, "bonus": 9, "range": 4, "cap": 4,
		"jobs": {"artisans": 2}, "store": true, "unlock": "perfumer", "icon": "perfume", "desc": "Розовое масло и мирра в стеклянных флаконах."},
	"jeweler": {"kind": "shop", "cat": "commerce", "sub": "goods", "name": "Ювелир", "cost": 1300, "bonus": 11, "range": 4, "cap": 4,
		"jobs": {"artisans": 2}, "store": true, "unlock": "jeweler", "icon": "ring", "desc": "Кольца, фибулы и жемчужные серьги."},

	# хозяйство
	"farm": {"kind": "farm", "cat": "farming", "name": "Пшеничное поле", "cost": 120, "jobs": {"plebs": 3}, "makes": "wheat", "unlock": "farm",
		"icon": "wheat", "desc": "Даёт пшеницу пекарням."},
	"grove": {"kind": "farm", "cat": "farming", "name": "Оливковая роща", "cost": 150, "jobs": {"plebs": 2}, "makes": "olives", "unlock": "grove",
		"icon": "olive", "desc": "Даёт оливки масляным лавкам."},
	"vineyard": {"kind": "farm", "cat": "farming", "name": "Виноградник", "cost": 200, "jobs": {"plebs": 3}, "makes": "grapes", "unlock": "vineyard",
		"icon": "grapes", "desc": "Даёт виноград винным лавкам."},
	"warehouse": {"kind": "store", "cat": "farming", "name": "Склад", "cost": 300, "range": 4, "jobs": {"plebs": 2}, "unlock": "warehouse",
		"icon": "warehouse", "desc": "Сюда со станции приходят товары, отсюда их разносят по лавкам вокруг. Лавкам со значком склада без него нечем торговать."},
	"scriptorium": {"kind": "rp", "cat": "farming", "name": "Скрипторий", "cost": 180, "rp": 5.0, "jobs": {"plebs": 2},
		"icon": "quill", "desc": "Писцы переписывают свитки — даёт очки исследований."},
	"school": {"kind": "rp", "cat": "farming", "name": "Школа", "cost": 600, "rp": 12.0, "jobs": {"artisans": 2}, "unlock": "school",
		"icon": "teacher", "desc": "Грамматик учит детей — больше очков исследований."},
	"library": {"kind": "rp", "cat": "farming", "name": "Библиотека", "cost": 1500, "rp": 27.0, "jobs": {"artisans": 3}, "unlock": "library",
		"icon": "bookshelf", "desc": "Тысячи свитков — много очков исследований."},
	"academy": {"kind": "rp", "cat": "farming", "name": "Академия", "cost": 3500, "rp": 55.0, "jobs": {"patricians": 3}, "unlock": "academy",
		"icon": "book", "desc": "Философы спорят под колоннадой — очень много очков исследований."},

	# особые: памятники радуют всех вокруг
	"fountain": {"kind": "monument", "cat": "special", "name": "Фонтан", "cost": 300, "bonus": 6, "range": 3, "unlock": "fountain",
		"icon": "water", "desc": "Фонтан для квартала: вода и радость всем вокруг."},
	"temple": {"kind": "monument", "cat": "special", "name": "Храм Юпитера", "cost": 1400, "bonus": 10, "range": 4, "jobs": {"plebs": 2}, "unlock": "temple",
		"icon": "level", "desc": "Храм на подиуме с колоннадой. Значительно повышает счастье жителей поблизости."},
	"forum": {"kind": "monument", "cat": "special", "name": "Форум", "cost": 3200, "bonus": 12, "range": 5, "unlock": "forum",
		"icon": "caesar", "desc": "Сердце города: колоннада, статуи и трибуна."},
	"arch": {"kind": "monument", "cat": "special", "name": "Триумфальная арка", "cost": 2400, "bonus": 10, "range": 4, "unlock": "arch",
		"icon": "castle", "desc": "Арка в честь побед — гордость жителей."},
	"colosseum": {"kind": "monument", "cat": "special", "name": "Амфитеатр", "cost": 9000, "bonus": 18, "range": 5, "jobs": {"patricians": 4}, "unlock": "colosseum",
		"icon": "swords", "desc": "Гладиаторы и звери. Весь город ходит смотреть."},
	"pantheon": {"kind": "monument", "cat": "special", "name": "Пантеон", "cost": 15000, "bonus": 20, "range": 5, "unlock": "pantheon",
		"icon": "level", "desc": "Храм всех богов с огромным куполом."},
	"center": {"kind": "center", "cat": "", "name": "Почтовая станция", "cost": 0, "fixed": true,
		"desc": "Сюда из тоннеля приезжают повозки с переселенцами и товарами."},

	# украшения: очки украшения домам вокруг
	"flowers": {"kind": "decor", "cat": "decor", "name": "Клумба", "cost": 8, "deco": 3, "unlock": "deco_flowers", "desc": "Цветы в каменной клумбе."},
	"planter": {"kind": "decor", "cat": "decor", "name": "Вазон", "cost": 12, "deco": 3, "unlock": "deco_flowers", "desc": "Нарядный вазон с цветами."},
	"tree": {"kind": "decor", "cat": "decor", "name": "Дерево", "cost": 10, "deco": 3, "unlock": "deco_trees", "desc": "Тенистое дерево."},
	"cypress": {"kind": "decor", "cat": "decor", "name": "Кипарис", "cost": 8, "deco": 2, "unlock": "deco_trees", "desc": "Стройный кипарис — римская классика."},
	"palm": {"kind": "decor", "cat": "decor", "name": "Пальма", "cost": 15, "deco": 3, "unlock": "deco_trees", "desc": "Пальма с юга."},
	"bush": {"kind": "decor", "cat": "decor", "name": "Куст", "cost": 5, "deco": 2, "unlock": "deco_trees", "desc": "Кудрявый куст."},
	"bench": {"kind": "decor", "cat": "decor", "name": "Скамья", "cost": 15, "deco": 3, "desc": "Посидеть и поболтать."},
	"well": {"kind": "decor", "cat": "decor", "name": "Колодец", "cost": 40, "deco": 4, "desc": "Колодец с кувшинами."},
	"goods": {"kind": "decor", "cat": "decor", "name": "Корзины и амфоры", "cost": 10, "deco": 2, "desc": "Товар у лавки."},
	"cart": {"kind": "decor", "cat": "decor", "name": "Телега", "cost": 30, "deco": 2, "desc": "Телега с товаром."},
	"brazier": {"kind": "decor", "cat": "decor", "name": "Жаровня", "cost": 25, "deco": 3, "light": true, "unlock": "deco_metal", "desc": "Ночью горит и освещает улицу."},
	"bigbrazier": {"kind": "decor", "cat": "decor", "name": "Большая жаровня", "cost": 70, "deco": 5, "light": true, "unlock": "deco_metal", "desc": "Бронзовая чаша с огнём."},
	"banner": {"kind": "decor", "cat": "decor", "name": "Знамя", "cost": 30, "deco": 3, "unlock": "deco_metal", "desc": "Знамя на шесте."},
	"statue": {"kind": "decor", "cat": "decor", "name": "Статуя", "cost": 220, "deco": 9, "unlock": "deco_stone", "desc": "Мраморная статуя на постаменте."},
	"column": {"kind": "decor", "cat": "decor", "name": "Колонна со статуей", "cost": 300, "deco": 10, "unlock": "deco_stone", "desc": "Колонна, увитая розами."},
	"lion": {"kind": "decor", "cat": "decor", "name": "Золотой лев", "cost": 500, "deco": 12, "unlock": "deco_stone", "desc": "Лев на постаменте."},
	"sundial": {"kind": "decor", "cat": "decor", "name": "Солнечные часы", "cost": 100, "deco": 5, "unlock": "deco_stone", "desc": "Часы для площади."},
	"smallfountain": {"kind": "decor", "cat": "decor", "name": "Фонтанчик", "cost": 70, "deco": 5, "unlock": "fountain", "desc": "Питьевой фонтанчик со львиной головой."},
	"pergola": {"kind": "decor", "cat": "decor", "name": "Беседка", "cost": 200, "deco": 8, "unlock": "deco_stone", "desc": "Беседка с куполом."},
	"duck": {"kind": "decor", "cat": "decor", "name": "Утки", "cost": 15, "deco": 3, "unlock": "animals", "water": true, "desc": "Утки плавают по пруду."},
	"swan": {"kind": "decor", "cat": "decor", "name": "Лебедь", "cost": 25, "deco": 4, "unlock": "animals", "water": true, "desc": "Белый лебедь на воде."},
}

## Разделы меню стройки (снизу посередине) и вкладки коммерции
const CATS := [["housing", "Жильё", "housing"], ["commerce", "Коммерция", "commerce"], ["farming", "Хозяйство и науки", "farming"],
	["decor", "Украшения", "decor"], ["special", "Особые постройки", "special"]]

# ---------- исследования ----------
## Каждый уровень города открывает свой раздел. unlock — что даёт (постройку открывает её ключ в B.unlock)
const RESEARCH := [
	{"id": "stall_veg", "lvl": 0, "name": "Овощная лавка", "cost": 30, "icon": "veg"},
	{"id": "stall_fish", "lvl": 0, "name": "Рыбная лавка", "cost": 30, "icon": "fish"},
	{"id": "reach1", "lvl": 0, "name": "Больший охват", "cost": 90, "icon": "arrow", "after": "stall_veg",
		"desc": "Лавки с едой обслуживают дома на треть дальше."},
	{"id": "farm", "lvl": 0, "name": "Пшеничное поле", "cost": 50, "icon": "wheat"},
	{"id": "deco_flowers", "lvl": 0, "name": "Цветы и вазоны", "cost": 25, "icon": "daisy"},
	{"id": "deco_trees", "lvl": 0, "name": "Деревья и кусты", "cost": 25, "icon": "tree"},
	{"id": "musicians", "lvl": 0, "name": "Уличные музыканты", "cost": 60, "icon": "lyre"},

	{"id": "floor2", "lvl": 1, "name": "Второй жилой этаж", "cost": 150, "icon": "housing",
		"desc": "Дома, где жителям хорошо, сами надстраивают второй этаж."},
	{"id": "weaver", "lvl": 1, "name": "Ткацкая лавка", "cost": 90, "icon": "wool"},
	{"id": "warehouse", "lvl": 1, "name": "Склад", "cost": 100, "icon": "warehouse"},
	{"id": "butcher", "lvl": 1, "name": "Мясная лавка", "cost": 120, "icon": "meat", "after": "warehouse"},
	{"id": "cobbler", "lvl": 1, "name": "Сапожник", "cost": 130, "icon": "boots", "after": "weaver"},
	{"id": "bakery", "lvl": 1, "name": "Пекарня", "cost": 180, "icon": "bread", "after": "warehouse"},
	{"id": "fountain", "lvl": 1, "name": "Фонтаны", "cost": 140, "icon": "water"},
	{"id": "animals", "lvl": 1, "name": "Утки и лебеди", "cost": 50, "icon": "swan"},

	{"id": "artisans", "lvl": 2, "name": "Класс ремесленников", "cost": 250, "icon": "hammer",
		"desc": "Открывает дома ремесленников. Им нужны еда, одежда и развлечения."},
	{"id": "dice", "lvl": 2, "name": "Игра в кости", "cost": 140, "icon": "dice"},
	{"id": "barber", "lvl": 2, "name": "Цирюльня", "cost": 180, "icon": "razor"},
	{"id": "thermopolium", "lvl": 2, "name": "Термополий", "cost": 230, "icon": "meal"},
	{"id": "school", "lvl": 2, "name": "Школа", "cost": 260, "icon": "teacher"},
	{"id": "grove", "lvl": 2, "name": "Оливковая роща", "cost": 150, "icon": "olive"},
	{"id": "oilshop", "lvl": 2, "name": "Масляная лавка", "cost": 190, "icon": "amphora", "after": "grove"},
	{"id": "roads2", "lvl": 2, "name": "Площади из плитки", "cost": 110, "icon": "plaza", "desc": "Новое покрытие дорог — узорная плитка."},
	{"id": "deco_stone", "lvl": 2, "name": "Каменные украшения", "cost": 160, "icon": "mona"},
	{"id": "store1", "lvl": 2, "name": "Больше носильщиков", "cost": 200, "icon": "warehouse", "after": "warehouse",
		"desc": "Склад разносит товары вдвое дальше."},

	{"id": "floor3", "lvl": 3, "name": "Третий жилой этаж", "cost": 400, "icon": "housing", "after": "floor2",
		"desc": "Самые счастливые дома дорастают до трёх этажей."},
	{"id": "dyer", "lvl": 3, "name": "Красильня", "cost": 300, "icon": "cape"},
	{"id": "potter", "lvl": 3, "name": "Гончарная", "cost": 260, "icon": "pottery"},
	{"id": "mimes", "lvl": 3, "name": "Помост мимов", "cost": 280, "icon": "puppet"},
	{"id": "temple", "lvl": 3, "name": "Храм", "cost": 380, "icon": "level"},
	{"id": "fullonica", "lvl": 3, "name": "Фуллоника", "cost": 320, "icon": "tshirt"},
	{"id": "deco_metal", "lvl": 3, "name": "Жаровни и знамёна", "cost": 180, "icon": "candle"},
	{"id": "vault1", "lvl": 3, "name": "Новое хранилище денег", "cost": 300, "icon": "money", "desc": "Казна вмещает вдвое больше."},

	{"id": "patricians", "lvl": 4, "name": "Класс патрициев", "cost": 600, "icon": "toga",
		"desc": "Открывает домусы патрициев. Им нужно всё: еда, одежда, развлечения, услуги и товары."},
	{"id": "balnea", "lvl": 4, "name": "Бани", "cost": 420, "icon": "bath"},
	{"id": "lamps", "lvl": 4, "name": "Мастер светильников", "cost": 420, "icon": "candle"},
	{"id": "library", "lvl": 4, "name": "Библиотека", "cost": 600, "icon": "bookshelf", "after": "school"},
	{"id": "vineyard", "lvl": 4, "name": "Виноградник", "cost": 280, "icon": "grapes"},
	{"id": "wineshop", "lvl": 4, "name": "Винная лавка", "cost": 380, "icon": "wine", "after": "vineyard"},
	{"id": "odeon", "lvl": 4, "name": "Одеон", "cost": 560, "icon": "harp"},
	{"id": "taberna", "lvl": 4, "name": "Таверна", "cost": 520, "icon": "mug"},
	{"id": "research1", "lvl": 4, "name": "Новые полки для свитков", "cost": 450, "icon": "scroll", "desc": "Очков исследований помещается вдвое больше."},

	{"id": "perfumer", "lvl": 5, "name": "Парфюмер", "cost": 700, "icon": "perfume"},
	{"id": "medic", "lvl": 5, "name": "Лекарь", "cost": 620, "icon": "medic"},
	{"id": "tailor", "lvl": 5, "name": "Мастерская тог", "cost": 800, "icon": "toga"},
	{"id": "baths", "lvl": 5, "name": "Термы", "cost": 900, "icon": "water", "after": "balnea"},
	{"id": "jeweler", "lvl": 5, "name": "Ювелир", "cost": 1000, "icon": "ring"},
	{"id": "forum", "lvl": 5, "name": "Форум", "cost": 1200, "icon": "caesar"},
	{"id": "taxes1", "lvl": 5, "name": "Налоги для богатых", "cost": 900, "icon": "coins", "desc": "Патриции платят на четверть больше."},

	{"id": "theatre", "lvl": 6, "name": "Театр", "cost": 1500, "icon": "fun", "after": "odeon"},
	{"id": "arch", "lvl": 6, "name": "Триумфальная арка", "cost": 1300, "icon": "castle"},
	{"id": "academy", "lvl": 6, "name": "Академия", "cost": 1600, "icon": "book", "after": "library"},
	{"id": "vault2", "lvl": 6, "name": "Подвалы казны", "cost": 1200, "icon": "money", "after": "vault1", "desc": "Казна вмещает ещё вдвое больше."},

	{"id": "colosseum", "lvl": 7, "name": "Амфитеатр", "cost": 3200, "icon": "swords"},
	{"id": "pantheon", "lvl": 7, "name": "Пантеон", "cost": 4500, "icon": "level"},
]

## Цвета домов: штукатурка подкрашивается (у соседей — всегда разные)
const PALETTE := [
	{"name": "Охра", "c": Color(1.0, 0.78, 0.47)},
	{"name": "Терракота", "c": Color(0.98, 0.6, 0.44)},
	{"name": "Розовый", "c": Color(1.0, 0.72, 0.68)},
	{"name": "Лимонный", "c": Color(1.0, 0.9, 0.56)},
	{"name": "Голубой", "c": Color(0.66, 0.82, 0.95)},
	{"name": "Шалфей", "c": Color(0.76, 0.9, 0.66)},
	{"name": "Белый", "c": Color(1.0, 1.0, 1.0)},
	{"name": "Персиковый", "c": Color(1.0, 0.82, 0.64)},
	{"name": "Сиреневый", "c": Color(0.86, 0.78, 0.95)},
	{"name": "Песочный", "c": Color(0.95, 0.86, 0.7)},
]


static func research(id: String) -> Dictionary:
	for r in RESEARCH:
		if r["id"] == id:
			return r
	return {}


static func range_m(d: Dictionary) -> float:
	return float(RANGE.get(int(d.get("range", 0)), 0.0))


static func floors_max(cls: String) -> int:
	return 2 if cls == "patricians" else 3
