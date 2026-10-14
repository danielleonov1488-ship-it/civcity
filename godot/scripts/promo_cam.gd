extends Node
## Съёмка клипов для промо-ролика в витрине (режим --promo, scripts/showcase.gd).
## Камера летит по гладкому сплайну (Catmull–Rom по точке взгляда, повороту, наклону и масштабу), кадры
## идут прямо в ffmpeg (x264) — экран загрузки в видео не попадает. Время кадра фиксированное (--fixed-fps 30):
## сколько бы ни считался кадр, в видео всё движется с нормальной скоростью (мелкие анимации — по AnimClock).
## Картинка считается в нужном размере (2560×1440, 1080×1920, 3840×2160) независимо от размера окна.
##
## Один клип за запуск, только через замок видеокарты:
##   bash /d/CivCity/.work/py/gpu_run.sh --fixed-fps 30 res://promo_cam.tscn -- clip=street
##        [vertical] [size=2560x1440] [out=путь.mp4] [warm=8] [dur=9] [crf=13]
##   проверка композиции (кадры начала/середины/конца, JPG): ... -- check=street,market [vertical] [size=960x540] [out=DIR]
##   снимки для сайта (PNG): ... -- stills=all|имя,имя [size=3840x2160] [out=D:/CivCity/site_media/screens]
## Без vertical — 2560×1440 в promo/video/public2/shots2/<клип>.mp4; vertical — 1080×1920 в promo/video/public2/shots2/<клип>_v.mp4;
## петли (loop_*) — 1920×1080 в promo/video/public2/shots2/<клип>.mp4 (петлю склеивает promo/site_media.py).

const FPS := 30
const LIFE := 11.0                   # час, в который город «просыпается» перед съёмкой: дела, лавки, прогулки
const SHOTS := "D:/CivCity/promo/video/public2/shots2"

