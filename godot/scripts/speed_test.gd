extends Node

const Report = preload("res://scripts/speed_test_report.gd")
const DURATION := Report.SEGMENT_SEC * 4.0
const WARM_SEC := 2.0
const REPORT_DIR := "user://speed_test"

class View:
	var point: Vector2
	var yaw: float
	var pitch: float
	var distance: float

	func _init(p: Vector2, y: float, tilt: float, d: float) -> void:
		point = p.clamp(Vector2(4.0, 4.0), Vector2(Land.SIZE - 4.0, Land.SIZE - 4.0))
		yaw = y
		pitch = tilt
		distance = d

class VerdictMedal extends Control:
	const ART := {
		"smooth": preload("res://assets/ui/ai/icons/check.png"),
		"heavy": preload("res://assets/ui/ai/icons/close.png"),
	}
	var grade := "unknown"

	func _ready() -> void:
		custom_minimum_size = Vector2(82, 82)
		mouse_filter = MOUSE_FILTER_IGNORE

	func set_grade(value: String) -> void:
		grade = value
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		if ART.has(grade):
			draw_texture_rect(ART[grade], Rect2(center - Vector2(41, 41), Vector2(82, 82)), false)
			return
		var color := Color("d29b30") if grade == "stutter" else Color("98795b")
		draw_circle(center + Vector2(0, 3), 37, Color("d9c39e"), true, -1.0, true)
		draw_circle(center, 37, Color("805831"), true, -1.0, true)
		draw_circle(center, 35, Color("eec883"), true, -1.0, true)
		draw_circle(center, 30, color.darkened(0.27), true, -1.0, true)
		draw_circle(center - Vector2(0, 2), 28, color, true, -1.0, true)
		draw_arc(center, 26, PI * 1.1, PI * 1.9, 24, Color(1, 1, 1, 0.25), 2.0, true)
		var ink := Color("fff4d3")
		if grade == "stutter":
			draw_line(center + Vector2(0, -12), center + Vector2(0, 2), ink, 7.0, true)
			for y in [-12, 2, 12]:
				draw_circle(center + Vector2(0, y), 3.5, ink, true, -1.0, true)
		else:
			draw_line(center + Vector2(-10, 0), center + Vector2(10, 0), ink, 6.0, true)


var game
var active := false
var report_text := ""
var report_path := ""

var _saved: Dictionary
var _info: Dictionary
var _views: Array[View] = []
var _samples: Array[Report.Samples] = []
var _vp: RID
var _warm_at := 0
var _start_at := 0
var _frame_at := 0
var _last_draw := 0
var _last_logic_ms := 0.0
var _logic_ms := 0.0
var _segment := -1
var _last_segment := -1
var _render_sample := false
var _last_render_sample := false
var _finishing := false
var _countdown := -1
var _driver_thread: Thread
var _driver := ""

var _layer: CanvasLayer
var _overlay: ColorRect
var _running: PanelContainer
var _counter: Label
var _result: PanelContainer
var _verdict: Label
var _medal: VerdictMedal
var _fps: Label
var _recommendation: Label
var _apply: Button
var _copy: Button
var _feedback: Label
var _recommended := ""


func _ready() -> void:
	process_priority = 1000000
	set_process(false)
	set_process_unhandled_input(false)
	set_process_unhandled_key_input(false)


func can_start() -> bool:
	return game.ready_done and game.mode in ["play", "new"] and not active and (_layer == null or not _layer.visible) and not game.rig.cine \
		and not game.legion_city_hidden() and LegionBattle.current == null and (game.photo == null or not game.photo.on) \
		and not (game.painting or game.fence_drag or game.floor_drag or game.field_from != Vector2.INF) \
		and game.moving.is_empty() and game.moving_nature.is_empty() \
		and DisplayServer.get_name() != "headless" and _window_ok()


