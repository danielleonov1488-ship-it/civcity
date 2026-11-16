extends Node
## Регрессии JSON и миграции; Godot запускает только владелец проверки.

const Fixture = preload("res://scripts/test_fort_fixture.gd")
var fails := 0


func check(ok: bool, reason: String) -> void:
	print(("FORT5A2 PASS " if ok else "FORT5A2 FAIL ") + reason)
	if not ok:
		fails += 1


func town() -> City:
	var c := City.new(Land.new())
	c.cozy_v = 1
	c.legion_v = 3
	c.hero = {}
	c.legion.flags["camp_open"] = true
	c.legion.army_tick()
	return c


func json_copy(lg: Legion) -> Dictionary:
	return JSON.parse_string(JSON.stringify(lg.to_dict()))


func _ready() -> void:
	var saved_clock := Legion.clock
	Legion.clock = 3000000.0
	_round_trip()
	_migration()
	Legion.clock = saved_clock
	print("FORT5A2 DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _round_trip() -> void:
	var c := town()
	var lg: Legion = c.legion
	Fixture.set_level(lg, "hq", 3)
	Fixture.set_level(lg, "kitchen", 1)
	Fixture.set_level(lg, "forge", 2)
	Fixture.gate(lg)
	var person := lg.recruit_resident()
	var sid := int(person["id"])
	var kitchen := int(lg.fort_slot_plot("kitchen")["id"])
	check(lg.fort_assign(kitchen, sid), "fixture assignment")
	person["battles"] = 7
	person["falls"] = 2
	person["train_plot"] = int(lg.fort_slot_plot("drill")["id"])
	var equipped := lg.add_item(Gear.craft_item("bow", 2, 1))
	check(lg.equip(sid, int(equipped["id"])), "fixture equipment")
	var pending := lg.fort_newcomers()
	var next_id := lg.sid_next
	var copy := town()
	copy.legion.from_dict(json_copy(lg))
	var restored := copy.legion.soldier(sid)
	check(copy.legion.fort_newcomers() == pending, "queue keeps every field and order")
	check(restored == person and restored["cls"] == "archer", "resident keeps identity, class, gear and counters")
	check(copy.legion.fort_worker_plot(sid) == kitchen and copy.legion.fort_population() == lg.fort_population(), "assignment and population preserved")
	check(typeof(restored["look_seed"]) == TYPE_INT and typeof(restored["train_plot"]) == TYPE_INT
		and typeof(restored["battles"]) == TYPE_INT and typeof(restored["falls"]) == TYPE_INT, "resident numbers are integers")
	for newcomer: Dictionary in copy.legion.fort_newcomers():
		check(typeof(newcomer["id"]) == TYPE_INT and typeof(newcomer["stars"]) == TYPE_INT
			and typeof(newcomer["look_seed"]) == TYPE_INT, "gate numbers are integers")
	check(copy.legion.fort == lg.fort and not copy.legion.fort_slot_plot("forge").has("craft"), "loading does not add an unused craft queue")
	var once: Dictionary = copy.legion.to_dict().duplicate(true)
	copy.legion.from_dict(json_copy(copy.legion))
	check(copy.legion.fort == once["fort"] and copy.legion.soldiers == once["soldiers"]
		and copy.legion.sid_next == next_id, "second load keeps population and IDs")
	var future := copy.legion._fort_newcomer()
	check(int(future["id"]) == next_id and copy.legion.soldier(int(future["id"])).is_empty()
		and not pending.any(func(p: Dictionary): return int(p["id"]) == int(future["id"])), "future arrival does not reuse a saved ID")
	# workers — основной список, worker — только совместимый первый ID.
	var missing_alias := json_copy(lg)
	for plot: Dictionary in missing_alias["fort"]["plots"]:
		plot.erase("worker")
	copy.legion.from_dict(missing_alias)
	check(copy.legion.fort_worker_plot(sid) == kitchen and copy.legion.fort_population() == lg.fort_population(), "workers survive without scalar alias")
	var modern_empty := json_copy(lg)
	for plot: Dictionary in modern_empty["fort"]["plots"]:
		if int(plot["id"]) == kitchen:
			plot.erase("worker")
			plot.erase("workers")
	copy.legion.from_dict(modern_empty)
	check(copy.legion.fort_occupants(kitchen).is_empty() and copy.legion.fort_population() == lg.fort_population(), "modern missing assignment does not create a person")


func _migration() -> void:
	var c := town()
	var lg: Legion = c.legion
	var old := json_copy(lg)
	old.erase("fort")
	old["camp"] = {"hq": 3, "barracks": 2, "forge": 1, "drill": 1, "store": 1, "mars": 0}
	lg.from_dict(old)
	var kitchen := int(lg.fort_slot_plot("kitchen")["id"])
	check(not lg.fort_worker(kitchen).is_empty(), "old camp gets a kitchen worker")
	var workers: Array = lg.soldiers.duplicate(true)
	var before: Dictionary = lg.fort.duplicate(true)
	var next_id := lg.sid_next
	var rng_state := str(lg._rng.state)
	lg.from_dict(json_copy(lg))
	lg._fort_migrate_workers()
	check(lg.soldiers == workers and lg.fort == before and lg.sid_next == next_id
		and str(lg._rng.state) == rng_state, "legacy migration runs once, including direct retry")
	check(lg.fort_assign(kitchen, 0), "clear migrated kitchen")
	lg.from_dict(json_copy(lg))
	check(lg.fort_worker(kitchen).is_empty() and lg.soldiers == workers, "cleared legacy room stays empty")
