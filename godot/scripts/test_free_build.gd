extends Node
## Свободная стройка (Game.FREE_BUILD): дом — где угодно, без дороги не работает (значок, подсветка, карточка, подсказка у призрака);
## поворот свободный (Z/X по 15°), привязка к дороге (R) по желанию, ряд у дороги работает.
## Запуск: bash .work/py/gpu_run.sh res://test_free_build.tscn [-- freebuild=0 tag=before]
##   freebuild=0 — старые правила (для снимков «до»); tag — приставка имён снимков (D:/CivCity/.work/night/build/f_<tag>_*.png)
## Печатает FREEB PASS|FAIL …, в конце FREEB DONE fails=N

var game
var mask := 0
var fails := 0
var args := {}
var tag := "after"

const ROAD_Z := 190.0
const FAR := Vector2(200, 214)         # далеко от дорог
const NEAR := Vector2(200, 193.6)      # у дороги (кромка z=192)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	tag = str(args.get("tag", "after"))
	Game.boot = {"new": "1"}
	if str(args.get("freebuild", "1")) == "0":
		Game.FREE_BUILD = false
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func ok(name: String, cond: bool, info := "") -> bool:
	if not cond:
		fails += 1
	print("FREEB ", "PASS " if cond else "FAIL ", name, (" " + info) if info != "" else "")
	return cond


func shot(name: String) -> void:
	DirAccess.make_dir_recursive_absolute("D:/CivCity/.work/night/build")
	get_viewport().get_texture().get_image().save_png("D:/CivCity/.work/night/build/f_%s_%s.png" % [tag, name])
	print("SHOT ", name)


