extends Node3D
## Общие проверки UNI6/TUTOR6. Никаких записей в профиль игрока.

const MapBadge = preload("res://scripts/map_badge.gd")
var game: Game
var city: City
var hud: Hud
var fails := 0
var tag := "UNI6"
var out := ""


func boot_run(prefix: String, folder: String, profiles := "D:/CivCity/.work/stage5/uni6/profiles") -> bool:
	tag = prefix
	out = folder
	var lang := "ru"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=").trim_suffix("/") + "/"
		if arg.begins_with("lang="):
			lang = arg.trim_prefix("lang=")
	var profile := "%s/%s_%d_%d" % [profiles, tag, int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	if not check(DirAccess.make_dir_recursive_absolute(profile) == OK and DirAccess.make_dir_recursive_absolute(out) == OK, "isolated output directories"):
		return false
	OS.set_environment("CIVCITY_SAVEDIR", profile)
	OS.set_environment("CIVCITY_NOLOGIN", "1")
	OS.set_environment("CIVCITY_NOMINPAUSE", "1")
	OS.set_environment("CIVCITY_HEROSCREEN", "0")
	Game.sandbox = false
	Game.boot = {"new": "1", "hour": "11", "nologin": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	game.can_save = false
	add_child(game)
	for i in 18000:
		if game.ready_done:
			break
		await get_tree().process_frame
	if not check(game.ready_done, "ready_done timeout"):
		return false
	game.settings["autosave"] = false
	game.settings["advisor_off"] = false
	game.speed = 0.0
	game.build_anim = false
	city = game.city
	hud = game.hud
	city.auto_hire = false
	city.cozy_v = 1
	city.money = 100000.0
	I18n.set_lang(lang)
	return true


func _process(_dt: float) -> void:
	if is_instance_valid(game):
		game.can_save = false


func frames(n := 8) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, why: String) -> bool:
	if not ok:
		fails += 1
		print(tag + " FAIL " + why)
	return ok


func shot(file: String) -> void:
	await frames(10)
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	if check(get_viewport().get_texture().get_image().save_png(out + file) == OK, "save " + file):
		print(tag + " SHOT " + out + file)


func place(type: String, at: Vector2) -> Dictionary:
	var b := city.place(type, at, 0.0, 0, 0, true)
	if check(not b.is_empty(), "place " + type):
		var door := city.door_point(b)
		city.land.paint_line(door - Vector2(3, 0), door + Vector2(3, 0), 2.0, Land.Kind.ROAD, true)
		city.compute()
	return b


func clear_guidance() -> void:
	hud.advisor_panel.hide()
	hud.guidance_queue.clear()
	hud._clear(hud.notes_box)
	hud._tip_next = 0
	hud._ptr_shown = {}


func texture_ok(texture: Texture2D, path: String) -> void:
	if texture == null:
		return
	check(not texture.resource_path.contains("assets/ui/ai/icons"), path + " painted icon " + texture.resource_path)
	if not Defs.PROF_ON:
		check(not texture.resource_path.contains("/prof/"), path + " profession texture")


func inspect_panel(panel: Control) -> void:
	check(panel.is_visible_in_tree(), String(panel.name) + " visible")
	inspect_node(panel)


func inspect_node(node: Control) -> void:
	if not node.is_visible_in_tree() or node.is_queued_for_deletion():
		return
	var path := String(node.get_path())
	if not Defs.PROF_ON:
		check(not node.has_meta("profession") and not node.has_meta("profession_role") and not String(node.name).begins_with("profession_"), path + " profession node")
	if node is TextureRect:
		texture_ok((node as TextureRect).texture, path)
	if node is Button:
		var b := node as Button
		texture_ok(b.icon, path)
		if b.text != "":
			var wanted := b.get_theme_font("font").get_string_size(I18n.t(b.text), HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
			var style := b.get_theme_stylebox("normal")
			wanted += style.get_content_margin(SIDE_LEFT) + style.get_content_margin(SIDE_RIGHT)
			if b.icon != null:
				wanted += b.get_theme_constant("icon_max_width") + b.get_theme_constant("h_separation")
			check(wanted <= b.size.x + 2.0 or b.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, path + " button text fits")
		for state: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
			style_ok(b.get_theme_stylebox(state), path + " " + state)
	if node is Panel or node is PanelContainer:
		style_ok(node.get_theme_stylebox("panel"), path)
	if node is Label:
		var label := node as Label
		if label.text != "":
			var line_height := label.get_line_height()
			if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
				var wanted := label.get_theme_font("font").get_multiline_string_size(I18n.t(label.text), HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size"))
				check(wanted.x <= label.size.x + 2.0 or label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, path + " label width")
			check(label.get_line_count() * line_height <= label.size.y + 3.0 or (label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS and label.size.y >= line_height), path + " label height")
	for child: Node in node.get_children():
		if child is Control:
			inspect_node(child as Control)


func style_ok(style: StyleBox, path: String) -> void:
	if style is StyleBoxFlat:
		var color := (style as StyleBoxFlat).bg_color
		check(color.a < 0.15 or not (color.r > color.g * 1.35 and color.r > color.b * 1.2), path + " red/burgundy background")
	elif style is StyleBoxTexture:
		var texture := (style as StyleBoxTexture).texture
		check(texture == null or not texture.resource_path.contains("kitA"), path + " old kit background")


func inspect_slots() -> void:
	var slots := hud.info_box.find_child("worker_slots", true, false)
	if not check(slots != null and slots.get_child_count() == city.job_max(hud.info_b), "one worker silhouette per slot"):
		return
	for slot: Control in slots.get_children():
		check(not slot is PanelContainer and not slot is Panel, "worker slot has no circle")
		check(slot.has_meta("occupied"), "worker slot has occupancy")
		for descendant: Control in slot.find_children("*", "Control", true, false):
			check(not descendant is PanelContainer and not descendant is Panel, "worker silhouette has no frame")
			if descendant is TextureRect:
				var picture := descendant as TextureRect
				check(picture.texture == CityStyle.icon("person"), "worker slot is a plain person, no portrait")
				check(is_equal_approx(picture.modulate.a, 1.0 if bool(slot.get_meta("occupied")) else 0.22), "filled/free worker visibility")
	var required := hud.info_box.find_child("RequiredWorkerClass", true, false) as Control
	check(required != null and required.tooltip_text != "", "required class pictogram has a tooltip")


func finish_run() -> void:
	print(tag + " DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
