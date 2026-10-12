class_name Defs
extends RefCounted
## Все числа и названия игры — устроено как в Town to City, только Рим:
## три класса жителей (у каждого свой дом), лавки по видам потребностей с дальностью, рабочими и
## производительностью, исследования за отдельную валюту, уровни города от Стоянки до Вечного города.

const DAY_SECONDS := 15.0         # игровой час
const START_MONEY := 2500
const REFUND := 0.5
## денариев за клетку 25 см (16 клеток на м²): мостовая 40 м кистью 2,0 (4 м шириной) ≈ 150 ден.,
## тропинка — вчетверо дешевле, площадь — в полтора раза дороже мостовой
const ROAD_COST := {"road": 0.055, "plaza": 0.083, "path": 0.014}
const DECOR_RADIUS := 14.0            # украшения радуют дома в этом радиусе
const DECO_RATE := 0.5                # +1% счастья за каждые 2 очка украшения (не больше deco_max класса)
const DENSITY_RADIUS := 9.0           # теснота: слишком много домов рядом
const DENSITY_FREE := 12              # столько соседей в радиусе — ещё не тесно (улица с узкими домами по обе стороны)
const DENSITY_STEP := 2               # −2% за каждого лишнего соседа
const DENSITY_MAX := 16               # теснота отнимает не больше
const MISSING_PENALTY := 10           # −10% за каждый вид нужной лавки, которой нет рядом
## Этажи покупает игрок в карточке дома (как в Town to City): нужен открытый этаж, полный дом и счастье
const FLOOR_HAPPY := {2: 70, 3: 80}   # счастье дома, с которого можно надстроить этаж
const FLOOR_PRICE := {"plebs": {2: 120, 3: 220}, "artisans": {2: 300, 3: 520}, "patricians": {2: 900, 3: 1500}}
const FLOOR_RESEARCH := {2: "floor2", 3: "floor3"}
## Приезд семей: первые ARRIVE_FREE семей едут всегда, дальше — только пока счастье города не ниже ARRIVE_HAPPY
const ARRIVE_HAPPY := 60
const ARRIVE_FREE := 3

# ---------- жители ----------

