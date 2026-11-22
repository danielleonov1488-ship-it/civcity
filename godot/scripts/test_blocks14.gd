extends "res://scripts/test_perf.gd"
## Сравнение исходного города и кварталов на одной видеокарте, без записи в сохранение владельца.

const STAGE := "D:/CivCity/.work/stage7/perf14c"
const SHOT_VIEWS := [
	["1_close_before_after", 205.0, 140.0, 30.0, 35.0, 22.0, 9.0],
	["2_center_before_after", 210.0, 145.0, 15.0, 42.0, 60.0, 9.0],
	["3_far_before_after", 192.0, 160.0, 15.0, 55.0, 240.0, 9.0],
	["4_night_before_after", 205.0, 140.0, 30.0, 35.0, 22.0, 22.0],
]


func _ready() -> void:
	Parts.blocks_on = false
	for arg: String in OS.get_cmdline_user_args():
		if arg == "mode=regress" or arg == "mode=changes":
			Parts.blocks_on = true
		if arg.begins_with("block_m="):
			Parts.block_size = clampf(float(arg.get_slice("=", 1)), 24.0, 64.0)
		if arg == "lod=0":
			Parts.block_lods = false
	if "blocks=0" in OS.get_cmdline_user_args():
		Parts.blocks_on = false
	super._ready()


func fail(message: String) -> void:
	fails += 1
	print("BLOCKS14 FAIL ", message)


func _run(mode: String) -> void:
	await _ready_game()
	if mode == "regress":
		if not await _wait_blocks():
			get_tree().quit(1)
			return
		await super._run("regress")
		return
	if mode == "changes":
		if await _wait_blocks():
			await _changes()
		_done()
		return
	if city_src.is_empty():
		fail("owner city missing")
		_done()
		return
	print("BLOCKS14 GPU %s | %s | buildings %d" % [RenderingServer.get_video_adapter_name(), str(get_window().size), game.city.buildings.size()])
	for entry: Array in _views(VIEWS_REGRESS):
		if entry[0] == "far":
			_view(entry)
	await frames(16)
	_inventory()
	var before := await _samples("A")
	await _tiled_draws(before["high/center"])
	var images := await _captures()
	_unfreeze()
	await _reboot()
	Parts.blocks_on = true
	_boot("play")
	await _ready_game()
	if not await _wait_blocks():
		_done()
		return
	_summary()
	var after := await _samples("B")
	for key: String in before:
		var a: Dictionary = before[key]
		var b: Dictionary = after[key]
		print("BLOCKS14 AB %s | DC %d -> %d / %d -> %d | tris %d -> %d / %d -> %d | rcpu %.2f -> %.2f | GPU %.2f -> %.2f | VRAM %d -> %d" % [
			key, a["vis_d"], b["vis_d"], a["sh_d"], b["sh_d"], a["vis_p"], b["vis_p"], a["sh_p"], b["sh_p"],
			a["rcpu"], b["rcpu"], a["gpu"], b["gpu"], a["video_mib"], b["video_mib"]])
		if int(b["video_mib"]) - int(a["video_mib"]) > 150:
			fail("video memory: " + key)
	_gate(before, after)
	var updated := await _captures()
	for key: String in images:
		var before_img: Image = images[key]
		var after_img: Image = updated[key]
		var result := _same(before_img, after_img)
		print("BLOCKS14 PIXEL %s mean %.5f c24 %d" % [key, result["mean"], result["c24"]])
		_pair(key, before_img, after_img)
	_unfreeze()
	if A.get("changes", "1") != "0":
		await _changes()
	_done()


func _ready_game() -> void:
	while not game.ready_done:
		await frames(5)
	game.can_save = false
	game.settings["autosave"] = false
	game.settings["quality_user"] = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _perf13_wait_icons()
	vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	Engine.max_fps = 0


func _reboot() -> void:
	var old: Node = game
	old.queue_free()
	await old.tree_exited
	await frames(12)


