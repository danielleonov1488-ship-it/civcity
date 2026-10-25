class_name CatDecor2
extends RefCounted
## Украшения этапа 5 (план 24.10, 5.2–5.3): наборы по исследованию на набор, на всех уровнях города — сельский двор,
## южные деревья, вода, скотный двор, ремесло, рынок, сад, статуи и руины, ночные огни, фрески, праздник, боги,
## «главные» украшения. Как и CatDecor: чертёж в родных размерах Synty (Catalog потом уменьшает до Catalog.DECOR),
## облик задаёт тип (look), мелочи — из b.rng (зависит только от типа). Настенные — от поверхности стены, +Z наружу.

const BLOOMS := CatDecor.BLOOMS
const TRUE_COLOR := CatDecor.TRUE_COLOR
const GILT := CatDecor.GILT
const HEDGE := CatDecor.HEDGE
const PUMPKIN := Color(1.5, 0.78, 0.28)
const OLIVE := Color(0.78, 0.9, 0.78)
const SOIL := Color(0.55, 0.4, 0.28)
const BRONZE_RM := {"tint": Color(0.72, 0.52, 0.32)}
const RED_PLAQUE := {"tint": Color(0.82, 0.36, 0.28)}
const BLUE_PLAQUE := {"tint": Color(0.42, 0.6, 0.86)}

## Живые животные у украшений (game._pets2): вид → [[кто, где (в осях украшения, без масштаба), поворот, движение,
## масштаб, облик (−1 — у всех)], …]
const PETS := {
	"cow": [["cow", Vector3(0.15, 0, 0.1), 0.5, "Eating", 1.0, 0], ["cow", Vector3(0.0, 0, 0.35), PI / 2, "Eating", 1.0, 1]],
	"horse": [["horse", Vector3(0.0, 0, 0.45), PI / 2, "Idle", 1.0, 0], ["horse", Vector3(0.05, 0, 0.05), PI / 2, "Eating", 1.0, 1]],
}
## Модели животных (Quaternius, CC0 — assets/animals/LICENSE.txt) и их длина от морды до хвоста, м
const BEASTS := {"cow": ["res://assets/animals/Cow.glb", 1.75], "horse": ["res://assets/animals/Horse_b.glb", 1.9],
	"donkey": ["res://assets/animals/Donkey.glb", 1.55]}


static func make(b: Bp, base: String, lk: int) -> void:
	match base:
		"veggies": _veggies(b, lk)
		"porch": _porch(b, lk)
		"woodpile": _woodpile(b, lk)
		"bigtree": _bigtree(b, lk)
		"pond": _pond(b, lk)
		"trough": _trough(b, lk)
		"basin": _basin(b, lk)
		"cow": _cow(b, lk)
		"horse": _horse(b, lk)
		"manger": _manger(b, lk)
		"forge_corner": _forge_corner(b, lk)
		"loom": _loom(b, lk)
		"kiln": _kiln(b, lk)
		"marble_yard": _marble_yard(b, lk)
		"awning": _awning(b, lk)
		"rugs": _rugs(b, lk)
		"handcart": _handcart(b, lk)
		"scrolls": _scrolls(b)
		"topiary": _topiary(b, lk)
		"trellis": _trellis(b, lk)
		"parterre": _parterre(b, lk)
		"ruins": _ruins(b, lk)
		"altar": _altar(b, lk)
		"bigvase": _bigvase(b, lk)
		"unfinished": _unfinished(b)
		"torchpost": _torchpost(b, lk)
		"incense": _incense(b, lk)
		"lanterns": _lanterns(b, lk)
		"fresco": _fresco(b, lk)
		"emblem": _emblem(b, lk)
		"drape": _drape(b, lk)
		"numeral": _numeral(b)
		"garland": _garland(b, lk)
		"bigbanner": _bigbanner(b, lk)
		"feast": _feast(b, lk)
		"poet": _poet(b)
		"colossus": _colossus(b, lk)
		"bigtorch": _bigtorch(b)
		"eagle": _eagle(b)
		"exedra": _exedra(b)
		"garden_pool": _garden_pool(b)
		"mosaic_panel": _mosaic_panel(b)
		"mosaic_court": _mosaic_court(b)
		"obelisk": _obelisk(b)
		"victory_col": _victory_col(b)
		"emperor": _emperor(b)
		"great_fountain": _great_fountain(b)


# ---------- помощники ----------

static func _yaw(b: Bp) -> float:
	return b.rng.randf() * TAU


static func _add(b: Bp, name: String, pos: Vector3, yaw: float, s: float, rm := {}) -> void:
	CatDecor._addr(b, name, pos, yaw, s, rm)


static func _sx(b: Bp, name: String, pos: Vector3, yaw: float, sv: Vector3, rm := {}) -> void:
	CatDecor._sx(b, name, pos, yaw, sv, rm)


## Коробка своего материала (#water, #marble, #dark): середина низа c
static func _box(b: Bp, mat: String, c: Vector3, size: Vector3, yaw := 0.0, rm := {}) -> void:
	b.parts.append([mat, b.base * Transform3D(Basis(Vector3.UP, yaw).scaled(size), c + Vector3(0, size.y / 2.0, 0)), rm.duplicate()])


## Брус Synty (2,5 м вдоль +X) от точки a длиной len, толщина k
static func _beam(b: Bp, a: Vector3, len: float, yaw := 0.0, k := 1.0) -> void:
	_sx(b, "SM_Prop_Beam_01", a, yaw, Vector3(len / 2.5, k, k))


## Столб высотой h (низ на p)
static func _pole(b: Bp, p: Vector3, h: float, thick := 1.0, name := "SM_Prop_Pole_01") -> void:
	_sx(b, name, p, 0.0, Vector3(thick, h / 3.0, thick))


## Полено: столб Synty, лежащий вдоль X (середина p), длиной len
static func _log(b: Bp, p: Vector3, len: float, k := 1.4) -> void:
	b.add_xf("SM_Prop_Pole_01", Transform3D(Basis(Vector3.BACK, PI / 2) * Basis.from_scale(Vector3(k, len / 3.0, k)), p + Vector3(len / 2.0, 0, 0)))


## Дощатая грядка w×d (середина c) с землёй внутри
static func _bed(b: Bp, w: float, d: float, c := Vector3.ZERO) -> void:
	for z: float in [-d / 2.0, d / 2.0]:
		_beam(b, c + Vector3(-w / 2.0, 0.08, z), w, 0.0, 0.9)
	for x: float in [-w / 2.0, w / 2.0]:
		_beam(b, c + Vector3(x, 0.08, d / 2.0), d, PI / 2, 0.9)
	_box(b, "#dark", c, Vector3(w - 0.1, 0.1, d - 0.1), 0.0)


## Цветущий кустик — всегда один и тот же (меньше разных деталей — меньше вызовов отрисовки)
static func _bloom(b: Bp, p: Vector3, s: float) -> void:
	_add(b, BLOOMS[0], p, _yaw(b), s, {"tint": TRUE_COLOR})


## Терракотовый горшок с цветами, низ на p.y
static func _pot(b: Bp, p: Vector3, s: float) -> void:
	b.add("SM_Prop_Vase_03", p, _yaw(b), 0.7 * s)
	_bloom(b, p + Vector3(0, 0.55 * s, 0), 0.32 * s)


static func _basket(b: Bp, p: Vector3, s := 0.6) -> void:
	b.add("SM_Prop_Basket_03", p, _yaw(b), s)


static func _grass(b: Bp, p: Vector3, s := 0.5) -> void:
	b.add("SM_Env_Grass_01", p, _yaw(b), s)


static func _flowers(b: Bp, p: Vector3, s := 1.1) -> void:
	b.add("SM_Env_Flowers_02", p, _yaw(b), s)


## Вода: шестиугольник радиусом r (три коробки), верх на y
static func _water_hex(b: Bp, c: Vector3, r: float, y: float, kz := 1.0) -> void:
	for k in 3:
		var bs := Basis(Vector3.UP, k * PI / 3.0) * Basis.from_scale(Vector3(r * 2.0, 0.05, r * 1.15))
		b.parts.append(["#water", b.base * Transform3D(Basis.from_scale(Vector3(1, 1, kz)) * bs, c + Vector3(0, y - 0.025, 0)), {}])


## Огонь в чаше с дымком и светом
static func _fire_at(b: Bp, p: Vector3, spread: float, smoke := true) -> void:
	CatDecor._fire(b, p, spread, 5, spread * 1.1, spread * 0.7)
	b.light(p + Vector3(0, 0.2, 0))
	if smoke:
		b.smoke.append(p + Vector3(0, 0.15, 0))


## Животное этапа 5 (game._pets2): модель Quaternius длиной BEASTS[kind] — узел Stories.Beast (играет «Eating», «Idle»)
static func beast(kind: String) -> Stories.Beast:
	var e: Array = BEASTS.get(kind, BEASTS["donkey"])
	var bn := Stories.Beast.new()
	var m := (load(String(e[0])) as PackedScene).instantiate() as Node3D
	bn.add_child(m)
	var box := Artisau.aabb(m)
	m.scale = Vector3.ONE * float(e[1]) / maxf(0.01, maxf(box.size.x, box.size.z))
	var aps := m.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		bn.ap = aps[0]
		for an in ["Walk", "Idle", "Eating", "Gallop", "Idle_2", "Idle_Headlow"]:
			if bn.ap.has_animation(an):
				bn.ap.get_animation(an).loop_mode = Animation.LOOP_LINEAR
	return bn


# ---------- сельский двор ----------

## Грядка: дощатая с капустой и луком, бобы на колышках или тыквы у плетня
static func _veggies(b: Bp, lk: int) -> void:
	match lk:
		0:
			_bed(b, 2.1, 1.15)
			for i in 3:
				_add(b, "SM_Env_Crop_Single_02", Vector3(-0.62 + i * 0.62, 0.08, -0.24), _yaw(b), 0.42, {"tint": Color(0.9, 1.05, 0.75)})
				_add(b, "SM_Env_Crop_Single_01", Vector3(-0.62 + i * 0.62, 0.08, 0.26), _yaw(b), 0.5)
			_basket(b, Vector3(1.45, 0, 0.4), 0.6)
		1:
			_bed(b, 2.3, 0.8)
			for i in 4:
				var x := -0.84 + i * 0.56
				_pole(b, Vector3(x, 0, 0), 1.35, 0.45)
				_sx(b, "SM_Env_Ivy_Pillar_01", Vector3(x, 0.05, 0), _yaw(b), Vector3(0.3, 0.42, 0.3))
				_add(b, "SM_Env_Crop_Single_01", Vector3(x + 0.25, 0.08, 0.15), _yaw(b), 0.32)
			_basket(b, Vector3(1.55, 0, 0.35), 0.6)
		_:
			b.add("SM_Env_Fence_Woof_01", Vector3(-1.25, 0, -0.55), 0.0)
			for e: Array in [[Vector3(-0.7, 0, 0.0), 0.42], [Vector3(0.05, 0, 0.2), 0.5], [Vector3(0.75, 0, -0.1), 0.38], [Vector3(-0.2, 0, 0.55), 0.32]]:
				_add(b, "SM_Env_Crop_Single_02", e[0], _yaw(b), e[1], {"tint": PUMPKIN})
			for x: float in [-1.0, -0.3, 0.45, 1.05]:
				_add(b, "SM_Env_Crop_Single_01", Vector3(x, 0, -0.25), _yaw(b), 0.45)
			_grass(b, Vector3(1.1, 0, 0.45))
			CatDecor._ground_fp(b, 2.5, 1.3)


