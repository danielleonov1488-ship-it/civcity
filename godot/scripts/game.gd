class_name Game
extends Node3D
## CivCity: уютный римский город как Town to City, на моделях Synty POLYGON Ancient Empire.
## Мир: большая карта с мягкими холмами, прудами и лесами; на севере гора с тоннелем — оттуда приезжают
## повозки. Игрок рисует дороги кистью, ставит дома и лавки (постройка занимает землю своей настоящей формой
## и встаёт фасадом к дороге), жители живут своей жизнью.
## Запуск: без параметров — меню; -- --new | --play | --demo; снимок: --shot=путь.png --view=x,z,yaw,pitch,dist --hour=8

static var boot := {}                 # с чем перезапуститься: {"menu"|"play"|"new"|"demo": "1"}
const DAY_LEN := 360.0                # сутки — 6 минут при обычной скорости (час — 15 секунд)

var land: Land
var city: City
var parts: Parts
var people: People
var rig: CameraRig
var hud: Hud
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var chunk_nodes := {}
var land_mat: ShaderMaterial
var surf_img: Image
var surf_tex: ImageTexture
var visuals := {}                     # id постройки → {h, lights, smoke, actors}
var nature := {}                      # Vector2i(2-метровая клетка) → [{h, p}]
var plot_signs := {}
var night_lights: Array[OmniLight3D] = []
var actors_root: Node3D
var swimmers := []                    # утки и лебеди на прудах
var _actor_speed := 1.0

var mode := "play"                    # menu | play | new | demo
var can_save := true
var speed := 1.0
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
var range_ring: MeshInstance3D
var brush_ring: MeshInstance3D
var brush_box: MeshInstance3D
var brush_r := 1.0
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
var _rmb_down := Vector2.ZERO
var _mouse_pos := Vector2(-1, -1)

const SAVE_NAME := "city.json"


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if not boot.is_empty():
		args = boot.duplicate()
	boot = {}
	if not (args.has("menu") or args.has("play") or args.has("new") or args.has("demo")):
		args["menu"] = "1"
	if args.has("menu"):
		mode = "menu"
	elif args.has("demo"):
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
	await _step("Вода и тоннель", 0.15)
	_water()
	_horizon()
	_tunnel()
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
		city.place("center", Land.CENTER, PI / 2, 0, 0, true)
		if mode == "demo" or mode == "menu":
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
	hud = Hud.new()
	hud.game = self
	add_child(hud)
	city.event.connect(func(t, i): hud.notify(t, i))
	city.changed.connect(func(): hud.refresh())
	city.changed.connect(_sync_all_actors)
	_update_plot_signs()
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
	elif mode == "demo" and shot_path == "":
		hud.notify("Готовый город: стройте сколько угодно — он не сохраняется", "info")
	elif not loaded and shot_path == "":
		hud.advisor("Аве! Я Марк, твой советник.", "Из тоннеля в горе к почтовой станции приезжают повозки с переселенцами. Проложи дорогу кистью (слева внизу) и поставь вдоль неё дома — они сами встанут фасадом к дороге. Рядом поставь лавки: каждая кормит и радует дома в своей дальности.\n\nКамера: колёсико — масштаб, зажатое колёсико — вращать, правая кнопка — двигать (или WASD, Q/E).")


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
	loading = CanvasLayer.new()
	loading.layer = 50
	add_child(loading)
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists("res://assets/ui/loading.png"):
		bg.texture = load("res://assets/ui/loading.png")
	var fill := ColorRect.new()
	fill.color = Color("2b1d12")
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading.add_child(fill)
	loading.add_child(bg)
	var box := VBoxContainer.new()
	box.name = "box"
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.position = Vector2(-260, -130)
	box.custom_minimum_size = Vector2(520, 0)
	loading.add_child(box)
	var title := Label.new()
	title.text = "CivCity"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", load("res://assets/fonts/Philosopher-Bold.ttf"))
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Color("fff3dc"))
	title.add_theme_color_override("font_outline_color", Color("3a2412"))
	title.add_theme_constant_override("outline_size", 10)
	box.add_child(title)
	var l := Label.new()
	l.name = "label"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", load("res://assets/fonts/AlegreyaSans-Bold.ttf"))
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color("fff3dc"))
	l.add_theme_color_override("font_outline_color", Color("3a2412"))
	l.add_theme_constant_override("outline_size", 6)
	box.add_child(l)
	var bar := ProgressBar.new()
	bar.name = "bar"
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(520, 16)
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(0.15, 0.1, 0.06, 0.8)
	bgs.set_corner_radius_all(8)
	bgs.border_color = Color("e8c98f")
	bgs.set_border_width_all(2)
	var fgs := StyleBoxFlat.new()
	fgs.bg_color = Color("e2a843")
	fgs.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("background", bgs)
	bar.add_theme_stylebox_override("fill", fgs)
	box.add_child(bar)
	var tip := Label.new()
	tip.text = ["Совет: лавки обслуживают только ближайшие дома — ставьте разные лавки среди домов.",
		"Совет: правая кнопка мыши отменяет выбранный инструмент.",
		"Совет: украшения рядом с домом дают до +30% счастья.",
		"Совет: щёлкните по значку дома в карточке, чтобы сменить его цвет.",
		"Совет: довольный полный дом сам надстроит этаж, если этаж открыт исследованием."][randi() % 5]
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_override("font", load("res://assets/fonts/AlegreyaSans-Medium.ttf"))
	tip.add_theme_font_size_override("font_size", 17)
	tip.add_theme_color_override("font_color", Color("f1e2c6"))
	tip.add_theme_color_override("font_outline_color", Color("3a2412"))
	tip.add_theme_constant_override("outline_size", 5)
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
	if sun:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if q != "low" else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS


