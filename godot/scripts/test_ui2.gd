extends Node3D
## Четыре кадра и проверки значков; запуск только у владельца проверки.

const Preference = preload("res://scripts/family_preference.gd")
const Badge = preload("res://scripts/map_badge.gd")
var out := "D:/CivCity/.work/stage2/ui2/shots/"
var game
var hud: Hud
var city: City
var clicks := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=").trim_suffix("/") + "/"
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	game.can_save = false
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, reason: String) -> bool:
	if not ok:
		print("UI2 FAIL ", reason)
		get_tree().quit(1)
	return ok


func shot(file: String) -> bool:
	hud.advisor_panel.visible = false
	await frames(8)
	await RenderingServer.frame_post_draw
	if not check(get_viewport().get_texture().get_image().save_png(out + file) == OK, "save " + file):
		return false
	print("UI2 SHOT ", out + file)
	return true


func family_with(tr_id: String, cls: String) -> Dictionary:
	for i in 10000:
		var f := {"name": "Юлии%d" % i, "n": 3, "cls": cls}
		if Preference.main(f) == tr_id:
			return f
	return {}


func event(button: MouseButton, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	return e


func _run() -> void:
	var waited := 0
	while not game.ready_done:
		await frames(5)
		waited += 5
		if not check(waited < 18000, "ready_done timeout"):
			return
	game.can_save = false
	game.settings["autosave"] = false
	game.speed = 0.0
	game.rig.cine = true
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1440, 900)
	game.tutorial.step = Tutorial.STEPS.size()
	game.tutorial.card.visible = false
	hud = game.hud
	hud.quiet_tips = 1
	city = game.city
	city.tips["tut"] = -1
	city.tips["ui"] = 3
	city.cozy_v = 1
	city.money = 1000000
	hud.apply_reveal(3)
	if not check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory"):
		return
	var green_home := city.place("house_pleb", Vector2(177, 123), 0, 0, 0, true)
	var bare_home := city.place("house_pleb", Vector2(151, 132), 0, 0, 0, true)
	var artisan_home := city.place("house_artisan", Vector2(171, 143), 0, 0, 0, true)
	var tree := city.place("tree", Vector2(179, 129), 0, 0, 0, true)
	var shop := city.place("stall_fruit", Vector2(208, 122), 0, 0, 0, true)
	if not check(not green_home.is_empty() and not bare_home.is_empty() and not artisan_home.is_empty() and not tree.is_empty() and not shop.is_empty(), "fixture buildings"):
		return
	for h: Dictionary in [green_home, bare_home, artisan_home]:
		var door := city.door_point(h)
		game.land.paint_line(door, Vector2(Land.ROAD_X, door.y), 0.9, Land.Kind.ROAD)
	var green := family_with("green", "plebs")
	var quiet := family_with("quiet", "artisans")
	if not check(not green.is_empty() and not quiet.is_empty(), "families with real traits"):
		return
	for f: Dictionary in [green, quiet]:
		city.arrivals.append(f)
		game.people._on_resident_returned(f)
	city.compute()
	city.changed.emit()
	city.arrivals_changed.emit()
	hud._update_world_icons()
	hud._close_windows()
	game.rig.set_view(Vector3(180, 2, 120), 0, 52, 80)
	await get_tree().create_timer(0.3).timeout
	hud._family_badges()
	hud._place_badges()
	var fam_key := "fam_" + String(green["name"])
	var problem_key := "b%d" % int(shop["id"])
	if not check(hud.badges.has(fam_key) and hud.badges.has("fam_" + String(quiet["name"])), "two waiting family badges"):
		return
	if not check(hud.badges.has(problem_key) and hud.badges[problem_key]["icon"] == "road" and bool(hud.badges[problem_key]["warn"]), "shop without road has warning"):
		return
	var family_badge: Badge = hud.badges[fam_key]["n"]
	if not check(family_badge.preference_texture != null and family_badge.ring == Badge.CLASS_RING["plebs"] and family_badge.get_child_count() == 0 and family_badge.tooltip_text.contains("рядом зелень"), "family preference, ring, tooltip and single Control"):
		return
	if not check(family_badge.visible and (hud.badges[problem_key]["n"] as Control).visible, "city shot contains family and problem"):
		return
	if not await shot("1_badges_city.png"):
		return
	var at: Vector3 = hud.badges[fam_key]["pos"]
	game.rig.set_view(at, 0, 45, 24)
	if not await shot("2_family_badge.png"):
		return
	hud._badge_input(event(MOUSE_BUTTON_LEFT, true), fam_key)
	if not check(game.tool == "settle" and game.settle_fam["name"] == green["name"], "family click starts settling"):
		return
	var good_key := "settle%d" % int(green_home["id"])
	var bare_key := "settle%d" % int(bare_home["id"])
	if not check(hud.badges.has(good_key) and hud.badges.has(bare_key), "settlement keys"):
		return
	if not check((hud.badges[good_key]["n"] as Badge).matches and not (hud.badges[bare_key]["n"] as Badge).matches, "green check only on matching home"):
		return
	game.rig.set_view(Vector3(169, 2, 131), 0, 52, 68)
	hud._place_badges()
	var key_node: Control = hud.badges[good_key]["n"]
	if not check(key_node.visible and key_node.mouse_filter == Control.MOUSE_FILTER_PASS and hud.badge_at(key_node.get_global_rect().get_center(), "settle") == good_key, "key picking after scaling"):
		return
	if not await shot("3_settle_keys.png"):
		return
	hud._badge_input(event(MOUSE_BUTTON_LEFT, true), good_key)
	if not check(city.pending.has(green["name"]) and int(city.pending[green["name"]]["home"]) == int(green_home["id"]), "key click assigns chosen home"):
		return
	await get_tree().create_timer(0.3).timeout
	hud._family_badges()
	if not check(not hud.badges.has(fam_key), "settled family badge removed"):
		return
	game.rig.set_view(Vector3(shop["pos"].x, float(shop["y"]) + 2, shop["pos"].y), 0, 50, 26)
	if not await shot("4_problem.png"):
		return
	hud._badge_click(problem_key)
	if not check(int(game.selected.get("id", -1)) == int(shop["id"]), "problem click selects shop"):
		return
	hud.close_panels()
	if not _cache_and_input():
		return
	game.rig.set_view(Vector3(180, 2, 120), 0, 50, 60)
	hud.set_badge("resize", Vector3(185, 6, 120), "family")
	hud._place_badges()
	var before_resize: Vector2 = (hud.badges["resize"]["n"] as Control).position
	get_window().size = Vector2i(1280, 720)
	await frames(5)
	hud._place_badges()
	if not check((hud.badges["resize"]["n"] as Control).position != before_resize, "viewport resize refreshes positions"):
		return
	print("UI2 DONE")
	get_tree().quit()


