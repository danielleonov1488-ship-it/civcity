extends Node

const View = preload("res://scripts/legion_battle_view.gd")
const Battle12 = preload("res://scripts/test_battle12.gd")
const Battle13 = preload("res://scripts/test_battle13.gd")
const SimDump = preload("res://scripts/test_sim_dump.gd")
const OUT := "D:/CivCity/.work/stage7/battle29h"
const BASE_HIDDEN := {"tutorial": 0, "britannia": 91, "carthage": 209, "hills": 33,
	"parthia": 161, "16x16": 254, "promo": 70}
const FRAME := 1.0 / 60.0
const GAME_SIZE := Vector2i(1920, 1080)
const SMALL_SIZE := Vector2i(1280, 720)
const PROMO_SIZE := Vector2i(1080, 1920)
const CLIP_START := 216
const CLIP_FRAMES := 360

var game: Game
var battle: LegionBattle
var output := OUT
var version := "after"
var failures := 0
var video := false
var diagnose := false
var checks := false
var base_capture := false
var air := 0
var strikes := 0
var focus := 0.0
var zoom := 2.08
var strike_context := {}
var requests: Array[Dictionary] = []
var latest_request := {}
var played_requests := 0
var arrived_pairs := 0
var arrived_outside := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			output = arg.trim_prefix("out=")
		elif arg.begins_with("mode="):
			version = arg.trim_prefix("mode=")
		elif arg == "metrics-only":
			video = false
		elif arg == "capture":
			video = true
		elif arg == "diagnose":
			diagnose = true
		elif arg == "checks":
			checks = true
		elif arg == "baseline":
			base_capture = true
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = GAME_SIZE
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
		if base_capture:
			await _capture_base()
		await _run()
		if checks:
			_check(SimDump.write_dump(300, output.path_join("sim_300.json"), 20261013, false), "write parity fixture")
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
	if video:
		await _play("promo_720p", _promo(), true, SMALL_SIZE, true)
		await _play("britannia_720p", _campaign("britannia", ["briton", "chariot", "charioteer", "druid"]), true, SMALL_SIZE, true)


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


func _capture_base() -> void:
	var source := load("res://.work/battle29g_base/battle.gd") as GDScript
	if not _check(source != null and source.can_instantiate(), "93ba0f4 capture fixture"):
		return
	get_window().size = GAME_SIZE
	await get_tree().process_frame
	var old: Node = source.open(game, _promo(), Callable(), {"speed": 1.0})
	old.set_process(false)
	if not _check(await _until(func() -> bool: return old.phase == "intro", 90.0), "93ba0f4 open promo"):
		old.abort()
		return
	var path := output.path_join("frames/promo_before")
	_check(DirAccess.make_dir_recursive_absolute(path) == OK, path)
	old.fade.hide()
	for frame in CLIP_START + CLIP_FRAMES:
		old._process(FRAME)
		if frame >= CLIP_START:
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			var shot := path.path_join("%05d.jpg" % (frame - CLIP_START))
			if not _check(image.get_size() == GAME_SIZE and image.save_jpg(shot, 0.92) == OK, "93ba0f4 capture"):
				break
			if frame == CLIP_START:
				print("BATTLE29 SHOT ", shot)
		elif frame % 120 == 119:
			await get_tree().process_frame
	old.abort()
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


