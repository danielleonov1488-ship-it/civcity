class_name Catalog
extends RefCounted
## Облик каждой постройки игры — фиксированный, как в Town to City: один продуманный вид на уровень,
## при повторной постройке меняются только детали и цвет (seed). Всё собрано из деталей Synty.

const M := Bp.M
const FL := Bp.FL

static var _cache := {}


static func make(type: String, tier := 0, seed_v := 1) -> Bp:
	var key := "%s:%d:%d" % [type, tier, seed_v % 6]
	if _cache.has(key):
		return _cache[key]
	var b := Bp.new(hash(key))
	match type:
		"house": _house(b, tier)
		"domus": _domus(b, tier)
		"farm": _farm(b)
		"grove": _grove(b)
		"vineyard": _vineyard(b)
		"bakery": _workshop(b, "bakery")
		"oilpress": _workshop(b, "oilpress")
		"winery": _workshop(b, "winery")
		"smithy": _smithy(b)
		"market": _market(b)
		"lumber": _lumber(b)
		"quarry": _quarry(b)
		"warehouse": _warehouse(b)
		"well": _well(b)
		"fountain": _fountain(b)
		"temple": _temple(b)
		"baths": _baths(b)
		"theatre": _theatre(b)
		"forum": _forum(b)
		"center": _center(b, tier)
		_: _decor(b, type)
	b.base = Transform3D.IDENTITY
	_actors(b, type, tier)
	_cache[key] = b
	return b


## Люди при деле: видны, пока постройка работает
static func _actors(b: Bp, type: String, tier: int) -> void:
	match type:
		"farm":
			b.actor(Vector3(-2.3, 0, -1.2), b.rng.randf() * TAU, "Fixing_Kneeling", "pleb")
			b.actor(Vector3(1.4, 0, 1.6), b.rng.randf() * TAU, "Fixing_Kneeling", "pleb")
			b.actor(Vector3(0.4, 0, -3.0), PI, "Crouch_Idle", "female")
		"grove":
			b.actor(Vector3(-1.6, 0, 1.6), PI, "Interact", "pleb")
			b.actor(Vector3(1.9, 0, -1.4), b.rng.randf() * TAU, "Fixing_Kneeling", "female")
		"vineyard":
			b.actor(Vector3(-1.5, 0, -2.9), PI / 2, "Interact", "female")
			b.actor(Vector3(1.5, 0, 0.7), -PI / 2, "Fixing_Kneeling", "pleb")
		"bakery":
			b.actor(Vector3(1.2, 0, 2.15), PI, "Interact", "pleb")
			b.actor(Vector3(-1.6, 0, 1.45), PI, "PickUp_Table", "female")
		"oilpress":
			b.actor(Vector3(1.0, 0, 2.2), PI, "Push", "pleb")
		"winery":
			b.actor(Vector3(0.0, 0, 1.5), PI, "PickUp_Table", "pleb")
		"lumber":
			b.actor(Vector3(-2.0, 0, 2.05), PI, "Interact", "pleb")
			b.actor(Vector3(0.6, 0, 0.9), 0.4, "Fixing_Kneeling", "pleb")
		"quarry":
			b.actor(Vector3(-0.3, 0, 0.2), PI + 0.4, "Fixing_Kneeling", "pleb")
			b.actor(Vector3(1.7, 0, 1.2), PI - 0.5, "Interact", "pleb")
		"smithy":
			b.actor(Vector3(0.9, 0, 0.62), PI + 0.4, "Interact", "pleb")
			b.actor(Vector3(3.0, 0, 1.35), PI, "Push", "pleb")
		"warehouse":
			b.actor(Vector3(-1.2, 0, 2.7), PI, "PickUp_Table", "pleb")
		"market":
			for c: Vector3 in [Vector3(-4.6, 0, -3.4), Vector3(-1.3, 0, -3.4), Vector3(2.0, 0, -3.4), Vector3(-4.6, 0, 0.9), Vector3(2.0, 0, 0.9)]:
				b.actor(c + Vector3(1.3, 0, 0.2), 0.0, b.pick(["Interact", "Idle_Talking", "Idle"]), "any")
			b.actor(Vector3(-3.3, 0, 2.4), PI, "Idle_Talking", "female")
			b.actor(Vector3(3.3, 0, 2.4), PI + 0.3, "Idle_Talking", "rich")
		"well":
			b.actor(Vector3(0.95, 0, 0.75), -PI * 0.7, "Interact", "female")
		"temple":
			b.actor(Vector3(0, 0, 7.9), PI, "Spell_Simple_Idle", "rich")
		"baths":
			b.actor(Vector3(-4.6, 0, 3.6), PI * 0.8, "Idle_Talking", "rich")
			b.actor(Vector3(-3.9, 0, 3.2), -PI * 0.2, "Idle_Talking", "rich")
			b.actor(Vector3(4.5, 0, 0.2), -PI / 2, "Idle", "female")
		"theatre":
			b.actor(Vector3(0, 0.6, 5.6), PI, "Dance", "female")
		"forum":
			b.actor(Vector3(-1.6, 0, 1.2), 0.9, "Idle_Talking", "rich")
			b.actor(Vector3(-0.8, 0, 1.9), PI + 0.9, "Idle_Talking", "rich")
			b.actor(Vector3(2.4, 0, 3.8), 0.0, "Sword_Idle", "soldier")
		"center":
			if tier >= 2:
				b.actor(Vector3(-2.6, 0, 3.6), 0.0, "Sword_Idle", "soldier")
				b.actor(Vector3(0.1, 0, 3.6), 0.0, "Sword_Idle", "soldier")
			elif tier == 1:
				b.actor(Vector3(-1.4, 0, 3.4), 0.0, "Sword_Idle", "soldier")
			else:
				b.actor(Vector3(-2.0, 0, 0.2), PI, "Idle_Talking", "rich")
		"domus":
			if tier >= 1:
				b.actor(Vector3(2.4, 0, -4.2), b.rng.randf() * TAU, "Fixing_Kneeling", "pleb")
				b.actor(Vector3(-3.0, 0, 1.4), 0.4, "Idle_Talking", "rich")


