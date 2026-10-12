class_name CatHouses
extends RefCounted
## Облик жилья: дома плебеев, ремесленников, патрициев — маленькие, уютные, как в Town to City, но римские
## (Помпеи, Остия, Кампания). Чертёж Bp строится в родных размерах Synty (пролёт 2,5 м, этаж 3 м);
## Catalog.make потом уменьшает его до «кукольного» масштаба (Catalog.ARCH).
## Как в Town to City: у всех обликов одного класса ОДНА И ТА ЖЕ коробка — ширина, глубина, линия фасада, этажи,
## высота карниза и конька. Дома узкие (просьба владельца): у всех трёх классов фасад одной ширины — два пролёта
## (дверь и окно/лавка), собранные из пролётов Synty по 2,5 м и сжатые вдоль фасада (_narrow, SX) до 4 м.
## Плебеи — коробка 5 м в глубину; ремесленники — та же коробка с лавкой внизу и двором-мастерской под навесом
## за домом; патриции — коробка за портиком с тремя колоннами на мраморном полу и сад за стенами. Разные только фасад (дверь, окна,
## ставни, балконы, навесы, фризы, таблички, фонари, цветы, плющ, статуи), вид крыши (шатровая, двускатная,
## фронтоном к улице — конёк на одной высоте), черепица, навершия, место трубы и цвет штукатурки.
## Рост тоже один на класс: tier = этажи; второй этаж — во всю глубину, третий — в глубине, впереди терраса.

const M := Bp.M
const FL := Bp.FL

# пролёты стен
const WALL := "SM_Bld_Wall_01"
const W1 := "SM_Bld_Wall_Window_01"      # окно (со ставнями и ящиком цветов)
const W2 := "SM_Bld_Wall_Window_02"      # три окошка под карнизами (только сбоку и сзади)
const W4 := "SM_Bld_Wall_Window_04"      # длинное окно под карнизом
const W5 := "SM_Bld_Wall_Window_05"      # окно с фронтоном
const W6 := "SM_Bld_Wall_Window_06"      # два арочных проёма — на стенах домов не ставим (издали читались тёмными дырками)
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


## Узкие дома: чертёж собирается в пролётах Synty по 2,5 м, а в конце сжимается вдоль фасада (ось X) в SX раз.
## Стены, карнизы, крыши, двери и ставни, ступени, навесы, ящики цветов, плющ и лоза сжимаются вместе с пролётом;
## вещи (горшки, скамьи, амфоры, фонари, статуи, колонны, трубы, таблички, вывески, навершия) сохраняют пропорции —
## сдвигается только их середина. Огни, дым и вход — следом
const SX := 0.75
const RIGID := ["SM_Bld_Pillar", "SM_Bld_Roof_Topper", "SM_Bld_Ornament", "SM_Bld_Trellis_Pillar", "SM_Env_Ivy_Pillar"]
const FLEX := ["SM_Bld_", "#dark", "SM_Prop_Overhang", "SM_Prop_Mural", "SM_Prop_FlowerBed", "SM_Prop_Drapery", "SM_Env_Ivy", "SM_Env_Vine"]


static func _flex(nm: String) -> bool:
	for s: String in RIGID:
		if nm.begins_with(s):
			return false
	for s: String in FLEX:
		if nm.begins_with(s):
			return true
	return false


static func _narrow(b: Bp, sx := SX) -> void:
	var S := Basis.from_scale(Vector3(sx, 1, 1))
	var k := Vector3(sx, 1, 1)
	for p: Array in b.parts:
		var nm: String = p[0]
		var xf: Transform3D = p[1]
		if _flex(nm):
			p[1] = Transform3D(S * xf.basis, xf.origin * k)
		else:
			var c := xf * Bp.model_aabb(nm).get_center()
			p[1] = Transform3D(xf.basis, xf.origin + Vector3(c.x * (sx - 1.0), 0, 0))
	for i in b.lights.size():
		b.lights[i] = b.lights[i] * k
	for i in b.smoke.size():
		b.smoke[i] = b.smoke[i] * k
	b.door = b.door * k


## Начало дома: класс жильцов, черепица (только терракота), решётки окон по классу, штукатурка без «фахверка».
## Случайность не зависит от этажности (Catalog сеет её ключом с tier — у дома при росте всё переставлялось бы):
## облик и всё у земли — из потока «g» (зерно: класс, облик, цвет), второй этаж — «f1», терраса и третий — «f2»,
## крыша — «roof». Поэтому, когда дом растёт, первый этаж не меняется, а второй — когда надстраивают третий
static func _begin(b: Bp, cls: String, v: int) -> void:
	_corner_runs.clear()
	_st = {"cls": cls, "bal": 0, "mural": false}
	var key := "%s|%d|%s" % [cls, v, b.tint.to_html()]
	var rs := {}
	for k: String in ["g", "f1", "f2", "roof"]:
		var r := RandomNumberGenerator.new()
		r.seed = hash(key + "|" + k)
		rs[k] = r
	_st["rng"] = rs
	_use(b, "g")
	_st["close_k"] = b.rng.randi() % 2
	_st["tp"] = _topper(b)
	# Решётки окон: W1 низ/верх, W5 низ/верх, оттенок дерева. Пока у решёток нет прозрачности (synty.gd), читается только
	# косой крест Window_01 (у остальных текстур проёмы и прутья одного тёмного цвета — окно выглядит чёрной дырой).
	# Когда прозрачность появится, патрициям можно дать узорные Window_03/04, плебеям внизу — прутья Window_02
	match cls:
		"pleb": _st["lat"] = ["Window_01", "Window_01", "Window_01", "Window_01", WIN_TINT]
		"artisan": _st["lat"] = ["Window_01", "Window_01", "Window_01", "Window_01", Color(0.95, 0.82, 0.7)]
		_: _st["lat"] = ["Window_01", "Window_01", "Window_01", "Window_01", Color(1.1, 1.0, 0.86)]
	# гладкий штукатурный парапет балкончика издали читается как глухой ящик на фасаде — только прутья или камень
	_st["jrail"] = "stone" if cls == "patrician" else b.pick(["bars", "stone", "bars"])
	b.ground_style = "plain"
	if cls == "patrician":
		b.roof_tex = b.pick(["Roof_Tile_03", "Roof_Tile_12"])
	else:
		b.roof_tex = b.pick(["Roof_Tile_01", "Roof_Tile_01", "Roof_Tile_12", "Roof_Tile_03"])
	# узорная штукатурка (Stucco_White_Pattern) на этажах читается как фахверк — даже на белом (синие полосы);
	# у жилья штукатурка гладкая, богатство — в отделке
	b.upper_style = "plain"
	b.remap = b.floor_remap(1)


## Перейти на поток случайности k ("g", "f1", "f2", "roof") — см. _begin
static func _use(b: Bp, k: String) -> void:
	b.rng = (_st["rng"] as Dictionary)[k]


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
## o: cornice (карниз; TRIM_MID — тонкий поясок; "" — без), plinth (каменный цоколь), no_plinth (стороны без цоколя),
## sides, corners, y
static func _storey(b: Bp, r: PackedFloat32Array, f: int, spec: Dictionary, o := {}) -> void:
	var y: float = o.get("y", f * FL)
	var cor: String = o.get("cornice", "SM_Bld_Trim_02")
	var cy := FL - (0.11 if cor == TRIM_MID else 0.33)
	var plinth0: bool = o.get("plinth", f == 0)
	var no_plinth: Array = o.get("no_plinth", [])
	var sides: Array = o.get("sides", [0, 1, 2, 3])
	b.remap = b.floor_remap(f)
	var wr := _wr(b)
	var ww := _wrw(b, f)
	for side: int in sides:
		var names: Array = spec.get(side, [])
		var n := _n(r, side)
		var plinth := plinth0 and not no_plinth.has(side)
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


## Парадная двустворчатая дверь домуса: створки во весь проём (2 м); порог — мраморный пол портика (_podium);
## сюда входят жители
static func _grand_door(b: Bp, r: PackedFloat32Array, i: int) -> void:
	var nm := "SM_Bld_Door_Half_0%d" % b.pick([2, 3])
	for k in 2:
		var a := _sp(r, 0, i * M + 0.25 + k * 1.0, 0.0, -0.02)
		_put(b, nm, a[0], a[1], Vector3(2.0, 1.08, 1.0))
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


