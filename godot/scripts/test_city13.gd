extends Node3D

const OUTPUT := "D:/CivCity/.work/stage7/city13b/"
const PREVIOUS_TOP := "D:/CivCity/.work/stage7/city13/shots/3_fields_sizes.png"
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


func capture() -> Image:
	await frames(10)
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func save_shot(img: Image, file: String) -> void:
	var path := out + file
	if check(img.save_png(path) == OK, "save " + file):
		print("CITY13 SHOT ", path)


func shot(file: String) -> void:
	save_shot(await capture(), file)


func compare_top(after: Image) -> void:
	var before := Image.load_from_file(PREVIOUS_TOP)
	if not check(before != null and not before.is_empty(), "previous CITY13 top screenshot"):
		return
	before.convert(after.get_format())
	before.resize(after.get_width(), after.get_height(), Image.INTERPOLATE_LANCZOS)
	var size := after.get_size()
	var pair := Image.create_empty(size.x * 2 + 4, size.y, false, after.get_format())
	pair.fill(Color("f6e3aa"))
	pair.blit_rect(before, Rect2i(Vector2i.ZERO, size), Vector2i.ZERO)
	pair.blit_rect(after, Rect2i(Vector2i.ZERO, size), Vector2i(size.x + 4, 0))
	save_shot(pair, "5_before_after.png")


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
	# Владелец 21.11: прежний арочный мост у ворот «и так был норм» — оставлен как был; тут только снимок для сверки.
	var label := "river" if river else "stream"
	if not check(game.land.bridges.size() >= 1, label + " bridge on the main road"):
		return
	var br: Dictionary = game.land.bridges[0]
	var p: Vector2 = br["pos"]
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


func grain(b: Dictionary, name_v: String) -> int:
	var n := 0
	for part: Array in city.blueprint(b).parts:
		n += int(part[0] == name_v)
	return n


func batched_wheat(b: Dictionary, name_v: String) -> int:
	var n := 0
	var visual: Dictionary = game.visuals.get(b["id"], {})
	for h: Array in visual.get("h", []):
		var group: Dictionary = h[0]
		if not String(group["key"]).begins_with(name_v + "|") or group["subs"].is_empty():
			continue
		var mm: MultiMesh = group["subs"][0]["mm"]
		var xf := mm.get_instance_transform(int(h[1]))
		if absf(xf.basis.determinant()) > 0.001:
			n += 1
	return n


func shader_and_lod() -> void:
	var ranges := {}
	for name_v: String in [CatCivic.WHEAT, CatCivic.WHEAT_DENSE]:
		var mesh := Parts._special_mesh(name_v)
		var mat := mesh.surface_get_material(0) as ShaderMaterial
		if check(mat != null and mat.shader != null, name_v + " uses a shader"):
			var code := mat.shader.code
			check(code.contains("TIME") and code.contains("VERTEX += wind") and code.contains("height * height"),
				name_v + " wind bends tips and anchors roots")
		for group: Dictionary in game.parts.groups.values():
			if String(group["key"]).begins_with(name_v + "|"):
				var batch: MultiMeshInstance3D = group["subs"][0]["mmi"]
				ranges[name_v] = batch.visibility_range_end
				check(batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, name_v + " has no shadow pass")
				break
	check(float(ranges.get(CatCivic.WHEAT, 0)) > float(ranges.get(CatCivic.WHEAT_DENSE, 0))
		and float(ranges.get(CatCivic.WHEAT_DENSE, 0)) > 0, "distant batches retain only the sparse layer")


