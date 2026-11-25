extends Node
## Крупные планы и проверка кадра выпуска в настоящем бою.

const Actor = preload("res://scripts/charpilot_actor.gd")
const Enemy = preload("res://scripts/legion_enemy_actor.gd")
const Layer = preload("res://scripts/fort_person_layer.gd")
const Pose = preload("res://scripts/legion_ranged_pose.gd")
const View = preload("res://scripts/legion_battle_view.gd")
const WIDTH := 1920
const HEIGHT := 1080
const OUT := "D:/CivCity/.work/stage7/bowanim_b/shots/"

var game: Game
var battle: LegionBattle
var fails := 0
var output := OUT


signal check_done
var embedded_output := ""


func _ready() -> void:
	if not embedded_output.is_empty():
		output = embedded_output
	for arg in OS.get_cmdline_user_args() if embedded_output.is_empty() else []:
		if arg.begins_with("out="):
			output = arg.trim_prefix("out=").trim_suffix("/") + "/"
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(WIDTH, HEIGHT)
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	game.can_save = false
	game.hero_screen_auto = false
	add_child(game)
	if await _until(func() -> bool: return game.ready_done, 150):
		game.settings["autosave"] = false
		await _run()
	else:
		_check(false, "ready_done")
	if is_instance_valid(battle):
		battle.abort()
	print("BOWANIM DONE fails=", fails)
	if embedded_output.is_empty():
		get_tree().quit(int(fails != 0))
	else:
		check_done.emit()


func _check(ok: bool, reason: String) -> bool:
	if not ok:
		fails += 1
		print("BOWANIM FAIL ", reason)
	return ok


func _until(condition: Callable, timeout: float) -> bool:
	var start := Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec() - start < timeout * 1000.0:
		await get_tree().process_frame
	return condition.call()


func _save(file: String, image: Image) -> void:
	if _check(image != null and not image.is_empty(), "read " + file):
		var path := output.path_join(file)
		if _check(image.save_png(path) == OK, "save " + file):
			print("BOWANIM SHOT ", path)


func _capture() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _run() -> void:
	if not _check(DirAccess.make_dir_recursive_absolute(output) == OK, "shot directory"):
		return
	if not _check(DisplayServer.get_name() != "headless", "graphics required"):
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	get_viewport().disable_3d = true
	await _phases("4_bow_unchanged.png", "gaulArcher",
		["Стойка", "К колчану", "Стрела на тетиве", "Натяжение", "Выпуск", "После выстрела"], [-1.0, 0.22, 0.42, 0.83, 0.91, 1.06])
	await _phases("1_sling_phases.png", "slinger",
		["Стойка", "Замах", "Праща над головой", "Шаг", "Выпуск", "Возврат"], [-1.0, 0.24, 0.39, 0.77, 0.84, 1.02])
	await _fallen_soldiers()
	get_viewport().disable_3d = false
	await _battle()


func _sheet(tilt := 4.0) -> Layer:
	var canvas := CanvasLayer.new()
	canvas.layer = 180
	add_child(canvas)
	var paper := ColorRect.new()
	paper.color = Color("eee1ce")
	paper.size = Vector2(WIDTH, HEIGHT)
	canvas.add_child(paper)
	var layer := Layer.new()
	paper.add_child(layer)
	layer.setup("AnimationStudy", tilt)
	layer.fit(paper.size)
	return layer


func _caption(layer: Layer, words: String, x: float, y: float) -> void:
	var title := Label.new()
	title.text = words
	title.add_theme_color_override("font_color", Color("4d322b"))
	title.add_theme_font_size_override("font_size", 25)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(x - 140, y)
	title.size.x = 280
	layer.add_child(title)


