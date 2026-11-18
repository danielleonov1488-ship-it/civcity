extends Node3D
## Карточки исследований и три кадра для проверки.

var out := "D:/CivCity/.work/stage7/research8/shots/"
var game: Game
var fails := 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=").trim_suffix("/") + "/"
	get_window().size = Vector2i(1280, 720)
	Game.boot = {"new": "1", "legion": "0"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	game.can_save = false
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, message: String) -> bool:
	if not ok:
		fails += 1
		print("RESEARCH8 FAIL ", message)
	return ok


func _finish() -> void:
	print("RESEARCH8 DONE fails=", fails)
	get_tree().quit(0 if fails == 0 else 1)


func shot(rank: int) -> void:
	await frames(8)
	await RenderingServer.frame_post_draw
	var file := out + "research_%d.png" % rank
	if check(get_viewport().get_texture().get_image().save_png(file) == OK, "save " + file):
		print("RESEARCH8 SHOT ", file)


static func viewport_bounds(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


static func check_tooltip(popup: Control, verify: Callable) -> void:
	verify.call(popup.is_visible_in_tree() and popup.get_viewport_rect().encloses(viewport_bounds(popup)), "tooltip fully inside viewport")


static func check_tree(hud: Hud, city: City, verify: Callable) -> int:
	var tree = hud.research_tree
	var panel := hud.research_panel
	verify.call(panel.get_viewport_rect().encloses(viewport_bounds(panel)), "research window inside viewport")
	var scroll: ScrollContainer = tree.scroll
	var bar := scroll.get_v_scroll_bar()
	verify.call(bar.visible and bar.max_value > bar.page and not scroll.get_h_scroll_bar().visible, "research scrolls vertically")
	var sections_bottom := -INF
	for tier: int in tree.sections:
		var section: Control = tree.sections[tier]
		var bounds := viewport_bounds(section)
		verify.call(section.is_visible_in_tree() and bounds.position.y >= sections_bottom - 0.5, "rank sections stack " + str(tier))
		sections_bottom = bounds.end.y
		var notice := section.get_node("RankLockNotice") as Control
		var items := section.get_node("Items") as Control
		verify.call(notice.visible == (tier > city.level) and (items.modulate.a < 1.0) == (tier > city.level), "rank lock and dimming " + str(tier))
	var rects: Array[Rect2] = []
	for r: Dictionary in Defs.RESEARCH:
		var id := String(r["id"])
		var tier := int(r["lvl"])
		var card: Button = tree.cards[id]
		var visible := city.research_visible(id) and not bool(r.get("hidden", false))
		if Defs.B.has(id) and Defs.B[id].get("sub", "") == "wonders":
			visible = visible and city.city_buildable(id)
		verify.call(card.is_visible_in_tree() == visible, "visible city research " + id)
		if not visible:
			continue
		var tag := "%s/%s" % [I18n.lang, id]
		var card_rect := viewport_bounds(card)
		var section: Control = tree.sections[tier]
		verify.call(viewport_bounds(section).grow(0.5).encloses(card_rect), "item fits its section " + tag)
		var picture := card.get_node("Picture") as TextureRect
		verify.call(picture.size == Vector2(72, 72) and picture.texture != null
			and picture.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			and is_equal_approx(viewport_bounds(picture).get_center().x, card_rect.get_center().x), "centred picture " + tag)
		var label := card.get_node("ItemName") as Label
		_check_name(card, label, I18n.t(String(r["name"])), tag, verify)
		for other: Rect2 in rects:
			verify.call(not other.intersects(card_rect), "item bounds overlap " + tag)
		rects.append(card_rect)
		_check_state(card, city, r, tag, verify)
		var parents := Defs.research_prerequisites(r)
		for before: String in parents:
			var parent: Control = tree.cards[before]
			if parent.is_visible_in_tree():
				var link_name := id + "_" + before if parents.size() > 1 else id
				var line := section.get_node("PrerequisiteLinks").get_node_or_null(link_name) as Line2D
				_check_link(line, parent, card, "%s <- %s" % [tag, before], verify)
	return rects.size()


static func _check_link(line: Line2D, parent: Control, child: Control, tag: String, verify: Callable) -> void:
	verify.call(viewport_bounds(child).position.y > viewport_bounds(parent).end.y, "dependent follows prerequisite " + tag)
	if not verify.call(line != null and line.visible and line.points.size() >= 4, "prerequisite connector " + tag):
		return
	var from := line.get_global_transform_with_canvas() * line.points[0]
	var to := line.get_global_transform_with_canvas() * line.points[-1]
	var parent_circle := viewport_bounds(parent.get_node("Medallion") as Control)
	var child_circle := viewport_bounds(child.get_node("Medallion") as Control)
	verify.call(from.distance_to(Vector2(parent_circle.get_center().x, parent_circle.end.y)) <= 3.0
		and to.distance_to(Vector2(child_circle.get_center().x, child_circle.position.y)) <= 3.0, "connector meets both circles " + tag)


static func _check_name(card: Control, label: Label, expected: String, tag: String, verify: Callable) -> void:
	verify.call(label.text == expected and label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING, "full name " + tag)
	verify.call(viewport_bounds(card).encloses(viewport_bounds(label)), "name rectangle inside item " + tag)
	verify.call(label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART and label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
		and label.get_theme_font_size("font_size") >= 14 and label.get_theme_color("font_color") == CityStyle.INK, "name style " + tag)
	var lines := label.get_line_count()
	verify.call(lines in [1, 2, 3] and label.get_visible_line_count() == lines, "one to three complete lines " + tag)
	var inner := Rect2(Vector2.ZERO, label.size).grow(0.5)
	var fits := true
	for i in expected.length():
		if expected[i].strip_edges().is_empty():
			continue
		var glyph := label.get_character_bounds(i)
		fits = fits and glyph.has_area() and inner.encloses(glyph)
	verify.call(fits, "drawn name fits its rectangle " + tag)


static func _check_state(card: Button, city: City, r: Dictionary, tag: String, verify: Callable) -> void:
	var id := String(r["id"])
	var done := (card.get_node("DoneTick") as Control).visible
	var locked := (card.get_node("ParentLock") as Control).visible
	var cost := card.get_node("CostBadge") as PanelContainer
	var image := card.get_node("Picture") as TextureRect
	var affordable := city.can_research(id).is_empty()
	verify.call(int(done) + int(locked) + int(cost.visible) == 1 and not card.has_node("Study"), "item has one status and is the only action " + tag)
	verify.call(done == city.research_done(id) and cost.visible == city.research_open(id) and card.disabled != affordable, "correct state " + tag)
	verify.call((image.material != null) == locked, "only locked pictures are desaturated " + tag)
	if cost.visible:
		var price := cost.get_node("Price/Cost") as Label
		var fill := (cost.get_theme_stylebox("panel") as StyleBoxFlat).bg_color
		verify.call(price.text.replace(" ", "").replace(" ", "").replace(" ", "") == str(int(r["cost"])) and viewport_bounds(cost).encloses(viewport_bounds(price)), "price fits its pill " + tag)
		verify.call((fill.g > fill.r) == affordable, "affordable price is green " + tag)
	elif locked:
		var missing := city.missing_research_prerequisite(r)
		if missing != "":
			var requirement := I18n.t("Сначала: %s") % I18n.t(String(Defs.research(missing)["name"]))
			verify.call(String(card.get_meta("tooltip", "")).contains(requirement), "lock tooltip names prerequisite " + tag)


func _run() -> void:
	var waited := 0
	while not game.ready_done and waited < 18000:
		await frames(5)
		waited += 5
	if not check(game.ready_done, "ready_done timeout") or not check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory"):
		_finish()
		return
	game.can_save = false
	game.settings["autosave"] = false
	game.settings["advisor_off"] = true
	game.rank_cine.force = false
	game.tutorial.step = Tutorial.STEPS.size()
	game.tutorial.card.hide()
	var hud: Hud = game.hud
	var city: City = game.city
	city.tips["tut"] = -1
	city.tips["ui"] = 3
	city.tips["rank_pressed"] = true
	var seen := {}
	for r: Dictionary in Defs.RESEARCH:
		seen[r["id"]] = true
	city.tips["seen_r"] = seen
	city.level = 2
	city.rp = 70
	city.research = {"stall_veg": true, "floor2": true, "weaver": true}
	hud.apply_reveal(3)
	hud.set_speed(0.0)
	game._set_hour(10.5)
	I18n.set_lang("ru")
	hud._top_action("research")
	var tree = hud.research_tree
	await frames(8)
	# Старые сохранения показывают ещё Легион и Стрельбище.
	var cozy_version := city.cozy_v
	city.cozy_v = 0
	for lang: String in ["ru", "en"]:
		I18n.set_lang(lang)
		tree.refresh()
		await frames(6)
		check(check_tree(hud, city, check) > 0, "names measured in " + lang)
	city.cozy_v = cozy_version
	I18n.set_lang("ru")
	tree.refresh()
	for rank in 3:
		tree.select_rank(rank)
		city.rp = [24, 70, 190][rank]
		hud._fill_research()
		await _wait_for_pictures(hud)
		await shot(rank)
	await _edge_tooltip(hud)
	_finish()


func _wait_for_pictures(hud: Hud) -> void:
	var tree = hud.research_tree
	var types: Array[String] = []
	for card: Control in tree.cards.values():
		if not card.is_visible_in_tree():
			continue
		for type: String in tree.building_ids(String(card.get_meta("rid"))):
			if game.city.city_buildable(type):
				types.append(type)
				break
	for attempt in 3600:
		if types.all(func(type: String): return hud.icons.get(type) != null):
			tree.refresh()
			return
		await frames(5)
	check(false, "building pictures timeout")


func _edge_tooltip(hud: Hud) -> void:
	var tree = hud.research_tree
	await tree.focus_card("deco_south")
	await frames(4)
	var card: Control = tree.cards["deco_south"]
	var corner := card.get_viewport_rect().end - Vector2(12, 12)
	hud.research_panel.global_position += corner - viewport_bounds(card).end
	tree.show_detail("deco_south")
	await frames(8)
	check_tooltip(tree.popup, check)
	var popup_rect := viewport_bounds(tree.popup)
	var card_rect := viewport_bounds(card)
	check(popup_rect.end.x <= card_rect.position.x, "right edge tooltip flips left")
	hud.close_panels()
	check(not tree.popup.visible, "tooltip hides when window closes")
