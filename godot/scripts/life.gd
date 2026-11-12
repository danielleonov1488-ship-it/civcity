class_name Life
extends Node
## Постройки отвечают жителям (владелец 12.11: «пересобирай всё в более детальное, чтобы всё открывалось и
## взаимодействовало с жителями»):
##  - двери: житель входит в дом или лавку или выходит из неё — створка распахивается внутрь (~0,3 с) и прикрывается
##    через ~0,8 с после него (People._door_in, People._go);
##  - ставни: утром открываются, вечером закрываются — у каждого окна в свой час и вразнобой, плавно; пустой дом
##    стоит со ставнями закрытыми, часть окон на ночь остаётся открытой (в них теплится огонёк);
##  - общественные здания (12.11, «жизнь построек 2»): створки дверей Synty у школы, склада, скриптория, бань, станции,
##    мастерских Легиона… и бронзовые врата храмов и маяка на подиуме за лестницей (_find_doors: «deep»); ставни
##    библиотеки, школы, терм, дома префекта, станции — створками (CatDressCivic._shutter_pair), по часам, как у лавок;
##  - мебель: скамьи у стен, табуреты и стулья у столов домов, лавок, таверн — места, где жители присаживаются
##    (People._furn_target); за столом таверны и термополия — с чашей;
##  - цветы у дома: утром и под вечер жилец выходит полить ящик под окном или горшки у двери (People «water»).
## Всё — детали Parts (один MultiMesh на все одинаковые детали города): меняется только место экземпляра
## (MultiMesh.set_instance_transform), прежнее запоминается и возвращается в точности. Двери и ставни шевелятся только
## у построек в кадре и недалеко от камеры; дальние ставни догоняют часы, когда к ним подъедет камера (без движения,
## вне кадра). Каждый кадр — только то, что сейчас движется, и SCAN_N построек со ставнями (по кругу)

static var on := true                 # для сравнений «было/стало» (test_perf mode=lifeab)

const DOOR_ANG := 1.35                # рад — на сколько распахивается дверь (внутрь дома)
const DOOR_OPEN_T := 0.3              # с — распахнуть
const DOOR_CLOSE_T := 0.5             # с — прикрыть
const DOOR_FAR := 150.0               # м от камеры: дальше двери не шевелятся (они там в несколько точек)
const SHUT_T := 1.7                   # с — створки ставен проходят путь
const SHUT_STAGGER := 5.0             # окна дома и соседей начинают вразнобой — в пределах стольких секунд
const SHUT_ANIM_R := 170.0            # м — плавно только в кадре и не дальше; ближе SHUT_SNAP_R вне кадра — сразу
const SHUT_SNAP_R := 260.0            # дальше от камеры ставни не трогаем вовсе
const SCAN_N := 12                    # построек со ставнями проверяем за кадр (по кругу; 100 построек — за 8 кадров)
const SEAT_CELL := 16.0               # клетка поиска мебели, м
## Здесь сидят зрители и ученики (Spectacle) — их скамьи жителям не предлагаем; таверна — днём, пока нет вечерних гостей
const SEAT_TAVERN_H := [9.0, 17.5]
## Стол рядом — пьют из чаши (а не просто сидят)
const DRINK := ["taberna", "thermopolium", "mansio", "dice", "wineshop"]

var game
var _info := {}                       # Bp → {doors, shut, pairs, seats, water}: по чертежу, считается один раз
var _doors := {}                      # id → {k, hold, subs: [[MultiMesh, место, исходное, петля в мире, знак]]}
var _shut := {}                       # id → {k, goal, wait: [по парам], h: [ручки створок], t0: [[…]], move}
var _shut_ids := []                   # постройки со ставнями (проверка по кругу)
var _moving := {}                     # id → true: у постройки сейчас движутся ставни (или ждут своей очереди)
var _scan_i := 0
var _seat_grid := {}                  # клетка → [id]
var _seat_cell := {}                  # id → клетка
var moves := 0                        # сколько створок сдвинуто за последний кадр (замеры)


func setup(g) -> void:
	game = g


# ---------- чертёж: где двери, ставни, сиденья ----------

func info(bp: Bp, type := "") -> Dictionary:
	if _info.has(bp):
		return _info[bp]
	var inf := {"doors": _find_doors(bp), "shut": [], "pairs": 0, "seats": _find_seats(bp, type), "water": _find_water(bp)}
	_find_shutters(bp, inf)
	_info[bp] = inf
	return inf


