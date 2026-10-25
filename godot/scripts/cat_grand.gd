class_name CatGrand
extends RefCounted
## Здания этапа 5, волна 2 (план 24.10, 5.5–5.6): лудус и большие постройки веб-версии — акведук кусками, храм Венеры
## и Ромы, большие термы, маяк у воды, цирк для скачек. Чертёж в родных размерах Synty (Catalog уменьшает до
## Catalog.ARCH), фасад к +Z, вход — b.door. Люди при деле (b.actor) — места работников по порядку.
## На «Низкой» и «Очень низкой» тяжёлые детали этих зданий подменяются лёгкими (LOW, game._show).

const M := Bp.M
const FL := Bp.FL

## Акведук: половина длины куска (вдоль X) — кусок у конца другого встаёт вплотную (game._aqua_snap)
const AQ_HALF := 5.0
const AQ_T := 0.55                    # полутолщина стены арок
const AQ_PIER := 1.1                  # опора; у концов куска — половинка (две половинки соседей — одна опора)

## Лёгкие подмены на «Низкой» / «Очень низкой»: коринфские колонны — гладкие, тяжёлые статуи — лёгкие
const LOW := {"SM_Bld_Pillar_Large_04": "SM_Bld_Pillar_Large_01", "SM_Bld_Pillar_Large_03": "SM_Bld_Pillar_Large_01",
	"SM_Prop_Statue_01": "SM_Prop_Statue_05", "SM_Prop_Statue_07": "SM_Prop_Statue_05", "SM_Prop_Statue_04": "SM_Prop_Statue_03",
	"SM_Prop_Cart_01": "SM_Prop_Cart_02", "SM_Bld_Pillar_02": "SM_Bld_Pillar_06", "SM_Bld_Wall_Door_Double_01": "SM_Bld_Wall_Door_Double_Large_01"}
const TYPES := ["ludus", "aqua", "venus", "thermae", "pharos", "circus_fl"]

## Животные при здании (game._pets2, как CatExtra.PETS): у стартовых ворот цирка — кони у колесниц
const PETS := {
	"circus_fl": [["horse", Vector3(-17.2, 0, 2.3), PI / 2, "Idle", 1.0, -1], ["horse", Vector3(-17.2, 0, -2.3), PI / 2, "Eating", 1.0, -1]],
}

const TRAV := {"Stucco_White_01": "Stone_01", "tints": {"Building_Large_Brick_01": Color(1.0, 0.92, 0.8)}}   # тёплый травертин
const GOLD_ROOF := {"Roof_Tile_01": "Roof_Tile_05", "tints": {"Roof_Tile_05": Color(1.25, 1.02, 0.5)}}       # золочёная черепица


static func make(b: Bp, type: String) -> void:
	match type:
		"ludus": _ludus(b)
		"aqua": _aqua(b)
		"venus": _venus(b)
		"thermae": _thermae(b)
		"pharos": _pharos(b)
		"circus_fl": _circus(b)


# ---------- помощники ----------

static func _put(b: Bp, nm: String, xf: Transform3D, rm := {}) -> void:
	b.parts.append([nm, b.base * xf, rm])


## Общие раскраски этих зданий: красный низ, белый верх и карнизы, черепица Roof_Tile_01 — как у терм (CatCivic._baths).
## Одни и те же раскраски — одни и те же группы деталей в пуле: меньше вызовов отрисовки, когда здания рядом
static func _skins(b: Bp) -> Array:
	b.roof_tex = "Roof_Tile_01"
	return [CatCivic._skin(b, "Stucco_Red_01", Color(1.0, 0.86, 0.8)), CatCivic._skin(b, "Stucco_White_01", CatCivic.WHITE)]


## Деталь, что землю не занимает (под ней ходят): арка акведука
static func _free(b: Bp, nm: String, xf: Transform3D, rm := {}) -> void:
	b.free_parts[b.parts.size()] = true
	_put(b, nm, xf, rm)


# ---------- лудус ----------

