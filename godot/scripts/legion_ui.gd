class_name LegionUi
extends Control
## Окно «Легион» (старый замысел владельца, новая графика): одно окно с вкладками
##   «Походы»   — рисованная карта провинции (assets/ui/ai/legion/40a…40h.jpg, пока карты нет — своя нарисованная),
##                бои стоят на каменных площадках тропы, в конце — босс; карточка боя: враги по волнам, награда,
##                рекомендованный уровень, шансы, провиант, кнопка «В бой»; под картой — 8 провинций (портреты боссов);
##   «Войска»   — отряд (места по порядку, выбор бойца), 5 родов войск: портрет, уровень, числа, ОДНА кнопка «Улучшить»
##                с ценой и таймером по настоящим часам; умения в бою (за Славу);
##   «Против городов» — рейтинг побед, заряды атак, отряд обороны, соперники с сервера (или «скоро»), летопись боёв;
##   «Чудеса»   — 8 чудес: картинка, бонус, нужный рейтинг, цена в денариях и Славе, «Поставить в городе» / «Возвести»;
##                Триумф за Славу.
## Медальон «Легион» сверху справа появляется, когда изучен «Легион». Правила и числа — Legion (legion.gd), бой — LegionSim.
## Подключение в hud.gd: LegionUi.attach(self) в _ready; LegionUi.close_for(self) в _close_windows и close_panels.
##
## Бой: «В бой» → Legion.start_battle(st) → сигнал battle_requested(setup) для 3D-боя; бой зовёт apply_result и по
## закрытии — legion.battle_closed.emit(out): окно открывается снова. Если 3D-боя нет (никто не слушает сигнал) —
## окно считает бой само (LegionSim.run) и показывает итог.
## Бои с городами: сеть — отдельный модуль (см. _net()): pvp_ready() / pvp_opponents(cb) / pvp_report(setup, out).
## Картинки владельца (листы 35–41) раскладывает .work/py/legion_art.py; нет картинки — рисованные значки игры.

const DIR := "res://assets/ui/ai/legion/"
const CW := 1140.0                         # ширина содержимого вкладки
const CH := 604.0                          # высота содержимого вкладки
const MAP := Vector2(784, 441)             # карта провинции на экране (16:9)
const MAP_PX := Vector2(1672, 941)         # размер картинок карт (точки площадок — в этих координатах)
const CARD_W := 330.0                      # карточка боя справа от карты
const SLOT := 62.0                         # место в отряде

const C_INK := Color("4a2c17")
const C_SOFT := Color("7a5a3c")
const C_GOOD := Color("4f7a2a")
const C_BAD := Color("b0402a")
const C_GOLD := Color("a8740f")
const C_CREAM := Color("fff4dc")
const ODDS_COL := {"good": Color("4f7a2a"), "mid": Color("a8740f"), "hard": Color("c0612a"), "bad": Color("b0402a")}

## Значки листа 39 (легион и рейтинг) и 38 (умения и итоги боя); без листа — рисованные значки игры
const ICON39 := {"glory": 0, "rating": 1, "battle": 2, "map": 3, "camp": 4, "barracks": 5, "range": 6, "siege": 7,
	"upgrade": 8, "timer": 9, "attack": 10, "defend": 11, "boss": 12, "lock": 13, "trophy": 14, "report": 15}
const ICON39_ALT := {"glory": "laurels", "rating": "level", "battle": "swords", "map": "scroll", "camp": "tent", "barracks": "castle",
	"range": "arrow", "siege": "hammer", "upgrade": "level", "timer": "time", "attack": "legion", "defend": "shield", "boss": "helmet",
	"lock": "lock", "trophy": "amphora", "report": "scroll"}
const ICON38 := {"eagle": 5, "hourglass": 12, "defeat": 13, "victory": 14, "chest": 15}
const ICON38_ALT := {"eagle": "eagle", "hourglass": "time", "defeat": "swords", "victory": "laurels", "chest": "coins"}
const UNIT_ALT := {"legionary": "helmet", "spearman": "shield", "archer": "arrow", "ballista": "hammer", "catapult": "rock"}
const PERK_ALT := {"oil": "pot", "testudo": "shield", "bandage": "medic", "volley": "arrow", "horn": "music"}
const TAGS := {"human": "человек", "beast": "зверь", "giant": "великан", "ranged": "стреляет издалека", "armored": "в броне",
	"swift": "быстрый", "swarm": "нападает стаей"}

## Площадки боёв на картах владельца (точки картинки 1672×941; .work/py/legion_art.py пишет то же в maps.json):
## camp — стоянка легиона в начале тропы (если камней на один больше), stops — 9 боёв, boss — площадка босса
const STOPS := {
	"40a": {"camp": [185, 822], "stops": [[307, 712], [490, 638], [700, 590], [932, 522], [805, 420], [643, 352], [740, 250], [930, 205], [1240, 306]], "boss": [1374, 244]},
	"40b": {"camp": [122, 772], "stops": [[445, 708], [612, 655], [697, 537], [576, 442], [603, 295], [778, 268], [912, 372], [1083, 425], [1323, 276]], "boss": [1468, 205]},
	"40c": {"camp": [150, 718], "stops": [[365, 652], [365, 557], [490, 494], [640, 514], [755, 456], [855, 395], [1003, 366], [1090, 298], [1215, 258]], "boss": [1395, 220]},
	"40d": {"stops": [[190, 698], [340, 588], [493, 481], [695, 479], [745, 370], [887, 277], [1020, 328], [1206, 372], [1360, 307]], "boss": [1440, 200]},
	"40e": {"camp": [205, 752], "stops": [[307, 706], [378, 627], [508, 570], [659, 497], [801, 455], [779, 375], [874, 290], [1033, 320], [1223, 364]], "boss": [1405, 290]},
	"40f": {"camp": [215, 739], "stops": [[415, 676], [564, 590], [605, 474], [726, 389], [717, 288], [821, 211], [958, 270], [1111, 326], [1327, 290]], "boss": [1466, 207]},
	"40g": {"camp": [258, 799], "stops": [[455, 720], [687, 643], [891, 622], [801, 535], [634, 457], [765, 368], [918, 380], [1008, 303], [1212, 295]], "boss": [1373, 260]},
	"40h": {"stops": [[190, 731], [305, 653], [376, 557], [593, 503], [779, 476], [862, 380], [990, 430], [1194, 384], [1272, 313]], "boss": [1427, 250]},
}
## Своя нарисованная карта (пока владелец не прислал картинку): тропа снизу слева вверх направо
const PLACE_PATH := [[190, 790], [330, 712], [478, 650], [452, 528], [588, 452], [748, 500], [884, 418], [846, 296], [1004, 238], [1170, 318], [1392, 244]]
const BIOMES := {
	"forest": {"ground": Color("97ad5c"), "ground2": Color("5f7f3a"), "dirt": Color("b9a06a"), "deco": ["pine", "tree", "tree", "pine", "tree", "rock"],
		"land": ["camp", "fence", "camp", "wood"], "water": "river"},
	"hills": {"ground": Color("b6a86c"), "ground2": Color("7f7f4a"), "dirt": Color("c2a46e"), "deco": ["rock", "pine", "rock", "tree", "pine"],
		"land": ["rock", "rock", "rock"], "water": "", "hills": true},
	"darkforest": {"ground": Color("6f8a4a"), "ground2": Color("3f5a33"), "dirt": Color("8f8358"), "deco": ["pine", "pine", "tree", "pine", "rock"],
		"land": ["camp", "fence", "well", "camp"], "water": "stream", "tint": Color(0.78, 0.86, 0.78)},
	"swamp": {"ground": Color("8f9a62"), "ground2": Color("5d6e4f"), "dirt": Color("7d7a52"), "deco": ["tree", "pine", "tree", "rock", "tree"],
		"land": ["camp", "wood", "fence"], "water": "ponds", "tint": Color(0.84, 0.9, 0.84)},
	"labyrinth": {"ground": Color("a9aa66"), "ground2": Color("88905a"), "deco": ["tree", "pine", "rock"], "land": ["castle"], "water": "sea"},
	"rocks": {"ground": Color("b2a46c"), "ground2": Color("8e8a5c"), "deco": ["rock", "tree", "rock"], "land": ["rock", "rock"], "water": "sea"},
	"desert": {"ground": Color("e2c47e"), "ground2": Color("cfa862"), "deco": ["rock", "rock"], "land": ["camp", "camp"], "water": "ponds"},
	"hades": {"ground": Color("6d5a52"), "ground2": Color("4a3c3a"), "deco": ["rock", "rock"], "land": ["castle"], "water": "stream"},
}

var hud: Hud
var game
var lg: Legion
var btn: Button                            # медальон «Легион» сверху справа
var btn_wrap: Control
var win: PanelContainer
var content: Control                       # сюда строится вкладка
var tabs := {}
var tab := "campaign"
var lbl_glory: Label
var lbl_money: Label
var lbl_rating: Label
var view_r := -1                           # какая провинция на карте
var view_c := -1                           # какой круг похода
var sel := {}                              # выбранный бой {c, r, s}
var overlay: Control                       # окно поверх (итог боя, выбор бойца)
var toast: PanelContainer
var _live := []                            # что обновлять каждые 0,2 с: таймеры улучшений, заряды атак
var _live_t := 0.0
var _dirty := false
var _city_t := 0.0
var _tex := {}
var _glow_tex: Texture2D
var _pending := {}                         # бой с городом, идущий в 3D: доложить серверу итог
var _pvp_state := "idle"                   # idle | loading | ok | error
var _pvp_list: Array = []
var _pvp_err := ""
var _pvp_fail := {}                         # ошибка списка соперников для окна: title, text, code (LegionNet.last_fail)
var _pvp_auto := false                      # сам повторил после ошибки (раз за заход на вкладку)
var _pvp_auto_wait := false                 # ждёт 5 с до этого повтора
var _net_obj = null
var _net_checked := false
# обучение Легиону (4 шага, Legion.tut_step): полоса в окне с шагом и «Пропустить», стрелка hud
var tut_bar: PanelContainer
var tut_lbl: Label
var tut_act: Button                        # «Поставить Казармы» (шаг 1, если окно открыто раньше)
var _fight_btn: Button                     # «В бой!» в карточке боя
var _front_btn: Button                     # передний край на карте
var _upg_btn: Button                       # «Улучшить до 2» у легионеров


# =====================================================================
#   подключение
# =====================================================================

static func attach(h: Hud) -> LegionUi:
	var u := of(h)
	if u != null:
		return u
	u = LegionUi.new()
	u.setup(h)
	return u


static func of(h) -> LegionUi:
	if h == null or h.root == null:
		return null
	return h.root.get_node_or_null("LegionUi") as LegionUi


## Закрыть окно (hud._close_windows / close_panels); true — оно было открыто
static func close_for(h) -> bool:
	var u := of(h)
	if u == null or not u.visible:
		return false
	u.close()
	return true


func setup(h: Hud) -> void:
	hud = h
	game = h.game
	name = "LegionUi"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	h.root.add_child(self)
	if game != null and game.city != null:
		lg = game.city.legion
	_make_button()
	_make_window()
	if lg != null:
		lg.changed.connect(func(): _dirty = true; _update_button(); hud._update_pointer())
		lg.battle_closed.connect(_on_battle_closed)
		game.city.changed.connect(_on_city)
	resized.connect(_fit)
	_update_button()


func _make_button() -> void:
	btn = hud._round("legion", "Легион: походы, войска и чудеса света", 48, func(): toggle())
	btn_wrap = hud._shadowed(btn)
	hud.top_panel.add_child(btn_wrap)
	hud.top_panel.move_child(btn_wrap, 0)
	hud.top_btns["legion"] = btn


## Медальон виден, когда изучен «Легион»; пока окно ни разу не открывали — светится
func _update_button() -> void:
	if btn_wrap == null:
		return
	var on: bool = lg != null and lg.window_open() and game != null and game.mode != "menu"
	btn_wrap.visible = on
	if on:
		hud._set_on(btn, not bool(lg.flags.get("seen", false)) or visible)
		# обучение, шаг 1: один раз советник рассказывает, с чего начать (стрелка — на Казармы). Только когда окно
		# исследований закрыто и советник свободен: Esc, правая кнопка и щелчок по карте закрывают окно вместе
		# с советником — совет погас бы, не показавшись (окно закрыли — hud зовёт эту проверку через кадр)
		if not lg.flags.has("advised") and not lg.flags.has("seen") and game.mode in ["play", "new"] and lg.tut_step() == "barracks" \
				and not hud.research_panel.visible and not hud.advisor_panel.visible:
			lg.flags["advised"] = true
			hud.advisor("Легион собран!", "Сначала поставьте Казармы (раздел «Легион» на нижней полосе) — они дают легионеров. Потом откройте медальон «Легион» сверху справа: там походы, войска и чудеса света.\n\nОтряд дерётся сам; ваше — состав и умения в нужный миг. Победы приносят денарии и Славу.",
				func(): lg.tut_skip())


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open(tab_id := "") -> void:
	if lg == null:
		return
	if not lg.window_open():
		hud.notify(lg.lock_text(), "lock")
		return
	hud._close_windows()
	hud._close_tray()
	hud._hide_info()
	visible = true
	lg.flags["seen"] = true
	if tab_id == "" and lg.tut_step() == "fight":
		tab_id = "campaign"                  # обучение: первый бой — на карте похода
	var fr := lg.frontier()
	if view_r < 0:
		view_r = int(fr["r"])
		view_c = int(fr["cycle"])
		sel = {}
	if lg.flags.has("turn_page") and tab_id != "pvp":
		# босс побеждён (в 3D-бою или пока окно было закрыто) — карта перелистывается на новую провинцию
		lg.flags.erase("turn_page")
		_turn_page()
	else:
		_select_tab(tab_id if tab_id != "" else tab)
	_update_button()
	hud._update_pointer()


func close() -> void:
	visible = false
	_close_overlay()
	_update_button()
	hud._update_pointer()


func _on_city() -> void:
	_update_button()
	if visible:
		_update_header()
		_city_t = 0.6                       # денарии поменялись — проверим чуть позже, хватает ли теперь на что-то


