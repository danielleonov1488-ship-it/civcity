class_name NewHouses
extends RefCounted
## Новые дома (владелец 13.11: «пересобрать модельки» — новые дома из деталей Synty POLYGON Ancient Empire, а не
## украшенные прежние; «темноты вообще не должно быть»; дома — мерка линейки размеров, их след прежний). Собраны с нуля
## в метрах города (base делит на масштаб Catalog, тот потом умножает обратно), фасад к +Z, вход — b.door.
##  - дома плебеев (5 обликов, след ≈ 2,8 × 4 м): скромные оштукатуренные дома в 1–3 этажа, черепица, крашеные ставни,
##    ящики с цветами, горшки у двери; облики — «Ставни» (шатровая крыша), «Балкон» (деревянный балкон с бельём,
##    двускатная крыша вдоль улицы), «Фронтон» (фронтон с медальоном к улице, кирпичный низ, окна с фронтончиками),
##    «Терраса» (плоская крыша-терраса с перголой и бельём, навес над окном и скамья), «Лоджия» (верхний этаж — лоджия
##    с колоннами за балюстрадой);
##  - дома ремесленников (5 обликов, след ≈ 2,8 × 5 м): внизу мастерская с открытым прилавком под навесом (тёплая
##    комната с орудиями и товаром ремесла), рядом дверь в каменной арке, наверху жильё; за домом двор под навесом со
##    снастью ремесла; облики — ткач (полосатый навес, балкон с тканями), торговец зерном (галерея-менианум на балках),
##    кузнец (кирпичный низ, фронтон), гончар (терраса с перголой, кувшины на навесе), медник (лоджия);
##  - домусы патрициев (4 облика, след ≈ 2,8 × 7,3 м): дом за портиком с колоннами на мраморном подиуме, мраморные
##    пилястры, расписной фриз, богатый карниз, парадная двустворчатая дверь в каменной арке; за домом сад за стенами
##    (кипарисы, клумбы, фонтан, пергола с ложем, статуя или колодец, садовник); облики — фронтон с медальоном, лоджия
##    со статуями, черепичный навес с архитравом, портик с виноградом;
##  - городской домус (после перестройки дома ремесленников, облики 4–5): коробка дома ремесленников до 3 этажей,
##    парадная дверь под маленьким портиком, мраморные пилястры, балкончики с балюстрадой, садик за домом.
## Рост: tier — этажи (у домуса 1–2, у остальных 1–3): нижний этаж и всё у земли при росте не меняются (случай — по
## типу, облику и цвету, у каждого этажа свой поток), верхний этаж облика (лоджия, терраса) поднимается выше.
## За каждой дверью и окном — освещённая комната (тёплое свечение материала, remap «glow», как у NewCivic и NewSmall),
## Life открывает двери и ставни; скамьи у дома, цветы для полива (ящики под окнами и горшки у двери), бельё.
## Стены — цветная штукатурка города (цвет дома, Bp.paint, оттенок — у экземпляра) с каменными углами, поясами и
## карнизами. Земля у дома — тротуар из плит (land.gdshader apron_pave, City.apron_of = 1; у домуса — бордюр, 2).
## Прежние сборки (CatHouses) остаются: ON — выключатели по типу (снимки «было/стало»); CIVCITY_NEWHOUSES=0 — прежние
## во всей игре, CIVCITY_NEWAPRON=0 — прежняя глина у домов.

static var ON := {"house_pleb": true, "house_artisan": true, "house_patrician": true} \
	if OS.get_environment("CIVCITY_NEWHOUSES") != "0" \
	else {"house_pleb": false, "house_artisan": false, "house_patrician": false}
## тротуар из плит вместо глины у домов, лавок и мастерских (land.gdshader apron_pave)
static var APRON := OS.get_environment("CIVCITY_NEWAPRON") != "0"
const TYPES := ["house_pleb", "house_artisan", "house_patrician"]

# ---------- размеры (м города, фасад к +Z; след — как у прежних домов, test_houses_probe) ----------
const X1 := 1.32                  # половина ширины коробки (лицо стены; рамы окон и углы — до 1,42, как прежний след 1,41)
const Z1 := 1.88                  # лицо фасада (и задней стены: −Z1) у домов плебеев и ремесленников
const H0 := 1.95                  # высота первого этажа
const HU := 1.75                  # высота верхних этажей
const E := 0.1                    # пояс между этажами
const SZ := 0.6                   # толщина стен (доля родной)
const P := 0.72                   # вещи Synty (горшки, скамьи, статуи, фонари) — в масштабе прежних домов
const IN := 0.24                  # от лица стены до облицовки комнаты внутри
const YARD := 1.1                 # двор ремесленника за домом (прежний след — до z −3,03)
const DZ0 := -0.8                 # домус: задняя стена
const DZ1 := 2.96                 # домус: фасад
const PZ := 3.55                  # домус: ось колонн портика (их лицо — у прежней линии 3,67)
const GZ := -3.6                  # домус: задняя ограда сада
const TZ := -3.18                 # городской домус: задняя ограда садика

const WARM := Color(0.3, 0.18, 0.09)
const FURN := {}                  # мебель за дверью — обычные детали (свет в комнате — от её стен «#room», а не от вещей)
const QUOIN := {"tints": {"Building_Large_Brick_01": Color(1.0, 0.92, 0.78)}}
const STONE := {"tints": {"Building_Large_Brick_01": Color(1.0, 0.92, 0.78)}}
const PIL := {"Building_Large_Brick_01": "Building_Marble_01"}
const FRIEZE := {"Stucco_Blue_01": "Building_Marble_03"}
const MARBLE_FLOOR := {"Stone_01": "Building_Marble_01"}
const WOOD := {"Stone_01": "Wood_02"}
const ROOFS := ["Roof_Tile_01", "Roof_Tile_03", "Roof_Tile_12"]
const LEAVES := ["SM_Bld_Door_01", "SM_Bld_Door_02", "SM_Bld_Door_05"]
const TOPPERS := [1, 2, 3, 5, 6]

## Модули стен: деталь Synty. W — гладкая штукатурка; S — окно со ставнями (Life), N — то же без ставен; P — окно
## с фронтончиком, Q — оно же со ставнями; T — узкое окошко; R — три окошка; H — длинное окно; D — дверь (створка
## Synty, Life); B — дверь на балкон (две створки); E — дверь в каменной арке; G — парадная двустворчатая дверь
## в каменной арке с мрамором; O — открытая мастерская (прилавок, за ним — тёплая комната); «-» — ничего
const MOD := {"W": "SM_Bld_Wall_01", "S": "SM_Bld_Wall_Window_01", "N": "SM_Bld_Wall_Window_01", "P": "SM_Bld_Wall_Window_05",
	"Q": "SM_Bld_Wall_Window_05", "T": "SM_Bld_Wall_Window_03", "R": "SM_Bld_Wall_Window_02", "H": "SM_Bld_Wall_Window_04",
	"D": "SM_Bld_Wall_Door_04", "B": "SM_Bld_Wall_Door_04", "E": "SM_Bld_Wall_Door_03", "G": "SM_Bld_Wall_Door_02"}
## Проём двери в родных единицах модуля: начало, конец, высота створки
const DOORS := {"D": [0.75, 1.75, 1.97], "B": [0.75, 1.75, 1.97], "E": [0.75, 1.75, 1.97], "G": [0.75, 1.75, 2.1]}


static func covers(type: String) -> bool:
	return bool(ON.get(type, false))


## Дом type в чертёж b: tier — этажи, variant — облик, color — цвет из палитры (Bp.paint уже покрасил: b.tint)
static func build(b: Bp, type: String, tier: int, variant: int, color: int) -> void:
	var K := Catalog.scale_of(type)
	b.base = Transform3D(Basis.from_scale(Vector3.ONE / K), Vector3.ZERO)
	var x := _ctx(b, type, variant, color)
	var door := Vector3.ZERO
	match type:
		"house_pleb": door = _pleb(b, clampi(tier, 1, 3), posmod(variant, 5), x)
		"house_artisan": door = _artisan(b, clampi(tier, 1, 3), posmod(variant, 5), x)
		_:
			if variant >= Defs.PAT_TOWN:
				door = _town(b, clampi(tier, 1, 3), posmod(variant - Defs.PAT_TOWN, Defs.PAT_TOWN_N), x)
			else:
				door = _domus(b, clampi(tier, 1, 2), posmod(variant, 4), x)
	b.base = Transform3D.IDENTITY
	b.door = door / K
	# лицо фасада (Bp.front_z — им дом встаёт вплотную к дороге) — ровно как у прежних домов: дом в готовых городах
	# и в меню встаёт на то же место (сдвиг — сантиметры, след — в прежних границах)
	var tf: float = FRONT["town" if type == "house_patrician" and variant >= Defs.PAT_TOWN else type]
	var dz := tf / K - b.front_z()
	if absf(dz) > 0.0005 and absf(dz) < 0.2 / K:
		var T := Transform3D(Basis.IDENTITY, Vector3(0, 0, dz))
		for pt: Array in b.parts:
			pt[1] = T * (pt[1] as Transform3D)
		for i in b.lights.size():
			b.lights[i] = b.lights[i] + Vector3(0, 0, dz)
		for ac: Array in b.actors:
			ac[0] = (ac[0] as Vector3) + Vector3(0, 0, dz)
		b.door += Vector3(0, 0, dz)


## Лицо фасада прежних домов (м, test_houses_probe: CatHouses)
const FRONT := {"house_pleb": 1.94, "house_artisan": 2.0, "house_patrician": 3.67, "town": 2.0}