# ---------- жильё плебеев: 5×5 м, растёт на месте ----------

static func _house(b: Bp, tier: int) -> void:
	b.paint(b.pick(Bp.PAINT))
	match tier:
		0:
			# пустой участок: колышки, верёвка, мешки и табличка
			for c: Vector3 in [Vector3(-2.2, 0, -2.2), Vector3(2.2, 0, -2.2), Vector3(-2.2, 0, 2.2), Vector3(2.2, 0, 2.2)]:
				b.add("SM_Prop_Pole_01", c, 0.0, 0.3)
			b.add("SM_Prop_Sack_Stack_02", Vector3(1.0, 0, 0.6), 0.6)
			b.add("SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 5), Vector3(-0.8, 0, -0.5), 1.0)
			b.door = Vector3(0, 0, 2.6)
		1:
			# хижина: беленая комнатка с черепичной крышей у задней межи, перед ней — дворик:
			# пергола с лозой над входом, стол с посудой, печь или ткацкий станок, сено, кувшины, плетень
			var di := b.rng.randi() % 2
			b.block(0, -1.25, 2, 1, 1, {"door_i": di, "door": "SM_Bld_Wall_Door_04", "win_p": 0.7})
			b.gable(0, -1.25, 2, 1, FL)
			var px := -1.25 if di == 0 else 1.25
			var ox := -px                         # вторая половина дворика
			for c: Vector3 in [Vector3(px - 1.05, 0, 2.2), Vector3(px + 1.05, 0, 2.2)]:
				b.add("SM_Bld_Trellis_Pillar_01", c, 0.0, 0.78)
			b.add("SM_Bld_Trellis_Roof_01", Vector3(px + 1.25, 2.44, 0.0), 0.0)
			b.add("SM_Env_Vine_0%d" % (1 + b.rng.randi() % 3), Vector3(px, 2.45, 1.1), b.rng.randf() * TAU, 0.75)
			if b.chance(0.6):
				b.add("SM_Env_Ivy_Pillar_Flowers_0%d" % (1 + b.rng.randi() % 2), Vector3(px + 1.05, 0, 2.2), 0.0, 0.78)
			b.add("SM_Prop_Table_0%d" % (1 + b.rng.randi() % 3), Vector3(px + 0.2, 0, 1.0), PI / 2, 0.8)
			b.add("SM_Prop_Seat_Stool_0%d" % (1 + b.rng.randi() % 2), Vector3(px - 0.6, 0, 1.2), b.rng.randf() * TAU)
			b.add("SM_Prop_Bowl_0%d" % (1 + b.rng.randi() % 5), Vector3(px + 0.1, 0.63, 0.9), 0.0, 0.7)
			b.add("SM_Prop_Jug_0%d" % (1 + b.rng.randi() % 5), Vector3(px + 0.35, 0.63, 1.15), 0.0, 0.7)
			match b.rng.randi() % 3:
				0:
					b.add("SM_Prop_Kiln_01", Vector3(ox + 0.4, 0, 0.95), b.rng.randf_range(-0.4, 0.4), 0.6)
					b.add("SM_Prop_Straw_Bundle_01", Vector3(ox - 0.7, 0, 1.6), b.rng.randf() * TAU)
				1:
					b.add("SM_Prop_Loom_01", Vector3(ox, 0, 0.6), 0.0, 0.85)
					b.add("SM_Prop_Basket_Set_0%d" % (1 + b.rng.randi() % 4), Vector3(ox + 0.7, 0, 1.5), b.rng.randf() * TAU, 0.7)
				_:
					b.add("SM_Prop_Straw_Stack_0%d" % (1 + b.rng.randi() % 2), Vector3(ox + 0.5, 0, 1.0), b.rng.randf() * TAU, 0.6)
					b.add("SM_Prop_Ladder_01", Vector3(ox - 0.9, 0, 0.12), 0.0)
			b.add("SM_Prop_Jar_01", Vector3(ox - 0.9, 0, 0.45), 0.0, 0.9)
			b.add("SM_Prop_Vase_0%d" % (1 + b.rng.randi() % 4), Vector3(ox - 0.55, 0, 0.35), b.rng.randf() * TAU, 0.8)
			b.add("SM_Env_Fence_Woof_0%d" % (1 + b.rng.randi() % 3), Vector3(ox - 1.25, 0, 2.35), 0.0, 1.0)
			b.add("SM_Prop_FlowerBed_0%d" % (1 + b.rng.randi() % 2), Vector3(px - 0.6, 0.35, -0.0), 0.0, 0.75)
			b.plants(ox - 1.0, 1.7, ox + 1.0, 2.2, 2)
			b.door = Vector3(px, 0, 2.6)
		2:
			if b.chance(0.65):
				# домик: две комнаты под двумя скатами, между ними крытое крыльцо со столом, цветы
				var fx := -1.25 if b.chance(0.5) else 1.25   # передняя комната
				var qx := -fx                                 # крыльцо
				b.block(0, -1.25, 2, 1, 1, {"door_i": 0 if qx < 0 else 1, "door": b.pick(["SM_Bld_Wall_Door_02", "SM_Bld_Wall_Door_03", "SM_Bld_Wall_Door_01"]), "win_p": 0.9, "win0": "SM_Bld_Wall_Window_06"})
				b.gable(0, -1.25, 2, 1, FL)
				b.block(fx, 1.25, 1, 1, 1, {"door_i": -1, "win_p": 1.0, "win0": "SM_Bld_Wall_Window_06", "sides": [0, 1 if fx < 0 else 3]})
				b.gable(fx, 1.25, 1, 1, FL)
				for c: Vector3 in [Vector3(qx - 1.1, 0, 2.3), Vector3(qx + 1.1, 0, 2.3)]:
					b.add("SM_Bld_Trellis_Pillar_01", c, 0.0, 0.84)
				b.add_xf("SM_Bld_Roof_Base_Straight_01", Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 0.55, 1.04)), Vector3(qx - 1.25, 2.62, 2.6)), true)
				b.add("SM_Bld_Roof_Edge_Straight_01", Vector3(qx - 1.25, 2.62, 2.6), 0.0, 1.0, true)
				b.add("SM_Prop_Table_0%d" % (1 + b.rng.randi() % 3), Vector3(qx, 0, 1.2), 0.0, 0.85)
				b.add("SM_Prop_Seat_Bench_0%d" % (1 + b.rng.randi() % 3), Vector3(qx, 0, 0.45), 0.0, 0.85)
				b.add("SM_Prop_Jug_0%d" % (1 + b.rng.randi() % 5), Vector3(qx - 0.3, 0.68, 1.2), 0.0, 0.7)
				b.add("SM_Prop_Bowl_0%d" % (1 + b.rng.randi() % 5), Vector3(qx + 0.25, 0.68, 1.15), 0.0, 0.7)
				b.add("SM_Prop_Pots_Hanging_0%d" % (1 + b.rng.randi() % 2), Vector3(qx + 0.9, 2.35, 2.3), 0.0)
				if b.chance(0.6):
					b.add("SM_Env_Ivy_Pillar_Flowers_0%d" % (1 + b.rng.randi() % 2), Vector3(qx + 1.1 * signf(qx), 0, 2.3), 0.0, 0.84)
				b.add("SM_Prop_FlowerBed_0%d" % (1 + b.rng.randi() % 2), Vector3(fx, 0.35, 2.55), 0.0, 0.8)
				b.add("SM_Prop_FlowerPot_Hanging_0%d" % (4 + b.rng.randi() % 3), Vector3(fx, 1.2, 2.63), 0.0)
				if b.chance(0.5):
					b.ivy(0, -1.25, 2, 1, 1)
			else:
				# домик: оштукатуренный, черепица, деревянный навес во всю ширину, лавочка, цветы
				var di := b.rng.randi() % 2
				b.block(0, 0, 2, 2, 1, {"door_i": di, "door": b.pick(["SM_Bld_Wall_Door_02", "SM_Bld_Wall_Door_03"]), "win_p": 0.9, "win0": "SM_Bld_Wall_Window_06"})
				b.gable(0, 0, 2, 2, FL)
				b.on_wall("SM_Prop_Overhang_01", 0, 0, 2, 2, 0, 0.5, 2.7, 0.12)
				b.on_wall("SM_Prop_Overhang_01", 0, 0, 2, 2, 0, 1.5, 2.7, 0.12)
				b.door_decor(0, 0, 2, 2, di)
				b.window_pots(0, 0, 2, 2, 0)
				b.add("SM_Prop_FlowerBed_0%d" % (1 + b.rng.randi() % 2), Vector3(1.25 if di == 0 else -1.25, 0.35, 2.55), 0.0, 0.8)
				b.add(b.pick(["SM_Prop_Jar_Pile_01", "SM_Prop_Vase_Pile_0%d" % (1 + b.rng.randi() % 6), "SM_Prop_Straw_Bundle_01"]), Vector3(2.15 if di == 0 else -2.15, 0, 2.85), b.rng.randf() * TAU, 0.75)
				if b.chance(0.6):
					b.ivy(0, 0, 2, 2, 1)
		3:
			# инсула: лавка внизу, жильё наверху, балкон с цветами и ковром, плющ
			var di := b.rng.randi() % 2
			b.block(0, 0, 2, 2, 2, {"door_i": di, "shop": [1 - di]})
			b.gable(0, 0, 2, 2, 2 * FL)
			b.shop_front(0, 0, 2, 2, 1 - di)
			b.balcony(0, 0, 2, 2, b.rng.randi() % 2, 1)
			b.window_pots(0, 0, 2, 2, 1)
			b.door_decor(0, 0, 2, 2, di)
			b.ivy(0, 0, 2, 2, 2)
			if b.chance(0.4):
				b.wall_banner(0, 0, 2, 2, 0.5 if di == 1 else 1.5, 2 * FL - 0.35)
		_:
			# большая инсула: три этажа под черепицей, лавка, балконы на двух этажах, знамёна, плющ
			var di := b.rng.randi() % 2
			b.block(0, 0, 2, 2, 3, {"door_i": di, "shop": [1 - di]})
			b.gable(0, 0, 2, 2, 3 * FL)
			b.shop_front(0, 0, 2, 2, 1 - di)
			b.balcony(0, 0, 2, 2, 0, 1)
			b.balcony(0, 0, 2, 2, 1, 2)
			if b.chance(0.5):
				b.balcony(0, 0, 2, 2, 1, 1)
			b.window_pots(0, 0, 2, 2, 1)
			b.window_pots(0, 0, 2, 2, 2)
			b.door_decor(0, 0, 2, 2, di)
			b.ivy(0, 0, 2, 2, 3)
			b.ivy(0, 0, 2, 2, 2)
			b.wall_banner(0, 0, 2, 2, 0.5 if di == 1 else 1.5, 2 * FL - 0.35)
			if b.chance(0.5):
				b.on_wall("SM_Prop_Overhang_01", 0, 0, 2, 2, 0, 0.5 if di == 0 else 1.5, 2.75, 0.12)