# ---------- небо, солнце, свет, цвет ----------

func _environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("5a93cf")
	sky_mat.sky_horizon_color = Color("f0d4a8")
	sky_mat.ground_horizon_color = Color("d8c3a0")
	sky_mat.ground_bottom_color = Color("6e6b56")
	sky_mat.sun_angle_max = 25.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.62
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 1.3
	env.ssao_intensity = 2.4
	env.ssao_power = 1.6
	env.ssil_enabled = true
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.9
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_bounce_feedback = 0.6
	env.sdfgi_min_cell_size = 0.25
	env.sdfgi_energy = 1.15
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color("e6e2d2")
	env.fog_density = 0.0011
	env.fog_aerial_perspective = 0.35
	env.fog_sky_affect = 0.55
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.12
	env.adjustment_brightness = 1.02
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 140.0
	sun.light_angular_distance = 1.4
	sun.shadow_blur = 1.2
	add_child(sun)
	_apply_quality()


## Тёплая виньетка по краям экрана, как в Town to City
func _grading() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 1
	add_child(cl)
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float strength = 0.42;
void fragment() {
	vec2 d = UV - 0.5;
	float v = smoothstep(0.28, 0.78, length(d * vec2(1.15, 1.0)));
	COLOR = vec4(0.28, 0.14, 0.05, v * strength);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	r.material = m
	cl.add_child(r)


func _set_hour(h: float) -> void:
	hour = fposmod(h, 24.0)
	var day_k := clampf((hour - 5.5) / 14.0, 0.0, 1.0)
	var ang := day_k * PI
	var to_sun := Vector3(cos(ang), sin(ang) * 0.9 + 0.05, 0.42).normalized()
	var night := hour < 5.6 or hour > 19.6
	var dusk := smoothstep(18.5, 20.5, hour) + (1.0 - smoothstep(4.5, 7.0, hour))
	if night:
		to_sun = Vector3(-0.3, 0.55, -0.5).normalized()
	var elev := clampf(to_sun.y, 0.0, 1.0)
	var c := Vector3(Land.START.x, 0, Land.START.y)
	sun.look_at_from_position(c + to_sun * 160.0, c, Vector3.UP)
	var warm := Color("ffa95e").lerp(Color("ffecd2"), smoothstep(0.15, 0.75, elev))
	sun.light_color = Color("9fb4ff") if night else warm
	sun.light_energy = 0.35 if night else 1.5 + 1.6 * smoothstep(0.05, 0.6, elev)
	sky_mat.sky_horizon_color = Color("2b3550") if night else Color("f6c48e").lerp(Color("eedbc0"), smoothstep(0.1, 0.6, elev))
	sky_mat.sky_top_color = Color("141c3a") if night else Color("5a93cf").lerp(Color("7c8fc4"), clampf(dusk, 0.0, 1.0) * 0.5)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color.darkened(0.1)
	env.ambient_light_energy = 0.28 if night else 0.62
	env.ambient_light_color = Color("6f7fb8") if night else Color.WHITE
	env.fog_light_color = Color("3c4672") if night else warm.lerp(Color("e3e6dc"), 0.75)
	(_puff_quad().material as StandardMaterial3D).albedo_color = Color(0.3, 0.33, 0.43) if night else Color(1, 1, 1).lerp(Color(1.0, 0.82, 0.66), clampf(dusk, 0.0, 1.0) * 0.6)
	var lit := night or hour < 6.6 or hour > 18.7
	var lm := (Parts._special_mesh("#lit") as PrimitiveMesh).material as StandardMaterial3D
	if lm:
		var k := smoothstep(18.3, 19.8, hour) + (1.0 - smoothstep(5.2, 6.8, hour))
		lm.emission_energy_multiplier = clampf(k, 0.0, 1.0) * (0.25 if hour > 22.5 or hour < 5.0 else 1.6)
	for l in night_lights:
		l.visible = lit
		l.light_energy = 2.4 if night else 1.1


# ---------- вода, тоннель, природа ----------

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
	# земля за краем карты — луг до горизонта (кольцо вокруг карты, под картой его нет)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("8fae4a")
	fm.roughness = 1.0
	var S := Land.SIZE
	var W := 700.0
	for r: Rect2 in [Rect2(-W, -W, S + 2 * W, W), Rect2(-W, S, S + 2 * W, W), Rect2(-W, 0, W, S), Rect2(S, 0, W, S)]:
		var far := MeshInstance3D.new()
		var fp := PlaneMesh.new()
		fp.size = r.size
		far.mesh = fp
		far.material_override = fm
		far.position = Vector3(r.position.x + r.size.x / 2.0, Land.BASE_Y + 3.0, r.position.y + r.size.y / 2.0)
		add_child(far)


## Тоннель в холме: каменный портал, тёмный проём, скалы по бокам и на холме над входом (не перед ним)
func _tunnel() -> void:
	var g := Land.TUNNEL
	var y := land.height_at(g.x, g.y + 1.5)
	var xf := Transform3D(Basis.IDENTITY, Vector3(g.x, y, g.y))
	var bp := Bp.new(3)
	# портал с распахнутыми створками — повозки выезжают из темноты тоннеля
	var portal := Synty.make("SM_Bld_Door_Monument_01")
	portal.transform = xf * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.9), Vector3(-2.5, 0, -0.3))
	add_child(portal)
	for mi: MeshInstance3D in portal.find_children("*Door_*", "MeshInstance3D", true, false):
		mi.rotate_y(deg_to_rad(-105.0) if String(mi.name).ends_with("_L") else deg_to_rad(105.0))
	bp.parts.append(["#dark", Transform3D(Basis.IDENTITY.scaled(Vector3(4.0, 5.4, 6.0)), Vector3(0, 2.7, -3.6)), {}])
	for x: float in [-3.9, 3.9]:
		bp.add("SM_Bld_Pillar_Large_02", Vector3(x, 0, 0.2), 0.0, 1.0)
		bp.add("SM_Env_Ivy_Pillar_Flowers_04", Vector3(x, 0, 0.2), randf() * TAU, 1.0)
		bp.brazier(Vector3(x * 1.3, 0, 1.4), true)
	bp.add("SM_Prop_Banner_03_A", Vector3(0, 6.9, 0.3), 0.0, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for side: float in [-1.0, 1.0]:
		for k in 3:
			var p := Vector3(side * rng.randf_range(6.8, 9.5), 0.0, -rng.randf_range(1.0, 4.0) - k * 1.5)
			p.y = land.height_at(g.x + p.x, g.y + p.z) - y - 0.6
			var sc := rng.randf_range(0.6, 0.84)
			bp.parts.append(["SM_Env_Rock_Cliff_Layers_02", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * 0.9, sc)), p), {"tint": Color(0.86, 0.8, 0.7)}])
		bp.add("SM_Env_Bush_Cluster_0%d" % (1 + rng.randi() % 5), Vector3(side * 6.2, 0, 1.6), rng.randf() * TAU, 0.8)
	# камни и деревья на верху холма
	for k in 7:
		var a := rng.randf() * TAU
		var r := rng.randf_range(3.0, 12.0)
		var q := Land.HILL + Vector2(cos(a), sin(a) * 0.8) * r
		if q.y > g.y - 4.0:
			continue
		var p := Vector3(q.x - g.x, land.height_at(q.x, q.y) - y - 0.2, q.y - g.y)
		if rng.randf() < 0.5:
			bp.add("SM_Env_Rock_Cliff_02", p, rng.randf() * TAU, rng.randf_range(0.5, 0.9))
		else:
			bp.add("SM_Env_Tree_0%d" % (1 + rng.randi() % 4), p, rng.randf() * TAU, rng.randf_range(0.45, 0.6))
	parts.place(bp, xf)
	for lp in bp.lights:
		_light(xf * lp)


