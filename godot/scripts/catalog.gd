class_name Catalog
extends RefCounted
## Облик построек — как в Town to City: у каждого типа несколько продуманных фасадов (variant),
## дом растёт этажами (tier = этажи), цвет штукатурки — из палитры (color). Всё собрано из деталей Synty.

const M := Bp.M
const FL := Bp.FL

static var _cache := {}


static func make(type: String, tier := 1, variant := 0, color := 0) -> Bp:
	var key := "%s:%d:%d:%d" % [type, tier, variant, color]
	if _cache.has(key):
		return _cache[key]
	var b := Bp.new(hash(key))
	b.paint(color)
	match type:
		"house_pleb": _house_pleb(b, tier, variant)
		"house_artisan": _house_artisan(b, tier, variant)
		"house_patrician": _house_patrician(b, tier, variant)
		"stall_fruit": _stall(b, "fruit", variant)
		"stall_veg": _stall(b, "veg", variant)
		"stall_fish": _stall(b, "fish", variant)
		"butcher", "bakery", "cobbler", "dyer", "tailor", "potter", "oilshop", "lamps", "wineshop", "perfumer", "jeweler", "weaver", "barber", "medic":
			_shop(b, type, variant)
		"thermopolium": _thermopolium(b)
		"taberna": _taberna(b)
		"fullonica": _fullonica(b)
		"musicians": _musicians(b)
		"dice": _dice(b)
		"mimes": _mimes(b)
		"odeon": _odeon(b)
		"theatre": _theatre(b)
		"balnea": _balnea(b)
		"baths": _baths(b)
		"farm": _farm(b)
		"grove": _grove(b)
		"vineyard": _vineyard(b)
		"warehouse": _warehouse(b)
		"scriptorium": _scriptorium(b)
		"school": _school(b)
		"library": _library(b)
		"academy": _academy(b)
		"fountain": _fountain(b)
		"temple": _temple(b)
		"forum": _forum(b)
		"arch": _arch(b)
		"colosseum": _colosseum(b)
		"pantheon": _pantheon(b)
		"center": _center(b, tier)
		_: _decor(b, type)
	b.base = Transform3D.IDENTITY
	_actors(b, type, tier)
	_cache[key] = b
	return b


# ---------- жильё ----------

## Дом плебеев 5×5 м: пять фасадов, 1–3 этажа
static func _house_pleb(b: Bp, floors: int, v: int) -> void:
	floors = clampi(floors, 1, 3)
	var di := b.rng.randi() % 2
	var top := floors * FL
	match v % 5:
		0:
			# классика: черепица, кашпо под окнами, клумба у двери
			b.block(0, 0, 2, 2, floors, {"door_i": di, "win_p": 0.85})
			b.gable(0, 0, 2, 2, top)
			b.door_decor(0, 0, 2, 2, di)
			for f in floors:
				b.window_pots(0, 0, 2, 2, f)
			b.add("SM_Prop_FlowerBed_0%d" % (1 + b.rng.randi() % 2), Vector3(1.25 if di == 0 else -1.25, 0.35, 2.58), 0.0, 0.8)
			if floors >= 2:
				b.balcony(0, 0, 2, 2, 1 - di, 1)
		1:
			# плоская крыша-терраса с перголой и лозой
			b.block(0, 0, 2, 2, floors, {"door_i": di, "roof_trim": false, "win_p": 0.8})
			b.flat_roof(0, 0, 2, 2, top)
			b.roof_pergola(-2.5 if di == 1 else 0.0, -2.5, top)
			b.add("SM_Prop_FlowerPot_Fancy_01", Vector3(1.7 if di == 1 else -1.7, top, 1.7), 0.0, 0.7)
			b.add("SM_Env_Garden_Plants_0%d" % (3 + b.rng.randi() % 4), Vector3(-1.6 if di == 1 else 1.6, top, 1.6), 0.0, 0.5)
			b.door_decor(0, 0, 2, 2, di)
			if floors >= 2:
				b.balcony(0, 0, 2, 2, 1 - di, floors - 1)
			b.ivy(0, 0, 2, 2, floors)
		2:
			# лавочка внизу, фронтон к улице
			b.block(0, 0, 2, 2, floors, {"door_i": di, "shop": [1 - di], "win_p": 0.8})
			b.gable_z(0, 0, 2, 2, top)
			b.shop_front(0, 0, 2, 2, 1 - di)
			for f in range(1, floors):
				b.window_pots(0, 0, 2, 2, f)
			if floors >= 2:
				b.wall_banner(0, 0, 2, 2, 0.5 if di == 1 else 1.5, 2 * FL - 0.35)
		3:
			# кирпичный низ, деревянный балкон с ковром, плющ до крыши
			b.ground_style = "brick"
			b.block(0, 0, 2, 2, floors, {"door_i": di, "door": "SM_Bld_Wall_Door_03", "win_p": 0.9})
			b.gable(0, 0, 2, 2, top)
			if floors >= 2:
				b.balcony(0, 0, 2, 2, 1 - di, 1)
			b.ivy(0, 0, 2, 2, floors)
			b.add("SM_Prop_Seat_Bench_0%d" % (1 + b.rng.randi() % 3), Vector3(1.25 if di == 0 else -1.25, 0, 3.0), 0.0, 0.9)
			b.add("SM_Prop_FlowerPot_Fancy_01", Vector3(-0.15 if di == 0 else 0.15, 0.0, 2.95), 0.0, 0.7)
		_:
			# дом в глубине с палисадником: плетень, скамья, цветы, кувшины
			b.block(0, -1.25, 2, 1, floors, {"door_i": di, "door": "SM_Bld_Wall_Door_04", "win_p": 0.9})
			b.gable(0, -1.25, 2, 1, top)
			var ox := 1.25 if di == 0 else -1.25
			for x: float in [-2.45, 0.05]:
				if absf(x + 1.2 - ox) < 0.5:
					b.add("SM_Env_Fence_Woof_0%d" % (1 + b.rng.randi() % 3), Vector3(x, 0, 2.4), 0.0, 0.96)
			b.add("SM_Env_Fence_Woof_Gate_01", Vector3(-ox - 1.2, 0, 2.4), 0.0, 0.96)
			b.add("SM_Prop_Seat_Bench_0%d" % (1 + b.rng.randi() % 3), Vector3(ox, 0, 0.6), 0.0, 0.85)
			b.plants(ox - 1.0, 1.4, ox + 1.0, 2.1, 3)
			b.add("SM_Prop_Jar_01", Vector3(-ox * 1.7, 0, 0.5), 0.0, 0.8)
			b.add("SM_Env_Tree_Thin_0%d" % (1 + b.rng.randi() % 2), Vector3(ox * 1.6, 0, 1.9), 0.0, 0.35)
			if floors >= 2:
				b.window_pots(0, -1.25, 2, 1, 1)


## Дом ремесленников 7,5×5 м: мастерская внизу, жильё сверху
static func _house_artisan(b: Bp, floors: int, v: int) -> void:
	floors = clampi(floors, 1, 3)
	var top := floors * FL
	var craft := v % 3
	match v % 5:
		0, 3:
			# мастерская с широкими проёмами и навесами, двускатная крыша
			b.block(0, 0, 3, 2, floors, {"door_i": 0, "shop": [1, 2], "win_p": 0.85})
			b.gable(0, 0, 3, 2, top)
			b.on_wall("SM_Prop_Overhang_01", 0, 0, 3, 2, 0, 1.5, 2.75, 0.12)
			b.on_wall("SM_Prop_Overhang_01", 0, 0, 3, 2, 0, 2.5, 2.75, 0.12)
			_craft(b, craft, Vector3(1.25, 0, 3.4))
			for f in range(1, floors):
				b.window_pots(0, 0, 3, 2, f)
			if floors >= 2:
				b.balcony(0, 0, 3, 2, 0, 1)
		1, 4:
			# угловой: жилой блок и пристройка-мастерская с террасой
			b.block(-1.25, 0, 2, 2, floors, {"door_i": 0, "win_p": 0.85})
			b.gable_z(-1.25, 0, 2, 2, top)
			b.block(2.5, 0, 1, 2, 1, {"door_i": -1, "shop": [0], "roof_trim": false, "sides": [0, 1, 2]})
			b.flat_roof(2.5, 0, 1, 2, FL)
			b.add("SM_Env_Garden_Plants_0%d" % (3 + b.rng.randi() % 4), Vector3(2.5, FL, 0.0), 0.0, 0.5)
			b.on_wall("SM_Prop_Overhang_02", 2.5, 0, 1, 2, 0, 0.5, 2.75, 0.12)
			_craft(b, craft, Vector3(2.5, 0, 3.3))
			b.door_decor(-1.25, 0, 2, 2, 0)
			if floors >= 2:
				b.balcony(-1.25, 0, 2, 2, 1, 1)
			b.ivy(-1.25, 0, 2, 2, floors)
		_:
			# с аркадой: колонны перед мастерской, наверху балконы
			b.block(0, -0.6, 3, 2, floors, {"door_i": 1, "shop": [0, 2], "win_p": 0.9})
			b.gable(0, -0.6, 3, 2, top)
			b.portico(-3.75, 3.75, 2.55, 0.65, 0.9, "SM_Bld_Pillar_0%d" % (1 + b.rng.randi() % 3), true)
			_craft(b, craft, Vector3(-2.5, 0, 1.6))
			for f in range(1, floors):
				b.window_pots(0, -0.6, 3, 2, f)
	if b.door.z < 2.0:
		b.door = Vector3(b.door.x, 0, 3.0)


