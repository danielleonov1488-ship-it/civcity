class_name Showcase
extends Node
## Витрина CivCity (режим --promo): большой подробный римский город для промо-ролика, снимков сайта и фона меню.
## Город раскладывается кодом через функции самой игры: дома и лавки ставит Game.placement (фасадом к дороге,
## рядами вплотную), украшения на стены вешает Game._wall_place, монументы — City.check_place/place.
## План (север — вверх, x — на восток): с севера через арку въезд по аллее кипарисов между виноградниками и полями
## к почтовой станции; от неё на юг — главная улица (кардо) к храму Юпитера; поперёк — декуманус. На их перекрёстке
## рынок с фонтаном и прилавками; на западе — форум с пантеоном, за ним озеро, триумфальная арка, театр и одеон;
## на востоке — парк у пруда (утки, лебеди, беседки, скамьи) и термы; на юге — виллы патрициев с садами и
## амфитеатр; вокруг — ряды узких цветных домов всех классов и этажей, фонари вдоль улиц, сады во дворах, поля.
## Здесь же «геройские» виды камеры (VIEWS) и кошки, которые с первой минуты гуляют по улицам.
## Запуск: Godot --path godot -- --promo [--hero=имя] [--noui] [--orbit=0.03] [--hour=17.5] [--shot=путь.png --frames=N]
##         облёт для ролика: Godot --path godot --write-movie D:/out/frames.png --fixed-fps 30 -- --promo --noui
##                           --fly=entrance,cardo_north,market,park,overview --fly_t=8 --fly_hold=1.5

## Геройские виды: t — точка, куда смотрит камера (x, z), yaw/pitch — градусы (yaw 0 — камера с юга, 90 — с востока),
## dist — масштаб кадра CameraRig, hour — лучший час (его меняет флаг --hour)
const VIEWS := {
	"overview": {"t": Vector2(194, 166), "yaw": 18.0, "pitch": 34.0, "dist": 110.0, "hour": 17.6},
	"menu": {"t": Vector2(196, 166), "yaw": 22.0, "pitch": 30.0, "dist": 76.0, "hour": 9.0},
	"main_street": {"t": Vector2(192, 150), "yaw": 188.0, "pitch": 22.0, "dist": 34.0, "hour": 8.0},
	"cardo_north": {"t": Vector2(192, 138), "yaw": 6.0, "pitch": 20.0, "dist": 40.0, "hour": 9.0},
	"market": {"t": Vector2(192, 172), "yaw": 35.0, "pitch": 36.0, "dist": 30.0, "hour": 10.0},
	"park": {"t": Vector2(215, 150), "yaw": 300.0, "pitch": 32.0, "dist": 36.0, "hour": 17.0},
	"forum": {"t": Vector2(152, 156), "yaw": 60.0, "pitch": 30.0, "dist": 40.0, "hour": 16.5},
	"temple": {"t": Vector2(192, 230), "yaw": 180.0, "pitch": 24.0, "dist": 34.0, "hour": 18.2},
	"villas": {"t": Vector2(205, 211), "yaw": 165.0, "pitch": 30.0, "dist": 30.0, "hour": 16.5},
	"entrance": {"t": Vector2(192, 84), "yaw": 160.0, "pitch": 28.0, "dist": 52.0, "hour": 7.2},
	"theatre": {"t": Vector2(150, 190), "yaw": 20.0, "pitch": 38.0, "dist": 40.0, "hour": 17.8},
	"night": {"t": Vector2(192, 172), "yaw": 25.0, "pitch": 32.0, "dist": 70.0, "hour": 22.5},
	"aqueduct": {"t": Vector2(100, 118), "yaw": 200.0, "pitch": 20.0, "dist": 60.0, "hour": 17.4},
	"plan": {"t": Vector2(192, 166), "yaw": 0.0, "pitch": 89.0, "dist": 160.0, "hour": 12.0},
}

const CARDO := 192.0                      # главная улица (с севера на юг)
const DECU := 172.0                       # декуманус (с запада на восток)
const MARKET := Vector2(192, 172)
const POND := Vector2(215, 150)           # пруд в парке (Land.PONDS[0])
const LAKE := Vector2(130, 182)           # озеро у форума (Land.PONDS[1])

var g                                     # Game
var city: City
var land: Land
var rng := RandomNumberGenerator.new()
var args := {}
var _started := false
var _orbit := 0.0
var _cols := []                           # последние цвета в ряду (соседи — разные)
var _houses := []                         # поставленные дома (для украшений на стенах)
var _greens := {}                         # клетки 1 м, где уже растёт посаженное дерево или куст (природа клетки не занимает)


## Построить город вместо обычного готового (вызывается из Game._ready в режиме --promo)
static func build(game, a: Dictionary) -> void:
	var s := Showcase.new()
	s.name = "Showcase"
	s.g = game
	s.args = a
	game.add_child(s)
	s._build()


func _build() -> void:
	city = g.city
	land = g.land
	rng.seed = 2026
	seed(2026)
	var t0 := Time.get_ticks_msec()
	# постройки показываем один раз в конце (иначе каждая перерисовывается при каждом изменении), пересчёт — тоже
	if city.building_added.is_connected(g._on_added):
		city.building_added.disconnect(g._on_added)
	city.bulk = true
	# вся карта своя: у края нет табличек «купить участок» (витрина не сохраняется)
	for j in Land.PLOTS:
		for i in Land.PLOTS:
			land.owned[Vector2i(i, j)] = true
	city.money = 1.0e9
	city.rp = 0
	city.level = 7
	for r in Defs.RESEARCH:
		city.research[r["id"]] = true
	for q in Defs.REQUESTS:
		city.goals_done.append(q["id"])
		if q.has("unlock"):
			city.research[q["unlock"]] = true
	var verbose := args.has("verbose")
	for st: String in ["_streets", "_monuments", "_learning", "_market", "_forum_square", "_lake_garden", "_temple_square", "_park",
			"_entrance", "_rows", "_villas", "_street_lamps", "_groves", "_yards", "_wall_decor", "_farms", "_aqueduct", "_all_looks"]:
		var ts := Time.get_ticks_msec()
		call(st)
		if verbose:
			print("  showcase %s: %d ms, %d buildings" % [st, Time.get_ticks_msec() - ts, city.buildings.size()])
	city.bulk = false
	city.money = 48000.0
	city.level = 7
	city.compute()
	var c := city.center()
	c["tier"] = city.level
	for id in city.buildings:
		g._show(city.buildings[id])
	city.building_added.connect(g._on_added)
	print("SHOWCASE built: %d buildings, %d houses, pop %d, %d ms" % [city.buildings.size(), _houses.size(), int(city.stats["pop"]), Time.get_ticks_msec() - t0])


# ---------- кирпичики ----------

func _road(a: Vector2, b: Vector2, r: float, kd := Land.Kind.ROAD) -> void:
	land.paint_line(a, b, r, kd, true)


