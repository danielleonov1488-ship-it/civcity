extends Node
## Этап 1 (1.12): замеры скорости и проверка «Средняя и Высокая — ни пикселя не изменилось» (против эталона GOLDEN).
##   bash .work/py/gpu_run.sh res://test_perf.tscn -- mode=regress          — для regress.sh: в конце «PERF DONE fails=0»
##   … -- mode=measure q=high,medium,low,verylow [city=new|путь] [views=имя:x:z:yaw:pitch:dist,…] [n=120 warm=60 settle=20]
##   … -- mode=shots out=ПАПКА [ref=ПАПКА] [q=high,medium]                 — снимки (и сверка с эталоном)
##   … -- mode=hitch q=low [frames=1200]                                    — рывки кадра (с автосохранением и ходом дня)
##   … -- mode=menu q=high,medium                                           — меню с витриной
##   … -- mode=menu boot_q=verylow q=verylow                                — меню, запущенное на этом качестве (лёгкий городок)
## Город: по умолчанию копия города владельца (D:/CivCity/.work/owner_save/city.json) — кладётся в свою папку
## сохранений запуска (gpu_run.sh даёт каждому запуску свою); city=new — новый городок.
## Снимки: час 9, время стоит (Engine.time_scale = 0 — вода и дым не двигаются), жители, звери, дым, птицы и
## интерфейс спрятаны; 3 вида. Эталон — снимки той же сборки до правок скорости (D:/CivCity/.work/perf_ref/golden).
## Постройки в городе поменяли намеренно — эталон перезаписать: … -- mode=shots rec=1 (на сборке без правок скорости
## вида Средней/Высокой это то же самое, что сейчас).

const OWNER := "D:/CivCity/.work/owner_save/city.json"
## Этап 4 (окантовка у домов, бордюры, новые утки) намеренно поменял картинку города — эталон записан заново в свою папку
## (… -- mode=shots rec=1 на сборке этапа 4): прежний «golden» остаётся у линии, где этапа 4 ещё нет.
## 26.10 включены облегчённая «Средняя» (Gfx.MEDIUM_LIGHT) и сжатие картинок Synty Basis (deploy/tex_vram.py basis) —
## эталон записан заново: … -- mode=shots rec=1 ref=D:/CivCity/.work/perf_ref/golden_s5 (снимки «было/стало» —
## .work/enable_gfx). Нужен импорт с Basis: линия с прежними несжатыми картинками в .godot/imported на «Высокой»
## разойдётся с ним (средняя разница ~2) — там сначала tools/godot.sh --headless --path godot --import
## 8.11 одеон получил трибуны круче (зрители садятся) — в городе владельца два одеона: эталон записан заново (golden_s6);
## прежний golden_s5 остаётся у линий без этой правки
## 12.11 дома, лавки, общественные здания и памятники — из своего набора (Blender), в городе владельца — старые дома,
## ужатые по прежнему следу: эталон записан заново (golden_s7); golden_s6 остаётся у линий без своего набора
## 12.11 позже: фонтан, нимфей и арка снова Synty, детали Synty в своих зданиях, своя станция — golden_s8 (сборка 52)
const GOLDEN := "D:/CivCity/.work/perf_ref/golden_s8"
const VIEWS_OWNER := "center:210:145:15:42:60,far:210:150:15:50:130,close:205:140:30:35:22"
const VIEWS_NEW := "default:192:124:15:42:60,far:192:140:15:50:130"
const SHOT_WAIT := 240               # кадров на вид перед снимком (SDFGI и тени успевают сойтись)
## Пороги этапа 1 (RTX 3060, город владельца, вид по умолчанию): «Низкая» и «Очень низкая» — время видеокарты, мс.
## Запас на соседние проверки (другая линия может грузить видеокарту): сверяем p10, а не медиану
const GATE_LOW := 7.4
const GATE_VLOW := 3.0
## Вызовы отрисовки и треугольники тени «Высокой» не должны вырасти больше чем на 10% от этих (вид center, город владельца)
const REF_HIGH := {"vis_d": 2356, "sh_d": 5295, "sh_p": 7.91e6}     # замер 25.10 до правок этапа 1 (сборка 504a0b5)