## Пейзаж до горизонта: за краем карты — холмы, луга и леса (низкодетально, без теней)
func _horizon() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 32.0
	var R := 1600.0
	var n := int(R * 2.0 / step)
	var fn := FastNoiseLite.new()
	fn.seed = 3
	fn.frequency = 0.004
	fn.fractal_octaves = 3
	var fz := FastNoiseLite.new()
	fz.seed = 8
	fz.frequency = 0.012
	var S := Land.SIZE
	var hgt := func(x: float, z: float) -> float:
		if x > 0.5 and z > 0.5 and x < S - 0.5 and z < S - 0.5:
			return Land.WATER_Y - 6.0
		var dx := maxf(maxf(-x, x - S), 0.0)
		var dz := maxf(maxf(-z, z - S), 0.0)
		var d := sqrt(dx * dx + dz * dz)
		return Land.EDGE_Y + smoothstep(0.0, 260.0, d) * (6.0 + fn.get_noise_2d(x, z) * 26.0) + smoothstep(500.0, 1400.0, d) * 60.0
	var col := func(x: float, z: float, y: float) -> Color:
		var f := fz.get_noise_2d(x, z)
		var c := Color("7fa23e").lerp(Color("4e7a34"), clampf(f * 1.6 + 0.3, 0.0, 1.0))
		return c.lerp(Color("b9b38a"), smoothstep(40.0, 80.0, y))
	var x0 := S / 2.0 - R
	for j in n:
		for i in n:
			var xa := x0 + i * step
			var za := x0 + j * step
			var pts: Array[Vector3] = [Vector3(xa, 0, za), Vector3(xa + step, 0, za), Vector3(xa + step, 0, za + step), Vector3(xa, 0, za + step)]
			var all_in := true
			for k in 4:
				pts[k].y = hgt.call(pts[k].x, pts[k].z)
				if pts[k].y > Land.WATER_Y:
					all_in = false
			if all_in:
				continue
			for tri: Array in [[0, 2, 1], [0, 3, 2]]:
				var a: Vector3 = pts[tri[0]]
				var b: Vector3 = pts[tri[1]]
				var c: Vector3 = pts[tri[2]]
				var nrm := (c - a).cross(b - a).normalized()
				var cc: Color = col.call((a.x + b.x + c.x) / 3.0, (a.z + b.z + c.z) / 3.0, (a.y + b.y + c.y) / 3.0)
				for v: Vector3 in [a, b, c]:
					st.set_normal(nrm)
					st.set_color(cc)
					st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# дальние леса: деревья пятнами вокруг карты
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var trees := {}
	for k in 9000:
		var a := rng.randf() * TAU
		var d := rng.randf_range(8.0, 520.0)
		var p := Vector2(S / 2.0, S / 2.0) + Vector2(cos(a), sin(a)) * (S * 0.72 + d)
		if p.x > 0 and p.y > 0 and p.x < S and p.y < S:
			continue
		if fz.get_noise_2d(p.x, p.y) < 0.05 and rng.randf() < 0.85:
			continue
		var nm := ("SM_Env_Tree_0%d" % (1 + rng.randi() % 4)) if rng.randf() < 0.7 else ("SM_Env_Tree_Thin_0%d" % (1 + rng.randi() % 2))
		var y: float = hgt.call(p.x, p.y)
		if not trees.has(nm):
			trees[nm] = []
		trees[nm].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.45, 0.8)), Vector3(p.x, y - 0.3, p.y)))
	for nm in trees:
		var src := Synty.make(nm, {"tint": Synty.GREEN})
		for smi: MeshInstance3D in src.find_children("*", "MeshInstance3D", true, false):
			var mesh := smi.mesh.duplicate() as Mesh
			for si in mesh.get_surface_count():
				var sm := smi.get_surface_override_material(si)
				if sm:
					mesh.surface_set_material(si, sm)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			var list: Array = trees[nm]
			mm.instance_count = list.size()
			var local := Citizen._rel(smi, src)
			for k in list.size():
				mm.set_instance_transform(k, (list[k] as Transform3D) * local)
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mmi)
		src.free()


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
		if land.occ[k] != 0 or not land.is_rock(k) or Vector2(x, z).distance_to(Land.TUNNEL) < 10.0:
			continue
		var y := land.height_at(x, z)
		bp.add("SM_Env_Rock_Cliff_02", Vector3(x, y - 0.3, z), rng.randf() * TAU, rng.randf_range(0.3, 0.55))
	parts.place(bp, Transform3D.IDENTITY)


