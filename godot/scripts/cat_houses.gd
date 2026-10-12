class_name CatHouses
extends RefCounted
## Облик жилья: дома плебеев, ремесленников, патрициев — маленькие, уютные, как в Town to City, но римские
## (Помпеи, Остия, Кампания). Чертёж Bp строится в родных размерах Synty (пролёт 2,5 м, этаж 3 м);
## Catalog.make потом уменьшает его до «кукольного» масштаба (Catalog.ARCH).
## Дом растёт вверх в пределах того же следа на земле: tier = число этажей. Третий этаж обычно отступает
## в глубину, а впереди — терраса (приземистый ступенчатый силуэт, как у домов Town to City).

const M := Bp.M
const FL := Bp.FL

# пролёты стен
const WALL := "SM_Bld_Wall_01"
const W1 := "SM_Bld_Wall_Window_01"      # окно (со ставнями и ящиком цветов)
const W2 := "SM_Bld_Wall_Window_02"      # три окошка под карнизами (только сбоку и сзади)
const W4 := "SM_Bld_Wall_Window_04"      # длинное окно под карнизом
const W5 := "SM_Bld_Wall_Window_05"      # окно с фронтоном
const W6 := "SM_Bld_Wall_Window_06"      # два арочных проёма (не больше одного на сторону этажа)
const D4 := "SM_Bld_Wall_Door_04"        # гладкий дверной проём
const D2 := "SM_Bld_Wall_Door_02"        # дверь в арке с каменным обрамлением
const D3 := "SM_Bld_Wall_Door_03"        # дверь с каменным наличником и полуциркульным верхом
const DOUBLE := "SM_Bld_Wall_Door_Double_01"   # парадная двустворчатая дверь домуса
const SHOP := "SM_Bld_Wall_Door_Large_02"  # широкий проём лавки/мастерской
const TRIM_MID := "SM_Bld_Trim_01"       # тонкий поясок между этажами (богатый карниз — только под крышей)
## Решётки окон тонируются тёплым деревом; за решёткой — тёмное стекло «#dark» (ночью в жилом доме светится)
const WIN_TINT := Color(1.0, 0.9, 0.8)
## Краска ставен (по серым доскам): зелёная (как в Town to City), бирюзовая, синяя, охра, бордо, тёмное дерево
const SHUTTERS := [Color(0.5, 0.95, 0.5), Color(0.45, 0.9, 0.85), Color(0.5, 0.7, 1.15), Color(1.25, 0.95, 0.5),
	Color(1.0, 0.5, 0.42), Color(0.8, 0.62, 0.45), Color(0.5, 0.95, 0.5)]
## Решётка балконов — прутья (крест-накрест «фахверк» не римский)
const BARS := {"Window_01": "Window_02", "tints": {"Window_02": WIN_TINT}}
const PANES := {
	"SM_Bld_Wall_Window_01": [[0.67, 0.75, 1.83, 1.9]],
	"SM_Bld_Wall_Window_05": [[0.67, 0.75, 1.83, 1.9]],
	"SM_Bld_Wall_Window_02": [[0.38, 1.47, 2.12, 2.05]],      # три окошка — одно стекло за стеной (между ними его прячет штукатурка)
	"SM_Bld_Wall_Window_04": [[0.38, 1.47, 2.12, 2.05]],
}

## Состояние текущего чертежа (сбрасывается в начале каждого дома): класс, решётки, был ли уже висячий балкон и т. п.
static var _st := {}
static var _corner_runs := {}     # угловые столбики коробок текущего чертежа (чтобы тянуть их вверх по этажам)


# =====================================================================================
#                                     набор деталей
# =====================================================================================

static func R(x0: float, x1: float, z0: float, z1: float) -> PackedFloat32Array:
	return PackedFloat32Array([x0, x1, z0, z1])


## Начало дома: класс жильцов, черепица (только терракота), решётки окон по классу, штукатурка без «фахверка»
static func _begin(b: Bp, cls: String) -> void:
	_corner_runs.clear()
	_st = {"cls": cls, "bal": 0, "mural": false, "close_k": b.rng.randi() % 2, "upwin": 0}
	# Решётки окон: W1 низ/верх, W5 низ/верх, оттенок дерева. Пока у решёток нет прозрачности (synty.gd), читается только
	# косой крест Window_01 (у остальных текстур проёмы и прутья одного тёмного цвета — окно выглядит чёрной дырой).
	# Когда прозрачность появится, патрициям можно дать узорные Window_03/04, плебеям внизу — прутья Window_02
	match cls:
		"pleb": _st["lat"] = ["Window_01", "Window_01", "Window_01", "Window_01", WIN_TINT]
		"artisan": _st["lat"] = ["Window_01", "Window_01", "Window_01", "Window_01", Color(0.95, 0.82, 0.7)]
		_: _st["lat"] = ["Window_01", "Window_01", "Window_01", "Window_01", Color(1.1, 1.0, 0.86)]
	_st["jrail"] = "stone" if cls == "patrician" else b.pick(["bars", "stucco", "stone", "stucco"])
	b.ground_style = "plain"
	if cls == "patrician":
		b.roof_tex = b.pick(["Roof_Tile_03", "Roof_Tile_12"])
	else:
		b.roof_tex = b.pick(["Roof_Tile_01", "Roof_Tile_01", "Roof_Tile_12", "Roof_Tile_03"])
	# узорная штукатурка (Stucco_White_Pattern) на этажах читается как фахверк — даже на белом (синие полосы);
	# у жилья штукатурка гладкая, богатство — в отделке
	b.upper_style = "plain"
	b.remap = b.floor_remap(1)


## Раскраска пролёта стены: штукатурка в цвет дома (и рустованный камень дверных пролётов — тоже)
static func _wr(b: Bp) -> Dictionary:
	var r: Dictionary = b.remap.duplicate(true)
	if r.has("Stucco_White_01"):
		r["Building_Large_Brick_01"] = r["Stucco_White_01"]
	return r


## То же для окон: решётка по классу и этажу (внизу у плебеев — прутья, вверху — косой крест; у патрициев — узор)
static func _wrw(b: Bp, f: int) -> Dictionary:
	var r := _wr(b)
	var lat: Array = _st.get("lat", ["Window_01", "Window_01", "Window_01", "Window_01", WIN_TINT])
	var hi := 0 if f == 0 else 1
	r["Window_01"] = lat[hi]
	r["Window_03"] = lat[2 + hi]
	var t: Dictionary = (r.get("tints", {}) as Dictionary).duplicate()
	for w: String in ["Window_01", "Window_02", "Window_03", "Window_04"]:
		t[w] = lat[4]
	r["tints"] = t
	return r


static func _put(b: Bp, nm: String, p: Vector3, yaw := 0.0, s := Vector3.ONE, remap := {}) -> void:
	b.parts.append([nm, b.base * Transform3D(Basis(Vector3.UP, yaw).scaled_local(s), p), remap])


## Точка на стороне прямоугольника r = [x0, x1, z0, z1]: сторона 0 — фасад (+Z), 1 — +X, 2 — зад, 3 — −X;
## u — метры вдоль стороны (слева направо, если смотреть снаружи), out — наружу от линии стены
static func _sp(r: PackedFloat32Array, side: int, u: float, y: float, out := 0.0) -> Array:
	match side:
		0: return [Vector3(r[0] + u, y, r[3] + out), 0.0]
		1: return [Vector3(r[1] + out, y, r[3] - u), PI / 2]
		2: return [Vector3(r[1] - u, y, r[2] - out), PI]
		_: return [Vector3(r[0] - out, y, r[2] + u), -PI / 2]


static func _on(b: Bp, nm: String, r: PackedFloat32Array, side: int, u: float, y: float, out := 0.0, s := 1.0, walls := false, yaw2 := 0.0) -> void:
	var a := _sp(r, side, u, y, out)
	_put(b, nm, a[0], float(a[1]) + yaw2, Vector3.ONE * s, b.remap.duplicate() if walls else {})


## Стекло окна: тёмная пластина «#dark» ЗА решёткой (решётку видно; ночью в жилом доме стекло светится сквозь неё)
static func _panes(b: Bp, nm: String, p: Vector3, yaw: float) -> void:
	if not PANES.has(nm):
		return
	var bs := Basis(Vector3.UP, yaw)
	for q: Array in PANES[nm]:
		var c := Vector3((float(q[0]) + float(q[2])) / 2.0, (float(q[1]) + float(q[3])) / 2.0, -0.035)
		var sz := Vector3(float(q[2]) - float(q[0]), float(q[3]) - float(q[1]), 0.03)
		b.parts.append(["#dark", b.base * Transform3D(bs * Basis.from_scale(sz), p + bs * c), {}])


static func _n(r: PackedFloat32Array, side: int) -> int:
	return maxi(1, int(round(((r[1] - r[0]) if side % 2 == 0 else (r[3] - r[2])) / M)))


## Этаж коробки r на уровне f: spec {сторона: [пролёты]}; "" — пропуск (там сосед/пристройка), нет в списке — глухая стена.
## o: cornice (карниз; TRIM_MID — тонкий поясок; "" — без), plinth (каменный цоколь), sides, corners, y
static func _storey(b: Bp, r: PackedFloat32Array, f: int, spec: Dictionary, o := {}) -> void:
	var y: float = o.get("y", f * FL)
	var cor: String = o.get("cornice", "SM_Bld_Trim_02")
	var cy := FL - (0.11 if cor == TRIM_MID else 0.33)
	var plinth: bool = o.get("plinth", f == 0)
	var sides: Array = o.get("sides", [0, 1, 2, 3])
	b.remap = b.floor_remap(f)
	var wr := _wr(b)
	var ww := _wrw(b, f)
	for side: int in sides:
		var names: Array = spec.get(side, [])
		var n := _n(r, side)
		# по бокам и сзади карниз и цоколь — одной деталью на всю стену (их видно наискосок);
		# тонкий поясок — одной деталью и на фасаде; богатый карниз и цоколь фасада — по пролётам
		var gaps := names.has("")
		var whole_c := (side != 0 or cor == TRIM_MID) and not gaps
		var whole_p := side != 0 and not gaps
		var i := 0
		while i < n:
			var nm: String = names[i] if i < names.size() else WALL
			if nm == "":
				i += 1
				continue
			# подряд идущие глухие пролёты сбоку и сзади — одной растянутой стеной
			var run := 1
			if side != 0 and nm == WALL:
				while i + run < n and (names[i + run] if i + run < names.size() else WALL) == WALL:
					run += 1
			var a := _sp(r, side, i * M, y)
			_put(b, nm, a[0], a[1], Vector3(run, 1, 1), ww if PANES.has(nm) else wr)
			if nm != W2 or side == 0:
				_panes(b, nm, a[0], a[1])
			for k in range(i, i + run):
				var ak := _sp(r, side, k * M, y)
				if cor != "" and (k == 0 or not whole_c):
					_put(b, cor, (ak[0] as Vector3) + Vector3(0, cy, 0), ak[1], Vector3(float(n) if whole_c else 1.0, 1, 1))
				if plinth and nm != SHOP and (k == 0 or not whole_p):
					_put(b, "SM_Bld_Trim_05", ak[0], ak[1], Vector3(float(n) if whole_p else 1.0, 1, 1))
			i += run
	# угловые столбики: если этаж ниже у той же коробки уже есть — вытянуть их на этаж выше, а не ставить новые
	var corners: Array = o.get("corners", [0, 1, 2, 3])
	var key := "%d|%s|%s" % [b.get_instance_id(), str(r), str(corners)]
	var prev: Dictionary = _corner_runs.get(key, {})
	if not prev.is_empty() and int(prev["f"]) == f - 1:
		prev["f"] = f
		var n := f - int(prev["f0"]) + 1
		for c: Array in prev["list"]:
			b.parts[c[0]][1] = b.base * Transform3D(Basis(Vector3.UP, c[2]).scaled_local(Vector3(1, n, 1)), c[1])
	else:
		var cr: Dictionary = b.remap.duplicate()
		var cs := [[Vector3(r[0], y, r[3]), 0.0], [Vector3(r[1], y, r[3]), PI / 2], [Vector3(r[1], y, r[2]), PI], [Vector3(r[0], y, r[2]), -PI / 2]]
		var lst := []
		for ci: int in corners:
			lst.append([b.parts.size(), cs[ci][0], cs[ci][1]])
			_put(b, "SM_Bld_Wall_End_01", cs[ci][0], cs[ci][1], Vector3.ONE, cr)
		_corner_runs[key] = {"f": f, "f0": f, "list": lst}
	b.remap = b.floor_remap(1)


## Угловые столбики коробки r (поставленные _storey) продлить ещё на этаж f — только углы idx
static func _extend_corners(b: Bp, r: PackedFloat32Array, f: int, idx: Array) -> bool:
	var key := "%d|%s|%s" % [b.get_instance_id(), str(r), str([0, 1, 2, 3])]
	var prev: Dictionary = _corner_runs.get(key, {})
	if prev.is_empty() or int(prev["f"]) != f - 1:
		return false
	var n := f - int(prev["f0"]) + 1
	for j: int in idx:
		var c: Array = prev["list"][j]
		b.parts[c[0]][1] = b.base * Transform3D(Basis(Vector3.UP, c[2]).scaled_local(Vector3(1, n, 1)), c[1])
	prev["f"] = f
	return true


## Тёмное нутро (ночью у жилых домов светится): в открытые двери и окна не видно травы насквозь
static func _dark(b: Bp, r: PackedFloat32Array, y0: float, y1: float) -> void:
	var s := Vector3(r[1] - r[0] - 0.5, y1 - y0 - 0.1, r[3] - r[2] - 0.5)
	b.parts.append(["#dark", b.base * Transform3D(Basis.IDENTITY.scaled(s), Vector3((r[0] + r[1]) / 2.0, (y0 + y1) / 2.0, (r[2] + r[3]) / 2.0)), {}])


## Нутро дома с лавками внизу: у первого этажа тёмная глубина отступает на метр — в лавке виден пол, прилавок и товар
static func _dark_shops(b: Bp, r: PackedFloat32Array, y1: float) -> void:
	_dark(b, R(r[0], r[1], r[2], r[3] - 0.85), 0.0, FL)
	if y1 > FL + 0.1:
		_dark(b, r, FL, y1)