## Лавка у порога: деревянная лавка с корзинами и кувшином; или табурет, кувшин и корзина шерсти
static func _porch(b: Bp, lk: int) -> void:
	if lk == 0:
		b.add("SM_Prop_Bench_01", Vector3(0, 0, -0.1), 0.0, 1.0)
		_basket(b, Vector3(-0.45, 0.47, -0.1), 0.45)
		b.add("SM_Prop_Jug_02", Vector3(1.1, 0, 0.1), _yaw(b), 0.75)
		_basket(b, Vector3(-1.15, 0, 0.15), 0.65)
		_pot(b, Vector3(0.75, 0, -0.55), 0.7)
	else:
		b.add("SM_Prop_Stool_01", Vector3(-0.2, 0, 0), 0.4, 1.0)
		b.add("SM_Prop_Jug_02", Vector3(-0.2, 0.33, 0.0), 0.0, 0.55)
		b.add("SM_Prop_Basket_06", Vector3(0.55, 0, 0.1), 0.3, 0.7)
		b.add("SM_Prop_Basket_Insert_02", Vector3(0.55, 0, 0.1), 0.3, 0.7)
		_grass(b, Vector3(-0.75, 0, -0.3), 0.45)
	b.door = Vector3(0, 0, 0.8)


## Поленница: дрова пирамидой под дощатым навесом; или штабель досок, лестница и мешок
static func _woodpile(b: Bp, lk: int) -> void:
	if lk == 0:
		# поленья лежат торцами к улице (вдоль Z), пирамидой
		var rows := [4, 3, 2]
		for j in rows.size():
			var n: int = rows[j]
			for i in n:
				b.add_xf("SM_Prop_Pole_01", Transform3D(Basis(Vector3.RIGHT, -PI / 2) * Basis.from_scale(Vector3(1.6, 0.36, 1.6)), Vector3((i - (n - 1) / 2.0) * 0.38, 0.17 + j * 0.31, -0.55)))
		for x: float in [-0.9, 0.9]:
			_pole(b, Vector3(x, 0, -0.55), 1.4, 0.7)
		_sx(b, "SM_Prop_Overhang_01", Vector3(0, 1.45, -0.62), 0.0, Vector3(0.8, 1.0, 1.1))
		b.add("SM_Prop_Basket_Backpack_01", Vector3(1.2, 0, 0.25), 0.6, 0.9)
	else:
		for j in 4:
			for i in 3:
				_beam(b, Vector3(-1.0, 0.08 + j * 0.15, -0.3 + i * 0.25), 2.0, 0.0, 1.0)
		CatDecor._lean(b, "SM_Prop_Ladder_01", Vector3(0.4, 0, 0.32), 0.0, 0.32, 0.7)
		b.add("SM_Prop_Sack_04", Vector3(-1.3, 0, 0.3), _yaw(b), 0.75)


# ---------- деревья ----------

## Большое дерево: старый дуб в кругу камней, раскидистая олива или высокая пальма
static func _bigtree(b: Bp, lk: int) -> void:
	match lk:
		0:
			b.add("SM_Env_Tree_03", Vector3.ZERO, _yaw(b), 0.85)
			b.add("SM_Prop_Stone_Border_01", Vector3.ZERO, _yaw(b), 0.5)
			_bloom(b, Vector3(0.45, 0, 0.3), 0.24)
			_grass(b, Vector3(-0.4, 0, -0.2), 0.6)
		1:
			_add(b, "SM_Env_Tree_04", Vector3.ZERO, _yaw(b), 0.55, {"tint": OLIVE})
			b.add("SM_Prop_Stone_Border_01", Vector3.ZERO, _yaw(b), 0.5)
			_flowers(b, Vector3(0, 0.02, 0), 1.2)
		_:
			b.add("SM_Env_Tree_Palm_03", Vector3.ZERO, _yaw(b), 0.5)
			b.add("SM_Env_Tree_Bush_02", Vector3(0.55, 0, 0.35), _yaw(b), 0.22)
			_bloom(b, Vector3(-0.45, 0, 0.35), 0.26)
			_grass(b, Vector3(-0.3, 0, -0.45), 0.6)


# ---------- вода ----------

## Пруд: в кольце камней с кувшинками, в камышах с утками или с дощатым мостком
static func _pond(b: Bp, lk: int) -> void:
	var y := 0.13
	match lk:
		0:
			b.add("SM_Prop_Stone_Border_01", Vector3.ZERO, 0.4, 0.78)
			_water_hex(b, Vector3.ZERO, 0.95, y)
			CatDecor._lilies(b, Vector3(-0.35, y - 0.03, -0.2), 0.55)
			CatDecor._lilies(b, Vector3(0.4, y - 0.03, 0.3), 0.45)
			_bloom(b, Vector3(1.15, 0, 0.6), 0.22)
			_grass(b, Vector3(-1.1, 0, 0.7), 0.55)
		1:
			b.add("SM_Prop_Stone_Border_01", Vector3.ZERO, 1.2, 0.85)
			_water_hex(b, Vector3.ZERO, 1.05, y)
			b.add("#duck", Vector3(-0.3, y, 0.15), 0.8, 1.0)
			b.add("#duck_f", Vector3(0.35, y, -0.2), 2.3, 0.9)
			for e: Array in [[Vector3(-1.25, 0, -0.5), 0.75], [Vector3(1.15, 0, -0.75), 0.7], [Vector3(-0.9, 0, 1.0), 0.6], [Vector3(1.25, 0, 0.6), 0.55]]:
				b.add("SM_Env_Grass_03", e[0], _yaw(b), e[1])
			CatDecor._lilies(b, Vector3(0.45, y - 0.03, 0.45), 0.45)
		_:
			_sx(b, "SM_Prop_Stone_Border_01", Vector3.ZERO, 0.0, Vector3(1.05, 0.8, 0.72))
			_water_hex(b, Vector3.ZERO, 1.25, y, 0.68)
			# мосток поперёк пруда: два бруса от берега к берегу, на них доски
			for x: float in [-0.28, 0.28]:
				_beam(b, Vector3(x, 0.26, 1.15), 2.3, PI / 2, 0.8)
			for i in 12:
				_beam(b, Vector3(-0.36, 0.36, 1.05 - i * 0.19), 0.72, 0.0, 0.8)
			b.add("SM_Env_Pebbles_01", Vector3(1.3, 0, 0.55), _yaw(b), 0.6)
			CatDecor._lilies(b, Vector3(-0.85, y - 0.03, 0.1), 0.45)
			_bloom(b, Vector3(-1.4, 0, -0.55), 0.22)
	CatDecor._ground_fp(b, 2.3, 2.0)
	b.door = Vector3(0, 0, 1.3)


## Поилка: каменное корыто с вёдрами или дощатое корыто с охапкой сена
static func _trough(b: Bp, lk: int) -> void:
	if lk == 0:
		var sx := 0.6
		var sz := 0.62
		_sx(b, "SM_Bld_Floor_Trim_02", Vector3(-1.25 * sx, 0, -0.515 * sz), 0.0, Vector3(sx, 0.9, sz))
		b.parts.append(["#water", b.base * Transform3D(Basis.from_scale(Vector3(2.5 * sx - 0.26, 0.06, 1.03 * sz - 0.22)), Vector3(0, 0.36, 0)), {}])
		b.add("SM_Prop_Jug_03", Vector3(1.05, 0, 0.25), _yaw(b), 0.8)
		b.add("SM_Prop_Jug_02", Vector3(-1.05, 0, 0.2), _yaw(b), 0.75)
		_grass(b, Vector3(0.5, 0, 0.55), 0.5)
		CatDecor._ground_fp(b, 1.6, 0.7)
	else:
		for z: float in [-0.28, 0.28]:
			for j in 2:
				_beam(b, Vector3(-0.85, 0.08 + j * 0.15, z), 1.7, 0.0, 1.0)
		for x: float in [-0.85, 0.85]:
			for j in 2:
				_beam(b, Vector3(x, 0.08 + j * 0.15, 0.28), 0.56, PI / 2, 1.0)
		b.parts.append(["#water", b.base * Transform3D(Basis.from_scale(Vector3(1.55, 0.05, 0.42)), Vector3(0, 0.26, 0)), {}])
		b.add("SM_Prop_Straw_Stack_01", Vector3(1.35, 0, -0.35), _yaw(b), 0.28)
		CatDecor._lean(b, "SM_Prop_Straw_Bundle_01", Vector3(-1.25, 0, 0.1), _yaw(b), 0.15, 0.45)
		CatDecor._ground_fp(b, 1.8, 0.7)


## Чаша для птиц на каменном столбике; или родник: струя из маски на камне в низкую чашу
static func _basin(b: Bp, lk: int) -> void:
	if lk == 0:
		b.add("SM_Prop_Plinth_02", Vector3.ZERO, 0.0, 0.85)
		var top := 1.01 * 0.85
		b.add("SM_Prop_Bowl_01", Vector3(0, top, 0), 0.0, 0.62)
		b.parts.append(["#water", b.base * Transform3D(Basis(Vector3.UP, PI / 4).scaled(Vector3(0.42, 0.03, 0.42)), Vector3(0, top + 0.1, 0)), {}])
		b.parts.append(["#water", b.base * Transform3D(Basis.from_scale(Vector3(0.42, 0.03, 0.42)), Vector3(0, top + 0.1, 0)), {}])
		for k in 3:
			var a := k * TAU / 3.0 + 0.4
			_bloom(b, Vector3(cos(a) * 0.45, 0, sin(a) * 0.45), 0.2)
	else:
		_sx(b, "SM_Prop_Marble_Block_02", Vector3(0, 0, -0.3), 0.0, Vector3(1.05, 1.15, 0.45))
		b.add("SM_Prop_Fountain_01", Vector3(0, 0.0, -0.05), 0.0, 1.0)
		b.parts.append(["#water", b.base * Transform3D(Basis.from_scale(Vector3(0.04, 0.32, 0.04)), Vector3(0, 0.42, 0.14)), {}])
		b.add("SM_Env_Pebbles_01", Vector3(0.75, 0, 0.35), _yaw(b), 0.5)
		_grass(b, Vector3(-0.7, 0, 0.25), 0.55)
		_bloom(b, Vector3(0.65, 0, -0.2), 0.2)
	b.door = Vector3(0, 0, 1.0)


