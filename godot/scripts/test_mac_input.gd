extends Node
## Управление на Mac — настоящими событиями, на Windows (как их присылает Godot на Mac,
## platform/macos/godot_content_view.mm): два пальца по трекпаду — InputEventPanGesture, щипок — InputEventMagnifyGesture.
##   bash .work/py/gpu_run.sh res://test_mac_input.tscn   — в конце «MACIN DONE fails=0»; снимки — .work/gd/a/mac/macin_*.png
## Проверяет: два пальца двигают карту (куда и насколько), ⌥ + два пальца — вращают и наклоняют, Ctrl/⌘ + два пальца
## и щипок — масштаб (точка под курсором остаётся под курсором), жест сбрасывает «Следовать»; над окном жест камеру
## не трогает; списки листаются жестом (титры — вверх-вниз, и перестают плыть сами; свиток стройки — вбок и от жеста
## вверх-вниз); Ctrl+Z / Ctrl+Y как прежде, а Win+Z на Windows — не отмена (⌘ только на Mac); мышь — как прежде
## (колёсико ×0,88, правая кнопка тянет карту); на Windows проверки «новой версии для Mac» нет; уровни графики Mac.

const SHOTS := "D:/CivCity/.work/gd/a/mac/"

var game
var rig
var fails := 0
var mask := 0


func check(ok: bool, what: String, extra = null) -> bool:
	print(("MACIN PASS " if ok else "MACIN FAIL ") + what + ("" if ok or extra == null else "  " + str(extra)))
	if not ok:
		fails += 1
	return ok


func _ready() -> void:
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	await frames(4)
	DirAccess.make_dir_recursive_absolute(SHOTS)
	get_viewport().get_texture().get_image().save_png(SHOTS + name)
	print("SHOT ", SHOTS + name)


