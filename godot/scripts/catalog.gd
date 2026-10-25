class_name Catalog
extends RefCounted
## Облик построек — как в Town to City: у каждого типа несколько продуманных фасадов (variant),
## дом растёт этажами (tier = этажи), цвет штукатурки — из палитры (color). Всё собрано из деталей Synty.

const M := Bp.M
const FL := Bp.FL
## Масштаб построек: детали Synty в натуральную величину, а нам нужен «кукольный» город как в Town to City —
## дома чуть меньше, люди заметно меньше дверей (Citizen.SIZE)
const ARCH := 0.72
const DECOR := 0.78

static var _cache := {}


static func make(type: String, tier := 1, variant := 0, color := 0) -> Bp:
	var dd0: Dictionary = Defs.B.get(type, {})
	if dd0.get("kind", "") == "decor":
		# украшение всегда выглядит как его карточка: облик задаёт тип, а не цвет, место или фасад
		# (у звена забора variant 1 — калитка)
		tier = 0
		variant = clampi(variant, 0, 1) if dd0.get("seg", false) else 0
		color = int(dd0.get("color", 0))
	var key := "%s:%d:%d:%d" % [type, tier, variant, color]
	if _cache.has(key):
		return _cache[key]
	# здание Легиона растёт с уровнем (tier — облик уровня, Legion.vis_tier): случай — как у 1-го уровня, чтобы
	# знамёна и плющ не менялись от уровня к уровню, а только прибавлялось новое
	var mil := String(dd0.get("kind", "")) == "military"
	var b := Bp.new(hash("%s:0:%d:%d" % [type, variant, color]) if mil else hash(key))
	b.paint(color)
	match type:
		"house_pleb": CatHouses._house_pleb(b, tier, variant)
		"house_artisan": CatHouses._house_artisan(b, tier, variant)
		"house_patrician": CatHouses._house_patrician(b, tier, variant)
		"stall_fruit": CatShops._stall(b, "fruit", variant)
		"stall_veg": CatShops._stall(b, "veg", variant)
		"stall_fish": CatShops._stall(b, "fish", variant)
		"butcher", "bakery", "cobbler", "dyer", "tailor", "potter", "oilshop", "lamps", "wineshop", "perfumer", "jeweler", "weaver", "barber", "medic":
			CatShops._shop(b, type, variant)
		"thermopolium": CatShops._thermopolium(b)
		"ogorod", "shelter", "puppets", "herbalist", "vigiles", "sculptor", "prefect", "nymphaeum": CatExtra.make(b, type)   # этап 5
		"ludus", "aqua", "venus", "thermae", "pharos", "circus_fl": CatGrand.make(b, type)   # этап 5, волна 2
		"taberna": CatShops._taberna(b)
		"fullonica": CatShops._fullonica(b)
		"musicians": CatShops._musicians(b)
		"dice": CatShops._dice(b)
		"mimes": CatShops._mimes(b)
		"odeon": CatCivic._odeon(b)
		"theatre": CatCivic._theatre(b)
		"balnea": CatCivic._balnea(b)
		"baths": CatCivic._baths(b)
		"farm": CatCivic._farm(b)
		"grove": CatCivic._grove(b)
		"vineyard": CatCivic._vineyard(b)
		"warehouse": CatCivic._warehouse(b)
		"scriptorium": CatCivic._scriptorium(b)
		"school": CatCivic._school(b)
		"library": CatCivic._library(b)
		"academy": CatCivic._academy(b)
		"fountain": CatMonuments._fountain(b)
		"temple": CatMonuments._temple(b)
		"forum": CatMonuments._forum(b)
		"arch": CatMonuments._arch(b)
		"colosseum": CatMonuments._colosseum(b)
		"pantheon": CatMonuments._pantheon(b)
		"center": CatCivic._center(b, tier)
		"barracks", "range", "spearcamp", "ballistae", "catapults", "forge", "infirmary", "armory": CatMilitary.make(b, type, tier)
		_: CatDecor._decor(b, type, variant)
	b.base = Transform3D.IDENTITY
	_actors(b, type, tier)
	var dd: Dictionary = Defs.B.get(type, {})
	_scale(b, DECOR if dd.get("kind", "") == "decor" and not dd.get("wall", false) else ARCH)   # на стенах — в масштабе дома
	_cache[key] = b
	return b


