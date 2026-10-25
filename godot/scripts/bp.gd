class_name Bp
extends RefCounted
## Чертёж постройки: список деталей Synty (имя, положение, раскраска) + огни, дым, вход.
## Начало координат — середина основания, фасад смотрит на +Z. Строится один раз на (тип, уровень, вариант)
## и потом ставится сколько угодно раз через пул деталей (Parts).

const M := 2.5      # модуль стены
const FL := 3.0     # этаж
const STUCCO := ["Stucco_White_01", "Stucco_Orange_01", "Stucco_Red_01", "Stucco_Blue_01"]
## Черепица: терракота разных оттенков, иногда песочная
const ROOFS := ["Roof_Tile_01", "Roof_Tile_03", "Roof_Tile_12", "Roof_Tile_01", "Roof_Tile_06", "Roof_Tile_05", "Roof_Tile_03"]

var parts := []                 # [имя, Transform3D, remap]
var lights: Array[Vector3] = []
var smoke: Array[Vector3] = []
var door := Vector3(0, 0, 3)    # куда входят жители (снаружи, у двери)
var rng := RandomNumberGenerator.new()
var remap := {}                 # раскраска стен этого здания (текущий этаж)
var tint := Color(1, 1, 1)      # цвет штукатурки (из палитры)
var ground_style := "brick"     # низ первого этажа: brick | pattern | plain
var upper_style := "plain"      # верхние этажи: plain | pattern
var roof_tex := "Roof_Tile_01"
var full_brick := false
var base := Transform3D.IDENTITY  # общий сдвиг/масштаб (для больших построек)
var actors := []                # люди при деле: [положение, поворот, движение, кто]
var _top := -1.0


func _init(seed_v := 1) -> void:
	rng.seed = seed_v


func pick(a: Array):
	return a[rng.randi() % a.size()]


func chance(p: float) -> bool:
	return rng.randf() < p


## Деталь в точке pos (метры), поворот yaw, масштаб s. walls = true — красится в цвет стен здания
func add(name: String, pos: Vector3, yaw := 0.0, s := 1.0, walls := false) -> void:
	parts.append([name, base * Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), pos), remap.duplicate() if walls else {}])


func add_xf(name: String, xf: Transform3D, walls := false) -> void:
	parts.append([name, base * xf, remap.duplicate() if walls else {}])


## Человек при деле (виден, когда постройка работает): работник в поле, торговец, жрец, стражник
func actor(p: Vector3, yaw: float, anim: String, who := "any") -> void:
	actors.append([base * p, yaw, anim, who])


func light(p: Vector3) -> void:
	lights.append(base * p)


## Раскраска здания: цвет штукатурки из палитры (индекс), стиль первого этажа и верха, черепица.
## c = -1 — кирпич целиком
func paint(c: int, styles := true) -> void:
	full_brick = c < 0
	tint = Color(1, 1, 1) if c < 0 else (Defs.PALETTE[c % Defs.PALETTE.size()]["c"] as Color)
	if styles:
		ground_style = pick(["brick", "plain", "pattern", "plain"])
		upper_style = pick(["plain", "plain", "pattern"])
	roof_tex = pick(ROOFS)
	remap = floor_remap(1)


func _set_tex(tex: String) -> Dictionary:
	var r := {}
	for s0 in STUCCO:
		r[s0] = tex
	r["Roof_Tile_01"] = roof_tex
	if not full_brick:
		r["tints"] = {tex: tint}
	return r


func floor_remap(f: int) -> Dictionary:
	if full_brick:
		return _set_tex("Building_Large_Brick_01")
	if f == 0:
		match ground_style:
			"brick": return _set_tex("Building_Half_Brick_01")
			"pattern": return _set_tex("Stucco_White_Pattern_0%d" % (3 + (int(tint.r * 97.0) % 2)))
	if upper_style == "pattern" and f > 0:
		return _set_tex("Stucco_White_Pattern_0%d" % (1 + (int(tint.g * 89.0) % 2)))
	return _set_tex("Stucco_White_01")


