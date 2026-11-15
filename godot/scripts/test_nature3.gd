extends Node
## Природа, 15.11 (трава реже, «Природа» в украшениях, кисть травы, поле пшеницы, мельница, мост, птицы, лодка):
##   bash .work/py/gpu_run.sh res://test_nature3.tscn -- mode=check              — проверки без картинок («NATURE3 DONE fails=0»)
##   … -- mode=shots out=ПАПКА [hour=13] [q=high]                                 — снимки: инструменты «Природы», цвета цветов,
##       кисть травы, поле, мельница, мост, лодка (новая игра, всё открыто)

var game
var A := {}
var fails := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		A[kv[0]] = kv[1] if kv.size() > 1 else "1"
	Game.boot = {"new": "1", "hour": str(A.get("hour", "13"))}
	if str(A.get("mode", "check")) == "birds":
		var city := str(A.get("city", "D:/CivCity/.work/owner_save/city.json"))
		DirAccess.copy_absolute(city, GamePaths.save_dir().path_join("city.json"))
		Game.boot = {"play": "1", "hour": str(A.get("hour", "10"))}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func ok(name: String, cond: bool, info := "") -> void:
	if not cond:
		fails += 1
	print("NATURE3 ", "PASS " if cond else "FAIL ", name, (" " + info) if info != "" else "")


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	game.can_save = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if game.seasons:
		game.seasons.force_m = 6.0
	if game.weather:
		game.weather.force = 0.0
		game.weather.left_h = 0.0
	game.city.money = 900000
	for r in Defs.RESEARCH:
		game.city.research[r["id"]] = true
	for t in Defs.B:
		var u: String = Defs.B[t].get("unlock", "")
		if u != "":
			game.city.research[u] = true
	await frames(10)
	match str(A.get("mode", "check")):
		"check": await _check()
		"shots": await _shots()
		"ui": await _ui()
		"birds": await _birds()
	print("NATURE3 DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func put(type: String, p: Vector2, variant := -1, color := -1, yaw := 0.0) -> Dictionary:
	game.tool = type
	var pl: Dictionary = game.placement(type, p, variant, color)
	game.tool = ""
	if pl["err"] != "":
		print("NATURE3 ERR ", type, " ", p, " ", pl["err"])
		return {}
	var b: Dictionary = game.city.place(type, pl["pos"], yaw, pl["variant"], pl["color"])
	return b


func _hide_ui() -> void:
	game.hud.visible = false
	game.rig.cine = true
	game.people.visible = false
	for n in game.find_children("*", "Decal", true, false):
		(n as Decal).visible = false


func _snap(path: String, wait := 90) -> void:
	await frames(3)
	if game.grass != null:
		game.grass.fill_now()
	await frames(wait)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	print("NATURE3 shot ", path)


func _view(x: float, z: float, yaw: float, pitch: float, dist: float) -> void:
	game.rig.set_view(Vector3(x, game.land.height_at(x, z), z), yaw, pitch, dist)


func _quality(q: String) -> void:
	game.settings["quality"] = q
	game._apply_quality()
	Gfx.swap_all()


## Проверки без картинок
func _check() -> void:
	# 1. все облики «Природы» строятся
	var total := 0
	for t in Defs.B:
		var d: Dictionary = Defs.B[t]
		if not d.has("nat"):
			continue
		var n := int(d["variants"])
		ok("%s: число обликов совпадает со списком" % t, n == CatNature.count_of(String(d["nat"])), "%d / %d" % [n, CatNature.count_of(String(d["nat"]))])
		for v in n:
			var bp := Catalog.make(t, 0, v, 6)
			total += 1
			if bp.parts.is_empty():
				ok("%s #%d строится" % [t, v], false)
		ok("%s есть во вкладке «Природа»" % t, Defs.decor_sub(t) == "nature")
	ok("облики «Природы» построены", total > 60, str(total))
	# модели из разных наборов: Meadow и Ancient Empire
	var meadow := 0
	var ancient := 0
	for v in 17:
		var bp2 := Catalog.make("nat_tree", 0, v, 0)
		for e: Array in bp2.parts:
			if String(e[0]).begins_with("M:"):
				meadow += 1
				break
			elif String(e[0]).begins_with("SM_Env_Tree"):
				ancient += 1
				break
	ok("деревья — из обоих наборов", meadow >= 5 and ancient >= 5, "Meadow %d, Ancient %d" % [meadow, ancient])
	# 2. случайная модель на каждую постановку и цвет цветов; сохраняются variant и color
	var seen := {}
	for i in 12:
		game.next_variant = randi() % 17
		var b := put("nat_tree", Vector2(205 + i * 3.0, 175), game.next_variant)
		if not b.is_empty():
			seen[int(b["variant"])] = true
	ok("деревья разных моделей", seen.size() >= 4, str(seen.keys()))
	var fb := put("nat_flowers", Vector2(210, 182), 2, 1)
	ok("цветы ставятся с цветом", not fb.is_empty() and int(fb["color"]) == 1 and int(fb["variant"]) == 2, str(fb.get("color")))
	var sd: Dictionary = game.city.save_data()
	var found := false
	for e in sd["buildings"]:
		if e["type"] == "nat_flowers" and int(e["color"]) == 1 and int(e["variant"]) == 2:
			found = true
	ok("в сохранении цвет и модель цветов", found)
	# снос — как у любого украшения
	var cnt0: int = game.city.buildings.size()
	game.city.remove(fb)
	ok("украшение сносится", game.city.buildings.size() == cnt0 - 1)
	# 3. мельница: ставится, крылья крутятся (материал вращения), сохраняется
	var mb := put("windmill", Vector2(225, 190))
	ok("мельница ставится", not mb.is_empty())
	var bpm := Catalog.make("windmill")
	var spin := 0
	var nd := Parts.ghost(bpm, "place")
	for mi: MeshInstance3D in nd.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if m is ShaderMaterial and (m as ShaderMaterial).shader.resource_path.ends_with("meadow_spin.gdshader"):
				spin += 1
	nd.free()
	ok("у мельницы крутятся крылья", spin >= 1, str(spin))
	ok("мельница и в «Хозяйстве», и в «Природе»", game.hud._types_in("farming").has("windmill") and game.hud._types_in("decor", "nature").has("windmill"))
	# 4. кисть травы: маска, сохранение, старые сохранения без маски
	var land: Land = game.land
	var rc := land.gm_paint(Vector2(200, 200), 3.0, 2)
	ok("кисть убрать траву красит маску", not rc.is_empty() and land.gm_at(200, 200) == 2 and land.gm_count > 20, str(land.gm_count))
	land.gm_paint(Vector2(220, 200), 2.0, 1)
	ok("кисть трава красит маску", land.gm_at(220, 200) == 1)
	var sv: Dictionary = land.save_changes()
	ok("маска в сохранении сжата", sv.has("gmask") and String(sv["gmask"]).length() < 4000, str(String(sv.get("gmask", "")).length()))
	var l2 := Land.new()
	l2.load_changes(sv)
	ok("маска возвращается из сохранения", l2.gm_at(200, 200) == 2 and l2.gm_at(220, 200) == 1 and l2.gm_at(100, 100) == 0 and l2.gm_count == land.gm_count)
	var old := sv.duplicate()
	old.erase("gmask")
	old.erase("gmask_n")
	var l3 := Land.new()
	l3.load_changes(old)
	ok("старое сохранение без маски грузится", l3.gm_count == 0 and l3.gm_at(200, 200) == 0)
	# 5. «Трава и цветы»: настройки
	game.settings["grass_range"] = "all"
	game.apply_grass_range()
	ok("«Не скрывать»: дальше и без отсечения кусков", Parts.grass_k >= 3.0 and not Parts.grass_off)
	game.settings["grass_range"] = "off"
	game.apply_grass_range()
	ok("«Выключить»: ковёр без радиуса", game.grass.radius == 0.0 and Parts.grass_off)
	game.settings["grass_range"] = "near"
	game.apply_grass_range()
	ok("«Близко»: как было", is_equal_approx(Parts.grass_k, 1.0) and game.grass.radius > 0.0)
	for q in ["low", "verylow"]:
		game.settings.erase("grass_range")
		ok("по умолчанию на «%s» — «Близко»" % q, GrassCarpet.range_key(game.settings, q) == "near")
	game.settings["quality"] = "high"
	game.settings.erase("grass_range")
	ok("по умолчанию на «Высокой» — «Далеко»", GrassCarpet.range_key(game.settings, "high") == "far")
	game.apply_grass_range()
	for v in [0, 3, 8, 13]:
		var bpb := Catalog.make("nat_bush", 0, v, 0)
		for e: Array in bpb.parts:
			print("NATURE3 DBG bush ", v, " ", e[0], " ", (e[1] as Transform3D).basis.get_scale(), " aabb ", Bp.model_aabb(String(e[0])).size)
	# 6. поле пшеницы: настоящая пшеница из набора
	var fbp := Catalog.make("farm")
	var wheat := 0
	for e: Array in fbp.parts:
		if String(e[0]).begins_with("M:SM_Env_CropField"):
			wheat += 1
	ok("поле — из пшеницы набора", wheat >= 20, str(wheat))


func _shots() -> void:
	_hide_ui()
	var out := str(A.get("out", "D:/CivCity/.work/night/nature3/shots_x"))
	var q := str(A.get("q", "high"))
	_quality(q)
	var c := Vector2(214.0, 174.0)
	game.clear_nature(c, 40.0)
	# --- «Природа»: несколько щелчков каждого инструмента (в игре каждый раз новая случайная модель) — рядами
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 7:
		put("nat_tree", Vector2(c.x - 13.0 + k * 4.4, c.y - 12.0), rng.randi() % 17, 6)
		put("nat_tree", Vector2(c.x - 13.0 + k * 4.4, c.y - 5.0), rng.randi() % 17, 6)
	await _snap_view(out, "tool_tree", Vector2(c.x, c.y - 8.0), 0.0, 36.0, 24.0)
	for k in 8:
		put("nat_bush", Vector2(c.x - 14.0 + k * 4.0, c.y + 1.0), rng.randi() % 18, 6)
		put("nat_bush", Vector2(c.x - 14.0 + k * 4.0, c.y + 5.0), rng.randi() % 18, 6)
	await _snap_view(out, "tool_bush", Vector2(c.x, c.y + 3.0), 0.0, 40.0, 17.0)
	for k in 6:
		put("nat_palm", Vector2(c.x - 10.0 + k * 4.0, c.y + 9.0), rng.randi() % 3, 6)
	await _snap_view(out, "tool_palm", Vector2(c.x, c.y + 9.0), 0.0, 32.0, 17.0)
	# --- цвета цветов
	for ci in CatNature.FLOWER_COLORS.size():
		put("nat_flowers", Vector2(c.x - 9.0 + ci * 3.0, c.y + 12.0), ci % 3, ci)
		put("nat_flowers", Vector2(c.x - 9.0 + ci * 3.0, c.y + 15.5), (ci + 1) % 3, ci)
	await _snap_view(out, "flower_colors", Vector2(c.x - 0.0, c.y + 12.0), 0.0, 30.0, 12.0)
	# --- отдельные модели Meadow
	var singles := ["nat_rock", "nat_stones", "nat_wall", "nat_sunflowers"]
	for si in singles.size():
		for k in 3:
			put(singles[si], Vector2(c.x - 8.0 + si * 4.5, c.y + 20.0 + k * 3.5), k, 6)
	await _snap_view(out, "singles", Vector2(c.x - 2.0, c.y + 23.0), 0.0, 34.0, 18.0)
	# --- кисть травы: убрать полосу в траве, посадить круг
	var land: Land = game.land
	var bc := Vector2(c.x + 28.0, c.y + 4.0)
	game.tool = "ungrass"
	game.brush_r = 3.0
	for k in 14:
		game._paint_at(bc + Vector2(k * 1.5 - 10.0, 0.0))
	game.tool = "grass"
	game.brush_r = 2.5
	for k in 8:
		game._paint_at(bc + Vector2(k * 1.2 - 4.0, 8.0))
	game.tool = ""
	await _snap_view(out, "brush", bc + Vector2(0, 4.0), 0.0, 40.0, 26.0)
	# --- поле пшеницы и мельница
	var fp := Vector2(c.x - 36.0, c.y + 4.0)
	game.clear_nature(fp, 18.0)
	put("farm", fp)
	put("windmill", fp + Vector2(14.0, -4.0), 0, -1, 0.5)
	put("windmill_2", fp + Vector2(14.0, 10.0), 0, -1, -0.3)
	await _snap_view(out, "farm_mill", fp + Vector2(7.0, 3.0), 30.0, 36.0, 28.0)
	await _snap_view(out, "farm_close", fp, 20.0, 32.0, 14.0)
	await _snap_view(out, "mill_close", fp + Vector2(14.0, -4.0), 10.0, 22.0, 9.0)
	# --- мост и ручей
	for br in land.bridges:
		var bp: Vector2 = br["pos"]
		await _snap_view(out, "bridge_a", bp, 0.0, 30.0, 20.0)
		await _snap_view(out, "bridge_b", bp, 70.0, 22.0, 12.0)
		break
	# --- пруд с лодкой
	var boats = game.get_node_or_null("Boats")
	if boats != null and not boats.boats.is_empty():
		game._set_hour(11.0)
		await frames(30)
		var bn: Node3D = boats.boats[0]["n"]
		await _snap_view(out, "boat", Vector2(bn.global_position.x, bn.global_position.z), 20.0, 38.0, 6.0, 20)
	print("NATURE3 shots done")


## Интерфейс: вкладка «Природа» в украшениях, панель «Цветы» с выбором цвета, кисти травы, мельница и поле в «Хозяйстве», настройки
func _ui() -> void:
	var out := str(A.get("out", "D:/CivCity/.work/night/nature3/ui_x"))
	DirAccess.make_dir_recursive_absolute(out)
	var h = game.hud
	h.visible = true
	await frames(600)                     # картинки карточек рисуются по очереди после загрузки
	var c := Vector2(214.0, 174.0)
	_view(c.x, c.y, 0.0, 38.0, 24.0)
	h._toggle_cat("decor")
	h.open_dsub = "nature"
	h.decor_mode = ""
	h._fill_cards()
	await frames(40)
	await _shot_ui(out, "tray_nature")
	h.select_build("nat_flowers", true)
	game.flower_color = 1
	await frames(60)
	h._fill_tool_panel()
	await _shot_ui(out, "tool_flowers")
	game.set_tool("")
	h._toggle_cat("farming")
	h._fill_cards()
	await frames(40)
	await _shot_ui(out, "tray_farming")
	h._toggle_cat("farming")
	game.set_tool("grass")
	await frames(30)
	await _shot_ui(out, "brush_grass")
	game.set_tool("")
	h._open_settings()
	await frames(30)
	await _shot_ui(out, "settings")


## Птицы на крышах города владельца: сидят на коньках, взлетают и садятся сверху, сквозь постройки не летают
func _birds() -> void:
	var out := str(A.get("out", "D:/CivCity/.work/night/nature3/birds_x"))
	DirAccess.make_dir_recursive_absolute(out)
	game.can_save = false
	game.hud.visible = false
	game.rig.cine = true
	game.people.visible = false
	if game.weather:
		game.weather.force = 0.0
		game.weather.left_h = 0.0
	game.city.buildings.size()
	var rb: RoofBirds = game.find_child("RoofBirds", true, false) as RoofBirds
	ok("есть птицы на крышах", rb != null)
	var v := str(A.get("view", "domus:262.8:171.2:-120:40:18")).split(":")
	_view(float(v[1]), float(v[2]), float(v[3]), float(v[4]), float(v[5]))
	game.speed = 3.0
	game._set_hour(10.0)
	var bad := 0
	var samples := 0
	var max_perched := 0
	var shots := 0
	var t_end := Time.get_ticks_msec() + int(float(A.get("secs", "40")) * 1000.0)
	var next_shot := 0
	while Time.get_ticks_msec() < t_end:
		await frames(6)
		game._set_hour(10.0)
		max_perched = maxi(max_perched, rb.birds.size())
		for f: Dictionary in rb.flying:
			var n: Node3D = f["n"]
			if not is_instance_valid(n):
				continue
			var p := n.global_position
			var o: int = game.land.occ[game.land.idx(clampi(int(p.x / Land.CELL), 0, Land.N - 1), clampi(int(p.z / Land.CELL), 0, Land.N - 1))]
			samples += 1
			if o != 0 and game.city.buildings.has(o):
				var b: Dictionary = game.city.buildings[o]
				if p.y < game.city.xf(b).origin.y + game.city.blueprint(b).top_y() - 0.05 and not game.city.def(b).get("water", false):
					bad += 1
		if Time.get_ticks_msec() > next_shot and shots < 8 and (not rb.birds.is_empty() or not rb.flying.is_empty()):
			next_shot = Time.get_ticks_msec() + 4000
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out.path_join("birds_%d.png" % shots))
			shots += 1
	ok("птицы сидят (больше нуля и не больше предела)", max_perched >= 1 and max_perched <= RoofBirds.MAX_BIRDS, str(max_perched))
	ok("летящие птицы не залетают в постройки", bad == 0 and samples > 0, "в постройках %d из %d замеров" % [bad, samples])


func _shot_ui(out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("NATURE3 ui ", name)


func _snap_view(out: String, name: String, p: Vector2, yaw: float, pitch: float, dist: float, wait := 90) -> void:
	_view(p.x, p.y, yaw, pitch, dist)
	game._set_hour(float(A.get("hour", "13")))
	await _snap(out.path_join(name + ".png"), wait)