var game
var A := {}
var vp: RID
var fails := 0
var city_src := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		A[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var mode: String = A.get("mode", "regress")
	Parts.split_on = A.get("split", "1") != "0"        # 12.11: оттенок у экземпляра (split=0 — как прежде, для сравнения)
	city_src = str(A.get("city", OWNER))
	if city_src == "new" or not FileAccess.file_exists(city_src):
		if city_src != "new":
			print("PERF note: нет города ", city_src, " — меряем новый городок")
		city_src = ""
	if mode == "menu":
		if A.has("boot_q"):
			# меню строится по качеству из настроек: «Низкая» и «Очень низкая» — лёгкий городок, а не витрина
			var f := FileAccess.open(GamePaths.save_dir().path_join("settings.json"), FileAccess.WRITE)
			f.store_string(JSON.stringify({"quality": A["boot_q"], "ui_scale": 1.0, "fullscreen": false}))
			f.close()
		_boot("menu")
	elif city_src != "":
		var dst := GamePaths.save_dir().path_join("city.json")
		if city_src.simplify_path().to_lower() != dst.simplify_path().to_lower():
			DirAccess.copy_absolute(city_src, dst)
		_boot("play")
	else:
		_boot("new")
	_run.call_deferred(mode)


func _boot(m: String) -> void:
	Game.boot = {m: "1", "hour": str(A.get("hour", "9"))}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func fail(what: String) -> void:
	fails += 1
	print("FAIL perf: ", what)


func _views(def: String) -> Array:
	var out := []
	for c in str(A.get("views", def)).split(","):
		var f := c.split(":")
		out.append([f[0], float(f[1]), float(f[2]), float(f[3]), float(f[4]), float(f[5])])
	return out


func _view(v: Array) -> void:
	game.rig.set_view(Vector3(v[1], game.land.height_at(v[1], v[2]), v[2]), v[3], v[4], v[5])


func _quality(q: String) -> void:
	# «Средняя» — как в игре (Gfx.MEDIUM_LIGHT, 1.10: облегчённая, включена 26.10); для сравнений: «medium_light» —
	# облегчённая, «medium_full» — прежняя (с PCSS и MSAA 4x)
	Gfx.medium_light = true if q == "medium_light" else (false if q == "medium_full" else Gfx.MEDIUM_LIGHT)
	q = "medium" if q in ["medium_light", "medium_full"] else q
	game.settings["quality"] = q
	game._apply_quality()
	Gfx.swap_all()                            # картинки «Очень низкой» — сразу (в игре — по одной за кадр)
	Engine.max_fps = 0


func _run(mode: String) -> void:
	while not game.ready_done:
		await frames(5)
	print("PERF ready: город готов через %.1f с после запуска" % (Time.get_ticks_msec() / 1000.0))
	game.can_save = mode == "hitch"           # копия города — только в своей папке запуска; пишем лишь в замере рывков
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	Engine.max_fps = 0
	print("PERF adapter: %s | %s | type %d | window %s | city %s | buildings %d residents %d" % [RenderingServer.get_video_adapter_name(),
		RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_type(), str(get_window().size),
		city_src if city_src != "" and mode != "menu" else ("menu" if mode == "menu" else "new"), game.city.buildings.size(), game.people.residents.size()])
	match mode:
		"measure": await _measure_all()
		"shots": await _shots_mode()
		"hitch": await _hitch()
		"menu": await _menu()
		"prof": await _prof()
		"probe": await _probe()
		"vram": await _vram()
		"groups": await _groups()
		"batch": await _batch()
		"citizens": await _citizens()
		"pplprof": await _pplprof()
		"ab": await _ab()
		"gpuab": await _gpuab()
		"offer": await _offer()
		_: await _regress()
	print("PERF DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


# ---------- замеры ----------

## Время главного потока за кадр: от начала кадра (process_frame) до начала отрисовки (frame_pre_draw) — скрипты,
## анимации, физика; плюс подготовка отрисовки на процессоре (measured render time cpu). Performance.TIME_PROCESS
## не годится: это максимум за секунду, а не время кадра
var _t_frame := 0
var _proc_ms := PackedFloat32Array()
var _rec := false


func _on_frame() -> void:
	_t_frame = Time.get_ticks_usec()


func _on_pre_draw() -> void:
	if _rec and _t_frame > 0:
		_proc_ms.append((Time.get_ticks_usec() - _t_frame) / 1000.0)


func _measure(tag: String) -> Dictionary:
	if not get_tree().process_frame.is_connected(_on_frame):
		get_tree().process_frame.connect(_on_frame)
		RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	await frames(int(A.get("warm", "60")))
	var n := int(A.get("n", "120"))
	var gpu := PackedFloat32Array()
	var ft := PackedFloat32Array()
	var rc := PackedFloat32Array()
	_proc_ms = PackedFloat32Array()
	_rec = true
	var t_prev := Time.get_ticks_usec()
	for i in n:
		await get_tree().process_frame
		var tn := Time.get_ticks_usec()
		ft.append((tn - t_prev) / 1000.0)
		t_prev = tn
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
		rc.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
	_rec = false
	var RS := RenderingServer
	var r := {
		"gpu": _pct(gpu, 0.5), "p10": _pct(gpu, 0.1),
		"frame": _pct(ft, 0.5), "p95": _pct(ft, 0.95), "p99": _pct(ft, 0.99), "max": _pct(ft, 1.0),
		"proc": _pct(_proc_ms, 0.5), "phys": 0.0, "rcpu": _pct(rc, 0.5),
		"vis_d": RS.viewport_get_render_info(vp, RS.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RS.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"sh_d": RS.viewport_get_render_info(vp, RS.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RS.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"vis_p": RS.viewport_get_render_info(vp, RS.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RS.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
		"sh_p": RS.viewport_get_render_info(vp, RS.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RS.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
		"vram": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0),
		"tex": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0),
		"people": game.people.visible_count}
	r["cpu"] = r["proc"] + r["phys"] + r["rcpu"]
	print("PERF %-22s gpu %5.2f (p10 %5.2f) | cpu %5.2f (proc %5.2f rcpu %5.2f) | frame %5.2f p95 %5.2f p99 %5.2f max %5.1f fps %5.1f | dc %4d + shadow %4d | tris %5.2fM + shadow %5.2fM | vram %d MB (tex %d) | people %d" % [
		tag, r["gpu"], r["p10"], r["cpu"], r["proc"], r["rcpu"], r["frame"], r["p95"], r["p99"], r["max"], 1000.0 / maxf(0.01, r["frame"]),
		r["vis_d"], r["sh_d"], r["vis_p"] / 1.0e6, r["sh_p"] / 1.0e6, r["vram"], r["tex"], r["people"]])
	return r


static func _pct(a: PackedFloat32Array, k: float) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	return s[clampi(int(s.size() * k), 0, s.size() - 1)]


func _settle() -> void:
	var settle := float(A.get("settle", "20"))
	var ts := Time.get_ticks_msec()
	while Time.get_ticks_msec() - ts < settle * 1000.0:
		await get_tree().process_frame


func _measure_all() -> void:
	await _settle()
	var views := _views(VIEWS_OWNER if city_src != "" else VIEWS_NEW)
	for q: String in str(A.get("q", "high,medium,low,verylow")).split(","):
		_quality(q)
		for v: Array in views:
			_view(v)
			game._set_hour(float(A.get("hour", "9")))
			await _measure("%s %s" % [v[0], q])


func _menu() -> void:
	if A.has("boot_q"):
		var n: int = game.city.buildings.size()
		print("PERF menu boot_q=%s: построек %d" % [A["boot_q"], n])
		if Gfx.is_low(str(A["boot_q"])) and n > 400:
			fail("меню на «%s» строит витрину (%d построек), а не лёгкий городок" % [A["boot_q"], n])
	await _settle()
	for q: String in str(A.get("q", "high,medium")).split(","):
		_quality(q)
		await _measure("menu %s" % q)


## Рывки кадра: 1200 кадров подряд на одной графике; посередине — автосохранение, и игровой час кончается (ход дня)
func _hitch() -> void:
	await _settle()
	var q: String = A.get("q", "low")
	_quality(q)
	_view(_views(VIEWS_OWNER if city_src != "" else VIEWS_NEW)[0])
	game.hud.set_speed(1.0)
	await frames(120)
	var n := int(A.get("frames", "1200"))
	var dts := PackedFloat32Array()
	var big := []
	if not get_tree().process_frame.is_connected(_on_frame):
		get_tree().process_frame.connect(_on_frame)
		RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	_proc_ms = PackedFloat32Array()
	_rec = true
	var t_prev := Time.get_ticks_usec()
	for i in n:
		if i == n / 3:                                       # через пару кадров — новый час: ход дня (city.sim_day)
			if game.clock_hours:
				game._set_hour(floorf(game.hour) + 0.995)
			else:
				game.day_t = Game.DAY_LEN / 24.0 - 0.05
		if i == n / 2:
			game.autosave_t = 1000.0                         # автосохранение в этом кадре
		await get_tree().process_frame
		var tn := Time.get_ticks_usec()
		var d := (tn - t_prev) / 1000.0
		t_prev = tn
		dts.append(d)
		if d > 33.0:
			# из чего рывок: скрипты и анимации (кадр до отрисовки), отрисовка на процессоре, видеокарта
			var pm := _proc_ms[_proc_ms.size() - 1] if not _proc_ms.is_empty() else -1.0
			big.append("%d:%.0f(скр %.0f, отр %.0f, вк %.0f)" % [i, d, pm, RenderingServer.viewport_get_measured_render_time_cpu(vp), RenderingServer.viewport_get_measured_render_time_gpu(vp)])
	_rec = false
	var over := func(x: float) -> int: return Array(dts).filter(func(v): return v > x).size()
	print("HITCH q=%s frames=%d p50=%.1f p95=%.1f p99=%.1f max=%.1f  >25ms=%d >33ms=%d >50ms=%d  spikes(i:ms)=%s  | ход дня %.1f мс, сохранение %.1f мс" % [q, n,
		_pct(dts, 0.5), _pct(dts, 0.95), _pct(dts, 0.99), _pct(dts, 1.0), over.call(25.0), over.call(33.0), over.call(50.0), " ".join(big.slice(0, 40)),
		float(game.get("sim_ms")) if game.get("sim_ms") != null else -1.0, float(game.get("save_ms")) if game.get("save_ms") != null else -1.0])


## Что сколько стоит на главном потоке (мс, лучшее из 3): ход дня и его части, сохранение по частям
func _prof() -> void:
	await _settle()
	var c: City = game.city
	var t := func(name: String, f: Callable, n := 3) -> void:
		var best := 1.0e9
		var tot := 0.0
		for i in n:
			var t0 := Time.get_ticks_usec()
			f.call()
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			best = minf(best, ms)
			tot += ms
			await get_tree().process_frame
		print("PROF %-26s best %7.2f ms  avg %7.2f" % [name, best, tot / n])
	await t.call("city.compute", func(): c.compute())
	await t.call("city.sim_day (всё)", func(): c.sim_day())
	await t.call("hud.refresh", func(): game.hud.refresh())
	await t.call("game._sync_all_actors", func(): game._sync_all_actors())
	await t.call("game._settle_refresh", func(): game._settle_refresh())
	await t.call("cover.refresh", func(): game.cover.refresh())
	await t.call("people._assign_jobs", func(): game.people._assign_jobs())
	await t.call("people._vis_tick", func(): game.people._vis_tick())
	# 1.7: невидимые жители — по очереди (каждый 8-й за кадр) против всех каждый кадр (far_n = 1); дважды, чередуя
	var sp: float = game.speed
	game.hud.set_speed(1.0)
	for k in 2:
		game.people.far_n = People.FAR_N
		await t.call("people._process (по очереди)", func(): game.people._process(1.0 / 60.0), 60)
		game.people.far_n = 1
		await t.call("people._process (каждый кадр)", func(): game.people._process(1.0 / 60.0), 60)
	game.people.far_n = People.FAR_N
	game.hud.set_speed(sp)
	var box := {}                                # лямбды видят словарь по ссылке (переменные — копией)
	await t.call("save: city.save_data", func(): box["d"] = c.save_data())
	await t.call("save: land.save_changes", func(): box["land"] = game.land.save_changes())
	box["d"]["land"] = box["land"]
	await t.call("save: JSON.stringify", func(): box["s"] = JSON.stringify(box["d"]))
	await t.call("save: deep copy", func(): box["d"].duplicate(true))
	await t.call("save: write file", func():
		var f := FileAccess.open(GamePaths.save_dir().path_join("prof.json"), FileAccess.WRITE)
		f.store_string(box["s"])
		f.close())
	await t.call("save: Account.after_save", func(): Account.me().after_save(box["s"]))
	game.can_save = true
	await t.call("game.save (всё)", func(): game.save())
	game.can_save = false
	print("PROF save size %d KB, city.changed handlers %d" % [str(box["s"]).length() / 1024, c.changed.get_connections().size()])
	# отличия земли по кускам (с запасом заранее) — ровно то же, что прежний перебор всех клеток
	var L: Land = game.land
	var oc := PackedInt32Array()
	var ok := PackedByteArray()
	var oh := PackedFloat32Array()
	for ch in L.touched.keys():
		for j in range(ch.y * Land.CH, ch.y * Land.CH + Land.CH):
			for i in range(ch.x * Land.CH, ch.x * Land.CH + Land.CH):
				var k := L.idx(i, j)
				if L.kind[k] != L.base_kind[k] or L.h[k] != L.base_h[k]:
					oc.append(k)
					ok.append(L.kind[k])
					oh.append(L.h[k])
	var nw := L.save_changes()
	var same: bool = nw["cells"] == Marshalls.raw_to_base64(oc.to_byte_array()) and nw["kinds"] == Marshalls.raw_to_base64(ok) and nw["hs"] == Marshalls.raw_to_base64(oh.to_byte_array())
	print("PROF land save cache: %s (%d клеток)" % ["то же, что прежний перебор" if same else "ОТЛИЧАЕТСЯ", oc.size()])
	if not same:
		fail("отличия земли из кэша не совпали с прежним перебором")


## Из чего складывается время видеокарты на одной графике: убираем по одной вещи и меряем
func _probe() -> void:
	await _settle()
	var q: String = A.get("q", "verylow")
	_quality(q)
	_view(_views(VIEWS_OWNER if city_src != "" else VIEWS_NEW)[0])
	var base := await _measure("%s BASE" % q)
	var vp := get_viewport()
	var nodes := func(pred: Callable) -> Array:
		return game.find_children("*", "GeometryInstance3D", true, false).filter(pred)
	var tests := {
		"nature_hidden": [func(): _grp_vis(func(k: String): return _is_nature(k), false), func(): _grp_vis(func(k: String): return true, true)],
		"bld_hidden": [func(): _grp_vis(func(k: String): return not _is_nature(k), false), func(): _grp_vis(func(k: String): return true, true)],
		"small_hidden": [func(): _grp_vis(func(k: String): return k.contains("Grass") or k.contains("Flowers") or k.contains("Pebbles") or k.contains("Lillies") or k.contains("Garden_Plants"), false), func(): _grp_vis(func(k: String): return true, true)],
		"props_hidden": [func(): _grp_vis(func(k: String): return k.begins_with("SM_Prop") and not _is_nature(k), false), func(): _grp_vis(func(k: String): return true, true)],
		"lod4": [func(): vp.mesh_lod_threshold = 4.0, func(): vp.mesh_lod_threshold = 1.0],
		"lod16": [func(): vp.mesh_lod_threshold = 16.0, func(): vp.mesh_lod_threshold = 1.0],
		"fsr_050": [func(): vp.scaling_3d_scale = 0.5, func(): game._apply_quality()],
		"fsr_040": [func(): vp.scaling_3d_scale = 0.4, func(): game._apply_quality()],
		"people_hidden": [func(): game.people.visible = false, func(): game.people.visible = true],
		"actors_hidden": [func(): game.actors_root.visible = false, func(): game.actors_root.visible = true],
		"parts_hidden": [func(): game.parts.visible = false, func(): game.parts.visible = true],
		"land_hidden": [func(): for ch in game.chunk_nodes: game.chunk_nodes[ch].visible = false, func(): for ch in game.chunk_nodes: game.chunk_nodes[ch].visible = true],
		"far_hidden": [func(): for m in game.far_near: m.visible = false, func(): for m in game.far_near: m.visible = true],
		"fxaa_off": [func(): vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED, func(): vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA],
		"fog_off": [func(): game.env.fog_enabled = false, func(): game.env.fog_enabled = true],
		"grade_off": [func(): game.grade.shader = null, func(): game.grade.shader = load("res://shaders/grade.gdshader")],
		# кандидаты облегчённой «Средней» (1.10)
		"pcss_off": [func(): game.sun.light_angular_distance = 0.0, func(): game._apply_quality()],
		"msaa2": [func(): vp.msaa_3d = Viewport.MSAA_2X, func(): game._apply_quality()],
		"msaa_off": [func(): vp.msaa_3d = Viewport.MSAA_DISABLED, func(): game._apply_quality()],
		"fsr085": [func(): vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR; vp.scaling_3d_scale = 0.85, func(): game._apply_quality()],
		"splits2": [func(): game.sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, func(): game._apply_quality()],
		"soft_med": [func(): RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM),
			func(): RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)],
		"atlas4096": [func(): RenderingServer.directional_shadow_atlas_set_size(4096, true), func(): RenderingServer.directional_shadow_atlas_set_size(8192, true)],
		"ssao_q2": [func(): RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_MEDIUM, true, 0.5, 2, 50, 300),
			func(): RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_HIGH, true, 0.5, 2, 50, 300)],
		"ssao_off": [func(): game.env.ssao_enabled = false, func(): game._apply_quality()],
		"glow_off": [func(): game.env.glow_enabled = false, func(): game._apply_quality()],
		"dof_off": [func(): game.rig.attrs.dof_blur_far_enabled = false; game.rig.attrs.dof_blur_near_enabled = false, func(): game._apply_quality()],
		"clouds_off": [func(): game.clouds.set_enabled(false), func(): game.clouds.set_enabled(true)],
		# 12.11 (владелец: «минимум 120 кадров»): самые тяжёлые эффекты «Высокой»
		"sdfgi_off": [func(): game.env.sdfgi_enabled = false, func(): game._apply_quality()],
		"ssil_off": [func(): game.env.ssil_enabled = false, func(): game._apply_quality()],
		"shadow_off": [func(): game.sun.shadow_enabled = false, func(): game._apply_quality()],
		"fsr075": [func(): vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR; vp.scaling_3d_scale = 0.75, func(): game._apply_quality()],
	}
	# 12.11: из чего складывается время процессора — выключаем обработку кадра у узлов одного сценария (и их детей)
	var by_script := {}
	for n: Node in game.find_children("*", "", true, false):
		var sc: Script = n.get_script()
		if sc and n.is_processing() or (sc and n.is_physics_processing()):
			var nm := sc.resource_path.get_file().get_basename()
			if not by_script.has(nm):
				by_script[nm] = []
			by_script[nm].append(n)
	for nm: String in by_script:
		var list: Array = by_script[nm]
		tests["proc_" + nm] = [func(): _proc_set(list, Node.PROCESS_MODE_DISABLED), func(): _proc_set(list, Node.PROCESS_MODE_INHERIT)]
	var anims: Array = game.find_children("*", "AnimationMixer", true, false)
	tests["anims_manual"] = [func(): _anim_cb(anims, AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL),
		func(): _anim_cb(anims, AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE)]
	print("PROBE сценариев с обработкой кадра: %d, анимаций %d: %s" % [by_script.size(), anims.size(), ", ".join(by_script.keys())])
	# по частям обработки жителей (People._process): кошки, повозка, беседы, герой — заменяем пустышкой
	tests["ppl_nocats"] = [func(): game.people.set_meta("perf_skip", "cats"), func(): game.people.remove_meta("perf_skip")]
	var only: String = A.get("only", "")
	var rep := int(A.get("rep", "1"))
	var order := []
	for k in rep:
		order.append_array(tests.keys())
	for t: String in order:
		if only != "" and not (t in only.split("+")):
			continue
		if A.has("prefix") and not (t.begins_with(str(A["prefix"])) or t == "anims_manual"):
			continue
		(tests[t][0] as Callable).call()
		var r := await _measure("%s -%s" % [q, t])
		(tests[t][1] as Callable).call()
		var b2 := await _measure("%s base-after" % q)
		print("DELTA %-14s gpu %+6.2f ms  cpu %+6.2f  dc %+5d  tris %+.2fM" % [t, float(r["gpu"]) - float(b2["gpu"]), float(r["cpu"]) - float(b2["cpu"]),
			int(r["vis_d"]) - int(b2["vis_d"]), (float(r["vis_p"]) - float(b2["vis_p"])) / 1.0e6])