## Клипы. keys: [время, точка взгляда (x, подъём над землёй, z), поворот°, наклон°, масштаб] — как в CameraRig/Showcase.VIEWS
## (поворот 0 — камера с юга смотрит на север, 90 — с востока; масштаб × CameraRig.K = расстояние до точки).
## hour — [час в начале, час в конце]; ease — none / inout / out; fov — угол объектива по вертикали (в игре 30°).
## follow — точка и поворот считаются от предмета: cat — кошка на скамье, cart — повозка с переселенцами,
## house — дом, который растёт (поворот 0 — камера перед ним). v — для вертикального ролика: свои keys или
## поправки dist (множитель), pitch/yaw (прибавить), fov (угол по ширине кадра), dur.
const CLIPS := {
	# семьи въезжают на повозке через арку, раннее утро; камера едет перед повозкой и обходит её сбоку
	"arrival": {"dur": 10.0, "hour": [7.0, 7.3], "follow": "cart", "cart_z": 57.0,
		"keys": [[0.0, Vector3(0, 1.2, 0.0), 4.0, 9.0, 13.5], [5.0, Vector3(0, 1.0, 0.0), 22.0, 13.0, 13.0], [10.0, Vector3(0, 1.0, 0.0), 44.0, 21.0, 13.5]],
		"v": {"dist": 1.15, "fov": 30.0, "dur": 8.0}},
	# пролёт по главной улице с севера к рынку
	"street": {"dur": 10.0, "hour": [8.0, 8.2],
		"keys": [[0.0, Vector3(192, 0, 128), 186.0, 21.0, 31.0], [10.0, Vector3(192, 0, 156), 178.0, 18.0, 27.0]],
		"v": {"dist": 1.1, "pitch": 4.0, "fov": 30.0, "dur": 7.0}},
	# дом вырастает из земли и надстраивает этажи
	"grow": {"dur": 9.0, "hour": [9.6, 9.7], "follow": "house", "house": Vector2(169.6, 156.0), "ease": "inout",
		"keys": [[0.0, Vector3(0, 2.4, 0), -30.0, 24.0, 15.0], [9.0, Vector3(0, 3.0, 0), 6.0, 20.0, 13.5]],
		"events": [[0.5, "build"], [3.5, "floor"], [6.2, "floor"]],
		"v": {"dist": 1.1, "pitch": 6.0, "fov": 30.0}},
	# рынок: люди у прилавков, фонтан — медленный облёт
	"market": {"dur": 9.0, "hour": [10.0, 10.1],
		"keys": [[0.0, Vector3(192, 0, 172), 12.0, 38.0, 23.0], [9.0, Vector3(192, 0, 172), 46.0, 33.0, 20.5]],
		"v": {"dist": 1.1, "fov": 30.0, "dur": 7.0}},
	# ребёнок подходит погладить кошку на форуме
	"cat": {"dur": 8.0, "hour": [16.6, 16.65], "follow": "cat", "spot": Vector2(157.0, 155.5), "cam": 112.0, "ease": "inout", "fov": 26.0,
		"keys": [[0.0, Vector3(0, 0.4, 0), -12.0, 13.0, 4.0], [8.0, Vector3(0, 0.36, 0), 10.0, 10.0, 3.5]],
		"v": {"dist": 1.15, "fov": 28.0}},
	# улица вилл: сады, пальмы, портики
	"villa": {"dur": 9.0, "hour": [16.5, 16.6],
		"keys": [[0.0, Vector3(198, 0, 209), 158.0, 27.0, 23.0], [9.0, Vector3(211, 0, 209), 170.0, 25.0, 21.0]],
		"v": {"dist": 1.1, "fov": 30.0, "dur": 7.0}},
	# парк у пруда: лебеди, беседки
	"park": {"dur": 9.0, "hour": [17.0, 17.1],
		"keys": [[0.0, Vector3(215, 0, 150), 312.0, 34.0, 32.0], [9.0, Vector3(215, 0, 150), 338.0, 31.0, 28.0]],
		"v": {"dist": 1.1, "fov": 30.0, "dur": 7.0}},
	# форум с пантеоном
	"forum": {"dur": 9.0, "hour": [16.4, 16.5],
		"keys": [[0.0, Vector3(150, 0, 158), 48.0, 28.0, 38.0], [9.0, Vector3(154, 0, 156), 76.0, 25.0, 34.0]],
		"v": {"dist": 1.1, "fov": 30.0, "dur": 7.0}},
	# акведук с холмов
	"aqueduct": {"dur": 9.0, "hour": [17.3, 17.4],
		"keys": [[0.0, Vector3(104, 0, 117), 206.0, 18.0, 56.0], [9.0, Vector3(117, 0, 122), 216.0, 18.0, 52.0]],
		"v": {"dist": 1.1, "fov": 30.0, "dur": 7.0}},
	# большой отлёт: от рынка — на весь город в золотой час
	"pullback": {"dur": 11.0, "hour": [17.5, 17.6], "ease": "out",
		"keys": [[0.0, Vector3(192, 0, 172), 30.0, 40.0, 22.0], [11.0, Vector3(194, 0, 166), 18.0, 34.0, 112.0]],
		"v": {"dist": 1.0, "fov": 30.0, "dur": 8.0}},
	# храм Юпитера на закате: медленный наезд
	"temple": {"dur": 9.0, "hour": [18.1, 18.4],
		"keys": [[0.0, Vector3(192, 2.0, 236), 174.0, 20.0, 23.0], [9.0, Vector3(192, 2.0, 237), 186.0, 17.0, 19.0]],
		"v": {"dist": 1.15, "pitch": 2.0, "fov": 30.0, "dur": 7.0}},
	# сумерки: в окнах зажигается свет
	"dusk": {"dur": 10.0, "hour": [19.6, 21.7],
		"keys": [[0.0, Vector3(192, 0, 148), 188.0, 24.0, 36.0], [10.0, Vector3(192, 0, 157), 180.0, 25.0, 33.0]],
		"v": {"dist": 1.1, "fov": 30.0, "dur": 7.0}},
	# ночь: фонари и жаровни на рынке
	"night": {"dur": 9.0, "hour": [22.2, 22.3],
		"keys": [[0.0, Vector3(192, 0, 170), 34.0, 31.0, 44.0], [9.0, Vector3(192, 0, 171), 14.0, 29.0, 38.0]],
		"v": {"dist": 1.1, "fov": 30.0, "dur": 7.0}},
	# ---- петли для сайта: камера почти стоит, жизнь идёт (7 с, склейка в петлю 5 с) ----
	"loop_market": {"dur": 7.0, "hour": [10.0, 10.0], "size": Vector2i(1920, 1080),
		"keys": [[0.0, Vector3(192, 0, 172), 33.0, 35.0, 24.0], [7.0, Vector3(192, 0, 172), 34.0, 35.0, 24.0]]},
	"loop_street": {"dur": 7.0, "hour": [8.2, 8.2], "size": Vector2i(1920, 1080),
		"keys": [[0.0, Vector3(192, 0, 150), 186.0, 22.0, 30.0], [7.0, Vector3(192, 0, 150), 186.5, 22.0, 30.0]]},
	"loop_park": {"dur": 7.0, "hour": [17.0, 17.0], "size": Vector2i(1920, 1080),
		"keys": [[0.0, Vector3(215, 0, 150), 300.0, 32.0, 30.0], [7.0, Vector3(215, 0, 150), 301.0, 32.0, 30.0]]},
	"loop_villa": {"dur": 7.0, "hour": [16.5, 16.5], "size": Vector2i(1920, 1080),
		"keys": [[0.0, Vector3(205, 0, 210), 165.0, 28.0, 26.0], [7.0, Vector3(205, 0, 210), 166.0, 28.0, 26.0]]},
	"loop_forum": {"dur": 7.0, "hour": [16.5, 16.5], "size": Vector2i(1920, 1080),
		"keys": [[0.0, Vector3(152, 0, 157), 60.0, 30.0, 36.0], [7.0, Vector3(152, 0, 157), 61.0, 30.0, 36.0]]},
	"loop_temple": {"dur": 7.0, "hour": [18.2, 18.2], "size": Vector2i(1920, 1080),
		"keys": [[0.0, Vector3(192, 0, 229), 180.0, 18.0, 34.0], [7.0, Vector3(192, 0, 229), 181.0, 18.0, 34.0]]},
	"loop_night": {"dur": 7.0, "hour": [22.3, 22.3], "size": Vector2i(1920, 1080),
		"keys": [[0.0, Vector3(192, 0, 171), 26.0, 31.0, 42.0], [7.0, Vector3(192, 0, 171), 27.0, 31.0, 42.0]]},
	"loop_fields": {"dur": 7.0, "hour": [7.4, 7.4], "size": Vector2i(1920, 1080),
		"keys": [[0.0, Vector3(192, 0, 82), 160.0, 26.0, 46.0], [7.0, Vector3(192, 0, 82), 161.0, 26.0, 46.0]]},
}

