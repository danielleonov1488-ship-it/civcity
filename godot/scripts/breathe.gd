class_name Breathe
extends Node3D
## «Город дышит» («Уютный Рим», этап 5, docs/PLAN_COZY.md): днём над травой и цветами порхают бабочки, ночью у земли
## мерцают светлячки, по небу изредка пролетает стайка птиц, на коньках крыш сидят голуби и воробьи, утром над водой стелется туман. Всё — частицы вокруг точки, куда смотрит камера
## (где игрок, там и жизнь; за краем экрана ничего не считается). На «Очень низкой» выключено, на «Низкой» — вдвое меньше.
## Картинки бабочек и птиц рисуются кодом (крылья — два кадра: взмах), без файлов.

const AREA := 12.0                       # полуширина квадрата вокруг точки взгляда, м (вблизи их и видно; дальше — мелочь)
const BUTTERFLY_H := [7.0, 18.5]         # часы бабочек
const FIREFLY_H := [20.5, 4.8]           # часы светлячков (через полночь)
const BIRD_GAP := [35.0, 70.0]           # секунд между стайками
const BIRD_H := [6.0, 19.5]
const MIST_H := [4.4, 9.0]               # утренний туман над водой: с рассвета до девяти, гуще всего в шесть-семь
const MIST_A := 0.2                      # прозрачность клубка в самый густой час

var game
var bfly: GPUParticles3D
var ffly: GPUParticles3D
var birds: GPUParticles3D
var mist: GPUParticles3D
var roof: RoofBirds                      # голуби и воробьи на коньках крыш (scripts/roof_birds.gd)
var _mist_t := 0.0
var _mist_at := Vector3.INF               # середина воды рядом с точкой взгляда (INF — воды нет)
var _bird_t := 20.0
var _q := "high"


func setup(g) -> void:
	game = g
	bfly = _butterflies()
	ffly = _fireflies()
	birds = _birds()
	mist = _mist()
	for p: GPUParticles3D in [bfly, ffly, birds, mist]:
		add_child(p)
		p.emitting = false
	roof = RoofBirds.new()
	add_child(roof)
	roof.setup(g)


func _process(dt: float) -> void:
	if game == null or not game.ready_done:
		return
	_q = str(game.settings.get("quality", "high"))
	var off: bool = _q == "verylow" or (game.mode == "menu" and not game.promo)
	var rig = game.rig
	var at := Vector3.ZERO
	if rig:
		at = rig.target
	var h: float = game.hour
	var day: bool = h >= BUTTERFLY_H[0] and h < BUTTERFLY_H[1]
	var night: bool = h >= FIREFLY_H[0] or h < FIREFLY_H[1]
	var k := 0.5 if _q == "low" else 1.0
	# бабочки и светлячки — у земли вокруг точки взгляда (высота земли — по Land)
	var gy: float = game.land.height_at(at.x, at.z) if game.land else at.y
	bfly.global_position = Vector3(at.x, gy + 0.9, at.z)
	ffly.global_position = Vector3(at.x, gy + 0.7, at.z)
	bfly.amount_ratio = k
	ffly.amount_ratio = k
	bfly.emitting = day and not off
	ffly.emitting = night and not off
	bfly.speed_scale = clampf(float(game.speed), 0.0, 2.0) if not game.promo else 1.0
	ffly.speed_scale = bfly.speed_scale
	# утренний туман: клубится над водой у точки взгляда (вода ищется раз в полторы секунды)
	_mist_t -= dt
	if _mist_t <= 0.0:
		_mist_t = 1.5
		_mist_at = _water_near(at)
	var mh: bool = h >= MIST_H[0] and h < MIST_H[1]
	mist.emitting = mh and not off and _mist_at != Vector3.INF
	if mist.emitting:
		mist.global_position = _mist_at
		var f := clampf((h - MIST_H[0]) / 1.2, 0.0, 1.0) * clampf((MIST_H[1] - h) / 1.8, 0.0, 1.0)
		var mm := (mist.draw_pass_1 as QuadMesh).material as StandardMaterial3D
		mm.albedo_color.a = MIST_A * f
		mist.amount_ratio = k
		mist.speed_scale = bfly.speed_scale
	# птицы: стайка раз в полминуты-минуту, через небо над точкой взгляда
	_bird_t -= dt * maxf(0.0, float(game.speed) if not game.promo else 1.0)
	if _bird_t <= 0.0 and not off and h >= BIRD_H[0] and h < BIRD_H[1]:
		_bird_t = randf_range(BIRD_GAP[0], BIRD_GAP[1])
		var a := randf() * TAU
		var dir := Vector3(cos(a), 0, sin(a))
		birds.global_position = Vector3(at.x, gy + randf_range(16.0, 24.0), at.z) - dir * 45.0
		var pm := birds.process_material as ParticleProcessMaterial
		pm.direction = dir
		birds.restart()
		birds.emitting = true