## Раскраски и случай этого дома. Случай не зависит от этажности (Catalog сеет чертёж ключом с tier): у каждого этажа
## свой поток («g» — всё у земли, «f1», «f2» — этажи выше, «roof» — крыша), поэтому при росте нижнее не меняется
static func _ctx(b: Bp, type: String, v: int, color: int) -> Dictionary:
	var t := b.tint
	var key := "%s|%d|%d" % [type, v, color]
	var rs := {}
	for k: String in ["g", "f1", "f2", "roof"]:
		var r := RandomNumberGenerator.new()
		r.seed = hash(key + "|" + k)
		rs[k] = r
	b.rng = rs["g"]
	var ci := posmod(color, 10)
	b.ground_style = "plain"
	b.upper_style = "plain"
	b.roof_tex = ROOFS[(ci + v) % ROOFS.size()] if type != "house_patrician" else ["Roof_Tile_03", "Roof_Tile_12"][(ci + v) % 2]
	var roof := b.floor_remap(1)
	var win := {"Stucco_White_01": "Building_Marble_01", "Stucco_Orange_01": "Stucco_White_01", "tints": {"Stucco_White_01": t}}
	return {"t": t, "v": v, "c": ci, "type": type, "rng": rs,
		"st": {"tints": {"Stucco_White_01": t}},
		"brick": {"Stucco_White_01": "Building_Half_Brick_01", "tints": {"Building_Half_Brick_01": t}},
		"win": win, "roof": roof,
		"shut": CatHouses.SHUTTERS[(ci * 3 + v) % CatHouses.SHUTTERS.size()],
		"leaf": LEAVES[(ci + v) % LEAVES.size()],
		"tp": "SM_Bld_Roof_Topper_0%d" % TOPPERS[(ci * 2 + v) % TOPPERS.size()]}


static func _use(b: Bp, x: Dictionary, k: String) -> void:
	b.rng = (x["rng"] as Dictionary)[k]


# =====================================================================
#   помощники (метры города, фасад к +Z)
# =====================================================================

static func _p(b: Bp, name: String, p: Vector3, yaw := 0.0, s := Vector3.ONE, rm := {}) -> void:
	b.parts.append([name, b.base * Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(s), p), rm])


static func _u(b: Bp, name: String, p: Vector3, yaw: float, s: float, rm := {}) -> void:
	_p(b, name, p, yaw, Vector3.ONE * s, rm)


static func _at(r: Array, side: int, a: float, out := 0.0, y := 0.0) -> Vector3:
	return NewSmall._at(r, side, a, out, y)


static func _yaw(side: int) -> float:
	return NewSmall._yaw(side)


static func _len(r: Array, side: int) -> float:
	return NewSmall._len(r, side)


## Низ этажа f и его высота
static func _fy(f: int) -> float:
	return 0.0 if f == 0 else H0 + E + (f - 1) * (HU + E)


static func _fh(f: int) -> float:
	return H0 if f == 0 else HU


## Верх дома из fl этажей (под карниз)
static func _top(fl: int) -> float:
	return _fy(fl - 1) + _fh(fl - 1)


## Пара модулей фасада: дверь (или что-то) в пролёте i, другое — во втором
static func _pair(i: int, a: String, c: String) -> String:
	return a + c if i == 0 else c + a


## Ярус стен по обходу прямоугольника r (лица стен — по его сторонам) от высоты y высотой h. mods — {сторона: строка
## модулей} (модули поровну по длине стороны). rm_wall — раскраска гладких стен (кирпичный низ). Возвращает
## {"W": [[сторона, начало, ширина]], "D": [[сторона, начало, ширина, вид]], "O": [...], "S": [... окна]}
static func _storey(b: Bp, r: Array, mods: Dictionary, y: float, h: float, x: Dictionary, rm_wall := {}) -> Dictionary:
	var out := {"W": [], "D": [], "O": [], "S": []}
	var st: Dictionary = x["st"] if rm_wall.is_empty() else rm_wall
	var sy := h / 3.01
	for side: int in mods:
		var s: String = mods[side]
		var n := s.length()
		var L := _len(r, side)
		var mw := L / n
		var k := mw / 2.5
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
			var rm: Dictionary = st if c in ["W", "S", "N", "R"] else (STONE if c in ["E", "G"] else x["win"])
			_p(b, nm, _at(r, side, a, -0.11 * SZ, y), _yaw(side), Vector3(k, sy, SZ), rm)
			match c:
				"W":
					out["W"].append([side, a, mw])
				"S", "Q":
					_shutters(b, r, side, a, k, y, sy, x["shut"])
					out["S"].append([side, a, mw])
				"N", "P", "T", "R", "H":
					out["S"].append([side, a, mw])
				"D", "E", "B", "G":
					var d: Array = DOORS[c]
					var dw := (float(d[1]) - float(d[0])) * k
					var dh := float(d[2]) * sy
					var dz := -0.09 * SZ
					if c in ["D", "E"]:
						_p(b, String(x["leaf"]), _at(r, side, a + float(d[0]) * k, dz, y), _yaw(side), Vector3(dw / 1.0, dh / 1.97, 0.7))
					else:
						var hn := "SM_Bld_Door_Half_0%d" % (2 + int(x["c"]) % 2)
						for e in 2:
							_p(b, hn, _at(r, side, a + float(d[0]) * k + e * dw * 0.5, dz, y), _yaw(side), Vector3(dw / 1.0, dh / 1.97, 0.7))
					out["D"].append([side, a, mw, c])
	return out


## Открытая мастерская в модуле: простенки по краям, прилавок из тёсаного камня с мраморной плитой, перемычка над
## проёмом; за ним — тёплая комната (её облицовка — _room с проёмом)
static func _open(b: Bp, r: Array, side: int, a: float, mw: float, y: float, h: float, st: Dictionary, x: Dictionary) -> void:
	var pw := 0.16
	var f := -0.11 * SZ
	var yaw := _yaw(side)
	var top := minf(h - 0.32, 1.5)
	_p(b, "SM_Bld_Wall_01", _at(r, side, a, f, y), yaw, Vector3(pw / 2.5, h / 3.01, SZ), st)
	_p(b, "SM_Bld_Wall_01", _at(r, side, a + mw - pw, f, y), yaw, Vector3(pw / 2.5, h / 3.01, SZ), st)
	_p(b, "SM_Bld_Wall_01", _at(r, side, a + pw, f, y + top), yaw, Vector3((mw - 2.0 * pw) / 2.5, (h - top) / 3.01, SZ), st)
	_p(b, "SM_Bld_Wall_01", _at(r, side, a + pw, f, y), yaw, Vector3((mw - 2.0 * pw) / 2.5, 0.48 / 3.01, SZ), STONE)
	_p(b, "SM_Bld_Wall_Large_Cap_01", _at(r, side, a + pw - 0.02, 0.03, y + 0.46), yaw, Vector3((mw - 2.0 * pw + 0.04) / 5.02, 0.16, 0.26))
	for e: float in [a + pw, a + mw - pw]:
		_p(b, "SM_Bld_Wall_Large_Pillar_01", _at(r, side, e, 0.015, y + 0.48), 0.0, Vector3(0.09, (top - 0.48) / 4.55, 0.09), PIL)


## Ставни (Life): две дощатые створки по бокам окна Synty (середина модуля, подоконник на 0,7 родных); краска — x
static func _shutters(b: Bp, r: Array, side: int, a: float, k: float, y: float, sy: float, col: Color) -> void:
	var rm := {"Stucco_White_01": "Wood_02", "Stucco_Orange_01": "Wood_02", "tints": {"Wood_02": col}}
	var w := 0.475 * k
	var s := Basis.from_scale(Vector3(w / 2.5, 1.35 * sy / 3.0, 0.3))
	var bs := Basis(Vector3.UP, _yaw(side))
	for lx: float in [-0.6 * k - w, 0.6 * k]:
		b.parts.append(["SM_Bld_Wall_01", b.base * Transform3D(bs * s, _at(r, side, a + 1.25 * k + lx, 0.03, y + 0.7 * sy)), rm])


## Пояс (тонкий карниз Synty) по сторонам r на высоте y: тыльной гранью — к лицу стены, по углам чуть внахлёст
static func _band(b: Bp, r: Array, y: float, nm: String, sy := 0.65, sz := 0.8, sides := [0, 1, 2, 3], rm := {}) -> void:
	var o := 0.07
	for side: int in sides:
		var L := _len(r, side)
		_p(b, nm, _at(r, side, -o, -0.11 * sz, y), _yaw(side), Vector3((L + 2.0 * o) / 2.5, sy, sz), rm)


## Каменные углы дома (рустованный камень, тёплый) или мраморные пилястры (у домусов): от y0 до y1
static func _corners(b: Bp, r: Array, y0: float, y1: float, rm: Dictionary, w := 0.2, sides := [0, 1, 2, 3]) -> void:
	var q := w * 0.5 - 0.035
	var s := Vector3(w / 0.92, (y1 - y0) / 4.55, w / 0.92)
	var cs := [Vector2(float(r[0]) + q, float(r[3]) - q), Vector2(float(r[1]) - q, float(r[3]) - q), Vector2(float(r[1]) - q, float(r[2]) + q), Vector2(float(r[0]) + q, float(r[2]) + q)]
	for i in 4:
		if not sides.has(i):
			continue
		var c: Vector2 = cs[i]
		_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(c.x, y0, c.y), 0.0, s, rm)


## Комната внутри коробки r (лица стен) на этаже y..y+h: облицовка стен изнутри (низ — помпейский красный, выше — охра)
## и пол — свои детали «#room…» (room_mesh): днём мягко освещены тёплым (комната за открытой дверью и ставнями — обставленная,
## не чёрная, но сама не светится), ночью — как прежние «#dark»/«#lit»: у жилого дома (Game._show: «#room_*» → «…_lit»)
## еле теплятся, у пустого — темно. lit = false — этаж ночью тёмный и в жилом доме (светятся не все окна дома).
## В передней стене — проёмы gaps [[x0, x1]]; floor_on — пол (видно в дверь)
static func _room(b: Bp, r: Array, y: float, h: float, gaps := [], floor_on := false, lit := true) -> void:
	var x0 := float(r[0]) + IN
	var x1 := float(r[1]) - IN
	var z0 := float(r[2]) + IN
	var z1 := float(r[3]) - IN
	var lo := minf(0.6, h * 0.34)
	var t := 0.03
	var sfx := "" if lit else "_d"
	for band: Array in [[0.0, lo, "#room_lo"], [lo, h - lo - 0.02, "#room_hi"]]:
		var y0 := y + float(band[0])
		var hh := float(band[1])
		var nm := String(band[2]) + sfx
		_rrun(b, nm, Vector3(x1, y0, z0), Vector3(0, 0, 1), z1 - z0, hh, t)
		_rrun(b, nm, Vector3(x0, y0, z1), Vector3(0, 0, -1), z1 - z0, hh, t)
		_rrun(b, nm, Vector3(x0, y0, z0), Vector3(1, 0, 0), x1 - x0, hh, t)
		var xs := [x0]
		for gp: Array in gaps:
			xs.append(clampf(float(gp[0]), x0, x1))
			xs.append(clampf(float(gp[1]), x0, x1))
		xs.append(x1)
		for i in range(0, xs.size(), 2):
			var a: float = xs[i]
			var c: float = xs[i + 1]
			if c - a > 0.05:
				_rrun(b, nm, Vector3(c, y0, z1), Vector3(-1, 0, 0), c - a, hh, t)
	if floor_on:
		_p(b, "#room_fl" + sfx, Vector3(x0, y - 0.02, z1), 0.0, Vector3((x1 - x0) / ROOM_U, 0.03 / ROOM_U, (z1 - z0) / ROOM_U))


