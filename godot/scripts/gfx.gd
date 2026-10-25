class_name Gfx
extends Node
## Графика (этап 1 плана от 24.10): «Высокая», «Средняя», «Низкая», «Очень низкая».
##  - при первом запуске уровень выбирается по видеокарте (first_launch), в городе один раз проверяется, тянет ли
##    видеокарта (медиана 4 с больше 11 мс — на ступень ниже); у тех, кто уже играет, сама ничего не меняется;
##    ручной выбор (quality_user) никогда не перебивается;
##  - сторож кадров: в городе 20 с подряд меньше 40 кадров на «Высокой» или «Средней» — советник один раз предложит
##    «Низкую» (кнопкой); встроенная видеокарта — один раз подскажет, как включить мощную;
##  - счётчик кадров в углу (настройки → «Показывать FPS»), F3 — подробно для проверяющих (с копированием).
## «Средняя» и «Высокая» — ровно как были (снимки test_perf совпадают до бита); облегчения — только на «Низкой» и ниже.

const ORDER := ["verylow", "low", "medium", "high"]
const NAMES := {"high": "Высокая", "medium": "Средняя", "low": "Низкая", "verylow": "Очень низкая"}
const CHECK_MS := 11.0                 # проверка в городе: видеокарте нужно больше — на ступень ниже
const CHECK_SKIP := 60                 # …первые кадры не в счёт (тени, шейдеры)
const CHECK_SEC := 4.0
const WATCH_FPS := 40.0                # сторож: меньше стольких кадров в среднем…
const WATCH_SEC := 20.0                # …за столько секунд в городе
const WATCH_START := 15.0              # первые секунды после загрузки не в счёт
const VIS := {"high": 150, "medium": 150, "low": 70, "verylow": 40}     # сколько жителей рисуем на улицах
const HALF_FAR := 60.0                 # «Низкая»: жители дальше — движения через кадр; «Очень низкая» — все

static var _sun_low := -1              # тени солнца облегчены (атлас 4096, мягкость низкая): общие для всей отрисовки
static var _tex_small := false         # «Очень низкая»: большие картинки материалов — копиями вдвое меньше
static var _small := {}                # путь картинки 4096² → её копия 2048²
const SMALL_FROM := 4096

var game
## автопроверки (gpu_run.sh задаёт CIVCITY_NOMINPAUSE=1) — без выбора по видеокарте, сторожа и советов; --autoq — с ними
var auto_on := OS.get_environment("CIVCITY_NOMINPAUSE") != "1" or OS.get_cmdline_user_args().has("--autoq")
var _vp: RID
var _measure := false
var _check_n := 0
var _check_t := 0.0
var _check_ms := PackedFloat32Array()
var _watch_t := 0.0
var _watch_n := 0
var _alive_t := 0.0
var _pending := []                     # советы ждут, пока советник свободен: [[заголовок, текст, кнопка, действие]]
var _fps_box: CanvasLayer
var _fps: Label
var _fps_t := 0.0
var _dbg: PanelContainer
var _dbg_text: Label
var _half := 0


# ---------- выбор уровня по видеокарте ----------