## 12.11: из чего сделан житель — сколько у него мешей со скелетом (каждый — отдельный пересчёт позы на видеокарте
## каждый кадр), поверхностей и точек
func _citizens() -> void:
	await _settle()
	var n := 0
	var tot := {"mi": 0, "skin": 0, "surf": 0, "verts": 0, "skel": 0}
	var names := {}
	for r in game.people.residents:
		var c = r["node"]
		if c == null:
			continue
		n += 1
		tot["skel"] += (c as Node).find_children("*", "Skeleton3D", true, false).size()
		for mi: MeshInstance3D in (c as Node).find_children("*", "MeshInstance3D", true, false):
			if not mi.visible:
				continue
			tot["mi"] += 1
			if mi.skin != null or mi.skeleton != NodePath(""):
				tot["skin"] += 1
			if mi.mesh:
				tot["surf"] += mi.mesh.get_surface_count()
				for s in mi.mesh.get_surface_count():
					if mi.mesh is ArrayMesh:
						tot["verts"] += (mi.mesh as ArrayMesh).surface_get_array_len(s)
			names[String(mi.name)] = int(names.get(String(mi.name), 0)) + 1
	var top := names.keys()
	top.sort_custom(func(a, b): return int(names[a]) > int(names[b]))
	print("CIT видимых жителей %d: мешей %d (со скелетом %d), скелетов %d, поверхностей %d, точек %d — на жителя %.1f мешей, %.0f точек" % [n,
		tot["mi"], tot["skin"], tot["skel"], tot["surf"], tot["verts"], float(tot["mi"]) / maxf(1, n), float(tot["verts"]) / maxf(1, n)])
	var t := []
	for k in top.slice(0, 25):
		t.append("%s×%d" % [k, names[k]])
	print("CIT части: ", ", ".join(t))


