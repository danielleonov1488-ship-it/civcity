class_name NewSmall
extends RefCounted
## Новые пост вигилов, школа, малые бани, склад и скрипторий (владелец 13.11: «пересобрать модельки» — новые здания из
## деталей Synty POLYGON Ancient Empire, а не украшенные прежние; «темноты вообще не должно быть»; у каждого здания своё
## основание; размеры — по утверждённой линейке SizeLadder, мерка — дом плебеев 2,8 × 4 м ≈ 11 м²). Собраны с нуля
## в метрах города (base делит на масштаб Catalog, тот потом умножает обратно), фасад к +Z, вход — b.door.
##  - пост вигилов (≈ 16 м², «малые», было 12 м² узкой полосой): караульня с широкими воротами (Life) в тёплое депо
##    с вёдрами, крюками и лестницами; рядом — каменная дозорная вышка с огнём в жаровне под черепичной крышей;
##    перед ними — каменный водоём со львиной головой, водовозка-сифон с бочкой, лестницы, вёдра, топоры;
##  - школа (≈ 39 м², «средние», в прежнем следе): двухэтажный дом грамматика (фасад А — длинная кровля вдоль улицы,
##    окна с цветами, фасад Б — большой фронтон к улице и ниша с Минервой), перед ним — двор под перголой
##    с виноградом (А) или под цветными тентами (Б): скамьи учеников (Spectacle), кресло учителя, солнечные часы;
##  - малые бани (≈ 36 м², было 31): зал с куполом на барабане, окна в тёплые комнаты, вход — портик с фронтоном
##    и бронзовыми дверями (Life); перед залом — открытый бассейн со львиной головой и фреской, скамья с полотенцами,
##    пальма, цветник, статуя;
##  - склад (≈ 36 м², было 31): кирпичный амбар-горрей с оштукатуренным чердаком, широкие ворота (Life) в тёплый зал
##    с полками и мешками, чердачная дверь с балкой-подъёмником и мешком, навес с амфорами сбоку; во дворе — товар,
##    повозка, грузчик на мешках у ворот (место работника, как прежде);
##  - скрипторий (≈ 16 м², «малые», было 14): узкий дом в два этажа (А — фронтон к улице, открытая лавка со свитками
##    под тентом и писцом за столом, Б — кровля вдоль улицы, окно со ставнями, козырёк над дверью).
## У каждого — мощёное основание по всему следу с бордюром, уходящим в землю (City.apron_of = 0); за каждой дверью и
## окном — освещённая комната (тёплое свечение материала, remap «glow»), закрытые створки или открытый двор. Стены —
## цветная штукатурка города (цвет постройки, Bp.paint) с белыми пилястрами, поясами и карнизами; у склада низ — кирпич.
## Фасад (А/Б) выбирает цвет постройки (FV) и variant: одинаковые здания в городе не повторяют друг друга.
## Постройка старого сохранения (Catalog.fit, SizeLadder.old_lot) собирается под свои прежние клетки (OLD_RECT) — то же
## здание, только уже и мельче; City.ladder_grow выращивает её в полный размер, где есть место. Школа — в прежнем следе.
## Прежние сборки (CatExtra, CatCivic) остаются: ON — выключатели по типу (снимки «было/стало»); CIVCITY_NEWSMALL=0 —
## прежние во всей игре.

static var ON := {"vigiles": true, "school": true, "balnea": true, "warehouse": true, "scriptorium": true} \
	if OS.get_environment("CIVCITY_NEWSMALL") != "0" \
	else {"vigiles": false, "school": false, "balnea": false, "warehouse": false, "scriptorium": false}
const TYPES := ["vigiles", "school", "balnea", "warehouse", "scriptorium"]

## Полный след (м, ширина × глубина при yaw 0), середина следа — начало координат. Школы здесь нет: она — в прежнем следе
const FULL := {"vigiles": Vector2(4.6, 3.5), "balnea": Vector2(6.6, 5.5), "warehouse": Vector2(7.0, 5.2), "scriptorium": Vector2(3.8, 4.2)}
## Прежний след в осях постройки (замер test_b4_probe mode=lots по прежним сборкам): x0, x1, z0, z1
const OLD_RECT := {"vigiles": [-2.78, 2.5, -1.99, 0.31], "school": [-3.24, 3.22, -3.69, 2.28], "balnea": [-3.19, 3.49, -2.78, 1.86],
	"warehouse": [-2.78, 3.99, -3.39, 1.14], "scriptorium": [-1.88, 1.88, -1.88, 1.72]}
## Фасад по цвету постройки (палитра Defs.PALETTE — 10 цветов): соседние копии одного типа — разными фасадами
const FV := [1, 1, 1, 0, 0, 1, 0, 1, 0, 1]

const Y0 := 0.06                  # верх мощёного основания
const WARM := Color(0.3, 0.18, 0.09)
const RED_GLOW := {"Stucco_White_01": "Stucco_Red_01", "glow": WARM * 0.9}
const OCHRE_GLOW := {"Stucco_White_01": "Stucco_Orange_01", "glow": WARM}
const PAVING := {"Stone_01": "Floor_Tiles_06"}
const MOSAIC := {"Stone_01": "Floor_Tiles_Circle_01"}
const WOOD := {"Stone_01": "Wood_02"}
const MARBLE := {"Stucco_White_01": "Building_Marble_01"}
const PIL := {"Building_Large_Brick_01": "Building_Marble_01"}
const FRIEZE := {"Stucco_Blue_01": "Building_Marble_03"}
const TYMPANUM := {"Stone_01": "Stucco_Blue_01", "tints": {"Stucco_Blue_01": Color(0.78, 0.87, 1.0)}}
const TYM_RED := {"Stone_01": "Stucco_Red_01"}
const STONE := {"Stucco_White_01": "Building_Large_Brick_01", "tints": {"Building_Large_Brick_01": Color(1.0, 0.93, 0.8)}}
const DOME := {"Stucco_Blue_01": "Stucco_White_01", "tints": {"Stucco_White_01": Color(0.67, 0.66, 0.62)}}
const WHITE := {"tints": {"Stucco_White_01": Color(1.0, 0.97, 0.92)}}
const GOLD := Color(1.0, 0.78, 0.36)
const FLAME := {"tint": Color(1.0, 0.55, 0.16), "glow": Color(1.2, 0.46, 0.1)}
const LEAF_WOOD := "SM_Bld_Door_Large_Half_01"
const LEAF_BRONZE := "SM_Bld_Door_Large_Half_03"
## Лицо стены Synty (+Z) от начала координат детали и толщина детали (родные метры)
const FACE := {"SM_Bld_Wall_01": 0.11, "SM_Bld_Wall_Window_03": 0.25, "SM_Bld_Wall_Window_04": 0.25, "SM_Bld_Wall_Window_05": 0.28,
	"SM_Bld_Wall_Window_06": 0.11, "SM_Bld_Wall_Alcove_01": 0.38, "SM_Bld_Wall_Door_Large_01": 0.30, "SM_Bld_Wall_Door_Double_Large_01": 0.22,
	"SM_Bld_Wall_Door_04": 0.11}
## Модули: деталь Synty, толщина (sz), проём двери вдоль модуля и высота (родные, CatDress.DOOR)
const MOD := {"W": "SM_Bld_Wall_01", "N": "SM_Bld_Wall_Window_05", "S": "SM_Bld_Wall_Window_05", "B": "SM_Bld_Wall_Window_05",
	"M": "SM_Bld_Wall_Window_06", "T": "SM_Bld_Wall_Window_03", "H": "SM_Bld_Wall_Window_04", "A": "SM_Bld_Wall_Alcove_01",
	"D": "SM_Bld_Wall_Door_Large_01", "G": "SM_Bld_Wall_Door_Double_Large_01", "L": "SM_Bld_Wall_Door_04"}
const SZ := {"W": 1.0, "N": 0.6, "S": 0.6, "B": 0.6, "M": 1.0, "T": 0.6, "H": 0.6, "A": 0.4, "D": 0.6, "G": 0.6, "L": 1.0}
const DOOR := {"D": [0.65, 1.85, 2.6], "G": [0.3, 2.2, 2.47], "L": [0.75, 1.75, 1.97]}


static func covers(type: String) -> bool:
	return bool(ON.get(type, false))


## Прежние сборки этих типов (выключатель ON — снимки «было»)
static func old(b: Bp, type: String) -> void:
	match type:
		"vigiles": CatExtra.make(b, type)
		"school": CatCivic._school(b)
		"balnea": CatCivic._balnea(b)
		"warehouse": CatCivic._warehouse(b)
		"scriptorium": CatCivic._scriptorium(b)


static func build(b: Bp, type: String, variant := 0, color := 0) -> void:
	var K := Catalog.scale_of(type)
	b.base = Transform3D(Basis.from_scale(Vector3.ONE / K), Vector3.ZERO)
	var fv := (int(FV[posmod(color, FV.size())]) + variant) % 2
	var fr := frame(type, Catalog.fit)
	var x := _ctx(b, fv)
	x["c"] = color
	var door := Vector3.ZERO
	match type:
		"vigiles": door = _vigiles(b, fr, x)
		"school": door = _school(b, fr, x)
		"balnea": door = _balnea(b, fr, x)
		"warehouse": door = _warehouse(b, fr, x)
		"scriptorium": door = _scriptorium(b, fr, x)
	b.base = Transform3D.IDENTITY
	b.door = door / K


