class_name WallDecor
extends RefCounted
## Настенные украшения как в Town to City: прилипают к стене постройки там, где курсор, — по всей длине и высоте,
## на любом этаже, лицом от стены; не закрывают окна, двери, балконы, навесы и другие украшения на этой стене.
## Надстроили этаж — украшение встаёт на ту же стену заново (окна нового облика тоже не закрывает).
## Стены — из чертежа постройки (Bp): модули SM_Bld_Wall_* (2,5 м, этаж 3 м — до масштаба Catalog.ARCH),
## проёмы окон и дверей — по замеру моделей лучами по сетке (OPEN). Всё — в осях постройки (как чертёж).

const SURF := 0.1125                  # наружная плоскость обычного модуля стены (толщина 0,225)
const SURF_LARGE := 0.3375            # у больших модулей 5 м
const OUT := 0.015                    # украшение чуть впереди стены
const STEP := 0.1                     # шаг поиска свободного места рядом, м
const RING_U := 16                    # ищем не дальше 1,6 м вдоль стены
const RING_Y := 16                    # и 1,6 м по высоте (до соседнего этажа)

## Проёмы модулей в своих осях (x 0…2,5 вдоль стены, y 0…3 вверх): Rect2(x, y, ширина, высота) — замер
## .work/lane_b/probe_walls.gd: всё, что не ровная стена (ниша окна, рама, ставни, дверь, арка)
const OPEN := {
	"SM_Bld_Wall_Window_01": [Rect2(0.6, 0.72, 1.3, 1.28)],
	"SM_Bld_Wall_Window_02": [Rect2(0.22, 1.32, 2.06, 0.96)],
	"SM_Bld_Wall_Window_03": [Rect2(0.97, 1.32, 0.56, 0.96)],
	"SM_Bld_Wall_Window_04": [Rect2(0.22, 1.32, 2.06, 0.96)],
	"SM_Bld_Wall_Window_05": [Rect2(0.47, 0.58, 1.56, 2.16)],
	"SM_Bld_Wall_Window_06": [Rect2(0.47, 1.47, 1.56, 0.66)],
	"SM_Bld_Wall_Door_01": [Rect2(0.47, 0.0, 1.56, 2.43)],
	"SM_Bld_Wall_Door_02": [Rect2(0.47, 0.0, 1.56, 2.88)],
	"SM_Bld_Wall_Door_03": [Rect2(0.47, 0.0, 1.56, 2.88)],
	"SM_Bld_Wall_Door_04": [Rect2(0.72, 0.0, 1.06, 1.98)],
	"SM_Bld_Wall_Door_Large_01": [Rect2(0.35, 0.0, 1.8, 2.88)],
	"SM_Bld_Wall_Door_Large_02": [Rect2(0.6, 0.0, 1.3, 2.58)],
	"SM_Bld_Wall_Door_Double_01": [Rect2(0.0, 0.0, 2.5, 2.88)],
	"SM_Bld_Wall_Large_Window_01": [Rect2(1.35, 1.92, 0.43, 0.81), Rect2(3.22, 1.92, 0.43, 0.81)],
	"SM_Bld_Wall_Alcove_01": [Rect2(0.35, 0.0, 1.8, 3.01)],
	"SM_Bld_Wall_Seat_01": [Rect2(0.1, 0.12, 2.4, 2.76)],
}

static var _faces := {}               # чертёж → стены
static var _rects := {}               # тип украшения → прямоугольник на стене


## Модуль стены (а не угол, карниз, парапет, перила)
static func _is_module(nm: String) -> bool:
	if not nm.begins_with("SM_Bld_Wall_"):
		return false
	for w in ["Balcony", "Tiny", "End", "Beam", "Cap", "Pillar"]:
		if nm.contains(w):
			return false
	var box := Bp.model_aabb(nm)
	return box.size.x >= 2.0 and box.size.y >= 2.5


## Деталь xf — стена: модуль в полный рост (а не дощечка из того же модуля в мелком масштабе — ставни, вывески)
static func is_wall(nm: String, xf: Transform3D) -> bool:
	if not _is_module(nm):
		return false
	var box := Bp.model_aabb(nm)
	return box.size.x * xf.basis.x.length() >= 0.9 and box.size.y * xf.basis.y.length() >= 1.4


## Проёмы модуля: замеренные; окно или дверь без замера — середина модуля целиком
static func _openings(nm: String) -> Array:
	if OPEN.has(nm):
		return OPEN[nm]
	if nm.contains("Door"):
		return [Rect2(0.2, 0.0, 2.1, 2.9)]
	if nm.contains("Window"):
		return [Rect2(0.2, 0.55, 2.1, 1.9)]
	return []