## Двускатная крыша с коньком вдоль Z (поперёк фасада) — фронтоном к улице
func gable_z(cx: float, cz: float, wm: int, dm: int, top: float, toppers := true) -> float:
	var keep := base
	base = base * Transform3D(Basis(Vector3.UP, PI / 2), Vector3(cx, 0, cz))
	var sm := smoke.size()
	var r := gable(0, 0, dm, wm, top, toppers)
	base = keep
	return r


# ---------- след постройки на земле ----------

const NONSOLID := ["Roof", "Trim", "Ivy", "Vine", "Banner", "Hanging", "Rug", "Drapery", "Overhang", "Trellis_Roof", "_Balcony_0",
	"SM_Bld_Balcony", "Grass", "SM_Env_Flowers", "Lillies", "Torch", "Mural", "Symbol", "SM_Bld_Door_0", "Topper", "Wall_Tiny", "Ornament",
	"Pillar_Trim", "Beam_Detail", "Cart_01_Insert", "Brazier_0", "Plate", "Bowl", "Jug", "Goblet", "Scroll_0", "Tool_"]

static var _aabbs := {}


static func model_aabb(name: String) -> AABB:
	if _aabbs.has(name):
		return _aabbs[name]
	var box := AABB(Vector3(-0.5, 0, -0.5), Vector3(1, 1, 1))
	if name.begins_with("#mil_"):
		box = CatMilitary.kit_mesh(name).get_aabb()     # детали Легиона из Kit — по их настоящим габаритам
	elif name.begins_with("#d2_"):
		box = CatDecor2.kit_mesh(name).get_aabb()       # свои детали украшений этапа 5
	elif not name.begins_with("#"):
		var n := Synty.make(name)
		box = Artisau.aabb(n)
		n.free()
	_aabbs[name] = box
	return box


## Высота верхушки постройки (для значков над ней)
func top_y() -> float:
	if _top >= 0.0:
		return _top
	var t := 1.0
	for p in parts:
		var nm: String = p[0]
		if nm.begins_with("#"):
			continue
		var box := model_aabb(nm)
		var xf: Transform3D = p[1]
		for i in 8:
			t = maxf(t, (xf * box.get_endpoint(i)).y)
	_top = t
	return t


## Передняя стена постройки (z фасада) — по стенам и дверям; если стен нет — по следу
func front_z() -> float:
	var f := -INF
	for p in parts:
		var nm: String = p[0]
		if (nm.begins_with("SM_Bld_Wall_") and not nm.contains("Balcony") and not nm.contains("Tiny")) or nm.begins_with("SM_Bld_Pillar"):
			var box := model_aabb(nm)
			var xf: Transform3D = p[1]
			for i in 8:
				f = maxf(f, (xf * box.get_endpoint(i)).z)
	return f


## Прямоугольники следа (в осях постройки, XZ): из габаритов настоящих деталей, без крыш, плюща, навесов и мелочи
## all = false — только части здания (SM_Bld_: стены, колонны, ступени) — контур бордюра Kerb идёт по стенам,
## а не вокруг кипарисов, перголы и скамей в саду
func footprint(all := true) -> Array:
	var out := []
	var fz := front_z()
	for p in parts:
		var nm: String = p[0]
		if not all and not nm.begins_with("SM_Bld_"):
			continue
		var skip := false
		for w in NONSOLID:
			if nm.contains(w):
				skip = true
				break
		if skip:
			continue
		var xf: Transform3D = p[1]
		var box := model_aabb(nm)
		if nm.begins_with("SM_Env_Tree") or nm.begins_with("SM_Env_Bush") or nm.begins_with("SM_Env_Garden"):
			# у деревьев — только ствол и низ кроны
			var c := box.get_center()
			box = AABB(Vector3(c.x - box.size.x * 0.15, box.position.y, c.z - box.size.z * 0.15), Vector3(box.size.x * 0.3, box.size.y, box.size.z * 0.3))
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		var low_y := INF
		for i in 8:
			var q := xf * box.get_endpoint(i)
			lo = lo.min(Vector2(q.x, q.z))
			hi = hi.max(Vector2(q.x, q.z))
			low_y = minf(low_y, q.y)
		if low_y > 1.6:
			continue                          # висит высоко (балкон, вывеска) — землю не занимает
		if fz > -INF and lo.y > fz - 0.05 and (hi.y - lo.y) < 1.0 and (hi.x - lo.x) < 1.6:
			continue                          # горшки и скамейки перед фасадом стоят на мостовой
		if (hi - lo).x < 0.05 or (hi - lo).y < 0.05:
			continue
		out.append(Rect2(lo, hi - lo))
	return out