# ---------- скотный двор (животных ставит game._pets2 по PETS) ----------

## Корова: лужок с цветами или ясли с сеном за плетнём
static func _cow(b: Bp, lk: int) -> void:
	_grass(b, Vector3(-0.9, 0, -0.6), 0.75)
	_flowers(b, Vector3(0.6, 0, -0.5), 1.3)
	if lk == 0:
		_flowers(b, Vector3(-0.5, 0, 0.7), 1.2)
		b.add("SM_Env_Grass_03", Vector3(1.05, 0, 0.6), _yaw(b), 0.7)
		b.add("SM_Prop_Straw_Stack_01", Vector3(-1.05, 0, 0.75), _yaw(b), 0.25)
	else:
		b.add("SM_Env_Fence_Woof_01", Vector3(-1.25, 0, -0.8), 0.0)
		_manger_box(b, Vector3(0, 0, -0.45), 1.4)
	CatDecor._ground_fp(b, 2.4, 2.0)
	b.door = Vector3(0, 0, 1.3)


## Лошадь: у коновязи с поилкой или под дощатым навесом
static func _horse(b: Bp, lk: int) -> void:
	if lk == 0:
		for x: float in [-1.05, 1.05]:
			_sx(b, "SM_Prop_Pole_01", Vector3(x, 0, -0.25), 0.0, Vector3(1.0, 0.4, 1.0))
		_beam(b, Vector3(-1.15, 1.02, -0.25), 2.3, 0.0, 0.5)
		var sx := 0.36
		_sx(b, "SM_Bld_Floor_Trim_02", Vector3(0.55 - 1.25 * sx, 0, -0.85), 0.0, Vector3(sx, 0.55, 0.3))
		b.parts.append(["#water", b.base * Transform3D(Basis.from_scale(Vector3(0.7, 0.04, 0.16)), Vector3(0.55, 0.2, -0.7)), {}])
		b.add("SM_Prop_Straw_Stack_02", Vector3(-0.8, 0, -0.85), _yaw(b), 0.25)
	else:
		for x: float in [-1.15, 1.15]:
			for z: float in [-0.9, 0.3]:
				_pole(b, Vector3(x, 0, z), 2.0 if z < 0.0 else 1.75, 0.9)
		_sx(b, "SM_Prop_Overhang_01", Vector3(0, 2.0, -1.05), 0.0, Vector3(0.95, 1.0, 1.85))
		b.add("SM_Prop_Straw_Stack_01", Vector3(-0.8, 0, -0.65), _yaw(b), 0.3)
		CatDecor._lean(b, "SM_Prop_Straw_Bundle_01", Vector3(0.95, 0, -0.65), _yaw(b), 0.15, 0.45)
	_grass(b, Vector3(1.2, 0, 0.75), 0.55)
	CatDecor._ground_fp(b, 2.6, 2.0)
	b.door = Vector3(0, 0, 1.3)


## Деревянные ясли (наклонная решётка из брусьев) с сеном
static func _manger_box(b: Bp, c: Vector3, w: float) -> void:
	for x: float in [-w / 2.0, w / 2.0]:
		_sx(b, "SM_Prop_Pole_01", c + Vector3(x, 0, 0), 0.0, Vector3(0.8, 0.27, 0.8))
	for k in 2:
		_beam(b, c + Vector3(-w / 2.0, 0.35 + k * 0.4, 0.12 * k), w, 0.0, 0.7)
	b.add("SM_Prop_Straw_Bundle_01", c + Vector3(-0.25, 0.3, 0.0), PI / 2, 0.42)
	b.add("SM_Prop_Straw_Bundle_01", c + Vector3(0.25, 0.3, 0.05), PI / 2 + 0.3, 0.4)


## Ясли с сеном и мешки; или плуг, серп и мешки у копны
static func _manger(b: Bp, lk: int) -> void:
	if lk == 0:
		_manger_box(b, Vector3(0, 0, -0.1), 1.6)
		b.add("SM_Prop_Sack_Stack_01", Vector3(1.35, 0, 0.2), 0.3, 0.45)
		b.add("SM_Prop_Basket_Backpack_01", Vector3(-1.2, 0, 0.3), 0.5, 0.9)
	else:
		b.add("SM_Prop_Straw_Stack_01", Vector3(-0.6, 0, -0.35), _yaw(b), 0.4)
		b.add("SM_Prop_Plough_01", Vector3(0.65, 0, -0.2), 1.3, 0.85)
		b.add("SM_Prop_Sack_Stack_02", Vector3(0.6, 0, 0.6), 0.2, 0.42)
		b.add_xf("SM_Prop_Sickle_01", Transform3D(Basis(Vector3.UP, 0.6) * Basis(Vector3.BACK, 1.45), Vector3(-0.1, 0.03, 0.55)))
		b.add("SM_Prop_Sack_04", Vector3(-1.25, 0, 0.45), _yaw(b), 0.7)


# ---------- ремесло ----------

## Кузнечный уголок: наковальня, точило, молот и жаровенка с углями; или каменный горн с огнём и наковальня
static func _forge_corner(b: Bp, lk: int) -> void:
	if lk == 0:
		b.add("SM_Prop_Anvil_01", Vector3(-0.35, 0, 0), 0.4, 0.85)
		b.add_xf("SM_Prop_Tool_Hammer_01", Transform3D(Basis(Vector3.UP, 0.8), Vector3(-0.35, 0.74, 0.0)))
		b.add("SM_Prop_Grinding_Wheel_01", Vector3(0.75, 0.3, -0.25), 1.2, 0.85)
		b.add("SM_Prop_Brazier_03", Vector3(0.65, 0, 0.6), 0.0, 0.55)
		b.add("SM_Prop_Brazier_03_Insert_01", Vector3(0.65, 0, 0.6), 0.0, 0.55)
		CatDecor._fire(b, Vector3(0.65, 0.5, 0.6), 0.05, 4, 0.06, 0.04)
		b.add("SM_Prop_Jug_03", Vector3(-1.05, 0, 0.35), _yaw(b), 0.7)
	else:
		var s := 0.55
		b.add("SM_Prop_Forge_01", Vector3(-0.3, 0, -0.35), 0.0, s)
		_fire_at(b, Vector3(-0.3, 0.42, 0.05), 0.08)
		b.add("SM_Prop_Anvil_01", Vector3(0.75, 0, 0.35), -0.5, 0.85)
		b.add_xf("SM_Prop_Tool_Hammer_01", Transform3D(Basis(Vector3.UP, -0.3), Vector3(0.75, 0.74, 0.35)))
		b.add("SM_Prop_Sack_04", Vector3(0.9, 0, -0.55), _yaw(b), 0.6)


## Ткацкий станок с шерстью и рулонами; или крашеные ткани сохнут на жердях
static func _loom(b: Bp, lk: int) -> void:
	if lk == 0:
		b.add("SM_Prop_Loom_01", Vector3(-0.25, 0, -0.2), 0.0, 0.9)
		b.add("SM_Prop_Rug_Stack_01", Vector3(0.95, 0, -0.15), 0.4, 0.75)
		b.add("SM_Prop_Basket_06", Vector3(0.7, 0, 0.55), 0.0, 0.6)
		b.add("SM_Prop_Basket_Insert_02", Vector3(0.7, 0, 0.55), 0.0, 0.6)
		b.add("SM_Prop_Stool_01", Vector3(-0.25, 0, 0.45), 0.2, 0.95)
	else:
		for x: float in [-1.2, 1.2]:
			_pole(b, Vector3(x, 0, 0), 2.1, 0.8)
		_beam(b, Vector3(-1.3, 2.05, 0), 2.6, 0.0, 0.6)
		CatShops._sheet(b, Vector3(-0.6, 2.0, 0.02), 0.95, 1.3, CatShops.RED)
		CatShops._sheet(b, Vector3(0.0, 2.0, -0.02), 0.6, 1.5, CatShops.MUSTARD)
		CatShops._sheet(b, Vector3(0.6, 2.0, 0.02), 0.95, 1.2, CatShops.BLUE)
		CatShops._vat(b, Vector3(0.0, 0, 0.75), CatShops.SKY, 0.8)
		_basket(b, Vector3(-1.0, 0, 0.6), 0.55)


## Печь гончара: купол печи с огнём и свежие амфоры; или стол с мисками и кувшинами
static func _kiln(b: Bp, lk: int) -> void:
	if lk == 0:
		b.add("SM_Prop_Kiln_01", Vector3(-0.35, 0, -0.25), 0.0, 0.6)
		CatDecor._fire(b, Vector3(-0.35, 0.16, 0.3), 0.07, 4, 0.06, 0.045)
		b.add("SM_Prop_Vase_Pile_02", Vector3(0.85, 0, -0.1), _yaw(b), 0.65)
		b.add("SM_Prop_Jar_01", Vector3(0.75, 0, 0.6), _yaw(b), 0.7)
		b.add("SM_Prop_Vase_02", Vector3(-1.15, 0, 0.45), _yaw(b), 0.6)
	else:
		b.add("SM_Prop_Table_01", Vector3(0, 0, -0.1), 0.0, 0.9)
		var top := 0.78 * 0.9
		b.add("SM_Prop_Bowl_04", Vector3(-0.5, top, -0.1), 0.0, 0.6)
		b.add("SM_Prop_Jug_02", Vector3(-0.1, top, -0.15), 0.0, 0.5)
		b.add("SM_Prop_Vase_06", Vector3(0.35, top, -0.05), 0.0, 0.42)
		b.add("SM_Prop_Bowl_06", Vector3(0.62, top, -0.2), 0.0, 0.5)
		b.add("SM_Prop_Seat_Stool_01", Vector3(0.0, 0, 0.55), 0.0, 0.9)
		b.add("SM_Prop_Vase_Pile_02", Vector3(1.2, 0, 0.2), _yaw(b), 0.55)


