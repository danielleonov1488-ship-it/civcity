class_name NewShops
extends RefCounted
## Новые лавки (владелец 13.11: «пересобрать модельки» — новые здания из деталей Synty POLYGON Ancient Empire, а не
## украшенные прежние; «темноты вообще не должно быть»; у каждого здания своё основание, без голой земли). Собраны
## с нуля в метрах города (base делит на масштаб Catalog, тот потом умножает обратно), фасад к +Z, вход — b.door.
## Каждая лавка — римская таберна-дом, как в Помпеях и Остии: внизу открытая лавка с каменным прилавком под мраморной
## плитой и дверь со створками (Life), за ними — освещённая комната с полками товара (тёплое свечение, remap «glow»);
## над прилавком — полосатый навес цвета ремесла, у его края на верёвках висит товар; перед лавкой на мостовой
## основания — товар крупно (видно с верхней камеры); над входом — вывеска ремесла (рисунок CatDress.TRADE_SIGN)
## на стене второго этажа и на железном кронштейне поперёк стены. Наверху — жильё: окна со ставнями (Life) и ящиками
## цветов, или деревянный балкон с цветами и ковром, или (у глубоких лавок) терраса над лавкой с перголой и лозой,
## или (чаще у малых лавок) низкий чердак-мезонин с окошками. Сзади — дверь во двор и окошко, по бокам и сзади цоколь.
## Красильня — сушильня на столбах под черепицей с цветными тканями; фуллоника — ванна с чанами и терраса с бельём;
## термополий — Г-образная стойка с вделанными долиями, жаровня и столик со стульями; таверна — дом с баром и двор
## под перголой с лозой, столики, длинный стол со скамьями (места Life и вечера в таверне Spectacle).
## След каждой лавки — прежний (замер test_probe_lots по прежним сборкам, пересечение цветов 0, 3, 7): старые
## сохранения встают на свои клетки без OLD_LOT. Разнообразие: сторона двери, кровля фронтоном к улице или коньком
## вдоль, вид второго этажа, оттенок черепицы, цвет ставен и полос навеса — по цвету постройки (у владельца у всех
## лавок variant 0). Цоколь, поясок, дверь во двор, настил террасы, горшки на цепях — детали и раскраски прежних
## сборок города (общие группы MultiMesh: новых вызовов отрисовки не прибавляют). Кольцо глины вокруг лавок (City.apron_of)
## не трогаю — его заменяет линия домов в land.gd; у лавки — своё мощёное основание и мраморная ступень у двери.
## Прежние сборки (CatShops) остаются: ON — выключатели по типу (снимки «было/стало»); CIVCITY_NEWSHOPS=0 — прежние
## во всей игре.

const TYPES := ["butcher", "bakery", "cobbler", "dyer", "tailor", "potter", "oilshop", "lamps", "wineshop", "perfumer",
	"jeweler", "weaver", "barber", "medic", "thermopolium", "taberna", "fullonica"]
static var ON := _all(OS.get_environment("CIVCITY_NEWSHOPS") != "0")

## Прежний след в осях постройки (м): x0, x1, z0, z1 — внутри него лавка и собирается
const RECT := {
	"butcher": [-1.49, 1.41, -1.89, 1.21], "cobbler": [-1.49, 1.41, -1.89, 1.08], "weaver": [-1.49, 1.41, -1.89, 1.10],
	"barber": [-1.49, 1.41, -1.89, 1.21], "potter": [-1.49, 1.51, -1.89, 1.21], "dyer": [-1.41, 1.41, -1.98, 0.45],
	"bakery": [-1.41, 1.41, -3.78, 0.80], "tailor": [-1.41, 1.41, -2.79, 1.20], "perfumer": [-1.41, 1.41, -2.79, 1.20],
	"jeweler": [-1.41, 1.41, -2.79, 1.20], "oilshop": [-1.41, 1.41, -3.78, 1.15], "lamps": [-1.41, 1.41, -3.78, 1.15],
	"wineshop": [-1.41, 1.41, -3.78, 1.15], "medic": [-1.41, 1.41, -3.78, 1.15],
	"thermopolium": [-2.09, 2.17, -1.89, 1.31], "taberna": [-2.09, 2.15, -3.69, 1.67], "fullonica": [-2.09, 2.09, -1.89, 1.26],
}
## Цвет полос навеса и знамени по ремеслу (атлас полотна CatShops.CLOTH): мясник — красный, гончар — горчичный…
const TRADE_COL := {"butcher": CatShops.RED, "potter": CatShops.MUSTARD, "barber": CatShops.BLUE, "cobbler": CatShops.ORANGE,
	"weaver": CatShops.PURPLE, "dyer": CatShops.MAGENTA, "bakery": CatShops.MUSTARD, "wineshop": CatShops.PURPLE,
	"oilshop": CatShops.GREEN, "lamps": CatShops.ORANGE, "medic": CatShops.SAGE, "perfumer": CatShops.PINK,
	"jeweler": CatShops.BLUE, "tailor": CatShops.PURPLE, "thermopolium": CatShops.RED, "taberna": CatShops.GREEN,
	"fullonica": CatShops.SKY}

const Y0 := 0.04                  # верх мощёного основания (у двора таверны стоят у жаровни: земля не выше 0,05)
const AY := 0.052                 # люди при деле — на плитах основания (ниже 0,05 их ставит на землю People)
const H1 := 2.15                  # первый этаж
const E := 0.12                   # пояс между этажами
const H2 := 1.5                   # второй этаж
const WD := 1.12                  # модуль двери в фасаде (остальное — открытая лавка)
const WARM := NewSmall.WARM
const GLOW := {"glow": NewSmall.WARM * 0.4}
const GLOW2 := {"glow": NewSmall.WARM * 0.6}
const SHUT := ["#shutters_green", "#shutters_blue", "#shutters_brown"]
## Малые лавки (2,9 × 3,1 м): у них чаще низкий чердак вместо полного второго этажа
const SMALL := ["butcher", "cobbler", "weaver", "barber", "potter"]
const HL := 1.02                  # чердак над лавкой
const MEAT := {"tint": CatShops.T_MEAT}
const ST2 := {"Stucco_White_01": "Stucco_White_01", "Stucco_Orange_01": "Stucco_White_01", "Stucco_Red_01": "Stucco_White_01",
	"Stucco_Blue_01": "Stucco_White_01", "Roof_Tile_01": "Roof_Tile_01"}
const BREAD := {"tint": CatShops.T_BREAD}
const OLIVE := {"tint": CatShops.T_OLIVE}
const GILT := {"tint": Color(1.0, 0.8, 0.35)}
const LEATHER := {"PolygonAncientEmpire_01_A": "PolygonAncientEmpire_02_A"}


## Раскраска прежних сборок (ST2) с оттенком c — общая группа деталей с ними
static func _st2(c: Color) -> Dictionary:
	var d := ST2.duplicate()
	d["tints"] = {"Stucco_White_01": c}
	return d


static func _all(v: bool) -> Dictionary:
	var d := {}
	for t: String in TYPES:
		d[t] = v
	return d


static func covers(type: String) -> bool:
	return bool(ON.get(type, false))


static func build(b: Bp, type: String, variant := 0, color := 0) -> void:
	var K := Catalog.scale_of(type)
	b.base = Transform3D(Basis.from_scale(Vector3.ONE / K), Vector3.ZERO)
	var o: Array = RECT[type]
	var fr := [float(o[0]) + 0.02, float(o[1]) - 0.02, float(o[2]) + 0.02, float(o[3]) - 0.02]
	var L := TYPES.find(type)
	var pal := posmod(color, Defs.PALETTE.size())
	var x := NewSmall._ctx(b, 0)
	x["c"] = color
	x["pal"] = pal
	x["type"] = type
	x["L"] = L
	# облик по цвету постройки и фасаду: соседние лавки одного ремесла — разные
	x["m"] = 1.0 if (pal + variant + L) % 2 == 0 else -1.0                 # дверь слева (лавка справа) или наоборот
	x["rz"] = (floori(pal / 2.0) + variant + L) % 2 == 0                   # кровля фронтоном к улице
	x["up"] = (pal + 2 * variant + L) % 3                                  # окна / балкон / терраса
	if type in SMALL and (pal + variant + L) % 3 != 1:
		x["up"] = 3                                                        # малые лавки: чаще низкий чердак
	x["shut"] = SHUT[(pal + L) % 3]
	x["col"] = int(TRADE_COL.get(type, CatShops.RED))
	x["col2"] = [CatShops.WHITE, CatShops.ACCENT[pal], CatShops.WHITE][(pal + L) % 3]
	if int(x["col2"]) == int(x["col"]):
		x["col2"] = CatShops.WHITE
	x["leaf"] = NewSmall.LEAF_WOOD
	var door := Vector3.ZERO
	match type:
		"thermopolium": door = _thermopolium(b, fr, x)
		"taberna": door = _taberna(b, fr, x)
		"fullonica": door = _fullonica(b, fr, x)
		"dyer": door = _dyer(b, fr, x)
		_: door = _shop(b, type, fr, x)
	b.base = Transform3D.IDENTITY
	b.door = door / K


# =====================================================================
#   помощники (метры города, фасад к +Z)
# =====================================================================

static func _p(b: Bp, name: String, p: Vector3, yaw := 0.0, s := Vector3.ONE, rm := {}) -> void:
	if name.begins_with("#hp_"):
		b.free_parts[b.parts.size()] = true      # вещицы HandProps: у Bp.model_aabb они — кубик 1 м, след раздули бы
	NewSmall._p(b, name, p, yaw, s, rm)


static func _u(b: Bp, name: String, p: Vector3, yaw: float, s: float, rm := {}) -> void:
	_p(b, name, p, yaw, Vector3.ONE * s, rm)


## Товар лавки — крупнее мелочей убранства (GS): ремесло узнаётся с верхней камеры
const GS := 1.3
static func _g(b: Bp, name: String, p: Vector3, yaw: float, s: float, rm := {}) -> void:
	_p(b, name, p, yaw, Vector3.ONE * s * GS, rm)


## Следующая деталь землю не занимает (навес, вывеска, верёвки)
static func _free(b: Bp) -> void:
	b.free_parts[b.parts.size()] = true


## Своё основание: плиты травертина по всему следу, по краю — бордюр из тёсаного камня, уходящий в землю
static func _base(b: Bp, x0: float, x1: float, z0: float, z1: float) -> void:
	NewCivic._floor(b, NewSmall.PAVING, x0, z0, x1, z1, Y0, 2.1)
	var e := 0.055
	NewCivic._ring(b, "SM_Bld_Wall_Large_01", x0 + e, x1 - e, z0 + e, z1 - e, -0.45, 5.0, (Y0 + 0.47) / 4.51, 0.16, {}, [0, 1, 2, 3], 2.1)


## Ступень у двери: мраморная плита перед порогом
static func _step(b: Bp, cx: float, z: float, w := 0.78) -> void:
	_p(b, "SM_Bld_Wall_Large_Cap_01", Vector3(cx - w * 0.5, Y0 - 0.012, z + 0.15), 0.0, Vector3(w / 5.02, 0.09 / 0.36, 0.3 / 0.9))


## Полосатый навес (CatDress «#dress:awning»: провис, подзор с зубцами): от стены (zb, высота yb) к краю (zf, yf)
static func _awning(b: Bp, xa: float, xb: float, zb: float, zf: float, yb: float, yf: float, ca: int, cb: int) -> void:
	var n := maxi(3, int(round((xb - xa) / 0.36)))
	_free(b)
	_p(b, "#dress:awning:%d:%d:%d" % [n, posmod(ca, CatShops.CLOTH.size()), posmod(cb, CatShops.CLOTH.size())],
		Vector3(xa, yb, zb), 0.0, Vector3(xb - xa, yb - yf, zf - zb))