## 12.11: честное «было/стало» на занятом компьютере — по очереди без и с новыми правками скорости (Gfx.lod_on),
## rounds раз, итог — медианы
func _ab() -> void:
	await _settle()
	var view: Array = _views(VIEWS_OWNER if city_src != "" else VIEWS_NEW)[0]
	for q: String in str(A.get("q", "high,verylow")).split(","):
		_quality(q)
		_view(view)
		var res := {false: {"cpu": [], "proc": [], "gpu": [], "frame": []}, true: {"cpu": [], "proc": [], "gpu": [], "frame": []}}
		for r in int(A.get("rounds", "4")):
			for on: bool in ([false, true] if r % 2 == 0 else [true, false]):
				Gfx.lod_on = on
				var m := await _measure("ab %s %s r%d" % [q, "new" if on else "old", r])
				if on and r == 0:
					print("AB разряды жителей (крупные, средние, мелкие, за экраном): ", Gfx.tier_n)
				for k: String in res[on]:
					(res[on][k] as Array).append(float(m[k]))
		Gfx.lod_on = true
		for on: bool in [false, true]:
			var med := {}
			for k: String in res[on]:
				var a := PackedFloat32Array(res[on][k])
				med[k] = _pct(a, 0.5)
			print("AB %-8s %s: кадр %.2f мс (%.0f к/с), процессор %.2f (скрипты %.2f), видеокарта %.2f" % [q, "стало" if on else "было ", med["frame"],
				1000.0 / maxf(0.01, med["frame"]), med["cpu"], med["proc"], med["gpu"]])