## Квадратик с картинкой и анимацией кадров (крылья); billboard — к камере
func _quad_mat(tex: Texture2D, frames: int, emit := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR if not emit else BaseMaterial3D.TRANSPARENCY_ALPHA
	m.alpha_scissor_threshold = 0.4
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true              # без этого частица рисуется метровой, scale_min/max не действуют
	m.particles_anim_h_frames = frames
	m.particles_anim_v_frames = 1
	m.particles_anim_loop = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m


## Бабочка: два кадра — крылья раскрыты и сложены; крылья жёлто-оранжевые с тёмной каймой и светлым пятнышком,
## у каждой бабочки свой оттенок (hue_variation)
func _butterfly_tex() -> ImageTexture:
	var S := 48
	var img := Image.create(S * 2, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var wing := Color("f0b23a")
	var rim := Color("3a2414")
	for f in 2:
		var spread := 1.0 if f == 0 else 0.3
		for y in S:
			for x in S:
				var dx := (x - S / 2.0 + 0.5) / (S / 2.0)
				var dy := (y - S / 2.0 + 0.5) / (S / 2.0)
				var ax := absf(dx) / spread
				var col := Color(0, 0, 0, 0)
				# верхнее крыло (больше) и нижнее; e — где внутри: 0 — середина, 1 — край
				var eu := pow((ax - 0.5) / 0.48, 2) + pow((dy + 0.22) / 0.42, 2)
				var el := pow((ax - 0.32) / 0.3, 2) + pow((dy - 0.38) / 0.3, 2)
				var e := minf(eu, el)
				if e < 1.0 and ax > 0.04:
					col = rim if e > 0.62 else wing
					if eu < 0.12 and dy < -0.2:
						col = Color("fff6dc")            # светлое пятнышко на верхнем крыле
				if absf(dx) < 0.05 and dy > -0.55 and dy < 0.6:
					col = Color("2a1a10")                # тельце
				if col.a > 0.0:
					img.set_pixel(f * S + x, y, col)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _butterflies() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Butterflies"
	p.amount = 48
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-AREA - 4, -3, -AREA - 4), Vector3(2 * AREA + 8, 8, 2 * AREA + 8))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(AREA, 0.5, AREA)
	pm.direction = Vector3(1, 0, 0)
	pm.spread = 180.0
	pm.flatness = 1.0                          # летят над землёй, не вверх (иначе ветер уносил их к камере)
	pm.initial_velocity_min = 0.35
	pm.initial_velocity_max = 0.7
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.35
	pm.turbulence_noise_scale = 3.0
	pm.turbulence_influence_min = 0.12
	pm.turbulence_influence_max = 0.25
	pm.scale_min = 0.24                        # крупнее настоящих — иначе сверху их не разглядеть (жители 0,61 м)
	pm.scale_max = 0.32
	pm.anim_speed_min = 7.0
	pm.anim_speed_max = 10.0
	pm.hue_variation_min = -0.1                # от красноватых до лимонных — у каждой свой оттенок
	pm.hue_variation_max = 0.08
	var fade := Gradient.new()                 # появляются и исчезают плавно
	fade.offsets = PackedFloat32Array([0.0, 0.1, 0.9, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var ft := GradientTexture1D.new()
	ft.gradient = fade
	pm.color_ramp = ft
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = _quad_mat(_butterfly_tex(), 2)
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _fireflies() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Fireflies"
	p.amount = 110
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-AREA - 4, -3, -AREA - 4), Vector3(2 * AREA + 8, 8, 2 * AREA + 8))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(AREA, 0.5, AREA)
	pm.spread = 180.0
	pm.flatness = 0.8
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.2
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.25
	pm.turbulence_influence_min = 0.1
	pm.turbulence_influence_max = 0.2
	pm.turbulence_noise_scale = 2.0
	pm.scale_min = 0.2
	pm.scale_max = 0.3
	var blink := Gradient.new()                # мерцают: загораются и гаснут
	blink.offsets = PackedFloat32Array([0.0, 0.2, 0.35, 0.5, 0.7, 1.0])
	blink.colors = PackedColorArray([Color(1, 1, 0.4, 0), Color(1.8, 2.6, 0.35, 1), Color(1, 1, 0.4, 0.15), Color(1.8, 2.6, 0.35, 1), Color(1, 1, 0.4, 0.2), Color(1, 1, 0.4, 0)])
	var bt := GradientTexture1D.new()
	bt.use_hdr = true                          # яркость выше 1 — светятся (и цепляют свечение экрана)
	bt.gradient = blink
	pm.color_ramp = bt
	p.process_material = pm
	var q: QuadMesh = (Game._puff_quad() as QuadMesh).duplicate()
	var m := (q.material as StandardMaterial3D).duplicate() as StandardMaterial3D
	m.billboard_keep_scale = true
	m.emission_enabled = true
	m.emission = Color(0.9, 1.0, 0.45)
	m.emission_energy_multiplier = 3.0
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## Птица: силуэт «галочкой», два кадра — крылья вверх и вниз
func _bird_tex() -> ImageTexture:
	var W := 32
	var H := 16
	var img := Image.create(W * 2, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for f in 2:
		var lift := -5.0 if f == 0 else 3.0
		for x in W:
			var dx := absf(x - W / 2.0 + 0.5) / (W / 2.0)
			var y := H / 2.0 + lift * dx * (1.6 - dx) - (0.0 if f == 0 else 1.0)
			for t in range(-1, 2):
				var yy := int(round(y)) + t
				if yy >= 0 and yy < H and (absf(float(t)) < 1.0 or dx < 0.75):
					img.set_pixel(f * W + x, yy, Color(0.16, 0.14, 0.13))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _birds() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Birds"
	p.amount = 9
	p.lifetime = 16.0
	p.one_shot = true
	p.explosiveness = 0.85
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-120, -20, -120), Vector3(240, 40, 240))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(3.0, 1.0, 3.0)
	pm.direction = Vector3(1, 0, 0)
	pm.spread = 6.0
	pm.initial_velocity_min = 5.5
	pm.initial_velocity_max = 6.5
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.9
	pm.scale_max = 1.2
	pm.anim_speed_min = 4.0
	pm.anim_speed_max = 6.0
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 0.5)
	q.material = _quad_mat(_bird_tex(), 2)
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## Середина воды у точки взгляда: клетки 5 м в квадрате 40 × 40 м; меньше трёх водных — воды нет (INF)
func _water_near(at: Vector3) -> Vector3:
	if game.land == null:
		return Vector3.INF
	var sum := Vector2.ZERO
	var n := 0
	for i in range(-4, 5):
		for j in range(-4, 5):
			var p := Vector2(at.x + i * 5.0, at.z + j * 5.0)
			if game.land.is_water(p):
				sum += p
				n += 1
	if n < 3:
		return Vector3.INF
	var c := sum / n
	return Vector3(c.x, Land.WATER_Y + 0.3, c.y)


