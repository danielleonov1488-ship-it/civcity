extends Node
## Проверка общего счёта по шагам симуляции и пять кадров боевого экрана.

const View = preload("res://scripts/legion_battle_view.gd")
const OUT := "D:/CivCity/.work/stage7/battle13/shots"
const HD := Vector2i(1920, 1080)
const SMALL := Vector2i(1280, 720)
const FRAME := 1.0 / 60.0

var game: Game
var battle: LegionBattle
var fails := 0
var output := OUT
var run_suite := true


func _ready() -> void:
	if not run_suite:
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			output = arg.trim_prefix("out=")
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	game.can_save = false
	game.hero_screen_auto = false
	add_child(game)
	if _check(await _until(func() -> bool: return game.ready_done, 150.0), "ready_done"):
		await run_on(game, output)
	else:
		print("BATTLE13 DONE fails=", fails)
	get_tree().quit(int(fails != 0))


func run_on(test_game: Game, shots: String) -> void:
	game = test_game
	output = shots
	if _check(DisplayServer.get_name() != "headless" and DirAccess.make_dir_recursive_absolute(output) == OK,
			"shot directory and graphics"):
		game.settings["autosave"] = false
		game.city.name = "Аврелия"
		get_window().content_scale_size = Vector2i.ZERO
		get_window().size = HD
		await _campaign()
		await _pvp()
		await _tutorial_loss()
		await _timeout()
	print("BATTLE13 DONE fails=", fails)


func _check(ok: bool, reason: String) -> bool:
	if not ok:
		fails += 1
		print("BATTLE13 FAIL ", reason)
	return ok


func _until(condition: Callable, seconds: float) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < end:
		await get_tree().process_frame
	return condition.call()


func _open(setup: Dictionary, auto := false) -> bool:
	battle = LegionBattle.open(game, setup, Callable(), {"speed": 1.0, "auto": auto, "auto_any": true})
	battle.set_process(false)
	if not _check(await _until(func() -> bool: return battle.phase == "intro", 30.0), "open battle"):
		await _close()
		return false
	battle.fade.hide()
	return true


func _close() -> void:
	battle.abort()
	await get_tree().process_frame


func _tick(frames := 1) -> void:
	for i in frames:
		battle._process(FRAME)


func _advance_until(condition: Callable, frames: int) -> bool:
	for i in frames:
		if condition.call() or not battle.sim.result.is_empty():
			break
		_tick()
	return condition.call()


func _shot(file: String, resolution: Vector2i) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	_check(image.get_size() == resolution, "shot resolution " + file)
	var path := output.path_join(file)
	if _check(image.save_png(path) == OK, "save " + file):
		print("BATTLE13 SHOT ", path)


func _setup(st: Dictionary, squad: Array, waves: Array) -> Dictionary:
	return {"kind": "campaign", "stage": st, "squad": squad, "waves": waves, "seed": 532,
		"perks": {"bandage": 1}, "rations_paid": true}


