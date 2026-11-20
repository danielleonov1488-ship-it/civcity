extends RefCounted
## Только фикстура тестов: заданный уровень без оплаты и ожидания.


static func set_level(legion: Legion, type: String, level: int) -> void:
	var p := legion.fort_slot_plot(type)
	if p.is_empty():
		p = legion.fort_plot(legion.fort_empty_plot())
	if p.is_empty():
		p = legion._fort_add_plot()
	p["b"] = type
	p["lv"] = level
	legion._fort_sync_camp()


static func gate(legion: Legion, count := 3) -> void:
	legion._fort_init()
	if not legion.fort.has("newcomers"):
		legion.fort["newcomers"] = []
	while (legion.fort["newcomers"] as Array).size() < mini(3, count):
		(legion.fort["newcomers"] as Array).append(legion._fort_newcomer())


static func recruit(legion: Legion, fighter := true) -> Dictionary:
	gate(legion, 1)
	var person := legion.recruit_resident()
	if fighter and not person.is_empty():
		house_fighter(legion, int(person["id"]))
	return person


static func house_fighter(legion: Legion, sid: int) -> bool:
	return legion.fort_assign(0, sid)
