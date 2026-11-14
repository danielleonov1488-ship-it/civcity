class_name NewShops2
extends RefCounted
## Новые прилавки рынка, уличные зрелища, огород, приют, кошачья лавка, травник, мастерская скульптора и лудус
## (владелец 13.11: «пересобрать модельки» — новые сборки из деталей Synty POLYGON Ancient Empire, а не украшенные
## прежние; «темноты вообще не должно быть»; у каждой постройки своё основание, без голой земли). Собраны с нуля в метрах
## города (base делит на масштаб Catalog, тот потом умножает обратно), фасад к +Z, вход — b.door.
##  - прилавки (фрукты, овощи, рыба; ≈ 5 м², как прежде): мощёный пятачок, четыре столба, полосатый навес (А — скат
##    к улице, Б — шатёр с коньком), прилавок (А — дощатый стол, Б — каменный в цвет постройки с мраморной плитой),
##    корзины товара лицом к покупателю, полка с товаром за продавцом, ящики и мешки, товар на верёвках, вывеска;
##  - уличные музыканты: низкая дощатая сцена под навесом (А) или под перголой с цветами (Б), скамья музыканта
##    с лирой, танцовщица на сцене, ковёр, корзина для монет, светильник;
##  - игра в кости: стол на мозаике под перголой с лозой (А) или под полосатым навесом (Б), четыре стула (двое
##    играют, два места — жителям, с чашей), кости и монеты на столе, амфоры, кувшин, фонарь;
##  - помост мимов: каменная сцена с дощатым полом и ступенями, расписной задник (фреска посередине, занавеси
##    в боковых дверях, карниз, акротерии), колонны с факелами, гирлянды, скамьи зрителей, жаровни;
##  - кукольный театр: расписная ширма-домик под черепичным фронтоном, окно сцены с куклами и занавесями, факелы,
##    скамейки для детей на ковре, кукольник сбоку;
##  - огород: плетень (А) или низкая каменная ограда (Б) с калиткой, грядки в дощатых бортиках (капуста, салат,
##    бобы на колышках), подсолнухи, пугало, навес с инструментом, тачка, бочка с водой, корзины урожая;
##  - приют: беленый домик под черепицей (тёплая комната за дверью и окнами), скамья с корзинками для кошек,
##    миски; загон за плетнём с навесом, сеном и поилкой (там ослик);
##  - кошачья лавка: розовый домик, открытая лавка с полками подушек и корзинок, розово-белый навес, кошачья
##    лежанка-башенка, корзинка с подушкой, миски; кошки и вещицы — game._pets2 по pets();
##  - травник: зелёный домик с открытой лавкой, под козырьком сушатся пучки трав, банки, горшки с травами;
##  - мастерская скульптора: мастерская с тёплой комнатой и навес с верстаком, двор за низкой оградой: статуя
##    в лесах, вторая незаконченная, глыбы и груда мрамора, готовая статуя на постаменте у входа;
##  - лудус (≈ 51 м², «большие» по линейке, было 39): двухэтажная казарма с кельями (окна в тёплые комнаты, ставни),
##    песчаная арена в каменном бортике, столб-палус, чучела, стойки с оружием, крытая скамья под навесом,
##    низкая стена с воротами, факелами и знамёнами, статуя гладиатора.
## Облик (А/Б) выбирает цвет постройки (FV) и variant: одинаковые постройки в городе не повторяют друг друга.
## Следы прежние (OLD_RECT, замер test_shops2_probe), кроме лудуса: его постройка старого сохранения собирается под
## прежние клетки (Catalog.fit) и растёт, где есть место (City.ladder_grow). Прежние сборки (CatShops, CatExtra,
## CatGrand) остаются: ON — выключатели по типу (снимки «было/стало»); CIVCITY_NEWSHOPS2=0 — прежние во всей игре.

const TYPES := ["stall_fruit", "stall_veg", "stall_fish", "musicians", "dice", "mimes", "puppets", "ogorod", "shelter", "catshop",
	"herbalist", "sculptor", "ludus"]
static var ON := _on_all(OS.get_environment("CIVCITY_NEWSHOPS2") != "0")

## Прежний след в осях постройки (замер test_shops2_probe по прежним сборкам): x0, x1, z0, z1
const OLD_RECT := {"stall_fruit": [-1.15, 0.98, -0.90, 1.73], "stall_veg": [-1.02, 0.98, -0.90, 1.49], "stall_fish": [-0.98, 0.98, -0.90, 1.56],
	"musicians": [-1.13, 1.06, -1.25, 0.79], "dice": [-1.26, 0.95, -0.90, 0.90], "mimes": [-1.81, 1.81, -2.16, 1.94],
	"puppets": [-1.23, 1.51, -0.72, 1.46], "ogorod": [-1.96, 1.96, -1.81, 1.74], "shelter": [-2.13, 3.12, -2.82, 0.42],
	"catshop": [-1.98, 1.98, -1.98, 1.21], "herbalist": [-1.88, 1.89, -1.88, 0.42], "sculptor": [-2.86, 2.85, -2.03, 1.59],
	"ludus": [-3.95, 3.95, -3.43, 1.56]}
## Новый след (кого нет — прежний): лудус по линейке ≈ 51 м²
const FULL := {"ludus": [-4.4, 4.4, -2.9, 2.9]}
## Облик по цвету постройки (палитра Defs.PALETTE — 10 цветов)
const FV := [0, 1, 0, 1, 1, 0, 1, 0, 0, 1]

const Y0 := NewSmall.Y0
const WARM := NewSmall.WARM
const STONE := NewSmall.STONE
const PAVING := NewSmall.PAVING
const MOSAIC := NewSmall.MOSAIC
const WOOD := NewSmall.WOOD
const TYMPANUM := NewSmall.TYMPANUM
const TYM_RED := NewSmall.TYM_RED
const PIL := NewSmall.PIL
const GLOW := {"glow": WARM * 0.4}
const ROSE := Color(1.0, 0.62, 0.66)
const ROSE_TYM := {"Stone_01": "Stucco_Red_01", "tints": {"Stucco_Red_01": Color(1.0, 0.72, 0.74)}}
const SAGE_T := Color(0.74, 0.9, 0.64)
const WHITEWASH := Color(1.0, 0.97, 0.9)
const LUDUS_RED := Color(0.95, 0.56, 0.44)
const GOLD_T := {"tint": Color(1.25, 0.95, 0.45)}
## Цвета полотна (CatShops.CLOTH): навесы, занавеси, вывески
const RED := CatShops.RED
const WHITE := CatShops.WHITE
const PINK := CatShops.PINK
const SKY := CatShops.SKY
const SAGE := CatShops.SAGE
const ORANGE := CatShops.ORANGE
const MUSTARD := CatShops.MUSTARD
const GREEN := CatShops.GREEN
const BLUE := CatShops.BLUE
const PURPLE := CatShops.PURPLE
const MAGENTA := CatShops.MAGENTA
const ACCENT := CatShops.ACCENT
const STALL_COLS := {"fruit": [RED, ORANGE, MAGENTA], "veg": [GREEN, SAGE, MUSTARD], "fish": [SKY, BLUE, SKY]}
const AWN_N := 6                         # полос у навеса прилавка (у всех прилавков одна сетка на цвет)


static func _on_all(v: bool) -> Dictionary:
	var d := {}
	for t: String in TYPES:
		d[t] = v
	return d


static func covers(type: String) -> bool:
	return bool(ON.get(type, false))


## Прежние сборки этих типов (выключатель ON — снимки «было»)
static func old(b: Bp, type: String) -> void:
	match type:
		"stall_fruit": CatShops._stall(b, "fruit", 0)
		"stall_veg": CatShops._stall(b, "veg", 0)
		"stall_fish": CatShops._stall(b, "fish", 0)
		"musicians": CatShops._musicians(b)
		"dice": CatShops._dice(b)
		"mimes": CatShops._mimes(b)
		"ludus": CatGrand.make(b, type)
		_: CatExtra.make(b, type)


## След постройки (x0, x1, z0, z1): лудус — по линейке (или прежние клетки старого сохранения), остальные — прежние
static func frame(type: String, fit: Vector2) -> Array:
	var o: Array = OLD_RECT[type] if (fit != Vector2.ZERO or not FULL.has(type)) else FULL[type]
	return [float(o[0]) + 0.02, float(o[1]) - 0.02, float(o[2]) + 0.02, float(o[3]) - 0.02]


static func build(b: Bp, type: String, variant := 0, color := 0) -> void:
	var K := Catalog.scale_of(type)
	b.base = Transform3D(Basis.from_scale(Vector3.ONE / K), Vector3.ZERO)
	var fv := (int(FV[posmod(color, FV.size())]) + variant) % 2
	var fr := frame(type, Catalog.fit)
	var x := _ctx(b, fv, b.tint)
	x["c"] = posmod(color, 10)
	x["v"] = variant
	var door := Vector3.ZERO
	match type:
		"stall_fruit", "stall_veg", "stall_fish": door = _stall(b, type.trim_prefix("stall_"), fr, x)
		"musicians": door = _musicians(b, fr, x)
		"dice": door = _dice(b, fr, x)
		"mimes": door = _mimes(b, fr, x)
		"puppets": door = _puppets(b, fr, x)
		"ogorod": door = _ogorod(b, fr, x)
		"shelter": door = _shelter(b, fr, x)
		"catshop": door = _catshop(b, fr, x)
		"herbalist": door = _herbalist(b, fr, x)
		"sculptor": door = _sculptor(b, fr, x)
		"ludus": door = _ludus(b, fr, x)
	b.base = Transform3D.IDENTITY
	b.door = door / K


## Раскраски постройки: штукатурка цвета t (оттенок у экземпляра — одна группа деталей на все цвета города)
static func _ctx(b: Bp, fv: int, t: Color) -> Dictionary:
	var x := NewSmall._ctx(b, fv)
	x["t"] = t
	x["st"] = {"tints": {"Stucco_White_01": t}}
	x["win"] = {"Stucco_White_01": "Building_Marble_01", "Stucco_Orange_01": "Stucco_White_01", "tints": {"Stucco_White_01": t}}
	x["door"] = {"Building_Large_Brick_01": "Stucco_White_01", "tints": {"Stucco_White_01": t}}     # оттенок — по картинке после подмены (Synty.material)
	return x


static func _tint(x: Dictionary, t: Color) -> void:
	x["t"] = t
	x["st"] = {"tints": {"Stucco_White_01": t}}
	x["win"] = {"Stucco_White_01": "Building_Marble_01", "Stucco_Orange_01": "Stucco_White_01", "tints": {"Stucco_White_01": t}}
	x["door"] = {"Building_Large_Brick_01": "Stucco_White_01", "tints": {"Stucco_White_01": t}}


# =====================================================================
#   помощники (метры города, фасад к +Z)
# =====================================================================

static func _p(b: Bp, name: String, p: Vector3, yaw := 0.0, s := Vector3.ONE, rm := {}) -> void:
	NewSmall._p(b, name, p, yaw, s, rm)


static func _u(b: Bp, name: String, p: Vector3, yaw: float, s: float, rm := {}) -> void:
	NewSmall._p(b, name, p, yaw, Vector3.ONE * s, rm)


## Деревянный столб (Pole_01) высотой h, толщиной th
static func _post(b: Bp, p: Vector3, h: float, th := 0.12) -> void:
	_p(b, "SM_Prop_Pole_01", p, 0.0, Vector3(th / 0.23, h / 3.0, th / 0.2))


## Брус (Beam_01, вдоль +X) от a длиной len, поворот yaw, толщина k (родная 0,15 × 0,23)
static func _beam(b: Bp, a: Vector3, len: float, yaw := 0.0, k := 0.6) -> void:
	_p(b, "SM_Prop_Beam_01", a, yaw, Vector3(len / 2.5, k, k))


## Колонна (Pillar_06) высотой h, толщиной w
static func _col(b: Bp, p: Vector3, h: float, w := 0.18) -> void:
	_p(b, "SM_Bld_Pillar_06", p, 0.0, Vector3(w / 0.51, h / 3.0, w / 0.51))


## Полосатый навес (CatDress.awning_mesh): от заднего края (zb, yb) к переднему (zf, yf), x0..x1; землю не занимает.
## yaw, pivot — поворот вокруг вертикали через pivot (задний скат шатра)
static func _awn(b: Bp, x0: float, x1: float, zb: float, zf: float, yb: float, yf: float, ca: int, cb: int, n := AWN_N, yaw := 0.0, pivot := Vector3.ZERO) -> void:
	var xf := Transform3D(Basis.from_scale(Vector3(x1 - x0, yb - yf, zf - zb)), Vector3(x0, yb, zb))
	if yaw != 0.0:
		xf = Transform3D(Basis(Vector3.UP, yaw), pivot) * Transform3D(Basis.IDENTITY, -pivot) * xf
	b.free_parts[b.parts.size()] = true
	b.parts.append(["#dress:awning:%d:%d:%d" % [n, posmod(ca, CatShops.CLOTH.size()), posmod(cb, CatShops.CLOTH.size())], b.base * xf, {}])


## Товар на верёвках вдоль x0..x1 под краем навеса (z, y): items — [деталь, масштаб, раскраска?]; землю не занимает
static func _hang(b: Bp, x0: float, x1: float, z: float, y: float, items: Array) -> void:
	var n := items.size()
	for k in n:
		var e: Array = items[k]
		var xx := lerpf(x0, x1, (k + 0.5) / n)
		var ln: float = [0.12, 0.22, 0.16, 0.26][k % 4]
		var top := Vector3(xx, y, z)
		b.free_parts[b.parts.size()] = true
		b.parts.append(["#dress:cord", b.base * Transform3D(Basis.from_scale(Vector3(1, ln, 1)), top), {}])
		var nm := String(e[0])
		var s := float(e[1])
		var hang := Vector3.ZERO
		if not nm.begins_with("#"):
			hang = Vector3(0, Bp.model_aabb(nm).end.y * s, 0)
		b.free_parts[b.parts.size()] = true
		b.parts.append([nm, b.base * Transform3D(Basis(Vector3.UP, k * 1.3) * Basis.from_scale(Vector3.ONE * s), top - Vector3(0, ln, 0) - hang),
			e[2] if e.size() > 2 else {}])


