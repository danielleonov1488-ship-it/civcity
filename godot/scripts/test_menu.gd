extends Node
## Проверка меню: «Настройки» открываются и в них можно нажимать (ползунок музыки, полный экран)
var game
var mask := 0

func _ready() -> void:
	Game.boot = {"menu": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func click(p: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	Input.parse_input_event(m)
	await frames(3)
	for pressed: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = p
		e.global_position = p
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		Input.parse_input_event(e)
		await frames(3)

func center_of(c: Control) -> Vector2:
	return c.get_viewport().get_final_transform() * (c.get_global_transform_with_canvas() * (c.size / 2.0))

func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(30)
	var btn: Button = null
	for b in game.hud.menu_root.find_children("*", "Button", true, false):
		if (b as Button).text == "Настройки":
			btn = b
	await click(center_of(btn))
	await frames(10)
	print("settings visible=", game.hud.settings_panel.visible)
	var sl: HSlider = game.hud.settings_panel.find_child("music", true, false)
	var before: float = game.settings["music"]
	var r := sl.get_global_rect()
	await click(game.get_viewport().get_final_transform() * (sl.get_global_transform_with_canvas() * Vector2(sl.size.x * 0.9, sl.size.y / 2)))
	print("music before=", before, " after=", game.settings["music"])
	var au: CheckBox = game.hud.settings_panel.find_child("auto", true, false)
	var a0: bool = game.settings["autosave"]
	await click(center_of(au))
	print("autosave before=", a0, " after=", game.settings["autosave"])
	get_viewport().get_texture().get_image().save_png("D:/CivCity/.work/gd/menu_settings.png")
	get_tree().quit()
