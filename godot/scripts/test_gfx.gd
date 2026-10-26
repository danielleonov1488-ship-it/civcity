extends Node
## Этап 1 (1.1, 1.2, 1.3): графика по видеокарте, уровни, счётчик кадров, F3, сторож кадров.
##   bash .work/py/gpu_run.sh res://test_gfx.tscn   — в конце «GFX DONE fails=0»; снимки — .work/gd/b/gfx_*.png
## Таблица видеокарт (в т. ч. ноутбучные на ступень ниже и встроенная); у тех, кто уже играет, уровень не меняется;
## ручной выбор (quality_user) переживает смену видеокарты; настройки: 4 уровня, «Показывать FPS», видеокарта;
## «Очень низкая» и обратно «Высокая» — всё возвращается; сторож предлагает «Низкую» один раз кнопкой у советника;
## проверка в городе после выбора по видеокарте опускает на ступень и объясняет один раз (и в следующий запуск, если
## совет не увидели); файл только от лаунчера — ещё новая установка, город без настроек — уже играет; уровень из
## лаунчера — выбор игрока; копии картинок «Очень низкой» — из файла картинки и с диска, без чтений с видеокарты,
## меняются по одной за кадр; у вопроса сторожа — «Не надо» вместо «Понятно».
## Включено 26.10 (решение владельца): облегчённая «Средняя» (Gfx.MEDIUM_LIGHT, 1.10) и картинки Synty, сжатые Basis
## (deploy/tex_vram.py basis, 1.9) — копия «Очень низкой» из такой картинки — её мипмапы со второго, байт в байт то, что
## на видеокарте, без чтений с неё; так же для сжатой BC7 (tex_vram.py bc7) и прежних несжатых (tex_vram.py off).

const SHOTS := "D:/CivCity/.work/gd/b/"

var game
var fails := 0


func check(ok: bool, what: String, extra = null) -> bool:
	print(("GFX PASS " if ok else "GFX FAIL ") + what + ("" if ok or extra == null else "  " + str(extra)))
	if not ok:
		fails += 1
	return ok


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	await frames(6)
	DirAccess.make_dir_recursive_absolute(SHOTS)
	get_viewport().get_texture().get_image().save_png(SHOTS + name)
	print("SHOT ", SHOTS + name)


func _ready() -> void:
	_table()
	_decide()
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


## Таблица: название видеокарты → уровень
func _table() -> void:
	var D := RenderingDevice.DEVICE_TYPE_DISCRETE_GPU
	var I := RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU
	var cases := [
		["NVIDIA GeForce RTX 3050 Laptop GPU", D, "low"], ["NVIDIA GeForce RTX 3060", D, "medium"],
		["NVIDIA GeForce RTX 3070 Laptop GPU", D, "medium"], ["NVIDIA GeForce RTX 4080 Laptop GPU", D, "high"],
		["Intel(R) Iris(R) Xe Graphics", I, "verylow"], ["Intel(R) UHD Graphics 620", 0, "verylow"],
		["AMD Radeon(TM) Graphics", I, "verylow"], ["NVIDIA GeForce RTX 3060 Laptop GPU", D, "low"],
		["NVIDIA GeForce GTX 1650", D, "low"], ["NVIDIA GeForce GTX 1060 6GB", D, "low"], ["NVIDIA GeForce MX450", D, "low"],
		["NVIDIA GeForce RTX 2050", D, "low"], ["NVIDIA GeForce RTX 4060 Ti", D, "medium"], ["NVIDIA GeForce RTX 2070 SUPER", D, "high"],
		["NVIDIA GeForce RTX 4090", D, "high"], ["AMD Radeon RX 6500 XT", D, "low"], ["AMD Radeon RX 6600", D, "medium"],
		["AMD Radeon RX 7700 XT", D, "high"], ["AMD Radeon RX 6700M", D, "medium"], ["AMD Radeon RX 580 Series", D, "low"],
		["Intel(R) Arc(TM) A380 Graphics", D, "low"], ["Intel(R) Arc(TM) A770 Graphics", D, "medium"],
		["Microsoft Basic Render Driver", 0, "verylow"], ["Some Unknown GPU 9000", D, "medium"],
		["NVIDIA GeForce 940MX", D, "low"], ["NVIDIA GeForce 930MX", D, "low"], ["NVIDIA GeForce 920M", D, "low"],
		["NVIDIA GeForce GT 1030", D, "low"], ["Quadro RTX 4000", D, "medium"], ["NVIDIA RTX 4000 Ada Generation", D, "medium"],
		["NVIDIA RTX A2000", D, "medium"]]
	var bad := []
	for c: Array in cases:
		var got := Gfx.tier_for(c[0], c[1])
		if got != c[2]:
			bad.append("%s → %s (ждали %s)" % [c[0], got, c[2]])
	check(bad.is_empty(), "таблица видеокарт: %d названий, ноутбучные на ступень ниже, встроенная — «Очень низкая»" % cases.size(), bad)


