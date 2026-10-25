class_name Defs
extends RefCounted
## Все числа и названия игры — устроено как в Town to City, только Рим:
## три класса жителей (у каждого свой дом), лавки по видам потребностей с дальностью, рабочими и
## производительностью, исследования за отдельную валюту, уровни города от Стоянки до Вечного города.

## Старт — 2000 ден.: на «Стоянке» и «Хуторе» денег впритык (этап 2.3), щедрые награды просьб — с «Деревни»
const START_MONEY := 2000
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
## Новая игра (City.econ, решение владельца Q3/Q4 — только в новых городах): внутри одного вида лавок (еда, одежда…)
## первая даёт бонус целиком, вторая — вполовину, третья и дальше — четверть; одинаковые украшения рядом (один вид,
## любой облик) — 100% / 60% / 30%: выгоднее разнообразие, чем десять одинаковых светильников
const SHOP_REPEAT := [1.0, 0.5, 0.25]
const DECO_REPEAT := [1.0, 0.6, 0.3]
## Налоги по классам (этап 2.7, как в Town to City; с уровня TAX_LVL — «Деревни»): k — во сколько раз налог,
## happy — % счастья домам класса (снимается со счастья без потолка, то есть сперва съедает «запас» выше 100%)
const TAX_SET := [{"name": "Мягкие", "k": 0.8, "happy": 5}, {"name": "Обычные", "k": 1.0, "happy": 0}, {"name": "Высокие", "k": 1.3, "happy": -8}]
const TAX_LVL := 2
## История денег и жителей (этап 2.4): последние HIST_N игровых часов; в строке — по порядку HIST_KEYS
## (налоги, жалованье, содержание, стройка, игры, земля, Легион, награды, прочее, не уместилось в казну, казна, жители, счастье)
const HIST_N := 48
const HIST_KEYS := ["tax", "wage", "upkeep", "build", "fest", "land", "legion", "reward", "other", "lost", "money", "pop", "happy"]
## Этажи покупает игрок инструментом «Этаж» (U) или в карточке дома (как в Town to City): нужен открытый этаж, полный дом и счастье
const FLOOR_HAPPY := {2: 65, 3: 75}   # счастье дома, с которого можно надстроить этаж
const FLOOR_PRICE := {"plebs": {2: 200, 3: 450}, "artisans": {2: 550, 3: 1000}, "patricians": {2: 1800, 3: 1500}}
const FLOOR_RESEARCH := {2: "floor2", 3: "floor3"}
## Приезд семей: первые ARRIVE_FREE семей едут всегда, дальше — только пока счастье города не ниже ARRIVE_HAPPY.
## И всегда — только в свободные дома (City.free_fit): нет места — едет одна семья «ищет жильё»
const ARRIVE_HAPPY := 60
const ARRIVE_FREE := 7
## Счастливый город зовёт чаще: [счастье от, множитель промежутка между повозками]; не чаще, чем ARRIVE_MULT_MIN
const ARRIVE_FAST := [[80, 0.65], [70, 0.8]]
const ARRIVE_MULT_MIN := 0.5
## Жалованье работнику в час (по уровню города) и содержание постройки в час — доля её цены
const WAGE := [0.3, 0.35, 0.45, 0.6, 0.75, 0.9, 1.05, 1.2]
const UPKEEP := 0.005
## Праздник «Игры в честь богов» — с уровня lvl («Посёлок»), в карточке почтовой станции: цена — tax_k часовых налогов
## каждого жителя (плебей — 3 ден., ремесленник — 5,5, патриций — 11,25: больше, чем игры вернут налогами);
## hours часов счастье всех домов +happy% и повозка ходит чаще (промежуток ×cart, но не чаще ARRIVE_MULT_MIN);
## новые игры — не раньше чем через cd часов после начала прошлых
const FESTIVAL := {"lvl": 3, "tax_k": 2.5, "hours": 24, "cd": 48, "happy": 8, "cart": 0.7}
## Земля: k-й купленный участок стоит PLOT_BASE × PLOT_GROW^(k−1), до тысяч: 6, 8, 10, 13, 17, 22 тыс. …
## (своя земля новой игры — Land.START_PLOTS)
const PLOT_BASE := 6000
const PLOT_GROW := 1.3

# ---------- жители ----------

## base — счастье дома без лавок и украшений; deco_max — сколько могут дать украшения (см. City.compute)
const CLASSES := {
	"plebs": {"name": "Плебеи", "one": "Плебеи", "icon": "person", "house": "house_pleb", "tax": 1.2, "per_floor": 4, "work": 0.5,
		"needs": ["food"], "base": 44, "deco_max": 12},
	"artisans": {"name": "Ремесленники", "one": "Ремесленники", "icon": "hammer", "house": "house_artisan", "tax": 2.2, "per_floor": 3, "work": 0.5,
		"needs": ["food", "clothes", "fun"], "base": 41, "deco_max": 14},
	"patricians": {"name": "Патриции", "one": "Патриции", "icon": "toga", "house": "house_patrician", "tax": 4.5, "per_floor": 3, "work": 0.35,
		"needs": ["food", "clothes", "fun", "services", "goods"], "base": 38, "deco_max": 16},
}
const CLASS_ORDER := ["plebs", "artisans", "patricians"]
## повозка с новыми семьями — раз в столько игровых часов (по уровню города); счастье города ускоряет (ARRIVE_FAST)
const ARRIVE_EVERY := [2.0, 2.5, 2.6, 2.4, 2.25, 2.1, 1.95, 1.8]
const ARRIVAL_MAX := [2, 2, 2, 2, 3, 3, 3, 3]   # сколько семей может ждать жилья (по уровню города), как в Town to City
## семей в повозке — не больше (по уровню города): с Городка повозка больше — иначе большой город не растёт
## быстрее одного рейса туда-обратно (бот темпа, test_pace)
const FAMILIES_PER_CART := [2, 2, 2, 2, 3, 3, 3, 3]
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

