extends Node
## Этап 1 (1.12): замеры скорости и проверка «Средняя и Высокая — ни пикселя не изменилось».
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
## (… -- mode=shots rec=1 на сборке этапа 4): прежний «golden» остаётся у линии, где этапа 4 ещё нет
const GOLDEN := "D:/CivCity/.work/perf_ref/golden_s4"
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
	game.settings["quality"] = q
	game._apply_quality()
	Gfx.swap_all()                            # картинки «Очень низкой» — сразу (в игре — по одной за кадр)
	Engine.max_fps = 0


func _run(mode: String) -> void:
	while not game.ready_done:
		await frames(5)
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
	}
	var only: String = A.get("only", "")
	for t: String in tests:
		if only != "" and not (t in only.split("+")):
			continue
		(tests[t][0] as Callable).call()
		var r := await _measure("%s -%s" % [q, t])
		(tests[t][1] as Callable).call()
		var b2 := await _measure("%s base-after" % q)
		print("DELTA %-14s gpu %+6.2f ms  cpu %+6.2f  dc %+5d  tris %+.2fM" % [t, float(r["gpu"]) - float(b2["gpu"]), float(r["cpu"]) - float(b2["cpu"]),
			int(r["vis_d"]) - int(b2["vis_d"]), (float(r["vis_p"]) - float(b2["vis_p"])) / 1.0e6])


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
	for s in game.swimmers:
		_hidden.append(s["n"])
	for n in game.find_children("*", "", true, false):
		# Decal — пятно поисков историй (мерцает); вода — волны по TIME шейдера (Engine.time_scale его не останавливает)
		if n is GPUParticles3D or n is CPUParticles3D or n is Birds or n is Decal:
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
