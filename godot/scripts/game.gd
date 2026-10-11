class_name Game
extends Node3D
## CivCity: уютный римский город в духе Town to City на моделях Synty POLYGON Ancient Empire.
## Мир: земля уступами, море, холмы, скала с воротами (оттуда приезжают переселенцы), центр города у ворот.
## Игрок кладёт дороги кистью, ставит здания (дом сам встаёт фасадом к дороге и в ряд к соседям),
## дома растут от того, что есть рядом, жители живут своей жизнью.
## Запуск для снимков: -- --shot=путь.png --view=x,z,yaw,pitch,dist --hour=8 --demo (готовый городок)

var land: Land
var base_land: Land                  # исходная карта — для сохранения только изменений
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
var surf_img: Image                  # маска покрытий (мостовая, площадь, тропа) для плавных краёв
var surf_tex: ImageTexture
var visuals := {}                    # id постройки → {handles, lights: [], smoke: []}
var nature := {}                     # Vector2i(2-метровая клетка) → [{handles, p}]
var plot_signs := {}
var night_lights: Array[OmniLight3D] = []
var actors_root: Node3D               # люди при деле у построек
var _actor_speed := 1.0

var speed := 1.0
var day_t := 0.0
var hour := 8.0
var clock_hours := true              # время суток идёт само
var shot_path := ""
var shot_frame := 200
var frame := 0
var autosave_t := 0.0

# инструменты
var tool := ""                       # "" | тип постройки | "road" | "plaza" | "path" | "erase" | "bulldoze"
var tool_yaw := 0.0
var ghost: Node3D
var ghost_key := ""
var ghost_plate: MeshInstance3D
var brush_ring: MeshInstance3D
var radius_ring: MeshInstance3D
var brush_r := 1.0
var stroke := []                     # изменения земли текущего мазка (для отмены)
var stroke_cost := 0.0
var undo_stack := []
var painting := false
var last_paint := Vector2.INF
var hover := Vector2.INF
var place_info := {}                 # {pos, yaw, err}
var _rmb_down := Vector2.ZERO
var _lmb_down := false

const SAVE_NAME := "city.json"

static var boot := {}                  # с чем перезапуститься: {"menu"|"play"|"new"|"demo": "1"}
var mode := "play"                     # menu — меню на фоне готового города; play — свой город; new — новый; demo — готовый город
var can_save := true
var _autogo := ""                      # проверка меню: через пару секунд перейти в режим (для снимков)


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if not boot.is_empty():
		args = boot.duplicate()           # перезапуск из меню — только новый режим, без старых параметров запуска
	boot = {}
	if args.is_empty():
		args["menu"] = "1"
	if args.has("menu"):
		mode = "menu"
		args["demo"] = "1"
	elif args.has("demo"):
		mode = "demo"
	elif args.has("new"):
		mode = "new"
	shot_path = args.get("shot", "")
	_autogo = args.get("autogo", "")
	can_save = shot_path == "" and (mode == "play" or mode == "new")
	shot_frame = int(args.get("frames", "200"))
	hour = float(args.get("hour", "8.0"))
	if args.has("hour"):
		clock_hours = false
	_environment()
	base_land = Land.new()
	land = Land.new()
	city = City.new(land)
	parts = Parts.new()
	add_child(parts)
	actors_root = Node3D.new()
	add_child(actors_root)
	land_mat = ShaderMaterial.new()
	land_mat.shader = load("res://shaders/land.gdshader")
	var tex := func(n: String) -> Texture2D: return load(Synty._tex_path(n))
	Synty._index()
	land_mat.set_shader_parameter("tile_road", tex.call("Floor_Tiles_04"))
	land_mat.set_shader_parameter("tile_plaza_a", tex.call("Floor_Tiles_03"))
	land_mat.set_shader_parameter("tile_plaza_b", tex.call("Floor_Tiles_05"))
	land_mat.set_shader_parameter("tile_plaza_c", tex.call("Floor_Tiles_01"))
	land_mat.set_shader_parameter("tile_plaza_d", tex.call("Floor_Tiles_02"))
	_water()
	_gate()
	_cliff_rocks()
	var birds := Birds.new()
	birds.center = Vector3(Land.CENTER.x, 0, Land.CENTER.y + 10)
	add_child(birds)
	city.building_added.connect(_on_added)
	city.building_removed.connect(_on_removed)
	city.house_changed.connect(_on_house_changed)
	people = People.new()
	add_child(people)
	var loaded := false
	if mode == "play":
		loaded = _load()
	if not loaded:
		city.place("center", Land.CENTER, 0.0, true, 1)
		if args.has("demo"):
			_demo_town()
	_nature()
	surf_img = land.make_surface()
	surf_img.generate_mipmaps()
	surf_tex = ImageTexture.create_from_image(surf_img)
	land_mat.set_shader_parameter("surf", surf_tex)
	for j in Land.CHN:
		for i in Land.CHN:
			land.dirty[Vector2i(i, j)] = true
	_rebuild_land(999)
	people.setup(land, city)
	if int(city.stats["pop"]) > 0:
		people.prespawn(mini(40, int(city.stats["pop"]) / 6))
	rig = CameraRig.new()
	rig.terrain = null
	add_child(rig)
	rig.land = land
	var v := str(args.get("view", "64,40,180,42,46")).split(",")
	rig.set_view(Vector3(float(v[0]), Land.BASE_Y, float(v[1])), float(v[2]), float(v[3]), float(v[4]))
	_make_markers()
	hud = Hud.new()
	hud.game = self
	add_child(hud)
	city.message.connect(func(t, k): hud.toast(t, k))
	city.changed.connect(func(): hud.refresh())
	city.changed.connect(_sync_all_actors)
	_update_plot_signs()
	_set_hour(hour)
	hud.refresh()
	if mode == "menu":
		hud.show_menu(FileAccess.file_exists(save_path()))
		rig.set_view(Vector3(66, Land.BASE_Y, 70), 205, 30, 62)
	elif mode == "demo" and shot_path == "":
		hud.toast("Готовый город: стройте и смотрите сколько угодно — он не сохраняется", "")
	elif not loaded and shot_path == "":
		hud.advisor("Аве! Я Марк, твой советник.", "Через ворота в скале к центру города приезжают переселенцы. Проложи от центра дорогу кистью (слева внизу) и поставь вдоль неё дома — они сами повернутся к дороге. Камера: колёсико — масштаб, зажатое колёсико — вращать, правая кнопка — двигать, WASD и Q/E.")


