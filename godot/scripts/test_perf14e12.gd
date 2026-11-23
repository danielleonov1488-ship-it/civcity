extends "res://scripts/test_perf14e11.gd"

const Perf14Timers = preload("res://scripts/perf14_timers.gd")


func _run(_mode: String) -> void:
	folder = str(A.get("out", ""))
	if folder == "" or city_src != OWNER:
		fail("нужны папка снимков и город владельца")
		_finish()
		return
	trace = FileAccess.open(folder.path_join("frames.tsv"), FileAccess.WRITE)
	if trace == null:
		fail("не открыт журнал кадров")
		_finish()
		return
	trace.store_line("action\tframe\twall_ms\tdraw\tspecialization\tshadow_us\tswaps\trender_cpu_ms\trender_gpu_ms")
	await _prepare()
	if A.has("materials"):
		await _night_materials()
	elif A.has("diagnose_e12"):
		await _watch("environment", func() -> void:
			game._set_hour(23.0, false)
			_lamps(false), 12, false)
		await _watch("lamps", func() -> void: _lamps(true), 12, false)
	else:
		_set_view(FAR)
		await frames(80)
		var edge := float(Land.SIZE) - 24.0
		_set_view([edge, 24.0, 155.0, 50.0, 130.0])
		await frames(120)
		_set_view(CENTER)
		await frames(90)
		await _watch("night", func() -> void: game._set_hour(23.0), 90)
		var fireflies := game.get_node("Breathe/Fireflies") as GPUParticles3D
		if not fireflies.emitting:
			fail("ночные светлячки не включились")
	if game._lamp_strength < 0.99 or not game.night_lights.any(func(l: OmniLight3D) -> bool: return l.visible):
		fail("ночные фонари не включились")
	game._set_hour(9.0)
	await frames(30)
	game.hud._open_settings()
	await frames(10)
	Gfx.swap_trace = FileAccess.open(folder.path_join("queue.tsv"), FileAccess.WRITE)
	if Gfx.swap_trace == null:
		fail("не открыт журнал очереди")
		_finish()
		return
	Gfx.swap_trace.store_line("usec\tframe\tevent\tqueue\tjobs\trequests\titem_usec\ttexture")
	var readbacks: int = Gfx.readbacks
	for pass_name: String in ["cold", "warm"]:
		await _switch("verylow", pass_name)
		await _switch("high", pass_name)
		if not Gfx._small.is_empty():
			fail("после возврата остались копии")
	if Gfx.readbacks != readbacks:
		fail("были чтения с видеокарты")
	Gfx.swap_trace.close()
	Gfx.swap_trace = null
	_finish()


func _lamps(show: bool) -> void:
	for light: OmniLight3D in game.night_lights:
		light.visible = show and light.light_energy > 0.02


func _night_materials() -> void:
	var camera: Camera3D = game.rig.cam
	var mask := camera.cull_mask
	var groups := {}
	var saved_layers := {}
	for node: GeometryInstance3D in game.find_children("*", "GeometryInstance3D", true, false):
		if node.get_viewport() != get_viewport() or not node.is_visible_in_tree() or node.layers & mask == 0:
			continue
		var tag := _night_group(node)
		if not groups.has(tag):
			groups[tag] = 1 << groups.size()
		saved_layers[node] = node.layers
		node.layers = groups[tag]
	camera.cull_mask = 0
	await frames(4)
	await _watch("sky", func() -> void: game._set_hour(23.0), 10, false)
	for tag: String in groups:
		var layer: int = groups[tag]
		await _watch(tag, func() -> void: camera.cull_mask = layer, 10, false)
	for node: GeometryInstance3D in saved_layers:
		if is_instance_valid(node):
			node.layers = saved_layers[node]
	camera.cull_mask = mask
	await _watch("night_all", func() -> void: pass, 15, false)


func _night_group(node: GeometryInstance3D) -> String:
	if node is GPUParticles3D or node is CPUParticles3D:
		return "particles"
	var mat := node.material_override
	var mesh: Mesh
	if node is MeshInstance3D:
		mesh = node.mesh
		if mat == null and mesh != null and mesh.get_surface_count() > 0:
			mat = node.get_active_material(0)
	elif node is MultiMeshInstance3D:
		mesh = node.multimesh.mesh if node.multimesh else null
	if mat == null and mesh != null and mesh.get_surface_count() > 0:
		mat = mesh.surface_get_material(0)
	if mat is ShaderMaterial and (mat as ShaderMaterial).shader != null:
		var shader: Shader = (mat as ShaderMaterial).shader
		var receiver: Game.ShadowDepth.Receiver = game.shadow_depth.receivers.get(node)
		if receiver != null:
			shader = receiver.materials.shader
		var tag := shader.resource_path.get_file().get_basename()
		if tag in ["land", "water", "foliage", "grass_carpet", "meadow_foliage", "crowd",
				"citizen_cloth", "cover", "stream_flow", "pool_water", "cat_fur", "tint"]:
			return tag
		return "other_shaders"
	if mat is BaseMaterial3D:
		if (mat as BaseMaterial3D).emission_enabled:
			return "emission"
		if (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return "transparent"
	return "opaque"


func _switch(quality: String, pass_name: String) -> void:
	var button: Button = game.hud.settings_panel.find_child("q_" + quality, true, false)
	var started := Time.get_ticks_usec()
	var last := started
	Perf14Timers.reset_frame()
	Perf14Timers.enabled = true
	button.pressed.emit()
	var press_ms := (Time.get_ticks_usec() - started) / 1000.0
	Perf14Timers.enabled = false
	print("PERF14E12 SWAP ", pass_name, " ", quality, " apply ", Perf14Timers.sections())
	var peak := 0.0
	var n := 0
	var deadline := started + (20_000_000 if A.has("diagnose_e12") else 10_000_000)
	while Gfx.swap_busy() and Time.get_ticks_usec() < deadline:
		await frames(1)
		var now := Time.get_ticks_usec()
		peak = maxf(peak, (now - last) / 1000.0)
		if now - last > 33_000:
			Gfx.swap_trace.store_csv_line(PackedStringArray([str(now), str(Engine.get_process_frames()),
				"long_frame", str(Gfx._queue.size()), str(Gfx._jobs.size()), str(Gfx._req.size()),
				str(now - last), ""]), "\t")
		last = now
		n += 1
	var ms := (Time.get_ticks_usec() - started) / 1000.0
	var busy := Gfx.swap_busy()
	print("PERF14E12 SWAP %s %s ms=%.2f press=%.2f peak=%.2f frames=%d busy=%s" %
		[pass_name, quality, ms, press_ms, peak, n, busy])
	Gfx.swap_trace.flush()
	if not A.has("diagnose_e12") and (busy or game.settings["quality"] != quality or (quality == "verylow" and ms > 10_000.0)):
		fail("смена качества " + quality)
	await frames(40)
	await RenderingServer.frame_post_draw
	var path := folder.path_join("%s_%s.png" % [pass_name, quality])
	if get_viewport().get_texture().get_image().save_png(path) != OK:
		fail("не сохранён снимок " + path)
	else:
		print("PERF14E12 SHOT ", path)


func fail(reason: String) -> void:
	fails += 1
	print("PERF14E12 FAIL ", reason)


func _finish() -> void:
	if trace != null:
		trace.close()
	print("PERF14E12 DONE fails=", fails)
	get_tree().quit(1 if fails else 0)