## Лудус: школа гладиаторов. Сзади — двухэтажная казарма-«кельи» с черепицей и щитами, по бокам — крытые колоннады
## со скамьями, посредине — песчаная арена в каменном бортике: столб-палус, чучела, стойки с оружием. Спереди —
## низкая стенка с воротами и факелами (с улицы видно, как бьются). Работники: двое на арене бьются деревянными
## мечами, третий — ланиста — смотрит и учит
static func _ludus(b: Bp) -> void:
	b.paint(1, false)
	var sk := _skins(b)
	var red: Dictionary = sk[0]
	var cz := -4.6
	CatCivic._box(b, 0, cz, 5, 1, [
		{0: ["SM_Bld_Wall_Window_06", "SM_Bld_Wall_Door_Double_Large_01", "SM_Bld_Wall_Door_Double_Large_01", "SM_Bld_Wall_Door_Double_Large_01", "SM_Bld_Wall_Window_06"], 1: ["SM_Bld_Wall_01"], 3: ["SM_Bld_Wall_01"]},
		{0: ["SM_Bld_Wall_Window_06", "SM_Bld_Wall_Window_06", "SM_Bld_Wall_01", "SM_Bld_Wall_Window_06", "SM_Bld_Wall_Window_06"], 1: ["SM_Bld_Wall_Window_06"], 3: ["SM_Bld_Wall_Window_06"]}],
		{"trim": "SM_Bld_Trim_02", "plain": [2], "skin": red, "trim_skin": sk[1], "dark_front": 0.5})
	b.remap = red
	var ridge := CatCivic._gable2(b, -6.25, 6.25, cz - 1.25, cz + 1.25, 2 * FL, 1.4)
	b.add("SM_Bld_Roof_Topper_03", Vector3(0, ridge - 0.05, cz), PI / 2, 0.8)
	CatCivic._chimney(b, Vector3(4.2, ridge - 0.75, cz - 0.4), 0.8)
	var fz := cz + 1.25
	# по фасаду казармы — щиты и знамя над воротами
	for sd: float in [-1.0, 1.0]:
		for i: float in [0.5, 1.5]:
			b.add("SM_Wep_Shield_04", Vector3(sd * (6.25 - i * M), FL + 1.5, fz + 0.2), 0.0, 0.8)
	b.add("SM_Prop_Banner_03_B", Vector3(0, 2 * FL - 0.3, fz + 0.12), 0.0, 0.8)
	b.torch_pair(0, cz, 5, 1, 2.5)
	# колоннады по бокам арены (стена снаружи, кровля к стене)
	for side: float in [-1.0, 1.0]:
		var keep := b.base
		b.base = keep * Transform3D(Basis(Vector3.UP, -side * PI / 2), Vector3(side * 6.6, 0, -0.6))
		CatCivic._stoa(b, 2.75, 1.55, "SM_Bld_Pillar_06", ["SM_Bld_Wall_01"], 0.8)
		b.add("SM_Prop_Seat_Bench_03", Vector3(-1.3, 0, 0.55), 0.0, 0.85)
		b.add("SM_Prop_Seat_Bench_03", Vector3(1.3, 0, 0.55), 0.0, 0.85)
		CatMilitary._lean_shield(b, Vector3(0.0, 0, 0.32), 0.0, "SM_Wep_Shield_04", 0.25, 0.75)
		b.add("SM_Prop_Jug_03", Vector3(2.2, 0, 0.45), 0.0, 0.7)
		b.base = keep
	# арена: песок в каменном бортике, в бортике спереди — проход
	CatMilitary._sand(b, Vector3(0, 0, -0.6), 9.2, 5.6)
	CatMonuments._ring_rect(b, "SM_Bld_Ground_Edge_01", -4.6, 4.6, -3.4, 2.2, 0.0, 2.5, 1.0, 1.0, {}, [1, 2, 3])
	for sd: float in [-1.0, 1.0]:
		CatMonuments._run(b, "SM_Bld_Ground_Edge_01", Vector3(-4.6 if sd < 0 else 1.0, 0, 2.2), Vector3(1, 0, 0), 3.6, 2.5)
	# палус, чучела, стойки с мечами и копьями
	CatExtra._pole(b, Vector3(-3.0, 0, -1.9), 1.9, 1.2)
	CatMilitary.add_kit(b, "#mil_dummy", Vector3(3.0, 0, -2.0), -0.3)
	CatMilitary.add_kit(b, "#mil_dummy", Vector3(3.4, 0, 0.9), 0.4)
	CatMilitary._rack(b, Vector3(-2.2, 0, fz + 0.35), 0.0, 2)
	CatMilitary._rack(b, Vector3(2.2, 0, fz + 0.35), 0.0, 2)
	b.add("SM_Prop_Sack_0%d" % (3 + b.rng.randi() % 3), Vector3(-3.9, 0, 1.4), 0.4, 0.7)
	b.add("SM_Prop_Straw_Stack_01", Vector3(-3.7, 0, -2.5), 0.6, 0.35)
	# спереди: низкая стенка с воротами; у ворот — статуя гладиатора, факелы, знамёна
	for sd: float in [-1.0, 1.0]:
		b.parts.append(["SM_Bld_Wall_01", b.base * Transform3D(Basis.IDENTITY.scaled_local(Vector3(5.0 / M, 0.38, 1.0)), Vector3(-6.85 if sd < 0 else 1.85, 0, 2.55)), red.duplicate()])
		CatShops._pole(b, Vector3(sd * 1.65, 0, 2.6), 2.6)
		b.add("SM_Prop_Torch_01", Vector3(sd * 1.65, 2.2, 2.75), 0.0, 1.3)
		CatDecor._flame(b, Vector3(sd * 1.65, 2.42, 2.75), 0.08)
		b.light(Vector3(sd * 1.65, 2.7, 2.9))
		b.add("SM_Prop_Banner_03_B", Vector3(sd * 1.65, 2.55, 2.68), 0.0, 0.55)
	CatDecor2._beam(b, Vector3(-1.8, 2.6, 2.6), 3.6, 0.0, 0.8)
	b.add("SM_Prop_Plinth_04", Vector3(-5.6, 0, 3.2), 0.0, 0.9)
	b.add("SM_Prop_Statue_02", Vector3(-5.6, 0.61, 3.2), 0.3, 0.7)
	b.actor(Vector3(-0.8, 0, -0.4), PI / 2, "Spar", "pleb")
	b.actor(Vector3(0.8, 0, -0.4), -PI / 2, "Sword_Idle", "pleb")
	b.actor(Vector3(-0.3, 0, -2.2), 0.2, "Spell_Simple_Idle", "any")
	b.door = Vector3(0, 0, 3.4)


# ---------- акведук ----------

