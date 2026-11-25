extends Node
## Полные бои с шагом замера 0,1 с и кадры настоящего экрана.

const View = preload("res://scripts/legion_battle_view.gd")
const EnemyTest = preload("res://scripts/test_enemy3d.gd")
const OUT := "D:/CivCity/.work/stage7/battle12d/shots/"
const HD := Vector2i(1920, 1080)
const SMALL := Vector2i(1280, 720)
const SEED := 532

var fails := 0
var game: Game
var battle: LegionBattle
var output := OUT
var legacy := false
var label := ""
var strikes := 0
var requests := 0
var event_air := 0
var air := 0
var low := 0
var overlaps := 0
var pairs := 0
var bounds_misses := 0
var rear_misses := 0
var rear_samples := 0
var rear_min := INF
var multi := 0
var two_on_one: Array[float] = []
var three_on_one: Array[float] = []
var heights := PackedFloat32Array()
var ally_boxes: Array[float] = []
var big_boxes: Array[float] = []
var horse_line_min := INF
var horse_line_samples := 0
var flank_samples := [0, 0]
var flank_clear := [0, 0]
var battle_flanks := [0, 0]
var battle_groups := [0, 0]
var numbers_peak := 0
var numbers_per_target := 0
var numbers_overlap := 0.0
var forest_before: Image
var forest_after: Image
var multi_shot := false
var busy_shot := false
var compare_sample := 0
var run_suite := true


func _ready() -> void:
	if not run_suite:
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			output = arg.trim_prefix("out=").trim_suffix("/") + "/"
		elif arg.begins_with("compare="):
			compare_sample = int(arg.trim_prefix("compare="))
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = HD
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	game.can_save = false
	game.hero_screen_auto = false
	add_child(game)
	if check(await _until(func() -> bool: return game.ready_done, 150.0), "ready_done"):
		game.settings["autosave"] = false
		await run_on(game, output)
	else:
		print("BATTLE12 DONE fails=", fails)
	get_tree().quit(int(fails != 0))