func _light(at: Vector3) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = at
	l.light_color = Color("ffb060")
	l.omni_range = 7.0
	l.light_energy = 2.0
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
	var t := Time.get_ticks_msec() / 1000.0
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

func _on_added(b: Dictionary) -> void:
	_show(b)
	var r := 14.0
	clear_nature(b["pos"], r, b["cells"])
	_update_plot_signs()


func _show(b: Dictionary) -> void:
	_hide(b)
	var bp := city.blueprint(b)
	var xf := city.xf(b)
	var lit := city.is_house(b) and int(b["pop"]) > 0
	var vis := {"h": parts.place(bp, xf, {"#dark": "#lit"} if lit else {}), "lights": [], "smoke": [], "actors": []}
	for lp in bp.lights:
		vis["lights"].append(_light(xf * lp))
	var lived: bool = not city.is_house(b) or int(b["pop"]) > 0
	if lived:
		for sp in bp.smoke.slice(0, 1):
			vis["smoke"].append(_smoke(xf * sp))
	visuals[b["id"]] = vis
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
	for a in vis.get("actors", []):
		(a as Node).queue_free()
	visuals.erase(b["id"])


func _on_removed(b: Dictionary) -> void:
	_hide(b)
	_puff(Vector3(b["pos"].x, b["y"], b["pos"].y))
	if selected.get("id", -1) == b["id"]:
		select_building({})
	_update_plot_signs()