## Мраморные глыбы с резцом и молотком; или штабель плит с лестницей
static func _marble_yard(b: Bp, lk: int) -> void:
	if lk == 0:
		b.add("SM_Prop_Marble_Block_01", Vector3(-0.3, 0, -0.2), 0.15, 0.75)
		b.add("SM_Prop_Marble_Block_02", Vector3(0.9, 0, 0.1), -0.3, 0.7)
		b.add("SM_Prop_Marble_Block_03", Vector3(-0.35, 0.8, -0.2), 0.4, 0.55)
		b.add_xf("SM_Prop_Tool_Chisel_01", Transform3D(Basis(Vector3.UP, 0.7), Vector3(0.9, 0.77, 0.1)))
		b.add_xf("SM_Prop_Tool_Hammer_01", Transform3D(Basis(Vector3.UP, -0.4), Vector3(0.75, 0.77, 0.25)))
		b.add("SM_Prop_Marble_Rubble_07", Vector3(0.2, 0, 0.6), _yaw(b), 0.6)
	else:
		b.add("SM_Prop_Marble_Stack_01", Vector3(0, 0, -0.2), 0.0, 0.5)
		CatDecor._lean(b, "SM_Prop_Ladder_01", Vector3(0.75, 0, 0.18), 0.0, 0.3, 0.55)
		b.add("SM_Prop_Marble_Rubble_04", Vector3(-0.6, 0, 0.45), _yaw(b), 0.5)
	b.door = Vector3(0, 0, 1.1)


# ---------- рынок ----------

## Навес с фруктами, с тканями или с посудой
static func _awning(b: Bp, lk: int) -> void:
	var c: int = [CatShops.RED, CatShops.BLUE, CatShops.GREEN][lk % 3]
	if lk == 1:
		for x: float in [-1.1, 1.1]:
			_pole(b, Vector3(x, 0, -0.2), 1.9, 0.8)
		_beam(b, Vector3(-1.2, 1.85, -0.2), 2.4, 0.0, 0.6)
		b.add("SM_Prop_Rug_Drape_01", Vector3(-0.5, 1.82, -0.15), 0.0, 0.85)
		b.add("SM_Prop_Rug_Drape_01", Vector3(0.45, 1.82, -0.15), 0.0, 0.8)
		b.add("SM_Prop_Rug_Stack_02" if Synty.has("SM_Prop_Rug_Stack_02") else "SM_Prop_Rug_Stack_01", Vector3(-0.6, 0, 0.45), 0.3, 0.7)
		b.add("SM_Prop_Rug_Folded_01", Vector3(0.6, 0, 0.5), 0.2, 0.7)
		b.door = Vector3(0, 0, 1.2)
		return
	for x: float in [-1.15, 1.15]:
		CatShops._pole(b, Vector3(x, 0, -0.75), 2.3)
		CatShops._pole(b, Vector3(x, 0, 0.75), 2.0)
	CatShops._awning(b, -1.25, 1.25, -0.85, 0.85, 2.35, 1.95, c, CatShops.WHITE)
	if lk == 0:
		b.add("SM_Prop_Table_01", Vector3(0, 0, -0.15), 0.0, 1.0)
		CatShops._basket(b, Vector3(-0.5, 0.78, -0.15), "apples", 0.5)
		CatShops._basket(b, Vector3(0.05, 0.78, -0.12), "oranges", 0.5, 0.4)
		CatShops._basket(b, Vector3(0.55, 0.78, -0.18), "apples", 0.5, 1.0)
	else:
		b.add("SM_Prop_Shelf_01", Vector3(0, 0, -0.4), 0.0, 0.75)
		for e: Array in [["SM_Prop_Vase_01", Vector3(-0.6, 0.66, -0.4), 0.42], ["SM_Prop_Jug_02", Vector3(-0.15, 0.66, -0.4), 0.45],
				["SM_Prop_Vase_01", Vector3(0.35, 0.66, -0.4), 0.42], ["SM_Prop_Jug_02", Vector3(0.65, 0.66, -0.4), 0.45],
				["SM_Prop_Jug_02", Vector3(-0.45, 1.12, -0.4), 0.4], ["SM_Prop_Vase_01", Vector3(0.2, 1.12, -0.4), 0.38]]:
			b.add(e[0], e[1], 0.0, e[2])
		b.add("SM_Prop_Vase_Pile_02", Vector3(0.8, 0, 0.45), _yaw(b), 0.5)
	b.door = Vector3(0, 0, 1.2)


## Ковры на продажу; или гора подушек на ковре
static func _rugs(b: Bp, lk: int) -> void:
	if lk == 0:
		b.add("SM_Prop_Rug_Preset_01", Vector3(-0.15, 0, 0), 0.3, 0.7)
		b.add("SM_Prop_Rug_Stack_01", Vector3(1.05, 0, -0.3), 0.2, 0.7)
		b.add("SM_Prop_Rug_Folded_01", Vector3(1.1, 0, 0.45), 0.6, 0.7)
	else:
		CatShops._put(b, "SM_Prop_Rug_02", Vector3(0, 0.01, 0), PI / 2, 0.75, CatShops._rug("03_B"))
		b.add("SM_Prop_Pillow_Pile_01", Vector3(-0.25, 0.02, -0.1), 0.2, 0.7)
		b.add("SM_Prop_Pillow_Pile_02", Vector3(0.55, 0.02, 0.2), -0.4, 0.6)
		_basket(b, Vector3(-1.05, 0, 0.45), 0.55)
	CatDecor._ground_fp(b, 2.2, 1.6)


## Тачка торговца с корзинами овощей или с амфорами
static func _handcart(b: Bp, lk: int) -> void:
	b.add("SM_Prop_Cart_02", Vector3(0, 0.0, 0), PI / 2, 0.8)
	if lk == 0:
		CatShops._basket(b, Vector3(-0.15, 0.74, 0.0), "greens", 0.42)
		CatShops._basket(b, Vector3(0.35, 0.74, 0.05), "beets", 0.42, 0.5)
		_basket(b, Vector3(0.0, 0, 0.75), 0.55)
	else:
		b.add_xf("SM_Prop_Vase_02", Transform3D(Basis(Vector3.BACK, 1.2) * Basis.from_scale(Vector3.ONE * 0.6), Vector3(-0.1, 0.8, 0.0)))
		b.add_xf("SM_Prop_Vase_01", Transform3D(Basis(Vector3.BACK, 1.25) * Basis.from_scale(Vector3.ONE * 0.6), Vector3(0.3, 0.83, 0.12)))
		b.add("SM_Prop_Sack_04", Vector3(0.6, 0, 0.7), _yaw(b), 0.7)
	b.door = Vector3(0, 0, 1.1)


## Лоток букиниста: стол со свитками, полка, табурет, корзина
static func _scrolls(b: Bp) -> void:
	_sx(b, "SM_Prop_Table_08", Vector3(0, 0, 0.0), 0.0, Vector3(0.7, 0.95, 0.7))
	var top := 0.78 * 0.95
	b.add("SM_Prop_Scroll_Pile_02", Vector3(-0.5, top, 0.0), 0.2, 0.6)
	b.add("SM_Prop_Scroll_Pile_02", Vector3(0.05, top, 0.0), -0.3, 0.6)
	b.add("SM_Prop_Scroll_01", Vector3(0.5, top + 0.05, 0.05), 1.3, 0.9)
	b.add("SM_Prop_Shelf_Scroll_01", Vector3(0, 0, -0.75), 0.0, 0.55)
	b.add("SM_Prop_Shelf_Scroll_01_Insert_01", Vector3(0, 0, -0.75), 0.0, 0.55)
	b.add("SM_Prop_Seat_Stool_01", Vector3(1.15, 0, -0.2), 0.0, 0.85)
	b.add("SM_Prop_Basket_06", Vector3(-1.2, 0, 0.35), 0.0, 0.6)
	b.add("SM_Prop_Scroll_Pile_02", Vector3(-1.2, 0.35, 0.35), 0.0, 0.6)
	b.door = Vector3(0, 0, 1.0)


# ---------- сад ----------

## Стриженый самшит-шар (свой Kit) поперечником d, низ на p.y
static func _ball(b: Bp, p: Vector3, d: float) -> void:
	b.add("#d2_ball", p, _yaw(b), d)


## Самшит: шар в мраморной кадке, конус в кругу цветов или три шара на плитах
static func _topiary(b: Bp, lk: int) -> void:
	match lk:
		0:
			b.add("SM_Prop_Plinth_04", Vector3.ZERO, 0.0, 0.85)
			_ball(b, Vector3(0, 0.55, 0), 0.95)
			_bloom(b, Vector3(0.55, 0, 0.45), 0.2)
		1:
			b.add("SM_Prop_Stone_Border_01", Vector3.ZERO, _yaw(b), 0.36)
			_flowers(b, Vector3(0, 0.02, 0), 0.9)
			b.add("SM_Prop_Vase_03", Vector3.ZERO, 0.0, 0.75)
			b.add("#d2_cone", Vector3(0, 0.6, 0), _yaw(b), 1.0)
		_:
			CatDecor._slab(b, Vector3.ZERO, Vector3(2.3, 0.08, 1.0))
			_ball(b, Vector3(-0.7, 0.08, 0), 0.7)
			_ball(b, Vector3(0.0, 0.08, 0), 0.95)
			_ball(b, Vector3(0.72, 0.08, 0), 0.7)
	b.door = Vector3(0, 0, 0.9)


## Шпалера: решётка с виноградной лозой; или низкая решётка в розах с вазонами
static func _trellis(b: Bp, lk: int) -> void:
	if lk == 0:
		var s := 0.75
		b.add("SM_Bld_Trellis_01", Vector3(1.25 * s, 0, 0), 0.0, s)
		for v: Array in [[Vector3(-0.45, 0.85, 0.08), 0.5], [Vector3(0.45, 1.35, 0.08), 0.45]]:
			b.add("SM_Env_Vine_01", v[0], 0.0, v[1])
		CatShops._vine_flat(b, Vector3(0.2, 1.9, 0.12), 0.0, b.rng.randi(), 0.45)
		_bloom(b, Vector3(-0.6, 0, 0.3), 0.22)
		_grass(b, Vector3(0.65, 0, 0.3), 0.45)
	else:
		b.add("SM_Bld_Trellis_02", Vector3(1.25, 0, 0), 0.0, 1.0)
		b.add("SM_Env_Ivy_Flowers_02", Vector3(-0.3, 0.45, 0.08), 0.0, 0.6)
		b.add("SM_Env_Ivy_Draped_Flowers_02", Vector3(0.0, 0.92, 0.04), 0.0, 0.6)
		for x: float in [-1.5, 1.5]:
			_pot(b, Vector3(x, 0, 0.3), 0.8)
	b.door = Vector3(0, 0, 0.9)