## Уменьшить весь чертёж вокруг основания: детали, огни, дым, людей при деле, вход
static func _scale(b: Bp, s: float) -> void:
	var S := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), Vector3.ZERO)
	for p in b.parts:
		p[1] = S * (p[1] as Transform3D)
	for i in b.lights.size():
		b.lights[i] = b.lights[i] * s
	for i in b.smoke.size():
		b.smoke[i] = b.smoke[i] * s
	for a in b.actors:
		a[0] = (a[0] as Vector3) * s
	b.door = b.door * s


# ---------- жильё ----------


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


const CANOPY := [Color(1, 1, 1), Color(0.55, 0.78, 0.95), Color(1.0, 0.86, 0.45), Color(0.62, 0.86, 0.55), Color(1.0, 0.62, 0.5), Color(0.86, 0.7, 0.95)]


static func canopy_remap(i: int) -> Dictionary:
	var k := posmod(i, CANOPY.size())
	if k == 0:
		return {}
	return {"PolygonAncientEmpire_01_A": "PolygonAncientEmpire_01_C", "tints": {"PolygonAncientEmpire_01_C": CANOPY[k]}}


# ---------- науки ----------


# ---------- памятники ----------


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
		# продавцы без покупателя не говорят «в воздух»: ждут, перекладывают товар; заговорят, когда подойдёт
		# покупатель (People._keeper_react)
		"stall_fruit", "stall_veg", "stall_fish":
			b.actor(Vector3(0, 0, -0.4), 0.0, "Idle", "any")
		"butcher", "cobbler", "potter", "oilshop", "wineshop", "lamps":
			b.actor(Vector3(1.0 * CatShops.SX, 0, 0.6), 0.0, "Interact", "any")
		"perfumer", "jeweler", "tailor", "weaver", "medic":
			b.actor(Vector3(1.25 * CatShops.SX, 0, 0.35), 0.0, "Interact", "any")
		"bakery":
			b.actor(Vector3(-1.2, 0, 1.75), PI, "Interact", "pleb")
		"barber":
			# первым — цирюльник с бритвой (работник один — его место первое), вторым — клиент в кресле
			b.actor(Vector3(1.9, 0, 1.2), -PI / 2, "Interact", "any")
			b.actor(Vector3(1.25, 0, 1.0), 0.0, "Sitting_Idle", "pleb")
		"thermopolium":
			b.actor(Vector3(-1.25, 0, 0.34), 0.0, "Interact", "any")
		"taberna":
			b.actor(Vector3(-2.0, 0, 2.1), PI, "Interact", "any")
			b.actor(Vector3(1.8, 0, 0.7), 0.0, "Idle", "any")
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
			b.actor(Vector3(-2.0, 0, 2.6), PI, "Idle", "any")
		"school":
			b.actor(Vector3(0, 0, 2.6), PI, "Idle", "rich")
		"scriptorium":
			b.actor(Vector3(1.2, 0, 1.7), PI, "Sitting_Idle", "pleb")
		"temple":
			b.actor(Vector3(0, 0, 7.1), PI, "Spell_Simple_Idle", "rich")
		"forum":
			b.actor(Vector3(-1.6, 0, 1.2), 0.9, "Idle", "rich")
			b.actor(Vector3(2.4, 0, 3.8), 0.0, "Sword_Idle", "soldier")
		"center":
			b.actor(Vector3(1.0, 0, 1.0) * CatCivic.CENTER_K, 0.4, "Idle", "any")
			if tier >= 2:
				b.actor(Vector3(-2.6, 0, 3.6) * CatCivic.CENTER_K, 0.0, "Sword_Idle", "soldier")
		"house_patrician":
			b.actor(Vector3(1.1, 0, -4.2), b.rng.randf() * TAU, "Fixing_Kneeling", "pleb")


static func _trim_run(b: Bp, a: Vector3, dir: Vector3, len: float) -> void:
	var yaw := atan2(-dir.z, dir.x)
	var n := maxi(1, int(round(len / 2.5)))
	var step := len / n
	for i in n:
		b.add_xf("SM_Bld_Trim_Large_Single_01", Transform3D(Basis(Vector3.UP, yaw).scaled_local(Vector3(step / 2.5, 1, 1)), a + dir * step * i))


