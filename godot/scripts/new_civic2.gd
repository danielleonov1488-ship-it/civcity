class_name NewCivic2
extends RefCounted
## Новые почтовая станция, бани, гостиница и дом префекта (владелец 13.11: «пересобрать модельки» — новые здания из
## деталей Synty POLYGON Ancient Empire, а не украшенные прежние; «темноты вообще не должно быть»; у каждого здания своё
## основание; про дом префекта, станцию и стражу — «стоят на голой земле с рваными тёмными краями»; размеры — по
## утверждённой линейке SizeLadder, мерка — дом плебеев 2,8 × 4 м). Собраны с нуля в метрах города (base делит на
## масштаб Catalog, тот потом умножает обратно), фасад к +Z, вход — b.door; образцы — NewTemple, NewCivic, NewGrand.
##  - почтовая станция («центр», ≈ 62 м², «большие», след прежний): охристый дом почты с мраморными пилястрами
##    и черепичной кровлей, слева — зал ожидания, справа — конюшня с арками и лошадью, перед ними — двор с повозкой,
##    доской объявлений, верстовым столбом и багажом. Растёт с уровнем города (CatCivic._center: tier): хутор — дом
##    в один этаж и навес-конюшня; дальше — второй этаж, портик, каменная конюшня, зал ожидания, белый портик
##    с фронтоном, колокольня, статуи и позолота. Кровля не выше 6,5 м (храм Юпитера, конёк 6,8 м, — главный);
##  - бани (≈ 68 м², «большие», было 73): зал с куполом на барабане и горячим бассейном за большой аркой, крылья
##    с малыми куполами, внизу помпейский красный, верх — белый мрамор; перед ними — двор с бассейном под открытым
##    небом (купальщики Spectacle), колоннады под черепицей, вход — пропилей с бронзовыми дверями (Life);
##  - гостиница (≈ 36 м², «средние», было 27): розовый двухэтажный дом с деревянным балконом в цветах и зелёными
##    ставнями (Life), за дверью — тёплая таверна; рядом — конюшня под навесом с лошадью, сеном и поилкой; во дворе —
##    повозка путников, багаж, стол под виноградной перголой, доска объявлений и вывеска;
##  - дом префекта (≈ 36 м², «средние», было 28): дом из кремового травертина в два этажа, портик в четыре колонны
##    с террасой наверху, фронтон с золотым рельефом, бронзовые двери (Life) в тёплые сени, фасции у дверей,
##    знамёна, ставни (Life), ниши со статуями сзади, плющ и цветы.
## У каждого — мощёный двор по всему следу с бордюром, уходящим в землю (Land под ним ничего не стелет:
## City.apron_of = 0); за каждой дверью и окном — освещённая комната или тёплое свечение (remap «glow»), закрытые
## ставни или открытый двор. Нет больших глухих стен ни с одной стороны: окна, пилястры, ниши со статуями, фризы,
## карнизы, плющ, знамёна. Старые сохранения (SizeLadder.old_lot, Catalog.fit): гостиница и дом префекта — под прежние
## клетки (City.ladder_grow выращивает их в полный размер, где есть место); бани — новые посреди прежнего следа,
## мостовая — по всему нему; станция — в прежнем следе. Прежние сборки остаются: ON — выключатели по типу (снимки
## «было/стало»); CIVCITY_NEWCIV2=0 — прежние во всей игре (=baths,mansio — новые только эти).

static var ON := _on_from_env()
const TYPES := ["center", "baths", "mansio", "prefect"]


## CIVCITY_NEWCIV2: не задан — все новые; «0» — все прежние; список через запятую — новые только эти (сравнения)
static func _on_from_env() -> Dictionary:
	var e := OS.get_environment("CIVCITY_NEWCIV2")
	if e == "0":
		return {}
	var on := {}
	for t: String in ["center", "baths", "mansio", "prefect"]:
		if e == "" or e == "1" or t in e.split(","):
			on[t] = true
	return on

## Полный след (м, x0, x1, z0, z1 при yaw 0): передний край — там же, где у прежней сборки (вход и улица на прежнем
## месте; гостиница и дом префекта растут назад и в стороны). Станция — внутри прежнего следа на вырост (уровень 6:
## 9,9 × 7,0 м), 8,8 × 7,0 = 62 м²; бани — та же глубина, уже: 9,5 × 7,2 = 68 м²
const FULL := {"center": [-4.4, 4.4, -4.49, 2.54], "baths": [-4.75, 4.75, -3.97, 3.19], "mansio": [-2.655, 3.345, -4.91, 1.09], "prefect": [-3.0, 3.0, -4.2, 1.8]}
## Прежний след в осях постройки (замер test_b3_probe по прежним сборкам): x0, x1, z0, z1
const OLD_RECT := {"center": [-4.4, 4.4, -4.49, 2.54], "baths": [-5.08, 5.06, -3.97, 3.19], "mansio": [-2.09, 2.78, -4.5, 1.09], "prefect": [-2.78, 2.78, -3.32, 1.8]}

const Y0 := 0.06                 # верх мощёного двора
const WT := 0.16
const WARM := Color(0.3, 0.18, 0.09)
const GOLD := Color(1.0, 0.78, 0.36)
const BRONZE := Color(0.7, 0.48, 0.28)
const GOLD_STATUE := {"tints": {"Statue_01": GOLD}}
const BRONZE_STATUE := {"tints": {"Statue_01": BRONZE}}
const PAVING := {"Stone_01": "Floor_Tiles_06"}
const PORCH := {"Stone_01": "Floor_Tiles_02"}
const MOSAIC := {"Stone_01": "Floor_Tiles_Circle_01"}
const WOOD_FLOOR := {"Stone_01": "Wood_02"}
const MARBLE := {"Stucco_White_01": "Building_Marble_01"}
const PIL := {"Building_Large_Brick_01": "Building_Marble_01"}
const FRIEZE := {"Stucco_Blue_01": "Building_Marble_03"}
const TYMPANUM := {"Stone_01": "Stucco_Blue_01", "tints": {"Stucco_Blue_01": Color(0.78, 0.87, 1.0)}}
const GOLD_RELIEF := {"tints": {"Building_Marble_01": GOLD}}
const DOME := {"Stucco_Blue_01": "Stucco_White_01", "tints": {"Stucco_White_01": Color(0.67, 0.66, 0.62)}}
const WARM_STONE := {"tints": {"Building_Large_Brick_01": Color(1.0, 0.88, 0.7)}}
const RED_LO := {"Stucco_White_01": "Stucco_Red_01", "glow": WARM * 0.9}      # нижняя облицовка комнаты (как NewGrand)
## Раскраски стен: гладкая стена Synty (штукатурка Stucco_White_01) и стена с окном (штукатурка Stucco_Orange_01,
## рама и фронтончик белые). Оттенок — у экземпляра (Parts: общая группа с домами города)
const OCHRE_WALL := {"Stucco_White_01": "Stucco_Orange_01"}
const OCHRE_WIN := {}
const CREAM := Color(1.0, 0.93, 0.8)
const CREAM_WALL := {"tints": {"Stucco_White_01": CREAM}}
const CREAM_WIN := {"Stucco_Orange_01": "Stucco_White_01", "tints": {"Stucco_White_01": CREAM}}
const ROSE := Color(1.18, 0.9, 0.86)
const ROSE_WALL := {"Stucco_White_01": "Stucco_Red_01", "tints": {"Stucco_Red_01": ROSE}}
const ROSE_WIN := {"Stucco_Orange_01": "Stucco_Red_01", "tints": {"Stucco_Red_01": ROSE}}
const RED_WALL := {"Stucco_White_01": "Stucco_Red_01"}
const RED_WIN := {"Stucco_Orange_01": "Stucco_Red_01"}
const WHITE_WALL := {"tints": {"Stucco_White_01": Color(1.0, 0.97, 0.92)}}
const ORANGE_TYM := {"Stone_01": "Stucco_Orange_01"}
const ROSE_TYM := {"Stone_01": "Stucco_Red_01", "tints": {"Stucco_Red_01": ROSE}}
const CREAM_TYM := {"Stone_01": "Stucco_White_01", "tints": {"Stucco_White_01": CREAM}}
const TIMBER := {"tints": {"Wood_01": Color(0.86, 0.66, 0.46)}}
const HAY := {"tint": Color(1.0, 0.92, 0.7)}

## Лошади (game._pets2, модель Quaternius): [вид, место в осях чертежа, поворот, движение, масштаб, облик]
const HORSE_K := 0.85


static func covers(type: String) -> bool:
	return bool(ON.get(type, false))


static func rect_of(type: String, old: bool) -> Array:
	return (OLD_RECT[type] if old else FULL[type]) as Array


static func build(b: Bp, type: String, tier: int) -> void:
	var K := Catalog.scale_of(type)
	var old := Catalog.fit != Vector2.ZERO
	var r := rect_of(type, old)
	var c := Vector3((float(r[0]) + float(r[1])) * 0.5, 0, (float(r[2]) + float(r[3])) * 0.5)
	if type == "baths":
		c = Vector3.ZERO                         # бани сами ставят себя посреди прежнего следа (_baths_dims)
	var w := float(r[1]) - float(r[0])
	var d := float(r[3]) - float(r[2])
	b.base = Transform3D(Basis.from_scale(Vector3.ONE / K), Vector3.ZERO) * Transform3D(Basis.IDENTITY, c)
	var door := Vector3.ZERO
	match type:
		"center": door = _center(b, w, d, clampi(tier, 0, 7))
		"baths": door = _baths(b, _baths_dims(old))
		"mansio": door = _mansio(b, w, d, old)
		"prefect": door = _prefect(b, w, d, old)
	b.base = Transform3D.IDENTITY
	b.door = (door + c) / K


# =====================================================================
#   помощники (метры города, середина следа — начало координат, фасад к +Z)
# =====================================================================

static func _p(b: Bp, name: String, p: Vector3, yaw := 0.0, s := Vector3.ONE, rm := {}) -> void:
	b.parts.append([name, b.base * Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(s), p), rm])


static func _u(b: Bp, name: String, p: Vector3, yaw: float, s: float, rm := {}) -> void:
	_p(b, name, p, yaw, Vector3.ONE * s, rm)


static func _box(b: Bp, c: Vector3, sz: Vector3) -> void:
	b.parts.append(["#marble", b.base * Transform3D(Basis.from_scale(sz), c), {}])


## Нормаль лица стены, идущей по dir (лицо — влево от направления, как у NewTemple._run)
static func _nrm(dir: Vector3) -> Vector3:
	return Vector3(-dir.z, 0, dir.x)


static func _yaw(dir: Vector3) -> float:
	return atan2(-dir.z, dir.x)


## Стороны корпуса x0..x1 × z0..z1: [начало на лице стены, направление, длина] (0 перед, 1 право, 2 зад, 3 лево)
static func _side(x0: float, x1: float, z0: float, z1: float, s: int) -> Array:
	match s:
		0: return [Vector3(x0, 0, z1), Vector3(1, 0, 0), x1 - x0]
		1: return [Vector3(x1, 0, z1), Vector3(0, 0, -1), z1 - z0]
		2: return [Vector3(x1, 0, z0), Vector3(-1, 0, 0), x1 - x0]
	return [Vector3(x0, 0, z0), Vector3(0, 0, 1), z1 - z0]