## Окно со ставнями и цветами; на каждом верхнем этаже фасада одно окно — с закрытыми ставнями
## (счёт окон — свой у каждого этажа: надстроенный третий не меняет второй)
static func _win(b: Bp, r: PackedFloat32Array, side: int, i: int, f: int, leaf: String, box := true) -> void:
	var closed := false
	if f >= 1 and side == 0:
		var k := "upwin%d" % f
		closed = int(_st.get(k, 0)) == int(_st.get("close_k", 0))
		_st[k] = int(_st.get(k, 0)) + 1
	_shutters(b, r, side, i, f * FL, leaf, closed)
	if box:
		_wbox(b, r, side, i, f * FL)


## Низ настенного фонаря — не ниже этого (в родных метрах): у Bp.footprint() всё, что висит ниже 1,6 м игры, занимает
## землю; фонарь пониже «съедал» бы клетку мостовой перед фасадом, а у обликов одного класса след был бы разный
static func _lamp_y(y: float) -> float:
	return maxf(y, 1.63 / Catalog.ARCH)


## Римский фонарь на кронштейне (ночью горит)
static func _lamp(b: Bp, r: PackedFloat32Array, side: int, u: float, y := 2.25) -> void:
	y = _lamp_y(y)
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
	if not rug:
		return                       # голый балкончик (второй на фасаде)
	if b.chance(0.6):
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


## Медальон в треугольнике фронтона — небольшой, мраморный, и не на каждом доме (sure — обязательно)
static func _medallion(b: Bp, r: PackedFloat32Array, side: int, u: float, y: float, sure := false) -> void:
	if not sure and not b.chance(0.5):
		return
	var a := _sp(r, side, u, y, 0.12)
	_put(b, "SM_Bld_Ornament_0%d" % b.pick([1, 2, 4, 5]), a[0], a[1], Vector3.ONE * b.rng.randf_range(0.45, 0.55),
		{"PolygonAncientEmpire_01_A": "Building_Marble_02"})


## Плющ (с цветами) на стене
static func _ivy(b: Bp, r: PackedFloat32Array, side: int, u: float, y: float, flowers := true, s := 1.0) -> void:
	var nm := ("SM_Env_Ivy_Flowers_%02d" if flowers else "SM_Env_Ivy_%02d") % b.pick([1, 2, 3, 4, 5, 8, 9])
	_on(b, nm, r, side, u, y, 0.13, s)


## Плющ свисает с парапета террасы — целиком в пределах стены (широкие плети не свешиваются за угол к соседу)
static func _ivy_drape(b: Bp, r: PackedFloat32Array, side: int, u: float, y: float) -> void:
	var nm := "SM_Env_Ivy_Draped_Flowers_0%d" % b.pick([1, 2, 3])
	var box := Bp.model_aabb(nm)
	var w := ((r[1] - r[0]) if side % 2 == 0 else (r[3] - r[2]))
	var lo := -box.position.x + 0.05
	var hi := w - box.end.x - 0.05
	_on(b, nm, r, side, clampf(u, lo, hi) if lo <= hi else w / 2.0, y, 0.12)


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
	_put(b, "SM_Prop_Seat_Bench_01", Vector3(r[0] + i * M + 1.25, 0, r[3] + 0.5), 0.0, Vector3.ONE * 0.75)    # пролёт узкий — скамья короче
	_pot(b, Vector3(r[0] + i * M + (0.18 if b.chance(0.5) else 2.32), 0, r[3] + 0.46), 0.42)


## Задняя стена этажа — одна на класс (облики различаются фасадом, зад у всех одинаковый), без случайности:
## внизу окно с решёткой и задняя дверь со ступенькой; на втором этаже окна со ставнями (у ремесленников между
## ними висячие цветы); наверху окошки под карнизом. У домуса (в сад): внизу двустворчатая дверь в сад с широкой
## ступенью (створки — _house_patrician) и окно, наверху окно с фронтончиком и окно со ставнями
static func _bk(b: Bp, r: PackedFloat32Array, f: int, shut: String) -> Array:
	var n := _n(r, 2)
	var a: Array
	if String(_st.get("cls", "")) == "patrician" and n == 2:
		if f == 0:
			var s := _sp(r, 2, 0.2, 0.0, 0.06)
			_put(b, "SM_Bld_Floor_Trim_01", s[0], s[1], Vector3(0.84, 1.0, 0.55))
			return [D4, W1]
		_shutters(b, r, 2, 1, f * FL, shut)
		return [W5, W1]
	match f:
		0:
			a = [W1, D4] if n == 2 else [W1, D4, W1]
			_door(b, r, 2, 1, "SM_Bld_Door_01", 0.0, false)
			_step(b, r, 2, 1)
		1:
			a = [W1, W2] if n == 2 else [W1, WALL, W1]      # одно окно со ставнями, другое — окошки под карнизом
			if n == 3:
				_on(b, "SM_Prop_FlowerPot_Hanging_05", r, 2, 1.5 * M, FL + 2.3, 0.11, 0.6)
		_:
			a = [W2, W2] if n == 2 else [W2, WALL, W2]
	# у трёхэтажного окно второго этажа сзади — без ставен (сзади их почти не видно, а деталей у дома и так много)
	var bare := f == 1 and int(_st.get("floors", 0)) >= 3
	for i in n:
		if f >= 1 and a[i] == W1 and not bare:
			_shutters(b, r, 2, i, f * FL, shut)
	return a


## У задней стены — приставленная лестница (иногда с корзиной у подножия) или пара амфор, в простенке между окном
## и задней дверью (_bk); низкие мешки и сноп издали читались камнями и пнём. Задний край — всегда ровно в BACK
## от линии стены, чтобы след на земле у всех обликов класса был одинаковый
const BACK := 0.45
static func _back_prop(b: Bp, r: PackedFloat32Array) -> void:
	var u := M - 0.05 + b.rng.randf_range(-0.1, 0.1)
	match b.rng.randi() % 3:
		1:
			_back_put(b, "SM_Prop_Vase_05", r, u - 0.2, Basis(Vector3.UP, b.rng.randf() * TAU).scaled(Vector3.ONE * 0.72))
			_back_put(b, b.pick(["SM_Prop_Vase_02", "SM_Prop_Jar_01"]), r, u + 0.22, Basis(Vector3.UP, b.rng.randf() * TAU).scaled(Vector3.ONE * 0.55), 0.08)
		var k:
			_back_put(b, "SM_Prop_Ladder_01", r, u, Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -0.1).scaled(Vector3.ONE * 0.8))
			if k == 2:
				_back_put(b, "SM_Prop_Basket_0%d" % b.pick([1, 2]), r, u - 0.55, Basis(Vector3.UP, b.rng.randf() * TAU).scaled(Vector3.ONE * 0.6), 0.06)


## Вещь у задней стены r (u — метры вдоль неё от угла +X): задний край — в BACK − gap от линии стены
static func _back_put(b: Bp, nm: String, r: PackedFloat32Array, u: float, bs: Basis, gap := 0.0) -> void:
	var box := Bp.model_aabb(nm)
	var mz := INF
	for k in 8:
		mz = minf(mz, (bs * box.get_endpoint(k)).z)
	b.add_xf(nm, Transform3D(bs, Vector3(r[1] - u, 0, r[2] - BACK + gap - mz)))


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
	# навершия — на той же высоте, что и у двускатной крыши (верх всех обликов класса одинаковый)
	if topper != "":
		if mid > 0.3:
			_fput(b, frame, topper, Vector3(x0 + S / 2.0, ridge - 0.04, 0), PI / 2, Vector3.ONE, {})
			_fput(b, frame, topper, Vector3(x1 - S / 2.0, ridge - 0.04, 0), PI / 2, Vector3.ONE, {})
		else:
			_fput(b, frame, topper, Vector3(0, ridge - 0.04, 0), 0.0, Vector3.ONE, {})
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


## Обстановка террасы (пол на высоте y): горшки по углам, ковёр или плющ на парапете, скамья или столик с кувшином
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
		_put(b, "SM_Prop_Jug_05", Vector3(cx + 0.3, ty + 0.5, rf[2] + 1.2), 0.0)