## base — счастье дома без лавок и украшений; deco_max — сколько могут дать украшения (см. City.compute)
const CLASSES := {
	"plebs": {"name": "Плебеи", "one": "Плебеи", "icon": "person", "house": "house_pleb", "tax": 1.4, "per_floor": 4, "work": 0.5,
		"needs": ["food"], "base": 44, "deco_max": 12},
	"artisans": {"name": "Ремесленники", "one": "Ремесленники", "icon": "hammer", "house": "house_artisan", "tax": 3.1, "per_floor": 3, "work": 0.5,
		"needs": ["food", "clothes", "fun"], "base": 41, "deco_max": 14},
	"patricians": {"name": "Патриции", "one": "Патриции", "icon": "toga", "house": "house_patrician", "tax": 8.0, "per_floor": 3, "work": 0.35,
		"needs": ["food", "clothes", "fun", "services", "goods"], "base": 38, "deco_max": 16},
}
const CLASS_ORDER := ["plebs", "artisans", "patricians"]
const ARRIVE_HOURS := 4.0            # повозка с новыми семьями — раз в столько игровых часов
const ARRIVAL_MAX := [2, 2, 3, 3, 4, 4, 5, 6]   # сколько семей может ждать жилья (по уровню города)
const FAMILY_SIZE := {"plebs": [2, 4], "artisans": [2, 3], "patricians": [1, 3]}

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
const COGNOMENS := ["Максимы", "Руфы", "Галлы", "Флакки", "Лонги", "Бруты", "Крассы", "Пульхры", "Нервы", "Сабины", "Цинны",
	"Лепиды", "Метеллы", "Катоны", "Сципионы", "Гракхи", "Мурены", "Бальбы", "Северы", "Приски", "Агриппы", "Варроны"]

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
	# жильё: этаж покупает игрок в карточке дома, когда дом полон и жителям хорошо (Defs.FLOOR_HAPPY)
	"house_pleb": {"kind": "house", "cat": "housing", "cls": "plebs", "name": "Дом плебеев", "cost": 100, "variants": 5,
		"desc": "Скромный дом для простых римлян. Когда дом полон и жители счастливы, в его карточке можно надстроить этаж — для новой семьи."},
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
	"scriptorium": {"kind": "rp", "cat": "farming", "name": "Скрипторий", "cost": 180, "rp": 2.0, "jobs": {"plebs": 2},
		"icon": "quill", "desc": "Писцы переписывают свитки — даёт очки исследований."},
	"school": {"kind": "rp", "cat": "farming", "name": "Школа", "cost": 600, "rp": 5.0, "jobs": {"artisans": 2}, "unlock": "school",
		"icon": "teacher", "desc": "Грамматик учит детей — больше очков исследований."},
	"library": {"kind": "rp", "cat": "farming", "name": "Библиотека", "cost": 1500, "rp": 11.0, "jobs": {"artisans": 3}, "unlock": "library",
		"icon": "bookshelf", "desc": "Тысячи свитков — много очков исследований."},
	"academy": {"kind": "rp", "cat": "farming", "name": "Академия", "cost": 3500, "rp": 22.0, "jobs": {"patricians": 3}, "unlock": "academy",
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
		"desc": "Сюда по большой дороге приезжают повозки с переселенцами и товарами."},

	# украшения: очки украшения домам вокруг. Каждый облик — своя карточка: что выбрал, то и встанет
	# (облик не зависит ни от места, ни от цвета). base — вид украшения (просьбы горожан, «посидеть на скамье»
	# считают все его облики), look — номер облика в CatDecor, color — постоянный цвет штукатурки облика (по умолчанию 0).
	# У первого облика ключ — старый тип: старые сохранения показывают его.
	# цветы
	"flowers": {"kind": "decor", "cat": "decor", "sub": "plants", "name": "Клумба в каменном ящике", "cost": 8, "deco": 3, "unlock": "deco_flowers", "desc": "Цветы в длинном каменном ящике."},
	"flowers_2": {"kind": "decor", "cat": "decor", "sub": "plants", "base": "flowers", "look": 1, "name": "Круглая клумба", "cost": 8, "deco": 3, "unlock": "deco_flowers", "desc": "Ковёр цветов в круглом бортике из камней."},
	"flowers_3": {"kind": "decor", "cat": "decor", "sub": "plants", "base": "flowers", "look": 2, "name": "Каменная цветочница", "cost": 10, "deco": 3, "unlock": "deco_flowers", "desc": "Высокая каменная цветочница, рядом горшочек с цветами."},
	"planter": {"kind": "decor", "cat": "decor", "sub": "plants", "name": "Ваза на камне", "cost": 12, "deco": 3, "unlock": "deco_flowers", "desc": "Расписная терракотовая ваза с цветами на круглом камне."},
	"planter_2": {"kind": "decor", "cat": "decor", "sub": "plants", "base": "planter", "look": 1, "name": "Две греческие вазы", "cost": 12, "deco": 3, "unlock": "deco_flowers", "desc": "Большая и маленькая расписные вазы с цветами."},
	"planter_3": {"kind": "decor", "cat": "decor", "sub": "plants", "base": "planter", "look": 2, "name": "Пифос и кувшины", "cost": 14, "deco": 3, "unlock": "deco_flowers", "desc": "Карликовая пальма в глиняном пифосе, ваза с цветами и кувшин."},
	"bush": {"kind": "decor", "cat": "decor", "sub": "plants", "name": "Куст в пифосе", "cost": 5, "deco": 2, "unlock": "deco_trees", "desc": "Южный куст в глиняном пифосе, у подножия цветы."},
	"bush_2": {"kind": "decor", "cat": "decor", "sub": "plants", "base": "bush", "look": 1, "name": "Цветущий олеандр", "cost": 6, "deco": 2, "unlock": "deco_trees", "desc": "Большой цветущий куст и два поменьше."},
	"bush_3": {"kind": "decor", "cat": "decor", "sub": "plants", "base": "bush", "look": 2, "name": "Куст-веер в цветах", "cost": 5, "deco": 2, "unlock": "deco_trees", "desc": "Южный куст-веер, вокруг — цветы."},
	"wall_flowers": {"kind": "decor", "cat": "decor", "sub": "plants", "unlock": "q_garden", "name": "Ящик с цветами на стене", "cost": 8, "deco": 2, "wall": true, "desc": "Каменный ящик с цветами под окном. Вешается на стену дома."},
	"wall_flowers_2": {"kind": "decor", "cat": "decor", "sub": "plants", "base": "wall_flowers", "look": 1, "unlock": "q_garden", "name": "Кашпо на стене", "cost": 8, "deco": 2, "wall": true, "desc": "Подвесной горшок с цветами. Вешается на стену дома."},
	"wall_flowers_3": {"kind": "decor", "cat": "decor", "sub": "plants", "base": "wall_flowers", "look": 2, "unlock": "q_garden", "name": "Два кашпо на стене", "cost": 12, "deco": 3, "wall": true, "desc": "Пара подвесных горшков с цветами. Вешается на стену дома."},
	# деревья
	"tree": {"kind": "decor", "cat": "decor", "sub": "trees", "name": "Дерево в каменном круге", "cost": 10, "deco": 3, "unlock": "deco_trees", "desc": "Тенистое дерево в бортике из камней, у корней цветы."},
	"tree_2": {"kind": "decor", "cat": "decor", "sub": "trees", "base": "tree", "look": 1, "name": "Дерево на лужайке", "cost": 10, "deco": 3, "unlock": "deco_trees", "desc": "Раскидистое дерево в траве и цветах."},
	"cypress": {"kind": "decor", "cat": "decor", "sub": "trees", "name": "Кипарис", "cost": 8, "deco": 2, "unlock": "deco_trees", "desc": "Стройный кипарис — римская классика."},
	"cypress_2": {"kind": "decor", "cat": "decor", "sub": "trees", "base": "cypress", "look": 1, "name": "Кипарис в цветах", "cost": 10, "deco": 2, "unlock": "deco_trees", "desc": "Кипарис в каменном круге, у корней ковёр цветов."},
	"palm": {"kind": "decor", "cat": "decor", "sub": "trees", "name": "Пальма", "cost": 15, "deco": 3, "unlock": "deco_trees", "desc": "Пальма с юга, у корней — зелень."},
	"palm_2": {"kind": "decor", "cat": "decor", "sub": "trees", "base": "palm", "look": 1, "name": "Пальма в каменном круге", "cost": 15, "deco": 3, "unlock": "deco_trees", "desc": "Пальма в бортике из камней с цветами."},
	# свет
	"lamp_post": {"kind": "decor", "cat": "decor", "sub": "light", "name": "Фонарь на столбе", "cost": 20, "deco": 3, "light": true, "desc": "Бронзовый фонарь на деревянном столбе, на перекладине — кашпо с цветами. Ночью светит на улицу."},
	"lamp_post_2": {"kind": "decor", "cat": "decor", "sub": "light", "base": "lamp_post", "look": 1, "name": "Фонарь с горшком цветов", "cost": 20, "deco": 3, "light": true, "desc": "Фонарь на столбе, у подножия — горшок с цветами. Ночью светит на улицу."},
	"lamp_post_3": {"kind": "decor", "cat": "decor", "sub": "light", "base": "lamp_post", "look": 2, "name": "Фонарь в цветах", "cost": 20, "deco": 3, "light": true, "desc": "Фонарь на столбе в кругу цветов. Ночью светит на улицу."},
	"candelabrum": {"kind": "decor", "cat": "decor", "sub": "light", "unlock": "q_lights", "name": "Светильник бронзовый", "cost": 25, "deco": 3, "light": true, "desc": "Высокий бронзовый светильник с огоньком на мраморном круге."},
	"candelabrum_2": {"kind": "decor", "cat": "decor", "sub": "light", "base": "candelabrum", "look": 1, "unlock": "q_lights", "name": "Светильник каменный", "cost": 25, "deco": 3, "light": true, "desc": "Огненная чаша на высокой мраморной подставке."},
	"wall_torch": {"kind": "decor", "cat": "decor", "sub": "light", "unlock": "q_lights", "name": "Факел с бляхой", "cost": 10, "deco": 2, "light": true, "wall": true, "desc": "Факел в кольце, за ним — золотая бляха. Вешается на стену дома, ночью горит."},
	"wall_torch_2": {"kind": "decor", "cat": "decor", "sub": "light", "base": "wall_torch", "look": 1, "unlock": "q_lights", "name": "Факел с львиной маской", "cost": 12, "deco": 2, "light": true, "wall": true, "desc": "Факел под мраморной львиной маской. Вешается на стену дома, ночью горит."},
	"wall_lamp": {"kind": "decor", "cat": "decor", "sub": "light", "unlock": "q_lights", "name": "Фонарь на стене", "cost": 15, "deco": 3, "light": true, "wall": true, "desc": "Фонарь со стёклами на кронштейне. Вешается на стену дома, ночью светит."},
	"wall_lamp_2": {"kind": "decor", "cat": "decor", "sub": "light", "base": "wall_lamp", "look": 1, "unlock": "q_lights", "name": "Лампа на цепочке", "cost": 15, "deco": 3, "light": true, "wall": true, "desc": "Римская бронзовая лампа на цепочке. Вешается на стену дома, ночью светит."},
	"brazier": {"kind": "decor", "cat": "decor", "sub": "light", "name": "Жаровня-треножник", "cost": 25, "deco": 3, "light": true, "unlock": "deco_metal", "desc": "Железный треножник с огнём на каменном круге. Ночью освещает улицу."},
	"brazier_2": {"kind": "decor", "cat": "decor", "sub": "light", "base": "brazier", "look": 1, "name": "Жаровня на тумбе", "cost": 25, "deco": 3, "light": true, "unlock": "deco_metal", "desc": "Огненная чаша на мраморной тумбе. Ночью освещает улицу."},
	"bigbrazier": {"kind": "decor", "cat": "decor", "sub": "light", "name": "Большая жаровня", "cost": 70, "deco": 5, "light": true, "unlock": "deco_metal", "desc": "Бронзовая чаша с огнём на высокой ножке."},
	"bigbrazier_2": {"kind": "decor", "cat": "decor", "sub": "light", "base": "bigbrazier", "look": 1, "name": "Широкая жаровня", "cost": 70, "deco": 5, "light": true, "unlock": "deco_metal", "desc": "Широкая низкая чаша с огнём на мраморной плите."},
	# улица
	"bench": {"kind": "decor", "cat": "decor", "sub": "street", "name": "Мраморная скамья", "cost": 15, "deco": 3, "desc": "Скамья между двумя горшками с цветами. Посидеть и поболтать."},
	"bench_2": {"kind": "decor", "cat": "decor", "sub": "street", "base": "bench", "look": 1, "name": "Деревянная скамья", "cost": 15, "deco": 3, "desc": "Скамья с вазой и корзиной. Посидеть и поболтать."},
	"bench_3": {"kind": "decor", "cat": "decor", "sub": "street", "base": "bench", "look": 2, "name": "Полукруглая скамья", "cost": 18, "deco": 3, "desc": "Мраморная скамья полукругом у куста."},
	"well": {"kind": "decor", "cat": "decor", "sub": "street", "name": "Колодец под черепицей", "cost": 40, "deco": 4, "desc": "Колодец с воротом под черепичной крышей, рядом кувшины."},
	"well_2": {"kind": "decor", "cat": "decor", "sub": "street", "base": "well", "look": 1, "name": "Колодец с навесом", "cost": 40, "deco": 4, "desc": "Колодец с воротом под дощатым навесом, рядом кувшины."},
	"well_3": {"kind": "decor", "cat": "decor", "sub": "street", "base": "well", "look": 2, "name": "Открытый колодец", "cost": 35, "deco": 4, "desc": "Каменный сруб с воротом, рядом кувшины и корзина."},
	"banner": {"kind": "decor", "cat": "decor", "sub": "street", "name": "Знамя на шесте", "cost": 30, "deco": 3, "unlock": "deco_metal", "desc": "Римский значок: полотнище на перекладине, золотые бляхи на древке."},
	"banner_2": {"kind": "decor", "cat": "decor", "sub": "street", "base": "banner", "look": 1, "name": "Знамя на постаменте", "cost": 30, "deco": 3, "unlock": "deco_metal", "desc": "Знамя с бахромой на мраморном постаменте."},
	"wall_banner": {"kind": "decor", "cat": "decor", "sub": "street", "name": "Знамя на стене", "cost": 20, "deco": 3, "wall": true, "unlock": "deco_metal", "desc": "Полотнище в узорной кайме на стене дома."},
	"wall_banner_2": {"kind": "decor", "cat": "decor", "sub": "street", "base": "wall_banner", "look": 1, "name": "Полотнище на стене", "cost": 20, "deco": 3, "wall": true, "unlock": "deco_metal", "desc": "Полотнище с бахромой на перекладине — вешается на стену дома."},
	"wall_banner_3": {"kind": "decor", "cat": "decor", "sub": "street", "base": "wall_banner", "look": 2, "name": "Два знамени на стене", "cost": 30, "deco": 3, "wall": true, "unlock": "deco_metal", "desc": "Два узких полотнища рядом на стене дома."},
	# двор и рынок
	"fence": {"kind": "decor", "cat": "decor", "sub": "yard", "unlock": "q_garden", "name": "Плетень", "cost": 5, "deco": 1, "desc": "Жердяной забор вокруг двора — ставьте рядами."},
	"fence_2": {"kind": "decor", "cat": "decor", "sub": "yard", "base": "fence", "look": 1, "unlock": "q_garden", "name": "Калитка", "cost": 10, "deco": 2, "desc": "Калитка между каменными столбиками с вазами."},
	"fence_3": {"kind": "decor", "cat": "decor", "sub": "yard", "base": "fence", "look": 2, "color": 1, "unlock": "q_garden", "name": "Садовая стенка", "cost": 15, "deco": 2, "desc": "Низкая оштукатуренная стенка с вазонами и плющом, как в Помпеях."},
	"hay": {"kind": "decor", "cat": "decor", "sub": "yard", "unlock": "q_garden", "name": "Стог сена", "cost": 6, "deco": 1, "desc": "Копна, прислонённый сноп, мешок и коса."},
	"hay_2": {"kind": "decor", "cat": "decor", "sub": "yard", "base": "hay", "look": 1, "unlock": "q_garden", "name": "Большая копна", "cost": 6, "deco": 1, "desc": "Большая копна сена, корзина и мешки."},
	"amphorae": {"kind": "decor", "cat": "decor", "sub": "yard", "unlock": "q_market", "name": "Амфоры", "cost": 10, "deco": 2, "desc": "Груда амфор с маслом и вином."},
	"amphorae_2": {"kind": "decor", "cat": "decor", "sub": "yard", "base": "amphorae", "look": 1, "unlock": "q_market", "name": "Пифосы", "cost": 10, "deco": 2, "desc": "Большие глиняные пифосы, ваза и мешок."},
	"amphorae_3": {"kind": "decor", "cat": "decor", "sub": "yard", "base": "amphorae", "look": 2, "unlock": "q_market", "name": "Вазы и корзина", "cost": 10, "deco": 2, "desc": "Груда расписных ваз и корзина."},
	"goods": {"kind": "decor", "cat": "decor", "sub": "yard", "unlock": "q_market", "name": "Корзины с товаром", "cost": 10, "deco": 2, "desc": "Корзины с фруктами, мешок и кувшин у лавки."},
	"goods_2": {"kind": "decor", "cat": "decor", "sub": "yard", "base": "goods", "look": 1, "unlock": "q_market", "name": "Корзины и ваза", "cost": 10, "deco": 2, "desc": "Плетёные корзины с зерном и расписная ваза."},
	"goods_3": {"kind": "decor", "cat": "decor", "sub": "yard", "base": "goods", "look": 2, "unlock": "q_market", "name": "Мешки и корзины", "cost": 10, "deco": 2, "desc": "Гора мешков, корзины с фруктами и глиняный пифос."},
	"cart": {"kind": "decor", "cat": "decor", "sub": "yard", "unlock": "q_market", "name": "Телега с мешками", "cost": 30, "deco": 2, "desc": "Телега с товаром, рядом мешки и корзина."},
	"cart_2": {"kind": "decor", "cat": "decor", "sub": "yard", "base": "cart", "look": 1, "unlock": "q_market", "name": "Телега с амфорами", "cost": 30, "deco": 2, "desc": "Телега с товаром, рядом амфоры и мешок."},
	# статуи и камень
	"statue": {"kind": "decor", "cat": "decor", "sub": "stone", "name": "Статуя воина", "cost": 220, "deco": 9, "unlock": "deco_stone", "desc": "Мраморный воин с копьём и щитом на постаменте."},
	"statue_2": {"kind": "decor", "cat": "decor", "sub": "stone", "base": "statue", "look": 1, "name": "Статуя полководца", "cost": 220, "deco": 9, "unlock": "deco_stone", "desc": "Полководец в плаще на круглом постаменте, вокруг вазоны."},
	"statue_3": {"kind": "decor", "cat": "decor", "sub": "stone", "base": "statue", "look": 2, "name": "Статуя девушки с амфорой", "cost": 220, "deco": 9, "unlock": "deco_stone", "desc": "Мраморная девушка с амфорой на плече."},
	"statue_4": {"kind": "decor", "cat": "decor", "sub": "stone", "base": "statue", "look": 3, "name": "Статуя мудреца", "cost": 220, "deco": 9, "unlock": "deco_stone", "desc": "Старый мудрец в тоге на круглом постаменте, вокруг вазоны."},
	"column": {"kind": "decor", "cat": "decor", "sub": "stone", "name": "Колонна со статуей", "cost": 300, "deco": 10, "unlock": "deco_stone", "desc": "Колонна, увитая розами, наверху — центурион."},
	"lion": {"kind": "decor", "cat": "decor", "sub": "stone", "name": "Золотой лев", "cost": 500, "deco": 12, "unlock": "deco_stone", "desc": "Позолоченный лев на высоком постаменте."},
	"lion_2": {"kind": "decor", "cat": "decor", "sub": "stone", "base": "lion", "look": 1, "name": "Лев с вазонами", "cost": 500, "deco": 12, "unlock": "deco_stone", "desc": "Позолоченный лев на мраморной плите, по углам вазоны с цветами."},
	"sundial": {"kind": "decor", "cat": "decor", "sub": "stone", "name": "Солнечные часы", "cost": 100, "deco": 5, "unlock": "deco_stone", "desc": "Часы на круглом мраморном камне."},
	"sundial_2": {"kind": "decor", "cat": "decor", "sub": "stone", "base": "sundial", "look": 1, "name": "Часы на колонне", "cost": 100, "deco": 5, "unlock": "deco_stone", "desc": "Солнечные часы на обрубке колонны."},
	"smallfountain": {"kind": "decor", "cat": "decor", "sub": "stone", "name": "Фонтанчик со львом", "cost": 70, "deco": 5, "unlock": "fountain", "desc": "Уличный фонтан как в Помпеях: каменное корыто, струя из львиной пасти."},
	"smallfountain_2": {"kind": "decor", "cat": "decor", "sub": "stone", "base": "smallfountain", "look": 1, "name": "Фонтан с резной стенкой", "cost": 70, "deco": 5, "unlock": "fountain", "desc": "Каменная чаша с водой у резной стенки."},
	"pergola": {"kind": "decor", "cat": "decor", "sub": "stone", "name": "Пергола", "cost": 200, "deco": 8, "unlock": "deco_stone", "desc": "Увитая виноградом пергола с ложем и столиком — как в садах Помпей."},
	"pergola_2": {"kind": "decor", "cat": "decor", "sub": "stone", "base": "pergola", "look": 1, "name": "Беседка-толос", "cost": 200, "deco": 8, "unlock": "deco_stone", "desc": "Круглая беседка под черепичным куполом, внутри скамья, колонны в розах."},
	# животные
	"sheep": {"kind": "decor", "cat": "decor", "sub": "animals", "name": "Овцы в загоне", "cost": 30, "deco": 3, "unlock": "animals", "desc": "Пара овечек в загоне с плетнём и корытцем."},
	"sheep_2": {"kind": "decor", "cat": "decor", "sub": "animals", "base": "sheep", "look": 1, "name": "Овцы на лугу", "cost": 30, "deco": 3, "unlock": "animals", "desc": "Пара овечек пасётся на лугу, в углу копёшка."},
	"duck": {"kind": "decor", "cat": "decor", "sub": "animals", "name": "Утки", "cost": 15, "deco": 3, "unlock": "animals", "water": true, "desc": "Утки плавают по пруду."},
	"swan": {"kind": "decor", "cat": "decor", "sub": "animals", "name": "Лебедь", "cost": 25, "deco": 4, "unlock": "animals", "water": true, "desc": "Белый лебедь на воде."},
}