## 12.11: облегчения «Высокой» для владельца — каждое по очереди с исходной (rounds раз, медианы), затем снимки каждого
## (время стоит, жителей нет) в out. Варианты: base, nosdfgi, nossil, atlas4k, splits2, softmed, msaa2, fsr2 (0,77 со
## сглаживанием FSR2), lite (всё лёгкое разом, кроме fsr2), lite_fsr2
##   … -- mode=gpuab q=high rounds=3 out=D:/CivCity/.work/perf120/gpuab [only=base+lite]
func _gpu_variant(name: String) -> void:
	game._apply_quality()
	var vp := get_viewport()
	var parts := name.split("+")
	for v: String in parts:
		match v:
			"nosdfgi":
				game.env.sdfgi_enabled = false
			"nossil":
				game.env.ssil_enabled = false
			"atlas4k":
				RenderingServer.directional_shadow_atlas_set_size(4096, true)
			"splits2":
				game.sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			"softmed":
				RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
			"msaa2":
				vp.msaa_3d = Viewport.MSAA_2X
			"fsr2":
				vp.msaa_3d = Viewport.MSAA_DISABLED
				vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
				vp.scaling_3d_scale = 0.77


func _gpu_reset() -> void:
	RenderingServer.directional_shadow_atlas_set_size(8192, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = 1.0
	game._apply_quality()


func _gpuab() -> void:
	await _settle()
	_quality(str(A.get("q", "high")))
	var view: Array = _views(VIEWS_OWNER if city_src != "" else VIEWS_NEW)[0]
	_view(view)
	var names: Array = Array(str(A.get("only", "base,nosdfgi,nossil,atlas4k,splits2,softmed,msaa2,fsr2,nosdfgi+nossil+atlas4k+softmed+msaa2,nosdfgi+nossil+atlas4k+softmed+fsr2")).replace("+", "&").split(","))
	for i in names.size():
		names[i] = str(names[i]).replace("&", "+")
	var res := {}
	for r in int(A.get("rounds", "3")):
		var order := names.duplicate()
		for k in r % order.size():
			order.push_back(order.pop_front())
		for nm: String in order:
			_gpu_reset()
			_gpu_variant(nm)
			await frames(30)
			var m := await _measure("gpuab %s r%d" % [nm, r])
			if not res.has(nm):
				res[nm] = {"gpu": [], "frame": [], "cpu": []}
			for k: String in ["gpu", "frame", "cpu"]:
				(res[nm][k] as Array).append(float(m[k]))
	for nm: String in names:
		var g := _pct(PackedFloat32Array(res[nm]["gpu"]), 0.5)
		var f := _pct(PackedFloat32Array(res[nm]["frame"]), 0.5)
		var c := _pct(PackedFloat32Array(res[nm]["cpu"]), 0.5)
		print("GPUAB %-48s видеокарта %5.2f мс | процессор %5.2f | кадр %5.2f (%.0f к/с)" % [nm, g, c, f, 1000.0 / maxf(0.01, f)])
	var out: String = A.get("out", "")
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
		_freeze()
		for v: Array in _views(VIEWS_OWNER if city_src != "" else VIEWS_NEW):
			_view(v)
			game._set_hour(9.0)
			for nm: String in names:
				_gpu_reset()
				_gpu_variant(nm)
				await frames(SHOT_WAIT)
				var img: Image = await _snap()
				img.save_png(out.path_join("%s_%s.png" % [v[0], nm.replace("+", "_")]))
		_unfreeze()
		print("GPUAB снимки: ", out)
	_gpu_reset()


static func _proc_set(list: Array, mode: int) -> void:
	for n: Node in list:
		if is_instance_valid(n):
			n.process_mode = mode


static func _anim_cb(list: Array, mode: int) -> void:
	for a in list:
		if is_instance_valid(a):
			(a as AnimationMixer).callback_mode_process = mode


## 12.11: время самого People._process (сценарий) против всего времени кадра на скриптах; затем — анимации жителей
## на ручном шаге (ни одна не считается) — сколько стоят они
func _pplprof() -> void:
	await _settle()
	_quality(str(A.get("q", "high")))
	_view(_views(VIEWS_OWNER if city_src != "" else VIEWS_NEW)[0])
	for k in 3:
		People.perf = true
		game.people.perf_us = 0
		var r := await _measure("pplprof r%d" % k)
		People.perf = false
		var n := int(A.get("n", "120"))
		print("PPL People._process в среднем %.2f мс за кадр (скрипты всего %.2f мс)" % [game.people.perf_us / 1000.0 / n, float(r["proc"])])
		var parts := []
		for sec: String in game.people.perf_sec:
			parts.append("%s %.2f" % [sec, int(game.people.perf_sec[sec]) / 1000.0 / n])
		game.people.perf_sec = {}
		var st := {}
		for rr in game.people.residents:
			if rr["node"] != null:
				st[rr["state"]] = int(st.get(rr["state"], 0)) + 1
		print("PPL части (мс за кадр): ", ", ".join(parts), " | видимые по делам: ", st)
		var anims: Array = game.people.find_children("*", "AnimationMixer", true, false)
		_anim_cb(anims, AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL)
		var r2 := await _measure("pplprof anims_off r%d" % k)
		_anim_cb(anims, AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE)
		print("PPL анимаций жителей %d: без них скрипты %.2f мс (разница %.2f), видеокарта %.2f → %.2f" % [anims.size(), float(r2["proc"]),
			float(r["proc"]) - float(r2["proc"]), float(r["gpu"]), float(r2["gpu"])])


## Для владельца (1.9, 1.10): снимки каждой графики на трёх видах (без жителей, время стоит) и замеры по кругу —
## графики чередуются, чтобы чужая нагрузка на видеокарту (вторая линия проверок) делилась поровну; итог — медианы
##   … -- mode=offer q=high,medium_full,medium_light out=ПАПКА tag=lossless rounds=3
func _offer() -> void:
	await _settle()
	var qs := Array(str(A.get("q", "high,medium_full,medium_light")).split(","))
	var views := _views(VIEWS_OWNER if city_src != "" else VIEWS_NEW)
	var tag: String = A.get("tag", "set")
	var out: String = A.get("out", "")
	if out != "" and not A.has("noshots"):
		_freeze()
		var shots := await _shots(qs, views, tag)
		DirAccess.make_dir_recursive_absolute(out)
		for k: String in shots:
			(shots[k] as Image).save_png(out.path_join("%s_%s.png" % [tag, k.replace("/", "_")]))
		_unfreeze()
		await frames(60)
	var res := {}
	var rounds := int(A.get("rounds", "3"))
	for r in rounds:
		var order := qs.duplicate()
		for i in r % order.size():
			order.push_back(order.pop_front())
		for q: String in order:
			_quality(q)
			for v: Array in views:
				_view(v)
				game._set_hour(9.0)
				var m := await _measure("%s %s %s r%d" % [tag, v[0], q, r])
				var key := "%s|%s" % [q, v[0]]
				if not res.has(key):
					res[key] = []
				res[key].append(m)
	var summary := {}
	for key: String in res:
		var g := PackedFloat32Array()
		var p10 := PackedFloat32Array()
		var cpu := PackedFloat32Array()
		var fr := PackedFloat32Array()
		var vr := 0
		var tx := 0
		for m: Dictionary in res[key]:
			g.append(m["gpu"])
			p10.append(m["p10"])
			cpu.append(m["cpu"])
			fr.append(m["frame"])
			vr = maxi(vr, int(m["vram"]))
			tx = maxi(tx, int(m["tex"]))
		summary[key] = {"gpu": _pct(g, 0.5), "p10": _pct(p10, 0.5), "cpu": _pct(cpu, 0.5), "frame": _pct(fr, 0.5), "vram": vr, "tex": tx}
		print("OFFER %s %-22s gpu %5.2f (p10 %5.2f) cpu %5.2f frame %5.2f | vram %d MB tex %d MB" % [tag, key, summary[key]["gpu"], summary[key]["p10"],
			summary[key]["cpu"], summary[key]["frame"], vr, tx])
	print("OFFER JSON %s %s" % [tag, JSON.stringify(summary)])
	Gfx.medium_light = Gfx.MEDIUM_LIGHT


## 12.11 (120 кадров): сколько вызовов отрисовки дали бы детали построек, склеенные кусками земли по материалу —
## разных материалов во всём городе и в куске (TILE м), сколько точек у всех деталей (память под склейку)
func _batch() -> void:
	await _settle()
	var tiles := []
	for t in str(A.get("tile", "16,32,48,64")).split(","):
		tiles.append(int(t))
	var mats := {}
	var mats_nt := {}
	var per_tile := {}
	var per_tile_nt := {}
	var verts := 0
	var idx := 0
	var calls := 0
	var inst := 0
	var t0 := Time.get_ticks_msec()
	var dist := {}
	var nt_groups := {}
	var with_col := {}
	for key: String in game.parts.groups:
		var g: Dictionary = game.parts.groups[key]
		var free := {}
		for f in g["free"]:
			free[f] = true
		for sub: Dictionary in g["subs"]:
			var mm: MultiMesh = sub["mm"]
			var mesh: Mesh = mm.mesh
			if mesh == null or mm.instance_count == 0:
				continue
			var live := []
			var buf := mm.buffer                       # одним чтением: по 12 чисел на экземпляр (базис по строкам и сдвиг)
			for i in mini(int(g["used"]), mm.instance_count):
				if free.has(i):
					continue
				var o := i * 12
				if absf(buf[o]) + absf(buf[o + 1]) + absf(buf[o + 2]) < 1e-6:
					continue
				live.append(Vector3(buf[o + 3], buf[o + 7], buf[o + 11]))
			if live.is_empty():
				continue
			inst += live.size()
			var vsub := 0
			for s2 in mesh.get_surface_count():
				if mesh is ArrayMesh:
					vsub += (mesh as ArrayMesh).surface_get_array_len(s2)
			for kk: int in [1, 2, 4, 8, 16, 32, 64]:
				if live.size() <= kk:
					dist[kk] = (dist.get(kk, [0, 0, 0]) as Array)
					dist[kk][0] += mesh.get_surface_count()
					dist[kk][1] += vsub * live.size()
					dist[kk][2] += live.size()
			# без оттенка: тот же меш (ресурс модели) и те же картинки — один MultiMesh с цветом экземпляра
			var nk := str(sub["mmi"].get_parent()) + "|" + key.get_slice("|", 0) + "|" + str(mesh.get_surface_count())
			for s3 in mesh.get_surface_count():
				var m3 := mesh.surface_get_material(s3)
				if m3 is StandardMaterial3D:
					var sm3 := m3 as StandardMaterial3D
					nk += "|%s|%d" % [str(sm3.albedo_texture.resource_path if sm3.albedo_texture else ""), sm3.transparency]
				else:
					nk += "|" + str(m3.get_instance_id() if m3 else 0)
			nt_groups[nk] = true
			for s4 in mesh.get_surface_count():
				if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_format(s4) & Mesh.ARRAY_FORMAT_COLOR:
					with_col[key.get_slice("|", 0)] = true
			for s in mesh.get_surface_count():
				calls += 1
				var m := mesh.surface_get_material(s)
				var mk := str(m.get_instance_id()) if m else "none"
				var nt := mk
				if m is StandardMaterial3D:
					var sm := m as StandardMaterial3D
					nt = "%s|%d|%s" % [str(sm.albedo_texture.resource_path if sm.albedo_texture else ""), sm.transparency, str(sm.normal_enabled)]
				mats[mk] = true
				mats_nt[nt] = true
				var vc := 0
				var ic := 0
				if mesh is ArrayMesh:
					vc = (mesh as ArrayMesh).surface_get_array_len(s)
					ic = (mesh as ArrayMesh).surface_get_array_index_len(s)
				verts += vc * live.size()
				idx += ic * live.size()
				for o: Vector3 in live:
					for ts: int in tiles:
						var tk := Vector3i(floori(o.x / ts), floori(o.z / ts), ts)
						if not per_tile.has(tk):
							per_tile[tk] = {}
							per_tile_nt[tk] = {}
						per_tile[tk][mk] = true
						per_tile_nt[tk][nt] = true
	print("BATCH групп %d, вызовов (все поверхности) %d, экземпляров %d, точек %.2fM, индексов %.2fM (≈%d МБ склейкой), счёт %d мс" % [game.parts.groups.size(),
		calls, inst, verts / 1.0e6, idx / 1.0e6, int((verts * 36 + idx * 4) / 1048576.0), Time.get_ticks_msec() - t0])
	for kk: int in [1, 2, 4, 8, 16, 32, 64]:
		var e: Array = dist.get(kk, [0, 0, 0])
		print("BATCH групп-поверхностей с ≤%d экз.: вызовов %d, экземпляров %d, точек склейкой %.2fM" % [kk, e[0], e[2], e[1] / 1.0e6])
	print("BATCH MultiMesh-ов без оттенка (цвет — у экземпляра): %d" % nt_groups.size())
	print("BATCH моделей с цветом в вершинах: %d: %s" % [with_col.size(), ", ".join(with_col.keys().slice(0, 40))])
	for ts: int in tiles:
		var n := 0
		var sum_t := 0
		var sum_nt := 0
		for tk: Vector3i in per_tile:
			if tk.z != ts:
				continue
			n += 1
			sum_t += (per_tile[tk] as Dictionary).size()
			sum_nt += (per_tile_nt[tk] as Dictionary).size()
		print("BATCH материалов %d (без оттенка %d); кусков %d по %d м: вызовов склейкой %d (без оттенка %d), в среднем на кусок %.1f" % [mats.size(), mats_nt.size(),
			n, ts, sum_t, sum_nt, float(sum_t) / maxf(1, n)])


## 1.6: сколько групп деталей (MultiMesh) и сколько их было бы, если бы оттенок (remap «tints») шёл в данные экземпляра
func _groups() -> void:
	await _settle()
	var n_grp := 0
	var n_inst := 0
	var merged := {}
	var small := 0
	var by_mesh := {}
	for key: String in game.parts.groups:
		var g: Dictionary = game.parts.groups[key]
		var live: int = int(g["used"]) - (g["free"] as Array).size()
		if live <= 0:
			continue
		n_grp += 1
		n_inst += live
		if live <= 2:
			small += 1
		var parts := key.split("|")
		var name: String = parts[0]
		by_mesh[name] = int(by_mesh.get(name, 0)) + 1
		# ключ без цветов оттенка: tints → только какие картинки подкрашены
		var mk := key
		var rx := RegEx.create_from_string("\"tints\": \\{([^}]*)\\}")
		var m := rx.search(key)
		if m:
			var inner := m.get_string(1)
			var names := []
			for e in inner.split("), "):
				names.append(e.get_slice(":", 0))
			mk = key.replace(m.get_string(0), "tints:" + ",".join(names))
		rx = RegEx.create_from_string("\"tint\": \\([^)]*\\)")
		mk = rx.sub(mk, "tint:*", true)
		merged[mk] = int(merged.get(mk, 0)) + live
	print("GROUPS живых групп %d (экземпляров %d, групп с ≤2: %d), разных моделей %d; без цветов оттенка групп было бы %d" % [n_grp, n_inst, small, by_mesh.size(), merged.size()])


## Какие картинки материалов сколько видеопамяти занимают (по заголовкам .ctex: размер, формат, мипмапы) и итог
## по папкам; плюс общий счёт Godot (Performance: текстуры и вся видеопамять)
func _vram() -> void:
	await _settle()
	for q: String in str(A.get("q", "high")).split(","):
		_quality(q)
		await frames(30)
		var seen := {}
		var mats := []
		mats.append_array(Synty._mats.values())
		mats.append_array(Citizen._plain_mats.values())
		mats.append_array(Citizen._mats.values())
		for m in mats:
			for pn: String in ["albedo_texture", "normal_texture", "roughness_texture", "orm_texture"]:
				var t = m.get(pn) if m is BaseMaterial3D else null
				if t is Texture2D:
					seen[t] = true
			if m is ShaderMaterial and (m as ShaderMaterial).get_shader_parameter("albedo_tex") is Texture2D:
				seen[(m as ShaderMaterial).get_shader_parameter("albedo_tex")] = true
		var rows := []
		var total := 0
		var by := {}
		for t: Texture2D in seen:
			var info := _tex_info(t)
			total += int(info["bytes"])
			var dir: String = str(info["path"]).get_base_dir().trim_prefix("res://")
			by[dir] = int(by.get(dir, 0)) + int(info["bytes"])
			rows.append(info)
		rows.sort_custom(func(a, b): return int(a["bytes"]) > int(b["bytes"]))
		print("VRAM %s: картинок материалов %d, по заголовкам %d МБ | Godot: текстуры %d МБ, вся видеопамять %d МБ" % [q, rows.size(), total / 1048576,
			int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0), int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)])
		for i in mini(int(A.get("top", "40")), rows.size()):
			var r: Dictionary = rows[i]
			print("VRAM %s top %2d %6.1f МБ %4dx%-4d %-8s mip %d %s" % [q, i, int(r["bytes"]) / 1048576.0, int(r["w"]), int(r["h"]), r["fmt"], int(r["mips"]), r["path"]])
		var dirs := by.keys()
		dirs.sort_custom(func(a, b): return int(by[a]) > int(by[b]))
		for d in dirs.slice(0, 15):
			print("VRAM %s dir %7.1f МБ %s" % [q, int(by[d]) / 1048576.0, d])