## Товар на верёвках вдоль края навеса: items — [деталь, масштаб, раскраска?]
static func _hang(b: Bp, xa: float, xb: float, z: float, y: float, items: Array) -> void:
	var n := items.size()
	for k in n:
		var e: Array = items[k]
		var hx := lerpf(xa, xb, (k + 0.5) / n)
		var ln: float = [0.12, 0.22, 0.16, 0.26][k % 4]
		var top := Vector3(hx, y, z)
		_free(b)
		_p(b, "#dress:cord", top, 0.0, Vector3(1.0, ln, 1.0))
		var nm := String(e[0])
		var s: Vector3 = e[1] if e[1] is Vector3 else Vector3.ONE * float(e[1])
		var hang := 0.0
		if not nm.begins_with("#"):
			hang = Bp.model_aabb(nm).end.y * s.y         # вещь Synty — за верх (кувшин за горлышко)
		_free(b)
		_p(b, nm, top - Vector3(0, ln + hang, 0), k * 1.3 if not nm.begins_with("SM_Prop_Rug") else 0.0, s, e[2] if e.size() > 2 else {})


## Вывеска ремесла на стене (рисунок signs.png, CatDress.TRADE_SIGN): доска 1,08 × 0,74 × s, лицом к +Z
static func _sign(b: Bp, type: String, p: Vector3, s := 0.62) -> void:
	_free(b)
	_p(b, "#sign:" + String(CatDress.TRADE_SIGN.get(type, "thermo")), p, 0.0, Vector3(s, s, 1.0))


## Вывеска на железном кронштейне поперёк стены фасада (видна вдоль улицы): p — точка крепления на лице стены
static func _bsign(b: Bp, type: String, p: Vector3, s := 0.6) -> void:
	_free(b)
	_p(b, "#bsign:" + String(CatDress.TRADE_SIGN.get(type, "thermo")), p, 0.0, Vector3.ONE * s)


## Цветная ткань с перекладины: середина верхнего края p, ширина w, длина h, цвет полотна (атлас CLOTH)
static func _sheet(b: Bp, p: Vector3, w: float, h: float, col: int, yaw := 0.0) -> void:
	var bs := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI / 2) * Basis.from_scale(Vector3(w / 2.6, 0.25, h / 2.6))
	_free(b)
	b.parts.append(["SM_Prop_Banner_Roof_01", b.base * Transform3D(bs, p + Vector3(-w / 2.0, 0, 0).rotated(Vector3.UP, yaw)), CatShops._cloth(col)])


## Перекладина на двух столбах вдоль X (от xa до xb на высоте y, в z)
static func _rail(b: Bp, xa: float, xb: float, z: float, y0: float, y: float, poles := true) -> void:
	if poles:
		for xx: float in [xa, xb]:
			_p(b, "SM_Prop_Pole_01", Vector3(xx, y0, z), 0.0, Vector3(0.45, (y - y0) / 3.0, 0.45))
	_p(b, "SM_Prop_Beam_01", Vector3(xa, y, z), 0.0, Vector3((xb - xa) / 2.5, 0.55, 0.55))


## Чан с краской или водой: глиняная чаша, в ней «жидкость» — плоское полотно цвета col
static func _vat(b: Bp, p: Vector3, col: int, s := 0.32) -> void:
	_p(b, "SM_Prop_Bowl_02", p, 0.0, Vector3(0.75, 1.6, 0.75) * s)
	_p(b, "SM_Prop_Banner_Roof_01", p + Vector3(-0.29 * s, 0.46 * s, -0.29 * s), 0.0, Vector3(0.22 * s, 0.03, 0.22 * s), CatShops._cloth(col))


## Корзина с товаром: bread, fish — плоская с хлебами; olives, apples, plums — круглая
static func _basket(b: Bp, p: Vector3, kind: String, s := 0.3, yaw := 0.0) -> void:
	match kind:
		"bread":
			_u(b, "SM_Prop_Basket_Set_06", p, yaw, s)
			_u(b, "SM_Prop_Basket_Set_06_Insert_01", p, yaw, s, BREAD)
		_:
			_u(b, "SM_Prop_Basket_11", p, yaw, s)
			var tn: Dictionary = {"olives": OLIVE, "apples": {"tint": CatShops.T_APPLE}, "plums": {"tint": CatShops.T_GRAPE}}.get(kind, {})
			_u(b, "SM_Prop_Basket_Insert_03", p + Vector3(0, 0.12 * s, 0), yaw, s, tn)


## Горшок с цветами / кустик
static func _pot(b: Bp, p: Vector3, s := 0.26) -> void:
	NewSmall._pot(b, p, s)


## Лампа на кронштейне у двери (ночью светится)
static func _lamp(b: Bp, p: Vector3) -> void:
	_free(b)
	_p(b, "#wall_lamp", p, 0.0, Vector3.ONE * 0.8)


# =====================================================================
#   фасад, этажи, кровля
# =====================================================================

## Первый этаж спереди: дверь со створками (Life) шириной WD с одной стороны (m > 0 — слева), открытая лавка
## с прилавком — остальное. Возвращает {dcx — середина двери, ox0/ox1 — модуль лавки, gaps — проёмы для облицовки}
static func _front(b: Bp, r: Array, y: float, h: float, x: Dictionary, m: float, wd := WD, ww := 0.0) -> Dictionary:
	var xa: float = r[0]
	var xb: float = r[1]
	var rd := [xa, xa + wd, r[2], r[3]] if m > 0 else [xb - wd, xb, r[2], r[3]]
	var ro := [xa + wd + ww, xb, r[2], r[3]] if m > 0 else [xa, xb - wd - ww, r[2], r[3]]
	if ww > 0.0:
		# между дверью и лавкой — окно со ставнями (Life)
		NewSmall._storey(b, [xa + wd, xa + wd + ww, r[2], r[3]] if m > 0 else [xb - wd - ww, xb - wd, r[2], r[3]], {0: "S"}, y, h, x)
	var resd := NewSmall._storey(b, rd, {0: "D"}, y, h, x)
	var reso := NewSmall._storey(b, ro, {0: "O"}, y, h, x)
	var d: Array = resd["D"][0]
	var gaps := NewSmall._gaps(rd, resd) + NewSmall._gaps(ro, reso)
	gaps.sort_custom(func(g0: Array, g1: Array) -> bool: return float(g0[0]) < float(g1[0]))    # облицовка — слева направо
	return {"dcx": float(rd[0]) + float(d[1]) + float(d[2]) * 0.5, "ox0": float(ro[0]), "ox1": float(ro[1]), "gaps": gaps}


## Цоколь по бокам и сзади: полоса чуть темнее стены (деталь прежних сборок, общая группа)
static func _socle(b: Bp, r: Array, t: Color, sides := [1, 2, 3]) -> void:
	for side: int in sides:
		NewSmall._run(b, "SM_Bld_Trim_05", r, side, Y0, -0.11, 2.5, 0.34 / 0.5, 0.55, _st2(t.darkened(0.18)), 1.8)


## Пояс между этажами (полоса стены цвета постройки и белый карниз) по прямоугольнику r на высоте y
static func _band(b: Bp, r: Array, y: float, x: Dictionary, sides := [0, 1, 2, 3]) -> void:
	for side: int in sides:
		NewSmall._run(b, "SM_Bld_Wall_01", r, side, y, -0.11 * 0.6, 2.5, E / 3.01, 0.6, x["st"], 1.8)
	NewSmall._cornice(b, r, y - 0.02, E + 0.02, 0.07, sides)


## Кровля над прямоугольником r с высоты y: фронтоном к улице (медальон в тимпане, навершие) или коньком вдоль
static func _roof(b: Bp, r: Array, y: float, x: Dictionary) -> float:
	var pal: int = x["pal"]
	var xc := (float(r[0]) + float(r[1])) * 0.5
	var i0 := b.parts.size()
	var ridge := 0.0
	if bool(x["rz"]):
		var tym: Dictionary = NewSmall.TYMPANUM if pal % 2 == 0 else NewSmall.TYM_RED
		ridge = NewSmall._roof(b, r, y, true, tym, 0.13)
		_u(b, ["SM_Bld_Ornament_02", "SM_Bld_Ornament_06", "SM_Bld_Ornament_01"][pal % 3], Vector3(xc, y + (ridge - y) * 0.3, float(r[3]) + 0.15), 0.0, 0.26)
	else:
		ridge = NewSmall._roof(b, r, y, false, NewSmall.TYM_RED if pal % 2 == 0 else NewSmall.TYMPANUM, 0.13)
	# черепица — один из трёх терракотовых оттенков (по цвету постройки): соседние крыши различаются
	var tile: String = CatShops.TILES[(pal + int(x.get("L", 0))) % CatShops.TILES.size()]
	if tile != "Roof_Tile_01":
		for i in range(i0, b.parts.size()):
			if String(b.parts[i][0]).begins_with("SM_Bld_Roof_Straight"):
				var rm: Dictionary = (b.parts[i][2] as Dictionary).duplicate()
				rm["Roof_Tile_01"] = tile
				b.parts[i][2] = rm
	return ridge


