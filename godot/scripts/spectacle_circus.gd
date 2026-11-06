class_name CircusShow
extends RefCounted
## Скачки в цирке (Spectacle): четыре колесницы-биги в цветах римских партий — красные, белые, зелёные, синие —
## круг за кругом обходят «спину» (мраморную стенку посредине) вокруг мет. На прямых — разгон, на поворотах
## притормаживают; кто быстрее, выходит на внешнюю дорожку и обгоняет — трибуны кричат, ближние — громче. Из-под колёс
## и копыт — пыль. Возничий — человек толпы (Crowd, движение «drive»: присел, подался вперёд, вожжи в руках),
## кони — анимированные лошади Quaternius (галоп), колесница — своя, из простых деталей.
## Звуки (Spectacle.sfx): обгон, круг; гул копыт ролик берёт по расстоянию до колесниц (promo_cam: cam_log).

const TEAMS := [["russata", Color("b8392b")], ["albata", Color("ece6d6")], ["prasina", Color("3f8a4c")], ["veneta", Color("2f5e9e")]]
const A := 17.0                          # меты: центры поворотов на ±A (родные размеры цирка, CatGrand._circus)
const LANE_MIN := 1.55
const LANE_MAX := 2.75
const V_STRAIGHT := 7.2                  # м/с (городской масштаб)
const V_TURN := 4.6

var sp
var V: Dictionary
var rng := RandomNumberGenerator.new()
var k := 1.0
var floor_y := 0.0
var chariots := []
var on := false
var _dust_mat: StandardMaterial3D


func _init(s, v: Dictionary) -> void:
	sp = s
	V = v
	rng.seed = int(V["id"]) * 17 + 3
	k = Catalog.ARCH
	var h: float = V["lay"]["tris"].surface(0.0, 2.2 * k, 1.0)
	floor_y = h if h > -INF else 0.02


func phase(ph: String) -> void:
	on = ph == "show"
	if on and chariots.is_empty():
		_spawn()
	elif not on and ph != "leave":
		free_all()


func free_all() -> void:
	for c: Dictionary in chariots:
		(c["n"] as Node).queue_free()
		if c.has("drv"):
			(V["crowd"] as Crowd).remove(c["drv"])
	chariots = []


## Колесница: кузов (пол, изогнутый передок, борта) в цвете партии с золотой каймой, два колеса со спицами, дышло,
## пара коней в галопе; возничий — в толпе площадки
func _spawn() -> void:
	for i in TEAMS.size():
		var col: Color = TEAMS[i][1]
		var n := Node3D.new()
		(V["root"] as Node3D).add_child(n)
		var body := Node3D.new()
		n.add_child(body)
		var paint := _mat(col, 0.6)
		var gold := _mat(Color("d4a548"), 0.4, 0.6)
		var wood := _mat(Color("6b4a2e"), 0.85)
		_box(body, Vector3(0, 0.36, 0), Vector3(0.82, 0.05, 0.6), wood)               # пол
		_box(body, Vector3(0, 0.62, 0.3), Vector3(0.86, 0.5, 0.05), paint, -0.18)     # передок
		_box(body, Vector3(0, 0.88, 0.34), Vector3(0.88, 0.05, 0.08), gold, -0.18)   # кайма
		for sd: float in [-1.0, 1.0]:
			_box(body, Vector3(sd * 0.42, 0.55, 0.05), Vector3(0.05, 0.36, 0.52), paint)
			_box(body, Vector3(sd * 0.42, 0.74, 0.05), Vector3(0.06, 0.04, 0.54), gold)
		_box(body, Vector3(0, 0.42, 0.95), Vector3(0.06, 0.06, 1.3), wood)            # дышло
		_box(body, Vector3(0, 0.62, 1.55), Vector3(0.9, 0.05, 0.05), wood)            # ярмо
		var wheels := []
		for sd: float in [-1.0, 1.0]:
			var w := _wheel(wood, gold)
			body.add_child(w)
			w.position = Vector3(sd * 0.5, 0.33, -0.02)
			wheels.append(w)
		_merge(body)
		var horses := []
		for sd: float in [-1.0, 1.0]:
			var hs := (load("res://assets/animals/Horse_b.glb") as PackedScene).instantiate() as Node3D
			body.add_child(hs)
			var bb := Artisau.aabb(hs)
			hs.scale = Vector3.ONE * 1.45 / maxf(bb.size.z, bb.size.x)
			hs.position = Vector3(sd * 0.3, 0, 1.65)
			var ap: AnimationPlayer = hs.find_children("*", "AnimationPlayer", true, false)[0]
			var gal := "Gallop"
			for a in ap.get_animation_list():
				if String(a).ends_with("Gallop"):
					gal = a
			ap.play(gal)
			ap.get_animation(gal).loop_mode = Animation.LOOP_LINEAR
			ap.seek(rng.randf() * 0.5, true)
			horses.append(ap)
		# топот копыт (на ходу: темп — по скорости)
		var hoof := AudioStreamPlayer3D.new()
		hoof.stream = Spectacle.stream("arena/gallop.ogg", true)
		hoof.bus = "SFX"
		hoof.unit_size = 5.0
		hoof.max_distance = 70.0
		hoof.volume_db = -8.0
		body.add_child(hoof)
		hoof.play(rng.randf() * 0.3)
		# пыль из-под колёс и копыт
		var dust := _dust()
		body.add_child(dust)
		dust.position = Vector3(0, 0.1, 0.4)
		var lane := lerpf(LANE_MIN, LANE_MAX, (i + 0.5) / TEAMS.size())
		var c := {"n": n, "body": body, "wheels": wheels, "horses": horses, "dust": dust, "team": TEAMS[i][0], "hoof": hoof,
			"lane": lane * k, "lane_to": lane * k, "s": i * 4.2, "v": V_STRAIGHT * 0.8, "pace": rng.randf_range(0.94, 1.06),
			"ph": rng.randf() * TAU, "lap": 0, "yaw": 0.0}
		var lk := Citizen.roll_look(rng, false, false, false, "SK_Chr_Worker_Male_01", "plebs")
		lk["main"] = col.to_html(false)
		lk["second"] = col.lightened(0.2).to_html(false)
		lk["trim"] = "d4a548"
		c["drv"] = (V["crowd"] as Crowd).add(lk, Transform3D.IDENTITY, "drive", Crowd.now() - rng.randf() * 2.0)
		chariots.append(c)
	for c: Dictionary in chariots:
		_place(c, 0.0)