# ---------- небо, солнце, свет ----------

func _environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("4f8ccf")
	sky_mat.sky_horizon_color = Color("e7d3b4")
	sky_mat.ground_horizon_color = Color("d8c3a0")
	sky_mat.ground_bottom_color = Color("6e6b56")
	sky_mat.sun_angle_max = 25.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.08
	env.ssao_enabled = true
	env.ssao_radius = 1.3
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.ssil_enabled = true
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.8
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_bounce_feedback = 0.6
	env.sdfgi_min_cell_size = 0.2
	env.sdfgi_energy = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color("dcc9ac")
	env.fog_density = 0.0025
	env.fog_aerial_perspective = 0.5
	env.fog_sky_affect = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.14
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 120.0
	sun.light_angular_distance = 1.2
	sun.shadow_blur = 1.1
	add_child(sun)


func _set_hour(h: float) -> void:
	hour = fposmod(h, 24.0)
	var day_k := clampf((hour - 5.5) / 14.0, 0.0, 1.0)
	var ang := day_k * PI
	var to_sun := Vector3(cos(ang), sin(ang) * 0.95 + 0.04, 0.38).normalized()
	var night := hour < 5.6 or hour > 19.6
	var dusk := smoothstep(19.0, 20.5, hour) + (1.0 - smoothstep(4.5, 6.0, hour))
	if night:
		to_sun = Vector3(-0.3, 0.55, -0.5).normalized()
	var elev := clampf(to_sun.y, 0.0, 1.0)
	var c := Vector3(64, 0, 64)
	sun.look_at_from_position(c + to_sun * 140.0, c, Vector3.UP)
	var warm := Color("ffb26e").lerp(Color("fff1dc"), smoothstep(0.15, 0.7, elev))
	sun.light_color = Color("9fb4ff") if night else warm
	sun.light_energy = 0.35 if night else 1.4 + 1.6 * smoothstep(0.05, 0.6, elev)
	sky_mat.sky_horizon_color = Color("2b3550") if night else Color("f0c99a").lerp(Color("e3d8c4"), smoothstep(0.1, 0.6, elev))
	sky_mat.sky_top_color = Color("101833") if night else Color("4f8ccf")
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color.darkened(0.1)
	env.ambient_light_energy = 0.25 if night else 0.6
	env.fog_light_color = Color("39436a") if night else warm.lerp(Color("dcc9ac"), 0.6)
	var lit := night or hour < 6.4 or hour > 18.9
	for l in night_lights:
		l.visible = lit
		l.light_energy = 2.2 if night else 1.0


# ---------- вода, ворота, природа ----------

func _water() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(520, 520)
	pm.subdivide_width = 140
	pm.subdivide_depth = 140
	mi.mesh = pm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/water.gdshader")
	mi.material_override = sm
	mi.position = Vector3(64, Land.SEA_Y, 64)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Ворота в скале: монументальный проём, тёмный тоннель, колонны, жаровни и знамёна
func _gate() -> void:
	var g := Land.GATE
	var y := Land.BASE_Y
	var xf := Transform3D(Basis.IDENTITY, Vector3(g.x, y, g.y))
	var bp := Bp.new(3)
	bp.add("SM_Bld_Door_Monument_01", Vector3(-2.5, 0, -0.2), 0.0, 0.85)
	bp.parts.append(["#dark", Transform3D(Basis.IDENTITY.scaled(Vector3(3.6, 7.0, 6.0)), Vector3(0, 3.5, -3.4)), {}])
	for x: float in [-3.6, 3.6]:
		bp.add("SM_Bld_Pillar_Large_02", Vector3(x, 0, 0.3), 0.0, 1.0)
		bp.add("SM_Env_Ivy_Pillar_Flowers_04", Vector3(x, 0, 0.3), randf() * TAU, 1.0)
		bp.brazier(Vector3(x * 1.35, 0, 1.6), true)
		bp.add("SM_Prop_Banner_03_A", Vector3(x * 0.8, 6.6, 0.25), 0.0, 1.0)
	bp.add("SM_Prop_Statue_Lion_01", Vector3(-6.2, 0, 1.0), 0.0, 0.75)
	bp.add("SM_Prop_Statue_Lion_01", Vector3(6.2, 0, 1.0), 0.0, 0.75)
	parts.place(bp, xf)
	for lp in bp.lights:
		_light(xf * lp)