## Корпус: стены модулями по сторонам (код модуля → деталь и убранство), этажи hs с поясом e между ними, пилястры
## по краям модулей и углам, карниз и фриз поверху, мраморный цоколь. sides: сторона → [коды нижнего этажа, верхнего…]
## (сторона без списка — без стен: к ней примыкает другой корпус). Коды: «W» гладкая стена, «G» окно в тёплый свет
## (стенка свечения за проёмом; внизу — ящик с цветами), «S» окно в тёплый свет со ставнями (Life), «N» ниша
## со статуей, «D» вход: бронзовые створки (Life) в арке, за ними — освещённые сени, «B» глухая арка с тёплой нишей,
## «» — пропуск. o: wall, win — раскраски; pil, frieze, plinth — да/нет; shut — цвет ставен; leaf — створки двери;
## statues — статуи ниш; room — глубина сеней. Возвращает высоту верха стен
static func _block(b: Bp, x0: float, x1: float, z0: float, z1: float, y: float, hs: Array, e: float, sides: Dictionary, o := {}) -> float:
	var wall: Dictionary = o.get("wall", CREAM_WALL)
	var win: Dictionary = o.get("win", CREAM_WIN)
	var band: Dictionary = o.get("band", MARBLE)
	var top := y
	for h: float in hs:
		top += h
	top += e * (hs.size() - 1)
	var st := 0
	for s: int in sides:
		var sd: Array = _side(x0, x1, z0, z1, s)
		var a: Vector3 = sd[0]
		var dir: Vector3 = sd[1]
		var len: float = sd[2]
		var n := _nrm(dir)
		var floors: Array = sides[s]
		var yy := y
		var nmods := 1
		for f in floors.size():
			var codes: Array = floors[f]
			var h: float = hs[f]
			nmods = maxi(nmods, codes.size())
			var mw := len / codes.size()
			for i in codes.size():
				var cd: String = codes[i]
				var p0 := Vector3(a.x, yy, a.z) + dir * (mw * i)
				_module(b, cd, p0, dir, mw, h, wall, win, o, f, st)
				st += 1
			yy += h
			if f < floors.size() - 1 and e > 0.0:
				# пояс между этажами: мраморная полоса заподлицо со стеной
				_p(b, "SM_Bld_Wall_01", Vector3(a.x, yy, a.z) - n * 0.11, _yaw(dir), Vector3(len / 2.5, e / 3.01, 1.0), band)
				yy += e
		# пилястры: по краям модулей нижнего этажа (и углам)
		if bool(o.get("pil", true)):
			var codes0: Array = floors[0]
			var mw0 := len / codes0.size()
			for i in codes0.size() + 1:
				var q := Vector3(a.x, y, a.z) + dir * clampf(mw0 * i, 0.08, len - 0.08) + n * 0.03
				_p(b, "SM_Bld_Wall_Large_Pillar_01", q, 0.0, Vector3(0.24, (top - y) / 4.55, 0.24), PIL)
		if bool(o.get("frieze", true)):
			_run(b, "SM_Bld_Trim_Large_Single_02", Vector3(a.x, top - 0.17, a.z) + n * 0.01, dir, len, 2.5, 0.34, 0.6, FRIEZE, 1.7)
		if bool(o.get("plinth", true)):
			_run(b, "SM_Bld_Trim_05", Vector3(a.x, y, a.z) + n * 0.01, dir, len, 2.5, 0.42, 0.45, MARBLE, 1.7)
	# карниз поверху — только по сторонам со стенами
	var cs := []
	for s: int in sides:
		cs.append(s)
	_ring(b, "SM_Bld_Wall_Large_Cap_01", x0 - 0.05, x1 + 0.05, z0 - 0.05, z1 + 0.05, top - 0.03, 5.02, 0.55, 0.4, {}, cs, 1.8)
	return top


## Один модуль стены (см. _block)
static func _module(b: Bp, cd: String, p0: Vector3, dir: Vector3, mw: float, h: float, wall: Dictionary, win: Dictionary, o: Dictionary, f: int, k: int) -> void:
	var yaw := _yaw(dir)
	var n := _nrm(dir)
	var sx := mw / 2.5
	var sy := h / 3.01
	match cd:
		"W":
			_p(b, "SM_Bld_Wall_01", p0 - n * 0.11, yaw, Vector3(sx, sy, 1.0), wall)
		"G", "S":
			_p(b, "SM_Bld_Wall_Window_05", p0 - n * 0.28 * 0.6, yaw, Vector3(sx, sy, 0.6), win)
			# тёплая стенка за проёмом (за ней — «комната»): видна сквозь решётку окна, ночью и днём
			_p(b, "SM_Bld_Wall_01", p0 + dir * (0.5 * sx) - n * 0.42 + Vector3(0, 0.55 * sy, 0), yaw, Vector3(1.5 * sx / 2.5, 1.65 * sy / 3.01, 0.1), NewGrand.GLOW_PANEL)
			if cd == "S":
				_shutters(b, p0, dir, sx, sy, String(o.get("shut", "#shutters_green")))
			elif f == 0 and bool(o.get("boxes", true)):
				var kb := minf(0.9, 1.25 * sx)
				_p(b, "#window_box", p0 + dir * (1.25 * sx) + Vector3(0, 0.62 * sy, 0), yaw, Vector3(kb, kb, 0.5))
		"N":
			_p(b, "SM_Bld_Wall_Alcove_01", p0 - n * 0.38 * 0.5, yaw, Vector3(sx, sy, 0.5), MARBLE)
			var sts: Array = o.get("statues", ["SM_Prop_Statue_03", "SM_Prop_Statue_05", "SM_Prop_Statue_06", "SM_Prop_Statue_07"])
			_u(b, String(sts[k % sts.size()]), p0 + dir * (1.25 * sx) - n * 0.12 + Vector3(0, 0.16 * sy, 0), yaw, minf(0.5, h * 0.21), o.get("statue_rm", {}))
		"B":
			_p(b, "SM_Bld_Wall_Door_Double_01", p0 - n * 0.24 * 0.5, yaw, Vector3(sx, sy, 0.5), wall if wall.has("Stucco_Orange_01") else WARM_STONE)
			_p(b, "SM_Bld_Wall_01", p0 + dir * (-0.03) - n * 0.3 * 0.5, yaw, Vector3((2.0 * sx + 0.06) / 2.5, (1.97 * sy + 0.05) / 3.01, 0.2), NewCivic.OCHRE_GLOW)
		"D":
			_p(b, "SM_Bld_Wall_Door_Large_01", p0 - n * 0.3, yaw, Vector3(sx, sy, 1.0), o.get("door_rm", WARM_STONE))
			var lw := 1.2 * sx * 0.5
			var ls := Vector3(lw / 0.56, 2.45 * sy / 2.47, 0.8)
			var leaf: String = o.get("leaf", "SM_Bld_Door_Large_Half_03")
			_p(b, leaf, p0 + dir * (0.65 * sx) - n * 0.26, yaw, ls)
			_p(b, leaf, p0 + dir * (0.65 * sx + lw) - n * 0.26, yaw, ls)


## Ставни (Life): две дощатые створки по бокам окна модуля (окно Synty: середина на 1,25 вдоль, низ проёма на 0,7)
static func _shutters(b: Bp, p0: Vector3, dir: Vector3, sx: float, sy: float, col: String) -> void:
	var bs := Basis(Vector3.UP, _yaw(dir))
	for e: Array in CatDressCivic._shutter_pair(col, sx, sy):
		var lx: Transform3D = e[1]
		var at := p0 + dir * (1.25 * sx + lx.origin.x) + _nrm(dir) * 0.012 + Vector3(0, 0.7 * sy, 0)
		b.parts.append([e[0], b.base * Transform3D(bs * lx.basis, at), e[2]])


static func _run(b: Bp, name: String, a: Vector3, dir: Vector3, len: float, pw: float, sy: float, sz: float, rm := {}, seg := 1.25) -> void:
	NewTemple._run(b, name, a, dir, len, pw, sy, sz, rm, seg)


static func _ring(b: Bp, name: String, x0: float, x1: float, z0: float, z1: float, y: float, pw: float, sy: float, sz: float, rm := {}, sides := [0, 1, 2, 3], seg := 1.25) -> void:
	NewTemple._ring(b, name, x0, x1, z0, z1, y, pw, sy, sz, rm, sides, seg)


## Своё основание: мощёный двор по всему следу, бордюр из тёсаного камня по краю уходит в землю
static func _court(b: Bp, x0: float, x1: float, z0: float, z1: float) -> void:
	NewGrand._court(b, x0, x1, z0, z1, PAVING, 1.6)


## Двускатная кровля, конёк вдоль X (x0..x1), скаты от z0 до z1 (свес включён), низ скатов на y; pitch — круче;
## щипцы на торцах ends [левый, правый] (tym — раскраска). Возвращает высоту конька
static func _gable_x(b: Bp, x0: float, x1: float, z0: float, z1: float, y: float, pitch := 1.0, tym := ORANGE_TYM, ends := [true, true], roof := {}) -> float:
	var rh := (z1 - z0) * 0.5
	var zm := (z0 + z1) * 0.5
	var k := rh / 7.5
	var ky := k * pitch
	var len := x1 - x0
	var n := maxi(1, int(ceil(len / 3.4)))
	var lx := len / n
	for i in n:
		_p(b, "SM_Bld_Roof_Straight_Thin_Large_01", Vector3(x0 + i * lx, y, zm + rh), 0.0, Vector3(lx / 7.5, ky, k), roof)
		_p(b, "SM_Bld_Roof_Straight_Thin_Large_01", Vector3(x0 + (i + 1) * lx, y, zm - rh), PI, Vector3(lx / 7.5, ky, k), roof)
	for e: Array in [[x0 + 0.08, bool(ends[0])], [x1 - 0.08, bool(ends[1])]]:
		if not bool(e[1]):
			continue
		var xx: float = e[0]
		_p(b, "SM_Bld_Roof_Side_Large_01", Vector3(xx, y, zm + rh - 0.05), 0.0, Vector3(0.45, ky, k), tym)
		_p(b, "SM_Bld_Roof_Side_Large_01", Vector3(xx, y, zm - rh + 0.05), PI, Vector3(0.45, ky, k), tym)
	return y + 1.94 * ky


## Двускатная кровля, конёк вдоль Z над x = xm (полуширина по свесу rh), z0..z1; фронтоны ends [перед, зад]
static func _gable_z(b: Bp, xm: float, rh: float, z0: float, z1: float, y: float, pitch := 1.0, tym := TYMPANUM, ends := [true, true], roof := {}) -> float:
	var keep := b.base
	b.base = keep * Transform3D(Basis.IDENTITY, Vector3(xm, 0, 0))
	var ridge := NewGrand._roof_z(b, rh, z0, z1, y, roof, tym, ends, pitch)
	b.base = keep
	return ridge


## Односкатный навес: верх у стены на x = xw (ниже — к xe), z0..z1, низ ската на y
static func _lean_x(b: Bp, xw: float, xe: float, z0: float, z1: float, y: float, pitch := 1.0) -> float:
	var rh := absf(xe - xw)
	var k := rh / 7.5
	var ky := k * pitch
	if xe > xw:
		_p(b, "SM_Bld_Roof_Straight_Thin_Large_01", Vector3(xe, y, z1), PI / 2, Vector3((z1 - z0) / 7.5, ky, k))
	else:
		_p(b, "SM_Bld_Roof_Straight_Thin_Large_01", Vector3(xe, y, z0), -PI / 2, Vector3((z1 - z0) / 7.5, ky, k))
	return y + 1.94 * ky


