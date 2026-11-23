extends "res://scripts/test_perf.gd"

const DRAW := Performance.PIPELINE_COMPILATIONS_DRAW
const SPECIALIZATION := Performance.PIPELINE_COMPILATIONS_SPECIALIZATION
const FAR := [192.0, 160.0, 15.0, 55.0, 240.0]
const CENTER := [210.0, 145.0, 15.0, 42.0, 60.0]
const GROUPS := ["horizon_no_shadow", "forest_no_shadow", "water_no_shadow",
	"grass", "river_foam", "remaining"]

var trace: FileAccess
var folder := ""
var _group_surfaces := {}


func _ready() -> void:
	A["mode"] = "perf14e11"
	A["warm"] = "90"
	A["n"] = "180"
	super._ready()


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
	if A.has("diagnose"):
		await _diagnose_zoom()
	elif not A.has("ab_only"):
		await _first_uses()
	if A.has("ab"):
		await _ab_switches()
	if A.has("mesh_ab"):
		await _ab_meshes()
	_finish()


func _prepare() -> void:
	while not game.ready_done:
		await frames(1)
	game.can_save = false
	game.hud.set_speed(0.0)
	game.weather.force = 0.0
	game.seasons.force_m = 6.0
	game._set_hour(9.0)
	game.rig.cine = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	_set_view(CENTER)
	await frames(120)
	print("PERF14E11 READY ", str(OS.get_user_data_dir()), " ", str(get_window().size),
		" ", RenderingServer.get_current_rendering_method(), " buildings=", game.city.buildings.size(),
		" residents=", game.people.residents.size())


func _set_view(view: Array) -> void:
	game.rig.set_view(Vector3(view[0], Land.BASE_Y, view[1]), view[2], view[3], view[4])


func _first_uses() -> void:
	# Первое отдаление повторяет точный переход из INTEG15.
	await _watch("zoom", func() -> void: _set_view(FAR), 80)
	var edge := float(Land.SIZE) - 24.0
	await _watch("corner", func() -> void: _set_view([edge, 24.0, 155.0, 50.0, 130.0]), 120)
	_set_view(CENTER)
	await frames(90)
	await _watch("night", func() -> void: game._set_hour(23.0), 90)
	if game._lamp_strength < 0.99 or not game.night_lights.any(func(l: OmniLight3D) -> bool: return l.visible):
		fail("ночные фонари не включились")
	game._set_hour(9.0)
	await frames(30)
	await _watch("rain", func() -> void: game.weather.force = 1.0, 360)
	if not game.weather.rain.emitting or game.weather.wet <= 0.0:
		fail("в дождь земля осталась сухой")
	await _watch("autumn", func() -> void: game.seasons.force_m = 9.5, 150)
	if game.seasons.now.x < 0.9 or not game.seasons.leaves.any(func(p: GPUParticles3D) -> bool: return p.emitting):
		fail("листопад не включился")


func _watch(label: String, action: Callable, count: int, check := true) -> void:
	await get_tree().process_frame
	var draw_before := int(Performance.get_monitor(DRAW))
	var spec_before := int(Performance.get_monitor(SPECIALIZATION))
	var then := Time.get_ticks_usec()
	var max_ms := 0.0
	var total := 0
	var specs := 0
	game.shadow_depth.profile = true
	action.call()
	for frame in count:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - then) / 1000.0
		var draw := int(Performance.get_monitor(DRAW))
		var spec := int(Performance.get_monitor(SPECIALIZATION))
		max_ms = maxf(max_ms, ms)
		total += draw - draw_before
		specs += spec - spec_before
		trace.store_line("%s\t%d\t%.3f\t%d\t%d\t%d\t%d\t%.3f\t%.3f" % [label, frame, ms,
			draw - draw_before, spec - spec_before, game.shadow_depth.update_usec, game.shadow_depth.switches,
			RenderingServer.viewport_get_measured_render_time_cpu(vp),
			RenderingServer.viewport_get_measured_render_time_gpu(vp)])
		draw_before = draw
		spec_before = spec
		then = now
	game.shadow_depth.profile = false
	trace.flush()
	print("PERF14E11 PIPELINE %s peak=%.2f draw=%d specialization=%d" % [label, max_ms, total, specs])
	if check and (max_ms > 50.0 or total != 0):
		fail("%s: %.2f мс, draw=%d" % [label, max_ms, total])
	await RenderingServer.frame_post_draw
	var path := folder.path_join(label + ".png")
	var image := get_viewport().get_texture().get_image()
	if image == null or image.save_png(path) != OK:
		fail("не сохранён снимок " + path)
	else:
		print("PERF14E11 SHOT ", path)


