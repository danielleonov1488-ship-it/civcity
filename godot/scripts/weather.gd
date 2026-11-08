class_name Weather
extends Node3D
## Погода («Уютный Рим», этап 7 «большое вау»): иногда днём идёт лёгкий дождь — косые струи вокруг точки взгляда,
## мостовые и земля темнеют и блестят (land.gdshader wet), картинка чуть мягче и прохладнее (grade.gdshader rain);
## после дождя земля ещё какое-то время сохнет. Ничего в игре не меняет — только вид. Только в новой игре (City.cozy_v ≥ 1),
## на «Очень низкой» без струй. Сохранения не нужно: погода начинается заново.

const CHANCE_H := 0.05                   # вероятность начала дождя в игровой час (днём)
const LEN_H := [1.5, 4.0]                # сколько идёт, игровых часов
const DRY_H := 0.6                       # сколько сохнет после, игровых часов
const HOURS := [6.0, 21.0]
const AREA := 22.0

var game
var rain: GPUParticles3D
var level := 0.0                          # сила дождя сейчас 0…1 (плавно)
var wet := 0.0                            # мокрость земли 0…1
var left_h := 0.0                         # сколько ещё идёт, игровых часов
var _last_hour := -1
var _rng := RandomNumberGenerator.new()
var _shadow_set := false
var force := -1.0                         # проверки и снимки: ≥ 0 — дождь такой силы, не по случаю


func setup(g) -> void:
	game = g
	_rng.randomize()
	rain = _rain()
	add_child(rain)
	rain.emitting = false


func raining() -> bool:
	return left_h > 0.0 or force > 0.0


func _process(dt: float) -> void:
	if game == null or not game.ready_done or game.city == null:
		return
	var on: bool = int(game.city.cozy_v) >= 1 and game.mode != "menu"
	var h: float = game.hour
	if on and force < 0.0:
		var hi := int(floor(h))
		if hi != _last_hour:
			_last_hour = hi
			if left_h > 0.0:
				left_h = maxf(0.0, left_h - 1.0)
			elif h >= HOURS[0] and h < HOURS[1] and game.speed > 0.0 and _rng.randf() < CHANCE_H:
				left_h = _rng.randf_range(LEN_H[0], LEN_H[1])
	var want := 0.0
	if force >= 0.0:
		want = force
	elif on and left_h > 0.0:
		want = 1.0
	var spd := maxf(1.0, float(game.speed))
	level = move_toward(level, want, dt * 0.25 * spd)
	# земля мокнет быстро, сохнет медленно (DRY_H игровых часов)
	if want > 0.05 and level > 0.2:
		wet = move_toward(wet, 1.0, dt * 0.3 * spd)
	else:
		wet = move_toward(wet, 0.0, dt * spd / (DRY_H * Game.DAY_LEN / 24.0))
	var q := str(game.settings.get("quality", "high"))
	rain.emitting = level > 0.05 and q != "verylow"
	if rain.emitting:
		var at: Vector3 = game.rig.target if game.rig else Vector3.ZERO
		rain.global_position = at + Vector3(0, 14.0, 0)
		rain.amount_ratio = level * (0.5 if q == "low" else 1.0)
	if game.land_mat != null:
		game.land_mat.set_shader_parameter("wet", wet)
	if game.grade != null:
		game.grade.set_shader_parameter("rain", level)
	if game.sun != null and (level > 0.0 or _shadow_set):
		game.sun.shadow_opacity = lerpf(1.0, 0.4, level)   # под тучами тени мягче
		_shadow_set = level > 0.0


## Струи: тонкие вытянутые полоски, падают чуть наискосок; прозрачные, без теней
func _rain() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Rain"
	p.amount = 1600
	p.lifetime = 1.2
	p.preprocess = 1.2
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-AREA - 4, -20, -AREA - 4), Vector3(2 * AREA + 8, 26, 2 * AREA + 8))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(AREA, 1.0, AREA)
	pm.direction = Vector3(0.15, -1, 0.05)
	pm.spread = 2.0
	pm.initial_velocity_min = 13.0
	pm.initial_velocity_max = 15.0
	pm.gravity = Vector3(0, -2, 0)
	pm.particle_flag_align_y = true            # струя вытянута по ходу падения
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.018, 0.55)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.82, 0.86, 0.95, 0.28)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