static func _bowl(b: Bp, p: Vector3, s := 0.42) -> void:
	NewCivic._bowl(b, p, s)


static func _pot(b: Bp, p: Vector3, s := 0.3) -> void:
	_u(b, "SM_Prop_FlowerPot_Fancy_01", p + Vector3(0, 0.57 * s, 0), b.rng.randf() * TAU, s)


static func _bush(b: Bp, p: Vector3, s := 0.32) -> void:
	NewCivic._bush(b, p, s)


static func _cypress(b: Bp, p: Vector3, s := 0.38) -> void:
	NewCivic._cypress(b, p, s)


static func _ivy(b: Bp, p: Vector3, yaw: float, k: int, s := 0.6) -> void:
	_u(b, "SM_Env_Ivy_Flowers_0%d" % (1 + k % 5), p, yaw, s)


## Доска объявлений: два столбика, доска с рисунком постоялого двора, черепичный козырёк, у ног — корзина со свитками
static func _notice(b: Bp, p: Vector3, yaw: float, s := 0.85) -> void:
	var bs := Basis(Vector3.UP, yaw)
	for sxk: float in [-0.56, 0.56]:
		_p(b, "SM_Prop_Pole_01", p + bs * Vector3(sxk, 0, 0) * s, yaw, Vector3(0.5, 0.66, 0.5) * s)
	b.free_parts[b.parts.size()] = true          # у вывески габарит — кубик 1 м (Bp.model_aabb): землю не занимает
	_p(b, "#sign:mansio", p + bs * Vector3(0, 1.32, 0.09) * s, yaw, Vector3.ONE * s)
	_p(b, "SM_Prop_Overhang_02", p + bs * Vector3(0, 2.02, -0.4) * s, yaw, Vector3.ONE * s)
	_u(b, "SM_Prop_Scroll_Pile_02", p + bs * Vector3(0.45, 0, -0.2) * s, yaw + 0.4, 0.5 * s)


## Багаж приезжих: короб с крышкой, скатка, мешок, заплечная корзина
static func _luggage(b: Bp, p: Vector3, yaw: float, s := 0.8) -> void:
	var bs := Basis(Vector3.UP, yaw)
	var bt := Bp.model_aabb("SM_Prop_Basket_02").end.y * s
	_u(b, "SM_Prop_Basket_02", p + bs * Vector3(-0.4, 0, 0) * s, yaw + 0.1, s)
	_u(b, "SM_Prop_Basket_Lid_01", p + bs * Vector3(-0.4 * s, bt - 0.02, 0), yaw + 0.1, s)
	_u(b, "SM_Prop_Rug_Folded_02", p + bs * Vector3(-0.4 * s, bt + 0.05, 0), yaw - 0.2, 0.55 * s)
	_u(b, "SM_Prop_Sack_03", p + bs * Vector3(0.2, 0, 0.02) * s, yaw + 0.3, s)
	_u(b, "SM_Prop_Basket_Backpack_01", p + bs * Vector3(0.68, 0, 0.04) * s, yaw + 0.4, s)


## Повозка (кузов и поклажа Synty)
static func _cart(b: Bp, p: Vector3, yaw: float, s := 0.85, load := 2) -> void:
	_u(b, "SM_Prop_Cart_01", p, yaw, s)
	_u(b, "SM_Prop_Cart_01_Insert_0%d" % load, p, yaw, s)


## Поилка: каменная чаша с водой
static func _trough(b: Bp, p: Vector3, yaw: float, s := 0.8) -> void:
	_u(b, "SM_Prop_Bowl_07", p, yaw, s)
	var bs := Basis(Vector3.UP, yaw)
	b.parts.append(["#water", b.base * Transform3D(bs * Basis.from_scale(Vector3(0.7, 0.12, 0.85) * s / 0.85), p + Vector3(0, 0.12 * s / 0.85 + 0.06, 0)), {}])


## Фасции: пучок прутьев с топором
static func _fasces(b: Bp, p: Vector3, sx: float) -> void:
	for k in 5:
		_p(b, "SM_Prop_Pole_01", p + Vector3(cos(k * 1.26) * 0.045, 0, sin(k * 1.26) * 0.045), 0.0, Vector3(0.22, 0.48, 0.22), {"tint": Color(0.75, 0.55, 0.35)})
	_p(b, "SM_Wep_Axe_01", p + Vector3(0, 0.82, 0.04), sx * 0.3, Vector3.ONE * 0.85)


## Статуя на постаменте
static func _statue(b: Bp, p: Vector3, yaw: float, nm: String, s := 0.5, rm := {}) -> void:
	_p(b, "SM_Prop_Plinth_04", p, 0.0, Vector3(0.62, 0.55, 0.62) * s / 0.5)
	_u(b, nm, p + Vector3(0, 0.68 * 0.55 * s / 0.5, 0), yaw, s, rm)


# =====================================================================
#   дом префекта
# =====================================================================

## w × d — след (полный 6 × 6; старое место 5,6 × 5,1). Фасад к +Z
static func _prefect(b: Bp, w: float, d: float, old: bool) -> Vector3:
	var X := w * 0.5
	var Z := d * 0.5
	_court(b, -X, X, -Z, Z)
	var m := 0.25
	var F := 0.3 if old else 0.42          # полоса двора перед лестницей
	var S := 0.42                          # лестница
	var P := 1.12 if old else 1.32         # портик
	var BX := X - m
	var BZ0 := -Z + m
	var BZ1 := Z - F - S - P
	var HP := 0.24
	var YP := Y0 + HP
	var H1 := 2.35
	var E := 0.2
	var H2 := 1.85 if old else 1.95
	var SZ := BZ1 + P                      # верх лестницы (край подиума портика)
	# подиум: тёсаный камень по бокам и сзади, плиты портика, лестница во всю ширину портика
	_ring(b, "SM_Bld_Wall_Large_01", -BX - 0.04, BX + 0.04, BZ0 - 0.04, SZ, Y0 - 0.3, 5.0, (HP + 0.3) / 4.51, 0.26, {}, [1, 2, 3], 2.0)
	_box(b, Vector3(0, Y0 + HP * 0.5, (BZ0 + SZ) * 0.5), Vector3(2.0 * BX, HP - 0.01, SZ - BZ0 - 0.02))
	NewCivic._floor(b, PORCH, -BX, BZ1, BX, SZ, YP + 0.003, 1.6)
	var ns := maxi(1, int(ceil(2.0 * BX / 2.5)))
	var sw := 2.0 * BX / ns
	for i in ns:
		_p(b, "SM_Bld_Stairs_01", Vector3(-BX + i * sw, Y0, SZ + S), 0.0, Vector3(sw / 2.5, HP / 1.5, S / 2.5))
	# корпус: внизу окна в тёплый свет и вход, наверху окна со ставнями; сзади — ниши со статуями
	var o := {"wall": CREAM_WALL, "win": CREAM_WIN, "shut": "#shutters_green", "door_rm": NewCivic.MARBLE,
		"statues": ["SM_Prop_Statue_05", "SM_Prop_Statue_07", "SM_Prop_Statue_03"]}
	var sides := {0: [["G", "D", "G"], ["S", "S", "S"]], 1: [["G", "G"], ["S", "S"]], 2: [["N", "G", "N"], ["S", "W", "S"]], 3: [["G", "G"], ["S", "S"]]}
	var top := _block(b, -BX, BX, BZ0, BZ1, YP, [H1, H2], E, sides, o)
	# сени за бронзовыми дверями: тёплый мрамор и роспись, бюст на постаменте, светильник
	var mw := 2.0 * BX / 3.0
	var kx := mw / 2.5
	var rz1 := BZ1 - 0.6
	var rd := minf(1.5, rz1 - BZ0 - 0.4)
	NewGrand._room(b, -mw * 0.5 + 0.08, mw * 0.5 - 0.08, rz1 - rd, rz1, YP, H1 - 0.06, 0.0, 0.6 * kx, 2.45 * H1 / 3.01,
		RED_LO, NewCivic.OCHRE_GLOW)
	_p(b, "SM_Prop_Plinth_02", Vector3(0, YP, rz1 - rd + 0.3), 0.0, Vector3(0.55, 0.62, 0.55), {"glow": WARM * 0.5})
	_u(b, "SM_Prop_Statue_05", Vector3(0, YP + 0.62, rz1 - rd + 0.3), 0.0, 0.32, {"glow": WARM * 0.6})
	_u(b, "SM_Prop_Mural_02", Vector3(-mw * 0.5 + 0.12, YP + 1.2, rz1 - rd * 0.5), PI / 2, minf(0.36, (rd - 0.2) / 2.53), {"glow": WARM * 0.55})
	# портик: четыре колонны на постаментах, антаблемент с фризом, наверху терраса с балюстрадой и знамёнами
	var cz := SZ - 0.28
	var colx := [-BX + 0.3, -mw * 0.5 + 0.05, mw * 0.5 - 0.05, BX - 0.3]
	for x: float in colx:
		_p(b, "SM_Prop_Plinth_04", Vector3(x, YP, cz), 0.0, Vector3(0.46, 0.4, 0.46))
		_p(b, "SM_Bld_Pillar_04", Vector3(x, YP + 0.27, cz), 0.0, Vector3(0.5, (H1 - 0.27) / 3.0, 0.5))
	NewCivic._ledge(b, -BX - 0.08, BX + 0.08, BZ1 - 0.05, cz + 0.32, YP + H1, E + 0.06)
	_run(b, "SM_Bld_Trim_Large_Single_02", Vector3(-BX - 0.06, YP + H1 + 0.02, cz + 0.33), Vector3(1, 0, 0), 2.0 * BX + 0.12, 2.5, 0.3, 0.5, FRIEZE, 1.6)
	var yt := YP + H1 + E + 0.06
	NewCivic._floor(b, PORCH, -BX, BZ1, BX, cz + 0.3, yt + 0.01, 1.6)
	_ring(b, "SM_Bld_Wall_Tiny_01", -BX + 0.04, BX - 0.04, BZ1 + 0.1, cz + 0.28, yt, 2.5, 1.1, 1.0, MARBLE, [0, 1, 3], 1.6)
	for sd: float in [-1.0, 1.0]:
		_pot(b, Vector3(sd * (BX - 0.3), yt + 0.31, cz + 0.05), 0.22)
		_u(b, "SM_Prop_Banner_03_C", Vector3(sd * (mw * 0.5 + 0.35), top - 0.1, BZ1 + 0.03), 0.0, 0.5)
	# между колоннами — синие гирлянды, под портиком — светильник на цепи и скамьи у стены
	NewCivic._garland(b, colx[1], colx[2], YP + H1 - 0.02, cz + 0.05)
	CatShops._hanging_lamp(b, Vector3(0, YP + H1 - 0.02, (BZ1 + cz) * 0.5 + 0.1), 0.45, true)
	for sd: float in [-1.0, 1.0]:
		_p(b, "SM_Prop_Seat_Bench_03", Vector3(sd * (BX - mw * 0.5), YP, BZ1 + 0.3), 0.0, Vector3.ONE * 0.42)
		_fasces(b, Vector3(sd * (0.6 * kx + 0.24), YP, BZ1 + 0.18), sd)
	# кровля: черепица, фронтон к улице — синий тимпан, золотой рельеф, акротерии; сзади — щипец в цвет стен
	var ridge := _gable_z(b, 0.0, BX + 0.18, BZ0 - 0.18, BZ1 + 0.18, top, 1.0, TYMPANUM, [true, true])
	var keep := b.base
	NewGrand._relief(b, BX + 0.18, top, ridge, BZ1 + 0.15, 0.0, false, "SM_Prop_Symbol_05")
	NewGrand._acro(b, BX + 0.18, top, ridge, BZ1 + 0.18, 0.0, "SM_Prop_Statue_04", 0.22)
	b.base = keep
	# у ступеней — статуи на постаментах и чаши огня, по углам двора — цветы, сзади — кипарисы и плющ
	for sd: float in [-1.0, 1.0]:
		if not old:
			_statue(b, Vector3(sd * (X - 0.45), Y0, Z - 0.62), 0.0, "SM_Prop_Statue_06" if sd > 0 else "SM_Prop_Statue_04", 0.42)
		else:
			_pot(b, Vector3(sd * (X - 0.25), Y0, Z - 0.2), 0.24)
		_bowl(b, Vector3(sd * (BX - 0.25), YP, SZ - 0.1), 0.26)
		_cypress(b, Vector3(sd * (X - 0.2), Y0, -Z + 0.2), 0.34)
		_ivy(b, Vector3(sd * (BX + 0.03), YP + 1.3, BZ0 + 0.5), sd * PI / 2, 1 if sd < 0 else 3, 0.58)
		_ivy(b, Vector3(sd * (BX - 0.45), YP + 1.1, BZ0 - 0.03), PI, 2 if sd < 0 else 4, 0.5)
	_u(b, "SM_Prop_Banner_03_A", Vector3(0, top - 0.1, BZ0 - 0.03), PI, 0.5)
	b.light(Vector3(0, YP + 1.6, BZ1 + 0.6))
	b.actor(Vector3(-0.85, YP, BZ1 + 0.75), 0.4, "Idle", "rich")
	b.actor(Vector3(0.95, YP, BZ1 + 0.85), -0.6, "Idle_Talking", "rich")
	return Vector3(0, 0, Z + 0.35)