## Полотнище с перекладины: середина верхнего края p, ширина w, длина h, цвет (землю не занимает: «Banner» — Bp.NONSOLID)
static func _sheet(b: Bp, p: Vector3, w: float, h: float, col: int, yaw := 0.0) -> void:
	var bs := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI / 2) * Basis.from_scale(Vector3(w / 2.6, 0.25, h / 2.6))
	b.parts.append(["SM_Prop_Banner_Roof_01", b.base * Transform3D(bs, p + Vector3(-w / 2.0, 0, 0).rotated(Vector3.UP, yaw)), CatShops._cloth(col)])


## Полосатый занавес (та же лёгкая сетка, что у навеса: подзор с зубцами — низ занавеса) от x0 до x1, верх ytop, длина ln
static func _curtain(b: Bp, x0: float, x1: float, ytop: float, ln: float, z: float, ca: int, cb: int, n := 4) -> void:
	var h := ln / (1.0 + CatDress.AWN_VAL)
	b.free_parts[b.parts.size()] = true
	b.parts.append(["#dress:awning:%d:%d:%d" % [n, posmod(ca, CatShops.CLOTH.size()), posmod(cb, CatShops.CLOTH.size())],
		b.base * Transform3D(Basis.from_scale(Vector3(x1 - x0, h, 0.03)), Vector3(x0, ytop, z)), {}])


## Гирлянда-драпировка (Drapery, родная 2,5 м) от x0 до x1 на высоте y, лицом к +Z (или повернута yaw вокруг p0)
static func _swag(b: Bp, x0: float, x1: float, y: float, z: float, col: int, k := 0, yaw := 0.0) -> void:
	var n := maxi(1, int(round((x1 - x0) / 1.1)))
	var w := (x1 - x0) / n
	for i in n:
		var c := Vector3(x0 + (i + 0.5) * w, y, z)
		_p(b, "SM_Prop_Drapery_0%d" % (1 + (k + i) % 3), c, yaw, Vector3(w / 2.5, 0.55, 0.8), CatShops._cloth(col))


## Низкая ограда из тёсаного камня с белой плитой по верху вдоль a → dir длиной len
static func _low_wall(b: Bp, a: Vector3, dir: Vector3, len: float, h := 0.42, rm := STONE) -> void:
	NewCivic._run(b, "SM_Bld_Wall_01", a, dir, len, 2.5, h / 3.01, 0.6, rm, 1.6)
	NewCivic._run(b, "SM_Bld_Wall_Large_Cap_01", a + Vector3(0, h - 0.02, 0), dir, len, 5.02, 0.36, 0.26, {}, 1.6)


## Ограда с расписной балюстрадой: цоколь из тёсаного камня, над ним — балюстрада с меандром (в цвет rm), белая плита
static func _rail_wall(b: Bp, a: Vector3, dir: Vector3, len: float, rm: Dictionary, h := 1.0) -> void:
	var hs := 0.38
	NewCivic._run(b, "SM_Bld_Wall_01", a, dir, len, 2.5, hs / 3.01, 0.6, STONE, 1.6)
	NewCivic._run(b, "SM_Bld_Wall_Balcony_06", a + Vector3(0, hs, 0), dir, len, 2.51, (h - hs) / 1.02, 0.5, rm, 1.3)
	NewCivic._run(b, "SM_Bld_Wall_Large_Cap_01", a + Vector3(0, h - 0.02, 0), dir, len, 5.02, 0.32, 0.26, {}, 1.6)


## Плетень (Fence_Woof) вдоль a → dir длиной len, высотой h; лицом наружу (влево от направления, как NewCivic._run)
static func _wattle(b: Bp, a: Vector3, dir: Vector3, len: float, h := 0.62, k := 0) -> void:
	var yaw := atan2(-dir.z, dir.x)
	var n := maxi(1, int(round(len / 1.3)))
	var st := len / n
	for i in n:
		_p(b, "SM_Env_Fence_Woof_0%d" % [1, 3][(i + k) % 2], a + dir * (st * i), yaw, Vector3(st / 2.46, h / 1.43, 0.8))


## Огонь в чаше-жаровне на земле
static func _brazier(b: Bp, p: Vector3, s := 0.42) -> void:
	_u(b, "SM_Prop_Brazier_03", p, 0.0, s)
	_u(b, "SM_Prop_Brazier_03_Insert_01", p, 0.0, s)
	NewCivic._fire(b, p + Vector3(0, 0.88 * s, 0), 2.4 * s / 0.42)
	b.light(p + Vector3(0, 1.2 * s + 0.2, 0))


## Факел на стене или столбе: держатель и пламя; свет
static func _torch(b: Bp, p: Vector3, yaw := 0.0, s := 0.9) -> void:
	_u(b, "SM_Prop_Torch_01", p, yaw, s)
	CatDecor._flame(b, p + Vector3(0, 0.2 * s, 0), 0.05 * s / 0.9)
	b.light(p + Vector3(0, 0.35, 0.15).rotated(Vector3.UP, yaw))


## Чан с водой: глиняная чаша, в ней вода
static func _vat(b: Bp, p: Vector3, s := 0.5) -> void:
	_p(b, "SM_Prop_Bowl_02", p, 0.0, Vector3(0.75, 1.6, 0.75) * s)
	b.parts.append(["#water", b.base * Transform3D(Basis.from_scale(Vector3(0.42 * s, 0.02, 0.42 * s)), p + Vector3(0, 0.46 * s, 0)), {}])


## Дом-коробка с тёплой комнатой: ярус стен NewSmall._storey, пилястры, карниз, кровля, нутро _hall.
## o: h — высота, along_z — фронтон к улице, tym — тимпан, mods — модули сторон, frieze — фриз, ivy — плющ на гладком
static func _house(b: Bp, r: Array, x: Dictionary, o: Dictionary) -> Dictionary:
	var H: float = o.get("h", 2.15)
	var res := NewSmall._storey(b, r, o["mods"], Y0, H, x)
	var pil := {}
	for side: int in o["mods"]:
		pil[side] = maxi(1, String(o["mods"][side]).length())
	NewSmall._pilasters(b, r, pil, Y0, H, 0.17)
	if o.get("frieze", true):
		NewSmall._frieze(b, r, Y0 + H - 0.2)
	NewSmall._cornice(b, r, Y0 + H - 0.03, 0.16, 0.08)
	if o.get("ivy", true):
		var k := 0
		for e: Array in res["W"]:
			NewSmall._ivy(b, r, e, Y0, H, k)
			k += 1
	var ridge := NewSmall._roof(b, r, Y0 + H + 0.08, bool(o.get("along_z", false)), o.get("tym", TYM_RED), 0.13)
	res["ridge"] = ridge
	var ir := NewSmall._inner(r, 0.3)
	NewSmall._hall(b, ir, Y0, H - 0.06, NewSmall._gaps(r, res))
	res["ir"] = ir
	b.light(Vector3((float(ir[0]) + float(ir[1])) * 0.5, Y0 + 1.5, (float(ir[2]) + float(ir[3])) * 0.5))
	return res


## Середина модуля из ответа _storey (сторона 0) по x
static func _mod_x(r: Array, e: Array) -> float:
	return float(r[0]) + float(e[1]) + float(e[2]) * 0.5


# =====================================================================
#   прилавки рынка
# =====================================================================

static func _stall(b: Bp, kind: String, fr: Array, x: Dictionary) -> Vector3:
	var fv: int = x["fv"]
	var pal: int = x["c"]
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	var cx := (x0 + x1) * 0.5
	var m := 1.0 if (pal + int(x["v"])) % 2 == 0 else -1.0       # ящики и вывеска — слева или справа
	NewCivic._base(b, x0, x1, z0, z1)
	var cols: Array = STALL_COLS[kind]
	var ca: int = cols[(pal + int(x["v"])) % 3]
	var cb := BLUE if kind == "fish" and (pal + int(x["v"])) % 3 == 2 else WHITE
	var px0 := x0 + 0.12
	var px1 := x1 - 0.12
	var pzb := z0 + 0.13
	var pzf := z1 - 0.16
	var hb := 2.08
	var hf := 1.74
	if fv == 0:
		# навес скатом к улице на четырёх столбах
		for xx: float in [px0, px1]:
			_post(b, Vector3(xx, Y0, pzb), hb)
			_post(b, Vector3(xx, Y0, pzf), hf)
		_beam(b, Vector3(px0, Y0 + hb - 0.05, pzb), px1 - px0, 0.0, 0.5)
		_beam(b, Vector3(px0, Y0 + hf - 0.05, pzf), px1 - px0, 0.0, 0.5)
		_awn(b, px0 - 0.1, px1 + 0.1, pzb - 0.1, z1 + 0.14, Y0 + hb + 0.03, Y0 + hf - 0.07, ca, cb)
	else:
		# шатёр: конёк вдоль улицы на двух высоких столбах, скаты вперёд и назад
		var zr := (pzb + pzf) * 0.5
		var hr := 2.3
		var he := 1.66
		for xx: float in [px0, px1]:
			_post(b, Vector3(xx, Y0, pzb), he)
			_post(b, Vector3(xx, Y0, pzf), he)
			_post(b, Vector3(xx, Y0, zr), hr, 0.13)
		_beam(b, Vector3(px0 - 0.08, Y0 + hr - 0.04, zr), px1 - px0 + 0.16, 0.0, 0.55)
		var hz := (z1 + 0.12 - zr)
		_awn(b, px0 - 0.1, px1 + 0.1, zr, zr + hz, Y0 + hr + 0.02, Y0 + he - 0.06, ca, cb)
		_awn(b, px0 - 0.1, px1 + 0.1, zr, zr + (zr - (z0 - 0.06)), Y0 + hr + 0.02, Y0 + he - 0.06, ca, cb, AWN_N, PI, Vector3(cx, 0, zr))
		_u(b, "SM_Bld_Roof_Topper_0%d" % [3, 5, 6][pal % 3], Vector3(cx, Y0 + hr + 0.04, zr), PI / 2, 0.28)
	# прилавок у переднего края: А — дощатый стол, Б — каменный в цвет постройки с мраморной плитой
	var zc := z1 - 0.36                                   # лицо прилавка
	var cw := px1 - px0 - 0.22
	var top := Y0 + 0.6
	if fv == 0:
		_p(b, "SM_Prop_Table_08", Vector3(cx, Y0, zc - 0.26), 0.0, Vector3(cw / 2.58, 0.6 / 0.78, 0.5 / 1.14))
	else:
		_p(b, "SM_Bld_Wall_Balcony_06", Vector3(cx - cw * 0.5, Y0, zc - 0.22 * 0.85), 0.0, Vector3(cw / 2.51, 0.56 / 1.02, 0.85), x["st"])
		_p(b, "SM_Bld_Wall_Large_Cap_01", Vector3(cx - cw * 0.5 - 0.03, Y0 + 0.55, zc - 0.25), 0.0, Vector3((cw + 0.06) / 5.02, 0.22, 0.58 / 0.9))
		top = Y0 + 0.62
	# товар на прилавке — крупные корзины лицом к покупателю
	var goods: Array = {"fruit": ["apples", "oranges", "plums"], "veg": ["greens", "beets", "grain"], "fish": ["fish", "olives", "fish"]}[kind]
	for k in 3:
		var g: String = goods[(k + pal) % 3]
		var gx := lerpf(cx - cw * 0.34, cx + cw * 0.34, k / 2.0)
		if g == "fish":
			CatShops._fish_tray(b, Vector3(gx, top + 0.03, zc - 0.24), 0.52, k * 0.3)
		else:
			CatShops._basket(b, Vector3(gx, top + 0.05, zc - 0.24), g, 0.52, 0.0, 0.32)
	# продавец за прилавком
	b.actor(Vector3(cx, Y0, zc - 0.82), 0.0, "Idle", "any")
	# за продавцом — полка с товаром и ящики по углам
	var sz := z0 + 0.26
	var sw := minf(1.25, px1 - px0 - 0.5)
	_p(b, "SM_Prop_Shelf_0%d" % (1 + pal % 2), Vector3(cx, Y0, sz), 0.0, Vector3(sw / 2.5, 1.05 / 1.86, 0.42 / 0.8))
	var shelf: Array = {"fruit": [["SM_Prop_Basket_05", 0.32], ["SM_Prop_Jug_05", 0.5], ["SM_Prop_Basket_06", 0.3], ["SM_Prop_Basket_12", 0.36]],
		"veg": [["SM_Prop_Sack_04", 0.3], ["SM_Prop_Basket_05", 0.32], ["SM_Prop_Jar_01", 0.3], ["SM_Prop_Basket_07", 0.3]],
		"fish": [["SM_Prop_Jug_02", 0.3], ["SM_Prop_Vase_03", 0.26], ["SM_Prop_Jar_01", 0.3], ["SM_Prop_Jug_06", 0.28]]}[kind]
	for j in 4:
		var e: Array = shelf[j]
		var sl: Vector2 = CatShops.SHELF_SLOTS[j]
		_u(b, e[0], Vector3(cx + sl.x * sw / 2.5, Y0 + sl.y * 1.05 / 1.86, sz), j * 0.7, e[1])
	var bx := cx + m * (px1 - px0) * 0.5 - m * 0.22
	var ox := cx - m * (px1 - px0) * 0.5 + m * 0.24
	match kind:
		"fruit":
			_u(b, "SM_Prop_Basket_Set_02", Vector3(bx, Y0, z0 + 0.42), 0.0, 0.34)
			_u(b, "SM_Prop_Basket_Set_02_Insert_01", Vector3(bx, Y0, z0 + 0.42), 0.0, 0.34)
			_u(b, "SM_Prop_Basket_Set_01", Vector3(ox, Y0, zc - 0.9), PI / 2, 0.3)
			_u(b, "SM_Prop_Basket_Set_01_Insert_01", Vector3(ox, Y0, zc - 0.9), PI / 2, 0.3)
			CatShops._basket(b, Vector3(bx, Y0, zc - 0.7), "apples", 0.48, 0.5)
			_hang(b, px0 + 0.1, px1 - 0.1, pzf + 0.05, Y0 + hf - 0.12, [["#hp_grapes", 0.45], ["#hp_grapes", 0.4], ["#hp_grapes", 0.45]])
		"veg":
			_u(b, "SM_Prop_Basket_Set_04", Vector3(bx, Y0, z0 + 0.4), PI / 2, 0.36)
			_u(b, "SM_Prop_Basket_Set_04_Insert_01", Vector3(bx, Y0, z0 + 0.4), PI / 2, 0.36, {"tint": CatShops.T_GREEN})
			_u(b, "SM_Prop_Sack_Stack_02", Vector3(ox, Y0, zc - 0.95), PI / 2, 0.36)
			_u(b, "SM_Prop_Straw_Bundle_01", Vector3(bx, Y0, zc - 0.62), 0.4, 0.5)
			for k in 2:
				_u(b, "SM_Env_Crop_Single_02", Vector3(ox + m * k * 0.2, Y0 + 0.02, zc - 0.55 + k * 0.08), k * 1.7, 0.2, {"tint": Color(0.9, 1.05, 0.75)})
			_hang(b, px0 + 0.1, px1 - 0.1, pzf + 0.05, Y0 + hf - 0.12, [["#dress:garlic", 0.8], ["#dress:herbs", 0.65], ["#dress:garlic", 0.75]])
		_:
			_vat(b, Vector3(bx, Y0, zc - 0.78), 0.46)
			_u(b, "SM_Prop_Jar_Pile_01", Vector3(ox, Y0, z0 + 0.42), 0.0, 0.36)
			_u(b, "SM_Prop_Vase_02", Vector3(bx, Y0, z0 + 0.36), 0.0, 0.42)
			CatShops._basket(b, Vector3(ox, Y0, zc - 0.62), "fish", 0.45, 0.3)
			CatShops._hanging_lamp(b, Vector3(cx, Y0 + hf - 0.06, pzf - 0.12), 0.32, false)
	# вывеска — полотнище на переднем столбе, сбоку от покупателей
	var sign_x := px0 if m < 0 else px1
	CatShops._sign(b, Vector3(sign_x - m * 0.04, Y0 + hf - 0.1, pzf + 0.07), 0.0, {"fruit": "C", "veg": "C", "fish": "D"}[kind],
		{"fruit": RED, "veg": GREEN, "fish": BLUE}[kind], 0.3)
	return Vector3(cx, 0, z1 + 0.35)


