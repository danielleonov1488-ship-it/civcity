class_name RoofBirds
extends Node3D
## Птицы на крышах («Уютный Рим», этап 5 «город дышит», docs/PLAN_COZY.md): днём на коньках крыш у точки взгляда
## сидят голуби и воробьи — поклёвывают, крутят головой; время от времени один вспархивает и улетает, другой садится.
## Места — пересечение луча с сеткой кровли; без найденной поверхности птицы не садятся.
## Все сидящие — одна MultiMesh (дёшево); летящий — отдельный маленький узел на пару секунд.
## На «Очень низкой» выключено, на «Низкой» — вдвое меньше. Ночью птиц нет.

const HOURS := [6.0, 19.5]
const NEAR := 34.0                       # постройки ближе этого к точке взгляда, м
## 15.11 (отзыв владельца: «птицы на крышах — баг, летают сквозь дома»): птиц втрое меньше, на крыше — одна; сидят только
## на коньках кровли (не на навершиях и деталях), а взлетают и садятся сверху — сперва вверх выше всех крыш вокруг, потом
## в сторону, садятся отвесно на конёк
const MAX_BIRDS := 6
const PER_ROOF := 1
const CLEAR := 3.0                       # м над самой высокой крышей рядом — высота полёта
const CLEAR_R := 26.0                    # м — какие постройки считать «рядом» с местом посадки
const SKIP_PARTS := ["Topper", "Trellis", "Detail", "Trim", "End_Cap", "Pillar", "Corner_Cap", "Edge"]
const REFRESH := 2.5                     # с — как часто пересматривать, какие крыши рядом
const HOP := [6.0, 14.0]                 # с — между взлётами и посадками
const FLY_T := 2.6                       # с — полёт
const SIZE := 1.6                        # во столько раз крупнее настоящей (иначе с высоты камеры не разглядеть)
const COLS := [Color(0.36, 0.38, 0.45), Color(0.3, 0.31, 0.37), Color(0.45, 0.32, 0.21), Color(0.38, 0.27, 0.18)]   # голуби, воробьи

var game
var mm: MultiMeshInstance3D
var birds: Array = []                    # [{id, p: Vector3 (мир), yaw, col, t (фаза), peck}]
var flying: Array = []                   # [{n: Node3D, a, b, t, land: {} или null}]
var _faces := {}                         # треугольники модели, без раскраски
var _perch := {}                         # id постройки → {n: число деталей, spots: [Vector3 в осях постройки]}
var _refresh := 0.0
var _hop := 4.0
var _last_at := Vector3.INF
var _rng := RandomNumberGenerator.new()


func setup(g) -> void:
	game = g
	_rng.randomize()
	mm = MultiMeshInstance3D.new()
	mm.name = "RoofBirds"
	var m := MultiMesh.new()
	m.transform_format = MultiMesh.TRANSFORM_3D
	m.use_colors = true
	m.mesh = bird_mesh()
	m.instance_count = MAX_BIRDS
	m.visible_instance_count = 0
	mm.multimesh = m
	mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mm)


func _process(dt: float) -> void:
	if game == null or not game.ready_done or game.city == null:
		return
	var q := str(game.settings.get("quality", "high"))
	var h: float = game.hour
	var on: bool = q != "verylow" and h >= HOURS[0] and h < HOURS[1] and not (game.mode == "menu" and not game.promo)
	if not on:
		if not birds.is_empty() or not flying.is_empty():
			clear()
		return
	var spd := clampf(float(game.speed), 0.0, 3.0) if not game.promo else 1.0
	var at: Vector3 = game.rig.target if game.rig else Vector3.ZERO
	_refresh -= dt
	if _refresh <= 0.0 or (_last_at != Vector3.INF and at.distance_to(_last_at) > 12.0 and _refresh < REFRESH - 0.5):
		_refresh = REFRESH
		_last_at = at
		_fill(at, MAX_BIRDS / 2 if q == "low" else MAX_BIRDS)
	# взлёт и посадка
	_hop -= dt * spd
	if _hop <= 0.0:
		_hop = _rng.randf_range(HOP[0], HOP[1])
		if not birds.is_empty() and _rng.randf() < 0.6:
			_take_off(birds.pop_at(_rng.randi() % birds.size()))
		else:
			_land_one(at)
	_tick_flying(dt * maxf(spd, 0.25))
	_draw(dt * spd)


