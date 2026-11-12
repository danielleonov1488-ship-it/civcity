extends Node
## Стенд облика: готовый город без интерфейса, одни и те же виды в разное время суток — для сравнения с Town to City.
## Аргументы (после --): tag=имя  views=0,1,2  hours=12.5,19.5
var game
var tag := "cur"
var views := [0, 1, 2]
var hours := [12.5, 19.5, 0.5]
var look := ""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		if kv.size() == 2:
			match kv[0]:
				"tag": tag = kv[1]
				"views": views = Array(kv[1].split(",")).map(func(x): return int(x))
				"hours": hours = Array(kv[1].split(",")).map(func(x): return float(x))
				"kit": KitHouses.ON = kv[1] != "0"        # kit=0 — прежние модели Synty (сравнение «было / стало»)
				"look": look = kv[1]                       # look=synty — проба света и цвета «как на картинках Synty»
	Game.boot = {"demo": "1", "noui": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func view(i: int) -> void:
	match i:
		0: game.rig.set_view(Vector3(190, 1.5, 150), 20, 40, 46)     # средний план
		1: game.rig.set_view(Vector3(186, 1.5, 142), 205, 30, 20)    # улица вблизи
		2: game.rig.set_view(Vector3(192, 1.5, 154), 20, 52, 90)     # весь город
		3: game.rig.set_view(Vector3(192, 1.5, 148), 0, 36, 30)      # как в Town to City: к тоннелю

func _run() -> void:
	while not game.ready_done:
		await frames(5)
	game.hud.visible = false
	game.speed = 0.0
	if look == "synty":
		# сочнее и теплее, как в рекламе Synty: насыщенность и контраст, тёплое солнце, меньше дымки, сильнее свечение огня
		var e: Environment = game.env
		e.tonemap_mode = Environment.TONE_MAPPER_AGX
		e.tonemap_exposure = 1.15
		e.adjustment_enabled = true
		e.adjustment_saturation = 1.22
		e.adjustment_contrast = 1.08
		e.adjustment_brightness = 1.02
		e.fog_density = 0.0004
		e.glow_intensity = 0.8
		e.glow_bloom = 0.05
		e.ssao_intensity = 2.0
		game.sky_mat.sky_top_color = Color("4f86d0")
		game.sky_mat.sky_horizon_color = Color("f4d6a8")
	game.clock_hours = false
	await frames(30)
	for h in hours:
		game._set_hour(h)
		for v in views:
			view(v)
			await frames(70)
			get_viewport().get_texture().get_image().save_png("D:/CivCity/.work/look/%s_v%d_h%s.png" % [tag, v, str(h).replace(".", "_")])
	print("look done")
	get_tree().quit()