## Створки входной двери: детали «SM_Bld_Door_…» первого этажа, ближние к месту входа (bp.door) и лицом к нему.
## Двустворчатая — обе створки (каждая на своей наружной петле); одна — петля у начала координат детали (так в Synty).
## Нет такой у самого входа — врата большого здания за лестницей и портиком (храмы Юпитера и Венеры, пантеон, маяк):
## на подиуме (до DEEP_Y над землёй) и дальше (до DEEP_D), но вход — прямо перед ними (не сбоку, DEEP_SIDE).
## Возвращает [[номер детали, петля (в осях постройки), знак поворота]]
const DEEP_Y := 1.3
const DEEP_D := 7.5
const DEEP_SIDE := 2.2
static func _find_doors(bp: Bp) -> Array:
	if bp.kit_id != "":
		return []                          # дом из своего набора — у него свои створки (KitShutters)
	var res := _doors_at(bp, false)
	return res if not res.is_empty() else _doors_at(bp, true)


static func _doors_at(bp: Bp, deep: bool) -> Array:
	var dp := bp.door
	var cand := []
	for i in bp.parts.size():
		var p: Array = bp.parts[i]
		var nm: String = p[0]
		if not nm.begins_with("SM_Bld_Door_"):
			continue
		var xf: Transform3D = p[1]
		var box: AABB = xf * Bp.model_aabb(nm)
		if box.position.y > (DEEP_Y if deep else 0.3):
			continue                       # верхние этажи, балконы
		var c := box.get_center()
		var out := Vector3(xf.basis.z.x, 0, xf.basis.z.z).normalized()
		var to := Vector3(dp.x - c.x, 0, dp.z - c.z)
		if deep:
			if to.length() > DEEP_D or to.dot(out) < to.length() * 0.6 or (to - out * to.dot(out)).length() > DEEP_SIDE:
				continue                   # вход не прямо перед вратами
		elif to.length() > 3.2 or to.dot(out) < 0.05:
			continue                       # не та дверь (сбоку, сзади) или вход не перед ней
		cand.append([to.length(), i, box, out, xf.origin])
	if cand.is_empty():
		return []
	cand.sort_custom(func(a, b): return a[0] < b[0])
	var first: AABB = cand[0][2]
	var pick := [cand[0]]
	for k in range(1, cand.size()):
		var bx: AABB = cand[k][2]
		if bx.get_center().distance_to(first.get_center()) < 1.4 and absf(bx.position.y - first.position.y) < 0.05:
			pick.append(cand[k])           # вторая половина двустворчатой
			break
	var mid := Vector3.ZERO
	for e: Array in pick:
		mid += (e[2] as AABB).get_center()
	mid /= pick.size()
	var res := []
	for e: Array in pick:
		var box: AABB = e[2]
		var c := box.get_center()
		var n_in: Vector3 = -(e[3] as Vector3)
		var ax := Vector3(1, 0, 0) if box.size.x >= box.size.z else Vector3(0, 0, 1)
		var hw := box.size.dot(ax) * 0.5
		var e0 := c - ax * hw
		var e1 := c + ax * hw
		var h: Vector3
		if pick.size() > 1:
			h = e0 if e0.distance_to(mid) > e1.distance_to(mid) else e1
		else:
			var o: Vector3 = e[4]
			h = e0 if absf((o - e0).dot(ax)) <= absf((o - e1).dot(ax)) else e1
		h.y = 0.0
		var v := Vector3(c.x - h.x, 0, c.z - h.z).normalized()
		var s := 1.0 if Vector3(v.z, 0, -v.x).dot(n_in) > 0.0 else -1.0
		res.append([int(e[1]), h, s])
	return res


