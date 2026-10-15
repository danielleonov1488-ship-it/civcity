class_name Game
extends Node3D
## CivCity: уютный римский город как Town to City, на моделях Synty POLYGON Ancient Empire.
## Мир: большая карта с мягкими холмами, прудами и лесами; с севера из-за горизонта через арку идёт большая дорога — по ней приезжают
## повозки. Игрок рисует дороги кистью, ставит дома и лавки (постройка занимает землю своей настоящей формой
## и встаёт фасадом к дороге), жители живут своей жизнью.
## Запуск: без параметров — меню; -- --new | --play | --demo; снимок: --shot=путь.png --view=x,z,yaw,pitch,dist --hour=8

static var boot := {}                 # с чем перезапуститься: {"menu"|"play"|"new"|"demo": "1"}
const DAY_LEN := 600.0                # сутки — 10 минут при обычной скорости (час — 25 секунд), как в Town to City
const HOUSE_LIGHT := 0.12             # ночной свет жилых домов (фонарик у двери, жаровня) — доля от фонаря-украшения

var land: Land
var city: City
var parts: Parts
var people: People
var rig: CameraRig
var hud: Hud
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var grade: ShaderMaterial              # цветокоррекция кадра (тёплые света, прохладные тени)
var chunk_nodes := {}
var land_mat: ShaderMaterial
var surf_img: Image
var surf_tex: ImageTexture
var visuals := {}                     # id постройки → {h, lights, smoke, actors}
var nature := {}                      # Vector2i(2-метровая клетка) → [{h, p}]
var plot_signs := {}
var plot_fill: MeshInstance3D            # подсветка участка под курсором (его можно купить)
var plot_fill_key := Vector2i(-1, -1)
var night_lights: Array[OmniLight3D] = []
var actors_root: Node3D
var swimmers := []                    # утки и лебеди на прудах
var _actor_speed := 1.0

var mode := "play"                    # menu | play | new | demo
var promo := false                    # --promo: вместо готового городка — большая витрина Showcase (режим demo)
var can_save := true
var speed := 1.0
var _min_speed := -1.0                # скорость до сворачивания окна (-1 — окно не свёрнуто)
var _min_battle = null                # бой Легиона, поставленный на паузу при сворачивании
var minimized_test := false           # проверки: «окно свёрнуто» без настоящего окна
var day_t := 0.0
var hour := 8.0
var clock_hours := true
var shot_path := ""
var shot_frame := 200
var frame := 0
var autosave_t := 0.0
var settings := {"fullscreen": false, "quality": "high", "ui_scale": 1.0, "autosave": true, "music": 0.55, "sfx": 0.7}
var sound: Sound
var place_color := -1                 # цвет будущей постройки (не меняется, пока курсор рядом)
var place_color_pos := Vector2.INF
var last_snap_n := Vector2.ZERO       # куда смотрел фасад в прошлый раз — чтобы дом не дёргался
var moving_nature := {}               # переносимое дерево или камень
var hover_nature := {}
var _autogo := ""
var loading: CanvasLayer
var ready_done := false

# ---------- инструменты ----------
var tool := ""                        # "" | тип постройки | road | plaza | path | erase | bulldoze | copy | move
var tool_yaw := 0.0
var tool_variant := -1                # -1 — случайный фасад
var next_variant := 0
var snap := true                      # привязать к пути
var ghost: Node3D
var ghost_key := ""
var highlight: Node3D                 # подсветка постройки под курсором (снос, выбор)
var highlight_key := ""
var selected := {}
var select_outline: Node3D
## Охват без кругов: дома подсвечены цветом (синие — уже с такой же лавкой, зелёные — получат), и «Обзор» (cover.gd)
var cover: Cover
var brush_ring: MeshInstance3D
var brush_box: MeshInstance3D
static var _brush_mem := 2.0          # размер кисти по умолчанию (как просил владелец); дальше — что выбрал игрок,
var brush_r := _brush_mem:            # и он помнится до выхода из игры (новая игра и загрузка его не сбрасывают)
	set(v):
		brush_r = v
		_brush_mem = v
var brush_square := false
var brush_line := false               # прямая линия
var brush_over := true                # рисовать поверх других дорог
var line_from := Vector2.INF
var stroke := []
var stroke_cost := 0.0
var undo_stack := []
var redo_stack := []
var painting := false
var last_paint := Vector2.INF
var hover := Vector2.INF
var place_info := {}
var moving := {}                      # перенос постройки: исходная запись
var settle_fam := {}                  # семья с площади, которой игрок выбирает дом
var tutorial: Tutorial
const RankCineScript := preload("res://scripts/rank_cine.gd")
var rank_cine = null                  # ролик «Новый ранг»: станция вырастает (scripts/rank_cine.gd)
## Поворот как в Town to City: зажать левую кнопку и вести мышь вбок — постройка поворачивается на месте;
## отпустил — не строится, строится следующим щелчком (уже повёрнутая)
var place_lock := {}                  # {p: точка} — призрак закреплён на месте
var pressing := false
var rot_drag := false
var press_screen := Vector2.ZERO
var press_hover := Vector2.INF
var rot_yaw0 := 0.0
var manual_yaw := false               # игрок сам повернул эту постройку — к дороге её не разворачиваем (до постановки)
const ROT_DRAG_PX := 14.0             # с какого сдвига мыши вбок (зажатая левая) начинается поворот — дрожь щелчка не в счёт
var last_snap_p := Vector2.INF        # где был курсор, когда фасад последний раз нашёл дорогу
# постановка, как в Town to City: куда навёл и как повернул (на траве, площади, мостовой); вплотную к дороге — фасадом
# к ней, ровно у края. У входа нужна мостовая
var pave_build := true                 # false — пока раскладывается готовый город меню (витрина, старый городок): там прежние правила
var yaw_set := false                   # игрок уже поворачивал постройку (Z/X, зажатая мышь) — дальше держим его поворот
var free_yaw := 0.0                    # …вот этот (отдельно от tool_yaw: перенос деревьев и домов его не сбивает)
var rot_off := Vector2.ZERO            # Z/X: середина постройки относительно курсора — поворачивается на месте, не прыгает
var press_pl := {}                     # какую постройку показывала тень в миг нажатия (поворот зажатой мышью — от неё)
const SNAP_R := 0.8                    # фасад (постройка серединой на курсоре) ближе этого к краю дороги — прилипает к краю
const SNAP_STAY := 1.5                 # …и держится, пока фасад не отошёл дальше этого (без дёрганья на границе)
const PAVE_SLOPE := 0.5                # дом и лавка на мостовой — только на почти ровном месте (иначе ступени вокруг)
var settle_marks := []                # подсветка подходящих домов
var settle_keys := []                 # значки «ключи» над ними
var floor_drag := false               # «Этаж» (U): левая кнопка зажата — готовые дома под курсором получают этаж
var floor_done: Array = []            # кому надстроили этаж в этом мазке (второй раз за мазок — нет)
var floor_spent := 0                  # сколько денариев ушло в этом мазке
var floor_broke := false              # в этом мазке кончились деньги — до отпускания кнопки больше не надстраиваем
var floor_hover := -1                 # под курсором: 1 — дом, которому можно этаж, 0 — дом, которому нельзя, −1 — не дом
const POPS_MAX := 40                  # рожиц после стройки за раз не больше (самые большие перемены счастья)
var _rmb_down := Vector2.ZERO
var _rmb_armed := false               # правую кнопку нажали над миром (а не над окном)
var _rmb_moved := 0.0                 # насколько ушла мышь с зажатой правой: тянули карту — не «щелчок»
var _paint_broke := false             # в этом мазке кончились деньги — дальше не рисуем до отпускания кнопки
var _mouse_pos := Vector2(-1, -1)
## Выбор мышью: луч из камеры по коробкам деталей построек (кэш на постройку)
var _pick_cache := {}                 # id → {b, id, tier, pos, yaw, y, inv, box, boxes}
var _pick_sig := []
var _pick_t := 0
var _pick_hit := {}                   # {id, t, p} — во что попал луч
static var _bp_boxes := {}            # чертёж → коробки его деталей (в осях постройки)

const SAVE_NAME := "city.json"


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if not boot.is_empty():
		args = boot.duplicate()
	boot = {}
	if not (args.has("menu") or args.has("play") or args.has("new") or args.has("demo") or args.has("promo")):
		args["menu"] = "1"
	promo = args.has("promo")
	if args.has("menu"):
		mode = "menu"
	elif args.has("demo") or promo:
		mode = "demo"
	elif args.has("new"):
		mode = "new"
	shot_path = args.get("shot", "")
	shot_frame = int(args.get("frames", "200"))
	_autogo = args.get("autogo", "")
	hour = float(args.get("hour", "8.5"))
	if args.has("hour"):
		clock_hours = false
	can_save = shot_path == "" and (mode == "play" or mode == "new")
	_load_settings()
	sound = Sound.new()
	sound.game = self
	add_child(sound)
	_environment()
	_grading()
	_loading_show()
	await _step("Земля и холмы", 0.05)
	land = Land.new()
	city = City.new(land)
	parts = Parts.new()
	add_child(parts)
	cover = Cover.new()
	add_child(cover)
	cover.setup(self)
	actors_root = Node3D.new()
	add_child(actors_root)
	land_mat = ShaderMaterial.new()
	land_mat.shader = load("res://shaders/land.gdshader")
	Synty._index()
	var tex := func(n: String) -> Texture2D: return load(Synty._tex_path(n))
	land_mat.set_shader_parameter("tile_road", tex.call("Floor_Tiles_04"))
	land_mat.set_shader_parameter("tile_plaza_a", tex.call("Floor_Tiles_03"))
	land_mat.set_shader_parameter("tile_plaza_b", tex.call("Floor_Tiles_05"))
	land_mat.set_shader_parameter("tile_plaza_c", tex.call("Floor_Tiles_01"))
	land_mat.set_shader_parameter("tile_plaza_d", tex.call("Floor_Tiles_02"))
	await _step("Вода, дорога и даль", 0.15)
	_water()
	_horizon()
	_gate()
	var birds := Birds.new()
	birds.center = Vector3(Land.START.x, 0, Land.START.y)
	add_child(birds)
	city.building_added.connect(_on_added)
	city.building_removed.connect(_on_removed)
	city.house_changed.connect(_on_house_changed)
	people = People.new()
	add_child(people)
	await _step("Город", 0.25)
	var loaded := false
	if mode == "play":
		loaded = _load()
	if not loaded:
		city.tips["v22_pace"] = true             # новая игра — сразу по новым правилам, объяснять перемены не нужно
		city.seed_seen()                         # открытое с начала — не «НОВОЕ»; пометки — у того, что откроют исследования
		if mode in ["play", "new"]:
			land.own_start()                     # своя земля новой игры — 2×3 участка, остальное покупается (меню и витрина — как были)
		city.place("center", Land.CENTER, PI / 2, 0, 0, true)
		# фон меню — тоже витрина (на «низком» качестве — прежний городок: он легче для видеокарты)
		if promo or (mode == "menu" and settings.get("quality", "high") != "low"):
			Showcase.build(self, args)
		elif mode == "demo" or mode == "menu":
			_demo_town()
	await _step("Леса и луга", 0.35)
	_nature()
	_ponds_life()
	_cliff_rocks()
	surf_img = land.make_surface()
	surf_img.generate_mipmaps()
	surf_tex = ImageTexture.create_from_image(surf_img)
	land_mat.set_shader_parameter("surf", surf_tex)
	land_mat.set_shader_parameter("map_size", Land.SIZE)
	land.dirty.clear()
	var total := Land.CHN * Land.CHN
	var built := 0
	var order := []
	for j in Land.CHN:
		for i in Land.CHN:
			order.append(Vector2i(i, j))
	order.sort_custom(func(a, b): return (Vector2(a) - Vector2(8, 4)).length() < (Vector2(b) - Vector2(8, 4)).length())
	for ch: Vector2i in order:
		_build_chunk(ch)
		built += 1
		if built % 16 == 0:
			await _step("Рисуем землю", 0.4 + 0.45 * built / total)
	await _step("Жители", 0.9)
	people.setup(land, city, self)
	rig = CameraRig.new()
	add_child(rig)
	rig.land = land
	var v := str(args.get("view", "192,124,15,42,60")).split(",")
	rig.set_view(Vector3(float(v[0]), Land.BASE_Y, float(v[1])), float(v[2]), float(v[3]), float(v[4]))
	_make_markers()
	_apply_quality()
	hud = Hud.new()
	hud.game = self
	add_child(hud)
	city.event.connect(func(t, i): hud.notify(t, i))
	city.quiet.connect(func(t, i): hud.bell(t, i))
	if city.unread > 0 and mode in ["play", "new"]:
		hud.bell_count += city.unread         # записано при загрузке (например, возврат очков) — только число на колокольчике
		hud.bell_badge.text = str(hud.bell_count)
	city.unread = 0
	city.changed.connect(func(): hud.refresh())
	city.changed.connect(_sync_all_actors)
	city.changed.connect(_settle_refresh)
	city.changed.connect(cover.refresh)       # подсветка охвата и «Обзор» — живые
	city.family_came.connect(func(f): hud.on_arrival(f))
	city.arrive_advice.connect(func(t): hud.on_arrive_block(t))
	city.festival_changed.connect(_fest_look)
	if mode == "new" and not loaded and not settings.get("tut_done", false) and shot_path == "":
		Tutorial.start_new(city)
	tutorial = Tutorial.new()
	add_child(tutorial)
	tutorial.setup(self)
	rank_cine = RankCineScript.new()
	add_child(rank_cine)
	rank_cine.setup(self)
	_update_plot_signs()
	if city.fest_left > 0:
		_fest_look(true)                      # сохранение с идущими играми — город сразу наряжен
	_set_hour(hour)
	hud.refresh()
	_sync_all_actors()
	ready_done = true
	_loading_hide()
	if args.has("noui"):
		hud.visible = false
	if mode == "menu":
		hud.show_menu(FileAccess.file_exists(save_path()))
		if not args.has("view"):
			rig.set_view(Vector3(194, Land.BASE_Y, 158), 22, 30, 70)
	elif mode == "demo" and shot_path == "" and not promo:
		hud.notify("Готовый город: стройте сколько угодно — он не сохраняется", "info")
	elif loaded and mode == "play" and shot_path == "" and not city.tips.has("v22_pace"):
		city.tips["v22_pace"] = true
		hud.advisor("В городе новые правила", hud.pace_note())
	elif not loaded and shot_path == "" and not tutorial.active():
		hud.advisor("Аве! Я Марк, твой советник.", "По большой дороге через арку к почтовой станции приезжают повозки с переселенцами. Проложи дорогу кистью (слева внизу) и поставь вдоль неё дома — они сами встанут фасадом к дороге. Рядом поставь лавки: каждая кормит и радует дома в своей дальности.\n\nКамера: колёсико — масштаб, зажатое колёсико — вращать, правая кнопка — двигать (или WASD, Q/E).")
	Account.me().attach(self)                 # вход в аккаунт и сверка города с облаком (scripts/account.gd)
	LegionBattle.attach(self)                 # 3D-бой Легиона: «В бой» в окне «Легион» открывает поле боя (scripts/legion_battle.gd)
	LegionNet.me()                            # бои с городами по сети: отряд обороны на сервер, отчёты о нападениях (scripts/legion_net.gd)
	QaDrive.attach(self)                      # автопроверка собранной игры, только с аргументом --qa=… (scripts/qa_drive.gd)


func _step(text: String, k: float) -> void:
	if loading:
		(loading.get_node("box/label") as Label).text = text + "…"
		(loading.get_node("box/bar") as ProgressBar).value = k * 100.0
	await get_tree().process_frame
	await get_tree().process_frame


# ---------- загрузка ----------

func _loading_show() -> void:
	if shot_path != "":
		return
	preload("res://scripts/cursors.gd").wait(self)        # песочные часы, пока грузится (потом курсор ставит интерфейс)
	loading = CanvasLayer.new()
	loading.layer = 50
	add_child(loading)
	var fill := ColorRect.new()
	fill.color = Color("2b1d12")
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading.add_child(fill)
	# рисованная картинка владельца (на весь экран, без полей) — каждый раз одна из трёх: городок на закате,
	# вечер с фонарями, легион выходит в поход
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var pics := ["res://assets/ui/ai/loading.jpg", "res://assets/ui/ai/loading_33.jpg", "res://assets/ui/ai/loading_34.jpg"].filter(
		func(p: String) -> bool: return ResourceLoader.exists(p))
	if pics.is_empty():
		pics = ["res://assets/ui/loading.png"]
	var pic: String = pics[randi() % pics.size()]
	if ResourceLoader.exists(pic):
		bg.texture = load(pic)
	loading.add_child(bg)
	# мягкое затемнение снизу — чтобы подпись и полоса читались на картинке
	var g := Gradient.new()
	g.set_color(0, Color(0.12, 0.07, 0.03, 0.0))
	g.set_color(1, Color(0.12, 0.07, 0.03, 0.78))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 4
	gt.height = 256
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var shade := TextureRect.new()
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.anchor_left = 0.0
	shade.anchor_right = 1.0
	shade.anchor_top = 0.62
	shade.anchor_bottom = 1.0
	loading.add_child(shade)
	# логотип сверху посередине
	var logo := TextureRect.new()
	logo.texture = load("res://assets/ui/ai/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	logo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	logo.offset_left = -250
	logo.offset_right = 250
	logo.offset_top = 22
	logo.offset_bottom = 268
	logo.visible = not pic.ends_with("loading_34.jpg")    # там вверху посередине орёл легиона — логотип закрыл бы его
	loading.add_child(logo)
	var box := VBoxContainer.new()
	box.name = "box"
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.position = Vector2(-280, -128)
	box.custom_minimum_size = Vector2(560, 0)
	box.add_theme_constant_override("separation", 8)
	loading.add_child(box)
	var l := Label.new()
	l.name = "label"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", load("res://assets/fonts/Philosopher-Bold.ttf"))
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color("fff3dc"))
	l.add_theme_color_override("font_outline_color", Color("3a2412"))
	l.add_theme_constant_override("outline_size", 8)
	box.add_child(l)
	# полоса загрузки: пергаментный жёлоб в бронзовой кайме, золотое заполнение (как ползунки в настройках)
	var bar := ProgressBar.new()
	bar.name = "bar"
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(560, 16)
	var mk := func(tex: String) -> StyleBoxTexture:
		var st := StyleBoxTexture.new()
		st.texture = load("res://assets/ui/ai/%s.png" % tex)
		st.texture_margin_left = 8
		st.texture_margin_right = 8
		st.content_margin_left = 8
		st.content_margin_right = 8
		return st
	bar.add_theme_stylebox_override("background", mk.call("g_slider"))
	bar.add_theme_stylebox_override("fill", mk.call("g_slider_fill"))
	box.add_child(bar)
	var tip := Label.new()
	tip.text = ["Совет: лавки обслуживают только ближайшие дома — ставьте разные лавки среди домов.",
		"Совет: правая кнопка мыши отменяет выбранный инструмент.",
		"Совет: украшения рядом с домом дают до +12% счастья (у богатых — больше).",
		"Совет: щёлкните по значку дома в карточке, чтобы сменить его цвет.",
		"Совет: «Этаж» (U) — ведите мышью с зажатой кнопкой вдоль улицы, и этаж получат все готовые дома."][randi() % 5]
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_override("font", load("res://assets/fonts/AlegreyaSans-Medium.ttf"))
	tip.add_theme_font_size_override("font_size", 18)
	tip.add_theme_color_override("font_color", Color("f6e8cc"))
	tip.add_theme_color_override("font_outline_color", Color("3a2412"))
	tip.add_theme_constant_override("outline_size", 6)
	box.add_child(tip)


func _loading_hide() -> void:
	if loading == null:
		return
	var tw := create_tween()
	for ch in loading.get_children():
		if ch is CanvasItem:
			tw.parallel().tween_property(ch, "modulate:a", 0.0, 0.6)
	tw.tween_callback(loading.queue_free)
	loading = null


# ---------- настройки ----------

func settings_path() -> String:
	return save_path().get_base_dir().path_join("settings.json")


func _load_settings() -> void:
	if FileAccess.file_exists(settings_path()):
		var d = JSON.parse_string(FileAccess.get_file_as_string(settings_path()))
		if typeof(d) == TYPE_DICTIONARY:
			for k in d:
				settings[k] = d[k]
	if shot_path == "":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_MAXIMIZED)


func save_settings() -> void:
	var f := FileAccess.open(settings_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))
	apply_settings()