## Снимки для сайта: [имя, клип, секунда клипа] — поза камеры, час и подготовка (кошка, повозка) берутся из клипа
const STILLS := [
	["overview", "pullback", 11.0], ["market", "market", 4.5], ["main-street", "loop_street", 0.0], ["cat", "cat", 1.6],
	["villas", "villa", 4.5], ["temple-sunset", "temple", 6.0], ["park", "park", 4.5], ["forum", "forum", 4.5],
	["arrival", "arrival", 4.0], ["dusk", "dusk", 9.0], ["night", "night", 4.5], ["aqueduct", "aqueduct", 4.5],
]

var game
var rig: CameraRig
var args := {}
var clip := {}
var clip_name := ""
var vertical := false
var W := 2560
var H := 1440
var dur := 9.0
var keys := []                       # [t, Vector3 цель (с высотой земли), yaw°, pitch°, ln(dist)]
var state := "boot"
var warm_n := 120
var warm_i := 0
var rec_i := 0
var rec_n := 0
var frames_total := 0
var ev_i := 0
var out := ""
var pipe: FileAccess
var pid := -1
# предметы, за которыми следит камера
var anchor_pos := Vector3.ZERO
var anchor_yaw := 0.0                # градусы
var follow := ""
var cat := {}
var petter := {}
var cart_z := 0.0
var pin_cart := false
var house := {}
var house_spec := {}
var hold_t := 0.0                    # проверка и снимки: камера стоит на этой секунде клипа
var life_until := 0                  # до этого кадра часы стоят на «часе жизни» (clip.life): горожане выходят из домов


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	vertical = args.has("vertical")
	process_priority = 1000           # после людей и повозки: кошку на скамью и камеру ставим последними
	set_process(false)
	var h0 := 9.0
	if args.has("clip"):
		clip_name = str(args["clip"])
		if not CLIPS.has(clip_name):
			push_error("нет клипа " + clip_name)
			get_tree().quit(2)
			return
		h0 = float(CLIPS[clip_name].get("life", LIFE))
	Game.boot = {"promo": "1", "noui": "1", "hour": str(h0), "shot": "D:/CivCity/.work/promo/_unused.png", "frames": "999999999"}
	var t0 := Time.get_ticks_msec()
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	while not game.ready_done:
		await _frames(5)
	print("PROMO_CAM city ready in %d ms" % (Time.get_ticks_msec() - t0))
	game.hud.visible = false
	AudioServer.set_bus_mute(0, true)          # пока считаются кадры, игра молчит (музыку кладём при монтаже)
	await _frames(4)                           # витрина ставит вид и выпускает кошек
	rig = game.rig
	rig.cine = true
	AnimClock.movie = 0.0
	if args.has("stills"):
		await _stills()
	elif args.has("check"):
		await _check()
	else:
		_start_clip()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Размер картинки: окно маленькое, а 3D считается ровно в W×H (растяжение «viewport»)