## Площадь из плитки — прямоугольник (ровная, края скруглены кистью)
func _plaza(r: Rect2) -> void:
	for pass_i in 2:
		var y := r.position.y + 0.5
		while y < r.end.y:
			var x := r.position.x + 0.5
			while x < r.end.x:
				land.paint_circle(Vector2(x, y), 0.6, Land.Kind.PLAZA, true, false, true)
				x += 1.0
			y += 1.0


## Поставить постройку ровно здесь (монументы, прилавки): только если место свободно; круто — выровнять
func _at(type: String, pos: Vector2, yaw: float, variant := 0, color := -1) -> Dictionary:
	if color < 0:
		color = _color()
	var chk := city.check_place(type, pos, yaw, variant, color, -2)
	var err: String = chk["err"]
	if err == "Слишком круто":
		var cells: PackedInt32Array = chk["cells"]
		var s := 0.0
		for k in cells:
			s += land.hq(k)
		land.flatten_cells(cells, snappedf(s / maxf(1.0, cells.size()), Land.STEP))
		chk = city.check_place(type, pos, yaw, variant, color, -2)
		err = chk["err"]
	if err != "" and err != "Нужна дорога у входа":
		if args.has("verbose"):
			print("  showcase: %s at %s — %s" % [type, str(pos), err])
		return {}
	return city.place(type, pos, yaw, variant, color, true)


## Поставить по правилам игры (Game.placement: фасадом к ближайшей дороге, в ряд к соседям); {} — не вышло
func _place(type: String, p: Vector2, variant := -1, color := -1, tier := 1) -> Dictionary:
	var d: Dictionary = Defs.B[type]
	if variant < 0:
		variant = rng.randi() % int(d.get("variants", 1))
	if color < 0:
		color = _color()
	g.last_snap_n = Vector2.ZERO
	g.last_snap_p = Vector2.INF
	var pl: Dictionary = g.placement(type, p, variant, color)
	if pl["err"] != "":
		return {}
	return _commit(type, pl, variant, color, tier)


func _commit(type: String, pl: Dictionary, variant: int, color: int, tier: int) -> Dictionary:
	var b := city.place(type, pl["pos"], pl["yaw"], variant, color, true)
	if city.is_house(b):
		_settle(b, tier)
	return b


## Дом заселён: по семье на этаж
func _settle(b: Dictionary, tier: int) -> void:
	var cls: String = city.def(b)["cls"]
	b["tier"] = clampi(tier, 1, Defs.floors_max(cls))
	b["pop"] = city.house_cap(b)
	var fams := []
	var per := int(Defs.CLASSES[cls]["per_floor"])
	for f in int(b["tier"]):
		fams.append({"name": Defs.FAMILIES[rng.randi() % Defs.FAMILIES.size()], "n": per})
	b["families"] = fams
	_houses.append(b)


## Цвет штукатурки: не такой, как у двух предыдущих соседей
func _color() -> int:
	var c := rng.randi() % Defs.PALETTE.size()
	var guard := 0
	while _cols.has(c) and guard < 20:
		c = rng.randi() % Defs.PALETTE.size()
		guard += 1
	_cols.append(c)
	if _cols.size() > 2:
		_cols.pop_front()
	return c


## Украшение в точке (поворот — свой); если занято — рядом по кругу до rmax
func _deco(type: String, p: Vector2, yaw := 0.0, rmax := 0.0) -> Dictionary:
	var k := 0
	var rr := 0.0
	while rr <= rmax + 0.001:
		var n := 1 if rr == 0.0 else maxi(6, int(rr * 8))
		for q in n:
			var pp := p + Vector2(cos(TAU * q / n), sin(TAU * q / n)) * rr
			var chk := city.check_place(type, pp, yaw, 0, 0, -2)
			if chk["err"] == "":
				return city.place(type, pp, yaw, 0, int(Defs.B[type].get("color", 0)), true)
		k += 1
		rr = k * 0.4
	return {}


## Облик украшения: случайный из видов base («tree» → tree / tree_2)
func _look(base: String) -> String:
	var l := Defs.looks_of(base)
	return l[rng.randi() % l.size()]


static func yaw_to(dir: Vector2) -> float:
	return atan2(dir.x, dir.y)


## Посадить дерево, куст или цветы природы (их можно снести, как лес; клетки они не занимают)
func _plant(name: String, p: Vector2, s: float) -> void:
	var key := Vector2i(int(floor(p.x)), int(floor(p.y)))
	if _greens.has(key):
		return
	for dj in range(-1, 2):
		for di in range(-1, 2):
			_greens[key + Vector2i(di, dj)] = true
	var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, land.height_at(p.x, p.y), p.y))
	g._add_nature(name, xf, p)


## Вокруг точки (радиус r) нет построек, дорог и воды
func _free_r(p: Vector2, r: float) -> bool:
	for q: Vector2 in [Vector2.ZERO, Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r), Vector2(r, r) * 0.7, Vector2(-r, r) * 0.7, Vector2(r, -r) * 0.7, Vector2(-r, -r) * 0.7]:
		var c := land.cell(p + q)
		var k := land.idx(c.x, c.y)
		if land.occ[k] != 0 or Land.walk_kind(land.kind[k]) or land.hq(k) < Land.WATER_Y + 0.2:
			return false
	return true


# ---------- улицы и площади ----------

func _streets() -> void:
	_road(Vector2(CARDO, 104), Vector2(CARDO, 230), 1.8)    # кардо: от станции на юг к храму
	_road(Vector2(140, DECU), Vector2(250, DECU), 1.6)      # декуманус: от форума через рынок на восток
	_road(Vector2(166, 112), Vector2(166, 230), 1.4)        # западная улица
	_road(Vector2(166, 134), Vector2(204, 134), 1.4)        # северная улица
	_road(Vector2(142, 206), Vector2(246, 206), 1.4)        # южная улица (виллы)
	_road(Vector2(222, DECU), Vector2(222, 230), 1.4)       # восточная улица
	_road(Vector2(166, 230), Vector2(250, 230), 1.4)        # храмовая улица (к амфитеатру)
	_road(Vector2(194, 120), Vector2(246, 120), 1.4)        # над парком
	_road(Vector2(246, 120), Vector2(246, 206), 1.4)        # за парком
	_plaza(Rect2(182, 164, 20, 16))                         # рынок
	_plaza(Rect2(140, 147, 24, 24))                         # форум
	_plaza(Rect2(181, 222, 22, 9))                          # перед храмом
	# парк у пруда: кольцевая тропа и тропинки к улицам
	var n := 44
	for k in n:
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		_road(POND + Vector2(cos(a0), sin(a0)) * 11.0, POND + Vector2(cos(a1), sin(a1)) * 11.0, 0.8, Land.Kind.DIRT)
	_road(Vector2(193.5, 150), Vector2(204.0, 150), 0.8, Land.Kind.DIRT)
	_road(Vector2(215, 161.0), Vector2(215, 170.6), 0.8, Land.Kind.DIRT)
	_road(Vector2(215, 121.2), Vector2(215, 139.0), 0.8, Land.Kind.DIRT)
	_road(Vector2(226.0, 150), Vector2(244.8, 150), 0.8, Land.Kind.DIRT)
	# у озера: тропа вдоль берега от декумануса к южной улице
	_road(Vector2(145.5, 173.4), Vector2(145.5, 205.0), 0.75, Land.Kind.DIRT)