func run_on(test_game: Game, shots: String) -> void:
	game = test_game
	output = shots
	if check(DisplayServer.get_name() != "headless", "graphics required") and check(
			DirAccess.make_dir_recursive_absolute(output) == OK, "shot directory"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		await _run()
	print("BATTLE12 DONE fails=", fails)


func check(ok: bool, reason: String) -> bool:
	if not ok:
		fails += 1
		print("BATTLE12 FAIL ", reason)
	return ok


func _until(condition: Callable, seconds: float) -> bool:
	var finish := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < finish:
		await get_tree().process_frame
	return condition.call()


func _capture() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _save(file: String, image: Image) -> void:
	var path := output.path_join(file)
	if check(image != null and image.save_png(path) == OK, "save " + path):
		print("BATTLE12 SHOT ", path)


func _campaign(region: String, wave1: Array, wave2: Array) -> Dictionary:
	var r := 0
	for index in Legion.regions().size():
		if Legion.regions()[index]["id"] == region:
			r = index
	var stage := Legion.stage(0, r, 0)
	var squad := [Legion.unit_stats("legionary", 8), Legion.unit_stats("spearman", 8),
		Legion.unit_stats("legionary", 8), Legion.unit_stats("archer", 8), Legion.unit_stats("priest", 8)]
	for entry: Dictionary in squad:
		entry["hp"] = float(entry["hp"]) * 2.1
	var waves := []
	for keys: Array in [wave1, wave2]:
		var wave := []
		for key: String in keys:
			wave.append(Legion.enemy_stats(key, 0.92))
		waves.append(wave)
	return {"kind": "campaign", "stage": stage, "seed": SEED, "squad": squad, "waves": waves,
		"rations_paid": true, "perks": {}}


func _pvp() -> Dictionary:
	var front := [{"type": "legionary", "level": 7}, {"type": "spearman", "level": 7},
		{"type": "legionary", "level": 7}, {"type": "archer", "level": 7}, {"type": "priest", "level": 7}]
	var enemies := [{"type": "legionary", "level": 7}, {"type": "spearman", "level": 7},
		{"type": "legionary", "level": 7}, {"type": "archer", "level": 7}]
	return game.city.legion.make_pvp_battle({"name": "Тускулум", "rating": 240, "city_level": 5,
		"attack": {"v": 1, "squad": front}, "snapshot": {"v": 1, "squad": enemies}, "seed": 701})


func _run() -> void:
	var forest := _campaign("forest", ["forestBear", "bandit", "slinger"], ["greatbear", "chief"])
	var baseline := await _play("forest-before", forest, HD, 3.0, "", 1, true)
	var result := await _play("forest", forest, HD, 3.0, "1_battle_forest.png", 1)
	check(result == baseline and not result.is_empty(), "forest result matches legacy layout")
	if forest_before != null and forest_after != null:
		var compared := Image.create(HD.x * 2, HD.y, false, Image.FORMAT_RGBA8)
		_put(compared, forest_before, Vector2i.ZERO)
		_put(compared, forest_after, Vector2i(HD.x, 0))
		_save("7_before_after.png", compared)
	await _play("gaul", _campaign("gaul", ["gaul", "gaul", "gaulArcher"], ["vercingetorix", "druid"]), SMALL, 2.0, "", 1)
	await _play("carthage", _campaign("carthage", ["mercenary", "slinger"], ["elephant", "mercenary"]), HD, 1.0, "4_carthage_elephant.png", 1)
	await _play("britannia", _campaign("britannia", ["briton", "druid"], ["chariot", "charioteer", "briton"]), SMALL, 3.0, "4_battle_chariots.png", 1)
	await _play("parthia", _campaign("parthia", ["horseArcher", "numidian", "cataphractFoe"],
		["cataphract", "horseArcher"]), HD, 3.0, "5_battle_ranged.png", 0)
	var pvp := await _play("pvp", _pvp(), SMALL, 2.0, "6_pvp.png", 0)
	check(not pvp.is_empty(), "PvP replay finished")
	check(multi_shot, "neighbouring front rows shot")
	check(busy_shot, "busy damage numbers shot")
	for i in 2:
		print("BATTLE12 FLANKS %d-on-1 separated=%d/%d" % [i + 2, flank_clear[i], flank_samples[i]])
		if i == 0 or flank_samples[i] > 0:
			check(flank_samples[i] > 0 and flank_clear[i] * 100 >= flank_samples[i] * 95,
				"%d-on-1 neighbouring rows on own side in at least 95%% of contact samples" % (i + 2))
	_check_boxes()
	await _fort()
	await _benchmark()
	var contacts := EnemyTest.new()
	contacts.run_suite = false
	add_child(contacts)
	get_window().size = HD
	await contacts.battle12_contacts(game, output)
	check(contacts.fails == 0, "Britannia and Africa contact regressions")
	print("BATTLE12 CONTACTS fails=", contacts.fails)
	contacts.queue_free()


func _put(dest: Image, piece: Image, at: Vector2i) -> void:
	piece.convert(dest.get_format())
	dest.blit_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), at)


func _events(source: View.Fighter, target: View.Fighter) -> void:
	requests += 1
	if not source.can_strike(target):
		event_air += 1
		if not legacy:
			print("BATTLE12 APPROACH %s %s ? %s at %.2f" % [label, source.unit.name, target.unit.name, battle.sim.t])


func _striking(source: View.Fighter, target: View.Fighter) -> void:
	strikes += 1
	if not source.can_strike(target):
		air += 1
		if not legacy:
			check(false, "%s air strike %s → %s at %.2f" % [label, source.unit.name, target.unit.name, battle.sim.t])


