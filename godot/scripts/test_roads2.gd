extends Node3D
## Новые покрытия: кисти, сохранение и пять кадров. Godot запускает проверяющий.

var out := "D:/CivCity/.work/stage3/roads1/shots/"
var quality := "high"
var game: Game
var failures := 0
var houses: Array[Dictionary] = []
const TYPES := ["cobble", "road", "footpath", "path"]
const ROWS := [172.0, 188.0, 204.0, 220.0]


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2 and pair[0] == "out":
			out = pair[1] if pair[1].ends_with("/") else pair[1] + "/"
		elif pair.size() == 2 and pair[0] == "q" and Gfx.ORDER.has(pair[1]):
			quality = pair[1]
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	add_child(game)
	game.can_save = false
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, reason: String) -> bool:
	if not ok:
		failures += 1
		push_error("ROADS2 FAIL " + reason)
	return ok


func shot(nm: String) -> void:
	await frames(12)
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(out + nm)
	if check(error == OK, "save " + nm):
		print("ROADS2 SHOT ", out + nm)


func cell_at(p: Vector2) -> int:
	var c := game.land.cell(p)
	return game.land.idx(c.x, c.y)


func street(t: String, a: Vector2, b: Vector2) -> void:
	game.set_tool(t)
	game.brush_line = true
	game.brush_r = 1.75
	game.brush_square = false
	game.brush_over = true
	game.painting = true
	game._paint_broke = false
	game.stroke = []
	game.stroke_cost = 0.0
	game.line_from = a
	game.hover = b
	game._line_update(true)
	var price: float = game.line_plan.get("cost", -1.0)
	var money := game.city.money
	check(price > 0.0, "line price " + t)
	check(game._prev_mode == 1, "line preview " + t)
	game._release()
	check(is_equal_approx(money - game.city.money, price), "charged preview price " + t)
	check(game.land.road_kind(cell_at(a.lerp(b, 0.5))) == int(Game.ROAD_KIND[t]), "painted " + t)


func material_checks() -> void:
	var land := game.land
	check(Defs.ROAD_COST["cobble"] == Defs.ROAD_COST["road"], "cobble cost")
	check(Defs.ROAD_COST["footpath"] == Defs.ROAD_COST["path"], "footpath cost")
	for t: String in ["cobble", "footpath"]:
		var p := Vector2(174, 172 if t == "cobble" else 204)
		var k := cell_at(p)
		var kd: int = Game.ROAD_KIND[t]
		var base := Land.road_base(kd)
		check(land.kind[k] == base and land.is_road(p), "walk class " + t)
		check(game.city._road_near(p, 1.7, PackedInt32Array()), "building access " + t)
		var same := land.line_cells(p, p + Vector2(5, 0), 0.5, kd)
		check((same["fresh"] as PackedByteArray).count(1) == 0, "no duplicate line charge " + t)
		var blocked := land.line_cells(p, p + Vector2(5, 0), 0.5, base, false, false)
		check((blocked["cells"] as PackedInt32Array).is_empty(), "over disabled " + t)
		var replace_line := land.line_cells(p, p + Vector2(5, 0), 0.5, base)
		check((replace_line["fresh"] as PackedByteArray).count(1) > 0, "replace counts as fresh " + t)
		var erased := land.apply_cells(PackedInt32Array([k]), Land.Kind.GRASS)
		check(land.deco[k] == 0 and not land.is_road(p), "erase " + t)
		land.undo(erased)
		check(land.road_kind(k) == kd, "undo erase " + t)
		var upgrade := land.brush_apply(PackedInt32Array([k]), -1)
		check((land.deco[k] & Land.ROAD_STYLE) == 0, "upgrade removes old material " + t)
		check(land.kind[k] == Land.Kind.ROAD and (land.is_up(k) == (t == "cobble")), "upgrade class " + t)
		land.undo(upgrade)
		check(land.road_kind(k) == kd, "undo upgrade " + t)
		# Свободная кисть: замена базового вида тоже платная, возврат — с материалом.
		var changed := land.paint_circle(p, 0.5, base, false)
		check(not changed.is_empty() and land.road_kind(k) == base, "free repaint " + t)
		land.undo(changed)
		check(land.road_kind(k) == kd, "undo free repaint " + t)
	game.people.refresh(land.dirty_walk.keys())
	for z: float in [172.0, 204.0]:
		check(game.people._path(Vector2(154, z), Vector2(226, z + 7)).size() >= 2, "residents walk straight and corner " + str(z))
	# В памяти и на диске используется настоящий формат земли, без пользовательского слота.
	var saved := land.save_changes()
	var f := FileAccess.open(out + "roads2_land.json", FileAccess.WRITE)
	if not check(f != null, "open roundtrip fixture"):
		return
	f.store_string(JSON.stringify(saved))
	f.close()
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(out + "roads2_land.json"))
	if not check(decoded is Dictionary, "parse roundtrip fixture"):
		return
	var loaded := Land.new()
	loaded.load_changes(decoded)
	for n in TYPES.size():
		var p := Vector2(174, ROWS[n])
		var k := cell_at(p)
		check(loaded.road_kind(k) == int(Game.ROAD_KIND[TYPES[n]]), "roundtrip " + TYPES[n])
		check(loaded.is_road(p), "loaded walk " + TYPES[n])
	check(loaded.road_style_n == land.road_style_n, "roundtrip material count")
	var same_materials := true
	for k: int in land.deco_cells:
		if loaded.deco[k] != land.deco[k] or loaded.kind[k] != land.kind[k]:
			same_materials = false
			break
	check(same_materials, "roundtrip all material cells")
	var mask_a := Image.create(Land.N / Land.SM, Land.N / Land.SM, false, Image.FORMAT_RGBA8)
	var mask_b := Image.create(Land.N / Land.SM, Land.N / Land.SM, false, Image.FORMAT_RGBA8)
	for n in TYPES.size():
		var c := loaded.cell(Vector2(174, ROWS[n]))
		var px := Vector2i(c.x / Land.SM, c.y / Land.SM)
		loaded._deco_px(mask_a, mask_b, px.x, px.y)
		var color := mask_b.get_pixelv(px)
		check(is_equal_approx(color.b, 1.0 if n == 0 else 0.0), "cobble mask %d" % n)
		check(is_equal_approx(color.a, 1.0 if n == 2 else 0.0), "footpath mask %d" % n)
	# Старый формат без deco сохраняет исходные номера покрытий.
	var legacy: Dictionary = saved.duplicate(true)
	legacy.erase("deco")
	legacy.erase("deco_v")
	loaded = null
	loaded = Land.new()
	loaded.load_changes(legacy)
	check(loaded.road_style_n == 0, "legacy has no new material")
	for n in TYPES.size():
		check(loaded.kind[cell_at(Vector2(174, ROWS[n]))] == Land.road_base(Game.ROAD_KIND[TYPES[n]]), "legacy kind %d" % n)