func _wait_blocks() -> bool:
	var parts: Parts = game.parts
	if parts.blocks == null:
		return not Parts.blocks_on
	var until := Time.get_ticks_msec() + 90000
	while not parts.blocks.settled() and Time.get_ticks_msec() < until:
		await frames(4)
	if not parts.blocks.settled():
		fail("block rebuild timed out")
		return false
	return true


func _summary() -> void:
	var blocks: Parts.Blocks = game.parts.blocks
	var merged := 0
	var pieces := 0
	var lods := 0
	for block: Dictionary in blocks.blocks.values():
		merged += (block["merged"] as Array).size()
		lods += int(block["lods"])
		var node: Node3D = block["draw"]
		if node != null:
			pieces += node.get_child_count()
	print("BLOCKS14 MESH size=%.0f blocks=%d committed=%d source_groups=%d surfaces=%d lods=%d budget_mib=%.1f longest_main_ms=%.3f" % [
		blocks.size, blocks.blocks.size(), blocks.builds, merged, pieces, lods, blocks.bytes / 1048576.0, blocks.peak_us / 1000.0])
	if merged == 0 or pieces == 0 or (blocks.use_lod and lods == 0):
		fail("no block geometry or LODs")


func _samples(tag: String) -> Dictionary:
	var results := {}
	for quality: String in ["high", "verylow"]:
		_quality(quality)
		await frames(3)
		RenderingServer.viewport_set_measure_render_time(vp, true)
		for view: Array in _views(VIEWS_REGRESS):
			if view[0] == "wide":
				continue
			_view(view)
			var key := quality + "/" + String(view[0])
			var sample := await _measure("B14 %s %s" % [tag, key])
			sample["video_mib"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576
			results[key] = sample
	return results


func _gate(before: Dictionary, after: Dictionary) -> void:
	var a: Dictionary = before["high/center"]
	var b: Dictionary = after["high/center"]
	if int(b["vis_d"]) > 700 or int(b["sh_d"]) > 1200:
		fail("draw calls target")
	if float(b["rcpu"]) > float(a["rcpu"]) * 0.5:
		fail("CPU preparation target")
	if float(after["high/far"]["gpu"]) > float(before["high/far"]["gpu"]) * 0.7:
		fail("high far GPU target")
	for key: String in ["verylow/center", "verylow/far"]:
		if float(after[key]["gpu"]) > float(before[key]["gpu"]) * 0.65:
			fail("verylow GPU target: " + key)


func _tiled_draws(baseline: Dictionary) -> void:
	_quality("high")
	_view(_views(VIEWS_REGRESS)[0])
	var tiled := RegEx.create_from_string("\\|-?\\d+,-?\\d+$")
	var changed: Array[MultiMeshInstance3D] = []
	for key: String in game.parts.groups:
		if tiled.search(key) == null:
			continue
		for sub: Dictionary in game.parts.groups[key]["subs"]:
			var node: MultiMeshInstance3D = sub["mmi"]
			if node.visible:
				node.hide()
				changed.append(node)
	await frames(15)
	var visible := RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var shadow := RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	print("BLOCKS14 TILED high center | draw delta %d / %d | rest %d / %d" % [int(baseline["vis_d"]) - visible, int(baseline["sh_d"]) - shadow, visible, shadow])
	for node: MultiMeshInstance3D in changed:
		node.show()


func _captures() -> Dictionary:
	_quality("high")
	_freeze()
	var out := {}
	for shot: Array in SHOT_VIEWS:
		_view(["", shot[1], shot[2], shot[3], shot[4], shot[5]])
		game._set_hour(float(shot[6]))
		await frames(60)
		out[shot[0]] = await _snap()
	return out


func _pair(name: String, a: Image, b: Image) -> void:
	a.convert(Image.FORMAT_RGB8)
	b.convert(Image.FORMAT_RGB8)
	var w := a.get_width()
	var h := a.get_height()
	var da := a.get_data()
	var db := b.get_data()
	for i in da.size():
		da[i] = mini(255, absi(da[i] - db[i]) * 8)
	var diff := Image.create_from_data(w, h, false, Image.FORMAT_RGB8, da)
	var canvas := Image.create_empty(w * 3, h, false, Image.FORMAT_RGB8)
	var rect := Rect2i(0, 0, w, h)
	canvas.blit_rect(a, rect, Vector2i.ZERO)
	canvas.blit_rect(b, rect, Vector2i(w, 0))
	canvas.blit_rect(diff, rect, Vector2i(w * 2, 0))
	_save_block_shot(canvas, name)


func _save_block_shot(img: Image, name: String) -> void:
	var dir: String = A.get("shots", STAGE + "/shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(name + ".png")
	if img.save_png(path) == OK:
		print("BLOCKS14 SHOT ", path)
	else:
		fail("cannot save screenshot " + path)


func _inventory() -> void:
	var f := FileAccess.open(STAGE + "/groups.tsv", FileAccess.WRITE)
	if f == null:
		fail("cannot write group inventory")
		return
	f.store_line("group\tsub\tsurface\tlive\tvertices_per_instance\tbase_triangles_per_instance\tfar_base_triangles_max\tnormal_calls_max\tshadow_calls_per_cascade_max\tlods\tmaterial\talbedo\tnormal")
	var groups: Dictionary = game.parts.groups
	var count := 0
	var subs := 0
	var triangles := []
	var camera: Camera3D = game.rig.cam
	var planes := camera.get_frustum()
	for key: String in groups:
		var g: Dictionary = groups[key]
		var n: int = int(g["used"]) - (g["free"] as Array).size()
		if n <= 0:
			continue
		count += 1
		var sid := 0
		for sub: Dictionary in g["subs"]:
			subs += 1
			sid += 1
			var mmi: MultiMeshInstance3D = sub["mmi"]
			var mesh := mmi.multimesh.mesh as ArrayMesh
			if mesh == null:
				var primitive: Mesh = mmi.multimesh.mesh
				for s in primitive.get_surface_count():
					var arrays := primitive.surface_get_arrays(s)
					var v: int = arrays[Mesh.ARRAY_VERTEX].size()
					var p: int = arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null else v
					_inventory_line(f, key, sid, s, n, v, p / 3, 0, mmi, 0, primitive.surface_get_material(s))
				continue
			var far := _frustum_aabb(planes, mmi.global_transform * mmi.get_aabb())
			var importer := ImporterMesh.from_mesh(mesh)
			var total := 0
			for s in mesh.get_surface_count():
				var v := mesh.surface_get_array_len(s)
				var p := maxi(mesh.surface_get_array_index_len(s), v) / 3
				var far_triangles := p * n if far else 0
				total += far_triangles
				var lods := importer.get_surface_lod_count(s)
				_inventory_line(f, key, sid, s, n, v, p, far_triangles, mmi, lods, mesh.surface_get_material(s))
			if total > 0:
				triangles.append([key, sid, total])
	f.close()
	triangles.sort_custom(func(a: Array, b: Array) -> bool: return int(a[2]) > int(b[2]))
	print("BLOCKS14 INVENTORY groups=%d live_groups=%d live_subs=%d alias=%d" % [groups.size(), count, subs, game.parts.alias.size()])
	for row: Array in triangles.slice(0, 20):
		print("BLOCKS14 FAR base_triangles_max %d | %s | sub %d" % [row[2], row[0], row[1]])


func _inventory_line(file: FileAccess, key: String, sid: int, s: int, n: int, v: int, p: int, far: int, mmi: MultiMeshInstance3D, lods: int, mat: Material) -> void:
	var base := mat as BaseMaterial3D
	var albedo := base.albedo_texture if base != null else null
	var normal := base.normal_texture if base != null else null
	file.store_line("%s\t%d\t%d\t%d\t%d\t%d\t%d\t1\t%d\t%d\t%s\t%s\t%s" % [
		key, sid, s, n, v, p, far, int(mmi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF), lods,
		"%s:%s" % [mat.get_class(), mat.resource_name] if mat != null else "", albedo.resource_path if albedo != null else "",
		normal.resource_path if normal != null else ""])


static func _frustum_aabb(planes: Array[Plane], box: AABB) -> bool:
	for plane: Plane in planes:
		var outside := true
		for i in 8:
			if not plane.is_point_over(box.get_endpoint(i)):
				outside = false
				break
		if outside:
			return false
	return true


func _changes() -> void:
	var parts: Parts = game.parts
	var blocks := parts.blocks
	var city: City = game.city
	game.hud.set_speed(0.0)
	var before := _signature()
	_quality("high")
	var played := await _batch_changes(city, blocks)
	if played.is_empty():
		return
	for id: int in played:
		if not blocks.buildings.has(id):
			fail("added building missing from block %d" % id)
	var h: Dictionary = city.buildings[played[0]]
	var key: Vector2i = blocks.buildings[played[0]]["key"]
	var revision: int = blocks.blocks[key]["rev"]
	var other := {}
	for pos: Vector2i in blocks.blocks:
		if pos != key:
			other[pos] = blocks.blocks[pos]["rev"]
	game.legion_cover(self, true)
	await frames(3)
	var built: int = blocks.builds
	city.recolor(h)
	await get_tree().create_timer(0.3).timeout
	if blocks.builds != built or not blocks.suspended:
		fail("block rebuild ran behind the fort")
	game.legion_cover(self, false)
	if int(blocks.blocks[key]["rev"]) <= revision:
		fail("recolour did not invalidate its block")
	for pos: Vector2i in other:
		if blocks.blocks[pos]["rev"] != other[pos]:
			fail("recolour changed an unrelated block")
	if not await _wait_blocks():
		return
	city.money = maxf(city.money, 100000)
	h["families"] = [{"name": "Test", "n": 2, "cls": "plebs"}]
	h["pop"] = 2
	h["happy"] = 100
	h["coming"] = 0
	var level: int = h["tier"]
	if not city.buy_floor(h, true) or int(h["tier"]) != level + 1:
		fail("floor upgrade: " + city.can_buy_floor(h))
	if not await _wait_blocks():
		return
	var selected: Dictionary = city.buildings[played[1]]
	var finished: Dictionary = city.buildings[played[2]]
	game.build_anim = true
	city.bulk = true
	var at: Vector2 = h["pos"] + Vector2(0, -9)
	var construction := city.place("house_pleb", at, 0.0, 1, 3, true)
	city.bulk = false
	game.build_anim = false
	game.select_building(selected)
	game.hud.visible = false
	game.rig.cine = true
	_view(["", at.x + 9.0, at.y + 6.0, 5.0, 40.0, 36.0])
	await frames(15)
	var sid := int(selected["id"])
	var nid := int(construction["id"])
	var fid := int(finished["id"])
	if not game._grow_live.has(nid) or blocks.buildings.has(nid) or not blocks.holds.has(sid) or not blocks.buildings.has(fid):
		fail("construction / selection / finished exclusion")
	_save_block_shot(await _snap(), "5_highlight_construction")
	game.select_building({})
	game.hud.visible = true
	game.rig.cine = false
	game._grow_cancel(nid)
	city.bulk = true
	city.remove(construction, false, true)
	for id: int in played:
		city.remove(city.buildings[id], false, true)
	city.bulk = false
	if not await _wait_blocks():
		return
	if before != _signature():
		fail("building set after demolition")
	_check_rows()
	var data: Dictionary = game._save_data()
	var path := GamePaths.save_dir().path_join("city.json")
	var saved := FileAccess.open(path, FileAccess.WRITE)
	if saved == null:
		fail("save roundtrip")
		return
	saved.store_string(JSON.stringify(data))
	saved.close()
	var saved_set := _signature()
	var saved_geometry := _geometry()
	await _reboot()
	_boot("play")
	await _ready_game()
	if await _wait_blocks():
		_check_rows()
		if saved_set != _signature() or saved_geometry != _geometry():
			fail("building set or block geometry after save/load")
	print("BLOCKS14 CHANGE add=30 recolour=1 floor=%d demolish=31 save_load=%d" % [
		int(h["tier"]) - level, int(saved_set == _signature() and saved_geometry == _geometry())])


func _batch_changes(city: City, blocks: Parts.Blocks) -> Array[int]:
	var ids: Array[int] = []
	var last := Time.get_ticks_usec()
	var max_us := 0
	var edits_us := 0
	blocks.peak_us = 0
	city.bulk = true
	for i in 30:
		var at := Vector2(230.0 + (i % 6) * 8.0, 91.0 + (i / 6) * 8.0)
		var start := Time.get_ticks_usec()
		var b := city.place("house_pleb", at, 0.0, i % 7, i % Defs.PALETTE.size(), true)
		edits_us = maxi(edits_us, Time.get_ticks_usec() - start)
		if b.is_empty():
			fail("place %d" % i)
			continue
		ids.append(int(b["id"]))
		await frames(1)
		var now := Time.get_ticks_usec()
		max_us = maxi(max_us, now - last)
		last = now
	city.bulk = false
	var until := Time.get_ticks_msec() + 90000
	var commit_frame_us := 0
	while not blocks.settled() and Time.get_ticks_msec() < until:
		await frames(1)
		var now := Time.get_ticks_usec()
		max_us = maxi(max_us, now - last)
		if blocks.last_commit_frame == Engine.get_process_frames() - 1:
			commit_frame_us = maxi(commit_frame_us, now - last)
		last = now
	print("BLOCKS14 HITCH edits=%d maxframe=%.3f commit_frame=%.3f sync_edit=%.3f block_main=%.3f" % [
		ids.size(), max_us / 1000.0, commit_frame_us / 1000.0, edits_us / 1000.0, blocks.peak_us / 1000.0])
	if not blocks.settled():
		fail("30 placements: block rebuild timed out")
	if blocks.peak_us > 8000 or commit_frame_us > 25000:
		fail("rebuild hitch exceeded budget")
	return ids


func _check_rows() -> void:
	var blocks: Parts.Blocks = game.parts.blocks
	var rows := 0
	for id: int in blocks.buildings:
		if not game.city.buildings.has(id) or not game.visuals.has(id):
			fail("stale building in a block: %d" % id)
			continue
		for h: Array in game.visuals[id]["h"]:
			var g: Dictionary = h[0]
			if g.has("rows"):
				rows += 1
				if not g["rows"].has(h[1]) or not is_same(g["block"], blocks.buildings[id]):
					fail("missing row for building %d" % id)
	var active := 0
	for block: Dictionary in blocks.blocks.values():
		for g: Dictionary in (block["groups"] as Dictionary).values():
			active += (g["rows"] as Dictionary).size()
	if rows != active:
		fail("stale block rows: %d vs %d" % [rows, active])


func _geometry() -> Dictionary:
	var out := {}
	for id: int in game.visuals:
		var rows := []
		for h: Array in game.visuals[id]["h"]:
			var g: Dictionary = h[0]
			if g.has("rows"):
				var row: Array = g["rows"][h[1]]
				rows.append([g["key"], str(row[0]), row[1]])
		out[id] = rows
	return out


func _signature() -> Dictionary:
	var out := {}
	for id: int in game.city.buildings:
		var b: Dictionary = game.city.buildings[id]
		out[id] = [b["type"], b["tier"], b["variant"], b["color"], b["pos"], b["yaw"]]
	return out


func _done() -> void:
	print("BLOCKS14 DONE fails=%d" % fails)
	get_tree().quit(1 if fails else 0)
