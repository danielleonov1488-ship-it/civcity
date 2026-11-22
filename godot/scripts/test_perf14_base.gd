extends Node

const OWNER := "D:/CivCity/.work/owner_save/city.json"
const TASK := "D:/CivCity/.work/stage7/perf14a"
const QUALITIES := ["high", "medium", "low", "verylow"]
const OWNER_VIEWS := [[210, 145, 15, 42, 60], [210, 150, 15, 50, 130], [192, 160, 15, 55, 240]]
const NEW_VIEWS := [[192, 124, 15, 42, 60], [192, 140, 15, 50, 130], [192, 160, 15, 55, 240]]
const VIEWS := ["center", "wide", "far"]

var game: Game
var args := {}
var out := ""
var started := ""


func setup_run() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=", true, 1)
		args[pair[0]] = pair[1] if pair.size() > 1 else "1"
	out = str(args.get("out", TASK))
	DirAccess.make_dir_recursive_absolute(out)
	started = "%d_%d" % [int(Time.get_unix_time_from_system()), OS.get_process_id()]


func boot_city(kind: String, quality: String, real_clock: bool) -> bool:
	if is_instance_valid(game):
		game.can_save = false
		game.queue_free()
		await game.tree_exited
		await frames(2)
	var dir := out.path_join("profiles").path_join("%s_%s_%s" % [started, kind, quality])
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return false
	GamePaths._dir = dir
	if kind == "owner" and DirAccess.copy_absolute(OWNER, dir.path_join("city.json")) != OK:
		return false
	var settings := FileAccess.open(dir.path_join("settings.json"), FileAccess.WRITE)
	if settings == null:
		return false
	settings.store_string(JSON.stringify({"quality": quality, "quality_user": true, "fullscreen": false, "fps_cap": 0}))
	settings.close()
	Game.boot = {"play" if kind == "owner" else "new": "1", "nologin": "1"}
	if not real_clock:
		Game.boot["hour"] = "9"
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	add_child(game)
	while not game.ready_done:
		await frames(1)
	game.can_save = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	return true


func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func set_quality(quality: String) -> void:
	game.settings["quality"] = quality
	game._apply_quality()
	Gfx.swap_all()


func set_view(views: Array, index: int) -> void:
	var v: Array = views[index]
	game.rig.set_view(Vector3(v[0], game.land.height_at(v[0], v[1]), v[1]), v[2], v[3], v[4])


func open_battle(durable: bool, done := Callable()) -> LegionBattle:
	var squad := []
	var wave := []
	var allies := ["legionary", "archer", "spearman", "cavalry"]
	var enemies := ["gaul", "gaulArcher", "briton", "horseArcher"]
	for i in 16:
		squad.append(Legion.unit_stats(allies[i % 4], 5))
		wave.append(Legion.enemy_stats(enemies[i % 4], 1.0))
	if durable:
		for stat: Dictionary in squad + wave:
			stat["hp"] = float(stat["hp"]) * 1000.0
	var battle_data := {"kind": "campaign", "stage": Legion.stage(0, 0, 0),
		"seed": 532, "squad": squad, "waves": [wave], "rations_paid": true, "perks": {}}
	return LegionBattle.open(game, battle_data, done, {"legion": game.city.legion, "speed": 1.0 if durable else 3.0, "auto": not durable})