# ---------- коробка стен ----------

## Точка на стене блока: середина блока (cx, cz), размер wm×dm модулей; сторона 0 фасад +Z, 1 → +X, 2 → −Z, 3 → −X
func wall_at(cx: float, cz: float, wm: int, dm: int, side: int, i: float, y: float, out := 0.0) -> Array:
	var hw := wm * M / 2.0
	var hd := dm * M / 2.0
	match side:
		0: return [Vector3(cx - hw + i * M, y, cz + hd + out), 0.0]
		1: return [Vector3(cx + hw + out, y, cz + hd - i * M), PI / 2]
		2: return [Vector3(cx + hw - i * M, y, cz - hd - out), PI]
		_: return [Vector3(cx - hw - out, y, cz - hd + i * M), -PI / 2]


func on_wall(name: String, cx: float, cz: float, wm: int, dm: int, side: int, i: float, y: float, out := 0.0, walls := false, s := 1.0) -> void:
	var a := wall_at(cx, cz, wm, dm, side, i, y, out)
	add(name, a[0], a[1], s, walls)


## Дом-коробка: этажи стен с окнами и дверями, карнизы, углы. o:
##   door_i — модуль двери на фасаде (−1 — без двери), shop — лавки на первом этаже (массив модулей),
##   win — вид окон, win_p — доля окон, trim, base_trim, sides (какие стороны рисовать)
func block(cx: float, cz: float, wm: int, dm: int, floors: int, o := {}) -> void:
	var win: String = o.get("win", pick(["SM_Bld_Wall_Window_01", "SM_Bld_Wall_Window_02", "SM_Bld_Wall_Window_03", "SM_Bld_Wall_Window_04", "SM_Bld_Wall_Window_05"]))
	var win0: String = o.get("win0", pick(["SM_Bld_Wall_Window_06", "SM_Bld_Wall_Window_01", "SM_Bld_Wall_Window_04"]))
	var trim: String = o.get("trim", pick(["SM_Bld_Trim_01", "SM_Bld_Trim_02", "SM_Bld_Trim_03", "SM_Bld_Trim_04"]))
	var door_i: int = o.get("door_i", rng.randi() % wm)
	var door_nm: String = o.get("door", pick(["SM_Bld_Wall_Door_01", "SM_Bld_Wall_Door_02", "SM_Bld_Wall_Door_03"]))
	var shop: Array = o.get("shop", [])
	var win_p: float = o.get("win_p", 0.75)
	var sides: Array = o.get("sides", [0, 1, 2, 3])
	var roof_trim: bool = o.get("roof_trim", true)
	for f in floors:
		var y := f * FL
		remap = floor_remap(f)
		for side in sides:
			var n := wm if side % 2 == 0 else dm
			for i in n:
				var nm := "SM_Bld_Wall_01"
				if f == 0 and side == 0 and i == door_i:
					nm = door_nm
				elif f == 0 and side == 0 and i in shop:
					nm = "SM_Bld_Wall_Door_Large_01"
				elif chance(win_p if side == 0 else win_p * 0.6):
					nm = win if f > 0 else win0
				on_wall(nm, cx, cz, wm, dm, side, i, y, 0.0, true)
				if f < floors - 1 or roof_trim:
					on_wall(trim, cx, cz, wm, dm, side, i, y + FL - 0.33, 0.0, true)
				if f == 0:
					on_wall("SM_Bld_Trim_05", cx, cz, wm, dm, side, i, 0.0, 0.0, true)
		# углы
		var hw := wm * M / 2.0
		var hd := dm * M / 2.0
		for c: Array in [[Vector3(cx - hw, y, cz + hd), 0.0], [Vector3(cx + hw, y, cz + hd), PI / 2], [Vector3(cx + hw, y, cz - hd), PI], [Vector3(cx - hw, y, cz - hd), -PI / 2]]:
			add("SM_Bld_Wall_End_01", c[0], c[1], 1.0, true)
	remap = floor_remap(1)
	# тёмное нутро — в открытые двери лавок не видно травы с другой стороны
	parts.append(["#dark", base * Transform3D(Basis.IDENTITY.scaled(Vector3(wm * M - 0.5, floors * FL - 0.1, dm * M - 0.5)), Vector3(cx, floors * FL / 2.0, cz)), {}])
	if door_i >= 0:
		var a := wall_at(cx, cz, wm, dm, 0, door_i + 0.3, 0.0, -0.02)
		add("SM_Bld_Door_0%d" % (1 + rng.randi() % 5), a[0], a[1])
		var d := wall_at(cx, cz, wm, dm, 0, door_i + 0.5, 0.0, 0.9)
		door = base * (d[0] as Vector3)


