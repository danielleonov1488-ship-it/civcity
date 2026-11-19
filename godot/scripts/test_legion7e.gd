extends Node
## Бой с пятью 3D-союзниками, проверка повтора и три кадра из игры.

const View = preload("res://scripts/legion_battle_view.gd")
const SKILLS := ["oil", "bandage", "volley"]
var out_dir := "D:/CivCity/.work/stage6/legion7e/shots"
var game: Game
var battle: LegionBattle
var fails := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out_dir = arg.trim_prefix("out=").trim_suffix("/")
	Game.boot = {"new": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	game.can_save = false
	game.hero_screen_auto = false
	add_child(game)
	_run()


func check(ok: bool, reason: String) -> bool:
	if not ok:
		fails += 1
		print("LEGION7E FAIL ", reason)
	return ok


func finish() -> void:
	if is_instance_valid(battle) and LegionBattle.current == battle:
		battle.abort()
	print("LEGION7E DONE fails=", fails)
	get_tree().quit(int(fails > 0))


func until(ready: Callable, seconds: float) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not bool(ready.call()) and Time.get_ticks_msec() < end:
		await get_tree().process_frame
	return bool(ready.call())


func shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join(file)
	var image := get_viewport().get_texture().get_image()
	if check(image != null and image.save_png(path) == OK, "кадр " + file):
		print("LEGION7E SHOT ", path)


func _setup(legion: Legion) -> Dictionary:
	var squad := [Legion.unit_stats("priest", 5), Legion.unit_stats("archer", 5),
		Legion.unit_stats("cavalry", 5), Legion.hero_unit_stats(5, 1, 1), Legion.unit_stats("legionary", 5)]
	for unit: Dictionary in squad:
		unit["row"] = 0
	var waves := []
	for keys: Array in [["bandit", "slinger", "bear", "gaul", "gaulArcher"],
			["bandit", "gaul", "slinger"], ["gaul", "gaulArcher", "forestBear"], ["bear", "slinger"], ["chief", "bandit"]]:
		var wave := []
		for key: String in keys:
			wave.append(Legion.enemy_stats(key, 1.0))
		waves.append(wave)
	return {"kind": "campaign", "stage": legion.stage_info(0, 0, 0), "seed": 71237,
		"squad": squad, "waves": waves, "perks": {"oil": 1, "bandage": 1, "volley": 1},
		"rations_paid": true}


func _click(button: Button) -> void:
	var at := get_viewport().get_final_transform() * (button.get_global_transform_with_canvas() * (button.size * 0.5))
	for down: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = at
		click.global_position = at
		click.button_index = MOUSE_BUTTON_LEFT
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		click.pressed = down
		get_viewport().push_input(click)


func _run() -> void:
	if not check(await until(func(): return game.ready_done, 240.0), "город не загрузился"):
		finish()
		return
	game.can_save = false
	game.settings["autosave"] = false
	if not check(DirAccess.make_dir_recursive_absolute(out_dir) == OK, "папка кадров"):
		finish()
		return

	var legion: Legion = game.city.legion
	legion.flags["battle_speed"] = 1.0
	legion.flags["battle_auto"] = false
	legion.flags["battle_hints"] = 3
	var setup := _setup(legion)
	var disabled_3d_before := get_viewport().disable_3d
	legion.battle_requested.emit(setup)
	battle = LegionBattle.current
	if not check(is_instance_valid(battle), "сигнал не открыл бой"):
		finish()
		return
	if not check(await until(func(): return battle.sim != null and battle.fade.modulate.a <= 0.01, 15.0), "поле не открылось"):
		finish()
		return

	check(battle.battle_view.people_layer.viewport.transparent_bg, "прозрачный 3D-слой бойцов")
	check(battle.views.size() == 10, "на старте нужно десять бойцов")
	var ally_sheets := {}
	var enemy_sheets := {}
	for f: View.Fighter in battle.views.values():
		var ours := f.unit.side == "ally"
		var sheets := ally_sheets if ours else enemy_sheets
		sheets[f.sheet] = true
		if ours:
			check(f.sprite == null and f.actor != null and f.actor.problem.is_empty()
				and f.actor.get_parent() == battle.battle_view.people_layer.viewport, "модель " + f.sheet)
		else:
			check(f.sprite == null and f.actor != null and f.actor.problem.is_empty()
				and f.actor.get_parent() == battle.battle_view.people_layer.viewport
				and f.actor.rotation_degrees.y < 0.0, "3D-модель противника " + f.unit.key)
		check((f.position.x < 0.0 if ours else f.position.x > 0.0) and (ours or f.flip_h), "сторона и направление " + f.sheet)
	check(ally_sheets.size() == 5 and enemy_sheets.has("bear") and enemy_sheets.has("barbarian_archer"), "листы отрядов")
	check(battle.wave_lbl.text == (I18n.t("Волна %d/%d") % [1, 5]), "табличка первой волны")
	await shot("1_battle_start.png")

	_click(battle.pause_btn)
	var held := battle.sim.t
	for i in 6:
		await get_tree().process_frame
	check(battle.paused and battle.sim.t == held, "пауза не остановила бой")
	_click(battle.pause_btn)
	check(not battle.paused, "бой не снялся с паузы")

	var fired := {}
	var mid := false
	var fps_ten := 0.0
	var end := Time.get_ticks_msec() + 120000
	while battle.phase != "result" and Time.get_ticks_msec() < end:
		if battle.views.size() == 10 and battle.fps_avg > 0.0:
			fps_ten = battle.fps_avg
		if not mid and battle.sim.t >= 3.5:
			for projectile in battle.shots.values():
				if projectile is AnimatedSprite2D:
					mid = true
					await shot("2_battle_mid.png")
					_click(battle.speed_btns[3])
					check(battle.speed == 3.0, "переключатель скорости")
					break
		for id: String in SKILLS:
			if fired.has(id) or battle.sim.perk_ready(id) != 0.0 or battle.sim.alive_of("enemy").is_empty():
				continue
			var button: Button = battle.perk_btns[id]
			var n := battle.sim.perks_used
			_click(button)
			if check(battle.sim.perks_used == n + 1 and battle.sim.perk_ready(id) > 0.0, "не сработало умение " + id):
				_click(button)
				check(battle.sim.perks_used == n + 1, "умение сработало во время перезарядки " + id)
			fired[id] = true
		await get_tree().process_frame
	check(mid, "не удалось увидеть летящую стрелу")
	print("LEGION7E FPS 10 units ", snappedf(fps_ten, 0.1))
	if not check(battle.phase == "result", "бой не дошёл до итога"):
		finish()
		return
	check(fired.size() == SKILLS.size() and battle.sim.perks_used == SKILLS.size(), "ожидаются три нажатия умений")
	_compare(setup)
	await get_tree().process_frame
	await shot("3_result.png")
	var back := battle.find_child("LegionBattleReturn", true, false) as Button
	if check(back != null and back.has_meta("ui_kit_a"), "кнопка возврата из итога"):
		_click(back)
		check(await until(func(): return LegionBattle.current == null, 5.0), "бой не закрылся")
		check(get_viewport().disable_3d == disabled_3d_before and game.hud.visible, "город не вернулся")
	finish()


func _compare(setup: Dictionary) -> void:
	# Прежний экран крутил тот же фиксированный шаг. Повторяем его с теми же вводами без отрисовки.
	var replay := LegionSim.new(setup)
	var inputs: Array = battle.sim.result["inputs"]
	var i := 0
	while replay.result.is_empty():
		while i < inputs.size() and int(inputs[i][0]) == replay.steps:
			var cmd: Array = inputs[i]
			if cmd[1] == "auto":
				replay.set_auto(bool(cmd[2]))
			else:
				check(replay.press(String(cmd[1])), "повтор не принял умение " + String(cmd[1]))
			i += 1
		replay.step(LegionSim.DT)
		replay.take_events()
	check(i == inputs.size() and replay.steps == battle.sim.steps and replay.result == battle.sim.result, "итог отличается от повтора с тем же зерном")