func clear() -> void:
	birds.clear()
	for f: Dictionary in flying:
		if is_instance_valid(f["n"]):
			(f["n"] as Node).queue_free()
	flying.clear()
	mm.multimesh.visible_instance_count = 0


## Рассадить птиц по крышам у точки взгляда: ушедшие из круга улетают «сами» (просто пропадают за краем)
func _fill(at: Vector3, cap: int) -> void:
	var keep := []
	for bd: Dictionary in birds:
		var home: Dictionary = game.city.buildings.get(int(bd["id"]), {})
		if home.is_empty():
			continue
		var spots := _spots(home)
		if spots.is_empty():
			continue
		bd["p"] = game.city.xf(home) * (spots[0] as Vector3)
		if Vector2(bd["p"].x - at.x, bd["p"].z - at.z).length() < NEAR + 6.0:
			keep.append(bd)
	birds = keep
	if birds.size() >= cap:
		return
	var near := _roofs_near(at)
	var built := 0
	for b: Dictionary in near:
		if birds.size() >= cap:
			break
		var id := int(b["id"])
		var have := 0
		for bd: Dictionary in birds:
			have += 1 if int(bd["id"]) == id else 0
		for flight: Dictionary in flying:
			if flight["land"] != null and int(flight["land"]["id"]) == id:
				have += 1
		if have >= PER_ROOF:
			continue
		if not _perch.has(id):
			if built >= 4:
				continue                          # места крыш — понемногу за раз (кадр не дёргается)
			built += 1
		var spots := _spots(b)
		if spots.is_empty() or _rng.randf() < 0.6:
			continue
		var xf: Transform3D = game.city.xf(b)
		for i in mini(_rng.randi_range(1, PER_ROOF) - have, spots.size()):
			if birds.size() >= cap:
				break
			var lp: Vector3 = spots[_rng.randi() % spots.size()]
			birds.append(_bird(id, xf * lp, xf.basis.get_euler().y))
	if OS.get_environment("CIVCITY_BIRDS_DEBUG") == "1" and not birds.is_empty():
		print("ROOFBIRDS %d, первая у %s" % [birds.size(), str(birds[0]["p"])])


func _bird(id: int, p: Vector3, base_yaw: float) -> Dictionary:
	return {"id": id, "p": p, "yaw": base_yaw + (PI / 2 if _rng.randf() < 0.5 else -PI / 2) + _rng.randf_range(-0.5, 0.5),
		"col": COLS[_rng.randi() % COLS.size()], "t": _rng.randf() * 10.0, "peck": _rng.randf_range(2.0, 6.0)}


## Жилые дома и лавки у точки взгляда, ближние — первыми
func _roofs_near(at: Vector3) -> Array:
	var out := []
	for id in game.city.buildings:
		var b: Dictionary = game.city.buildings[id]
		if not (game.city.is_house(b) or String(Defs.B.get(b["type"], {}).get("cat", "")) in ["commerce", "farming"]):
			continue
		var c: Vector3 = game.city.xf(b).origin
		var d := Vector2(c.x - at.x, c.z - at.z).length()
		if d < NEAR:
			out.append([d, b])
	out.sort_custom(func(a, b2): return float(a[0]) < float(b2[0]))
	var bs := []
	for e: Array in out:
		bs.append(e[1])
	return bs