## Ставни: дощатые створки по бокам окна (CatHouses._shutters, CatDress._shutters — стенка Synty с текстурой досок
## Wood_02). Пара — две створки в одной плоскости и на одной высоте, между ними — окно. Закрываются, поворачиваясь на
## петле у окна наружу и дальше — на окно, и растягиваются до середины окна. Закрытые чертежом пары (вплотную) не
## трогаем. inf.shut: [[номер детали, петля, знак, ось вдоль стены (к свободному краю), растяжка, номер пары]]
static func _find_shutters(bp: Bp, inf: Dictionary) -> void:
	var leaves := []
	for i in bp.parts.size():
		var p: Array = bp.parts[i]
		if String(p[0]) != "SM_Bld_Wall_01" or String((p[2] as Dictionary).get("Stucco_White_01", "")) != "Wood_02":
			continue
		var xf: Transform3D = p[1]
		var box: AABB = xf * Bp.model_aabb("SM_Bld_Wall_01")
		var nx := box.size.x < box.size.z                       # тонкая по x — стена вдоль z
		var ax := Vector3(0, 0, 1) if nx else Vector3(1, 0, 0)
		var out := Vector3(xf.basis.z.x, 0, xf.basis.z.z).normalized()
		leaves.append({"i": i, "box": box, "ax": ax, "nx": nx, "out": out, "used": false})
	var pairs := 0
	for a: Dictionary in leaves:
		if a["used"]:
			continue
		var ba: AABB = a["box"]
		var ax: Vector3 = a["ax"]
		var best := {}
		var bg := INF
		for b: Dictionary in leaves:
			if b == a or b["used"] or b["nx"] != a["nx"]:
				continue
			var bb: AABB = b["box"]
			if absf(ba.position.y - bb.position.y) > 0.06 or absf(ba.size.y - bb.size.y) > 0.06:
				continue
			var n := Vector3(1, 0, 0) if a["nx"] else Vector3(0, 0, 1)
			if absf(ba.get_center().dot(n) - bb.get_center().dot(n)) > 0.06:
				continue
			var a0 := ba.position.dot(ax)
			var a1 := a0 + ba.size.dot(ax)
			var b0 := bb.position.dot(ax)
			var b1 := b0 + bb.size.dot(ax)
			var gap := b0 - a1 if b0 >= a1 else a0 - b1
			if gap < 0.3 or gap > 1.8 or gap >= bg:
				continue
			bg = gap
			best = b
		if best.is_empty():
			continue
		a["used"] = true
		best["used"] = true
		var lo: Dictionary = a if ba.position.dot(ax) < (best["box"] as AABB).position.dot(ax) else best
		var hi: Dictionary = best if lo == a else a
		for e: Array in [[lo, 1.0], [hi, -1.0]]:
			var L: Dictionary = e[0]
			var box: AABB = L["box"]
			var sgn: float = e[1]                       # +1: петля на дальнем по оси краю (створка слева от окна)
			var c := box.get_center()
			var w := box.size.dot(ax)
			var h := c + ax * sgn * w * 0.5
			h.y = 0.0
			var free := -ax * sgn                       # от петли к свободному краю
			var o: Vector3 = L["out"]
			var s := 1.0 if Vector3(free.z, 0, -free.x).dot(o) > 0.0 else -1.0
			var stretch := (bg * 0.5 + 0.01) / maxf(w, 0.01)
			(inf["shut"] as Array).append([int(L["i"]), h, s, free, stretch, pairs])
		pairs += 1
	inf["pairs"] = pairs