## Дом-лавка: r — коробка стен; рисует этажи, кровлю, нутро; возвращает сведения для товара
## up: 0 — окна со ставнями и цветами, 1 — деревянный балкон, 2 — верх отступает, над лавкой терраса с перголой,
## 3 — низкий чердак (окошки, вывеска на простенке)
static func _house(b: Bp, type: String, r: Array, x: Dictionary, up: int) -> Dictionary:
	var m: float = x["m"]
	var pal: int = x["pal"]
	var hd := float(r[3]) - float(r[2])
	var y2 := Y0 + H1 + E
	var h2 := HL if up == 3 else H2
	var ytop := y2 + h2
	var sb := 1.05 if up == 2 else 0.0
	var r2 := [r[0], r[1], r[2], float(r[3]) - sb]
	var f := _front(b, r, Y0, H1, x, m)
	# бока и зад первого этажа: окна в тёплые комнаты (со ставнями — Life), гладкий модуль — под плющ
	var ns := 1 if hd < 2.3 else 2
	var g1 := {1: "S" if ns == 1 else ("NS" if m > 0 else "SN"), 3: "S" if ns == 1 else ("SW" if m > 0 else "WS")}
	var res1 := NewSmall._storey(b, r, g1, Y0, H1, x)
	var t: Color = x["t"]
	NewSmall._storey(b, r, {2: "ML" if m > 0 else "LM"}, Y0, H1, x, {}, _st2(t))          # сзади — дверь во двор и окошко
	_socle(b, r, t)
	_band(b, r, Y0 + H1, x)
	# второй этаж: над дверью окно, над лавкой — гладкий простенок с вывеской (или дверь на балкон)
	var win := "B" if pal % 3 == 0 else "S"
	var front2 := (win + "W") if m > 0 else ("W" + win)
	if up == 1:
		front2 = "LW" if m > 0 else "WL"
	elif up == 2:
		front2 = "SS" if pal % 2 == 0 else "BB"
	elif up == 3:
		front2 = "TW" if m > 0 else "WT"
	var hd2 := float(r2[3]) - float(r2[2])
	var ns2 := 1 if hd2 < 2.3 else 2
	var g2 := {0: front2, 1: "S" if ns2 == 1 else "WS", 2: "SN" if m > 0 else "NS", 3: "S" if ns2 == 1 else "SW"}
	# сзади под окнами второго этажа — светлый поясок-подоконник
	NewSmall._run(b, "SM_Bld_Trim_02", r2, 2, y2 + 0.02, -0.11, 2.5, 0.6, 0.8, _st2(t.lightened(0.45)), 1.8)
	if up == 3:
		g2 = {0: front2, 1: "T", 2: "TT", 3: "T"}
	var res2 := NewSmall._storey(b, r2, g2, y2, h2, x)
	NewSmall._pilasters(b, r, {0: 1, 1: 1, 2: 2, 3: 1}, Y0, H1 + E)
	NewSmall._pilasters(b, r2, {0: 1, 1: 1, 2: 2, 3: 1}, y2, h2, 0.17)
	if up != 3:
		NewSmall._frieze(b, r2, ytop - 0.2)
	NewSmall._cornice(b, r2, ytop - 0.03, 0.16, 0.08)
	for e: Array in res1["W"]:
		NewSmall._ivy(b, r, e, Y0, H1, pal + int(e[0]))
	for e: Array in res2["W"]:
		if int(e[0]) != 0:
			NewSmall._ivy(b, r2, e, y2, h2, pal + int(e[0]))
	var ridge := _roof(b, r2, ytop + 0.08, x)
	# нутро в тёплом свете: внизу лавка (через проём и дверь), наверху жильё (через окна)
	var ir := NewSmall._inner(r, 0.3)
	if up == 2:
		NewSmall._hall(b, ir, Y0, H1 - 0.04, f["gaps"])
		NewSmall._hall(b, NewSmall._inner(r2, 0.3), y2 - 0.02, H2 - 0.06, [])
	else:
		NewSmall._hall(b, ir, Y0, ytop - Y0 - 0.08, f["gaps"])
	b.light(Vector3((float(ir[0]) + float(ir[1])) * 0.5, Y0 + 1.6, (float(ir[2]) + float(ir[3])) * 0.5))
	var fz: float = r[3]
	var dcx: float = f["dcx"]
	var ox0: float = f["ox0"]
	var ox1: float = f["ox1"]
	# над дверью — черепичный козырёк, сбоку — фонарь; у порога — мраморная ступень
	_p(b, "SM_Prop_Overhang_01", Vector3(dcx, Y0 + H1 - 0.2, fz + 0.01), 0.0, Vector3(0.36, 0.7, 0.62))
	_lamp(b, Vector3(dcx - m * 0.48, Y0 + 1.55, fz + 0.02))
	_step(b, dcx, fz)
	# вывеска ремесла: на простенке второго этажа над лавкой; при террасе — на стене над перголой
	var scx := (ox0 + ox1) * 0.5
	var sz := float(r2[3])
	match up:
		0: _sign(b, type, Vector3(scx, y2 + H2 * 0.5, sz + 0.03), 0.6)
		1: _sign(b, type, Vector3(scx, y2 + H2 * 0.56, sz + 0.03), 0.56)
		3: _sign(b, type, Vector3(scx, y2 + HL * 0.5, sz + 0.03), 0.62)
		_: _sign(b, type, Vector3((float(r[0]) + float(r[1])) * 0.5, Y0 + H1 + 0.32, fz + 0.06), 0.5)
	# и на кронштейне у угла второго этажа над дверью (над навесом, видна вдоль улицы)
	_bsign(b, type, Vector3(float(r[0]) + 0.12 if m > 0 else float(r[1]) - 0.12, ytop - 0.16, sz + 0.02), 0.58)
	match up:
		1: _balcony(b, r, y2, x)
		2: _terrace(b, r, r2, x)
		3:
			_free(b)
			_u(b, "SM_Prop_FlowerPot_Hanging_0%d" % (4 + pal % 3), Vector3(dcx, ytop - 0.08, sz + 0.12), 0.0, 0.3)
	return {"f": f, "ir": ir, "fz": fz, "dcx": dcx, "ox0": ox0, "ox1": ox1, "y2": y2, "ytop": ytop, "ridge": ridge, "r2": r2, "up": up}


## Деревянный балкон во всю ширину второго этажа: настил, перила, цветы в кашпо, ковёр на перилах
static func _balcony(b: Bp, r: Array, y2: float, x: Dictionary) -> void:
	var pal: int = x["pal"]
	var xa := float(r[0]) - 0.02
	var xb := float(r[1]) + 0.02
	var fz: float = r[3]
	var dep := 0.42
	_free(b)
	NewCivic._floor(b, NewSmall.WOOD, xa, fz, xb, fz + dep, y2 - 0.02, 2.0)
	# опоры — балки из стены
	for xx: float in [xa + 0.15, xb - 0.15]:
		_free(b)
		_p(b, "SM_Prop_Beam_01", Vector3(xx, y2 - 0.08, fz - 0.05), -PI / 2, Vector3((dep + 0.05) / 2.5, 0.8, 0.8))
	var pr := [xa, xb, fz, fz + dep]
	for side: int in [0, 1, 3]:
		_free(b)
		NewSmall._run(b, "SM_Bld_Wall_Balcony_03", pr, side, y2 - 0.02, -0.04, 2.5, 0.48, 0.5, {}, 2.0, 0.0, -1.0)
	# у части балконов — ковёр, переброшенный через перила; цветы в подвесных кашпо по краям
	if pal % 2 == 1:
		_free(b)
		_u(b, "SM_Prop_Rug_Drape_01", Vector3((xa + xb) * 0.5 + 0.3, y2 + 0.42, fz + dep + 0.02), PI, 0.36, CatShops._rug(["01_B", "03_A", "01_C"][pal % 3]))
	for xx: float in [xa + 0.5, xb - 0.5]:
		_free(b)
		_u(b, "SM_Prop_FlowerPot_Hanging_0%d" % (4 + (pal + int(xx > 0.0)) % 3), Vector3(xx, y2 + 0.98, fz + dep - 0.06), 0.0, 0.34)


## Терраса над передней частью лавки (верх отступает): настил, белые перила, пергола с лозой, горшки, бельё
static func _terrace(b: Bp, r: Array, r2: Array, x: Dictionary) -> void:
	var pal: int = x["pal"]
	var yt := Y0 + H1 + E
	var tz0: float = r2[3]
	var tz1: float = r[3]
	_flat(b, float(r[0]), float(r[1]), tz0, tz1, yt)
	var pr := [float(r[0]) + 0.02, float(r[1]) - 0.02, tz0, tz1 - 0.02]
	for side: int in [0, 1, 3]:
		NewSmall._run(b, "SM_Bld_Wall_Balcony_04", pr, side, yt - 0.01, -0.03, 2.5, 0.42, 0.55, {}, 2.0)
	# пергола: два столбика у переднего края, рейки к стене верхнего этажа, лоза поверх
	var ph := 1.3
	var px0 := float(r[0]) + 0.12
	var px1 := float(r[1]) - 0.12
	for xx: float in [px0, px1]:
		_p(b, "SM_Bld_Pillar_06", Vector3(xx, yt, tz1 - 0.12), 0.0, Vector3(0.16, ph / 3.0, 0.16))
	_p(b, "SM_Prop_Beam_01", Vector3(px0 - 0.06, yt + ph, tz1 - 0.12), 0.0, Vector3((px1 - px0 + 0.12) / 2.5, 0.55, 0.55))
	_p(b, "SM_Bld_Trellis_Roof_Large_02", Vector3(px0, yt + ph + 0.02, tz0 + 0.02), 0.0, Vector3((px1 - px0) / 7.5, 0.5, (tz1 - tz0 - 0.1) / 5.0))
	for k in 2:
		var vx := lerpf(px0 + 0.45, px1 - 0.45, float(k))
		b.parts.append(["SM_Env_Vine_0%d" % (1 + (pal + k) % 3), b.base * Transform3D(Basis(Vector3.UP, 0.0 if k == 0 else PI) * Basis(Vector3.RIGHT, -PI / 2) * Basis.from_scale(Vector3(0.42, 0.4, 0.4)),
			Vector3(vx, yt + ph + 0.1, (tz0 + tz1) * 0.5)), {}])
	_u(b, "SM_Env_Ivy_Pillar_Flowers_0%d" % (1 + pal % 2), Vector3(px1 if pal % 2 == 0 else px0, yt, tz1 - 0.12), 0.0, 0.42)
	# горшки с цветами и скамейка на террасе
	_pot(b, Vector3(px0 + 0.15, yt, tz0 + 0.25), 0.22)
	_pot(b, Vector3(px1 - 0.2, yt, tz0 + 0.3), 0.2)
	_p(b, "SM_Prop_Seat_Bench_01", Vector3((px0 + px1) * 0.5, yt, tz0 + 0.18), 0.0, Vector3(0.36, 0.42, 0.42))


## Плоская кровля-настил террасы (SM_Bld_Roof_Base_Flat_02: плита 2,5 × 2,5 на высоте 0,68–0,75) — верх на y
static func _flat(b: Bp, xa: float, xb: float, za: float, zb: float, y: float) -> void:
	var n := maxi(1, int(ceil((xb - xa) / 2.5 - 0.01)))
	var w := (xb - xa) / n
	for i in n:
		_p(b, "SM_Bld_Roof_Base_Flat_02", Vector3(xa + i * w, y - 0.75, zb), 0.0, Vector3(w / 2.5, 1.0, (zb - za) / 2.5))


## Полки с товаром у задней стены нутра: it — до четырёх [деталь, масштаб, раскраска?] (два внизу, два наверху)
static func _shelf(b: Bp, ir: Array, it: Array, k := 0) -> void:
	var w := minf(1.9, float(ir[1]) - float(ir[0]) - 0.2)
	var c := Vector3((float(ir[0]) + float(ir[1])) * 0.5, Y0, float(ir[2]) + 0.2)
	var sy := 1.25 / 1.86
	_p(b, "SM_Prop_Shelf_0%d" % (1 + posmod(k, 2)), c, 0.0, Vector3(w / 2.5, sy, 0.42), GLOW)
	for j in mini(it.size(), 6):
		var e: Array = it[j]
		var per := 3 if it.size() > 4 else 2
		var row := floori(j / float(per))
		var col := j % per
		var px := c.x + (col - (per - 1) * 0.5) * w / (per + 0.3)
		var py: float = Y0 + float([0.62, 1.04][row]) * sy / 0.672
		var rm: Dictionary = e[2] if e.size() > 2 else {}
		rm = rm.duplicate()
		rm["glow"] = WARM * 0.4
		_u(b, String(e[0]), Vector3(px, py, c.z), j * 0.7, float(e[1]), rm)


# =====================================================================
#   лавка-дом (мясник, пекарня, сапожник, портной, гончар, масло, лампы, вино, благовония, ювелир, ткач,
#   цирюльник, лекарь)
# =====================================================================

static func _shop(b: Bp, type: String, fr: Array, x: Dictionary) -> Vector3:
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	var D := z1 - z0
	var m: float = x["m"]
	var pal: int = x["pal"]
	_base(b, x0, x1, z0, z1)
	var fs := clampf(D * 0.25, 0.62, 1.3)                         # мостовая перед лавкой — товар крупно
	var r := [x0 + 0.08, x1 - 0.08, z0 + 0.1, z1 - fs]
	var up: int = x["up"]
	if up == 2 and float(r[3]) - float(r[2]) < 2.6:
		up = pal % 2                                              # террасе нужна глубокая лавка
	var h := _house(b, type, r, x, up)
	var fz: float = h["fz"]
	var ox0: float = h["ox0"]
	var ox1: float = h["ox1"]
	var dcx: float = h["dcx"]
	var ir: Array = h["ir"]
	# навес над прилавком: от стены под поясом к краю над мостовой; у широкой мостовой — на двух столбиках
	var aw := clampf(fs - 0.12, 0.45, 0.8)
	var yb := Y0 + H1 - 0.06
	var yf := yb - 0.36
	_awning(b, ox0 + 0.02, ox1 - 0.02, fz + 0.02, fz + aw, yb, yf, int(x["col"]), int(x["col2"]))
	if fs > 0.78:
		for xx: float in [ox0 + 0.08, ox1 - 0.08]:
			_p(b, "SM_Prop_Pole_01", Vector3(xx, Y0, fz + aw - 0.06), 0.0, Vector3(0.42, (yf - Y0) / 3.0, 0.42))
	var c := {"type": type, "fz": fz, "z1": z1, "ox0": ox0, "ox1": ox1, "ocx": (ox0 + ox1) * 0.5, "dcx": dcx, "m": m, "pal": pal,
		"ir": ir, "ct": Y0 + 0.545, "hz": fz + aw - 0.05, "hy": yf + 0.02, "x0": x0, "x1": x1, "fs": fs, "x": x}
	_goods(b, type, c)
	# кадка у угла мостовой со стороны двери (если есть место), куст у заднего угла
	var px := x0 + 0.2 if m > 0 else x1 - 0.2
	if absf(px - dcx) > 0.55 and fs > 0.7:
		_pot(b, Vector3(px, Y0, z1 - 0.2), 0.22)
	NewSmall._bush(b, Vector3(x1 - 0.22 if m > 0 else x0 + 0.22, Y0, z0 + 0.25), 0.16)
	return Vector3(dcx, 0, z1 + 0.35)