## Что в окне зависит от денариев города: перерисовываем, только если тут что-то поменялось
func _sig() -> String:
	var a: Array = [lg.city_level(), lg.cap()]
	for t in Legion.UNIT_IDS:
		a.append(lg.can_upgrade(t))
	for id in Legion.PERK_IDS:
		a.append(lg.can_upgrade_perk(id))
	for w: Dictionary in Legion.WONDERS:
		a.append(lg.can_build_wonder(String(w["id"])))
	a.append(lg.can_triumph())
	if not sel.is_empty():
		var st := lg.stage_info(int(sel["c"]), int(sel["r"]), int(sel["s"]))
		a.append(lg.can_fight(st))
		a.append(lg.food_cost(st) <= game.city.money)
	return str(a)


var _last_sig := ""


func _process(dt: float) -> void:
	if not visible:
		return
	if _city_t > 0.0:
		_city_t -= dt
		if _city_t <= 0.0:
			var sg := _sig()
			if sg != _last_sig:
				_dirty = true
	if _dirty and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_dirty = false
		_rebuild()
	_live_t -= dt
	if _live_t <= 0.0:
		_live_t = 0.2
		_tick_live()


## Таймеры: полоски улучшений, заряды атак. Улучшение дошло — завершаем сразу (не ждём игрового часа)
func _tick_live() -> void:
	_odds_poll()
	var done := false
	for type in lg.upg.keys():
		if lg.upgrade_left(type) <= 0.0:
			done = true
	if done:
		for m in lg.tick():
			if game.city.has_method("_event"):
				game.city._event(m, "legion")
	for e: Dictionary in _live:
		var l: Label = e.get("label")
		if l == null or not is_instance_valid(l):
			continue
		match String(e["kind"]):
			"upg":
				var t: String = e["type"]
				if lg.upg.has(t):
					l.text = "До %d уровня: %s" % [int(lg.upg[t]["to"]), Legion.fmt_duration(lg.upgrade_left(t))]
					var b: ProgressBar = e.get("bar")
					if b != null and is_instance_valid(b):
						b.value = lg.upgrade_progress(t)
			"odds":
				var est := _odds_est(e["st"])
				if not est.is_empty() and not bool(e.get("done", false)):
					e["done"] = true
					var od := lg.odds(e["st"], est)
					l.text = String(od[1])
					l.add_theme_color_override("font_color", ODDS_COL.get(String(od[0]), C_INK))
			"pvp":
				var n := lg.pvp_charges_now()
				l.text = "Атак в запасе: %d из %d" % [n, int(Legion.PVP["charges"])] + ("" if n >= int(Legion.PVP["charges"]) else " · ещё одна через %s" % Legion.fmt_duration(lg.pvp_next_charge()))


# =====================================================================
#   окно и вкладки
# =====================================================================

func _make_window() -> void:
	win = PanelContainer.new()
	win.add_theme_stylebox_override("panel", hud._box_panel(8))
	add_child(win)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	win.add_child(v)
	# шапка: слева Слава и денарии, посередине «Легион», справа рейтинг и «закрыть»
	var hdr := HBoxContainer.new()
	var left := HBoxContainer.new()
	left.custom_minimum_size = Vector2(360, 0)
	left.add_theme_constant_override("separation", 8)
	var g := _chip_val(_ic39("glory"), "0", "Слава: даётся за победы. Тратится на умения, высокие уровни бойцов, чудеса света и Триумф")
	lbl_glory = g[1]
	left.add_child(g[0])
	var m := _chip_val(hud.ico("coins", 64), "0", "Денарии в казне города: на них улучшают бойцов и собирают провиант в поход")
	lbl_money = m[1]
	left.add_child(m[0])
	hdr.add_child(left)
	var t := hud._label("Легион", 32, false, C_INK, hud.font_title)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_child(t)
	var right := HBoxContainer.new()
	right.custom_minimum_size = Vector2(360, 0)
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 8)
	var r := _chip_val(_ic39("rating"), "0", "Рейтинг походов: растёт с каждой новой победой и не тратится. Открывает чудеса света")
	lbl_rating = r[1]
	right.add_child(r[0])
	var close_b: Button = hud._bare("close", "Закрыть", 36, func(): close())
	close_b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_child(close_b)
	hdr.add_child(right)
	v.add_child(hdr)
	# вкладки
	var tb := HBoxContainer.new()
	tb.alignment = BoxContainer.ALIGNMENT_CENTER
	tb.add_theme_constant_override("separation", 10)
	for d: Array in [["campaign", "Походы", _ic39("map")], ["troops", "Войска", _ic39("battle")],
			["pvp", "Против городов", _ic39("attack")], ["wonders", "Чудеса", hud.ico("special", 64)]]:
		var id: String = d[0]
		var b := _tab_btn(String(d[1]), d[2])
		b.pressed.connect(func(): _select_tab(id))
		tabs[id] = b
		tb.add_child(b)
	v.add_child(tb)
	# обучение: шаг одной строкой и «Пропустить» (видно, пока идёт обучение; внизу окна)
	tut_bar = hud._chip(true, 10)
	tut_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 10)
	tut_bar.add_child(th)
	var ti := _tr(_ic39("map"), 30)
	ti.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(ti)
	tut_lbl = hud._label("", 17, true, C_INK)
	tut_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(tut_lbl)
	tut_act = _btn("Поставить Казармы", 0, 15, hud.ico("hammer", 64), "", func(): close(); hud.select_build("barracks"))
	tut_act.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(tut_act)
	var sk := _btn("Пропустить обучение", 0, 14, null, "", func(): lg.tut_skip())
	sk.tooltip_text = "Без подсказок; в первом бою один раз покажем масло"
	sk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(sk)
	tut_bar.visible = false
	content = MarginContainer.new()
	content.custom_minimum_size = Vector2(CW, CH)
	v.add_child(content)
	v.add_child(tut_bar)                     # внизу окна: стрелки на вкладки и карточки её не закрывают
	toast = hud._chip(true, 12)
	toast.visible = false
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tl := hud._label("", 17, true, C_INK)
	tl.name = "t"
	toast.add_child(tl)
	add_child(toast)


func _tab_btn(text: String, icon: Texture2D) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(214, 46)
	b.focus_mode = Control.FOCUS_NONE
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.add_child(_tr(icon, 32))
	h.add_child(hud._label(text, 20, true))
	b.add_child(h)
	return b


func _select_tab(id: String) -> void:
	tab = id
	for k in tabs:
		var b: Button = tabs[k]
		var on: bool = k == id
		b.add_theme_stylebox_override("normal", hud._box_pill(16, 6, "g_btn_on" if on else "g_btn"))
		b.add_theme_stylebox_override("hover", hud._box_pill(16, 6, "g_btn_on" if on else "g_btn_hover"))
	if id == "pvp" and _pvp_state != "loading":
		_pvp_state = "idle"                  # каждый заход — свежий список соперников
		_pvp_auto = false
	_rebuild()


func _rebuild() -> void:
	if content == null or lg == null:
		return
	_live = []
	hud._clear(content)
	_fight_btn = null
	_front_btn = null
	_upg_btn = null
	var body: Control
	match tab:
		"troops":
			body = _build_troops()
		"pvp":
			body = _build_pvp()
		"wonders":
			body = _build_wonders()
		_:
			body = _build_campaign()
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(body)
	_update_header()
	_update_tut()
	_last_sig = _sig()
	_fit.call_deferred()
	hud._update_pointer()


# =====================================================================
#   обучение Легиону: шаг в полосе окна, стрелка — у hud (hud._update_pointer спрашивает tut_pointer)
# =====================================================================

const TUT_TEXT := {
	"barracks": "Поставьте Казармы — они дают легионеров.",
	"medal": "Откройте медальон «Легион» сверху справа.",
	"fight": "Первый бой — учебный. Отряд дерётся сам, но в нужный миг нужна ваша команда.",
	"troops": "Бойцы растут по часам, даже когда игра закрыта. Улучшите легионеров.",
}


## Идёт обучение Легиону (только в настоящей игре: не в меню и не в показе)
func tut_active() -> bool:
	return lg != null and game != null and game.mode in ["play", "new"] and lg.tut_step() != ""


## Полоса обучения в окне: «Шаг 3 из 4 · …» и «Пропустить обучение»
func _update_tut() -> void:
	if tut_bar == null:
		return
	var on := tut_active()
	var was := tut_bar.visible
	tut_bar.visible = on
	if on:
		var step := lg.tut_step()
		tut_lbl.text = "Шаг %d из %d · %s" % [Legion.tut_num(step), Legion.TUT_STEPS.size(), TUT_TEXT.get(step, "")]
		tut_act.visible = step == "barracks"
	if was != on:
		_fit.call_deferred()


## Куда показывает стрелка обучения: [Control или null, подпись]
func tut_pointer() -> Array:
	var step := lg.tut_step()
	match step:
		"barracks":
			if visible:
				return [tut_act, ""]
			if game.tool == "barracks":
				return [null, ""]
			return [hud._card_or_cat("military", "barracks"), "Казармы"]
		"medal":
			return [btn, "Легион"]
		"fight", "troops":
			if not visible:
				return [btn, "Легион"]
			if overlay != null and is_instance_valid(overlay):
				return [null, ""]
			if step == "fight":
				if tab != "campaign":
					return [tabs["campaign"], "Походы"]
				if _fight_btn != null and is_instance_valid(_fight_btn) and int(sel.get("s", -1)) == 0 and int(sel.get("r", -1)) == 0 and int(sel.get("c", -1)) == 0:
					return [_fight_btn, ""]
				if _front_btn != null and is_instance_valid(_front_btn):
					return [_front_btn, "Бой I"]
				return [null, ""]
			if tab != "troops":
				return [tabs["troops"], "Войска"]
			if _upg_btn != null and is_instance_valid(_upg_btn):
				return [_upg_btn, ""]
	return [null, ""]


func _update_header() -> void:
	if lbl_glory == null or lg == null:
		return
	lbl_glory.text = hud.fmt(floorf(lg.glory))
	lbl_money.text = hud.fmt(game.city.money)
	lbl_rating.text = "Рейтинг %s" % hud.fmt(lg.rating)


## Окно — посередине и целиком на экране (при крупном интерфейсе — чуть меньше)
func _fit() -> void:
	if win == null:
		return
	win.reset_size()
	var s := win.get_combined_minimum_size()
	win.size = s
	var avail := size
	if avail.x < 10.0:
		return
	var k := minf(1.0, minf((avail.x - 12.0) / s.x, (avail.y - 12.0) / s.y))
	win.scale = Vector2(k, k)
	win.position = ((avail - s * k) / 2.0).floor()
	if toast:
		toast.reset_size()
		toast.position = Vector2((avail.x - toast.size.x) / 2.0, win.position.y + s.y * k - toast.size.y - 30.0)


## Короткая надпись внизу окна (почему нельзя и т. п.) — сама гаснет
func _say(text: String) -> void:
	if text == "" or toast == null:
		return
	(toast.get_node("t") as Label).text = text
	toast.visible = true
	toast.modulate.a = 1.0
	_fit()
	var tw := toast.create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(toast, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): toast.visible = false)


# =====================================================================
#   картинки
# =====================================================================

func _art(kind: String, id: String) -> Texture2D:
	var key := kind + ":" + id
	if not _tex.has(key):
		_tex[key] = Legion.art_texture(kind, id)
	return _tex[key]


## Клетка листа значков (38, 39 — 4×4)
func _sheet(sheet: String, i: int) -> Texture2D:
	var key := "sheet:%s:%d" % [sheet, i]
	if _tex.has(key):
		return _tex[key]
	var t: Texture2D = null
	var f := DIR + sheet + ".png"
	if ResourceLoader.exists(f):
		var base := load(f) as Texture2D
		if base != null:
			var at := AtlasTexture.new()
			at.atlas = base
			var w := base.get_width() / 4.0
			var h := base.get_height() / 4.0
			at.region = Rect2((i % 4) * w, (i / 4) * h, w, h)
			t = at
	_tex[key] = t
	return t


func _ic39(n: String) -> Texture2D:
	var t := _sheet("39", int(ICON39[n]))
	return t if t != null else hud.ico(String(ICON39_ALT[n]), 64)


func _ic38(n: String) -> Texture2D:
	var t := _sheet("38", int(ICON38[n]))
	return t if t != null else hud.ico(String(ICON38_ALT[n]), 64)


func _unit_tex(type: String) -> Texture2D:
	var t := _art("unit", type)
	return t if t != null else hud.ico(String(UNIT_ALT.get(type, "helmet")), 64)


func _enemy_tex(key: String) -> Texture2D:
	var t := _art("enemy", key)
	if t != null:
		return t
	var E: Dictionary = Legion.ENEMIES[key]
	return hud.ico("helmet" if bool(E.get("boss", false)) else ("swords" if "human" in E["tags"] else "cat"), 64)


func _perk_tex(id: String) -> Texture2D:
	var t := _art("perk", id)
	return t if t != null else hud.ico(String(PERK_ALT.get(id, "swords")), 64)


func _wonder_tex(id: String) -> Texture2D:
	var t := _art("wonder", id)
	return t if t != null else hud.ico("special", 128)


## Есть ли у портрета своя бронзовая рамка (картинки владельца) — тогда без медальона
func _framed(kind: String, id: String) -> bool:
	return _art(kind, id) != null


func _tr(tex: Texture2D, sz: float, grey := false) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.custom_minimum_size = Vector2(sz, sz)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if grey:
		hud._grey(r)
	return r


## Портрет: у картинок владельца рамка своя; у заглушки — бронзовый медальон со значком
func _portrait(kind: String, id: String, sz: float, grey := false) -> Control:
	var tex: Texture2D
	match kind:
		"unit":
			tex = _unit_tex(id)
		"enemy":
			tex = _enemy_tex(id)
		"perk":
			tex = _perk_tex(id)
		_:
			tex = _wonder_tex(id)
	if _framed(kind, id) or kind == "perk":
		return _tr(tex, sz, grey)
	var p := Panel.new()
	p.custom_minimum_size = Vector2(sz, sz)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", hud._medal("medal_lock" if grey else "medal", sz))
	var ic := _tr(tex, sz * 0.6, grey)
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = sz * 0.2
	ic.offset_top = sz * 0.2
	ic.offset_right = -sz * 0.2
	ic.offset_bottom = -sz * 0.2
	p.add_child(ic)
	return p


## Золотое свечение под выбранным боем
func _glow(sz: float) -> TextureRect:
	if _glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.86, 0.42, 0.95))
		g.set_color(1, Color(1.0, 0.78, 0.3, 0.0))
		g.add_point(0.55, Color(1.0, 0.82, 0.38, 0.55))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(0.5, 0.0)
		gt.width = 128
		gt.height = 128
		_glow_tex = gt
	var r := TextureRect.new()
	r.texture = _glow_tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = Vector2(sz, sz)
	return r