# =====================================================================
#   уличные музыканты
# =====================================================================

static func _musicians(b: Bp, fr: Array, x: Dictionary) -> Vector3:
	var fv: int = x["fv"]
	var pal: int = x["c"]
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	var cx := (x0 + x1) * 0.5
	NewCivic._base(b, x0, x1, z0, z1)
	# низкая сцена: бортик из тёсаного камня, дощатый пол, по краю — белая плита
	var SH := 0.16
	var sr := [x0 + 0.1, x1 - 0.1, z0 + 0.08, z0 + 1.08]
	for side: int in [0, 1, 3]:
		NewSmall._run(b, "SM_Bld_Wall_01", sr, side, Y0, -0.06, 2.5, SH / 3.01, 0.5, STONE, 1.2)
	NewSmall._run(b, "SM_Bld_Wall_01", sr, 2, Y0, -0.06, 2.5, SH / 3.01, 0.5, STONE, 1.2)
	NewCivic._floor(b, WOOD, float(sr[0]), float(sr[2]), float(sr[1]), float(sr[3]), Y0 + SH, 1.2)
	NewCivic._run(b, "SM_Bld_Wall_Large_Cap_01", Vector3(float(sr[0]) - 0.02, Y0 + SH - 0.04, float(sr[3])), Vector3(1, 0, 0), float(sr[1]) - float(sr[0]) + 0.04, 5.02, 0.18, 0.16, {}, 1.2)
	var ys := Y0 + SH
	_p(b, "SM_Prop_Rug_0%d" % (1 + pal % 4), Vector3(cx + 0.15, ys + 0.004, (float(sr[2]) + float(sr[3])) * 0.5 + 0.05), PI / 2, Vector3(0.32, 0.5, 0.3),
		CatShops._rug(["01_A", "01_B", "03_A", "02_B"][pal % 4]))
	# навес над сценой: А — полосатый на четырёх столбах, Б — пергола в цветущем плюще
	var qx0 := float(sr[0]) + 0.06
	var qx1 := float(sr[1]) - 0.06
	var qz0 := float(sr[2]) + 0.06
	var qz1 := float(sr[3]) - 0.04
	var ph := 1.9
	if fv == 0:
		for xx: float in [qx0, qx1]:
			_post(b, Vector3(xx, ys, qz0), ph + 0.2)
			_post(b, Vector3(xx, ys, qz1), ph)
		_awn(b, qx0 - 0.08, qx1 + 0.08, qz0 - 0.08, qz1 + 0.16, ys + ph + 0.22, ys + ph - 0.06, [RED, BLUE, PURPLE, GREEN, ORANGE][pal % 5], WHITE)
		_swag(b, qx0, qx1, ys + ph - 0.2, qz1 + 0.17, ACCENT[pal], pal)
	else:
		for xx: float in [qx0, qx1]:
			for zz: float in [qz0, qz1]:
				_col(b, Vector3(xx, ys, zz), ph, 0.15)
		for xx: float in [qx0, qx1]:
			_u(b, "SM_Env_Ivy_Pillar_Flowers_0%d" % (1 + (pal + int(xx > 0.0)) % 3), Vector3(xx, ys, qz1), pal * 0.7, 0.5)
		_p(b, "SM_Bld_Trellis_Roof_01", Vector3(qx1 + 0.1, ys + ph, qz0 - 0.1), 0.0, Vector3((qx1 - qx0 + 0.2) / 2.5, 0.5, (qz1 - qz0 + 0.2) / 2.5))
		for k in 2:
			b.parts.append(["SM_Env_Vine_0%d" % (1 + (k + pal) % 2), b.base * Transform3D(Basis(Vector3.UP, 0.0 if k == 0 else PI) * Basis(Vector3.RIGHT, -PI / 2) * Basis.from_scale(Vector3(0.62, 0.5, 0.55)),
				Vector3(cx + (k - 0.5) * 0.7, ys + ph + 0.15, (qz0 + qz1) * 0.5 + (0.25 if k == 0 else -0.25))), {}])
		_swag(b, qx0, qx1, ys + ph - 0.06, qz1 + 0.04, ACCENT[pal], pal)
	# музыкант на скамье (с лирой рядом: People._bench_lyres прячет её, пока он играет), танцовщица
	var mx := float(sr[0]) + 0.55
	var mz := float(sr[2]) + 0.42
	_p(b, "SM_Prop_Seat_Bench_05", Vector3(mx + 0.18, ys, mz - 0.05), 0.0, Vector3(0.36, 0.72, 0.55))
	b.actor(Vector3(mx, ys, mz), 0.0, "Sitting_Talking", "pleb")
	b.parts.append(["SM_Prop_Lyre_01", b.base * Transform3D(Basis(Vector3.UP, 0.4) * Basis(Vector3.RIGHT, -0.25) * Basis.from_scale(Vector3.ONE * 0.62),
		Vector3(mx + 0.52, ys + 0.42, mz - 0.1)), {}])
	b.actor(Vector3(cx + 0.42, ys, float(sr[2]) + 0.66), 0.0, "Dance", "female")
	# у сцены: кувшин и чаша на табурете, светильник, цветы; впереди — корзина для монет
	_u(b, "SM_Prop_Stool_01", Vector3(float(sr[1]) - 0.22, ys, float(sr[2]) + 0.28), 0.6, 0.6)
	_u(b, "SM_Prop_Jug_0%d" % (1 + pal % 4), Vector3(float(sr[1]) - 0.26, ys + 0.2, float(sr[2]) + 0.26), 0.0, 0.3)
	_u(b, "SM_Prop_Goblet_01", Vector3(float(sr[1]) - 0.14, ys + 0.2, float(sr[2]) + 0.34), 0.0, 0.6)
	_u(b, "SM_Prop_Basket_0%d" % (1 + pal % 4), Vector3(cx, Y0, z1 - 0.3), 0.0, 0.36)
	for k in 3:
		_u(b, "SM_Prop_Plate_03", Vector3(cx - 0.08 + k * 0.07, Y0 + 0.12, z1 - 0.3 + (k % 2) * 0.05), k * 1.1, 0.12, GOLD_T)
	var lx := x0 + 0.24 if pal % 2 == 0 else x1 - 0.24
	_u(b, "SM_Prop_Senser_02", Vector3(lx, Y0, z1 - 0.28), 0.0, 0.6)
	b.light(Vector3(lx, Y0 + 0.7, z1 - 0.28))
	NewSmall._pot(b, Vector3(x1 - 0.24 if pal % 2 == 0 else x0 + 0.24, Y0, z1 - 0.26), 0.24)
	NewSmall._bush(b, Vector3(x1 - 0.22 if pal % 2 == 0 else x0 + 0.22, Y0, float(sr[3]) + 0.25), 0.16)
	return Vector3(cx, 0, z1 + 0.35)


# =====================================================================
#   игра в кости
# =====================================================================

static func _dice(b: Bp, fr: Array, x: Dictionary) -> Vector3:
	var fv: int = x["fv"]
	var pal: int = x["c"]
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	NewCivic._base(b, x0, x1, z0, z1)
	NewCivic._floor(b, MOSAIC, -0.72, -0.72, 0.72, 0.72, Y0 + 0.004, 1.5)
	# стол (как прежде — посредине) и четыре стула: двое играют, два места — жителям (Life: за столом — с чашей)
	_p(b, "SM_Prop_Table_07", Vector3(0, Y0, 0), 0.0, Vector3(0.82, 0.53 / 0.55, 0.82))
	var ty := Y0 + 0.53
	for a in 4:
		var q := Vector3(cos(a * PI / 2), 0, sin(a * PI / 2)) * 0.68
		_u(b, "SM_Prop_Seat_Chair_01", q + Vector3(0, Y0, 0), atan2(-q.x, -q.z), 0.66)
	b.actor(Vector3(0.68, Y0, 0), -PI / 2, "Sitting_Talking", "pleb")
	b.actor(Vector3(-0.68, Y0, 0), PI / 2, "Sitting_Idle", "pleb")
	# на столе: стаканчик для костей, три кости, монеты на блюде, кубки
	_u(b, "SM_Prop_Goblet_02", Vector3(0.1, ty, -0.08), 0.0, 0.62)
	for k in 3:
		_p(b, "#marble", Vector3(-0.06 + k * 0.07, ty + 0.018, 0.08 + (k % 2) * 0.05), k * 0.7, Vector3.ONE * 0.036)
	_u(b, "SM_Prop_Plate_03", Vector3(-0.14, ty, -0.06), 0.0, 0.5)
	for k in 4:
		_u(b, "SM_Prop_Plate_03", Vector3(-0.14 + (k % 2) * 0.04, ty + 0.012 + k * 0.006, -0.06 + (k / 2) * 0.03), k * 0.9, 0.11, GOLD_T)
	_u(b, "SM_Prop_Goblet_01", Vector3(0.2, ty, 0.14), 0.0, 0.62)
	# навес: А — пергола с лозой на столбах, Б — полосатый навес
	var px0 := x0 + 0.1
	var px1 := x1 - 0.1
	var pz0 := z0 + 0.1
	var pz1 := z1 - 0.1
	var ph := 1.92
	if fv == 0:
		for xx: float in [px0, px1]:
			for zz: float in [pz0, pz1]:
				_post(b, Vector3(xx, Y0, zz), ph, 0.13)
		_p(b, "SM_Bld_Trellis_Roof_01", Vector3(px1 + 0.08, Y0 + ph, pz0 - 0.08), 0.0, Vector3((px1 - px0 + 0.16) / 2.5, 0.55, (pz1 - pz0 + 0.16) / 2.5))
		for k in 3:
			b.parts.append(["SM_Env_Vine_0%d" % (1 + (k + pal) % 3), b.base * Transform3D(Basis(Vector3.UP, 0.0 if k % 2 == 0 else PI) * Basis(Vector3.RIGHT, -PI / 2) * Basis.from_scale(Vector3(0.6, 0.5, 0.55)),
				Vector3(lerpf(px0 + 0.5, px1 - 0.5, k / 2.0), Y0 + ph + 0.16, (pz0 + pz1) * 0.5 + [0.4, -0.15, 0.3][k])), {}])
		for xx: float in [px0, px1]:
			_u(b, "SM_Env_Ivy_Pillar_0%d" % (1 + pal % 3), Vector3(xx, Y0, pz1), pal * 0.5, 0.48)
	else:
		for xx: float in [px0, px1]:
			_post(b, Vector3(xx, Y0, pz0), ph + 0.12)
			_post(b, Vector3(xx, Y0, pz1), ph - 0.18)
		_awn(b, px0 - 0.1, px1 + 0.1, pz0 - 0.1, pz1 + 0.12, Y0 + ph + 0.15, Y0 + ph - 0.24, [RED, BLUE, PURPLE, GREEN][pal % 4], WHITE)
	# фонарь на цепи над столом
	CatShops._hanging_lamp(b, Vector3(0, Y0 + ph - 0.02, 0), 0.34)
	# по углам: амфоры с вином, кувшин и кубки на табурете, корзина
	var m := 1.0 if pal % 2 == 0 else -1.0
	var ca := x0 + 0.3 if m > 0 else x1 - 0.3            # угол «амфоры»
	var cs := x1 - 0.28 if m > 0 else x0 + 0.28          # угол «табурет»
	_u(b, "SM_Prop_Vase_Pile_0%d" % [2, 5][pal % 2], Vector3(ca, Y0, z0 + 0.3), PI / 2, 0.22)
	_u(b, "SM_Prop_Stool_01", Vector3(cs, Y0, z0 + 0.28), 0.3, 0.46)
	_u(b, "SM_Prop_Jug_02", Vector3(cs - 0.02, Y0 + 0.16, z0 + 0.26), 0.0, 0.28)
	_u(b, "SM_Prop_Vase_04", Vector3(ca, Y0, z1 - 0.26), 0.0, 0.34)
	NewSmall._pot(b, Vector3(cs, Y0, z1 - 0.24), 0.2)
	return Vector3(0, 0, z1 + 0.35)