func _set_size(w: int, h: int) -> void:
	W = w
	H = h
	var win := get_tree().root
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var k := minf(960.0 / w, 720.0 / h)
	win.size = Vector2i(int(w * k), int(h * k))
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	win.content_scale_size = Vector2i(w, h)
	win.content_scale_factor = 1.0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0


func _parse_size(def: Vector2i) -> Vector2i:
	if args.has("size"):
		var s := str(args["size"]).split("x")
		return Vector2i(int(s[0]), int(s[1]))
	return def


# ---------- клип ----------

func _load_clip(name: String) -> void:
	clip_name = name
	clip = CLIPS[name]
	var v: Dictionary = clip.get("v", {}) if vertical else {}
	dur = float(v.get("dur", clip["dur"]))
	if args.has("dur"):
		dur = float(args["dur"])
	var src: Array = v.get("keys", clip["keys"])
	var cdur := float(clip["dur"])
	follow = str(clip.get("follow", ""))
	keys = []
	var prev_yaw := INF
	for k: Array in src:
		var t := float(k[0]) * dur / cdur            # укороченный клип — тот же путь, быстрее
		var p: Vector3 = k[1]
		var yaw := float(k[2]) + float(v.get("yaw", 0.0))
		if prev_yaw != INF:
			yaw = prev_yaw + wrapf(yaw - prev_yaw, -180.0, 180.0)
		prev_yaw = yaw
		var pitch := float(k[3]) + float(v.get("pitch", 0.0))
		var dist := float(k[4]) * float(v.get("dist", 1.0))
		if follow == "":
			p.y += maxf(1.0, game.land.height_at(p.x, p.z))
		keys.append([t, p, yaw, pitch, log(dist)])
	var cam: Camera3D = rig.cam
	if vertical:
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		cam.fov = float(v.get("fov", 30.0))
	else:
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.fov = float(clip.get("fov", 30.0))
	rig.attrs.dof_blur_amount = float(clip.get("blur", 0.09))
	ev_i = 0


func _start_clip() -> void:
	_load_clip(clip_name)
	var def: Vector2i = Vector2i(1080, 1920) if vertical else clip.get("size", Vector2i(2560, 1440))
	var sz := _parse_size(def)
	_set_size(sz.x, sz.y)
	out = str(args.get("out", SHOTS.path_join(clip_name + ("_v" if vertical else "") + ".mp4")))
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	_setup(true)
	warm_n = int(float(args.get("warm", "8")) * FPS)
	life_until = frames_total + maxi(0, warm_n - 75)    # последние 2,5 с прогрева — уже при свете клипа
	rec_n = int(round(dur * FPS))
	state = "warm"
	RenderingServer.frame_post_draw.connect(_post_draw)
	set_process(true)
	print("PROMO_CAM clip %s %dx%d, %.1f s (%d frames) -> %s" % [clip_name, W, H, dur, rec_n, out])


## Подготовка: кошка на скамью, повозка к арке, дом под снос (full — по-настоящему, для съёмки)
func _setup(full: bool) -> void:
	match follow:
		"cat":
			_setup_cat()
		"cart":
			_setup_cart()
		"house":
			_setup_house(full)


func _process(_dt: float) -> void:
	frames_total += 1
	AnimClock.movie = frames_total / float(FPS)
	if state == "hold":
		_pose(hold_t)
	if state == "warm":
		warm_i += 1
		_pose(0.0)
		if warm_i >= warm_n and (_gate() or warm_i > warm_n + 40 * FPS):
			_rec_start()
			state = "rec"
			rec_i = 0
	if state == "rec":
		var t := rec_i / float(FPS)
		_events(t)
		_pose(t)