## Товар ремесла: на прилавке, на мостовой перед ним (крупно — видно сверху), на верёвках у края навеса, на полках нутра,
## и человек при деле за прилавком (первое место — работника лавки, Catalog._actors прежних лавок)
static func _goods(b: Bp, type: String, c: Dictionary) -> void:
	var fz: float = c["fz"]
	var z1: float = c["z1"]
	var ox0: float = c["ox0"]
	var ox1: float = c["ox1"]
	var ocx: float = c["ocx"]
	var dcx: float = c["dcx"]
	var m: float = c["m"]
	var pal: int = c["pal"]
	var ir: Array = c["ir"]
	var ct: float = c["ct"]
	var hz: float = c["hz"]
	var hy: float = c["hy"]
	var ow := ox1 - ox0
	var cz := fz + 0.03                                  # середина столешницы прилавка
	var gz := minf(z1 - 0.22, fz + 0.42)                 # товар на мостовой перед прилавком
	var oa := ox0 + 0.32                                 # края проёма лавки
	var ob := ox1 - 0.32
	var ou := ox1 - 0.2 if m > 0 else ox0 + 0.2          # дальний от двери край мостовой
	var worker := Vector3(ocx, AY, fz - 0.42)
	match type:
		"butcher":
			# окорока и колбасы на верёвках у края навеса, на прилавке — куски мяса на блюдах, колода с тесаком на мостовой
			_hang(b, ox0 + 0.12, ox1 - 0.12, hz, hy, [["#hp_ham", 0.36], ["SM_Prop_Sack_03", Vector3(0.12, 0.42, 0.13), {"tint": Color(0.6, 0.27, 0.2)}],
				["#hp_ham", 0.32], ["SM_Prop_Sack_03", Vector3(0.12, 0.4, 0.13), {"tint": Color(0.6, 0.27, 0.2)}], ["#hp_ham", 0.36]])
			_g(b, "SM_Prop_Plate_02", Vector3(oa + 0.12, ct, cz), 0.0, 0.6)
			_g(b, "SM_Prop_Basket_Insert_04", Vector3(oa + 0.12, ct + 0.02, cz), 0.3, 0.42, MEAT)
			_g(b, "SM_Prop_Basket_Insert_04", Vector3(ocx + 0.05, ct, cz + 0.02), -0.4, 0.36, MEAT)
			_g(b, "SM_Prop_Jug_05", Vector3(ob - 0.08, ct, cz), 0.0, 0.5)
			_g(b, "SM_Prop_Stool_01", Vector3(ou - 0.1 * m, Y0, gz), 0.5, 0.62, {"tint": Color(0.75, 0.55, 0.4)})
			_g(b, "SM_Prop_Basket_Insert_04", Vector3(ou - 0.1 * m, Y0 + 0.27, gz), 1.2, 0.32, MEAT)
			_g(b, "SM_Prop_Tool_Hammer_01", Vector3(ou - 0.04 * m, Y0 + 0.285, gz + 0.06), 0.9, 0.9)
			_g(b, "SM_Prop_Jar_Pile_01", Vector3(ocx - 0.25 * m, Y0, gz + 0.02), 0.0, 0.26)
			# нутро: окорока на балке, полка с горшками соли и кувшинами
			_p(b, "SM_Prop_Beam_01", Vector3(float(ir[0]) + 0.1, Y0 + 1.75, float(ir[2]) + 0.55), 0.0, Vector3((float(ir[1]) - float(ir[0]) - 0.2) / 2.5, 0.5, 0.5), GLOW)
			for k in 3:
				_g(b, "#hp_ham", Vector3(lerpf(float(ir[0]) + 0.35, float(ir[1]) - 0.35, k / 2.0), Y0 + 1.55, float(ir[2]) + 0.55), k * 1.1, 0.34)
			_shelf(b, ir, [["SM_Prop_Jar_01", 0.32], ["SM_Prop_Jug_02", 0.3], ["SM_Prop_Jug_05", 0.45], ["SM_Prop_Plate_01", 0.38]], pal)
			b.actor(worker, 0.0, "Interact", "any")
		"bakery":
			# хлебы в корзинах на прилавке и на столике у входа, мешки муки, жёрнов на мостовой; в глубине — печь с огнём
			for k in 3:
				_basket(b, Vector3(lerpf(oa + 0.05, ob - 0.05, k / 2.0), ct, cz), "bread", 0.24, k * 0.8)
			_p(b, "SM_Prop_Table_04", Vector3(ocx + 0.15 * m, Y0, gz + 0.08), 0.0, Vector3(0.5, 0.62, 0.5))
			_basket(b, Vector3(ocx + 0.15 * m, Y0 + 0.48, gz + 0.08), "bread", 0.28, 0.4)
			_g(b, "SM_Prop_Grinding_Wheel_01", Vector3(ou - 0.05 * m, Y0 + 0.13, gz + 0.1), 0.0, 0.34)
			_g(b, "SM_Prop_Sack_Stack_01", Vector3(ou - 0.1 * m, Y0, minf(z1 - 0.2, gz + 0.48)), 0.2, 0.26)
			var kx := (float(ir[0]) + float(ir[1])) * 0.5
			_g(b, "SM_Prop_Kiln_01", Vector3(kx, Y0, float(ir[2]) + 0.42), 0.0, 0.32, GLOW)
			NewSmall._fire(b, Vector3(kx, Y0 + 0.12, float(ir[2]) + 0.72), 2.2)
			b.light(Vector3(kx, Y0 + 0.5, float(ir[2]) + 0.9))
			_g(b, "SM_Prop_Sack_04", Vector3(float(ir[1]) - 0.3, Y0, float(ir[2]) + 0.35), 0.4, 0.4, GLOW)
			_g(b, "SM_Prop_Basket_Set_06", Vector3(float(ir[0]) + 0.3, Y0, float(ir[2]) + 0.35), 0.4, 0.28, GLOW)
			_hang(b, ox0 + 0.15, ox1 - 0.15, hz, hy, [["#dress:herbs", 0.55], ["SM_Prop_Basket_06", 0.3], ["#dress:herbs", 0.5]])
			b.actor(worker, 0.0, "Interact", "pleb")
		"cobbler":
			# сандалии на верёвках, кожи на прилавке, корзины с обувью, колодка и табурет на мостовой
			_hang(b, ox0 + 0.1, ox1 - 0.1, hz, hy, [["#hp_sandals", 0.55], ["#hp_sandals", 0.5], ["#hp_sandals", 0.55], ["#hp_sandals", 0.5]])
			_g(b, "SM_Prop_Rug_Folded_03", Vector3(oa + 0.12, ct, cz), 0.2, 0.32, LEATHER)
			_g(b, "SM_Prop_Basket_12", Vector3(ocx + 0.05, ct, cz), -0.2, 0.42)
			_g(b, "#hp_sandals", Vector3(ocx + 0.05, ct + 0.04, cz), 0.3, 0.42)
			_g(b, "SM_Prop_Tool_Hammer_01", Vector3(ob - 0.05, ct + 0.02, cz), 0.8, 0.8)
			_g(b, "SM_Prop_Anvil_01", Vector3(ou - 0.05 * m, Y0, gz), 0.4, 0.3)
			_g(b, "SM_Prop_Basket_06", Vector3(ocx - 0.2 * m, Y0, gz + 0.04), 0.3, 0.38)
			_g(b, "#hp_sandals", Vector3(ocx - 0.2 * m, Y0 + 0.26, gz + 0.04), 0.9, 0.45)
			_free(b)
			_g(b, "SM_Prop_Rug_Drape_01", Vector3(ox1 + 0.04 if m > 0 else ox0 - 0.04, Y0 + 1.45, fz - 0.4), PI / 2 * m, 0.34, LEATHER)
			_shelf(b, ir, [["SM_Prop_Basket_06", 0.32], ["SM_Prop_Basket_12", 0.42], ["SM_Prop_Rug_Folded_03", 0.3, LEATHER], ["SM_Prop_Basket_07", 0.3]], pal)
			b.actor(worker, 0.0, "Interact", "any")
		"tailor":
			# тоги — белая и пурпурная на раме у края мостовой, ткани стопками на прилавке, стол с отрезами в глубине
			var tx := ou - 0.55 * m
			_rail(b, minf(tx, ou), maxf(tx, ou), gz + 0.05, Y0, Y0 + 1.5)
			_sheet(b, Vector3(minf(tx, ou) + 0.16, Y0 + 1.5, gz + 0.05), 0.24, 0.95, CatShops.WHITE)
			_sheet(b, Vector3(maxf(tx, ou) - 0.16, Y0 + 1.5, gz + 0.05), 0.24, 0.85, CatShops.PURPLE)
			_g(b, "SM_Prop_Rug_Folded_01", Vector3(oa + 0.1, ct, cz), 0.2, 0.3, CatShops._rug("03_A"))
			_g(b, "SM_Prop_Rug_Folded_02", Vector3(oa + 0.12, ct + 0.04, cz), -0.1, 0.27, CatShops._rug("03_B"))
			_g(b, "SM_Prop_Rug_Folded_01", Vector3(ob - 0.1, ct, cz), 0.1, 0.3, CatShops._rug("02_B"))
			_p(b, "SM_Prop_Table_05", Vector3((float(ir[0]) + float(ir[1])) * 0.5, Y0, float(ir[2]) + 0.95), PI / 2, Vector3.ONE * 0.48, GLOW)
			_g(b, "SM_Prop_Rug_Folded_02", Vector3((float(ir[0]) + float(ir[1])) * 0.5, Y0 + 0.38, float(ir[2]) + 0.95), 0.3, 0.3, GLOW)
			_shelf(b, ir, [["SM_Prop_Rug_Folded_02", 0.3, CatShops._rug("01_B")], ["SM_Prop_Rug_Folded_01", 0.3, CatShops._rug("03_C")],
				["SM_Prop_Rug_Folded_01", 0.28, CatShops._rug("03_A")], ["SM_Prop_Rug_Folded_02", 0.28, CatShops._rug("01_C")]], pal)
			_hang(b, ox0 + 0.2, ox1 - 0.2, hz, hy, [["SM_Prop_Rug_Drape_01", Vector3(0.2, 0.32, 0.08), CatShops._rug("03_A")], ["SM_Prop_Rug_Drape_01", Vector3(0.2, 0.36, 0.08), CatShops._rug("01_B")]])
			b.actor(worker, 0.0, "Interact", "any")
		"potter":
			# гора амфор и ваз на мостовой, печь для обжига с огнём, кувшины на верёвках, вазы на прилавке
			_g(b, "SM_Prop_Vase_Pile_02", Vector3(ou - 0.12 * m, Y0, gz + 0.05), PI / 2, 0.26)
			_g(b, "SM_Prop_Kiln_01", Vector3(ocx - 0.15 * m, Y0, gz + 0.05), PI, 0.2)
			NewSmall._fire(b, Vector3(ocx - 0.15 * m, Y0 + 0.08, gz + 0.25), 1.6)
			b.light(Vector3(ocx - 0.15 * m, Y0 + 0.3, gz + 0.4))
			_g(b, "SM_Prop_Vase_0%d" % (1 + pal % 6), Vector3(oa + 0.06, ct, cz), 0.0, 0.3)
			_g(b, "SM_Prop_Jug_0%d" % (1 + (pal + 2) % 6), Vector3(ocx, ct, cz), 0.4, 0.34)
			_g(b, "SM_Prop_Bowl_04", Vector3(ob - 0.05, ct, cz), 0.0, 0.5)
			_hang(b, ox0 + 0.12, ox1 - 0.12, hz, hy, [["SM_Prop_Jug_05", 0.42], ["SM_Prop_Jug_01", 0.26], ["SM_Prop_Jug_05", 0.38]])
			_shelf(b, ir, [["SM_Prop_Vase_02", 0.28], ["SM_Prop_Vase_03", 0.27], ["SM_Prop_Jug_03", 0.26], ["SM_Prop_Vase_06", 0.3]], pal)
			b.actor(worker, 0.0, "Interact", "any")
		"oilshop":
			# долии с маслом и маслина в кадке на мостовой, корзина маслин, кувшины на прилавке, бронзовая олива на стене
			_g(b, "SM_Prop_Jar_01", Vector3(ou, Y0, gz), 0.0, 0.48)
			_g(b, "SM_Prop_Jar_01", Vector3(ou - 0.3 * m, Y0, gz + 0.22), 0.8, 0.42)
			_g(b, "SM_Prop_Vase_04", Vector3(ocx - 0.2 * m, Y0, gz + 0.1), 0.0, 0.45)
			_g(b, "SM_Env_Tree_Bush_0%d" % (1 + pal % 3), Vector3(ocx - 0.2 * m, Y0 + 0.33, gz + 0.1), 0.0, 0.14, {"tint": Color(0.75, 0.9, 0.6)})
			_basket(b, Vector3(oa + 0.1, ct, cz), "olives", 0.28)
			_g(b, "SM_Prop_Jug_06", Vector3(ocx + 0.05, ct, cz), 0.0, 0.3)
			_g(b, "SM_Prop_Jug_02", Vector3(ob - 0.05, ct, cz), 0.5, 0.3)
			_free(b)
			_g(b, "SM_Prop_Symbol_18", Vector3(ocx, Y0 + 1.82, fz + 0.04), 0.0, 0.3, CatShops.BRONZE)
			_hang(b, ox0 + 0.12, ox1 - 0.12, hz, hy, [["SM_Prop_Jug_06", 0.26], ["#dress:garlic", 0.6], ["SM_Prop_Jug_05", 0.4]])
			_shelf(b, ir, [["SM_Prop_Jug_06", 0.3], ["SM_Prop_Jar_01", 0.34], ["SM_Prop_Jug_02", 0.28], ["SM_Prop_Jug_06", 0.28]], pal)
			b.actor(worker, 0.0, "Interact", "any")
		"lamps":
			# светильники на цепях у края навеса (светят), канделябры у входа, лампы рядком на прилавке
			for k in 3:
				var lx := lerpf(ox0 + 0.2, ox1 - 0.2, k / 2.0)
				_free(b)
				_g(b, "SM_Prop_Senser_03", Vector3(lx, hy - 0.62, hz), 0.0, 0.5)
				if k == 1:
					b.light(Vector3(lx, hy - 0.55, hz))
			for k in 4:
				_g(b, "SM_Prop_Senser_04", Vector3(lerpf(oa, ob, k / 3.0), ct, cz), k * 0.5, 0.28)
			_g(b, "SM_Prop_Senser_01", Vector3(ou, Y0, gz), 0.0, 0.5)
			_g(b, "SM_Prop_Senser_02", Vector3(ocx - 0.15 * m, Y0, gz + 0.12), 0.0, 0.62)
			_shelf(b, ir, [["SM_Prop_Senser_04", 0.3], ["SM_Prop_Senser_04", 0.3], ["SM_Prop_Senser_02", 0.3], ["SM_Prop_Senser_04", 0.28]], pal)
			b.actor(worker, 0.0, "Interact", "any")
		"wineshop":
			# амфоры у входа (одна лежит), лоза над дверью, грозди на верёвках, кувшины и кубки на прилавке
			for k in 3:
				_g(b, "SM_Prop_Jug_03", Vector3(ou - k * 0.2 * m, Y0, gz - 0.04 + (k % 2) * 0.12), k * 0.7, 0.4)
			_p(b, "SM_Prop_Jug_03", Vector3(ocx - 0.2 * m, Y0 + 0.08, gz + 0.12), PI / 2, Vector3.ONE * 0.38)
			b.parts[b.parts.size() - 1][1] = b.base * Transform3D(Basis(Vector3.UP, 0.4) * Basis(Vector3.FORWARD, PI / 2) * Basis.from_scale(Vector3.ONE * 0.38), Vector3(ocx - 0.2 * m, Y0 + 0.1, gz + 0.12))
			_g(b, "SM_Prop_Jug_0%d" % (1 + pal % 4), Vector3(oa + 0.06, ct, cz), 0.0, 0.3)
			_g(b, "SM_Prop_Goblet_01", Vector3(ocx, ct, cz), 0.0, 0.6)
			_g(b, "SM_Prop_Goblet_02", Vector3(ocx + 0.14, ct, cz + 0.03), 0.0, 0.6)
			_g(b, "SM_Prop_Jug_05", Vector3(ob - 0.05, ct, cz), 0.0, 0.48)
			_hang(b, ox0 + 0.12, ox1 - 0.12, hz, hy, [["#hp_grapes", 0.45], ["SM_Prop_Jug_05", 0.42], ["#hp_grapes", 0.4]])
			_free(b)
			_g(b, "SM_Env_Vine_0%d" % (1 + pal % 3), Vector3(dcx, Y0 + H1 + 0.02, fz + 0.06), 0.0, 0.32)
			_shelf(b, ir, [["SM_Prop_Vase_01", 0.26], ["SM_Prop_Jug_03", 0.26], ["SM_Prop_Jug_01", 0.3], ["SM_Prop_Vase_02", 0.26]], pal)
			b.actor(worker, 0.0, "Interact", "any")
		"perfumer":
			# флаконы и кубки на прилавке, ящик роз и курильница на мостовой, сушёные цветы на верёвках
			for k in 3:
				_g(b, "SM_Prop_Jug_05", Vector3(lerpf(oa, ocx - 0.05, k / 2.0), ct, cz + (k % 2) * 0.03), k * 0.6, 0.38)
			_g(b, "SM_Prop_Goblet_02", Vector3(ocx + 0.12, ct, cz), 0.0, 0.6)
			_g(b, "SM_Prop_Vase_04", Vector3(ob - 0.05, ct, cz), 0.0, 0.26)
			_p(b, "SM_Prop_FlowerBed_01", Vector3(ocx - 0.1 * m, Y0 + 0.39 * 0.36, gz + 0.04), 0.0, Vector3.ONE * 0.36)
			_g(b, "SM_Prop_Senser_02", Vector3(ou, Y0, gz), 0.0, 0.55)
			b.light(Vector3(ou, Y0 + 0.5, gz))
			_hang(b, ox0 + 0.15, ox1 - 0.15, hz, hy, [["#dress:herbs", 0.5], ["SM_Prop_Jug_05", 0.36], ["#dress:herbs", 0.45]])
			_g(b, "SM_Prop_Pillow_Pile_02", Vector3(float(ir[0]) + 0.45, Y0 + 0.01, float(ir[3]) - 0.5), 0.4, 0.34, GLOW)
			_shelf(b, ir, [["SM_Prop_Jug_05", 0.4], ["SM_Prop_Goblet_02", 0.55], ["SM_Prop_Vase_04", 0.26], ["SM_Prop_Jug_05", 0.36], ["SM_Prop_Goblet_01", 0.55], ["SM_Prop_Jug_05", 0.38]], pal)
			b.actor(worker, 0.0, "Interact", "female")
		"jeweler":
			# золотые кубки, чаши и бусы на прилавке, бусы на верёвках, бюст на постаменте у входа
			_g(b, "SM_Prop_Goblet_01", Vector3(oa + 0.04, ct, cz), 0.0, 0.62, GILT)
			_g(b, "SM_Prop_Bowl_04", Vector3(oa + 0.24, ct, cz), 0.0, 0.42, GILT)
			_g(b, "#hp_necklace", Vector3(ocx + 0.08, ct + 0.02, cz + 0.02), 0.0, 0.42)
			_g(b, "SM_Prop_Plate_02", Vector3(ob - 0.08, ct, cz), 0.3, 0.42, GILT)
			_g(b, "SM_Prop_Goblet_02", Vector3(ob - 0.06, ct + 0.02, cz), 0.0, 0.55, GILT)
			_hang(b, ox0 + 0.15, ox1 - 0.15, hz, hy, [["#hp_necklace", 0.5], ["#hp_necklace", 0.45], ["#hp_necklace", 0.5]])
			_g(b, "SM_Prop_Plinth_02", Vector3(ou, Y0, gz), 0.0, 0.48)
			_g(b, "SM_Prop_Statue_0%d" % (1 + pal % 7), Vector3(ou, Y0 + 0.63, gz), 0.0, 0.18)
			_p(b, "SM_Prop_Table_04", Vector3(ocx - 0.15 * m, Y0, gz + 0.06), 0.0, Vector3(0.42, 0.62, 0.42))
			_g(b, "SM_Prop_Goblet_01", Vector3(ocx - 0.15 * m, Y0 + 0.48, gz + 0.06), 0.0, 0.6, GILT)
			_g(b, "SM_Prop_Plate_02", Vector3(ocx - 0.15 * m + 0.1, Y0 + 0.48, gz + 0.02), 0.0, 0.36, GILT)
			_shelf(b, ir, [["SM_Prop_Goblet_01", 0.6, GILT], ["SM_Prop_Bowl_04", 0.45, GILT], ["SM_Prop_Plate_02", 0.4, GILT], ["SM_Prop_Goblet_02", 0.6, GILT]], pal)
			b.actor(worker, 0.0, "Interact", "rich")
		"weaver":
			# ткацкий станок с полотном на мостовой, стопки тканей, цветные ткани на верёвках, рулоны на прилавке
			var cl := ["01_B", "02_B", "01_A", "03_B"]
			_g(b, "SM_Prop_Loom_01", Vector3(ou - 0.32 * m, Y0, gz + 0.02), 0.0, 0.4, CatShops._rug(cl[pal % 4]))
			_g(b, "SM_Prop_Rug_Stack_01", Vector3(ocx - 0.32 * m, Y0, gz + 0.06), 0.2, 0.3, CatShops._rug("03_B"))
			_g(b, "SM_Prop_Rug_Folded_01", Vector3(oa + 0.1, ct, cz), 0.2, 0.3, CatShops._rug(cl[(pal + 1) % 4]))
			_g(b, "SM_Prop_Rug_Folded_02", Vector3(ob - 0.1, ct, cz), -0.1, 0.3, CatShops._rug(cl[(pal + 2) % 4]))
			_hang(b, ox0 + 0.15, ox1 - 0.15, hz, hy, [["SM_Prop_Rug_Drape_01", Vector3(0.22, 0.36, 0.08), CatShops._rug(CatShops.SHELF_CLOTH[pal % 4])],
				["SM_Prop_Rug_Drape_01", Vector3(0.2, 0.42, 0.08), CatShops._rug(CatShops.SHELF_CLOTH[(pal + 1) % 4])]])
			_shelf(b, ir, [["SM_Prop_Rug_Folded_01", 0.3, CatShops._rug("01_B")], ["SM_Prop_Rug_Folded_02", 0.3, CatShops._rug("03_C")],
				["SM_Prop_Rug_Folded_02", 0.28, CatShops._rug("01_A")], ["SM_Prop_Rug_Folded_01", 0.28, CatShops._rug("03_B")]], pal)
			b.actor(worker, 0.0, "Interact", "female")
		"barber":
			# кресло для бритья на мостовой (клиент в нём), цирюльник с бритвой рядом; таз, кувшин, полотенце и
			# зеркальце на прилавке; полотенца на верёвке
			var chx := ocx - 0.12 * m
			var chz := minf(z1 - 0.3, fz + 0.5)
			_g(b, "SM_Prop_Seat_Chair_01", Vector3(chx, Y0, chz), PI, 0.72)
			_g(b, "SM_Prop_Bowl_04", Vector3(oa + 0.08, ct, cz), 0.0, 0.5)
			_g(b, "SM_Prop_Jug_05", Vector3(oa + 0.3, ct, cz), 0.0, 0.45)
			_g(b, "SM_Prop_Rug_Folded_02", Vector3(ocx + 0.1, ct, cz), 0.3, 0.26, CatShops._rug("03_A"))
			_g(b, "SM_Prop_Plate_03", Vector3(ob - 0.06, ct + 0.005, cz), 0.0, 0.6, GILT)
			_hang(b, ox0 + 0.15, ox1 - 0.15, hz, hy, [["SM_Prop_Rug_Drape_01", Vector3(0.18, 0.3, 0.08), CatShops._rug("03_A")], ["SM_Prop_Rug_Drape_01", Vector3(0.18, 0.28, 0.08), CatShops._rug("03_B")]])
			_g(b, "SM_Prop_FlowerPot_Fancy_01", Vector3(ou, Y0 + 0.57 * 0.24, minf(z1 - 0.2, gz + 0.1)), 0.0, 0.24)
			_shelf(b, ir, [["SM_Prop_Jug_05", 0.42], ["SM_Prop_Bowl_04", 0.45], ["SM_Prop_Goblet_01", 0.55], ["SM_Prop_Rug_Folded_02", 0.28, CatShops._rug("03_A")]], pal)
			# первым — цирюльник (работник один — его место первое), вторым — клиент в кресле
			b.actor(Vector3(chx + 0.42 * m, AY, chz - 0.05), -PI / 2 * m, "Interact", "any")
			b.actor(Vector3(chx, AY, chz), 0.0, "Sitting_Idle", "pleb")
		"medic":
			# пучки трав на верёвках, свитки, ступка и склянки на прилавке, травы в горшках и скамья для больных
			_hang(b, ox0 + 0.12, ox1 - 0.12, hz, hy, [["#dress:herbs", 0.55], ["#dress:herbs", 0.5], ["#dress:garlic", 0.5], ["#dress:herbs", 0.55]])
			_g(b, "SM_Prop_Scroll_Pile_0%d" % (1 + pal % 6), Vector3(oa + 0.08, ct, cz), 0.3, 0.32)
			_g(b, "SM_Prop_Bowl_04", Vector3(ocx, ct, cz), 0.0, 0.45)
			_g(b, "SM_Prop_Jug_05", Vector3(ob - 0.05, ct, cz), 0.0, 0.42)
			for k in 2:
				var vx := ou - k * 0.42 * m
				_g(b, "SM_Prop_Vase_04", Vector3(vx, Y0, gz + k * 0.1), 0.0, 0.38)
				_g(b, "SM_Env_Garden_Plants_0%d" % (3 + (pal + k) % 4), Vector3(vx, Y0 + 0.29, gz + k * 0.1), k * 1.3, 0.13)
			_shelf(b, ir, [["SM_Prop_Scroll_Pile_02", 0.3], ["SM_Prop_Vase_04", 0.26], ["SM_Prop_Scroll_Pile_04", 0.3], ["SM_Prop_Jug_05", 0.42]], pal)
			b.actor(worker, 0.0, "Interact", "any")