## Верхний этаж f в глубине (как в Town to City): на задней половине r — комната (пролёты фасада top),
## на передней — терраса с парапетом над этажом ниже. Возвращает прямоугольник комнаты (для крыши)
static func _setback(b: Bp, r: PackedFloat32Array, f: int, top: Array, cor: String, shut: String, rails := [0, 1, 3], cbox := PackedFloat32Array(), dress := true) -> PackedFloat32Array:
	var zm := r[3] - 2.5
	var rb := R(r[0], r[1], r[2], zm)
	var rf := R(r[0], r[1], zm, r[3])
	b.remap = b.floor_remap(f - 1)
	_terrace(b, rf, f * FL, rails, _rail(b) if r[1] - r[0] < 6.0 else "SM_Bld_Wall_Balcony_04")
	b.remap = b.floor_remap(1)
	var ns := _n(rb, 1)
	var s1 := [W2] if ns == 1 else [W2, WALL]
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
	if dress:
		_terrace_dress(b, rf, f * FL)
	return rb


## Пергола с виноградом на террасе (пол на высоте y) над прямоугольником 2,5×2,5 с углом (x, z);
## dx — сдвиг лозы к середине участка (плеть шире решётки и не должна свешиваться за стену к соседу)
static func _pergola(b: Bp, x: float, z: float, y: float, seat := true, lush := true, dx := 0.0) -> void:
	# на террасе задний край перголы лежит на стене комнаты — столбы только спереди
	var posts := [Vector3(x + 0.3, y, z + M - 0.3), Vector3(x + M - 0.3, y, z + M - 0.3)]
	if lush:
		posts.append_array([Vector3(x + 0.3, y, z + 0.3), Vector3(x + M - 0.3, y, z + 0.3)])
	for c: Vector3 in posts:
		_put(b, "SM_Bld_Trellis_Pillar_01", c, 0.0, Vector3.ONE * 0.75)
	_put(b, "SM_Bld_Trellis_Roof_01", Vector3(x + M, y + 2.3, z), 0.0)
	# лоза густо: две плети накрест, свисают с краёв
	# (на террасе — одна плеть пониже: листва не выше конька комнаты)
	var a := b.rng.randf() * TAU
	if not lush:
		_put(b, "SM_Env_Vine_0%d" % (1 + b.rng.randi() % 3), Vector3(x + M / 2.0 + dx, y + 2.3, z + M / 2.0), a, Vector3.ONE)
	else:
		_put(b, "SM_Env_Vine_0%d" % (1 + b.rng.randi() % 3), Vector3(x + M / 2.0 - 0.3 + dx, y + 2.3, z + M / 2.0), a, Vector3.ONE * 1.15)
		_put(b, "SM_Env_Vine_0%d" % (1 + b.rng.randi() % 3), Vector3(x + M / 2.0 + 0.3 + dx, y + 2.3, z + M / 2.0 + 0.3), a + PI / 2, Vector3.ONE * 1.05)
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


## Навершие конька — только невысокие (верх крыши у всех обликов класса на одной высоте); 4-й похож на крест — не для Рима
static func _topper(b: Bp) -> String:
	return "SM_Bld_Roof_Topper_0%d" % b.pick([1, 2, 3])


## Горшок с цветком на мостовой у стены (u — метры вдоль фасада)
static func _front_pot(b: Bp, r: PackedFloat32Array, u: float, s := 0.5) -> void:
	_front_put(b, "SM_Prop_FlowerPot_Fancy_01", r, u, 0.57 * s, s)


## Амфора или кувшин на мостовой у стены
static func _front_jar(b: Bp, r: PackedFloat32Array, u: float, s := 0.75) -> void:
	_front_put(b, b.pick(["SM_Prop_Vase_02", "SM_Prop_Vase_05", "SM_Prop_Vase_01", "SM_Prop_Jar_01", "SM_Prop_Vase_03"]), r, u, 0.0, s, b.rng.randf() * TAU)


# =====================================================================================
#                  каркас: у всех обликов класса одна и та же коробка
# =====================================================================================

## Подъём конька над карнизом — один на класс (у дома и у комнаты на крыше), поэтому крыши всех обликов
## одной высоты, какой бы ни был вид крыши
const RISE := 1.125         # дом плебеев и ремесленников (5 м в глубину)
const RISE_TOP := 0.75      # комната на крыше (2,5 м в глубину)
const RISE_PAT := 1.2       # домус


## Крыша над коробкой r с карнизом на высоте eave: "hip" — шатровая/вальмовая, "gx" — двускатная, конёк вдоль улицы,
## "gz" — фронтоном к улице (скат положе: пролёт шире, а конёк на той же высоте). Навершия, одна труба на коньке
## (chim — где вдоль конька, −1…1), medal — мраморный медальон во фронтоне. Возвращает высоту конька
static func _roof(b: Bp, r: PackedFloat32Array, eave: float, kind: String, rise: float, chim: float, medal := false, detail := true) -> float:
	var w := r[1] - r[0]
	var d := r[3] - r[2]
	var tp: String = _st.get("tp", "SM_Bld_Roof_Topper_01")      # навершие выбрано в _begin — одно на всех этажах
	var at := Vector3((r[0] + r[1]) / 2.0, 0, (r[2] + r[3]) / 2.0)
	var reach := 0.24                  # от конька до дальнего края трубы
	var half := d / 2.0                # полупролёт ската
	match kind:
		"hip":
			half = minf(w, d) / 2.0
			_hip(b, r, eave, rise / (0.75 * half / M), tp)
			var mid := absf(w - d)
			if mid > 0.3:
				var off := chim * maxf(0.0, mid / 2.0 - 0.6)
				at += Vector3(off, 0, 0) if w > d else Vector3(0, 0, off)
			else:
				# шатёр над квадратным домом: труба на скате сбоку от макушки
				at += Vector3(1.0 if chim >= 0.0 else -1.0, 0, 0)
				reach = 1.24
		"gz":
			half = w / 2.0
			_gable(b, r, eave, rise / (0.75 * half / M), true, tp, detail)
			at += Vector3(0, 0, chim * maxf(0.0, d / 2.0 - 0.9))
			if medal:
				_medallion(b, r, 0, w / 2.0, eave + rise * 0.4, true)
		_:
			_gable(b, r, eave, rise / (0.75 * half / M), false, tp, detail)
			at += Vector3(chim * (w / 2.0 - 0.9), 0, 0)
	var ridge := eave + rise
	_chimney(b, at + Vector3(0, ridge - rise / half * reach - 0.06, 0))
	return ridge


## Каркас дома — одна коробка r0 на все облики класса: до двух этажей во всю глубину, у трёхэтажного третий —
## в глубине, впереди терраса (как в Town to City); крыша. p: g / u / t — пролёты фасада первого, второго этажа
## и комнаты на крыше; roof / troof — вид крыши дома и комнаты; chim — труба вдоль конька; rise — подъём конька;
## medal — медальон во фронтоне; dress — обставить террасу. Бока и зад у всех одинаковые (_bk); на верхних этажах
## на каждой боковой стене окошки под карнизом в передней половине (у края ряда высокий узкий дом не стоит глухой
## плитой), внизу бока глухие. У трёхэтажного — без цоколя сзади (бережём детали).
## Случайность по этажам — из своих потоков (_begin); по выходе снова поток «g». Возвращает {r0, rb, rf, cor, shut, ridge}
static func _frame(b: Bp, r0: PackedFloat32Array, floors: int, p: Dictionary) -> Dictionary:
	var cor := _cor(b)
	if String(_st.get("cls", "")) == "patrician":
		cor = "SM_Bld_Trim_04"           # у домуса — самый богатый карниз (у узкого фасада всего два пролёта)
	var shut := _shut(b)
	var full := mini(floors, 2)
	_st["floors"] = floors
	var g: Array = p["g"]
	for f in full:
		_use(b, "g" if f == 0 else "f1")
		_storey(b, r0, f, {0: g if f == 0 else p["u"], 1: [] if f == 0 else [W2, WALL], 2: _bk(b, r0, f, shut),
			3: [] if f == 0 else [WALL, W2]},
			{"cornice": cor if f == floors - 1 else TRIM_MID, "no_plinth": [2] if floors >= 3 else []})
	if g.has(SHOP):
		_dark_shops(b, r0, full * FL)
	else:
		_dark(b, r0, 0.0, full * FL)
	var o := {"r0": r0, "cor": cor, "shut": shut}
	var chim: float = p.get("chim", 0.5)
	var medal: bool = p.get("medal", false)
	if floors >= 3:
		_use(b, "f2")
		var rb := _setback(b, r0, 2, p["t"], cor, shut, [0, 1, 3], PackedFloat32Array(), p.get("dress", true))
		o["rb"] = rb
		o["rf"] = R(r0[0], r0[1], rb[3], r0[3])
		_use(b, "roof")
		o["ridge"] = _roof(b, rb, 3 * FL, p.get("troof", "gx"), RISE_TOP, chim, medal, false)
	else:
		_use(b, "roof")
		o["ridge"] = _roof(b, r0, floors * FL, p.get("roof", "gx"), p.get("rise", RISE), chim, medal)
	_use(b, "g")
	return o