## Туман: большие мягкие клубки над водой, медленно плывут и тают; прозрачность — по часу (_process)
func _mist() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Mist"
	p.amount = 70
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-40, -4, -40), Vector3(80, 10, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(13.0, 0.18, 13.0)
	pm.direction = Vector3(1, 0, 0.35)
	pm.spread = 40.0
	pm.flatness = 1.0
	pm.initial_velocity_min = 0.12
	pm.initial_velocity_max = 0.35
	pm.gravity = Vector3.ZERO
	pm.scale_min = 6.0
	pm.scale_max = 10.0
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	var ft := GradientTexture1D.new()
	ft.gradient = fade
	pm.color_ramp = ft
	p.process_material = pm
	pm.angle_min = 0.0                          # плоские пласты лежат над водой под разными углами
	pm.angle_max = 360.0
	pm.particle_flag_rotate_y = true
	var q: QuadMesh = (Game._puff_quad() as QuadMesh).duplicate()
	q.orientation = PlaneMesh.FACE_Y            # плоско над водой: не врезается в неё прямой кромкой
	var m := (q.material as StandardMaterial3D).duplicate() as StandardMaterial3D
	m.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.93, 0.95, 1.0, MIST_A)
	m.vertex_color_use_as_albedo = true
	m.proximity_fade_enabled = true             # мягко входит в воду и берег, без резкой кромки
	m.proximity_fade_distance = 1.2
	m.no_depth_test = false
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
