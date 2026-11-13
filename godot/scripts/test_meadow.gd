extends Node
## Природа Meadow Forest (13.11): ряды моделей набора вблизи (деревья, кусты, цветы, трава, камни, поля, мельница,
## водяное колесо, ограды) и проверка ручьёв на картах. Снимки — в out=ПАПКА.
##   bash .work/py/gpu_run.sh res://test_meadow.tscn -- mode=lineup out=D:/… [q=high,low] [hour=15.5]
##   bash .work/py/gpu_run.sh res://test_meadow.tscn -- mode=check            — ручьи: новая карта и город владельца
##     (вода не под постройками и дорогами, ручьи не режут землю, сохранение помнит ручьи); в конце «MEADOW DONE fails=0»
##   … mode=views out=… views=имя:x:z:yaw:pitch:dist,… [city=new|путь]       — снимки видов (вода видна)

const OWNER := "D:/CivCity/.work/owner_save/city.json"

var game
var A := {}
var fails := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		A[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var city := str(A.get("city", "new"))
	if city != "new" and FileAccess.file_exists(city):
		var dst := GamePaths.save_dir().path_join("city.json")
		DirAccess.copy_absolute(city, dst)
		Game.boot = {"play": "1", "hour": str(A.get("hour", "15.5"))}
	else:
		Game.boot = {"new": "1", "hour": str(A.get("hour", "15.5"))}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func ok(name: String, cond: bool, info := "") -> void:
	if not cond:
		fails += 1
	print("MEADOW ", "PASS " if cond else "FAIL ", name, (" " + info) if info != "" else "")


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	game.can_save = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# новая игра начинается зимой (Seasons — по игровому календарю): снимки — летом, если не сказано иначе
	if game.seasons and A.get("month", "6") != "-1":
		game.seasons.force_m = float(A.get("month", "6"))
	if game.weather:
		game.weather.force = float(A.get("rain", "0"))       # снимки — без дождя (новая игра: дождь по случаю)
		game.weather.left_h = 0.0
	await frames(10)
	match str(A.get("mode", "lineup")):
		"lineup": await _lineup()
		"check": await _check()
		"views": await _views()
	print("MEADOW DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _quality(q: String) -> void:
	game.settings["quality"] = q
	game._apply_quality()
	Gfx.swap_all()


func _hide_ui() -> void:
	game.hud.visible = false
	game.rig.cine = true
	game.people.visible = false
	for n in game.find_children("*", "Decal", true, false):
		(n as Decal).visible = false          # тени облаков плывут — на снимках сверки их нет (как в test_perf)


func _snap(path: String) -> void:
	await frames(int(A.get("wait", "120")))
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	print("MEADOW shot ", path)


## Ряды моделей на ровном лугу у станции (новая игра): что за чем видно в нашем свете
func _lineup() -> void:
	_hide_ui()
	var out := str(A.get("out", "D:/CivCity/.work/nature/lineup"))
	var c := Vector2(214.0, 172.0)
	game.clear_nature(c, 26.0)
	var y: float = game.land.height_at(c.x, c.y)
	var rows := [
		["M:SM_Env_Tree_Meadow_01", "M:SM_Env_Tree_Meadow_02", "M:SM_Env_Tree_Birch_01", "M:SM_Env_Tree_Birch_02", "M:SM_Env_Tree_Birch_03",
			"M:SM_Env_Tree_Fruit_01", "M:SM_Env_Tree_Fruit_02", "M:SM_Env_Tree_Fruit_03", "SM_Env_Tree_01", "SM_Env_Tree_Large_01"],
		["M:SM_Env_Bush_01", "M:SM_Env_Bush_02", "M:SM_Env_Bush_03", "M:SM_Env_Rock_01", "M:SM_Env_Rock_03", "M:SM_Env_Rock_Pile_02",
			"M:SM_Env_Rock_Small_Pile_02", "M:SM_Prop_Stonewall_Long_01", "M:SM_Bld_Windmill_01", "M:SM_Prop_WaterWheel_01"],
		["M:SM_Env_Wildflowers_01", "M:SM_Env_Wildflowers_02", "M:SM_Env_Wildflowers_03", "M:SM_Env_Wildflowers_01@1", "M:SM_Env_Flowers_Flat_01",
			"M:SM_Env_Flowers_Flat_02", "M:SM_Env_Grass_Tall_Clump_01", "M:SM_Env_Grass_Med_Clump_01", "M:SM_Env_Ground_Cover_01", "M:SM_Env_Grass_Bush_01"],
		["M:SM_Env_Sunflower_01", "M:SM_Env_CropField_Clump_01", "M:SM_Env_CropField_Clump_02", "M:SM_Env_Lillies_01", "M:SM_Env_Rock_Round_01",
			"SM_Env_Flowers_01", "SM_Env_Grass_01", "SM_Env_Tree_Bush_01", "SM_Env_Rock_Cliff_02", "M:SM_Env_Rock_Small_Pile_01"],
	]
	var sc := {"M:SM_Env_Tree_Meadow_01": 0.42, "M:SM_Env_Tree_Meadow_02": 0.72, "M:SM_Env_Tree_Birch_01": 0.6, "M:SM_Env_Tree_Birch_02": 0.65,
		"M:SM_Env_Tree_Birch_03": 0.9, "M:SM_Env_Tree_Fruit_01": 0.85, "M:SM_Env_Tree_Fruit_02": 0.9, "M:SM_Env_Tree_Fruit_03": 1.1,
		"SM_Env_Tree_01": 0.55, "SM_Env_Tree_Large_01": 0.36, "M:SM_Env_Bush_01": 0.6, "M:SM_Env_Bush_02": 0.9, "M:SM_Env_Bush_03": 0.55,
		"M:SM_Env_Rock_01": 0.4, "M:SM_Env_Rock_03": 0.35, "M:SM_Env_Rock_Pile_02": 0.15, "M:SM_Prop_Stonewall_Long_01": 0.8,
		"M:SM_Bld_Windmill_01": 0.72, "M:SM_Prop_WaterWheel_01": 0.62, "M:SM_Env_Lillies_01": 0.5, "SM_Env_Rock_Cliff_02": 0.2,
		"SM_Env_Tree_Bush_01": 0.65, "M:SM_Env_Wildflowers_Patch_01": 0.2, "SM_Env_Flowers_01": 1.4}
	var gap := [5.0, 4.4, 1.6, 1.6]
	var z := c.y - 9.0
	for ri in rows.size():
		var row: Array = rows[ri]
		for i in row.size():
			var nm: String = row[i]
			var p := Vector2(c.x - gap[ri] * 4.5 + i * gap[ri], z)
			var yy: float = game.land.height_at(p.x, p.y)
			var s := float(sc.get(nm, 1.0))
			if nm == "FX:butterfly":
				game._add_nature("M:FX_Butterfly_Mesh_01", Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.09), Vector3(p.x, yy + 0.4, p.y)), p)
				continue
			game._add_nature(nm, Transform3D(Basis(Vector3.UP, 0.4).scaled(Vector3.ONE * s), Vector3(p.x, yy, p.y)), p,
				{"bloom": 1} if nm.contains("Fruit") else {})
		z += [7.0, 6.0, 3.0, 3.0][ri]
	for q: String in str(A.get("q", "high,low")).split(","):
		_quality(q)
		game.rig.set_view(Vector3(c.x, y, c.y - 1.0), 0.0, 32.0, 34.0)
		game._set_hour(float(A.get("hour", "15.5")))
		await _snap(out.path_join("lineup_%s.png" % q))
		game.rig.set_view(Vector3(c.x, y, c.y + 5.0), 20.0, 40.0, 14.0)
		await _snap(out.path_join("lineup_near_%s.png" % q))