## Створка двери в пролёте i стороны side; set_door — сюда входят жители (снаружи, перед дверью)
static func _door(b: Bp, r: PackedFloat32Array, side: int, i: int, leaf: String, y := 0.0, set_door := true) -> void:
	if leaf != "":
		var a := _sp(r, side, i * M + 0.75, y, -0.02)
		_put(b, leaf, a[0], a[1])
	if set_door:
		var d := _sp(r, side, i * M + 1.25, 0.0, 0.9)
		b.door = b.base * (d[0] as Vector3)


## Каменная ступенька перед дверью
static func _step(b: Bp, r: PackedFloat32Array, side: int, i: int) -> void:
	var a := _sp(r, side, i * M + 0.55, 0.0, 0.06)
	_put(b, "SM_Bld_Floor_Trim_01", a[0], a[1], Vector3(0.56, 1.0, 0.55))


## Парадная двустворчатая дверь домуса: створки во весь проём (2 м), широкая ступень; сюда входят жители
static func _grand_door(b: Bp, r: PackedFloat32Array, i: int) -> void:
	var nm := "SM_Bld_Door_Half_0%d" % b.pick([2, 3])
	for k in 2:
		var a := _sp(r, 0, i * M + 0.25 + k * 1.0, 0.0, -0.02)
		_put(b, nm, a[0], a[1], Vector3(2.0, 1.08, 1.0))
	var s := _sp(r, 0, i * M + 0.2, 0.0, 0.06)
	_put(b, "SM_Bld_Floor_Trim_01", s[0], s[1], Vector3(0.84, 1.0, 0.55))
	var d := _sp(r, 0, i * M + 1.25, 0.0, 0.9)
	b.door = b.base * (d[0] as Vector3)


## Ставни по бокам окна W1 (пролёт i, низ этажа y): дощатые створки, крашеные (shut — номер краски SHUTTERS).
## Доска — плоская стенка с текстурой досок: 20 треугольников вместо сотен у дверных створок.
## closed — створки закрыты (ночью это окно тёмное — дом не светится одинаковыми квадратами)
static func _shutters(b: Bp, r: PackedFloat32Array, side: int, i: int, y: float, shut: String, closed := false) -> void:
	var rm := {"Stucco_White_01": "Wood_02", "Stucco_Orange_01": "Wood_02", "tints": {"Wood_02": SHUTTERS[int(shut) % SHUTTERS.size()]}}
	if closed:
		for uu: float in [0.67, 1.25]:
			var a := _sp(r, side, i * M + uu, y + 0.7, 0.14)
			_put(b, WALL, a[0], a[1], Vector3(0.232, 0.4, 0.3), rm)
		return
	for uu: float in [0.61 - 0.44, 1.89]:
		var a := _sp(r, side, i * M + uu, y + 0.7, 0.16)
		_put(b, WALL, a[0], a[1], Vector3(0.176, 0.4, 0.3), rm)


## Ящик с цветами под окном W1: верх — у подоконника; наверху задняя стенка — вплотную к штукатурке,
## внизу ящик стоит на выступе цоколя (так он не входит в след дома на земле)
static func _wbox(b: Bp, r: PackedFloat32Array, side: int, i: int, y: float) -> void:
	var nm := "SM_Prop_FlowerBed_0%d" % (1 + b.rng.randi() % 2)
	if y < 1.0 and side == 0:
		_front_put(b, nm, r, i * M + 1.25, y + 0.62, 0.6)
		return
	var a := _sp(r, side, i * M + 1.25, y + 0.62, 0.15)
	_put(b, nm, a[0], a[1], Vector3.ONE * 0.6)


## Вещь на мостовой перед фасадом r (u — метры вдоль фасада): задней кромкой — в CLEAR от линии стены.
## Ближе нельзя: вещь войдёт в след дома на земле, а фасад встаёт вплотную к дороге
const CLEAR := 0.24
static func _front_put(b: Bp, nm: String, r: PackedFloat32Array, u: float, y: float, s: float, yaw := 0.0, gap := 0.0) -> void:
	var box := Bp.model_aabb(nm)
	var bs := Basis(Vector3.UP, yaw).scaled_local(Vector3.ONE * s)
	var mz := INF
	for k in 8:
		mz = minf(mz, (bs * box.get_endpoint(k)).z)
	_put(b, nm, Vector3(r[0] + u, y, r[3] + CLEAR + gap - mz), yaw, Vector3.ONE * s)


## Окно со ставнями и цветами; одно окно верхнего этажа на фасаде — с закрытыми ставнями
static func _win(b: Bp, r: PackedFloat32Array, side: int, i: int, f: int, leaf: String, box := true) -> void:
	var closed := false
	if f >= 1 and side == 0:
		closed = int(_st.get("upwin", 0)) == int(_st.get("close_k", 0))
		_st["upwin"] = int(_st.get("upwin", 0)) + 1
	_shutters(b, r, side, i, f * FL, leaf, closed)
	if box:
		_wbox(b, r, side, i, f * FL)


## Римский фонарь на кронштейне (ночью горит)
static func _lamp(b: Bp, r: PackedFloat32Array, side: int, u: float, y := 2.25) -> void:
	var a := _sp(r, side, u, y, 0.11)
	_put(b, "#wall_lamp", a[0], a[1])
	b.light((a[0] as Vector3) + Basis(Vector3.UP, a[1]) * Vector3(0, -0.2, 0.42))


## Светильник в глубине портика/лоджии: фонарь на стене r (сторона side, u) или бронзовый светильник на полу (r пуст)
static func _hang_lamp(b: Bp, p: Vector3, r := PackedFloat32Array(), side := 0, u := 0.0) -> void:
	if r.size() == 4:
		_lamp(b, r, side, u, minf(2.3, p.y - 0.4))
	else:
		_put(b, "SM_Prop_Senser_02", p, 0.0, Vector3.ONE * 0.9)
		b.light(p + Vector3(0, 0.75, 0))


## Табличка-знак (символ) на стене
static func _plaque(b: Bp, r: PackedFloat32Array, side: int, u: float, y: float, s := 0.42) -> void:
	_on(b, "SM_Prop_Symbol_%02d" % b.pick([1, 2, 3, 4, 6, 8, 9, 10]), r, side, u, y, 0.12, s)    # лёгкие таблички


## Висячие горшки / корзина с цветами на стене
static func _hang_pots(b: Bp, r: PackedFloat32Array, side: int, u: float, y: float) -> void:
	_on(b, "SM_Prop_FlowerPot_Hanging_0%d" % (4 + b.rng.randi() % 3), r, side, u, y - 0.25, 0.11, 0.6)


## «Французский» балкончик перед дверью верхнего этажа: у каждого дома свой — решётка из прутьев,
## штукатуреный парапет в цвет дома или каменная балюстрада на плите; иногда с ковром
static func _jbal(b: Bp, r: PackedFloat32Array, side: int, i: int, f: int, rug := true) -> void:
	var y := f * FL
	match String(_st.get("jrail", "stucco")):
		"bars":
			var a := _sp(r, side, i * M, y, 0.2)
			_put(b, "SM_Bld_Wall_Balcony_03", a[0], a[1], Vector3.ONE, BARS)
		"stone":
			var s := _sp(r, side, i * M + 0.25, y - 0.14, 0.11)
			_put(b, "SM_Bld_Floor_Trim_01", s[0], s[1], Vector3(0.8, 1.0, 0.5))
			var a := _sp(r, side, i * M + 0.25, y, 0.33)
			_put(b, "SM_Bld_Wall_Balcony_06", a[0], a[1], Vector3(0.8, 1, 1), b.remap.duplicate())
		_:
			var a := _sp(r, side, i * M + 0.2, y, 0.22)
			_put(b, "SM_Bld_Wall_Balcony_04", a[0], a[1], Vector3(0.84, 1, 1), b.remap.duplicate())
	if rug and b.chance(0.6):
		var q := _sp(r, side, i * M + b.rng.randf_range(0.7, 1.8), y + 0.95, 0.3)
		_put(b, "SM_Prop_Rug_Drape_01", q[0], float(q[1]) + PI, Vector3.ONE * 0.75)
	else:
		_on(b, "SM_Prop_FlowerPot_Hanging_0%d" % (4 + b.rng.randi() % 3), r, side, i * M + 0.5, y + 0.95, 0.3, 0.55)


## Деревянный балкон на консолях (как «висячий балкон» в Помпеях) с ковром и горшком — не больше одного на дом;
## следующие — балкончики _jbal
static func _balcony(b: Bp, r: PackedFloat32Array, side: int, i: int, f: int, pot := true) -> void:
	if int(_st.get("bal", 0)) >= 1:
		_jbal(b, r, side, i, f, pot)
		return
	_st["bal"] = 1
	var a := _sp(r, side, i * M + 1.25, f * FL, 0.11)
	_put(b, "SM_Bld_Balcony_01", a[0], a[1], Vector3.ONE, BARS)
	if pot:
		var p := _sp(r, side, i * M + 0.45, f * FL + 0.0, 0.62)
		_put(b, "SM_Prop_FlowerPot_Fancy_01", (p[0] as Vector3) + Vector3(0, 0.57 * 0.5, 0), 0.0, Vector3.ONE * 0.5)
	if b.chance(0.7 if pot else 0.4):
		var q := _sp(r, side, i * M + b.rng.randf_range(1.1, 1.9), f * FL + 0.88, 1.12)
		_put(b, "SM_Prop_Rug_Drape_01", q[0], float(q[1]) + PI, Vector3.ONE * 0.8)


## Расписной фриз (меандр) под карнизом над окнами этажа f — по пролётам с простыми окнами или глухой стеной.
## Не больше одного этажа на дом (яркая роспись повсюду смотрится современно)
static func _frieze(b: Bp, r: PackedFloat32Array, side: int, f: int, names: Array) -> void:
	if _st.get("mural", false):
		return
	_st["mural"] = true
	var nm := "SM_Prop_Mural_0%d" % (3 + b.rng.randi() % 2)
	var rm := {"tints": {"Mural_01": Color(0.9, 0.8, 0.72)}}     # роспись чуть приглушить — меньше «плаката»
	for i in names.size():
		if names[i] in [W1, W6, WALL]:
			var a := _sp(r, side, i * M + 1.25, f * FL + 2.4, 0.11)
			_put(b, nm, a[0], a[1], Vector3.ONE, rm)


## Медальон в треугольнике фронтона — небольшой, мраморный, и не на каждом доме
static func _medallion(b: Bp, r: PackedFloat32Array, side: int, u: float, y: float) -> void:
	if not b.chance(0.5):
		return
	var a := _sp(r, side, u, y, 0.12)
	_put(b, "SM_Bld_Ornament_0%d" % b.pick([1, 2, 4, 5]), a[0], a[1], Vector3.ONE * b.rng.randf_range(0.45, 0.55),
		{"PolygonAncientEmpire_01_A": "Building_Marble_02"})


## Плющ (с цветами) на стене
static func _ivy(b: Bp, r: PackedFloat32Array, side: int, u: float, y: float, flowers := true, s := 1.0) -> void:
	var nm := ("SM_Env_Ivy_Flowers_%02d" if flowers else "SM_Env_Ivy_%02d") % b.pick([1, 2, 3, 4, 5, 8, 9])
	_on(b, nm, r, side, u, y, 0.13, s)


## Плющ свисает с парапета террасы
static func _ivy_drape(b: Bp, r: PackedFloat32Array, side: int, u: float, y: float) -> void:
	_on(b, "SM_Env_Ivy_Draped_Flowers_0%d" % b.pick([1, 2, 3]), r, side, u, y, 0.12)


## Амфора/кувшин/корзина на земле
static func _jar(b: Bp, p: Vector3, s := 0.8) -> void:
	var nm: String = b.pick(["SM_Prop_Vase_02", "SM_Prop_Vase_05", "SM_Prop_Vase_01", "SM_Prop_Jar_01", "SM_Prop_Vase_03"])
	_put(b, nm, p, b.rng.randf() * TAU, Vector3.ONE * s)


## Горшок с растением (на земле или на террасе)
static func _pot(b: Bp, p: Vector3, s := 0.55) -> void:
	_put(b, "SM_Prop_FlowerPot_Fancy_01", p + Vector3(0, 0.57 * s, -0.41 * s), 0.0, Vector3.ONE * s)


static func _bench(b: Bp, p: Vector3, yaw := 0.0) -> void:
	_put(b, "SM_Prop_Seat_Bench_01", p, yaw, Vector3.ONE * 0.85)


## Скамья у стены под окном пролёта i (ящика цветов под этим окном нет) и горшок у её края
static func _street_bench(b: Bp, r: PackedFloat32Array, i: int) -> void:
	_bench(b, Vector3(r[0] + i * M + 1.25, 0, r[3] + 0.5))
	_pot(b, Vector3(r[0] + i * M + (0.22 if b.chance(0.5) else 2.28), 0, r[3] + 0.46), 0.45)


## Задняя стена этажа: внизу окно с решёткой, на втором этаже окно со ставнями, выше — окошки
static func _bk(b: Bp, r: PackedFloat32Array, f: int, shut: String) -> Array:
	var n := _n(r, 2)
	var a := []
	for i in n:
		a.append(WALL)
	var i := f % n
	if f == 0:
		a[i] = W1          # окно без ставен (решётку видно), а не пара арочных дырочек
	elif f == 1:
		a[i] = W1
		_shutters(b, r, 2, i, f * FL, shut)
	else:
		a[i] = W2
	return a


## Приставленная к стене лестница или сноп соломы (не у каждого дома)
static func _leaning(b: Bp, r: PackedFloat32Array, side: int, u: float) -> void:
	if not b.chance(0.4):
		return
	var ladder := b.chance(0.5)
	var a := _sp(r, side, u, 0.0, 0.5 if ladder else 0.3)
	var xf := Transform3D(Basis(Vector3.UP, a[1]) * Basis(Vector3.RIGHT, -0.15 if ladder else -0.1).scaled(Vector3.ONE * 0.85), a[0])
	b.add_xf("SM_Prop_Ladder_01" if ladder else "SM_Prop_Straw_Bundle_01", xf)