# =====================================================================
#   красильня: сушильня на столбах под черепицей, цветные ткани, чаны с краской
# =====================================================================

static func _dyer(b: Bp, fr: Array, x: Dictionary) -> Vector3:
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	var m: float = x["m"]
	var pal: int = x["pal"]
	_base(b, x0, x1, z0, z1)
	var fs := 0.62
	var r := [x0 + 0.08, x1 - 0.08, z0 + 0.1, z1 - fs]
	var f := _front(b, r, Y0, H1, x, m)
	NewSmall._storey(b, r, {1: "S", 3: "S"}, Y0, H1, x)
	NewSmall._storey(b, r, {2: "ML" if m > 0 else "LM"}, Y0, H1, x, {}, _st2(x["t"]))
	_socle(b, r, x["t"])
	_band(b, r, Y0 + H1, x)
	NewSmall._pilasters(b, r, {0: 1, 1: 1, 2: 2, 3: 1}, Y0, H1 + E)
	var ir := NewSmall._inner(r, 0.3)
	NewSmall._hall(b, ir, Y0, H1 - 0.04, f["gaps"])
	b.light(Vector3((float(ir[0]) + float(ir[1])) * 0.5, Y0 + 1.5, (float(ir[2]) + float(ir[3])) * 0.5))
	var fz: float = r[3]
	var dcx: float = f["dcx"]
	var ox0: float = f["ox0"]
	var ox1: float = f["ox1"]
	# сушильня наверху: деревянный настил, перила, столбы, черепичная кровля, ткани всех цветов на перекладинах
	var yt := Y0 + H1 + E
	NewCivic._floor(b, NewSmall.WOOD, float(r[0]), float(r[2]), float(r[1]), fz, yt - 0.005, 2.0)
	var pr := [float(r[0]) + 0.02, float(r[1]) - 0.02, float(r[2]) + 0.02, fz - 0.02]
	for side in 4:
		NewSmall._run(b, "SM_Bld_Wall_Balcony_03", pr, side, yt - 0.01, -0.04, 2.5, 0.42, 0.5, {}, 2.0)
	var ph := 1.45
	var cs := [Vector2(float(pr[0]) + 0.08, float(pr[2]) + 0.08), Vector2(float(pr[1]) - 0.08, float(pr[2]) + 0.08),
		Vector2(float(pr[0]) + 0.08, float(pr[3]) - 0.08), Vector2(float(pr[1]) - 0.08, float(pr[3]) - 0.08)]
	for cc: Vector2 in cs:
		_p(b, "SM_Prop_Pole_01", Vector3(cc.x, yt, cc.y), 0.0, Vector3(0.55, ph / 3.0, 0.55))
	var lr := [float(r[0]) - 0.04, float(r[1]) + 0.04, float(r[2]) - 0.04, fz + 0.04]
	_roof(b, lr, yt + ph, x)
	var cols := [CatShops.MAGENTA, CatShops.BLUE, CatShops.MUSTARD, CatShops.RED, CatShops.PURPLE, CatShops.GREEN]
	for row in 2:
		var bz := lerpf(float(pr[2]) + 0.3, float(pr[3]) - 0.3, float(row))
		_p(b, "SM_Prop_Beam_01", Vector3(float(pr[0]) + 0.08, yt + ph - 0.1, bz), 0.0, Vector3((float(pr[1]) - float(pr[0]) - 0.16) / 2.5, 0.45, 0.45))
		for k in 3:
			var sx := lerpf(float(pr[0]) + 0.5, float(pr[1]) - 0.5, k / 2.0)
			_sheet(b, Vector3(sx, yt + ph - 0.1, bz), 0.62, 0.9 - 0.12 * ((k + row) % 2), int(cols[(pal + k + row * 3) % cols.size()]))
	# вывеска на перилах сушильни, кронштейн у края лавки
	_sign(b, "dyer", Vector3((float(r[0]) + float(r[1])) * 0.5, yt + 0.23, fz + 0.06), 0.42)
	_bsign(b, "dyer", Vector3(float(r[0]) + 0.14 if m > 0 else float(r[1]) - 0.14, yt + ph - 0.12, fz - 0.06), 0.55)
	_p(b, "SM_Prop_Overhang_01", Vector3(dcx, Y0 + H1 - 0.2, fz + 0.01), 0.0, Vector3(0.36, 0.7, 0.55))
	_lamp(b, Vector3(dcx - m * 0.48, Y0 + 1.55, fz + 0.02))
	_step(b, dcx, fz)
	# навес над прилавком, чаны с краской на мостовой, мотки ткани на прилавке
	var yb := Y0 + H1 - 0.06
	_awning(b, ox0 + 0.02, ox1 - 0.02, fz + 0.02, fz + 0.45, yb, yb - 0.3, int(x["col"]), int(x["col2"]))
	var ct := Y0 + 0.545
	var oa := ox0 + 0.32
	var ob := ox1 - 0.32
	var gz := fz + 0.32
	var vc := [CatShops.MAGENTA, CatShops.SKY, CatShops.MUSTARD]
	for k in 3:
		var vx := lerpf(ox0 + 0.25, ox1 - 0.25, k / 2.0)
		if absf(vx - dcx) < 0.45:
			continue
		_vat(b, Vector3(vx, Y0, gz), int(vc[(k + pal) % 3]), 0.26)
	_u(b, "SM_Prop_Rug_Folded_01", Vector3(oa + 0.08, ct, fz + 0.03), 0.2, 0.28, CatShops._rug("01_B"))
	_u(b, "SM_Prop_Rug_Folded_02", Vector3(ob - 0.08, ct, fz + 0.03), -0.2, 0.28, CatShops._rug("01_A"))
	_shelf(b, ir, [["SM_Prop_Rug_Folded_02", 0.26, CatShops._rug("03_B")], ["SM_Prop_Jug_02", 0.26], ["SM_Prop_Rug_Folded_01", 0.26, CatShops._rug("03_A")], ["SM_Prop_Bowl_04", 0.4]], pal)
	b.actor(Vector3((ox0 + ox1) * 0.5, AY, fz - 0.38), 0.0, "Interact", "any")
	return Vector3(dcx, 0, z1 + 0.35)