# ---------- патриции: 10×10 м ----------

static func _domus(b: Bp, tier: int) -> void:
	b.paint(b.pick(["White", "Orange", "Red", "White"]))
	if tier == 0:
		b.fence(-4.8, -4.8, 4.8, 4.8)
		b.add("SM_Prop_Marble_Block_02", Vector3(1.5, 0, 0.5), 0.3)
		b.add("SM_Prop_Marble_Rubble_04", Vector3(-1.0, 0, -1.0), 0.0)
		b.door = Vector3(0, 0, 5.2)
		return
	var floors := 1 if tier <= 2 else 2
	# дом в глубине участка (4×2 модуля), перед ним портик с колоннами, сзади сад
	b.block(0, -1.25, 4, 2, floors, {"door_i": 1, "door": "SM_Bld_Wall_Door_Double_01", "win_p": 0.7})
	var ridge := b.gable(0, -1.25, 4, 2, floors * FL)
	# портик с колоннами и черепичным навесом до стены
	b.portico(-5.0, 5.0, 2.9, 0.0, 0.92, "SM_Bld_Pillar_0%d" % (1 + b.rng.randi() % 5), tier >= 3)
	b.add("SM_Prop_Rug_01", Vector3(-1.25, 0.01, 1.4), PI / 2, 0.8)
	# дорожка от ворот и клумбы
	b.add("SM_Prop_FlowerBed_01", Vector3(-3.2, 0, 4.4), 0.0)
	b.add("SM_Prop_FlowerBed_02", Vector3(3.2, 0, 4.4), 0.0)
	b.door = Vector3(-1.25, 0, 5.3)
	b.light(Vector3(-1.25, 2.3, 2.6))
	# сад сзади: фонтанчик, деревья, скамья
	if tier >= 2:
		b.add("SM_Prop_Fountain_04", Vector3(0, 0, -4.3), 0.0, 0.45)
		b.add("SM_Prop_Fountain_04_Insert_01", Vector3(0, 0, -4.3), 0.0, 0.45)
		b.column_statue(Vector3(-4.0, 0, 4.4), 0.0, 0.8)
		b.column_statue(Vector3(4.0, 0, 4.4), 0.0, 0.8)
	b.add("SM_Env_Tree_Thin_0%d" % (1 + b.rng.randi() % 2), Vector3(-4.2, 0, -4.3), 0.0, 0.6)
	b.add("SM_Env_Tree_Thin_0%d" % (1 + b.rng.randi() % 2), Vector3(4.2, 0, -4.3), 0.0, 0.6)
	b.plants(-3.5, -4.9, 3.5, -3.6, 3)
	if tier >= 3:
		# вилла: терраса-пергола над садом, бассейн, жаровни
		b.add("SM_Prop_Seat_Kline_Large_0%d" % (1 + b.rng.randi() % 3), Vector3(-2.4, 0, -4.3), 0.0, 0.8)
		b.brazier(Vector3(-4.6, 0, 3.6), true)
		b.brazier(Vector3(4.6, 0, 3.6), true)
		b.window_pots(0, -1.25, 4, 2, 1)
		b.balcony(0, -1.25, 4, 2, 2, 1)
	if tier >= 4:
		# дворец: знамёна, драпировки и золото на колоннах, статуи на крыше
		for i in 4:
			b.add("SM_Prop_Drapery_0%d" % (1 + i % 3), Vector3(-3.75 + i * M, 2.7, 3.05), 0.0)
		b.wall_banner(0, -1.25, 4, 2, 0.5, 2 * FL - 0.35)
		b.wall_banner(0, -1.25, 4, 2, 3.5, 2 * FL - 0.35)
		b.add("SM_Prop_Statue_0%d" % (1 + b.rng.randi() % 7), Vector3(-4.6, ridge - 0.4, -1.25), 0.0, 0.6)
		b.add("SM_Prop_Statue_0%d" % (1 + b.rng.randi() % 7), Vector3(4.6, ridge - 0.4, -1.25), 0.0, 0.6)
		b.add("SM_Prop_Statue_Lion_01", Vector3(-3.6, 0, 5.0), 0.0, 0.35)
		b.add("SM_Prop_Statue_Lion_01", Vector3(3.6, 0, 5.0), 0.0, 0.35)
	b.ivy(0, -1.25, 4, 2, floors)


