class_name CatDress
extends RefCounted
## Наполнение домов и лавок деталями, как на картинках Synty (владелец 12.11: «всё на Synty, пересобрать…
## более детальными и живыми»; «детальнее… что-то между нашими сборными и Синти: кирпичики, земля…»):
## ящики цветов под окнами, цветущий плющ, горшки у дверей и на цепях, вывески над дверью и на кронштейне,
## кирпичная кладка там, где отбита штукатурка, каменные блоки на углах, трава и камешки у стен, корзины и мешки
## у лавок. Ставится после сборки облика по стенам Synty из чертежа (снаружи — от середины дома); землю не
## занимает (Bp.free_parts) — след и правила постановки прежние. Свои детали (#bricks_*, #quoin_*, #bsign:*)
## одинаковы во всём городе — каждая рисуется одним MultiMesh (Parts).

const WALL_W := 2.5            # стена Synty: 2,5 вдоль (x от 0), 3 в высоту, толщина по z
const FACE := 0.115            # от середины толщины стены до её лица
const BOXES := ["SM_Prop_FlowerBed_01", "SM_Prop_FlowerBed_02"]
## Окна стен Synty (сняты с картинки стен спереди): подоконник по высоте и окна [середина вдоль стены, ширина]
const WIN := {"SM_Bld_Wall_Window_01": [0.65, [[1.25, 1.2]]], "SM_Bld_Wall_Window_02": [1.4, [[0.55, 0.42], [1.25, 0.42], [1.95, 0.42]]],
	"SM_Bld_Wall_Window_03": [1.4, [[1.25, 0.42]]], "SM_Bld_Wall_Window_04": [1.4, [[1.25, 1.75]]], "SM_Bld_Wall_Window_05": [0.65, [[1.25, 1.2]]]}
## Двери: [начало и конец проёма вдоль стены, верх проёма] (сняты с вершин стен Synty)
const DOOR := {"SM_Bld_Wall_Door_01": [0.7, 1.8, 2.05], "SM_Bld_Wall_Door_02": [0.75, 1.75, 2.85], "SM_Bld_Wall_Door_03": [0.75, 1.75, 2.75],
	"SM_Bld_Wall_Door_04": [0.75, 1.75, 1.97], "SM_Bld_Wall_Door_Double_01": [0.25, 2.25, 1.97], "SM_Bld_Wall_Door_Double_03": [0.25, 2.25, 1.97],
	"SM_Bld_Wall_Door_Large_01": [0.65, 1.85, 2.6], "SM_Bld_Wall_Door_Large_02": [0.6, 1.9, 2.6], "SM_Bld_Wall_Door_Double_Large_01": [0.3, 2.2, 2.47]}
## Каменное обрамление двери выступает из стены дальше её лица
const DOOR_FRAME := {"SM_Bld_Wall_Door_02": 0.13, "SM_Bld_Wall_Door_03": 0.175}
const IVY := ["SM_Env_Ivy_Flowers_01", "SM_Env_Ivy_Flowers_02", "SM_Env_Ivy_Flowers_03", "SM_Env_Ivy_Flowers_04", "SM_Env_Ivy_Flowers_05"]
## Клетки signs.png (как SIGNS в deploy/kit/kit_houses.py): 6 столбцов × 7 рядов
const SIGNS := ["meat", "bread", "shoes", "dye", "togas", "pots", "oil", "lamps", "wine", "perfume", "jewel", "cloth", "barber", "medic",
	"thermo", "taberna", "fullonica", "mansio", "fruit", "veg", "fish", "fresco", "copper", "grain", "scriptorium", "school", "library",
	"academy", "warehouse", "vigiles", "herbalist", "sculptor", "catshop", "shelter", "balnea", "baths", "prefect", "arch_ins", "relief",
	"puppets", "mimes", "dice"]