# ---------- монументы ----------

func _monuments() -> void:
	_at("temple", Vector2(CARDO, 236.8), PI, 0, 0)
	_at("forum", Vector2(135.3, 159.0), PI / 2, 0, 0)
	_at("pantheon", Vector2(152.0, 136.8), 0.0, 0, 0)
	_at("arch", Vector2(152.0, 174.9), PI, 0, 0)
	_at("theatre", Vector2(156.0, 199.0), 0.0, 0, 0)
	_at("odeon", Vector2(154.0, 210.8), PI, 0, 0)
	_at("colosseum", Vector2(238.0, 241.6), PI, 0, 0)
	_at("baths", Vector2(236.0, 168.0), 0.0, 0, 0)
	_at("balnea", Vector2(232.5, 202.6), 0.0, 0, 0)


func _learning() -> void:
	_at("academy", Vector2(186.0, 118.0), PI / 2, 0, 6)
	_at("library", Vector2(177.0, 130.6), 0.0, 0, 6)
	_at("school", Vector2(169.8, 120.5), -PI / 2, 0, 3)
	_at("scriptorium", Vector2(195.6, 109.0), -PI / 2, 0, 9)
	_at("warehouse", Vector2(195.2, 98.6), -PI / 2, 0, 0)
	# склады у западной и восточной улиц (фасадом к ним): лавкам со значком склада есть откуда брать товар
	_place("warehouse", Vector2(170.5, 152.0), 0, 0)
	_place("warehouse", Vector2(218.0, 190.0), 0, 0)


# ---------- рынок ----------

func _market() -> void:
	var c := MARKET
	_at("fountain", c, 0.0, 0, 0)
	# кольцо прилавков вокруг фонтана — лицом наружу (покупатели обходят кругом)
	var ring := ["stall_fruit", "stall_veg", "stall_fish", "musicians", "stall_fruit", "stall_veg", "stall_fish", "dice"]
	for k in 8:
		var a := TAU * (k + 0.5) / 8.0
		var p := c + Vector2(cos(a) * 6.6, sin(a) * 5.6)
		_at(ring[k], p, yaw_to(p - c), 0, -1)
	# скамьи вокруг фонтана, жаровни по углам, товары и телеги у прилавков
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4
		var p := c + Vector2(cos(a), sin(a)) * 3.4
		_deco(_look("bench"), p, yaw_to(p - c), 0.4)
	for q: Vector2 in [Vector2(-9.0, -7.0), Vector2(9.0, -7.0), Vector2(-9.0, 7.0), Vector2(9.0, 7.0)]:
		_deco(_look("bigbrazier"), c + q, 0.0, 0.4)
	for k in 12:
		var a := TAU * k / 12.0 + 0.26
		var p := c + Vector2(cos(a) * 8.8, sin(a) * 7.0)
		_deco(_look(["goods", "amphorae", "goods", "cart"][k % 4]), p, yaw_to(c - p), 0.5)


# ---------- форум ----------

func _forum_square() -> void:
	var c := Vector2(152, 159)
	_at("fountain", c, PI / 2, 0, 0)
	# у фонтана — четыре круглые клумбы и скамьи, по оси — статуи на постаментах
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4
		var dir := Vector2(cos(a), sin(a))
		_deco("flowers_2", c + dir * 4.4, 0.0, 0.4)
		_deco(_look("bench"), c + Vector2(cos(a + PI / 4), sin(a + PI / 4)) * 4.2, yaw_to(Vector2(cos(a + PI / 4), sin(a + PI / 4))), 0.3)
	for sd: float in [-1.0, 1.0]:
		for k in 3:
			_deco(["statue", "statue_3", "statue_4"][k], c + Vector2(-6.0 + k * 6.0, 6.8 * sd), PI if sd > 0 else 0.0, 0.4)
		_deco("column", Vector2(152 + 6.6 * sd, 149.6), 0.0, 0.4)
		_deco(_look("lion"), c + Vector2(-9.0, 4.2 * sd), PI / 2, 0.4)
		_deco(_look("bigbrazier"), c + Vector2(-9.2, 8.8 * sd), 0.0, 0.4)
		_deco(_look("bigbrazier"), Vector2(152 + 3.6 * sd, 149.4), 0.0, 0.4)
		# по краям площади — кипарисы в каменных кругах и знамёна
		for k in 5:
			_deco("cypress_2", Vector2(141.4 + k * 5.3, 159 + 10.7 * sd), 0.0, 0.3)
		for k in 3:
			_deco(_look("banner"), Vector2(162.6, 159 + sd * (3.0 + k * 3.4)), -PI / 2, 0.3)
	_deco(_look("candelabrum"), c + Vector2(7.5, 0.0), 0.0, 0.4)
	_deco(_look("sundial"), c + Vector2(-5.6, 0.0), 0.0, 0.4)


## Сад у озера: аллея кипарисов вдоль берега, статуи, беседка, скамьи лицом к воде
func _lake_garden() -> void:
	var z := 177.0
	var k := 0
	while z < 204.0:
		_deco("cypress_2" if k % 2 == 0 else "cypress", Vector2(147.6, z), 0.0, 0.3)
		if k % 2 == 1:
			_deco(_look("bench"), Vector2(143.6, z), -PI / 2, 0.3)
		elif k % 4 == 0:
			_deco(_look("lamp_post"), Vector2(143.5, z + 1.2), 0.0, 0.3)
		z += 3.0
		k += 1
	_deco("pergola_2", Vector2(158.0, 181.5), 0.0, 1.5)
	_deco(_look("statue"), Vector2(152.0, 179.0), PI, 0.6)
	_deco(_look("smallfountain"), Vector2(162.0, 178.0), -PI / 2, 0.6)
	_deco("pergola", Vector2(155.0, 189.0), PI, 1.2)
	for q: Vector2 in [Vector2(161.5, 186.0), Vector2(150.5, 185.0), Vector2(162.0, 192.0)]:
		_deco(_look(["flowers", "bush", "palm"][rng.randi() % 3]), q, rng.randf() * TAU, 0.8)
	for k2 in 5:
		var a := TAU * k2 / 5.0 + 0.4
		var t := "swan" if k2 % 2 == 0 else "duck"
		var p := LAKE + Vector2(cos(a), sin(a)) * 6.0
		if city.check_place(t, p, a, 0, 0, -2)["err"] == "":
			city.place(t, p, a, 0, 0, true)


# ---------- храм ----------