# =====================================================================
#   фуллоника: дом с ванной из чанов перед ним, половина верха — жильё, половина — терраса с бельём
# =====================================================================

static func _fullonica(b: Bp, fr: Array, x: Dictionary) -> Vector3:
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	var m: float = x["m"]
	var pal: int = x["pal"]
	_base(b, x0, x1, z0, z1)
	var fs := 0.95
	var r := [x0 + 0.08, x1 - 0.08, z0 + 0.1, z1 - fs]
	var f := _front(b, r, Y0, H1, x, m, WD, 1.2)
	NewSmall._storey(b, r, {1: "S", 3: "S"}, Y0, H1, x)
	NewSmall._storey(b, r, {2: "MLM"}, Y0, H1, x, {}, _st2(x["t"]))
	_socle(b, r, x["t"])
	_band(b, r, Y0 + H1, x)
	NewSmall._pilasters(b, r, {0: 1, 1: 1, 2: 3, 3: 1}, Y0, H1 + E)
	var fz: float = r[3]
	var dcx: float = f["dcx"]
	var ox0: float = f["ox0"]
	var ox1: float = f["ox1"]
	var y2 := Y0 + H1 + E
	var ytop := y2 + H2
	# жильё — над дверью (на половине ширины), фронтоном к улице; другая половина — терраса-сушильня
	var hw := (float(r[1]) - float(r[0])) * 0.5
	var r2 := [float(r[0]), float(r[0]) + hw, r[2], fz] if m > 0 else [float(r[1]) - hw, float(r[1]), r[2], fz]
	var si := 1 if m > 0 else 3                       # бок жилья к террасе (окна видны с неё)
	var g2 := {0: "S" if pal % 2 == 0 else "B", 2: "S"}
	g2[si] = "SW"
	g2[4 - si] = "S"
	var res2 := NewSmall._storey(b, r2, g2, y2, H2, x)
	NewSmall._pilasters(b, r2, {0: 1, 1: 1, 2: 1, 3: 1}, y2, H2, 0.17)
	NewSmall._frieze(b, r2, ytop - 0.2)
	NewSmall._cornice(b, r2, ytop - 0.03, 0.16, 0.08)
	for e: Array in res2["W"]:
		NewSmall._ivy(b, r2, e, y2, H2, pal)
	var x2 := x.duplicate()
	x2["rz"] = true
	_roof(b, r2, ytop + 0.08, x2)
	var tr := [float(r[0]) + hw, float(r[1]), r[2], fz] if m > 0 else [float(r[0]), float(r[1]) - hw, r[2], fz]
	_flat(b, float(tr[0]), float(tr[1]), float(tr[2]), fz, y2)
	var pr := [float(tr[0]), float(tr[1]) - 0.02, float(tr[2]) + 0.02, fz - 0.02] if m > 0 else [float(tr[0]) + 0.02, float(tr[1]), float(tr[2]) + 0.02, fz - 0.02]
	NewSmall._run(b, "SM_Bld_Wall_Balcony_04", pr, 0, y2 - 0.01, -0.03, 2.5, 0.42, 0.55, {}, 2.0)
	NewSmall._run(b, "SM_Bld_Wall_Balcony_04", pr, 2, y2 - 0.01, -0.03, 2.5, 0.42, 0.55, {}, 2.0)
	NewSmall._run(b, "SM_Bld_Wall_Balcony_04", pr, 1 if m > 0 else 3, y2 - 0.01, -0.03, 2.5, 0.42, 0.55, {}, 2.0)
	# бельё на верёвках террасы: белые тоги и цветные туники
	for row in 2:
		var bz := lerpf(float(pr[2]) + 0.35, float(pr[3]) - 0.3, float(row))
		_rail(b, float(pr[0]) + 0.12, float(pr[1]) - 0.12, bz, y2, y2 + 1.25)
		for k in 2:
			var sx := lerpf(float(pr[0]) + 0.45, float(pr[1]) - 0.45, float(k))
			_sheet(b, Vector3(sx, y2 + 1.25, bz), 0.5, 0.75 - 0.1 * ((k + row) % 2), [CatShops.WHITE, [CatShops.SKY, CatShops.PINK, CatShops.MUSTARD][pal % 3]][(k + row) % 2])
	# нутро: зал в тёплом свете, полки с тканями
	var ir := NewSmall._inner(r, 0.3)
	NewSmall._hall(b, ir, Y0, H1 - 0.04, f["gaps"])
	var ir2 := NewSmall._inner(r2, 0.3)
	NewSmall._hall(b, ir2, y2 - 0.02, H2 - 0.06, [])
	b.light(Vector3((float(ir[0]) + float(ir[1])) * 0.5, Y0 + 1.5, (float(ir[2]) + float(ir[3])) * 0.5))
	_shelf(b, ir, [["SM_Prop_Rug_Folded_01", 0.3, CatShops._rug("03_A")], ["SM_Prop_Rug_Folded_02", 0.3, CatShops._rug("03_B")],
		["SM_Prop_Rug_Folded_02", 0.28, CatShops._rug("03_A")], ["SM_Prop_Rug_Folded_01", 0.28, CatShops._rug("03_C")]], pal)
	# в мастерской — перекладина с сохнущими полотнами и стопка сукна (видно через проём)
	var rz := (float(ir[2]) + float(ir[3])) * 0.5 + 0.1
	var rx0 := ox0 + 0.3
	var rx1 := ox1 - 0.3
	_p(b, "SM_Prop_Beam_01", Vector3(rx0, Y0 + 1.55, rz), 0.0, Vector3((rx1 - rx0) / 2.5, 0.5, 0.5), GLOW)
	for k in 2:
		_sheet(b, Vector3(lerpf(rx0 + 0.3, rx1 - 0.3, float(k)), Y0 + 1.55, rz), 0.45, 0.8, [CatShops.WHITE, [CatShops.SKY, CatShops.MUSTARD, CatShops.PINK][pal % 3]][k])
	_u(b, "SM_Prop_Rug_Stack_01", Vector3(float(ir[1]) - 0.35 if m > 0 else float(ir[0]) + 0.35, Y0, float(ir[3]) - 0.4), 0.3, 0.3, CatShops._rug("03_A"))
	# вход: козырёк, фонарь, ступень; вывески — на стене жилья и на кронштейне
	_p(b, "SM_Prop_Overhang_01", Vector3(dcx, Y0 + H1 - 0.2, fz + 0.01), 0.0, Vector3(0.38, 0.7, 0.62))
	_lamp(b, Vector3(dcx - m * 0.5, Y0 + 1.55, fz + 0.02))
	_step(b, dcx, fz)
	_sign(b, "fullonica", Vector3((ox0 + ox1) * 0.5, Y0 + H1 + 0.3, fz + 0.07), 0.48)
	_bsign(b, "fullonica", Vector3(float(r2[0]) + 0.12 if m > 0 else float(r2[1]) - 0.12, ytop - 0.16, fz + 0.02), 0.58)
	# перед мастерской — низкая каменная ванна с тремя чанами (валяльщики топчут сукно), корзины белья
	var bx0 := ox0 + 0.12
	var bx1 := ox1 - 0.12
	var bz0 := fz + 0.12
	var bz1 := minf(z1 - 0.1, fz + 0.78)
	var wr := [bx0, bx1, bz0, bz1]
	for side in 4:
		NewSmall._run(b, "SM_Bld_Wall_01", wr, side, Y0, -0.05, 2.5, 0.26 / 3.01, 0.45, NewSmall.STONE, 1.6)
	NewCivic._ring(b, "SM_Bld_Wall_Large_Cap_01", bx0 - 0.03, bx1 + 0.03, bz0 - 0.03, bz1 + 0.03, Y0 + 0.25, 5.02, 0.22, 0.22, {}, [0, 1, 2, 3], 1.6)
	b.parts.append(["#water", b.base * Transform3D(Basis.from_scale(Vector3(bx1 - bx0 - 0.14, 0.04, bz1 - bz0 - 0.14)), Vector3((bx0 + bx1) * 0.5, Y0 + 0.13, (bz0 + bz1) * 0.5)), {}])
	for k in 3:
		_vat(b, Vector3(lerpf(bx0 + 0.32, bx1 - 0.32, k / 2.0), Y0 + 0.03, (bz0 + bz1) * 0.5), [CatShops.SKY, CatShops.WHITE, CatShops.SKY][k], 0.42)
	_u(b, "SM_Prop_Basket_08", Vector3(dcx + 0.42 * m, Y0, z1 - 0.18), 0.0, 0.36)
	_u(b, "SM_Prop_Rug_Folded_01", Vector3(dcx + 0.42 * m, Y0 + 0.2, z1 - 0.18), 0.4, 0.26, CatShops._rug("03_A"))
	b.actor(Vector3((bx0 + bx1) * 0.5 - 0.15, AY, bz1 + 0.12), PI, "Interact", "any")
	NewSmall._bush(b, Vector3(x1 - 0.22 if m > 0 else x0 + 0.22, Y0, z0 + 0.25), 0.16)
	return Vector3(dcx, 0, z1 + 0.35)


