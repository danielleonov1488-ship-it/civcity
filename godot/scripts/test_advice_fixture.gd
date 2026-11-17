extends RefCounted
## Советы читаем по очереди; плашки и паузы пролистываем без ожидания секунд.

const MAX_STEPS := 64


static func _advance(hud: Hud) -> void:
	if hud.advisor_panel.visible:
		hud.adv_ok.pressed.emit()
	hud._clear(hud.notes_box)
	hud._tip_next = 0
	hud._flush_guidance()
	hud._once_tips()


static func show(hud: Hud, title: String) -> bool:
	for attempt in MAX_STEPS:
		if hud.advisor_panel.visible and hud.adv_title.text == title:
			return true
		_advance(hud)
	return hud.advisor_panel.visible and hud.adv_title.text == title


## Первый показ уже проверен; считаем повторные открытия, включая отложенные.
static func repeats(hud: Hud, title: String) -> int:
	var count := 0
	for attempt in MAX_STEPS:
		_advance(hud)
		if hud.advisor_panel.visible and hud.adv_title.text == title:
			count += 1
	return count
