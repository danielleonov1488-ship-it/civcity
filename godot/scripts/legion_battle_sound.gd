extends Node
## Звуки боя. События приходят из представления; время и случайность свои.

signal played(event: String, file: String, pan: float)
signal loop_changed(event: String, playing: bool)

const PACK := "res://assets/sfx/battle2/"
const MANIFEST := PACK + "sounds.json"
const MAX_SHOTS := 10
const LOOP_EVENTS := ["battle_bed", "ambience_field", "gallop", "cart_roll"]
# дБ, пауза в секундах, приоритет (1 — фоновые акценты, 5 — итог боя).
const MIX := {
	"swing": [-23.0, 0.14, 1], "hit_metal": [-15.0, 0.06, 2], "hit_wood": [-15.0, 0.06, 2],
	"hit_heavy": [-13.0, 0.12, 2], "hit_flesh": [-28.0, 0.22, 1],
	"bow_draw": [-21.0, 0.16, 2], "bow_release": [-15.0, 0.05, 2],
	"arrow_fly": [-25.0, 0.24, 1], "arrow_hit": [-19.0, 0.10, 2],
	"sling_whirl": [-21.0, 0.16, 1], "stone_hit": [-17.0, 0.10, 2], "boulder": [-13.0, 0.22, 2],
	"fall": [-17.0, 0.15, 3], "grunt": [-25.0, 0.50, 1], "death_vox": [-22.0, 0.80, 3],
	"horse_snort": [-22.0, 2.80, 3], "horse_whinny": [-17.0, 1.60, 3],
	"bear_roar": [-17.0, 1.75, 3], "bear_hurt": [-22.0, 1.20, 3],
	"boar": [-20.0, 1.65, 3], "bull": [-18.0, 1.75, 3], "elephant": [-16.0, 2.00, 3],
	"giant_vox": [-17.0, 1.60, 3], "giant_hurt": [-21.0, 1.35, 3],
	"oil": [-14.0, 0.35, 2], "heal": [-19.0, 0.50, 2],
	"war_horn": [-10.0, 0.65, 4], "battle_cry": [-14.0, 0.75, 4],
	"war_drum": [-13.0, 0.20, 4], "victory": [-11.0, 0.65, 5],
	"battle_bed": [-28.0, 0.0, 0], "ambience_field": [-36.0, 0.0, 0],
	"gallop": [-23.0, 0.0, 0], "cart_roll": [-27.0, 0.0, 0],
}
const FALLBACK := {
	"hit_metal": "hit_wood", "hit_heavy": "hit_wood", "bow_release": "swing",
	"arrow_hit": "stone_hit", "stone_hit": "hit_wood", "boulder": "hit_heavy",
	"bear_hurt": "bear_roar", "bull": "boar", "giant_hurt": "giant_vox",
	"horse_whinny": "horse_snort",
}
const ANIMAL_VOICES := ["horse_snort", "horse_whinny", "bear_roar", "bear_hurt", "boar", "bull",
	"elephant", "giant_vox", "giant_hurt"]
const FIELD_BIOMES := ["forest", "darkforest", "field", "hills"]
const ATTACK_BEAT := 0.075
const SILENT := -60.0

class Voice:
	var player: AudioStreamPlayer2D
	var priority := 0
	var started := 0.0
	var victory := false
	var gain := 0.0

class Cue:
	var event: String
	var due: float
	var pan: float
	var gain: float
	var pitch: float
	var featured: bool

static var _horn: AudioStreamWAV
var _rng := RandomNumberGenerator.new()
var _variants := {}
var _last_variant := {}
var _last_played := {}
var _voices: Array[Voice] = []
var _loops := {}
var _loop_targets := {}
var _loop_trims := {}
var _queue: Array[Cue] = []
var _clock := 0.0
var _speed := 1.0
var _next_action := 0.0
var _next_texture := 0.0
var _field_t := 0.0
var _field_ambience := false
var _finished := false


func _ready() -> void:
	Sound.ensure_sfx_bus()
	_load_pack()
	var pan_strength := float(ProjectSettings.get_setting("audio/general/2d_panning_strength"))
	for i in MAX_SHOTS:
		var voice := Voice.new()
		var player := AudioStreamPlayer2D.new()
		player.bus = &"SFX"
		player.area_mask = 0
		player.attenuation = 0.0
		player.max_distance = 100000.0
		player.panning_strength = 1.2 / maxf(0.001, pan_strength)
		add_child(player)
		voice.player = player
		_voices.append(voice)
	for event: String in LOOP_EVENTS:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		player.volume_db = SILENT
		add_child(player)
		_loops[event] = player


static func read_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	return data if data is Dictionary else {}