## Облицовка «#room…» от a по направлению dir длиной len, высотой h, толщиной t; лицо — влево от направления (внутрь)
static func _rrun(b: Bp, nm: String, a: Vector3, dir: Vector3, len: float, h: float, t: float) -> void:
	_p(b, nm, a, atan2(-dir.z, dir.x), Vector3(len / ROOM_U, h / ROOM_U, t / ROOM_U))


# ---------- свет в комнатах (свои детали «#room…»: Parts._special_mesh, Bp.model_aabb) ----------

## Сторона детали комнаты (м): меньше Parts.SMALL_SHADOW — облицовка внутри дома тени не отбрасывает
const ROOM_U := 0.8
const ROOM_COL := {"lo": Color("a65c48"), "hi": Color("dcc29a"), "fl": Color("b98a62")}
const ROOM_NIGHT := Color("ffa04a")        # как у прежних «#lit»
const ROOM_FILL := 0.16                    # днём: мягкий тёплый свет внутри (доля цвета стены)
static var _room_mats := {}
static var _room_meshes := {}


## Деталь комнаты: коробка ROOM_U (x 0…U вдоль стены, y 0…U вверх, z −U…0 — лицо к +Z), свой материал;
## имена: «#room_lo|hi|fl» (ночью светится у жилого дома), «…_lit» (жилой дом), «…_d» (ночью темно)
static func room_mesh(name: String) -> Mesh:
	if _room_meshes.has(name):
		return _room_meshes[name]
	var k := Kit.new()
	k.boxc(Vector3(ROOM_U * 0.5, ROOM_U * 0.5, -ROOM_U * 0.5), Vector3.ONE * ROOM_U, Color.WHITE, [])
	var m := k.mesh()
	var key := name.trim_prefix("#room_").get_slice("_", 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ROOM_COL.get(key, Color("e3b277"))
	mat.roughness = 1.0
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = ROOM_FILL
	m.surface_set_material(0, mat)
	_room_mats[name] = mat
	_room_meshes[name] = m
	return m


## Подмена деталей комнат у жилого дома (Game._show — рядом с «#dark» → «#lit»)
static func lit_subst(subst: Dictionary) -> void:
	for k: String in ["lo", "hi", "fl"]:
		subst["#room_" + k] = "#room_%s_lit" % k


## Свет комнат по часу (Game: вместе с «#lit»): day — 1 днём, lamp — 1 ночью; днём у всех мягкий тёплый свет внутри,
## ночью у жилых — еле тёплый огонёк, как у прежних окон (те же доли, что у «#lit»), у пустых и «_d» — темно
static func light_rooms(day: float, lamp: float, lh: float) -> void:
	var night := lamp * (0.018 if lh > 23.0 or lh < 4.0 else 0.045)
	for name: String in _room_mats:
		var mat: StandardMaterial3D = _room_mats[name]
		if name.ends_with("_lit"):
			mat.emission = (mat.albedo_color * day + ROOM_NIGHT * (1.0 - day))
			mat.emission_energy_multiplier = ROOM_FILL * day + night * 4.0
		else:
			mat.emission_energy_multiplier = ROOM_FILL * day


## Светится ли ночью этаж f жилого дома: первый — всегда, выше — два этажа из трёх (у соседей — разные)
static func _lit(x: Dictionary, f: int) -> bool:
	return f == 0 or (int(x["c"]) + int(x["v"]) + f) % 3 != 0


## Проёмы передней стены (вдоль x) — для облицовки комнаты: двери и мастерские из ответа _storey
static func _gaps(r: Array, res: Dictionary) -> Array:
	var g := []
	for e: Array in res["D"]:
		if int(e[0]) != 0:
			continue
		var d: Array = DOORS[String(e[3])]
		var k := float(e[2]) / 2.5
		g.append([float(r[0]) + float(e[1]) + float(d[0]) * k - 0.04, float(r[0]) + float(e[1]) + float(d[1]) * k + 0.04])
	for e: Array in res["O"]:
		if int(e[0]) == 0:
			g.append([float(r[0]) + float(e[1]) + 0.14, float(r[0]) + float(e[1]) + float(e[2]) - 0.14])
	return g


## Середина модуля i передней стороны r (x) при n модулях
static func _mx(r: Array, i: int, n := 2) -> float:
	var mw := (float(r[1]) - float(r[0])) / n
	return float(r[0]) + mw * (i + 0.5)


# ---------- крыши ----------

static func _fp(b: Bp, frame: Transform3D, nm: String, p: Vector3, yaw: float, s: Vector3, rm: Dictionary) -> void:
	b.parts.append([nm, b.base * frame * Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(s), p), rm])


## Двускатная черепичная крыша над r (линии стен): конёк вдоль X или вдоль Z (фронтоном к улице). rise — подъём конька;
## front/back — торцы. Возвращает высоту конька
static func _gable(b: Bp, r: Array, top: float, rise: float, along_z: bool, x: Dictionary, front := true, back := true) -> float:
	var rm: Dictionary = x["roof"]
	var L := (float(r[3]) - float(r[2])) if along_z else (float(r[1]) - float(r[0]))
	var S := (float(r[1]) - float(r[0])) if along_z else (float(r[3]) - float(r[2]))
	var frame := Transform3D(Basis(Vector3.UP, -PI / 2 if along_z else 0.0), Vector3((float(r[0]) + float(r[1])) / 2.0, 0, (float(r[2]) + float(r[3])) / 2.0))
	var k := S / 2.0 / 2.5
	var ky := rise / (0.75 * k)
	var n := maxi(1, int(round(L / 2.5)))
	var seg := L / n
	var hx := L / 2.0
	var hz := S / 2.0
	for i in n:
		_fp(b, frame, "SM_Bld_Roof_Base_Straight_01", Vector3(-hx + i * seg, top, hz), 0.0, Vector3(seg / 2.5, k * ky, k), rm)
		_fp(b, frame, "SM_Bld_Roof_Base_Straight_01", Vector3(hx - i * seg, top, -hz), PI, Vector3(seg / 2.5, k * ky, k), rm)
		_fp(b, frame, "SM_Bld_Roof_Edge_Straight_01", Vector3(-hx + i * seg, top, hz), 0.0, Vector3(seg / 2.5, P, P), rm)
		_fp(b, frame, "SM_Bld_Roof_Edge_Straight_01", Vector3(hx - i * seg, top, -hz), PI, Vector3(seg / 2.5, P, P), rm)
	# торцы: −X (при коньке вдоль Z — фасад) и +X
	var ends := []
	if back or not along_z:
		ends.append_array([[Vector3(-hx, top, hz), 0.0], [Vector3(-hx, top, -hz), PI]])
	if front or not along_z:
		ends.append_array([[Vector3(hx, top, -hz), PI], [Vector3(hx, top, hz), 0.0]])
	for c: Array in ends:
		_fp(b, frame, "SM_Bld_Roof_Base_Straight_Side_01", c[0], c[1], Vector3(P, k * ky, k), rm)
	if b.chance(0.6):
		_fp(b, frame, "SM_Bld_Roof_Detail_0%d" % (1 + b.rng.randi() % 2), Vector3(-hx, top, hz), 0.0, Vector3(seg / 2.5, k * ky, k), rm)
	var ridge := top + 0.75 * k * ky
	var tp: String = x["tp"]
	for e: float in [-hx + 0.08, hx - 0.08]:
		_fp(b, frame, tp, Vector3(e, ridge - 0.03, 0), PI / 2, Vector3.ONE * P * 0.85, {})
	return ridge


## Вальмовая (четырёхскатная) крыша над r: угловые скаты, на вытянутом доме — конёк посередине
static func _hip(b: Bp, r: Array, top: float, rise: float, x: Dictionary) -> float:
	var rm: Dictionary = x["roof"]
	var w := float(r[1]) - float(r[0])
	var d := float(r[3]) - float(r[2])
	var along_z := d > w + 0.01
	var L := maxf(w, d)
	var S := minf(w, d)
	var frame := Transform3D(Basis(Vector3.UP, PI / 2 if along_z else 0.0), Vector3((float(r[0]) + float(r[1])) / 2.0, 0, (float(r[2]) + float(r[3])) / 2.0))
	var s := S / 2.0 / 2.5
	var ky := rise / (0.75 * s)
	var hx := L / 2.0
	var hz := S / 2.0
	var sc := Vector3(s, s * ky, s)
	_fp(b, frame, "SM_Bld_Roof_Base_Corner_01", Vector3(-hx, top, hz), 0.0, sc, rm)
	_fp(b, frame, "SM_Bld_Roof_Base_Corner_01", Vector3(hx, top, hz), PI / 2, sc, rm)
	_fp(b, frame, "SM_Bld_Roof_Base_Corner_01", Vector3(hx, top, -hz), PI, sc, rm)
	_fp(b, frame, "SM_Bld_Roof_Base_Corner_01", Vector3(-hx, top, -hz), -PI / 2, sc, rm)
	var mid := L - S
	var ridge := top + rise
	if mid > 0.05:
		_fp(b, frame, "SM_Bld_Roof_Base_Straight_01", Vector3(-hx + hz, top, hz), 0.0, Vector3(mid / 2.5, s * ky, s), rm)
		_fp(b, frame, "SM_Bld_Roof_Base_Straight_01", Vector3(hx - hz, top, -hz), PI, Vector3(mid / 2.5, s * ky, s), rm)
	var tp: String = x["tp"]
	if mid > 0.3:
		for e: float in [-hx + hz, hx - hz]:
			_fp(b, frame, tp, Vector3(e, ridge - 0.03, 0), PI / 2, Vector3.ONE * P * 0.85, {})
	else:
		_fp(b, frame, tp, Vector3(0, ridge - 0.03, 0), 0.0, Vector3.ONE * P * 0.85, {})
	return ridge


