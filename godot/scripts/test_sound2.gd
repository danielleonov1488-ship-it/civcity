extends Node
## Звук в настоящем походе, на двух скоростях. Результаты выводятся в журнал проверки.

const Mixer = preload("res://scripts/legion_battle_sound.gd")
const View = preload("res://scripts/legion_battle_view.gd")
const OUT := "D:/CivCity/.work/stage7/sound2/mix_log.txt"
const CASES := {
	"forest": ["forestBear", "forestBear", "bear", "greatbear", "boar", "bandit", "slinger"],
	"gaul": ["gaul", "gaul", "gaul", "gaulArcher", "gaulArcher", "druid", "vercingetorix"],
	"carthage": ["mercenary", "mercenary", "elephant", "numidian", "slinger", "pirate"],
	"britannia": ["briton", "briton", "chariot", "chariot", "charioteer", "druid", "boudicca"],
	"parthia": ["horseArcher", "horseArcher", "cataphract", "cataphractFoe", "surena", "numidian"],
}
const SAMPLE_FROM := 2.0
const SAMPLE_TO := 18.0

var game: Game
var battle: LegionBattle
var fails := 0
var _path := OUT
var _log: FileAccess
var _trace := false
var _manifest := {}
var _files := {}
var _counts := {}
var _loops := {}
var _sync := {}
var _max_voices := 0
var _peak := -200.0
var _sample_count := 0
var _sample := false
var _wave_horn := false
var _gallop_moved := false
var _victory := false
var _last_file := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_path = arg.trim_prefix("out=")
	_check_pack()
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	game.can_save = false
	game.hero_screen_auto = false
	add_child(game)
	if _check(await _until(func() -> bool: return game.ready_done, 150.0), "ready_done"):
		game.settings["autosave"] = false
		game.settings["sfx"] = 1.0
		game.settings["music"] = 0.55
		game.sound.apply_volumes()
		Legion.v2_test = true
		Legion.V2 = true
		Engine.max_fps = 120
		_check_pool()
		for province: String in CASES:
			var slow := await _sample_battle(province, 1.0)
			var fast := await _sample_battle(province, 3.0)
			var ratio := fast / maxf(0.001, slow)
			_check(slow > 0.0 and fast > 0.0 and ratio <= 1.65, "density %s ratio=%.3f" % [province, ratio])
			print("SOUND2 DENSITY %s x1=%.2f/s x3=%.2f/s ratio=%.3f" % [province, slow, fast, ratio])
		await _victory_battle()
		if _peak <= -80.0:
			print("SOUND2 PEAK skipped, audio driver reports no signal")
		else:
			_check(_peak <= -0.5, "SFX peak %.2f dB" % _peak)
			print("SOUND2 PEAK %.2f dB at SFX=100%%" % _peak)
	if is_instance_valid(battle):
		battle.abort()
	print("SOUND2 DONE fails=", fails)
	get_tree().quit(int(fails != 0))


func _check(ok: bool, message: String) -> bool:
	if not ok:
		fails += 1
		print("SOUND2 FAIL ", message)
	return ok


func _until(condition: Callable, seconds: float) -> bool:
	var start := Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec() - start < seconds * 1000.0:
		await get_tree().process_frame
	return condition.call()


func _check_pack() -> void:
	_manifest = Mixer.read_manifest()
	_check(not _manifest.is_empty(), "manifest loaded")
	for event: String in Mixer.MIX:
		_check(_manifest.has(event), "manifest event " + event)
	var imported := 0
	var loops := 0
	for event: String in _manifest:
		var entries: Array = _manifest[event]
		for entry: Dictionary in entries:
			var file := String(entry["file"])
			var path := Mixer.PACK + file
			_files[file] = true
			_check(FileAccess.file_exists(path), "source " + file)
			if _check(ResourceLoader.exists(path, "AudioStreamOggVorbis"), "import " + file):
				var stream := load(path) as AudioStreamOggVorbis
				if _check(stream != null and stream.get_length() > 0.0, "decode " + file):
					imported += 1
			_check(bool(entry.get("loop", false)) == (event in Mixer.LOOP_EVENTS), "loop flag " + file)
			loops += int(bool(entry.get("loop", false)))
	print("SOUND2 PACK imported=%d loop_files=%d" % [imported, loops])