func apply_settings() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_MAXIMIZED)
	_apply_quality()
	if hud:
		hud.apply_scale(float(settings["ui_scale"]))


func _apply_quality() -> void:
	var q: String = settings["quality"]
	if env == null:
		return
	env.sdfgi_enabled = q == "high"
	env.ssil_enabled = q == "high"
	env.ssao_enabled = q != "low"
	env.glow_enabled = q != "low"
	if sun:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if q != "low" else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = 190.0 if q != "low" else 175.0
	# слабые ноутбуки: картинка считается в 75% размера и аккуратно растягивается (FSR), без размытия глубины
	var vp := get_viewport()
	if vp and shot_path == "":
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if q == "low" else Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = 0.75 if q == "low" else 1.0
	if rig and rig.attrs:
		rig.attrs.dof_blur_far_enabled = q != "low"
		rig.attrs.dof_blur_near_enabled = q != "low"
	Engine.max_fps = 60 if shot_path == "" else 0


# ---------- небо, солнце, свет, цвет ----------

func _environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("6f95c4")
	sky_mat.sky_horizon_color = Color("f0d0a4")
	sky_mat.ground_horizon_color = Color("d8bf98")
	sky_mat.ground_bottom_color = Color("6a5f4c")
	sky_mat.sun_angle_max = 25.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.tonemap_exposure = 1.1
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 2.6
	env.ssao_power = 1.5
	env.ssao_detail = 0.8
	env.ssao_light_affect = 0.3
	env.ssil_enabled = true
	env.ssil_radius = 3.0
	env.ssil_intensity = 0.6
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_bounce_feedback = 0.5
	env.sdfgi_min_cell_size = 0.25
	env.sdfgi_energy = 0.75
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color("e9c9a0")
	env.fog_density = 0.0009
	env.fog_aerial_perspective = 0.5
	env.fog_sky_affect = 0.45
	env.adjustment_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 190.0
	sun.light_angular_distance = 2.2
	sun.shadow_blur = 1.6
	add_child(sun)
	_apply_quality()


## Цветокоррекция и виньетка поверх кадра (интерфейс — выше, его не трогает)
func _grading() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 1
	add_child(cl)
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grade = ShaderMaterial.new()
	grade.shader = load("res://shaders/grade.gdshader")
	r.material = grade
	cl.add_child(r)


## Свет суток — как в Town to City: солнце не поднимается высоко (тени всегда видны), светит из-за домов
## сбоку; долгое золотое утро и вечер, короткая сиреневая ночь, при которой всё видно; фонари и окна
## загораются постепенно в сумерках. Цвет кадра — тёплые света и прохладные тени (grade.gdshader).
func _set_hour(h: float) -> void:
	hour = fposmod(h, 24.0)
	# день: 0 — ночь, 1 — полный день; рассвет 4.6–7.2, закат 18.6–21.6
	var day := smoothstep(4.3, 6.4, hour) * (1.0 - smoothstep(19.8, 22.4, hour))
	# золото: утро и вечер
	var gold := (smoothstep(4.5, 6.0, hour) * (1.0 - smoothstep(7.5, 10.5, hour))) + (smoothstep(15.5, 18.5, hour) * (1.0 - smoothstep(21.0, 22.4, hour)))
	gold = clampf(gold, 0.0, 1.0)
	# солнце: с востока на запад по северной стороне неба, высота не больше 46°
	var t := clampf((hour - 4.6) / 17.6, 0.0, 1.0)
	var ang := t * PI
	var elev := deg_to_rad(4.0 + 44.0 * sin(ang))
	# как в Town to City: солнце весь день справа — утром спереди-справа, днём сбоку, вечером сзади-справа;
	# тени ложатся влево, фасады то освещены, то в мягкой тени
	var flat := Vector3(1.0, 0.0, lerpf(0.9, -0.95, t)).normalized()
	var sun_dir := (flat * cos(elev) + Vector3.UP * sin(elev)).normalized()
	var moon_dir := Vector3(-0.35, 0.62, -0.5).normalized()
	var dir := moon_dir.lerp(sun_dir, smoothstep(0.0, 0.25, day)).normalized()
	var c := Vector3(Land.START.x, 0, Land.START.y)
	sun.look_at_from_position(c + dir * 200.0, c, Vector3.UP)
	var noon := Color("ffe8c8")
	var golden := Color("ffb070")
	# луна — мягкая сиренево-лавандовая, не ледяная синяя (ночь уютная, а не холодная)
	var night_c := Color("a3a6dc")
	var sun_c := noon.lerp(golden, gold)
	sun.light_color = night_c.lerp(sun_c, day)
	sun.light_energy = lerpf(1.5, lerpf(2.6, 2.9, gold), day)
	sky_mat.sky_top_color = Color("2e2a5c").lerp(Color("6f95c4").lerp(Color("9a8fc0"), gold * 0.6), day)
	sky_mat.sky_horizon_color = Color("665a92").lerp(Color("efd6b4").lerp(Color("f6a870"), gold), day)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color.darkened(0.1)
	# рассеянный свет: днём слабый и серо-сиреневый — тени глубокие; ночью сиреневый — всё видно, но темнее,
	# чтобы фонари, жаровни и огни арки лежали на мостовой тёплыми пятнами
	env.ambient_light_energy = lerpf(1.25, lerpf(0.5, 0.66, gold), day)
	env.ambient_light_color = Color("8a90c8").lerp(Color("c4b8c8"), day)
	env.ambient_light_sky_contribution = lerpf(0.35, 0.3, day)
	env.fog_light_color = Color("585088").lerp(Color("e9d2b0").lerp(Color("f2b07a"), gold * 0.8), day)
	(_puff_quad().material as StandardMaterial3D).albedo_color = Color(0.55, 0.55, 0.7).lerp(Color(1, 1, 1).lerp(Color(1.0, 0.85, 0.7), gold * 0.6), day)
	if grade:
		var g_day := Vector3(1.07, 0.97, 0.84)
		var g_gold := Vector3(1.08, 0.95, 0.82)
		# ночь: сиреневая, но не ледяная — синеву притушили, а тёплый свет фонарей шейдер не подсинивает (warm_keep)
		var g_night := Vector3(0.88, 0.86, 1.18)
		var gain := g_night.lerp(g_day.lerp(g_gold, gold), day)
		grade.set_shader_parameter("gain", gain)
		grade.set_shader_parameter("shadow_tint", Vector3(0.93, 0.88, 1.05).lerp(Vector3(0.86, 0.84, 0.95).lerp(Vector3(0.84, 0.8, 0.92), gold), day))
		grade.set_shader_parameter("green_shift", lerpf(0.15, 0.6, day))
		grade.set_shader_parameter("tint", Vector3(1.02, 1.07, 1.34).lerp(Vector3.ONE, day))
		grade.set_shader_parameter("sat", lerpf(0.95, lerpf(1.04, 0.93, gold), day))
		grade.set_shader_parameter("warm_keep", 1.0 - smoothstep(0.15, 0.7, day))
		grade.set_shader_parameter("contrast", lerpf(1.06, 1.14, day))
	# окна и фонари: разгораются в сумерках. Окна домов и лавок — еле тёплый огонёк, как от спички
	# (улицу освещают фонари и жаровни, а не дома); к полуночи и он почти гаснет
	var lamp := 1.0 - smoothstep(0.15, 0.7, day)
	var lm := (Parts._special_mesh("#lit") as PrimitiveMesh).material as StandardMaterial3D
	if lm:
		lm.emission_energy_multiplier = lamp * (0.018 if hour > 23.0 or hour < 4.0 else 0.045)
	var em := (Parts._special_mesh("#ember") as PrimitiveMesh).material as StandardMaterial3D
	if em:
		em.emission_energy_multiplier = lamp * 1.6
	Parts._glass_material().emission_energy_multiplier = lamp * 3.0
	Parts._glass_dim_material().emission_energy_multiplier = lamp * 3.0 * HOUSE_LIGHT
	for l in night_lights:
		var k: float = l.get_meta("k", 1.0)
		l.visible = lamp * k > 0.02
		# фонари, жаровни и огни арки — заметные тёплые пятна; огонёк у жилого дома остаётся еле видным
		l.light_energy = lamp * k * (2.6 if k >= 1.0 else 1.6)


# ---------- вода, въезд, пейзаж до горизонта, природа ----------

func _water() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(Land.SIZE + 8.0, Land.SIZE + 8.0)
	pm.subdivide_width = 200
	pm.subdivide_depth = 200
	mi.mesh = pm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/water.gdshader")
	mi.material_override = sm
	mi.position = Vector3(Land.SIZE / 2.0, Land.WATER_Y, Land.SIZE / 2.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Арка на въезде на свою землю: большая дорога проходит под ней (чертёж — Entrance.gate_bp). Опоры и колонны
## занимают землю (там не построить и не пройти), ночью горят фонари на опорах и огненные чаши на колоннах
func _gate() -> void:
	var g := Land.GATE
	var y := land.height_at(g.x, g.y)
	var xf := Transform3D(Basis(Vector3.UP, 0.0), Vector3(g.x, y, g.y))
	var bp := Entrance.gate_bp()
	parts.place(bp, xf)
	for lp in bp.lights:
		_light(xf * lp)
	land.set_occ(land.footprint_cells(Entrance.solid_rects(), g, 0.0), -1)


var far_xs := PackedFloat32Array()      # сетка пейзажа за краем карты (линии x и z) и высоты в её узлах
var far_zs := PackedFloat32Array()
var far_hy := PackedFloat32Array()


## Высота пейзажа за краем карты ровно по его сетке (деревья и цветы стоят на земле, а не висят)
func far_y(x: float, z: float) -> float:
	var i := clampi(far_xs.bsearch(x) - 1, 0, far_xs.size() - 2)
	var j := clampi(far_zs.bsearch(z) - 1, 0, far_zs.size() - 2)
	var nx := far_xs.size()
	var u := clampf((x - far_xs[i]) / (far_xs[i + 1] - far_xs[i]), 0.0, 1.0)
	var v := clampf((z - far_zs[j]) / (far_zs[j + 1] - far_zs[j]), 0.0, 1.0)
	var h00 := far_hy[j * nx + i]
	var h10 := far_hy[j * nx + i + 1]
	var h01 := far_hy[(j + 1) * nx + i]
	var h11 := far_hy[(j + 1) * nx + i + 1]
	# треугольники сетки делятся диагональю 00–11
	if u >= v:
		return h00 + (h10 - h00) * u + (h11 - h10) * v
	return h00 + (h11 - h01) * u + (h01 - h00) * v


## Пейзаж до горизонта: за краем карты земля продолжается без шва — тот же шейдер земли (вид 8: те же пятна
## травы клетками по 25 см, ступеньки-горизонтали, тот же оттенок чужой земли), рощи, кусты, цветы и трава
## как на карте, дальше холмы и горы в дымке; большая дорога уходит на север за горизонт. Сетка мельче у края
## карты (4 м) и у дороги (1 м поперёк, 2 м вдоль), дальше — 16 м. По краю карты — юбка вниз (щелей нет).
func _horizon() -> void:
	var S := Land.SIZE
	var R := 1600.0
	var lo := S / 2.0 - R
	var hi := S / 2.0 + R
	var lines := func(fine: Array) -> PackedFloat32Array:
		var set := {}
		var t := lo
		while t <= hi + 0.01:
			set[snappedf(t, 0.001)] = true
			t += 32.0
		for f: Array in fine:
			t = f[0]
			while t <= float(f[1]) + 0.001:
				set[snappedf(t, 0.001)] = true
				t += float(f[2])
		var arr := set.keys()
		arr.sort()
		return PackedFloat32Array(arr)
	# 32 м вдали, 8 м до 192 м от края, 4 м до 64 м (вдоль всего края — чтобы край пейзажа повторял край карты)
	var rings := [[-192.0, S + 192.0, 8.0], [-64.0, S + 64.0, 4.0]]
	far_xs = lines.call(rings + [[Land.ROAD_X - 24.0, Land.ROAD_X + 24.0, 1.0]])
	far_zs = lines.call(rings + [[-128.0, 0.0, 2.0]])
	var nx := far_xs.size()
	var nz := far_zs.size()
	far_hy.resize(nx * nz)
	for j in nz:
		for i in nx:
			far_hy[j * nx + i] = land.far_height(far_xs[i], far_zs[j])
	var fz := FastNoiseLite.new()
	fz.seed = 8
	fz.frequency = 0.012
	# крупные пятна потемнее и посветлее (вдали, где мелкие пятна сливаются) — в тех же оттенках чужой земли
	var g0 := (Land.C_GRASS[0] as Color).lerp(Land.LOCK, 0.18)
	var g3 := (Land.C_GRASS[3] as Color).lerp(Land.LOCK, 0.18)
	for gi in 4:
		var gc := (Land.C_GRASS[gi] as Color).lerp(Land.LOCK, 0.18).srgb_to_linear()
		land_mat.set_shader_parameter("far_g%d" % gi, Vector3(gc.r, gc.g, gc.b))
	land_mat.set_shader_parameter("far_road_x", Land.ROAD_X)
	land_mat.set_shader_parameter("far_road_half", Land.ROAD_R)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	verts.resize(nx * nz)
	norms.resize(nx * nz)
	cols.resize(nx * nz)
	uvs.resize(nx * nz)
	for j in nz:
		for i in nx:
			var k := j * nx + i
			var x := far_xs[i]
			var z := far_zs[j]
			var y := far_hy[k]
			verts[k] = Vector3(x, y, z)
			var ia := maxi(i - 1, 0)
			var ib := mini(i + 1, nx - 1)
			var ja := maxi(j - 1, 0)
			var jb := mini(j + 1, nz - 1)
			var gx := (far_hy[j * nx + ib] - far_hy[j * nx + ia]) / (far_xs[ib] - far_xs[ia])
			var gz := (far_hy[jb * nx + i] - far_hy[ja * nx + i]) / (far_zs[jb] - far_zs[ja])
			# у края — нормаль вверх, как у ступенек земли на карте (склон видно по горизонталям); вдали — настоящая
			var dd := Vector2(maxf(maxf(-x, x - S), 0.0), maxf(maxf(-z, z - S), 0.0)).length()
			norms[k] = Vector3.UP.lerp(Vector3(-gx, 1.0, -gz).normalized(), smoothstep(40.0, 220.0, dd)).normalized()
			var tone := clampf(0.5 + fz.get_noise_2d(x, z) * 0.9, 0.0, 1.0)
			cols[k] = g0.lerp(g3, tone).srgb_to_linear()
			uvs[k] = Vector2(8.0, y)
	var ix := PackedInt32Array()
	for j in nz - 1:
		for i in nx - 1:
			var cx := (far_xs[i] + far_xs[i + 1]) * 0.5
			var cz := (far_zs[j] + far_zs[j + 1]) * 0.5
			if cx > 0.0 and cz > 0.0 and cx < S and cz < S:
				continue                      # внутри карты — там своя земля
			var a := j * nx + i
			# обход как у кусков земли (Land.chunk_mesh): (00, 11, 01) и (00, 10, 11) — диагональ 00–11
			ix.append_array([a, a + nx + 1, a + nx, a, a + 1, a + nx + 1])
	# юбка по краю карты: от края пейзажа вниз на 1 м лицом внутрь (если земля у края чуть ниже — не видно щели)
	var skirt := func(a: Vector2, b: Vector2, ya: float, yb: float, n: Vector3) -> void:
		var base := verts.size()
		verts.append_array([Vector3(b.x, yb - 1.0, b.y), Vector3(b.x, yb, b.y), Vector3(a.x, ya, a.y), Vector3(a.x, ya - 1.0, a.y)])
		norms.append_array([n, n, n, n])
		var c := g0.srgb_to_linear()
		cols.append_array([c, c, c, c])
		var u := Vector2(1.0, maxf(ya, yb))
		uvs.append_array([u, u, u, u])
		ix.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
	var j0 := far_zs.find(0.0)
	var j1 := far_zs.find(S)
	var i0 := far_xs.find(0.0)
	var i1 := far_xs.find(S)
	for i in range(i0, i1):
		var xa := far_xs[i]
		var xb := far_xs[i + 1]
		skirt.call(Vector2(xa, 0.0), Vector2(xb, 0.0), far_hy[j0 * nx + i], far_hy[j0 * nx + i + 1], Vector3(0, 0, 1))      # север: лицом внутрь
		skirt.call(Vector2(xb, S), Vector2(xa, S), far_hy[j1 * nx + i + 1], far_hy[j1 * nx + i], Vector3(0, 0, -1))
	for j in range(j0, j1):
		var za := far_zs[j]
		var zb := far_zs[j + 1]
		skirt.call(Vector2(0.0, zb), Vector2(0.0, za), far_hy[(j + 1) * nx + i0], far_hy[j * nx + i0], Vector3(1, 0, 0))
		skirt.call(Vector2(S, za), Vector2(S, zb), far_hy[j * nx + i1], far_hy[(j + 1) * nx + i1], Vector3(-1, 0, 0))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = ix
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = land_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_far_nature()
	# дальние леса: деревья пятнами (без теней — далеко)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var batches := {}
	for k in 16000:
		var p := Vector2(rng.randf_range(-640.0, S + 640.0), rng.randf_range(-640.0, S + 640.0))
		var dx := maxf(maxf(-p.x, p.x - S), 0.0)
		var dz := maxf(maxf(-p.y, p.y - S), 0.0)
		var d := sqrt(dx * dx + dz * dz)
		if d < 110.0:
			continue                          # ближе — рощи как на карте (_far_nature)
		if p.y < 0.0 and absf(p.x - Land.ROAD_X) < Land.ROAD_R + 6.0 + d * 0.02:
			continue                          # на большой дороге деревья не растут
		if fz.get_noise_2d(p.x, p.y) < 0.05 and rng.randf() < 0.85:
			continue
		var nm := ("SM_Env_Tree_0%d" % (1 + rng.randi() % 4)) if rng.randf() < 0.7 else ("SM_Env_Tree_Thin_0%d" % (1 + rng.randi() % 2))
		var y: float = far_y(p.x, p.y)
		var key := "%s|%d,%d" % [nm, floori(p.x / 400.0), floori(p.y / 400.0)]
		if not batches.has(key):
			batches[key] = {"name": nm, "list": [], "shadow": false, "range": 0.0}
		batches[key]["list"].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.45, 0.8)), Vector3(p.x, y - 0.3, p.y)))
	_batch_mm(batches)


## Природа за краем карты вблизи (до 110 м): те же рощи (тот же шум лесов, что в _nature), одиночные деревья,
## кусты, цветы, трава и камешки той же густоты — край карты не виден по природе. Их нельзя снести: там не наша земля
func _far_nature() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var fn := FastNoiseLite.new()
	fn.seed = 77
	fn.frequency = 0.02
	var S := Land.SIZE
	var B := 110.0
	var n := int((S + 2.0 * B) * (S + 2.0 * B) * 52000.0 / (S * S))
	var batches := {}
	for k in n:
		var x := rng.randf_range(-B, S + B)
		var z := rng.randf_range(-B, S + B)
		var r := rng.randf()
		if x > -0.5 and z > -0.5 and x < S + 0.5 and z < S + 0.5:
			continue
		if z < 0.0 and absf(x - Land.ROAD_X) < 7.0:
			continue                          # у большой дороги — чисто
		var forest := fn.get_noise_2d(x, z)
		var name := ""
		var s := 1.0
		if forest > 0.3 and r < 0.3:
			var t := rng.randf()
			if t < 0.55:
				name = "SM_Env_Tree_0%d" % (1 + rng.randi() % 4)
				s = rng.randf_range(0.42, 0.66)
			elif t < 0.75:
				name = "SM_Env_Tree_Large_0%d" % (1 + rng.randi() % 3)
				s = rng.randf_range(0.3, 0.42)
			elif t < 0.9:
				name = "SM_Env_Tree_Thin_0%d" % (1 + rng.randi() % 2)
				s = rng.randf_range(0.6, 0.95)
			else:
				name = "SM_Env_Bush_Cluster_0%d" % (1 + rng.randi() % 5)
				s = rng.randf_range(0.6, 1.0)
		elif r < 0.004:
			name = "SM_Env_Tree_0%d" % (1 + rng.randi() % 4)
			s = rng.randf_range(0.42, 0.62)
		elif r < 0.008:
			name = "SM_Env_Tree_Thin_0%d" % (1 + rng.randi() % 2)
			s = rng.randf_range(0.6, 0.9)
		elif r < 0.022:
			name = "SM_Env_Tree_Bush_0%d" % (1 + rng.randi() % 3)
			s = rng.randf_range(0.5, 0.8)
		elif r < 0.07:
			name = "SM_Env_Flowers_0%d" % (1 + rng.randi() % 5)
			s = rng.randf_range(1.0, 1.8)
		elif r < 0.13:
			name = "SM_Env_Grass_0%d" % (1 + rng.randi() % 3)
			s = rng.randf_range(0.7, 1.2)
		elif r < 0.137:
			name = "SM_Env_Rock_Cliff_02"
			s = rng.randf_range(0.12, 0.25)
		else:
			continue
		var y := far_y(x, z) - (0.1 if name.contains("Rock") else 0.0)
		var small := name.contains("Grass") or name.contains("Flowers")
		var key := "%s|%d,%d" % [name, floori(x / 160.0), floori(z / 160.0)]
		if not batches.has(key):
			batches[key] = {"name": name, "list": [], "shadow": not small, "range": 150.0 if small else 0.0}
		batches[key]["list"].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, y, z)))
	_batch_mm(batches)