## Пролёты с дверью di и окнами в остальных: [W1, D4] и т. п.
static func _bays(n: int, door_i: int, door: String, other := W1) -> Array:
	var a := []
	for i in n:
		a.append(door if i == door_i else other)
	return a


## Плющ на боковой стене (side 1 или 3) — целиком на стене, не свисает за угол
static func _side_ivy(b: Bp, r: PackedFloat32Array, side: int, y: float, s := 1.0) -> void:
	var n := _n(r, side) * M
	_ivy(b, r, side, b.rng.randf_range(1.25 * s, n - 1.25 * s), y, true, s)


## Терраса с перголой (виноград над скамьёй) над пролётом pi, в другом углу — горшок, на парапете — ковёр или плющ
static func _terrace_pergola(b: Bp, o: Dictionary, pi: int) -> void:
	var rf: PackedFloat32Array = o["rf"]
	var y := 2 * FL + 0.07
	var n := _n(rf, 0)
	_pergola(b, rf[0] + pi * M, rf[2], y, true, false, 0.3 if pi == 0 else (-0.3 if pi == n - 1 else 0.0))
	var other := n - 1 if pi == 0 else 0
	_pot(b, Vector3(rf[0] + other * M + 1.25, y, rf[3] - 0.5), 0.55)
	if b.chance(0.6):
		_on(b, "SM_Prop_Rug_Drape_01", rf, 0, other * M + 1.25, 2 * FL + 1.0, 0.0, 0.8, false, PI)
	else:
		_ivy_drape(b, rf, 0, other * M + 1.25, 2 * FL + 1.0)


# =====================================================================================
#                                     дома плебеев
# =====================================================================================

## Дом плебеев: у всех пяти обликов одна коробка 2×2 пролёта (после сжатия 4×5 м), фасад на одной линии; второй
## этаж во всю глубину, третий — в глубине с террасой впереди. Разное — фасад, отделка, вид крыши (конёк на одной высоте)
static func _house_pleb(b: Bp, floors: int, v: int) -> void:
	floors = clampi(floors, 1, 3)
	_begin(b, "pleb", v % 5)
	var r0 := R(-2.5, 2.5, -2.5, 2.5)
	var di := b.rng.randi() % 2          # пролёт двери
	# у облика: сначала всё у земли (поток «g»), потом этажи выше (свои потоки)
	match v % 5:
		0: _pleb_shutters(b, r0, floors, di)
		1: _pleb_balcony(b, r0, floors, di)
		2: _pleb_pediment(b, r0, floors, di)
		3: _pleb_brick(b, r0, floors, di)
		_: _pleb_awning(b, r0, floors, di)
	_use(b, "g")
	_back_prop(b, r0)
	_narrow(b)


## Край пролёта двери у угла дома (u вдоль фасада): там горшки, фонарь, кувшин
static func _outer(di: int, n: int, k := 0.25) -> float:
	if n > 1 and di == n - 1:
		return n * M - k
	return di * M + k


## 0 «Ставни»: дверь под табличкой, окна со ставнями и ящиками цветов, фонарь на простенке; шатровая крыша
static func _pleb_shutters(b: Bp, r0: PackedFloat32Array, floors: int, di: int) -> void:
	var wi := 1 - di
	var o := _frame(b, r0, floors, {"g": _bays(2, di, D4), "u": [W1, W1], "t": _bays(2, wi, D4), "roof": "hip", "troof": "hip",
		"chim": 1.0 if di == 0 else -1.0})
	var shut: String = o["shut"]
	_door(b, r0, 0, di, _leaf(b))
	_step(b, r0, 0, di)
	_win(b, r0, 0, wi, 0, shut)
	_lamp(b, r0, 0, M, 2.25)
	_plaque(b, r0, 0, di * M + 1.25, 2.12)
	_hang_pots(b, r0, 0, _outer(di, 2, 0.22), 2.55)
	_front_pot(b, r0, _outer(di, 2, 0.32), 0.5)
	_side_ivy(b, r0, 3 if di == 0 else 1, 1.5)
	if floors >= 2:
		_use(b, "f1")
		for i in 2:
			_win(b, r0, 0, i, 1, shut)
		_hang_pots(b, r0, 0, M, FL + 2.5)


## 1 «Балкон»: над дверью деревянный висячий балкон с ковром, у окна скамья и горшок; двускатная крыша,
## на террасе — пергола с виноградом
static func _pleb_balcony(b: Bp, r0: PackedFloat32Array, floors: int, di: int) -> void:
	var wi := 1 - di
	var o := _frame(b, r0, floors, {"g": _bays(2, di, D4), "u": _bays(2, di, D4), "t": _bays(2, di, D4), "roof": "gx", "troof": "gx",
		"chim": 0.55 if di == 0 else -0.55, "dress": false})
	var shut: String = o["shut"]
	_door(b, r0, 0, di, _leaf(b))
	_step(b, r0, 0, di)
	if floors == 1:
		_on(b, "SM_Prop_Overhang_02", r0, 0, di * M + 1.25, 2.55, 0.1)       # козырёк (выше — балкон)
	_win(b, r0, 0, wi, 0, shut, false)
	_street_bench(b, r0, wi)
	_lamp(b, r0, 0, _outer(di, 2, 0.2), 2.2)
	_front_jar(b, r0, _outer(di, 2, 0.32), 0.7)
	_side_ivy(b, r0, 1 if di == 0 else 3, 1.6)
	if floors >= 2:
		_use(b, "f1")
		_balcony(b, r0, 0, di, 1)
		_door2(b, r0, 0, di, 1)
		_win(b, r0, 0, wi, 1, shut)
	if floors >= 3:
		_use(b, "f2")
		_terrace_pergola(b, o, wi)


## 2 «Фронтон»: дом фронтоном к улице с медальоном, над окном расписной фриз; на втором этаже балкончик над дверью
static func _pleb_pediment(b: Bp, r0: PackedFloat32Array, floors: int, di: int) -> void:
	var wi := 1 - di
	var g := _bays(2, di, D4)
	var o := _frame(b, r0, floors, {"g": g, "u": _bays(2, di, D4), "t": _bays(2, di, D4), "roof": "gz", "troof": "gz",
		"chim": -0.6, "medal": true})
	var shut: String = o["shut"]
	_door(b, r0, 0, di, _leaf(b))
	_step(b, r0, 0, di)
	_win(b, r0, 0, wi, 0, shut)
	_frieze(b, r0, 0, 0, g)
	_lamp(b, r0, 0, _outer(di, 2, 0.2), 2.2)
	_front_jar(b, r0, _outer(di, 2, 0.32), 0.75)
	_front_pot(b, r0, wi * M + (0.3 if wi == 0 else 2.2), 0.42)
	_side_ivy(b, r0, 1 if di == 1 else 3, 1.4)
	if floors >= 2:
		_use(b, "f1")
		_jbal(b, r0, 0, di, 1)
		_door2(b, r0, 0, di, 1)
		_win(b, r0, 0, wi, 1, shut)