func _diagnose_zoom() -> void:
	var camera: Camera3D = game.rig.cam
	var restore := {}
	var original_mask := camera.cull_mask
	camera.cull_mask = 0
	_set_view(FAR)
	await frames(60)
	for node: GeometryInstance3D in game.find_children("*", "GeometryInstance3D", true, false):
		if node.get_viewport() != get_viewport():
			continue
		var index := _diagnostic_group(node)
		restore[node] = node.layers
		node.layers = 1 << index
		if not _group_surfaces.has(index):
			_group_surfaces[index] = {}
		var material: Material = node.material_override
		var mesh: Mesh
		if node is MeshInstance3D:
			mesh = node.mesh
		elif node is MultiMeshInstance3D:
			mesh = node.multimesh.mesh
		if material == null and mesh != null and mesh.get_surface_count() > 0:
			material = mesh.surface_get_material(0)
		if material is ShaderMaterial:
			var receiver: Game.ShadowDepth.Receiver = game.shadow_depth.receivers.get(node)
			var shader: Shader = receiver.materials.shader if receiver != null else material.shader
			if shader != null:
				_group_surfaces[index][shader.resource_path] = true
	for i in GROUPS.size():
		print("PERF14E11 PIPELINE group ", GROUPS[i], " ", _group_surfaces.get(i, {}))
		await _watch(GROUPS[i], func() -> void: camera.cull_mask = 1 << i, 15, false)
	for node: GeometryInstance3D in restore:
		if is_instance_valid(node):
			node.layers = restore[node]
	camera.cull_mask = original_mask
	_set_view(CENTER)
	await frames(90)


func _diagnostic_group(node: GeometryInstance3D) -> int:
	var receiver: Game.ShadowDepth.Receiver = game.shadow_depth.receivers.get(node)
	if receiver != null and receiver.distant:
		if node is MultiMeshInstance3D:
			return 1
		if node.name == &"RiverFar" or node.name == &"CityWater":
			return 2
		return 0
	elif game.grass.is_ancestor_of(node):
		return 3
	elif "Foam" in node.name:
		return 4
	return 5


func _ab_switches() -> void:
	# Переключаем тени и хвосты в одной сцене. Настройки сеток читаются при создании групп.
	game.weather.force = 0.0
	game.seasons.force_m = 6.0
	game._set_hour(9.0)
	for option: String in ["shadow", "prefix"]:
		for enabled: bool in [true, false, true, false]:
			if option == "shadow":
				game.shadow_depth.enabled = enabled
			else:
				Parts.trim_freed_slots = enabled
				for group: Dictionary in game.parts.groups.values():
					game.parts._sync_draw_prefix(group)
			for view: Array in [CENTER, FAR]:
				_set_view(view)
				await _measure("%s_%s_%s" % [option, "on" if enabled else "off", "center" if view == CENTER else "far"])
		game.shadow_depth.enabled = true
		Parts.trim_freed_slots = true
		for group: Dictionary in game.parts.groups.values():
			game.parts._sync_draw_prefix(group)


func _ab_meshes() -> void:
	for config: Array in [["shared_reused", true, true], ["shared", true, false],
			["copies", false, false], ["shared_repeat", true, false]]:
		game.queue_free()
		await game.tree_exited
		await frames(2)
		Game.perf14_share_meshes = config[1]
		Parts.reuse_tiled_sources = config[2]
		_boot("play")
		await _prepare()
		for view: Array in [CENTER, FAR]:
			_set_view(view)
			await _measure("%s_%s" % [config[0], "center" if view == CENTER else "far"])
	Game.perf14_share_meshes = true
	Parts.reuse_tiled_sources = true


func fail(reason: String) -> void:
	fails += 1
	print("PERF14E11 FAIL ", reason)


func _finish() -> void:
	if trace != null:
		trace.close()
	print("PERF14E11 DONE fails=", fails)
	get_tree().quit(1 if fails else 0)
