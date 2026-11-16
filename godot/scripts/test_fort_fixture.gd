extends RefCounted
## Только фикстура тестов: заданный уровень без оплаты и ожидания.


static func set_level(legion: Legion, type: String, level: int) -> void:
	var p := legion.fort_slot_plot(type)
	if p.is_empty():
		p = legion.fort_plot(legion.fort_empty_plot())
	assert(not p.is_empty(), "No plot for test fixture: " + type)
	p["b"] = type
	p["lv"] = level
	legion._fort_sync_camp()
