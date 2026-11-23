class_name Land
extends RefCounted
## Земля игры: карта 384×384 м из клеток по 25 см с уступами по 12,5 см (как в Town to City).
## Середина 256×256 м — своя земля с начала: мягкие холмы, луга, леса пятнами, пруды. С севера из-за
## горизонта приходит большая мощёная дорога: через край карты, через арку на въезде на свою землю — к
## почтовой станции; по ней приезжают повозки. Вокруг — кольцо дорогих участков по 64 м, а дальше до
## горизонта — тот же пейзаж (его рисует игра, высоты — far_height). Каждая клетка помнит, какая постройка
## на ней стоит (occ): постройки занимают землю своей настоящей формой, а не прямоугольником.
## Высоты хранятся «как есть», а читаются ступеньками по 12,5 см (hq).

const CELL := 0.25
const SIZE := 384.0
const N := 1536
const STEP := 0.125
const BASE_Y := 2.0
const WATER_Y := 1.0
const SEA_Y := WATER_Y
const EDGE_Y := 4.5                 # средняя высота пейзажа за краем карты (дальние холмы и горы — от неё)
const CH := 64                      # клеток в куске сетки (16 м)
const CHN := N / CH
const PLOT := 64.0                  # участок земли
const PLOTS := 6
const START_PLOTS := Rect2i(2, 1, 2, 3)   # своя земля новой игры: участки x 2–3, z 1–3 (x 128–256, z 64–256 м)
const OLD_PLOTS := 16                    # столько своей земли давали с начала прежде (4×4): купленные — сверх них
const ROAD_X := 192.0                    # большая дорога идёт с севера вдоль x = 192
const ROAD_R := 2.25                     # её полуширина (4,5 м — шире улиц города)
const TUNNEL := Vector2(ROAD_X, 0.5)     # где большая дорога входит на карту (старое имя — повозки и уходящие семьи)
const EDGE_ROAD := TUNNEL
const GATE := Vector2(ROAD_X, 64.0)      # арка на въезде на свою землю (граница участков)
const HILL := GATE                       # (старое имя: у арки нет скал)
const CENTER := Vector2(185.0, 99.0)     # почтовая станция
const START := Vector2(192.0, 150.0)     # середина своей земли
const PONDS := [[Vector3(215.0, 150.0, 7.5)], [Vector3(130.0, 182.0, 13.0)], [Vector3(260.0, 214.0, 11.0)],
	[Vector3(176.0, 262.0, 17.0)], [Vector3(102.0, 124.0, 9.0)], [Vector3(338.0, 300.0, 22.0)], [Vector3(40.0, 250.0, 16.0)]]
const SM := 2                       # маска покрытий — по 2×2 клетки

enum Kind { GRASS, DIRT, ROCK, SAND, ROAD, PLAZA, YARD, FIELD }

var h := PackedFloat32Array()        # высоты (без ступенек)
var kind := PackedByteArray()
var tint := PackedByteArray()        # 0…255 — оттенок травы пятнами
var occ := PackedInt32Array()        # id постройки на клетке (0 — свободно)
var base_h := PackedFloat32Array()   # исходная карта — для сохранения только изменений
var base_kind := PackedByteArray()
var owned := {}                      # Vector2i участка → true
var dirty := {}                      # Vector2i куска → true (перестроить сетку: поменялись видимые уступы)
var dirty_soft := {}                 # куски, где поменялось только покрытие (стенки уступов) — сетку можно и позже
var dirty_walk := {}                 # куски, где поменялось покрытие или высота — сетка ходьбы жителей
var gen := 0                         # счётчик правок земли (клетки, занятость): запасы проверок места сверяются с ним
var mask_lo := Vector2i(1 << 30, 1 << 30)   # прямоугольник маски покрытий (пиксели N/SM), который надо обновить
var mask_hi := Vector2i(-1, -1)
var road_chunks := {}                # куски, где есть дороги (для маски покрытий и сетки ходьбы)
## Утоптанная земля у домов и лавок (окантовка из глины, 0…255 на клетку): не сохраняется — считается по постройкам
## (City.apron_all при загрузке, City.place / remove по ходу). Видна только на траве: дороги, площади, поля, вода — как были
var wear := PackedByteArray()
var wear_chunks := {}                # куски, где есть окантовка (маска покрытий собирается и для них)
var wear_block := {}                 # id построек с бордюром (домус, храм, пантеон): глина соседей не заходит за их стены в сад
## Этап 5.7–5.8: узор земли и улучшенные дороги — свой слой поверх покрытий (сохраняется отдельно: старые сохранения
## без него — как были). deco[k]: биты GMASK — кисть «Земля» на траве (Defs.GROUND: 1 сочная трава … 5 гравий);
## бит UP — улучшенная мостовая (каменные плиты) или площадь (травертин с мозаикой)
const UP := 8
const GMASK := 7
## Варианты дороги: в kind остаётся класс ходьбы, в deco — материал. Старые номера не меняются.
const COBBLE := 16
const FOOTPATH := 32
const ROAD_STYLE := COBBLE | FOOTPATH
const ROAD_COBBLE := 16
const ROAD_FOOTPATH := 17
var road_style_n := 0


## 15.11: маска травы — кисти «Трава» и «Убрать траву» (GrassCarpet): клетка 1 м, 0 — как само растёт, 1 — посажено
## (густо, с цветами), 2 — убрано. Сохраняется сжатой строкой (gmask); в старых сохранениях её нет
const GM_N := 384
var grass_mask := PackedByteArray()
var gm_count := 0                    # сколько клеток с кистью (0 — в сохранение ничего не пишем)
var _gm_enc := ""                    # сохранение маски: пересчитывается только после правки
var _gm_dirty := true
var deco := PackedByteArray()
var deco_cells := {}                 # клетка → true, где узор есть (сохранение без перебора всей карты)
var deco_chunks := {}                # куски, где узор был (маска узора собирается только по ним)
var up_n := 0                        # клеток улучшенной дороги (0 — «ухоженных улиц» нет, шейдер их не рисует)
var ground_n := 0                    # клеток с узором «Земли»
var deco_ver := 0                    # растёт с каждой правкой узора («ухоженная улица» у домов — City)
var walk_ver := 0                    # растёт, когда меняется покрытие клетки или занятость (тот же кэш «ухоженной улицы»)
var deco_lo := Vector2i(1 << 30, 1 << 30)   # прямоугольник маски узора (пиксели N/SM), который надо обновить
var deco_hi := Vector2i(-1, -1)
var _deco_enc := []                  # готовые строки сохранения узора; пусто — собрать заново из кусков
var _dc_dirty := {}                  # кусок → true: узор поменялся после того, как кусок посчитан для сохранения
var _dc_cells := {}                  # кусок → клетки с узором (PackedInt32Array) и их значения (PackedByteArray)
var _dc_vals := {}
## Клетки под арками акведука (этап 5.6): клетка → id постройки. Землю они не занимают (под арками ходят и проводят
## улицы), но другая постройка и деревья сквозь арки не встают. Не сохраняется — City.place / remove / load_data
var under := {}
## Клетки внутри построек (15.11, владелец: «внутри построек трава»): прямоугольник вокруг следа каждой постройки —
## двор, комнаты за проёмами — трава-ковёр там не растёт. Число построек на клетке; не сохраняется — City._bare_add / remove
var bare := PackedByteArray()
## Ручьи (13.11, scripts/streams.gd): какие проложены (номера Streams.LIST) — пишется в сохранение; streams_saved — что
## пришло из сохранения (null — сохранение старше ручьёв: тогда кладутся только те, где всё свободно); bridges — мосты
## там, где ручей проходит под дорогой исходной карты (не сохраняются — считаются заново)
var streams: Array = []
var streams_saved = null
var bridges: Array = []
## Видимая земля под мостами: у дороги над рекой клетки остаются насыпью для ходьбы (высота h — дорога), а
## рисуется русло — чтобы под арками текла вода. Клетка → высота дна; не сохраняется (Streams.apply)
var vis_h := {}
var bridge_road_chunks := {}
var vis_lo := Vector2i(1 << 30, 1 << 30)       # рамка клеток vis_h: узлы вне неё не проверяются (быстро)
var vis_hi := Vector2i(-1, -1)
## Новая карта лугов (13.11): мельницы и поля на дальних окраинах — только у городов, начатых после этой правки
var meadow_new := false

var n1 := FastNoiseLite.new()
var n2 := FastNoiseLite.new()
var n3 := FastNoiseLite.new()


func _init() -> void:
	n1.seed = 11
	n1.frequency = 0.011
	n1.fractal_octaves = 4
	n2.seed = 23
	n2.frequency = 0.06
	n3.seed = 37
	n3.frequency = 0.02
	generate()


func idx(i: int, j: int) -> int:
	return j * N + i


func inside(i: int, j: int) -> bool:
	return i >= 0 and j >= 0 and i < N and j < N


func cell(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x / CELL), 0, N - 1), clampi(int(p.y / CELL), 0, N - 1))


func cell_center(i: int, j: int) -> Vector2:
	return Vector2((i + 0.5) * CELL, (j + 0.5) * CELL)


## Высота клетки ступеньками по 12,5 см
func hq(k: int) -> float:
	return roundf(h[k] / STEP) * STEP


func height_at(x: float, z: float) -> float:
	var c := cell(Vector2(x, z))
	return hq(idx(c.x, c.y))


func kind_at(x: float, z: float) -> int:
	var c := cell(Vector2(x, z))
	return kind[idx(c.x, c.y)]


func occ_at(p: Vector2) -> int:
	var c := cell(p)
	return occ[idx(c.x, c.y)]


func plot_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x / PLOT), 0, PLOTS - 1), clampi(int(p.y / PLOT), 0, PLOTS - 1))


func is_owned(p: Vector2) -> bool:
	return owned.has(plot_of(p))


func is_water(p: Vector2) -> bool:
	return height_at(p.x, p.y) < WATER_Y + 0.05