## Стены чертежа: [{n: наружу, a: вдоль (слева направо, если смотреть на стену), d: плоскость (n·p = d),
## mods: [Rect2 (u, y)] модули, block: [Rect2] что закрывать нельзя, bound: Rect2}]
static func faces(bp: Bp) -> Array:
	var key := bp.get_instance_id()
	if _faces.has(key):
		return _faces[key]
	var groups := {}
	var others := []
	for p in bp.parts:
		var nm: String = p[0]
		var xf: Transform3D = p[1]
		if is_wall(nm, xf):
			var box := Bp.model_aabb(nm)
			var sx := xf.basis.x.length()
			var sy := xf.basis.y.length()
			var sz := xf.basis.z.length()
			var a := xf.basis.x / sx
			var n := xf.basis.z / sz
			if absf(n.y) > 0.1 or absf(a.y) > 0.1:
				continue
			var o := xf.origin
			var d := o.dot(n) + (SURF_LARGE if box.size.x > 4.0 else SURF) * sz
			var fk := "%d:%d" % [roundi(rad_to_deg(atan2(n.x, n.z))), roundi(d * 20.0)]
			var f: Dictionary = groups.get(fk, {})
			if f.is_empty():
				f = {"n": n, "a": a, "d": d, "mods": [], "block": []}
				groups[fk] = f
			var u0 := o.dot(a) + box.position.x * sx
			var y0 := o.y + box.position.y * sy
			(f["mods"] as Array).append(Rect2(u0, y0, box.size.x * sx, box.size.y * sy))
			for r: Rect2 in _openings(nm):
				(f["block"] as Array).append(Rect2(u0 + r.position.x * sx, y0 + r.position.y * sy, r.size.x * sx, r.size.y * sy))
		elif nm != "#dark":
			var box: AABB = Parts._special_mesh(nm).get_aabb() if nm.begins_with("#") else Bp.model_aabb(nm)
			others.append(xf * box)
	var out := groups.values()
	for f: Dictionary in out:
		var n: Vector3 = f["n"]
		var a: Vector3 = f["a"]
		var d: float = f["d"]
		var bound := Rect2()
		for i in (f["mods"] as Array).size():
			bound = f["mods"][i] if i == 0 else bound.merge(f["mods"][i])
		f["bound"] = bound
		# всё, что выступает из этой стены (карнизы, балконы, навесы, ставни, двери, плющ, горшки, углы), — занято
		for w: AABB in others:
			var lo := INF
			var hi := -INF
			var ulo := INF
			var uhi := -INF
			for i in 8:
				var c := w.get_endpoint(i)
				var dn := c.dot(n)
				lo = minf(lo, dn)
				hi = maxf(hi, dn)
				var u := c.dot(a)
				ulo = minf(ulo, u)
				uhi = maxf(uhi, u)
			if hi < d - 0.04 or lo > d + 0.7:
				continue
			var r := Rect2(ulo, w.position.y, uhi - ulo, w.size.y)
			if r.intersects(bound.grow(0.05)):
				(f["block"] as Array).append(r)
	_faces[key] = out
	return out


## Прямоугольник украшения на стене относительно его начала (x вдоль стены, y вверх) — по деталям чертежа
static func rect_of(type: String) -> Rect2:
	if _rects.has(type):
		return _rects[type]
	var bp := Catalog.make(type)
	var box := AABB()
	var first := true
	for p in bp.parts:
		var nm: String = p[0]
		var b: AABB = Parts._special_mesh(nm).get_aabb() if nm.begins_with("#") else Bp.model_aabb(nm)
		var w: AABB = (p[1] as Transform3D) * b
		box = w if first else box.merge(w)
		first = false
	var r := Rect2(box.position.x, box.position.y, box.size.x, box.size.y).grow(0.01)
	if first:
		r = Rect2(-0.25, -0.25, 0.5, 0.5)
	_rects[type] = r
	return r


## Прямоугольники уже висящих на постройке украшений (кроме skip) — на каких стенах: [[n, d, Rect2]]
static func hosted(c: City, host: Dictionary, skip := -1) -> Array:
	var out := []
	var inv := c.xf(host).affine_inverse()
	for id in c.buildings:
		var o: Dictionary = c.buildings[id]
		if int(o.get("host", -1)) != int(host["id"]) or int(id) == skip:
			continue
		var pl := inv * Vector3((o["pos"] as Vector2).x, float(o["y"]), (o["pos"] as Vector2).y)
		var ly := float(o["yaw"]) - float(host["yaw"])
		out.append([Vector3(sin(ly), 0, cos(ly)), pl, rect_of(String(o["type"]))])
	return out


