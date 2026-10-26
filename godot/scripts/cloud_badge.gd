class_name CloudBadge
extends Button
## Значок «нет связи с облаком» сверху справа, слева от колокольчика: перечёркнутое облачко на медальоне.
## Виден, когда сервер не отвечает дольше 2 минут (Account.off_since) — только в своей игре со входом.
## Подсказка — AccountUi.status_text(); щелчок — попробовать снова сразу (Account.retry_now).
## Один раз за запуск игры советник спокойно объясняет, что город сохраняется на компьютере.
## Рисуется кодом — без новых картинок.

const AFTER := 120.0                     # сколько секунд без связи, прежде чем показать значок
const TEXT := "Игра уже пару минут не может достучаться до сервера civcity.ru. Ничего не пропало: город сохраняется на этом компьютере и сам уйдёт в облако, когда связь появится.\n\nЕсли включён VPN или прокси — добавьте CivCity в исключения. Пока связи нет, вверху справа видно перечёркнутое облачко; щёлкните по нему, чтобы попробовать снова."

var hud
var holder: Control                      # обёртка с тенью (её и прячем, чтобы не оставалось пустого места)
var _t := 0.0


static func make(h, size: float) -> CloudBadge:
	var b := CloudBadge.new()
	b.hud = h
	b.name = "CloudOff"
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_NONE
	for st: Array in [["normal", "medal"], ["hover", "medal_hover"], ["pressed", "medal_on"], ["hover_pressed", "medal_on"]]:
		b.add_theme_stylebox_override(st[0], h._medal(st[1], size))
	var ic := Control.new()
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.draw.connect(func(): _paint(ic))
	b.add_child(ic)
	b.tooltip_text = "Нет связи с облаком"
	b.pressed.connect(b._click)
	return b


## Облачко из трёх кругов (голубовато-серое, с тёмной каймой) и красная черта поверх
static func _paint(c: Control) -> void:
	var s := minf(c.size.x, c.size.y)
	var o := (c.size - Vector2(s, s)) * 0.5
	var ink := Color("4a2c17")
	var cloud := Color("a9bccb")
	var red := Color("b0402a")
	var parts := [[Vector2(0.33, 0.58), 0.16], [Vector2(0.5, 0.44), 0.21], [Vector2(0.68, 0.56), 0.15]]
	var base := Rect2(o + Vector2(0.33, 0.52) * s, Vector2(0.35, 0.22) * s)
	for pass_i in 2:
		var grow := s * 0.06 if pass_i == 0 else 0.0
		var col := ink if pass_i == 0 else cloud
		for p: Array in parts:
			c.draw_circle(o + (p[0] as Vector2) * s, float(p[1]) * s + grow, col, true, -1.0, true)
		c.draw_rect(base.grow(grow), col)
	var a := o + Vector2(0.24, 0.24) * s
	var e := o + Vector2(0.77, 0.8) * s
	c.draw_line(a, e, ink, s * 0.13, true)
	c.draw_line(a, e, red, s * 0.075, true)


func _click() -> void:
	Account.me().retry_now()
	_t = 0.0
	tooltip_text = "Пробуем связаться с облаком…"


func _process(dt: float) -> void:
	_t -= dt
	if _t > 0.0:
		return
	_t = 1.0
	var a := Account.me()
	var g = hud.game if hud else null
	var on: bool = g != null and String(g.mode) in ["play", "new"] and a.required() and a.signed_in() \
		and a.off_since > 0.0 and Time.get_unix_time_from_system() - a.off_since >= AFTER
	var box: Control = holder if holder != null else self
	if box.visible != on:
		box.visible = on
	if not on:
		return
	tooltip_text = "%s\nЩёлкните по облачку — попробуем снова сейчас." % AccountUi.status_text()
	if not a.off_told:
		var rc = g.get("rank_cine")
		if rc != null and rc.calm() and not hud.advisor_panel.visible:   # чужой совет не перебиваем — скажем, когда он закрыт
			a.off_told = true
			hud.advisor("Нет связи с облаком", TEXT)
