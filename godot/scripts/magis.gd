class_name Magis
extends RefCounted
## Эдикты считают только игровые часы. Данные эффектов живут в Defs.

static func edict(id: String) -> Dictionary:
	for m: Dictionary in Defs.MAGIS:
		for e: Dictionary in m["edicts"]:
			if e["id"] == id:
				return e
	return {}


static func magistracy(id: String) -> Dictionary:
	for m: Dictionary in Defs.MAGIS:
		if m["id"] == id:
			return m
		for e: Dictionary in m["edicts"]:
			if e["id"] == id:
				return m
	return {}


static func seats(c: City) -> int:
	return 2 if c.level >= 5 else 1


static func is_open(c: City, id: String) -> bool:
	var m := magistracy(id)
	return not m.is_empty() and c.level >= int(m["rank"])


static func occupied(c: City, id: String) -> Array:
	var out := []
	var m := magistracy(id)
	for e: Dictionary in m.get("edicts", []):
		if c.magis_orders.has(e["id"]):
			out.append(e["id"])
	return out


static func active(c: City, id: String) -> bool:
	return c.magis_orders.has(id) and int(c.magis_orders[id].get("left", 0)) <= 0


static func mul(c: City, key: String) -> float:
	var value := 1.0
	var ids: Array = c.magis_orders.keys()
	ids.sort()  # Порядок принятия и загрузка не меняют округление.
	for id: String in ids:
		if active(c, id):
			value *= float(edict(id).get("fx", {}).get(key, 1.0))
	return value


static func add(c: City, key: String) -> float:
	var value := 0.0
	var ids: Array = c.magis_orders.keys()
	ids.sort()  # Порядок принятия и загрузка не меняют округление.
	for id: String in ids:
		if active(c, id):
			value += float(edict(id).get("fx", {}).get(key, 0.0))
	return value


static func can_adopt(c: City, id: String) -> String:
	var e := edict(id)
	if e.is_empty():
		return "Эдикт не найден"
	if not is_open(c, id):
		return I18n.t("Нужен уровень «%s»") % I18n.t(String(Defs.LEVELS[int(magistracy(id)["rank"])]["name"]))
	if c.magis_orders.has(id):
		return "Эдикт уже принят"
	if int(c.magis_cooldown.get(id, 0)) > 0:
		return I18n.t("Повторно через %d ч") % int(c.magis_cooldown[id])
	if occupied(c, id).size() >= seats(c):
		return "Все места заняты"
	if c.money < int(e["cost"]):
		return "Не хватает денариев"
	return ""


static func adopt(c: City, id: String) -> bool:
	if can_adopt(c, id) != "":
		return false
	var e := edict(id)
	c.money -= int(e["cost"])
	c.flow("other", -float(e["cost"]))
	c.magis_orders[id] = {"left": int(e["hours"]), "paid": int(e["cost"])}
	c.compute(true)
	c.changed.emit()
	return true


static func cancel(c: City, id: String) -> bool:
	if not c.magis_orders.has(id):
		return false
	var order: Dictionary = c.magis_orders[id]
	if int(order["left"]) > 0:
		# Возврат не теряется даже при полной казне.
		var refund := float(order["paid"])
		c.money += refund
		c.flow("other", refund)
	c.magis_orders.erase(id)
	c.magis_cooldown[id] = 24
	c.compute(true)
	c.changed.emit()
	return true


static func hour(c: City) -> void:
	for id: String in c.magis_cooldown.keys():
		c.magis_cooldown[id] = maxi(0, int(c.magis_cooldown[id]) - 1)
		if int(c.magis_cooldown[id]) == 0:
			c.magis_cooldown.erase(id)
	for id: String in c.magis_orders:
		var order: Dictionary = c.magis_orders[id]
		if int(order["left"]) > 0:
			order["left"] = int(order["left"]) - 1
			if int(order["left"]) == 0 and edict(id)["fx"].has("legion_gate"):
				c.magis_gate_on = true
	if c.magis_gate_on and c.legion.v3() and c.legion.window_open():
		c.magis_gate_h += 1.0
		var interval := c.legion.gate_interval()
		if c.magis_gate_h >= interval and c.magis_gate_queue.size() < 3:
			c.magis_gate_h -= interval
			c.magis_gate_serial += 1
			c.magis_gate_queue.append({"key": "gate:%d" % c.magis_gate_serial,
				"name": I18n.t("Доброволец %d") % c.magis_gate_serial,
				"gate": true, "stars": clampi(1 + c.level / 2, 1, 5), "former": I18n.t("Доброволец у ворот")})
		c.magis_gate_h = minf(c.magis_gate_h, interval)