## Скалы Synty вдоль обрыва с воротами: вместо ровной стенки уступов — слоистый песчаник
func _cliff_rocks() -> void:
	var bp := Bp.new(17)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var x := 1.0
	while x < 127.0:
		var step := rng.randf_range(4.5, 7.0)
		if absf(x - Land.GATE.x) < 4.8:
			x += step
			continue
		var top := land.height_at(x, 6.0)
		var zf := -1.0
		for k in 120:
			var z := 8.0 + k * 0.2
			if land.height_at(x, z) < top - 2.5:
				zf = z
				break
		if zf > 0.0:
			var low := land.height_at(x, zf + 1.5)
			if rng.randf() < 0.6:
				var sc := rng.randf_range(0.42, 0.58)
				bp.add_xf("SM_Env_Rock_Cliff_Layers_01", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.75, 0.95), sc)), Vector3(x, low - 0.6, zf - 3.2)))
			else:
				var sc := rng.randf_range(0.8, 1.1)
				bp.add_xf("SM_Env_Rock_Cliff_Layers_02", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * 1.1, sc)), Vector3(x, low - 0.4, zf - 2.2)))
			if rng.randf() < 0.45:
				bp.add("SM_Env_Rock_Cliff_02", Vector3(x + rng.randf_range(-2, 2), low - 0.2, zf + rng.randf_range(0.2, 1.2)), rng.randf() * TAU, rng.randf_range(0.4, 0.7))
			if rng.randf() < 0.5:
				bp.add("SM_Env_Bush_Cluster_0%d" % (1 + rng.randi() % 5), Vector3(x + rng.randf_range(-2, 2), low, zf + rng.randf_range(0.6, 1.6)), rng.randf() * TAU, rng.randf_range(0.6, 0.9))
		x += step
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


func _nature() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for n in 9000:
		var x := rng.randf_range(1.0, 127.0)
		var z := rng.randf_range(1.0, 127.0)
		var c := land.cell(Vector2(x, z))
		var k := land.idx(c.x, c.y)
		if land.kind[k] != Land.Kind.GRASS:
			continue
		var p := Vector2(x, z)
		if p.distance_to(Land.CENTER) < 12.0 or absf(x - Land.GATE.x) < 4.5 and z < 30.0:
			continue
		if not city.building_at(p).is_empty():
			continue
		var y := land.h[k]
		var hill := clampf((y - Land.BASE_Y) / 6.0, 0.0, 1.0)
		var near_town := p.distance_to(Land.VALLEY) < 34.0 or p.distance_to(Land.CENTER) < 22.0
		var r := rng.randf()
		var name := ""
		var s := 1.0
		if r < 0.035 + hill * 0.05:
			name = "SM_Env_Tree_0%d" % (1 + rng.randi() % 4)
			s = rng.randf_range(0.45, 0.7)
		elif r < 0.08 + hill * 0.07:
			name = "SM_Env_Tree_Thin_0%d" % (1 + rng.randi() % 2)
			s = rng.randf_range(0.6, 0.9)
		elif r < 0.1 and x > 96.0:
			name = "SM_Env_Tree_Palm_0%d" % (1 + rng.randi() % 3)
			s = rng.randf_range(0.4, 0.6)
		elif r < 0.17:
			name = "SM_Env_Tree_Bush_0%d" % (1 + rng.randi() % 3)
			s = rng.randf_range(0.5, 0.8)
		elif r < 0.25:
			name = "SM_Env_Garden_Plants_0%d" % (3 + rng.randi() % 5)
			s = rng.randf_range(0.5, 0.8)
		elif r < 0.4:
			name = "SM_Env_Flowers_0%d" % (1 + rng.randi() % 5)
			s = rng.randf_range(1.0, 1.8)
		elif r < 0.55:
			name = "SM_Env_Grass_0%d" % (1 + rng.randi() % 3)
			s = rng.randf_range(0.7, 1.2)
		elif r < 0.6 and hill > 0.15:
			name = "SM_Env_Rock_Cliff_02"
			s = rng.randf_range(0.18, 0.4)
		else:
			continue
		# в долине — луг: деревья редкие, больше цветов и травы
		if near_town and r < 0.17 and rng.randf() < 0.85:
			continue
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, y - (0.15 if name.contains("Rock") else 0.0), z))
		var key := Vector2i(int(x / 2.0), int(z / 2.0))
		if not nature.has(key):
			nature[key] = []
		nature[key].append({"h": parts.place_one(name, xf, {"tint": Synty.GREEN} if name.begins_with("SM_Env_Tree") or name.begins_with("SM_Env_Garden") else {}), "p": p})


## Убрать природу в прямоугольнике постройки или под кистью
func clear_nature(c: Vector2, r: float, f := {}) -> void:
	for kz in range(int((c.y - r) / 2.0) - 1, int((c.y + r) / 2.0) + 2):
		for kx in range(int((c.x - r) / 2.0) - 1, int((c.x + r) / 2.0) + 2):
			var key := Vector2i(kx, kz)
			if not nature.has(key):
				continue
			var keep := []
			for it in nature[key]:
				var p: Vector2 = it["p"]
				var inside := City.obb_has(f, p) if not f.is_empty() else p.distance_to(c) <= r
				if inside:
					parts.remove(it["h"])
				else:
					keep.append(it)
			nature[key] = keep