## Кто получает выбор по видеокарте
func _decide() -> void:
	var D := RenderingDevice.DEVICE_TYPE_DISCRETE_GPU
	var st := {"quality": "high"}
	var w := Gfx.decide(st, false, true, "NVIDIA GeForce RTX 3050 Laptop GPU", D)
	check(w and st["quality"] == "low" and st["quality_auto"] == "low" and st["quality_checked"] == false,
		"новая установка (настроек нет): RTX 3050 Laptop — «Низкая», одна проверка в городе впереди", st)
	st = {"quality": "high"}
	w = Gfx.decide(st, true, true, "NVIDIA GeForce RTX 3050 Laptop GPU", D)
	check(w and st["quality"] == "high" and st["quality_auto"] == "kept", "уже играет (quality: high, без quality_auto) — остаётся «Высокая», отмечено kept", st)
	w = Gfx.decide(st, true, true, "Intel(R) UHD Graphics", RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU)
	check(not w and st["quality"] == "high", "kept: другая видеокарта — всё равно ничего не меняем", st)
	st = {"quality": "medium", "quality_auto": "medium", "adapter": "NVIDIA GeForce RTX 3060", "quality_user": true}
	w = Gfx.decide(st, true, true, "NVIDIA GeForce RTX 3050 Laptop GPU", D)
	check(not w and st["quality"] == "medium", "ручной выбор переживает смену видеокарты", st)
	st = {"quality": "medium", "quality_auto": "medium", "adapter": "NVIDIA GeForce RTX 3060"}
	w = Gfx.decide(st, true, true, "NVIDIA GeForce RTX 3050 Laptop GPU", D)
	check(w and st["quality"] == "low" and st["adapter"] == "NVIDIA GeForce RTX 3050 Laptop GPU",
		"выбрано по видеокарте, видеокарта сменилась — выбрано заново", st)
	st = {"quality": "high"}
	w = Gfx.decide(st, false, false, "NVIDIA GeForce RTX 3050 Laptop GPU", D)
	check(not w and st["quality"] == "high" and not st.has("quality_auto"), "автопроверки (без --autoq) — без выбора, как раньше", st)
	# уровень поменяли в лаунчере (quality ≠ quality_auto) — это выбор игрока: ни проверка, ни смена видеокарты не трогают
	st = {"quality": "low", "quality_auto": "verylow", "adapter": "Intel(R) UHD Graphics", "quality_checked": false}
	w = Gfx.decide(st, true, true, "Intel(R) UHD Graphics", RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU)
	check(w and st["quality"] == "low" and bool(st.get("quality_user", false)), "уровень сменили в лаунчере — выбор игрока, остаётся «Низкая»", st)
	# кто уже играет: файл, который записал только лаунчер ({"fullscreen": true}), — ещё не игра; город есть — играет
	var I := RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU
	st = {"quality": "high", "fullscreen": true}
	var had := Gfx.installed(st, {"fullscreen": true}, false)
	w = Gfx.decide(st, had, true, "Intel(R) Iris(R) Xe Graphics", I)
	check(not had and w and st["quality"] == "verylow" and not st.has("quality_user"),
		"лаунчер записал только «во весь экран», города нет — новая установка: уровень по видеокарте", st)
	st = {"quality": "high"}
	had = Gfx.installed(st, null, true)
	w = Gfx.decide(st, had, true, "NVIDIA GeForce RTX 3060", D)
	check(had and st["quality"] == "high" and st["quality_auto"] == "kept", "настроек нет, а город есть — уже играет: «Высокая», kept", st)
	st = {"quality": "low"}
	had = Gfx.installed(st, {"quality": "low"}, false)
	w = Gfx.decide(st, had, true, "NVIDIA GeForce RTX 4090", D)
	check(not had and not w and st["quality"] == "low" and bool(st.get("quality_user", false)),
		"качество выбрали в лаунчере до первой игры — выбор игрока, по видеокарте не меняем", st)
	st = {"quality": "high", "ui_scale": 1.0}
	check(Gfx.installed(st, st.duplicate(), false) and not st.has("quality_user"), "файл, записанный игрой (с ui_scale), — уже играет")


