extends RefCounted
## Черты уже участвуют в счастье. Все положительные черты дают одинаковые +3%.

const LOOK := {
	"crowd": ["family", "много соседей"],
	"quiet": ["sleep", "тихую улицу"],
	"flowers": ["flower", "цветы рядом"],
	"dark": ["candle", "свет рядом"],
	"pious": ["laurels", "храм рядом"],
	"bather": ["bath", "ходить в термы"],
	"theatre": ["fun", "ходить на зрелища"],
	"cat": ["cat", "кошку рядом"],
	"green": ["tree", "рядом зелень"],
	"market": ["commerce", "разные лавки рядом"],
	"allergy": ["housing", "жить без животных"],
}


static func main(f: Dictionary) -> String:
	var traits: Array = Balance.traits_of(String(f.get("name", "")))
	for t: String in traits:
		if Balance.TRAITS[t].has("ok"):
			return t
	return String(traits[0]) if not traits.is_empty() else ""


static func matches(city: City, h: Dictionary, f: Dictionary) -> bool:
	if city.cozy_v < 1 or h.is_empty() or f.is_empty():
		return false
	var tr_id := main(f)
	if tr_id == "":
		return false
	var near: Array = []
	var crowd := 0
	var pos: Vector2 = h["pos"]
	# Проверка только при обновлении ключей; никаких обходов города в кадре.
	for other: Dictionary in city.buildings.values():
		var distance := pos.distance_to(other["pos"])
		var kind: String = city.def(other)["kind"]
		if kind == "house" and other["id"] != h["id"] and distance <= Defs.DENSITY_RADIUS:
			crowd += 1
		if kind == "decor" and distance <= Defs.DECOR_RADIUS:
			near.append([Defs.base_of(other["type"]), 1.0])
	var probe := h.duplicate()
	probe["families"] = [f]
	var parts := city.trait_parts(probe, crowd, near, (h.get("score", {}) as Dictionary).size(), h.get("mon_types", {}))
	var positive: String = Balance.TRAITS[tr_id].get("ok", "")
	for part: Array in parts:
		if part[0] == positive and int(part[1]) > 0:
			return true
	if tr_id == "allergy":
		return not near.any(func(e: Array) -> bool: return e[0] in Balance.T_PETS)
	return false