func _rec_start() -> void:
	pin_cart = false
	var ff := str(args.get("ffmpeg", "ffmpeg"))
	var crf := str(args.get("crf", "13"))
	var a := PackedStringArray(["-y", "-hide_banner", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % [W, H],
		"-r", str(FPS), "-i", "-", "-c:v", "libx264", "-preset", str(args.get("preset", "faster")), "-crf", crf,
		"-pix_fmt", "yuv420p", "-movflags", "+faststart", out])
	var pr := OS.execute_with_pipe(ff, a)
	if pr.is_empty():
		push_error("ffmpeg не запустился")
		get_tree().quit(3)
		return
	pipe = pr["stdio"]
	pid = int(pr["pid"])


func _post_draw() -> void:
	if state != "rec":
		return
	var img := get_viewport().get_texture().get_image()
	if img.get_format() != Image.FORMAT_RGB8:
		img.convert(Image.FORMAT_RGB8)
	if img.get_width() != W or img.get_height() != H:
		if rec_i == 0:
			print("PROMO_CAM warning: frame %dx%d, resizing to %dx%d" % [img.get_width(), img.get_height(), W, H])
		img.resize(W, H, Image.INTERPOLATE_LANCZOS)
	pipe.store_buffer(img.get_data())
	if rec_i == 0 or rec_i == rec_n / 2 or rec_i == rec_n - 1:
		var pv := "D:/CivCity/.work/promo/cam_rec"
		DirAccess.make_dir_recursive_absolute(pv)
		img.save_jpg(pv.path_join(out.get_file().get_basename() + "_%d.jpg" % (0 if rec_i == 0 else (1 if rec_i == rec_n / 2 else 2))), 0.88)
	rec_i += 1
	if rec_i >= rec_n:
		state = "done"
		_finish()


func _finish() -> void:
	pipe.flush()
	pipe.close()
	var t0 := Time.get_ticks_msec()
	while OS.is_process_running(pid) and Time.get_ticks_msec() - t0 < 120000:
		OS.delay_msec(100)
	var ok := FileAccess.file_exists(out)
	print("PROMO_CAM done %s: %s, %d frames" % [clip_name, "ok" if ok else "FAILED", rec_n])
	get_tree().quit(0 if ok else 4)


# ---------- путь камеры ----------

func _ease(u: float) -> float:
	match str(clip.get("ease", "none")):
		"inout":
			return lerpf(u, u * u * (3.0 - 2.0 * u), 0.7)
		"out":
			return 1.0 - pow(1.0 - u, 2.2)
		"in":
			return pow(u, 1.6)
	return u


## Эрмитов сплайн по ключам (касательные — Catmull–Rom; на краях — наклон крайнего отрезка: без остановок)
func _spline(i_val: int, t: float) -> Variant:
	var n := keys.size()
	if n == 1:
		return keys[0][i_val]
	var i := 0
	while i < n - 2 and t > float(keys[i + 1][0]):
		i += 1
	var t0 := float(keys[i][0])
	var t1 := float(keys[i + 1][0])
	var h := maxf(0.0001, t1 - t0)
	var u := clampf((t - t0) / h, 0.0, 1.0)
	var v0 = keys[i][i_val]
	var v1 = keys[i + 1][i_val]
	var m0 = _tangent(i_val, i)
	var m1 = _tangent(i_val, i + 1)
	var u2 := u * u
	var u3 := u2 * u
	return (2.0 * u3 - 3.0 * u2 + 1.0) * v0 + (u3 - 2.0 * u2 + u) * h * m0 + (-2.0 * u3 + 3.0 * u2) * v1 + (u3 - u2) * h * m1


func _tangent(i_val: int, k: int) -> Variant:
	var n := keys.size()
	var a := maxi(0, k - 1)
	var b := mini(n - 1, k + 1)
	return (keys[b][i_val] - keys[a][i_val]) / maxf(0.0001, float(keys[b][0]) - float(keys[a][0]))


