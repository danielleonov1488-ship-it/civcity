class_name Doors
extends RefCounted
## Створки дверей одним общим проходом (владелец 15.11: «склад до сих пор с одной дверью», «у почтовой станции тоже одна
## дверь», «у многих зданий легиона нет дверей или одна»). В двустворчатом проёме висела одна створка (или ни одной) —
## вторая половина проёма зияла. Правило, единое для всех построек, после Interiors.apply (Catalog.make):
##  1. Проём — дыра в стене Synty (Interiors.holes), что стоит на полу (низ < 0,12) и выше 1,8. Считается только тот, за
##     которым есть комната или заднник (то же правило, что у interiors.gd: проём во двор, арки акведука, аркады трибун —
##     сквозные и остаются открытыми; памятники — кольцо арок амфитеатра и цирка, арка, форум — целиком открыты). Открытая лавка (SM_Bld_Wall_Door_Double_03, прилавок) — тоже без створок.
##  2. Какие створки уже висят в проёме (SM_Bld_Door*): закрывают ≥ 80% ширины — всё хорошо.
##  3. Иначе проём ≥ 1,6 м — две зеркальные створки, каждая в половину проёма и на своей петле, приоткрыты внутрь
##     (15–35°, чтобы тёплая комната за ними была видна); старые створки проёма заменяются. Уже проём — одна приоткрытая.
## Створки — обычные детали Synty (тот же MultiMesh), новых вызовов отрисовки нет.

const ON := true
const WIDE := 1.6                       # проём от этой ширины — двустворчатый (м)
const COVER := 0.8                      # доля ширины проёма, закрытая створками: не меньше — проём уже в порядке
const OPEN_MIN := 15                    # приоткрыто внутрь: от и до (градусов)
const OPEN_SPAN := 21
const OPEN_NAMES := ["SM_Bld_Wall_Door_Double_03"]    # открытая лавка

## Итог последнего прохода (для проверки): проёмов, уже в порядке, исправлено, двустворчатых, одностворчатых, заменено
## старых створок, добавлено деталей
static var last := {}