# =====================================================================
#   помост мимов
# =====================================================================

static func _mimes(b: Bp, fr: Array, x: Dictionary) -> Vector3:
	var fv: int = x["fv"]
	var pal: int = x["c"]
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	var cx := (x0 + x1) * 0.5
	NewCivic._base(b, x0, x1, z0, z1)
	var acc: int = ACCENT[pal]
	# сцена: бортик из тёсаного камня, дощатый пол, по краю — белая плита; ступени сбоку спереди
	var SH := 0.42
	var sr := [x0 + 0.12, x1 - 0.12, z0 + 0.12, z0 + 1.78]
	for side in 4:
		NewSmall._run(b, "SM_Bld_Wall_01", sr, side, Y0, -0.07, 2.5, SH / 3.01, 0.6, STONE, 1.4)
	NewCivic._floor(b, WOOD, float(sr[0]), float(sr[2]), float(sr[1]), float(sr[3]), Y0 + SH, 1.7)
	NewCivic._run(b, "SM_Bld_Wall_Large_Cap_01", Vector3(float(sr[0]) - 0.03, Y0 + SH - 0.05, float(sr[3]) + 0.02), Vector3(1, 0, 0), float(sr[1]) - float(sr[0]) + 0.06, 5.02, 0.2, 0.2, {}, 1.4)
	var ys := Y0 + SH
	var sxs := -1.0 if fv == 0 else 1.0                       # ступени слева (А) или справа (Б)
	var stx := cx + sxs * (float(sr[1]) - float(sr[0])) * 0.33
	for k in 2:
		var hh := SH * (2 - k) / 3.0
		var dz := 0.22 * (k + 1)
		_p(b, "SM_Bld_Wall_01", Vector3(stx - 0.32, Y0, float(sr[3]) + dz * 0.5), 0.0, Vector3(0.64 / 2.5, hh / 3.01, dz / 0.22), STONE)
	# расписной задник: стена в цвет постройки, посредине — фреска, по бокам — двери с занавесями; пилястры, карниз,
	# фриз, акротерии; сзади — ниша со статуей и плющ
	var br := [float(sr[0]) + 0.02, float(sr[1]) - 0.02, float(sr[2]) + 0.02, float(sr[2]) + 0.3]
	var BH := 2.0
	var res := NewSmall._storey(b, br, {0: "LWL", 1: "W", 2: "WWW", 3: "W"}, ys, BH, x)
	# двери задника — без створок Synty (сцена — не вход): занавеси во всю дверь
	var keep := []
	for i in b.parts.size():
		var p: Array = b.parts[i]
		if String(p[0]) == "SM_Bld_Door_04":
			continue
		keep.append(p)
	b.parts = keep
	var mwb := (float(br[1]) - float(br[0])) / 3.0
	var kb := mwb / 2.5
	for e: Array in res["L"]:
		var dx0 := float(br[0]) + float(e[1]) + 0.75 * kb
		var dw := 1.0 * kb
		_curtain(b, dx0 - 0.02, dx0 + dw + 0.02, ys + 1.97 * BH / 3.01 - 0.02, 1.97 * BH / 3.01 - 0.04, float(br[3]) - 0.07, [PURPLE, RED, BLUE][pal % 3], WHITE, 3)
		_p(b, "SM_Prop_Drapery_0%d" % (1 + pal % 3), Vector3(dx0 + dw * 0.5, ys + 1.97 * BH / 3.01 + 0.02, float(br[3]) + 0.03), 0.0, Vector3((dw + 0.2) / 2.5, 0.5, 0.8), CatShops._cloth(acc))
	NewSmall._u(b, "SM_Prop_Mural_0%d" % [1, 2][fv], Vector3(cx, ys + BH * 0.52, float(br[3]) + 0.012), 0.0, minf(0.5, mwb / 2.53 - 0.03))
	NewSmall._u(b, "SM_Prop_Mural_02", Vector3(cx, ys + BH * 0.55, float(br[2]) - 0.012), PI, minf(0.42, mwb / 2.53 - 0.03))
	NewSmall._pilasters(b, br, {0: 3, 1: 1, 2: 3, 3: 1}, ys, BH, 0.16)
	NewSmall._frieze(b, br, ys + BH - 0.2, [0, 2])
	NewSmall._cornice(b, br, ys + BH - 0.03, 0.18, 0.1)
	for e: Array in res["W"]:
		if int(e[0]) == 2 and absf(float(e[1]) - mwb) > 0.1:
			NewSmall._ivy(b, br, e, ys, BH, pal + int(e[1] * 3.0))
	_u(b, "SM_Bld_Ornament_02", Vector3(cx, ys + BH + 0.28, float(br[3]) - 0.1), 0.0, 0.36)
	for sd: float in [-1.0, 1.0]:
		_u(b, "SM_Bld_Ornament_06", Vector3(cx + sd * (mwb * 1.5 - 0.12), ys + BH + 0.18, float(br[3]) - 0.1), 0.0, 0.28)
	# колонны с факелами у краёв сцены, между ними наверху — гирлянда
	var czc := float(sr[2]) + 0.62
	for sd: float in [-1.0, 1.0]:
		var xx := cx + sd * ((float(sr[1]) - float(sr[0])) * 0.5 - 0.16)
		_col(b, Vector3(xx, ys, czc), BH + 0.05, 0.2)
		_torch(b, Vector3(xx, ys + 1.35, czc + 0.12), 0.0, 0.85)
	_beam(b, Vector3(float(sr[0]) + 0.06, ys + BH + 0.02, czc), float(sr[1]) - float(sr[0]) - 0.12, 0.0, 0.6)
	_swag(b, float(sr[0]) + 0.16, float(sr[1]) - 0.16, ys + BH - 0.05, czc + 0.08, acc, pal)
	# гирлянда по краю сцены, реквизит на сцене
	_swag(b, float(sr[0]) + 0.05, float(sr[1]) - 0.05, ys - 0.02, float(sr[3]) + 0.13, ACCENT[(pal + 3) % 10], pal + 1)
	_u(b, "SM_Prop_Basket_10", Vector3(float(sr[0]) + 0.42, ys, float(sr[2]) + 0.62 + 0.5), 0.3, 0.32)
	_u(b, "SM_Prop_Vase_02", Vector3(float(sr[1]) - 0.38, ys, float(sr[2]) + 0.62 + 0.42), 0.0, 0.36)
	_u(b, "SM_Prop_Rug_Folded_0%d" % (1 + pal % 3), Vector3(float(sr[0]) + 0.42, ys + 0.3, float(sr[2]) + 0.62 + 0.5), 0.2, 0.3)
	b.actor(Vector3(cx - 0.56, ys, float(sr[2]) + 1.12), 0.0, "Dance", "any")
	b.actor(Vector3(cx + 0.62, ys, float(sr[2]) + 0.98), 0.0, "Spell_Simple_Idle", "any")
	# зрители: две скамьи (Life — жители садятся смотреть), жаровни по углам
	var bz := float(sr[3]) + 0.75
	for sd: float in [-1.0, 1.0]:
		_p(b, "SM_Prop_Seat_Bench_05", Vector3(cx + sd * 0.78, Y0, bz), 0.0, Vector3(0.5, 0.72, 0.6))
	_p(b, "SM_Prop_Seat_Bench_05", Vector3(cx, Y0, bz + 0.72), 0.0, Vector3(0.62, 0.72, 0.6))
	for sd: float in [-1.0, 1.0]:
		_brazier(b, Vector3(cx + sd * ((x1 - x0) * 0.5 - 0.24), Y0, z1 - 0.26), 0.38)
	return Vector3(cx, 0, z1 + 0.35)


# =====================================================================
#   кукольный театр
# =====================================================================

static func _puppets(b: Bp, fr: Array, x: Dictionary) -> Vector3:
	var fv: int = x["fv"]
	var pal: int = x["c"]
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	NewCivic._base(b, x0, x1, z0, z1)
	var acc: int = ACCENT[pal]
	# ширма-домик: стенки в цвет постройки, окно сцены, черепичный фронтон
	var r := [-0.96, 0.96, z0 + 0.1, z0 + 0.66]
	var H := 1.86
	var wy0 := Y0 + 0.92                                        # окно сцены
	var wy1 := Y0 + 1.48
	var wx0 := -0.62
	var wx1 := 0.62
	var st: Dictionary = x["st"]
	var f := -0.11 * 0.3
	# передняя стенка: низ, верх над окном, простенки
	NewCivic._run(b, "SM_Bld_Wall_01", Vector3(float(r[0]), Y0, float(r[3]) + f), Vector3(1, 0, 0), float(r[1]) - float(r[0]), 2.5, (wy0 - Y0) / 3.01, 0.3, st, 2.0)
	NewCivic._run(b, "SM_Bld_Wall_01", Vector3(float(r[0]), wy1, float(r[3]) + f), Vector3(1, 0, 0), float(r[1]) - float(r[0]), 2.5, (Y0 + H - wy1) / 3.01, 0.3, st, 2.0)
	for e: Array in [[float(r[0]), wx0], [wx1, float(r[1])]]:
		NewCivic._run(b, "SM_Bld_Wall_01", Vector3(float(e[0]), wy0, float(r[3]) + f), Vector3(1, 0, 0), float(e[1]) - float(e[0]), 2.5, (wy1 - wy0) / 3.01, 0.3, st, 2.0)
	# бока и зад — стенки; сзади окна — пурпурный задник
	NewCivic._run(b, "SM_Bld_Wall_01", Vector3(float(r[1]), Y0, float(r[3])), Vector3(0, 0, -1), float(r[3]) - float(r[2]), 2.5, H / 3.01, 0.3, st, 2.0)
	NewCivic._run(b, "SM_Bld_Wall_01", Vector3(float(r[0]), Y0, float(r[2])), Vector3(0, 0, 1), float(r[3]) - float(r[2]), 2.5, H / 3.01, 0.3, st, 2.0)
	NewCivic._run(b, "SM_Bld_Wall_01", Vector3(float(r[1]), Y0, float(r[2])), Vector3(-1, 0, 0), float(r[1]) - float(r[0]), 2.5, H / 3.01, 0.3, st, 2.0)
	_sheet(b, Vector3(0, wy1 + 0.02, float(r[2]) + 0.08), wx1 - wx0 + 0.1, wy1 - wy0 + 0.04, [PURPLE, BLUE, MAGENTA][pal % 3])
	# сзади — дверца кукольника, знамя, плющ (глухой стены нет)
	_p(b, "SM_Bld_Door_04", Vector3(0.3, Y0, float(r[2]) - 0.035), PI, Vector3(0.62, 1.3 / 1.96, 0.5))
	_p(b, "SM_Prop_Banner_01_A", Vector3(-0.42, Y0 + H - 0.12, float(r[2]) - 0.05), PI, Vector3.ONE * 0.42)
	_u(b, "SM_Env_Ivy_Flowers_0%d" % (1 + pal % 4), Vector3(0.62, Y0 + 1.25, float(r[2]) - 0.04), PI, 0.3)
	NewSmall._frieze(b, r, Y0 + H - 0.2, [2])
	# пол сцены (полка под куклами), рама окна, занавеси и драпировка над окном
	_p(b, "SM_Bld_Wall_Large_Cap_01", Vector3(wx0 - 0.02, wy0 - 0.06, float(r[3]) - 0.1), 0.0, Vector3((wx1 - wx0 + 0.04) / 5.02, 0.3, 0.42 / 0.9))
	for xx: float in [wx0, wx1]:
		_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(xx, wy0, float(r[3]) + 0.01), 0.0, Vector3(0.08, (wy1 - wy0) / 4.55, 0.08), PIL)
	for sd: float in [-1.0, 1.0]:
		_sheet(b, Vector3((wx1 if sd > 0.0 else wx0) - sd * 0.1, wy1 - 0.01, float(r[3]) + 0.03), 0.2, wy1 - wy0 - 0.04, acc)
	_swag(b, wx0, wx1, wy1 + 0.02, float(r[3]) + 0.05, acc, pal)
	# низ ширмы — роспись (сценка с колесницей или с воинами), под окном — расписной пояс; над окном — медальон
	_u(b, "SM_Prop_Mural_02", Vector3(0, Y0 + (wy0 - Y0) * 0.48, float(r[3]) + 0.012), 0.0, minf(0.4, (wy0 - Y0 - 0.14) / 1.77))
	NewSmall._frieze(b, r, wy0 - 0.2, [0])
	NewSmall._pilasters(b, r, {0: 1, 1: 1, 2: 1, 3: 1}, Y0, H, 0.14)
	NewSmall._cornice(b, r, Y0 + H - 0.03, 0.12, 0.06)
	_u(b, "SM_Bld_Ornament_0%d" % [2, 6][fv], Vector3(0, wy1 + 0.2, float(r[3]) + 0.02), 0.0, 0.24)
	var ridge := NewCivic._gable_x(b, float(r[0]) - 0.1, float(r[1]) + 0.1, float(r[2]) - 0.1, float(r[3]) + 0.12, Y0 + H + 0.05, TYMPANUM if fv == 0 else ROSE_TYM)
	_u(b, "SM_Bld_Roof_Topper_0%d" % [5, 3][fv], Vector3(0, ridge - 0.02, (float(r[2]) + float(r[3])) * 0.5), PI / 2, 0.3)
	# куклы в окне: рыцарь и купчиха
	b.parts.append(["SM_Prop_Statue_02", b.base * Transform3D(Basis(Vector3.UP, 0.4).scaled(Vector3.ONE * 0.17), Vector3(-0.26, wy0, float(r[3]) - 0.14)), {"tint": Color(1.2, 0.55, 0.45)}])
	b.parts.append(["SM_Prop_Statue_06", b.base * Transform3D(Basis(Vector3.UP, -0.5).scaled(Vector3.ONE * 0.17), Vector3(0.28, wy0, float(r[3]) - 0.14)), {"tint": Color(0.55, 0.75, 1.2)}])
	# факелы по бокам ширмы
	for sd: float in [-1.0, 1.0]:
		_torch(b, Vector3(sd * (float(r[1]) + 0.04), Y0 + 1.42, float(r[3]) - 0.1), sd * PI / 2, 0.8)
	# перед ширмой: ковёр и скамейки для детей
	var fz := float(r[3])
	_p(b, "SM_Prop_Rug_0%d" % (1 + pal % 4), Vector3(0, Y0 + 0.004, (fz + z1) * 0.5 + 0.05), PI / 2, Vector3(0.36, 0.5, 0.3), CatShops._rug(["01_A", "01_B", "03_A", "02_B"][pal % 4]))
	for sd: float in [-1.0, 1.0]:
		_p(b, "SM_Prop_Seat_Bench_01", Vector3(sd * 0.48, Y0, z1 - 0.42), 0.0, Vector3(0.48, 0.5, 0.5))
	# кукольник сбоку, корзина с куклами, вывеска на шесте
	var kx := x1 - 0.32
	b.actor(Vector3(kx, Y0, fz + 0.3), -0.6, "Spell_Simple_Idle", "any")
	_u(b, "SM_Prop_Basket_10", Vector3(kx, Y0, float(r[2]) + 0.25), 0.3, 0.34)
	_u(b, "SM_Prop_Rug_Folded_0%d" % (1 + pal % 3), Vector3(kx, Y0 + 0.2, float(r[2]) + 0.25), 0.5, 0.28)
	_post(b, Vector3(x0 + 0.14, Y0, z1 - 0.2), 1.6, 0.1)
	CatShops._sign(b, Vector3(x0 + 0.14, Y0 + 1.55, z1 - 0.14), 0.0, "B", acc, 0.3)
	NewSmall._pot(b, Vector3(x0 + 0.22, Y0, fz + 0.22), 0.2)
	return Vector3(0, 0, z1 + 0.35)