## Вывеска над дверью лавки и общественного здания (рисунки Codex)
const TRADE_SIGN := {"butcher": "meat", "bakery": "bread", "cobbler": "shoes", "dyer": "dye", "tailor": "togas", "potter": "pots",
	"oilshop": "oil", "lamps": "lamps", "wineshop": "wine", "perfumer": "perfume", "jeweler": "jewel", "weaver": "cloth", "barber": "barber",
	"medic": "medic", "thermopolium": "thermo", "taberna": "taberna", "fullonica": "fullonica", "mansio": "mansio", "scriptorium": "scriptorium",
	"herbalist": "herbalist", "sculptor": "sculptor", "catshop": "catshop", "shelter": "shelter", "balnea": "balnea", "baths": "baths",
	"prefect": "prefect", "school": "school", "library": "library", "academy": "academy", "warehouse": "warehouse", "vigiles": "vigiles"}
## Товар у входа лавки — вещицы, что жители носят в руках (HandProps): окорока у мясника, сандалии у сапожника, бусы у ювелира
const TRADE_GOODS := {"butcher": "ham", "cobbler": "sandals", "jeweler": "necklace", "wineshop": "grapes"}
const HANG := ["SM_Prop_FlowerPot_Hanging_01", "SM_Prop_FlowerPot_Hanging_02", "SM_Prop_FlowerPot_Hanging_03", "SM_Prop_FlowerPot_Hanging_04"]
## Корзины, мешки и кувшины у входа лавки (сбоку от двери, проход свободен)
const STOCK := [["SM_Prop_Basket_Set_01", 0.42], ["SM_Prop_Sack_Stack_01", 0.42], ["SM_Prop_Basket_Set_02", 0.42], ["SM_Prop_Sack_Stack_02", 0.42],
	["SM_Prop_Jar_Pile_01", 0.5]]
const GRASS := ["SM_Env_Grass_01", "SM_Env_Grass_03", "SM_Env_Grass_01"]
const PEBBLES := ["SM_Env_Pebbles_01", "SM_Env_Pebbles_02"]
const BRICK_VARIANTS := 6


