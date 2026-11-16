extends RefCounted
## Новые семьи показывают одно желание; черты сохранены для прежних семей.

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


static func look(f: Dictionary) -> Array:
	return FamilyWant.LOOK.get(String(f["want"]), ["housing", "свободный дом"]) if f.has("want") else LOOK.get(main(f), ["housing", "свободный дом"])


static func main(f: Dictionary) -> String:
	if f.has("want"):
		return String(f["want"])
	var traits: Array = Balance.traits_of(String(f.get("name", "")))
	for t: String in traits:
		if Balance.TRAITS[t].has("ok"):
			return t
	return String(traits[0]) if not traits.is_empty() else ""


static func effects(city: City, h: Dictionary, f: Dictionary) -> Array:
	if city.cozy_v < 1 or h.is_empty() or f.is_empty():
		return []
	if f.has("want"):
		return FamilyWant.parts(city, h, f)
	var tr_id := main(f)
	if tr_id == "":
		return []
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
	return city.trait_parts(probe, crowd, near, (h.get("score", {}) as Dictionary).size(), h.get("mon_types", {}))


static func matches(city: City, h: Dictionary, f: Dictionary) -> bool:
	if f.has("want"):
		return FamilyWant.matches(city, h, String(f["want"]))
	var tr_id := main(f)
	if tr_id == "" or city.cozy_v < 1 or h.is_empty() or f.is_empty():
		return false
	var positive: String = Balance.TRAITS[tr_id].get("ok", "")
	for part: Array in effects(city, h, f):
		if part[0] == positive and int(part[1]) > 0:
			return true
	if tr_id == "allergy":
		return not effects(city, h, f).any(func(e: Array) -> bool: return e[0] == Balance.TRAITS["allergy"]["bad"])
	return false


static func tooltip(city: City, h: Dictionary, f: Dictionary) -> String:
	if f.has("want"):
		var id := String(f["want"])
		return "Хотят: %s\n%s\n%s" % [look(f)[1], FamilyWant.HELP.get(id, ""), "Выполнено: +5% к счастью дома" if matches(city, h, f) else "Пока не выполнено: без штрафа"]
	var lines := []
	var parts := effects(city, h, f)
	for tr_id: String in Balance.traits_of(String(f.get("name", ""))):
		var d: Dictionary = Balance.TRAITS[tr_id]
		var pref: Array = LOOK.get(tr_id, ["housing", "свободный дом"])
		lines.append("Хотят: %s" % String(pref[1]))
		if d.has("ok"):
			lines.append("%s: +%d%%" % [d["ok"], Balance.TRAIT_OK])
		if d.has("bad"):
			lines.append("%s: %d%%" % [d["bad"], Balance.TRAIT_BAD])
		var value := 0
		for part: Array in parts:
			if part[0] == d.get("ok", "") or part[0] == d.get("bad", ""):
				value = int(part[1])
		lines.append("Сейчас: %+d%% к счастью дома" % value)
	lines.append("Одинаковая черта учитывается один раз на дом")
	return "\n".join(lines)