## Детали кузова (коробки) — одной сеткой: по поверхности на материал (меньше вызовов отрисовки)
func _merge(body: Node3D) -> void:
	var by_mat := {}
	for ch in body.get_children():
		if ch is MeshInstance3D:
			var mi := ch as MeshInstance3D
			var m: Material = mi.material_override
			if not by_mat.has(m):
				by_mat[m] = []
			by_mat[m].append(mi)
	var out := ArrayMesh.new()
	for m: Material in by_mat:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for mi: MeshInstance3D in by_mat[m]:
			st.append_from(mi.mesh, 0, mi.transform)
		st.set_material(m)
		st.commit(out)
		for mi: MeshInstance3D in by_mat[m]:
			body.remove_child(mi)
			mi.free()
	var one := MeshInstance3D.new()
	one.mesh = out
	body.add_child(one)


func _mat(col: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	return m


func _box(parent: Node3D, p: Vector3, sz: Vector3, m: Material, tilt := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = m
	mi.position = p
	mi.rotation.x = tilt
	parent.add_child(mi)
	return mi


## Колесо: обод, ступица, четыре спицы (вращается вокруг оси X)
func _wheel(wood: Material, gold: Material) -> Node3D:
	var w := Node3D.new()
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.27
	tm.outer_radius = 0.33
	tm.rings = 20
	tm.ring_segments = 6
	rim.mesh = tm
	rim.material_override = wood
	rim.rotation.z = PI / 2.0
	w.add_child(rim)
	for j in 4:
		var sp_mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.03, 0.56, 0.03)
		sp_mi.mesh = bm
		sp_mi.material_override = wood
		sp_mi.rotation.x = j * PI / 4.0
		w.add_child(sp_mi)
	var hub := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.06
	cm.bottom_radius = 0.06
	cm.height = 0.1
	hub.mesh = cm
	hub.material_override = gold
	hub.rotation.z = PI / 2.0
	w.add_child(hub)
	_merge(w)
	return w


func _dust() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 70
	p.lifetime = 1.8
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0.6, -1)
	pm.spread = 35.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.2
	pm.gravity = Vector3(0, 0.12, 0)
	pm.damping_min = 1.2
	pm.damping_max = 2.0
	pm.scale_min = 0.5
	pm.scale_max = 1.1
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.45, 0.05, 1.0)
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.35))
	sc.add_point(Vector2(0.4, 0.85))
	sc.add_point(Vector2(1, 1.2))
	var st := CurveTexture.new()
	st.curve = sc
	pm.scale_curve = st
	var g := Gradient.new()
	g.set_color(0, Color(0.86, 0.74, 0.55, 0.75))
	g.set_color(1, Color(0.9, 0.8, 0.62, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	if _dust_mat == null:
		_dust_mat = StandardMaterial3D.new()
		_dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_dust_mat.vertex_color_use_as_albedo = true
		_dust_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
				img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 1.6))
		_dust_mat.albedo_texture = ImageTexture.create_from_image(img)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.55, 0.55)
	qm.material = _dust_mat
	p.draw_pass_1 = qm
	return p


## Точка и направление на круге: прямые z = ∓r от −A до +A, повороты вокруг мет (±A, 0) радиусом r
func _at(s: float, r: float) -> Array:
	var a := A * k
	var P := 4.0 * a + 2.0 * PI * r
	s = fposmod(s, P)
	if s < 2.0 * a:
		return [Vector3(-a + s, floor_y, -r), Vector3(1, 0, 0)]
	s -= 2.0 * a
	if s < PI * r:
		var f := s / r
		return [Vector3(a + r * sin(f), floor_y, -r * cos(f)), Vector3(cos(f), 0, sin(f))]
	s -= PI * r
	if s < 2.0 * a:
		return [Vector3(a - s, floor_y, r), Vector3(-1, 0, 0)]
	s -= 2.0 * a
	var f2 := s / r
	return [Vector3(-a - r * sin(f2), floor_y, r * cos(f2)), Vector3(-cos(f2), 0, -sin(f2))]