# =====================================================================
#   гостиница
# =====================================================================

## w × d — след (полный 6 × 6; старое место 4,9 × 5,6). Слева — дом, справа — конюшня, впереди — двор
static func _mansio(b: Bp, w: float, d: float, old: bool) -> Vector3:
	var X := w * 0.5
	var Z := d * 0.5
	_court(b, -X, X, -Z, Z)
	var m := 0.3
	var HX0 := -X + m
	var HX1 := HX0 + (2.9 if old else 3.3)      # дом
	var HZ0 := -Z + m
	var HZ1 := HZ0 + (2.9 if old else 3.05)
	var SX1 := X - m                             # конюшня: от дома до края
	var H1 := 2.3
	var E := 0.18
	var H2 := 1.95
	var o := {"wall": ROSE_WALL, "win": ROSE_WIN, "door_rm": WARM_STONE, "shut": "#shutters_green", "band": WHITE_WALL,
		"leaf": "SM_Bld_Door_Large_Half_01", "frieze": false}
	var sides := {0: [["G", "D"], ["S", "S"]], 1: [["W", "W"], ["S", "G"]], 2: [["G", "N"], ["S", "S"]], 3: [["G", "G"], ["S", "S"]]}
	if old:
		sides[3] = [["G"], ["S"]]
		sides[1] = [["W"], ["S"]]
	var top := _block(b, HX0, HX1, HZ0, HZ1, Y0, [H1, H2], E, sides, o)
	# таверна за дверью: тёплая комната, стол с кувшином, амфоры
	var mw := (HX1 - HX0) * 0.5
	var kx := mw / 2.5
	var dc := HX0 + mw * 1.5
	var rz1 := HZ1 - 0.6
	var rd := minf(1.6, rz1 - HZ0 - 0.3)
	NewGrand._room(b, dc - mw * 0.5 + 0.08, dc + mw * 0.5 - 0.08, rz1 - rd, rz1, Y0, H1 - 0.05, dc, 0.6 * kx, 2.45 * H1 / 3.01,
		RED_LO, NewCivic.OCHRE_GLOW)
	_u(b, "SM_Prop_Table_01", Vector3(dc, Y0, rz1 - rd * 0.55), 0.0, 0.5, {"glow": WARM * 0.4})
	_u(b, "SM_Prop_Jug_02", Vector3(dc - 0.1, Y0 + 0.39, rz1 - rd * 0.55), 0.0, 0.55, {"glow": WARM * 0.4})
	_u(b, "SM_Prop_Vase_Pile_02", Vector3(dc + mw * 0.5 - 0.35, Y0, rz1 - rd + 0.3), 0.0, 0.38, {"glow": WARM * 0.4})
	# балкон второго этажа над входом: деревянные перила, цветы, ковёр на перилах
	var by := Y0 + H1 + E
	_ledge_z(b, HX0 + 0.1, HX1 - 0.1, HZ1 - 0.05, HZ1 + 0.55, by - 0.12, 0.14)
	_run(b, "SM_Bld_Wall_Balcony_03", Vector3(HX0 + 0.1, by, HZ1 + 0.52), Vector3(1, 0, 0), HX1 - HX0 - 0.2, 2.5, 0.75, 0.7, ROSE_WALL, 1.6)
	for k in 2:
		_u(b, "SM_Prop_FlowerPot_Hanging_0%d" % (4 + k), Vector3(HX0 + 0.55 + k * (HX1 - HX0 - 1.1), by + 0.95, HZ1 + 0.5), 0.0, 0.5)
	_u(b, "SM_Prop_Rug_Drape_01", Vector3(HX0 + mw * 0.75, by + 0.62, HZ1 + 0.56), 0.0, 0.62)
	# кровля: черепица, конёк вдоль фасада, щипцы в цвет стен
	var ridge := _gable_x(b, HX0 - 0.15, HX1 + 0.12, HZ0 - 0.2, HZ1 + 0.2, top, 1.8, ROSE_TYM, [true, true])
	_u(b, "SM_Bld_Roof_Topper_03", Vector3(HX0 + 0.2, ridge - 0.04, (HZ0 + HZ1) * 0.5), 0.0, 0.62)
	_u(b, "SM_Bld_Roof_Topper_03", Vector3(HX1 - 0.2, ridge - 0.04, (HZ0 + HZ1) * 0.5), 0.0, 0.62)
	# вывеска с ключом над дверью, фонарь
	CatShops._sign(b, Vector3(dc + mw * 0.45, 2.55, HZ1 + 0.04), 0.0, "H", 2, 0.55)
	CatShops._lamp(b, Vector3(dc - mw * 0.55, 2.1, HZ1 + 0.02), 0.0)
	# конюшня: каменная, открыта к двору; бок и зад — окно в тёплый свет и глухая арка с сеном в свете, пилястры,
	# карниз; навес под черепицей — от стены дома
	var sz0 := HZ0
	var sz1 := HZ1 - 0.15
	var sxa := HX1
	var sh := 2.05
	var st := {"Stucco_White_01": "Building_Large_Brick_01", "Stucco_Orange_01": "Building_Large_Brick_01", "tints": {"Building_Large_Brick_01": Color(1.0, 0.86, 0.7)}}
	_block(b, sxa, SX1, sz0, sz1, Y0, [sh], 0.0, {1: [["B", "G"]], 2: [["G"] if old else ["G", "B"]]}, {"wall": st, "win": st, "frieze": false, "boxes": false})
	_lean_x(b, sxa, SX1 + 0.12, sz0 - 0.12, sz1 + 0.25, Y0 + sh + 0.02, 1.2)
	_ivy(b, Vector3(SX1 + 0.02, Y0 + 1.1, sz1 - 0.35), PI / 2, 2, 0.5)
	# внутри: сено, мешки, седло на балке, поилка; лошадь — game._pets2 (pets)
	_u(b, "SM_Prop_Straw_Stack_02", Vector3(SX1 - 0.55, Y0, sz0 + 0.55), 0.3, 0.45, HAY)
	_u(b, "SM_Prop_Straw_Bundle_01", Vector3(sxa + 0.4, Y0, sz0 + 0.45), 0.6, 0.8, HAY)
	_u(b, "SM_Prop_Sack_Stack_01", Vector3(sxa + 0.45, Y0, sz0 + 1.05), PI / 2, 0.55)
	_trough(b, Vector3((sxa + SX1) * 0.5, Y0, sz1 - 0.35), 0.0, 0.62)
	# двор: повозка путников, багаж у двери, стол под виноградной перголой, доска объявлений, кадки с цветами
	var yz0 := HZ1 + 0.6
	_cart(b, Vector3((sxa + SX1) * 0.5 + 0.05, Y0, (yz0 + Z) * 0.5 + 0.05), PI + 0.08, 0.66 if old else 0.72, 2)
	_luggage(b, Vector3(dc + 0.35, Y0, HZ1 + 0.42), 0.0, 0.62)
	var tx := HX0 + mw * 0.6
	var tz := (yz0 + Z) * 0.5 + 0.2
	if not old:
		for c: Vector3 in [Vector3(tx - 0.85, Y0, tz - 0.55), Vector3(tx + 0.85, Y0, tz - 0.55), Vector3(tx - 0.85, Y0, tz + 0.65), Vector3(tx + 0.85, Y0, tz + 0.65)]:
			_p(b, "SM_Bld_Trellis_Pillar_01", c, 0.0, Vector3(0.62, 0.86, 0.62))
		_p(b, "SM_Bld_Trellis_Roof_01", Vector3(tx + 1.05, Y0 + 2.1, tz - 0.75), 0.0, Vector3(0.84, 0.84, 0.75))
		b.parts.append(["SM_Env_Vine_0%d" % (1 + b.rng.randi() % 2), b.base * Transform3D(Basis(Vector3.RIGHT, -PI / 2).scaled(Vector3(0.75, 0.8, 0.8)), Vector3(tx, Y0 + 2.32, tz + 0.6)), {}])
	_u(b, "SM_Prop_Table_04", Vector3(tx, Y0, tz), 0.0, 0.62)
	for sd: float in [-1.0, 1.0]:
		_u(b, "SM_Prop_Seat_Stool_02", Vector3(tx + sd * 0.55, Y0, tz), 0.0, 0.75)
	_u(b, "SM_Prop_Jug_03", Vector3(tx - 0.08, Y0 + 0.46, tz), 0.0, 0.5)
	_u(b, "SM_Prop_Bowl_04", Vector3(tx + 0.14, Y0 + 0.46, tz - 0.05), 0.0, 0.55)
	_notice(b, Vector3(X - 0.55, Y0, Z - 0.3), -0.35, 0.62)
	_pot(b, Vector3(-X + 0.25, Y0, Z - 0.25), 0.26)
	_pot(b, Vector3(HX0 + 0.2, Y0, HZ1 + 0.25), 0.22)
	_p(b, "SM_Prop_Seat_Bench_01", Vector3(HX0 + mw * 0.5, Y0, HZ1 + 0.28), 0.0, Vector3.ONE * 0.62)
	b.light(Vector3(dc, 1.5, HZ1 + 0.7))
	b.actor(Vector3(dc - mw * 0.65, Y0, HZ1 + 0.7), PI - 0.4, "Interact", "any")
	return Vector3(dc, 0, Z + 0.35)