## Разделы меню стройки (снизу посередине) и вкладки коммерции
## Вкладки раздела «Украшения» (как вкладки потребностей у лавок)
const DECOR_SUBS := [["plants", "Цветы", "daisy"], ["trees", "Деревья", "pine"], ["light", "Свет", "lamp"],
	["street", "Улица", "bench"], ["yard", "Двор и рынок", "cart"], ["stone", "Статуи и камень", "mona"], ["animals", "Животные", "swan"]]
const CATS := [["housing", "Жильё", "housing"], ["commerce", "Коммерция", "commerce"], ["farming", "Хозяйство и науки", "farming"],
	["decor", "Украшения", "decor"], ["special", "Особые постройки", "special"]]

# ---------- исследования ----------
## Каждый уровень города открывает свой раздел. unlock — что даёт (постройку открывает её ключ в B.unlock)
const RESEARCH := [
	# первые исследования: город начинает с 0 очков, первые просьбы дают ~25 — первое изучение
	# через 2–3 часа работы скриптория (2 очка в час), овощная лавка — часов через 10
	{"id": "stall_veg", "lvl": 0, "name": "Овощная лавка", "cost": 45, "icon": "veg"},
	{"id": "stall_fish", "lvl": 0, "name": "Рыбная лавка", "cost": 55, "icon": "fish"},
	{"id": "reach1", "lvl": 0, "name": "Больший охват", "cost": 120, "icon": "arrow", "after": "stall_veg",
		"desc": "Лавки с едой обслуживают дома на треть дальше."},
	{"id": "farm", "lvl": 0, "name": "Пшеничное поле", "cost": 70, "icon": "wheat"},
	{"id": "deco_flowers", "lvl": 0, "name": "Цветы и вазоны", "cost": 30, "icon": "daisy"},
	{"id": "deco_trees", "lvl": 0, "name": "Деревья и кусты", "cost": 30, "icon": "tree"},
	{"id": "musicians", "lvl": 0, "name": "Уличные музыканты", "cost": 70, "icon": "lyre"},

	{"id": "floor2", "lvl": 1, "name": "Второй жилой этаж", "cost": 200, "icon": "housing",
		"desc": "Второй этаж можно купить в карточке дома, когда дом полон, а счастье в нём не ниже 70%. Туда въедет ещё одна семья."},
	{"id": "weaver", "lvl": 1, "name": "Ткацкая лавка", "cost": 120, "icon": "wool"},
	{"id": "warehouse", "lvl": 1, "name": "Склад", "cost": 130, "icon": "warehouse"},
	{"id": "butcher", "lvl": 1, "name": "Мясная лавка", "cost": 160, "icon": "meat", "after": "warehouse"},
	{"id": "cobbler", "lvl": 1, "name": "Сапожник", "cost": 170, "icon": "boots", "after": "weaver"},
	{"id": "bakery", "lvl": 1, "name": "Пекарня", "cost": 230, "icon": "bread", "after": "warehouse"},
	{"id": "fountain", "lvl": 1, "name": "Фонтаны", "cost": 180, "icon": "water"},
	{"id": "animals", "lvl": 1, "name": "Животные: утки, лебеди, овцы", "cost": 60, "icon": "swan"},

	{"id": "artisans", "lvl": 2, "name": "Класс ремесленников", "cost": 380, "icon": "hammer",
		"desc": "Открывает дома ремесленников. Им нужны еда, одежда и развлечения."},
	{"id": "dice", "lvl": 2, "name": "Игра в кости", "cost": 210, "icon": "dice"},
	{"id": "barber", "lvl": 2, "name": "Цирюльня", "cost": 270, "icon": "razor"},
	{"id": "thermopolium", "lvl": 2, "name": "Термополий", "cost": 340, "icon": "meal"},
	{"id": "school", "lvl": 2, "name": "Школа", "cost": 390, "icon": "teacher"},
	{"id": "grove", "lvl": 2, "name": "Оливковая роща", "cost": 220, "icon": "olive"},
	{"id": "oilshop", "lvl": 2, "name": "Масляная лавка", "cost": 280, "icon": "amphora", "after": "grove"},
	{"id": "roads2", "lvl": 2, "name": "Площади из плитки", "cost": 160, "icon": "plaza", "desc": "Новое покрытие дорог — узорная плитка."},
	{"id": "deco_stone", "lvl": 2, "name": "Каменные украшения", "cost": 240, "icon": "mona"},
	{"id": "store1", "lvl": 2, "name": "Больше носильщиков", "cost": 300, "icon": "warehouse", "after": "warehouse",
		"desc": "Склад разносит товары вдвое дальше."},

	{"id": "floor3", "lvl": 3, "name": "Третий жилой этаж", "cost": 680, "icon": "housing", "after": "floor2",
		"desc": "Третий этаж можно купить в карточке полного дома со счастьем не ниже 80%."},
	{"id": "dyer", "lvl": 3, "name": "Красильня", "cost": 510, "icon": "cape"},
	{"id": "potter", "lvl": 3, "name": "Гончарная", "cost": 440, "icon": "pottery"},
	{"id": "mimes", "lvl": 3, "name": "Помост мимов", "cost": 480, "icon": "puppet"},
	{"id": "temple", "lvl": 3, "name": "Храм", "cost": 650, "icon": "level"},
	{"id": "fullonica", "lvl": 3, "name": "Фуллоника", "cost": 540, "icon": "tshirt"},
	{"id": "deco_metal", "lvl": 3, "name": "Жаровни и знамёна", "cost": 310, "icon": "candle"},
	{"id": "vault1", "lvl": 3, "name": "Новое хранилище денег", "cost": 510, "icon": "money", "desc": "Казна вмещает вдвое больше."},

	{"id": "patricians", "lvl": 4, "name": "Класс патрициев", "cost": 1140, "icon": "toga",
		"desc": "Открывает домусы патрициев. Им нужно всё: еда, одежда, развлечения, услуги и товары."},
	{"id": "balnea", "lvl": 4, "name": "Бани", "cost": 800, "icon": "bath"},
	{"id": "lamps", "lvl": 4, "name": "Мастер светильников", "cost": 800, "icon": "candle"},
	{"id": "library", "lvl": 4, "name": "Библиотека", "cost": 1140, "icon": "bookshelf", "after": "school"},
	{"id": "vineyard", "lvl": 4, "name": "Виноградник", "cost": 530, "icon": "grapes"},
	{"id": "wineshop", "lvl": 4, "name": "Винная лавка", "cost": 720, "icon": "wine", "after": "vineyard"},
	{"id": "odeon", "lvl": 4, "name": "Одеон", "cost": 1060, "icon": "harp"},
	{"id": "taberna", "lvl": 4, "name": "Таверна", "cost": 990, "icon": "mug"},
	{"id": "research1", "lvl": 4, "name": "Новые полки для свитков", "cost": 860, "icon": "scroll", "desc": "Очков исследований помещается вдвое больше."},

	{"id": "perfumer", "lvl": 5, "name": "Парфюмер", "cost": 1470, "icon": "perfume"},
	{"id": "medic", "lvl": 5, "name": "Лекарь", "cost": 1300, "icon": "medic"},
	{"id": "tailor", "lvl": 5, "name": "Мастерская тог", "cost": 1680, "icon": "toga"},
	{"id": "baths", "lvl": 5, "name": "Термы", "cost": 1890, "icon": "water", "after": "balnea"},
	{"id": "jeweler", "lvl": 5, "name": "Ювелир", "cost": 2100, "icon": "ring"},
	{"id": "forum", "lvl": 5, "name": "Форум", "cost": 2520, "icon": "caesar"},
	{"id": "taxes1", "lvl": 5, "name": "Налоги для богатых", "cost": 1890, "icon": "coins", "desc": "Патриции платят на четверть больше."},

	{"id": "theatre", "lvl": 6, "name": "Театр", "cost": 3450, "icon": "fun", "after": "odeon"},
	{"id": "arch", "lvl": 6, "name": "Триумфальная арка", "cost": 2990, "icon": "castle"},
	{"id": "academy", "lvl": 6, "name": "Академия", "cost": 3680, "icon": "book", "after": "library"},
	{"id": "vault2", "lvl": 6, "name": "Подвалы казны", "cost": 2760, "icon": "money", "after": "vault1", "desc": "Казна вмещает ещё вдвое больше."},

	{"id": "colosseum", "lvl": 7, "name": "Амфитеатр", "cost": 8000, "icon": "swords"},
	# не дороже предела очков на высшем уровне (5000 × 2 с «research1») — иначе изучить нельзя вовсе
	{"id": "pantheon", "lvl": 7, "name": "Пантеон", "cost": 9800, "icon": "level"},
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


## Просьбы горожан (как запросы в Town to City): кто просит, что сделать, награда. Награда-«unlock» открывает украшения.
## p: [вид, параметр] — road, houses, fam, count <тип>, kind <вид>, pop, happy, cls <класс>, floors <этажей>,
## fed <потребность>, research, shops, near <тип> <класс>, store, light
const REQUESTS := [
	{"id": "road1", "who": "advisor", "text": "Проложите мостовую от станции", "p": ["road"], "need": 40, "money": 100, "rp": 0, "icon": "road",
		"hint": "Выберите «Мостовую» слева внизу и ведите кисть с зажатой левой кнопкой мыши от площади у станции."},
	{"id": "houses3", "who": "advisor", "text": "Постройте 3 дома у дороги", "p": ["houses"], "need": 3, "money": 150, "rp": 5, "tool": "house_pleb", "icon": "housing",
		"hint": "Дом ставится фасадом к дороге. Повозка привезёт семьи по большой дороге."},
	{"id": "fam3", "who": "advisor", "text": "Заселите три семьи", "p": ["fam"], "need": 3, "money": 100, "rp": 5, "icon": "family",
		"hint": "Семьи ждут на площади у станции. Нажмите на значок семьи слева вверху и выберите им дом."},
	{"id": "fruit", "who": "plebs", "text": "Нам бы поесть: фруктовая лавка", "p": ["count", "stall_fruit"], "need": 1, "money": 100, "rp": 5, "tool": "stall_fruit", "icon": "food",
		"hint": "Лавка кормит ближайшие дома в своей дальности. Чем больше разных лавок рядом, тем счастливее дом."},
	{"id": "scriptorium", "who": "advisor", "text": "Постройте скрипторий", "p": ["count", "scriptorium"], "need": 1, "money": 100, "rp": 10, "tool": "scriptorium", "icon": "quill",
		"hint": "Скрипторий даёт очки исследований — за них открываются новые постройки."},
	{"id": "research1", "who": "advisor", "text": "Изучите что-нибудь", "p": ["research"], "need": 1, "money": 150, "rp": 0, "icon": "research",
		"hint": "Нажмите на свиток вверху справа — откроется меню исследований. Очки исследований дают скрипторий, школа и библиотека."},
	{"id": "lights", "who": "plebs", "text": "Ночью темно: 3 фонаря на столбах", "p": ["count", "lamp_post"], "need": 3, "money": 120, "rp": 10, "tool": "lamp_post", "icon": "candle",
		"unlock": "q_lights", "reward": "факелы и фонари на стены, светильники",
		"hint": "Фонари радуют дома вокруг и светят ночью. Поставьте их вдоль улиц."},
	{"id": "fed6", "who": "plebs", "text": "Еды на всех: 6 сытых домов", "p": ["fed", "food"], "need": 6, "money": 150, "rp": 15, "icon": "food",
		"hint": "Дом сыт, если рядом лавка с едой и в ней хватает работников. Посмотрите охват лавок (глаз вверху справа)."},
	{"id": "pop30", "who": "advisor", "text": "Соберите 30 жителей", "p": ["pop"], "need": 30, "money": 200, "rp": 25, "icon": "family",
		"hint": POP_HINT},
	{"id": "decor5", "who": "plebs", "text": "Красоты хочется: 5 украшений", "p": ["kind", "decor"], "need": 5, "money": 120, "rp": 10, "icon": "flower",
		"unlock": "q_garden", "reward": "цветы на стены, плетень, стог сена",
		"hint": "Украшения дают дому очки красоты: +1% счастья за каждые 2 очка (у плебеев до +12%). Ставьте их в промежутках между домами."},
	{"id": "floor2", "who": "plebs", "text": "Нам тесно: дом в 2 этажа", "p": ["floors", 2], "need": 1, "money": 250, "rp": 40, "icon": "housing",
		"hint": "Изучите «Второй жилой этаж». Потом откройте карточку полного дома со счастьем от 70% и купите этаж."},
	{"id": "store", "who": "plebs", "text": "Склад и мясная лавка", "p": ["store"], "need": 2, "money": 200, "rp": 40, "icon": "warehouse"},
	{"id": "market", "who": "plebs", "text": "Рынок: 4 разные лавки", "p": ["shops"], "need": 4, "money": 220, "rp": 40, "icon": "commerce",
		"unlock": "q_market", "reward": "телега, корзины и амфоры",
		"hint": "Разные лавки рядом делают дома счастливее. Откройте новые в исследованиях."},
	{"id": "fountain4", "who": "plebs", "text": "Вода рядом: фонтан у 4 домов", "p": ["near", "fountain", "plebs"], "need": 4, "money": 300, "rp": 50, "icon": "water",
		"hint": "Изучите «Фонтаны» и поставьте фонтан посреди домов плебеев."},
	{"id": "happy60", "who": "advisor", "text": "Счастье города 60%", "p": ["happy"], "need": 60, "money": 300, "rp": 60, "icon": "happy",
		"hint": "Новые семьи едут только в город, где счастье не ниже 60%. Разные лавки рядом с домами, украшения и памятники поднимают счастье."},
	{"id": "pop100", "who": "advisor", "text": "Соберите 100 жителей", "p": ["pop"], "need": 100, "money": 400, "rp": 80, "icon": "family",
		"hint": POP_HINT},
	{"id": "artisan", "who": "advisor", "text": "Постройте дом ремесленников", "p": ["count", "house_artisan"], "need": 1, "money": 300, "rp": 60, "tool": "house_artisan", "icon": "hammer"},
	{"id": "art12", "who": "artisans", "text": "Поселите 12 ремесленников", "p": ["cls", "artisans"], "need": 12, "money": 350, "rp": 70, "icon": "hammer"},
	{"id": "clothes8", "who": "artisans", "text": "Одежду всем: 8 домов с одеждой", "p": ["fed", "clothes"], "need": 8, "money": 380, "rp": 70, "icon": "clothes"},
	{"id": "floor2x5", "who": "plebs", "text": "Пять домов в 2 этажа", "p": ["floors", 2], "need": 5, "money": 400, "rp": 80, "icon": "housing"},
	{"id": "temple", "who": "artisans", "text": "Постройте храм", "p": ["count", "temple"], "need": 1, "money": 500, "rp": 100, "tool": "temple", "icon": "level"},
	{"id": "school", "who": "artisans", "text": "Детям нужна школа", "p": ["count", "school"], "need": 1, "money": 450, "rp": 100, "tool": "school", "icon": "teacher"},
	{"id": "pop300", "who": "advisor", "text": "Соберите 300 жителей", "p": ["pop"], "need": 300, "money": 900, "rp": 150, "icon": "family",
		"hint": POP_HINT},
	{"id": "patrician", "who": "advisor", "text": "Постройте домус патрициев", "p": ["count", "house_patrician"], "need": 1, "money": 800, "rp": 150, "tool": "house_patrician", "icon": "toga"},
	{"id": "floor3", "who": "artisans", "text": "Дом в 3 этажа", "p": ["floors", 3], "need": 1, "money": 700, "rp": 140, "icon": "housing"},
	{"id": "pat10", "who": "patricians", "text": "Поселите 10 патрициев", "p": ["cls", "patricians"], "need": 10, "money": 900, "rp": 180, "icon": "toga"},
	{"id": "happy70", "who": "patricians", "text": "Счастье города 70%", "p": ["happy"], "need": 70, "money": 1000, "rp": 200, "icon": "happy"},
	{"id": "pop600", "who": "advisor", "text": "Соберите 600 жителей", "p": ["pop"], "need": 600, "money": 1500, "rp": 300, "icon": "family",
		"hint": POP_HINT},
	{"id": "forum", "who": "patricians", "text": "Постройте форум", "p": ["count", "forum"], "need": 1, "money": 2000, "rp": 400, "tool": "forum", "icon": "caesar"},
	{"id": "pop1000", "who": "advisor", "text": "Соберите 1000 жителей", "p": ["pop"], "need": 1000, "money": 3000, "rp": 600, "icon": "laurels",
		"hint": POP_HINT},
]
## Подсказка к просьбам «Соберите N жителей»: откуда берутся жители и почему повозка может стоять
const POP_HINT := "Жители прибавляются, когда повозка привозит новые семьи и вы заселяете их в дома. Первые три семьи приедут всегда, а дальше — только пока счастье города не ниже %d%%. Наведите на счастье вверху — там видно, что его поднимет." % ARRIVE_HAPPY
const WHO := {"advisor": ["Советник Марк", "caesar"], "plebs": ["Плебеи просят", "person"], "artisans": ["Ремесленники просят", "hammer"], "patricians": ["Патриции просят", "toga"]}


static func request(id: String) -> Dictionary:
	for r in REQUESTS:
		if r["id"] == id:
			return r
	return {}


## Чем открывается постройка: исследованием или просьбой горожан
static func unlock_text(id: String) -> String:
	var r := research(id)
	if not r.is_empty():
		return "исследованием «%s»" % r["name"]
	for q in REQUESTS:
		if q.get("unlock", "") == id:
			return "наградой за просьбу «%s»" % q["text"]
	return ""


static func unlock_short(id: String) -> String:
	var r := research(id)
	if not r.is_empty():
		return r["name"]
	for q in REQUESTS:
		if q.get("unlock", "") == id:
			return "Просьба горожан"
	return ""


static func research(id: String) -> Dictionary:
	for r in RESEARCH:
		if r["id"] == id:
			return r
	return {}


## Вид украшения, к которому относится облик («flowers_2» → «flowers»); у остальных построек — сам тип
static func base_of(type: String) -> String:
	return String((B.get(type, {}) as Dictionary).get("base", type))


## Все облики вида украшения (карточки по порядку): «flowers» → [flowers, flowers_2, flowers_3]
static func looks_of(base: String) -> Array:
	var out := []
	for t in B:
		if t == base or (B[t] as Dictionary).get("base", "") == base:
			out.append(t)
	return out


static func range_m(d: Dictionary) -> float:
	return float(RANGE.get(int(d.get("range", 0)), 0.0))


static func floors_max(cls: String) -> int:
	return 2 if cls == "patricians" else 3