# ---------- земля ----------

func _rebuild_land(limit := 6) -> void:
	var done := []
	for ch in land.dirty.keys():
		if done.size() >= limit:
			break
		done.append(ch)
	for ch in done:
		land.dirty.erase(ch)
		var mi: MeshInstance3D = chunk_nodes.get(ch)
		if mi == null:
			mi = MeshInstance3D.new()
			mi.material_override = land_mat
			add_child(mi)
			chunk_nodes[ch] = mi
		mi.mesh = land.chunk_mesh(ch.x, ch.y)
		if surf_img:
			land.update_surface(surf_img, ch)
	if surf_tex and not done.is_empty():
		surf_img.generate_mipmaps()
		surf_tex.update(surf_img)
	if people and people.land and not done.is_empty():
		people.refresh(done)


# ---------- постройки: картинка ----------

func _bxf(b: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, b["yaw"]), Vector3(b["pos"].x, b["y"], b["pos"].y))


func _on_added(b: Dictionary) -> void:
	_show(b)
	var d: Dictionary = Defs.B[b["type"]]
	clear_nature(b["pos"], float(d["w"]) + float(d["d"]), city.obb(b, 0.4))
	_update_plot_signs()


func _show(b: Dictionary) -> void:
	_hide(b)
	var bp := Catalog.make(b["type"], b["tier"], b["seed"])
	var xf := _bxf(b)
	var vis := {"h": parts.place(bp, xf), "lights": [], "smoke": []}
	for lp in bp.lights:
		vis["lights"].append(_light(xf * lp))
	var lived: bool = Defs.B[b["type"]]["kind"] != "house" or int(b["pop"]) > 0
	if lived:
		for sp in bp.smoke.slice(0, 1):
			vis["smoke"].append(_smoke(xf * sp))
	visuals[b["id"]] = vis
	_sync_actors(b)
	_set_hour(hour)


## Люди при деле у постройки: появляются, когда она работает (есть работники и дорога), и уходят, когда нет
func _sync_actors(b: Dictionary) -> void:
	var vis: Dictionary = visuals.get(b["id"], {})
	if vis.is_empty():
		return
	var d: Dictionary = Defs.B[b["type"]]
	var on: bool = (int(b["pop"]) > 0) if d["kind"] == "house" else bool(b.get("active", true)) and bool(b.get("road", true))
	if bool(vis.get("act_on", false)) == on and vis.has("actors"):
		return
	for a in vis.get("actors", []):
		(a as Node).queue_free()
	vis["actors"] = []
	vis["act_on"] = on
	if not on:
		return
	var bp := Catalog.make(b["type"], b["tier"], b["seed"])
	var xf := _bxf(b)
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


func _on_house_changed(b: Dictionary, up: bool) -> void:
	_show(b)
	if up:
		_puff(Vector3(b["pos"].x, b["y"], b["pos"].y), Color("fff3c8"))
	if hud:
		hud.house_event(b, up)


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
	grad.set_color(0, Color(0.95, 0.94, 0.92, 0.3))
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
		_quad.size = Vector2(0.7, 0.7)
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
	for k in plot_signs:
		(plot_signs[k] as Node).queue_free()
	plot_signs.clear()
	for j in Land.PLOTS:
		for i in Land.PLOTS:
			var p := Vector2i(i, j)
			if not city.can_buy(p):
				continue
			var c := Vector2((i + 0.5) * Land.PLOT, (j + 0.5) * Land.PLOT)
			if land.is_water(c) and land.is_water(c + Vector2(4, 4)) and land.is_water(c - Vector2(4, 4)):
				continue
			# межевой столб со знаменем и ценой — участок продаётся
			var y := maxf(land.height_at(c.x, c.y), 0.3)
			var sign := Node3D.new()
			sign.position = Vector3(c.x, y, c.y)
			sign.add_child(Synty.make("SM_Prop_Pole_02"))
			var ban := Synty.make("SM_Prop_Banner_02_%s" % ["A", "C", "E", "G"][(i + j) % 4])
			ban.position = Vector3(0, 3.2, 0)
			ban.rotation.y = 0.6
			sign.add_child(ban)
			var l := Label3D.new()
			l.text = "Купить · %d ден." % city.plot_price()
			if hud:
				l.font = hud.font_bold
			l.font_size = 44
			l.outline_size = 12
			l.modulate = Color("fff6dc")
			l.outline_modulate = Color("6a4a2a")
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.pixel_size = 0.009
			l.position = Vector3(0, 4.4, 0)
			l.visibility_range_end = 90.0
			sign.add_child(l)
			add_child(sign)
			plot_signs[p] = sign


# ---------- кадр ----------