## Двускатная черепичная крыша над блоком (конёк вдоль X); глубина ската подгоняется под dm
func gable(cx: float, cz: float, wm: int, dm: int, top: float, toppers := true) -> float:
	var hw := wm * M / 2.0
	var hd := dm * M / 2.0
	var k := dm / 2.0
	var sxf := func(pos: Vector3, yaw: float) -> Transform3D:
		return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(1.0, k, k)), pos)
	for i in wm:
		add_xf("SM_Bld_Roof_Base_Straight_01", sxf.call(Vector3(cx - hw + i * M, top, cz + hd), 0.0), true)
		add_xf("SM_Bld_Roof_Base_Straight_01", sxf.call(Vector3(cx + hw - i * M, top, cz - hd), PI), true)
		add("SM_Bld_Roof_Edge_Straight_01", Vector3(cx - hw + i * M, top, cz + hd), 0.0, 1.0, true)
		add("SM_Bld_Roof_Edge_Straight_01", Vector3(cx + hw - i * M, top, cz - hd), PI, 1.0, true)
	add_xf("SM_Bld_Roof_Base_Straight_Side_01", sxf.call(Vector3(cx - hw, top, cz + hd), 0.0), true)
	add_xf("SM_Bld_Roof_Base_Straight_Side_01", sxf.call(Vector3(cx + hw, top, cz - hd), PI), true)
	add_xf("SM_Bld_Roof_Base_Straight_Side_01", sxf.call(Vector3(cx + hw, top, cz + hd), 0.0), true)
	add_xf("SM_Bld_Roof_Base_Straight_Side_01", sxf.call(Vector3(cx - hw, top, cz - hd), PI), true)
	var ridge := top + 0.75 * k
	if toppers:
		var tp := "SM_Bld_Roof_Topper_0%d" % pick([1, 2, 3, 5, 6])    # 4-й похож на крест — не для Рима
		add(tp, Vector3(cx - hw + 0.12, ridge + 0.02, cz), 0.0)
		add(tp, Vector3(cx + hw - 0.12, ridge + 0.02, cz), 0.0)
	smoke.append(base * Vector3(cx + hw * 0.45, ridge + 0.1, cz - 0.3))
	return ridge