func _play(label: String, setup: Dictionary, capture := false, resolution := GAME_SIZE, capture_only := false) -> void:
	air = 0
	strikes = 0
	focus = 0.0
	zoom = 2.08
	strike_context.clear()
	requests.clear()
	latest_request.clear()
	played_requests = 0
	arrived_pairs = 0
	arrived_outside = 0
	get_window().size = resolution
	await get_tree().process_frame
	var options := {"speed": 1.0, "auto": false}
	if label.begins_with("promo"):
		options = {"speed": 1.0}
	battle = LegionBattle.open(game, setup, Callable(), options)
	battle.set_process(false)
	if not _check(await _until(func() -> bool: return battle.phase == "intro", 90.0), "open " + label):
		battle.abort()
		return
	battle.fade.hide()
	var view := battle.battle_view
	_check(Vector2i(view.size) == resolution, label + " game resolution")
	view.melee_pose.connect(_strike)
	view.melee_event.connect(_count_request)
	var track := Readings.new()
	var spacing := FileAccess.open(output.path_join("spacing_%s_%s.csv" % [label, version]), FileAccess.WRITE) \
		if label in ["britannia", "carthage"] else null
	if spacing != null:
		spacing.store_line("frame,ally_layout_p95,ally_display_p95,long_layout_p95,long_display_p95,mean_display_lag_widths")
	var still := resolution == SMALL_SIZE
	var path := output.path_join("shots" if still else "frames").path_join(label + "_" + version)
	if capture and video:
		var disk := DirAccess.open(output)
		if disk != null and disk.get_space_left() < 1500000000:
			print("BATTLE29 CAPTURE SKIP ", label, ": less than 1.5 GB")
			capture = false
	capture = capture and video and _check(DirAccess.make_dir_recursive_absolute(path) == OK, path)
	var tick_times: Array[float] = []
	var peak := 0
	var clips := 0
	var frame_count := 1 if still else CLIP_FRAMES
	var start_frame := CLIP_START + 150 if still else CLIP_START
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
		if capture and frame >= start_frame and clips < frame_count:
			if resolution == PROMO_SIZE:
				_frame_pose(view, clips)
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			if clips == 0:
				print("BATTLE29 CAPTURE ", label, " ", image.get_size())
				_check(image.get_size() == resolution, label + " captured resolution")
			var shot := path.path_join("%05d.jpg" % clips)
			if not _check(image.save_jpg(shot, 0.92) == OK, "capture " + label):
				capture = false
			elif clips == 0:
				print("BATTLE29 SHOT ", shot)
			clips += 1
			if capture_only and (clips == frame_count or not capture):
				break
		elif frame % 120 == 119:
			await get_tree().process_frame
		if battle.tut_freeze:
			battle.use_perk("oil")
		if not battle.sim.result.is_empty():
			break
	if capture:
		_check(clips == frame_count, "all frames " + label)
	if capture_only:
		print("BATTLE29 FRAMING ", label, " rows=", view._front_rows, " row_px=", view._row_step * view.world.scale.y)
		battle.abort()
		await get_tree().process_frame
		return
	_check(not battle.sim.result.is_empty(), "full battle " + label)
	var stats := track.result()
	stats["air"] = air
	stats["strikes"] = strikes
	stats["melee_requests"] = view.melee_requests
	stats["hidden_strikes"] = view.melee_requests - view.melee_played
	stats["hidden_pct"] = 100.0 * int(stats["hidden_strikes"]) / maxi(1, view.melee_requests)
	stats["peak"] = peak
	stats["strike_context"] = strike_context
	stats["arrived_pairs"] = arrived_pairs
	stats["arrived_outside"] = arrived_outside
	stats["row_gap_figure"] = view._row_step / (View.STANDARD_HEIGHT / clampf(view._zoom, 0.94, 1.07))
	stats["outcome"] = battle.sim.result
	if diagnose:
		_write_hidden(label, view.melee_requests - view.melee_played)
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
		_check(int(stats["hidden_strikes"]) <= int(BASE_HIDDEN[label]), label + " hidden strikes <= base")
		_check(track.totem_stacks == 0, label + " steady vertical stacks")
		if label != "tutorial":
			_check(track.totem_samples > 0, label + " steady grid samples")
		_check(arrived_outside == 0, label + " arrived front pairs in reach")
		if label == "tutorial":
			_check(view.melee_played == 4 and view.melee_requests == 4, "tutorial all four strikes")
		_check(air == 0 and strikes > 0, label + " contact strikes")
		_check(float(stats["slide_pct"]) <= 0.30, label + " slides <= 0.30%")
		if label == "16x16":
			_check(float(stats["script_mean_ms"]) <= 4.60, label + " script budget <= 4.60 ms")
	battle.abort()
	await get_tree().process_frame


