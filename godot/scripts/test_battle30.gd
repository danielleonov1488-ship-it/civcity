extends Node

## BATTLE30: бой как в Hustle Castle — замер рывков, ударов из-за спины, бойцов друг в друге и запись роликов.
## Аргументы: out=<папка> capture (писать кадры) base (снять исходный бой 93ba0f4 из .work/battle29g_base)
## only=<имя,имя> — только выбранные бои.

const OUT := "D:/CivCity/.work/stage7/battle30/run"
const FRAME := 1.0 / 60.0
const SIZE := Vector2i(1920, 1080)
const CLIP_START := 150
const CLIP_FRAMES := 600

var game: Game
var output := OUT
var capture := false
var base := false
var base_only := false
var only: PackedStringArray = []
var failures := 0
var requests := 0
var played := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			output = arg.trim_prefix("out=")
		elif arg == "capture":
			capture = true
		elif arg == "base":
			base = true
		elif arg == "baseonly":
			base = true
			base_only = true
		elif arg.begins_with("only="):
			only = arg.trim_prefix("only=").split(",")
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = SIZE
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	game.can_save = false
	game.hero_screen_auto = false
	add_child(game)
	if _check(await _until(func() -> bool: return game.ready_done, 150.0), "ready_done"):
		game.settings["autosave"] = false
		DirAccess.make_dir_recursive_absolute(output)
		for label: String in ["tutorial", "stage", "promo", "britannia", "carthage", "big"]:
			if only.is_empty() or label in only:
				if not base_only:
					await _play(label, false)
				if base:
					await _play(label, true)
	print("BATTLE30 DONE fails=", failures)
	get_tree().quit(int(failures > 0))


func _check(ok: bool, reason: String) -> bool:
	if not ok:
		failures += 1
		print("BATTLE30 FAIL ", reason)
	return ok