func _process(dt: float) -> void:
	frame += 1
	_rebuild_land()
	var sdt := dt * speed
	if speed > 0.0:
		day_t += sdt
		if day_t >= Defs.DAY_SECONDS:
			day_t -= Defs.DAY_SECONDS
			city.sim_day()
		if clock_hours:
			_set_hour(hour + sdt * 24.0 / 480.0)       # сутки — 8 минут
	people.set_meta("speed", speed)
	if speed != _actor_speed:
		_actor_speed = speed
		for a in actors_root.get_children():
			(a as Citizen).anim.speed_scale = speed
	_update_tool()
	autosave_t += dt
	if mode == "menu":
		rig._yaw_t += dt * 0.035
		if _autogo != "" and frame == 90:
			hud._menu_go(_autogo)
	if autosave_t > 60.0 and can_save:
		autosave_t = 0.0
		save()
	if shot_path != "" and frame == shot_frame:
		var img := get_viewport().get_texture().get_image()
		img.save_png(shot_path)
		print("SHOT ", shot_path, " fps=", Engine.get_frames_per_second(), " parts=", parts.count())
		get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and can_save:
		save()


# ---------- точка земли под курсором ----------

var _mouse_pos := Vector2(-1, -1)


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
	var top := 14.0
	var t0 := maxf(0.0, (o.y - top) / -d.y)
	var t1 := (o.y + 3.0) / -d.y
	var n := clampi(int((t1 - t0) * Vector2(d.x, d.z).length() / 0.1), 1, 2000)
	var prev := t0
	for i in range(1, n + 1):
		var t := t0 + (t1 - t0) * i / n
		var p := o + d * t
		if p.x < 0 or p.z < 0 or p.x > Land.SIZE or p.z > Land.SIZE:
			if p.y < -1.0:
				return Vector2.INF
			prev = t
			continue
		if p.y <= land.height_at(p.x, p.z):
			var lo := prev
			var hi := t
			for k in 8:
				var m := (lo + hi) * 0.5
				var q := o + d * m
				if q.y <= land.height_at(q.x, q.z):
					hi = m
				else:
					lo = m
			var r := o + d * hi
			return Vector2(r.x, r.z)
		prev = t
	return Vector2.INF


# ---------- инструменты ----------

func set_tool(t: String) -> void:
	tool = t
	painting = false
	if ghost:
		ghost.queue_free()
		ghost = null
		ghost_key = ""
	if hud:
		hud.on_tool(t)


func _make_markers() -> void:
	ghost_plate = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE
	ghost_plate.mesh = pm
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.45, 0.85, 0.4, 0.35)
	m.no_depth_test = true
	ghost_plate.material_override = m
	ghost_plate.visible = false
	add_child(ghost_plate)
	brush_ring = _ring(Color(1, 0.98, 0.9, 0.85))
	radius_ring = _ring(Color(1.0, 0.92, 0.6, 0.6))


