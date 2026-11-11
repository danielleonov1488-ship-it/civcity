class_name Ivy
## Плющ разрастается на старых домах («Уютный Рим», этап 5 «город дышит», docs/PLAN_COZY.md): дом, что стоит
## дольше STAGE_H[0] игровых часов, обрастает парой лоз у земли; дольше STAGE_H[1] — плющ гуще и лезет выше,
## местами с цветами. Только в новой игре (City.cozy_v ≥ 1). Лозы — детали Synty на глухих стенах дома
## (по его чертежу: стена — по габаритам, наружу — от середины дома); какие стены — по номеру дома, всегда одни и те же.

const STAGE_H := [72, 192]               # часов: 3 игровых дня — немного, 8 — гуще
const PER_STAGE := [0, 2, 5]             # сколько лоз на стадии
const OUT := 0.08                         # отступ от стены наружу, м


## Стадия плюща дома b (0 — нет)
static func stage(city, b: Dictionary) -> int:
	if city == null or int(city.get("cozy_v")) < 1 or not city.is_house(b):
		return 0
	var age := int(city.clock_h) - int(b.get("hz", 0))
	return 2 if age >= STAGE_H[1] else (1 if age >= STAGE_H[0] else 0)


## Чертёж лоз для дома с чертежом bp на стадии st (в осях дома)
static func blueprint(bp: Bp, st: int, seed_v: int) -> Bp:
	var out := Bp.new(seed_v)
	if st <= 0:
		return out
	if not bp.kit_faces.is_empty():
		return _kit(bp, st, seed_v, out)
	var walls := []
	var c := Vector3.ZERO
	for p in bp.parts:
		var nm := String(p[0])
		if not nm.begins_with("SM_Bld_Wall") or nm.contains("Door") or nm.contains("Window") or nm.contains("Balcony") or nm.contains("Trim"):
			continue
		var ab := Bp.model_aabb(nm)
		var xf: Transform3D = p[1]
		var ctr := xf * ab.get_center()
		walls.append([xf, ab, ctr])
		c += ctr
	if walls.is_empty():
		return out
	c /= walls.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	# сначала нижние стены (лоза растёт от земли), потом — выше
	walls.sort_custom(func(a, b2): return float(a[2].y) < float(b2[2].y))
	var low: Array = walls.filter(func(w): return float(w[2].y) < 2.0)
	var pool: Array = low if st == 1 or walls.size() == low.size() else low + walls.filter(func(w): return float(w[2].y) >= 2.0).slice(0, 3)
	var picks := []
	var tries := 0
	while picks.size() < mini(int(PER_STAGE[st]), pool.size()) and tries < 40:
		tries += 1
		var w: Array = pool[rng.randi() % pool.size()]
		if w in picks:
			continue
		picks.append(w)
	for w: Array in picks:
		var xf: Transform3D = w[0]
		var ab: AABB = w[1]
		var ctr: Vector3 = w[2]
		# тонкая сторона стены — её нормаль; наружу — от середины дома
		var ax := Vector3.RIGHT if ab.size.x < ab.size.z else Vector3.BACK
		var nrm := (xf.basis * ax)
		nrm.y = 0.0
		nrm = nrm.normalized()
		if nrm.dot(Vector3(ctr.x - c.x, 0, ctr.z - c.z)) < 0.0:
			nrm = -nrm
		var thick := minf(ab.size.x, ab.size.z) * 0.5
		var base := Vector3(ctr.x, xf.origin.y, ctr.z) + nrm * (thick + OUT)
		var yaw := atan2(nrm.x, nrm.z)
		var name := ("SM_Env_Ivy_Flowers_%02d" % (1 + rng.randi() % 13)) if st == 2 and rng.randf() < 0.4 else ("SM_Env_Ivy_%02d" % (1 + rng.randi() % 13))
		out.add_xf(name, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * rng.randf_range(0.8, 1.0)), base + Vector3(rng.randf_range(-0.4, 0.4), 0, 0).rotated(Vector3.UP, yaw)))
	return out


## Дом из своего набора: лозы — у земли на глухих участках стен из Blender (между окнами и дверями), сначала бока и зад
static func _kit(bp: Bp, st: int, seed_v: int, out: Bp) -> Bp:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var spots := []                         # [приоритет, точка, поворот]
	for f: Dictionary in bp.kit_faces:
		var n: Vector3 = f["n"]
		var a: Vector3 = f["a"]
		var d: float = f["d"]
		var bd: Rect2 = f["bound"]
		var pri := 0 if String(f.get("side", "")) in ["left", "right", "back"] else 1
		var u := bd.position.x + 0.45
		while u < bd.end.x - 0.45:
			var free := true
			for r: Rect2 in f.get("block", []):
				if r.position.y < 1.2 and u > r.position.x - 0.35 and u < r.end.x + 0.35:
					free = false
					break
			if free:
				spots.append([pri + rng.randf() * 0.5, a * u + n * (d + OUT), atan2(n.x, n.z)])
			u += 0.6
	spots.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	var want := mini(int(PER_STAGE[st]), spots.size())
	for i in want:
		var e: Array = spots[i]
		var name := ("SM_Env_Ivy_Flowers_%02d" % (1 + rng.randi() % 13)) if st == 2 and rng.randf() < 0.4 else ("SM_Env_Ivy_%02d" % (1 + rng.randi() % 13))
		out.add_xf(name, Transform3D(Basis(Vector3.UP, float(e[2])).scaled(Vector3.ONE * rng.randf_range(0.75, 0.95)), e[1]))
	return out
