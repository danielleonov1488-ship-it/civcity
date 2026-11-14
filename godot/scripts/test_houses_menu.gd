extends Node
## Готовый город меню (promo/demo) — сколько построек каждого типа встало (сверка прежних и новых домов):
##   bash .work/py/gpu_run.sh res://test_houses_menu.tscn -- mode=promo [new=0]
var game
var mode := "promo"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"mode": mode = kv[1]
			"new":
				for t: String in NewHouses.TYPES:
					NewHouses.ON[t] = kv[1] != "0"
				NewHouses.APRON = kv[1] != "0"
	Game.boot = {mode: "1", "noui": "1", "hour": "9"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	while not game.ready_done:
		await get_tree().process_frame
	var cnt := {}
	for id in game.city.buildings:
		var t := String(game.city.buildings[id]["type"])
		cnt[t] = int(cnt.get(t, 0)) + 1
	var keys := cnt.keys()
	keys.sort()
	for t in keys:
		print("MENUCNT %s %s %d" % [mode, t, cnt[t]])
	print("MENUCNT DONE")
	get_tree().quit()
