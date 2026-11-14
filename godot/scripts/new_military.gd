class_name NewMilitary
extends RefCounted
## Новые здания Легиона (владелец 13.11: «пересобрать модельки» — новые здания из деталей Synty POLYGON Ancient Empire,
## а не украшенные прежние; «темноты вообще не должно быть»; у каждого здания своё основание; размеры — по линейке:
## все тринадцать «средние», 3–4 дома, в прежних следах — OLD_LOT не нужен). Собраны с нуля в метрах города (base делит
## на масштаб Catalog, тот потом умножает обратно), фасад к +Z, вход — b.door у переднего края.
## Общий римский военный облик: низ из тёплого тёсаного камня, верх — штукатурка своего цвета у каждого здания
## (легионный красный у казарм и склада оружия, охра, терракота, белила, сливки), белые мраморные пилястры, расписной
## фриз, карниз, черепица с красным фронтоном; красные значки с золотым орлом, щиты, стойки оружия, жаровни с огнём.
## За каждой дверью, воротами, окном и пологом палатки — освещённая комната (тёплое свечение материала, remap «glow»,
## как у NewTemple и NewSmall) с мебелью по делу здания. Основание — мощёное, с бордюром, уходящим в землю
## (City.apron_of = 0: ни глины, ни травы под зданием); плац и двор — утоптанный песок поверх мощения.
## Здание растёт с уровнем Легиона (tier = Legion.vis_tier, 0…5): каждый уровень только ПРИБАВЛЯЕТ детали
## (test_legion: детали 1-го уровня на месте, новые — внутри следа 1-го уровня), случай общий для всех уровней:
##   2-й — значки легиона у ворот и знамёна на фасаде;
##   3-й — каменная ограда с зубцами вдоль двора (у лагеря — уже есть частокол) и огни в чашах на столбах ворот;
##   4-й — пристройка: башня, портик, подъёмник, вторая печь или навес (у каждого своё) и бронзовый орёл;
##   5-й — арка ворот с красной доской и золотыми цифрами легиона, статуи;
##   6-й — золото: орёл на коньке, золочёные щиты на стенах, акротерии, золотой пояс под карнизом.
## Люди при деле (b.actor): легионеры у чучел, лучники на рубеже, копейщики, мастера у машин, кузнец у горна, лекарь,
## жрец — днём; у Плавильни, Лесопилки и Дубильни это места работников (People._enter_work), по два, как прежде.
## Прежние сборки (CatMilitary) остаются: ON — выключатели по типу (снимки «было/стало»); CIVCITY_NEWMIL=0 — прежние
## во всей игре.

const TYPES := ["barracks", "range", "spearcamp", "ballistae", "catapults", "forge", "infirmary", "armory", "smelter", "sawmill",
	"tannery", "principia", "mars"]
static var ON := _on_env()

## Участок каждого здания (м, оси постройки: x0, x1, z0, z1; фасад к +Z) — прежний след (замер test_mil_probe new=0)
const LOT := {
	"barracks": [-3.10, 3.10, -3.73, 2.50], "range": [-3.39, 3.31, -3.57, 2.07], "spearcamp": [-2.97, 2.90, -3.60, 2.52],
	"ballistae": [-3.30, 3.35, -3.59, 1.86], "catapults": [-3.29, 3.30, -3.59, 1.92], "forge": [-3.30, 3.22, -3.59, 1.71],
	"infirmary": [-3.00, 3.00, -3.73, 2.21], "armory": [-3.06, 3.06, -3.73, 2.36], "smelter": [-3.30, 3.36, -3.73, 2.53],
	"sawmill": [-2.86, 4.03, -3.88, 2.19], "tannery": [-3.44, 3.30, -3.83, 2.00], "principia": [-3.08, 3.08, -3.73, 3.15],
	"mars": [-2.91, 2.91, -3.59, 3.08],
}

const Y0 := 0.06                  # верх мощёного основания
const WARM := Color(0.3, 0.18, 0.09)
const GOLD := Color(1.0, 0.78, 0.36)
const BRONZE := Color(0.7, 0.48, 0.28)
const CREAM := Color(1.0, 0.93, 0.8)
## Раскраски (те же словари, что у NewSmall и NewCivic: одни и те же группы деталей на весь город)
const STONE := {"Stucco_White_01": "Building_Large_Brick_01", "tints": {"Building_Large_Brick_01": Color(1.0, 0.93, 0.8)}}
const STONE_WIN := {"Stucco_White_01": "Building_Large_Brick_01", "Stucco_Orange_01": "Building_Large_Brick_01", "tints": {"Building_Large_Brick_01": Color(1.0, 0.93, 0.8)}}
const PIER := {"tints": {"Building_Large_Brick_01": Color(1.0, 0.93, 0.8)}}
const PIL := {"Building_Large_Brick_01": "Building_Marble_01"}
const TYM_RED := {"Stone_01": "Stucco_Red_01"}
const TYMPANUM := {"Stone_01": "Stucco_Blue_01", "tints": {"Stucco_Blue_01": Color(0.78, 0.87, 1.0)}}
const PAVING := {"Stone_01": "Floor_Tiles_06"}
const MOSAIC := {"Stone_01": "Floor_Tiles_Circle_01"}
const WOODF := {"Stone_01": "Wood_02"}
const MARBLE := {"Stucco_White_01": "Building_Marble_01"}
const OCHRE_GLOW := {"Stucco_White_01": "Stucco_Orange_01", "glow": WARM}
const FLAME := {"tint": Color(1.0, 0.55, 0.16), "glow": Color(1.2, 0.46, 0.1)}
const EMBER := {"tint": Color(1.0, 0.42, 0.12), "glow": Color(1.0, 0.32, 0.06)}
const GLOW := {"glow": WARM * 0.4}
const GOLD_T := {"tint": GOLD}
const GOLD_STATUE := {"tints": {"Statue_01": GOLD}}
const BRONZE_STATUE := {"tints": {"Statue_01": BRONZE}}
const RED_PLAQUE := {"tints": {"Stucco_White_01": Color(0.72, 0.2, 0.16)}}
const LEAF_BRONZE := "SM_Bld_Door_Large_Half_03"
const LEAF_WOOD := "SM_Bld_Door_Large_Half_01"

## Штукатурка верхних этажей (оттенок белой штукатурки Synty — цвет у экземпляра, одна группа деталей)
const COL := {
	"barracks": Color(0.92, 0.5, 0.4), "armory": Color(0.86, 0.46, 0.38), "range": Color(1.0, 0.78, 0.47),
	"spearcamp": Color(1.0, 0.82, 0.64), "ballistae": Color(1.0, 0.8, 0.5), "catapults": Color(0.98, 0.62, 0.46),
	"forge": Color(0.95, 0.86, 0.7), "smelter": Color(0.95, 0.86, 0.7), "sawmill": Color(1.0, 0.84, 0.56),
	"tannery": Color(1.0, 0.86, 0.72), "infirmary": Color(1.0, 0.98, 0.94), "principia": Color(1.0, 0.94, 0.84),
	"mars": Color(0.9, 0.48, 0.4),
}


static func _on_env() -> Dictionary:
	var off := OS.get_environment("CIVCITY_NEWMIL") == "0"
	var d := {}
	for t: String in TYPES:
		d[t] = not off
	return d


static func covers(type: String) -> bool:
	return bool(ON.get(type, false))


## Собрать здание type облика tier (Legion.vis_tier)
static func build(b: Bp, type: String, tier := 0) -> void:
	var K := Catalog.scale_of(type)
	b.base = Transform3D(Basis.from_scale(Vector3.ONE / K), Vector3.ZERO)
	var fr: Array = LOT[type]
	b.tint = COL.get(type, Color(1, 1, 1))
	var x := NewSmall._ctx(b, 0)
	x["c"] = 0
	var g := {}
	var door := Vector3.ZERO
	match type:
		"barracks": door = _barracks(b, fr, x, g)
		"range": door = _range(b, fr, x, g)
		"spearcamp": door = _spearcamp(b, fr, x, g)
		"ballistae": door = _siege(b, fr, x, g, false)
		"catapults": door = _siege(b, fr, x, g, true)
		"forge": door = _forge(b, fr, x, g)
		"infirmary": door = _infirmary(b, fr, x, g)
		"armory": door = _armory(b, fr, x, g)
		"smelter": door = _smelter(b, fr, x, g)
		"sawmill": door = _sawmill(b, fr, x, g)
		"tannery": door = _tannery(b, fr, x, g)
		"principia": door = _principia(b, fr, x, g)
		"mars": door = _mars(b, fr, x, g)
	if tier > 0:
		_grow(b, type, fr, x, g, tier)
	b.base = Transform3D.IDENTITY
	b.door = door / K


# =====================================================================
#   помощники (метры города, фасад к +Z)
# =====================================================================

static func _p(b: Bp, name: String, p: Vector3, yaw := 0.0, s := Vector3.ONE, rm := {}) -> void:
	b.parts.append([name, b.base * Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(s), p), rm])


static func _u(b: Bp, name: String, p: Vector3, yaw: float, s: float, rm := {}) -> void:
	_p(b, name, p, yaw, Vector3.ONE * s, rm)


## Деталь на лице стены прямоугольника r: сторона side, смещение a по обходу, высота y, вынос out
static func _on(b: Bp, name: String, r: Array, side: int, a: float, y: float, s: float, out := 0.05, rm := {}) -> void:
	_u(b, name, NewSmall._at(r, side, a, out, y), NewSmall._yaw(side), s, rm)


## Утоптанный песок плаца поверх мощения
static func _sand(b: Bp, x0: float, x1: float, z0: float, z1: float) -> void:
	b.parts.append(["#mil_sand", b.base * Transform3D(Basis.from_scale(Vector3(x1 - x0, 1.0, z1 - z0)), Vector3((x0 + x1) * 0.5, Y0 + 0.002, (z0 + z1) * 0.5)), {}])


## Зубцы по линии от a вдоль dir длиной len (первый и последний — на концах)
static func _merlons(b: Bp, a: Vector3, dir: Vector3, len: float, hm := 0.24, t := 0.22, mw := 0.24, step := 0.5) -> void:
	var n := maxi(2, int(round((len - mw) / step)) + 1)
	var st := (len - mw) / float(n - 1)
	var yaw := atan2(-dir.z, dir.x)
	for i in n:
		_p(b, "SM_Bld_Wall_01", a + dir * (i * st), yaw, Vector3(mw / 2.5, hm / 3.01, t / 0.22), STONE)


## Ограда из тёсаного камня по линии от a вдоль dir: тело высотой h, плита поверху, зубцы (crenel)
static func _wall_line(b: Bp, a: Vector3, dir: Vector3, len: float, h := 0.5, t := 0.22, crenel := true) -> void:
	if len < 0.2:
		return
	NewCivic._run(b, "SM_Bld_Wall_01", a, dir, len, 2.5, h / 3.01, t / 0.22, STONE, 1.6)
	NewCivic._run(b, "SM_Bld_Wall_Large_Cap_01", a + Vector3(0, h - 0.02, 0), dir, len, 5.02, 0.08 / 0.36, (t + 0.08) / 0.9, {}, 1.6)
	if crenel:
		_merlons(b, a + Vector3(0, h + 0.06, 0), dir, len, 0.22, t)


## Зубчатый парапет по обходу прямоугольника r (внутрь от края на полтолщины), от высоты y
static func _parapet(b: Bp, r: Array, y: float, sides := [0, 1, 2, 3], hb := 0.2, t := 0.2) -> void:
	var x0: float = r[0]
	var x1: float = r[1]
	var z0: float = r[2]
	var z1: float = r[3]
	var h := t * 0.5
	var lines := {0: [Vector3(x0, y, z1 - h), Vector3(1, 0, 0), x1 - x0], 1: [Vector3(x1 - h, y, z1), Vector3(0, 0, -1), z1 - z0],
		2: [Vector3(x1, y, z0 + h), Vector3(-1, 0, 0), x1 - x0], 3: [Vector3(x0 + h, y, z0), Vector3(0, 0, 1), z1 - z0]}
	for side: int in sides:
		var e: Array = lines[side]
		NewCivic._run(b, "SM_Bld_Wall_01", e[0], e[1], e[2], 2.5, hb / 3.01, t / 0.22, STONE, 1.8)
		_merlons(b, (e[0] as Vector3) + Vector3(0, hb, 0), e[1], e[2], 0.22, t)


## Столб ворот из тёсаного камня с плитой поверху
static func _post(b: Bp, p: Vector3, w := 0.34, h := 0.86) -> void:
	_p(b, "SM_Bld_Wall_Large_Pillar_01", p, 0.0, Vector3(w / 0.92, h / 4.55, w / 0.92), PIER)
	_p(b, "SM_Bld_Wall_Large_Cap_01", p + Vector3(-w * 0.62, h, 0), 0.0, Vector3(w * 1.24 / 5.02, 0.09 / 0.36, w * 1.24 / 0.9))


## Жаровня с огнём (s — масштаб чаши), lit — со светом
static func _brazier(b: Bp, p: Vector3, s := 0.42, lit := true) -> void:
	_u(b, "SM_Prop_Brazier_03", p, 0.0, s)
	_u(b, "SM_Prop_Brazier_03_Insert_01", p, 0.0, s)
	NewCivic._fire(b, p + Vector3(0, 0.88 * s, 0), 2.6 * s / 0.42)
	if lit:
		b.light(p + Vector3(0, 1.4 * s + 0.2, 0))


## Значок легиона (красное полотнище, золотой орёл в венке)
static func _standard(b: Bp, p: Vector3, s := 0.66, yaw := 0.0) -> void:
	b.parts.append(["#mil_standard", b.base * Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * s), p), {}])


static func _kit(b: Bp, name: String, p: Vector3, yaw := 0.0, s := 1.0) -> void:
	b.parts.append([name, b.base * Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * s), p), {}])


## Стойка с оружием (1 — копья, 2 — мечи): yaw — куда смотрит
static func _rack(b: Bp, p: Vector3, yaw: float, kind := 1, s := 0.45, rm := {}) -> void:
	_u(b, "SM_Prop_Weapon_Rack_0%d" % kind, p, yaw, s, rm)
	_u(b, "SM_Prop_Weapon_Rack_0%d_Insert_01" % kind, p, yaw, s, rm)


## Щит, прислонённый к стене или стойке
static func _lean_shield(b: Bp, p: Vector3, yaw: float, nm := "SM_Wep_Shield_04", s := 0.5, tilt := 0.25, rm := {}) -> void:
	var box := Bp.model_aabb(nm)
	b.parts.append([nm, b.base * Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -tilt) * Basis.from_scale(Vector3.ONE * s), p + Vector3(0, -box.position.y * s, 0)), rm])


## Палатка: кожаный шатёр, за откинутыми полами — тёплая светящаяся стенка (лампа внутри)
static func _tent(b: Bp, p: Vector3, yaw := 0.0) -> void:
	var bs := Basis(Vector3.UP, yaw)
	_kit(b, "#mil_tent2", p, yaw)
	_p(b, "SM_Bld_Wall_01", p + bs * Vector3(-0.3, 0.0, 0.55), yaw, Vector3(0.6 / 2.5, 1.0 / 3.01, 0.1), OCHRE_GLOW)
	_p(b, "SM_Prop_Rug_0%d" % (1 + b.rng.randi() % 3), p + bs * Vector3(0, 0.01, 0.15), yaw + PI / 2, Vector3.ONE * 0.28, GLOW)


## Знамя на стене (верх полотнища — на высоте y)
static func _wall_banner(b: Bp, r: Array, side: int, a: float, y: float, s := 0.55) -> void:
	_on(b, "SM_Prop_Banner_03_A", r, side, a, y, s, 0.07)


## Щит на стене (середина — на высоте y)
static func _wall_shield(b: Bp, r: Array, side: int, a: float, y: float, s := 0.42, rm := {}) -> void:
	var box := Bp.model_aabb("SM_Wep_Shield_04")
	var c := box.get_center()
	var p := NewSmall._at(r, side, a, 0.06, y)
	var bs := Basis(Vector3.UP, NewSmall._yaw(side))
	b.parts.append(["SM_Wep_Shield_04", b.base * Transform3D(bs * Basis.from_scale(Vector3.ONE * s), p - bs * (c * s)), rm])