## Много одинаковых деталей одним MultiMesh на кусок: batches[ключ] = {name, list: [Transform3D], shadow, range}
func _batch_mm(batches: Dictionary) -> void:
	var srcs := {}
	for key in batches:
		var bt: Dictionary = batches[key]
		var nm: String = bt["name"]
		if not srcs.has(nm):
			var tinted := nm.begins_with("SM_Env_Tree") or nm.begins_with("SM_Env_Bush")
			var src := Synty.make(nm, {"tint": Synty.GREEN} if tinted else {})
			var subs := []
			for smi: MeshInstance3D in src.find_children("*", "MeshInstance3D", true, false):
				var mesh := smi.mesh.duplicate() as Mesh
				for si in mesh.get_surface_count():
					var sm := smi.get_surface_override_material(si)
					if sm:
						mesh.surface_set_material(si, sm)
				subs.append([mesh, Citizen._rel(smi, src)])
			src.free()
			srcs[nm] = subs
		var list: Array = bt["list"]
		for sub: Array in srcs[nm]:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = sub[0]
			mm.instance_count = list.size()
			var local: Transform3D = sub[1]
			for k in list.size():
				mm.set_instance_transform(k, (list[k] as Transform3D) * local)
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bt["shadow"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if float(bt["range"]) > 0.0:
				mmi.visibility_range_end = float(bt["range"])
				mmi.visibility_range_end_margin = 20.0
				mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			add_child(mmi)


## Скалы на крутых склонах (вместо голых стенок уступов)
func _cliff_rocks() -> void:
	var bp := Bp.new(17)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for n in 3000:
		var x := rng.randf_range(2.0, Land.SIZE - 2.0)
		var z := rng.randf_range(2.0, Land.SIZE - 2.0)
		var c := land.cell(Vector2(x, z))
		var k := land.idx(c.x, c.y)
		if land.occ[k] != 0 or not land.is_rock(k) or Vector2(x, z).distance_to(Land.HILL) < 30.0:
			continue
		var y := land.height_at(x, z)
		bp.add("SM_Env_Rock_Cliff_02", Vector3(x, y - 0.3, z), rng.randf() * TAU, rng.randf_range(0.3, 0.55))
	parts.place(bp, Transform3D.IDENTITY)


# ---------- игры в честь богов: город наряжен ----------

var fest_vis := {}                       # наряд праздника: {h: детали в пуле, mesh: гирлянды}
const FEST_Z := [70, 78, 86, 94, 102, 110, 118]   # где вдоль большой дороги (от арки к станции) встают шесты парами
const FEST_SIDE := 3.3                   # шесты — так далеко от середины дороги (она 4,5 м шириной)
const FEST_POLE := 1.4                   # шест выше обычного (3 м × 1,4): гирлянда над повозкой
const FEST_SAG := 0.55                   # гирлянда провисает посередине
const FEST_COLORS := [Color("b8322a"), Color("e8b13c"), Color("f2ead4"), Color("3d6fa3"), Color("c25a1c"), Color("4f8a3a")]


## Игры в честь богов (City.festival): вдоль большой дороги от арки до станции — шесты со знамёнами парами и гирлянды
## флажков поперёк дороги; жители сходятся на площадь у станции (People._fest_target). Шесты и знамёна — в общем пуле
## деталей (MultiMesh), все гирлянды — одна сетка без теней: слабым ноутбукам не тяжело. Где у дороги стоит дом
## игрока — шеста нет
func _fest_look(on: bool) -> void:
	if not fest_vis.is_empty():
		parts.remove(fest_vis["h"])
		if fest_vis["mesh"] != null:
			(fest_vis["mesh"] as Node).queue_free()
		fest_vis = {}
	if not on or mode in ["menu", "demo"]:
		return
	var h := []
	var lines := []
	var k := 0
	var prev := {}                           # сторона дороги → верх прошлого шеста (гирлянда вдоль дороги)
	for z: int in FEST_Z:
		var tops := {}
		for side: float in [-1.0, 1.0]:
			var p := _fest_spot(Vector2(Land.ROAD_X + side * FEST_SIDE, float(z)), side)
			if p == Vector2.INF:
				prev.erase(side)
				continue
			var y := land.height_at(p.x, p.y)
			h.append_array(parts.place_one("SM_Prop_Pole_02", Transform3D(Basis.from_scale(Vector3(1.0, FEST_POLE, 1.0)), Vector3(p.x, y, p.y))))
			# знамя поперёк дороги, к ней половиной: видно и с дороги, и сбоку
			var ban := "SM_Prop_Banner_02_%s" % ["A", "C", "E", "G", "B", "H", "D"][k % 7]
			h.append_array(parts.place_one(ban, Transform3D(Basis.IDENTITY, Vector3(p.x - side * 0.5, y + 3.0 * FEST_POLE - 0.35, p.y))))
			var top := Vector3(p.x, y + 3.0 * FEST_POLE - 0.05, p.y)
			if prev.has(side):
				lines.append([prev[side], top])
			prev[side] = top
			tops[side] = top
			k += 1
		if tops.size() == 2:
			lines.append([tops[-1.0], tops[1.0]])
	var mi: MeshInstance3D = null
	if not lines.is_empty():
		mi = MeshInstance3D.new()
		mi.mesh = _garlands(lines)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	fest_vis = {"h": h, "mesh": mi}


## Место для шеста у дороги (сдвигаем от дороги до 1,6 м): своя трава или земля, не вода, не мостовая, без построек рядом
func _fest_spot(p: Vector2, side: float) -> Vector2:
	for k in 3:
		var q := p + Vector2(side * 0.8 * k, 0.0)
		var c := land.cell(q)
		var ok := land.inside(c.x, c.y) and not land.is_water(q) and not Land.walk_kind(land.kind[land.idx(c.x, c.y)])
		for j in range(c.y - 2, c.y + 3):
			for i in range(c.x - 2, c.x + 3):
				if ok and (not land.inside(i, j) or land.occ[land.idx(i, j)] != 0):
					ok = false
		if ok:
			return q
	return Vector2.INF


## Гирлянды флажков поперёк дороги: шнур провисает, на нём треугольные флажки разных цветов (одна сетка на все)
static func _garlands(lines: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var k := 0
	for ln: Array in lines:
		var a: Vector3 = ln[0]
		var b: Vector3 = ln[1]
		var n := maxi(6, int(a.distance_to(b) / 0.42))
		var nrm := (b - a).cross(Vector3.UP).normalized()
		var pts := []
		for i in n + 1:
			var u := float(i) / n
			pts.append(a.lerp(b, u) + Vector3.DOWN * FEST_SAG * 4.0 * u * (1.0 - u))
		for i in n:
			var p0: Vector3 = pts[i]
			var p1: Vector3 = pts[i + 1]
			_tri(st, p0, p1, p1 + Vector3.DOWN * 0.045, Color("5a3d22"), nrm)          # шнур
			_tri(st, p0, p1 + Vector3.DOWN * 0.045, p0 + Vector3.DOWN * 0.045, Color("5a3d22"), nrm)
			var q0 := p0.lerp(p1, 0.06)
			var q1 := p0.lerp(p1, 0.94)
			_tri(st, q0, q1, (q0 + q1) * 0.5 + Vector3.DOWN * 0.48, FEST_COLORS[k % FEST_COLORS.size()], nrm)   # флажок
			k += 1
	var m := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.9
	if m.get_surface_count() > 0:
		m.surface_set_material(0, mat)
	return m


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, nrm: Vector3) -> void:
	for v: Vector3 in [a, b, c]:
		st.set_color(col)
		st.set_normal(nrm)
		st.add_vertex(v)


## Ночной огонёк; k — доля яркости (1 — фонари и жаровни, у жилых домов — еле теплится)
func _light(at: Vector3, k := 1.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.set_meta("k", k)
	l.position = at
	# цвет насыщеннее, чем кажется: ночная цветокоррекция подсинивает тёмное — пятно света остаётся тёплым
	l.light_color = Color("ffb366")
	l.omni_range = 4.6
	l.omni_attenuation = 1.4
	l.light_energy = 1.4
	l.shadow_enabled = false
	add_child(l)
	night_lights.append(l)
	return l


## Рощи пятнами, луга с цветами и травой, кусты. Каждое дерево и камень — отдельные: их можно снести или перенести
func _nature() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var fn := FastNoiseLite.new()
	fn.seed = 77
	fn.frequency = 0.02
	for n in 52000:
		var x := rng.randf_range(1.0, Land.SIZE - 1.0)
		var z := rng.randf_range(1.0, Land.SIZE - 1.0)
		var p := Vector2(x, z)
		var c := land.cell(p)
		var k := land.idx(c.x, c.y)
		if land.kind[k] != Land.Kind.GRASS or land.occ[k] != 0 or land.is_water(p):
			continue
		var near_b := false
		for o: Vector2 in [Vector2(3.0, 0), Vector2(-3.0, 0), Vector2(0, 3.0), Vector2(0, -3.0)]:
			if land.occ_at(p + o) != 0 or land.is_road(p + o):
				near_b = true
		if near_b:
			continue
		if p.distance_to(Land.CENTER) < 14.0 or (absf(x - Land.TUNNEL.x) < 7.0 and z > Land.TUNNEL.y - 1.0 and z < 136.0):
			continue
		var y := land.height_at(x, z)
		var forest := fn.get_noise_2d(x, z)
		var ds := maxf(absf(x - Land.START.x) - 40.0, absf(z - Land.START.y) - 40.0)
		forest -= (1.0 - smoothstep(-20.0, 30.0, ds)) * 0.35       # у города рощ меньше
		var r := rng.randf()
		var name := ""
		var s := 1.0
		if forest > 0.3 and r < 0.3:
			var t := rng.randf()
			if t < 0.55:
				name = "SM_Env_Tree_0%d" % (1 + rng.randi() % 4)
				s = rng.randf_range(0.42, 0.66)
			elif t < 0.75:
				name = "SM_Env_Tree_Large_0%d" % (1 + rng.randi() % 3)
				s = rng.randf_range(0.3, 0.42)
			elif t < 0.9:
				name = "SM_Env_Tree_Thin_0%d" % (1 + rng.randi() % 2)
				s = rng.randf_range(0.6, 0.95)
			else:
				name = "SM_Env_Bush_Cluster_0%d" % (1 + rng.randi() % 5)
				s = rng.randf_range(0.6, 1.0)
		elif r < 0.004:
			name = "SM_Env_Tree_0%d" % (1 + rng.randi() % 4)
			s = rng.randf_range(0.42, 0.62)
		elif r < 0.008:
			name = "SM_Env_Tree_Thin_0%d" % (1 + rng.randi() % 2)
			s = rng.randf_range(0.6, 0.9)
		elif r < 0.022:
			name = "SM_Env_Tree_Bush_0%d" % (1 + rng.randi() % 3)
			s = rng.randf_range(0.5, 0.8)
		elif r < 0.07:
			name = "SM_Env_Flowers_0%d" % (1 + rng.randi() % 5)
			s = rng.randf_range(1.0, 1.8)
		elif r < 0.13:
			name = "SM_Env_Grass_0%d" % (1 + rng.randi() % 3)
			s = rng.randf_range(0.7, 1.2)
		elif r < 0.137:
			name = "SM_Env_Rock_Cliff_02"
			s = rng.randf_range(0.12, 0.25)
		else:
			continue
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, y - (0.1 if name.contains("Rock") else 0.0), z))
		_add_nature(name, xf, p)


func _add_nature(name: String, xf: Transform3D, p: Vector2) -> void:
	var key := Vector2i(int(p.x / 2.0), int(p.y / 2.0))
	if not nature.has(key):
		nature[key] = []
	var tinted := name.begins_with("SM_Env_Tree") or name.begins_with("SM_Env_Garden") or name.begins_with("SM_Env_Bush")
	var remap := {"tint": Synty.GREEN} if tinted else {}
	nature[key].append({"h": parts.place_one(name, xf, remap, true), "p": p, "name": name, "xf": xf, "remap": remap})


## Дерево, куст или камень под курсором (их можно снести и перенести, как в Town to City)
func nature_at(p: Vector2) -> Dictionary:
	var best := {}
	var bd := 1.6
	for kz in range(int(p.y / 2.0) - 1, int(p.y / 2.0) + 2):
		for kx in range(int(p.x / 2.0) - 1, int(p.x / 2.0) + 2):
			for it in nature.get(Vector2i(kx, kz), []):
				var nm: String = it["name"]
				if nm.contains("Grass") or nm.contains("Flowers") or nm.contains("Lillies"):
					continue
				var d := (it["p"] as Vector2).distance_to(p)
				var r := 1.6 if nm.contains("Tree") else 1.0
				if d < r and d < bd:
					bd = d
					best = it
	return best


func remove_nature(it: Dictionary) -> void:
	var key := Vector2i(int((it["p"] as Vector2).x / 2.0), int((it["p"] as Vector2).y / 2.0))
	parts.remove(it["h"])
	(nature.get(key, []) as Array).erase(it)


## У прудов: камыши, кувшинки, утки и лебеди плавают кругами
func _ponds_life() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for pd in Land.PONDS:
		var c3: Vector3 = pd[0]
		var c := Vector2(c3.x, c3.y)
		var r := c3.z
		for k in int(r * 5):
			var a := rng.randf() * TAU
			var q := c + Vector2(cos(a), sin(a)) * r * rng.randf_range(0.85, 1.12)
			var y := land.height_at(q.x, q.y)
			if y > Land.WATER_Y + 0.6:
				continue
			_add_nature("SM_Env_Grass_0%d" % (1 + rng.randi() % 3), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.0, 1.6)), Vector3(q.x, maxf(y, Land.WATER_Y - 0.1), q.y)), q)
		for k in int(r * 0.8):
			var a := rng.randf() * TAU
			var q := c + Vector2(cos(a), sin(a)) * r * rng.randf_range(0.2, 0.6)
			_add_nature("SM_Env_Lillies_0%d" % (1 + rng.randi() % 3), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(q.x, Land.WATER_Y + 0.01, q.y)), q)
		for k in 2 + int(r / 6.0):
			var swan := rng.randf() < 0.35
			var mi := MeshInstance3D.new()
			mi.mesh = Parts._special_mesh("#swan" if swan else "#duck")
			add_child(mi)
			swimmers.append({"n": mi, "c": c, "r": r * rng.randf_range(0.25, 0.5), "a": rng.randf() * TAU, "w": rng.randf_range(0.05, 0.12) * (1.0 if rng.randf() < 0.5 else -1.0), "ph": rng.randf() * TAU})


func _swim(dt: float) -> void:
	var t := AnimClock.now()
	for s in swimmers:
		s["a"] = float(s["a"]) + float(s["w"]) * dt * maxf(0.2, speed)
		var a: float = s["a"]
		var rr: float = float(s["r"]) * (1.0 + 0.15 * sin(a * 2.0 + float(s["ph"])))
		var p: Vector2 = (s["c"] as Vector2) + Vector2(cos(a), sin(a)) * rr
		var n: Node3D = s["n"]
		n.position = Vector3(p.x, Land.WATER_Y + sin(t * 1.6 + float(s["ph"])) * 0.015, p.y)
		var dir := Vector2(-sin(a), cos(a)) * signf(float(s["w"]))
		n.rotation.y = atan2(dir.x, dir.y)


## Убрать природу под постройкой (по клеткам следа) или под кистью
func clear_nature(c: Vector2, r: float, cells := PackedInt32Array()) -> void:
	var cellset := {}
	for k in cells:
		cellset[k] = true
	for kz in range(int((c.y - r) / 2.0) - 1, int((c.y + r) / 2.0) + 2):
		for kx in range(int((c.x - r) / 2.0) - 1, int((c.x + r) / 2.0) + 2):
			var key := Vector2i(kx, kz)
			if not nature.has(key):
				continue
			var keep := []
			for it in nature[key]:
				var p: Vector2 = it["p"]
				var inside := false
				if cellset.is_empty():
					inside = p.distance_to(c) <= r
				else:
					var cc := land.cell(p)
					for dj in range(-2, 3):
						for di in range(-2, 3):
							if cellset.has(land.idx(clampi(cc.x + di, 0, Land.N - 1), clampi(cc.y + dj, 0, Land.N - 1))):
								inside = true
				if inside:
					parts.remove(it["h"])
				else:
					keep.append(it)
			nature[key] = keep


# ---------- земля ----------

func _build_chunk(ch: Vector2i) -> void:
	var mi: MeshInstance3D = chunk_nodes.get(ch)
	if mi == null:
		mi = MeshInstance3D.new()
		mi.material_override = land_mat
		add_child(mi)
		chunk_nodes[ch] = mi
	mi.mesh = land.chunk_mesh(ch.x, ch.y)


func _rebuild_land(limit := 6) -> void:
	var done := []
	for ch in land.dirty.keys():
		if done.size() >= limit:
			break
		done.append(ch)
	for ch in done:
		land.dirty.erase(ch)
		_build_chunk(ch)
		if surf_img:
			land.update_surface(surf_img, ch)
	if surf_tex and not done.is_empty():
		surf_img.generate_mipmaps()
		surf_tex.update(surf_img)
	if people and people.land and not done.is_empty():
		people.refresh(done)


# ---------- постройки: картинка ----------

var build_anim := false               # постройка поставлена игроком — показать, как она растёт

func _on_added(b: Dictionary) -> void:
	if build_anim and city.def(b)["kind"] != "decor":
		_grow_anim(b)
	else:
		_show(b)
	if not (b["cells"] as PackedInt32Array).is_empty():
		clear_nature(b["pos"], 14.0, b["cells"])
	var bp: Vector2 = b["pos"]
	if not fest_vis.is_empty() and absf(bp.x - Land.ROAD_X) < 16.0 and bp.y > FEST_Z[0] - 12 and bp.y < FEST_Z[-1] + 12:
		_fest_look(true)                       # новый дом у дороги во время игр — шесты переставим, чтобы не торчали из стены