static func _craft(b: Bp, kind: int, p: Vector3) -> void:
	match kind:
		0:
			# ткач: станок, рулоны, корзины шерсти
			b.add("SM_Prop_Loom_01", p + Vector3(-0.6, 0, -0.4), 0.0, 0.85)
			b.add("SM_Prop_Rug_Stack_01", p + Vector3(0.8, 0, -0.5), 0.3, 0.8)
			b.add("SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 5), p + Vector3(1.3, 0, 0.2), 0.0)
		1:
			# гончар: печь, амфоры, круг
			b.add("SM_Prop_Kiln_01", p + Vector3(-0.7, 0, -0.5), PI, 0.6)
			b.add("SM_Prop_Vase_Pile_0%d" % (1 + b.rng.randi() % 6), p + Vector3(0.9, 0, -0.4), 0.0, 0.8)
			b.add("SM_Prop_Jar_01", p + Vector3(1.4, 0, 0.2), 0.0, 0.8)
		_:
			# кузнец: наковальня, точило, стойка
			b.add("SM_Prop_Anvil_01", p + Vector3(-0.5, 0, -0.3), 0.4, 0.9)
			b.add("SM_Prop_Grinding_Wheel_01", p + Vector3(0.9, 0.32, -0.4), 1.2, 0.9)
			b.add("SM_Prop_Barrel_01" if Synty.has("SM_Prop_Barrel_01") else "SM_Prop_Jar_01", p + Vector3(1.5, 0, 0.1), 0.0, 0.8)


## Домус патрициев 10×10 м: дом с портиком, сад с фонтанчиком и статуями; 1–2 этажа
static func _house_patrician(b: Bp, floors: int, v: int) -> void:
	floors = clampi(floors, 1, 2)
	var top := floors * FL
	var pillar := "SM_Bld_Pillar_0%d" % [2, 1, 4, 5][v % 4]
	b.block(0, -1.25, 4, 2, floors, {"door_i": 1, "door": "SM_Bld_Wall_Door_Double_01", "win_p": 0.75})
	var ridge := b.gable(0, -1.25, 4, 2, top) if v % 2 == 0 else top
	if v % 2 == 1:
		b.flat_roof(0, -1.25, 4, 2, top)
		b.roof_pergola(2.5, -3.75, top)
		b.add("SM_Prop_Statue_0%d" % (1 + b.rng.randi() % 7), Vector3(-3.4, top, 0.6), 0.0, 0.5)
	b.portico(-5.0, 5.0, 2.9, 0.0, 0.92, pillar, v >= 2)
	b.add("SM_Prop_Rug_01", Vector3(-1.25, 0.01, 1.4), PI / 2, 0.8)
	b.light(Vector3(-1.25, 2.3, 2.6))
	# сад сзади: фонтанчик, деревья, клумбы, скамья
	b.add("SM_Prop_Fountain_04", Vector3(0, 0, -4.4), 0.0, 0.4)
	b.add("SM_Prop_Fountain_04_Insert_01", Vector3(0, 0, -4.4), 0.0, 0.4)
	b.add("SM_Env_Tree_Thin_0%d" % (1 + b.rng.randi() % 2), Vector3(-4.2, 0, -4.4), 0.0, 0.55)
	b.add("SM_Env_Tree_Palm_0%d" % (1 + b.rng.randi() % 3), Vector3(4.2, 0, -4.3), 0.0, 0.35)
	b.plants(-3.2, -4.9, 3.2, -3.9, 3)
	b.add("SM_Prop_Seat_Kline_0%d" % (1 + b.rng.randi() % 3), Vector3(-2.3, 0, -4.3), 0.0, 0.8)
	# перед домом: клумбы и статуи на колоннах
	b.add("SM_Prop_FlowerBed_01", Vector3(-3.4, 0.4, 4.3), 0.0)
	b.add("SM_Prop_FlowerBed_02", Vector3(1.6, 0.4, 4.3), 0.0)
	b.column_statue(Vector3(4.3, 0, 4.3), 0.0, 0.75)
	if floors >= 2:
		b.window_pots(0, -1.25, 4, 2, 1)
		b.balcony(0, -1.25, 4, 2, 3, 1)
		b.wall_banner(0, -1.25, 4, 2, 0.5, 2 * FL - 0.35)
		b.brazier(Vector3(-4.6, 0, 3.4), true)
		b.add("SM_Prop_Statue_Lion_01", Vector3(-2.4, 0, 4.6), 0.0, 0.3)
	b.ivy(0, -1.25, 4, 2, floors)
	b.door = Vector3(-1.25, 0, 5.2)


# ---------- коммерция ----------

## Цвет полотняного навеса: красный как есть, остальные — светлая ткань, подкрашенная в цвет
const CANOPY := [Color(1, 1, 1), Color(0.55, 0.78, 0.95), Color(1.0, 0.86, 0.45), Color(0.62, 0.86, 0.55), Color(1.0, 0.62, 0.5), Color(0.86, 0.7, 0.95)]


static func canopy_remap(i: int) -> Dictionary:
	var k := posmod(i, CANOPY.size())
	if k == 0:
		return {}
	return {"PolygonAncientEmpire_01_A": "PolygonAncientEmpire_01_C", "tints": {"PolygonAncientEmpire_01_C": CANOPY[k]}}

## Лавка под навесом 3×3 м: стол с товаром, корзины, мешки
static func _stall(b: Bp, kind: String, v: int) -> void:
	var c := Vector3(-1.3, 0, -1.3)
	var cr := canopy_remap(v + kind.length())
	for d: Vector3 in [Vector3(0, 0, 0), Vector3(2.6, 0, 0), Vector3(0, 0, 2.6), Vector3(2.6, 0, 2.6)]:
		b.add("SM_Prop_Pole_01", c + d, 0.0, 0.92)
	b.parts.append([["SM_Prop_Banner_Roof_01", "SM_Prop_Banner_Roof_03"][v % 2], b.base * Transform3D(Basis.IDENTITY, c + Vector3(0, 2.78, 0)), cr])
	b.add("SM_Prop_Table_08", Vector3(0, 0, 0.55), 0.0, 0.85)
	var goods: Array
	match kind:
		"fruit": goods = ["SM_Prop_Basket_Insert_01", "SM_Prop_Bowl_0%d", "SM_Prop_Basket_Insert_02"]
		"veg": goods = ["SM_Prop_Basket_Insert_04", "SM_Prop_Basket_Insert_02", "SM_Prop_Basket_0%d"]
		_: goods = ["SM_Prop_Plate_0%d", "SM_Prop_Basket_Insert_03", "SM_Prop_Bowl_0%d"]
	for k in 3:
		var nm: String = goods[k]
		if nm.contains("%d"):
			nm = nm % (1 + b.rng.randi() % 3)
		if nm.contains("Insert"):
			b.add("SM_Prop_Basket_0%d" % (1 + k), Vector3(-0.75 + k * 0.75, 0.66, 0.55), 0.0, 0.7)
		b.add(nm, Vector3(-0.75 + k * 0.75, 0.7, 0.55), b.rng.randf() * TAU, 0.7)
	b.add("SM_Prop_Basket_Set_0%d" % (1 + b.rng.randi() % 5), Vector3(1.0, 0, 1.4), b.rng.randf() * TAU, 0.75)
	b.add(b.pick(["SM_Prop_Sack_Stack_01", "SM_Prop_Jar_Pile_01", "SM_Prop_Vase_Pile_02"]), Vector3(-1.0, 0, -0.8), b.rng.randf() * TAU, 0.7)
	b.add("SM_Prop_Rug_0%d" % (5 + b.rng.randi() % 2), Vector3(0, 0.01, 1.35), PI / 2, 0.6)
	b.door = Vector3(0, 0, 1.9)


## Лавки-домики трёх видов: с полотняным навесом над прилавком, мастерская фронтоном к улице
## с фреской у входа, нарядная двухэтажная лавка с террасой. Перед входом — товар своего ремесла
static func _shop(b: Bp, type: String, v: int) -> void:
	var col: int = {"butcher": 1, "bakery": 7, "cobbler": 9, "dyer": 4, "tailor": 6, "potter": 0, "oilshop": 5, "lamps": 3,
		"wineshop": 8, "perfumer": 2, "jeweler": 6, "weaver": 3, "barber": 4, "medic": 5}.get(type, 0)
	b.paint(col)
	var layout: String = {"butcher": "awning", "cobbler": "awning", "potter": "awning", "oilshop": "awning", "wineshop": "awning", "lamps": "awning",
		"weaver": "work", "tailor": "work", "dyer": "work", "barber": "work", "medic": "work", "bakery": "work",
		"perfumer": "fancy", "jeweler": "fancy"}.get(type, "work")
	var t := Vector3(0, 0, 1.2)
	match layout:
		"awning":
			b.block(0, -1.25, 2, 1, 1, {"door_i": 0, "shop": [1], "win_p": 0.5})
			b.gable(0, -1.25, 2, 1, FL, false)
			for x: float in [-2.5, 2.5]:
				b.add("SM_Prop_Pole_01", Vector3(x, 0, 2.5), 0.0, 0.85)
			b.parts.append(["SM_Prop_Banner_Roof_02", Transform3D(Basis.IDENTITY, Vector3(-2.5, 2.5, 0.0)), canopy_remap(type.length() + v)])
			b.add("SM_Prop_Table_08", Vector3(1.0, 0, 1.3), 0.0, 0.85)
			t = Vector3(1.0, 0, 1.3)
		"work":
			b.ground_style = "plain"
			b.remap = b.floor_remap(0)
			b.block(0, -1.25, 2, 1, 1, {"door_i": 0, "shop": [1], "win_p": 0.0, "sides": [0, 1, 2, 3]})
			b.gable_z(0, -1.25, 2, 1, FL)
			b.add("SM_Prop_Overhang_01", Vector3(1.25, 2.75, 0.12), 0.0)
			b.add("SM_Prop_Mural_0%d" % (1 + (type.length() % 2)), Vector3(-1.25, 1.3, 0.13), 0.0, 0.8)
			t = Vector3(1.25, 0, 1.2)
		_:
			b.block(0, -1.25, 2, 2, 2, {"door_i": 0, "shop": [1], "roof_trim": false, "win_p": 0.9})
			b.flat_roof(0, -1.25, 2, 2, 2 * FL)
			b.roof_pergola(0.0, -3.75, 2 * FL)
			b.add("SM_Prop_FlowerPot_Fancy_01", Vector3(-1.7, 2 * FL, -0.4), 0.0, 0.7)
			b.balcony(0, -1.25, 2, 2, 0, 1)
			b.add("SM_Prop_Overhang_01", Vector3(1.25, 2.75, 1.37), 0.0)
			b.window_pots(0, -1.25, 2, 2, 1)
			t = Vector3(1.25, 0, 2.3)
	b.wall_banner(0, -1.25, 2, 1 if layout != "fancy" else 2, 0.5 if layout == "awning" else 1.5, 2.5)
	match type:
		"butcher":
			b.add("SM_Prop_Basket_Insert_03", t + Vector3(-0.4, 0.66, 0), 0.0, 0.7)
			b.add("SM_Prop_Pots_Hanging_01", Vector3(1.0, 2.2, 1.0), 0.0)
			b.add("SM_Prop_Jar_Pile_01", Vector3(-1.4, 0, 1.0), 0.0, 0.7)
		"bakery":
			b.add("SM_Prop_Kiln_01", Vector3(-1.4, 0, 1.0), PI, 0.65)
			b.light(Vector3(-1.4, 0.6, 1.6))
			b.add("SM_Prop_Table_05", t, PI / 2, 0.9)
			b.add("SM_Prop_Basket_Insert_02", t + Vector3(0, 0.74, 0), 0.0, 0.8)
			b.add("SM_Prop_Sack_Stack_01", Vector3(2.0, 0, 2.2), 0.4, 0.75)
		"cobbler":
			b.add("SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 5), t + Vector3(-0.4, 0.66, 0), 0.0, 0.6)
			b.add("SM_Prop_Shelf_01", Vector3(-1.2, 0, 0.5), 0.0, 0.7)
			b.add("SM_Prop_Seat_Stool_01", Vector3(-1.4, 0, 1.6), 0.0)
		"dyer":
			for k in 3:
				b.add("SM_Prop_Jar_01", Vector3(-1.9 + k * 0.7, 0, 1.6), 0.0, 1.05)
			b.add("SM_Prop_Rug_Folded_0%d" % (1 + b.rng.randi() % 3), t, 0.3)
			b.add("SM_Prop_Pole_01", Vector3(2.2, 0, 2.4), 0.0, 0.7)
			b.add("SM_Prop_Rug_Drape_01", Vector3(2.2, 1.8, 2.4), PI / 2, 0.8)
		"tailor", "weaver":
			b.add("SM_Prop_Loom_01", Vector3(-1.3, 0, 1.0), 0.0, 0.85)
			b.add("SM_Prop_Rug_Stack_0%d" % (1 + b.rng.randi() % 2), t, 0.0, 0.8)
			b.add("SM_Prop_Rug_Folded_0%d" % (1 + b.rng.randi() % 3), Vector3(2.1, 0, 2.0), 0.4)
		"potter":
			b.add("SM_Prop_Vase_Pile_0%d" % (1 + b.rng.randi() % 6), Vector3(-1.4, 0, 1.2), 0.0, 0.85)
			b.add("SM_Prop_Vase_0%d" % (1 + b.rng.randi() % 5), t + Vector3(-0.3, 0.66, 0), 0.0, 0.6)
			b.add("SM_Prop_Bowl_0%d" % (1 + b.rng.randi() % 5), t + Vector3(0.4, 0.66, 0), 0.0, 0.8)
		"oilshop", "wineshop":
			b.add("SM_Prop_Jar_Pile_01", Vector3(-1.4, 0, 1.1), 0.0, 0.9)
			b.add("SM_Prop_Jug_0%d" % (1 + b.rng.randi() % 5), t + Vector3(-0.3, 0.66, 0), 0.0, 0.7)
			b.add("SM_Prop_Vase_0%d" % (1 + b.rng.randi() % 5), t + Vector3(0.4, 0.66, 0), 0.0, 0.6)
		"lamps":
			b.add("SM_Prop_Senser_03", t + Vector3(-0.3, 0.66, 0), 0.0, 0.5)
			b.add("SM_Prop_Senser_01", Vector3(-1.4, 0, 1.3), 0.0, 0.85)
			b.add("SM_Prop_Torch_02", Vector3(-1.9, 1.8, 0.15), 0.0)
			b.light(Vector3(-1.9, 2.1, 0.4))
		"perfumer", "jeweler":
			b.add("SM_Prop_Table_03", t, 0.0, 0.85)
			b.add("SM_Prop_Goblet_0%d" % (1 + b.rng.randi() % 2), t + Vector3(-0.2, 0.75, 0), 0.0)
			b.add("SM_Prop_Vase_0%d" % (1 + b.rng.randi() % 5), t + Vector3(0.25, 0.75, 0.1), 0.0, 0.4)
			b.add("SM_Prop_Senser_01", Vector3(-1.4, 0, 2.2), 0.0, 0.8)
			b.add("SM_Prop_Rug_0%d" % (1 + b.rng.randi() % 4), Vector3(0, 0.01, 2.4), PI / 2, 0.7)
		"barber":
			b.add("SM_Prop_Seat_Chair_02", t + Vector3(0, 0, 0.2), PI, 0.95)
			b.add("SM_Prop_Table_05", Vector3(-1.3, 0, 0.9), 0.0, 0.9)
			b.add("SM_Prop_Jug_0%d" % (1 + b.rng.randi() % 5), Vector3(-1.3, 0.76, 0.9), 0.0, 0.7)
			b.add("SM_Prop_Seat_Bench_01", Vector3(-1.3, 0, 2.1), 0.0, 0.85)
		"medic":
			b.add("SM_Prop_Table_05", t, PI / 2, 0.9)
			b.add("SM_Prop_Scroll_Pile_0%d" % (1 + b.rng.randi() % 6), t + Vector3(0, 0.76, 0), 0.0, 0.7)
			b.add("SM_Prop_Seat_Kline_01", Vector3(-1.2, 0, 1.5), 0.0, 0.7)
	b.add("SM_Prop_FlowerPot_Fancy_01", Vector3(-2.2, 0, 2.3), 0.0, 0.6)
	b.door = Vector3(1.25, 0, 3.0 if layout == "fancy" else 2.7)


static func _thermopolium(b: Bp) -> void:
	b.paint(1)
	b.block(0, -1.25, 3, 1, 1, {"door_i": 2, "shop": [0, 1], "win_p": 0.4})
	b.gable(0, -1.25, 3, 1, FL, false)
	b.add("SM_Prop_Overhang_01", Vector3(-2.5, 2.75, 0.12), 0.0)
	b.add("SM_Prop_Overhang_01", Vector3(0.0, 2.75, 0.12), 0.0)
	# прилавок-стойка с кувшинами
	b.parts.append(["#marble", Transform3D(Basis.IDENTITY.scaled(Vector3(4.4, 0.95, 0.7)), Vector3(-1.25, 0.47, 0.8)), {}])
	for k in 4:
		b.add("SM_Prop_Jar_01", Vector3(-3.0 + k * 1.15, 0.95, 0.8), 0.0, 0.45)
	for k in 3:
		b.add("SM_Prop_Seat_Stool_0%d" % (1 + k % 2), Vector3(-2.8 + k * 1.5, 0, 1.7), 0.0)
	b.add("SM_Prop_Table_07", Vector3(2.6, 0, 1.9), 0.0)
	b.wall_banner(0, -1.25, 3, 1, 1.0, 2.5)
	b.door = Vector3(0, 0, 2.7)


static func _taberna(b: Bp) -> void:
	b.paint(0)
	b.block(0, -2.5, 3, 2, 2, {"door_i": 1, "shop": [0, 2], "win_p": 0.7})
	b.gable(0, -2.5, 3, 2, 2 * FL)
	b.balcony(0, -2.5, 3, 2, 1, 1)
	# двор со столами под перголой
	for c: Vector3 in [Vector3(-3.6, 0, 0.3), Vector3(3.6, 0, 0.3), Vector3(-3.6, 0, 3.6), Vector3(3.6, 0, 3.6)]:
		b.add("SM_Bld_Trellis_Pillar_01", c, 0.0, 0.85)
	b.add("SM_Bld_Trellis_Roof_Large_01", Vector3(-3.75, 2.65, 0.15), 0.0, 1.0)
	b.add("SM_Bld_Trellis_Roof_Large_01", Vector3(-0.05, 2.65, 0.15), 0.0, 1.0)
	for c: Vector3 in [Vector3(-2.0, 0, 1.4), Vector3(1.8, 0, 1.4), Vector3(0, 0, 3.0)]:
		b.add("SM_Prop_Table_0%d" % (2 + b.rng.randi() % 2), c, 0.0, 0.85)
		b.add("SM_Prop_Seat_Stool_01", c + Vector3(-0.9, 0, 0), 0.0)
		b.add("SM_Prop_Seat_Stool_02", c + Vector3(0.9, 0, 0), 0.0)
		b.add("SM_Prop_Jug_0%d" % (1 + b.rng.randi() % 5), c + Vector3(0, 0.66, 0), 0.0, 0.7)
	b.add("SM_Env_Vine_01", Vector3(-1.8, 2.7, 1.8), 0.0, 0.9)
	b.add("SM_Env_Vine_02", Vector3(1.8, 2.7, 1.8), 1.0, 0.9)
	b.add("SM_Prop_Vase_Pile_02", Vector3(3.2, 0, -0.6), 0.0, 0.8)
	b.brazier(Vector3(-3.2, 0, 4.4))
	b.door = Vector3(0, 0, 4.6)


static func _fullonica(b: Bp) -> void:
	b.paint(5)
	b.block(0, -1.25, 3, 1, 1, {"door_i": 1, "win_p": 0.7})
	b.flat_roof(0, -1.25, 3, 1, FL)
	# сушка: верёвки на шестах с покрывалами, чаны
	for x: float in [-3.4, 0.0, 3.4]:
		b.add("SM_Prop_Pole_01", Vector3(x, 0, 1.5), 0.0, 0.85)
	b.add("SM_Prop_Rug_Drape_01", Vector3(-1.7, 1.5, 1.5), 0.0)
	b.add("SM_Prop_Rug_Drape_01", Vector3(1.7, 1.5, 1.5), 0.0)
	for k in 3:
		b.add("SM_Prop_Jar_01", Vector3(-2.5 + k * 2.5, 0, 0.5), 0.0, 1.1)
	b.add("SM_Prop_Basket_Set_02", Vector3(3.0, 0, 2.7), 0.0, 0.8)
	b.door = Vector3(0, 0, 2.9)


static func _musicians(b: Bp) -> void:
	b.add("SM_Prop_Seat_Bench_03", Vector3(0, 0, -0.6), 0.0)
	b.add("SM_Prop_Rug_0%d" % (1 + b.rng.randi() % 4), Vector3(0, 0.01, 0.4), PI / 2, 0.8)
	b.add("SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 4), Vector3(0.0, 0, 0.9), 0.0, 0.7)
	b.add("SM_Prop_Pole_02", Vector3(1.3, 0, -0.9), 0.0, 0.8)
	b.add("SM_Prop_Banner_03_%s" % b.pick(["A", "C", "E"]), Vector3(1.3, 2.9, -0.9), 0.0, 0.8)
	b.door = Vector3(0, 0, 1.4)


static func _dice(b: Bp) -> void:
	var c := Vector3(-1.3, 0, -1.3)
	for d: Vector3 in [Vector3(0, 0, 0), Vector3(2.6, 0, 0), Vector3(0, 0, 2.6), Vector3(2.6, 0, 2.6)]:
		b.add("SM_Prop_Pole_02", c + d, 0.0, 0.75)
	b.parts.append(["SM_Prop_Banner_Roof_03", Transform3D(Basis.IDENTITY, c + Vector3(0, 2.75, 0)), canopy_remap(4)])
	b.add("SM_Prop_Table_02", Vector3.ZERO, 0.0, 0.85)
	for a in 4:
		var q := Vector3(cos(a * PI / 2), 0, sin(a * PI / 2)) * 0.95
		b.add("SM_Prop_Seat_Stool_0%d" % (1 + a % 2), q, 0.0)
	b.add("SM_Prop_Goblet_01", Vector3(0.2, 0.67, 0.1), 0.0)
	b.add("SM_Prop_Jug_02", Vector3(1.6, 0, 1.4), 0.0, 0.8)
	b.door = Vector3(0, 0, 1.9)


static func _mimes(b: Bp) -> void:
	# деревянный помост с занавесом, перед ним скамьи
	b.parts.append(["#marble", Transform3D(Basis.IDENTITY.scaled(Vector3(5.0, 0.7, 3.0)), Vector3(0, 0.35, -1.6)), {}])
	for x: float in [-2.4, 2.4]:
		b.add("SM_Prop_Pole_02", Vector3(x, 0.7, -3.0), 0.0, 1.0)
	b.add("SM_Prop_Drapery_01", Vector3(-1.25, 3.0, -3.0), 0.0)
	b.add("SM_Prop_Drapery_02", Vector3(1.25, 3.0, -3.0), 0.0)
	b.add("SM_Prop_Banner_Large_01", Vector3(0, 3.6, -3.1), 0.0, 0.6)
	b.add("SM_Prop_Seat_Bench_01", Vector3(-1.3, 0, 1.4), 0.0, 0.9)
	b.add("SM_Prop_Seat_Bench_01", Vector3(1.3, 0, 1.4), 0.0, 0.9)
	b.add("SM_Prop_Seat_Bench_01", Vector3(0, 0, 2.5), 0.0, 0.9)
	b.brazier(Vector3(-2.6, 0, 0.3))
	b.brazier(Vector3(2.6, 0, 0.3))
	b.door = Vector3(0, 0, 3.2)


static func _odeon(b: Bp) -> void:
	var s := 0.24
	for i in 4:
		b.add_xf("SM_Bld_Amphitheatre_01", Transform3D(Basis(Vector3.UP, PI / 2 - i * PI / 4).scaled(Vector3.ONE * s), Vector3(0, 0.1, 1.6)))
	b.add_xf("SM_Bld_Amphitheatre_End_01", Transform3D(Basis(Vector3.UP, PI / 2).scaled(Vector3.ONE * s), Vector3(0, 0.1, 1.6)))
	b.add_xf("SM_Bld_Amphitheatre_End_01", Transform3D(Basis(Vector3.UP, -PI / 2).scaled(Vector3(-s, s, s)), Vector3(0, 0.1, 1.6)))
	b.parts.append(["#marble", Transform3D(Basis.IDENTITY.scaled(Vector3(8.0, 0.5, 2.0)), Vector3(0, 0.25, 3.4)), {}])
	for x: float in [-3.3, -1.1, 1.1, 3.3]:
		b.add("SM_Bld_Pillar_0%d" % (1 + b.rng.randi() % 2), Vector3(x, 0.5, 4.2), 0.0, 0.65)
	b.add("SM_Prop_Drapery_03", Vector3(-1.1, 2.4, 4.3), 0.0, 0.8)
	b.door = Vector3(0, 0, 5.2)


static func _balnea(b: Bp) -> void:
	b.paint(6)
	b.block(0, -2.5, 3, 1, 1, {"door_i": 1, "door": "SM_Bld_Wall_Door_Double_01", "win": "SM_Bld_Wall_Window_05", "win0": "SM_Bld_Wall_Window_05", "win_p": 0.9})
	b.gable(0, -2.5, 3, 1, FL)
	b.parts.append(["#water", Transform3D(Basis.IDENTITY.scaled(Vector3(5.0, 0.1, 2.5)), Vector3(0, 0.05, 0.75)), {}])
	for i in 2:
		b.add("SM_Bld_Bath_Edge_01", Vector3(-2.5 + i * M, 0, 2.0), 0.0)
		b.add("SM_Bld_Bath_Edge_01", Vector3(-2.5 + (i + 1) * M, 0, -0.5), PI)
	b.add("SM_Bld_Bath_Edge_01", Vector3(2.5, 0, 2.0), PI / 2)
	b.add("SM_Bld_Bath_Edge_01", Vector3(-2.5, 0, -0.5), -PI / 2)
	for c: Vector3 in [Vector3(-2.5, 0, -0.5), Vector3(2.5, 0, -0.5), Vector3(-2.5, 0, 2.0), Vector3(2.5, 0, 2.0)]:
		b.add("SM_Bld_Bath_Corner_01", c, 0.0)
	for x: float in [-3.4, 3.4]:
		b.add("SM_Bld_Pillar_01", Vector3(x, 0, 1.2), 0.0, 0.75)
		b.add("SM_Env_Ivy_Pillar_Flowers_0%d" % (1 + b.rng.randi() % 2), Vector3(x, 0, 1.2), 0.0, 0.75)
	b.add("SM_Env_Tree_Palm_0%d" % (1 + b.rng.randi() % 3), Vector3(3.3, 0, 3.0), 0.0, 0.35)
	b.door = Vector3(0, 0, 3.4)


# ---------- науки ----------

static func _scriptorium(b: Bp) -> void:
	b.paint(9)
	b.block(0, -1.25, 2, 1, 1, {"door_i": 0, "win_p": 0.9})
	b.gable(0, -1.25, 2, 1, FL)
	b.add("SM_Prop_Table_05", Vector3(1.2, 0, 1.0), PI / 2, 0.9)
	b.add("SM_Prop_Scroll_Pile_0%d" % (1 + b.rng.randi() % 6), Vector3(1.2, 0.76, 1.0), 0.0, 0.7)
	b.add("SM_Prop_Seat_Stool_01", Vector3(1.2, 0, 1.7), 0.0)
	b.add("SM_Bld_Shelf_Scroll_01", Vector3(-2.5, 0, -0.05), 0.0, 0.8)
	b.add("SM_Bld_Shelf_Scroll_01_Insert_01", Vector3(-2.5, 0, -0.05), 0.0, 0.8)
	b.add("SM_Prop_FlowerPot_Fancy_01", Vector3(2.2, 0, 2.2), 0.0, 0.6)
	b.door = Vector3(-1.25, 0, 0.9)


static func _school(b: Bp) -> void:
	b.paint(3)
	b.block(0, -2.5, 3, 2, 1, {"door_i": 1, "door": "SM_Bld_Wall_Door_Double_01", "win_p": 0.9})
	b.gable(0, -2.5, 3, 2, FL)
	b.portico(-3.75, 3.75, 2.4, 0.0, 0.85, "SM_Bld_Pillar_01")
	for k in 3:
		b.add("SM_Prop_Seat_Bench_01", Vector3(-2.2 + k * 2.2, 0, 3.6), 0.0, 0.85)
	b.add("SM_Prop_Sundial_01", Vector3(3.4, 0, 4.0), 0.0)
	b.add("SM_Prop_Scroll_Pile_0%d" % (1 + b.rng.randi() % 6), Vector3(-1.0, 0, 1.2), 0.0)
	b.door = Vector3(0, 0, 4.6)


static func _library(b: Bp) -> void:
	b.paint(6)
	b.block(0, -2.5, 4, 2, 2, {"door_i": 1, "door": "SM_Bld_Wall_Door_Double_Large_01", "win": "SM_Bld_Wall_Window_05", "win_p": 0.95})
	b.gable(0, -2.5, 4, 2, 2 * FL)
	b.portico(-5.0, 5.0, 2.6, 0.0, 1.0, "SM_Bld_Pillar_02", true)
	for x: float in [-3.6, 3.6]:
		b.column_statue(Vector3(x, 0, 4.0), 0.0, 0.8)
	b.add("SM_Prop_Scroll_Pile_0%d" % (1 + b.rng.randi() % 6), Vector3(-1.2, 0, 1.3), 0.0)
	b.add("SM_Prop_Seat_Bench_03", Vector3(1.2, 0, 1.5), 0.0, 0.9)
	b.wall_banner(0, -2.5, 4, 2, 0.5, 2 * FL - 0.35)
	b.wall_banner(0, -2.5, 4, 2, 3.5, 2 * FL - 0.35)
	b.door = Vector3(0, 0, 4.4)


static func _academy(b: Bp) -> void:
	b.paint(6)
	# двор-перистиль: колонны по кругу, в центре фонтан, сзади зал
	b.block(0, -5.0, 5, 2, 2, {"door_i": 2, "door": "SM_Bld_Wall_Door_Double_Large_01", "win": "SM_Bld_Wall_Window_05", "win_p": 0.95})
	b.gable(0, -5.0, 5, 2, 2 * FL)
	for x in range(-2, 3):
		b.add("SM_Bld_Pillar_02", Vector3(x * 2.5, 0, 4.5), 0.0, 0.95)
	for z in range(0, 3):
		b.add("SM_Bld_Pillar_02", Vector3(-5.0, 0, -1.5 + z * 3.0), 0.0, 0.95)
		b.add("SM_Bld_Pillar_02", Vector3(5.0, 0, -1.5 + z * 3.0), 0.0, 0.95)
	b.add("SM_Prop_Fountain_04", Vector3(0, 0, 0.8), 0.0, 0.7)
	b.add("SM_Prop_Fountain_04_Insert_01", Vector3(0, 0, 0.8), 0.0, 0.7)
	for x: float in [-2.8, 2.8]:
		b.add("SM_Prop_Seat_Bench_03", Vector3(x, 0, 1.0), PI / 2 * signf(x))
		b.add("SM_Env_Tree_Thin_0%d" % (1 + b.rng.randi() % 2), Vector3(x, 0, 3.4), 0.0, 0.5)
	b.add("SM_Prop_Statue_0%d" % (1 + b.rng.randi() % 7), Vector3(0, 0, -2.4), 0.0, 0.9)
	b.door = Vector3(0, 0, 5.6)


# ---------- памятники ----------

static func _arch(b: Bp) -> void:
	b.add("SM_Bld_Door_Monument_01", Vector3(-2.5, 0, 0), 0.0, 0.8)
	b.add("SM_Prop_Statue_0%d" % (1 + b.rng.randi() % 7), Vector3(0, 6.6, 0), 0.0, 1.0)
	for x: float in [-3.6, 3.6]:
		b.add("SM_Prop_Statue_Lion_01", Vector3(x, 0, 1.6), 0.0, 0.55)
		b.brazier(Vector3(x, 0, -1.6), true)
	b.add("SM_Prop_Banner_Large_01", Vector3(0, 4.9, 0.6), 0.0, 0.6)
	b.door = Vector3(0, 0, 2.6)


static func _colosseum(b: Bp) -> void:
	var s := 0.55
	for i in 8:
		b.add_xf("SM_Bld_Amphitheatre_01", Transform3D(Basis(Vector3.UP, i * PI / 4).scaled(Vector3.ONE * s), Vector3.ZERO))
	b.parts.append(["#marble", Transform3D(Basis.IDENTITY.scaled(Vector3(7.0, 0.2, 7.0)), Vector3(0, 0.1, 0)), {}])
	for i in 6:
		var a := i * TAU / 6.0
		b.add("SM_Prop_Banner_03_%s" % ["A", "B", "C", "D", "E", "F"][i], Vector3(cos(a), 0, sin(a)) * 11.0 + Vector3(0, 9.0, 0), -a)
	b.add("SM_Prop_Statue_0%d" % (1 + b.rng.randi() % 7), Vector3(0, 0.2, 0), 0.0, 1.2)
	b.door = Vector3(0, 0, 13.0)


static func _pantheon(b: Bp) -> void:
	b.paint(6)
	# круглый зал из стен по кругу, портик с колоннами, купол из конусов кровли
	var r := 6.5
	for i in 16:
		var a := i * TAU / 16.0
		b.add_xf("SM_Bld_Wall_Large_01", Transform3D(Basis(Vector3.UP, -a + PI / 2).scaled(Vector3(0.53, 1.4, 1)), Vector3(cos(a), 0, sin(a)) * r - Vector3(cos(a + PI / 2), 0, sin(a + PI / 2)) * 1.32), true)
	b.parts.append(["#marble", Transform3D(Basis.IDENTITY.scaled(Vector3(r * 1.85, 2.8, r * 1.85)), Vector3(0, 6.6 + 1.4, 0)), {}])
	b.parts.append(["#marble", Transform3D(Basis.IDENTITY.scaled(Vector3(r * 1.3, 1.6, r * 1.3)), Vector3(0, 9.4 + 0.8, 0)), {}])
	b.parts.append(["#dark", Transform3D(Basis.IDENTITY.scaled(Vector3(r * 1.7, 6.4, r * 1.7)), Vector3(0, 3.2, 0)), {}])
	b.portico(-5.0, 5.0, r + 4.0, r - 0.5, 1.6, "SM_Bld_Pillar_Large_01")
	for x: float in [-4.0, 4.0]:
		b.add("SM_Prop_Statue_Lion_01", Vector3(x, 0, r + 5.6), 0.0, 0.7)
	b.door = Vector3(0, 0, r + 6.0)


## Почтовая станция у тоннеля — растёт с уровнем города
static func _center(b: Bp, stage: int) -> void:
	b.paint(0)
	if stage <= 0:
		b.block(-1.25, -1.25, 3, 1, 1, {"door_i": 1, "door": "SM_Bld_Wall_Door_Double_01", "win_p": 0.6})
		b.gable(-1.25, -1.25, 3, 1, FL)
		b.add("SM_Prop_Overhang_01", Vector3(-1.25, 2.75, 0.12), 0.0)
		b.add("SM_Prop_Sack_Stack_01", Vector3(2.4, 0, -1.0), 0.3)
		b.add("SM_Prop_Basket_Set_01", Vector3(2.6, 0, 0.7), 1.0, 0.9)
		b.add("SM_Prop_Cart_01", Vector3(-4.2, 0, 1.6), 0.8, 0.85)
		b.add("SM_Prop_Cart_01_Insert_03", Vector3(-4.2, 0, 1.6), 0.8, 0.85)
		b.add("SM_Prop_Pole_02", Vector3(3.5, 0, 2.6), 0.0, 1.2)
		b.add("SM_Prop_Banner_03_A", Vector3(3.5, 3.55, 2.6), 0.0)
		b.brazier(Vector3(1.5, 0, 1.5))
		b.door = Vector3(0, 0, 2.2)
		return
	var floors := 2 if stage < 5 else 3
	b.block(0, -1.25, 4, 2, floors, {"door_i": 1, "door": "SM_Bld_Wall_Door_Double_Large_01", "win": "SM_Bld_Wall_Window_05", "win_p": 0.9})
	var ridge := b.gable(0, -1.25, 4, 2, floors * FL)
	b.portico(-5.0, 5.0, 2.9, 0.0, 0.92, "SM_Bld_Pillar_0%d" % (2 if stage < 5 else 4), stage >= 3)
	for i in 4:
		b.add("SM_Prop_Drapery_0%d" % (1 + i % 3), Vector3(-3.75 + i * M, 2.7, 3.05), 0.0)
	b.brazier(Vector3(-4.6, 0, 4.4), stage >= 3)
	b.brazier(Vector3(4.6, 0, 4.4), stage >= 3)
	b.wall_banner(0, -1.25, 4, 2, 0.5, floors * FL - 0.35)
	b.wall_banner(0, -1.25, 4, 2, 3.5, floors * FL - 0.35)
	if stage >= 4:
		b.add("SM_Prop_Statue_Lion_01", Vector3(-2.6, 0, 4.5), 0.0, 0.4)
		b.add("SM_Prop_Statue_Lion_01", Vector3(2.6, 0, 4.5), 0.0, 0.4)
		b.add("SM_Prop_Statue_0%d" % (1 + b.rng.randi() % 7), Vector3(0, ridge - 0.3, -1.25), 0.0, 0.7)
	if stage >= 6:
		b.add("SM_Prop_Banner_Large_01", Vector3(0, floors * FL - 0.3, 1.4), 0.0, 0.65)
	b.door = Vector3(-1.25, 0, 5.0)


## Люди при деле: видны, пока постройка работает
static func _actors(b: Bp, type: String, tier: int) -> void:
	match type:
		"farm":
			b.actor(Vector3(-2.3, 0, -1.2), b.rng.randf() * TAU, "Fixing_Kneeling", "pleb")
			b.actor(Vector3(1.4, 0, 1.6), b.rng.randf() * TAU, "Fixing_Kneeling", "pleb")
		"grove":
			b.actor(Vector3(-1.6, 0, 1.6), PI, "Interact", "pleb")
		"vineyard":
			b.actor(Vector3(-1.5, 0, -2.9), PI / 2, "Interact", "female")
		"stall_fruit", "stall_veg", "stall_fish":
			b.actor(Vector3(0, 0, -0.4), 0.0, "Idle_Talking", "any")
		"butcher", "cobbler", "potter", "oilshop", "wineshop", "lamps":
			b.actor(Vector3(1.0, 0, 0.6), 0.0, "Idle_Talking", "any")
		"perfumer", "jeweler", "tailor", "weaver", "medic":
			b.actor(Vector3(1.25, 0, 0.35), 0.0, "Interact", "any")
		"bakery":
			b.actor(Vector3(-1.2, 0, 1.75), PI, "Interact", "pleb")
		"barber":
			b.actor(Vector3(1.25, 0, 1.0), 0.0, "Sitting_Idle", "pleb")
			b.actor(Vector3(1.9, 0, 1.2), -PI / 2, "Interact", "any")
		"thermopolium":
			b.actor(Vector3(-1.25, 0, 0.1), 0.0, "Idle_Talking", "any")
		"taberna":
			b.actor(Vector3(-2.0, 0, 2.1), PI, "Idle_Talking", "any")
			b.actor(Vector3(1.8, 0, 0.7), 0.0, "Idle_Talking", "any")
		"musicians":
			b.actor(Vector3(-0.6, 0, -0.6), 0.0, "Sitting_Talking", "pleb")
			b.actor(Vector3(0.6, 0, -0.1), 0.0, "Dance", "female")
		"dice":
			b.actor(Vector3(0.95, 0, 0), -PI / 2, "Sitting_Talking", "pleb")
			b.actor(Vector3(-0.95, 0, 0), PI / 2, "Sitting_Idle", "pleb")
		"mimes":
			b.actor(Vector3(-0.8, 0.7, -1.4), 0.0, "Dance", "any")
			b.actor(Vector3(0.9, 0.7, -1.6), 0.0, "Spell_Simple_Idle", "any")
		"odeon":
			b.actor(Vector3(0, 0.5, 3.4), PI, "Spell_Simple_Idle", "rich")
		"theatre":
			b.actor(Vector3(-1.5, 0.6, 5.6), PI, "Spell_Simple_Idle", "rich")
			b.actor(Vector3(1.5, 0.6, 5.8), PI, "Dance", "female")
		"balnea":
			b.actor(Vector3(-2.0, 0, 2.6), PI, "Idle_Talking", "any")
		"school":
			b.actor(Vector3(0, 0, 2.6), PI, "Idle_Talking", "rich")
		"scriptorium":
			b.actor(Vector3(1.2, 0, 1.7), PI, "Sitting_Idle", "pleb")
		"temple":
			b.actor(Vector3(0, 0, 7.9), PI, "Spell_Simple_Idle", "rich")
		"forum":
			b.actor(Vector3(-1.6, 0, 1.2), 0.9, "Idle_Talking", "rich")
			b.actor(Vector3(2.4, 0, 3.8), 0.0, "Sword_Idle", "soldier")
		"center":
			b.actor(Vector3(1.0, 0, 1.0), 0.4, "Idle_Talking", "any")
			if tier >= 2:
				b.actor(Vector3(-2.6, 0, 3.6), 0.0, "Sword_Idle", "soldier")
		"house_patrician":
			b.actor(Vector3(2.4, 0, -4.2), b.rng.randf() * TAU, "Fixing_Kneeling", "pleb")


static func _farm(b: Bp) -> void:
	b.fence(-4.9, -4.9, 4.9, 4.9)
	for i in 11:
		b.add("SM_Env_Crop_Rows_0%d" % (1 + i % 3), Vector3(-4.0 + i * 0.75, 0, -4.2), 0.0, 0.9)
	b.add("SM_Prop_Straw_Stack_02", Vector3(3.8, 0, 3.6), 0.4, 0.7)
	b.add("SM_Prop_Straw_Bundle_01", Vector3(2.8, 0, 4.2), 0.0)
	b.add("SM_Prop_Plough_01", Vector3(-3.6, 0, 4.1), 1.3)
	b.add("SM_Prop_Basket_Backpack_01", Vector3(-2.7, 0, 4.3), 0.4)
	b.add("SM_Prop_Scythe_01", Vector3(-2.4, 0.7, 4.4), 0.2)
	b.door = Vector3(0, 0, 5.3)



static func _grove(b: Bp) -> void:
	b.fence(-4.9, -4.9, 4.9, 4.9)
	for i in 3:
		for j in 3:
			var p := Vector3(-3.2 + i * 3.2 + b.rng.randf_range(-0.3, 0.3), 0, -3.2 + j * 3.0 + b.rng.randf_range(-0.3, 0.3))
			b.add_xf("SM_Env_Tree_0%d" % (3 + (i + j) % 2), Transform3D(Basis(Vector3.UP, b.rng.randf() * TAU).scaled(Vector3(0.42, 0.36, 0.42)), p), false)
	b.add("SM_Prop_Basket_Set_01", Vector3(3.6, 0, 4.0), 0.3, 0.8)
	b.add("SM_Prop_Ladder_01", Vector3(-1.6, 0, 1.0), 0.5)
	b.add("SM_Prop_Jar_Pile_01", Vector3(-3.6, 0, 4.0), 0.0, 0.8)
	b.door = Vector3(0, 0, 5.3)



static func _vineyard(b: Bp) -> void:
	b.fence(-4.9, -4.9, 4.9, 4.9)
	for j in 5:
		for i in 3:
			b.add("SM_Env_Vine_0%d" % (1 + (i + j) % 3), Vector3(-3.0 + i * 3.0, 0, -3.8 + j * 1.8), 0.0, 1.0)
	b.add("SM_Prop_Basket_Set_06", Vector3(3.8, 0, 4.2), 0.0, 0.8)
	b.add("SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 4), Vector3(-3.8, 0, 4.2), 0.0)
	b.door = Vector3(0, 0, 5.3)



static func _warehouse(b: Bp) -> void:
	b.paint(b.pick([6, -1, 0]))
	b.block(0, -0.6, 3, 1, 1, {"door_i": 1, "door": "SM_Bld_Wall_Door_Double_Large_01", "win_p": 0.3})
	b.gable(0, -0.6, 3, 1, FL, false)
	b.add("SM_Prop_Sack_Stack_01", Vector3(-2.6, 0, 1.6), 0.2, 0.9)
	b.add("SM_Prop_Sack_Stack_02", Vector3(-2.6, 0.6, 1.5), 0.6, 0.8)
	b.add("SM_Prop_Jar_Pile_01", Vector3(2.5, 0, 1.7), 0.0)
	b.add("SM_Prop_Basket_Set_02", Vector3(-1.2, 0, 2.0), 0.4, 0.8)
	b.add("SM_Prop_Cart_01", Vector3(1.4, 0, 1.9), 1.5, 0.75)
	b.add("SM_Prop_Cart_01_Insert_02", Vector3(1.4, 0, 1.9), 1.5, 0.75)
	b.door = Vector3(0, 0, 2.7)



static func _fountain(b: Bp) -> void:
	b.add("SM_Prop_Fountain_04", Vector3.ZERO, 0.0, 1.35)
	b.add("SM_Prop_Fountain_04_Insert_01", Vector3.ZERO, 0.0, 1.35)
	for c: Vector3 in [Vector3(-2.1, 0, -2.1), Vector3(2.1, 0, -2.1), Vector3(-2.1, 0, 2.1), Vector3(2.1, 0, 2.1)]:
		b.add("SM_Prop_FlowerPot_Fancy_01", c + Vector3(0, 0.57 * 0.7, 0), 0.0, 0.7)
	b.add("SM_Env_Lillies_02", Vector3(0.8, 0.85, 0.5), 0.0, 0.6)
	b.door = Vector3(0, 0, 2.6)



static func _temple(b: Bp) -> void:
	var s := 0.62
	b.base = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), Vector3(0, 0, 4.5))
	var cols := 6
	var step := 2.5
	var w := (cols - 1) * step          # 12.5 между осями крайних колонн
	var deep := 6
	var pod := 1.5
	var hw := w / 2.0 + 1.0
	var z_front := -1.0                 # передний край подиума (за ним лестница к +Z)
	var zc0 := z_front - 1.2            # первый ряд колонн
	var zb := zc0 - (deep - 1) * step   # задний ряд
	# подиум из мрамора и лестница во всю ширину
	b.parts.append(["#marble", b.base * Transform3D(Basis.IDENTITY.scaled(Vector3(hw * 2.0, pod, zc0 - zb + 2.6)), Vector3(0, pod / 2.0, (zc0 + zb) / 2.0)), {}])
	for i in int(ceil(hw * 2 / step)):
		b.add("SM_Bld_Stairs_01", Vector3(-hw + i * step, 0, z_front + 2.5), 0.0)
	# колоннада
	for i in cols:
		var x := -w / 2.0 + i * step
		b.add("SM_Bld_Pillar_Large_01", Vector3(x, pod, zc0), 0.0)
		b.add("SM_Bld_Pillar_Large_01", Vector3(x, pod, zb), 0.0)
		if i == 0 or i == cols - 1:
			b.add("SM_Env_Ivy_Pillar_Flowers_04", Vector3(x, pod, zc0), b.rng.randf() * TAU)
	for j in range(1, deep - 1):
		for x: float in [-w / 2.0, w / 2.0]:
			b.add("SM_Bld_Pillar_Large_01", Vector3(x, pod, zc0 - j * step), 0.0)
	# целла с большой дверью
	var cw := w - step * 2
	var cz0 := zc0 - step
	var cz1 := zb + step
	var nm := int(cw / step)
	for i in nm:
		var x := -cw / 2.0 + i * step
		b.add("SM_Bld_Wall_Door_Double_Large_01" if i == nm / 2 - (1 if nm % 2 == 0 else 0) else "SM_Bld_Wall_01", Vector3(x, pod, cz0), 0.0)
		b.add("SM_Bld_Wall_01", Vector3(x, pod + 3.0, cz0), 0.0)
		b.add("SM_Bld_Wall_01", Vector3(x + step, pod, cz1), PI)
		b.add("SM_Bld_Wall_01", Vector3(x + step, pod + 3.0, cz1), PI)
	for j in int((cz0 - cz1) / step):
		for f in 2:
			b.add("SM_Bld_Wall_01", Vector3(cw / 2.0, pod + f * 3.0, cz0 - j * step), PI / 2)
			b.add("SM_Bld_Wall_01", Vector3(-cw / 2.0, pod + f * 3.0, cz0 - (j + 1) * step), -PI / 2)
	# антаблемент — сплошной пояс над колоннами по периметру
	var ye := pod + 6.0 + 0.48
	var span := w + 1.0
	var zf := zc0 + 0.5
	var zbk := zb - 0.5
	_trim_run(b, Vector3(-span / 2.0, ye, zf), Vector3(1, 0, 0), span)
	_trim_run(b, Vector3(span / 2.0, ye, zbk), Vector3(-1, 0, 0), span)
	_trim_run(b, Vector3(span / 2.0, ye, zf), Vector3(0, 0, -1), zf - zbk)
	_trim_run(b, Vector3(-span / 2.0, ye, zbk), Vector3(0, 0, 1), zf - zbk)
	# крыша вдоль оси храма и фронтоны
	var eave := ye + 0.48
	var half := span / 2.0 + 0.2
	var k := half / 7.5
	var len := zf - zbk + 0.8
	var n := int(ceil(len / 7.5))
	var lz := len / n
	for i in n:
		var z0 := zbk - 0.4 + i * lz
		b.add_xf("SM_Bld_Roof_Straight_Thin_Large_01", Transform3D(Basis(Vector3.UP, -PI / 2).scaled_local(Vector3(lz / 7.5, k, k)), Vector3(-half, eave, z0)))
		b.add_xf("SM_Bld_Roof_Straight_Thin_Large_01", Transform3D(Basis(Vector3.UP, PI / 2).scaled_local(Vector3(lz / 7.5, k, k)), Vector3(half, eave, z0 + lz)))
	for zz: float in [zf + 0.4, zbk - 0.4]:
		b.add_xf("SM_Bld_Roof_Side_Large_01", Transform3D(Basis(Vector3.UP, -PI / 2).scaled_local(Vector3(1, k, k)), Vector3(-half, eave, zz)))
		b.add_xf("SM_Bld_Roof_Side_Large_01", Transform3D(Basis(Vector3.UP, PI / 2).scaled_local(Vector3(1, k, k)), Vector3(half, eave, zz)))
	# статуя на коньке, львы и жаровни у лестницы, статуи на подиуме
	b.add("SM_Prop_Statue_0%d" % (1 + b.rng.randi() % 7), Vector3(0, eave + k * 1.95, zf + 0.3), 0.0, 0.9)
	b.add("SM_Prop_Statue_Lion_01", Vector3(-hw + 0.6, 0, z_front + 2.6), 0.0, 0.8)
	b.add("SM_Prop_Statue_Lion_01", Vector3(hw - 0.6, 0, z_front + 2.6), 0.0, 0.8)
	b.brazier(Vector3(-3.2, pod, zc0 + 0.9), true)
	b.brazier(Vector3(3.2, pod, zc0 + 0.9), true)
	b.add("SM_Prop_Senser_01", Vector3(0, pod, zc0 - 1.1), 0.0)
	for i in 3:
		b.add("SM_Prop_Drapery_0%d" % (1 + i), Vector3(-2.5 + i * 2.5, pod + 5.9, zc0 + 0.36), 0.0)
	b.base = Transform3D.IDENTITY
	b.door = Vector3(0, 0, 6.3)



static func _trim_run(b: Bp, a: Vector3, dir: Vector3, len: float) -> void:
	var yaw := atan2(-dir.z, dir.x)
	var n := maxi(1, int(round(len / 2.5)))
	var step := len / n
	for i in n:
		b.add_xf("SM_Bld_Trim_Large_Single_01", Transform3D(Basis(Vector3.UP, yaw).scaled_local(Vector3(step / 2.5, 1, 1)), a + dir * step * i))



static func _baths(b: Bp) -> void:
	b.paint(6)
	# корпус бань сзади (5×1 модуля, высокий этаж), бассейн с колоннами и статуями спереди
	b.block(0, -3.75, 5, 1, 1, {"door_i": 2, "door": "SM_Bld_Wall_Door_Double_Large_01", "win": "SM_Bld_Wall_Window_05", "win0": "SM_Bld_Wall_Window_05", "win_p": 0.9})
	b.flat_roof(0, -3.75, 5, 1, FL)
	b.add("SM_Prop_Pergola_01", Vector3(0, FL, -3.75), 0.0, 0.55)
	# бассейн 3×2 модуля: каменный борт, вода, ступени
	var px0 := -3.75
	var pz0 := -1.5
	b.parts.append(["#water", Transform3D(Basis.IDENTITY.scaled(Vector3(7.5, 0.1, 5.0)), Vector3(0, 0.05, pz0 + 2.5)), {}])
	for i in 3:
		b.add("SM_Bld_Bath_Edge_01", Vector3(px0 + i * M, 0, pz0 + 5.0), 0.0)
		b.add("SM_Bld_Bath_Edge_01", Vector3(px0 + (i + 1) * M, 0, pz0), PI)
	for j in 2:
		b.add("SM_Bld_Bath_Edge_01", Vector3(px0 + 7.5, 0, pz0 + 5.0 - j * M), PI / 2)
		b.add("SM_Bld_Bath_Edge_01", Vector3(px0, 0, pz0 + j * M), -PI / 2)
	for c: Vector3 in [Vector3(px0, 0, pz0), Vector3(px0 + 7.5, 0, pz0), Vector3(px0, 0, pz0 + 5), Vector3(px0 + 7.5, 0, pz0 + 5)]:
		b.add("SM_Bld_Bath_Corner_01", c, 0.0)
	b.add("SM_Bld_Bath_Stairs_01", Vector3(0, 0, pz0 + 5.0 - 0.1), PI)
	# колонны с розами и статуи по сторонам
	for z: float in [-1.0, 1.4, 3.6]:
		for x: float in [-5.4, 5.4]:
			b.add("SM_Bld_Pillar_0%d" % (1 + b.rng.randi() % 2), Vector3(x, 0, z), 0.0, 0.85)
			b.add("SM_Env_Ivy_Pillar_Flowers_0%d" % (1 + b.rng.randi() % 2), Vector3(x, 0, z), b.rng.randf() * TAU, 0.85)
			b.add("SM_Prop_Statue_0%d" % (1 + b.rng.randi() % 7), Vector3(x, 2.55, z), 0.0, 0.55)
	b.add("SM_Prop_Table_02", Vector3(-4.2, 0, 4.4), 0.0, 0.8)
	b.add("SM_Prop_Seat_Chair_01", Vector3(-4.9, 0, 4.4), PI / 2)
	b.add("SM_Prop_Seat_Chair_01", Vector3(-3.5, 0, 4.4), -PI / 2)
	b.add("SM_Prop_Jug_02", Vector3(-4.2, 0.62, 4.4), 0.0, 0.6)
	b.add("SM_Prop_Basket_Set_02", Vector3(4.4, 0, 4.5), 0.0, 0.7)
	b.add("SM_Env_Tree_Palm_0%d" % (1 + b.rng.randi() % 3), Vector3(5.6, 0, -3.0), 0.0, 0.55)
	b.door = Vector3(0, 0, 5.3)



static func _theatre(b: Bp) -> void:
	# полукруг трибун из четырёх клиньев амфитеатра, перед ним сцена с колоннами
	var s := 0.32
	var cz := 3.5
	for i in 4:
		b.add_xf("SM_Bld_Amphitheatre_01", Transform3D(Basis(Vector3.UP, PI / 2 - i * PI / 4).scaled(Vector3.ONE * s), Vector3(0, 0.15, cz)))
	b.add_xf("SM_Bld_Amphitheatre_End_01", Transform3D(Basis(Vector3.UP, PI / 2).scaled(Vector3.ONE * s), Vector3(0, 0.15, cz)))
	b.add_xf("SM_Bld_Amphitheatre_End_01", Transform3D(Basis(Vector3.UP, -PI / 2).scaled(Vector3(-s, s, s)), Vector3(0, 0.15, cz)))
	b.parts.append(["#marble", Transform3D(Basis.IDENTITY.scaled(Vector3(12.0, 0.6, 2.6)), Vector3(0, 0.3, cz + 2.2)), {}])
	for x: float in [-5.0, -2.5, 2.5, 5.0]:
		b.add("SM_Bld_Pillar_0%d" % (1 + b.rng.randi() % 3), Vector3(x, 0.6, cz + 3.1), 0.0, 0.8)
	b.add("SM_Prop_Drapery_01", Vector3(-3.75, 2.9, cz + 3.25), 0.0)
	b.add("SM_Prop_Drapery_02", Vector3(3.75, 2.9, cz + 3.25), 0.0)
	b.brazier(Vector3(-6.4, 0, cz + 3.0), true)
	b.brazier(Vector3(6.4, 0, cz + 3.0), true)
	b.door = Vector3(0, 0, 7.6)



static func _forum(b: Bp) -> void:
	b.paint(6)
	# галерея буквой П: колонны с поясом и черепичным навесом, задняя стена с нишами и статуями
	b.portico(-6.25, 6.25, -4.6, -7.1, 1.0, "SM_Bld_Pillar_02", true)
	for i in 5:
		b.add("SM_Bld_Wall_Alcove_01", Vector3(-6.25 + i * 2.5, 0, -7.1), 0.0)
		b.add("SM_Prop_Statue_0%d" % (1 + (i + 2) % 7), Vector3(-5.0 + i * 2.5, 0.25, -7.45), 0.0, 0.8)
	for side: float in [-1.0, 1.0]:
		for j in 4:
			var z := -2.1 + j * 2.5
			b.add("SM_Bld_Pillar_02", Vector3(side * 6.25, 0, z), 0.0)
			if j % 2 == 1:
				b.add("SM_Env_Ivy_Pillar_Flowers_0%d" % (1 + b.rng.randi() % 2), Vector3(side * 6.25, 0, z), b.rng.randf() * TAU)
		for j in 3:
			var z := -2.1 + j * 2.5
			if side < 0:
				b.add("SM_Bld_Wall_Tiny_01", Vector3(-6.25, 3.0, z), -PI / 2, 1.0, true)
			else:
				b.add("SM_Bld_Wall_Tiny_01", Vector3(6.25, 3.0, z + 2.5), PI / 2, 1.0, true)
	# центр площади: статуя на большом постаменте, львы, жаровни, скамьи, знамя
	b.add("SM_Prop_Plinth_05", Vector3(0, 0, -0.5), 0.0, 0.7)
	b.add("SM_Prop_Statue_0%d" % (1 + b.rng.randi() % 7), Vector3(0, 1.8, -0.5), 0.0, 1.2)
	b.add("SM_Prop_Statue_Lion_01", Vector3(-3.4, 0, 4.6), 0.0, 0.55)
	b.add("SM_Prop_Statue_Lion_01", Vector3(3.4, 0, 4.6), 0.0, 0.55)
	b.brazier(Vector3(-2.6, 0, 2.2), true)
	b.brazier(Vector3(2.6, 0, 2.2), true)
	b.add("SM_Prop_Banner_Large_01", Vector3(0, 3.6, -4.4), 0.0, 0.8)
	b.add("SM_Prop_Seat_Bench_03", Vector3(-4.6, 0, 1.0), PI / 2)
	b.add("SM_Prop_Seat_Bench_03", Vector3(4.6, 0, 1.0), -PI / 2)
	b.plants(-5.5, 5.0, 5.5, 6.6, 4)
	b.door = Vector3(0, 0, 7.6)



static func _decor(b: Bp, type: String) -> void:
	match type:
		"tree": b.add("SM_Env_Tree_0%d" % (1 + b.rng.randi() % 4), Vector3.ZERO, b.rng.randf() * TAU, 0.42)
		"cypress": b.add("SM_Env_Tree_Thin_0%d" % (1 + b.rng.randi() % 2), Vector3.ZERO, b.rng.randf() * TAU, 0.75)
		"palm": b.add("SM_Env_Tree_Palm_0%d" % (1 + b.rng.randi() % 3), Vector3.ZERO, b.rng.randf() * TAU, 0.45)
		"flowers": b.add("SM_Prop_FlowerBed_0%d" % (1 + b.rng.randi() % 2), Vector3(0, 0.41, 0), 0.0, 1.0)
		"bush": b.add("SM_Env_Garden_Plants_0%d" % (3 + b.rng.randi() % 5), Vector3.ZERO, b.rng.randf() * TAU, 0.7)
		"planter": b.add("SM_Prop_FlowerPot_Fancy_01", Vector3(0, 0.57, 0), 0.0, 0.9)
		"bench": b.add("SM_Prop_Seat_Bench_0%d" % [1, 3, 5][b.rng.randi() % 3], Vector3.ZERO, 0.0)
		"brazier": b.brazier(Vector3.ZERO)
		"bigbrazier": b.brazier(Vector3.ZERO, true)
		"statue":
			b.add("SM_Prop_Plinth_04", Vector3.ZERO, 0.0)
			b.add("SM_Prop_Statue_0%d" % (1 + b.rng.randi() % 7), Vector3(0, 0.68, 0), 0.0, 0.85)
		"column":
			b.column_statue(Vector3.ZERO, 0.0, 1.0)
			b.add("SM_Env_Ivy_Pillar_Flowers_02", Vector3.ZERO, b.rng.randf() * TAU)
		"lion": b.add("SM_Prop_Statue_Lion_01", Vector3.ZERO, 0.0, 0.7)
		"sundial": b.add("SM_Prop_Sundial_01", Vector3.ZERO, 0.0)
		"smallfountain":
			b.add("SM_Prop_Plinth_02", Vector3.ZERO, 0.0)
			b.add("SM_Prop_Fountain_01", Vector3(0, 0, 0.24), 0.0)
		"pergola": b.add("SM_Prop_Pergola_01", Vector3(0, 0.36 * 0.85, 0), 0.0, 0.85)
		"banner":
			b.add("SM_Prop_Pole_02", Vector3.ZERO, 0.0, 1.2)
			b.add("SM_Prop_Banner_03_%s" % b.pick(["A", "B", "C", "D", "E"]), Vector3(0, 3.55, 0.0), 0.0)
		"cart":
			b.add("SM_Prop_Cart_01", Vector3.ZERO, 0.0, 0.9)
			b.add("SM_Prop_Cart_01_Insert_0%d" % (1 + b.rng.randi() % 3), Vector3.ZERO, 0.0, 0.9)
		"well":
			b.add("SM_Prop_Well_01", Vector3.ZERO, 0.0, 0.85)
			b.add("SM_Prop_Jug_0%d" % (1 + b.rng.randi() % 4), Vector3(1.1, 0, 0.8), 0.4)
		"duck":
			for k in 3:
				b.add("#duck", Vector3(cos(k * 2.1) * 0.7, 0, sin(k * 2.1) * 0.6), k * 1.7, 1.0 - k * 0.15)
		"swan": b.add("#swan", Vector3.ZERO, b.rng.randf() * TAU, 1.0)
		"goods": b.add(b.pick(["SM_Prop_Basket_Set_01", "SM_Prop_Jar_Pile_01", "SM_Prop_Vase_Pile_01", "SM_Prop_Vase_Pile_03", "SM_Prop_Sack_Stack_01"]), Vector3.ZERO, b.rng.randf() * TAU)
	b.door = Vector3(0, 0, 1.0)