## 3 «Кирпич»: нижний этаж кирпичный, у входа плющ и амфоры, окна со ставнями; двускатная крыша
static func _pleb_brick(b: Bp, r0: PackedFloat32Array, floors: int, di: int) -> void:
	var wi := 1 - di
	b.ground_style = "brick"
	var o := _frame(b, r0, floors, {"g": _bays(2, di, D4), "u": [W1, W1], "t": _bays(2, wi, D4), "roof": "gx", "troof": "hip",
		"chim": -0.55 if di == 0 else 0.55})
	var shut: String = o["shut"]
	_door(b, r0, 0, di, _leaf(b))
	_step(b, r0, 0, di)
	_win(b, r0, 0, wi, 0, shut)
	_ivy(b, r0, 3 if di == 0 else 1, 3.6 if di == 0 else 1.4, 1.8, true, 0.9)
	_front_jar(b, r0, _outer(di, 2, 0.27), 0.7)
	_front_jar(b, r0, M + (0.2 if di == 1 else -0.2), 0.55)      # на простенке между ступенькой и окном
	_lamp(b, r0, 0, M, 2.25)
	_plaque(b, r0, 0, di * M + 1.25, 2.12)
	if floors >= 2:
		_use(b, "f1")
		_win(b, r0, 0, di, 1, shut, false)
		_hang_pots(b, r0, 0, di * M + 1.25, FL + 0.9)
		_win(b, r0, 0, wi, 1, shut)


## 4 «Навес»: над окном черепичный навес, под ним скамья и амфора; на втором этаже балкончик над дверью;
## шатровая крыша
static func _pleb_awning(b: Bp, r0: PackedFloat32Array, floors: int, di: int) -> void:
	var wi := 1 - di
	var o := _frame(b, r0, floors, {"g": _bays(2, di, D4), "u": _bays(2, di, D4), "t": _bays(2, wi, D4), "roof": "hip", "troof": "gx",
		"chim": -1.0 if di == 0 else 1.0})
	var shut: String = o["shut"]
	_door(b, r0, 0, di, _leaf(b))
	_step(b, r0, 0, di)
	_win(b, r0, 0, wi, 0, shut, false)
	_on(b, "SM_Prop_Overhang_01", r0, 0, wi * M + 1.25, 2.72, 0.12)
	_street_bench(b, r0, wi)
	_plaque(b, r0, 0, di * M + 1.25, 2.12)
	_lamp(b, r0, 0, _outer(di, 2, 0.2), 2.2)
	_front_jar(b, r0, _outer(di, 2, 0.32), 0.7)
	_side_ivy(b, r0, 3 if di == 0 else 1, 1.5)
	if floors >= 2:
		_use(b, "f1")
		_jbal(b, r0, 0, di, 1)
		_door2(b, r0, 0, di, 1)
		_win(b, r0, 0, wi, 1, shut)


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
## (kind: 0 — ткач, 1 — гончар, 2 — кузнец/медник, 3 — зерно и мешки)
## aw — ширина навеса (у двух лавок рядом навесы чуть уже, чтобы не сходились на общем простенке);
## ban — вывеска с правого (1) или левого (0) края проёма, −1 — наугад; ban_p — вероятность вывески
static func _shopfront(b: Bp, r: PackedFloat32Array, i: int, kind: int, awning := true, ban := -1, aw := 1.0, ban_p := 0.6) -> void:
	if awning:
		var a := _sp(r, 0, i * M + 1.25, 2.78, 0.12)
		_put(b, "SM_Prop_Overhang_01", a[0], a[1], Vector3(aw, 1, 1))
	_shop_inside(b, r, i, mini(kind, 2))
	var sl := b.chance(0.5) if ban < 0 else ban == 1     # вывеска справа (товар у стены — слева)
	var su := i * M + (0.45 if sl else 2.05)      # у узкого дома — не за угол
	if kind == 3:
		# зерно: мешки горкой на пороге, амфора у стены
		_put(b, "SM_Prop_Sack_Stack_0%d" % (1 + b.rng.randi() % 2), Vector3(r[0] + i * M + 1.25, 0, r[3] - 0.3), b.rng.randf_range(-0.08, 0.08), Vector3.ONE * 0.72)
		_front_put(b, b.pick(["SM_Prop_Vase_02", "SM_Prop_Vase_05", "SM_Prop_Jar_01"]), r, su, 0.0, 0.7)
		return
	var c := _sp(r, 0, i * M + 1.25, 0.0, -0.2)
	var p: Vector3 = c[0]
	_put(b, "SM_Prop_Table_01", p, 0.0, Vector3(0.78, 1, 0.7))
	var top := p + Vector3(0, 0.78, 0)
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
	if b.chance(ban_p):
		_on(b, "SM_Prop_Banner_0%d_%s" % [1 + b.rng.randi() % 2, b.pick(["A", "B", "C", "D", "E", "F"])], r, 0, i * M + (2.48 if sl else 0.02), 2.62, 0.12, 0.45)


## Дом ремесленников: у всех пяти обликов одна коробка 2×2 пролёта, как у плебеев (после сжатия 4×5 м): внизу лавка
## под навесом и дверь в каменном наличнике, наверху жильё; второй этаж во всю глубину, третий — в глубине с террасой
## впереди. За домом у всех один двор-мастерская под навесом (_art_yard) — дом глубже, чем у плебеев
const ART_CRAFT := [0, 3, 2, 1, 2]       # ремесло облика: 0 ткач, 1 гончар, 2 кузнец/медник, 3 зерно
static func _house_artisan(b: Bp, floors: int, v: int) -> void:
	floors = clampi(floors, 1, 3)
	_begin(b, "artisan", v % 5)
	var r0 := R(-2.5, 2.5, -2.5, 2.5)
	var craft: int = ART_CRAFT[v % 5]
	var si := b.rng.randi() % 2          # пролёт лавки (дверь — в другом)
	# у облика: сначала всё у земли (поток «g»), потом этажи выше (свои потоки)
	match v % 5:
		0: _art_balcony(b, r0, floors, craft, si)
		1: _art_workshop(b, r0, floors, craft, si)
		2: _art_pediment(b, r0, floors, craft, si)
		3: _art_brick(b, r0, floors, craft, si)
		_: _art_balconies(b, r0, floors, craft, si)
	_use(b, "g")
	_art_yard(b, r0, craft)
	_narrow(b)


## Лавка в пролёте si: навес, прилавок с товаром, вывеска — у простенка с дверью (не свешивается за угол дома)
static func _art_shop(b: Bp, r0: PackedFloat32Array, si: int, craft: int, ban_p := 0.6) -> void:
	_shopfront(b, r0, si, craft, true, 1 if si == 0 else 0, 1.0, ban_p)