## Сколько картинка занимает в видеопамяти: копия «Очень низкой» (ImageTexture) — по самой картинке; файл — по
## заголовку .ctex (Gfx._ctex): RGB8 на видеокарте — как RGBA8; мипмапы — ещё треть
func _tex_info(t: Texture2D) -> Dictionary:
	var w := t.get_width()
	var h := t.get_height()
	var fmt := -1
	var mips := 0
	var path := t.resource_path if t.resource_path != "" else str(t.get_meta("orig", "")) + " (копия)"
	if t is ImageTexture:
		fmt = (t as ImageTexture).get_format()
		mips = 1 if (t as ImageTexture).has_mipmaps() else 0
	elif t.resource_path != "":
		var f := FileAccess.open(Gfx._ctex(t.resource_path), FileAccess.READ)
		if f and f.get_length() > 52:
			f.seek(36)
			var df := f.get_32()
			f.get_32()
			mips = f.get_32()
			fmt = f.get_32()
			if df == 3:                        # Basis (1.9): в заголовке — формат исходной картинки, на видеокарте — BC7 (рельеф — BC5)
				fmt = Image.FORMAT_BPTC_RGBA
	var bpp: float = {Image.FORMAT_L8: 1.0, Image.FORMAT_LA8: 2.0, Image.FORMAT_RGB8: 4.0, Image.FORMAT_RGBA8: 4.0, Image.FORMAT_DXT1: 0.5,
		Image.FORMAT_DXT3: 1.0, Image.FORMAT_DXT5: 1.0, Image.FORMAT_RGTC_R: 0.5, Image.FORMAT_RGTC_RG: 1.0, Image.FORMAT_BPTC_RGBA: 1.0}.get(fmt, 4.0)
	var names := {Image.FORMAT_L8: "L8", Image.FORMAT_LA8: "LA8", Image.FORMAT_RGB8: "RGB8", Image.FORMAT_RGBA8: "RGBA8", Image.FORMAT_DXT1: "DXT1",
		Image.FORMAT_DXT5: "DXT5", Image.FORMAT_RGTC_RG: "RGTC_RG", Image.FORMAT_BPTC_RGBA: "BC7"}
	var bytes: float = w * h * bpp * (4.0 / 3.0 if mips > 0 else 1.0)
	return {"path": path, "w": w, "h": h, "fmt": names.get(fmt, str(fmt)), "mips": mips, "bytes": int(bytes)}


