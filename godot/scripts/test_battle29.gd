extends Node

const View = preload("res://scripts/legion_battle_view.gd")
const Battle12 = preload("res://scripts/test_battle12.gd")
const Battle13 = preload("res://scripts/test_battle13.gd")
const OUT := "D:/CivCity/.work/stage7/battle29e"
const FRAME := 1.0 / 60.0
const VIDEO_SIZE := Vector2i(1080, 1920)
const CLIP_START := 216
const CLIP_FRAMES := 360
const BASE_STRIKES := {"tutorial": 4, "britannia": 75, "carthage": 147, "hills": 32,
	"parthia": 190, "16x16": 172, "promo": 228}

var game: Game
var battle: LegionBattle
var output := OUT
var version := "after"
var failures := 0
var video := true
var diagnose := false
var checks := false
var air := 0
var strikes := 0
var focus := 0.0
var strike_context := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			output = arg.trim_prefix("out=")
		elif arg.begins_with("mode="):
			version = arg.trim_prefix("mode=")
		elif arg == "metrics-only":
			video = false
		elif arg == "diagnose":
			diagnose = true
			video = false
		elif arg == "checks":
			checks = true
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
		if checks:
			await _regression_fixtures()
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
	if diagnose:
		await _play("britannia", _campaign("britannia", ["briton", "chariot", "charioteer", "druid"]))
		await _play("carthage", _campaign("carthage", ["elephant", "mercenary", "slinger"]))
		await _play("16x16", _campaign("gaul", ["gaul", "gaul", "gaulArcher", "druid"], 16))
		return
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


func _regression_fixtures() -> void:
	var spacing := Battle12.new()
	spacing.run_suite = false
	add_child(spacing)
	await spacing.run_on(game, output.path_join("shots/battle12_" + version))
	_check(spacing.fails <= 1, "battle spacing and contacts")
	var scoring := Battle13.new()
	scoring.run_suite = false
	add_child(scoring)
	await scoring.run_on(game, output.path_join("shots/battle13_" + version))
	_check(scoring.fails == 0, "score and timeout")
	game.queue_free()
	await get_tree().process_frame
	for name_: String in ["enemy3d", "legion7e", "bowanim", "legion12", "fortcut"]:
		get_window().content_scale_size = Vector2i.ZERO
		get_window().size = Vector2i(1920, 1080)
		var script := load("res://scripts/test_%s.gd" % name_) as GDScript
		var fixture: Node = script.new()
		fixture.set("embedded_output", output.path_join("shots/%s_%s" % [name_, version]) + "/")
		call_deferred("add_child", fixture)
		await Signal(fixture, "check_done")
		_check(int(fixture.get("fails")) <= (1 if name_ == "fortcut" else 0), name_)
		fixture.queue_free()
		await get_tree().process_frame


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
	strike_context.clear()
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
	view.melee_event.connect(_count_request)
	var track := Readings.new()
	var spacing := FileAccess.open(output.path_join("spacing_%s_%s.csv" % [label, version]), FileAccess.WRITE) \
		if label in ["britannia", "carthage"] else null
	if spacing != null:
		spacing.store_line("frame,ally_layout_p95,ally_display_p95,long_layout_p95,long_display_p95,mean_display_lag_widths")
	var path := output.path_join("frames").path_join(label + "_" + version)
	capture = capture and video and _check(DirAccess.make_dir_recursive_absolute(path) == OK, path)
	var tick_times: Array[float] = []
	var peak := 0
	var clips := 0
	var profile_frames := 0
	for frame in 60 * 182:
		view.profile_display = label == "16x16" and view._fighters.size() == 32 and frame >= 240
		profile_frames += int(view.profile_display)
		var started := Time.get_ticks_usec()
		battle._process(FRAME)
		var elapsed := Time.get_ticks_usec() - started
		if view._fighters.size() == 32 and frame >= 240:
			tick_times.append(elapsed / 1000.0)
		track.measure(view, battle.phase in ["intro", "fight"], battle.tut_freeze)
		if spacing != null:
			_measure_spacing(view, frame, spacing)
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
	stats["melee_requests"] = view.melee_requests
	stats["hidden_strikes"] = view.melee_requests - view.melee_played
	stats["hidden_pct"] = 100.0 * int(stats["hidden_strikes"]) / maxi(1, view.melee_requests)
	stats["peak"] = peak
	stats["strike_context"] = strike_context
	stats["outcome"] = battle.sim.result
	if label == "16x16":
		_check(peak == 32 and not tick_times.is_empty(), "16x16 timing samples")
		tick_times.sort()
		stats["script_mean_ms"] = tick_times.reduce(func(total: float, ms: float) -> float: return total + ms, 0.0) / maxf(1.0, tick_times.size())
		stats["script_p99_ms"] = tick_times[maxi(0, ceili(tick_times.size() * 0.99) - 1)] if not tick_times.is_empty() else 0.0
		var to_ms := 0.001 / maxf(1.0, profile_frames)
		print("BATTLE29 PROFILE frames=%d layout=%.3f ms follower=%.3f ms gaps=%.3f ms" %
			[profile_frames, view.layout_usec * to_ms, view.display_usec * to_ms, view.display_gaps_usec * to_ms])
	print("BATTLE29 METRICS ", label, " ", JSON.stringify(stats))
	if version != "before":
		_check(track.teleports == 0, label + " teleports")
		_check(track.quick_swaps == 0, label + " unwalked side swaps")
		_check(track.front_crossings == 0 and track.wrong_side == 0, label + " front crossings")
		_check(float(stats["overlap_pct"]) <= 1.0, label + " foot overlap <= 1%")
		_check(strikes >= float(BASE_STRIKES[label]) * 0.80 or float(stats["hidden_pct"]) <= 25.0,
			label + " visible or hidden strikes")
		_check(air == 0 and strikes > 0, label + " contact strikes")
		if not diagnose:
			_check(float(stats["slide_pct"]) <= 0.30, label + " slides <= 0.30%")
			if label == "16x16":
				_check(float(stats["script_mean_ms"]) <= 4.60, label + " script budget <= 4.60 ms")
	battle.abort()
	await get_tree().process_frame