## Крутой обрыв (скала) — перепад к соседу от 50 см
func is_rock(k: int) -> bool:
	var i := k % N
	var j := k / N
	var y := hq(k)
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if inside(i + d.x, j + d.y) and absf(y - hq(idx(i + d.x, j + d.y))) >= 0.5:
			return true
	return false


static func road_base(kd: int) -> int:
	return Kind.ROAD if kd == ROAD_COBBLE else (Kind.DIRT if kd == ROAD_FOOTPATH else kd)


static func road_style(kd: int) -> int:
	return COBBLE if kd == ROAD_COBBLE else (FOOTPATH if kd == ROAD_FOOTPATH else 0)


static func painted_kind(kd: int, dv: int) -> int:
	if kd == Kind.ROAD and (dv & COBBLE) != 0:
		return ROAD_COBBLE
	if kd == Kind.DIRT and (dv & FOOTPATH) != 0:
		return ROAD_FOOTPATH
	return kd


func road_kind(k: int) -> int:
	return painted_kind(kind[k], deco[k])


static func walk_kind(kd: int) -> bool:
	return kd == Kind.ROAD or kd == Kind.PLAZA or kd == Kind.DIRT or kd == ROAD_COBBLE or kd == ROAD_FOOTPATH


## Дорога (мостовая, площадь, тропа) без построек
func is_road(p: Vector2) -> bool:
	var c := cell(p)
	var k := idx(c.x, c.y)
	return walk_kind(kind[k]) and occ[k] == 0


# ---------- рельеф ----------

## Мягкие холмы (без дороги, прудов и края): на своей земле у станции почти ровно, дальше — выше
func _relief(x: float, z: float) -> float:
	var ds := maxf(absf(x - START.x) - 40.0, absf(z - START.y) - 40.0)
	var amp := lerpf(0.3, 2.4, smoothstep(0.0, 70.0, ds))
	var y := BASE_Y + 0.4 + n1.get_noise_2d(x, z) * amp + n3.get_noise_2d(x, z) * amp * 0.25
	y += smoothstep(80.0, 150.0, ds) * (2.0 + n3.get_noise_2d(x * 0.5, z * 0.5) * 3.0)
	return y


var _road_prof := PackedFloat32Array()


## Высота большой дороги на z: плавно по холмам (среднее по ±24 м), у арки и станции — ровно
func road_y(z: float) -> float:
	if _road_prof.is_empty():
		_road_prof.resize(int(SIZE) + 1)
		for zi in _road_prof.size():
			var s := 0.0
			for k in range(-4, 5):
				s += _relief(ROAD_X, zi + k * 6.0)
			_road_prof[zi] = s / 9.0
		# площадка у арки — ровная
		var yg := _road_prof[int(GATE.y)]
		for zi in _road_prof.size():
			_road_prof[zi] = lerpf(_road_prof[zi], yg, 1.0 - smoothstep(6.0, 16.0, absf(zi - GATE.y)))
	var zc := clampf(z, 0.0, SIZE)
	var i0 := mini(int(zc), _road_prof.size() - 2)
	var y := lerpf(_road_prof[i0], _road_prof[i0 + 1], zc - i0)
	return lerpf(y, BASE_Y + 0.4, smoothstep(72.0, 96.0, z))


func raw_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var y := _relief(x, z)
	# большая дорога с края карты к станции: поперёк ровная, вдоль — плавно по холмам; склоны мягко к ней
	var dx := absf(x - ROAD_X)
	if dx < ROAD_R + 14.0 and z < 140.0:
		var corridor := (1.0 - smoothstep(ROAD_R + 1.0, ROAD_R + 13.0, dx)) * (1.0 - smoothstep(130.0, 140.0, z))
		y = lerpf(y, road_y(z), corridor)
	# у арки — ровная площадка пошире
	y = lerpf(y, road_y(GATE.y), 1.0 - smoothstep(7.0, 14.0, p.distance_to(GATE)))
	y = lerpf(y, BASE_Y + 0.4, 1.0 - smoothstep(10.0, 18.0, p.distance_to(CENTER + Vector2(3, 0))))
	# пруды
	for pd in PONDS:
		var c: Vector3 = pd[0]
		var r := c.z * (1.0 + n2.get_noise_2d(x * 0.8, z * 0.8) * 0.18)
		var d := p.distance_to(Vector2(c.x, c.y))
		if d < r + 3.0:
			y = lerpf(y, WATER_Y - 0.9, 1.0 - smoothstep(r * 0.55, r, d))
			y = lerpf(y, maxf(minf(y, WATER_Y + 0.35), WATER_Y + 0.15), (1.0 - smoothstep(r, r + 2.5, d)) * smoothstep(r * 0.55, r, d))
	# у края карты — просто холмы (они же продолжаются за краем: far_height), без низин с водой
	var edge := minf(minf(x, SIZE - x), minf(z, SIZE - z))
	y = lerpf(y, _edge_relief(x, z), 1.0 - smoothstep(0.0, 22.0, edge))
	return y


## Холмы у края карты и сразу за ним — одни и те же (шва нет), но не ниже луга у воды
func _edge_relief(x: float, z: float) -> float:
	return maxf(_relief(x, z), WATER_Y + 0.5)


func generate() -> void:
	# высоты — по сетке 1 м, потом растягиваем на клетки 25 см (быстро, средствами движка)
	var M := int(SIZE) + 1
	var coarse := PackedFloat32Array()
	coarse.resize(M * M)
	for j in M:
		for i in M:
			coarse[j * M + i] = raw_height(float(i), float(j))
	var img := Image.create_from_data(M, M, false, Image.FORMAT_RF, coarse.to_byte_array())
	img.resize(N, N, Image.INTERPOLATE_BILINEAR)
	h = img.get_data().to_float32_array()
	kind.resize(N * N)
	kind.fill(Kind.GRASS)
	occ.resize(N * N)
	occ.fill(0)
	wear.resize(N * N)
	wear.fill(0)
	wear_chunks.clear()
	wear_block.clear()
	deco.resize(N * N)
	deco.fill(0)
	deco_cells.clear()
	deco_chunks.clear()
	up_n = 0
	ground_n = 0
	road_style_n = 0
	_deco_enc = []
	_dc_dirty.clear()
	_dc_cells.clear()
	_dc_vals.clear()
	under.clear()
	bare.resize(N * N)
	bare.fill(0)
	var tn := FastNoiseLite.new()
	tn.seed = 5
	tn.frequency = 0.035
	tn.fractal_octaves = 3
	tint = tn.get_image(N, N, false, false, true).get_data()
	# большая дорога с края карты через арку мимо станции и площадь перед станцией
	paint_line(Vector2(ROAD_X, 0.1), Vector2(ROAD_X, 106.0), ROAD_R, Kind.ROAD, true)
	paint_line(Vector2(ROAD_X, 104.0), Vector2(ROAD_X, 128.0), 1.7, Kind.ROAD, true)
	for z in range(92, 106):
		paint_line(Vector2(187.5, z + 0.5), Vector2(190.0, z + 0.5), 0.6, Kind.PLAZA, true)
	# своя земля с начала: середина 4×4 участка (256×256 м) — у готового города меню и витрины;
	# новая игра берёт меньше (own_start), старые сохранения — свою (load_changes)
	for dj in range(1, 5):
		for di in range(1, 5):
			owned[Vector2i(di, dj)] = true
	base_h = h.duplicate()
	base_kind = kind.duplicate()
	dirty.clear()
	dirty_soft.clear()
	dirty_walk.clear()
	touched.clear()
	_save_dirty.clear()


## Своя земля новой игры — START_PLOTS (2×3 участка, ~24,6 тыс. м²): остальное покупается
func own_start() -> void:
	owned.clear()
	for j in range(START_PLOTS.position.y, START_PLOTS.end.y):
		for i in range(START_PLOTS.position.x, START_PLOTS.end.x):
			owned[Vector2i(i, j)] = true


# ---------- пейзаж за краем карты ----------

var _far_n: FastNoiseLite


## Высота земли за краем карты (её рисует игра до горизонта): у края — те же холмы, что на карте (_edge_relief,
## шва нет), дальше — большие холмы и горы в дымке. Вдоль большой дороги на север — пологая долина, дорога поперёк
## ровная, первые 60 м за краем — на высоте дороги у края (по ней едут повозки и уходят семьи: Land.height_at
## за краем отдаёт высоту крайней клетки — она та же)
func far_height(x: float, z: float) -> float:
	if _far_n == null:
		_far_n = FastNoiseLite.new()
		_far_n.seed = 3
		_far_n.frequency = 0.004
		_far_n.fractal_octaves = 3
	var dx := maxf(maxf(-x, x - SIZE), 0.0)
	var dz := maxf(maxf(-z, z - SIZE), 0.0)
	var d := sqrt(dx * dx + dz * dz)
	var hills := EDGE_Y + smoothstep(0.0, 220.0, d) * (5.0 + _far_n.get_noise_2d(x, z) * 22.0) + smoothstep(500.0, 1400.0, d) * 55.0
	var y := lerpf(_edge_relief(x, z) if d < 260.0 else hills, hills, smoothstep(30.0, 260.0, d))
	if z < 0.0:
		var rd := absf(x - ROAD_X)
		if rd < ROAD_R + 60.0:
			var y0 := roundf(_edge_relief(ROAD_X, 0.0) / STEP) * STEP
			var far := EDGE_Y + (5.0 + _far_n.get_noise_2d(ROAD_X, z) * 22.0) * 0.35 * smoothstep(0.0, 220.0, -z) + smoothstep(500.0, 1400.0, -z) * 55.0
			var ry := lerpf(y0, far, smoothstep(60.0, 420.0, -z))
			var w := 1.0 - smoothstep(ROAD_R + 1.5, ROAD_R + 4.0 + 50.0 * smoothstep(0.0, 400.0, -z), rd)
			y = lerpf(y, ry, w)
	return Streams.far_carve(y, x, z)         # 15.11: долина реки (если она проложена в этом городе)