func start() -> void:
	if not can_start():
		return
	if _layer == null:
		_build_ui()
	var hud: Hud = game.hud
	var rig: CameraRig = game.rig
	var gfx: Gfx = game.gfx
	_saved = {"view": rig.capture_view(), "speed": game.speed, "hud": hud.visible,
		"rig_process": rig.is_processing(), "rig_input": rig.is_processing_unhandled_input(),
		"fps_layer": gfx._fps_box.visible, "measure": gfx._measure, "size": get_window().size}
	_info = _system_info()
	if _driver_thread == null and _driver.is_empty():
		_driver_thread = Thread.new()
		if _driver_thread.start(OS.get_video_adapter_driver_info) != OK:
			_driver_thread = null
	_views = _route()
	_samples.clear()
	for i in Report.SEGMENTS.size():
		_samples.append(Report.Samples.new())
	report_text = ""
	report_path = ""
	_start_at = 0
	_warm_at = 0
	_last_draw = 0
	_segment = -1
	_last_segment = -1
	_render_sample = false
	_last_render_sample = false
	_finishing = false
	_countdown = -1
	active = true
	hud.settings_panel.hide()
	hud.set_guidance_suspended(true)
	hud.hide()
	gfx._fps_box.hide()
	game.speed = 0.0
	rig.set_process(false)
	rig.set_process_unhandled_input(false)
	_show_view(0, 0, 0.0)
	_vp = get_viewport().get_viewport_rid()
	gfx._set_measure(true)
	_counter.text = "Готовим проверку…"
	_overlay.color = Color.TRANSPARENT
	_running.show()
	_result.hide()
	_layer.show()
	get_tree().process_frame.connect(_begin_frame)
	RenderingServer.frame_pre_draw.connect(_before_draw)
	set_process(true)
	set_process_unhandled_input(true)
	set_process_unhandled_key_input(true)


func _window_ok() -> bool:
	return DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_MINIMIZED and not game.minimized_test \
		and (DisplayServer.window_is_focused() or OS.get_environment("CIVCITY_TESTWIN") == "hidden")


func _begin_frame() -> void:
	_frame_at = Time.get_ticks_usec()


func _process(_dt: float) -> void:
	if not _window_ok() or get_window().size != _saved["size"]:
		_stop()
		return
	_poll_driver()
	var now := Time.get_ticks_usec()
	if _start_at == 0:
		if Gfx.swap_busy() or game._clock_busy:
			_warm_at = 0
			return
		if _warm_at == 0:
			_warm_at = now
		if now - _warm_at < WARM_SEC * 1000000.0:
			return
		_start_at = now
		_info["scale"] = get_viewport().scaling_3d_scale
		_info["citizens"] = int(game.city.stats.get("pop", 0))
	var t := (now - _start_at) / 1000000.0
	if t >= DURATION:
		_finishing = true
		return
	var left := ceili(DURATION - t)
	if left != _countdown:
		_countdown = left
		_counter.text = I18n.t("Идёт проверка… %d с") % left
	_segment = int(t / Report.SEGMENT_SEC)
	var phase := fmod(t, Report.SEGMENT_SEC)
	# Таймеры рендера приходят с задержкой. У стыков учитываем длительность кадра, а CPU/GPU — после четверти секунды.
	_render_sample = phase >= 0.25
	var k := smoothstep(0.0, 3.0, phase)
	match _segment:
		0: _show_view(0, 1, 0.2 * k)
		1: _show_view(0, 1, 0.2 + 0.8 * k)
		2: _show_view(1, 2, k)
		3:
			if phase < 3.0:
				_show_view(2, 3, k)
			else:
				_show_view(3, 4, smoothstep(3.0, Report.SEGMENT_SEC, phase))
	_logic_ms = (Time.get_ticks_usec() - _frame_at) / 1000.0


func _before_draw() -> void:
	var now := Time.get_ticks_usec()
	if _last_segment >= 0 and now > _last_draw:
		var gpu := 0.0
		var cpu := 0.0
		if _last_render_sample:
			gpu = RenderingServer.viewport_get_measured_render_time_gpu(_vp)
			cpu = _last_logic_ms + RenderingServer.get_frame_setup_time_cpu() \
				+ RenderingServer.viewport_get_measured_render_time_cpu(_vp)
		_samples[_last_segment].add((now - _last_draw) / 1000.0, cpu, gpu)
	_last_draw = now
	_last_logic_ms = _logic_ms
	_last_render_sample = _render_sample
	_last_segment = -1 if _finishing else _segment
	if _finishing:
		_complete.call_deferred()


