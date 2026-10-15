extends Node
## Проверка 3D-боя Легиона без города: открывает бой похода и снимает кадры.
##   console.exe --path godot res://test_battle.tscn -- region=0 stage=2 cycle=0 lvl=+0 squad=auto perks=bosses auto=0 speed=1
##     shots=3,9,20 result=1 tag=forest out=D:/CivCity/.work/legion_battle quality=high perk_at=6:oil,10:volley
## lvl — уровень бойцов: число или +N/−N к рекомендованному; squad — "auto" или список родов через запятую;
## perks — none | bosses (как у игрока на этом месте похода) | all; shots — секунды боя для кадров; result=1 — кадр итога;
## perk_at — нажать умение в секунду боя; pvp=1 — бой с городом (отряд обороны — такой же отряд);
## retreat_at=с — спросить «Отступить?» (кадр) и отступить; pause_at=с — пауза (кадр); game=1 — бой из готового города;
## next=1 — после победы нажать «Дальше» и снять следующий бой (next_shot=с); close=1 — после итога «В лагерь».
## auto=1 — «Авто» с начала (проверке можно и в непройденном бою: auto_any); hover_auto=с — навести мышь на «Авто» (кадр
## с подсказкой). Учебный бой — region=0 stage=0 (первый бой, масло ещё не жали): кадр, когда бой замер со стрелкой
## на масле (…_tut_freeze), потом «нажимает» масло и снимает …_tut_after; печатает TUT freeze/press.
## Печатает средний FPS, итог боя и куда сохранены кадры. Запускать только через .work/py/gpu_run.sh (замок видеокарты).

var args := {}
var battle: LegionBattle
var legion: Legion
var shots := []
var shot_i := 0
var out_dir := "D:/CivCity/.work/legion_battle"
var tag := "battle"
var done_t := -1.0
var t := 0.0
var fps_log := []
var perk_at := []
var finished := false


var game
var integ := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	out_dir = args.get("out", out_dir)
	tag = args.get("tag", tag)
	DirAccess.make_dir_recursive_absolute(out_dir)
	if args.has("game"):
		_integ()
		return
	for s in String(args.get("shots", "4,12")).split(",", false):
		shots.append(float(s))
	for p in String(args.get("perk_at", "")).split(",", false):
		var kv := p.split(":")
		perk_at.append([float(kv[0]), kv[1]])
	var c := int(args.get("cycle", "0"))
	var r := int(args.get("region", "0"))
	var s := int(args.get("stage", "0"))
	legion = Legion.new()
	legion.free_mode = true
	legion.progress = Legion.stage_index(c, r, s)
	var lv_arg: String = args.get("lvl", "+0")
	var lvl := Legion.target_level(c, r, s)
	if lv_arg.begins_with("+") or lv_arg.begins_with("-"):
		lvl += int(lv_arg)
	else:
		lvl = int(lv_arg)
	for k in Legion.UNIT_IDS:
		legion.levels[k] = clampi(lvl, 1, Legion.MAX_LEVEL)
	var pk: String = args.get("perks", "bosses")
	for id in Legion.PERK_IDS:
		var need := int(Legion.PERKS[id]["boss"])
		if pk == "all" or (pk == "bosses" and legion.bosses() >= need):
			legion.perks[id] = maxi(1, mini(Legion.PERK_MAX, 1 + legion.bosses() / 3))
	var sq: String = args.get("squad", "auto")
	if sq == "auto":
		legion.use_auto_squad()
	else:
		legion.squad = Array(sq.split(","))
	var setup: Dictionary
	if args.has("pvp"):
		var snap := legion.defense_snapshot()
		setup = legion.make_pvp_battle({"name": "Тускулум", "rating": 240, "city_level": 5, "snapshot": snap}, int(args.get("seed", "7")))
	else:
		var st := legion.stage_info(c, r, s)
		setup = legion.make_battle(st, int(args.get("seed", "7")))
	print("BATTLE ", "pvp" if args.has("pvp") else "%d-%d-%d" % [c, r, s], " lvl=", lvl, " squad=", legion.squad_stats().map(func(x): return x["key"]), " perks=", legion.open_perks())
	print("BATTLE tutorial=", setup.get("tutorial", ""), " packs=", setup.get("packs", []))
	battle = LegionBattle.open(self, setup, _on_done, {"legion": legion, "speed": float(args.get("speed", "1")), "auto": args.get("auto", "0") == "1",
		"auto_any": args.get("auto", "0") == "1",
		"quality": args.get("quality", "high"), "zoom": float(args.get("zoom", "1"))}.merged({"cam_x": float(args["cam_x"])} if args.has("cam_x") else {}))
	battle.finished.connect(func(o: Dictionary) -> void:
		print("RESULT win=", o.get("win"), " alive=", o.get("alive"), "/", o.get("total"), " time=", snappedf(float(o.get("time", 0)), 0.1),
			" stars=", o.get("stars"), " reward=", o.get("reward"), " unlocks=", o.get("unlocks"), " delta=", o.get("delta", "")))