## Односкатная черепичная кровля (навес двора): низкий край — сторона low_side
static func _lean(b: Bp, r: Array, top: float, rise: float, low_side: int, x: Dictionary) -> void:
	var rm: Dictionary = x["roof"]
	var yaw: float = [0.0, PI / 2, PI, -PI / 2][low_side]
	var L := (float(r[1]) - float(r[0])) if low_side % 2 == 0 else (float(r[3]) - float(r[2]))
	var S := (float(r[3]) - float(r[2])) if low_side % 2 == 0 else (float(r[1]) - float(r[0]))
	var frame := Transform3D(Basis(Vector3.UP, yaw), Vector3((float(r[0]) + float(r[1])) / 2.0, 0, (float(r[2]) + float(r[3])) / 2.0))
	var k := S / 2.5
	var ky := rise / (0.75 * k)
	_fp(b, frame, "SM_Bld_Roof_Base_Straight_01", Vector3(-L / 2.0, top, S / 2.0), 0.0, Vector3(L / 2.5, k * ky, k), rm)
	_fp(b, frame, "SM_Bld_Roof_Edge_Straight_01", Vector3(-L / 2.0, top, S / 2.0), 0.0, Vector3(L / 2.5, P, P), rm)
	_fp(b, frame, "SM_Bld_Roof_Base_Straight_Side_01", Vector3(-L / 2.0, top, S / 2.0), 0.0, Vector3(P, k * ky, k), rm)
	_fp(b, frame, "SM_Bld_Roof_Base_Straight_Side_01", Vector3(L / 2.0, top, S / 2.0), 0.0, Vector3(P, k * ky, k), rm)


## Плоская крыша-терраса над r на высоте y: пол из плит, парапет по сторонам rails (в цвет дома)
static func _terrace(b: Bp, r: Array, y: float, x: Dictionary, rails := [0, 1, 2, 3], rail := "SM_Bld_Wall_Balcony_04") -> void:
	var w := float(r[1]) - float(r[0])
	var d := float(r[3]) - float(r[2])
	_p(b, "SM_Bld_Roof_Base_Flat_02", Vector3(float(r[0]), y - 0.7, float(r[3])), 0.0, Vector3(w / 2.5, 1.0, d / 2.5), x["roof"])
	for side: int in rails:
		var L := _len(r, side)
		var rh := 0.55 if rail == "SM_Bld_Wall_Balcony_04" else 0.5
		_p(b, rail, _at(r, side, 0.0, -0.11 * SZ, y), _yaw(side), Vector3(L / 2.5, rh / 1.01, SZ), x["win"])


## Пергола с лозой над прямоугольником (x0..x1, z0..z1) на высоте y (столбы высотой h)
static func _pergola(b: Bp, x0: float, x1: float, z0: float, z1: float, y: float, h := 1.45, posts := [0, 1, 2, 3], vs := 0.8) -> void:
	var cs := [Vector3(x0 + 0.08, y, z1 - 0.08), Vector3(x1 - 0.08, y, z1 - 0.08), Vector3(x1 - 0.08, y, z0 + 0.08), Vector3(x0 + 0.08, y, z0 + 0.08)]
	for i in 4:
		if posts.has(i):
			_p(b, "SM_Bld_Trellis_Pillar_01", cs[i], 0.0, Vector3(P * 0.6, h / 3.13, P * 0.6))
	_p(b, "SM_Bld_Trellis_Roof_01", Vector3(x1, y + h, z0), 0.0, Vector3((x1 - x0) / 2.5, P * 0.7, (z1 - z0) / 2.5))
	var a := b.rng.randf() * TAU
	_u(b, "SM_Env_Vine_0%d" % (1 + b.rng.randi() % 3), Vector3((x0 + x1) * 0.5, y + h, (z0 + z1) * 0.5), a, P * vs)
	if (x1 - x0) > 2.0:
		_u(b, "SM_Env_Vine_0%d" % (1 + b.rng.randi() % 3), Vector3((x0 + x1) * 0.5 + 0.5, y + h, (z0 + z1) * 0.5 + 0.2), a + PI / 2, P * vs * 0.88)


# ---------- наполнение ----------

## Фонарик на стене у двери (у жилого дома ночью еле теплится) — один свет на дом
static func _lamp(b: Bp, p: Vector3, yaw := 0.0) -> void:
	_u(b, "#wall_lamp", p, yaw, P)
	b.light(p + Vector3(0, -0.14, 0.28).rotated(Vector3.UP, yaw))


## Горшок с цветами на земле (его поливают жильцы)
static func _pot(b: Bp, p: Vector3, s := 0.3) -> void:
	_u(b, "SM_Prop_FlowerPot_Fancy_01", p + Vector3(0, 0.57 * s, 0), b.rng.randf() * TAU, s)


## Цветник под окном первого этажа (на фасаде: его поливают жильцы, Life._find_water)
static func _fbed(b: Bp, r: Array, a: float, mw: float, y: float) -> void:
	var s := minf(0.42, mw * 0.32)
	_p(b, "SM_Prop_FlowerBed_0%d" % (1 + b.rng.randi() % 2), _at(r, 0, a + mw * 0.5, 0.13, y + 0.22), 0.0, Vector3(s * 1.1, s, s * 0.9))


## Ящик с цветами под окном верхнего этажа
static func _wbox(b: Bp, r: Array, side: int, a: float, mw: float, y: float) -> void:
	var k := mw / 2.5
	_p(b, "#window_box", _at(r, side, a + 1.25 * k, 0.0, y + 0.66 * (HU / 3.01)), _yaw(side), Vector3(minf(0.7, 1.4 * k), 0.75, 0.6))


## Вещь на мостовой перед фасадом (x — вдоль фасада): задней кромкой — в 0,12 м от лица стены, на земле. Ближе нельзя:
## вещь вошла бы в след дома на земле (Bp.footprint пропускает мелочь перед фасадом), а фасад встаёт вплотную к дороге
static func _front(b: Bp, nm: String, x: float, s: float, yaw := 0.0, rm := {}) -> void:
	var box := Bp.model_aabb(nm)
	var bs := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * s)
	var zmin := INF
	for i in 8:
		zmin = minf(zmin, (bs * box.get_endpoint(i)).z)
	_p(b, nm, Vector3(x, -box.position.y * s, Z1 + 0.12 - zmin), yaw, Vector3.ONE * s, rm)


static func _fpot(b: Bp, x: float, s := 0.26) -> void:
	_front(b, "SM_Prop_FlowerPot_Fancy_01", x, s)


static func _fjar(b: Bp, x: float, s := 0.45) -> void:
	_front(b, b.pick(["SM_Prop_Vase_02", "SM_Prop_Vase_05", "SM_Prop_Vase_01", "SM_Prop_Jar_01", "SM_Prop_Vase_03"]), x, s, b.rng.randf() * TAU)


static func _fbench(b: Bp, x: float) -> void:
	_front(b, "SM_Prop_Seat_Bench_01", x, 0.5)


## Скамья у стены (Life: жители присаживаются)
static func _bench(b: Bp, p: Vector3, yaw := 0.0) -> void:
	_p(b, "SM_Prop_Seat_Bench_01", p, yaw, Vector3.ONE * 0.5)


## Плющ с цветами на гладком модуле стены
static func _ivy(b: Bp, r: Array, e: Array, y: float, h: float, k := 0) -> void:
	var side: int = e[0]
	var s := minf(0.5, float(e[2]) / 2.6)
	_u(b, "SM_Env_Ivy_Flowers_0%d" % (1 + (k + side) % 4), _at(r, side, float(e[1]) + float(e[2]) * 0.5, 0.03, y + h * 0.6), _yaw(side), s)


## Висячий горшок с цветами на кронштейне
static func _hang(b: Bp, r: Array, side: int, a: float, y: float) -> void:
	_u(b, "SM_Prop_FlowerPot_Hanging_0%d" % (4 + b.rng.randi() % 3), _at(r, side, a, 0.02, y), _yaw(side), 0.4)


## Амфора или кувшин у стены
static func _jar(b: Bp, p: Vector3, s := 0.45) -> void:
	_u(b, b.pick(["SM_Prop_Vase_02", "SM_Prop_Vase_05", "SM_Prop_Vase_01", "SM_Prop_Jar_01", "SM_Prop_Vase_03"]), p, b.rng.randf() * TAU, s)


## Каменная ступень у двери
static func _step(b: Bp, r: Array, cx: float, w: float) -> void:
	_p(b, "SM_Bld_Floor_Trim_01", Vector3(cx - w * 0.5, 0.0, float(r[3]) - 0.02), 0.0, Vector3(w / 2.5, 0.75, 0.3))


## Бельё на верёвке (два шеста, верёвка, туники и простыня) — на балконе или террасе, лицом yaw; p — середина у стены
static func _laundry(b: Bp, p: Vector3, yaw := 0.0, s := 0.5) -> void:
	_p(b, "#laundry", p, yaw, Vector3(s, s * 1.05, s))


## Черепичный козырёк над проёмом (центр cx, низ y)
static func _hood(b: Bp, r: Array, cx: float, y: float, w: float) -> void:
	_p(b, "SM_Prop_Overhang_01", Vector3(cx, y, float(r[3]) + 0.02), 0.0, Vector3(w / 2.5, 0.95, 0.85))