func _phases(file: String, key: String, labels: Array, samples: Array) -> void:
	var layer := _sheet()
	for i in samples.size():
		var actor := Enemy.new()
		layer.viewport.add_child(actor)
		if not _check(actor.build_enemy(key, 31, 0), "phase actor " + actor.problem):
			continue
		var elapsed := float(samples[i])
		var x := 360.0 + float(i % 3) * 600.0
		var y := 470.0 + floorf(float(i) / 3.0) * 490.0
		layer.place(actor, Vector2(x, y), 348, 82)
		actor.pose_at(actor.idle if elapsed < 0.0 else actor.strike, maxf(0.0, elapsed))
		_caption(layer, labels[i], x, y + 25)
		if key == "gaulArcher":
			_check(actor.ranged.arrow.visible == (elapsed >= Pose.NOCK and elapsed < 0.91), "arrow phase %d" % i)
			if i == 3:
				var string_top := actor.find_child("BowStringTop", true, false) as Node3D
				_check(string_top.scale.y > 0.55, "draw stretches string")
				var arrow := actor.ranged.arrow
				var tail := arrow.position
				var tip := arrow.transform * (Vector3.BACK * Pose.ARROW_LENGTH)
				var grip := actor.to_local(actor.ranged.bow.global_position)
				var nock := string_top.transform * (Vector3.UP * 0.5)
				_check(tail.distance_to(nock) < 0.002 and (tip - grip).dot(arrow.basis.z) > 0.0, "arrow on string and through bow")
				_cancel(actor)
		elif key == "slinger":
			_check(actor.ranged.stone.visible == (elapsed < 0.84), "stone phase %d" % i)
			_sling_check(actor.ranged, elapsed)
	await get_tree().process_frame
	_save(file, await _capture())
	layer.get_parent().get_parent().queue_free()
	await get_tree().process_frame


func _cancel(actor: Enemy) -> void:
	var f := View.Fighter.new()
	f.actor = actor
	f.unit = LegionSim.Unit.new()
	f.unit.timer = 0.19
	f.unit.range_m = 7.5
	f.unit.target = LegionSim.Unit.new()
	f.attack_clip = Pose.BOW
	f.release_time = Pose.RELEASES[Pose.BOW]
	_check(f._ranged_windup(0.40, 1.0, true, INF) and f.sample > 0.65, "anticipate attack cooldown")
	f.unit.target.alive = false
	_check(f._ranged_windup(0.05, 1.05, true, INF) and f.ranged_mix > 0.0 and f.ranged_mix < 1.0, "ease out of draw")
	_check(not f._ranged_windup(0.08, 1.13, true, INF) and f.aim_target == null, "cancel draw after target death")
	f.actor = null
	f.free()


func _sling_check(pose: Pose, elapsed: float) -> void:
	var cords := pose._cords
	_check(cords.instance_count == 2 * Pose.CORD_STEPS, "two segmented sling cords")
	for cord in 2:
		var index := cord * Pose.CORD_STEPS
		var first := cords.get_instance_transform(index)
		var last := cords.get_instance_transform(index + Pose.CORD_STEPS - 1)
		var a := first * (Vector3.DOWN * 0.5)
		var b := last * (Vector3.UP * 0.5)
		var length := 0.0
		for step in Pose.CORD_STEPS:
			var part := cords.get_instance_transform(index + step)
			var segment := part.basis.y.length()
			length += segment
			_check(segment < Pose.CORD_LENGTH * 0.5, "no long solid segment")
			if step > 0:
				var prev := cords.get_instance_transform(index + step - 1)
				_check((prev * (Vector3.UP * 0.5)).distance_to(part * (Vector3.DOWN * 0.5)) < 0.002,
					"continuous cord")
		_check(length <= (Pose.CORD_LENGTH + 0.04) * pose._height, "cord length")
		if elapsed < 0.0:
			_check(length - a.distance_to(b) > 0.020, "idle cord sags")
		if is_equal_approx(elapsed, 0.39):
			_check(length - a.distance_to(b) < 0.012 and pose._arc.visible, "taut cord and visible arc")
		if is_equal_approx(elapsed, 0.84) and cord == 1:
			var grip := pose.point("RightHand") + Vector3(0, -0.035, 0.035)
			_check(a.distance_to(grip) > 0.10, "release cord leaves fingers")
	print("BOWANIM SLING phase=%.2f two cords" % elapsed)