func _campaign() -> void:
	var st := Legion.stage(0, 0, 9)
	var squad := [Legion.unit_stats("legionary", 8), Legion.unit_stats("spearman", 8),
		Legion.unit_stats("legionary", 8), Legion.unit_stats("archer", 8), Legion.unit_stats("priest", 8)]
	for entry: Dictionary in squad:
		entry["hp"] = float(entry["hp"]) * 2.1
	var first := [Legion.enemy_stats("forestBear", 0.92), Legion.enemy_stats("bandit", 0.92),
		Legion.enemy_stats("slinger", 0.92)]
	var second := [Legion.enemy_stats("chief", 0.92), Legion.enemy_stats("bandit", 0.92)]
	if not await _open(_setup(st, squad, [first, second]), true):
		return
	_totals("start")
	var title := String(st["name"]) if String(st["theme"]).is_empty() else String(st["theme"])
	_check(battle.ally_name.text == game.city.name and battle.enemy_name.text == I18n.t(title), "campaign names")
	_check(battle.battle_clock.text == "03:00" and battle.wave_chip.visible and
		battle.wave_lbl.text == I18n.t("Волна %d/%d") % [1, 2] and not battle.boss_panel.visible, "first wave")
	_check_speed(1)
	_check_speed(3)
	var first_max := battle.enemy_health.max_hp
	var trail_seen := _advance_until(func() -> bool: return battle.enemy_health.trail > battle.enemy_health.displayed + 0.01, 500)
	_check(trail_seen and battle.sim.wave_idx == 0, "white damage trail in first wave")
	_totals("first damage")
	await _shot("1_top_block.png", HD)
	_top_layout(HD)
	if _check(_advance_until(func() -> bool: return battle.sim.wave_idx == 1, 1800), "boss wave reached"):
		_totals("new wave")
		_check(battle.wave_lbl.text == I18n.t("Волна %d/%d") % [2, 2] and battle.enemy_health.max_hp != first_max, "new wave chip and HP max")
		_check(battle.boss_panel.visible and battle.boss_pic.texture != null and
			battle.enemy_medal.texture == battle.boss_pic.texture, "boss panel and portrait")
		_tick(60)
		_totals("boss fighting")
		_check(battle.boss_panel.visible and is_equal_approx(battle.boss_bar.value, battle._boss_unit.hp_frac()), "boss HP")
		await _shot("2_boss_wave.png", HD)
		_top_layout(HD)
		get_window().size = SMALL
		await get_tree().process_frame
		await get_tree().process_frame
		await _shot("4_720p.png", SMALL)
		_top_layout(SMALL)
		if _check(_advance_until(func() -> bool: return not battle.sim.result.is_empty(), 2400), "campaign ends"):
			_check(bool(battle.sim.result["win"]), "campaign ends in a win")
			_tick(40)
			_totals("won")
			_check(battle.enemy_health.displayed == 0.0 and battle.enemy_health.trail == 0.0 and
				not battle.boss_panel.visible, "defeated enemies reach zero and boss panel hides")
	await _close()
	get_window().size = HD


func _check_speed(speed: int) -> void:
	battle.speed_btns[speed].pressed.emit()
	var start := battle.sim.t
	_tick(61)
	_check(absf(battle.sim.t - start - 61 * FRAME * speed) < 0.08, "sim advances at ×%d" % speed)
	var parts := battle.battle_clock.text.split(":")
	var shown := int(parts[0]) * 60 + int(parts[1])
	var expected := 180.0 - battle.sim.t
	_check(absf(battle.time_left - expected) <= 0.2 and absf(shown - expected) <= 0.2,
		"clock at ×%d: %s / %.3f" % [speed, battle.battle_clock.text, expected])
	_totals("×%d" % speed)
	var paused_at := battle.sim.t
	battle.pause_btn.pressed.emit()
	_tick(15)
	_check(battle.sim.t == paused_at and battle.battle_clock.text == "%02d:%02d" % [shown / 60, shown % 60], "paused clock")
	battle.pause_btn.pressed.emit()


func _pvp() -> void:
	var own := [{"type": "legionary", "level": 7}, {"type": "spearman", "level": 7},
		{"type": "archer", "level": 7}, {"type": "priest", "level": 7}]
	var rival := [{"type": "legionary", "level": 7}, {"type": "spearman", "level": 7},
		{"type": "legionary", "level": 7}, {"type": "archer", "level": 7}]
	var replay := game.city.legion.make_pvp_battle({"name": "Тускулум", "rating": 240, "city_level": 5,
		"attack": {"v": 1, "squad": own}, "snapshot": {"v": 1, "squad": rival}}, 701)
	if not await _open(replay):
		return
	_tick(250)
	_check(battle.pvp and battle.enemy_name.text == "Тускулум" and battle.enemy_medal.texture != null and
		not battle.wave_chip.visible and not battle.boss_panel.visible, "PvP replay score")
	_totals("PvP")
	await _shot("3_pvp.png", HD)
	_top_layout(HD)
	await _close()


func _tutorial_loss() -> void:
	var recruit := Legion.unit_stats("legionary", 1)
	recruit["hp"] = 1.0
	var setup := _setup(Legion.stage(0, 0, 0), [recruit], [[Legion.enemy_stats("bandit", 1.0)]])
	setup["fort_guide_first"] = true
	if not await _open(setup):
		return
	_check(battle.top_block.visible and not battle.battle_clock.visible and not battle.wave_chip.visible and
		not battle.boss_panel.visible, "first tutorial score")
	if _check(_advance_until(func() -> bool: return not battle.sim.result.is_empty(), 1200), "tutorial battle ends"):
		_check(not bool(battle.sim.result["win"]) and not bool(battle.sim.result["timeout"]), "defeated ally")
		_tick(40)
		_totals("lost")
		_check(battle.ally_health.displayed == 0.0 and battle.ally_health.trail == 0.0, "defeated allies reach zero")
	await _close()