## Кусок акведука вдоль X: два пролёта в два яруса арок из травертина, поверху — каменный жёлоб с карнизом, в нём вода.
## Землю занимают только опоры: под арками — свободная земля (можно провести улицу, жители ходят под арками).
## У концов — половинки опор: соседний кусок встаёт вплотную, и опора на стыке — как все
static func _aqua(b: Bp) -> void:
	var H1 := 5.0
	var H2 := 3.0
	var top := H1 + H2
	for sp in 2:
		var x0 := -AQ_HALF + sp * AQ_HALF
		var x1 := x0 + AQ_HALF
		for tr: Array in [[0.0, H1], [H1, H2]]:
			var y0: float = tr[0]
			var th: float = tr[1]
			var sc := Basis.from_scale(Vector3(AQ_HALF / M, th / 3.01, 1.0))
			_free(b, "SM_Bld_Wall_Door_Double_01", Transform3D(sc, Vector3(x0, y0, AQ_T)), TRAV)
			_free(b, "SM_Bld_Wall_Door_Double_01", Transform3D(Basis(Vector3.UP, PI) * sc, Vector3(x1, y0, -AQ_T)), TRAV)
		# карниз между ярусами — с обеих сторон
		_put(b, "SM_Bld_Wall_Large_Cap_01", Transform3D(Basis.from_scale(Vector3(AQ_HALF / 5.02, 0.6, 1.4)), Vector3(x0, H1, 0.0)))
	# опоры: внизу — тёсаный камень во всю высоту нижнего яруса, внутри арок — светлый проём
	for k in 3:
		var x := -AQ_HALF + k * AQ_HALF
		var w := AQ_PIER if k == 1 else AQ_PIER * 0.5
		var cx := x + (w * 0.5 if k == 0 else (-w * 0.5 if k == 2 else 0.0))
		_put(b, "SM_Bld_Wall_Large_Pillar_01", Transform3D(Basis.from_scale(Vector3(w / 0.92, H1 / 4.55, 2.0 * AQ_T / 0.92)), Vector3(cx, 0, 0)), CatMonuments.TRAV_BLOCKS)
		_put(b, "#marble", Transform3D(Basis.from_scale(Vector3(w * 0.8, H2 * 0.6, 2.0 * AQ_T - 0.06)), Vector3(cx, H1 + H2 * 0.3, 0)))
	# жёлоб поверху: каменный короб, карниз, полоса воды
	CatMonuments._box(b, "#marble", Vector3(0, top + 0.3, 0), Vector3(2.0 * AQ_HALF + 0.02, 0.6, 2.0 * AQ_T + 0.2))
	_put(b, "SM_Bld_Wall_Large_Cap_01", Transform3D(Basis.from_scale(Vector3(2.0 * AQ_HALF / 5.02, 0.8, 1.45)), Vector3(-AQ_HALF, top + 0.6, 0.0)))
	_put(b, "#water", Transform3D(Basis.from_scale(Vector3(2.0 * AQ_HALF - 0.1, 0.06, 0.5)), Vector3(0, top + 0.88, 0)))
	# плющ на средней опоре, у подножий — трава и камни
	b.add(CatMonuments._ivy_flat(b), Vector3(0.0, 2.2, AQ_T + 0.08), 0.0, 1.0)
	b.add("SM_Env_Grass_0%d" % (1 + b.rng.randi() % 3), Vector3(-AQ_HALF + 0.5, 0, AQ_T + 0.4), b.rng.randf() * TAU, 0.8)
	b.add("SM_Env_Grass_0%d" % (1 + b.rng.randi() % 3), Vector3(0.3, 0, -AQ_T - 0.4), b.rng.randf() * TAU, 0.8)
	b.door = Vector3(0, 0, AQ_T + 1.2)


# ---------- храм Венеры и Ромы ----------

## Храм Венеры и Ромы: самый большой храм — колоннада со всех сторон (спереди — восемь коринфских колонн), высокий
## подиум с лестницей во всю ширину, мраморная целла с бронзовыми вратами, золочёная черепица, синие фронтоны
## с медальонами, у лестницы — статуи Венеры и Ромы, жаровни, алтарь с огнём; вокруг кипарисы и цветы
static func _venus(b: Bp) -> void:
	var s := 0.66
	b.base = Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3(0, 0, 7.4))
	var pod := 1.8
	var hw := 8.75                       # оси крайних колонн
	var zc0 := -1.0                      # передний ряд колонн
	var zcb := -23.5                     # задний ряд
	var px := hw + 0.85
	CatMonuments._podium(b, -px, px, zcb - 0.9, 0.0, pod)
	CatMonuments._floor(b, CatMonuments.PAVING, -px, zcb - 0.9, px, 0.0, pod + 0.02, 4, 6)
	var zfront := CatMonuments._front_stairs(b, -hw, hw, 0.0, pod)
	for sd: float in [-1.0, 1.0]:
		CatMonuments._big_brazier(b, Vector3(sd * (hw + 0.42), pod + 0.72, 1.6), 0.62)
	# колоннада: спереди — коринфские, по бокам и сзади — гладкие (легче)
	for i in 8:
		b.add("SM_Bld_Pillar_Large_04", Vector3(-hw + i * M, pod, zc0))
	for z in range(1, 9):
		for sd: float in [-1.0, 1.0]:
			b.add("SM_Bld_Pillar_Large_01", Vector3(sd * hw, pod, zc0 - z * M))
	for i in 8:
		b.add("SM_Bld_Pillar_Large_01", Vector3(-hw + i * M, pod, zcb))
	# целла: мраморные стены в два яруса, ниши со статуями у врат
	var keep := b.remap
	b.remap = CatMonuments.MARBLE_WALL
	var zcf := -3.9
	var cz := (zcf + zcb + 2.4) / 2.0
	var dm := 7
	for f in 2:
		var y := pod + f * FL
		for i in dm:
			b.on_wall("SM_Bld_Wall_01", 0, cz, 5, dm, 1, i, y, 0.0, true)
			b.on_wall("SM_Bld_Wall_01", 0, cz, 5, dm, 3, i, y, 0.0, true)
		for i in 5:
			b.on_wall("SM_Bld_Wall_01", 0, cz, 5, dm, 2, i, y, 0.0, true)
		for i: int in ([0, 4] if f == 0 else [0, 1, 3, 4]):
			b.on_wall("SM_Bld_Wall_01", 0, cz, 5, dm, 0, i, y, 0.0, true)
	b.remap = keep
	var cf := cz + dm * M / 2.0
	for i: int in [1, 3]:
		b.on_wall("SM_Bld_Wall_Alcove_01", 0, cz, 5, dm, 0, i, pod)
		CatMonuments._statue(b, Vector3(-6.25 + i * M + 1.25, pod + 0.22, cf - 0.15), 0.0, 0.78, 6 if i == 1 else 3)
	_put(b, "SM_Bld_Door_Monument_01", Transform3D(Basis.from_scale(Vector3(0.56, 0.667, 0.56)), Vector3(-1.42, pod, cf + 0.08)))
	CatMonuments._box(b, "#dark", Vector3(0, pod + FL, cz), Vector3(5 * M - 0.5, 2 * FL - 0.1, dm * M - 0.6))
	# антаблемент, золочёная кровля, фронтоны спереди и сзади
	var x0 := -hw - 0.45
	var x1 := hw + 0.45
	var zf := zc0 + 0.45
	var zb := zcb - 0.45
	var eave := CatMonuments._entablature(b, x0, x1, zb, zf, pod + 6.0)
	var half := x1 + 0.15
	var ridge := _roof(b, half, zf + 0.35, zb - 0.35, eave, GOLD_ROOF, CatMonuments.TYMPANUM)
	CatMonuments._pediment(b, half, eave, zf + 0.35, ridge, zb - 0.35)
	for i: int in [1, 3, 5]:
		CatMonuments._at(b, "SM_Prop_Drapery_03", Vector3(-hw + M * 0.5 + i * M, pod + 5.95, zc0 + 0.42), 0.0, 1.0, CatMonuments.SWAG_RED)
	# алтарь перед лестницей, статуи богинь у её подножия
	b.add("SM_Prop_Plinth_04", Vector3(0, 0, zfront + 2.2), 0.0, 1.2)
	CatMonuments._fire_bowl(b, Vector3(0, 0.82, zfront + 2.2), 0.9)
	for sd: float in [-1.0, 1.0]:
		b.add("SM_Prop_Plinth_04", Vector3(sd * (hw - 1.2), 0, zfront + 1.2), 0.0, 1.3)
		CatMonuments._statue(b, Vector3(sd * (hw - 1.2), 0.68 * 1.3, zfront + 1.2), 0.0, 1.05, 6 if sd < 0.0 else 4)
		CatMonuments._pot(b, Vector3(sd * (hw + 0.3), pod, zc0 + 0.55), 0.55)
		b.add("SM_Env_Ivy_Pillar_Flowers_04", Vector3(sd * hw, pod, zcb), b.rng.randf() * TAU, 1.0)
		for z: float in [zcb + 2.0, -8.0, zc0 - 1.0]:
			CatMonuments._cypress(b, Vector3(sd * (px + 1.0), 0, z), 1.1)
		b.add("SM_Env_Bush_Cluster_0%d" % (1 + b.rng.randi() % 3), Vector3(sd * (px + 0.6), 0, -14.0), b.rng.randf() * TAU, 0.9)
		b.add("SM_Env_Flowers_0%d" % (1 + b.rng.randi() % 4), Vector3(sd * (hw - 3.0), 0, zfront + 1.0), b.rng.randf() * TAU, 1.3)
	b.base = Transform3D.IDENTITY
	b.door = Vector3(0, 0, 7.4 + (zfront + 0.7) * s)
	b.actor(Vector3(0, 0, 7.4 + (zfront + 1.6) * s), PI, "Spell_Simple_Idle", "rich")
	b.actor(Vector3(1.8, pod * s, 7.4 + (zc0 - 1.2) * s), PI + 0.3, "Idle", "any")


