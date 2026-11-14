class_name SizeLadder
extends RefCounted
## Линейка размеров построек (владелец 13.11: пробные храм, амфитеатр и цирк вышли слишком маленькими рядом
## с библиотекой и одеоном — размеры решаем для всех зданий сразу). Мерка — дом плебеев, 2,8 × 4 м ≈ 11 м².
## Ступени: малые 1–2 дома, средние 3–4, большие 5–7, главные 8–10, чудеса города 10–14.
## apply() подгоняет прежние сборки под будущую площадь следа — только для снимков на утверждение;
## новые здания потом собираются сразу в этом размере.

const HOUSE := 11.2

## Будущая площадь следа, м² (кого нет в списке — размер прежний)
const TARGET := {
	# малые, 1–2 дома (NewSmall: пост вигилов и скрипторий — по ≈ 16 м²)
	"vigiles": 16.0, "scriptorium": 16.0,
	# средние, 3–4 дома
	"prefect": 36.0, "mansio": 36.0, "warehouse": 36.0, "balnea": 36.0, "school": 38.0,
	# большие, 5–7 домов (лудус — NewShops2, ≈ 51 м², было 39)
	"library": 62.0, "center": 62.0, "baths": 68.0, "ludus": 51.0,
	# главные, 8–10 домов
	"temple": 90.0, "pantheon": 100.0, "thermae": 112.0,
	# чудеса города, 10–14 домов
	"colosseum": 125.0, "circus_fl": 150.0,
}

## Ревизия линейки: новая постройка запоминает её (b["sz"]). Тип, пересобранный в новом размере, записывается в SINCE
## с ревизией, с которой он новый; постройка с меньшей ревизией (или без неё — старое сохранение) стоит на прежних
## клетках, и её облик собирается под прежний след (OLD_LOT, Catalog.fit).
const REV := 1
## тип → ревизия, с которой он в новом размере (заполняется, когда новая сборка типа готова):
## храм Юпитера (NewTemple, 90 м²), амфитеатр и цирк (NewArena, чудеса города, 125 и 150 м²),
## театр, одеон, библиотека, большие термы (NewCivic), пантеон (NewGrand, 100 м², растёт, где есть место) — с ревизии 1;
## в старых городах — на прежних клетках. Академия, форум, храм Венеры (NewGrand) — в прежних следах (OLD_LOT не нужен).
## Почтовая станция, бани, гостиница, дом префекта (NewCivic2) — с ревизии 1: гостиница и дом префекта (36 м², было 27
## и 28) в старых городах — под прежние клетки и растут, где есть место; бани (68 м², было 73) — посреди прежнего следа;
## станция (62 м²) — внутри прежнего следа на вырост (OLD_LOT не нужен)
## пост вигилов, малые бани, склад, скрипторий (NewSmall) — с ревизии 1, растут, где есть место; школа (NewSmall) —
## в прежнем следе
## прилавки, уличные зрелища, огород, приют, кошачья лавка, травник, скульптор (NewShops2) — с ревизии 1, в прежних следах
## (OLD_LOT не нужен); лудус (NewShops2, 51 м², было 39) — с ревизии 1: в старых городах — под прежние клетки, растёт,
## где есть место
const SINCE := {"temple": 1, "colosseum": 1, "circus_fl": 1, "theatre": 1, "odeon": 1, "library": 1, "thermae": 1,
	"pantheon": 1, "academy": 1, "forum": 1, "venus": 1, "center": 1, "baths": 1, "mansio": 1, "prefect": 1,
	"vigiles": 1, "school": 1, "balnea": 1, "warehouse": 1, "scriptorium": 1,
	"stall_fruit": 1, "stall_veg": 1, "stall_fish": 1, "musicians": 1, "dice": 1, "mimes": 1, "puppets": 1, "ogorod": 1, "shelter": 1,
	"catshop": 1, "herbalist": 1, "sculptor": 1, "ludus": 1}

## Прежний след (м, ширина × глубина при yaw 0) — проба размеров 12.11, до линейки
const OLD_LOT := {
	"temple": Vector2(6.3, 7.6), "colosseum": Vector2(15.2, 15.7), "circus_fl": Vector2(28.6, 8.9), "thermae": Vector2(14.6, 10.5),
	"library": Vector2(8.3, 5.9), "pantheon": Vector2(7.2, 9.9), "prefect": Vector2(5.6, 5.1), "mansio": Vector2(4.9, 5.6),
	"warehouse": Vector2(6.8, 4.5), "balnea": Vector2(6.7, 4.6), "theatre": Vector2(10.3, 7.65), "odeon": Vector2(9.3, 7.15),
	"baths": Vector2(10.14, 7.16),
	"vigiles": Vector2(5.3, 2.3), "scriptorium": Vector2(3.8, 3.6),
	"ludus": Vector2(7.9, 5.0),
}

## Ступень каждого типа — для подписей на снимках
const TIER := {
	"house_pleb": "мерка", "vigiles": "малые", "prefect": "средние", "mansio": "средние", "school": "средние",
	"warehouse": "средние", "balnea": "средние", "library": "большие", "center": "большие", "odeon": "большие",
	"forum": "большие", "theatre": "большие", "baths": "большие", "venus": "большие", "temple": "главные",
	"academy": "главные", "pantheon": "главные", "thermae": "главные", "colosseum": "чудеса", "circus_fl": "чудеса",
	"stall_fruit": "малые", "stall_veg": "малые", "stall_fish": "малые", "musicians": "малые", "dice": "малые", "puppets": "малые",
	"mimes": "малые", "ogorod": "малые", "herbalist": "малые", "catshop": "малые", "shelter": "малые", "sculptor": "малые",
	"ludus": "большие",
}


## Постройка стоит на прежнем следе: её тип пересобран позже, чем она построена (или она из старого сохранения)
static func old_lot(b: Dictionary) -> bool:
	var t := String(b.get("type", ""))
	return SINCE.has(t) and int(b.get("sz", 0)) < int(SINCE[t])


## Тип по линейке стал больше прежнего следа (храм): постройку старого сохранения стоит пробовать вырастить на месте
## (City.ladder_grow); те, что стали меньше (амфитеатр, цирк, большие термы), не растут
static func grows(t: String) -> bool:
	if not TARGET.has(t) or not OLD_LOT.has(t):
		return false
	var o: Vector2 = OLD_LOT[t]
	return float(TARGET[t]) > o.x * o.y


## Площадь следа постройки сейчас (м²): прямоугольник вокруг её деталей, как у пробы размеров
static func area(type: String) -> float:
	var b := Catalog.make(type, 1, 0, 0)
	var lot := Rect2()
	var first := true
	for r: Rect2 in b.footprint():
		lot = r if first else lot.merge(r)
		first = false
	return lot.size.x * lot.size.y


## Подогнать прежние сборки под TARGET: множитель масштаба = √(будущая площадь / нынешняя)
static func apply() -> void:
	Catalog.LADDER = {}
	Catalog._cache.clear()
	var f := {}
	for t: String in TARGET:
		if SINCE.has(t):
			print("LADDER %-10s уже в новом размере (SINCE)" % t)
			continue                          # пересобран в новом размере — не подгонять
		var a := area(t)
		if a > 0.1:
			f[t] = sqrt(float(TARGET[t]) / a)
			print("LADDER %-10s %5.0f м² → %5.0f м²  ×%.2f" % [t, a, float(TARGET[t]), float(f[t])])
	Catalog.LADDER = f
	Catalog._cache.clear()
