extends Node
## Проверка управления настоящими событиями мыши: кнопка «Мостовая», протяжка дороги, раздел «Жильё»,
## карточка дома, клики у дороги, правая кнопка — отмена, клик по дому — карточка

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
	return cam.unproject_position(Vector3(w.x, game.land.height_at(w.x, w.y), w.y))

func center_of(c: Control) -> Vector2:
	return c.get_global_rect().get_center()

func shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png("D:/CivCity/.work/gd/" + name)
	print("SHOT ", name, " tool=", game.tool, " buildings=", game.city.buildings.size(), " money=", int(game.city.money))

func _run() -> void:
	await frames(60)
	game.hud.advisor_panel.visible = false
	game.rig.set_view(Vector3(64, 2, 47), 0, 58, 40)
	await frames(10)
	# кнопка «Мостовая»
	await click(center_of(game.hud.road_btns["road"]))
	print("after road button tool=", game.tool)
	# протяжка дороги от центра на юг
	var a := scr(Vector2(64, 37))
	var b := scr(Vector2(64, 56))
	move(a)
	await frames(3)
	btn(a, MOUSE_BUTTON_LEFT, true)
	for k in 30:
		move(a.lerp(b, k / 29.0))
		await frames(1)
	btn(b, MOUSE_BUTTON_LEFT, false)
	await frames(5)
	print("road cells at (64,48): ", game.land.kind_at(64, 48), " money=", int(game.city.money))
	# поперечная улица
	a = scr(Vector2(50, 50))
	b = scr(Vector2(78, 50))
	move(a)
	await frames(3)
	btn(a, MOUSE_BUTTON_LEFT, true)
	for k in 30:
		move(a.lerp(b, k / 29.0))
		await frames(1)
	btn(b, MOUSE_BUTTON_LEFT, false)
	await frames(5)
	shot("in1_roads.png")
	# правая кнопка — отмена инструмента
	await click(scr(Vector2(70, 40)), MOUSE_BUTTON_RIGHT)
	print("after RMB tool=", game.tool)
	# раздел «Жильё» и карточка дома
	for c in game.hud.cats_box.get_children():
		if (c as Button).text == "Жильё":
			await click(center_of(c))
	await frames(5)
	var card: Control = null
	for c in game.hud.tray_grid.get_children():
		if c.get_meta("type", "") == "house":
			card = c
	print("tray visible=", game.hud.tray.visible, " card=", card != null)
	await click(center_of(card))
	print("after card tool=", game.tool)
	# навести у дороги — снимок с призраком
	move(scr(Vector2(61, 44)))
	await frames(8)
	shot("in2_ghost.png")
	for w: Vector2 in [Vector2(61, 41), Vector2(61, 46), Vector2(67, 41), Vector2(67, 46), Vector2(58, 53), Vector2(70, 53)]:
		await click(scr(w))
	print("houses placed, buildings=", game.city.buildings.size())
	await click(scr(Vector2(74, 44)), MOUSE_BUTTON_RIGHT)
	print("after RMB2 tool=", game.tool)
	await frames(10)
	# клик по дому — карточка
	var hb: Dictionary = {}
	for id in game.city.buildings:
		if game.city.buildings[id]["type"] == "house":
			hb = game.city.buildings[id]
	if not hb.is_empty():
		await click(scr(hb["pos"]))
	print("info visible=", game.hud.info_panel.visible)
	await frames(10)
	shot("in3_info.png")
	get_tree().quit()