## След постройки (x0, x1, z0, z1): полный — по линейке (середина — начало координат); старое место — прежние клетки
static func frame(type: String, fit: Vector2) -> Array:
	if type == "school" or fit != Vector2.ZERO:
		var o: Array = OLD_RECT[type]
		return [float(o[0]) + 0.02, float(o[1]) - 0.02, float(o[2]) + 0.02, float(o[3]) - 0.02]   # бордюр — в прежних клетках
	var f: Vector2 = FULL[type]
	return [-f.x * 0.5, f.x * 0.5, -f.y * 0.5, f.y * 0.5]


## Раскраски этой постройки: штукатурка её цвета (оттенок у экземпляра — одна группа деталей на все цвета города)
static func _ctx(b: Bp, fv: int) -> Dictionary:
	var t := b.tint
	return {"fv": fv, "t": t,
		"st": {"tints": {"Stucco_White_01": t}},
		# окно Synty: рама — белый мрамор, стена — штукатурка цвета постройки
		"win": {"Stucco_White_01": "Building_Marble_01", "Stucco_Orange_01": "Stucco_White_01", "tints": {"Stucco_White_01": t}},
		# стены дверей и ниш (кирпич Synty) — штукатурка цвета постройки
		"door": {"Building_Large_Brick_01": "Stucco_White_01", "tints": {"Building_Large_Brick_01": t}},
		"leaf": LEAF_WOOD, "shut": "#shutters_green", "statue": 0}


# =====================================================================
#   помощники (метры города, фасад к +Z)
# =====================================================================

static func _p(b: Bp, name: String, p: Vector3, yaw := 0.0, s := Vector3.ONE, rm := {}) -> void:
	b.parts.append([name, b.base * Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(s), p), rm])


static func _u(b: Bp, name: String, p: Vector3, yaw: float, s: float, rm := {}) -> void:
	_p(b, name, p, yaw, Vector3.ONE * s, rm)


## Точка на контуре прямоугольника r = [x0, x1, z0, z1]: сторона (0 перед +Z, 1 право +X, 2 зад, 3 лево), смещение a по
## обходу (перед — слева направо, право — спереди назад, зад — справа налево, лево — сзади вперёд), out — наружу
static func _at(r: Array, side: int, a: float, out := 0.0, y := 0.0) -> Vector3:
	var x0: float = r[0]
	var x1: float = r[1]
	var z0: float = r[2]
	var z1: float = r[3]
	match side:
		0: return Vector3(x0 + a, y, z1 + out)
		1: return Vector3(x1 + out, y, z1 - a)
		2: return Vector3(x1 - a, y, z0 - out)
	return Vector3(x0 - out, y, z0 + a)


static func _yaw(side: int) -> float:
	return [0.0, PI / 2, PI, -PI / 2][side]


static func _len(r: Array, side: int) -> float:
	return (float(r[1]) - float(r[0])) if side % 2 == 0 else (float(r[3]) - float(r[2]))


## Ряд одинаковых деталей вдоль стороны (лицом наружу): кусками не длиннее seg
static func _run(b: Bp, name: String, r: Array, side: int, y: float, out: float, pw: float, sy: float, sz: float, rm := {}, seg := 1.8, a0 := 0.0, a1 := -1.0) -> void:
	var L := _len(r, side) if a1 < 0.0 else a1
	L -= a0
	var n := maxi(1, int(round(L / seg)))
	var st := L / n
	for i in n:
		_p(b, name, _at(r, side, a0 + i * st, out, y), _yaw(side), Vector3(st / pw, sy, sz), rm)


## Ярус стен по обходу прямоугольника r от высоты y высотой h. mods — {сторона: строка видов модулей} (модули поровну
## по длине стороны): W — гладкая штукатурка (на неё потом — плющ, роспись), N — окно с решёткой в тёплую комнату,
## S — оно же со ставнями (Life), B — оно же с ящиком цветов, M — малое окно, T — окно-бойница, H — высокое широкое окно,
## A — ниша со статуей, D — дверь со створками (Life), G — широкие ворота со створками (Life), L — дверь чердака,
## O — открытая лавка (прилавок, за ним — тёплая комната), «-» — ничего. rm — раскраска стен (иначе x["st"]).
## Возвращает {"W": [[сторона, начало, ширина]], "D": [...], "O": [...], "G": [...]}
static func _storey(b: Bp, r: Array, mods: Dictionary, y: float, h: float, x: Dictionary, rm_wall := {}, rm_win := {}, rm_door := {}) -> Dictionary:
	var out := {"W": [], "D": [], "O": [], "G": [], "L": []}
	var st: Dictionary = x["st"] if rm_wall.is_empty() else rm_wall
	var win: Dictionary = x["win"] if rm_win.is_empty() else rm_win
	var drm: Dictionary = x["door"] if rm_door.is_empty() else rm_door
	for side: int in mods:
		var s: String = mods[side]
		var n := s.length()
		var L := _len(r, side)
		var mw := L / n
		var k := mw / 2.5
		var sy := h / 3.01
		for i in n:
			var c := s[i]
			var a := i * mw
			if c == "-":
				continue
			if c == "O":
				_open(b, r, side, a, mw, y, h, st, x)
				out["O"].append([side, a, mw])
				continue
			var nm: String = MOD[c]
			var sz: float = SZ[c]
			var rm: Dictionary = st if c == "W" else (drm if c in ["D", "G", "A"] else win)
			_p(b, nm, _at(r, side, a, -float(FACE[nm]) * sz, y), _yaw(side), Vector3(k, sy, sz), rm)
			match c:
				"W":
					out["W"].append([side, a, mw])
				"S":
					_shutters(b, r, side, a, k, y, sy, String(x["shut"]))
				"B":
					if y < 1.0 and side != 0:
						continue                     # ящик цветов на земле у бока занял бы клетки соседа — только у фасада
					var kb := minf(0.85, 1.25 * k)
					_p(b, "#window_box", _at(r, side, a + 1.25 * k, 0.0, y + 0.62 * sy), _yaw(side), Vector3(kb, kb, 0.5))
				"A":
					var sn := "SM_Prop_Statue_0%d" % [7, 5, 3, 6][(int(x["statue"]) + i + side) % 4]
					x["statue"] = int(x["statue"]) + 1
					_u(b, sn, _at(r, side, a + 1.25 * k, -0.13, y + 0.12 * sy), _yaw(side), minf(0.46, h * 0.2))
				"D", "G", "L":
					var d: Array = DOOR[c]
					var lw := (float(d[1]) - float(d[0])) * k * 0.5
					var dh := float(d[2]) * sy * (0.94 if c == "D" else 0.99)
					var leaf: String = "SM_Bld_Door_04" if c == "L" else String(x["leaf"])
					if c == "L":
						_p(b, leaf, _at(r, side, a + float(d[0]) * k, -0.03, y), _yaw(side), Vector3(2.0 * lw / 1.0, dh / 1.96, 0.9))
					else:
						var dz := -(float(FACE[nm]) - 0.04) * sz
						var ls := Vector3(lw / 0.56, dh / 2.47, 0.7)
						_p(b, leaf, _at(r, side, a + float(d[0]) * k, dz, y), _yaw(side), ls)
						_p(b, leaf, _at(r, side, a + float(d[0]) * k + lw, dz, y), _yaw(side), ls)
					out[c].append([side, a, mw])
	return out


## Открытая лавка в модуле: простенки по краям, низкий прилавок, перемычка; за ним — тёплая комната (_hall)
static func _open(b: Bp, r: Array, side: int, a: float, mw: float, y: float, h: float, st: Dictionary, x: Dictionary) -> void:
	var pw := 0.24
	var sz := 0.7
	var f := -0.11 * sz
	var yaw := _yaw(side)
	var top := minf(h - 0.3, 1.75)
	_p(b, "SM_Bld_Wall_01", _at(r, side, a, f, y), yaw, Vector3(pw / 2.5, h / 3.01, sz), st)
	_p(b, "SM_Bld_Wall_01", _at(r, side, a + mw - pw, f, y), yaw, Vector3(pw / 2.5, h / 3.01, sz), st)
	_p(b, "SM_Bld_Wall_01", _at(r, side, a + pw, f, y + top), yaw, Vector3((mw - 2.0 * pw) / 2.5, (h - top) / 3.01, sz), st)
	# прилавок: кладка из тёсаного камня, сверху — мраморная плита
	_p(b, "SM_Bld_Wall_01", _at(r, side, a + pw, f, y), yaw, Vector3((mw - 2.0 * pw) / 2.5, 0.5 / 3.01, sz), STONE)
	_p(b, "SM_Bld_Wall_Large_Cap_01", _at(r, side, a + pw - 0.02, 0.04, y + 0.48), yaw, Vector3((mw - 2.0 * pw + 0.04) / 5.02, 0.2, 0.3))
	# белое обрамление проёма
	for e: float in [a + pw, a + mw - pw]:
		_p(b, "SM_Bld_Wall_Large_Pillar_01", _at(r, side, e, 0.02, y + 0.5), 0.0, Vector3(0.1, (top - 0.5) / 4.55, 0.1), PIL)