# =====================================================================
#   огород
# =====================================================================

static func _ogorod(b: Bp, fr: Array, x: Dictionary) -> Vector3:
	var fv: int = x["fv"]
	var pal: int = x["c"]
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	NewCivic._base(b, x0, x1, z0, z1)
	var gw := 0.84                                              # калитка посредине спереди
	var e := 0.08 if fv == 0 else 0.13
	# ограда: А — плетень, Б — низкая каменная стенка; у калитки — столбики
	if fv == 0:
		_wattle(b, Vector3(x0 + e, Y0, z1 - e), Vector3(1, 0, 0), (x1 - x0) * 0.5 - e - gw * 0.5, 0.6, 0)
		_wattle(b, Vector3(gw * 0.5, Y0, z1 - e), Vector3(1, 0, 0), (x1 - x0) * 0.5 - e - gw * 0.5, 0.6, 1)
		_wattle(b, Vector3(x1 - e, Y0, z1 - e), Vector3(0, 0, -1), z1 - z0 - 2.0 * e, 0.6, 0)
		_wattle(b, Vector3(x1 - e, Y0, z0 + e), Vector3(-1, 0, 0), x1 - x0 - 2.0 * e, 0.6, 1)
		_wattle(b, Vector3(x0 + e, Y0, z0 + e), Vector3(0, 0, 1), z1 - z0 - 2.0 * e, 0.6, 0)
		for sd: float in [-1.0, 1.0]:
			_post(b, Vector3(sd * gw * 0.5, Y0, z1 - e), 0.85, 0.12)
	else:
		_low_wall(b, Vector3(x0 + e, Y0, z1 - e), Vector3(1, 0, 0), (x1 - x0) * 0.5 - e - gw * 0.5, 0.42)
		_low_wall(b, Vector3(gw * 0.5, Y0, z1 - e), Vector3(1, 0, 0), (x1 - x0) * 0.5 - e - gw * 0.5, 0.42)
		_low_wall(b, Vector3(x1 - e, Y0, z1 - e), Vector3(0, 0, -1), z1 - z0 - 2.0 * e, 0.42)
		_low_wall(b, Vector3(x1 - e, Y0, z0 + e), Vector3(-1, 0, 0), x1 - x0 - 2.0 * e, 0.42)
		_low_wall(b, Vector3(x0 + e, Y0, z0 + e), Vector3(0, 0, 1), z1 - z0 - 2.0 * e, 0.42)
		for sd: float in [-1.0, 1.0]:
			_p(b, "SM_Prop_Plinth_02", Vector3(sd * (gw * 0.5 + 0.08), Y0, z1 - e - 0.1), 0.0, Vector3(0.42, 0.6, 0.42))
			NewSmall._pot(b, Vector3(sd * (gw * 0.5 + 0.08), Y0 + 0.6, z1 - e - 0.1), 0.18)
	# навес с инструментом у заднего угла: беленые стенки, черепичный скат на двух столбах
	var m := 1.0 if pal % 2 == 0 else -1.0                      # навес справа (А) или слева
	var sw := 1.2
	var sd0 := 0.95
	var shx0 := x1 - e - 0.06 - sw if m > 0 else x0 + e + 0.06
	var shx1 := shx0 + sw
	var shz0 := z0 + e + 0.06
	var shz1 := shz0 + sd0
	var wst := {"tints": {"Stucco_White_01": WHITEWASH.lerp(x["t"], 0.6)}}
	var hb := 1.45
	var hf := 1.2
	NewCivic._run(b, "SM_Bld_Wall_01", Vector3(shx0, Y0, shz0 + 0.06), Vector3(1, 0, 0), sw, 2.5, hb / 3.01, 0.5, wst, 1.4)
	var outer := shx1 if m > 0 else shx0
	NewCivic._run(b, "SM_Bld_Wall_01", Vector3(outer, Y0, shz1) if m > 0 else Vector3(outer, Y0, shz0 + 0.06), Vector3(0, 0, -1) if m > 0 else Vector3(0, 0, 1), sd0 - 0.06, 2.5, hf / 3.01, 0.5, wst, 1.4)
	_u(b, "SM_Env_Ivy_Flowers_0%d" % (1 + pal % 4), Vector3((shx0 + shx1) * 0.5, Y0 + 0.85, shz0 + 0.06 - 0.08), PI, 0.42)
	_u(b, "SM_Env_Ivy_Flowers_0%d" % (1 + (pal + 2) % 4), Vector3(outer + m * 0.08, Y0 + 0.7, (shz0 + shz1) * 0.5), PI / 2 * m, 0.34)
	var inner := shx0 + 0.06 if m > 0 else shx1 - 0.06
	_post(b, Vector3(inner, Y0, shz1 - 0.05), hf, 0.11)
	var ky := (hb - hf) / 1.95
	_p(b, "SM_Bld_Roof_Straight_Thin_Large_01", Vector3(shx0 - 0.08, Y0 + hf - 0.04, shz1 + 0.12), 0.0, Vector3((sw + 0.16) / 7.5, ky, (sd0 + 0.2) / 7.5))
	# под навесом: коса и мотыга у стены, корзина-заплечник, мешок, лейка-кувшин
	CatDecor._lean(b, "SM_Prop_Scythe_01", Vector3((shx0 + shx1) * 0.5 - 0.25, Y0 + 0.4, shz0 + 0.2), 0.0, -0.18, 0.55)
	_u(b, "SM_Prop_Sickle_01", Vector3((shx0 + shx1) * 0.5 + 0.25, Y0 + 1.0, shz0 + 0.14), 0.0, 0.6)
	_u(b, "SM_Prop_Basket_Backpack_01", Vector3((shx0 + shx1) * 0.5 - 0.1, Y0, shz1 - 0.3), 0.4, 0.5)
	_u(b, "SM_Prop_Sack_0%d" % (3 + pal % 3), Vector3(inner + m * 0.3 - m * 0.02, Y0, shz0 + 0.35), 0.4, 0.42)
	_u(b, "SM_Prop_Jug_03", Vector3(outer - m * 0.2, Y0, shz1 - 0.2), 0.0, 0.32)
	_p(b, "SM_Prop_Shelf_01", Vector3((shx0 + shx1) * 0.5 + m * 0.15, Y0, shz0 + 0.24), 0.0, Vector3(0.6 / 2.5, 0.9 / 1.86, 0.3 / 0.8))
	for k in 3:
		_u(b, ["SM_Prop_Vase_03", "SM_Prop_Basket_05", "SM_Prop_Jug_05"][k], Vector3((shx0 + shx1) * 0.5 + m * 0.15 + (k - 1) * 0.17, Y0 + [0.35, 0.58, 0.35][k], shz0 + 0.24), k * 0.8, [0.22, 0.22, 0.32][k])
	# грядки в дощатых бортиках: слева и справа от дорожки к калитке
	var bed_l := [x0 + e + 0.16, -0.32]
	var bed_r := [0.32, x1 - e - 0.16]
	var zf0 := 0.05
	var zf1 := z1 - e - 0.28
	var zb0 := z0 + e + 0.22
	var zb1 := -0.32
	var beds := [[bed_l, [zf0, zf1], 0], [bed_r, [zf0, zf1], 1]]
	if m > 0:
		beds.append([bed_l, [zb0, zb1], 2])
	else:
		beds.append([bed_r, [zb0, zb1], 2])
	for be: Array in beds:
		var bxr: Array = be[0]
		var bzr: Array = be[1]
		var bx0 := float(bxr[0])
		var bx1 := float(bxr[1])
		var bz0 := float(bzr[0])
		var bz1 := float(bzr[1])
		_bed(b, bx0, bx1, bz0, bz1)
		var kind: int = (int(be[2]) + pal) % 3
		var nx := maxi(2, int((bx1 - bx0) / 0.36))
		var nz := maxi(1, int((bz1 - bz0) / 0.42))
		for i in nx:
			for j in nz:
				var p := Vector3(lerpf(bx0 + 0.2, bx1 - 0.2, (i + 0.5) / nx) if nx > 1 else (bx0 + bx1) * 0.5, Y0 + 0.12, lerpf(bz0 + 0.18, bz1 - 0.18, (j + 0.5) / nz))
				match kind:
					0: _u(b, "SM_Env_Crop_Single_02", p, b.rng.randf() * TAU, 0.22, {"tint": Color(0.9, 1.05, 0.75)})
					1: _u(b, "SM_Env_Crop_Single_01", p, b.rng.randf() * TAU, 0.3)
					_:
						if (i + j) % 2 == 0:
							_post(b, p, 0.8, 0.05)
							_p(b, "SM_Env_Ivy_Pillar_0%d" % (1 + (i + j) % 3), p, b.rng.randf() * TAU, Vector3(0.2, 0.3, 0.2))
						else:
							_u(b, "SM_Env_Crop_Single_01", p, b.rng.randf() * TAU, 0.26)
	# подсолнухи у задней ограды (по другую сторону от навеса), пугало в конце дорожки
	var sfx0 := x0 + e + 0.3 if m > 0 else 0.4
	var sfx1 := -0.4 if m > 0 else x1 - e - 0.3
	for k in 3:
		_u(b, "M:SM_Env_Sunflower_01", Vector3(lerpf(sfx0, sfx1, k / 2.0), Y0, z0 + e + 0.3), k * 1.3, 0.5)
	_u(b, "M:SM_Prop_ScareCrow_01", Vector3(0, Y0, (zb0 + zb1) * 0.5 - 0.1), 0.15 * m, 0.28)
	# у дорожки: бочка с водой, корзины урожая; тачка у навеса
	_vat(b, Vector3(-m * 0.95, Y0, (zb1 + zf0) * 0.5), 0.36)
	CatShops._basket(b, Vector3(-0.2, Y0, z1 - e - 0.16), "greens", 0.36, 0.2)
	CatShops._basket(b, Vector3(0.22, Y0, z1 - e - 0.2), "beets", 0.34, 0.9)
	_u(b, "M:SM_Prop_HandCart_01", Vector3((shx0 + shx1) * 0.5, Y0, (shz1 + zf0) * 0.5), PI / 2 * m + 0.15, 0.3)
	# огородник на коленях у грядки
	b.actor(Vector3(-0.1, Y0, 0.55), -PI / 2, "Fixing_Kneeling", "pleb")
	return Vector3(0, 0, z1 + 0.35)


## Грядка: дощатые бортики, земля рядами
static func _bed(b: Bp, bx0: float, bx1: float, bz0: float, bz1: float) -> void:
	for zz: float in [bz0, bz1]:
		_beam(b, Vector3(bx0, Y0 + 0.07, zz), bx1 - bx0, 0.0, 0.55)
	for xx: float in [bx0, bx1]:
		_beam(b, Vector3(xx, Y0 + 0.07, bz1), bz1 - bz0, PI / 2, 0.55)
	var n := maxi(1, int(round((bz1 - bz0) / 0.6)))
	var d := (bz1 - bz0 - 0.08) / n
	for j in n:
		_p(b, "SM_Env_Ground_Row_01", Vector3((bx0 + bx1) * 0.5, Y0, bz0 + 0.04 + (j + 0.5) * d), PI / 2, Vector3(d / 1.24, 0.3, (bx1 - bx0 - 0.08) / 6.4))


# =====================================================================
#   приют для животных
# =====================================================================

## Места приюта (дом, скамья с корзинками, загон) — их же берут кошки и ослик (pets)
static func _shelter_lay(fr: Array) -> Dictionary:
	var x0: float = fr[0]
	var z0: float = fr[2]
	var z1: float = fr[3]
	var r := [x0 + 0.1, x0 + 2.3, z0 + 0.12, z1 - 0.62]
	var hz1: float = r[3]
	var bench := Vector3(float(r[0]) + 1.55, Y0, hz1 + 0.3)
	return {"r": r, "bench": bench, "baskets": [bench + Vector3(-0.22, 0.25, 0), bench + Vector3(0.22, 0.25, 0)],
		"pen": [float(r[1]) + 0.25, float(fr[1]) - 0.08, z0 + 0.1, z1 - 0.08]}