## Сиденья мебели (в осях постройки): [где ступни, куда лицом (yaw), высота сиденья, середина сиденья, без спинки, пьют ли,
## можно подойти от входа]. Скамьи — как у скамьи-украшения (People._bench_seats); стулья и табуреты — только у стола
## (лицом к нему). Только на земле и не там, где сидят люди при деле (bp.actors). «От входа» — от bp.door до места по
## прямой не мешает ни одна стена, колонна, дверь (дворик таверны, портик термополия): идут через вход (People «via»)
static func _find_seats(bp: Bp, type: String) -> Array:
	var out := []
	if Spectacle.VENUES.has(type) and type != "taberna":
		return out                         # трибуны, школьные скамьи — у зрелищ свои зрители
	if Defs.base_of(type) == "bench" or bp.kit_id != "":
		return out                         # скамья-украшение — своё (People._seat_target)
	var tables := []
	for p in bp.parts:
		var nm: String = p[0]
		if nm.begins_with("SM_Prop_Table_0"):
			var tb: AABB = (p[1] as Transform3D) * Bp.model_aabb(nm)
			if tb.position.y < 0.15:
				tables.append(tb.get_center())
	var drink := type in DRINK
	var walls := []                        # высокое на земле: стены, колонны, створки, нутро — сквозь них не пройти
	for p in bp.parts:
		var nm: String = p[0]
		if nm.begins_with("SM_Env_") or nm.begins_with("SM_Prop_Banner") or nm.contains("Lamp") or nm.contains("Ivy"):
			continue
		var wb: AABB = (p[1] as Transform3D) * Bp.model_aabb(nm)
		if wb.position.y < 0.6 and wb.end.y > 1.4 and maxf(wb.size.x, wb.size.z) > 0.15:
			walls.append(Rect2(wb.position.x + 0.04, wb.position.z + 0.04, maxf(0.0, wb.size.x - 0.08), maxf(0.0, wb.size.z - 0.08)))
	var dp := Vector2(bp.door.x, bp.door.z)
	# вещи над землёй (кувшин, корзинка, товар ремесла): на скамье с ними не сидят (скамья-полка лавки, CatDress._display;
	# скамья с кувшином на краю, CatDress «bench»)
	var items := []
	for p in bp.parts:
		var nm: String = p[0]
		if nm.begins_with("SM_Prop_Seat_") or nm.begins_with("SM_Prop_Table_0") or nm.begins_with("SM_Bld_") or nm.begins_with("SM_Env_"):
			continue
		var ib: AABB = (p[1] as Transform3D) * Bp.model_aabb(nm)
		if ib.position.y > 0.2 and ib.position.y < 1.3 and ib.size.y < 1.2 and maxf(ib.size.x, ib.size.z) < 1.4:
			items.append(ib)
	for p in bp.parts:
		var nm: String = p[0]
		var bench := nm.begins_with("SM_Prop_Seat_Bench")
		var chair := nm.begins_with("SM_Prop_Seat_Chair") or nm.begins_with("SM_Prop_Stool") or nm.begins_with("SM_Prop_Seat_Stool")
		if not bench and not chair:
			continue
		var xf: Transform3D = p[1]
		var mb := Bp.model_aabb(nm)
		var box: AABB = xf * mb
		if box.position.y > 0.15:
			continue
		var c := box.get_center()
		var busy := false
		for a: Array in bp.actors:
			var ap: Vector3 = a[0]
			if Vector2(ap.x - c.x, ap.z - c.z).length() < 0.7:
				busy = true
				break
		if busy:
			continue
		var sc := xf.basis.get_scale()
		var seat_h := minf(mb.size.y, 0.5) * sc.y
		var near_t := Vector3.INF
		for t: Vector3 in tables:
			if Vector2(t.x - c.x, t.z - c.z).length() < 1.3 and (near_t == Vector3.INF or Vector2(t.x - c.x, t.z - c.z).length() < Vector2(near_t.x - c.x, near_t.z - c.z).length()):
				near_t = t
		if chair:
			if near_t == Vector3.INF:
				continue
			var f := Vector3(near_t.x - c.x, 0, near_t.z - c.z).normalized()
			var mid := Vector3(c.x, 0, c.z) - f * 0.04
			var foot := mid + f * People.SIT_BACK
			out.append([foot, atan2(f.x, f.z), seat_h, mid, false, drink, _open_from(dp, Vector2(foot.x, foot.z), walls)])
			continue
		var w := mb.size.x * sc.x
		var fwd := xf.basis.z.normalized()
		var side := xf.basis.x.normalized()
		var bmid := xf * Vector3(mb.get_center().x, 0, mb.get_center().z)
		bmid.y = 0.0
		var two: bool = nm in People.BENCH_TWO_SIDED
		var at_table := near_t != Vector3.INF
		if at_table:
			# скамья у стола — лицом к столу (с той стороны, где стол)
			fwd = fwd if fwd.dot(near_t - bmid) > 0.0 else -fwd
			two = false
		var n := 3 if w > 1.55 else (2 if w > 0.75 else 1)
		for k in n:
			var o := (k - (n - 1) / 2.0) * w * (0.3 if n == 3 else 0.44)
			var m2 := bmid + side * o
			if _item_on(items, m2, box.position.y + seat_h):
				continue
			var ft := m2 + fwd * People.SIT_BACK
			out.append([ft, atan2(fwd.x, fwd.z), seat_h, m2, two, drink and at_table, _open_from(dp, Vector2(ft.x, ft.z), walls)])
	return out


## На сиденье в точке m (высота верха top) стоит вещь: её низ у верха сиденья, место — под ней (с запасом на бёдра)
static func _item_on(items: Array, m: Vector3, top: float) -> bool:
	for ib: AABB in items:
		if absf(ib.position.y - top) < 0.15 and Rect2(ib.position.x - 0.18, ib.position.z - 0.18, ib.size.x + 0.36, ib.size.z + 0.36).has_point(Vector2(m.x, m.z)):
			return true
	return false