## Плита-карниз вдоль X от x0 до x1 на высоте y, по глубине z0..z1
static func _ledge_z(b: Bp, x0: float, x1: float, z0: float, z1: float, y: float, h := 0.26) -> void:
	NewCivic._ledge(b, x0, x1, z0, z1, y, h)


## Лошади у конюшен (game._pets2): места — по тем же размерам, что и сборка
static func pets(bd: Dictionary) -> Array:
	var t := String(bd["type"])
	if not covers(t):
		return []
	var old := t != "center" and SizeLadder.old_lot(bd) and SizeLadder.OLD_LOT.has(t)
	var r := rect_of(t, old)
	var c := Vector3((float(r[0]) + float(r[1])) * 0.5, 0, (float(r[2]) + float(r[3])) * 0.5)
	var X := (float(r[1]) - float(r[0])) * 0.5
	var Z := (float(r[3]) - float(r[2])) * 0.5
	var K := Catalog.scale_of(t)
	var out := []
	match t:
		"mansio":
			var HX1 := -X + 0.3 + (2.9 if old else 3.3)
			var sxm := (HX1 + X - 0.3) * 0.5
			out.append(["horse", (c + Vector3(sxm, 0, -Z + 0.3 + 1.35)) / K, 0.0, "Eating", HORSE_K * (0.85 if old else 1.0), -1])
		"center":
			out = _center_pets(X, Z, c, K, clampi(int(bd.get("tier", 0)), 0, 7))
	return out


# =====================================================================
#   бани
# =====================================================================

## Бани — в осях постройки без сдвига: новые посреди прежнего следа (та же глубина), мостовая старого места — по всему нему
static func _baths_dims(old: bool) -> Dictionary:
	var full: Array = FULL["baths"]
	var x1 := float(full[1])
	var z0 := float(full[2])
	var z1 := float(full[3])
	var pave: Array = (OLD_RECT["baths"] as Array).duplicate() if old else full.duplicate()
	var dz := (z0 + z1) * 0.5
	var BZ0 := z0 + 0.25                  # банный корпус: задняя грань
	var BZ1 := BZ0 + 2.85                 # передняя грань (ко двору)
	var FZ := z1 - 0.25                   # лицо передней стенки двора
	var s := 0.8                          # бортики бассейна — модуль 2 м
	var pools := [[-2.0, 2.0, BZ1 + 0.95, BZ1 + 2.95, "out"], [-1.25, 1.25, BZ0 + 0.32, BZ0 + 1.57, "in"]]
	return {"x1": x1, "z0": z0, "z1": z1, "dz": dz, "pave": pave, "BZ0": BZ0, "BZ1": BZ1, "FZ": FZ, "CX": 1.55, "HC": 2.75,
		"WX": x1 - 0.25, "HW": 2.15, "s": s, "pools": pools, "wy": Y0 + 0.1, "zd": float(pave[3]) + 0.35}


static func _baths(b: Bp, d: Dictionary) -> Vector3:
	var pv: Array = d["pave"]
	_court(b, pv[0], pv[1], pv[2], pv[3])
	var x1: float = d["x1"]
	var BZ0: float = d["BZ0"]
	var BZ1: float = d["BZ1"]
	var FZ: float = d["FZ"]
	var CX: float = d["CX"]
	var HC: float = d["HC"]
	var WX: float = d["WX"]
	var HW: float = d["HW"]
	var s: float = d["s"]
	var wy: float = d["wy"]
	# ---- кальдарий: фасад — большая арка во двор, бока и зад — красный низ, мраморные пилястры и карниз
	var aw := 2.0 * CX
	_p(b, "SM_Bld_Wall_Door_Double_Large_01", Vector3(-CX, Y0, BZ1 - 0.22 * 0.6), 0.0, Vector3(aw / 2.5, HC / 3.01, 0.6), RED_WALL)
	var o := {"wall": RED_WALL, "win": RED_WIN, "boxes": false, "statues": ["SM_Prop_Statue_06", "SM_Prop_Statue_03"]}
	_block(b, -CX, CX, BZ0, BZ1, Y0, [HC], 0.0, {2: [["N", "N"]]}, o)
	# нутро кальдария: облицовка, мозаика, потолок в тёплом свете; горячий бассейн с паром, курильницы
	var ix := CX - 0.18
	NewCivic._lining(b, -ix, ix, BZ0 + 0.3, BZ1 - 0.16, Y0, HC - 0.06, [[-CX + 0.15, CX - 0.15]])
	NewCivic._floor(b, NewCivic.HALL_FLOOR, -ix, BZ0 + 0.2, ix, BZ1 - 0.1, Y0 + 0.006, 1.7)
	NewCivic._ceiling(b, -ix, BZ0 + 0.2, ix, BZ1 - 0.1, Y0 + HC - 0.1)
	var pi_: Array = (d["pools"] as Array)[1]
	NewCivic._pool(b, pi_[0], pi_[1], pi_[2], pi_[3], 0.5, wy, false)
	for sd: float in [-1.0, 1.0]:
		_u(b, "SM_Prop_Senser_01", Vector3(sd * (ix - 0.25), Y0, BZ1 - 0.45), 0.0, 0.5, {"glow": WARM * 0.6})
	_u(b, "SM_Prop_Marble_LionHead_01", Vector3(0, Y0 + 0.75, BZ0 + 0.34), 0.0, 0.4, {"glow": WARM * 0.5})
	b.light(Vector3(0, 1.5, BZ1 - 0.8))
	# барабан и свинцовый купол над залом (колонны беседки Synty спрятаны в барабане)
	var dr := minf(CX, (BZ1 - BZ0) * 0.5) - 0.3
	var zc := (BZ0 + BZ1) * 0.5
	var ky := 0.36
	var yd := Y0 + HC + 0.08
	var hd := 3.6 * ky + 0.05
	NewCivic._floor(b, PAVING, -CX, BZ0, CX, BZ1, Y0 + HC + 0.08, 2.4)
	for i in 10:
		NewCivic._on_arc(b, "SM_Bld_Wall_Tiny_01", Vector3(0, 0, zc), i * TAU / 10.0, dr, yd, 2.0 * dr * tan(PI / 10.0) + 0.06, 2.5, hd / 0.31, 1.2, MARBLE)
	NewCivic._on_arc_ring_cap(b, Vector3(0, 0, zc), dr + 0.05, yd + hd - 0.02, 10)
	var ks := (2.0 * dr + 0.2) / 5.12
	_p(b, "SM_Prop_Pergola_01", Vector3(0, yd + hd - 3.6 * ky, zc), 0.0, Vector3(ks, ky, ks), DOME)
	# ---- крылья (раздевальня и тёплый зал): окна в тёплый свет, малые купола на плоских крышах
	for sd: float in [-1.0, 1.0]:
		var lo := minf(sd * CX, sd * WX)
		var hi := maxf(sd * CX, sd * WX)
		var wz0 := BZ0 + 0.25
		var wz1 := BZ1 - 0.2
		var ws := {0: [["G", "G"]], 2: [["G", "N"] if sd > 0 else ["N", "G"]]}
		ws[1 if sd > 0 else 3] = [["S", "S"]]
		var ow := {"wall": RED_WALL, "win": RED_WIN, "boxes": false, "shut": "#shutters_blue", "statues": ["SM_Prop_Statue_07", "SM_Prop_Statue_05"]}
		var wt := _block(b, lo, hi, wz0, wz1, Y0, [HW], 0.0, ws, ow)
		NewCivic._floor(b, PAVING, lo, wz0, hi, wz1, wt + 0.05, 2.0)
		_ring(b, "SM_Bld_Wall_Tiny_01", lo + 0.05, hi - 0.05, wz0 + 0.05, wz1 - 0.05, wt + 0.05, 2.5, 1.0, 1.0, MARBLE, [0, 1, 2] if sd > 0 else [0, 2, 3], 2.0)
		var mc := Vector3((lo + hi) * 0.5, 0, (wz0 + wz1) * 0.5)
		var mr := 0.6
		var mky := 0.19
		var ymd := wt + 0.08
		var mh := 3.6 * mky + 0.06
		for i in 8:
			NewCivic._on_arc(b, "SM_Bld_Wall_Tiny_01", mc, i * TAU / 8.0, mr, ymd, 2.0 * mr * tan(PI / 8.0) + 0.05, 2.5, mh / 0.31, 1.0, MARBLE)
		var mks := (2.0 * mr + 0.14) / 5.12
		_p(b, "SM_Prop_Pergola_01", mc + Vector3(0, ymd + mh - 3.6 * mky, 0), 0.0, Vector3(mks, mky, mks), DOME)
		_u(b, "SM_Prop_Banner_03_C", Vector3(sd * (WX - 0.55), wt - 0.08, wz1 + 0.02), 0.0, 0.45)
	# ---- двор: бассейн под открытым небом, мозаика вокруг, колоннады по бокам, передняя стенка с пропилеем
	var po: Array = (d["pools"] as Array)[0]
	NewCivic._pool(b, po[0], po[1], po[2], po[3], s, wy, true)
	NewCivic._floor(b, MOSAIC, float(po[0]) - 0.5, float(po[2]) - 0.45, float(po[1]) + 0.5, float(po[3]) + 0.45, Y0 + 0.003, 2.0)
	var ccx := x1 - 0.8
	var z_a := BZ1 + 0.3
	var z_b := FZ - 0.35
	for sd: float in [-1.0, 1.0]:
		for i in 3:
			_p(b, "SM_Bld_Pillar_02", Vector3(sd * ccx, Y0, lerpf(z_a, z_b, i / 2.0)), 0.0, Vector3(0.6, 0.72, 0.6))
		var xf := sd * (x1 - 0.12)
		var L := z_b - z_a + 0.4
		var cm := L / 2.0
		for i in 2:
			var zz := (z_b + 0.2 - i * cm) if sd > 0 else (z_a - 0.2 + i * cm)
			var nm := "SM_Bld_Wall_Window_05" if (i == 0) == (sd > 0) else "SM_Bld_Wall_Alcove_01"
			var szk := 0.6 if nm == "SM_Bld_Wall_Window_05" else 0.5
			_p(b, nm, Vector3(xf - sd * float(NewCivic.FACE[nm]) * szk, Y0, zz), PI / 2 * sd, Vector3(cm / 2.5, 2.5 / 3.01, szk), RED_WIN if szk == 0.6 else MARBLE)
			if szk == 0.6:
				var a := Vector3(xf, Y0, zz)
				var dir := Vector3(0, 0, -sd)
				_p(b, "SM_Bld_Wall_01", a + dir * (0.5 * cm / 2.5) - _nrm(dir) * 0.42 + Vector3(0, 0.55 * 2.5 / 3.01, 0), _yaw(dir), Vector3(1.5 * cm / 2.5 / 2.5, 1.65 * 2.5 / 3.01 / 3.01, 0.1), NewGrand.GLOW_PANEL)
			else:
				var zcn := zz - cm * 0.5 if sd > 0 else zz + cm * 0.5
				_u(b, "SM_Prop_Statue_0%d" % (6 if sd > 0 else 3), Vector3(xf - sd * 0.12, Y0 + 0.14, zcn), PI / 2 * sd, 0.48)
		for i in 3:
			var zz := lerpf(z_a - 0.2, z_b + 0.2, i / 2.0)
			_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(xf + sd * 0.02, Y0, clampf(zz, z_a - 0.12, z_b + 0.12)), 0.0, Vector3(0.16, 2.5 / 4.55, 0.2), PIL)
		_run(b, "SM_Bld_Wall_Large_Cap_01", Vector3(xf - sd * 0.12, Y0 + 2.48, z_b + 0.2) if sd > 0 else Vector3(xf - sd * 0.12, Y0 + 2.48, z_a - 0.2), Vector3(0, 0, -1) if sd > 0 else Vector3(0, 0, 1), L, 5.02, 0.4, 0.4, {}, 2.2)
		var kr := (x1 + 0.1 - ccx + 0.25) / 7.5
		var eave := Y0 + 2.15
		if sd > 0:
			_p(b, "SM_Bld_Roof_Straight_Thin_Large_01", Vector3(ccx - 0.25, eave, z_a - 0.25), -PI / 2, Vector3((z_b - z_a + 0.5) / 7.5, kr, kr))
		else:
			_p(b, "SM_Bld_Roof_Straight_Thin_Large_01", Vector3(-ccx + 0.25, eave, z_b + 0.25), PI / 2, Vector3((z_b - z_a + 0.5) / 7.5, kr, kr))
		_p(b, "SM_Prop_Seat_Bench_03", Vector3(sd * (x1 - 0.48), Y0, (z_a + z_b) * 0.5), -sd * PI / 2, Vector3.ONE * 0.48)
		# статуи у углов бассейна, пальмы, цветы
		_statue(b, Vector3(sd * (float(po[1]) + 0.42), Y0, float(po[3]) + 0.3), 0.0, "SM_Prop_Statue_0%d" % (3 if sd < 0 else 5), 0.42)
		_u(b, "SM_Env_Tree_Palm_0%d" % (3 if sd < 0 else 1), Vector3(sd * (ccx - 0.7), Y0, z_a + 0.1), b.rng.randf() * TAU, 0.25)
		_pot(b, Vector3(sd * 1.6, Y0, float(po[2]) - 0.4), 0.32)
	# передняя стенка и пропилей
	var gw := 2.3
	for sd: float in [-1.0, 1.0]:
		var xa := sd * gw * 0.5
		var xb := sd * (x1 - 0.12)
		var lo := minf(xa, xb)
		var hi := maxf(xa, xb)
		_run(b, "SM_Bld_Wall_Large_01", Vector3(lo, Y0 - 0.3, FZ - 0.34 * 0.3), Vector3(1, 0, 0), hi - lo, 5.0, 1.4 / 4.51, 0.3, WARM_STONE, 2.2)
		_run(b, "SM_Bld_Wall_Large_Cap_01", Vector3(lo, Y0 + 1.05, FZ - 0.1), Vector3(1, 0, 0), hi - lo, 5.02, 0.5, 0.4, {}, 2.2)
		_pot(b, Vector3(sd * (gw * 0.5 + 1.5), Y0 + 1.15, FZ - 0.1), 0.24)
		# стенка двора не глухая: медальоны, плющ, мраморный цоколь
		_u(b, "SM_Bld_Ornament_02", Vector3(sd * (gw * 0.5 + 0.75), Y0 + 0.62, FZ + 0.02), 0.0, 0.34)
		_u(b, "SM_Bld_Ornament_02", Vector3(sd * (gw * 0.5 + 2.4), Y0 + 0.62, FZ + 0.02), 0.0, 0.34)
		_ivy(b, Vector3(sd * (x1 - 0.55), Y0 + 0.55, FZ + 0.02), 0.0, 2 + int(sd), 0.5)
		_run(b, "SM_Bld_Trim_05", Vector3(lo, Y0, FZ + 0.01), Vector3(1, 0, 0), hi - lo, 2.5, 0.42, 0.45, MARBLE, 2.2)
	var syd := 2.4 / 3.01
	_p(b, "SM_Bld_Wall_Door_Large_01", Vector3(-gw * 0.5, Y0, FZ - 0.3 * 0.5), 0.0, Vector3(gw / 2.5, syd, 0.5), WHITE_WALL)
	var lw := 1.2 * (gw / 2.5) * 0.5
	var ls := Vector3(lw / 0.56, 2.45 * syd / 2.47, 0.8)
	_p(b, "SM_Bld_Door_Large_Half_03", Vector3(-gw * 0.5 + 0.65 * gw / 2.5, Y0, FZ - 0.05), 0.0, ls)
	_p(b, "SM_Bld_Door_Large_Half_03", Vector3(-gw * 0.5 + 0.65 * gw / 2.5 + lw, Y0, FZ - 0.05), 0.0, ls)
	var pz := FZ + 0.05
	for sd: float in [-1.0, 1.0]:
		_p(b, "SM_Bld_Pillar_02", Vector3(sd * 1.35, Y0, pz), 0.0, Vector3(0.6, 0.83, 0.6))
	NewCivic._ledge(b, -1.65, 1.65, FZ - 0.35, pz + 0.18, Y0 + 2.49, 0.24)
	var pr := NewCivic._gable_z(b, -1.7, 1.7, FZ - 0.4, pz + 0.2, Y0 + 2.73, TYMPANUM, true, true)
	_u(b, "SM_Bld_Ornament_02", Vector3(0, Y0 + 2.73 + (pr - Y0 - 2.73) * 0.4, pz + 0.17), 0.0, 0.32)
	_u(b, "SM_Prop_Statue_04", Vector3(0, pr - 0.08, pz + 0.12), 0.0, 0.22, GOLD_STATUE)
	_bowl(b, Vector3(-1.85, Y0, float(pv[3]) - 0.12), 0.28)
	_bowl(b, Vector3(1.85, Y0, float(pv[3]) - 0.12), 0.28)
	# топка у задней стены: печь, поленья, дым
	b.free_parts[b.parts.size()] = true
	_u(b, "SM_Prop_Kiln_01", Vector3(2.9, Y0, BZ0 - 0.02), PI, 0.42)
	b.smoke.append(b.base * Vector3(2.9, 1.4, BZ0 - 0.08))
	for k in 2:
		b.free_parts[b.parts.size()] = true
		_p(b, "SM_Prop_Beam_01", Vector3(2.1, Y0 + 0.04 + k * 0.08, BZ0 - 0.1 + k * 0.03), PI / 2 + 0.05 * k, Vector3.ONE * 0.28)
	# люди при деле: служитель у входа, банщик с полотенцами у бассейна
	b.actor(Vector3(0.85, Y0, FZ + 0.3), 0.0, "Idle", "pleb")
	_u(b, "SM_Prop_Rug_Folded_03", Vector3(float(po[1]) - 0.35, Y0 + 0.003, float(po[3]) + 0.38), 0.0, 0.42)
	b.actor(Vector3(float(po[1]) - 0.35, Y0, float(po[3]) + 0.7), PI, "Interact", "any")
	return Vector3(0, 0, float(d["zd"]))