## Печная труба на крыше (беленая, с терракотовой шапкой и тёмным дымоходом, как в Town to City) — из неё дымок;
## p — низ трубы на скате
static func _chimney(b: Bp, p: Vector3) -> void:
	_put(b, "#chimney", p, 0.0, Vector3(1.0, 0.95, 1.0))
	_smoke(b, p + Vector3(0, 1.22, 0))


static func _smoke(b: Bp, p: Vector3) -> void:
	b.smoke.append(b.base * p)


# ---------- крыши ----------

static func _fput(b: Bp, frame: Transform3D, nm: String, p: Vector3, yaw: float, s: Vector3, remap: Dictionary) -> void:
	b.parts.append([nm, b.base * frame * Transform3D(Basis(Vector3.UP, yaw).scaled_local(s), p), remap])


## Двускатная черепичная крыша над r: конёк вдоль X, или вдоль Z (along_z — фронтоном к улице). ky — крутизна.
## detail — пятна переложенной черепицы; back — торец со стороны −Z (у навеса над дверью он упирается в стену).
## Возвращает высоту конька
static func _gable(b: Bp, r: PackedFloat32Array, top: float, ky := 1.6, along_z := false, topper := "", detail := true, back := true) -> float:
	var L := (r[3] - r[2]) if along_z else (r[1] - r[0])
	var S := (r[1] - r[0]) if along_z else (r[3] - r[2])
	var frame := Transform3D(Basis(Vector3.UP, PI / 2 if along_z else 0.0), Vector3((r[0] + r[1]) / 2.0, 0, (r[2] + r[3]) / 2.0))
	var k := S / 2.0 / M
	var n := maxi(1, int(round(L / M)))
	var seg := L / n
	var x0 := -L / 2.0
	var x1 := L / 2.0
	var z0 := -S / 2.0
	var z1 := S / 2.0
	var rr: Dictionary = b.remap.duplicate()
	for i in n:
		_fput(b, frame, "SM_Bld_Roof_Base_Straight_01", Vector3(x0 + i * seg, top, z1), 0.0, Vector3(seg / M, k * ky, k), rr)
		_fput(b, frame, "SM_Bld_Roof_Base_Straight_01", Vector3(x1 - i * seg, top, z0), PI, Vector3(seg / M, k * ky, k), rr)
		_fput(b, frame, "SM_Bld_Roof_Edge_Straight_01", Vector3(x0 + i * seg, top, z1), 0.0, Vector3(seg / M, 1, 1), rr)
		_fput(b, frame, "SM_Bld_Roof_Edge_Straight_01", Vector3(x1 - i * seg, top, z0), PI, Vector3(seg / M, 1, 1), rr)
	var ends := [[Vector3(x0, top, z1), 0.0], [Vector3(x0, top, z0), PI]]
	if back:
		ends.append_array([[Vector3(x1, top, z0), PI], [Vector3(x1, top, z1), 0.0]])
	for c: Array in ends:
		_fput(b, frame, "SM_Bld_Roof_Base_Straight_Side_01", c[0], c[1], Vector3(1, k * ky, k), rr)
	# переложенная черепица пятнами — крыша не гладкая
	if detail:
		var di := b.rng.randi() % n
		if b.chance(0.5):
			_fput(b, frame, "SM_Bld_Roof_Detail_0%d" % (1 + b.rng.randi() % 2), Vector3(x0 + di * seg, top, z1), 0.0, Vector3(seg / M, k * ky, k), rr)
		else:
			_fput(b, frame, "SM_Bld_Roof_Detail_0%d" % (1 + b.rng.randi() % 2), Vector3(x1 - di * seg, top, z0), PI, Vector3(seg / M, k * ky, k), rr)
	var ridge := top + 0.75 * k * ky
	if topper != "":
		_fput(b, frame, topper, Vector3(x0 + 0.1, ridge - 0.04, 0), PI / 2, Vector3.ONE, {})
		if back:
			_fput(b, frame, topper, Vector3(x1 - 0.1, ridge - 0.04, 0), PI / 2, Vector3.ONE, {})
	return ridge


## Вальмовая (четырёхскатная) крыша над r из угловых скатов; на длинном доме — с коньком посередине
static func _hip(b: Bp, r: PackedFloat32Array, top: float, ky := 1.6, topper := "") -> float:
	var w := r[1] - r[0]
	var d := r[3] - r[2]
	var along_z := d > w + 0.01
	var L := maxf(w, d)
	var S := minf(w, d)
	var frame := Transform3D(Basis(Vector3.UP, PI / 2 if along_z else 0.0), Vector3((r[0] + r[1]) / 2.0, 0, (r[2] + r[3]) / 2.0))
	var s := S / 2.0 / M
	var x0 := -L / 2.0
	var x1 := L / 2.0
	var z0 := -S / 2.0
	var z1 := S / 2.0
	var rr: Dictionary = b.remap.duplicate()
	var sc := Vector3(s, s * ky, s)
	_fput(b, frame, "SM_Bld_Roof_Base_Corner_01", Vector3(x0, top, z1), 0.0, sc, rr)
	_fput(b, frame, "SM_Bld_Roof_Base_Corner_01", Vector3(x1, top, z1), PI / 2, sc, rr)
	_fput(b, frame, "SM_Bld_Roof_Base_Corner_01", Vector3(x1, top, z0), PI, sc, rr)
	_fput(b, frame, "SM_Bld_Roof_Base_Corner_01", Vector3(x0, top, z0), -PI / 2, sc, rr)
	var mid := L - S
	var ridge := top + 0.75 * s * ky
	if mid > 0.3:
		var n := maxi(1, int(round(mid / M)))
		var seg := mid / n
		for i in n:
			_fput(b, frame, "SM_Bld_Roof_Base_Straight_01", Vector3(x0 + S / 2.0 + i * seg, top, z1), 0.0, Vector3(seg / M, s * ky, s), rr)
			_fput(b, frame, "SM_Bld_Roof_Base_Straight_01", Vector3(x1 - S / 2.0 - i * seg, top, z0), PI, Vector3(seg / M, s * ky, s), rr)
	if topper != "":
		if mid > 0.3:
			_fput(b, frame, topper, Vector3(x0 + S / 2.0, ridge, 0), PI / 2, Vector3.ONE, {})
			_fput(b, frame, topper, Vector3(x1 - S / 2.0, ridge, 0), PI / 2, Vector3.ONE, {})
		else:
			_fput(b, frame, topper, Vector3(0, ridge, 0), 0.0, Vector3.ONE, {})
	return ridge


## Односкатная черепичная кровля над r: низкий край со стороны low_side (0 — к улице), высокий — напротив.
## edge — черепичный край по нижней кромке
static func _lean(b: Bp, r: PackedFloat32Array, top: float, ky := 1.0, low_side := 0, edge := true, ends := true) -> float:
	var yaw: float = [0.0, PI / 2, PI, -PI / 2][low_side]
	var L := (r[1] - r[0]) if low_side % 2 == 0 else (r[3] - r[2])
	var S := (r[3] - r[2]) if low_side % 2 == 0 else (r[1] - r[0])
	var frame := Transform3D(Basis(Vector3.UP, yaw), Vector3((r[0] + r[1]) / 2.0, 0, (r[2] + r[3]) / 2.0))
	var k := S / M
	var n := maxi(1, int(round(L / M)))
	var seg := L / n
	var rr: Dictionary = b.remap.duplicate()
	for i in n:
		_fput(b, frame, "SM_Bld_Roof_Base_Straight_01", Vector3(-L / 2.0 + i * seg, top, S / 2.0), 0.0, Vector3(seg / M, k * ky, k), rr)
		if edge:
			_fput(b, frame, "SM_Bld_Roof_Edge_Straight_01", Vector3(-L / 2.0 + i * seg, top, S / 2.0), 0.0, Vector3(seg / M, 1, 1), rr)
	if ends:
		_fput(b, frame, "SM_Bld_Roof_Base_Straight_Side_01", Vector3(-L / 2.0, top, S / 2.0), 0.0, Vector3(1, k * ky, k), rr)
		_fput(b, frame, "SM_Bld_Roof_Base_Straight_Side_01", Vector3(L / 2.0, top, S / 2.0), 0.0, Vector3(1, k * ky, k), rr)
	return top + 0.75 * k * ky


## Плоская крыша-терраса (пол из черепицы) с парапетом по сторонам rails
static func _terrace(b: Bp, r: PackedFloat32Array, top: float, rails := [0, 1, 3], rail := "SM_Bld_Wall_Balcony_04") -> void:
	var rr: Dictionary = b.remap.duplicate()
	# пол: плиты по 2,5 м в глубину, вдоль фасада — не больше двух (растянуты)
	var nx := _n(r, 0)
	var cnt := (nx + 1) / 2
	var sx := float(nx) / cnt
	for i in cnt:
		for j in _n(r, 1):
			_put(b, "SM_Bld_Roof_Base_Flat_02", Vector3(r[0] + i * M * sx, top - 0.68, r[3] - j * M), 0.0, Vector3(sx, 1, 1), rr)
	# гладкий штукатурный парапет — одной деталью на сторону, балюстрада — по пролётам
	for side: int in rails:
		var n := _n(r, side)
		if rail == "SM_Bld_Wall_Balcony_04":
			var a := _sp(r, side, 0.0, top)
			_put(b, rail, a[0], a[1], Vector3(n, 1, 1), b.remap.duplicate())
		else:
			for i in n:
				_on(b, rail, r, side, i * M, top, 0.0, 1.0, true)


## Обстановка террасы (пол на высоте y): горшки по углам, ковёр или плющ на парапете, скамья или столик с табуретом
static func _terrace_dress(b: Bp, rf: PackedFloat32Array, y: float) -> void:
	var ty := y + 0.07
	var w := rf[1] - rf[0]
	_pot(b, Vector3(rf[0] + 0.45, ty, rf[3] - 0.45))
	_pot(b, Vector3(rf[1] - 0.45, ty, rf[3] - 0.45), 0.5)
	if b.chance(0.65):
		_on(b, "SM_Prop_Rug_Drape_01", rf, 0, b.rng.randf_range(1.0, w - 1.0), y + 1.0, 0.0, 0.8, false, PI)
	else:
		_ivy_drape(b, rf, 0, b.rng.randf_range(1.0, w - 1.0), y + 1.0)
	var cx := (rf[0] + rf[1]) / 2.0 + (b.rng.randf_range(-1.6, 1.6) if w > 6.0 else 0.0)
	if b.chance(0.5 if w < 6.0 else 0.7):
		_bench(b, Vector3(cx + b.rng.randf_range(-0.6, 0.6), ty, rf[2] + 0.75))
	else:
		_put(b, "SM_Prop_Table_07", Vector3(cx + 0.3, ty, rf[2] + 1.2), 0.0, Vector3.ONE * 0.9)
		_put(b, "SM_Prop_Stool_01", Vector3(cx - 0.5, ty, rf[2] + 1.25), 0.4)
		_put(b, "SM_Prop_Jug_05", Vector3(cx + 0.3, ty + 0.5, rf[2] + 1.2), 0.0)


## Верхний этаж f в глубине (как в Town to City): на задней половине r — комната (пролёты фасада top),
## на передней — терраса с парапетом над этажом ниже. Возвращает прямоугольник комнаты (для крыши)
static func _setback(b: Bp, r: PackedFloat32Array, f: int, top: Array, cor: String, shut: String, rails := [0, 1, 3], cbox := PackedFloat32Array()) -> PackedFloat32Array:
	var zm := r[3] - 2.5
	var rb := R(r[0], r[1], r[2], zm)
	var rf := R(r[0], r[1], zm, r[3])
	b.remap = b.floor_remap(f - 1)
	_terrace(b, rf, f * FL, rails, _rail(b) if r[1] - r[0] < 6.0 else "SM_Bld_Wall_Balcony_04")
	b.remap = b.floor_remap(1)
	var ns := _n(rb, 1)
	var s1 := [W6] if ns == 1 else [W6, WALL]
	var s3 := [W2] if ns == 1 else [WALL, W2]
	# задние углы комнаты — продолжение углов дома: вытягиваем их, а новые ставим только спереди
	var ext := _extend_corners(b, cbox if cbox.size() == 4 else r, f, [2, 3])
	_storey(b, rb, f, {0: top, 1: s1, 2: _bk(b, rb, f, shut), 3: s3}, {"cornice": cor, "corners": [0, 1] if ext else [0, 1, 2, 3]})
	for i in top.size():
		if top[i] == D4:
			_door2(b, rb, 0, i, f)
		elif top[i] == W1:
			_win(b, rb, 0, i, f, shut, false)
	_dark(b, rb, f * FL, (f + 1) * FL)
	_terrace_dress(b, rf, f * FL)
	return rb


## Пергола с виноградом на террасе (пол на высоте y) над прямоугольником 2,5×2,5 с углом (x, z)
static func _pergola(b: Bp, x: float, z: float, y: float, seat := true) -> void:
	for c: Vector3 in [Vector3(x + 0.3, y, z + 0.3), Vector3(x + M - 0.3, y, z + 0.3), Vector3(x + 0.3, y, z + M - 0.3), Vector3(x + M - 0.3, y, z + M - 0.3)]:
		_put(b, "SM_Bld_Trellis_Pillar_01", c, 0.0, Vector3.ONE * 0.75)
	_put(b, "SM_Bld_Trellis_Roof_01", Vector3(x + M, y + 2.3, z), 0.0)
	# лоза густо: две плети накрест, свисают с краёв
	var a := b.rng.randf() * TAU
	_put(b, "SM_Env_Vine_0%d" % (1 + b.rng.randi() % 3), Vector3(x + M / 2.0 - 0.3, y + 2.3, z + M / 2.0), a, Vector3.ONE * 1.3)
	_put(b, "SM_Env_Vine_0%d" % (1 + b.rng.randi() % 3), Vector3(x + M / 2.0 + 0.3, y + 2.3, z + M / 2.0 + 0.3), a + PI / 2, Vector3.ONE * 1.2)
	if seat:
		_bench(b, Vector3(x + M / 2.0, y, z + M / 2.0 - 0.3))