## Ставни (Life): две дощатые створки по бокам окна Synty (окно — середина модуля, подоконник на 0,65 родных)
static func _shutters(b: Bp, r: Array, side: int, a: float, k: float, y: float, sy: float, shut: String) -> void:
	var bs := Basis(Vector3.UP, _yaw(side))
	for e: Array in CatDressCivic._shutter_pair(shut, k, sy):
		var lx: Transform3D = e[1]
		var at := _at(r, side, a + 1.25 * k + lx.origin.x, 0.012, y + 0.7 * sy)
		b.parts.append([e[0], b.base * Transform3D(bs * lx.basis, at), e[2]])


## Пилястры из белого мрамора на углах и между модулями (mods[side] — сколько модулей на стороне)
static func _pilasters(b: Bp, r: Array, mods: Dictionary, y: float, h: float, w := 0.2) -> void:
	var s := Vector3(w / 0.92, h / 4.55, w / 0.92)
	for side: int in mods:
		var n := int(mods[side])
		var L := _len(r, side)
		for i in range(1, n):
			_p(b, "SM_Bld_Wall_Large_Pillar_01", _at(r, side, L * i / n, 0.015, y), _yaw(side), s, PIL)
	var q := w * 0.5 - 0.06
	for c: Vector2 in [Vector2(float(r[0]) + q, float(r[3]) - q), Vector2(float(r[1]) - q, float(r[3]) - q), Vector2(float(r[0]) + q, float(r[2]) + q), Vector2(float(r[1]) - q, float(r[2]) + q)]:
		_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(c.x, y, c.y), 0.0, s, PIL)


## Карниз (белая плита) по обходу прямоугольника r на высоте y, толщиной th, выносом out
static func _cornice(b: Bp, r: Array, y: float, th := 0.16, out := 0.08, sides := [0, 1, 2, 3]) -> void:
	var e := [float(r[0]) - out, float(r[1]) + out, float(r[2]) - out, float(r[3]) + out]
	NewCivic._ring(b, "SM_Bld_Wall_Large_Cap_01", e[0], e[1], e[2], e[3], y, 5.02, th / 0.36, (out * 2.0 + 0.12) / 0.9, {}, sides, 2.2)


## Расписной фриз (красное с мрамором) под карнизом
static func _frieze(b: Bp, r: Array, y: float, sides := [0, 1, 2, 3]) -> void:
	for side: int in sides:
		_run(b, "SM_Bld_Trim_Large_Single_02", r, side, y, 0.0, 2.5, 0.26, 0.45, FRIEZE, 1.8)


## Тёплая комната за проёмами: облицовка стен изнутри (низ — помпейский красный, выше — охра), мозаика и потолок —
## всё светится само (днём и ночью). r — внутренние плоскости стен; gaps — проёмы передней стены [[x0, x1], …]
static func _hall(b: Bp, r: Array, y: float, h: float, gaps := []) -> void:
	NewCivic._lining(b, r[0], r[1], r[2], r[3], y, h, gaps)
	NewCivic._floor(b, NewCivic.HALL_FLOOR, r[0], r[2], r[1], r[3], y + 0.006, 1.7)
	NewCivic._ceiling(b, r[0], r[2], r[1], r[3], y + h - 0.03)


## Проёмы передней стены (вдоль x) для _hall: двери и лавки из ответа _storey
static func _gaps(r: Array, res: Dictionary) -> Array:
	var g := []
	for c: String in ["D", "G", "O"]:
		for e: Array in res[c]:
			if int(e[0]) != 0:
				continue
			var a: float = e[1]
			var mw: float = e[2]
			if c == "O":
				g.append([float(r[0]) + a + 0.2, float(r[0]) + a + mw - 0.2])
			else:
				var d: Array = DOOR[c]
				var k := mw / 2.5
				g.append([float(r[0]) + a + float(d[0]) * k - 0.03, float(r[0]) + a + float(d[1]) * k + 0.03])
	return g


## Внутренние плоскости стен прямоугольника r (стены с окнами Synty — толщиной до ~0,32 м)
static func _inner(r: Array, inset := 0.33) -> Array:
	return [float(r[0]) + inset, float(r[1]) - inset, float(r[2]) + inset, float(r[3]) - inset]


## Плющ с цветами на гладком модуле (если он не на передней стороне — и кашпо)
static func _ivy(b: Bp, r: Array, e: Array, y: float, h: float, k := 0) -> void:
	var side: int = e[0]
	var a: float = e[1]
	var mw: float = e[2]
	var s := minf(0.62, mw / 2.4)
	_u(b, "SM_Env_Ivy_Flowers_0%d" % (1 + (k + side) % 4), _at(r, side, a + mw * 0.5, 0.03, y + h * 0.55), _yaw(side), s)


## Огонь в чаше: три язычка, средний выше
static func _fire(b: Bp, c: Vector3, s: float) -> void:
	NewCivic._fire(b, c, s)


## Горшок с цветами
static func _pot(b: Bp, p: Vector3, s := 0.28) -> void:
	_u(b, "SM_Prop_FlowerPot_Fancy_01", p + Vector3(0, 0.57 * s, 0), b.rng.randf() * TAU, s)


static func _bush(b: Bp, p: Vector3, s := 0.3) -> void:
	NewCivic._bush(b, p, s)


## Двускатная кровля: конёк вдоль X (скаты к +Z и −Z, фронтоны по бокам) или вдоль Z (фронтон к улице)
static func _roof(b: Bp, r: Array, y: float, along_z: bool, tym: Dictionary, ov := 0.14, front := true, back := true) -> float:
	if along_z:
		return NewCivic._gable_z(b, float(r[0]) - ov, float(r[1]) + ov, float(r[2]) - ov, float(r[3]) + ov + 0.05, y, tym, front, back)
	return NewCivic._gable_x(b, float(r[0]) - ov, float(r[1]) + ov, float(r[2]) - ov, float(r[3]) + ov + 0.05, y, tym)


## Низкий бортик из тёсаного камня вдоль стороны прямоугольника (по краю двора)
static func _kerb_wall(b: Bp, a: Vector3, dir: Vector3, len: float, h := 0.42) -> void:
	NewCivic._run(b, "SM_Bld_Wall_01", a, dir, len, 2.5, h / 3.01, 0.6, STONE, 1.6)
	NewCivic._run(b, "SM_Bld_Wall_Large_Cap_01", a + Vector3(0, h - 0.02, 0), dir, len, 5.02, 0.36, 0.26, {}, 1.6)


# =====================================================================
#   скрипторий
# =====================================================================