## Клетка поменялась. mesh — поменялся видимый уступ (12,5 см): сетку куска перестроить; mask — поменялось
## покрытие: маска для шейдера (и стенки уступов — сетка «потом», dirty_soft). Ни то ни другое — только для сохранения
func _mark(i: int, j: int, mesh := true, mask := true, changes_walk := true) -> void:
	gen += 1
	var ci := clampi(i / CH, 0, CHN - 1)
	var cj := clampi(j / CH, 0, CHN - 1)
	var ch := Vector2i(ci, cj)
	touched[ch] = true
	_save_dirty[ch] = true
	dirty_walk[ch] = true
	if mask:
		walk_ver += int(changes_walk)
		var mi := i / SM
		var mj := j / SM
		if mi < mask_lo.x:
			mask_lo.x = mi
		if mj < mask_lo.y:
			mask_lo.y = mj
		if mi > mask_hi.x:
			mask_hi.x = mi
		if mj > mask_hi.y:
			mask_hi.y = mj
	if not mesh:
		if mask:
			dirty_soft[ch] = true
		return
	dirty[ch] = true
	# стенки уступов на краю куска рисует соседний кусок
	if i % CH == 0 and i > 0:
		dirty[Vector2i((i - 1) / CH, cj)] = true
	if j % CH == 0 and j > 0:
		dirty[Vector2i(ci, (j - 1) / CH)] = true
	if i % CH == CH - 1 and i < N - 1:
		dirty[Vector2i((i + 1) / CH, cj)] = true
	if j % CH == CH - 1 and j < N - 1:
		dirty[Vector2i(ci, (j + 1) / CH)] = true


# ---------- кисть дорог ----------

## Покрасить клетки в круге (square — квадрат) радиуса r. over — рисовать поверх других дорог.
## seen — мазок кисти игрока (game.gd): высоты сразу не сглаживаются (smooth_cells — один раз, когда кнопку отпустили,
## так мазок по склону не тормозит), и клетка, уже взятая этим мазком, второй раз не записывается.
## Без seen — как раньше: дорога сглаживается сразу
func paint_circle(p: Vector2, r: float, kd: int, flat := false, only_owned := true, square := false, over := true, seen = null) -> Array:
	var out := []
	var base := road_base(kd)
	var c := cell(p)
	var rc := int(ceil(r / CELL))
	var y0 := height_at(p.x, p.y)
	var defer: bool = seen != null
	# своя ли земля — один раз на всю кисть, если она целиком на одном участке
	var own_all := -1                         # -1 — смотреть каждую клетку, 1 — вся кисть на своей земле
	if only_owned:
		var pa := plot_of(p - Vector2(r, r))
		if pa == plot_of(p + Vector2(r, r)):
			if not owned.has(pa):
				return out
			own_all = 1
	var r2 := r * r
	for j in range(c.y - rc, c.y + rc + 1):
		for i in range(c.x - rc, c.x + rc + 1):
			if not inside(i, j):
				continue
			var q := cell_center(i, j)
			if square:
				if absf(q.x - p.x) > r or absf(q.y - p.y) > r:
					continue
			elif q.distance_squared_to(p) > r2:
				continue
			if own_all < 0 and only_owned and not is_owned(q):
				continue
			var k := idx(i, j)
			if defer and seen.has(k):
				continue
			var kk := road_kind(k)
			var y := hq(k)
			if y < WATER_Y + 0.05 or occ[k] != 0:
				continue
			if kd == Kind.GRASS and not walk_kind(kk):
				continue
			if kd != Kind.GRASS and walk_kind(kk) and kk != kd and not over:
				continue
			if kd != Kind.GRASS and kk == kd and (not flat or absf(y - y0) < 0.01):
				continue
			if flat and absf(y - y0) > 1.2:
				continue                         # обрыв кисть не срезает
			out.append([Vector2i(i, j), kind[k], h[k], deco[k]])
			if defer:
				seen[k] = true
			if kk != kd:
				set_deco(k, road_style(kd))                   # новое покрытие — без прежнего узора и улучшения
			kind[k] = base
			var mesh := false
			if flat and walk_kind(kd) and not defer:
				# дорога ложится по земле: только сглаживаем мелкие ступеньки вдоль неё, не поднимая над травой
				h[k] = _smooth_at(i, j, 3)
				mesh = hq(k) != y
			_mark(i, j, mesh, kk != kd)
			if walk_kind(kd):
				road_chunks[Vector2i(i / CH, j / CH)] = true
	return out


## Мазок окончен: дорога ложится по земле — сгладить мелкие ступеньки один раз по всем клеткам мазка (как _smooth_at)
func smooth_cells(cells: PackedInt32Array) -> void:
	for k in cells:
		var i := k % N
		var j := k / N
		var y0 := h[k]
		var sum := 0.0
		var n := 0
		var i0 := maxi(i - 3, 0)
		var i1 := mini(i + 3, N - 1)
		for jj in range(maxi(j - 3, 0), mini(j + 3, N - 1) + 1):
			var row := jj * N
			for ii in range(i0, i1 + 1):
				var y := h[row + ii]
				if y >= WATER_Y + 0.05 and absf(y - y0) < 0.5:   # обрывы и стены в среднее не берём
					sum += y
					n += 1
		if n == 0:
			continue
		var old := hq(k)
		h[k] = sum / n
		if hq(k) != old:
			_mark(i, j, true, false)
		else:
			touched[Vector2i(clampi(i / CH, 0, CHN - 1), clampi(j / CH, 0, CHN - 1))] = true
			_save_dirty[Vector2i(clampi(i / CH, 0, CHN - 1), clampi(j / CH, 0, CHN - 1))] = true


## Клетки прямой линии кисти от a до b — как мазок paint_circle по этой линии (те же проверки: своя земля, не вода,
## не под постройкой, «поверх других дорог», обрыв), но земля не меняется. Для показа дороги до отпускания кнопки
## и для неё же при отпускании: что показали — то и легло, по той же цене.
## {"cells": клетки по порядку вдоль линии, "fresh": 1 — покрытие поменяется (за неё платят), "t": доля пути 0…1}
## gk ≥ −1 — прямая кисти «Улучшить» (−1) / «Земля» (вид узора): те же клетки, что у brush_cells, за один проход (kd не нужен)
func line_cells(a: Vector2, b: Vector2, r: float, kd: int, square := false, over := true, gk := -2) -> Dictionary:
	var deco_line := gk >= -1
	var ab := b - a
	var l2 := ab.length_squared()
	var len := sqrt(l2)
	var flat := kd != Kind.GRASS
	var r2 := r * r
	var nb := int(len / 0.5) + 2              # по корзинам через 0,5 м вдоль линии — порядок для «денег хватит до сюда»
	var bk := []                              # обычные массивы: Packed* внутри Array копируются при каждом обращении
	bk.resize(nb)
	for i in nb:
		bk[i] = []
	var c0 := cell(a.min(b) - Vector2(r, r))
	var c1 := cell(a.max(b) + Vector2(r, r))
	var nrm := Vector2(-ab.y, ab.x).normalized() * r if len > 1e-4 else Vector2.ZERO
	for j in range(c0.y, c1.y + 1):
		var qy := (j + 0.5) * CELL
		var i0 := c0.x
		var i1 := c1.x
		if not square:
			# ряд пересекает капсулу одним отрезком: края — по двум кругам и двум сдвинутым сторонам
			var lo := INF
			var hi := -INF
			for e: Vector2 in [a, b]:
				var dy := qy - e.y
				if absf(dy) <= r:
					var dx := sqrt(r2 - dy * dy)
					lo = minf(lo, e.x - dx)
					hi = maxf(hi, e.x + dx)
			if len > 1e-4:
				for s: float in [-1.0, 1.0]:
					var p0 := a + nrm * s
					var p1 := b + nrm * s
					if absf(p1.y - p0.y) > 1e-6 and (qy - p0.y) * (qy - p1.y) <= 0.0:
						var x := p0.x + (qy - p0.y) / (p1.y - p0.y) * (p1.x - p0.x)
						lo = minf(lo, x)
						hi = maxf(hi, x)
			if lo > hi:
				continue
			i0 = maxi(c0.x, int(floor(lo / CELL)) - 1)
			i1 = mini(c1.x, int(floor(hi / CELL)) + 1)
		else:
			# квадрат по линии: ряд qy даёт отрезок t по оси y, по нему — края ряда по x (а не вся рамка линии)
			var tl := 0.0
			var th := 1.0
			if absf(ab.y) < 1e-6:
				if absf(qy - a.y) > r:
					continue
			else:
				var t1 := (qy - r - a.y) / ab.y
				var t2 := (qy + r - a.y) / ab.y
				tl = maxf(0.0, minf(t1, t2))
				th = minf(1.0, maxf(t1, t2))
				if tl > th:
					continue
			var xa := a.x + ab.x * tl
			var xb := a.x + ab.x * th
			i0 = maxi(c0.x, int(floor((minf(xa, xb) - r) / CELL)) - 1)
			i1 = mini(c1.x, int(floor((maxf(xa, xb) + r) / CELL)) + 1)
		for i in range(i0, i1 + 1):
			if not inside(i, j):
				continue
			var q := Vector2((i + 0.5) * CELL, qy)
			var t := 0.0
			if square:
				# квадрат, протянутый по линии: есть t, при котором |q − p(t)| по обеим осям ≤ r
				var tl := 0.0
				var th := 1.0
				var ok := true
				for ax in 2:
					var qa: float = q[ax]
					var aa: float = a[ax]
					var da: float = ab[ax]
					if absf(da) < 1e-6:
						if absf(qa - aa) > r:
							ok = false
					else:
						var t1 := (qa - r - aa) / da
						var t2 := (qa + r - aa) / da
						tl = maxf(tl, minf(t1, t2))
						th = minf(th, maxf(t1, t2))
				if not ok or tl > th:
					continue
				t = (tl + th) * 0.5
			else:
				if l2 > 1e-8:
					t = clampf((q - a).dot(ab) / l2, 0.0, 1.0)
				if q.distance_squared_to(a + ab * t) > r2:
					continue
			if deco_line:
				var kq := j * N + i
				if brush_ok(kq, q, gk):
					(bk[mini(nb - 1, int(t * len / 0.5))] as Array).append(kq)
				continue
			if not is_owned(q):
				continue
			var k := j * N + i
			var kk := road_kind(k)
			var y := hq(k)
			if y < WATER_Y + 0.05 or occ[k] != 0:
				continue
			var gd := not flat and (deco[k] & GMASK) != 0      # ластик: и узор «Земли» на траве
			if not flat and not walk_kind(kk) and not gd:
				continue
			if flat and walk_kind(kk) and kk != kd and not over:
				continue
			if flat:
				var pt := a + ab * t
				var y0 := height_at(pt.x, pt.y)
				if absf(y - y0) > 1.2:
					continue                     # обрыв кисть не срезает
				if kk == kd and absf(y - y0) < 0.01:
					continue
			var bi := mini(nb - 1, int(t * len / 0.5))
			(bk[bi] as Array).append(k if kk != kd or gd else -1 - k)     # отрицательное — клетка не меняется (за неё не платят)
	var cells := PackedInt32Array()
	var fresh := PackedByteArray()
	var ts := PackedFloat32Array()
	for bi in nb:
		var tv := float(bi) / maxf(1.0, nb - 1.0)
		for e: int in bk[bi]:
			cells.append(e if e >= 0 else -1 - e)
			fresh.append(1 if e >= 0 else 0)
			ts.append(tv)
	return {"cells": cells, "fresh": fresh, "t": ts}