## Дом в один-два этажа по прямоугольнику r: lo и up — модули сторон (NewSmall._storey: W стена, N/S/B окна, M малое,
## T бойница, H широкое окно, A ниша со статуей, D дверь, G ворота, O открытая лавка, L дверь чердака), низ из тёсаного
## камня (o.stone), пилястры, фриз, карнизы, плющ на гладких простенках, кровля (o.roof: x — конёк вдоль улицы, z —
## фронтон к улице, flat — плоская), тёплое нутро за проёмами. Возвращает {res, up, ytop, ridge, y2, ir}
static func _house(b: Bp, r: Array, lo: Dictionary, up: Dictionary, x: Dictionary, o := {}) -> Dictionary:
	var H1: float = o.get("H1", 2.3)
	var H2: float = o.get("H2", 1.5)
	var E := 0.14
	var stone: bool = o.get("stone", true)
	var res := NewSmall._storey(b, r, lo, Y0, H1, x, STONE if stone else {}, STONE_WIN if stone else {}, STONE if stone else {})
	var ytop := Y0 + H1
	var y2 := Y0
	var upr := {"W": [], "D": [], "O": [], "G": [], "L": []}
	if not up.is_empty():
		y2 = Y0 + H1 + E
		upr = NewSmall._storey(b, r, up, y2, H2, x)
		for side in 4:
			NewSmall._run(b, "SM_Bld_Wall_01", r, side, Y0 + H1, -0.11 * 0.6, 2.5, E / 3.01, 0.6, x["st"], 1.8)
		NewSmall._cornice(b, r, Y0 + H1 - 0.03, E + 0.04, 0.08)
		ytop = y2 + H2
	var cnt := {}
	for side: int in lo:
		cnt[side] = String(lo[side]).length()
	NewSmall._pilasters(b, r, cnt, Y0, ytop - Y0, float(o.get("pw", 0.2)))
	if bool(o.get("frieze", true)):
		NewSmall._frieze(b, r, ytop - 0.2)
	NewSmall._cornice(b, r, ytop - 0.03, 0.18, 0.1)
	var walls: Array = upr["W"] if not up.is_empty() else res["W"]
	for e: Array in walls:
		if bool(o.get("ivy", true)) and int(e[0]) != 0:
			NewSmall._ivy(b, r, e, y2, ytop - y2, int(o.get("ivy_k", 1)))
	if not up.is_empty():
		# гладкий каменный простенок нижнего яруса (бока и зад) — щит легиона, через один — плющ: без голых стен
		var k := 0
		for e: Array in res["W"]:
			var side: int = e[0]
			if side == 0:
				continue
			if k % 2 == 0:
				_wall_shield(b, r, side, float(e[1]) + float(e[2]) * 0.5, Y0 + H1 * 0.55, 0.4)
			else:
				NewSmall._ivy(b, r, e, Y0, H1, k + 2)
			k += 1
	var ridge := ytop
	match String(o.get("roof", "x")):
		"x": ridge = NewSmall._roof(b, r, ytop + 0.08, false, o.get("tym", TYM_RED), 0.16)
		"z": ridge = NewSmall._roof(b, r, ytop + 0.08, true, o.get("tym", TYM_RED), 0.16)
		"flat":
			NewCivic._floor(b, PAVING, float(r[0]), float(r[2]), float(r[1]), float(r[3]), ytop + 0.02, 2.2)
			_parapet(b, [float(r[0]) - 0.04, float(r[1]) + 0.04, float(r[2]) - 0.04, float(r[3]) + 0.04], ytop + 0.04)
			ridge = ytop + 0.5
	var ir := NewSmall._inner(r, 0.33)
	if bool(o.get("hall", true)):
		NewSmall._hall(b, ir, Y0, ytop - Y0 - 0.1, NewSmall._gaps(r, res))
		b.light(Vector3((float(ir[0]) + float(ir[1])) * 0.5, Y0 + 1.5, (float(ir[2]) + float(ir[3])) * 0.5))
	return {"res": res, "up": upr, "ytop": ytop, "ridge": ridge, "y2": y2, "ir": ir, "H1": H1}


## Середина модуля m (из ответа _storey) на стороне 0 прямоугольника r — x
static func _mx(r: Array, m: Array) -> float:
	return float(r[0]) + float(m[1]) + float(m[2]) * 0.5


## Портик на колоннах перед дверью: пол-мозаика, базы, колонны, карниз, фронтон к улице. Возвращает конёк
static func _porch(b: Bp, cx: float, hz1: float, hw: float, dep: float, H: float, tym := TYM_RED, n := 2) -> float:
	var pz := hz1 + dep
	NewCivic._floor(b, MOSAIC, cx - hw, hz1, cx + hw, pz + 0.1, Y0 + 0.022, 1.8)
	var xs := [cx - hw + 0.14, cx + hw - 0.14]
	if n == 4:
		xs = [cx - hw + 0.14, cx - (hw - 0.14) / 3.0, cx + (hw - 0.14) / 3.0, cx + hw - 0.14]
	for xx: float in xs:
		_p(b, "SM_Prop_Plinth_03", Vector3(xx, Y0, pz - 0.1), 0.0, Vector3(0.36, 0.9, 0.36))
		_p(b, "SM_Bld_Pillar_06", Vector3(xx, Y0 + 0.045, pz - 0.1), 0.0, Vector3(0.34, (H - 0.32) / 3.0, 0.34))
	NewCivic._ledge(b, cx - hw - 0.06, cx + hw + 0.06, hz1, pz + 0.06, Y0 + H - 0.27, 0.2)
	return NewCivic._gable_z(b, cx - hw - 0.1, cx + hw + 0.1, hz1 + 0.05, pz + 0.12, Y0 + H - 0.07, tym, true, false)


## Сторожевая башня: квадрат tr, каменный ствол высотой h с бойницами (за ними — тёплое нутро), карниз, деревянный
## пол, зубчатый парапет, черепичная кровля на четырёх столбах, огонь в жаровне, знамя. Возвращает высоту пола
static func _tower(b: Bp, tr: Array, h: float, x: Dictionary, roof := true, banner_side := 0) -> float:
	var res := NewSmall._storey(b, tr, {0: "T", 1: "T", 2: "W", 3: "T"}, Y0, h, x, STONE, STONE_WIN, STONE)
	NewSmall._hall(b, NewSmall._inner(tr, 0.26), Y0, h - 0.06, [])
	NewSmall._cornice(b, tr, Y0 + h - 0.02, 0.14, 0.1)
	var yp := Y0 + h + 0.08
	var pr := [float(tr[0]) - 0.08, float(tr[1]) + 0.08, float(tr[2]) - 0.08, float(tr[3]) + 0.08]
	NewCivic._floor(b, WOODF, pr[0], pr[2], pr[1], pr[3], yp - 0.02, 2.0)
	_parapet(b, pr, yp, [0, 1, 2, 3], 0.22, 0.16)
	var tc := Vector3((float(tr[0]) + float(tr[1])) * 0.5, 0, (float(tr[2]) + float(tr[3])) * 0.5)
	if roof:
		var ph := 0.95
		for c: Vector3 in [Vector3(pr[0] + 0.1, 0, pr[2] + 0.1), Vector3(pr[1] - 0.1, 0, pr[2] + 0.1), Vector3(pr[0] + 0.1, 0, pr[3] - 0.1), Vector3(pr[1] - 0.1, 0, pr[3] - 0.1)]:
			_p(b, "SM_Prop_Pole_01", Vector3(c.x, yp, c.z), 0.0, Vector3(0.55, ph / 3.0, 0.55))
		NewSmall._roof(b, pr, yp + ph, false, TYM_RED, 0.14)
	_brazier(b, tc + Vector3(0, yp, 0), 0.36, true)
	var bp: Vector3 = NewSmall._at(pr, banner_side, NewSmall._len(pr, banner_side) * 0.5, 0.03, yp + 0.42)
	_u(b, "SM_Prop_Banner_03_A", bp, NewSmall._yaw(banner_side), 0.4)
	return yp


## Арка ворот: два пилона из тёсаного камня, перекладина с зубцами, красная доска с золотыми цифрами легиона
static func _arch(b: Bp, cx: float, z: float, hw: float, h := 2.05, num := "XII") -> void:
	var pw := 0.36
	for sd: float in [-1.0, 1.0]:
		var px := cx + sd * (hw + pw * 0.5)
		_p(b, "SM_Bld_Wall_Large_Pillar_01", Vector3(px, Y0, z), 0.0, Vector3(pw / 0.92, h / 4.55, pw / 0.92), PIER)
	var x0 := cx - hw - pw
	var L := 2.0 * (hw + pw)
	NewCivic._run(b, "SM_Bld_Wall_01", Vector3(x0, Y0 + h, z), Vector3(1, 0, 0), L, 2.5, 0.42 / 3.01, 0.3 / 0.22, STONE, 2.6)
	NewCivic._run(b, "SM_Bld_Wall_Large_Cap_01", Vector3(x0 - 0.05, Y0 + h + 0.4, z), Vector3(1, 0, 0), L + 0.1, 5.02, 0.1 / 0.36, 0.42 / 0.9, {}, 2.6)
	_merlons(b, Vector3(x0, Y0 + h + 0.49, z), Vector3(1, 0, 0), L, 0.22, 0.26)
	# красная доска на перекладине, золотые цифры
	var pwid := minf(1.4, 2.0 * hw)
	_p(b, "SM_Bld_Wall_01", Vector3(cx - pwid * 0.5, Y0 + h + 0.05, z + 0.17), 0.0, Vector3(pwid / 2.5, 0.32 / 3.01, 0.1), RED_PLAQUE)
	var n := num.length()
	for i in n:
		var nm := "SM_Prop_Numeral_%s_01" % num[i]
		_u(b, nm, Vector3(cx + (i - (n - 1) * 0.5) * 0.2, Y0 + h + 0.1, z + 0.2), 0.0, 0.5, GOLD_T)


## Ворота лагеря: два толстых бревна, перекладина, поверху — частокол, красная доска с золотыми цифрами легиона
static func _gate_timber(b: Bp, cx: float, z: float, hw: float, num := "IX") -> void:
	for sd: float in [-1.0, 1.0]:
		_p(b, "SM_Prop_Pole_01", Vector3(cx + sd * (hw + 0.22), Y0, z), 0.0, Vector3(1.45, 2.45 / 3.0, 1.45))
	var L := 2.0 * (hw + 0.42)
	_p(b, "SM_Prop_Beam_01", Vector3(cx - L * 0.5, Y0 + 2.12, z), 0.0, Vector3(L / 2.5, 1.3, 1.3))
	var n := maxi(1, int(round(L)))
	for i in n:
		b.parts.append(["#mil_palisade", b.base * Transform3D(Basis.from_scale(Vector3(L / n, 0.32, 0.8)), Vector3(cx - L * 0.5 + L / n * i, Y0 + 2.2, z)), {}])
	var pwid := minf(1.2, 2.0 * hw + 0.2)
	_p(b, "SM_Bld_Wall_01", Vector3(cx - pwid * 0.5, Y0 + 1.72, z + 0.12), 0.0, Vector3(pwid / 2.5, 0.32 / 3.01, 0.1), RED_PLAQUE)
	var nn := num.length()
	for i in nn:
		_u(b, "SM_Prop_Numeral_%s_01" % num[i], Vector3(cx + (i - (nn - 1) * 0.5) * 0.2, Y0 + 1.77, z + 0.15), 0.0, 0.5, GOLD_T)


## Бронзовый (или золотой) орёл на постаменте (если p.y > 0.3 — без постамента: на кровле, на арке)
static func _eagle(b: Bp, p: Vector3, s := 0.42, gold := false) -> void:
	if p.y < 0.3:
		_p(b, "SM_Prop_Plinth_02", Vector3(p.x, Y0, p.z), 0.0, Vector3(0.85, 0.72, 0.85))
		p.y = Y0 + 0.73
	_kit(b, "#mil_eagle", p, 0.0, s)


## Статуя легионера (бронза) на постаменте
static func _statue(b: Bp, p: Vector3, yaw: float, nm := "SM_Prop_Statue_04", s := 0.34, rm := BRONZE_STATUE) -> void:
	if p.y < 0.3:
		_p(b, "SM_Prop_Plinth_02", Vector3(p.x, Y0, p.z), 0.0, Vector3(0.95, 0.62, 0.95))
		p.y = Y0 + 0.63
	_u(b, nm, p, yaw, s, rm)


## Горшок с цветами и куст (как у NewSmall)
static func _pot(b: Bp, p: Vector3, s := 0.26) -> void:
	NewSmall._pot(b, p, s)


# =====================================================================
#   рост с уровнем
# =====================================================================
## g — места прибавок, их задаёт сборка здания:
##   gate [x, полуширина] — ворота у переднего края; stand — значки; banner — [r, сторона, a, y] знамёна на стенах;
##   walls — [[a, dir, len]] каменная ограда (передняя — сама, с разрывом под ворота, если front); fire — свои жаровни;
##   eagle, statue — орёл и статуя; arch — номер легиона на арке (по умолчанию XII); ridge — орёл на коньке;
##   shields — [r, сторона, a, y] золочёные щиты; acro — [точка] акротерии; band — [r, y] золотой пояс
static func _grow(b: Bp, type: String, fr: Array, x: Dictionary, g: Dictionary, t: int) -> void:
	var keep := b.rng
	var gr := RandomNumberGenerator.new()
	gr.seed = hash(type) + 17
	b.rng = gr
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z1: float = fr[3]
	var gate: Array = g.get("gate", [(x0 + x1) * 0.5, 0.75])
	var gx: float = gate[0]
	var gw: float = gate[1]
	var zf := z1 - 0.2
	# 2-й уровень: значки легиона у ворот, знамёна на фасаде
	for p: Vector3 in g.get("stand", []):
		_standard(b, p, 0.72)
	for e: Array in g.get("banner", []):
		_wall_banner(b, e[0], int(e[1]), float(e[2]), float(e[3]), 0.5)
	# 3-й: ограда с зубцами, столбы ворот с огнём
	if t >= 2:
		if bool(g.get("front", true)):
			_wall_line(b, Vector3(x0 + 0.1, Y0, zf), Vector3(1, 0, 0), gx - gw - 0.17 - (x0 + 0.1))
			_wall_line(b, Vector3(gx + gw + 0.17, Y0, zf), Vector3(1, 0, 0), x1 - 0.1 - (gx + gw + 0.17))
		for e: Array in g.get("walls", []):
			_wall_line(b, e[0], e[1], float(e[2]))
		if bool(g.get("front", true)):
			for sd: float in [-1.0, 1.0]:
				var pp := Vector3(gx + sd * (gw + 0.17), Y0, zf)
				_post(b, pp, 0.34, 0.86)
				_brazier(b, pp + Vector3(0, 0.95, 0), 0.26, sd > 0.0)
		var k := 0
		for p: Vector3 in g.get("fire", []):
			_brazier(b, p, 0.34, k == 0)
			k += 1
	# 4-й: пристройка (у каждого своя) и бронзовый орёл
	if t >= 3:
		_wing(b, type, fr, x, g)
		if g.has("eagle"):
			_eagle(b, g["eagle"], 0.42)
	# 5-й: арка ворот с номером легиона, статуи
	if t >= 4:
		if String(g.get("arch_kind", "stone")) == "timber":
			_gate_timber(b, gx, zf, gw, String(g.get("num", "XII")))
		else:
			_arch(b, gx, zf, gw, 2.05, String(g.get("num", "XII")))
		for e: Array in g.get("statue", []):
			_statue(b, e[0], float(e[1]))
	# 6-й: золото
	if t >= 5:
		if g.has("ridge"):
			_kit(b, "#mil_eagle", g["ridge"], 0.0, 0.62)
		for e: Array in g.get("shields", []):
			_wall_shield(b, e[0], int(e[1]), float(e[2]), float(e[3]), 0.36, GOLD_T)
		for p: Vector3 in g.get("acro", []):
			_u(b, "SM_Bld_Ornament_06", p, 0.0, 0.28, GOLD_T)
		if g.has("band"):
			var bd: Array = g["band"]
			var r: Array = bd[0]
			for side: int in [0, 1, 3]:
				NewSmall._run(b, "SM_Bld_Wall_Large_Cap_01", r, side, float(bd[1]), 0.035, 5.02, 0.06 / 0.36, 0.06 / 0.9, GOLD_T, 2.2)
		# золотые орлы на значках у ворот и на арке
		_kit(b, "#mil_eagle", Vector3(gx, Y0 + 2.05 + 0.75, zf), 0.0, 0.5)
	b.rng = keep


