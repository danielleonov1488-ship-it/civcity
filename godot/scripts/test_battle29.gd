extends Node

const View = preload("res://scripts/legion_battle_view.gd")
const OUT := "D:/CivCity/.work/stage7/battle29c"
const FRAME := 1.0 / 60.0
const VIDEO_SIZE := Vector2i(1080, 1920)
const CLIP_START := 216
const CLIP_FRAMES := 360

var game: Game
var battle: LegionBattle
var output := OUT
var version := "after"
var failures := 0
var video := true
var air := 0
var strikes := 0
var focus := 0.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			output = arg.trim_prefix("out=")
		elif arg.begins_with("mode="):
			version = arg.trim_prefix("mode=")
		elif arg == "metrics-only":
			video = false
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = VIDEO_SIZE if video else Vector2i(1600, 900)
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	game.can_save = false
	game.hero_screen_auto = false
	add_child(game)
	if _check(await _until(func() -> bool: return game.ready_done, 150.0), "ready_done"):
		game.settings["autosave"] = false
		if video:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Engine.max_fps = 0
		_check(DirAccess.make_dir_recursive_absolute(output.path_join("shots")) == OK, "shot directory")
		await _run()
	print("BATTLE29 DONE fails=", failures)
	get_tree().quit(int(failures > 0))


func _check(ok: bool, reason: String) -> bool:
	if not ok:
		failures += 1
		print("BATTLE29 FAIL ", reason)
	return ok