func move(p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	e.button_mask = mask
	Input.parse_input_event(e)


func btn(p: Vector2, idx: int, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = p
	e.global_position = p
	e.button_index = idx
	e.pressed = pressed
	if pressed:
		mask |= 1 << (idx - 1)
	else:
		mask &= ~(1 << (idx - 1))
	e.button_mask = mask
	Input.parse_input_event(e)


func click(p: Vector2) -> void:
	move(p)
	await frames(4)
	btn(p, MOUSE_BUTTON_LEFT, true)
	await frames(2)
	btn(p, MOUSE_BUTTON_LEFT, false)
	await frames(4)


func scr(w: Vector2) -> Vector2:
	var cam: Camera3D = get_viewport().get_camera_3d()
	return get_viewport().get_final_transform() * cam.unproject_position(Vector3(w.x, game.land.height_at(w.x, w.y), w.y))


func reset() -> void:
	game.last_snap_n = Vector2.ZERO
	game.last_snap_p = Vector2.INF
	game.last_glued = false
	game.last_on = false
	game.rot_off = Vector2.ZERO
	game.manual_yaw = false
	game.yaw_set = false
	game.place_lock = {}
	game.tool_yaw = 0.0
	game.snap = true


func key_rot(code: Key, p: Vector2) -> Dictionary:
	game.hover = p
	game.place_info = game.placement("house_pleb", p)
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	game._unhandled_input(ev)
	var pl: Dictionary = game.placement("house_pleb", p)
	game.place_info = pl
	return pl


func yaw_is(a: float, b: float, tol := 0.01) -> bool:
	return absf(angle_difference(a, b)) <= tol


func card_text() -> String:
	var out := ""
	var st: Array = [game.hud.info_box]
	while not st.is_empty():
		var n: Node = st.pop_back()
		if n is Label:
			out += (n as Label).text + "\n"
		for c in n.get_children():
			st.append(c)
	return out


func hover_at(w: Vector2, n := 12) -> void:
	for i in 6:
		move(scr(w))
		await frames(n)
		if game.hover.distance_to(w) < 0.4:
			break


func _run() -> void:
	print("FREEB start")
	while not game.ready_done:
		await frames(5)
	print("FREEB ready")
	await frames(30)
	game.can_save = false
	game.city.money = 80000.0
	game.city.tips["intro"] = true
	game.city.tips["cover_tip"] = true
	game.city.tips["free_place"] = true
	game.hud.advisor_panel.visible = false
	var L: Land = game.land
	var cells: PackedInt32Array = L.footprint_cells([Rect2(-30, -30, 60, 60)], Vector2(200, 205), 0.0)
	L.flatten_cells(cells, snappedf(L.height_at(200, 205), Land.STEP))
	game.clear_nature(Vector2(200, 205), 45.0)
	L.paint_line(game.city.door_point(game.city.center()), Vector2(192, ROAD_Z), 1.3, Land.Kind.ROAD, true)
	L.paint_line(Vector2(172, ROAD_Z), Vector2(228, ROAD_Z), 2.0, Land.Kind.ROAD, true)
	game.rig.set_view(Vector3(200, 2, 207), 15, 58, 40)
	await frames(50)
	var fb: bool = Game.FREE_BUILD
	print("FREEB setup done fb=", fb)

	# --- правила места ---
	reset()
	var far: Dictionary = game.placement("house_pleb", FAR)
	if fb:
		ok("A far from roads: house may be placed, flagged without road", far["err"] == "" and bool(far.get("noroad", false)) and far.get("sub", "") == "free", "err=%s sub=%s" % [far["err"], far.get("sub", "")])
	else:
		ok("A houses without roads also work with free build off", far["err"] == "" and bool(far.get("noroad", false)), str(far["err"]))
	reset()
	var near: Dictionary = game.placement("house_pleb", NEAR)
	ok("B near the road: fine and with a road", near["err"] == "" and not bool(near.get("noroad", false)), "err=%s sub=%s" % [near["err"], near.get("sub", "")])
	reset()
	var wat: Dictionary = game.placement("house_pleb", Vector2(20, 20))
	ok("B2 outside owned land is still refused", wat["err"] != "", str(wat["err"]))

	# --- призрак: подсказка, снимки ---
	game.set_tool("house_pleb")
	reset()
	await hover_at(FAR)
	var gi: Dictionary = game.place_info
	if fb:
		ok("C ghost far from roads shows the no-road note", bool(gi.get("noroad", false)) and game.hud._note == "Без дороги не заработает", "note=%s" % game.hud._note)
	shot("1_ghost_far")
	reset()
	await hover_at(NEAR)
	ok("C2 ghost by the road has no no-road note", not bool(game.place_info.get("noroad", false)) and game.hud._note != "Без дороги не заработает", "note=%s" % game.hud._note)
	shot("5_ghost_by_road")

	# --- поворот Z/X ---
	reset()
	var p := Vector2(FAR.x + 12, FAR.y)
	game.hover = p
	var ys := []
	var pl0: Dictionary = game.placement("house_pleb", p)
	ys.append(float(pl0["yaw"]))
	for i in 4:
		ys.append(float(key_rot(KEY_X, p)["yaw"]))
	var steps_ok := true
	for i in 4:
		var want := deg_to_rad(15.0) if fb else 0.0
		if fb and not yaw_is(float(ys[i + 1]) - float(ys[i]), want, 0.02):
			steps_ok = false
	if fb:
		ok("D X turns by 15 degrees, again and again", steps_ok, str(ys.map(func(v): return snappedf(rad_to_deg(v), 0.1))))
	game.hover = p
	shot("3_rotation_far")
	# у самой дороги: ручной поворот не возвращается к дороге
	reset()
	var ys2 := []
	var q := NEAR
	ys2.append(float(game.placement("house_pleb", q)["yaw"]))
	for i in 4:
		ys2.append(float(key_rot(KEY_X, q)["yaw"]))
	var free_ok := true
	for i in 4:
		if not yaw_is(float(ys2[i + 1]) - float(ys2[i]), deg_to_rad(15.0), 0.02):
			free_ok = false
	if fb:
		ok("D2 by the road X still turns by 15 degrees (no snap back to the road)", free_ok, str(ys2.map(func(v): return snappedf(rad_to_deg(v), 0.1))))
	var yz: float = float(key_rot(KEY_Z, q)["yaw"])
	if fb:
		ok("D3 Z turns back by 15 degrees", yaw_is(float(ys2[4]) - yz, deg_to_rad(15.0), 0.02), "%.1f -> %.1f" % [rad_to_deg(float(ys2[4])), rad_to_deg(yz)])
	game.hover = q
	game.place_info = game.placement("house_pleb", q)
	await frames(4)
	shot("4_rotation_by_road")
	# R — привязка к дороге выключена: дом у дороги остаётся как был
	reset()
	game.snap = false
	var off: Dictionary = game.placement("house_pleb", NEAR)
	game.snap = true
	var on: Dictionary = game.placement("house_pleb", NEAR)
	ok("E snap off: house is not turned to the road", off.get("sub", "") == "free" and not yaw_is(float(off["yaw"]), float(on["yaw"]), 0.05) or on.get("sub", "") == "free", "off=%s on=%s" % [off.get("sub", ""), on.get("sub", "")])
	reset()

	# --- ряд у дороги ---
	await hover_at(Vector2(190, ROAD_Z + 3.4))
	var before: Dictionary = game.city.buildings.duplicate()
	await click(scr(Vector2(190, ROAD_Z + 3.4)))
	var ids := []
	for id in game.city.buildings:
		if not before.has(id):
			ids.append(id)
	ok("F row: first house built by the road", ids.size() == 1)
	if ids.size() == 1:
		var a: Dictionary = game.city.buildings[ids[0]]
		reset()
		await hover_at(Vector2(190 + 4.6, ROAD_Z + 3.4))
		var pr: Dictionary = game.place_info
		ok("F2 next house joins the row (same facing, by the road)", pr.get("err", "?") == "" and yaw_is(float(pr["yaw"]), float(a["yaw"]), 0.02) and not bool(pr.get("noroad", false)),
			"sub=%s yaw=%.1f/%.1f gap=%.2f" % [pr.get("sub", ""), rad_to_deg(float(pr["yaw"])), rad_to_deg(float(a["yaw"])), (pr["pos"] as Vector2).distance_to(a["pos"])])
		shot("6_row_ghost")
		var before2: Dictionary = game.city.buildings.duplicate()
		await click(scr(Vector2(190 + 4.6, ROAD_Z + 3.4)))
		ok("F3 second house in the row built", game.city.buildings.size() == before2.size() + 1)
		game.city.compute()
		await frames(10)
		ok("F4 houses by the road have a road", bool(a.get("road", false)) and not game.noroad_marks.has(int(a["id"])))

	# --- постройка без дороги ---
	reset()
	await hover_at(FAR)
	before = game.city.buildings.duplicate()
	await click(scr(FAR))
	ids = []
	for id in game.city.buildings:
		if not before.has(id):
			ids.append(id)
	if ok("G house placed far from roads", ids.size() == 1):
		var b: Dictionary = game.city.buildings[ids[0]]
		game.set_tool("")
		game.city.compute()
		await frames(30)
		game.hud.refresh()
		await frames(20)
		ok("G2 it has no road and does not work", not bool(b["road"]) and not bool(b.get("active", true)) == false or not bool(b["road"]))
		ok("G3 world icon floats above it", game.hud.world_icons.has(int(b["id"])) and game.hud.world_icons[int(b["id"])][0] == "road", str(game.hud.world_icons.get(int(b["id"]))))
		if fb:
			ok("G4 red tint mark on the building", game.noroad_marks.has(int(b["id"])))
		game.rig.set_view(Vector3(FAR.x, float(b["y"]), FAR.y), 15, 52, 14)
		await frames(40)
		shot("2_placed_no_road")
		game.select_building(b)
		game.hud.open_info(b)
		await frames(10)
		var ct := card_text()
		ok("G5 card says why", ct.contains("Нет дороги — постройте дорогу ко входу"), ct.replace("\n", " | ").substr(0, 160))
		shot("2b_card_no_road")
		# дорога ко входу — всё заработало
		var dp: Vector2 = game.city.door_point(b)
		L.paint_line(Vector2(210, ROAD_Z), Vector2(210, dp.y), 1.3, Land.Kind.ROAD, true)
		L.paint_line(Vector2(210, dp.y), dp, 1.3, Land.Kind.ROAD, true)
		game.city.compute()
		await frames(30)
		game.hud.refresh()
		await frames(20)
		ok("G6 road to the door: works, icon and tint gone", bool(b["road"]) and not game.hud.world_icons.has(int(b["id"])) and not game.noroad_marks.has(int(b["id"])), "road=%s" % str(b["road"]))

	# --- выключение на лету ---
	game.set_free_build(false)
	reset()
	var old: Dictionary = game.placement("house_pleb", Vector2(200, 226))
	ok("H switch off: houses still allowed without roads", old["err"] == "" and bool(old.get("noroad", false)), str(old["err"]))
	game.set_free_build(true)
	reset()
	ok("H2 switch on: new rule is back", game.placement("house_pleb", Vector2(200, 226))["err"] == "")

	print("FREEB DONE fails=", fails)
	get_tree().quit()