func _ring(col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.96
	tm.outer_radius = 1.0
	tm.rings = 64
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


## Куда встанет постройка: у дороги — фасадом к ней, впритык к соседям в ряд; вдали — как повернул игрок
func placement(type: String, p: Vector2) -> Dictionary:
	var d: Dictionary = Defs.B[type]
	var hd := float(d["d"]) / 2.0
	var hw := float(d["w"]) / 2.0
	var yaw := tool_yaw
	var pos := p
	var err := ""
	if d["kind"] != "decor":
		var e := _nearest_road(p, maxf(5.5, hd + 2.5))
		if not e.is_empty():
			var nrm: Vector2 = e["n"]
			yaw = snappedf(atan2(nrm.x, nrm.y), deg_to_rad(5.0))
			var f := City.facing(yaw)
			pos = (e["p"] as Vector2) - f * (hd + 0.05)
			pos = _snap_row(type, pos, yaw)
		elif not d.get("noroad", false):
			err = "Поставьте у дороги — к ней встанет фасад"
	if err == "":
		err = city.check_place(type, pos, yaw)
	return {"pos": pos, "yaw": yaw, "err": err}


func _is_road(p: Vector2) -> bool:
	var k := land.kind_at(p.x, p.y)
	return k == Land.Kind.ROAD or k == Land.Kind.PLAZA or k == Land.Kind.DIRT


## Ближайший край дороги: точка и направление к ней
func _nearest_road(p: Vector2, maxd: float) -> Dictionary:
	var best := {}
	var hits := []
	for k in 36:
		var a := TAU * k / 36.0
		var dir := Vector2(sin(a), cos(a))
		var dd := 0.0
		var hit := -1.0
		while dd <= maxd:
			if _is_road(p + dir * dd):
				hit = dd
				break
			dd += 0.2
		hits.append(hit)
		if hit >= 0.0 and (best.is_empty() or hit < float(best["d"])):
			best = {"d": hit, "k": k}
	if best.is_empty():
		return {}
	# направление — среднее по соседним лучам, чтобы дом вставал ровно вдоль края, а не под углом к клетке
	var sum := Vector2.ZERO
	var k0: int = best["k"]
	for o in range(-4, 5):
		var k := posmod(k0 + o, 36)
		var hit: float = hits[k]
		if hit >= 0.0 and hit <= float(best["d"]) + 1.5:
			var a := TAU * k / 36.0
			sum += Vector2(sin(a), cos(a)) / (hit + 0.3)
	var n := sum.normalized() if sum.length() > 0.001 else Vector2(sin(TAU * k0 / 36.0), cos(TAU * k0 / 36.0))
	var dd2 := 0.0
	while dd2 <= maxd + 1.0 and not _is_road(p + n * dd2):
		dd2 += 0.1
	return {"p": p + n * dd2, "n": n}


## Ряд домов: если рядом дом с тем же поворотом — придвинуться к нему боком и выровнять фасад
func _snap_row(type: String, pos: Vector2, yaw: float) -> Vector2:
	var d: Dictionary = Defs.B[type]
	var hw := float(d["w"]) / 2.0
	var hd := float(d["d"]) / 2.0
	var ax := City.axis(yaw)
	var f := City.facing(yaw)
	for id in city.buildings:
		var o: Dictionary = city.buildings[id]
		var od: Dictionary = Defs.B[o["type"]]
		if od["kind"] == "decor" or od.get("fixed", false):
			continue
		if absf(angle_difference(float(o["yaw"]), yaw)) > deg_to_rad(12):
			continue
		var rel: Vector2 = pos - (o["pos"] as Vector2)
		var along := rel.dot(ax)
		var across := rel.dot(f)
		var ohw := float(od["w"]) / 2.0
		var ohd := float(od["d"]) / 2.0
		if absf(across - (ohd - hd)) > 1.4:
			continue
		var gap := absf(along) - (hw + ohw)
		if gap < 1.6 and gap > -hw:
			var s := signf(along) if along != 0.0 else 1.0
			return (o["pos"] as Vector2) + ax * s * (hw + ohw + 0.02) + f * (ohd - hd)
	return pos


func _update_tool() -> void:
	hover = ground_at_mouse()
	ghost_plate.visible = false
	brush_ring.visible = false
	radius_ring.visible = false
	if tool == "" or hover == Vector2.INF or (hud and hud.mouse_over_ui()):
		if ghost:
			ghost.visible = false
		return
	if tool in ["road", "plaza", "path", "erase"]:
		var y := land.height_at(hover.x, hover.y)
		brush_ring.visible = true
		brush_ring.position = Vector3(hover.x, y + 0.08, hover.y)
		brush_ring.scale = Vector3(brush_r, 1.0, brush_r)
		if painting:
			_paint_to(hover)
		return
	if tool == "bulldoze":
		var b := city.building_at(hover)
		if not b.is_empty():
			var d: Dictionary = Defs.B[b["type"]]
			_show_plate(b["pos"], b["yaw"], float(d["w"]), float(d["d"]), float(b["y"]), Color(0.95, 0.35, 0.25, 0.4))
		return
	if not Defs.B.has(tool):
		return
	var pl := placement(tool, hover)
	place_info = pl
	var d: Dictionary = Defs.B[tool]
	var key := tool + ":" + str(int(pl["yaw"] * 1000))
	if ghost == null or ghost_key != tool:
		if ghost:
			ghost.queue_free()
		var tier := 1 if tool == "house" else (0 if d["kind"] == "house" else 0)
		ghost = Parts.ghost(Catalog.make(tool, tier, 0))
		add_child(ghost)
		ghost_key = tool
	ghost.visible = true
	var y := land.height_at(pl["pos"].x, pl["pos"].y)
	ghost.transform = Transform3D(Basis(Vector3.UP, pl["yaw"]), Vector3(pl["pos"].x, y + 0.02, pl["pos"].y))
	var ok: bool = pl["err"] == ""
	_show_plate(pl["pos"], pl["yaw"], float(d["w"]), float(d["d"]), y, Color(0.45, 0.85, 0.4, 0.35) if ok else Color(0.95, 0.35, 0.25, 0.45))
	if d.has("radius"):
		radius_ring.visible = true
		radius_ring.position = Vector3(pl["pos"].x, y + 0.1, pl["pos"].y)
		radius_ring.scale = Vector3(float(d["radius"]), 1.0, float(d["radius"]))
	if hud:
		hud.tool_status(pl["err"])


func _show_plate(c: Vector2, yaw: float, w: float, dd: float, y: float, col: Color) -> void:
	ghost_plate.visible = true
	ghost_plate.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(w, 1, dd)), Vector3(c.x, y + 0.06, c.y))
	(ghost_plate.material_override as StandardMaterial3D).albedo_color = col


func _unhandled_input(e: InputEvent) -> void:
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
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_click()
			else:
				_end_stroke()
	elif e is InputEventKey and e.pressed and not e.echo:
		var k := e as InputEventKey
		match k.keycode:
			KEY_ESCAPE:
				if tool != "":
					set_tool("")
				else:
					hud.close_panels()
			KEY_Z:
				if k.ctrl_pressed:
					_undo()
				else:
					tool_yaw -= deg_to_rad(15)
			KEY_X:
				tool_yaw += deg_to_rad(15)
			KEY_R:
				set_tool("road")
			KEY_B:
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
			KEY_BRACKETRIGHT:
				brush_r = minf(3.0, brush_r + 0.25)
			KEY_F5:
				save()
				hud.toast("Город сохранён", "ok")