## Клетки дороги под кистью ластика (своя земля, не под постройкой), ещё не взятые мазком seen — их уберут при отпускании
func erase_cells(p: Vector2, r: float, square := false, seen := {}) -> PackedInt32Array:
	var out := PackedInt32Array()
	var c := cell(p)
	var rc := int(ceil(r / CELL))
	var r2 := r * r
	for j in range(c.y - rc, c.y + rc + 1):
		for i in range(c.x - rc, c.x + rc + 1):
			if not inside(i, j):
				continue
			var q := cell_center(i, j)
			if square:
				if absf(q.x - p.x) > r or absf(q.y - p.y) > r:
					continue
			elif q.distance_squared_to(p) > r2:
				continue
			var k := j * N + i
			if seen.has(k) or not (walk_kind(kind[k]) or (deco[k] & GMASK) != 0) or occ[k] != 0 or hq(k) < WATER_Y + 0.05 or not is_owned(q):
				continue
			seen[k] = true
			out.append(k)
	return out


## Покрыть клетки видом kd (дорога по готовому списку line_cells, ластик); высоты не трогаем.
## Ластик (трава) стирает и узор «Земли», новое покрытие — прежний узор и улучшение.
## Возвращает записи для отмены [клетка, вид, высота, узор]
func apply_cells(cells: PackedInt32Array, kd: int) -> Array:
	var out := []
	for k in cells:
		var i := k % N
		var j := k / N
		var kk := road_kind(k)
		out.append([Vector2i(i, j), kind[k], h[k], deco[k]])
		if kk != kd or kd == Kind.GRASS:
			set_deco(k, road_style(kd))
		if kk != kd:
			kind[k] = road_base(kd)
			_mark(i, j, false, true)
		if walk_kind(kd):
			road_chunks[Vector2i(i / CH, j / CH)] = true
	return out


## Средняя высота вокруг клетки (радиус rc клеток) — для мягкой дороги по склону
func _smooth_at(i: int, j: int, rc: int) -> float:
	var sum := 0.0
	var n := 0
	var y0 := h[idx(i, j)]
	for dj in range(-rc, rc + 1):
		for di in range(-rc, rc + 1):
			if inside(i + di, j + dj):
				var y := h[idx(i + di, j + dj)]
				if y >= WATER_Y + 0.05 and absf(y - y0) < 0.5:   # обрывы и стены в среднее не берём
					sum += y
					n += 1
	return sum / n if n > 0 else h[idx(i, j)]


func paint_line(a: Vector2, b: Vector2, r: float, kd: int, flat := false) -> Array:
	var out := []
	var n := int(a.distance_to(b) / (CELL * 2.0)) + 1
	for s in n + 1:
		out.append_array(paint_circle(a.lerp(b, float(s) / n), r, kd, flat, false))
	return out


## Вернуть клетки как были (отмена мазка кисти). Клетки под постройками не трогаются: земля и мостовая под
## домом остаются такими, какими были, когда его ставили (иначе дом повис бы или земля проткнула бы пол).
## Возвращает номера записей, которые правда вернули
func undo(changes: Array) -> PackedInt32Array:
	var done := PackedInt32Array()
	# с конца: мазок по склону записывает одну клетку дважды (сперва трава, потом уже мостовая) — вернуть надо первое
	for n in range(changes.size() - 1, -1, -1):
		var ch: Array = changes[n]
		var c: Vector2i = ch[0]
		var k := idx(c.x, c.y)
		if occ[k] != 0:
			continue
		done.append(n)
		var old_hq := hq(k)
		var old_kd := kind[k]
		kind[k] = ch[1]
		h[k] = ch[2]
		if ch.size() > 3:
			set_deco(k, int(ch[3]))              # узор и улучшение — как были (этап 5.7–5.8)
		_mark(c.x, c.y, hq(k) != old_hq, old_kd != kind[k])
		if walk_kind(ch[1]):
			road_chunks[Vector2i(c.x / CH, c.y / CH)] = true
	return done


# ---------- узор земли и улучшенные дороги (этап 5.7–5.8) ----------

## Узор клетки k := v: счётчики, маска для шейдера, сохранение
func set_deco(k: int, v: int) -> void:
	var o := deco[k]
	if o == v:
		return
	if (o & UP) != 0:
		up_n -= 1
	if (v & UP) != 0:
		up_n += 1
	if (o & GMASK) != 0:
		ground_n -= 1
	if (v & GMASK) != 0:
		ground_n += 1
	if (o & ROAD_STYLE) != 0:
		road_style_n -= 1
	if (v & ROAD_STYLE) != 0:
		road_style_n += 1
	deco[k] = v
	if v == 0:
		deco_cells.erase(k)
	else:
		deco_cells[k] = true
	var i := k % N
	var j := k / N
	deco_chunks[Vector2i(i / CH, j / CH)] = true
	_dc_dirty[Vector2i(i / CH, j / CH)] = true
	deco_lo = deco_lo.min(Vector2i(i / SM, j / SM))
	deco_hi = deco_hi.max(Vector2i(i / SM, j / SM))
	deco_ver += 1
	_deco_enc = []


## Клетка — улучшенная дорога (мостовая из плит или площадь с травертином)
func is_up(k: int) -> bool:
	return (deco[k] & UP) != 0 and (kind[k] == Kind.ROAD or kind[k] == Kind.PLAZA)


## Клетки под кистью «Улучшить» (gk < 0) или «Земля» (gk — вид узора, 0 — обычная трава) в круге (квадрате) p, r:
## своя земля, не вода, не под постройкой, ещё не взятые мазком seen и ещё не такие.
## «Улучшить» берёт тропу (станет мостовой), мостовую и площадь без улучшения; «Земля» — траву (не дорогу)
func brush_cells(p: Vector2, r: float, square: bool, gk: int, seen: Dictionary) -> PackedInt32Array:
	var out := PackedInt32Array()
	var c := cell(p)
	var rc := int(ceil(r / CELL))
	var r2 := r * r
	for j in range(c.y - rc, c.y + rc + 1):
		for i in range(c.x - rc, c.x + rc + 1):
			if not inside(i, j):
				continue
			var q := cell_center(i, j)
			if square:
				if absf(q.x - p.x) > r or absf(q.y - p.y) > r:
					continue
			elif q.distance_squared_to(p) > r2:
				continue
			var k := j * N + i
			if seen.has(k) or not brush_ok(k, q, gk):
				continue
			seen[k] = true
			out.append(k)
	return out


## Клетка k (середина q) годится для кисти «Улучшить» (gk < 0) или «Земля» (gk ≥ 0): своя земля, не вода, не под
## постройкой и ещё не такая. Одна проверка у свободного мазка и у прямой линии — что показали, то и ляжет
func brush_ok(k: int, q: Vector2, gk: int) -> bool:
	if occ[k] != 0 or hq(k) < WATER_Y + 0.05 or not is_owned(q):
		return false
	var kd := kind[k]
	if gk < 0:
		return kd == Kind.DIRT or ((kd == Kind.ROAD or kd == Kind.PLAZA) and (deco[k] & UP) == 0)
	return kd == Kind.GRASS and (deco[k] & GMASK) != gk


## Доплата за клетку кисти «Улучшить»: тропа → мостовая, мостовая → плиты, площадь → травертин
func up_price(k: int) -> float:
	match kind[k]:
		Kind.DIRT:
			return float(Defs.ROAD_UP["path"])
		Kind.PLAZA:
			return float(Defs.ROAD_UP["plaza"])
	return float(Defs.ROAD_UP["road"])


## Кисть по готовым клеткам: «Улучшить» (gk < 0) — тропа становится мостовой, мостовая и площадь — улучшенными;
## «Земля» — узор gk (0 — трава). Высоты не трогаем. Возвращает записи для отмены [клетка, вид, высота, узор]
func brush_apply(cells: PackedInt32Array, gk: int) -> Array:
	var out := []
	for k in cells:
		var i := k % N
		var j := k / N
		out.append([Vector2i(i, j), kind[k], h[k], deco[k]])
		if gk >= 0:
			set_deco(k, (deco[k] & ~GMASK) | gk)
		elif kind[k] == Kind.DIRT:
			set_deco(k, deco[k] & ~ROAD_STYLE)
			kind[k] = Kind.ROAD
			_mark(i, j, false, true)
			road_chunks[Vector2i(i / CH, j / CH)] = true
		else:
			set_deco(k, (deco[k] & ~ROAD_STYLE) | UP)
	return out