# =====================================================================
#   термополий: Г-образная стойка с долиями, жаровня, столик со стульями на мостовой
# =====================================================================

static func _thermopolium(b: Bp, fr: Array, x: Dictionary) -> Vector3:
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	var m: float = x["m"]
	var pal: int = x["pal"]
	_base(b, x0, x1, z0, z1)
	var fs := 0.98
	var r := [x0 + 0.08, x1 - 0.08, z0 + 0.1, z1 - fs]
	var up: int = 1 if x["up"] == 2 else int(x["up"])
	var h := _house(b, "thermopolium", r, x, up)
	var fz: float = h["fz"]
	var ox0: float = h["ox0"]
	var ox1: float = h["ox1"]
	var dcx: float = h["dcx"]
	var ir: Array = h["ir"]
	var ct := Y0 + 0.545
	# колено стойки — вглубь лавки у дальнего края проёма (за ним — продавец), в столешнице — долии с едой
	var kx := ox1 - 0.34 if m > 0 else ox0 + 0.34
	_p(b, "SM_Bld_Wall_01", Vector3(kx + 0.065, Y0, fz - 0.05), PI / 2, Vector3(0.62 / 2.5, 0.5 / 3.01, 0.6), NewSmall.STONE)
	_p(b, "SM_Bld_Wall_Large_Cap_01", Vector3(kx, Y0 + 0.48, fz + 0.0), PI / 2, Vector3(0.66 / 5.02, 0.2, 0.3))
	for k in 3:
		_u(b, "SM_Prop_Jar_01", Vector3(lerpf(ox0 + 0.45, ox1 - 0.45, k / 2.0), ct - 0.2, fz + 0.03), k * 0.9, 0.36)
	_u(b, "SM_Prop_Brazier_04", Vector3(kx, ct, fz - 0.3), 0.0, 0.26)
	_u(b, "SM_Prop_Bowl_02", Vector3(kx, ct + 0.06, fz - 0.3), 0.0, 0.2)
	NewSmall._fire(b, Vector3(kx, ct + 0.04, fz - 0.3), 1.4)
	b.light(Vector3(kx, ct + 0.4, fz - 0.2))
	# горшки на цепях под навесом, кувшины и миски на стойке, роспись-ларарий у задней стены
	var aw := 0.78
	var yb := Y0 + H1 - 0.06
	var yf := yb - 0.36
	_awning(b, ox0 + 0.02, ox1 - 0.02, fz + 0.02, fz + aw, yb, yf, int(x["col"]), int(x["col2"]))
	for xx: float in [ox0 + 0.08, ox1 - 0.08]:
		_p(b, "SM_Prop_Pole_01", Vector3(xx, Y0, fz + aw - 0.06), 0.0, Vector3(0.42, (yf - Y0) / 3.0, 0.42))
	_hang(b, ox0 + 0.9, ox1 - 0.9, fz + aw - 0.05, yf + 0.02, [["#dress:garlic", 0.55], ["#dress:herbs", 0.5]])
	for k in 2:
		_free(b)
		_u(b, "SM_Prop_Pots_Hanging_0%d" % (1 + k), Vector3(lerpf(ox0 + 0.35, ox1 - 0.35, float(k)), yf + 0.04, fz + aw - 0.1), k * 0.8, 0.42)
	_u(b, "SM_Prop_Jug_0%d" % (1 + pal % 4), Vector3(ox0 + 0.28, ct, fz + 0.03), 0.0, 0.28)
	_u(b, "SM_Prop_Bowl_04", Vector3(ox1 - 0.28 if m < 0 else ox0 + 0.55, ct, fz + 0.04), 0.0, 0.45)
	_free(b)
	_u(b, "SM_Prop_Mural_02", Vector3((float(ir[0]) + float(ir[1])) * 0.5, Y0 + 1.25, float(ir[2]) + 0.02), 0.0, 0.32, {"Mural_01": "mural_08", "glow": WARM * 0.4})
	_shelf(b, [ir[0], ir[1], float(ir[2]) + 0.05, ir[3]], [["SM_Prop_Jug_02", 0.3], ["SM_Prop_Bowl_04", 0.45], ["SM_Prop_Jug_03", 0.26], ["SM_Prop_Plate_02", 0.4]], pal)
	# столик и два стула на мостовой (места Life: стулья у стола) — у дальнего от двери края
	var tx := ox1 - 0.62 if m > 0 else ox0 + 0.62
	var tz := minf(z1 - 0.3, fz + aw + 0.12)
	_p(b, "SM_Prop_Table_07", Vector3(tx, Y0, tz), 0.0, Vector3(0.62, 0.5 / 0.55, 0.62))
	for sd: float in [-1.0, 1.0]:
		_u(b, "SM_Prop_Seat_Chair_01", Vector3(tx + sd * 0.42, Y0, tz), PI / 2, 0.66)
	_u(b, "SM_Prop_Jug_0%d" % (1 + (pal + 1) % 4), Vector3(tx + 0.07, Y0 + 0.5, tz), 0.0, 0.24)
	_u(b, "SM_Prop_Goblet_02", Vector3(tx - 0.08, Y0 + 0.5, tz + 0.06), 0.0, 0.5)
	b.actor(Vector3((ox0 + ox1) * 0.5 - 0.15 * m, AY, fz - 0.36), 0.0, "Interact", "any")
	_pot(b, Vector3(x0 + 0.2 if m > 0 else x1 - 0.2, Y0, z1 - 0.2), 0.22)
	NewSmall._bush(b, Vector3(x1 - 0.22 if m > 0 else x0 + 0.22, Y0, z0 + 0.25), 0.16)
	return Vector3(dcx, 0, z1 + 0.35)