## 1.10: «Средняя» облегчённая (Gfx.MEDIUM_LIGHT включён 26.10); переключатель возвращает прежнюю; «Высокую» не трогает
func _medium_light() -> void:
	var vp := get_viewport()
	check(Gfx.MEDIUM_LIGHT and Gfx.medium_light, "облегчённая «Средняя» включена для всех (решение владельца 26.10)")
	game.settings["quality"] = "medium"
	game._apply_quality()
	check(is_equal_approx(game.sun.light_angular_distance, 0.0) and vp.msaa_3d == Viewport.MSAA_2X and game.env.ssao_enabled and game.sun.shadow_enabled
		and not game.env.sdfgi_enabled and game.sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		and is_equal_approx(vp.scaling_3d_scale, 1.0) and is_equal_approx(game.sun.directional_shadow_max_distance, 190.0),
		"«Средняя»: без PCSS и MSAA 2x, остальное как у прежней «Средней» (4 полосы теней до 190 м, SSAO, без SDFGI, полный размер)",
		[game.sun.light_angular_distance, vp.msaa_3d, game.env.ssao_enabled, game.env.sdfgi_enabled])
	Gfx.medium_light = false
	game._apply_quality()
	var was := [game.sun.light_angular_distance, vp.msaa_3d, game.env.ssao_enabled, game.env.sdfgi_enabled]
	check(is_equal_approx(was[0], 2.2) and was[1] == Viewport.MSAA_4X and was[2] and not was[3],
		"переключатель выключили — «Средняя» прежняя: мягкие тени PCSS, MSAA 4x, SSAO, без SDFGI", was)
	Gfx.medium_light = true
	game.settings["quality"] = "high"
	game._apply_quality()
	check(is_equal_approx(game.sun.light_angular_distance, 2.2) and vp.msaa_3d == Viewport.MSAA_4X and game.env.sdfgi_enabled,
		"облегчённая «Средняя» «Высокую» не трогает (PCSS, MSAA 4x, SDFGI)")
	game.settings["quality"] = "medium"
	game._apply_quality()
	check(is_equal_approx(game.sun.light_angular_distance, 0.0) and vp.msaa_3d == Viewport.MSAA_2X, "после «Высокой» — снова облегчённая «Средняя»")