## Уровень по видеокарте: встроенная (и программная) — «Очень низкая»; GTX 10xx/16xx, RTX 2050/3050, MX, RX 5500/6400/6500,
## Arc A3 — «Низкая»; xx60 — «Средняя»; xx70 и выше — «Высокая». Ноутбучная («Laptop», «Max-Q», RX …M) — на ступень
## ниже, но не ниже «Низкой» (3060 Laptop — «Низкая», 3070 Laptop — «Средняя», 4080 Laptop — «Высокая»);
## незнакомая отдельная — «Средняя»
static func tier_for(name: String, type: int) -> String:
	var n := name.to_lower()
	if type == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU or type == RenderingDevice.DEVICE_TYPE_VIRTUAL_GPU or type == RenderingDevice.DEVICE_TYPE_CPU:
		return "verylow"
	for w in ["llvmpipe", "swiftshader", "basic render", "software", "intel(r) uhd", "intel(r) hd", "intel(r) iris", "uhd graphics", "iris(r) xe",
			"radeon(tm) graphics", "radeon graphics", "vega 3 ", "vega 6 ", "vega 7 ", "vega 8 ", "vega 10 ", "vega 11 ", "680m", "760m", "780m", "890m"]:
		if n.contains(w):
			return "verylow"
	if n.contains("vega"):
		return "low"                       # отдельная Vega 56/64 (встроенные Vega узнаны выше)
	var laptop := n.contains("laptop") or n.contains("max-q") or n.contains("mobile")
	var s := 2                             # 1 — «Низкая», 2 — «Средняя», 3 — «Высокая», 4 — с запасом (xx80, xx90)
	var re := RegEx.create_from_string("\\b(rtx|gtx|mx|rx|arc)(?:\\(tm\\))?\\s*([a-z]?)(\\d{3,4})([a-z]?)")
	var m := re.search(n)
	if m:
		var fam := m.get_string(1)
		var letter := m.get_string(2)
		var num := int(m.get_string(3))
		var suf := m.get_string(4)
		if fam == "arc":
			s = 1 if (letter == "a" and num < 400) else 2
			laptop = laptop or suf == "m"
		elif fam == "mx" or fam == "gtx":
			s = 1
		elif fam == "rtx":
			var cls := num % 100           # 2050/3050 — 50, 4060 — 60, 3070 — 70, 4090 — 90
			if letter != "":
				s = 2                      # RTX A2000 и другие рабочие — как незнакомая
			else:
				s = 1 if cls <= 50 else (2 if cls == 60 else (3 if cls == 70 else 4))
		elif fam == "rx":
			laptop = laptop or suf == "m" or suf == "s"
			if num < 1000:
				s = 1                      # RX 470…590
			else:
				var gen := num / 1000
				var cls := (num % 100) / 10 if num >= 9000 else (num % 1000) / 100     # 6650 — 6, 9070 — 7
				if cls <= 5:
					s = 1 if cls < 5 or gen <= 6 else 2   # RX 5500/6400/6500 — «Низкая»; 7500 и новее — «Средняя»
				elif cls == 6:
					s = 2
				elif cls == 7:
					s = 3 if gen >= 6 else 2   # RX 5700 — «Средняя», 6700+/7700+ — «Высокая»
				else:
					s = 4
	elif n.contains("titan"):
		s = 4
	if laptop:
		s = maxi(1, s - 1)
	return ORDER[clampi(s, 1, 3)]


## Видеокарта для надписи в настройках и отчёта F3
static func adapter() -> String:
	return RenderingServer.get_video_adapter_name()


## Настройки прочитаны (game._load_settings). Новая установка (файла настроек не было) — уровень по видеокарте и
## одна проверка в городе; новая установка, у которой сменилась видеокарта (без ручного выбора) — заново. У тех, кто
## уже играет (файл был, выбора по видеокарте не было), — ничего не меняем: quality_auto = "kept"
static func first_launch(g, had_file: bool) -> void:
	var auto_on := OS.get_environment("CIVCITY_NOMINPAUSE") != "1" or OS.get_cmdline_user_args().has("--autoq")
	if decide(g.settings, had_file, auto_on, adapter(), RenderingServer.get_video_adapter_type()):
		_write(g)


## Решение без файлов и видеокарты (его проверяет test_gfx): поменять ли настройки st; true — записать файл
static func decide(st: Dictionary, had_file: bool, auto_on: bool, name: String, type: int) -> bool:
	if bool(st.get("quality_user", false)):
		return false
	var qa := str(st.get("quality_auto", ""))
	if not had_file:
		if not auto_on:
			return false                   # автопроверки (gpu_run.sh): прежнее поведение, «Высокая»
		_pick(st, name, type)
		return true
	if qa == "":
		st["quality_auto"] = "kept"        # уже играет: уровень не трогаем
		return true
	if qa != "kept" and str(st.get("adapter", "")) != name and auto_on:
		_pick(st, name, type)              # выбрано по видеокарте, а видеокарта другая — выбрать заново
		return true
	return false


static func _pick(st: Dictionary, name: String, type: int) -> void:
	var q := tier_for(name, type)
	st["quality"] = q
	st["quality_auto"] = q
	st["adapter"] = name
	st["quality_checked"] = false


## Файл настроек без применения (окно и графика ещё не созданы)
static func _write(g) -> void:
	var f := FileAccess.open(g.settings_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(g.settings))


static func lower(q: String) -> String:
	return ORDER[maxi(0, ORDER.find(q) - 1)]


static func is_low(q: String) -> bool:
	return q == "low" or q == "verylow"


# ---------- уровни ----------