func _count_request(source: View.Fighter, target: View.Fighter) -> void:
	var state := "before_front"
	var in_reach := source.can_strike(target)
	var front_pair := source.rank == 0 and target.rank == 0 and source.on_own_side() and target.on_own_side()
	if front_pair and source.position.distance_to(source.layout_pos) <= source.body_width() * 0.10 \
			and target.position.distance_to(target.layout_pos) <= target.body_width() * 0.10:
		arrived_pairs += 1
		arrived_outside += int(not in_reach)
	if source.view._front_active:
		if source.pass_phase != View.Pass.NONE:
			state = "passing"
		elif in_reach:
			state = "in_contact"
		elif source.rank > 0:
			state = "queued"
		elif target.rear:
			state = "rear_target"
		elif target.rank > 0:
			state = "queued_target"
		elif front_pair:
			state = "front_out_of_reach"
		else:
			state = "moving_target"
	strike_context[state] = int(strike_context.get(state, 0)) + 1
	if not diagnose:
		return
	var d := target.body_ground() - source.body_ground()
	var edge := source.edge_toward(d.x) if source.wide and source.long_model.is_empty() else source.muzzle
	var gap := maxf(0.0, absf(d.x) - edge - target.edge_toward(-d.x))
	var adjacent := source.neighbouring_row(target)
	var ranked := source.rank >= 0 and target.rank >= 0 and source.on_own_side() and target.on_own_side()
	var depth := absf(d.y) * (View.STRIKE_DEPTH if ranked else 1.0)
	var overlap := Rect2(source.outline.position - d, source.outline.size).intersection(target.outline).get_area()
	var nearest: View.Fighter
	for other in source.view._fighters:
		if other.unit.alive and other.side_dir != source.side_dir and other.rank == 0:
			if nearest == null or absf(other.position.y - source.position.y) < absf(nearest.position.y - source.position.y):
				nearest = other
	latest_request[source.unit.id] = requests.size()
	requests.append({"time": battle.sim.t, "source": source.unit.id, "source_key": source.unit.key,
		"target": target.unit.id, "target_key": target.unit.key, "source_rank": source.rank,
		"target_rank": target.rank, "source_row": source.front_row, "target_row": target.front_row,
		"dx": absf(d.x), "dy": absf(d.y), "edge_gap": gap, "effective": Vector2(gap, depth).length(),
		"reach": source.projected_reach(target), "adjacent": adjacent, "facing": source.flip_h == (d.x < 0.0),
		"overlap": overlap / maxf(1.0, minf(source.outline_area, target.outline_area)),
		"nearest_front": nearest.unit.id if nearest != null else -1, "planned_dx": absf(target.layout_pos.x - source.layout_pos.x),
		"target_alive": target.unit.alive, "source_alive": source.unit.alive, "state": state,
		"contact": in_reach, "visible": false})


func _strike(source: View.Fighter, target: View.Fighter) -> void:
	strikes += 1
	air += int(not source.can_strike(target))
	if diagnose and source.view.melee_played > played_requests:
		played_requests = source.view.melee_played
		var index: int = latest_request.get(source.unit.id, -1)
		if index >= 0 and int(requests[index]["target"]) == target.unit.id:
			requests[index]["visible"] = true