## От входа a до места b по прямой (в осях постройки) не мешает ничего высокого и недалеко
static func _open_from(a: Vector2, b: Vector2, walls: Array) -> bool:
	if a.distance_to(b) > 6.0:
		return false
	var n := int(a.distance_to(b) / 0.1) + 1
	for i in range(1, n):
		var q := a.lerp(b, float(i) / n)
		for r: Rect2 in walls:
			if r.has_point(q):
				return false
	return true


## Цветы у дома, которые поливают жильцы (People «water»): ящики под окнами первого этажа и горшки на мостовой перед
## фасадом. [[где стоять, на что смотреть]] в осях постройки — в полуметре перед цветами, лицом к ним
static func _find_water(bp: Bp) -> Array:
	var out := []
	if bp.kit_id != "":
		return out
	for p in bp.parts:
		var nm: String = p[0]
		var bed := nm.begins_with("SM_Prop_FlowerBed_0")
		var pot := nm.begins_with("SM_Prop_FlowerPot_Fancy") or nm.begins_with("SM_Prop_FlowerPot_0")
		if not bed and not pot:
			continue
		var xf: Transform3D = p[1]
		var box: AABB = xf * Bp.model_aabb(nm)
		if box.position.y > 0.9:
			continue                       # выше первого этажа — не дотянуться
		var c := box.get_center()
		var f := Vector3(xf.basis.z.x, 0, xf.basis.z.z).normalized() if bed else Vector3(c.x, 0, c.z).normalized()
		if f.z < 0.5:
			continue                       # только перед фасадом (к улице)
		var stand := Vector3(c.x, 0, c.z) + f * (0.32 + (box.size.z * 0.5 if bed else 0.1))
		out.append([stand, Vector3(c.x, 0, c.z)])
		if out.size() >= 3:
			break
	return out


func water(b: Dictionary) -> Array:
	return info(game.city.blueprint(b), String(b["type"]))["water"] if on else []


# ---------- постройку показали или убрали (Game._show / Game._hide) ----------

func shown(b: Dictionary) -> void:
	var id := int(b["id"])
	_forget(id)
	var bp: Bp = game.city.blueprint(b)
	var inf := info(bp, String(b["type"]))
	if not (inf["seats"] as Array).is_empty():
		var cell := Vector2i(floori((b["pos"] as Vector2).x / SEAT_CELL), floori((b["pos"] as Vector2).y / SEAT_CELL))
		var l: Array = _seat_grid.get(cell, [])
		l.append(id)
		_seat_grid[cell] = l
		_seat_cell[id] = cell
	if int(inf["pairs"]) > 0:
		var vis: Dictionary = game.visuals.get(id, {})
		var hs: Array = vis.get("h", [])
		var lh := []
		for e: Array in inf["shut"]:
			lh.append(hs[int(e[0])] if int(e[0]) < hs.size() else [])
		var np: int = inf["pairs"]
		var k := []
		k.resize(np)
		k.fill(1.0)                        # как построено — открыты
		var wait := []
		wait.resize(np)
		wait.fill(0.0)
		var t0 := []
		t0.resize(lh.size())
		var plan := []
		var pl := []
		for pi in np:
			plan.append(_plan(b, pi))
			pl.append([])
		for j in (inf["shut"] as Array).size():
			(pl[int((inf["shut"] as Array)[j][5])] as Array).append(j)
		var bp2: Vector2 = b["pos"]
		# обычные Array, а не Packed: их правят по месту (Packed из словаря — копия)
		var st := {"b": b, "house": game.city.is_house(b), "plan": plan, "pl": pl, "p3": Vector3(bp2.x, float(b["y"]) + 2.0, bp2.y),
			"k": k, "goal": k.duplicate(), "wait": wait, "h": lh, "t0": t0, "xf": game.city.xf(b), "inf": inf}
		_shut[id] = st
		_shut_ids.append(id)
		_shut_now(id, st, _hour(), true)   # сразу по часам (дом перестроили ночью — ставни уже закрыты)


func hidden(b: Dictionary) -> void:
	_forget(int(b["id"]))


## Постройку убрали или выставили заново: её места в пуле уже не её — забыть, ничего не возвращая (Parts.remove обнулил)
func _forget(id: int) -> void:
	_doors.erase(id)
	if _shut.has(id):
		_shut.erase(id)
		_shut_ids.erase(id)
		_moving.erase(id)
	if _seat_cell.has(id):
		var l: Array = _seat_grid.get(_seat_cell[id], [])
		l.erase(id)
		_seat_cell.erase(id)