func _views() -> void:
	_hide_ui()
	var out := str(A.get("out", "D:/CivCity/.work/nature/views"))
	for q: String in str(A.get("q", "high")).split(","):
		_quality(q)
		for v: String in str(A.get("views", "")).split(",", false):
			var f := v.split(":")
			game.rig.set_view(Vector3(float(f[1]), game.land.height_at(float(f[1]), float(f[2])), float(f[2])), float(f[3]), float(f[4]), float(f[5]))
			game._set_hour(float(A.get("hour", "15.5")))
			await _snap(out.path_join("%s_%s.png" % [q, f[0]]))


## Ручьи: на месте ли, нет ли воды под постройками и дорогами, сохранение помнит ручьи
func _check() -> void:
	var land: Land = game.land
	ok("ручьи проложены", not land.streams.is_empty(), str(land.streams))
	var wet_under := 0
	var wet_road := 0
	for b in game.city.buildings.values():
		for k: int in b["cells"]:
			if land.hq(k) < Land.WATER_Y + 0.05 and not Land.PONDS.is_empty():
				# вода под постройкой: только если клетка — в ложбине ручья
				for id: int in land.streams:
					if (Streams.cells(land, id)["cells"] as Dictionary).has(k):
						wet_under += 1
	for id: int in land.streams:
		var cd: Dictionary = Streams.cells(land, id)["cells"]
		for k: int in cd:
			if Land.walk_kind(land.kind[k]) and land.hq(k) < Land.WATER_Y + 0.05:
				wet_road += 1
	ok("нет воды ручьёв под постройками", wet_under == 0, str(wet_under))
	ok("нет воды ручьёв на дорогах", wet_road == 0, str(wet_road))
	ok("мосты на большой дороге", land.streams.has(6) == not land.bridges.is_empty(), str(land.bridges.size()))
	var sv: Dictionary = land.save_changes()
	ok("сохранение помнит ручьи", sv.has("streams") and (sv["streams"] as Array).size() == land.streams.size(), str(sv.get("streams")))
	# земля не разрезана: от станции до каждого участка своей земли можно дойти по суше (поиск по сетке 1 м)
	var cut := _cut_check()
	ok("ручьи не отрезают своей земли", cut == 0, "отрезано клеток: %d" % cut)
	# второй заход: та же земля из сохранения — ручьи те же, без новых проверок
	var l2 := Land.new()
	l2.load_changes(sv)
	var list := Streams.choose(l2, l2.streams_saved)
	ok("из сохранения — те же ручьи", list == land.streams, "%s / %s" % [str(list), str(land.streams)])
	# мельница — украшение: строится, есть след, ставится на свободный луг у дороги новой игры
	for t: String in ["windmill", "windmill_2"]:
		var bp := Catalog.make(t)
		var mill := 0
		for e: Array in bp.parts:
			if String(e[0]).contains("Windmill"):
				mill += 1
		ok("украшение %s строится" % t, mill == 1 and bp.parts.size() >= 4, "деталей %d" % bp.parts.size())
	var t0 := Time.get_ticks_msec()
	var l3 := Land.new()
	var all := Streams.choose(l3, null)
	print("MEADOW choose на чистой карте: ", all, " за ", Time.get_ticks_msec() - t0, " мс (с картой)")


func _cut_check() -> int:
	var land: Land = game.land
	var S := int(Land.SIZE)
	var seen := PackedByteArray()
	seen.resize(S * S)
	var q: Array[Vector2i] = []
	var st := Vector2i(int(Land.START.x), int(Land.START.y))
	q.append(st)
	seen[st.y * S + st.x] = 1
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		for d: Vector2i in dirs:
			var n := c + d
			if n.x < 0 or n.y < 0 or n.x >= S or n.y >= S or seen[n.y * S + n.x] == 1:
				continue
			if land.is_water(Vector2(n.x + 0.5, n.y + 0.5)):
				continue
			seen[n.y * S + n.x] = 1
			q.append(n)
	var cut := 0
	for j in S:
		for i in S:
			var p := Vector2(i + 0.5, j + 0.5)
			if land.is_owned(p) and seen[j * S + i] == 0 and not land.is_water(p):
				cut += 1
	return cut
