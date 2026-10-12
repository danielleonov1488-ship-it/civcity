extends Node
## Проверка управления настоящими событиями мыши: кисть дороги, раздел «Жильё», карточка дома,
## постановка домов у дороги, подсветка при сносе, выбор постройки (обводка и карточка), правая кнопка

var game
var mask := 0


func _ready() -> void:
	Game.boot = {"new": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func move(p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	e.button_mask = mask
	Input.parse_input_event(e)


func btn(p: Vector2, idx: int, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = p
	e.global_position = p
	e.button_index = idx
	e.pressed = pressed
	if pressed:
		mask |= 1 << (idx - 1)
	else:
		mask &= ~(1 << (idx - 1))
	e.button_mask = mask
	Input.parse_input_event(e)


func click(p: Vector2, idx := MOUSE_BUTTON_LEFT) -> void:
	move(p)
	await frames(3)
	btn(p, idx, true)
	await frames(2)
	btn(p, idx, false)
	await frames(3)


func scr(w: Vector2) -> Vector2:
	var cam: Camera3D = get_viewport().get_camera_3d()
	return get_viewport().get_final_transform() * cam.unproject_position(Vector3(w.x, game.land.height_at(w.x, w.y), w.y))


func center_of(c: Control) -> Vector2:
	return c.get_viewport().get_final_transform() * (c.get_global_transform_with_canvas() * (c.size / 2.0))


func shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png("D:/CivCity/.work/gd/" + name)
	print("SHOT ", name, " tool=", game.tool, " buildings=", game.city.buildings.size(), " money=", int(game.city.money))


func drag(a: Vector2, b: Vector2) -> void:
	move(a)
	await frames(3)
	btn(a, MOUSE_BUTTON_LEFT, true)
	for k in 30:
		move(a.lerp(b, k / 29.0))
		await frames(1)
	btn(b, MOUSE_BUTTON_LEFT, false)
	await frames(5)


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(30)
	game.hud.advisor_panel.visible = false
	game.rig.set_view(Vector3(192, 2, 138), 15, 58, 40)
	await frames(20)
	await click(center_of(game.hud.road_btns["road"]))
	print("after road button tool=", game.tool)
	await drag(scr(Vector2(192, 128)), scr(Vector2(192, 150)))
	await drag(scr(Vector2(178, 140)), scr(Vector2(206, 140)))
	print("road at (192,144): ", game.land.kind_at(192, 144), " money=", int(game.city.money))
	shot("in1_roads.png")
	await click(scr(Vector2(200, 132)), MOUSE_BUTTON_RIGHT)
	print("after RMB tool=", game.tool)
	await click(center_of(game.hud.cats["housing"]))
	await frames(5)
	var card: Control = null
	for c in game.hud.tray_grid.get_children():
		if c.get_meta("type", "") == "house_pleb":
			card = c
	print("tray visible=", game.hud.tray.visible, " card=", card != null)
	await click(center_of(card))
	print("after card tool=", game.tool)
	move(scr(Vector2(188, 136)))
	await frames(10)
	shot("in2_ghost.png")
	for w: Vector2 in [Vector2(188, 136), Vector2(183, 136), Vector2(188, 144), Vector2(183, 144), Vector2(197, 136), Vector2(202, 144)]:
		await click(scr(w))
	print("houses placed, buildings=", game.city.buildings.size())
	# поворот как в Town to City: зажать и вести вбок — не строится; следующий щелчок строит повёрнутым
	var n0: int = game.city.buildings.size()
	var a := scr(Vector2(186, 152))
	move(a)
	await frames(3)
	btn(a, MOUSE_BUTTON_LEFT, true)
	for k in 20:
		move(a + Vector2(k * 6.0, 0))
		await frames(1)
	btn(a + Vector2(114, 0), MOUSE_BUTTON_LEFT, false)
	await frames(5)
	print("ROT after drag: built=", game.city.buildings.size() - n0, " lock=", not game.place_lock.is_empty(), " yaw=", snappedf(rad_to_deg(game.tool_yaw), 1))
	shot("in2b_rotated_ghost.png")
	await click(a + Vector2(114, 0))
	print("ROT after click: built=", game.city.buildings.size() - n0, " lock=", not game.place_lock.is_empty())
	await click(scr(Vector2(210, 130)), MOUSE_BUTTON_RIGHT)
	print("after RMB2 tool=", game.tool)
	# снос: подсветка всей модели
	await click(center_of(game.hud.tool_btns["bulldoze"]))
	var hb: Dictionary = {}
	for id in game.city.buildings:
		if game.city.is_house(game.city.buildings[id]):
			hb = game.city.buildings[id]
			break
	move(scr(hb["pos"]))
	await frames(10)
	print("highlight=", game.highlight != null, " hb=", hb["pos"], " hover=", game.hover, " over_ui=", game.hud.mouse_over_ui(), " at=", game.city.building_at(game.hover).get("id", -1), " hbid=", hb["id"], " hovered=", get_viewport().gui_get_hovered_control())
	shot("in3_bulldoze.png")
	await click(scr(Vector2(210, 130)), MOUSE_BUTTON_RIGHT)
	await frames(5)
	await click(scr(hb["pos"]))
	print("info visible=", game.hud.info_panel.visible, " outline=", game.select_outline != null)
	await frames(10)
	shot("in4_info.png")
	# снос и перенос дерева
	var tree := {}
	for key in game.nature:
		for it in game.nature[key]:
			if String(it["name"]).contains("Tree") and (it["p"] as Vector2).distance_to(Vector2(192, 140)) < 40.0:
				tree = it
				break
		if not tree.is_empty():
			break
	print("tree found=", not tree.is_empty())
	if not tree.is_empty():
		game.rig.set_view(Vector3(tree["p"].x, 2, tree["p"].y), 15, 50, 16)
		await frames(30)
		game.hud.close_panels()
		game.set_tool("move")
		move(scr(tree["p"]))
		await frames(10)
		print("hover nature=", not game.hover_nature.is_empty())
		shot("in5_tree.png")
		await click(scr(tree["p"]))
		print("moving tree tool=", game.tool)
		await click(scr(tree["p"] + Vector2(4, 0)))
		print("after place tool=", game.tool, " tree at new=", not game.nature_at(tree["p"] + Vector2(4, 0)).is_empty())
	get_tree().quit()