## Купальщики (Spectacle «bath»): в каждом бассейне — по грудь в воде; путь — с улицы через пропилей во двор,
## к своему бассейну (во внутренний — мимо открытого бассейна, через большую арку зала), у края — вниз в воду
static func seats(sp, lay: Dictionary, b: Dictionary, _tris) -> void:
	if String(b["type"]) != "baths":
		return
	var old := SizeLadder.old_lot(b) and SizeLadder.OLD_LOT.has("baths")
	var d := _baths_dims(old)
	var seats_a: Array = lay["seats"]
	var wy: float = d["wy"]
	var FZ: float = d["FZ"]
	var BZ1: float = d["BZ1"]
	var zd: float = d["zd"]
	var po: Array = (d["pools"] as Array)[0]
	if not lay.has("fx"):
		lay["fx"] = []
	var list := []
	for pl: Array in d["pools"]:
		var x0: float = pl[0]
		var x1: float = pl[1]
		var z0: float = pl[2]
		var z1: float = pl[3]
		var inner := String(pl[4]) == "in"
		var sx := x1 - x0
		var sz := z1 - z0
		var c := Vector3((x0 + x1) * 0.5, 0, (z0 + z1) * 0.5)
		(lay["fx"] as Array).append(["steam", Vector3(c.x, wy + 0.05, c.z), Vector3(sx, 0, sz)])
		var nx := maxi(1, int(floor((sx - 0.5) / 0.5)))
		var nz := maxi(1, int(floor((sz - 0.5) / 0.55)))
		for i in nx:
			for j in nz:
				var w := Vector3(x0 + 0.25 + (i + 0.5) * (sx - 0.5) / nx, 0, z0 + 0.25 + (j + 0.5) * (sz - 0.5) / nz)
				var root := Vector3(w.x, wy - Spectacle.BATH_DEPTH, w.z)
				var path := PackedVector3Array([Vector3(0, 0, zd), Vector3(0, Y0, FZ + 0.1), Vector3(0, Y0, FZ - 0.5)])
				var side := -1.0 if w.x < 0.0 else 1.0
				if inner:
					path.append(Vector3(side * (float(po[1]) + 0.75), Y0, float(po[3]) + 0.35))
					path.append(Vector3(side * (float(po[1]) + 0.75), Y0, float(po[2]) - 0.4))
					path.append(Vector3(side * 0.8, Y0, BZ1 + 0.3))
					path.append(Vector3(side * 0.8, Y0, BZ1 - 0.4))
				path.append(Vector3(w.x, Y0, z1 + 0.3))
				path.append(Vector3(w.x, wy - Spectacle.BATH_DEPTH * 0.5, z1 - 0.25))
				path.append(root)
				var yaw: float = atan2(c.x - w.x + 0.01, c.z - w.z) + sp.rng.randf_range(-0.6, 0.6)
				list.append({"root": root, "yaw": yaw, "row": 0, "path": path, "far": sp.rng.randf(), "pose": "bath"})
	list.sort_custom(func(a, bb): return a["far"] < bb["far"])
	var ids := []
	for st in list:
		ids.append(seats_a.size())
		seats_a.append(st)
	lay["groups"]["bath"] = ids


# =====================================================================
#   почтовая станция
# =====================================================================