# ---------- камера ----------

func _cam() -> Camera3D:
	var rig = game.rig if game else null
	return rig.cam if rig != null else null


## Точка в кадре и не дальше far от камеры
func _seen(p: Vector3, far: float) -> bool:
	var cam := _cam()
	if cam == null:
		return false
	return cam.global_position.distance_squared_to(p) < far * far and cam.is_position_in_frustum(p)


static func _dead(t: Transform3D) -> bool:
	return absf(t.basis.determinant()) < 1e-9


# ---------- двери ----------

## Житель входит в постройку b или выходит из неё: дверь распахнута ещё hold секунд (игровых), потом прикрывается.
## Постройка вне кадра или далеко — ничего не происходит
func door(b: Dictionary, hold: float) -> void:
	if not on or b.is_empty() or game == null:
		return
	var id := int(b["id"])
	if _doors.has(id):
		var d0: Dictionary = _doors[id]
		d0["hold"] = maxf(float(d0["hold"]), hold)
		return
	var bp: Bp = game.city.blueprint(b)
	var leaves: Array = info(bp, String(b["type"]))["doors"]
	if leaves.is_empty():
		return
	var dp: Vector2 = game.city.door_point(b)
	if not _seen(Vector3(dp.x, float(b["y"]) + 1.0, dp.y), DOOR_FAR):
		return
	var vis: Dictionary = game.visuals.get(id, {})
	var hs: Array = vis.get("h", [])
	var W: Transform3D = game.city.xf(b)
	var subs := []
	for e: Array in leaves:
		var pi: int = e[0]
		if pi >= hs.size():
			continue
		var g: Dictionary = (hs[pi] as Array)[0]
		var slot: int = (hs[pi] as Array)[1]
		var hw: Vector3 = W * (e[1] as Vector3)
		for sub in g["subs"]:
			var mm: MultiMesh = sub["mm"]
			if slot >= mm.instance_count:
				continue
			var t0 := mm.get_instance_transform(slot)
			if _dead(t0):
				continue                   # спрятана (ролик)
			subs.append([mm, slot, t0, hw, float(e[2])])
	if subs.is_empty():
		return
	_doors[id] = {"k": 0.0, "hold": hold, "subs": subs}


func _door_tick(sdt: float) -> void:
	for id in _doors.keys():
		var d: Dictionary = _doors[id]
		var k: float = d["k"]
		var k0 := k
		if float(d["hold"]) > 0.0:
			d["hold"] = float(d["hold"]) - sdt
			k = minf(1.0, k + sdt / DOOR_OPEN_T)
		else:
			k = maxf(0.0, k - sdt / DOOR_CLOSE_T)
		d["k"] = k
		if k <= 0.0:
			for s: Array in d["subs"]:
				var mm: MultiMesh = s[0]
				if int(s[1]) < mm.instance_count and not _dead(mm.get_instance_transform(int(s[1]))):
					mm.set_instance_transform(int(s[1]), s[2])       # как было — в точности
			_doors.erase(id)
			continue
		if k == k0:
			continue
		var subs: Array = d["subs"]
		var s0: Array = subs[0]
		if int(s0[1]) >= (s0[0] as MultiMesh).instance_count or _dead((s0[0] as MultiMesh).get_instance_transform(int(s0[1]))):
			continue                       # постройку спрятали (ролик) — не показывать её дверь
		var a := DOOR_ANG * smoothstep(0.0, 1.0, k)
		var ra := Basis(Vector3.UP, a)
		var rb := Basis(Vector3.UP, -a)
		for s: Array in subs:
			var mm: MultiMesh = s[0]
			var slot: int = s[1]
			if slot >= mm.instance_count:
				continue
			var hw: Vector3 = s[3]
			var r := ra if float(s[4]) > 0.0 else rb
			mm.set_instance_transform(slot, Transform3D(r, hw - r * hw) * (s[2] as Transform3D))
			moves += 1


## Дверь постройки id сейчас открыта на долю (0 — закрыта; для проверок)
func door_k(id: int) -> float:
	return float((_doors.get(id, {}) as Dictionary).get("k", 0.0))


# ---------- ставни ----------