static func dress(b: Bp, type: String) -> void:
	var walls := []
	var ends := []
	var sum := Vector3.ZERO
	for p in b.parts:
		var nm := String(p[0])
		if nm == "SM_Bld_Wall_End_01":
			ends.append(p[1])
			continue
		if not nm.begins_with("SM_Bld_Wall_") or nm.contains("Tiny") or nm.contains("Balcony") or nm.contains("Trim") or nm.contains("Pillar") \
				or nm.contains("End") or nm.contains("Beam"):
			continue
		var xf: Transform3D = p[1]
		if xf.basis.y.length() < 0.9 or xf.basis.x.length() < 0.6:
			continue                                   # низкие парапеты террас и обрезки стен — не трогаем
		var c := xf * Bp.model_aabb(nm).get_center()
		walls.append([nm, xf, c])
		sum += c
	if walls.size() < 2:
		return
	var mid := sum / walls.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([type, b.parts.size(), walls.size(), int(mid.x * 100.0), int(mid.z * 100.0)])
	var shop := not type.begins_with("house_")
	var ivy_left := 2 if rng.randf() < 0.5 else 1
	# насколько у дома облупилась штукатурка: у половины домов — ничуть, у прочих — пара пятен
	var bricky := 0.0 if rng.randf() < 0.45 else rng.randf_range(0.25, 0.5)
	var brick_left := [rng.randi_range(1, 3)]
	var sign_at := []
	var bracket := false
	for w: Array in walls:
		var nm: String = w[0]
		var xf: Transform3D = w[1]
		var c: Vector3 = w[2]
		var along := xf.basis.x.normalized()
		var n := xf.basis.z.normalized()
		var sx := xf.basis.x.length()
		var sy := xf.basis.y.length()
		var out := n if (c - mid).dot(n) > 0.0 else -n
		out.y = 0.0
		if out.length() < 0.5:
			continue
		out = out.normalized()
		var yaw := atan2(out.x, out.z)
		var o := xf.origin
		var ground := o.y < 1.0
		var face := FACE * xf.basis.z.length()
		# along смотрит вдоль стены; если стена повёрнута к нам изнанкой, «вдоль» для глаза снаружи — обратное:
		# у кронштейна и кирпичей это неважно, у вывески над дверью — середина проёма та же
		var at := func(u: float, v: float, d: float) -> Vector3: return o + along * u * sx + Vector3.UP * v * sy + out * (d + face)
		var front := out.z > 0.6
		if nm.contains("Window"):
			# ящики цветов ровно под окнами (у круглых отдушин — нет)
			if WIN.has(nm) and rng.randf() < (0.5 if shop else 0.8):
				var wd: Array = WIN[nm]
				var bx: String = BOXES[rng.randi() % BOXES.size()]
				for e: Array in wd[1]:
					_put(b, bx, at.call(float(e[0]), float(wd[0]) - 0.14, 0.12), yaw, Vector3(float(e[1]) * sx / 1.57 * 1.05, 0.4, 0.34))
			# под высоким подоконником — отбитая штукатурка
			if WIN.has(nm) and float(WIN[nm][0]) > 1.0 and rng.randf() < bricky * 0.7:
				_bricks(b, at.call(rng.randf_range(0.6, 1.9), rng.randf_range(0.45, 0.8), 0.0), yaw, rng, 1.0, brick_left)
			if ground and rng.randf() < 0.35:
				_tuft(b, at, yaw, rng, 0.15 if rng.randf() < 0.5 else 2.35)
		elif nm.contains("Door"):
			var dd: Array = DOOR.get(nm, [0.75, 1.75, 1.97])
			var d0 := float(dd[0])
			var d1 := float(dd[1])
			var top := float(dd[2])
			var fr: float = DOOR_FRAME.get(nm, 0.0)
			if shop:
				if front and ground and TRADE_SIGN.has(type):
					var key := String(TRADE_SIGN[type])
					# вывеска над дверью — потом, над самым широким входом, где над проёмом есть место
					if top + 0.47 + 0.44 < 3.0:
						var hooks := []
						for hu: float in [WALL_W * 0.5 - 0.85, WALL_W * 0.5 + 0.85]:
							hooks.append(at.call(hu, minf(top + 0.05, 2.05), 0.2 + fr))
						sign_at.append([d1 - d0, at.call((d0 + d1) * 0.5, top + 0.47, 0.03 + fr), yaw, hooks])
					if not bracket:
						# вывеска на железном кронштейне поперёк стены — видна вдоль улицы
						var bu := d1 + 0.28 if d1 + 0.28 < WALL_W - 0.12 else d0 - 0.28
						if bu > 0.12:
							bracket = true
							_put(b, "#bsign:" + key, at.call(bu, 2.42, 0.0), yaw, Vector3.ONE * 1.1)
					# корзины и мешки сбоку от входа
					for side: float in [d0 - 0.4, d1 + 0.4]:
						if side > 0.25 and side < WALL_W - 0.25 and rng.randf() < 0.7:
							var st: Array = STOCK[rng.randi() % STOCK.size()]
							_put(b, String(st[0]), at.call(side, 0.0, 0.3 + fr), yaw + rng.randf_range(-0.4, 0.4), Vector3.ONE * float(st[1]))
				if ground and rng.randf() < 0.4:
					_tuft(b, at, yaw, rng, 0.12 if d0 > 0.5 else 2.38)
				continue
			if ground and rng.randf() < 0.8 and d0 > 0.5:
				for side: float in [d0 - 0.3, d1 + 0.3]:
					if rng.randf() < 0.8:
						var p0: Vector3 = at.call(side, 0.0, 0.32 + fr)
						_put(b, "SM_Prop_Vase_03", p0, rng.randf() * TAU, Vector3.ONE * 0.62)
						_put(b, CatDecor.BLOOMS[rng.randi() % CatDecor.BLOOMS.size()], p0 + Vector3(0, 0.36, 0), rng.randf() * TAU, Vector3.ONE * 0.22,
							{"tint": CatDecor.TRUE_COLOR})
			if rng.randf() < 0.55 and top < 2.3:
				_put(b, HANG[rng.randi() % HANG.size()], at.call(WALL_W - 0.3 if rng.randf() < 0.5 else 0.3, 2.45, 0.3), yaw, Vector3.ONE * 0.42)
			elif d0 > 0.6 and rng.randf() < bricky * 0.6:
				_bricks(b, at.call(d0 * 0.45 if rng.randf() < 0.5 else (d1 + WALL_W) * 0.5 + 0.05, rng.randf_range(1.05, 1.5), 0.0), yaw, rng, 0.7, brick_left)
		else:
			var ivy := false
			if ivy_left > 0 and rng.randf() < 0.6:
				ivy_left -= 1
				ivy = true
				_put(b, IVY[rng.randi() % IVY.size()], at.call(WALL_W * (0.3 if rng.randf() < 0.5 else 0.7), 0.95, 0.02), yaw, Vector3(0.9, 1.15, 1.0))
			if nm == "SM_Bld_Wall_01" and not ivy and bricky > 0.0 and rng.randf() < bricky + 0.15:
				# кирпич под облупившейся штукатуркой: чаще внизу, у земли, иногда под карнизом
				var v := rng.randf_range(0.45, 1.0) if rng.randf() < 0.6 else rng.randf_range(1.5, 2.3)
				_bricks(b, at.call(rng.randf_range(0.55, 1.95), v, 0.0), yaw, rng, 1.0, brick_left)
				if rng.randf() < 0.3:
					_bricks(b, at.call(rng.randf_range(0.5, 2.0), clampf(3.0 - v, 0.5, 2.3), 0.0), yaw, rng, 0.65, brick_left)
			if ground and rng.randf() < 0.55:
				_tuft(b, at, yaw, rng, rng.randf_range(0.2, 2.3))
	if not sign_at.is_empty():
		sign_at.sort_custom(func(a: Array, c: Array) -> bool: return float(a[0]) > float(c[0]))
		var sg: Array = sign_at[0]
		var key := String(TRADE_SIGN[type])
		# вывеска над дверью, крупно; по бокам — товар на крюках
		_put(b, "#sign:" + key, sg[1], sg[2], Vector3(1.22, 1.22, 1.0))
		if TRADE_GOODS.has(type):
			for hp: Vector3 in sg[3]:
				_put(b, "#hp_" + String(TRADE_GOODS[type]), hp, float(sg[2]) + rng.randf_range(-0.3, 0.3), Vector3.ONE * 0.75)
	# каменные блоки на углах дома (через этаж кладка в перевязку), у части домов
	if rng.randf() < 0.6:
		for xf: Transform3D in ends:
			var rot := xf.basis.orthonormalized()
			var floors := maxi(1, int(round(xf.basis.y.length())))
			for k in floors:
				var p0 := xf.origin + Vector3.UP * Bp.FL * k
				_put_xf(b, "#quoin_%d" % (0 if p0.y < 1.0 else 1), Transform3D(rot, p0))


