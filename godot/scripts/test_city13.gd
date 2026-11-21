extends Node3D

const OUTPUT := "D:/CivCity/.work/stage7/city13/"
const TestCat := preload("res://scripts/test_cat.gd")
const TestPace := preload("res://scripts/test_pace.gd")
var out := OUTPUT + "shots/"
var game: Game
var city: City
var fails := 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4).trim_suffix("/") + "/"
	var profile := OUTPUT.path_join("profiles/city13_%d" % Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(profile) == OK, "profile")
	check(DirAccess.make_dir_recursive_absolute(out) == OK, "shots")
	OS.set_environment("CIVCITY_SAVEDIR", profile)
	OS.set_environment("CIVCITY_NOLOGIN", "1")
	OS.set_environment("CIVCITY_HEROSCREEN", "0")
	GamePaths._dir = ""
	get_window().size = Vector2i(1440, 900)
	if await boot(true):
		await bridge(true)
	game.queue_free()
	await frames(5)
	if await boot(false):
		await bridge(false)
		await fields()
		await cats()
		await english()
	await balance()
	print("CITY13 DONE fails=", fails)
	get_tree().quit(0 if fails == 0 else 1)


func check(ok: bool, message: String) -> bool:
	if not ok:
		fails += 1
		print("CITY13 FAIL ", message)
	return ok


func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func shot(file: String) -> void:
	await frames(10)
	await RenderingServer.frame_post_draw
	var path := out + file
	if check(get_viewport().get_texture().get_image().save_png(path) == OK, "save " + file):
		print("CITY13 SHOT ", path)