## Луч вниз по настоящим треугольникам кровли. Габариты дают только точки поиска.
func _spots(b: Dictionary) -> Array:
	var id := int(b["id"])
	var bp: Bp = game.city.blueprint(b)
	var signature := hash([bp.parts, bp.perch])
	if _perch.has(id) and int(_perch[id]["signature"]) == signature:
		return _perch[id]["spots"]
	var faces := PackedVector3Array()
	var candidates: Array = bp.perch.duplicate()
	for part: Array in bp.parts:
		var nm := String(part[0])
		if not _roof_part(nm):
			continue
		var local := _model_faces(nm)
		if local.is_empty():
			continue
		var xf: Transform3D = part[1]
		var top := -INF
		var ridge: Array[Vector3] = []
		for v: Vector3 in local:
			var q: Vector3 = xf * v
			faces.append(q)
			top = maxf(top, q.y)
		# Середина верхнего ребра — устойчивее случайной точки на скате.
		for v: Vector3 in local:
			var q: Vector3 = xf * v
			if q.y >= top - 0.025 and not ridge.has(q):
				ridge.append(q)
		if not ridge.is_empty() and not nm.begins_with("K:"):
			var center := Vector3.ZERO
			for q: Vector3 in ridge:
				center += q
			center /= float(ridge.size())
			candidates.append(center)
	var spots := []
	for candidate: Vector3 in candidates:
		var hit := _surface_at(faces, candidate)
		if hit.is_finite() and hit.y > 1.0:
			var separate := true
			for old: Vector3 in spots:
				if old.distance_to(hit) < 0.35:
					separate = false
			if separate:
				spots.append(hit)
	spots.sort_custom(func(x: Vector3, y: Vector3): return x.y > y.y)
	if spots.size() > 6:
		spots.resize(6)
	_perch[id] = {"signature": signature, "spots": spots}
	return spots


static func _roof_part(nm: String) -> bool:
	if nm.begins_with("K:") and nm.ends_with("/House"):
		return true
	if nm.begins_with("#") or not nm.to_lower().contains("roof"):
		return false
	for word: String in SKIP_PARTS:
		if nm.to_lower().contains(word.to_lower()):
			return false
	return true


## Те же локальные преобразования сеток, что использует Parts при отрисовке.
func _model_faces(nm: String) -> PackedVector3Array:
	if _faces.has(nm):
		return _faces[nm]
	var out := PackedVector3Array()
	var src := Synty.make(nm)
	for mi: MeshInstance3D in src.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var xf: Transform3D = Citizen._rel(mi, src)
		for v: Vector3 in mi.mesh.get_faces():
			out.append(xf * v)
	src.free()
	_faces[nm] = out
	return out


static func _surface_at(faces: PackedVector3Array, point: Vector3) -> Vector3:
	var top := -INF
	for v: Vector3 in faces:
		top = maxf(top, v.y)
	if not is_finite(top):
		return Vector3.INF
	var from := Vector3(point.x, top + 1.0, point.z)
	var best := Vector3.INF
	for i in range(0, faces.size() - 2, 3):
		var normal := (faces[i + 1] - faces[i]).cross(faces[i + 2] - faces[i])
		# Вертикальная кромка не годится для посадки; порядок вершин у наборов разный.
		if normal.length_squared() < 0.0000001 or absf(normal.normalized().y) < 0.25:
			continue
		var hit: Variant = Geometry3D.ray_intersects_triangle(from, Vector3.DOWN, faces[i], faces[i + 1], faces[i + 2])
		if hit != null and (not best.is_finite() or (hit as Vector3).y > best.y):
			best = hit
	return best


func _take_off(bd: Dictionary) -> void:
	var n := _flyer(bd["col"])
	add_child(n)
	var a: Vector3 = bd["p"]
	var dir := Vector3(sin(float(bd["yaw"])), 0, cos(float(bd["yaw"]))).rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6))
	var fy := _fly_y(a)
	# вверх отвесно выше всех крыш рядом, потом в сторону и ещё выше — сквозь дома не пролетает
	flying.append({"n": n, "pts": [a, Vector3(a.x, fy, a.z), a + dir * 22.0 + Vector3(0, fy - a.y + 4.0, 0)], "t": 0.0, "land": null, "up": true})