func _play(name_: String, setup: Dictionary, resolution: Vector2i, speed: float, file: String,
		wave: int, before := false) -> Dictionary:
	label = name_
	legacy = before
	strikes = 0
	requests = 0
	event_air = 0
	air = 0
	pairs = 0
	low = 0
	overlaps = 0
	bounds_misses = 0
	rear_misses = 0
	rear_samples = 0
	rear_min = INF
	multi = 0
	heights.clear()
	ally_boxes.clear()
	big_boxes.clear()
	horse_line_min = INF
	horse_line_samples = 0
	battle_flanks = [0, 0]
	battle_groups = [0, 0]
	numbers_peak = 0
	numbers_per_target = 0
	numbers_overlap = 0.0
	get_window().size = resolution
	battle = LegionBattle.open(game, setup.duplicate(true), Callable(),
		{"legion": game.city.legion, "speed": speed, "auto": false, "legacy_layout": before})
	battle.set_process(false)
	if not check(await _until(func() -> bool: return battle.phase == "intro", 30.0), "open " + label):
		battle.abort()
		return {}
	battle.fade.hide()
	battle.battle_view.melee_pose.connect(_striking)
	battle.battle_view.melee_event.connect(_events)
	var shown := false
	var samples := 0
	var view := battle.battle_view
	if name_ == "gaul":
		_number_fixture(view._fighters[0])
	while battle.sim.result.is_empty() and samples < 1801:
		# Одинаковые шаги симуляции даже при медленном видеодрайвере.
		for step in 6:
			battle._process(0.1 / (6.0 * speed))
		samples += 1
		var meeting := _measure(view)
		if not before:
			_measure_numbers()
		if name_ == "gaul" and compare_sample == samples:
			_save("gaul_after.png", await _capture())
		if meeting != null and not multi_shot and not before and name_ != "forest":
			await _save_meeting(view, meeting, samples)
		if not before and not busy_shot and battle.sim.wave_idx >= 1 and battle.bars.floats.size() >= 8:
			_save("3_numbers.png", await _capture())
			busy_shot = true
		var forest_sample := (name_ == "forest" or before) and samples == 60
		if forest_sample:
			if before:
				forest_before = await _capture()
			else:
				forest_after = await _capture()
		if not shown and file != "" and battle.sim.wave_idx >= wave and _shot_ready(view, wave):
			_save(file, await _capture())
			shown = true
		await get_tree().process_frame
	check(not battle.sim.result.is_empty(), "full battle " + label)
	if file != "":
		check(shown, "battle screenshot " + file)
	heights.sort()
	var median := heights[heights.size() / 2] if not heights.is_empty() else 0.0
	var overlap_pct := 100.0 * float(overlaps) / maxf(1.0, pairs)
	print("BATTLE12 METRICS %s %dx%d x%.0f samples=%d median=%.2f%% overlap=%.3f%% (%d/%d) below30=%d melee=%d/%d air=%d event_outside=%d two_on_one=%d rear_min=%.2f rear_below2=%d/%d outside_field=%d" %
		[label, resolution.x, resolution.y, speed, samples, median * 100, overlap_pct, overlaps, pairs, low, strikes, requests,
		air, event_air, multi, rear_min, rear_misses, rear_samples, bounds_misses])
	if not before:
		var allies := _p95(ally_boxes)
		var big := _p95(big_boxes)
		print("BATTLE12 SEPARATION %s allies_p95=%.3f (%d) big_p95=%.3f (%d)" %
			[label, allies, ally_boxes.size(), big, big_boxes.size()])
		print("BATTLE12 NUMBERS %s max_overlap=%.3f per_target=%d total=%d" %
			[label, numbers_overlap, numbers_per_target, numbers_peak])
		print("BATTLE12 GROUPS %s 2=%d/%d 3=%d/%d" %
			[label, battle_flanks[0], battle_groups[0], battle_flanks[1], battle_groups[1]])
		check(not ally_boxes.is_empty() and allies <= 0.25, label + " ally screen boxes p95 <= 0.25")
		check(big <= 0.20, label + " long body screen boxes p95 <= 0.20")
		if name_ in ["carthage", "britannia", "parthia"]:
			check(not big_boxes.is_empty(), label + " long model samples")
		if name_ == "parthia":
			print("BATTLE12 MOUNT LINE min=%.1f samples=%d" % [horse_line_min, horse_line_samples])
			check(horse_line_samples > 0 and horse_line_min >= 0.0, "horse archer bodies clear of the Roman line")
		check(numbers_overlap <= 0.20 and numbers_per_target <= 3 and numbers_peak > 0, label + " readable damage numbers")
		check(median >= 0.15 and median <= 0.21, label + " figure height")
		check(overlap_pct <= 1.0 and low == 0, label + " overlap")
		check(strikes > 0 and air == 0, label + " melee contact")
		check(rear_samples > 0 and rear_misses == 0, label + " ranged gap")
		check(bounds_misses == 0, label + " field strip")
	var result := battle.sim.result.duplicate(true)
	battle.abort()
	await get_tree().process_frame
	return result


