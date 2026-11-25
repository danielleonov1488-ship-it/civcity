extends "res://scripts/promo28_cam.gd"
## Жизнь витринного города в рост человека.

const LIFE_VIEWS := {
	"life_porters": {"hour": [11.2, 11.3], "follow": "porters", "blur": 0.05,
		"keys": [[0, Vector3(0, 0.86, 0), -2, 10, 5.2], [8, Vector3(0, 0.90, 0), 3, 8, 4.9]]},
	"life_cat_wall": {"hour": [16.4, 16.5], "follow": "wall_cat", "blur": 0.08,
		"keys": [[0, Vector3(0, 0.26, 0), -19, 12, 3.3], [8, Vector3(0, 0.22, 0), 11, 13, 2.85]]},
	"life_market": {"hour": [10.5, 10.6], "follow": "market_worker", "blur": 0.06,
		"keys": [[0, Vector3(-0.55, 1.10, 0), -54, 10, 3.9], [8, Vector3(0.10, 1.14, 0), -45, 11, 3.45]]},
	"life_lamps": {"hour": [19.5, 21.5], "blur": 0.035,
		"keys": [[0, Vector3(192, 0.6, 143), -3, 6, 9.0], [8, Vector3(192, 0.6, 137.5), 1, 6, 8.0]]},
}

var porters: Array[Dictionary] = []
var wall_spot := Vector3.ZERO
var stall: Dictionary
var life_started := false


func _clip_config(name: String) -> Dictionary:
	if not LIFE_VIEWS.has(name):
		return super._clip_config(name)
	var cfg: Dictionary = LIFE_VIEWS[name].duplicate()
	cfg["dur"] = 8.0
	cfg["life"] = float(cfg["hour"][0])
	cfg["warm"] = 4.0
	cfg["v"] = {"fov": 31.0}
	cfg["ease"] = "inout"
	return cfg


func _setup(full: bool) -> void:
	super._setup(full)
	match follow:
		"porters":
			_prepare_porters()
		"wall_cat":
			_prepare_cat()
		"market_worker":
			_prepare_stall()


func _nearest_building(type: String, p: Vector2) -> Dictionary:
	var nearest := INF
	var result: Dictionary = {}
	for b: Dictionary in city.buildings.values():
		if b["type"] != type:
			continue
		var d := p.distance_squared_to(b["pos"])
		if d < nearest:
			nearest = d
			result = b
	return result


func _prepare_porters() -> void:
	var people: People = game.people
	var candidates: Array = people.residents.filter(func(r: Dictionary) -> bool: return not r["child"])
	var p := Vector2(191.45, 143.0)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return p.distance_squared_to(a["p"]) < p.distance_squared_to(b["p"]))
	if candidates.size() < 2:
		_fail("нет жителей для прохода по улице")
		return
	for i in 2:
		var r: Dictionary = candidates[i]
		people._leave_slot(r)
		people._release(r)
		r["p"] = p + Vector2(1.2 * i, -0.9 * i)
		r["state"] = "idle"
		r["yaw"] = 0.0
		r["yoff"] = 0.0
		r["yoff_to"] = 0.0
		r["act"] = "stand"
		r["at"] = 100.0
		r["carry"] = "basket" if i == 0 else "amphora"
		people._seq(r, [["Idle", 100.0]])
		people._place(r)
		porters.append(r)


func _prepare_cat() -> void:
	var wall := _nearest_building("fence_3", Vector2(195, 207))
	if wall.is_empty() or game.people.cats.is_empty():
		_fail("нет кошки или стенки")
		return
	cat = game.people.cats[0]
	for c: Dictionary in game.people.cats:
		if c.get("fur") == Color("e0913f"):
			cat = c
			break
	var p: Vector2 = wall["pos"] + City.facing(wall["yaw"]) * 0.12
	cat["p"] = p
	cat["path"] = PackedVector2Array()
	cat["state"] = "sit"
	cat["t"] = 999.0
	cat["pet"] = 0
	anchor_yaw = rad_to_deg(float(wall["yaw"]))
	cat["yaw"] = float(wall["yaw"]) + PI / 2.0
	wall_spot = Vector3(p.x, float(wall["y"]) + 0.79, p.y)


func _prepare_stall() -> void:
	stall = _nearest_building("stall_fruit", Vector2(198, 174))
	if stall.is_empty():
		_fail("нет фруктовой лавки на рынке")
		return
	anchor_yaw = rad_to_deg(float(stall["yaw"]))
	var front := City.facing(stall["yaw"]) * 0.72
	var p: Vector2 = stall["pos"] + front
	anchor_pos = Vector3(p.x, float(stall["y"]), p.y)


func _events(t: float) -> void:
	if follow == "porters" and not life_started:
		life_started = true
		for i in porters.size():
			game.people._go(porters[i], Vector2(191.45 + 1.2 * i, 165.0), "deliver")
	super._events(t)


func _anchor() -> void:
	match follow:
		"porters":
			anchor_pos = (game.people.person_pos(porters[0]) + game.people.person_pos(porters[1])) * 0.5
		"wall_cat":
			var actor: Node3D = cat["n"]
			actor.global_position = wall_spot
			anchor_pos = wall_spot
		"market_worker":
			pass
		_:
			super._anchor()