# =====================================================================
#   мелочи оформления
# =====================================================================

func _l(text: String, sz := 16, bold := false, col := C_INK) -> Label:
	return hud._label(text, sz, bold, col)


func _title(text: String, sz := 22, col := C_INK) -> Label:
	return hud._label(text, sz, false, col, hud.font_title)


func _wl(text: String, w: float, sz := 14, col := C_SOFT, bold := false, center := false) -> Label:
	var l: Label = hud._wrap(hud._label(text, sz, bold, col), w)
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _chip_val(tex: Texture2D, text: String, tip: String, sz := 19) -> Array:
	var p: PanelContainer = hud._chip(false, 8)
	p.tooltip_text = tip
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_tr(tex, 28))
	var l := _l(text, sz, true)
	h.add_child(l)
	p.add_child(h)
	return [p, l]


func _bar_panel(pad := 6.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", hud._box_bar(pad))
	return p


func _hdiv(h := 14.0) -> TextureRect:
	return hud._divider(h)


## Цена: денарии и Слава (красным — чего не хватает)
func _cost_row(cost: Dictionary, sz := 16) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if int(cost.get("money", 0)) > 0:
		h.add_child(_tr(hud.ico("coins", 64), sz + 6))
		h.add_child(_l(hud.fmt(float(cost["money"])), sz, true, C_INK if float(cost["money"]) <= game.city.money else C_BAD))
	if int(cost.get("glory", 0)) > 0:
		if h.get_child_count() > 0:
			h.add_child(_gap(6))
		h.add_child(_tr(_ic39("glory"), sz + 8))
		h.add_child(_l(str(int(cost["glory"])), sz, true, C_INK if float(cost["glory"]) <= lg.glory + 0.001 else C_BAD))
	return h


func _gap(w: float, h := 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _bar(w: float, v: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.min_value = 0.0
	b.max_value = 1.0
	b.step = 0.001
	b.value = v
	b.custom_minimum_size = Vector2(w, 16)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_stylebox_override("background", hud._ai_box("g_slider", [8, 0, 8, 0], [0, 0, 0, 0]))
	b.add_theme_stylebox_override("fill", hud._ai_box("g_slider_fill", [8, 0, 8, 0], [0, 0, 0, 0]))
	return b


## Кнопка-плашка с надписью (и значком); why — почему нельзя (кнопка серая, причина в подсказке)
func _btn(text: String, w: float, sz: int, icon: Texture2D, why: String, cb: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", hud.font_bold)
	b.add_theme_font_size_override("font_size", sz)
	if icon != null:
		b.icon = icon
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", sz + 10)
	b.text = text
	if w > 0.0:
		b.custom_minimum_size = Vector2(w, sz + 22)
	if why != "":
		b.disabled = true
		b.tooltip_text = why
	b.pressed.connect(cb)
	return b


## Действие кнопки: улучшить бойца / умение, Триумф, чудо; не вышло — сказать почему
func _do(what: String, id: String) -> void:
	var ok := false
	match what:
		"upgrade":
			ok = lg.upgrade(id)
			if not ok:
				_say(lg.can_upgrade(id))
		"perk":
			ok = lg.upgrade_perk(id)
			if not ok:
				_say(lg.can_upgrade_perk(id))
		"triumph":
			ok = lg.triumph()
			if not ok:
				_say(lg.can_triumph())
		"wonder":
			ok = lg.build_wonder(id)
			if not ok:
				_say(lg.can_build_wonder(id))
	if ok and game and game.sound:
		game.sound.ui("coins")


## Кнопка-картинка (портрет): без рамки, при наведении светлеет
func _pic_btn(c: Control, sz: float, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(sz, sz)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	var e := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, e)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(c)
	b.mouse_entered.connect(func(): c.modulate = Color(1.14, 1.1, 1.04))
	b.mouse_exited.connect(func(): c.modulate = Color.WHITE)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


## Ярлычок с числом в углу портрета (уровень, сколько врагов)
func _badge(parent: Control, text: String, corner := Vector2(1, 1), sz := 14) -> void:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("6e3d17")
	sb.border_color = Color("e9bd5c")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	sb.content_margin_top = -1
	sb.content_margin_bottom = 0
	sb.anti_aliasing = true
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _l(text, sz, true, C_CREAM)
	p.add_child(l)
	_pin(p, corner, Vector2(5, 4))
	parent.add_child(p)


## Прикрепить к углу/краю родителя (corner — доля 0…1): размер — по содержимому, растёт внутрь от края
## (размер до входа в дерево не известен, поэтому — якорями, а не расчётом позиции)
func _pin(c: Control, corner: Vector2, push := Vector2.ZERO) -> void:
	c.anchor_left = corner.x
	c.anchor_right = corner.x
	c.anchor_top = corner.y
	c.anchor_bottom = corner.y
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH if is_equal_approx(corner.x, 0.5) else (Control.GROW_DIRECTION_BEGIN if corner.x > 0.5 else Control.GROW_DIRECTION_END)
	c.grow_vertical = Control.GROW_DIRECTION_BOTH if is_equal_approx(corner.y, 0.5) else (Control.GROW_DIRECTION_BEGIN if corner.y > 0.5 else Control.GROW_DIRECTION_END)
	var dx := push.x * (1.0 if corner.x > 0.5 else (-1.0 if corner.x < 0.5 else 0.0))
	var dy := push.y * (1.0 if corner.y > 0.5 else (-1.0 if corner.y < 0.5 else 0.0))
	c.offset_left = dx
	c.offset_right = dx
	c.offset_top = dy
	c.offset_bottom = dy


# =====================================================================
#   «Походы»
# =====================================================================

func _build_campaign() -> Control:
	var fr := lg.frontier()
	if view_r < 0:
		view_r = int(fr["r"])
		view_c = int(fr["cycle"])
	view_c = clampi(view_c, 0, int(fr["cycle"]))
	if sel.is_empty() or int(sel["r"]) != view_r or int(sel["c"]) != view_c:
		sel = {"c": view_c, "r": view_r, "s": _default_stage(view_c, view_r)}
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.add_child(_map_view())
	left.add_child(_region_strip())
	h.add_child(left)
	h.add_child(_stage_card(lg.stage_info(int(sel["c"]), int(sel["r"]), int(sel["s"]))))
	return h


## Какой бой показать на карте сразу: передний край (если он тут), иначе босс пройденной провинции или первый бой
func _default_stage(c: int, r: int) -> int:
	var fr := lg.frontier()
	if int(fr["cycle"]) == c and int(fr["r"]) == r:
		return int(fr["s"])
	return Legion.STAGES - 1 if lg.region_done(c, r) else 0


## Точки площадок провинции r на картинке (MAP_PX): {camp: Vector2 или null, stops: [9 × Vector2], boss: Vector2}
func _stops(r: int, has_art: bool) -> Dictionary:
	var key := String(Legion.REGIONS[r]["map"])
	var d: Dictionary = {}
	if has_art:
		d = _maps_json().get(key, STOPS.get(key, {}))
	var out := {"camp": null, "stops": [], "boss": Vector2.ZERO}
	if d.has("stops") and (d["stops"] as Array).size() >= Legion.STAGES - 1 and d.has("boss"):
		if d.get("camp") != null:
			out["camp"] = Vector2(float(d["camp"][0]), float(d["camp"][1]))
		for p: Array in d["stops"]:
			(out["stops"] as Array).append(Vector2(float(p[0]), float(p[1])))
		out["boss"] = Vector2(float(d["boss"][0]), float(d["boss"][1]))
		return out
	# своя карта: тропа PLACE_PATH, у каждой провинции чуть по-своему
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + r * 131
	var pts: Array = []
	for p: Array in PLACE_PATH:
		pts.append(Vector2(float(p[0]) + rng.randf_range(-26, 26), float(p[1]) + rng.randf_range(-20, 20)))
	out["camp"] = pts[0]
	out["stops"] = pts.slice(1, Legion.STAGES)
	out["boss"] = pts[pts.size() - 1]
	return out


var _maps_cache = null


## Площадки новых карт, найденные .work/py/legion_art.py (если владелец прислал ещё карты)
func _maps_json() -> Dictionary:
	if _maps_cache == null:
		_maps_cache = {}
		var f := DIR + "maps.json"
		if FileAccess.file_exists(f):
			var j = JSON.parse_string(FileAccess.get_file_as_string(f))
			if j is Dictionary:
				_maps_cache = j
	return _maps_cache


func _map_view() -> Control:
	var frame := _bar_panel(0)
	var m := Control.new()
	m.custom_minimum_size = MAP
	m.clip_contents = true
	frame.add_child(m)
	var R: Dictionary = Legion.REGIONS[view_r]
	var tex := _art("map", String(R["id"]))
	var pts := _stops(view_r, tex != null)
	var k := MAP / MAP_PX
	if tex != null:
		var img := TextureRect.new()
		img.texture = tex
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_SCALE
		img.set_anchors_preset(Control.PRESET_FULL_RECT)
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_child(img)
	else:
		var mp := MapPaint.new()
		mp.biome = String(R["biome"])
		mp.seed_v = 1000 + view_r * 17
		var path: Array = []
		if pts["camp"] != null:
			path.append(pts["camp"])
		path.append_array(pts["stops"])
		path.append(pts["boss"])
		mp.pts = path
		mp.k = k
		var B: Dictionary = BIOMES.get(mp.biome, BIOMES["forest"])
		for n in (B["deco"] as Array) + (B["land"] as Array):
			mp.icons[n] = _ic39("camp") if n == "camp" else hud.ico(String(n), 96)
		mp.emblem = _art("enemy", String(R["boss"]))
		var gk := "ground:%d" % view_r                      # земля считается один раз на провинцию
		if not _tex.has(gk):
			mp._make_ground(B)
			_tex[gk] = mp._ground
		mp._ground = _tex[gk]
		mp.set_anchors_preset(Control.PRESET_FULL_RECT)
		mp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_child(mp)
	var fr := lg.frontier()
	var vc := view_c
	# стоянка легиона в начале тропы
	if pts["camp"] != null:
		var cp: Vector2 = pts["camp"] * k
		var camp := _tr(_ic39("camp"), 46)
		camp.position = cp - Vector2(23, 34)
		camp.size = Vector2(46, 46)
		camp.mouse_filter = Control.MOUSE_FILTER_PASS
		camp.tooltip_text = "Стоянка легиона: отсюда отряд выходит в поход"
		m.add_child(camp)
	# бои по тропе
	for s in Legion.STAGES:
		var boss := s == Legion.STAGES - 1
		var p: Vector2 = (pts["boss"] if boss else (pts["stops"] as Array)[s]) * k
		var st := {"c": vc, "r": view_r, "s": s}
		var is_sel: bool = int(sel["s"]) == s
		var front: bool = int(fr["cycle"]) == vc and int(fr["r"]) == view_r and int(fr["s"]) == s and lg.region_rank_ok(view_r)
		var b := _stage_btn(vc, view_r, s, boss, front)
		var sz: float = b.custom_minimum_size.x
		if is_sel:
			var gl := _glow(sz * 1.9)
			gl.position = p - gl.size / 2.0
			m.add_child(gl)
		b.position = p - Vector2(sz, sz) / 2.0
		b.size = Vector2(sz, sz)
		b.pivot_offset = Vector2(sz, sz) / 2.0
		b.pressed.connect(func(): sel = st; _rebuild())
		m.add_child(b)
		if front:
			_front_btn = b
			var tw := b.create_tween().set_loops()
			tw.tween_property(b, "scale", Vector2(1.1, 1.1), 0.55).set_trans(Tween.TRANS_SINE)
			tw.tween_property(b, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE)
			# орёл легиона над передним краем
			var eg := _tr(_ic38("eagle"), 44)
			eg.size = Vector2(44, 44)
			eg.position = p + Vector2(-22, -sz / 2.0 - 46)
			m.add_child(eg)
			var tw2 := eg.create_tween().set_loops()
			tw2.tween_property(eg, "position:y", eg.position.y - 6, 0.6).set_trans(Tween.TRANS_SINE)
			tw2.tween_property(eg, "position:y", eg.position.y, 0.6).set_trans(Tween.TRANS_SINE)
		var stars := Legion.star_count(int(lg.stars.get(Legion.stage_key(vc, view_r, s), 0)))
		if lg.stage_done(vc, view_r, s):
			var sr := Stars.new(stars, 13.0 if not boss else 16.0)
			sr.position = p + Vector2(-sr.custom_minimum_size.x / 2.0, sz / 2.0 - 4.0)
			m.add_child(sr)
	# лента с названием провинции
	var rib: PanelContainer = hud._chip(true, 18)
	rib.mouse_filter = Control.MOUSE_FILTER_PASS
	rib.tooltip_text = String(R["desc"])
	var rh := HBoxContainer.new()
	rh.add_theme_constant_override("separation", 8)
	rh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rh.add_child(_title("%s. %s" % [Legion.roman(view_r + 1), R["name"]], 22))
	if vc > 0 or int(fr["cycle"]) > 0:
		rh.add_child(_l("· поход %s" % Legion.roman(vc + 1), 16, true, C_SOFT))
	if lg.stage_open(vc, view_r, 0):
		var sn := lg.region_stars(vc, view_r)
		var sc := Stars.new(1, 18.0, 1)
		sc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rh.add_child(sc)
		rh.add_child(_l("%d/%d" % [sn, Legion.STAGES * 3], 17, true, C_GOLD if sn >= Legion.STAGES * 3 else C_INK))
		var trn := String(R.get("trophy", ""))
		rib.tooltip_text += "
Звёзды провинции: %d из %d. За все — сундук Славы%s" % [sn, Legion.STAGES * 3,
			(" и трофей «%s» в город" % String(Defs.B[trn]["name"])) if vc == 0 and trn != "" and Defs.B.has(trn) else ""]
	rib.add_child(rh)
	_pin(rib, Vector2(0.5, 0.0), Vector2(0, -8))
	m.add_child(rib)
	# провинция закрыта
	var lock := ""
	if not lg.region_rank_ok(view_r):
		lock = lg.region_lock_text(view_r) + ". Пока растите город — и прокачивайте бойцов в прошлых провинциях."
	elif not lg.stage_open(vc, view_r, 0):
		var pr: Dictionary = Legion.REGIONS[maxi(0, view_r - 1)]
		lock = "Сначала пройдите «%s»: победите босса — %s." % [pr["name"], Legion.ENEMIES[pr["boss"]]["name"]]
	if lock != "":
		var dim := ColorRect.new()
		dim.color = Color(0.16, 0.1, 0.05, 0.38)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_child(dim)
		var lp := _bar_panel(10)
		lp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lh := HBoxContainer.new()
		lh.add_theme_constant_override("separation", 10)
		lh.add_child(_tr(_ic39("lock"), 64))
		lh.add_child(_wl(lock, 330, 17, C_INK, true))
		lp.add_child(lh)
		_pin(lp, Vector2(0.5, 0.5))
		lp.offset_top = 30
		lp.offset_bottom = 30
		m.add_child(lp)
	return frame


func _stage_btn(c: int, r: int, s: int, boss: bool, front: bool) -> Button:
	var open := lg.stage_open(c, r, s)
	var done := lg.stage_done(c, r, s)
	var R: Dictionary = Legion.REGIONS[r]
	var tip := ""
	if boss:
		tip = "Босс: %s" % Legion.ENEMIES[R["boss"]]["name"]
	else:
		tip = "Бой %s" % Legion.roman(s + 1)
		var th := String((Legion.FIXED.get("%d-%d" % [r, s], {}) as Dictionary).get("name", ""))
		if th != "":
			tip += " «%s»" % th
	tip += " — " + ("пройден" if done else ("следующий" if open else "ещё закрыт"))
	if boss:
		var sz := 76.0
		var face := _portrait("enemy", String(R["boss"]), sz, not open)
		return _pic_btn(face, sz, tip, Callable())
	var sz := 44.0
	var b := Button.new()
	b.custom_minimum_size = Vector2(sz, sz)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	var st := "medal_on" if front else ("medal" if open else "medal_lock")
	b.add_theme_stylebox_override("normal", hud._medal(st, sz))
	b.add_theme_stylebox_override("hover", hud._medal("medal_on" if front else ("medal_hover" if open else "medal_lock"), sz))
	b.add_theme_stylebox_override("pressed", hud._medal("medal_on", sz))
	b.add_theme_stylebox_override("hover_pressed", hud._medal("medal_on", sz))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var l := _title(Legion.roman(s + 1), 19 if s < 8 else 16, C_INK if open else Color(C_INK, 0.45))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(l)
	return b


## Под картой — все провинции (портреты боссов): щелчок открывает карту провинции
func _region_strip() -> Control:
	var fr := lg.frontier()
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 2)
	for r in Legion.REGIONS.size():
		var R: Dictionary = Legion.REGIONS[r]
		var rr := r
		var reached := lg.stage_open(view_c, r, 0) or lg.region_done(view_c, r)
		var done := lg.region_done(view_c, r)
		var v := VBoxContainer.new()
		v.custom_minimum_size = Vector2(98, 0)
		v.add_theme_constant_override("separation", 0)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(98, 58)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if r == view_r:
			var gl := _glow(84)
			gl.position = Vector2(7, -13)
			holder.add_child(gl)
		var face := _portrait("enemy", String(R["boss"]), 56, not reached)
		var tip := "%s\n%s" % [R["name"], R["desc"]]
		if not lg.region_rank_ok(r):
			tip += "\n" + lg.region_lock_text(r)
		elif done:
			tip += "\nПройдена: босс побеждён"
		var b := _pic_btn(face, 56, tip, func(): view_r = rr; sel = {}; _rebuild())
		b.position = Vector2(21, 1)
		b.size = Vector2(56, 56)
		holder.add_child(b)
		if done:
			var ck := _tr(hud.ico("check", 64), 22)
			ck.position = Vector2(64, 36)
			ck.size = Vector2(22, 22)
			holder.add_child(ck)
		elif not reached:
			var lk := _tr(hud.ico("lock", 64), 20)
			lk.position = Vector2(64, 37)
			lk.size = Vector2(20, 20)
			holder.add_child(lk)
		v.add_child(holder)
		var nl := _wl(String(R["name"]), 96, 13, C_INK if reached else C_SOFT, true, true)
		v.add_child(nl)
		h.add_child(v)
	# круг похода (после первого круга — можно смотреть прошлые)
	if int(fr["cycle"]) > 0:
		var nc := (view_c + 1) % (int(fr["cycle"]) + 1)
		var cb := _btn("Поход %s" % Legion.roman(view_c + 1), 0, 15, null, "", func(): view_c = nc; sel = {}; _rebuild())
		cb.tooltip_text = "Походы бесконечны: каждый новый круг — враги сильнее, награды больше. Щелчок — другой круг"
		cb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(cb)
	return h


func _stage_card(st: Dictionary) -> Control:
	var p := _bar_panel(8)
	p.custom_minimum_size = Vector2(CARD_W, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var R: Dictionary = Legion.REGIONS[int(st["r"])]
	var boss: bool = st["boss"]
	# заголовок
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 8)
	if boss:
		hh.add_child(_portrait("enemy", String(R["boss"]), 70))
	else:
		var md := Panel.new()
		md.custom_minimum_size = Vector2(56, 56)
		md.add_theme_stylebox_override("panel", hud._medal("medal", 56))
		md.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var nl := _title(Legion.roman(int(st["s"]) + 1), 24)
		nl.set_anchors_preset(Control.PRESET_FULL_RECT)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		md.add_child(nl)
		hh.add_child(md)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if boss:
		tv.add_child(_l("Босс провинции", 15, true, C_SOFT))
		tv.add_child(hud._wrap(_title(String(st["name"]), 23), CARD_W - 110))
	elif String(st.get("theme", "")) != "":
		tv.add_child(hud._wrap(_title(String(st["theme"]), 23), CARD_W - 90))
		tv.add_child(_l("Бой %d из %d · %s" % [int(st["s"]) + 1, Legion.STAGES, String(st["title"])], 14, true, C_SOFT))
	else:
		tv.add_child(_title("Бой %d из %d" % [int(st["s"]) + 1, Legion.STAGES], 24))
		tv.add_child(_l(String(st["title"]), 15, true, C_SOFT))
	if st["done"]:
		var sh := HBoxContainer.new()
		sh.add_theme_constant_override("separation", 6)
		sh.add_child(Stars.new(int(st["stars"]), 17.0))
		sh.add_child(_l("пройден", 14, true, C_GOOD))
		tv.add_child(sh)
	hh.add_child(tv)
	v.add_child(hh)
	v.add_child(_hdiv(12))
	# враги по волнам
	var waves: Array = st["waves"]
	v.add_child(_l("Враги — %d %s" % [waves.size(), Hud._plural(waves.size(), "волна", "волны", "волн")], 16, true))
	for wi in waves.size():
		var wh := HBoxContainer.new()
		wh.add_theme_constant_override("separation", 3)
		var nl := _l("%d" % (wi + 1), 15, true, C_SOFT)
		nl.custom_minimum_size = Vector2(14, 0)
		wh.add_child(nl)
		var groups := {}
		var order: Array = []
		for k in waves[wi]:
			if not groups.has(k):
				groups[k] = 0
				order.append(k)
			groups[k] = int(groups[k]) + 1
		for k: String in order:
			var big: bool = bool(Legion.ENEMIES[k].get("boss", false))
			var sz := 50.0 if big else 42.0
			var holder := Control.new()
			holder.custom_minimum_size = Vector2(sz, sz)
			holder.mouse_filter = Control.MOUSE_FILTER_PASS
			holder.tooltip_text = _enemy_tip(st, k)
			var face := _portrait("enemy", k, sz)
			face.set_anchors_preset(Control.PRESET_FULL_RECT)
			holder.add_child(face)
			if int(groups[k]) > 1:
				_badge(holder, "×%d" % int(groups[k]), Vector2(1, 1), 13)
			wh.add_child(holder)
		v.add_child(wh)
	var tips := lg.tips(st)
	if tips != "":
		v.add_child(_wl(tips, CARD_W - 24, 14, C_SOFT))
	# отряд не под этот бой (пока мест три — загадка на выбор отряда): совет и кнопка «Под бой»
	var hint := lg.squad_hint(st)
	if hint != "":
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		var off := lg.squad_off(st)
		hb.add_child(_wl(hint, CARD_W - (128 if off else 24), 14, C_BAD, true))
		if off:
			var ab := _btn("Под бой", 0, 15, _ic39("battle"), "", func(): lg.use_auto_squad(st))
			ab.tooltip_text = "«Лучший состав» для этого боя"
			ab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hb.add_child(ab)
		v.add_child(hb)
	# три звезды боя: условия; добытые раньше — золотые
	var sm := int(st.get("star_mask", 0))
	var stx := Legion.star_texts(st)
	var sg := GridContainer.new()
	sg.columns = 2
	sg.add_theme_constant_override("h_separation", 5)
	sg.add_theme_constant_override("v_separation", 0)
	for i in 3:
		var on := (sm & (1 << i)) != 0
		var s1 := Stars.new(1 if on else 0, 15.0, 1)
		s1.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sg.add_child(s1)
		sg.add_child(_l(String(stx[i]), 14, on, C_INK if on else C_SOFT))
	sg.tooltip_text = "Звёзды боя: каждая добывается раз и навсегда. Все три — +%d Славы; все 30 звёзд провинции — сундук Славы" % Legion.STAR_GLORY
	sg.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(sg)
	v.add_child(_hdiv(12))
	# шансы
	var rec := int(st["recommended"])
	var lh := HBoxContainer.new()
	lh.add_theme_constant_override("separation", 6)
	lh.add_child(_tr(_ic39("upgrade"), 26))
	lh.add_child(_l("Нужен уровень бойцов: %d" % rec, 16, true))
	v.add_child(lh)
	var est := _odds_est(st)
	var od := lg.odds(st, est)
	var sq := lg.squad_stats()
	var avg := 0.0
	for u: Dictionary in sq:
		avg += float(u["level"])
	avg = avg / maxf(1.0, sq.size())
	var oh := HBoxContainer.new()
	oh.add_theme_constant_override("separation", 6)
	oh.add_child(_gap(26))
	oh.add_child(_l(("У отряда: %s · " % String.num(avg, 1).replace(".", ",")) if not sq.is_empty() else "", 15, true, C_SOFT))
	var ol := _l(String(od[1]), 15, true, ODDS_COL.get(String(od[0]), C_INK))
	ol.tooltip_text = "Прикидка: %d боёв этим отрядом с «Авто» — как внимательный игрок" % Legion.ODDS_RUNS
	ol.mouse_filter = Control.MOUSE_FILTER_PASS
	oh.add_child(ol)
	v.add_child(oh)
	if est.is_empty() and not sq.is_empty():
		_live.append({"kind": "odds", "label": ol, "st": st})
	# награда и провиант
	var first: bool = st["first"]
	var rw := Legion.reward_for(st, first)
	var rh := HBoxContainer.new()
	rh.add_theme_constant_override("separation", 5)
	rh.add_child(_l("Награда:", 16, true))
	rh.add_child(_tr(hud.ico("coins", 64), 24))
	rh.add_child(_l(hud.fmt(float(rw["money"])), 16, true))
	rh.add_child(_tr(_ic39("glory"), 26))
	rh.add_child(_l(str(int(rw["glory"])), 16, true))
	if rw.has("rp"):
		rh.add_child(_tr(hud.ico("research", 64), 24))
		rh.add_child(_l(str(int(rw["rp"])), 16, true))
	v.add_child(rh)
	if first and not st["done"]:
		v.add_child(_l("Первая победа — награда ×2,5", 14, true, C_GOOD))
	elif st["done"]:
		v.add_child(_l("Повтор: награда меньше, рейтинг +1", 14, true, C_SOFT))
	var fh := HBoxContainer.new()
	fh.add_theme_constant_override("separation", 5)
	fh.add_child(_l("Провиант в поход:", 15, true, C_SOFT))
	fh.add_child(_tr(hud.ico("coins", 64), 22))
	var food := lg.food_cost(st)
	fh.add_child(_l(hud.fmt(food), 15, true, C_INK if food <= game.city.money else C_BAD))
	v.add_child(fh)
	v.add_child(_hdiv(12))
	# отряд
	var qh := HBoxContainer.new()
	qh.add_theme_constant_override("separation", 3)
	qh.add_child(_l("Отряд:", 15, true, C_SOFT))
	if sq.is_empty():
		qh.add_child(_l("никого", 15, true, C_BAD))
	for u: Dictionary in sq:
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(36, 36)
		holder.mouse_filter = Control.MOUSE_FILTER_PASS
		holder.tooltip_text = "%s, %d уровень" % [u["name"], int(u["level"])]
		var face := _portrait("unit", String(u["key"]), 36)
		face.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.add_child(face)
		_badge(holder, str(int(u["level"])), Vector2(1, 1), 12)
		qh.add_child(holder)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qh.add_child(sp)
	var eb := _btn("Состав", 0, 15, null, "", func(): _select_tab("troops"))
	eb.tooltip_text = "Кто идёт в бой и в каком порядке — во вкладке «Войска»"
	eb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	qh.add_child(eb)
	v.add_child(qh)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(fill)
	# в бой
	var why := lg.can_fight(st)
	var fb := _btn("Повторить бой" if st["done"] else "В бой!", CARD_W - 30, 24, _ic39("battle"), why, func(): _fight(st))
	fb.add_theme_font_override("font", hud.font_title)
	fb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(fb)
	_fight_btn = fb
	if why != "":
		var wl := _wl(why, CARD_W - 24, 14, C_BAD, true, true)
		v.add_child(wl)
	elif lg.tutorial_battle(st) and lg.squad_off(st) and lg.slots() <= Legion.SQUAD_BASE:
		# старое сохранение: лучник в отряде до первого боя — учебный бой посчитан на трёх легионеров
		v.add_child(_wl("Учебный бой — для трёх легионеров: лучника в лесу некому прикрыть. «Состав» → «Лучший состав».", CARD_W - 24, 13, C_BAD, true, true))
	elif lg.tutorial_battle(st):
		v.add_child(_wl("Учебный бой: в нужный миг подскажем, что нажать.", CARD_W - 24, 13, C_GOOD, true, true))
	else:
		v.add_child(_wl("Отряд дерётся сам; ваше — состав и умения в нужный миг." + ("" if st["done"] else " «Авто» — после первой победы."), CARD_W - 24, 13, C_SOFT, false, true))
	return p


# =====================================================================
#   шансы боя: прикидка прогоном боёв в фоне (Legion.odds_job / odds_run), запоминается
# =====================================================================

var _odds_cache := {}                      # ключ (Legion.odds_key) → {cur, best?, best_types}
var _odds_task := -1                       # идущий расчёт (WorkerThreadPool) или −1
var _odds_key := ""
var _odds_res := {}
var _odds_next := {}                       # задание, ждущее очереди (игрок щёлкнул другой бой)


## Оценка шансов для карточки боя: готовая или {} (тогда расчёт уходит в фон, надпись обновит _tick_live)
func _odds_est(st: Dictionary) -> Dictionary:
	if lg.squad_stats().is_empty():
		return {}
	var key := lg.odds_key(st)
	if _odds_cache.has(key):
		return _odds_cache[key]
	if _odds_task < 0:
		_odds_start(lg.odds_job(st))
	elif _odds_key != key and String(_odds_next.get("key", "")) != key:
		_odds_next = lg.odds_job(st)
	return {}


func _odds_start(job: Dictionary) -> void:
	_odds_key = String(job["key"])
	var j := job.duplicate(true)
	_odds_task = WorkerThreadPool.add_task(func(): _odds_res = Legion.odds_run(j), false, "legion odds")


## Расчёт в фоне закончился: запомнить и взяться за следующий
func _odds_poll() -> void:
	if _odds_task < 0 or not WorkerThreadPool.is_task_completed(_odds_task):
		return
	WorkerThreadPool.wait_for_task_completion(_odds_task)
	_odds_task = -1
	if _odds_cache.size() > 64:
		_odds_cache.clear()
	_odds_cache[_odds_key] = _odds_res
	var nj := _odds_next
	_odds_next = {}
	if not nj.is_empty() and not _odds_cache.has(String(nj["key"])):
		_odds_start(nj)


## Расчёт готов (проверки ждут его перед снимком)
func odds_busy() -> bool:
	_odds_poll()
	return _odds_task >= 0


func _exit_tree() -> void:
	if _odds_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_odds_task)
		_odds_task = -1


## Бой для «Лучшего состава» во «Войсках»: выбранный на карте (пусто — передний край)
func _card_stage() -> Dictionary:
	if sel.is_empty():
		return {}
	return lg.stage_info(int(sel["c"]), int(sel["r"]), int(sel["s"]))


func _enemy_tip(st: Dictionary, k: String) -> String:
	var E: Dictionary = Legion.ENEMIES[k]
	var s := Legion.foe_stats(st, k)
	var tags: Array = []
	for t in E["tags"]:
		if TAGS.has(t):
			tags.append(TAGS[t])
	var extra: Array = []
	if float(E.get("cleave", 0.0)) > 0.0:
		extra.append("бьёт нескольких сразу")
	if bool(E.get("charge", false)):
		extra.append("разбегается и сбивает с ног")
	if int(E.get("bites", 0)) > 0:
		extra.append("кусает троих сразу")
	if String(E.get("shot", "")) == "boulder":
		extra.append("бросает камни")
	if String(E.get("prefer", "")) == "ranged":
		extra.append("сначала бросается на стрелков")
	var t := "%s%s\nЗдоровье %s · урон %s · броня %d" % [E["name"], (" — " + ", ".join(tags)) if not tags.is_empty() else "",
		hud.fmt(float(s["hp"])), hud.fmt(float(s["atk"])), int(s["armor"])]
	if not extra.is_empty():
		var x := ", ".join(extra)
		t += "\n" + x.left(1).to_upper() + x.substr(1)
	return t


# =====================================================================
#   бой: 3D-бой, если он есть; иначе считаем сами и показываем итог
# =====================================================================

func _has_battle_scene() -> bool:
	return not lg.battle_requested.get_connections().is_empty()


func _fight(st: Dictionary) -> void:
	var why := lg.can_fight(st)
	if why != "":
		_say(why)
		return
	if bool(get_meta("pvp_attacking", false)):
		_say("Легион уже выступает на город — дождитесь ответа сервера")
		return
	lg.flags["tut_fought"] = true                # обучение: шаг «первый бой» позади (дальше — «Войска»)
	if _has_battle_scene():
		_pending = {}
		close()
		lg.start_battle(st)
		return
	var setup := lg.make_battle(st)
	var sim := LegionSim.new(setup)
	var res := sim.run(true)
	var out := lg.apply_result(setup, res)
	_show_result(out, setup)


## 3D-бой закрыт: окно снова открыто (бой с городом — итог уходит на сервер)
func _on_battle_closed(out: Dictionary) -> void:
	# итог боя с городом — только если это он (delta ставит лишь apply_pvp_result): итог похода серверу не уходит,
	# даже если ожидание боя с городом зачем-то осталось
	if String(_pending.get("kind", "")) == "pvp" and out.has("delta"):
		var n = _net()
		if n != null and n.has_method("pvp_report"):
			n.pvp_report(_pending, out)
	var was_pvp := out.has("delta") or (out.is_empty() and String(_pending.get("kind", "")) == "pvp")
	_pending = {}
	if was_pvp:
		_pvp_state = "idle"
	if bool(out.get("win", false)) and out.has("next") and not (out["next"] as Dictionary).is_empty() and not lg.flags.has("turn_page"):
		var nx: Dictionary = out["next"]
		sel = {"c": int(nx["cycle"]), "r": int(nx["r"]), "s": int(nx["s"])}
		view_r = int(nx["r"])
		view_c = int(nx["cycle"])
	open("pvp" if was_pvp else "campaign")


func _show_result(out: Dictionary, setup: Dictionary) -> void:
	var pvp := String(setup.get("kind", "")) == "pvp"
	var win_b := bool(out.get("win", false))
	var p := _modal(470)
	var v: VBoxContainer = p.get_child(0)
	var head := _title("Победа!" if win_b else "Поражение", 36, C_GOOD if win_b else C_BAD)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	if pvp:
		var opp: Dictionary = setup.get("opponent", {})
		v.add_child(_wl("Бой с городом «%s»" % opp.get("name", "?"), 420, 17, C_SOFT, true, true))
	else:
		var st: Dictionary = setup["stage"]
		v.add_child(_wl("%s — %s" % [st["title"], st["theme"] if String(st.get("theme", "")) != "" else st["name"]], 420, 17, C_SOFT, true, true))
	var ic := _tr(_ic38("victory" if win_b else "defeat"), 96)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	if win_b and not pvp:
		var sr := Stars.new(int(out.get("stars", 0)), 30.0)
		sr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(sr)
		# какая звезда не далась и почему
		var stg: Dictionary = setup["stage"]
		var sm := int(out.get("star_mask", 0))
		var tx := Legion.star_texts(stg)
		for i in [1, 2]:
			if (sm & (1 << i)) == 0:
				v.add_child(_wl("Нет звезды «%s»: %s" % [tx[i], Legion.star_miss(i, out, stg)], 420, 14, C_BAD, false, true))
		var ch: Dictionary = out.get("chest", {})
		if not ch.is_empty():
			v.add_child(_wl("Все 30 звёзд «%s»! Сундук Славы +%d." % [ch["region"], int(ch["glory"])], 420, 16, C_GOLD, true, true))
	v.add_child(_wl("Вернулись %d из %d бойцов" % [int(out.get("alive", 0)), int(out.get("total", 0))], 420, 16, C_INK, true, true))
	var rw: Dictionary = out.get("reward", {})
	if not rw.is_empty():
		var rh := HBoxContainer.new()
		rh.alignment = BoxContainer.ALIGNMENT_CENTER
		rh.add_theme_constant_override("separation", 6)
		rh.add_child(_tr(_ic38("chest"), 34))
		if rw.has("money"):
			rh.add_child(_tr(hud.ico("coins", 64), 26))
			rh.add_child(_l("+" + hud.fmt(float(rw["money"])), 20, true, C_GOOD))
		if rw.has("glory"):
			rh.add_child(_tr(_ic39("glory"), 28))
			rh.add_child(_l("+%d" % int(rw["glory"]), 20, true, C_GOOD))
		if rw.has("rp"):
			rh.add_child(_tr(hud.ico("research", 64), 26))
			rh.add_child(_l("+%d" % int(rw["rp"]), 20, true, C_GOOD))
		v.add_child(rh)
	if pvp:
		var d := int(out.get("delta", 0))
		v.add_child(_wl("Рейтинг побед: %s%d" % ["+" if d >= 0 else "", d], 420, 18, C_GOOD if d >= 0 else C_BAD, true, true))
	elif int(out.get("rating", 0)) > 0:
		v.add_child(_wl("Рейтинг походов +%d" % int(out["rating"]), 420, 17, C_GOOD, true, true))
	var unl: Array = out.get("unlocks", [])
	if not unl.is_empty():
		v.add_child(_hdiv(14))
		v.add_child(_wl("Открыто: " + ", ".join(unl) + ".", 420, 17, C_INK, true, true))
	if not win_b:
		v.add_child(_hdiv(14))
		v.add_child(_wl("Не беда! Улучшите бойцов во вкладке «Войска», поставьте в отряд тех, кто сильнее против этих врагов, и вовремя жмите умения в бою.", 420, 15, C_SOFT, false, true))
	if not _has_battle_scene():
		v.add_child(_wl("Отряд сражался сам — показ битвы появится позже.", 420, 13, C_SOFT, false, true))
	var bh := HBoxContainer.new()
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	bh.add_theme_constant_override("separation", 12)
	if win_b:
		var nx: Dictionary = out.get("next", {})
		bh.add_child(_btn("Дальше", 180, 20, null, "", func(): _after_win(nx)))
	else:
		bh.add_child(_btn("К войскам", 180, 20, null, "", func(): _close_overlay(); _select_tab("troops")))
		bh.add_child(_btn("Закрыть", 140, 20, null, "", func(): _close_overlay(); _rebuild()))
	v.add_child(bh)
	_rebuild()


## «Дальше» после победы: босс пал — перелистнуть карту, иначе выбрать следующий бой
func _after_win(nx: Dictionary) -> void:
	_close_overlay()
	if tab == "pvp":
		_rebuild()
		return
	if lg.flags.has("turn_page"):
		lg.flags.erase("turn_page")
		_turn_page()
		return
	if not nx.is_empty():
		sel = {"c": int(nx["cycle"]), "r": int(nx["r"]), "s": int(nx["s"])}
		view_r = int(nx["r"])
		view_c = int(nx["cycle"])
	_rebuild()


## Босс побеждён — карта «перелистывается» на следующую провинцию
func _turn_page() -> void:
	var fr := lg.frontier()
	view_r = int(fr["r"])
	view_c = int(fr["cycle"])
	sel = {}
	tab = "campaign"
	_select_tab("campaign")
	if content.get_child_count() > 0:
		var c: Control = content.get_child(0)
		c.modulate.a = 0.0
		c.position.x = 40.0
		var tw := c.create_tween().set_parallel()
		tw.tween_property(c, "modulate:a", 1.0, 0.45)
		tw.tween_property(c, "position:x", 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# =====================================================================
#   окна поверх: итог боя, выбор бойца
# =====================================================================

func _modal(w: float) -> PanelContainer:
	_close_overlay()
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.06, 0.03, 0.42)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", hud._box_scroll_v(18))
	p.custom_minimum_size = Vector2(w, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	_pin(p, Vector2(0.5, 0.5))
	overlay.add_child(p)
	return p


func _center_later(p: Control) -> void:
	await get_tree().process_frame
	if is_instance_valid(p):
		p.reset_size()
		p.position = ((size - p.size) / 2.0).floor()


func _close_overlay() -> void:
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null


## Выбор бойца на место i (which: "campaign" — отряд похода, "defense" — отряд обороны)
func _pick_unit(i: int, which: String, at: Control) -> void:
	_close_overlay()
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			_close_overlay())
	add_child(overlay)
	var p := _bar_panel(8)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	v.add_child(_l("Место %d: кто встанет?" % (i + 1), 16, true))
	var cur: Array = lg.squad if which == "campaign" or lg.defense.is_empty() else lg.defense
	for t: String in Legion.UNIT_IDS:
		var U: Dictionary = Legion.UNITS[t]
		var ok := lg.available(t)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var face := _portrait("unit", t, 44, not ok)
		face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(face)
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", -3)
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.add_child(_l("%s · %d ур." % [U["name"], int(lg.levels.get(t, 1))], 16, true, C_INK if ok else C_SOFT))
		var sub := ("Силён против: " + String(U["strong"])) if ok else lg.unit_lock_text(t)
		tv.add_child(_wl(sub, 290, 13, C_SOFT))
		h.add_child(tv)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(380, 62)
		b.disabled = not ok
		if i < cur.size() and String(cur[i]) == t:
			b.add_theme_stylebox_override("normal", hud._box_pill(16, 6, "g_btn_on"))
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 12
		h.offset_right = -12
		b.add_child(h)
		var tt := t
		b.pressed.connect(func(): _set_slot(which, i, tt); _close_overlay())
		v.add_child(b)
	var eb := _btn("Оставить место пустым", 380, 15, null, "", func(): _set_slot(which, i, ""); _close_overlay())
	v.add_child(eb)
	overlay.add_child(p)
	p.reset_size()
	var r := at.get_global_rect()                    # уже с масштабом окна
	var gp := get_global_transform().affine_inverse() * r.position
	var gs := r.size
	var pos := Vector2(gp.x + gs.x / 2.0 - p.size.x / 2.0, gp.y + gs.y + 6.0)
	if pos.y + p.size.y > size.y - 8.0:
		pos.y = gp.y - p.size.y - 6.0
	p.position = Vector2(clampf(pos.x, 8.0, size.x - p.size.x - 8.0), clampf(pos.y, 8.0, size.y - p.size.y - 8.0))


func _set_slot(which: String, i: int, t: String) -> void:
	if which == "defense":
		lg.set_defense_slot(i, t)
	else:
		lg.set_slot(i, t)


# =====================================================================
#   «Войска»
# =====================================================================

func _build_troops() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(_squad_panel("campaign"))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 10)
	for t: String in Legion.UNIT_IDS:
		cards.add_child(_unit_card(t))
	v.add_child(cards)
	v.add_child(_perks_panel())
	return v