func _on_done(o: Dictionary) -> void:
	finished = true


## Вместе с городом (готовый город --demo, не сохраняется): окно «Легион» просит бой → бой открывается поверх города,
## город прячется и встаёт на паузу; после «В лагерь» всё возвращается. Проверяет, что вернулось, и снимает кадры
func _integ() -> void:
	integ = true
	Game.boot = {"demo": "1", "hour": "10.5"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	while not game.ready_done:
		await get_tree().process_frame
	for i in 30:
		await get_tree().process_frame
	_shot_plain(tag + "_city_before")
	legion = game.city.legion
	legion.free_mode = true
	var r := int(args.get("region", "0"))
	var s := int(args.get("stage", "2"))
	legion.progress = Legion.stage_index(0, r, s)
	for k in Legion.UNIT_IDS:
		legion.levels[k] = Legion.target_level(0, r, s) + 1
	legion.use_auto_squad()
	var speed0: float = game.speed
	var money0: float = game.city.money
	var st := legion.stage_info(0, r, s)
	print("INTEG can_fight='", legion.can_fight(st), "' speed0=", speed0, " money0=", money0)
	var closed := []
	legion.battle_closed.connect(func(o): closed.append(o))
	legion.start_battle(st)
	await get_tree().process_frame
	battle = LegionBattle.current
	print("INTEG battle_open=", battle != null, " disable_3d=", get_viewport().disable_3d, " hud_visible=", game.hud.visible, " city_speed=", game.speed)
	battle.finished.connect(func(o: Dictionary) -> void:
		print("RESULT win=", o.get("win"), " alive=", o.get("alive"), "/", o.get("total"), " reward=", o.get("reward")))
	while battle.phase != "result":
		await get_tree().process_frame
		if battle.sim and battle.sim.t > 6.0 and shot_i == 0:
			_shot(tag + "_in_city_battle")
			shot_i = 1
	for i in 60:
		await get_tree().process_frame
	_shot(tag + "_in_city_result")
	battle._close()
	for i in 90:
		await get_tree().process_frame
	_shot_plain(tag + "_city_after")
	print("INTEG closed_signal=", closed.size(), " battle_alive=", is_instance_valid(battle), " disable_3d=", get_viewport().disable_3d,
		" hud_visible=", game.hud.visible, " city_speed=", game.speed, " money_delta=", game.city.money - money0, " rig_cine=", game.rig.cine,
		" current=", LegionBattle.current)
	get_tree().quit()


func _shot_plain(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var p := out_dir + "/" + name + ".png"
	img.save_png(p)
	print("SHOT ", p, " fps=", Engine.get_frames_per_second())


func _process(dt: float) -> void:
	if integ:
		return
	t += dt
	if battle == null or not is_instance_valid(battle) or battle.sim == null:
		if args.has("curtain") and battle != null and is_instance_valid(battle) and battle.fade != null and t > 0.05:
			_shot(tag + "_curtain")
			args.erase("curtain")
		if t > 3.0 and finished:
			_quit()
		return
	if not args.has("_built"):
		args["_built"] = "1"
		print("BUILD ", int(t * 1000.0), " ms (от открытия до первого кадра боя)")
	var st: float = battle.sim.t
	if int(t) != int(t - dt) and battle.fps_avg > 0.0:
		fps_log.append(battle.fps_avg)
	# учебный бой: бой замер — кадр со стрелкой, потом масло
	if battle.tut_freeze and not args.has("_tut_t"):
		args["_tut_t"] = str(t)
		var foes := 0
		for u in battle.sim.units:
			if u.side == "enemy" and u.alive and u.wave == battle.sim.wave_idx:
				foes += 1
		print("TUT freeze at ", snappedf(st, 0.1), " s: wave ", battle.sim.wave_idx + 1, ", foes ", foes, ", oil ready ", battle.sim.perk_ready("oil"),
			", speed ", battle.speed, ", auto_btn visible ", battle.auto_btn.visible, ", hint «", battle.hint_lbl.text, "»")
	if args.has("_tut_t") and not args.has("_tut_shot") and t - float(args["_tut_t"]) > 1.2:
		args["_tut_shot"] = "1"
		var st0: float = battle.sim.t
		_shot(tag + "_tut_freeze")
		print("TUT still frozen: ", battle.tut_freeze and is_equal_approx(battle.sim.t, st0), " arrow ", battle.tut_arrow.visible)
		var alive0 := battle.sim.alive_of("enemy").size()
		battle.use_perk("oil")
		print("TUT press: freeze ", battle.tut_freeze, ", flags.tut_oil ", legion.flags.get("tut_oil", false), ", foes alive ", alive0, " → ", battle.sim.alive_of("enemy").size(),
			", hint «", battle.hint_lbl.text, "»")
		args["_tut_after"] = str(t + 1.4)
	if args.has("_tut_after") and t >= float(args["_tut_after"]):
		args.erase("_tut_after")
		_shot(tag + "_tut_after")
	if args.has("hover_auto") and st >= float(args["hover_auto"]):
		args.erase("hover_auto")
		var ab: Control = battle.auto_btn
		var c := ab.get_viewport().get_final_transform() * (ab.get_global_transform_with_canvas() * (ab.size / 2.0))
		var m := InputEventMouseMotion.new()
		m.position = c
		m.global_position = c
		Input.parse_input_event(m)
		args["hover_shot"] = str(t + 1.6)
		print("AUTO disabled=", battle.auto_btn.disabled, " pressed=", battle.auto_btn.button_pressed, " sim auto=", battle.sim.auto["ally"], " tip «", battle.auto_btn.tooltip_text, "»")
	if args.has("hover_shot") and t >= float(args["hover_shot"]):
		args.erase("hover_shot")
		_shot(tag + "_auto_off")
	for p: Array in perk_at:
		if p[0] >= 0.0 and st >= float(p[0]):
			battle.use_perk(String(p[1]))
			p[0] = -1.0
	if args.has("retreat_at") and st >= float(args["retreat_at"]) and battle.modal == null and battle.phase == "fight":
		battle._ask_retreat()
		args["retreat_shot"] = str(t + 0.6)
		args.erase("retreat_at")
	if args.has("retreat_shot") and t >= float(args["retreat_shot"]):
		_shot(tag + "_retreat_ask")
		args.erase("retreat_shot")
		battle._retreat()
	if args.has("pause_at") and st >= float(args["pause_at"]) and not battle.paused:
		battle._toggle_pause()
		args["pause_shot"] = str(t + 0.5)
		args.erase("pause_at")
	if args.has("pause_shot") and t >= float(args["pause_shot"]):
		_shot(tag + "_paused")
		args.erase("pause_shot")
		battle._toggle_pause()
	if shot_i < shots.size() and st >= float(shots[shot_i]) and battle.phase != "result":
		_shot("%s_%02d" % [tag, int(shots[shot_i])])
		shot_i += 1
	if battle.phase == "result":
		if done_t < 0.0:
			done_t = t
		if t - done_t > 1.2 and args.get("result", "1") == "1":
			_shot(tag + "_result")
			args["result"] = "0"
			if args.has("next") and not (battle.out.get("next", {}) as Dictionary).is_empty():
				# «Дальше»: следующий бой без выхода в город
				args.erase("next")
				battle._again(battle.out["next"])
				done_t = -1.0
				shots = [float(args.get("next_shot", "4"))]
				shot_i = 0
				tag += "_next"
				args["result"] = "1"
			elif args.has("close"):
				battle._close()
			else:
				_quit()
	if t > float(args.get("timeout", "240")):
		print("TIMEOUT")
		_quit()


func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var p := out_dir + "/" + name + ".png"
	img.save_png(p)
	print("SHOT ", p, " fps=", snappedf(battle.fps_avg, 0.1), " units=", battle.views.size(), " shots=", battle.shots.size())


func _quit() -> void:
	var avg := 0.0
	var mn := 999.0
	for f: float in fps_log:
		avg += f
		mn = minf(mn, f)
	if not fps_log.is_empty():
		avg /= fps_log.size()
	print("FPS avg=", snappedf(avg, 0.1), " min=", snappedf(mn, 0.1), " samples=", fps_log.size())
	if battle != null and is_instance_valid(battle):
		battle.abort()
	get_tree().quit()