## Природа — куски по 48 м (ключ «…|x,z»); постройки — куски по участку («…|bx,z», Parts._bgroup) или вся карта
static func _is_nature(k: String) -> bool:
	return k.count("|") >= 2 and not k.get_slice("|", 2).begins_with("b")


func _grp_vis(pred: Callable, v: bool) -> void:
	for key in game.parts.groups:
		if pred.call(str(key)):
			for sub in game.parts.groups[key]["subs"]:
				(sub["mmi"] as Node3D).visible = v


# ---------- снимки ----------

## Всё, что двигается само (жители, звери, дым, птицы, утки, вода), и интерфейс — прочь; время стоит
var _hidden: Array = []


func _freeze() -> void:
	game.hud.set_speed(0.0)
	game.hud.visible = false
	game.rig.cine = true                      # камера стоит, подсветки инструмента и участка под мышью нет
	_hidden = [game.people, game.actors_root]
	if game.has_node("Tourism"):
		_hidden.append(game.get_node("Tourism"))      # гуляющие гости гостиниц (новая игра)
	for s in game.swimmers:
		_hidden.append(s["n"])
	for n in game.find_children("*", "", true, false):
		# Decal — пятно поисков историй (мерцает); вода — волны по TIME шейдера (Engine.time_scale его не останавливает)
		if n is GPUParticles3D or n is CPUParticles3D or n is Birds or n is RoofBirds or n is Decal:
			_hidden.append(n)
		elif n is MeshInstance3D and (n as MeshInstance3D).mesh is PlaneMesh and (n as MeshInstance3D).material_override is ShaderMaterial:
			_hidden.append(n)
	for n: Node3D in _hidden:
		n.visible = false
	Engine.time_scale = 0.0


func _unfreeze() -> void:
	Engine.time_scale = 1.0
	for n in _hidden:
		if is_instance_valid(n):
			(n as Node3D).visible = true
	_hidden = []
	game.hud.visible = true
	game.rig.cine = false
	game.hud.set_speed(1.0)