## Маски узора для шейдера (по 2×2 клетки): [0] — RGBA доли кисти «Земля» (сочная трава, луг, песок, утоптанная земля),
## [1] — R гравий, G улучшенная дорога, B булыжник, A плиточная дорожка. Собираются только по кускам, где узор был
func make_deco_masks() -> Array:
	var a := Image.create(N / SM, N / SM, false, Image.FORMAT_RGBA8)
	var b := Image.create(N / SM, N / SM, false, Image.FORMAT_RGBA8)
	var s := CH / SM
	for ch: Vector2i in deco_chunks:
		for j in range(ch.y * s, ch.y * s + s):
			for i in range(ch.x * s, ch.x * s + s):
				_deco_px(a, b, i, j)
	deco_lo = Vector2i(1 << 30, 1 << 30)
	deco_hi = Vector2i(-1, -1)
	return [a, b]


## Обновить в масках узора только поменявшийся прямоугольник; false — нечего обновлять
func update_deco_masks(a: Image, b: Image) -> bool:
	if deco_hi.x < 0:
		return false
	for im: Image in [a, b]:
		if im.has_mipmaps():
			im.clear_mipmaps()
	var x0 := maxi(deco_lo.x, 0)
	var y0 := maxi(deco_lo.y, 0)
	var x1 := mini(deco_hi.x, N / SM - 1)
	var y1 := mini(deco_hi.y, N / SM - 1)
	deco_lo = Vector2i(1 << 30, 1 << 30)
	deco_hi = Vector2i(-1, -1)
	for j in range(y0, y1 + 1):
		for i in range(x0, x1 + 1):
			_deco_px(a, b, i, j)
	return true


func _deco_px(a: Image, b: Image, i: int, j: int) -> void:
	var k0 := (j * SM) * N + i * SM
	var c := Color(0, 0, 0, 0)
	var e := Color(0, 0, 0, 0)
	for k: int in [k0, k0 + 1, k0 + N, k0 + N + 1]:
		var v := deco[k]
		if v == 0:
			continue
		var kd := kind[k]
		match v & GMASK if kd == Kind.GRASS else 0:
			1: c.r += 0.25
			2: c.g += 0.25
			3: c.b += 0.25
			4: c.a += 0.25
			5: e.r += 0.25
		if (v & UP) != 0 and (kd == Kind.ROAD or kd == Kind.PLAZA):
			e.g += 0.25
		if kd == Kind.ROAD and (v & COBBLE) != 0:
			e.b += 0.25
		if kd == Kind.DIRT and (v & FOOTPATH) != 0:
			e.a += 0.25
	a.set_pixel(i, j, c)
	b.set_pixel(i, j, e)


## Узор для сохранения: [клетки, значения] строками base64. Куски считаются заранее (save_warm, как отличия земли) —
## здесь только склейка готового: большой город в плитах не дёргает кадр автосохранения
func _deco_save() -> Array:
	if _deco_enc.is_empty():
		for ch in _dc_dirty.keys():          # обычно пусто: save_warm уже посчитал
			_deco_chunk(ch)
		var cells := PackedInt32Array()
		var vals := PackedByteArray()
		for ch in _dc_cells:
			cells.append_array(_dc_cells[ch])
			vals.append_array(_dc_vals[ch])
		_deco_enc = [Marshalls.raw_to_base64(cells.to_byte_array()), Marshalls.raw_to_base64(vals)]
	return _deco_enc


## Клетки с узором одного куска (64×64) — для сохранения
func _deco_chunk(ch: Vector2i) -> void:
	var cells := PackedInt32Array()
	var vals := PackedByteArray()
	for j in range(ch.y * CH, ch.y * CH + CH):
		var row := j * N
		for i in range(ch.x * CH, ch.x * CH + CH):
			var v := deco[row + i]
			if v != 0:
				cells.append(row + i)
				vals.append(v)
	if cells.is_empty():
		_dc_cells.erase(ch)
		_dc_vals.erase(ch)
	else:
		_dc_cells[ch] = cells
		_dc_vals[ch] = vals
	_dc_dirty.erase(ch)


# ---------- постройки на земле ----------

## Клетки следа постройки: rects — прямоугольники в осях постройки, pos/yaw — где стоит
func footprint_cells(rects: Array, pos: Vector2, yaw: float, pad := 0.0) -> PackedInt32Array:
	var out := PackedInt32Array()
	var ax := Vector2(cos(yaw), -sin(yaw))
	var fw := Vector2(sin(yaw), cos(yaw))
	var single := rects.size() == 1
	var seen := {}
	for r: Rect2 in rects:
		var rr := r.grow(pad)
		var end := rr.end
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for cnr: Vector2 in [rr.position, rr.position + Vector2(rr.size.x, 0), rr.position + Vector2(0, rr.size.y), rr.end]:
			var w := pos + ax * cnr.x + fw * cnr.y
			lo = lo.min(w)
			hi = hi.max(w)
		var c0 := cell(lo)
		var c1 := cell(hi)
		for j in range(c0.y, c1.y + 1):
			var row := j * N
			for i in range(c0.x, c1.x + 1):
				var q := cell_center(i, j) - pos
				var lx := q.dot(ax)
				var lz := q.dot(fw)
				if lx >= rr.position.x and lx <= end.x and lz >= rr.position.y and lz <= end.y:
					var k := row + i
					if not single:
						if seen.has(k):
							continue
						seen[k] = true
					out.append(k)
	return out


## Клетки прямоугольника, что охватывает след постройки в её осях (двор, комнаты за проёмами, дворик между флигелями)
func hull_cells(cells: PackedInt32Array, pos: Vector2, yaw: float) -> PackedInt32Array:
	if cells.is_empty():
		return cells
	var ax := Vector2(cos(yaw), -sin(yaw))
	var fw := Vector2(sin(yaw), cos(yaw))
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for k in cells:
		var d := cell_center(k % N, k / N) - pos
		var l := Vector2(d.dot(ax), d.dot(fw))
		lo = lo.min(l)
		hi = hi.max(l)
	return footprint_cells([Rect2(lo, hi - lo)], pos, yaw, 0.02)


func set_occ(cells: PackedInt32Array, id: int) -> void:
	gen += 1
	for k in cells:
		occ[k] = id
	walk_ver += 1


## Выровнять клетки под постройкой на высоту y (вокруг остаются уступы — как подпорные стенки)
func flatten_cells(cells: PackedInt32Array, y: float, kd := -1) -> void:
	for k in cells:
		if hq(k) != y or (kd >= 0 and kind[k] != kd):
			var step := hq(k) != y
			var kch := kd >= 0 and kind[k] != kd
			var changes_walk := kch and walk_kind(kind[k]) != walk_kind(kd)
			h[k] = y
			if kd >= 0:
				if kind[k] != kd and (deco[k] & ROAD_STYLE) != 0:
					set_deco(k, deco[k] & ~ROAD_STYLE)
				kind[k] = kd
			_mark(k % N, k / N, step, kch, changes_walk)


## Земля вокруг постройки плавно подходит к её полу — без ям и ступенек (rc клеток вокруг)
func blend_ring(cells: PackedInt32Array, y: float, rc := 7) -> void:
	var seen := {}
	for k in cells:
		seen[k] = true
	var front := cells
	for step in range(1, rc + 1):
		front = _next_ring(front, seen)
		var t := 1.0 - float(step) / float(rc + 1)
		t = t * t * (3.0 - 2.0 * t)
		for k in front:
			if occ[k] != 0 or walk_kind(kind[k]) or h[k] < WATER_Y + 0.2:
				continue
			var ny := lerpf(h[k], y, t)
			if absf(ny - h[k]) > 0.01:
				var old := hq(k)
				h[k] = ny
				_mark(k % N, k / N, hq(k) != old, false)


const RING_STEPS := [1, -1, N, -N]


func _next_ring(front: PackedInt32Array, seen: Dictionary, stop_at_kerb := false) -> PackedInt32Array:
	var next := PackedInt32Array()
	for k in front:
		var col := k % N
		for offset: int in RING_STEPS:
			var other := k + offset
			if other < 0 or other >= N * N or seen.has(other):
				continue
			if (offset == 1 and col == N - 1) or (offset == -1 and col == 0):
				continue
			seen[other] = true
			if not stop_at_kerb or occ[other] == 0 or not wear_block.has(occ[other]):
				next.append(other)
	return next


# ---------- окантовка у домов: утоптанная глина (Town to City) ----------

const APRON_W := [255, 255, 240, 170, 80]   # по кольцам от стены (клетки 25 см): под постройкой и у стены — сплошь, дальше реже
const APRON_DOOR := 5                   # пятно у двери: радиус в клетках (1,25 м) — там ходят


## Окантовка вокруг следа постройки cells: кольца от стены (по четырём соседям) и пятно у двери door.
## Пишется наибольшее (соседние дома друг друга не стирают); маска покрытий обновится по прямоугольнику.
## Клетки построек с бордюром (wear_block) глина обходит: ни на них, ни сквозь них в сад домуса и двор храма
## Мостовая под большой постройкой (амфитеатр, цирк, форум, театр): весь след — площадь, чтобы между круглой
## постройкой и улицей вокруг не оставалось клочков травы; снесли — земля снова прежняя (base_kind)
## to — чем покрыть (по умолчанию площадь; под ареной цирка — песок: владелец 14.11 — «под цирком стала площадь»)
func pave_under(cells: PackedInt32Array, on: bool, to := Kind.PLAZA) -> void:
	for k in cells:
		var kd: int = to if on else int(base_kind[k])
		if on and not (int(kind[k]) in [Kind.GRASS, Kind.DIRT, Kind.SAND, Kind.YARD]):
			continue
		if not on and int(kind[k]) != to:
			continue
		if int(kind[k]) != kd:
			if (deco[k] & ROAD_STYLE) != 0:
				set_deco(k, deco[k] & ~ROAD_STYLE)
			kind[k] = kd
			_mark(k % N, k / N, true, true)