## Партер: четыре цветника вокруг вазы на гравии; или квадраты самшита вокруг чаши с водой
static func _parterre(b: Bp, lk: int) -> void:
	_box(b, "#marble", Vector3(0, -0.02, 0), Vector3(3.0, 0.06, 3.0), 0.0, {})
	if lk == 0:
		for k in 4:
			var a := k * PI / 2.0
			var c := Vector3(cos(a), 0, sin(a)) * 0.95
			b.add("SM_Prop_FlowerBed_01", c + Vector3(0, 0.33 * 0.6, 0), a + PI / 2, 0.6)
		b.add("SM_Prop_Plinth_04", Vector3.ZERO, 0.0, 0.7)
		b.add("SM_Prop_Vase_03", Vector3(0, 0.47, 0), 0.0, 0.7)
		_bloom(b, Vector3(0, 0.47 + 0.6, 0), 0.25)
	else:
		for k in 4:
			var a := k * PI / 2.0 + PI / 4.0
			var c := Vector3(cos(a), 0, sin(a)) * 1.0
			_sx(b, "SM_Env_Bush_Cluster_01", c + Vector3(0, 0.25, 0), a, Vector3(0.07, 0.11, 0.07), {"tint": HEDGE})
		b.add("SM_Prop_Bowl_01", Vector3(0, 0.0, 0), 0.0, 0.85)
		CatDecor._sx(b, "SM_Prop_Plinth_03", Vector3(0, 0, 0), 0.0, Vector3(1.0, 1.0, 1.0))
		_water_hex(b, Vector3.ZERO, 0.38, 0.2)
		b.add("SM_Prop_Fountain_03", Vector3(0, 0.55, 0), 0.0, 0.6)
	b.door = Vector3(0, 0, 1.8)


# ---------- статуи и руины ----------

## Руины: обломок колонны в плюще и обломках; или разбитая статуя в траве
static func _ruins(b: Bp, lk: int) -> void:
	if lk == 0:
		# обломок колонны на базе, верх отбит; капитель упала рядом
		b.add("SM_Prop_Pillar_Base_02", Vector3(0, 0, -0.2), 0.0, 0.62)
		_sx(b, "SM_Bld_Pillar_02", Vector3(0, 0.93, -0.2), 0.0, Vector3(0.62, 0.42, 0.62), CatMonuments.CAP_MARBLE)
		_sx(b, "SM_Env_Ivy_Pillar_01", Vector3(0, 0.9, -0.2), _yaw(b), Vector3(0.66, 0.5, 0.66))
		b.add_xf("SM_Prop_Pillar_Top_01", Transform3D(Basis(Vector3.UP, 0.7) * Basis(Vector3.BACK, 1.3) * Basis.from_scale(Vector3.ONE * 0.62), Vector3(-0.55, 0.3, 0.45)))
		b.add("SM_Prop_Marble_Rubble_04", Vector3(0.65, 0, 0.45), _yaw(b), 0.55)
		b.add("SM_Prop_Marble_Rubble_07", Vector3(-0.75, 0, 0.35), _yaw(b), 0.7)
		_grass(b, Vector3(-0.6, 0, -0.6), 0.6)
		_bloom(b, Vector3(0.6, 0, -0.55), 0.2)
	else:
		b.add("SM_Prop_Plinth_04", Vector3(-0.5, 0, -0.35), 0.0, 0.85)
		b.add("SM_Prop_Statue_Broken_04", Vector3(-0.5, 0.58, -0.35), 0.3, 0.75)
		b.add("SM_Prop_Statue_Broken_03", Vector3(0.45, 0, 0.1), 2.2, 0.9)
		b.add("SM_Prop_Statue_Broken_05", Vector3(-0.35, 0, 0.55), 0.9, 0.85)
		b.add("SM_Prop_Marble_Rubble_07", Vector3(0.75, 0, -0.55), _yaw(b), 0.6)
		_grass(b, Vector3(1.0, 0, 0.55), 0.55)
		_flowers(b, Vector3(0, 0, 0), 1.3)
	CatDecor._ground_fp(b, 2.0, 1.7)
	b.door = Vector3(0, 0, 1.2)


## Алтарь: мраморный с огнём в бронзовой чаше; или с дарами — чаши, фрукты, курильница
static func _altar(b: Bp, lk: int) -> void:
	CatDecor._slab(b, Vector3.ZERO, Vector3(1.6, 0.1, 1.3))
	_sx(b, "SM_Prop_Marble_Block_02", Vector3(0, 0.1, -0.05), 0.0, Vector3(0.95, 0.82, 0.72))
	var top := 0.1 + 1.07 * 0.82
	b.add("SM_Bld_Ornament_04", Vector3(0, 0.55, 0.36), 0.0, 0.45)
	if lk == 0:
		b.add("SM_Prop_Brazier_04", Vector3(0, top, -0.05), 0.0, 0.5)
		b.add("SM_Prop_Brazier_04_Insert_01", Vector3(0, top, -0.05), 0.0, 0.5)
		_fire_at(b, Vector3(0, top + 0.24, -0.05), 0.11)
		for x: float in [-0.68, 0.68]:
			b.add("SM_Prop_Vase_04", Vector3(x, 0.1, 0.42), _yaw(b), 0.45)
			_bloom(b, Vector3(x, 0.34, 0.42), 0.13)
	else:
		b.add("SM_Prop_Bowl_04", Vector3(-0.25, top, -0.05), 0.0, 0.55)
		CatShops._basket(b, Vector3(0.2, top, -0.25), "grapes" if b.chance(0.5) else "apples", 0.35)
		b.add("SM_Prop_Senser_02", Vector3(0.75, 0.1, 0.3), 0.0, 1.0)
		CatDecor._fire(b, Vector3(0.75, 0.82, 0.3), 0.04, 3, 0.05, 0.035)
		b.smoke.append(Vector3(0.75, 0.9, 0.3))
		_bloom(b, Vector3(-0.7, 0.1, 0.4), 0.2)
	b.door = Vector3(0, 0, 1.1)


## Монументальная ваза на постаменте; или пара высоких амфор на мраморной ступени
static func _bigvase(b: Bp, lk: int) -> void:
	if lk == 0:
		CatDecor._slab(b, Vector3.ZERO, Vector3(1.1, 0.1, 1.1))
		b.add("SM_Prop_Plinth_04", Vector3(0, 0.1, 0), 0.0, 1.0)
		b.add("SM_Prop_Vase_05", Vector3(0, 0.78, 0), 0.0, 1.25)
		_bloom(b, Vector3(0, 0.78 + 1.2, 0), 0.24)
		_bloom(b, Vector3(0.62, 0, 0.55), 0.18)
	else:
		CatDecor._slab(b, Vector3.ZERO, Vector3(2.0, 0.14, 0.9))
		for x: float in [-0.55, 0.55]:
			b.add("SM_Prop_Vase_01" if x < 0.0 else "SM_Prop_Vase_02", Vector3(x, 0.14, 0), 0.4, 1.35)
		_bloom(b, Vector3(0, 0.14, 0.15), 0.22)
	b.door = Vector3(0, 0, 1.0)


## Статуя в работе: глыба с проступающей фигурой в лесах, лестница, резцы и обломки
static func _unfinished(b: Bp) -> void:
	b.add("SM_Prop_Statue_Unfinished_01", Vector3(0, 0, -0.3), 0.0, 0.85)
	for x: float in [-0.75, 0.75]:
		_pole(b, Vector3(x, 0, -0.75), 2.2, 0.7)
	_beam(b, Vector3(-0.85, 2.1, -0.75), 1.7, 0.0, 0.6)
	_beam(b, Vector3(-0.85, 1.1, -0.75), 1.7, 0.0, 0.6)
	CatDecor._lean(b, "SM_Prop_Ladder_01", Vector3(0.95, 0, -0.35), -0.4, 0.28, 0.65)
	b.add("SM_Prop_Marble_Block_03", Vector3(-0.9, 0, 0.35), 0.4, 0.5)
	b.add_xf("SM_Prop_Tool_Chisel_01", Transform3D(Basis(Vector3.UP, 0.7), Vector3(-0.9, 0.46, 0.35)))
	b.add_xf("SM_Prop_Tool_Compass_01", Transform3D(Basis(Vector3.UP, -0.5), Vector3(-0.85, 0.46, 0.2)))
	b.add("SM_Prop_Marble_Rubble_07", Vector3(0.45, 0, 0.45), _yaw(b), 0.5)
	b.door = Vector3(0, 0, 1.1)


# ---------- ночные огни ----------

## Факел на шесте (основание p): тёмный шест, наверху смоляной факел с огнём
static func _torch_on_pole(b: Bp, p: Vector3) -> void:
	b.add("SM_Prop_Plinth_03", p, 0.0, 0.55)
	_sx(b, "SM_Prop_Pole_02", p + Vector3(0, 0.08, 0), 0.0, Vector3(0.75, 0.8, 0.75), {"tint": CatDecor.BRONZE})
	var top := p + Vector3(0, 0.08 + 2.4, 0)
	b.add("SM_Prop_Torch_03", top + Vector3(0, 0.12, 0), 0.0, 1.5)
	CatDecor._flame(b, top + Vector3(0, 0.42, 0), 0.11)
	b.light(top + Vector3(0, 0.6, 0))


static func _torchpost(b: Bp, lk: int) -> void:
	if lk == 0:
		_torch_on_pole(b, Vector3.ZERO)
		_grass(b, Vector3(0.3, 0, 0.2), 0.45)
	else:
		for x: float in [-1.0, 1.0]:
			_torch_on_pole(b, Vector3(x, 0, 0))
			_pot(b, Vector3(x * 1.45, 0, 0.25), 0.65)
		CatShops._put(b, "SM_Prop_Rug_02", Vector3(0, 0.01, 0.2), PI / 2, 0.55, CatShops._rug("01_B"))
	b.door = Vector3(0, 0, 0.9)


