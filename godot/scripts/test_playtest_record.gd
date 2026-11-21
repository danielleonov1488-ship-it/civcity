extends RefCounted
## Замеры кадра и артефакты одного прогона.

var folder: String
var metrics := {}
var issues: Array[String] = []
var evidence := {}
var phases := {}
var phase := 0
var frame_titles: FileAccess
var next_frame := 0
var next_scan := 0
var last_frame := 0
var last_progress := 0
var dead_end := false
var busy := false
var pending: Array[int] = []
var arrows := {"city": {}, "fort": {}}
var tracks := {"city": {}, "fort": {}}
var modals := {}
var long_modals := {}
var clipped := {}
var russian := {}
var waits := {}
var latest_state := ""
var cyrillic := RegEx.create_from_string("[А-Яа-яЁё]")
var generated_name := RegEx.create_from_string("@[A-Za-z]+@[0-9]+")


func setup(path: String) -> bool:
	folder = path
	if DirAccess.make_dir_recursive_absolute(folder.path_join("shots/frames")) != OK:
		return false
	frame_titles = FileAccess.open(folder.path_join("shots/frames.tsv"), FileAccess.WRITE)
	return frame_titles != null


func metric(key: String, value: Variant) -> void:
	metrics[key] = value
	print("PLAYTEST METRIC %s=%s" % [key, value])


func issue(message: String) -> void:
	if not issues.has(message):
		issues.append(message)
		print("PLAYTEST ISSUE ", message)


func begin(number: int) -> void:
	phase = number
	var now := Time.get_ticks_msec()
	phases[phase] = {"start": now, "frames": 0, "duration": 0.0, "max_ms": 0.0,
		"slow": 0, "hitches": 0, "dead_ends": 0, "game_s": 0.0, "toasts": 0,
		"popups": 0, "bell": 0, "max_toasts": 0, "max_messages": 0}
	next_frame = now
	next_scan = now
	last_frame = 0
	progress("начало")


func progress(description: String) -> void:
	last_progress = Time.get_ticks_msec()
	latest_state = description
	dead_end = false


func clock(dt: float, speed: float) -> void:
	var now := Time.get_ticks_msec()
	var row: Dictionary = phases[phase]
	if last_frame > 0:
		var ms := float(Time.get_ticks_usec() - last_frame) / 1000.0
		row["frames"] += 1
		row["duration"] += ms
		row["max_ms"] = maxf(row["max_ms"], ms)
		row["slow"] += int(ms > 50.0)
		row["hitches"] += int(ms > 100.0)
	last_frame = Time.get_ticks_usec()
	row["game_s"] += dt * speed
	if not dead_end and now - last_progress > 60000:
		dead_end = true
		row["dead_ends"] += 1
		issue("p%d: нет продвижения больше 60 с (%s)" % [phase, latest_state])


func wait_over_ten(step: String, seconds: float) -> void:
	if waits.has(step):
		waits[step] = maxf(waits[step], seconds)
	else:
		waits[step] = seconds


func arrow(kind: String, key: String, shown: bool, pos: Vector2, side: Variant,
		glide: bool, completed: bool, ended: bool) -> void:
	var last: Dictionary = tracks[kind]
	var rows: Dictionary = arrows[kind]
	var prior: String = last.get("key", "")
	var current := key if shown else ""
	if prior != "" and prior != current:
		rows[prior]["hide"] += 1
	if shown:
		if not rows.has(current):
			rows[current] = {"show": 0, "hide": 0, "flips": 0, "max_px": 0.0,
				"frames": 0, "after_action": 0, "after_end": 0}
		var row: Dictionary = rows[current]
		row["show"] += int(prior != current)
		row["frames"] += 1
		row["after_action"] += int(completed)
		row["after_end"] += int(ended)
		# Сравниваем сторону даже после краткого скрытия того же указателя.
		if row.has("side") and row["side"] != side:
			row["flips"] += 1
		row["side"] = side
		if prior == current and not glide and not bool(last.get("glide")):
			row["max_px"] = maxf(row["max_px"], pos.distance_to(last["pos"]))
	tracks[kind] = {"key": current, "pos": pos, "glide": glide}


func notifications(toast_count: int, new_toasts: int, popup_count: int, new_popups: int, bell: int) -> void:
	var row: Dictionary = phases[phase]
	row["toasts"] += new_toasts
	row["popups"] += new_popups
	row["bell"] += bell
	row["max_toasts"] = maxi(row["max_toasts"], toast_count)
	row["max_messages"] = maxi(row["max_messages"], toast_count + popup_count)