# ---------- еда ----------

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


## Мастерская 5×5: домик 2×1 модуля в глубине, перед ним двор с печью/жерновом/амфорами
static func _workshop(b: Bp, kind: String) -> void:
	b.paint(b.pick(["White", "Orange", "Brick"]))
	b.block(0, -1.25, 2, 1, 1, {"door_i": 0, "shop": [1], "win_p": 0.4})
	b.gable(0, -1.25, 2, 1, FL, false)
	b.add("SM_Prop_Overhang_01", Vector3(1.25, 2.75, 0.12), 0.0)
	match kind:
		"bakery":
			b.add("SM_Prop_Kiln_01", Vector3(1.2, 0, 1.3), PI, 0.75)
			b.light(Vector3(1.2, 0.6, 1.9))
			b.add("SM_Prop_Sack_Stack_01", Vector3(-1.3, 0, 1.6), 0.3, 0.8)
			b.add("SM_Prop_Table_05", Vector3(-1.6, 0, 0.8), 0.0, 0.9)
			b.add("SM_Prop_Basket_Insert_03", Vector3(-1.6, 0.72, 0.8), 0.0, 0.8)
		"oilpress":
			b.add("SM_Prop_Grinding_Wheel_01", Vector3(1.0, 0.34, 1.3), 0.6)
			b.add("SM_Prop_Jar_Pile_01", Vector3(-1.4, 0, 1.5), 0.0, 0.9)
			b.add("SM_Prop_Basket_Set_04", Vector3(-1.6, 0, 0.5), 0.0, 0.7)
		_:
			b.add("SM_Prop_Vase_Pile_0%d" % (1 + b.rng.randi() % 6), Vector3(1.2, 0, 1.4), 0.0)
			b.add("SM_Prop_Vase_Pile_0%d" % (1 + b.rng.randi() % 6), Vector3(-1.3, 0, 1.6), 1.0)
			b.add("SM_Prop_Basket_Set_06", Vector3(-1.7, 0, 0.6), 0.0, 0.7)
	b.door = Vector3(0, 0, 2.7)