## Отряд: места по порядку (первые — впереди строя), запертые места — после боссов
func _squad_panel(which: String) -> Control:
	var p := _bar_panel(6)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	info.custom_minimum_size = Vector2(240 if which == "campaign" else 0, 0)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if which == "campaign":
		info.add_child(_title("Отряд в походе", 22))
		info.add_child(_l("Сила отряда: %s" % hud.fmt(lg.squad_power()), 16, true, C_INK))
		info.add_child(_wl("Щелчок по месту — выбрать бойца. Легионеры всегда впереди, лучники за ними, машины в тылу.", 236, 13, C_SOFT))
		h.add_child(info)
	h.add_child(_slots_row(which, SLOT if which == "campaign" else 50.0))
	if which == "campaign":
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(sp)
		var b := _btn("Лучший состав", 0, 17, _ic39("battle"), "", func(): lg.use_auto_squad(_card_stage()))
		b.tooltip_text = "Собрать отряд под выбранный бой: впереди легионеры и копейщики, за ними лучники, в тылу машины. Пока мест три — под врага: против пращников — с лучником, против волков — три легионера"
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(b)
	return p


func _slots_row(which: String, sz: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var src: Array = lg.squad if which == "campaign" or lg.defense.is_empty() else lg.defense
	var n := lg.slots()
	for i in Legion.SQUAD_MAX:
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(sz, sz)
		if i >= n:
			var lk := Panel.new()
			lk.custom_minimum_size = Vector2(sz, sz)
			lk.set_anchors_preset(Control.PRESET_FULL_RECT)
			lk.add_theme_stylebox_override("panel", hud._medal("medal_lock", sz))
			var li := _tr(hud.ico("lock", 64), sz * 0.42)
			li.set_anchors_preset(Control.PRESET_CENTER)
			li.position = Vector2(sz * 0.29, sz * 0.29)
			li.size = Vector2(sz * 0.42, sz * 0.42)
			lk.add_child(li)
			lk.mouse_filter = Control.MOUSE_FILTER_PASS
			var nb: int = int(Legion.SLOT_BOSSES[clampi(i - Legion.SQUAD_BASE, 0, Legion.SLOT_BOSSES.size() - 1)])
			lk.tooltip_text = "Место откроется после победы над боссом: %s" % Legion.boss_name(nb)
			holder.add_child(lk)
			row.add_child(holder)
			continue
		var t: String = String(src[i]) if i < src.size() else ""
		var face: Control
		var tip := ""
		if t != "" and Legion.UNITS.has(t):
			face = _portrait("unit", t, sz, not lg.available(t))
			tip = "%s, %d уровень%s\nЩелчок — поставить другого" % [Legion.UNITS[t]["name"], int(lg.levels.get(t, 1)), "" if lg.available(t) else "\n" + lg.unit_lock_text(t)]
		else:
			var e := Panel.new()
			e.add_theme_stylebox_override("panel", hud._medal("medal", sz))
			var pl := _title("+", sz * 0.5, C_SOFT)
			pl.set_anchors_preset(Control.PRESET_FULL_RECT)
			pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			e.add_child(pl)
			face = e
			tip = "Пустое место — щелчок, чтобы поставить бойца"
		var ii := i
		var b := _pic_btn(face, sz, tip, Callable())
		b.pressed.connect(func(): _pick_unit(ii, which, b))
		b.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.add_child(b)
		if t != "" and Legion.UNITS.has(t):
			_badge(holder, str(int(lg.levels.get(t, 1))), Vector2(1, 1), 13)
		row.add_child(holder)
	return row


func _unit_card(t: String) -> Control:
	var U: Dictionary = Legion.UNITS[t]
	var ok := lg.available(t)
	var p := _bar_panel(6)
	p.custom_minimum_size = Vector2(220, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var face := _portrait("unit", t, 84, not ok)
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(face)
	var nm := _title(String(U["name"]), 22)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nm)
	var info := lg.upgrade_info(t)
	var lv := HBoxContainer.new()
	lv.alignment = BoxContainer.ALIGNMENT_CENTER
	lv.add_theme_constant_override("separation", 4)
	lv.add_child(_l("Уровень %d" % int(info["cur"]), 18, true, C_INK if ok else C_SOFT))
	var lim := _l("из %d" % int(info["limit"]), 14, true, C_SOFT)
	lim.tooltip_text = "Предел уровня от величины города (и пройденных кругов походов)"
	lim.mouse_filter = Control.MOUSE_FILTER_PASS
	lv.add_child(lim)
	v.add_child(lv)
	var role := _wl(String(U["role"]), 204, 13, C_SOFT, false, true)
	role.custom_minimum_size.y = 36
	v.add_child(role)
	# числа: сейчас → после улучшения
	var cur := lg.stats(t)
	var nxt := Legion.unit_stats(t, int(info["to"]), lg.bonus("atk"), lg.bonus("hp"))
	var show_next := ok and not bool(info["max"]) and not bool(info["blocked"])
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 0)
	g.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	g.add_child(_stat("medic", "Здоровье", float(cur["hp"]), float(nxt["hp"]), show_next))
	g.add_child(_stat("swords", "Урон за удар", float(cur["atk"]), float(nxt["atk"]), show_next))
	g.add_child(_stat("shield", "Броня: часть урона гасится", float(cur["armor"]), float(nxt["armor"]), show_next))
	var rng := float(U["range"])
	var rl := HBoxContainer.new()
	rl.add_theme_constant_override("separation", 3)
	rl.add_child(_tr(hud.ico("arrow", 64), 20))
	rl.add_child(_l("вблизи" if rng < 3.0 else "%s м" % String.num(rng, 0), 15, true))
	rl.tooltip_text = "Дальность удара"
	rl.mouse_filter = Control.MOUSE_FILTER_PASS
	g.add_child(rl)
	v.add_child(g)
	var strong := _wl("Силён против: " + String(U["strong"]), 204, 13, C_INK, true, true)
	v.add_child(strong)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(fill)
	v.add_child(_hdiv(10))
	# улучшение — одна кнопка
	var b: String = String(U["building"])
	if not ok:
		var lt := lg.unit_lock_text(t)
		var lh := HBoxContainer.new()
		lh.add_theme_constant_override("separation", 6)
		lh.add_child(_tr(_ic39("barracks" if b == "barracks" else ("range" if b == "range" else "siege")), 36, true))
		lh.add_child(_wl(lt, 160, 13, C_SOFT, true))
		v.add_child(lh)
		if game.city.unlocked(b):
			var bb := _btn("Построить", 190, 16, hud.ico("hammer", 64), "", func(): close(); hud.select_build(b))
			bb.tooltip_text = "%s: %s" % [Defs.B[b]["name"], Defs.B[b].get("desc", "")]
			bb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			v.add_child(bb)
	elif lg.upg.has(t):
		var tl := _l("До %d уровня: %s" % [int(lg.upg[t]["to"]), Legion.fmt_duration(lg.upgrade_left(t))], 15, true, C_INK)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(tl)
		var bar := _bar(196, lg.upgrade_progress(t))
		bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(bar)
		v.add_child(_wl("Тренировка идёт и когда игра закрыта", 204, 12, C_SOFT, false, true))
		_live.append({"kind": "upg", "type": t, "label": tl, "bar": bar})
	elif bool(info["max"]):
		v.add_child(_wl("Наивысший уровень!", 204, 15, C_GOOD, true, true))
	else:
		var why := lg.can_upgrade(t)
		if bool(info["blocked"]):
			v.add_child(_wl(why, 204, 13, C_SOFT, true, true))
		else:
			var ch := HBoxContainer.new()
			ch.alignment = BoxContainer.ALIGNMENT_CENTER
			ch.add_theme_constant_override("separation", 8)
			ch.add_child(_cost_row(info["cost"], 15))
			var th := HBoxContainer.new()
			th.add_theme_constant_override("separation", 2)
			th.add_child(_tr(_ic39("timer"), 22))
			th.add_child(_l(Legion.fmt_duration(float(info["time"])), 15, true, C_SOFT))
			ch.add_child(th)
			v.add_child(ch)
			var ub := _btn("Улучшить до %d" % int(info["to"]), 196, 17, _ic39("upgrade"), why, func(): _do("upgrade", t))
			ub.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			v.add_child(ub)
			if t == "legionary":
				_upg_btn = ub
			if why != "":
				v.add_child(_wl(why, 204, 12, C_BAD, true, true))
	return p