func move(p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	e.button_mask = mask
	Input.parse_input_event(e)


func btn(p: Vector2, idx: int, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = p
	e.global_position = p
	e.button_index = idx
	e.pressed = pressed
	if pressed:
		mask |= 1 << (idx - 1)
	else:
		mask &= ~(1 << (idx - 1))
	e.button_mask = mask
	Input.parse_input_event(e)


func click(p: Vector2, idx := MOUSE_BUTTON_LEFT) -> void:
	move(p)
	await frames(3)
	btn(p, idx, true)
	await frames(2)
	btn(p, idx, false)
	await frames(3)


func drag(a: Vector2, b: Vector2) -> void:
	move(a)
	await frames(3)
	btn(a, MOUSE_BUTTON_LEFT, true)
	for k in 30:
		move(a.lerp(b, k / 29.0))
		await frames(1)
	btn(b, MOUSE_BUTTON_LEFT, false)
	await frames(5)


## Два пальца по трекпаду (как шлёт Godot на Mac: позиция курсора, delta, клавиши-модификаторы)
func pan(p: Vector2, d: Vector2, alt := false, ctrl := false) -> void:
	var e := InputEventPanGesture.new()
	e.position = p
	e.delta = d
	e.alt_pressed = alt
	e.ctrl_pressed = ctrl
	Input.parse_input_event(e)


func pinch(p: Vector2, f: float) -> void:
	var e := InputEventMagnifyGesture.new()
	e.position = p
	e.factor = f
	Input.parse_input_event(e)


func key(code: Key, ctrl := false, meta := false, shift := false) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		e.ctrl_pressed = ctrl
		e.meta_pressed = meta
		e.shift_pressed = shift
		Input.parse_input_event(e)
		await frames(2)


func scr(w: Vector2) -> Vector2:
	var cam: Camera3D = get_viewport().get_camera_3d()
	return get_viewport().get_final_transform() * cam.unproject_position(Vector3(w.x, game.land.height_at(w.x, w.y), w.y))


func center_of(c: Control) -> Vector2:
	return c.get_viewport().get_final_transform() * (c.get_global_transform_with_canvas() * (c.size / 2.0))


## Точка карты, где под курсором нет окна (ищем по сетке)
func world_point() -> Vector2:
	var vs := get_viewport().get_visible_rect().size
	for fy in [0.42, 0.5, 0.36, 0.58, 0.3]:
		for fx in [0.5, 0.42, 0.58, 0.35, 0.65]:
			var p := vs * Vector2(fx, fy)
			move(p)
			await frames(2)
			if not CameraRig.gesture_on_ui(get_viewport()) and game.ground_at_mouse().is_finite():
				return p
	return vs * 0.5


func view(at := Vector3(192, 2, 140), yaw := 15.0, pitch := 50.0, d := 40.0) -> void:
	rig.set_view(at, yaw, pitch, d)
	await frames(10)


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(30)
	rig = game.rig
	game.hud.advisor_panel.visible = false
	_tiers()
	check(MacUpdate._inst == null and not MacUpdate.wanted(), "на Windows проверки «новой версии для Mac» нет (узел не создан)")
	check(not Packs.all_in_one, "в редакторе наборы не «всё в одном»")

	# ---------- два пальца: карта едет вместе с пальцами ----------
	await view()
	var p := await world_point()
	check(not CameraRig.gesture_on_ui(get_viewport()), "точка карты без окон под курсором", p)
	var right := Vector3(cos(rig._yaw_t), 0, -sin(rig._yaw_t))
	var fwd := Vector3(sin(rig._yaw_t), 0, cos(rig._yaw_t))
	var k: float = rig._dist_t * 0.0016 * CameraRig.GESTURE_PX
	var t0: Vector3 = rig._target_t
	for i in 4:
		pan(p, Vector2(0.5, 0))
		await frames(1)
	var dt: Vector3 = rig._target_t - t0
	check(absf(dt.dot(right) - 2.0 * k) < 0.05 * k and absf(dt.dot(fwd)) < 0.01, "два пальца вбок: цель вправо на %.2f м (ждали %.2f)" % [dt.dot(right), 2.0 * k], dt)
	# два одинаковых жеста в одном кадре (трекпад шлёт чаще, чем кадры) — оба в счёт, а копии Godot — нет
	t0 = rig._target_t
	pan(p, Vector2(0.5, 0))
	pan(p, Vector2(0.5, 0))
	await frames(1)
	dt = rig._target_t - t0
	check(absf(dt.dot(right) - k) < 0.05 * k, "два одинаковых жеста в одном кадре: %.2f м (ждали %.2f)" % [dt.dot(right), k])
	t0 = rig._target_t
	pan(p, Vector2(0, 1.0))
	await frames(1)
	dt = rig._target_t - t0
	check(absf(dt.dot(fwd) - k) < 0.05 * k, "два пальца вверх (вид вниз): цель к камере на %.2f м (ждали %.2f)" % [dt.dot(fwd), k], dt)
	# ⌥ Option + два пальца — вращать и наклонять
	var y0: float = rig._yaw_t
	var p0: float = rig._pitch_t
	pan(p, Vector2(1.0, 0), true)
	await frames(1)
	check(absf((rig._yaw_t - y0) - CameraRig.GESTURE_PX * 0.006) < 1e-4, "⌥ + два пальца вбок: поворот на %.1f°" % rad_to_deg(rig._yaw_t - y0))
	pan(p, Vector2(0, 1.0), true)
	await frames(1)
	check(absf((p0 - rig._pitch_t) - CameraRig.GESTURE_PX * 0.005) < 1e-4, "⌥ + два пальца вверх-вниз: наклон на %.1f°" % rad_to_deg(p0 - rig._pitch_t))
	var t1: Vector3 = rig._target_t
	check(t1.distance_to(t0 + fwd * k) < 0.01, "⌥ + два пальца карту не двигают")
	# Ctrl (на Mac ⌘) + два пальца — масштаб
	var d0: float = rig._dist_t
	pan(p, Vector2(0, 1.0), false, true)
	await frames(1)
	check(rig._dist_t < d0 and absf(rig._dist_t / d0 - exp(-CameraRig.GESTURE_ZOOM)) < 0.02, "⌘ + два пальца вверх — ближе: %.1f → %.1f" % [d0, rig._dist_t])
	# щипок — масштаб к точке под пальцами (как колёсико)
	await view()
	p = await world_point()
	await frames(40)
	var g0: Vector2 = game.ground_at_mouse()
	d0 = rig._dist_t
	for i in 3:
		pinch(p, 1.15)
		await frames(2)
	await frames(120)
	var g1: Vector2 = game.ground_at_mouse()
	check(absf(rig._dist_t - d0 / pow(1.15, 3)) < 0.05, "щипок врозь — ближе: %.1f → %.1f (ждали %.1f)" % [d0, rig._dist_t, d0 / pow(1.15, 3)])
	check(g0.is_finite() and g1.is_finite() and g0.distance_to(g1) <= 0.6, "щипок: точка под курсором сдвинулась на %.2f м" % g0.distance_to(g1))
	d0 = rig._dist_t
	pinch(p, 0.8)
	await frames(2)
	check(absf(rig._dist_t - d0 / 0.8) < 0.05, "щипок вместе — дальше: %.1f → %.1f" % [d0, rig._dist_t])
	await shot("macin_pinch.png")
	# жест сбрасывает «Следовать» (как тянуть карту мышью)
	rig.start_follow(func() -> Vector3: return Vector3(192, 2, 140))
	check(rig.following(), "«Следовать» включено")
	pan(p, Vector2(0.4, 0.2))
	await frames(2)
	check(not rig.following(), "два пальца сбросили «Следовать»")

	# ---------- мышь — как прежде ----------
	await view()
	p = await world_point()
	d0 = rig._dist_t
	btn(p, MOUSE_BUTTON_WHEEL_UP, true)
	btn(p, MOUSE_BUTTON_WHEEL_UP, false)
	await frames(2)
	check(absf(rig._dist_t - d0 * 0.88) < 1e-3, "колёсико: ×0,88 (%.2f → %.2f)" % [d0, rig._dist_t])
	await view()
	p = await world_point()
	t0 = rig._target_t
	right = Vector3(cos(rig._yaw_t), 0, -sin(rig._yaw_t))
	btn(p, MOUSE_BUTTON_RIGHT, true)
	await frames(1)
	var rel := Vector2(40, 0)
	var mm := InputEventMouseMotion.new()
	mm.position = p + rel
	mm.global_position = p + rel
	mm.relative = rel
	mm.button_mask = mask
	Input.parse_input_event(mm)
	await frames(1)
	btn(p + rel, MOUSE_BUTTON_RIGHT, false)
	await frames(2)
	dt = rig._target_t - t0
	var rel_vp := get_viewport().get_final_transform().affine_inverse().basis_xform(rel)    # окно проверки ≠ 1600×900
	check(absf(dt.dot(right) + rel_vp.x * rig._dist_t * 0.0016) < 0.01, "правая кнопка тянет карту как прежде: %.2f м (ждали %.2f)" % [dt.dot(right), -rel_vp.x * rig._dist_t * 0.0016])
	game.hud.close_panels()
	game.set_tool("")
	await frames(5)

	# ---------- над окном жест камеру не трогает ----------
	await view()
	var bar: Control = game.hud.bar_mid
	var bp := center_of(bar)
	move(bp)
	await frames(3)
	check(CameraRig.gesture_on_ui(get_viewport()), "курсор над нижней панелью разделов", get_viewport().gui_get_hovered_control())
	t0 = rig._target_t
	d0 = rig._dist_t
	pan(bp, Vector2(1.5, 1.5))
	pinch(bp, 1.3)
	await frames(3)
	check(rig._target_t.distance_to(t0) < 1e-4 and absf(rig._dist_t - d0) < 1e-4, "над окном: ни сдвига, ни масштаба")

	# ---------- свиток стройки: жестом вбок и вверх-вниз ----------
	await click(center_of(game.hud.cats["housing"]))
	await frames(10)
	var sc: ScrollContainer = game.hud.tray.find_child("scroll", true, false)
	var hs := sc.get_h_scroll_bar()
	if hs.max_value - hs.page <= 1.0:
		# карточек мало — свиток не листается; сужаем его на время проверки (обработчик тот же)
		sc.custom_minimum_size.x = 0
		sc.size.x = 200
		(sc.get_parent() as Control).custom_minimum_size.x = 0
		await frames(3)
	var card: Control = game.hud.tray_grid.get_child(0)
	var cp := center_of(card)
	move(cp)
	await frames(3)
	t0 = rig._target_t
	var h0 := hs.value
	pan(cp, Vector2(0, 2.0))
	await frames(2)
	check(hs.max_value - hs.page > 1.0 and hs.value > h0, "свиток стройки: два пальца вверх-вниз листают вбок (%.0f → %.0f из %.0f)" % [h0, hs.value, hs.max_value - hs.page])
	h0 = hs.value
	pan(cp, Vector2(-1.0, 0))
	await frames(2)
	check(hs.value < h0, "свиток стройки: два пальца вбок листают вбок (%.0f → %.0f)" % [h0, hs.value])
	check(rig._target_t.distance_to(t0) < 1e-4, "свиток стройки листается — карта стоит")
	game.hud._close_tray()
	await frames(5)

	# ---------- список вверх-вниз: титры ----------
	game.hud.open_credits()
	await frames(20)
	var csc: ScrollContainer = game.hud.credits_panel.find_child("scroll", true, false)
	var cpt := center_of(csc)
	move(cpt)
	await frames(3)
	var v0 := csc.get_v_scroll_bar().value
	t0 = rig._target_t
	for i in 3:
		pan(cpt, Vector2(0, 2.0))
		await frames(1)
	await frames(2)
	check(csc.get_v_scroll_bar().value > v0 + 10.0, "титры листаются двумя пальцами (%.0f → %.0f)" % [v0, csc.get_v_scroll_bar().value])
	check(not game.hud.credits_panel.has_meta("roll"), "после жеста титры больше не плывут сами")
	check(rig._target_t.distance_to(t0) < 1e-4, "титры листаются — карта стоит")
	await shot("macin_credits.png")
	game.hud.close_panels()
	await frames(5)

	# ---------- Ctrl+Z / Ctrl+Y как прежде; Win+Z на Windows — не отмена ----------
	await view(Vector3(192, 2, 138), 15, 58, 40)
	await click(center_of(game.hud.road_btns["road"]))
	await drag(scr(Vector2(186, 128)), scr(Vector2(186, 150)))
	var probe := Vector2(186, 140)
	var kind0: int = game.land.kind_at(probe.x, probe.y)
	check(game.land.is_road(probe), "мазок дороги лёг", kind0)
	await key(KEY_Z, false, true)              # Win+Z (на Mac это был бы ⌘Z)
	await frames(3)
	check(game.land.is_road(probe), "Win+Z на Windows — не отмена (дорога на месте)")
	await key(KEY_Z, true)
	await frames(3)
	check(not game.land.is_road(probe), "Ctrl+Z — мазок отменён")
	await key(KEY_Y, true)
	await frames(3)
	check(game.land.is_road(probe), "Ctrl+Y — мазок вернулся")
	var kc := InputEventKey.new()
	kc.ctrl_pressed = true
	var km := InputEventKey.new()
	km.meta_pressed = true
	check(Game.cmd_key(kc) and not Game.cmd_key(km), "cmd_key: Ctrl — да, Win — нет (на Windows как прежде)")
	game.set_tool("")
	print("MACIN DONE fails=%d" % fails)
	get_tree().quit()


## Уровни графики Mac (без видеокарты — по названию, как шлёт Godot)
func _tiers() -> void:
	var I := RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU
	var D := RenderingDevice.DEVICE_TYPE_DISCRETE_GPU
	var cases := [
		["Apple M1 (Apple7)", I, "low"], ["Apple M2 (Apple8)", I, "low"], ["Apple M3 (Apple9)", I, "low"],
		["Apple M4 (Apple9)", I, "medium"], ["Apple M5 (Apple10)", I, "medium"],
		["Apple M1 Pro (Apple7)", I, "medium"], ["Apple M4 Pro (Apple9)", I, "medium"],
		["Apple M1 Max (Apple7)", I, "medium"], ["Apple M2 Max (Apple8)", I, "medium"], ["Apple M3 Max (Apple9)", I, "high"],
		["Apple M4 Max (Apple9)", I, "high"], ["Apple M1 Ultra (Apple7)", I, "high"], ["Apple M2 Ultra (Apple8)", I, "high"],
		["Apple Paravirtual device", I, "verylow"], ["Apple A18 Pro (Apple9)", I, "low"],
		["Intel(R) Iris(TM) Plus Graphics 655", I, "verylow"], ["Intel(R) UHD Graphics 630", I, "verylow"],
		["Intel(R) Iris(TM) Plus Graphics", I, "verylow"],
		["AMD Radeon Pro 560X", D, "low"], ["AMD Radeon Pro 5500M", D, "low"], ["AMD Radeon Pro 5300M", D, "low"],
		["AMD Radeon Pro Vega 20", D, "low"], ["AMD Radeon Pro 5700 XT", D, "medium"], ["AMD Radeon Pro W5700X", D, "medium"],
		# прежние ПК — те же
		["NVIDIA GeForce RTX 3060", D, "medium"], ["AMD Radeon RX 6600", D, "medium"], ["Intel(R) Iris(R) Xe Graphics", I, "verylow"]]
	var bad := []
	for c: Array in cases:
		var got := Gfx.tier_for(c[0], c[1])
		if got != c[2]:
			bad.append("%s → %s (ждали %s)" % [c[0], got, c[2]])
	check(bad.is_empty(), "уровни графики Mac: %d названий" % cases.size(), bad)
	check(is_equal_approx(Gfx.hidpi_scale(), 1.0), "на Windows 3D не уменьшается (hidpi_scale = 1)")