func _on_house_changed(b: Dictionary, up: bool) -> void:
	_show(b)
	if up:
		_puff(Vector3(b["pos"].x, b["y"], b["pos"].y), Color("fff3c8"))
	if hud:
		hud.house_event(b, up)
	if selected.get("id", -1) == b["id"]:
		select_building(b)


## Люди при деле у постройки: появляются, когда она работает, и уходят, когда нет
func _sync_actors(b: Dictionary) -> void:
	var vis: Dictionary = visuals.get(b["id"], {})
	if vis.is_empty():
		return
	var d := city.def(b)
	# у мастерских и лавок работают настоящие жители (приходят из дома) — тут только станция и сады патрициев
	var on: bool = not d.has("jobs") and d["kind"] in ["center", "house"] and (int(b["pop"]) > 0 or d["kind"] == "center") and hour > 6.5 and hour < 20.5
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
		var c := Citizen.create(rng, who == "female" or (who == "any" and rng.randf() < 0.5), false, who == "rich", model)
		actors_root.add_child(c)
		c.transform = xf * Transform3D(Basis(Vector3.UP, float(a[1])), a[0])
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
	p.amount = 10
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.position = at
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.25, 1, 0.1)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.35
	pm.initial_velocity_max = 0.55
	pm.gravity = Vector3(0.12, 0.05, 0.04)
	pm.scale_min = 0.6
	pm.scale_max = 0.9
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.4))
	sc.add_point(Vector2(1, 2.4))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var grad := Gradient.new()
	grad.set_color(0, Color(0.95, 0.94, 0.92, 0.16))
	grad.set_color(1, Color(0.9, 0.9, 0.9, 0.0))
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

func _update_plot_signs() -> void:
	if hud == null:
		return
	for k in plot_signs:
		(plot_signs[k] as Node).queue_free()
	plot_signs.clear()
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
			var l := Label3D.new()
			l.text = "Купить · %s ден." % hud.fmt(city.plot_price())
			l.font = hud.font_bold
			l.font_size = 48
			l.outline_size = 14
			l.modulate = Color("fff6dc")
			l.outline_modulate = Color("6a4a2a")
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.pixel_size = 0.01
			l.position = Vector3(0, 4.6, 0)
			l.visibility_range_end = 120.0
			sign.add_child(l)
			add_child(sign)
			plot_signs[p] = sign


# ---------- кадр ----------

func _process(dt: float) -> void:
	if not ready_done:
		return
	frame += 1
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
			(a as Citizen).anim.speed_scale = speed
	_update_tool()
	autosave_t += dt
	if mode == "menu":
		rig._yaw_t += dt * 0.03
		if _autogo != "" and frame == 60:
			hud._menu_go(_autogo)
	if autosave_t > 90.0 and can_save and settings.get("autosave", true):
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


# ---------- точка земли под курсором ----------

func _input(e: InputEvent) -> void:
	if e is InputEventMouse:
		_mouse_pos = (e as InputEventMouse).position


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


# ---------- инструменты ----------

func set_tool(t: String) -> void:
	if t == "" and not moving.is_empty():
		_cancel_move()
	if t != "move_nature" and not moving_nature.is_empty():
		_add_nature(moving_nature["name"], moving_nature["xf"], moving_nature["p"])
		moving_nature = {}
	tool = t
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
	if hud:
		hud.on_tool(t)