func modal_windows(visible: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	for id: int in modals.keys():
		if not visible.has(id):
			modals.erase(id)
	for id: int in visible:
		if not modals.has(id):
			modals[id] = now
		var seconds := float(now - int(modals[id])) / 1000.0
		if seconds > 10.0:
			long_modals["p%d %s #%d" % [phase, visible[id], id]] = snappedf(seconds, 0.1)


func scan_text(root: Node, text_context: String, viewport: Rect2, english: bool) -> void:
	if Time.get_ticks_msec() < next_scan:
		return
	next_scan = Time.get_ticks_msec() + 5000
	for node: Node in root.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree() or control.self_modulate.a < 0.05:
			continue
		var rect := control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)
		var area := viewport
		var parent := control.get_parent()
		var scroll := false
		while parent is CanvasItem:
			if parent.modulate.a < 0.05:
				area = Rect2()
				break
			if parent is Control and (parent.clip_contents or parent is ScrollContainer):
				area = area.intersection(parent.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, parent.size))
				scroll = scroll or parent is ScrollContainer
			parent = parent.get_parent()
		if not area.intersects(rect):
			continue
		var caption := ""
		if control is Label:
			caption = translated(control, control.text)
			if caption.is_empty():
				continue
			var reason := _label_overflow(control, caption)
			if reason.is_empty() and not scroll and not area.grow(2.0).encloses(rect):
				reason = "за краем окна или обрезающего контейнера"
			if not reason.is_empty():
				clipped[_text_key(text_context, control, caption)] = reason
		elif control is RichTextLabel:
			caption = control.get_parsed_text()
		elif control is Button:
			caption = translated(control, control.text)
		elif control is LineEdit or control is TextEdit:
			caption = control.text
		if english and cyrillic.search(caption) != null:
			russian[_text_key(text_context, control, caption)] = true


func translated(control: Control, caption: String) -> String:
	# Label.text и Button.text хранят исходную фразу. Godot переводит её при отрисовке.
	if control.has_method("can_auto_translate") and not control.call("can_auto_translate"):
		return caption
	return I18n.t(caption)


func _text_key(context: String, control: Control, caption: String) -> String:
	var parent := control.get_parent()
	var location := str(control.name)
	while parent is Control:
		if not str(parent.name).begins_with("@"):
			location = str(parent.name) + "/" + location
			break
		parent = parent.get_parent()
	# Автоматические имена меняются при пересборке карточек.
	location = generated_name.sub(location, control.get_class(), true)
	return "%s / %s / %s" % [context, location, caption.replace("\n", " ↵ ")]


func _label_overflow(label: Label, caption: String) -> String:
	if label.get_visible_line_count() < label.get_line_count():
		return "строки %d/%d" % [label.get_visible_line_count(), label.get_line_count()]
	if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
		return ""
	var style := label.get_theme_stylebox("normal")
	var width := label.size.x - style.get_minimum_size().x
	var font := label.get_theme_font("font")
	var size := label.get_theme_font_size("font_size")
	if label.label_settings != null:
		if label.label_settings.font != null:
			font = label.label_settings.font
		size = label.label_settings.font_size
	for line: String in caption.split("\n"):
		var measured := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if measured > width + 2.0:
			return "ширина %.0f/%.0f px" % [measured, width]
	return ""


func frame(view: Viewport, title: String) -> void:
	var now := Time.get_ticks_msec()
	if now < next_frame or busy:
		return
	var number := phase
	var sec := int(float(now - int(phases[number]["start"])) / 1000.0)
	next_frame = int(phases[number]["start"]) + (sec + 1) * 1000
	var file := "p%d_%04d.jpg" % [number, sec]
	busy = true
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	if image != null and not image.is_empty():
		frame_titles.store_line("%s\t%d\t%d\t%s" % [file, number, sec, title.replace("\t", " ").replace("\n", " ")])
		frame_titles.flush()
		_encode(image, folder.path_join("shots/frames").path_join(file), false)
	else:
		issue("p%d: не удалось прочитать кадр %s" % [number, file])
	busy = false


func shot(view: Viewport, file: String) -> void:
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1920, 1080):
		issue("PNG %s: ожидалось 1920×1080" % file)
		return
	_encode(image, folder.path_join("shots").path_join(file + ".png"), true)