static func _shelter(b: Bp, fr: Array, x: Dictionary) -> Vector3:
	var fv: int = x["fv"]
	var pal: int = x["c"]
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	NewCivic._base(b, x0, x1, z0, z1)
	var L := _shelter_lay(fr)
	var r: Array = L["r"]
	_tint(x, WHITEWASH.lerp(x["t"], 0.35))
	x["shut"] = "#shutters_blue" if fv == 0 else "#shutters_green"
	x["leaf"] = NewSmall.LEAF_WOOD
	var res := _house(b, r, x, {"h": 2.05, "along_z": true, "tym": TYM_RED if fv == 0 else TYMPANUM, "mods": {0: "DN", 1: "S", 2: "NA", 3: "S"}})
	var hz1: float = r[3]
	var ir: Array = res["ir"]
	_u(b, "SM_Bld_Roof_Topper_01", Vector3((float(r[0]) + float(r[1])) * 0.5, float(res["ridge"]) - 0.04, hz1 + 0.1), 0.0, 0.36)
	# в тёплой комнате: соломенные лежанки, корзинки с подушками, миски
	_u(b, "SM_Prop_Straw_Stack_01", Vector3(float(ir[1]) - 0.35, Y0, float(ir[2]) + 0.35), 0.4, 0.24, GLOW)
	for k in 2:
		var bp := Vector3(float(ir[0]) + 0.35 + k * 0.55, Y0, float(ir[2]) + 0.3)
		_u(b, "SM_Prop_Basket_11", bp, k * 0.7, 0.36, GLOW)
		_u(b, "SM_Prop_Pillow_06", bp + Vector3(0, 0.03, 0), k, 0.3, GLOW)
	_u(b, "SM_Prop_Bowl_04", Vector3((float(ir[0]) + float(ir[1])) * 0.5, Y0, (float(ir[2]) + float(ir[3])) * 0.5), 0.0, 0.5, GLOW)
	# скамья с корзинками у окна (в них спят кошки — pets), миски у двери, мешок корма, фонарь, вывеска
	var bench: Vector3 = L["bench"]
	_p(b, "SM_Prop_Seat_Bench_03", bench, 0.0, Vector3(0.38, 0.38, 0.4))
	for bp: Vector3 in L["baskets"]:
		_u(b, "SM_Prop_Basket_11", bp, 0.3, 0.3)
		_u(b, "SM_Prop_Pillow_06", bp + Vector3(0, 0.03, 0), 0.5, 0.26)
	var d: Array = res["D"][0]
	var dcx := _mod_x(r, d)
	for k in 2:
		_u(b, "SM_Prop_Bowl_04", Vector3(dcx + 0.36 + k * 0.2, Y0, hz1 + 0.5), 0.0, 0.42)
	_u(b, "SM_Prop_Sack_0%d" % (3 + pal % 3), Vector3(float(r[0]) + 0.2, Y0, hz1 + 0.25), 0.5, 0.4)
	_p(b, "#wall_lamp", Vector3(dcx - 0.42, Y0 + 1.6, hz1 + 0.02), 0.0)
	CatShops._sign(b, Vector3(dcx + 0.45, Y0 + 1.95, hz1 + 0.06), 0.0, "E", SKY, 0.3)
	NewSmall._pot(b, Vector3(float(r[1]) - 0.15, Y0, hz1 + 0.22), 0.22)
	b.actor(Vector3(dcx + 0.55, Y0, hz1 + 0.75), PI - 0.3, "Interact", "any")
	# загон за плетнём: навес у задней стенки, сено, поилка; калитка спереди у дома
	var pen: Array = L["pen"]
	var px0: float = pen[0]
	var px1: float = pen[1]
	var pz0: float = pen[2]
	var pz1: float = pen[3]
	_wattle(b, Vector3(px1, Y0, pz0), Vector3(-1, 0, 0), px1 - px0, 0.62, 0)
	_wattle(b, Vector3(px1, Y0, pz1), Vector3(0, 0, -1), pz1 - pz0, 0.62, 1)
	_wattle(b, Vector3(px0, Y0, pz0), Vector3(0, 0, 1), pz1 - pz0, 0.62, 0)
	_wattle(b, Vector3(px0 + 0.9, Y0, pz1), Vector3(1, 0, 0), px1 - px0 - 0.9, 0.62, 1)
	_p(b, "SM_Env_Fence_Woof_Gate_01", Vector3(px0 + 0.05, Y0, pz1), 0.5, Vector3(0.8 / 2.51, 0.6 / 1.29, 0.8))
	# навес для ослика: беленая задняя стенка, черепичный скат на столбах
	var sh_d := 1.05
	var wst: Dictionary = x["st"]
	NewCivic._run(b, "SM_Bld_Wall_01", Vector3(px0 + 0.1, Y0, pz0 + 0.12), Vector3(1, 0, 0), px1 - px0 - 0.2, 2.5, 1.6 / 3.01, 0.5, wst, 1.4)
	NewCivic._run(b, "SM_Bld_Wall_Large_Cap_01", Vector3(px0 + 0.06, Y0 + 1.58, pz0 + 0.12), Vector3(1, 0, 0), px1 - px0 - 0.12, 5.02, 0.3, 0.22, {}, 1.4)
	for k in 2:
		_u(b, "SM_Env_Ivy_Flowers_0%d" % (1 + (pal + k * 2) % 4), Vector3(lerpf(px0 + 0.6, px1 - 0.6, k), Y0 + 0.85, pz0 + 0.12 - 0.08), PI, 0.4)
	NewSmall._pilasters(b, [px0 + 0.1, px1 - 0.1, pz0 + 0.06, pz0 + 0.18], {2: 2}, Y0, 1.6, 0.14)
	for xx: float in [px0 + 0.14, px1 - 0.14]:
		_post(b, Vector3(xx, Y0, pz0 + sh_d), 1.32, 0.11)
	_p(b, "SM_Bld_Roof_Straight_Thin_Large_01", Vector3(px0 + 0.02, Y0 + 1.3, pz0 + sh_d + 0.12), 0.0, Vector3((px1 - px0 - 0.04) / 7.5, 0.34 / 1.95, (sh_d + 0.1) / 7.5))
	_u(b, "SM_Prop_Straw_Stack_02", Vector3(px1 - 0.42, Y0, pz0 + 0.42), 0.3, 0.26)
	_u(b, "SM_Prop_Straw_Bundle_01", Vector3(px0 + 0.35, Y0, pz0 + 0.35), 0.2, 0.36)
	# поилка: каменное корыто с водой
	var tz := pz1 - 0.42
	var tx := px1 - 0.42
	NewCivic._ring(b, "SM_Bld_Wall_Large_Cap_01", tx - 0.3, tx + 0.3, tz - 0.14, tz + 0.14, Y0, 5.02, 0.6, 0.18, {}, [0, 1, 2, 3], 0.7)
	b.parts.append(["#water", b.base * Transform3D(Basis.from_scale(Vector3(0.52, 0.02, 0.22)), Vector3(tx, Y0 + 0.17, tz)), {}])
	_u(b, "SM_Prop_Basket_0%d" % (1 + pal % 4), Vector3(px0 + 0.5, Y0, pz1 - 0.35), 0.4, 0.3)
	return Vector3(dcx, 0, z1 + 0.35)


# =====================================================================
#   кошачья лавка
# =====================================================================

## Места кошачьей лавки (дом, лавка, навес, башенка) — их же берут кошки и вещицы (pets)
static func _catshop_lay(fr: Array) -> Dictionary:
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	var r := [x0 + 0.1, x1 - 0.1, z0 + 0.12, z1 - 1.02]
	var hz1: float = r[3]
	var mw := (float(r[1]) - float(r[0])) * 0.5
	var ocx := float(r[0]) + mw * 1.5                          # открытая лавка — правая половина
	return {"r": r, "ocx": ocx, "ctop": Y0 + 0.55, "tower": Vector3(x1 - 0.3, Y0, z1 - 0.34),
		"basket": Vector3(float(r[0]) + 0.3, Y0, hz1 + 0.42), "toy": Vector3(0.32, Y0 + 1.84, hz1 + 0.6)}


static func _catshop(b: Bp, fr: Array, x: Dictionary) -> Vector3:
	var fv: int = x["fv"]
	var pal: int = x["c"]
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z1: float = fr[3]
	NewCivic._base(b, x0, x1, fr[2], z1)
	var L := _catshop_lay(fr)
	var r: Array = L["r"]
	var hz1: float = r[3]
	_tint(x, ROSE.lerp(x["t"], 0.2))
	x["shut"] = "#shutters_blue" if fv == 0 else "#shutters_green"
	x["leaf"] = NewSmall.LEAF_WOOD
	var res := _house(b, r, x, {"h": 2.2, "along_z": false, "tym": ROSE_TYM, "mods": {0: "DO", 1: "B", 2: "NAN" if fv == 0 else "SAS", 3: "S"}})
	var ir: Array = res["ir"]
	var ocx: float = L["ocx"]
	var o: Array = res["O"][0]
	var ow: float = o[2]
	# в лавке на полках — подушки, корзинки, клубки в мисках; лежанка (тёплый свет)
	var sw := minf(1.5, ow - 0.3)
	_p(b, "SM_Prop_Shelf_02", Vector3(ocx, Y0, float(ir[2]) + 0.22), 0.0, Vector3(sw / 2.5, 1.45 / 1.86, 0.5), GLOW)
	for j in 4:
		var sl: Vector2 = CatShops.SHELF_SLOTS[j]
		_u(b, ["SM_Prop_Basket_06", "SM_Prop_Pillow_05", "SM_Prop_Basket_12", "SM_Prop_Pillow_06"][j], Vector3(ocx + sl.x * sw / 2.5, Y0 + sl.y * 1.45 / 1.86, float(ir[2]) + 0.22), j * 0.7, [0.32, 0.3, 0.36, 0.32][j], GLOW)
	_u(b, "SM_Prop_Pillow_Pile_0%d" % (1 + pal % 3), Vector3(float(ir[0]) + 0.45, Y0, float(ir[2]) + 0.4), 0.3, 0.35, GLOW)
	# на прилавке: подставки для вещиц (вещицы и кошки — game._pets2), поднос с рыбкой-угощением
	var ctop: float = L["ctop"]
	for k in 2:
		_u(b, "SM_Prop_Bowl_04", Vector3(ocx - ow * 0.32 + k * ow * 0.42, ctop, hz1 + 0.02), 0.0, 0.36)
	CatShops._fish_tray(b, Vector3(ocx + ow * 0.36, ctop + 0.02, hz1 + 0.02), 0.3, 0.2)
	# розово-белый навес на трёх столбах
	var ay := Y0 + 2.0
	for xx: float in [x0 + 0.16, 0.0, x1 - 0.16]:
		_post(b, Vector3(xx, Y0, z1 - 0.12), 1.72)
	_beam(b, Vector3(x0 + 0.1, Y0 + 1.68, z1 - 0.12), x1 - x0 - 0.2, 0.0, 0.5)
	_awn(b, x0 + 0.04, x1 - 0.04, hz1 + 0.02, z1 + 0.06, ay, Y0 + 1.72, PINK, WHITE, 8)
	# кошачья башенка в углу (на ней дремлет кошка), корзинка-лежанка у двери, миски
	var tw: Vector3 = L["tower"]
	_p(b, "SM_Prop_Plinth_01", tw, 0.0, Vector3(0.4, 1.0, 0.45))
	_p(b, "SM_Prop_Pole_01", tw + Vector3(0, 0.25, 0), 0.0, Vector3(0.8, 0.32 / 3.0, 0.9))
	_p(b, "SM_Prop_Plinth_01", tw + Vector3(0, 0.55, 0), 0.4, Vector3(0.36, 0.6, 0.38))
	_u(b, "SM_Prop_Pillow_06", tw + Vector3(0, 0.7, 0), 0.2, 0.3)
	var bk: Vector3 = L["basket"]
	_u(b, "SM_Prop_Basket_11", bk, 0.3, 0.42)
	_u(b, "SM_Prop_Pillow_06", bk + Vector3(0, 0.04, 0), 0.5, 0.34)
	var d: Array = res["D"][0]
	var dcx := _mod_x(r, d)
	for k in 2:
		_u(b, "SM_Prop_Bowl_04", Vector3(dcx + 0.32 + k * 0.2, Y0, hz1 + 0.32), 0.0, 0.42)
	CatShops._sign(b, Vector3(dcx - 0.45, Y0 + 1.95, hz1 + 0.06), 0.0, "H", PINK, 0.3)
	_p(b, "#wall_lamp", Vector3(dcx + 0.44, Y0 + 1.6, hz1 + 0.02), 0.0)
	NewSmall._pot(b, Vector3(x0 + 0.22, Y0, z1 - 0.28), 0.24)
	# хозяйка за прилавком
	b.actor(Vector3(ocx, Y0, hz1 - 0.42), 0.0, "Interact", "any")
	return Vector3(dcx, 0, z1 + 0.35)


# =====================================================================
#   травник
# =====================================================================