func _shot_ready(view: View, wave: int) -> bool:
	for f: View.Fighter in view._fighters:
		if f.unit.alive and f.unit.wave == wave and not f.unit.entering:
			if label not in ["britannia", "carthage"]:
				return true
			if f.unit.key == ("charioteer" if label == "britannia" else "elephant"):
				for ally: View.Fighter in view._fighters:
					if ally.unit.side == "ally" and _engaged(ally, f) and ally.attack_left > 0.0:
						return true
	return false


func _number_fixture(target: View.Fighter) -> void:
	var bars := battle.bars
	bars.float_value(target, 25, "hurt", 0.0)
	bars.float_value(target, 37, "crit", 0.15)
	bars.float_value(target, 18, "heal", 0.15)
	check(bars.floats.size() == 2 and bars.floats[0].caption == "62!"
		and bars.floats[1].caption == "+18", "merge hits within 0.15s, preserve crit and heal")
	bars.float_value(target, 40, "hurt", 0.151)
	check(bars.floats.size() == 3 and bars.floats[2].caption == "40", "hit outside the merge window")
	bars.float_value(target, 12, "hurt", 0.50)
	bars.age_floats(0.2)
	check(bars.floats.size() == 3 and bars.floats[0].caption == "+18"
		and bars.floats[0].age > bars.floats[2].age, "cap at three and fade earlier numbers faster")
	bars.floats.clear()


func _measure_numbers() -> void:
	battle.bars.layout_floats()
	var counts := {}
	var boxes := battle.bars.floats
	numbers_peak = maxi(numbers_peak, boxes.size())
	for i in boxes.size():
		var current := boxes[i]
		counts[current.id] = int(counts.get(current.id, 0)) + 1
		numbers_per_target = maxi(numbers_per_target, int(counts[current.id]))
		for j in i:
			numbers_overlap = maxf(numbers_overlap, _overlap(current.box, boxes[j].box))


func _overlap(a: Rect2, b: Rect2) -> float:
	return a.intersection(b).get_area() / maxf(1.0, minf(a.get_area(), b.get_area()))


func _p95(readings: Array[float]) -> float:
	if readings.is_empty():
		return 0.0
	readings.sort()
	return readings[ceili(readings.size() * 0.95) - 1]


func _screen_box(view: View, f: View.Fighter) -> Rect2:
	# Габарит корпуса в проекции, включая морду и зад длинной модели.
	var foot := view.screen(f.visible_foot())
	var height := f.body_height() * view.world.scale.y
	var left := f.edge_toward(-1.0) * view.world.scale.x
	return Rect2(foot - Vector2(left, height), Vector2(f.body_width() * view.world.scale.x, height))


func _engaged(attacker: View.Fighter, target: View.Fighter) -> bool:
	return attacker.unit.alive and attacker.layout_target == target and attacker.rank == 0 \
		and attacker.can_strike(target)