func _check_pool() -> void:
	var pool := Mixer.new()
	add_child(pool)
	_check(pool.get_child_count() == 14, "14 players including loops")
	for event: String in Mixer.LOOP_EVENTS:
		var stream := pool._pick(event) as AudioStreamOggVorbis
		_check(stream != null and stream.loop, "loop on runtime resource " + event)
	for event: String in ["swing", "hit_metal", "hit_wood", "hit_heavy", "hit_flesh", "bow_draw",
			"bow_release", "arrow_hit", "stone_hit", "fall"]:
		_check(pool.play(event, 0.0, 0.0, 1.0, true), "fill priority pool " + event)
	_check(pool.active_shots() == 10 and not pool.play("arrow_fly"), "10 shots and weak cue dropped")
	_check(pool.play("war_horn") and pool.play("victory") and pool.active_shots() == 10, "horn and victory preempt lower voices")
	var sfx := AudioServer.get_bus_index("SFX")
	var limiter := AudioServer.get_bus_effect(sfx, 0) as AudioEffectHardLimiter
	_check(AudioServer.get_bus_effect_count(sfx) == 1 and limiter != null and is_equal_approx(limiter.ceiling_db, -1.0),
		"single -1 dB limiter")
	print("SOUND2 POOL players=14 one_shots=10 priority=checked")
	pool.queue_free()


func _open(province: String, speed: float, quick: bool = false) -> void:
	_counts.clear()
	_loops.clear()
	_sync.clear()
	_last_file.clear()
	_max_voices = 0
	_sample_count = 0
	_sample = not quick
	_wave_horn = false
	_gallop_moved = false
	_victory = false
	var region := -1
	var regions := Legion.regions()
	for i in regions.size():
		var id: String = regions[i]["id"]
		if id == province or (province == "carthage" and id == "africa"):
			region = i
			break
	if not _check(region >= 0, "province " + province):
		return
	var stage := Legion.stage(0, region, Legion.stages() - 1)
	var roster := ["legionary", "spearman", "legionary", "spearman", "legionary", "archer", "archer", "priest"]
	var enemies: Array = CASES[province]
	if quick:
		roster = ["legionary", "spearman", "legionary"]
		enemies = ["chariot"]
	var squad := []
	for key: String in roster:
		var stat := Legion.unit_stats(key, 5)
		stat["hp"] = float(stat["hp"]) * 7.0
		squad.append(stat)
	var wave := []
	for key: String in enemies:
		var stat := Legion.enemy_stats(key, 1.0)
		stat["hp"] = 15.0 if quick else clampf(float(stat["hp"]) * 7.0, 950.0, 3300.0)
		wave.append(stat)
	var setup := {"kind": "campaign", "stage": stage, "seed": 532, "squad": squad, "waves": [wave],
		"rations_paid": true, "perks": {}}
	var legion := Legion.new()
	legion.free_mode = true
	legion.progress = 100
	battle = LegionBattle.open(game, setup, Callable(), {"legion": legion, "speed": speed})
	battle.battle_sound._rng.seed = 852
	battle.battle_sound.played.connect(_played)
	battle.battle_sound.loop_changed.connect(_loop_changed)


func _sample_battle(province: String, speed: float) -> float:
	_trace = province == "forest" and speed == 1.0
	if _trace:
		_log = FileAccess.open(_path, FileAccess.WRITE)
		if _check(_log != null, "mix_log.txt writable"):
			_log.store_line("SOUND2 | forest x1 | 00.000–30.000 s | successful SFX starts and loop stops | pan: left -0.6 / right +0.6")
	_open(province, speed)
	if not _check(await _until(func() -> bool: return is_instance_valid(battle) and battle.sim != null, 45.0), "battle start " + province):
		return 0.0
	var stop_at := 30.0 if _trace else SAMPLE_TO
	var start := Time.get_ticks_msec()
	while battle.sim.t < stop_at and battle.sim.result.is_empty() and Time.get_ticks_msec() - start < 52000:
		await get_tree().process_frame
		_observe_peak()
	_check(battle.sim.t >= stop_at, "sample reached %.1f sim seconds %s x%.0f" % [stop_at, province, speed])
	var tag := "%s x%.0f" % [province, speed]
	_check(_wave_horn, "horn on wave start " + tag)
	_check(int(_counts.get("bow_release", 0)) > 0 and _sync.has("ally"), "ally bow release on projectile frame " + tag)
	_check(_counts.has("arrow_hit") and _counts.has("battle_cry"), "arrow impact and battle cry " + tag)
	if speed == 1.0 or province in ["gaul", "parthia"]:
		_check(_counts.has("bow_draw"), "bow windup " + tag)
	_check(_max_voices <= Mixer.MAX_SHOTS, "voice cap " + tag)
	_check(_loops.has("ambience_field+") == (province in ["forest", "gaul", "britannia"]), "biome ambience " + tag)
	match province:
		"forest":
			_check(_counts.has("bear_roar") and _counts.has("war_drum"), "bear and boss drums " + tag)
			if speed == 1.0:
				_check(_counts.has("sling_whirl") and _counts.has("stone_hit"), "slinger windup and impact " + tag)
		"gaul":
			_check(_sync.has("gaulArcher") and _counts.has("stone_hit"), "Gaul ranged signatures " + tag)
		"carthage":
			_check(_counts.has("elephant"), "elephant " + tag)
		"britannia":
			_check(_gallop_moved and _loops.has("cart_roll+"), "chariots start hoof and wheel loops " + tag)
		"parthia":
			_check(_sync.has("horseArcher"), "mounted bow release on projectile frame " + tag)
	print("SOUND2 MIX ", tag, " max_one_shots=", _max_voices, " shots=", _counts, " loops=", _loops, " bow_sync=", _sync)
	var density := _sample_count / ((SAMPLE_TO - SAMPLE_FROM) / speed)
	if _trace and _log != null:
		_log.store_line("30.000  END")
		_log.close()
		_log = null
	_trace = false
	battle.abort()
	await get_tree().process_frame
	return density