## Низкая оштукатуренная ограда от a до c (по земле), высота h; в цвет дома
static func _lowwall(b: Bp, a: Vector3, c: Vector3, h := 1.0, coping := true) -> void:
	var d := c - a
	var len := d.length()
	if len < 0.1:
		return
	var yaw := atan2(-d.z, d.x)
	b.remap = b.floor_remap(0)
	_put(b, WALL, a, yaw, Vector3(len / M, h / 3.01, 1.0), _wr(b))
	if coping:
		# каменный поясок по верху — с лицевой стороны (к улице)
		_put(b, "SM_Bld_Trim_01", a + Vector3(0, h - 0.06, 0), yaw, Vector3(len / M, 1, 1))
	b.remap = b.floor_remap(1)


# ---------- случайный выбор отделки (у каждого дома своя) ----------

static func _leaf(b: Bp) -> String:
	return b.pick(["SM_Bld_Door_05", "SM_Bld_Door_01", "SM_Bld_Door_02", "SM_Bld_Door_05"])


static func _shut(b: Bp) -> String:
	return str(b.rng.randi() % SHUTTERS.size())


## Створки двери на балкон/террасу (двустворчатая, из половинок)
static func _door2(b: Bp, r: PackedFloat32Array, side: int, i: int, f: int) -> void:
	var nm := "SM_Bld_Door_Half_0%d" % b.pick([2, 3])
	for uu: float in [0.75, 1.25]:
		var a := _sp(r, side, i * M + uu, f * FL, -0.02)
		_put(b, nm, a[0], a[1])


static func _rail(b: Bp) -> String:
	return b.pick(["SM_Bld_Wall_Balcony_04", "SM_Bld_Wall_Balcony_06"])


static func _cor(b: Bp) -> String:
	return b.pick(["SM_Bld_Trim_02", "SM_Bld_Trim_02", "SM_Bld_Trim_03"])    # 4-й карниз слишком тяжёлый (600 треугольников)


static func _topper(b: Bp) -> String:
	return "SM_Bld_Roof_Topper_0%d" % b.pick([1, 2, 3, 5, 6])    # 4-й похож на крест — не для Рима


## Дверной пролёт: у плебеев почти всегда гладкий (рустованные — по 1200–1300 треугольников)
static func _door_bay(b: Bp) -> String:
	if _st.get("cls", "") == "pleb":
		return b.pick([D4, D4, D4, D3])
	return b.pick([D4, D4, D3])


# =====================================================================================
#                                     дома плебеев
# =====================================================================================

## Дом плебеев (след до 5×5 м): пять обликов, 1–3 этажа
static func _house_pleb(b: Bp, floors: int, v: int) -> void:
	floors = clampi(floors, 1, 3)
	_begin(b, "pleb")
	match v % 5:
		0: _pleb_terrace(b, floors)
		1: _pleb_torretta(b, floors)
		2: _pleb_casetta(b, floors)
		3: _pleb_portico(b, floors)
		_: _pleb_fronte(b, floors)


## 0 «Терраса» — как в Town to City: низ во всю глубину, верхний этаж отступает назад, впереди терраса с парапетом
static func _pleb_terrace(b: Bp, floors: int) -> void:
	var di := b.rng.randi() % 2
	var wi := 1 - di
	var r0 := R(-2.5, 2.5, -2.5, 2.5)
	var cor := _cor(b)
	var shut := _shut(b)
	var front := [W1, W1]
	front[di] = _door_bay(b)
	_storey(b, r0, 0, {0: front, 1: [W6, WALL], 2: _bk(b, r0, 0, shut), 3: [WALL, W6]}, {"cornice": cor if floors == 1 else TRIM_MID})
	_door(b, r0, 0, di, _leaf(b))
	_step(b, r0, 0, di)
	_win(b, r0, 0, wi, 0, shut, false)
	_street_bench(b, r0, wi)
	_lamp(b, r0, 0, 2.5, 2.25)
	_leaning(b, r0, 2, b.rng.randf_range(0.6, 4.4))
	if b.chance(0.3):
		_frieze(b, r0, 0, 0, front)
	_plaque(b, r0, 0, di * M + 1.25, 2.12)
	_hang_pots(b, r0, 0, di * M + (0.2 if di == 1 else 2.3), 2.55)
	_jar(b, Vector3(r0[0] + di * M + (2.25 if di == 0 else 0.25), 0, r0[3] + 0.6))
	_ivy(b, r0, b.pick([1, 3]), b.rng.randf_range(1.0, 4.0), 1.5)
	if floors == 1:
		_dark(b, r0, 0.0, FL)
		var ridge := _hip(b, r0, FL, 1.5, _topper(b))
		_chimney(b, Vector3(0.9, ridge - 0.62, 0.0))
		return
	# средний этаж (у трёхэтажного) — во всю глубину
	for f in range(1, floors - 1):
		var mid := [W1, W1]
		mid[di] = D4
		_storey(b, r0, f, {0: mid, 1: [W2, WALL], 2: _bk(b, r0, f, shut), 3: [WALL, W2]}, {"cornice": TRIM_MID})
		_win(b, r0, 0, wi, f, shut)
		_jbal(b, r0, 0, di, f)
		_door2(b, r0, 0, di, f)
	var ft := floors - 1
	_dark(b, r0, 0.0, ft * FL)
	var top := [W1, W1]
	top[b.rng.randi() % 2] = D4
	var rb := _setback(b, r0, ft, top, cor, shut)
	var ridge := _gable(b, rb, floors * FL, 2.0, false, _topper(b))
	_chimney(b, Vector3(1.2, ridge - 0.25, -1.25))


## 1 «Торретта»: узкая башня фронтоном к улице + пристройка с террасой и перголой, за ней дворик
static func _pleb_torretta(b: Bp, floors: int) -> void:
	var left := b.chance(0.5)
	var tx := -2.5 if left else 0.0
	var ax := 0.0 if left else -2.5
	var rt := R(tx, tx + 2.5, -2.5, 2.5)
	var ra := R(ax, ax + 2.5, 0.0, 2.5)
	var af := 1 if floors < 3 else 2
	var t_in := 1 if left else 3          # сторона башни к пристройке
	var t_out := 3 if left else 1
	var a_in := t_out                      # сторона пристройки к башне
	var a_out := t_in
	var ia := 0 if t_in == 1 else 1        # пролёт башни у пристройки
	var cor := _cor(b)
	var shut := _shut(b)
	var tf := floors if floors > 1 else 1
	for f in tf:
		var spec := {}
		spec[0] = [_door_bay(b)] if f == 0 else [b.pick([W1, W1, W5])]
		spec[t_out] = [W6, WALL] if f == 0 else [WALL, W2]
		spec[2] = _bk(b, rt, f, shut)
		var inner := [W6, W6] if f == 0 else [W2, W2]
		inner[ia] = "" if f < af else (D4 if f == af else W1)
		spec[t_in] = inner
		_storey(b, rt, f, spec, {"cornice": cor if f == tf - 1 else TRIM_MID})
		if f > 0 and (spec[0] as Array)[0] == W1:
			_win(b, rt, 0, 0, f, shut, f == 1)
	_door(b, rt, 0, 0, _leaf(b))
	_step(b, rt, 0, 0)
	_plaque(b, rt, 0, 1.25, 2.12)
	_lamp(b, rt, 0, 0.18 if left else 2.32, 2.2)
	_dark(b, rt, 0.0, tf * FL)
	var ridge := _gable(b, rt, tf * FL, 1.7, true, _topper(b))
	_chimney(b, Vector3(tx + 1.25, ridge - 0.25, -1.4))
	if floors >= 3:
		_jbal(b, rt, 0, 0, 2, false)
	# пристройка
	for f in af:
		var spec := {}
		spec[0] = [W1]
		spec[a_out] = [W6] if f == 0 else [WALL]
		spec[2] = [WALL] if f == 0 else [W6]
		spec[a_in] = [""]
		_storey(b, ra, f, spec, {"cornice": TRIM_MID if f < af - 1 else "", "corners": [1, 2] if left else [0, 3]})
		_win(b, ra, 0, 0, f, shut, f > 0)
	_dark(b, ra, 0.0, af * FL)
	b.remap = b.floor_remap(af - 1)
	_terrace(b, ra, af * FL, [0, a_out, 2], _rail(b))
	_door2(b, rt, t_in, ia, af)
	b.remap = b.floor_remap(1)
	_pergola(b, ax, 0.0, af * FL + 0.07)
	_ivy_drape(b, ra, 0, 1.0 if left else 1.5, af * FL + 1.0)
	if b.chance(0.6):
		_on(b, "SM_Prop_Rug_Drape_01", ra, a_out, 1.25, af * FL + 1.0, 0.0, 0.75, false, PI)
	# дворик за пристройкой: ограда, смоковница, амфоры
	var yx0 := ax
	var yx1 := ax + 2.5
	var outer_x := yx1 if left else yx0
	_lowwall(b, Vector3(outer_x, 0, 0.0), Vector3(outer_x, 0, -2.4), 1.1, false)
	_lowwall(b, Vector3(yx0 if left else yx1, 0, -2.4), Vector3(yx1 if left else yx0, 0, -2.4), 1.1, false)
	_put(b, "SM_Env_Tree_Bush_0%d" % (1 + b.rng.randi() % 2), Vector3((yx0 + yx1) / 2.0, 0, -1.3), b.rng.randf() * TAU, Vector3.ONE * 0.5)
	_jar(b, Vector3(outer_x + (-0.45 if left else 0.45), 0, -0.5), 0.75)
	_street_bench(b, ra, 0)


## 2 «Касетта»: домик в глубине участка, впереди садик за низкой оградой с калиткой
static func _pleb_casetta(b: Bp, floors: int) -> void:
	var di := b.rng.randi() % 2
	var wi := 1 - di
	var rh := R(-2.5, 2.5, -2.5, 0.0)
	var cor := _cor(b)
	var shut := _shut(b)
	var gz := 2.3                          # линия ограды садика
	for f in floors:
		var front := [W1, W1]
		if f == 0:
			front[di] = _door_bay(b)
		elif f == 1:
			front[di] = D4
		_storey(b, rh, f, {0: front, 1: [W6] if f == 0 else [W2], 2: _bk(b, rh, f, shut), 3: [WALL] if f == 0 else [W6]},
			{"cornice": cor if f == floors - 1 else TRIM_MID})
		for i in 2:
			if front[i] == W1:
				_win(b, rh, 0, i, f, shut, f == 0 or b.chance(0.5))
		if f == floors - 1 and b.chance(0.3):
			_frieze(b, rh, 0, f, front)
		if f == 1:
			_balcony(b, rh, 0, di, 1)
			_door2(b, rh, 0, di, 1)
	_door(b, rh, 0, di, _leaf(b), 0.0, false)
	_step(b, rh, 0, di)
	_lamp(b, rh, 0, 2.5, 2.25)
	_on(b, "SM_Prop_Overhang_02", rh, 0, di * M + 1.25, 2.55, 0.1)
	_dark(b, rh, 0.0, floors * FL)
	_leaning(b, rh, 2, b.rng.randf_range(0.6, 4.4))
	var ridge: float
	if floors < 3:
		ridge = _gable(b, rh, floors * FL, 2.4, false, _topper(b))
	else:
		ridge = _gable(b, rh, floors * FL, 1.35, true, _topper(b))
		_medallion(b, rh, 0, 2.5, floors * FL + 0.42)
	_chimney(b, Vector3(-1.2 if floors < 3 else 0.0, ridge - 0.25, -1.25 if floors < 3 else -1.7))
	_ivy(b, rh, 3 if di == 1 else 1, 1.2, 1.6, true, 0.9)
	# садик: ограда с калиткой, клумбы, деревце, скамья
	var gx := -2.5 + di * M + 1.25
	var gw := 0.62
	_lowwall(b, Vector3(-2.5, 0, gz), Vector3(gx - gw, 0, gz), 0.72)
	_lowwall(b, Vector3(gx + gw, 0, gz), Vector3(2.5, 0, gz), 0.72)
	_lowwall(b, Vector3(-2.5, 0, 0.05), Vector3(-2.5, 0, gz), 0.72, false)
	_lowwall(b, Vector3(2.5, 0, gz), Vector3(2.5, 0, 0.05), 0.72, false)
	for sx: float in [-1.0, 1.0]:
		_put(b, "SM_Prop_Pillar_Base_01", Vector3(gx + sx * (gw + 0.12), 0, gz), 0.0, Vector3(0.38, 1.0, 0.38))
		_pot(b, Vector3(gx + sx * (gw + 0.12), 1.0, gz), 0.34)
	b.door = b.base * Vector3(gx, 0, gz + 0.65)
	var ox := -2.5 + wi * M + 1.25
	_put(b, "SM_Prop_FlowerBed_0%d" % (1 + b.rng.randi() % 2), Vector3(ox, 0.39 * 0.85, gz - 0.55), 0.0, Vector3.ONE * 0.85)
	if b.chance(0.5):
		_put(b, "SM_Env_Tree_Thin_0%d" % (1 + b.rng.randi() % 2), Vector3(ox + (0.9 if wi == 1 else -0.9), 0, 1.0), 0.0, Vector3.ONE * 0.36)
	else:
		_put(b, "SM_Env_Tree_Bush_0%d" % (1 + b.rng.randi() % 2), Vector3(ox + (0.8 if wi == 1 else -0.8), 0, 1.0), b.rng.randf() * TAU, Vector3.ONE * 0.42)
	_bench(b, Vector3(ox - (0.3 if wi == 1 else -0.3), 0, 0.95))     # перед ящиком цветов, не под ним
	_put(b, "SM_Env_Garden_Plants_0%d" % (3 + b.rng.randi() % 4), Vector3(gx - (0.9 if di == 0 else -0.9), 0, gz - 0.5), b.rng.randf() * TAU, Vector3.ONE * 0.45)
	_put(b, "SM_Env_Flowers_0%d" % (1 + b.rng.randi() % 5), Vector3(gx, 0.01, 1.3), b.rng.randf() * TAU, Vector3.ONE * 1.3)
	_jar(b, Vector3(-2.5 + di * M + (2.2 if di == 0 else 0.3), 0, 0.45), 0.7)