func _stat(icon: String, tip: String, a: float, b: float, show_next: bool) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	h.tooltip_text = tip
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(_tr(hud.ico(icon, 64), 20))
	h.add_child(_l(hud.fmt(a), 15, true))
	if show_next and roundi(b) != roundi(a):
		h.add_child(_l("→" + hud.fmt(b), 13, true, C_GOOD))
	return h


## Умения в бою: открываются боссами, усиливаются за Славу
func _perks_panel() -> Control:
	var p := _bar_panel(6)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 10)
	hh.add_child(_title("Умения в бою", 21))
	var hint := _l("кнопки внизу экрана боя: жмите, когда готовы. Открываются победами над боссами, сильнее — за Славу", 14, true, C_SOFT)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hh.add_child(hint)
	v.add_child(hh)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for id: String in Legion.PERK_IDS:
		var P: Dictionary = Legion.PERKS[id]
		var lvl := int(lg.perks.get(id, 0))
		var h := HBoxContainer.new()
		h.custom_minimum_size = Vector2(218, 0)
		h.add_theme_constant_override("separation", 6)
		h.tooltip_text = "%s\n%s\nПерезарядка %d с" % [P["name"], P["desc"], int(P["cd"])]
		h.mouse_filter = Control.MOUSE_FILTER_PASS
		h.add_child(_portrait("perk", id, 56, lvl <= 0))
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 0)
		tv.add_child(_l(String(P["name"]), 16, true, C_INK if lvl > 0 else C_SOFT))
		if lvl > 0:
			tv.add_child(_l("ур. %d из %d · %d с" % [lvl, Legion.PERK_MAX, int(P["cd"])], 13, true, C_SOFT))
			var why := lg.can_upgrade_perk(id)
			if lvl >= Legion.PERK_MAX:
				tv.add_child(_l("наивысший", 13, true, C_GOOD))
			else:
				var ii := id
				var b := _btn("+1 за %d" % lg.perk_cost(id), 0, 14, _ic39("glory"), why, func(): _do("perk", ii))
				b.custom_minimum_size = Vector2(120, 30)
				tv.add_child(b)
		else:
			tv.add_child(_wl("после победы: %s" % Legion.boss_name(int(P["boss"])), 150, 12, C_SOFT, true))
		h.add_child(tv)
		row.add_child(h)
	v.add_child(row)
	return p