## rp_h — очков исследований в час привозит почта на станцию (растёт со станцией).
## Новый уровень — как в Town to City: город сам не растёт, а когда выполнены условия (жители pop, счастье happy
## и постройки need), игрок жмёт «Перейти на новый уровень» (City.rank_up). need — постройки, которые можно
## открыть исследованиями ПРЕДЫДУЩЕГО уровня или раньше (иначе тупик): p — как у просьб (City.progress_of), n — сколько
## text — строка чек-листа, say — то же во фразе советника («нужно 60 жителей, … и склад»)
const LEVELS := [
	{"name": "Стоянка", "pop": 0, "happy": 0, "money": 2500, "rp": 250, "rp_h": 1.0, "need": []},
	{"name": "Хутор", "pop": 20, "happy": 55, "money": 4000, "rp": 500, "rp_h": 2.5, "need": [
		{"p": ["count", "stall_fruit"], "n": 1, "text": "Фруктовая лавка", "icon": "food", "say": "фруктовая лавка"},
		{"p": ["count", "scriptorium"], "n": 1, "text": "Скрипторий", "icon": "quill", "say": "скрипторий"}]},
	{"name": "Деревня", "pop": 60, "happy": 58, "money": 8000, "rp": 800, "rp_h": 4.5, "need": [
		{"p": ["shops", "food"], "n": 3, "text": "Разные лавки еды", "icon": "food", "say": "три разные лавки еды"},
		{"p": ["count", "warehouse"], "n": 1, "text": "Склад", "icon": "warehouse", "say": "склад"},
		{"p": ["floors", 2], "n": 2, "text": "Дома в 2 этажа", "icon": "housing", "say": "два дома в 2 этажа"}]},
	{"name": "Посёлок", "pop": 180, "happy": 60, "money": 12000, "rp": 1100, "rp_h": 5.0, "need": [
		{"p": ["count", "school"], "n": 1, "text": "Школа", "icon": "teacher", "say": "школа"},
		{"p": ["count", "house_artisan"], "n": 4, "text": "Дома ремесленников", "icon": "hammer", "say": "четыре дома ремесленников"},
		{"p": ["count", "fountain"], "n": 1, "text": "Фонтан", "icon": "water", "say": "фонтан"}]},
	{"name": "Городок", "pop": 320, "happy": 62, "money": 20000, "rp": 1300, "rp_h": 5.5, "need": [
		{"p": ["count", "temple"], "n": 1, "text": "Храм", "icon": "level", "say": "храм"},
		{"p": ["shops", "clothes"], "n": 2, "text": "Разные лавки одежды", "icon": "clothes", "say": "две разные лавки одежды"},
		{"p": ["floors", 2], "n": 10, "text": "Дома в 2 этажа", "icon": "housing", "say": "десять домов в 2 этажа"}]},
	{"name": "Город", "pop": 520, "happy": 64, "money": 30000, "rp": 1600, "rp_h": 6.0, "need": [
		{"p": ["count", "house_patrician"], "n": 3, "text": "Домусы патрициев", "icon": "toga", "say": "три домуса патрициев"},
		{"p": ["count", "library"], "n": 1, "text": "Библиотека", "icon": "bookshelf", "say": "библиотека"},
		{"p": ["floors", 3], "n": 3, "text": "Дома в 3 этажа", "icon": "housing", "say": "три дома в 3 этажа"}]},
	{"name": "Большой город", "pop": 800, "happy": 66, "money": 50000, "rp": 2800, "rp_h": 7.0, "need": [
		{"p": ["count", "forum"], "n": 1, "text": "Форум", "icon": "caesar", "say": "форум"},
		{"p": ["shops", "services"], "n": 2, "text": "Разные лавки услуг", "icon": "services", "say": "две разные лавки услуг"},
		{"p": ["cls", "patricians"], "n": 30, "text": "Патриции", "icon": "toga", "say": "30 патрициев"}]},
	{"name": "Вечный город", "pop": 1200, "happy": 68, "money": 100000, "rp": 6000, "rp_h": 9.0, "need": [
		{"p": ["count", "academy"], "n": 1, "text": "Академия", "icon": "book", "say": "академия"},
		{"p": ["count", "theatre"], "n": 1, "text": "Театр", "icon": "fun", "say": "театр"},
		{"p": ["floors", 3], "n": 15, "text": "Дома в 3 этажа", "icon": "housing", "say": "15 домов в 3 этажа"}]},
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
	# жильё: этаж покупает игрок инструментом «Этаж» (U), когда дом полон и жителям хорошо (Defs.FLOOR_HAPPY)
	"house_pleb": {"kind": "house", "cat": "housing", "cls": "plebs", "name": "Дом плебеев", "cost": 100, "variants": 5,
		"desc": "Скромный дом для простых римлян. Когда дом полон и жители счастливы, инструментом «Этаж» (справа внизу, клавиша U) можно надстроить этаж — для новой семьи."},
	"house_artisan": {"kind": "house", "cat": "housing", "cls": "artisans", "name": "Дом ремесленников", "cost": 350, "variants": 5, "unlock": "artisans",
		"desc": "Дом с мастерской внизу. Ремесленникам нужны еда, одежда и развлечения."},
	"house_patrician": {"kind": "house", "cat": "housing", "cls": "patricians", "name": "Домус патрициев", "cost": 1000, "variants": 4, "unlock": "patricians",
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
	# max — сколько можно держать на каждом уровне города (лишние, поставленные раньше, стоят, но не работают:
	# работают первые по номеру); rp_up — прибавка к очкам за исследование (доля от rp); gen — «нет … » (для подсказок)
	"scriptorium": {"kind": "rp", "cat": "farming", "name": "Скрипторий", "cost": 180, "rp": 2.0, "jobs": {"plebs": 2},
		"max": [1, 2, 3, 4, 5, 6, 8, 10], "rp_up": {"scribes1": 0.5, "scribes2": 0.5}, "gen": "скрипториев",
		"icon": "quill", "desc": "Писцы переписывают свитки — даёт очки исследований."},
	"school": {"kind": "rp", "cat": "farming", "name": "Школа", "cost": 800, "rp": 5.0, "jobs": {"artisans": 2}, "unlock": "school",
		"max": [0, 0, 2, 4, 5, 6, 7, 8], "gen": "школ",
		"icon": "teacher", "desc": "Грамматик учит детей — больше очков исследований."},
	"library": {"kind": "rp", "cat": "farming", "name": "Библиотека", "cost": 2500, "rp": 9.0, "jobs": {"artisans": 3}, "unlock": "library",
		"max": [0, 0, 0, 0, 2, 3, 4, 5], "gen": "библиотек",
		"icon": "bookshelf", "desc": "Тысячи свитков — много очков исследований."},
	"academy": {"kind": "rp", "cat": "farming", "name": "Академия", "cost": 6000, "rp": 12.0, "jobs": {"patricians": 3}, "unlock": "academy",
		"max": [0, 0, 0, 0, 0, 0, 1, 2], "gen": "академий",
		"icon": "book", "desc": "Философы спорят под колоннадой — очень много очков исследований."},

	# особые: памятники радуют всех вокруг
	"fountain": {"kind": "monument", "cat": "special", "name": "Фонтан", "cost": 400, "bonus": 6, "range": 3, "unlock": "fountain",
		"icon": "water", "desc": "Фонтан для квартала: вода и радость всем вокруг."},
	"temple": {"kind": "monument", "cat": "special", "name": "Храм Юпитера", "cost": 2500, "bonus": 10, "range": 4, "jobs": {"plebs": 2}, "unlock": "temple",
		"icon": "level", "desc": "Храм на подиуме с колоннадой. Значительно повышает счастье жителей поблизости."},
	"forum": {"kind": "monument", "cat": "special", "name": "Форум", "cost": 8000, "bonus": 12, "range": 5, "unlock": "forum",
		"icon": "caesar", "desc": "Сердце города: колоннада, статуи и трибуна."},
	# чудеса Легиона (Legion.WONDERS): открываются исследованием или рейтингом походов, сверх денариев стоят Славы (glory)
	"arch": {"kind": "monument", "cat": "special", "name": "Триумфальная арка", "cost": 6000, "bonus": 10, "range": 4, "unlock": "arch", "glory": 25,
		"icon": "castle", "desc": "Арка в честь побед — гордость жителей. Чудо Легиона: +5% урона всем бойцам."},
	"colosseum": {"kind": "monument", "cat": "special", "name": "Амфитеатр", "cost": 30000, "bonus": 18, "range": 5, "jobs": {"patricians": 4}, "unlock": "colosseum", "glory": 50,
		"icon": "swords", "desc": "Гладиаторы и звери. Весь город ходит смотреть. Чудо Легиона: +10% здоровья бойцам и Слава каждый день."},
	"pantheon": {"kind": "monument", "cat": "special", "name": "Пантеон", "cost": 60000, "bonus": 20, "range": 5, "unlock": "pantheon", "glory": 80,
		"icon": "level", "desc": "Храм всех богов с огромным куполом. Чудо Легиона: +10% урона бойцам и Слава каждый день."},
	"center": {"kind": "center", "cat": "", "name": "Почтовая станция", "cost": 0, "fixed": true,
		"desc": "Сюда по большой дороге приезжают повозки с переселенцами и товарами."},

	# Легион (Д10, как в Hustle Castle): здания Легиона стоят на карте и растут уровнями — улучшение в карточке здания
	# (Legion: уровень, что даёт, «Улучшить — N ден., M Славы, время»); отряд, походы и чудеса — в окне «Легион».
	# unique — одна на город; unlock "bossN" — открывается победой над N-м боссом походов (Legion.boss_name),
	# "rank:N" — с уровня города N (когда Легион собран). Казармы — с «Хутора», историей «Разбойники у арки» (Д9):
	# 400 вместо прежних 1500 — встают на первые деньги, не отнимая школу и дома ремесленников (бот темпа)
	"barracks": {"kind": "military", "cat": "military", "name": "Казармы", "cost": 400, "unlock": "legion", "unique": true, "icon": "legion",
		"desc": "Дом легионеров — щит и меч, держат строй. Улучшайте Казармы в их карточке: легионеры сильнее, мест в отряде больше. Лучше всего — в военном квартале у арки."},
	"range": {"kind": "military", "cat": "military", "name": "Стрельбище", "cost": 800, "unlock": "archery", "unique": true, "icon": "arrow",
		"desc": "Мишени и навес для стрелков: открывает лучников. Улучшайте Стрельбище в его карточке — лучники станут сильнее."},
	"spearcamp": {"kind": "military", "cat": "military", "name": "Лагерь копейщиков", "cost": 1800, "unlock": "boss1", "unique": true, "icon": "tent",
		"desc": "Палатки и чучела для учёбы: открывает копейщиков в тяжёлой броне — грозу зверей и великанов. Улучшения — в карточке лагеря."},
	"ballistae": {"kind": "military", "cat": "military", "name": "Мастерская баллист", "cost": 2800, "unlock": "boss3", "unique": true, "icon": "anvil",
		"desc": "Мастера собирают баллисты: болт пробивает строй врагов насквозь. Улучшения — в карточке мастерской."},
	"catapults": {"kind": "military", "cat": "military", "name": "Мастерская катапульт", "cost": 3400, "unlock": "boss5", "unique": true, "icon": "saw",
		"desc": "Здесь строят онагры: камень накрывает толпу врагов. Улучшения — в карточке мастерской."},
	"forge": {"kind": "military", "cat": "military", "name": "Кузница", "cost": 900, "unlock": "rank:2", "unique": true, "icon": "swords",
		"desc": "Кузнецы куют мечи и доспехи для Легиона: каждый уровень — +3% урона и здоровья всем бойцам в походах."},
	"infirmary": {"kind": "military", "cat": "military", "name": "Лазарет", "cost": 1300, "unlock": "rank:3", "unique": true, "icon": "medic",
		"desc": "Лекари и койки для раненых: между волнами боя бойцы восстанавливают здоровье — с каждым уровнем больше."},
	"armory": {"kind": "military", "cat": "military", "name": "Склад оружия", "cost": 2000, "unlock": "rank:4", "unique": true, "icon": "shield",
		"desc": "Щиты, шлемы и доспехи про запас: каждый уровень — +2 брони всем бойцам в походах. Позже здесь будет снаряжение героя."},

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
	# заборы (seg): тянут мышью, как дорогу, — звенья по линии; variant 1 — калитка (gate). menu: false — новых нет в витрине меню
	"fence": {"kind": "decor", "cat": "decor", "sub": "yard", "unlock": "q_garden", "name": "Плетень", "cost": 5, "deco": 1, "seg": true, "gate": true, "desc": "Плетёный забор вокруг двора. Тяните мышью, как дорогу: звенья встанут по линии."},
	"fence_2": {"kind": "decor", "cat": "decor", "sub": "yard", "base": "fence", "look": 1, "unlock": "q_garden", "name": "Калитка", "cost": 10, "deco": 2, "desc": "Калитка между каменными столбиками с вазами."},
	"fence_3": {"kind": "decor", "cat": "decor", "sub": "yard", "base": "fence", "look": 2, "color": 1, "unlock": "q_garden", "name": "Садовая стенка", "cost": 15, "deco": 2, "seg": true, "gate": true, "desc": "Низкая оштукатуренная стенка с вазонами и плющом, как в Помпеях. Тяните мышью, как дорогу."},
	"fence_wood": {"kind": "decor", "cat": "decor", "sub": "yard", "unlock": "q_garden", "name": "Ограда", "cost": 6, "deco": 1, "seg": true, "gate": true, "menu": false, "desc": "Деревянные жерди между каменными столбиками. Тяните мышью, как дорогу: звенья встанут по линии."},
	"hedge": {"kind": "decor", "cat": "decor", "sub": "yard", "unlock": "q_garden", "name": "Живая изгородь", "cost": 8, "deco": 2, "seg": true, "gate": true, "menu": false, "desc": "Подстриженная зелёная изгородь, в ней цветы. Тяните мышью, как дорогу."},
	"stonewall": {"kind": "decor", "cat": "decor", "sub": "yard", "unlock": "q_garden", "name": "Каменная стенка", "cost": 12, "deco": 2, "seg": true, "gate": true, "menu": false, "desc": "Низкая стенка из камня с плитами поверху. Тяните мышью, как дорогу."},
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
	# трофеи Легиона: все 30 звёзд провинции (Legion.REGIONS trophy) — бесплатно, одна на город
	"trophy_cart": {"kind": "decor", "cat": "decor", "sub": "stone", "name": "Телега атамана", "cost": 0, "deco": 10, "unlock": "trophy:forest", "unique": true, "trophy": true,
		"desc": "Трофей Легиона за все 30 звёзд «Леса разбойников»: телега атамана со щитами, копьями и знаменем шайки."},
	# животные
	"sheep": {"kind": "decor", "cat": "decor", "sub": "animals", "name": "Овцы в загоне", "cost": 30, "deco": 3, "unlock": "animals", "desc": "Пара овечек в загоне с плетнём и корытцем."},
	"sheep_2": {"kind": "decor", "cat": "decor", "sub": "animals", "base": "sheep", "look": 1, "name": "Овцы на лугу", "cost": 30, "deco": 3, "unlock": "animals", "desc": "Пара овечек пасётся на лугу, в углу копёшка."},
	"duck": {"kind": "decor", "cat": "decor", "sub": "animals", "name": "Утки", "cost": 15, "deco": 3, "unlock": "animals", "water": true, "desc": "Утки плавают по пруду."},
	"swan": {"kind": "decor", "cat": "decor", "sub": "animals", "name": "Лебедь", "cost": 25, "deco": 4, "unlock": "animals", "water": true, "desc": "Белый лебедь на воде."},
	# награды историй горожан (StoryDefs, unlock «s_…»): в витрине меню их нет
	"catbasket": {"kind": "decor", "cat": "decor", "sub": "animals", "name": "Кошачья корзинка", "cost": 15, "deco": 3, "unlock": "s_cat", "story": true,
		"desc": "Плетёная корзинка с подушкой и миска молока — в корзинке дремлет рыжая кошка. Награда за историю «Где Мурка?»."},
	"latrunc": {"kind": "decor", "cat": "decor", "sub": "street", "name": "Стол для латрункулов", "cost": 40, "deco": 4, "unlock": "s_square", "story": true,
		"desc": "Столик с доской для латрункулов, два табурета, кувшин и чаши. По утрам старики садятся играть. Награда за историю «Скверик для стариков»."},
	"rosearch": {"kind": "decor", "cat": "decor", "sub": "plants", "name": "Арка из роз", "cost": 60, "deco": 5, "unlock": "s_wedding", "story": true,
		"desc": "Садовая арка, увитая цветущими розами, у подножия — вазоны. Под такой аркой гуляют молодые. Награда за историю «Свадьба Юлии»."},
	"nymphfountain": {"kind": "decor", "cat": "decor", "sub": "stone", "base": "smallfountain", "look": 3, "name": "Фонтан с нимфой", "cost": 120, "deco": 6, "unlock": "s_leak", "story": true,
		"desc": "Круглая чаша, посреди — мраморная нимфа льёт воду из кувшина. Из такого фонтана пьют и старики в скверике. Награда за историю «Течь в водопроводе»."},
	"donkeypost": {"kind": "decor", "cat": "decor", "sub": "animals", "name": "Ослик у коновязи", "cost": 40, "deco": 4, "unlock": "s_donkey", "story": true,
		"desc": "Коновязь с поилкой и охапкой сена, у неё жуёт серый ослик. Награда за историю «Ослик возчика»."},
	"balcony": {"kind": "decor", "cat": "decor", "sub": "street", "name": "Балкон с бельём", "cost": 40, "deco": 4, "wall": true, "unlock": "s_crowded", "story": true,
		"desc": "Деревянный балкон на втором этаже: на верёвке сохнет бельё, на перилах — ковёр, в углу — цветы. Вешается на дом в 2–3 этажа. Награда за историю горожан «Тесно в доме»."},
	"legionpost": {"kind": "decor", "cat": "decor", "sub": "street", "name": "Сторожевой пост", "cost": 60, "deco": 5, "light": true, "unlock": "s_bandits", "story": true,
		"desc": "Знамя легиона с золотым навершием, стойка с копьями, щит и жаровня — дозор у дороги, чтобы разбойникам неповадно было. Ночью горит огонь. Награда за историю горожан «Разбойники у арки»."},
	# редкие облики — награды «Заказов старосты» (StoryOrders, unlock «o_…»): в витрине меню их нет
	"lamp_post_4": {"kind": "decor", "cat": "decor", "sub": "light", "base": "lamp_post", "look": 3, "name": "Фонарь с двумя кашпо", "cost": 25, "deco": 4, "light": true, "unlock": "o_well", "story": true,
		"desc": "Фонарь на столбе, по обе стороны перекладины — кашпо с цветами. Ночью светит на улицу. Награда старосты."},
	"planter_4": {"kind": "decor", "cat": "decor", "sub": "plants", "base": "planter", "look": 3, "name": "Пальма в мраморной кадке", "cost": 18, "deco": 4, "unlock": "o_yard", "story": true,
		"desc": "Южная пальма в мраморной кадке на ступени, у подножия — горшочки с цветами. Награда старосты."},
	"smallfountain_3": {"kind": "decor", "cat": "decor", "sub": "stone", "base": "smallfountain", "look": 2, "name": "Фонтан-раковина", "cost": 90, "deco": 6, "unlock": "o_benches", "story": true,
		"desc": "Золочёная раковина на мраморной подставке, из неё стекает вода в низкую чашу. Награда старосты."},
	"banner_3": {"kind": "decor", "cat": "decor", "sub": "street", "base": "banner", "look": 2, "name": "Знамя старосты", "cost": 35, "deco": 4, "unlock": "o_park", "story": true,
		"desc": "Пурпурное знамя на высоком шесте с позолоченными бляхами, у подножия — вазоны. Награда старосты."},
	"statue_5": {"kind": "decor", "cat": "decor", "sub": "stone", "base": "statue", "look": 4, "name": "Мальчик с птицей", "cost": 240, "deco": 10, "unlock": "o_night", "story": true,
		"desc": "Мраморный мальчик выпускает птицу, постамент в цветах. Награда старосты."},
	"column_2": {"kind": "decor", "cat": "decor", "sub": "stone", "base": "column", "look": 1, "name": "Колонна с золотым навершием", "cost": 320, "deco": 11, "unlock": "o_temple", "story": true,
		"desc": "Колонна в розах, наверху — позолоченное навершие, как у знамён легиона. Награда старосты."},
	"sundial_3": {"kind": "decor", "cat": "decor", "sub": "stone", "base": "sundial", "look": 2, "name": "Часы с позолотой", "cost": 140, "deco": 7, "unlock": "o_eternal", "story": true,
		"desc": "Солнечные часы на мраморной колонне с позолоченным навершием, вокруг — вазоны. Награда старосты."},
}

## Разделы меню стройки (снизу посередине) и вкладки коммерции
## Вкладки раздела «Украшения» (как вкладки потребностей у лавок)
const DECOR_SUBS := [["plants", "Цветы", "daisy"], ["trees", "Деревья", "pine"], ["light", "Свет", "lamp"],
	["street", "Улица", "bench"], ["yard", "Двор и рынок", "cart"], ["stone", "Статуи и камень", "mona"], ["animals", "Животные", "swan"]]
const CATS := [["housing", "Жильё", "housing"], ["commerce", "Коммерция", "commerce"], ["farming", "Хозяйство и науки", "farming"],
	["decor", "Украшения", "decor"], ["special", "Особые постройки", "special"], ["military", "Легион", "legion"]]
## Подписи разделов на кнопках меню стройки (и в событии «Изучено: … — карточка в «Лавки · Товары»»)
const CAT_SHORT := {"housing": "Жильё", "commerce": "Лавки", "farming": "Хозяйство", "decor": "Украшения", "special": "Памятники", "military": "Легион"}

# ---------- исследования ----------
## Каждый уровень города открывает свой раздел. unlock — что даёт (постройку открывает её ключ в B.unlock).
## Цены рядов подобраны ботом темпа (test_pace -- bot): к новому уровню изучено около 70–90% своего ряда, а самое
## дорогое в ряду помещается на полки этого уровня (с «Новыми полками» — вдвое больше, с Городка).
## Кривая очков v2 (этап 2.1, решение владельца Q1): на «Хуторе» исследование — раз в ~1,8 мин, а не раз в минуту;
## Пекарня и Сапожник — в ряду «Деревни»; самое дорогое в ряду «Деревни» — четверть полок, а не половина.
## story — исследование открывает история горожан (без очков): в свитке оно серое, изучить нельзя
const RESEARCH := [
	# первые исследования дешёвые: просьбы до хутора дают ~65 очков
	{"id": "stall_veg", "lvl": 0, "name": "Овощная лавка", "cost": 20, "icon": "veg"},
	{"id": "stall_fish", "lvl": 0, "name": "Рыбная лавка", "cost": 30, "icon": "fish"},
	{"id": "reach1", "lvl": 0, "name": "Больший охват", "cost": 80, "icon": "arrow", "after": "stall_veg",
		"desc": "Лавки с едой обслуживают дома на треть дальше."},
	{"id": "farm", "lvl": 0, "name": "Пшеничное поле", "cost": 50, "icon": "wheat"},
	{"id": "deco_flowers", "lvl": 0, "name": "Цветы и вазоны", "cost": 15, "icon": "daisy"},
	{"id": "deco_trees", "lvl": 0, "name": "Деревья и кусты", "cost": 15, "icon": "tree"},
	{"id": "musicians", "lvl": 0, "name": "Уличные музыканты", "cost": 40, "icon": "lyre"},

	{"id": "floor2", "lvl": 1, "name": "Второй жилой этаж", "cost": 60, "icon": "housing",
		"desc": "Открывает инструмент «Этаж» (справа внизу, клавиша U): второй этаж можно купить дому, когда он полон, а счастье в нём не ниже 65%. Туда въедет ещё одна семья."},
	{"id": "weaver", "lvl": 1, "name": "Ткацкая лавка", "cost": 50, "icon": "wool"},
	{"id": "warehouse", "lvl": 1, "name": "Склад", "cost": 60, "icon": "warehouse"},
	{"id": "butcher", "lvl": 1, "name": "Мясная лавка", "cost": 80, "icon": "meat", "after": "warehouse"},
	{"id": "fountain", "lvl": 1, "name": "Фонтаны", "cost": 90, "icon": "water"},
	{"id": "animals", "lvl": 1, "name": "Животные: утки, лебеди, овцы", "cost": 40, "icon": "swan"},
	{"id": "scribes1", "lvl": 1, "name": "Ученики писцов", "cost": 40, "icon": "quill",
		"desc": "За писцами садятся ученики: каждый скрипторий даёт 3 очка исследований в час вместо 2."},
	# Легион — с «Хутора», но не за очки: его открывает история «Разбойники у арки» (решение владельца Д9)
	{"id": "legion", "lvl": 1, "name": "Легион", "cost": 0, "icon": "legion", "story": "bandits",
		"desc": "Открывает Казармы и окно «Легион»: отряд идёт походом против разбойников, зверей и чудовищ, добывает Славу и денарии. Новые провинции открываются по мере роста города."},

	{"id": "artisans", "lvl": 2, "name": "Класс ремесленников", "cost": 180, "icon": "hammer",
		"desc": "Открывает дома ремесленников. Им нужны еда, одежда и развлечения."},
	{"id": "cobbler", "lvl": 2, "name": "Сапожник", "cost": 120, "icon": "boots", "after": "weaver"},
	{"id": "bakery", "lvl": 2, "name": "Пекарня", "cost": 130, "icon": "bread", "after": "warehouse"},
	{"id": "dice", "lvl": 2, "name": "Игра в кости", "cost": 180, "icon": "dice"},
	{"id": "barber", "lvl": 2, "name": "Цирюльня", "cost": 200, "icon": "razor"},
	{"id": "thermopolium", "lvl": 2, "name": "Термополий", "cost": 220, "icon": "meal"},
	{"id": "school", "lvl": 2, "name": "Школа", "cost": 180, "icon": "teacher"},
	{"id": "grove", "lvl": 2, "name": "Оливковая роща", "cost": 160, "icon": "olive"},
	{"id": "oilshop", "lvl": 2, "name": "Масляная лавка", "cost": 200, "icon": "amphora", "after": "grove"},
	{"id": "deco_stone", "lvl": 2, "name": "Каменные украшения", "cost": 200, "icon": "mona"},
	{"id": "store1", "lvl": 2, "name": "Больше носильщиков", "cost": 220, "icon": "warehouse", "after": "warehouse",
		"desc": "Склад разносит товары вдвое дальше."},
	# лучники — с «Деревни»: лес (с «Хутора») просит лучника уже во втором бою — «пращники в кустах»
	{"id": "archery", "lvl": 2, "name": "Стрельбище", "cost": 200, "icon": "arrow", "after": "legion", "desc": "Лучники для Легиона: бьют издалека и снимают вражеских стрелков."},

	{"id": "floor3", "lvl": 3, "name": "Третий жилой этаж", "cost": 450, "icon": "housing", "after": "floor2",
		"desc": "Третий этаж — тем же инструментом «Этаж» (U): полному дому со счастьем не ниже 75%."},
	{"id": "dyer", "lvl": 3, "name": "Красильня", "cost": 360, "icon": "cape"},
	{"id": "potter", "lvl": 3, "name": "Гончарная", "cost": 320, "icon": "pottery"},
	{"id": "mimes", "lvl": 3, "name": "Помост мимов", "cost": 350, "icon": "puppet"},
	{"id": "temple", "lvl": 3, "name": "Храм", "cost": 460, "icon": "level"},
	{"id": "fullonica", "lvl": 3, "name": "Фуллоника", "cost": 390, "icon": "tshirt"},
	{"id": "deco_metal", "lvl": 3, "name": "Жаровни и знамёна", "cost": 220, "icon": "candle"},
	{"id": "vault1", "lvl": 3, "name": "Новое хранилище денег", "cost": 370, "icon": "money", "desc": "Казна вмещает вдвое больше."},
	{"id": "scribes2", "lvl": 3, "name": "Мастерская писцов", "cost": 330, "icon": "quill", "after": "scribes1",
		"desc": "Скрипторий даёт 4 очка исследований в час."},

	{"id": "patricians", "lvl": 4, "name": "Класс патрициев", "cost": 750, "icon": "toga",
		"desc": "Открывает домусы патрициев. Им нужно всё: еда, одежда, развлечения, услуги и товары."},
	{"id": "balnea", "lvl": 4, "name": "Бани", "cost": 750, "icon": "bath"},
	{"id": "lamps", "lvl": 4, "name": "Мастер светильников", "cost": 720, "icon": "candle"},
	{"id": "library", "lvl": 4, "name": "Библиотека", "cost": 750, "icon": "bookshelf", "after": "school"},
	{"id": "vineyard", "lvl": 4, "name": "Виноградник", "cost": 480, "icon": "grapes"},
	{"id": "wineshop", "lvl": 4, "name": "Винная лавка", "cost": 660, "icon": "wine", "after": "vineyard"},
	{"id": "odeon", "lvl": 4, "name": "Одеон", "cost": 950, "icon": "harp"},
	{"id": "taberna", "lvl": 4, "name": "Таверна", "cost": 890, "icon": "mug"},
	{"id": "research1", "lvl": 4, "name": "Новые полки для свитков", "cost": 690, "icon": "scroll", "desc": "Очков исследований помещается вдвое больше."},

	{"id": "perfumer", "lvl": 5, "name": "Парфюмер", "cost": 1350, "icon": "perfume"},
	{"id": "medic", "lvl": 5, "name": "Лекарь", "cost": 1190, "icon": "medic"},
	{"id": "tailor", "lvl": 5, "name": "Мастерская тог", "cost": 1550, "icon": "toga"},
	{"id": "baths", "lvl": 5, "name": "Термы", "cost": 1740, "icon": "water", "after": "balnea"},
	{"id": "jeweler", "lvl": 5, "name": "Ювелир", "cost": 1930, "icon": "ring"},
	{"id": "forum", "lvl": 5, "name": "Форум", "cost": 2310, "icon": "caesar"},
	{"id": "taxes1", "lvl": 5, "name": "Налоги для богатых", "cost": 1740, "icon": "coins", "desc": "Патриции платят на четверть больше."},

	{"id": "theatre", "lvl": 6, "name": "Театр", "cost": 4830, "icon": "fun", "after": "odeon"},
	{"id": "arch", "lvl": 6, "name": "Триумфальная арка", "cost": 4190, "icon": "castle"},
	{"id": "academy", "lvl": 6, "name": "Академия", "cost": 5150, "icon": "book", "after": "library"},
	{"id": "vault2", "lvl": 6, "name": "Подвалы казны", "cost": 3860, "icon": "money", "after": "vault1", "desc": "Казна вмещает ещё вдвое больше."},

	{"id": "colosseum", "lvl": 7, "name": "Амфитеатр", "cost": 10000, "icon": "swords"},
	# не дороже предела очков на высшем уровне (6000 × 2 с «research1») — иначе изучить нельзя вовсе
	{"id": "pantheon", "lvl": 7, "name": "Пантеон", "cost": 11500, "icon": "level"},
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
	# первые просьбы — до хутора и деревни — лёгкие, но скупые на очки и денарии (этап 2.1/2.3: исследование на «Хуторе» —
	# раз в ~1,8 мин, денег впритык); щедрые денежные награды — с «Деревни» (просьбы «Деревни» — на ~40% щедрее прежнего:
	# там надо разом и школу, и дома ремесленников, и Казармы, и этажи)
	{"id": "road1", "who": "advisor", "text": "Проложите мостовую от станции", "p": ["road"], "need": 40, "money": 50, "rp": 0, "icon": "road",
		"hint": "Выберите «Мостовую» слева внизу и ведите кисть с зажатой левой кнопкой мыши от площади у станции."},
	{"id": "houses3", "who": "advisor", "text": "Постройте 3 дома у дороги", "p": ["houses"], "need": 3, "money": 50, "rp": 5, "tool": "house_pleb", "icon": "housing",
		"hint": "Дом ставится фасадом к дороге. Повозка привезёт семьи по большой дороге."},
	{"id": "fam3", "who": "advisor", "text": "Заселите три семьи", "p": ["fam"], "need": 3, "money": 50, "rp": 5, "icon": "family",
		"hint": "Семьи ждут на площади у станции. Нажмите на значок семьи слева вверху и выберите им дом."},
	{"id": "fruit", "who": "plebs", "text": "Нам бы поесть: фруктовая лавка", "p": ["count", "stall_fruit"], "need": 1, "money": 40, "rp": 5, "tool": "stall_fruit", "icon": "food",
		"hint": "Лавка кормит ближайшие дома в своей дальности. Чем больше разных лавок рядом, тем счастливее дом."},
	{"id": "scriptorium", "who": "advisor", "text": "Постройте скрипторий", "p": ["count", "scriptorium"], "need": 1, "money": 50, "rp": 10, "tool": "scriptorium", "icon": "quill",
		"hint": "Скрипторий даёт очки исследований — за них открываются новые постройки."},
	{"id": "research1", "who": "advisor", "text": "Изучите что-нибудь", "p": ["research"], "need": 1, "money": 50, "rp": 10, "icon": "research",
		"hint": "Нажмите на свиток вверху справа — откроется меню исследований. Очки исследований дают скрипторий, школа и библиотека."},
	{"id": "lights", "who": "plebs", "text": "Ночью темно: 3 фонаря на столбах", "p": ["count", "lamp_post"], "need": 3, "money": 40, "rp": 10, "tool": "lamp_post", "icon": "candle",
		"unlock": "q_lights", "reward": "факелы и фонари на стены, светильники",
		"hint": "Фонари радуют дома вокруг и светят ночью. Поставьте их вдоль улиц."},
	{"id": "decor5", "who": "plebs", "text": "Красоты хочется: 5 украшений", "p": ["kind", "decor"], "need": 5, "money": 40, "rp": 10, "icon": "flower",
		"unlock": "q_garden", "reward": "цветы на стены, плетень, стог сена",
		"hint": "Украшения дают дому очки красоты: +1% счастья за каждые 2 очка (у плебеев до +12%). Ставьте их в промежутках между домами."},
	{"id": "fed6", "who": "plebs", "text": "Еды на всех: 6 сытых домов", "p": ["fed", "food"], "need": 6, "money": 60, "rp": 10, "icon": "food",
		"hint": "Дом сыт, если рядом лавка с едой и в ней хватает работников. Откройте «Обзор» (глаз вверху справа) и выберите «Еда» — красные дома без еды."},
	{"id": "hamlet", "who": "advisor", "text": "Станьте хутором", "p": ["rank", 1], "need": 4, "money": 150, "rp": 25, "icon": "level",
		"hint": RANK_HINT},
	{"id": "scriptorium2", "who": "advisor", "text": "Второй скрипторий", "p": ["count", "scriptorium"], "need": 2, "money": 80, "rp": 15, "tool": "scriptorium", "icon": "quill",
		"hint": "На хуторе можно держать два скриптория, в деревне — три. Больше скрипториев — быстрее исследования."},
	{"id": "market", "who": "plebs", "text": "Рынок: 4 разные лавки", "p": ["shops"], "need": 4, "money": 140, "rp": 25, "icon": "commerce",
		"unlock": "q_market", "reward": "телега, корзины и амфоры",
		"hint": "Разные лавки рядом делают дома счастливее. Откройте новые в исследованиях."},
	{"id": "floor2", "who": "plebs", "text": "Нам тесно: дом в 2 этажа", "p": ["floors", 2], "need": 1, "money": 250, "rp": 30, "icon": "housing",
		"hint": "Изучите «Второй жилой этаж». Потом нажмите «Этаж» справа внизу (или U) и щёлкните по дому со стрелкой — это полный дом со счастьем от 65%."},
	{"id": "pop40", "who": "advisor", "text": "Соберите 40 жителей", "p": ["pop"], "need": 40, "money": 140, "rp": 25, "icon": "family",
		"hint": POP_HINT},
	{"id": "fountain4", "who": "plebs", "text": "Вода рядом: фонтан у 4 домов", "p": ["near", "fountain", "plebs"], "need": 4, "money": 200, "rp": 30, "icon": "water",
		"hint": "Изучите «Фонтаны» и поставьте фонтан посреди домов плебеев."},
	{"id": "village", "who": "advisor", "text": "Станьте деревней", "p": ["rank", 2], "need": 5, "money": 800, "rp": 60, "icon": "level",
		"hint": RANK_HINT},
	{"id": "store", "who": "plebs", "text": "Склад и мясная лавка", "p": ["store"], "need": 2, "money": 300, "rp": 40, "icon": "warehouse",
		"parts": [{"p": ["count", "warehouse"], "n": 1, "tool": "warehouse", "text": "Склад", "icon": "warehouse"},
			{"p": ["count", "butcher"], "n": 1, "tool": "butcher", "text": "Мясная лавка", "icon": "meat"}],
		"hint": "Склад хранит товары и разносит их лавкам вокруг себя. Мясная лавка берёт мясо со склада — ставьте её в охвате склада: с лавкой в руках дома и лавки в охвате подсвечиваются. Обе открываются исследованиями — сначала «Склад», потом «Мясная лавка»."},
	{"id": "happy60", "who": "advisor", "text": "Счастье города 60%", "p": ["happy"], "need": 60, "money": 300, "rp": 50, "icon": "happy",
		"hint": "Новые семьи едут только в город, где счастье не ниже 60%. Разные лавки рядом с домами, украшения и памятники поднимают счастье."},
	{"id": "pop100", "who": "advisor", "text": "Соберите 100 жителей", "p": ["pop"], "need": 100, "money": 500, "rp": 60, "icon": "family",
		"hint": POP_HINT},
	{"id": "artisan", "who": "advisor", "text": "Постройте дом ремесленников", "p": ["count", "house_artisan"], "need": 1, "money": 400, "rp": 50, "tool": "house_artisan", "icon": "hammer",
		"hint": "Дом ремесленников открывает исследование «Класс ремесленников». Ставится, как плебейский, — фасадом к дороге. Ремесленникам нужны рядом еда, одежда и развлечения."},
	{"id": "art12", "who": "artisans", "text": "Поселите 12 ремесленников", "p": ["cls", "artisans"], "need": 12, "money": 450, "rp": 60, "icon": "hammer",
		"hint": "Ремесленники приезжают в повозке, когда есть свободные дома ремесленников. Постройте ещё таких домов у дорог, а рядом — еду, одежду и развлечения: тогда семьи едут охотно."},
	{"id": "clothes8", "who": "artisans", "text": "Одежду всем: 8 домов с одеждой", "p": ["fed", "clothes"], "need": 8, "money": 450, "rp": 60, "icon": "clothes",
		"hint": "Дом одет, если рядом лавка одежды и в ней хватает работников. Откройте «Обзор» (глаз вверху справа) → «Одежда»: красные дома без одежды — поставьте лавку одежды между ними."},
	{"id": "floor2x5", "who": "plebs", "text": "Пять домов в 2 этажа", "p": ["floors", 2], "need": 5, "money": 500, "rp": 60, "icon": "housing",
		"hint": "Этаж надстраивают полному дому, где счастье от 65%. Нажмите «Этаж» справа внизу (или U) и ведите мышью вдоль улицы — этаж получат все готовые дома под курсором."},
	{"id": "temple", "who": "artisans", "text": "Постройте храм", "p": ["count", "temple"], "need": 1, "money": 800, "rp": 150, "tool": "temple", "icon": "level",
		"hint": "Храм открывает исследование «Храм» (уровень «Посёлок»). Это большой памятник: радует все дома в своём охвате — ставьте его посреди кварталов."},
	{"id": "school", "who": "artisans", "text": "Детям нужна школа", "p": ["count", "school"], "need": 1, "money": 450, "rp": 120, "tool": "school", "icon": "teacher",
		"hint": "Школу открывает исследование «Школа» (уровень «Деревня»). Она даёт очки исследований, а работают в ней ремесленники — без них школа стоит."},
	{"id": "pop300", "who": "advisor", "text": "Соберите 300 жителей", "p": ["pop"], "need": 300, "money": 900, "rp": 200, "icon": "family",
		"hint": POP_HINT},
	{"id": "patrician", "who": "advisor", "text": "Постройте домус патрициев", "p": ["count", "house_patrician"], "need": 1, "money": 800, "rp": 250, "tool": "house_patrician", "icon": "toga",
		"hint": "Домус открывает исследование «Класс патрициев» (уровень «Городок»). Патрициям нужно рядом всё: еда, одежда, развлечения, услуги и товары."},
	{"id": "floor3", "who": "artisans", "text": "Дом в 3 этажа", "p": ["floors", 3], "need": 1, "money": 700, "rp": 200, "icon": "housing",
		"hint": "Изучите «Третий жилой этаж». Третий этаж получает дом в 2 этажа, когда он полон и счастье в нём от 75%: «Этаж» справа внизу (или U)."},
	{"id": "pat10", "who": "patricians", "text": "Поселите 10 патрициев", "p": ["cls", "patricians"], "need": 10, "money": 900, "rp": 180, "icon": "toga",
		"hint": "Патриции приезжают в свободные домусы, если городу хорошо. Постройте ещё домусов и окружите их лавками всех пяти видов."},
	{"id": "happy70", "who": "patricians", "text": "Счастье города 70%", "p": ["happy"], "need": 70, "money": 1000, "rp": 200, "icon": "happy",
		"hint": "Наведите на счастье вверху — там видно, что его поднимет. Больше всего помогают разные лавки рядом с домами, украшения и памятники; «Обзор» покажет дома, где плохо."},
	{"id": "pop600", "who": "advisor", "text": "Соберите 600 жителей", "p": ["pop"], "need": 600, "money": 1500, "rp": 300, "icon": "family",
		"hint": POP_HINT},
	{"id": "forum", "who": "patricians", "text": "Постройте форум", "p": ["count", "forum"], "need": 1, "money": 4000, "rp": 400, "tool": "forum", "icon": "caesar",
		"hint": "Форум открывает исследование «Форум» (уровень «Город»). Это главный памятник города, он нужен для «Большого города» — оставьте под него просторное место."},
	{"id": "pop1000", "who": "advisor", "text": "Соберите 1000 жителей", "p": ["pop"], "need": 1000, "money": 3000, "rp": 600, "icon": "laurels",
		"hint": POP_HINT},
]
## Подсказка к просьбам «Соберите N жителей»: откуда берутся жители и почему повозка может стоять
const POP_HINT := "Жители прибавляются, когда повозка привозит новые семьи и вы заселяете их в дома. Повозка везёт семьи только туда, где есть свободное место, — стройте дома заранее. Первые %d семей приедут всегда, а дальше — только пока счастье города не ниже %d%%; от 70%% повозка ходит чаще. Наведите на счастье вверху — там видно, что его поднимет." % [ARRIVE_FREE, ARRIVE_HAPPY]
## Подсказка к просьбам «Станьте хутором / деревней» (список условий подставляет интерфейс — City.rank_text)
const RANK_HINT := "Новый уровень город получает не сам: когда выполнены все условия, под табличкой города появляется кнопка «Перейти на новый уровень» — нажмите её. Список условий — если навести мышь на уровень города вверху слева."
const WHO := {"advisor": ["Советник Марк", "caesar"], "plebs": ["Плебеи просят", "person"], "artisans": ["Ремесленники просят", "hammer"], "patricians": ["Патриции просят", "toga"]}


static func request(id: String) -> Dictionary:
	for r in REQUESTS:
		if r["id"] == id:
			return r
	return {}


## Чем открывается постройка: исследованием или просьбой горожан
static func unlock_text(id: String) -> String:
	if id.begins_with("boss"):
		return "победой Легиона над боссом «%s»" % Legion.boss_name(int(id.substr(4)))
	if id.begins_with("rank:"):
		return "на уровне «%s» (когда собран Легион)" % LEVELS[clampi(int(id.substr(5)), 0, LEVELS.size() - 1)]["name"]
	if id.begins_with("trophy:"):
		for R: Dictionary in Legion.REGIONS:
			if String(R["id"]) == id.substr(7):
				return "всеми 30 звёздами Легиона в провинции «%s»" % R["name"]
	var r := research(id)
	if r.has("story"):
		return "в истории горожан «%s»" % String(StoryDefs.story(String(r["story"])).get("title", r["name"]))
	if not r.is_empty():
		return "исследованием «%s»" % r["name"]
	for q in REQUESTS:
		if q.get("unlock", "") == id:
			return "наградой за просьбу «%s»" % q["text"]
	var s := StoryDefs.by_unlock(id)
	if not s.is_empty():
		return "наградой за историю горожан «%s»" % s["title"]
	var o := StoryOrders.order(id)
	if not o.is_empty():
		return "наградой за заказ старосты «%s»" % o["title"]
	return ""


static func unlock_short(id: String) -> String:
	if id.begins_with("boss"):
		return "Победа над боссом"
	if id.begins_with("rank:"):
		return "Уровень «%s»" % LEVELS[clampi(int(id.substr(5)), 0, LEVELS.size() - 1)]["name"]
	if id.begins_with("trophy:"):
		return "30 звёзд похода"
	var r := research(id)
	if r.has("story"):
		return "История горожан"
	if not r.is_empty():
		return r["name"]
	for q in REQUESTS:
		if q.get("unlock", "") == id:
			return "Просьба горожан"
	if not StoryDefs.by_unlock(id).is_empty():
		return "История горожан"
	if not StoryOrders.order(id).is_empty():
		return "Заказ старосты"
	return ""


static func research(id: String) -> Dictionary:
	for r in RESEARCH:
		if r["id"] == id:
			return r
	return {}


## Звено забора вдоль своей оси X (Catalog.DECOR × 2,5 м): так часто по линии встают звенья
const FENCE_PITCH := 1.95


## Вид украшения, к которому относится облик («flowers_2» → «flowers»); у остальных построек — сам тип
static func base_of(type: String) -> String:
	return String((B.get(type, {}) as Dictionary).get("base", type))


## Все облики вида украшения (карточки по порядку): «flowers» → [flowers, flowers_2, flowers_3]. Редкие облики-награды
## (истории, заказы старосты — story) сюда не входят: их не ставит готовый город меню, у просьб — обычные облики
static func looks_of(base: String) -> Array:
	var out := []
	for t in B:
		if t == base or ((B[t] as Dictionary).get("base", "") == base and not (B[t] as Dictionary).get("story", false)):
			out.append(t)
	return out


static func range_m(d: Dictionary) -> float:
	return float(RANGE.get(int(d.get("range", 0)), 0.0))


static func floors_max(cls: String) -> int:
	return 2 if cls == "patricians" else 3
