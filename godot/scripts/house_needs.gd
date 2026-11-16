class_name HouseNeeds
extends RefCounted
## Покрытие — лучший работающий источник; счастье остаётся по правилам BAL1.


static func category(d: Dictionary) -> String:
	return String(d.get("need", d.get("sub", "") if d.get("kind", "") == "shop" else ""))


static func state(coverage: int) -> String:
	return "red" if coverage < 34 else ("yellow" if coverage < 67 else "green")


static func percent(value: Variant) -> int:
	var number := float(value)
	return roundi(clampf(number, 0.0, 100.0)) if is_finite(number) else 0


static func reset(h: Dictionary) -> void:
	h["need_coverage"] = {}
	h["need_states"] = {}
	h["need_sources"] = {}
	for n: String in Defs.NEED_ORDER:
		h["need_coverage"][n] = 0
		h["need_states"][n] = "red"
		h["need_sources"][n] = []


static func add(h: Dictionary, b: Dictionary, d: Dictionary, bonus: int) -> void:
	var n := category(d)
	if n not in Defs.NEED_ORDER:
		return
	var pct := percent(float(b.get("staff", 1.0)) * 100.0)
	if pct <= 0:
		return
	h["needs"][n] = true
	h["need_coverage"][n] = maxi(int(h["need_coverage"][n]), pct)
	h["need_states"][n] = state(int(h["need_coverage"][n]))
	var sources: Array = h["need_sources"][n]
	var source := {"id": int(b["id"]), "type": String(b["type"]), "coverage": pct, "bonus": bonus}
	# Одинаковый вид радует один раз, как score и mon_types.
	for i in sources.size():
		if sources[i]["type"] == b["type"]:
			if int(sources[i]["coverage"]) < pct:
				sources[i] = source
			return
	sources.append(source)


static func finish(h: Dictionary, econ: int) -> void:
	for n: String in Defs.NEED_ORDER:
		var sources: Array = h["need_sources"][n]
		sources.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(Defs.B[a["type"]].get("bonus", 0)) > int(Defs.B[b["type"]].get("bonus", 0)))
		if econ < 1 or n == "faith":
			continue
		for i in sources.size():
			sources[i]["bonus"] = roundi(int(sources[i]["bonus"]) * float(Defs.SHOP_REPEAT[mini(i, Defs.SHOP_REPEAT.size() - 1)]))


static func averages(houses: Array, rank: int) -> Dictionary:
	var out := {}
	for n: String in Defs.NEED_ORDER:
		var sum := 0.0
		var weight := 0
		var empty_sum := 0
		var count := 0
		for h: Dictionary in houses:
			if n not in Defs.needs_for(String(Defs.B[h["type"]]["cls"]), rank):
				continue
			var pct := percent(h["need_coverage"][n])
			var pop := int(h["pop"])
			sum += pct * pop
			weight += pop
			empty_sum += pct
			count += 1
		var pct := roundi(sum / weight) if weight > 0 else (roundi(float(empty_sum) / count) if count > 0 else 0)
		out[n] = {"coverage": pct, "state": state(pct), "houses": count, "residents": weight}
	return out