func _disconnect_measure() -> void:
	active = false
	set_process(false)
	get_tree().process_frame.disconnect(_begin_frame)
	RenderingServer.frame_pre_draw.disconnect(_before_draw)


func _restore() -> void:
	_disconnect_measure()
	var gfx: Gfx = game.gfx
	var rig: CameraRig = game.rig
	rig.restore_view(_saved["view"])
	rig.set_process(_saved["rig_process"])
	rig.set_process_unhandled_input(_saved["rig_input"])
	game.speed = _saved["speed"]
	game.hud.visible = _saved["hud"]
	gfx._fps_box.visible = _saved["fps_layer"]
	gfx._set_measure(_saved["measure"])
	_running.hide()


func _stop() -> void:
	_restore()
	_close()


func _complete() -> void:
	if not active:
		return
	_restore()
	_poll_driver()
	_info["driver"] = _driver if not _driver.is_empty() else "—"
	var all := Report.Samples.new()
	for sample in _samples:
		all.merge(sample)
	var total := all.stats()
	_report_saved(Report.format_report(_info, _samples, total))
	_show_result(total, _info["quality"])


func _show_result(stats: Dictionary, quality: String) -> void:
	var answer := Report.verdict(stats, quality)
	_recommended = answer["quality"]
	_medal.set_grade(answer["grade"])
	_fps.text = str(roundi(float(stats["fps"]))) if not stats.is_empty() else "—"
	_verdict.text = answer["text"]
	_recommendation.text = I18n.t("Советуем: %s") % I18n.t(Gfx.NAMES[_recommended])
	_apply.visible = _recommended != quality
	_feedback.text = "Не удалось сохранить отчёт" if report_path.is_empty() else ""
	_overlay.color = Color(0.12, 0.08, 0.05, 0.28)
	var hud: Hud = game.hud
	hud._snug(_result)
	_result.show()


func _report_saved(value: String) -> void:
	report_text = value
	if DirAccess.make_dir_recursive_absolute(REPORT_DIR) != OK:
		return
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := REPORT_DIR.path_join("%s_%d_%d.txt" % [stamp, OS.get_process_id(), Time.get_ticks_usec()])
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file and file.store_string(report_text):
		file.close()
		report_path = path


func _poll_driver() -> void:
	if _driver_thread != null and not _driver_thread.is_alive():
		var parts: PackedStringArray = _driver_thread.wait_to_finish()
		_driver = " ".join(parts).strip_edges()
		_driver_thread = null


func _exit_tree() -> void:
	if active:
		_disconnect_measure()
	if _driver_thread != null:
		_driver_thread.wait_to_finish()


func _system_info() -> Dictionary:
	var ram := int(OS.get_memory_info().get("physical", -1))
	var screen := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	var size := get_window().size
	var cap := Engine.max_fps
	var vsync := DisplayServer.window_get_vsync_mode()
	var api := RenderingServer.get_current_rendering_driver_name()
	var gfx: Gfx = game.gfx
	# «Плавность» из PERF14-b: во время маршрута масштаб зафиксирован, настройка игрока сохраняется.
	var smooth := "unavailable"
	if gfx.has_method("_configure_smooth"):
		smooth = "on" if bool(game.settings.get("smooth", true)) else "off"
	return {"version": _version(), "os": OS.get_name() + " " + OS.get_version(),
		"gpu": Gfx.adapter(), "adapter": "%s / %s %s / %s" % [RenderingServer.get_video_adapter_vendor(),
			api, RenderingServer.get_video_adapter_api_version(), RenderingServer.get_current_rendering_method()],
		"cpu": OS.get_processor_name(), "cores": OS.get_processor_count(), "ram": "%.1f GiB" % (ram / 1073741824.0) if ram > 0 else "—",
		"screen": "%dx%d" % [screen.x, screen.y], "window": "%dx%d" % [size.x, size.y], "scale": get_viewport().scaling_3d_scale,
		"cap": str(cap) if cap > 0 else "none", "vsync": ["off", "on", "adaptive", "mailbox"][vsync],
		"quality": str(game.settings.get("quality", "high")), "smooth": smooth,
		"buildings": game.city.buildings.size(), "citizens": int(game.city.stats.get("pop", 0))}