func is_road_tool(t: String) -> bool:
	return t in ["road", "plaza", "path", "erase"]


func _make_markers() -> void:
	brush_ring = _ring(Color(1, 0.98, 0.9, 0.85))
	range_ring = _ring(Color(1.0, 0.92, 0.6, 0.7))
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


## Куда встанет постройка: у дороги — фасадом к ней, вплотную к соседям в ряд; иначе — как повернул игрок
func placement(type: String, p: Vector2, variant := -1, color := -1) -> Dictionary:
	var d: Dictionary = Defs.B[type]
	if variant < 0:
		variant = next_variant
	if color < 0:
		if not moving.is_empty():
			color = int(moving.get("color", 0))
		else:
			if place_color < 0 or place_color_pos.distance_to(p) > 5.0:
				place_color = city.pick_color(p)
				place_color_pos = p
			color = place_color
	var tier := 1 if d["kind"] == "house" else (city.level if type == "center" else 0)
	if not moving.is_empty():
		tier = int(moving["tier"])
	var bp := Catalog.make(type, tier, variant, color)
	var bb := _bounds(bp)
	var yaw := tool_yaw
	var pos := p
	if snap and d["kind"] != "decor" and d["kind"] != "farm":
		var e := _nearest_road(p, maxf(6.0, (float(bb[3]) - float(bb[2])) * 0.5 + 3.0))
		if not e.is_empty():
			var nrm: Vector2 = e["n"]
			# не дёргаться: если прежнее направление почти так же близко к дороге — оставить его
			if last_snap_n != Vector2.ZERO and nrm.angle_to(last_snap_n) != 0.0:
				var dd := 0.0
				while dd <= 8.0 and not land.is_road(p + last_snap_n * dd):
					dd += 0.2
				if dd <= p.distance_to(e["p"]) + 0.8:
					nrm = last_snap_n
					e["p"] = p + nrm * dd
			last_snap_n = nrm
			yaw = snappedf(atan2(nrm.x, nrm.y), deg_to_rad(5.0))
			var f := City.facing(yaw)
			pos = (e["p"] as Vector2) - f * (float(bb[3]) + 0.05)
			pos = _snap_row(pos, yaw, bb, int(moving.get("id", -1)))
	var chk := city.check_place(type, pos, yaw, variant, color, -3 if not moving.is_empty() else -1)
	return {"pos": pos, "yaw": yaw, "err": chk["err"], "cells": chk["cells"], "y": chk["y"], "variant": variant, "color": color, "tier": tier}


## Ближайший край дороги: точка и направление к ней
func _nearest_road(p: Vector2, maxd: float) -> Dictionary:
	var best := {}
	var hits := []
	for k in 48:
		var a := TAU * k / 48.0
		var dir := Vector2(sin(a), cos(a))
		var dd := 0.0
		var hit := -1.0
		while dd <= maxd:
			if land.is_road(p + dir * dd):
				hit = dd
				break
			dd += 0.2
		hits.append(hit)
		if hit >= 0.0 and (best.is_empty() or hit < float(best["d"])):
			best = {"d": hit, "k": k}
	if best.is_empty():
		return {}
	var sum := Vector2.ZERO
	var k0: int = best["k"]
	for o in range(-2, 3):
		var k := posmod(k0 + o, 48)
		var hit: float = hits[k]
		if hit >= 0.0 and hit <= float(best["d"]) * 1.12 + 0.3:
			var a := TAU * k / 48.0
			sum += Vector2(sin(a), cos(a)) / (hit + 0.3)
	var n := sum.normalized() if sum.length() > 0.001 else Vector2(sin(TAU * k0 / 48.0), cos(TAU * k0 / 48.0))
	var dd2 := 0.0
	while dd2 <= maxd + 1.0 and not land.is_road(p + n * dd2):
		dd2 += 0.1
	return {"p": p + n * dd2, "n": n}


## Ряд: если рядом постройка с тем же поворотом — придвинуться к ней боком и выровнять фасад
func _snap_row(pos: Vector2, yaw: float, bb: Array, ignore := -1) -> Vector2:
	var ax := City.axis(yaw)
	var f := City.facing(yaw)
	for id in city.buildings:
		if id == ignore:
			continue
		var o: Dictionary = city.buildings[id]
		var od: Dictionary = city.def(o)
		if od["kind"] == "decor" or od.get("fixed", false) or od["kind"] == "farm":
			continue
		if absf(angle_difference(float(o["yaw"]), yaw)) > deg_to_rad(12):
			continue
		var ob := _bounds(city.blueprint(o))
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
		if gap_r > -0.3 and gap_r < 1.6:
			return pos - ax * gap_r + f * shift
		if gap_l > -0.3 and gap_l < 1.6:
			return pos + ax * gap_l + f * shift
	return pos