## Стройка как в Town to City: здание вырастает из земли за пару секунд, в пыли; потом — настоящее
func _grow_anim(b: Dictionary) -> void:
	var g := Parts.ghost(city.blueprint(b), "place", Color(1.0, 0.95, 0.85, 0.35))
	var xf := city.xf(b)
	g.transform = xf
	g.scale = Vector3(1.0, 0.04, 1.0)
	add_child(g)
	var id: int = b["id"]
	var tw := create_tween()
	tw.tween_property(g, "scale", Vector3(1.0, 1.06, 1.0), 1.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(g, "scale", Vector3.ONE, 0.18)
	tw.tween_callback(func():
		g.queue_free()
		if city.buildings.has(id):
			_show(city.buildings[id])
			_puff(Vector3(b["pos"].x, float(b["y"]) + 0.3, b["pos"].y), Color("efe3c8")))
	for k in 3:
		get_tree().create_timer(0.35 * k).timeout.connect(func(): _puff(xf.origin + Vector3(randf_range(-1.5, 1.5), 0.2, randf_range(-1.5, 1.5)), Color("e8dcc4")))


func _show(b: Dictionary) -> void:
	_hide(b)
	var bp := city.blueprint(b)
	var xf := city.xf(b)
	var lit := city.is_house(b) and int(b["pop"]) > 0
	# у жилых домов фонарик у двери и окна ночью еле теплятся, как спичка: улицу светят фонари-украшения
	var subst := {"#wall_lamp": "#wall_lamp_dim"} if city.is_house(b) else {}
	if lit:
		subst["#dark"] = "#lit"
	var vis := {"h": parts.place(bp, xf, subst), "lights": [], "smoke": [], "actors": []}
	for lp in bp.lights:
		vis["lights"].append(_light(xf * lp, HOUSE_LIGHT if city.is_house(b) else 1.0))
	var lived: bool = not city.is_house(b) or int(b["pop"]) > 0
	if lived and (int(b["id"]) % 3 == 0 or not city.is_house(b)):    # дымок — тонкой струйкой и не над каждым домом
		for sp in bp.smoke.slice(0, 1):
			vis["smoke"].append(_smoke(xf * sp))
	visuals[b["id"]] = vis
	if Defs.base_of(b["type"]) == "sheep":      # овцы бродят по лугу любого облика
		_sheep(b, vis)
	_sync_actors(b)
	_set_hour(hour)


func _hide(b: Dictionary) -> void:
	var vis: Dictionary = visuals.get(b["id"], {})
	if vis.is_empty():
		return
	parts.remove(vis["h"])
	for l in vis["lights"]:
		night_lights.erase(l)
		(l as Node).queue_free()
	for s in vis["smoke"]:
		(s as Node).queue_free()
	for a in vis.get("actors", []) + vis.get("pets", []):
		(a as Node).queue_free()
	visuals.erase(b["id"])


func _on_removed(b: Dictionary) -> void:
	_hide(b)
	_puff(Vector3(b["pos"].x, b["y"], b["pos"].y))
	if selected.get("id", -1) == b["id"]:
		select_building({})


func _on_house_changed(b: Dictionary, up: bool) -> void:
	# новую станцию покажет ролик «Новый ранг» — до него стоит старая
	var held: bool = up and b["type"] == "center" and rank_cine != null and rank_cine.holds_station()
	if not held:
		_show(b)
		if up:
			_puff(Vector3(b["pos"].x, b["y"], b["pos"].y), Color("fff3c8"))
	if hud:
		hud.house_event(b, up)
	if selected.get("id", -1) == b["id"]:
		select_building(b)


static var _sheep_scene: PackedScene


## Две овечки пасутся (модель Quaternius CC0)
func _sheep(b: Dictionary, vis: Dictionary) -> void:
	if _sheep_scene == null:
		_sheep_scene = load("res://assets/animals/Sheep_a.glb")
	var rng := RandomNumberGenerator.new()
	rng.seed = int(b["id"])
	for k in 2:
		var sh := _sheep_scene.instantiate() as Node3D
		actors_root.add_child(sh)
		var box := Artisau.aabb(sh)
		var sc := 0.9 / maxf(0.01, maxf(box.size.x, box.size.z))
		sh.scale = Vector3.ONE * sc
		var off := Vector2(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.8, 0.8))
		var p: Vector2 = (b["pos"] as Vector2) + off
		sh.position = Vector3(p.x, land.height_at(p.x, p.y), p.y)
		sh.rotation.y = rng.randf() * TAU
		var ap: AnimationPlayer = sh.find_children("*", "AnimationPlayer", true, false)[0] if not sh.find_children("*", "AnimationPlayer", true, false).is_empty() else null
		if ap:
			for a in ap.get_animation_list():
				if String(a).ends_with("Eating") or String(a).ends_with("Idle_Eating") or String(a) == "Eating":
					ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
					ap.play(a)
					ap.seek(rng.randf() * 2.0, true)
					break
		if not vis.has("pets"):
			vis["pets"] = []
		vis["pets"].append(sh)


## Люди при деле у постройки: появляются, когда она работает, и уходят, когда нет
func _sync_actors(b: Dictionary) -> void:
	var vis: Dictionary = visuals.get(b["id"], {})
	if vis.is_empty():
		return
	var d := city.def(b)
	# у мастерских и лавок работают настоящие жители (приходят из дома) — тут только станция и сады патрициев
	# (и военные постройки: солдаты и мастера Легиона — не жители города)
	var on: bool = not d.has("jobs") and d["kind"] in ["center", "house", "military"] and (int(b["pop"]) > 0 or d["kind"] != "house") and hour > 6.5 and hour < 20.5
	if bool(vis.get("act_on", false)) == on and vis.has("act_on"):
		return
	for a in vis.get("actors", []):
		(a as Node).queue_free()
	vis["actors"] = []
	vis["act_on"] = on
	if not on:
		return
	var bp := city.blueprint(b)
	var xf := city.xf(b)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(b["id"]) * 7919 + int(b["tier"])
	for a: Array in bp.actors:
		var who: String = a[3]
		var model := ""
		if who == "soldier":
			model = "SK_Chr_Solider_Male_01" if rng.randf() < 0.7 else "SK_Chr_Soldier_Female_02"
		# одежда по сословию дома; садовник у домуса — слуга, в простом
		var cls: String = "patricians" if who == "rich" else String(d.get("cls", "plebs"))
		if cls == "patricians" and who != "rich":
			cls = "plebs"
		var c := Citizen.create(rng, who == "female" or (who == "any" and rng.randf() < 0.5), false, who == "rich", model, cls)
		actors_root.add_child(c)
		c.transform = xf * Transform3D(Basis(Vector3.UP, float(a[1])), a[0])
		c.scale = Vector3.ONE * Citizen.SIZE
		if (a[0] as Vector3).y < 0.05:
			c.position.y = land.height_at(c.position.x, c.position.z)
		c.play(a[2], 0.0)
		var cur := c.anim.current_animation
		if cur != "":
			c.anim.seek(rng.randf() * c.anim.get_animation(cur).length, true)
		vis["actors"].append(c)


func _sync_all_actors() -> void:
	for id in city.buildings:
		_sync_actors(city.buildings[id])


## Дым из отдушины — мягкие клубы
func _smoke(at: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 7
	p.lifetime = 4.0
	p.preprocess = 4.0
	p.position = at
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.25, 1, 0.1)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.35
	pm.initial_velocity_max = 0.55
	pm.gravity = Vector3(0.12, 0.05, 0.04)
	pm.scale_min = 0.22
	pm.scale_max = 0.34
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.5))
	sc.add_point(Vector2(1, 2.2))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var grad := Gradient.new()
	grad.set_color(0, Color(0.86, 0.84, 0.82, 0.32))
	grad.set_color(1, Color(0.8, 0.8, 0.8, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	p.draw_pass_1 = _puff_quad()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


static var _quad: QuadMesh


static func _puff_quad() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2(1.0, 1.0)
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		var rg := Gradient.new()
		rg.set_color(0, Color(1, 1, 1, 1))
		rg.set_color(1, Color(1, 1, 1, 0))
		var rt := GradientTexture2D.new()
		rt.gradient = rg
		rt.fill = GradientTexture2D.FILL_RADIAL
		rt.fill_from = Vector2(0.5, 0.5)
		rt.fill_to = Vector2(1.0, 0.5)
		m.albedo_texture = rt
		_quad.material = m
	return _quad


## Облачко пыли при стройке и сносе
func _puff(at: Vector3, col := Color("e8dcc4")) -> void:
	var p := GPUParticles3D.new()
	p.amount = 24
	p.lifetime = 1.4
	p.one_shot = true
	p.explosiveness = 0.9
	p.position = at + Vector3(0, 0.3, 0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 2.0
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 60.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0, -0.4, 0)
	pm.scale_min = 1.2
	pm.scale_max = 2.0
	var grad := Gradient.new()
	grad.set_color(0, Color(col, 0.7))
	grad.set_color(1, Color(col, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	p.draw_pass_1 = _puff_quad()
	add_child(p)
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)


# ---------- участки ----------

static var _gold_mat: StandardMaterial3D


static func _plot_mat(a: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.84, 0.38, a)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Пунктир по краю участка, лежит на земле (повторяет холмы)
func _plot_border(p: Vector2i) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x0 := p.x * Land.PLOT
	var z0 := p.y * Land.PLOT
	var L := Land.PLOT
	var sides := [[Vector2(x0, z0), Vector2(1, 0)], [Vector2(x0 + L, z0), Vector2(0, 1)], [Vector2(x0 + L, z0 + L), Vector2(-1, 0)], [Vector2(x0, z0 + L), Vector2(0, -1)]]
	for sd: Array in sides:
		var a: Vector2 = sd[0]
		var d: Vector2 = sd[1]
		var mid := a + d * L * 0.5
		if mid.x < 0.5 or mid.y < 0.5 or mid.x > Land.SIZE - 0.5 or mid.y > Land.SIZE - 0.5:
			continue                          # по краю карты рамку не рисуем: там земля просто продолжается
		var n := Vector2(-d.y, d.x) * 0.16
		var t := 0.0
		while t < L - 0.01:
			var q0 := a + d * t
			var q1 := a + d * minf(t + 0.7, L)
			var qm := (q0 + q1) * 0.5
			var kd := land.kind_at(qm.x, qm.y)
			if kd == Land.Kind.ROAD or kd == Land.Kind.PLAZA:
				t += 1.2
				continue                      # по мостовой пунктир не рисуем (большая дорога идёт по границе участков)
			for tri: Array in [[q0 - n, q1 - n, q1 + n], [q0 - n, q1 + n, q0 + n]]:
				for q: Vector2 in tri:
					st.add_vertex(Vector3(q.x, maxf(land.height_at(q.x, q.y), Land.WATER_Y) + 0.14, q.y))
			t += 1.2
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	if _gold_mat == null:
		_gold_mat = _plot_mat(0.85)
	mi.material_override = _gold_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Курсор над участком, который можно купить: мягкая золотая заливка поверх земли
func _plot_hover(p: Vector2i) -> void:
	if p == plot_fill_key:
		return
	plot_fill_key = p
	if plot_fill:
		plot_fill.queue_free()
		plot_fill = null
	if p.x < 0:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 2.0
	var n := int(Land.PLOT / step)
	var y := func(x: float, z: float) -> float: return maxf(land.height_at(x, z), Land.WATER_Y) + 0.1
	for j in n:
		for i in n:
			var xa := p.x * Land.PLOT + i * step
			var za := p.y * Land.PLOT + j * step
			var v00 := Vector3(xa, y.call(xa, za), za)
			var v10 := Vector3(xa + step, y.call(xa + step, za), za)
			var v01 := Vector3(xa, y.call(xa, za + step), za + step)
			var v11 := Vector3(xa + step, y.call(xa + step, za + step), za + step)
			for v: Vector3 in [v00, v10, v11, v00, v11, v01]:
				st.add_vertex(v)
	plot_fill = MeshInstance3D.new()
	plot_fill.mesh = st.commit()
	plot_fill.material_override = _plot_mat(0.16)
	plot_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plot_fill)


func _update_plot_signs() -> void:
	if hud == null:
		return
	for k in plot_signs:
		(plot_signs[k] as Node).queue_free()
		hud.clear_badge("plot%d_%d" % [k.x, k.y])
	plot_signs.clear()
	_plot_hover(Vector2i(-1, -1))
	for j in Land.PLOTS:
		for i in Land.PLOTS:
			var p := Vector2i(i, j)
			if not city.can_buy(p):
				continue
			var c := Vector2((i + 0.5) * Land.PLOT, (j + 0.5) * Land.PLOT)
			# столб ставим ближе к своей земле
			var dir := Vector2.ZERO
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if land.owned.has(p + d):
					dir += Vector2(d)
			var at := c + dir.normalized() * Land.PLOT * 0.36
			if land.is_water(at):
				at = c
			var y := maxf(land.height_at(at.x, at.y), Land.WATER_Y)
			var sign := Node3D.new()
			sign.position = Vector3(at.x, y, at.y)
			sign.add_child(Synty.make("SM_Prop_Pole_02"))
			var ban := Synty.make("SM_Prop_Banner_02_%s" % ["A", "C", "E", "G"][(i + j) % 4])
			ban.position = Vector3(0, 3.2, 0)
			ban.rotation.y = 0.6
			sign.add_child(ban)
			add_child(sign)
			# золотая пунктирная рамка по земле вокруг участка и табличка с ценой (всегда одного размера)
			var border := _plot_border(p)
			sign.add_child(border)
			border.global_transform = Transform3D.IDENTITY
			hud.set_badge("plot%d_%d" % [i, j], Vector3(at.x, y + 4.4, at.y), "coins", false, "%s ден." % hud.fmt(city.plot_price()))
			plot_signs[p] = sign


# ---------- кадр ----------

func _process(dt: float) -> void:
	if not ready_done:
		return
	frame += 1
	_minimized_pause()
	_rebuild_land()
	_swim(dt)
	var sdt := dt * speed
	if speed > 0.0 and mode != "menu":
		var h0 := hour
		var nh := hour + sdt * 24.0 / DAY_LEN
		if not clock_hours:
			day_t += sdt
			if day_t >= DAY_LEN / 24.0:
				day_t -= DAY_LEN / 24.0
				city.sim_day()
		else:
			if int(floor(nh)) != int(floor(h0)):
				city.sim_day()
			if nh >= 24.0:
				city.day += 1
			_set_hour(nh)
	elif mode == "menu" and clock_hours:
		_set_hour(hour + dt * 0.5 * 24.0 / DAY_LEN)
	if speed != _actor_speed:
		_actor_speed = speed
		for a in actors_root.get_children():
			if a is Citizen:
				(a as Citizen).anim.speed_scale = speed
			else:
				for ap in a.find_children("*", "AnimationPlayer", true, false):
					(ap as AnimationPlayer).speed_scale = speed
	if rig and rig.cine:
		_plot_hover(Vector2i(-1, -1))         # в ролике камеру ведёт он: без подсветки участка под мышью
		brush_ring.visible = false            # …и без кольца кисти на земле (подсветку домов прячет cover.gd)
		brush_box.visible = false
	else:
		_update_tool()
	autosave_t += dt
	if mode == "menu":
		rig._yaw_t += dt * 0.03
		if _autogo != "" and frame == 60:
			hud._menu_go(_autogo)
	if autosave_t > 90.0 and can_save and settings.get("autosave", true) and moving.is_empty() and moving_nature.is_empty():
		autosave_t = 0.0
		save()
	if shot_path != "" and frame == shot_frame:
		var img := get_viewport().get_texture().get_image()
		img.save_png(shot_path)
		print("SHOT ", shot_path, " fps=", Engine.get_frames_per_second(), " parts=", parts.count())
		get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and can_save and ready_done:
		save()


## Окно свернули — город на паузе (без игрока он не живёт: 5 минут на быстрой скорости — двое суток), развернули —
## прежняя скорость. Только сворачивание: переключиться на другое окно (Alt+Tab) — не пауза. Бой кампании тоже ждёт,
## а бой с городом идёт дальше: сервер ждёт его итог только полчаса, потом засчитывает поражение. Ролики (ранг,
## повозка) ждут игрока сами. Улучшения бойцов идут по часам, как и задумано
func _minimized_pause() -> void:
	if mode == "menu" or mode == "demo" or promo or shot_path != "" or hud == null:
		return
	var mini := minimized_test or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED
	if mini:
		if _min_speed < 0.0:
			_min_speed = speed
			var b = LegionBattle.current
			if b != null and is_instance_valid(b) and not b.pvp and not b.paused and b.phase != "result" and b.modal == null:
				b._toggle_pause()
				_min_battle = b
		if speed > 0.0:
			_min_speed = speed                # скорость вернули (ролик ранга, обучение) — запомнить и снова стоп
			hud.paused_speed = speed
			hud.set_speed(0.0)
	elif _min_speed >= 0.0:
		if speed <= 0.0 and _min_speed > 0.0:
			hud.set_speed(_min_speed)
		_min_speed = -1.0
		if _min_battle != null and is_instance_valid(_min_battle) and _min_battle.paused:
			_min_battle._toggle_pause()
		_min_battle = null


# ---------- точка земли под курсором ----------

func _input(e: InputEvent) -> void:
	if e is InputEventMouse:
		_mouse_pos = (e as InputEventMouse).position
		# правая кнопка: тянули карту — это не щелчок (он закрывает свиток и окна)
		if _rmb_armed and e is InputEventMouseMotion:
			_rmb_moved = maxf(_rmb_moved, _mouse_pos.distance_to(_rmb_down))


func ground_at_mouse() -> Vector2:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector2.INF
	var mp := _mouse_pos if _mouse_pos.x >= 0.0 else get_viewport().get_mouse_position()
	var o := cam.project_ray_origin(mp)
	var d := cam.project_ray_normal(mp)
	if d.y > -0.001:
		return Vector2.INF
	var top := 20.0
	var t0 := maxf(0.0, (o.y - top) / -d.y)
	var t1 := (o.y - Land.WATER_Y + 2.0) / -d.y
	var n := clampi(int((t1 - t0) * Vector2(d.x, d.z).length() / 0.12), 1, 3000)
	var prev := t0
	for i in range(1, n + 1):
		var t := t0 + (t1 - t0) * i / n
		var p := o + d * t
		if p.x < 0 or p.z < 0 or p.x > Land.SIZE or p.z > Land.SIZE:
			if p.y < -1.0:
				return Vector2.INF
			prev = t
			continue
		var gy := maxf(land.height_at(p.x, p.z), Land.WATER_Y)
		if p.y <= gy:
			var lo := prev
			var hi := t
			for k in 8:
				var m := (lo + hi) * 0.5
				var q := o + d * m
				if q.y <= maxf(land.height_at(q.x, q.z), Land.WATER_Y):
					hi = m
				else:
					lo = m
			var r := o + d * hi
			return Vector2(r.x, r.z)
		prev = t
	return Vector2.INF


# ---------- постройка под курсором: луч по настоящим деталям ----------

## Коробки деталей чертежа в осях постройки (по габаритам моделей Synty); вложенные друг в друга отбрасываются.
## Считается один раз на чертёж
static func pick_boxes(bp: Bp) -> Array:
	var key := bp.get_instance_id()
	if _bp_boxes.has(key):
		return _bp_boxes[key]
	var raw := []
	for p in bp.parts:
		var nm: String = p[0]
		var box: AABB = Parts._special_mesh(nm).get_aabb() if nm.begins_with("#") else Bp.model_aabb(nm)
		var w: AABB = (p[1] as Transform3D) * box
		if w.size.x + w.size.y + w.size.z < 0.06:
			continue
		raw.append(w)
	raw.sort_custom(func(a: AABB, b: AABB): return a.get_volume() > b.get_volume())
	var kept := []
	for b: AABB in raw:
		var inside := false
		if raw.size() < 600:
			for k: AABB in kept:
				if k.grow(0.03).encloses(b):
					inside = true
					break
		if not inside:
			kept.append(b)
	_bp_boxes[key] = kept
	return kept


func _pick_entry(b: Dictionary) -> Dictionary:
	var boxes := pick_boxes(city.blueprint(b))
	if city.def(b)["kind"] == "decor":
		# мелочь (украшения на стенах, фонари, цветы) ловится чуть шире, чем нарисована
		var g := []
		for bx: AABB in boxes:
			g.append(bx.grow(0.12))
		boxes = g
	var bound := AABB()
	for i in boxes.size():
		bound = boxes[i] if i == 0 else bound.merge(boxes[i])
	var xf := city.xf(b)
	return {"b": b, "id": int(b["id"]), "tier": b["tier"], "pos": b["pos"], "yaw": b["yaw"], "y": b["y"],
		"inv": xf.affine_inverse(), "box": xf * bound.grow(0.05), "boxes": boxes}


## Во что попадает луч из камеры: ближайшая постройка {id, t, p (точка попадания)} или {}.
## Сначала грубо — по общей коробке постройки, потом по коробкам деталей; холм перед постройкой заслоняет её
func _ray_pick(o: Vector3, d: Vector3) -> Dictionary:
	if _pick_cache.size() > city.buildings.size() + 32:
		for id in _pick_cache.keys():
			if not city.buildings.has(id):
				_pick_cache.erase(id)
	var cands := []
	for id in city.buildings:
		var b: Dictionary = city.buildings[id]
		var c: Dictionary = _pick_cache.get(id, {})
		if c.is_empty() or not is_same(c["b"], b) or c["tier"] != b["tier"] or c["pos"] != b["pos"] or c["yaw"] != b["yaw"] or c["y"] != b["y"]:
			c = _pick_entry(b)
			_pick_cache[id] = c
		var e = (c["box"] as AABB).intersects_ray(o, d)
		if e != null:
			cands.append([o.distance_to(e), c])
	if cands.is_empty():
		return {}
	cands.sort_custom(func(a, b): return a[0] < b[0])
	var tg := INF
	if hover != Vector2.INF:
		tg = o.distance_to(Vector3(hover.x, maxf(land.height_at(hover.x, hover.y), Land.WATER_Y), hover.y)) + 0.6
	var best_t := tg
	var best := {}
	for cd: Array in cands:
		if float(cd[0]) >= best_t:
			break
		var c: Dictionary = cd[1]
		var inv: Transform3D = c["inv"]
		var lo := inv * o
		var ld := inv.basis * d
		for bx: AABB in c["boxes"]:
			var h = bx.intersects_ray(lo, ld)
			if h != null:
				var t := lo.distance_to(h)
				if t < best_t:
					best_t = t
					best = {"id": c["id"], "t": t, "p": o + d * t}
	return best


## Постройка под курсором — как в Town to City ловится вся модель (крыша, верхние этажи, украшения на стенах),
## ближняя к камере; если луч ни во что не попал — та, на чьём следе земля под курсором.
## Луч пересчитывается, только когда сдвинулась мышь или камера (или город поменялся)
func pick_building() -> Dictionary:
	var cam := get_viewport().get_camera_3d()
	if cam == null or city == null:
		return {}
	var mp := _mouse_pos if _mouse_pos.x >= 0.0 else get_viewport().get_mouse_position()
	var sig := [mp, cam.global_transform, city.buildings.size(), city.next_id]
	var now := Time.get_ticks_msec()
	if sig != _pick_sig or now - _pick_t > 300:
		_pick_sig = sig
		_pick_t = now
		_pick_hit = _ray_pick(cam.project_ray_origin(mp), cam.project_ray_normal(mp))
	var id := int(_pick_hit.get("id", -1))
	if id >= 0 and city.buildings.has(id):
		return city.buildings[id]
	if hover == Vector2.INF:
		return {}
	return city.building_at(hover)


# ---------- инструменты ----------

func set_tool(t: String) -> void:
	if painting:
		# инструмент сменили посреди мазка: уже проложенное и оплаченное — в отмену (Ctrl+Z вернёт деньги),
		# подпись у курсора гаснет; недотянутую прямую линию не рисуем — игрок отменял
		line_from = Vector2.INF
		_release()
	if floor_drag:
		_floor_end()                          # мазок «Этажа» прервали — его итог всё равно в колокольчик
	floor_hover = -1
	var prev_tool := tool
	if not moving.is_empty() and t != String(moving["type"]):
		_cancel_move()
	if t != "move_nature" and not moving_nature.is_empty():
		_add_nature(moving_nature["name"], moving_nature["xf"], moving_nature["p"])
		moving_nature = {}
	tool = t
	place_lock = {}
	pressing = false
	rot_drag = false
	if t != "" and hud and hud.overlay != "":
		hud.set_overlay("")                   # взяли инструмент — «Обзор» закрывается, стройка покажет свой охват
	if t != prev_tool or t == "":
		manual_yaw = false
		rot_off = Vector2.ZERO
		last_snap_n = Vector2.ZERO        # новая постройка — к дороге заново, без памяти о прошлой
	if t != "settle":
		settle_fam = {}
		_clear_settle_marks()
	painting = false
	line_from = Vector2.INF
	if ghost:
		ghost.queue_free()
		ghost = null
		ghost_key = ""
	_clear_highlight()
	if Defs.B.has(t) and tool_variant >= 0:
		next_variant = tool_variant
	elif Defs.B.has(t):
		next_variant = randi() % int(Defs.B[t].get("variants", 1))
	if t == "floor" and city.mark_seen("@floor") and hud:
		hud.update_new_marks()                # взяли «Этаж» — пометка «НОВОЕ» с кнопки снята
	if cover:
		cover.refresh()                       # стройка с охватом — синие дома и значки таких же построек сразу
	if hud:
		hud.on_tool(t)
		if Cover.kind_of(t) != "":
			hud.cover_tip()
		elif t == "floor":
			hud.floor_tip()


func is_road_tool(t: String) -> bool:
	return t in ["road", "plaza", "path", "erase"]


func _make_markers() -> void:
	brush_ring = _ring(Color(1, 0.98, 0.9, 0.85))
	brush_box = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2, 0.06, 2)
	brush_box.mesh = bm
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 0.98, 0.9, 0.35)
	m.no_depth_test = true
	brush_box.material_override = m
	brush_box.visible = false
	add_child(brush_box)