func _timeout() -> void:
	var ally := Legion.unit_stats("legionary", 1)
	var enemy := Legion.enemy_stats("bandit", 1.0)
	for entry: Dictionary in [ally, enemy]:
		entry["hp"] = 24000.0
		entry["atk"] = 5.0
	if not await _open(_setup(Legion.stage(0, 0, 0), [ally], [[enemy]])):
		return
	# Подходим к границе, затем даём симуляции самой довести бой до тайм-аута.
	battle.sim.t = 149.0
	_tick()
	var normal := battle.battle_clock.get_theme_color("font_color")
	battle.speed_btns[3].pressed.emit()
	_tick(60)
	_check(battle.battle_clock.text == "00:28" and battle.battle_clock.get_theme_color("font_color") != normal,
		"last 30 seconds turn red")
	await _shot("5_last_30s.png", HD)
	if _check(_advance_until(func() -> bool: return not battle.sim.result.is_empty(), 700), "time limit reached"):
		_check(bool(battle.sim.result["timeout"]) and battle.time_left == 0.0 and
			battle.battle_clock.text == "00:00", "sim timeout at zero")
		_tick(150)
		# Панель итога собирается по частям на кадрах дерева.
		await _until(func() -> bool: return battle.phase == "result", 10.0)
		var title := battle.modal.find_child("LegionBattleResultTitle", true, false) as Label if battle.modal else null
		_check(battle.phase == "result" and title != null and title.text == I18n.t("Время вышло"), "timeout result")
	await _close()


func _totals(at: String) -> void:
	for side: String in ["ally", "enemy"]:
		var hp := 0.0
		var maximum := 0.0
		for u in battle.sim.units:
			if u.side != side or (side == "enemy" and u.wave != battle.sim.wave_idx):
				continue
			if u.alive:
				hp += u.hp
			maximum += u.max_hp
		var bar := battle.ally_health if side == "ally" else battle.enemy_health
		_check(is_equal_approx(bar.hp, hp) and is_equal_approx(bar.max_hp, maximum) and
			bar.caption.text == "%d/%d" % [roundi(hp), roundi(maximum)], "%s HP totals %s" % [side, at])


func _top_layout(resolution: Vector2i) -> void:
	var screen := Rect2(Vector2.ZERO, Vector2(resolution))
	var controls: Array[Control] = [battle.top_block, battle.retreat_btn, battle.pause_btn, battle.auto_btn]
	for button: Button in battle.speed_btns.values():
		controls.append(button)
	if battle.boss_panel.visible:
		controls.append(battle.boss_panel)
		_separate([battle.boss_pic, battle.boss_name, battle.boss_bar], battle.boss_panel.get_global_rect(), "boss")
	if battle.banner.modulate.a > 0.01:
		controls.append(battle.banner)
	_separate(controls, screen, "top")
	var panel := battle.top_block.get_global_rect()
	var contents: Array[Control] = [battle.ally_health, battle.enemy_health, battle.ally_name,
		battle.enemy_name, battle.battle_clock]
	if battle.wave_chip.visible:
		contents.append(battle.wave_chip)
	var row := battle.ally_health.get_parent().get_parent()
	for medal: Node in row.get_children():
		if medal is TextureRect:
			contents.append(medal)
	_separate(contents, panel, "score")
	_check(absf(panel.get_center().x - screen.get_center().x) < 1.0, "score centered")
	for fighter: View.Fighter in battle.views.values():
		if fighter.unit.alive and not fighter.unit.entering:
			var y := battle.battle_view.screen(fighter.head()).y
			_check(y - 7.0 >= battle._score_floor(), "fighter headroom " + fighter.unit.key)
	print("BATTLE13 LAYOUT %dx%d score=%.0fx%.0f bottom=%.0f" %
		[resolution.x, resolution.y, panel.size.x, panel.size.y, battle._score_floor()])


func _separate(nodes: Array[Control], bounds: Rect2, group: String) -> void:
	for i in nodes.size():
		var rect := nodes[i].get_global_rect()
		_check(nodes[i].is_visible_in_tree() and rect.has_area() and bounds.encloses(rect), "fits " + group + " " + str(nodes[i].name))
		for j in i:
			_check(not rect.intersects(nodes[j].get_global_rect()), "overlap " + str(nodes[i].name) + " / " + str(nodes[j].name))