func _load_pack() -> void:
	var manifest := read_manifest()
	for event: String in MIX:
		var entries: Variant = manifest.get(event, [])
		if entries is not Array:
			continue
		var streams: Array[AudioStreamOggVorbis] = []
		for entry: Variant in entries:
			if entry is not Dictionary:
				continue
			var file := String(entry.get("file", ""))
			if file.is_empty() or file != file.get_file() or not ResourceLoader.exists(PACK + file, "AudioStreamOggVorbis"):
				continue
			var stream := load(PACK + file) as AudioStreamOggVorbis
			if stream != null:
				stream.loop = event in LOOP_EVENTS and bool(entry.get("loop", false))
				if stream.loop == (event in LOOP_EVENTS):
					streams.append(stream)
		if not streams.is_empty():
			_variants[event] = streams


func reset(biome: String) -> void:
	_queue.clear()
	_last_played.clear()
	_last_variant.clear()
	_loop_targets.clear()
	_clock = 0.0
	_next_action = 0.0
	_next_texture = 0.0
	_field_t = 0.0
	_field_ambience = biome in FIELD_BIOMES
	_finished = false
	for voice in _voices:
		voice.player.stop()
	for player: AudioStreamPlayer in _loops.values():
		player.stop()
		player.volume_db = SILENT


func advance(dt: float, speed: float, running: bool) -> void:
	_speed = speed
	if running:
		_clock += dt
		var i := 0
		while i < _queue.size():
			var cue := _queue[i]
			if cue.due <= _clock:
				_queue.remove_at(i)
				play(cue.event, cue.pan, cue.gain, cue.pitch, cue.featured)
			else:
				i += 1
	for voice in _voices:
		if not voice.victory or not voice.player.playing:
			continue
		var age := _clock - voice.started
		if age >= 4.0:
			voice.player.stop()
		elif age > 2.8:
			voice.player.volume_db = lerpf(voice.gain, SILENT, smoothstep(2.8, 4.0, age))
	for event: String in LOOP_EVENTS:
		_fade_loop(event, dt)


func later(event: String, delay: float, pan := 0.0, gain := 0.0, pitch := 1.0, featured := false) -> void:
	var cue := Cue.new()
	cue.event = event
	cue.due = _clock + delay
	cue.pan = pan
	cue.gain = gain
	cue.pitch = pitch
	cue.featured = featured
	_queue.append(cue)


func play(event: String, pan := 0.0, gain := 0.0, pitch := 1.0, featured := false) -> bool:
	if not MIX.has(event):
		return false
	var mix: Array = MIX[event]
	var priority: int = mix[2]
	if priority == 0:
		return false
	var speed_scale := 1.0 if featured or priority >= 4 else 1.0 + (_speed - 1.0) * 0.42
	if _clock - float(_last_played.get(event, -INF)) + 0.00001 < float(mix[1]) * speed_scale:
		return false
	# Замах не перекрывает свой удар или натяжение тетивы у соседнего бойца.
	var action := priority == 2 and not featured and event != "bow_draw"
	var texture := not featured and event in ["swing", "grunt", "arrow_fly"]
	if (action and _clock < _next_action) or (texture and _clock < _next_texture):
		return false
	var voice := _available_voice(priority)
	if voice == null:
		return false
	var stream := _pick(event)
	if stream == null:
		return false
	_last_played[event] = _clock
	if action:
		_next_action = _clock + 0.064 * speed_scale
	if texture:
		_next_texture = _clock + 0.14 * speed_scale
	voice.started = _clock
	voice.priority = priority
	voice.victory = event == "victory"
	voice.gain = float(mix[0]) + gain + _rng.randf_range(-1.5, 1.5)
	var player := voice.player
	player.stop()
	player.stream = stream
	player.pitch_scale = pitch * _random_pitch(event)
	player.volume_db = voice.gain
	var area := get_viewport().get_visible_rect()
	var screen := Vector2(area.size.x * (0.5 + clampf(pan, -0.6, 0.6) / 1.2), area.size.y * 0.5)
	var transform := get_viewport().get_global_canvas_transform() * get_viewport().get_canvas_transform()
	player.global_position = transform.affine_inverse() * screen
	player.play()
	played.emit(event, stream.resource_path.get_file() if not stream.resource_path.is_empty() else "synth_horn", pan)
	return true


func _available_voice(priority: int) -> Voice:
	var weakest: Voice
	for voice in _voices:
		if not voice.player.playing:
			return voice
		if weakest == null or voice.priority < weakest.priority or (voice.priority == weakest.priority and voice.started < weakest.started):
			weakest = voice
	return weakest if weakest != null and weakest.priority < priority else null


func _pick(event: String) -> AudioStream:
	var key := event
	while not _variants.has(key) and FALLBACK.has(key):
		key = FALLBACK[key]
	if not _variants.has(key):
		return _horn_stream() if key == "war_horn" else null
	var streams: Array = _variants[key]
	var idx := 0
	if streams.size() > 1:
		var last := int(_last_variant.get(key, -1))
		idx = _rng.randi_range(0, streams.size() - (2 if last >= 0 else 1))
		if last >= 0 and idx >= last:
			idx += 1
	_last_variant[key] = idx
	return streams[idx]


func wave(boss: bool) -> void:
	_last_played.erase("war_horn")
	play("war_horn")
	later("battle_cry", 0.40)
	if boss:
		for beat: float in [0.19, 0.54, 0.89]:
			later("war_drum", beat)