func _snap() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


## Снимки вида по графикам: {"q/вид": Image}
func _shots(qs: Array, views: Array, tag: String) -> Dictionary:
	var out := {}
	for q: String in qs:
		_quality(q)
		for v: Array in views:
			_view(v)
			game._set_hour(9.0)
			await frames(SHOT_WAIT)
			var img: Image = await _snap()
			if A.has("stab"):                          # проверка: кадр через 120 кадров — тот же?
				for k in int(A["stab"]):
					await frames(120)
					var img2: Image = await _snap()
					print("PERF stab %s/%s +%d: %s" % [q, v[0], 120 * (k + 1), _same(img, img2)["info"]])
					if A.has("stabsave"):
						DirAccess.make_dir_recursive_absolute(str(A["stabsave"]))
						img.save_png(str(A["stabsave"]).path_join("%s_%s_%d.png" % [q, v[0], k]))
						img2.save_png(str(A["stabsave"]).path_join("%s_%s_%d.png" % [q, v[0], k + 1]))
					img = img2
			out["%s/%s" % [q, v[0]]] = img
			print("PERF shot %s %s/%s" % [tag, q, v[0]])
	return out


## Два кадра «те же», если разница не больше шума отрисовки. Шум откалиброван: два прогона одной сборки (25.10,
## город владельца и новый городок, вода спрятана) — средняя разница (по самому разному каналу точки) до 0,06,
## точек с разницей > 24 — до 52 (Низкая — один в один); настоящие перемены — от 0,37 (Высокая и Средняя на
## дальнем виде) до 9 (Средняя и Низкая)
const DIFF_MEAN := 0.15
const DIFF_C24 := 500


static func _same(a: Image, b: Image) -> Dictionary:
	if a == null or b == null or a.get_size() != b.get_size():
		return {"same": false, "mean": 255.0, "c24": 1 << 30, "info": "размер"}
	a = a.duplicate()
	b = b.duplicate()
	a.convert(Image.FORMAT_RGB8)
	b.convert(Image.FORMAT_RGB8)
	var da := a.get_data()
	var db := b.get_data()
	if da == db:
		return {"same": true, "mean": 0.0, "c24": 0, "info": "один в один"}
	var sum := 0
	var c24 := 0
	var mx := 0
	var n := da.size()
	var i := 0
	while i < n:
		var d := maxi(absi(da[i] - db[i]), maxi(absi(da[i + 1] - db[i + 1]), absi(da[i + 2] - db[i + 2])))
		if d > 0:
			sum += d
			if d > 24:
				c24 += 1
			if d > mx:
				mx = d
		i += 3
	var mean := float(sum) / float(n / 3)
	var ok := mean <= DIFF_MEAN and c24 <= DIFF_C24
	return {"same": ok, "mean": mean, "c24": c24, "info": "%s: средняя разница %.4f, точек > 24: %d, max %d" % ["в пределах шума" if ok else "ДРУГОЙ", mean, c24, mx]}


func _save_set(shots: Dictionary, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for k: String in shots:
		(shots[k] as Image).save_png(dir.path_join(k.replace("/", "_") + ".png"))


## Сверка с эталоном: снимки должны совпасть в пределах шума отрисовки (_same)
func _compare_golden(shots: Dictionary, ref: String) -> void:
	for k: String in shots:
		var p := ref.path_join(k.replace("/", "_") + ".png")
		if not FileAccess.file_exists(p):
			print("PERF golden %s: нет эталона %s" % [k, p])
			continue
		var r := _same(shots[k], Image.load_from_file(p))
		print("PERF golden %-14s %s" % [k, r["info"]])
		if not r["same"]:
			fail("снимок %s не совпал с эталоном (%s) — графика «%s» изменилась" % [k, r["info"], k.split("/")[0]])


func _shots_mode() -> void:
	await _settle()
	_freeze()
	var views := _views(VIEWS_OWNER if city_src != "" else VIEWS_NEW)
	var shots := await _shots(Array(str(A.get("q", "high,medium")).split(",")), views, "set")
	var out: String = A.get("out", "")
	if A.has("rec"):
		out = A.get("ref", GOLDEN)
	if out != "":
		_save_set(shots, out)
		print("PERF saved ", shots.size(), " shots to ", out)
	if A.has("ref") and not A.has("rec"):
		_compare_golden(shots, str(A["ref"]))
	_unfreeze()


## Для regress.sh: (1) Высокая и Средняя совпадают с эталоном; (2) после Низкой и Очень низкой снова Высокая —
## тот же кадр (ничего не «прилипло»); (3) пороги скорости Низкой и Очень низкой; (4) вызовы и тени Высокой не выросли
func _regress() -> void:
	await _settle()
	var views := _views(VIEWS_OWNER if city_src != "" else VIEWS_NEW)
	_freeze()
	var first := await _shots(["high", "medium"], views, "first")
	if city_src != "" and DirAccess.dir_exists_absolute(str(A.get("ref", GOLDEN))):
		_compare_golden(first, str(A.get("ref", GOLDEN)))
	else:
		print("PERF golden: эталона нет — сверяем только повтор")
	if A.has("out"):
		_save_set(first, str(A["out"]))
	# через Низкую и Очень низкую — и обратно
	for q: String in ["low", "verylow"]:
		_quality(q)
		await frames(30)
	var again := await _shots(["high", "medium"], views, "again")
	for k: String in first:
		var r := _same(first[k], again[k])
		print("PERF roundtrip %-14s %s" % [k, r["info"]])
		if not r["same"]:
			fail("после Низкой снова «%s»: кадр %s другой (%s)" % [k.split("/")[0], k, r["info"]])
	_unfreeze()
	# скорость: вид по умолчанию
	var v0: Array = views[0]
	_view(v0)
	var meas := {}
	for q: String in ["high", "low", "verylow"]:
		_quality(q)
		meas[q] = await _measure("%s %s" % [v0[0], q])
	if city_src != "":
		var lo: Dictionary = meas["low"]
		var vl: Dictionary = meas["verylow"]
		var hi: Dictionary = meas["high"]
		if float(lo["p10"]) > GATE_LOW:
			fail("Низкая: видеокарта %.2f мс (p10) > %.1f" % [lo["p10"], GATE_LOW])
		if float(vl["p10"]) > GATE_VLOW:
			fail("Очень низкая: видеокарта %.2f мс (p10) > %.1f" % [vl["p10"], GATE_VLOW])
		for k: String in REF_HIGH:
			if float(hi[k]) > float(REF_HIGH[k]) * 1.1:
				fail("Высокая: %s = %d, было %d (+10%% предел)" % [k, int(hi[k]), int(REF_HIGH[k])])
		print("PERF GATES low p10 %.2f/%.1f, verylow p10 %.2f/%.1f, high dc %d/%d shadow dc %d/%d shadow tris %.2fM/%.2fM" % [
			lo["p10"], GATE_LOW, vl["p10"], GATE_VLOW, hi["vis_d"], REF_HIGH["vis_d"], hi["sh_d"], REF_HIGH["sh_d"], hi["sh_p"] / 1.0e6, REF_HIGH["sh_p"] / 1.0e6])