## 1.9: картинка, сжатая для видеокарты (BC7 с мипмапами, как после deploy/tex_vram.py bc7), — копия вдвое меньше для
## «Очень низкой» — её мипмап 1 из файла, байт в байт, без чтения с видеокарты; Basis и сжатая без мипмапов — оригинал
func _vram_copy() -> void:
	var img := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	for y in 512:
		for x in 512:
			img.set_pixel(x, y, Color(float(x % 64) / 64.0, float(y % 32) / 32.0, 0.5 if (x / 128 + y / 128) % 2 == 0 else 0.2, 1.0))
	img.generate_mipmaps()
	var err := img.compress(Image.COMPRESS_BPTC)
	var dir := "user://test_gfx_ctex"
	DirAccess.make_dir_recursive_absolute(dir)
	var p0 := dir.path_join("bc7.ctex")
	_write_ctex(p0, img, 0)
	var rb0 := Gfx.readbacks
	var c := Gfx._from_ctex(p0)
	var off := img.get_mipmap_offset(1)
	check(err == OK and img.get_format() == Image.FORMAT_BPTC_RGBA and c != null and c.get_width() == 256 and c.get_format() == Image.FORMAT_BPTC_RGBA
		and c.has_mipmaps() and c.get_data() == img.get_data().slice(off) and Gfx.readbacks == rb0 and Gfx._ctex_small_ok(p0),
		"сжатая для видеокарты (BC7 с мипмапами): копия «Очень низкой» — её мипмап 1 байт в байт, без видеокарты",
		[err, img.get_format(), c.get_width() if c else -1])
	var nm := img.duplicate() as Image
	nm.clear_mipmaps()
	var p1 := dir.path_join("bc7_nomip.ctex")
	_write_ctex(p1, nm, 0)
	var p3 := dir.path_join("basis.ctex")
	_write_ctex(p3, img, 3)
	check(Gfx._from_ctex(p1) == null and not Gfx._ctex_small_ok(p1) and not Gfx._ctex_small_ok(p3) and Gfx._from_ctex(p3) == null,
		"сжатая без мипмапов и пустой Basis — копию не делаем (остаётся оригинал, без чтения с видеокарты)")
	# Basis из настоящей картинки игры (палитра 4096²): метка «рельеф» (RG) и обрезанный файл — оригинал, без ошибок
	var bm := _big_mat()
	var src := Gfx._ctex(bm.albedo_texture.resource_path) if bm else ""
	var raw := FileAccess.get_file_as_bytes(src) if src != "" else PackedByteArray()
	if raw.size() > 60 and raw.decode_u32(36) == 3:
		var p4 := dir.path_join("basis_ok.ctex")
		_put(p4, raw)
		var rg := raw.duplicate()
		rg.encode_u32(56, 0x80000000)
		var p5 := dir.path_join("basis_rg.ctex")
		_put(p5, rg)
		var p6 := dir.path_join("basis_cut.ctex")
		_put(p6, raw.slice(0, raw.size() / 2))
		var cut := raw.duplicate()                 # длина данных та же, а оглавление уровней указывает за край
		cut.encode_u64(56 + 4 + 80, raw.size())
		var p7 := dir.path_join("basis_bad_index.ctex")
		_put(p7, cut)
		var h4 := Gfx._from_ctex(p4)
		check(Gfx._ctex_small_ok(p4) and h4 != null and h4.get_width() == 2048 and h4.has_mipmaps() and h4.is_compressed(),
			"Basis (настоящий файл): копия 2048², сжатая, с мипмапами", h4)
		check(not Gfx._ctex_small_ok(p5) and not Gfx._ctex_small_ok(p6) and Gfx._from_ctex(p6) == null and Gfx._from_ctex(p7) == null and Gfx.readbacks == rb0,
			"Basis: карта рельефа (RG), обрезанный файл и испорченное оглавление — копии нет (оригинал), без чтения с видеокарты")
	else:
		print("GFX note: картинки Synty не в Basis (deploy/tex_vram.py status) — проверки файла Basis пропущены")
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))