## Трава и камешки у подножия стены (u — место вдоль стены)
static func _tuft(b: Bp, at: Callable, yaw: float, rng: RandomNumberGenerator, u: float) -> void:
	_put(b, GRASS[rng.randi() % GRASS.size()], at.call(u, 0.0, 0.06), yaw + rng.randf_range(-0.5, 0.5), Vector3.ONE * rng.randf_range(0.28, 0.42))
	if rng.randf() < 0.35:
		_put(b, PEBBLES[rng.randi() % PEBBLES.size()], at.call(u + rng.randf_range(-0.3, 0.3), 0.0, 0.12), rng.randf() * TAU, Vector3.ONE * rng.randf_range(0.14, 0.22))


static func _bricks(b: Bp, p: Vector3, yaw: float, rng: RandomNumberGenerator, s := 1.0, left := [1]) -> void:
	if int(left[0]) <= 0:
		return
	left[0] = int(left[0]) - 1
	_put(b, "#bricks_%d" % (rng.randi() % BRICK_VARIANTS), p, yaw, Vector3.ONE * s * rng.randf_range(0.85, 1.15))


static func _put(b: Bp, nm: String, p: Vector3, yaw: float, s: Vector3, remap := {}) -> void:
	b.free_parts[b.parts.size()] = true
	b.parts.append([nm, Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(s), p), remap])


static func _put_xf(b: Bp, nm: String, xf: Transform3D) -> void:
	b.free_parts[b.parts.size()] = true
	b.parts.append([nm, xf, {}])