func _click() -> void:
	if hover == Vector2.INF:
		return
	if tool in ["road", "plaza", "path", "erase"]:
		painting = true
		stroke = []
		stroke_cost = 0.0
		last_paint = Vector2.INF
		_paint_to(hover)
		return
	if tool == "bulldoze":
		var b := city.building_at(hover)
		if not b.is_empty():
			if Defs.B[b["type"]].get("fixed", false):
				hud.toast("Центр города не сносится — он растёт вместе с городом", "warn")
			else:
				city.remove(b)
		return
	if Defs.B.has(tool):
		var pl := placement(tool, hover)
		if pl["err"] != "":
			hud.toast(pl["err"], "warn")
			return
		city.place(tool, pl["pos"], pl["yaw"])
		_puff(Vector3(pl["pos"].x, land.height_at(pl["pos"].x, pl["pos"].y), pl["pos"].y))
		if Defs.B[tool]["kind"] == "house" and tool != "domus":
			pass
		return
	# без инструмента: участок на продажу или карточка постройки
	var plot := land.plot_of(hover)
	if city.can_buy(plot) and plot_signs.has(plot):
		hud.ask_buy(plot)
		return
	var b := city.building_at(hover)
	if not b.is_empty():
		hud.open_info(b)
	else:
		hud.close_panels()


func _paint_to(p: Vector2) -> void:
	if last_paint != Vector2.INF and p.distance_to(last_paint) < brush_r * 0.3:
		return
	var kinds := {"road": Land.Kind.ROAD, "plaza": Land.Kind.PLAZA, "path": Land.Kind.DIRT, "erase": Land.Kind.GRASS}
	var kd: int = kinds[tool]
	var a := last_paint if last_paint != Vector2.INF else p
	var ch := []
	var n := int(a.distance_to(p) / (Land.CELL * 2.0)) + 1
	for s in n + 1:
		var q := a.lerp(p, float(s) / n)
		ch.append_array(land.paint_circle(q, brush_r, kd, kd != Land.Kind.GRASS))
	last_paint = p
	if ch.is_empty():
		return
	var cost := 0.0
	if tool != "erase":
		cost = ch.size() * float(Defs.ROAD_COST[tool])
	if cost > city.money:
		land.undo(ch)
		hud.toast("Не хватает денариев", "warn")
		painting = false
		return
	city.money -= cost
	stroke_cost += cost
	stroke.append_array(ch)
	clear_nature(p, brush_r + 0.3)


func _end_stroke() -> void:
	if not painting:
		return
	painting = false
	if not stroke.is_empty():
		undo_stack.append({"ch": stroke, "cost": stroke_cost})
		if undo_stack.size() > 30:
			undo_stack.pop_front()
		city.compute()
		hud.refresh()
	stroke = []


func _undo() -> void:
	if undo_stack.is_empty():
		return
	var u: Dictionary = undo_stack.pop_back()
	land.undo(u["ch"])
	city.money += float(u["cost"])
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


## Перезапуск сцены в другом режиме (меню, свой город, новый, готовый)
func restart(m: String) -> void:
	if can_save:
		save()
	boot = {m: "1"}
	if _autogo != "" and shot_path != "":
		boot["shot"] = shot_path
		boot["frames"] = str(shot_frame)
	get_tree().reload_current_scene()