static func _market(b: Bp) -> void:
	# ряды лавок под тканевыми навесами на шестах: столы с товаром, ковры, корзины
	var roofs := ["SM_Prop_Banner_Roof_01", "SM_Prop_Banner_Roof_03"]
	var goods := ["SM_Prop_Vase_0%d", "SM_Prop_Jug_0%d", "SM_Prop_Bowl_0%d", "SM_Prop_Basket_0%d", "SM_Prop_Plate_0%d"]
	var stalls := [Vector3(-4.6, 0, -3.4), Vector3(-1.3, 0, -3.4), Vector3(2.0, 0, -3.4), Vector3(-4.6, 0, 0.9), Vector3(2.0, 0, 0.9)]
	for s in stalls.size():
		var c: Vector3 = stalls[s]
		for d: Vector3 in [Vector3(0, 0, 0), Vector3(2.6, 0, 0), Vector3(0, 0, 2.6), Vector3(2.6, 0, 2.6)]:
			b.add("SM_Prop_Pole_0%d" % (1 + b.rng.randi() % 2), c + d, 0.0, 0.92)
		b.add(b.pick(roofs), c + Vector3(0, 2.78, 0), 0.0)
		var t := c + Vector3(1.3, 0, 0.75)
		b.add("SM_Prop_Table_08", t, 0.0, 0.85)
		for k in 4:
			var nm: String = (b.pick(goods) as String) % (1 + b.rng.randi() % 3)
			b.add(nm, t + Vector3(-0.8 + k * 0.53, 0.66, b.rng.randf_range(-0.2, 0.2)), b.rng.randf() * TAU, 0.55)
		b.add("SM_Prop_Rug_03", c + Vector3(1.3, 0.01, 1.8), b.rng.randf() * 0.3, 0.9)
		b.add(b.pick(["SM_Prop_Basket_Set_01", "SM_Prop_Jar_Pile_01", "SM_Prop_Vase_Pile_02", "SM_Prop_Sack_Stack_01", "SM_Prop_Basket_Set_03"]), c + Vector3(b.rng.randf_range(0.4, 2.2), 0, 2.2), b.rng.randf() * TAU, 0.8)
	b.add("SM_Prop_Shelf_01", Vector3(-1.3 + 1.3, 0, 2.7), 0.0, 0.9)
	b.add("SM_Prop_Cart_01", Vector3(4.2, 0, 2.6), 0.4, 0.8)
	b.add("SM_Prop_Cart_01_Insert_01", Vector3(4.2, 0, 2.6), 0.4, 0.8)
	b.brazier(Vector3(-4.8, 0, 3.5))
	b.door = Vector3(0, 0, 4.0)


