class_name FamilyWant
extends RefCounted
## Одно желание на семью; невыполненное ничего не отнимает.

const ORDER := ["trees", "water", "flowers", "quiet", "market", "temple", "plaza"]
const LOOK := {
	"trees": ["tree", "деревья"], "water": ["water", "вода"],
	"flowers": ["flower", "цветы"], "quiet": ["sleep", "тишина"],
	"market": ["commerce", "рынок"], "temple": ["faith", "храм"],
	"plaza": ["road", "площадь"],
}
const HELP := {
	"trees": "Деревья или роща в 12 м от дома",
	"water": "Фонтан, пруд или вода в 15 м от дома",
	"flowers": "Клумба или вазон в 10 м от дома",
	"quiet": "Не больше 2 соседних домов в 10 м",
	"market": "Лавка еды в 15 м от дома",
	"temple": "Храм или алтарь в 25 м от дома",
	"plaza": "Мощёная площадь в 10 м от дома",
}
const BONUS := 5
const TREES := ["tree", "cypress", "palm", "bigtree", "grove", "nat_tree"]
const FLOWERS := ["flowers", "planter", "wall_flowers", "rosearch", "parterre", "trellis", "nat_flowers"]
const WATER := ["fountain", "smallfountain", "nymphfountain", "garden_pool", "pond", "spring", "birdbath"]


## Редкое желание появляется только с Хутора. Пустая строка тоже сохраняется.
static func roll(rng: RandomNumberGenerator, rank: int) -> String:
	if rank < 1 or rng.randi_range(0, 3) != 0:
		return ""
	return random_id(rng)


const ADVICE := {
	"trees": "Семья хочет жить у деревьев.", "water": "Семья хочет жить у воды.",
	"flowers": "Семья хочет жить у цветов.", "quiet": "Семья хочет жить на тихой улице.",
	"market": "Семья хочет жить у рынка.", "temple": "Семья хочет жить у храма.",
	"plaza": "Семья хочет жить у площади.",
}


static func advice(id: String) -> String:
	return String(ADVICE.get(id, "")) + "\nПоселите её там — будет счастливее.\nЗначок желания — над семьёй и слева вверху."


static func random_id(rng: RandomNumberGenerator) -> String:
	return String(ORDER[rng.randi_range(0, ORDER.size() - 1)])


static func matches(city: City, h: Dictionary, id: String, nearby: Array = []) -> bool:
	if h.is_empty() or id not in ORDER:
		return false
	var pos: Vector2 = h["pos"]
	var neighbours := 0
	var list: Array = city.buildings.values() if nearby.is_empty() else nearby
	for b: Dictionary in list:
		var distance := pos.distance_to(b["pos"])
		var d: Dictionary = city.def(b)
		var base := Defs.base_of(String(b["type"]))
		match id:
			"trees":
				if distance <= 12.0 and (base in TREES or d.get("sub", "") == "trees"):
					return true
			"water":
				if distance <= 15.0 and (base in WATER or d.get("sub", "") == "water"):
					return true
			"flowers":
				if distance <= 10.0 and base in FLOWERS:
					return true
			"quiet":
				if distance <= 10.0 and d["kind"] == "house" and b["id"] != h["id"]:
					neighbours += 1
			"market":
				if distance <= 15.0 and d["kind"] == "shop" and HouseNeeds.category(d) == "food" and bool(b.get("active", false)):
					return true
			"temple":
				if distance <= 25.0 and HouseNeeds.category(d) == "faith":
					return true
	if id == "quiet":
		return neighbours <= 2
	if id == "trees" or id == "flowers":
		return city.want_nature.is_valid() and bool(city.want_nature.call(pos, 12.0 if id == "trees" else 10.0, id))
	if id == "water" or id == "plaza":
		return _terrain(city, h, id)
	return false


## Кэш только земли: рабочая лавка и природные деревья проверяются заново.
static func _terrain(city: City, h: Dictionary, id: String) -> bool:
	var pos: Vector2 = h["pos"]
	var land := city.land
	if int(h.get("_want_land", 0)) != land.get_instance_id() or int(h.get("_want_gen", -1)) != land.gen or h.get("_want_pos", Vector2.INF) != pos:
		h["_want_land"] = land.get_instance_id()
		h["_want_gen"] = land.gen
		h["_want_pos"] = pos
		h["_want_terrain"] = {}
	var cache: Dictionary = h["_want_terrain"]
	if cache.has(id):
		return bool(cache[id])
	var radius := 15.0 if id == "water" else 10.0
	# Площадь ищем по всем клеткам: даже маленький мазок считается.
	var step := Land.CELL
	for j in range(floori((pos.y - radius) / step), ceili((pos.y + radius) / step) + 1):
		var z := (float(j) + 0.5) * step
		var dy := z - pos.y
		if absf(dy) > radius:
			continue
		var dx := sqrt(radius * radius - dy * dy)
		if j < 0 or j >= Land.N:
			continue
		var lo := clampi(ceili((pos.x - dx) / Land.CELL - 0.5), 0, Land.N - 1)
		var hi := clampi(floori((pos.x + dx) / Land.CELL - 0.5), 0, Land.N - 1)
		if hi < lo:
			continue
		var start := land.idx(lo, j)
		var end := land.idx(hi, j) + 1
		var found := false
		if id == "plaza":
			found = land.kind.slice(start, end).has(Land.Kind.PLAZA)
		else:
			var lowest := INF
			for hv in land.h.slice(start, end):
				lowest = minf(lowest, float(hv))
			found = roundf(lowest / Land.STEP) * Land.STEP < Land.WATER_Y + 0.05
		if found:
			cache[id] = true
			return true
	cache[id] = false
	return false


static func parts(city: City, h: Dictionary, f: Dictionary, nearby: Array = []) -> Array:
	var id := String(f.get("want", ""))
	if not matches(city, h, id, nearby):
		return []
	return [["Желание семьи %s: %s" % [f["name"], LOOK[id][1]], BONUS]]