## Пологая кровля храма (как CatMonuments._temple_roof), со своей черепицей rm и тимпанами tym
static func _roof(b: Bp, half: float, z_front: float, z_back: float, eave: float, rm: Dictionary, tym: Dictionary) -> float:
	var k := half / 7.5
	var len := z_front - z_back
	var n := maxi(1, int(ceil(len / 7.5)))
	var lz := len / n
	for i in n:
		var z0 := z_back + i * lz
		_put(b, "SM_Bld_Roof_Straight_Thin_Large_01", Transform3D(Basis(Vector3.UP, -PI / 2).scaled_local(Vector3(lz / 7.5, k, k)), Vector3(-half, eave, z0)), rm)
		_put(b, "SM_Bld_Roof_Straight_Thin_Large_01", Transform3D(Basis(Vector3.UP, PI / 2).scaled_local(Vector3(lz / 7.5, k, k)), Vector3(half, eave, z0 + lz)), rm)
	var trm := tym.duplicate(true)
	for kk in rm:
		if kk != "tints":
			trm[kk] = rm[kk]
	if rm.has("tints"):
		var tt: Dictionary = trm.get("tints", {}).duplicate()
		tt.merge(rm["tints"])
		trm["tints"] = tt
	for zz: float in [z_front, z_back]:
		_put(b, "SM_Bld_Roof_Side_Large_01", Transform3D(Basis(Vector3.UP, -PI / 2).scaled_local(Vector3(1, k, k)), Vector3(-half, eave, zz)), trm)
		_put(b, "SM_Bld_Roof_Side_Large_01", Transform3D(Basis(Vector3.UP, PI / 2).scaled_local(Vector3(1, k, k)), Vector3(half, eave, zz)), trm)
	return eave + 1.94 * k


# ---------- большие термы ----------