## Курильница: бронзовая на треноге с тлеющими углями и дымком; или на мраморной колонне в цветах
static func _incense(b: Bp, lk: int) -> void:
	if lk == 0:
		b.add("SM_Prop_Plinth_03", Vector3.ZERO, 0.0, 0.8)
		b.add("SM_Prop_Senser_02", Vector3(0, 0.12, 0), 0.0, 1.45)
		CatDecor._fire(b, Vector3(0, 0.12 + 0.8 * 1.45 - 0.08, 0), 0.06, 4, 0.06, 0.04)
		b.light(Vector3(0, 1.4, 0))
		b.smoke.append(Vector3(0, 1.35, 0))
		_flowers(b, Vector3(0.3, 0, 0.3), 0.8)
	else:
		b.add("SM_Prop_Pillar_Base_02", Vector3.ZERO, 0.0, 0.72)
		var top := 1.5 * 0.72
		b.add("SM_Prop_Senser_04", Vector3(0, top, 0), 0.0, 1.3)
		CatDecor._fire(b, Vector3(0, top + 0.55, 0), 0.07, 4, 0.06, 0.045)
		b.light(Vector3(0, top + 0.75, 0))
		b.smoke.append(Vector3(0, top + 0.7, 0))
		for k in 3:
			var a := k * TAU / 3.0 + 0.3
			_bloom(b, Vector3(cos(a) * 0.55, 0, sin(a) * 0.55), 0.2)
	b.door = Vector3(0, 0, 0.9)


## Подвесной фонарь (бронзовая лампа на цепочке, как Senser_03) под точкой p
static func _hang_lamp(b: Bp, p: Vector3, lit: bool) -> void:
	b.add("SM_Prop_Senser_03", p - Vector3(0, 1.25 * 0.5, 0), 0.0, 0.5)
	if lit:
		b.light(p - Vector3(0, 0.55, 0))


## Гирлянда фонарей между столбами; или садовая арка в плюще с фонарями
static func _lanterns(b: Bp, lk: int) -> void:
	if lk == 0:
		for x: float in [-1.3, 1.3]:
			b.add("SM_Prop_Plinth_03", Vector3(x, 0, 0), 0.0, 0.5)
			_pole(b, Vector3(x, 0.07, 0), 2.6, 0.8, "SM_Prop_Pole_02")
		_beam(b, Vector3(-1.4, 2.62, 0), 2.8, 0.0, 0.55)
		for k in 3:
			_hang_lamp(b, Vector3(-0.85 + k * 0.85, 2.6, 0), k != 1)
		_bloom(b, Vector3(-1.3, 0, 0.35), 0.18)
	else:
		var h := 3.13 * 0.75
		for sx: float in [-1.0, 1.0]:
			b.add("SM_Bld_Trellis_Pillar_01", Vector3(sx * 0.95, 0, 0), 0.0, 0.75)
			b.add("SM_Env_Ivy_Pillar_01", Vector3(sx * 0.95, 0, 0.02), _yaw(b), 0.85)
		b.add("SM_Bld_Trellis_Roof_End_01", Vector3(-1.25, h - 0.08, 0), PI / 2, 1.0)
		b.add("SM_Env_Ivy_Draped_02", Vector3(0, h + 0.2, 0.06), 0.0, 0.66)
		for x: float in [-0.5, 0.5]:
			_hang_lamp(b, Vector3(x, h - 0.05, 0), true)
		CatDecor._ground_fp(b, 2.6, 0.8)
	b.door = Vector3(0, 0, 1.0)


# ---------- на стены ----------

## Фреска: две большие картины и два фриза Synty (Mural), в масштабе дома
static func _fresco(b: Bp, lk: int) -> void:
	var nm := "SM_Prop_Mural_0%d" % (1 + clampi(lk, 0, 3))
	var s: float = [0.7, 0.75, 0.85, 0.85][clampi(lk, 0, 3)]
	b.add(nm, Vector3(0, 0.25, 0.015), 0.0, s)


## Мозаичная эмблема: белый знак на цветном круглом медальоне; в венке; или два знака рядом
static func _medallion(b: Bp, p: Vector3, d: float, rm: Dictionary, sym: String, ss: float) -> void:
	b.parts.append(["SM_Prop_Plinth_03", b.base * Transform3D(Basis(Vector3.RIGHT, PI / 2) * Basis.from_scale(Vector3(d / 0.73, 0.6, d / 0.73)), p), rm.duplicate()])
	b.add(sym, p + Vector3(0, -0.34 * ss, 0.1), 0.0, ss)


static func _emblem(b: Bp, lk: int) -> void:
	match lk:
		0:
			_medallion(b, Vector3(0, 0.4, 0.0), 1.0, RED_PLAQUE, "SM_Prop_Symbol_10", 0.95)
		1:
			_medallion(b, Vector3(0, 0.45, 0.0), 0.95, BLUE_PLAQUE, "SM_Prop_Symbol_05", 1.0)
			for sx: float in [-1.0, 1.0]:
				b.add("SM_Env_Ivy_Draped_02", Vector3(sx * 0.42, 0.05, 0.06), sx * 0.6, 0.42)
		_:
			_medallion(b, Vector3(-0.5, 0.4, 0.0), 0.8, RED_PLAQUE, "SM_Prop_Symbol_03", 0.8)
			_medallion(b, Vector3(0.5, 0.4, 0.0), 0.8, RED_PLAQUE, "SM_Prop_Symbol_14", 0.8)


## Драпировка: полотно фестонами; или две ткани с подхватами
static func _drape(b: Bp, lk: int) -> void:
	if lk == 0:
		CatDecor._sx(b, "SM_Prop_Drapery_01", Vector3(-1.25, 0.75, 0.04), 0.0, Vector3(1.0, 1.0, 1.0), CatMonuments.SWAG_RED)
	else:
		for sx: float in [-1.0, 1.0]:
			CatShops._sheet(b, Vector3(sx * 0.45, 0.85, 0.05), 0.55, 1.1, CatShops.PURPLE if sx < 0.0 else CatShops.MUSTARD)
			b.add("SM_Prop_Banner_Drape_01", Vector3(sx * 0.62, 0.35, 0.18), 0.0 if sx < 0.0 else PI, 0.8)
		_beam(b, Vector3(-0.85, 0.88, 0.05), 1.7, 0.0, 0.4)


## Табличка с номером: мраморная доска, на ней бронзовые римские цифры
static func _numeral(b: Bp) -> void:
	b.parts.append(["#marble", b.base * Transform3D(Basis.from_scale(Vector3(1.1, 0.5, 0.05)), Vector3(0, 0.3, 0.025)), {}])
	var n := ["X", "V", "I"]
	for i in n.size():
		_add(b, "SM_Prop_Numeral_%s_01" % n[i], Vector3(-0.32 + i * 0.32, 0.16, 0.06), 0.0, 0.6, BRONZE_RM)


# ---------- праздник ----------

## Гирлянда пёстрых полотнищ между двумя шестами; или арка в лавре и лентах
static func _garland(b: Bp, lk: int) -> void:
	if lk == 0:
		for x: float in [-1.45, 1.45]:
			b.add("SM_Prop_Plinth_03", Vector3(x, 0, 0), 0.0, 0.5)
			_pole(b, Vector3(x, 0.07, 0), 2.9, 0.85, "SM_Prop_Pole_02")
			b.parts.append(["SM_Bld_Ornament_09", b.base * Transform3D(Basis.from_scale(Vector3.ONE * 0.6), Vector3(x, 3.0, 0)), {"tint": GILT}])
		_beam(b, Vector3(-1.5, 2.75, 0), 3.0, 0.0, 0.35)
		var cols := [CatShops.RED, CatShops.MUSTARD, CatShops.BLUE, CatShops.MUSTARD, CatShops.RED]
		for k in 5:
			CatShops._sheet(b, Vector3(-1.0 + k * 0.5, 2.74, 0.0), 0.36, 0.55 + (0.12 if k % 2 == 0 else 0.0), cols[k])
	else:
		var h := 3.13 * 0.8
		for sx: float in [-1.0, 1.0]:
			b.add("SM_Bld_Trellis_Pillar_01", Vector3(sx * 1.0, 0, 0), 0.0, 0.8)
			b.add("SM_Env_Ivy_Pillar_01", Vector3(sx * 1.0, 0, 0.02), _yaw(b), 0.9)
			CatShops._sheet(b, Vector3(sx * 1.0, h - 0.1, 0.12), 0.18, 1.3, CatShops.RED)
			_pot(b, Vector3(sx * 1.5, 0, 0.4), 0.75)
		b.add("SM_Bld_Trellis_Roof_End_01", Vector3(-1.3, h - 0.08, 0), PI / 2, 1.04)
		b.add("SM_Env_Ivy_Draped_02", Vector3(0, h + 0.2, 0.06), 0.0, 0.7)
		b.add("SM_Env_Ivy_Draped_02", Vector3(0, h + 0.18, -0.06), PI, 0.66)
		b.parts.append(["SM_Bld_Ornament_04", b.base * Transform3D(Basis.from_scale(Vector3.ONE * 0.5), Vector3(0, h + 0.25, 0.14)), {"tint": GILT}])
		CatDecor._ground_fp(b, 3.4, 1.0)
	b.door = Vector3(0, 0, 1.0)


## Большое полотнище на двух высоких шестах; или три знамени разной высоты на мраморной ступени
static func _bigbanner(b: Bp, lk: int) -> void:
	if lk == 0:
		for x: float in [-1.35, 1.35]:
			b.add("SM_Prop_Plinth_04", Vector3(x, 0, 0), 0.0, 0.55)
			_pole(b, Vector3(x, 0.37, 0), 3.9, 0.9, "SM_Prop_Pole_02")
			b.parts.append(["SM_Bld_Ornament_09", b.base * Transform3D(Basis.from_scale(Vector3.ONE * 0.75), Vector3(x, 4.3, 0)), {"tint": GILT}])
		_beam(b, Vector3(-1.4, 4.05, 0.02), 2.8, 0.0, 0.5)
		CatShops._sheet(b, Vector3(0, 4.0, 0.05), 2.5, 2.4, CatShops.RED)
		for k in 3:
			b.parts.append(["SM_Bld_Ornament_07", b.base * Transform3D(Basis.from_scale(Vector3.ONE * 0.45), Vector3(-0.7 + k * 0.7, 3.1, 0.12)), {"tint": GILT}])
	else:
		CatDecor._slab(b, Vector3.ZERO, Vector3(2.6, 0.14, 1.0))
		var hs := [2.7, 3.3, 2.7]
		var bn := ["SM_Prop_Banner_01_B", "SM_Prop_Banner_02_F", "SM_Prop_Banner_01_C"]
		for k in 3:
			var x := -0.9 + k * 0.9
			var h: float = hs[k]
			_sx(b, "SM_Prop_Pole_02", Vector3(x, 0.14, 0), 0.0, Vector3(0.9, h / 3.0, 0.9))
			_beam(b, Vector3(x - 0.4, 0.14 + h - 0.08, 0.08), 0.8, 0.0, 0.5)
			b.add(bn[k], Vector3(x, 0.14 + h - 0.12, -0.02), 0.0, 0.62)
			b.parts.append(["SM_Bld_Ornament_09", b.base * Transform3D(Basis.from_scale(Vector3.ONE * 0.6), Vector3(x, 0.14 + h + 0.05, 0)), {"tint": GILT}])
	b.door = Vector3(0, 0, 1.1)