# =====================================================================
#   «Против городов»
# =====================================================================

## Сеть боёв с городами — отдельный модуль. Ищем объект с pvp_opponents: Account.me() или scripts/legion_net.gd
func _net():
	if _net_checked:
		return _net_obj
	_net_checked = true
	var a = Account.me()
	if a != null and a.has_method("pvp_opponents"):
		_net_obj = a
		return a
	var path := "res://scripts/legion_net.gd"
	if ResourceLoader.exists(path):
		var s := load(path) as Script
		if s != null:
			for m: Dictionary in s.get_script_method_list():
				if String(m["name"]) == "me":
					_net_obj = s.call("me")
					return _net_obj
			var o = s.new()
			if o is Node:
				add_child(o)
			_net_obj = o
	return _net_obj


func _net_ready() -> bool:
	var n = _net()
	if n == null or not n.has_method("pvp_opponents"):
		return false
	return not n.has_method("pvp_ready") or bool(n.pvp_ready())


func _load_opponents() -> void:
	var n = _net()
	_pvp_state = "loading"
	_pvp_err = ""
	n.pvp_opponents(func(list, err):
		_pvp_list = list if list is Array else []
		_pvp_err = String(err)
		_pvp_state = "error" if _pvp_err != "" else "ok"
		_pvp_fail = (n.last_fail as Dictionary).duplicate() if _pvp_err != "" and "last_fail" in n else {}
		if _pvp_state == "error" and not _pvp_auto and is_inside_tree():
			# связь могла мигнуть — один раз пробуем снова сами, через 5 секунд
			_pvp_auto = true
			_pvp_auto_wait = true
			get_tree().create_timer(5.0).timeout.connect(_pvp_retry_auto)
		if visible and tab == "pvp":
			_rebuild())


func _pvp_retry_auto() -> void:
	_pvp_auto_wait = false
	if visible and tab == "pvp" and _pvp_state == "error":
		_load_opponents()
		_rebuild()


func _build_pvp() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	# слева: рейтинг, атаки, отряд обороны
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(400, 0)
	left.add_theme_constant_override("separation", 8)
	var rp := _bar_panel(8)
	var rh := HBoxContainer.new()
	rh.add_theme_constant_override("separation", 12)
	rh.add_child(_tr(_ic39("rating"), 76))
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 0)
	rv.add_child(_l("Рейтинг побед над городами", 15, true, C_SOFT))
	rv.add_child(_title(hud.fmt(lg.pvp_rating), 38))
	rv.add_child(_l("Побед %d · поражений %d" % [lg.pvp_wins, lg.pvp_losses], 15, true, C_INK))
	rh.add_child(rv)
	var rbox := VBoxContainer.new()
	rbox.add_theme_constant_override("separation", 4)
	rbox.add_child(rh)
	if _net_ready():
		LegionPvpView.me_rows(self, rbox, _net())       # название города в боях, отбитые нападения
	rp.add_child(rbox)
	left.add_child(rp)
	var ap := _bar_panel(8)
	var av := VBoxContainer.new()
	av.add_theme_constant_override("separation", 4)
	var ah := HBoxContainer.new()
	ah.add_theme_constant_override("separation", 2)
	var n := lg.pvp_charges_now()
	for i in int(Legion.PVP["charges"]):
		ah.add_child(_tr(_ic39("attack"), 40, i >= n))
	av.add_child(ah)
	var cl := _l("", 15, true, C_INK)
	av.add_child(cl)
	_live.append({"kind": "pvp", "label": cl})
	av.add_child(_wl("Одна атака копится полчаса. Добычу ни у кого не отнимают: денарии и Слава — награда за смелость.", 370, 13, C_SOFT))
	ap.add_child(av)
	left.add_child(ap)
	var dp := _bar_panel(8)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 4)
	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", 8)
	dh.add_child(_tr(_ic39("defend"), 40))
	var dtv := VBoxContainer.new()
	dtv.add_theme_constant_override("separation", -2)
	dtv.add_child(_title("Отряд обороны", 21))
	dtv.add_child(_l("Сила: %s" % hud.fmt(lg.squad_power("defense")), 15, true, C_INK))
	dh.add_child(dtv)
	dv.add_child(dh)
	var same := CheckBox.new()
	same.text = "Как отряд похода"
	same.focus_mode = Control.FOCUS_NONE
	same.button_pressed = lg.defense.is_empty()
	same.add_theme_font_size_override("font_size", 16)
	same.toggled.connect(func(on: bool):
		if on:
			lg.defense = []
		else:
			lg.defense = lg.squad.duplicate()
		lg.changed.emit())
	dv.add_child(same)
	dv.add_child(_slots_row("defense", 46.0))
	dv.add_child(_wl("Его видят другие игроки, когда нападают на ваш город. Бой и тут идёт сам.", 370, 13, C_SOFT))
	dp.add_child(dv)
	left.add_child(dp)
	h.add_child(left)
	# справа: соперники и летопись
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	var op := _bar_panel(8)
	op.size_flags_vertical = Control.SIZE_EXPAND_FILL
	op.add_child(_opponents())
	right.add_child(op)
	var lp := _bar_panel(8)
	lp.custom_minimum_size = Vector2(0, 196)
	lp.add_child(_pvp_log())
	right.add_child(lp)
	h.add_child(right)
	return h