func _pose(t: float) -> void:
	var u := _ease(clampf(t / dur, 0.0, 1.0)) * dur
	var tgt: Vector3 = _spline(1, u)
	var yaw: float = _spline(2, u)
	var pitch: float = _spline(3, u)
	var dist := exp(float(_spline(4, u)))
	if follow != "":
		_anchor()
		var a := deg_to_rad(anchor_yaw)
		var f := Vector3(sin(a), 0, cos(a))
		var r := Vector3(cos(a), 0, -sin(a))
		tgt = anchor_pos + r * tgt.x + Vector3.UP * tgt.y + f * tgt.z
		yaw += anchor_yaw
	var y := deg_to_rad(yaw)
	var p := deg_to_rad(pitch)
	var off := Vector3(sin(y) * cos(p), sin(p), cos(y) * cos(p)) * dist * CameraRig.K
	rig.cine_look(tgt + off, tgt)
	var hs: Array = clip["hour"]
	var h0 := float(hs[0])
	var h1 := float(hs[hs.size() - 1])
	var hr := lerpf(h0, h1, clampf(t / dur, 0.0, 1.0))
	if frames_total < life_until:
		hr = float(clip.get("life", LIFE))
	game._set_hour(hr)
	if pin_cart:
		_pin_cart(t)


func _anchor() -> void:
	match follow:
		"cart":
			var c: Dictionary = game.people.cart
			if not c.is_empty():
				var n: Node3D = c["n"]
				anchor_pos = n.position
			anchor_yaw = 0.0


# ---------- кошка: ребёнок выходит из дома погладить её ----------

## Кошка сидит на площади; ребёнок (или взрослый) из ближайшего дома или с улицы идёт к ней и гладит —
## как в игре (People: «cat»). Съёмка начинается, когда он уже в паре шагов от кошки.
func _setup_cat() -> void:
	var city: City = game.city
	var ppl = game.people
	if ppl.cats.is_empty():
		push_warning("нет кошек")
		return
	anchor_yaw = float(clip.get("cam", 110.0))
	var cy := deg_to_rad(anchor_yaw)
	var cam_dir := Vector2(sin(cy), cos(cy))
	var spot := _find_spot(clip["spot"], cam_dir)
	# рыжая (или светлая) кошка — её лучше видно
	cat = ppl.cats[0]
	for want_fur in [Color("e0913f"), Color("f2ede4"), Color("a87447")]:
		var found := false
		for c: Dictionary in ppl.cats:
			if c.get("fur") == want_fur:
				cat = c
				found = true
		if found:
			break
	if not petter.is_empty():
		ppl._release(petter)
	cat["state"] = "sit"
	cat["t"] = 999.0
	cat["pet"] = 0
	cat["p"] = spot
	cat["path"] = PackedVector2Array()
	cat["yaw"] = atan2(cam_dir.x, cam_dir.y) + PI / 2       # боком к камере
	ppl._cat_place(cat)
	anchor_pos = Vector3(spot.x, game.land.height_at(spot.x, spot.y), spot.y)
	# кто погладит: ребёнок из дома рядом (лучше — тот, кто дома: выйдет из дверей), иначе любой прохожий поблизости
	petter = {}
	var best := 1.0e9
	for r: Dictionary in ppl.residents:
		if r["state"] in ["work", "door"] or r["act"] == "talk" or not (r["conv"] as Dictionary).is_empty():
			continue
		var h: Dictionary = city.buildings.get(r["home"], {})
		var from: Vector2 = city.door_point(h) if r["state"] == "home" and not h.is_empty() else r["p"]
		var d := from.distance_to(spot)
		if d < 4.0 or d > 22.0:
			continue
		d += 0.0 if r["child"] else 8.0
		d += 0.0 if r["state"] == "home" else 3.0
		if d < best:
			best = d
			petter = r
	if petter.is_empty():
		push_warning("некому гладить кошку")
		return
	# подходит сбоку от кошки (с той стороны, откуда идёт): из камеры оба в профиль
	var side := Vector2(cam_dir.y, -cam_dir.x)
	if side.dot((petter["p"] as Vector2) - spot) < 0.0:
		side = -side
	var tgt := {"act": "cat", "cat": cat, "p": spot + side * 0.45, "face": spot}
	ppl._release(petter)
	ppl._claim(petter, tgt)
	ppl._go(petter, tgt["p"], "errand", true)
	print("PROMO_CAM cat at %s, petter %d (%s, child %s) from %s" % [str(spot), int(petter["id"]), petter["state"], str(petter["child"]), str(petter["p"])])


