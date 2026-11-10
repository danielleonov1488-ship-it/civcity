extends Node
## Снимки интерфейса «мрамор» на всех основных экранах (сравнить с пергаментом: --paui): меню, настройки, исследования,
## финансы, статистика, события, пауза, название города, Легион, журнал, карточка постройки, свиток стройки.
##   bash .work/py/gpu_run.sh res://test_ui_marble.tscn -- [out=D:/CivCity/.work/ui_marble] [mode=menu|demo]
var game
var out := "D:/CivCity/.work/ui_marble"
var mode := "demo"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		if a.begins_with("mode="):
			mode = a.substr(5)
	DirAccess.make_dir_recursive_absolute(out)
	Game.boot = {mode: "1", "hour": "11.0"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	await frames(10)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [out, mode, name])
	print("shot ", name)


func _close_all() -> void:
	var h = game.hud
	for p in [h.research_panel, h.finance_panel, h.stats_panel, h.events_panel, h.settings_panel, h.pause_panel, h.journal_panel, h.advisor_panel]:
		if p != null:
			(p as Control).visible = false
	await frames(5)


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(40)
	var h = game.hud
	if mode == "menu":
		await shot("menu")
		h._open_settings()
		await shot("settings")
		print("UIMARBLE DONE")
		get_tree().quit()
		return
	await _close_all()
	await shot("city")
	for id in ["research", "finance", "stats"]:
		h._top_action(id)
		await shot(id)
		await _close_all()
	h._toggle(h.events_panel)
	h._fill_events()
	await shot("events")
	await _close_all()
	h._open_settings()
	await shot("settings")
	await _close_all()
	game.stories.ui.open_journal("chron")
	await shot("journal")
	await _close_all()
	# карточка постройки и свиток стройки
	for id in game.city.buildings:
		var b: Dictionary = game.city.buildings[id]
		if String(b["type"]).begins_with("temple"):
			h.open_info(b)
			break
	await shot("info")
	h._hide_info()
	h.select_build("house")
	await shot("build_tray")
	game.set_tool("")
	h.tray.visible = false
	var lu := LegionUi.of(h)
	if lu != null:
		lu.open("campaign")
		await shot("legion")
		lu.close()
	print("UIMARBLE DONE")
	get_tree().quit()