static func _herbalist(b: Bp, fr: Array, x: Dictionary) -> Vector3:
	var fv: int = x["fv"]
	var pal: int = x["c"]
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	NewCivic._base(b, x0, x1, z0, z1)
	var r := [x0 + 0.1, x1 - 0.1, z0 + 0.12, z1 - 0.46]
	var hz1: float = r[3]
	_tint(x, SAGE_T.lerp(x["t"], 0.3))
	x["shut"] = "#shutters_brown" if fv == 0 else "#shutters_green"
	x["leaf"] = NewSmall.LEAF_WOOD
	var res := _house(b, r, x, {"h": 2.12, "along_z": false, "tym": TYM_RED, "mods": {0: "OD" if fv == 0 else "DO", 1: "S", 2: "NSN", 3: "B"}})
	var ir: Array = res["ir"]
	var o: Array = res["O"][0]
	var ocx := _mod_x(r, o)
	var ow: float = o[2]
	var d: Array = res["D"][0]
	var dcx := _mod_x(r, d)
	_u(b, "SM_Bld_Roof_Topper_05", Vector3((float(r[0]) + float(r[1])) * 0.5, float(res["ridge"]) - 0.05, (float(r[2]) + hz1) * 0.5), PI / 2, 0.32)
	# в лавке: полка с банками мазей, стол со ступкой, пучки трав под потолком (тёплый свет)
	var sw := minf(1.4, ow - 0.3)
	_p(b, "SM_Prop_Shelf_02", Vector3(ocx, Y0, float(ir[2]) + 0.22), 0.0, Vector3(sw / 2.5, 1.45 / 1.86, 0.5), GLOW)
	for j in 4:
		var sl: Vector2 = CatShops.SHELF_SLOTS[j]
		_u(b, ["SM_Prop_Jar_01", "SM_Prop_Vase_06", "SM_Prop_Jug_05", "SM_Prop_Bowl_04"][j], Vector3(ocx + sl.x * sw / 2.5, Y0 + sl.y * 1.45 / 1.86, float(ir[2]) + 0.22), j * 0.6, [0.28, 0.3, 0.42, 0.36][j], GLOW)
	for k in 4:
		b.parts.append(["SM_Env_Grass_0%d" % (1 + k % 3), b.base * Transform3D(Basis(Vector3.RIGHT, PI).scaled(Vector3(0.22, 0.32, 0.22)), Vector3(lerpf(float(ir[0]) + 0.3, float(ir[1]) - 0.3, k / 3.0), Y0 + 1.95, float(ir[2]) + 0.6)), {"glow": WARM * 0.3}])
	# на прилавке: ступка, банки
	var ctop := Y0 + 0.55
	_u(b, "SM_Prop_Bowl_06", Vector3(ocx - ow * 0.25, ctop, hz1 + 0.02), 0.0, 0.36)
	_u(b, "SM_Prop_Jar_01", Vector3(ocx + ow * 0.12, ctop, hz1 + 0.02), 0.0, 0.3)
	_u(b, "SM_Prop_Vase_06", Vector3(ocx + ow * 0.32, ctop, hz1 + 0.02), 0.5, 0.3)
	# черепичный козырёк над фасадом, под ним на брусе сушатся пучки трав и висят горшочки
	var fx0 := float(r[0]) + 0.05
	var fx1 := float(r[1]) - 0.05
	_p(b, "SM_Prop_Overhang_01", Vector3((fx0 + fx1) * 0.5, Y0 + 2.08, hz1 + 0.02), 0.0, Vector3((fx1 - fx0) / 2.5, 0.8, 0.62))
	for xx: float in [fx0 + 0.05, fx1 - 0.05]:
		_post(b, Vector3(xx, Y0, z1 - 0.12), 1.86, 0.09)
	_beam(b, Vector3(fx0, Y0 + 1.84, z1 - 0.12), fx1 - fx0, 0.0, 0.45)
	var hx0 := ocx - ow * 0.45
	var hx1 := ocx + ow * 0.45
	for k in 5:
		b.free_parts[b.parts.size()] = true
		b.parts.append(["SM_Env_Grass_0%d" % (1 + (k + pal) % 3), b.base * Transform3D(Basis(Vector3.UP, k * 1.1) * Basis(Vector3.RIGHT, PI).scaled(Vector3(0.24, 0.36, 0.24)), Vector3(lerpf(hx0, hx1, k / 4.0), Y0 + 1.84, z1 - 0.12)), {}])
	b.free_parts[b.parts.size()] = true
	_u(b, "SM_Prop_Pots_Hanging_0%d" % (1 + pal % 2), Vector3(dcx + 0.5 * (1.0 if dcx < ocx else -1.0), Y0 + 1.84, z1 - 0.12), 0.0, 0.5)
	# у входа — травы в горшках, грядка мяты под окном сбоку
	for k in 2:
		var px := dcx + (0.45 + k * 0.28) * (1.0 if dcx > ocx else -1.0)
		px = clampf(px, x0 + 0.2, x1 - 0.2)
		_u(b, "SM_Prop_Vase_03", Vector3(px, Y0, z1 - 0.25), b.rng.randf() * TAU, 0.34)
		_u(b, "SM_Env_Garden_Plants_0%d" % [1, 5][k], Vector3(px, Y0 + 0.28, z1 - 0.25), b.rng.randf() * TAU, 0.16)
	NewSmall._pot(b, Vector3(ocx + ow * 0.42 * (1.0 if ocx > dcx else -1.0), Y0, z1 - 0.26), 0.24)
	CatShops._sign(b, Vector3(dcx + 0.42 * (1.0 if dcx < ocx else -1.0), Y0 + 1.6, hz1 + 0.06), 0.0, "C", GREEN, 0.3)
	b.actor(Vector3(ocx, Y0, hz1 - 0.42), 0.0, "Interact", "any")
	return Vector3(dcx, 0, z1 + 0.35)


# =====================================================================
#   мастерская скульптора
# =====================================================================

static func _sculptor(b: Bp, fr: Array, x: Dictionary) -> Vector3:
	var fv: int = x["fv"]
	var pal: int = x["c"]
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	NewCivic._base(b, x0, x1, z0, z1)
	var m := 1.0 if fv == 0 else -1.0                           # мастерская слева (А) или справа (Б)
	var hw := 2.4
	var hd := 1.55
	var r := [x0 + 0.1, x0 + 0.1 + hw, z0 + 0.12, z0 + 0.12 + hd] if m > 0 else [x1 - 0.1 - hw, x1 - 0.1, z0 + 0.12, z0 + 0.12 + hd]
	var hz1: float = r[3]
	x["shut"] = "#shutters_brown"
	x["leaf"] = NewSmall.LEAF_WOOD
	var res := _house(b, r, x, {"h": 2.15, "along_z": false, "tym": TYMPANUM, "mods": {0: "DN" if m > 0 else "ND", 1: "S" if m > 0 else "W", 2: "NW", 3: "W" if m > 0 else "S"}})
	var ir: Array = res["ir"]
	# в мастерской: бюсты на постаментах, глыбы, инструмент (тёплый свет)
	_p(b, "SM_Prop_Plinth_02", Vector3(float(ir[0]) + 0.3, Y0, float(ir[2]) + 0.3), 0.0, Vector3(0.6, 0.62, 0.6), GLOW)
	_u(b, "SM_Prop_Statue_05", Vector3(float(ir[0]) + 0.3, Y0 + 0.62, float(ir[2]) + 0.3), 0.3, 0.28, {"glow": WARM * 0.6})
	_u(b, "SM_Prop_Marble_Block_02", Vector3(float(ir[1]) - 0.4, Y0, float(ir[2]) + 0.35), 0.2, 0.3, GLOW)
	var d: Array = res["D"][0]
	var dcx := _mod_x(r, d)
	CatShops._sign(b, Vector3(dcx + 0.5 * m, Y0 + 1.95, hz1 + 0.06), 0.0, "E", WHITE, 0.3)
	_p(b, "#wall_lamp", Vector3(dcx - 0.4 * m, Y0 + 1.6, hz1 + 0.02), 0.0)
	# навес-портик с верстаком рядом с мастерской: задняя стена в цвет постройки, колонны, черепичный скат
	var px0 := float(r[1]) + 0.12 if m > 0 else x0 + 0.1
	var px1 := x1 - 0.1 if m > 0 else float(r[0]) - 0.12
	var pz0 := z0 + 0.12
	var pz1 := z0 + 1.32
	var ph := 1.95
	NewCivic._run(b, "SM_Bld_Wall_01", Vector3(px0, Y0, pz0 + 0.11), Vector3(1, 0, 0), px1 - px0, 2.5, (ph + 0.3) / 3.01, 1.0, x["st"], 1.6)
	NewSmall._pilasters(b, [px0, px1, pz0, pz0 + 0.22], {0: 2, 2: 2}, Y0, ph + 0.3, 0.16)
	NewCivic._run(b, "SM_Bld_Wall_Large_Cap_01", Vector3(px1 + 0.04, Y0 + ph + 0.28, pz0 + 0.11), Vector3(-1, 0, 0), px1 - px0 + 0.08, 5.02, 0.32, 0.36, {}, 1.6)
	for k in 2:
		_u(b, "SM_Env_Ivy_Flowers_0%d" % (1 + (pal + k) % 4), Vector3(lerpf(px0, px1, 0.25 + k * 0.5), Y0 + 1.15, pz0 - 0.02), PI, 0.5)
	for k in 3:
		_col(b, Vector3(lerpf(px0 + 0.14, px1 - 0.14, k / 2.0), Y0, pz1 - 0.1), ph, 0.17)
	_p(b, "SM_Bld_Roof_Straight_Thin_Large_01", Vector3(px0 - 0.06, Y0 + ph - 0.02, pz1 + 0.08), 0.0, Vector3((px1 - px0 + 0.12) / 7.5, 0.32 / 1.95, (pz1 - pz0 + 0.06) / 7.5))
	var pcx := (px0 + px1) * 0.5
	_p(b, "SM_Prop_Table_05", Vector3(pcx - 0.3, Y0, pz0 + 0.55), PI / 2, Vector3.ONE * 0.62)
	for e: Array in [["SM_Prop_Tool_Hammer_01", Vector3(pcx - 0.6, Y0 + 0.49, pz0 + 0.5)], ["SM_Prop_Tool_Chisel_01", Vector3(pcx - 0.35, Y0 + 0.49, pz0 + 0.62)], ["SM_Prop_Tool_Compass_01", Vector3(pcx - 0.1, Y0 + 0.49, pz0 + 0.45)]]:
		_u(b, e[0], e[1], b.rng.randf() * TAU, 0.75)
	_p(b, "SM_Prop_Plinth_02", Vector3(px1 - 0.3 if m > 0 else px0 + 0.3, Y0, pz0 + 0.45), 0.0, Vector3(0.6, 0.62, 0.6))
	_u(b, "SM_Prop_Statue_0%d" % [5, 3][pal % 2], Vector3(px1 - 0.3 if m > 0 else px0 + 0.3, Y0 + 0.62, pz0 + 0.45), PI + 0.4, 0.3)
	_u(b, "SM_Prop_Marble_Rubble_0%d" % [4, 7][pal % 2], Vector3(pcx + 0.35, Y0, pz0 + 0.75), b.rng.randf() * TAU, 0.3)
	# двор: низкая ограда спереди с проходом и по бокам
	var gw := 1.0
	var e := 0.13
	_low_wall(b, Vector3(x0 + e, Y0, z1 - e), Vector3(1, 0, 0), (x1 - x0) * 0.5 - e - gw * 0.5, 0.4)
	_low_wall(b, Vector3(gw * 0.5, Y0, z1 - e), Vector3(1, 0, 0), (x1 - x0) * 0.5 - e - gw * 0.5, 0.4)
	_low_wall(b, Vector3(x1 - e, Y0, z1 - e), Vector3(0, 0, -1), z1 - hz1 - 0.1 - e, 0.4)
	_low_wall(b, Vector3(x0 + e, Y0, hz1 + 0.1), Vector3(0, 0, 1), z1 - hz1 - 0.1 - e, 0.4)
	# статуя в лесах: столбы, брусья, лестница; вторая незаконченная — на низком постаменте
	var s1 := Vector3(-0.85 * m, Y0, hz1 + 0.85)
	_u(b, "SM_Prop_Statue_Unfinished_01", s1 + Vector3(0, 0, -0.15), 0.2, 0.5)
	for sx: float in [-0.5, 0.5]:
		for sz: float in [-0.35, 0.3]:
			_post(b, s1 + Vector3(sx, 0, sz), 1.45, 0.07)
	for yy: float in [0.6, 1.25]:
		_beam(b, s1 + Vector3(-0.56, yy, 0.3), 1.12, 0.0, 0.45)
		_beam(b, s1 + Vector3(-0.56, yy, -0.35), 1.12, 0.0, 0.45)
	NewCivic._floor(b, WOOD, s1.x - 0.52, s1.z - 0.36, s1.x + 0.52, s1.z + 0.32, Y0 + 0.62, 1.2)
	CatDecor._lean(b, "SM_Prop_Ladder_01", s1 + Vector3(0.62 * m, 0, 0.32), 0.0, -0.2, 0.42)
	var s2 := Vector3(0.75 * m, Y0, hz1 + 0.75)
	_p(b, "SM_Prop_Plinth_01", s2, 0.0, Vector3(0.62, 0.8, 0.62))
	_u(b, "SM_Prop_Statue_Unfinished_02", s2 + Vector3(0, 0.2, 0), -0.4 * m, 0.55)
	# глыбы и груда мрамора по краю двора, обломки
	var bx := x1 - 0.55 if m > 0 else x0 + 0.55
	_u(b, "SM_Prop_Marble_Block_01", Vector3(bx, Y0, hz1 + 0.55), PI / 2 + 0.1, 0.32)
	_u(b, "SM_Prop_Marble_Block_03", Vector3(bx, Y0 + 0.34, hz1 + 0.5), PI / 2 - 0.2, 0.26)
	_u(b, "SM_Prop_Marble_Pile_01", Vector3(-bx, Y0, z1 - 0.48) + Vector3(0.2 * m, 0, 0), 0.4, 0.26)
	_u(b, "SM_Prop_Marble_Rubble_07", Vector3(0.05, Y0, hz1 + 0.35), b.rng.randf() * TAU, 0.32)
	_u(b, "SM_Prop_Marble_Rubble_04", Vector3(-1.6 * m, Y0, z1 - 0.38), b.rng.randf() * TAU, 0.28)
	# готовая статуя на постаменте у входа
	var sx2 := (gw * 0.5 + 0.4) * m
	_p(b, "SM_Prop_Plinth_04", Vector3(sx2, Y0, z1 - 0.38), 0.0, Vector3(0.5, 0.6, 0.5))
	_u(b, "SM_Prop_Statue_0%d" % [6, 4][pal % 2], Vector3(sx2, Y0 + 0.41, z1 - 0.38), -0.3 * m, 0.42)
	# мастера у статуй
	b.actor(s1 + Vector3(0, 0, 0.62), PI, "Interact", "any")
	b.actor(s2 + Vector3(-0.42 * m, 0, 0.35), PI * 0.75 * m, "Interact", "any")
	return Vector3(0, 0, z1 + 0.35)


# =====================================================================
#   лудус
# =====================================================================