func _count_request(source: View.Fighter, target: View.Fighter) -> void:
	var state := "before_front"
	if source.view._front_active:
		if source.pass_phase != View.Pass.NONE:
			state = "passing"
		elif source.rank > 0:
			state = "queued"
		elif source.can_strike(target):
			state = "in_contact"
		elif target.rear:
			state = "rear_target"
		elif target.rank > 0:
			state = "queued_target"
		else:
			state = "front_out_of_reach"
	strike_context[state] = int(strike_context.get(state, 0)) + 1


func _strike(source: View.Fighter, target: View.Fighter) -> void:
	strikes += 1
	air += int(not source.can_strike(target))


func _measure_spacing(view: View, frame: int, log_file: FileAccess) -> void:
	var living: Array[View.Fighter] = []
	var display: Array[Rect2] = []
	var layout: Array[Rect2] = []
	var lag := 0.0
	for f: View.Fighter in view._fighters:
		if not f.unit.alive:
			continue
		living.append(f)
		var box := f.screen_box()
		var offset := f.layout_pos - f.visible_foot()
		display.append(box)
		layout.append(Rect2(box.position + offset * view.world.scale, box.size))
		lag += offset.length() / f.body_width()
	var ally_layout: Array[float] = []
	var ally_display: Array[float] = []
	var long_layout: Array[float] = []
	var long_display: Array[float] = []
	for i in living.size():
		var a := living[i]
		for j in i:
			var b := living[j]
			if a.unit.side == "ally" and b.unit.side == "ally":
				ally_layout.append(_box_overlap(layout[i], layout[j]))
				ally_display.append(_box_overlap(display[i], display[j]))
			elif a.unit.side != b.unit.side and (not a.long_model.is_empty() or not b.long_model.is_empty()):
				long_layout.append(_box_overlap(layout[i], layout[j]))
				long_display.append(_box_overlap(display[i], display[j]))
	log_file.store_line("%d,%.4f,%.4f,%.4f,%.4f,%.4f" % [frame, _p95(ally_layout),
		_p95(ally_display), _p95(long_layout), _p95(long_display), lag / maxf(1.0, living.size())])


