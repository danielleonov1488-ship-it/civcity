class_name Balance
## Числа баланса «Уютного Рима» (план docs/PLAN_COZY.md, этап 1) — в одном месте, чтобы крутить их без правки логики.
## Действуют в городах с City.cozy_v ≥ 1 (новая игра после переработки); старые сохранения и проверки на них —
## по прежним правилам (Defs.LEVELS, Defs.ARRIVE_EVERY).

## Ранги: меньше жителей, больше качества. Индекс — уровень города (как Defs.LEVELS); у каждого — жители, счастье
## города и условия-постройки (формат Defs.LEVELS need). Имена, казна и свитки — из Defs.LEVELS. Постройка в условиях
## ранга N открывается исследованием уровня не выше N−1 (театр — «Большой город», амфитеатр и цирк — после «Вечного»).
const LEVELS := [
	{},
	{"pop": 15, "happy": 55, "need": [
		{"p": ["count", "stall_fruit"], "n": 1, "text": "Фруктовая лавка", "icon": "food", "say": "фруктовая лавка"},
		{"p": ["count", "scriptorium"], "n": 1, "text": "Скрипторий", "icon": "quill", "say": "скрипторий"}]},
	{"pop": 40, "happy": 57, "need": [
		{"p": ["shops", "food"], "n": 3, "text": "Разные лавки еды", "icon": "food", "say": "три разные лавки еды"},
		{"p": ["count", "warehouse"], "n": 1, "text": "Склад", "icon": "warehouse", "say": "склад"},
		{"p": ["floors", 2], "n": 2, "text": "Дома в 2 этажа", "icon": "housing", "say": "два дома в 2 этажа"}]},
	{"pop": 90, "happy": 59, "need": [
		{"p": ["count", "school"], "n": 1, "text": "Школа", "icon": "teacher", "say": "школа"},
		{"p": ["count", "house_artisan"], "n": 2, "text": "Дома ремесленников", "icon": "hammer", "say": "два дома ремесленников"},
		{"p": ["count", "fountain"], "n": 1, "text": "Фонтан", "icon": "water", "say": "фонтан"}]},
	{"pop": 170, "happy": 61, "need": [
		{"p": ["count", "temple"], "n": 1, "text": "Храм", "icon": "level", "say": "храм"},
		{"p": ["shops", "clothes"], "n": 2, "text": "Разные лавки одежды", "icon": "clothes", "say": "две разные лавки одежды"},
		{"p": ["floors", 2], "n": 6, "text": "Дома в 2 этажа", "icon": "housing", "say": "шесть домов в 2 этажа"}]},
	{"pop": 300, "happy": 63, "need": [
		{"p": ["count", "house_patrician"], "n": 2, "text": "Домусы патрициев", "icon": "toga", "say": "два домуса патрициев"},
		{"p": ["count", "library"], "n": 1, "text": "Библиотека", "icon": "bookshelf", "say": "библиотека"},
		{"p": ["floors", 3], "n": 2, "text": "Дома в 3 этажа", "icon": "housing", "say": "два дома в 3 этажа"}]},
	{"pop": 500, "happy": 65, "need": [
		{"p": ["count", "forum"], "n": 1, "text": "Форум", "icon": "caesar", "say": "форум"},
		{"p": ["shops", "services"], "n": 2, "text": "Разные лавки услуг", "icon": "services", "say": "две разные лавки услуг"},
		{"p": ["cls", "patricians"], "n": 15, "text": "Патриции", "icon": "toga", "say": "15 патрициев"}]},
	{"pop": 800, "happy": 67, "need": [
		{"p": ["count", "academy"], "n": 1, "text": "Академия", "icon": "book", "say": "академия"},
		{"p": ["count", "theatre"], "n": 1, "text": "Театр", "icon": "fun", "say": "театр"},
		{"p": ["floors", 3], "n": 10, "text": "Дома в 3 этажа", "icon": "housing", "say": "десять домов в 3 этажа"},
		{"p": ["cls", "patricians"], "n": 30, "text": "Патриции", "icon": "toga", "say": "30 патрициев"}]},
]

## Повозка в большом городе ходит реже: промежуток × (1 + жители / ARRIVE_SLOW_POP), не больше ARRIVE_SLOW_MAX.
## 100 жителей — ×1,25; 300 — ×1,75; 800 — ×3 (рост сам себя тормозит, как в Town to City)
const ARRIVE_SLOW_POP := 400.0
const ARRIVE_SLOW_MAX := 3.0

## «Большой город»: общий штраф к счастью всех домов за величину города (сверх тесноты у дома): −1% за каждые
## SIZE_STEP жителей сверх SIZE_FREE, не больше SIZE_MAX. Большой город капризнее — его надо украшать и развлекать.
const SIZE_FREE := 120
const SIZE_STEP := 60
const SIZE_MAX := 8


## Штраф за величину города при pop жителях (≤ 0)
static func size_penalty(pop: int) -> int:
	return -mini(SIZE_MAX, maxi(0, pop - SIZE_FREE) / SIZE_STEP)


## Множитель промежутка между повозками при pop жителях
static func arrive_slow(pop: int) -> float:
	return minf(ARRIVE_SLOW_MAX, 1.0 + float(pop) / ARRIVE_SLOW_POP)