## w × d — прежний след станции (её место в городе не меняется). s — уровень города (облик растёт)
static func _center(b: Bp, w: float, d: float, s: int) -> Vector3:
	var X := w * 0.5
	var Z := d * 0.5
	_court(b, -X, X, -Z, Z)
	var g := _center_geo(X, Z, s)
	var CX: float = g["CX"]
	var BZ0: float = g["BZ0"]
	var BZ1: float = g["BZ1"]
	var SZ1: float = g["SZ1"]
	var H1 := 2.4
	var E := 0.2
	var H2 := 2.0
	var two := s >= 2
	var stone := s >= 3
	var hall := s >= 4
	var tall := s >= 6
	var hs := [H1, H2] if two else [H1]
	# ---- дом почты: охра, мраморные пилястры; внизу окна в тёплый свет и вход, наверху — со ставнями
	var o := {"wall": OCHRE_WALL, "win": OCHRE_WIN, "door_rm": NewCivic.MARBLE if s >= 3 else WARM_STONE, "shut": "#shutters_green", "frieze": s >= 3,
		"leaf": "SM_Bld_Door_Large_Half_03" if s >= 3 else "SM_Bld_Door_Large_Half_01", "statues": ["SM_Prop_Statue_05", "SM_Prop_Statue_07", "SM_Prop_Statue_03"]}
	var up_front := ["S", "W", "S"] if s >= 5 else ["S", "S", "S"]
	var sides := {0: [["G", "D", "G"]], 2: [["G", "N", "G"]], 1: [["G", "G"]], 3: [["G", "G"]]}
	if stone:
		sides[1] = [["", ""]]
	if hall:
		sides[3] = [["", ""]]
	if two:
		(sides[0] as Array).append(up_front)
		(sides[2] as Array).append(["S", "S", "S"])
		(sides[1] as Array).append(["S", "S"])
		(sides[3] as Array).append(["S", "S"])
	var top := _block(b, -CX, CX, BZ0, BZ1, Y0, hs, E, sides, o)
	var mw := 2.0 * CX / 3.0
	var kx := mw / 2.5
	# сени за дверью: тёплая комната — стойка почты со свитками, светильник
	var rz1 := BZ1 - 0.6
	var rd := minf(1.6, rz1 - BZ0 - 0.4)
	NewGrand._room(b, -mw * 0.5 + 0.08, mw * 0.5 - 0.08, rz1 - rd, rz1, Y0, H1 - 0.06, 0.0, 0.6 * kx, 2.45 * H1 / 3.01, RED_LO, NewCivic.OCHRE_GLOW)
	_u(b, "SM_Prop_Table_02", Vector3(0, Y0, rz1 - rd + 0.42), 0.0, 0.55, {"glow": WARM * 0.4})
	_u(b, "SM_Prop_Scroll_Pile_03", Vector3(-0.15, Y0 + 0.46, rz1 - rd + 0.42), 0.4, 0.38, {"glow": WARM * 0.4})
	_u(b, "SM_Prop_Senser_01", Vector3(mw * 0.5 - 0.28, Y0, rz1 - 0.3), 0.0, 0.45, {"glow": WARM * 0.6})
	# кровля дома: черепица, конёк вдоль фасада, щипцы в цвет стен; с 6 уровня — колоколенка на коньке
	var ridge := _gable_x(b, -CX - 0.18, CX + 0.18, BZ0 - 0.22, BZ1 + 0.22, top, 1.3 if two else 1.5, ORANGE_TYM, [not hall, not stone])
	if tall:
		_belfry(b, Vector3(0, ridge - 0.12, (BZ0 + BZ1) * 0.5), s)
	else:
		for sd: float in [-1.0, 1.0]:
			_u(b, "SM_Bld_Roof_Topper_0%d" % (3 if s < 5 else 5), Vector3(sd * (CX - 0.1), ridge - 0.04, (BZ0 + BZ1) * 0.5), 0.0, 0.62)
	# знамёна и медальон на фасаде
	if two:
		for sd: float in [-1.0, 1.0]:
			_u(b, "SM_Prop_Banner_03_%s" % ["A", "C", "E", "G"][s % 4], Vector3(sd * (CX - 0.12), top - 0.1, BZ1 + 0.03), 0.0, 0.48)
	if s >= 5:
		_u(b, "SM_Bld_Ornament_04", Vector3(0, top - 0.75, BZ1 + 0.05), 0.0, 0.62, GOLD_RELIEF if s >= 7 else {})
	# ---- вход: козырёк (хутор), портик с террасой (3–4), белый портик с фронтоном (с 5)
	_center_porch(b, g, s, H1)
	# ---- конюшня справа: навес на столбах (до 3), потом каменная с арками ворот, с 6 — с сеновалом
	_center_stable(b, g, s, H1)
	# ---- слева: двор с перголой (до 4), потом зал ожидания
	_center_hall(b, g, s, H1, H2)
	# ---- двор перед станцией: повозка, доска объявлений, верстовой столб, багаж
	_cart(b, Vector3(-X + 1.35, Y0, Z - 0.98), PI - 0.1, 0.72, 2 if s % 2 == 0 else 3)
	_notice(b, Vector3(X - 0.55, Y0, Z - 0.3), -0.3, 0.62)
	_p(b, "SM_Prop_Plinth_02", Vector3(-X + 0.35, Y0, BZ1 + 0.35), 0.0, Vector3.ONE * 0.62)
	_u(b, "SM_Prop_Pillar_Top_01", Vector3(-X + 0.35, Y0 + 0.62, BZ1 + 0.35), 0.0, 0.3)
	_luggage(b, Vector3(1.05, Y0, BZ1 + 0.42), 0.0, 0.62)
	if s >= 2:
		_luggage(b, Vector3(-1.2, Y0, BZ1 + 0.4), PI * 0.05, 0.55)
	if s >= 4:
		# львы у входа, ближе к средним колоннам
		for sd: float in [-1.0, 1.0]:
			_p(b, "SM_Prop_Plinth_04", Vector3(sd * 1.55, Y0, Z - 0.42), 0.0, Vector3(0.5, 0.32, 0.7))
			_u(b, "SM_Prop_Statue_Lion_01", Vector3(sd * 1.55, Y0 + 0.22, Z - 0.48), -sd * 0.2, 0.2, GOLD_STATUE if s >= 7 else {})
	if s >= 5:
		for sd: float in [-1.0, 1.0]:
			_p(b, "SM_Prop_Plinth_04", Vector3(sd * 2.45, Y0, Z - 0.35), 0.0, Vector3(0.42, 0.55, 0.42))
			_bowl(b, Vector3(sd * 2.45, Y0 + 0.37, Z - 0.35), 0.28)
	if s >= 1:
		_pot(b, Vector3(-CX + 0.25, Y0, BZ1 + 0.25), 0.24)
		_pot(b, Vector3(CX - 0.25, Y0, BZ1 + 0.25), 0.24)
	# огни ночью: у входа и у конюшни
	b.light(Vector3(0, 1.7, BZ1 + 0.8))
	if s >= 3:
		b.light(Vector3(X - 1.3, 1.5, SZ1 + 0.6))
	# люди при деле: почтарь у двери, конюх у поилки, страж у портика
	b.actor(Vector3(0.75, Y0, BZ1 + 0.95), 0.4, "Idle", "any")
	if s >= 1:
		b.actor(Vector3(CX + 0.75, Y0, SZ1 + 0.7) if stone else Vector3(CX + 0.6, Y0, BZ1 + 0.4), PI * 0.8, "Interact", "pleb")
	if s >= 2:
		b.actor(Vector3(-1.75, Y0, BZ1 + 1.15), 0.0, "Sword_Idle", "soldier")
	return Vector3(0, 0, Z + 0.35)


## Размеры станции (одни и те же для сборки и лошадей)
static func _center_geo(X: float, Z: float, _s: int) -> Dictionary:
	var m := 0.25
	var BZ0 := -Z + m
	var BZ1 := Z - 2.35
	return {"m": m, "CX": 1.95, "BZ0": BZ0, "BZ1": BZ1, "SZ1": BZ1 - 0.3, "X": X, "Z": Z}


## Колоколенка на коньке: каменная тумба, четыре тонкие колонны, бронзовый колокол, малый свинцовый купол
## (верх — около 6,3 м: храм Юпитера с коньком 6,8 м остаётся выше)
static func _belfry(b: Bp, p: Vector3, s: int) -> void:
	_p(b, "SM_Prop_Plinth_02", p, 0.0, Vector3(0.6, 0.18, 0.6))
	var y := p.y + 0.13
	var colh := 0.45
	for c: Vector2 in [Vector2(-0.2, -0.2), Vector2(0.2, -0.2), Vector2(-0.2, 0.2), Vector2(0.2, 0.2)]:
		_p(b, "SM_Bld_Pillar_06", Vector3(p.x + c.x, y, p.z + c.y), 0.0, Vector3(0.18, colh / 3.0, 0.18))
	_u(b, "SM_Prop_Senser_03", Vector3(p.x, y + 0.06, p.z), 0.0, 0.26, BRONZE_STATUE if s < 7 else GOLD_STATUE)
	var ky := 0.1
	_p(b, "SM_Prop_Pergola_01", Vector3(p.x, y + colh - 3.6 * ky, p.z), 0.0, Vector3(0.115, ky, 0.115), DOME)


## Вход станции: козырёк (до 3), портик с террасой и балюстрадой (3–4), белый портик с фронтоном (с 5)
static func _center_porch(b: Bp, g: Dictionary, s: int, H1: float) -> void:
	var BZ1: float = g["BZ1"]
	var CX: float = g["CX"]
	if s < 3:
		_u(b, "SM_Prop_Overhang_01", Vector3(0, 2.38, BZ1 + 0.12), 0.0, 0.85)
		_u(b, "#wall_lamp", Vector3(-0.85, 2.05, BZ1 + 0.02), 0.0, 1.0)
		if s >= 1:
			for i in 2:
				_u(b, "SM_Prop_FlowerPot_Hanging_0%d" % (4 + i), Vector3(-1.4 + i * 2.8, 2.15, BZ1 + 0.12), 0.0, 0.5)
		return
	var cz := BZ1 + 1.25
	var colx := [-CX + 0.3, -0.62, 0.62, CX - 0.3]
	NewCivic._floor(b, PORCH, -CX, BZ1, CX, cz + 0.3, Y0 + 0.004, 1.6)
	if s < 5:
		for x: float in colx:
			_p(b, "SM_Bld_Pillar_02", Vector3(x, Y0, cz), 0.0, Vector3(0.62, H1 / 3.0 * 0.95, 0.62))
		for sd: float in [-1.0, 1.0]:
			_ivy(b, Vector3(sd * (CX - 0.3), Y0 + 0.9, cz + 0.12), 0.0, 3 + int(sd), 0.4)
		NewCivic._ledge(b, -CX - 0.06, CX + 0.06, BZ1 - 0.05, cz + 0.3, Y0 + H1 * 0.95 + 0.02, 0.2)
		var yt := Y0 + H1 * 0.95 + 0.22
		_ring(b, "SM_Bld_Wall_Tiny_01", -CX + 0.04, CX - 0.04, BZ1 + 0.1, cz + 0.26, yt, 2.5, 1.0, 1.0, WHITE_WALL, [0, 1, 3], 1.6)
		for i in 3:
			_u(b, "SM_Prop_Drapery_0%d" % (1 + i), Vector3((float(colx[i]) + float(colx[i + 1])) * 0.5, Y0 + H1 * 0.95 - 0.02, cz + 0.06), 0.0, 0.6)
		for sd: float in [-1.0, 1.0]:
			_pot(b, Vector3(sd * (CX - 0.3), yt + 0.28, cz + 0.05), 0.22)
		return
	# белый портик: колонны на постаментах, антаблемент с фризом, фронтон с синим тимпаном и золотым рельефом
	for x: float in colx:
		_p(b, "SM_Prop_Plinth_04", Vector3(x, Y0, cz), 0.0, Vector3(0.46, 0.4, 0.46))
		_p(b, "SM_Bld_Pillar_04", Vector3(x, Y0 + 0.27, cz), 0.0, Vector3(0.52, (H1 - 0.27) / 3.0, 0.52))
	NewCivic._ledge(b, -CX - 0.1, CX + 0.1, BZ1 - 0.05, cz + 0.34, Y0 + H1, 0.24)
	_run(b, "SM_Bld_Trim_Large_Single_02", Vector3(-CX - 0.08, Y0 + H1 + 0.02, cz + 0.35), Vector3(1, 0, 0), 2.0 * CX + 0.16, 2.5, 0.3, 0.5, FRIEZE, 1.6)
	var yp := Y0 + H1 + 0.26
	var pr := _gable_z(b, 0.0, CX + 0.12, BZ1 - 0.1, cz + 0.4, yp, 1.0, TYMPANUM, [true, false])
	NewGrand._relief(b, CX + 0.12, yp, pr, cz + 0.37, 0.0, false, "SM_Prop_Symbol_05")
	if s >= 6:
		NewGrand._acro(b, CX + 0.12, yp, pr, cz + 0.4, 0.0, "SM_Prop_Statue_04", 0.22, GOLD_STATUE if s >= 7 else {})
	for i in 3:
		_u(b, "SM_Prop_Drapery_0%d" % (1 + i), Vector3((float(colx[i]) + float(colx[i + 1])) * 0.5, Y0 + H1 - 0.02, cz + 0.06), 0.0, 0.6)
	for sd: float in [-1.0, 1.0]:
		_ivy(b, Vector3(sd * (CX - 0.3), Y0 + 0.9, cz + 0.12), 0.0, 3 + int(sd), 0.42)
		_p(b, "SM_Prop_Seat_Bench_03", Vector3(sd * 1.3, Y0, BZ1 + 0.3), 0.0, Vector3.ONE * 0.42)
	CatShops._hanging_lamp(b, Vector3(0, Y0 + H1 - 0.02, (BZ1 + cz) * 0.5 + 0.1), 0.42, false)