## 3 «Портик»: внизу комната за колоннами (лоджия), над ней этаж на колоннах; третий этаж — в глубине, с террасой
static func _pleb_portico(b: Bp, floors: int) -> void:
	var di := b.rng.randi() % 2
	var wi := 1 - di
	var rg := R(-2.5, 2.5, -2.5, 0.0)
	var r0 := R(-2.5, 2.5, -2.5, 2.5)
	var rp := R(-2.5, 2.5, 0.0, 2.5)
	var cor := _cor(b)
	var shut := _shut(b)
	var pil := "SM_Bld_Pillar_0%d" % b.pick([6, 6, 1])
	var zc := 2.25
	var front := [W1, W1]
	front[di] = _door_bay(b)
	_storey(b, rg, 0, {0: front, 1: [W6], 2: _bk(b, rg, 0, shut), 3: [WALL]}, {"cornice": cor if floors == 1 else ""})
	_leaning(b, rg, 2, b.rng.randf_range(0.6, 4.4))
	_door(b, rg, 0, di, _leaf(b))
	b.door = b.base * Vector3(-2.5 + di * M + 1.25, 0, 3.4)     # жители входят с улицы, у колонн
	_win(b, rg, 0, wi, 0, shut, false)
	_dark(b, rg, 0.0, FL)
	var cx := [-2.18, 0.0, 2.18] if pil.ends_with("6") else [-2.15, 2.15]
	for x: float in cx:
		_put(b, pil, Vector3(x, 0, zc), 0.0)
	_put(b, "SM_Env_Ivy_Pillar_Flowers_0%d" % (1 + b.rng.randi() % 2), Vector3(cx[0] if wi == 0 else cx[cx.size() - 1], 0, zc), b.rng.randf() * TAU)
	# в лоджии: скамья, амфоры, горшок, светильник
	_bench(b, Vector3(-2.5 + wi * M + 1.25, 0, 0.75))
	_jar(b, Vector3(-2.5 + di * M + (2.15 if di == 0 else 0.35), 0, 0.5), 0.75)
	_pot(b, Vector3(-2.5 + di * M + (0.3 if di == 0 else 2.2), 0, 0.55), 0.5)
	_hang_lamp(b, Vector3(0, FL, 0), rg, 0, di * M + (2.3 if di == 0 else 0.2))
	if floors == 1:
		# крыльцо под общей вальмовой крышей: колонны несут карниз
		b.remap = b.floor_remap(0)
		for i in 2:
			_put(b, "SM_Bld_Wall_Tiny_01", Vector3(-2.5 + i * M, FL - 0.31, zc + 0.05), 0.0, Vector3.ONE, b.remap.duplicate())
		for side: int in [1, 3]:
			var a := _sp(rp, side, 0.0, FL - 0.31, -0.25)
			_put(b, "SM_Bld_Wall_Tiny_01", a[0], a[1], Vector3(0.9, 1, 1), b.remap.duplicate())
		b.remap = b.floor_remap(1)
		var ridge := _hip(b, r0, FL, 1.6, _topper(b))
		_chimney(b, Vector3(0.9, ridge - 0.65, 0.0))
		return
	# второй этаж — во всю глубину, на колоннах
	var up := [W1, W1]
	up[di] = W1 if floors == 2 else D4
	_storey(b, r0, 1, {0: up, 1: [W2, WALL], 2: _bk(b, r0, 1, shut), 3: [WALL, W6]}, {"cornice": cor if floors == 2 else TRIM_MID})
	_win(b, r0, 0, wi, 1, shut)
	if up[di] == W1:
		_win(b, r0, 0, di, 1, shut, b.chance(0.5))
	else:
		_jbal(b, r0, 0, di, 1)
		_door2(b, r0, 0, di, 1)
	_dark(b, r0, FL, 2 * FL)
	_ivy(b, r0, 1 if wi == 1 else 3, 1.5, FL + 1.5)
	if floors == 2:
		var ridge := _gable(b, r0, 2 * FL, 1.6, false, _topper(b))
		_chimney(b, Vector3(-1.3, ridge - 0.25, 0.0))
		return
	var top := [W1, W1]
	top[wi] = D4
	var rb := _setback(b, r0, 2, top, cor, shut)
	var ridge := _gable(b, rb, 3 * FL, 2.0, false, _topper(b))
	_chimney(b, Vector3(-1.3, ridge - 0.25, -1.25))


## 4 «Фронтон»: дом фронтоном к улице; у трёхэтажного верхний этаж в глубине, фронтон над ним, впереди терраса
static func _pleb_fronte(b: Bp, floors: int) -> void:
	var di := b.rng.randi() % 2
	var wi := 1 - di
	var r0 := R(-2.5, 2.5, -2.5, 2.5)
	var cor := _cor(b)
	var shut := _shut(b)
	var full := mini(floors, 2)
	for f in full:
		var front := [W1, W1]
		if f == 0:
			front[di] = _door_bay(b)
		else:
			front[di] = b.pick([W5, W1])
		_storey(b, r0, f, {0: front, 1: [W6, WALL] if f == 0 else [W2, WALL], 2: _bk(b, r0, f, shut), 3: [WALL, W6] if f == 0 else [WALL, W2]},
			{"cornice": cor if f == floors - 1 else TRIM_MID})
		for i in 2:
			if front[i] == W1:
				_win(b, r0, 0, i, f, shut, f > 0 and b.chance(0.7))
		if f == 0 and b.chance(0.3):
			_frieze(b, r0, 0, 0, front)
	_door(b, r0, 0, di, _leaf(b))
	_step(b, r0, 0, di)
	_lamp(b, r0, 0, di * M + (2.32 if di == 0 else 0.18), 2.2)
	_hang_pots(b, r0, 0, 2.5, 2.6)
	_street_bench(b, r0, wi)
	_leaning(b, r0, 2, b.rng.randf_range(0.6, 4.4))
	_dark(b, r0, 0.0, full * FL)
	_ivy(b, r0, b.pick([1, 3]), b.rng.randf_range(1.5, 3.5), 1.4)
	if floors == 1:
		_jar(b, Vector3(r0[0] + di * M + (2.2 if di == 0 else 0.3), 0, r0[3] + 0.6))
	var rr := r0
	if floors == 3:
		var top := [W1, W1]
		top[di] = D4
		rr = _setback(b, r0, 2, top, cor, shut)
	var ridge := _gable(b, rr, floors * FL, 1.45 if floors < 3 else 1.3, true, _topper(b))
	_medallion(b, rr, 0, 2.5, floors * FL + 0.45)
	_chimney(b, Vector3(0.0, ridge - 0.25, rr[2] + 1.5))


# =====================================================================================
#                                  дома ремесленников
# =====================================================================================

## Нутро лавки за проёмом SHOP (пролёт i фасада r): каменный пол, товар у задней стены, под притолокой — полог
## или висячие горшки. Тёмная глубина отступает на метр (_dark_shops), поэтому лавка не «чёрная дыра»
static func _shop_inside(b: Bp, r: PackedFloat32Array, i: int, kind: int, hang := true) -> void:
	var f0 := _sp(r, 0, i * M + 0.15, 0.0, -1.05)
	_put(b, "SM_Bld_Floor_Trim_01", f0[0], f0[1], Vector3(0.88, 0.5, 1.0))
	var bk := _sp(r, 0, i * M + b.pick([0.75, 1.75]), 0.0, -0.72)
	match kind:
		0: _put(b, "SM_Prop_Rug_Stack_02", bk[0], b.rng.randf_range(-0.4, 0.4), Vector3.ONE * 0.8)
		1: _put(b, "SM_Prop_Vase_05", bk[0], b.rng.randf() * TAU, Vector3.ONE * 0.85)
		_: _put(b, "SM_Prop_Sack_Stack_02", bk[0], b.rng.randf_range(-0.3, 0.3), Vector3.ONE * 0.6)
	var h := b.rng.randf() if hang else 1.0
	if h < 0.6:
		_on(b, "SM_Prop_Drapery_03", r, 0, i * M + 1.25, 2.45, -0.06, 0.88)     # полог (другие пологи — по 2–2,6 тыс. треугольников)
	elif h < 0.8:
		_on(b, "SM_Prop_FlowerPot_Hanging_0%d" % (4 + b.rng.randi() % 3), r, 0, i * M + b.pick([0.6, 1.9]), 2.4, -0.3, 0.55)