## Стол с угощением и скамьи; или пиршественное ложе с подушками и столиком
static func _feast(b: Bp, lk: int) -> void:
	if lk == 0:
		_sx(b, "SM_Prop_Table_08", Vector3.ZERO, 0.0, Vector3(1.0, 1.0, 0.8))
		var top := 0.78
		for e: Array in [["SM_Prop_Plate_03", Vector3(-0.85, top, 0.05), 0.4], ["SM_Prop_Plate_03", Vector3(0.0, top, -0.1), 0.45],
				["SM_Prop_Plate_03", Vector3(0.8, top, 0.1), 0.4], ["SM_Prop_Goblet_01", Vector3(-0.45, top, 0.25), 0.8],
				["SM_Prop_Goblet_01", Vector3(0.4, top, -0.25), 0.8], ["SM_Prop_Jug_02", Vector3(0.45, top, 0.2), 0.5], ["SM_Prop_Jug_02", Vector3(-0.4, top, -0.25), 0.5]]:
			b.add(e[0], e[1], _yaw(b), e[2])
		CatShops._basket(b, Vector3(0.0, top, 0.22), "grapes" if b.chance(0.5) else "apples", 0.42)
		for z: float in [-0.8, 0.8]:
			CatShops._put_xf(b, "SM_Prop_Seat_Bench_05", Transform3D(Basis.from_scale(Vector3(1.0, CatShops.SEAT, 0.85)), Vector3(0, 0, z)))
	else:
		b.add("SM_Prop_Seat_Kline_Large_01", Vector3(0, 0, -0.35), 0.0, 0.85)
		CatShops._table(b, Vector3(0, 0, 0.6), 0.85)
		b.add("SM_Prop_Plate_03", Vector3(-0.1, CatShops.TABLE7, 0.6), 0.0, 0.42)
		b.add("SM_Prop_Goblet_01", Vector3(0.18, CatShops.TABLE7, 0.55), 0.0, 0.8)
		CatShops._basket(b, Vector3(-0.05, CatShops.TABLE7 + 0.02, 0.62), "grapes", 0.3)
		b.add("SM_Prop_Vase_02", Vector3(1.25, 0, 0.3), _yaw(b), 0.75)
		_pot(b, Vector3(-1.35, 0, 0.3), 0.75)
	b.door = Vector3(0, 0, 1.3)


## Помост поэта: низкий дощатый помост с ковром, лира на табурете, нимфа на постаменте
static func _poet(b: Bp) -> void:
	b.parts.append(["#dark", b.base * Transform3D(Basis.IDENTITY.scaled(Vector3(2.4, 0.26, 1.6)), Vector3(0, 0.13, -0.2)), {}])
	_sx(b, "SM_Bld_Trellis_Roof_01", Vector3(1.2, 0.0, -1.0), 0.0, Vector3(0.96, 1.0, 0.67))
	CatShops._put(b, "SM_Prop_Rug_01", Vector3(0, 0.3, -0.2), PI / 2, 0.6, CatShops._rug("03_A"))
	b.add("SM_Prop_Stool_01", Vector3(0.35, 0.3, -0.3), 0.3, 1.0)
	b.add_xf("SM_Prop_Lyre_01", Transform3D(Basis(Vector3.UP, 0.5) * Basis(Vector3.RIGHT, -0.3), Vector3(0.35, 0.78, -0.3)))
	b.add("SM_Prop_Plinth_02", Vector3(-0.75, 0.28, -0.6), 0.0, 0.75)
	b.add("SM_Prop_Statue_03", Vector3(-0.75, 0.28 + 0.76, -0.6), 0.3, 0.45)
	for x: float in [-1.45, 1.45]:
		_pot(b, Vector3(x, 0, 0.55), 0.7)
	b.door = Vector3(0, 0, 1.2)


# ---------- боги и герои ----------

## Ступенчатый мраморный пьедестал (две плиты и высокая тумба), верх — на возвращённой высоте
static func _pedestal(b: Bp, w: float, h: float) -> float:
	CatDecor._slab(b, Vector3.ZERO, Vector3(w, 0.16, w))
	CatDecor._slab(b, Vector3(0, 0.16, 0), Vector3(w * 0.78, 0.16, w * 0.78))
	_sx(b, "SM_Prop_Plinth_05", Vector3(0, 0.32, 0), 0.0, Vector3(w * 0.55 / 2.6, h / 2.59, w * 0.55 / 2.82))
	return 0.32 + h


static func _colossus(b: Bp, lk: int) -> void:
	match lk:
		0:
			var top := _pedestal(b, 2.3, 1.3)
			b.add("SM_Prop_Statue_07", Vector3(0, top - 0.02, 0), 0.0, 1.45)
		1:
			var top := _pedestal(b, 2.4, 1.2)
			b.add("SM_Prop_Statue_01", Vector3(0.1, top - 0.02, -0.05), 0.0, 1.3)
			for sx: float in [-1.0, 1.0]:
				b.add("SM_Prop_Brazier_03", Vector3(sx * 0.92, 0.16, 0.75), 0.0, 0.6)
				b.add("SM_Prop_Brazier_03_Insert_01", Vector3(sx * 0.92, 0.16, 0.75), 0.0, 0.6)
				CatDecor._fire(b, Vector3(sx * 0.92, 0.16 + 0.53, 0.75), 0.06, 4, 0.07, 0.045)
		_:
			CatDecor._slab(b, Vector3.ZERO, Vector3(2.2, 0.14, 2.2))
			b.add("SM_Prop_Pillar_Base_02", Vector3(0, 0.14, 0), 0.0, 0.85)
			b.add("SM_Prop_Statue_03", Vector3(0, 0.14 + 1.5 * 0.85 - 0.02, 0), 0.0, 1.35)
			for k in 4:
				var a := k * TAU / 4.0 + PI / 4.0
				_bloom(b, Vector3(cos(a) * 0.85, 0.14, sin(a) * 0.85), 0.24)
	b.door = Vector3(0, 0, 1.5)


## Бронзовый треножник: большая чаша с огнём на высокой мраморной колонне
static func _bigtorch(b: Bp) -> void:
	CatDecor._slab(b, Vector3.ZERO, Vector3(1.5, 0.14, 1.5))
	b.add("SM_Prop_Pillar_Base_01", Vector3(0, 0.14, 0), 0.0, 0.95)
	_sx(b, "SM_Bld_Pillar_02", Vector3(0, 1.09, 0), 0.0, Vector3(0.5, 0.62, 0.5))
	var h := 1.09 + 3.0 * 0.62
	b.add("SM_Prop_Brazier_01", Vector3(0, h, 0), 0.0, 0.62)
	b.add("SM_Prop_Brazier_01_Insert_01", Vector3(0, h, 0), 0.0, 0.62)
	CatDecor._fire(b, Vector3(0, h + 1.12, 0), 0.25, 7, 0.12, 0.07)
	b.light(Vector3(0, h + 1.35, 0))
	b.smoke.append(Vector3(0, h + 1.4, 0))
	b.door = Vector3(0, 0, 1.2)


## Золотой орёл (свой Kit: тело, крылья вверх, голова, венок) на колонне в плюще
static func _eagle(b: Bp) -> void:
	CatDecor._slab(b, Vector3.ZERO, Vector3(1.3, 0.14, 1.3))
	b.add("SM_Prop_Plinth_04", Vector3(0, 0.14, 0), 0.0, 1.0)
	var top := 0.82
	_sx(b, "SM_Bld_Pillar_02", Vector3(0, top, 0), 0.0, Vector3(0.5, 0.6, 0.5))
	_sx(b, "SM_Env_Ivy_Pillar_01", Vector3(0, top, 0), _yaw(b), Vector3(0.55, 0.65, 0.55))
	b.add("SM_Prop_Pillar_Top_01", Vector3(0, top + 1.8, 0), 0.0, 0.5)
	b.add("#d2_eagle", Vector3(0, top + 1.8 + 0.12, 0), 0.0, 1.0)
	_bloom(b, Vector3(0.62, 0.14, 0.55), 0.2)
	_bloom(b, Vector3(-0.6, 0.14, 0.55), 0.18)
	b.door = Vector3(0, 0, 1.2)


# ---------- «главные» украшения ----------

## Экседра: полукруглая мраморная скамья, по краям — статуи на постаментах, вазоны и кипарисы
static func _exedra(b: Bp) -> void:
	CatDecor._slab(b, Vector3(0, 0, -0.3), Vector3(5.2, 0.12, 3.0))
	b.add("SM_Prop_Seat_Bench_04", Vector3(0, 0.12, 0.6), 0.0, 0.85)
	for sx: float in [-1.0, 1.0]:
		b.add("SM_Prop_Plinth_04", Vector3(sx * 2.25, 0.12, -1.25), 0.0, 0.85)
		b.add(["SM_Prop_Statue_04", "SM_Prop_Statue_06"][int(sx > 0.0)], Vector3(sx * 2.25, 0.12 + 0.68 * 0.85, -1.25), 0.0, 0.75)
		_pot(b, Vector3(sx * 2.25, 0.12, 0.85), 0.8)
		b.add("SM_Env_Tree_Thin_01", Vector3(sx * 2.4, 0, -1.95), _yaw(b), 0.55)
	_bloom(b, Vector3(0, 0.12, -0.2), 0.3)
	b.door = Vector3(0, 0, 1.6)


## Мраморный бассейн: бортик из мрамора, в воде — кувшинки, у края — статуя на постаменте, вазоны по углам
static func _garden_pool(b: Bp) -> void:
	var hw := 1.6
	var hd := 1.1
	CatDecor._slab(b, Vector3.ZERO, Vector3(hw * 2.0 + 0.6, 0.08, hd * 2.0 + 0.6))
	for z: float in [-hd, hd]:
		b.parts.append(["#marble", b.base * Transform3D(Basis.from_scale(Vector3(hw * 2.0 + 0.3, 0.32, 0.18)), Vector3(0, 0.24, z)), {}])
	for x: float in [-hw, hw]:
		b.parts.append(["#marble", b.base * Transform3D(Basis.from_scale(Vector3(0.18, 0.32, hd * 2.0)), Vector3(x, 0.24, 0)), {}])
	b.parts.append(["#water", b.base * Transform3D(Basis.from_scale(Vector3(hw * 2.0 - 0.15, 0.05, hd * 2.0 - 0.15)), Vector3(0, 0.3, 0)), {}])
	CatDecor._lilies(b, Vector3(-0.6, 0.29, 0.3), 0.55)
	CatDecor._lilies(b, Vector3(0.7, 0.29, -0.35), 0.5)
	b.add("SM_Prop_Plinth_02", Vector3(0, 0.08, -hd - 0.15), 0.0, 0.8)
	b.add("SM_Prop_Statue_03", Vector3(0, 0.08 + 0.8, -hd - 0.15), PI, 0.5)
	for c: Vector3 in [Vector3(-hw, 0.4, -hd), Vector3(hw, 0.4, -hd), Vector3(-hw, 0.4, hd), Vector3(hw, 0.4, hd)]:
		_pot(b, c, 0.55)
	b.door = Vector3(0, 0, 1.8)


