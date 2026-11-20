class_name Hud
extends CanvasLayer
## Интерфейс в римском духе — рисованный набор владельца (assets/ui/ai): резные рамки с меандром, свитки
## с валиками, бронзовые медальоны с цветными иконками, табличка с орлом и лентой названия города. Устроен как в Town to City:
## сверху слева — город, жители, счастье, время; рядом — три класса жителей; под ними — задания со стрелкой-подсказкой.
## Сверху справа — Легион, герой, исследования, обзор города, фото, меню.
## Снизу: слева — дороги, посередине — разделы стройки (свиток разворачивается с карточками), справа — инструменты, деньги, очки.

var game
var root: Control
var font: Font
var font_bold: Font
var font_title: Font
var theme_main: Theme
var icons := {}                      # картинки построек для карточек
var _ico := {}
var _medals := {}
var _grey_mat: ShaderMaterial

const AI := "res://assets/ui/ai/"     # рисованный интерфейс (иконки, рамки, медальоны, значки)
## Новый интерфейс «пергамент» (2026-11-06, гибрид 1): светлые окна с тонкой коричневой обводкой, медальоны — светлые
## кружки с тонким кольцом; рисуется кодом (art/ui_pa/gen.py, gen_icons.py). Картинки с тем же именем берутся отсюда вместо AI;
## --oldui — прежние бронзовые рамки (сравнить)
const PA := "res://assets/ui/pa/"
## Интерфейс «мрамор» (выбор владельца 11.11.2026): те же рамки, кнопки, медальоны белым мрамором с золотом (art/ui_marble/gen.py);
## картинки с тем же именем берутся отсюда раньше PA. Настройки → «Мраморный интерфейс» (settings.ui_style), --paui — пергамент
const MB := "res://assets/ui/marble/"
static var marble := true
const PA_PAD := 6.0                   # тень вокруг рамок нового интерфейса — за краем панели (expand_margin)
static var old_ui := OS.get_cmdline_user_args().has("--oldui") or OS.get_cmdline_args().has("--oldui")
const CARD := Vector2(128, 176)       # карточка постройки в свитке стройки
const PLATE := Vector2(264, 70)       # табличка с названием города (картинка 640×169)
const TASKS_Y := 54                   # просьбы горожан (и карточка обучения) — под верхней полосой
const BAR_H := 78                     # высота нижних полос (компактнее — отзыв 14.11): окна инструментов встают над ними
const MIN_W := 1440.0                 # интерфейс не крупнее, чем помещается в 1440 точек по ширине: снизу — дороги с «Улучшить» и «Земля»,
                                      # разделы с «Легионом» и инструменты (~1375); сверху — фишки классов и 10 медальонов с «Героем», «Легионом» и облачком (~1430)
const FAM_Y := 54                     # семьи на площади — под верхней полосой, правее свитка просьб
const NOTES_Y := 54                   # всплывашки — под верхней полосой (сдвигаются вправо от значков семей)
const ADV_Y := 70                     # советник — под верхней полосой

const C_INK := Color("4a2c17")
const C_SOFT := Color("7a5a3c")
const C_GOOD := Color("4f7a2a")
const C_BAD := Color("b0402a")
const C_GOLD := Color("c98a1e")
const C_CREAM := Color("fff4dc")
const CARD_ACCENT := Color("7a2230")
const INFO_WIDTH := 340.0
const INFO_BODY := 316.0

var lbl_city: Label
var name_plate: Control               # название города в верхней полосе: в своём городе его можно нажать (окно «Название города»)
var top_row: HBoxContainer            # верхняя полоса целиком
var _renown_on := false               # титул города нужен (показывается, если хватает места, см. _fit_top)
const CITY_FONT := 21                 # размер названия в верхней полосе (длинное — мельче, show_city_name)
const TOP_BTN := 42                   # медальоны сверху справа
const NAME_W := 190.0                 # самое длинное название города по ширине в верхней полосе
var lbl_level: Label
var lbl_pop: Label
var lbl_happy: Label
var lbl_day: Label
var lbl_clock: Label
var save_quill: TextureRect               # перо у часов — идёт сохранение (saving)
var _quill_tw: Tween
var speed_btns := []
var class_box: HBoxContainer
var city_card: Control
var top_panel: Control
var fam_box: HBoxContainer            # семьи на площади ждут жилья (как очередь поезда в Town to City)
var _fam_known := {}
var tasks_box: VBoxContainer
var tasks_panel: PanelContainer
var hover_money: Control
var hover_rp: Control
var _build_menu_key := ""
var lbl_money: Label
var lbl_income: Label
var lbl_rp: Label
var lbl_rp_day: Label
var cats := {}
var top_btns := {}
var bar_left: PanelContainer             # нижние полосы: дороги, разделы стройки, инструменты с казной
var bar_mid: PanelContainer
var bar_right: PanelContainer
var tray: PanelContainer
var tray_grid: HBoxContainer
var tray_stabs: HBoxContainer
var open_ssub := "monuments"
var tray_tabs: HBoxContainer
var tray_title: Label
var open_cat := ""
var _tray_w := 0.0                    # на сколько широк свиток стройки без поправки на окно инструмента
var _tray_h := 0.0
var _tray_key := ""
var open_sub := "food"
var open_dsub := "plants"             # вкладка украшений
var tray_dtabs: HBoxContainer
## Меню украшений (этап 5.4): «Избранное» (★ правой кнопкой по карточке), «Недавние» (8 последних), поиск по названию,
## «Только открытые». decor_mode: "" — вкладка, fav, recent, search. Избранное и недавние — в настройках игрока
var tray_dtools: HBoxContainer
var decor_mode := ""
var decor_query := ""
var decor_search: LineEdit
const RECENT_N := 8
var tool_panel: PanelContainer
var undo_btn: Button                      # медаль «Отменить» в панели постройки (3.6)
var thumb_rect: TextureRect               # живая картинка постройки (3.4)
var color_box: HBoxContainer              # ряд цветов фасада (3.4)
var gate_check: CheckBox                  # забор: калитка посередине
var upg_decor_check: CheckBox             # «Перестроить»: сносить мешающие украшения
const THUMB := Vector2i(220, 140)
var tool_title: Label
var tool_keys: Label
var tool_err: Label
var variant_box: HBoxContainer
var road_panel: PanelContainer
var road_btns := {}
var road_groups := {}                  # три кнопки групп в нижней полосе
var _last_road_tool := "road"
var _last_grass_tool := "grass"
var tool_btns := {}
var info_panel: PanelContainer
var house_more := false                 # карточка дома подробная (две колонки) или короткая (по умолчанию)
var info_box: VBoxContainer
var info_b := {}
var info_p := {}                      # карточка жителя или кошки (PersonCard): {"r": житель} / {"cat": кошка}
var person_tag: Label                 # подпись у курсора над жителем: «Гай Юлий · пекарь»
var lg_upg_btn: Button                    # карточка здания Легиона: «Улучшить — …» (стрелка обучения Легиону, шаг 4)
var _lg_live := {}                        # карточка здания Легиона: полоска и надпись идущего улучшения {key, bar, label}
var _lg_live_t := 0.0
var advisor_panel: PanelContainer
var adv_title: Label
var adv_text: Label
var adv_skip: Button                        # «Пропустить обучение» у совета-шага (advisor(…, skip))
var adv_ok: Button                          # «Понятно» (у вопроса Gfx — «Не надо»)
var adv_face: TextureRect                   # портрет советника (в угловой карточке — поменьше)
var _bar_arrow_t0 := 0                      # когда впервые показали стрелку «Казармы» (она показывается один раз, ~10 с)
var adv_never: Button                       # «Больше не показывать» — выключает всплывающие советы (настройка advisor_off)
var _adv_skip_cb := Callable()
var notes_box: VBoxContainer
var overview_panel: PanelContainer
var overview_tab := "city"
var overview_pages: Dictionary = {}
var overview_buttons: Dictionary = {}
var overview_scroll: ScrollContainer
var settings_scroll: ScrollContainer
var events_panel: PanelContainer
var research_panel: PanelContainer
var research_tree
var research_box: VBoxContainer
var lbl_research_rp: Label
var lbl_research_rate: Label              # «+11 в час» у очков в окне исследований (этап 2.2)
var _tax_warn := {}                       # окно «Финансы»: предупреждения о налогах — пересчёт раз в игровой час
var finance_panel: PanelContainer
var stats_panel: PanelContainer
var pause_panel: PanelContainer
var settings_panel: PanelContainer
var buy_panel: PanelContainer
var buy_plot := Vector2i(-1, -1)
var menu_root: Control
var world_icons := {}                 # id постройки → значок беды
var badge_layer: Control              # спокойные значки; дальние чуть меньше
const MapBadge = preload("res://scripts/map_badge.gd")
const FamilyPreference = preload("res://scripts/family_preference.gd")
var _badges_dirty := true
var _badge_pick_dirty := true
var _badge_tool := "__unset__"
var _badge_camera: Camera3D
var _badge_transform := Transform3D.IDENTITY
var _badge_projection := Projection()
var _badge_viewport := Rect2()
var _badge_target := Vector3.INF
var _badge_zoom := -1.0
var _badge_show := false
var _badge_overlay := "__unset__"
var _family_badge_next_ms := 0
var badges := {}                      # ключ → {pos, icon, n}
var paused_speed := 1.0
var hidden_ui := false
var bell_count := 0
var bell_badge: Label
var floor_badge: Label                    # на кнопке «Этаж»: сколько домов готовы к этажу
var upg_badge: Label                      # на кнопке «Перестроить»: сколько домов готовы к перестройке
const FLOOR_TIP := "Этаж (U): щёлкните по дому со стрелкой или ведите с зажатой кнопкой вдоль улицы — этаж получат все готовые дома под курсором"
const EMPTY_TIP := "Казна пуста: жалованья работникам и содержания построек за час больше, чем пришло налогов. Город в долг не живёт — недоплаченное просто не плачено, а жители обижены: счастье всех домов ниже — и ещё пару часов после того, как казна снова сможет платить. Подробно — «Обзор города» → «Деньги»."
const UPG_TIP := "Перестроить (Shift+U): дом плебеев — в дом ремесленников, дом ремесленников — в городской домус. Щёлкните по дому с двойной стрелкой или ведите вдоль улицы"
## Двойная стрелка «Перестроить» — цвета класса, которым станет дом
const UPC_COL := {"upc_a": Color("e0904a"), "upc_p": Color("a77ee0")}
var cloud_off: CloudBadge             # значок «нет связи с облаком» слева от колокольчика
var pointer: TextureRect
var pointer_target: Control
var _pointer_badge := {}
var pointer_text: Label
var credits_panel: PanelContainer         # титры: кто и что сделал для игры
var journal_panel: PanelContainer = null  # журнал «Истории горожан» (собирает StoryUi при первом открытии)
var hover_tip: PanelContainer             # мгновенная подсказка у плашки города и фишек классов
var hover_box: VBoxContainer
var hover_src: Control                    # над чем сейчас мышь
var hover_level: Control                  # зоны плашки города: уровень, жители, счастье
var hover_pop: Control
var hover_happy: Control
var renown_pill: Control                   # известность и титул города (новая игра) — плашка под плашкой города
var lbl_renown: Label
var rank_btn: Button                      # «Перейти на новый уровень» — под табличкой города, когда все условия выполнены
var full_money: Label                     # «Казна полна — доход пропадает» над казной
var empty_money: Label                    # «Казна пуста — жалованье не плачено» над казной (казна в минус не уходит)
## Советы не друг за другом (решение владельца 26.10): закрыли совет — следующий сам (раз на механику) не раньше чем
## через TIP_GAP_MS. Только в своей игре (игра — главная сцена; проверка темпа ставит tip_gap сама): в автопроверках
## советы идут подряд, как раньше. Совет по щелчку игрока (строка просьбы, шаг истории) — сразу
const TIP_GAP_MS := 30000
var tip_gap := false
var _tip_next := 0
var full_rp: Label                        # «Полки полны — очки пропадают»
var _cursor_key := ""                     # какой рисованный курсор стоит на обычной стрелке (по инструменту, см. _cursor_world)
var _cursor_px := 0


func _ready() -> void:
	layer = 10
	marble = str(game.settings.get("ui_style", "marble")) == "marble" and not OS.get_cmdline_user_args().has("--paui")
	_fonts()
	theme_main = _theme()
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme_main
	root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(root)
	_badge_layer()
	_city_card()
	_class_chips()
	_families()
	_tasks()
	_rank_button()
	_top_right()
	MagisUI.attach(self)
	_bottom_left()
	_bottom_center()
	_bottom_right()
	_tool_panel()
	_overlay_panel()
	_info_panel()
	_advisor()
	_notes()
	_events_panel()
	_research_panel()
	_finance_panel()
	_stats_panel()
	_pause_panel()
	_settings_panel()
	_credits_panel()
	_buy_panel()
	_pointer()
	_hover_tip_panel()
	LegionUi.attach(self)                      # окно «Легион» и его медальон сверху справа (scripts/legion_ui.gd)
	CampUI.attach(self)                        # отдельный лагерь новой игры
	_hero_button()                             # медальон «Герой» (Д11): лицо своего героя, щелчок — к нему
	if game != null and game.city != null:
		game.city.rp_reward.connect(_fly_rp)      # просьба дала очки — «+25» летит к счётчику свитков (без звука и всплывашки)
	apply_scale(float(game.settings.get("ui_scale", 1.0)))
	get_window().size_changed.connect(func():
		apply_scale(float(game.settings.get("ui_scale", 1.0)))
		_fit_top.call_deferred())
	get_tree().node_added.connect(_on_node_added)
	_hook_buttons(self)
	_make_icons()


## Размер интерфейса из настроек, но не крупнее, чем помещается по ширине окна (MIN_W логических точек):
## иначе нижние полосы и кнопки наверху наезжают друг на друга
func apply_scale(s: float) -> void:
	get_window().content_scale_factor = clampf(s, 0.7, ui_cap())
	var ws := Vector2(get_window().size)
	if ws.x >= 64.0 and ws.y >= 64.0:
		_fit_bottom.call_deferred()           # экран в точках стал уже — полосы внизу подогнать
	if settings_panel != null and settings_panel.visible:
		_ui_slider_fit()                      # окно поменяло размер при открытых настройках


## Самый крупный интерфейс, что помещается в окно по ширине (MIN_W логических точек)
func ui_cap() -> float:
	var ws := Vector2(get_window().size)
	if ws.x < 64.0 or ws.y < 64.0:
		return 1.6
	var st := minf(ws.x / 1600.0, ws.y / 900.0)          # растяжение canvas_items от базовых 1600×900
	return maxf(0.7, minf(1.6, ws.x / (st * MIN_W)))


## Ползунок «Размер интерфейса» — только до того, что помещается в окно (дальше он ничего не менял бы);
## сохранённый выбор не трогаем: в окне пошире снова станет крупнее
func _ui_slider_fit() -> void:
	var us := settings_panel.find_child("ui_scale", true, false) as HSlider
	if us == null:
		return
	us.set_block_signals(true)                # меньший предел не должен переписать настройку через value_changed
	us.max_value = clampf(floorf(ui_cap() / 0.05 + 0.001) * 0.05, 1.0, 1.4)
	us.set_value_no_signal(float(game.settings.get("ui_scale", 1.0)))
	us.set_block_signals(false)


## Щелчок у каждой кнопки интерфейса
func _on_node_added(n: Node) -> void:
	if n is BaseButton and is_ancestor_of(n):
		_hook(n)


func _hook_buttons(n: Node) -> void:
	for c in n.find_children("*", "BaseButton", true, false):
		_hook(c)


func _hook(b: BaseButton) -> void:
	if b.has_meta("snd"):
		return
	b.set_meta("snd", true)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND      # над кнопкой — курсор-«рука»
	b.pressed.connect(func():
		if game and game.sound:
			game.sound.ui("click"))


# ---------- оформление ----------

func _fonts() -> void:
	font = _lining(load("res://assets/fonts/AlegreyaSans-Bold.ttf"))
	font_bold = _lining(load("res://assets/fonts/AlegreyaSans-ExtraBold.ttf"))
	font_title = load("res://assets/fonts/Philosopher-Bold.ttf")


## Цифры одной высоты и ширины (у Alegreya по умолчанию «старинные»: 0 похож на «о», часы дёргаются)
func _lining(f: Font) -> Font:
	var v := FontVariation.new()
	v.base_font = f
	var ts := TextServerManager.get_primary_interface()
	v.opentype_features = {ts.name_to_tag("lnum"): 1, ts.name_to_tag("tnum"): 1}
	return v


## Рисованная рамка 9-slice: поля картинки m и поля текста cm — [слева, сверху, справа, снизу].
## Поля замерены по картинкам (углы, валики и розетки не растягиваются); tile — края плиткой (меандр)
## pm, pcm — поля картинки и текста у нового интерфейса (если картинка есть в PA); у окон, кнопок и карточек
## вокруг — тень PA_PAD за краем
func _ai_box(name: String, m: Array, cm: Array, tile := false, pm: Array = [], pcm: Array = []) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	var pa := pa_has(name)
	s.texture = load(ui_tex(name))
	if pa:
		var e := PA_PAD if name.begins_with("g_panel") or name.begins_with("g_btn") or name.begins_with("g_card") or name.begins_with("g_scroll") else 0.0
		var tm: Array = pm if not pm.is_empty() else m
		m = [float(tm[0]) + e, float(tm[1]) + e, float(tm[2]) + e, float(tm[3]) + e]
		if not pcm.is_empty():
			cm = pcm
		s.expand_margin_left = e
		s.expand_margin_top = e
		s.expand_margin_right = e
		s.expand_margin_bottom = e
		tile = false
	s.texture_margin_left = m[0]
	s.texture_margin_top = m[1]
	s.texture_margin_right = m[2]
	s.texture_margin_bottom = m[3]
	s.content_margin_left = cm[0]
	s.content_margin_top = cm[1]
	s.content_margin_right = cm[2]
	s.content_margin_bottom = cm[3]
	if tile:
		s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return s


## Есть ли картинка нового интерфейса с этим именем (и он не выключен --oldui)
static func pa_has(name: String) -> bool:
	return not old_ui and ResourceLoader.exists(PA + name + ".png")


## Путь картинки интерфейса: новая (PA), если есть, иначе прежняя (AI). name — без «.png»
static func ui_tex(name: String) -> String:
	if marble and not old_ui and ResourceLoader.exists(MB + name + ".png"):
		return MB + name + ".png"
	return (PA if pa_has(name) else AI) + name + ".png"


## Резная рамка с меандром и розетками по углам — окна (рамка 21 px); новый интерфейс — тонкая обводка
func _box_panel(pad := 8.0) -> StyleBoxTexture:
	return _ai_box("g_panel", [46, 46, 45, 47], [21 + pad, 20 + pad, 21 + pad, 21 + pad], true, [14, 14, 14, 14], [12 + pad, 10 + pad, 12 + pad, 11 + pad])


## Та же рамка потоньше (10 px) — полосы внизу экрана, панели инструментов
func _box_bar(pad := 4.0) -> StyleBoxTexture:
	return _ai_box("g_panel_xs", [23, 23, 22, 24], [10 + pad, 9 + pad, 10 + pad, 13 + pad], true, [11, 11, 11, 11], [8 + pad, 6 + pad, 8 + pad, 7 + pad])


## Вертикальный свиток: валики сверху и снизу (просьбы, карточка постройки, главное меню).
## Пергамент начинается на 31-й точке под верхним валиком и кончается за 32 точки до низа, по бокам — с 27-й
func _box_scroll_v(pad := 10.0) -> StyleBoxTexture:
	return _ai_box("g_scroll_v", [34, 33, 34, 36], [27 + pad, 28 + pad * 0.5, 27 + pad, 32 + pad * 0.5], false, [14, 14, 14, 14],
		[14 + pad, 12 + pad * 0.5, 14 + pad, 12 + pad * 0.5])


## Горизонтальный свиток: валики слева и справа (стройка, советник, обучение)
func _box_scroll_h(pad := 8.0) -> StyleBoxTexture:
	return _ai_box("g_scroll_h", [45, 58, 45, 63], [44 + pad * 1.5, 26 + pad, 44 + pad * 1.5, 29 + pad], false, [14, 14, 14, 14],
		[16 + pad * 1.5, 12 + pad, 16 + pad * 1.5, 12 + pad])


## Плашка — длинная бронзовая кнопка (кнопки, фишки, всплывашки, подсказки)
func _box_pill(h := 16.0, v := 6.0, name := "g_btn") -> StyleBoxTexture:
	return _ai_box(name, [22, 12, 22, 12], [h, v, h, v], false, [11, 11, 11, 11])


## Бронзовый медальон под размер кнопки; у «нажатого» свечение выходит за край (рамка совпадает с обычным)
func _medal(name: String, size: float) -> StyleBoxTexture:
	var key := "%s:%d" % [name, int(size)]
	if _medals.has(key):
		return _medals[key]
	var s := StyleBoxTexture.new()
	s.texture = load(ui_tex(name))
	if name == "medal_on" and not pa_has(name):
		var e := size * 0.077
		s.expand_margin_left = e
		s.expand_margin_right = e
		s.expand_margin_top = e
		s.expand_margin_bottom = e
	_medals[key] = s
	return s


func _theme() -> Theme:
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 18
	t.set_stylebox("panel", "PanelContainer", _box_panel())
	t.set_stylebox("normal", "Button", _box_pill())
	t.set_stylebox("hover", "Button", _box_pill(16, 6, "g_btn_hover"))
	t.set_stylebox("pressed", "Button", _box_pill(16, 6, "g_btn_on"))
	t.set_stylebox("hover_pressed", "Button", _box_pill(16, 6, "g_btn_on"))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	var dis := _box_pill()
	dis.modulate_color = Color(0.85, 0.82, 0.78, 0.8)
	t.set_stylebox("disabled", "Button", dis)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", C_INK)
	t.set_color("font_disabled_color", "Button", Color(C_INK, 0.45))
	# иконки на кнопках рисованные и цветные — не красим
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		t.set_color(c, "Button", Color.WHITE)
	t.set_color("icon_disabled_color", "Button", Color(1, 1, 1, 0.45))
	t.set_constant("h_separation", "Button", 8)
	t.set_color("font_color", "Label", C_INK)
	t.set_stylebox("panel", "TooltipPanel", _box_pill(16, 10))
	t.set_color("font_color", "TooltipLabel", C_INK)
	t.set_font("font", "TooltipLabel", font)
	t.set_font_size("font_size", "TooltipLabel", 17)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "CheckBox", C_INK)
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		t.set_stylebox(st, "CheckBox", StyleBoxEmpty.new())
	var on: Texture2D = load(ui_tex("g_check_on"))
	var off: Texture2D = load(ui_tex("g_check_off"))
	t.set_icon("checked", "CheckBox", on)
	t.set_icon("unchecked", "CheckBox", off)
	t.set_icon("checked_disabled", "CheckBox", on)
	t.set_icon("unchecked_disabled", "CheckBox", off)
	t.set_constant("h_separation", "CheckBox", 8)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "OptionButton", C_INK)
	# полосы прокрутки: тот же пергаментный жёлоб в бронзовой кайме, бегунок — золотой (как у ползунка)
	var hs := _ai_box("g_slider", [8, 0, 8, 0], [0, 7, 0, 7])
	var hg := _ai_box("g_slider_fill", [8, 0, 8, 0], [8, 7, 8, 7])
	var hgl := hg.duplicate() as StyleBoxTexture
	hgl.modulate_color = Color(1.12, 1.08, 1.0)
	t.set_stylebox("scroll", "HScrollBar", hs)
	t.set_stylebox("grabber", "HScrollBar", hg)
	t.set_stylebox("grabber_highlight", "HScrollBar", hgl)
	t.set_stylebox("grabber_pressed", "HScrollBar", hgl)
	var vs := _ai_box("g_slider_v", [0, 8, 0, 8], [7, 0, 7, 0])
	var vg := _ai_box("g_slider_fill_v", [0, 8, 0, 8], [7, 8, 7, 8])
	var vgl := vg.duplicate() as StyleBoxTexture
	vgl.modulate_color = Color(1.12, 1.08, 1.0)
	t.set_stylebox("scroll", "VScrollBar", vs)
	t.set_stylebox("grabber", "VScrollBar", vg)
	t.set_stylebox("grabber_highlight", "VScrollBar", vgl)
	t.set_stylebox("grabber_pressed", "VScrollBar", vgl)
	for sbn in ["HScrollBar", "VScrollBar"]:
		t.set_stylebox("scroll_focus", sbn, StyleBoxEmpty.new())
	t.set_constant("scrollbar_h_separation", "ScrollContainer", 4)
	t.set_constant("scrollbar_v_separation", "ScrollContainer", 6)
	# ползунок: пергаментный жёлоб в бронзовой кайме, заполненная часть — золотая, ручка — бронзовая с лавром
	t.set_stylebox("slider", "HSlider", _ai_box("g_slider", [8, 0, 8, 0], [0, 8, 0, 8]))
	var fill := _ai_box("g_slider_fill", [8, 0, 8, 0], [0, 8, 0, 8])
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var knob: Texture2D = load(ui_tex("g_knob"))
	t.set_icon("grabber", "HSlider", knob)
	t.set_icon("grabber_highlight", "HSlider", knob)
	t.set_icon("grabber_disabled", "HSlider", knob)
	return t


## Есть ли рисованная (цветная) иконка
func painted(name: String) -> bool:
	return ResourceLoader.exists(AI + "icons/%s.png" % name) or pa_has("icons/" + name)


## Картинка для пережатия: из исходного PNG на диске (игра запущена из проекта) — без чтения из видеокарты.
## get_image() у импортированной текстуры читает её обратно из видеопамяти, и драйвер изредка падал (код 139
## в test_tutorial / test_story, 17.11). В собранной игре исходников нет — тогда как раньше.
static func src_image(path: String) -> Image:
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			return img
	return (load(path) as Texture2D).get_image()


## Иконка нужного размера: рисованная PNG из assets/ui/ai/icons (цветная — не красится),
## иначе белая SVG из assets/ui/icons (красится через modulate)
func ico(name: String, size := 64) -> Texture2D:
	var key := "%s:%d" % [name, size]
	if _ico.has(key):
		return _ico[key]
	var tex: Texture2D = null
	var png := ui_tex("icons/" + name)
	if ResourceLoader.exists(png):
		var img := src_image(png)
		if img.is_compressed():
			img.decompress()
		img.clear_mipmaps()
		img.convert(Image.FORMAT_RGBA8)
		var px := clampi(size, 8, img.get_width())
		if px != img.get_width():
			img.resize(px, px, Image.INTERPOLATE_LANCZOS)
		img.generate_mipmaps()
		tex = ImageTexture.create_from_image(img)
	else:
		var path := "res://assets/ui/icons/%s.svg" % name
		if FileAccess.file_exists(path):
			var img := Image.new()
			img.load_svg_from_string(FileAccess.get_file_as_string(path), size / 512.0)
			tex = ImageTexture.create_from_image(img)
		elif ResourceLoader.exists(path):         # собранная игра: исходных SVG нет, только импортированная картинка 512
			var img := (load(path) as Texture2D).get_image()
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			img.resize(maxi(1, roundi(img.get_width() * size / 512.0)), maxi(1, roundi(img.get_height() * size / 512.0)), Image.INTERPOLATE_LANCZOS)
			tex = ImageTexture.create_from_image(img)
	if tex != null:
		tex.set_meta("city_icon", name)
	_ico[key] = tex
	return tex


func _label(text: String, size := 18, bold := false, col := C_INK, f: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_font_override("font", f if f else (font_bold if bold else font))
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Иконка: рисованная — в своих цветах; белая SVG (если рисованной нет) — цветом col
func _icon(name: String, size := 22, col := C_INK) -> TextureRect:
	var r := TextureRect.new()
	r.texture = ico(name, mini(128, size * 2))
	r.set_meta("city_icon", name)
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.modulate = Color.WHITE if painted(name) else col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Картинка из рисованного набора (портрет, табличка, логотип…) с сохранением пропорций
func _pic(name: String, size: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load(ui_tex(name.get_basename()) if name.get_extension() == "png" else AI + name)
	r.custom_minimum_size = size
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Портрет класса жителей в бронзовом медальоне
func _cls_pic(cl: String, size: float) -> TextureRect:
	return _pic("class_%s.png" % cl, Vector2(size, size))


## Серый «неактивный» вид: замок, нет лавки рядом, нельзя изучить
func _grey(c: CanvasItem, on := true) -> void:
	if not on:
		c.material = null
		return
	if _grey_mat == null:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV) * COLOR;\n\tfloat g = dot(c.rgb, vec3(0.3, 0.59, 0.11));\n\tCOLOR = vec4(mix(c.rgb, vec3(g) * vec3(1.03, 0.98, 0.9), 0.88), c.a * 0.7);\n}\n"
		_grey_mat = ShaderMaterial.new()
		_grey_mat.shader = sh
	c.material = _grey_mat


## Тонкий бронзовый разделитель с лавровой розеткой
func _divider(h := 22.0) -> TextureRect:
	var d := _pic("divider.png", Vector2(0, h))
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return d


## Бронзовый медальон с иконкой посередине (иконка всегда внутри круга)
func _round(name: String, tip: String, size := 56, cb: Callable = Callable()) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	for st: Array in [["normal", "medal"], ["hover", "medal_hover"], ["pressed", "medal_on"], ["hover_pressed", "medal_on"], ["disabled", "medal_lock"]]:
		b.add_theme_stylebox_override(st[0], _medal(st[1], size))
	# у круглых рисованных значков (глаз, «i», «?», галочка) своё золотое кольцо снято: эмаль становится лицом медальона
	var face := painted(name + "_m")
	var ic := _icon(name + "_m" if face else name, int(size * (0.74 if face else 0.62)))
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	var o := size * (0.135 if face else 0.19)
	ic.offset_left = o
	ic.offset_right = -o
	ic.offset_top = o
	ic.offset_bottom = -o
	ic.name = "ic"
	b.add_child(ic)
	b.set_meta("icon", name)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


## Кнопка-картинка без медальона: у рисованных значков скорости и «закрыть» уже есть свой круг
func _bare(name: String, tip: String, size := 34, cb: Callable = Callable()) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	var e := StyleBoxEmpty.new()
	for st in ["normal", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, e)
	b.add_theme_stylebox_override("hover", _medal("medal_hover", size))
	var ic := _icon(name, size)
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.name = "ic"
	b.add_child(ic)
	b.set_meta("icon", name)
	b.set_meta("bare", true)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


func _set_on(b: Button, on: bool) -> void:
	if b.has_meta("swatch"):
		b.add_theme_stylebox_override("normal", _box_pill(5, 5, "g_btn_on" if on else "g_btn"))
		b.add_theme_stylebox_override("hover", _box_pill(5, 5, "g_btn_on" if on else "g_btn_hover"))
		return
	var s: float = b.custom_minimum_size.x
	if b.has_meta("bare"):
		var mo := _medal("medal_on", s)
		if on and pa_has("medal_on"):
			mo = mo.duplicate() as StyleBoxTexture      # новый интерфейс: у значка своё кольцо — золотое кольцо чуть шире него
			for sd in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				mo.set_expand_margin(sd, maxf(3.0, s * 0.1))
		b.add_theme_stylebox_override("normal", mo if on else StyleBoxEmpty.new())
		(b.get_node("ic") as CanvasItem).modulate = Color.WHITE if on else Color(0.86, 0.82, 0.76)
		return
	b.add_theme_stylebox_override("normal", _medal("medal_on" if on else "medal", s))
	b.add_theme_stylebox_override("hover", _medal("medal_on" if on else "medal_hover", s))


## Медальон с подписью снизу (разделы стройки, инструменты)
func _round_lbl(name: String, text: String, tip: String, size := 60, cb: Callable = Callable()) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -6)
	var b := _round(name, tip, size, cb)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)
	var l := _label(text, 13, true, C_INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	v.set_meta("btn", b)
	return v


## Панель: "panel" — резная рамка (окна), "bar" — рамка потоньше (полосы на экране),
## "scroll_v" / "scroll_h" — свитки; старое имя "papyrus" = "bar". pad — отступ текста от рамки
func _panel(parent: Control = null, tex := "panel", _m := 0.0, pad := -1.0) -> PanelContainer:
	var p := PanelContainer.new()
	var sb: StyleBoxTexture
	match tex:
		"scroll_v":
			sb = _box_scroll_v(10.0 if pad < 0 else pad)
		"scroll_h":
			sb = _box_scroll_h(8.0 if pad < 0 else pad)
		"bar", "papyrus":
			sb = _box_bar(4.0 if pad < 0 else pad)
		_:
			sb = _box_panel(8.0 if pad < 0 else pad)
	p.add_theme_stylebox_override("panel", sb)
	(parent if parent else root).add_child(p)
	return p


## Прикрепить окно к углу/краю экрана со сдвигом off (растёт от края внутрь экрана)
func _put(c: Control, preset: int, off: Vector2) -> void:
	c.set_anchors_preset(preset)
	var gh := Control.GROW_DIRECTION_END
	var gv := Control.GROW_DIRECTION_END
	match preset:
		Control.PRESET_TOP_RIGHT:
			gh = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_BOTTOM_LEFT:
			gv = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_BOTTOM_RIGHT:
			gh = Control.GROW_DIRECTION_BEGIN
			gv = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_CENTER_TOP:
			gh = Control.GROW_DIRECTION_BOTH
		Control.PRESET_CENTER_BOTTOM:
			gh = Control.GROW_DIRECTION_BOTH
			gv = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_CENTER:
			gh = Control.GROW_DIRECTION_BOTH
			gv = Control.GROW_DIRECTION_BOTH
	c.grow_horizontal = gh
	c.grow_vertical = gv
	c.offset_left = off.x
	c.offset_right = off.x
	c.offset_top = off.y
	c.offset_bottom = off.y
	c.set_meta("put", [preset, off])


## Godot сам не уменьшает окно, когда содержимого стало меньше: прикрепляем заново — размер станет по содержимому
func _snug(c: Control) -> void:
	if c.has_meta("put"):
		var m: Array = c.get_meta("put")
		_put(c, m[0], m[1])
	else:
		c.reset_size()


## Убрать содержимое сразу (а не в конце кадра), чтобы размер окна пересчитался по новому
func _clear(box: Node) -> void:
	for ch in box.get_children():
		box.remove_child(ch)
		ch.queue_free()


## Ещё раз подогнать окно под содержимое через кадр — когда перенос строк уже посчитан по настоящей ширине
func _refit(c: Control) -> void:
	if c.has_meta("refit"):
		return
	c.set_meta("refit", true)
	await get_tree().process_frame
	if is_instance_valid(c):
		c.remove_meta("refit")
		_snug(c)


## Текст с переносом строк фиксированной ширины. Ширину задаём сразу (а не после раскладки):
## иначе новая надпись нулевой ширины считает себя в одну букву на строку — огромной высоты,
## и окно вытягивается до низа экрана
func _wrap(l: Label, w: float) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(w, 0)
	l.size = Vector2(w, l.size.y)
	return l


## Плашка-фишка (классы, семьи, всплывашки, лавки в карточке дома)
func _chip(dark := false, cm := 10.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box_pill(cm + 6.0, maxf(5.0, cm * 0.5), "g_btn_on" if dark else "g_btn"))
	return p


func fmt(v: float) -> String:
	return Gear.stock_text(roundi(v))


func mouse_over_ui() -> bool:
	var camp_ui := CampUI.of(self)
	if camp_ui != null and camp_ui.visible:
		return true
	if menu_root and menu_root.visible:
		return true
	var h := root.get_viewport().gui_get_hovered_control()
	# После пересборки значка Godot может ещё помнить прежний Control под мышью.
	if h != null and game != null and game._mouse_pos.x >= 0.0:
		if not h.is_visible_in_tree() or not h.get_global_rect().has_point(game._mouse_pos) or (game.tool in ["floor", "upgrade"] and badge_layer.is_ancestor_of(h)):
			h = null
	if h == null and game != null and game._mouse_pos.x >= 0.0:
		# окно под мышью только что пересобрали (карточка после «Гардероб», «Внешность», «+ работник»): до первого
		# движения мыши Godot не знает, над чем она, — смотрим сами, чтобы подпись постройки за карточкой не легла
		# поверх неё (проверка 26.10)
		# где мышь — по последнему событию мыши (как game.ground_at_mouse): у корневого окна get_mouse_position — курсор ОС
		var mp: Vector2 = game._mouse_pos
		var lu := LegionUi.of(self)
		for p in [info_panel, tool_panel, tasks_panel, tray, road_panel, overlay_panel, advisor_panel, bar_left, bar_mid, bar_right, city_card, renown_pill, top_panel,
				research_panel, finance_panel, stats_panel, events_panel, pause_panel, settings_panel, buy_panel, credits_panel, journal_panel,
				lu.win if lu != null and lu.visible else null]:
			# только то, что и так ловит мышь (рамки-контейнеры вроде ряда медальонов щелчок пропускают в мир)
			if p != null and (p as Control).is_visible_in_tree() and ((p as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE
					and (p as Control).get_global_rect().has_point(mp)):
				return true
	return h != null and h != root


# ---------- город, классы, задания ----------

func _city_card() -> void:
	# ОДНА тонкая полоса сверху слева (отзыв 14.11 «слишком много экрана»): название города, уровень, жители, счастье,
	# три класса (значок и число — подробности по наведению), казна, очки исследований, день, скорость и время.
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _box_pill(10, 2))
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	city_card = bar
	root.add_child(bar)
	_put(bar, Control.PRESET_TOP_LEFT, Vector2(8, 6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	bar.add_child(row)
	top_row = row
	# название города: в своём городе его можно нажать — окно «Название города» (в меню и готовом городе — просто надпись)
	var nm := MarginContainer.new()
	nm.add_theme_constant_override("margin_left", 4)
	nm.add_theme_constant_override("margin_right", 6)
	name_plate = nm
	var nh := HBoxContainer.new()
	nh.add_theme_constant_override("separation", 5)
	nh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nh.add_child(_icon("laurels", 22))
	lbl_city = _label(CityName.PLACEHOLDER, CITY_FONT, false, C_INK, font_title)
	lbl_city.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nh.add_child(lbl_city)
	nm.add_child(nh)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(nm)
	if game != null and game.mode in ["play", "new"]:
		nm.mouse_filter = Control.MOUSE_FILTER_STOP
		nm.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		nm.tooltip_text = "Щёлкните — назвать город"
		nm.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				nm.accept_event()
				open_city_name())
		nm.mouse_entered.connect(func(): nm.modulate = Color(1.12, 1.09, 1.03))
		nm.mouse_exited.connect(func(): nm.modulate = Color.WHITE)
	show_city_name()
	row.add_child(_vsep())
	# уровень, жители, счастье: каждая пара «значок + число» — одна зона для подсказки целиком (без щелей между ними)
	lbl_level = _label("Стоянка", 15, true, C_SOFT)
	hover_level = _hover_zone(row, [lbl_level], _tip_level)
	lbl_pop = _label("0", 16, true)
	hover_pop = _hover_zone(row, [_icon("family", 20), lbl_pop], _tip_pop)
	lbl_happy = _label("0%", 16, true, C_GOOD)
	hover_happy = _hover_zone(row, [_icon("happy", 20), lbl_happy], _tip_happy)
	for z: Control in [hover_level, hover_pop, hover_happy]:
		z.set_meta("tip_anchor", bar)            # подсказка встаёт под всей полосой, не закрывая её
	# три класса жителей — маленькие значки с числом (подробности — по наведению, _tip_class)
	row.add_child(_vsep())
	class_box = HBoxContainer.new()
	class_box.add_theme_constant_override("separation", 2)
	row.add_child(class_box)
	row.add_child(_vsep())
	# казна и очки исследований (раньше — внизу справа)
	var money_icon := CityStyle.pictogram("coins", 24)
	lbl_money = _label("0", 17, true)
	lbl_income = _label("", 14, true, C_GOOD)
	hover_money = _hover_zone(row, [money_icon, lbl_money, lbl_income], _tip_money)
	hover_money.name = "MoneyHover"
	hover_money.set_meta("tip_anchor", bar)
	lbl_rp = _label("0 / 300", 17, true)
	lbl_rp_day = _label("", 14, true, C_GOOD)
	hover_rp = _hover_zone(row, [CityStyle.pictogram("research", 24), lbl_rp, lbl_rp_day], _tip_rp)
	hover_rp.name = "ResearchPointsHover"
	hover_rp.set_meta("tip_anchor", bar)
	row.add_child(_vsep())
	# день, скорость, время
	var t := HBoxContainer.new()
	t.alignment = BoxContainer.ALIGNMENT_CENTER
	t.add_theme_constant_override("separation", 2)
	lbl_day = _label("День 1", 14, true, C_SOFT)
	t.add_child(lbl_day)
	for sp: Array in [[0.0, "pause", "Пауза (пробел)"], [1.0, "play", "Обычная скорость (1)"], [2.0, "fastfwd", "Быстро (2)"], [4.0, "fastfwd3", "Очень быстро (3)"]]:
		var sv: float = sp[0]
		var b := _bare(sp[1], sp[2], 24, func(): set_speed(sv))
		t.add_child(b)
		speed_btns.append([b, sv])
	lbl_clock = _label("08:00", 14, true, C_SOFT)
	t.add_child(lbl_clock)
	row.add_child(t)
	# известность и почётный титул (новая игра): последняя в полосе, подсказка — откуда и что дальше
	var rp := HBoxContainer.new()
	rp.visible = false
	lbl_renown = _label("", 14, true, C_INK)
	var rzn := _hover_zone(rp, [_icon("laurels", 18), lbl_renown], _tip_renown)
	rzn.set_meta("tip_anchor", bar)
	row.add_child(rp)
	renown_pill = rp
	# перо у часов: пока город сохраняется (автосохранение, F5), оно видно и чуть «пишет», потом тает
	save_quill = _icon("quill", 20, C_INK)
	save_quill.pivot_offset = Vector2(10, 10)
	save_quill.visible = false
	lbl_clock.add_child(save_quill)


## Тонкая вертикальная черта между группами в верхней полосе
func _vsep() -> Control:
	var c := ColorRect.new()
	c.color = Color(0.45, 0.32, 0.2, 0.35)
	c.custom_minimum_size = Vector2(1, 22)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Верхняя полоса не должна наезжать на медальоны справа: не помещается — прячем по очереди необязательное
## (день, прибавка очков, доход в час, титул города, часы)
func _fit_top() -> void:
	if city_card == null or top_panel == null or root == null or not root.is_inside_tree():
		return
	var opt: Array = [lbl_rp_day, lbl_income, renown_pill, lbl_day, lbl_clock]
	for x: Control in opt:
		x.set_meta("fit_hide", false)
	lbl_day.visible = true
	lbl_rp_day.visible = lbl_rp_day.text != ""
	lbl_income.visible = true
	lbl_clock.visible = true
	renown_pill.visible = _renown_on
	_snug(city_card)
	var room := root.size.x - top_panel.get_combined_minimum_size().x - 22.0 - 8.0
	for x: Control in opt:
		if city_card.get_combined_minimum_size().x <= room:
			break
		if x.visible:
			x.visible = false
			x.set_meta("fit_hide", true)
			_snug(city_card)


## Город сохраняется: перо у часов (без звука и всплывашки) — видно полторы секунды, чуть покачивается и тает
func saving() -> void:
	if save_quill == null or game == null or not (game.mode in ["play", "new"]):
		return
	save_quill.position = Vector2(lbl_clock.size.x + 1.0, -3.0)
	save_quill.visible = true
	save_quill.modulate.a = 1.0
	save_quill.rotation = 0.0
	if _quill_tw and _quill_tw.is_valid():
		_quill_tw.kill()
	_quill_tw = create_tween()
	for i in 3:
		_quill_tw.tween_property(save_quill, "rotation", -0.22, 0.2)
		_quill_tw.tween_property(save_quill, "rotation", 0.12, 0.2)
	_quill_tw.tween_property(save_quill, "modulate:a", 0.0, 0.5)
	_quill_tw.tween_callback(func(): save_quill.visible = false)


## Название города на табличке: имя с сервера (city.name), пока его нет — «Новый Рим» (в меню и готовом городе — всегда).
## Длинное имя (до 24 знаков) — мельче, чтобы целиком влезло в ленту
func show_city_name() -> void:
	var nm := CityName.PLACEHOLDER
	if game != null and game.city != null and game.mode in ["play", "new"] and String(game.city.name) != "":
		nm = String(game.city.name)
	elif game != null and not game.visiting.is_empty():
		nm = String(game.visiting.get("name", nm))      # в гостях — название города друга
	if lbl_city == null or (lbl_city.text == nm and lbl_city.has_meta("fit")):
		return
	lbl_city.text = nm
	lbl_city.set_meta("fit", true)
	var w := NAME_W
	var sz := CITY_FONT
	while sz > 11 and font_title.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > w:
		sz -= 1
	lbl_city.add_theme_font_size_override("font_size", sz)


## Щелчок по табличке: окно «Название города» (то же, что у кнопки «Имя» в «Легионе»)
func open_city_name() -> void:
	if game == null or not (game.mode in ["play", "new"]):
		return
	if game.sound:
		game.sound.ui("click")
	_close_windows()
	CityName.open(self)


## Никаких окон на экране (для советов «к слову»: про название города)
func _screen_free() -> bool:
	var magis := MagisUI.of(self)
	if magis != null and magis.visible:
		return false
	var camp_ui := CampUI.of(self)
	if camp_ui != null and camp_ui.visible:
		return false
	for x in [info_panel, events_panel, research_panel, finance_panel, stats_panel, pause_panel, settings_panel, buy_panel, credits_panel, tray, journal_panel]:
		if x and x.visible:
			return false
	var lu := LegionUi.of(self)
	if (lu != null and lu.visible) or CityName.window(self) != null:
		return false
	var au = get_node_or_null("AccountUi")
	return au == null or au._modal == null or not is_instance_valid(au._modal)


func _class_chips() -> void:
	pass                                      # значки классов теперь внутри верхней полосы (_city_card, class_box)


## Интерфейс открывается постепенно (как в Town to City): 0 — только стройка, 1 — плашка города и классы,
## 2 — кнопки сверху справа, 3 — всё, включая задания
func ui_level() -> int:
	if game == null or game.city == null:
		return 3
	return int(game.city.tips.get("ui", 3))


func apply_reveal(lvl: int) -> void:
	for x: Control in [city_card]:
		if x and x.visible != (lvl >= 1):
			x.visible = lvl >= 1
			if x.visible:
				x.modulate.a = 0.0
				x.create_tween().tween_property(x, "modulate:a", 1.0, 0.6)
	if top_panel and top_panel.visible != (lvl >= 2):
		top_panel.visible = lvl >= 2
		if top_panel.visible:
			top_panel.modulate.a = 0.0
			top_panel.create_tween().tween_property(top_panel, "modulate:a", 1.0, 0.6)
	if lvl < 3:
		tasks_panel.visible = false
	if game.tutorial != null:
		game.tutorial.reveal()
	# пока плашки города нет, семьи ждут в самом углу
	_put(fam_box, Control.PRESET_TOP_LEFT, Vector2(10, 12) if lvl < 1 else Vector2(_fam_x(), FAM_Y))


func _families() -> void:
	fam_box = HBoxContainer.new()
	_put(fam_box, Control.PRESET_TOP_LEFT, Vector2(_fam_x(), FAM_Y))
	fam_box.add_theme_constant_override("separation", 6)
	fam_box.visible = false
	root.add_child(fam_box)


## Где слева стоят семьи на площади: правее свитка просьб (свёрнутый — маленький значок, развёрнутый — широкий)
func _fam_x() -> float:
	var x := 8.0
	if tasks_panel != null and tasks_panel.visible:
		x = 8.0 + maxf(tasks_panel.size.x, tasks_panel.get_combined_minimum_size().x) + 10.0
	if rank_btn != null and rank_btn.visible:
		x = maxf(x, 8.0 + PLATE.x + 10.0)       # кнопка «Перейти на новый уровень» стоит под полосой слева
	return x


func _place_fam() -> void:
	if fam_box == null or ui_level() < 1:
		return
	var m: Array = fam_box.get_meta("put", [])
	if not m.is_empty() and not is_equal_approx((m[1] as Vector2).x, _fam_x()):
		_put(fam_box, Control.PRESET_TOP_LEFT, Vector2(_fam_x(), FAM_Y))


## Значки семей на площади: щелчок — выбрать им дом
func _fill_families() -> void:
	_clear(fam_box)
	_snug(fam_box)
	var c: City = game.city
	fam_box.visible = not c.arrivals.is_empty() and game.mode != "demo"
	if not fam_box.visible:
		_fam_known = {}
		return
	var chip := _chip(false, 10.0)
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	var family_count := c.arrivals.size()
	var family_word := _plural(family_count, "семья", "семьи", "семей")
	match family_word:
		"семья": chip.tooltip_text = "%d семья ждёт жилья" % family_count
		"семьи": chip.tooltip_text = "%d семьи ждут жилья" % family_count
		_: chip.tooltip_text = "%d семей ждут жилья" % family_count
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	chip.add_child(h)
	var cap := _label("Ждут\nжилья", 14, true, C_SOFT)
	cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(cap)
	var now := {}
	for f in c.arrivals:
		var nm: String = f["name"]
		var cd: Dictionary = Defs.CLASSES[f["cls"]]
		var home_name: String = Defs.B[cd["house"]]["name"]
		var b := _round("family", "Семья %s · %d чел. · %s\nХотят жить: «%s»\nНажмите и выберите им дом" % [nm, int(f["n"]), cd["name"].to_lower(), home_name], 50,
			func(): game.start_settle(nm))
		if game.tool == "settle" and game.settle_fam.get("name", "") == nm:
			_set_on(b, true)
		if f["cls"] != "plebs":
			var ci := _cls_pic(f["cls"], 24)
			ci.position = Vector2(-6, -6)
			b.add_child(ci)
		var want_id := String(f.get("want", ""))
		if want_id != "":
			var want := TextureRect.new()
			want.name = "WantIcon"
			want.texture = MapBadge.want_texture(want_id)
			want.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			want.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			want.position = Vector2(29, 29)
			want.size = Vector2(23, 23)
			want.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(want)
			b.tooltip_text += "\nХотят: %s" % String(FamilyWant.LOOK[want_id][1])
		h.add_child(b)
		now[nm] = true
		if not _fam_known.has(nm):
			# новая семья — медальон мягко «подпрыгивает»
			b.pivot_offset = Vector2(25, 25)
			b.scale = Vector2(0.6, 0.6)
			var tw := b.create_tween()
			tw.tween_property(b, "scale", Vector2(1.12, 1.12), 0.25).set_trans(Tween.TRANS_BACK)
			tw.tween_property(b, "scale", Vector2.ONE, 0.2)
	# Число рядом с медальонами — семьи, не люди в одной семье.
	var cnt := _label(str(family_count), 18, true, C_INK)
	cnt.name = "WaitingFamilyCount"
	cnt.tooltip_text = chip.tooltip_text
	cnt.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(cnt)
	_fam_known = now
	fam_box.add_child(chip)



## Повозка впервые встала из-за низкого счастья: объясняет советник (дальше — обычная всплывашка). Открыт другой
## совет — ждёт, пока его закроют (_once_tips), и говорит о счастье на тот момент
	CityStyle.apply(fam_box)


func on_arrive_block(text: String) -> void:
	if game.mode == "demo" or game.mode == "menu" or tutorial_busy():
		notify(text, "happy")
		return
	if not _tip_free() or not guidance_queue.is_empty():
		game.city.tips["arrive_wait"] = true    # открытый совет (или ролик ранга) не перебиваем — скажем, когда советник свободен
		return
	_arrive_advice()


func _arrive_advice() -> void:
	var c: City = game.city
	if not _tip_free() or not guidance_queue.is_empty():
		c.tips["arrive_wait"] = true
		return
	c.tips.erase("arrive_wait")
	advisor("Новые семьи не едут", "Сейчас счастье — %d%%, а для приезда семей нужно %d%%. Наведите мышь на счастье вверху — подсказка покажет, как его поднять." % [int(c.stats.get("happy", 0)), c.arrive_happy()])


## Советы о приезжих: первая семья; семья, которой негде жить
## Первый совет ждёт окончания обучения; желание берём из реально приехавшей семьи.
func _want_advice() -> bool:
	var c: City = game.city
	if game.mode in ["demo", "menu"] or tutorial_busy() or c.tips.has("want_advice") or not c.tips.has("want_arrived"):
		return false
	var id := String(c.tips["want_arrived"])
	c.tips["want_advice"] = true
	advisor("Желание семьи", FamilyWant.advice(id), Callable(), true, false, {"want_icon": id})
	return true


func on_arrival(f: Dictionary) -> void:
	_want_advice()
	var c: City = game.city
	if game.mode == "demo" or tutorial_busy():
		return
	# приехала семья — короткая плашка (не чаще раза в игровой час; остальные приезды видны значками слева)
	if int(c.hour_n) != _fam_toast_h:
		_fam_toast_h = int(c.hour_n)
		_toast("Приехала семья %s" % f["name"], "family")          # надпись переведёт Godot (образец «Приехала семья %s»)
	if c.settled_total == 0 and not c.tips.has("first_family"):
		c.tips["first_family"] = true
		advisor("Приехали первые жители!", "Семьи сошли с повозки на площадь у станции и ждут жилья. Нажмите на значок семьи слева вверху — подходящие дома засветятся, — и щёлкните по дому.\n\nПока семьи ждут, новые не едут: на площади помещается всего несколько семей. А везёт их повозка только туда, где в домах есть свободное место, — стройте дома заранее. Так город растёт постепенно.")
		return
	if c.homes_for(f).is_empty() and not c.tips.has("nohome_" + f["cls"]) and not advisor_panel.visible:   # открытый совет не перебиваем
		c.tips["nohome_" + f["cls"]] = true
		var cd: Dictionary = Defs.CLASSES[f["cls"]]
		advisor("Семье негде жить", "Семья %s (%s) ищет «%s», а свободных мест нет. Постройте дом у дороги — семья подождёт на площади." % [f["name"], cd["name"].to_lower(), Defs.B[cd["house"]]["name"]])


func _tasks() -> void:
	tasks_panel = _panel(null, "scroll_v", 0, 4)
	tasks_panel.set_meta("frame", tasks_panel.get_theme_stylebox("panel"))
	_put(tasks_panel, Control.PRESET_TOP_LEFT, Vector2(8, TASKS_Y))
	tasks_panel.custom_minimum_size = Vector2(328, 0)
	tasks_box = VBoxContainer.new()
	tasks_box.add_theme_constant_override("separation", 4)
	tasks_panel.add_child(tasks_box)


# ---------- новый уровень по кнопке (как зелёная кнопка в Town to City) ----------

const RANK_H := 50                          # на столько опускаются просьбы, когда видна кнопка уровня


func _rank_button() -> void:
	rank_btn = Button.new()
	rank_btn.text = "Перейти на новый уровень"
	rank_btn.icon = ico("level", 40)
	rank_btn.expand_icon = false
	rank_btn.focus_mode = Control.FOCUS_NONE
	rank_btn.add_theme_font_override("font", font_bold)
	rank_btn.add_theme_font_size_override("font_size", 18)
	rank_btn.add_theme_stylebox_override("normal", _box_pill(18, 6, "g_btn_on"))
	rank_btn.add_theme_stylebox_override("hover", _box_pill(18, 6, "g_btn_hover"))
	rank_btn.add_theme_stylebox_override("pressed", _box_pill(18, 6, "g_btn_on"))
	rank_btn.add_theme_stylebox_override("hover_pressed", _box_pill(18, 6, "g_btn_on"))
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		rank_btn.add_theme_color_override(st, C_GOOD)
	rank_btn.custom_minimum_size = Vector2(PLATE.x, 44)
	rank_btn.visible = false
	rank_btn.pressed.connect(press_rank)
	root.add_child(rank_btn)
	_put(rank_btn, Control.PRESET_TOP_LEFT, Vector2(8, TASKS_Y + 2))


## Кнопка видна: условия выполнены, город не в меню и не в демо, обучение кончилось
func rank_shown() -> bool:
	if game == null or game.city == null or game.mode in ["demo", "menu"]:
		return false
	if tutorial_busy():
		return false
	return ui_level() >= 1 and game.city.rank_ok()


## «Перейти на новый уровень»: уровень +1, ролик «Новый ранг» сыграет сам (rank_cine ловит level_up)
func press_rank() -> void:
	var c: City = game.city
	if not c.rank_ok():
		return
	advisor_panel.visible = false            # ролик ждёт, пока открыт советник, — убираем его
	_hide_hover()
	_hide_info()
	c.rank_up()
	refresh()


## Кнопка уровня и сдвиг просьб под неё; плашка уровня светится, пока город готов
func _update_rank_ui() -> void:
	var on := rank_shown()
	if rank_btn.visible != on:
		rank_btn.visible = on
		_put(tasks_panel, Control.PRESET_TOP_LEFT, Vector2(8, TASKS_Y + (RANK_H if on else 0)))
		_place_fam()
	if on:
		var nx: Dictionary = game.city.next_level()
		rank_btn.tooltip_text = "Город готов стать «%s»: все условия выполнены. Нажмите — откроются новые исследования, казна станет вместительнее." % nx.get("name", "")
	lbl_level.add_theme_color_override("font_color", C_GOOD if on else C_SOFT)
	if not on:
		lbl_level.modulate = Color.WHITE
		rank_btn.self_modulate = Color.WHITE


# ---------- мгновенные подсказки: плашка города (уровень, жители, счастье) и фишки классов ----------

const TIP_W := 330.0
var _hover_hold := 0                        # сколько кадров не проверять, ушла ли мышь (после пересборки)


func _hover_tip_panel() -> void:
	hover_tip = _panel(null, "bar", 0, 6)
	hover_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_tip.visible = false
	hover_tip.z_index = 20
	hover_box = VBoxContainer.new()
	hover_box.add_theme_constant_override("separation", 3)
	hover_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_tip.add_child(hover_box)


## Зона подсказки: значок и число вместе (с полями по бокам — между зонами нет «мёртвых» щелей).
## Подсказка открывается сразу, где бы ни была мышь над зоной
func _hover_zone(parent: Control, items: Array, build: Callable) -> Control:
	var z := HBoxContainer.new()
	z.add_theme_constant_override("separation", 3)
	z.custom_minimum_size = Vector2(0, 24)
	z.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for it: Control in items:
		it.mouse_filter = Control.MOUSE_FILTER_IGNORE
		it.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		z.add_child(it)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 5)
	m.add_theme_constant_override("margin_right", 5)
	m.add_child(z)
	parent.add_child(m)
	_hover_on(m, build)
	return m


func _hover_on(c: Control, build: Callable) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.set_meta("tip", build)
	c.mouse_entered.connect(func(): _show_hover(c))
	c.mouse_exited.connect(func():
		if hover_src == c:
			_hide_hover())


func _show_hover(c: Control) -> void:
	hover_src = c
	_fill_hover()


func _hide_hover() -> void:
	hover_src = null
	if hover_tip:
		hover_tip.visible = false


## Пересобрать подсказку (при наведении и при каждом обновлении города — числа живые)
func _fill_hover() -> void:
	if hover_src == null or not is_instance_valid(hover_src) or not hover_src.is_visible_in_tree():
		_hide_hover()
		return
	_clear(hover_box)
	(hover_src.get_meta("tip") as Callable).call(hover_box)
	hover_tip.visible = true
	_hover_hold = 3
	_place_hover()
	_place_hover_later()


func _place_hover() -> void:
	if hover_src == null or not is_instance_valid(hover_src):
		return
	hover_tip.reset_size()
	var r := hover_src.get_global_rect()
	var below := r.end.y
	if hover_src.has_meta("tip_anchor"):
		below = (hover_src.get_meta("tip_anchor") as Control).get_global_rect().end.y
	var p := Vector2(r.position.x - 8.0, below + 4.0)
	p.x = clampf(p.x, 4.0, maxf(4.0, root.size.x - hover_tip.size.x - 4.0))
	hover_tip.position = p


func _place_hover_later() -> void:
	await get_tree().process_frame
	if hover_tip.visible:
		_place_hover()


## Мышь ушла, а сигнал «ушла» не пришёл (фишку пересобрали под мышью) — прячем подсказку сами
func _hover_tick() -> void:
	if hover_tip == null or not hover_tip.visible:
		return
	if hover_src == null or not is_instance_valid(hover_src) or not hover_src.is_visible_in_tree():
		_hide_hover()
		return
	if _hover_hold > 0:
		_hover_hold -= 1                    # пересобранную фишку ещё раскладывают — проверим через пару кадров
		return
	var h := root.get_viewport().gui_get_hovered_control()
	if h != null:
		if h != hover_src and not hover_src.is_ancestor_of(h):
			_hide_hover()
		return
	if not hover_src.get_global_rect().grow(2.0).has_point(hover_src.get_global_mouse_position()):
		_hide_hover()


func _tip_head(v: Control, icon: Variant, text: String) -> void:
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 7)
	h.add_child(icon if icon is Control else _icon(String(icon), 28))
	var l := _label(text, 20, false, C_INK, font_title)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	v.add_child(h)


func _tip_text(v: Control, text: String, col := C_SOFT, size := 15, bold := false) -> void:
	v.add_child(_wrap(_label(text, size, bold, col), TIP_W))


## Строка подсказки: значок · подпись · значение; ok = 1 / 0 — галочка или крестик в конце
func _tip_row(v: Control, icon: Variant, text: String, val: String, col := C_INK, ok := -1) -> void:
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 6)
	h.custom_minimum_size = Vector2(TIP_W, 0)
	if icon is Control:
		h.add_child(icon)
	elif String(icon) != "":
		h.add_child(_icon(String(icon), 22, C_SOFT))
	var l := _label(text, 15)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	var vl := _label(val, 15, true, col)
	vl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(vl)
	if ok >= 0:
		var mk := _icon("check" if ok == 1 else "close", 18)
		mk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(mk)
	v.add_child(h)


static func _plural(n: int, one: String, few: String, many: String) -> String:
	var m := n % 100
	if m >= 11 and m <= 14:
		return many
	match n % 10:
		1:
			return one
		2, 3, 4:
			return few
	return many


## Уровень города → чек-лист условий следующего (галочки, сколько из скольких) и что он даст.
## Сам город уровень не поднимает: когда всё готово, под табличкой появляется кнопка «Перейти на новый уровень»
func _tip_level(v: VBoxContainer) -> void:
	var c: City = game.city
	_tip_head(v, "level", "Уровень города: «%s»" % Defs.LEVELS[c.level]["name"])
	var nx := c.next_level()
	if nx.is_empty():
		_tip_text(v, "Это высший уровень — ваш город стал Вечным!", C_GOOD, 15, true)
		return
	var nd := c.rank_needs()
	var met := c.rank_met()
	_tip_text(v, "Следующий уровень — «%s». Готово %d из %d:" % [nx["name"], met, nd.size()], C_INK, 15, true)
	for e: Dictionary in nd:
		var val := ("%d%% / %d%%" % [int(e["have"]), int(e["need"])]) if e["pct"] else ("%s / %s" % [fmt(int(e["have"])), fmt(int(e["need"]))])
		_tip_row(v, e["icon"], e["text"], val, C_GOOD if e["ok"] else C_BAD, 1 if e["ok"] else 0)
		if not e["ok"] and e["icon"] != "family" and not e["pct"]:
			# постройка условия: что сделать прямо сейчас (та же подсказка, что у стрелки просьб и в карточке станции)
			var say := String(need_do(e["p"], String(e.get("tool", "")), int(e.get("need", 0))).get("say", ""))
			if say != "":
				_tip_text(v, "   → " + say + ".", C_SOFT, 13)
	if met == nd.size():
		_tip_text(v, "Всё готово! Нажмите «Перейти на новый уровень» под табличкой города — когда сами захотите.", C_GOOD, 15, true)
	# пределы — с уже изученными хранилищами (как money_cap/rp_cap), а не голые числа уровня
	_tip_text(v, "На новом уровне казна вмещает %s ден., очков исследований — %s%s, открываются новые исследования." % [fmt(c.money_cap_for(c.level + 1)), fmt(c.rp_cap_for(c.level + 1)), _caps_text(c.level + 1)])
	if met < nd.size():
		if not nd[0]["ok"]:
			_tip_text(v, "Жителей прибавится, если строить дома у дорог и заселять приезжих.", C_INK, 14)
		if not nd[1]["ok"]:
			_tip_text(v, "Счастье поднимают лавки рядом с домами, украшения и памятники — наведите на счастье, там подробнее.", C_INK, 14)
		for i in range(2, nd.size()):
			if not nd[i]["ok"]:
				# что делать по каждой постройке — под её строкой (→ …); закрытое не помещается на полки — там же
				_tip_text(v, "Щёлкните по почтовой станции — в её карточке строки условий нажимаются и ведут прямо к делу.", C_INK, 14)
				break


## «, скрипториев — до 3, школ — до 2» — пределы построек для очков исследований на уровне lvl
func _caps_text(lvl: int) -> String:
	var out := ""
	for t in ["scriptorium", "school", "library", "academy"]:
		var mx: Array = Defs.B[t].get("max", [])
		if mx.is_empty():
			continue
		var n := int(mx[clampi(lvl, 0, mx.size() - 1)])
		if n > 0:
			out += ", %s — до %d" % [String(Defs.B[t].get("gen", t)), n]
	return out


## Жители → по классам, кто ждёт жилья и едет в повозке
func _tip_pop(v: VBoxContainer) -> void:
	var c: City = game.city
	_tip_head(v, "family", "Жители: %s" % fmt(int(c.stats["pop"])))
	for cl in Defs.CLASS_ORDER:
		var cd: Dictionary = Defs.CLASSES[cl]
		var n := int(c.stats["residents"].get(cl, 0))
		if n == 0 and not c.unlocked(cd["house"]):
			continue
		_tip_row(v, _cls_pic(cl, 26), cd["name"], "%s чел." % fmt(n))
	var fam_n := c.arrivals.size()
	var ppl := 0
	for f in c.arrivals:
		ppl += int(f["n"])
	if fam_n > 0:
		_tip_row(v, "tent", "Ждут жилья на площади", "%d %s · %d чел." % [fam_n, _plural(fam_n, "семья", "семьи", "семей"), ppl], C_BAD)
	if not c.pending.is_empty():
		_tip_row(v, "family", "Идут в свой новый дом", "%d %s" % [c.pending.size(), _plural(c.pending.size(), "семья", "семьи", "семей")], C_GOOD)
	if c.incoming > 0:
		_tip_row(v, "horse", "Едут в повозке", "%d %s" % [c.incoming, _plural(c.incoming, "семья", "семьи", "семей")], C_INK)
	_arrive_rows(v, true)
	var block := String(c.stats.get("arrive_block", ""))
	var wait := c.arrive_wait()
	if block != "":
		_tip_text(v, block, C_BAD, 14, true)
	elif wait != "":
		_tip_text(v, wait, C_BAD, 14, true)
	elif fam_n > 0:
		_tip_text(v, "Нажмите на значок семьи слева вверху и выберите им дом.", C_INK, 14)
	else:
		_tip_text(v, "Повозка привозит новые семьи по большой дороге — только туда, где есть место. Стройте дома у дорог заранее.", C_SOFT, 14)


## Строки о повозке: как часто ходит (и почему чаще) и на сколько семей есть место в домах.
## tip — в мгновенной подсказке (иначе — в карточке станции)
func _arrive_rows(v: Control, tip: bool) -> void:
	var c: City = game.city
	var am: Array = c.arrive_mult()
	var every := "раз в %s ч" % String.num(c.arrive_every(), 1).replace(".", ",")
	var fit := maxi(0, c.free_fit())
	var fit_txt := ("на %d %s" % [fit, _plural(fit, "семью", "семьи", "семей")]) if fit > 0 else "нет"
	if tip:
		_tip_row(v, "horse", "Повозка с семьями", every, C_INK)
		if float(am[0]) < 1.0:
			_tip_text(v, "Чаще обычного: %s." % am[1], C_GOOD, 14)
		_tip_row(v, "housing", "Свободное место в домах", fit_txt, C_GOOD if fit > 0 else C_BAD)
	else:
		v.add_child(_row("horse", "Повозка с семьями", every))
		if float(am[0]) < 1.0:
			v.add_child(_wrap(_label("Чаще обычного: %s." % am[1], 14, true, C_GOOD), 330))
		v.add_child(_row("housing", "Место в домах", fit_txt, C_GOOD if fit > 0 else C_BAD))
		var block := c.arrivals_blocked()
		if block != "":
			v.add_child(_wrap(_label(block, 14, true, C_BAD), 330))


## Счастье города → из чего складывается, по классам, что сделать и что оно даёт
func _tip_renown(v: VBoxContainer) -> void:
	var c: City = game.city
	_tip_head(v, "laurels", "Известность: %s" % fmt(int(c.renown)))
	_tip_text(v, "Почётный титул города — «%s»: +%d%% счастья всем домам." % [Renown.title_of(c.renown), Renown.title_happy(c)], C_INK, 15, true)
	var nx := Renown.next_title(c.renown)
	if not nx.is_empty():
		_tip_text(v, "Следующий титул — «%s»: ещё %s." % [nx[0], fmt(int(nx[1]) - int(c.renown))], C_SOFT, 14)
	var parts := Renown.hour_parts(c)
	if not parts.is_empty():
		_tip_text(v, "Растёт каждый час (+%s):" % String.num(Renown.hour_gain(c), 1).replace(".", ","), C_INK, 14, true)
		for e: Array in parts:
			_tip_row(v, "", String(e[0]), "+" + String.num(float(e[1]), 1).replace(".", ","), C_GOOD)
	if c.fest_left > 0 and c.cal_fest_id != "":
		_tip_text(v, "Сегодня — %s: город празднует, известность растёт быстрее." % Renown.cal_fest_name(c.cal_fest_id), C_GOOD, 14, true)
	else:
		var nf := Renown.next_fest(c.day)
		if not (nf[0] as Dictionary).is_empty():
			_tip_text(v, "Ближайший праздник — %s, через %d %s. %s" % [nf[0]["name"], int(nf[1]), _plural(int(nf[1]), "день", "дня", "дней"), nf[0]["bonus"]], C_INK, 14)
	var sid := Seasons.id_of(c.day)
	_tip_text(v, "Сейчас %s. %s" % [Seasons.name_of(c.day), {"winter": "Листва потускнела, хвоя темнее.", "spring": "Сады в цвету.", "summer": "Всё в зелени.", "autumn": "Листва золотая и багряная, листья падают."}[sid]], C_SOFT, 13)
	_tip_text(v, "Туристы гостиниц, зрелища, украшения, достопримечательности и счастье горожан прибавляют известность — расти можно без конца, даже когда город уже Вечный.", C_SOFT, 13)


func _tip_happy(v: VBoxContainer) -> void:
	var c: City = game.city
	var hp := int(c.stats["happy"])
	_tip_head(v, "happy", "Счастье города: %d%%" % hp)
	var parts: Array = c.stats.get("happy_parts", [])
	if not parts.is_empty():
		_tip_text(v, "Из чего складывается (в среднем на жителя):", C_INK, 14, true)
		var first := true
		for p: Array in parts:
			var val := int(p[1])
			_tip_row(v, "", String(p[0]), ("%d%%" % val) if first else _pct(val), C_INK if first else (C_GOOD if val > 0 else (C_BAD if val < 0 else C_SOFT)))
			first = false
	var shown := 0
	for cl in Defs.CLASS_ORDER:
		if int(c.stats["residents"].get(cl, 0)) > 0:
			shown += 1
	if shown > 1 or parts.is_empty():
		_tip_text(v, "По классам:", C_INK, 14, true)
		for cl in Defs.CLASS_ORDER:
			if int(c.stats["residents"].get(cl, 0)) <= 0:
				continue
			var ch := int(c.stats["class_happy"].get(cl, 0))
			_tip_row(v, _cls_pic(cl, 24), Defs.CLASSES[cl]["name"], "%d%%" % ch, C_GOOD if ch >= 60 else (C_GOLD if ch >= 40 else C_BAD))
	var tips: Array = c.stats.get("happy_tips", [])
	_tip_text(v, "Что сделать:", C_INK, 14, true)
	if tips.is_empty():
		_tip_text(v, "• Лавки нужных видов рядом с домами, украшения между домами и памятники поднимают счастье; теснота и нехватка лавок — опускают.", C_INK, 14)
	for t in tips:
		_tip_text(v, "• " + String(t), C_INK, 14)
	_tip_text(v, "Счастливые жители платят больше налогов, а новые семьи едут, пока счастье города не ниже %d%%. Щёлкните по дому — карточка покажет, чего не хватает именно ему." % game.city.arrive_happy(), C_SOFT, 14)


## Фишка класса → жители, счастье, нужды (у скольких домов нет нужной лавки), работа
func _tip_class(v: VBoxContainer, cl: String) -> void:
	var c: City = game.city
	var cd: Dictionary = Defs.CLASSES[cl]
	var n := int(c.stats["residents"].get(cl, 0))
	_tip_head(v, _cls_pic(cl, 40), "%s · %s %s" % [cd["name"], fmt(n), _plural(n, "житель", "жителя", "жителей")])
	var hp := int(c.stats["class_happy"].get(cl, 0))
	_tip_row(v, "happy", "Счастье", "%d%%" % hp, C_GOOD if hp >= 60 else (C_GOLD if hp >= 40 else C_BAD))
	var houses := []
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		if c.is_house(b) and c.def(b)["cls"] == cl:
			houses.append(b)
	_tip_text(v, "Нужно рядом с домом «%s»:" % Defs.B[cd["house"]]["name"], C_INK, 14, true)
	for nd in Defs.needs_for(cl, c.level):
		var miss := 0
		for b in houses:
			if nd in b.get("missing", []):
				miss += 1
		var txt := "есть у всех" if miss == 0 else "нет у %d из %d" % [miss, houses.size()]
		if houses.is_empty():
			txt = "—"
		_tip_row(v, Defs.NEEDS[nd]["icon"], Defs.NEEDS[nd]["name"], txt, C_GOOD if miss == 0 else C_BAD, -1 if houses.is_empty() else (1 if miss == 0 else 0))
	for nd: String in cd["needs"]:
		if nd not in Defs.needs_for(cl, c.level):
			_tip_row(v, Defs.NEEDS[nd]["icon"], Defs.NEEDS[nd]["name"], _need_later(cl, nd), C_SOFT, -1)
	var jobs := int(c.stats["jobs"].get(cl, 0))
	var workers := int(c.stats["workers"].get(cl, 0))
	var free := int(c.stats["free"].get(cl, 0))
	_tip_row(v, "hammer", "Могут работать", "%d чел." % workers)
	_tip_row(v, "commerce", "Мест для них в лавках и мастерских", "%d" % jobs, C_BAD if jobs > workers else C_INK)
	if jobs > workers:
		_tip_text(v, "Работников не хватает — постройки работают слабее. Заселите больше семей. Лишнее место можно убрать (−) там, где оно меньше всего нужно, например у скриптория: лавка, у которой забрали всех работников, закрывается.", C_BAD, 14)
	elif free > 0:
		_tip_text(v, "Свободны %d — наймите их кнопкой «+» в карточке здания." % free, C_SOFT, 14)
	_tip_text(v, "Налог: %s ден. в час с жителя — больше, когда жители счастливы." % String.num(float(cd["tax"]), 1).replace(".", ","), C_SOFT, 14)


# ---------- курсор: рисованные курсоры вместо курсоров Windows (assets/ui/ai/cursors, см. scripts/cursors.gd) ----------

const Cursors := preload("res://scripts/cursors.gd")
## Формы курсора с постоянной картинкой. Обычная стрелка (CURSOR_ARROW) меняется по инструменту, «рука» светится при нажатии;
## CURSOR_FORBIDDEN ставится недоступным кнопкам — над ними серая стрелка (нажать нельзя). Текстовый курсор — как в Windows
const CURSOR_FIXED := {Input.CURSOR_WAIT: "wait", Input.CURSOR_BUSY: "wait", Input.CURSOR_MOVE: "move", Input.CURSOR_DRAG: "hand_glow",
	Input.CURSOR_CAN_DROP: "hand", Input.CURSOR_FORBIDDEN: "arrow_grey", Input.CURSOR_VSIZE: "resize_v", Input.CURSOR_HSIZE: "resize_h",
	Input.CURSOR_BDIAGSIZE: "resize_diag", Input.CURSOR_FDIAGSIZE: "resize_diag", Input.CURSOR_HELP: "help", Input.CURSOR_CROSS: "cross"}
var _cursor_hand := ""


## Какой курсор нужен сейчас. Над окнами — стрелка, над кнопками и значками — «рука», над недоступной кнопкой — серая;
## над городом — по инструменту и по тому, что под мышью (_cursor_world). Зажата левая кнопка — стрелка и рука светятся
func _cursor_tick() -> void:
	var px := Cursors.size_for(get_viewport())
	var down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var key := "arrow"
	var ui := mouse_over_ui()
	if game == null or not game.ready_done:
		key = "wait"
	elif ui:
		_cursor_disabled_btn()
	elif root.visible:
		key = _cursor_world()
	if down and key in ["arrow", "hand"]:
		key += "_glow"
	var hand := "hand_glow" if down else "hand"
	if key == _cursor_key and hand == _cursor_hand and px == _cursor_px:
		return
	if px != _cursor_px:
		for sh in CURSOR_FIXED:
			Cursors.put(sh, CURSOR_FIXED[sh], px)
	_cursor_key = key
	_cursor_hand = hand
	_cursor_px = px
	Cursors.put(Input.CURSOR_POINTING_HAND, hand, px)
	Cursors.put(Input.CURSOR_ARROW, key, px)


## Курсор над городом (мышь не над окнами)
func _cursor_world() -> String:
	var t: String = game.tool
	var rig = game.rig
	if game.rot_drag or (rig and rig._orbit):
		return "rotate"                     # поворот постройки (левая зажата и ведут вбок) или камеры (зажатое колёсико)
	if rig and rig._pan and game._rmb_moved > 6.0:
		return "move"                       # тянут карту правой кнопкой
	if t == "":
		# щёлкнуть можно: постройка — откроется карточка, участок с табличкой — купить, потерянная кошка — нашли
		var sto = game.get("stories")
		if sto != null and sto.near_cat(game._mouse_pos):
			return "hand"
		if game.people != null and not game.people.hover_pick(game._mouse_pos).is_empty():
			return "hand"                   # житель или кошка под курсором — откроется их карточка
		return "hand" if game.plot_fill_key.x >= 0 or not game.pick_building().is_empty() else "arrow"
	if t in ["bulldoze", "move", "copy"]:
		var b: Dictionary = game.pick_building()
		var d: Dictionary = {} if b.is_empty() else game.city.def(b)
		if d.get("fixed", false) or (t == "move" and d.get("wall", false)):
			return "forbidden"                  # почтовую станцию не снести и не перенести, украшение на стене не переносится
		return {"bulldoze": "demolish", "move": "move", "copy": "hand"}[t]
	if t == "erase":
		return "demolish"
	if t in ["road", "path", "plaza", "cobble", "footpath"]:
		return "road"
	if t == "move_nature":
		var p: Vector2 = game.hover
		var ok: bool = p != Vector2.INF and game.land.occ_at(p) == 0 and not game.land.is_water(p) and not game.land.is_road(p)
		return "move" if ok else "arrow_red"
	if t == "settle":
		return "people"
	if t == "floor" or t == "upgrade":
		# над домом, которому можно этаж, — «строить»; над домом, которому нельзя, — красная стрелка (у курсора — почему)
		return {1: "build", 0: "arrow_red"}.get(int(game.floor_hover), "arrow")
	if Defs.B.has(t):
		if game.hover != Vector2.INF and String(game.place_info.get("err", "")) != "":
			return "arrow_red"                  # здесь не поставить — призрак красный
		if not game.moving.is_empty():
			return "move"
		return "monument" if Defs.B[t].get("cat", "") == "special" else "build"
	return "arrow"


## Недоступная кнопка (не хватает денег, ещё закрыто) — серая стрелка вместо «руки»: нажать нельзя
func _cursor_disabled_btn() -> void:
	var h := root.get_viewport().gui_get_hovered_control()
	if h is BaseButton and h.has_meta("snd"):
		var want := Control.CURSOR_FORBIDDEN if (h as BaseButton).disabled else Control.CURSOR_POINTING_HAND
		if h.mouse_default_cursor_shape != want:
			h.mouse_default_cursor_shape = want


# ---------- сверху справа ----------

## Сверху справа — отдельные бронзовые медальоны без общей рамки (как в Town to City), с мягкой тенью под каждым
func _top_right() -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_panel = h
	root.add_child(h)
	_put(h, Control.PRESET_TOP_RIGHT, Vector2(-10, 6))
	# перечёркнутое облачко — нет связи с облаком дольше 2 минут (scripts/cloud_badge.gd); обычно скрыто
	cloud_off = CloudBadge.make(self, 40)
	cloud_off.holder = _shadowed(cloud_off)
	cloud_off.holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cloud_off.holder.visible = false
	h.add_child(cloud_off.holder)
	for t: Array in [["research", "research", "Исследования"], ["overview", "stats", "Обзор города"],
			["photo", "photo", "Режим фото (P): интерфейс прячется, камера — к самой земле, время суток, размытие, снимок"], ["menu", "menu", "Меню игры"]]:
		var id: String = t[0]
		var b := _round(t[1], t[2], TOP_BTN, func(): _top_action(id))
		h.add_child(_shadowed(b))
		top_btns[id] = b
	# Старые имена нужны указателям и проверкам.
	for id: String in ["finance", "stats", "bell", "view"]:
		top_btns[id] = top_btns["overview"]
	bell_badge = _label("", 15, true, C_CREAM)
	bell_badge.add_theme_color_override("font_outline_color", C_BAD)
	bell_badge.add_theme_constant_override("outline_size", 9)
	bell_badge.position = Vector2(TOP_BTN - 13, -4)
	top_btns["overview"].add_child(bell_badge)
	_new_pill(top_btns["research"], "bottom")         # «НОВОЕ» — открылись исследования, которых игрок ещё не видел


var _shadow_tex: Texture2D


## Медальон на мягкой круглой тени — читается и на светлой траве, и на крышах
func _shadowed(b: Control) -> Control:
	if _shadow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(0.12, 0.07, 0.03, 0.55))
		g.set_color(1, Color(0.12, 0.07, 0.03, 0.0))
		g.add_point(0.62, Color(0.12, 0.07, 0.03, 0.42))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(0.5, 0.0)
		gt.width = 64
		gt.height = 64
		_shadow_tex = gt
	var c := Control.new()
	c.custom_minimum_size = b.custom_minimum_size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := TextureRect.new()
	sh.texture = _shadow_tex
	sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sh.set_anchors_preset(Control.PRESET_FULL_RECT)
	var e := b.custom_minimum_size.x * 0.12
	sh.offset_left = -e
	sh.offset_top = -e + 2.0
	sh.offset_right = e
	sh.offset_bottom = e + 3.0
	c.add_child(sh)
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(b)
	return c



func _top_action(id: String) -> void:
	if clean:
		toggle_clean()                        # «чистый экран» (H): Esc и кнопки сначала возвращают интерфейс
		if id == "menu":
			return
	match id:
		"research":
			_toggle(research_panel)
			_fill_research()
			_update_pointer()                     # стрелка просьбы — с кнопки на карточку нужного исследования
		"overview":
			_open_overview("city")
		"finance":
			_open_overview("money")
		"stats":
			_open_overview("people")
		"bell":
			_open_overview("events")
		"view":
			set_overlay("" if overlay != "" else overlay_last)
		"photo":
			_photo()
		"menu":
			_toggle(pause_panel)


## Окно посреди экрана: открывается одно, а свиток стройки и карточка постройки при этом прячутся
func _toggle(p: Control) -> void:
	var was := p.visible
	_close_windows()
	p.visible = not was
	if p.visible:
		_close_tray()
		_hide_info()


func _close_windows() -> void:
	MagisUI.close_for(self)
	CampUI.close_for(self)
	for x in [events_panel, research_panel, finance_panel, stats_panel, pause_panel, settings_panel, buy_panel, credits_panel, journal_panel]:
		if x:
			x.visible = false
	LegionUi.close_for(self)


## Свиток стройки и карточка постройки не открыты вместе (как в Town to City): одно прячет другое
func _close_tray() -> void:
	if tray and tray.visible:
		open_cat = ""
		tray.visible = false
		_refresh_cat_buttons()


func _hide_info() -> void:
	if info_panel and (info_panel.visible or not info_b.is_empty() or not info_p.is_empty()):
		info_panel.visible = false
		if not info_b.is_empty():
			PersonCard.close()                # портрет «Кошачьей лавки» — долой
		info_b = {}
		if not info_p.is_empty():
			info_p = {}
			PersonCard.close()
		if game:
			game.select_building({})


# ---------- «Обзор» (вместо кругов охвата, решение владельца Д3) ----------
## Счастье каждого дома (рожица и цифра, дом подсвечен цветом) или одна потребность: где она есть (зелёные),
## где нет (красные, значок ✗), значки — лавки этого вида. Подсветку и значки ставит game.cover (cover.gd).
## Окно с режимами и легендой — справа внизу (там, где окно инструмента: при «Обзоре» инструмента нет);
## открыта карточка постройки — окно встаёт левее неё (_place_overlay), чтобы режимы и легенда оставались видны.

var overlay := ""                     # "" — выключен; "happy" — счастье; food, clothes… — одна потребность
var overlay_last := "happy"
var overlay_panel: PanelContainer
var _ov_btns := {}
var _ov_title: Label
var _ov_legend: VBoxContainer
const OV_DATIVE := {"plebs": "плебеям", "artisans": "ремесленникам", "patricians": "патрициям"}
const OV_HAS := {"food": ["Еда есть рядом", "Еды рядом нет"], "clothes": ["Одежда есть рядом", "Одежды рядом нет"],
	"fun": ["Развлечения есть рядом", "Развлечений рядом нет"], "services": ["Услуги есть рядом", "Услуг рядом нет"],
	"goods": ["Товары есть рядом", "Товаров рядом нет"], "faith": ["Храм или алтарь рядом", "Храма или алтаря рядом нет"]}


func _overlay_panel() -> void:
	overlay_panel = _panel(null, "bar", 0, 8)
	_put(overlay_panel, Control.PRESET_BOTTOM_RIGHT, Vector2(-10, -BAR_H - 10))
	overlay_panel.custom_minimum_size = Vector2(360, 0)
	overlay_panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	overlay_panel.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	var t := _label("Обзор", 21, false, C_INK, font_title)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(_bare("close", "Закрыть обзор (Esc или правая кнопка)", 30, func(): set_overlay("")))
	v.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for m: String in ["happy"] + Defs.NEED_ORDER + ["water", "classes"]:
		var mm := m
		var icon: String = String({"happy": "happy", "water": "water", "classes": "toga"}.get(m, "")) if m in ["happy", "water", "classes"] else String(Defs.NEEDS[m]["icon"])
		var tip: String = "Счастье каждого дома" if m == "happy" else ("Вода: у каких домов фонтан рядом, а у каких нет" if m == "water" \
			else ("Классы: какие дома можно перестроить в следующий класс и что мешает остальным" if m == "classes" else "%s: где есть, а где нет" % Defs.NEEDS[m]["name"]))
		var b := _round(icon, tip, 36, func(): set_overlay(mm))
		row.add_child(b)
		_ov_btns[m] = b
	v.add_child(row)
	_ov_title = _label("", 18, true, C_INK)
	v.add_child(_ov_title)
	_ov_legend = VBoxContainer.new()
	_ov_legend.add_theme_constant_override("separation", 4)
	v.add_child(_ov_legend)


## Включить «Обзор» в режиме mode ("" — выключить). Инструмент при этом убираем: стройка показывает свой охват сама
func set_overlay(mode: String) -> void:
	if mode != "" and game and game.tool != "":
		game.set_tool("")
	overlay = mode
	if mode != "":
		overlay_last = mode
		_close_tray()
	if top_btns.has("view"):
		_set_on(top_btns["view"], mode != "")
	overlay_panel.visible = mode != ""
	if game and game.cover:
		game.cover.refresh()                  # подсветка и значки; при mode != "" — и легенда (fill_overlay)
	if mode != "":
		cover_tip(true)                       # открыл «Обзор» сам — объясним сразу


## Легенда «Обзора»: что значат цвета и сколько каких домов (числа живые — после каждого пересчёта города)
func fill_overlay() -> void:
	if overlay == "" or overlay_panel == null:
		return
	for m in _ov_btns:
		_set_on(_ov_btns[m], m == overlay)
	_clear(_ov_legend)
	var block: String = game.city.arrivals_blocked()
	if block != "":
		_ov_legend.add_child(_wrap(_label(block, 14, true, C_BAD), 340))
	var s: Dictionary = game.cover.sets
	var n: Array = s.get("n", [0, 0, 0])
	if overlay == "happy":
		_ov_title.text = "Счастье каждого дома"
		_ov_row(_face("face_good", 24), "%d%% и больше — хорошо, хватит на 2-й этаж" % Cover.HAPPY_GOOD, n[0])
		_ov_row(_face("face_mid", 24), "%d–%d%% — так себе" % [Cover.HAPPY_BAD, Cover.HAPPY_GOOD - 1], n[1])
		_ov_row(_face("face_bad", 24), "Меньше %d%% — плохо" % Cover.HAPPY_BAD, n[2])
		_ov_legend.add_child(_wrap(_label("Щёлкните по дому — в карточке видно, из чего его счастье. Пустые дома не подсвечены.", 14, false, C_SOFT), 340))
	elif overlay == "water":
		_ov_title.text = "Вода"
		_ov_row(_swatch(Cover.GREEN), "Фонтан рядом: +%d%% счастья" % int(Defs.B["fountain"]["bonus"]), n[0])
		if int(n[1]) > 0:
			_ov_row(_swatch(Cover.GOLD), "Фонтан рядом не работает — нет дороги у входа", n[1])
		_ov_row(_swatch(Cover.RED), "Фонтана рядом нет", n[2])
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		r.add_child(_icon("water", 24))
		r.add_child(_wrap(_label("Значки над крышами — где стоят фонтаны", 15, false, C_INK), 300))
		_ov_legend.add_child(r)
		_ov_legend.add_child(_wrap(_label("Фонтан поит дома вокруг себя. Для «Посёлка» нужен хотя бы один. Пустые дома не подсвечены.", 14, false, C_SOFT), 340))
	elif overlay == "classes":
		_fill_overlay_classes(s, n)
	else:
		var nd: Dictionary = Defs.NEEDS[overlay]
		_ov_title.text = nd["name"]
		var who := []
		for cl in Defs.CLASS_ORDER:
			if Defs.needs_for(cl, int(game.city.level) if game and game.city else 0).has(overlay):
				who.append(OV_DATIVE.get(cl, cl))
		_ov_row(_swatch(Cover.GREEN), "Покрытие 67–100%", n[0])
		_ov_row(_swatch(Cover.GOLD), "Покрытие 34–66%", n[1])
		_ov_row(_swatch(Cover.RED), "Покрытие 0–33%", n[2])
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		r.add_child(_icon(nd["icon"], 24))
		r.add_child(_wrap(_label("Значки над крышами — где стоят нужные здания", 15, false, C_INK), 300))
		_ov_legend.add_child(r)
		_ov_legend.add_child(_wrap(_label("Нужно: %s. Пустые дома не подсвечены." % ", ".join(who), 14, false, C_SOFT), 340))
	_snug(overlay_panel)


## «Обзор → Классы»: кого можно перестроить (Д12), кому не хватает денариев, что мешает остальным; кнопка «Перестроить»
func _fill_overlay_classes(s: Dictionary, n: Array) -> void:
	var c: City = game.city
	_ov_title.text = "Классы: кого можно перестроить"
	if not c.research.has("artisans"):
		_ov_legend.add_child(_wrap(_label("Дом плебеев можно перестроить в дом ремесленников, а дом ремесленников — в городской домус. Сначала изучите «%s»." % Defs.research("artisans").get("name", ""), 15, false, C_INK), 340))
		return
	_ov_row(_drawn("upc_a", 26), "Можно перестроить сейчас (над крышей — цена)", n[0])
	_ov_row(_swatch(Cover.GOLD), "Готов, но не хватает денариев", n[1])
	_ov_row(_swatch(Cover.RED), "Что-то мешает — значок над крышей", n[2])
	if int(n[2]) > 0:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		for e: Array in [["food", "нужды класса"], ["face_bad", "счастье"], ["housing", "место позади"], ["decor", "украшения"]]:
			var ic: Control = _drawn(String(e[0]), 22) if String(e[0]).begins_with("face_") else _icon(String(e[0]), 22)
			r.add_child(ic)
			r.add_child(_label(String(e[1]), 14, false, C_SOFT))
		_ov_legend.add_child(r)
	if int(s.get("decor", 0)) > 0:
		_ov_legend.add_child(_wrap(_label("Где мешают одни украшения позади дома — в карточке дома есть «Снести мешающее» (денарии за них вернутся).", 14, false, C_SOFT), 340))
	var tail := []
	if int(s.get("top", 0)) > 0:
		tail.append("Домусов (выше класса нет): %d" % int(s["top"]))
	if int(s.get("locked", 0)) > 0:
		tail.append("домов ремесленников ждут «%s»: %d" % [Defs.research("patricians").get("name", ""), int(s["locked"])])
	if not tail.is_empty():
		var tt := "; ".join(tail)
		_ov_legend.add_child(_wrap(_label(tt.left(1).to_upper() + tt.substr(1) + ".", 14, false, C_SOFT), 340))
	var b := Button.new()
	b.text = "Перестроить (Shift+U)"
	b.name = "classes_tool"
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = UPG_TIP
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_stylebox_override("normal", _box_pill(14, 4))
	b.add_theme_stylebox_override("hover", _box_pill(14, 4, "g_btn_hover"))
	b.add_theme_stylebox_override("pressed", _box_pill(14, 4, "g_btn_on"))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func(): game.set_tool("upgrade"))
	_ov_legend.add_child(b)
	_ov_legend.add_child(_wrap(_label("Щёлкните по дому — в карточке видно, каких условий не хватает. Сам дом класс не меняет — только по вашему щелчку.", 14, false, C_SOFT), 340))


func _ov_row(mark: Control, text: String, count: int) -> void:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(mark)
	var l := _label(text, 15, false, C_INK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(l)
	r.add_child(_label("%d %s" % [count, _plural(count, "дом", "дома", "домов")], 15, true, C_SOFT))
	_ov_legend.add_child(r)


## Цветной квадратик для легенды — тот же цвет, что у подсветки домов
func _swatch(col: Color) -> Control:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(5)
	sb.set_border_width_all(2)
	sb.border_color = Color("3a2412")
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(24, 24)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Рожица, нарисованная кодом (зелёная улыбается, золотая — ровно, красная грустит)
func _face(kind: String, size := 26) -> Control:
	var f := FaceIcon.new()
	f.mood = {"face_good": 1, "face_mid": 0, "face_bad": -1}.get(kind, 0)
	f.col = {"face_good": Color("6fbf4a"), "face_mid": Color("e8b53a"), "face_bad": Color("d9553a")}.get(kind, Color("e8b53a"))
	f.custom_minimum_size = Vector2(size, size)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return f


class FaceIcon extends Control:
	var mood := 1                     # 1 — довольный, 0 — так себе, −1 — грустный
	var col := Color("6fbf4a")

	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.5
		var c := size * 0.5
		var ink := Color("3a2412")
		draw_circle(c, r, ink)
		draw_circle(c, r - maxf(1.5, r * 0.12), col)
		draw_circle(c + Vector2(-r * 0.32, -r * 0.2), r * 0.13, ink)
		draw_circle(c + Vector2(r * 0.32, -r * 0.2), r * 0.13, ink)
		var w := maxf(1.6, r * 0.14)
		match mood:
			1:
				draw_arc(c + Vector2(0, -r * 0.08), r * 0.5, PI * 0.2, PI * 0.8, 10, ink, w, true)
			-1:
				draw_arc(c + Vector2(0, r * 0.72), r * 0.42, PI * 1.22, PI * 1.78, 10, ink, w, true)
			_:
				draw_line(c + Vector2(-r * 0.34, r * 0.34), c + Vector2(r * 0.34, r * 0.34), ink, w, true)


## Золотая стрелка вверх, нарисованная кодом: «можно надстроить этаж» (над крышей и на кнопке «Этаж»).
## dbl — двойной шеврон «Перестроить» (Д12) цвета нового класса: медный — ремесленники, лиловый — патриции
class UpArrow extends Control:
	var dbl := false
	var col := Color("f2c14e")

	func _draw() -> void:
		if dbl:
			var ink := Color("3a2412")
			var w := maxf(1.5, minf(size.x, size.y) * 0.08)
			for k in 2:
				var y0 := 0.06 + k * 0.42
				var ch := PackedVector2Array()
				for p: Vector2 in [Vector2(0.5, y0), Vector2(0.97, y0 + 0.4), Vector2(0.72, y0 + 0.5), Vector2(0.5, y0 + 0.3), Vector2(0.28, y0 + 0.5), Vector2(0.03, y0 + 0.4)]:
					ch.append(p * size)
				draw_colored_polygon(ch, col if k == 0 else col.darkened(0.15))
				draw_colored_polygon(PackedVector2Array([Vector2(0.5, y0 + 0.08) * size, Vector2(0.5, y0 + 0.26) * size, Vector2(0.2, y0 + 0.4) * size]), col.lightened(0.35))
				var ln := ch.duplicate()
				ln.append(ch[0])
				draw_polyline(ln, ink, w, true)
			return
		var pts := PackedVector2Array()
		for p: Vector2 in [Vector2(0.5, 0.03), Vector2(0.97, 0.5), Vector2(0.69, 0.5), Vector2(0.69, 0.97), Vector2(0.31, 0.97), Vector2(0.31, 0.5), Vector2(0.03, 0.5)]:
			pts.append(p * size)
		draw_colored_polygon(pts, Color("f2c14e"))
		# светлый блик слева — как у рисованных медальонов
		draw_colored_polygon(PackedVector2Array([Vector2(0.5, 0.12) * size, Vector2(0.5, 0.5) * size, Vector2(0.16, 0.44) * size]), Color("fde39a"))
		var ln := pts.duplicate()
		ln.append(pts[0])
		draw_polyline(ln, Color("3a2412"), maxf(1.5, minf(size.x, size.y) * 0.08), true)


## Значок, нарисованный кодом: рожица (face_good | face_mid | face_bad) или стрелка вверх (up); иначе null
func _drawn(icon: String, size: int) -> Control:
	if icon.begins_with("face_"):
		return _face(icon, size)
	if icon == "up" or icon.begins_with("upc"):
		var a := UpArrow.new()
		if icon.begins_with("upc"):
			a.dbl = true
			a.col = UPC_COL.get(icon, Color("f2c14e"))
		a.custom_minimum_size = Vector2(size * 0.8, size)
		a.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return a
	return null


# ---------- рожицы после стройки (как в Town to City): над домами, чьё счастье поменялось, — «+5%» и улыбка ----------
# Пул POPS готовых плашек в слое значков: всплывают с задержкой (волна от постройки), поднимаются на 40 точек и гаснут

const POP_T := 2.2                    # сколько живёт рожица, с
const POP_RISE := 40.0                # на сколько точек поднимается
var _pops: Array = []                 # [{n: плашка, face, lbl, pos: точка мира, t0: когда всплыть (мс), on}]


func happy_pop(pos: Vector3, delta: int, delay := 0.0) -> void:
	var e: Dictionary = {}
	for p: Dictionary in _pops:
		if not p["on"]:
			e = p
			break
	if e.is_empty():
		if _pops.size() < Game.POPS_MAX:
			e = _make_pop()
			_pops.append(e)
		else:
			# все заняты — берём ту, что всплыла раньше всех
			e = _pops[0]
			for p: Dictionary in _pops:
				if int(p["t0"]) < int(e["t0"]):
					e = p
	var good := delta > 0
	var f: FaceIcon = e["face"]
	f.mood = 1 if good else -1
	f.col = Color("6fbf4a") if good else Color("d9553a")
	f.queue_redraw()
	var l: Label = e["lbl"]
	l.text = _pct(delta)
	l.add_theme_color_override("font_color", Color("c9ffb0") if good else Color("ffb7a3"))
	e["pos"] = pos
	e["t0"] = Time.get_ticks_msec() + int(delay * 1000.0)
	e["on"] = true
	(e["n"] as Control).visible = false


func _make_pop() -> Dictionary:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := _face("face_good", 24) as FaceIcon
	f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(f)
	var l := _label("", 18, true, C_CREAM)
	l.add_theme_color_override("font_outline_color", Color("2a1a0c"))
	l.add_theme_constant_override("outline_size", 7)
	h.add_child(l)
	h.visible = false
	badge_layer.add_child(h)
	return {"n": h, "face": f, "lbl": l, "pos": Vector3.ZERO, "t0": 0, "on": false}


## Сколько рожиц сейчас в деле (ждут своей очереди или всплывают) — для проверок
func pops_active() -> int:
	var n := 0
	for p: Dictionary in _pops:
		if p["on"]:
			n += 1
	return n


func _place_pops() -> void:
	if _pops.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	var now := Time.get_ticks_msec()
	var show: bool = cam != null and root.visible and not hidden_ui and not (game.rig != null and game.rig.cine)
	for p: Dictionary in _pops:
		if not p["on"]:
			continue
		var n: Control = p["n"]
		var t := float(now - int(p["t0"])) / 1000.0
		if t > POP_T:
			p["on"] = false
			n.visible = false
			continue
		var w: Vector3 = p["pos"]
		if t < 0.0 or not show or cam.is_position_behind(w):
			n.visible = false
			continue
		var k := t / POP_T
		var pt := cam.unproject_position(w)
		n.reset_size()
		n.position = (pt - Vector2(n.size.x * 0.5, n.size.y) - Vector2(0, POP_RISE * ease(k, 0.5))).round()
		# быстро проявляется, держится, мягко гаснет; в начале чуть больше — «выпрыгивает»
		n.modulate.a = clampf(t / 0.15, 0.0, 1.0) * clampf((POP_T - t) / 0.8, 0.0, 1.0)
		n.pivot_offset = n.size * 0.5
		n.scale = Vector2.ONE * (1.0 + 0.25 * maxf(0.0, 1.0 - t / 0.25))
		n.visible = true


# ---------- «НОВОЕ» (как в Town to City): открылось исследованием или рангом, а игрок ещё не смотрел ----------
# Карточка — пока на неё не навели мышь (0,4 с) или не взяли; исследование — пока не навели или не закрыли окно;
# разделы, вкладки, кнопка исследований и «Этаж» — пока внутри есть новое (City.is_new, tips.seen — в сохранении)

## Пометка на кнопке b: "top" — плашка «НОВОЕ» над медальоном, "bottom" — под ним, "card" — в углу карточки,
## "dot" — красная точка (узкие вкладки)
func _new_pill(b: Control, where: String) -> Control:
	var p: Control
	if where == "dot":
		var d := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("d0432c")
		sb.set_corner_radius_all(8)
		sb.set_border_width_all(2)
		sb.border_color = C_CREAM
		d.add_theme_stylebox_override("panel", sb)
		d.size = Vector2(15, 15)
		d.position = Vector2(b.custom_minimum_size.x - 13, -3)
		p = d
	else:
		var pc := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("c4402a")
		sb.set_corner_radius_all(6)
		sb.set_border_width_all(2)
		sb.border_color = Color("fbe6b0")
		sb.content_margin_left = 5
		sb.content_margin_right = 5
		sb.content_margin_top = 0
		sb.content_margin_bottom = 1
		pc.add_theme_stylebox_override("panel", sb)
		pc.add_child(_label("НОВОЕ", 11, true, C_CREAM))
		pc.reset_size()
		var w := b.custom_minimum_size.x
		var sz := pc.get_combined_minimum_size()
		match where:
			"card":
				pc.position = Vector2(w - sz.x - 9, 44)       # в углу картинки, под названием (название не закрывает)
			"corner":
				pc.position = Vector2(w - sz.x * 0.5 - 6, -8)
			"bottom":
				pc.position = Vector2((w - sz.x) * 0.5, b.custom_minimum_size.y - sz.y + 6)
			_:
				pc.position = Vector2((w - sz.x) * 0.5, -sz.y + 6)
		p = pc
	p.name = "new_mark"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in p.find_children("*", "Control", true, false):
		(ch as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.visible = false
	b.add_child(p)
	return p


func _show_new(b: Control, on: bool) -> void:
	var p := b.get_node_or_null("new_mark") as Control
	if p and p.visible != on:
		p.visible = on


## Пометки «НОВОЕ» на разделах, вкладках, кнопках исследований и «Этаж», на карточках открытого свитка
func update_new_marks() -> void:
	if game == null or game.city == null:
		return
	var c: City = game.city
	var play: bool = game.mode in ["new", "play"]
	var n: Dictionary = c.new_counts() if play else {}
	for cid in cats:
		_show_new(cats[cid], int(n.get(cid, 0)) > 0)
	for b in tray_tabs.get_children():
		_show_new(b, int(n.get("commerce|" + String(b.get_meta("sub")), 0)) > 0)
	for b in tray_stabs.get_children():
		var key := "special|wonders" if b.get_meta("sub") == "wonders" else "special|"
		_show_new(b, int(n.get(key, 0)) > 0)
	for b in tray_dtabs.get_children():
		_show_new(b, int(n.get("decor|" + String(b.get_meta("sub")), 0)) > 0)
	_show_new(top_btns["research"], play and c.new_research() > 0)
	_show_new(tool_btns["floor"], play and c.is_new("@floor") and c.floor_ready(false).is_empty())
	floor_badge.visible = true      # число готовых домов видно и до первого использования
	_show_new(tool_btns["upgrade"], play and c.research.has("artisans") and c.is_new("@upgrade"))
	upg_badge.visible = not (play and c.research.has("artisans") and c.is_new("@upgrade"))
	for b in tray_grid.get_children():
		if b.has_meta("type"):
			_show_new(b, play and c.is_new(b.get_meta("type")))


## Мышь на карточке 0,4 с — карточку посмотрели: «НОВОЕ» с неё снимается
func _card_hovered(b: Button, type: String) -> void:
	if not (game.mode in ["new", "play"]) or not game.city.is_new(type):
		return
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(b) and b.is_hovered() and game.city.mark_seen(type):
		update_new_marks()


# ---------- подпись у курсора, пока ставят лавку (сколько новых домов, сколько уже с такой же) ----------

var cover_box: VBoxContainer
var _cover_l: Array = []              # строки: зелёная, синяя, третья — предупреждение или заметка (кремовая)


func cover_caption(green: String, blue: String, soft := "") -> void:
	_cap3 = [green, blue, soft]
	_caption_refresh()


## Четвёртая строка у курсора — тихий статус инструмента: «Прямая» (прямая линия дороги), «В счёт скверика ✓» /
## «Далеко от дома — не в счёт» (цель истории рядом с домом). "" — нет. Ставит game._update_tool каждый кадр
func cursor_note(text: String, col := Color("fff4dc")) -> void:
	if text == _note and col == _note_col:
		if text != "" and cover_box and cover_box.visible:
			_place_caption()
		return
	_note = text
	_note_col = col
	_caption_refresh()


var _cap3 := ["", "", ""]
var _note := ""
var _note_col := Color("fff4dc")
var _err := ""                            # пятая строка — что не так с местом постройки, красным (3.5)
var _hint := false                        # значок поворота «Z / X» — первые 3 постановки (3.5)
var _hint_row: HBoxContainer


## Почему здесь не поставить — у курсора одной короткой красной строкой (тот же текст, что в панели, тем же кадром);
## hint — показать значок поворота «Z / X»
func cursor_error(text: String, hint := false) -> void:
	if text == _err and hint == _hint:
		return
	_err = text
	_hint = hint
	_caption_refresh()


func _caption_refresh() -> void:
	if cover_box == null:
		cover_box = VBoxContainer.new()
		cover_box.add_theme_constant_override("separation", 3)
		cover_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for col in [Color("b4ffae"), Color("a9d4ff"), Color("ffe3a3"), Color("fff4dc"), Color("ffab96")]:
			var l := _label("", 19, true, col)
			l.add_theme_color_override("font_outline_color", Color("2a1a0c"))
			l.add_theme_constant_override("outline_size", 8)
			l.visible = false
			cover_box.add_child(l)
			_cover_l.append(l)
		_hint_row = HBoxContainer.new()
		_hint_row.add_theme_constant_override("separation", 4)
		_hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hi := TextureRect.new()
		hi.texture = load(AI + "cursors/rotate.png")
		hi.custom_minimum_size = Vector2(26, 26)
		hi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hi.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hint_row.add_child(hi)
		var hl := _label("Z / X — повернуть", 17, true, Color("fff4dc"))
		hl.add_theme_color_override("font_outline_color", Color("2a1a0c"))
		hl.add_theme_constant_override("outline_size", 8)
		_hint_row.add_child(hl)
		_hint_row.visible = false
		cover_box.add_child(_hint_row)
		cover_box.visible = false
		root.add_child(cover_box)
	var tx := [_cap3[0], _cap3[1], _cap3[2], _note, _err]
	var on := false
	var changed := false
	if _hint_row.visible != _hint:
		_hint_row.visible = _hint
		changed = true
	on = _hint
	for i in 5:
		var l: Label = _cover_l[i]
		on = on or tx[i] != ""
		if l.text != tx[i]:
			l.text = tx[i]
			l.visible = tx[i] != ""
			changed = true
	(_cover_l[3] as Label).add_theme_color_override("font_color", _note_col)
	if changed:
		cover_box.reset_size()
	if cover_box.visible != on:
		cover_box.visible = on
	if on:
		_place_caption()


## Подпись справа снизу от курсора; не влезает — по другую сторону курсора, и всегда целиком на экране
func _place_caption() -> void:
	var mp: Vector2 = game._mouse_pos if game._mouse_pos.x >= 0.0 else root.get_local_mouse_position()
	var sz := cover_box.get_combined_minimum_size()
	var p := mp + Vector2(30, 26)
	if p.x + sz.x > root.size.x - 6.0:
		p.x = mp.x - 18.0 - sz.x
	if p.y + sz.y > root.size.y - 6.0:
		p.y = mp.y - 14.0 - sz.y
	p.x = clampf(p.x, 6.0, maxf(6.0, root.size.x - sz.x - 6.0))
	p.y = clampf(p.y, 6.0, maxf(6.0, root.size.y - sz.y - 6.0))
	# подписи не ложатся на окно выбранной постройки и карточки справа: уходят левее них, а нет места — выше
	for pn: Control in [tool_panel, info_panel, overlay_panel]:
		if pn == null or not pn.visible:
			continue
		var r := Rect2(pn.global_position, pn.size).grow(6.0)
		if Rect2(p, sz).intersects(r):
			var left := r.position.x - sz.x
			if left >= 6.0:
				p.x = left
			else:
				p.y = maxf(6.0, r.position.y - sz.y)
	cover_box.position = p.round()


## Советник один раз (tips.cover_tip): кругов охвата больше нет — подсветка домов, и есть «Обзор»
func cover_tip(by_player := false) -> void:
	var c: City = game.city
	if c.tips.has("cover_tip") or not _tip_free(not by_player):
		return
	c.tips["cover_tip"] = true
	advisor("Кому достанется лавка", "Кругов охвата больше нет — смотрите на цвет домов. Пока ставите лавку, зелёные дома получат её впервые, а синие уже снабжает такая же лавка: вторая такая же им ничего не прибавит. У курсора написано, сколько новых домов, а значки над крышами показывают, где такие лавки уже стоят. С памятниками и украшениями так же: зелёным домам станет лучше.\n\nОткройте «Обзор города» → «Город» → «Счастье на карте»: там видно счастье домов и наличие нужных лавок.")


## Кнопка «Фото» — режим фото (scripts/photo_mode.gd): интерфейс прячется, наклон, время суток, размытие, снимок
# ---------- «чистый экран» (клавиша H): весь интерфейс прячется, остаётся крошечная подсказка ----------

var clean := false
var clean_hint: Label


func toggle_clean() -> void:
	if game == null or (menu_root != null and menu_root.visible) or (game.get("photo") != null and game.photo.on):
		return
	clean = not clean
	root.visible = not clean
	if badge_layer != null:
		badge_layer.visible = not clean
	hidden_ui = clean
	if clean_hint == null:
		clean_hint = _label("", 14, true, C_CREAM)
		clean_hint.add_theme_color_override("font_outline_color", Color("3a2412"))
		clean_hint.add_theme_constant_override("outline_size", 5)
		clean_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		clean_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
		clean_hint.offset_left = 10.0
		clean_hint.offset_top = -26.0
		clean_hint.offset_bottom = -6.0
		add_child(clean_hint)
	clean_hint.text = I18n.t("H — вернуть интерфейс")
	clean_hint.visible = clean
	clean_hint.modulate.a = 1.0
	if clean:
		var tw := clean_hint.create_tween()
		tw.tween_interval(3.0)
		tw.tween_property(clean_hint, "modulate:a", 0.35, 1.0)
	else:
		_fit_top()


func _photo() -> void:
	if game and game.get("photo") != null:
		game.photo.toggle()


# ---------- снизу ----------

func _bottom_left() -> void:
	bar_left = _panel(null, "bar", 0, 1)
	_put(bar_left, Control.PRESET_BOTTOM_LEFT, Vector2(10, -6))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	bar_left.add_child(h)
	for t: Array in [["roads", "road", "Дороги"], ["ground", "flower", "Земля"], ["grass", "daisy", "Трава"]]:
		var group: String = t[0]
		var b := _round(t[1], t[2], 52, func(): _toggle_road_group(group))
		h.add_child(b)
		road_groups[group] = b
		if group == "ground":
			road_btns["ground"] = b
	# Общая панель хранит прежние имена настроек; содержимое зависит от выбранной группы.
	road_panel = _panel(null, "bar", 0, 6)
	road_panel.custom_minimum_size = Vector2(420, 170)
	_put(road_panel, Control.PRESET_BOTTOM_LEFT, Vector2(10, -BAR_H - 10))
	road_panel.visible = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	road_panel.add_child(vb)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	vb.add_child(body)
	var swatches := GridContainer.new()
	swatches.name = "road_swatches"
	swatches.columns = 2
	swatches.add_theme_constant_override("h_separation", 6)
	swatches.add_theme_constant_override("v_separation", 6)
	swatches.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(swatches)
	for t: Array in [["road", "road", "Мостовая: каменная улица"], ["path", "path", "Тропа: утоптанная дорожка — почти даром"],
			["cobble", "road", "Булыжник: тёплая каменная улица"], ["footpath", "path", "Плиточная дорожка: камни среди травы — почти даром"],
			["plaza", "plaza", "Площадь из узорной плитки"],
			["roadup", "hammer", "Улучшить дорогу: тропа станет мостовой, мостовая — каменными плитами, площадь — травертином"]]:
		var tn: String = t[0]
		var b := _road_swatch(tn, t[1], t[2])
		if tn == "roadup":
			# Пустое место остаётся в сетке, даже пока исследование не открыло кнопку.
			var cell := VBoxContainer.new()
			cell.custom_minimum_size = Vector2(56, 56)
			swatches.add_child(cell)
			b.name = "upgrade_box"
			b.visible = game.city.research.has(Defs.ROAD_UP_RES)
			cell.add_child(b)
		else:
			swatches.add_child(b)
	var grass := HBoxContainer.new()
	grass.name = "grass_swatches"
	grass.add_theme_constant_override("separation", 6)
	grass.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grass.visible = false
	grass.add_child(_road_swatch("grass", "daisy", "Посадить: густая трава и цветы"))
	grass.add_child(_road_swatch("ungrass", "eraser", "Убрать: стереть траву и цветы"))
	body.add_child(grass)
	var settings := VBoxContainer.new()
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.add_theme_constant_override("separation", 4)
	body.add_child(settings)
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 8)
	var sl := HSlider.new()
	sl.min_value = 0.5
	sl.max_value = 4.0
	sl.step = 0.25
	sl.custom_minimum_size = Vector2(160, 26)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.tooltip_text = "Размер кисти ([ / ])"
	sl.value = game.brush_r
	sl.value_changed.connect(func(x): game.brush_r = x; refresh_tools())
	sl.name = "size"
	r1.add_child(sl)
	var sv := _label("", 17, true)
	sv.name = "size_val"
	sv.custom_minimum_size = Vector2(34, 0)
	r1.add_child(sv)
	settings.add_child(r1)
	var r2 := HBoxContainer.new()
	r2.name = "brush_options"
	r2.add_theme_constant_override("separation", 4)
	for t: Array in [["linefree", "Рисовать свободно"], ["linestraight", "Прямая линия: от точки до точки"], ["brushround", "Круглая кисть"], ["brushsquare", "Квадратная кисть"]]:
		var nm: String = t[0]
		var b := _round(nm, t[1], 36, func(): _road_opt(nm))
		r2.add_child(b)
		road_btns[nm] = b
	settings.add_child(r2)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	var eraser := _round("eraser", "Ластик: стереть дорогу или узор земли", 32, func(): game.set_tool("erase"))
	road_btns["erase"] = eraser
	actions.add_child(eraser)
	for nm: String in ["undo", "redo"]:
		var b := _round(nm, "Отменить (Ctrl+Z)" if nm == "undo" else "Вернуть (Ctrl+Y)", 32, func(): _road_opt(nm))
		actions.add_child(b)
		road_btns[nm] = b
	var over := CheckBox.new()
	over.text = "Поверх (R)"
	over.tooltip_text = "Рисовать поверх других дорог (R)"
	over.button_pressed = true
	over.add_theme_font_size_override("font_size", 14)
	over.toggled.connect(func(x): game.brush_over = x)
	over.name = "over"
	road_btns["over"] = over
	actions.add_child(over)
	settings.add_child(actions)
	var price := _label("", 14, false, C_SOFT)
	price.name = "price"
	price.mouse_filter = Control.MOUSE_FILTER_PASS
	price.clip_text = true
	price.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	settings.add_child(price)
	var lt := _label("", 13, false, C_SOFT)
	lt.name = "line_tip"
	lt.mouse_filter = Control.MOUSE_FILTER_PASS
	lt.clip_text = true
	lt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lt.visible = false
	settings.add_child(lt)
	# Кисть «Земля»: прежний выбор узора и общие настройки кисти.
	var gr := HBoxContainer.new()
	gr.name = "ground_row"
	gr.add_theme_constant_override("separation", 6)
	gr.visible = false
	for gi in Defs.GROUND.size():
		var gk := gi
		var gb := Button.new()
		gb.custom_minimum_size = Vector2(44, 44)
		gb.focus_mode = Control.FOCUS_NONE
		gb.tooltip_text = "%s — %s" % [Defs.GROUND[gi][0], String(Defs.GROUND[gi][1]).to_lower()]
		for st in ["normal", "hover", "pressed"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = GROUND_COL[gi]
			sb.set_corner_radius_all(22)
			sb.set_border_width_all(3 if st == "normal" else 4)
			sb.border_color = Color("6b4a2a") if st == "normal" else C_GOLD
			gb.add_theme_stylebox_override(st, sb)
		gb.pressed.connect(func(): game.ground_kind = gk; refresh_tools())
		gb.name = "g%d" % gi
		gr.add_child(gb)
	vb.add_child(gr)


## Квадратный образец использует те же рисованные рамки и иконки, что остальные кнопки.
func _road_swatch(t: String, icon_name: String, tip: String) -> Button:
	var b := _round(icon_name, tip, 56, func(): game.set_tool(t))
	b.set_meta("swatch", true)
	if t in ["cobble", "footpath"]:
		# Свой образец вместо одинаковых значков дороги и тропы.
		var texture_name := "Cobblestone_Texture_01" if t == "cobble" else "Footpath_Tiles_Texture_01"
		var face := b.get_node("ic") as TextureRect
		face.texture = load("res://assets/synty_meadow/Textures/Terrain/" + texture_name + ".png")
		face.modulate = Color(0.91, 0.85, 0.73)
	for st: Array in [["normal", "g_btn"], ["hover", "g_btn_hover"], ["pressed", "g_btn_on"], ["hover_pressed", "g_btn_on"]]:
		b.add_theme_stylebox_override(st[0], _box_pill(5, 5, st[1]))
	road_btns[t] = b
	return b


## Повторное нажатие закрывает панель и снимает кисть; при открытии возвращаем последний инструмент группы.
func _toggle_road_group(group: String) -> void:
	if road_panel.visible and _road_group(String(game.tool)) == group:
		game.set_tool("")
		return
	var t := "ground"
	if group == "roads":
		t = _last_road_tool
		if t == "roadup" and not game.city.research.has(Defs.ROAD_UP_RES):
			t = "road"
	elif group == "grass":
		t = _last_grass_tool
	game.set_tool(t)


func _road_group(t: String) -> String:
	if t == "ground":
		return "ground"
	if t in ["grass", "ungrass"]:
		return "grass"
	return "roads" if t in ["road", "path", "plaza", "cobble", "footpath", "erase", "roadup"] else ""


## Стрелка обучения и просьб: сначала открыть группу, затем выбрать мостовую.
func road_target() -> Control:
	var b := road_btns.get("road") as Control
	return b if b != null and b.is_visible_in_tree() else (road_groups.get("roads") as Control)


## Кружки кисти «Земля» (Defs.GROUND): обычная трава, сочная, луг, песок, глина, гравий
const GROUND_COL := [Color("6d7d36"), Color("3f5a1e"), Color("8c9a3e"), Color("dccb9c"), Color("8a5a32"), Color("a19b8e")]


func _road_opt(nm: String) -> void:
	match nm:
		"linefree", "linestraight":
			game.brush_line = nm == "linestraight" and not game.is_grass_tool(game.tool)
			# у дорог и у ластика — своя «Прямая линия»; помнится и после перезапуска
			game.settings["line_erase" if game.tool == "erase" else "line_road"] = game.brush_line
			_store_settings()
		"brushround": game.brush_square = false
		"brushsquare": game.brush_square = true
		"undo": game._undo("road")
		"redo": game._redo()
	refresh_tools()
	refresh_undo()


func refresh_tools() -> void:
	_refresh_brush()
	_fill_tool_panel()


## Кисть дороги: какой способ и форма выбраны, размер, «поверх других дорог»
func _refresh_brush() -> void:
	if road_btns.has("linefree"):
		_set_on(road_btns["linefree"], not game.brush_line)
		_set_on(road_btns["linestraight"], game.brush_line)
		_set_on(road_btns["brushround"], not game.brush_square)
		_set_on(road_btns["brushsquare"], game.brush_square)
		(road_btns["over"] as CheckBox).set_pressed_no_signal(game.brush_over)
		var lt := road_panel.find_child("line_tip", true, false) as Label
		if lt:
			# что сейчас будет: прямая ложится при отпускании, свободная — сразу под кистью
			lt.text = ("Дорога ляжет при отпускании" if game.tool != "erase" else "Ластик сотрёт при отпускании") if game.brush_line else ""
			lt.tooltip_text = "Прямая линия: нажмите в начале и отпустите в конце. Рисовать свободно — сразу под кистью."
			lt.visible = not lt.text.is_empty()
		(road_panel.find_child("size", true, false) as HSlider).set_value_no_signal(game.brush_r)
		(road_panel.find_child("size_val", true, false) as Label).text = ("%.2f" % game.brush_r).trim_suffix("0").replace(".", ",")
		var t: String = game.tool
		var group := _road_group(t)
		(road_panel.find_child("road_swatches", true, false) as Control).visible = group == "roads"
		(road_panel.find_child("grass_swatches", true, false) as Control).visible = group == "grass"
		(road_panel.find_child("brush_options", true, false) as Control).visible = group != "grass"
		(road_btns["erase"] as Button).visible = group != "grass"
		road_panel.custom_minimum_size = Vector2(420, 100 if group == "grass" else 170)
		var pl := road_panel.find_child("price", true, false) as Label
		var strip := 2.0 * float(game.brush_r) / Land.CELL / Land.CELL     # клеток в метре полосы
		if Defs.ROAD_COST.has(t):
			pl.text = "Метр — около %s ден. (полоса %s м)" % [price_txt(road_price_m(t)), ("%.1f" % (game.brush_r * 2.0)).replace(".", ",")]
		elif t == "roadup":
			pl.text = "Метр: тропа → мостовая ~%s · мостовая → плиты ~%s · площадь → травертин ~%s ден." % [price_txt(strip * float(Defs.ROAD_UP["path"])),
				price_txt(strip * float(Defs.ROAD_UP["road"])), price_txt(strip * float(Defs.ROAD_UP["plaza"]))]
		elif t == "ground":
			pl.text = "«%s» · метр — около %s ден." % [Defs.GROUND[game.ground_kind][0], price_txt(strip * Defs.GROUND_COST)]
		elif game.is_grass_tool(t):
			pl.text = "Бесплатно"
		else:
			pl.text = "Стирать дорогу — бесплатно" if t == "erase" else ""
		pl.tooltip_text = pl.text
		pl.visible = pl.text != ""
		(road_btns["over"] as CheckBox).visible = not game.is_deco_tool(t) and not game.is_grass_tool(t)
		var gr := road_panel.find_child("ground_row", true, false) as HBoxContainer
		gr.visible = t == "ground"
		for gb: Button in gr.get_children():
			var on := gb.name == "g%d" % game.ground_kind
			(gb.get_theme_stylebox("normal") as StyleBoxFlat).border_color = C_GOLD if on else Color("6b4a2a")
			(gb.get_theme_stylebox("normal") as StyleBoxFlat).set_border_width_all(5 if on else 3)
		_snug(road_panel)


func _bottom_center() -> void:
	var p := _panel(null, "bar", 0, 1)
	_put(p, Control.PRESET_CENTER_BOTTOM, Vector2(0, -6))
	bar_mid = p
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	for c: Array in Defs.CATS:
		var cid: String = c[0]
		var short: String = Defs.CAT_SHORT.get(cid, c[1])
		var v := _round_lbl(c[2], short, c[1], 46, func(): _toggle_cat(cid))
		h.add_child(v)
		cats[cid] = v.get_meta("btn")
		_new_pill(cats[cid], "top")
	# свиток с карточками над разделами (разворачивается)
	tray = _panel(null, "scroll_h", 0, 5)
	_put(tray, Control.PRESET_CENTER_BOTTOM, Vector2(0, -BAR_H))

	tray.visible = false
	tray.clip_contents = true
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	tray.add_child(v)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 10)
	tray_title = _label("", 22, false, C_INK, font_title)
	top.add_child(tray_title)
	tray_tabs = HBoxContainer.new()
	tray_tabs.add_theme_constant_override("separation", 4)
	top.add_child(tray_tabs)
	v.add_child(top)
	for n in Defs.NEED_ORDER:
		if n == "faith":
			continue
		var nn: String = n
		var b := _round(Defs.NEEDS[n]["icon"], Defs.NEEDS[n]["name"], 40, func(): open_sub = nn; _fill_cards())
		b.set_meta("sub", nn)
		tray_tabs.add_child(b)
		_new_pill(b, "dot")
	tray_stabs = HBoxContainer.new()
	tray_stabs.name = "monument_groups"
	tray_stabs.add_theme_constant_override("separation", 6)
	top.add_child(tray_stabs)
	for group: Array in [["monuments", "Памятники"], ["wonders", "Чудеса"]]:
		var sub: String = group[0]
		var b := _tchip(String(group[1]), String(group[1]), func(): open_ssub = sub; _fill_cards())
		b.set_meta("sub", sub)
		tray_stabs.add_child(b)
		_new_pill(b, "dot")
	tray_dtabs = HBoxContainer.new()
	tray_dtabs.add_theme_constant_override("separation", 4)
	top.add_child(tray_dtabs)
	for ds: Array in Defs.DECOR_SUBS:
		var dn: String = ds[0]
		var b := _round(ds[2], ds[1], 40, func(): open_dsub = dn; decor_mode = ""; _clear_search(); _fill_cards())
		b.set_meta("sub", dn)
		tray_dtabs.add_child(b)
		_new_pill(b, "dot")
	_decor_tools(v)
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.name = "scroll"
	sc.gui_input.connect(_pan_sideways.bind(sc))
	v.add_child(sc)
	tray_grid = HBoxContainer.new()
	tray_grid.add_theme_constant_override("separation", 10)
	sc.add_child(tray_grid)


## Свиток стройки помещается между панелью кисти слева и окном инструмента справа.
## Пока они открыты, свиток уже; лишние карточки листаются вбок
func _fit_tray() -> void:
	if tray == null or not tray.visible or _tray_w <= 0.0:
		return
	var sc := tray.find_child("scroll", true, false) as Control
	if sc == null:
		return
	var vw := root.size.x
	var w := _tray_w
	var dx := 0.0
	var frame: float = tray.get_theme_stylebox("panel").get_minimum_size().x       # рамка свитка по бокам
	var left_min := 10.0
	var right_edge := vw - 10.0
	if road_panel != null and road_panel.visible:
		left_min += maxf(road_panel.size.x, road_panel.get_combined_minimum_size().x) + 12.0
	if tool_panel != null and tool_panel.visible:
		var tw := maxf(tool_panel.size.x, tool_panel.get_combined_minimum_size().x)
		right_edge -= tw + 12.0
	if left_min > 10.0 or right_edge < vw - 10.0:
		var avail := right_edge - left_min
		w = minf(w, maxf(160.0, avail - frame))
		var full := w + frame
		var center := clampf(vw * 0.5, left_min + full * 0.5, right_edge - full * 0.5)
		dx = center - vw * 0.5
	var key := "%d|%d|%d" % [int(w), int(dx), int(vw)]
	if key == _tray_key:
		return
	_tray_key = key
	sc.custom_minimum_size = Vector2(w, _tray_h + (18.0 if w < _tray_w - 1.0 and _tray_h < CARD.y + 10.0 else 0.0))
	_put(tray, Control.PRESET_CENTER_BOTTOM, Vector2(dx, -BAR_H))          # равные отступы: размер — по содержимому (reset_size тут сломал бы это)


## Трекпад Mac: свиток стройки листается вбок, а пальцы по привычке ведут вверх-вниз — такой жест тоже листает его
## вбок (колёсико мыши ScrollContainer и так листает вбок, когда прокрутки вверх-вниз нет; жест сам — только вбок).
## На Windows жестов нет — там ничего не меняется
func _pan_sideways(ev: InputEvent, sc: ScrollContainer) -> void:
	if not ev is InputEventPanGesture:
		return
	var d := (ev as InputEventPanGesture).delta
	if absf(d.y) <= absf(d.x):
		return                                # вбок — листает сам ScrollContainer
	var hs := sc.get_h_scroll_bar()
	var before := hs.value
	hs.value += hs.page * d.y / 8.0           # как ScrollContainer (ScrollBar::PAGE_DIVISOR = 8)
	if hs.value != before:
		sc.accept_event()


func _bottom_right() -> void:
	var p := _panel(null, "bar", 0, 1)
	_put(p, Control.PRESET_BOTTOM_RIGHT, Vector2(-10, -6))
	bar_right = p
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 0)
	p.add_child(pv)
	# «Казна полна» и «Полки полны» — над счётчиками, только пока доход или очки пропадают
	full_money = _label("Казна полна — доход пропадает", 14, true, C_BAD)
	full_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	full_money.mouse_filter = Control.MOUSE_FILTER_PASS
	full_money.tooltip_text = "Казна заполнена до предела — новые денарии пропадают. Потратьте их: дома, этажи, лавки, памятники, украшения, игры в честь богов (с уровня «Посёлок» — в карточке почтовой станции), новые участки земли. Предел растёт с уровнем города и исследованиями хранилищ."
	full_money.visible = false
	pv.add_child(full_money)
	empty_money = _label("Казна пуста — жалованье не плачено", 14, true, C_BAD)
	empty_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	empty_money.mouse_filter = Control.MOUSE_FILTER_PASS
	empty_money.tooltip_text = EMPTY_TIP
	empty_money.visible = false
	pv.add_child(empty_money)
	full_rp = _label("Полки полны — очки пропадают", 14, true, C_BAD)
	full_rp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	full_rp.mouse_filter = Control.MOUSE_FILTER_PASS
	full_rp.tooltip_text = "Очков исследований столько, сколько вмещают полки, — новые пропадают. Изучите что-нибудь в свитке исследований вверху справа."
	full_rp.visible = false
	pv.add_child(full_rp)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	pv.add_child(h)
	for t: Array in [["floor", "housing", "Этаж", FLOOR_TIP], ["upgrade", "housing", "Перестроить", UPG_TIP], ["copy", "copy", "Копия", "Копировать постройку (Ctrl+C) — тот же облик, цвет и поворот. Быстро: наведите на постройку и нажмите F"], ["move", "move", "Перенос", "Перенести постройку, дерево или камень (M)"],
			["bulldoze", "demolish", "Снос", "Снос (Delete): постройки, деревья, камни"]]:
		var tn: String = t[0]
		var v := _round_lbl(t[1], t[2], t[3], 42, func(): game.set_tool("" if game.tool == tn else tn))
		h.add_child(v)
		tool_btns[tn] = v.get_meta("btn")
	# «Этаж»: на доме — золотая стрелка вверх; число — сколько домов готовы к этажу; «НОВОЕ» — пока инструмент не брали
	var fb: Button = tool_btns["floor"]
	var ar := UpArrow.new()
	ar.name = "up"
	ar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ar.position = Vector2(23, 20)
	ar.size = Vector2(15, 17)
	fb.add_child(ar)
	floor_badge = _label("", 15, true, C_GOOD)
	floor_badge.add_theme_color_override("font_outline_color", C_INK)
	floor_badge.add_theme_constant_override("outline_size", 9)
	floor_badge.position = Vector2(29, -4)
	fb.add_child(floor_badge)
	_new_pill(fb, "top")
	# «Перестроить» (Д12): на доме — двойная стрелка; число — сколько домов готовы стать следующим классом
	var ub: Button = tool_btns["upgrade"]
	var ua := UpArrow.new()
	ua.name = "up"
	ua.dbl = true
	ua.col = UPC_COL["upc_a"]
	ua.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ua.position = Vector2(23, 18)
	ua.size = Vector2(15, 19)
	ub.add_child(ua)
	upg_badge = _label("", 15, true, C_CREAM)
	upg_badge.add_theme_color_override("font_outline_color", C_GOOD)
	upg_badge.add_theme_constant_override("outline_size", 9)
	upg_badge.position = Vector2(29, -4)
	ub.add_child(upg_badge)
	_new_pill(ub, "top")


## Полоса разделов посередине не заходит под правую (крупный интерфейс, длинная казна, «Полки полны»):
## тогда она сдвигается влево — в просвет у полосы дорог, но не на неё
func _fit_bottom() -> void:
	if bar_left == null or bar_mid == null or bar_right == null or not bar_mid.has_meta("put"):
		return
	var vw := root.size.x
	var wl := maxf(bar_left.size.x, bar_left.get_combined_minimum_size().x)
	var wm := maxf(bar_mid.size.x, bar_mid.get_combined_minimum_size().x)
	var wr := maxf(bar_right.size.x, bar_right.get_combined_minimum_size().x)
	# три полосы шире экрана (крупный интерфейс, кнопок стало больше) — правая чуть мельче, к своему правому нижнему углу
	var k := clampf((vw - 36.0 - wl - wm) / maxf(wr, 1.0), 0.8, 1.0)
	bar_right.pivot_offset = bar_right.size
	if not is_equal_approx(bar_right.scale.x, k):
		bar_right.scale = Vector2(k, k)
	wr *= k
	var mid_l := (vw - wm) * 0.5
	var over := mid_l + wm + 8.0 - (vw - 10.0 - wr)              # насколько середина наехала бы на правую
	var room := mid_l - (10.0 + wl + 8.0)                          # сколько места до полосы дорог
	var dx := -ceilf(clampf(over, 0.0, maxf(0.0, room)))
	var off: Vector2 = (bar_mid.get_meta("put") as Array)[1]
	if not is_equal_approx(off.x, dx):
		_put(bar_mid, Control.PRESET_CENTER_BOTTOM, Vector2(dx, off.y))


func _toggle_cat(cid: String) -> void:
	if open_cat == cid and tray.visible:
		open_cat = ""
		tray.visible = false
		_refresh_cat_buttons()
		return
	open_cat = cid
	tray.visible = true
	_hide_info()
	_close_windows()
	_fill_cards()
	_refresh_cat_buttons()
	_unroll()


## Свиток разворачивается из середины
func _unroll() -> void:
	if game and game.sound:
		pass
	await get_tree().process_frame
	var w := tray.get_combined_minimum_size().x
	tray.pivot_offset = Vector2(w / 2.0, 0)
	tray.scale = Vector2(0.08, 1.0)
	var tw := create_tween()
	tw.tween_property(tray, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _refresh_cat_buttons() -> void:
	for c in cats:
		_set_on(cats[c], c == open_cat and tray.visible)


func _types_in(cat: String, sub := "") -> Array:
	var out := []
	for type in Defs.B:
		var d: Dictionary = Defs.B[type]
		if bool(d.get("hidden", false)):
			continue
		if cat == "special" and sub in ["monuments", "wonders"]:
			if (d.get("sub", "") == "wonders") != (sub == "wonders"):
				continue
		if d["cat"] != cat and d.get("also", "") != cat:
			continue                          # also — дополнительный раздел для постройки
		if cat == "commerce" and d.get("sub", "") != sub:
			continue
		if cat == "decor" and sub != "" and Defs.decor_sub(type) != sub:
			continue
		if d.get("also", "") == cat and d["cat"] != cat and cat != "decor" and d.get("kind", "") == "decor" and Defs.base_of(type) != type:
			continue                          # в другом разделе — только главный облик
		if (String(d.get("unlock", "")).begins_with("army:") or String(d.get("unlock", "")).begins_with("tour:")) and game != null and int(game.city.cozy_v) < 1:
			continue                          # мастерские Легиона 2.0 и гостиница — только в новой игре
		if d.get("kind", "") == "military" or d.get("cat", "") == "military":
			continue                          # военные постройки доступны только внутри форта
		if game != null and game.city != null and not game.city.unlocked(type):
			continue
		out.append(type)
	return out


# ---------- меню украшений (этап 5.4): избранное, недавние, поиск ----------

## Ряд под вкладками украшений: избранное, недавние, поиск.
func _decor_tools(v: VBoxContainer) -> void:
	tray_dtools = HBoxContainer.new()
	tray_dtools.alignment = BoxContainer.ALIGNMENT_CENTER
	tray_dtools.add_theme_constant_override("separation", 8)
	tray_dtools.visible = false
	v.add_child(tray_dtools)
	var fav := _tchip("★ Избранное", "Украшения со звёздочкой. Отметить или снять — правой кнопкой мыши по карточке", func(): _decor_mode("fav"))
	fav.name = "fav"
	tray_dtools.add_child(fav)
	var rec := _tchip("Недавние", "%d украшений, что вы ставили последними" % RECENT_N, func(): _decor_mode("recent"))
	rec.name = "recent"
	tray_dtools.add_child(rec)
	decor_search = LineEdit.new()
	decor_search.name = "search"
	decor_search.placeholder_text = "Найти украшение…"
	decor_search.custom_minimum_size = Vector2(230, 32)
	decor_search.clear_button_enabled = true
	decor_search.add_theme_stylebox_override("normal", _box_pill(14, 3, "g_btn"))
	var fo := StyleBoxFlat.new()
	fo.draw_center = false
	fo.border_color = C_GOLD
	fo.set_border_width_all(2)
	fo.set_corner_radius_all(16)
	decor_search.add_theme_stylebox_override("focus", fo)
	decor_search.add_theme_font_override("font", font_bold)
	decor_search.add_theme_font_size_override("font_size", 15)
	decor_search.add_theme_color_override("font_color", C_INK)
	decor_search.add_theme_color_override("font_placeholder_color", Color(C_SOFT, 0.6))
	decor_search.add_theme_color_override("caret_color", C_INK)
	decor_search.text_changed.connect(func(t: String):
		decor_query = t.strip_edges()
		decor_mode = "search" if decor_query != "" else ("" if decor_mode == "search" else decor_mode)
		_fill_cards())
	decor_search.text_submitted.connect(func(_t: String): decor_search.release_focus())
	tray_dtools.add_child(decor_search)



## Кнопка-«таблетка» с надписью (переключатель)
func _tchip(text: String, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.toggle_mode = true
	b.add_theme_stylebox_override("normal", _box_pill(14, 3, "g_btn"))
	b.add_theme_stylebox_override("hover", _box_pill(14, 3, "g_btn_on"))
	b.add_theme_stylebox_override("pressed", _box_pill(14, 3, "g_btn_on"))
	b.add_theme_stylebox_override("hover_pressed", _box_pill(14, 3, "g_btn_on"))
	b.add_theme_font_override("font", font_bold)
	b.add_theme_font_size_override("font_size", 15)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, C_INK)
	b.pressed.connect(cb)
	return b


func _decor_mode(m: String) -> void:
	decor_mode = "" if decor_mode == m else m
	if decor_mode != "search":
		_clear_search()
	_fill_cards()


## Ушли из поиска (вкладка, ★, «Недавние»): строку очистить и отпустить клавиатуру
func _clear_search() -> void:
	if not decor_search:
		return
	if decor_search.text != "":
		decor_search.set_block_signals(true)
		decor_search.text = ""
		decor_search.set_block_signals(false)
	decor_query = ""
	if decor_search.has_focus():
		decor_search.release_focus()


func decor_favs() -> Array:
	return (game.settings.get("fav_decor", []) as Array) if game else []


func decor_recent() -> Array:
	return (game.settings.get("recent_decor", []) as Array) if game else []


## ★ — отметить украшение или снять отметку (правая кнопка по карточке)
func toggle_fav(type: String) -> void:
	var f: Array = decor_favs().duplicate()
	if f.has(type):
		f.erase(type)
	else:
		f.append(type)
	game.settings["fav_decor"] = f
	_store_settings()
	_fill_cards()


## Украшение поставили — в начало «Недавних» (game._build_here)
func note_recent(type: String) -> void:
	var r: Array = decor_recent().duplicate()
	r.erase(type)
	r.push_front(type)
	game.settings["recent_decor"] = r.slice(0, RECENT_N)
	_store_settings()


## Вкладка, избранное, недавние или поиск: всегда только открытые украшения.
func _decor_list() -> Array:
	var out := []
	match decor_mode:
		"fav":
			for t in Defs.B:
				if decor_favs().has(t) and Defs.B[t]["cat"] == "decor":
					out.append(t)
		"recent":
			for t in decor_recent():
				if Defs.B.has(String(t)):
					out.append(String(t))
		"search":
			var q := decor_query.to_lower()
			for t in Defs.B:
				var d: Dictionary = Defs.B[t]
				if d["cat"] == "decor" and (String(d["name"]).to_lower().contains(q) or String(d.get("desc", "")).to_lower().contains(q)):
					out.append(t)
		_:
			out = _types_in("decor", open_dsub)
	if game and game.city:
		out = out.filter(func(t): return game.city.unlocked(t))
	return out


func _fill_cards() -> void:
	_sync_build_tabs()
	for ch in tray_grid.get_children():
		tray_grid.remove_child(ch)
		ch.queue_free()
	tray_stabs.visible = open_cat == "special"
	for b in tray_stabs.get_children():
		(b as Button).set_pressed_no_signal(b.get_meta("sub") == open_ssub)
	tray_tabs.visible = open_cat == "commerce"
	for b in tray_tabs.get_children():
		_set_on(b, b.get_meta("sub") == open_sub)
	tray_dtabs.visible = open_cat == "decor"
	for b in tray_dtabs.get_children():
		_set_on(b, b.get_meta("sub") == open_dsub and decor_mode == "")
	tray_dtools.visible = open_cat == "decor"
	(tray_dtools.get_node("fav") as Button).set_pressed_no_signal(decor_mode == "fav")
	(tray_dtools.get_node("recent") as Button).set_pressed_no_signal(decor_mode == "recent")
	var names := {"housing": "Жильё", "commerce": "Лавки и мастерские", "farming": "Хозяйство и науки", "decor": "Украшения", "special": "Памятники",
		"military": "Военные постройки Легиона"}
	tray_title.text = names.get(open_cat, "")
	if open_cat == "special" and open_ssub == "wonders":
		tray_title.text += " · Чудеса"
	if open_cat == "commerce":
		tray_title.text += " · " + Defs.NEEDS[open_sub]["name"]
	if open_cat == "decor":
		match decor_mode:
			"fav": tray_title.text += " · Избранное"
			"recent": tray_title.text += " · Недавние"
			"search": tray_title.text += " · Поиск"
			_:
				for ds: Array in Defs.DECOR_SUBS:
					if ds[0] == open_dsub:
						tray_title.text += " · " + String(ds[1])
	var list := _decor_list() if open_cat == "decor" else _types_in(open_cat, open_ssub if open_cat == "special" else open_sub)
	if list.is_empty() and open_cat == "decor":
		var em := _label({"fav": "Здесь будут украшения со звёздочкой ★ — правая кнопка мыши по карточке.",
			"recent": "Здесь будут украшения, что вы ставили последними.", "search": "Ничего не нашлось — попробуйте другое слово."}.get(decor_mode, "Здесь пока пусто."), 16, true, C_SOFT)
		em.custom_minimum_size = Vector2(560, CARD.y - 40.0)
		em.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		em.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tray_grid.add_child(em)
	var camp_hint := false
	if camp_hint:
		tray_grid.add_child(_camp_hint_card())
	for type in list:
		var d: Dictionary = Defs.B[type]
		var b := Button.new()
		b.custom_minimum_size = CARD
		b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		b.set_meta("type", type)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", _card_box("g_card"))
		b.add_theme_stylebox_override("hover", _card_box("g_card_hover"))
		b.add_theme_stylebox_override("pressed", _card_box("g_card_hover"))
		b.add_theme_stylebox_override("hover_pressed", _card_box("g_card_hover"))
		b.tooltip_text = _card_tip(type)
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 0)
		v.offset_top = 8
		v.offset_left = 11
		v.offset_right = -11
		v.offset_bottom = -30                # снизу — лавровая розетка рамки
		b.add_child(v)
		var nm := _label(d["name"], 14, true, C_INK)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.custom_minimum_size = Vector2(104, 36)
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nm.add_theme_constant_override("line_spacing", -3)
		v.add_child(nm)
		var img := TextureRect.new()
		img.custom_minimum_size = Vector2(104, 80)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img.texture = icons.get(type)
		img.name = "img"
		v.add_child(img)
		var pr := HBoxContainer.new()
		pr.alignment = BoxContainer.ALIGNMENT_CENTER
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pr.name = "price"
		v.add_child(pr)
		var tp: String = type
		b.pressed.connect(func(): select_build(tp, true))
		if d["kind"] == "decor":
			# ★ — правой кнопкой (избранное, этап 5.4); у отмеченных — золотая звёздочка в углу.
			# Щелчок гасим сразу, пока карточка в дереве, а ряд пересобираем потом: иначе правая кнопка
			# уходит в game._unhandled_input — и свиток закрывается, инструмент из рук пропадает
			b.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
					b.accept_event()
					if (ev as InputEventMouseButton).pressed:
						toggle_fav.call_deferred(tp))
			if decor_favs().has(type):
				var st := _label("★", 22, true, C_GOLD)
				st.add_theme_color_override("font_outline_color", Color("3a2412"))
				st.add_theme_constant_override("outline_size", 6)
				st.position = Vector2(CARD.x - 30, 2)
				b.add_child(st)
		_new_pill(b, "card")
		b.mouse_entered.connect(func(): _card_hovered(b, tp))
		tray_grid.add_child(b)
	var ncards := list.size() + (1 if camp_hint else 0)
	var w := minf(1180.0, maxf(ncards * (CARD.x + 10.0) - 10.0, 560.0 if open_cat == "decor" else 0.0))
	_tray_w = w
	_tray_h = CARD.y + (20.0 if ncards * (CARD.x + 10.0) - 10.0 > 1180.0 else 2.0)
	_snug(tray)
	# полоса прокрутки (если карточек больше, чем влезает) — ниже лавров карточек
	(tray.find_child("scroll", true, false) as Control).custom_minimum_size = Vector2(w, _tray_h)
	_tray_key = ""
	_fit_tray()

	_update_cards()
	update_new_marks()
	_update_pointer()


## Военные постройки — в форте, раздел на городской полосе всегда скрыт.
func _sync_military_tab() -> void:
	var tab := cats.get("military") as Control
	if tab == null or tab.get_parent() == null:
		return
	var on := false
	var box := tab.get_parent() as Control
	if box.visible != on:
		box.visible = on
		if not on and open_cat == "military" and tray.visible:
			_toggle_cat("military")
		_fit_bottom.call_deferred()


## Легион 3.0: первая карточка раздела «Легион» — где теперь Лагерь (щелчок открывает его)
func _camp_hint_card() -> Button:
	var b := Button.new()
	b.custom_minimum_size = CARD
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	b.focus_mode = Control.FOCUS_NONE
	b.name = "camp_hint"
	for st: Array in [["normal", "g_card"], ["hover", "g_card_hover"], ["pressed", "g_card_hover"], ["hover_pressed", "g_card_hover"]]:
		b.add_theme_stylebox_override(st[0], _card_box(st[1]))
	b.tooltip_text = "Воины призываются из жителей в Лагере. Здесь — мастерские города: они дают Лагерю железо, дерево и кожу."
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.offset_top = 8
	v.offset_left = 11
	v.offset_right = -11
	v.offset_bottom = -30
	b.add_child(v)
	var img := TextureRect.new()
	img.custom_minimum_size = Vector2(104, 60)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.texture = ico("tent", 64)
	v.add_child(img)
	var l := _label("Лагерь Легиона — кнопка «Легион» наверху", 13, true, C_INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(104, 60)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	b.pressed.connect(func():
		CampUI.attach(self).open())
	return b


## Рамка карточки постройки (картинка 128×181, снизу лавровая розетка); у подсвеченной свечение за краем
func _card_box(name: String) -> StyleBoxTexture:
	var key := "card:" + name
	if _medals.has(key):
		return _medals[key]
	var g := 8.0 if name == "g_card_hover" else 0.0
	var s := _ai_box(name, [10 + g, 10 + g, 10 + g, 32 + g], [0, 0, 0, 0], false, [11, 11, 11, 11])
	if pa_has(name):
		_medals[key] = s                    # новый интерфейс: подсветка — та же рамка золотом, без выноса за край
		return s
	s.expand_margin_left = g
	s.expand_margin_right = g
	s.expand_margin_top = g
	s.expand_margin_bottom = g
	_medals[key] = s
	return s


func _card_tip(type: String) -> String:
	var d: Dictionary = Defs.B[type]
	var t: String = d["name"].to_upper() + "\n" + d["desc"]
	match d["kind"]:
		"shop":
			t += "\n\nСчастье домам: +%d%%\nДальность обслуживания: %s\nОбслуживает домов: %s\nРабочие: %s" % [d["bonus"], Defs.WORD[int(d["range"])],
				Defs.WORD[int(d["cap"])], _jobs_text(d)]
			t += "\nНужен склад рядом" if d.get("store", false) else "\nСклад не требуется"
		"monument":
			t += "\n\nСчастье всем вокруг: +%d%%\nДальность: %s" % [d["bonus"], Defs.WORD[int(d["range"])]]
		"rp":
			var rph: float = game.city.rp_per_hour(type) if game and game.city else float(d["rp"])
			t += "\n\nОчки исследований: +%s в час\nРабочие: %s" % [String.num(rph, 1), _jobs_text(d)]
		"house":
			var c: Dictionary = Defs.CLASSES[d["cls"]]
			t += "\n\nЖители: %s, одна семья на этаж\nНужно им: %s" % [c["name"].to_lower(), ", ".join(Defs.needs_for(String(d["cls"]), game.city.level).map(func(n): return Defs.NEEDS[n]["name"].to_lower()))]
		"decor":
			t += "\n\nОчки украшения: %d" % int(d.get("deco", 1))
			if d.has("mon"):
				t += "\nГлавное украшение: +%d%% счастья домам в %d м — как памятник, сверх предела украшений" % [int(d["mon"]), int(Defs.range_m(d))]
			if game and game.city and game.city.econ >= 1:
				var sk := Defs.set_of(type)
				if sk != "":
					t += "\nНабор «%s»: три разных вида из него рядом с домом — ещё +%d%% счастья" % [Defs.research(sk)["name"], Defs.SET_BONUS]
			t += "\nПравая кнопка мыши — убрать из избранного" if decor_favs().has(type) else "\nПравая кнопка мыши — в избранное ★"
		"farm", "store":
			if d.has("jobs"):
				t += "\n\nРабочие: %s" % _jobs_text(d)
	if d["kind"] == "inn":
		t += "\n\nГости приходят смотреть достопримечательности в %d м: храм, форум, арку, акведук, маяк, театр, термы, фонтаны. Чем их больше и чем они краше — тем больше гостей и денег.\nРабочие: %s" % [int(Tourism.TOUR_R), _jobs_text(d)]
	# этап 5, волна 2: Слава в цене и каждый день, одна на город, у воды, без дороги
	if d["kind"] == "monument" and d.has("jobs"):
		t += "\nРабочие: %s" % _jobs_text(d)
	if d.has("glory_day"):
		t += "\nПриносит Славу: +%s в день" % String.num(float(d["glory_day"]), 1).replace(".", ",")
	if d.get("unique", false) and d["kind"] != "military":
		t += "\nОдна на город"
	if d.get("shore", false):
		t += "\nСтавится у самой воды"
	if d.get("noroad", false):
		t += "\nДорога у входа не нужна"
	if game and game.city and not game.city.unlocked(type):
		var uid: String = game.city.unlock_id(type)
		t += "\n\nОткроется %s" % Defs.unlock_text(uid)
		var rr := Defs.research(uid)
		if not rr.is_empty() and int(rr["lvl"]) > game.city.level:
			t += " (уровень «%s»)" % Defs.LEVELS[int(rr["lvl"])]["name"]
	var cnt := 0
	if game and game.city:
		for id in game.city.buildings:
			if game.city.buildings[id]["type"] == type:
				cnt += 1
	var mx: int = game.city.build_max(type) if game and game.city else -1
	if mx >= 0:
		t += "\nВ городе: %d из %d" % [cnt, mx]
		if cnt > mx:
			t += " — сверх предела не работают: %d" % (cnt - mx)
		var lv: int = game.city.level
		var amx: Array = Defs.B[type]["max"]
		if lv + 1 < Defs.LEVELS.size():           # сколько можно будет на следующем уровне
			t += " (на уровне «%s» — %d)" % [Defs.LEVELS[lv + 1]["name"], int(amx[mini(lv + 1, amx.size() - 1)])]
	else:
		t += "\nВ городе: %d" % cnt
	return t


func _jobs_text(d: Dictionary) -> String:
	var parts := []
	for c in d.get("jobs", {}):
		parts.append("%d %s" % [d["jobs"][c], Defs.CLASSES[c]["name"].to_lower()])
	return ", ".join(parts) if not parts.is_empty() else "не нужны"


func _update_cards() -> void:
	_sync_build_menu()
	var c: City = game.city
	for b in tray_grid.get_children():
		if not b.has_meta("type"):
			continue
		var type: String = b.get_meta("type")
		var d: Dictionary = Defs.B[type]
		if c.build_max(type) >= 0 or d.get("sub", "") == "wonders":
			var tip := _card_tip(type)       # «В городе: N из M» меняется с каждой постройкой и рангом
			if b.tooltip_text != tip:
				b.tooltip_text = tip
		var img: TextureRect = b.find_child("img", true, false)
		if img and img.texture == null:
			img.texture = icons.get(type)
		var pr: HBoxContainer = b.find_child("price", true, false)
		for x in pr.get_children():
			x.queue_free()
		if c.cap_err(type) != "":
			# предел уровня города: больше таких не поставить, пока город не вырастет
			var lm := _label("Предел: %d" % c.build_max(type), 12, true, C_SOFT)
			lm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lm.custom_minimum_size = Vector2(84, 0)
			pr.add_child(lm)
			b.add_theme_stylebox_override("normal", _card_box("g_card"))
			img.modulate = Color.WHITE
			_grey(img)
		elif c.wonder_credit_ready(type):
			pr.add_child(_icon("laurels", 22, C_GOOD))
			pr.add_child(_label("Даром", 16, true, C_GOOD))
			b.tooltip_text = _card_tip(type) + "\nПрежняя покупка: одна постановка даром"
			b.add_theme_stylebox_override("normal", _card_box("g_card"))
			img.modulate = Color.WHITE
			_grey(img, false)
		elif c.gift_ready(type):
			# подарок друга (SocialNet): даром, сколько штук осталось
			pr.add_child(_icon("mail", 22, C_GOOD))
			pr.add_child(_label("Подарок ×%d" % (c.gifts[type] as Array).size(), 16, true, C_GOOD))
			b.tooltip_text = "Подарок из «%s» — ставится даром" % String((c.gifts[type] as Array)[0])
			b.add_theme_stylebox_override("normal", _card_box("g_card"))
			img.modulate = Color.WHITE
			_grey(img, false)
		elif d.get("trophy", false):
			# трофей Легиона — бесплатно
			pr.add_child(_icon("laurels", 22))
			pr.add_child(_label("Трофей", 16, true, C_GOOD))
			b.add_theme_stylebox_override("normal", _card_box("g_card"))
			img.modulate = Color.WHITE
			_grey(img, false)
		else:
			pr.add_child(_icon("coins", 22))
			pr.add_child(_label(fmt(c.build_price(type)), 18, true, C_INK if c.money >= c.build_price(type) else C_BAD))
			b.add_theme_stylebox_override("normal", _card_box("g_card"))
			img.modulate = Color.WHITE
			_grey(img, false)


## from_tray — взяли карточку в самом свитке: вкладку, ★/«Недавние» и поиск не трогаем (там и так видна эта карточка)
func select_build(type: String, from_tray := false) -> void:
	if not Defs.B.has(type):
		return
	if decor_search and decor_search.has_focus():
		decor_search.release_focus()          # взяли украшение — клавиши снова у карты (WASD, Z/X, пробел)
	var cat: String = Defs.B[type]["cat"]
	if bool(Defs.B[type].get("hidden", false)):
		return
	if cat == "special":
		var sub := "wonders" if Defs.B[type].get("sub", "") == "wonders" else "monuments"
		if open_ssub != sub:
			open_ssub = sub
			if tray.visible and open_cat == cat:
				_fill_cards()
	if cat == "commerce":
		open_sub = Defs.B[type]["sub"]
	if cat == "decor" and not from_tray:
		# стрелка, строка просьбы, Легион: к вкладке карточки (★/«Недавние»/поиск остаются, если она там есть)
		if not (decor_mode in ["fav", "recent"] and _decor_list().has(type)):
			open_dsub = Defs.decor_sub(type) if Defs.decor_sub(type) != "" else open_dsub
			decor_mode = "" if decor_mode != "search" else decor_mode
		if tray.visible and open_cat == "decor":
			_fill_cards()
	_hide_info()
	if (open_cat != cat or not tray.visible) and cat != "":
		_close_windows()
		open_cat = cat
		tray.visible = true
		_fill_cards()
		_refresh_cat_buttons()
		_unroll()
	if not game.city.unlocked(type):
		notify("«%s» откроется %s" % [Defs.B[type]["name"], Defs.unlock_text(game.city.unlock_id(type))], "lock")
		return
	if game.mode in ["new", "play"] and game.city.mark_seen(type):
		update_new_marks()                    # взяли карточку — она больше не «НОВОЕ»
	if game.city.cap_err(type) != "":
		notify(game.city.cap_err(type), "lock")
		return
	game.end_copy()                           # карточку взяли сами — обычная стройка, не продолжение копии
	game.set_tool(type)
	if game.tutorial != null and Tutorial.BUILD_STEPS.get(game.tutorial.cur_id(), "") == type:
		_close_tray()
	_update_pointer()


# ---------- стрелка-подсказка к заданию ----------

func _pointer() -> void:
	pointer = TextureRect.new()
	pointer.name = "GuidanceArrow"
	pointer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pointer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pointer.texture = preload("res://assets/ui/tutorial_arrow.svg")
	pointer.custom_minimum_size = Vector2(64, 64)
	pointer.size = Vector2(64, 64)
	pointer.pivot_offset = Vector2(32, 32)
	pointer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pointer.visible = false
	add_child(pointer)
	pointer_text = _label("", 17, true, C_CREAM)
	pointer_text.add_theme_color_override("font_outline_color", Color("3a2412"))
	pointer_text.add_theme_constant_override("outline_size", 7)
	pointer_text.visible = false
	add_child(pointer_text)


## Стрелка обучения или временная подсказка по щелчку строки
func _update_pointer() -> void:
	pointer_target = null
	_pointer_badge = {}
	if game == null or game.city == null or game.mode == "demo" or game.mode == "menu":
		return
	var camp := CampUI.of(self)
	var legion_ui := LegionUi.of(self)
	if (camp != null and camp.visible) or (game.city.legion.v3() and legion_ui != null and legion_ui.visible):
		if pointer != null:
			pointer.hide()
			pointer_text.hide()
		return
	if tutorial_busy():
		if game.tutorial != null:
			var pt: Array = game.tutorial.pointer()
			pointer_target = pt[0]
			pointer_text.text = pt[1]
			if badges.has("tutorial_target") and pointer_target != badges["tutorial_target"]["n"]:
				clear_badge("tutorial_target")
			if pointer_target is MapBadge:
				for badge: Dictionary in badges.values():
					if pointer_target == badge["n"]:
						_pointer_badge = badge
						break
		return
	# щёлкнули по строке (просьба, условие уровня, цель истории) — стрелка PTR_SHOW_MS к тому, что нужно сделать
	if not _ptr_shown.is_empty():
		if Time.get_ticks_msec() < int(_ptr_shown["until"]):
			pointer_target = _do_target(_ptr_shown["do"], true)
			pointer_text.text = String((_ptr_shown["do"] as Dictionary).get("tip", ""))
			if pointer_target != null:
				return
		else:
			_ptr_shown = {}
	# Владелец, 17.11: «после обучения эта стрелка не нужна вообще — мешает играть и сбивает с толку».
	# Сама стрелка больше не появляется: ни к просьбам, ни к историям, ни к кнопке уровня, ни к Легиону.
	# Стрелка — только в обучении и по щелчку строки просьбы / условия уровня (show_pointer, PTR_SHOW_MS).
	return

const PTR_SHOW_MS := 6000              # стрелка по щелчку строки — столько мс, потом гаснет
var _ptr_shown := {}                   # {"do": need_do, "until": мс} — стрелка по щелчку
var _ptr_tick := 0.0


## Первые просьбы до «Хутора»; стрелка к ним — только по щелчку строки
func early_request(g: Dictionary) -> bool:
	if game.city.level >= 1:
		return false
	for r: Dictionary in Defs.REQUESTS:
		if r["id"] == g["id"]:
			return true
		if r["id"] == "hamlet":
			return false
	return false


## Показать стрелкой (на PTR_SHOW_MS) то, что нужно сделать (need_do): щелчок по строке просьбы, условия уровня, цели
func show_pointer(w: Dictionary) -> void:
	if w.is_empty() or _do_target(w, true) == null and String(w.get("kind", "")) in ["", "wait", "locked"]:
		return
	_ptr_shown = {"do": w, "until": Time.get_ticks_msec() + PTR_SHOW_MS}
	_update_pointer()
	_ensure_pointer_visible.call_deferred()


func _ensure_pointer_visible() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var target: Control = pointer_target
	if not is_instance_valid(target) or not target.is_visible_in_tree():
		return
	var ancestor: Node = target.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			(ancestor as ScrollContainer).ensure_control_visible(target)
		ancestor = ancestor.get_parent()


# ---------- что сделать по условию: просьбы, их части и строки уровня (стрелка, подпись, щелчок) ----------

## Стрелка к просьбе g: {target — куда показать (или null), tip — подпись у стрелки}
func _request_target(g: Dictionary) -> Dictionary:
	var w := request_do(g)
	return {"target": _do_target(w), "tip": String(w.get("tip", "")), "do": w}


## Что сделать по просьбе g: первая невыполненная часть (parts — в виде условий уровня) или вся просьба
func request_do(g: Dictionary) -> Dictionary:
	for pt: Dictionary in g.get("parts", []):
		if game.city.progress_of(pt["p"]) < int(pt.get("n", 1)):
			return need_do(pt["p"], String(pt.get("tool", "")), int(pt.get("n", 1)))
	return need_do(g["p"], String(g.get("tool", "")), int(g.get("need", 0)))


## Ждём повозку: жилья хватает, не хватает только людей — стрелки нет, советник и строка говорят, что ждать
const WAIT_SETTLERS := "Ждём переселенцев — повозка привезёт новые семьи: жилья хватает"
const WAIT_ROW := "Ждём переселенцев — повозка привезёт новые семьи"


## Что сделать по условию p (вид — как у просьб и условий уровня; tool — какую постройку взять; n — сколько нужно,
## 0 — не знаем): {kind, type, rid, layer, tip — подпись у стрелки, say — что сделать, одной фразой}. kind: build —
## взять постройку type; research — она закрыта, нужно исследование rid; research_any — любое исследование; cap — предел
## уровня; floor — «Этаж»; view — «Обзор» со слоем layer; road — «Мостовая»; fam — семья на площади; rank — кнопка
## нового уровня; wait — делать нечего, ждём переселенцев (стрелки нет); {} — делать нечего
func need_do(p: Array, tool := "", n := 0) -> Dictionary:
	var c: City = game.city
	var arg = p[1] if p.size() > 1 else null
	match String(p[0]):
		"near":
			# фонтан у домов: фонтана ещё нет — поставить; есть — «Обзор → Вода»: где вода есть, а где нет
			if String(arg) == "fountain" and c.count_type("fountain") > 0 and tool == "":
				return {"kind": "view", "layer": "water", "tip": "Обзор",
					"say": "«Обзор» (глаз вверху справа) → «Вода»: красные дома — без воды; поставьте фонтан посреди них"}
			return _do_type(tool if tool != "" else String(arg))
		"count":
			var up := _do_upgrade(String(arg))
			if not up.is_empty():
				return up                     # дома ремесленников и домусы: есть готовые к перестройке — «Перестроить»
			return _do_type(tool if tool != "" else String(arg))
		"houses":
			return _do_type(tool if tool != "" else "house_pleb")
		"light":
			return _do_type(tool if tool != "" else "lamp_post")
		"kind":
			if tool != "" or String(arg) == "decor":
				return _do_type(tool if tool != "" else "bench")
			for t in Defs.B:
				if Defs.B[t]["kind"] == arg and String(Defs.B[t].get("cat", "")) != "":
					return _do_type(t)
		"cls":
			var upc := _do_upgrade(String(Defs.CLASSES[String(arg)]["house"]))
			if not upc.is_empty():
				return upc
			return _do_type(tool if tool != "" else String(Defs.CLASSES[String(arg)]["house"]))
		"store":
			if c.manual_hiring():
				for b: Dictionary in c.buildings.values():
					if b["type"] in ["warehouse", "butcher"] and c.hired_of(b) == 0:
						return hire_do(b)
			for t in ["warehouse", "butcher"]:
				if c.count_type(t) == 0:
					return _do_type(t)
			return _do_type("butcher")
		"shops":
			return _do_shop(arg)
		"fed":
			# «6 сытых домов»: самих домов меньше — сначала дома (а не «Обзор», отзывы 27.10); дома стоят, но пусты —
			# ждём переселенцев; лавок этого вида нет — поставить (или открыть); есть, а дома голодные — ещё лавку рядом с ними
			var nm_need := String({"food": "лавку еды", "clothes": "лавку одежды", "fun": "развлечения", "services": "лавку услуг",
				"goods": "лавку товаров"}.get(String(arg), "лавку"))
			if n > 0 and c.progress_of(["houses"]) < n:
				var wh := _do_type("house_pleb")
				wh["say"] = "Пока домов меньше %d — постройте ещё дома, а рядом с ними %s" % [n, nm_need]
				return wh
			var lived := c._count(func(b): return c.is_house(b) and int(b["pop"]) > 0)
			if n > 0 and lived < n and _shops_of(String(arg)) > 0:
				return {"kind": "wait", "tip": "", "say": "Дома стоят, но в части ещё никто не живёт. " + WAIT_SETTLERS}
			var ws := _do_shop(String(arg))
			if _shops_of(String(arg)) > 0 and String(ws.get("kind", "")) == "build":
				ws["say"] = "Не всем домам хватает: поставьте ещё %s возле них — «Обзор» → «%s» покажет такие дома красным" % [
					nm_need, Defs.NEEDS[arg]["name"]]
			return ws
		"floors":
			var rid := "floor%d" % int(arg)
			if not c.research.has(rid):
				return _do_research(rid, "Этажи открывает исследование «%s»" % Defs.research(rid)["name"])
			return {"kind": "floor", "tip": "Этаж",
				"say": "«Этаж» справа внизу (U): дом должен быть полон, счастье в нём — не ниже %d%%" % int(Defs.FLOOR_HAPPY.get(int(arg), 65))}
		"happy":
			return {"kind": "view", "layer": "happy", "tip": "Обзор", "say": "«Обзор» покажет дома, где плохо; наведите на счастье вверху — там видно, что его поднимет"}
		"pop":
			if not c.arrivals.is_empty() and fam_box != null and fam_box.visible:
				return {"kind": "fam", "tip": "Семья", "say": "Семьи ждут на площади: нажмите на значок семьи и выберите им дом"}
			if String(c.stats.get("arrive_block", "")) != "":
				return {"kind": "view", "layer": "happy", "tip": "Обзор", "say": String(c.stats["arrive_block"])}
			# жилья на нужное число людей хватает — не хватает только переселенцев: ждём повозку, стрелки нет (прежде
			# стрелка без конца звала строить плебейский дом — отзывы 27.10)
			if (n > 0 and c.house_room() >= n) or (n <= 0 and c.free_fit() > 0):
				return {"kind": "wait", "tip": "", "say": WAIT_SETTLERS}
			var w := _do_type("house_pleb")
			w["say"] = "Стройте дома заранее: повозка везёт семьи только туда, где есть свободное место" if n <= 0 else \
				"Домов на %d жителей не хватает (места — на %d): постройте ещё дома, повозка привезёт в них семьи" % [n, c.house_room()]
			return w
		"research":
			return {"kind": "research_any", "tip": "Исследования", "say": "Свиток вверху справа — меню исследований"}
		"soldiers":
			return {"kind": "legion", "action": "recruit", "tip": "", "say": "«Лагерь» сверху → «Казарма» → «Призвать»"}
		"tier":
			# «Уютный Рим»: изучить больше исследований ряда arg (очки копят скриптории, школы и почта)
			return {"kind": "research_any", "tip": "Исследования",
				"say": "Свиток вверху справа: изучите ещё исследования ряда «%s» — очки копят скриптории, школы и почта" % Defs.LEVELS[clampi(int(arg), 0, Defs.LEVELS.size() - 1)]["name"]}
		"road":
			return {"kind": "road", "tip": "Мостовая", "say": "«Мостовая» слева внизу: ведите с зажатой кнопкой"}
		"fam":
			# семьи на площади — к значку семьи; нет их и мест нет — строить дома; места есть — ждём повозку
			if c.arrivals.is_empty() and c.free_fit() <= 0 and c.incoming == 0:
				var wf := _do_type("house_pleb")
				wf["say"] = "Свободных мест в домах нет: постройте дом — повозка привезёт в него семью"
				return wf
			if c.arrivals.is_empty():
				return {"kind": "wait", "tip": "", "say": WAIT_SETTLERS}
			return {"kind": "fam", "tip": "Семья", "say": "Нажмите на значок семьи слева вверху и выберите им дом"}
		"rank":
			var lv := int(arg)
			if c.level >= lv:
				return {}
			if c.rank_ok():
				return {"kind": "rank", "tip": "", "say": "Нажмите «Перейти на новый уровень» под табличкой города"}
			# первое невыполненное условие, где правда есть что сделать; жителей ждём (жилья хватает) — к следующему
			var wait := {}
			for e: Dictionary in c.rank_needs(lv):
				if not e["ok"] and e.has("p"):
					var we := need_do(e["p"], String(e.get("tool", "")), int(e.get("need", 0)))
					if String(we.get("kind", "")) != "wait":
						return we
					if wait.is_empty():
						wait = we
			return wait
	return {}


## Дом класса type можно получить перестройкой (Д12) и такие дома уже готовы — «Перестроить» справа внизу; иначе {}
func _do_upgrade(type: String) -> Dictionary:
	var c: City = game.city
	if not (type in ["house_artisan", "house_patrician"]) or not c.unlocked(type):
		return {}
	var n := 0
	for id in c.upgrade_ready(false):
		if c.upgrade_to(c.buildings[id]) == type:
			n += 1
	if n == 0:
		return {}
	var what := "домами ремесленников" if type == "house_artisan" else "городскими домусами"
	return {"kind": "upgrade", "tip": "Перестроить",
		"say": "«Перестроить» справа внизу (Shift+U): %d %s готовы стать %s" % [n, _plural(n, "дом", "дома", "домов"), what]}


## Постройка type: открыта — взять её; закрыта — исследование (доступное: «Мясная лавка» после «Склада»); предел уровня
func _do_type(type: String) -> Dictionary:
	var c: City = game.city
	if not Defs.B.has(type):
		return {}
	var d: Dictionary = Defs.B[type]
	var nm := String(d["name"])
	if not c.unlocked(type):
		var rid := c.unlock_id(type)
		if Defs.research(rid).is_empty() or Defs.story_of(Defs.research(rid)) != "":
			return {"kind": "locked", "type": type, "tip": nm, "say": "«%s» откроется %s" % [nm, Defs.unlock_text(rid)]}
		var w := _do_research(rid, "«%s» открывает исследование «%s»" % [nm, Defs.research(rid)["name"]])
		w["type"] = type
		return w
	var cap := c.cap_err(type)
	if cap != "":
		return {"kind": "cap", "type": type, "tip": "Предел уровня", "say": cap}
	return {"kind": "build", "type": type, "tip": nm,
		"say": "«%s» — в разделе «%s» внизу" % [nm, Defs.CAT_SHORT.get(String(d.get("cat", "")), "")]}


## Исследование rid (или то, что надо изучить раньше него); say — что оно откроет
func _do_research(rid: String, say: String) -> Dictionary:
	var c: City = game.city
	var r := Defs.research(rid)
	while r.has("after") and not c.research.has(String(r["after"])):
		rid = String(r["after"])
		r = Defs.research(rid)
	var why := c.can_research(rid)
	if why != "" and why != "Уже изучено":
		say += ". Сейчас: " + why.left(1).to_lower() + why.substr(1)
	return {"kind": "research", "rid": rid, "tip": "Исследования", "say": say}


## Разные лавки (sub — этого вида, null — любые): открытую, которой ещё нет, — взять; нет такой — открыть ближайшую
func _do_shop(sub) -> Dictionary:
	var c: City = game.city
	if c.manual_hiring():
		for b: Dictionary in c.buildings.values():
			var d := c.def(b)
			if d["kind"] == "shop" and (sub == null or String(d.get("sub", "")) == String(sub)) and c.hired_of(b) < c.job_max(b) and not b.get("over", false):
				return hire_do(b)
	var locked := ""
	var lk := 99
	for t in Defs.B:
		var d: Dictionary = Defs.B[t]
		if d["kind"] != "shop" or (sub != null and String(d.get("sub", "")) != String(sub)) or c.count_type(t) > 0:
			continue
		if c.unlocked(t):
			return _do_type(t)
		var lv := int(Defs.research(String(d.get("unlock", ""))).get("lvl", 98))
		if lv < lk:
			lk = lv
			locked = t
	if locked != "":
		return _do_type(locked)
	for t in Defs.B:                           # все лавки вида уже стоят — взять любую ещё раз
		if Defs.B[t]["kind"] == "shop" and (sub == null or String(Defs.B[t].get("sub", "")) == String(sub)):
			return _do_type(t)
	return {}


func _shops_of(sub: String) -> int:
	var c: City = game.city
	return c._count(func(b): return c.def(b)["kind"] == "shop" and String(c.def(b).get("sub", "")) == sub)


## Куда показать стрелкой то, что нужно сделать (need_do): карточка (сначала её раздел и вкладка), исследования
## (в открытом окне — сама карточка исследования), «Этаж», «Обзор», уровень города. shown — стрелка по щелчку строки:
## постройка уже в руках (инструмент выбран, слой открыт) — всё равно показать, где её карточка (кнопка), чтобы запомнить
func _do_target(w: Dictionary, shown := false) -> Control:
	match String(w.get("kind", "")):
		"hire":
			if not info_panel.visible or int(info_b.get("id", -1)) != int(w.get("id", -2)):
				return null
			if game.city.hired_of(info_b) > 0:
				return null
			return info_box.find_child("hire_plus", true, false) as Control
		"study":
			return research_tree.study_target() if research_panel.visible else null
		"people":
			return people_target if is_instance_valid(people_target) and people_target.is_visible_in_tree() else null
		"info":
			if not info_panel.visible:
				return null
			var action := String(w.get("action", ""))
			for button: Button in info_box.find_children("*", "Button", true, false):
				if not button.is_queued_for_deletion() and button.is_visible_in_tree() and String(button.get_meta("quest_action", "")) == action and action != "":
					return button
			return info_panel
		"magis":
			return top_btns.get("magis")
		"plaza":
			return road_btns.get("plaza", road_target())
		"locked":
			return _card_or_cat(String(Defs.B.get(String(w.get("type", "")), {}).get("cat", "")), String(w.get("type", "")))
		"build":
			var type := String(w["type"])
			var cat := String(Defs.B[type].get("cat", ""))
			if (game.tool == type and not shown) or cat == "":
				return null
			return _card_or_cat(cat, type)
		"research", "research_any":
			if research_panel.visible:
				return _research_card(String(w.get("rid", "")))
			return top_btns.get("research")
		"cap":
			return rank_btn if rank_btn.visible else hover_level
		"floor":
			return null if game.tool == "floor" and not shown else tool_btns.get("floor")
		"upgrade":
			return null if game.tool == "upgrade" and not shown else tool_btns.get("upgrade")
		"view":
			var layer := String(w["layer"])
			if overlay == layer and not shown:
				return null
			return _ov_btns.get(layer) if overlay != "" else top_btns.get("view")
		"road":
			return null if game.tool == "road" and not shown else road_target()
		"fam":
			if game.tool != "settle" and fam_box.visible and fam_box.get_child_count() > 0:
				for x in fam_box.get_child(0).find_children("*", "Button", true, false):
					return x
		"rank":
			return rank_btn

	return null


## Щелчок по строке просьбы или условия уровня: взять нужную постройку, открыть исследования на нужной карточке,
## «Этаж», «Обзор» со слоем, семью на площади
func _do_click(w: Dictionary) -> void:
	match String(w.get("kind", "")):
		"hire":
			var b: Dictionary = game.city.buildings.get(int(w.get("id", -1)), {})
			if not b.is_empty():
				var p: Vector2 = b["pos"]
				game.rig.set_view(Vector3(p.x, float(b["y"]), p.y), 15, 40, 28)
				open_info(b)
		"build":
			select_build(String(w["type"]))
			_scroll_build_card(String(w["type"]))
		"locked":
			select_build(String(w.get("type", "")))
			_scroll_build_card(String(w.get("type", "")))
		"cap", "rank":
			_open_overview("city")
		"magis":
			MagisUI.attach(self).open()
		"plaza":
			if game.tool != "plaza":
				game.set_tool("plaza")
		"research", "research_any":
			if not research_panel.visible:
				_top_action("research")
			_scroll_research(String(w.get("rid", "")))
		"floor":
			if game.tool != "floor":
				game.set_tool("floor")
		"upgrade":
			if game.tool != "upgrade":
				game.set_tool("upgrade")
		"view":
			set_overlay(String(w["layer"]))
		"road":
			if game.tool != "road":
				game.set_tool("road")
		"fam":
			if not game.city.arrivals.is_empty():
				game.start_settle(game.city.arrivals[0]["name"])

	show_pointer(w)                           # и стрелка на несколько секунд — куда дальше (карточка исследования, семья…)
	_update_pointer()


func _scroll_build_card(type: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var card := _card_or_cat(open_cat, type)
	if card == null or not card.has_meta("type"):
		return
	var parent: Node = card.get_parent()
	while parent != null and not parent is ScrollContainer:
		parent = parent.get_parent()
	if parent is ScrollContainer:
		(parent as ScrollContainer).ensure_control_visible(card)
	_update_pointer()


## Карточка исследования rid в открытом окне (или null)
func _research_card(rid: String) -> Control:
	if research_tree == null:
		return null
	if rid == "":
		rid = String(research_tree._first)
	return research_tree.cards.get(rid)


## Открыть описание и прокрутить дерево к нужному исследованию.
func _scroll_research(rid: String) -> void:
	if research_tree == null:
		return
	if rid == "":
		rid = String(research_tree._first)
	research_tree.reveal(rid)
	await get_tree().process_frame
	await get_tree().process_frame
	_update_pointer()


## Части условия одной строкой: «Склад ✓ · Мясная лавка 0/1» (parts просьбы или условия уровня)
func parts_line(parts: Array) -> String:
	var bits := []
	for pt: Dictionary in parts:
		var have: int
		var need: int
		if pt.has("ok"):                        # строка уровня (City.rank_needs)
			have = int(pt["have"])
			need = int(pt["need"])
		else:
			have = game.city.progress_of(pt["p"])
			need = int(pt.get("n", 1))
		var txt := String(pt.get("text", ""))
		if have >= need:
			bits.append(txt + " ✓")
		elif pt.get("pct", false):
			bits.append("%s %d%%/%d%%" % [txt, have, need])
		else:
			bits.append("%s %s/%s" % [txt, fmt(mini(have, need)), fmt(need)])
	return " · ".join(bits)


func _card_or_cat(cat: String, type: String) -> Control:
	if tray.visible and open_cat == cat:
		for b in tray_grid.get_children():
			if b.get_meta("type", "") == type:
				return b
		# карточка на другой вкладке — показать на вкладку
		var tabs: HBoxContainer = tray_dtabs if cat == "decor" else (tray_tabs if cat == "commerce" else (tray_stabs if cat == "special" else null))
		# у украшений — вкладка меню (с переездами этапа 5: колодец — в «Воде», телега — в «Рынке»)
		var want := Defs.decor_sub(type) if cat == "decor" else String(Defs.B[type].get("sub", ""))
		if cat == "special" and want != "wonders":
			want = "monuments"
		if tabs:
			for t in tabs.get_children():
				if String(t.get_meta("sub", "")) == want:
					return t
	return cats.get(cat)


func _process(_dt: float) -> void:
	if not _ptr_shown.is_empty() and Time.get_ticks_msec() >= int(_ptr_shown["until"]):
		_ptr_shown = {}
		_update_pointer()
	if game and game.ready_done:
		_flush_guidance()
		if tutorial_busy():
			advisor_panel.hide()
			notes_box.hide()
			_ptr_tick -= _dt
			if _ptr_tick <= 0.0 or game.tutorial != null and game.tutorial.cur_id() == "cart":
				_ptr_tick = 0.2
				_update_pointer()
		else:
			notes_box.visible = not advisor_panel.visible
	_fit_tray()
	if game and game.ready_done:
		_family_badges()
	_quest_world_tick()
	_place_badges()
	_place_pops()
	if info_panel.visible and not info_b.is_empty():
		_refresh_source_pictures()
	_place_notes()
	_place_overlay()
	_cursor_tick()
	_hover_tick()
	_person_tag_tick(_dt)
	if not info_p.is_empty() and info_panel and info_panel.visible:
		PersonCard.tick(self, info_p, _dt)     # портрет следит за головой, «Сейчас» — дважды в секунду
	if tool_panel and tool_panel.visible and Engine.get_process_frames() % 30 == 0:
		refresh_undo()                        # отменить постройку можно 30 с — медаль сереет сама
	if not _lg_live.is_empty() and info_panel and info_panel.visible:
		_lg_live_t -= _dt
		if _lg_live_t <= 0.0:
			_lg_live_t = 0.25
			_lg_tick()                        # карточка здания Легиона: идущее улучшение
	if rank_btn and rank_btn.visible:
		# город готов к новому уровню: кнопка и надпись уровня мягко светятся
		var k := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 320.0)
		rank_btn.self_modulate = Color.WHITE.lerp(Color(1.2, 1.16, 1.02), k)
		lbl_level.modulate = Color.WHITE.lerp(Color(1.35, 1.35, 1.1), k)

	if _fold_badge and is_instance_valid(_fold_badge):
		# на свёрнутом свитке новое «✓» мягко светится 2 с
		var gk := 0.0
		if Time.get_ticks_msec() < _fold_glow_until:
			gk = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 140.0)
		_fold_badge.modulate = Color.WHITE.lerp(Color(1.35, 1.4, 1.2), gk)
	if game and lbl_clock:
		var h := int(game.hour)
		var m := int((game.hour - h) * 60.0) / 10 * 10
		lbl_clock.text = "%02d:%02d" % [h, m]
	if not _ptr_shown.is_empty():
		# стрелка по щелчку строки: следует за тем, что открылось (раздел → вкладка → карточка), и гаснет через PTR_SHOW_MS
		_ptr_tick -= _dt
		if _ptr_tick <= 0.0:
			_ptr_tick = 0.25
			_update_pointer()
	if pointer:
		var t: Control = pointer_target
		# мировая цель обучения (повозка, дом) — проекция; цели внутри форта и окна Легиона тоже показываем (обучение Легиона)
		var world := _tutorial_pointer_projection()
		var show := is_instance_valid(t) and (t.is_visible_in_tree() or world.is_finite()) and root.visible
		pointer.visible = show
		pointer_text.visible = show and pointer_text.text != ""
		if show:
			if tutorial_busy():
				_place_tutorial_pointer(t, world)
				return
			var r := t.get_global_rect()
			var bob := sin(Time.get_ticks_msec() / 450.0) * 4.0
			var above := r.position.y > 200.0
			pointer.rotation = 0.0 if above else PI
			pointer.position = Vector2(r.get_center().x - 32, (r.position.y - 68 - bob) if above else (r.end.y + 4 + bob))
			if info_panel.visible and info_panel.is_ancestor_of(t):
				# В карточке наконечник стоит у кнопки, подпись — за левым краем окна.
				var tip := 59.0  # наконечник с обводкой на SVG 64×64
				pointer.rotation = 0.0
				pointer.position = Vector2(r.get_center().x - 32, r.position.y - tip)
				var label_y := r.position.y - 26.0
				if t.name == "hire_plus":
					# Крупная стрелка слева: наконечник точно у «+».
					pointer.rotation = -PI / 2.0
					pointer.position = Vector2(r.position.x - tip, r.get_center().y - 32)
					label_y = r.get_center().y
				pointer_text.position = Vector2(maxf(6.0, info_panel.get_global_rect().position.x - pointer_text.size.x - 12.0), label_y - pointer_text.size.y / 2.0)
			elif above:
				pointer_text.position = pointer.position + Vector2(32 - pointer_text.size.x / 2.0, -26)
			else:
				# стрелка снизу смотрит вверх: подпись сбоку от неё, чтобы не налезать на окна ниже
				var vw := root.size.x
				var px := pointer.position.x + 64.0
				if px + pointer_text.size.x > vw - 6.0:
					px = pointer.position.x + 2.0 - pointer_text.size.x
				pointer_text.position = Vector2(px, pointer.position.y + 32.0 - pointer_text.size.y / 2.0)
			# стрелка к медальону или кнопке легла бы на открытую карточку (подпись — поверх имени героя): пока карточка
			# открыта, стрелки нет (проверка 26.10); стрелка к кнопке в самой карточке («Улучшить» Казарм) — остаётся
			if info_panel.visible and not info_panel.is_ancestor_of(t) and Rect2(pointer.position, pointer.size).merge(
					Rect2(pointer_text.position, pointer_text.size)).intersects(info_panel.get_global_rect()):
				pointer.visible = false
				pointer_text.visible = false


func _tutorial_pointer_projection() -> Vector2:
	if _pointer_badge.is_empty():
		return Vector2.INF
	var cam := get_viewport().get_camera_3d()
	var vr := get_viewport().get_visible_rect()
	var pos: Vector3 = _pointer_badge["pos"]
	if not _badge_camera_safe(cam, vr) or not pos.is_finite():
		return Vector2.INF
	var point := cam.unproject_position(pos)
	if cam.is_position_behind(pos):
		point = 2.0 * vr.get_center() - point
	return point if point.is_finite() else Vector2.INF


## Подбираем сторону у самой цели, чтобы карточки не прятали стрелку.
func _place_tutorial_pointer(target: Control, world: Vector2) -> void:
	var screen := get_viewport().get_visible_rect().grow(-4)
	var r := target.get_global_rect()
	if world.is_finite() and (not target.is_visible_in_tree() or not screen.has_point(world)):
		r = Rect2(world.clamp(screen.position, screen.end), Vector2.ZERO)
	var half := pointer.size * 0.5
	var bob := 6.0 + sin(Time.get_ticks_msec() / 450.0) * 4.0
	var sides: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	if target == game.tutorial.next_btn or r.get_center().y < 120.0:
		sides = [Vector2.DOWN, Vector2.RIGHT, Vector2.LEFT, Vector2.UP]
	elif target.name == "hire_plus" or target == game.tutorial.camera_keys:
		sides = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	var best := INF
	var direction := Vector2.DOWN
	for side: Vector2 in sides:
		var desired := r.get_center() + side * (half.x + (r.size * 0.5).dot(side.abs()) + bob) - half
		var at := desired.clamp(screen.position, screen.end - pointer.size).round()
		var box := Rect2(at, pointer.size)
		var cost := desired.distance_squared_to(at)
		for panel: Control in [game.tutorial.card, info_panel, tray, tool_panel, fam_box, research_panel]:
			if panel.is_visible_in_tree() and not panel.is_ancestor_of(target):
				cost += box.intersection(panel.get_global_rect()).get_area()
		if cost < best:
			best = cost
			pointer.position = at
			direction = side
	pointer.rotation = Vector2.UP.angle_to(direction)
	var label_at := pointer.position + Vector2(half.x - pointer_text.size.x * 0.5, -pointer_text.size.y - 4.0)
	pointer_text.position = label_at.clamp(screen.position, screen.end - pointer_text.size)



# ---------- панель инструмента (справа над кнопками) ----------

func _tool_panel() -> void:
	tool_panel = _panel(null, "bar", 0, 8)
	_put(tool_panel, Control.PRESET_BOTTOM_RIGHT, Vector2(-10, -BAR_H - 10))
	tool_panel.custom_minimum_size = Vector2(350, 0)
	tool_panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	tool_panel.add_child(v)
	var tr := HBoxContainer.new()
	tr.add_theme_constant_override("separation", 6)
	tool_title = _label("", 21, false, C_INK, font_title)
	tool_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tool_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tr.add_child(tool_title)
	# 3.6: поставили по ошибке — отменить с полным возвратом (30 с, пока никто не живёт)
	undo_btn = _round("undo", "Отменить постройку", 38, func(): game._undo("place"); refresh_undo())
	undo_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.add_child(undo_btn)
	v.add_child(tr)
	# 3.4: живая картинка постройки — тот же облик и цвет, что у призрака
	thumb_rect = TextureRect.new()
	thumb_rect.custom_minimum_size = Vector2(THUMB.x, THUMB.y)
	thumb_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	thumb_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb_rect.visible = false
	v.add_child(thumb_rect)
	# 3.4: цвет фасада — «Авто» (не как у соседей) или один из 10
	color_box = HBoxContainer.new()
	color_box.add_theme_constant_override("separation", 3)
	color_box.visible = false
	v.add_child(color_box)
	color_box.add_child(_label("Цвет:", 16, true))
	var auto := Button.new()
	auto.text = "Авто"
	auto.focus_mode = Control.FOCUS_NONE
	auto.add_theme_font_size_override("font_size", 14)
	auto.tooltip_text = "Цвет выберет игра — не такой, как у соседних домов (Shift+C — следующий цвет)"
	auto.set_meta("ci", -1)
	auto.pressed.connect(func(): game.set_color(-1); thumb_update())
	color_box.add_child(auto)
	for i in Defs.PALETTE.size():
		var ci := i
		var sw := Button.new()
		sw.custom_minimum_size = Vector2(22, 22)
		sw.focus_mode = Control.FOCUS_NONE
		sw.tooltip_text = "%s (Shift+C — следующий цвет)" % Defs.PALETTE[i]["name"]
		sw.set_meta("ci", i)
		sw.pressed.connect(func(): game.set_color(ci); thumb_update())
		color_box.add_child(sw)
	color_restyle()
	variant_box = HBoxContainer.new()
	variant_box.add_theme_constant_override("separation", 4)
	v.add_child(variant_box)
	gate_check = CheckBox.new()
	gate_check.text = "Калитка посередине (G)"
	gate_check.add_theme_font_size_override("font_size", 16)
	gate_check.focus_mode = Control.FOCUS_NONE
	gate_check.toggled.connect(func(x): game.fence_gate = x; game._fence_key = "")
	gate_check.visible = false
	v.add_child(gate_check)
	# «Перестроить»: как в Town to City — украшения позади дома, что мешают новому облику, сносятся (деньги вернутся)
	upg_decor_check = CheckBox.new()
	upg_decor_check.text = "Сносить мешающие украшения (половина цены вернётся)"
	upg_decor_check.add_theme_font_size_override("font_size", 15)
	upg_decor_check.focus_mode = Control.FOCUS_NONE
	upg_decor_check.tooltip_text = "Дому для нового класса нужно больше места сзади, а там стоят украшения — их уберут, как сносом, и дом перестроится"
	upg_decor_check.toggled.connect(func(x):
		game.upg_decor = x
		if game.cover:
			game.cover.refresh()
		_fill_tool_panel())
	upg_decor_check.visible = false
	v.add_child(upg_decor_check)
	tool_keys = _label("", 15, false, C_SOFT)
	tool_keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tool_keys.custom_minimum_size = Vector2(320, 0)
	v.add_child(tool_keys)
	tool_err = _label("", 16, true, C_BAD)
	tool_err.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tool_err.custom_minimum_size = Vector2(320, 0)
	v.add_child(tool_err)


func on_tool(t: String) -> void:
	for k in road_btns:
		if road_btns[k] is Button and k in ["road", "path", "plaza", "cobble", "footpath", "erase", "roadup", "ground", "grass", "ungrass"]:
			_set_on(road_btns[k], k == t)
	for k in tool_btns:
		_set_on(tool_btns[k], k == t or (k == "move" and t == "move_nature"))
	var group := _road_group(t)
	if group == "roads":
		_last_road_tool = t
	elif group == "grass":
		_last_grass_tool = t
	for k in road_groups:
		_set_on(road_groups[k], k == group)
	road_panel.visible = group != ""
	if road_panel.visible:
		_refresh_brush()
	tool_err.text = ""

	_fill_tool_panel()
	_update_pointer()


func _fill_tool_panel() -> void:
	_fill_tool_panel_body()
	tool_err.visible = tool_err.text != ""
	_snug(tool_panel)


func _fill_tool_panel_body() -> void:
	var t: String = game.tool
	tool_panel.visible = t != ""
	_clear(variant_box)
	variant_box.visible = false
	thumb_rect.visible = false
	color_box.visible = false
	gate_check.visible = false
	upg_decor_check.visible = t == "upgrade" and game.city.research.has("artisans")
	upg_decor_check.set_pressed_no_signal(game.upg_decor)
	undo_btn.visible = Defs.B.has(t)          # у дорог свои «Отменить» и «Вернуть» — в панели кисти
	refresh_undo()
	if t == "":
		return
	if t == "floor":
		var c: City = game.city
		var n: int = c.floor_ready(false).size()
		tool_title.text = "Этаж · готовы домов: %d" % n
		tool_err.text = ""
		tool_keys.text = "Щёлкните по дому со стрелкой — над ним вырастет этаж, туда въедет ещё семья. Ведите с зажатой кнопкой вдоль улицы — этаж получат все готовые дома под курсором, пока хватает денариев.\nГотов дом, когда он полон, а счастье в нём от %d%% (3-й этаж — от %d%%). Esc или правая кнопка — выход." % [int(Defs.FLOOR_HAPPY[2]), int(Defs.FLOOR_HAPPY[3])]
		if not c.research.has("floor2"):
			tool_err.text = "Этажи откроет исследование «%s» (уровень «%s»)" % [Defs.research("floor2")["name"], Defs.LEVELS[int(Defs.research("floor2")["lvl"])]["name"]]
		elif n == 0:
			tool_err.text = "Пока ни один дом не готов: наведите на дом — у курсора будет написано, чего ему не хватает"
		return
	if t == "upgrade":
		var c: City = game.city
		var n: int = c.upgrade_ready(false).size()
		if game.upg_decor:
			var us := Cover.upgrade_sets(c, true)          # и дома, которым мешают одни украшения позади
			n = (us["ready"] as Array).size() + (us["short"] as Array).size()
		tool_title.text = "Перестроить · готовы домов: %d" % n
		tool_err.text = ""
		tool_keys.text = "Щёлкните по дому или ведите мышью вдоль улицы — класс станет выше.\nНужны исследование, денарии и место. Esc — выход."
		if not c.research.has("artisans"):
			tool_err.text = "Перестройку откроет исследование «%s» (уровень «%s»)" % [Defs.research("artisans")["name"], Defs.LEVELS[int(Defs.research("artisans")["lvl"])]["name"]]
		elif n == 0:
			tool_err.text = "Пока ни один дом не готов: наведите на дом — у курсора будет написано, чего ему не хватает"
		return
	if t == "story_zone":
		tool_title.text = "Место задания"
		tool_keys.text = "Щёлкните по земле, чтобы поставить круг.\nEsc или правая кнопка — отмена."
		return
	if t == "settle":
		var f: Dictionary = game.settle_fam
		var cd: Dictionary = Defs.CLASSES[f.get("cls", "plebs")]
		var home_name: String = Defs.B[cd["house"]]["name"]
		tool_title.text = "Семья %s" % f.get("name", "")
		tool_keys.text = "%d чел. · %s. Хотят жить: «%s».\nЩёлкните по светящемуся дому. Правая кнопка — отмена." % [int(f.get("n", 0)), cd["name"].to_lower(), home_name]
		if game.city.homes_for(f).is_empty():
			tool_err.text = "Свободного дома нет — постройте «%s» у дороги. Семья подождёт на площади." % home_name
		else:
			variant_box.visible = true
			var auto := Button.new()
			auto.text = "Выбрать дом за меня"
			auto.pressed.connect(func(): game.settle_auto())
			variant_box.add_child(auto)
		variant_box.visible = true
		variant_box.add_child(_refuse_button(String(f["name"])))
		return
	if Defs.B.has(t):
		var d: Dictionary = Defs.B[t]
		tool_title.text = "%s · %s" % [d["name"], "подарок, даром" if game.city.gift_ready(t) else fmt(game.city.build_price(t)) + " ден."]
		thumb_rect.visible = true
		color_box.visible = d["kind"] != "decor" and game.moving.is_empty()
		color_restyle()
		thumb_update()
		var keys := "Повернуть: зажмите левую кнопку и ведите мышь вбок (или Z/X) · правая кнопка — отмена"
		if d.get("seg", false):
			keys = "Тяните с зажатой кнопкой, как дорогу: звенья встанут по линии, цена — у курсора. Щелчок — одно звено (Z/X — повернуть). Esc или правая кнопка посреди — отмена"
			gate_check.visible = d.get("gate", false)
			gate_check.set_pressed_no_signal(game.fence_gate)
		elif d.get("wall", false):
			keys = "Наведите на стену дома — украшение встанет там, где курсор, на любом этаже, мимо окон и дверей · правая кнопка — отмена"
		if d.has("nat"):
			# «Природа»: модель случайная на каждый щелчок (C/V — листать), у цветов — выбор цвета
			keys = "Каждый щелчок — новая случайная модель (C / V — листать) · " + keys
			variant_box.visible = true
			if d.get("fcolors", false):
				variant_box.add_child(_label("Цвет:", 16, true))
				for ci in CatNature.FLOWER_COLORS.size():
					var fc := ci
					var cb := Button.new()
					cb.custom_minimum_size = Vector2(30, 30)
					cb.focus_mode = Control.FOCUS_NONE
					cb.tooltip_text = String(CatNature.FLOWER_COLORS[ci][0])
					cb.set_meta("fc", ci)
					for st in ["normal", "hover", "pressed"]:
						var sb := StyleBoxFlat.new()
						sb.bg_color = CatNature.FLOWER_COLORS[ci][1]
						sb.set_corner_radius_all(15)
						sb.set_border_width_all(4 if (st != "normal" or game.flower_color == ci) else 2)
						sb.border_color = C_GOLD if (st != "normal" or game.flower_color == ci) else Color("6b4a2a")
						cb.add_theme_stylebox_override(st, sb)
					cb.pressed.connect(func():
						game.flower_color = fc
						for o in variant_box.get_children():
							if o is Button and o.has_meta("fc"):
								var on: bool = int(o.get_meta("fc")) == fc
								(o as Button).get_theme_stylebox("normal").set("border_color", C_GOLD if on else Color("6b4a2a"))
								(o as Button).get_theme_stylebox("normal").set("border_width_left", 4 if on else 2)
								(o as Button).get_theme_stylebox("normal").set("border_width_right", 4 if on else 2)
								(o as Button).get_theme_stylebox("normal").set("border_width_top", 4 if on else 2)
								(o as Button).get_theme_stylebox("normal").set("border_width_bottom", 4 if on else 2)
						if game.ghost != null and not game.place_info.is_empty():
							game._ghost_frozen()          # призрак сразу нового цвета (пока он есть)
						thumb_update())
					variant_box.add_child(cb)
			else:
				variant_box.add_child(_label("Модель: случайная каждый раз", 15, false, C_SOFT))
		elif int(d.get("variants", 1)) > 1:
			keys = "C/V — другой фасад · " + keys
			variant_box.visible = true
			variant_box.add_child(_label("Фасад:", 16, true))
			for i in int(d["variants"]):
				var vi := i
				var b := Button.new()
				b.text = str(i + 1)
				_small(b)
				b.tooltip_text = "Фасад %d" % (i + 1)
				b.set_meta("vi", i)
				# панель не пересобираем: кнопка под мышью остаётся, призрак стоит на месте и сразу меняет фасад
				b.pressed.connect(_facade_pick.bind(vi))
				if game.tool_variant == i:
					b.add_theme_stylebox_override("normal", _medal("medal_on", 34))
				variant_box.add_child(b)
			var rnd := CheckBox.new()
			rnd.text = "Случайный"
			rnd.button_pressed = game.tool_variant < 0
			rnd.add_theme_font_size_override("font_size", 15)
			rnd.toggled.connect(func(x): game.tool_variant = -1 if x else game.next_variant; _facade_restyle())
			variant_box.add_child(rnd)
		if d["kind"] != "decor" and d["kind"] != "farm":
			keys += "\nПривязка к дороге (R): " + ("вкл" if game.snap else "выкл")
		tool_keys.text = keys
	else:
		var names := {"cobble": "Булыжник", "footpath": "Плиточная дорожка", "road": "Мостовая", "path": "Тропа", "plaza": "Площадь", "erase": "Ластик", "bulldoze": "Снос", "copy": "Копировать", "move": "Перенести", "move_nature": "Перенести",
			"roadup": "Улучшить дорогу", "ground": "Земля", "grass": "Трава", "ungrass": "Убрать траву"}
		tool_title.text = names.get(t, t)
		var keys := {"cobble": "Каменная улица с мягкими краями. Стоит как мостовая.",
			"footpath": "Камни среди травы. Стоит как тропа.", "road": "Каменная улица. Ведите с зажатой левой кнопкой. [ ] — размер, Ctrl+Z — отменить, Esc посреди мазка — отменить его.",
			"path": "Утоптанная тропа — самая дешёвая дорога: ею удобно тянуть длинные улицы к окраинам.", "plaza": "Плитка для площадей у рынков и храмов — самая дорогая.", "erase": "Наведите на дорогу — что уберётся, видно красным. Ведите с зажатой кнопкой: дорога уберётся, когда отпустите (Esc посреди — передумать). Звенья заборов под ластиком тоже уберутся.",
			"bulldoze": "Наведите на постройку, дерево или камень — подсветится красным. Щелчок — снести.", "copy": "Щёлкните по постройке — возьмёте такую же: тот же облик, цвет фасада и поворот. Без инструмента — наведите на постройку и нажмите F.",
			"move": "Щёлкните по постройке, дереву или камню и поставьте на новое место.", "move_nature": "Поставьте на новое место. Z/X — повернуть.",
			"roadup": "Ведите по улице с зажатой кнопкой: тропа станет мостовой, мостовая — дорогой из больших каменных плит, площадь — травертином с мозаикой. По плитам горожане ходят быстрее, а дома у ухоженной улицы счастливее на %d%%." % Defs.STREET_BONUS,
			"ground": "Узор на траве — для красоты: выберите кружок и ведите с зажатой кнопкой. Счастья не прибавляет, зато город становится живым. Кружок «Трава» и «Ластик» стирают узор.",
			"grass": "Кисть травы: ведите с зажатой кнопкой — там вырастет густая трава с цветами. Бесплатно, [ ] — размер кисти. Убрать — кистью «Убрать траву».",
			"ungrass": "Ведите с зажатой кнопкой — трава и цветы под кистью исчезнут, останется земля. Бесплатно, [ ] — размер кисти. Вернуть — кистью «Трава»."}
		var txt: String = keys.get(t, "")
		if Defs.ROAD_COST.has(t):
			# цена видна сразу: сколько стоит метр при нынешней кисти — у всех трёх видов дороги
			tool_title.text = "%s · около %s ден. за метр" % [names[t], price_txt(road_price_m(t))]
			txt += "\nМетр при кисти %s: тропа ~%s · мостовая ~%s · площадь ~%s ден." % [
				("%.2f" % game.brush_r).trim_suffix("0").replace(".", ","), price_txt(road_price_m("path")), price_txt(road_price_m("road")), price_txt(road_price_m("plaza"))]
		tool_keys.text = txt + "\nПравая кнопка — отмена"


## Выбран фасад: медали перекрашиваются, призрак меняет облик сразу (game._ghost_frozen), панель не пересобирается
func _facade_pick(vi: int) -> void:
	game.tool_variant = vi
	game.next_variant = vi
	_facade_restyle()
	thumb_update()                            # картинка в панели — сразу, тем же щелчком


func _facade_restyle() -> void:
	for ch in variant_box.get_children():
		if ch is CheckBox:
			(ch as CheckBox).set_pressed_no_signal(game.tool_variant < 0)
		elif ch is Button and ch.has_meta("vi"):
			(ch as Button).add_theme_stylebox_override("normal", _medal("medal_on" if game.tool_variant == int(ch.get_meta("vi")) else "medal", 34))


func tool_status(err: String) -> void:
	if tool_err.text != err:
		tool_err.text = err
		tool_err.visible = err != ""
		_snug(tool_panel)


## Цена метра дороги при нынешней кисти: полоса шириной 2r из клеток по 25 см
func road_price_m(t: String) -> float:
	if not Defs.ROAD_COST.has(t):
		return 0.0
	return 2.0 * float(game.brush_r) / Land.CELL / Land.CELL * float(Defs.ROAD_COST[t])


## Цена словами: мелочь — с десятыми, остальное — целыми
func price_txt(v: float) -> String:
	if v < 9.95:
		return ("%.1f" % v).trim_suffix(",0").trim_suffix(".0").replace(".", ",")
	return fmt(v)


var _stroke_lbl: Label
var _stroke_tw: Tween
var _stroke_warn: Label


## Подпись у курсора, пока тянут прямую дорогу, ластик или забор (3.1, 3.2): main — «12 м · 42 ден.», warn — вторая
## строка («Денег хватит до сюда»). Гаснет вместе с подписью мазка (stroke_live(…, done))
func stroke_text(main: String, warn := "", col := C_CREAM) -> void:
	stroke_live(0.0, "road", false)           # подпись и казна — как у мазка
	_stroke_lbl.text = main
	_stroke_lbl.add_theme_color_override("font_color", col)
	if _stroke_warn == null:
		_stroke_warn = _label("", 17, true, Color("ffb09a"))
		_stroke_warn.add_theme_color_override("font_outline_color", Color("3a2412"))
		_stroke_warn.add_theme_constant_override("outline_size", 7)
		_stroke_lbl.add_child(_stroke_warn)
	_stroke_warn.text = warn
	_stroke_warn.visible = warn != ""
	_stroke_warn.position = Vector2(0, 24)
	_stroke_lbl.reset_size()


## Медали «Отменить»: в панели постройки — серая, когда отменять нечего (подсказка — что отменится и сколько
## вернётся); у дорог «Отменить» и «Вернуть» — серые, когда стопки пусты (3.6)
func refresh_undo() -> void:
	if undo_btn:
		var u: Dictionary = game.undo_place_info()
		undo_btn.disabled = u.is_empty()
		if u.is_empty():
			undo_btn.tooltip_text = "Отменить постройку можно 30 секунд, пока в ней никто не живёт"
		else:
			undo_btn.tooltip_text = "Отменить: %s, вернётся %s ден." % [u["name"], fmt(float(u["cost"]))]
		_grey(undo_btn.get_node("ic") as CanvasItem, u.is_empty())
	for nm in ["undo", "redo"]:
		if road_btns.has(nm):
			var b: Button = road_btns[nm]
			var empty: bool = (game.undo_stack if nm == "undo" else game.redo_stack).is_empty()
			if nm == "undo" and not empty:
				empty = String((game.undo_stack.back() as Dictionary).get("t", "road")) == "place"
			if nm == "redo":
				b.tooltip_text = "Вернуть (Ctrl+Y)" + ("" if empty else ": %s ден." % price_txt(float((game.redo_stack.back() as Dictionary).get("cost", 0.0))))
			b.disabled = empty
			_grey(b.get_node("ic") as CanvasItem, empty)


## Ряд цветов: выбранный — в золотой рамке
func color_restyle() -> void:
	if color_box == null:
		return
	for b in color_box.get_children():
		if not (b is Button) or not b.has_meta("ci"):
			continue
		var ci := int(b.get_meta("ci"))
		var on: bool = ci == int(game.color_user)
		if ci < 0:
			b.custom_minimum_size = Vector2(52, 26)
			b.add_theme_stylebox_override("normal", _box_pill(8, 2, "g_btn_on" if on else "g_btn"))
			b.add_theme_stylebox_override("hover", _box_pill(8, 2, "g_btn_hover"))
			b.add_theme_stylebox_override("pressed", _box_pill(8, 2, "g_btn_on"))
			continue
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Defs.PALETTE[ci]["c"]
			sb.set_corner_radius_all(11)
			sb.set_border_width_all(3 if on else (2 if st == "hover" else 1))
			sb.border_color = C_GOLD if on else (C_SOFT if st == "hover" else Color(0.29, 0.17, 0.09, 0.6))
			b.add_theme_stylebox_override(st, sb)
	thumb_update()


# ---------- живая картинка постройки в панели (3.4) ----------

var _thumb_vp: SubViewport
var _thumb_cam: Camera3D
var _thumb_holder: Node3D
var _thumb_key := ""


func _thumb_make() -> void:
	var vp := SubViewport.new()
	vp.size = THUMB
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("f3e6cf")
	e.ambient_light_energy = 0.85
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.2
	we.environment = e
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.light_energy = 2.2
	sun.light_color = Color("fff0d8")
	vp.add_child(sun)
	_thumb_cam = Camera3D.new()
	_thumb_cam.fov = 30
	vp.add_child(_thumb_cam)
	_thumb_holder = Node3D.new()
	vp.add_child(_thumb_holder)
	_thumb_vp = vp
	thumb_rect.texture = vp.get_texture()


## Облик будущей постройки (тип, этаж, фасад, цвет) — как у призрака; картинка перерисовывается один раз, только
## когда облик поменялся (без чтения с видеокарты: ViewportTexture прямо в панели)
func thumb_update() -> void:
	if thumb_rect == null or not thumb_rect.visible or game == null or not Defs.B.has(game.tool):
		return
	var t: String = game.tool
	var pl: Dictionary = game.place_info if String(game.place_info.get("_t", "")) == t else {}
	var d: Dictionary = Defs.B[t]
	var tier := int(pl.get("tier", 1 if d["kind"] == "house" else 0))
	var v := int(pl.get("variant", 0))
	if d["kind"] != "decor" and game.moving.is_empty():
		v = int(game.next_variant)
	var c := int(pl.get("color", maxi(0, int(game.place_color))))
	if int(game.color_user) >= 0 and d["kind"] != "decor":
		c = int(game.color_user)
	if d.get("seg", false):
		v = 1 if game.fence_gate else 0
	var key := "%s:%d:%d:%d" % [t, tier, v, c]
	if key == _thumb_key:
		return
	_thumb_key = key
	if _thumb_vp == null:
		_thumb_make()
	for ch in _thumb_holder.get_children():
		ch.queue_free()
	var g := Parts.ghost(Catalog.make(t, tier, v, c), "outline", Color(0, 0, 0, 0))
	for gi: GeometryInstance3D in g.find_children("*", "GeometryInstance3D", true, false):
		gi.material_override = null
	for ch in g.get_children():
		if ch is MeshInstance3D and (ch as MeshInstance3D).mesh == Parts._special_mesh("#dark") and (ch as Node3D).position.y < -0.05:
			g.remove_child(ch)
			ch.free()
	_thumb_holder.add_child(g)
	var box := Artisau.aabb(g)
	var ctr := box.get_center()
	var rad := maxf(0.3 if d["kind"] == "decor" else 0.6, box.size.length() * 0.5)
	var dir := Vector3(0.62, 0.6, 0.95).normalized()
	_thumb_cam.look_at_from_position(ctr + dir * rad / sin(deg_to_rad(15.0)) * 0.95, ctr, Vector3.UP)
	_thumb_vp.render_target_update_mode = SubViewport.UPDATE_ONCE

## Пока ведут кисть: казна меняется сразу, у курсора — сколько стоит этот мазок (или что денег не хватило).
## done — мазок окончен, подпись мягко гаснет
func stroke_live(cost: float, t: String, broke := false, done := false) -> void:
	var c: City = game.city
	lbl_money.text = "%s / %s" % [fmt(c.money), fmt(c.money_cap())]
	if _stroke_lbl == null:
		_stroke_lbl = _label("", 19, true, C_CREAM)
		_stroke_lbl.add_theme_color_override("font_outline_color", Color("3a2412"))
		_stroke_lbl.add_theme_constant_override("outline_size", 8)
		_stroke_lbl.visible = false
		root.add_child(_stroke_lbl)
	if done:
		if _stroke_lbl.visible:
			if _stroke_tw:
				_stroke_tw.kill()
			_stroke_tw = _stroke_lbl.create_tween()
			_stroke_tw.tween_interval(0.9)
			_stroke_tw.tween_property(_stroke_lbl, "modulate:a", 0.0, 0.6)
			_stroke_tw.tween_callback(func(): _stroke_lbl.visible = false)
		return
	if t == "erase" or not (Defs.ROAD_COST.has(t) or game.is_deco_tool(t)):
		_stroke_lbl.visible = false
		return
	if _stroke_tw and _stroke_tw.is_valid():
		_stroke_tw.kill()
	if _stroke_warn:
		_stroke_warn.visible = false
	if broke:
		_stroke_lbl.text = "Не хватает денариев · мазок %s ден." % fmt(cost)
		_stroke_lbl.add_theme_color_override("font_color", Color("ffb09a"))
	else:
		_stroke_lbl.text = "Этот мазок: %s ден." % fmt(cost)
		_stroke_lbl.add_theme_color_override("font_color", C_CREAM)
	_stroke_lbl.modulate.a = 1.0
	_stroke_lbl.visible = true
	_stroke_lbl.reset_size()
	var mp: Vector2 = game._mouse_pos if game._mouse_pos.x >= 0.0 else root.get_local_mouse_position()
	_stroke_lbl.position = (mp + Vector2(24, -40)).round()



# ---------- карточка постройки ----------

func _info_panel() -> void:
	info_panel = _panel(null, "scroll_v", 0, 8)
	_put(info_panel, Control.PRESET_TOP_RIGHT, Vector2(-10, 62))
	info_panel.custom_minimum_size = Vector2(INFO_WIDTH, 0)
	info_panel.visible = false
	info_box = VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 6)
	info_box.custom_minimum_size = Vector2(INFO_BODY, 0)
	info_panel.add_child(info_box)


func open_info(b: Dictionary) -> void:
	_close_tray()
	_close_windows()
	if not info_p.is_empty():
		info_p = {}
		PersonCard.close()
		if game and game.people:
			game.people.set_focus(0)
	elif not info_b.is_empty() and int(info_b.get("id", -1)) != int(b.get("id", -2)):
		PersonCard.close()                    # была карточка «Кошачьей лавки» с портретом
	info_b = b
	info_panel.visible = true
	_fill_info()
	_update_pointer()                         # обучение Легиону: в карточке Казарм стрелка — на «Улучшить»


## Карточка жителя или кошки (щелчок по нему на улице, строка в карточке дома, «Горожане»): {"r": житель} / {"cat": кошка}
func open_person(sel: Dictionary) -> void:
	_close_tray()
	_close_windows()
	info_b = {}
	info_p = sel
	info_panel.visible = true
	_fill_info()


## Подпись у курсора над жителем или кошкой («Гай Юлий · пекарь») — маленькая кремовая табличка, не окно
func _person_tag_tick(dt: float) -> void:
	var on := false
	if game != null and game.ready_done and game.mode != "menu" and game.tool == "" and game.people != null and root.visible \
			and game.rig != null and not game.rig.cine and not mouse_over_ui() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var hit: Dictionary = game.people.hover_pick(game._mouse_pos)
		if not hit.is_empty():
			if person_tag == null:
				var pc := PanelContainer.new()
				pc.add_theme_stylebox_override("panel", _box_pill(10, 3))
				pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
				person_tag = _label("", 15, true, C_INK)
				pc.add_child(person_tag)
				root.add_child(pc)
			person_tag.text = game.people.tag_of(hit["r"]) if hit.has("r") else "%s · %s" % People.cat_name(hit["cat"])
			var pc: Control = person_tag.get_parent()
			pc.reset_size()
			# справа снизу от курсора; не влезает — по другую сторону, всегда целиком на экране (как _place_caption)
			var mp: Vector2 = game._mouse_pos if game._mouse_pos.x >= 0.0 else root.get_local_mouse_position()
			var sz := pc.get_combined_minimum_size()
			var p := mp + Vector2(20, 24)
			if p.x + sz.x > root.size.x - 6.0:
				p.x = mp.x - 18.0 - sz.x
			if p.y + sz.y > root.size.y - 6.0:
				p.y = mp.y - 14.0 - sz.y
			p.x = clampf(p.x, 6.0, maxf(6.0, root.size.x - sz.x - 6.0))
			p.y = clampf(p.y, 6.0, maxf(6.0, root.size.y - sz.y - 6.0))
			pc.position = p.round()
			on = true
	if person_tag != null:
		(person_tag.get_parent() as Control).visible = on
	if game != null and game.people != null:
		var hh: Dictionary = game.people.hover_pick(game._mouse_pos) if on else {}
		game.people.hero_hover(on and hh.has("r") and (hh["r"] as Dictionary).has("hero"))   # над героем — мягкая обводка
	# советник один раз (этап 6.3): мышь задержалась на прохожем — рассказать, что его можно нажать и что в карточке
	_tag_dwell = _tag_dwell + dt if on else 0.0
	if _tag_dwell >= 0.8 and not game.city.tips.has("people_tip") and _tip_free() and _screen_free():
		game.city.tips["people_tip"] = true
		advisor("У каждого жителя — имя", "Это житель вашего города. Нажмите на него: узнаете, кто он в семье, где работает, что делает сейчас и чего ему не хватает для счастья. Кнопка «Следовать» — камера пойдёт за ним по улицам; найти любого по имени можно в «Жители и работники» → «Горожане». Причёски и наряды горожане меняют в цирюльне и лавках одежды — а выбрать их можете и вы, кнопкой «Внешность» в его карточке. Кошек тоже можно нажать.")


var _tag_dwell := 0.0



## Общий значок профессии: кремовый диск, у подходящего работника — зелёный край.
func _profession_icon(prof: String, side: int, fits := false) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.name = "ProfessionIcon"
	badge.custom_minimum_size = Vector2(side, side)
	badge.size = Vector2(side, side)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_PASS
	badge.set_meta("profession", prof)
	badge.set_meta("fits", fits)
	var frame := _card_frame(side >> 1, 1)
	frame.border_color = C_GOOD if fits else Color("bc9655")
	frame.set_border_width_all(2 if fits else 0)
	badge.add_theme_stylebox_override("panel", frame)
	var d: Dictionary = Defs.PROFESSIONS.get(prof, {})
	badge.tooltip_text = String(d.get("name", "")) + "\n+20% к работе, если подходит"
	var picture := TextureRect.new()
	picture.name = "ProfessionPicture"
	picture.texture = load("res://assets/ui/prof/%s.png" % String(d.get("icon", ""))) if not d.is_empty() else null
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(picture)
	return badge


## Работа: каждый силуэт — одно место; заполненные места показывают класс жителя.
func _hire_row(b: Dictionary) -> VBoxContainer:
	var c: City = game.city
	var mx := c.job_max(b)
	var h := c.hired_of(b)
	var members := c.staff_members(b) if c.manual_hiring() else []
	var profession := Defs.building_profession(c.def(b))
	var block := VBoxContainer.new()
	block.name = "work_block"
	block.add_theme_constant_override("separation", 3)
	block.add_child(_divider(4))
	var title := _label("Работа", 14, true, CARD_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	block.add_child(title)
	var crew := HBoxContainer.new()
	crew.name = "work_crew"
	crew.alignment = BoxContainer.ALIGNMENT_CENTER
	crew.add_theme_constant_override("separation", 8)
	block.add_child(crew)
	# Один знак объясняет, кому доступна работа; места ниже — без рамок.
	for cls: String in Defs.CLASS_ORDER:
		if int(c.def(b).get("jobs", {}).get(cls, 0)) > 0:
			var required := CityStyle.pictogram(String(CityStyle.CLASS_ICON[cls]), 28)
			required.name = "RequiredWorkerClass"
			required.tooltip_text = String(Defs.CLASSES[cls]["name"])
			required.mouse_filter = Control.MOUSE_FILTER_PASS
			crew.add_child(required)
			break
	if Defs.PROF_ON and profession != "":
		var match_row := HBoxContainer.new()
		match_row.name = "profession_summary"
		match_row.alignment = BoxContainer.ALIGNMENT_CENTER
		match_row.add_theme_constant_override("separation", 3)
		var wanted := _profession_icon(profession, 26)
		wanted.set_meta("profession_role", "wanted")
		var fitting := int(b.get("prof_fit", 0)) if c.manual_hiring() else 0
		wanted.tooltip_text += "\n" + "Подходят %d из %d" % [fitting, h]
		match_row.add_child(wanted)
		var number := _label("%d / %d" % [fitting, h], 13, true, C_GOOD if fitting > 0 else CARD_ACCENT)
		number.name = "profession_count"
		match_row.add_child(number)
		crew.add_child(match_row)
	var slots := GridContainer.new()
	slots.name = "worker_slots"
	slots.columns = mini(6, mx)
	slots.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slots.add_theme_constant_override("h_separation", 5)
	crew.add_child(slots)
	var index := 0
	for cls: String in Defs.CLASS_ORDER:
		for k in int(c.def(b).get("jobs", {}).get(cls, 0)):
			var occupied := false
			var worker_prof := ""
			var tip := String(Defs.CLASSES[cls]["name"])
			if c.manual_hiring():
				var same: Array = members.filter(func(w: Dictionary) -> bool: return String(w["m"].get("job_class", "")) == cls)
				occupied = k < same.size()
				if occupied:
					worker_prof = String(same[k]["m"].get("prof", ""))
					tip = Residents.full_name(same[k]["m"], same[k]["family"])
			else:
				occupied = index < roundi(h * float(b.get("fill", 1.0)))
			var slot := Control.new()
			slot.name = "worker_slot_%d" % index
			slot.custom_minimum_size = Vector2(28, 32)
			slot.tooltip_text = tip
			slot.set_meta("worker_slot", true)
			slot.set_meta("occupied", occupied)
			var figure := CityStyle.pictogram("person", 28)
			figure.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			figure.modulate.a = 1.0 if occupied else 0.22
			slot.add_child(figure)
			if Defs.PROF_ON and occupied and worker_prof != "":
				var badge := _profession_icon(worker_prof, 18, worker_prof == profession)
				badge.set_meta("profession_role", "worker")
				badge.position = Vector2(14, 14)
				slot.add_child(badge)
			slots.add_child(slot)
			index += 1
	for cls: String in Defs.CLASS_ORDER:
		if int(c.def(b).get("jobs", {}).get(cls, 0)) <= 0:
			continue
		var free := int(c.stats.get("free", {}).get(cls, 0))
		var available := HBoxContainer.new()
		available.name = "hire_class_" + cls
		available.tooltip_text = String(Defs.CLASSES[cls]["name"])
		available.alignment = BoxContainer.ALIGNMENT_CENTER
		available.add_theme_constant_override("separation", 5)
		available.add_child(CityStyle.pictogram(String(CityStyle.CLASS_ICON[cls]), 24))
		var free_label := _label("свободно: %d" % free, 14, true, CARD_ACCENT if free > 0 else C_BAD)
		free_label.name = "hire_free_" + cls
		free_label.tooltip_text = String(Defs.CLASSES[cls]["name"])
		free_label.mouse_filter = Control.MOUSE_FILTER_PASS
		available.add_child(free_label)
		block.add_child(available)
	var can_add := c.can_hire(b)
	if h < mx and not can_add and not b.get("over", false):
		var none := _wrap(_label("Нет свободных горожан нужного класса", 14, false, C_SOFT), INFO_BODY)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		block.add_child(none)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	var minus := Button.new()
	minus.name = "hire_minus"
	minus.text = "−"
	_card_button(minus, true)
	minus.disabled = h <= 0
	minus.tooltip_text = "Уволить работника"
	minus.pressed.connect(func(): game.happy_action(func(): c.fire(b), b["pos"]); _fill_info())
	var plus := Button.new()
	plus.name = "hire_plus"
	plus.set_meta("quest_action", "hire")
	plus.text = "+"
	_card_button(plus, true)
	plus.disabled = not can_add
	plus.tooltip_text = "Нанять работника" if can_add or h >= mx else "Нет свободных горожан нужного класса"
	plus.pressed.connect(func(): game.happy_action(func(): c.hire(b), b["pos"]); _fill_info())
	var count := _label("%d / %d" % [h, mx], 18, true, C_GOOD if h > 0 else C_SOFT)
	count.name = "hire_n"
	row.add_child(minus)
	row.add_child(count)
	if c.manual_hiring() and h == 0:
		var pointer_gap := Control.new()
		pointer_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pointer_gap.custom_minimum_size.x = 64
		row.add_child(pointer_gap)
	row.add_child(plus)
	row.add_child(_label("%d%%" % roundi(float(b.get("staff", 0.0)) * 100.0), 14, true, C_SOFT))
	block.add_child(row)
	return block


## Первый найм объясняем один раз, когда освободится советник.
func on_workplace_built(b: Dictionary) -> void:
	var c: City = game.city
	if c.manual_hiring() and c.job_max(b) > 0 and not c.tips.has("manual_hire_tip"):
		if not c.tips.has("manual_hire_pending"):
			c.tips["manual_hire_pending"] = int(b["id"])
		if tutorial_busy():
			c.tips["manual_hire_tutorial"] = true


func _manual_hire_advice() -> bool:
	var c: City = game.city
	if not c.manual_hiring() or not c.tips.has("manual_hire_pending") or c.tips.has("manual_hire_tip"):
		return false
	# Стройку и поворот призрака не перекрываем новым окном.
	if not game.ready_done or game.tool != "" or not advisor_on() or not _tip_free():
		return false
	var b: Dictionary = c.buildings.get(int(c.tips["manual_hire_pending"]), {})
	if b.is_empty() or (c.hired_of(b) > 0 and not c.tips.has("manual_hire_tutorial")):
		c.tips.erase("manual_hire_pending")
		return false
	c.tips["manual_hire_tip"] = true
	c.tips.erase("manual_hire_pending")
	c.tips.erase("manual_hire_tutorial")
	advisor("Работа в новом здании", "Работников добавляют кнопкой «+» в карточке здания. Кнопка «−» освобождает место.", Callable(), false, false, hire_do(b))
	return true


func hire_do(b: Dictionary) -> Dictionary:
	return {"kind": "hire", "id": int(b["id"]), "tip": "Нанять работника", "say": "Откройте здание и наймите работников кнопкой «+»"}


var _work_cycle := {}


func _cycle_work(cls: String) -> void:
	var c: City = game.city
	var places: Array = []
	for b: Dictionary in c.buildings.values():
		if not b.get("over", false) and int(c.def(b).get("jobs", {}).get(cls, 0)) > int(c.jobs_of(b).get(cls, 0)):
			places.append(b)
	if places.is_empty():
		_open_overview("city")
		return
	var index := (int(_work_cycle.get(cls, -1)) + 1) % places.size()
	_work_cycle[cls] = index
	_do_click(hire_do(places[index]))


## Маленькая круглая кнопка-медальон со знаком (−, +, номер фасада)
func _small(b: Button, w := 34.0) -> void:
	b.custom_minimum_size = Vector2(w, w)
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_font_override("font", font_bold)
	for st: Array in [["normal", "medal"], ["hover", "medal_hover"], ["pressed", "medal_on"], ["hover_pressed", "medal_on"], ["disabled", "medal_lock"]]:
		b.add_theme_stylebox_override(st[0], _medal(st[1], w))


## Строка карточки, которую можно нажать: прозрачная кнопка поверх (подсветка при наведении, подсказка tip)
func _clickable(row: Control, tip: String, cb: Callable) -> Control:
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in row.find_children("*", "Control", true, false):
		(ch as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(row)
	var b := Button.new()
	b.set_meta("bare", true) # Прозрачное действие поверх строки, без рамки карточки.
	b.focus_mode = Control.FOCUS_NONE
	var e := StyleBoxEmpty.new()
	for st in ["normal", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, e)
	var hov := StyleBoxFlat.new()
	hov.bg_color = Color(CityStyle.OLIVE, 0.10)
	hov.set_corner_radius_all(6)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("hover_pressed", hov)
	b.tooltip_text = tip
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(cb)
	m.add_child(b)
	return m


func _row(icon: String, text: String, val: String, col := C_INK) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	r.add_child(_icon(icon, 24, C_SOFT))
	var l := _label(text, 17)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(l)
	r.add_child(_label(val, 18, true, col))
	return r


## Карточку пересобирают при каждом обновлении города (раз в игровой час) — и каждый раз она должна
## сжаться ровно по содержимому: прикрепляем заново сразу и ещё раз через кадр (после переноса строк)
func _fill_info() -> void:
	_fill_info_body()
	if info_p.is_empty() and not info_b.is_empty():
		_compact_info_style()
	if info_b.is_empty() or game.city.def(info_b).get("kind", "") != "military":
		CityStyle.apply(info_panel)
	_snug(info_panel)
	_refit(info_panel)


func _fill_info_body() -> void:
	_clear(info_box)
	lg_upg_btn = null
	_lg_live = {}
	if not info_p.is_empty():
		info_panel.add_theme_stylebox_override("panel", _box_scroll_v(8))
		info_panel.custom_minimum_size.x = 370
		info_box.custom_minimum_size.x = 330
		# карточка жителя или кошки (этапы 6.3–6.5) — в том же окне справа сверху
		if not PersonCard.fill(self, info_box, info_p):
			info_p = {}
			PersonCard.close()
			info_panel.visible = false
		return
	var b := info_b
	if b.is_empty() or not game.city.buildings.has(b["id"]):
		if not b.is_empty():
			PersonCard.close()                # портрет кошки в карточке «Кошачьей лавки» — вместе с карточкой
			info_b = {}
		info_panel.visible = false
		return
	var c: City = game.city
	var d := c.def(b)
	var cw := INFO_BODY
	info_panel.add_theme_stylebox_override("panel", _card_frame())
	info_box.custom_minimum_size = Vector2(cw, 0)
	info_panel.custom_minimum_size = Vector2(INFO_WIDTH, 0)
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	var ib := _round(d.get("icon", Defs.CLASSES[d["cls"]]["icon"] if d.has("cls") else "info"), "Сменить цвет" if c.is_house(b) else d["name"], 42)
	if c.is_house(b):
		(ib.get_node("ic") as TextureRect).texture = ico("color", 60)
		ib.pressed.connect(func(): c.recolor(b))
	(ib.get_node("ic") as TextureRect).texture = MapBadge.ink_texture("color" if c.is_house(b) else String(d.get("icon", "info")))
	hdr.add_child(ib)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := _wrap(_label(d["name"], 18, false, CARD_ACCENT, font_title), cw - 90.0)
	nm.name = "InfoTitle"
	tv.add_child(nm)
	hdr.add_child(tv)
	var close := _bare("close", "Закрыть", 28, func(): close_panels())
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hdr.add_child(close)
	info_box.add_child(hdr)
	info_box.add_child(_divider(6))
	if not bool(b.get("road", true)) and not b.get("over", false) and d["kind"] != "decor":
		info_box.add_child(_wrap(_label("Нет дороги — постройте дорогу ко входу", 15, true, C_BAD), cw))
	match d["kind"]:
		"house":
			_fill_house(b, d, tv, cw)
		"shop":
			tv.add_child(_label(Defs.NEEDS[d["sub"]]["name"], 14, true, C_SOFT))
			info_box.add_child(_card_row("happy", "Счастье домам", "+%d%%" % int(d["bonus"]), C_GOOD))
			info_box.add_child(_card_row("arrow", "Дальность", Defs.WORD[int(d["range"])]))
			info_box.add_child(_card_row("housing", "Обслуживает домов", "%d из %d" % [int(b.get("served", 0)), int(ceil(float(Defs.CAPACITY[int(d["cap"])]) * float(b.get("staff", 1.0))))]))
			_cover_rows(b, "")
			if d.get("store", false):
				_store_row(b)
			if String(b["type"]) == "catshop":
				info_box.add_child(_divider(10))
				_catshop_rows(b, cw)
			if not b.get("active", true) and String(b.get("why", "")) != "road":
				var st_txt := c.idle_text(b)            # нет работников: почему именно (никто не живёт, не тот класс, мало мест)
				var why := {"store": "Нет склада рядом — нечем торговать", "good": "Нет сырья: %s" % {"wheat": "постройте пшеничное поле", "olives": "посадите оливковую рощу", "grapes": "посадите виноградник"}.get(d.get("needs_good", ""), ""),
					"road": "Нет дороги у входа", "staff": "Не работает: " + st_txt}
				var wl := _wrap(_label(why.get(b.get("why", "staff"), "Не работает"), 15, true, C_BAD), cw)
				info_box.add_child(wl)
		"inn":
			var ti := Tourism.inn_info(c, b)
			tv.add_child(_label("Гостей в сутки: %d" % int(ti["guests"]), 14, true, C_SOFT))
			info_box.add_child(_card_row("coins", "Доход от гостей", "+%s в час" % String.num(float(ti["per_h"]), 1).replace(".", ","), C_GOOD))
			info_box.add_child(_card_row("star", "Достопримечательности рядом", "%d из %d" % [roundi(float(ti["score"])), int(Tourism.TOUR_MAX)]))
			var names := []
			for e: Array in (ti["list"] as Array).slice(0, 5):
				names.append(String(e[0]))
			var tip := ("Гости ходят смотреть: %s." % ", ".join(names)) if not names.is_empty() else "Рядом нечего смотреть — поставьте в %d м храм, арку, фонтан, театр или акведук: гостей станет больше." % int(Tourism.TOUR_R)
			if float(ti["decor"]) > 0.0:
				tip += " Украшения вокруг тоже радуют гостей."
			info_box.add_child(_wrap(_label(tip, 14, false, C_SOFT), cw))
			if not b.get("active", true) and bool(b.get("road", true)):
				info_box.add_child(_wrap(_label("Не работает: " + c.idle_text(b), 15, true, C_BAD), cw))
		"monument":
			info_box.add_child(_card_row("happy", "Счастье всем вокруг", "+%d%%" % int(d["bonus"]), C_GOOD))
			info_box.add_child(_card_row("arrow", "Дальность", Defs.WORD[int(d["range"])]))
			_cover_rows(b, "Радует домов")
		"rp":
			info_box.add_child(_card_row("research", "Очки исследований в час", "+%.1f" % (c.rp_per_hour(b["type"]) * float(b.get("staff", 1.0))), C_GOOD))
			if b.get("over", false):
				# старый город: таких построек больше, чем можно на этом уровне — лишние не работают (их не сносим)
				info_box.add_child(_wrap(_label("Сверх предела уровня — не работает", 15, true, C_BAD), cw))
				var nl := c.level + 1
				var mx: Array = d.get("max", [])
				while nl < Defs.LEVELS.size() and nl < mx.size() and int(mx[nl]) <= c.build_max(b["type"]):
					nl += 1
				var more := (" Больше заработает на уровне «%s»." % Defs.LEVELS[nl]["name"]) if nl < Defs.LEVELS.size() and nl < mx.size() else ""
				info_box.add_child(_wrap(_label("На уровне «%s» работают %d (первые построенные).%s Сносить не нужно: пока постройка не работает, она ничего не стоит." % [Defs.LEVELS[c.level]["name"], c.build_max(b["type"]), more], 14, false, C_SOFT), cw))
		"farm":
			info_box.add_child(_card_row("wheat", "Даёт", {"wheat": "пшеницу", "olives": "оливки", "grapes": "виноград"}[d["makes"]], C_GOOD))
		"store":
			info_box.add_child(_card_row("arrow", "Разносит товары", Defs.WORD[4]))
			_cover_rows(b, "Снабжает лавок")
		"center":
			_post_arrivals(info_box)
			tv.add_child(_label("Уровень города: %s" % Defs.LEVELS[c.level]["name"], 14, true, C_SOFT))
			info_box.add_child(_card_row("scroll", "Почта привозит свитки", "+%s в час" % String.num(float(Defs.LEVELS[c.level].get("rp_h", 0.0)) * c.rp_mult(), 1), C_GOOD))
			var nx := c.next_level()
			if not nx.is_empty():
				# чек-лист условий следующего уровня; когда всё готово — кнопка «Перейти на новый уровень»
				var nd := c.rank_needs()
				info_box.add_child(_card_row("level", "Следующий уровень", "%s · %d из %d" % [nx["name"], c.rank_met(), nd.size()]))
				for e: Dictionary in nd:
					var val := ("%d%% / %d%%" % [int(e["have"]), int(e["need"])]) if e["pct"] else ("%s / %s" % [fmt(int(e["have"])), fmt(int(e["need"]))])
					var r := _card_row(e["icon"], e["text"], val, C_GOOD if e["ok"] else C_BAD)
					var mk := _card_icon("check" if e["ok"] else "close", 18)
					mk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					r.add_child(mk)
					# невыполненное условие — щелчком к делу (та же стрелка, что у просьб): постройка, исследование, «Этаж», «Обзор»
					var w: Dictionary = {} if e["ok"] else need_do(e["p"], String(e.get("tool", "")), int(e.get("need", 0)))
					if w.is_empty():
						info_box.add_child(r)
					else:
						info_box.add_child(_clickable(r, String(w.get("say", "")) + ".", func(): _do_click(need_do(e["p"], String(e.get("tool", "")), int(e.get("need", 0))))))
				if rank_shown():
					var rb := Button.new()
					rb.text = "Перейти на новый уровень"
					rb.icon = ico("level", 32)
					rb.focus_mode = Control.FOCUS_NONE
					rb.add_theme_font_override("font", font_bold)
					rb.add_theme_stylebox_override("normal", _box_pill(16, 6, "g_btn_on"))
					for st in ["font_color", "font_hover_color", "font_pressed_color"]:
						rb.add_theme_color_override(st, C_GOOD)
					rb.pressed.connect(press_rank)
					info_box.add_child(rb)
			_arrive_rows(info_box, false)
			var wait := c.arrive_wait()
			if wait != "":
				info_box.add_child(_wrap(_label(wait, 14, true, C_BAD), 330))
			if c.waiting > 0:
				info_box.add_child(_card_row("tent", "Ждут жилья", "%d %s" % [c.waiting, _plural(c.waiting, "семья", "семьи", "семей")], C_BAD))
			_fest_rows(info_box)
		"decor":
			info_box.add_child(_card_row("flower", "Очки украшения", "+%d" % int(d.get("deco", 1)), C_GOOD))
			_cover_rows(b, "Радует домов")
		"military":
			_legion_rows(b, tv, cw)
	if c.job_max(b) > 0:
		info_box.add_child(_hire_row(b))
	if String(b["type"]) == "bakery" and c.legion.v3():
		var ration_k: float = (float(b.get("staff", 0.0)) if b.get("active", false) else 0.0) if c.manual_hiring() else 1.0
		info_box.add_child(_card_row("legion", "Еда Легиону", "+%d в день" % int(round(Legion.RATION_BAKERY * ration_k)), C_GOOD))   # Легион 3.0: хлеб кормит лагерь
	info_panel.tooltip_text = String(d.get("desc", ""))
	if String(b.get("gift", "")) != "":         # подарок друга (SocialNet)
		info_box.add_child(_card_row("mail", "Подарок", "из «%s»" % String(b["gift"]), C_GOOD))
	if not d.get("fixed", false):
		var h := HBoxContainer.new()
		h.name = "InfoActions"
		h.alignment = BoxContainer.ALIGNMENT_END
		h.add_theme_constant_override("separation", 6)
		var bd := Button.new()
		bd.name = "InfoDemolish"
		bd.tooltip_text = "Снести"
		bd.icon = MapBadge.ink_texture("demolish")
		bd.pressed.connect(func(): c.remove(b); close_panels())
		h.add_child(bd)
		if not d.get("wall", false):              # украшение на стене не переносится (только снести и повесить заново)
			var bm := Button.new()
			bm.set_meta("quest_action", "move")
			bm.name = "InfoMove"
			bm.tooltip_text = "Перенести"
			bm.icon = MapBadge.ink_texture("move")
			# переносим именно эту постройку (не ту, что под курсором за карточкой)
			bm.pressed.connect(func(): game.set_tool("move"); game.start_move(b); close_panels())
			h.add_child(bm)
		# «Копировать»: сразу в руках такая же постройка — тот же облик, цвет фасада и поворот
		var bc := Button.new()
		bc.name = "InfoCopy"
		bc.tooltip_text = "Копировать"
		bc.icon = MapBadge.ink_texture("copy")
		bc.tooltip_text = "Взять такую же: тот же облик, цвет фасада и поворот.\nБыстро — наведите на любую постройку и нажмите F"
		bc.pressed.connect(func(): close_panels(); game.copy_building(b))
		h.add_child(bc)
		for x in h.get_children():
			_card_button(x as Button, true)
		info_box.add_child(h)


## Небольшая кнопка карточки: шрифт и значок поменьше, тянется на свою долю ряда
func _small_btn(x: Button) -> void:
	x.add_theme_font_size_override("font_size", 15)
	x.expand_icon = false
	x.add_theme_constant_override("icon_max_width", 24)
	x.add_theme_constant_override("h_separation", 4)
	x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	x.focus_mode = Control.FOCUS_NONE
	for st: Array in [["normal", "g_btn"], ["hover", "g_btn_hover"], ["pressed", "g_btn_on"], ["hover_pressed", "g_btn_on"]]:
		x.add_theme_stylebox_override(st[0], _box_pill(8, 4, st[1]))


## Карточка «Кошачьей лавки» (Д14): кошка в вещице дня (живой портрет), что продаётся, у скольких кошек обновки
func _catshop_rows(b: Dictionary, cw: float) -> void:
	var c: City = game.city
	var order: Array = Defs.CAT_ITEM_ORDER
	var item := String(order[posmod(c.day + int(b["id"]), order.size())])
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	var fur := int(b["id"]) % People.CAT_FURS.size()
	hb.add_child(PersonCard.portrait(self, "shop:%d:%s" % [int(b["id"]), item], func(vp: SubViewport): PersonCard.shop_cat_subject(vp, fur, item)))
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(_label("Сегодня на витрине", 14, true, C_SOFT))
	tv.add_child(_wrap(_label(String(Defs.CAT_ITEMS[item]["name"]), 20, false, C_INK, font_title), cw - 130.0))
	var recs: Array = c.cat_recs()
	var dressed := 0
	var near := 0
	var homes: Dictionary = {}
	for h in b.get("serves", []):
		homes[int(h)] = true
	for rec: Dictionary in recs:
		if not (rec.get("it", []) as Array).is_empty():
			dressed += 1
		if homes.has(int(rec.get("home", -1))):
			near += 1
	tv.add_child(_wrap(_label("Кошек с обновками в городе: %d из %d" % [dressed, recs.size()], 14, false, C_SOFT), cw - 130.0))
	tv.add_child(_wrap(_label("Кошек в домах рядом: %d" % near, 14, false, C_SOFT), cw - 130.0))
	hb.add_child(tv)
	info_box.add_child(hb)
	info_box.add_child(_label("В продаже", 15, true, C_SOFT))
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 10)
	fl.add_theme_constant_override("v_separation", 2)
	for x in order:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 3)
		var dot := TextureRect.new()
		dot.texture = PersonCard._dot(String(x))
		dot.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_child(dot)
		r.add_child(_label(String(Defs.CAT_ITEMS[x]["name"]), 13, false, C_INK))
		fl.add_child(r)
	info_box.add_child(fl)
	info_box.add_child(_wrap(_label("Выбрать кошке вещь самим: щёлкните по кошке на улице.", 13, true, C_SOFT), cw))


## Карточка здания Легиона (Д10): уровень, что даёт сейчас и на следующем уровне, «Улучшить — N ден., M Славы, время»,
## полоска идущего улучшения (идёт и когда игра закрыта); «Окно «Легион»» — отряд, походы и умения
func _legion_rows(_b: Dictionary, _tv: VBoxContainer, cw: float) -> void:
	info_box.add_child(_wrap(_label("Военные постройки — только в форте", 14, false, C_SOFT), cw))


func _lg_tick() -> void:
	_lg_live.clear()


## Лавке нужен склад (3.9): «Товар со склада · 40 м» или «Нет склада рядом — товар не идёт» и «Показать склад»
func _store_row(b: Dictionary) -> void:
	var c: City = game.city
	var st: Dictionary = c.store_for(b)
	if not st.is_empty() and bool(st["ok"]):
		info_box.add_child(_card_row("warehouse", "Товар со склада", "%d м" % roundi(float(st["d"])), C_GOOD))
	elif not st.is_empty() and bool(st["near"]):
		info_box.add_child(_wrap(_label("Склад рядом не работает: %s — товар не идёт" % c.idle_text(st["b"]), 15, true, C_BAD), INFO_BODY))
	else:
		info_box.add_child(_wrap(_label("Нет склада рядом — товар не идёт", 15, true, C_BAD), INFO_BODY))
	if st.is_empty():
		info_box.tooltip_text = "Постройте склад рядом (раздел «Хозяйство»): со склада разносят товар по лавкам."
		return
	var w: Dictionary = st["b"]
	var sb := Button.new()
	sb.text = "Показать склад" + ("" if bool(st["near"]) else " (%d м — далеко)" % roundi(float(st["d"])))
	sb.icon = ico("warehouse", 32)
	sb.focus_mode = Control.FOCUS_NONE
	sb.name = "show_store"
	sb.pressed.connect(func():
		if not c.buildings.has(int(w["id"])):
			return
		game.select_building(w)
		game.rig.fly_to(Vector3((w["pos"] as Vector2).x, float(w["y"]), (w["pos"] as Vector2).y))
		open_info(w))
	info_box.add_child(sb)


## Строки карточки об охвате (те же числа, что подсветка домов, Cover.selected_sets): head — сколько своих домов
## (лавок у склада); ниже — сколько из них получают то же и от другой такой же постройки (синие)
func _cover_rows(b: Dictionary, head: String) -> void:
	var c: City = game.city
	var s := Cover.selected_sets(c, b)
	var kind: String = c.def(b)["kind"]
	if head != "":
		var n: int = (s["green"] as Array).size() if kind == "decor" else int(s["own"])
		info_box.add_child(_card_row("commerce" if kind == "store" else "housing", head, str(n), C_GOOD if n > 0 else C_SOFT))
	var k: int = s["dup"]
	var t: String = {"shop": "Из них уже с такой же лавкой", "monument": "Из них радует и другой такой же",
		"store": "Из них уже с другим складом", "decor": "Украшений уже хватает"}.get(kind, "")
	var blue := Color("2f63a8")
	info_box.add_child(_card_row("housing" if kind != "store" else "commerce", t, str(k), blue if k > 0 else C_SOFT))
	if k > 0:
		var why := "Синим домам украшений уже хватает — больше не прибавится." if kind == "decor" \
			else "Синие получают то же от другой такой же постройки — им эта ничего не добавляет. Зелёные — только от этой."
		info_box.tooltip_text = why
	var hf: int = s.get("half", 0)
	if hf > 0:
		# +1% за каждые 2 очка: очко этого украшения ждёт следующего рядом
		info_box.add_child(_wrap(_label("Ещё %d %s прибавит вместе со следующим украшением рядом." % [hf, _plural(hf, "дому", "домам", "домам")], 14, false, C_SOFT), INFO_BODY))


## Карточка станции: игры в честь богов (с уровня «Посёлок») — идут ли, когда снова и кнопка «Устроить игры — N ден.»
func _fest_rows(v: Control) -> void:
	var c: City = game.city
	if not c.fest_open():
		return
	var F: Dictionary = Defs.FESTIVAL
	v.add_child(_divider(14))
	if c.fest_left > 0:
		v.add_child(_row("laurels", "Игры в честь богов", "идут, ещё %d ч" % c.fest_left, C_GOOD))
		v.add_child(_wrap(_label("Весь город празднует: счастье всех домов +%d%%, повозка с семьями ходит чаще." % int(F["happy"]), 14, false, C_GOOD), 330))
		return
	var why := c.can_festival()
	var st := "можно устроить"
	if c.fest_cd > 0:
		st = "через %d ч" % c.fest_cd
	elif why != "":
		st = "мало денариев" if why.begins_with("Не хватает") else ""
	v.add_child(_row("laurels", "Игры в честь богов", st, C_GOOD if why == "" else (C_BAD if why.begins_with("Не хватает") else C_SOFT)))
	var fb := Button.new()
	fb.name = "fest_btn"
	fb.set_meta("quest_action", "festival")
	fb.text = "Устроить игры — %s ден." % fmt(c.fest_price())
	fb.icon = ico("laurels", 32)
	fb.focus_mode = Control.FOCUS_NONE
	fb.disabled = why != ""
	fb.tooltip_text = why if why != "" else "Устроить игры в честь богов"
	fb.pressed.connect(press_festival)
	v.add_child(fb)
	var txt := "На сутки: счастье всех домов +%d%%, повозка ходит чаще. Цена зависит от налогов: %s." % [int(F["happy"]), fest_rates()]
	v.add_child(_wrap(_label(why if why != "" else txt, 14, why != "", C_BAD if why.begins_with("Не хватает") else C_SOFT), 330))


## Почём игры с жителя каждого класса (City.fest_price): «по 3 ден. за плебея, 5,5 — за ремесленника, 11,3 — за патриция»
func fest_rates() -> String:
	var c: City = game.city
	var who := {"plebs": "плебея", "artisans": "ремесленника", "patricians": "патриция"}
	var out := []
	for cl in who:
		var tax := float(Defs.CLASSES[cl]["tax"]) * (1.25 if cl == "patricians" and c.research.has("taxes1") else 1.0)
		var x := roundf(tax * float(Defs.FESTIVAL["tax_k"]) * 10.0) / 10.0
		var v := (str(roundi(x)) if is_equal_approx(x, roundf(x)) else String.num(x, 1)).replace(".", ",")
		out.append(("по %s ден. за %s" if out.is_empty() else "%s — за %s") % [v, who[cl]])
	return ", ".join(out)


## «Устроить игры» в карточке станции: платим, город празднует (звук — только монетки)
func press_festival() -> void:
	if game.city.festival():
		game.sound.ui("coins")
	refresh()


## Карточка дома (как в Town to City): счастье крупно и что оно даёт; слева — что нужно классу и какая лавка
## закрывает каждую нужду, жильцы; справа — из чего складывается счастье (b["happy_parts"] из City.compute);
## внизу — кнопка «Надстроить этаж» (City.can_buy_floor / buy_floor / floor_price).
## Тело карточки — в прокрутке не выше места над нижней полосой: высокая карточка (патриции, много семей)
## не закрывает казну внизу и не уходит за край экрана; шапка и кнопки «Снести / Перенести» видны всегда
func _fill_house(b: Dictionary, d: Dictionary, tv: VBoxContainer, cw: float) -> void:
	var outer := info_box
	var body := VBoxContainer.new()
	body.name = "HouseBody"
	body.add_theme_constant_override("separation", 6)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sc := ScrollContainer.new()
	sc.name = "house_scroll"
	_olive_scroll(sc)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.follow_focus = false
	sc.add_child(body)
	outer.add_child(sc)
	# Полоса прокрутки помещается внутри тех же 340 точек вместе с рамкой.
	# Полоса зарезервирована сразу: её видимость не меняет минимум строки.
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	var scroll_width := ceilf(sc.get_v_scroll_bar().get_combined_minimum_size().x)
	# и поля самой прокрутки (её рамка): без них карточка выходила на 344 вместо 340 (проба 17.11)
	var sc_box: StyleBox = sc.get_theme_stylebox("panel")
	var sc_pad := ceilf(sc_box.get_minimum_size().x) if sc_box != null else 0.0
	sc_pad += float(sc.get_theme_constant("scrollbar_v_separation"))   # зазор между текстом и полосой (по умолчанию 4)
	var body_width := maxf(1.0, cw - scroll_width - sc_pad)
	body.custom_minimum_size = Vector2(body_width, 0)
	info_box = body
	_fill_house_body(b, d, tv, body_width)
	info_box = outer
	_fit_house_scroll(sc, body)
	_fit_house_scroll_later(sc, body, int(b["id"]))


## Высота прокрутки карточки дома: по содержимому, но не ниже верха нижней полосы (казна, Копия/Перенос/Снос)
func _fit_house_scroll(sc: ScrollContainer, body: Control) -> void:
	if not is_instance_valid(sc) or not is_instance_valid(body):
		return
	var want := body.get_combined_minimum_size().y
	sc.custom_minimum_size.y = 0.0
	var outside := info_panel.get_combined_minimum_size().y      # шапка, кнопки и поля окна
	var room := get_viewport().get_visible_rect().size.y - 62.0 - BAR_H - 10.0 - outside
	sc.custom_minimum_size.y = minf(want, maxf(160.0, room))


## Через кадр (перенос строк уже посчитан) — ещё раз по настоящей высоте; карточку пересобирают каждый
## игровой час — прокрутка остаётся там, где её оставил игрок
func _fit_house_scroll_later(sc: ScrollContainer, body: Control, id: int) -> void:
	await get_tree().process_frame
	if not is_instance_valid(sc):
		return
	_fit_house_scroll(sc, body)
	_snug(info_panel)
	var hs: Array = info_panel.get_meta("house_scroll", [-1, 0])
	for k in 2:
		if int(hs[0]) == id:
			sc.scroll_vertical = int(hs[1])
		if k == 0:
			await get_tree().process_frame
			if not is_instance_valid(sc):
				return
	sc.get_v_scroll_bar().value_changed.connect(func(v: float):
		if is_instance_valid(info_panel):
			info_panel.set_meta("house_scroll", [id, int(v)]))
	if int(hs[0]) != id:
		info_panel.set_meta("house_scroll", [id, 0])


func _fill_house_body(b: Dictionary, d: Dictionary, tv: VBoxContainer, cw: float) -> void:
	var c: City = game.city
	var cl := String(d["cls"])
	var tier := int(b["tier"])
	var fmax := Defs.floors_max(cl, int(b.get("variant", 0)))
	var subtitle := _label(String(Defs.CLASSES[cl]["name"]), 12, true, CARD_ACCENT)
	subtitle.tooltip_text = "%s · этаж %d из %d · цвет «%s»" % [Defs.CLASSES[cl]["name"], tier, fmax, Defs.PALETTE[int(b["color"])]["name"]]
	var occupancy := HBoxContainer.new()
	occupancy.add_theme_constant_override("separation", 5)
	occupancy.add_child(subtitle)
	occupancy.add_child(_card_icon("person", 24))
	var residents := _label("%d/%d" % [int(b["pop"]), c.house_cap(b)], 12, true, CARD_ACCENT)
	residents.name = "HouseOccupancy"
	residents.tooltip_text = "жителей / мест"
	residents.mouse_filter = Control.MOUSE_FILTER_PASS
	occupancy.add_child(residents)
	tv.add_child(occupancy)
	var hp := int(b["happy"])
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 5)
	top.add_child(_card_icon("happy", 26))
	var happy := _label("Счастье %d%%" % hp, 16, true, CARD_ACCENT)
	happy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(happy)
	var inc := int(b["pop"]) * c.house_tax(b) * (0.5 + minf(100.0, float(hp)) / 100.0)
	top.add_child(_card_icon("income", 24))
	top.add_child(_label("+%s/ч" % fmt(inc), 13, true, CARD_ACCENT))
	info_box.add_child(top)
	info_box.add_child(_need_strip(b.get("need_coverage", {}), Defs.needs_for(cl, c.level), cw, cl))
	_fill_house_short(b, d, cw, hp)
	if house_more:
		info_box.add_child(_label("Из чего счастье", 14, true, CARD_ACCENT))
		var parts: Array = b.get("happy_parts", [])
		if parts.is_empty():
			parts = _happy_parts_old(b, cl)
		for part: Array in parts:
			info_box.add_child(_card_row("happy", String(part[0]), _pct(int(part[1]))))


## Один отказ для карточки семьи и списка у станции.
func _refuse_button(family_name: String) -> Button:
	var button := Button.new()
	button.text = "Отказать"
	button.tooltip_text = "Семья уедет. Новую привезут позже."
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func():
		if game.city.refuse_family(family_name):
			if game.tool == "settle" and String(game.settle_fam.get("name", "")) == family_name:
				game.set_tool("")
			if info_panel.visible:
				_fill_info())
	return button


func _post_arrivals(box: VBoxContainer) -> void:
	var c: City = game.city
	var pause := CheckButton.new()
	pause.name = "ArrivalsPause"
	pause.text = "Пауза: новые семьи не едут"
	pause.set_pressed_no_signal(c.arrivals_paused)
	pause.toggled.connect(func(on: bool): c.set_arrivals_paused(on))
	box.add_child(pause)
	for f: Dictionary in c.arrivals:
		var row := HBoxContainer.new()
		var pick := Button.new()
		pick.text = "Семья %s · %d чел." % [f["name"], int(f["n"])]
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nm := String(f["name"])
		pick.pressed.connect(func(): game.start_settle(nm))
		row.add_child(pick)
		row.add_child(_refuse_button(nm))
		box.add_child(row)


## Короткая карточка дома: счастье, нужды, жильцы и свободные этажи.
func _fill_house_short(b: Dictionary, d: Dictionary, cw: float, hp: int) -> void:
	var c: City = game.city
	var cl: String = d["cls"]
	var cls: Dictionary = Defs.CLASSES[cl]
	if hp < 25 and int(b["pop"]) > 0:
		info_box.add_child(_wrap(_label("Ниже 25% двое суток — одна семья переедет.", 14, true, C_BAD), cw))
	var needs := VBoxContainer.new()
	needs.add_theme_constant_override("separation", 3)
	info_box.add_child(needs)
	_need_rows(b, cls, needs, cw)
	_house_shortfalls(b, cw, hp)
	_family_rows(b, info_box, cw, house_more)          # «Подробнее» — ещё и члены семьи по именам
	if c.upgrade_to(b) != "" and c.research.has("artisans"):
		_upgrade_rows(b, cw)
	var tier := int(b["tier"])
	var fmax := Defs.floors_max(cl, int(b.get("variant", 0)))
	if tier < fmax and c.has_method("can_buy_floor"):
		var price := int(c.call("floor_price", b))
		var why := String(c.call("can_buy_floor", b))
		var fb := Button.new()
		fb.focus_mode = Control.FOCUS_NONE
		fb.name = "InfoFloor"
		fb.text = "Надстроить этаж · %s" % fmt(price)
		fb.icon = CityStyle.icon("level")
		fb.expand_icon = false
		fb.custom_minimum_size = Vector2(0, 30)
		fb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_card_button(fb, false, true)
		fb.add_theme_font_size_override("font_size", 14)
		fb.add_theme_font_override("font", font_bold)
		fb.disabled = why != ""
		fb.tooltip_text = why if why != "" else "Надстроить этаж: место ещё для 1 семьи"
		fb.pressed.connect(func():
			if c.call("buy_floor", b):
				if game.sound:
					game.sound.ui("coins")
				_fill_info())
		info_box.add_child(fb)
		info_box.add_child(_wrap(_label("Несколько домов — инструментом «Этаж» (U).", 12, false, CARD_ACCENT), cw))
	info_box.add_child(_more_btn(not house_more))


## «Подробнее» / «Короче»: короткая или подробная карточка дома (запоминается до выхода из игры)
func _more_btn(to_more: bool) -> Button:
	var mb := Button.new()
	mb.focus_mode = Control.FOCUS_NONE
	mb.flat = false
	mb.clip_text = true
	mb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mb.text = "Подробнее: из чего счастье, жильцы ▾" if to_more else "Короче ▴"
	mb.add_theme_font_size_override("font_size", 14)
	mb.add_theme_color_override("font_color", C_SOFT)
	mb.add_theme_color_override("font_hover_color", C_INK)
	mb.size_flags_horizontal = Control.SIZE_FILL
	mb.tooltip_text = mb.text
	mb.text = ""
	mb.icon = CityStyle.icon("info")
	_card_button(mb, true)
	mb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	mb.pressed.connect(func():
		house_more = to_more
		_fill_info())
	return mb


## Цвет и число видны вместе: состояние можно прочесть и без цвета.
func _need_color(pct: int) -> Color:
	return C_BAD if pct < 34 else (Color("93620f") if pct < 67 else C_GOOD)


func _need_strip(coverage: Dictionary, required: Array, width: float, cl := "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "NeedStrip"
	row.add_theme_constant_override("separation", 4)
	for n: String in Defs.NEED_ORDER:
		var needed := n in required
		var pct := HouseNeeds.percent(coverage.get(n, 0))
		var col := CARD_ACCENT
		var v := VBoxContainer.new()
		v.modulate.a = 1.0 if needed else 0.35
		v.name = "need_" + n
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.custom_minimum_size.x = floorf(clampf((width - 20.0) / 6.0, 1.0, 256.0)) if is_finite(width) else 1.0
		v.add_theme_constant_override("separation", 1)
		v.mouse_filter = Control.MOUSE_FILTER_PASS
		v.tooltip_text = ("%s: покрытие %d%%" % [Defs.NEEDS[n]["name"], pct]) if needed else _need_later(cl, n)
		v.set_meta("coverage", pct)
		v.set_meta("state", HouseNeeds.state(pct) if needed else "disabled")
		var ic := _icon(Defs.NEEDS[n]["icon"], 24)
		ic.texture = MapBadge.ink_texture(Defs.NEEDS[n]["icon"])
		ic.modulate = col
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var value := _label("%d%%" % pct if needed else "—", 14, true, col)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(value)
		row.add_child(v)
	return row


## Все семьи, включая большие домусы; головы ведут к прежним карточкам жителей.
func _family_rows(b: Dictionary, box: VBoxContainer, width: float, details: bool) -> void:
	var c: City = game.city
	var families: Array = b.get("families", [])
	box.add_child(_divider(8))
	box.add_child(_label("Семьи · %d из %d этажей%s" % [families.size(), c.house_floors(b), " — тесновато" if families.size() > c.house_floors(b) else ""], 15, true, C_SOFT))
	box.tooltip_text = c.house_room_text(b)
	box.add_child(_label(c.house_room_text(b), 12, true, CARD_ACCENT))
	if families.is_empty():
		box.add_child(_wrap(_label("Пока пусто: семья приедет на повозке — заселите её значком слева вверху", 13, false, C_SOFT), width))
	for i in families.size():
		var f: Dictionary = families[i]
		var family := VBoxContainer.new()
		family.name = "family_%d" % i
		family.add_theme_constant_override("separation", 2)
		var title := HBoxContainer.new()
		var name_label := _label(String(f["name"]), 13, true, CARD_ACCENT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		name_label.mouse_filter = Control.MOUSE_FILTER_PASS
		name_label.tooltip_text = name_label.text
		title.add_child(name_label)
		var pref: Array = FamilyPreference.look(f)
		var preference := _icon(String(pref[0]), 27)
		preference.name = "Preference"
		preference.texture = MapBadge.want_texture(String(f.get("want", pref[0])))
		preference.modulate = Color.WHITE if FamilyPreference.matches(c, b, f) else Color(1, 1, 1, 0.5)
		preference.mouse_filter = Control.MOUSE_FILTER_PASS
		preference.tooltip_text = FamilyPreference.tooltip(c, b, f)
		# старые семьи без желания (до CITY5a) — значка нет: прежняя «черта» показывала кошку (владелец: кошки — странное желание)
		preference.visible = String(f.get("want", "")) != ""
		family.add_child(title)
		var heads := HFlowContainer.new()
		heads.name = "Members"
		heads.add_theme_constant_override("h_separation", 3)
		var members := Residents.fit(f, hash([String(f["name"]), int(b["id"])]), String(c.def(b)["cls"]))
		var adults := 0
		for m: Dictionary in members:
			if int(m.get("age", 0)) > 0:
				adults += 1
		heads.custom_minimum_size.x = minf(width * 0.6, members.size() * 22 + (adults * 22 if Defs.PROF_ON else 0))
		for m: Dictionary in members:
			var child := int(m.get("age", 1)) == 0
			var head := Button.new()
			head.flat = true
			head.custom_minimum_size = Vector2(24, 26)
			head.icon = MapBadge.ink_texture("head_child" if child else "head_adult")
			head.expand_icon = true
			head.add_theme_constant_override("icon_max_width", 18 if child else 22)
			head.add_theme_color_override("icon_normal_color", CARD_ACCENT)
			for state in ["normal", "hover", "pressed", "focus"]:
				head.add_theme_stylebox_override(state, StyleBoxEmpty.new())
			head.tooltip_text = "%s · %s" % [m.get("pn", "?"), Residents.role(m, members)]
			head.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var live: Dictionary = {}
			if game.people != null:
				for resident: Dictionary in game.people.residents:
					if int(resident["home"]) == int(b["id"]) and resident.get("m", {}) == m:
						live = resident
						break
			if not live.is_empty():
				head.pressed.connect(func(): game.select_person({"r": live}))
			var person := HBoxContainer.new()
			person.add_theme_constant_override("separation", 1)
			person.add_child(head)
			if Defs.PROF_ON and not child:
				var badge := _profession_icon(String(m.get("prof", "")), 20)
				badge.set_meta("profession_role", "family")
				person.add_child(badge)
			heads.add_child(person)
		title.add_child(heads)
		title.add_child(preference)
		family.tooltip_text = FamilyPreference.tooltip(c, b, f)
		if details:
			# «Подробнее»: члены семьи по именам — щелчок открывает карточку жителя (было до компактных карточек)
			var chips := PersonCard.family_chips(self, b, f, width)
			if chips:
				family.add_child(chips)
		box.add_child(family)


## Источники нужного классу вида: картинка и действующий бонус к счастью.
func _need_rows(b: Dictionary, cls: Dictionary, left: VBoxContainer, lw: float) -> void:
	var c: City = game.city
	var cl := String(c.def(b)["cls"])
	for n: String in Defs.NEED_ORDER:
		if n not in cls["needs"]:
			continue
		var needed := n in Defs.needs_for(cl, c.level)
		if not needed or (b.get("need_sources", {}).get(n, []) as Array).is_empty():
			continue
		var category := VBoxContainer.new()
		category.name = "sources_" + n
		category.modulate.a = 1.0 if needed else 0.35
		category.tooltip_text = String(Defs.NEEDS[n]["name"]) + ": " + (_need_hint(b, n) if needed else _need_later(cl, n))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		row.add_child(_card_icon(Defs.NEEDS[n]["icon"], 26))
		category.add_child(row)
		var sources: Array = b.get("need_sources", {}).get(n, []) if needed else []
		if sources.is_empty():
			row.add_child(_label("0%" if needed else "—", 12, true, CARD_ACCENT))
		else:
			var pictures := HFlowContainer.new()
			# Значок 26 и промежуток 5 тоже входят в ширину строки.
			pictures.custom_minimum_size.x = maxf(1.0, lw - 31.0)
			pictures.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pictures.add_theme_constant_override("h_separation", 8)
			pictures.add_theme_constant_override("v_separation", 2)
			row.add_child(pictures)
			for source: Dictionary in sources:
				var type := String(source["type"])
				var tile := HBoxContainer.new()
				tile.add_theme_constant_override("separation", 2)
				var image := TextureRect.new()
				image.name = "SourcePicture"
				image.set_meta("building_type", type)
				image.custom_minimum_size = Vector2(28, 28)
				image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				var source_icon := String(Defs.B[type].get("icon", "housing"))
				image.set_meta("city_icon", source_icon)
				image.texture = CityStyle.icon(source_icon)
				image.modulate = CityStyle.OLIVE
				tile.add_child(image)
				tile.add_child(_label("+%d%%" % int(source["bonus"]), 12, true, CARD_ACCENT))
				var sid := int(source["id"])
				pictures.add_child(_clickable(tile, "%s · покрытие %d%% · счастье +%d%%" % [Defs.B[type]["name"], int(source["coverage"]), int(source["bonus"])], func():
					var provider: Dictionary = c.buildings.get(sid, {})
					if not provider.is_empty():
						game.select_building(provider)
						open_info(provider)))
		left.add_child(category)


## Ближайший существующий вид; если вокруг пусто — доступный и недорогой.
func _need_building(b: Dictionary, need: String) -> String:
	var c: City = game.city
	var nearest := ""
	var distance := INF
	for source: Dictionary in c.buildings.values():
		var d := c.def(source)
		if HouseNeeds.category(d) != need or not c.unlocked(String(source["type"])):
			continue
		var ds: float = (source["pos"] as Vector2).distance_squared_to(b["pos"])
		if ds < distance:
			distance = ds
			nearest = String(source["type"])
	if nearest != "":
		return nearest
	var cheapest := INF
	var available := false
	for type: String in Defs.B:
		var d: Dictionary = Defs.B[type]
		if HouseNeeds.category(d) != need or bool(d.get("hidden", false)):
			continue
		var open := c.unlocked(type)
		if (open and not available) or (open == available and float(d["cost"]) < cheapest):
			available = open
			cheapest = float(d["cost"])
			nearest = type
	return nearest


func _loss_icon(label: String) -> String:
	if label.begins_with("Нет лавки:"):
		for n: String in Defs.NEED_ORDER:
			if label.ends_with(String(Defs.NEEDS[n]["name"]).to_lower()):
				return String(Defs.NEEDS[n]["icon"])
	if label == "Нет рядом: вера":
		return "faith"
	if label.begins_with("Налоги") or label == "Жалованье не плачено":
		return "coins"
	if label == "Теснота":
		return "housing"
	if label == "Большой город":
		return "person"
	return "happy"


## Короткие действия видны сразу, подробный расчёт остаётся под «Подробнее».
func _house_shortfalls(b: Dictionary, width: float, hp: int) -> void:
	var c: City = game.city
	var missing := VBoxContainer.new()
	missing.name = "HouseMissing"
	missing.add_theme_constant_override("separation", 5)
	for need: String in Defs.needs_for(String(c.def(b)["cls"]), c.level):
		var coverage := int(b.get("need_coverage", {}).get(need, 0))
		if coverage >= 100:
			continue
		var row := HBoxContainer.new()
		row.name = "Missing_" + need
		row.add_theme_constant_override("separation", 5)
		row.add_child(_card_icon(String(Defs.NEEDS[need]["icon"]), 26))
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 1)
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_child(_label(I18n.t(String(Defs.NEEDS[need]["name"])) + " · %d%%" % coverage, 12, true, CARD_ACCENT))
		var type := _need_building(b, need)
		var action := HBoxContainer.new()
		action.add_theme_constant_override("separation", 4)
		var caption := "Откройте лавку в исследованиях"
		if type != "":
			var picture := _card_icon(String(Defs.B[type].get("icon", "housing")), 26)
			picture.name = "SuggestedBuilding"
			picture.set_meta("building_type", type)
			action.add_child(picture)
			caption = I18n.t("%s — поставьте рядом") % I18n.t(String(Defs.B[type]["name"]))
		var instruction := _wrap(_label(caption, 12, false, CARD_ACCENT), maxf(1.0, width - 61.0))
		instruction.name = "MissingAction"
		action.add_child(instruction)
		body.add_child(action)
		row.add_child(body)
		if type != "":
			var kind := "build" if c.unlocked(type) else "locked"
			missing.add_child(_clickable(row, _need_hint(b, need), func(): _do_click({"kind": kind, "type": type})))
		else:
			missing.add_child(row)
	if missing.get_child_count() > 0:
		missing.add_child(_label("Чего не хватает", 14, true, CARD_ACCENT))
		missing.move_child(missing.get_child(missing.get_child_count() - 1), 0)
		info_box.add_child(missing)
	else:
		missing.queue_free()
	if hp >= 60 and int(b.get("happy_target", hp)) >= 60:
		return
	var losses: Array = (b.get("happy_parts", []) as Array).filter(func(part: Array) -> bool:
		return int(part[1]) < 0 and String(part[0]) != "Больше 100% не бывает")
	losses.sort_custom(func(a: Array, other: Array) -> bool: return int(a[1]) < int(other[1]))
	if losses.is_empty():
		return
	var worst := VBoxContainer.new()
	worst.name = "HouseLosses"
	worst.add_theme_constant_override("separation", 3)
	worst.add_child(_label("Снижает счастье", 14, true, CARD_ACCENT))
	for part: Array in losses.slice(0, 2):
		worst.add_child(_card_row(_loss_icon(String(part[0])), String(part[0]), _pct(int(part[1])), C_BAD))
	info_box.add_child(worst)


func _need_later(cl: String, n: String) -> String:
	if cl == "":
		for candidate: String in Defs.CLASS_ORDER:
			if n in Defs.CLASSES[candidate]["needs"] and game.city.level < Defs.need_rank(candidate, n):
				return "с уровня «%s»" % Defs.LEVELS[Defs.need_rank(candidate, n)]["name"]
	if cl != "" and n in Defs.CLASSES[cl]["needs"]:
		var rank := Defs.need_rank(cl, n)
		if game.city.level < rank:
			return "с уровня «%s»" % Defs.LEVELS[rank]["name"]
	return "Не нужно этому классу"


func _need_hint(b: Dictionary, n: String) -> String:
	var c: City = game.city
	for source: Dictionary in c.buildings.values():
		var d := c.def(source)
		if HouseNeeds.category(d) != n:
			continue
		var reach := c.shop_range(d) if d["kind"] == "shop" else c.need_range(d)
		if (source["pos"] as Vector2).distance_to(b["pos"]) <= reach:
			if not bool(source.get("active", true)):
				return "«%s» рядом не работает: %s" % [d["name"], c.idle_text(source)]
			return "«%s» рядом не успевает ко всем (−%d%%)" % [d["name"], c.missing_penalty()]
	if n == "faith":
		return "Нет рядом: храм или алтарь (−%d%%)" % c.missing_penalty()
	for type: String in Defs.B:
		if Defs.B[type]["kind"] == "shop" and HouseNeeds.category(Defs.B[type]) == n and c.unlocked(type):
			return "Нет рядом (−%d%%) — поставьте «%s»" % [c.missing_penalty(), Defs.B[type]["name"]]
	return "Нет рядом (−%d%%) — лавку откроют исследования" % c.missing_penalty()


## Карточка дома: «Перестроить» (Д12) — во что, галочки условий (класс изучен, нужды нового класса, счастье после
## перестройки с запасом, место позади дома) и кнопка с ценой; много домов сразу — инструментом (Shift+U)
func _upgrade_rows(b: Dictionary, cw: float) -> void:
	var c: City = game.city
	var nt := c.upgrade_to(b)
	if nt == "":
		return
	var nd: Dictionary = Defs.B[nt]
	var cl1 := String(nd["cls"])
	var title := "Перестроить в дом ремесленников" if nt == "house_artisan" else "Перестроить в городской домус"
	if house_more:
		info_box.add_child(_label(title, 13, true, CARD_ACCENT))
	var rows := []
	var res_ok := c.unlocked(nt)
	rows.append([res_ok, "Изучен «%s»" % Defs.research(String(nd.get("unlock", "")))["name"]])
	var hp := c.upgrade_happy(b)
	rows.append([true, "Счастье после перестройки: %d%%" % clampi(hp, 0, 100)])
	# место позади — когда класс изучен (до того check_place клетки не смотрит); текст — тот же, что у кнопки
	var room := ""
	if res_ok:
		room = c.upgrade_room(b)
		rows.append([room == "", "За домом есть место" if room == "" else room])
	for e: Array in rows if house_more else []:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		var mk := _card_icon("check" if e[0] else "close", 18)
		mk.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		r.add_child(mk)
		r.add_child(_wrap(_label(String(e[1]), 14, false, C_INK if e[0] else C_BAD), cw - 30.0))
		info_box.add_child(r)
	# мешают только украшения — снести их за возврат, как в Town to City (план 6.6)
	var dec: Array = c.upgrade_decor_blockers(b) if res_ok and room != "" else []
	if not dec.is_empty():
		var nms := []
		var back := 0.0
		for id in dec:
			var o: Dictionary = c.buildings[id]
			if not nms.has(String(c.def(o)["name"])):
				nms.append(String(c.def(o)["name"]))
			back += c.refund_price(o)
		var db := Button.new()
		db.focus_mode = Control.FOCUS_NONE
		db.text = "Снести мешающее: %s (вернётся %s ден.)" % [", ".join(nms.map(func(x): return "«%s»" % x)), fmt(int(back))]
		db.icon = ico("demolish", 28)
		db.expand_icon = false
		db.custom_minimum_size = Vector2(cw, 40)
		db.clip_text = true
		db.tooltip_text = "Украшения за домом уберут, половина их цены вернётся в казну — дому хватит места"
		db.pressed.connect(func():
			for id in dec:
				if c.buildings.has(id):
					c.remove(c.buildings[id])
			_fill_info())
		info_box.add_child(db)
	var ntier := c.upgrade_tier(b)
	var cap := ntier
	if (b["families"] as Array).size() > cap:
		var more := "надстройте этаж." if ntier < Defs.floors_max(cl1, c.upgrade_variant(b)) else "выше этот дом не строят, новые семьи туда не въедут."
		info_box.add_child(_wrap(_label("После перестройки этажей будет %d, а семей %d — тесновато, но никто не уедет; %s" % [cap, (b["families"] as Array).size(), more], 13, false, C_SOFT), cw))
	var price := c.upgrade_price(b)
	var why := c.can_upgrade(b)
	var ub := Button.new()
	ub.focus_mode = Control.FOCUS_NONE
	ub.name = "InfoUpgrade"
	ub.text = "Перестроить · %s" % fmt(price)
	ub.icon = load("res://assets/ui/kitA/icons/upgrade.png")
	ub.expand_icon = false
	ub.custom_minimum_size = Vector2(0, 30)
	ub.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_card_button(ub, false, true)
	ub.add_theme_font_size_override("font_size", 14)
	ub.add_theme_font_override("font", font_bold)
	ub.disabled = why != ""
	ub.tooltip_text = why if why != "" else "Семья останется и станет классом «%s»: налог с дома выше" % String(Defs.CLASSES[cl1]["name"])
	ub.pressed.connect(func():
		if c.upgrade_house(b):
			if game.sound:
				game.sound.ui("coins")
			_fill_info())
	info_box.add_child(ub)
	if why != "" and house_more:
		var wl := _wrap(_label(why, 14, true, C_BAD), cw)
		wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_box.add_child(wl)



## Слагаемые счастья дома по старым полям (если City.compute их ещё не считает)
func _happy_parts_old(b: Dictionary, cl: String) -> Array:
	var out := [["Основа", game.city.base_happy(cl)]]
	for t in b.get("score", {}):
		if not game.city.shop_needed(b, Defs.B[t]):
			continue
		out.append([Defs.B[t]["name"], int(b["score"][t])])
	if int(b.get("deco_bonus", 0)) != 0:
		out.append(["Украшения", int(b["deco_bonus"])])
	if float(b.get("monuments", 0.0)) > 0.0:
		out.append(["Памятники", int(b["monuments"])])
	if float(b.get("density", 0.0)) < 0.0:
		out.append(["Теснота", int(b["density"])])
	for n in b.get("missing", []):
		out.append([("Нет рядом: вера" if n == "faith" else "Нет лавки: " + String(Defs.NEEDS[n]["name"]).to_lower()), -game.city.missing_penalty()])
	return out


## «+5%», «−10%» (настоящий минус)
func _pct(v: int) -> String:
	return ("+%d%%" % v) if v > 0 else (("−%d%%" % -v) if v < 0 else "0%")


## С какого счастья дома можно надстроить следующий этаж
func _floor_need(b: Dictionary) -> int:
	if game.city.has_method("floor_need"):
		return int(game.city.call("floor_need", b))
	return 55 + 12 * (int(b["tier"]) - 1)


var _defs_map := {}


## Число из Defs по имени (если его там нет — запасное), чтобы интерфейс не ломался от переименований
func _defc(name: String, dflt: Variant) -> Variant:
	if _defs_map.is_empty():
		_defs_map = (load("res://scripts/defs.gd") as Script).get_script_constant_map()
	return _defs_map.get(name, dflt)


## Закрыть окна; true — было что закрывать
func close_panels() -> bool:
	var magis := MagisUI.of(self)
	if magis != null and magis.visible:
		if is_instance_valid(magis.popup):
			magis._close_popup()
		else:
			magis.close()
		return true
	if CampUI.close_for(self):
		return true
	if CityName.close(self):
		return true                              # окно «Название города» — поверх всего: закрывается первым, одно
	var any := info_panel.visible or advisor_panel.visible or buy_panel.visible
	for x in [events_panel, research_panel, finance_panel, stats_panel, pause_panel, settings_panel, credits_panel, journal_panel]:
		if x == null:
			continue
		any = any or x.visible
		x.visible = false
	any = LegionUi.close_for(self) or any        # окно «Легион» (scripts/legion_ui.gd)
	info_panel.visible = false
	advisor_panel.visible = false
	buy_panel.visible = false
	if not info_b.is_empty():
		PersonCard.close()
	info_b = {}
	if not info_p.is_empty():
		info_p = {}
		PersonCard.close()
	if game:
		game.select_building({})
	_update_pointer()
	return any


func house_event(b: Dictionary, up: bool) -> void:
	if not info_b.is_empty() and info_b.get("id", -1) == b["id"]:
		_fill_info()


# ---------- советник, всплывашки, события ----------

var adv_show: Button
var _adv_target := {}
var guidance_queue: Array[Dictionary] = []
var _guidance_playing := false


## Общий затвор, в том числе до создания Tutorial при загрузке.
func tutorial_busy() -> bool:
	return game != null and game.city != null and ((game.tutorial != null and game.tutorial.active()) or int(game.city.tips.get("tut", -1)) >= 0)


func guide_style(path := "panels/panel_inset", _rim := 12, pad := 12) -> StyleBoxFlat:
	return CityStyle.panel(40 if path == "panels/slot_round" else 12, pad)


func guide_link(caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_size_override("font_size", 11)
	for state: String in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color("754827"))
	button.add_theme_color_override("font_hover_color", CityStyle.OLIVE)
	button.pressed.connect(action)
	return button


func guide_button(caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(96, 34)
	button.add_theme_font_size_override("font_size", 14)
	CityStyle.button(button)
	button.pressed.connect(action)
	return button


func _queue_guidance(item: Dictionary) -> void:
	for queued: Dictionary in guidance_queue:
		if queued.get("kind") == item.get("kind") and queued.get("title", queued.get("text")) == item.get("title", item.get("text")):
			return
	guidance_queue.append(item)


func _flush_guidance() -> void:
	if tutorial_busy() or not _tip_free() or not _screen_free() or notes_box.get_child_count() > 0:
		return
	if guidance_queue.is_empty():
		# Ждавший совет считает счастье только перед показом.
		if game.city.tips.has("arrive_wait") and String(game.city.stats.get("arrive_block", "")) != "":
			_arrive_advice()
		return
	var item: Dictionary = guidance_queue.pop_front()
	_guidance_playing = true
	if item["kind"] == "advisor":
		advisor(item["title"], item["text"], item.get("skip", Callable()), bool(item.get("force", false)), bool(item.get("corner", false)), item.get("target", {}))
	else:
		_toast(item["text"], item["icon"])
	_guidance_playing = false


## Переводим исходный совет целиком, затем оставляем две короткие фразы.
func _short_advice(body: String) -> String:
	var translated := I18n.t(body).replace("\n", " ")
	var re := RegEx.create_from_string("[^.!?]+[.!?]?")
	var lines := PackedStringArray()
	for found: RegExMatch in re.search_all(translated):
		var line := found.get_string().strip_edges()
		if line == "":
			continue
		if line.length() > 150:
			var cut := line.substr(0, 147)
			var space := cut.rfind(" ")
			line = cut.substr(0, space if space > 80 else 147) + "…"
		lines.append(line)
		if lines.size() == 2:
			break
	return " ".join(lines)


func _advisor() -> void:
	advisor_panel = PanelContainer.new()
	advisor_panel.name = "AdvisorCard"
	advisor_panel.add_theme_stylebox_override("panel", guide_style())
	root.add_child(advisor_panel)
	_put(advisor_panel, Control.PRESET_CENTER_TOP, Vector2(0, ADV_Y))
	advisor_panel.custom_minimum_size = Vector2(512, 0)
	advisor_panel.hide()
	advisor_panel.visibility_changed.connect(func():
		notes_box.visible = not advisor_panel.visible and not tutorial_busy()
		if not advisor_panel.visible:
			_tip_next = Time.get_ticks_msec() + TIP_GAP_MS)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	advisor_panel.add_child(h)
	var medal := PanelContainer.new()
	medal.add_theme_stylebox_override("panel", guide_style("panels/slot_round", 12, 4))
	medal.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(medal)
	adv_face = _pic("advisor.png", Vector2(64, 64))
	medal.add_child(adv_face)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	h.add_child(v)
	adv_title = _label("", 16, true)
	adv_title.clip_text = true
	adv_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(adv_title)
	adv_text = _label("", 14)
	adv_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	adv_text.custom_minimum_size = Vector2(0, 0)
	v.add_child(adv_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	adv_show = guide_button("Показать", func():
		var target := _adv_target.duplicate()
		advisor_panel.hide()
		if not target.is_empty():
			_do_click(target))
	adv_show.name = "AdvisorShow"
	adv_show.hide()
	row.add_child(adv_show)
	adv_ok = guide_button("Понятно", func(): advisor_panel.hide())
	row.add_child(adv_ok)
	adv_skip = guide_link("Пропустить обучение", func():
		advisor_panel.hide()
		if _adv_skip_cb.is_valid():
			_adv_skip_cb.call()
		_update_pointer())
	adv_skip.hide()
	v.add_child(adv_skip)
	adv_never = guide_link("Больше не показывать", func():
		game.settings["advisor_off"] = true
		_store_settings()
		advisor_panel.hide())
	adv_never.tooltip_text = "Советы не будут всплывать. Вернуть — Настройки → «Подсказки советника»"
	adv_never.hide()
	v.add_child(adv_never)


## Советы второго плана — не всплывают окном, а тихо ложатся в колокольчик (отзыв 14.11: слишком много подсказок).
## Остаются окном: обучение, первые жители, «Казна пуста», новый уровень, «Новые семьи не едут», истории горожан
	CityStyle.apply(advisor_panel)


const QUIET_TIPS := ["Игры в честь богов", "Этаж — без карточки дома", "Перестроить дом", "Обновка для кошки", "Казна полна", "Полки полны",
	"На этаж пока не хватает", "Налоги по классам", "Разнообразие радует больше", "Наборы украшений", "Улучшенные улицы", "Главные украшения",
	"Как назовём город?", "Летопись города", "Кому работать", "Семье негде жить", "Зрелища", "Здания Легиона", "Герой в боях с городами",
	"Заборы тянут мышью", "Украшения на стенах", "В городе новые правила", "Кому достанется лавка"]


## Тихие советы работают в настоящей игре (главная сцена main.tscn); автопроверки запускают игру внутри своей сцены и
## по-прежнему видят каждый совет окном (так проверяют их тексты). quiet_tips = 0 / 1 — проверка может задать сама
var quiet_tips := -1


func _quiet_on() -> bool:
	if quiet_tips < 0:
		var cs := get_tree().current_scene
		quiet_tips = 1 if ((cs != null and cs.scene_file_path == "res://main.tscn") or OS.get_cmdline_user_args().has("--quiet")) else 0
	return quiet_tips == 1


## Советы ещё показываются? Настройка «Подсказки советника» (или кнопка «Больше не показывать»)
func advisor_on() -> bool:
	return game == null or not bool(game.settings.get("advisor_off", false))


## Совет: заголовок и текст; skip — совет начинает обучение: рядом с «Понятно» кнопка «Пропустить обучение».
## force — игрок сам попросил (щёлкнул по просьбе): показываем всегда
func advisor(title: String, text: String, skip := Callable(), force := false, corner := false, target: Dictionary = {}) -> void:
	if tutorial_busy() or (not _guidance_playing and (advisor_panel.visible or not guidance_queue.is_empty() or notes_box.get_child_count() > 0)):
		_queue_guidance({"kind": "advisor", "title": title, "text": text, "skip": skip, "force": force, "corner": corner, "target": target})
		return
	if not force and not skip.is_valid() and game != null and game.city != null and game.mode != "demo":
		if _quiet_on() and (not advisor_on() or title in QUIET_TIPS or title.ends_with("— ваш герой")):
			_advisor_quiet(title, text)
			return
	_advisor_layout(corner)
	adv_title.text = title
	adv_text.text = I18n.t(text) if target.has("want_icon") else _short_advice(text)
	adv_text.tooltip_text = ""
	adv_skip.text = "Пропустить обучение"
	adv_ok.text = "Понятно"
	_adv_skip_cb = skip
	adv_skip.visible = skip.is_valid()
	adv_never.visible = not skip.is_valid() and not force and not corner
	_adv_target = target.duplicate()
	if _adv_target.is_empty():
		if title == "Город готов к новому уровню!" or title.begins_with("Город стал"):
			_adv_target = {"kind": "rank"}
		elif title == StoryDefs.ADV_LEGION or title == "Лагерь открыт":
			_adv_target = {"kind": "legion"}
	adv_show.visible = _adv_target.has("kind")
	var want_icon := advisor_panel.find_child("WantAdviceIcon", true, false) as TextureRect
	if want_icon == null:
		want_icon = TextureRect.new()
		want_icon.name = "WantAdviceIcon"
		want_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		want_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		want_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		adv_face.add_child(want_icon)
	want_icon.custom_minimum_size = Vector2(32, 32)
	want_icon.position = Vector2(34, 34)
	want_icon.size = Vector2(32, 32)
	want_icon.visible = target.has("want_icon")
	if want_icon.visible:
		want_icon.texture = MapBadge.want_texture(String(target["want_icon"]))
	advisor_panel.show()
	_refit(advisor_panel)


func _advisor_layout(corner: bool) -> void:
	_put(advisor_panel, Control.PRESET_TOP_RIGHT if corner else Control.PRESET_CENTER_TOP,
		Vector2(-10, TOP_BTN + 16) if corner else Vector2(0, ADV_Y))
	advisor_panel.custom_minimum_size = Vector2(512, 0)
	adv_text.custom_minimum_size = Vector2(0, 0)
	adv_face.custom_minimum_size = Vector2(64, 64)
	advisor_panel.reset_size()


## Совет без окна: одна строка в колокольчике («Заголовок. Первая фраза»)
func _advisor_quiet(title: String, text: String) -> void:
	var c: City = game.city
	var first := I18n.t(text).split("\n")[0]       # переводим весь совет и берём первую фразу: так она точно есть в словаре
	title = I18n.t(title)
	var dot := first.find(". ")
	if dot > 0:
		first = first.substr(0, dot + 1)
	c.events.append({"day": c.day, "text": "%s. %s" % [title, first], "icon": "info", "hn": c.hour_n, "advisor": true, "full_text": title + ". " + I18n.t(text)})
	if c.events.size() > 60:
		c.events.pop_front()
	bell(title, "info", false, true)


func _notes() -> void:
	notes_box = VBoxContainer.new()
	_put(notes_box, Control.PRESET_CENTER_TOP, Vector2(0, NOTES_Y))     # под фишками классов, не на них
	notes_box.custom_minimum_size = Vector2(440, 0)
	notes_box.add_theme_constant_override("separation", 5)
	notes_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(notes_box)


## «Обзор» справа внизу; открыта карточка постройки — встаём левее неё (карточка рисуется поверх и закрыла бы
## режимы и легенду, а легенда сама зовёт щёлкнуть по дому). Сдвиг — через _put: _snug в fill_overlay его сохранит
func _place_overlay() -> void:
	if overlay_panel == null or not overlay_panel.visible:
		return
	var x := -10.0
	if info_panel.visible:
		x = minf(-10.0, info_panel.position.x - root.size.x - 12.0)
		x = maxf(x, overlay_panel.size.x + 10.0 - root.size.x)        # не уезжать за левый край
	var m: Array = overlay_panel.get_meta("put", [Control.PRESET_BOTTOM_RIGHT, Vector2(-10, -BAR_H - 10)])
	if not is_equal_approx((m[1] as Vector2).x, x):
		_put(overlay_panel, Control.PRESET_BOTTOM_RIGHT, Vector2(x, -BAR_H - 10))


## Всплывашки посередине сверху, но не на значках семей слева и не на карточке постройки справа
func _place_notes() -> void:
	if notes_box == null or root == null:
		return
	var w := root.size.x
	var half := maxf(220.0, notes_box.size.x * 0.5)
	var lo := 0.0
	if fam_box.visible and fam_box.get_child_count() > 0:
		lo = fam_box.position.x + fam_box.size.x + 12.0
	var hi := w
	if info_panel.visible:
		hi = info_panel.position.x - 12.0
	var cx := clampf(w * 0.5, lo + half, maxf(lo + half, hi - half))
	var off := roundf(cx - w * 0.5)
	if not is_equal_approx(notes_box.offset_left, off - half) or not is_equal_approx(notes_box.offset_right, off + half):
		notes_box.offset_left = off - half
		notes_box.offset_right = off + half


## Значки событий-ответов на действие игрока («почему нельзя», «сохранено») — это не события города: короткая плашка,
## в колокольчик не пишутся
const FEEDBACK_ICONS := ["lock", "save", "move", "info", "check_tip"]
## Важное, что стоит плашки сверху на 3 секунды (всё остальное — только в колокольчик, отзыв 14.11): новый уровень города,
## пожар, праздник, приехала семья
const TOAST_WORDS := ["пожар", "сегодня ", "игры в честь", "праздник", "приехала семья"]
const TOAST_SEC := 3.0
var _toast_day := {}                       # текст плашки → в какой игровой день уже показывали (одно и то же — раз в сутки)
var _fam_toast_h := -1                     # в какой игровой час показали плашку «приехала семья» (не чаще раза в час)


func _game_day() -> int:
	return int(game.city.day) if game != null and game.city != null else 0


## Событие города или сообщение для игрока. Плашка — только про важное; обычные события — тихо, числом на колокольчике.
## seen — о том, что игрок сделал сам (изучил, надстроил): число на колокольчике не растёт
func notify(text: String, icon := "info", seen := false) -> void:
	if icon in FEEDBACK_ICONS:
		_toast(text, icon)                 # ответ на действие — коротко, без записи в колокольчик
		return
	var rc = game.get("rank_cine") if game else null
	if icon == "level" and rc != null and rc.covers_toast():
		bell(text, icon, false)           # новый ранг покажет ролик — всплывашка не нужна, только колокольчик
		return
	var low := text.to_lower()
	var important := icon == "level" or TOAST_WORDS.any(func(w): return low.begins_with(w) or low.contains(w))
	if important:
		_toast(text, icon)
	bell(text, icon, seen)


## Плашка наверху на TOAST_SEC секунд: одна за раз, одно и то же сообщение — не чаще раза в игровые сутки
func _toast(text: String, icon: String) -> void:
	if tutorial_busy() or (not _guidance_playing and (advisor_panel.visible or not guidance_queue.is_empty() or notes_box.get_child_count() > 0)):
		_queue_guidance({"kind": "toast", "text": text, "icon": icon})
		return
	var day := _game_day()
	if int(_toast_day.get(text, -1)) == day:
		return
	_toast_day[text] = day
	var p := _chip(false, 12.0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(_icon(icon, 26, C_SOFT))
	var l := _label(text, 15, true)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(360, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	p.add_child(h)
	notes_box.add_child(p)
	while notes_box.get_child_count() > 1:
		var o := notes_box.get_child(0)
		notes_box.remove_child(o)
		o.queue_free()
	p.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(TOAST_SEC - 0.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)


## В гостях у другого игрока (Game.visiting, SocialNet): сверху плашка «Вы в гостях у «…»» — кто, сколько жителей,
## «Нравится» (раз в сутки), «Домой»; стройки и задач внизу нет — город только посмотреть
func visit_banner(v: Dictionary) -> void:
	for n in [bar_left, bar_mid, bar_right, road_panel, tray, tasks_panel, tool_panel, fam_box]:
		if n != null:
			(n as Control).visible = false
	var p := _panel(null, "panel", 0, 10)
	p.name = "VisitBanner"
	_put(p, Control.PRESET_CENTER_TOP, Vector2(0, 92))
	var v2 := VBoxContainer.new()
	v2.add_theme_constant_override("separation", 4)
	p.add_child(v2)
	var t := _label("Вы в гостях у «%s»" % String(v.get("name", "?")), 24, false, C_INK, font_title)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v2.add_child(t)
	var c: Dictionary = v.get("card", {}) if typeof(v.get("card")) == TYPE_DICTIONARY else {}
	var bits := []
	if not c.is_empty():
		bits.append("%s, %d жителей" % [String(c.get("rank", "")), int(c.get("pop", 0))])
		if String(c.get("title", "")) != "":
			bits.append(String(c["title"]))
		if String(c.get("hero", "")) != "":
			bits.append("герой — %s" % String(c["hero"]))
	bits.append("город только посмотреть: здесь ничего не строится и не сохраняется")
	var sub_l := _wrap(_label(" · ".join(PackedStringArray(bits)), 14, false, C_SOFT), 520)
	sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v2.add_child(sub_l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var like := Button.new()
	like.text = "Нравится (%d)" % int(v.get("likes", 0))
	like.icon = ico("happy", 22)
	_small_btn(like)
	like.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	like.disabled = bool(v.get("liked", false))
	if like.disabled:
		like.tooltip_text = "Сегодня вы уже сказали «нравится»"
	like.pressed.connect(func():
		like.disabled = true
		SocialNet.me().like(int(v.get("id", 0)), func(d: Dictionary, err: String):
			if err != "":
				notify(err, "info")
				like.disabled = false
				return
			like.text = "Нравится (%d)" % int(d.get("likes", 0))
			if game.sound:
				game.sound.ui("coins")))
	row.add_child(like)
	var home := Button.new()
	home.text = "Домой"
	home.icon = ico("housing", 22)
	_small_btn(home)
	home.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	home.pressed.connect(func(): game.restart("play"))
	row.add_child(home)
	v2.add_child(row)
	_snug.call_deferred(p)
	show_city_name()


func _window(title: String, w := 560.0) -> Array:
	var p := _panel(null, "panel", 0, 10)
	_put(p, Control.PRESET_CENTER, Vector2.ZERO)
	p.custom_minimum_size = Vector2(w, 0)
	p.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var hdr := HBoxContainer.new()
	var sp := Control.new()                      # противовес кнопке «закрыть» — заголовок ровно посередине
	sp.custom_minimum_size = Vector2(36, 0)
	hdr.add_child(sp)
	var t := _label(title, 30, false, C_INK, font_title)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_child(t)
	var close := _bare("close", "Закрыть", 36, func(): p.visible = false)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hdr.add_child(close)
	v.add_child(hdr)
	v.add_child(_divider())
	return [p, v, hdr]


func _events_panel() -> void:
	var w := _window("Обзор города", 720)
	overview_panel = w[0]
	overview_panel.name = "CityOverview"
	# Один внешний контейнер: старые ссылки по-прежнему закрывают всё окно.
	events_panel = overview_panel
	finance_panel = overview_panel
	stats_panel = overview_panel
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	(w[1] as VBoxContainer).add_child(tabs)
	overview_scroll = ScrollContainer.new()
	overview_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	(w[1] as VBoxContainer).add_child(overview_scroll)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview_scroll.add_child(pages)
	for t: Array in [["city", "Город"], ["money", "Деньги"], ["people", "Жители"], ["events", "События"]]:
		var id: String = t[0]
		var b := Button.new()
		b.name = "overview_tab_" + id
		b.text = t[1]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("pressed", _box_pill(16, 6, "g_btn_on"))
		b.add_theme_stylebox_override("hover_pressed", _box_pill(16, 6, "g_btn_on"))
		b.pressed.connect(func(): _select_overview(id))
		tabs.add_child(b)
		overview_buttons[id] = b
		var page := VBoxContainer.new()
		page.name = "overview_" + id
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 10)
		page.visible = id == "city"
		pages.add_child(page)
		overview_pages[id] = page
	var list := VBoxContainer.new()
	list.name = "list"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	overview_pages["events"].add_child(list)
	root.resized.connect(_fit_overview_settings)
	_fit_overview_settings.call_deferred()


func _fit_overview_settings() -> void:
	# Высота в логических точках, с запасом для заголовка и вкладок.
	var room := root.size.y
	if overview_scroll != null:
		overview_scroll.custom_minimum_size = Vector2(660, clampf(room - 190.0, 180.0, 480.0))
		_snug(overview_panel)
	if settings_scroll != null:
		settings_scroll.custom_minimum_size = Vector2(490, clampf(room - 150.0, 180.0, 480.0))
		_snug(settings_panel)


func _open_overview(tab := "city") -> void:
	var was := overview_panel.visible and overview_tab == tab
	_close_windows()
	if was:
		return
	overview_panel.visible = true
	_close_tray()
	_hide_info()
	_select_overview(tab)


func _select_overview(tab: String) -> void:
	if not overview_pages.has(tab):
		return
	overview_tab = tab
	for id: String in overview_pages:
		(overview_pages[id] as Control).visible = id == tab
		(overview_buttons[id] as Button).set_pressed_no_signal(id == tab)
	overview_scroll.scroll_vertical = 0
	_refresh_overview()
	_fit_overview_settings()


func _refresh_overview() -> void:
	match overview_tab:
		"city": _fill_overview_city()
		"money": _fill_finance()
		"people": _fill_stats()
		"events": _fill_events()
	CityStyle.apply(overview_panel)


func _fill_overview_city() -> void:
	var v: VBoxContainer = overview_pages["city"]
	_clear(v)
	var c: City = game.city
	var families := 0
	for home: Dictionary in c.buildings.values():
		if c.is_house(home):
			families += (home.get("families", []) as Array).size()
	v.add_child(_row("family", "Жители / семьи", "%d / %d" % [int(c.stats.get("pop", 0)), families]))
	v.add_child(_row("housing", "Семьи ждут дом", str(c.arrivals.size())))
	v.add_child(_label("Потребности жителей", 18, true))
	var coverage := {}
	var required := []
	for n: String in Defs.NEED_ORDER:
		var need: Dictionary = c.stats.get("needs", {}).get(n, {})
		coverage[n] = int(need.get("coverage", 0))
		if int(need.get("houses", 0)) > 0:
			required.append(n)
	v.add_child(_need_strip(coverage, required, 620))
	v.add_child(_wrap(_label("Среднее по жителям, которым нужна эта потребность", 13, false, C_SOFT), 620))
	var workers := 0
	var jobs := 0
	var free := 0
	for cl: String in Defs.CLASS_ORDER:
		workers += int(c.stats.get("filled", {}).get(cl, 0))

		free += int(c.stats.get("free", {}).get(cl, 0))
	for b: Dictionary in c.buildings.values():
		if not b.get("over", false):
			jobs += c.job_max(b)
	v.add_child(_row("hammer", "Работники / рабочие места", "%d / %d" % [workers, jobs]))
	v.add_child(_row("person", "Без работы", str(free)))
	for cl: String in Defs.CLASS_ORDER:
		v.add_child(_label(String(Defs.CLASSES[cl]["name"]), 16, true))
		v.add_child(_row("person", "Свободные горожане", str(int(c.stats.get("free", {}).get(cl, 0))), C_GOOD))
		v.add_child(_row("hammer", "Пустые рабочие места", str(c.empty_jobs(cl))))
	var happy := int(c.stats.get("happy", 0))
	v.add_child(_row("happy", "Счастье", "%d%%" % happy, C_GOOD if happy >= 60 else C_BAD))
	var losses: Array = []
	for part: Array in c.stats.get("happy_parts", []):
		if int(part[1]) < 0 and String(part[0]) != "Больше 100% не бывает":
			losses.append(part)
	losses.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) < int(b[1]))
	for part: Array in losses.slice(0, 3):
		v.add_child(_row("face_bad", String(part[0]), "%d%%" % int(part[1]), C_BAD))
	if losses.is_empty():
		var tips: Array = c.stats.get("happy_tips", [])
		for tip in tips.slice(0, 3):
			v.add_child(_wrap(_label(String(tip), 15, false, C_SOFT), 620))
	var net := (float(c.stats.get("income", 0.0)) - float(c.stats.get("upkeep", 0.0))) * 24.0
	v.add_child(_row("coins", "Доход минус расходы за сутки", ("+" if net >= 0 else "−") + fmt(absf(net)), C_GOOD if net >= 0 else C_BAD))
	var map := Button.new()
	map.name = "overview_happiness_map"
	map.text = "Счастье на карте"
	map.icon = ico("view", 26)
	map.pressed.connect(func():
		overview_panel.visible = false
		set_overlay("" if overlay != "" else "happy"))
	v.add_child(map)
	v.add_child(_divider())
	v.add_child(_row("level", "Уровень города", String(Defs.LEVELS[c.level]["name"])))
	var nx := c.next_level()
	if nx.is_empty():
		v.add_child(_label("Это высший уровень — ваш город стал Вечным!", 16, true, C_GOOD))
	else:
		v.add_child(_label("Следующий уровень — «%s»" % nx["name"], 18, true))
		for need: Dictionary in c.rank_needs():
			var value := ("%d%% / %d%%" % [int(need["have"]), int(need["need"])]) if need["pct"] else ("%s / %s" % [fmt(need["have"]), fmt(need["need"])])
			v.add_child(_row("check" if need["ok"] else String(need["icon"]), String(need["text"]), value, C_GOOD if need["ok"] else C_BAD))


## Фильтруем только показ; полный журнал City.events не меняется.
func _important_event(e: Dictionary) -> bool:
	if bool(e.get("advisor", false)):
		return true
	var icon := String(e.get("icon", ""))
	var text := String(e.get("text", "")).to_lower()
	if icon == "level":
		return true
	if icon in ["fire", "sick", "disaster"] or text.begins_with("огонь погас") or (icon == "brazier" and text.contains("пожар")):
		return true
	if text.begins_with("просьба выполнена") or text.begins_with("заказ выполнен"):
		return true
	if text.begins_with("семья ") and text.contains("уехала"):
		return true
	if text.begins_with("игры в честь богов!") or text.begins_with("триумф!") or (text.begins_with("сегодня ") and text.contains("празднует")):
		return true
	if text.begins_with("открыто украшение") or text.begins_with("открыты украшения"):
		return true
	if icon == "research" and (text.begins_with("изучено:") or text.begins_with("открыто:") or text.begins_with("открылась")):
		return true
	if icon == "legion" and ["побед", "поражен", "отступ", "проиграл", "бой заверш", "поход заверш", "отбили", "нападали"].any(func(word: String) -> bool: return text.contains(word)):
		return true
	return ["пожар", "заболели", "эпидемия", "наводнение", "землетрясение"].any(func(word: String) -> bool: return text.begins_with(word))


func _overview_events() -> Array:
	var result: Array = []
	var events: Array = game.city.events
	for i in range(events.size() - 1, -1, -1):
		if _important_event(events[i]):
			result.append(events[i])
			if result.size() == 30:
				break
	return result


func _event_line(text: String) -> String:
	var line := text.replace("\n", " ").strip_edges()
	if line.length() <= 70:
		return line
	for i in line.length():
		if line[i] in [".", "!", "?"] and (i == line.length() - 1 or line[i + 1] == " "):
			line = line.left(i + 1)
			break
	return line


func _fill_events() -> void:
	if overview_panel.visible and overview_tab == "events":
		bell_count = 0
		bell_badge.text = ""
	var list: VBoxContainer = events_panel.find_child("list", true, false)
	_clear(list)
	var ev := _overview_events()
	if ev.is_empty():
		list.add_child(_label("Пока ничего не случилось.", 17, false, C_SOFT))
	for e: Dictionary in ev:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.add_child(_icon(String(e.get("icon", "info")), 24, C_SOFT))
		h.add_child(_label("День %d" % (int(e.get("day", 0)) + 1), 15, true, C_SOFT))
		var full := I18n.t(String(e.get("full_text", e["text"])))
		var l := _label(_event_line(I18n.t(String(e["text"]))), 16)
		l.tooltip_text = full
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.custom_minimum_size = Vector2(450, 0)
		h.add_child(l)
		list.add_child(h)


# ---------- исследования ----------

func _research_panel() -> void:
	var w := _window("Исследования", 900)
	(w[0] as PanelContainer).add_theme_stylebox_override("panel", _card_frame())
	((w[2] as HBoxContainer).get_child(1) as Label).add_theme_font_size_override("font_size", 22)
	(w[1] as VBoxContainer).get_child(1).hide()
	research_panel = w[0]
	research_panel.name = "ResearchWindow"
	CityStyle.apply(research_panel)
	research_tree = preload("res://scripts/research_tree.gd").new()
	research_tree.setup(self, w[1])
	research_panel.visibility_changed.connect(func():
		if research_panel.visible:
			_research_head()                  # В том числе при прямом show(), без кнопки верхней полосы.
			research_tree.open_scroll = true
		else:
			research_tree.close_detail())
	# окно закрыли — всё, что в нём было новым, игрок видел: «НОВОЕ» с исследований снимается
	research_panel.visibility_changed.connect(func():
		if not research_panel.visible and game and game.city and game.mode in ["new", "play"]:
			for r in Defs.RESEARCH:
				game.city.mark_seen_r(r["id"])
			update_new_marks()
			# изучили второй этаж — про «Этаж» советник скажет, когда окно закрыто. Через кадр: Esc, правая кнопка
			# и щелчок по карте закрывают окна (close_panels) вместе с советником — совет погас бы, не показавшись.
			# Сначала «Легион собран!» (изучили «Легион»), потом остальные советы: они ждут, пока советник занят
			var lu := LegionUi.of(self)
			if lu != null:
				lu._update_button.call_deferred()
			_once_tips.call_deferred())


func _fill_research() -> void:
	if not research_panel.visible:
		return
	_research_head()
	research_tree.refresh()
	if research_tree.open_scroll:
		research_tree.close_detail()
		research_tree.focus_rank(game.city.level)
	research_tree.open_scroll = false

# ---------- финансы, статистика ----------
func _finance_panel() -> void:
	var page: VBoxContainer = overview_pages["money"]
	var v := VBoxContainer.new()
	v.name = "finance_body"
	page.add_child(v)


func _stats_panel() -> void:
	var page: VBoxContainer = overview_pages["people"]
	# две вкладки: «Обзор» (классы, работники) и «Горожане» — найти жителя по имени или семье (этап 6.9)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	for t: Array in [["", "Обзор", "stats"], ["people", "Горожане", "person"]]:
		var b := Button.new()
		b.text = t[1]
		b.icon = ico(t[2], 26)
		CityStyle.button(b)
		b.add_theme_font_size_override("font_size", 14)
		b.custom_minimum_size = Vector2(144, 36)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.name = "tab_" + (t[0] if t[0] != "" else "main")
		b.add_theme_font_override("font", font_bold)
		b.add_theme_stylebox_override("pressed", _box_pill(16, 6, "g_btn_on"))
		b.add_theme_stylebox_override("hover_pressed", _box_pill(16, 6, "g_btn_on"))
		var id: String = t[0]
		b.pressed.connect(func():
			stats_tab = id
			_fill_stats())
		tabs.add_child(b)
	page.add_child(tabs)
	var v := VBoxContainer.new()
	v.name = "stats_body"
	page.add_child(v)
	# «Горожане»: строка поиска и фильтры живут, пока окно открыто (часовое обновление их не пересобирает)
	var pv := VBoxContainer.new()
	pv.name = "people"
	pv.add_theme_constant_override("separation", 6)
	pv.visible = false
	var q := LineEdit.new()
	q.name = "q"
	q.placeholder_text = "Имя или семья: «Гай», «Юлиев»…"
	q.clear_button_enabled = true
	q.custom_minimum_size = Vector2(500, 40)
	q.add_theme_font_size_override("font_size", 18)
	q.text_changed.connect(func(_t):
		people_guidance = {}
		_fill_people())
	pv.add_child(q)
	var fl := HBoxContainer.new()
	fl.add_theme_constant_override("separation", 6)
	for f: Array in [["", "Все"], ["nojob", "Без работы"], ["sad", "Несчастные"], ["kids", "Дети"], ["happy", "По счастью"]]:
		var fb := Button.new()
		fb.text = f[1]
		fb.toggle_mode = true
		fb.focus_mode = Control.FOCUS_NONE
		fb.name = "f_" + (f[0] if f[0] != "" else "all")
		fb.add_theme_font_size_override("font_size", 16)
		fb.add_theme_stylebox_override("pressed", _box_pill(12, 4, "g_btn_on"))
		fb.add_theme_stylebox_override("hover_pressed", _box_pill(12, 4, "g_btn_on"))
		var fid: String = f[0]
		fb.pressed.connect(func():
			people_filter = fid
			people_guidance = {}
			_fill_people())
		fl.add_child(fb)
	pv.add_child(fl)
	var list := VBoxContainer.new()
	list.name = "plist"
	list.add_theme_constant_override("separation", 4)
	list.custom_minimum_size = Vector2(480, 0)
	pv.add_child(list)
	page.add_child(pv)


var stats_tab := ""                    # "" — обзор, "people" — «Горожане»
var people_filter := ""
var people_guidance: Dictionary = {}
var people_target: Control
var _quest_world: Dictionary = {}
var _quest_world_until := 0


## «Горожане»: найденные жители строками (имя, кто, работа, счастье дома); щелчок — карточка и камера за ним
func _fill_people() -> void:
	var pv: Control = stats_panel.find_child("people", true, false)
	var list: VBoxContainer = stats_panel.find_child("plist", true, false)
	if pv == null or list == null or game.people == null:
		return
	for b in pv.find_children("f_*", "Button", true, false):
		(b as Button).set_pressed_no_signal(String(b.name) == "f_" + (people_filter if people_filter != "" else "all"))
	people_target = null
	_clear(list)
	var q: LineEdit = pv.find_child("q", true, false)
	var c: City = game.city
	var ppl: People = game.people
	var info := {}
	var found := PersonCard.search(ppl, q.text if q else "", people_filter, info)
	if not people_guidance.is_empty() and String(people_guidance.get("fam", "")) != "":
		found = found.filter(func(r: Dictionary): return String(r.get("fam", "")) == String(people_guidance["fam"]) and String(r.get("pn", "")) == String(people_guidance.get("pn", "")))
	if found.is_empty():
		list.add_child(_label("Никого не нашли" if (q and q.text != "") or people_filter != "" else "В городе пока никто не живёт", 16, false, C_SOFT))
		return
	for r: Dictionary in found:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(_cls_pic(String(r["cls"]), 30))
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", -2)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(_label(People.name_of(r), 17, true))
		var ms := PersonCard.members_of(ppl, r)
		var who := Residents.role(r.get("m", {}), ms) if r.has("m") else ""
		var jb: Dictionary = c.buildings.get(int(r["job"]), {})
		var job := Residents.job_noun(String(jb["type"]), r["female"]) if not jb.is_empty() else ("" if r["child"] else "без работы")
		tv.add_child(_label("%s · семья %s%s" % [who, StoryDefs.fam_gen(String(r["fam"])), (" · " + job) if job != "" else ""], 13, false, C_SOFT))
		row.add_child(tv)
		var h: Dictionary = c.buildings.get(int(r["home"]), {})
		if not h.is_empty():
			var hp := int(h["happy"])
			row.add_child(_label("%d%%" % mini(hp, 100), 16, true, C_GOOD if hp >= 60 else (C_GOLD if hp >= 40 else C_BAD)))
		var family_mode := people_filter == "happy"
		var click_row := _clickable(row, "Карточка дома семьи" if family_mode else "Карточка жителя, камера пойдёт за ним", func():
			stats_panel.visible = false
			people_guidance = {}
			_ptr_shown = {}
			if family_mode and not h.is_empty():
				game.select_building(h)
				guide_world({"building": int(h["id"])})
			else:
				game.select_person({"r": r})
				guide_world({"resident": r})
				PersonCard.follow(self, {"r": r})
			if game.stories != null:
				game.stories.tick()
			_update_pointer())
		list.add_child(click_row)
		click_row.set_meta("resident", r)
		if not people_guidance.is_empty() and people_target == null:
			var button := click_row.get_child(click_row.get_child_count() - 1) as Button
			var rim := StyleBoxFlat.new()
			rim.bg_color = Color(1.0, 0.83, 0.35, 0.14)
			rim.border_color = C_GOLD
			rim.set_border_width_all(2)
			rim.set_corner_radius_all(6)
			button.add_theme_stylebox_override("normal", rim)
			button.name = "QuestResident"
			people_target = button
	if people_target != null:
		_focus_people.call_deferred()

	if int(info.get("total", 0)) > found.size():
		var more := _label("Показаны %d из %d — уточните имя или семью" % [found.size(), int(info["total"])], 14, false, C_SOFT)
		more.name = "more"
		list.add_child(more)


## После раскладки прокручиваем к строке; срок стрелки задаёт только щелчок.
func _focus_people() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(people_target) and people_target.is_visible_in_tree():
		overview_scroll.ensure_control_visible(people_target)



## Тот же значок над миром, что у историй. Для жителя следует за его положением.
func guide_world(target: Dictionary) -> void:
	_quest_world = target
	_quest_world_until = Time.get_ticks_msec() + PTR_SHOW_MS
	_quest_world_tick(true)


func _quest_world_tick(move_camera := false) -> void:
	if tutorial_busy():
		clear_badge("quest_target")
		return
	if _quest_world.is_empty():
		return
	if Time.get_ticks_msec() >= _quest_world_until:
		clear_badge("quest_target")
		_quest_world = {}
		return
	var pos := Vector3.ZERO
	if _quest_world.has("resident"):
		var r: Dictionary = _quest_world["resident"]
		var p: Vector2 = r.get("p", Vector2.ZERO)
		pos = Vector3(p.x, game.land.height_at(p.x, p.y) + 2.0, p.y)
	elif _quest_world.has("building"):
		var b: Dictionary = game.city.buildings.get(int(_quest_world["building"]), {})
		if b.is_empty():
			clear_badge("quest_target")
			_quest_world = {}
			return
		pos = Vector3(b["pos"].x, float(b["y"]) + game.city.blueprint(b).top_y() + 1.4, b["pos"].y)
	else:
		pos = _quest_world.get("pos", Vector3.ZERO)
	set_badge("quest_target", pos, "arrow_down", false, "", Callable(), "mark")
	if move_camera:
		game.rig.look_at_point(pos - Vector3(0, 1.4, 0))


func _fill_finance() -> void:
	var v: VBoxContainer = finance_panel.find_child("finance_body", true, false)
	for ch in v.get_children():
		ch.queue_free()
	var c: City = game.city
	var wages := float(c.stats.get("wages", 0.0))
	var net := float(c.stats.get("income", 0.0)) - float(c.stats.get("upkeep", 0.0)) - float(c.stats.get("legion_denarii", 0.0))
	v.add_child(_row("coins", "В казне", "%s / %s" % [fmt(c.money), fmt(c.money_cap())]))
	v.add_child(_row("income", "Налоги за час", "+%s" % fmt(c.stats.get("income", 0.0)), C_GOOD))
	v.add_child(_row("family", "Жалованье работникам за час", "−%s" % fmt(wages), C_BAD))
	v.add_child(_row("hammer", "Содержание построек за час", "−%s" % fmt(float(c.stats.get("upkeep", 0.0)) - wages), C_BAD))
	v.add_child(_row("check", "Итого за час", ("+" if net >= 0 else "−") + fmt(absf(net)), C_GOOD if net >= 0 else C_BAD))
	if c.unpaid_h == Defs.UNPAID_H and float(c.stats.get("unpaid", 0.0)) > 0.0:
		v.add_child(_row("coins", "Казна пуста — не плачено за час", fmt(float(c.stats.get("unpaid", 0.0))), C_BAD))
		v.add_child(_wrap(_label("Город в долг не живёт: недоплаченное не плачено, а жители обижены — счастье всех домов −%d%% — и ещё %d ч после того, как казна снова сможет платить. Поднимите налоги (с «Деревни»), заселяйте дома, уберите лишних работников «−» в карточках построек." % [Defs.UNPAID_HAPPY, Defs.UNPAID_H - 1], 14, false, C_BAD), 420))
	elif c.unpaid_h > 0:
		v.add_child(_row("family", "Жители ещё обижены за жалованье", "%d ч" % c.unpaid_h, C_INK))   # казна уже платит, обида проходит
	v.add_child(_row("research", "Очки исследований", "%s / %s (+%s в час)" % [fmt(c.rp), fmt(c.rp_cap()), fmt_rate(float(c.stats.get("rp_day", 0.0)))]))
	# история: доход за час и казна — последние 48 игровых часов; «За сутки» — куда ушли и откуда пришли денарии
	if c.hist.size() >= 2:
		var nets := []
		for i in c.hist_series("tax").size():
			nets.append(int(c.hist_series("tax")[i]) + int(c.hist_series("wage")[i]) + int(c.hist_series("upkeep")[i]))
		v.add_child(_spark_row("Доход за час, последние %d ч" % nets.size(), nets, C_GOOD, true))
		v.add_child(_spark_row("Казна, последние %d ч" % nets.size(), c.hist_series("money"), C_GOLD, false))
	if not c.hist.is_empty():
		var day_l := _label(day_line(), 14, false, C_INK)
		day_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		day_l.custom_minimum_size = Vector2(420, 0)
		v.add_child(day_l)
	if c.tax_open():
		v.add_child(_divider(14))
		_tax_rows(v)
	var tx := []
	for cl in ["plebs", "artisans", "patricians"]:
		tx.append(String.num(float(Defs.CLASSES[cl]["tax"]), 1).replace(".", ","))
	var hint := _label("Налог платит каждый житель: плебей — %s, ремесленник — %s, патриций — %s денария в час; счастливые платят больше. Содержание: каждая постройка (кроме домов и украшений) стоит в час %s%% своей цены, а каждый работник — %s ден. жалованья; жалованье растёт с уровнем города. Казна не вмещает больше предела — поднимайте уровень города и изучайте хранилища." % [tx[0], tx[1], tx[2], String.num(c.upkeep_rate() * 100.0, 1).replace(".", ","), String.num(c.wage(), 2).replace(".", ",")], 14, false, C_SOFT)
	if c.cozy_v >= 1:
		hint.text += "\n" + "Дома: %s%% цены в час (половина ставки). Это входит в содержание построек." % String.num(c.upkeep_rate() * 50.0, 1).replace(".", ",")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(400, 0)
	v.add_child(hint)


## «За сутки: налоги +4 200, жалованье −1 100, содержание −900, стройка −2 300» — по истории денег (City.hist)
	CityStyle.apply(overview_panel)


func day_line() -> String:
	var c: City = game.city
	var n := mini(24, c.hist.size())
	var names := {"tax": "налоги", "wage": "жалованье", "upkeep": "содержание", "build": "стройка", "fest": "игры", "land": "земля",
		"legion": "Легион", "reward": "награды", "tour": "туристы", "other": "дороги и прочее"}
	var bits := []
	var tot := 0
	for k in ["tax", "tour", "wage", "upkeep", "build", "fest", "land", "legion", "reward", "other"]:
		var s := c.hist_sum(k, n)
		tot += s
		if s != 0:
			bits.append("%s %s%s" % [names[k], "+" if s > 0 else "−", fmt(absi(s))])
	var lost := c.hist_sum("lost", n)
	tot -= lost                                # итого = сколько правда прибыло в казну (что не уместилось — пропало)
	var unpaid := c.hist_sum("unpaid", n)
	tot += unpaid                              # не плачено (казна была пуста) — эти денарии и не уходили
	var head := "За сутки" if n >= 24 else "За %d ч" % n
	var t := "%s: %s. Итого %s%s ден." % [head, ", ".join(bits) if not bits.is_empty() else "без движения", "+" if tot >= 0 else "−", fmt(absi(tot))]
	if lost > 0:
		t += " Не уместилось в казну: %s." % fmt(lost)
	if unpaid > 0:
		t += " Не плачено жалованья и содержания (казна была пуста): %s." % fmt(unpaid)
	return t


## Строка с искоркой: подпись, последнее число и тонкая линия за последние часы
func _spark_row(title: String, data: Array, col: Color, zero: bool) -> Control:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 10)
	var l := _label("%s: %s" % [title, fmt(float(data[-1])) if not data.is_empty() else "—"], 14, true, C_SOFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_child(l)
	var sp := Spark.new()
	sp.data = data
	sp.col = col
	sp.zero = zero
	sp.custom_minimum_size = Vector2(200, 34)
	r.add_child(sp)
	return r


## Налоги по классам (с «Деревни», как в Town to City): мягкие / обычные / высокие; предупреждение, если высокие
## опустят счастье города ниже нужного для следующего уровня
func _tax_rows(v: VBoxContainer) -> void:
	var c: City = game.city
	v.add_child(_label("Налоги по классам", 18, false, C_INK, font_title))
	var nx := c.level + 1
	var need := int(c.lv(nx)["happy"]) if nx < Defs.LEVELS.size() else 0
	var key := "%d|%d|%s|%d" % [c.hour_n, c.level, str(c.taxes), c.buildings.size()]
	if String(_tax_warn.get("key", "")) != key:
		_tax_warn = {"key": key}
		# прикидка нужна, только когда предупреждение может показаться: счастья сейчас хватает на следующий уровень
		if need > 0 and int(c.stats.get("happy", 0)) >= need:
			for cl in Defs.CLASS_ORDER:
				if int(c.stats["residents"].get(cl, 0)) > 0 and c.tax_of(cl) != 2:
					_tax_warn[cl] = c.happy_if_tax(cl, 2)
	for cl in Defs.CLASS_ORDER:
		if int(c.stats["residents"].get(cl, 0)) <= 0 and c.tax_of(cl) == 1:
			continue
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		r.add_child(_cls_pic(cl, 30))
		var nl := _label(String(Defs.CLASSES[cl]["name"]), 16, true, C_INK)
		nl.custom_minimum_size = Vector2(130, 0)
		nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(nl)
		for i in Defs.TAX_SET.size():
			var ts: Dictionary = Defs.TAX_SET[i]
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			var on := c.tax_of(cl) == i
			b.text = ("✓ " if on else "") + String(ts["name"])
			b.disabled = on
			b.tooltip_text = "%s: налог ×%s, счастье домов класса %s" % [ts["name"], String.num(float(ts["k"]), 1).replace(".", ","),
				("%+d%%" % int(ts["happy"])) if int(ts["happy"]) != 0 else "без изменений"]
			var ci: int = i
			var cc: String = cl
			b.pressed.connect(func():
				game.city.set_tax(cc, ci)
				_fill_finance())
			r.add_child(b)
		v.add_child(r)
		if _tax_warn.has(cl) and need > 0 and int(_tax_warn[cl]) < need and int(c.stats.get("happy", 0)) >= need:
			var wl := _label("Высокие налоги опустят счастье города до %d%%, а для уровня «%s» нужно %d%%." % [int(_tax_warn[cl]), Defs.LEVELS[nx]["name"], need], 13, true, C_BAD)
			wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			wl.custom_minimum_size = Vector2(420, 0)
			v.add_child(wl)
	if need > 0 and int(c.stats.get("happy", 0)) < need and not c.taxes.values().filter(func(x): return int(x) == 2).is_empty():
		var wl2 := _label("Счастье города %d%%, а для уровня «%s» нужно %d%%: высокие налоги мешают." % [int(c.stats.get("happy", 0)), Defs.LEVELS[nx]["name"], need], 13, true, C_BAD)
		wl2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		wl2.custom_minimum_size = Vector2(420, 0)
		v.add_child(wl2)


## Искорка: ряд чисел за последние часы — тонкая линия с точкой на конце (окна «Финансы» и «Жители»)
class Spark extends Control:
	var data: Array = []
	var col := Color("6b8f3a")
	var zero := false                     # с нулевой линией: доход бывает и в минус

	func _draw() -> void:
		if data.size() < 2:
			return
		var lo := float(data.min())
		var hi := float(data.max())
		if zero:
			lo = minf(lo, 0.0)
			hi = maxf(hi, 0.0)
		if hi - lo < 0.001:
			hi = lo + 1.0
		var w := size.x
		var h := size.y
		var pts := PackedVector2Array()
		for i in data.size():
			pts.append(Vector2(w * i / float(data.size() - 1), h - 3.0 - (h - 6.0) * (float(data[i]) - lo) / (hi - lo)))
		if zero and lo < 0.0:
			var zy := h - 3.0 - (h - 6.0) * (0.0 - lo) / (hi - lo)
			draw_line(Vector2(0, zy), Vector2(w, zy), Color(col, 0.35), 1.0)
		draw_polyline(pts, col, 2.0, true)
		draw_circle(pts[pts.size() - 1], 3.0, col)


func _fill_stats() -> void:
	var v: VBoxContainer = stats_panel.find_child("stats_body", true, false)
	for ch in v.get_children():
		ch.queue_free()
	var pv: Control = stats_panel.find_child("people", true, false)
	for b in stats_panel.find_children("tab_*", "Button", true, false):
		(b as Button).set_pressed_no_signal(String(b.name) == "tab_" + (stats_tab if stats_tab != "" else "main"))
	v.visible = stats_tab == ""
	if pv:
		pv.visible = stats_tab == "people"
	if stats_tab == "people":
		_fill_people()
		_snug(stats_panel)
		return
	var c: City = game.city
	if c.hist.size() >= 2:
		v.add_child(_spark_row("Жители, последние %d ч" % c.hist.size(), c.hist_series("pop"), C_INK, false))
		v.add_child(_spark_row("Счастье города, %", c.hist_series("happy"), C_GOOD, false))
	for cl in Defs.CLASS_ORDER:
		var cd: Dictionary = Defs.CLASSES[cl]
		var hd := HBoxContainer.new()
		hd.add_theme_constant_override("separation", 8)
		hd.add_child(_cls_pic(cl, 36))
		var hl := _label(cd["name"], 20, false, C_INK, font_title)
		hl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hd.add_child(hl)
		v.add_child(hd)
		v.add_child(_row("family", "Жителей", str(int(c.stats["residents"].get(cl, 0)))))
		v.add_child(_row("happy", "Счастье", "%d%%" % int(c.stats.get("class_happy", {}).get(cl, 0)), C_GOOD))
		v.add_child(_row("hammer", "Работники / рабочие места", "%d / %d" % [int(c.stats["workers"].get(cl, 0)), int(c.stats["jobs"].get(cl, 0))]))
		v.add_child(_row("check", "Свободных работников", str(int(c.stats["free"].get(cl, 0)))))




# ---------- меню паузы, настройки, покупка земли ----------
	CityStyle.apply(overview_panel)


func _pause_panel() -> void:
	var w := _window("Меню", 380)
	pause_panel = w[0]
	var v: VBoxContainer = w[1]
	for t: Array in [["Продолжить", "play", func(): pause_panel.visible = false], ["Сохранить", "save", func(): _save_now()],
			["Настройки", "settings", func(): pause_panel.visible = false; _open_settings()], ["Титры", "laurels", func(): open_credits()],
			["Главное меню", "level", func(): game.restart("menu")], ["Выход", "exit", func(): _quit()]]:
		var b := Button.new()
		b.text = t[0]
		b.icon = ico(t[1], 40)
		b.expand_icon = false
		b.custom_minimum_size = Vector2(320, 54)
		b.add_theme_font_size_override("font_size", 21)
		b.pressed.connect(t[2])
		v.add_child(b)


func _save_now() -> void:
	if game.can_save:
		game.save()
		notify("Город сохранён", "save")
	else:
		notify("Готовый город не сохраняется — начните свой в меню.", "info")
	pause_panel.visible = false


func _quit() -> void:
	if game.can_save:
		game.save()
	Account.me().quit_game()                  # сначала город уходит в облако (не дольше нескольких секунд)


func _settings_panel() -> void:
	var w := _window("Настройки", 550)
	settings_panel = w[0]
	settings_scroll = ScrollContainer.new()
	settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	(w[1] as VBoxContainer).add_child(settings_scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 12)
	settings_scroll.add_child(v)
	var more := VBoxContainer.new()
	more.name = "settings_more_body"
	more.add_theme_constant_override("separation", 12)
	var mk_slider := func(parent: VBoxContainer, text: String, icon: String, key: String, lo: float, hi: float, step: float) -> HSlider:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		r.add_child(_icon(icon, 26, C_SOFT))
		var l := _label(text, 18, true)
		l.custom_minimum_size = Vector2(190, 0)
		r.add_child(l)
		var sl := HSlider.new()
		sl.name = key
		sl.min_value = lo
		sl.max_value = hi
		sl.step = step
		sl.custom_minimum_size = Vector2(220, 28)
		sl.value_changed.connect(func(x):
			game.settings[key] = x
			if key == "music" or key == "sfx":
				game.sound.apply_volumes())
		sl.drag_ended.connect(func(_c): game.save_settings())
		r.add_child(sl)
		parent.add_child(r)
		return sl
	mk_slider.call(v, "Музыка", "music", "music", 0.0, 1.0, 0.05)
	mk_slider.call(v, "Звуки", "sound", "sfx", 0.0, 1.0, 0.05)
	var us: HSlider = mk_slider.call(more, "Размер интерфейса", "view", "ui_scale", 0.8, 1.4, 0.05)
	us.tooltip_text = "Размер кнопок и надписей — до самого крупного, что помещается в это окно (иначе полосы внизу наехали бы друг на друга)"
	Gfx.settings_block(self, v, more)               # «Графика» (4 уровня), «Показывать FPS», видеокарта — scripts/gfx.gd
	var fs := CheckBox.new()
	fs.text = "Полный экран"
	fs.name = "fs"
	fs.add_theme_font_size_override("font_size", 18)
	fs.toggled.connect(func(x): game.settings["fullscreen"] = x; game.save_settings())
	v.add_child(fs)
	# язык: две понятные кнопки «RU | EN» (то же — в главном меню); выбранная подсвечена
	var lr := HBoxContainer.new()
	lr.add_theme_constant_override("separation", 8)
	lr.add_child(_icon("scroll", 26, C_SOFT))
	var ll := _label("Язык / Language", 18, true)
	ll.custom_minimum_size = Vector2(190, 0)
	lr.add_child(ll)
	lr.add_child(_lang_buttons())
	v.add_child(lr)
	var av := CheckBox.new()
	av.text = "Подсказки советника"
	av.name = "adv"
	av.tooltip_text = "Выключите подсказки — советы останутся в «Обзоре города», на вкладке «События»."
	av.add_theme_font_size_override("font_size", 18)
	av.button_pressed = advisor_on()
	av.toggled.connect(func(x):
		game.settings["advisor_off"] = not x
		game.save_settings())
	v.add_child(av)
	var details := Button.new()
	details.name = "settings_more"
	details.alignment = HORIZONTAL_ALIGNMENT_LEFT
	details.pressed.connect(func():
		game.settings["settings_more"] = not bool(game.settings.get("settings_more", false))
		game.save_settings()
		_settings_more_refresh())
	v.add_child(details)
	v.add_child(more)
	_settings_more_refresh()
	var au := CheckBox.new()
	au.text = "Автосохранение"
	au.name = "auto"
	au.add_theme_font_size_override("font_size", 18)
	au.toggled.connect(func(x): game.settings["autosave"] = x; game.save_settings())
	more.add_child(au)
	# аккаунт (почта, облако, «Выйти») и «Уничтожить город…» с тремя подтверждениями — scripts/account_ui.gd
	AccountUi.settings_block(self, more)


func _settings_more_refresh() -> void:
	var on := bool(game.settings.get("settings_more", false))
	var more := settings_panel.find_child("settings_more_body", true, false) as Control
	var button := settings_panel.find_child("settings_more", true, false) as Button
	more.visible = on
	button.text = "Подробнее ▾" if on else "Подробнее ▸"
	_fit_overview_settings.call_deferred()


# ---------- титры ----------

## Кто и что сделал для игры (по файлам CREDITS/LICENSE в assets). Разделы: [заголовок, значок, [[что, кто · лицензия], …]]
const CREDITS := [
	["Игра", "laurels", [
		["CivCity — уютный римский город", "замысел, игровой дизайн и решения — Leonov Labs"],
		["Программирование, мир, жители и интерфейс", "Leonov Labs вместе с Claude (Anthropic)"]]],
	["Город и постройки", "housing", [
		["Synty Studios — POLYGON Ancient Empire", "3D-модели домов, лавок, храмов, деревьев и украшений · лицензия Synty Store"],
		["Artisau — Ancient Greece Low Poly", "статуи и мелкие предметы, шатры, слон и Минотавр в боях Легиона · CC0"]]],
	["Жители и животные", "family", [
		["Quaternius — Universal Base Characters, Modular Character Outfits", "жители города · CC0"],
		["Quaternius — Universal Animation Library", "походка, работа и отдых жителей · CC0"],
		["Quaternius — модели и анимации животных", "животные в городе и звери в боях Легиона, скелет и движения кошек · CC0"],
		["Poly by Google — «Kitten» (Poly Pizza, poly.pizza/m/dBJgGEu5bHW)", "кошки города (надета на скелет кошки Quaternius, окрасы — в игре) · CC-BY 3.0"],
		["jeremy — «Duck» (Poly Pizza)", "утки на прудах · CC-BY 3.0"],
		["Poly by Google — «Duck» (Poly Pizza)", "лебедь на прудах (перекрашен) · CC-BY 3.0"]]],
	["Музыка", "music", [
		["Записи из Викисклада и Musopen", "общественное достояние (PD) и CC0 · громкость выровнена для игры"],
		["Эрик Сати — Гимнопедия № 1", "PD"],
		["Фредерик Шопен — Ноктюрн ми-бемоль мажор, соч. 9 № 2", "CC0"],
		["Роберт Шуман — «Грёзы» из «Детских сцен»", "PD"],
		["Фредерик Шопен — Ноктюрн соль мажор, соч. 37 № 2", "исп. Ольга Гуревич · CC0"],
		["Фредерик Шопен — Вальс ля-бемоль мажор, соч. 69 № 1", "CC0"],
		["Фредерик Шопен — Ноктюрн ми минор, соч. 72 № 1", "CC0"],
		["Роберт Шуман — «О чужих странах и людях»", "PD"],
		["Фредерик Шопен — Ноктюрн фа-диез мажор, соч. 15 № 2", "CC0"],
		["Фредерик Шопен — Вальс ля минор", "PD"],
		["Роберт Шуман — «Поэт говорит»", "PD"],
		["Эдвард Григ — «Утро» из сюиты «Пер Гюнт»", "Musopen Symphony · PD"],
		["Иоганн Себастьян Бах — Ария", "Air Force Strings, оркестр ВВС США · PD"],
		["Антонио Вивальди — Концерт для двух мандолин, RV 532, Анданте", "The Modena Chamber Orchestra · PD"],
		["Анонимный романс (Jeux interdits)", "Джим Гринингер, гитара · CC0"],
		["Йозеф Гайдн — Квартет «Жаворонок», Адажио", "Musopen String Quartet · PD"],
		["Иоганн Пахельбель — Канон", "Strolling Strings, оркестр ВВС США · PD"],
		["Клод Дебюсси — «Священный танец»", "камерный оркестр морской пехоты США, арфа — Карен Гримзи · PD"],
		["Томазо Альбинони — Концерт для гобоя ре минор, Адажио", "Пол Арден-Тейлор, гобой · CC0"],
		["Георг Фридрих Гендель — «Музыка на воде», Менуэт", "камерный оркестр морской пехоты США · PD"],
		["Иоганн Себастьян Бах — Гольдберг-вариации, Ария", "Кимико Исидзака · CC0"],
		["Вольфганг Амадей Моцарт — Серенада «Гран партита», Адажио", "оркестр морской пехоты США · PD"],
		["Антонио Вивальди — «Зима», Ларго", "The Modena Chamber Orchestra · PD"],
		["Александр Бородин — Квартет № 2, Ноктюрн", "Musopen String Quartet · PD"],
		["Феликс Мендельсон — «Итальянская» симфония, Анданте", "Musopen Symphony · PD"],
		["Георг Фридрих Гендель — «Гармоничный кузнец»", "Musopen, клавесин · CC0"],
		["Антонин Дворжак — Квартет № 10, Романс", "Musopen String Quartet · PD"],
		["Людвиг ван Бетховен — «Патетическая» соната, Адажио", "Musopen · CC0"]]],
	["Звуки", "sound", [
		["Kenney — Interface Sounds, RPG Audio, UI Audio", "щелчки, стройка, монеты, звуки боя · CC0 · kenney.nl"],
		["Higgsfield — нейросеть Mirelo", "звон мечей, залп стрел, удар камня, клич · созданы для CivCity"],
		["Kerzoven — «Cat Purr & Meow», IgnasD — «Meow»", "кошки · OpenGameArt, CC0"],
		["Gregor Quendel — «Free Crowd Cheering Sounds»", "шум и ликование трибун · OpenGameArt, CC BY 4.0"],
		["D4XX — «Single Horse Galopp» (набор congusbongus)", "топот коней в цирке · OpenGameArt, CC0"],
		["isaiah658 — «Ambient Bird Sounds»", "птицы · OpenGameArt, CC0"]]],
	["Интерфейс", "scroll", [
		["Рисованные рамки, свитки, медальоны, иконки, портреты и логотип", "нарисованы для CivCity"],
		["Часть значков инструментов", "по мотивам game-icons.net — Lorc, Delapouite · CC BY 3.0"]]],
	["Шрифты", "quill", [
		["Philosopher — Jovanny Lemonad", "SIL Open Font License 1.1"],
		["Alegreya Sans — Huerta Tipográfica", "SIL Open Font License 1.1"]]],
	["Движок", "settings", [
		["Godot Engine 4", "© Хуан Линецкий, Ариэль Манзур и участники Godot · лицензия MIT · godotengine.org"]]],
]


func _credits_panel() -> void:
	var w := _window("Титры", 680)
	credits_panel = w[0]
	var v: VBoxContainer = w[1]
	var sc := ScrollContainer.new()
	sc.name = "scroll"
	sc.custom_minimum_size = Vector2(640, 560)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(col)
	col.add_child(_pic("logo_min.png", Vector2(600, 150)))
	var tag := _label("Уютный римский город", 20, false, C_SOFT, font_title)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tag)
	var by := _label("Создано Leonov Labs", 18, true, C_INK)
	by.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(by)
	var tg := LinkButton.new()
	tg.text = "Наш канал в Telegram — t.me/leonovlabs"
	tg.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	tg.add_theme_font_override("font", font_bold)
	tg.add_theme_font_size_override("font_size", 15)
	tg.add_theme_color_override("font_color", C_SOFT)
	tg.add_theme_color_override("font_hover_color", C_INK)
	tg.focus_mode = Control.FOCUS_NONE
	tg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tg.pressed.connect(func(): OS.shell_open("https://t.me/leonovlabs"))
	col.add_child(tg)
	for sec: Array in CREDITS:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 10)
		col.add_child(gap)
		var hdr := HBoxContainer.new()
		hdr.alignment = BoxContainer.ALIGNMENT_CENTER
		hdr.add_theme_constant_override("separation", 8)
		hdr.add_child(_icon(sec[1], 30))
		hdr.add_child(_label(sec[0], 24, false, C_INK, font_title))
		col.add_child(hdr)
		col.add_child(_divider(14))
		for it: Array in sec[2]:
			var a := _wrap(_label(it[0], 17, true, C_INK), 600)
			a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(a)
			var bl := _wrap(_label(it[1], 14, false, C_SOFT), 600)
			bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(bl)
			var sp := Control.new()
			sp.custom_minimum_size = Vector2(0, 3)
			col.add_child(sp)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 18)
	col.add_child(gap2)
	var thanks := _label("Спасибо, что играете!", 26, false, C_INK, font_title)
	thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(thanks)
	var gap3 := Control.new()
	gap3.custom_minimum_size = Vector2(0, 30)
	col.add_child(gap3)
	# игрок крутит колёсико (на Mac — ведёт двумя пальцами) или тянет полосу — титры больше не плывут сами
	var stop := func(e: InputEvent):
		if (e is InputEventMouseButton or e is InputEventPanGesture) and credits_panel.has_meta("roll"):
			(credits_panel.get_meta("roll") as Tween).kill()
			credits_panel.remove_meta("roll")
	sc.gui_input.connect(stop)
	sc.get_v_scroll_bar().gui_input.connect(stop)


## Титры: окно посреди экрана, через пару секунд текст медленно плывёт вверх (как в кино)
func open_credits() -> void:
	_toggle(credits_panel)
	if not credits_panel.visible:
		return
	var sc: ScrollContainer = credits_panel.find_child("scroll", true, false)
	sc.scroll_vertical = 0
	if credits_panel.has_meta("roll"):
		(credits_panel.get_meta("roll") as Tween).kill()
	await get_tree().process_frame
	var bar := sc.get_v_scroll_bar()
	var top := maxf(0.0, bar.max_value - bar.page)
	if top <= 0.0 or not credits_panel.visible:
		return
	var tw := sc.create_tween()
	tw.tween_interval(2.5)
	tw.tween_method(func(y: float): sc.scroll_vertical = int(y), 0.0, top, top / 28.0)
	credits_panel.set_meta("roll", tw)


## Кнопки «RU | EN»: выбранная подсвечена; нажали другую — язык меняется сразу (город сохранится и откроется заново)
func _lang_buttons() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.name = "lang_row"
	for l: String in ["ru", "en"]:
		var b := Button.new()
		b.text = l.to_upper()
		b.name = "lang_" + l
		b.custom_minimum_size = Vector2(64, 38)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_font_override("font", font_bold)
		b.tooltip_text = String(I18n.LANGS[l])
		b.set_meta("lang", l)
		b.pressed.connect(_set_lang.bind(l))
		h.add_child(b)
	_lang_restyle(h)
	return h


func _lang_restyle(h: Node) -> void:
	for b in h.get_children():
		var on: bool = String(b.get_meta("lang")) == I18n.lang
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			if on:
				(b as Button).add_theme_stylebox_override(st, _box_pill(14, 5, "g_btn_on"))
			else:
				(b as Button).remove_theme_stylebox_override(st)
		(b as Button).add_theme_color_override("font_color", C_GOOD if on else C_INK)
		(b as Button).add_theme_color_override("font_hover_color", C_GOOD if on else C_INK)


## Сменить язык: настройка в файл, город сохраняется, игра открывается заново на новом языке
func _set_lang(l: String) -> void:
	if l == I18n.lang:
		return
	game.settings["lang"] = l
	game.save_settings()
	game.restart("menu" if game.mode == "menu" else ("play" if game.mode in ["play", "new"] else String(game.mode)))


func _open_settings(stay := false) -> void:
	_settings_more_refresh()
	var adv := settings_panel.find_child("adv", true, false) as CheckBox
	if adv != null:
		adv.set_pressed_no_signal(advisor_on())
	var lrow := settings_panel.find_child("lang_row", true, false)
	if lrow != null:
		_lang_restyle(lrow)
	(settings_panel.find_child("fs", true, false) as CheckBox).set_pressed_no_signal(bool(game.settings["fullscreen"]))
	(settings_panel.find_child("auto", true, false) as CheckBox).set_pressed_no_signal(bool(game.settings["autosave"]))
	_ui_slider_fit()
	for key in ["music", "sfx", "ui_scale"]:
		(settings_panel.find_child(key, true, false) as HSlider).set_value_no_signal(float(game.settings.get(key, 1.0)))
	Gfx.settings_refresh(self)
	AccountUi.settings_refresh(self)
	if not stay:
		_toggle(settings_panel)


func _buy_panel() -> void:
	var w := _window("Новая земля", 460)
	buy_panel = w[0]
	var v: VBoxContainer = w[1]
	var l := _label("", 18)
	l.name = "text"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(410, 0)
	v.add_child(l)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 10)
	var ok := Button.new()
	ok.name = "ok"
	ok.text = "Купить"
	ok.icon = ico("coins", 32)
	ok.pressed.connect(func():
		if game.city.buy_plot(buy_plot):
			game._update_plot_signs()
			buy_panel.visible = false
		else:
			ask_buy(buy_plot))                    # не купили — почему, пишем тут же (без всплывашек)
	h.add_child(ok)
	var no := Button.new()
	no.text = "Не сейчас"
	no.pressed.connect(func(): buy_panel.visible = false)
	h.add_child(no)
	v.add_child(h)


## Окно покупки участка. Цена выше предела казны — так и пишем (какой уровень или исследование поможет), «Купить» гаснет;
## просто мало денариев — сколько в казне сейчас
func ask_buy(p: Vector2i) -> void:
	buy_plot = p
	var c: City = game.city
	var price := c.plot_price()
	var t := "Участок 64 × 64 м за краем вашей земли. Купить его за %s денариев? На нём можно будет строить. Каждый следующий участок — дороже." % fmt(price)
	var over := float(price) > c.money_cap()
	if over:
		t += "\n\n" + plot_cap_note()
	elif c.money < float(price):
		t += "\n\nВ казне пока %s ден. — накопите ещё %s." % [fmt(c.money), fmt(ceilf(float(price) - c.money))]
	(buy_panel.find_child("text", true, false) as Label).text = t
	(buy_panel.find_child("ok", true, false) as Button).disabled = over
	buy_panel.visible = true


## Участок дороже, чем вмещает казна: на каком уровне города он станет по карману (или с «Новым хранилищем денег»)
func plot_cap_note() -> String:
	var c: City = game.city
	var price := float(c.plot_price())
	var t := "Сейчас казна вмещает только %s ден. — столько не скопить." % fmt(c.money_cap())
	var lv := ""
	for l in range(c.level + 1, Defs.LEVELS.size()):
		if c.money_cap_for(l) >= price:
			lv = Defs.LEVELS[l]["name"]
			break
	# хранилище, которое можно изучить уже сейчас (вдвое больше казна) — если его хватит
	var vault := ""
	for id in ["vault1", "vault2"]:
		var r := Defs.research(id)
		if c.research.has(id):
			continue
		if c.level >= int(r["lvl"]) and (not r.has("after") or c.research.has(r["after"])) and c.money_cap() * 2.0 >= price:
			vault = r["name"]
		break
	if lv != "":
		t += " Участок станет по карману на уровне «%s»" % lv + (" или когда изучите «%s»." % vault if vault != "" else ".")
	elif vault != "":
		t += " Изучите «%s» — казна станет вдвое больше." % vault
	return t


# ---------- обновление ----------

func refresh() -> void:
	if game == null or game.city == null:
		return
	var c: City = game.city
	lbl_level.text = Defs.LEVELS[c.level]["name"]          # подсказка — мгновенная, _tip_level
	lbl_pop.text = fmt(c.stats["pop"])
	lbl_happy.text = "%d%%" % int(c.stats["happy"])
	if renown_pill != null:
		_renown_on = Renown.on(c) and city_card != null and city_card.visible   # прячется вместе с полосой; видна, если хватает места (_fit_top)
		lbl_renown.text = "%s · %s" % [Renown.title_of(c.renown), fmt(int(c.renown))]
		if c.fest_left > 0 and c.cal_fest_id != "":
			lbl_renown.text += " · " + Renown.cal_fest_name(c.cal_fest_id)
	lbl_day.text = "День %d" % (c.day + 1)
	if Renown.on(c):
		lbl_day.text += " · " + Seasons.name_of(c.day)
	show_city_name()
	lbl_money.text = fmt(c.money)
	lbl_money.tooltip_text = I18n.t("Денарии в казне") + ": %s / %s" % [fmt(c.money), fmt(c.money_cap())]
	var net := c.projected_net()
	lbl_income.text = ("+" if net >= 0 else "") + fmt(net) + "/ч"
	lbl_income.tooltip_text = "Ожидаемый доход за час при нынешних жильцах и работниках. Прошедшие часы — в «Финансах»"
	lbl_income.add_theme_color_override("font_color", C_GOOD if net >= 0 else C_BAD)
	# сверх полок (вернули очки) — честно «сверх полок», а не «4160 / 3200»
	lbl_rp.text = ("%s+" % fmt(c.rp)) if c.rp > c.rp_cap() + 0.5 else "%s / %s" % [fmt(c.rp), fmt(c.rp_cap())]     # «999 999+» — сверх полок (в подсказке — подробно)
	lbl_rp.tooltip_text = rp_tip()
	lbl_rp_day.text = "+%.1f" % float(c.stats.get("rp_day", 0.0)) if float(c.stats.get("rp_day", 0.0)) > 0.0 else ""
	for sb in speed_btns:
		_set_on(sb[0], is_equal_approx(game.speed, sb[1]))
	_update_full_marks()
	_update_rank_ui()
	_update_floor_btn()
	_update_upg_btn()
	var ub := road_panel.find_child("upgrade_box", true, false) if road_panel else null
	if ub:
		ub.visible = c.research.has(Defs.ROAD_UP_RES)    # кисть «Улучшить» — после «Базальтовой мостовой» (этап 5.7)
	update_new_marks()
	_sync_build_menu()
	_sync_military_tab()
	_fit_bottom()                             # «Полки полны» — правая полоса шире
	_fill_classes()
	_fit_top()
	_fill_families()
	_fill_tasks()
	_once_tips()
	if tray.visible:
		_update_cards()
	if info_panel.visible and not PersonCard.editing(info_p):     # открыт «Гардероб» / «Внешность» — не пересобираем («Сейчас» живёт сам)
		_fill_info()
	if research_panel.visible:
		_research_head()
		research_tree.refresh()
	if overview_panel.visible:
		_refresh_overview()
	_update_world_icons()
	game._update_noroad_marks()
	_update_pointer()
	if hover_src:
		_fill_hover()                       # числа в открытой подсказке живые


## Заголовок окна исследований: очки / полки и «+N в час»
func _research_head() -> void:
	var c: City = game.city
	lbl_research_rp.text = ("%s (сверх полок)" % fmt(c.rp)) if c.rp > c.rp_cap() + 0.5 else "%s / %s" % [fmt(c.rp), fmt(c.rp_cap())]
	var ph := float(c.stats.get("rp_day", 0.0))
	lbl_research_rate.text = "+%s в час" % fmt_rate(ph)
	lbl_research_rp.get_parent().set("tooltip_text", rp_tip())


## «13,5» — прибавка в час с одной цифрой после запятой (целые — без неё)
static func fmt_rate(v: float) -> String:
	return str(roundi(v)) if is_equal_approx(v, roundf(v)) or v >= 100.0 else String.num(v, 1).replace(".", ",")


## Через сколько хватит очков на исследование ценой cost: «~2 мин» — по нынешней прибавке в час и скорости игры
## (1 игровой час — Game.DAY_LEN / 24 с при ×1); "" — уже хватает, прибавки нет или дороже полок
func rp_eta(cost: float) -> String:
	var c: City = game.city
	var ph := float(c.stats.get("rp_day", 0.0))
	var need := cost - c.rp
	if need <= 0.0 or ph <= 0.0 or cost > c.rp_cap():
		return ""
	var sec := need / ph * (Game.DAY_LEN / 24.0) / maxf(1.0, float(game.speed))
	var m := ceili(sec / 60.0)
	if m >= 60:
		return "~%d ч %d мин" % [m / 60, m % 60]
	return "~%d мин" % maxi(1, m)


## Подсказка у счётчика свитков: сколько и откуда очки в час (почта, скриптории, школы…)
func rp_tip() -> String:
	var c: City = game.city
	var t := "Очки исследований: %s, на полках помещается %s." % [fmt(c.rp), fmt(c.rp_cap())]
	if c.rp > c.rp_cap() + 0.5:
		t += " Сверх полок — возвращённые очки: их можно тратить, но новые не копятся, пока не станет меньше."
	var src: Dictionary = c.rp_sources()
	var bits := []
	if float(src.get("post", 0.0)) > 0.0:
		bits.append("почта на станции +%s" % fmt_rate(float(src["post"])))
	for tp in ["scriptorium", "school", "library", "academy"]:
		if float(src.get(tp, 0.0)) > 0.0:
			var nm := String(Defs.B[tp].get("gen", tp))
			bits.append("%s +%s" % [nm.left(1).to_upper() + nm.substr(1) if bits.is_empty() else nm, fmt_rate(float(src[tp]))])
	if not bits.is_empty():
		t += "\nВ час: +%s — %s." % [fmt_rate(float(c.stats.get("rp_day", 0.0))), ", ".join(bits)]
	t += "\nПолки растут с уровнем города и исследованием «Новые полки для свитков»."
	return t


## «+25» летит от свитка просьб к счётчику очков (просьба выполнена) — тихо, без звука и всплывашки
func _fly_rp(n: int) -> void:
	if n <= 0 or lbl_rp == null or not lbl_rp.is_visible_in_tree() or game == null or not (game.mode in ["new", "play"]):
		return
	var l := _label("+%d" % n, 20, true, C_GOOD)
	l.add_theme_color_override("font_outline_color", Color("fff4dc"))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	var to := lbl_rp.global_position - root.global_position
	l.position = to + Vector2(-60, -70)
	var tw := l.create_tween()
	tw.tween_property(l, "position", to + Vector2(4, -4), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.75)
	tw.tween_callback(l.queue_free)


## «Казна полна»: сколько домов готовы к перестройке и во что она встанет — «готовы 3 дома на 3 600 ден.» ("" — ни одного)
func _upg_spend() -> String:
	var c: City = game.city
	if not c.research.has("artisans"):
		return ""
	var ups: Array = c.upgrade_ready(false)
	if ups.is_empty():
		return ""
	var sum := 0
	for id in ups:
		sum += c.upgrade_price(c.buildings[id])
	return "%s %d %s на %s ден." % [_plural(ups.size(), "готов", "готовы", "готовы"), ups.size(), _plural(ups.size(), "дом", "дома", "домов"), fmt(sum)]


## «Казна полна — доход пропадает» / «Полки полны — очки пропадают»: казна или полки у предела, а прибавка есть
func _update_full_marks() -> void:
	var c: City = game.city
	var play: bool = not (game.mode in ["demo", "menu"])
	var net := float(c.stats.get("income", 0.0)) - float(c.stats.get("upkeep", 0.0)) - float(c.stats.get("legion_denarii", 0.0))
	var m_on := play and c.money >= c.money_cap() - 0.5 and net > 0.0
	var r_on := play and c.rp >= c.rp_cap() - 0.05 and float(c.stats.get("rp_day", 0.0)) > 0.0
	# прошлый час не плачен и денариев так и нет (обида, что ещё держится после, — только в карточках домов)
	var e_on := play and c.unpaid_h == Defs.UNPAID_H and c.money < 0.5
	if empty_money.visible != e_on:
		empty_money.visible = e_on                # казна пуста: жалованье не плачено — красным над казной
		lbl_money.add_theme_color_override("font_color", C_BAD if e_on else C_INK)
		_snug(empty_money.get_parent().get_parent() as Control)
	if full_money.visible != m_on or full_rp.visible != r_on:
		full_money.visible = m_on
		full_rp.visible = r_on
		var r1 := Defs.research("research1")
		full_rp.tooltip_text = "Очков исследований столько, сколько вмещают полки, — новые пропадают. Изучите что-нибудь в свитке исследований вверху справа." \
			+ (("\nИли изучите «%s» — полки вместят вдвое больше." % r1["name"]) if not c.research.has("research1") and c.level >= int(r1["lvl"]) else "")
		# куда пустить денарии: игры — когда открыты, участки — когда следующий не дороже предела казны
		var ways := "дома, этажи, лавки, памятники, украшения"
		var upg := _upg_spend()
		if upg != "":
			ways += ", перестройка домов (%s)" % upg.trim_suffix(".")
		if c.fest_open():
			ways += ", игры в честь богов (в карточке почтовой станции)"
		if _plot_fits():
			ways += ", новые участки земли"
		full_money.tooltip_text = "Казна заполнена до предела — новые денарии пропадают. Потратьте их: %s. Предел растёт с уровнем города и исследованиями хранилищ." % ways
		_snug(full_money.get_parent().get_parent() as Control)


## Кнопка «Этаж»: до «Второго жилого этажа» серая (в подсказке — чем откроется); потом число — сколько домов готовы
## к этажу (полные и счастливые; денариев может и не хватать — тогда над домом красная цена)
func _update_floor_btn() -> void:
	var c: City = game.city
	var fb: Button = tool_btns["floor"]
	var open := c.research.has("floor2")
	var n: int = c.floor_ready(false).size() if open and game.mode in ["new", "play"] else 0
	var txt := str(n) if n > 0 else ""
	if floor_badge.text != txt:
		floor_badge.text = txt
	var tip := FLOOR_TIP + ("\nГотовы к этажу сейчас: %d" % n if open else "")
	if not open:
		tip = "Этаж (U): надстроить этаж полному дому, где жителям хорошо. Откроется исследованием «%s» (уровень «%s»)" % [
			Defs.research("floor2")["name"], Defs.LEVELS[int(Defs.research("floor2")["lvl"])]["name"]]
	if fb.tooltip_text != tip:
		fb.tooltip_text = tip
	if game.tool == "floor" and tool_panel.visible:
		_fill_tool_panel()                    # «готовы домов: N» — живое
	if bool(fb.get_meta("open", true)) != open or not fb.has_meta("open"):
		fb.set_meta("open", open)
		_grey(fb.get_node("ic"), not open)
		(fb.get_node("up") as CanvasItem).modulate = Color.WHITE if open else Color(0.62, 0.6, 0.56, 0.75)


## Кнопка «Перестроить» (Д12): до «Класса ремесленников» серая (в подсказке — чем откроется); потом число — сколько
## домов готовы стать следующим классом (денариев может и не хватать — тогда над домом красная цена)
func _update_upg_btn() -> void:
	var c: City = game.city
	var ub: Button = tool_btns["upgrade"]
	var open := c.research.has("artisans")
	var n: int = c.upgrade_ready(false).size() if open and game.mode in ["new", "play"] else 0
	var txt := str(n) if n > 0 else ""
	if upg_badge.text != txt:
		upg_badge.text = txt
	var tip := UPG_TIP + ("\nГотовы к перестройке сейчас: %d" % n if open else "")
	if not open:
		tip = "Перестроить (Shift+U): дом плебеев — в дом ремесленников, потом — в городской домус. Откроется исследованием «%s» (уровень «%s»)" % [
			Defs.research("artisans")["name"], Defs.LEVELS[int(Defs.research("artisans")["lvl"])]["name"]]
	if ub.tooltip_text != tip:
		ub.tooltip_text = tip
	if game.tool == "upgrade" and tool_panel.visible:
		_fill_tool_panel()                    # «готовы домов: N» — живое
	if bool(ub.get_meta("open", true)) != open or not ub.has_meta("open"):
		ub.set_meta("open", open)
		_grey(ub.get_node("ic"), not open)
		(ub.get_node("up") as CanvasItem).modulate = Color.WHITE if open else Color(0.62, 0.6, 0.56, 0.75)


## Советник один раз (tips.upgrade_tool): дома растут в следующий класс только по щелчку игрока
func upgrade_tip(by_player := false) -> void:
	var c: City = game.city
	if c.tips.has("upgrade_tool") or not c.research.has("artisans") or not _tip_free(not by_player):
		return
	c.tips["upgrade_tool"] = true
	advisor("Перестроить дом", "Выберите «Перестроить» и щёлкните по дому — его класс станет выше.\nНужны исследование, денарии и место; недостающие нужды появятся в карточке.", Callable(), by_player)


## Советник один раз (tips.floor_tool): этажи — инструментом «Этаж», без карточки каждого дома
func floor_tip(by_player := false) -> void:
	var c: City = game.city
	if c.tips.has("floor_tool") or not c.research.has("floor2") or not _tip_free(not by_player):
		return
	c.tips["floor_tool"] = true
	advisor("Этаж — без карточки дома", "Нажмите «Этаж» справа внизу или клавишу U. Для нескольких домов ведите мышью с зажатой кнопкой вдоль улицы — этаж получат готовые дома, пока хватает денариев.", Callable(), by_player)


## Следующий участок земли по карману: продаётся (есть табличка) и не дороже предела казны
func _plot_fits() -> bool:
	var c: City = game.city
	return float(c.plot_price()) <= c.money_cap() and not game.plot_signs.is_empty()


## Можно ли сейчас показать совет советника (один раз на механику): своя игра, обучение кончилось,
## советник и ролик свободны. gap = false — совет по действию игрока (взял инструмент, открыл «Обзор»): без паузы
func _tip_free(gap := true) -> bool:
	if game == null or not (game.mode in ["new", "play"]) or game.shot_path != "" or not visible or not root.visible:
		return false
	if tutorial_busy():
		return false
	if advisor_panel.visible or (not _guidance_playing and notes_box.get_child_count() > 0):
		return false
	if gap and (tip_gap or game == get_tree().current_scene) and Time.get_ticks_msec() < _tip_next:
		return false                          # только что закрыли совет — дадим осмотреться
	var rc = game.get("rank_cine")
	return rc == null or (rc.cine.is_empty() and rc.pending.is_empty())


## Каких работников («Плебеев», «Ремесленников») заметно меньше, чем мест, и мест этого класса не в одной постройке; "" — хватает
func _hire_short() -> String:
	var c: City = game.city
	var ratio: Dictionary = c.stats.get("ratio", {})
	for cl in Defs.CLASS_ORDER:
		if float(ratio.get(cl, 1.0)) >= 0.75:
			continue
		var n := 0
		for id in c.buildings:
			var b: Dictionary = c.buildings[id]
			if not c.is_house(b) and int(c.jobs_of(b).get(cl, 0)) > 0:
				n += 1
		if n >= 3:
			return String({"plebs": "Плебеев", "artisans": "Ремесленников", "patricians": "Патрициев"}.get(cl, ""))
	return ""


## Советы один раз: город готов к новому уровню; казна полна; полки полны
func _once_tips() -> void:
	var c: City = game.city
	if not _tip_free():
		return
	if _want_advice():
		return
	if not c.tips.has("unhappy_penalty"):
		for h: Dictionary in c.buildings.values():
			if c.is_house(h) and c.unhappy_badge(h):
				c.tips["unhappy_penalty"] = true
				advisor("Когда дома неуютно", "Ниже 40% счастья жители работают и платят налоги вполовину.\nЕсли счастье ниже 25% двое суток, одна семья переедет.", Callable(), true)
				return
	if c.unpaid_h > 0 and not c.tips.has("unpaid_tip"):
		c.tips["unpaid_tip"] = true
		advisor("Казна пуста", unpaid_advice())   # казна в минус не уходит: один раз — что случилось и как поправить
		return
	if _manual_hire_advice():
		return
	if c.tips.has("arrive_wait") and String(c.stats.get("arrive_block", "")) != "":
		_arrive_advice()                      # «Новые семьи не едут» ждал, пока закроют другой совет; повозка уже едет — подождёт, пока встанет снова
		return
	if rank_btn.visible and not c.tips.has("rank_tip"):
		c.tips["rank_tip"] = true
		var nx := c.next_level()
		advisor("Город готов к новому уровню!", "Все условия для уровня «%s» выполнены. Город сам не растёт: нажмите кнопку «Перейти на новый уровень» под табличкой города (или в карточке почтовой станции) — когда сами захотите.\n\nНовый уровень откроет новые исследования, казна станет вместительнее. Условия следующего уровня всегда видно, если навести мышь на уровень города." % nx.get("name", ""))
		return
	if c.fest_open() and int(c.stats.get("pop", 0)) > 0 and not c.tips.has("fest_tip"):
		c.tips["fest_tip"] = true
		advisor("Игры в честь богов", fest_note())
		return
	if c.research.has("floor2") and not c.tips.has("floor_tool") and not research_panel.visible:
		floor_tip()                           # изучили второй этаж (или старый город после обновления) — один раз про «Этаж»
		return
	if c.research.has("artisans") and not c.tips.has("upgrade_tool") and not research_panel.visible and not c.upgrade_ready(false).is_empty():
		upgrade_tip()                         # первый дом готов стать следующим классом (или старый город после обновления) — про «Перестроить»
		return
	if c.tips.has("cat_item_first") and not c.tips.has("cat_item_tip"):
		c.tips["cat_item_tip"] = true
		advisor("Обновка для кошки", "Хозяева кошки купили ей вещицу в «Кошачьей лавке» — теперь она так и гуляет по городу! Хозяева кошек из домов поблизости от лавки иногда покупают им шляпки, бантики, ошейники с колокольчиком и банданы.\n\nЩёлкните по кошке на улице: в её карточке видны её вещи — можно надеть другую или выбрать ей обновку из лавки самим.")
		return
	if full_money.visible and not c.tips.has("full_money"):
		c.tips["full_money"] = true
		var fest := " Или устройте игры в честь богов — в карточке почтовой станции." if c.fest_open() else ""
		# участки — только когда следующий по карману (дороже предела казны его не купить)
		var land := ", участки земли за краем своей" if _plot_fits() else ""
		var vault := " и изучите «%s»" % Defs.research("vault1")["name"] if not c.research.has("vault1") else ""
		var upg := _upg_spend()
		var upg_t := (" К перестройке %s — инструмент «Перестроить» (Shift+U)." % upg.trim_suffix(".")) if upg != "" else ""
		advisor("Казна полна", "Казна заполнена до предела — новые денарии пропадают. Пустите их в дело: новые дома и этажи, лавки, украшения и памятники%s.%s%s Чтобы казна вмещала больше, поднимайте уровень города%s." % [land, fest, upg_t, vault])
		return
	if full_rp.visible and not c.tips.has("full_rp"):
		c.tips["full_rp"] = true
		advisor("Полки полны", "Очков исследований столько, сколько вмещают полки, — новые пропадают. Изучите что-нибудь в свитке исследований вверху справа. Полки вырастут на новом уровне города и с исследованием «Новые полки для свитков».")
		return
	# советы экономики v2 — когда на экране нет окон (Esc закрыл бы совет вместе с окном)
	if not _screen_free():
		return
	# свой герой (Д11): один раз — кто он, где живёт, как его найти и переодеть (экран «Ваш герой» уже закрыт)
	# (в автопроверках, где экран сам не открывается, — и совета нет: их советы не перебиваются)
	if Hero.exists(c) and not c.tips.has("hero_tip") and bool(game.get("hero_offer_done")) and bool(game.get("hero_screen_auto")) 			and not HeroScreen.is_open(game) and game.people != null and not game.people.hero_r.is_empty():
		c.tips["hero_tip"] = true
		advisor("%s — ваш герой" % Hero.name_of(c), hero_note())
		return
	# «Хутор»: дом готов к этажу, а денариев не хватает — один раз: налоги подойдут (этап 2.3, денег впритык)
	# С инструментом в руках совет ждёт: окно перекрыло бы улицу и забрало мазок.
	if game.tool == "" and not game.floor_drag and c.level == 1 and c.research.has("floor2") and not c.tips.has("floor_money") and c.tips.has("floor_tool"):
		var ready: Array = c.floor_ready(false)
		if not ready.is_empty() and c.money < float(c.floor_price(c.buildings[ready[0]])):
			c.tips["floor_money"] = true
			advisor("На этаж пока не хватает", "Дом готов к новому этажу, но этаж стоит %s денариев, а в казне меньше. Не беда: налоги приходят каждый час — подождите немного, и денариев хватит. На «Хуторе» денег впритык; щедрые награды за просьбы — с «Деревни»." % fmt(c.floor_price(c.buildings[ready[0]])))
			return
	# налоги по классам открылись (с «Деревни») — один раз
	if c.tax_open() and not c.tips.has("tax_tip") and int(c.stats.get("pop", 0)) > 0:
		c.tips["tax_tip"] = true
		advisor("Налоги по классам", "Теперь налоги можно настроить для каждого класса — в «Обзоре города» → «Деньги». Мягкие: налог ×0,8, зато дома этого класса на 5% счастливее. Высокие: налог ×1,3, но счастье −8%. Счастье выше 100% — запас: дом с запасом платит высокий налог, ничуть не грустнея.\n\nОкно предупредит, если высокие налоги опустят счастье города ниже, чем нужно для следующего уровня.")
		return
	# новая игра: повтор лавки того же вида и одинаковые украшения рядом дают меньше — один раз, когда это впервые случилось
	if c.econ >= 1 and bool(c.stats.get("dim_any", false)) and not c.tips.has("dim_tip"):
		c.tips["dim_tip"] = true
		advisor("Разнообразие радует больше", "Лавки одного вида рядом с домом складываются не целиком: вторая лавка с едой даёт половину своей радости, третья — четверть. А вот лавка другого вида — одежда, развлечения, услуги — снова целиком. С украшениями так же: второе такое же рядом — 60%, третье — 30%, а разные — целиком.\n\nИз чего складывается счастье дома, видно в его карточке.")
		return
	# этап 5: наборы украшений (новая игра) и «главные» украшения — один раз, когда открылись
	if c.econ >= 1 and not c.tips.has("set_tip") and Defs.DECOR_SETS.any(func(s): return c.research.has(s)):
		c.tips["set_tip"] = true
		advisor("Наборы украшений", "Украшения из одного исследования — это набор: «Сельский двор», «Вода в саду», «Сад»… Поставьте рядом с домом три разных вида из одного набора — дом станет счастливее ещё на %d%%, даже если украшений у него уже вдоволь.\n\nК какому набору относится украшение — видно в подсказке на его карточке. В меню украшений есть «★ Избранное», «Недавние» и поиск." % Defs.SET_BONUS)
		return
	if not c.tips.has("pave_up_tip") and c.research.has(Defs.ROAD_UP_RES):
		c.tips["pave_up_tip"] = true
		advisor("Улучшенные улицы", "Слева внизу появилась кисть «Улучшить». Проведите ею по улице: тропа станет мостовой, мостовая — дорогой из больших каменных плит, площадь — травертином с мозаикой.\n\nПо плитам горожане ходят быстрее, а дом, у входа которого улица ухоженная, счастливее на %d%%. Платить — только за то, что улучшили." % Defs.STREET_BONUS)
		return
	if not c.tips.has("prem_tip") and ["prem_patrician", "prem_mosaic", "prem_triumph", "prem_eternal"].any(func(s): return c.research.has(s)):
		c.tips["prem_tip"] = true
		advisor("Главные украшения", "Во вкладке «Главные» — дорогие украшения: экседра, бассейн, мозаики, обелиск… Каждое радует дома вокруг себя, как маленький памятник, — сверх того, что дают обычные украшения. Хорошее дело для полной казны.")
		return
	# название: сервер дал городу имя сам (игрок его ещё не выбирал) — один раз, когда на экране ничего не открыто;
	# rename — сервер уже умеет менять название (старый сервер его не шлёт: совет не тратим на смену, которая не выйдет)
	var me: Dictionary = LegionNet.me().me_state
	if not c.tips.has("name_tip") and not me.is_empty() and bool(me.get("rename", false)) and not bool(me.get("custom", true)) and _screen_free():
		c.tips["name_tip"] = true
		advisor("Как назовём город?", "Дайте городу имя — щёлкните по табличке с названием вверху слева. Это имя увидят соперники и таблица лучших городов.")
		return
	# «Летопись города»: венки уже есть — один раз, где их смотреть (сами венки — тихо, в колокольчик); не в первые
	# минуты игры (там и так много нового) — с «Хутора»
	if Chronicle.any(c) and not c.tips.has("chron_tip") and c.chron_on and c.level >= 1:
		c.tips["chron_tip"] = true
		var nb := Chronicle.count(c)
		var first := ""
		for id in c.chron["b"]:
			first = String(Chronicle.badge(String(id)).get("name", ""))
		var got := ("Город заслужил лавровый венок «%s»!" % first) if nb == 1 else ("Город заслужил уже %d %s!" % [nb, _plural(nb, "лавровый венок", "лавровых венка", "лавровых венков")])
		advisor("Летопись города", got + " Венки даются за вехи: сто горожан, первую победу Легиона, полсотни украшений, сто дней городу… Все награды сохранены в летописи.\n\nВсе венки и счётчики города — в журнале: свиток «Просьбы горожан» → книжка → вкладка «Летопись».")
		return
	# 6.12: работников меньше, чем мест, — один раз про «−» в карточке менее нужной постройки (как в Town to City)
	if not c.manual_hiring() and not c.tips.has("hire_tip") and int(c.stats.get("pop", 0)) >= 30 and _hire_short() != "":
		c.tips["hire_tip"] = true
		advisor("Кому работать", "%s на все рабочие места не хватает — каждая постройка их класса работает слабее. Сколько нанять, решаете вы, как в Town to City: в карточке постройки, что нужна меньше, нажмите «−» у строки «Работники» — освободившиеся люди пойдут туда, где нужнее. «+» вернёт их. А больше жителей — больше работников." % _hire_short())
		return
	# Магистратуры ждут все обычные советы и отложенные сообщения историй.
	MagisUI.advise(self)


## Советник один раз (tips.unpaid_tip), когда казна впервые не смогла заплатить жалованье: что случилось и как поправить
func unpaid_advice() -> String:
	var tax := "Поднимите налоги в «Обзоре города» → «Деньги» или уберите лишних работников кнопкой «−»." if game.city.tax_open() else "Заселяйте дома — жители платят налоги; уберите лишних работников кнопкой «−»."
	return "Жалованья и содержания построек за час набралось больше, чем есть в казне. " + tax


func unpaid_note() -> String:
	var c: City = game.city
	var tax := "поднимите налоги в «Обзоре города» → «Деньги»" if c.tax_open() else "стройте дома и заселяйте семьи — налоги платят жители"
	return "Жалованья работникам и содержания построек за час набралось больше, чем есть в казне. В долг город не живёт: казна встала на нуле, недоплаченное не плачено — и жители обижены: счастье всех домов −%d%% — и ещё %d ч после того, как казна снова сможет платить.\n\nКак поправить: %s; ставьте лавки и памятники, которые радуют дома, — счастливые платят больше; в карточках построек, где работники нужны меньше, нажмите «−» у «Работников» — меньше жалованья. Расходы видны в «Обзоре города» → «Деньги»." % [Defs.UNPAID_HAPPY, Defs.UNPAID_H - 1, tax]


## Советник один раз (tips.fest_tip), когда открылись игры в честь богов: что дают, сколько стоят, где кнопка
func fest_note() -> String:
	var c: City = game.city
	var F: Dictionary = Defs.FESTIVAL
	var often := "раз в двое суток" if int(F["cd"]) == 48 else "раз в %d ч" % int(F["cd"])
	# город давно выше «Посёлка» (старое сохранение) — «дорос до „Посёлка“» звучало бы странно
	var head := "Город дорос до уровня «%s» — теперь можно устраивать игры в честь богов." if c.level <= int(F["lvl"]) else "С уровня «%s» в городе можно устраивать игры в честь богов."
	return (head + " Целые сутки весь город празднует: счастье всех домов на %d%% выше, а повозка с семьями ходит чаще.\n\n" \
		+ "Чем больше налогов платит город, тем дороже игры: %s (сейчас — %s ден.). Устраивать их можно %s. Щёлкните по почтовой станции — кнопка «Устроить игры» в её карточке.") \
		% [Defs.LEVELS[int(F["lvl"])]["name"], int(F["happy"]), fest_rates(), fmt(c.fest_price()), often]


## Что поменялось в старом городе после обновления темпа (советник один раз, city.tips.v22_pace)
func pace_note() -> String:
	var c: City = game.city
	var t := "Аве! В городе кое-что поменялось — коротко о главном:\n\n"
	t += "• Новый уровень город больше не получает сам. Когда выполнены все условия — жители, счастье и нужные постройки, — под табличкой города появится кнопка «Перейти на новый уровень». Список условий — если навести мышь на уровень города.\n"
	t += "• Повозка везёт семьи только туда, где есть свободное место. Если мест нет, приедет одна семья «ищет жильё» — значит, пора строить. Счастливый город (от 70%) зовёт семьи чаще.\n"
	t += "• Налоги стали ниже, а жалованье работникам и содержание построек растут вместе с городом — денарии снова стоит беречь.\n"
	t += "• Школ, библиотек и академий теперь можно держать ограниченное число — по уровню города, как скрипториев."
	var oc := c.over_cap()
	if not oc.is_empty():
		var by := {}
		for id in oc:
			var nm := String(Defs.B[c.buildings[id]["type"]].get("gen", "построек"))
			by[nm] = int(by.get(nm, 0)) + 1
		var parts := []
		for nm in by:
			parts.append("%s — %d" % [nm, by[nm]])
		t += " Сверх предела у вас: %s. Они остаются на месте, но не работают и ничего не стоят, пока город не вырастет — сносить их не нужно." % ", ".join(parts)
	return t


## Событие только в колокольчик: число на значке, без всплывашки
## seen — игрок и так это видел (сам сделал; строка слилась с прежней за этот час): число на значке не растёт
func bell(_text: String, _icon := "info", seen := false, advisor_tip := false) -> void:
	if not _important_event({"text": _text, "icon": _icon, "advisor": advisor_tip}):
		return
	if overview_panel.visible and overview_tab == "events":
		_fill_events()
		return
	if seen:
		return
	bell_count += 1
	bell_badge.text = str(bell_count)


func _fill_classes() -> void:
	var hover_cls := ""                     # мышь над фишкой класса — после пересборки подсказка остаётся на новой фишке
	if hover_src and is_instance_valid(hover_src) and hover_src.has_meta("cls"):
		hover_cls = hover_src.get_meta("cls")
	_clear(class_box)
	var c: City = game.city
	for cl in Defs.CLASS_ORDER:
		var cd: Dictionary = Defs.CLASSES[cl]
		if not c.unlocked(cd["house"]) and int(c.stats["residents"].get(cl, 0)) == 0:
			continue
		# маленький значок: портрет класса и число жителей; счастье — цветом числа, остальное — по наведению (_tip_class)
		var chip := MarginContainer.new()
		chip.add_theme_constant_override("margin_left", 3)
		chip.add_theme_constant_override("margin_right", 3)
		chip.set_meta("cls", cl)
		_hover_on(chip, _tip_class.bind(cl))
		chip.set_meta("tip_anchor", city_card)
		if cl == hover_cls:
			hover_src = chip
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 3)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pic := _cls_pic(cl, 28)               # портрет класса в медальоне
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(pic)
		var hp := int(c.stats["class_happy"].get(cl, 0))
		var short := int(c.stats["jobs"].get(cl, 0)) - int(c.stats["workers"].get(cl, 0))
		var nres := int(c.stats["residents"].get(cl, 0))
		var col := C_INK
		if nres > 0 and hp < 40:
			col = C_BAD
		elif nres > 0 and hp < 60:
			col = C_GOLD
		var n := _label(fmt(nres), 16, true, col)
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(n)
		var free := int(c.stats.get("free", {}).get(cl, 0))
		var available := Button.new()
		available.name = "free_" + cl
		available.text = "+%d" % free if free > 0 else "0"
		available.flat = true
		available.add_theme_font_size_override("font_size", 14)
		available.add_theme_color_override("font_color", C_GOOD if free > 0 else C_SOFT)
		available.tooltip_text = "Свободные горожане: нанимайте их в здания кнопкой «+»"
		available.pressed.connect(_cycle_work.bind(cl))
		h.add_child(available)
		if short > 0 and not c.manual_hiring():
			var w := _label("−%d" % short, 13, true, C_BAD)       # работников не хватает
			w.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(w)
		chip.add_child(h)
		class_box.add_child(chip)
	if city_card != null:
		_snug(city_card)


func _fill_tasks() -> void:
	_clear(tasks_box)
	var c: City = game.city
	var goals := c.active_goals(3)
	var sto = game.get("stories")
	var story: bool = sto != null and (not sto.row_info().is_empty() or sto.journal_any() or Chronicle.any(c))   # история горожан — золотая строка сверху
	tasks_panel.visible = (not goals.is_empty() or story) and game.mode != "demo" and ui_level() >= 3
	if _fold_city != c:
		_fold_city = c                           # другой город (новая игра, загрузка) — счёт «✓» с нуля
		_fold_done0 = c.goals_done.size()
	if tasks_panel.visible:
		_tasks_frame(tasks_folded())
		if tasks_folded():                       # свёрнут — маленький значок-свиток со счётчиком, без рамки
			_fill_tasks_folded(goals)
		else:
			_fill_tasks_body(goals)
	# свиток пересобирается при каждом обновлении города (в большом городе на ×3 — раз в несколько секунд): кнопки
	# строк («Выслушать», «Взяться», «В бой!», части цели) срабатывают по нажатию, а не по отпусканию — иначе щелчок,
	# попавший на пересборку, пропадал (проверка 26.10)
	for b in tasks_box.find_children("*", "BaseButton", true, false):
		(b as BaseButton).action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	# свиток по содержимому: прикрепить заново уже ПОСЛЕ заполнения (иначе он сжимается до пустого и
	# просьбы вылезают за нижний валик) и ещё раз через кадр, когда перенос строк уже посчитан
	_snug(tasks_panel)
	_refit(tasks_panel)
	_place_fam()


# ---------- свиток просьб сворачивается (отзыв 17): узкая полоска «Просьбы · 3», сам не разворачивается ----------

var _fold_city: City = null
var _fold_done0 := 0                         # сколько просьб было выполнено, когда свиток свернули
var _fold_badge: Label = null                # «✓1» на свёрнутом свитке
var _fold_badge_n := 0
var _fold_glow_until := 0                    # до какого мига (мс) «✓» мягко светится


## Свиток свёрнут (настройка tasks_folded); во время обучения — всегда развёрнут
func tasks_folded() -> bool:
	if game == null or tutorial_busy():
		return false
	return bool(game.settings.get("tasks_folded", true))        # по умолчанию — маленький значок-свиток со счётчиком (отзыв 14.11)


## Свернуть / развернуть свиток просьб (запоминается в настройках) — за 0,2 с
func fold_tasks(on: bool) -> void:
	game.settings["tasks_folded"] = on
	_store_settings()
	_fold_done0 = game.city.goals_done.size()
	_fold_badge_n = 0
	_fill_tasks()
	tasks_panel.pivot_offset = Vector2(tasks_panel.size.x * 0.5, 0.0)
	tasks_panel.scale = Vector2(1.0, 0.6)
	tasks_panel.modulate.a = 0.4
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(tasks_panel, "scale", Vector2.ONE, 0.2)
	tw.tween_property(tasks_panel, "modulate:a", 1.0, 0.2)


## Настройки — в файл, без применения: окно и качество графики не трогаем (не мигает)
func _store_settings() -> void:
	if game == null:
		return
	var f := FileAccess.open(game.settings_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(game.settings))


## Рамка свитка просьб: развёрнутый — резной свиток, свёрнутый — без рамки (только значок-медальон)
func _tasks_frame(compact: bool) -> void:
	var sb: StyleBox = StyleBoxEmpty.new() if compact else tasks_panel.get_meta("frame")
	if compact:
		tasks_panel.custom_minimum_size = Vector2.ZERO
	else:
		tasks_panel.custom_minimum_size = Vector2(328, 0)
	tasks_panel.add_theme_stylebox_override("panel", sb)


## Свёрнутый свиток: маленький медальон-свиток; на нём число просьб, зелёное «✓1», если что-то выполнилось,
## золотая точка — история ждёт. Подробности — по наведению, щелчок разворачивает
func _fill_tasks_folded(goals: Array) -> void:
	var c: City = game.city
	var done := c.goals_done.size() - _fold_done0
	var b := _round("scroll", "", 46, fold_tasks.bind(false))
	b.name = "unfold"
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	var tip := I18n.t("Просьбы горожан") + ": %d" % goals.size()
	if done > 0:
		tip += "\n" + I18n.t("Выполнено, пока свиток свёрнут") + ": %d" % done
	b.tooltip_text = tip + "\n" + I18n.t("Щёлкните — развернуть")
	var cnt := _label(str(goals.size()), 15, true, C_CREAM)
	cnt.add_theme_color_override("font_outline_color", C_BAD)
	cnt.add_theme_constant_override("outline_size", 9)
	cnt.position = Vector2(33, -5)
	cnt.name = "count"
	b.add_child(cnt)
	_fold_badge = null
	if done > 0:
		var bd := _label("✓%d" % done, 15, true, C_CREAM)
		bd.add_theme_color_override("font_outline_color", C_GOOD)
		bd.add_theme_constant_override("outline_size", 8)
		bd.position = Vector2(30, 28)
		b.add_child(bd)
		_fold_badge = bd
		if done > _fold_badge_n:
			_fold_glow_until = Time.get_ticks_msec() + 2000    # новое — мягко светится 2 с
	_fold_badge_n = done
	var sto = game.get("stories")
	if sto != null and not sto.row_info().is_empty():
		var dot := GoldDot.new()                 # история горожан ждёт
		dot.name = "story_dot"
		dot.custom_minimum_size = Vector2(14, 14)
		dot.size = Vector2(14, 14)
		dot.position = Vector2(-3, -3)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(dot)
	tasks_box.add_child(b)


## Кнопка со стрелкой-шевроном в медальоне: свернуть (▴) / развернуть (▾)
func _chevron_btn(down: bool, tip: String, size: int, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	var e := StyleBoxEmpty.new()
	for st in ["normal", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, e)
	b.add_theme_stylebox_override("hover", _medal("medal_hover", size))
	var ch := Chevron.new()
	ch.down = down
	ch.set_anchors_preset(Control.PRESET_FULL_RECT)
	ch.offset_left = size * 0.16
	ch.offset_right = -size * 0.16
	ch.offset_top = size * 0.16
	ch.offset_bottom = -size * 0.16
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ch)
	b.pressed.connect(cb)
	return b


## Шеврон, нарисованный кодом: золотой с тёмной каймой, как стрелка «Этажа»
class Chevron extends Control:
	var down := false

	func _draw() -> void:
		var ys := [0.68, 0.32, 0.68] if not down else [0.34, 0.7, 0.34]
		var pts := PackedVector2Array([Vector2(0.14, ys[0]) * size, Vector2(0.5, ys[1]) * size, Vector2(0.86, ys[2]) * size])
		var w := maxf(2.0, minf(size.x, size.y) * 0.16)
		draw_polyline(pts, Color("3a2412"), w + 3.0, true)
		draw_polyline(pts, Color("f2c14e"), w, true)


## Золотая точка: история горожан ждёт (на свёрнутом свитке)
class GoldDot extends Control:
	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.5
		draw_circle(size * 0.5, r, Color("3a2412"))
		draw_circle(size * 0.5, r - 1.6, Color("f2c14e"))
		draw_circle(size * 0.5 + Vector2(-r * 0.25, -r * 0.25), r * 0.3, Color("fde39a"))


func _fill_tasks_body(goals: Array) -> void:
	var c: City = game.city
	var hdr := HBoxContainer.new()
	hdr.alignment = BoxContainer.ALIGNMENT_CENTER
	hdr.add_theme_constant_override("separation", 6)
	hdr.add_child(_icon("scroll", 26, C_SOFT))
	hdr.add_child(_label("Просьбы горожан", 20, false, C_INK, font_title))
	var sto = game.get("stories")
	if sto != null and (sto.journal_any() or Chronicle.any(c)):
		# книжка — журнал: пройденные истории («Пересмотреть») и «Летопись города» (счётчики и лавровые венки)
		hdr.add_child(_bare("bookshelf", "Журнал: истории горожан и летопись города", 28, func(): sto.ui.open_journal("" if sto.journal_any() else "chron")))
	if not tutorial_busy():
		var fb := _chevron_btn(false, "Свернуть свиток", 28, fold_tasks.bind(true))
		fb.name = "fold"
		hdr.add_child(fb)
	tasks_box.add_child(hdr)
	tasks_box.add_child(_divider(14))
	if sto != null:
		sto.ui.task_row(tasks_box)           # история горожан — золотая строка наверху
	var first := true
	for g in goals:
		var prog := mini(c.goal_progress(g["id"]), int(g["need"]))
		# строка просьбы растёт по тексту (текст сверху, под ним полоса), а прозрачная кнопка лежит поверх всей строки
		var row := MarginContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side in ["left", "right", "top", "bottom"]:
			row.add_theme_constant_override("margin_" + side, 2)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		var e := StyleBoxEmpty.new()
		for st in ["normal", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(st, e)
		var hov := _box_pill(8, 4, "g_btn_hover")
		hov.modulate_color = Color(1, 1, 1, 0.45)
		b.add_theme_stylebox_override("hover", hov)
		b.add_theme_stylebox_override("hover_pressed", hov)
		var who: Array = Defs.WHO.get(g.get("who", "advisor"), Defs.WHO["advisor"])
		var hint_txt := String(g.get("hint", ""))
		if hint_txt == Defs.POP_HINT:
			hint_txt = c.pop_hint()
		# «Соберите N жителей», а повозка стоит из-за счастья — сразу сказать почему и что делать
		var block := String(c.stats.get("arrive_block", ""))
		if String((g["p"] as Array)[0]) == "pop" and block != "":
			var ht: Array = c.stats.get("happy_tips", [])
			hint_txt = block + "." + ((" Совет: " + String(ht[0]) + ".") if not ht.is_empty() else "") + ("\n" + hint_txt if hint_txt != "" else "")
		var rank_lv := int((g["p"] as Array)[1]) if String((g["p"] as Array)[0]) == "rank" else -1
		if rank_lv > 0:
			# «Станьте хутором»: условия уровня — из данных (Defs.LEVELS), чтобы не расходились с кнопкой
			hint_txt = "Нужно: %s.\n%s" % [c.rank_text(rank_lv), hint_txt]
		b.tooltip_text = "%s\n%s\nНаграда: %d ден.%s%s" % [who[0], hint_txt if hint_txt != "" else String(g["text"]), g["money"], (", %d оч. исследований" % g["rp"]) if int(g["rp"]) > 0 else "",
			("\nОткроется: " + g["reward"]) if g.has("reward") else ""]
		var h := HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_theme_constant_override("separation", 8)
		var med := Panel.new()                    # медальон с иконкой просьбы; первая — светится
		med.custom_minimum_size = Vector2(44, 44)
		med.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		med.mouse_filter = Control.MOUSE_FILTER_IGNORE
		med.add_theme_stylebox_override("panel", _medal("medal_on" if first else "medal", 44))
		var ic := _icon(g.get("icon", "check"), 28, C_INK)
		ic.position = Vector2(8, 8)
		med.add_child(ic)
		h.add_child(med)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 3)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var t := _wrap(_label(g["text"], 15, true), 222)
		v.add_child(t)
		var pr := HBoxContainer.new()
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pr.add_theme_constant_override("separation", 6)
		var bar := ProgressBar.new()
		bar.max_value = int(g["need"])
		bar.value = prog
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(170, 14)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# жёлоб и золотая полоса — как у ползунка
		bar.add_theme_stylebox_override("background", _ai_box("g_slider", [8, 0, 8, 0], [8, 0, 8, 0]))
		bar.add_theme_stylebox_override("fill", _ai_box("g_slider_fill", [8, 0, 8, 0], [8, 0, 8, 0]))
		pr.add_child(bar)
		var cnt := _label("%s/%s" % [fmt(prog), fmt(int(g["need"]))], 14, true, C_SOFT)
		if rank_lv > 0 and prog >= int(g["need"]):
			cnt.text = "готово!"                  # осталось нажать «Перейти на новый уровень»
			cnt.add_theme_color_override("font_color", C_GOOD)
		cnt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pr.add_child(cnt)
		v.add_child(pr)
		# из чего просьба: «Склад ✓ · Мясная лавка 0/1»; у «Станьте деревней» — что ещё не готово из условий уровня
		var sub := ""
		if g.has("parts"):
			sub = parts_line(g["parts"])
		elif rank_lv > c.level:
			sub = parts_line(c.rank_needs(rank_lv).filter(func(e): return not e["ok"]))
		if prog < int(g["need"]) and String(request_do(g).get("kind", "")) == "wait":
			sub = (sub + "\n" if sub != "" else "") + WAIT_ROW      # делать нечего — ждём повозку (стрелки нет)
		if sub != "" and prog < int(g["need"]):
			var sl := _wrap(_label(sub, 13, true, C_SOFT), 222)
			sl.name = "parts"
			v.add_child(sl)
		h.add_child(v)
		row.add_child(h)
		row.add_child(b)                          # кнопка последней — поверх строки, ловит щелчок и подсказку
		var gg: Dictionary = g
		var gh := hint_txt
		b.pressed.connect(func():
			# щелчок: подсказка советника и сразу к делу — нужная постройка, исследование, «Этаж» или «Обзор» (need_do)
			var w := request_do(gg)
			var say := String(w.get("say", ""))
			if gh != "":
				advisor(gg["text"], gh + (("\n\nСейчас: " + say + ".") if say != "" and (gg.has("parts") or rank_lv > 0 or String(w.get("kind", "")) in ["wait", "build"] and (gg["p"] as Array)[0] in ["fed", "pop", "fam"]) else ""), Callable(), true)
			elif say != "":
				advisor(gg["text"], say + ".", Callable(), true)
			_do_click(w))
		tasks_box.add_child(row)
		first = false


func toggle_pause() -> void:
	if game.speed > 0.0:
		paused_speed = game.speed
		set_speed(0.0)
	else:
		set_speed(paused_speed)


func set_speed(s: float) -> void:
	game.speed = s
	refresh()


# ---------- значки над постройками (нет работников, нет склада, ждут жильё) ----------

func _update_world_icons() -> void:
	var want := {}
	var c: City = game.city
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		var d := c.def(b)
		if b.get("over", false) or d["kind"] == "decor":
			continue
		var icon := ""
		var warn := true
		var price := ""
		var tip := ""
		if c.is_house(b) and c.unhappy_badge(b):
			icon = "house_problem"
			tip = "Счастье ниже 40%: труд и налоги вполовину"
		elif not bool(b.get("road", true)):
			icon = "road"
			tip = "Нет дороги — постройте дорогу ко входу"
		elif c.job_max(b) > 0 and (c.hired_of(b) == 0 or float(b.get("staff", 0.0)) <= 0.0):
			icon = "no_workers"
			tip = "Нет работников — откройте здание и нажмите «+»"
		elif c.is_house(b):
			var red := []
			for n: String in Defs.needs_for(String(d["cls"]), c.level):
				if int(b.get("need_coverage", {}).get(n, 0)) < 100:
					red.append(Defs.NEEDS[n]["name"])
			if c.unhappy_badge(b) or (not red.is_empty() and String(d["cls"]) in ["artisans", "patricians"] and int(b["pop"]) > 0):
				icon = "house_problem"
				tip = "Счастье ниже 40%: труд и налоги вполовину" if red.is_empty() else "Жителям не хватает: %s" % ", ".join(red)

		# У станции остаются только значки ожидающих групп из _family_badges.
		# Пауза прибытия видна и меняется в карточке станции.
		if icon != "":
			want[id] = [icon, warn, price, tip]
	for id in world_icons.keys():
		if not want.has(id):
			clear_badge("b%d" % id)
			world_icons.erase(id)
	for id in want:
		var b: Dictionary = c.buildings[id]
		var top: float = c.blueprint(b).top_y() + 1.2
		var key := "b%d" % id
		set_badge(key, Vector3(b["pos"].x, float(b["y"]) + top, b["pos"].y), want[id][0], want[id][1], want[id][2])
		(badges[key]["n"] as Control).tooltip_text = want[id][3]
		world_icons[id] = want[id]


# ---------- значки над миром ----------

func _badge_layer() -> void:
	badge_layer = Control.new()
	badge_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(badge_layer)
	move_child(badge_layer, 0)                # окна интерфейса рисуются поверх значков


## Общий спокойный значок. style и ключи сохранены для вызывающих и тестов.
func set_badge(key: String, pos: Vector3, icon: String, warn := false, text := "", cb: Callable = Callable(), style := "") -> void:
	text = text if game != null and game.tool == "floor" and key.begins_with("fl") and icon == "up" else ""
	if badges.has(key):
		var old: Dictionary = badges[key]
		if old["pos"] != pos:
			old["pos"] = pos
			_badges_dirty = true
		if cb.is_valid():
			old["cb"] = cb
		else:
			cb = old.get("cb", Callable())
		if old["icon"] == icon and old.get("text", "") == text and old.get("style", "") == style:
			if old["warn"] != warn:
				old["warn"] = warn
				(old["n"] as MapBadge).set_warning(warn)
				_badges_dirty = true
			return
		(old["n"] as Control).hide()
		(old["n"] as Node).queue_free()
	var p := MapBadge.new()
	p.setup(icon, warn, text, font_bold)
	p.visible = false
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.gui_input.connect(_badge_input.bind(key))
	badge_layer.add_child(p)
	badges[key] = {"pos": pos, "icon": icon, "warn": warn, "text": text, "style": style, "n": p,
		"anc": Vector2(0.5, 0.5), "ph": 0.0, "cb": cb}
	_badges_dirty = true
	_badge_pick_dirty = true


## Совпадение с той же чертой, что видна рядом с семьёй.
func set_badge_match(key: String, home: Dictionary, family: Dictionary) -> void:
	if badges.has(key):
		var p: MapBadge = badges[key]["n"]
		p.set_match(FamilyPreference.matches(game.city, home, family))


## Значок ловит только левую кнопку (нажатие — действие, отпускание тоже не уходит в мир);
## правая/средняя кнопка и движение мыши проходят дальше — карту можно тянуть и вращать прямо со значка
func _badge_input(e: InputEvent, key: String) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if (e as InputEventMouseButton).pressed:
			_badge_click(key)


## Нажали значок над миром
func _badge_click(key: String) -> void:
	if not badges.has(key):
		return
	var cb: Callable = badges[key].get("cb", Callable())
	if cb.is_valid():
		cb.call()
		return
	var c: City = game.city
	if key.begins_with("fam_"):
		game.start_settle(key.substr(4))                       # семья на площади — выбрать ей дом
	elif key.begins_with("settle") and key.substr(6).is_valid_int():
		var h: Dictionary = c.buildings.get(int(key.substr(6)), {})
		if not h.is_empty() and c.can_host(h, game.settle_fam):
			game._settle_into(h)                                # ключи над домом — заселить сюда
	elif key.begins_with("plot"):
		var ij := key.substr(4).split("_")
		if ij.size() == 2 and c.can_buy(Vector2i(int(ij[0]), int(ij[1]))):
			ask_buy(Vector2i(int(ij[0]), int(ij[1])))           # цена участка — купить
	elif key.begins_with("b") and key.substr(1).is_valid_int():
		var b: Dictionary = c.buildings.get(int(key.substr(1)), {})
		if b.is_empty():
			return
		game.select_building(b)
		open_info(b)


## Четыре обновления в секунду; в остальные кадры — только проверка часов.
func _family_badges() -> void:
	var now := Time.get_ticks_msec()
	if now < _family_badge_next_ms:
		return
	_family_badge_next_ms = now + 250
	var want := {}
	var c: City = game.city
	if c != null and game.people != null and game.mode != "demo" and game.mode != "menu":
		for f: Dictionary in c.arrivals:
			var at: Vector3 = game.people.waiting_family_pos(String(f["name"]))
			if not at.is_finite():
				continue
			var key := "fam_" + String(f["name"])
			want[key] = true
			set_badge(key, at + Vector3(0, 1.7, 0), "family")
			var p: MapBadge = badges[key]["n"]
			var pref: Array = FamilyPreference.look(f)
			var old_size := p.size
			p.family(String(f["cls"]), String(f.get("want", "")))
			if old_size != p.size:
				_badges_dirty = true
			var cls: String = Defs.CLASSES[f["cls"]]["name"]
			p.tooltip_text = "Семья %s · %d чел. · %s · хотят: %s" % [f["name"], int(f["n"]), cls.to_lower(), pref[1]]
	for k in badges.keys():
		if String(k).begins_with("fam_") and not want.has(k):
			clear_badge(k)


## Значок с ключом на prefix под точкой mp (координаты интерфейса), "" — нет. «Этаж»: стрелки мышь не ловят
## (мазок идёт по городу), а дом под стрелкой ищет game._floor_pick. Из нескольких под мышью — верхний (нарисован
## последним): за что видно, за то и платят. skip_warn — красные (не по карману) не в счёт
func badge_at(mp: Vector2, prefix: String, skip_warn := false) -> String:
	if mp.x < 0.0:
		return ""
	var best := ""
	var best_i := -1
	for k in badges:
		if String(k).begins_with(prefix) and not (skip_warn and bool(badges[k]["warn"])):
			var n: Control = badges[k]["n"]
			if n.is_visible_in_tree() and n.get_index() > best_i and n.get_global_rect().has_point(mp):
				best_i = n.get_index()
				best = String(k)
	return best


## Точки внутри всех стрелок на отрезке: быстрый мазок не перескочит узкий значок.
func badge_stroke_samples(from: Vector2, to: Vector2, prefix: String) -> Array[float]:
	var samples: Array[float] = []
	if not from.is_finite() or not to.is_finite():
		return samples
	for key: String in badges:
		if not key.begins_with(prefix) or bool(badges[key]["warn"]):
			continue
		var node: Control = badges[key]["n"]
		if not node.is_visible_in_tree():
			continue
		var span := _badge_segment_span(node.get_global_rect(), from, to)
		if span != Vector2.INF:
			samples.append((span.x + span.y) * 0.5)
	return samples


static func _badge_segment_span(rect: Rect2, from: Vector2, to: Vector2) -> Vector2:
	var delta := to - from
	var enter := 0.0
	var leave := 1.0
	for axis in 2:
		if is_zero_approx(delta[axis]):
			if from[axis] < rect.position[axis] or from[axis] >= rect.end[axis]:
				return Vector2.INF
			continue
		var near_t: float = (rect.position[axis] - from[axis]) / delta[axis]
		var far_t: float = (rect.end[axis] - from[axis]) / delta[axis]
		enter = maxf(enter, minf(near_t, far_t))
		leave = minf(leave, maxf(near_t, far_t))
		if enter > leave:
			return Vector2.INF
	return Vector2(enter, leave)


func clear_badge(key: String) -> void:
	if badges.has(key):
		(badges[key]["n"] as Control).hide()
		(badges[key]["n"] as Node).queue_free()
		badges.erase(key)
		_badges_dirty = true


func _place_badges() -> void:
	if badges.is_empty():
		return
	var viewport := get_viewport()
	var cam := viewport.get_camera_3d()
	var vr := viewport.get_visible_rect()
	# Не передаём на GPU ни плохую камеру, ни координаты у плоскости проекции.
	if not _badge_camera_safe(cam, vr):
		for entry: Dictionary in badges.values():
			(entry["n"] as Control).hide()
		_badges_dirty = true
		return
	var show: bool = root.visible and game.mode != "menu" and badge_layer.modulate.a > 0.001
	var tl: String = game.tool
	var transform := cam.get_camera_transform()
	var projection := cam.get_camera_projection()
	var target: Vector3 = game.rig.target
	var zoom: float = game.rig.dist
	var place: bool = _badges_dirty or cam != _badge_camera or transform != _badge_transform or projection != _badge_projection or vr != _badge_viewport or show != _badge_show or target != _badge_target or zoom != _badge_zoom or tl != _badge_tool or overlay != _badge_overlay
	var pick: bool = _badge_pick_dirty or tl != _badge_tool
	if not place and not pick:
		return
	_badge_camera = cam
	_badge_transform = transform
	_badge_projection = projection
	_badge_viewport = vr
	_badge_show = show
	_badge_target = target
	_badge_zoom = zoom
	_badge_tool = tl
	_badge_overlay = overlay
	_badges_dirty = false
	_badge_pick_dirty = false
	for k in badges:
		var b: Dictionary = badges[k]
		var p: Control = b["n"]
		if pick:
			var can: bool = tl == "" or (tl == "settle" and (String(k).begins_with("settle") or String(k).begins_with("fam_")))
			# PASS сохраняет перетаскивание правой/средней кнопкой.
			p.mouse_filter = Control.MOUSE_FILTER_PASS if can else Control.MOUSE_FILTER_IGNORE
		if not place:
			continue
		var key := String(k)
		if tl == "floor" and key.begins_with("b") and badges.has("fl" + key.substr(1)):
			p.hide()
			continue
		if b["icon"] == "up" and tl != "floor":
			p.visible = false
			continue
		var w: Vector3 = b["pos"]
		if not w.is_finite() or not target.is_finite() or not is_finite(zoom):
			p.hide()
			continue
		var far: bool = zoom >= 90.0 and Vector2(w.x, w.z).distance_squared_to(Vector2(target.x, target.z)) > 180.0 * 180.0
		if not show or cam.is_position_behind(w) or (far and not bool(b["warn"])):
			p.visible = false
			continue
		var anc: Vector2 = b.get("anc", Vector2(0.5, 0.5))
		# Цена краснеет без изменения размера и прозрачности прежней стрелки.
		var price_arrow: bool = b["icon"] == "up" or String(b["icon"]).begins_with("upc")
		var layout := _badge_layout(cam, w, p.size, anc, vr, bool(b["warn"]) and not price_arrow)
		if layout.is_empty():
			p.hide()
			continue
		p.scale = layout["scale"]
		p.position = layout["pos"]
		p.modulate.a = layout["alpha"]
		p.show()


static func _badge_camera_safe(cam: Camera3D, vr: Rect2) -> bool:
	if cam == null or not vr.position.is_finite() or not vr.size.is_finite() or absf(vr.position.x) > 16384.0 or absf(vr.position.y) > 16384.0 or vr.size.x <= 0.0 or vr.size.y <= 0.0 or vr.size.x > 16384.0 or vr.size.y > 16384.0:
		return false
	var xf := cam.get_camera_transform()
	var determinant := xf.basis.determinant()
	if not xf.is_finite() or not is_finite(determinant) or absf(determinant) < 0.000001 or not is_finite(cam.near) or not is_finite(cam.far) or cam.near <= 0.0 or cam.far <= cam.near:
		return false
	var proj := cam.get_camera_projection()
	return proj.x.is_finite() and proj.y.is_finite() and proj.z.is_finite() and proj.w.is_finite()


## Сначала проверяем всё; только готовый безопасный результат назначаем Control.
static func _badge_layout(cam: Camera3D, world: Vector3, extent: Vector2, anchor: Vector2, vr: Rect2, warning: bool) -> Dictionary:
	if not _badge_camera_safe(cam, vr) or not world.is_finite() or not extent.is_finite() or not anchor.is_finite():
		return {}
	if extent.x <= 0.0 or extent.y <= 0.0 or extent.x > 512.0 or extent.y > 512.0:
		return {}
	var local := cam.get_camera_transform().affine_inverse() * world
	if not local.is_finite() or local.z >= -maxf(0.05, cam.near) or -local.z > cam.far:
		return {}
	var distance := cam.global_position.distance_to(world)
	if not is_finite(distance):
		return {}
	var depth := clampf((distance - 35.0) / 180.0, 0.0, 1.0)
	var factor := clampf(lerpf(1.0, 0.85 if warning else 0.8, depth), 0.5, 1.5)
	if not is_finite(depth) or not is_finite(factor):
		return {}
	var point := cam.unproject_position(world)
	if not point.is_finite() or not vr.grow(30.0).has_point(point):
		return {}
	var at := (point - extent * factor * anchor.clamp(Vector2.ZERO, Vector2.ONE)).round()
	if not at.is_finite() or not vr.grow(800.0).has_point(at):
		return {}
	return {"pos": at, "scale": Vector2.ONE * factor, "alpha": 1.0 if warning else clampf(lerpf(1.0, 0.76, depth), 0.0, 1.0)}


# ---------- свой герой (Д11): медальон «Герой» ----------

var hero_btn: Button
var hero_wrap: Control
var _hero_face_key := ""


## Медальон «Герой» сверху справа, рядом с «Легионом»: лицо героя; щелчок — камера к нему и его карточка
func _hero_button() -> void:
	hero_btn = _round("caesar", "Герой: найти его в городе", 48, func(): find_hero())
	hero_wrap = _shadowed(hero_btn)
	top_panel.add_child(hero_wrap)
	top_panel.move_child(hero_wrap, mini(1, top_panel.get_child_count() - 1))
	top_btns["hero"] = hero_btn
	hero_btn_refresh()


## Медальон — по герою (имя в подсказке, лицо); нет героя (меню, витрина) — не виден
func hero_btn_refresh() -> void:
	if hero_wrap == null:
		return
	var on: bool = game != null and game.mode in ["play", "new"] and Hero.exists(game.city)
	hero_wrap.visible = on
	if not on:
		return
	hero_btn.tooltip_text = "%s — ваш герой: найти в городе (карточка, «Следовать», «Гардероб»)" % Hero.name_of(game.city)
	var key := Citizen.look_key(Hero.look(game.city))
	if key != _hero_face_key:
		_hero_face_key = key
		_hero_face()


## Лицо героя в медальоне: рисуется один раз (свой маленький мир, как портрет в карточке) и остаётся картинкой
func _hero_face() -> void:
	if DisplayServer.get_name() == "headless" or game.shot_path != "":
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(128, 128)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff1d8")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 35, 0)
	key.light_energy = 1.25
	vp.add_child(key)
	var front := DirectionalLight3D.new()
	front.look_at_from_position(Vector3.ZERO, -StoryUi.FACE_DIR + Vector3(0, -0.25, 0), Vector3.UP)
	front.light_energy = 0.5
	vp.add_child(front)
	var c := Citizen.build(Hero.look(game.city).duplicate())
	c.scale = Vector3.ONE
	Citizen.face_fix(c)
	vp.add_child(c)
	c.play("Idle", 0.0, 0.2)
	var cam := Camera3D.new()
	cam.fov = 24.0
	cam.near = 0.02
	vp.add_child(cam)
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(vp) or not is_instance_valid(c):
		return
	var sk: Skeleton3D = c.find_children("*", "Skeleton3D", true, false)[0]
	var head := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head"))).origin + Vector3(0, 0.06, 0)
	cam.position = head + StoryUi.FACE_DIR * 0.95
	cam.look_at(head - Vector3(0, 0.02, 0), Vector3.UP)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if not is_instance_valid(vp) or not is_instance_valid(hero_btn):
		return
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		return
	img.generate_mipmaps()
	var ic := hero_btn.get_node_or_null("ic") as TextureRect
	if ic == null:
		return
	ic.texture = ImageTexture.create_from_image(img)
	ic.material = StoryUi._mask_mat()
	var o := 48 * 0.12
	ic.offset_left = o
	ic.offset_right = -o
	ic.offset_top = o
	ic.offset_bottom = -o


## «Герой»: камера идёт за ним, открыта его карточка (дома или в лавке — камера у двери, в карточке «Сейчас»)
func find_hero() -> void:
	var ppl: People = game.people
	if ppl == null or ppl.hero_r.is_empty():
		return
	game.select_person({"r": ppl.hero_r})
	PersonCard.follow(self, {"r": ppl.hero_r})


## Совет о герое (один раз)
func hero_note() -> String:
	var c: City = game.city
	var f := Hero.female(c)
	var t := "%s живёт в городе: гуляет по улицам, заглядывает в лавки и на площади, а ночует в городе. %s отличишь издали: лавровый венок и плащ. Найти героя — медальон с %s лицом сверху справа. Щёлкните по %s на улице: «Следовать», «Гардероб» и «Изменить». Новые вещи открывают рост города и истории." % [
		"Ваша римлянка" if f else "Ваш римлянин", "Её" if f else "Его", "её" if f else "его", "ней" if f else "нему"]
	if not bool(c.hero.get("made", false)):
		t += " Своего героя можно создать там же — «Изменить»."
	return t


# ---------- стартовое меню ----------

## Фон меню — неподвижная картинка вместо живого города (Game.menu_still): еле заметно наплывает и отплывает
func menu_backdrop(tex: Texture2D) -> void:
	if menu_root == null or tex == null:
		return
	var tr := TextureRect.new()
	tr.name = "menu_bg"
	tr.texture = tex
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_root.add_child(tr)
	menu_root.move_child(tr, 0)
	tr.resized.connect(func(): tr.pivot_offset = tr.size * 0.5)
	var tw := tr.create_tween().set_loops()
	tw.tween_property(tr, "scale", Vector2(1.06, 1.06), 45.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(tr, "scale", Vector2.ONE, 45.0).set_trans(Tween.TRANS_SINE)


func show_menu(has_save: bool) -> void:
	root.visible = false
	menu_root = Control.new()
	menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_root.theme = theme_main
	add_child(menu_root)
	menu_root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# логотип над свитком с кнопками
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_put(col, Control.PRESET_TOP_LEFT, Vector2(70, 34))
	menu_root.add_child(col)
	var logo := _pic("logo_min.png", Vector2(470, 231))
	col.add_child(logo)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box_scroll_v(18))
	p.custom_minimum_size = Vector2(380, 0)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var sub := _label("Уютный римский город", 21, false, C_SOFT, font_title)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(_divider(18))
	var mk := func(text: String, icon: String, cb: Callable) -> Button:
		var b := Button.new()
		b.text = text
		b.icon = ico(icon, 40)
		b.custom_minimum_size = Vector2(300, 58)
		b.add_theme_font_size_override("font_size", 24)
		b.add_theme_font_override("font", font_bold)
		b.pressed.connect(cb)
		v.add_child(b)
		return b
	mk.call("Играть", "play", func(): _menu_go("play" if has_save else "new"))
	mk.call("Настройки", "settings", func(): _menu_settings())
	mk.call("Титры", "laurels", func(): _menu_credits())
	mk.call("Выход", "exit", func(): Account.me().quit_game())
	# язык: «RU | EN» в углу — видно сразу, без поисков по настройкам
	var lw := HBoxContainer.new()
	lw.add_theme_constant_override("separation", 6)
	lw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lw.add_child(_icon("scroll", 28, C_CREAM))
	lw.add_child(_lang_buttons())
	menu_root.add_child(lw)
	_put(lw, Control.PRESET_TOP_RIGHT, Vector2(-24, 20))
	var foot := _label("Щипок — масштаб · два пальца — двигать · Option + два пальца — вращать" if OS.has_feature("macos")
		else "Колёсико — масштаб · зажатое колёсико — вращать · правая кнопка — двигать", 16, true, C_CREAM)   # Mac — про трекпад
	foot.add_theme_color_override("font_outline_color", Color("3a2412"))
	foot.add_theme_constant_override("outline_size", 6)
	_put(foot, Control.PRESET_BOTTOM_LEFT, Vector2(80, -36))
	foot.visible = not bool(game.get("menu_still"))      # за меню картинка, а не город — двигать камеру нечем
	menu_root.add_child(foot)
	_hook_buttons(menu_root)


## Настройки из главного меню: меню прячется, пока открыто окно (иначе оно перехватывало щелчки)
func _menu_settings() -> void:
	menu_root.visible = false
	root.visible = true
	for ch in root.get_children():
		(ch as CanvasItem).visible = ch == settings_panel
	_open_settings(true)
	settings_panel.visible = true
	if not settings_panel.visibility_changed.is_connected(_menu_settings_closed):
		settings_panel.visibility_changed.connect(_menu_settings_closed)


func _menu_settings_closed() -> void:
	if game.mode == "menu" and not settings_panel.visible and menu_root:
		root.visible = false
		menu_root.visible = true


## Титры из главного меню — так же, как настройки: меню прячется, пока открыто окно
func _menu_credits() -> void:
	menu_root.visible = false
	root.visible = true
	for ch in root.get_children():
		(ch as CanvasItem).visible = false
	open_credits()
	if not credits_panel.visibility_changed.is_connected(_menu_credits_closed):
		credits_panel.visibility_changed.connect(_menu_credits_closed)


func _menu_credits_closed() -> void:
	if game.mode == "menu" and not credits_panel.visible and menu_root:
		root.visible = false
		menu_root.visible = true


func _menu_go(m: String) -> void:
	if not await MacUpdate.allow_play():      # Mac: эта сборка устарела — окно «скачайте новую версию» (mac_update.gd)
		return
	if not Account.me().may_play(m):          # без входа не играем; сначала сверка города с облаком (account.gd)
		return
	var l := _label("Загрузка…", 32, false, C_CREAM, font_title)
	l.add_theme_color_override("font_outline_color", Color("3a2412"))
	l.add_theme_constant_override("outline_size", 8)
	l.set_anchors_preset(Control.PRESET_CENTER)
	menu_root.add_child(l)
	await get_tree().process_frame
	await get_tree().process_frame
	game.restart(m)


# ---------- картинки построек для карточек ----------

func _make_icons() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(200, 168)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("f3e6cf")
	e.ambient_light_energy = 0.85
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.2
	we.environment = e
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.light_energy = 2.2
	sun.light_color = Color("fff0d8")
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 30
	vp.add_child(cam)
	var holder := Node3D.new()
	vp.add_child(holder)
	_icons_async(vp, cam, holder)


## Папка готовых картинок построек (user://icons/…): своя у каждой сборки — поменялись файлы игры (код, модели), и
## картинки рисуются заново; старые папки удаляются. В редакторе ключ — сами скрипты построек
const ICON_V := 1                         # поменяли свет, камеру или размер картинок — увеличить
const ICON_SRC := ["catalog.gd", "cat_houses.gd", "cat_shops.gd", "cat_civic.gd", "cat_monuments.gd", "cat_decor.gd", "cat_military.gd",
	"parts.gd", "synty.gd", "kit.gd", "bp.gd", "artisau.gd", "entrance.gd", "hud.gd", "cat_decor2.gd", "cat_extra.gd", "cat_grand.gd", "cat_nature.gd", "cat_meadow.gd", "meadow.gd"]


func _icon_dir() -> String:
	var key := "v%d" % ICON_V
	if OS.has_feature("editor"):
		for f: String in ICON_SRC:
			key += FileAccess.get_md5("res://scripts/" + f)
	else:
		var exe := OS.get_executable_path()
		for p: String in [exe.get_basename() + ".pck", exe.get_base_dir().path_join("CivCity_models.pck")]:
			var fa := FileAccess.open(p, FileAccess.READ)
			if fa:
				key += "_%d_%d" % [FileAccess.get_modified_time(p), fa.get_length()]
	var root := "user://icons"
	var name := key.md5_text().substr(0, 12)
	DirAccess.make_dir_recursive_absolute(root.path_join(name))
	for old in DirAccess.get_directories_at(root):
		if old != name:
			var od := root.path_join(old)
			for f in DirAccess.get_files_at(od):
				DirAccess.remove_absolute(od.path_join(f))
			DirAccess.remove_absolute(od)
	return root.path_join(name)


## Картинки построек для карточек: готовые берём из папки (имя — тип и отпечаток деталей облика), рисуем только
## недостающие — при запуске почти нет чтений картинки с видеокарты (на слабых видеокартах на них падала игра)
func _icons_async(vp: SubViewport, cam: Camera3D, holder: Node3D) -> void:
	var col := 0
	var idir := _icon_dir()
	var drawn := 0
	for type in Defs.B:
		if type == "center":
			continue
		var d: Dictionary = Defs.B[type]
		if bool(d.get("hidden", false)):
			continue
		var tier := 2 if d["kind"] == "house" else 0
		col = (col + 3) % Defs.PALETTE.size()
		# у украшений облик задаёт тип (Catalog.make сам берёт их постоянный цвет) — картинка как поставленное
		if d.get("fcolors", false):
			col = 6                               # цветы «Природы»: на карточке — пёстрые, а не цвет палитры фасадов
		var bp: Bp = Catalog.make(type, tier, 0, col)
		var path := idir.path_join("%s_%s%s.png" % [type, str(bp.parts).md5_text().substr(0, 12), "_p" if pets_of(type).size() > 0 else ""])
		if FileAccess.file_exists(path):
			var ci := Image.load_from_file(path)
			if ci != null and not ci.is_empty():
				icons[type] = ImageTexture.create_from_image(ci)
				continue
		drawn += 1
		var g := Parts.ghost(bp, "outline", Color(0, 0, 0, 0))
		for gi: GeometryInstance3D in g.find_children("*", "GeometryInstance3D", true, false):
			gi.material_override = null
		# тёмная плашка под землёй (ровняет землю под клумбой, лужком, перголой) — на картинке не нужна
		for ch in g.get_children():
			if ch is MeshInstance3D and (ch as MeshInstance3D).mesh == Parts._special_mesh("#dark") and (ch as Node3D).position.y < -0.05:
				g.remove_child(ch)
				ch.free()
		add_pets(g, type)                         # корова, лошадь, кошки приюта — и на картинке карточки
		holder.add_child(g)
		var box := Artisau.aabb(g)
		var c := box.get_center()
		var deco: bool = d["kind"] == "decor"
		var rad := maxf(0.3 if deco else 0.6, box.size.length() * 0.5)
		var dir := Vector3(0.62, 0.6, 0.95).normalized()
		cam.look_at_from_position(c + dir * rad / sin(deg_to_rad(15.0)) * 0.95, c, Vector3.UP)
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		if not _icons_alive(vp):
			return                                # игру закрыли посреди картинок: окна и сцены уже нет
		var img := vp.get_texture().get_image()
		if deco:
			# украшения маленькие: обрезать пустые поля, чтобы облик был крупно и облики отличались на карточке
			var r := img.get_used_rect()
			if r.size.x > 8 and r.size.y > 8:
				r = r.grow(int(maxf(r.size.x, r.size.y) * 0.05)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
				img = img.get_region(r)
		icons[type] = ImageTexture.create_from_image(img)
		img.save_png(path)
		g.queue_free()
		await get_tree().process_frame
		if not _icons_alive(vp):
			return
	vp.queue_free()
	if drawn > 0:
		print("Картинки построек: нарисовано %d, остальные — из %s" % [drawn, idir])
	if tray.visible:
		_update_cards()


## Животные этапа 5 у постройки (CatDecor2.PETS / CatExtra.PETS) для этого облика
static func pets_of(type: String) -> Array:
	var lk := int((Defs.B.get(type, {}) as Dictionary).get("look", 0))
	var list: Array = KitHouses.pets(type)
	if list.is_empty():
		list = CatGrand.PETS.get(type, CatExtra.PETS.get(type, CatDecor2.PETS.get(Defs.base_of(type), [])))
	return list.filter(func(e: Array): return e.size() <= 5 or int(e[5]) < 0 or int(e[5]) == lk)


## Поставить животных постройки в узел-призрак g (картинка карточки, лист обликов): как в игре (game._pets2), без движения
static func add_pets(g: Node3D, type: String) -> void:
	var sc := Catalog.DECOR if String(Defs.B[type]["kind"]) == "decor" else Catalog.scale_of(type)
	var k := 0
	for e: Array in pets_of(type):
		var n: Node3D
		if String(e[0]) == "cat":
			n = People.cat_node(k % 3, String(e[3]), 7 + k)
			if e.size() > 6 and e[6] is String:          # строка — вещица с витрины (число — окрас котят Маси)
				People.cat_wear(n, String(e[6]))
		elif String(e[0]) in ["acc", "toy"]:
			n = shop_prop(e)
		else:
			var bn: Stories.Beast = CatDecor2.beast(String(e[0]))
			bn.play(String(e[3]), 0.0)
			if bn.ap:
				bn.ap.seek(0.6, true)
			n = bn
		n.transform = Transform3D(Basis(Vector3.UP, float(e[2])).scaled(Vector3.ONE * float(e[4])), (e[1] as Vector3) * sc)
		g.add_child(n)
		k += 1


## Вещица на витрине «Кошачьей лавки» (["acc", где, поворот, id вещицы, масштаб]) или клубок на нитке (["toy", …]:
## узел — в точке крепления нитки, клубок висит под ней; качает его game._toy_swing)
static func shop_prop(e: Array) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if String(e[0]) == "acc":
		mi.mesh = People._wear_build(String(e[3]))
		mi.material_override = Kit.material(0.75)
	else:
		var kt := Kit.new()
		kt.rod(Vector3.ZERO, Vector3(0, -1.25, 0), 0.006, 4, Color("e8dcc8"))
		kt.blob(Vector3(0, -1.32, 0), Vector3(0.07, 0.07, 0.07), Color("d9506e"), 3, 0.1)
		kt.blob(Vector3(0.03, -1.3, 0.04), Vector3(0.04, 0.03, 0.02), Color("f07fa0"), 5, 0.1)
		mi.mesh = kt.mesh()
		mi.material_override = Kit.material(0.85)
	root.add_child(mi)
	return root


## Картинки карточек ещё можно рисовать: игра не закрывается, интерфейс и его окошко для картинок на месте
func _icons_alive(vp: SubViewport) -> bool:
	return _quitting == false and is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(vp) 		and vp.is_inside_tree() and get_tree() != null


var _quitting := false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_PREDELETE:
		_quitting = true                          # закрываем игру: картинки карточек больше не рисуем


## Кремовая карточка с тонкой оливковой рамкой.
func _card_frame(radius := 10, padding := 12) -> StyleBoxFlat:
	return CityStyle.panel(radius, padding)


var _card_button_textures: Dictionary = {}


## 512×160 переводим в высоту кнопки до нарезки: золотые края остаются тонкими.
func _card_button_texture(file: String) -> Texture2D:
	if not _card_button_textures.has(file):
		var image := src_image("res://assets/ui/kitA/buttons/%s.png" % file)
		if image.is_compressed():
			image.decompress()
		image.resize(102, 32, Image.INTERPOLATE_LANCZOS)
		_card_button_textures[file] = ImageTexture.create_from_image(image)
	return _card_button_textures[file]


func _card_button(button: Button, round_button := false, _green := false) -> void:
	button.custom_minimum_size = Vector2(32, 32) if round_button else Vector2(0, 32)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_font_override("font", font_bold)
	button.clip_text = not round_button
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	CityStyle.button(button, round_button)
	if not round_button and button.text != "":
		button.custom_minimum_size.x = minf(INFO_BODY, ceilf(font_bold.get_string_size(I18n.t(button.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x) + 24 + (26 if button.icon != null else 0))
	button.set_meta("compact_kit", true)


func _card_row(icon: String, text: String, value: String, _color := CARD_ACCENT) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.tooltip_text = text + ": " + value
	row.add_child(_card_icon(icon, 26))
	var title := _label(text, 13, false, CARD_ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	row.add_child(title)
	var number := _label(value, 14, true, _color)
	if number.get_minimum_size().x > 140:
		number.custom_minimum_size.x = 140
		number.clip_text = true
	row.add_child(number)
	return row


func _compact_info_style() -> void:
	var body := info_box.find_child("HouseBody", true, false) as Control
	for node: Control in info_box.find_children("*", "Control", true, false):
		var width_limit := body.custom_minimum_size.x if body != null and body.is_ancestor_of(node) else INFO_BODY
		node.custom_minimum_size.x = minf(node.custom_minimum_size.x, width_limit)
		if node is Label:
			var label := node as Label
			if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
				label.custom_minimum_size.x = minf(label.custom_minimum_size.x, width_limit)
			if label.autowrap_mode == TextServer.AUTOWRAP_OFF and label.get_parent() is VBoxContainer:
				label.clip_text = true
				label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				if label.tooltip_text == "":
					label.tooltip_text = label.text
			if label.get_theme_color("font_color") not in [C_BAD, C_GOOD]:
				label.add_theme_color_override("font_color", CityStyle.INK)
			label.add_theme_font_size_override("font_size", mini(14, label.get_theme_font_size("font_size")) if label.name != "InfoTitle" else 18)
		elif node is Button:
			var button := node as Button
			if not button.flat and not button.has_meta("compact_kit") and not button.has_meta("icon") and not button.has_meta("bare"):
				_card_button(button)
				button.custom_minimum_size.x = minf(button.custom_minimum_size.x, width_limit)
				if button.get_parent() is HBoxContainer:
					var siblings := button.get_parent().get_child_count()
					button.custom_minimum_size.x = minf(button.custom_minimum_size.x, (width_limit - 6 * (siblings - 1)) / maxi(1, siblings))
		elif node is TextureRect:
			var picture := node as TextureRect
			if picture.texture != null and picture.texture.resource_path.ends_with(".svg"):
				picture.modulate = Color(CityStyle.OLIVE, picture.modulate.a)


func _refresh_source_pictures() -> void:
	for picture: TextureRect in info_box.find_children("SourcePicture*", "TextureRect", true, false):
		var type := String(picture.get_meta("building_type", ""))
		picture.texture = CityStyle.icon(String(Defs.B.get(type, {}).get("icon", "housing")))
		picture.modulate = CityStyle.OLIVE


func _card_icon(key: String, side := 26, _color := CARD_ACCENT) -> TextureRect:
	return CityStyle.pictogram(key, side)


## Полоса прокрутки городских окон — оливковая на кремовом (была фиолетовая из темы по умолчанию)
static func _olive_scroll(sc: ScrollContainer) -> void:
	var bar := sc.get_v_scroll_bar()
	var track := StyleBoxFlat.new()
	track.bg_color = Color("E8D9BA")
	track.set_corner_radius_all(4)
	track.content_margin_left = 3
	track.content_margin_right = 3
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	for state: Array in [["grabber", Color("4F5B2E")], ["grabber_highlight", Color("66753C")], ["grabber_pressed", Color("3E4824")]]:
		var g := StyleBoxFlat.new()
		g.bg_color = state[1]
		g.set_corner_radius_all(4)
		bar.add_theme_stylebox_override(String(state[0]), g)


## Пустых разделов нет; новые открытия появляются даже при открытом свитке.
func _category_types(cat: String) -> Array:
	if cat != "commerce":
		return _types_in(cat)
	var out := []
	for need: String in Defs.NEED_ORDER:
		out.append_array(_types_in(cat, need))
	return out


func _sync_build_menu() -> void:
	var key := ""
	for cid: String in cats:
		var types := _category_types(cid)
		key += str(types)
		var box := (cats[cid] as Control).get_parent() as Control
		box.visible = not types.is_empty()
		if types.is_empty() and open_cat == cid:
			tray.hide()
			open_cat = ""
	if key != _build_menu_key:
		_build_menu_key = key
		if tray.visible:
			_fill_cards()
		_refresh_cat_buttons()
		_fit_bottom.call_deferred()


func _sync_build_tabs() -> void:
	for pair: Array in [[tray_tabs, "commerce", open_sub], [tray_dtabs, "decor", open_dsub], [tray_stabs, "special", open_ssub]]:
		var first := ""
		var found := false
		for tab: Button in (pair[0] as Control).get_children():
			var sub := String(tab.get_meta("sub"))
			tab.visible = not _types_in(String(pair[1]), sub).is_empty()
			if tab.visible:
				if first == "":
					first = sub
				found = found or sub == String(pair[2])
		if not found and first != "":
			match String(pair[1]):
				"commerce": open_sub = first
				"decor": open_dsub = first
				"special": open_ssub = first


func _tip_money(v: VBoxContainer) -> void:
	var c: City = game.city
	var flow := c.projected_finance()
	_tip_head(v, CityStyle.pictogram("coins", 24), "Денарии в казне")
	_tip_row(v, "coins", "Доход в час", "+%s/ч" % fmt_rate(float(flow["income"])), C_GOOD)
	_tip_row(v, "person", "Налоги", "+%s" % fmt_rate(float(flow["tax"])))
	_tip_row(v, "commerce", "Лавки", "+%s" % fmt_rate(float(flow["shops"])))
	_tip_row(v, "family", "Туристы", "+%s" % fmt_rate(float(flow["tourists"])))
	if not is_zero_approx(float(flow["export"])):
		_tip_row(v, "warehouse", "Продажа товаров", "+%s" % fmt_rate(float(flow["export"])))
	if float(flow["levy"]) > 0.0:
		_tip_row(v, "shield", "Отчисления Легиону", "−%s" % fmt_rate(float(flow["levy"])), C_BAD)
	_tip_row(v, "coins", "Расход в час", "−%s/ч" % fmt_rate(float(flow["expense"])), C_BAD)
	_tip_row(v, "hammer", "Содержание", "−%s" % fmt_rate(float(flow["upkeep"])))
	_tip_row(v, "worker", "Жалованье", "−%s" % fmt_rate(float(flow["wages"])))
	_tip_row(v, "chest", "Казна вмещает", fmt(c.money_cap()))
	CityStyle.apply(v)


func _tip_rp(v: VBoxContainer) -> void:
	var c: City = game.city
	var sources := c.rp_sources()
	var total := 0.0
	for value: float in sources.values():
		total += value
	_tip_head(v, CityStyle.pictogram("research", 24), "Очки исследований")
	_tip_row(v, "research", "Прирост в час", "+%s/ч" % fmt_rate(total), C_GOOD)
	for source: String in ["post", "scriptorium", "school", "library", "academy"]:
		var names := {"post": "Почта", "scriptorium": "Скриптории", "school": "Школы", "library": "Библиотеки", "academy": "Академии"}
		_tip_row(v, "mail" if source == "post" else "research", String(names[source]), "+%s" % fmt_rate(float(sources.get(source, 0.0))))
	_tip_row(v, "scroll", "Полки вмещают", fmt(c.rp_cap()))
	CityStyle.apply(v)