## Плоская крыша-терраса с низким парапетом
func flat_roof(cx: float, cz: float, wm: int, dm: int, top: float) -> void:
	var hw := wm * M / 2.0
	var hd := dm * M / 2.0
	for i in wm:
		for j in dm:
			add("SM_Bld_Roof_Base_Flat_02", Vector3(cx - hw + i * M, top - 0.68, cz + hd - j * M), 0.0)
	for side in 4:
		var n := wm if side % 2 == 0 else dm
		for i in n:
			on_wall("SM_Bld_Wall_Balcony_04", cx, cz, wm, dm, side, i, top, 0.0, true)
	smoke.append(base * Vector3(cx + hw * 0.5, top + 0.4, cz - hd * 0.5))


## Пергола с лозой на крыше-террасе (угол блока)
func roof_pergola(x: float, z: float, top: float) -> void:
	for c: Vector3 in [Vector3(x + 0.25, top, z + 0.25), Vector3(x + M - 0.25, top, z + 0.25), Vector3(x + 0.25, top, z + M - 0.25), Vector3(x + M - 0.25, top, z + M - 0.25)]:
		add("SM_Bld_Trellis_Pillar_01", c, 0.0, 0.75)
	add("SM_Bld_Trellis_Roof_01", Vector3(x + M, top + 2.3, z), 0.0)
	add("SM_Env_Vine_0%d" % (1 + rng.randi() % 3), Vector3(x + M / 2, top + 2.3, z + M / 2), rng.randf() * TAU, 0.8)
	add("SM_Prop_Seat_Kline_0%d" % (1 + rng.randi() % 3), Vector3(x + M / 2, top, z + M / 2), 0.0, 0.8)


# ---------- украшения на стенах и у входа ----------

func ivy(cx: float, cz: float, wm: int, dm: int, floors: int, flowers := true) -> void:
	var side: int = pick([0, 1, 3])
	var n := wm if side % 2 == 0 else dm
	var nm := "SM_Env_Ivy_Flowers_0%d" % pick([1, 2, 3, 4, 6, 8, 9]) if flowers else "SM_Env_Ivy_0%d" % pick([1, 2, 3, 4, 6, 8, 9])
	on_wall(nm, cx, cz, wm, dm, side, rng.randi() % n + 0.5, rng.randf_range(1.4, maxf(1.6, floors * FL - 1.3)), 0.13)


## Цветы у окна: подвесные кашпо под окнами фасада
func window_pots(cx: float, cz: float, wm: int, dm: int, floor_i: int) -> void:
	for i in wm:
		if chance(0.55):
			on_wall("SM_Prop_FlowerPot_Hanging_0%d" % (4 + rng.randi() % 3), cx, cz, wm, dm, 0, i + 0.5, floor_i * FL + 1.0, 0.13)


## Лавка: черепичный навес над проёмом, стол с товаром, коврик, корзины
func shop_front(cx: float, cz: float, wm: int, dm: int, i: int, kind := "") -> void:
	on_wall("SM_Prop_Overhang_01", cx, cz, wm, dm, 0, i + 0.5, 2.75, 0.12)
	var a := wall_at(cx, cz, wm, dm, 0, i + 0.5, 0.0, 1.0)
	var p: Vector3 = a[0]
	add("SM_Prop_Table_01", p, 0.0)
	var on_top := ["SM_Prop_Vase_0%d", "SM_Prop_Jug_0%d", "SM_Prop_Bowl_0%d", "SM_Prop_Basket_0%d"]
	if kind == "fruit":
		on_top = ["SM_Prop_Basket_0%d", "SM_Prop_Bowl_0%d"]
	for k in 3:
		var nm: String = (pick(on_top) as String) % (1 + rng.randi() % 4)
		add(nm, p + Vector3(-0.55 + k * 0.55, 0.78, rng.randf_range(-0.15, 0.15)), rng.randf() * TAU, 0.6)
	add(pick(["SM_Prop_Basket_Set_01", "SM_Prop_Jar_Pile_01", "SM_Prop_Vase_Pile_0%d" % (1 + rng.randi() % 6), "SM_Prop_Sack_Stack_01"]), p + Vector3(rng.randf_range(-1.0, 1.0), 0, 0.9), rng.randf() * TAU, 0.85)
	if chance(0.6):
		add("SM_Prop_Rug_0%d" % (5 + rng.randi() % 2), p + Vector3(0, 0.01, 0.2), PI / 2, 0.7)