static func _scriptorium(b: Bp, fr: Array, x: Dictionary) -> Vector3:
	var fv: int = x["fv"]
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	NewCivic._base(b, x0, x1, z0, z1)
	var fs := clampf((z1 - z0) - 3.4, 0.3, 0.8)          # полоса перед домом (у старого места — узкая)
	var r := [x0 + 0.1, x1 - 0.1, z0 + 0.12, z1 - fs]
	var H1 := 2.15
	var E := 0.14
	var H2 := 1.48
	var y2 := Y0 + H1 + E
	var ytop := y2 + H2
	x["shut"] = "#shutters_blue" if fv == 0 else "#shutters_green"
	var g1 := {0: "DO" if fv == 0 else "SD", 1: "NS" if fv == 0 else "SN", 2: "NA" if fv == 0 else "AN", 3: "SN" if fv == 0 else "NS"}
	var g2 := {0: "SS" if fv == 0 else "BB", 1: "WS" if fv == 0 else "SW", 2: "SN" if fv == 0 else "NS", 3: "SW" if fv == 0 else "WS"}
	var res := _storey(b, r, g1, Y0, H1, x)
	var up := _storey(b, r, g2, y2, H2, x)
	# пояс между этажами и полоса стены за ним
	for side in 4:
		_run(b, "SM_Bld_Wall_01", r, side, Y0 + H1, -0.11 * 0.6, 2.5, E / 3.01, 0.6, x["st"], 1.8)
	_cornice(b, r, Y0 + H1 - 0.02, E + 0.02, 0.07)
	_pilasters(b, r, {0: 2, 1: 2, 2: 2, 3: 2}, Y0, ytop - Y0)
	_cornice(b, r, ytop - 0.03, 0.18, 0.1)
	for e: Array in up["W"]:
		_ivy(b, r, e, y2, H2, 1)
	# кровля: А — фронтон к улице (синий тимпан, золотой медальон), Б — конёк вдоль улицы, козырёк над дверью
	if fv == 0:
		var ridge := _roof(b, r, ytop + 0.1, true, TYMPANUM, 0.14)
		_u(b, "SM_Bld_Ornament_02", Vector3((float(r[0]) + float(r[1])) * 0.5, ytop + 0.1 + (ridge - ytop - 0.1) * 0.32, float(r[3]) + 0.16), 0.0, 0.3)
	else:
		_roof(b, r, ytop + 0.1, false, TYM_RED, 0.14)
	# нутро в тёплом свете: полки со свитками, стол писца, амфоры чернил, светильник
	var ir := _inner(r, 0.31)
	_hall(b, ir, Y0, ytop - Y0 - 0.08, _gaps(r, res))
	var ix0: float = ir[0]
	var ix1: float = ir[1]
	var iz0: float = ir[2]
	var iz1: float = ir[3]
	var shelf := {"glow": WARM * 0.45}
	var sw := minf(2.2, ix1 - ix0 - 0.2)
	_p(b, "SM_Prop_Shelf_Scroll_01", Vector3((ix0 + ix1) * 0.5, Y0, iz0 + 0.02), 0.0, Vector3(sw / 2.33, 1.55 / 2.71, 0.5), shelf)
	_p(b, "SM_Prop_Shelf_Scroll_01_Insert_0%d" % (1 + fv), Vector3((ix0 + ix1) * 0.5, Y0, iz0 + 0.02), 0.0, Vector3(sw / 2.33, 1.55 / 2.71, 0.5), shelf)
	# стол писца — у лавки (А) или у окна (Б), писец на табурете лицом к улице
	var mw := (float(r[1]) - float(r[0])) * 0.5
	var dx := float(r[0]) + mw * 1.5 if fv == 0 else float(r[0]) + mw * 0.5
	var tz := iz1 - 0.55
	_p(b, "SM_Prop_Table_05", Vector3(dx, Y0, tz), PI / 2, Vector3.ONE * 0.62, {"glow": WARM * 0.4})
	_u(b, "SM_Prop_Scroll_Pile_0%d" % [1, 3][fv], Vector3(dx - 0.18, Y0 + 0.49, tz), 0.3, 0.42, {"glow": WARM * 0.4})
	_u(b, "SM_Prop_Scroll_01", Vector3(dx + 0.16, Y0 + 0.49, tz + 0.02), 1.2, 0.55, {"glow": WARM * 0.4})
	_u(b, "SM_Prop_Seat_Stool_01", Vector3(dx, Y0, tz - 0.48), 0.0, 0.55, {"glow": WARM * 0.4})
	b.actor(Vector3(dx, Y0, tz - 0.42), 0.0, "Sitting_Idle", "pleb")
	_u(b, "SM_Prop_Vase_Pile_0%d" % [2, 5][fv], Vector3(ix1 - 0.35 if fv == 0 else ix0 + 0.35, Y0, iz0 + 0.75), 0.0, 0.3, {"glow": WARM * 0.4})
	b.light(Vector3((ix0 + ix1) * 0.5, Y0 + 1.7, (iz0 + iz1) * 0.5))
	# перед домом: А — тент над лавкой на двух столбиках, скамья у двери; Б — козырёк, вывеска, скамья под окном
	var fz := float(r[3])
	if fv == 0:
		var o: Array = res["O"][0]
		var ox0 := float(r[0]) + float(o[1])
		var ow: float = o[2]
		var dep := maxf(0.35, fs - 0.12)
		_p(b, "SM_Prop_Banner_Roof_01", Vector3(ox0 + 0.05, Y0 + H1 - 0.12, fz - 0.04), 0.0, Vector3((ow - 0.1) / 2.6, 0.9, dep / 2.6), Catalog.canopy_remap(2 + b.rng.randi() % 4))
		if fs > 0.6:
			for xx: float in [ox0 + 0.12, ox0 + ow - 0.12]:
				_p(b, "SM_Bld_Pillar_06", Vector3(xx, Y0, fz + dep - 0.05), 0.0, Vector3(0.2, (H1 - 0.25) / 3.0, 0.2))
		# свитки на прилавке
		_u(b, "SM_Prop_Scroll_Pile_02", Vector3(ox0 + ow * 0.35, Y0 + 0.62, fz + 0.02), 1.57, 0.5)
		_u(b, "SM_Prop_Scroll_Pile_04", Vector3(ox0 + ow * 0.7, Y0 + 0.62, fz + 0.02), 1.4, 0.45)
		var d: Array = res["D"][0]
		var dcx := float(r[0]) + float(d[1]) + float(d[2]) * 0.5
		CatShops._sign(b, Vector3(dcx - 0.62, Y0 + 1.6, fz + 0.06), 0.0, "B", CatShops.RED, 0.42)
		if fs > 0.6:
			_pot(b, Vector3(float(r[0]) + 0.2, Y0, fz + 0.32), 0.26)
	else:
		var d: Array = res["D"][0]
		var dcx := float(r[0]) + float(d[1]) + float(d[2]) * 0.5
		_p(b, "SM_Prop_Overhang_01", Vector3(dcx, Y0 + H1 - 0.12, fz + 0.02), 0.0, Vector3(0.62, 0.9, 0.85))
		_p(b, "#wall_lamp", Vector3(dcx - 0.62, Y0 + 1.7, fz + 0.02), 0.0)
		CatShops._sign(b, Vector3(float(r[0]) + mw * 0.5, Y0 + H1 + 0.05, fz + 0.1), 0.0, "D", CatShops.BLUE, 0.4)
		if fs > 0.6:
			_p(b, "SM_Prop_Seat_Bench_01", Vector3(float(r[0]) + mw * 0.5, Y0, fz + 0.32), 0.0, Vector3.ONE * 0.5)
			_pot(b, Vector3(float(r[1]) - 0.2, Y0, fz + 0.3), 0.26)
	# кадки у задних углов и куст у бока
	_pot(b, Vector3(float(r[0]) + 0.12, Y0, float(r[2]) + 0.16), 0.22)
	_bush(b, Vector3(x1 - 0.26, Y0, (float(r[2]) + fz) * 0.5 + 0.3), 0.18)
	var door: Array = res["D"][0]
	return Vector3(float(r[0]) + float(door[1]) + float(door[2]) * 0.5, 0, z1 + 0.35)


# =====================================================================
#   пост вигилов
# =====================================================================