func _save_meeting(view: View, target: View.Fighter, sample: int) -> void:
	var box := _screen_box(view, target)
	var count := 0
	for f: View.Fighter in view._fighters:
		if _engaged(f, target):
			box = box.merge(_screen_box(view, f))
			count += 1
	if count < 2:
		return
	var whole := await _capture()
	var rect := Rect2i(box.grow(box.size.y * 0.48)).intersection(Rect2i(Vector2i.ZERO, whole.get_size()))
	var close_up := whole.get_region(rect)
	close_up.resize(rect.size.x * 3 / 2, rect.size.y * 3 / 2, Image.INTERPOLATE_LANCZOS)
	var canvas := Image.create(whole.get_width() + close_up.get_width(),
		maxi(whole.get_height(), close_up.get_height()), false, Image.FORMAT_RGBA8)
	canvas.fill(Color("221913"))
	_put(canvas, whole, Vector2i(0, (canvas.get_height() - whole.get_height()) / 2))
	_put(canvas, close_up, Vector2i(whole.get_width(), (canvas.get_height() - close_up.get_height()) / 2))
	_save("1_neighbouring_rows.png", canvas)
	print("BATTLE12 ROWS ", label, " sample=", sample, " t=", battle.sim.t, " target=", target.unit.key)
	multi_shot = true


func _check_boxes() -> void:
	for attackers: int in [2, 3]:
		var readings := two_on_one if attackers == 2 else three_on_one
		if readings.is_empty():
			if attackers == 2:
				check(false, "2-on-1 box samples")
			continue
		var p95 := _p95(readings)
		print("BATTLE12 BOXES %d-on-1 p95=%.3f samples=%d" % [attackers, p95, readings.size()])
		check(p95 <= 0.35, "%d-on-1 box overlap p95 <= 0.35" % attackers)


func _measure(view: View) -> View.Fighter:
	var living: Array[View.Fighter] = []
	var boxes: Array[Rect2] = []
	var projected: Array[Rect2] = []
	for f: View.Fighter in view._fighters:
		if f.unit.alive:
			living.append(f)
			boxes.append(_screen_box(view, f))
			if not legacy:
				projected.append(f.screen_box())
	var meeting: View.Fighter
	var meeting_size := 0
	for i in living.size():
		var f := living[i]
		var foot := view.screen(f.body_ground())
		heights.append(f.body_height() * view.world.scale.y / view.size.y)
		var strip_min := view.screen(Vector2(0.0, -view._trail_depth)).y
		var strip_max := view.screen(Vector2(0.0, view._trail_depth)).y
		if foot.y < strip_min - 0.1 or foot.y > strip_max + 0.1 or foot.x < 0.0 or foot.x > view.size.x:
			bounds_misses += 1
		var rear := INF
		var box := boxes[i]
		var ratios: Array[float] = []
		var attackers: Array[View.Fighter] = []
		var swinging := 0
		for j in living.size():
			if i == j:
				continue
			var other := living[j]
			var other_foot := view.screen(other.body_ground())
			if j < i:
				var width := minf(f.body_width(), other.body_width()) * view.world.scale.x
				var distance := foot.distance_to(other_foot)
				pairs += 1
				overlaps += int(distance < width * 0.5)
				low += int(distance < width * 0.3)
				if not legacy:
					var same_side := f.unit.side == other.unit.side
					if distance < width * 0.3:
						print("BATTLE12 FEET %s t=%.2f %s/%s at %s/%s gap=%.1f min=%.1f" %
							[label, battle.sim.t, f.unit.key, other.unit.key, f.position, other.position, distance, width * 0.3])
					if same_side and f.unit.side == "ally":
						ally_boxes.append(_overlap(projected[i], projected[j]))
					if not same_side and (not f.long_model.is_empty() or not other.long_model.is_empty()):
						var overlap := _overlap(projected[i], projected[j])
						big_boxes.append(overlap)
						if label == "britannia" and overlap > 0.24 and int(battle.sim.t * 10.0) % 5 == 0:
							print("BATTLE12 LONG t=%.2f %s/%s overlap=%.2f at %s/%s plan %s/%s front=%.1f enters=%s/%s" %
								[battle.sim.t, f.unit.key, other.unit.key, overlap, f.position, other.position,
								f.layout_pos, other.layout_pos, view._front_x, f.unit.entering, other.unit.entering])
					if not same_side and (f.rear_mount or other.rear_mount):
						var dx := maxf(projected[i].position.x - projected[j].end.x,
							projected[j].position.x - projected[i].end.x)
						horse_line_min = minf(horse_line_min, dx / view.world.scale.x)
						horse_line_samples += 1
			if f.rear and not other.rear and f.unit.side == other.unit.side and other.on_own_side():
				var gap := (foot.x - other_foot.x) * f.side_dir / (f.beam * view.world.scale.x)
				if not legacy and gap < minf(2.0, rear_min) - 0.02:
					print("BATTLE12 REAR %s t=%.2f %s/%s gap=%.2f at %s/%s plan %s/%s front=%.1f enters=%s" %
						[label, battle.sim.t, f.unit.key, other.unit.key, gap, f.position, other.position,
						f.layout_pos, other.layout_pos, view._front_x, other.unit.entering])
				rear = minf(rear, gap)
			if _engaged(other, f):
				attackers.append(other)
				ratios.append(_overlap(box, boxes[j]) if legacy else _overlap(projected[i], projected[j]))
				if other.attack_left > 0.0 and other.sample >= 0.08:
					swinging += 1
		if rear < INF:
			rear_min = minf(rear_min, rear)
			rear_samples += 1
			rear_misses += int(rear < 2.0)
		if ratios.size() >= 2:
			multi += 1
			if ratios.size() == 2:
				two_on_one.append_array(ratios)
			else:
				three_on_one.append_array(ratios)
			if not legacy and attackers.size() <= 3:
				var index := attackers.size() - 2
				flank_samples[index] += 1
				var clear := _has_flank(f, attackers)
				flank_clear[index] += int(clear)
				battle_groups[index] += 1
				battle_flanks[index] += int(clear)
			if swinging > 0 and ratios.max() <= 0.35 and ratios.size() > meeting_size:
				meeting = f
				meeting_size = ratios.size()
	return meeting