func _temple_square() -> void:
	var c := Vector2(CARDO, 226.5)
	for sd: float in [-1.0, 1.0]:
		_deco(_look("statue"), c + Vector2(6.4 * sd, -1.6), PI, 0.5)
		_deco(_look("lion"), Vector2(CARDO + 5.8 * sd, 233.2), PI, 0.4)
		_deco(_look("bigbrazier"), c + Vector2(9.4 * sd, 2.6), 0.0, 0.4)
		_deco(_look("banner"), c + Vector2(3.4 * sd, -3.2), PI, 0.4)
		_deco(_look("candelabrum"), c + Vector2(3.3 * sd, 3.4), 0.0, 0.3)
		for k in 4:
			_deco("cypress_2" if k % 2 == 0 else "cypress", Vector2(CARDO + 5.9 * sd, 236.2 + k * 2.2), 0.0, 0.4)


# ---------- парк у пруда ----------

func _park() -> void:
	var pc := POND
	# у воды — скамьи лицом к пруду, цветы, кусты, фонари; по внешней стороне тропы — кипарисы, деревья, пальмы
	for k in 12:
		var a := TAU * k / 12.0 + 0.26
		var dir := Vector2(cos(a), sin(a))
		match k % 3:
			0: _deco(_look("bench"), pc + dir * 9.5, yaw_to(-dir), 0.4)
			1: _deco(_look("flowers"), pc + dir * 9.6, yaw_to(-dir), 0.4)
			2: _deco(_look("bush"), pc + dir * 9.6, yaw_to(-dir), 0.4)
	for k in 22:
		var a := TAU * k / 22.0 + 0.07
		var dir := Vector2(cos(a), sin(a))
		var t: String = "cypress" if k % 2 == 0 else ["tree", "palm", "tree", "flowers"][(k / 2) % 4]
		_deco(_look(t), pc + dir * 12.9, 0.0, 0.5)
	for k in 6:
		var a := TAU * k / 6.0 + 0.52
		_deco(_look("lamp_post"), pc + Vector2(cos(a), sin(a)) * 12.6, 0.0, 0.4)
	# беседки, статуи у входов, фонтанчики, часы
	_deco("pergola_2", pc + Vector2(-11.5, -11.0), 0.8, 1.2)
	_deco("pergola", pc + Vector2(11.5, 11.0), PI + 0.8, 1.2)
	_deco("pergola", pc + Vector2(-12.0, 10.5), -0.8, 1.2)
	for sd: float in [-1.0, 1.0]:
		_deco(_look("statue"), Vector2(205.6, 150 + 2.3 * sd), -PI / 2, 0.4)
		_deco(_look("planter"), Vector2(215 + 2.0 * sd, 137.0), 0.0, 0.4)
		_deco(_look("lion"), Vector2(215 + 2.6 * sd, 164.0), 0.0, 0.4)
	_deco(_look("smallfountain"), pc + Vector2(13.5, -8.0), 0.0, 0.8)
	_deco(_look("sundial"), pc + Vector2(14.0, 6.0), 0.0, 0.8)
	_deco(_look("well"), pc + Vector2(-15.0, -6.0), 0.0, 0.8)
	# утки и лебеди на пруду
	for k in 6:
		var a := TAU * k / 6.0 + 0.3
		var p := pc + Vector2(cos(a), sin(a)) * 3.8
		var t := "swan" if k % 3 == 0 else "duck"
		if city.check_place(t, p, a, 0, 0, -2)["err"] == "":
			city.place(t, p, a, 0, 0, true)


# ---------- въезд: аллея кипарисов, станция ----------

func _entrance() -> void:
	var z := 69.0
	var k := 0
	while z <= 91.0:
		for sd: float in [-1.0, 1.0]:
			if k % 3 == 2:
				_deco(_look("lamp_post"), Vector2(CARDO + 3.6 * sd, z), 0.0, 0.3)
			else:
				_deco("cypress" if k % 2 == 0 else "cypress_2", Vector2(CARDO + 4.4 * sd, z), 0.0, 0.3)
		z += 3.6
		k += 1
	# плетень вдоль полей у дороги, посередине — калитка
	var fz := 68.4
	var fk := 0
	while fz < 92.0:
		_deco("fence_2" if fk == 5 else "fence", Vector2(184.9, fz), PI / 2, 0.0)
		fz += 2.12 if fk != 5 else 2.4
		fk += 1
	# у станции: телеги, амфоры, мешки, колодец, сено
	for q: Array in [["cart", Vector2(200.0, 105.5)], ["amphorae", Vector2(201.0, 93.0)], ["goods_2", Vector2(199.0, 91.6)], ["cart_2", Vector2(178.5, 106.0)],
			["well", Vector2(179.5, 91.5)], ["hay_2", Vector2(175.5, 96.0)], ["amphorae_2", Vector2(176.0, 102.0)], ["goods_3", Vector2(201.5, 102.5)]]:
		_deco(q[0], q[1], rng.randf() * TAU, 1.0)


# ---------- ряды домов вдоль улиц ----------

## Ряд вдоль улицы a→b (полуширина r) с одной стороны side (+1 — слева по ходу на карте, −1 — справа):
## style — какие дома и лавки (см. _pick); дома встают фасадом к этой улице, вплотную (Game.placement + ряд)
func _row(a: Vector2, b: Vector2, r: float, side: float, style: String, ends := 2.5) -> void:
	var dir := (b - a).normalized()
	var n := Vector2(-dir.y, dir.x) * side         # от улицы к домам
	var L := a.distance_to(b)
	var t := ends
	var i := 0
	var miss := 0
	_cols.clear()
	while t < L - ends:
		var spec := _pick(style, i)
		var type: String = spec["type"]
		var v := rng.randi() % int(Defs.B[type].get("variants", 1))
		var col := _color()
		var bb: Array = g._row_bounds(Catalog.make(type, 1, v, col))
		var w := float(bb[1]) - float(bb[0])
		var depth_c := float(bb[3]) - (float(bb[2]) + float(bb[3])) * 0.5
		if t + w > L - ends + 0.5:
			break
		var p := a + dir * (t + w * 0.5) + n * (r + 0.1 + depth_c)
		g.last_snap_n = Vector2.ZERO
		g.last_snap_p = Vector2.INF
		var pl: Dictionary = g.placement(type, p, v, col)
		var ok: bool = pl["err"] == ""
		if ok:
			var f := City.facing(pl["yaw"])
			ok = f.dot(-n) > 0.96 and absf(((pl["pos"] as Vector2) - p).dot(dir)) < 1.6
		if ok:
			_commit(type, pl, v, col, int(spec["tier"]))
			t += w + float(spec.get("gap", 0.6))
			i += 1
			miss = 0
		else:
			t += 0.5
			miss += 1