## Прилететь и сесть на свободное место крыши рядом
func _land_one(at: Vector3) -> void:
	var cap := MAX_BIRDS / 2 if str(game.settings.get("quality", "high")) == "low" else MAX_BIRDS
	if birds.size() + flying.size() >= cap:
		return
	var near := _roofs_near(at)
	if near.is_empty():
		return
	var b: Dictionary = near[_rng.randi() % mini(near.size(), 6)]
	if not _perch.has(int(b["id"])):
		return
	var spots: Array = _spots(b)
	for bird: Dictionary in birds:
		if int(bird["id"]) == int(b["id"]):
			return
	for flight: Dictionary in flying:
		if flight["land"] != null and int(flight["land"]["id"]) == int(b["id"]):
			return
	if spots.is_empty():
		return
	var xf: Transform3D = game.city.xf(b)
	var bd := _bird(int(b["id"]), xf * (spots[_rng.randi() % spots.size()] as Vector3), xf.basis.get_euler().y)
	var n := _flyer(bd["col"])
	add_child(n)
	var a := _rng.randf() * TAU
	var tp: Vector3 = bd["p"]
	var fy := _fly_y(tp)
	# прилетает на высоте выше всех крыш, садится на конёк отвесно сверху
	var from: Vector3 = tp + Vector3(cos(a), 0, sin(a)) * 20.0 + Vector3(0, fy - tp.y + 3.0, 0)
	flying.append({"n": n, "pts": [from, Vector3(tp.x, fy, tp.z), tp], "t": 0.0, "land": bd, "up": false})


func _tick_flying(dt: float) -> void:
	var left := []
	for f: Dictionary in flying:
		var n: Node3D = f["n"]
		if not is_instance_valid(n):
			continue
		f["t"] = float(f["t"]) + dt / (FLY_T * 1.5)
		var k := clampf(float(f["t"]), 0.0, 1.0)
		var pts: Array = f["pts"]
		var p := _along(pts, k)
		var dir := _along(pts, minf(k + 0.03, 1.0)) - _along(pts, maxf(k - 0.03, 0.0))
		n.global_position = p
		if Vector2(dir.x, dir.z).length() > 0.02:
			n.rotation.y = atan2(dir.x, dir.z)
		var flap := sin(float(f["t"]) * FLY_T * 26.0)
		for w in [n.get_node("WL"), n.get_node("WR")]:
			(w as Node3D).rotation.z = flap * 0.9 * (1.0 if w.name == "WL" else -1.0)
		if k >= 1.0:
			if f["land"] != null:
				var landing: Dictionary = f["land"]
				var home: Dictionary = game.city.buildings.get(int(landing["id"]), {})
				if not home.is_empty():
					for spot: Vector3 in _spots(home):
						var world_spot: Vector3 = game.city.xf(home) * spot
						if world_spot.distance_to(landing["p"]) < 0.03:
							landing["p"] = world_spot
							birds.append(landing)
							break
			n.queue_free()
			continue
		left.append(f)
	flying = left


## Высота полёта над местом p: выше самой высокой постройки в CLEAR_R на CLEAR м (и не ниже 4 м над местом сидения)
func _fly_y(p: Vector3) -> float:
	var top := p.y + 4.0
	for id in game.city.buildings:
		var b: Dictionary = game.city.buildings[id]
		var o: Vector3 = game.city.xf(b).origin
		if Vector2(o.x - p.x, o.z - p.z).length() > CLEAR_R:
			continue
		top = maxf(top, o.y + game.city.blueprint(b).top_y() + 1.0)
	return top + CLEAR


## Точка на ломаной pts по доле пути k (по длине)
static func _along(pts: Array, k: float) -> Vector3:
	var total := 0.0
	for i in range(1, pts.size()):
		total += (pts[i] as Vector3).distance_to(pts[i - 1])
	var want := total * clampf(k, 0.0, 1.0)
	for i in range(1, pts.size()):
		var seg := (pts[i] as Vector3).distance_to(pts[i - 1])
		if want <= seg or i == pts.size() - 1:
			return (pts[i - 1] as Vector3).lerp(pts[i], clampf(want / maxf(seg, 0.001), 0.0, 1.0))
		want -= seg
	return pts[pts.size() - 1]