func _has_flank(target: View.Fighter, attackers: Array[View.Fighter]) -> bool:
	var front := target.view._front_x
	var target_foot := target.visible_foot()
	for i in attackers.size():
		var f := attackers[i]
		var foot := f.visible_foot()
		if (foot.x - front) * f.side_dir < 0.0 or (foot.x - target_foot.x) * f.side_dir <= 0.0:
			return false
		if target.rank == 0 and not f.neighbouring_row(target):
			return false
		for j in i:
			var other := attackers[j]
			if (f.row_mask & other.row_mask) != 0 or absf(foot.y - other.visible_foot().y) < 25.0:
				return false
	return true



func _fort() -> void:
	get_window().size = HD
	var legion := game.city.legion
	legion.fort = {"money": 1e6, "know": {}, "exp": 0, "plots": [], "next_id": 0, "up": {}}
	var hq := legion._fort_add_plot("hq", 2)
	var room := legion._fort_add_plot("forge", 1)
	var empty := legion._fort_add_plot("", 0)
	legion._fort_add_plot("barracks", 1)
	legion._fort_fill_grid()
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var cut := FortCutaway.new()
	layer.add_child(cut)
	check(cut.setup(legion, game), "fort setup")
	var id := int(empty["id"])
	var built := int(room["id"])
	for key: int in cut.room_sprites:
		var art: Sprite2D = cut.room_sprites[key]
		check(art.has_node("Cobwebs") == (cut._empty_lights.has(key)), "cobweb placement %d" % key)
	check((cut.room_sprites[id] as Sprite2D).has_node("Cobwebs") and
		not (cut.room_sprites[int(hq["id"])] as Sprite2D).has_node("Cobwebs"), "empty has webs, HQ has none")
	var image := await _capture()
	_save("8_fort_empty_dark.png", image)
	var empty_brightness := _brightness(image, cut.plot_footprint(id))
	var built_brightness := _brightness(image, cut.plot_footprint(built))
	print("BATTLE12 FORT empty=%.3f built=%.3f ratio=%.3f" % [empty_brightness, built_brightness, empty_brightness / maxf(0.001, built_brightness)])
	check(empty_brightness <= built_brightness * 0.60, "fort brightness")
	cut.focus_plot("plot_%d" % id)
	for i in 15:
		cut._process(0.1)
	image = await _capture()
	var rect := Rect2i(cut.plot_footprint(id).grow(4.0)).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if check(rect.has_area(), "empty room crop"):
		_save("9_fort_empty_close.png", image.get_region(rect))
	layer.queue_free()
	await get_tree().process_frame