## Расписание пары pi постройки b: Vector3(открыть в час, закрыть в час, 1 — открыта всю ночь). Дом — утром открывает
## (6–8 ч), вечером закрывает (20:30–23:30), каждое окно в свой час, четверть окон на ночь открыты. Лавка и прочие —
## днём (6:30–7:36 … 19:24–20:48). Пустой дом закрыт (это — в _want_p, по b.pop)
func _plan(b: Dictionary, pi: int) -> Vector3:
	var r := float(absi(hash(int(b["id"]) * 131 + pi * 17 + 5)) % 1000) / 1000.0
	if game.city.is_house(b):
		return Vector3(lerpf(6.0, 8.0, r), lerpf(20.5, 23.5, fmod(r * 7.31, 1.0)), 1.0 if fmod(r * 3.7, 1.0) < 0.25 else 0.0)
	return Vector3(lerpf(6.5, 7.6, r), lerpf(19.4, 20.8, fmod(r * 7.31, 1.0)), 0.0)


## Хочет ли пара pi постройки b быть открытой в час h (1 — да, 0 — нет)
func _want(b: Dictionary, pi: int, h: float) -> float:
	var st: Dictionary = _shut.get(int(b["id"]), {})
	var pl: Vector3 = (st["plan"] as Array)[pi] if not st.is_empty() else _plan(b, pi)
	return _want_p(bool(st.get("house", game.city.is_house(b))), int(b.get("pop", 0)), pl, h)


static func _want_p(house: bool, pop: int, pl: Vector3, h: float) -> float:
	if house and pop <= 0:
		return 0.0
	if pl.z > 0.5:
		return 1.0
	return 1.0 if h >= pl.x and h < pl.y else 0.0


func _hour() -> float:
	return float(game.look_hour) if float(game.look_hour) >= 0.0 else float(game.hour)


## Свести ставни постройки id с часом h: в кадре и близко — плавно и вразнобой, иначе — сразу (snap).
## Дёшево, когда менять нечего: только сравнения с готовым расписанием
func _shut_now(id: int, st: Dictionary, h: float, snap_all := false) -> void:
	var b: Dictionary = st["b"]
	var house: bool = st["house"]
	var pop := int(b.get("pop", 0))
	var plan: Array = st["plan"]
	var goal: Array = st["goal"]
	var k: Array = st["k"]
	var moving: bool = _moving.has(id)
	var np := plan.size()
	var first := -1
	for pi in np:
		var w := _want_p(house, pop, plan[pi], h)
		if w == float(goal[pi]) and (moving or w == float(k[pi])):
			continue
		first = pi
		break
	if first < 0:
		return
	var anim := not snap_all and _seen(st["p3"], SHUT_ANIM_R)
	var wait: Array = st["wait"]
	var changed := false
	for pi in range(first, np):
		var w := _want_p(house, pop, plan[pi], h)
		if w == float(goal[pi]) and (moving or w == float(k[pi])):
			continue
		goal[pi] = w
		if anim:
			wait[pi] = float(absi(hash(id * 7 + pi * 13)) % 1000) / 1000.0 * SHUT_STAGGER
			_moving[id] = true
		else:
			k[pi] = w
			changed = true
	if changed:
		for pi in np:
			_shut_pose(st, pi)


## Поставить створки пары pi постройки на её долю раскрытия
func _shut_pose(st: Dictionary, pi: int) -> void:
	var lv: Array = (st["inf"] as Dictionary)["shut"]
	var hs: Array = st["h"]
	var t0s: Array = st["t0"]
	var kk := smoothstep(0.0, 1.0, float((st["k"] as Array)[pi]))
	var W: Transform3D = st["xf"]
	for j: int in (st["pl"] as Array)[pi]:
		var hnd: Array = hs[j]
		if hnd.is_empty():
			continue
		var slot: int = hnd[1]
		if t0s[j] == null:
			if kk >= 1.0:
				continue                   # ещё не трогали и открыта — как построено
			var t0 := []
			for sub in (hnd[0] as Dictionary)["subs"]:
				var mm: MultiMesh = sub["mm"]
				if slot >= mm.instance_count:
					t0 = []
					break
				var x := mm.get_instance_transform(slot)
				if _dead(x):
					t0 = []
					break
				t0.append([mm, x])
			if t0.is_empty():
				continue                   # спрятана (ролик) — в другой раз
			t0s[j] = t0
		var m := Transform3D.IDENTITY
		if kk < 1.0:
			var e: Array = lv[j]
			var hw: Vector3 = W * (e[1] as Vector3)
			var ax: Vector3 = W.basis * (e[3] as Vector3)
			var r := Basis(Vector3.UP, (1.0 - kk) * PI * float(e[2]))
			var sw := lerpf(float(e[4]), 1.0, kk) - 1.0
			var S := Basis(Vector3(1, 0, 0) + ax * ax.x * sw, Vector3(0, 1, 0) + ax * ax.y * sw, Vector3(0, 0, 1) + ax * ax.z * sw)
			var rs := r * S
			m = Transform3D(rs, hw - rs * hw)
		for q: Array in t0s[j]:
			var mm: MultiMesh = q[0]
			if slot < mm.instance_count:
				mm.set_instance_transform(slot, m * (q[1] as Transform3D) if kk < 1.0 else (q[1] as Transform3D))
				moves += 1