func _cache_and_input() -> bool:
	# Около сорока настоящих лёгких узлов; прогрев вне измерения.
	var at := Vector3(180, 5, 120)
	game.rig.set_view(at, 0, 50, 60)
	for i in maxi(0, 40 - hud.badges.size()):
		hud.set_badge("perf%d" % i, at + Vector3((i % 8) * 2, 0, (i / 8) * 2), "keys")
	hud.set_badge("probe", at, "coins", false, "125", func(): clicks += 1)
	hud._place_badges()
	var node: Control = hud.badges["probe"]["n"]
	if not check(node.get_child_count() == 1 and node.get_child(0) is Label, "text pill has only one Label"):
		return false
	var before := node.position
	var started := Time.get_ticks_usec()
	for i in 200:
		hud._place_badges()
	var average := float(Time.get_ticks_usec() - started) / 200.0
	print("UI2 PLACE_US ", average)
	if not check(average <= 60.0 and node.position == before, "static placement <= 60 us and no bob"):
		return false
	game.rig.cam.global_position += Vector3(3, 0, 0)
	hud._place_badges()
	if not check(node.position != before, "camera transform refreshes positions"):
		return false
	before = node.position
	game.rig.cam.fov += 5.0
	hud._place_badges()
	if not check(node.position != before, "projection refreshes positions"):
		return false
	before = node.position
	hud.set_badge("probe", at + Vector3(5, 0, 0), "coins", false, "125")
	hud._place_badges()
	if not check(hud.badges["probe"]["n"] == node and node.position != before, "same-node world movement marks dirty"):
		return false
	hud._badge_input(event(MOUSE_BUTTON_RIGHT, true), "probe")
	hud._badge_input(event(MOUSE_BUTTON_MIDDLE, true), "probe")
	hud._badge_input(event(MOUSE_BUTTON_LEFT, false), "probe")
	if not check(clicks == 0 and node.mouse_filter == Control.MOUSE_FILTER_PASS, "right/middle pass through without action"):
		return false
	hud._badge_input(event(MOUSE_BUTTON_LEFT, true), "probe")
	if not check(clicks == 1, "callback survives same-node update"):
		return false
	game.set_tool("floor")
	hud._place_badges()
	if not check(node.mouse_filter == Control.MOUSE_FILTER_IGNORE, "tool change disables badge mouse filtering"):
		return false
	game.set_tool("")
	hud._place_badges()
	if not check(node.mouse_filter == Control.MOUSE_FILTER_PASS, "tool reset restores picking"):
		return false
	hud.root.hide()
	hud._place_badges()
	if not check(not node.visible, "hidden HUD hides badges"):
		return false
	hud.root.show()
	hud._place_badges()
	if not check(node.visible, "visible HUD restores badges"):
		return false
	# Точка далеко от цели, но на оси камеры: проблема остаётся видна.
	game.rig.set_view(at, 0, 50, 110)
	var far: Vector3 = at - game.rig.cam.global_basis.z * 300.0
	hud.set_badge("far_normal", far, "keys")
	hud.set_badge("far_problem", far, "road", true)
	hud._place_badges()
	var warning: Control = hud.badges["far_problem"]["n"]
	if not check(not (hud.badges["far_normal"]["n"] as Control).visible and warning.visible and is_equal_approx(warning.scale.x, 0.8) and warning.modulate.a < 1.0, "distant culling preserves smaller faded problems"):
		return false
	hud.clear_badge("probe")
	return check(not hud.badges.has("probe") and not node.visible, "removed badge immediately stops picking")