## Пристройка 4-го уровня — у каждого здания своя
static func _wing(b: Bp, type: String, fr: Array, x: Dictionary, g: Dictionary) -> void:
	var w: Dictionary = g.get("wing", {})
	match String(w.get("kind", "")):
		"porch":
			_porch(b, float(w["cx"]), float(w["z"]), float(w["hw"]), float(w["dep"]), float(w["h"]), TYM_RED, int(w.get("n", 2)))
		"tower":
			_tower(b, w["r"], float(w["h"]), x, true, int(w.get("side", 0)))
		"crane":
			_kit(b, "#mil_crane", w["p"], float(w.get("yaw", 0.0)))
		"turrets":
			for tr: Array in w["r"]:
				var y0: float = w["y"]
				var res := NewSmall._storey(b, tr, {0: "T", 1: "T", 2: "T", 3: "T"}, y0, 1.0, x, STONE, STONE_WIN, STONE)
				NewSmall._hall(b, NewSmall._inner(tr, 0.24), y0, 0.94, [])
				NewSmall._cornice(b, tr, y0 + 0.98, 0.12, 0.08)
				_parapet(b, [float(tr[0]) - 0.06, float(tr[1]) + 0.06, float(tr[2]) - 0.06, float(tr[3]) + 0.06], y0 + 1.06, [0, 1, 2, 3], 0.18, 0.16)
				NewCivic._floor(b, PAVING, float(tr[0]), float(tr[2]), float(tr[1]), float(tr[3]), y0 + 1.04, 2.0)
				_u(b, "SM_Prop_Banner_03_A", Vector3((float(tr[0]) + float(tr[1])) * 0.5, y0 + 0.92, float(tr[3]) + 0.03), 0.0, 0.42)
		"shed":
			_shed(b, w["r"], float(w["h"]), int(w.get("dir", 1)))
			for e: Array in w.get("items", []):
				_u(b, String(e[0]), e[1], float(e[2]), float(e[3]), e[4] if e.size() > 4 else {})
		"trophies":
			for p: Vector3 in w["p"]:
				_kit(b, "#mil_trophy", p, 0.0, 0.9)
		"pergola":
			var r: Array = w["r"]
			var h: float = w["h"]
			for c: Vector3 in [Vector3(r[0], 0, r[2]), Vector3(r[1], 0, r[2]), Vector3(r[0], 0, r[3]), Vector3(r[1], 0, r[3])]:
				_p(b, "SM_Bld_Pillar_06", Vector3(c.x, Y0, c.z), 0.0, Vector3(0.26, h / 3.0, 0.26))
				_u(b, "SM_Env_Ivy_Pillar_Flowers_0%d" % (1 + b.rng.randi() % 2), Vector3(c.x, Y0, c.z), b.rng.randf() * TAU, 0.55)
			_p(b, "SM_Bld_Trellis_Roof_Large_02", Vector3(r[0], Y0 + h, r[2]), 0.0, Vector3((float(r[1]) - float(r[0])) / 7.5, 0.8, (float(r[3]) - float(r[2])) / 5.0))
			for k in 2:
				b.parts.append(["SM_Env_Vine_0%d" % (1 + k), b.base * Transform3D(Basis(Vector3.UP, k * PI) * Basis(Vector3.RIGHT, -PI / 2) * Basis.from_scale(Vector3(0.8, 0.7, 0.7)),
					Vector3(lerpf(r[0], r[1], 0.3 + 0.4 * k), Y0 + h + 0.2, (float(r[2]) + float(r[3])) * 0.5)), {}])
		"furnace":
			var p: Vector3 = w["p"]
			_u(b, "SM_Prop_Kiln_01", p, float(w.get("yaw", PI)), 0.62)
			NewCivic._fire(b, p + Basis(Vector3.UP, float(w.get("yaw", PI))) * Vector3(0, 0.3, -0.42), 2.4)
			_chimney(b, p + Vector3(0.0, 0, -0.62), 3.4, 0.42)


## Навес: односкатная черепичная кровля на столбах над прямоугольником r (dir 1 — скат к +Z, −1 — к −Z), высота h
static func _shed(b: Bp, r: Array, h: float, dir := 1) -> void:
	var x0: float = r[0]
	var x1: float = r[1]
	var z0: float = r[2]
	var z1: float = r[3]
	var dep := z1 - z0 + 0.2
	var kr := dep / 7.5
	var zl := z1 + 0.1 if dir > 0 else z0 - 0.1
	_p(b, "SM_Bld_Roof_Straight_Thin_Large_01", Vector3(x0 - 0.1 if dir > 0 else x1 + 0.1, Y0 + h, zl), 0.0 if dir > 0 else PI, Vector3((x1 - x0 + 0.2) / 7.5, kr * 1.3, kr))
	var zp := z1 - 0.08 if dir > 0 else z0 + 0.08
	_p(b, "SM_Prop_Beam_01", Vector3(x0, Y0 + h - 0.06, zp), 0.0, Vector3((x1 - x0) / 2.5, 1.0, 1.0))
	var n := maxi(2, int(round((x1 - x0) / 1.6)) + 1)
	for i in n:
		var xx := lerpf(x0 + 0.08, x1 - 0.08, float(i) / (n - 1))
		_p(b, "SM_Prop_Pole_01", Vector3(xx, Y0, zp), 0.0, Vector3(0.6, (h - 0.04) / 3.0, 0.6))


## Каменная труба (квадрат w) от земли p до высоты h, с колпаком и дымом
static func _chimney(b: Bp, p: Vector3, h: float, w := 0.5) -> void:
	var r := [p.x - w * 0.5, p.x + w * 0.5, p.z - w * 0.5, p.z + w * 0.5]
	for side in 4:
		NewSmall._run(b, "SM_Bld_Wall_01", r, side, Y0, -0.11 * 0.5, 2.5, h / 3.01, 0.5, STONE, 2.0)
	NewSmall._cornice(b, r, Y0 + h - 0.04, 0.12, 0.06)
	_p(b, "SM_Bld_Wall_01", Vector3(p.x - w * 0.5 + 0.06, Y0 + h + 0.08, p.z), 0.0, Vector3((w - 0.12) / 2.5, 0.16 / 3.01, (w - 0.12) / 0.22), STONE)
	b.smoke.append(b.base * Vector3(p.x, Y0 + h + 0.3, p.z))


# =====================================================================
#   казармы
# =====================================================================

## Казармы: двухэтажный дом контуберниев — низ из тёсаного камня с широкими воротами и окнами со ставнями, верх
## легионного красного, щит с копьями над воротами, черепица с красным фронтоном; внутри — тёплый зал с койками,
## стойкой копий и щитами на стенах. Перед домом — песчаный плац: два чучела, у них легионеры с мечами, стойки копий
## и мечей, скамья со щитами, у ворот — часовой и значок легиона
static func _barracks(b: Bp, fr: Array, x: Dictionary, g: Dictionary) -> Vector3:
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	var xc := (x0 + x1) * 0.5
	NewCivic._base(b, x0, x1, z0, z1)
	var hd := clampf((z1 - z0) - 2.95, 3.0, 3.4)
	var r := [x0 + 0.1, x1 - 0.1, z0 + 0.12, z0 + 0.12 + hd]
	var hz1: float = r[3]
	x["leaf"] = LEAF_WOOD
	x["shut"] = "#shutters_brown"
	var h := _house(b, r, {0: "SGS", 1: "NW", 2: "TNT", 3: "WN"}, {0: "BWB", 1: "SW", 2: "SNS", 3: "WS"}, x, {"H1": 2.3, "H2": 1.5, "roof": "x"})
	var res: Dictionary = h["res"]
	var y2: float = h["y2"]
	var ytop: float = h["ytop"]
	var gate: Array = res["G"][0]
	var gcx := _mx(r, gate)
	# над воротами — щит легиона и копья накрест, по сторонам ворот — фонари
	var up: Dictionary = h["up"]
	for e: Array in up["W"]:
		if int(e[0]) == 0:
			var wx := float(e[1]) + float(e[2]) * 0.5
			_wall_shield(b, r, 0, wx, y2 + 0.78, 0.5)
			for sd: float in [-1.0, 1.0]:
				_p(b, "SM_Wep_Spear_01", NewSmall._at(r, 0, wx + sd * 0.12, 0.04, y2 + 0.2), 0.0, Vector3.ONE * 0.55)
				b.parts[-1][1] = b.parts[-1][1] * Transform3D(Basis(Vector3.BACK, sd * 0.45), Vector3.ZERO)
	for sd: float in [-1.0, 1.0]:
		_p(b, "#wall_lamp", Vector3(gcx + sd * 0.85, Y0 + 1.62, hz1 + 0.02), 0.0)
	# нутро: койки у задней стены, стол с табуретами, стойка копий, щиты на стене
	var ir: Array = h["ir"]
	var ix0: float = ir[0]
	var ix1: float = ir[1]
	var iz0: float = ir[2]
	var iz1: float = ir[3]
	for k in 3:
		var kx := lerpf(ix0 + 0.75, ix1 - 0.75, k / 2.0)
		_u(b, "SM_Prop_Seat_Kline_02", Vector3(kx, Y0, iz0 + 0.42), 0.0, 0.42, GLOW)
		_u(b, "SM_Prop_Pillow_0%d" % (1 + k), Vector3(kx - 0.35, Y0 + 0.26, iz0 + 0.42), 0.2, 0.36, GLOW)
		_wall_shield(b, [ix0, ix1, iz0 - 0.06, iz1], 2, (ix1 - ix0) - (kx - ix0), Y0 + 1.45, 0.34, GLOW)
	_p(b, "SM_Prop_Table_01", Vector3(gcx, Y0, (iz0 + iz1) * 0.5 + 0.2), 0.0, Vector3.ONE * 0.5, GLOW)
	_rack(b, Vector3(ix0 + 0.18, Y0, (iz0 + iz1) * 0.5), PI / 2, 1, 0.38, GLOW)
	# плац: песок, два чучела, легионеры с мечами лицом к ним
	var yz0 := hz1 + 0.3
	_sand(b, x0 + 0.35, x1 - 0.35, yz0, z1 - 0.45)
	for sd: float in [-1.0, 1.0]:
		_kit(b, "#mil_dummy", Vector3(xc + sd * 1.4, Y0, hz1 + 1.05), sd * 0.15, 0.62)
		b.actor(Vector3(xc + sd * 1.4, Y0, hz1 + 1.8), PI, "Sword_Idle", "soldier")
	# стойки копий и мечей у боков, скамья и щиты у стены, часовой и значок у ворот
	_rack(b, Vector3(x0 + 0.48, Y0, hz1 + 0.85), PI / 2, 1, 0.42)
	_rack(b, Vector3(x1 - 0.48, Y0, hz1 + 0.85), -PI / 2, 2, 0.42)
	_p(b, "SM_Prop_Seat_Bench_01", Vector3(gcx - 1.75, Y0, hz1 + 0.24), 0.0, Vector3.ONE * 0.5)
	for k in 2:
		_lean_shield(b, Vector3(gcx - 2.35 + k * 0.28, Y0, hz1 + 0.16), 0.1 * k, "SM_Wep_Shield_0%d" % [4, 2][k], 0.42)
	_standard(b, Vector3(gcx - 1.25, Y0, hz1 + 0.32), 0.6)
	b.actor(Vector3(gcx + 1.2, Y0, hz1 + 0.42), 0.0, "Idle", "soldier")
	NewCivic2._trough(b, Vector3(gcx + 1.85, Y0, hz1 + 0.3), 0.0, 0.5)
	_u(b, "SM_Prop_Jar_Pile_01", Vector3(x1 - 0.55, Y0, hz1 + 1.85), 0.4, 0.36)
	_pot(b, Vector3(gcx - 2.55, Y0, hz1 + 0.22), 0.22)
	_pot(b, Vector3(gcx + 2.45, Y0, hz1 + 0.6), 0.22)
	NewCivic._bush(b, Vector3(x0 + 0.55, Y0, hz1 + 1.85), 0.2)
	# места прибавок уровня
	g["gate"] = [gcx, 0.72]
	g["stand"] = [Vector3(x0 + 0.42, Y0, z1 - 0.6), Vector3(x1 - 0.42, Y0, z1 - 0.6)]
	var wl := float(r[1]) - float(r[0])
	g["banner"] = [[r, 0, wl / 3.0, ytop - 0.12], [r, 0, wl * 2.0 / 3.0, ytop - 0.12]]
	g["walls"] = [[Vector3(x0 + 0.21, Y0, z1 - 0.2), Vector3(0, 0, -1), z1 - 0.2 - hz1 - 0.05], [Vector3(x1 - 0.21, Y0, hz1 + 0.05), Vector3(0, 0, 1), z1 - 0.2 - hz1 - 0.05]]
	g["wing"] = {"kind": "porch", "cx": gcx, "z": hz1, "hw": 0.95, "dep": 0.62, "h": 2.25}
	g["eagle"] = Vector3(gcx, Y0 + 2.45, hz1 + 0.7)
	g["statue"] = [[Vector3(gcx - 0.89, Y0 + 2.55, z1 - 0.2), 0.0], [Vector3(gcx + 0.89, Y0 + 2.55, z1 - 0.2), 0.0]]
	g["ridge"] = Vector3(xc, float(h["ridge"]) + 0.05, (float(r[2]) + hz1) * 0.5)
	g["shields"] = [[r, 0, wl / 6.0, y2 + 0.78], [r, 0, wl * 5.0 / 6.0, y2 + 0.78]]
	g["acro"] = [Vector3(float(r[0]) - 0.1, ytop + 0.1, (float(r[2]) + hz1) * 0.5), Vector3(float(r[1]) + 0.1, ytop + 0.1, (float(r[2]) + hz1) * 0.5)]
	g["band"] = [r, ytop - 0.24]
	g["num"] = "XII"
	return Vector3(gcx, 0, z1 + 0.3)


# =====================================================================
#   стрельбище
# =====================================================================