## Свои детали (Parts._special_mesh): #sign:<клетка>, #bsign:<клетка>, #bricks_<n>, #quoin_<0|1>
static func kit_mesh(name: String) -> Mesh:
	if name.begins_with("#sign:"):
		return sign_mesh(name.substr(6))
	if name.begins_with("#bsign:"):
		return bracket_sign_mesh(name.substr(7))
	if name.begins_with("#bricks_"):
		return bricks_mesh(int(name.substr(8)))
	if name.begins_with("#quoin_"):
		return quoin_mesh(int(name.substr(7)))
	return null


static func _cell_uv(key: String) -> Rect2:
	var i := maxi(0, SIGNS.find(key))
	var cx := i % 6
	var cy := i / 6
	return Rect2(cx / 6.0 + 0.002, cy / 7.0 + 0.002, 1.0 / 6.0 - 0.004, 1.0 / 7.0 - 0.004)


## Картинка-четырёхугольник: углы a-b-c-d против часовой, если смотреть снаружи; ua… — их UV.
## В Godot лицевая сторона — по часовой, поэтому вершины идут в обратном порядке (как Kit.tri).
static func _pic(st: SurfaceTool, q: Array, uv: Array, nrm: Vector3) -> void:
	st.set_normal(nrm)
	for i: int in [0, 2, 1, 0, 3, 2]:
		st.set_uv(uv[i])
		st.add_vertex(q[i])


static var _sign_mat: StandardMaterial3D
static func _sign_material() -> StandardMaterial3D:
	if _sign_mat == null:
		_sign_mat = StandardMaterial3D.new()
		_sign_mat.albedo_texture = load("res://assets/kit/tex/signs.png")
		_sign_mat.roughness = 0.8
	return _sign_mat


## Вывеска на стене: доска из тёмного дерева, на лицевой стороне (+Z) — клетка signs.png; 1 × 0,67 (единицы чертежа)
static func sign_mesh(key: String) -> Mesh:
	var r := _cell_uv(key)
	var k := Kit.new()
	k.boxc(Vector3(0, 0, 0.0), Vector3(1.08, 0.74, 0.05), Color("5a3a22"), [])
	var am := k.mesh()
	am.surface_set_material(0, Kit.material(0.85))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.5
	var h := 0.335
	var z := 0.027
	_pic(st, [Vector3(-w, -h, z), Vector3(w, -h, z), Vector3(w, h, z), Vector3(-w, h, z)],
		[Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.position.y)], Vector3(0, 0, 1))
	st.commit(am)
	am.surface_set_material(1, _sign_material())
	return am


## Вывеска на кронштейне: железный прут из стены (+Z — от стены), под ним на кольцах доска поперёк стены,
## рисунок с обеих сторон (видно вдоль улицы). Начало — точка крепления на лице стены.
static func bracket_sign_mesh(key: String) -> Mesh:
	var r := _cell_uv(key)
	var k := Kit.new()
	var iron := Color("2b2622")
	k.rod(Vector3(0, 0, -0.02), Vector3(0, 0, 0.98), 0.022, 6, iron)
	k.rod(Vector3(0, -0.42, -0.02), Vector3(0, -0.02, 0.6), 0.016, 5, iron)            # подкос
	k.boxc(Vector3(0, 0, 0.0), Vector3(0.08, 0.1, 0.04), iron, [])                     # накладка на стене
	k.boxc(Vector3(0, -0.42, 0.0), Vector3(0.07, 0.08, 0.04), iron, [])
	k.cyl(Vector3(0, -0.035, 0.98), 0.035, 0.07, 6, iron)                              # шарик на конце
	for z: float in [0.25, 0.85]:
		k.rod(Vector3(0, 0, z), Vector3(0, -0.1, z), 0.008, 4, iron)                    # кольца
	var bh := 0.5
	var y0 := -0.1
	k.box(Vector3(-0.026, y0 - bh, 0.17), Vector3(0.026, y0, 0.93), Color("5a3a22"), [])
	k.box(Vector3(-0.03, y0 - 0.035, 0.15), Vector3(0.03, y0, 0.95), Color("3e2716"), [])    # верхняя планка
	var am := k.mesh()
	am.surface_set_material(0, Kit.material(0.8))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ya := y0 - bh + 0.03
	var yb := y0 - 0.05
	var za := 0.2
	var zb := 0.9
	var uvl := [Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.position.y)]
	# сторона +X: смотрящему «вправо» — это −Z
	_pic(st, [Vector3(0.028, ya, zb), Vector3(0.028, ya, za), Vector3(0.028, yb, za), Vector3(0.028, yb, zb)], uvl, Vector3(1, 0, 0))
	# сторона −X: «вправо» — это +Z
	_pic(st, [Vector3(-0.028, ya, za), Vector3(-0.028, ya, zb), Vector3(-0.028, yb, zb), Vector3(-0.028, yb, za)], uvl, Vector3(-1, 0, 0))
	st.commit(am)
	am.surface_set_material(1, _sign_material())
	return am