func save() -> void:
	if not can_save:
		return
	var data := city.save_data()
	data["land"] = land.save_changes(base_land)
	data["hour"] = hour
	data["version"] = 1
	var f := FileAccess.open(save_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func _load() -> bool:
	if not FileAccess.file_exists(save_path()):
		return false
	var txt := FileAccess.get_file_as_string(save_path())
	var data = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		return false
	land.load_changes(data.get("land", {}))
	city.money = float(data.get("money", Defs.START_MONEY))
	city.day = int(data.get("day", 0))
	city.max_rank = int(data.get("max_rank", 0))
	city.goals_done = data.get("goals", [])
	city.plots_bought = int(data.get("plots_bought", 0))
	city.tips_seen = data.get("tips", [])
	var g: Dictionary = data.get("goods", {})
	for k in g:
		city.goods[k] = float(g[k])
	hour = float(data.get("hour", 8.0))
	for bd in data.get("buildings", []):
		var b := {"id": city.next_id, "type": bd["type"], "tier": int(bd["tier"]), "pos": Vector2(float(bd["x"]), float(bd["z"])), "yaw": float(bd["yaw"]),
			"seed": int(bd["seed"]), "pop": int(bd["pop"]), "y": float(bd.get("y", Land.BASE_Y)), "up": 0, "down": 0, "needs": {}, "happy": 50, "beauty": 0.0, "road": true, "staff": 1.0, "active": true}
		city.next_id += 1
		city.buildings[b["id"]] = b
	city.compute()
	for id in city.buildings:
		_show(city.buildings[id])
	return true


# ---------- готовый городок (для снимков и первого знакомства) ----------

func _demo_town() -> void:
	city.money = 90000
	for g in Defs.GOALS:
		city.goals_done.append(g["id"])
	city.max_rank = Defs.RANKS.size() - 1
	for j in range(1, 7):
		for i in range(1, 7):
			land.owned[Vector2i(i, j)] = true
	var R := Land.Kind.ROAD
	var road := func(a: Vector2, b: Vector2, w: float, kd: int) -> void:
		land.paint_line(a, b, w, kd, true)
	# улицы: главная от центра к храму через площадь, поперечные, переулки-тропы
	road.call(Vector2(64, 36), Vector2(64, 99), 1.7, R)
	road.call(Vector2(38, 50), Vector2(92, 50), 1.35, R)
	road.call(Vector2(36, 86), Vector2(94, 86), 1.35, R)
	road.call(Vector2(47, 50), Vector2(47, 86), 1.2, R)
	road.call(Vector2(81, 50), Vector2(81, 86), 1.2, R)
	road.call(Vector2(47, 68), Vector2(55, 68), 1.2, R)
	road.call(Vector2(73, 68), Vector2(81, 68), 1.2, R)
	road.call(Vector2(36, 50), Vector2(30, 62), 1.0, Land.Kind.DIRT)
	road.call(Vector2(30, 62), Vector2(30, 92), 1.0, Land.Kind.DIRT)
	road.call(Vector2(94, 86), Vector2(98, 96), 1.0, Land.Kind.DIRT)
	for k in 30:
		land.paint_circle(Vector2(64, 68), 8.5, Land.Kind.PLAZA, true, false)
	var put := func(type: String, near: Vector2, r: float, tier := -1) -> Dictionary:
		for k in range(0, int(r * 2) + 1):
			var rr := k * 0.5
			var n := maxi(1, int(rr * 6))
			for q in n:
				var p := near + Vector2(cos(TAU * q / n), sin(TAU * q / n)) * rr
				var pl: Dictionary = placement(type, p)
				if pl["err"] == "":
					var b := city.place(type, pl["pos"], pl["yaw"], true)
					if tier >= 0:
						b["tier"] = tier
						var T: Dictionary = Defs.tiers(type)[tier] if not Defs.tiers(type).is_empty() else {}
						b["pop"] = int(T.get("cap", 0))
					return b
		return {}
	# главное: храм в конце улицы, рынок и термы у площади, театр, форум
	put.call("temple", Vector2(64, 106), 4)
	put.call("fountain", Vector2(64, 68), 1)
	put.call("market", Vector2(51.5, 62), 4)
	put.call("baths", Vector2(76, 61), 4)
	put.call("forum", Vector2(72, 95), 5)
	put.call("theatre", Vector2(42, 96), 6)
	for x: float in [40.0, 52.0]:
		put.call("domus", Vector2(x, 80), 4, 3 + int(x > 45.0))
	put.call("domus", Vector2(87, 80), 4, 4)
	put.call("domus", Vector2(87, 56), 4, 2)
	# окраины: поля, роща, виноградник, мастерские
	put.call("farm", Vector2(24, 66), 6)
	put.call("farm", Vector2(24, 78), 6)
	put.call("grove", Vector2(24, 90), 6)
	put.call("vineyard", Vector2(36, 59), 4)
	put.call("bakery", Vector2(34, 72), 4)
	put.call("oilpress", Vector2(34, 80), 4)
	put.call("winery", Vector2(97, 90), 5)
	put.call("warehouse", Vector2(56, 44), 4)
	put.call("smithy", Vector2(73, 44), 4)
	put.call("well", Vector2(52, 54), 3)
	put.call("well", Vector2(76, 76), 3)
	put.call("well", Vector2(58, 90), 3)
	# дома рядами вдоль всех улиц; чем ближе к площади — тем выше
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for z in range(34, 104):
		for x in range(30, 100):
			var p := Vector2(x, z)
			if not _is_road(p + Vector2(2.6, 0)) and not _is_road(p - Vector2(2.6, 0)) and not _is_road(p + Vector2(0, 2.6)) and not _is_road(p - Vector2(0, 2.6)):
				continue
			var pl: Dictionary = placement("house", p)
			if pl["err"] != "":
				continue
			var hb := city.place("house", pl["pos"], pl["yaw"], true)
			var d := (pl["pos"] as Vector2).distance_to(Vector2(64, 68))
			var tier := 1
			if d < 16.0:
				tier = [3, 4, 4, 3][rng.randi() % 4]
			elif d < 28.0:
				tier = [2, 3, 3, 4][rng.randi() % 4]
			elif d < 40.0:
				tier = [1, 2, 2, 3][rng.randi() % 4]
			else:
				tier = [1, 1, 2][rng.randi() % 3]
			hb["tier"] = tier
			hb["pop"] = Defs.PLEB_TIERS[tier]["cap"]
	# красота: кипарисы вдоль главной улицы, скамьи и жаровни у фонтана, статуи у храма, цветы
	var deco := func(type: String, p: Vector2, yaw: float) -> void:
		if city.check_place(type, p, yaw) == "":
			city.place(type, p, yaw, true)
	for k in 8:
		var a := TAU * k / 8.0 + 0.2
		deco.call("bench", Vector2(64, 68) + Vector2(cos(a), sin(a)) * 5.2, -a - PI / 2)
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4
		deco.call("bigbrazier", Vector2(64, 68) + Vector2(cos(a), sin(a)) * 7.4, 0.0)
	for z in range(38, 98, 4):
		for sx: float in [-1.0, 1.0]:
			if absf(z - 68) > 10:
				deco.call("cypress", Vector2(64 + sx * 2.4, z), 0.0)
	for p: Vector2 in [Vector2(58, 99), Vector2(70, 99)]:
		deco.call("statue", p, PI)
	for p: Vector2 in [Vector2(55.5, 99), Vector2(72.5, 99)]:
		deco.call("lion", p, PI)
	for k in 60:
		var p := Vector2(rng.randf_range(32, 98), rng.randf_range(36, 104))
		deco.call(["flowers", "bush", "planter", "tree", "flowers", "palm"][k % 6], p, rng.randf() * TAU)
	city.compute()
	for id in city.buildings:
		_show(city.buildings[id])
