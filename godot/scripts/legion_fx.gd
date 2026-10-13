class_name LegionFx
extends Node3D
## Частицы и вспышки 3D-боя Легиона: пыль от шагов и ударов, искры, огонь ожога, зелёные искры лечения,
## расходящиеся круги ударов, котёл кипящего масла, дождь стрел «Залпа», круги «Черепахи» и «Боевого рога».
## Частицы считаются на процессоре и рисуются двумя пачками (MultiMesh): мягкие и светящиеся.
## Время эффектов идёт вместе со скоростью боя (tick(dt) получает уже ускоренное время).

const MAX := 900

var _soft: MultiMeshInstance3D
var _glow: MultiMeshInstance3D
var _parts: Array = []                  # [pos, vel, grav, size, grow, life, t, color, glow]
var _rings: Array = []                  # {n, t, life, r0, r1, c}
var _items: Array = []                  # котлы, стрелы залпа
var _ring_mat: Dictionary = {}

static var _ring_tex: Texture2D
static var _shot_mats := {}


func _ready() -> void:
	_soft = _pack(false)
	_glow = _pack(true)


func _pack(glow: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = LegionField.soft_tex()
	m.disable_receive_shadows = true
	if glow:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	q.material = m
	mm.mesh = q
	mm.instance_count = MAX
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-60, -10, -60), Vector3(120, 40, 120))
	add_child(mi)
	return mi


## Одна частица
func add(pos: Vector3, vel: Vector3, color: Color, size := 0.2, life := 0.8, grav := 0.0, grow := 0.0, glow := false) -> void:
	if _parts.size() >= MAX * 2:
		return
	_parts.append([pos, vel, grav, size, grow, life, 0.0, color, glow])


## Облачко частиц из точки: n штук, разлёт spread (м/с), вверх up (м/с)
func burst(pos: Vector3, color: Color, n: int, spread := 1.2, up := 1.2, size := 0.2, life := 0.7, glow := false, grav := 3.0, grow := 0.6) -> void:
	for i in n:
		var a := randf() * TAU
		var r := randf() * spread
		var v := Vector3(cos(a) * r, up * randf_range(0.4, 1.0), sin(a) * r * 0.6)
		var c := color
		c.a *= randf_range(0.6, 1.0)
		add(pos + Vector3(randf_range(-0.15, 0.15), randf_range(0.0, 0.2), randf_range(-0.15, 0.15)), v, c, size * randf_range(0.7, 1.3), life * randf_range(0.7, 1.2), grav, grow, glow)


## Пыль из-под ног / от удара о землю
func dust(pos: Vector3, k := 1.0) -> void:
	burst(pos + Vector3(0, 0.05, 0), Color(0.82, 0.74, 0.6, 0.4), int(6 * k), 0.9 * k, 0.6, 0.32 * k, 0.9, false, -0.2, 1.3)


## Искры удара металла
func sparks(pos: Vector3) -> void:
	burst(pos, Color(1.0, 0.82, 0.45, 1.0), 6, 2.2, 1.8, 0.07, 0.3, true, 6.0, -0.5)


## Расходящийся круг на земле (удар великана, взрыв камня, рог)
func ring(pos: Vector3, radius: float, color: Color, life := 0.6, width := 1.0) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = ring_tex()
	m.albedo_color = color
	m.disable_receive_shadows = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3(0, 0.06, 0)
	add_child(mi)
	_rings.append({"n": mi, "t": 0.0, "life": life, "r0": radius * 0.25, "r1": radius * 1.2 * width, "c": color})


## Постоянный круг под бойцом («Черепаха», «Рог»): вернуть узел, бой двигает его сам
func status_ring(color: Color, radius := 0.55) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(radius * 2.0, radius * 2.0)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var key := color.to_html()
	if not _ring_mat.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = ring_tex()
		m.albedo_color = color
		m.disable_receive_shadows = true
		_ring_mat[key] = m
	mi.material_override = _ring_mat[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


static func ring_tex() -> Texture2D:
	if _ring_tex == null:
		var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
		for y in 128:
			for x in 128:
				var d := Vector2(x - 63.5, y - 63.5).length() / 63.5
				var a := clampf(1.0 - absf(d - 0.84) / 0.13, 0.0, 1.0)
				a = a * a * (3.0 - 2.0 * a)
				a += clampf(1.0 - d, 0.0, 1.0) * 0.12 * float(d < 0.84)
				img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
		img.generate_mipmaps()
		_ring_tex = ImageTexture.create_from_image(img)
	return _ring_tex


## Котёл кипящего масла над точкой: появляется, опрокидывается, золотое масло льётся вниз, всплеск и пар
func cauldron(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = LegionFighter._kit_mesh("#cauldron")
	mi.position = pos + Vector3(0, 4.6, 0)
	mi.scale = Vector3.ONE * 0.9
	add_child(mi)
	_items.append({"kind": "pot", "n": mi, "t": 0.0, "life": 1.7, "pos": pos})


## Дождь стрел на точки targets (из-за спины отряда, по высокой дуге)
func volley(targets: Array) -> void:
	for p: Vector3 in targets:
		for i in 3:
			var a := MeshInstance3D.new()
			a.mesh = LegionFighter._kit_mesh("#arrow")
			a.visible = false
			add_child(a)
			var from := Vector3(-17.0 - randf() * 4.0, 1.5, p.z + randf_range(-0.6, 0.6))
			var to := p + Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.3, 0.3))
			_items.append({"kind": "arrow", "n": a, "t": -randf() * 0.45, "life": 0.95, "from": from, "to": to, "arc": 5.5})