## Покрытие под постройкой, возле которой проложили дорогу (15.11, отзыв владельца: «под первым зданием — дыры голой земли»):
## кисть обходит клетки под домами и украшениями, и вокруг стен и мелочи у порога оставались клочки травы и глины.
## Клетки следа — тем же покрытием (трава, земля, песок, двор), высота не меняется; снесли постройку — мостовая остаётся
func pave_beneath(cells: PackedInt32Array, kd: int) -> int:
	var n := 0
	for k in cells:
		var kk := int(kind[k])
		if road_kind(k) == kd or not (kk in [Kind.GRASS, Kind.DIRT, Kind.SAND, Kind.YARD]) or hq(k) < WATER_Y + 0.05:
			continue
		kind[k] = road_base(kd)
		if road_style(kd) != 0 or (deco[k] & ROAD_STYLE) != 0:
			set_deco(k, road_style(kd))
		_mark(k % N, k / N, false, true)
		road_chunks[Vector2i((k % N) / CH, (k / N) / CH)] = true
		n += 1
	return n


func wear_stamp(cells: PackedInt32Array, door := Vector2.INF) -> void:
	if cells.is_empty():
		return
	var seen := {}
	var front := cells
	var i0 := N
	var j0 := N
	var i1 := -1
	var j1 := -1
	for k in cells:
		seen[k] = true
		wear[k] = 255
		var ci := k % N
		var cj := k / N
		i0 = mini(i0, ci)
		j0 = mini(j0, cj)
		i1 = maxi(i1, ci)
		j1 = maxi(j1, cj)
	for st in range(1, APRON_W.size()):
		var w: int = APRON_W[st]
		front = _next_ring(front, seen, true)
		for k in front:
			if wear[k] < w:
				wear[k] = w
	var R := APRON_W.size() - 1
	i0 -= R
	j0 -= R
	i1 += R
	j1 += R
	if door != Vector2.INF:
		var dc := cell(door)
		for dj in range(-APRON_DOOR, APRON_DOOR + 1):
			for di in range(-APRON_DOOR, APRON_DOOR + 1):
				var d := sqrt(float(di * di + dj * dj))
				if d > APRON_DOOR or not inside(dc.x + di, dc.y + dj):
					continue
				var w := int(255.0 * clampf(1.2 - d / APRON_DOOR, 0.0, 1.0))
				var k2 := idx(dc.x + di, dc.y + dj)
				if occ[k2] != 0 and wear_block.has(occ[k2]):
					continue
				if wear[k2] < w:
					wear[k2] = w
		i0 = mini(i0, dc.x - APRON_DOOR)
		j0 = mini(j0, dc.y - APRON_DOOR)
		i1 = maxi(i1, dc.x + APRON_DOOR)
		j1 = maxi(j1, dc.y + APRON_DOOR)
	_wear_dirty(i0, j0, i1, j1)


## Стереть окантовку в прямоугольнике клеток (снесли постройку: кольца соседей потом пишутся заново)
func wear_clear(i0: int, j0: int, i1: int, j1: int) -> void:
	i0 = clampi(i0, 0, N - 1)
	j0 = clampi(j0, 0, N - 1)
	i1 = clampi(i1, 0, N - 1)
	j1 = clampi(j1, 0, N - 1)
	for j in range(j0, j1 + 1):
		var row := j * N
		for i in range(i0, i1 + 1):
			wear[row + i] = 0
	_wear_dirty(i0, j0, i1, j1)


## Окантовка поменялась в прямоугольнике: маску покрытий — пересобрать там (кусков сетки и сохранения не трогаем)
func _wear_dirty(i0: int, j0: int, i1: int, j1: int) -> void:
	i0 = clampi(i0, 0, N - 1)
	j0 = clampi(j0, 0, N - 1)
	i1 = clampi(i1, 0, N - 1)
	j1 = clampi(j1, 0, N - 1)
	mask_lo = Vector2i(mini(mask_lo.x, i0 / SM), mini(mask_lo.y, j0 / SM))
	mask_hi = Vector2i(maxi(mask_hi.x, i1 / SM), maxi(mask_hi.y, j1 / SM))
	for cj in range(j0 / CH, j1 / CH + 1):
		for ci in range(i0 / CH, i1 / CH + 1):
			wear_chunks[Vector2i(ci, cj)] = true


## Доля окантовки в пикселе маски (2×2 клетки): только на траве
func _wear_px(k0: int) -> float:
	var a := 0
	for k: int in [k0, k0 + 1, k0 + N, k0 + N + 1]:
		if kind[k] == Kind.GRASS:
			a += wear[k]
	return a / 1020.0


# ---------- маска покрытий для шейдера (плавные края дорог) ----------

func make_surface() -> Image:
	var img := Image.create(N / SM, N / SM, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 1))
	for ch in road_chunks:
		update_surface(img, ch)
	for ch in wear_chunks:
		if not road_chunks.has(ch):
			update_surface(img, ch)
	mask_lo = Vector2i(1 << 30, 1 << 30)       # маска собрана целиком — обновлять пока нечего
	mask_hi = Vector2i(-1, -1)
	return img


## Обновить в маске только поменявшийся прямоугольник (mask_lo…mask_hi); false — нечего обновлять
func update_surface_rect(img: Image) -> bool:
	if mask_hi.x < 0:
		return false
	if img.has_mipmaps():
		img.clear_mipmaps()
	var x0 := maxi(mask_lo.x, 0)
	var y0 := maxi(mask_lo.y, 0)
	var x1 := mini(mask_hi.x, N / SM - 1)
	var y1 := mini(mask_hi.y, N / SM - 1)
	mask_lo = Vector2i(1 << 30, 1 << 30)
	mask_hi = Vector2i(-1, -1)
	for j in range(y0, y1 + 1):
		for i in range(x0, x1 + 1):
			var k0 := (j * SM) * N + i * SM
			var c := Color(0, 0, 0, 1)
			for kd: int in [kind[k0], kind[k0 + 1], kind[k0 + N], kind[k0 + N + 1]]:
				if kd == Kind.ROAD:
					c.r += 0.25
				elif kd == Kind.PLAZA:
					c.g += 0.25
				elif kd == Kind.DIRT:
					c.b += 0.25
			c.a = 1.0 - _wear_px(k0)            # A: 1 — трава, меньше — окантовка у домов
			img.set_pixel(i, j, c)
	return true


func update_surface(img: Image, ch: Vector2i) -> void:
	if img.has_mipmaps():
		img.clear_mipmaps()
	var s := CH / SM
	for j in range(ch.y * s, ch.y * s + s):
		for i in range(ch.x * s, ch.x * s + s):
			var r := 0.0
			var g := 0.0
			var b := 0.0
			for dj in SM:
				for di in SM:
					var kd := kind[idx(i * SM + di, j * SM + dj)]
					if kd == Kind.ROAD:
						r += 0.25
					elif kd == Kind.PLAZA:
						g += 0.25
					elif kd == Kind.DIRT:
						b += 0.25
			img.set_pixel(i, j, Color(r, g, b, 1.0 - _wear_px((j * SM) * N + i * SM)))


# ---------- цвета и сетка ----------

const C_GRASS := [Color("536428"), Color("5e6e2c"), Color("6a7832"), Color("767f37")]
const C_DIRT := Color("c6a878")
const C_ROCK := Color("d9c7ad")
const C_SAND := Color("e2cf9c")
const C_SAND_WET := Color("bfae84")
const C_YARD := Color("b8a07a")
const C_PAVE := Color("b9a98e")
const C_FIELD := Color("9a7a4e")
const LOCK := Color("c4bb98")


## Русло под мостовой — песок, даже когда клетка для ходьбы остаётся дорогой.
func _surface_kind(k: int, y: float) -> int:
	return Kind.SAND if y < WATER_Y + 0.3 and vis_h.has(k) else kind[k]


## Что рисовать на клетке: дороги и дворы — как есть; трава у воды — песок, на обрыве — скала
func show_kind(k: int, y: float) -> int:
	var kd := _surface_kind(k, y)
	if kd != Kind.GRASS:
		return kd
	if y < WATER_Y + 0.3:
		return Kind.SAND
	return kd


func top_color(kd: int, k: int, y: float) -> Color:
	match kd:
		Kind.ROCK: return C_ROCK
		Kind.SAND: return C_SAND_WET if y < WATER_Y + 0.12 else C_SAND
		Kind.YARD: return C_YARD
		Kind.FIELD: return C_FIELD
	return C_GRASS[tint[k] >> 6]