func _put(path: String, b: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(b)
	f.close()


## Файл картинки в виде, как его пишет импорт Godot (GST2): df 0 — данные картинки как есть, 3 — Basis (здесь — пустышка)
func _write_ctex(path: String, img: Image, df: int) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer("GST2".to_ascii_buffer())
	f.store_32(1)
	f.store_32(img.get_width())
	f.store_32(img.get_height())
	f.store_32(0)
	f.store_32(0)
	f.store_32(0)
	f.store_32(0)
	f.store_32(0)
	f.store_32(df)
	f.store_16(img.get_width())
	f.store_16(img.get_height())
	f.store_32(img.get_mipmap_count())
	f.store_32(img.get_format())
	if df == 3:
		f.store_32(4)
		f.store_32(0)
	else:
		f.store_buffer(img.get_data())
	f.close()


## Материал с картинкой 4096² (палитра Synty)
func _big_mat() -> BaseMaterial3D:
	for m in Synty._mats.values():
		if m is BaseMaterial3D and (m as BaseMaterial3D).albedo_texture is CompressedTexture2D and (m as BaseMaterial3D).albedo_texture.get_width() >= 4096:
			return m
	return null


## Ждём, пока картинки поменяются (по одной за кадр); сколько кадров
func _swap_wait() -> int:
	var n := 0
	while Gfx.swap_busy() and n < 1500:
		await frames(1)
		n += 1
	return n


func _press(b: BaseButton) -> void:
	b.emit_signal("pressed")
	await frames(3)


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(30)
	var gfx: Gfx = game.gfx
	var hud = game.hud
	check(gfx != null and str(game.settings.get("quality_auto", "")) == "kept" and game.settings["quality"] == "high",
		"запуск с файлом настроек: «Высокая» осталась, quality_auto = kept", [game.settings.get("quality"), game.settings.get("quality_auto")])
	var f := FileAccess.get_file_as_string(game.settings_path())
	check(f.contains("\"quality_auto\":\"kept\""), "kept записано в settings.json")
	# окно настроек
	hud._open_settings()
	await frames(5)
	var sp: Control = hud.settings_panel
	var names := []
	for k: String in ["high", "medium", "low", "verylow"]:
		var b: Button = sp.find_child("q_" + k, true, false)
		names.append(b.text if b else "—")
	check(names == ["Высокая", "Средняя", "Низкая", "Очень низкая"], "настройки: четыре уровня графики", names)
	var gl: Label = sp.find_child("gpu_name", true, false)
	check(gl != null and gl.text.contains(RenderingServer.get_video_adapter_name()), "настройки: «Видеокарта: …»", gl.text if gl else "")
	var cb: CheckBox = sp.find_child("show_fps", true, false)
	check(cb != null and not cb.button_pressed and not gfx._fps.visible, "«Показывать FPS» есть и выключен по умолчанию")
	await shot("gfx_settings.png")
	# картинки «Очень низкой»: копия 2048² из файла картинки — точь-в-точь прежняя (через видеокарту)
	var mat := _big_mat()
	var path: String = mat.albedo_texture.resource_path if mat else ""
	var ctex := Gfx._ctex(path)
	var cache := Gfx._cache_file(path, ctex)
	DirAccess.remove_absolute(cache)
	var t0 := Time.get_ticks_usec()
	var a := Gfx._from_ctex(ctex)
	var miss_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var rb: Image = mat.albedo_texture.get_image() if mat else null
	var same := false
	# сжатая (Basis, 1.9): копия — мипмапы со второго, байт в байт то, что лежит на видеокарте; несжатая — уменьшение
	var packed := a != null and a.is_compressed()
	if a and rb:
		if packed:
			same = rb.is_compressed() and rb.has_mipmaps() and rb.get_format() == a.get_format() and a.has_mipmaps() \
				and rb.get_data().slice(rb.get_mipmap_offset(1)) == a.get_data()
		else:
			rb.resize(rb.get_width() / 2, rb.get_height() / 2, Image.INTERPOLATE_BILINEAR)
			var a2 := a.duplicate() as Image
			a2.convert(Image.FORMAT_RGBA8)
			rb.convert(Image.FORMAT_RGBA8)
			same = a2.get_data() == rb.get_data()
	var kind := "сжатая Basis: мипмапы со второго, %s" % ("BC7" if a and a.get_format() == Image.FORMAT_BPTC_RGBA else str(a.get_format() if a else -1)) if packed else "без сжатия: уменьшение"
	check(mat != null and a != null and a.get_width() == 2048 and same,
		"копия 2048² из файла картинки (без видеокарты) — та же, что на видеокарте (%s; %s, %.0f мс)" % [kind, path.get_file(), miss_ms],
		[a.get_format() if a else -1, rb.get_format() if rb else -1])
	Gfx.readbacks = 0
	# Очень низкая — и обратно: нажатие не ждёт картинок, они меняются в фоне по одной за кадр
	var bv: Button = sp.find_child("q_verylow", true, false)
	t0 = Time.get_ticks_usec()
	bv.emit_signal("pressed")
	var press_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var busy := Gfx.swap_busy()
	await frames(3)
	check(busy and press_ms < 1000.0, "«Очень низкая»: картинки меняются после нажатия, по одной за кадр (нажатие — %.0f мс)" % press_ms, [busy, press_ms])
	var vp := get_viewport()
	check(game.settings["quality"] == "verylow" and bool(game.settings.get("quality_user", false)), "«Очень низкая» нажата: выбор игрока (quality_user)")
	check(not game.sun.shadow_enabled and game.people.max_vis == 40 and vp.msaa_3d == Viewport.MSAA_DISABLED and is_equal_approx(vp.scaling_3d_scale, 0.5)
		and not (game.far_forest[0] as Node3D).visible and is_equal_approx(vp.mesh_lod_threshold, 4.0),
		"«Очень низкая»: без теней солнца, 40 прохожих, без MSAA, FSR 0.5, без дальних лесов, LOD раньше",
		[game.sun.shadow_enabled, game.people.max_vis, vp.msaa_3d, vp.scaling_3d_scale])
	var nf := await _swap_wait() + 3
	await frames(40)
	check(game.people.visible_count <= 40, "лишние прохожие убраны", game.people.visible_count)
	var at = mat.albedo_texture
	# копия на диске — только у несжатой (её уменьшать долго); сжатую каждый раз берём из файла — десятки мс
	check(not Gfx.swap_busy() and at is ImageTexture and at.get_width() == 2048 and str(at.get_meta("orig", "")) == path
		and FileAccess.file_exists(cache) != packed and (at as ImageTexture).get_format() == a.get_format() and Gfx.readbacks == 0,
		"«Очень низкая»: за %d кадров у материалов копии 2048² (%s), ни одного чтения с видеокарты" % [nf, "сжатые, как оригинал" if packed else "копия на диске"],
		[at, Gfx.readbacks, FileAccess.file_exists(cache)])
	check(Gfx.tex(path) == at, "новый материал берёт ту же копию (без картинки 4096²)")
	Gfx._small.erase(path)
	t0 = Time.get_ticks_usec()
	var hit := Gfx._small_tex(path)
	var hit_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var ci := Gfx._from_ctex(ctex) if packed else Gfx._cache_read(cache)
	check(hit != null and hit.get_width() == 2048 and Gfx.readbacks == 0 and ci != null and ci.get_data() == a.get_data(),
		("копия заново из сжатого файла — та же картинка (%.0f мс)" % hit_ms) if packed else
		("копия с диска — та же картинка (%.0f мс вместо %.0f мс из файла 4096²)" % [hit_ms, miss_ms]))
	await _press(sp.find_child("q_low", true, false))
	check(game.sun.shadow_enabled and is_equal_approx(game.sun.light_angular_distance, 0.0) and game.people.max_vis == 70
		and is_equal_approx(game.sun.directional_shadow_max_distance, 175.0) and vp.msaa_3d == Viewport.MSAA_DISABLED
		and (game.chunk_nodes.values()[0] as GeometryInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"«Низкая»: резкие тени (без PCSS) до 175 м, без MSAA, 70 прохожих, земля без тени")
	await _press(sp.find_child("q_high", true, false))
	var cast_ok := true
	for m: GeometryInstance3D in game.far_near:
		if m.cast_shadow != int(m.get_meta("cast", m.cast_shadow)):
			cast_ok = false
	check(game.sun.shadow_enabled and is_equal_approx(game.sun.light_angular_distance, 2.2) and game.people.max_vis == 150
		and vp.msaa_3d == Viewport.MSAA_4X and is_equal_approx(vp.scaling_3d_scale, 1.0) and (game.far_forest[0] as Node3D).visible
		and is_equal_approx(vp.mesh_lod_threshold, 1.0) and cast_ok and game.env.sdfgi_enabled
		and (game.chunk_nodes.values()[0] as GeometryInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON,
		"снова «Высокая»: всё вернулось (тени, PCSS, MSAA, масштаб, леса, тени пейзажа, SDFGI)")
	nf = await _swap_wait()
	at = mat.albedo_texture
	check(not Gfx.swap_busy() and at is CompressedTexture2D and at.resource_path == path and at.get_width() == 4096 and Gfx._small.is_empty(),
		"снова «Высокая»: за %d кадров оригиналы 4096² вернулись (читались в фоне), копии отпущены" % nf, [at, Gfx._small.size()])
	# счётчик кадров
	cb.button_pressed = true
	await frames(45)
	check(gfx._fps.visible and gfx._fps.text.ends_with("FPS") and bool(game.settings.get("show_fps", false)), "«Показывать FPS»: счётчик в углу", gfx._fps.text)
	hud._toggle(sp)
	await shot("gfx_fps.png")
	# F3
	var ev := InputEventKey.new()
	ev.keycode = KEY_F3
	ev.pressed = true
	get_viewport().push_input(ev)
	await frames(10)
	check(gfx._dbg != null and gfx._dbg.visible and gfx._dbg_text.text.contains("видеокарта") and gfx._dbg_text.text.contains(RenderingServer.get_video_adapter_name()),
		"F3: подробности (кадры, видеокарта, вызовы, память, название)")
	await shot("gfx_f3.png")
	gfx._toggle_dbg()
	cb.button_pressed = false
	# сторож кадров: 20 с в среднем меньше 40 кадров на «Высокой» — один совет с кнопкой
	game.settings["quality"] = "high"
	game.settings.erase("tip_q_low")
	game._apply_quality()
	gfx.auto_on = true
	hud.advisor_panel.visible = false            # приветствие советника закрыли — совет сторожа ждёт, пока советник свободен
	gfx._watch_t = 0.0
	gfx._watch_n = 0
	for i in 400:
		gfx._watch_step(0.05)                  # 400 кадров за 20 с — 20 кадров в секунду
	await frames(10)
	check(hud.advisor_panel.visible and hud.adv_skip.visible and hud.adv_skip.text == "Включить «Низкую»" and bool(game.settings.get("tip_q_low", false)),
		"сторож: советник предлагает «Низкую» кнопкой (один раз)", [hud.advisor_panel.visible, hud.adv_skip.text])
	check(hud.adv_ok.text == "Не надо" and hud.adv_skip.get_theme_font_size("font_size") == 18,
		"у вопроса — «Включить «Низкую»» обычной кнопкой и «Не надо» (а не «Понятно», которое читается как «да»)", hud.adv_ok.text)
	await shot("gfx_watchdog.png")
	await _press(hud.adv_skip)
	check(game.settings["quality"] == "low" and bool(game.settings.get("quality_user", false)) and not hud.advisor_panel.visible and game.people.max_vis == 70,
		"«Включить «Низкую»»: включилась, это выбор игрока")
	hud.advisor("Проверка", "обычный совет")
	check(hud.adv_skip.text == "Пропустить обучение" and not hud.adv_skip.visible and hud.adv_ok.text == "Понятно"
		and hud.adv_skip.get_theme_font_size("font_size") == 14, "следующий совет — с прежними кнопками («Понятно»)")
	hud.advisor_panel.visible = false
	for i in 400:
		gfx._watch_step(0.05)
	await frames(10)
	check(not hud.advisor_panel.visible, "второй раз сторож не предлагает")
	# проверка в городе после выбора по видеокарте: медленно — на ступень ниже, объяснение один раз
	game.settings["quality"] = "medium"
	game.settings["quality_auto"] = "medium"
	game.settings["quality_checked"] = false
	game.settings["quality_user"] = false
	game.settings.erase("tip_q_auto")
	game._apply_quality()
	check(gfx._check_due(), "выбрано по видеокарте — проверка в городе впереди")
	gfx._check_n = Gfx.CHECK_SKIP + 1
	gfx._check_t = Gfx.CHECK_SEC
	gfx._check_ms = PackedFloat32Array([14.0, 15.0, 16.0, 13.5, 14.2])
	gfx._check_step(0.0)
	await frames(10)
	check(game.settings["quality"] == "low" and game.settings["quality_auto"] == "low" and bool(game.settings["quality_checked"]) and not gfx._check_due(),
		"проверка: видеокарте нужно > 11 мс — на ступень ниже (Средняя → Низкая), больше не проверяем", [game.settings["quality"], game.settings.get("quality_checked")])
	check(hud.advisor_panel.visible and hud.adv_title.text.contains("видеокарт") and hud.adv_text.text.contains("Низкая"),
		"советник один раз: какой уровень выбран и где поменять", hud.adv_text.text)
	await shot("gfx_auto.png")
	# проверка прошла, а совет не увидели (закрыли игру во время обучения) — при следующем запуске советник объяснит
	hud.advisor_panel.visible = false
	game.settings.erase("tip_q_auto")
	var g2 := Gfx.new()
	g2.game = game
	game.add_child(g2)
	var q2 := g2._pending.filter(func(p): return p[3] == "tip_q_auto")
	check(q2.size() == 1 and str(q2[0][1]).contains("Низкая"), "совет о выборе не увидели — в следующий запуск советник объяснит", g2._pending)
	game.settings["quality_user"] = true
	var g3 := Gfx.new()
	g3.game = game
	game.add_child(g3)
	check(g3._pending.filter(func(p): return p[3] == "tip_q_auto").is_empty(), "…но не после ручного выбора («Я выбрал» было бы неправдой)")
	game.remove_child(g2)
	game.remove_child(g3)
	g2.free()
	g3.free()
	game.settings["quality_user"] = false
	game.settings["tip_q_auto"] = true
	var saved = JSON.parse_string(FileAccess.get_file_as_string(game.settings_path()))
	check(typeof(saved) == TYPE_DICTIONARY and saved.get("quality") == "low" and bool(saved.get("tip_q_auto", false)) and bool(saved.get("tip_q_low", false)),
		"всё записано в settings.json (уровень и флаги советов)", saved)
	_medium_light()
	_vram_copy()
	game.can_save = false
	print("GFX DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