static func apply(b: Bp, kind: String) -> void:
	last = {"holes": 0, "ok": 0, "fixed": 0, "dbl": 0, "single": 0, "replaced": 0, "added": 0}
	if not ON or kind == "decor" or kind == "monument" or not b.kit_mov.is_empty():
		return
	var n0 := b.parts.size()
	var rooms := []                       # обратные преобразования комнат и заднников
	var stands := []
	var leaves := []                      # [номер, AABB в мире]
	for i in n0:
		var nm: String = b.parts[i][0]
		var xf: Transform3D = b.parts[i][1]
		if nm == "#room" or nm == "#room_lit":
			rooms.append(xf.affine_inverse())
		elif nm.begins_with("SM_Bld_Amphitheatre"):
			stands.append(xf * Bp.model_aabb(nm))
		elif _is_leaf(nm):
			leaves.append(i)
	var add := []                         # новые створки [имя, Transform3D, {}]
	var drop := {}                        # номера старых створок, что заменяются
	var reuse := []
	for i in n0:
		var nm: String = b.parts[i][0]
		if not nm.begins_with("SM_Bld_") or b.free_parts.has(i) or OPEN_NAMES.has(nm):
			continue
		var hs := Interiors.holes(nm)
		if hs.is_empty():
			continue
		var xf: Transform3D = b.parts[i][1]
		var box := Bp.model_aabb(nm)
		var zin := box.position.z
		var sc := Vector3(xf.basis.x.length(), xf.basis.y.length(), xf.basis.z.length())
		var inv := xf.affine_inverse()
		for r: Rect2 in hs:
			if r.position.y >= 0.12 or r.size.y < 1.8:
				continue
			var cxm := r.position.x + r.size.x * 0.5
			var cym := r.position.y + r.size.y * 0.5
			if not Interiors._covered(xf * Vector3(cxm, cym, zin - 0.3), rooms, 0.05):
				continue                  # за проёмом ни комнаты, ни заднника — сквозной проход
			var st := false
			for s: AABB in stands:
				if s.has_point(xf * Vector3(cxm, cym, zin - 0.85)):
					st = true
			if st:
				continue
			last["holes"] += 1
			# створки, что уже висят в этом проёме (в осях стены)
			var here := []
			var cov := []                 # промежутки по x, закрытые створками
			for k: int in leaves:
				if drop.has(k):
					continue
				var lb: AABB = (inv * (b.parts[k][1] as Transform3D)) * Bp.model_aabb(b.parts[k][0])
				var lc := lb.get_center()
				if lc.x < r.position.x - 0.1 or lc.x > r.position.x + r.size.x + 0.1 or lb.position.y > r.size.y * 0.6 or lc.z < zin - 0.4 or lc.z > 0.5:
					continue
				here.append(k)
				cov.append(Vector2(maxf(lb.position.x, r.position.x), minf(lb.end.x, r.position.x + r.size.x)))
			if _share(cov, r.size.x, r.position.x) >= COVER:
				last["ok"] += 1
				continue
			for k in here:
				drop[k] = true
				reuse.append(k)
			last["replaced"] += here.size()
			last["fixed"] += 1
			var width := r.size.x * sc.x
			var wide := width >= WIDE
			var seed := int(absf(xf.origin.x * 7.31 + xf.origin.z * 3.17 + cxm * 5.0) * 100.0)
			var leaf := _leaf_name(nm, r.size.y * sc.y >= 2.2, seed)
			var lsz := Bp.model_aabb(leaf).size
			var nl := 2 if wide else 1
			var kx := clampf((r.size.x / float(nl) - 0.04) / lsz.x, 0.85, 1.12)
			var ky := clampf((r.size.y - 0.02) / lsz.y, 0.9, 1.2)
			var rot0 := xf.basis.orthonormalized()
			for k in nl:
				var ang := deg_to_rad(float(OPEN_MIN + (seed + k * 37) % OPEN_SPAN))
				var hinge := Vector3(r.position.x + 0.02, 0.0, -0.02)
				var yaw := ang
				if k == 1:
					# правая створка — зеркало левой: разворот на π (не отрицательный масштаб — грани не выворачиваются)
					hinge = Vector3(r.position.x + r.size.x - 0.02, 0.0, -0.02 - lsz.z)
					yaw = PI - ang
				var bas := rot0 * Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(kx * sc.x, ky * sc.y, sc.z))
				add.append([leaf, Transform3D(bas, xf * hinge), {}])
			last["dbl" if wide else "single"] += 1
	# новые створки встают на места заменённых, остальные — в конец чертежа
	var ri := 0
	for a: Array in add:
		if ri < reuse.size():
			var p: Array = b.parts[reuse[ri]]
			p[0] = a[0]
			p[1] = a[1]
			p[2] = a[2]
			drop.erase(reuse[ri])
			ri += 1
		else:
			b.parts.append(a)
			last["added"] += 1
	var rm := drop.keys()
	rm.sort()
	rm.reverse()
	for k in rm:
		_remove(b, int(k))


static func _is_leaf(nm: String) -> bool:
	return (nm.begins_with("SM_Bld_Door_") and not nm.contains("Monument")) or nm.begins_with("SM_Bld_Base_Door")


## Какая створка к стене: большой проём — большая; тонкая стена (_04) — тонкая створка 04; остальные — по случаю
static func _leaf_name(wall: String, large: bool, seed: int) -> String:
	if large:
		return "SM_Bld_Door_Large_0%d" % (2 if wall.ends_with("_02") else 1)
	if wall.ends_with("_04"):
		return "SM_Bld_Door_04"
	return "SM_Bld_Door_0%d" % [1, 2, 3, 5, 1][seed % 5]


## Доля ширины проёма [x0, x0+w], закрытая промежутками cov (Vector2: от, до)
static func _share(cov: Array, w: float, x0: float) -> float:
	if cov.is_empty():
		return 0.0
	var s := cov.duplicate()
	s.sort_custom(func(a: Vector2, c: Vector2) -> bool: return a.x < c.x)
	var tot := 0.0
	var end := x0
	for v: Vector2 in s:
		var lo := maxf(v.x, end)
		if v.y > lo:
			tot += v.y - lo
			end = v.y
	return tot / w


## Убрать деталь с номером i; номера в free_parts (арки без следа) сдвигаются
static func _remove(b: Bp, i: int) -> void:
	b.parts.remove_at(i)
	var fp := {}
	for k in b.free_parts:
		var kk := int(k)
		if kk == i:
			continue
		fp[kk - 1 if kk > i else kk] = true
	b.free_parts = fp