static func load_state(c: City, d: Dictionary) -> void:
	c.magis_orders = {}
	c.magis_cooldown = {}
	c.magis_gate_on = false
	c.magis_gate_h = 0.0
	c.magis_gate_serial = 0
	c.magis_gate_queue = []
	c.magis_treasury = 0.0
	if int(d.get("magis_v", 0)) != 1:
		return
	var data: Dictionary = d.get("magis", {}) if d.get("magis", {}) is Dictionary else {}
	var orders: Dictionary = data.get("orders", {}) if data.get("orders", {}) is Dictionary else {}
	for m: Dictionary in Defs.MAGIS:
		var used := 0
		for e: Dictionary in m["edicts"]:
			var id := String(e["id"])
			if used >= seats(c) or not is_open(c, id) or not orders.get(id) is Dictionary:
				continue
			var order: Dictionary = orders[id]
			c.magis_orders[id] = {"left": clampi(int(order.get("left", 0)), 0, int(e["hours"])), "paid": int(e["cost"])}
			used += 1
	var cooldown: Dictionary = data.get("cooldown", {}) if data.get("cooldown", {}) is Dictionary else {}
	for id: String in cooldown:
		if not edict(id).is_empty() and not c.magis_orders.has(id):
			c.magis_cooldown[id] = clampi(int(cooldown[id]), 0, 24)
	c.magis_gate_on = bool(data.get("gate_on", false))
	c.magis_gate_h = clampf(float(data.get("gate_h", 0.0)), 0.0, 48.0)
	c.magis_gate_serial = maxi(0, int(data.get("gate_serial", 0)))
	if data.get("gate_queue", []) is Array:
		for pick in data.get("gate_queue", []):
			if pick is Dictionary and bool(pick.get("gate", false)) and pick.has("key") and pick.has("name"):
				c.magis_gate_queue.append(pick.duplicate(true))
				if c.magis_gate_queue.size() >= 3:
					break
	c.magis_treasury = maxf(0.0, float(data.get("treasury", 0.0)))


static func save_state(c: City) -> Dictionary:
	return {"orders": c.magis_orders.duplicate(true), "cooldown": c.magis_cooldown.duplicate(true),
		"gate_on": c.magis_gate_on, "gate_h": c.magis_gate_h, "gate_serial": c.magis_gate_serial,
		"gate_queue": c.magis_gate_queue.duplicate(true), "treasury": c.magis_treasury}


## Часть прежних налогов от торговли: без эдиктов общая сумма не меняется.
static func commerce(c: City, tax: float) -> Dictionary:
	var shop_weight := 0.0
	var store_weight := 0.0
	for b: Dictionary in c.buildings.values():
		if not bool(b.get("active", false)):
			continue
		var d := c.def(b)
		if d["kind"] == "shop":
			shop_weight += float(b.get("served", 0))
		elif d["kind"] == "store" and not c.goods.is_empty():
			store_weight += float(b.get("staff", 0.0))
	var shop_base := tax * minf(0.3, shop_weight / maxf(1.0, float(c.stats["pop"])) * 0.3)
	var export_base := tax * minf(0.1, store_weight * 0.05)
	return {"shop": shop_base * c.edict_mul("shop_income"), "export": c.warehouse_sale_price(export_base),
		"delta": shop_base * (c.edict_mul("shop_income") - 1.0) + export_base * (c.edict_mul("goods_price") - 1.0)}


static func tax_income(c: City, cls := "") -> float:
	var value := 0.0
	for h: Dictionary in c.buildings.values():
		if c.is_house(h) and (cls == "" or String(c.def(h)["cls"]) == cls):
			value += int(h["pop"]) * c.house_tax(h) * (0.5 + minf(100.0, float(h["happy"])) / 100.0)
	return value


static func missing_cost(c: City, needs: Array) -> int:
	var total := 0
	for n: String in needs:
		total += c.need_penalty(n)
	return total


static func pick_class(c: City, options: Array) -> String:
	# Нейтральный путь оставляет прежнее число вызовов RNG.
	var changed := false
	for cls: String in options:
		changed = changed or c.edict_mul("arrival_class:" + cls) != 1.0
	if not changed:
		return String(options[c.rng.randi() % options.size()])
	var total := 0.0
	for cls: String in options:
		total += c.edict_mul("arrival_class:" + cls)
	var roll := c.rng.randf() * total
	for cls: String in options:
		roll -= c.edict_mul("arrival_class:" + cls)
		if roll <= 0.0:
			return cls
	return String(options.back())