## Отбитая штукатурка: рваное пятно кирпичной кладки на лице стены (+Z — наружу), середина — начало координат.
## Тонкие римские кирпичи рядами вперевязку на светлом растворе, вокруг — тёмный край штукатурки.
const BRICK_COLS := ["a8634a", "9a5842", "b5715a", "8f5240", "b07d64", "9e6450", "a96e55"]
static func bricks_mesh(variant: int) -> Mesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7151 + variant * 97
	var k := Kit.new()
	var rows := rng.randi_range(5, 8)
	var bh := 0.062
	var gap := 0.016
	var pitch := bh + gap
	var bl := 0.24
	var hw := rng.randf_range(0.34, 0.5)
	var y_lo := -rows * pitch * 0.5
	var cx := 0.0
	for r in rows:
		var t := (r + 0.5) / rows * 2.0 - 1.0
		var w := hw * sqrt(maxf(0.0, 1.0 - t * t * 0.85)) * rng.randf_range(0.72, 1.12)
		cx = clampf(cx + rng.randf_range(-0.06, 0.06), -0.08, 0.08)
		var x0 := cx - w
		var x1 := cx + w
		var y := y_lo + r * pitch
		# край штукатурки и раствор (ступеньками по рядам, как отваливается штукатурка)
		k.box(Vector3(x0 - 0.03, y - 0.015, 0.0), Vector3(x1 + 0.03, y + pitch + 0.015, 0.004), Color("86664f"), ["bottom", "z-"])
		k.box(Vector3(x0 - 0.01, y, 0.0), Vector3(x1 + 0.01, y + pitch, 0.008), Color("bfae92"), ["bottom", "z-"])
		var off := (bl + gap) * 0.5 if r % 2 == 1 else 0.0
		var bx := x0 - off
		while bx < x1:
			var a := maxf(bx, x0)
			var e := minf(bx + bl, x1)
			if e - a > 0.05:
				var col := Color(BRICK_COLS[rng.randi() % BRICK_COLS.size()]).lerp(Color("6e3a26"), rng.randf() * 0.15)
				k.box(Vector3(a, y + gap * 0.5, 0.008), Vector3(e, y + gap * 0.5 + bh, rng.randf_range(0.018, 0.026)), col, ["bottom", "z-"])
			bx += bl + gap
	var am := k.mesh()
	am.surface_set_material(0, Kit.material(0.92))
	return am


## Угловые камни (кладка в перевязку): начало — середина торца угла Synty (SM_Bld_Wall_End_01), наружу — −X и +Z;
## 0 — первый этаж (над цоколем), 1 — верхние этажи (под карнизом)
static func quoin_mesh(variant: int) -> Mesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 911 + variant
	var k := Kit.new()
	var cx := -FACE
	var cz := FACE
	var t := 0.032
	var y := 0.48 if variant == 0 else 0.12
	var y_end := 2.62
	var n := int((y_end - y) / 0.36)
	var pitch := (y_end - y) / n
	var hgt := pitch - 0.035
	for i in n:
		var col := Color("dccfb6").lerp(Color("bfae92"), rng.randf() * 0.6)
		var long_a := i % 2 == 0
		var la := 0.46 if long_a else 0.28
		var lb := 0.28 if long_a else 0.46
		var y0 := y + i * pitch
		k.box(Vector3(cx - t, y0, cz), Vector3(cx + la, y0 + hgt, cz + t), col)            # по лицу +Z
		k.box(Vector3(cx - t, y0, cz - lb), Vector3(cx, y0 + hgt, cz), col)                # по лицу −X
	var am := k.mesh()
	am.surface_set_material(0, Kit.material(0.9))
	return am