func finish(win: bool) -> void:
	_finished = true
	for i in range(_queue.size() - 1, -1, -1):
		if not _queue[i].event.begins_with("hit_"):
			_queue.remove_at(i)
	_loop_targets.clear()
	if win:
		play("victory")
		_last_played.erase("war_drum")
		play("war_drum", 0.0, -2.0)
	else:
		_last_played.erase("war_horn")
		play("war_horn", 0.0, -2.0, 0.75)


func update_field(sim: LegionSim, dt: float, fighting: bool, view: LegionBattleView) -> void:
	if _finished:
		return
	if not fighting:
		_loop_targets.clear()
		_field_t = 0.0
		return
	_field_t -= dt
	if _field_t > 0.0:
		return
	_field_t = 0.10
	var melee := 0
	var horses := 0
	var carts := 0
	var idle_horse: LegionSim.Unit
	for u in sim.units:
		if not u.alive:
			continue
		if not u.moving and not u.entering and u.shot == "" and u.attack_t > 0.0:
			melee += 1
		if is_horse(u):
			if u.moving or u.entering:
				horses += 1
				carts += int(u.key in ["chariot", "charioteer"])
			elif idle_horse == null:
				idle_horse = u
	_set_group("battle_bed", melee)
	_set_group("gallop", horses)
	_set_group("cart_roll", carts)
	_loop_targets["ambience_field"] = float(MIX["ambience_field"][0]) if _field_ambience else SILENT
	if idle_horse != null and chance(0.04):
		var fighter: LegionBattleView.Fighter = view.views.get(idle_horse.id)
		play("horse_snort", view.sound_pan(fighter.position) if fighter != null else 0.0)


func _set_group(event: String, count: int) -> void:
	_loop_targets[event] = float(MIX[event][0]) - 7.0 / sqrt(float(count)) if count > 0 else SILENT


func _fade_loop(event: String, dt: float) -> void:
	var player: AudioStreamPlayer = _loops[event]
	var target := float(_loop_targets.get(event, SILENT))
	if not player.playing and target > SILENT:
		var stream := _pick(event)
		if stream == null:
			return
		player.stream = stream
		player.pitch_scale = _random_pitch(event)
		_loop_trims[event] = _rng.randf_range(-1.5, 1.5)
		player.volume_db = SILENT
		player.play()
		loop_changed.emit(event, true)
	if player.playing:
		if target > SILENT:
			target += float(_loop_trims[event])
		player.volume_db = move_toward(player.volume_db, target, dt * (100.0 if target > SILENT else 64.0))
		if player.volume_db <= SILENT and target <= SILENT:
			player.stop()
			loop_changed.emit(event, false)


func _random_pitch(event: String) -> float:
	var spread := 0.03 if event in ANIMAL_VOICES or event == "gallop" else 0.05
	return _rng.randf_range(1.0 - spread, 1.0 + spread)


func chance(probability: float) -> bool:
	return _rng.randf() < probability


func active_shots() -> int:
	var count := 0
	for voice in _voices:
		count += int(voice.player.playing)
	return count


func loop_active(event: String) -> bool:
	var player: AudioStreamPlayer = _loops.get(event)
	return player != null and player.playing


static func is_horse(u: LegionSim.Unit) -> bool:
	return "cavalry" in u.tags or u.key in ["chariot", "charioteer", "horseArcher", "cataphract",
		"cataphractFoe", "numidian", "surena"]


static func animal_voice(key: String, hurt: bool) -> String:
	match key:
		"forestBear", "venomBear", "hadesBear", "bear", "greatbear", "hadesGuardian":
			return "bear_hurt" if hurt else "bear_roar"
		"boar":
			return "boar"
		"bull", "bullLeader":
			return "bull"
		"elephant":
			return "elephant"
		"cyclops", "minotaur", "giant":
			return "giant_hurt" if hurt else "giant_vox"
	return ""


## Боевой рог (корну): низкий тёплый звук с вибрато, мягкое нарастание и затухание
static func _horn_stream() -> AudioStreamWAV:
	if _horn != null:
		return _horn
	var rate := 22050
	var dur := 1.25
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		var env := smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(dur - 0.45, dur, t))
		var f := 146.8 * (1.0 + 0.006 * sin(TAU * 5.2 * t)) * (1.0 + 0.04 * (1.0 - smoothstep(0.0, 0.15, t)))
		var ph := fmod(f * t, 1.0)
		var saw := 2.0 * ph - 1.0
		var ph2 := fmod(f * 1.5 * t, 1.0)
		var s := saw * 0.6 + (2.0 * ph2 - 1.0) * 0.25 + sin(TAU * f * 0.5 * t) * 0.35
		lp += (s - lp) * 0.12
		var v := clampf(lp * env * 0.55, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	_horn = AudioStreamWAV.new()
	_horn.format = AudioStreamWAV.FORMAT_16_BITS
	_horn.mix_rate = rate
	_horn.stereo = false
	_horn.data = data
	return _horn