## Мозаика: круглый узор из плиток (плита пола Synty с мозаикой, как у фонтана) в мраморной рамке
static func _mosaic(b: Bp, w: float) -> void:
	CatDecor._slab(b, Vector3.ZERO, Vector3(w + 0.3, 0.04, w + 0.3))
	CatMonuments._floor(b, CatMonuments.MOSAIC, -w / 2.0, -w / 2.0, w / 2.0, w / 2.0, 0.05)


static func _mosaic_panel(b: Bp) -> void:
	_mosaic(b, 2.6)
	for k in 4:
		var a := k * PI / 2.0 + PI / 4.0
		_pot(b, Vector3(cos(a), 0, sin(a)) * 1.75, 0.7)
	b.door = Vector3(0, 0, 1.6)


static func _mosaic_court(b: Bp) -> void:
	_mosaic(b, 3.6)
	b.add("SM_Prop_Fountain_04", Vector3.ZERO, 0.0, 0.3)
	b.add("SM_Prop_Fountain_04_Insert_01", Vector3.ZERO, 0.0, 0.3)
	b.add("SM_Prop_Fountain_03", Vector3(0, 0.3 * 1.81 + 0.1, 0), 0.0, 0.7)
	for a: float in [0.0, PI / 2.0, PI, 3.0 * PI / 2.0]:
		var d := Vector3(sin(a), 0, cos(a))
		b.add("SM_Prop_Seat_Bench_01", d * 2.2, a, 0.75)
	for k in 4:
		var a := k * PI / 2.0 + PI / 4.0
		b.add("SM_Env_Tree_Thin_01", Vector3(cos(a), 0, sin(a)) * 2.3, _yaw(b), 0.45)
	b.door = Vector3(0, 0, 2.4)


## Обелиск (свой Kit: сужающийся четырёхгранный столб из гранита, золотая верхушка) на трёх ступенях
static func _obelisk(b: Bp) -> void:
	for k in 3:
		var w := 2.2 - k * 0.45
		CatDecor._slab(b, Vector3(0, k * 0.16, 0), Vector3(w, 0.16, w))
	b.add("#d2_obelisk", Vector3(0, 0.48, 0), 0.0, 1.0)
	for k in 4:
		var a := k * PI / 2.0 + PI / 4.0
		_bloom(b, Vector3(cos(a), 0, sin(a)) * 1.2, 0.22)
	b.door = Vector3(0, 0, 1.4)


## Колонна победы: высокая колонна на постаменте, наверху золотой орёл, у подножия — трофеи (щиты, копья) и вазоны
static func _victory_col(b: Bp) -> void:
	CatDecor._slab(b, Vector3.ZERO, Vector3(2.6, 0.16, 2.6))
	_sx(b, "SM_Prop_Plinth_05", Vector3(0, 0.16, 0), 0.0, Vector3(0.6, 0.55, 0.55))
	var top := 0.16 + 2.59 * 0.55
	_sx(b, "SM_Bld_Pillar_02", Vector3(0, top, 0), 0.0, Vector3(0.75, 1.6, 0.75))
	b.add("SM_Prop_Pillar_Top_01", Vector3(0, top + 4.8, 0), 0.0, 0.75)
	b.add("#d2_eagle", Vector3(0, top + 4.8 + 0.18, 0), 0.0, 1.4)
	CatMilitary._lean_shield(b, Vector3(-0.95, 0.16, 0.95), 0.6, "SM_Wep_Shield_01", 0.3, 0.6)
	CatMilitary._lean_shield(b, Vector3(0.95, 0.16, 0.95), -0.6, "SM_Wep_Shield_03", 0.3, 0.6)
	for sx: float in [-1.0, 1.0]:
		_pot(b, Vector3(sx * 1.05, 0.16, -0.95), 0.7)
	b.door = Vector3(0, 0, 1.6)


## Статуя триумфатора (полководец в шлеме с гребнем) на огромном ступенчатом пьедестале, по углам — жаровни
static func _emperor(b: Bp) -> void:
	var top := _pedestal(b, 3.2, 1.8)
	b.add("SM_Prop_Statue_02", Vector3(0, top - 0.02, 0), 0.0, 1.7)
	b.parts.append(["SM_Bld_Ornament_04", b.base * Transform3D(Basis.from_scale(Vector3.ONE * 0.8), Vector3(0, 1.3, 0.5)), {"tint": GILT}])
	for c: Vector3 in [Vector3(-1.35, 0.16, 1.35), Vector3(1.35, 0.16, 1.35), Vector3(-1.35, 0.16, -1.35), Vector3(1.35, 0.16, -1.35)]:
		b.add("SM_Prop_Brazier_03", c, 0.0, 0.62)
		b.add("SM_Prop_Brazier_03_Insert_01", c, 0.0, 0.62)
		CatDecor._fire(b, c + Vector3(0, 0.54, 0), 0.06, 4, 0.07, 0.045)
	b.light(Vector3(0, 2.0, 1.6))
	b.door = Vector3(0, 0, 2.0)


## Фонтан с тритонами: большая чаша в три яруса, вокруг — статуи на постаментах и львиные маски
static func _great_fountain(b: Bp) -> void:
	var s := 0.85
	b.add("SM_Prop_Fountain_04", Vector3.ZERO, 0.0, s)
	b.add("SM_Prop_Fountain_04_Insert_01", Vector3.ZERO, 0.0, s)
	var t1 := 1.81 * s
	b.add("SM_Prop_Fountain_04", Vector3(0, t1 - 0.1, 0), PI / 4.0, 0.35)
	b.add("SM_Prop_Fountain_04_Insert_01", Vector3(0, t1 - 0.1, 0), PI / 4.0, 0.35)
	b.add("SM_Prop_Statue_03", Vector3(0, t1 - 0.1 + 1.81 * 0.35 - 0.04, 0), 0.0, 0.55)
	for k in 4:
		var a := k * PI / 2.0
		var d := Vector3(sin(a), 0, cos(a))
		b.add("SM_Prop_Plinth_04", d * 2.15, a, 0.7)
		b.add(["SM_Prop_Statue_02", "SM_Prop_Statue_04", "SM_Prop_Statue_06", "SM_Prop_Statue_05"][k], d * 2.15 + Vector3(0, 0.68 * 0.7, 0), a + PI, 0.6)
	b.door = Vector3(0, 0, 2.6)


# ---------- свои модели (Kit): золотой орёл, обелиск ----------

static var _meshes := {}
const GOLD := Color("d9a93a")
const GOLD_D := Color("b07f22")
const GRANITE := Color("b9a58e")
const HEDGE_K := Color("5f8f3e")


static func kit_mesh(name: String) -> Mesh:
	if _meshes.has(name):
		return _meshes[name]
	var k := Kit.new()
	match name:
		"#d2_eagle": _k_eagle(k)
		"#d2_obelisk": _k_obelisk(k)
		"#d2_ball": k.blob(Vector3(0, 0.5, 0), Vector3(0.5, 0.47, 0.5), HEDGE_K, 5, 0.07)
		"#d2_cone": _k_cone(k)
		_: k.boxc(Vector3(0, 0.5, 0), Vector3.ONE, Color.MAGENTA)
	var m := k.mesh()
	if m.get_surface_count() > 0:
		m.surface_set_material(0, Kit.material(0.45))
	_meshes[name] = m
	return m


## Орёл с поднятыми крыльями на шаре, высота ~0,9 м (как на значках легионов, только крупнее)
static func _k_eagle(k: Kit) -> void:
	k.cyl(Vector3(0, 0, 0), 0.16, 0.06, 10, GOLD_D)
	k.blob(Vector3(0, 0.18, 0), Vector3(0.13, 0.13, 0.13), GOLD, 3, 0.04)
	k.blob(Vector3(0, 0.46, 0), Vector3(0.12, 0.2, 0.11), GOLD, 7, 0.08)
	k.blob(Vector3(0, 0.72, 0.05), Vector3(0.07, 0.075, 0.085), GOLD, 8, 0.05)
	k.cone(Vector3(0, 0.7, 0.12), 0.03, 0.07, 4, GOLD_D)
	for sx: float in [-1.0, 1.0]:
		k.quad_out(Vector3(sx * 0.06, 0.4, 0.0), Vector3(sx * 0.06, 0.62, 0.0), Vector3(sx * 0.46, 0.92, -0.05), Vector3(sx * 0.42, 0.55, -0.05), GOLD, Vector3(0, 0.6, -0.5))
		k.quad_out(Vector3(sx * 0.06, 0.4, 0.0), Vector3(sx * 0.06, 0.62, 0.0), Vector3(sx * 0.46, 0.92, -0.05), Vector3(sx * 0.42, 0.55, -0.05), GOLD_D, Vector3(0, 0.6, 0.5))
	k.quad_out(Vector3(-0.07, 0.3, -0.06), Vector3(0.07, 0.3, -0.06), Vector3(0.1, 0.14, -0.2), Vector3(-0.1, 0.14, -0.2), GOLD_D, Vector3(0, 0.3, 0.3))


## Самшит-конус высотой ~1,2 м: ярусы-«капли», сужаются кверху
static func _k_cone(k: Kit) -> void:
	for j in 4:
		var r := 0.36 - j * 0.08
		k.blob(Vector3(0, 0.22 + j * 0.27, 0), Vector3(r, 0.2, r), HEDGE_K, 11 + j, 0.06)


## Обелиск: четырёхгранный столб 3,6 м, сужается кверху, наверху — золотая пирамидка
static func _k_obelisk(k: Kit) -> void:
	k.cyl(Vector3(0, 0, 0), 0.52, 0.22, 4, GRANITE.darkened(0.1))
	k.cyl(Vector3(0, 0.22, 0), 0.4, 3.4, 4, GRANITE, 0.24)
	k.cone(Vector3(0, 3.62, 0), 0.24, 0.42, 4, GOLD)