## Что поставить в ряд: тип, этажи, промежуток после (широкий — под фонарь или кипарис)
func _pick(style: String, i: int) -> Dictionary:
	var r := rng.randf()
	var gap := 2.3 if i % 6 == 5 else 0.6
	match style:
		"pleb":
			if r < 0.78:
				return {"type": "house_pleb", "tier": [1, 2, 2, 3, 3][rng.randi() % 5], "gap": gap}
			return {"type": "house_artisan", "tier": 1 + rng.randi() % 3, "gap": gap}
		"mixed":
			if r < 0.14:
				return {"type": _shop(), "tier": 1, "gap": gap}
			if r < 0.55:
				return {"type": "house_pleb", "tier": 1 + rng.randi() % 3, "gap": gap}
			return {"type": "house_artisan", "tier": [2, 3, 3][rng.randi() % 3], "gap": gap}
		"main":
			if r < 0.2:
				return {"type": _shop(), "tier": 1, "gap": gap}
			if r < 0.3:
				return {"type": "house_patrician", "tier": 2, "gap": gap}
			if r < 0.5:
				return {"type": "house_pleb", "tier": 3, "gap": gap}
			return {"type": "house_artisan", "tier": [2, 3, 3][rng.randi() % 3], "gap": gap}
		"shops":
			if i % 2 == 0:
				return {"type": _shop(), "tier": 1, "gap": 0.6}
			return {"type": "house_artisan", "tier": [2, 3, 3][rng.randi() % 3], "gap": 0.6}
		"rich":
			if r < 0.45:
				return {"type": "house_patrician", "tier": 1 + rng.randi() % 2, "gap": 2.6}
			if r < 0.55:
				return {"type": _shop(), "tier": 1, "gap": gap}
			return {"type": "house_artisan", "tier": 1 + rng.randi() % 2, "gap": gap}
	return {"type": "house_pleb", "tier": 2, "gap": gap}


var _shop_i := 0
const SHOPS := ["bakery", "butcher", "thermopolium", "weaver", "barber", "potter", "cobbler", "wineshop", "taberna", "tailor", "oilshop",
	"perfumer", "dyer", "lamps", "jeweler", "medic", "fullonica", "mimes"]


func _shop() -> String:
	_shop_i += 1
	return SHOPS[_shop_i % SHOPS.size()]


func _rows() -> void:
	# рынок: лавки по краям площади, лицом к ней
	_row(Vector2(182, 164), Vector2(182, 170.4), 0.0, 1.0, "shops", 0.3)
	_row(Vector2(182, 173.6), Vector2(182, 180), 0.0, 1.0, "shops", 0.3)
	_row(Vector2(202, 164), Vector2(202, 170.4), 0.0, -1.0, "shops", 0.3)
	_row(Vector2(202, 173.6), Vector2(202, 180), 0.0, -1.0, "shops", 0.3)
	_row(Vector2(182, 164), Vector2(190.2, 164), 0.0, -1.0, "shops", 0.3)
	_row(Vector2(193.8, 164), Vector2(202, 164), 0.0, -1.0, "shops", 0.3)
	_row(Vector2(182, 180), Vector2(190.2, 180), 0.0, 1.0, "shops", 0.3)
	_row(Vector2(193.8, 180), Vector2(202, 180), 0.0, 1.0, "shops", 0.3)
	# кардо — витрина города: дома повыше, лавки, домусы
	_row(Vector2(CARDO, 104), Vector2(CARDO, 164), 1.8, 1.0, "main")
	_row(Vector2(CARDO, 104), Vector2(CARDO, 164), 1.8, -1.0, "main")
	_row(Vector2(CARDO, 180), Vector2(CARDO, 198), 1.8, 1.0, "main")
	_row(Vector2(CARDO, 180), Vector2(CARDO, 198), 1.8, -1.0, "main")
	_row(Vector2(CARDO, 198), Vector2(CARDO, 222), 1.8, 1.0, "rich", 1.0)
	_row(Vector2(CARDO, 198), Vector2(CARDO, 222), 1.8, -1.0, "rich", 1.0)
	# декуманус
	_row(Vector2(164, DECU), Vector2(182, DECU), 1.6, 1.0, "shops")
	_row(Vector2(164, DECU), Vector2(182, DECU), 1.6, -1.0, "shops")
	_row(Vector2(202, DECU), Vector2(250, DECU), 1.6, 1.0, "mixed")
	_row(Vector2(202, DECU), Vector2(250, DECU), 1.6, -1.0, "shops")
	# западная и северная
	_row(Vector2(166, 112), Vector2(166, 230), 1.4, 1.0, "pleb")
	_row(Vector2(166, 112), Vector2(166, 230), 1.4, -1.0, "pleb")
	_row(Vector2(166, 134), Vector2(204, 134), 1.4, 1.0, "pleb")
	_row(Vector2(166, 134), Vector2(204, 134), 1.4, -1.0, "mixed")
	# над парком, за парком, восточная
	_row(Vector2(194, 120), Vector2(246, 120), 1.4, 1.0, "mixed")
	_row(Vector2(194, 120), Vector2(246, 120), 1.4, -1.0, "pleb")
	_row(Vector2(246, 120), Vector2(246, 206), 1.4, 1.0, "pleb")
	_row(Vector2(246, 120), Vector2(246, 206), 1.4, -1.0, "mixed")
	_row(Vector2(222, DECU), Vector2(222, 230), 1.4, 1.0, "mixed")
	_row(Vector2(222, DECU), Vector2(222, 230), 1.4, -1.0, "rich")
	# храмовая (южная улица — улица вилл, см. _villas)
	_row(Vector2(166, 230), Vector2(250, 230), 1.4, -1.0, "rich")


## Улица вилл (южная): домусы патрициев с портиками по обе стороны, между ними — сады: кипарисы, пальмы,
## статуи, фонтанчики, клумбы
func _villas() -> void:
	var gaps := ["cypress_2", "fence_3", "palm_2", "statue_3", "cypress", "smallfountain_2", "fence_3", "palm", "flowers_3", "statue_2", "bush_2", "planter_2"]
	var gi := 0
	for side: float in [1.0, -1.0]:
		for seg: Array in [[142.0, 164.6], [167.4, 190.2], [193.8, 220.6], [223.4, 244.6]]:
			var x0: float = seg[0]
			var x1: float = seg[1]
			var t := 1.2
			var k := 0
			while x0 + t + 2.82 < x1 - 0.8:
				var p := Vector2(x0 + t + 1.41, 206.0 + side * (1.4 + 0.1 + 3.67))
				var col: int = [6, 9, 0, 7, 3, 2, 5, 8][(k + (3 if side < 0 else 0)) % 8]
				var v := (k + (2 if side < 0 else 0)) % 4
				g.last_snap_n = Vector2.ZERO
				g.last_snap_p = Vector2.INF
				var pl: Dictionary = g.placement("house_patrician", p, v, col)
				if pl["err"] != "" or absf(((pl["pos"] as Vector2) - p).x) > 1.5 or City.facing(pl["yaw"]).dot(Vector2(0, -side)) < 0.96:
					t += 0.5
					continue
				var bld := _commit("house_patrician", pl, v, col, 2 if k % 3 != 1 else 1)
				t += 2.82 + 3.0
				k += 1
				# в саду между виллами — у самой улицы
				var gp: Vector2 = (bld["pos"] as Vector2) + Vector2(1.41 + 1.5, 0) + City.facing(bld["yaw"]) * 2.4
				_deco(gaps[gi % gaps.size()], gp, bld["yaw"], 0.4)
				gi += 1