## Свободное место для кошки рядом с want: вокруг пусто (нет построек и украшений), и между ней и камерой — тоже
func _find_spot(want: Vector2, cam_dir: Vector2) -> Vector2:
	var land: Land = game.land
	var side := Vector2(cam_dir.y, -cam_dir.x)
	for ring in 12:
		var rr := ring * 0.6
		var n := 1 if ring == 0 else 6 + ring * 3
		for q in n:
			var a := TAU * q / n
			var p := want + Vector2(cos(a), sin(a)) * rr
			var ok := true
			for o: Vector2 in [Vector2.ZERO, Vector2(1.3, 0), Vector2(-1.3, 0), Vector2(0, 1.3), Vector2(0, -1.3), Vector2(0.9, 0.9), Vector2(-0.9, 0.9), Vector2(0.9, -0.9), Vector2(-0.9, -0.9)]:
				var c := land.cell(p + o)
				var k := land.idx(c.x, c.y)
				if land.occ_at(p + o) != 0 or land.hq(k) < Land.WATER_Y + 0.2:
					ok = false
					break
			if ok:
				for t in range(1, 9):
					for w: float in [0.0, 0.7, -0.7]:
						if land.occ_at(p + cam_dir * t + side * w) != 0:
							ok = false
			if ok:
				return p
	return want


## Можно снимать: тот, кто гладит, в паре шагов от кошки (или уже гладит)
func _gate() -> bool:
	if follow != "cat" or petter.is_empty() or cat.is_empty():
		return true
	return cat["state"] == "pet" or (petter["p"] as Vector2).distance_to(cat["p"]) < float(clip.get("gate", 2.4))


# ---------- повозка с переселенцами ----------

func _setup_cart() -> void:
	var ppl = game.people
	var c: Dictionary = ppl.cart
	if c.is_empty():
		push_warning("нет повозки")
		return
	cart_z = float(clip.get("cart_z", 52.0))
	game.city.incoming = 3
	c["state"] = "wait"
	c["t"] = 0.0
	c["show"] = true
	pin_cart = true


## Пока греемся — повозка стоит у арки (идёт на месте); в съёмке едет сама своим шагом
func _pin_cart(t: float) -> void:
	var c: Dictionary = game.people.cart
	if c.is_empty() or c["state"] != "in":
		return
	game.people.cart_seek_z(cart_z + People.CART_V * t)


# ---------- дом растёт ----------

func _setup_house(full: bool) -> void:
	var city: City = game.city
	var want: Vector2 = clip["house"]
	var best := {}
	var bd := 1.0e9
	for id in city.buildings:
		var b: Dictionary = city.buildings[id]
		if not (b["type"] in ["house_pleb", "house_artisan"]):
			continue
		var d := (b["pos"] as Vector2).distance_to(want)
		if d < bd:
			bd = d
			best = b
	if best.is_empty():
		return
	var f := City.facing(best["yaw"])
	anchor_pos = Vector3(best["pos"].x, float(best["y"]), best["pos"].y)
	anchor_yaw = rad_to_deg(atan2(f.x, f.y))
	house_spec = {"type": best["type"], "pos": best["pos"], "yaw": best["yaw"], "variant": best["variant"], "color": best["color"]}
	print("PROMO_CAM house %d %s at %s, facing %.0f°" % [int(best["id"]), best["type"], str(best["pos"]), anchor_yaw])
	if full:
		city.remove(best, false)
	else:
		house = best


func _events(t: float) -> void:
	var evs: Array = clip.get("events", [])
	while ev_i < evs.size() and t >= float(evs[ev_i][0]) * dur / float(clip["dur"]):
		match str(evs[ev_i][1]):
			"build":
				_ev_build()
			"floor":
				_ev_floor()
		ev_i += 1


func _ev_build() -> void:
	var city: City = game.city
	var s := house_spec
	game.build_anim = true
	var b: Dictionary = city.place(s["type"], s["pos"], s["yaw"], s["variant"], s["color"], true)
	game.build_anim = false
	if b.is_empty():
		push_warning("дом не встал обратно")
		return
	_fill(b)
	house = b


func _fill(b: Dictionary) -> void:
	var city: City = game.city
	b["pop"] = city.house_cap(b)
	var fams := []
	var per := int(Defs.CLASSES[city.def(b)["cls"]]["per_floor"])
	for k in int(b["tier"]):
		fams.append({"name": Defs.FAMILIES[(int(b["id"]) + k) % Defs.FAMILIES.size()], "n": per})
	b["families"] = fams