func gold_share(img: Image, b: Dictionary) -> float:
	var half := Vector2(City.field_size(b)) * Catalog.FIELD_TILE * 0.5 - Vector2.ONE * 0.18
	var xf := city.xf(b)
	var cam := game.rig.cam
	# Проекция камеры в логических пикселях, PNG — в физических пикселях окна.
	var center := cam.unproject_position(cam.global_position - cam.global_basis.z * 10.0)
	var pixel_scale := Vector2(img.get_size()) / (center * 2.0)
	var outline := PackedVector2Array()
	for edge: Vector2 in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)]:
		outline.append(cam.unproject_position(xf * Vector3(edge.x, 0.025, edge.y)) * pixel_scale)
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for v: Vector2 in outline:
		bounds = bounds.expand(v)
	var sample := Rect2i(bounds).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var total := 0
	var gold := 0
	for y in range(sample.position.y, sample.end.y, 2):
		for x in range(sample.position.x, sample.end.x, 2):
			if not Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), outline):
				continue
			total += 1
			var c := img.get_pixel(x, y)
			# Золото и солома — жёлтые; коричневая почва и оранжевая глина сюда не входят.
			if c.h >= 0.105 and c.h <= 0.183 and c.s >= 0.23 and c.v >= 0.47:
				gold += 1
	print("CITY13 GOLD ROI ", sample, " samples=", total, " scale=", pixel_scale)
	check(total >= 1000, "enough pixels in the projected field")
	return float(gold) / maxf(total, 1)


func render_time() -> float:
	await frames(16)
	await RenderingServer.frame_post_draw
	var start := Time.get_ticks_usec()
	for i in 90:
		await RenderingServer.frame_post_draw
	return float(Time.get_ticks_usec() - start) / 90000.0


func field_perf() -> void:
	# Отдельный пул позволяет скрыть все десять полей без пересчёта земли и симуляции.
	var perf_parts := Parts.new()
	game.parts.get_parent().add_child(perf_parts)
	perf_parts.tint_split = game.parts.tint_split
	var city_parts := game.parts
	var old_anim := game.build_anim
	game.parts = perf_parts
	game.build_anim = false
	city.bulk = true
	var placed: Array[Dictionary] = []
	var size := Vector2i(6, 6)
	for z in range(70, 100, 7):
		for x in range(52, 96, 7):
			var start := plot("farm", size, x * 2.5, (x + 2) * 2.5, z * 2.5, (z + 2) * 2.5)
			if start == Vector2.INF:
				continue
			var at := start - Vector2.ONE * 0.4 + Vector2(size) * Catalog.FIELD_TILE * 0.5
			var b := city.place("farm", at, 0.0, 0, 0, true, size)
			if not b.is_empty():
				placed.append(b)
			if placed.size() == 10:
				break
		if placed.size() == 10:
			break
	city.bulk = false
	game.build_anim = old_anim
	game.parts = city_parts
	if not check(placed.size() == 10, "performance fixture adds ten 6x6 fields"):
		return
	var bounds := Rect2(placed[0]["pos"], Vector2.ZERO)
	for b: Dictionary in placed:
		bounds = bounds.expand(b["pos"])
	view_at(bounds.get_center(), 2.0, 0, 68, 99)
	for b: Dictionary in placed:
		var center := game.rig.cam.unproject_position(city.xf(b).origin)
		check(get_viewport().get_visible_rect().has_point(center), "performance field on screen")
		check(batched_wheat(b, CatCivic.WHEAT) == 144 and batched_wheat(b, CatCivic.WHEAT_DENSE) == 432,
			"6x6 clumps survived MultiMesh growth")
	for i in 1800:
		var icons_drawing := false
		for child: Node in game.hud.get_children():
			if child is SubViewport and child.size == Vector2i(200, 168):
				icons_drawing = true
				break
		if not icons_drawing and game.land.dirty.is_empty() and game.land.dirty_walk.is_empty():
			break
		await frames(1)
	check(game.land.dirty.is_empty() and game.land.dirty_walk.is_empty(), "land finished rebuilding before timing")
	var old_cap := Engine.max_fps
	var old_vsync := DisplayServer.window_get_vsync_mode()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await frames(60)
	var before: Array[float] = []
	var after: Array[float] = []
	for visible_v: bool in [false, true, true, false, false, true, true, false]:
		perf_parts.visible = visible_v
		var ms := await render_time()
		(after if visible_v else before).append(ms)
	Engine.max_fps = old_cap
	DisplayServer.window_set_vsync_mode(old_vsync)
	perf_parts.visible = true
	before.sort()
	after.sort()
	var off := (before[1] + before[2]) * 0.5
	var on := (after[1] + after[2]) * 0.5
	var delta := on - off
	print("CITY13 PERF fields=%d ms_before=%.3f ms_after=%.3f delta=%.3f batches=%d" % [
		placed.size(), off, on, delta, perf_parts.groups.size()])
	print("CITY13 PERF SAMPLES hidden=", before, " shown=", after)
	check(delta <= 1.0, "ten fields add at most 1.0 ms (%.3f ms)" % delta)


