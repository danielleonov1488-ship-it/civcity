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
