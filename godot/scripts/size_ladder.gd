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
	# средние, 3–4 дома
	"prefect": 36.0, "mansio": 36.0, "warehouse": 36.0, "balnea": 36.0,
	# большие, 5–7 домов
	"library": 62.0,
	# главные, 8–10 домов
	"temple": 90.0, "pantheon": 100.0, "thermae": 112.0,
	# чудеса города, 10–14 домов
	"colosseum": 125.0, "circus_fl": 150.0,
}

## Ступень каждого типа — для подписей на снимках
const TIER := {
	"house_pleb": "мерка", "vigiles": "малые", "prefect": "средние", "mansio": "средние", "school": "средние",
	"warehouse": "средние", "balnea": "средние", "library": "большие", "center": "большие", "odeon": "большие",
	"forum": "большие", "theatre": "большие", "baths": "большие", "venus": "большие", "temple": "главные",
	"academy": "главные", "pantheon": "главные", "thermae": "главные", "colosseum": "чудеса", "circus_fl": "чудеса",
}


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
		var a := area(t)
		if a > 0.1:
			f[t] = sqrt(float(TARGET[t]) / a)
			print("LADDER %-10s %5.0f м² → %5.0f м²  ×%.2f" % [t, a, float(TARGET[t]), float(f[t])])
	Catalog.LADDER = f
	Catalog._cache.clear()