## Сидящие: лёгкое покачивание, время от времени клюёт (наклон) и крутит головой (поворот)
func _draw(dt: float) -> void:
	var m := mm.multimesh
	var n := mini(birds.size(), MAX_BIRDS)
	for i in n:
		var bd: Dictionary = birds[i]
		bd["t"] = float(bd["t"]) + dt
		var t := float(bd["t"])
		var peck := fmod(t, float(bd["peck"]))
		var tilt := 0.35 * sin(clampf(peck / 0.35, 0.0, 1.0) * PI) if peck < 0.35 else 0.0
		var turn := 0.4 * sin(t * 0.7 + float(i))
		var basis := (Basis(Vector3.UP, float(bd["yaw"]) + turn) * Basis(Vector3.RIGHT, tilt)).scaled(Vector3.ONE * SIZE)
		m.set_instance_transform(i, Transform3D(basis, bd["p"]))
		m.set_instance_color(i, bd["col"])
	m.visible_instance_count = n


## Сидящая птица (≈ 0,25 м, смотрит вдоль +Z): тельце, голова, клюв, хвост — одной сеткой; цвет — от экземпляра
static func bird_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var parts := [
		[_ell(Vector3(0.07, 0.065, 0.11)), Transform3D(Basis.IDENTITY, Vector3(0, 0.07, 0)), Color(1, 1, 1)],
		[_ell(Vector3(0.045, 0.045, 0.045)), Transform3D(Basis.IDENTITY, Vector3(0, 0.135, 0.085)), Color(0.92, 0.92, 0.95)],
		[_box(Vector3(0.02, 0.015, 0.04)), Transform3D(Basis.IDENTITY, Vector3(0, 0.13, 0.135)), Color(0.85, 0.6, 0.25)],
		[_box(Vector3(0.06, 0.012, 0.08)), Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(0, 0.08, -0.12)), Color(0.7, 0.7, 0.75)],
		[_box(Vector3(0.012, 0.05, 0.012)), Transform3D(Basis.IDENTITY, Vector3(0.025, 0.02, 0.01)), Color(0.75, 0.45, 0.35)],
		[_box(Vector3(0.012, 0.05, 0.012)), Transform3D(Basis.IDENTITY, Vector3(-0.025, 0.02, 0.01)), Color(0.75, 0.45, 0.35)],
	]
	for e: Array in parts:
		var src: ArrayMesh = e[0]
		var arr := src.surface_get_arrays(0)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var xf: Transform3D = e[1]
		for k in idx:
			st.set_color(e[2])
			st.set_normal((xf.basis * ns[k]).normalized())
			st.add_vertex(xf * vs[k])
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	st.set_material(mat)
	return st.commit()


static func _ell(r: Vector3) -> ArrayMesh:
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 8
	s.rings = 5
	var am := ArrayMesh.new()
	var arr := s.get_mesh_arrays()
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for i in vs.size():
		vs[i] = vs[i] * r
	arr[Mesh.ARRAY_VERTEX] = vs
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am


static func _box(sz: Vector3) -> ArrayMesh:
	var b := BoxMesh.new()
	b.size = sz
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, b.get_mesh_arrays())
	return am


## Летящая птица: тельце и два крыла (машут в _tick_flying)
func _flyer(col: Color) -> Node3D:
	var n := Node3D.new()
	n.scale = Vector3.ONE * SIZE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.9
	var body := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.07
	bm.height = 0.22
	bm.radial_segments = 8
	bm.rings = 4
	body.mesh = bm
	body.rotation.x = PI / 2
	body.material_override = mat
	n.add_child(body)
	for sd: float in [1.0, -1.0]:
		var piv := Node3D.new()
		piv.name = "WL" if sd > 0 else "WR"
		n.add_child(piv)
		var w := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(0.2, 0.012, 0.09)
		w.mesh = wm
		w.position = Vector3(sd * 0.1, 0, 0)
		w.material_override = mat
		piv.add_child(w)
	return n