## Лавка: навес, прилавок на пороге (как в Помпеях) с товаром ремесла, товар у стены сбоку, вывеска-полотнище
static func _shopfront(b: Bp, r: PackedFloat32Array, i: int, kind: int, awning := true) -> void:
	if awning:
		_on(b, "SM_Prop_Overhang_01", r, 0, i * M + 1.25, 2.78, 0.12)
	_shop_inside(b, r, i, kind)
	var c := _sp(r, 0, i * M + 1.25, 0.0, -0.2)
	var p: Vector3 = c[0]
	_put(b, "SM_Prop_Table_01", p, 0.0, Vector3(0.78, 1, 0.7))
	var top := p + Vector3(0, 0.78, 0)
	var sl := b.chance(0.5)
	var su := i * M + (0.32 if sl else 2.18)
	match kind:
		0:   # ткач: свёртки ткани, корзины шерсти
			_put(b, "SM_Prop_Rug_Stack_02", top + Vector3(-0.3, 0, 0), 0.2, Vector3.ONE * 0.6)
			_put(b, "SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 5), top + Vector3(0.38, 0, 0), b.rng.randf() * TAU, Vector3.ONE * 0.5)
			_front_put(b, "SM_Prop_Rug_Stack_02", r, su, 0.0, 0.55, 0.3)
		1:   # гончар: миска и кувшин на прилавке, амфора у стены
			_put(b, "SM_Prop_Bowl_0%d" % (1 + b.rng.randi() % 3), top + Vector3(-0.3, 0, 0), 0.0, Vector3.ONE * 0.38)
			_put(b, "SM_Prop_Jug_0%d" % (1 + b.rng.randi() % 4), top + Vector3(0.3, 0, 0.0), b.rng.randf() * TAU, Vector3.ONE * 0.55)
			_front_put(b, "SM_Prop_Vase_04", r, su, 0.0, 0.6, 0.5)
		_:   # кузнец/медник: молот и блюдо на прилавке, наковальня у стены
			_put(b, "SM_Prop_Tool_Hammer_01", top + Vector3(-0.3, 0.02, 0), 0.6, Vector3.ONE * 1.3)
			_put(b, "SM_Prop_Plate_0%d" % (1 + b.rng.randi() % 3), top + Vector3(0.3, 0, 0.05), 0.0, Vector3.ONE * 0.8)
			_front_put(b, "SM_Prop_Anvil_01", r, su, 0.0, 0.55, 0.5)
	if b.chance(0.6):
		_on(b, "SM_Prop_Banner_0%d_%s" % [1 + b.rng.randi() % 2, b.pick(["A", "B", "C", "D", "E", "F"])], r, 0, i * M + (2.48 if sl else 0.02), 2.62, 0.12, 0.45)


## Мастерская под навесом/портиком: станок, печь или горн с утварью; p — центр, ось вдоль x
static func _workshop(b: Bp, kind: int, p: Vector3, yaw := 0.0) -> void:
	var bs := Basis(Vector3.UP, yaw)
	var at := func(o: Vector3) -> Vector3: return p + bs * o
	match kind:
		0:
			_put(b, "SM_Prop_Loom_01", at.call(Vector3(-0.45, 0, 0)), yaw, Vector3.ONE * 0.85)
			_put(b, "SM_Prop_Rug_Stack_02", at.call(Vector3(0.75, 0, -0.25)), yaw + 0.3, Vector3.ONE * 0.8)
			_put(b, "SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 5), at.call(Vector3(0.85, 0, 0.5)), b.rng.randf() * TAU)
			_put(b, "SM_Prop_Stool_01", at.call(Vector3(-0.45, 0, 0.55)), yaw)
		1:
			_put(b, "SM_Prop_Kiln_01", at.call(Vector3(-0.45, 0, -0.15)), yaw + PI, Vector3.ONE * 0.52)
			_jar(b, at.call(Vector3(0.75, 0, -0.3)), 0.65)
			_put(b, "SM_Prop_Vase_06", at.call(Vector3(1.05, 0, 0.05)), 0.0, Vector3.ONE * 0.6)
			_put(b, "SM_Prop_Table_07", at.call(Vector3(0.1, 0, 0.6)), yaw, Vector3.ONE * 0.8)
		_:
			_put(b, "SM_Prop_Forge_01", at.call(Vector3(-0.5, 0, -0.2)), yaw, Vector3.ONE * 0.5)
			_put(b, "SM_Prop_Anvil_01", at.call(Vector3(0.45, 0, 0.35)), yaw + 0.4, Vector3.ONE * 0.85)
			_put(b, "SM_Prop_Grinding_Wheel_01", at.call(Vector3(0.95, 0.32 * 0.8, -0.35)), yaw + 1.2, Vector3.ONE * 0.8)
			_put(b, "SM_Prop_Jar_01", at.call(Vector3(1.0, 0, 0.6)), 0.0, Vector3.ONE * 0.7)


## Дом ремесленников (след до 7,5×5 м): мастерская или лавка внизу, жильё сверху; пять обликов, 1–3 этажа
static func _house_artisan(b: Bp, floors: int, v: int) -> void:
	floors = clampi(floors, 1, 3)
	_begin(b, "artisan")
	var craft := v % 3
	match v % 5:
		0: _art_bottega(b, floors, craft)
		1: _art_tettoia(b, floors, craft)
		2: _art_porticus(b, floors, craft)
		3: _art_altana(b, floors, craft)
		_: _art_frontone(b, floors, craft)


## 0 «Боттега»: две лавки и дверь, вальмовая крыша; на втором этаже окна со ставнями и балкон,
## третий этаж — в глубине, впереди терраса
static func _art_bottega(b: Bp, floors: int, craft: int) -> void:
	var r0 := R(-3.75, 3.75, -2.5, 2.5)
	var di := 0 if b.chance(0.5) else 2
	var cor := _cor(b)
	var shut := _shut(b)
	var front := [SHOP, SHOP, SHOP]
	front[di] = _door_bay(b)
	_storey(b, r0, 0, {0: front, 1: [W6, WALL], 2: _bk(b, r0, 0, shut), 3: [WALL, W6]}, {"cornice": cor if floors == 1 else TRIM_MID})
	_door(b, r0, 0, di, _leaf(b))
	_step(b, r0, 0, di)
	for i in 3:
		if i != di:
			_shopfront(b, r0, i, craft)
	_lamp(b, r0, 0, 5.0 if di == 2 else 2.5, 2.2)
	_plaque(b, r0, 0, di * M + 1.25, 2.12)
	_leaning(b, r0, 2, b.rng.randf_range(0.6, 6.9))
	var full := mini(floors, 2)
	if full == 2:
		# у двухэтажного посередине — дверь на висячий балкон; у трёхэтажного жизнь — на террасе, здесь окно с фронтончиком
		var up := [W1, D4 if floors == 2 else W5, W1]
		_storey(b, r0, 1, {0: up, 1: [W2, WALL], 2: _bk(b, r0, 1, shut), 3: [WALL, W2]}, {"cornice": cor if floors == 2 else TRIM_MID})
		_win(b, r0, 0, 0, 1, shut)
		_win(b, r0, 0, 2, 1, shut)
		if floors == 2:
			_balcony(b, r0, 0, 1, 1)
			_door2(b, r0, 0, 1, 1)
		if b.chance(0.35):
			_frieze(b, r0, 0, 1, up)
	_dark_shops(b, r0, full * FL)
	var rr := r0
	if floors == 3:
		rr = _setback(b, r0, 2, [W1, D4, W1], cor, shut)
	var ridge := _hip(b, rr, floors * FL, 1.6, _topper(b))
	_chimney(b, Vector3(-0.6, ridge - 0.25, (rr[2] + rr[3]) / 2.0))
	_ivy(b, r0, b.pick([1, 3]), b.rng.randf_range(1.0, 4.0), 1.5 + (full - 1) * 1.2)


## 1 «Тетто́йя»: жилой дом и открытая мастерская под односкатным навесом на столбах
static func _art_tettoia(b: Bp, floors: int, craft: int) -> void:
	var left := b.chance(0.5)
	var rh := R(-3.75, 1.25, -2.5, 2.5) if left else R(-1.25, 3.75, -2.5, 2.5)
	var rs := R(1.25, 3.75, -2.5, 2.5) if left else R(-3.75, -1.25, -2.5, 2.5)
	var h_in := 1 if left else 3           # сторона дома к навесу
	var s_out := 1 if left else 3          # наружная сторона навеса
	var cor := _cor(b)
	var shut := _shut(b)
	var di := 1 if left else 0             # дверь — у навеса
	var full := mini(floors, 2)
	for f in full:
		var front := [W1, W1]
		if f == 0:
			front[di] = _door_bay(b)
		elif floors == 2:
			front[1 - di] = D4
		_storey(b, rh, f, {0: front, h_in: [W6, WALL] if f == 0 else [W2, WALL], 2: _bk(b, rh, f, shut), (4 - h_in) % 4: [WALL, W6] if f == 0 else [WALL, W2]},
			{"cornice": cor if f == floors - 1 else TRIM_MID})
		for i in 2:
			if front[i] == W1:
				_win(b, rh, 0, i, f, shut, f == 0 or b.chance(0.6))
			elif front[i] == D4 and f > 0:
				_jbal(b, rh, 0, i, f)
				_door2(b, rh, 0, i, f)
	_door(b, rh, 0, di, _leaf(b))
	_step(b, rh, 0, di)
	_lamp(b, rh, 0, 2.5, 2.3)
	_dark(b, rh, 0.0, full * FL)
	var rr := rh
	if floors == 3:
		var top := [W1, W1]
		top[1 - di] = D4
		rr = _setback(b, rh, 2, top, cor, shut)
	var ridge := _gable(b, rr, floors * FL, 1.5 if floors < 3 else 1.3, true, _topper(b))
	_medallion(b, rr, 0, 2.5, floors * FL + 0.42)
	_chimney(b, Vector3((rh[0] + rh[1]) / 2.0, ridge - 0.25, rr[2] + 1.1))
	# навес-мастерская: задняя и боковая стены, столбы, черепичный скат к улице
	b.remap = b.floor_remap(0)
	_on(b, WALL, rs, 2, 0.0, 0.0, 0.0, 1.0, true)
	_on(b, W6, rs, s_out, 2.5 if s_out == 1 else 0.0, 0.0, 0.0, 1.0, true)
	b.remap = b.floor_remap(1)
	var px := rs[1] - 0.25 if left else rs[0] + 0.25
	for z: float in [2.25, -0.05]:
		_put(b, "SM_Bld_Trellis_Pillar_01", Vector3(px, 0, z), 0.0, Vector3(1.0, 0.86, 1.0))
	_lean(b, rs, 2.62, 0.48, 0)
	_workshop(b, craft, Vector3((rs[0] + rs[1]) / 2.0, 0, 0.9), 0.0)
	_put(b, "SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 5), Vector3((rs[0] + rs[1]) / 2.0 - 0.6, 0, -1.9), b.rng.randf() * TAU)
	_jar(b, Vector3((rs[0] + rs[1]) / 2.0 + 0.5, 0, -1.95), 0.75)
	_jar(b, Vector3(px, 0, 2.35), 0.7)
	_put(b, "SM_Prop_Sack_Stack_0%d" % (1 + b.rng.randi() % 2), Vector3(px + (-0.6 if left else 0.6), 0, 1.6), b.rng.randf() * TAU, Vector3.ONE * 0.7)


## 2 «Портик»: колоннада вдоль улицы, под ней мастерская и лавки; наверху жильё на колоннах,
## третий этаж — в глубине, с террасой
static func _art_porticus(b: Bp, floors: int, craft: int) -> void:
	var rg := R(-3.75, 3.75, -2.5, 0.0)
	var r0 := R(-3.75, 3.75, -2.5, 2.5)
	var cor := _cor(b)
	var shut := _shut(b)
	var pil := "SM_Bld_Pillar_0%d" % b.pick([1, 1, 6])
	var zc := 2.15
	_storey(b, rg, 0, {0: [SHOP, _door_bay(b), SHOP], 1: [W6], 2: _bk(b, rg, 0, shut), 3: [WALL]}, {"cornice": cor if floors == 1 else ""})
	_door(b, rg, 0, 1, _leaf(b))
	b.door = b.base * Vector3(0, 0, 3.4)
	_dark_shops(b, rg, FL)
	for i: int in [0, 2]:
		_shop_inside(b, rg, i, (craft + i) % 3, false)
	_leaning(b, rg, 2, b.rng.randf_range(0.6, 6.9))
	for x: float in [-3.4, -1.15, 1.15, 3.4]:
		_put(b, pil, Vector3(x, 0, zc), 0.0)
	_put(b, "SM_Env_Ivy_Pillar_Flowers_0%d" % (1 + b.rng.randi() % 2), Vector3(-3.4 if b.chance(0.5) else 3.4, 0, zc), b.rng.randf() * TAU)
	# под портиком: мастерская с одной стороны, прилавок с другой, светильник
	var ws_left := b.chance(0.5)
	_workshop(b, craft, Vector3(-2.3 if ws_left else 2.3, 0, 1.05), 0.0)
	var tx := 2.3 if ws_left else -2.3
	_put(b, "SM_Prop_Table_01", Vector3(tx, 0, 1.0), 0.0, Vector3(0.8, 1, 0.75))
	_jar(b, Vector3(tx - 0.3, 0.78, 1.0), 0.45)
	_put(b, "SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 5), Vector3(tx + 0.35, 0.78, 1.0), b.rng.randf() * TAU, Vector3.ONE * 0.5)
	_hang_lamp(b, Vector3(0, FL, 0), rg, 0, 3.75 + 0.95)
	if floors == 1:
		b.remap = b.floor_remap(0)
		for x: float in [-3.75, -1.25, 1.25]:
			_put(b, "SM_Bld_Wall_Tiny_01", Vector3(x, FL - 0.31, zc + 0.05), 0.0, Vector3.ONE, b.remap.duplicate())
		for side: int in [1, 3]:
			var a := _sp(R(-3.75, 3.75, 0.0, 2.5), side, 0.0, FL - 0.31, -0.3)
			_put(b, "SM_Bld_Wall_Tiny_01", a[0], a[1], Vector3(0.9, 1, 1), b.remap.duplicate())
		b.remap = b.floor_remap(1)
		var ridge := _hip(b, r0, FL, 1.5, _topper(b))
		_chimney(b, Vector3(0.6, ridge - 0.25, 0.0))
		return
	var up := [W1, D4 if floors == 2 else W5, W1]
	# задние углы этажа — продолжение углов нижней комнаты за портиком
	_storey(b, r0, 1, {0: up, 1: [W2, WALL], 2: _bk(b, r0, 1, shut), 3: [WALL, W6]}, {"cornice": cor if floors == 2 else TRIM_MID, "corners": [0, 1]})
	_extend_corners(b, rg, 1, [2, 3])
	for i in 3:
		if up[i] == W1:
			_win(b, r0, 0, i, 1, shut)
		elif up[i] == D4:
			_jbal(b, r0, 0, i, 1)
			_door2(b, r0, 0, i, 1)
	_dark(b, r0, FL, 2 * FL)
	_ivy(b, r0, b.pick([1, 3]), 2.0, FL + 1.4)
	var rr := r0
	if floors == 3:
		rr = _setback(b, r0, 2, [W1, D4, W1], cor, shut, [0, 1, 3], rg)
	var ridge := _gable(b, rr, floors * FL, 1.6, false, _topper(b))
	_chimney(b, Vector3(-1.6, ridge - 0.25, (rr[2] + rr[3]) / 2.0))


## 3 «Альтана»: каменный (кирпичный) низ с лавками, наверху висячий балкон, под крышей — открытая лоджия
static func _art_altana(b: Bp, floors: int, craft: int) -> void:
	var r0 := R(-3.75, 3.75, -2.5, 2.5)
	var rb := R(-3.75, 3.75, -2.5, 0.0)
	b.ground_style = "brick"
	var cor := _cor(b)
	var shut := _shut(b)
	var loggia := floors == 3
	var fl := floors - 1 if loggia else floors
	_storey(b, r0, 0, {0: [SHOP, D3, SHOP], 1: [W6, WALL], 2: _bk(b, r0, 0, shut), 3: [WALL, W6]}, {"cornice": cor if fl == 1 else TRIM_MID})
	_door(b, r0, 0, 1, _leaf(b))
	_step(b, r0, 0, 1)
	_shopfront(b, r0, 0, craft)
	_shopfront(b, r0, 2, (craft + 1) % 3)
	_lamp(b, r0, 0, 2.5, 2.2)
	_leaning(b, r0, 2, b.rng.randf_range(0.6, 6.9))
	for f in range(1, fl):
		_storey(b, r0, f, {0: [W1, D4, W1], 1: [W2, WALL], 2: _bk(b, r0, f, shut), 3: [WALL, W2]}, {"cornice": TRIM_MID if loggia else cor})
		_win(b, r0, 0, 0, f, shut)
		_win(b, r0, 0, 2, f, shut)
		_door2(b, r0, 0, 1, f)
		_balcony(b, r0, 0, 1, f, true)
	_dark_shops(b, r0, fl * FL)
	if loggia:
		# лоджия: комната в глубине, впереди тонкие колонны и балюстрада, общая крыша
		var f := floors - 1
		var ext := _extend_corners(b, r0, f, [2, 3])
		_storey(b, rb, f, {0: [W1, D4, W1], 1: [WALL], 2: _bk(b, rb, f, shut), 3: [WALL]}, {"cornice": "", "corners": [0, 1] if ext else [0, 1, 2, 3]})
		_dark(b, rb, f * FL, floors * FL)
		b.remap = b.floor_remap(f - 1)
		_terrace(b, R(-3.75, 3.75, 0.0, 2.5), f * FL, [], "")
		for i in 3:
			_on(b, "SM_Bld_Wall_Balcony_06", r0, 0, i * M, f * FL, 0.0, 1.0, true)
		for side: int in [1, 3]:
			_on(b, "SM_Bld_Wall_Balcony_06", R(-3.75, 3.75, 0.0, 2.5), side, 0.0, f * FL, 0.0, 1.0, true)
		b.remap = b.floor_remap(1)
		for x: float in [-3.5, -1.2, 1.2, 3.5]:
			_put(b, "SM_Bld_Pillar_06", Vector3(x, f * FL, 2.25), 0.0)
		_bench(b, Vector3(-1.4, f * FL + 0.07, 0.7))
		_pot(b, Vector3(1.6, f * FL + 0.07, 1.4), 0.5)
		_on(b, "SM_Prop_Rug_Drape_01", r0, 0, b.rng.randf_range(1.0, 6.5), f * FL + 1.0, 0.25, 0.8, false, PI)
	var ridge := _gable(b, r0, floors * FL, 1.7, false, _topper(b))
	_chimney(b, Vector3(1.5, ridge - 0.25, 0.0))


## 4 «Фронтон»: лавка и мастерская под большим фронтоном к улице, медальон, балкончики;
## у трёхэтажного верх в глубине, фронтон над ним, впереди терраса
static func _art_frontone(b: Bp, floors: int, craft: int) -> void:
	var r0 := R(-3.75, 3.75, -2.5, 2.5)
	var di := 0 if b.chance(0.5) else 2
	var cor := _cor(b)
	var shut := _shut(b)
	var front := [SHOP, SHOP, SHOP]
	front[di] = b.pick([D3, D4])
	var full := mini(floors, 2)
	_storey(b, r0, 0, {0: front, 1: [W6, WALL], 2: _bk(b, r0, 0, shut), 3: [WALL, W6]}, {"cornice": cor if full == 1 else TRIM_MID})
	_door(b, r0, 0, di, _leaf(b))
	_step(b, r0, 0, di)
	_shopfront(b, r0, 1, craft)
	var oi := 2 - di
	# вторая лавка — зерно и мешки: мешки горкой на пороге, амфора у стены
	_on(b, "SM_Prop_Overhang_01", r0, 0, oi * M + 1.25, 2.78, 0.12)
	_shop_inside(b, r0, oi, 2)
	_put(b, "SM_Prop_Sack_Stack_0%d" % (1 + b.rng.randi() % 2), Vector3(r0[0] + oi * M + 1.25, 0, r0[3] - 0.3), b.rng.randf_range(-0.08, 0.08), Vector3.ONE * 0.72)
	_front_put(b, b.pick(["SM_Prop_Vase_02", "SM_Prop_Vase_05", "SM_Prop_Jar_01"]), r0, oi * M + (0.32 if oi == 0 else 2.18), 0.0, 0.7)
	_lamp(b, r0, 0, di * M + (2.32 if di == 0 else 0.18), 2.2)
	_leaning(b, r0, 2, b.rng.randf_range(0.6, 6.9))
	if full == 2:
		var up := [W1, W5, W1]
		_storey(b, r0, 1, {0: up, 1: [W2, WALL], 2: _bk(b, r0, 1, shut), 3: [WALL, W2]}, {"cornice": cor if floors == 2 else TRIM_MID})
		_win(b, r0, 0, 0, 1, shut)
		_win(b, r0, 0, 2, 1, shut)
	_dark_shops(b, r0, full * FL)
	var rr := r0
	if floors == 3:
		rr = _setback(b, r0, 2, [W1, D4, W1], cor, shut)
	var ridge := _gable(b, rr, floors * FL, 1.0, true, _topper(b))
	_medallion(b, rr, 0, 3.75, floors * FL + 0.5)
	_chimney(b, Vector3(0.0, ridge - 0.25, rr[2] + 1.3))
	_ivy(b, r0, b.pick([1, 3]), b.rng.randf_range(1.0, 4.0), 1.6)


# =====================================================================================
#                                    домусы патрициев
# =====================================================================================

## Статуя на постаменте
static func _statue(b: Bp, p: Vector3, yaw := 0.0, h := 0.75) -> void:
	_put(b, "SM_Prop_Pillar_Base_02", p, 0.0, Vector3.ONE * h)
	_put(b, "SM_Prop_Statue_0%d" % b.pick([3, 5, 6]), p + Vector3(0, 1.5 * h, 0), yaw, Vector3.ONE * 0.62 * h)


static func _fountain(b: Bp, p: Vector3, s := 0.5) -> void:
	_put(b, "SM_Prop_Fountain_04", p, 0.0, Vector3.ONE * s)
	_put(b, "SM_Prop_Fountain_04_Insert_01", p, 0.0, Vector3.ONE * s)


static func _bed(b: Bp, p: Vector3, yaw := 0.0, s := 0.85) -> void:
	_put(b, "SM_Prop_FlowerBed_0%d" % (1 + b.rng.randi() % 2), p + Vector3(0, 0.39 * s, 0), yaw, Vector3.ONE * s)


static func _cypress(b: Bp, p: Vector3, s := 0.4) -> void:
	_put(b, "SM_Env_Tree_Thin_0%d" % (1 + b.rng.randi() % 2), p, b.rng.randf() * TAU, Vector3.ONE * s)


## Протирон — главный знак богатого дома: два мраморных столба у парадной двери (пролёт i фасада r)
## под маленьким черепичным фронтоном, на столбах — фонари. Возвращает z переднего края (жители входят перед ним)
static func _porch(b: Bp, r: PackedFloat32Array, i: int, deep := 1.1) -> float:
	var dx := r[0] + i * M + 1.25
	var z0 := r[3]
	var pz := z0 + deep - 0.26
	for sx: float in [-1.0, 1.0]:
		_put(b, "SM_Bld_Pillar_06", Vector3(dx + sx * 1.0, 0, pz), 0.0, Vector3(1, 0.97, 1))
		_put(b, "#wall_lamp", Vector3(dx + sx * 1.0, 2.15, pz + 0.25), 0.0, Vector3.ONE * 0.85)
	b.light(Vector3(dx, 1.95, pz + 0.6))
	_gable(b, R(dx - 1.25, dx + 1.25, z0 - 0.05, z0 + deep + 0.12), FL - 0.12, 1.25, true, "SM_Bld_Roof_Topper_06", false, false)
	var front := pz + 0.26
	b.door = b.base * Vector3(dx, 0, front + 0.45)
	return front


## Ворота сада: проём в низкой ограде по линии z от x0 до x1, калитка шириной 2·gw в точке gx; постаменты с вазами
static func _garden_front(b: Bp, x0: float, x1: float, z: float, gx: float, gw := 0.8, statues := true) -> void:
	_lowwall(b, Vector3(x0, 0, z), Vector3(gx - gw, 0, z), 0.8)
	_lowwall(b, Vector3(gx + gw, 0, z), Vector3(x1, 0, z), 0.8)
	for sx: float in [-1.0, 1.0]:
		var p := Vector3(gx + sx * (gw + 0.15), 0, z - 0.1)
		if statues:
			_put(b, "SM_Prop_Pillar_Base_01", p, 0.0, Vector3(0.5, 1.3, 0.5))
			_put(b, "SM_Prop_Vase_0%d" % b.pick([1, 3, 5]), p + Vector3(0, 1.3, 0), 0.0, Vector3.ONE * 0.6)
		else:
			_put(b, "SM_Prop_Pillar_Base_01", p, 0.0, Vector3(0.45, 1.1, 0.45))
	b.door = b.base * Vector3(gx, 0, z + 0.7)


## Домус патрициев (след до 10×10 м): четыре облика, 1–2 этажа
static func _house_patrician(b: Bp, floors: int, v: int) -> void:
	floors = clampi(floors, 1, 2)
	_begin(b, "patrician")
	match v % 4:
		0: _pat_peristyle(b, floors)
		1: _pat_portico(b, floors)
		2: _pat_tower(b, floors)
		_: _pat_garden(b, floors)


## 0 «Перистиль»: фасад с парадной дверью под протироном, окна под фронтончиками у двери; за домом — сад
## с колоннадой, фонтаном, кипарисами и статуей
static func _pat_peristyle(b: Bp, floors: int) -> void:
	var rf := R(-5.0, 5.0, 1.5, 4.0)
	var cor := _cor(b)
	var shut := _shut(b)
	var pd := 1 + b.rng.randi() % 2           # пролёт парадной двери
	for f in floors:
		var front := [W1, W1, W1, W1]
		if f == 0:
			front[pd] = DOUBLE
			front[pd - 1] = W5
			front[pd + 1] = W5
		else:
			front = [W1, W5, W5, W1]
		var back := [W1, W1, W1, W1] if f == 0 else [W2, W6, WALL, W2]
		_storey(b, rf, f, {0: front, 1: [W6], 2: back, 3: [W6]}, {"cornice": cor if f == floors - 1 else TRIM_MID})
		for i in 4:
			if front[i] == W1:
				_win(b, rf, 0, i, f, shut, f == 0 or b.chance(0.6))
		if f == 0:
			for i: int in [0, 3]:
				_shutters(b, rf, 2, i, 0.0, shut)
	_dark(b, rf, 0.0, floors * FL)
	_grand_door(b, rf, pd)
	_porch(b, rf, pd)
	var dx := rf[0] + pd * M + 1.25
	if floors >= 2:
		b.brazier(Vector3(dx - 1.7, 0, rf[3] + 0.35))
		b.brazier(Vector3(dx + 1.7, 0, rf[3] + 0.35))
	else:
		for sx: float in [-1.6, 1.6]:
			_pot(b, Vector3(dx + sx, 0, rf[3] + 0.45), 0.55)
	var ridge := _gable(b, rf, floors * FL, 2.0, false, _topper(b))
	_chimney(b, Vector3(2.0 if pd == 1 else -2.0, ridge - 0.25, 2.75))
	# сад-перистиль: стены по краям, колоннада с черепичными скатами, фонтан, клумбы, кипарисы, статуя
	b.remap = b.floor_remap(0)
	var wr := _wr(b)
	_put(b, WALL, Vector3(-5.0, 0, -5.5), -PI / 2, Vector3(2.8, 1, 1), wr)
	_put(b, WALL, Vector3(5.0, 0, 1.5), PI / 2, Vector3(2.8, 1, 1), wr)
	_put(b, cor, Vector3(-5.0, FL - 0.33, -5.5), -PI / 2, Vector3(2.8, 1, 1))
	_put(b, cor, Vector3(5.0, FL - 0.33, 1.5), PI / 2, Vector3(2.8, 1, 1))
	_put(b, WALL, Vector3(5.0, 0, -5.5), PI, Vector3(4, 1, 1), wr)
	_put(b, cor, Vector3(5.0, FL - 0.33, -5.5), PI, Vector3(4, 1, 1))
	_put(b, "SM_Bld_Wall_End_01", Vector3(5.0, 0, -5.5), PI, Vector3.ONE, b.remap.duplicate())
	_put(b, "SM_Bld_Wall_End_01", Vector3(-5.0, 0, -5.5), -PI / 2, Vector3.ONE, b.remap.duplicate())
	b.remap = b.floor_remap(1)
	var rw := R(-5.0, 5.0, -5.5, 1.5)
	_ivy(b, rw, 2, b.rng.randf_range(1.5, 3.5), 1.4)
	_ivy(b, rw, b.pick([1, 3]), b.rng.randf_range(3.0, 5.0), 1.5)
	var ch := 0.8
	for z: float in [-3.6, -1.35, 0.9]:
		_put(b, "SM_Bld_Pillar_06", Vector3(-3.55, 0, z), 0.0, Vector3.ONE * ch)
		_put(b, "SM_Bld_Pillar_06", Vector3(3.55, 0, z), 0.0, Vector3.ONE * ch)
	for x: float in [-1.2, 1.2]:
		_put(b, "SM_Bld_Pillar_06", Vector3(x, 0, -3.95), 0.0, Vector3.ONE * ch)
	# скаты колоннады упираются торцами в стены — торцевые детали не нужны
	_lean(b, R(-5.0, -3.4, -5.5, 1.5), 2.42, 1.2, 1, false, false)
	_lean(b, R(3.4, 5.0, -5.5, 1.5), 2.42, 1.2, 3, false, false)
	_lean(b, R(-3.4, 3.4, -5.5, -3.8), 2.42, 1.25, 0, false, false)
	_put(b, "SM_Env_Ivy_Pillar_Flowers_0%d" % (1 + b.rng.randi() % 2), Vector3(-3.55, 0, 0.9), 0.3)
	_fountain(b, Vector3(0, 0, -1.2), 0.5)
	_bed(b, Vector3(-1.9, 0, 0.55), 0.0, 0.75)
	_bed(b, Vector3(1.9, 0, 0.55), 0.0, 0.75)
	_bed(b, Vector3(-1.9, 0, -2.9), 0.0, 0.7)
	_cypress(b, Vector3(-2.7, 0, -1.1))
	_cypress(b, Vector3(2.7, 0, -1.1))
	_statue(b, Vector3(1.25, 0, -3.0), 0.0, 0.6)
	_put(b, "SM_Prop_Seat_Kline_0%d" % (1 + b.rng.randi() % 3), Vector3(-4.3, 0, -1.2), PI / 2, Vector3.ONE * 0.62)
	_put(b, "SM_Prop_Brazier_03", Vector3(-1.25, 0, -4.6), 0.0, Vector3.ONE * 0.6)
	_put(b, "SM_Prop_Brazier_03_Insert_01", Vector3(-1.25, 0, -4.6), 0.0, Vector3.ONE * 0.6)


## 1 «Портик»: дом за колоннадой во всю ширину, над входом — фронтон; на втором этаже — солярий над портиком
## со статуями по углам; сзади сад
static func _pat_portico(b: Bp, floors: int) -> void:
	var r0 := R(-5.0, 5.0, -2.5, 2.5)
	var cor := _cor(b)
	var shut := _shut(b)
	var pil := "SM_Bld_Pillar_0%d" % b.pick([1, 1, 2])
	var zc := 4.15
	for f in floors:
		var front := [W5, DOUBLE, W5, W1] if f == 0 else [W1, D4, D4, W1]
		_storey(b, r0, f, {0: front, 1: [W6, W1], 2: [W1, W6, WALL, W1] if f == 0 else [W2, W1, W1, W2], 3: [W1, WALL]},
			{"cornice": cor if f == floors - 1 else TRIM_MID})
		if f == 0:
			for i: int in [0, 3]:
				_shutters(b, r0, 2, i, 0.0, shut)
			_shutters(b, r0, 1, 1, 0.0, shut)
			_shutters(b, r0, 3, 0, 0.0, shut)
			_win(b, r0, 0, 3, 0, shut, false)
		else:
			_win(b, r0, 0, 0, f, shut)
			_win(b, r0, 0, 3, f, shut)
			for i: int in [1, 2]:
				_door2(b, r0, 0, i, f)
			for i: int in [1, 2]:
				_shutters(b, r0, 2, i, f * FL, shut)
	_dark(b, r0, 0.0, floors * FL)
	_grand_door(b, r0, 1)
	b.door = b.base * Vector3(-1.25, 0, 5.4)
	# фонари на простенках по сторонам парадной двери
	_lamp(b, r0, 0, M - 0.35, 2.3)
	_put(b, "#wall_lamp", (_sp(r0, 0, 2 * M + 0.35, 2.3, 0.11)[0] as Vector3), 0.0)
	# портик: колонны, архитрав, черепичный скат или терраса-солярий
	for k in 5:
		_put(b, pil, Vector3(-4.65 + k * 2.325, 0, zc), 0.0)
	b.remap = b.floor_remap(0)
	for k in 4:
		_put(b, "SM_Bld_Wall_Tiny_01", Vector3(-5.0 + k * M, FL - 0.31, zc + 0.05), 0.0, Vector3.ONE, b.remap.duplicate())
	b.remap = b.floor_remap(1)
	var rp := R(-5.0, 5.0, 2.5, 4.4)
	if floors == 1:
		_lean(b, rp, FL - 0.02, 0.45, 0)
		# фронтон над пролётом входа — как у храма
		_gable(b, R(-2.45, 0.1, 2.6, 4.5), FL - 0.04, 1.0, true, "SM_Bld_Roof_Topper_06", false, false)
	else:
		b.remap = b.floor_remap(0)
		_terrace(b, R(-5.0, 5.0, 2.5, 4.4), FL, [], "")
		for k in 4:
			_put(b, "SM_Bld_Wall_Balcony_06", Vector3(-5.0 + k * M, FL, 4.4), 0.0, Vector3.ONE, b.remap.duplicate())
		for side: int in [1, 3]:
			_on(b, "SM_Bld_Wall_Balcony_06", rp, side, 0.0, FL, 0.0, 1.0, true, 0.0)
		b.remap = b.floor_remap(1)
		# статуи по углам солярия — видно издалека
		for sx: float in [-1.0, 1.0]:
			_put(b, "SM_Prop_Statue_0%d" % b.pick([3, 5, 6]), Vector3(sx * 4.75, FL + 1.0, 4.2), PI * 0.1 * -sx, Vector3.ONE * 0.5)
		_pot(b, Vector3(-3.6, FL + 0.07, 3.8), 0.55)
		_pot(b, Vector3(3.6, FL + 0.07, 3.8), 0.55)
		_bench(b, Vector3(-1.9, FL + 0.07, 3.0))
		_ivy_drape(b, R(-5.0, 5.0, 2.5, 4.4), 0, 7.5, FL + 1.0)
	_put(b, "SM_Prop_Rug_0%d" % (1 + b.rng.randi() % 4), Vector3(-1.25, 0.01, 3.3), PI / 2, Vector3.ONE * 0.7)
	for sx: float in [-1.0, 1.0]:
		if floors == 1:
			_statue(b, Vector3(sx * 3.5, 0, 3.3), -sx * PI * 0.1, 0.55)
		else:
			_put(b, "SM_Prop_Pillar_Base_01", Vector3(sx * 3.5, 0, 3.3), 0.0, Vector3(0.5, 1.2, 0.5))
			_put(b, "SM_Prop_Vase_05", Vector3(sx * 3.5, 1.2, 3.3), 0.0, Vector3.ONE * 0.6)
	var ridge := _hip(b, r0, floors * FL, 1.6, _topper(b))
	_chimney(b, Vector3(1.6, ridge - 0.25, 0.0))
	# сад за домом: ограда, фонтан, кипарисы, клумбы, ложе
	_lowwall(b, Vector3(-5.0, 0, -2.6), Vector3(-5.0, 0, -5.5), 1.1, false)
	_lowwall(b, Vector3(-5.0, 0, -5.5), Vector3(5.0, 0, -5.5), 1.1, false)
	_lowwall(b, Vector3(5.0, 0, -5.5), Vector3(5.0, 0, -2.6), 1.1, false)
	_fountain(b, Vector3(-1.0, 0, -4.1), 0.42)
	_cypress(b, Vector3(-4.3, 0, -4.9), 0.42)
	_cypress(b, Vector3(4.3, 0, -4.9), 0.42)
	_bed(b, Vector3(1.3, 0, -3.3), 0.0, 0.75)
	_bed(b, Vector3(-3.4, 0, -3.3), 0.0, 0.75)
	_put(b, "SM_Prop_Seat_Kline_0%d" % (1 + b.rng.randi() % 3), Vector3(3.6, 0, -3.6), -PI / 2, Vector3.ONE * 0.6)
	if floors >= 2:
		b.brazier(Vector3(-2.85, 0, 3.1))
		b.brazier(Vector3(0.35, 0, 3.1))


## 2 «Башня»: дом с садовой башней-бельведером (лоджия под вальмовой крышей), у входа протирон, впереди цветник,
## сзади большой виноградный навес над ложами и фонтан
static func _pat_tower(b: Bp, floors: int) -> void:
	var left := b.chance(0.5)
	var rm := R(-5.0, 2.5, -2.5, 2.5) if left else R(-2.5, 5.0, -2.5, 2.5)
	var rt := R(2.5, 5.0, 0.0, 2.5) if left else R(-5.0, -2.5, 0.0, 2.5)
	var tq := R(2.5, 5.0, -2.5, 0.0) if left else R(-5.0, -2.5, -2.5, 0.0)
	var cor := _cor(b)
	var shut := _shut(b)
	var m_in := 1 if left else 3
	var t_in := 3 if left else 1
	var t_out := 1 if left else 3
	var di := 1
	for f in floors:
		var front := [W5, DOUBLE, W5] if f == 0 else [W1, D4, W1]
		var inner := ["", W6] if m_in == 1 else [W6, ""]
		_storey(b, rm, f, {0: front, m_in: inner, 2: _bk(b, rm, f, shut), (m_in + 2) % 4: [W6, W1]}, {"cornice": cor if f == floors - 1 else TRIM_MID})
		_shutters(b, rm, (m_in + 2) % 4, 1, f * FL, shut)
		if f > 0:
			_win(b, rm, 0, 0, f, shut)
			_win(b, rm, 0, 2, f, shut)
			_balcony(b, rm, 0, 1, f)
			_door2(b, rm, 0, 1, f)
	_dark(b, rm, 0.0, floors * FL)
	_grand_door(b, rm, di)
	_porch(b, rm, di, 1.0)
	var ridge := _gable(b, rm, floors * FL, 1.8, false, _topper(b))
	_chimney(b, Vector3((rm[0] + rm[1]) / 2.0 - 1.0, ridge - 0.25, 0.0))
	# башня: на этаж выше дома, наверху лоджия с колоннами
	var tf := floors + 1
	for f in tf - 1:
		_storey(b, rt, f, {0: [W5] if f == 0 else [W1], t_in: [""] if f < floors else [W6], 2: [WALL] if f == 0 else [W1], t_out: [W6] if f == 0 else [WALL]},
			{"cornice": cor if f == tf - 2 else TRIM_MID})
		if f > 0:
			_win(b, rt, 0, 0, f, shut)
	_dark(b, rt, 0.0, (tf - 1) * FL)
	var lf := tf - 1
	b.remap = b.floor_remap(lf)
	_terrace(b, rt, lf * FL, [], "")
	b.remap = b.floor_remap(1)
	for c: Vector3 in [Vector3(rt[0] + 0.3, 0, rt[2] + 0.3), Vector3(rt[1] - 0.3, 0, rt[2] + 0.3), Vector3(rt[0] + 0.3, 0, rt[3] - 0.3), Vector3(rt[1] - 0.3, 0, rt[3] - 0.3)]:
		_put(b, "SM_Bld_Pillar_06", c + Vector3(0, lf * FL, 0), 0.0, Vector3.ONE * 0.8)
	b.remap = b.floor_remap(lf)
	for side: int in [0, 1, 2, 3]:
		_on(b, "SM_Bld_Wall_Balcony_04", rt, side, 0.0, lf * FL, -0.3, 1.0, true)
	b.remap = b.floor_remap(1)
	_hip(b, R(rt[0] + 0.05, rt[1] - 0.05, rt[2] + 0.05, rt[3] - 0.05), lf * FL + 2.4, 1.9, "SM_Bld_Roof_Topper_06")
	_hang_lamp(b, Vector3((rt[0] + rt[1]) / 2.0, lf * FL + 0.07, (rt[2] + rt[3]) / 2.0))
	# дворик за башней: скамья у стены и амфора
	_bench(b, Vector3((tq[0] + tq[1]) / 2.0, 0, tq[3] - 0.45), PI)
	_jar(b, Vector3(tq[0] + 0.45 if left else tq[1] - 0.45, 0, tq[2] + 0.6), 0.75)
	# цветник перед домом и ограда с воротами (жители входят в ворота)
	var gx := (rm[0] + rm[1]) / 2.0
	_garden_front(b, -5.0, 5.0, 4.4, gx, 0.75, true)
	_bed(b, Vector3(gx - 2.4, 0, 3.4), 0.0, 0.8)
	_bed(b, Vector3(gx + 2.4, 0, 3.4), 0.0, 0.8)
	_cypress(b, Vector3((rt[0] + rt[1]) / 2.0, 0, 3.5), 0.38)
	# сад сзади: большая пергола с виноградом над ложем и столом, фонтан
	_put(b, "SM_Bld_Trellis_Roof_Large_01", Vector3(-1.0, 2.35, -5.4), 0.0, Vector3(1.0, 1.0, 0.55))
	for c: Vector3 in [Vector3(-0.85, 0, -5.25), Vector3(4.15, 0, -5.25), Vector3(-0.85, 0, -2.75), Vector3(4.15, 0, -2.75)]:
		_put(b, "SM_Bld_Trellis_Pillar_01", c, 0.0, Vector3.ONE * 0.78)
	_put(b, "SM_Env_Vine_0%d" % (1 + b.rng.randi() % 3), Vector3(0.8, 2.45, -4.0), 0.2, Vector3.ONE * 1.2)
	_put(b, "SM_Env_Vine_0%d" % (1 + b.rng.randi() % 3), Vector3(3.0, 2.45, -4.1), 2.0, Vector3.ONE * 1.2)
	_put(b, "SM_Prop_Seat_Kline_0%d" % (1 + b.rng.randi() % 3), Vector3(0.6, 0, -4.6), 0.0, Vector3.ONE * 0.62)
	_fountain(b, Vector3(-3.4, 0, -4.1), 0.42)
	_lowwall(b, Vector3(-5.0, 0, -2.6), Vector3(-5.0, 0, -5.6), 1.0, false)
	_lowwall(b, Vector3(-5.0, 0, -5.6), Vector3(5.0, 0, -5.6), 1.0, false)
	_lowwall(b, Vector3(5.0, 0, -5.6), Vector3(5.0, 0, -2.6), 1.0, false)
	if floors >= 2:
		b.brazier(Vector3(gx - 1.6, 0, 3.0))


## 3 «Сад»: домус фронтоном к улице с протироном у входа, рядом — сад за оградой с перголой,
## фонтаном, статуей и клумбами; за домом колодец
static func _pat_garden(b: Bp, floors: int) -> void:
	var left := b.chance(0.5)
	var rm := R(-5.0, 0.0, -3.5, 4.0) if left else R(0.0, 5.0, -3.5, 4.0)
	var gx0 := 0.0 if left else -5.0
	var gx1 := 5.0 if left else 0.0
	var g_side := 1 if left else 3          # сторона дома к саду
	var o_side := 3 if left else 1
	var cor := _cor(b)
	var shut := _shut(b)
	var di := 1 if left else 0
	var gz := 3.9                           # линия ограды сада
	for f in floors:
		var front := [W5, W5]
		if f == 0:
			front[di] = DOUBLE
		else:
			front = [W1, W1]
		var gs := [W1, D4, W1] if f == 0 else [W1, W5, W1]
		_storey(b, rm, f, {0: front, g_side: gs, 2: _bk(b, rm, f, shut), o_side: [W6, W1, WALL] if f == 0 else [W2, WALL, W2]},
			{"cornice": cor if f == floors - 1 else TRIM_MID})
		for i in 3:
			if gs[i] == W1:
				_win(b, rm, g_side, i, f, shut, f > 0)
		if f == 0:
			if b.chance(0.5):
				_frieze(b, rm, g_side, f, gs)
			_shutters(b, rm, o_side, 1, 0.0, shut)
		if f > 0:
			for i in 2:
				_win(b, rm, 0, i, f, shut)
	_dark(b, rm, 0.0, floors * FL)
	_grand_door(b, rm, di)
	_porch(b, rm, di)
	_door2(b, rm, g_side, 1, 0)
	# фронтон к улице с медальоном
	var ridge := _gable(b, rm, floors * FL, 1.5, true, _topper(b))
	_medallion(b, rm, 0, 2.5, floors * FL + 0.45)
	_chimney(b, Vector3((rm[0] + rm[1]) / 2.0, ridge - 0.25, -1.9))
	_ivy(b, rm, o_side, 4.4, 1.6)
	# сад: ограда спереди и сзади, ворота, пергола, фонтан, статуя, клумбы, кипарисы
	var gcx := (gx0 + gx1) / 2.0
	var dsave := b.door
	_garden_front(b, gx0, gx1, gz, gcx, 0.7, true)
	b.door = dsave
	_lowwall(b, Vector3(gx1 if left else gx0, 0, gz), Vector3(gx1 if left else gx0, 0, -5.5), 1.0, false)
	_lowwall(b, Vector3(gx0, 0, -5.5), Vector3(gx1, 0, -5.5), 1.0, false)
	_fountain(b, Vector3(gcx, 0, 0.6), 0.5)
	_bed(b, Vector3(gcx - 1.5, 0, 2.9), 0.0, 0.75)
	_bed(b, Vector3(gcx + 1.5, 0, 2.9), 0.0, 0.75)
	_statue(b, Vector3(gcx + (1.7 if left else -1.7), 0, -1.2), -PI / 2 if left else PI / 2, 0.6)
	_cypress(b, Vector3(gx1 - 0.6 if left else gx0 + 0.6, 0, 3.2), 0.4)
	_cypress(b, Vector3(gx1 - 0.6 if left else gx0 + 0.6, 0, -1.4), 0.4)
	_pergola(b, gcx - 1.25, -4.9, 0.0, false)
	_put(b, "SM_Prop_Seat_Kline_0%d" % (1 + b.rng.randi() % 3), Vector3(gcx - 0.9, 0, -3.7), PI / 2, Vector3.ONE * 0.6)
	_put(b, "SM_Env_Flowers_0%d" % (1 + b.rng.randi() % 5), Vector3(gcx + 0.2, 0.01, -1.1), b.rng.randf() * TAU, Vector3.ONE * 1.4)
	# двор за домом: колодец
	_put(b, "SM_Prop_Well_01", Vector3((rm[0] + rm[1]) / 2.0 - 1.2, 0, -4.6), b.rng.randf() * TAU, Vector3.ONE * 0.5)
	_jar(b, Vector3((rm[0] + rm[1]) / 2.0 + 1.3, 0, -5.0), 0.7)
	if floors >= 2:
		# жаровни: у стены по другую сторону протирона и в саду у ворот (не на дорожке к двери)
		var dx := rm[0] + di * M + 1.25
		b.brazier(Vector3(dx + (-1.7 if left else 1.7), 0, rm[3] + 0.35))
		b.brazier(Vector3(gcx + (1.3 if left else -1.3), 0, gz - 0.35))