func _ring(col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.97
	tm.outer_radius = 1.0
	tm.rings = 96
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.no_depth_test = true
	mi.material_override = m
	mi.visible = false
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## Границы следа постройки вдоль её осей: [minx, maxx, minz, maxz]
func _bounds(bp: Bp) -> Array:
	var b := [INF, -INF, INF, -INF]
	for r: Rect2 in bp.footprint():
		b[0] = minf(b[0], r.position.x)
		b[1] = maxf(b[1], r.end.x)
		b[2] = minf(b[2], r.position.y)
		b[3] = maxf(b[3], r.end.y)
	if b[0] == INF:
		return [-0.5, 0.5, -0.5, 0.5]
	return b


## Куда встанет постройка: у дороги — фасадом к ней, вплотную к соседям в ряд; иначе — как повернул игрок.
## Украшение всегда ровно то, что выбрано в меню (у каждого облика своя карточка): у стены оно ни во что
## не превращается; настенные украшения — отдельные карточки и вешаются только на стены
func placement(type: String, p: Vector2, variant := -1, color := -1) -> Dictionary:
	var d: Dictionary = Defs.B[type]
	if d.get("wall", false):
		return _wall_place(type, p)
	if d["kind"] == "decor":
		variant = 0                       # облик украшения задаёт его тип (карточка), а не фасад
	elif variant < 0:
		variant = next_variant
	if color < 0:
		if not moving.is_empty():
			color = int(moving.get("color", 0))
		else:
			if place_color < 0 or (place_lock.is_empty() and place_color_pos.distance_to(p) > 5.0):
				place_color = city.pick_color(p)
				place_color_pos = p
			color = place_color
	var tier := 1 if d["kind"] == "house" else (city.level if type == "center" else 0)
	if not moving.is_empty():
		tier = int(moving["tier"])
	var bp := Catalog.make(type, tier, variant, color)
	var bb: Array = _row_bounds(bp).duplicate()     # фасадом (bb[3] — передняя стена) — вплотную к краю дороги
	var yaw := tool_yaw
	var locked := not place_lock.is_empty()
	if locked:
		p = place_lock["p"]
	var pos := p
	var mid := int(moving.get("id", -1))
	var sub := ""
	# игрок: свободная постановка, как в Town to City — куда навёл и как повернул; вплотную к дороге — фасадом к ней.
	# Готовый город меню (витрина, старый городок) раскладывается по прежним правилам — он не меняется
	var free: bool = pave_build and not (d["kind"] in ["decor", "farm", "center"])
	if free:
		var r := _free_place(p, bb, mid, locked)
		pos = r["pos"]
		yaw = r["yaw"]
		sub = r["sub"]
	else:
		var road_snap: bool = snap and not locked and d["kind"] != "decor" and d["kind"] != "farm"
		if road_snap and manual_yaw:
			# игрок сам повернул постройку: двигаем её вперёд до края дороги (а с самой дороги — назад, на обочину)
			var f := City.facing(yaw)
			var reach := float(bb[3]) + 3.0
			var dd := 0.0
			if land.is_road(p):
				while dd <= reach and land.is_road(p - f * dd):
					dd += 0.1
				if dd <= reach:
					pos = p - f * dd - f * (float(bb[3]) + 0.02)
					pos = _snap_row(pos, yaw, bb, int(moving.get("id", -1)))
			else:
				while dd <= reach and not land.is_road(p + f * dd):
					dd += 0.2
				if dd <= reach:
					pos = p + f * dd - f * (float(bb[3]) + 0.02)
					pos = _snap_row(pos, yaw, bb, int(moving.get("id", -1)))
		elif road_snap:
			# как в Town to City: фасадом (дверью) к ближайшей дороге; курсор на самой дороге — дом встаёт
			# на ближнюю обочину (раньше в этом случае он смотрел вдоль дороги — боком — и садился на мостовую)
			var keep := last_snap_n if last_snap_p.distance_to(p) < 2.0 else Vector2.ZERO
			var e := _nearest_road(p, maxf(6.0, (float(bb[3]) - float(bb[2])) * 0.5 + 3.0), (float(bb[1]) - float(bb[0])) * 0.5, keep)
			if not e.is_empty():
				var nrm: Vector2 = e["n"]
				# не дёргаться: пока курсор плавно ведут, прежняя дорога остаётся, если она почти так же близко
				# (мелкое дрожание направления или соседняя дорога у угла); прежнее направление — только этой постановки
				if not e.get("on", false) and last_snap_n != Vector2.ZERO and last_snap_p.distance_to(p) < 2.0:
					var ang := absf(nrm.angle_to(last_snap_n))
					if ang > 0.0 and (ang < deg_to_rad(10.0) or ang > deg_to_rad(60.0)):
						var dd := 0.0
						while dd <= 8.0 and not land.is_road(p + last_snap_n * dd):
							dd += 0.2
						if dd <= p.distance_to(e["p"]) + (0.25 if ang < deg_to_rad(10.0) else 0.6):
							nrm = last_snap_n
							e["p"] = p + nrm * dd
				last_snap_n = nrm
				last_snap_p = p
				yaw = snappedf(atan2(nrm.x, nrm.y), deg_to_rad(5.0))
				var f := City.facing(yaw)
				pos = (e["p"] as Vector2) - f * (float(bb[3]) + 0.02)
				pos = _snap_row(pos, yaw, bb, int(moving.get("id", -1)))
	var chk := city.check_place(type, pos, yaw, variant, color, -3 if not moving.is_empty() else -1)
	var err: String = chk["err"]
	if err == "" and free:
		err = _free_checks(type, chk["cells"], pos, yaw, variant, color, tier, mid)
	# готовый город меню: дом и лавка на мостовую не встают (кромку — неровный край кисти у фасада — прощаем)
	elif err == "" and d["kind"] in ["house", "shop", "rp", "store"] and _over_road(chk["cells"], pos, yaw, float(bb[3])):
		err = "Здесь дорога — поставьте рядом с ней"
	# игрок: поле и крупное украшение тоже не на большую дорогу к станции (фонарь или цветы у края — можно)
	if err == "" and pave_build and d["kind"] in ["farm", "decor"]:
		var on_big := 0
		for k in (chk["cells"] as PackedInt32Array):
			if Land.walk_kind(land.base_kind[k]):
				on_big += 1
		if on_big > (0 if d["kind"] == "farm" else 16):
			err = "По большой дороге ездят повозки — здесь не строят"
	return {"pos": pos, "yaw": yaw, "err": err, "cells": chk["cells"], "y": chk["y"], "variant": variant, "color": color, "tier": tier,
		"mode": "free" if free else "", "sub": sub}


## Клетки следа заходят на дорогу глубже кромки фасада?
func _over_road(cells: PackedInt32Array, pos: Vector2, yaw: float, front: float) -> bool:
	var f := City.facing(yaw)
	for k in cells:
		if Land.walk_kind(land.kind[k]) and (land.cell_center(k % Land.N, k / Land.N) - pos).dot(f) < front - 0.45:
			return true
	return false


## Поворот новой постройки без дороги рядом: переносимая — как стояла; игрок повернул (эту или прежние) — его
## поворот; иначе — фасадом к камере (по сторонам света)
func _free_yaw() -> float:
	if not moving.is_empty() or manual_yaw:
		return tool_yaw
	if yaw_set:
		return free_yaw
	return snappedf(rig.yaw, PI / 2) if rig else 0.0


## Z/X: запомнить, где середина показанной постройки относительно курсора — поворот будет вокруг неё (без прыжка)
func _rot_keep() -> void:
	if not place_info.has("pos") or not Defs.B.has(tool) or hover == Vector2.INF or not moving.is_empty():
		return
	if manual_yaw:
		return                                # уже крутят — сдвиг тот же
	var bb := _row_bounds(Catalog.make(tool, int(place_info.get("tier", 0)), int(place_info.get("variant", 0)), int(place_info.get("color", 0))))
	var y := float(place_info["yaw"])
	var c: Vector2 = (place_info["pos"] as Vector2) + City.axis(y) * ((float(bb[0]) + float(bb[1])) * 0.5) + City.facing(y) * ((float(bb[2]) + float(bb[3])) * 0.5)
	rot_off = c - hover


## Свободная постановка игрока: {"pos", "yaw", "sub"}.
## sub: "road" — курсор на траве вплотную к дороге, постройка фасадом к ней ровно у края (в ряд с соседями);
##      "free" — серединой следа на курсор, своим поворотом (на траве, площади, мостовой);
##      "lock" — крутят зажатой мышью: на месте, поворот из tool_yaw
func _free_place(p: Vector2, bb: Array, mid: int, locked: bool) -> Dictionary:
	if locked:
		return {"pos": p, "yaw": tool_yaw, "sub": "lock"}
	# вплотную к дороге (курсор на траве у края) — фасадом к ней. Свой поворот этой постройки (Z/X, зажатая мышь)
	# и выключенная привязка (R) — не прилипает. Войти — ближе SNAP_R, выйти — дальше SNAP_STAY: на границе не дёргается
	var near_prev := last_snap_n != Vector2.ZERO and last_snap_p.distance_to(p) < 2.0
	var side_ok := not land.is_road(p)
	if not side_ok and near_prev:
		# курсор заехал на дорогу у самого края (до 1 м) — постройка остаётся прилипшей, а не прыгает на мостовую
		var dd0 := 0.0
		while dd0 <= 1.0 and land.is_road(p - last_snap_n * dd0):
			dd0 += 0.1
		side_ok = dd0 <= 1.0
	if snap and not manual_yaw and side_ok:
		var keep := last_snap_n if near_prev else Vector2.ZERO
		var reach := (float(bb[3]) - float(bb[2])) * 0.5 + (SNAP_STAY if near_prev else SNAP_R)     # от середины до фасада + зазор
		var e := _nearest_road(p, reach, (float(bb[1]) - float(bb[0])) * 0.5, keep)
		if not e.is_empty():
			var nrm: Vector2 = e["n"]
			# не дёргаться: пока курсор плавно ведут, прежняя дорога остаётся, если она почти так же близко
			if near_prev:
				var ang := absf(nrm.angle_to(last_snap_n))
				if ang > 0.0 and (ang < deg_to_rad(10.0) or ang > deg_to_rad(60.0)):
					var dd := 0.0
					while dd <= reach + 0.5 and not land.is_road(p + last_snap_n * dd):
						dd += 0.1
					if dd <= p.distance_to(e["p"]) + (0.25 if ang < deg_to_rad(10.0) else 0.6):
						nrm = last_snap_n
						e["p"] = p + nrm * dd
			last_snap_n = nrm
			last_snap_p = p
			var yr := snappedf(atan2(nrm.x, nrm.y), deg_to_rad(5.0))
			var pr := (e["p"] as Vector2) - City.facing(yr) * (float(bb[3]) + 0.02)
			return {"pos": _snap_row(pr, yr, bb, mid), "yaw": yr, "sub": "road"}
	last_snap_n = Vector2.ZERO
	last_snap_p = Vector2.INF
	var y0 := _free_yaw()
	if manual_yaw:
		p += rot_off                          # повернули Z/X — середина остаётся, где была
	var pc := p - City.axis(y0) * ((float(bb[0]) + float(bb[1])) * 0.5) - City.facing(y0) * ((float(bb[2]) + float(bb[3])) * 0.5)
	if snap:
		pc = _snap_row(pc, y0, bb, mid)       # рядом дом с тем же поворотом — встать с ним в ряд
	return {"pos": pc, "yaw": y0, "sub": "free"}


## Проверки свободной постановки (после check_place): не на большой дороге к станции, у входа — мостовая (не своя),
## чужую дверь не загораживать, на мостовой — почти ровно. "" — можно
func _free_checks(type: String, cells: PackedInt32Array, pos: Vector2, yaw: float, variant: int, color: int, tier: int, mid: int) -> String:
	var d: Dictionary = Defs.B[type]
	var homey: bool = d["kind"] in ["house", "shop", "rp", "store"]
	var lo := INF
	var hi := -INF
	var own := {}
	var paved := 0
	for k in cells:
		own[k] = true
		if Land.walk_kind(land.base_kind[k]):
			return "По большой дороге ездят повозки — здесь не строят"
		if Land.walk_kind(land.kind[k]):
			paved += 1
		lo = minf(lo, land.hq(k))
		hi = maxf(hi, land.hq(k))
	if homey and paved * 2 >= cells.size() and hi - lo > PAVE_SLOPE:
		return "Мостовая здесь слишком наклонная — найдите место ровнее"
	var bp := Catalog.make(type, tier, variant, color)
	var ax := City.axis(yaw)
	var f := City.facing(yaw)
	if not _road_free_near(pos + ax * bp.door.x + f * bp.door.z, 1.7, own):
		return "Нужна дорога у входа"
	var rects: Array = bp.footprint()
	if rects.is_empty():
		rects = [Rect2(-0.4, -0.4, 0.8, 0.8)]
	for id in city.buildings:
		if id == mid:
			continue
		var o: Dictionary = city.buildings[id]
		if (o["pos"] as Vector2).distance_squared_to(pos) > 225.0:
			continue
		var od: Dictionary = city.def(o)
		if od["kind"] == "decor" or od["kind"] == "farm":
			continue
		var odp := city.door_point(o)
		var rel := odp - pos
		var lp := Vector2(rel.dot(ax), rel.dot(f))
		for r: Rect2 in rects:
			if r.grow(0.4).has_point(lp):
				return "Так загородится вход соседней постройки"
		# сосед сейчас у дороги, а новая постройка закроет ему всю мостовую у входа
		if od["kind"] != "center" and bool(o.get("road", false)) and not _road_free_near(odp, 1.7, own):
			return "Так загородится вход соседней постройки"
	return ""


## Есть ли свободная мостовая (не под постройкой и не под этой же постройкой own) ближе r к точке
func _road_free_near(p: Vector2, r: float, own: Dictionary) -> bool:
	var c := land.cell(p)
	var rc := int(ceil(r / Land.CELL))
	for j in range(c.y - rc, c.y + rc + 1):
		for i in range(c.x - rc, c.x + rc + 1):
			if not land.inside(i, j):
				continue
			var k := land.idx(i, j)
			if Land.walk_kind(land.kind[k]) and land.occ[k] == 0 and not own.has(k) and land.cell_center(i, j).distance_to(p) <= r:
				return true
	return false


## Украшение на стену: стена дома, в которую смотрит курсор (луч по деталям), иначе — ближайшая к точке земли
func _wall_place(type: String, p: Vector2, maxd := 1.8) -> Dictionary:
	var best := {}
	var bd := maxd
	var only := -1                        # луч попал в дом (или в украшение на его стене) — вешаем на него
	var hl := Vector3.ZERO                # точка попадания в осях этого дома
	var hb := pick_building() if p == hover and p != Vector2.INF else {}     # только для курсора (не для готового города)
	var hp: Variant = _pick_hit.get("p") if int(_pick_hit.get("id", -1)) == int(hb.get("id", -2)) else null
	if hb.has("host"):
		hb = city.buildings.get(int(hb["host"]), {})
	if not hb.is_empty() and hp != null and not (city.def(hb)["kind"] in ["decor", "farm"]):
		only = int(hb["id"])
		hl = city.xf(hb).affine_inverse() * (hp as Vector3)
		bd = maxf(maxd, 3.0)
	for id in city.buildings:
		var b: Dictionary = city.buildings[id]
		if only >= 0 and int(id) != only:
			continue
		var kd: String = city.def(b)["kind"]
		if kd in ["decor", "farm"] or (only < 0 and (b["pos"] as Vector2).distance_to(p) > 14.0):
			continue
		var bp := city.blueprint(b)
		var fz := bp.front_z()
		if fz == -INF:
			continue
		var bb := _bounds(bp)
		bb[3] = fz
		var ax := City.axis(b["yaw"])
		var fw := City.facing(b["yaw"])
		var rel: Vector2 = p - (b["pos"] as Vector2)
		var lx := rel.dot(ax)
		var lz := rel.dot(fw)
		if only >= 0:
			lx = hl.x
			lz = hl.z
		var sides := [[absf(lz - float(bb[3])), "f"], [absf(lz - float(bb[2])), "b"], [absf(lx - float(bb[1])), "r"], [absf(lx - float(bb[0])), "l"]]
		for sd: Array in sides:
			var inside_x := lx >= float(bb[0]) - 0.3 and lx <= float(bb[1]) + 0.3
			var inside_z := lz >= float(bb[2]) - 0.3 and lz <= float(bb[3]) + 0.3
			if (sd[1] in ["f", "b"] and not inside_x) or (sd[1] in ["l", "r"] and not inside_z):
				continue
			if float(sd[0]) < bd:
				bd = sd[0]
				var px := clampf(lx, float(bb[0]) + 0.35, float(bb[1]) - 0.35)
				var pz := clampf(lz, float(bb[2]) + 0.35, float(bb[3]) - 0.35)
				var ly := 0.0
				match sd[1]:
					"f":
						pz = float(bb[3]) + 0.02
						ly = 0.0
					"b":
						pz = float(bb[2]) - 0.02
						ly = PI
					"r":
						px = float(bb[1]) + 0.02
						ly = PI / 2
					"l":
						px = float(bb[0]) - 0.02
						ly = -PI / 2
				var wp: Vector2 = (b["pos"] as Vector2) + ax * px + fw * pz
				var hgt: float = {"wall_torch": 2.25, "wall_lamp": 2.45, "wall_flowers": 1.25, "wall_banner": 2.2}.get(Defs.base_of(type), 2.0) * Catalog.ARCH
				# облик настенного украшения задаёт его тип (карточка); цвет — просто цвет дома, на облик не влияет
				best = {"pos": wp, "yaw": float(b["yaw"]) + ly, "err": "", "cells": PackedInt32Array(), "y": float(b["y"]) + hgt,
					"variant": 0, "color": int(b.get("color", 0)), "tier": 0, "host": b["id"]}
	if best.is_empty():
		var g := land.height_at(p.x, p.y)
		return {"pos": p, "yaw": tool_yaw, "err": "Наведите на стену дома", "cells": PackedInt32Array(), "y": g + 2.0, "variant": 0, "color": 0, "tier": 0}
	if city.money < float(Defs.B[type]["cost"]):
		best["err"] = "Не хватает денариев"
	return best


## Ближайшая дорога: точка на её кромке (сюда встанет фасад) и направление n от дома к дороге.
## hw — полуширина фасада: кромка меряется по всей его ширине, и если дорога рядом прямая, фасад ложится
## вдоль неё (а не на ближайший выступ, угол или скруглённый конец). Курсор на самой дороге — дом встаёт
## на ближнюю к курсору свободную обочину ("on": true), фасадом к этой дороге.
## keep — прежнее направление (пока курсор плавно ведут): посреди дороги дом не перескакивает на другую обочину
func _nearest_road(p: Vector2, maxd: float, hw := 0.0, keep := Vector2.ZERO) -> Dictionary:
	var on := land.is_road(p)
	var fan := _fan(p, maxd, not on)
	if fan.is_empty():
		return {}
	var n: Vector2 = fan["n"]
	if on and keep != Vector2.ZERO and (-n).dot(keep) < 0.5:
		var dk := 0.0
		while dk <= maxd and not _free_land(p - keep * dk):
			dk += 0.1
		if dk <= float(fan["d"]) + 0.5:
			fan = {"p": p - keep * dk, "n": -keep, "d": dk}
			n = -keep
	var p0 := p                           # откуда меряем — со стороны дома
	var q0: Vector2 = fan["p"]            # точка у кромки дороги
	var plain := {"p": fan["p"], "n": n}
	if on:
		plain = {"p": fan["p"], "n": -n, "on": true}
		p0 = q0 + n * 0.3                 # чуть за кромкой, на обочине
		q0 = q0 - n * 0.15
		n = -n
	var ax := _road_axis(_road_mid(q0, n), 5.0)     # круг — посреди дороги: так и у скруглённого конца видно, куда она идёт
	var s := clampf(hw * 0.85, 0.0, 3.0)
	var lim := p0.distance_to(q0) + 3.0
	if ax != Vector2.ZERO:
		# дорога тут вытянута: фасад — ровно вдоль неё (или к её концу), без косых углов
		var nq := n
		var best_dot := -2.0
		for cand: Vector2 in [Vector2(-ax.y, ax.x), Vector2(ax.y, -ax.x), ax, -ax]:
			if cand.dot(n) > best_dot:
				best_dot = cand.dot(n)
				nq = cand
		n = nq
		# у перекрёстка буквой Т соседняя улица попадает в круг и перекашивает ось на 5–10°: если кромка прямо
		# перед фасадом — ровная прямая, фасад ложится вдоль неё (мелкий наклон до 3,5° — это лесенка клеток
		# у косой улицы, там вернее ось)
		var m := _edge_slope(p0, n, maxf(s, 1.0), lim)
		if m != INF and absf(m) > 0.06 and absf(m) < 0.27:
			n = (n - Vector2(n.y, -n.x) * m).normalized()
	# направление дороги не ясно (поворот, перекрёсток): кромка по трём точкам вдоль фасада — если она тут
	# прямая, фасад ложится ровно вдоль неё (у косой улицы кромка — лесенка из клеток, там вернее ось выше)
	var pr := _probe3(p0, n, s, lim)
	if ax == Vector2.ZERO and s >= 0.2 and pr[0] < INF and pr[2] < INF and (pr[1] == INF or absf(pr[1] - (pr[0] + pr[2]) * 0.5) < 0.25):
		var tilt := atan2(pr[2] - pr[0], 2.0 * s)
		if absf(tilt) < deg_to_rad(12.0):
			n = (n * 2.0 * s - Vector2(n.y, -n.x) * (pr[2] - pr[0])).normalized()
			pr = _probe3(p0, n, s, lim)
	# фасад — у ближайшей из трёх точек, чтобы дом нигде не налез на дорогу
	var best: float = minf(pr[1], minf(pr[0], pr[2]))
	if best == INF:
		return plain
	var res := {"p": p0 + n * best, "n": n}
	if on:
		res["on"] = true
	return res


## Расстояние до дороги по направлению n из трёх точек вдоль фасада (слева −s, середина, справа +s); INF — не дошли.
## Край находится с точностью до сантиметра (дорога лежит клетками по 25 см — для ровных улиц это точно)
func _probe3(p0: Vector2, n: Vector2, s: float, lim: float) -> Array:
	var side := Vector2(n.y, -n.x)
	var out := [INF, INF, INF]
	for k in 3:
		if k != 1 and s < 0.2:
			continue
		var a := p0 + side * (s * (k - 1))
		var dd := 0.0
		while dd <= lim:
			if land.is_road(a + n * dd):
				var lo := maxf(0.0, dd - 0.1)
				var hi := dd
				for it in 4:
					var m := (lo + hi) * 0.5
					if land.is_road(a + n * m):
						hi = m
					else:
						lo = m
				out[k] = hi if dd > 0.0 else 0.0
				break
			dd += 0.1
	return out


## Наклон кромки дороги перед фасадом: 9 лучей по n из точек вдоль фасада (−s…+s), прямая по точкам кромки
## (м на м вдоль фасада). INF — кромка тут не прямая (угол, скруглённый конец) или лучей, дошедших до дороги, мало
func _edge_slope(p0: Vector2, n: Vector2, s: float, lim: float) -> float:
	var side := Vector2(n.y, -n.x)
	var tt := []
	var dv := []
	for k in 9:
		var t := s * (k / 4.0 - 1.0)
		var a := p0 + side * t
		var dd := 0.0
		while dd <= lim and not land.is_road(a + n * dd):
			dd += 0.1
		if dd > lim:
			continue
		var lo := maxf(0.0, dd - 0.1)
		var hi := dd
		for it in 4:
			var md := (lo + hi) * 0.5
			if land.is_road(a + n * md):
				hi = md
			else:
				lo = md
		tt.append(t)
		dv.append(hi)
	if tt.size() < 7:
		return INF
	var mt := 0.0
	var md2 := 0.0
	for i in tt.size():
		mt += float(tt[i])
		md2 += float(dv[i])
	mt /= tt.size()
	md2 /= tt.size()
	var sxy := 0.0
	var sxx := 0.0
	for i in tt.size():
		sxy += (float(tt[i]) - mt) * (float(dv[i]) - md2)
		sxx += (float(tt[i]) - mt) * (float(tt[i]) - mt)
	if sxx < 0.01:
		return INF
	var m := sxy / sxx
	for i in tt.size():
		if absf(float(dv[i]) - (md2 + m * (float(tt[i]) - mt))) > 0.1:
			return INF
	return m


## Веер из 48 лучей от p: ближайшая дорога (want = true) или, с дороги, ближайшая свободная своя земля
## (want = false — обочина, куда можно поставить дом). Возвращает {p — первая такая точка, n — направление}
func _fan(p: Vector2, maxd: float, want: bool) -> Dictionary:
	var best_k := -1
	var best_d := INF
	var hits := []
	hits.resize(48)
	for k in 48:
		var a := TAU * k / 48.0
		var dir := Vector2(sin(a), cos(a))
		var dd := 0.0
		var hit := -1.0
		var lim := minf(maxd, best_d * 1.12 + 0.3)     # дальше ближайшей найденной искать незачем
		while dd <= lim:
			var q := p + dir * dd
			if (land.is_road(q) if want else _free_land(q)):
				hit = dd
				break
			dd += 0.2
		hits[k] = hit
		if hit >= 0.0 and hit < best_d:
			best_d = hit
			best_k = k
	if best_k < 0:
		return {}
	var sum := Vector2.ZERO
	# курсор у прямого края: с шагом 0,2 м до края разом доходит целая полоса лучей. Берём всю эту полосу
	# поровну — направление выходит ровно поперёк края. Раньше брался первый по счёту луч, нормаль косила
	# на 20–30°, и дом вставал наискось или вдоль улицы (боком)
	var run := _plateau(hits, best_d) if pave_build else []
	if run.size() >= 2:
		for k: int in run:
			var a := TAU * k / 48.0
			sum += Vector2(sin(a), cos(a))
	else:
		for o in range(-2, 3):
			var k := posmod(best_k + o, 48)
			var hit: float = hits[k]
			if hit >= 0.0 and hit <= best_d * 1.12 + 0.3:
				var a := TAU * k / 48.0
				sum += Vector2(sin(a), cos(a)) / (hit + 0.3)
	var n := sum.normalized() if sum.length() > 0.001 else Vector2(sin(TAU * best_k / 48.0), cos(TAU * best_k / 48.0))
	var dd2 := 0.0
	while dd2 <= maxd + 1.0:
		var q := p + n * dd2
		if (land.is_road(q) if want else _free_land(q)):
			break
		dd2 += 0.1
	return {"p": p + n * dd2, "n": n, "d": dd2}


## Самая длинная полоса соседних лучей (по кругу), дошедших до цели на одном и том же ближайшем расстоянии best.
## Пусто — если такой луч один или все 48 (тогда направление не определить по равенству)
func _plateau(hits: Array, best: float) -> Array:
	var eq := []
	eq.resize(hits.size())
	var cnt := 0
	for k in hits.size():
		eq[k] = float(hits[k]) >= 0.0 and absf(float(hits[k]) - best) < 0.001
		if eq[k]:
			cnt += 1
	if cnt < 2 or cnt == hits.size():
		return []
	var n := hits.size()
	var longest := []
	for k in n:
		if not eq[k] or eq[posmod(k - 1, n)]:
			continue                      # не начало полосы
		var cur := []
		var j := k
		while eq[j] and cur.size() < n:
			cur.append(j)
			j = (j + 1) % n
		if cur.size() > longest.size():
			longest = cur
	return longest


## Свободная своя земля (не дорога, не постройка, не вода)
func _free_land(q: Vector2) -> bool:
	var c := land.cell(q)
	var k := land.idx(c.x, c.y)
	return not Land.walk_kind(land.kind[k]) and land.occ[k] == 0 and land.hq(k) >= Land.WATER_Y + 0.05 and land.is_owned(q)


## Середина дороги у кромки q0 (n — от дома к дороге): посередине между ближней и дальней кромкой и поперёк —
## круг для _road_axis тогда лежит на дороге ровно, и её направление не перекашивается
func _road_mid(q0: Vector2, n: Vector2) -> Vector2:
	var far := 0.0
	while far < 8.0 and land.is_road(q0 + n * (far + 0.25)):
		far += 0.25
	var c := q0 + n * (far * 0.5)
	var side := Vector2(n.y, -n.x)
	var a := 0.0
	while a < 8.0 and land.is_road(c + side * (a + 0.25)):
		a += 0.25
	var b := 0.0
	while b < 8.0 and land.is_road(c - side * (b + 0.25)):
		b += 0.25
	return c + side * ((a - b) * 0.5)


## Куда тянется дорога около точки q: главная ось клеток дороги в радиусе r (единичный вектор);
## Vector2.ZERO — если дорога тут не вытянута (перекрёсток, угол, широкая площадь)
func _road_axis(q: Vector2, r := 2.5) -> Vector2:
	var c := land.cell(q)
	var rc := int(r / Land.CELL)
	var st := 2 if rc <= 24 else 3
	var n := 0
	var sx := 0.0
	var sy := 0.0
	var sxx := 0.0
	var syy := 0.0
	var sxy := 0.0
	for j in range(-rc, rc + 1, st):
		for i in range(-rc, rc + 1, st):
			if i * i + j * j > rc * rc or not land.inside(c.x + i, c.y + j):
				continue
			var k := land.idx(c.x + i, c.y + j)
			if not Land.walk_kind(land.kind[k]) or land.occ[k] != 0:
				continue
			n += 1
			sx += i
			sy += j
			sxx += i * i
			syy += j * j
			sxy += i * j
	if n < 6:
		return Vector2.ZERO
	var mx := sx / n
	var my := sy / n
	var cxx := sxx / n - mx * mx
	var cyy := syy / n - my * my
	var cxy := sxy / n - mx * my
	var tr := cxx + cyy
	var disc := sqrt(maxf(0.0, tr * tr / 4.0 - (cxx * cyy - cxy * cxy)))
	var l1 := tr / 2.0 + disc
	var l2 := tr / 2.0 - disc
	if l1 <= 0.0 or (l2 > 0.0 and l1 / l2 < 1.7):
		return Vector2.ZERO
	var ang := 0.5 * atan2(2.0 * cxy, cxx - cyy)
	return Vector2(cos(ang), sin(ang))


## Ряд: если рядом постройка с тем же поворотом — придвинуться к ней боком и выровнять фасад
const ROW_GAP := 0.6                  # промежуток между соседними домами в ряду, м


func _snap_row(pos: Vector2, yaw: float, bb: Array, ignore := -1) -> Vector2:
	var ax := City.axis(yaw)
	var f := City.facing(yaw)
	for id in city.buildings:
		if id == ignore:
			continue
		var o: Dictionary = city.buildings[id]
		if (o["pos"] as Vector2).distance_squared_to(pos) > 900.0:
			continue                          # дальше 30 м соседом по ряду не бывает (быстро: построек сотни)
		var od: Dictionary = city.def(o)
		if od["kind"] == "decor" or od.get("fixed", false) or od["kind"] == "farm":
			continue
		if absf(angle_difference(float(o["yaw"]), yaw)) > deg_to_rad(12):
			continue
		var ob := _row_bounds(city.blueprint(o))
		var rel: Vector2 = pos - (o["pos"] as Vector2)
		var along := rel.dot(ax)
		var across := rel.dot(f)
		# фасады на одной линии?
		var front_me := across + float(bb[3])
		var front_o := float(ob[3])
		if absf(front_me - front_o) > 1.4:
			continue
		var gap_r := along + float(bb[0]) - float(ob[1])     # справа от соседа
		var gap_l := float(ob[0]) - (along + float(bb[1]))   # слева от соседа
		var shift := front_o - front_me
		# как в Town to City: дома в ряд по одной линии фасадов, но с промежутком — туда можно поставить украшения
		if gap_r > -0.3 and gap_r < 1.9:
			return pos - ax * (gap_r - ROW_GAP) + f * shift
		if gap_l > -0.3 and gap_l < 1.9:
			return pos + ax * (gap_l - ROW_GAP) + f * shift
	return pos


static var _row_cache := {}           # чертёж → границы следа (фасад — по передней стене); считаются один раз


## Границы следа постройки [minx, maxx, minz, фасад z] — из кэша (не копия: не менять!)
func _row_bounds(bp: Bp) -> Array:
	var key := bp.get_instance_id()
	if not _row_cache.has(key):
		var ob := _bounds(bp)
		var ofz := bp.front_z()
		if ofz > -INF:
			ob[3] = ofz
		_row_cache[key] = ob
	return _row_cache[key]


func _update_tool() -> void:
	hover = ground_at_mouse()
	brush_ring.visible = false
	brush_box.visible = false
	var over_ui := hud and hud.mouse_over_ui()
	if tool == "" and hover != Vector2.INF and not over_ui:
		var pl := land.plot_of(hover)
		_plot_hover(pl if plot_signs.has(pl) and not land.is_owned(hover) else Vector2i(-1, -1))
	else:
		_plot_hover(Vector2i(-1, -1))
	if tool == "floor":
		_floor_hover(over_ui)                 # дом ловит луч (и стрелка над крышей) — даже на фоне неба
		return
	if tool == "" or hover == Vector2.INF or over_ui:
		cover.preview_off()                   # подпись у курсора — только когда стройка над землёй
		if ghost:
			ghost.visible = false
		if tool in ["bulldoze", "copy", "move", "settle"]:
			# постройку ловит луч — даже если за ней небо, а не земля
			if over_ui:
				_clear_highlight()
			elif tool == "settle":
				_settle_hover(hover)
			else:
				_hover_any(hover)
		if painting and hud:
			hud.stroke_live(stroke_cost, tool, _paint_broke)
		return
	if is_road_tool(tool):
		var y := land.height_at(hover.x, hover.y)
		if brush_square:
			brush_box.visible = true
			brush_box.position = Vector3(hover.x, y + 0.05, hover.y)
			brush_box.scale = Vector3(brush_r, 1.0, brush_r)
		else:
			brush_ring.visible = true
			brush_ring.position = Vector3(hover.x, y + 0.08, hover.y)
			brush_ring.scale = Vector3(brush_r, 1.0, brush_r)
		if painting and not brush_line:
			_paint_to(hover)
		if painting and hud:
			var shown := stroke_cost
			if brush_line and line_from != Vector2.INF:
				shown = line_from.distance_to(hover) * hud.road_price_m(tool)   # прямая ляжет при отпускании — примерная цена
			hud.stroke_live(shown, tool, _paint_broke)     # «этот мазок: N ден.» у курсора, казна — сразу
		return
	if tool in ["bulldoze", "copy", "move"]:
		_hover_any(hover)
		return
	if tool == "settle":
		_settle_hover(hover)
		return
	if tool == "move_nature":
		_move_nature_ghost()
		return
	if not Defs.B.has(tool):
		return
	var pl := placement(tool, hover)
	place_info = pl
	var key := "%s:%d:%d:%d" % [tool, pl["tier"], pl["variant"], pl["color"]]
	if ghost == null or ghost_key != key:
		if ghost:
			ghost.queue_free()
		ghost = Parts.ghost(Catalog.make(tool, pl["tier"], pl["variant"], pl["color"]), "place")
		add_child(ghost)
		ghost_key = key
	ghost.visible = true
	var ok: bool = pl["err"] == ""
	Parts.ghost_color(ghost, Color(0.45, 1.0, 0.45, 0.32) if ok else Color(1.0, 0.25, 0.2, 0.5))
	var y := float(pl["y"]) if ok else land.height_at(pl["pos"].x, pl["pos"].y)
	ghost.transform = Transform3D(Basis(Vector3.UP, pl["yaw"]), Vector3(pl["pos"].x, y + 0.02, pl["pos"].y))
	# охват — без кругов: синие дома уже с такой же, зелёные получат эту (решение владельца Д3)
	if Cover.kind_of(tool) != "":
		cover.preview(tool, pl["pos"])
	if hud:
		hud.tool_status(pl["err"])


## Подсветка постройки под курсором: снос — красная, копировать и перенести — золотая
func _hover_any(p: Vector2) -> void:
	var b := pick_building()
	if b.is_empty() and tool in ["bulldoze", "move"] and p != Vector2.INF:
		var it := nature_at(p)
		if not it.is_empty():
			_hover_nature(it)
			return
	hover_nature = {}
	_hover_building(b)


## Подсветка дерева или камня (снос — красным, перенос — золотым)
func _hover_nature(it: Dictionary) -> void:
	var key := "n%d_%d:%s" % [int((it["p"] as Vector2).x * 100), int((it["p"] as Vector2).y * 100), tool]
	hover_nature = it
	if key == highlight_key:
		return
	_clear_highlight()
	highlight_key = key
	var bp := Bp.new(1)
	bp.parts.append([it["name"], Transform3D.IDENTITY, it["remap"]])
	highlight = Parts.ghost(bp, "shell", Color(1.0, 0.18, 0.12, 0.5) if tool == "bulldoze" else Color(1.0, 0.85, 0.4, 0.4))
	highlight.transform = it["xf"]
	add_child(highlight)
	if hud:
		var nm: String = it["name"]
		var what := "дерево" if nm.contains("Tree") else ("куст" if nm.contains("Bush") else "камень")
		hud.tool_status(("Убрать %s" % what) if tool == "bulldoze" else ("Перенести %s" % what))


func _move_nature_ghost() -> void:
	if ghost == null:
		var bp := Bp.new(1)
		bp.parts.append([moving_nature["name"], Transform3D.IDENTITY, moving_nature["remap"]])
		ghost = Parts.ghost(bp, "place")
		add_child(ghost)
	ghost.visible = true
	var basis: Basis = (moving_nature["xf"] as Transform3D).basis
	var ok := land.occ_at(hover) == 0 and not land.is_water(hover) and not land.is_road(hover)
	Parts.ghost_color(ghost, Color(0.45, 1.0, 0.45, 0.32) if ok else Color(1.0, 0.25, 0.2, 0.5))
	ghost.transform = Transform3D(basis.rotated(Vector3.UP, tool_yaw), Vector3(hover.x, land.height_at(hover.x, hover.y), hover.y))


func _hover_building(b: Dictionary) -> void:
	var key := "" if b.is_empty() else "%d:%s" % [b["id"], tool]
	if key == highlight_key:
		return
	_clear_highlight()
	highlight_key = key
	if b.is_empty() or (tool != "" and city.def(b).get("fixed", false) and tool != "copy"):
		return
	var col := Color(1.0, 0.18, 0.12, 0.5) if tool == "bulldoze" else Color(1.0, 0.85, 0.4, 0.35)
	if tool == "":
		col = Color(1, 1, 1, 0.12)
	highlight = Parts.ghost(city.blueprint(b), "shell", col)
	highlight.transform = city.xf(b)
	add_child(highlight)
	if hud and tool == "bulldoze":
		hud.tool_status("Снести: %s (вернётся %s ден.)" % [city.def(b)["name"], hud.fmt(float(city.def(b)["cost"]) * Defs.REFUND)])


func _clear_highlight() -> void:
	if highlight:
		highlight.queue_free()
		highlight = null
	highlight_key = ""


# ---------- заселение семьи (как в Town to City: значок семьи → подсвеченный дом) ----------

func start_settle(name: String) -> void:
	var f := city.arrival(name)
	if f.is_empty():
		return
	hud.close_panels()
	settle_fam = f
	set_tool("settle")
	_settle_marks_show()


func _clear_settle_marks() -> void:
	for m in settle_marks:
		(m as Node).queue_free()
	settle_marks = []
	for k in settle_keys:
		hud.clear_badge(k)
	settle_keys = []


## Все дома, куда семья может въехать, мягко светятся
func _settle_marks_show() -> void:
	_clear_settle_marks()
	for b in city.homes_for(settle_fam):
		var g := Parts.ghost(city.blueprint(b), "shell", Color(1.0, 0.95, 0.7, 0.22))
		g.transform = city.xf(b)
		add_child(g)
		settle_marks.append(g)
		var o := Parts.ghost(city.blueprint(b), "outline", Color(1.0, 0.9, 0.55))
		o.transform = city.xf(b)
		add_child(o)
		settle_marks.append(o)
		# ключи над домом: здесь есть место
		hud.set_badge("settle%d" % b["id"], Vector3(b["pos"].x, float(b["y"]) + city.blueprint(b).top_y() + 1.2, b["pos"].y), "keys")
		settle_keys.append("settle%d" % b["id"])


## Пока выбираем дом, город живёт: обновить подсветку (или выйти, если семьи уже нет)
func _settle_refresh() -> void:
	if tool != "settle":
		return
	var f := city.arrival(settle_fam.get("name", ""))
	if f.is_empty():
		set_tool("")
		return
	settle_fam = f
	_settle_marks_show()


func _settle_hover(_p: Vector2) -> void:
	var b := _settle_pick()
	if b.is_empty() or not city.is_house(b):
		_clear_highlight()
		hud.tool_status("")
		return
	if city.can_host(b, settle_fam):
		var key := "settle:%d" % b["id"]
		if key != highlight_key:
			_clear_highlight()
			highlight_key = key
			highlight = Parts.ghost(city.blueprint(b), "outline", Color(1.0, 1.0, 0.92))
			highlight.transform = city.xf(b)
			add_child(highlight)
		hud.tool_status("")
	else:
		_clear_highlight()
		var cls: String = settle_fam["cls"]
		if city.def(b)["cls"] != cls:
			hud.tool_status("Этот дом для другого класса — им нужен «%s»" % Defs.B[Defs.CLASSES[cls]["house"]]["name"])
		else:
			var free := city.house_cap(b) - int(b["pop"]) - int(b.get("coming", 0))
			hud.tool_status("Тесно: свободно мест %d, а их %d" % [maxi(0, free), int(settle_fam["n"])])


## Дом под курсором для заселения: луч по всей модели; украшение на стене — значит, его дом
func _settle_pick() -> Dictionary:
	var b := pick_building()
	if b.has("host"):
		b = city.buildings.get(int(b["host"]), {})
	return b


func _settle_into(b: Dictionary) -> bool:
	var name: String = settle_fam.get("name", "")
	if name == "" or not city.assign(name, b["id"]):
		return false
	sound.ui("place")
	set_tool("")
	return true


## «Выбрать дом за меня»: ближайший к станции подходящий дом
func settle_auto() -> void:
	var homes := city.homes_for(settle_fam)
	if homes.is_empty():
		return
	var c := city.center()
	var from: Vector2 = c["pos"] if not c.is_empty() else Land.CENTER
	# сначала — дома, где после этой семьи не останется «лишнего» места, в которое не влезет никто
	# (у плебеев семьи от двух: одно свободное место так и пустовало бы, а этаж не надстроить)
	var fmin := int(Defs.FAMILY_SIZE[String(settle_fam["cls"])][0])
	var waste := func(h: Dictionary) -> int:
		var left := city.house_cap(h) - int(h["pop"]) - int(h.get("coming", 0)) - int(settle_fam["n"])
		return 1 if left > 0 and left < fmin else 0
	homes.sort_custom(func(a, b):
		var wa: int = waste.call(a)
		var wb: int = waste.call(b)
		if wa != wb:
			return wa < wb
		return (a["pos"] as Vector2).distance_to(from) < (b["pos"] as Vector2).distance_to(from))
	_settle_into(homes[0])


# ---------- «Этаж» (U), как в Town to City: щёлкнуть по дому со стрелкой или вести по улице с зажатой кнопкой ----------
# Готовые дома (полные, счастливые) светятся зелёным, над крышей — стрелка с ценой (cover.gd, _floor). Каждый дом
# за мазок — один этаж, за свою цену; кончились денарии — мазок дальше не надстраивает. Монетки звенят раз на мазок,
# итог — одной строкой в колокольчик (City.floors_done). Кнопки «надстроить все разом» нет (решение владельца Д4)

## Дом под курсором: стрелка над крышей (по ней щёлкают чаще всего) или сама модель; украшение на стене — его дом
func _floor_pick() -> Dictionary:
	if hud:
		var k: String = hud.badge_at(_mouse_pos, "fl")
		if k != "" and k.substr(2).is_valid_int() and city.buildings.has(int(k.substr(2))):
			return city.buildings[int(k.substr(2))]
	return _settle_pick()


## Каждый кадр с «Этажом» в руках: подсветка и подпись у дома под курсором; с зажатой кнопкой — надстроить его
func _floor_hover(over_ui: bool) -> void:
	if floor_drag and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_floor_end()                          # кнопку отпустили над окном — мазок окончен
	var b := {} if over_ui else _floor_pick()
	if not b.is_empty() and not city.is_house(b):
		b = {}
	if floor_drag and not b.is_empty():
		_floor_buy(b)
	if over_ui:
		floor_hover = -1
		_clear_highlight()
		cover.preview_off()
		return
	cover.say(_floor_lines(b))
	if b.is_empty():
		floor_hover = -1
		_clear_highlight()
		return
	var ok := city.can_buy_floor(b) == ""
	floor_hover = 1 if ok else 0
	var key := "floor:%d:%d:%s" % [int(b["id"]), int(b["tier"]), ok]
	if key != highlight_key:
		_clear_highlight()
		highlight_key = key
		if ok:
			highlight = Parts.ghost(city.blueprint(b), "outline", Color(1.0, 1.0, 0.92))
			highlight.transform = city.xf(b)
			add_child(highlight)


## Подпись у курсора: [зелёная — этаж и цена (или только что надстроили), синяя — итог мазка, кремовая — почему нельзя]
func _floor_lines(b: Dictionary) -> Array:
	var tot := ""
	if not floor_done.is_empty():
		tot = "Этот мазок: %d %s · %s ден." % [floor_done.size(), City.plural(floor_done.size(), "этаж", "этажа", "этажей"), hud.fmt(floor_spent)]
	if b.is_empty():
		return ["", tot, "Не хватает денариев" if floor_broke else ""]
	if floor_done.has(int(b["id"])):
		return ["Надстроили %d-й этаж — скоро въедет новая семья" % int(b["tier"]), tot, ""]
	var why := city.can_buy_floor(b)
	var price := city.floor_price(b)
	if why == "":
		var per := int(Defs.CLASSES[city.def(b)["cls"]]["per_floor"])
		return ["Дом семьи %s: %d-й этаж · %s ден. · +%d %s" % [city._fam_name(b), int(b["tier"]) + 1, hud.fmt(price), per, City.plural(per, "место", "места", "мест")], tot, ""]
	if city.can_buy_floor(b, false) == "":
		why = "Не хватает денариев: этаж стоит %s ден." % hud.fmt(price)
	return ["", tot, why]


## Надстроить дом b в этом мазке (если он готов и денариев хватает)
func _floor_buy(b: Dictionary) -> void:
	if floor_broke or floor_done.has(int(b["id"])) or city.can_buy_floor(b, false) != "":
		return
	var price := city.floor_price(b)
	if city.money < float(price):
		floor_broke = true                    # денарии кончились — дальше этот мазок не надстраивает
		return
	if city.buy_floor(b, true):
		floor_done.append(int(b["id"]))
		floor_spent += price
		if floor_done.size() == 1:
			sound.ui("coins")                 # монетки — один раз на мазок, а не на каждый дом


## Мазок окончен (кнопку отпустили, сменили инструмент): итог — одной строкой в колокольчик
func _floor_end() -> void:
	floor_drag = false
	city.floors_done(floor_done, floor_spent)
	floor_done = []
	floor_spent = 0
	floor_broke = false


## Рожицы после стройки (как в Town to City): над домами, чьё счастье поменялось, — улыбка или грусть и «+5%»,
## волной от постройки (дальние — позже). Не в меню и готовом городе, не в ролике нового ранга, без звука
func _happy_pops(before: Dictionary, at: Vector2) -> void:
	if before.is_empty() or hud == null or mode in ["menu", "demo"] or promo or (rig and rig.cine):
		return
	var after := city.happy_map()
	var ch := []
	for id in after:
		if before.has(id) and int(after[id]) != int(before[id]):
			ch.append([absi(int(after[id]) - int(before[id])), int(id), int(after[id]) - int(before[id])])
	ch.sort_custom(func(a, b): return a[0] > b[0])
	for e: Array in ch.slice(0, POPS_MAX):
		var h: Dictionary = city.buildings[e[1]]
		var top := Vector3(h["pos"].x, float(h["y"]) + city.blueprint(h).top_y() + 1.0, h["pos"].y)
		hud.happy_pop(top, e[2], minf(1.2, at.distance_to(h["pos"]) * 0.03))


## Лавка, украшение, памятник, склад — после них над домами всплывают рожицы
static func _pops_for(type: String) -> bool:
	return Defs.B.has(type) and Defs.B[type]["kind"] in ["shop", "decor", "monument", "store"]


## Действие, от которого может поменяться счастье домов (наём в карточке лавки), — и рожицы над теми, у кого поменялось
func happy_action(f: Callable, at: Vector2) -> void:
	var h0 := city.happy_map()
	f.call()
	_happy_pops(h0, at)


## Выбрать постройку: обводка по силуэту и карточка; у лавки, памятника, украшения, склада — подсветка охвата
func select_building(b: Dictionary) -> void:
	if select_outline:
		select_outline.queue_free()
		select_outline = null
	selected = b
	if cover:
		cover.refresh()
	if b.is_empty():
		return
	select_outline = Parts.ghost(city.blueprint(b), "outline", Color(1.0, 0.96, 0.82))
	select_outline.transform = city.xf(b)
	add_child(select_outline)


func _unhandled_input(e: InputEvent) -> void:
	if not ready_done or mode == "menu":
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_rmb_down = mb.position
				_rmb_moved = 0.0
				_rmb_armed = true
			elif _rmb_armed:
				_rmb_armed = false
				if maxf(_rmb_moved, mb.position.distance_to(_rmb_down)) < 6.0:
					# правая кнопка щелчком (без движения) — отменить инструмент и закрыть свиток стройки,
					# без инструмента — закрыть окна и снять выбор (как в Town to City). Тянули карту — ничего не закрываем
					hud._close_tray()
					if tool != "":
						set_tool("")
					elif not hud.close_panels() and selected.is_empty() and hud.overlay != "":
						hud.set_overlay("")           # окон и выбора нет — правая кнопка закрывает «Обзор»
					else:
						select_building({})
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				press_screen = mb.position
				press_hover = hover
				press_pl = place_info.duplicate() if Defs.B.has(tool) else {}
				_click()
			else:
				_release()
	elif e is InputEventMouseMotion and pressing and Defs.B.has(tool):
		var mpos := (e as InputEventMouseMotion).position
		var dx := mpos.x - press_screen.x
		# поворот — только если мышь заметно и именно вбок ушла с зажатой кнопкой; дрожь руки при щелчке — не поворот
		if not rot_drag and absf(dx) > ROT_DRAG_PX and absf(dx) > absf(mpos.y - press_screen.y) * 1.3 and press_hover != Vector2.INF:
			rot_drag = true
			if place_lock.is_empty():
				var pl0 := press_pl if press_pl.has("pos") else placement(tool, press_hover)
				place_lock = {"p": pl0["pos"]}
				rot_yaw0 = float(pl0["yaw"])
			else:
				rot_yaw0 = tool_yaw
		if rot_drag:
			# без скачка: отсчёт поворота — от порога
			tool_yaw = rot_yaw0 + (dx - signf(dx) * minf(absf(dx), ROT_DRAG_PX)) * deg_to_rad(0.6)
	elif e is InputEventKey and e.pressed and not e.echo:
		var k := e as InputEventKey
		match k.keycode:
			KEY_ESCAPE:
				# как в Town to City: отменить инструмент → закрыть окна → снять выбор → меню игры
				if tool != "":
					set_tool("")
				elif hud.close_panels():
					pass
				elif not selected.is_empty():
					select_building({})
				elif hud.overlay != "":
					hud.set_overlay("")               # потом — закрыть «Обзор»
				else:
					hud._top_action("menu")
			KEY_Z:
				if k.ctrl_pressed:
					_undo()
				else:
					_rot_keep()
					tool_yaw = _yaw_now() - deg_to_rad(15)
					manual_yaw = true
					yaw_set = true
					free_yaw = tool_yaw
			KEY_Y:
				if k.ctrl_pressed:
					_redo()
			KEY_X:
				_rot_keep()
				tool_yaw = _yaw_now() + deg_to_rad(15)
				manual_yaw = true
				yaw_set = true
				free_yaw = tool_yaw
			KEY_C:
				if k.ctrl_pressed:
					set_tool("copy")
				elif Defs.B.has(tool):
					next_variant = posmod(next_variant + 1, int(Defs.B[tool].get("variants", 1)))
			KEY_V:
				if Defs.B.has(tool):
					next_variant = posmod(next_variant - 1, int(Defs.B[tool].get("variants", 1)))
			KEY_R:
				if is_road_tool(tool):
					brush_over = not brush_over
				else:
					snap = not snap
				hud.refresh_tools()
			KEY_M:
				set_tool("move")
			KEY_U:
				set_tool("" if tool == "floor" else "floor")
			KEY_DELETE:
				set_tool("bulldoze")
			KEY_SPACE:
				hud.toggle_pause()
			KEY_1:
				hud.set_speed(1.0)
			KEY_2:
				hud.set_speed(2.0)
			KEY_3:
				hud.set_speed(4.0)
			KEY_BRACKETLEFT:
				brush_r = maxf(0.5, brush_r - 0.25)
				hud.refresh_tools()
			KEY_BRACKETRIGHT:
				brush_r = minf(4.0, brush_r + 0.25)
				hud.refresh_tools()
			KEY_F5:
				if can_save:
					save()
					hud.notify("Город сохранён", "save")


func _click() -> void:
	# постройку ловит луч по всей модели — щёлкнуть можно и по крыше на фоне неба (земли под курсором нет)
	if hover == Vector2.INF and not tool in ["", "settle", "bulldoze", "copy", "move", "floor"]:
		return
	if is_road_tool(tool):
		painting = true
		stroke = []
		stroke_cost = 0.0
		_paint_broke = false
		if hud:
			hud.tool_status("")       # старое «не хватает денариев» — только если и этот мазок упрётся в казну
		last_paint = Vector2.INF
		if brush_line:
			line_from = hover
		else:
			_paint_to(hover)
		return
	match tool:
		"settle":
			var b := _settle_pick()
			if b.is_empty() or not city.can_host(b, settle_fam) or not _settle_into(b):
				sound.ui("error")
			return
		"floor":
			# мазок: этот дом и все готовые, над которыми пройдёт курсор, пока кнопка зажата (_floor_hover)
			floor_drag = true
			floor_done = []
			floor_spent = 0
			floor_broke = false
			var b := _floor_pick()
			if not b.is_empty() and city.is_house(b):
				_floor_buy(b)
			return
		"move_nature":
			if land.occ_at(hover) == 0 and not land.is_water(hover) and not land.is_road(hover):
				var basis: Basis = (moving_nature["xf"] as Transform3D).basis.rotated(Vector3.UP, tool_yaw)
				var xf := Transform3D(basis, Vector3(hover.x, land.height_at(hover.x, hover.y), hover.y))
				_add_nature(moving_nature["name"], xf, hover)
				moving_nature = {}
				sound.ui("place")
				set_tool("move")
			else:
				sound.ui("error")
			return
		"bulldoze":
			var b := pick_building()
			if b.is_empty() and not hover_nature.is_empty() and hover != Vector2.INF:
				remove_nature(hover_nature)
				hover_nature = {}
				_clear_highlight()
				_puff(Vector3(hover.x, land.height_at(hover.x, hover.y), hover.y), Color("cfe0b0"))
				sound.ui("demolish")
				return
			if not b.is_empty():
				if city.def(b).get("fixed", false):
					hud.notify("Почтовая станция не сносится — с неё начинается город", "info")
				else:
					var h0 := city.happy_map() if _pops_for(b["type"]) else {}
					city.remove(b)
					_clear_highlight()
					sound.ui("demolish")
					_happy_pops(h0, b["pos"])     # снесли лавку или украшение — над кем стало хуже, грустные рожицы
			return
		"copy":
			var b := pick_building()
			if not b.is_empty() and not city.def(b).get("fixed", false):
				tool_variant = -1
				set_tool(b["type"])
				next_variant = int(b["variant"])
			return
		"move":
			if not moving.is_empty():
				return
			var b := pick_building()
			if not b.is_empty() and city.def(b).get("wall", false):
				hud.tool_status("Украшение на стене не переносится — снесите его и повесьте заново")
				sound.ui("error")
				return
			if b.is_empty() and not hover_nature.is_empty() and hover != Vector2.INF:
				moving_nature = hover_nature.duplicate()
				remove_nature(hover_nature)
				hover_nature = {}
				_clear_highlight()
				tool_yaw = 0.0
				tool = ""
				set_tool("move_nature")
				return
			start_move(b)
			return
	if Defs.B.has(tool):
		if not Defs.B[tool].get("wall", false):
			pressing = true
			rot_drag = false
			return
		_build_here()
		return
	# без инструмента: постройка под курсором (вся модель — крыша, верх, украшения) — карточка; иначе участок на продажу
	var b := pick_building()
	if b.is_empty() and hover != Vector2.INF:
		var plot := land.plot_of(hover)
		if city.can_buy(plot) and plot_signs.has(plot) and not land.is_owned(hover):
			hud.ask_buy(plot)
			return
	if not b.is_empty() and city.def(b)["kind"] == "center" and not city.arrivals.is_empty():
		start_settle(city.arrivals[0]["name"])
	elif not b.is_empty():
		select_building(b)
		hud.open_info(b)
	else:
		select_building({})
		hud.close_panels()


## Поднять постройку b для переноса (инструмент «Перенос» или кнопка «Перенести» в карточке).
## Жильцы и украшения на стенах едут вместе с ней. false — эту постройку не переносят
func start_move(b: Dictionary) -> bool:
	if b.is_empty() or not moving.is_empty() or not city.buildings.has(int(b["id"])):
		return false
	if city.def(b).get("fixed", false):
		return false
	if city.def(b).get("wall", false):
		if hud:
			hud.tool_status("Украшение на стене не переносится — снесите его и повесьте заново")
		sound.ui("error")
		return false
	moving = {"id": b["id"], "type": b["type"], "tier": b["tier"], "variant": b["variant"], "color": b["color"], "pop": b["pop"],
		"families": b["families"], "pos": b["pos"], "yaw": b["yaw"], "decor": _hosted(b), "hire": b.get("hire", -1),
		"born": int(b.get("born", b["id"]))}     # порядок постройки едет с ней: перенесённая школа не станет «лишней»
	if _pops_for(b["type"]):
		moving["happy0"] = city.happy_map()   # счастье домов до переноса: на новом месте — рожицы над теми, у кого поменялось
	city.moving_id = int(b["id"])
	city.remove(b, false)
	var t: String = b["type"]
	tool = ""
	set_tool(t)
	next_variant = int(moving["variant"])
	tool_yaw = float(moving["yaw"])
	if hud:
		hud.notify("Перенос: поставьте постройку на новое место (правая кнопка — вернуть обратно)", "move")
	return true


## Украшения на стенах постройки: тип и место относительно неё
func _hosted(b: Dictionary) -> Array:
	var out := []
	var ax := City.axis(b["yaw"])
	var fw := City.facing(b["yaw"])
	for id in city.buildings:
		var o: Dictionary = city.buildings[id]
		if int(o.get("host", -1)) == int(b["id"]):
			var rel: Vector2 = (o["pos"] as Vector2) - (b["pos"] as Vector2)
			out.append([o["type"], rel.dot(ax), rel.dot(fw), float(o["yaw"]) - float(b["yaw"]), float(o["y"]) - float(b["y"]), o["variant"], o["color"]])
	return out


## Постройка встала на новое место: жильцы идут за ней, украшения возвращаются на её стены
func _moved(b: Dictionary, m := {}) -> void:
	if m.is_empty():
		m = moving
	var old := int(m["id"])
	if int(m.get("hire", -1)) >= 0:
		b["hire"] = int(m["hire"])
	city.moving_id = -1
	city.rehome(old, int(b["id"]))
	var ax := City.axis(b["yaw"])
	var fw := City.facing(b["yaw"])
	for dd: Array in m.get("decor", []):
		var p: Vector2 = (b["pos"] as Vector2) + ax * float(dd[1]) + fw * float(dd[2])
		var o := city.place(dd[0], p, float(b["yaw"]) + float(dd[3]), int(dd[5]), int(dd[6]), true)
		o["host"] = b["id"]
		o["y"] = float(b["y"]) + float(dd[4])
		_show(o)


## Поворот призрака сейчас (если он стоит у дороги — повёрнут к ней)
func _yaw_now() -> float:
	if not manual_yaw and place_info.has("yaw"):
		return float(place_info["yaw"])
	return tool_yaw


## Поставить постройку там, где призрак (после щелчка без поворота)
func _build_here() -> void:
	if Defs.B.has(tool):
		var pl := placement(tool, hover)
		if pl["err"] != "":
			hud.tool_status(pl["err"])        # повёрнутый призрак остаётся на месте — можно довернуть
			sound.ui("error")
			return
		place_lock = {}
		var b: Dictionary
		if not moving.is_empty():
			b = city.place(tool, pl["pos"], pl["yaw"], int(pl["variant"]), int(moving["color"]), true)
			b["born"] = int(moving.get("born", b["born"]))
			b["tier"] = int(moving["tier"])
			b["pop"] = int(moving["pop"])
			b["families"] = moving["families"]
			var h0: Dictionary = moving.get("happy0", {})
			_moved(b)
			moving = {}
			_show(b)
			city.compute()
			set_tool("")
			_happy_pops(h0, pl["pos"])
		else:
			var h0 := city.happy_map() if _pops_for(tool) else {}
			build_anim = true
			b = city.place(tool, pl["pos"], pl["yaw"], int(pl["variant"]), int(pl["color"]))
			build_anim = false
			if pl.has("host"):
				b["host"] = pl["host"]
				b["y"] = pl["y"]
				_show(b)
			_happy_pops(h0, pl["pos"])           # лавка, украшение, памятник: рожицы волной над домами, кому стало лучше или хуже
			if tool_variant < 0:
				next_variant = randi() % int(Defs.B[tool].get("variants", 1))
			if pl.get("sub", "") == "free" and not city.tips.has("free_place") and mode != "demo" and not (tutorial and tutorial.active()):
				city.tips["free_place"] = true
				hud.advisor("Строим где хотите", "Дом встаёт там, куда вы навели, — на траве, на площади, хоть на мостовой. Повернуть — зажмите кнопку мыши и ведите вбок (или Z / X); этот поворот запомнится и для следующих домов.\n\nПодведите дом вплотную к дороге — он сам встанет ровно фасадом к ней. Нужно одно: у входа должна быть мостовая, иначе жители не дойдут.")
			# поворот был для этой постройки: следующая снова сама встанет фасадом к дороге (а поворот
			# tool_yaw остаётся — для мест без дороги и для украшений)
			manual_yaw = false
			rot_off = Vector2.ZERO
		_puff(Vector3(pl["pos"].x, float(pl["y"]), pl["pos"].y))
		sound.ui("place")
		return


func _cancel_move() -> void:
	var m := moving
	moving = {}
	var b := city.place(m["type"], m["pos"], m["yaw"], int(m["variant"]), int(m["color"]), true)
	b["born"] = int(m.get("born", b["born"]))
	b["tier"] = int(m["tier"])
	b["pop"] = int(m["pop"])
	b["families"] = m["families"]
	_moved(b, m)
	_show(b)
	city.compute()


func _release() -> void:
	if floor_drag:
		_floor_end()
		return
	if pressing:
		pressing = false
		if rot_drag:
			rot_drag = false
			if absf(angle_difference(tool_yaw, rot_yaw0)) < deg_to_rad(4.0):
				# мышь вернули почти туда же — это просто щелчок: строим там, где стояло, фасадом к дороге
				tool_yaw = rot_yaw0
				if not hud.mouse_over_ui():
					_build_here()
				place_lock = {}
			else:
				place_lock = {}                   # повернули — дальше постройка едет за мышкой, щелчок — построить
				manual_yaw = true
				yaw_set = true
				free_yaw = tool_yaw
				rot_off = Vector2.ZERO
		elif not hud.mouse_over_ui() and (hover != Vector2.INF or not place_lock.is_empty()):
			_build_here()
		return
	if not painting:
		return
	if brush_line and line_from != Vector2.INF and hover != Vector2.INF and not _paint_broke:
		var a := line_from
		var n := int(a.distance_to(hover) / (Land.CELL * 2.0)) + 1
		last_paint = Vector2.INF
		for s in n + 1:
			_paint_at(a.lerp(hover, float(s) / n))
			if _paint_broke:
				break                 # деньги кончились — дальше линию не тянем (без дыр в мостовой)
	if hud:
		if brush_line:
			hud.stroke_live(stroke_cost, tool, _paint_broke)   # вместо прикидки — сколько списано на самом деле
		hud.stroke_live(stroke_cost, tool, false, true)    # мазок окончен — подпись у курсора гаснет
	line_from = Vector2.INF
	painting = false
	if not stroke.is_empty():
		if tool != "erase":
			city.road_cells += stroke.size()
			city._check_goals()
		undo_stack.append({"ch": stroke, "cost": stroke_cost})
		redo_stack.clear()
		if undo_stack.size() > 40:
			undo_stack.pop_front()
		city.compute()
		hud.refresh()
	stroke = []


func _paint_to(p: Vector2) -> void:
	if _paint_broke or (last_paint != Vector2.INF and p.distance_to(last_paint) < brush_r * 0.3):
		return
	var a := last_paint if last_paint != Vector2.INF else p
	var n := int(a.distance_to(p) / (Land.CELL * 2.0)) + 1
	for s in n + 1:
		_paint_at(a.lerp(p, float(s) / n))
	last_paint = p


func _paint_at(q: Vector2) -> void:
	var kinds := {"road": Land.Kind.ROAD, "plaza": Land.Kind.PLAZA, "path": Land.Kind.DIRT, "erase": Land.Kind.GRASS}
	var kd: int = kinds[tool]
	var ch := land.paint_circle(q, brush_r, kd, kd != Land.Kind.GRASS, true, brush_square, brush_over)
	if ch.is_empty():
		return
	var cost := 0.0
	if tool != "erase":
		var fresh := 0
		for c in ch:
			if int(c[1]) != kd:
				fresh += 1        # где покрытие уже было, кисть только подравнивает высоту — это бесплатно
		cost = fresh * float(Defs.ROAD_COST[tool])
	if cost > city.money:
		# денег не хватило: дальше этот мазок не рисуется, но уже проложенное остаётся (и отменяется Ctrl+Z целиком)
		land.undo(ch)
		hud.tool_status("Не хватает денариев: в казне %s ден." % hud.fmt(city.money))
		hud.stroke_live(stroke_cost, tool, true)
		_paint_broke = true
		sound.ui("error")
		return
	city.money -= cost
	stroke_cost += cost
	stroke.append_array(ch)
	clear_nature(q, brush_r + 0.3)


func _undo() -> void:
	if undo_stack.is_empty():
		return
	var u: Dictionary = undo_stack.pop_back()
	var now := []
	for c in u["ch"]:
		var k := land.idx(c[0].x, c[0].y)
		now.append([c[0], land.kind[k], land.h[k]])
	# клетки, где после мазка поставили дом, не откатываются (land.undo их пропускает) — и денег за них не вернём
	var done := land.undo(u["ch"])
	var part := float(done.size()) / maxf(1.0, float(u["ch"].size()))
	var back := []
	for i in done:
		back.append(now[i])
	var cost := float(u["cost"]) * part
	redo_stack.append({"ch": back, "cost": cost})
	city.money += cost
	city.compute()
	hud.refresh()


func _redo() -> void:
	if redo_stack.is_empty():
		return
	var r: Dictionary = redo_stack.pop_back()
	if city.money < float(r["cost"]):
		return
	var back := []
	for c in r["ch"]:
		var k := land.idx(c[0].x, c[0].y)
		back.append([c[0], land.kind[k], land.h[k]])
	var done := land.undo(r["ch"])
	var part := float(done.size()) / maxf(1.0, float(r["ch"].size()))
	var keep := []
	for i in done:
		keep.append(back[i])
	var cost := float(r["cost"]) * part
	undo_stack.append({"ch": keep, "cost": cost})
	city.money -= cost
	city.compute()
	hud.refresh()


# ---------- сохранение ----------

func save_path() -> String:
	# папка: --savedir=, CIVCITY_SAVEDIR от программы запуска, в редакторе D:/CivCity/saves, иначе user:// (см. game_paths.gd)
	return GamePaths.save_dir().path_join(SAVE_NAME)


func save() -> void:
	if not can_save:
		return
	if not moving.is_empty() or not moving_nature.is_empty():
		set_tool("")                          # перенос не закончен — вернуть на место, иначе постройка пропадёт
	var data := city.save_data()
	data["land"] = land.save_changes()
	data["hour"] = hour
	data["version"] = 2
	var s := JSON.stringify(data)
	var f := FileAccess.open(save_path(), FileAccess.WRITE)
	if f:
		f.store_string(s)
		f.close()
	Account.me().after_save(s)                # и в облако (не чаще раза в минуту, при выходе — сразу)


func _load() -> bool:
	if not FileAccess.file_exists(save_path()):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path()))
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 1)) < 2:
		return false
	land.load_changes(data.get("land", {}))
	city.load_data(data)
	if clock_hours:
		hour = float(data.get("hour", 8.0))
	for id in city.buildings:
		_show(city.buildings[id])
	return true