static func _ludus(b: Bp, fr: Array, x: Dictionary) -> Vector3:
	var fv: int = x["fv"]
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	var W := x1 - x0
	var D := z1 - z0
	var cx := (x0 + x1) * 0.5
	NewCivic._base(b, x0, x1, z0, z1)
	_tint(x, LUDUS_RED.lerp(x["t"], 0.25))
	x["shut"] = "#shutters_brown"
	x["leaf"] = NewSmall.LEAF_WOOD
	# казарма-кельи: два этажа, двери келий и окна в тёплые комнаты, ставни; щиты на поясе; знамя
	var bd := clampf(D * 0.36, 1.7, 2.1)
	var r := [x0 + 0.1, x1 - 0.1, z0 + 0.12, z0 + 0.12 + bd]
	var hz1: float = r[3]
	var H1 := 2.1
	var E := 0.14
	var H2 := 1.45
	var y2 := Y0 + H1 + E
	var ytop := y2 + H2
	var n := maxi(5, int(round((W - 0.2) / 1.25)))
	if n % 2 == 0:
		n += 1
	var g1 := ""
	var g2 := ""
	var gb := ""
	for i in n:
		g1 += "D" if i % 2 == 1 else "S"
		g2 += "S" if i % 2 == 0 else "N"
		gb += "N" if i % 2 == 0 else "W"
	var res := NewSmall._storey(b, r, {0: g1, 1: "SN", 2: gb, 3: "NS"}, Y0, H1, x)
	var up := NewSmall._storey(b, r, {0: g2, 1: "NS", 2: g2, 3: "SN"}, y2, H2, x)
	for side in 4:
		NewSmall._run(b, "SM_Bld_Wall_01", r, side, Y0 + H1, -0.11 * 0.6, 2.5, E / 3.01, 0.6, x["st"], 1.8)
	NewSmall._cornice(b, r, Y0 + H1 - 0.03, E + 0.04, 0.08)
	NewSmall._pilasters(b, r, {0: n, 1: 2, 2: n, 3: 2}, Y0, ytop - Y0, 0.17)
	NewSmall._frieze(b, r, ytop - 0.2)
	NewSmall._cornice(b, r, ytop - 0.03, 0.18, 0.1)
	var ridge := NewSmall._roof(b, r, ytop + 0.08, false, TYM_RED, 0.16)
	for e: Array in res["W"]:
		var side: int = e[0]
		_u(b, "SM_Wep_Shield_04", NewSmall._at(r, side, float(e[1]) + float(e[2]) * 0.5, 0.05, Y0 + 1.35), NewSmall._yaw(side), 0.48)
	_p(b, "SM_Prop_Banner_03_B", Vector3(cx, ytop - 0.22, hz1 + 0.1), 0.0, Vector3.ONE * 0.5)
	_u(b, "SM_Bld_Roof_Topper_03", Vector3(cx, ridge - 0.04, (float(r[2]) + hz1) * 0.5), PI / 2, 0.4)
	var ir := NewSmall._inner(r, 0.32)
	NewSmall._hall(b, ir, Y0, ytop - Y0 - 0.1, NewSmall._gaps(r, res))
	# в кельях: лежанки, стойка мечей, кувшины (тёплый свет)
	for k in 3:
		var kx := lerpf(float(ir[0]) + 0.7, float(ir[1]) - 0.7, k / 2.0)
		_p(b, "SM_Prop_Seat_Kline_01", Vector3(kx, Y0, float(ir[2]) + 0.32), 0.0, Vector3.ONE * 0.42, GLOW)
		_u(b, "SM_Prop_Jug_0%d" % (1 + k % 4), Vector3(kx + 0.55, Y0, float(ir[2]) + 0.25), 0.0, 0.3, GLOW)
	b.light(Vector3(cx - W * 0.25, Y0 + 1.5, (float(ir[2]) + float(ir[3])) * 0.5))
	b.light(Vector3(cx + W * 0.25, Y0 + 1.5, (float(ir[2]) + float(ir[3])) * 0.5))
	# стены двора: низкие, в цвет казармы, с белой плитой; ворота посредине спереди
	var WH := 1.1
	var gw := 1.5
	var e := 0.13
	var wst: Dictionary = x["st"]
	_rail_wall(b, Vector3(x0 + e, Y0, z1 - e), Vector3(1, 0, 0), W * 0.5 - e - gw * 0.5, wst, WH)
	_rail_wall(b, Vector3(cx + gw * 0.5, Y0, z1 - e), Vector3(1, 0, 0), W * 0.5 - e - gw * 0.5, wst, WH)
	_rail_wall(b, Vector3(x1 - e, Y0, z1 - e), Vector3(0, 0, -1), z1 - e - hz1, wst, WH)
	_rail_wall(b, Vector3(x0 + e, Y0, hz1), Vector3(0, 0, 1), z1 - e - hz1, wst, WH)
	for xx: float in [x0 + e + 0.02, x1 - e - 0.02, cx - gw * 0.5 - 0.6, cx + gw * 0.5 + 0.6]:
		_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(xx, Y0, z1 - e + 0.02), 0.0, Vector3(0.2, (WH + 0.06) / 4.55, 0.2), PIL)
	# ворота: два столба из белого камня, перемычка с щитом и знаменем, факелы
	var gy := 2.05
	for sd: float in [-1.0, 1.0]:
		var gx := cx + sd * (gw * 0.5 + 0.08)
		_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(gx, Y0, z1 - e - 0.02), 0.0, Vector3(0.3, gy / 4.55, 0.3), PIL)
		_torch(b, Vector3(gx, Y0 + 1.45, z1 - e + 0.14), 0.0, 0.85)
		_p(b, "SM_Prop_Banner_03_B", Vector3(gx, gy - 0.05, z1 - e + 0.12), 0.0, Vector3.ONE * 0.42)
	_p(b, "SM_Bld_Wall_Large_Cap_01", Vector3(cx - gw * 0.5 - 0.25, Y0 + gy, z1 - e - 0.02), 0.0, Vector3((gw + 0.5) / 5.02, 0.6, 0.45))
	NewSmall._frieze(b, [cx - gw * 0.5 - 0.22, cx + gw * 0.5 + 0.22, z1 - e - 0.2, z1 - e + 0.18], Y0 + gy + 0.18, [0])
	var gr := NewCivic._gable_z(b, cx - gw * 0.5 - 0.3, cx + gw * 0.5 + 0.3, z1 - e - 0.3, z1 - e + 0.26, Y0 + gy + 0.4, TYM_RED, true, true)
	_u(b, "SM_Bld_Ornament_02", Vector3(cx, Y0 + gy + 0.4 + (gr - Y0 - gy - 0.4) * 0.32, z1 - e + 0.24), 0.0, 0.22)
	# арена: песок в каменном бортике
	var ax0 := x0 + e + 0.22
	var ax1 := x1 - e - 0.22
	var az0 := hz1 + 0.55
	var az1 := z1 - e - 0.25
	var kerb := {}
	NewCivic._ring(b, "SM_Bld_Wall_Large_Cap_01", ax0, ax1, az0, az1, Y0 - 0.05, 5.02, 0.4, 0.2, kerb, [1, 2, 3], 1.6)
	NewCivic._run(b, "SM_Bld_Wall_Large_Cap_01", Vector3(ax0, Y0 - 0.05, az1), Vector3(1, 0, 0), (ax1 - ax0) * 0.5 - gw * 0.5, 5.02, 0.4, 0.2, kerb, 1.6)
	NewCivic._run(b, "SM_Bld_Wall_Large_Cap_01", Vector3(cx + gw * 0.5, Y0 - 0.05, az1), Vector3(1, 0, 0), (ax1 - ax0) * 0.5 - gw * 0.5, 5.02, 0.4, 0.2, kerb, 1.6)
	CatMilitary._sand(b, Vector3((ax0 + ax1) * 0.5, Y0, (az0 + az1) * 0.5), ax1 - ax0 - 0.12, az1 - az0 - 0.12)
	# столб-палус, чучела, стойки с оружием у боковых стен, щиты
	var acz := (az0 + az1) * 0.5
	var pal_x := ax0 + 1.25 if fv == 0 else ax1 - 1.25
	_post(b, Vector3(pal_x, Y0, acz - 0.2), 1.25, 0.22)
	CatMilitary.add_kit(b, "#mil_dummy", Vector3(ax1 - 0.75 if fv == 0 else ax0 + 0.75, Y0, az0 + 0.45), -0.3, 0.6)
	CatMilitary.add_kit(b, "#mil_dummy", Vector3(ax1 - 0.6 if fv == 0 else ax0 + 0.6, Y0, az1 - 0.55), 0.4, 0.6)
	for sd: float in [-1.0, 1.0]:
		var rx := x0 + e + 0.28 if sd < 0.0 else x1 - e - 0.28
		CatMilitary._rack(b, Vector3(rx, Y0, acz + 0.1), PI / 2 * -sd, 1 + int(sd > 0.0), 0.42)
	# крытая скамья у стены казармы (смотрят ученики), щиты у стены
	var bx0 := cx - W * 0.3
	var bx1 := cx + W * 0.3
	_u(b, "SM_Prop_Seat_Bench_03", Vector3(cx - W * 0.18, Y0, hz1 + 0.25), 0.0, 0.42)
	_u(b, "SM_Prop_Seat_Bench_03", Vector3(cx + W * 0.18, Y0, hz1 + 0.25), 0.0, 0.42)
	_p(b, "SM_Prop_Overhang_01", Vector3(cx - W * 0.18, Y0 + 1.75, hz1 + 0.02), 0.0, Vector3(0.48, 0.8, 0.7))
	_p(b, "SM_Prop_Overhang_01", Vector3(cx + W * 0.18, Y0 + 1.75, hz1 + 0.02), 0.0, Vector3(0.48, 0.8, 0.7))
	CatMilitary._lean_shield(b, Vector3(bx0 - 0.1, Y0, hz1 + 0.15), 0.0, "SM_Wep_Shield_04", 0.25, 0.42)
	CatMilitary._lean_shield(b, Vector3(bx1 + 0.1, Y0, hz1 + 0.15), 0.0, "SM_Wep_Shield_04", 0.25, 0.42)
	# статуя гладиатора у ворот (во дворе), жаровня у другой стороны
	var stx := cx - (gw * 0.5 + 0.55) if fv == 0 else cx + (gw * 0.5 + 0.55)
	_p(b, "SM_Prop_Plinth_04", Vector3(stx, Y0, az1 - 0.05), 0.0, Vector3(0.5, 0.6, 0.5))
	_u(b, "SM_Prop_Statue_02", Vector3(stx, Y0 + 0.41, az1 - 0.05), PI + 0.3, 0.32)
	_brazier(b, Vector3(cx + (gw * 0.5 + 0.55) * (1.0 if fv == 0 else -1.0), Y0, az1 - 0.05), 0.36)
	# двое бьются деревянными мечами, ланиста смотрит и учит
	b.actor(Vector3(cx - 0.45, Y0, acz), PI / 2, "Spar", "pleb")
	b.actor(Vector3(cx + 0.45, Y0, acz), -PI / 2, "Sword_Idle", "pleb")
	b.actor(Vector3(cx + 0.25, Y0, az0 + 0.3), 0.2, "Spell_Simple_Idle", "any")
	return Vector3(cx, 0, z1 + 0.35)


# =====================================================================
#   животные и вещицы (game._pets2, Hud.pets_of): в осях чертежа (метры / масштаб Catalog)
# =====================================================================

static func pets(type: String) -> Array:
	if not covers(type) or not (type in ["shelter", "catshop"]):
		return []
	var K := Catalog.scale_of(type)
	var fr := frame(type, Vector2.ZERO)
	var out := []
	if type == "shelter":
		var L := _shelter_lay(fr)
		var bs: Array = L["baskets"]
		var pen: Array = L["pen"]
		out.append(["cat", ((bs[0] as Vector3) + Vector3(0, 0.05, 0)) / K, 2.4, "sleep", 0.9, -1])
		out.append(["cat", ((bs[1] as Vector3) + Vector3(0, 0.05, 0)) / K, 0.6, "sleep", 0.9, -1])
		out.append(["donkey", Vector3((float(pen[0]) + float(pen[1])) * 0.5 + 0.1, 0, float(pen[2]) + 0.75) / K, PI / 2 + 0.2, "Eating", 0.85, -1])
	else:
		var L := _catshop_lay(fr)
		var r: Array = L["r"]
		var hz1: float = r[3]
		var ocx: float = L["ocx"]
		var mw := (float(r[1]) - float(r[0])) * 0.5
		var ow := mw
		var ctop: float = L["ctop"]
		var tw: Vector3 = L["tower"]
		var bk: Vector3 = L["basket"]
		var toy: Vector3 = L["toy"]
		out.append(["cat", Vector3(ocx + ow * 0.08, ctop, hz1 + 0.02) / K, 0.35, "sit", 1.0, -1, "petasos"])
		out.append(["cat", (bk + Vector3(0, 0.08, 0)) / K, 2.2, "sleep", 0.9, -1, "bow"])
		out.append(["cat", Vector3(toy.x, Y0, toy.z) / K, 0.1, "pet", 1.0, -1, "collar"])
		out.append(["cat", (tw + Vector3(0, 0.73, 0)) / K, 0.2, "sleep", 0.85, -1, "bandana"])
		out.append(["toy", toy / K, 0.0, "", 1.0, -1])
		out.append(["acc", Vector3(ocx - ow * 0.32, ctop + 0.1, hz1 + 0.02) / K, 0.4, "pileus", 1.5, -1])
		out.append(["acc", Vector3(ocx + ow * 0.1, ctop + 0.1, hz1 + 0.02) / K, -0.3, "wreath", 1.4, -1])
		var shz := float(r[2]) + 0.3 + 0.22                  # полка в лавке (как в _catshop)
		out.append(["acc", Vector3(ocx - 0.3, Y0 + 1.45 + 0.04, shz) / K, 0.3, "cape", 1.2, -1])
		out.append(["acc", Vector3(ocx + 0.3, Y0 + 1.45 + 0.06, shz) / K, 0.0, "flower", 1.6, -1])
	return out