static func _vigiles(b: Bp, fr: Array, x: Dictionary) -> Vector3:
	var fv: int = x["fv"]
	var m := 1.0 if fv == 0 else -1.0                       # вышка справа (А) или слева (Б)
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	var W := x1 - x0
	var D := z1 - z0
	NewCivic._base(b, x0, x1, z0, z1)
	var ts := clampf(D * 0.43, 1.1, 1.5)                    # вышка
	var fy := clampf(D - 2.6, 0.45, 0.95)                   # двор перед караульней
	var hw := minf(3.2, W - 0.2 - ts - 0.3)
	var hr := [x0 + 0.1, x0 + 0.1 + hw, z0 + 0.12, z1 - fy] if m > 0 else [x1 - 0.1 - hw, x1 - 0.1, z0 + 0.12, z1 - fy]
	var tr := [x1 - 0.1 - ts, x1 - 0.1, z0 + 0.12, z0 + 0.12 + ts] if m > 0 else [x0 + 0.1, x0 + 0.1 + ts, z0 + 0.12, z0 + 0.12 + ts]
	var H := 2.35
	# караульня: красно-охристая штукатурка цвета постройки, широкие ворота в депо, окно, сбоку — ниша и знамя
	x["leaf"] = LEAF_WOOD
	var front := "GN" if m > 0 else "NG"
	var res := _storey(b, hr, {0: front, 1: "SW" if m > 0 else "NS", 2: "WN", 3: "NW" if m > 0 else "WN"}, Y0, H, x)
	_pilasters(b, hr, {0: 2, 1: 2, 2: 2, 3: 2}, Y0, H)
	_frieze(b, hr, Y0 + H - 0.2)
	_cornice(b, hr, Y0 + H - 0.04, 0.16, 0.08)
	for e: Array in res["W"]:
		if int(e[0]) == 2:
			_ivy(b, hr, e, Y0, H, 2)
		else:
			var side: int = e[0]
			_p(b, "SM_Prop_Banner_01_A", _at(hr, side, float(e[1]) + float(e[2]) * 0.5, 0.06, Y0 + H - 0.25), _yaw(side), Vector3.ONE * 0.62)
	var ridge := _roof(b, hr, Y0 + H + 0.08, true, TYM_RED, 0.12)
	_u(b, "SM_Prop_Symbol_0%d" % [5, 9][fv], Vector3((float(hr[0]) + float(hr[1])) * 0.5, Y0 + H + 0.12, float(hr[3]) + 0.17), 0.0, 0.32 * (ridge - Y0 - H) / 0.38)
	# депо в тёплом свете: крюки, вёдра, лестница, топоры на стене
	var ir := _inner(hr, 0.3)
	_hall(b, ir, Y0, H - 0.06, _gaps(hr, res))
	var glow := {"glow": WARM * 0.4}
	var ix0: float = ir[0]
	var ix1: float = ir[1]
	var iz0: float = ir[2]
	for k in 4:
		_u(b, "SM_Prop_Jug_03", Vector3(lerpf(ix0 + 0.25, ix1 - 0.25, k / 3.0), Y0, iz0 + 0.18), b.rng.randf() * TAU, 0.42, glow)
	_p(b, "SM_Prop_Ladder_01", Vector3((ix0 + ix1) * 0.5, Y0, iz0 + 0.12), PI / 2 * 0.0 + 0.0, Vector3(0.7, 0.62, 0.7), glow)
	for k in 2:
		_p(b, "SM_Wep_Axe_01", Vector3(ix0 + 0.4 + k * 0.3, Y0 + 1.15, iz0 + 0.05), 0.0, Vector3.ONE * 0.8, glow)
	b.light(Vector3((ix0 + ix1) * 0.5, Y0 + 1.6, (float(ir[2]) + float(ir[3])) * 0.5))
	# дозорная вышка: тёсаный камень, площадка с перилами, столбы, черепичная крыша, огонь в жаровне
	var ph := 2.35
	var tw := {0: "M", 1: "W", 2: "W", 3: "W"}
	var stone_win := {"Stucco_White_01": "Building_Large_Brick_01", "Stucco_Orange_01": "Building_Large_Brick_01", "tints": {"Building_Large_Brick_01": Color(1.0, 0.93, 0.8)}}
	_storey(b, tr, tw, Y0, ph, x, STONE, stone_win, STONE)
	_cornice(b, tr, Y0 + ph - 0.02, 0.14, 0.12)
	var yp := Y0 + ph + 0.1
	var tc := Vector3((float(tr[0]) + float(tr[1])) * 0.5, 0, (float(tr[2]) + float(tr[3])) * 0.5)
	NewCivic._floor(b, WOOD, float(tr[0]) - 0.08, float(tr[2]) - 0.08, float(tr[1]) + 0.08, float(tr[3]) + 0.08, yp - 0.02, 2.0)
	var pr := [float(tr[0]) - 0.06, float(tr[1]) + 0.06, float(tr[2]) - 0.06, float(tr[3]) + 0.06]
	for side in 4:
		_run(b, "SM_Bld_Wall_Balcony_03", pr, side, yp, -0.05, 2.5, 0.5, 0.6, {}, 2.0)
	var ph2 := 1.05
	for c: Vector3 in [Vector3(pr[0] + 0.07, 0, pr[2] + 0.07), Vector3(pr[1] - 0.07, 0, pr[2] + 0.07), Vector3(pr[0] + 0.07, 0, pr[3] - 0.07), Vector3(pr[1] - 0.07, 0, pr[3] - 0.07)]:
		_p(b, "SM_Prop_Pole_01", Vector3(c.x, yp, c.z), 0.0, Vector3(0.6, ph2 / 3.0, 0.6))
	_roof(b, pr, yp + ph2, false, TYM_RED, 0.18)
	_u(b, "SM_Prop_Brazier_03", tc + Vector3(0, yp, 0), 0.0, 0.42)
	_u(b, "SM_Prop_Brazier_03_Insert_01", tc + Vector3(0, yp, 0), 0.0, 0.42)
	_fire(b, tc + Vector3(0, yp + 0.38, 0), 2.6)
	b.light(tc + Vector3(0, yp + 0.6, 0))
	# знамёна на перилах вышки (к улице и в сторону)
	_p(b, "SM_Prop_Banner_01_A", Vector3(tc.x, yp + 0.45, pr[3] + 0.02), 0.0, Vector3.ONE * 0.5)
	_p(b, "SM_Prop_Banner_01_A", Vector3(pr[1] + 0.02 if m > 0 else pr[0] - 0.02, yp + 0.45, tc.z), PI / 2 * m, Vector3.ONE * 0.5)
	# лестница к площадке — по боку вышки, обращённому к караульне
	var lx := float(tr[0]) - 0.1 if m > 0 else float(tr[1]) + 0.1
	_p(b, "SM_Prop_Ladder_01", Vector3(lx - 0.18 * m, Y0, tc.z + 0.15), PI / 2 * m, Vector3(0.75, 0.86, 0.75))
	# водоём из тёсаного камня перед вышкой, в него льёт львиная голова со стены вышки
	var wz0 := float(tr[3]) + 0.12
	var wz1 := minf(z1 - 0.15, wz0 + 0.85)
	var wx0 := float(tr[0]) + 0.08
	var wx1 := float(tr[1]) - 0.08
	if wz1 - wz0 > 0.45:
		var wr := [wx0, wx1, wz0, wz1]
		for side in 4:
			_run(b, "SM_Bld_Wall_01", wr, side, Y0, -0.06, 2.5, 0.55 / 3.01, 0.55, STONE, 1.6)
		NewCivic._ring(b, "SM_Bld_Wall_Large_Cap_01", wx0 - 0.04, wx1 + 0.04, wz0 - 0.04, wz1 + 0.04, Y0 + 0.53, 5.02, 0.3, 0.3, {}, [0, 1, 2, 3], 1.6)
		b.parts.append(["#water", b.base * Transform3D(Basis.from_scale(Vector3(wx1 - wx0 - 0.2, 0.06, wz1 - wz0 - 0.2)), Vector3(tc.x, Y0 + 0.44, (wz0 + wz1) * 0.5)), {}])
		_u(b, "SM_Prop_Marble_LionHead_01", Vector3(tc.x, Y0 + 1.05, float(tr[3]) + 0.03), 0.0, 0.5)
		_u(b, "SM_Prop_Fountain_03", Vector3(tc.x, Y0 + 0.62, float(tr[3]) + 0.03), 0.0, 0.62)
		b.actor(Vector3(tc.x - 0.75 * m, Y0, wz1 + 0.05 if wz1 + 0.3 < z1 else (wz0 + wz1) * 0.5), PI * 0.75 * m, "Interact", "pleb")
	else:
		b.actor(Vector3(tc.x, Y0, z1 - 0.25), PI, "Interact", "pleb")
	# двор: водовозка-сифон с бочкой, вёдра у стены, лестницы, багор
	var hz1 := float(hr[3])
	var gate: Array = res["G"][0]
	var gcx := float(hr[0]) + float(gate[1]) + float(gate[2]) * 0.5
	if fy > 0.8:
		var cx := clampf(gcx, x0 + 0.85, x1 - 0.85)
		_p(b, "SM_Prop_Cart_01", Vector3(cx - 0.32, Y0, hz1 + 0.45), PI / 2, Vector3.ONE * 0.46)
		_p(b, "SM_Prop_Bowl_02", Vector3(cx, Y0 + 0.42, hz1 + 0.44), 0.0, Vector3(0.75, 1.6, 0.75) * 0.5)
		b.actor(Vector3(cx + 0.95 * m, Y0, hz1 + 0.5), -PI / 2 * m, "Idle", "pleb")
	else:
		b.actor(Vector3(gcx, Y0, z1 - 0.15), PI, "Idle", "pleb")
	# у окна (по другую сторону от ворот): вёдра в ряд и лестница, прислонённая к стене
	var wx := gcx + m * float(gate[2]) * 0.62
	for k in 3:
		_u(b, "SM_Prop_Jug_03", Vector3(wx + m * k * 0.22, Y0, hz1 + 0.16), b.rng.randf() * TAU, 0.38)
	CatDecor._lean(b, "SM_Prop_Ladder_01", Vector3(float(hr[1]) - 0.22 if m > 0 else float(hr[0]) + 0.22, Y0, hz1 + 0.12), 0.0, -0.2, 0.62)
	CatShops._sign(b, Vector3(gcx, Y0 + H - 0.55, hz1 + 0.08), 0.0, "H", CatShops.RED, 0.38)
	_p(b, "#wall_lamp", Vector3(gcx + 0.62 * m, Y0 + 1.55, hz1 + 0.02), 0.0)
	_pot(b, Vector3(x0 + 0.2 if m > 0 else x1 - 0.2, Y0, z1 - 0.2), 0.24)
	return Vector3(gcx, 0, z1 + 0.35)


# =====================================================================
#   склад
# =====================================================================