## Можно ли повесить украшение с прямоугольником rect началом в (u, y) стены f: целиком на модулях стены и ничего не
## закрывает (extra — прямоугольники других украшений на этой стене)
static func fits(f: Dictionary, rect: Rect2, u: float, y: float, extra: Array) -> bool:
	var r := Rect2(u + rect.position.x, y + rect.position.y, rect.size.x, rect.size.y)
	if not (f["bound"] as Rect2).grow(0.01).encloses(r):
		return false
	for pt: Vector2 in [r.position, r.position + Vector2(r.size.x, 0), r.position + Vector2(0, r.size.y), r.end, r.get_center()]:
		var inside := false
		for m: Rect2 in f["mods"]:
			if m.grow(0.01).has_point(pt):
				inside = true
				break
		if not inside:
			return false
	for b: Rect2 in f["block"]:
		if b.intersects(r):
			return false
	for b: Rect2 in extra:
		if b.intersects(r):
			return false
	return true


## Чужие украшения на стене f — прямоугольниками в её осях
static func _extra_on(f: Dictionary, others: Array) -> Array:
	var out := []
	var n: Vector3 = f["n"]
	for e: Array in others:
		var en: Vector3 = e[0]
		var ep: Vector3 = e[1]
		if en.dot(n) < 0.9 or absf(ep.dot(n) - float(f["d"])) > 0.35:
			continue
		var r: Rect2 = e[2]
		out.append(Rect2(ep.dot(f["a"]) + r.position.x, ep.y + r.position.y, r.size.x, r.size.y))
	return out


## Ближайшее к (u, y) годное место на стене f: Vector2(u, y) или Vector2.INF
static func nearest(f: Dictionary, rect: Rect2, u: float, y: float, extra: Array) -> Vector2:
	if fits(f, rect, u, y, extra):
		return Vector2(u, y)
	var best := Vector2.INF
	var bd := INF
	# сначала — ровно за край того, что мешает (окно, карниз, соседнее украшение): узкое место на стене не теряется
	# между шагами поиска по сетке
	var r := Rect2(u + rect.position.x, y + rect.position.y, rect.size.x, rect.size.y)
	var cands := []
	var bnd: Rect2 = f["bound"]
	for b: Rect2 in (f["block"] as Array) + extra:
		if not b.intersects(r):
			continue
		cands.append(Vector2(b.position.x - rect.end.x - 0.005, y))
		cands.append(Vector2(b.end.x - rect.position.x + 0.005, y))
		cands.append(Vector2(u, b.position.y - rect.end.y - 0.005))
		cands.append(Vector2(u, b.end.y - rect.position.y + 0.005))
	if r.position.x < bnd.position.x:
		cands.append(Vector2(bnd.position.x - rect.position.x + 0.005, y))
	if r.end.x > bnd.end.x:
		cands.append(Vector2(bnd.end.x - rect.end.x - 0.005, y))
	for cnd: Vector2 in cands:
		var du := cnd.x - u
		var dy := cnd.y - y
		if absf(du) > RING_U * STEP or absf(dy) > RING_Y * STEP:
			continue
		var dd := du * du + dy * dy * 1.3
		if dd < bd and fits(f, rect, cnd.x, cnd.y, extra):
			bd = dd
			best = cnd
	if best != Vector2.INF:
		return best
	var stop := RING_U
	for ring in range(1, RING_U + 1):
		if ring > stop:
			break
		for iu in range(-ring, ring + 1):
			for iy in range(-mini(ring, RING_Y), mini(ring, RING_Y) + 1):
				if maxi(absi(iu), absi(iy)) != ring:
					continue
				var du := iu * STEP
				var dy := iy * STEP
				var dd := du * du + dy * dy * 1.3      # по высоте сдвигаем чуть неохотнее, чем вдоль стены
				if dd >= bd:
					continue
				if fits(f, rect, u + du, y + dy, extra):
					bd = dd
					best = Vector2(u + du, y + dy)
		if best != Vector2.INF and stop == RING_U:
			stop = mini(RING_U, int(ceil(ring * 1.5)))
	return best