func _update_tool() -> void:
	hover = ground_at_mouse()
	brush_ring.visible = false
	brush_box.visible = false
	range_ring.visible = selected.has("id") and Defs.range_m(city.def(selected)) > 0.0 if not selected.is_empty() else false
	var over_ui := hud and hud.mouse_over_ui()
	if tool == "" or hover == Vector2.INF or over_ui:
		if ghost:
			ghost.visible = false
		if tool in ["bulldoze", "copy", "move"] or tool == "":
			if not over_ui and hover != Vector2.INF and tool != "":
				_hover_any(hover)
			elif tool != "":
				_clear_highlight()
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
		return
	if tool in ["bulldoze", "copy", "move"]:
		_hover_any(hover)
		return
	if tool == "move_nature":
		_move_nature_ghost()
		return
	if not Defs.B.has(tool):
		return
	var pl := placement(tool, hover)
	place_info = pl
	var d: Dictionary = Defs.B[tool]
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
	var rr := Defs.range_m(d)
	if rr > 0.0:
		if d.get("sub", "") == "food" and city.research.has("reach1"):
			rr *= 1.33
		range_ring.visible = true
		range_ring.position = Vector3(pl["pos"].x, y + 0.12, pl["pos"].y)
		range_ring.scale = Vector3(rr, 1.0, rr)
	if hud:
		hud.tool_status(pl["err"])


## Подсветка постройки под курсором: снос — красная, копировать и перенести — золотая
func _hover_any(p: Vector2) -> void:
	var b := city.building_at(p)
	if b.is_empty() and tool in ["bulldoze", "move"]:
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


## Выбрать постройку: обводка по силуэту и карточка
func select_building(b: Dictionary) -> void:
	if select_outline:
		select_outline.queue_free()
		select_outline = null
	selected = b
	if b.is_empty():
		range_ring.visible = false
		return
	select_outline = Parts.ghost(city.blueprint(b), "outline", Color(1.0, 0.96, 0.82))
	select_outline.transform = city.xf(b)
	add_child(select_outline)
	var rr := Defs.range_m(city.def(b))
	if rr > 0.0:
		range_ring.position = Vector3(b["pos"].x, float(b["y"]) + 0.12, b["pos"].y)
		range_ring.scale = Vector3(rr, 1.0, rr)


