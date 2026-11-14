extends Node
## Город владельца: куда перестройка дома плебеев в дом ремесленников не помещается и почему (прежние и новые дома):
##   bash .work/py/gpu_run.sh res://test_houses_upg.tscn -- [new=0]
const OWNER := "D:/CivCity/.work/owner_save/city.json"
var game


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("new="):
			for t: String in NewHouses.TYPES:
				NewHouses.ON[t] = a.substr(4) != "0"
	DirAccess.copy_absolute(OWNER, GamePaths.save_dir().path_join("city.json"))
	Game.boot = {"play": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	while not game.ready_done:
		await get_tree().process_frame
	var c: City = game.city
	game.can_save = false
	for r in Defs.RESEARCH:
		c.research[r["id"]] = true
	var ids: Array = c.buildings.keys()
	ids.sort()
	for id in ids:
		var h: Dictionary = c.buildings[id]
		if String(h["type"]) != "house_pleb":
			continue
		var res: Dictionary = c.upgrade_place(h)
		var who := c._upgrade_blocker(h) if String(res["err"]) == "Место занято" else ""
		print("UPG id=%d v=%d pos=%s yaw=%.2f err=%s %s" % [int(id), int(h.get("variant", 0)), h["pos"], float(h["yaw"]), res["err"], who])
	print("UPG DONE")
	get_tree().quit()