## Применить уровень из game.settings["quality"]. Высокая и Средняя — прежние значения (как в project.godot и
## game._environment), каждая «облегчённая» вещь возвращается ровно к ним
static func apply(g) -> void:
	var q: String = str(g.settings.get("quality", "high"))
	if not NAMES.has(q):
		q = "high"
	var env: Environment = g.env
	if env == null:
		return
	var low := is_low(q)
	env.sdfgi_enabled = q == "high"
	env.ssil_enabled = q == "high"
	env.ssao_enabled = not low
	env.glow_enabled = not low
	var sun: DirectionalLight3D = g.sun
	if sun:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if low else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		# 175 м, как и прежняя «Низкая»: при 120 м (по плану) издалека город совсем без теней — плоский
		sun.directional_shadow_max_distance = 175.0 if low else 190.0
		sun.light_angular_distance = 0.0 if low else 2.2          # без «мягких» теней PCSS — они самые дорогие
		sun.shadow_enabled = q != "verylow"
	# атлас теней солнца и его фильтр — общие настройки отрисовки (project.godot: 8192, мягкие высокие)
	var sl := 1 if low else 0
	if sl != _sun_low:
		if sl == 1 or _sun_low == 1:
			RenderingServer.directional_shadow_atlas_set_size(4096 if low else 8192, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW if low else RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
		_sun_low = sl
	var vp: Viewport = g.get_viewport()
	if vp:
		vp.msaa_3d = Viewport.MSAA_DISABLED if low else Viewport.MSAA_4X
		# «Очень низкая»: дальние модели (деревья, жители, детали построек) упрощаются раньше (по умолчанию — 1 точка экрана)
		vp.mesh_lod_threshold = 4.0 if q == "verylow" else 1.0
		# слабые видеокарты: картинка считается меньше и аккуратно растягивается (FSR); снимки (--shot) — в полном размере
		if g.shot_path == "":
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if low else Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 0.5 if q == "verylow" else (0.75 if q == "low" else 1.0)
	if g.rig and g.rig.attrs:
		g.rig.attrs.dof_blur_far_enabled = not low
		g.rig.attrs.dof_blur_near_enabled = not low
	# земля и пейзаж за краем карты на «Низкой» тень не отбрасывают; дальние леса на «Очень низкой» не рисуются
	var cs := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if low else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for ch in g.chunk_nodes:
		(g.chunk_nodes[ch] as GeometryInstance3D).cast_shadow = cs
	for mmi: GeometryInstance3D in g.far_near:
		if not mmi.has_meta("cast"):
			mmi.set_meta("cast", mmi.cast_shadow)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if low else int(mmi.get_meta("cast"))
	for mmi: GeometryInstance3D in g.far_forest:
		mmi.visible = q != "verylow"
	if g.people:
		g.people.max_vis = int(VIS[q])
	small_textures(q == "verylow")
	Engine.max_fps = 60 if g.shot_path == "" else 0


## «Очень низкая»: картинки 4096² (палитры Synty, мрамор, статуи — по 64 МБ видеопамяти) у материалов заменяются
## копиями 2048² (16 МБ): на встроенной видеокарте память общая с системой. Другие уровни — снова оригиналы (с диска).
## Новые материалы (новый облик, новый житель) берут картинки через Gfx.tex — сразу маленькие
static func small_textures(on: bool) -> void:
	if on == _tex_small:
		return
	_tex_small = on
	var mats := []
	mats.append_array(Synty._mats.values())
	mats.append_array(Citizen._plain_mats.values())
	mats.append_array(Citizen._mats.values())
	var mb = Parts._special.get("#marble")
	if mb is PrimitiveMesh and (mb as PrimitiveMesh).material:
		mats.append((mb as PrimitiveMesh).material)
	for m in mats:
		if m is BaseMaterial3D:
			var bm := m as BaseMaterial3D
			bm.albedo_texture = _swap(bm.albedo_texture, on)
			bm.normal_texture = _swap(bm.normal_texture, on)
		elif m is ShaderMaterial:
			var t = (m as ShaderMaterial).get_shader_parameter("albedo_tex")
			if t is Texture2D:
				(m as ShaderMaterial).set_shader_parameter("albedo_tex", _swap(t, on))
	if not on:
		_small.clear()


## Картинка для нового материала (Synty.material, Citizen): на «Очень низкой» — копия 2048², без загрузки оригинала
static func tex(path: String) -> Texture2D:
	if path == "":
		return null
	if _tex_small and _small.has(path):
		return _small[path]
	var t: Texture2D = load(path)
	return _swap(t, true) if _tex_small else t


static func _swap(t: Texture2D, on: bool) -> Texture2D:
	if t == null:
		return t
	if on:
		if t is CompressedTexture2D and t.get_width() >= SMALL_FROM and t.resource_path != "":
			var key := t.resource_path
			if not _small.has(key):
				var img := t.get_image()
				if img == null or img.is_empty():
					return t
				if img.is_compressed():
					img.decompress()
				img.resize(t.get_width() / 2, t.get_height() / 2, Image.INTERPOLATE_BILINEAR)
				var it := ImageTexture.create_from_image(img)
				it.set_meta("orig", key)
				_small[key] = it
			return _small[key]
		return t
	if t.has_meta("orig"):
		return load(str(t.get_meta("orig")))
	return t


# ---------- в городе: проверка, сторож, счётчик ----------

func _ready() -> void:
	_vp = get_viewport().get_viewport_rid()
	process_priority = 100
	_fps_box = CanvasLayer.new()
	_fps_box.layer = 12
	add_child(_fps_box)
	_fps = Label.new()
	_fps.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps.offset_left = -130
	_fps.offset_right = -14
	_fps.offset_top = 76
	_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps.add_theme_font_size_override("font_size", 16)
	_fps.add_theme_color_override("font_color", Color("fff3dc"))
	_fps.add_theme_color_override("font_outline_color", Color("3a2412"))
	_fps.add_theme_constant_override("outline_size", 6)
	if game.hud and game.hud.font_bold:
		_fps.add_theme_font_override("font", game.hud.font_bold)
	_fps_box.add_child(_fps)
	refresh()
	if _check_due():
		_set_measure(true)
	if auto_on and game.mode in ["play", "new"] and game.shot_path == "" and not bool(game.settings.get("tip_igpu", false)) \
			and tier_for(adapter(), RenderingServer.get_video_adapter_type()) == "verylow":
		_pending.append(["Встроенная видеокарта", ("Игра идёт на встроенной видеокарте (%s) — ей тяжело. Если в ноутбуке есть вторая, мощная: " +
			"Параметры Windows → Система → Дисплей → Графика → CivCity → «Высокая производительность». И подключите зарядку — без неё " +
			"ноутбук сам замедляет видеокарту.") % adapter(), "", "tip_igpu"])


## Настройки поменялись: счётчик кадров
func refresh() -> void:
	_fps.visible = bool(game.settings.get("show_fps", false)) and game.shot_path == ""


func _set_measure(on: bool) -> void:
	if on != _measure:
		_measure = on
		RenderingServer.viewport_set_measure_render_time(_vp, on)


func _check_due() -> bool:
	var st: Dictionary = game.settings
	var qa := str(st.get("quality_auto", ""))
	return game.mode in ["play", "new"] and game.shot_path == "" and qa != "" and qa != "kept" and not bool(st.get("quality_checked", true)) \
		and not bool(st.get("quality_user", false))


## Сейчас обычная игра в городе (не меню, не ролик, не бой, окно не свёрнуто и в фокусе)
func _in_city() -> bool:
	if not game.ready_done or not (game.mode in ["play", "new"]) or game.shot_path != "":
		return false
	if game.rig == null or game.rig.cine or LegionBattle.current != null:
		return false
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED or game.minimized_test:
		return false
	return DisplayServer.window_is_focused() or OS.get_environment("CIVCITY_TESTWIN") == "hidden"   # окно проверки — за краем экрана


func _process(dt: float) -> void:
	if not game.ready_done:
		return
	var real := dt / maxf(0.0001, Engine.time_scale)
	if _fps.visible:
		_fps_t -= real
		if _fps_t <= 0.0:
			_fps_t = 0.5
			_fps.text = "%d FPS" % int(round(Engine.get_frames_per_second()))
	if _dbg and _dbg.visible:
		_dbg_text.text = report()
	_anims(real)
	var city := _in_city()
	if city:
		_alive_t += real
	if city and _check_due():
		_check_step(real)
	if city and auto_on and _alive_t > WATCH_START:
		_watch_step(real)
	if not _pending.is_empty() and _adv_free():
		var p: Array = _pending.pop_front()
		game.settings[p[3]] = true
		_write(game)
		game.hud.advisor(p[0], p[1], p[4] if p.size() > 4 else Callable())
		if p.size() > 4:
			game.hud.adv_skip.text = p[2]


func _adv_free() -> bool:
	var h = game.hud
	if h == null or h.advisor_panel == null or h.advisor_panel.visible or not h.visible:
		return false
	if game.tutorial and game.tutorial.active():
		return false
	return _in_city()


## Одна проверка в городе после выбора по видеокарте: медиана времени видеокарты за 4 с; больше 11 мс — на ступень ниже
func _check_step(dt: float) -> void:
	_set_measure(true)
	_check_n += 1
	if _check_n <= CHECK_SKIP:
		return
	var ms := RenderingServer.viewport_get_measured_render_time_gpu(_vp)
	if ms > 0.0:
		_check_ms.append(ms)
	_check_t += dt
	if _check_t < CHECK_SEC:
		return
	var st: Dictionary = game.settings
	var q: String = st.get("quality", "high")
	var med := 0.0
	if not _check_ms.is_empty():
		var s := _check_ms.duplicate()
		s.sort()
		med = s[s.size() / 2]
	if med > CHECK_MS and q != "verylow":
		q = lower(q)
		st["quality"] = q
		st["quality_auto"] = q
	st["quality_checked"] = true
	print("Графика: проверка в городе — видеокарта %.1f мс, уровень «%s»" % [med, NAMES[q]])
	_write(game)
	game._apply_quality()
	_set_measure(_dbg != null and _dbg.visible)
	if not bool(st.get("tip_q_auto", false)):
		_pending.push_front(["Графика под вашу видеокарту", ("Я выбрал графику «%s» — под вашу видеокарту (%s), чтобы город шёл плавно. " +
			"Поменять можно в любой момент: Меню → Настройки → Графика.") % [NAMES[q], adapter()], "", "tip_q_auto"])


## Сторож кадров: 20 с в городе в среднем меньше 40 кадров, а графика выше «Низкой» — один раз предложить «Низкую»
func _watch_step(dt: float) -> void:
	var st: Dictionary = game.settings
	if bool(st.get("tip_q_low", false)) or is_low(str(st.get("quality", "high"))) or _check_due():
		return
	_watch_t += dt
	_watch_n += 1
	if _watch_t < WATCH_SEC:
		return
	var avg := _watch_n / _watch_t
	_watch_t = 0.0
	_watch_n = 0
	if avg >= WATCH_FPS:
		return
	st["tip_q_low"] = true                 # предлагаем один раз (и в очереди — тоже один)
	_pending.append(["Видеокарте тяжело", ("Город идёт рывками — около %d кадров в секунду. Включить «Низкую» графику? Тени станут проще, " +
		"на улицах будет меньше прохожих, зато всё пойдёт плавнее. Вернуть можно в Настройках → Графика.") % int(avg), "Включить «Низкую»",
		"tip_q_low", func():
			game.settings["quality"] = "low"
			game.settings["quality_user"] = true
			_write(game)
			game._apply_quality()])


# ---------- движения жителей через кадр (Низкая — дальние, Очень низкая — все) ----------

func _anims(dt: float) -> void:
	var q: String = str(game.settings.get("quality", "high"))
	var on := is_low(q)
	if not on and _half == 0:
		return
	_half += 1
	var cam := get_viewport().get_camera_3d()
	var cp := cam.global_position if cam else Vector3.ZERO
	var list := []
	if game.people:
		for r in game.people.residents:
			if r["node"] != null:
				list.append(r["node"])
	if game.actors_root:
		for a in game.actors_root.get_children():
			if a is Citizen:
				list.append(a)
	var k := 0
	for c: Citizen in list:
		var ap := c.anim
		if ap == null:
			continue
		var half := on and (q == "verylow" or c.global_position.distance_squared_to(cp) > HALF_FAR * HALF_FAR)
		if half:
			if ap.callback_mode_process != AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL:
				ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
				ap.set_meta("half_dt", 0.0)
			var acc: float = float(ap.get_meta("half_dt", 0.0)) + dt
			if (k + _half) % 2 == 0:
				ap.advance(acc)
				acc = 0.0
			ap.set_meta("half_dt", acc)
		elif ap.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL:
			ap.advance(float(ap.get_meta("half_dt", 0.0)))
			ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
		k += 1
	if not on:
		_half = 0


# ---------- F3: подробно для проверяющих ----------

func _unhandled_key_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_F3:
		_toggle_dbg()
		get_viewport().set_input_as_handled()


func _toggle_dbg() -> void:
	if _dbg == null:
		_dbg = PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.07, 0.04, 0.82)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		_dbg.add_theme_stylebox_override("panel", sb)
		_dbg.position = Vector2(14, 220)
		var v := VBoxContainer.new()
		_dbg.add_child(v)
		_dbg_text = Label.new()
		_dbg_text.add_theme_font_size_override("font_size", 15)
		_dbg_text.add_theme_color_override("font_color", Color("fff3dc"))
		v.add_child(_dbg_text)
		var b := Button.new()
		b.text = "Копировать"
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): DisplayServer.clipboard_set(report()))
		v.add_child(b)
		_fps_box.add_child(_dbg)
		_dbg.visible = false
	_dbg.visible = not _dbg.visible
	_set_measure(_dbg.visible or _check_due())