func _unhandled_input(e: InputEvent) -> void:
	if not ready_done or mode == "menu":
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_rmb_down = mb.position
			elif mb.position.distance_to(_rmb_down) < 6.0:
				# правая кнопка без движения — отменить инструмент (как в Town to City)
				if tool != "":
					set_tool("")
				else:
					hud.close_panels()
					select_building({})
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_click()
			else:
				_release()
	elif e is InputEventKey and e.pressed and not e.echo:
		var k := e as InputEventKey
		match k.keycode:
			KEY_ESCAPE:
				if tool != "":
					set_tool("")
				elif hud.close_panels() == false:
					select_building({})
			KEY_Z:
				if k.ctrl_pressed:
					_undo()
				else:
					tool_yaw -= deg_to_rad(15)
			KEY_Y:
				if k.ctrl_pressed:
					_redo()
			KEY_X:
				tool_yaw += deg_to_rad(15)
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
	if hover == Vector2.INF:
		return
	if is_road_tool(tool):
		painting = true
		stroke = []
		stroke_cost = 0.0
		last_paint = Vector2.INF
		if brush_line:
			line_from = hover
		else:
			_paint_to(hover)
		return
	match tool:
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
			var b := city.building_at(hover)
			if b.is_empty() and not hover_nature.is_empty():
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
					city.remove(b)
					_clear_highlight()
					sound.ui("demolish")
			return
		"copy":
			var b := city.building_at(hover)
			if not b.is_empty() and not city.def(b).get("fixed", false):
				tool_variant = -1
				set_tool(b["type"])
				next_variant = int(b["variant"])
			return
		"move":
			var b := city.building_at(hover)
			if b.is_empty() and not hover_nature.is_empty():
				moving_nature = hover_nature.duplicate()
				remove_nature(hover_nature)
				hover_nature = {}
				_clear_highlight()
				tool_yaw = 0.0
				tool = ""
				set_tool("move_nature")
				return
			if not b.is_empty() and not city.def(b).get("fixed", false):
				moving = {"id": b["id"], "type": b["type"], "tier": b["tier"], "variant": b["variant"], "color": b["color"], "pop": b["pop"],
					"families": b["families"], "pos": b["pos"], "yaw": b["yaw"]}
				city.remove(b, false)
				city.money += 0.0
				var t: String = b["type"]
				tool = ""
				set_tool(t)
				next_variant = int(moving["variant"])
				tool_yaw = float(moving["yaw"])
				hud.notify("Перенос: поставьте постройку на новое место (правая кнопка — вернуть обратно)", "move")
			return
	if Defs.B.has(tool):
		var pl := placement(tool, hover)
		if pl["err"] != "":
			hud.tool_status(pl["err"])
			sound.ui("error")
			return
		var b: Dictionary
		if not moving.is_empty():
			b = city.place(tool, pl["pos"], pl["yaw"], int(pl["variant"]), int(moving["color"]), true)
			b["tier"] = int(moving["tier"])
			b["pop"] = int(moving["pop"])
			b["families"] = moving["families"]
			moving = {}
			_show(b)
			city.compute()
			set_tool("")
		else:
			b = city.place(tool, pl["pos"], pl["yaw"], int(pl["variant"]), int(pl["color"]))
			if tool_variant < 0:
				next_variant = randi() % int(Defs.B[tool].get("variants", 1))
		_puff(Vector3(pl["pos"].x, float(pl["y"]), pl["pos"].y))
		sound.ui("place")
		return
	# без инструмента: участок на продажу или карточка постройки
	var plot := land.plot_of(hover)
	if city.can_buy(plot) and plot_signs.has(plot) and not land.is_owned(hover):
		hud.ask_buy(plot)
		return
	var b := city.building_at(hover)
	if not b.is_empty():
		select_building(b)
		hud.open_info(b)
	else:
		select_building({})
		hud.close_panels()


func _cancel_move() -> void:
	var m := moving
	moving = {}
	var b := city.place(m["type"], m["pos"], m["yaw"], int(m["variant"]), int(m["color"]), true)
	b["tier"] = int(m["tier"])
	b["pop"] = int(m["pop"])
	b["families"] = m["families"]
	_show(b)
	city.compute()


func _release() -> void:
	if not painting:
		return
	if brush_line and line_from != Vector2.INF and hover != Vector2.INF:
		var a := line_from
		var n := int(a.distance_to(hover) / (Land.CELL * 2.0)) + 1
		last_paint = Vector2.INF
		for s in n + 1:
			_paint_at(a.lerp(hover, float(s) / n))
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
	if last_paint != Vector2.INF and p.distance_to(last_paint) < brush_r * 0.3:
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
		cost = ch.size() * float(Defs.ROAD_COST[tool])
	if cost > city.money:
		land.undo(ch)
		hud.tool_status("Не хватает денариев")
		painting = false
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
	land.undo(u["ch"])
	redo_stack.append({"ch": now, "cost": u["cost"]})
	city.money += float(u["cost"])
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
	land.undo(r["ch"])
	undo_stack.append({"ch": back, "cost": r["cost"]})
	city.money -= float(r["cost"])
	city.compute()
	hud.refresh()


# ---------- сохранение ----------

func save_path() -> String:
	var dir := ""
	if OS.has_feature("editor"):
		dir = ProjectSettings.globalize_path("res://").path_join("../saves")
	else:
		dir = OS.get_executable_path().get_base_dir().path_join("saves")
	DirAccess.make_dir_recursive_absolute(dir)
	return dir.path_join(SAVE_NAME)


func save() -> void:
	if not can_save:
		return
	var data := city.save_data()
	data["land"] = land.save_changes()
	data["hour"] = hour
	data["version"] = 2
	var f := FileAccess.open(save_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


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
	city.money = 90000
	city.rp = 0
	city.level = 6
	for r in Defs.RESEARCH:
		city.research[r["id"]] = true
	for g in City.GOALS:
		city.goals_done.append(g["id"])
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
	for t: Array in [["statue", Vector2(186, 194)], ["statue", Vector2(198, 194)], ["lion", Vector2(183, 198)], ["lion", Vector2(201, 198)]]:
		place.call(t[0], t[1], 1.5)
	for k in 90:
		var p := Vector2(randf_range(158, 230), randf_range(124, 198))
		var t: String = ["flowers", "bush", "planter", "tree", "flowers", "palm", "goods", "well"][k % 8]
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
