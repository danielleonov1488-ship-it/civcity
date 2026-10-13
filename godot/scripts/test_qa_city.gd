extends Node
## Город для автопроверки собранной игры (deploy/qa_exported.sh, сценарий legion): готовый город (демо, 210 построек)
## + Легион середины похода (исследования «Легион» и «Стрельбище», Казармы и Стрельбище, бойцы 3 ур., Лес — бой 3).
## Пишет JSON сохранения (как Game.save) — deploy/qa_accounts.js кладёт его в облако тестового аккаунта.
##   bash .work/py/gpu_run.sh res://test_qa_city.tscn -- out=D:/CivCity/.work/qa/legion_city.json
## Город не сохраняется в saves/ (режим demo).

var game
var out := "D:/CivCity/.work/qa/legion_city.json"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.trim_prefix("out=")
	Game.boot = {"demo": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(20)
	var c: City = game.city
	var lg: Legion = c.legion
	c.research["legion"] = true
	c.research["archery"] = true
	var spots := [Vector2(150, 205), Vector2(166, 205)]
	var i := 0
	for t in ["barracks", "range"]:
		var r: Dictionary = c.place(t, spots[i], 0.0, 0, -1, true)
		print("QACITY place ", t, " -> ", "ok" if not r.is_empty() else "FAIL")
		i += 1
	lg.progress = 2
	lg.levels = {"legionary": 3, "spearman": 1, "archer": 3, "ballista": 1, "catapult": 1}
	lg.use_auto_squad()
	lg.flags["intro"] = true
	lg.flags["seen"] = true
	c.changed.emit()
	await frames(10)
	print("QACITY squad=", lg.squad, " can_fight='", lg.can_fight(lg.stage_info(0, 0, 2)), "' window_open=", lg.window_open())
	var data := c.save_data()
	data["land"] = game.land.save_changes()
	data["hour"] = 10.0
	data["version"] = 2
	var s := JSON.stringify(data)
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(s)
	f.close()
	print("QACITY wrote ", out, " buildings=", c.buildings.size(), " bytes=", s.length())
	get_tree().quit()
