extends Node3D

const SHOTS := "D:/CivCity/.work/stage7/testkit15/shots/"
const HQ7_TIME := 36.0 * 3600.0

var game: Game
var legion: Legion
var factor := 1
var fails := 0


func _ready() -> void:
	if OS.get_cmdline_user_args().has("factor=20"):
		factor = 20
	check(Legion.test_time_factor == factor, "test factor from environment")
	Game.boot = {"new": "1", "nologin": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	add_child(game)
	game.can_save = false
	var deadline := Time.get_ticks_msec() + 180000
	while not game.ready_done and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if check(game.ready_done, "game ready"):
		game.hud.set_speed(0.0)
		await _check_hud()
		legion = game.city.legion
		legion.flags["camp_open"] = true
		legion.sync_v2()
		await _live_timers()
		_late_hq()
	print("TESTKIT15 DONE fails=", fails)
	get_tree().quit(0 if fails == 0 else 1)


func check(ok: bool, reason: String) -> bool:
	if not ok:
		fails += 1
		print("TESTKIT15 FAIL ", reason)
	return ok


func _check_hud() -> void:
	var hud := game.hud
	hud.apply_reveal(3)
	await get_tree().create_timer(0.65).timeout
	var badge := hud.find_child("TestTimeBadge", true, false) as Control
	check((badge != null) == (factor > 1), "test badge visibility")
	if badge != null:
		check(badge.is_visible_in_tree(), "test badge shown in city HUD")
		check((badge.get_child(0) as Label).text == I18n.t("Тест ×%d") % factor, "test badge text")
	hud._fly_rp(10)
	var fly := hud.root.get_child(-1) as Label
	if not check(fly != null and fly.text == "+10", "reward floating label"):
		return
	var bounds := Rect2(hud.root.global_position, hud.root.size)
	var renders := DisplayServer.get_name() != "headless"
	var sampled := 0
	while is_instance_valid(fly):
		check(bounds.encloses(fly.get_global_rect().grow(6.0)), "reward and outline inside viewport")
		if sampled == 8 and renders:
			await RenderingServer.frame_post_draw
			var path := SHOTS.path_join("reward_x%d.png" % factor)
			if check(get_viewport().get_texture().get_image().save_png(path) == OK, "save " + path):
				print("TESTKIT15 SHOT ", path)
		sampled += 1
		await get_tree().process_frame
	check(sampled >= 2, "reward visible over multiple frames")


func _live_timers() -> void:
	legion.flags["fort_guide"] = Legion.FortGuide.DONE
	legion.fort["money"] = 20000.0
	legion.rations = 500.0
	var recruit := legion._add_soldier({"name": "Test"})
	var barracks := legion.fort_slot_plot("barracks")
	if not check(not barracks.is_empty(), "barracks fixture"):
		return
	var sid := int(recruit["id"])
	legion.flags["fort_guide_sid"] = sid
	var hq_start := Time.get_ticks_usec()
	if not check(legion.fort_upgrade(0), "HQ 1 → 2 starts"):
		return
	var hq_timer := legion.fort_plot_timer(0)
	check(float(hq_timer.get("total", 0.0)) == 5.0, "HQ duration remains five game seconds")
	legion.flags["fort_guide"] = Legion.FortGuide.TRAIN
	var train_start := Time.get_ticks_usec()
	if not check(legion.fort_assign(int(barracks["id"]), sid), "training starts"):
		return
	check(float(recruit["train_total"]) == 4.0, "training duration remains four game seconds")
	var hq_secs := -1.0
	var train_secs := -1.0
	while (hq_secs < 0.0 or train_secs < 0.0) and Time.get_ticks_usec() - hq_start < 12000000:
		legion.army_tick()
		var stamp := Time.get_ticks_usec()
		if hq_secs < 0.0 and legion.camp_level("hq") == 2:
			hq_secs = (stamp - hq_start) / 1000000.0
		if train_secs < 0.0 and int(recruit["rank"]) == 1:
			train_secs = (stamp - train_start) / 1000000.0
		await get_tree().process_frame
	_record_time("HQ2", hq_secs, 5.0)
	_record_time("TRAIN", train_secs, 4.0)


func _record_time(timer: String, measured: float, nominal: float) -> void:
	var expected := nominal / factor
	check(measured >= expected - 0.02 and measured <= expected + 0.20, timer + " real time")
	print("TESTKIT15 %s ×%d: %.3f s (expected %.3f s)" % [timer, factor, measured, expected])


func _late_hq() -> void:
	legion.flags["fort_guide"] = Legion.FortGuide.DONE
	legion.fort_plot(0)["lv"] = 6
	legion.fort["money"] = 1800000
	legion.mats["wood"] = 765000.0
	var base := Legion.now()
	Legion.clock = base
	if not check(legion.fort_upgrade(0), "HQ 6 → 7 starts"):
		Legion.clock = -1.0
		return
	var target := base + HQ7_TIME
	var timer := legion.fort_plot_timer(0)
	check(float(timer["total"]) == HQ7_TIME and is_zero_approx(float(timer["end"]) - target), "HQ7 deadline stays in game seconds")
	var copy: Dictionary = JSON.parse_string(JSON.stringify(game._save_data()))
	var plots: Array = copy["legion"]["fort"]["plots"]
	check(absf(float(plots[0]["up"]["end"]) - target) < 0.001, "save keeps the deadline")
	var bonus := float(copy.get("legion_test_elapsed", 0.0))
	check((bonus > 0.0) == (factor > 1), "only test saves contain clock bonus")
	var no_elapsed := Legion.timer_bonus(0.0)
	var delay := HQ7_TIME / factor
	for wall_seconds: float in [delay - 1.0, delay]:
		Legion.clock = base + wall_seconds + Legion.timer_bonus(wall_seconds) - no_elapsed
		legion.fort_finish()
		check(legion.camp_level("hq") == (6 if wall_seconds < delay else 7), "HQ7 completion boundary")
	Legion.clock = -1.0
	Legion.restore_timer_clock(bonus)
	check(absf(Legion.now() - Time.get_unix_time_from_system() - bonus) < 0.1, "saved clock bonus restored")
	print("TESTKIT15 HQ7 ×%d: %.0f real s by clock (36 game hours)" % [factor, delay])