static func _version() -> String:
	var build := 0
	var version := str(ProjectSettings.get_setting("application/config/version", "?"))
	if OS.has_feature("macos"):
		build = MacUpdate.our_build()
	elif OS.has_feature("template"):
		var dir := OS.get_executable_path().get_base_dir()
		for name: String in ["manifest.json", "version.json"]:
			var path := dir.path_join(name)
			if not FileAccess.file_exists(path):
				continue
			var data = JSON.parse_string(FileAccess.get_file_as_string(path))
			if data is Dictionary and int(data.get("build", 0)) > 0:
				build = int(data["build"])
				version = str(data.get("version", version))
				break
	return "%s (build %s)" % [version, str(build) if build > 0 else "dev" if OS.has_feature("editor") else "—"]


func _route() -> Array[View]:
	var city: City = game.city
	var land: Land = game.land
	var density := {}
	var center := Vector2.ZERO
	var weight_sum := 0.0
	var span := Rect2()
	var chunk_size := Land.CH * Land.CELL
	for b: Dictionary in city.buildings.values():
		if bool(b.get("over", false)) or city.def(b)["kind"] == "decor":
			continue
		var p: Vector2 = b["pos"]
		var weight := 2.0 + float(b.get("pop", 0))
		var chunk := Vector2i(p / chunk_size)
		density[chunk] = float(density.get(chunk, 0.0)) + weight
		span = Rect2(p, Vector2.ZERO) if weight_sum == 0.0 else span.expand(p)
		center += p * weight
		weight_sum += weight
	center = center / weight_sum if weight_sum > 0.0 else Land.START
	var street := _street(land, density, center, chunk_size)
	var axis := (street[1] - street[0]).normalized()
	var side_yaw := 45.0 + rad_to_deg(atan2(axis.x, axis.y))
	var wide := clampf(maxf(span.size.x, span.size.y) * 0.55, 56.0, 92.0)
	return [View.new(center, 15.0, 36.0, 24.0), View.new(center, 25.0, 49.0, wide), View.new(center, 36.0, 56.0, 128.0),
		View.new(street[0], side_yaw, 34.0, 23.0), View.new(street[1], side_yaw, 34.0, 23.0)]


func _street(land: Land, density: Dictionary, center: Vector2, chunk_size: float) -> PackedVector2Array:
	# Ищем дорогу рядом с наибольшим числом домов и жителей, чтобы маршрут не зависел от движения прохожих.
	var chunks := land.road_chunks.keys()
	chunks.sort()
	var point := Vector2.INF
	var best := -INF
	for chunk: Vector2i in chunks:
		var mid := (Vector2(chunk) + Vector2(0.5, 0.5)) * chunk_size
		var score := -mid.distance_to(center) * 0.02 + float(density.get(chunk, 0.0))
		for y in range(-1, 2):
			for x in range(-1, 2):
				score += float(density.get(chunk + Vector2i(x, y), 0.0))
		if score <= best:
			continue
		var nearest := INF
		for y in range(1, Land.CH, 4):
			for x in range(1, Land.CH, 4):
				var p := land.cell_center(chunk.x * Land.CH + x, chunk.y * Land.CH + y)
				var d := p.distance_squared_to(mid)
				if d < nearest and land.is_road(p):
					point = p
					nearest = d
		if nearest < INF:
			best = score
	if not point.is_finite():
		return PackedVector2Array([center - Vector2(10, 0), center + Vector2(10, 0)])
	var axis: Vector2 = game._road_axis(point, 7.0)
	if axis == Vector2.ZERO:
		axis = Vector2.RIGHT if land.is_road(point + Vector2(3, 0)) else Vector2.DOWN
	var ends := PackedVector2Array()
	for sign_dir: float in [-1.0, 1.0]:
		var end := point
		for m in range(1, 16):
			var p := point + axis * (sign_dir * m)
			if not land.is_road(p):
				break
			end = p
		ends.append(end)
	return ends if ends[0].distance_to(ends[1]) >= 4.0 else PackedVector2Array([point - axis * 6.0, point + axis * 6.0])