func put_house(p: Vector2) -> void:
	for attempt in 24:
		var at := p + Vector2((attempt % 6) * 0.3, (attempt / 6) * 0.25)
		var pl: Dictionary = game.placement("house_pleb", at)
		if pl["err"] != "":
			continue
		var b := game.city.place("house_pleb", pl["pos"], pl["yaw"], pl["variant"], pl["color"], true)
		game._show(b)
		houses.append(b)
		return
	check(false, "house near " + str(p))


func view_at(p: Vector2, distance: float, pitch_deg: float) -> void:
	game.set_tool("")
	game.hud.visible = false
	game.rig.set_view(Vector3(p.x, game.land.height_at(p.x, p.y), p.y), 0.0, pitch_deg, distance)


func _run() -> void:
	var waited := 0
	while not game.ready_done:
		await frames(5)
		waited += 5
		if waited >= 18000:
			check(false, "ready_done timeout")
			get_tree().quit(1)
			return
	game.can_save = false
	game.settings["autosave"] = false
	game.settings["quality"] = quality
	game.settings["quality_user"] = true
	game._apply_quality()
	game.speed = 0.0
	game.city.money = 1000000.0
	game.hud.close_panels()
	game.hud.advisor_panel.visible = false
	if game.weather:
		game.weather.left_h = 0.0
		game.weather.force = 0.0
	game._set_hour(11.0)
	if not check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory"):
		get_tree().quit(1)
		return
	# Четыре параллельные улицы: у новых — ещё и угол справа.
	game.clear_nature(Vector2(190, 196), 53.0)
	for n in TYPES.size():
		street(TYPES[n], Vector2(150, ROWS[n]), Vector2(226, ROWS[n]))
		if n == 0 or n == 2:
			street(TYPES[n], Vector2(226, ROWS[n]), Vector2(226, ROWS[n] + 9))
	material_checks()
	game.set_tool("house_pleb")
	game.snap = true
	for n in TYPES.size():
		for x: float in [164.0, 187.0, 210.0]:
			put_house(Vector2(x, ROWS[n] - 4.0))
	game.city.compute()
	for b: Dictionary in houses:
		check(bool(b.get("road", false)), "house road access " + str(b["id"]))
	game.set_tool("")
	await frames(180)
	view_at(Vector2(182, 172), 19.0, 54.0)
	await shot("1_cobble_close.png")
	view_at(Vector2(182, 204), 19.0, 54.0)
	await shot("2_footpath_close.png")
	view_at(Vector2(190, 195), 100.0, 68.0)
	await shot("3_compare_mid.png")
	view_at(Vector2(190, 188), 125.0, 46.0)
	await shot("4_far.png")
	game.hud.visible = true
	game.hud.apply_reveal(3)
	game.set_tool("cobble")
	for t: String in ["cobble", "footpath"]:
		var button := game.hud.road_btns.get(t) as Button
		check(button != null and button.is_visible_in_tree(), "swatch visible " + t)
		check(game.hud._road_group(t) == "roads", "road group " + t)
		if button != null:
			button.pressed.emit()
			check(game.tool == t and not button.tooltip_text.is_empty(), "swatch selects " + t)
	await shot("5_panel.png")
	if failures == 0:
		print("ROADS2 DONE")
	get_tree().quit(0 if failures == 0 else 1)