func door_decor(cx: float, cz: float, wm: int, dm: int, door_i: int) -> void:
	if chance(0.75):
		var a := wall_at(cx, cz, wm, dm, 0, door_i - 0.05 if door_i > 0 else door_i + 1.05, 0.0, 0.45)
		add("SM_Prop_FlowerPot_Fancy_01", a[0], rng.randf() * TAU, 0.85)
	if chance(0.5):
		on_wall("SM_Prop_Pots_Hanging_0%d" % (1 + rng.randi() % 2), cx, cz, wm, dm, 0, door_i + 0.92, 2.55, 0.32)
	if chance(0.35):
		var b := wall_at(cx, cz, wm, dm, 0, door_i + 1.1, 0.0, 0.5)
		if door_i + 1 < wm:
			add("SM_Prop_Seat_Bench_01", b[0], b[1])


func balcony(cx: float, cz: float, wm: int, dm: int, i: int, floor_i: int) -> void:
	var a := wall_at(cx, cz, wm, dm, 0, i + 0.5, floor_i * FL, 0.11)
	add("SM_Bld_Balcony_01", a[0], a[1])
	var f := wall_at(cx, cz, wm, dm, 0, i + 0.18, floor_i * FL, 0.75)
	add("SM_Prop_FlowerPot_Fancy_01", f[0], 0.0, 0.8)
	if chance(0.6):
		var r := wall_at(cx, cz, wm, dm, 0, i + 0.62, floor_i * FL + 0.95, 1.12)
		add("SM_Prop_Rug_Drape_01", r[0], r[1] + PI)


func wall_banner(cx: float, cz: float, wm: int, dm: int, i: float, y: float) -> void:
	var letter: String = pick(["A", "B", "C", "D", "E", "F"])
	on_wall("SM_Prop_Banner_0%d_%s" % [1 + rng.randi() % 3, letter], cx, cz, wm, dm, 0, i, y, 0.02)


func torch_pair(cx: float, cz: float, wm: int, dm: int, i: float) -> void:
	for s: float in [-0.42, 0.42]:
		var a := wall_at(cx, cz, wm, dm, 0, i + s, 2.1, 0.12)
		add("SM_Prop_Torch_01", a[0], a[1])
		light((a[0] as Vector3) + Vector3(0, 0.25, 0.1))


# ---------- двор, природа, мелочи ----------

func yard_bits(x0: float, z0: float, x1: float, z1: float, n: int) -> void:
	var items := ["SM_Prop_Basket_0%d", "SM_Prop_Jar_01", "SM_Prop_Sack_0%d", "SM_Prop_Vase_0%d", "SM_Prop_Straw_Bundle_01", "SM_Prop_Stool_01", "SM_Prop_Jug_0%d"]
	for k in n:
		var nm: String = pick(items)
		if nm.contains("%d"):
			nm = nm % (1 + rng.randi() % 5)
		add(nm, Vector3(rng.randf_range(x0, x1), 0, rng.randf_range(z0, z1)), rng.randf() * TAU)


func plants(x0: float, z0: float, x1: float, z1: float, n: int) -> void:
	for k in n:
		var r := rng.randf()
		var p := Vector3(rng.randf_range(x0, x1), 0, rng.randf_range(z0, z1))
		if r < 0.45:
			add("SM_Env_Garden_Plants_0%d" % (3 + rng.randi() % 5), p, rng.randf() * TAU, rng.randf_range(0.5, 0.75))
		elif r < 0.75:
			add("SM_Env_Flowers_0%d" % (1 + rng.randi() % 5), p, rng.randf() * TAU, rng.randf_range(1.0, 1.6))
		else:
			add("SM_Env_Grass_0%d" % (1 + rng.randi() % 3), p, rng.randf() * TAU, rng.randf_range(0.6, 1.0))