static func _warehouse(b: Bp, fr: Array, x: Dictionary) -> Vector3:
	var fv: int = x["fv"]
	var m := 1.0 if fv == 0 else -1.0                       # навес с амфорами справа (А) или слева (Б)
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	var W := x1 - x0
	var D := z1 - z0
	NewCivic._base(b, x0, x1, z0, z1)
	var ls := clampf(W - 5.6, 0.0, 1.45)
	var bw := W - 0.2 - ls
	var yd := clampf(D - 3.75, 0.7, 1.4)
	var r := [x0 + 0.1, x0 + 0.1 + bw, z0 + 0.12, z1 - yd] if m > 0 else [x1 - 0.1 - bw, x1 - 0.1, z0 + 0.12, z1 - yd]
	var H1 := 2.4
	var E := 0.14
	var H2 := 1.5
	var y2 := Y0 + H1 + E
	var ytop := y2 + H2
	# кирпичный низ (тёплый, с оттенком цвета постройки), оштукатуренный чердак цвета постройки
	var tb: Color = Color(1.0, 0.8, 0.66).lerp(x["t"], 0.3)
	var brick := {"Stucco_White_01": "Building_Large_Brick_01", "tints": {"Building_Large_Brick_01": tb}}
	var bwin := {"Stucco_White_01": "Building_Marble_01", "Stucco_Orange_01": "Building_Large_Brick_01", "tints": {"Building_Large_Brick_01": tb}}
	var bdoor := {"tints": {"Building_Large_Brick_01": tb}}
	x["leaf"] = LEAF_WOOD
	x["shut"] = "#shutters_brown"
	var g1 := {0: "HGH" if fv == 0 else "GAG", 1: "TW", 2: "TWT", 3: "WT"}
	var g2 := {0: "SLS" if fv == 0 else "BLB", 1: "NS", 2: "SNS", 3: "SN"}
	var res := _storey(b, r, g1, Y0, H1, x, brick, bwin, bdoor)
	var up := _storey(b, r, g2, y2, H2, x)
	for side in 4:
		_run(b, "SM_Bld_Wall_01", r, side, Y0 + H1, -0.11 * 0.6, 2.5, E / 3.01, 0.6, x["st"], 1.8)
	_cornice(b, r, Y0 + H1 - 0.03, E + 0.04, 0.08)
	_pilasters(b, r, {0: 3, 1: 2, 2: 3, 3: 2}, Y0, H1, 0.22)
	_pilasters(b, r, {0: 3, 1: 2, 2: 3, 3: 2}, y2, H2, 0.16)
	_cornice(b, r, ytop - 0.03, 0.16, 0.1)
	# гладкие кирпичные простенки: рельефы-медальоны и плющ
	for e: Array in res["W"]:
		var side: int = e[0]
		_u(b, "SM_Bld_Ornament_0%d" % [2, 6][side % 2], _at(r, side, float(e[1]) + float(e[2]) * 0.5, 0.02, Y0 + H1 * 0.62), _yaw(side), 0.34)
		if side == 2:
			_ivy(b, r, e, Y0, H1, 3)
	_roof(b, r, ytop + 0.08, false, TYM_RED, 0.16)
	# тёплый зал: полки с кувшинами, мешки, амфоры (через ворота и окна)
	var ir := _inner(r, 0.33)
	_hall(b, ir, Y0, ytop - Y0 - 0.1, _gaps(r, res))
	var ix0: float = ir[0]
	var ix1: float = ir[1]
	var iz0: float = ir[2]
	var iz1: float = ir[3]
	var glow := {"glow": WARM * 0.4}
	for sd: float in [-1.0, 1.0]:
		var sx := (ix0 + ix1) * 0.5 + sd * (ix1 - ix0) * 0.25
		_p(b, "SM_Prop_Shelf_0%d" % (1 if sd < 0 else 2), Vector3(sx, Y0, iz0 + 0.28), 0.0, Vector3(((ix1 - ix0) * 0.5 - 0.15) / 2.5, 1.35 / 1.86, 0.55), glow)
	_u(b, "SM_Prop_Sack_Stack_01", Vector3(ix0 + 0.55, Y0, iz1 - 0.6), 0.3, 0.55, glow)
	_u(b, "SM_Prop_Vase_Pile_02", Vector3(ix1 - 0.6, Y0, iz1 - 0.75), 0.0, 0.4, glow)
	_u(b, "SM_Prop_Basket_Set_02", Vector3((ix0 + ix1) * 0.5 + 0.9, Y0, (iz0 + iz1) * 0.5), 0.4, 0.45, glow)
	b.light(Vector3((ix0 + ix1) * 0.5, Y0 + 1.7, (iz0 + iz1) * 0.5))
	# чердачная дверь над воротами: балка-подъёмник, верёвка, мешок
	var fz := float(r[3])
	for e: Array in up["L"]:
		var lcx := float(r[0]) + float(e[1]) + float(e[2]) * 0.5
		_p(b, "SM_Prop_Beam_01", Vector3(lcx, y2 + H2 - 0.18, fz - 0.25), -PI / 2, Vector3(0.42, 1.2, 1.2))
		_p(b, "SM_Prop_Pole_01", Vector3(lcx, y2 + 0.15, fz + 0.75), 0.0, Vector3(0.18, (H2 - 0.45) / 3.0, 0.18))
		_u(b, "SM_Prop_Sack_04", Vector3(lcx, y2 - 0.1, fz + 0.75), PI / 2, 0.5)
	# навес сбоку: черепичный козырёк на столбах, под ним — амфоры, мешки, кувшины
	if ls > 0.6:
		var sx0 := float(r[1]) if m > 0 else float(r[0])
		var sx1 := x1 - 0.1 if m > 0 else x0 + 0.1
		var sz0 := float(r[2]) + 0.2
		var sz1 := fz - 0.1
		# односкатная черепичная кровля: от стены (верх) к столбам (свес)
		var dep := absf(sx1 - sx0) + 0.12
		var kr := dep / 7.5
		var ye := Y0 + 1.95
		_p(b, "SM_Bld_Roof_Straight_Thin_Large_01", Vector3(sx1 + m * 0.12, ye, sz1 + 0.1 if m > 0 else sz0 - 0.1), PI / 2 * m,
			Vector3((sz1 - sz0 + 0.2) / 7.5, kr * 1.3, kr))
		_p(b, "SM_Prop_Beam_01", Vector3(sx1 - m * 0.12, ye - 0.06, sz0 if m > 0 else sz1), -PI / 2 * m, Vector3((sz1 - sz0) / 2.5, 1.0, 1.0))
		for zz: float in [sz0 + 0.1, (sz0 + sz1) * 0.5, sz1 - 0.1]:
			_p(b, "SM_Bld_Pillar_06", Vector3(sx1 - m * 0.12, Y0, zz), 0.0, Vector3(0.22, 1.75 / 3.0, 0.22))
		var cx := (sx0 + sx1) * 0.5
		_u(b, "SM_Prop_Vase_Pile_02", Vector3(cx, Y0, sz0 + 0.75), PI / 2, 0.36)
		_u(b, "SM_Prop_Sack_Stack_02", Vector3(cx, Y0, sz1 - 0.5), PI / 2, 0.42)
		_u(b, "SM_Prop_Jar_01", Vector3(cx - m * 0.15, Y0, (sz0 + sz1) * 0.5 + 0.1), 0.0, 0.5)
	# двор: товар у стены, повозка, грузчик на мешках у ворот (место работника)
	var gate: Array = res["G"][0]
	var gcx := float(r[0]) + float(gate[1]) + float(gate[2]) * 0.5
	# (место — ближе 1,5 м к месту входа: второй работник, придя, заходит в ворота, People._enter_work); товар — по ту
	# сторону ворот, где двор шире
	var dd := 1.0 if x1 - gcx > gcx - x0 else -1.0
	var seat_x := gcx + 0.85 * dd
	var seat_z := maxf(fz + 0.36, z1 - 0.55)
	var sb := Bp.model_aabb("SM_Prop_Sack_Stack_01")
	var ssy := 0.27 / maxf(sb.size.y, 0.01)
	_p(b, "SM_Prop_Sack_Stack_01", Vector3(seat_x, Y0, seat_z), PI / 2, Vector3(0.42, ssy, 0.42))
	b.actor(Vector3(seat_x, Y0, seat_z + 0.05), 0.0, "Sitting_Idle", "pleb")
	var lo := x0 + 0.3
	var hi := x1 - 0.3
	var ox := clampf(gcx - 1.2 * dd, lo, hi)
	_u(b, "SM_Prop_Sack_Stack_02", Vector3(ox, Y0, fz + 0.3), 0.0, 0.42)
	_u(b, "SM_Prop_Sack_05", Vector3(clampf(ox - 0.5 * dd, lo, hi), Y0, fz + 0.25), 0.6, 0.5)
	for k in 3:
		_u(b, "SM_Prop_Vase_0%d" % [1, 3, 6][k], Vector3(clampf(gcx + (1.5 + k * 0.28) * dd, lo, hi - 0.1 + k * 0.05), Y0, fz + 0.22 + 0.12 * k), b.rng.randf() * TAU, 0.45)
	if yd > 1.1:
		var cx := clampf(ox - 0.2 * dd, x0 + 0.8, x1 - 0.8)
		_p(b, "SM_Prop_Cart_01", Vector3(cx - 0.29, Y0, z1 - 0.48), PI / 2, Vector3.ONE * 0.42)
		_p(b, "SM_Prop_Cart_01_Insert_02", Vector3(cx - 0.29, Y0, z1 - 0.48), PI / 2, Vector3.ONE * 0.42)
	_u(b, "SM_Prop_Basket_Set_06", Vector3(clampf(gcx + 1.35 * dd, lo, hi), Y0, z1 - 0.32), 0.3, 0.4)
	_p(b, "#wall_lamp", Vector3(gcx - 0.95 * dd, Y0 + 1.75, fz + 0.02), 0.0)
	_u(b, "SM_Prop_Symbol_0%d" % [5, 1][fv], Vector3(gcx, Y0 + H1 - 0.28, fz + 0.03), 0.0, 0.42)
	return Vector3(gcx, 0, z1 + 0.35)


# =====================================================================
#   малые бани
# =====================================================================