func _fallen_soldiers() -> void:
	var layer := _sheet(33.0)
	for i in 6:
		var column := i % 3
		var after := i >= 3
		var actor := Actor.new()
		layer.viewport.add_child(actor)
		var clip := "Death01"
		if column == 2:
			var clips := actor.build_rival_hero({"skin": "A", "cape": "a3283a"}, 63)
			clip = clips["death"]
		elif not _check(actor.build(1, column == 1, "A", {}, "centurion" if column == 1 else "legionary"), actor.problem):
			continue
		var x := 415.0 + column * 615.0
		var y := 326.0 if not after else 823.0
		layer.place(actor, Vector2(x, y), 322, 69)
		var t := actor.clip_length(clip) * 0.999
		if after:
			actor.pose_at(clip, t)
			_check_fallen(actor, str(column))
		else:
			var key := StringName(actor._clips[clip.to_lower()])
			for player: AnimationPlayer in actor._players:
				player.play(key, 0.0)
				player.seek(t, true)
		var rig_to_model := Citizen._rel(actor._rig, actor)
		var hips := rig_to_model * actor._rig.get_bone_global_pose(actor._rig.find_bone("Hips")).origin
		var feet := rig_to_model * actor._rig.get_bone_global_pose(actor._rig.find_bone("RightFoot")).origin
		var head := rig_to_model * actor._rig.get_bone_global_pose(actor._rig.find_bone("Head")).origin
		var center := layer.camera.unproject_position(actor.to_global(hips.lerp((head + feet) * 0.5, 0.8).slide(Vector3.UP)))
		layer.shadows.append(Vector3(center.x, center.y, 590))
		_caption(layer, ["Legionary", "Centurion", "Hero"][column], x - 73, y + 118)
	_caption(layer, "Before", 140, 76)
	_caption(layer, "After", 140, 554)
	layer.queue_redraw()
	await get_tree().process_frame
	_save("2_fallen_soldiers.png", await _capture())
	layer.get_parent().get_parent().queue_free()
	await get_tree().process_frame

	for king: String in ["gaulKing", "vercingetorix", "boudicca", "hannibal"]:
		var actor := Enemy.new()
		add_child(actor)
		if _check(actor.build_enemy(king, 21, 0), "build " + king):
			actor.pose_at(actor.fall, actor.clip_length(actor.fall) * 0.999)
			_check_fallen(actor, king)
			actor.pose_at(actor.idle, 0.0)
			_check(actor._enemy_shield != null and actor._enemy_shield.visible and actor._fall_shield != null and not actor._fall_shield.visible, "restore shield " + king)
		actor.queue_free()
	var kneeling := Actor.new()
	add_child(kneeling)
	if _check(kneeling.build(1, false, "A", {}, "centurion"), "kneeling centurion"):
		_check(kneeling.pose_at("Fixing_Kneeling", 0.5) and kneeling._shield.visible and kneeling._capes[0].visible, "kneeling keeps gear")
		kneeling.pose_at("Death01", kneeling.clip_length("Death01") * 0.999)
		_check_fallen(kneeling, "after kneeling")
		kneeling.pose_at("Fixing_Kneeling", 0.5)
		_check(kneeling._shield.visible and kneeling._capes[0].visible, "revived kneeling restores gear")
	kneeling.queue_free()


