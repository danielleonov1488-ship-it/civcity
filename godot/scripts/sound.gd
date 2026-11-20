class_name Sound
extends Node
## Звук: спокойная классическая музыка для фортепиано (записи — общественное достояние), птицы днём,
## тихие щелчки кнопок, звуки стройки, мяуканье кошек. Громкость музыки и звуков — в настройках.

var music: AudioStreamPlayer
var ambient: AudioStreamPlayer
var pool: Array[AudioStreamPlayer] = []
var tracks := []
var order := []
var cur := -1
var cache := {}
var game
var _pause_t := 2.0
var _music_base_db := 0.0
var _city_ambience_db := -60.0
var _duck_db := 0.0
var _duck_tween: Tween
var _battle_owners := {}
var played := {}                      # сколько раз звучал звук интерфейса (для проверок: один звон монет на мазок)

## Выбор владельца (12.10): кнопки, окна, стройка, снос, «нельзя», выполненная просьба — без звука; остались только монетки
const SFX := {"coins": "coins.ogg"}
const MEOWS := ["cat_softmew.wav", "cat_mewpurr.wav", "cat_mewfood.wav", "Meow.ogg"]


func _ready() -> void:
	_ensure_bus(&"Music")
	ensure_sfx_bus()
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	music.finished.connect(func(): _pause_t = randf_range(3.0, 8.0))
	add_child(music)
	ambient = AudioStreamPlayer.new()
	ambient.bus = "SFX"
	var birds := _load("birds.ogg")
	if birds is AudioStreamOggVorbis:
		(birds as AudioStreamOggVorbis).loop = true
	ambient.stream = birds
	ambient.volume_db = -60.0
	add_child(ambient)
	ambient.play()
	for k in 6:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		pool.append(p)
	_scan_music()
	apply_volumes()


## Список музыки (в собранной игре тоже: ResourceLoader видит и упакованные файлы). Набора музыки ещё нет (лаунчер
## докачивает его после «Играть») — пусто; _process заглядывает снова, пока он не подключится (scripts/packs.gd)
func _scan_music() -> void:
	tracks.clear()
	for f in ResourceLoader.list_directory("res://assets/music"):
		if String(f).ends_with(".ogg"):
			tracks.append("res://assets/music/" + String(f))
	tracks.sort()
	order = range(tracks.size())
	order.shuffle()
	cur = -1


static func _ensure_bus(bus: StringName) -> int:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus)
		AudioServer.set_bus_send(idx, &"Master")
	return idx


static func ensure_sfx_bus() -> int:
	var idx := _ensure_bus(&"SFX")
	for i in AudioServer.get_bus_effect_count(idx):
		var effect := AudioServer.get_bus_effect(idx, i)
		if effect is AudioEffectHardLimiter or effect is AudioEffectLimiter:
			return idx
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(idx, limiter)
	return idx


func apply_volumes() -> void:
	var s: Dictionary = game.settings if game else {}
	_music_base_db = linear_to_db(maxf(0.0001, float(s.get("music", 0.55))))
	_set_music_duck(_duck_db)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(0.0001, float(s.get("sfx", 0.7)))))


func duck_for_battle(owner: int, active: bool) -> void:
	var was_active := not _battle_owners.is_empty()
	if active:
		_battle_owners[owner] = true
	else:
		_battle_owners.erase(owner)
	var battle_active := not _battle_owners.is_empty()
	if was_active == battle_active:
		return
	if _duck_tween != null:
		_duck_tween.kill()
	_duck_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_duck_tween.tween_method(_set_music_duck, _duck_db, -6.0 if battle_active else 0.0, 0.40)


func _set_music_duck(db: float) -> void:
	_duck_db = db
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), _music_base_db + db)
	_update_city_ambience()


func _update_city_ambience() -> void:
	# На поле свой фон; городские птицы затихают вместе с музыкой.
	ambient.volume_db = lerpf(_city_ambience_db, -80.0, clampf(-_duck_db / 6.0, 0.0, 1.0))


func _load(name: String) -> AudioStream:
	if cache.has(name):
		return cache[name]
	var path := "res://assets/sfx/" + name
	var st: AudioStream = load(path) if ResourceLoader.exists(path) else null
	cache[name] = st
	return st


var _rescan_t := 0.0


func _process(dt: float) -> void:
	if tracks.is_empty():
		_rescan_t -= dt
		if _rescan_t <= 0.0:
			_rescan_t = 6.0
			_scan_music()
		if tracks.is_empty():
			return
	if not music.playing:
		_pause_t -= dt
		if _pause_t <= 0.0:
			cur = (cur + 1) % order.size()
			music.stream = load(tracks[order[cur]])
			music.volume_db = -10.0          # записи выровнены по громкости (-18 LUFS) — чуть тише, как раньше
			music.play()
	# птицы днём, тише издалека; ночью тишина
	if game and game.ready_done:
		var h: float = game.hour
		var day := smoothstep(5.0, 7.0, h) * (1.0 - smoothstep(19.5, 21.0, h))
		var near := 1.0 - smoothstep(25.0, 70.0, game.rig.dist) if game.rig else 0.3
		var target := lerpf(-60.0, -30.0, day * near)
		_city_ambience_db = lerpf(_city_ambience_db, target, minf(1.0, dt * 1.5))
		_update_city_ambience()


func ui(name := "click") -> void:
	played[name] = int(played.get(name, 0)) + 1
	if not SFX.has(name):
		return
	var st := _load(SFX[name])
	if st == null:
		return
	for p in pool:
		if not p.playing:
			p.stream = st
			p.volume_db = -8.0 if name == "click" else -4.0
			p.pitch_scale = randf_range(0.96, 1.04)
			p.play()
			return


func cat(p3: AudioStreamPlayer3D) -> void:
	var st := _load(MEOWS[randi() % MEOWS.size()])
	if st and p3:
		p3.stream = st
		p3.pitch_scale = randf_range(0.92, 1.12)
		p3.play()
