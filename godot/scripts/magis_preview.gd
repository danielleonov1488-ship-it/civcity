class_name MagisPreview
extends RefCounted
## Проекция чисел без изменения города и его RNG.

const LABELS := {"shop_income": "Доход лавок", "build_cost": "Дом плебеев", "upkeep": "Содержание", "rp_rate": "Исследования", "arrivals": "Повозка каждые", "work_output": "Выработка", "goods_price": "Продажи склада", "tourists": "Гостей в сутки", "festival_happy": "Счастье праздника", "legion_gate": "Новобранец каждые", "legion_rations": "Пайки на поход", "legion_denarii": "В казну Легиона"}
const CLASS_TAX := {"plebs": "Налог плебеев", "artisans": "Налог ремесленников", "patricians": "Налог патрициев"}
const CLASS_HAPPY := {"all": "Счастье города", "plebs": "Счастье плебеев", "artisans": "Счастье ремесленников", "patricians": "Счастье патрициев"}


static func metric(c: City, key: String) -> Dictionary:
	var value := 0.0
	var title := String(LABELS.get(key, key))
	var unit := ""
	var reverse := false
	if key.begins_with("tax_k:"):
		var cls := key.get_slice(":", 1)
		title = CLASS_TAX[cls]
		value = Magis.tax_income(c, cls)
		unit = " / ч"
	elif key.begins_with("happy:"):
		var cls := key.get_slice(":", 1)
		title = CLASS_HAPPY[cls]
		value = float(c.stats["happy"]) if cls == "all" else float(c.stats["class_happy"].get(cls, 0))
	elif key.begins_with("need_radius:"):
		var need := key.get_slice(":", 1)
		title = I18n.t("Дальность: %s") % I18n.t(String(Defs.NEEDS[need]["name"]))
		for b: Dictionary in c.buildings.values():
			var d := c.def(b)
			if HouseNeeds.category(d) == need:
				value = maxf(value, c.shop_range(d) if d["kind"] == "shop" else c.need_range(d))
		unit = " м"
	elif key.begins_with("need_weight:"):
		title = "Штраф за нехватку еды"
		value = c.need_penalty(key.get_slice(":", 1))
	elif key.begins_with("arrival_class:"):
		title = "Доля семей ремесленников"
		var fit := c.fit_by_class()
		var options := []
		for cls: String in fit:
			if int(fit[cls]) > 0:
				options.append(cls)
		if options.is_empty():
			options = fit.keys()
		var total := 0.0
		for cls: String in options:
			total += c.edict_mul("arrival_class:" + cls)
		value = 100.0 * c.edict_mul(key) / total if key.get_slice(":", 1) in options and total > 0.0 else 0.0
		unit = "%"
	else:
		match key:
			"shop_income", "goods_price":
				var commerce := Magis.commerce(c, Magis.tax_income(c))
				value = float(commerce["shop" if key == "shop_income" else "export"])
				unit = " / ч"
			"build_cost": value = c.build_price("house_pleb")
			"upkeep":
				for b: Dictionary in c.buildings.values():
					var d := c.def(b)
					if d["kind"] in ["house", "shop", "monument", "store", "farm", "military", "inn", "rp"] and not b.get("over", false):
						value += float(d["cost"]) * c.upkeep_rate() * (0.5 if d["kind"] == "house" and c.cozy_v >= 1 else (0.0 if d["kind"] == "house" else 1.0))
				unit = " / ч"
			"rp_rate":
				for rate in c.rp_sources().values():
					value += float(rate)
				unit = " / ч"
			"arrivals":
				value = c.arrive_every()
				unit = " ч"
				reverse = true
			"work_output":
				for b: Dictionary in c.buildings.values():
					if bool(b.get("active", false)) and not c.is_house(b) and c.def(b).has("jobs"):
						value += float(b.get("staff", 0.0)) * c.edict_mul(key)
			"tourists":
				for b: Dictionary in c.buildings.values():
					if b["type"] == "mansio":
						value += float(Tourism.inn_info(c, b)["guests"])
			"festival_happy": value = float(Defs.FESTIVAL["happy"]) * c.edict_mul(key)
			"legion_gate":
				value = c.legion.gate_interval()
				unit = " ч"
				reverse = true
			"legion_rations": value = c.legion.ration_cost({})
			"legion_denarii":
				value = (Magis.tax_income(c) + Tourism.hour_income(c)) * c.edict_add(key)
				unit = " / ч"
	return {"label": I18n.t(title), "value": value, "unit": I18n.t(unit), "reverse": reverse}


static func rows(c: City, id: String) -> Array:
	var out := []
	var e := Magis.edict(id)
	var removing := Magis.active(c, id)
	for key: String in e["fx"]:
		var m := metric(c, key)
		var before := float(m["value"])
		var effect := float(e["fx"][key])
		var after := before
		if key.begins_with("happy:"):
			after = clampf(before + (-effect if removing else effect), 0.0, 100.0)
		elif key == "legion_denarii":
			after += (Magis.tax_income(c) + Tourism.hour_income(c)) * (-effect if removing else effect)
		elif key.begins_with("arrival_class:"):
			var proportion := before / 100.0
			var factor := 1.0 / effect if removing else effect
			after = 100.0 * proportion * factor / maxf(0.001, 1.0 + proportion * (factor - 1.0))
		else:
			var factor := 1.0 / effect if removing else effect
			after = before / factor if bool(m["reverse"]) else before * factor
			if key.begins_with("need_weight:") or key == "festival_happy":
				after = roundf(after)
		out.append({"key": key, "label": m["label"], "before": before, "after": after, "unit": m["unit"]})
	return out