static func _balnea(b: Bp, fr: Array, x: Dictionary) -> Vector3:
	var fv: int = x["fv"]
	var m := 1.0 if fv == 0 else -1.0                       # вход справа, бассейн слева (А) или наоборот (Б)
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	var D := z1 - z0
	NewCivic._base(b, x0, x1, z0, z1)
	var hd := clampf(D - 2.45, 1.9, 3.0)
	var r := [x0 + 0.1, x1 - 0.1, z0 + 0.12, z0 + 0.12 + hd]
	var H := 2.5
	var hz1: float = r[3]
	x["leaf"] = LEAF_BRONZE
	x["shut"] = "#shutters_green"
	var front := "NWND" if m > 0 else "DNWN"
	var res := _storey(b, r, {0: front, 1: "NS", 2: "SNNS", 3: "SN"}, Y0, H, x)
	_pilasters(b, r, {0: 4, 1: 2, 2: 4, 3: 2}, Y0, H)
	_frieze(b, r, Y0 + H - 0.2)
	_cornice(b, r, Y0 + H - 0.03, 0.18, 0.1)
	# плоская кровля с белым парапетом; купол кальдария на барабане (свинец)
	NewCivic._floor(b, PAVING, float(r[0]), float(r[2]), float(r[1]), hz1, Y0 + H + 0.12, 2.2)
	NewCivic._ring(b, "SM_Bld_Wall_Tiny_01", float(r[0]) + 0.04, float(r[1]) - 0.04, float(r[2]) + 0.04, hz1 - 0.04, Y0 + H + 0.12, 2.5, 1.0, 1.0, WHITE, [0, 1, 2, 3], 2.0)
	var dc := Vector3((float(r[0]) + float(r[1])) * 0.5 - 0.45 * m, 0, (float(r[2]) + hz1) * 0.5)
	var dr := minf(1.18, hd * 0.5 - 0.26)
	var ky := 0.3 * dr / 1.18
	var yd := Y0 + H + 0.14
	var dh := 3.6 * ky + 0.06
	for i in 10:
		NewCivic._on_arc(b, "SM_Bld_Wall_Tiny_01", dc, i * TAU / 10.0, dr, yd, 2.0 * dr * tan(PI / 10.0) + 0.05, 2.5, dh / 0.31, 1.1, WHITE)
	NewCivic._on_arc_ring_cap(b, dc, dr + 0.04, yd + dh - 0.02, 10)
	var ks := (2.0 * dr + 0.16) / 5.12
	_p(b, "SM_Prop_Pergola_01", dc + Vector3(0, yd + dh - 3.6 * ky, 0), 0.0, Vector3(ks, ky, ks), DOME)
	# зал в тёплом свете: горячий бассейн, статуя в нише, скамья, светильники
	var ir := _inner(r, 0.32)
	_hall(b, ir, Y0, H - 0.06, _gaps(r, res))
	var ix0: float = ir[0]
	var ix1: float = ir[1]
	var iz0: float = ir[2]
	var iz1: float = ir[3]
	var pc := (ix0 + ix1) * 0.5 - 0.5 * m
	b.parts.append(["#water", b.base * Transform3D(Basis.from_scale(Vector3(1.6, 0.05, minf(0.9, iz1 - iz0 - 0.9))), Vector3(pc, Y0 + 0.05, (iz0 + iz1) * 0.5 - 0.1)), {}])
	NewCivic._ring(b, "SM_Bld_Wall_Large_Cap_01", pc - 0.86, pc + 0.86, (iz0 + iz1) * 0.5 - 0.1 - minf(0.9, iz1 - iz0 - 0.9) * 0.5 - 0.06,
		(iz0 + iz1) * 0.5 - 0.1 + minf(0.9, iz1 - iz0 - 0.9) * 0.5 + 0.06, Y0, 5.02, 0.36, 0.2, {"glow": WARM * 0.5}, [0, 1, 2, 3], 1.0)
	_p(b, "SM_Prop_Plinth_04", Vector3(pc, Y0, iz0 + 0.3), 0.0, Vector3(0.45, 0.42, 0.45), {"glow": WARM * 0.5})
	_u(b, "SM_Prop_Statue_06", Vector3(pc, Y0 + 0.28, iz0 + 0.3), 0.0, 0.46, {"glow": WARM * 0.6})
	_p(b, "SM_Prop_Seat_Bench_03", Vector3(ix1 - 0.55 if m > 0 else ix0 + 0.55, Y0, iz0 + 0.35), 0.0, Vector3.ONE * 0.38, {"glow": WARM * 0.4})
	_u(b, "SM_Prop_Senser_01", Vector3(ix0 + 0.25 if m > 0 else ix1 - 0.25, Y0, iz1 - 0.3), 0.0, 0.42, {"glow": WARM * 0.6})
	b.light(Vector3(pc, Y0 + 1.6, (iz0 + iz1) * 0.5))
	# вход: портик на двух колоннах с фронтоном перед бронзовыми дверями
	var d: Array = res["D"][0]
	var dcx := float(r[0]) + float(d[1]) + float(d[2]) * 0.5
	var vd := clampf(z1 - hz1 - 0.55, 0.8, 1.35)
	var pz := hz1 + vd
	var phw := minf(0.85, float(d[2]) * 0.5 + 0.05)
	NewCivic._floor(b, MOSAIC, dcx - phw, hz1, dcx + phw, pz + 0.1, Y0 + 0.004, 1.8)
	for sd: float in [-1.0, 1.0]:
		_p(b, "SM_Prop_Plinth_03", Vector3(dcx + sd * (phw - 0.14), Y0, pz - 0.1), 0.0, Vector3(0.38, 1.0, 0.38))
		_p(b, "SM_Bld_Pillar_06", Vector3(dcx + sd * (phw - 0.14), Y0 + 0.05, pz - 0.1), 0.0, Vector3(0.36, (H - 0.32) / 3.0, 0.36))
	NewCivic._ledge(b, dcx - phw - 0.06, dcx + phw + 0.06, hz1, pz + 0.06, Y0 + H - 0.27, 0.2)
	var pr := NewCivic._gable_z(b, dcx - phw - 0.1, dcx + phw + 0.1, hz1 + 0.05, pz + 0.12, Y0 + H - 0.07, TYMPANUM, true, false)
	_u(b, "SM_Bld_Ornament_02", Vector3(dcx, Y0 + H - 0.07 + (pr - Y0 - H + 0.07) * 0.3, pz + 0.08), 0.0, 0.24)
	# открытый бассейн во дворе со львиной головой на стене зала
	var pw := minf(2.5, (float(r[1]) - float(r[0])) * 0.5 - 0.35)
	var pcx := (float(r[0]) + 0.35 + pw * 0.5) if m > 0 else (float(r[1]) - 0.35 - pw * 0.5)
	var pz0 := hz1 + 0.32
	var pz1 := minf(z1 - 0.3, pz0 + 1.25)
	NewCivic._pool(b, pcx - pw * 0.5, pcx + pw * 0.5, pz0, pz1, 0.5, Y0 + 0.07, false)
	_u(b, "SM_Prop_Marble_LionHead_01", Vector3(pcx, Y0 + 0.95, hz1 + 0.04), 0.0, 0.85)
	_u(b, "SM_Prop_Fountain_03", Vector3(pcx, Y0 + 0.36, hz1 + 0.05), 0.0, 1.0)
	# над львиной головой — фреска с купальщиками на гладком простенке
	for e: Array in res["W"]:
		if int(e[0]) == 0:
			var wcx := float(r[0]) + float(e[1]) + float(e[2]) * 0.5
			_u(b, "SM_Prop_Mural_0%d" % [1, 3][fv], Vector3(wcx, Y0 + 1.75, hz1 + 0.012), 0.0, minf(0.55, float(e[2]) / 2.53 - 0.04))
	# скамья с полотенцами между бассейном и входом, амфоры масла, пальма в углу, цветы
	var bx := (pcx + pw * 0.5 * m + dcx - phw * m) * 0.5
	if absf(dcx - pcx) - pw * 0.5 - phw > 0.7:
		_p(b, "SM_Prop_Seat_Bench_03", Vector3(bx, Y0, hz1 + 0.35), 0.0, Vector3.ONE * 0.34)
		_u(b, "SM_Prop_Rug_Folded_0%d" % (1 + fv), Vector3(bx - 0.15, Y0 + 0.22, hz1 + 0.35), 0.2, 0.4)
	_u(b, "SM_Prop_Rug_Folded_03", Vector3(pcx + 0.6, Y0 + 0.004, pz1 + 0.18), 0.1, 0.42)
	var ox := dcx + (phw + 0.22) * m                        # с наружной стороны портика — если там есть место
	if absf(ox - (x1 if m > 0 else x0)) < 0.35:
		ox = dcx - (phw + 0.22) * m
	_u(b, "SM_Prop_Vase_01", Vector3(ox, Y0, pz - 0.15), 0.0, 0.42)
	_u(b, "SM_Prop_Jug_06", Vector3(ox, Y0, pz + 0.18), 0.0, 0.5)
	var cx := x0 + 0.38 if m > 0 else x1 - 0.38
	_p(b, "SM_Env_Tree_Palm_0%d" % (1 + fv), Vector3(cx, Y0, z1 - 0.38), b.rng.randf() * TAU, Vector3.ONE * 0.22)
	# у бока двора — цветник и статуя на постаменте
	_p(b, "SM_Prop_FlowerBed_01", Vector3(cx, Y0 + 0.17 * 0.4, hz1 + 0.6), PI / 2, Vector3.ONE * 0.4)
	_p(b, "SM_Prop_Plinth_02", Vector3(cx, Y0, (hz1 + 0.6 + z1 - 0.38) * 0.5 + 0.1), 0.0, Vector3(0.5, 0.42, 0.5))
	_u(b, "SM_Prop_Statue_0%d" % [5, 3][fv], Vector3(cx, Y0 + 0.42, (hz1 + 0.6 + z1 - 0.38) * 0.5 + 0.1), PI / 2 * m, 0.3)
	_pot(b, Vector3(x1 - 0.25 if m > 0 else x0 + 0.25, Y0, z1 - 0.25), 0.26)
	_p(b, "#wall_lamp", Vector3(dcx - (phw + 0.25) * m, Y0 + 1.6, hz1 + 0.02), 0.0)
	b.actor(Vector3(dcx - (phw + 0.3) * m, Y0, z1 - 0.35), PI + 0.3 * m, "Idle", "any")
	# сзади — дрова для печи под черепичным козырьком
	var fx := float(r[0]) + 0.9 if m > 0 else float(r[1]) - 0.9
	_p(b, "SM_Prop_Overhang_01", Vector3(fx, Y0 + 1.4, float(r[2]) - 0.02), PI, Vector3(0.55, 0.8, 0.6))
	return Vector3(dcx, 0, z1 + 0.35)


# =====================================================================
#   школа
# =====================================================================