# =====================================================================
#   таверна: дом с баром и открытым входом, двор под перголой с лозой, столики и скамьи
# =====================================================================

static func _taberna(b: Bp, fr: Array, x: Dictionary) -> Vector3:
	var x0: float = fr[0]
	var x1: float = fr[1]
	var z0: float = fr[2]
	var z1: float = fr[3]
	var pal: int = x["pal"]
	_base(b, x0, x1, z0, z1)
	var hd := 2.55
	var r := [x0 + 0.08, x1 - 0.08, z0 + 0.1, z0 + 0.1 + hd]
	var fz: float = r[3]
	var W := float(r[1]) - float(r[0])
	var y2 := Y0 + H1 + E
	var ytop := y2 + H2
	# фасад: бар-прилавок | открытый вход в зал (проём без створок — тёплый зал за ним) | бар-прилавок
	var mw := W / 3.0
	var ra := [float(r[0]), float(r[0]) + mw, r[2], fz]
	var rb := [float(r[0]) + mw, float(r[0]) + 2.0 * mw, r[2], fz]
	var rc := [float(r[0]) + 2.0 * mw, float(r[1]), r[2], fz]
	var resa := NewSmall._storey(b, ra, {0: "O"}, Y0, H1, x)
	var resc := NewSmall._storey(b, rc, {0: "O"}, Y0, H1, x)
	var k := mw / 2.5
	var sy := H1 / 3.01
	_p(b, "SM_Bld_Wall_Door_Large_01", Vector3(float(rb[0]), Y0, fz - 0.3 * 0.6), 0.0, Vector3(k, sy, 0.6), x["door"])
	var gaps := NewSmall._gaps(ra, resa) + NewSmall._gaps(rc, resc)
	gaps.append([float(rb[0]) + 0.65 * k - 0.03, float(rb[0]) + 1.85 * k + 0.03])
	gaps.sort_custom(func(g0: Array, g1: Array) -> bool: return float(g0[0]) < float(g1[0]))
	var dcx := float(rb[0]) + 1.25 * k
	NewSmall._storey(b, r, {1: "NS", 2: "SNS", 3: "SN"}, Y0, H1, x)
	_socle(b, r, x["t"])
	_band(b, r, Y0 + H1, x)
	var res2 := NewSmall._storey(b, r, {0: "SBS" if pal % 2 == 0 else "BSB", 1: "WS", 2: "NSN", 3: "SW"}, y2, H2, x)
	NewSmall._pilasters(b, r, {0: 3, 1: 1, 2: 3, 3: 1}, Y0, H1 + E)
	NewSmall._pilasters(b, r, {0: 3, 1: 1, 2: 3, 3: 1}, y2, H2, 0.17)
	NewSmall._frieze(b, r, ytop - 0.2)
	NewSmall._cornice(b, r, ytop - 0.03, 0.16, 0.08)
	for e: Array in res2["W"]:
		NewSmall._ivy(b, r, e, y2, H2, pal + int(e[0]))
	var x2 := x.duplicate()
	x2["rz"] = false
	_roof(b, r, ytop + 0.08, x2)
	var ir := NewSmall._inner(r, 0.3)
	NewSmall._hall(b, ir, Y0, ytop - Y0 - 0.08, gaps)
	b.light(Vector3((float(ir[0]) + float(ir[1])) * 0.5, Y0 + 1.6, (float(ir[2]) + float(ir[3])) * 0.5))
	# зал: амфоры у стен, полка с кувшинами, бочонки-долии
	_shelf(b, ir, [["SM_Prop_Jug_03", 0.26], ["SM_Prop_Jug_02", 0.28], ["SM_Prop_Goblet_01", 0.55], ["SM_Prop_Jug_01", 0.3], ["SM_Prop_Jug_05", 0.4], ["SM_Prop_Goblet_02", 0.55]], pal)
	_u(b, "SM_Prop_Vase_Pile_02", Vector3(float(ir[0]) + 0.4, Y0, float(ir[3]) - 0.5), 0.0, 0.24, GLOW)
	_u(b, "SM_Prop_Jar_Pile_01", Vector3(float(ir[1]) - 0.4, Y0, float(ir[3]) - 0.5), 0.0, 0.28, GLOW)
	# на барах: кувшины, кубки, миски
	var ct := Y0 + 0.545
	for e: Array in [[ra, 0], [rc, 1]]:
		var rr: Array = e[0]
		var cx := (float(rr[0]) + float(rr[1])) * 0.5
		_u(b, "SM_Prop_Jug_0%d" % (1 + (pal + int(e[1])) % 4), Vector3(cx - 0.18, ct, fz + 0.03), 0.0, 0.28)
		_u(b, "SM_Prop_Goblet_0%d" % (1 + int(e[1])), Vector3(cx + 0.05, ct, fz + 0.03), 0.0, 0.55)
		_u(b, "SM_Prop_Bowl_04", Vector3(cx + 0.22, ct, fz + 0.04), 0.0, 0.4)
	# над входом — вывеска, по сторонам фонари; вывеска на кронштейне у угла
	_sign(b, "taberna", Vector3(dcx, y2 + H2 * 0.5, fz + 0.03), 0.56)
	for sd: float in [-1.0, 1.0]:
		_lamp(b, Vector3(dcx + sd * 0.48, Y0 + 1.6, fz + 0.02))
	_step(b, dcx, fz, 0.9)
	# двор: у дома — пергола на двух столбах (рейки от дома, лоза поверх, плющ на столбах), у улицы — открыто
	# (сверху видно столы); у правого края у улицы свободно — там по вечерам стоят у жаровни (Spectacle)
	var zp := fz + 1.45
	var ph := 2.05
	var pxs := [float(r[0]) + 0.1, float(r[1]) - 0.1]
	for xx: float in pxs:
		_p(b, "SM_Bld_Pillar_06", Vector3(xx, Y0, zp), 0.0, Vector3(0.22, ph / 3.0, 0.22))
	_p(b, "SM_Prop_Beam_01", Vector3(float(r[0]), Y0 + ph, zp), 0.0, Vector3(W / 2.5, 0.8, 0.8))
	_p(b, "SM_Bld_Trellis_Roof_Large_02", Vector3(float(r[0]) + 0.05, Y0 + ph + 0.03, fz + 0.02), 0.0, Vector3((W - 0.1) / 7.5, 0.6, (zp - fz) / 5.0))
	for kv in 3:
		var vx := lerpf(float(r[0]) + 0.75, float(r[1]) - 0.75, kv / 2.0)
		b.parts.append(["SM_Env_Vine_0%d" % (1 + (pal + kv) % 3), b.base * Transform3D(Basis(Vector3.UP, 0.0 if kv % 2 == 0 else PI) * Basis(Vector3.RIGHT, -PI / 2) * Basis.from_scale(Vector3(0.5, 0.45, 0.45)),
			Vector3(vx, Y0 + ph + 0.14, (fz + zp) * 0.5 + (0.3 if kv % 2 == 0 else -0.3))), {}])
	_u(b, "SM_Env_Ivy_Pillar_Flowers_0%d" % (1 + pal % 2), Vector3(float(pxs[0]), Y0, zp), 0.5, 0.55)
	_u(b, "SM_Env_Ivy_Pillar_Flowers_0%d" % (1 + (pal + 1) % 2), Vector3(float(pxs[1]), Y0, zp), 1.5, 0.55)
	for xx: float in [float(r[0]) + 0.95, float(r[1]) - 0.95]:
		_free(b)
		_u(b, "SM_Prop_Senser_03", Vector3(xx, Y0 + ph - 0.62, zp - 0.05), 0.0, 0.5)
	b.light(Vector3(float(r[0]) + 0.95, Y0 + ph - 0.55, zp - 0.05))
	# столики: под перголой два круглых со стульями, у улицы длинный стол со скамьями (места Life и вечера в таверне);
	# посуда — на столах, скамьи пустые
	var tt := [[Vector2(-1.3, fz + 0.72), 0.0], [Vector2(1.3, fz + 0.72), 1.0]]
	for e: Array in tt:
		var c: Vector2 = e[0]
		_p(b, "SM_Prop_Table_07", Vector3(c.x, Y0, c.y), 0.0, Vector3(0.62, 0.5 / 0.55, 0.62))
		for sd: float in [-1.0, 1.0]:
			_u(b, "SM_Prop_Seat_Chair_01", Vector3(c.x + sd * 0.42, Y0, c.y), PI / 2, 0.66)
		_u(b, "SM_Prop_Jug_0%d" % (1 + (pal + int(e[1])) % 4), Vector3(c.x + 0.07, Y0 + 0.5, c.y - 0.04), 0.0, 0.24)
		_u(b, "SM_Prop_Goblet_0%d" % (1 + int(e[1])), Vector3(c.x - 0.08, Y0 + 0.5, c.y + 0.07), 0.0, 0.5)
	var lt := Vector2(-0.1, zp + 0.55)
	_p(b, "SM_Prop_Table_08", Vector3(lt.x, Y0, lt.y), 0.0, Vector3(0.5, 0.5 / 0.78, 0.5))
	for sd: float in [-1.0, 1.0]:
		_p(b, "SM_Prop_Seat_Bench_05", Vector3(lt.x, Y0, lt.y + sd * 0.45), 0.0, Vector3(0.5, 0.34 / 0.46, 0.52))
	_u(b, "SM_Prop_Plate_02", Vector3(lt.x - 0.35, Y0 + 0.5, lt.y), 0.0, 0.4)
	_u(b, "SM_Prop_Jug_05", Vector3(lt.x + 0.05, Y0 + 0.5, lt.y - 0.03), 0.0, 0.42)
	_u(b, "SM_Prop_Goblet_02", Vector3(lt.x + 0.35, Y0 + 0.5, lt.y + 0.05), 0.0, 0.5)
	# жаровня у улицы слева, амфоры и цветы у стены дома, кадка у столба
	_u(b, "SM_Prop_Brazier_03", Vector3(float(r[0]) + 0.5, Y0, zp + 0.6), 0.0, 0.42)
	_u(b, "SM_Prop_Brazier_03_Insert_01", Vector3(float(r[0]) + 0.5, Y0, zp + 0.6), 0.0, 0.42)
	_u(b, "SM_Prop_Vase_Pile_02", Vector3(float(r[0]) + 0.42, Y0, fz + 0.24), PI / 2, 0.2)
	_pot(b, Vector3(float(r[1]) - 0.22, Y0, fz + 0.22), 0.24)
	_pot(b, Vector3(0.0, Y0, fz + 0.28), 0.22)
	_u(b, "SM_Prop_Jar_01", Vector3(0.95, Y0, z1 - 0.3), 0.6, 0.42)
	# хозяин за баром, служанка у входа в зал
	b.actor(Vector3((float(ra[0]) + float(ra[1])) * 0.5, AY, fz - 0.4), 0.0, "Interact", "any")
	b.actor(Vector3(dcx + 0.1, AY, fz - 0.32), 0.0, "Idle", "any")
	return Vector3(dcx, 0, z1 + 0.6)