## Мебель за дверью (видно в открытую дверь): столик с кувшином, табурет, сундук — в тёплом свете
static func _furnish(b: Bp, r: Array, dx: float) -> void:
	var z0 := float(r[2]) + IN
	var ox := float(r[0]) + IN + 0.35 if dx > 0.0 else float(r[1]) - IN - 0.35
	_u(b, "SM_Prop_Table_07", Vector3(dx, 0.0, z0 + 0.55), 0.0, P * 0.8, FURN)
	_u(b, "SM_Prop_Jug_0%d" % (1 + b.rng.randi() % 4), Vector3(dx + 0.05, 0.42, z0 + 0.55), 0.3, P * 0.55, FURN)
	_u(b, b.pick(["SM_Prop_Jar_01", "SM_Prop_Vase_02", "SM_Prop_Basket_05"]), Vector3(ox, 0.0, z0 + 0.3), 0.0, 0.4, FURN)


# =====================================================================
#   дома плебеев
# =====================================================================

## Дом плебеев: коробка 2,8 × 3,76 м, 1–3 этажа, фасад из двух пролётов (дверь и окно), бока — по три модуля
static func _pleb(b: Bp, fl: int, v: int, x: Dictionary) -> Vector3:
	var r := [-X1, X1, -Z1, Z1]
	var di := (int(x["c"]) + v) % 2
	var wi := 1 - di
	var up: Array
	var g0: String
	match v:
		0: g0 = _pair(di, "D", "S"); up = ["SS", "SS"]
		1: g0 = _pair(di, "D", "N"); up = [_pair(di, "B", "S"), "SS"]
		2: g0 = _pair(di, "D", "S"); up = ["QQ", "QQ"]
		3: g0 = _pair(di, "D", "S"); up = [_pair(di, "S", "R"), "SS"]
		_: g0 = _pair(di, "D", "N"); up = ["SS", "SS"]
	var loggia := v == 4 and fl >= 2
	var top := _top(fl)
	var dx := _mx(r, di)
	# этажи
	for f in fl:
		_use(b, x, "g" if f == 0 else ("f1" if f == 1 else "f2"))
		var y := _fy(f)
		var h := _fh(f)
		if loggia and f == fl - 1:
			_loggia(b, r, y, h, di, x)
			continue
		var front: String = g0 if f == 0 else String(up[f - 1])
		var sd1 := "WNH" if f == 0 else ("NSW" if (v + f) % 2 == 0 else "WSN")
		var sd3 := "HNW" if f == 0 else ("WNH" if (v + f) % 2 == 0 else "HNW")
		var bk := "HW" if f == 0 else ("NW" if f % 2 == 1 else "WN")
		var rmw: Dictionary = x["brick"] if v == 2 and f == 0 else {}
		var res := _storey(b, r, {0: front, 1: sd1, 2: bk, 3: sd3}, y, h, x, rmw)
		_room(b, r, y, h, _gaps(r, res), f == 0 or front.contains("B"), _lit(x, f))
		if f > 0:
			for e: Array in res["S"]:
				if int(e[0]) == 0 and v != 2:
					_wbox(b, r, 0, float(e[1]), float(e[2]), y)
			for e: Array in res["D"]:
				if String(e[3]) == "B":
					_balcony(b, r, float(e[1]), float(e[2]), y, x)
		var k := 0
		for e: Array in res["W"]:
			if int(e[0]) == 0:
				continue
			if (k + f + v) % 3 != 2:
				_ivy(b, r, e, y, h, k + v)
			else:
				_hang(b, r, int(e[0]), float(e[1]) + float(e[2]) * 0.5, y + h * 0.62)
			k += 1
		_band(b, r, y + h - 0.02, "SM_Bld_Trim_01" if f < fl - 1 else ("SM_Bld_Trim_03" if v == 2 else "SM_Bld_Trim_02"), 0.6 if f < fl - 1 else 0.55)
	_band(b, r, 0.0, "SM_Bld_Trim_05", 0.5, 0.75)
	_corners(b, r, 0.0, top + 0.12, QUOIN, 0.22)
	# у земли (поток «g»)
	_use(b, x, "g")
	_step(b, r, dx, 0.7)
	_furnish(b, r, dx)
	var wx := _mx(r, wi)
	var mw := float(r[1]) - float(r[0])
	match v:
		0:
			_lamp(b, Vector3(dx + (0.43 if di == 0 else -0.43), 1.66, Z1 + 0.02))
			_fbed(b, r, wi * mw * 0.5, mw * 0.5, 0.0)
			_fpot(b, float(r[0]) + 0.2 if di == 0 else float(r[1]) - 0.2, 0.27)
			_hang(b, r, 0, dx + (-0.4 if di == 0 else 0.4), 1.55)
		1:
			_fbench(b, wx)
			_fjar(b, float(r[0]) + 0.18 if di == 0 else float(r[1]) - 0.18, 0.42)
			_lamp(b, Vector3(dx + (0.43 if di == 0 else -0.43), 1.66, Z1 + 0.02))
			_fpot(b, dx + (0.42 if di == 1 else -0.42), 0.25)
		2:
			_lamp(b, Vector3(dx + (0.43 if di == 0 else -0.43), 1.66, Z1 + 0.02))
			_fbed(b, r, wi * mw * 0.5, mw * 0.5, 0.0)
			_fjar(b, float(r[0]) + 0.18 if di == 0 else float(r[1]) - 0.18, 0.5)
		3:
			_hood(b, r, wx, 1.55, 1.2)
			_fbench(b, wx)
			_fpot(b, dx + (0.42 if di == 1 else -0.42), 0.27)
			_lamp(b, Vector3(dx + (0.43 if di == 0 else -0.43), 1.66, Z1 + 0.02))
		_:
			_lamp(b, Vector3(dx + (0.43 if di == 0 else -0.43), 1.66, Z1 + 0.02))
			_fbench(b, wx)
			for sx: float in [-0.44, 0.44]:
				_fpot(b, dx + sx, 0.24)
	# за домом: корзины и кувшин у задней стены (прежний след — до z −2,12)
	_jar(b, Vector3(float(r[1]) - 0.4, 0.0, -Z1 - 0.07), 0.32)
	_u(b, "SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 5), Vector3(float(r[0]) + 0.45, 0.0, -Z1 - 0.06), 0.3, 0.3)
	# крыша (поток «roof»)
	_use(b, x, "roof")
	var rr := [float(r[0]) + 0.06, float(r[1]) - 0.06, float(r[2]) + 0.06, float(r[3]) - 0.06]
	var eave := top + 0.05
	match v:
		0, 4:
			_hip(b, rr, eave, 0.78, x)
		1:
			_gable(b, rr, eave, 0.8, false, x)
		2:
			var ridge := _gable(b, rr, eave, 0.82, true, x)
			_u(b, "SM_Bld_Ornament_02", Vector3(0.0, eave + (ridge - eave) * 0.34, Z1 + 0.06), 0.0, 0.26)
		_:
			_roof_terrace(b, r, top, di, x)
	return Vector3(dx, 0.0, Z1 + 0.55)


## Деревянный балкон перед дверью B верхнего этажа (модуль a..a+mw фасада), на нём — бельё на верёвке
static func _balcony(b: Bp, r: Array, a: float, mw: float, y: float, x: Dictionary) -> void:
	var cx := float(r[0]) + a + mw * 0.5
	var w := minf(mw * 0.92, 1.3)
	_p(b, "SM_Bld_Balcony_01", Vector3(cx, y + 0.02, Z1 - 0.02), 0.0, Vector3(w / 2.41, 0.62, 0.55))
	_laundry(b, Vector3(cx, y + 0.06, Z1 - 0.05), 0.0, w / 2.3)


## Верхний этаж-лоджия: стена с дверью и окном отступает вглубь, впереди — пол, балюстрада и три колонны под крышей
static func _loggia(b: Bp, r: Array, y: float, h: float, di: int, x: Dictionary) -> void:
	var dep := 0.72
	var rb := [float(r[0]), float(r[1]), float(r[2]), float(r[3]) - dep]
	var res := _storey(b, rb, {0: _pair(di, "B", "S"), 1: "HW", 2: "SW", 3: "WH"}, y, h, x)
	_room(b, rb, y, h, _gaps(rb, res), true)
	# бока лоджии — продолжение боковых стен до фасада
	var side_r := [float(r[0]), float(r[1]), float(r[3]) - dep, float(r[3])]
	_storey(b, side_r, {1: "W", 3: "W"}, y, h, x)
	NewCivic._floor(b, MARBLE_FLOOR, float(r[0]) + 0.1, float(r[3]) - dep, float(r[1]) - 0.1, float(r[3]) - 0.02, y + 0.01, 3.0)
	var bh := 0.48
	_p(b, "SM_Bld_Wall_Balcony_06", Vector3(float(r[0]) + 0.12, y, float(r[3]) - 0.04), 0.0, Vector3((float(r[1]) - float(r[0]) - 0.24) / 2.51, bh / 1.02, 0.42))
	for xx: float in [float(r[0]) + 0.13, 0.0, float(r[1]) - 0.13]:
		_p(b, "SM_Bld_Pillar_06", Vector3(xx, y, float(r[3]) - 0.11), 0.0, Vector3(0.36, h / 3.0, 0.36))
	_pot(b, Vector3(float(r[0]) + 0.35 if di == 1 else float(r[1]) - 0.35, y + 0.01, float(r[3]) - dep + 0.25), 0.24)
	_bench(b, Vector3(_mx(r, 1 - di), y + 0.01, float(r[3]) - dep + 0.2))
	_u(b, "SM_Prop_FlowerPot_Hanging_0%d" % (4 + b.rng.randi() % 3), Vector3(_mx(r, di), y + h - 0.32, float(r[3]) - 0.3), 0.0, 0.36)


## Плоская крыша-терраса над домом: парапет, пергола с лозой над задней половиной, бельё, горшки, столик
static func _roof_terrace(b: Bp, r: Array, top: float, di: int, x: Dictionary) -> void:
	var y := top + 0.04
	_terrace(b, r, y, x)
	_band(b, r, y - 0.06, "SM_Bld_Trim_01", 0.6)
	var zb := float(r[2]) + 0.12
	var zm := zb + 1.55
	_pergola(b, float(r[0]) + 0.08, float(r[1]) - 0.08, zb, zm, y, 1.12, [0, 1], 0.55)
	_bench(b, Vector3(0.0, y, zb + 0.35))
	_laundry(b, Vector3(0.0, y, zm + 0.05), 0.0, 0.5)
	_pot(b, Vector3(float(r[0]) + 0.3, y, float(r[3]) - 0.3), 0.26)
	_pot(b, Vector3(float(r[1]) - 0.3, y, float(r[3]) - 0.3), 0.22)
	_u(b, "SM_Prop_Rug_Drape_01", Vector3(_mx(r, di), y + 0.52, float(r[3]) + 0.02), PI, 0.5)


# =====================================================================
#   дома ремесленников
# =====================================================================

const CRAFT := [0, 3, 2, 1, 2]           # ремесло облика: 0 ткач, 1 гончар, 2 кузнец/медник, 3 зерно

## Дом ремесленников: та же коробка, что у плебеев; внизу мастерская с открытым прилавком (в пролёте si) и дверь
## в каменной арке, наверху жильё; за домом двор под черепичным навесом со снастью ремесла
static func _artisan(b: Bp, fl: int, v: int, x: Dictionary) -> Vector3:
	var r := [-X1, X1, -Z1, Z1]
	var di := (int(x["c"]) + v + 1) % 2
	var si := 1 - di
	var craft: int = CRAFT[v]
	var up: Array
	match v:
		0: up = [_pair(di, "B", "S"), "SS"]
		1: up = [_pair(di, "B", "H"), "SS"]
		2: up = ["QQ", "QQ"]
		3: up = [_pair(si, "S", "R"), "SS"]
		_: up = ["SS", "SS"]
	var loggia := v == 4 and fl >= 2
	var top := _top(fl)
	var dx := _mx(r, di)
	var sx := _mx(r, si)
	for f in fl:
		_use(b, x, "g" if f == 0 else ("f1" if f == 1 else "f2"))
		var y := _fy(f)
		var h := _fh(f)
		if loggia and f == fl - 1:
			_loggia(b, r, y, h, di, x)
			continue
		var front: String = _pair(di, "E", "O") if f == 0 else String(up[f - 1])
		var sd := "WNH" if f == 0 else ("NSW" if f % 2 == 1 else "WSN")
		var rmw: Dictionary = x["brick"] if v == 2 and f == 0 else {}
		var res := _storey(b, r, {0: front, 1: sd, 2: "HW" if f == 0 else "NW", 3: "HNW" if f == 0 else ("WNH" if f % 2 == 1 else "HNW")}, y, h, x, rmw)
		_room(b, r, y, h, _gaps(r, res), f == 0 or front.contains("B"), _lit(x, f))
		if f > 0:
			for e: Array in res["S"]:
				if int(e[0]) == 0 and v != 2 and v != 1:
					_wbox(b, r, 0, float(e[1]), float(e[2]), y)
			for e: Array in res["D"]:
				if String(e[3]) == "B":
					if v == 1:
						_gallery(b, r, y, x)
					else:
						_balcony(b, r, float(e[1]), float(e[2]), y, x)
						if v == 0:
							_u(b, "SM_Prop_Rug_Drape_01", Vector3(float(r[0]) + float(e[1]) + float(e[2]) * 0.5, y + 0.5, Z1 + 0.5), PI, 0.42, CatShops._rug(["01_B", "03_C", "01_C"][int(x["c"]) % 3]))
		var k := 0
		for e: Array in res["W"]:
			if int(e[0]) == 0:
				continue
			if (k + f) % 3 != 2:
				_ivy(b, r, e, y, h, k + v)
			else:
				_hang(b, r, int(e[0]), float(e[1]) + float(e[2]) * 0.5, y + h * 0.62)
			k += 1
		_band(b, r, y + h - 0.02, "SM_Bld_Trim_01" if f < fl - 1 else ("SM_Bld_Trim_03" if v % 2 == 0 else "SM_Bld_Trim_02"), 0.6 if f < fl - 1 else 0.55)
	_band(b, r, 0.0, "SM_Bld_Trim_05", 0.5, 0.75)
	_corners(b, r, 0.0, top + 0.12, QUOIN, 0.22)
	_use(b, x, "g")
	_step(b, r, dx, 0.7)
	_workshop(b, r, si, craft, v, x)
	_lamp(b, Vector3(dx + (0.43 if di == 0 else -0.43), 1.66, Z1 + 0.02))
	_fpot(b, float(r[0]) + 0.17 if di == 0 else float(r[1]) - 0.17, 0.24)
	_yard(b, r, craft, x)
	_use(b, x, "roof")
	var rr := [float(r[0]) + 0.06, float(r[1]) - 0.06, float(r[2]) + 0.06, float(r[3]) - 0.06]
	var eave := top + 0.05
	match v:
		0, 4:
			_hip(b, rr, eave, 0.78, x)
		1:
			_gable(b, rr, eave, 0.8, false, x)
		2:
			var ridge := _gable(b, rr, eave, 0.82, true, x)
			_u(b, "SM_Bld_Ornament_02", Vector3(0.0, eave + (ridge - eave) * 0.34, Z1 + 0.06), 0.0, 0.26)
		_:
			_roof_terrace(b, r, top, di, x)
	return Vector3(dx, 0.0, Z1 + 0.55)


## Мастерская в пролёте si: навес (полотняный у ткача и гончара, черепичный у остальных), товар ремесла на прилавке,
## внутри — снасть ремесла и полки в тёплом свете, вывеска-полотнище у простенка
static func _workshop(b: Bp, r: Array, si: int, craft: int, v: int, x: Dictionary) -> void:
	var mw := (float(r[1]) - float(r[0])) * 0.5
	var x0 := float(r[0]) + si * mw
	var cx := x0 + mw * 0.5
	var z1 := float(r[3])
	if v == 0 or v == 3:
		var pal := CatShops._pal(b)
		CatShops._awning(b, x0 + 0.04, x0 + mw - 0.04, z1 + 0.02, z1 + 0.62, 1.82, 1.58, CatShops.ACCENT[(pal + craft * 3) % CatShops.ACCENT.size()])
		var goods := CatShops._hang_goods(["weaver", "potter", "", "grain"][craft], pal)
		if not goods.is_empty():
			var sc := []
			for g: Array in goods:
				var e := g.duplicate()
				e[1] = (e[1] as Vector3) * 0.72 if e[1] is Vector3 else float(e[1]) * 0.72
				sc.append(e)
			CatShops._hang_row(b, x0 + 0.25, x0 + mw - 0.25, z1 + 0.62, 1.58, sc)
	else:
		_hood(b, r, cx, 1.62, mw * 0.95)
	# товар на прилавке (верх прилавка — 0,5 м)
	var ty := 0.52
	var tz := z1 - 0.05
	match craft:
		0:
			_u(b, "SM_Prop_Rug_Stack_02", Vector3(cx - 0.2, ty, tz), 0.2, 0.36)
			_u(b, "SM_Prop_Rug_Folded_01", Vector3(cx + 0.22, ty, tz), 0.1, 0.32, CatShops._rug(["01_B", "03_C", "01_C"][int(x["c"]) % 3]))
		1:
			_u(b, "SM_Prop_Jug_0%d" % (1 + b.rng.randi() % 4), Vector3(cx - 0.22, ty, tz), 0.4, 0.38)
			_u(b, "SM_Prop_Bowl_0%d" % (1 + b.rng.randi() % 3), Vector3(cx + 0.02, ty, tz), 0.0, 0.26)
			_u(b, "SM_Prop_Vase_04", Vector3(cx + 0.26, ty, tz), 0.5, 0.26)
		2:
			_u(b, "SM_Prop_Tool_Hammer_01", Vector3(cx - 0.18, ty + 0.01, tz), 0.6, 0.9)
			_u(b, "SM_Prop_Plate_0%d" % (1 + b.rng.randi() % 3), Vector3(cx + 0.2, ty, tz), 0.0, 0.55)
		_:
			_u(b, "SM_Prop_Basket_05", Vector3(cx - 0.2, ty, tz), 0.0, 0.32)
			_u(b, "SM_Prop_Sack_0%d" % (1 + b.rng.randi() % 3), Vector3(cx + 0.2, ty, tz), 0.3, 0.3)
	# внутри: снасть ремесла у задней стены, мешки и кувшины, всё в тёплом свете
	var iz := float(r[2]) + IN + 0.42
	var ix := cx
	match craft:
		0: _u(b, "SM_Prop_Loom_01", Vector3(ix, 0.0, iz), 0.0, 0.5, FURN)
		1:
			_u(b, "SM_Prop_Vase_Pile_0%d" % (1 + b.rng.randi() % 6), Vector3(ix, 0.0, iz), 0.0, 0.42, FURN)
			_u(b, "SM_Prop_Jar_01", Vector3(ix + 0.45, 0.0, iz + 0.3), 0.0, 0.42, FURN)
		2:
			_u(b, "SM_Prop_Anvil_01", Vector3(ix, 0.0, iz + 0.3), 0.4, 0.52, FURN)
			_u(b, "SM_Prop_Barrel_01" if Synty.has("SM_Prop_Barrel_01") else "SM_Prop_Jar_01", Vector3(ix + 0.5, 0.0, iz), 0.0, 0.45, FURN)
		_:
			_u(b, "SM_Prop_Sack_Stack_0%d" % (1 + b.rng.randi() % 2), Vector3(ix, 0.0, iz), 0.0, 0.45, FURN)
			_u(b, "SM_Prop_Jar_01", Vector3(ix - 0.45, 0.0, iz + 0.25), 0.0, 0.42, FURN)
	# вывеска-полотнище у простенка мастерской
	var bx := x0 + (mw - 0.06 if si == 0 else 0.06)
	CatShops._sign(b, Vector3(bx, 1.5, z1 + 0.05), 0.0, ["E", "B", "H", "C"][craft], CatShops.ACCENT[(int(x["c"]) + v) % CatShops.ACCENT.size()], 0.34)


## Галерея-менианум на балках вдоль всего фасада второго этажа (деревянный пол, перила крест-накрест)
static func _gallery(b: Bp, r: Array, y: float, x: Dictionary) -> void:
	var dep := 0.42
	var x0 := float(r[0]) + 0.04
	var x1 := float(r[1]) - 0.04
	NewCivic._floor(b, WOOD, x0, Z1, x1, Z1 + dep, y + 0.02, 3.0)
	for xx: float in [x0 + 0.12, 0.0, x1 - 0.12]:
		_p(b, "SM_Prop_Beam_01", Vector3(xx, y - 0.05, Z1 - 0.02), -PI / 2, Vector3((dep + 0.06) / 2.5, 1.2, 0.8))
	_p(b, "SM_Bld_Wall_Balcony_01", Vector3(x0, y + 0.02, Z1 + dep), 0.0, Vector3((x1 - x0) / 2.5, 0.62, 0.6))
	for e: Array in [[x1, PI / 2], [x0, -PI / 2]]:
		var at := Vector3(float(e[0]), y + 0.02, Z1 + dep if float(e[1]) > 0.0 else Z1)
		_p(b, "SM_Bld_Wall_Balcony_01", at, float(e[1]), Vector3(dep / 2.5, 0.62, 0.6))
	_laundry(b, Vector3(x1 - 0.55, y + 0.06, Z1 - 0.04), 0.0, 0.42)
	_u(b, "SM_Prop_Sack_0%d" % (1 + b.rng.randi() % 3), Vector3(x0 + 0.3, y + 0.03, Z1 + 0.2), 0.4, 0.3)


## Двор-мастерская за домом: черепичный навес скатом назад на двух столбах, под ним снасть ремесла. Столбы и снасть —
## на тех же местах и тех же размеров, что у прежнего двора (CatHouses._art_yard): след дома на земле прежний, и
## перестройка плебейского дома в старых городах помещается там же, где помещалась (test_stage6b owner)
const YP := Vector2(0.702, -2.382)       # место снасти прежнего двора (м)
static func _yard(b: Bp, r: Array, craft: int, x: Dictionary) -> void:
	var z1 := float(r[2])
	var z0 := z1 - YARD
	for xx: float in [-1.188, 1.188]:
		_p(b, "SM_Bld_Trellis_Pillar_01", Vector3(xx, 0, -2.922), 0.0, Vector3(0.518, 1.4 / 3.13, 0.518))
	_lean(b, [float(r[0]) + 0.02, float(r[1]) - 0.02, z0, z1], 1.42, 0.38, 2, x)
	# плиты двора землю не занимают (Bp.free_parts): по ним ходят
	b.free_parts[b.parts.size()] = true
	_p(b, "SM_Bld_Floor_Trim_01", Vector3(float(r[0]), 0.0, z0 + 0.02), 0.0, Vector3((float(r[1]) - float(r[0])) / 2.5, 0.5, (YARD - 0.04) / 0.97))
	var p := Vector3(YP.x, 0.0, YP.y)
	# смещения и масштабы прежнего двора: вдоль фасада × 0,54, вглубь × 0,72, вещи × 0,72
	var o := func(dx: float, dz: float) -> Vector3: return p + Vector3(dx * 0.54, 0.0, dz * 0.72)
	match craft:
		0:
			_u(b, "SM_Prop_Loom_01", p, PI + 0.15, 0.54)
			_u(b, "SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 5), o.call(-1.05, 0.35), b.rng.randf() * TAU, 0.504)
		1:
			_u(b, "SM_Prop_Kiln_01", o.call(0.1, -0.1), PI, 0.36)
			_u(b, "SM_Prop_Vase_Pile_0%d" % (1 + b.rng.randi() % 6), o.call(-1.2, 0.2), 0.0, 0.432)
		2:
			_u(b, "SM_Prop_Anvil_01", o.call(0.2, 0.1), 0.4, 0.576)
			_u(b, "SM_Prop_Grinding_Wheel_01", o.call(-0.9, -0.1) + Vector3(0, 0.216, 0), 1.2, 0.576)
		_:
			_u(b, "SM_Prop_Sack_Stack_0%d" % (1 + b.rng.randi() % 2), p, b.rng.randf_range(-0.2, 0.2), 0.504)
			_u(b, "SM_Prop_Jar_01", o.call(-1.05, 0.3), 0.0, 0.54)


# =====================================================================
#   домусы патрициев
# =====================================================================

## Домус: дом 2,8 × 3,76 м за портиком на мраморном подиуме, за домом сад за стенами; 1–2 этажа
static func _domus(b: Bp, fl: int, v: int, x: Dictionary) -> Vector3:
	var r := [-X1, X1, DZ0, DZ1]
	var pd := (int(x["c"]) + v) % 2
	var top := _top(fl)
	var dx := _mx(r, pd)
	for f in fl:
		_use(b, x, "g" if f == 0 else "f1")
		var y := _fy(f)
		var h := _fh(f)
		var front: String = _pair(pd, "G", "P") if f == 0 else (_pair(pd, "B", "Q") if v == 1 else ("QQ" if v % 2 == 0 else "PP"))
		var res := _storey(b, r, {0: front, 1: "WPW" if f == 0 else "WQW", 2: "PW", 3: "WPW" if f == 0 else "WPW"}, y, h, x)
		_room(b, r, y, h, _gaps(r, res), f == 0 or front.contains("B"), _lit(x, f))
		var k := 0
		for e: Array in res["W"]:
			if int(e[0]) != 0 and (k + f) % 2 == 1:
				_ivy(b, r, e, y, h, k + v)
			k += 1
		if f < fl - 1:
			_band(b, r, y + h - 0.02, "SM_Bld_Trim_01", 0.6)
	_band(b, r, 0.0, "SM_Bld_Trim_05", 0.5, 0.75)
	NewSmall._frieze(b, r, top - 0.18)
	_band(b, r, top - 0.02, "SM_Bld_Trim_04", 0.6)
	_corners(b, r, 0.0, top + 0.1, PIL, 0.2)
	_use(b, x, "g")
	_porch(b, r, v, pd, fl, x)
	_furnish(b, r, dx)
	_u(b, "SM_Prop_Statue_0%d" % [3, 5, 6, 7][v], Vector3(float(r[1]) - IN - 0.35 if pd == 0 else float(r[0]) + IN + 0.35, 0.0, float(r[3]) - IN - 0.3), PI, 0.3, FURN)
	_garden(b, r, v, fl, x)
	_use(b, x, "roof")
	var rr := [float(r[0]) + 0.06, float(r[1]) - 0.06, float(r[2]) + 0.06, float(r[3]) - 0.06]
	var eave := top + 0.06
	match v:
		1, 3:
			_hip(b, rr, eave, 0.8, x)
		0:
			_gable(b, rr, eave, 0.82, false, x)
		_:
			var ridge := _gable(b, rr, eave, 0.85, true, x)
			_u(b, "SM_Bld_Ornament_02", Vector3(0.0, eave + (ridge - eave) * 0.34, float(r[3]) + 0.06), 0.0, 0.28)
	return Vector3(dx, 0.0, 4.0)


## Портик домуса: мраморный подиум со ступенью, колонны, крыша по облику (0 — фронтон с медальоном, 1 — лоджия
## с балюстрадой и статуями, 2 — черепичный навес с мраморным архитравом, 3 — пергола с виноградом), фонари
static func _porch(b: Bp, r: Array, v: int, pd: int, fl: int, x: Dictionary) -> void:
	var z0 := float(r[3])
	var x0 := float(r[0])
	var x1 := float(r[1])
	var ph := 0.12
	_p(b, "SM_Bld_Base_Floor_Combined_01", Vector3(x0, ph - 0.01, z0 - 0.05), 0.0, Vector3((x1 - x0) / 2.5, 1.2, (PZ + 0.18 - z0) / 2.5), MARBLE_FLOOR)
	_p(b, "SM_Bld_Floor_Trim_01", Vector3(x0, 0.0, PZ + 0.02), 0.0, Vector3((x1 - x0) / 2.5, 0.75, 0.24))
	var cols := [x0 + 0.16, 0.0, x1 - 0.16] if v != 3 else [x0 + 0.16, x1 - 0.16]
	var ch := 1.72
	var pil := "SM_Bld_Pillar_02" if v == 0 else "SM_Bld_Pillar_06"
	var cs := 0.3 if v == 0 else 0.4
	for xx: float in cols:
		_p(b, pil, Vector3(xx, ph, PZ), 0.0, Vector3(cs, ch / 3.0, cs))
	var top := ph + ch
	var rp := [x0 - 0.02, x1 + 0.02, z0 - 0.05, PZ + 0.2]
	match v:
		0:
			_band(b, [x0, x1, z0, PZ + 0.12], top - 0.02, "SM_Bld_Trim_04", 0.55, 0.8, [0])
			var ridge := _gable(b, rp, top + 0.06, 0.55, true, x, true, false)
			_u(b, "SM_Bld_Ornament_02", Vector3(0.0, top + 0.06 + (ridge - top - 0.06) * 0.36, PZ + 0.24), 0.0, 0.22)
		1:
			_p(b, "SM_Bld_Roof_Base_Flat_02", Vector3(x0, top - 0.62, PZ + 0.2), 0.0, Vector3((x1 - x0) / 2.5, 1.0, (PZ + 0.2 - z0) / 2.5), x["roof"])
			_band(b, [x0, x1, z0, PZ + 0.18], top - 0.02, "SM_Bld_Trim_04", 0.55, 0.8, [0, 1, 3])
			_p(b, "SM_Bld_Wall_Balcony_06", Vector3(x0 + 0.04, top + 0.08, PZ + 0.18), 0.0, Vector3((x1 - x0 - 0.08) / 2.51, 0.45, 0.42))
			for e: Array in [[x1 - 0.02, PI / 2], [x0 + 0.02, -PI / 2]]:
				var at := Vector3(float(e[0]), top + 0.08, PZ + 0.18 if float(e[1]) > 0.0 else z0)
				_p(b, "SM_Bld_Wall_Balcony_06", at, float(e[1]), Vector3((PZ + 0.18 - z0) / 2.51, 0.45, 0.42))
			if fl >= 2:
				for xx: float in [x0 + 0.2, x1 - 0.2]:
					_u(b, "SM_Prop_Statue_0%d" % b.pick([3, 5, 6]), Vector3(xx, top + 0.1, PZ + 0.02), (0.3 if xx < 0.0 else -0.3), 0.24)
				_pot(b, Vector3(0.0, top + 0.1, (z0 + PZ) * 0.5), 0.26)
		2:
			_band(b, [x0, x1, z0, PZ + 0.12], top - 0.02, "SM_Bld_Trim_04", 0.55, 0.8, [0])
			_lean(b, rp, top + 0.08, 0.38, 0, x)
		_:
			_pergola(b, x0 + 0.04, x1 - 0.04, z0 + 0.02, PZ + 0.08, ph, ch, [0, 1])
	# фонари на стене у двери и золотые жаровни у ступени (у двухэтажного — жаровни, у одноэтажного — горшки)
	var dx := _mx(r, pd)
	_lamp(b, Vector3(dx + (0.48 if pd == 0 else -0.48), 1.66, z0 + 0.02))
	for xx: float in [x0 + 0.42, x1 - 0.42]:
		_pot(b, Vector3(xx, ph, PZ - 0.25), 0.25)
	if fl >= 2:
		_u(b, "SM_Prop_Brazier_01", Vector3(dx, 0.0, PZ + 0.42), 0.0, 0.2)
		_u(b, "SM_Prop_Brazier_01_Insert_01", Vector3(dx, 0.0, PZ + 0.42), 0.0, 0.2)
	# мозаичный порог перед дверью
	_p(b, "SM_Bld_Base_Floor_01", Vector3(dx - 0.32, ph + 0.012, z0 + 0.05), 0.0, Vector3(0.64 / 2.5, 1.0, 0.4 / 2.5), {"Stone_01": "Floor_Tiles_0%d" % (1 + int(x["c"]) % 3)})


## Сад за домусом: ограда в цвет дома с каменным поясом, кипарисы, клумбы, дорожка; середина по облику —
## фонтан, пергола с ложем, статуя на постаменте или колодец; садовник за работой
static func _garden(b: Bp, r: Array, v: int, fl: int, x: Dictionary) -> void:
	var z1 := float(r[2])
	var gr := [float(r[0]), float(r[1]), GZ, z1]
	_garden_walls(b, gr, x)
	NewCivic._floor(b, {"Stone_01": "Floor_Tiles_06"}, -0.3, GZ + 0.15, 0.3, z1 - 0.02, 0.012, 3.0)
	NewCivic._cypress(b, Vector3(float(r[0]) + 0.42, 0, GZ + 0.45), 0.42 if fl >= 2 else 0.32)
	NewCivic._cypress(b, Vector3(float(r[1]) - 0.42, 0, GZ + 0.45), 0.3)
	_u(b, "SM_Prop_FlowerBed_02", Vector3(float(r[0]) + 0.5, 0.0, z1 - 0.55), PI / 2, 0.42)
	NewCivic._bush(b, Vector3(float(r[1]) - 0.45, 0.0, z1 - 0.5), 0.22)
	var c := Vector3(0.0, 0.0, (GZ + z1) * 0.5)
	match v:
		0:
			_u(b, "SM_Prop_Fountain_04", c, 0.0, 0.26)
			_u(b, "SM_Prop_Fountain_04_Insert_01", c, 0.0, 0.26)
			_u(b, "SM_Prop_Seat_Bench_03", Vector3(float(r[0]) + 0.35, 0.0, c.z), PI / 2, 0.38)
		1:
			_pergola(b, float(r[0]) + 0.1, float(r[1]) - 0.1, GZ + 0.12, GZ + 1.25, 0.0, 1.5)
			_u(b, "SM_Prop_Seat_Kline_0%d" % (1 + int(x["c"]) % 3), Vector3(0.0, 0.0, GZ + 0.6), 0.0, 0.4)
		2:
			_u(b, "SM_Prop_Pillar_Base_02", c, 0.0, 0.3)
			_u(b, "SM_Prop_Statue_0%d" % [3, 5, 6][int(x["c"]) % 3], c + Vector3(0, 0.45, 0), PI, 0.3)
			_bench(b, Vector3(float(r[0]) + 0.35, 0.0, c.z + 0.2), PI / 2)
		_:
			_u(b, "SM_Prop_Well_01", c, b.rng.randf() * TAU, 0.34)
			_jar(b, Vector3(float(r[0]) + 0.4, 0.0, GZ + 1.1), 0.42)
	b.actor(Vector3(0.8, 0, GZ + 0.7), b.rng.randf() * TAU, "Fixing_Kneeling", "pleb")


## Ограда сада (низкая стена в цвет дома с каменным поясом по верху) по бокам и сзади прямоугольника r
static func _garden_walls(b: Bp, gr: Array, x: Dictionary) -> void:
	var h := 0.85
	_storey(b, gr, {1: "W", 2: "W", 3: "W"}, 0.0, h, x)
	_band(b, gr, h - 0.04, "SM_Bld_Trim_01", 0.7, 0.8, [1, 2, 3])
	_ivy(b, gr, [2, 0.0, float(gr[1]) - float(gr[0])], 0.0, h, int(x["c"]))


# =====================================================================
#   городской домус (после перестройки дома ремесленников)
# =====================================================================

## Городской домус: коробка дома ремесленников (1–3 этажа), парадная дверь под маленьким портиком, мраморные пилястры,
## балкончики с балюстрадой; за домом садик за оградой (k 0 — фонтан, 1 — ложе под перголой)
static func _town(b: Bp, fl: int, k: int, x: Dictionary) -> Vector3:
	var r := [-X1, X1, -Z1, Z1]
	var pd := (int(x["c"]) + k) % 2
	var top := _top(fl)
	var dx := _mx(r, pd)
	for f in fl:
		_use(b, x, "g" if f == 0 else ("f1" if f == 1 else "f2"))
		var y := _fy(f)
		var h := _fh(f)
		var front: String = _pair(pd, "G", "P") if f == 0 else ("QQ" if (f + k) % 2 == 0 else "PP")
		var res := _storey(b, r, {0: front, 1: "WPW" if f == 0 else "WQW", 2: "PW", 3: "WPW"}, y, h, x)
		_room(b, r, y, h, _gaps(r, res), f == 0, _lit(x, f))
		if f > 0:
			var bi := (f + pd) % 2
			_p(b, "SM_Bld_Wall_Balcony_06", Vector3(float(r[0]) + bi * X1 + 0.12, y + 0.02, Z1 + 0.14), 0.0, Vector3((X1 - 0.24) / 2.51, 0.42, 0.36))
			_p(b, "SM_Bld_Base_Floor_Combined_01", Vector3(float(r[0]) + bi * X1 + 0.12, y + 0.03, Z1 - 0.02), 0.0, Vector3((X1 - 0.24) / 2.5, 1.0, 0.18 / 2.5), MARBLE_FLOOR)
		var kk := 0
		for e: Array in res["W"]:
			if int(e[0]) != 0 and (kk + f) % 2 == 1:
				_ivy(b, r, e, y, h, kk + k)
			kk += 1
		if f < fl - 1:
			_band(b, r, y + h - 0.02, "SM_Bld_Trim_01", 0.6)
	_band(b, r, 0.0, "SM_Bld_Trim_05", 0.5, 0.75)
	NewSmall._frieze(b, r, top - 0.18)
	_band(b, r, top - 0.02, "SM_Bld_Trim_04", 0.6)
	_corners(b, r, 0.0, top + 0.1, PIL, 0.2)
	_use(b, x, "g")
	# маленький портик у двери: две колонны, мраморный архитрав, черепичный козырёк, фонари; на ступени — мозаика
	for xx: float in [dx - 0.42, dx + 0.42]:
		_p(b, "SM_Bld_Pillar_06", Vector3(xx, 0.0, Z1 + 0.04), 0.0, Vector3(0.24, 1.62 / 3.0, 0.24))
	_p(b, "SM_Bld_Wall_Large_Cap_01", Vector3(dx - 0.52, 1.6, Z1 - 0.06), 0.0, Vector3(1.04 / 5.02, 0.4, 0.26))
	_hood(b, r, dx, 1.84, 1.1)
	_p(b, "SM_Bld_Floor_Trim_01", Vector3(dx - 0.42, 0.0, Z1 - 0.02), 0.0, Vector3(0.84 / 2.5, 0.75, 0.3), MARBLE_FLOOR)
	_lamp(b, Vector3(dx + (0.62 if pd == 0 else -0.62), 1.66, Z1 + 0.02))
	_fpot(b, float(r[0]) + 0.2 if pd == 1 else float(r[1]) - 0.2, 0.26)
	_fbed(b, r, (1 - pd) * X1, X1, 0.0)
	_furnish(b, r, dx)
	# садик за домом
	var gr := [float(r[0]), float(r[1]), TZ, float(r[2])]
	_garden_walls(b, gr, x)
	NewCivic._cypress(b, Vector3(float(r[0]) + 0.38, 0, TZ + 0.4), 0.4 if fl >= 2 else 0.3)
	_u(b, "SM_Prop_FlowerBed_02", Vector3(float(r[1]) - 0.45, 0.0, (TZ + float(r[2])) * 0.5), -PI / 2, 0.38)
	if k == 0:
		_u(b, "SM_Prop_Fountain_04", Vector3(0.1, 0.0, (TZ + float(r[2])) * 0.5), 0.0, 0.24)
		_u(b, "SM_Prop_Fountain_04_Insert_01", Vector3(0.1, 0.0, (TZ + float(r[2])) * 0.5), 0.0, 0.24)
	else:
		_pergola(b, float(r[0]) + 0.1, float(r[1]) - 0.1, TZ + 0.1, TZ + 1.0, 0.0, 1.45, [0, 1, 2, 3])
		_u(b, "SM_Prop_Seat_Kline_0%d" % (1 + int(x["c"]) % 3), Vector3(0.1, 0.0, TZ + 0.5), 0.0, 0.36)
	b.actor(Vector3(0.75, 0, TZ + 0.45), b.rng.randf() * TAU, "Fixing_Kneeling", "pleb")
	_use(b, x, "roof")
	var rr := [float(r[0]) + 0.06, float(r[1]) - 0.06, float(r[2]) + 0.06, float(r[3]) - 0.06]
	var eave := top + 0.06
	if k == 0:
		_hip(b, rr, eave, 0.8, x)
	else:
		var ridge := _gable(b, rr, eave, 0.85, true, x)
		_u(b, "SM_Bld_Ornament_02", Vector3(0.0, eave + (ridge - eave) * 0.34, Z1 + 0.06), 0.0, 0.26)
	return Vector3(dx, 0.0, Z1 + 0.55)