## Что видно в F3 (и что копируется)
func report() -> String:
	var RS := RenderingServer
	var gpu := RS.viewport_get_measured_render_time_gpu(_vp)
	var cpu := RS.viewport_get_measured_render_time_cpu(_vp)
	var vis_d := RS.viewport_get_render_info(_vp, RS.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RS.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var sh_d := RS.viewport_get_render_info(_vp, RS.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RS.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var vis_p := RS.viewport_get_render_info(_vp, RS.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RS.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	var sh_p := RS.viewport_get_render_info(_vp, RS.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RS.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	var q := str(game.settings.get("quality", "high"))
	var lines := [
		"FPS %d · кадр %.1f мс" % [int(round(Engine.get_frames_per_second())), 1000.0 / maxf(1.0, Engine.get_frames_per_second())],
		"видеокарта %.2f мс · отрисовка на процессоре %.2f мс" % [gpu, cpu],
		"вызовов %d + тени %d · треугольников %.2fM + тени %.2fM" % [vis_d, sh_d, vis_p / 1.0e6, sh_p / 1.0e6],
		"видеопамять %d МБ (текстуры %d)" % [int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0), int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0)],
		"графика «%s»%s · окно %s · масштаб %.2f" % [NAMES.get(q, q), " (по видеокарте)" if str(game.settings.get("quality_auto", "")) == q else "", str(get_window().size), get_viewport().scaling_3d_scale],
		"%s · %s · Vulkan %s" % [adapter(), RS.get_video_adapter_vendor(), RS.get_video_adapter_api_version()],
		"жителей на улицах %d из %d · построек %d" % [game.people.visible_count if game.people else 0, game.people.residents.size() if game.people else 0, game.city.buildings.size() if game.city else 0],
		"версия %s" % ProjectSettings.get_setting("application/config/version", "?")]
	return "\n".join(lines)


# ---------- настройки: строка «Графика», FPS, видеокарта ----------

## В окне настроек (hud._settings_panel): четыре кнопки уровня, «Показывать FPS», название видеокарты
static func settings_block(h, v: VBoxContainer) -> void:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	r.add_child(h._icon("photo", 26, h.C_SOFT))
	r.add_child(h._label("Графика", 18, true))
	v.add_child(r)
	var q := HBoxContainer.new()
	q.add_theme_constant_override("separation", 6)
	q.alignment = BoxContainer.ALIGNMENT_CENTER
	for key: String in ["high", "medium", "low", "verylow"]:
		var b := Button.new()
		b.text = NAMES[key]
		b.name = "q_" + key
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(func():
			h.game.settings["quality"] = key
			h.game.settings["quality_user"] = true            # ручной выбор — больше ничего само не меняет
			h.game.save_settings()
			h._open_settings(true))
		q.add_child(b)
	v.add_child(q)
	var gpu: Label = h._wrap(h._label("Видеокарта: " + adapter(), 15, false, h.C_SOFT), 470)
	gpu.name = "gpu_name"
	v.add_child(gpu)
	var fps := CheckBox.new()
	fps.text = "Показывать FPS"
	fps.name = "show_fps"
	fps.add_theme_font_size_override("font_size", 18)
	fps.toggled.connect(func(x): h.game.settings["show_fps"] = x; h.game.save_settings())
	v.add_child(fps)


static func settings_refresh(h) -> void:
	for key: String in ["high", "medium", "low", "verylow"]:
		var b: Button = h.settings_panel.find_child("q_" + key, true, false)
		if b:
			b.add_theme_stylebox_override("normal", h._box_pill(12, 6, "g_btn_on" if h.game.settings["quality"] == key else "g_btn"))
	var fps := h.settings_panel.find_child("show_fps", true, false) as CheckBox
	if fps:
		fps.set_pressed_no_signal(bool(h.game.settings.get("show_fps", false)))