## Большие термы: высокий зал-кальдарий с огромными арочными окнами и куполом на барабане, по бокам — крылья
## с малыми куполами; перед залом — бассейн под открытым небом в колоннаде, статуи, пальмы; сзади — дым топки
static func _thermae(b: Bp) -> void:
	b.paint(6, false)
	b.tint = Color(1.0, 0.95, 0.86)
	b.ground_style = "pattern"
	b.upper_style = "plain"
	b.roof_tex = "Roof_Tile_01"
	b.remap = b.floor_remap(1)
	var white := CatCivic._skin(b, "Stucco_White_01", CatCivic.WHITE)
	var red := CatCivic._skin(b, "Stucco_Red_01", Color(1.0, 0.86, 0.8))
	# зал: 3×3 модуля, стены из больших арочных окон (5 м) в полтора этажа, карниз, барабан и купол
	var cz := -4.5
	var hx := 3.75
	var hall_h := 6.8
	var wsc := Basis.from_scale(Vector3(7.5 / 5.0, hall_h / 4.51, 1))
	var brick := CatMonuments.BRICK           # зал — римский кирпич, как у терм Каракаллы; карнизы белые
	# спереди и по бокам — по три высоких арочных окна (в них темно), сзади — глухая стена
	var asc := Basis.from_scale(Vector3(1.0, hall_h / 3.01, 1.0))
	for i in 3:
		_put(b, "SM_Bld_Wall_Door_Double_01", Transform3D(asc, Vector3(-hx + i * M, 0, cz + hx)), brick)
		_put(b, "SM_Bld_Wall_Door_Double_01", Transform3D(Basis(Vector3.UP, PI / 2) * asc, Vector3(hx, 0, cz + hx - i * M)), brick)
		_put(b, "SM_Bld_Wall_Door_Double_01", Transform3D(Basis(Vector3.UP, -PI / 2) * asc, Vector3(-hx, 0, cz - hx + i * M)), brick)
	_put(b, "SM_Bld_Wall_Large_01", Transform3D(Basis(Vector3.UP, PI) * wsc, Vector3(hx, 0, cz - hx)), brick)
	CatMonuments._box(b, "#dark", Vector3(0, hall_h / 2.0, cz), Vector3(7.0, hall_h - 0.1, 7.0))
	CatMonuments._ring_rect(b, "SM_Bld_Wall_Large_Cap_01", -hx - 0.1, hx + 0.1, cz - hx - 0.1, cz + hx + 0.1, hall_h - 0.1, 5.0, 1.0, 1.0)
	# барабан (круглая стенка — закрывает столбики купола) и свинцовый купол
	var kb := b.base
	b.base = kb * Transform3D(Basis.IDENTITY, Vector3(0, 0, cz))
	for i in 8:
		CatMonuments._ring_put(b, "SM_Bld_Wall_Tiny_01", i * PI / 4.0 + PI / 8.0, 3.5, hall_h + 0.2, 2.0 * 3.5 * tan(PI / 8.0) + 0.06, 2.5, 4.0, 1.0, white)
	b.base = kb
	CatMonuments._box(b, "#marble", Vector3(0, hall_h + 0.1, cz), Vector3(7.2, 0.2, 7.2))
	var ky := 0.8
	_put(b, "SM_Prop_Pergola_01", Transform3D(Basis.from_scale(Vector3(1.32, ky, 1.32)), Vector3(0, hall_h + 0.95 - 3.6 * ky, cz)), CatMonuments.DOME_LEAD)
	# крылья: 2×2 модуля, красный низ, белый верх, плоская крыша с парапетом и малым куполом
	for sd: float in [-1.0, 1.0]:
		var wx := sd * (hx + 2.5)
		CatCivic._box(b, wx, cz + 0.6, 2, 2, [
			{0: ["SM_Bld_Wall_Window_06", "SM_Bld_Wall_Door_Double_Large_01"] if sd < 0.0 else ["SM_Bld_Wall_Door_Double_Large_01", "SM_Bld_Wall_Window_06"],
				1: ["SM_Bld_Wall_Window_06", "SM_Bld_Wall_01"], 2: ["SM_Bld_Wall_01", "SM_Bld_Wall_01"], 3: ["SM_Bld_Wall_01", "SM_Bld_Wall_Window_06"]}],
			{"trim": "SM_Bld_Trim_02", "skin": red, "trim_skin": white, "sides": [0, 2, 1 if sd > 0.0 else 3], "dark_front": 0.5})
		for i in 2:
			for j in 2:
				b.add("SM_Bld_Roof_Base_Flat_02", Vector3(wx - 2.5 + i * M, FL - 0.68, cz + 0.6 + 2.5 - j * M), 0.0)
		b.remap = white
		for side: int in [0, 2, 1 if sd > 0.0 else 3]:
			for i in 2:
				b.on_wall("SM_Bld_Wall_Balcony_05", wx, cz + 0.6, 2, 2, side, i, FL, 0.0, true)
		b.remap = b.floor_remap(1)
		b.add("SM_Prop_Pergola_01", Vector3(wx, FL + 0.05, cz + 0.6), 0.0, 0.42)
		b.add("SM_Env_Tree_Palm_0%d" % (1 + b.rng.randi() % 3), Vector3(sd * 9.4, 0, cz - 2.0), b.rng.randf() * TAU, 0.5)
	b.smoke.append(b.base * Vector3(2.0, hall_h + 2.0, cz - 3.9))
	CatCivic._chimney(b, Vector3(2.4, hall_h - 0.4, cz - 3.2), 1.0)
	# бассейн под открытым небом: вода, бортики, ступени; по бокам — колоннады, статуи по углам
	var pz0 := cz + hx + 0.4
	CatCivic._pool(b, -5.0, 5.0, pz0, pz0 + 5.0, true)
	CatMonuments._floor(b, CatMonuments.MOSAIC, -6.4, pz0 - 0.4, 6.4, pz0 + 6.4, 0.01, 5, 3)
	for sd: float in [-1.0, 1.0]:
		for i in 3:
			b.add("SM_Bld_Pillar_02", Vector3(sd * 6.3, 0, pz0 + 0.3 + i * 2.4), 0.0, 0.95)
		CatMonuments._box(b, "#marble", Vector3(sd * 6.3, 2.85 + 0.16, pz0 + 2.7), Vector3(0.62, 0.32, 5.6))
		b.add("SM_Env_Lillies_0%d" % (1 + b.rng.randi() % 3), Vector3(sd * 2.6, 0.13, pz0 + 2.5), b.rng.randf() * TAU, 0.6)
		CatCivic._statue(b, Vector3(sd * 5.6, 0, pz0 + 5.9), 0.0, 0.8)
		b.brazier(Vector3(sd * 1.6, 0, pz0 + 5.95))
		b.add("SM_Prop_Fountain_01", Vector3(sd * 2.5, 0.0, pz0 + 0.25), 0.0, 0.9)
		b.add("SM_Prop_Seat_Bench_03", Vector3(sd * 7.2, 0, pz0 + 2.6), sd * PI / 2 * -1.0, 0.8)
	b.add("SM_Prop_Rug_Folded_03", Vector3(3.6, 0.22, pz0 + 5.25), 0.0, 0.6)
	b.add("SM_Prop_Basket_Set_02", Vector3(-7.0, 0, pz0 - 0.6), 0.0, 0.6)
	b.actor(Vector3(-1.2, 0, pz0 + 5.6), PI, "Idle", "any")
	b.actor(Vector3(4.2, 0, pz0 + 5.7), PI - 0.5, "Interact", "any")
	b.actor(Vector3(-4.3, 0, pz0 - 0.15), 0.0, "Idle_Talking", "any")
	b.actor(Vector3(1.4, 0, pz0 - 0.2), 0.3, "Spell_Simple_Idle", "any")
	b.door = Vector3(0, 0, pz0 + 6.9)