# ---------- фонари вдоль улиц ----------

func _street_lamps() -> void:
	var segs := [[Vector2(CARDO, 108), Vector2(CARDO, 162), 1.8, 8.0], [Vector2(CARDO, 182), Vector2(CARDO, 220), 1.8, 8.0],
		[Vector2(204, DECU), Vector2(248, DECU), 1.6, 10.0], [Vector2(166, 114), Vector2(166, 228), 1.4, 12.0], [Vector2(168, 134), Vector2(202, 134), 1.4, 12.0],
		[Vector2(144, 206), Vector2(244, 206), 1.4, 10.0], [Vector2(222, 174), Vector2(222, 228), 1.4, 12.0], [Vector2(196, 120), Vector2(244, 120), 1.4, 12.0],
		[Vector2(246, 122), Vector2(246, 204), 1.4, 12.0], [Vector2(168, 230), Vector2(248, 230), 1.4, 12.0], [Vector2(166, DECU), Vector2(180, DECU), 1.6, 8.0]]
	for s: Array in segs:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var r: float = s[2]
		var step: float = s[3]
		var dir := (b - a).normalized()
		var n := Vector2(-dir.y, dir.x)
		var L := a.distance_to(b)
		var t := 3.0
		var k := 0
		while t < L - 2.0:
			var sd := 1.0 if k % 2 == 0 else -1.0
			var p := a + dir * t + n * sd * (r + 0.42)
			for dt: float in [0.0, 0.7, -0.7, 1.4, -1.4, 2.1, -2.1]:
				var q := p + dir * dt
				if land.occ_at(q) == 0 and _lamp_ok(q):
					if not _deco(_look("lamp_post"), q, yaw_to(-n * sd), 0.0).is_empty():
						break
			t += step
			k += 1


## Фонарь не встаёт на середину дороги: рядом должна быть не-дорога (обочина)
func _lamp_ok(q: Vector2) -> bool:
	return not (land.is_road(q + Vector2(0.6, 0)) and land.is_road(q - Vector2(0.6, 0)) and land.is_road(q + Vector2(0, 0.6)) and land.is_road(q - Vector2(0, 0.6)))


# ---------- дворы и сады ----------

## Рощицы по углам парка (после домов: деревья природы клеток не занимают, их ставим только в свободные места)
func _groves() -> void:
	for k in 130:
		var p := POND + Vector2(rng.randf_range(-20, 20), rng.randf_range(-19, 19))
		if p.distance_to(POND) < 14.5 or not _free_r(p, 2.2):
			continue
		if rng.randf() < 0.6:
			_plant("SM_Env_Tree_0%d" % (1 + rng.randi() % 4), p, rng.randf_range(0.36, 0.5))
		else:
			_plant("SM_Env_Tree_Bush_0%d" % (1 + rng.randi() % 3), p, rng.randf_range(0.5, 0.8))


## Внутри кварталов (за домами): деревья, кусты и цветы, а между ними — сено, овцы, колодцы, перголы, амфоры
func _yards() -> void:
	var opts := ["hay", "well", "pergola", "amphorae", "planter", "sheep", "goods", "flowers", "bush", "tree", "cypress", "palm", "sundial", "smallfountain", "bench", "cart", "flowers", "bush"]
	var z := 104.0
	while z < 248.0:
		var x := 128.0
		while x < 258.0:
			var p := Vector2(x + rng.randf_range(-0.8, 0.8), z + rng.randf_range(-0.8, 0.8))
			x += 2.1
			if not _between_houses(p) or not _free_r(p, 1.0):
				continue
			var r := rng.randf()
			if r < 0.4 and _free_r(p, 2.0):
				_plant("SM_Env_Tree_0%d" % (1 + rng.randi() % 4), p, rng.randf_range(0.42, 0.6))
			elif r < 0.54:
				_plant("SM_Env_Tree_Bush_0%d" % (1 + rng.randi() % 3), p, rng.randf_range(0.55, 0.8))
			elif r < 0.72:
				_plant("SM_Env_Flowers_0%d" % (1 + rng.randi() % 5), p, rng.randf_range(1.2, 1.9))
			elif r < 0.86 and not _greens.has(Vector2i(int(floor(p.x)), int(floor(p.y)))):
				_deco(_look(opts[rng.randi() % opts.size()]), p, rng.randf() * TAU, 0.0)
			else:
				_plant("SM_Env_Grass_0%d" % (1 + rng.randi() % 3), p, rng.randf_range(0.9, 1.4))
		z += 2.1


## Точка во дворе: постройки и с одной, и с другой стороны (по x или по z) в 10 м
func _between_houses(p: Vector2) -> bool:
	var hits := 0
	for d: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		for s in range(1, 11):
			var o := land.occ_at(p + d * s)
			if o > 0 and city.buildings.has(o) and city.def(city.buildings[o])["kind"] in ["house", "shop", "rp", "store"]:
				hits += 1
				break
	return hits >= 2


# ---------- украшения на стенах домов ----------

const WALLS := ["wall_flowers", "wall_flowers_2", "wall_flowers_3", "wall_lamp", "wall_lamp_2", "wall_torch", "wall_torch_2", "wall_banner", "wall_banner_2", "wall_banner_3"]


func _wall_decor() -> void:
	var i := 0
	for b in _houses:
		i += 1
		var main := absf((b["pos"] as Vector2).x - CARDO) < 8.0
		if i % 3 != 0 and not (main and i % 3 == 1):
			continue
		var bp := city.blueprint(b)
		var f := City.facing(b["yaw"])
		var ax := City.axis(b["yaw"])
		var dx := -signf(bp.door.x) * 0.72 if bp.door.x != 0.0 else 0.8
		var t: String = WALLS[(i / 3 + rng.randi() % 3) % WALLS.size()]
		var p: Vector2 = (b["pos"] as Vector2) + ax * dx + f * (bp.front_z() + 0.3)
		var pl: Dictionary = g._wall_place(t, p, 1.0)
		if pl["err"] != "" or int(pl.get("host", -1)) != int(b["id"]):
			continue
		var w := city.place(t, pl["pos"], pl["yaw"], 0, int(pl["color"]), true)
		w["host"] = pl["host"]
		w["y"] = pl["y"]


# ---------- поля, рощи и виноградники вокруг ----------

