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

const SFX := {"click": "click.ogg", "select": "select.ogg", "open": "open.ogg", "close": "close.ogg", "place": "place.ogg",
	"error": "error.ogg", "done": "done.ogg", "demolish": "demolish.ogg", "scroll": "scroll.ogg"}
const MEOWS := ["cat_softmew.wav", "cat_mewpurr.wav", "cat_mewfood.wav", "Meow.ogg"]


func _ready() -> void:
	for b in ["Music", "SFX"]:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, b)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
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
	var d := DirAccess.open("res://assets/music")
	if d:
		for f in d.get_files():
			if f.ends_with(".ogg"):
				tracks.append("res://assets/music/" + f)
	tracks.sort()
	order = range(tracks.size())
	order.shuffle()
	apply_volumes()


func apply_volumes() -> void:
	var s: Dictionary = game.settings if game else {}
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(0.0001, float(s.get("music", 0.55)))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(0.0001, float(s.get("sfx", 0.7)))))


func _load(name: String) -> AudioStream:
	if cache.has(name):
		return cache[name]
	var path := "res://assets/sfx/" + name
	var st: AudioStream = load(path) if ResourceLoader.exists(path) else null
	cache[name] = st
	return st


func _process(dt: float) -> void:
	if tracks.is_empty():
		return
	if not music.playing:
		_pause_t -= dt
		if _pause_t <= 0.0:
			cur = (cur + 1) % order.size()
			music.stream = load(tracks[order[cur]])
			music.volume_db = -6.0
			music.play()
	# птицы днём, тише издалека; ночью тишина
	if game and game.ready_done:
		var h: float = game.hour
		var day := smoothstep(5.0, 7.0, h) * (1.0 - smoothstep(19.5, 21.0, h))
		var near := 1.0 - smoothstep(40.0, 110.0, game.rig.dist) if game.rig else 0.5
		var target := lerpf(-60.0, -15.0, day * (0.35 + 0.65 * near))
		ambient.volume_db = lerpf(ambient.volume_db, target, minf(1.0, dt * 1.5))


func ui(name := "click") -> void:
	var st := _load(SFX.get(name, "click.ogg"))
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