func _encode(image: Image, path: String, png: bool) -> void:
	for job: int in pending.duplicate():
		if WorkerThreadPool.is_task_completed(job):
			WorkerThreadPool.wait_for_task_completion(job)
			pending.erase(job)
	pending.append(WorkerThreadPool.add_task(func() -> void:
		var err: Error
		if png:
			err = image.save_png(path)
		else:
			image.resize(1280, 720, Image.INTERPOLATE_BILINEAR)
			err = image.save_jpg(path, 0.83)
		if err != OK:
			issue.call_deferred("Не записан снимок %s (%d)" % [path, err])
		elif png:
			print("PLAYTEST SHOT ", path), false, "PLAYTEST frame"))


func finish() -> void:
	for job: int in pending:
		WorkerThreadPool.wait_for_task_completion(job)
	pending.clear()
	frame_titles.close()
	var tutorial_waits := waits.keys()
	metric("tutorial.waits_over_10s", tutorial_waits.size())
	metric("ui.modals_over_10s", long_modals.size())
	metric("text.clipped_labels", clipped.size())
	metric("text.russian_in_english", russian.size())
	for step: String in tutorial_waits:
		issue("ожидание в обучении %s: %.1f с" % [step, waits[step]])
	if not long_modals.is_empty():
		issue("окна открыты дольше 10 с: %d" % long_modals.size())
	if not clipped.is_empty():
		issue("обрезанные или выходящие за границы Labels: %d" % clipped.size())
	if not russian.is_empty():
		issue("русский текст в английском интерфейсе: %d" % russian.size())
	for kind: String in arrows:
		var totals := {"flips": 0, "show": 0, "hide": 0, "max_px": 0.0, "after_action": 0, "after_end": 0}
		for key: String in arrows[kind]:
			var row: Dictionary = arrows[kind][key]
			row.erase("side")
			for field: String in totals:
				if field in ["show", "hide", "max_px"]:
					totals[field] = maxf(totals[field], row[field])
				else:
					totals[field] += row[field]
		for field: String in totals:
			var threshold: float = {"show": 1, "hide": 1, "max_px": 40}.get(field, 0)
			var value := snappedf(totals[field], 0.01)
			metric("arrow.%s.%s" % [kind, field], value)
			if float(totals[field]) > threshold:
				issue("стрелка %s: %s=%s (порог %s)" % [kind, field, value, threshold])
	for number: int in phases:
		var row: Dictionary = phases[number]
		var prefix := "p%d." % number
		var minimum := 1000.0 / maxf(1.0, row["max_ms"])
		var average := 1000.0 * float(row["frames"]) / maxf(1.0, row["duration"])
		var minutes := float(row["game_s"]) / 60.0
		# Настройки и проверки сохранения проходят на паузе.
		var has_game_time := minutes > 0.0 and number != 4
		metric(prefix + "fps_min", snappedf(minimum, 0.01) if row["frames"] > 0 else 0.0)
		metric(prefix + "fps_avg", snappedf(average, 0.01))
		metric(prefix + "frames_over_50ms", row["slow"])
		metric(prefix + "hitches_over_100ms", row["hitches"])
		metric(prefix + "dead_ends", row["dead_ends"])
		metric(prefix + "game_minutes", snappedf(minutes, 0.001))
		for field: String in ["toasts", "popups", "bell", "max_toasts", "max_messages"]:
			metric(prefix + field, row[field])
		for field: String in ["toasts", "popups", "bell"]:
			var rate: Variant = snappedf(float(row[field]) / minutes, 0.01) if has_game_time else "н/д"
			metric(prefix + field + "_per_game_min", rate)
		if row["max_toasts"] > 2:
			issue("p%d: больше двух плашек одновременно" % number)
		if has_game_time and float(row["toasts"]) / minutes > 2.0:
			issue("p%d: больше двух плашек на игровую минуту" % number)
		if average < 60.0:
			issue("p%d: средний FPS %.2f ниже 60" % [number, average])
		if row["hitches"] > 3:
			issue("p%d: %d кадров дольше 100 мс" % [number, row["hitches"]])
	evidence.merge({"arrows": arrows, "waits": waits, "modals": long_modals, "clipped": clipped, "russian": russian})
	var file := FileAccess.open(folder.path_join("metrics.json"), FileAccess.WRITE)
	if file == null:
		issue("Не записаны метрики")
	else:
		file.store_string(JSON.stringify({"metrics": metrics, "issues": issues, "evidence": evidence}, "\t"))
		file.close()