func _farms() -> void:
	# у въезда: к западу от дороги — пшеница и рощи, к востоку — виноградники
	for j in 3:
		for i in 4:
			_at(["farm", "grove", "farm", "farm"][(i + j) % 4], Vector2(154.0 + i * 8.4, 70.0 + j * 8.4), 0.0, 0, 0)
	for j in 4:
		for i in 5:
			if j == 3 and i == 0:
				continue
			_at("vineyard" if (i + j) % 3 != 2 else "grove", Vector2(203.0 + i * 8.4, 70.0 + j * 8.4), 0.0, 0, 0)
	# на западе за форумом и на востоке за парком
	for j in 3:
		for i in 2:
			_at(["farm", "vineyard", "grove"][(i + j) % 3], Vector2(117.0 + i * 8.0, 140.0 + j * 8.4), 0.0, 0, 0)
	for j in 5:
		for i in 3:
			_at(["vineyard", "grove", "farm"][(i + j) % 3], Vector2(256.0 + i * 8.4, 126.0 + j * 8.4), 0.0, 0, 0)
	# на юго-западе за одеоном и на юго-востоке за амфитеатром
	for j in 3:
		for i in 4:
			_at(["farm", "farm", "vineyard", "grove"][(i + 2 * j) % 4], Vector2(108.0 + i * 8.4, 216.0 + j * 8.4), 0.0, 0, 0)
	for j in 2:
		for i in 4:
			_at(["vineyard", "farm", "grove"][(i + j) % 3], Vector2(256.0 + i * 8.4, 233.0 + j * 8.4), 0.0, 0, 0)
	# овцы и сено у полей
	for q: Vector2 in [Vector2(150, 96), Vector2(146, 80), Vector2(244, 104), Vector2(112, 166), Vector2(280, 176), Vector2(252, 112), Vector2(104, 206),
			Vector2(140, 236), Vector2(292, 236), Vector2(286, 120)]:
		_deco(_look("sheep"), q, rng.randf() * TAU, 2.0)
		_deco(_look("hay"), q + Vector2(2.6, 1.5), rng.randf() * TAU, 2.0)


## Акведук: с западных холмов к форуму идёт римский водовод — ряд арок из кирпича (в низинах — в два яруса),
## поверху — каменный жёлоб с карнизом; у города — водонапорная башня. Это пейзаж (не постройка игры):
## детали ставятся прямо в пул Parts, земля под опорами помечена занятой (там не растёт лес и не строят)
const AQ_A := Vector2(30.0, 104.0)        # начало на холмах
const AQ_B := Vector2(139.0, 128.0)       # башня у пантеона
const AQ_W := 3.4                         # пролёт арки, м
const AQ_T := 0.42                        # полутолщина стены арок


func _aqueduct() -> void:
	var d := (AQ_B - AQ_A).normalized()
	var L := AQ_A.distance_to(AQ_B)
	var n := int(L / AQ_W)
	var yaw := atan2(-d.y, d.x)
	var bs := Basis(Vector3.UP, yaw)
	var nz := bs.z                                  # наружная сторона стены (вбок от трассы)
	var top := -INF
	for i in n + 1:
		var q := AQ_A + d * (i * AQ_W)
		top = maxf(top, land.height_at(q.x, q.y))
	top = clampf(top, 5.5, 11.0) + 0.6              # дно жёлоба: вода течёт ровно
	var b := Bp.new(77)
	var cells := PackedInt32Array()
	for i in n:
		var c0 := AQ_A + d * (i * AQ_W)
		var c1 := c0 + d * AQ_W
		var cm := (c0 + c1) * 0.5
		var gy := minf(land.height_at(c0.x, c0.y), minf(land.height_at(cm.x, cm.y), land.height_at(c1.x, c1.y))) - 0.15
		var h := top - gy
		if h < 0.6:
			continue
		var o := Vector3(c0.x, gy, c0.y)
		var e := Vector3(c1.x, gy, c1.y)
		if h < 1.8:
			# на холме — сплошная стенка
			CatMonuments._box(b, "#marble", (o + e) * 0.5 + Vector3(0, h * 0.5, 0), Vector3(AQ_W, h, AQ_T * 2.0), yaw)
		else:
			var tiers: Array = [[0.0, h]] if h < 5.6 else [[0.0, h - 2.9], [h - 2.9, 2.9]]
			for tr: Array in tiers:
				var y0: float = tr[0]
				var th: float = tr[1]
				var sc := Basis.from_scale(Vector3(AQ_W / 2.5, th / 3.0, 1.0))
				b.add_xf("SM_Bld_Wall_Door_Double_01", Transform3D(bs * sc, o + nz * AQ_T + Vector3(0, y0, 0)))
				b.add_xf("SM_Bld_Wall_Door_Double_01", Transform3D(Basis(Vector3.UP, yaw + PI) * sc, e - nz * AQ_T + Vector3(0, y0, 0)))
				# опоры изнутри арки (видно сквозь пролёт)
				for pe: Vector3 in [o, e]:
					CatMonuments._box(b, "#marble", pe + Vector3(0, y0 + th * 0.3, 0), Vector3(0.5, th * 0.6, AQ_T * 2.0 - 0.06), yaw)
				if y0 > 0.0:
					b.add_xf("SM_Bld_Wall_Large_Cap_01", Transform3D(bs * Basis.from_scale(Vector3(AQ_W / 5.02, 0.6, 1.25)), o + Vector3(0, y0, 0)))
		# жёлоб и карниз поверху
		CatMonuments._box(b, "#marble", (o + e) * 0.5 + Vector3(0, h + 0.28, 0), Vector3(AQ_W + 0.02, 0.56, AQ_T * 2.0 + 0.2), yaw)
		b.add_xf("SM_Bld_Wall_Large_Cap_01", Transform3D(bs * Basis.from_scale(Vector3(AQ_W / 5.02, 0.8, 1.35)), o + Vector3(0, h + 0.56, 0)))
		cells.append_array(land.footprint_cells([Rect2(0, -AQ_T - 0.3, AQ_W, AQ_T * 2.0 + 0.6)], c0, yaw - PI / 2))
	# водонапорная башня (кастеллум) у города
	var ty := land.height_at(AQ_B.x, AQ_B.y)
	var th2 := top + 1.2 - ty
	var tc := Vector3(AQ_B.x, ty, AQ_B.y) + Vector3(d.x, 0, d.y) * 1.6
	CatMonuments._box(b, "#marble", tc + Vector3(0, th2 * 0.5, 0), Vector3(3.2, th2, 3.2), yaw)
	# с четырёх сторон — стены с арочной нишей, поверху карниз и шатровая черепичная крыша
	for k in 4:
		var fb := Basis(Vector3.UP, yaw + k * PI / 2)
		var o4 := tc + fb * Vector3(-1.75, 0, 1.75)
		b.add_xf("SM_Bld_Wall_Door_Double_01", Transform3D(fb * Basis.from_scale(Vector3(3.5 / 2.5, th2 / 3.0, 1.0)), o4))
		b.add_xf("SM_Bld_Wall_Large_Cap_01", Transform3D(fb * Basis.from_scale(Vector3(3.9 / 5.02, 1.0, 1.4)), tc + fb * Vector3(-1.95, th2, 1.75)))
	var keep := b.base
	b.base = Transform3D(bs * Basis.from_scale(Vector3.ONE * 0.76), tc + Vector3(0, th2 + 0.3, 0))
	CatCivic._hip(b, -2.5, 2.5, -2.5, 2.5, 0.0, 1.5)
	b.base = keep
	g.parts.place(b, Transform3D.IDENTITY)
	cells.append_array(land.footprint_cells([Rect2(-1.9, -1.9, 3.8, 3.8)], Vector2(tc.x, tc.z), yaw))
	for k in cells:
		if land.occ[k] == 0:
			land.occ[k] = -1