# ---------- маяк ----------

## Маяк, как на Фаросе: каменная площадка со ступенями, квадратная башня с окошками в три этажа, восьмигранный
## ярус, круглый фонарь на колоннах с огнём (ночью светит далеко) и статуя наверху; у подножия — амфоры, мешки, канаты
static func _pharos(b: Bp) -> void:
	b.paint(0, false)
	var white: Dictionary = _skins(b)[1]         # белый известняк, как у Фароса (раскраска — общая с термами)
	var stone := white
	var py := 1.0
	CatCivic._marble(b, Vector3(0, 0, 0), Vector3(9.0, py, 9.0))
	CatMonuments._ring_rect(b, "SM_Bld_Wall_Large_Cap_01", -4.5, 4.5, -4.5, 4.5, py - 0.28, 5.0, 1.0, 0.8)
	CatMonuments._front_stairs(b, -2.5, 2.5, 4.5, py)
	# башня 2×2 модуля в три этажа: камень, узкие окошки, карнизы
	var keep := b.base
	b.base = keep * Transform3D(Basis.IDENTITY, Vector3(0, py, 0))
	CatCivic._box(b, 0, 0, 2, 2, [
		{0: ["SM_Bld_Wall_Door_04", "SM_Bld_Wall_01"], 1: ["SM_Bld_Wall_01", "SM_Bld_Wall_Window_06"], 2: ["SM_Bld_Wall_01", "SM_Bld_Wall_01"], 3: ["SM_Bld_Wall_Window_06", "SM_Bld_Wall_01"]},
		{0: ["SM_Bld_Wall_Window_06", "SM_Bld_Wall_Window_06"], 1: ["SM_Bld_Wall_Window_06", "SM_Bld_Wall_01"], 2: ["SM_Bld_Wall_01", "SM_Bld_Wall_Window_06"], 3: ["SM_Bld_Wall_01", "SM_Bld_Wall_Window_06"]},
		{0: ["SM_Bld_Wall_01", "SM_Bld_Wall_Window_06"], 1: ["SM_Bld_Wall_Window_06", "SM_Bld_Wall_Window_06"], 2: ["SM_Bld_Wall_Window_06", "SM_Bld_Wall_01"], 3: ["SM_Bld_Wall_Window_06", "SM_Bld_Wall_Window_06"]}],
		{"trim": "SM_Bld_Trim_02", "skin": stone, "trim_skin": white})
	CatCivic._leaf(b, 0, 0, 2, 2, 0, "SM_Bld_Door_02")
	var t1 := 3 * FL
	# плоская крыша башни с парапетом
	for i in 2:
		for j in 2:
			b.add("SM_Bld_Roof_Base_Flat_02", Vector3(-2.5 + i * M, t1 - 0.68, 2.5 - j * M), 0.0)
	b.remap = white
	for side in 4:
		for i in 2:
			b.on_wall("SM_Bld_Wall_Balcony_05", 0, 0, 2, 2, side, i, t1, 0.0, true)
	# восьмигранный ярус
	var r8 := 1.75
	var w8 := 2.0 * r8 * tan(PI / 8.0) + 0.05
	for f in 2:
		for i in 8:
			var ang := i * PI / 4.0
			CatMonuments._ring_put(b, "SM_Bld_Wall_Window_06" if (i + f) % 2 == 0 else "SM_Bld_Wall_01", ang, r8, t1 + f * 2.6, w8, 2.5, 2.6 / 3.01, 1.0, stone)
	var t2 := t1 + 5.2
	for i in 8:
		CatMonuments._ring_put(b, "SM_Bld_Wall_Large_Cap_01", i * PI / 4.0, r8 + 0.1, t2 - 0.25, w8 + 0.15, 5.0, 1.0, 0.8)
	CatMonuments._box(b, "#marble", Vector3(0, t2 / 2.0 + t1 / 2.0, 0), Vector3(2.0 * r8 - 0.3, t2 - t1, 2.0 * r8 - 0.3))
	CatMonuments._box(b, "#marble", Vector3(0, t2 + 0.1, 0), Vector3(2.0 * r8 + 0.2, 0.2, 2.0 * r8 + 0.2))
	# фонарь — круглая беседка на колоннах под свинцовым куполом, внутри большая жаровня с огнём, наверху статуя
	var kl := 0.6
	_put(b, "SM_Prop_Pergola_01", Transform3D(Basis.from_scale(Vector3(kl, kl, kl)), Vector3(0, t2 + 0.2 + 0.36 * kl, 0)), CatMonuments.DOME_LEAD)
	b.add("SM_Prop_Brazier_04", Vector3(0, t2 + 0.2, 0), 0.0, 1.5)
	b.add("SM_Prop_Brazier_04_Insert_01", Vector3(0, t2 + 0.2, 0), 0.0, 1.5)
	CatDecor._fire(b, Vector3(0, t2 + 1.05, 0), 0.22, 7, 0.16, 0.08)
	b.light(Vector3(0, t2 + 1.4, 0))
	b.light(Vector3(0, t2 + 1.4, 0.6))
	b.smoke.append(b.base * Vector3(0, t2 + 2.6, 0))
	var tip := t2 + 0.2 + 6.02 * kl
	b.add("SM_Prop_Statue_04", Vector3(0, tip, 0), 0.0, 0.95)
	b.base = keep
	# у подножия — амфоры, мешки, канаты, ящик, якорь-камни
	for e: Array in [["SM_Prop_Vase_Pile_02", Vector3(-3.6, py, 3.4)], ["SM_Prop_Sack_Stack_01", Vector3(3.5, py, 3.3)], ["SM_Prop_Jar_Pile_01", Vector3(3.6, py, -3.4)],
			["SM_Prop_Basket_Set_01", Vector3(-3.6, py, -3.5)]]:
		b.add(e[0], e[1], b.rng.randf() * TAU, 0.75)
	b.actor(Vector3(2.2, py, 3.4), -0.4, "Idle", "pleb")
	b.actor(Vector3(-2.3, py, 3.0), 0.5, "Interact", "pleb")
	b.door = Vector3(0, 0, 4.5 + 2.7 + 0.6)