func tick(dt: float) -> void:
	# частицы
	var keep: Array = []
	var ns := 0
	var ng := 0
	var mms := _soft.multimesh
	var mmg := _glow.multimesh
	for p: Array in _parts:
		p[6] += dt
		if p[6] >= p[5]:
			continue
		var v: Vector3 = p[1]
		v.y -= float(p[2]) * dt
		v *= 1.0 - minf(1.0, dt * 1.2)
		p[1] = v
		p[0] = (p[0] as Vector3) + v * dt
		keep.append(p)
		var k: float = float(p[6]) / float(p[5])
		var s: float = float(p[3]) * maxf(0.05, 1.0 + float(p[4]) * k)
		var c: Color = p[7]
		c.a *= (1.0 - k) * minf(1.0, k * 8.0 + 0.3)
		var xf := Transform3D(Basis.from_scale(Vector3(s, s, s)), p[0])
		if bool(p[8]):
			if ng < MAX:
				mmg.set_instance_transform(ng, xf)
				mmg.set_instance_color(ng, c)
				ng += 1
		elif ns < MAX:
			mms.set_instance_transform(ns, xf)
			mms.set_instance_color(ns, c)
			ns += 1
	_parts = keep
	mms.visible_instance_count = ns
	mmg.visible_instance_count = ng
	# круги
	var kr: Array = []
	for r: Dictionary in _rings:
		r["t"] += dt
		var k: float = float(r["t"]) / float(r["life"])
		var n: MeshInstance3D = r["n"]
		if k >= 1.0:
			n.queue_free()
			continue
		var rad := lerpf(float(r["r0"]), float(r["r1"]), ease(k, 0.4))
		n.scale = Vector3(rad, 1.0, rad)
		var c: Color = r["c"]
		(n.material_override as StandardMaterial3D).albedo_color = Color(c.r, c.g, c.b, c.a * (1.0 - k))
		kr.append(r)
	_rings = kr
	# котлы и стрелы
	var ki: Array = []
	for it: Dictionary in _items:
		it["t"] += dt
		var t: float = it["t"]
		var n: Node3D = it["n"]
		if it["kind"] == "pot":
			var pos: Vector3 = it["pos"]
			n.rotation.z = minf(2.1, maxf(0.0, t - 0.25) * 3.2)
			n.position.y = pos.y + 4.6 + sin(minf(t, 0.25) / 0.25 * PI * 0.5) * 0.25
			if t > 0.45 and t < 1.25:
				for i in 4:
					add(n.position + Vector3(0.55 + randf_range(-0.15, 0.15), -0.1, randf_range(-0.3, 0.3)),
						Vector3(randf_range(-0.4, 0.4), -2.0, randf_range(-0.3, 0.3)), Color(1.0, 0.72, 0.22, 0.95) if randf() < 0.6 else Color(1.0, 0.88, 0.4, 0.95),
						0.16, 0.75, 9.0, 0.6, true)
			if t > 0.8 and t < 0.84 + dt:
				burst(pos + Vector3(0.6, 0.1, 0), Color(1.0, 0.7, 0.25, 0.9), 22, 2.6, 1.6, 0.18, 0.7, true, 5.0)
				ring(pos + Vector3(0.6, 0, 0), 2.2, Color(1.0, 0.75, 0.3, 0.8), 0.7)
			if t > 0.9 and t < 1.6 and randf() < 0.6:
				add(pos + Vector3(randf_range(-1.6, 2.2), 0.2, randf_range(-1.2, 1.2)), Vector3(0, 0.9, 0), Color(0.95, 0.93, 0.9, 0.35), 0.5, 1.4, -0.2, 1.6)
			if t > float(it["life"]):
				n.queue_free()
				continue
		else:
			if t < 0.0:
				ki.append(it)
				continue
			n.visible = true
			var k := minf(1.0, t / float(it["life"]))
			var p0 := _arc(it, k)
			var p1 := _arc(it, minf(1.0, k + 0.03))
			n.position = p0
			if p1.distance_squared_to(p0) > 1e-6:
				n.look_at(p1, Vector3.UP)
			if k >= 1.0:
				dust(it["to"], 0.4)
				n.queue_free()
				continue
		ki.append(it)
	_items = ki


static func _arc(it: Dictionary, k: float) -> Vector3:
	var a: Vector3 = it["from"]
	var b: Vector3 = it["to"]
	var p := a.lerp(b, k)
	p.y += sin(k * PI) * float(it["arc"])
	return p


## Сетка снаряда по виду (стрела, камень пращи, болт, камень онагра, валун циклопа)
static func shot_mesh(kind: String) -> Mesh:
	match kind:
		"arrow":
			return LegionFighter._kit_mesh("#arrow")
		"bolt":
			return LegionFighter._kit_mesh("#bolt")
		"stone":
			return LegionFighter._kit_mesh("#rock")
		"boulder":
			return LegionFighter._kit_mesh("#rock_big")
	return LegionFighter._kit_mesh("#pebble")