## Украшение type на постройку с чертежом bp: курсор попал в точку hit (оси постройки), луч смотрит по dir.
## {"p": начало украшения (оси постройки), "yaw": поворот относительно постройки, "err": "" | почему нельзя,
## "face": стена} или {} — под курсором не стена
static func solve(bp: Bp, hit: Vector3, dir: Vector3, type: String, others: Array, origin := Vector3.INF) -> Dictionary:
	var best := {}
	var on := hit
	# стена, которую луч из камеры (origin, dir) пересекает первой в её пределах: точка — где луч входит в стену,
	# а не где он задел коробку карниза, ставни или соседнего украшения
	var bt := INF
	var o := origin if origin.is_finite() else hit
	if dir != Vector3.ZERO:
		for f: Dictionary in faces(bp):
			var n: Vector3 = f["n"]
			var dn := dir.dot(n)
			if dn > -0.05:
				continue                      # к этой стене камера спиной
			var t := (float(f["d"]) - o.dot(n)) / dn
			var q := o + dir * t
			var ok_t := t > 0.0 if origin.is_finite() else (t > -6.0 and t < 2.0)
			if ok_t and t < bt and (f["bound"] as Rect2).grow(0.2).has_point(Vector2(q.dot(f["a"]), q.y)):
				bt = t
				best = f
				on = q
	if best.is_empty():
		var bd := 0.45
		for f: Dictionary in faces(bp):
			var n: Vector3 = f["n"]
			if dir != Vector3.ZERO and dir.dot(n) > -0.05:
				continue
			var dist := absf(hit.dot(n) - float(f["d"]))
			if dist < bd and (f["bound"] as Rect2).grow(0.3).has_point(Vector2(hit.dot(f["a"]), hit.y)):
				bd = dist
				best = f
				on = hit
	if best.is_empty():
		return {}
	var rect := rect_of(type)
	var u0 := on.dot(best["a"]) - rect.get_center().x
	var y0 := on.y - rect.get_center().y
	var at := nearest(best, rect, u0, y0, _extra_on(best, others))
	var err := ""
	if at == Vector2.INF:
		at = Vector2(u0, y0)
		err = "Здесь окна и двери — наведите на свободное место стены"
	return {"p": point(best, at), "yaw": atan2((best["n"] as Vector3).x, (best["n"] as Vector3).z), "err": err, "face": best,
		"u": at.x, "y": at.y, "on": Vector2(u0, y0)}


## Точка начала украшения на стене f в (u, y) стены — в осях постройки
static func point(f: Dictionary, at: Vector2) -> Vector3:
	var p: Vector3 = (f["a"] as Vector3) * at.x + (f["n"] as Vector3) * (float(f["d"]) + OUT)
	p.y = at.y
	return p


## Надстроили этаж (облик постройки другой): украшение o встаёт на ту же стену — на прежнее место или ближайшее
## свободное. true — передвинули (записи pos и y поменялись)
static func reanchor(c: City, host: Dictionary, o: Dictionary) -> bool:
	var bp := c.blueprint(host)
	var hx := c.xf(host)
	var pl := hx.affine_inverse() * Vector3((o["pos"] as Vector2).x, float(o["y"]), (o["pos"] as Vector2).y)
	var ly := float(o["yaw"]) - float(host["yaw"])
	var nd := Vector3(sin(ly), 0, cos(ly))
	var best := {}
	var bd := 1.5
	for f: Dictionary in faces(bp):
		if (f["n"] as Vector3).dot(nd) < 0.9:
			continue
		var dist := absf(pl.dot(f["n"]) - float(f["d"]))
		if dist < bd:
			bd = dist
			best = f
	if best.is_empty():
		return false
	var rect := rect_of(String(o["type"]))
	var others := hosted(c, host, int(o["id"]))
	var at := nearest(best, rect, pl.dot(best["a"]), pl.y, _extra_on(best, others))
	if at == Vector2.INF:
		# на этой стене места не осталось (новый облик — другие окна) — на ближайшую другую стену постройки
		var bdist := INF
		var bf := {}
		for f: Dictionary in faces(bp):
			if f == best:
				continue
			var fb: Rect2 = f["bound"]
			var u := clampf(pl.dot(f["a"]), fb.position.x, fb.end.x) - rect.get_center().x
			var cand := nearest(f, rect, u, pl.y, _extra_on(f, others))
			if cand == Vector2.INF:
				continue
			var dist := point(f, cand).distance_to(pl)
			if dist < bdist:
				bdist = dist
				bf = f
				at = cand
		if bf.is_empty():
			return false
		best = bf
	var w := hx * point(best, at)
	var np := Vector2(w.x, w.z)
	var ny := float(host["yaw"]) + atan2((best["n"] as Vector3).x, (best["n"] as Vector3).z)
	if np.distance_to(o["pos"]) < 0.005 and absf(w.y - float(o["y"])) < 0.005:
		return false
	o["pos"] = np
	o["y"] = w.y
	o["yaw"] = ny
	return true