func _check_fallen(actor: Actor, label: String) -> void:
	var shield := actor._fall_shield
	if not _check(actor._fallen and shield != null and shield.visible, "dropped shield " + label):
		return
	var normal := Vector3.BACK if actor._enemy_shield == null else Actor.ENEMY_SHIELD_NORMAL
	var up := absf((shield.basis * normal).normalized().dot(Vector3.UP))
	var aabb := shield.transform * actor._fall_flat_to_mesh * actor._fall_bounds
	var hip := actor._fall_point(0).y
	_check(up > 0.92 and aabb.get_center().y < hip and absf(aabb.position.y - 0.012) < 0.01, "grounded shield " + label)
	var first := (actor._fall_point(4) - actor._fall_point(3)).normalized()
	var second := (actor._fall_point(5) - actor._fall_point(4)).normalized()
	_check(first.dot(second) < 0.75, "bent elbow " + label)
	var lowest := INF
	for i in actor._fall_indices.size():
		lowest = minf(lowest, actor._fall_point(i).y - float(Actor.FALL_RADIUS[i]))
	_check(absf(lowest) < 0.035, "grounded body " + label)
	for cape: Node3D in actor._capes:
		_check(not cape.visible, "cape folded out of sight " + label)
	print("BOWANIM FALL ", label, " shield_up=", up, " hip=", hip, " shield_y=", aabb.get_center().y, " ground=", lowest)