## Перезапуск сцены в другом режиме (меню, свой город, новый, готовый)
func restart(m: String) -> void:
	if can_save and ready_done:
		save()
	boot = {m: "1"}
	if _autogo != "" and shot_path != "":
		boot["shot"] = shot_path
		boot["frames"] = str(shot_frame)
	get_tree().reload_current_scene()


func new_game() -> void:
	if FileAccess.file_exists(save_path()):
		DirAccess.remove_absolute(save_path())
	can_save = false
	restart("new")


# ---------- готовый город (меню и витрина) ----------

func _demo_town() -> void:
	pave_build = false                    # городок раскладывается по прежним правилам (без стройки на площади)
	city.money = 90000
	city.rp = 0
	city.level = 6
	for r in Defs.RESEARCH:
		city.research[r["id"]] = true
	for g in Defs.REQUESTS:
		city.goals_done.append(g["id"])
		if g.has("unlock"):
			city.research[g["unlock"]] = true
	var R := Land.Kind.ROAD
	var road := func(a: Vector2, b: Vector2, w: float, kd: int) -> void:
		land.paint_line(a, b, w, kd, true)
	# улицы: главная от тоннеля на юг к храму, площадь с фонтаном, поперечные улицы и переулки
	road.call(Vector2(192, 126), Vector2(192, 194), 1.7, R)
	road.call(Vector2(162, 138), Vector2(224, 138), 1.4, R)
	road.call(Vector2(162, 170), Vector2(226, 170), 1.4, R)
	road.call(Vector2(172, 138), Vector2(172, 170), 1.2, R)
	road.call(Vector2(212, 138), Vector2(212, 170), 1.2, R)
	road.call(Vector2(162, 126), Vector2(162, 178), 1.0, Land.Kind.DIRT)
	road.call(Vector2(172, 154), Vector2(182, 154), 1.0, Land.Kind.DIRT)
	road.call(Vector2(202, 154), Vector2(212, 154), 1.0, Land.Kind.DIRT)
	road.call(Vector2(226, 170), Vector2(232, 186), 1.0, Land.Kind.DIRT)
	for k in 30:
		land.paint_circle(Vector2(192, 154), 9.0, Land.Kind.PLAZA, true, false)
	var place := func(type: String, near: Vector2, r: float, tier := -1, variant := -1) -> Dictionary:
		var v := variant if variant >= 0 else randi() % int(Defs.B[type].get("variants", 1))
		for k in range(0, int(r * 2) + 1):
			var rr := k * 0.5
			var n := maxi(1, int(rr * 6))
			for q in n:
				var p := near + Vector2(cos(TAU * q / n), sin(TAU * q / n)) * rr
				var pl := placement(type, p, v)
				if str(pl["err"]).begins_with("Слишком круто"):
					var bb := _bounds(Catalog.make(type, 1, v, 0))
					var cells := land.footprint_cells([Rect2(bb[0] - 0.5, bb[2] - 0.5, bb[1] - bb[0] + 1.0, bb[3] - bb[2] + 1.0)], pl["pos"], pl["yaw"])
					land.flatten_cells(cells, snappedf(land.height_at(pl["pos"].x, pl["pos"].y), Land.STEP))
					pl = placement(type, p, v)
				if pl["err"] == "" or pl["err"] == "Не хватает денариев":
					var b := city.place(type, pl["pos"], pl["yaw"], v, -1, true)
					if tier >= 0 and city.is_house(b):
						b["tier"] = tier
						b["pop"] = city.house_cap(b)
						b["families"] = [{"name": Defs.FAMILIES[randi() % Defs.FAMILIES.size()], "n": b["pop"]}]
						_show(b)
					return b
		return {}
	seed(42)
	place.call("temple", Vector2(192, 202), 5)
	place.call("fountain", Vector2(192, 154), 1)
	place.call("forum", Vector2(214, 184), 6)
	place.call("theatre", Vector2(168, 186), 6)
	place.call("baths", Vector2(206, 146), 4)
	place.call("warehouse", Vector2(180, 128), 4)
	place.call("scriptorium", Vector2(204, 130), 4)
	place.call("library", Vector2(220, 158), 5)
	place.call("farm", Vector2(148, 146), 5)
	place.call("farm", Vector2(148, 160), 5)
	place.call("grove", Vector2(148, 174), 5)
	place.call("vineyard", Vector2(240, 176), 5)
	# лавки вокруг площади и вдоль улиц
	for t: Array in [["stall_fruit", Vector2(183, 146)], ["stall_veg", Vector2(201, 162)], ["stall_fish", Vector2(183, 163)], ["bakery", Vector2(177, 142)],
			["butcher", Vector2(207, 142)], ["weaver", Vector2(177, 166)], ["cobbler", Vector2(207, 166)], ["thermopolium", Vector2(197, 134)],
			["taberna", Vector2(186, 174)], ["musicians", Vector2(188, 148)], ["dice", Vector2(197, 160)], ["barber", Vector2(166, 150)],
			["potter", Vector2(218, 150)], ["wineshop", Vector2(166, 162)], ["jeweler", Vector2(200, 174)], ["perfumer", Vector2(218, 166)]]:
		place.call(t[0], t[1], 4)
	# дома вдоль всех улиц: у площади — повыше и побогаче
	for z in range(124, 198, 2):
		for x in range(156, 232, 2):
			var p := Vector2(x, z)
			if not land.is_road(p + Vector2(3.5, 0)) and not land.is_road(p - Vector2(3.5, 0)) and not land.is_road(p + Vector2(0, 3.5)) and not land.is_road(p - Vector2(0, 3.5)):
				continue
			var dc := p.distance_to(Vector2(192, 154))
			var type := "house_pleb"
			var r := randf()
			if dc < 30.0 and r < 0.35:
				type = "house_artisan"
			elif dc > 18.0 and dc < 44.0 and r > 0.93:
				type = "house_patrician"
			var tier := 1
			if dc < 22.0:
				tier = [2, 3, 3][randi() % 3]
			elif dc < 38.0:
				tier = [1, 2, 2, 3][randi() % 4]
			else:
				tier = [1, 1, 2][randi() % 3]
			if type == "house_patrician":
				tier = mini(tier, 2)
			var v := randi() % int(Defs.B[type]["variants"])
			var pl := placement(type, p, v)
			if pl["err"] == "":
				var b := city.place(type, pl["pos"], pl["yaw"], v, -1, true)
				b["tier"] = tier
				b["pop"] = city.house_cap(b)
				b["families"] = [{"name": Defs.FAMILIES[randi() % Defs.FAMILIES.size()], "n": b["pop"]}]
				_show(b)
	# красота: кипарисы вдоль главной улицы, скамьи и жаровни у фонтана, статуи у храма, цветы
	for k in 8:
		var a := TAU * k / 8.0 + 0.2
		place.call("bench", Vector2(192, 154) + Vector2(cos(a), sin(a)) * 5.6, 0.5)
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4
		place.call("bigbrazier", Vector2(192, 154) + Vector2(cos(a), sin(a)) * 7.8, 0.5)
	for z in range(128, 194, 4):
		for sx: float in [-1.0, 1.0]:
			if absf(z - 154) > 11:
				var p := Vector2(128 + sx * 2.6, z)
				var pl := placement("cypress", p)
				if pl["err"] == "":
					city.place("cypress", pl["pos"], 0.0, 0, -1, true)
	for t: Array in [["statue_2", Vector2(186, 194)], ["statue_4", Vector2(198, 194)], ["lion", Vector2(183, 198)], ["lion", Vector2(201, 198)]]:
		place.call(t[0], t[1], 1.5)
	for k in 90:
		var p := Vector2(randf_range(158, 230), randf_range(124, 198))
		# у каждого вида украшений несколько обликов (отдельные карточки) — в готовом городе берём любой
		var t: String = Defs.looks_of(["flowers", "bush", "planter", "tree", "flowers", "palm", "goods", "well"][k % 8]).pick_random()
		var pl := placement(t, p)
		if pl["err"] == "":
			city.place(t, pl["pos"], randf() * TAU, 0, -1, true)
	for k in 6:
		var pd: Vector3 = Land.PONDS[0][0]
		var p := Vector2(pd.x, pd.y) + Vector2(cos(k), sin(k)) * pd.z * 0.4
		var pl := placement("swan" if k % 3 == 0 else "duck", p)
		if pl["err"] == "":
			city.place("swan" if k % 3 == 0 else "duck", pl["pos"], randf() * TAU, 0, -1, true)
	city.level = 6
	city.compute()
	var c := city.center()
	c["tier"] = city.level
	for id in city.buildings:
		_show(city.buildings[id])
	pave_build = true