# ---------- цирк ----------

## Цирк для скачек колесниц (вдоль X): песчаная дорожка вокруг «спины» — мраморной стенки с обелиском, статуями,
## бассейнами и тумбами-метами на концах; по длинным сторонам — трибуны ступенями под полосатыми навесами, снаружи —
## аркада; на одном конце — стартовые ворота с башнями (у ворот кони и колесницы), на другом — полукруглая стена
## с триумфальными воротами. В середине передней трибуны — ложа с колоннами и фронтоном
static func _circus(b: Bp) -> void:
	b.paint(0, false)
	var sk := _skins(b)
	b.remap = sk[0]
	var L := 22.0                        # от середины до конца прямой дорожки
	var tw := 4.2                        # полуширина дорожки
	var sd_d := 3.6                      # глубина трибун
	var sh := 2.8                        # высота трибун
	# дорожка — песок (у полукруглого конца — тоже)
	CatMilitary._sand(b, Vector3(1.0, 0, 0), 2.0 * L + 2.0, 2.0 * tw)
	for k in 2:
		var bs := Basis(Vector3.UP, k * PI / 4.0)
		_put(b, "#mil_sand", Transform3D(bs * Basis.from_scale(Vector3(2.0 * tw, 1.0, 2.0 * tw)), Vector3(L, 0.012 + k * 0.002, 0)))
	# спина: мраморная стенка, вода поверху, обелиск, статуи, меты
	CatMonuments._box(b, "#marble", Vector3(0, 0.4, 0), Vector3(2.0 * (L - 6.0), 0.8, 1.2))
	CatMonuments._ring_rect(b, "SM_Bld_Wall_Large_Cap_01", -(L - 6.0), L - 6.0, -0.6, 0.6, 0.55, 5.0, 0.8, 0.6)
	_put(b, "#water", Transform3D(Basis.from_scale(Vector3(2.0 * (L - 6.5), 0.05, 0.6)), Vector3(0, 0.84, 0)))
	b.add("#d2_obelisk", Vector3(0, 0.8, 0), 0.0, 1.9)
	for x: float in [-9.0, -4.5, 4.5, 9.0]:
		b.add("SM_Prop_Plinth_04", Vector3(x, 0.8, 0), 0.0, 0.7)
		CatMonuments._statue(b, Vector3(x, 0.8 + 0.48, 0), PI / 2 if x < 0.0 else -PI / 2, 0.55, 0)
	for e: float in [-(L - 5.0), L - 5.0]:
		CatMonuments._box(b, "#marble", Vector3(e, 0.5, 0), Vector3(1.8, 1.0, 1.8))
		for j in 3:
			b.add("#d2_obelisk", Vector3(e, 1.0, -0.55 + j * 0.55), 0.0, 0.42)
		b.add("SM_Prop_Senser_01", Vector3(e + signf(e) * 0.9, 1.0, 0.0), 0.0, 0.7)
	# трибуны: ступени из лестниц амфитеатра, сзади — аркада наружу, поверху — навесы
	var n := int((2.0 * L) / M)
	for side: float in [-1.0, 1.0]:
		var zi := side * (tw + 0.2)
		for i in n:
			var x := -L + i * M
			if side > 0.0 and absf(x + M * 0.5) < 2.6:
				continue                         # посредине передней трибуны — проход и ложа
			# ступени поднимаются от дорожки наружу: у детали низ — у z = −6,23, верх — у z = −22,5 (x от −2,5 до 0)
			var kz := sd_d / 16.27
			var ys := sh / 5.18
			if side < 0.0:
				_put(b, "SM_Bld_Amphitheatre_End_01", Transform3D(Basis.from_scale(Vector3(1.0, ys, kz)), Vector3(x + M, 0.5 * ys - 0.1, zi + 6.23 * kz)))
			else:
				_put(b, "SM_Bld_Amphitheatre_End_01", Transform3D(Basis(Vector3.UP, PI) * Basis.from_scale(Vector3(1.0, ys, kz)), Vector3(x, 0.5 * ys - 0.1, zi - 6.23 * kz)))
		var zo := side * (tw + 0.2 + sd_d)
		for i in int((2.0 * L) / 5.0):
			var x := -L + i * 5.0
			var yaw := 0.0 if side > 0.0 else PI
			var p := Vector3(x if side > 0.0 else x + 5.0, 0, zo)
			if side > 0.0 and absf(x + 2.5) < 2.6:
				_put(b, "SM_Bld_Wall_Door_Double_Large_01", Transform3D(Basis.from_scale(Vector3(2.0, (sh + 0.6) / 3.01, 1.0)), p), TRAV)
				continue
			for j in 2:
				var pj := p + Basis(Vector3.UP, yaw) * Vector3(j * M, 0, 0)
				_put(b, "SM_Bld_Wall_Door_Double_Large_01", Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(1.0, (sh + 0.6) / 3.01, 1.0)), pj), TRAV)
		CatMonuments._box(b, "#dark", Vector3(0, (sh + 0.5) / 2.0, zo - side * 0.42), Vector3(2.0 * L - 0.2, sh + 0.5, 0.3))   # за арками — темно
		CatMonuments._run(b, "SM_Bld_Wall_Large_Cap_01", Vector3(-L if side > 0.0 else L, sh + 0.55, zo), Vector3(side, 0, 0), 2.0 * L, 5.0, 1.0, 0.9)
		# навесы: полосатые полотнища над верхними рядами, через одно — шафран
		for i in int((2.0 * L) / 5.1):
			var x := -L + 2.55 + i * 5.1
			if side > 0.0 and absf(x) < 3.0:
				continue
			var by := Basis(Vector3.UP, 0.0 if side < 0.0 else PI)
			_put(b, "SM_Prop_Banner_Roof_02", Transform3D(by * Basis(Vector3.RIGHT, -0.25), Vector3(x, sh + 1.6, zo - side * 1.0) - by * Vector3(2.55, 0, 0)), {} if i % 2 == 0 else CatMonuments.VELA_SAFFRON)
		for i in 5:
			var x := -L + 4.0 + i * (2.0 * L - 8.0) / 4.0
			CatShops._pole(b, Vector3(x, sh, zo - side * 0.2), 2.6)
			b.add("SM_Prop_Banner_03_B", Vector3(x, sh + 2.3, zo - side * 0.08), 0.0 if side > 0.0 else PI, 0.6)
	# ложа посредине передней трибуны: помост, четыре колонны, фронтон, пурпурные знамёна
	var lz := tw + 1.4
	CatMonuments._box(b, "#marble", Vector3(0, 0.6, lz + 0.6), Vector3(4.6, 1.2, 2.6))
	var keep := b.base
	b.base = keep * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 1.2, lz + 0.2))
	CatCivic._pediment(b, -1.8, 1.8, 0.0, -1.6, "SM_Bld_Pillar_02", 3.0, 0.8, 4, 0.9, 0.0)
	b.add("SM_Prop_Seat_Kline_01", Vector3(0, 0, -1.0), 0.0, 0.8)
	b.base = keep
	for sd: float in [-1.0, 1.0]:
		b.add("SM_Prop_Banner_03_B", Vector3(sd * 1.8, 1.0, lz - 0.25), PI, 0.6)
	# стартовые ворота: шесть арок между двумя башнями, у ворот — колесницы
	var gx := -L - 1.0
	for i in 6:
		var z := -tw + 0.7 + i * (2.0 * tw - 1.4) / 5.0
		_put(b, "SM_Bld_Wall_Door_Double_01", Transform3D(Basis(Vector3.UP, PI / 2) * Basis.from_scale(Vector3(1.4 / M, 1.0, 1.0)), Vector3(gx, 0, z + 0.7)), TRAV)
	CatMonuments._box(b, "#dark", Vector3(gx - 1.0, 1.5, 0), Vector3(1.8, 3.0, 2.0 * tw))
	for sd: float in [-1.0, 1.0]:
		var tz := sd * (tw + 1.2)
		CatCivic._box(b, gx - 0.6, tz, 1, 1, [{0: ["SM_Bld_Wall_Window_06"], 1: ["SM_Bld_Wall_01"], 2: ["SM_Bld_Wall_01"], 3: ["SM_Bld_Wall_01"]},
			{0: ["SM_Bld_Wall_Window_06"], 1: ["SM_Bld_Wall_Window_06"], 2: ["SM_Bld_Wall_01"], 3: ["SM_Bld_Wall_Window_06"]}], {"skin": sk[0], "trim_skin": sk[1], "trim": "SM_Bld_Trim_02"})
		b.remap = sk[0]
		CatCivic._hip(b, gx - 0.6 - 1.4, gx - 0.6 + 1.4, tz - 1.4, tz + 1.4, 2 * FL, 1.3)
	CatMonuments._run(b, "SM_Bld_Wall_Large_Cap_01", Vector3(gx, 3.05, tw), Vector3(0, 0, -1), 2.0 * tw, 5.0, 0.8, 0.9)
	for z: float in [-2.3, 2.3]:
		b.add_xf("SM_Prop_Cart_01", Transform3D(Basis(Vector3.UP, PI / 2).scaled(Vector3.ONE * 0.62), Vector3(-L + 1.6, 0, z)))
	# полукруглый конец: стена по дуге с воротами на оси, статуи на тумбах
	var R := tw + 0.3
	var kc := b.base
	b.base = kc * Transform3D(Basis.IDENTITY, Vector3(L, 0, 0))
	for i in 8:
		var ang := (i + 0.5) * PI / 8.0
		var nm := "SM_Bld_Wall_Door_Double_Large_01" if i == 3 or i == 4 else "SM_Bld_Wall_01"
		CatMonuments._ring_put(b, nm, ang, R, 0.0, 2.0 * R * tan(PI / 16.0) + 0.05, 2.5, 1.0, 1.0, TRAV if i == 3 or i == 4 else sk[1])
	b.add("SM_Prop_Plinth_04", Vector3(R + 1.0, 0, -2.2), 0.0, 0.9)
	CatMonuments._statue(b, Vector3(R + 1.0, 0.61, -2.2), PI / 2, 0.75, 4)
	b.base = kc
	b.door = Vector3(0, 0, tw + 0.2 + sd_d + 1.2)
	b.actor(Vector3(-L + 2.8, 0, 1.2), -PI / 2, "Idle", "pleb")
	b.actor(Vector3(-L + 2.8, 0, -1.3), -PI / 2 + 0.4, "Interact", "pleb")
	b.actor(Vector3(-2.0, 0.8, 0.0), 0.0, "Spell_Simple_Idle", "any")
	b.actor(Vector3(0, 0, tw + 0.2 + sd_d + 0.6), PI, "Idle", "pleb")
	b.actor(Vector3(1.6, 1.2, lz + 0.4), PI, "Idle", "rich")
	b.actor(Vector3(-1.6, 1.2, lz + 0.4), PI + 0.3, "Idle_Talking", "rich")