func _brightness(image: Image, bounds: Rect2) -> float:
	var rect := Rect2i(bounds.grow(-5.0)).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var luma := 0.0
	var count := 0
	for y in range(rect.position.y, rect.end.y, 3):
		for x in range(rect.position.x, rect.end.x, 3):
			var c := image.get_pixel(x, y)
			luma += c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
			count += 1
	return luma / maxf(1.0, count)


func _benchmark() -> void:
	var squad := [Legion.unit_stats("archer", 5), Legion.unit_stats("archer", 5),
		Legion.unit_stats("priest", 5), Legion.unit_stats("legionary", 5), Legion.enemy_stats("slinger", 1.0)]
	var wave := []
	for key: String in ["gaulArcher", "germArcher", "nileArcher", "slinger", "priest", "druid",
			"horseArcher", "gaul", "briton", "mercenary", "elephant"]:
		wave.append(Legion.enemy_stats(key, 1.0))
	for stat: Dictionary in squad + wave:
		stat["hp"] = float(stat["hp"]) * 18.0
	var setup := {"kind": "campaign", "stage": {"r": 0, "s": 0, "name": "Лучники", "boss": true},
		"seed": SEED, "squad": squad, "waves": [wave], "rations_paid": true, "perks": {}}
	get_window().size = HD
	for speed: float in [1.0, 3.0]:
		var baseline: Array[float] = []
		var current: Array[float] = []
		for turn in 5:
			for before: bool in [true, false]:
				var fps := await _fps_window(setup, speed, before)
				if fps <= 0.0:
					return
				var readings := baseline if before else current
				readings.append(fps)
				print("BATTLE12 FPS window=%d %s x%.0f %.1f" %
					[turn + 1, "before" if before else "after", speed, fps])
		baseline.sort()
		current.sort()
		var before_fps := baseline[2]
		var after_fps := current[2]
		print("BATTLE12 FPS MEDIAN x%.0f before=%.1f after=%.1f ratio=%.3f" %
			[speed, before_fps, after_fps, after_fps / before_fps])
		check(after_fps >= before_fps * 0.92 or after_fps >= 400.0, "FPS x%.0f >= 92%% of baseline or >= 400" % speed)


func _fps_window(setup: Dictionary, speed: float, before: bool) -> float:
	battle = LegionBattle.open(game, setup.duplicate(true), Callable(),
		{"legion": game.city.legion, "speed": 1.0, "auto": false, "legacy_layout": before})
	battle.set_process(false)
	if not check(await _until(func() -> bool: return battle.sim != null, 30.0), "open FPS battle"):
		battle.abort()
		return 0.0
	battle.fade.hide()
	# Один состав, сид и момент начала замера у каждого окна.
	for i in 420:
		battle._process(1.0 / 60.0)
	if not check(battle.sim.steps == 210 and battle.views.size() == 16, "same start of FPS window"):
		battle.abort()
		return 0.0
	battle._set_speed(speed)
	battle.set_process(true)
	for i in 20:
		await get_tree().process_frame
	var begin := Time.get_ticks_usec()
	for i in 120:
		await get_tree().process_frame
	var fps := 120000000.0 / maxf(1.0, Time.get_ticks_usec() - begin)
	check(battle.views.size() == 16, "16 fighters at end of FPS window")
	battle.abort()
	await get_tree().process_frame
	return fps