func _opponents() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	if not _net_ready():
		# сервера боёв пока нет — объясняем, что будет
		var hh := HBoxContainer.new()
		hh.add_theme_constant_override("separation", 14)
		hh.add_child(_tr(_ic39("attack"), 110))
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 6)
		tv.add_child(_title("Бои с городами — скоро", 26))
		tv.add_child(_wl("Здесь ваш легион сможет нападать на отряды обороны других игроков сайта. Отряд дерётся сам, как в походе. Победа поднимает рейтинг побед и приносит денарии и Славу — ни у кого ничего не отнимается.", 540, 16, C_INK))
		tv.add_child(_wl("Уже сейчас соберите отряд обороны слева: его увидят те, кто нападёт на ваш город. Рейтинг побед открывает старшие чудеса света.", 540, 15, C_SOFT))
		var n = _net()
		if n != null and n.has_method("signed_in") and not bool(n.signed_in()):
			tv.add_child(_wl("Чтобы сражаться с другими городами, войдите в аккаунт (Меню → Настройки).", 540, 15, C_BAD, true))
		hh.add_child(tv)
		v.add_child(_gap(0, 30))
		v.add_child(hh)
		return v
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var t := _title("Соперники", 24)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(_l("ваш отряд: сила %s" % hud.fmt(lg.squad_power()), 15, true, C_SOFT))
	top.add_child(_btn("Найти других", 0, 15, hud.ico("redo", 64), "", func(): _load_opponents(); _rebuild()))
	if _net().has_method("pvp_top"):
		top.add_child(_btn("Лучшие города", 0, 15, _ic39("trophy"), "", func(): LegionPvpView.top(self)))
	v.add_child(top)
	if _pvp_state == "idle":
		_load_opponents.call_deferred()
		_pvp_state = "loading"
	if _pvp_state == "loading":
		v.add_child(_wl("Ищем соперников вашей силы…", 600, 17, C_SOFT, true))
		return v
	if _pvp_state == "error":
		var f := _pvp_fail if not _pvp_fail.is_empty() else {"title": "Соперников найти не вышло", "text": _pvp_err}
		LegionPvpView.error_block(self, v, f, func(): _load_opponents(); _rebuild(), "пробуем снова сами…" if _pvp_auto_wait else "")
		return v
	if _pvp_list.is_empty():
		v.add_child(_wl("Пока некого атаковать — загляните позже.", 600, 17, C_SOFT, true))
		return v
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(0, 300)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	sc.add_child(list)
	var mine := lg.squad_power()
	var why := lg.pvp_can_attack()
	for o in _pvp_list:
		if not (o is Dictionary):
			continue
		var opp: Dictionary = o
		var row: PanelContainer = hud._chip(false, 10)
		var rh := HBoxContainer.new()
		rh.add_theme_constant_override("separation", 10)
		var lvl := clampi(int(opp.get("city_level", 0)), 0, Defs.LEVELS.size() - 1)
		var bot := bool(opp.get("bot", false))
		rh.add_child(_tr(hud.ico("huts" if bot else "castle", 64), 40))
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", -2)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(_l(String(opp.get("name", "?")), 18, true))
		var sub := _l("%s · рейтинг %s" % ["вольный город" if bot else Defs.LEVELS[lvl]["name"], hud.fmt(float(opp.get("rating", 0)))], 14, true, C_SOFT)
		if bot:
			sub.tooltip_text = "Город без хозяина: его отряд собрал сервер. Рейтинга за него вдвое меньше"
			sub.mouse_filter = Control.MOUSE_FILTER_PASS
		tv.add_child(sub)
		rh.add_child(tv)
		LegionPvpView.squad_strip(self, rh, opp.get("snapshot", {}))
		var pw := Legion.snapshot_power(opp.get("snapshot", {}))
		var col := C_GOOD if pw < mine * 0.9 else (C_GOLD if pw <= mine * 1.15 else C_BAD)
		var pl := _l("сила %s" % hud.fmt(pw), 16, true, col)
		pl.tooltip_text = "Сила их отряда обороны. Ваш отряд: %s" % hud.fmt(mine)
		pl.mouse_filter = Control.MOUSE_FILTER_PASS
		pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rh.add_child(pl)
		var ab := _btn("Напасть", 140, 17, _ic39("attack"), why, func(): _attack(opp))
		ab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rh.add_child(ab)
		row.add_child(rh)
		list.add_child(row)
	v.add_child(sc)
	return v


func _attack(opp: Dictionary) -> void:
	var why := lg.pvp_can_attack()
	if why != "":
		_say(why)
		return
	var nt = _net()
	if nt != null and nt.has_method("pvp_attack") and not opp.has("battle"):
		# сначала сервер: тратит заряд, даёт номер боя и свежий отряд соперника (LegionNet.pvp_attack)
		if bool(get_meta("pvp_attacking", false)):
			return
		set_meta("pvp_attacking", true)
		_say("Легион выступает…")
		nt.pvp_attack(opp, func(o2: Dictionary, err: String):
			set_meta("pvp_attacking", false)
			# ответ опоздал: окно закрыто или уже идёт другой бой — этот бой не начинаем (на сервере он просто истечёт)
			if not visible or (LegionBattle.current != null and is_instance_valid(LegionBattle.current)):
				return
			if err != "":
				_say(err)
				if err.contains("обновите") or err.contains("выберите другой") or err.contains("недавно"):
					_pvp_state = "idle"          # список устарел — взять свежий
					_rebuild()
				return
			_attack(o2))
		return
	if _has_battle_scene():
		close()
		_pending = lg.start_pvp_battle(opp)
		# бой мог и не открыться (уже идёт другой — тот, что у LegionBattle.current) — тогда и ждать нечего
		var b = LegionBattle.current
		if b != null and is_instance_valid(b) and b.setup != _pending:
			_pending = {}
		return
	var setup := lg.make_pvp_battle(opp)
	var sim := LegionSim.new(setup)
	var res := sim.run(true)
	var out := lg.apply_pvp_result(setup, res)
	var n = _net()
	if n != null and n.has_method("pvp_report"):
		n.pvp_report(setup, out)
	_show_result(out, setup)


func _pvp_log() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 8)
	hh.add_child(_tr(_ic39("report"), 30))
	hh.add_child(_title("Летопись боёв", 20))
	v.add_child(hh)
	if lg.pvp_log.is_empty():
		v.add_child(_l("Боёв с городами пока не было.", 15, true, C_SOFT))
		return v
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 140)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	for e in lg.pvp_log:
		if not (e is Dictionary):
			continue
		var d: Dictionary = e
		var win_b := bool(d.get("win", false))
		var att := bool(d.get("attack", true))
		var rh := HBoxContainer.new()
		rh.add_theme_constant_override("separation", 6)
		rh.add_child(_tr(_ic38("victory" if win_b else "defeat"), 24))
		var txt := ""
		if att:
			txt = "Вы напали на «%s»: %s" % [d.get("name", "?"), "победа" if win_b else "поражение"]
		else:
			txt = "На вас напал «%s»: %s" % [d.get("name", "?"), "отбились" if win_b else "отряд не устоял"]
		var dl := int(d.get("delta", 0))
		if bool(d.get("void", false)):
			txt += ", сервер бой не засчитал"
		else:
			txt += ", рейтинг %s%d" % ["+" if dl >= 0 else "", dl]
		if int(d.get("money", 0)) > 0:
			txt += ", добыча %s" % hud.fmt(float(d["money"]))
		if int(d.get("glory", 0)) != 0:
			txt += ", %s%d Славы" % ["+" if int(d["glory"]) > 0 else "−", absi(int(d["glory"]))]
		var l := _l(txt, 15, true, C_INK)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		l.tooltip_text = txt
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		rh.add_child(l)
		rh.add_child(_l(_ago(float(d.get("t", 0.0))), 13, true, C_SOFT))
		list.add_child(rh)
	v.add_child(sc)
	return v


func _ago(t: float) -> String:
	var s := Legion.now() - t
	if s < 90.0:
		return "только что"
	return Legion.fmt_duration(s) + " назад"


# =====================================================================
#   «Чудеса»
# =====================================================================

func _build_wonders() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(_chip_val(_ic39("map"), "Рейтинг походов: %s" % hud.fmt(lg.rating), "Растёт с новыми победами в походах. Открывает Арку, Амфитеатр и Пантеон", 17)[0])
	top.add_child(_chip_val(_ic39("attack"), "Рейтинг побед: %s" % hud.fmt(lg.pvp_rating), "Растёт с победами над другими городами. Открывает старшие чудеса", 17)[0])
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	# Триумф
	var tri: PanelContainer = hud._chip(false, 10)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 8)
	th.add_child(_tr(_ic38("victory"), 36))
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -3)
	tv.add_child(_l("Триумф", 17, true))
	if lg.triumph_left > 0:
		var days := ceili(lg.triumph_left / 24.0)
		tv.add_child(_l("город празднует ещё %d %s: счастье +%d%%" % [days, Hud._plural(days, "день", "дня", "дней"), int(Legion.TRIUMPH["happy"])], 13, true, C_GOOD))
	else:
		tv.add_child(_l("праздник на %d дня: счастье всех домов +%d%%" % [int(Legion.TRIUMPH["hours"]) / 24, int(Legion.TRIUMPH["happy"])], 13, true, C_SOFT))
	th.add_child(tv)
	if lg.triumph_left <= 0:
		var why := lg.can_triumph()
		var tb := _btn("%d" % int(Legion.TRIUMPH["glory"]), 0, 16, _ic39("glory"), why, func(): _do("triumph", ""))
		tb.tooltip_text = "Устроить Триумф за %d Славы" % int(Legion.TRIUMPH["glory"]) if why == "" else why
		tb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		th.add_child(tb)
	tri.add_child(th)
	top.add_child(tri)
	v.add_child(top)
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	for w: Dictionary in Legion.WONDERS:
		g.add_child(_wonder_card(w))
	v.add_child(g)
	return v


func _wonder_card(w: Dictionary) -> Control:
	var id: String = w["id"]
	var state := lg.wonder_state(id)
	var p := _bar_panel(4)
	p.custom_minimum_size = Vector2(277, 0)
	p.tooltip_text = "%s
%s" % [Legion.wonder_name(w), w["bonus"]]
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	p.add_child(v)
	var ph := Control.new()
	ph.custom_minimum_size = Vector2(250, 118)
	ph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := _tr(_wonder_tex(id), 118, state == "locked")
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ph.add_child(pic)
	if state == "built":
		var ck := _tr(hud.ico("check", 64), 32)
		ck.position = Vector2(176, 82)
		ck.size = Vector2(32, 32)
		ph.add_child(ck)
	elif state == "locked":
		var lk := _tr(hud.ico("lock", 64), 28)
		lk.position = Vector2(178, 86)
		lk.size = Vector2(28, 28)
		ph.add_child(lk)
	v.add_child(ph)
	var nm := _wl(Legion.wonder_name(w), 266, 17, C_INK, false, true)
	nm.add_theme_font_override("font", hud.font_title)
	v.add_child(nm)
	var bonus := _wl(String(w["bonus"]), 266, 13, C_SOFT, true, true)
	bonus.custom_minimum_size.y = 34
	v.add_child(bonus)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(fill)
	var pvp := bool(w.get("pvp", false))
	var need := int(w["rating"])
	var have := lg.wonder_rating_now(w)
	var cost := lg.wonder_cost(id)
	if state == "built":
		var bl := _l("Построено — бонус действует", 15, true, C_GOOD)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(bl)
		return p
	if state == "locked":
		# закрыто рейтингом: сколько ещё набрать и сколько будет стоить
		var rl := _l("Рейтинг %s: %s из %s" % ["побед" if pvp else "походов", hud.fmt(have), hud.fmt(need)], 13, true, C_INK)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rl.tooltip_text = "Чудо откроется, когда рейтинг %s дойдёт до %s" % ["побед над городами" if pvp else "походов", hud.fmt(need)]
		rl.mouse_filter = Control.MOUSE_FILTER_PASS
		v.add_child(rl)
		var bar := _bar(220, clampf(float(have) / maxf(1.0, need), 0.0, 1.0))
		bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(bar)
		var ch := HBoxContainer.new()
		ch.alignment = BoxContainer.ALIGNMENT_CENTER
		ch.add_theme_constant_override("separation", 4)
		ch.add_child(_l("цена:", 13, true, C_SOFT))
		ch.add_child(_cost_row(cost, 14))
		v.add_child(ch)
		return p
	var cr := _cost_row(cost, 15)
	cr.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(cr)
	var why := lg.can_build_wonder(id)
	var b: Button
	if w.has("building"):
		var bt: String = w["building"]
		b = _btn("Поставить в городе", 230, 16, hud.ico("hammer", 64), why, func(): close(); hud.select_build(bt))
		if why == "":
			b.tooltip_text = "Окно закроется — выберите место в городе. Слава спишется, когда поставите"
	else:
		b = _btn("Возвести", 230, 16, hud.ico("hammer", 64), why, func(): _do("wonder", id))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)
	return p


# =====================================================================
#   звёзды за бой
# =====================================================================

class Stars extends Control:
	var n := 0
	var star := 12.0
	var of := 3                   # сколько звёзд рисовать (1 — значок у строки условия)

	func _init(count: int, s: float, total := 3) -> void:
		n = count
		star = s
		of = total
		custom_minimum_size = Vector2(s * of + (of - 1) * 2.0, s)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for i in of:
			var c := Vector2(star * 0.5 + i * (star + 2.0), star * 0.5)
			var pts := PackedVector2Array()
			for k in 10:
				var r := star * (0.56 if k % 2 == 0 else 0.25)
				var a := -PI / 2.0 + k * PI / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			var on := i < n
			draw_colored_polygon(pts, Color("f4b93a") if on else Color(0.42, 0.33, 0.24, 0.38))
			pts.append(pts[0])
			draw_polyline(pts, Color("5a3512") if on else Color(0.33, 0.25, 0.18, 0.55), maxf(1.2, star * 0.09), true)


