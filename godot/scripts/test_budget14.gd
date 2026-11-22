extends "res://scripts/test_perf14_base.gd"

const CAP := 90
const WARM := 90
const SAMPLE := 180
const GPU := 0
const PREP := 1
const DRAW := 2
const SHADOW := 3
const PRIMITIVES := 4
const OBJECTS := 5
const VRAM := 6
const ROOT_GPU := 7
const SUB_GPU := 8

var report: FileAccess
var failed := false
var frame_started := 0
var recording := false
var script_ms := PackedFloat32Array()


func _ready() -> void:
	setup_run()
	_run.call_deferred()


func _run() -> void:
	var file := out.path_join(str(args.get("report", "budget_before.md")))
	report = FileAccess.open(file, FileAccess.WRITE)
	if report == null or not await boot_city("owner", "high", false):
		print("BUDGET14 FAIL исходный город или отчёт недоступен")
		get_tree().quit(1)
		return
	get_window().size = Vector2i(1920, 1200)
	_line("# PERF14 · бюджет GPU")
	_line("")
	_line("Адаптер %s, окно %s. Медианы %d кадров после %d кадров разогрева, предел 90 кадров/с. GPU — сумма измерений root и активных SubViewport. CPU — скрипты, физика и подготовка рендера. Оценка ноутбука по множителям 7×, 9×, 11× для GPU и 1,3× для CPU." % [
		RenderingServer.get_video_adapter_name(), get_window().size, SAMPLE, WARM])
	_line("")
	_line("| Сцена | Графика | Вид | GPU мс | Root / sub мс | CPU скр. / ренд. мс | Draw / тени | Примитивы | Объекты | VRAM МиБ | UHD мс (7× / 9× / 11×) | CPU ×1,3 мс |")
	_line("|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
	get_tree().process_frame.connect(_frame_started)
	RenderingServer.frame_pre_draw.connect(_before_draw)
	Engine.max_fps = CAP
	game.hud.set_speed(0.0)
	await _city_views("Город владельца", OWNER_VIEWS)
	if not await boot_city("new", "high", false):
		print("BUDGET14 FAIL новый город не открыт")
		get_tree().quit(1)
		return
	get_window().size = Vector2i(1920, 1200)
	Engine.max_fps = CAP
	game.hud.set_speed(3.0)
	await get_tree().create_timer(100.0, false, false, true).timeout
	game.hud.set_speed(0.0)
	await _city_views("Новый · 300 секунд симуляции", NEW_VIEWS)
	await _battle_views()
	if not await boot_city("owner", "high", false):
		print("BUDGET14 FAIL город владельца не открыт для A/B")
		get_tree().quit(1)
		return
	get_window().size = Vector2i(1920, 1200)
	game.hud.set_speed(0.0)
	Engine.max_fps = CAP
	var probes := await _probes(file)
	_line("")
	_line("## A/B · город владельца")
	_line("")
	_line("Δ — медиана A минус медиана B, мс. Доли не складываются: эффекты используют общие проходы. Для двух или четырёх полос теней указаны переходы между режимами; API не даёт времени отдельных каскадов.")
	_line("")
	_line("| Графика | Вид | Изменение B | A GPU, мс | B GPU, мс | Δ, мс |")
	_line("|---|---|---|---:|---:|---:|")
	for q: String in QUALITIES:
		var rows: Array = probes[q]
		rows.sort_custom(func(a: Array, b: Array) -> bool: return a[3] - a[4] > b[3] - b[4])
		for row: Array in rows:
			_line("| %s | %s | %s | %.2f | %.2f | %+.2f |" % [Gfx.NAMES[q], row[0], row[1], row[3], row[4], row[3] - row[4]])
	report.close()
	print("BUDGET14 %s %s" % ["FAIL" if failed else "DONE", file])
	get_tree().quit(1 if failed else 0)


func _city_views(scenario: String, views: Array) -> void:
	for q: String in QUALITIES:
		set_quality(q)
		Engine.max_fps = CAP
		for index in VIEWS.size():
			set_view(views, index)
			var result := await _sample()
			_row(scenario, q, VIEWS[index], result)


func _battle_views() -> void:
	for q: String in QUALITIES:
		set_quality(q)
		Engine.max_fps = CAP
		var battle := open_battle(true)
		battle.set_process(false)
		await frames(10)
		if battle.sim == null:
			failed = true
			print("BUDGET14 FAIL нет симуляции боя ", q)
			battle.abort()
			return
		battle.fade.hide()
		for i in 420:
			battle._process(1.0 / 60.0)
		battle.set_process(true)
		for index in VIEWS.size():
			battle.battle_view.set_zoom([1.0, 0.88, 0.75][index])
			var result := await _sample()
			_row("Бой 16×16", q, VIEWS[index], result)
			if battle.views.size() != 32:
				failed = true
				print("BUDGET14 FAIL в бою не 32 бойца ", q)
		battle.abort()
		await frames(15)


func _frame_started() -> void:
	frame_started = Time.get_ticks_usec()


func _before_draw() -> void:
	if recording:
		script_ms.append((Time.get_ticks_usec() - frame_started) / 1000.0)


func _sample() -> Array:
	var rs := RenderingServer
	var root := get_viewport().get_viewport_rid()
	var viewports: Array[RID] = [root]
	for sub: SubViewport in game.find_children("*", "SubViewport", true, false):
		if sub.render_target_update_mode != SubViewport.UPDATE_DISABLED:
			viewports.append(sub.get_viewport_rid())
	for rid in viewports:
		rs.viewport_set_measure_render_time(rid, true)
	await frames(WARM)
	var samples := []
	for i in 9:
		samples.append(PackedFloat32Array())
	script_ms.clear()
	recording = true
	for i in SAMPLE:
		var gpu := 0.0
		var cpu := 0.0
		var root_gpu := 0.0
		var shadow := 0
		for rid in viewports:
			var viewport_gpu := rs.viewport_get_measured_render_time_gpu(rid)
			gpu += viewport_gpu
			if rid == root:
				root_gpu = viewport_gpu
			cpu += rs.viewport_get_measured_render_time_cpu(rid)
			shadow += rs.viewport_get_render_info(rid, rs.VIEWPORT_RENDER_INFO_TYPE_SHADOW, rs.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		var row := [gpu, cpu, rs.get_rendering_info(rs.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME) - shadow,
			shadow, rs.get_rendering_info(rs.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			rs.get_rendering_info(rs.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			rs.get_rendering_info(rs.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0, root_gpu, gpu - root_gpu]
		for j in row.size():
			var values: PackedFloat32Array = samples[j]
			values.append(row[j])
			samples[j] = values
		await get_tree().process_frame
	recording = false
	var result := []
	for values: PackedFloat32Array in samples:
		result.append(_median(values))
	result.append(_median(script_ms))
	if result[GPU] <= 0.0 or script_ms.size() != SAMPLE:
		failed = true
		print("BUDGET14 FAIL GPU или метки начала рендера недоступны: ", result[GPU], " / ", script_ms.size())
	return result


func _probes(file: String) -> Dictionary:
	var results := {}
	var raw := FileAccess.open(file.get_basename() + "_ab.tsv", FileAccess.WRITE)
	var vp := get_viewport()
	var env := game.env
	var sun := game.sun
	var attrs := game.rig.attrs
	for q: String in QUALITIES:
		set_quality(q)
		Engine.max_fps = CAP
		var tests := [
			[0, "Тени солнца выкл.", sun, &"shadow_enabled", false],
			[0, "Тени 2 полосы", sun, &"directional_shadow_mode", DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS],
			[0, "Тени 1 полоса", sun, &"directional_shadow_mode", DirectionalLight3D.SHADOW_ORTHOGONAL],
			[0, "SSAO выкл.", env, &"ssao_enabled", false],
			[0, "Glow выкл.", env, &"glow_enabled", false],
			[0, "Туман выкл.", env, &"fog_enabled", false],
			[0, "MSAA выкл.", vp, &"msaa_3d", Viewport.MSAA_DISABLED],
			[0, "FXAA выкл.", vp, &"screen_space_aa", Viewport.SCREEN_SPACE_AA_DISABLED],
			[0, "DOF выкл.", attrs, &"dof_blur_far_enabled", false],
			[0, "Вода скрыта", _shader_nodes(["water", "pool_water", "stream_flow"]), &"visible", false],
			[0, "Листва, трава и пшеница скрыты", [game.grass] + _shader_nodes(["foliage", "meadow_foliage", "wheat", "field_cover"]), &"visible", false],
			[2, "Дальние леса скрыты", game.far_near + game.far_forest, &"visible", false],
			[0, "Жители скрыты", [game.people, game.actors_root], &"visible", false],
			[0, "Детали зданий скрыты", _building_parts(), &"visible", false],
			[0, "Куски земли скрыты", game.chunk_nodes.values(), &"visible", false],
			[0, "Масштаб 3D ×0,8", vp, &"scaling_3d_scale", vp.scaling_3d_scale * 0.8],
		]
		var rows := []
		for index in [2, 0]:
			set_view(OWNER_VIEWS, index)
			var base := await _sample()
			for test: Array in tests:
				if test[0] != index:
					continue
				var targets: Array = test[2] if test[2] is Array else [test[2]]
				var old := {}
				for target: Object in targets:
					if target != null and target.get(test[3]) != test[4]:
						old[target] = target.get(test[3])
						target.set(test[3], test[4])
				if test[1] == "DOF выкл." and attrs.dof_blur_near_enabled:
					attrs.dof_blur_near_enabled = false
					targets = [attrs]
				else:
					targets = []
				var b := base
				if (not old.is_empty() or not targets.is_empty()) and (test[3] != &"directional_shadow_mode" or sun.shadow_enabled):
					b = await _sample()
				for target: Object in old:
					target.set(test[3], old[target])
				if not targets.is_empty():
					attrs.dof_blur_near_enabled = true
				rows.append([VIEWS[index], test[1], q, base[GPU], b[GPU]])
				if raw:
					raw.store_line("%s	%s	%s	%.4f	%.4f" % [q, VIEWS[index], test[1], base[GPU], b[GPU]])
					raw.flush()
				await frames(6)
				print("BUDGET14 AB %s %s %s %.2f -> %.2f" % [q, VIEWS[index], test[1], base[GPU], b[GPU]])
		results[q] = rows
	if raw:
		raw.close()
	return results


func _shader_nodes(names: Array) -> Array:
	var nodes := []
	for n: GeometryInstance3D in game.find_children("*", "GeometryInstance3D", true, false):
		var materials: Array[Material] = [n.material_override]
		var mesh: Mesh
		if n is MeshInstance3D:
			mesh = n.mesh
		elif n is MultiMeshInstance3D and n.multimesh != null:
			mesh = n.multimesh.mesh
		if mesh:
			for i in mesh.get_surface_count():
				materials.append(n.get_active_material(i) if n is MeshInstance3D else mesh.surface_get_material(i))
		for mat in materials:
			if mat is ShaderMaterial and mat.shader != null and mat.shader.resource_path.get_file().get_basename() in names:
				nodes.append(n)
				break
	return nodes


func _building_parts() -> Array:
	var nodes := []
	for key: String in game.parts.groups:
		var tail := key.get_slice("|", key.get_slice_count("|") - 1)
		if tail.contains(",") and not tail.begins_with("b") and tail.split(",")[0].is_valid_int():
			continue                         # ?????? ???????
		var group: Dictionary = game.parts.groups[key]
		for sub: Dictionary in group["subs"]:
			nodes.append(sub["mmi"])
	return nodes


static func _median(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 0.0
	values.sort()
	return values[values.size() / 2]


func _row(scenario: String, q: String, view: String, m: Array) -> void:
	_line("| %s | %s | %s | %.2f | %.2f / %.2f | %.2f / %.2f | %d / %d | %d | %d | %.0f | %.1f / %.1f / %.1f | %.1f |" % [
		scenario, Gfx.NAMES[q], view, m[GPU], m[ROOT_GPU], m[SUB_GPU], m[9], m[PREP], m[DRAW], m[SHADOW],
		m[PRIMITIVES], m[OBJECTS], m[VRAM], m[GPU] * 7.0, m[GPU] * 9.0, m[GPU] * 11.0, (m[9] + m[PREP]) * 1.3])


func _line(value: String) -> void:
	report.store_line(value)
	report.flush()
	print(value)