func _lap_len(r: float) -> float:
	return 4.0 * A * k + 2.0 * PI * r


func _in_turn(s: float, r: float) -> float:
	var a := A * k
	var P := _lap_len(r)
	s = fposmod(s, P)
	var t1 := 2.0 * a
	var t2 := t1 + PI * r
	var t3 := t2 + 2.0 * a
	# 1 — в повороте, плавно к прямой (за 4 м до и после)
	var d := minf(minf(absf(s - t1), absf(s - t2)), minf(absf(s - t3), absf(s - P)))
	if (s > t1 and s < t2) or s > t3:
		return 1.0
	return 1.0 - smoothstep(0.0, 4.0, d)


func tick(dt: float, ph: String) -> void:
	if chariots.is_empty():
		return
	# порядок: кто впереди (круг + доля круга)
	for c: Dictionary in chariots:
		var P := _lap_len(float(c["lane"]))
		c["prog"] = float(c["s"]) / P
	for c: Dictionary in chariots:
		var r: float = c["lane"]
		var turn := _in_turn(float(c["s"]), r)
		c["ph"] = float(c["ph"]) + dt * 0.35
		var want := lerpf(V_STRAIGHT, V_TURN, turn) * float(c["pace"]) * (1.0 + 0.07 * sin(float(c["ph"])))
		# впереди кто-то медленнее на той же дорожке — выйти наружу и обогнать
		var block := false
		for o: Dictionary in chariots:
			if o == c:
				continue
			var gap := (float(o["prog"]) - float(c["prog"])) * _lap_len(r)
			if gap > 0.0 and gap < 3.4 and absf(float(o["lane"]) - r) < 0.6:
				block = true
				if float(o["v"]) < want:
					c["lane_to"] = clampf(float(o["lane"]) + 0.75 * k * (1.0 if float(o["lane"]) < LANE_MAX * k - 0.6 else -1.0), LANE_MIN * k, LANE_MAX * k)
					if not c.has("pass") and turn < 0.2:
						c["pass"] = o
		if block and turn > 0.5:
			want = minf(want, V_TURN)
		c["v"] = move_toward(float(c["v"]), want, dt * 3.0)
		# дорожка: к цели, на прямых — медленно назад к своей
		c["lane"] = move_toward(r, float(c["lane_to"]), dt * 0.55)
		if not block and turn < 0.1 and rng.randf() < dt * 0.15:
			c["lane_to"] = lerpf(LANE_MIN, LANE_MAX, rng.randf()) * k
		var P0 := _lap_len(r)
		var old_prog := float(c["s"]) / P0
		c["s"] = float(c["s"]) + float(c["v"]) * dt
		# новый круг — у ложи (середина передней прямой)
		var P1 := _lap_len(float(c["lane"]))
		c["s"] = float(c["s"]) * P1 / P0
		if floor(float(c["s"]) / P1 - 0.75) > floor(old_prog - 0.75):
			c["lap"] = int(c["lap"]) + 1
		# обогнал
		if c.has("pass"):
			var o: Dictionary = c["pass"]
			if float(c["s"]) / P1 > float(o["s"]) / _lap_len(float(o["lane"])) + 0.03:
				c.erase("pass")
				var at: Vector3 = (c["n"] as Node3D).position
				sp.sfx.emit("cheer", (V["root"] as Node3D).to_global(at + Vector3(0, 1, 0)), 0.8)
				sp.react(V, 0.4, 2.5, at)
		_place(c, dt)


func _place(c: Dictionary, dt: float) -> void:
	var e := _at(float(c["s"]), float(c["lane"]))
	var p: Vector3 = e[0]
	var d: Vector3 = e[1]
	var e2 := _at(float(c["s"]) + 0.6, float(c["lane"]))
	d = ((e2[0] as Vector3) - p).normalized()
	var yaw := atan2(d.x, d.z)
	var n: Node3D = c["n"]
	n.position = p
	n.rotation.y = yaw
	# на повороте кузов чуть кренится, колёса крутятся по скорости
	var turn := _in_turn(float(c["s"]), float(c["lane"]))
	(c["body"] as Node3D).rotation.z = -0.06 * turn
	for w: Node3D in c["wheels"]:
		w.rotation.x += float(c["v"]) * dt / 0.33
	for ap: AnimationPlayer in c["horses"]:
		ap.speed_scale = clampf(float(c["v"]) / 6.0, 0.6, 1.4)
	var hoof: AudioStreamPlayer3D = c.get("hoof")
	if hoof:
		hoof.pitch_scale = clampf(float(c["v"]) / 6.0, 0.75, 1.3)
	var drv: Dictionary = c["drv"]
	var cr: Crowd = V["crowd"]
	cr.move(drv, Transform3D(Basis(Vector3.UP, yaw), n.position + n.basis * Vector3(0, 0.38, -0.05)))