# =====================================================================
#   своя карта провинции, пока владелец не прислал картинку: пергамент, земля, тропа с камнями, лес и скалы
# =====================================================================

class MapPaint extends Control:
	var biome := "forest"
	var seed_v := 1
	var pts: Array = []                   # тропа: точки в координатах картинки (MAP_PX)
	var k := Vector2.ONE                  # картинка → экран
	var icons := {}                       # значок → текстура (деревья, скалы, логово босса)
	var emblem: Texture2D                 # портрет босса — герб провинции в углу, как на рисованных картах
	var _ground: ImageTexture
	var _items: Array = []
	var _blobs: Array = []                # тени под рощами

	## Земля: два слоя шума (тон травы и проплешины земли) — мазками, а не ровной заливкой
	func _make_ground(B: Dictionary) -> void:
		var W := 256
		var H := 144
		var n := FastNoiseLite.new()
		n.seed = seed_v
		n.frequency = 0.03
		n.fractal_octaves = 4
		var n2 := FastNoiseLite.new()
		n2.seed = seed_v + 7
		n2.frequency = 0.07
		n2.fractal_octaves = 2
		var img := Image.create(W, H, false, Image.FORMAT_RGB8)
		var g1: Color = B["ground2"]
		var g2: Color = B["ground"]
		var g3: Color = (B["ground"] as Color).lightened(0.2)
		var dirt: Color = B.get("dirt", Color("bea36a"))
		for y in H:
			for x in W:
				var v := n.get_noise_2d(x, y) * 0.5 + 0.5
				var c := g1.lerp(g2, smoothstep(0.25, 0.55, v)).lerp(g3, smoothstep(0.58, 0.9, v))
				var d := n2.get_noise_2d(x, y)
				if d > 0.32:
					c = c.lerp(dirt, minf(0.7, (d - 0.32) * 1.6))
				img.set_pixel(x, y, c)
		_ground = ImageTexture.create_from_image(img)

	func _draw() -> void:
		var S := size
		var B: Dictionary = LegionUi.BIOMES.get(biome, LegionUi.BIOMES["forest"])
		if _ground == null:
			_make_ground(B)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_v
		var km := (k.x + k.y) * 0.5 * 1.6
		var ground: Color = B["ground"]
		var ground2: Color = B["ground2"]
		# пергамент и рваный край карты
		draw_rect(Rect2(Vector2.ZERO, S), Color("e6cf9b"))
		var inner := Rect2(Vector2(16, 14), S - Vector2(32, 28))
		draw_texture_rect(_ground, inner, false)
		var path := _smooth()
		if _items.is_empty():
			_items = _place_items(B, rng, inner, path)
		var edge := PackedVector2Array()
		var steps := 90
		for i in steps + 1:
			var t := float(i) / steps
			var p: Vector2
			if t < 0.25:
				p = inner.position.lerp(Vector2(inner.end.x, inner.position.y), t * 4.0)
			elif t < 0.5:
				p = Vector2(inner.end.x, inner.position.y).lerp(inner.end, (t - 0.25) * 4.0)
			elif t < 0.75:
				p = inner.end.lerp(Vector2(inner.position.x, inner.end.y), (t - 0.5) * 4.0)
			else:
				p = Vector2(inner.position.x, inner.end.y).lerp(inner.position, (t - 0.75) * 4.0)
			edge.append(p + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3)))
		# травинки
		for i in 700:
			var p := Vector2(rng.randf_range(inner.position.x, inner.end.x), rng.randf_range(inner.position.y, inner.end.y))
			var c: Color = ground2.darkened(0.15) if rng.randf() < 0.5 else ground.lightened(0.3)
			c.a = 0.28
			draw_line(p, p + Vector2(rng.randf_range(-2, 2), -rng.randf_range(3, 7)), c, 1.2, true)
		# холмы
		if bool(B.get("hills", false)):
			for i in 9:
				var p := Vector2(rng.randf_range(inner.position.x, inner.end.x), rng.randf_range(inner.position.y + 20, inner.end.y))
				var r := rng.randf_range(50.0, 95.0) * km
				_ellipse(p + Vector2(r * 0.1, r * 0.16), r, r * 0.42, Color(ground2.darkened(0.3), 0.5))
				_ellipse(p, r * 0.95, r * 0.38, ground.darkened(0.04))
				_ellipse(p - Vector2(r * 0.22, r * 0.12), r * 0.55, r * 0.16, Color(ground.lightened(0.28), 0.7))
		for bl: Array in _blobs:
			_ellipse(bl[0], bl[1], bl[1] * 0.5, Color(ground2.darkened(0.35), 0.32))
		# вода
		match String(B.get("water", "")):
			"river", "stream":
				var w := (24.0 if B["water"] == "river" else 14.0) * km
				var rv := PackedVector2Array()
				for q: Array in [[960, 990], [1060, 830], [1240, 770], [1420, 800], [1560, 720], [1720, 700]]:
					rv.append(Vector2(float(q[0]), float(q[1])) * k)
				var rs := _catmull(rv, 10)
				draw_polyline(rs, Color("8a7a4a"), w + 7.0, true)
				draw_polyline(rs, Color("4f8796"), w + 2.0, true)
				draw_polyline(rs, Color("73adbc"), w * 0.7, true)
				draw_polyline(rs, Color(0.9, 0.97, 1.0, 0.5), w * 0.18, true)
			"ponds", "sea":
				for q: Array in [[1260, 790, 110], [1490, 610, 70], [130, 170, 80], [620, 880, 60], [1050, 120, 55]]:
					var c := Vector2(float(q[0]), float(q[1])) * k
					var r := float(q[2]) * km * 0.6
					for j in 3:
						var o := Vector2(rng.randf_range(-0.5, 0.5) * r, rng.randf_range(-0.25, 0.25) * r)
						_ellipse(c + o, r * 1.12, r * 0.66, Color("6f7b4a"))
					for j in 3:
						var o := Vector2(rng.randf_range(-0.45, 0.45) * r, rng.randf_range(-0.2, 0.2) * r)
						_ellipse(c + o, r, r * 0.56, Color("5e8f8c"))
					_ellipse(c - Vector2(r * 0.3, r * 0.15), r * 0.38, r * 0.1, Color(0.9, 1.0, 1.0, 0.4))
					for j in 7:
						var a := rng.randf_range(0, TAU)
						var rp := c + Vector2(cos(a) * r * 1.05, sin(a) * r * 0.62)
						for h in 3:
							draw_line(rp + Vector2(h * 2.0, 0), rp + Vector2(h * 2.0 + rng.randf_range(-2, 2), -rng.randf_range(6, 11)), Color("55663a"), 1.4, true)
		# тропа
		draw_polyline(path, Color(0.3, 0.2, 0.1, 0.35), 26.0 * k.x * 1.6, true)
		draw_polyline(path, Color("8a6a3c"), 22.0 * k.x * 1.6, true)
		draw_polyline(path, Color("d9b97e"), 16.0 * k.x * 1.6, true)
		for i in range(0, path.size(), 2):
			var p: Vector2 = path[i] + Vector2(rng.randf_range(-6, 6), rng.randf_range(-4, 4)) * k.x * 1.6
			draw_circle(p, rng.randf_range(0.8, 1.6), Color(0.5, 0.38, 0.22, 0.55))
		# площадки боёв: каменное кольцо, как на рисованных картах
		for i in pts.size():
			var p: Vector2 = pts[i] * k
			var big := i == pts.size() - 1
			var rx := (40.0 if big else 22.0) * k.x * 1.6
			_ellipse(p + Vector2(0, rx * 0.2), rx * 1.08, rx * 0.62, Color(0.2, 0.15, 0.1, 0.4))
			_ellipse(p, rx, rx * 0.58, Color("5d564c"))
			_ellipse(p - Vector2(0, rx * 0.05), rx * 0.93, rx * 0.5, Color("bdb6a6"))
			_ellipse(p - Vector2(0, rx * 0.09), rx * 0.72, rx * 0.36, Color("ded3bb"))
		# леса и скалы — рощами, подальше от тропы; логово босса
		for it: Array in _items:
			var tex: Texture2D = icons.get(it[1])
			if tex == null:
				continue
			var p: Vector2 = it[0]
			var s: float = it[2]
			_ellipse(p + Vector2(s * 0.06, -s * 0.03), s * 0.34, s * 0.12, Color(0.12, 0.1, 0.04, 0.3))
			draw_texture_rect(tex, Rect2(p - Vector2(s * 0.5, s * 0.92), Vector2(s, s)), false, it[3])
		# поля пергамента поверх: что торчит за край — уходит «за край карты»
		var pc := Color("e6cf9b")
		draw_rect(Rect2(0, 0, S.x, inner.position.y), pc)
		draw_rect(Rect2(0, inner.end.y, S.x, S.y - inner.end.y), pc)
		draw_rect(Rect2(0, 0, inner.position.x, S.y), pc)
		draw_rect(Rect2(inner.end.x, 0, S.x - inner.end.x, S.y), pc)
		draw_polyline(edge, pc, 9.0, true)
		draw_polyline(edge, Color(0.45, 0.3, 0.13, 0.55), 2.0, true)
		# герб провинции и роза ветров
		if emblem != null:
			var es := 74.0
			draw_texture_rect(emblem, Rect2(inner.position + Vector2(10, 8), Vector2(es, es)), false, Color(0.86, 0.72, 0.52, 0.55))
		var cc := inner.position + Vector2(50, 176)
		var ink := Color(0.42, 0.27, 0.12, 0.6)
		draw_arc(cc, 30.0, 0, TAU, 40, ink, 1.5, true)
		draw_arc(cc, 24.0, 0, TAU, 40, Color(ink, 0.35), 1.0, true)
		for j in 8:
			var a := j * PI / 4.0 - PI / 2.0
			var l := 34.0 if j % 2 == 0 else 20.0
			var tip := cc + Vector2(cos(a), sin(a)) * l
			var side := Vector2(cos(a + PI / 2.0), sin(a + PI / 2.0)) * (5.0 if j % 2 == 0 else 3.5)
			draw_colored_polygon(PackedVector2Array([cc + side, tip, cc - side]), Color(0.42, 0.27, 0.12, 0.55 if j % 2 == 0 else 0.35))
		# края карты темнее
		for i in 8:
			draw_rect(Rect2(inner.position + Vector2(i, i) * 2.5, inner.size - Vector2(i, i) * 5.0), Color(0.3, 0.18, 0.06, 0.045), false, 2.5)

	func _place_items(B: Dictionary, rng: RandomNumberGenerator, inner: Rect2, path: PackedVector2Array) -> Array:
		var out: Array = []
		var deco: Array = B["deco"]
		var tint: Color = B.get("tint", Color.WHITE)
		var u := size.x / 784.0               # размеры — в точках экрана при карте 784 в ширину
		var clear := 30.0 * u
		_blobs = []
		# рощи: центры у краёв и в пустых местах
		var groves := 13
		var tries := 0
		while groves > 0 and tries < 400:
			tries += 1
			var c := Vector2(rng.randf_range(inner.position.x, inner.end.x), rng.randf_range(inner.position.y + 24, inner.end.y))
			if _near(c, path, clear * 1.6):
				continue
			groves -= 1
			var n := rng.randi_range(6, 13)
			var rad := rng.randf_range(40.0, 78.0) * u
			_blobs.append([c, rad * 1.05])
			for j in n:
				var p := c + Vector2(rng.randf_range(-rad, rad), rng.randf_range(-rad * 0.55, rad * 0.55))
				if not inner.grow(-6).has_point(p) or _near(p, path, clear):
					continue
				var nm := String(deco[rng.randi() % deco.size()])
				out.append([p, nm, rng.randf_range(40.0, 54.0) * u * (1.2 if nm == "pine" else 1.0), tint.lerp(Color.WHITE, rng.randf_range(0.0, 0.4))])
		# одиночные деревья и камни
		for j in 26:
			var p := Vector2(rng.randf_range(inner.position.x + 10, inner.end.x - 10), rng.randf_range(inner.position.y + 30, inner.end.y - 4))
			if _near(p, path, clear):
				continue
			out.append([p, String(deco[rng.randi() % deco.size()]), rng.randf_range(32.0, 44.0) * u, tint])
		# логово босса
		var land: Array = B["land"]
		if not pts.is_empty():
			var bp: Vector2 = pts[pts.size() - 1] * k
			for i in land.size():
				var a := -2.5 + i * 0.95
				out.append([bp + Vector2(cos(a) * 1.2, sin(a) * 0.6) * 66.0 * u, String(land[i]), 54.0 * u, Color.WHITE])
		out.sort_custom(func(a, b): return (a[0] as Vector2).y < (b[0] as Vector2).y)
		return out

	func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
		var p := PackedVector2Array()
		for i in 28:
			var a := TAU * i / 28.0
			p.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		draw_colored_polygon(p, col)

	func _smooth() -> PackedVector2Array:
		var raw := PackedVector2Array()
		for p: Vector2 in pts:
			raw.append(p * k)
		return _catmull(raw, 12)

	func _catmull(raw: PackedVector2Array, n: int) -> PackedVector2Array:
		var out := PackedVector2Array()
		if raw.size() < 2:
			return raw
		for i in raw.size() - 1:
			var p0 := raw[maxi(0, i - 1)]
			var p1 := raw[i]
			var p2 := raw[i + 1]
			var p3 := raw[mini(raw.size() - 1, i + 2)]
			for j in n:
				var t := float(j) / n
				var t2 := t * t
				var t3 := t2 * t
				out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
		out.append(raw[raw.size() - 1])
		return out

	func _near(p: Vector2, path: PackedVector2Array, d: float) -> bool:
		var inner := Rect2(Vector2(16, 14), size - Vector2(32, 28))
		if Rect2(inner.position, Vector2(110, 110)).has_point(p):                       # герб
			return true
		if p.distance_to(inner.position + Vector2(50, 176)) < 58.0:                       # роза ветров
			return true
		if Rect2(Vector2(size.x * 0.5 - 170, 0), Vector2(340, 74)).has_point(p):        # лента с названием
			return true
		for q in path:
			if q.distance_squared_to(p) < d * d:
				return true
		for q: Vector2 in pts:
			if (q * k).distance_squared_to(p) < d * d * 2.2:
				return true
		return false
