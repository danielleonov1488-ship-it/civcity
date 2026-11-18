extends "res://scripts/test_city5b.gd"
## CITY5b-2: размеры карточек, источники нужд и полные подписи исследований.


func _ready() -> void:
	out = "D:/CivCity/.work/stage5/city5b2/shots/"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=").trim_suffix("/") + "/"
	get_window().size = Vector2i(1440, 900)
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	game.can_save = false
	add_child(game)
	_run()


func check(ok: bool, why: String) -> bool:
	if not ok:
		fails += 1
		print("CITY5B2 FAIL " + why)
	return ok


func _finish() -> void:
	print("CITY5B2 DONE fails=", fails)
	get_tree().quit(0 if fails == 0 else 1)


func _run() -> void:
	var rect := Rect2(60, 0, 44, 44)
	var from := Vector2(0, 22)
	var to := Vector2(166, 22)
	var span := Hud._badge_segment_span(rect, from, to)
	check(span != Vector2.INF and rect.has_point(from.lerp(to, (span.x + span.y) * 0.5)), "166px stroke intersects 44px badge")
	span = Hud._badge_segment_span(rect, to, from)
	check(span != Vector2.INF and rect.has_point(to.lerp(from, (span.x + span.y) * 0.5)), "reverse stroke intersects badge")
	check(Hud._badge_segment_span(rect, Vector2(0, 45), Vector2(166, 45)) == Vector2.INF, "stroke outside badge misses")
	await super._run()


func shot(file: String) -> void:
	hud.advisor_panel.hide()
	if hud.info_panel.visible:
		await _wait_source_pictures()
		_card_bounds()
	await frames(12)
	hud._place_badges()
	await RenderingServer.frame_post_draw
	if check(get_viewport().get_texture().get_image().save_png(out + file) == OK, "save " + file):
		print("CITY5B2 SHOT " + out + file)


func _card_bounds() -> void:
	super._card_bounds()
	for name: String in ["InfoFloor", "InfoUpgrade"]:
		var button := hud.info_box.find_child(name, true, false) as Button
		if button == null:
			continue
		check(not button.clip_text and button.get_theme_font_size("font_size") == 14, name + " readable 14px text")
		check(button.icon != null and hud.info_panel.get_global_rect().encloses(button.get_global_rect()), name + " icon and button fit card")
		var frame := button.get_theme_stylebox("normal") as StyleBoxFlat
		check(frame != null and frame.bg_color == CityStyle.CREAM and frame.border_color == CityStyle.RIM, name + " cream city pill")
		check(button.get_theme_stylebox("disabled") is StyleBoxFlat, name + " faded city state")
		var face: Font = button.get_theme_font("font")
		var text_width := face.get_string_size(I18n.t(button.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		check(button.size.x >= text_width + 46.0, name + " text, icon and margins fit without clipping")
	if city.is_house(hud.info_b):
		var floor_button := hud.info_box.find_child("InfoFloor", true, false) as Button
		if int(hud.info_b["tier"]) < Defs.floors_max(String(city.def(hud.info_b)["cls"]), int(hud.info_b.get("variant", 0))):
			check(floor_button != null and floor_button.text == "Этаж" and floor_button.tooltip_text.begins_with("Надстроить этаж · "), "floor action retained")
		var pictures := hud.info_box.find_children("SourcePicture*", "TextureRect", true, false)
		check(not pictures.is_empty(), "house has covering-building pictures")
		for picture: TextureRect in pictures:
			var type := String(picture.get_meta("building_type", ""))
			check(picture.texture != null, "nonempty covering picture " + type)
			if hud.icons.has(type):
				check(picture.texture == hud.icons[type] and picture.modulate == Color.WHITE, "colored covering building picture " + type)
			var bonus := picture.get_parent().get_child(1) as Label
			check(bonus != null and bonus.text.begins_with("+") and bonus.text.ends_with("%") and not bonus.clip_text, "covering bonus visible " + type)
			var overlay := picture.get_parent().get_parent().get_child(1) as Button
			check(overlay != null and overlay.get_theme_stylebox("normal") is StyleBoxEmpty, "source action does not cover picture " + type)


func _wait_source_pictures() -> void:
	for attempt in 3600:
		var ready := true
		for picture: TextureRect in hud.info_box.find_children("SourcePicture*", "TextureRect", true, false):
			if not hud.icons.has(String(picture.get_meta("building_type", ""))):
				ready = false
		if ready:
			hud._refresh_building_pictures()
			return
		await frames(5)
	check(false, "covering pictures timeout")