func _battle() -> void:
	var ally_sling := Legion.enemy_stats("slinger", 1.0)
	var squad := [Legion.unit_stats("archer", 5), Legion.unit_stats("archer", 5),
		Legion.unit_stats("priest", 5), Legion.unit_stats("legionary", 5), ally_sling]
	var wave := []
	for key: String in ["gaulArcher", "germArcher", "nileArcher", "slinger", "priest", "druid",
			"horseArcher", "gaul", "briton", "mercenary", "elephant"]:
		wave.append(Legion.enemy_stats(key, 1.0))
	for stat: Dictionary in squad + wave:
		stat["hp"] = float(stat["hp"]) * 18.0
	var stage := {"r": 0, "s": 0, "name": "Лучники", "boss": true}
	var setup := {"kind": "campaign", "stage": stage, "seed": 532, "squad": squad, "waves": [wave],
		"rations_paid": true, "perks": {}}
	battle = LegionBattle.open(game, setup, Callable(), {"legion": game.city.legion, "speed": 1.0})
	if not _check(await _until(func() -> bool: return battle.sim != null and battle.fade.modulate.a <= 0.01, 35), "battle started"):
		return
	var modes := {}
	for f: View.Fighter in battle.views.values():
		if f.actor != null and f.actor.ranged != null:
			var mode: String = f.actor.ranged.mode
			modes["%s/%s" % [f.unit.side, mode]] = true
			_check(f.attack_clip == f.actor.ranged.action_clip(), "attack clip " + f.unit.key)
	_check(modes.size() == 6, "both sides shoot and cast: %s" % [modes.keys()])
	print("BOWANIM ROSTER ", modes.keys())
	var figures := battle.views.size()
	var start := Time.get_ticks_usec()
	var changed_at := 0.0
	var release_counts := [{}, {}]
	var draw_counts := [{}, {}]
	var speed_index := 0
	var field_saved := false
	var horse_draw := false
	while battle.sim.t < 14.0 and Time.get_ticks_usec() - start < 16000000:
		await get_tree().process_frame
		var v := battle.battle_view
		var ally_draw := false
		var enemy_draw := false
		for f: View.Fighter in v.views.values():
			if f.actor == null or f.actor.ranged == null or f.actor.ranged.arrow == null:
				continue
			if f.actor.ranged.arrow.visible and f.sample > 0.68 and f.sample < 0.91:
				draw_counts[speed_index][f.unit.side] = true
				if f.unit.side == "ally":
					ally_draw = true
				elif f.unit.key == "horseArcher":
					horse_draw = true
				else:
					enemy_draw = true
		for s: LegionSim.Shot in v.shots:
			var sprite: Node2D = v.shots[s]
			if int(sprite.get_meta("release_frame", -1)) != Engine.get_process_frames() - 1:
				continue
			var f: View.Fighter = v.views[s.from.id]
			var expected := float(Pose.RELEASES[f.attack_clip])
			_check(is_equal_approx(f.sample, expected) and f.release_frame == int(sprite.get_meta("release_frame")),
				"sync ×%d %s" % [1 if speed_index == 0 else 3, f.unit.key])
			var at: Vector2 = sprite.get_meta("launch")
			_check(sprite.position.distance_to(at) < 0.01, "launch position " + f.unit.key)
			if f.actor.ranged.arrow != null:
				_check(not f.actor.ranged.arrow.visible, "hide arrow on release")
			if f.actor.ranged.stone != null:
				_check(not f.actor.ranged.stone.visible, "hide stone on release")
			var kind := f.unit.side + "/" + f.actor.ranged.mode
			release_counts[speed_index][kind] = int(release_counts[speed_index].get(kind, 0)) + 1
		if ally_draw and enemy_draw:
			field_saved = true
		if speed_index == 0 and battle.sim.t >= 7.0:
			speed_index = 1
			changed_at = battle.sim.t
			battle._set_speed(3.0)
	for i in 2:
		print("BOWANIM SYNC ×%d releases=%s draw=%s" % [1 if i == 0 else 3, release_counts[i], draw_counts[i]])
		_check(release_counts[i].size() == 6 and draw_counts[i].size() == 2, "both sides released and nocked")
	_check(changed_at > 0.0 and battle.sim.t >= changed_at + 4.0, "timed sequence ×3")
	_check(field_saved and horse_draw, "battle shot coverage")
	for speed: float in [1.0, 3.0]:
		battle._set_speed(speed)
		var view := battle.battle_view
		view.profile_poses = true
		view.pose_usec = 0
		view.windup_usec = 0
		Pose.profile_enabled = true
		Pose.profile_usec = 0
		Pose.profile_calls = 0
		var begin := Time.get_ticks_usec()
		for i in 120:
			await get_tree().process_frame
		var fps := 120000000.0 / maxf(1.0, Time.get_ticks_usec() - begin)
		view.profile_poses = false
		Pose.profile_enabled = false
		print("BOWANIM CPU x%.0f pose=%.4f ms ranged=%.4f ms calls/frame=%.2f state+windup=%.4f ms" % [speed, view.pose_usec / 120000.0, Pose.profile_usec / 120000.0, Pose.profile_calls / 120.0, view.windup_usec / 120000.0])
		var extent := Vector2i(battle.battle_view.size)
		print("BOWANIM FPS ×%.0f %.1f at %dx%d figures=%d" % [speed, fps, extent.x, extent.y, battle.views.size()])
		var target := 340.0 if speed == 1.0 else 300.0
		_check(fps >= target and figures == 16 and battle.views.size() == 16 and extent == Vector2i(WIDTH, HEIGHT),
			"1920x1080 performance x%.0f target %.0f" % [speed, target])
	await _battle_fall()


func _battle_fall() -> void:
	battle._set_speed(1.0)
	var fallen: View.Fighter
	for id in battle.views:
		var f: View.Fighter = battle.views[id]
		if f.unit.key == "legionary" and f.unit.side == "ally":
			fallen = f
			f.actor.set_outfit("legionary")
			# Let the next actual enemy hit finish this fighter.
			f.unit.hp = 1.0
			break
	if not _check(fallen != null, "battle death fixture"):
		return
	var ready := func() -> bool:
		return is_instance_valid(fallen) and fallen.death >= 0.49 and fallen.death <= 0.75
	if _check(await _until(ready, 12), "battle shows fallen soldier"):
		var slingers := 0
		for id in battle.views:
			var f: View.Fighter = battle.views[id]
			if f.unit.alive and f.actor != null and f.actor.visible and f.actor.ranged != null and f.actor.ranged.mode == "sling":
				slingers += 1
		_check(slingers >= 2 and fallen.actor._fall_shield.visible, "battle shows live slingers and fallen gear")
		_save("3_battle.png", await _capture())