## Каждый облик украшения — хотя бы раз (что не встало по плану, ставим в свободные места у площадей и в парке)
func _all_looks() -> void:
	var have := {}
	for id in city.buildings:
		have[city.buildings[id]["type"]] = true
	var spots := [Vector2(206, 132), Vector2(226, 132), Vector2(234, 140), Vector2(200, 160), Vector2(230, 160), Vector2(176, 152), Vector2(181, 142),
		Vector2(160, 186), Vector2(208, 214), Vector2(186, 214), Vector2(214, 222), Vector2(176, 222)]
	var si := 0
	for t in Defs.B:
		var d: Dictionary = Defs.B[t]
		if d["kind"] != "decor" or have.has(t) or d.get("water", false):
			continue
		if d.get("wall", false):
			for b in _houses:
				var bp := city.blueprint(b)
				var p: Vector2 = (b["pos"] as Vector2) + City.facing(b["yaw"]) * (bp.front_z() + 0.3) - City.axis(b["yaw"]) * signf(bp.door.x) * 0.72
				var pl: Dictionary = g._wall_place(t, p, 1.0)
				if pl["err"] == "" and int(pl.get("host", -1)) == int(b["id"]) and not _wall_taken(int(b["id"])):
					var w := city.place(t, pl["pos"], pl["yaw"], 0, int(pl["color"]), true)
					w["host"] = pl["host"]
					w["y"] = pl["y"]
					break
			continue
		for tries in spots.size():
			var p: Vector2 = spots[si % spots.size()]
			si += 1
			if not _deco(t, p, rng.randf() * TAU, 3.0).is_empty():
				break


func _wall_taken(id: int) -> bool:
	for k in city.buildings:
		if int(city.buildings[k].get("host", -1)) == id:
			return true
	return false


# ---------- камера, кошки, облёт ----------
## Флаги режима --promo (для ролика и снимков):
##   --hero=имя            встать на геройский вид (и его час, если не задан --hour)
##   --orbit=0.03          медленно вращать камеру вокруг цели (рад/с)
##   --daylapse=0.5        часы идут: столько игровых часов за секунду (закат → ночь)
##   --fly=a,b,c           облёт по геройским видам; --fly_t=8 — секунд на перелёт; --fly_hold=1.5 — постоять на виде;
##                         --fly_hour=keep — не менять час по пути; --fly_quit — закрыть игру после облёта
##                         (с --write-movie закрывается сама)

var _fly := []
var _fly_t := 8.0
var _fly_hold := 1.5
var _fly_clock := 0.0
var _fly_keep_hour := false
var _daylapse := 0.0
var _quit_t := -1.0


func _process(dt: float) -> void:
	if g == null or not g.ready_done:
		return
	if not _started:
		_started = true
		_start()
		return
	if _orbit != 0.0 and g.rig:
		g.rig._yaw_t += dt * _orbit
	if _daylapse != 0.0:
		g._set_hour(g.hour + dt * _daylapse)
	if not _fly.is_empty():
		_fly_step(dt)
	if _quit_t >= 0.0:
		_quit_t -= dt
		if _quit_t < 0.0:
			get_tree().quit()


func _start() -> void:
	# кошки сразу гуляют по улицам (в обычной игре они появляются постепенно)
	var ppl = g.people
	if ppl:
		var lived := city.buildings.values().filter(func(b): return city.is_house(b) and int(b["pop"]) > 0)
		for k in 12:
			if lived.is_empty() or ppl.cats.size() >= 12:
				break
			ppl.cats.append(ppl._make_cat(lived[rng.randi() % lived.size()]))
	_orbit = float(args.get("orbit", "0"))
	_daylapse = float(args.get("daylapse", "0"))
	if _daylapse != 0.0:
		g.clock_hours = false
	var hero := str(args.get("hero", ""))
	if g.mode == "menu" and hero == "" and not args.has("view"):
		hero = "menu"
	if hero == "" and not args.has("view"):
		hero = "overview"
	if args.has("fly"):
		_fly = Array(str(args["fly"]).split(",")).filter(func(v): return VIEWS.has(v))
		_fly_t = maxf(0.5, float(args.get("fly_t", "8")))
		_fly_hold = maxf(0.0, float(args.get("fly_hold", "1.5")))
		_fly_keep_hour = str(args.get("fly_hour", "")) == "keep" or args.has("hour")
		if not _fly.is_empty():
			hero = _fly[0]
	if VIEWS.has(hero):
		view(hero, not args.has("hour") and g.mode != "menu")


## Облёт: стоим на виде _fly_hold секунд, потом плавно (ease in/out) перелетаем к следующему за _fly_t секунд;
## цель, поворот, наклон, масштаб и (если не keep) час суток меняются вместе
func _fly_step(dt: float) -> void:
	_fly_clock += dt
	var leg := _fly_hold + _fly_t
	var seg := int(_fly_clock / leg)
	if seg >= _fly.size() - 1:
		if _quit_t < 0.0 and (Engine.get_write_movie_path() != "" or args.has("fly_quit")):
			_quit_t = _fly_hold + 0.5
		_fly = []
		return
	var u := clampf((fmod(_fly_clock, leg) - _fly_hold) / _fly_t, 0.0, 1.0)
	if u <= 0.0:
		return
	u = u * u * (3.0 - 2.0 * u)
	var a: Dictionary = VIEWS[_fly[seg]]
	var b: Dictionary = VIEWS[_fly[seg + 1]]
	var t := (a["t"] as Vector2).lerp(b["t"], u)
	var yaw := rad_to_deg(lerp_angle(deg_to_rad(float(a["yaw"])), deg_to_rad(float(b["yaw"])), u))
	var pitch := lerpf(float(a["pitch"]), float(b["pitch"]), u)
	# масштаб — по логарифму: перелёт «вверх и вниз» выглядит ровно
	var dist := exp(lerpf(log(float(a["dist"])), log(float(b["dist"])), u))
	g.rig.set_view(Vector3(t.x, land.height_at(t.x, t.y), t.y), yaw, pitch, dist)
	if not _fly_keep_hour:
		var h0 := float(a["hour"])
		var h1 := float(b["hour"])
		if h1 < h0 - 12.0:
			h1 += 24.0
		elif h1 > h0 + 12.0:
			h1 -= 24.0
		g._set_hour(fposmod(lerpf(h0, h1, u), 24.0))


## Поставить камеру на геройский вид (и его час, если with_hour)
func view(name: String, with_hour := true) -> void:
	var v: Dictionary = VIEWS[name]
	var t: Vector2 = v["t"]
	g.rig.set_view(Vector3(t.x, land.height_at(t.x, t.y), t.y), float(v["yaw"]), float(v["pitch"]), float(v["dist"]))
	if with_hour:
		g.clock_hours = false
		g._set_hour(float(v["hour"]))