func _write_hidden(label: String, expected: int) -> void:
	var path := output.path_join("hidden_%s_%s.jsonl" % [label, version])
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not _check(file != null, "write " + path):
		return
	var hidden := 0
	for entry in requests:
		if not entry["visible"]:
			file.store_line(JSON.stringify(entry))
			hidden += 1
	_check(hidden == expected, label + " hidden request accounting %d/%d" % [hidden, expected])


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
	var center := view.size.x * 0.5
	var front := view.screen(Vector2(view._front_x, 0.0)).x
	var low := front
	var high := front
	var top := view.world.position.y
	var bottom := top
	for f: View.Fighter in view._fighters:
		if f.unit.alive:
			var box := f.screen_box()
			low = minf(low, box.position.x)
			high = maxf(high, box.end.x)
			top = minf(top, box.position.y)
			bottom = maxf(bottom, box.end.y)
	var anchor := lerpf(front, (low + high) * 0.5, 0.35)
	var desired := 2.08 + smoothstep(0.0, 12.0, frame * FRAME) * 0.12
	var width := view.size.x - 64.0
	var fit := minf(width / maxf(high - low, 1.0), (view.size.y - 160.0) / maxf(bottom - top, 1.0))
	zoom = minf(fit, lerpf(zoom, minf(desired, fit), 0.08))
	var half := width * 0.5 / zoom
	var pan := anchor - center if frame == 0 else lerpf(focus, anchor - center, 0.13)
	focus = clampf(pan, high - half - center, low + half - center)
	view.scale = Vector2.ONE * zoom
	view.pivot_offset = Vector2(center, (top + bottom) * 0.5)
	view.position = Vector2(-focus * zoom, view.size.y * 0.54 - view.pivot_offset.y)
	# Поле остаётся на весь экран при зуме и смещении 3D-фигур.
	view.field.position = view.pivot_offset - (view.pivot_offset + view.position) / zoom
	view.field.scale = Vector2.ONE / zoom
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
	var totem_stacks := 0
	var totem_samples := 0

	func measure(view: View, fighting: bool, frozen: bool) -> void:
		var current := {}
		var living: Array[View.Fighter] = []
		for f in view._fighters:
			if f.unit.alive:
				living.append(f)
		if view._front_active and fighting and not frozen:
			_measure_totems(view, living)
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

	func _measure_totems(view: View, living: Array[View.Fighter]) -> void:
		var steady: Array[View.Fighter] = []
		for f in living:
			if not f.unit.entering and f.travel.length_squared() < (FRAME * f.body_width() * 0.20) ** 2:
				steady.append(f)
		if steady.size() < 3:
			return
		totem_samples += 1
		steady.sort_custom(func(a: View.Fighter, b: View.Fighter) -> bool:
			return a.visible_foot().x < b.visible_foot().x)
		var depth := view._row_step * 0.25
		for i in steady.size() - 2:
			var a := steady[i]
			var a_foot := a.visible_foot()
			for j in range(i + 1, steady.size() - 1):
				var b := steady[j]
				var b_foot := b.visible_foot()
				if b_foot.x - a_foot.x > a.body_width() * 0.30:
					break
				if absf(b_foot.y - a_foot.y) < depth:
					continue
				for k in range(j + 1, steady.size()):
					var c := steady[k]
					var c_foot := c.visible_foot()
					if c_foot.x - a_foot.x > a.body_width() * 0.30:
						break
					var width := minf(a.body_width(), minf(b.body_width(), c.body_width()))
					if c_foot.x - a_foot.x <= width * 0.30 and absf(c_foot.y - a_foot.y) >= depth \
							and absf(c_foot.y - b_foot.y) >= depth:
						totem_stacks += 1

	func result() -> Dictionary:
		distances.sort()
		var samples := distances.size()
		return {"samples": samples, "max": distances[samples - 1] if samples else 0.0,
			"p99": distances[ceili(samples * 0.99) - 1] if samples else 0.0, "teleports": teleports,
			"swaps": swaps, "unwalked_swaps": quick_swaps, "reversals_s": 60.0 * reversals / maxf(1.0, samples),
			"slides": slides, "slide_pct": 100.0 * slides / maxf(1.0, samples),
			"overlap_pct": 100.0 * overlaps / maxf(1.0, pairs), "deep": deep,
			"front_crossings": front_crossings, "wrong_side_frames": wrong_side, "walks_around": walks_around,
			"totem_stacks": totem_stacks, "totem_samples": totem_samples,
			"queue_gap_min": queue_min if queue_samples > 0 else null,
			"queue_plan_min": queue_plan_min if queue_samples > 0 else null,
			"queue_samples": queue_samples, "queue_below_target": queue_short}