# ---------- ремёсла ----------

static func _lumber(b: Bp) -> void:
	# навес на столбах, штабели брусьев, лестница, козлы
	for c: Vector3 in [Vector3(-3.4, 0, -2.2), Vector3(-0.9, 0, -2.2), Vector3(1.6, 0, -2.2), Vector3(-3.4, 0, 0.3), Vector3(-0.9, 0, 0.3), Vector3(1.6, 0, 0.3)]:
		b.add("SM_Bld_Trellis_Pillar_01", c, 0.0, 0.9)
	b.add("SM_Bld_Trellis_Roof_01", Vector3(-0.9, 2.8, -2.2), 0.0)
	b.add("SM_Bld_Trellis_Roof_01", Vector3(1.6, 2.8, -2.2), 0.0)
	for k in 6:
		b.add("SM_Prop_Beam_01", Vector3(-2.3, 0.08 + (k % 3) * 0.16, -1.6 + int(k / 3) * 0.3), 0.0)
	for k in 5:
		b.add("SM_Prop_Beam_01", Vector3(0.3, 0.08 + k * 0.15, 1.6), 0.08 * k)
	b.add("SM_Prop_Ladder_01", Vector3(2.8, 0, -1.4), 0.4)
	b.add("SM_Prop_Table_01", Vector3(-2.0, 0, 1.4), 0.0, 0.9)
	b.add("SM_Prop_Tool_Hammer_01", Vector3(-2.0, 0.72, 1.4), 0.6)
	b.add("SM_Prop_Straw_Bundle_01", Vector3(3.1, 0, 1.6), 0.0)
	b.door = Vector3(0, 0, 2.7)