func _p95(values: Array[float]) -> float:
	values.sort()
	return values[ceili(values.size() * 0.95) - 1] if not values.is_empty() else 0.0


func _box_overlap(a: Rect2, b: Rect2) -> float:
	return a.intersection(b).get_area() / maxf(1.0, minf(a.get_area(), b.get_area()))


func _frame_pose(view: View, frame: int) -> void:
	var sum := 0.0
	var weights := 0.0
	for f: View.Fighter in view._fighters:
		if f.unit.alive and absf(f.position.x) < 570.0:
			var weight := 2.5 if f.unit.key == "hero" or f.unit.boss else 1.0
			sum += (view.screen(f.position).x - view.size.x * 0.5) * weight
			weights += weight
	if weights > 0.0:
		var center := sum / weights
		if view._front_active:
			var front := view.screen(Vector2(view._front_x, 0.0)).x - view.size.x * 0.5
			center = lerpf(center, front, 0.80)
		focus = lerpf(focus, center, 0.036)
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
	var front_crossings := 0
	var wrong_side := 0
	var walks_around := 0
	var queue_samples := 0
	var queue_short := 0
	var queue_min := INF
	var queue_plan_min := INF

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
			var front_side := 0
			if view._front_active:
				var x := (foot.x - view._front_x) * f.side_dir
				front_side = 1 if x >= -0.01 else -1
				if front_side < 0 and f.on_own_side():
					wrong_side += 1
				if not last.is_empty() and int(last[5]) * front_side < 0:
					if f.display_passing and absf(foot.y) >= view._trail_depth - 4.0:
						walks_around += 1
					else:
						front_crossings += 1
				var ahead := f.queue_ahead
				if is_instance_valid(ahead) and ahead.unit.alive:
					var edges := f.edge_toward(-f.side_dir) + ahead.edge_toward(f.side_dir)
					var gap := ((foot.x - ahead.visible_foot().x) * f.side_dir - edges) / width
					var planned := ((f.layout_pos.x - ahead.layout_pos.x) * f.side_dir - edges) / width
					queue_min = minf(queue_min, gap)
					queue_plan_min = minf(queue_plan_min, planned)
					queue_samples += 1
					queue_short += int(gap < View.QUEUE_GAP - 0.01)
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
					var walked := is_instance_valid(target) and (f.display_passing or target.display_passing) \
						and (absf(foot.y) >= view._trail_depth - 4.0 or absf(target.visible_foot().y) >= view._trail_depth - 4.0)
					crossing = bool(last[4]) or (walked and movement < 0.25)
					if side == 0.0:
						side = float(last[3])
					elif side * float(last[3]) < 0.0:
						swaps += 1
						quick_swaps += int(not crossing)
						crossing = false
			current[f.unit.id] = [foot, direction, target_id, side, crossing, front_side]
		previous = current

	func result() -> Dictionary:
		distances.sort()
		var samples := distances.size()
		return {"samples": samples, "max": distances[samples - 1] if samples else 0.0,
			"p99": distances[ceili(samples * 0.99) - 1] if samples else 0.0, "teleports": teleports,
			"swaps": swaps, "unwalked_swaps": quick_swaps, "reversals_s": 60.0 * reversals / maxf(1.0, samples),
			"slides": slides, "slide_pct": 100.0 * slides / maxf(1.0, samples),
			"overlap_pct": 100.0 * overlaps / maxf(1.0, pairs), "deep": deep,
			"front_crossings": front_crossings, "wrong_side_frames": wrong_side, "walks_around": walks_around,
			"queue_gap_min": queue_min if queue_samples > 0 else null,
			"queue_plan_min": queue_plan_min if queue_samples > 0 else null,
			"queue_samples": queue_samples, "queue_below_target": queue_short}
