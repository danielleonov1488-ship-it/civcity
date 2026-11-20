extends Node
## Полные бои с шагом замера 0,1 с и кадры настоящего экрана.

const View = preload("res://scripts/legion_battle_view.gd")
const OUT := "D:/CivCity/.work/stage7/battle12/shots/"
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
var heights := PackedFloat32Array()
var forest_before: Image
var forest_after: Image
var multi_shot := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			output = arg.trim_prefix("out=").trim_suffix("/") + "/"
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = HD
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	game.can_save = false
	game.hero_screen_auto = false
	add_child(game)
	if check(await _until(func() -> bool: return game.ready_done, 150.0), "ready_done"):
		game.settings["autosave"] = false
		if check(DisplayServer.get_name() != "headless", "graphics required") and check(
				DirAccess.make_dir_recursive_absolute(output) == OK, "shot directory"):
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Engine.max_fps = 0
			await _run()
	print("BATTLE12 DONE fails=", fails)
	get_tree().quit(int(fails != 0))


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
	await _play("carthage", _campaign("carthage", ["mercenary", "slinger"], ["elephant", "mercenary"]), HD, 1.0, "3_battle_carthage.png", 1)
	await _play("britannia", _campaign("britannia", ["briton", "druid"], ["chariot", "charioteer", "briton"]), SMALL, 3.0, "4_battle_chariots.png", 1)
	await _play("parthia", _campaign("parthia", ["horseArcher", "numidian", "cataphractFoe"],
		["cataphract", "horseArcher"]), HD, 3.0, "5_battle_ranged.png", 0)
	var pvp := await _play("pvp", _pvp(), SMALL, 2.0, "6_pvp.png", 0)
	check(not pvp.is_empty(), "PvP replay finished")
	check(multi_shot, "two attackers shot")
	await _fort()
	await _benchmark()


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
	get_window().size = resolution
	battle = LegionBattle.open(game, setup.duplicate(true), Callable(),
		{"legion": game.city.legion, "speed": speed, "auto": false, "legacy_layout": before})
	if not check(await _until(func() -> bool: return battle.sim != null, 30.0), "open " + label):
		return {}
	battle.set_process(false)
	battle.fade.hide()
	battle.battle_view.melee_pose.connect(_striking)
	battle.battle_view.melee_event.connect(_events)
	var shown := false
	var samples := 0
	var view := battle.battle_view
	while battle.sim.result.is_empty() and samples < 1801:
		# Одинаковые шаги симуляции даже при медленном видеодрайвере.
		for step in 6:
			battle._process(0.1 / (6.0 * speed))
		samples += 1
		var meeting := _measure(view)
		if meeting != null and not multi_shot and not before and name_ != "forest":
			var whole := await _capture()
			var at := Vector2i(view.screen(meeting.body_ground()))
			var rect := Rect2i(at - Vector2i(325, 360), Vector2i(650, 430))
			rect = rect.intersection(Rect2i(Vector2i.ZERO, whole.get_size()))
			var close_up := whole.get_region(rect)
			close_up.resize(rect.size.x * 3 / 2, rect.size.y * 3 / 2, Image.INTERPOLATE_LANCZOS)
			var canvas := Image.create(whole.get_width() + close_up.get_width(), whole.get_height(), false, Image.FORMAT_RGBA8)
			canvas.fill(Color("221913"))
			_put(canvas, whole, Vector2i.ZERO)
			_put(canvas, close_up, Vector2i(whole.get_width(), (whole.get_height() - close_up.get_height()) / 2))
			_save("2_battle_two_on_one.png", canvas)
			multi_shot = true
		var forest_sample := (name_ == "forest" or before) and samples == 60
		if forest_sample:
			if before:
				forest_before = await _capture()
			else:
				forest_after = await _capture()
		if not shown and file != "" and battle.sim.wave_idx >= wave and (meeting != null or
				(samples >= 28 and _wave_in_contact(view, wave))):
			_save(file, await _capture())
			shown = true
		if samples % 20 == 0:
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
		check(median >= 0.15 and median <= 0.21, label + " figure height")
		check(overlap_pct <= 1.0 and low == 0, label + " overlap")
		check(strikes > 0 and air == 0, label + " melee contact")
		check(rear_samples > 0 and rear_misses == 0, label + " ranged gap")
		check(bounds_misses == 0, label + " field strip")
	var result := battle.sim.result.duplicate(true)
	battle.abort()
	await get_tree().process_frame
	return result


func _wave_in_contact(view: View, wave: int) -> bool:
	for f: View.Fighter in view._fighters:
		if f.unit.alive and f.unit.wave == wave and not f.unit.entering:
			return true
	return false


func _measure(view: View) -> View.Fighter:
	var living: Array[View.Fighter] = []
	for f: View.Fighter in view._fighters:
		if f.unit.alive:
			living.append(f)
	var meeting: View.Fighter
	for i in living.size():
		var f := living[i]
		var foot := view.screen(f.body_ground())
		heights.append(f.body_height() * view.world.scale.y / view.size.y)
		var strip_min := view.screen(Vector2(0.0, -view._trail_depth)).y
		var strip_max := view.screen(Vector2(0.0, view._trail_depth)).y
		if foot.y < strip_min - 0.1 or foot.y > strip_max + 0.1 or foot.x < 0.0 or foot.x > view.size.x:
			bounds_misses += 1
		var rear := INF
		var attackers := 0
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
			if f.rear and not other.rear and f.unit.side == other.unit.side:
				rear = minf(rear, (foot.x - other_foot.x) * f.side_dir / (f.beam * view.world.scale.x))
			if other.layout_target == f and other.slot > 0 and other.slot < 4 and other.can_strike(f):
				attackers += 1
				if other.attack_left > 0.0:
					swinging += 1
		if rear < INF:
			rear_min = minf(rear_min, rear)
			rear_samples += 1
			rear_misses += int(rear < 2.0)
		if attackers >= 2:
			multi += 1
			if swinging > 0:
				meeting = f
	return meeting


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
	var readings: Array[float] = []
	for before: bool in [true, false]:
		battle = LegionBattle.open(game, setup.duplicate(true), Callable(),
			{"legion": game.city.legion, "speed": 1.0, "auto": false, "legacy_layout": before})
		if not check(await _until(func() -> bool: return battle.sim != null and battle.sim.t >= 7.0, 70.0), "FPS battle"):
			battle.abort()
			return
		for speed: float in [1.0, 3.0]:
			battle._set_speed(speed)
			for i in 16:
				await get_tree().process_frame
			var begin := Time.get_ticks_usec()
			for i in 120:
				await get_tree().process_frame
			var fps := 120000000.0 / maxf(1.0, Time.get_ticks_usec() - begin)
			print("BATTLE12 FPS %s x%.0f %.1f at 1920x1080 figures=%d" %
				["before" if before else "after", speed, fps, battle.views.size()])
			readings.append(fps)
		battle.abort()
		await get_tree().process_frame
	for i in 2:
		check(readings[i + 2] >= readings[i] * 0.95, "FPS x%d within 5%% of baseline" % (1 if i == 0 else 3))