static func _quarry(b: Bp) -> void:
	b.add("SM_Env_Rock_Cliff_02", Vector3(-1.8, -0.2, -2.4), 0.4, 0.95)
	b.add("SM_Env_Rock_Cliff_02", Vector3(1.6, -0.3, -2.6), 2.1, 0.8)
	b.add("SM_Prop_Marble_Block_01", Vector3(-2.2, 0, 1.2), 0.2, 0.8)
	b.add("SM_Prop_Marble_Block_02", Vector3(-0.6, 0, 1.6), 1.1, 0.8)
	b.add("SM_Prop_Marble_Block_03", Vector3(0.6, 0, 0.6), 0.5, 0.8)
	b.add("SM_Prop_Marble_Rubble_01", Vector3(1.2, 0, -0.6), 0.0)
	b.add("SM_Prop_Marble_Rubble_04", Vector3(-1.0, 0, -0.4), 1.0)
	b.add("SM_Prop_Marble_Pile_01", Vector3(2.6, 0, 1.8), 0.6, 0.8)
	b.add("SM_Prop_Cart_02", Vector3(-2.6, 0.49, 2.8), 1.6, 0.8)
	b.add("SM_Prop_Ladder_01", Vector3(0.1, 0, -1.5), 0.3)
	b.add("SM_Prop_Tool_Chisel_01", Vector3(0.6, 0.9, 0.6), 0.7)
	b.door = Vector3(0, 0, 4.0)


static func _smithy(b: Bp) -> void:
	b.paint("Brick")
	b.block(-2.5, -1.25, 1, 1, 1, {"door_i": 0, "win_p": 0.5})
	b.gable(-2.5, -1.25, 1, 1, FL, false)
	# открытая кузня под навесом: горн, наковальня, стойка с оружием, точильный круг
	for c: Vector3 in [Vector3(-1.2, 0, -2.4), Vector3(3.6, 0, -2.4), Vector3(-1.2, 0, 1.2), Vector3(3.6, 0, 1.2)]:
		b.add("SM_Prop_Pole_01", c, 0.0, 0.95)
	b.add("SM_Prop_Banner_Roof_02", Vector3(-1.2, 2.85, -2.4), 0.0, 0.95)
	b.add("SM_Prop_Forge_01", Vector3(2.4, 0, -1.4), 0.0, 0.85)
	b.light(Vector3(2.4, 0.9, -0.6))
	b.add("SM_Prop_Anvil_01", Vector3(0.9, 0, -0.1), 0.4)
	b.add("SM_Prop_Weapon_Rack_01", Vector3(0.6, 0, -1.9), 0.0, 0.9)
	b.add("SM_Prop_Weapon_Rack_01_Insert_01", Vector3(0.6, 0, -1.9), 0.0, 0.9)
	b.add("SM_Prop_Grinding_Wheel_01", Vector3(3.0, 0.34, 0.6), 1.2)
	b.add("SM_Prop_Rug_02", Vector3(1.0, 0.01, 1.6), PI / 2, 0.8)
	b.door = Vector3(0, 0, 2.7)


static func _warehouse(b: Bp) -> void:
	b.paint(b.pick(["White", "Brick", "Orange"]))
	b.block(0, -0.6, 3, 1, 1, {"door_i": 1, "door": "SM_Bld_Wall_Door_Double_Large_01", "win_p": 0.3})
	b.gable(0, -0.6, 3, 1, FL, false)
	b.add("SM_Prop_Sack_Stack_01", Vector3(-2.6, 0, 1.6), 0.2, 0.9)
	b.add("SM_Prop_Sack_Stack_02", Vector3(-2.6, 0.6, 1.5), 0.6, 0.8)
	b.add("SM_Prop_Jar_Pile_01", Vector3(2.5, 0, 1.7), 0.0)
	b.add("SM_Prop_Basket_Set_02", Vector3(-1.2, 0, 2.0), 0.4, 0.8)
	b.add("SM_Prop_Cart_01", Vector3(1.4, 0, 1.9), 1.5, 0.75)
	b.add("SM_Prop_Cart_01_Insert_02", Vector3(1.4, 0, 1.9), 1.5, 0.75)
	b.door = Vector3(0, 0, 2.7)


# ---------- службы ----------

static func _well(b: Bp) -> void:
	b.add("SM_Prop_Well_01", Vector3(0, 0, 0), 0.0, 0.85)
	b.add("SM_Prop_Jug_0%d" % (1 + b.rng.randi() % 4), Vector3(1.2, 0, 0.9), 0.4)
	b.add("SM_Env_Flowers_0%d" % (1 + b.rng.randi() % 5), Vector3(-1.2, 0, 1.0), 0.0, 1.3)
	b.door = Vector3(0, 0, 1.6)