func boot(river: bool) -> bool:
	Streams.river_on = river
	Game.boot = {"new": "1", "hour": "11", "nologin": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	game.can_save = false
	add_child(game)
	for i in 18000:
		if game.ready_done:
			break
		await get_tree().process_frame
	if not check(game.ready_done, "ready_done"):
		return false
	game.can_save = false
	game.settings["autosave"] = false
	game.speed = 0.0
	game.tutorial.finish()
	game.tutorial.set_process(false)
	game.stories.set_process(false)
	game.hud.close_panels()
	game.hud.root.hide()
	city = game.city
	city.money = 100000.0
	for tech in ["farm", "grove", "vineyard", "catshop"]:
		city.research[tech] = true
	return true


func view_at(p: Vector2, y: float, yaw: float, tilt: float, distance: float) -> void:
	game.rig.set_view(Vector3(p.x, y, p.y), yaw, tilt, distance)


func bridge(river: bool) -> void:
	var label := "river" if river else "stream"
	if not check(game.land.bridges.size() == 1, label + " bridge on the main road"):
		return
	var br: Dictionary = game.land.bridges[0]
	var p: Vector2 = br["pos"]
	var half: float = br["half"]
	var y: float = br["y"]
	var water := game.get_node_or_null("CityWater") as MeshInstance3D
	if not check(water != null and water.mesh is PlaneMesh, "rendered water plane"):
		return
	var extent := (water.mesh as PlaneMesh).size * 0.5
	var surface := Rect2(Vector2(water.position.x, water.position.z) - extent, extent * 2.0)
	var clear: bool = br["river"] == river and is_equal_approx(water.position.y, Land.WATER_Y)
	for iz in 25:
		for dx: float in [-Land.ROAD_R, -1.0, 0.0, 1.0, Land.ROAD_R]:
			var q := p + Vector2(dx, lerpf(-half, half, iz / 24.0))
			var node := Vector2i((q / (Land.CELL * Land.RS)).round())
			clear = clear and surface.has_point(q) and game.land.node_y(node.x, node.y) < Land.WATER_Y
	check(clear, label + " water covers the whole span with the bed below it")
	check(y - 0.48 > water.position.y + 0.05 and is_equal_approx(p.x, Land.ROAD_X), label + " deck follows the road above the waves")
	for offset: float in [-half + Land.CELL, 0.0, half - Land.CELL]:
		check(is_equal_approx(game.land.height_at(p.x, p.y + offset), y), label + " level walking surface")
	view_at(p, Land.WATER_Y + 0.5, 65, 23, 26.0 if river else 18.0)
	await shot("2_bridge_river.png" if river else "1_bridge_stream.png")


func plot(type: String, size: Vector2i, x0: float, x1: float, z0: float, z1: float, stride := 2.5) -> Vector2:
	for z in range(roundi(z0 / 2.5), roundi(z1 / 2.5), roundi(stride / 2.5)):
		for x in range(roundi(x0 / 2.5), roundi(x1 / 2.5), roundi(stride / 2.5)):
			var center := (Vector2(x, z) + Vector2(size) * 0.5) * Catalog.FIELD_TILE
			if city.check_place(type, center, 0.0, 0, 0, -1, PackedInt32Array(), false, size)["err"] == "":
				return Vector2(x, z) * Catalog.FIELD_TILE + Vector2.ONE * 0.4
	return Vector2.INF


func drag_plot(type: String, size: Vector2i, start: Vector2) -> Dictionary:
	if not check(start != Vector2.INF, "clear plot for " + type):
		return {}
	var id := city.next_id
	var money := city.money
	game.set_tool(type)
	game._mouse_pos = Vector2(800, 450)
	game.hover = start
	game._click()
	game.hover = start + Vector2(size - Vector2i.ONE) * Catalog.FIELD_TILE
	var preview := game.placement(type, game.hover)
	check(City.field_size(preview) == size and preview["err"] == "", "rectangle preview " + str(size))
	game._release()
	game.set_tool("")
	var b: Dictionary = city.buildings.get(id, {})
	if check(not b.is_empty(), "drag placed " + type):
		check(City.field_size(b) == size, "saved field dimensions")
		check(is_equal_approx(money - city.money, city.build_price(type, size)), "area price charged")
	return b


func grain(b: Dictionary) -> int:
	var n := 0
	for part: Array in city.blueprint(b).parts:
		n += int(String(part[0]) == "#wheat")
	return n


func batched_wheat(b: Dictionary) -> int:
	var n := 0
	var visual: Dictionary = game.visuals.get(b["id"], {})
	for h: Array in visual.get("h", []):
		var group: Dictionary = h[0]
		if not String(group["key"]).begins_with("#wheat|") or group["subs"].is_empty():
			continue
		var mm: MultiMesh = group["subs"][0]["mm"]
		var xf := mm.get_instance_transform(int(h[1]))
		if absf(xf.basis.determinant()) > 0.001:
			n += 1
	return n


func render_time() -> float:
	await frames(24)
	var start := Time.get_ticks_usec()
	for i in 90:
		await RenderingServer.frame_post_draw
	return float(Time.get_ticks_usec() - start) / 90000.0


func fields() -> void:
	var small := drag_plot("farm", Vector2i(2, 2), plot("farm", Vector2i(2, 2), 145, 180, 132, 171))
	var big := drag_plot("farm", Vector2i(5, 4), plot("farm", Vector2i(5, 4), 145, 180, 132, 171))
	if small.is_empty() or big.is_empty():
		return
	check(grain(small) == 24 and grain(big) == 120, "wheat instances scale with area")
	check(city.job_max(small) == 1 and city.job_max(big) == 4, "rounded field job slots")
	check(city.build_price("farm", Vector2i(5, 4)) == 5.0 * city.build_price("farm", Vector2i(2, 2)), "area cost ratio")
	for i in 360:
		if game.visuals.has(small["id"]) and game.visuals.has(big["id"]):
			break
		await frames(1)
	check(batched_wheat(small) == 24 and batched_wheat(big) == 120, "all wheat is present in MultiMesh batches")
	await get_tree().create_timer(2.0).timeout
	var mid: Vector2 = (small["pos"] + big["pos"]) * 0.5
	view_at(mid, float(big["y"]), -10, 63, 26)
	await shot("3_fields_sizes.png")
	view_at(big["pos"], float(big["y"]) + 0.4, 18, 33, 11)
	await shot("4_field_close.png")
	var old := city.place("farm", Vector2(166, 173), 0.0, 0, 0, true)
	var old_cells: PackedInt32Array = old["cells"]
	var data: Dictionary = JSON.parse_string(JSON.stringify(city.save_data()))
	var land := Land.new()
	land.generate()
	land.own_start()
	var loaded := City.new(land)
	loaded.load_data(data)
	var saved: Dictionary = loaded.buildings[big["id"]]
	var old_loaded: Dictionary = loaded.buildings[old["id"]]
	check(City.field_size(saved) == Vector2i(5, 4) and saved["cells"] == big["cells"], "field size and occupied cells round-trip")
	check(City.field_size(old_loaded) == Vector2i.ZERO and old_loaded["cells"] == old_cells and loaded.job_max(old_loaded) == 3, "legacy field layout and jobs")
	var farm_home := city.place("house_pleb", Vector2(177, 136), 0.0, 0, 0, true)
	var door := city.door_point(farm_home)
	game.land.paint_line(door, Vector2(Land.ROAD_X, door.y), 0.9, Land.Kind.ROAD)
	for family: String in ["Корнелии", "Ливии", "Фабии"]:
		add_family(farm_home, family)
	city.compute()
	check(city.hire(small, 1) == 1 and city.hire(big, 4) == 4, "full staffing uses scaled slots")
	var output_small := city.farm_output(small) / maxf(float(small["staff"]), 0.001)
	var output_big := city.farm_output(big) / maxf(float(big["staff"]), 0.001)
	check(output_small > 0 and is_equal_approx(output_big, output_small * 5.0), "staffed fields produce in proportion to area")
	check(drag_plot("grove", Vector2i(3, 2), plot("grove", Vector2i(3, 2), 150, 180, 156, 203)).size() > 0, "olive grove resizing")
	check(drag_plot("vineyard", Vector2i(2, 3), plot("vineyard", Vector2i(2, 3), 150, 180, 156, 203)).size() > 0, "vineyard resizing")
	view_at(Vector2(163, 196), 2, 0, 68, 115)
	var old_cap := Engine.max_fps
	var old_vsync := DisplayServer.window_get_vsync_mode()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var before := await render_time()
	var draw_before := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var count := 0
	var size := Vector2i(6, 6)
	for z in range(70, 97, 7):
		for x in range(52, 96, 7):
			var start := plot("farm", size, x * 2.5, (x + 2) * 2.5, z * 2.5, (z + 2) * 2.5)
			if start == Vector2.INF:
				continue
			var at := start - Vector2.ONE * 0.4 + Vector2(size) * Catalog.FIELD_TILE * 0.5
			if not city.place("farm", at, 0.0, 0, 0, true, size).is_empty():
				count += 1
			if count == 10:
				break
		if count == 10:
			break
	var after := await render_time()
	var draw_after := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	Engine.max_fps = old_cap
	DisplayServer.window_set_vsync_mode(old_vsync)
	check(count == 10, "performance fixture adds ten 6x6 fields")
	check(batched_wheat(small) == 24 and batched_wheat(big) == 120, "instances survive batch growth")
	print("CITY13 PERF fields=%d ms_before=%.2f ms_after=%.2f fps_before=%.1f fps_after=%.1f draws_before=%d draws_after=%d" % [
		count, before, after, 1000.0 / before, 1000.0 / after, draw_before, draw_after])


func cats() -> void:
	var shop := city.place("catshop", Vector2(177, 113), 0.0, 0, 0, true)
	var door := city.door_point(shop)
	game.land.paint_line(door + Vector2(0, 0.6), Vector2(Land.ROAD_X, door.y + 0.6), 0.9, Land.Kind.ROAD)
	city.compute()
	city.changed.emit()
	await frames(12)
	var pets: Array = game.visuals[shop["id"]].get("pets", [])
	var list := KitHouses.pets("catshop")
	if list.is_empty():
		list = CatExtra.PETS["catshop"]
	if not check(pets.size() == list.size(), "cat shop models instantiated"):
		return
	var scale := Catalog.scale_of("catshop")
	var xf := city.xf(shop)
	var shop_triangles := PackedVector3Array()
	for part: Array in city.blueprint(shop).parts:
		var name_v: String = part[0]
		if not name_v.begins_with("K:"):
			continue
		var mesh := KitLib._mesh(name_v)
		if mesh == null:
			continue
		var world: Transform3D = xf * part[1]
		for q: Vector3 in mesh.get_faces():
			shop_triangles.append(world * q)
	var cat_check := TestCat.new()
	var in_shop := 0
	var close_cat: Node3D
	for i in list.size():
		var entry: Array = list[i]
		if entry[0] != "cat":
			continue
		in_shop += 1
		var pet: Node3D = pets[i]
		if entry[6] == "petasos":
			close_cat = pet
		var seat := CatExtra.pet_position("catshop", entry)
		check(pet.global_position.distance_to(xf * (seat * scale)) < 0.03 and seat.z > 0.6, "cat seat is outside shop wall %d" % i)
		var skeletons := pet.find_children("*", "Skeleton3D", true, false)
		if not check(not skeletons.is_empty(), "Kitten skeleton available"):
			continue
		var sk := skeletons[0] as Skeleton3D
		var mi := pet.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var mat := mi.material_override as ShaderMaterial
		if not check(mat != null, "Kitten shader material"):
			continue
		var eye := mat.get_shader_parameter("eye_mask") as Texture2D
		if check(eye != null, "pupil mask on cat %d" % i):
			var img := eye.get_image()
			check(img.get_pixel(32, 32).r > 0.9 and img.get_pixel(25, 42).g > 0.65, "dark pupil and separate catchlight")
		var low := INF
		for q: Vector3 in cat_check._posed(sk, mi):
			low = minf(low, (mi.global_transform * q).y)
		check(absf(low - pet.global_position.y) < 0.09, "cat paws or body meet support %d (offset %.3f)" % [i, low - pet.global_position.y])
		var clear := true
		for z: float in [-0.10, 0.0, 0.10]:
			var p := pet.global_transform * Vector3(0, 0, z)
			for j in range(0, shop_triangles.size(), 3):
				if Geometry3D.segment_intersects_triangle(p + Vector3.UP * 0.036, p + Vector3.UP * 0.19,
						shop_triangles[j], shop_triangles[j + 1], shop_triangles[j + 2]) != null:
					clear = false
		check(clear, "cat body clears the shop geometry %d" % i)
	cat_check.free()
	check(in_shop == 4, "four cats in cat shop")
	view_at(shop["pos"] + Vector2(0, 0.9), float(shop["y"]) + 0.75, 9, 19, 11)
	await shot("6_cat_shop.png")
	if close_cat == null:
		return
	var p := close_cat.global_position
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 38
	cam.near = 0.025
	cam.position = p + Vector3(0.07, 0.40, 0.75)
	cam.look_at(p + Vector3(0.0, 0.33, 0.10))
	cam.make_current()
	await shot("5_cat_eyes_close.png")
	game.rig.cam.make_current()
	cam.queue_free()


func add_family(home: Dictionary, name_v: String) -> Array:
	var family := {"name": name_v, "n": 2, "cls": "plebs"}
	home["families"].append(family)
	home["pop"] += 2
	return game.people._make_family(name_v, 2, int(home["id"]), city.door_point(home), "plebs", family)


func label_contains(root: Node, value: String) -> bool:
	for label: Label in root.find_children("*", "Label", true, false):
		if String(label.tr(label.text)).contains(value):
			return true
	return false


func english() -> void:
	var home := city.place("house_pleb", Vector2(183, 126), 0.0, 0, 0, true)
	var res := add_family(home, "Квинкции")
	res[0]["m"]["pn"] = "Гней"
	var name_v := Residents.full_name(res[0]["m"], "Квинкции")
	var hud: Hud = game.hud
	I18n.set_lang("en")
	hud.root.show()
	hud.apply_reveal(3)
	hud.open_info(home)
	check(hud.info_box.find_child("family_0", true, false) != null and label_contains(hud.info_box, "Quinctii"), "English family list and house card")
	var slot := hud._worker_slot(0, "plebs", true, {"m": res[0]["m"], "family": "Квинкции"}, "")
	check(String(slot.tr(slot.tooltip_text)) == "Gnaeus Quinctius", "English worker slot")
	slot.free()
	check(I18n.t("Тиберий Юлий") == "Tiberius Iulius", "English Legion generator name")
	check(I18n.display_name("Златомир Щукин") == "Zlatomir Shchukin", "stored-name fallback")
	city._seen("Семья: %s" % "Квинкции", "family")
	var event: Dictionary = city.events.back()
	check(I18n.t(String(event["text"])).contains("Quinctii"), "English notification substitution")
	check(I18n.t(I18n.remember_name("Златомир Щукин")) == "Zlatomir Shchukin", "old hero name in UI")
	game.select_person({"r": res[0]})
	check(label_contains(hud.info_panel, "Gnaeus Quinctius"), "English dweller card " + name_v)
	var family_chip := false
	for button: Button in hud.info_panel.find_children("*", "Button", true, false):
		family_chip = family_chip or button.text.begins_with("Quinctia")
	check(family_chip, "English sibling name on dweller card")
	view_at(home["pos"], float(home["y"]) + 0.6, 0, 43, 26)
	await shot("7_en_names.png")
	I18n.set_lang("ru")
	check(People.name_of(res[0]) == "Гней Квинкций" and I18n.t("Тиберий Юлий") == "Тиберий Юлий", "Russian names unchanged")


func balance() -> void:
	var prior := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("balance_log="):
			prior = arg.substr(12)
	if prior != "":
		check_balance_log(prior)
		return
	game.queue_free()
	await frames(5)
	Streams.river_on = true
	get_viewport().disable_3d = true
	var pace := TestPace.new()
	pace.embedded = true
	add_child(pace)
	await pace.balance_finished
	check(pace.city13_rank_pop > 0 and pace.city13_rank_pop <= 520, "all ranks at 520 residents or fewer")
	check(pace.city13_last_build_pop <= 520, "last ordinary building unlocked by 520 residents")
	check(pace.fails == 0, "economy bot finished")



func check_balance_log(path: String) -> void:
	if not check(FileAccess.file_exists(path), "balance log"):
		return
	var max_pop := 0
	var ranks := {}
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		if not line.begins_with("CITY13 RANK "):
			continue
		var parts := line.split(" ", false)
		ranks[int(parts[2])] = true
		max_pop = maxi(max_pop, int(parts[4].trim_prefix("pop=")))
		print(line)
	check(ranks.size() == Defs.LEVELS.size() and max_pop <= 520, "all ranks at 520 residents or fewer")
