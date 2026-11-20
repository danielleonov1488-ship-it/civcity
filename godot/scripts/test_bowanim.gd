extends Node
## Крупные планы и проверка кадра выпуска в настоящем бою.

const Actor = preload("res://scripts/charpilot_actor.gd")
const Enemy = preload("res://scripts/legion_enemy_actor.gd")
const Layer = preload("res://scripts/fort_person_layer.gd")
const Pose = preload("res://scripts/legion_ranged_pose.gd")
const View = preload("res://scripts/legion_battle_view.gd")
const WIDTH := 1920
const HEIGHT := 1080
const OUT := "D:/CivCity/.work/stage7/bowanim/shots/"

var game: Game
var battle: LegionBattle
var fails := 0
var output := OUT


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
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
	get_tree().quit(int(fails != 0))


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
	await _phases("1_bow_phases.png", "gaulArcher",
		["Стойка", "К колчану", "Стрела на тетиве", "Натяжение", "Выпуск", "После выстрела"], [-1.0, 0.22, 0.42, 0.83, 0.91, 1.06])
	await _phases("2_sling_phases.png", "slinger",
		["Стойка", "Замах", "Праща над головой", "Шаг", "Выпуск", "Возврат"], [-1.0, 0.24, 0.39, 0.77, 0.84, 1.02])
	await _phases("3_cast_phases.png", "druid",
		["Стойка", "Подъём", "Посох вверху", "Сияние", "Опускание", "Стойка"], [-1.0, 0.26, 0.52, 0.70, 0.96, 1.18])
	await _parthian()
	await _cape()
	get_viewport().disable_3d = false
	await _battle()


func _sheet() -> Layer:
	var canvas := CanvasLayer.new()
	canvas.layer = 180
	add_child(canvas)
	var paper := ColorRect.new()
	paper.color = Color("eee1ce")
	paper.size = Vector2(WIDTH, HEIGHT)
	canvas.add_child(paper)
	var layer := Layer.new()
	paper.add_child(layer)
	layer.setup("AnimationStudy", 4.0)
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
		if key == "druid" and i == 3:
			var glow := AnimatedSprite2D.new()
			glow.sprite_frames = View._effect_frames("fx_heal")
			glow.animation = &"effect"
			glow.frame = 2
			glow.position = layer.camera.unproject_position(actor.to_global(actor.ranged.launch))
			glow.scale = Vector2.ONE * 0.55
			layer.add_child(glow)
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
	_check(f._ranged_windup(0.40, 1.0, true, INF) and f.sample > 0.65, "anticipate attack cooldown")
	f.unit.target.alive = false
	_check(f._ranged_windup(0.05, 1.05, true, INF) and f.ranged_mix > 0.0 and f.ranged_mix < 1.0, "ease out of draw")
	_check(not f._ranged_windup(0.08, 1.13, true, INF) and f.aim_target == null, "cancel draw after target death")
	f.actor = null
	f.free()


func _parthian() -> void:
	var layer := _sheet()
	for i in 2:
		var actor := Enemy.new()
		layer.viewport.add_child(actor)
		if not _check(actor.build_enemy("horseArcher", 6, 0), "mounted actor " + actor.problem):
			continue
		var x := 450.0 + 1020.0 * i
		layer.place(actor, Vector2(x, 815), 440, 107)
		actor.pose_at(actor.idle if i == 0 else actor.strike, 0.82)
		_caption(layer, "В седле" if i == 0 else "Выстрел назад", x, 875)
	await get_tree().process_frame
	_save("5_parthian.png", await _capture())
	layer.get_parent().get_parent().queue_free()
	await get_tree().process_frame


func _cape() -> void:
	var layer := _sheet()
	var fixed := 0
	for i in 4:
		var actor := Actor.new()
		layer.viewport.add_child(actor)
		if not _check(actor.build(1, false, "A", {}, "legionary"), actor.problem):
			continue
		var group := actor.find_child("outfit_legionary_cape", true, false)
		var entries := Actor._kit_file("outfit_legionary_cape_m", Actor.KIT)
		for j in group.get_child_count():
			var part := group.get_child(j) as MeshInstance3D
			var rig: Skeleton3D = actor._rig
			var mesh_transform: Transform3D = entries[j]["transform"]
			var from_mesh := Citizen._rel(rig, actor).affine_inverse() * mesh_transform
			var names: PackedStringArray = entries[j]["bones"]
			if i % 2 == 0:
				part.skin = part.skin.duplicate() as Skin
				for bind in names.size():
					var name_on_rig := Actor.BONE_MAP.find_profile_bone_name(names[bind])
					var bone := rig.find_bone(name_on_rig)
					if bone >= 0:
						part.skin.set_bind_bone(bind, bone)
						part.skin.set_bind_pose(bind, rig.get_bone_global_rest(bone).affine_inverse() * from_mesh)
			else:
				for bind in part.skin.get_bind_count():
					if part.skin.get_bind_bone(bind) == rig.find_bone("UpperChest"):
						fixed += 1
		var x := 520.0 + (i % 2) * 880.0
		var y := 490.0 if i < 2 else 790.0
		layer.place(actor, Vector2(x, y), 370, 63)
		actor.pose_at("Hit_Chest" if i < 2 else "Death01", 0.11 if i < 2 else actor.clip_length("Death01") * 0.63)
		_caption(layer, ["Удар до", "Удар после", "Падение до", "Падение после"][i], x, y + (120 if i >= 2 else 24))
	_check(fixed > 0, "cape follows chest")
	await get_tree().process_frame
	_save("6_legionary_death.png", await _capture())
	layer.get_parent().get_parent().queue_free()
	await get_tree().process_frame


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
	var strips: Array[Image] = []
	var capture_after := 3.58
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
		if not field_saved and ally_draw and enemy_draw:
			_save("4_battle_archers.png", await _capture())
			field_saved = true
		if battle.sim.t >= capture_after and strips.size() < 12:
			var frame := await _capture()
			frame.resize(480, 270, Image.INTERPOLATE_LANCZOS)
			strips.append(frame)
			capture_after += 0.29
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
		var begin := Time.get_ticks_usec()
		for i in 120:
			await get_tree().process_frame
		var fps := 120000000.0 / maxf(1.0, Time.get_ticks_usec() - begin)
		var extent := battle.battle_view.people_layer.viewport.size
		print("BOWANIM FPS ×%.0f %.1f at %dx%d figures=%d" % [speed, fps, extent.x, extent.y, battle.views.size()])
		_check(fps > 60.0 and figures == 16 and battle.views.size() == 16 and extent == Vector2i(WIDTH, HEIGHT),
			"1920x1080 performance")
	_check(strips.size() == 12, "battle frame strip")
	if not strips.is_empty():
		var strip := Image.create(1920, 810, false, strips[0].get_format())
		for i in strips.size():
			strip.blit_rect(strips[i], Rect2i(0, 0, 480, 270), Vector2i(i % 4, int(floorf(float(i) / 4.0))) * Vector2i(480, 270))
		_save("7_bow_loop.png", strip)