## Двор-мастерская за домом ремесленника — у всех обликов один и тот же: черепичный навес скатом назад на двух
## деревянных столбах вдоль задней стены, под ним снасть ремесла (у задней двери проход свободен)
const YARD := 1.9
static func _art_yard(b: Bp, r0: PackedFloat32Array, craft: int) -> void:
	var z1 := r0[2]
	var z0 := z1 - YARD
	for x: float in [r0[0] + 0.3, r0[1] - 0.3]:
		_put(b, "SM_Bld_Trellis_Pillar_01", Vector3(x, 0, z0 + 0.3), 0.0, Vector3.ONE * 0.72)
	b.remap = b.floor_remap(1)
	_lean(b, R(r0[0], r0[1], z0, z1), 2.15, 0.9, 2)
	# задняя дверь — в пролёте у −X (_bk), снасть — у +X
	var p := Vector3(r0[1] - 1.2, 0, z1 - 0.85)
	match craft:
		0:
			_put(b, "SM_Prop_Loom_01", p, PI + 0.15, Vector3.ONE * 0.75)
			_put(b, "SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 5), p + Vector3(-1.05, 0, 0.35), b.rng.randf() * TAU, Vector3.ONE * 0.7)
		1:
			_put(b, "SM_Prop_Kiln_01", p + Vector3(0.1, 0, -0.1), PI, Vector3.ONE * 0.5)
			_put(b, "SM_Prop_Vase_Pile_0%d" % (1 + b.rng.randi() % 6), p + Vector3(-1.2, 0, 0.2), 0.0, Vector3.ONE * 0.6)
		2:
			_put(b, "SM_Prop_Anvil_01", p + Vector3(0.2, 0, 0.1), 0.4, Vector3.ONE * 0.8)
			_put(b, "SM_Prop_Grinding_Wheel_01", p + Vector3(-0.9, 0.3, -0.1), 1.2, Vector3.ONE * 0.8)
		_:
			_put(b, "SM_Prop_Sack_Stack_0%d" % (1 + b.rng.randi() % 2), p, b.rng.randf_range(-0.2, 0.2), Vector3.ONE * 0.7)
			_put(b, "SM_Prop_Jar_01", p + Vector3(-1.05, 0, 0.3), 0.0, Vector3.ONE * 0.75)


## 0 «Балкон»: лавка под черепичным навесом, рядом дверь в каменном наличнике; над дверью деревянный висячий
## балкон, над лавкой окно со ставнями и цветами; вальмовая крыша
static func _art_balcony(b: Bp, r0: PackedFloat32Array, floors: int, craft: int, si: int) -> void:
	var di := 1 - si
	var o := _frame(b, r0, floors, {"g": _bays(2, di, D3, SHOP), "u": _bays(2, di, D4), "t": _bays(2, si, D4), "roof": "hip", "troof": "hip",
		"chim": 1.0 if di == 0 else -1.0})
	var shut: String = o["shut"]
	_door(b, r0, 0, di, _leaf(b))
	_step(b, r0, 0, di)
	_art_shop(b, r0, si, craft)
	_lamp(b, r0, 0, _outer(di, 2, 0.2), 2.2)
	_side_ivy(b, r0, 3 if di == 0 else 1, 1.5)
	if floors >= 2:
		_use(b, "f1")
		_balcony(b, r0, 0, di, 1)
		_door2(b, r0, 0, di, 1)
		_win(b, r0, 0, si, 1, shut)


## 1 «Мастерская»: лавка под навесом, наверху два окна со ставнями и вывеска-полотнище между ними;
## двускатная крыша, на террасе пергола с виноградом
static func _art_workshop(b: Bp, r0: PackedFloat32Array, floors: int, craft: int, si: int) -> void:
	var di := 1 - si
	var o := _frame(b, r0, floors, {"g": _bays(2, di, D3, SHOP), "u": [W1, W1], "t": _bays(2, di, D4), "roof": "gx", "troof": "hip",
		"chim": 0.55 if di == 0 else -0.55, "dress": false})
	var shut: String = o["shut"]
	_door(b, r0, 0, di, _leaf(b))
	_step(b, r0, 0, di)
	_art_shop(b, r0, si, craft, 0.0)
	_front_pot(b, r0, _outer(di, 2, 0.36), 0.5)
	_lamp(b, r0, 0, _outer(di, 2, 0.2), 2.2)
	if floors >= 2:
		_use(b, "f1")
		_win(b, r0, 0, 0, 1, shut)
		_win(b, r0, 0, 1, 1, shut)
		# вывеска мастерской между окнами (над ставнями)
		_on(b, "SM_Prop_Banner_0%d_%s" % [1 + b.rng.randi() % 2, b.pick(["A", "B", "C", "D", "E", "F"])], r0, 0, M, FL + 2.66, 0.12, 0.5)
	if floors >= 3:
		_use(b, "f2")
		_terrace_pergola(b, o, si)


## 2 «Фронтон»: лавка, дверь; наверху окна с фронтончиками и ящиками цветов, между ними висячие цветы;
## фронтон к улице с медальоном
static func _art_pediment(b: Bp, r0: PackedFloat32Array, floors: int, craft: int, si: int) -> void:
	var di := 1 - si
	var o := _frame(b, r0, floors, {"g": _bays(2, di, D3, SHOP), "u": [W5, W5], "t": _bays(2, di, D4), "roof": "gz", "troof": "gz",
		"chim": -0.6, "medal": true})
	_door(b, r0, 0, di, _leaf(b))
	_step(b, r0, 0, di)
	_art_shop(b, r0, si, craft)
	_front_jar(b, r0, _outer(di, 2, 0.36), 0.7)
	_lamp(b, r0, 0, _outer(di, 2, 0.2), 2.2)
	_side_ivy(b, r0, b.pick([1, 3]), 1.6)
	if floors >= 2:
		_use(b, "f1")
		for i in 2:
			_wbox(b, r0, 0, i, FL)
		_hang_pots(b, r0, 0, M, FL + 2.5)


## 3 «Кирпич»: кирпичный низ, лавка, дверь; наверху балкончик с решёткой над дверью и окно со ставнями;
## двускатная крыша
static func _art_brick(b: Bp, r0: PackedFloat32Array, floors: int, craft: int, si: int) -> void:
	var di := 1 - si
	b.ground_style = "brick"
	_st["jrail"] = "bars"            # каменный балкончик на узком фасаде читался глухим ящиком
	var o := _frame(b, r0, floors, {"g": _bays(2, di, D3, SHOP), "u": _bays(2, di, D4), "t": _bays(2, si, D4), "roof": "gx", "troof": "hip",
		"chim": -0.55 if di == 0 else 0.55})
	var shut: String = o["shut"]
	_door(b, r0, 0, di, _leaf(b))
	_step(b, r0, 0, di)
	_art_shop(b, r0, si, craft)
	_front_jar(b, r0, _outer(di, 2, 0.34), 0.65)
	_lamp(b, r0, 0, _outer(di, 2, 0.2), 2.2)
	_side_ivy(b, r0, 3 if di == 0 else 1, 1.6, 0.9)
	if floors >= 2:
		_use(b, "f1")
		_jbal(b, r0, 0, di, 1)
		_door2(b, r0, 0, di, 1)
		_win(b, r0, 0, si, 1, shut)


## 4 «Балкончик»: лавка, дверь, горшок у входа; наверху балкончик с решёткой над лавкой, окно со ставнями
## и расписной фриз; вальмовая крыша
static func _art_balconies(b: Bp, r0: PackedFloat32Array, floors: int, craft: int, si: int) -> void:
	var di := 1 - si
	_st["jrail"] = "bars"
	var u := _bays(2, si, D4)
	var o := _frame(b, r0, floors, {"g": _bays(2, di, D3, SHOP), "u": u, "t": _bays(2, di, D4), "roof": "hip", "troof": "gx",
		"chim": 1.0 if di == 0 else -1.0})
	var shut: String = o["shut"]
	_door(b, r0, 0, di, _leaf(b))
	_step(b, r0, 0, di)
	_art_shop(b, r0, si, craft)
	_lamp(b, r0, 0, _outer(di, 2, 0.2), 2.2)
	_front_pot(b, r0, _outer(di, 2, 0.36), 0.5)
	if floors >= 2:
		_use(b, "f1")
		_jbal(b, r0, 0, si, 1)
		_door2(b, r0, 0, si, 1)
		_win(b, r0, 0, di, 1, shut)
		_frieze(b, r0, 0, 1, u)


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


## Плющ на колонне протирона (низ колонны p): листва чуть уже и повёрнута пышной стороной к дому,
## чтобы не выходить за линию фасада front (на мостовую)
static func _pillar_ivy(b: Bp, p: Vector3, front: float) -> void:
	var nm := "SM_Env_Ivy_Pillar_Flowers_0%d" % (1 + b.rng.randi() % 2)
	var box := Bp.model_aabb(nm)
	var best := 0.0
	var bz := INF
	for k in 8:
		var bs := Basis(Vector3.UP, k * TAU / 8.0).scaled(Vector3(0.85, 0.97, 0.85))
		var mz := -INF
		for e in 8:
			mz = maxf(mz, (bs * box.get_endpoint(e)).z)
		if mz < bz - 0.001:
			bz = mz
			best = k * TAU / 8.0
	var bs := Basis(Vector3.UP, best).scaled(Vector3(0.85, 0.97, 0.85))
	var z := minf(p.z, front - 0.02 - bz)
	b.add_xf(nm, Transform3D(bs, Vector3(p.x, p.y, z)))


## Портик домуса во всю ширину фасада — главный знак богатого дома: мраморный пол-стилобат со ступенью к улице
## (_podium), на нём три небольшие мраморные колонны (по углам и посередине: дверь и окно — каждое в своём пролёте
## между колоннами), на крайних — фонари. Вид крыши портика: "ped" — черепичный фронтон к улице с золотым навершием
## и мраморным медальоном, "lean" — черепичный навес скатом к улице на мраморном архитраве, "flat" — лоджия-терраса
## с каменной балюстрадой и статуями по углам. Колонны у всех обликов на одних местах: портик задаёт линию фасада
## (дом стоит за ним в глубине)
const PORCH := 1.1
const PCOL := [-2.2, 0.0, 2.2]       # колонны до сжатия (после — ±1,65 м и середина)
const PH := 0.125                    # верх мраморного пола портика (вещи под портиком стоят на нём)
const MARBLE_FLOOR := {"Stone_01": "Building_Marble_01"}
static func _portico(b: Bp, rm: PackedFloat32Array, style: String) -> void:
	var z0 := rm[3]
	var pz := z0 + PORCH - 0.2
	var top := FL - 0.12
	var ly := _lamp_y(2.15)
	_podium(b, rm)
	for x: float in PCOL:
		_put(b, "SM_Bld_Pillar_06", Vector3(x, PH, pz), 0.0, Vector3(0.75, (2.91 - PH) / 3.0, 0.75))
	for x: float in [PCOL[0], PCOL[2]]:
		_put(b, "#wall_lamp", Vector3(x, ly, pz + 0.18), 0.0, Vector3.ONE * 0.8)
	b.light(Vector3(0, ly - 0.2, pz + 0.55))
	var rp := R(rm[0], rm[1], z0 - 0.05, z0 + PORCH + 0.12)
	match style:
		"ped":
			_gable(b, rp, top, 1.0, true, "SM_Bld_Roof_Topper_06", false, false)
			_medallion(b, rp, 0, (rm[1] - rm[0]) / 2.0, top + 0.27, true)
		"lean":
			b.remap = b.floor_remap(1)
			_lean(b, rp, top, 0.95, 0)
			# мраморный архитрав по верху колонн (богатый карниз, как под крышей дома) — навес не «плебейский»
			for i in 2:
				_put(b, "SM_Bld_Trim_04", Vector3(rm[0] + i * M, top - 0.3, pz + 0.09), 0.0)
		_:
			# лоджия: плита с каменной балюстрадой спереди и по бокам, статуи на углах, горшок с цветами
			var rr: Dictionary = b.remap.duplicate()
			var d := rp[3] - rp[2]
			_put(b, "SM_Bld_Roof_Base_Flat_02", Vector3(rp[0], top - 0.68, rp[3]), 0.0, Vector3(2.0, 1, d / M), rr)
			for i in 2:
				var rail := _sp(rp, 0, i * M, top, -0.25)
				_put(b, "SM_Bld_Wall_Balcony_06", rail[0], rail[1], Vector3(1.0, 0.85, 1.0), b.remap.duplicate())
			for side: int in [1, 3]:
				var a := _sp(rp, side, 0.0 if side == 1 else 0.05, top, -0.25)
				_put(b, "SM_Bld_Wall_Balcony_06", a[0], a[1], Vector3((d - 0.05) / M, 0.85, 1.0), b.remap.duplicate())
			for x: float in [PCOL[0], PCOL[2]]:
				_put(b, "SM_Prop_Statue_0%d" % b.pick([3, 5, 6]), Vector3(x, top + 0.87, z0 + 0.9), (0.3 if x < 0 else -0.3), Vector3.ONE * 0.34)
			_pot(b, Vector3(0, top, z0 + 0.45), 0.5)


## Мраморный пол портика (плита толщиной PH от стены до колонн) и каменная ступень во всю ширину по его краю:
## верхняя полка ступени — под колоннами, нижняя чуть выходит на мостовую (как ступенька у дверей плебеев)
static func _podium(b: Bp, rm: PackedFloat32Array) -> void:
	var z0 := rm[3]
	var w := (rm[1] - rm[0]) / M
	var zs := z0 + PORCH - 0.165             # начало ступени: верхняя полка доходит до передней кромки колонн
	_put(b, "SM_Bld_Base_Floor_Combined_01", Vector3(rm[0], PH - 0.01, z0 - 0.05), 0.0,
		Vector3(w, 1.25, (zs + 0.06 - z0 + 0.05) / M), MARBLE_FLOOR)
	_put(b, "SM_Bld_Floor_Trim_01", Vector3(rm[0], 0.0, zs), 0.0, Vector3(w, 1.0, 0.45))


## Золотая жаровня-чаша на точёной ножке (как у станции); s — масштаб (0,34 — чаша чуть ниже пояса прохожему).
## В углях — три уголька #ember: днём тёмные, в сумерках разгораются вместе с фонарями (сами угли Synty не светятся)
static func _gold_brazier(b: Bp, p: Vector3, s := 0.34) -> void:
	_put(b, "SM_Prop_Brazier_01", p, 0.0, Vector3.ONE * s)
	_put(b, "SM_Prop_Brazier_01_Insert_01", p, 0.0, Vector3.ONE * s)
	var a := 0.6 + p.x * 2.3          # без случайности: поток «g» у дома одинаков на всех этажностях
	for k in 3:
		var off: Vector2 = [Vector2(0.05, 0.0), Vector2(0.3, 0.14), Vector2(-0.22, -0.24)][k]
		var e: float = [0.3, 0.22, 0.2][k] * s
		var q := p + Vector3(off.x * s, 1.9 * s, off.y * s)       # утоплены в угли: видны только верхушки
		b.parts.append(["#ember", b.base * Transform3D(Basis(Vector3.UP, a + k * 0.7).scaled(Vector3.ONE * e), q), {}])
	b.light(p + Vector3(0, 2.0 * s + 0.3, 0))


## Парадный вход домуса: двустворчатая дверь во весь проём в пролёте pd и портик; сюда входят жители
static func _pat_entry(b: Bp, rm: PackedFloat32Array, pd: int, style: String) -> void:
	_grand_door(b, rm, pd)
	_portico(b, rm, style)
	b.door = b.base * Vector3(rm[0] + pd * M + 1.25, 0, rm[3] + PORCH + 0.45)


## Точка на фасаде домуса у земли: пролёт wi, u метров от его левого края (до сжатия)
static func _wx(rm: PackedFloat32Array, wi: int, u: float) -> float:
	return rm[0] + wi * M + u


## У дальнего угла пролёта окна wi (рядом с угловой колонной портика), до сжатия
static func _wcorner(rm: PackedFloat32Array, wi: int, k := 0.55) -> float:
	return _wx(rm, wi, k if wi == 0 else M - k)


## На мостовой перед портиком — по паре по сторонам двери (у средней колонны и у крайней, чаша не выходит за угол
## дома): золотые жаровни-чаши (у двухэтажного) или горшки с цветами. Перед нижней полкой ступени портика
const BRAZ := 0.34                   # жаровня у входа: чаша чуть ниже пояса прохожему, мостовую не загромождает
static func _pat_flank(b: Bp, rm: PackedFloat32Array, floors: int, pd: int) -> void:
	var rf := R(rm[0], rm[1], rm[2], rm[3] + PORCH)
	for x: float in [PCOL[1], -2.0 if pd == 0 else 2.0]:
		var u := x - rm[0]
		if floors >= 2:
			# задней кромкой чаши — в CLEAR + 0,08 от линии портика (за нижней полкой ступени), как _front_put
			_gold_brazier(b, Vector3(x, 0, rf[3] + CLEAR + 0.08 - Bp.model_aabb("SM_Prop_Brazier_01").position.z * BRAZ), BRAZ)
		else:
			_front_put(b, "SM_Prop_FlowerPot_Fancy_01", rf, u, 0.57 * 0.5, 0.5, 0.0, 0.08)


## Домус патрициев: та же ширина, что у домов плебеев и ремесленников (два пролёта), но дом стоит в глубине за
## портиком с колоннами во всю ширину, а за домом сад за стенами; 1–2 этажа. У всех четырёх обликов одна коробка,
## портик одной глубины с колоннами на одних местах и одинаковый сад. Разное — крыша портика, окна, балконы,
## вид крыши, убранство у фасада и середина сада
static func _house_patrician(b: Bp, floors: int, v: int) -> void:
	floors = clampi(floors, 1, 2)
	_begin(b, "patrician", v % 4)
	var rm := R(-2.5, 2.5, -1.0, 4.0)
	var pd := b.rng.randi() % 2           # пролёт парадной двери, в другом — окно
	# у облика: сначала всё у земли (поток «g»), потом второй этаж (поток «f1»)
	match v % 4:
		0: _pat_peristyle(b, rm, floors, pd)
		1: _pat_loggia(b, rm, floors, pd)
		2: _pat_temple(b, rm, floors, pd)
		_: _pat_arcade(b, rm, floors, pd)
	_use(b, "g")
	_door2(b, rm, 2, 0, 0)                    # дверь в сад (проём и ступень — в _bk)
	_pat_garden(b, rm, v % 4, floors)
	_narrow(b)


## 0 «Перистиль»: портик под фронтоном с медальоном; внизу окно с фронтончиком и цветами, у угла под портиком
## золотая жаровня; по сторонам двери на мостовой — жаровни или горшки; наверху окна с фронтончиками и крашеными
## ставнями (ящики цветов над фронтоном портика теснились с его навершием); двускатная крыша
static func _pat_peristyle(b: Bp, rm: PackedFloat32Array, floors: int, pd: int) -> void:
	var wi := 1 - pd
	var o := _frame(b, rm, floors, {"g": _bays(2, pd, DOUBLE, W5), "u": [W5, W5], "roof": "gx", "rise": RISE_PAT,
		"chim": b.pick([-0.45, 0.45])})
	_wbox(b, rm, 0, wi, 0.0)
	_pat_entry(b, rm, pd, "ped")
	_gold_brazier(b, Vector3(_wcorner(rm, wi, 0.42), PH, rm[3] + 0.38), 0.32)
	_pat_flank(b, rm, floors, pd)
	_side_ivy(b, rm, 3 if wi == 0 else 1, 1.5)
	if floors >= 2:
		_use(b, "f1")
		_win(b, rm, 0, wi, 1, o["shut"], false)
		_win(b, rm, 0, pd, 1, o["shut"], false)


## 1 «Лоджия»: портик-лоджия с балюстрадой и статуями по углам, наверху на неё выходит дверь; внизу окно
## с фронтончиком и цветами, под портиком статуя на постаменте; вальмовая крыша
static func _pat_loggia(b: Bp, rm: PackedFloat32Array, floors: int, pd: int) -> void:
	var wi := 1 - pd
	_frame(b, rm, floors, {"g": _bays(2, pd, DOUBLE, W5), "u": _bays(2, wi, D4, W5), "roof": "hip", "rise": RISE_PAT,
		"chim": 0.6 if wi == 0 else -0.6})
	_wbox(b, rm, 0, wi, 0.0)
	_pat_entry(b, rm, pd, "flat")
	_statue(b, Vector3(_wcorner(rm, wi, 0.45), PH, rm[3] + 0.42), (0.35 if wi == 0 else -0.35), 0.5)
	_pat_flank(b, rm, floors, pd)
	_side_ivy(b, rm, 3 if wi == 0 else 1, 1.5)
	if floors >= 2:
		_use(b, "f1")
		_door2(b, rm, 0, wi, 1)
		_wbox(b, rm, 0, pd, FL)


## 2 «Храм»: портик под фронтоном и сам дом фронтоном к улице с медальоном (как храм); внизу окно с фронтончиком,
## под портиком ваза на постаменте; наверху окна со ставнями (без ящиков цветов — над фронтоном портика тесно)
## и расписной фриз
static func _pat_temple(b: Bp, rm: PackedFloat32Array, floors: int, pd: int) -> void:
	var wi := 1 - pd
	var u := [W1, W1]
	var o := _frame(b, rm, floors, {"g": _bays(2, pd, DOUBLE, W5), "u": u, "roof": "gz", "rise": RISE_PAT, "chim": -0.5, "medal": true})
	var shut: String = o["shut"]
	_wbox(b, rm, 0, wi, 0.0)
	_pat_entry(b, rm, pd, "ped")
	var vx := _wcorner(rm, wi, 0.5)
	_put(b, "SM_Prop_Pillar_Base_01", Vector3(vx, PH, rm[3] + 0.42), 0.0, Vector3(0.42, 1.0, 0.42))
	_put(b, "SM_Prop_Vase_0%d" % b.pick([1, 3, 5]), Vector3(vx, PH + 1.0, rm[3] + 0.42), 0.0, Vector3.ONE * 0.5)
	_pat_flank(b, rm, floors, pd)
	_side_ivy(b, rm, b.pick([1, 3]), 1.6)
	if floors >= 2:
		_use(b, "f1")
		_win(b, rm, 0, wi, 1, shut, false)
		_win(b, rm, 0, pd, 1, shut, false)
		_frieze(b, rm, 0, 1, u)


## 3 «Аркада»: портик под черепичным навесом на мраморном архитраве, плющ на колонне; внизу окно с фронтончиком
## и цветами (вещи в углу портика с улицы всё равно закрывает колонна); наверху окна со ставнями и цветами;
## вальмовая крыша
static func _pat_arcade(b: Bp, rm: PackedFloat32Array, floors: int, pd: int) -> void:
	var wi := 1 - pd
	var o := _frame(b, rm, floors, {"g": _bays(2, pd, DOUBLE, W5), "u": [W1, W1], "roof": "hip", "rise": RISE_PAT,
		"chim": 0.6 if wi == 0 else -0.6})
	var shut: String = o["shut"]
	_wbox(b, rm, 0, wi, 0.0)
	_pat_entry(b, rm, pd, "lean")
	var cx: float = PCOL[0] if wi == 0 else PCOL[2]
	_pillar_ivy(b, Vector3(cx, PH, rm[3] + PORCH - 0.2), rm[3] + PORCH)
	_pat_flank(b, rm, floors, pd)
	if floors >= 2:
		_use(b, "f1")
		_win(b, rm, 0, wi, 1, shut)
		_win(b, rm, 0, pd, 1, shut)


## Сад за домусом — у всех обликов один участок 2 пролёта × 4 м (стены, кипарисы, клумба у окна; дверь в сад —
## у +X); разное — середина: фонтан, пергола, статуя или колодец. Место садовника (1,5; −4,2) до сжатия
## (после — (1,2; −4,2)) свободно
static func _pat_garden(b: Bp, rm: PackedFloat32Array, kind: int, floors := 1) -> void:
	var z0 := rm[2] - 0.05
	var zb := -5.0
	var xl := rm[0]
	var xr := rm[1]
	_lowwall(b, Vector3(xl, 0, z0), Vector3(xl, 0, zb), 1.1, false)
	_lowwall(b, Vector3(xl, 0, zb), Vector3(xr, 0, zb), 1.1, false)
	_lowwall(b, Vector3(xr, 0, zb), Vector3(xr, 0, z0), 1.1, false)
	var rw := R(xl, xr, zb, z0)
	_ivy(b, rw, 2, b.rng.randf_range(1.4, 3.6), 0.62, true, 0.6)
	# кипарис в дальнем углу выглядывает из-за крыши — с улицы видно, что за домом сад
	_cypress(b, Vector3(-2.0, 0, -4.45), 0.55 if floors < 2 else 0.85)
	_cypress(b, Vector3(-2.05, 0, -1.65), 0.36)
	_bed(b, Vector3(-0.95, 0, -1.75), 0.0, 0.7)
	match kind:
		0:
			_fountain(b, Vector3(-0.35, 0, -3.15), 0.42)
			_put(b, "SM_Prop_Seat_Kline_0%d" % (1 + b.rng.randi() % 3), Vector3(-0.7, 0, -4.5), 0.0, Vector3.ONE * 0.55)
		1:
			_pergola(b, -1.6, -4.9, 0.0, false, true, 0.0)
			_put(b, "SM_Prop_Seat_Kline_0%d" % (1 + b.rng.randi() % 3), Vector3(-0.35, 0, -3.75), 0.0, Vector3.ONE * 0.55)
			_pot(b, Vector3(1.4, 0, -2.6), 0.5)
		2:
			_statue(b, Vector3(-0.4, 0, -3.2), 0.0, 0.65)
			_cypress(b, Vector3(0.4, 0, -4.45), 0.3)
			_bench(b, Vector3(-2.0, 0, -3.1), PI / 2)
		_:
			_put(b, "SM_Prop_Well_01", Vector3(-0.5, 0, -3.2), b.rng.randf() * TAU, Vector3.ONE * 0.45)
			_jar(b, Vector3(-1.5, 0, -4.55), 0.7)
			_jar(b, Vector3(-1.05, 0, -4.6), 0.6)