static func _fountain(b: Bp) -> void:
	b.add("SM_Prop_Fountain_04", Vector3.ZERO, 0.0, 1.35)
	b.add("SM_Prop_Fountain_04_Insert_01", Vector3.ZERO, 0.0, 1.35)
	for c: Vector3 in [Vector3(-2.1, 0, -2.1), Vector3(2.1, 0, -2.1), Vector3(-2.1, 0, 2.1), Vector3(2.1, 0, 2.1)]:
		b.add("SM_Prop_FlowerPot_Fancy_01", c + Vector3(0, 0.57 * 0.7, 0), 0.0, 0.7)
	b.add("SM_Env_Lillies_02", Vector3(0.8, 0.85, 0.5), 0.0, 0.6)
	b.door = Vector3(0, 0, 2.6)


## Храм: строится в «родном» масштабе Synty (колонны 6 м) и уменьшается до участка 10×15 м
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
	b.paint("White")
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
	b.paint("White")
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


## Центр города (10×10 м): растёт со званием
static func _center(b: Bp, stage: int) -> void:
	b.paint("White")
	if stage == 0:
		# лагерь переселенцев: навесы на шестах, столы, мешки, телега, костёр, знамя
		for c: Vector3 in [Vector3(-4.5, 0, -2.0), Vector3(0.6, 0, -2.0), Vector3(-4.5, 0, 0.6), Vector3(0.6, 0, 0.6)]:
			b.add("SM_Prop_Pole_01", c, 0.0, 0.9)
		b.add("SM_Prop_Banner_Roof_02", Vector3(-4.5, 2.7, -2.0), 0.0)
		b.add("SM_Prop_Table_08", Vector3(-2.0, 0, -0.7), 0.0, 0.9)
		b.add("SM_Prop_Scroll_Pile_01", Vector3(-2.4, 0.7, -0.7), 0.0, 0.8)
		b.add("SM_Prop_Bowl_03", Vector3(-1.4, 0.7, -0.7), 0.0, 0.7)
		b.add("SM_Prop_Sack_Stack_01", Vector3(2.8, 0, -3.0), 0.3)
		b.add("SM_Prop_Basket_Set_01", Vector3(3.3, 0, -1.2), 1.0, 0.9)
		b.add("SM_Prop_Cart_01", Vector3(3.2, 0, 2.5), 0.8, 0.85)
		b.add("SM_Prop_Cart_01_Insert_03", Vector3(3.2, 0, 2.5), 0.8, 0.85)
		b.brazier(Vector3(-1.0, 0, 3.0), true)
		b.add("SM_Prop_Pole_02", Vector3(-4.2, 0, 3.6), 0.0, 1.3)
		b.add("SM_Prop_Banner_03_A", Vector3(-4.2, 3.9, 3.6), 0.0)
		b.add("SM_Prop_Straw_Stack_01", Vector3(-4.0, 0, -3.8), 0.0)
		b.add("SM_Prop_Rug_03", Vector3(-2.0, 0.01, -0.6), 0.0)
		b.door = Vector3(0, 0, 5.2)
		return
	if stage == 1:
		# дом старосты: двухэтажный дом с портиком
		b.block(0, -1.25, 3, 2, 2, {"door_i": 1, "door": "SM_Bld_Wall_Door_Double_01"})
		b.gable(0, -1.25, 3, 2, 2 * FL)
		b.balcony(0, -1.25, 3, 2, 1, 1)
		b.wall_banner(0, -1.25, 3, 2, 0.5, 2 * FL - 0.35)
		b.wall_banner(0, -1.25, 3, 2, 2.5, 2 * FL - 0.35)
		b.brazier(Vector3(-2.5, 0, 3.0))
		b.brazier(Vector3(2.5, 0, 3.0))
		b.add("SM_Prop_FlowerBed_01", Vector3(-3.6, 0, 4.2), 0.0)
		b.add("SM_Prop_FlowerBed_02", Vector3(3.6, 0, 4.2), 0.0)
		b.ivy(0, -1.25, 3, 2, 2)
		b.door = Vector3(0, 0, 3.0)
		return
	# курия / базилика / дворец: здание с колоннадой на подиуме, растёт этажами и украшениями
	var floors := 2 if stage < 4 else 3
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
	if stage >= 5:
		b.add("SM_Prop_Banner_Large_01", Vector3(0, floors * FL - 0.3, 1.4), 0.0, 0.65)
	b.door = Vector3(-1.25, 0, 5.0)


# ---------- украшения ----------

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
		"goods": b.add(b.pick(["SM_Prop_Basket_Set_01", "SM_Prop_Jar_Pile_01", "SM_Prop_Vase_Pile_01", "SM_Prop_Vase_Pile_03", "SM_Prop_Sack_Stack_01"]), Vector3.ZERO, b.rng.randf() * TAU)
	b.door = Vector3(0, 0, 1.0)