## Сетка куска (ci, cj): верх — полосами из одинаковых клеток (меньше треугольников), стенки — к нижним соседям
func chunk_mesh(ci: int, cj: int) -> ArrayMesh:
	var v := PackedVector3Array()
	var nr := PackedVector3Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()
	var ix := PackedInt32Array()
	var i0 := ci * CH
	var j0 := cj * CH
	var plot_cells := int(PLOT / CELL)
	# высоты куска с рамкой в одну клетку — читаем один раз
	var W := CH + 2
	var hy := PackedFloat32Array()
	hy.resize(W * W)
	for j in W:
		for i in W:
			var gi := clampi(i0 + i - 1, 0, N - 1)
			var gj := clampi(j0 + j - 1, 0, N - 1)
			var yy := hq(idx(gi, gj))
			if not vis_h.is_empty() and vis_h.has(idx(gi, gj)):
				yy = roundf(vis_h[idx(gi, gj)] / STEP) * STEP
			if i0 + i - 1 < 0 or j0 + j - 1 < 0 or i0 + i - 1 >= N or j0 + j - 1 >= N:
				# за краем — пейзаж до горизонта той же высоты (far_height): низкая стенка вниз закрывает щёлку в пару см
				yy -= 0.3
			hy[j * W + i] = yy
	var quad := func(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, n: Vector3, c: Color, kd: int, top: float) -> void:
		var base := v.size()
		v.append_array([a, b, cc, d])
		nr.append_array([n, n, n, n])
		var lc := c.srgb_to_linear()
		col.append_array([lc, lc, lc, lc])
		var u := Vector2(kd, top)
		uv.append_array([u, u, u, u])
		ix.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
	for j in range(j0, j0 + CH):
		var i := i0
		var lj := j - j0 + 1
		while i < i0 + CH:
			var k := idx(i, j)
			var y := hy[lj * W + (i - i0 + 1)]
			var kd := show_kind(k, y)
			var tc := tint[k] >> 6
			var own := is_owned(cell_center(i, j))
			var e := i + 1
			while e < i0 + CH:
				var k2 := idx(e, j)
				var y2 := hy[lj * W + (e - i0 + 1)]
				if y2 != y or show_kind(k2, y2) != kd or (tint[k2] >> 6) != tc:
					break
				if e % plot_cells == 0:
					break                       # граница участка — не сливаем (разный цвет своей и чужой земли)
				e += 1
			var c := top_color(kd, k, y)
			if not own:
				c = c.lerp(LOCK, 0.18)
			var x0 := i * CELL
			var x1 := e * CELL
			var z0 := j * CELL
			var z1 := z0 + CELL
			quad.call(Vector3(x0, y, z0), Vector3(x0, y, z1), Vector3(x1, y, z1), Vector3(x1, y, z0), Vector3.UP, c, kd, y)
			i = e
	if bridge_road_chunks.has(Vector2i(ci, cj)):
		for j in range(j0, j0 + CH):
			for i in range(i0, i0 + CH):
				var k := idx(i, j)
				if not vis_h.has(k) or kind[k] != Kind.ROAD:
					continue
				var y := hq(k)
				if y <= hy[(j - j0 + 1) * W + i - i0 + 1]:
					continue
				var x := i * CELL
				var z := j * CELL
				var c := top_color(Kind.ROAD, k, y)
				if not is_owned(cell_center(i, j)):
					c = c.lerp(LOCK, 0.18)
				quad.call(Vector3(x, y, z), Vector3(x, y, z + CELL), Vector3(x + CELL, y, z + CELL),
					Vector3(x + CELL, y, z), Vector3.UP, c, Kind.ROAD, y)
	# стенки уступов
	for j in range(j0, j0 + CH):
		var lj := j - j0 + 1
		for i in range(i0, i0 + CH):
			var li := i - i0 + 1
			var y := hy[lj * W + li]
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var yn := hy[(lj + d.y) * W + li + d.x]
				if yn >= y:
					continue
				var x0 := i * CELL
				var z0 := j * CELL
				var x1 := x0 + CELL
				var z1 := z0 + CELL
				var a: Vector3
				var b: Vector3
				if d.x == 1:
					a = Vector3(x1, 0, z1); b = Vector3(x1, 0, z0)
				elif d.x == -1:
					a = Vector3(x0, 0, z0); b = Vector3(x0, 0, z1)
				elif d.y == 1:
					a = Vector3(x0, 0, z1); b = Vector3(x1, 0, z1)
				else:
					a = Vector3(x1, 0, z0); b = Vector3(x0, 0, z0)
				var k := idx(i, j)
				var rocky := y - yn >= 0.45
				var skd := show_kind(k, y)
				var paved := skd == Kind.ROAD or skd == Kind.PLAZA
				var c := C_ROCK if rocky else (C_PAVE if paved else top_color(skd, k, y))
				quad.call(Vector3(b.x, yn, b.z), Vector3(b.x, y, b.z), Vector3(a.x, y, a.z), Vector3(a.x, yn, a.z), Vector3(d.x, 0, d.y), c, Kind.ROCK if rocky else (Kind.ROAD if paved else Kind.DIRT), y)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nr
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = ix
	var m := ArrayMesh.new()
	if not v.is_empty():
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


# ---------- плавная земля (14.11) ----------

## Владелец 14.11: «земля выглядит хуже, чем раньше… хочу, чтобы выглядело как в паке Synty». Ступеньки по 12,5 см
## (hq) рисовались полосами и горизонталями, у прудов — кольцами. Теперь видимая земля — плавная: сетка узлов через
## RS клеток (0,5 м), высота узла — средняя «как есть» (h, без ступенек) у четырёх клеток вокруг угла; нормали —
## по соседним узлам. Высоты игры (hq, height_at), занятость, дороги и участки — те же: постройки стоят на
## выровненных клетках (h = их пол), дороги сглажены кистью, природа — на surface_y. smooth_on = false — как было
const RS := 2
static var smooth_on := OS.get_environment("CIVCITY_NATURE2") != "0"


## Высота узла плавной сетки (vi, vj) — в метрах: угол клеток (vi·RS, vj·RS)
func node_y(vi: int, vj: int, visible_ground := true) -> float:
	var i1 := clampi(vi * RS, 0, N - 1)
	var j1 := clampi(vj * RS, 0, N - 1)
	var i0 := clampi(vi * RS - 1, 0, N - 1)
	var j0 := clampi(vj * RS - 1, 0, N - 1)
	if visible_ground and i1 >= vis_lo.x and i0 <= vis_hi.x and j1 >= vis_lo.y and j0 <= vis_hi.y:
		return (_vh(j0 * N + i0) + _vh(j0 * N + i1) + _vh(j1 * N + i0) + _vh(j1 * N + i1)) * 0.25
	return (h[j0 * N + i0] + h[j0 * N + i1] + h[j1 * N + i0] + h[j1 * N + i1]) * 0.25


## Высота клетки для рисования: под мостом — дно (vis_h), иначе h
func _vh(k: int) -> float:
	return vis_h[k] if vis_h.has(k) else h[k]


func set_vis(k: int, y: float) -> void:
	vis_h[k] = y
	var i := k % N
	var j := k / N
	vis_lo = Vector2i(mini(vis_lo.x, i), mini(vis_lo.y, j))
	vis_hi = Vector2i(maxi(vis_hi.x, i), maxi(vis_hi.y, j))


## Что кисть траву сказала про точку: 0 — само, 1 — посажено, 2 — убрано
func gm_at(x: float, z: float) -> int:
	if gm_count == 0:
		return 0
	var i := int(x)
	var j := int(z)
	if i < 0 or j < 0 or i >= GM_N or j >= GM_N:
		return 0
	return grass_mask[j * GM_N + i]


## Мазок кисти травы: круг радиуса r (м) в точке c, v: 1 — посадить, 2 — убрать, 0 — стереть метку. Возвращает
## прямоугольник правки [от, до] (м) или пустой массив, если ничего не изменилось
func gm_paint(c: Vector2, r: float, v: int) -> Array:
	if grass_mask.is_empty():
		grass_mask.resize(GM_N * GM_N)
		grass_mask.fill(0)
	var any := false
	for j in range(maxi(0, int(floor(c.y - r))), mini(GM_N, int(ceil(c.y + r)) + 1)):
		for i in range(maxi(0, int(floor(c.x - r))), mini(GM_N, int(ceil(c.x + r)) + 1)):
			if Vector2(i + 0.5, j + 0.5).distance_to(c) > r:
				continue
			var k := j * GM_N + i
			var o := grass_mask[k]
			if o == v:
				continue
			if o == 0:
				gm_count += 1
			elif v == 0:
				gm_count -= 1
			grass_mask[k] = v
			any = true
	if not any:
		return []
	_gm_dirty = true
	return [Vector2(c.x - r - 1.0, c.y - r - 1.0), Vector2(c.x + r + 1.0, c.y + r + 1.0)]


func gm_save() -> Dictionary:
	if gm_count <= 0:
		return {}
	if _gm_dirty:
		_gm_enc = Marshalls.raw_to_base64(grass_mask.compress(FileAccess.COMPRESSION_ZSTD))
		_gm_dirty = false
	return {"gmask": _gm_enc, "gmask_n": GM_N}


func gm_load(d: Dictionary) -> void:
	var enc := String(d.get("gmask", ""))
	var n := int(d.get("gmask_n", 0))
	if enc == "" or n != GM_N:
		return
	var raw := Marshalls.base64_to_raw(enc)
	var m := raw.decompress(GM_N * GM_N, FileAccess.COMPRESSION_ZSTD)
	if m.size() != GM_N * GM_N:
		return
	grass_mask = m
	gm_count = 0
	for b in m:
		if b != 0:
			gm_count += 1
	_gm_dirty = true


## Высота видимой (плавной) земли в точке — ровно по треугольникам сетки (диагональ 00–11, как chunk_mesh)
func surface_y(x: float, z: float) -> float:
	if not smooth_on:
		var c := cell(Vector2(x, z))
		return roundf(_vh(idx(c.x, c.y)) / STEP) * STEP
	var step := CELL * RS
	var u := clampf(x / step, 0.0, float(N / RS) - 0.001)
	var v := clampf(z / step, 0.0, float(N / RS) - 0.001)
	var vi := int(u)
	var vj := int(v)
	var fu := u - vi
	var fv := v - vj
	var a := node_y(vi, vj)
	var c := node_y(vi + 1, vj + 1)
	if fu >= fv:
		var d := node_y(vi + 1, vj)
		return a + (d - a) * fu + (c - d) * fv
	var b2 := node_y(vi, vj + 1)
	return a + (c - b2) * fu + (b2 - a) * fv


## Плавная сетка куска (ci, cj): узлы через RS клеток. UV.x = 0 (вид клетки — по маске покрытий в шейдере),
## UV.y — высота; UV2.x — доля пашни, UV2.y = 2 под мостовой; цвет — оттенок клетки (как у chunk_mesh)
func smooth_mesh(ci: int, cj: int) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, smooth_arrays(ci, cj))
	return mesh