func _until(condition: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return condition.call()


func _setup(label: String) -> Dictionary:
	var legion := game.city.legion
	match label:
		"tutorial":
			var tutorial := legion.make_battle(legion.stage_info(0, 0, 0), 30)
			tutorial["tutorial"] = "oil"
			tutorial["perks"] = {"oil": 1}
			if (tutorial["squad"] as Array).is_empty():
				tutorial["squad"] = [Legion.unit_stats("legionary", 2), Legion.unit_stats("archer", 2)]
			return tutorial
		"stage":
			# Обычный бой кампании, как у игрока: пять бойцов, здоровье без множителей.
			var setup := legion.make_battle(legion.stage_info(0, 1, 3), 30)
			setup.erase("tutorial")
			var squad: Array[Dictionary] = []
			for kind: String in ["legionary", "legionary", "spearman", "archer", "priest"]:
				squad.append(Legion.unit_stats(kind, 3))
			setup["squad"] = squad
			return setup
		"promo":
			return _promo()
		"britannia":
			return _campaign("britannia", ["briton", "chariot", "charioteer", "druid"])
		"carthage":
			return _campaign("carthage", ["elephant", "mercenary", "slinger"])
		"big":
			return _campaign("gaul", ["gaul", "gaul", "gaulArcher", "druid"], 10)
	return {}


func _campaign(region: String, foes: Array, count := 6) -> Dictionary:
	var r := 0
	for i in Legion.regions().size():
		if Legion.regions()[i]["id"] == region:
			r = i
	var stage := Legion.stage(0, r, 0)
	var roles := ["legionary", "spearman", "cavalry", "legionary", "archer", "priest"]
	var squad: Array[Dictionary] = []
	var wave: Array[Dictionary] = []
	for i in count:
		squad.append(Legion.unit_stats(roles[i % roles.size()], 5))
	for i in (count if count > 6 else foes.size()):
		wave.append(Legion.enemy_stats(foes[i % foes.size()], 1.05))
	for unit: Dictionary in squad + wave:
		unit["hp"] = roundi(float(unit["hp"]) * 2.0)
	return {"kind": "campaign", "stage": stage, "seed": 30, "squad": squad, "waves": [wave],
		"rations_paid": true, "perks": {}}


func _promo() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 28
	game.city.hero = Hero.random(rng, 0)
	var legion := game.city.legion
	var setup := legion.make_battle(legion.stage_info(0, 2, 5), 28)
	setup.erase("tutorial")
	var hero := Legion.hero_unit_stats(3, 4, 2)
	hero["hero"] = true
	var squad: Array[Dictionary] = [hero]
	for kind: String in ["legionary", "legionary", "archer", "cavalry", "priest"]:
		squad.append(Legion.unit_stats(kind, 3))
	var gauls: Array[Dictionary] = []
	for kind: String in ["vercingetorix", "gaul", "gaul", "gaul", "gaulArcher", "druid", "boar"]:
		gauls.append(Legion.enemy_stats(kind, 1.05))
	for unit: Dictionary in squad + gauls:
		unit["hp"] = roundi(float(unit["hp"]) * 2.7)
	setup["squad"] = squad
	setup["waves"] = [gauls]
	setup["packs"] = []
	setup["hero_look"] = Hero.battle_look(game.city, 2)
	return setup


func _count_request(_source, _target) -> void:
	requests += 1


func _count_played(_source, _target) -> void:
	played += 1


func _play(label: String, old: bool) -> void:
	var name_ := label + ("_base" if old else "_new")
	requests = 0
	played = 0
	get_window().size = SIZE
	await get_tree().process_frame
	var setup := _setup(label)
	var battle: Node
	if old:
		var source: GDScript = load("res://b30_fixture/battle.gd")
		battle = source.open(game, setup, Callable(), {"speed": 1.0})
	else:
		battle = LegionBattle.open(game, setup, Callable(), {"speed": 1.0})
	battle.set_process(false)
	if not _check(await _until(func() -> bool: return battle.phase == "intro", 90.0), "open " + name_):
		battle.abort()
		return
	battle.fade.hide()
	var view: Control = battle.battle_view
	view.melee_event.connect(_count_request)
	view.melee_pose.connect(_count_played)
	var path := output.path_join("frames").path_join(name_)
	var shooting := capture and DirAccess.make_dir_recursive_absolute(path) == OK
	var last := {}
	var frames := 0
	var teleports := 0
	var max_step := 0.0
	var behind := 0
	var behind_goal := 0
	var behind_mutual := 0
	var engaged := 0
	var inside := 0
	var pairs := 0
	var idle := 0
	var melee_samples := 0
	var clips := 0
	for frame in 60 * 182:
		battle._process(FRAME)
		var fighting: bool = battle.phase in ["intro", "fight"] and not battle.tut_freeze
		var alive: Array = []
		for f in view._fighters:
			if f.unit.alive:
				alive.append(f)
		if fighting and frame > 30:
			frames += 1
			for f in alive:
				var width: float = maxf(f.body_width(), 1.0)
				var id: int = f.unit.id
				if last.has(id):
					var step: float = (f.position - last[id]).length() / width
					max_step = maxf(max_step, step)
					if step > 0.25:
						teleports += 1
				last[id] = f.position
				if f.rear or f.unit.entering:
					continue
				melee_samples += 1
				var t = f.layout_target
				if t != null and t.unit.alive and f.contact_blend >= 0.95 and t.long_model.is_empty() and f.long_model.is_empty():
					engaged += 1
					if (f.position.x - t.position.x) * f.side_dir < -0.15 * width:
						behind += 1
						if (f.goal.x - t.goal.x) * f.side_dir < -0.15 * width:
							behind_goal += 1
						if f.slot == 1 and t.layout_target == f:
							behind_mutual += 1
				if t == null and not f.unit.moving and f.unit.target != null and f.unit.target.alive and f.travel.length() < 0.05:
					idle += 1
			for i in alive.size():
				var a = alive[i]
				for j in i:
					var b = alive[j]
					if a.side_dir == b.side_dir or a.wide or b.wide:
						continue
					pairs += 1
					var w: float = minf(a.body_width(), b.body_width())
					if absf(a.position.x - b.position.x) < w * 0.35 and absf(a.position.y - b.position.y) < 22.0:
						inside += 1
		if shooting and frame >= CLIP_START and clips < CLIP_FRAMES:
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			if image.save_jpg(path.path_join("%05d.jpg" % clips), 0.9) != OK:
				shooting = false
			clips += 1
		elif frame % 120 == 119:
			await get_tree().process_frame
		if battle.tut_freeze:
			battle.use_perk("oil")
		if not battle.sim.result.is_empty():
			break
	var stats := {
		"frames": frames, "teleports": teleports, "max_step_bw": snappedf(max_step, 0.001),
		"behind_pct": snappedf(100.0 * behind / maxi(1, engaged), 0.01),
		"behind_goal": behind_goal, "behind_mutual": behind_mutual, "behind": behind,
		"inside_pct": snappedf(100.0 * inside / maxi(1, pairs), 0.001),
		"idle_pct": snappedf(100.0 * idle / maxi(1, melee_samples), 0.01),
		"strikes_played": played, "strike_requests": requests, "clips": clips,
		"outcome": battle.sim.result,
	}
	print("BATTLE30 METRICS ", name_, " ", JSON.stringify(stats))
	if not old:
		_check(teleports == 0, name_ + " teleports")
	battle.abort()
	await get_tree().process_frame
	await get_tree().process_frame