func fields() -> void:
	var small := drag_plot("farm", Vector2i(2, 2), plot("farm", Vector2i(2, 2), 145, 180, 132, 171))
	var big := drag_plot("farm", Vector2i(5, 4), plot("farm", Vector2i(5, 4), 145, 180, 132, 171))
	if small.is_empty() or big.is_empty():
		return
	check(grain(small, CatCivic.WHEAT) == 16 and grain(small, CatCivic.WHEAT_DENSE) == 48
		and grain(big, CatCivic.WHEAT) == 80 and grain(big, CatCivic.WHEAT_DENSE) == 240,
		"wheat clumps scale with area at both distances")
	check(city.job_max(small) == 1 and city.job_max(big) == 4, "rounded field job slots")
	check(city.build_price("farm", Vector2i(5, 4)) == 5.0 * city.build_price("farm", Vector2i(2, 2)), "area cost ratio")
	for i in 360:
		if game.visuals.has(small["id"]) and game.visuals.has(big["id"]):
			break
		await frames(1)
	check(batched_wheat(small, CatCivic.WHEAT) == 16 and batched_wheat(big, CatCivic.WHEAT_DENSE) == 240,
		"both density layers are present in MultiMesh")
	shader_and_lod()
	await get_tree().create_timer(2.0).timeout
	var mid: Vector2 = (small["pos"] + big["pos"]) * 0.5
	view_at(mid, float(big["y"]), -10, 63, 26)
	var top := await capture()
	save_shot(top, "1_fields_top.png")
	compare_top(top)
	view_at(big["pos"], float(big["y"]) + 0.4, 18, 33, 11)
	await shot("2_field_close.png")
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
	var size := Vector2i(6, 6)
	var large := drag_plot("farm", size, plot("farm", size, 200, 232, 166, 190))
	if not large.is_empty():
		for i in 360:
			if game.visuals.has(large["id"]):
				break
			await frames(1)
		await get_tree().create_timer(2.0).timeout
		view_at(large["pos"], float(large["y"]), -10, 63, 34)
		var share := gold_share(await capture(), large)
		print("CITY13 GOLD size=6x6 camera=34 share=%.1f%%" % (share * 100.0))
		check(share >= 0.70, "golden pixels cover at least 70% of the field")
		view_at(large["pos"], float(large["y"]), -10, 63, 84)
		var far := await capture()
		var far_share := gold_share(far, large)
		print("CITY13 GOLD size=6x6 camera=84 share=%.1f%%" % (far_share * 100.0))
		check(far_share >= 0.70, "distant field remains gold")
		save_shot(far, "3_field_far.png")
	var grove_size := Vector2i(3, 2)
	var vine_size := Vector2i(2, 3)
	var grove := drag_plot("grove", grove_size, plot("grove", grove_size, 150, 180, 156, 203))
	var vines := drag_plot("vineyard", vine_size, plot("vineyard", vine_size, 150, 180, 156, 203))
	if not grove.is_empty() and not vines.is_empty():
		for i in 360:
			if game.visuals.has(grove["id"]) and game.visuals.has(vines["id"]):
				break
			await frames(1)
		await get_tree().create_timer(2.0).timeout
		var center: Vector2 = (grove["pos"] + vines["pos"]) * 0.5
		view_at(center, float(grove["y"]), 170, 63, 26)
		await shot("4_grove_vineyard.png")
	await field_perf()


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
	await shot("8_cat_eyes_close.png")
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