## Стрельбище: слева сзади — оружейная хижина (камень и охра, фронтон к улице, лук и колчаны в тёплой комнате);
## справа — стрелковая дорожка: сзади каменная стенка-вал со снопами соломы и тремя мишенями, впереди — рубеж
## с колышками и верёвкой, лучники лицом к мишеням, корзины стрел; у хижины — скамья под козырьком и стойка луков
static func _range(b: Bp, fr: Array, x: Dictionary, g: Dictionary) -> Vector3:
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	var xc := (x0 + x1) * 0.5
	NewCivic._base(b, x0, x1, z0, z1)
	# хижина
	var hr := [x0 + 0.1, x0 + 2.45, z0 + 0.12, z0 + 2.55]
	var hz1: float = hr[3]
	x["leaf"] = LEAF_WOOD
	x["shut"] = "#shutters_green"
	var h := _house(b, hr, {0: "D", 1: "SW", 2: "N", 3: "WS"}, {}, x, {"H1": 2.3, "roof": "z", "frieze": true, "stone": false})
	var res: Dictionary = h["res"]
	var ytop: float = h["ytop"]
	var d: Array = res["D"][0]
	var dcx := _mx(hr, d)
	_p(b, "SM_Prop_Overhang_01", Vector3(dcx, Y0 + 2.1, hz1 + 0.02), 0.0, Vector3(0.62, 0.85, 0.8))
	_p(b, "#wall_lamp", Vector3(dcx + 0.62, Y0 + 1.6, hz1 + 0.02), 0.0)
	_u(b, "SM_Bld_Ornament_02", Vector3(dcx, ytop + 0.18, hz1 + 0.17), 0.0, 0.26)
	var ir: Array = h["ir"]
	_rack(b, Vector3((float(ir[0]) + float(ir[1])) * 0.5, Y0, float(ir[2]) + 0.12), 0.0, 2, 0.4, GLOW)
	_kit(b, "#mil_quiver", Vector3(float(ir[0]) + 0.3, Y0, float(ir[3]) - 0.35), 0.0, 0.62)
	_kit(b, "#mil_quiver", Vector3(float(ir[1]) - 0.3, Y0, float(ir[3]) - 0.4), 0.8, 0.62)
	# стрелковая дорожка
	var lx0 := float(hr[1]) + 0.3
	var lx1 := x1 - 0.3
	_sand(b, lx0, lx1, z0 + 0.3, z1 - 0.45)
	# вал: каменная стенка со снопами соломы, перед ней — мишени
	_wall_line(b, Vector3(lx0 - 0.05, Y0, z0 + 0.3), Vector3(1, 0, 0), lx1 - lx0 + 0.1, 0.62, 0.3, false)
	var tx := []
	for i in 3:
		var t := lerpf(lx0 + 0.6, lx1 - 0.6, i / 2.0)
		tx.append(t)
		_u(b, "SM_Prop_Straw_Stack_01", Vector3(t + b.rng.randf_range(-0.1, 0.1), Y0, z0 + 0.62), b.rng.randf() * TAU, 0.45)
		_kit(b, "#mil_target", Vector3(t, Y0, z0 + 1.2 + (0.1 if i == 1 else 0.0)), b.rng.randf_range(-0.1, 0.1), 0.62)
	# рубеж: колышки с верёвкой и красными флажками, лучники лицом к мишеням, корзины стрел
	var lz := z1 - 1.25
	for t: float in [lx0 + 0.15, (lx0 + lx1) * 0.5, lx1 - 0.15]:
		_p(b, "SM_Prop_Pole_01", Vector3(t, Y0, lz), 0.0, Vector3(0.3, 0.22, 0.3))
	_kit(b, "#mil_rope", Vector3(lx0 + 0.15, Y0 + 0.6, lz), 0.0, ((lx1 - lx0) * 0.5 - 0.15) / 2.25)
	_kit(b, "#mil_rope", Vector3((lx0 + lx1) * 0.5, Y0 + 0.6, lz), 0.0, ((lx1 - lx0) * 0.5 - 0.15) / 2.25)
	for i in [0, 2]:
		b.actor(Vector3(float(tx[i]), Y0, lz + 0.42), PI, "Pistol_Idle", "soldier")
		_kit(b, "#mil_quiver", Vector3(float(tx[i]) + 0.42, Y0, lz + 0.5), b.rng.randf() * TAU, 0.55)
	b.actor(Vector3(float(tx[1]) + 0.2, Y0, lz + 0.8), PI + 0.4, "Idle", "soldier")
	# у хижины: скамья, стойка луков, корзины, кипарис
	_p(b, "SM_Prop_Seat_Bench_02", Vector3(dcx - 0.25, Y0, hz1 + 0.28), 0.0, Vector3.ONE * 0.45)
	_rack(b, Vector3(float(hr[1]) - 0.05, Y0, hz1 + 0.55), -PI / 2, 2, 0.36)
	_u(b, "SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 5), Vector3(x0 + 0.35, Y0, hz1 + 0.3), 0.0, 0.4)
	NewCivic._cypress(b, Vector3(x0 + 0.4, Y0, z0 + 0.4), 0.3)
	_standard(b, Vector3(lx1 - 0.3, Y0, lz + 0.05), 0.6)
	_u(b, "SM_Prop_Straw_Bundle_01", Vector3(lx1 - 0.35, Y0, z0 + 1.0), 0.6, 0.55)
	_u(b, "SM_Prop_Straw_Bundle_01", Vector3(lx0 + 0.3, Y0, z0 + 0.95), 2.0, 0.5)
	_pot(b, Vector3(float(hr[1]) + 0.05, Y0, z0 + 0.35), 0.22)
	_pot(b, Vector3(x0 + 1.95, Y0, hz1 + 0.25), 0.22)
	# места прибавок
	g["gate"] = [xc - 0.1, 0.72]
	g["stand"] = [Vector3(x0 + 0.42, Y0, z1 - 0.6), Vector3(x1 - 0.42, Y0, z1 - 0.6)]
	g["banner"] = [[hr, 1, 1.45, ytop - 0.15], [hr, 0, 0.32, ytop - 0.15]]
	g["walls"] = [[Vector3(x0 + 0.21, Y0, z1 - 0.2), Vector3(0, 0, -1), z1 - 0.2 - hz1 - 0.05], [Vector3(x1 - 0.21, Y0, z0 + 0.5), Vector3(0, 0, 1), z1 - 0.7 - z0]]
	g["wing"] = {"kind": "tower", "r": [x0 + 0.25, x0 + 1.4, hz1 + 0.75, hz1 + 1.9], "h": 2.9, "side": 1}
	g["eagle"] = Vector3((lx0 + lx1) * 0.5, Y0, z1 - 0.62)
	g["statue"] = [[Vector3((lx0 + lx1) * 0.5 + 1.0, Y0, z1 - 0.62), PI]]
	g["ridge"] = Vector3(dcx, float(h["ridge"]) + 0.02, float(hr[3]) + 0.05)
	g["shields"] = [[hr, 1, 0.5, Y0 + 1.6], [hr, 3, 1.9, Y0 + 1.6]]
	g["acro"] = [Vector3(float(hr[0]) + 0.05, ytop + 0.12, hz1 + 0.08), Vector3(float(hr[1]) - 0.05, ytop + 0.12, hz1 + 0.08)]
	g["band"] = [hr, ytop - 0.24]
	g["num"] = "VII"
	return Vector3(xc - 0.1, 0, z1 + 0.3)


# =====================================================================
#   лагерь копейщиков
# =====================================================================

## Лагерь копейщиков: частокол вокруг (ворота к улице), песчаный двор, сзади — две кожаные палатки (за пологом —
## тёплый свет лампы), между ними стойка копий; посреди — большой значок легиона, у костра в жаровне — табуреты
## и отдыхающий копейщик; спереди справа — два чучела и копейщики лицом к ним; копья, щиты, корзины
static func _spearcamp(b: Bp, fr: Array, x: Dictionary, g: Dictionary) -> Vector3:
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	var xc := (x0 + x1) * 0.5
	NewCivic._base(b, x0, x1, z0, z1)
	_sand(b, x0 + 0.25, x1 - 0.25, z0 + 0.25, z1 - 0.25)
	# частокол по краю, ворота посередине спереди
	var gw := 0.72
	var e := 0.2
	var segs := [[Vector3(x0 + e, Y0, z1 - e), Vector3(1, 0, 0), xc - gw - (x0 + e)], [Vector3(xc + gw, Y0, z1 - e), Vector3(1, 0, 0), x1 - e - (xc + gw)],
		[Vector3(x1 - e, Y0, z1 - e), Vector3(0, 0, -1), z1 - z0 - 2.0 * e], [Vector3(x1 - e, Y0, z0 + e), Vector3(-1, 0, 0), x1 - x0 - 2.0 * e],
		[Vector3(x0 + e, Y0, z0 + e), Vector3(0, 0, 1), z1 - z0 - 2.0 * e]]
	for sg: Array in segs:
		var a: Vector3 = sg[0]
		var dir: Vector3 = sg[1]
		var L: float = sg[2]
		var n := maxi(1, int(round(L)))
		var st := L / n
		var yaw := atan2(-dir.z, dir.x)
		for i in n:
			b.parts.append(["#mil_palisade", b.base * Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(st, 0.78, 1.0)), a + dir * (st * i)), {}])
	# столбы ворот: толстые брёвна, на них — щиты
	for sd: float in [-1.0, 1.0]:
		var gp := Vector3(xc + sd * (gw + 0.05), Y0, z1 - e)
		_p(b, "SM_Prop_Pole_01", gp, 0.0, Vector3(1.1, 0.6, 1.1))
		_u(b, "SM_Wep_Shield_0%d" % [1, 3][int(sd > 0)], gp + Vector3(0, 1.15, 0.1), 0.0, 0.42)
	# палатки сзади, между ними — стойка копий
	for sd: float in [-1.0, 1.0]:
		_tent(b, Vector3(xc + sd * 1.35, Y0, z0 + 1.35), sd * -0.06)
		_lean_shield(b, Vector3(xc + sd * 1.35 + 0.62, Y0, z0 + 2.45), -sd * 0.3, "SM_Wep_Shield_0%d" % [4, 2][int(sd > 0)], 0.42)
		b.parts.append(["SM_Wep_Spear_0%d" % (1 + int(sd > 0)), b.base * Transform3D(Basis(Vector3.UP, sd) * Basis(Vector3.RIGHT, 0.06) * Basis.from_scale(Vector3.ONE * 0.62), Vector3(xc + sd * 1.35 - 0.68, Y0 + 0.62, z0 + 2.4)), {}])
	_rack(b, Vector3(xc, Y0, z0 + 0.55), 0.0, 1, 0.4)
	# посреди — большой значок, у костра — табуреты и отдыхающий
	_standard(b, Vector3(xc - 0.35, Y0, z0 + 3.0), 0.8)
	var fx := x0 + 1.15
	var fz := z1 - 1.85
	_brazier(b, Vector3(fx, Y0, fz), 0.36, true)
	_u(b, "SM_Prop_Seat_Stool_01", Vector3(fx - 0.55, Y0, fz + 0.3), 0.6, 0.5)
	_u(b, "SM_Prop_Seat_Stool_01", Vector3(fx + 0.5, Y0, fz + 0.4), -0.4, 0.5)
	b.actor(Vector3(fx - 0.55, Y0 + 0.02, fz + 0.3), 0.6 + PI * 0.8, "Sitting_Idle", "soldier")
	_u(b, "SM_Prop_Jug_0%d" % (1 + b.rng.randi() % 5), Vector3(fx + 0.1, Y0, fz + 0.62), 0.0, 0.4)
	# чучела и копейщики
	for k in 2:
		var dx := xc + 0.55 + k * 1.3
		_kit(b, "#mil_dummy", Vector3(dx, Y0, z1 - 2.25), 0.15 - 0.3 * k, 0.6)
		b.actor(Vector3(dx, Y0, z1 - 1.5), PI, "Sword_Idle", "soldier")
	_u(b, "SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 5), Vector3(x1 - 0.55, Y0, z0 + 2.85), 0.0, 0.42)
	_u(b, "SM_Prop_Sack_Stack_01", Vector3(x0 + 0.55, Y0, z0 + 2.9), 0.4, 0.42)
	# места прибавок: у лагеря ограда уже есть — на 3-м уровне знамёна на частоколе
	g["gate"] = [xc, gw - 0.17]
	g["front"] = false
	g["fire"] = [Vector3(xc - 0.95, Y0, z1 - 1.05), Vector3(xc + 0.95, Y0, z1 - 1.05)]
	g["arch_kind"] = "timber"
	g["stand"] = [Vector3(xc - 1.15, Y0, z1 - 0.62), Vector3(xc + 1.15, Y0, z1 - 0.62)]
	g["banner"] = []
	g["walls"] = []
	g["wing"] = {"kind": "tower", "r": [x0 + 0.42, x0 + 1.47, z0 + 2.45, z0 + 3.5], "h": 2.4, "side": 0}
	g["eagle"] = Vector3(x1 - 0.75, Y0, z1 - 0.75)
	g["statue"] = []
	g["ridge"] = Vector3(xc - 0.35, Y0 + 2.75, z0 + 3.0)
	g["shields"] = []
	g["num"] = "IX"
	return Vector3(xc, 0, z1 + 0.3)


# =====================================================================
#   мастерские баллист и катапульт
# =====================================================================

## Мастерская баллист (cat = false): слева — двухэтажный цех (кирпичный низ с широкими воротами в тёплый зал с
## верстаком, верх охрой, чердачная дверь с балкой-подъёмником), справа — двор: готовая баллиста на треноге, связка
## болтов на козлах, верстак под полотняным навесом, точило, штабель брусьев.
## Мастерская катапульт (cat = true): зеркально — цех справа (низ из тёсаного камня, верх терракотой, фронтон к улице),
## слева — каменный двор: онагр с камнем в ковше, груда ядер, мраморные глыбы под тёску, наковальня
static func _siege(b: Bp, fr: Array, x: Dictionary, g: Dictionary, cat: bool) -> Vector3:
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	var xc := (x0 + x1) * 0.5
	var m := -1.0 if cat else 1.0                      # цех слева (баллисты) или справа (катапульты)
	NewCivic._base(b, x0, x1, z0, z1)
	var hw := 3.55
	var hd := clampf((z1 - z0) - 2.3, 3.0, 3.3)
	var r := [x0 + 0.1, x0 + 0.1 + hw, z0 + 0.12, z0 + 0.12 + hd] if not cat else [x1 - 0.1 - hw, x1 - 0.1, z0 + 0.12, z0 + 0.12 + hd]
	var hz1: float = r[3]
	x["leaf"] = LEAF_WOOD
	x["shut"] = "#shutters_brown"
	var tb: Color = Color(1.0, 0.8, 0.66)
	var brick := {"Stucco_White_01": "Building_Large_Brick_01", "tints": {"Building_Large_Brick_01": tb}}
	var bwin := {"Stucco_White_01": "Building_Marble_01", "Stucco_Orange_01": "Building_Large_Brick_01", "tints": {"Building_Large_Brick_01": tb}}
	var lo := {0: "GS" if not cat else "SG", 1: "TW", 2: "TWT", 3: "WT"}
	var upm := {0: "SL" if not cat else "LS", 1: "NS", 2: "SNS", 3: "SN"}
	var res := {}
	var h := {}
	if not cat:
		res = NewSmall._storey(b, r, lo, Y0, 2.35, x, brick, bwin, {"tints": {"Building_Large_Brick_01": tb}})
		h = _house_top(b, r, res, upm, x, 2.35, 1.45, "x", lo)
	else:
		h = _house(b, r, lo, upm, x, {"H1": 2.35, "H2": 1.45, "roof": "z", "tym": TYMPANUM})
		res = h["res"]
	var ytop: float = h["ytop"]
	var y2: float = h["y2"]
	var gate: Array = res["G"][0]
	var gcx := _mx(r, gate)
	# чердачная дверь: балка-подъёмник с канатом и корзиной
	var up: Dictionary = h["up"]
	for e: Array in up["L"]:
		var lcx := _mx(r, e)
		_p(b, "SM_Prop_Beam_01", Vector3(lcx, y2 + 1.27, hz1 - 0.25), -PI / 2, Vector3(0.42, 1.2, 1.2))
		_u(b, "SM_Prop_Basket_02", Vector3(lcx, y2 - 0.25, hz1 + 0.72), 0.4, 0.45)
	_p(b, "#wall_lamp", Vector3(gcx - 0.85 * m, Y0 + 1.7, hz1 + 0.02), 0.0)
	_u(b, "SM_Prop_Symbol_0%d" % (6 if cat else 5), Vector3(gcx, Y0 + 2.08, hz1 + 0.04), 0.0, 0.36)
	# тёплый зал: верстак, инструменты, брусья, заготовка ложа
	var ir: Array = h["ir"]
	var ix0: float = ir[0]
	var ix1: float = ir[1]
	var iz0: float = ir[2]
	var iz1: float = ir[3]
	_u(b, "SM_Prop_Table_04", Vector3((ix0 + ix1) * 0.5, Y0, iz0 + 0.45), 0.0, 0.55, GLOW)
	_u(b, "SM_Prop_Tool_Hammer_01", Vector3((ix0 + ix1) * 0.5 - 0.2, Y0 + 0.5, iz0 + 0.45), 0.8, 0.7, GLOW)
	for k in 3:
		_u(b, "SM_Prop_Beam_01", Vector3(ix1 - 0.5 if not cat else ix0 + 0.5, Y0 + 0.06 + k * 0.1, iz1 - 0.6 - k * 0.04), PI / 2, 0.5, GLOW)
	_u(b, "SM_Prop_Shelf_01", Vector3(ix0 + 0.6 if not cat else ix1 - 0.6, Y0, iz0 + 0.18), 0.0, 0.5, GLOW)
	# двор
	var yx0 := float(r[1]) + 0.25 if not cat else x0 + 0.3
	var yx1 := x1 - 0.3 if not cat else float(r[0]) - 0.25
	var ycx := (yx0 + yx1) * 0.5
	_sand(b, yx0, yx1, z0 + 0.3, z1 - 0.45)
	if not cat:
		# навес над верстаком сзади, баллиста на виду впереди
		var ar := [yx0 + 0.05, yx1 - 0.05, z0 + 0.3, z0 + 1.8]
		for c: Vector3 in [Vector3(ar[0], 0, ar[2]), Vector3(ar[1], 0, ar[2]), Vector3(ar[0], 0, ar[3]), Vector3(ar[1], 0, ar[3])]:
			_p(b, "SM_Prop_Pole_01", Vector3(c.x, Y0, c.z), 0.0, Vector3(0.5, 2.0 / 3.0, 0.5))
		_p(b, "SM_Prop_Banner_Roof_01", Vector3(ar[0] - 0.05, Y0 + 2.0, ar[3] + 0.08), 0.0, Vector3((ar[1] - ar[0] + 0.1) / 2.6, 0.9, (ar[3] - ar[2] + 0.16) / 2.6), Catalog.canopy_remap(4))
		_u(b, "SM_Prop_Table_04", Vector3(ycx, Y0, z0 + 0.95), 0.0, 0.55)
		_u(b, "SM_Prop_Tool_Hammer_01", Vector3(ycx - 0.15, Y0 + 0.5, z0 + 0.95), 0.6, 0.7)
		_u(b, "SM_Prop_Tool_Chisel_01", Vector3(ycx + 0.2, Y0 + 0.5, z0 + 1.0), 2.0, 0.7)
		_u(b, "SM_Prop_Grinding_Wheel_01", Vector3(yx1 - 0.3, Y0 + 0.2, z0 + 1.0), PI / 2, 0.5)
		b.actor(Vector3(ycx, Y0, z0 + 1.45), PI, "Interact", "pleb")
		_kit(b, "#mil_ballista", Vector3(ycx - 0.1, Y0, z1 - 1.75), 0.35, 0.68)
		b.actor(Vector3(ycx + 0.75, Y0, z1 - 1.3), -2.0, "Fixing_Kneeling", "pleb")
		_kit(b, "#mil_bolts", Vector3(yx0 + 0.45, Y0, z0 + 2.3), PI / 2, 0.62)
		for k in 3:
			_u(b, "SM_Prop_Beam_01", Vector3(yx1 - 0.3, Y0 + 0.05 + k * 0.1, z1 - 1.5 + k * 0.03), PI / 2 + 0.03 * k, 0.5)
	else:
		# онагр, ядра, глыбы, наковальня
		_kit(b, "#mil_catapult", Vector3(ycx + 0.05, Y0, z0 + 1.7), 0.3, 0.7)
		_u(b, "SM_Prop_Marble_Stack_01", Vector3(ycx - 0.3, Y0, z0 + 3.0), 0.3, 0.32)
		b.actor(Vector3(ycx + 0.85, Y0, z0 + 2.3), -0.8, "Fixing_Kneeling", "pleb")
		_kit(b, "#mil_stones", Vector3(yx0 + 0.4, Y0, z1 - 1.35), 0.0, 0.62)
		_kit(b, "#mil_stones", Vector3(yx1 - 0.35, Y0, z0 + 0.45), 1.3, 0.55)
		_u(b, "SM_Prop_Marble_Block_0%d" % (1 + b.rng.randi() % 4), Vector3(ycx + 0.6, Y0, z1 - 1.05), 0.2, 0.36)
		_u(b, "SM_Prop_Marble_Rubble_0%d" % (1 + b.rng.randi() % 7), Vector3(ycx + 0.05, Y0, z1 - 0.8), 0.0, 0.5)
		_u(b, "SM_Prop_Anvil_01", Vector3(yx0 + 0.35, Y0, z0 + 0.55), 0.6, 0.5)
		_u(b, "SM_Prop_Tool_Hammer_01", Vector3(ycx + 0.62, Y0 + 0.36, z1 - 1.1), 0.4, 0.7)
		b.actor(Vector3(ycx + 0.62, Y0, z1 - 0.62), PI, "Interact", "pleb")
	_pot(b, Vector3(gcx + 1.1 * m, Y0, hz1 + 0.22), 0.24)
	_standard(b, Vector3(gcx + 0.95 * m, Y0, hz1 + 0.45) if not cat else Vector3(gcx + 0.95 * m, Y0, hz1 + 0.45), 0.58)
	# места прибавок
	g["gate"] = [xc, 0.72]
	g["stand"] = [Vector3(x0 + 0.42, Y0, z1 - 0.6), Vector3(x1 - 0.42, Y0, z1 - 0.6)]
	g["banner"] = [[r, 0, 0.3, ytop - 0.12], [r, 0, hw - 0.3, ytop - 0.12]]
	var ys := x1 - 0.21 if not cat else x0 + 0.21
	g["walls"] = [[Vector3(ys, Y0, z1 - 0.2), Vector3(0, 0, -1), z1 - z0 - 0.45] if not cat else [Vector3(ys, Y0, z0 + 0.25), Vector3(0, 0, 1), z1 - z0 - 0.45]]
	g["wing"] = {"kind": "crane", "p": Vector3(ycx, Y0, z1 - 1.75 if not cat else z0 + 1.75), "yaw": 0.0}
	g["eagle"] = Vector3(float(r[0]) + 0.45 if not cat else float(r[1]) - 0.45, Y0, z1 - 0.7)
	g["statue"] = []
	g["ridge"] = Vector3((float(r[0]) + float(r[1])) * 0.5, float(h["ridge"]) + 0.03, (float(r[2]) + hz1) * 0.5 if not cat else hz1 + 0.05)
	g["shields"] = [[r, 1 if not cat else 3, 1.2, y2 + 0.75]]
	g["acro"] = [Vector3(float(r[0]) + 0.05, ytop + 0.12, hz1 + 0.08), Vector3(float(r[1]) - 0.05, ytop + 0.12, hz1 + 0.08)] if cat else []
	g["band"] = [r, ytop - 0.24]
	g["num"] = "V" if cat else "IV"
	return Vector3(xc, 0, z1 + 0.3)


## Верх дома над готовым нижним ярусом (кирпичный низ): верхний ярус, пояса, пилястры, фриз, кровля, нутро
static func _house_top(b: Bp, r: Array, res: Dictionary, upm: Dictionary, x: Dictionary, H1: float, H2: float, roof: String, lo: Dictionary) -> Dictionary:
	var E := 0.14
	var y2 := Y0 + H1 + E
	var upr := NewSmall._storey(b, r, upm, y2, H2, x)
	for side in 4:
		NewSmall._run(b, "SM_Bld_Wall_01", r, side, Y0 + H1, -0.11 * 0.6, 2.5, E / 3.01, 0.6, x["st"], 1.8)
	NewSmall._cornice(b, r, Y0 + H1 - 0.03, E + 0.04, 0.08)
	var ytop := y2 + H2
	var cnt := {}
	for side: int in lo:
		cnt[side] = String(lo[side]).length()
	NewSmall._pilasters(b, r, cnt, Y0, H1, 0.22)
	NewSmall._pilasters(b, r, cnt, y2, H2, 0.16)
	NewSmall._cornice(b, r, ytop - 0.03, 0.16, 0.1)
	for e: Array in upr["W"]:
		if int(e[0]) != 0:
			NewSmall._ivy(b, r, e, y2, H2, 2)
	for e: Array in res["W"]:
		var side: int = e[0]
		_on(b, "SM_Bld_Ornament_0%d" % [2, 6][side % 2], r, side, float(e[1]) + float(e[2]) * 0.5, Y0 + H1 * 0.62, 0.34, 0.02)
	var ridge := NewSmall._roof(b, r, ytop + 0.08, roof == "z", TYM_RED, 0.16)
	var ir := NewSmall._inner(r, 0.33)
	NewSmall._hall(b, ir, Y0, ytop - Y0 - 0.1, NewSmall._gaps(r, res))
	b.light(Vector3((float(ir[0]) + float(ir[1])) * 0.5, Y0 + 1.5, (float(ir[2]) + float(ir[3])) * 0.5))
	return {"res": res, "up": upr, "ytop": ytop, "ridge": ridge, "y2": y2, "ir": ir, "H1": H1}


# =====================================================================
#   кузница
# =====================================================================

## Кузница: слева — кирпичная мастерская под черепицей, спереди дверь и открытый горн за прилавком (огонь светится,
## над ним — высокая каменная труба с дымом); внутри — горн, наковальня, клещи и мечи на стене. Справа — двор под
## навесом: наковальня с кузнецом, точило, бочка для закалки, стойка мечей, уголь, бруски железа
static func _forge(b: Bp, fr: Array, x: Dictionary, g: Dictionary) -> Vector3:
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	var xc := (x0 + x1) * 0.5
	NewCivic._base(b, x0, x1, z0, z1)
	var r := [x0 + 0.1, x0 + 3.85, z0 + 0.12, z0 + 3.0]
	var hz1: float = r[3]
	x["leaf"] = LEAF_WOOD
	x["shut"] = "#shutters_brown"
	var tb: Color = Color(0.92, 0.72, 0.6)
	var brick := {"Stucco_White_01": "Building_Large_Brick_01", "tints": {"Building_Large_Brick_01": tb}}
	var bwin := {"Stucco_White_01": "Building_Marble_01", "Stucco_Orange_01": "Building_Large_Brick_01", "tints": {"Building_Large_Brick_01": tb}}
	var lo := {0: "DO", 1: "TW", 2: "TWT", 3: "WT"}
	var res := NewSmall._storey(b, r, lo, Y0, 2.6, x, brick, bwin, {"tints": {"Building_Large_Brick_01": tb}})
	var ytop := Y0 + 2.6
	NewSmall._pilasters(b, r, {0: 2, 1: 2, 2: 3, 3: 2}, Y0, 2.6, 0.22)
	NewSmall._frieze(b, r, ytop - 0.2)
	NewSmall._cornice(b, r, ytop - 0.03, 0.16, 0.1)
	for e: Array in res["W"]:
		if int(e[0]) == 2:
			NewSmall._ivy(b, r, e, Y0, 2.6, 3)
		else:
			_on(b, "SM_Wep_Sword_0%d" % (1 + int(e[0]) % 3), r, int(e[0]), float(e[1]) + float(e[2]) * 0.5, Y0 + 1.1, 0.6, 0.04)
	var ridge := NewSmall._roof(b, r, ytop + 0.08, false, TYM_RED, 0.16)
	var ir := NewSmall._inner(r, 0.33)
	NewSmall._hall(b, ir, Y0, 2.5, NewSmall._gaps(r, res))
	var ix0: float = ir[0]
	var ix1: float = ir[1]
	var iz0: float = ir[2]
	var iz1: float = ir[3]
	# горн за открытым проёмом: огонь, свет, наковальня, мечи и клещи на стене
	var o: Array = res["O"][0]
	var ocx := _mx(r, o)
	_u(b, "SM_Prop_Forge_01", Vector3(ocx, Y0, iz0 + 0.55), 0.0, 0.5, GLOW)
	NewCivic._fire(b, Vector3(ocx, Y0 + 0.55, iz0 + 0.62), 3.0)
	_p(b, "SM_Bld_Wall_01", Vector3(ocx - 0.32, Y0 + 0.42, iz0 + 0.4), 0.0, Vector3(0.64 / 2.5, 0.16 / 3.01, 0.5), EMBER)
	b.light(Vector3(ocx, Y0 + 0.9, iz0 + 1.0))
	_u(b, "SM_Prop_Anvil_01", Vector3(ocx - 0.2, Y0, iz1 - 0.75), 0.4, 0.42, GLOW)
	for k in 3:
		_u(b, "SM_Wep_Sword_0%d" % (1 + k), Vector3(ix0 + 0.4 + k * 0.25, Y0 + 1.25, iz0 + 0.04), 0.0, 0.55, GLOW)
	_chimney(b, Vector3(ocx, 0, float(r[2]) + 0.35), float(ridge) + 0.8 - Y0, 0.55)
	var d: Array = res["D"][0]
	var dcx := _mx(r, d)
	_p(b, "#wall_lamp", Vector3(dcx - 0.6, Y0 + 1.65, hz1 + 0.02), 0.0)
	_u(b, "SM_Prop_Symbol_0%d" % 7, Vector3(dcx, Y0 + 2.2, hz1 + 0.04), 0.0, 0.36)
	# двор под навесом: наковальня с кузнецом, точило, бочка, стойка мечей, уголь, железо
	var yx0 := float(r[1]) + 0.25
	var yx1 := x1 - 0.3
	_sand(b, yx0, yx1, z0 + 0.3, z1 - 0.45)
	_shed(b, [yx0, yx1, z0 + 0.25, z0 + 2.25], 2.2, 1)
	_rack(b, Vector3((yx0 + yx1) * 0.5, Y0, z0 + 0.42), 0.0, 2, 0.42)
	_u(b, "SM_Prop_Grinding_Wheel_01", Vector3(yx0 + 0.35, Y0 + 0.2, z0 + 1.2), 1.4, 0.48)
	_kit(b, "#mil_coal", Vector3(yx1 - 0.4, Y0, z0 + 1.2), 0.0, 0.8)
	_kit(b, "#mil_ingots", Vector3(yx1 - 0.45, Y0, z0 + 1.95), 0.3, 0.75)
	var ax := (yx0 + yx1) * 0.5
	_u(b, "SM_Prop_Anvil_01", Vector3(ax, Y0, z1 - 1.6), 0.3, 0.5)
	_u(b, "SM_Prop_Tool_Hammer_01", Vector3(ax + 0.05, Y0 + 0.43, z1 - 1.6), 1.2, 0.7)
	b.actor(Vector3(ax, Y0, z1 - 1.05), PI, "Interact", "pleb")
	_u(b, "SM_Prop_Jar_01", Vector3(yx0 + 0.3, Y0, z1 - 1.25), 0.0, 0.5)
	_brazier(b, Vector3(yx1 - 0.35, Y0, z1 - 1.4), 0.34, false)
	b.actor(Vector3(yx0 + 0.6, Y0, z0 + 1.55), -0.9, "Fixing_Kneeling", "pleb")
	for k in 2:
		_lean_shield(b, Vector3(dcx + 0.55 + k * 0.28, Y0, hz1 + 0.15), -0.1 * k, "SM_Wep_Shield_0%d" % [4, 1][k], 0.42)
	_standard(b, Vector3(dcx - 0.9, Y0, hz1 + 0.4), 0.58)
	_u(b, "SM_Prop_Sack_Stack_01", Vector3(x0 + 0.6, Y0, hz1 + 0.3), 0.2, 0.36)
	_pot(b, Vector3(float(r[1]) - 0.15, Y0, hz1 + 0.22), 0.22)
	for k in 3:
		_u(b, "SM_Prop_Beam_01", Vector3(x0 + 0.75, Y0 + 0.05 + k * 0.09, z1 - 0.75 - k * 0.03), 0.02 * k, 0.45)
	# места прибавок
	g["gate"] = [xc, 0.72]
	g["stand"] = [Vector3(xc - 1.3, Y0, z1 - 0.6), Vector3(xc + 1.3, Y0, z1 - 0.6)]
	g["banner"] = [[r, 0, 0.3, ytop - 0.12], [r, 1, 0.4, ytop - 0.12]]
	g["walls"] = [[Vector3(x1 - 0.21, Y0, z1 - 0.2), Vector3(0, 0, -1), z1 - z0 - 0.45]]
	g["wing"] = {"kind": "shed", "r": [x0 + 0.3, x0 + 3.7, hz1, hz1 + 0.95], "h": 2.2, "dir": 1,
		"items": [["SM_Prop_Anvil_01", Vector3(x0 + 3.2, Y0, hz1 + 0.55), 0.3, 0.42]]}
	g["eagle"] = Vector3(ax + 0.75, Y0, z1 - 0.75)
	g["statue"] = []
	g["ridge"] = Vector3((float(r[0]) + float(r[1])) * 0.5 + 0.8, float(ridge) + 0.03, (float(r[2]) + hz1) * 0.5)
	g["shields"] = [[r, 3, 1.4, Y0 + 1.7]]
	g["acro"] = []
	g["band"] = [r, ytop - 0.24]
	g["num"] = "III"
	return Vector3(xc, 0, z1 + 0.3)


# =====================================================================
#   лазарет
# =====================================================================

## Лазарет: белёный дом под черепицей (синие ставни, посох Асклепия над дверью) с палатой в тёплом свете — койки,
## подушки, столик с чашами; перед домом справа — черепичная галерея на колоннах с двумя койками (раненый легионер,
## лекарь у койки), слева — грядки с травами, кадки, столик лекаря с кувшинами и чашами, каменный колодец
static func _infirmary(b: Bp, fr: Array, x: Dictionary, g: Dictionary) -> Vector3:
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	var xc := (x0 + x1) * 0.5
	NewCivic._base(b, x0, x1, z0, z1)
	var hd := clampf((z1 - z0) - 2.95, 2.9, 3.2)
	var r := [x0 + 0.1, x1 - 0.1, z0 + 0.12, z0 + 0.12 + hd]
	var hz1: float = r[3]
	x["leaf"] = LEAF_WOOD
	x["shut"] = "#shutters_blue"
	var h := _house(b, r, {0: "SDS", 1: "SN", 2: "NSN", 3: "NS"}, {}, x, {"H1": 2.45, "roof": "x", "stone": false, "tym": TYMPANUM})
	var res: Dictionary = h["res"]
	var ytop: float = h["ytop"]
	var d: Array = res["D"][0]
	var dcx := _mx(r, d)
	_u(b, "SM_Prop_Symbol_0%d" % 2, Vector3(dcx, Y0 + 1.98, hz1 + 0.04), 0.0, 0.55)
	_p(b, "#wall_lamp", Vector3(dcx - 0.62, Y0 + 1.62, hz1 + 0.02), 0.0)
	# палата: койки с подушками, столик с чашами
	var ir: Array = h["ir"]
	var ix0: float = ir[0]
	var ix1: float = ir[1]
	var iz0: float = ir[2]
	var iz1: float = ir[3]
	for k in 3:
		var kx := lerpf(ix0 + 0.7, ix1 - 0.7, k / 2.0)
		_u(b, "SM_Prop_Seat_Kline_02", Vector3(kx, Y0, iz0 + 0.42), 0.0, 0.42, GLOW)
		_u(b, "SM_Prop_Pillow_0%d" % (3 + k), Vector3(kx - 0.35, Y0 + 0.26, iz0 + 0.42), 0.2, 0.36, GLOW)
	_u(b, "SM_Prop_Table_05", Vector3(dcx + 0.6, Y0, (iz0 + iz1) * 0.5 + 0.2), PI / 2, 0.5, GLOW)
	_u(b, "SM_Prop_Bowl_0%d" % 2, Vector3(dcx + 0.6, Y0 + 0.4, (iz0 + iz1) * 0.5 + 0.2), 0.0, 0.3, GLOW)
	_u(b, "SM_Prop_Pots_Hanging_01", Vector3(ix1 - 0.4, Y0 + 1.6, iz1 - 0.1), 0.0, 0.5, GLOW)
	# галерея справа: черепица на колоннах, две койки, раненый и лекарь
	var gx0 := dcx + 0.85
	var gx1 := x1 - 0.25
	var gz1 := minf(z1 - 0.6, hz1 + 1.55)
	NewCivic._floor(b, MOSAIC, gx0, hz1, gx1, gz1, Y0 + 0.022, 1.8)
	for xx: float in [gx0 + 0.1, gx1 - 0.1]:
		_p(b, "SM_Prop_Plinth_03", Vector3(xx, Y0, gz1 - 0.1), 0.0, Vector3(0.3, 0.9, 0.3))
		_p(b, "SM_Bld_Pillar_06", Vector3(xx, Y0 + 0.04, gz1 - 0.1), 0.0, Vector3(0.28, 1.85 / 3.0, 0.28))
	var dep := gz1 - hz1 + 0.12
	var kr := dep / 7.5
	_p(b, "SM_Bld_Roof_Straight_Thin_Large_01", Vector3(gx0 - 0.1, Y0 + 1.95, gz1 + 0.1), 0.0, Vector3((gx1 - gx0 + 0.2) / 7.5, kr * 1.3, kr))
	_p(b, "SM_Prop_Beam_01", Vector3(gx0, Y0 + 1.9, gz1 - 0.08), 0.0, Vector3((gx1 - gx0) / 2.5, 1.0, 1.0))
	for k in 2:
		var kx := lerpf(gx0 + 0.55, gx1 - 0.55, float(k))
		_u(b, "SM_Prop_Seat_Kline_02", Vector3(kx, Y0 + 0.02, hz1 + 0.62), PI / 2, 0.4)
		_u(b, "SM_Prop_Pillow_0%d" % (1 + k), Vector3(kx, Y0 + 0.28, hz1 + 0.3), 0.0, 0.34)
	for k in 3:
		_u(b, "SM_Prop_Pots_Hanging_0%d" % (1 + k), Vector3(lerpf(gx0 + 0.3, gx1 - 0.3, k / 2.0), Y0 + 1.86, gz1 - 0.08), 0.0, 0.42)
	b.actor(Vector3(gx0 + 0.55, Y0 + 0.08, hz1 + 0.65), PI / 2, "Sitting_Idle", "soldier")
	b.actor(Vector3(gx1 - 0.15, Y0, hz1 + 1.05), -PI / 2 - 0.3, "Fixing_Kneeling", "female")
	# слева: грядки с травами, кадки, столик лекаря, колодец
	_u(b, "SM_Prop_FlowerBed_01", Vector3(x0 + 0.85, Y0 + 0.07, hz1 + 0.75), 0.0, 0.42)
	_u(b, "SM_Prop_FlowerBed_02", Vector3(x0 + 0.85, Y0 + 0.07, hz1 + 1.55), 0.0, 0.42)
	_u(b, "SM_Prop_Well_01", Vector3(dcx - 1.2, Y0, z1 - 1.25), 0.3, 0.3)
	_u(b, "SM_Prop_Table_04", Vector3(dcx - 0.95, Y0, hz1 + 0.42), 0.0, 0.45)
	_u(b, "SM_Prop_Jug_0%d" % (1 + b.rng.randi() % 6), Vector3(dcx - 1.05, Y0 + 0.42, hz1 + 0.42), 0.0, 0.32)
	_u(b, "SM_Prop_Bowl_0%d" % (1 + b.rng.randi() % 4), Vector3(dcx - 0.8, Y0 + 0.42, hz1 + 0.45), 0.0, 0.25)
	NewCivic._bush(b, Vector3(x0 + 0.55, Y0, z1 - 0.95), 0.22)
	for k in 2:
		_u(b, "SM_Env_Garden_Plants_0%d" % [3, 6][k], Vector3(x0 + 0.85, Y0 + 0.12, hz1 + 0.75 + k * 0.8), b.rng.randf() * TAU, 0.2, {"tint": Color(1, 1, 1)})
	_standard(b, Vector3(dcx + 0.62, Y0, hz1 + 0.3), 0.5)
	# места прибавок
	g["gate"] = [dcx, 0.66]
	g["stand"] = [Vector3(x0 + 0.42, Y0, z1 - 0.6), Vector3(x1 - 0.42, Y0, z1 - 0.6)]
	var wl := float(r[1]) - float(r[0])
	g["banner"] = [[r, 1, 0.4, ytop - 0.12], [r, 3, hd - 0.4, ytop - 0.12]]
	g["walls"] = [[Vector3(x0 + 0.21, Y0, z1 - 0.2), Vector3(0, 0, -1), z1 - 0.2 - hz1 - 0.05], [Vector3(x1 - 0.21, Y0, hz1 + 0.05), Vector3(0, 0, 1), z1 - 0.2 - hz1 - 0.05]]
	g["wing"] = {"kind": "pergola", "r": [x0 + 0.3, x0 + 1.75, hz1 + 0.25, z1 - 0.62], "h": 1.85}
	g["eagle"] = Vector3(dcx + 0.0, Y0 + 2.62, hz1 + 0.12)
	g["statue"] = [[Vector3(xc + 1.6, Y0, z1 - 0.75), PI]]
	g["ridge"] = Vector3(xc, float(h["ridge"]) + 0.03, (float(r[2]) + hz1) * 0.5)
	g["shields"] = [[r, 0, wl * 0.5 - 1.25, Y0 + 2.05], [r, 0, wl * 0.5 + 1.25, Y0 + 2.05]]
	g["acro"] = [Vector3(float(r[0]) - 0.1, ytop + 0.1, (float(r[2]) + hz1) * 0.5), Vector3(float(r[1]) + 0.1, ytop + 0.1, (float(r[2]) + hz1) * 0.5)]
	g["band"] = [r, ytop - 0.24]
	g["num"] = "II"
	return Vector3(dcx, 0, z1 + 0.3)


# =====================================================================
#   склад оружия
# =====================================================================

## Склад оружия: двухэтажный склад — низ из тёсаного камня, широкие ворота в тёплый зал со стойками копий, щитами
## штабелями и полками, верх легионного красного с малыми окнами, большой фронтон к улице (красный тимпан, щит);
## во дворе — стойки копий и мечей, щиты рядами, бочонки, повозка со снаряжением, оружейник и часовой
static func _armory(b: Bp, fr: Array, x: Dictionary, g: Dictionary) -> Vector3:
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	var xc := (x0 + x1) * 0.5
	NewCivic._base(b, x0, x1, z0, z1)
	var hd := clampf((z1 - z0) - 2.7, 3.0, 3.4)
	var r := [x0 + 0.35, x1 - 0.35, z0 + 0.12, z0 + 0.12 + hd]
	var hz1: float = r[3]
	x["leaf"] = LEAF_WOOD
	x["shut"] = "#shutters_brown"
	var h := _house(b, r, {0: "TGT", 1: "TW", 2: "TWT", 3: "WT"}, {0: "MSM", 1: "MW", 2: "SMS", 3: "WM"}, x, {"H1": 2.4, "H2": 1.4, "roof": "z", "tym": TYM_RED})
	var res: Dictionary = h["res"]
	var ytop: float = h["ytop"]
	var y2: float = h["y2"]
	var gate: Array = res["G"][0]
	var gcx := _mx(r, gate)
	# щит в тимпане, фонари у ворот
	_wall_shield(b, [r[0], r[1], r[2], hz1 + 0.12], 0, (float(r[1]) - float(r[0])) * 0.5, ytop + 0.32, 0.36)
	for sd: float in [-1.0, 1.0]:
		_p(b, "#wall_lamp", Vector3(gcx + sd * 0.82, Y0 + 1.7, hz1 + 0.02), 0.0)
	# нутро: стойки, щиты, полки
	var ir: Array = h["ir"]
	var ix0: float = ir[0]
	var ix1: float = ir[1]
	var iz0: float = ir[2]
	var iz1: float = ir[3]
	_rack(b, Vector3(gcx - 0.6, Y0, iz0 + 0.14), 0.0, 1, 0.42, GLOW)
	_rack(b, Vector3(gcx + 0.6, Y0, iz0 + 0.14), 0.0, 2, 0.42, GLOW)
	for k in 4:
		_lean_shield(b, Vector3(ix0 + 0.18, Y0, iz0 + 0.5 + k * 0.32), PI / 2, "SM_Wep_Shield_0%d" % [4, 4, 2, 4][k], 0.42, 0.25, GLOW)
		_lean_shield(b, Vector3(ix1 - 0.18, Y0, iz0 + 0.5 + k * 0.32), -PI / 2, "SM_Wep_Shield_04", 0.42, 0.25, GLOW)
	_u(b, "SM_Prop_Shelf_02", Vector3(gcx, Y0, iz1 - 0.6), PI, 0.45, GLOW)
	# двор
	_sand(b, x0 + 0.35, x1 - 0.35, hz1 + 0.3, z1 - 0.45)
	_rack(b, Vector3(x0 + 0.48, Y0, hz1 + 0.95), PI / 2, 1, 0.42)
	_rack(b, Vector3(x1 - 0.48, Y0, hz1 + 0.95), -PI / 2, 1, 0.42)
	for k in 3:
		_lean_shield(b, Vector3(gcx - 2.1 + k * 0.32, Y0, hz1 + 0.17), 0.08 * k, "SM_Wep_Shield_0%d" % [4, 2, 4][k], 0.42)
		_lean_shield(b, Vector3(gcx + 1.45 + k * 0.32, Y0, hz1 + 0.17), -0.08 * k, "SM_Wep_Shield_04", 0.42)
	_p(b, "SM_Prop_Cart_01", Vector3(xc + 0.95, Y0, z1 - 1.05), PI / 2 + 0.2, Vector3.ONE * 0.42)
	_p(b, "SM_Prop_Cart_01_Insert_01", Vector3(xc + 0.95, Y0, z1 - 1.05), PI / 2 + 0.2, Vector3.ONE * 0.42)
	_u(b, "SM_Prop_Basket_Set_0%d" % (1 + b.rng.randi() % 6), Vector3(xc - 1.15, Y0, z1 - 1.0), 0.3, 0.42)
	_u(b, "SM_Prop_Sack_Stack_0%d" % (1 + b.rng.randi() % 2), Vector3(xc - 1.75, Y0, z1 - 1.45), -0.2, 0.42)
	b.actor(Vector3(gcx + 1.2, Y0, hz1 + 0.5), 0.0, "Sword_Idle", "soldier")
	b.actor(Vector3(xc + 0.2, Y0, z1 - 1.2), 2.2, "Interact", "pleb")
	_standard(b, Vector3(gcx - 1.25, Y0, hz1 + 0.4), 0.6)
	# места прибавок
	g["gate"] = [gcx, 0.72]
	g["stand"] = [Vector3(x0 + 0.42, Y0, z1 - 0.6), Vector3(x1 - 0.42, Y0, z1 - 0.6)]
	var wl := float(r[1]) - float(r[0])
	g["banner"] = [[r, 0, 0.32, ytop - 0.12], [r, 0, wl - 0.32, ytop - 0.12]]
	g["walls"] = [[Vector3(x0 + 0.21, Y0, z1 - 0.2), Vector3(0, 0, -1), z1 - z0 - 0.45], [Vector3(x1 - 0.21, Y0, z0 + 0.25), Vector3(0, 0, 1), z1 - z0 - 0.45]]
	g["wing"] = {"kind": "porch", "cx": gcx, "z": hz1, "hw": 0.95, "dep": 0.62, "h": 2.3}
	g["eagle"] = Vector3(gcx, Y0 + 2.5, hz1 + 0.7)
	g["statue"] = [[Vector3(gcx - 0.89, Y0 + 2.55, z1 - 0.2), 0.0], [Vector3(gcx + 0.89, Y0 + 2.55, z1 - 0.2), 0.0]]
	g["ridge"] = Vector3(xc, float(h["ridge"]) + 0.03, hz1 + 0.05)
	g["shields"] = [[r, 1, hd * 0.5, y2 + 0.72], [r, 3, hd * 0.5, y2 + 0.72]]
	g["acro"] = [Vector3(float(r[0]) + 0.05, ytop + 0.12, hz1 + 0.08), Vector3(float(r[1]) - 0.05, ytop + 0.12, hz1 + 0.08)]
	g["band"] = [r, ytop - 0.24]
	g["num"] = "X"
	return Vector3(gcx, 0, z1 + 0.3)


# =====================================================================
#   плавильня
# =====================================================================

## Плавильня: слева — каменный дом печника (фронтон к улице, широкие ворота в тёплый зал с тиглями и мехами), высокая
## труба с дымом; справа — двор: большая обжиговая печь с огнём в устье (светится), кучи руды и угля, бруски железа,
## наковальня, тачка-повозка. Два места работников: у печи и у наковальни
static func _smelter(b: Bp, fr: Array, x: Dictionary, g: Dictionary) -> Vector3:
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	var xc := (x0 + x1) * 0.5
	NewCivic._base(b, x0, x1, z0, z1)
	var r := [x0 + 0.1, x0 + 3.35, z0 + 0.12, z0 + 3.25]
	var hz1: float = r[3]
	x["leaf"] = LEAF_WOOD
	x["shut"] = "#shutters_brown"
	var h := _house(b, r, {0: "G", 1: "TW", 2: "TT", 3: "WT"}, {}, x, {"H1": 2.55, "roof": "z", "stone": true, "frieze": true, "ivy_k": 3})
	var res: Dictionary = h["res"]
	var ytop: float = h["ytop"]
	var gate: Array = res["G"][0]
	var gcx := _mx(r, gate)
	_chimney(b, Vector3(float(r[1]) - 0.45, 0, float(r[2]) + 0.45), float(h["ridge"]) + 1.0 - Y0, 0.55)
	_p(b, "#wall_lamp", Vector3(gcx - 0.95, Y0 + 1.65, hz1 + 0.02), 0.0)
	var ir: Array = h["ir"]
	var ix0: float = ir[0]
	var ix1: float = ir[1]
	var iz0: float = ir[2]
	var iz1: float = ir[3]
	# зал: тигли у печного жерла (тлеет), мехи, бруски на полке
	_u(b, "SM_Prop_Kiln_01", Vector3(ix1 - 0.6, Y0, iz0 + 0.55), PI, 0.45, GLOW)
	_p(b, "SM_Bld_Wall_01", Vector3(ix1 - 0.9, Y0 + 0.3, iz0 + 0.95), 0.0, Vector3(0.6 / 2.5, 0.14 / 3.01, 0.4), EMBER)
	_u(b, "SM_Prop_Sack_Stack_01", Vector3(ix0 + 0.5, Y0, iz0 + 0.5), 0.3, 0.42, GLOW)
	_kit(b, "#mil_ingots", Vector3(ix0 + 0.5, Y0, iz1 - 0.6), 0.2, 0.7)
	# двор: печь с огнём, руда, уголь, железо, наковальня, повозка
	var yx0 := float(r[1]) + 0.25
	var yx1 := x1 - 0.3
	var ycx := (yx0 + yx1) * 0.5
	_sand(b, yx0, yx1, z0 + 0.3, z1 - 0.45)
	var kp := Vector3(ycx + 0.2, Y0, z0 + 1.0)
	_u(b, "SM_Prop_Kiln_01", kp, 0.0, 0.62)
	NewCivic._fire(b, kp + Vector3(0, 0.3, 0.42), 2.6)
	b.light(kp + Vector3(0, 0.7, 0.9))
	b.smoke.insert(0, b.base * (kp + Vector3(0, 1.8, 0)))
	_kit(b, "#mil_ore", Vector3(yx1 - 0.35, Y0, z0 + 2.15), 0.4, 0.62)
	_kit(b, "#mil_coal", Vector3(yx0 + 0.35, Y0, z0 + 2.2), 0.0, 0.7)
	_kit(b, "#mil_ingots", Vector3(ycx - 0.45, Y0, z1 - 1.3), 0.2, 0.7)
	_u(b, "SM_Prop_Anvil_01", Vector3(ycx + 0.55, Y0, z1 - 1.5), 0.5, 0.48)
	_p(b, "SM_Prop_Cart_01", Vector3(gcx - 0.3, Y0, z1 - 1.0), PI / 2 - 0.15, Vector3.ONE * 0.42)
	_p(b, "SM_Prop_Cart_01_Insert_03", Vector3(gcx - 0.3, Y0, z1 - 1.0), PI / 2 - 0.15, Vector3.ONE * 0.42)
	b.actor(Vector3(kp.x, Y0, kp.z + 1.05), PI, "Interact", "pleb")
	b.actor(Vector3(ycx + 0.55, Y0, z1 - 0.95), PI + 0.3, "Fixing_Kneeling", "pleb")
	_standard(b, Vector3(gcx + 1.05, Y0, hz1 + 0.35), 0.55)
	_kit(b, "#mil_ore", Vector3(yx1 - 0.4, Y0, z1 - 1.25), 2.1, 0.5)
	_kit(b, "#mil_logs", Vector3(yx0 + 0.45, Y0, z0 + 0.55), 0.0, 0.42)
	_u(b, "SM_Prop_Jar_01", Vector3(ycx + 1.0, Y0, z1 - 1.75), 0.0, 0.45)
	_u(b, "SM_Prop_Sack_Stack_02", Vector3(yx1 - 0.35, Y0, z0 + 0.45), 0.3, 0.38)
	_rack(b, Vector3(x0 + 0.62, Y0, hz1 + 0.75), PI / 2, 2, 0.36)
	_pot(b, Vector3(float(r[1]) - 0.2, Y0, hz1 + 0.22), 0.22)
	_u(b, "SM_Prop_Table_04", Vector3(x0 + 2.75, Y0, z1 - 1.35), 0.2, 0.42)
	_kit(b, "#mil_ingots", Vector3(x0 + 2.72, Y0 + 0.33, z1 - 1.38), 0.5, 0.42)
	_u(b, "SM_Prop_Tool_Hammer_01", Vector3(x0 + 2.9, Y0 + 0.33, z1 - 1.25), 1.2, 0.6)
	# места прибавок
	g["gate"] = [xc, 0.72]
	g["stand"] = [Vector3(x0 + 0.42, Y0, z1 - 0.6), Vector3(x1 - 0.42, Y0, z1 - 0.6)]
	g["banner"] = [[r, 1, 0.4, ytop - 0.12], [r, 0, 0.3, ytop - 0.12]]
	g["walls"] = [[Vector3(x1 - 0.21, Y0, z1 - 0.2), Vector3(0, 0, -1), z1 - z0 - 0.45], [Vector3(x0 + 0.21, Y0, z1 - 0.2), Vector3(0, 0, -1), z1 - 0.2 - hz1 - 0.05]]
	g["wing"] = {"kind": "shed", "r": [yx0, yx1, z0 + 1.9, z0 + 2.95], "h": 1.95, "dir": 1}
	g["eagle"] = Vector3(yx1 - 0.3, Y0, z1 - 0.75)
	g["statue"] = []
	g["ridge"] = Vector3((float(r[0]) + float(r[1])) * 0.5, float(h["ridge"]) + 0.03, hz1 + 0.05)
	g["shields"] = [[r, 3, 1.6, Y0 + 1.7]]
	g["acro"] = [Vector3(float(r[0]) + 0.05, ytop + 0.12, hz1 + 0.08), Vector3(float(r[1]) - 0.05, ytop + 0.12, hz1 + 0.08)]
	g["band"] = [r, ytop - 0.24]
	g["num"] = "VI"
	return Vector3(xc, 0, z1 + 0.3)


# =====================================================================
#   лесопилка
# =====================================================================

## Лесопилка: слева — домик пильщиков (охра, фронтон к улице, дверь в тёплую комнату с инструментом); справа сзади —
## большой навес на столбах под черепицей: козлы с бревном и двуручной пилой (два места работников — пильщики
## по сторонам бревна), под навесом — доски; во дворе — штабеля брёвен и досок, повозка с брёвнами, корзина
static func _sawmill(b: Bp, fr: Array, x: Dictionary, g: Dictionary) -> Vector3:
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	var xc := (x0 + x1) * 0.5
	NewCivic._base(b, x0, x1, z0, z1)
	var r := [x0 + 0.1, x0 + 2.45, z0 + 0.12, z0 + 3.0]
	var hz1: float = r[3]
	x["leaf"] = LEAF_WOOD
	x["shut"] = "#shutters_green"
	var h := _house(b, r, {0: "D", 1: "SW", 2: "N", 3: "WS"}, {}, x, {"H1": 2.3, "roof": "z", "stone": false})
	var res: Dictionary = h["res"]
	var ytop: float = h["ytop"]
	var d: Array = res["D"][0]
	var dcx := _mx(r, d)
	_p(b, "SM_Prop_Overhang_01", Vector3(dcx, Y0 + 2.1, hz1 + 0.02), 0.0, Vector3(0.62, 0.85, 0.8))
	_p(b, "#wall_lamp", Vector3(dcx + 0.62, Y0 + 1.6, hz1 + 0.02), 0.0)
	var ir: Array = h["ir"]
	_u(b, "SM_Prop_Shelf_01", Vector3((float(ir[0]) + float(ir[1])) * 0.5, Y0, float(ir[2]) + 0.18), 0.0, 0.45, GLOW)
	_u(b, "SM_Wep_Axe_01", Vector3(float(ir[0]) + 0.3, Y0 + 1.1, float(ir[2]) + 0.05), 0.0, 0.7, GLOW)
	_kit(b, "#mil_planks", Vector3((float(ir[0]) + float(ir[1])) * 0.5, Y0, float(ir[3]) - 0.5), 0.0, 0.55)
	# навес с пилой
	var sx0 := float(r[1]) + 0.3
	var sx1 := x1 - 0.25
	_sand(b, sx0 - 0.05, sx1, z0 + 0.3, z1 - 0.45)
	_shed(b, [sx0, sx1, z0 + 0.25, z0 + 2.75], 2.3, 1)
	NewCivic._run(b, "SM_Bld_Wall_01", Vector3(sx1, Y0, z0 + 0.22), Vector3(-1, 0, 0), sx1 - sx0, 2.5, 0.75 / 3.01, 0.6, STONE, 1.8)
	var cx := (sx0 + sx1) * 0.5
	_kit(b, "#mil_saw", Vector3(cx, Y0, z0 + 1.45), PI / 2, 0.68)
	b.actor(Vector3(cx, Y0, z0 + 0.85), 0.0, "Interact", "pleb")
	b.actor(Vector3(cx, Y0, z0 + 2.05), PI, "Interact", "pleb")
	_kit(b, "#mil_planks", Vector3(sx1 - 0.55, Y0, z0 + 1.45), PI / 2, 0.55)
	_kit(b, "#mil_logs", Vector3(sx0 + 0.6, Y0, z0 + 1.45), PI / 2, 0.55)
	# двор: брёвна, доски, повозка
	_kit(b, "#mil_logs", Vector3(cx + 0.4, Y0, z1 - 1.1), 0.08, 0.62)
	_kit(b, "#mil_planks", Vector3(x0 + 1.25, Y0, z1 - 1.05), 0.0, 0.55)
	_p(b, "SM_Prop_Cart_01", Vector3(cx - 1.2, Y0, z0 + 3.35), 0.15, Vector3.ONE * 0.42)
	_u(b, "SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 5), Vector3(dcx + 0.75, Y0, hz1 + 0.3), 0.0, 0.4)
	NewCivic._cypress(b, Vector3(x0 + 0.38, Y0, hz1 + 0.4), 0.28)
	_standard(b, Vector3(dcx - 0.7, Y0, hz1 + 0.35), 0.55)
	_kit(b, "#mil_logs", Vector3(cx + 1.15, Y0, z1 - 1.75), 1.45, 0.5)
	_kit(b, "#mil_planks", Vector3(x0 + 1.25, Y0 + 0.18, z1 - 1.05), 0.12, 0.5)
	_u(b, "SM_Wep_Axe_02", Vector3(cx - 0.35, Y0 + 0.35, z1 - 1.1), 0.4, 0.6)
	_u(b, "SM_Prop_Sack_Stack_01", Vector3(sx1 - 0.4, Y0, z0 + 2.45), 0.2, 0.36)
	_pot(b, Vector3(float(r[1]) + 0.1, Y0, hz1 + 0.25), 0.22)
	_u(b, "SM_Prop_Table_04", Vector3(float(r[1]) + 0.55, Y0, z1 - 1.25), 0.3, 0.42)
	_u(b, "SM_Prop_Tool_Hammer_01", Vector3(float(r[1]) + 0.5, Y0 + 0.33, z1 - 1.25), 0.4, 0.6)
	_u(b, "SM_Prop_Tool_Chisel_01", Vector3(float(r[1]) + 0.65, Y0 + 0.33, z1 - 1.2), 2.0, 0.6)
	# места прибавок
	g["gate"] = [xc, 0.72]
	g["stand"] = [Vector3(x0 + 0.42, Y0, z1 - 0.6), Vector3(x1 - 0.42, Y0, z1 - 0.6)]
	g["banner"] = [[r, 1, 0.4, ytop - 0.12], [r, 3, 2.4, ytop - 0.12]]
	g["walls"] = [[Vector3(x1 - 0.21, Y0, z1 - 0.2), Vector3(0, 0, -1), z1 - z0 - 0.45], [Vector3(x0 + 0.21, Y0, z1 - 0.2), Vector3(0, 0, -1), z1 - 0.2 - hz1 - 0.05]]
	g["wing"] = {"kind": "crane", "p": Vector3(cx + 0.55, Y0, z0 + 3.6), "yaw": 0.0}
	g["eagle"] = Vector3(x1 - 0.75, Y0, z1 - 0.75)
	g["statue"] = []
	g["ridge"] = Vector3(dcx, float(h["ridge"]) + 0.03, hz1 + 0.05)
	g["shields"] = [[r, 3, 1.0, Y0 + 1.6]]
	g["acro"] = [Vector3(float(r[0]) + 0.05, ytop + 0.12, hz1 + 0.08), Vector3(float(r[1]) - 0.05, ytop + 0.12, hz1 + 0.08)]
	g["band"] = [r, ytop - 0.24]
	g["num"] = "VIII"
	return Vector3(xc, 0, z1 + 0.3)


# =====================================================================
#   дубильня
# =====================================================================

## Дубильня: справа — белёный дом с персиковым верхом (ставни, чердачная дверь со шкурами на просушке, тёплая
## комната с рулонами кожи); слева — двор: рамы с растянутыми шкурами, чаны с отваром, кувшины, верёвка с кожами
## между столбами, сложенные кожи. Два места работников: у чана и у рамы
static func _tannery(b: Bp, fr: Array, x: Dictionary, g: Dictionary) -> Vector3:
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	var xc := (x0 + x1) * 0.5
	NewCivic._base(b, x0, x1, z0, z1)
	var r := [x1 - 3.5, x1 - 0.1, z0 + 0.12, z0 + 3.0]
	var hz1: float = r[3]
	x["leaf"] = LEAF_WOOD
	x["shut"] = "#shutters_green"
	var h := _house(b, r, {0: "DS", 1: "WN", 2: "NN", 3: "SW"}, {0: "LB", 1: "SW", 2: "SS", 3: "WS"}, x, {"H1": 2.2, "H2": 1.35, "roof": "x", "stone": false})
	var res: Dictionary = h["res"]
	var ytop: float = h["ytop"]
	var y2: float = h["y2"]
	var d: Array = res["D"][0]
	var dcx := _mx(r, d)
	var up: Dictionary = h["up"]
	for e: Array in up["L"]:
		var lcx := _mx(r, e)
		_p(b, "SM_Prop_Beam_01", Vector3(lcx, y2 + 1.15, hz1 - 0.25), -PI / 2, Vector3(0.4, 1.1, 1.1))
		_u(b, "SM_Prop_Rug_Drape_01", Vector3(lcx, y2 + 0.05, hz1 + 0.06), 0.0, 0.4)
	_p(b, "#wall_lamp", Vector3(dcx - 0.62, Y0 + 1.6, hz1 + 0.02), 0.0)
	var ir: Array = h["ir"]
	_u(b, "SM_Prop_Rug_Stack_01", Vector3(float(ir[0]) + 0.6, Y0, float(ir[2]) + 0.5), 0.3, 0.42, GLOW)
	_u(b, "SM_Prop_Rug_Stack_02", Vector3(float(ir[1]) - 0.6, Y0, float(ir[2]) + 0.5), -0.2, 0.42, GLOW)
	_u(b, "SM_Prop_Table_04", Vector3((float(ir[0]) + float(ir[1])) * 0.5, Y0, float(ir[3]) - 0.6), 0.0, 0.45, GLOW)
	# двор
	var yx0 := x0 + 0.3
	var yx1 := float(r[0]) - 0.25
	var ycx := (yx0 + yx1) * 0.5
	_sand(b, yx0, yx1, z0 + 0.3, z1 - 0.45)
	_kit(b, "#mil_hides", Vector3(yx0 + 0.75, Y0, z0 + 0.65), 0.15, 0.62)
	_kit(b, "#mil_hides", Vector3(yx1 - 0.7, Y0, z0 + 0.6), -0.1, 0.6)
	for k in 3:
		_kit(b, "#mil_vat", Vector3(ycx - 0.7 + k * 0.72, Y0, z0 + 2.0 + (0.2 if k == 1 else 0.0)), k * 0.7, 0.55)
	NewSmall._pot(b, Vector3(yx0 + 0.25, Y0, z0 + 2.75), 0.22)
	_u(b, "SM_Prop_Jar_01", Vector3(yx1 - 0.2, Y0, z0 + 2.7), 0.0, 0.45)
	# верёвка с кожами между столбами
	var lz := z1 - 1.25
	for xx: float in [yx0 + 0.1, yx1 - 0.1]:
		_p(b, "SM_Prop_Pole_01", Vector3(xx, Y0, lz), 0.0, Vector3(0.4, 0.5, 0.4))
	_kit(b, "#mil_rope", Vector3(yx0 + 0.1, Y0 + 1.42, lz), 0.0, (yx1 - yx0 - 0.2) / 2.25)
	for k in 3:
		_u(b, "SM_Prop_Rug_Drape_01", Vector3(lerpf(yx0 + 0.6, yx1 - 0.6, k / 2.0), Y0 + 1.3, lz), 0.0, 0.32)
	_u(b, "SM_Prop_Rug_Folded_0%d" % (1 + b.rng.randi() % 3), Vector3(dcx + 0.7, Y0, hz1 + 0.35), 0.2, 0.42)
	_p(b, "SM_Prop_Seat_Bench_01", Vector3(ycx, Y0, z1 - 0.85), 0.0, Vector3.ONE * 0.45)
	_u(b, "SM_Prop_Rug_Folded_0%d" % (1 + b.rng.randi() % 3), Vector3(ycx - 0.15, Y0 + 0.22, z1 - 0.85), 0.1, 0.36)
	_pot(b, Vector3(yx1 + 0.05, Y0, hz1 + 0.25), 0.22)
	b.actor(Vector3(ycx, Y0, z0 + 2.75), PI, "Interact", "pleb")
	b.actor(Vector3(yx0 + 0.75, Y0, z0 + 1.25), PI, "Fixing_Kneeling", "pleb")
	_standard(b, Vector3(dcx + 0.62, Y0, hz1 + 0.75), 0.52)
	# места прибавок
	g["gate"] = [dcx, 0.72]
	g["stand"] = [Vector3(x0 + 0.42, Y0, z1 - 0.6), Vector3(x1 - 0.42, Y0, z1 - 0.6)]
	g["banner"] = [[r, 1, 0.4, ytop - 0.12], [r, 0, 3.1, ytop - 0.12]]
	g["walls"] = [[Vector3(x0 + 0.21, Y0, z1 - 0.2), Vector3(0, 0, -1), z1 - z0 - 0.45], [Vector3(x1 - 0.21, Y0, hz1 + 0.05), Vector3(0, 0, 1), z1 - 0.2 - hz1 - 0.05]]
	g["wing"] = {"kind": "shed", "r": [yx0, yx1, z0 + 1.6, z0 + 2.6], "h": 1.9, "dir": -1}
	g["eagle"] = Vector3(x1 - 0.75, Y0, z1 - 0.75)
	g["statue"] = []
	g["ridge"] = Vector3((float(r[0]) + float(r[1])) * 0.5, float(h["ridge"]) + 0.03, (float(r[2]) + hz1) * 0.5)
	g["shields"] = [[r, 1, 1.4, Y0 + 1.6]]
	g["acro"] = [Vector3(float(r[0]) - 0.1, ytop + 0.1, (float(r[2]) + hz1) * 0.5), Vector3(float(r[1]) + 0.1, ytop + 0.1, (float(r[2]) + hz1) * 0.5)]
	g["band"] = [r, ytop - 0.24]
	g["num"] = "XI"
	return Vector3(dcx, 0, z1 + 0.3)


# =====================================================================
#   принципия
# =====================================================================

## Принципия — штаб Легиона: двухэтажный дом под плоской кровлей с зубчатым парапетом (низ из тёсаного камня, верх
## сливочный с красным фризом), перед ним — портик на четырёх мраморных колоннах с красным фронтоном и орлом;
## бронзовые двери в тёплый зал со столом карт и знамёнами. Перед штабом — мощёный двор с мозаикой: золотой орёл
## легиона на мраморном постаменте, два значка, часовые у портика, стол полководца под красным навесом
static func _principia(b: Bp, fr: Array, x: Dictionary, g: Dictionary) -> Vector3:
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	var xc := (x0 + x1) * 0.5
	NewCivic._base(b, x0, x1, z0, z1)
	var hd := clampf((z1 - z0) - 3.5, 3.0, 3.4)
	var r := [x0 + 0.1, x1 - 0.1, z0 + 0.12, z0 + 0.12 + hd]
	var hz1: float = r[3]
	x["leaf"] = LEAF_BRONZE
	x["shut"] = "#shutters_green"
	var h := _house(b, r, {0: "NDN", 1: "NW", 2: "NAN", 3: "WN"}, {0: "BSB", 1: "SW", 2: "SNS", 3: "WS"}, x, {"H1": 2.35, "H2": 1.5, "roof": "x"})
	# зубчатый парапет по краю кровли — штаб-крепость (черепица за зубцами)
	_parapet(b, [float(r[0]) - 0.06, float(r[1]) + 0.06, float(r[2]) - 0.06, float(r[3]) + 0.06], float(h["ytop"]) + 0.02, [0, 1, 2, 3], 0.24, 0.2)
	var res: Dictionary = h["res"]
	var ytop: float = h["ytop"]
	var y2: float = h["y2"]
	var d: Array = res["D"][0]
	var dcx := _mx(r, d)
	# портик: четыре колонны, красный фронтон с орлом
	var pr := _porch(b, dcx, hz1, 1.45, 0.9, 2.35, TYM_RED, 4)
	_kit(b, "#mil_eagle", Vector3(dcx, Y0 + 2.32, hz1 + 1.06), 0.0, 0.3)
	# нутро: стол карт со свитками, знамёна у стен
	var ir: Array = h["ir"]
	var ix0: float = ir[0]
	var ix1: float = ir[1]
	var iz0: float = ir[2]
	var iz1: float = ir[3]
	_u(b, "SM_Prop_Table_01", Vector3(dcx, Y0, (iz0 + iz1) * 0.5), 0.0, 0.55, GLOW)
	_u(b, "SM_Prop_Scroll_Pile_03", Vector3(dcx - 0.15, Y0 + 0.43, (iz0 + iz1) * 0.5), 0.4, 0.38, GLOW)
	_u(b, "SM_Prop_Scroll_01", Vector3(dcx + 0.2, Y0 + 0.43, (iz0 + iz1) * 0.5 + 0.05), 1.2, 0.5, GLOW)
	for sd: float in [-1.0, 1.0]:
		_wall_banner(b, [ix0, ix1, iz0 - 0.05, iz1], 2, (ix1 - ix0) * 0.5 + sd * 0.9, Y0 + 2.0, 0.45)
	_u(b, "SM_Prop_Shelf_Scroll_01", Vector3(ix0 + 0.9, Y0, iz0 + 0.04), 0.0, 0.45, GLOW)
	# двор: мозаика, орёл на постаменте, значки, часовые, стол полководца под навесом
	NewCivic._floor(b, MOSAIC, dcx - 1.0, hz1 + 1.2, dcx + 1.0, z1 - 0.55, Y0 + 0.012, 2.0)
	_p(b, "SM_Prop_Plinth_02", Vector3(dcx, Y0, hz1 + 1.95), 0.0, Vector3(1.05, 0.85, 1.05))
	_kit(b, "#mil_eagle", Vector3(dcx, Y0 + 0.86, hz1 + 1.95), 0.0, 0.5)
	for sd: float in [-1.0, 1.0]:
		_standard(b, Vector3(dcx + sd * 1.25, Y0, hz1 + 1.4), 0.7)
		b.actor(Vector3(dcx + sd * 1.05, Y0, hz1 + 1.02), 0.0, "Sword_Idle", "soldier")
	var tx := x1 - 1.05
	var tz := hz1 + 1.55
	for c: Vector3 in [Vector3(tx - 0.65, 0, tz - 0.55), Vector3(tx + 0.65, 0, tz - 0.55), Vector3(tx - 0.65, 0, tz + 0.55), Vector3(tx + 0.65, 0, tz + 0.55)]:
		_p(b, "SM_Prop_Pole_01", Vector3(c.x, Y0, c.z), 0.0, Vector3(0.45, 1.75 / 3.0, 0.45))
	_p(b, "SM_Prop_Banner_Roof_01", Vector3(tx - 0.7, Y0 + 1.75, tz + 0.62), 0.0, Vector3(1.4 / 2.6, 0.9, 1.24 / 2.6), Catalog.canopy_remap(4))
	_u(b, "SM_Prop_Table_04", Vector3(tx, Y0, tz), 0.0, 0.45)
	_u(b, "SM_Prop_Scroll_Pile_0%d" % 2, Vector3(tx - 0.1, Y0 + 0.42, tz), 0.6, 0.4)
	_u(b, "SM_Prop_Seat_Chair_03", Vector3(tx, Y0, tz - 0.45), 0.0, 0.45)
	b.actor(Vector3(tx + 0.1, Y0, tz + 0.45), PI, "Idle", "rich")
	_pot(b, Vector3(x0 + 0.35, Y0, hz1 + 0.25), 0.26)
	NewCivic._cypress(b, Vector3(x0 + 0.42, Y0, hz1 + 1.3), 0.3)
	_brazier(b, Vector3(x0 + 0.95, Y0, hz1 + 0.3), 0.32, false)
	# места прибавок
	g["gate"] = [dcx, 0.8]
	g["stand"] = [Vector3(x0 + 0.42, Y0, z1 - 0.6), Vector3(x1 - 0.42, Y0, z1 - 0.6)]
	var wl := float(r[1]) - float(r[0])
	g["banner"] = [[r, 0, 0.32, ytop - 0.12], [r, 0, wl - 0.32, ytop - 0.12]]
	g["walls"] = [[Vector3(x0 + 0.21, Y0, z1 - 0.2), Vector3(0, 0, -1), z1 - 0.2 - hz1 - 0.05], [Vector3(x1 - 0.21, Y0, hz1 + 0.05), Vector3(0, 0, 1), z1 - 0.2 - hz1 - 0.05]]
	g["wing"] = {"kind": "turrets", "y": ytop + 0.06, "r": [[float(r[0]) + 0.1, float(r[0]) + 1.15, float(r[2]) + 0.1, float(r[2]) + 1.15], [float(r[1]) - 1.15, float(r[1]) - 0.1, float(r[2]) + 0.1, float(r[2]) + 1.15]]}
	g["eagle"] = Vector3(x0 + 0.95, Y0, z1 - 1.05)
	g["statue"] = [[Vector3(dcx - 0.97, Y0 + 2.55, z1 - 0.2), 0.0], [Vector3(dcx + 0.97, Y0 + 2.55, z1 - 0.2), 0.0]]
	g["ridge"] = Vector3(dcx, float(pr) + 0.02, hz1 + 0.98)
	g["shields"] = [[r, 0, wl * 0.5 - 1.2, y2 + 0.75], [r, 0, wl * 0.5 + 1.2, y2 + 0.75], [r, 1, hd * 0.5, y2 + 0.75], [r, 3, hd * 0.5, y2 + 0.75]]
	g["acro"] = [Vector3(dcx - 1.5, Y0 + 2.36, hz1 + 1.0), Vector3(dcx + 1.5, Y0 + 2.36, hz1 + 1.0)]
	g["band"] = [r, ytop - 0.24]
	g["num"] = "I"
	return Vector3(dcx, 0, z1 + 0.3)


# =====================================================================
#   храм Марса
# =====================================================================

## Храм Марса: небольшой храм бога войны на каменном подиуме со ступенями к улице; целла — красная штукатурка
## с мраморными пилястрами и нишами, портик на четырёх мраморных колоннах, фронтон с красным тимпаном и золотым
## медальоном, черепица (конёк ~4,4 м — ниже храма Юпитера); бронзовые двери (Life) в целлу в тёплом свете — статуя
## Марса с копьём и щитом на постаменте, жаровни, трофеи. Перед ступенями — алтарь с огнём, две жаровни, трофеи
## (тропеи) по сторонам, значок легиона, жрец
static func _mars(b: Bp, fr: Array, x: Dictionary, g: Dictionary) -> Vector3:
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	var xc := (x0 + x1) * 0.5
	NewCivic._base(b, x0, x1, z0, z1)
	# подиум
	var PH := 0.5
	var CH := 2.6                      # высота целлы: конёк ~3,9 м — ниже храма Юпитера (6,8 м)
	var pd := [xc - 2.15, xc + 2.15, z0 + 0.2, z0 + 4.55]
	var pz1: float = pd[3]
	for side in 4:
		NewSmall._run(b, "SM_Bld_Wall_01", pd, side, Y0, -0.11 * 1.2, 2.5, PH / 3.01, 1.2, STONE, 1.8)
	NewSmall._cornice(b, pd, Y0 + PH - 0.04, 0.12, 0.06)
	NewCivic._floor(b, PAVING, float(pd[0]), float(pd[2]), float(pd[1]), pz1, Y0 + PH, 2.2)
	# ступени к улице (три плиты по всей ширине портика)
	for k in 3:
		var sz0 := pz1 + (2 - k) * 0.22
		_p(b, "SM_Bld_Wall_01", Vector3(xc - 1.55, Y0, sz0 + 0.11), 0.0, Vector3(3.1 / 2.5, (PH * (k + 1) / 3.0) / 3.01, 1.0), STONE)
		NewCivic._floor(b, PAVING, xc - 1.55, sz0, xc + 1.55, sz0 + 0.24, Y0 + PH * (k + 1) / 3.0, 3.2)
	# целла
	var yb := Y0 + PH
	var cr := [xc - 1.75, xc + 1.75, z0 + 0.35, z0 + 3.25]
	var cz1: float = cr[3]
	x["leaf"] = LEAF_BRONZE
	var res := NewSmall._storey(b, cr, {0: "WDW", 1: "AW", 2: "WAW", 3: "WA"}, yb, CH, x)
	NewSmall._pilasters(b, cr, {0: 3, 1: 2, 2: 3, 3: 2}, yb, CH, 0.2)
	NewSmall._frieze(b, cr, yb + CH - 0.2)
	var ytop := yb + CH
	NewSmall._cornice(b, cr, ytop - 0.03, 0.18, 0.1)
	for e: Array in res["W"]:
		var side: int = e[0]
		if side == 0:
			_wall_shield(b, cr, 0, float(e[1]) + float(e[2]) * 0.5, yb + 1.35, 0.42)
			for sd: float in [-1.0, 1.0]:
				_p(b, "SM_Wep_Spear_03", NewSmall._at(cr, 0, float(e[1]) + float(e[2]) * 0.5 + sd * 0.1, 0.04, yb + 0.5), 0.0, Vector3.ONE * 0.55)
				b.parts[-1][1] = b.parts[-1][1] * Transform3D(Basis(Vector3.BACK, sd * 0.4), Vector3.ZERO)
		elif side == 2:
			NewSmall._ivy(b, cr, e, yb, CH, 2)
	# кровля: фронтон к улице над целлой и портиком
	var rr := [cr[0], cr[1], cr[2], pz1 - 0.15]
	var ridge := NewSmall._roof(b, rr, ytop + 0.08, true, TYM_RED, 0.16)
	_u(b, "SM_Bld_Ornament_02", Vector3(xc, ytop + 0.08 + (ridge - ytop - 0.08) * 0.32, float(rr[3]) + 0.18), 0.0, 0.32)
	# портик: четыре колонны на подиуме
	for i in 4:
		var px := lerpf(xc - 1.55, xc + 1.55, i / 3.0)
		_p(b, "SM_Bld_Pillar_02", Vector3(px, yb, pz1 - 0.35), 0.0, Vector3(0.62, CH / 3.0, 0.62))
	NewCivic._ledge(b, xc - 1.8, xc + 1.8, cz1, pz1 - 0.12, ytop - 0.27, 0.24)
	NewCivic._floor(b, MOSAIC, xc - 1.6, cz1, xc + 1.6, pz1 - 0.1, yb + 0.006, 1.8)
	# целла внутри: тёплый свет, статуя Марса, жаровни, трофеи
	var ir := NewSmall._inner(cr, 0.33)
	NewSmall._hall(b, ir, yb, CH - 0.1, NewSmall._gaps(cr, res))
	var ix0: float = ir[0]
	var ix1: float = ir[1]
	var iz0: float = ir[2]
	var iz1: float = ir[3]
	_p(b, "SM_Prop_Plinth_04", Vector3(xc, yb, iz0 + 0.45), 0.0, Vector3(0.5, 0.45, 0.5), {"glow": WARM * 0.5})
	_u(b, "SM_Prop_Statue_01", Vector3(xc, yb + 0.3, iz0 + 0.45), 0.0, 0.42, {"glow": WARM * 0.6})
	for sd: float in [-1.0, 1.0]:
		_u(b, "SM_Prop_Senser_01", Vector3(xc + sd * 0.8, yb, iz0 + 0.5), 0.0, 0.42, {"glow": WARM * 0.6})
		_lean_shield(b, Vector3(xc + sd * (ix1 - ix0) * 0.42, yb, (iz0 + iz1) * 0.5), -sd * PI / 2, "SM_Wep_Shield_04", 0.42, 0.25, GLOW)
	b.light(Vector3(xc, yb + 1.4, (iz0 + iz1) * 0.5))
	# перед ступенями: алтарь с огнём, жаровни, трофеи, значок, жрец
	var az := minf(z1 - 0.9, pz1 + 0.95)
	_p(b, "SM_Prop_Plinth_04", Vector3(xc, Y0, az), 0.0, Vector3(0.62, 0.6, 0.62))
	NewCivic._bowl(b, Vector3(xc, Y0 + 0.41, az), 0.34)
	b.light(Vector3(xc, Y0 + 1.1, az))
	for sd: float in [-1.0, 1.0]:
		_brazier(b, Vector3(xc + sd * 1.0, Y0, az + 0.1), 0.34, false)
		_kit(b, "#mil_trophy", Vector3(xc + sd * 2.35, Y0, pz1 - 1.6), -sd * 0.4, 0.75)
	_standard(b, Vector3(x0 + 0.42, Y0, pz1 - 0.35), 0.62)
	b.actor(Vector3(xc + 0.55, Y0, az + 0.15), -PI * 0.7, "Spell_Simple_Idle", "rich")
	_pot(b, Vector3(x1 - 0.3, Y0, z0 + 0.3), 0.24)
	NewCivic._cypress(b, Vector3(x1 - 0.42, Y0, pz1 - 0.3), 0.3)
	# места прибавок
	g["gate"] = [xc, 0.8]
	g["stand"] = [Vector3(xc - 1.45, Y0, z1 - 0.55), Vector3(xc + 1.45, Y0, z1 - 0.55)]
	g["banner"] = [[cr, 1, 0.5, ytop - 0.12], [cr, 3, 2.4, ytop - 0.12]]
	g["walls"] = [[Vector3(x0 + 0.21, Y0, z1 - 0.2), Vector3(0, 0, -1), z1 - z0 - 0.45], [Vector3(x1 - 0.21, Y0, z0 + 0.25), Vector3(0, 0, 1), z1 - z0 - 0.45]]
	g["wing"] = {"kind": "trophies", "p": [Vector3(xc - 2.35, Y0, z0 + 1.2), Vector3(xc + 2.35, Y0, z0 + 1.2)]}
	g["eagle"] = Vector3(xc, ridge + 0.02, float(rr[3]) + 0.05)
	g["statue"] = [[Vector3(x1 - 0.55, Y0, z1 - 0.85), -PI * 0.85]]
	g["ridge"] = Vector3(xc, ridge + 0.02, float(rr[2]) + 0.2)
	g["shields"] = [[pd, 1, 1.5, Y0 + 0.28], [pd, 3, 2.8, Y0 + 0.28]]
	g["acro"] = [Vector3(float(rr[0]) + 0.02, ytop + 0.12, float(rr[3]) + 0.12), Vector3(float(rr[1]) - 0.02, ytop + 0.12, float(rr[3]) + 0.12)]
	g["band"] = [cr, ytop - 0.24]
	g["num"] = "XIII"
	return Vector3(xc, 0, z1 + 0.3)