func smooth_arrays(ci: int, cj: int) -> Array:
	var Q := CH / RS                          # узлов-промежутков в куске
	var W := Q + 1
	var vi0 := ci * Q
	var vj0 := cj * Q
	var step := CELL * RS
	var plot_cells := int(PLOT / CELL)
	# высоты узлов с рамкой в один узел (для нормалей)
	var WB := W + 2
	var hy := PackedFloat32Array()
	hy.resize(WB * WB)
	for j in WB:
		for i in WB:
			hy[j * WB + i] = node_y(vi0 + i - 1, vj0 + j - 1)
	var v := PackedVector3Array()
	var nr := PackedVector3Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	v.resize(W * W)
	nr.resize(W * W)
	col.resize(W * W)
	uv.resize(W * W)
	uv2.resize(W * W)
	var inv := 1.0 / (2.0 * step)
	for j in W:
		for i in W:
			var n := j * W + i
			var b := (j + 1) * WB + (i + 1)
			var y := hy[b]
			var gi := vi0 + i
			var gj := vj0 + j
			v[n] = Vector3(gi * step, y, gj * step)
			nr[n] = Vector3(-(hy[b + 1] - hy[b - 1]) * inv, 1.0, -(hy[b + WB] - hy[b - WB]) * inv).normalized()
			var ci1 := clampi(gi * RS, 0, N - 1)
			var cj1 := clampi(gj * RS, 0, N - 1)
			var ci0 := clampi(gi * RS - 1, 0, N - 1)
			var cj0 := clampi(gj * RS - 1, 0, N - 1)
			var k := cj1 * N + ci1
			var ground_y := hq(k)
			var bed := y < WATER_Y and kind[k] == Kind.ROAD and vis_h.has(k)
			var c := top_color(Kind.SAND if bed else show_kind(k, ground_y), k, y if bed else ground_y)
			if not owned.has(Vector2i(ci1 / plot_cells, cj1 / plot_cells)):
				c = c.lerp(LOCK, 0.18)
			col[n] = c.srgb_to_linear()
			uv[n] = Vector2(0.0, y)
			var f := 0
			for kk: int in [cj0 * N + ci0, cj0 * N + ci1, cj1 * N + ci0, k]:
				if kind[kk] == Kind.FIELD:
					f += 1
			uv2[n] = Vector2(f * 0.25, 2.0 if bed else 1.0)
	var ix := PackedInt32Array()
	ix.resize(Q * Q * 6)
	var t := 0
	for j in Q:
		for i in Q:
			var a := j * W + i
			# как у chunk_mesh: (00, 11, 01) и (00, 10, 11) — диагональ 00–11
			ix[t] = a
			ix[t + 1] = a + W + 1
			ix[t + 2] = a + W
			ix[t + 3] = a
			ix[t + 4] = a + 1
			ix[t + 5] = a + W + 1
			t += 6
	if bridge_road_chunks.has(Vector2i(ci, cj)):
		_append_bridge_road(v, nr, col, uv, uv2, ix, Vector2i(vi0, vj0), Q)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nr
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = ix
	return arr


## Верх моста повторяет высоту, текстуру и цвет прежней дороги.
func _append_bridge_road(v: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray,
		uv: PackedVector2Array, uv2: PackedVector2Array, indices: PackedInt32Array, start: Vector2i, count: int) -> void:
	var step := CELL * RS
	var left := ROAD_X - ROAD_R - 0.01
	var right := ROAD_X + ROAD_R + 0.01
	var first := ceili(left / step)
	var last := floori(right / step)
	var offsets := [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.ONE, Vector2i.DOWN]
	for i in count:
		var u := start.x + i
		var x := u * step
		if x >= right or x + step <= left:
			continue
		for j in count:
			var w := start.y + j
			var a := j * (count + 1) + i
			var corners := [a, a + 1, a + count + 2, a + count + 1]
			var lowered := PackedByteArray()
			for k in 4:
				var d: Vector2i = offsets[k]
				var y := node_y(u + d.x, w + d.y, false)
				lowered.append(int(v[corners[k]].y < y - 0.001))
			for tri: Vector3i in [Vector3i(0, 2, 3), Vector3i(0, 1, 2)]:
				if lowered[tri.x] + lowered[tri.y] + lowered[tri.z] == 0:
					continue
				for k: int in [tri.x, tri.y, tri.z]:
					var d: Vector2i = offsets[k]
					var row := w + d.y
					var px := clampf((u + d.x) * step, left, right)
					# Край продолжает мостовую от её последнего узла. Соседний узел уже на откосе к воде.
					var gx := clampi(u + d.x, first, last)
					var y := node_y(gx, row, false)
					var west := maxi(gx - 1, first)
					var east := mini(gx + 1, last)
					var nx := (node_y(west, row, false) - node_y(east, row, false)) / float(east - west)
					var nz := (node_y(gx, row - 1, false) - node_y(gx, row + 1, false)) * 0.5
					indices.append(v.size())
					v.append(Vector3(px, y, row * step))
					normals.append(Vector3(nx, step, nz).normalized())
					colors.append(colors[(j + d.y) * (count + 1) + gx - start.x])
					uv.append(Vector2(0.0, y))
					uv2.append(Vector2(0.0, 1.0))


# ---------- сохранение ----------

func save_changes() -> Dictionary:
	# сохраняем только клетки, отличающиеся от исходной карты; по кускам, которые не менялись с прошлого раза, —
	# готовое (перебор всех клеток большого города — 60 мс, рывок кадра при автосохранении)
	if not _save_dirty.is_empty() or _enc.is_empty():
		_encode()
	var plots := []
	for p in owned:
		plots.append([p.x, p.y])
	var out := {"cells": _enc[0], "kinds": _enc[1], "hs": _enc[2], "plots": plots, "streams": streams.duplicate()}
	if meadow_new:
		out["nv"] = 1
	if not deco_cells.is_empty():
		var de := _deco_save()               # узор земли и улучшенные дороги (этап 5.7–5.8) — только если он есть
		out["deco"] = de[0]
		out["deco_v"] = de[1]
	out.merge(gm_save())
	return out


## Отличия всех изменённых кусков — одной строкой base64 на массив (как в сохранении); пересчёт — только поменявшихся
func _encode() -> void:
	var cells := PackedInt32Array()
	var kinds := PackedByteArray()
	var hs := PackedFloat32Array()
	for ch in _changed_chunks():
		if _save_dirty.has(ch) or not _sc_cells.has(ch):
			_save_chunk(ch)
		cells.append_array(_sc_cells[ch])
		kinds.append_array(_sc_kinds[ch])
		hs.append_array(_sc_hs[ch])
	_save_dirty.clear()
	_enc = [Marshalls.raw_to_base64(cells.to_byte_array()), Marshalls.raw_to_base64(kinds), Marshalls.raw_to_base64(hs.to_byte_array())]


var touched := {}                    # куски, где игрок что-то менял
var _save_dirty := {}                # куски, поменявшиеся после того, как их отличия посчитаны (save_changes, save_warm)
var _sc_cells := {}                  # кусок → его отличия от исходной карты: клетки, виды, высоты
var _sc_kinds := {}
var _sc_hs := {}
var _enc := []                       # готовые строки сохранения [клетки, виды, высоты]; пусто — посчитать заново


func _save_chunk(ch: Vector2i) -> void:
	var cells := PackedInt32Array()
	var kinds := PackedByteArray()
	var hs := PackedFloat32Array()
	for j in range(ch.y * CH, ch.y * CH + CH):
		for i in range(ch.x * CH, ch.x * CH + CH):
			var k := idx(i, j)
			if kind[k] != base_kind[k] or h[k] != base_h[k]:
				cells.append(k)
				kinds.append(kind[k])
				hs.append(h[k])
	_sc_cells[ch] = cells
	_sc_kinds[ch] = kinds
	_sc_hs[ch] = hs
	_save_dirty.erase(ch)
	_enc = []


## Понемногу каждый кадр (game._process): отличия поменявшихся кусков считаются заранее — к сохранению всё готово
func save_warm(limit := 2) -> void:
	# узор земли (этап 5.7–5.8): поменявшиеся куски, потом склейка строк — каждое своим кадром
	if not _dc_dirty.is_empty():
		var dn := 0
		for ch in _dc_dirty.keys():
			_deco_chunk(ch)
			dn += 1
			if dn >= limit:
				break
		return
	if _deco_enc.is_empty() and not deco_cells.is_empty():
		_deco_save()
		return
	if _save_dirty.is_empty():
		if _enc.is_empty() and not touched.is_empty():
			_encode()                    # все куски посчитаны — строки сохранения заранее (отдельным кадром)
		return
	var n := 0
	for ch in _save_dirty.keys():
		if not touched.has(ch):
			_save_dirty.erase(ch)
			continue
		_save_chunk(ch)
		n += 1
		if n >= limit:
			return


func _changed_chunks() -> Array:
	return touched.keys()


func load_changes(d: Dictionary) -> void:
	gen += 1
	var cells := Marshalls.base64_to_raw(d.get("cells", "")).to_int32_array()
	var kinds := Marshalls.base64_to_raw(d.get("kinds", ""))
	var hs := Marshalls.base64_to_raw(d.get("hs", "")).to_float32_array()
	for n in cells.size():
		var k := cells[n]
		kind[k] = kinds[n]
		h[k] = hs[n]
		var ch := Vector2i((k % N) / CH, (k / N) / CH)
		touched[ch] = true
		_save_dirty[ch] = true
		if walk_kind(kinds[n]):
			road_chunks[ch] = true
	# узор земли и улучшенные дороги (этап 5.7–5.8); в старых сохранениях его нет
	var dc := Marshalls.base64_to_raw(d.get("deco", "")).to_int32_array()
	var dv := Marshalls.base64_to_raw(d.get("deco_v", ""))
	for n in mini(dc.size(), dv.size()):
		if dc[n] >= 0 and dc[n] < N * N:
			set_deco(dc[n], dv[n] & (UP | GMASK | ROAD_STYLE))
	owned.clear()
	for p in d.get("plots", []):
		owned[Vector2i(int(p[0]), int(p[1]))] = true
	gm_load(d)                                        # маска травы (15.11): в старых сохранениях её нет — как само растёт
	streams_saved = d.get("streams", null)            # ручьи (13.11): в старых сохранениях их нет — null
	meadow_new = int(d.get("nv", 0)) >= 1