## Надстройка этажа: дом с новым этажом поднимается из-под земли на высоту этажа (низ скрыт землёй — будто
## вырастает снизу), у основания — облачка пыли; в конце на его месте настоящий дом
func _ev_floor() -> void:
	if house.is_empty():
		return
	var city: City = game.city
	var b := house
	var cls: String = city.def(b)["cls"]
	if int(b["tier"]) >= Defs.floors_max(cls):
		return
	var og := Parts.ghost(city.blueprint(b), "place")
	var old_h := _height(og)
	og.free()
	var old := int(b["tier"])
	b["tier"] = old + 1
	_fill(b)
	var gh := Parts.ghost(city.blueprint(b), "place")
	var dy := maxf(1.0, _height(gh) - old_h)
	for mi: GeometryInstance3D in gh.find_children("*", "GeometryInstance3D", true, false):
		mi.material_overlay = null
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var xf := city.xf(b)
	gh.transform = xf
	gh.position = xf.origin - Vector3(0, dy, 0)
	game._hide(b)
	game.add_child(gh)
	var base := Vector3(b["pos"].x, float(b["y"]), b["pos"].y)
	var tw: Tween = game.create_tween()
	tw.tween_property(gh, "position", xf.origin + Vector3(0, 0.06, 0), 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(gh, "position", xf.origin, 0.25).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		gh.queue_free()
		if city.buildings.has(b["id"]):
			game._show(b))
	game._puff(base, Color("efe3c8"))
	get_tree().create_timer(0.5).timeout.connect(func(): game._puff(base, Color("efe3c8")))
	get_tree().create_timer(1.6).timeout.connect(func(): game._puff(base + Vector3(0, 0.2, 0), Color("fff3c8")))


## Высота модели (верх всех её частей) — по чертежу, собранному в узлы
static func _height(n: Node3D) -> float:
	var top := 0.0
	var stack := [[n, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var node: Node = it[0]
		var xf: Transform3D = it[1]
		for ch in node.get_children():
			if ch is Node3D:
				var cx := xf * (ch as Node3D).transform
				if ch is MeshInstance3D and (ch as MeshInstance3D).mesh:
					top = maxf(top, (cx * (ch as MeshInstance3D).mesh.get_aabb()).end.y)
				stack.append([ch, cx])
	return top


# ---------- проверка композиции ----------

func _check() -> void:
	var names := str(args["check"]).split(",")
	var sz := _parse_size(Vector2i(540, 960) if vertical else Vector2i(960, 540))
	_set_size(sz.x, sz.y)
	var dir := str(args.get("out", "D:/CivCity/.work/promo/cam_check"))
	DirAccess.make_dir_recursive_absolute(dir)
	state = "hold"
	set_process(true)
	for nm in names:
		if not CLIPS.has(nm):
			continue
		_load_clip(nm)
		cat = {}
		pin_cart = false
		life_until = frames_total + 40
		_setup(false)
		var first := true
		for u: float in [0.0, 0.5, 1.0]:
			hold_t = u * dur
			await _frames(75 if first else 30)
			var guard := 0
			while first and not _gate() and guard < 40 * FPS:
				await _frames(1)
				guard += 1
			first = false
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var fn := dir.path_join("%s%s_%d.jpg" % [nm, "_v" if vertical else "", int(u * 2)])
			img.save_jpg(fn, 0.85)
			print("CHECK ", fn)
	print("PROMO_CAM check done")
	get_tree().quit()


# ---------- снимки для сайта ----------

func _stills() -> void:
	var sel := str(args["stills"])
	var sz := _parse_size(Vector2i(3840, 2160))
	_set_size(sz.x, sz.y)
	var dir := str(args.get("out", "D:/CivCity/site_media/screens"))
	DirAccess.make_dir_recursive_absolute(dir)
	state = "hold"
	set_process(true)
	var first := true
	for s: Array in STILLS:
		if sel != "all" and not (s[0] in sel.split(",")):
			continue
		_load_clip(s[1])
		cat = {}
		pin_cart = false
		life_until = frames_total + (90 if first else 25)
		_setup(false)
		hold_t = minf(float(s[2]), dur)
		await _frames(150 if first or follow == "cart" else 70)
		if follow == "cat":
			var guard := 0
			while not (not cat.is_empty() and cat["state"] == "pet") and guard < 40 * FPS:
				await _frames(1)
				guard += 1
			await _frames(int(float(s[2]) * FPS))
		first = false
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var fn := dir.path_join("civcity-%s.png" % s[0])
		img.save_png(fn)
		print("STILL ", fn)
	print("PROMO_CAM stills done")
	get_tree().quit()