func _victory_battle() -> void:
	var music := AudioServer.get_bus_index("Music")
	var normal := linear_to_db(float(game.settings.get("music", 0.55)))
	_open("britannia", 1.0, true)
	_check(await _until(func() -> bool: return _gallop_moved, 25.0), "gallop starts when the chariot moves")
	var ducked := func() -> bool: return absf(AudioServer.get_bus_volume_db(music) - (normal - 6.0)) < 0.15
	_check(await _until(ducked, 5.0), "music faded down 6 dB")
	_check(await _until(func() -> bool: return _victory, 25.0), "result played victory")
	_check(await _until(func() -> bool: return not battle.battle_sound.loop_active("gallop"), 5.0), "gallop fades out after movement")
	_check(await _until(func() -> bool: return _counts.has("fall"), 5.0), "fall at grounded death pose")
	_check(_loops.has("gallop-") and _loops.has("cart_roll-"), "hoof and wheel loops stopped")
	_check(_counts.has("war_drum"), "result played drum")
	battle._close()
	_check(await _until(func() -> bool: return not is_instance_valid(battle), 5.0), "battle closed")
	_check(await _until(func() -> bool: return absf(AudioServer.get_bus_volume_db(music) - normal) < 0.15, 5.0), "music level restored")
	print("SOUND2 RESULT victory=", _victory, " gallop_stopped=", _loops.has("gallop-"), " followed_by_fall=", _counts.has("fall"))


func _played(event: String, file: String, pan: float) -> void:
	var legacy := file.begins_with("hf_") or file.begins_with("metalPot")
	var fallback := event == "war_horn" and file == "synth_horn" and (_manifest.get("war_horn", []) as Array).is_empty()
	_check(not legacy and (_files.has(file) or fallback), "source for " + event + ": " + file)
	_check(absf(pan) <= 0.60001, "pan limit " + event)
	var previous := String(_last_file.get(event, ""))
	if (_manifest.get(event, []) as Array).size() > 1:
		_check(previous != file, "variant repeated " + event + ": " + file)
	_last_file[event] = file
	_counts[event] = int(_counts.get(event, 0)) + 1
	_max_voices = maxi(_max_voices, battle.battle_sound.active_shots())
	if battle.sim != null and _sample and battle.sim.t >= SAMPLE_FROM and battle.sim.t < SAMPLE_TO:
		_sample_count += 1
	if event == "war_horn" and battle.sim != null and battle.sim.t < 0.15:
		_wave_horn = true
	if event == "victory":
		_victory = true
	if event == "bow_release" and _sample:
		_release_sync(pan)
	_trace_line(event, "%s pan=%+.2f" % [file, pan])


func _release_sync(pan: float) -> void:
	var frame := Engine.get_process_frames()
	for shot: LegionSim.Shot in battle.shots:
		if shot.kind != "arrow":
			continue
		var sprite: Node2D = battle.shots[shot]
		var f: View.Fighter = battle.views.get(shot.from.id)
		if f == null or not is_equal_approx(battle.battle_view.sound_pan(f.position), pan):
			continue
		if int(sprite.get_meta("release_frame", -1)) == frame and f.release_frame == frame:
			_sync[f.unit.side] = int(_sync.get(f.unit.side, 0)) + 1
			_sync[f.unit.key] = int(_sync.get(f.unit.key, 0)) + 1
			return
	_check(false, "bow release without a matching BOWANIM projectile")


func _loop_changed(event: String, playing: bool) -> void:
	var key := event + ("+" if playing else "-")
	_loops[key] = int(_loops.get(key, 0)) + 1
	if event == "gallop" and playing and battle.sim != null:
		for u in battle.sim.units:
			if u.key in ["chariot", "charioteer"] and u.alive and (u.moving or u.entering):
				_gallop_moved = true
				break
	_trace_line(key, "")


func _observe_peak() -> void:
	var sfx := AudioServer.get_bus_index("SFX")
	_peak = maxf(_peak, AudioServer.get_bus_peak_volume_left_db(sfx, 0))
	_peak = maxf(_peak, AudioServer.get_bus_peak_volume_right_db(sfx, 0))


func _trace_line(event: String, extra: String) -> void:
	if _trace and _log != null and battle.battle_sound._clock < 30.0:
		_log.store_line("%06.3f  %-16s %s" % [battle.battle_sound._clock, event, extra])