func _until(condition: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return condition.call()


func _run() -> void:
	var legion := game.city.legion
	var tutorial := legion.make_battle(legion.stage_info(0, 0, 0), 29)
	tutorial["tutorial"] = "oil"
	tutorial["perks"] = {"oil": 1}
	if (tutorial["squad"] as Array).is_empty():
		tutorial["squad"] = [Legion.unit_stats("legionary", 2), Legion.unit_stats("archer", 2)]
	await _play("tutorial", tutorial)
	await _play("britannia", _campaign("britannia", ["briton", "chariot", "charioteer", "druid"]), true)
	await _play("carthage", _campaign("carthage", ["elephant", "mercenary", "slinger"]))
	await _play("hills", _campaign("hills", ["boar", "boar", "bear", "forestBear"]))
	await _play("parthia", _campaign("parthia", ["horseArcher", "cataphract", "numidian"]))
	await _play("16x16", _campaign("gaul", ["gaul", "gaul", "gaulArcher", "druid"], 16))
	await _play("promo", _promo(), true)


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
	for i in (16 if count == 16 else foes.size()):
		wave.append(Legion.enemy_stats(foes[i % foes.size()], 1.05))
	for unit: Dictionary in squad + wave:
		unit["hp"] = roundi(float(unit["hp"]) * (5.0 if count == 16 else 2.7))
	return {"kind": "campaign", "stage": stage, "seed": 29, "squad": squad, "waves": [wave],
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


func _play(label: String, setup: Dictionary, capture := false) -> void:
	air = 0
	strikes = 0
	focus = 0.0
	get_window().size = VIDEO_SIZE if capture and video else Vector2i(1920, 1080)
	await get_tree().process_frame
	var options := {"speed": 1.0, "auto": false}
	if label == "promo":
		options = {"speed": 1.0}
	battle = LegionBattle.open(game, setup, Callable(), options)
	battle.set_process(false)
	if not _check(await _until(func() -> bool: return battle.phase == "intro", 90.0), "open " + label):
		battle.abort()
		return
	battle.fade.hide()
	var view := battle.battle_view
	view.melee_pose.connect(_strike)
	var track := Readings.new()
	var path := output.path_join("frames").path_join(label + "_" + version)
	capture = capture and video and _check(DirAccess.make_dir_recursive_absolute(path) == OK, path)
	var tick_times: Array[float] = []
	var peak := 0
	var clips := 0
	for frame in 60 * 182:
		var started := Time.get_ticks_usec()
		battle._process(FRAME)
		var elapsed := Time.get_ticks_usec() - started
		if view._fighters.size() == 32 and frame >= 240:
			tick_times.append(elapsed / 1000.0)
		track.measure(view, battle.phase in ["intro", "fight"], battle.tut_freeze)
		peak = maxi(peak, view._fighters.size())
		if capture and frame >= CLIP_START and clips < CLIP_FRAMES:
			_frame_pose(view, clips)
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			if clips == 0:
				print("BATTLE29 CAPTURE ", label, " ", image.get_size())
				var shot := output.path_join("shots/%s_%s.png" % [label, version])
				if _check(image.save_png(shot) == OK, "save " + shot):
					print("BATTLE29 SHOT ", shot)
			if not _check(image.save_jpg(path.path_join("%05d.jpg" % clips), 0.96) == OK, "capture " + label):
				capture = false
			clips += 1
		elif frame % 120 == 119:
			await get_tree().process_frame
		if battle.tut_freeze:
			battle.use_perk("oil")
		if not battle.sim.result.is_empty():
			break
	_check(not battle.sim.result.is_empty(), "full battle " + label)
	if capture:
		_check(clips == CLIP_FRAMES, "all video frames " + label)
	var stats := track.result()
	stats["air"] = air
	stats["strikes"] = strikes
	stats["peak"] = peak
	stats["outcome"] = battle.sim.result
	if label == "16x16":
		_check(peak == 32 and not tick_times.is_empty(), "16x16 timing samples")
		tick_times.sort()
		stats["script_mean_ms"] = tick_times.reduce(func(total: float, ms: float) -> float: return total + ms, 0.0) / maxf(1.0, tick_times.size())
		stats["script_p99_ms"] = tick_times[maxi(0, ceili(tick_times.size() * 0.99) - 1)] if not tick_times.is_empty() else 0.0
	print("BATTLE29 METRICS ", label, " ", JSON.stringify(stats))
	if version != "before":
		_check(track.teleports == 0, label + " teleports")
		_check(track.quick_swaps == 0, label + " unwalked side swaps")
		_check(air == 0 and strikes > 0, label + " contact strikes")
	battle.abort()
	await get_tree().process_frame


func _strike(source: View.Fighter, target: View.Fighter) -> void:
	strikes += 1
	air += int(not source.can_strike(target))


func _frame_pose(view: View, frame: int) -> void:
	var sum := 0.0
	var weights := 0.0
	for f: View.Fighter in view._fighters:
		if f.unit.alive and absf(f.position.x) < 570.0:
			var weight := 2.5 if f.unit.key == "hero" or f.unit.boss else 1.0
			sum += (view.screen(f.position).x - view.size.x * 0.5) * weight
			weights += weight
	if weights > 0.0:
		focus = lerpf(focus, sum / weights, 0.036)
	var magnify := 2.08 + smoothstep(0.0, 12.0, frame * FRAME) * 0.12
	view.scale = Vector2.ONE * magnify
	view.pivot_offset = Vector2(view.size.x * 0.5, view.world.position.y)
	view.position = Vector2(-focus * magnify, view.size.y * 0.59 - view.world.position.y)
	battle.ui.hide()


class Readings:
	var previous := {}
	var distances := PackedFloat32Array()
	var teleports := 0
	var swaps := 0
	var quick_swaps := 0
	var reversals := 0
	var slides := 0
	var pairs := 0
	var overlaps := 0
	var deep := 0

	func measure(view: View, fighting: bool, frozen: bool) -> void:
		var current := {}
		var living: Array[View.Fighter] = []
		for f in view._fighters:
			if f.unit.alive:
				living.append(f)
		for i in living.size():
			var f := living[i]
			var foot := f.visible_foot()
			var width := f.body_width()
			for j in i:
				var other := living[j]
				var gap := foot.distance_to(other.visible_foot()) / minf(width, other.body_width())
				pairs += 1
				overlaps += int(gap < 0.5)
				deep += int(gap < 0.3)
			var target := f.layout_target
			var side := 0.0
			if is_instance_valid(target) and absf(foot.x - target.visible_foot().x) > target.body_width() * 0.2:
				side = signf(foot.x - target.visible_foot().x)
			var target_id := target.unit.id if is_instance_valid(target) else -1
			var last: Array = previous.get(f.unit.id, [])
			var direction := Vector2.ZERO
			var crossing := false
			if not last.is_empty():
				var delta := foot - (last[0] as Vector2)
				var movement := delta.length() / width
				distances.append(movement)
				var allowed := 1.85
				if f.has_method("move_speed"):
					allowed = float(f.call("move_speed")) / width
				elif f.wide or f.unit.key in ["boar", "cavalry"]:
					allowed = 2.55
				teleports += int(movement > minf(0.25, 1.5 * allowed * FRAME) + 0.0001)
				var moving := movement > FRAME * 0.055
				var walking := f.sprite.animation == &"walk" if f.sprite != null else f.clip == f.walk_clip
				if fighting and not frozen:
					slides += int(walking != moving)
				if moving:
					direction = delta.normalized()
					var old_dir: Vector2 = last[1]
					reversals += int(direction.dot(old_dir) < -0.5)
				if target_id == int(last[2]):
					var walked := f.display_passing and is_instance_valid(target) and absf(foot.y - target.visible_foot().y) >= View.PASS_DEPTH
					crossing = bool(last[4]) or (walked and moving and movement < 0.25)
					if side == 0.0:
						side = float(last[3])
					elif side * float(last[3]) < 0.0:
						swaps += 1
						quick_swaps += int(not crossing)
						crossing = false
			current[f.unit.id] = [foot, direction, target_id, side, crossing]
		previous = current

	func result() -> Dictionary:
		distances.sort()
		var samples := distances.size()
		return {"samples": samples, "max": distances[samples - 1] if samples else 0.0,
			"p99": distances[ceili(samples * 0.99) - 1] if samples else 0.0, "teleports": teleports,
			"swaps": swaps, "unwalked_swaps": quick_swaps, "reversals_s": 60.0 * reversals / maxf(1.0, samples),
			"slides": slides, "slide_pct": 100.0 * slides / maxf(1.0, samples),
			"overlap_pct": 100.0 * overlaps / maxf(1.0, pairs), "deep": deep}