func _show_view(from: int, to: int, weight: float) -> void:
	var a := _views[from]
	var b := _views[to]
	var p := a.point.lerp(b.point, weight)
	var yaw := rad_to_deg(lerp_angle(deg_to_rad(a.yaw), deg_to_rad(b.yaw), weight))
	var rig: CameraRig = game.rig
	rig.set_view(Vector3(p.x, 0.0, p.y), yaw, lerpf(a.pitch, b.pitch, weight), lerpf(a.distance, b.distance, weight))


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo() and event.keycode == KEY_ESCAPE:
		if active:
			_stop()
		else:
			_close()
	get_viewport().set_input_as_handled()


func _unhandled_input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()


func _close() -> void:
	_layer.hide()
	game.hud.set_guidance_suspended(false)
	set_process_unhandled_input(false)
	set_process_unhandled_key_input(false)


func _apply_quality() -> void:
	game.settings["quality"] = _recommended
	game.settings["quality_user"] = true
	game.save_settings()
	_apply.hide()


func _copy_report() -> void:
	DisplayServer.clipboard_set(report_text)
	_feedback.text = "Отчёт скопирован"


func _build_ui() -> void:
	var hud: Hud = game.hud
	_layer = CanvasLayer.new()
	_layer.layer = 30
	add_child(_layer)
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.theme = hud.theme_main
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.mouse_force_pass_scroll_events = false
	_layer.add_child(_overlay)
	_running = hud._panel(_overlay, "bar")
	_running.name = "SpeedTestRunning"
	hud._put(_running, Control.PRESET_CENTER_TOP, Vector2(0, 22))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_running.add_child(row)
	_counter = hud._label("", 20, true)
	_counter.custom_minimum_size.x = 202.0
	_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_counter)
	row.add_child(_button("Стоп", "", _stop))
	_result = hud._panel(_overlay, "panel", 0.0, 16.0)
	_result.name = "SpeedTestResult"
	hud._put(_result, Control.PRESET_CENTER, Vector2.ZERO)
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = 320.0
	content.add_theme_constant_override("separation", 7)
	_result.add_child(content)
	var title := hud._label("Проверка скорости", 18, true, Hud.C_SOFT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var hero := HBoxContainer.new()
	hero.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_theme_constant_override("separation", 14)
	content.add_child(hero)
	_medal = VerdictMedal.new()
	_medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hero.add_child(_medal)
	var readout := VBoxContainer.new()
	readout.add_theme_constant_override("separation", 0)
	readout.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hero.add_child(readout)
	var figure := HBoxContainer.new()
	figure.add_theme_constant_override("separation", 6)
	readout.add_child(figure)
	_fps = hud._label("", 49, true)
	figure.add_child(_fps)
	var unit := hud._label("кадров/с", 16, true, Hud.C_SOFT)
	unit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	figure.add_child(unit)
	_verdict = hud._label("", 20, false, Hud.C_INK, hud.font_title)
	readout.add_child(_verdict)
	var recommendation := HBoxContainer.new()
	recommendation.alignment = BoxContainer.ALIGNMENT_CENTER
	recommendation.add_theme_constant_override("separation", 9)
	content.add_child(recommendation)
	_recommendation = hud._label("", 19)
	_recommendation.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	recommendation.add_child(_recommendation)
	_apply = _button("Включить", "", _apply_quality)
	recommendation.add_child(_apply)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 8)
	content.add_child(actions)
	_copy = _button("Скопировать отчёт", "scroll", _copy_report)
	actions.add_child(_copy)
	actions.add_child(_button("Закрыть", "", _close))
	_feedback = hud._label("", 16, false, Hud.C_SOFT)
	_feedback.custom_minimum_size.y = 18.0
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_feedback)


func _button(text: String, icon_name: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	if not icon_name.is_empty():
		button.icon = game.hud.ico(icon_name, 22)
	button.pressed.connect(action)
	game.hud._hook(button)
	return button