static func _school(b: Bp, fr: Array, x: Dictionary) -> Vector3:
	var fv: int = x["fv"]
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	NewCivic._base(b, x0, x1, z0, z1)
	var cd := minf(2.65, (z1 - z0) * 0.45)                 # двор перед домом
	var r := [x0 + 0.1, x1 - 0.1, z0 + 0.12, z1 - cd]
	var H1 := 2.25
	var E := 0.14
	var H2 := 1.6
	var y2 := Y0 + H1 + E
	var ytop := y2 + H2
	var hz1: float = r[3]
	x["leaf"] = LEAF_BRONZE if fv == 1 else LEAF_WOOD
	x["shut"] = "#shutters_green" if fv == 0 else "#shutters_blue"
	var res := _storey(b, r, {0: "SDS", 1: "NS", 2: "NAN", 3: "SN"}, Y0, H1, x)
	var up := _storey(b, r, {0: "BNB" if fv == 0 else "SAS", 1: "SW", 2: "BSB", 3: "WS"}, y2, H2, x)
	for side in 4:
		_run(b, "SM_Bld_Wall_01", r, side, Y0 + H1, -0.11 * 0.6, 2.5, E / 3.01, 0.6, x["st"], 2.1)
	_cornice(b, r, Y0 + H1 - 0.03, E + 0.04, 0.08)
	_pilasters(b, r, {0: 3, 1: 2, 2: 3, 3: 2}, Y0, ytop - Y0)
	_frieze(b, r, ytop - 0.2)
	_cornice(b, r, ytop - 0.03, 0.18, 0.1)
	for e: Array in up["W"]:
		_ivy(b, r, e, y2, H2, 2)
	var xc := (float(r[0]) + float(r[1])) * 0.5
	if fv == 0:
		# длинная кровля вдоль улицы; над дверью (под перголой) — медальон
		_roof(b, r, ytop + 0.08, false, TYM_RED, 0.16)
		_u(b, "SM_Bld_Ornament_02", Vector3(xc, Y0 + H1 - 0.32, hz1 + 0.04), 0.0, 0.26)
	else:
		# большой фронтон к улице: синий тимпан, золотая сова Минервы — медальон, акротерии
		var ridge := _roof(b, r, ytop + 0.08, true, TYMPANUM, 0.16)
		_u(b, "SM_Bld_Ornament_02", Vector3(xc, ytop + 0.08 + (ridge - ytop - 0.08) * 0.3, hz1 + 0.18), 0.0, 0.36)
		for sd: float in [-1.0, 1.0]:
			_u(b, "SM_Bld_Ornament_06", Vector3(xc + sd * (xc - float(r[0]) - 0.05), ytop + 0.12, hz1 + 0.1), 0.0, 0.28)
		var d: Array = res["D"][0]
		_p(b, "SM_Prop_Overhang_01", Vector3(float(r[0]) + float(d[1]) + float(d[2]) * 0.5, Y0 + H1 - 0.15, hz1 + 0.02), 0.0, Vector3(0.7, 0.9, 0.9))
	# классы в тёплом свете (через двери и окна обоих этажей): свитки на полках, стол, бюст
	var ir := _inner(r, 0.33)
	_hall(b, ir, Y0, ytop - Y0 - 0.1, _gaps(r, res))
	var ix0: float = ir[0]
	var ix1: float = ir[1]
	var iz0: float = ir[2]
	var iz1: float = ir[3]
	var shelf := {"glow": WARM * 0.45}
	for sd: float in [-1.0, 1.0]:
		var sx := xc + sd * (ix1 - ix0) * 0.27
		_p(b, "SM_Prop_Shelf_Scroll_01", Vector3(sx, Y0, iz0 + 0.02), 0.0, Vector3(1.5 / 2.33, 1.5 / 2.71, 0.5), shelf)
		_p(b, "SM_Prop_Shelf_Scroll_01_Insert_0%d" % (1 if sd < 0 else 2), Vector3(sx, Y0, iz0 + 0.02), 0.0, Vector3(1.5 / 2.33, 1.5 / 2.71, 0.5), shelf)
	_p(b, "SM_Prop_Table_01", Vector3(xc, Y0, (iz0 + iz1) * 0.5), 0.0, Vector3.ONE * 0.55, {"glow": WARM * 0.4})
	_u(b, "SM_Prop_Scroll_Pile_03", Vector3(xc - 0.15, Y0 + 0.43, (iz0 + iz1) * 0.5), 0.4, 0.38, {"glow": WARM * 0.4})
	_p(b, "SM_Prop_Plinth_02", Vector3(ix1 - 0.3, Y0, iz1 - 0.3), 0.0, Vector3(0.55, 0.65, 0.55), {"glow": WARM * 0.5})
	_u(b, "SM_Prop_Statue_05", Vector3(ix1 - 0.3, Y0 + 0.65, iz1 - 0.3), PI, 0.26, {"glow": WARM * 0.6})
	b.light(Vector3(xc, Y0 + 1.6, (iz0 + iz1) * 0.5))
	# двор: пергола с виноградом (А) или полосатые тенты на столбах (Б); скамьи учеников лицом к учителю (Spectacle)
	var px0 := x0 + 0.32
	var px1 := x1 - 0.32
	var pzf := z1 - 0.28
	var ph := H1 - 0.12
	if fv == 0:
		for xx: float in [px0, xc - 1.6, xc + 1.6, px1]:
			_p(b, "SM_Bld_Pillar_06", Vector3(xx, Y0, pzf), 0.0, Vector3(0.3, ph / 3.0, 0.3))
		for xx: float in [px0, px1]:
			_u(b, "SM_Env_Ivy_Pillar_Flowers_0%d" % (1 + b.rng.randi() % 2), Vector3(xx, Y0, pzf), b.rng.randf() * TAU, 0.62)
		_p(b, "SM_Bld_Trellis_Roof_Large_02", Vector3(px0, Y0 + ph, hz1 + 0.02), 0.0, Vector3((px1 - px0) / 7.5, 0.8, (pzf - hz1 - 0.02) / 5.0))
		for k in 4:
			var vx := lerpf(px0 + 0.6, px1 - 0.6, k / 3.0)
			b.parts.append(["SM_Env_Vine_0%d" % (1 + k % 2), b.base * Transform3D(Basis(Vector3.UP, 0.0 if k % 2 == 0 else PI) * Basis(Vector3.RIGHT, -PI / 2) * Basis.from_scale(Vector3(0.9, 0.7, 0.75)),
				Vector3(vx, Y0 + ph + 0.2, (hz1 + pzf) * 0.5 + (0.6 if k % 2 == 0 else -0.6))), {}])
	else:
		for xx: float in [px0, xc, px1]:
			_p(b, "SM_Prop_Pole_01", Vector3(xx, Y0, pzf), 0.0, Vector3(0.6, ph / 3.0, 0.6))
		var cw := (px1 - px0) * 0.5
		for i in 2:
			_p(b, "SM_Prop_Banner_Roof_01", Vector3(px0 + i * cw + 0.02, Y0 + ph + 0.05, hz1 + 0.02), 0.0, Vector3((cw - 0.04) / 2.6, 0.9, (pzf - hz1 + 0.1) / 2.6),
				Catalog.canopy_remap(1 + (int(x["c"]) + i * 2) % 5))
	# скамьи: два ряда по две (на каждой — трое детей), кресло учителя у улицы лицом к ним, учитель
	var rz := [hz1 + 0.75, hz1 + 1.45]
	for zz: float in rz:
		for sd: float in [-1.0, 1.0]:
			_p(b, "SM_Prop_Seat_Bench_01", Vector3(sd * 0.98, Y0, zz), 0.0, Vector3.ONE * 0.7)
	_u(b, "SM_Prop_Scroll_Pile_02", Vector3(-1.3, Y0 + 0.35, float(rz[0])), 0.4, 0.5)
	_u(b, "SM_Prop_Lyre_01", Vector3(1.35, Y0 + 0.42, float(rz[1])), 0.2, 0.55)
	_p(b, "SM_Prop_Seat_Chair_03", Vector3(0.85, Y0, z1 - 0.55), PI, Vector3.ONE * 0.52)
	_u(b, "SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 5), Vector3(-0.85, Y0, z1 - 0.5), 0.0, 0.45)
	_u(b, "SM_Prop_Scroll_Pile_06", Vector3(-0.85, Y0 + 0.28, z1 - 0.5), 0.0, 0.36)
	b.actor(Vector3(0, Y0, z1 - 0.42), PI, "Idle", "rich")
	# солнечные часы и цветы по углам двора, бортики по бокам двора
	_u(b, "SM_Prop_Sundial_01", Vector3(px0 + 0.45, Y0, hz1 + 0.55), 0.0, 0.42)
	_pot(b, Vector3(px1 - 0.3, Y0, hz1 + 0.4), 0.3)
	_pot(b, Vector3(px1 - 0.25, Y0, pzf - 0.35), 0.24)
	for sd: float in [-1.0, 1.0]:
		var kx := x0 + 0.12 if sd < 0 else x1 - 0.12
		_kerb_wall(b, Vector3(kx, Y0, pzf - 0.15 if sd < 0 else hz1 + 0.1), Vector3(0, 0, -1) if sd < 0 else Vector3(0, 0, 1), pzf - 0.25 - hz1, 0.36)
	_p(b, "#wall_lamp", Vector3(xc - 0.7, Y0 + 1.75, hz1 + 0.02), 0.0)
	return Vector3(0, 0, z1 + 0.35)