## Конюшня станции (справа): навес на столбах с сеном и поилкой (до 3), потом каменная с арками ворот, с 6 — с сеновалом
static func _center_stable(b: Bp, g: Dictionary, s: int, H1: float) -> void:
	var X: float = g["X"]
	var m: float = g["m"]
	var CX: float = g["CX"]
	var BZ0: float = g["BZ0"]
	var SZ1: float = g["SZ1"]
	var x1 := X - m
	if s < 3:
		var ye := Y0 + 1.85
		_run(b, "SM_Bld_Wall_Large_01", Vector3(x1, Y0 - 0.3, BZ0 + 0.17), Vector3(-1, 0, 0), x1 - CX, 5.0, 1.35 / 4.51, 0.34, WARM_STONE, 2.0)
		_run(b, "SM_Bld_Wall_Large_Cap_01", Vector3(x1 + 0.03, Y0 + 1.03, BZ0 + 0.17), Vector3(-1, 0, 0), x1 - CX, 5.02, 0.4, 0.45, {}, 2.0)
		_ivy(b, Vector3((CX + x1) * 0.5 + 0.3, Y0 + 0.55, BZ0 - 0.01), PI, 1, 0.5)
		_ivy(b, Vector3(x1 - 0.35, Y0 + 0.5, BZ0 - 0.01), PI, 4, 0.42)
		for c: Vector3 in [Vector3(x1 - 0.12, Y0, SZ1 - 0.1), Vector3(CX + 0.15, Y0, SZ1 - 0.1), Vector3(x1 - 0.12, Y0, (BZ0 + SZ1) * 0.5)]:
			_p(b, "SM_Bld_Trellis_Pillar_01", c, 0.0, Vector3(0.78, ye / 2.45, 0.78))
		_lean_x(b, CX, x1 + 0.15, BZ0 - 0.15, SZ1 + 0.2, ye, 0.85)
		_u(b, "SM_Prop_Straw_Stack_02", Vector3(x1 - 0.6, Y0, BZ0 + 0.6), 0.4, 0.55, HAY)
		_u(b, "SM_Prop_Straw_Bundle_01", Vector3(CX + 0.5, Y0, BZ0 + 0.45), 0.3, 0.85, HAY)
		_u(b, "SM_Prop_Sack_Stack_02", Vector3(x1 - 0.45, Y0, SZ1 - 0.55), PI / 2, 0.55)
		_trough(b, Vector3((CX + x1) * 0.5, Y0, SZ1 + 0.45), 0.0, 0.7)
		return
	# каменная конюшня: две арки ворот с тёплым светом сена за ними, окна по боку и сзади, черепица
	var st := {"Stucco_White_01": "Building_Large_Brick_01", "Stucco_Orange_01": "Building_Large_Brick_01", "tints": {"Building_Large_Brick_01": Color(1.0, 0.82, 0.66)}}
	var o := {"wall": st, "win": st, "frieze": false, "boxes": false, "statues": ["SM_Prop_Statue_01"], "statue_rm": BRONZE_STATUE}
	var sides := {0: [["B", "B"]], 1: [["G", "N", "G"]], 2: [["G", "G"]]}
	var hs := [H1]
	if s >= 6:
		hs = [H1, 1.6]
		(sides[0] as Array).append(["S", "S"])
		(sides[1] as Array).append(["S", "W", "S"])
		(sides[2] as Array).append(["S", "S"])
		o["shut"] = "#shutters_brown"
	var top := _block(b, CX, x1, BZ0, SZ1, Y0, hs, 0.18, sides, o)
	var ridge := _gable_x(b, CX, x1 + 0.15, BZ0 - 0.18, SZ1 + 0.18, top, 1.35, ORANGE_TYM, [false, true])
	_u(b, "SM_Bld_Roof_Topper_02", Vector3(x1 - 0.05, ridge - 0.04, (BZ0 + SZ1) * 0.5), 0.0, 0.6)
	_trough(b, Vector3(CX + 0.75, Y0, SZ1 + 0.42), 0.0, 0.7)
	_u(b, "SM_Prop_Straw_Bundle_01", Vector3(x1 - 0.35, Y0, SZ1 + 0.3), 0.5, 0.75, HAY)
	_ivy(b, Vector3(x1 + 0.03, Y0 + 1.3, BZ0 + 0.5), PI / 2, 2, 0.55)


## Слева от дома почты: двор с перголой для проезжающих (до 4), потом зал ожидания; с 6 — в два этажа
static func _center_hall(b: Bp, g: Dictionary, s: int, H1: float, H2: float) -> void:
	var X: float = g["X"]
	var m: float = g["m"]
	var CX: float = g["CX"]
	var BZ0: float = g["BZ0"]
	var SZ1: float = g["SZ1"]
	var x0 := -X + m
	if s < 4:
		if s >= 1:
			var tx := (x0 - CX) * 0.5
			var tz := SZ1 - 1.0
			for c: Vector3 in [Vector3(tx - 0.95, Y0, tz - 0.8), Vector3(tx + 0.95, Y0, tz - 0.8), Vector3(tx - 0.95, Y0, tz + 0.8), Vector3(tx + 0.95, Y0, tz + 0.8)]:
				_p(b, "SM_Bld_Trellis_Pillar_01", c, 0.0, Vector3(0.66, 0.9, 0.66))
			_p(b, "SM_Bld_Trellis_Roof_01", Vector3(tx + 1.2, Y0 + 2.2, tz - 1.0), 0.0, Vector3(0.96, 0.9, 0.8))
			b.parts.append(["SM_Env_Vine_0%d" % (1 + b.rng.randi() % 2), b.base * Transform3D(Basis(Vector3.RIGHT, -PI / 2).scaled(Vector3(0.85, 0.85, 0.85)), Vector3(tx, Y0 + 2.42, tz + 0.75)), {}])
			_u(b, "SM_Prop_Table_04", Vector3(tx, Y0, tz), 0.0, 0.66)
			for sd: float in [-1.0, 1.0]:
				_u(b, "SM_Prop_Seat_Stool_02", Vector3(tx + sd * 0.6, Y0, tz), 0.0, 0.78)
			_u(b, "SM_Prop_Jug_02", Vector3(tx - 0.1, Y0 + 0.48, tz), 0.0, 0.5)
			_u(b, "SM_Prop_Bowl_04", Vector3(tx + 0.15, Y0 + 0.48, tz - 0.05), 0.0, 0.55)
			_bush(b, Vector3(x0 + 0.3, Y0, BZ0 + 0.35), 0.34)
		else:
			_u(b, "SM_Prop_Vase_Pile_02", Vector3(x0 + 0.6, Y0, BZ0 + 0.6), 0.6, 0.6)
			_u(b, "SM_Prop_Sack_Stack_01", Vector3(x0 + 0.6, Y0, BZ0 + 1.6), 0.2, 0.6)
		_cypress(b, Vector3(x0 + 0.2, Y0, BZ0 + 0.2), 0.34)
		return
	var o := {"wall": OCHRE_WALL, "win": OCHRE_WIN, "shut": "#shutters_green", "frieze": s >= 5, "statues": ["SM_Prop_Statue_06", "SM_Prop_Statue_03"]}
	var sides := {0: [["G", "G"]], 3: [["G", "N", "G"]], 2: [["G", "G"]]}
	var hs := [H1]
	if s >= 6:
		hs = [H1, H2]
		(sides[0] as Array).append(["S", "S"])
		(sides[3] as Array).append(["S", "S", "S"])
		(sides[2] as Array).append(["S", "S"])
	var top := _block(b, x0, -CX, BZ0, SZ1, Y0, hs, 0.2, sides, o)
	var ridge := _gable_x(b, x0 - 0.15, -CX, BZ0 - 0.18, SZ1 + 0.18, top, 1.35, ORANGE_TYM, [true, false])
	_u(b, "SM_Bld_Roof_Topper_03", Vector3(x0 + 0.1, ridge - 0.04, (BZ0 + SZ1) * 0.5), 0.0, 0.6)
	_ivy(b, Vector3(x0 - 0.03, Y0 + 1.2, SZ1 - 0.5), -PI / 2, 1, 0.55)
	_p(b, "SM_Prop_Seat_Bench_01", Vector3((x0 - CX) * 0.5, Y0, SZ1 + 0.3), 0.0, Vector3.ONE * 0.62)
	_u(b, "SM_Prop_Banner_03_%s" % ["B", "D", "F", "H"][s % 4], Vector3((x0 - CX) * 0.5, top - 0.1, SZ1 + 0.03), 0.0, 0.45)


## Лошади станции: под навесом (до 3), потом у поилки перед каменной конюшней
static func _center_pets(X: float, Z: float, c: Vector3, K: float, s: int) -> Array:
	var g := _center_geo(X, Z, s)
	var CX: float = g["CX"]
	var x1 := X - float(g["m"])
	var SZ1: float = g["SZ1"]
	var BZ0: float = g["BZ0"]
	if s < 3:
		return [["horse", (c + Vector3((CX + x1) * 0.5, 0, (BZ0 + SZ1) * 0.5 + 0.1)) / K, PI / 2, "Idle", HORSE_K, -1]]
	return [["horse", (c + Vector3(CX + 1.55, 0, SZ1 + 0.75)) / K, -PI / 2 + 0.3, "Eating", HORSE_K, -1]]