func fence(x0: float, z0: float, x1: float, z1: float, gate_front := true) -> void:
	var fn: String = pick(["SM_Env_Fence_Wood_01", "SM_Env_Fence_Wood_03"])
	var seg := func(a: Vector3, b: Vector3, gate: bool) -> void:
		var len := a.distance_to(b)
		var n := maxi(1, int(round(len / 2.5)))
		var dir := (b - a) / n
		var yaw := atan2(-dir.z, dir.x)
		for k in n:
			var nm := "SM_Env_Fence_Wood_Gate_01" if gate and k == n / 2 else fn
			add_xf(nm, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(dir.length() / 2.5, 1, 1)), a + dir * k))
	seg.call(Vector3(x0, 0, z1), Vector3(x1, 0, z1), gate_front)
	seg.call(Vector3(x1, 0, z1), Vector3(x1, 0, z0), false)
	seg.call(Vector3(x1, 0, z0), Vector3(x0, 0, z0), false)
	seg.call(Vector3(x0, 0, z0), Vector3(x0, 0, z1), false)


func brazier(p: Vector3, big := false) -> void:
	if big:
		add("SM_Prop_Brazier_01", p, 0.0, 0.75)
		add("SM_Prop_Brazier_01_Insert_01", p, 0.0, 0.75)
		light(p + Vector3(0, 1.5, 0))
	else:
		add("SM_Prop_Brazier_03", p, 0.0)
		add("SM_Prop_Brazier_03_Insert_01", p, 0.0)
		light(p + Vector3(0, 0.95, 0))


## Портик: ряд колонн по z_col от x0 до x1 (шаг 2,5 м), над ними пояс, черепичный скат до стены z_wall.
## dir = +1 — портик перед стеной (к +Z), −1 — за стеной. Возвращает высоту верха колонн
func portico(x0: float, x1: float, z_col: float, z_wall: float, h := 0.92, pillar := "SM_Bld_Pillar_02", ivy := false) -> float:
	var n := int(round((x1 - x0) / M))
	var top := 3.0 * h
	var dir := signf(z_col - z_wall)
	var depth := absf(z_col - z_wall) + 0.4
	for i in n + 1:
		var x := x0 + i * M
		add(pillar, Vector3(x, 0, z_col), 0.0, h)
		if ivy and i % 2 == 0:
			add("SM_Env_Ivy_Pillar_Flowers_0%d" % (1 + rng.randi() % 2), Vector3(x, 0, z_col), rng.randf() * TAU, h)
	for i in n:
		var x := x0 + i * M
		if dir > 0:
			add("SM_Bld_Wall_Tiny_01", Vector3(x, top, z_col), 0.0, 1.0, true)
			add_xf("SM_Bld_Roof_Base_Straight_01", Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 0.55, depth / 2.5)), Vector3(x, top + 0.3, z_col + 0.4)), true)
		else:
			add("SM_Bld_Wall_Tiny_01", Vector3(x + M, top, z_col), PI, 1.0, true)
			add_xf("SM_Bld_Roof_Base_Straight_01", Transform3D(Basis(Vector3.UP, PI).scaled(Vector3(1.0, 0.55, depth / 2.5)), Vector3(x + M, top + 0.3, z_col - 0.4)), true)
	return top


func column_statue(p: Vector3, yaw: float, h := 1.0) -> void:
	add("SM_Prop_Pillar_Base_02", p, 0.0, h)
	add("SM_Prop_Statue_0%d" % (1 + rng.randi() % 7), p + Vector3(0, 1.5 * h, 0), yaw, 0.75 * h)