func _shut_tick(dt: float) -> void:
	var n := _shut_ids.size()
	if n > 0:
		var cam := _cam()
		if cam != null:
			var cp := cam.global_position
			var h := _hour()
			var r2 := SHUT_SNAP_R * SHUT_SNAP_R
			for c in mini(SCAN_N, n):
				_scan_i = (_scan_i + 1) % n
				var id: int = _shut_ids[_scan_i]
				var st: Dictionary = _shut[id]
				if (st["p3"] as Vector3).distance_squared_to(cp) <= r2:
					_shut_now(id, st, h)
	if _moving.is_empty():
		return
	for id in _moving.keys():
		var st: Dictionary = _shut.get(id, {})
		if st.is_empty():
			_moving.erase(id)
			continue
		var goal: Array = st["goal"]
		var k: Array = st["k"]
		var wait: Array = st["wait"]
		var busy := false
		for pi in k.size():
			if k[pi] == goal[pi]:
				continue
			busy = true
			if float(wait[pi]) > 0.0:
				wait[pi] = float(wait[pi]) - dt
				continue
			k[pi] = move_toward(float(k[pi]), float(goal[pi]), dt / SHUT_T)
			_shut_pose(st, pi)
		if not busy:
			_moving.erase(id)


## Пара pi постройки id открыта на долю (1 — как построено; для проверок; −1 — средняя по парам)
func shut_k(id: int, pi := -1) -> float:
	var st: Dictionary = _shut.get(id, {})
	if st.is_empty():
		return 1.0
	var k: Array = st["k"]
	if pi >= 0:
		return k[pi]
	var s := 0.0
	for v in k:
		s += v
	return s / maxf(1.0, k.size())


# ---------- мебель: где присесть (People._furn_target) ----------

## Постройки с сиденьями не дальше maxd от точки
func seat_hosts(from: Vector2, maxd: float) -> Array:
	var out := []
	if not on:
		return out
	var c0 := Vector2i(floori(from.x / SEAT_CELL), floori(from.y / SEAT_CELL))
	var n := ceili(maxd / SEAT_CELL)
	for dz in range(-n, n + 1):
		for dx in range(-n, n + 1):
			for id in _seat_grid.get(c0 + Vector2i(dx, dz), []):
				var b: Dictionary = game.city.buildings.get(id, {})
				if not b.is_empty() and (b["pos"] as Vector2).distance_to(from) <= maxd and seat_open(b):
					out.append(b)
	return out


## Можно ли сейчас присесть у постройки b (таверна — днём, вечером её столы занимают гости Spectacle)
func seat_open(b: Dictionary) -> bool:
	if String(b["type"]) == "taberna":
		var h: float = game.hour
		return h >= float(SEAT_TAVERN_H[0]) and h < float(SEAT_TAVERN_H[1])
	return true


func seats(b: Dictionary) -> Array:
	return info(game.city.blueprint(b), String(b["type"]))["seats"]


# ---------- кадр ----------

## Замер (test_perf mode=lifeab): микросекунды Life._process за кадры замера
static var perf := false
var perf_us := 0
var perf_n := 0


func _process(dt: float) -> void:
	if perf:
		var t0 := Time.get_ticks_usec()
		_process_body(dt)
		perf_us += Time.get_ticks_usec() - t0
		perf_n += 1
	else:
		_process_body(dt)


func _process_body(dt: float) -> void:
	moves = 0
	if not on or game == null or game.city == null:
		return
	var sdt := minf(dt, 0.1) * float(game.speed)
	if not _doors.is_empty():
		_door_tick(sdt)
	_shut_tick(minf(dt, 0.1) * maxf(1.0, float(game.speed)))
