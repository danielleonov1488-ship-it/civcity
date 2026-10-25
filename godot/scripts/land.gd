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


static func walk_kind(kd: int) -> bool:
	return kd == Kind.ROAD or kd == Kind.PLAZA or kd == Kind.DIRT


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
	_deco_enc = []
	_dc_dirty.clear()
	_dc_cells.clear()
	_dc_vals.clear()
	under.clear()
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
	return y


## Клетка поменялась. mesh — поменялся видимый уступ (12,5 см): сетку куска перестроить; mask — поменялось
## покрытие: маска для шейдера (и стенки уступов — сетка «потом», dirty_soft). Ни то ни другое — только для сохранения
func _mark(i: int, j: int, mesh := true, mask := true) -> void:
	var ci := clampi(i / CH, 0, CHN - 1)
	var cj := clampi(j / CH, 0, CHN - 1)
	var ch := Vector2i(ci, cj)
	touched[ch] = true
	_save_dirty[ch] = true
	dirty_walk[ch] = true
	if mask:
		walk_ver += 1
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
			var kk := kind[k]
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
			out.append([Vector2i(i, j), kk, h[k], deco[k]])
			if defer:
				seen[k] = true
			if kk != kd and deco[k] != 0:
				set_deco(k, 0)                   # новое покрытие — без прежнего узора и улучшения
			kind[k] = kd
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
			var kk := kind[k]
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
		var kk := kind[k]
		out.append([Vector2i(i, j), kk, h[k], deco[k]])
		if deco[k] != 0 and (kk != kd or kd == Kind.GRASS):
			set_deco(k, 0)
		if kk != kd:
			kind[k] = kd
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
			kind[k] = Kind.ROAD
			_mark(i, j, false, true)
			road_chunks[Vector2i(i / CH, j / CH)] = true
		else:
			set_deco(k, deco[k] | UP)
	return out


## Маски узора для шейдера (по 2×2 клетки): [0] — RGBA доли кисти «Земля» (сочная трава, луг, песок, утоптанная земля),
## [1] — R гравий, G улучшенная дорога. Собираются только по кускам, где узор был
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
	var seen := {}
	for r: Rect2 in rects:
		var rr := r.grow(pad)
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for cnr: Vector2 in [rr.position, rr.position + Vector2(rr.size.x, 0), rr.position + Vector2(0, rr.size.y), rr.end]:
			var w := pos + ax * cnr.x + fw * cnr.y
			lo = lo.min(w)
			hi = hi.max(w)
		var c0 := cell(lo)
		var c1 := cell(hi)
		for j in range(c0.y, c1.y + 1):
			for i in range(c0.x, c1.x + 1):
				var q := cell_center(i, j) - pos
				var lx := q.dot(ax)
				var lz := q.dot(fw)
				if lx >= rr.position.x and lx <= rr.end.x and lz >= rr.position.y and lz <= rr.end.y:
					var k := idx(i, j)
					if not seen.has(k):
						seen[k] = true
						out.append(k)
	return out


func set_occ(cells: PackedInt32Array, id: int) -> void:
	for k in cells:
		occ[k] = id
	walk_ver += 1


## Выровнять клетки под постройкой на высоту y (вокруг остаются уступы — как подпорные стенки)
func flatten_cells(cells: PackedInt32Array, y: float, kd := -1) -> void:
	for k in cells:
		if hq(k) != y or (kd >= 0 and kind[k] != kd):
			var step := hq(k) != y
			var kch := kd >= 0 and kind[k] != kd
			h[k] = y
			if kd >= 0:
				kind[k] = kd
			_mark(k % N, k / N, step, kch)


## Земля вокруг постройки плавно подходит к её полу — без ям и ступенек (rc клеток вокруг)
func blend_ring(cells: PackedInt32Array, y: float, rc := 7) -> void:
	var dist := {}
	var front: Array[int] = []
	for k in cells:
		dist[k] = 0
		front.append(k)
	for step in range(1, rc + 1):
		var nxt: Array[int] = []
		for k in front:
			var i := k % N
			var j := k / N
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not inside(i + d.x, j + d.y):
					continue
				var k2 := idx(i + d.x, j + d.y)
				if dist.has(k2):
					continue
				dist[k2] = step
				nxt.append(k2)
		front = nxt
	for k in dist:
		var st: int = dist[k]
		if st == 0 or occ[k] != 0 or walk_kind(kind[k]) or h[k] < WATER_Y + 0.2:
			continue
		var t := 1.0 - float(st) / float(rc + 1)
		t = t * t * (3.0 - 2.0 * t)
		var ny := lerpf(h[k], y, t)
		if absf(ny - h[k]) > 0.01:
			var old := hq(k)
			h[k] = ny
			_mark(k % N, k / N, hq(k) != old, false)


# ---------- окантовка у домов: утоптанная глина (Town to City) ----------

const APRON_W := [255, 255, 240, 170, 80]   # по кольцам от стены (клетки 25 см): под постройкой и у стены — сплошь, дальше реже
const APRON_DOOR := 5                   # пятно у двери: радиус в клетках (1,25 м) — там ходят


## Окантовка вокруг следа постройки cells: кольца от стены (по четырём соседям) и пятно у двери door.
## Пишется наибольшее (соседние дома друг друга не стирают); маска покрытий обновится по прямоугольнику.
## Клетки построек с бордюром (wear_block) глина обходит: ни на них, ни сквозь них в сад домуса и двор храма
func wear_stamp(cells: PackedInt32Array, door := Vector2.INF) -> void:
	if cells.is_empty():
		return
	var seen := {}
	var front := PackedInt32Array()
	var i0 := N
	var j0 := N
	var i1 := -1
	var j1 := -1
	for k in cells:
		seen[k] = true
		front.append(k)
		wear[k] = 255
		var ci := k % N
		var cj := k / N
		i0 = mini(i0, ci)
		j0 = mini(j0, cj)
		i1 = maxi(i1, ci)
		j1 = maxi(j1, cj)
	for st in range(1, APRON_W.size()):
		var w: int = APRON_W[st]
		var nxt := PackedInt32Array()
		for k in front:
			var ci := k % N
			for k2: int in [k + 1 if ci < N - 1 else -1, k - 1 if ci > 0 else -1, k + N, k - N]:
				if k2 < 0 or k2 >= N * N or seen.has(k2):
					continue
				seen[k2] = true
				if occ[k2] != 0 and wear_block.has(occ[k2]):
					continue            # стена домуса: не красим и дальше за неё не идём
				nxt.append(k2)
				if wear[k2] < w:
					wear[k2] = w
		front = nxt
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


## Что рисовать на клетке: дороги и дворы — как есть; трава у воды — песок, на обрыве — скала
func show_kind(k: int, y: float) -> int:
	var kd := kind[k]
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


# ---------- сохранение ----------

func save_changes() -> Dictionary:
	# сохраняем только клетки, отличающиеся от исходной карты; по кускам, которые не менялись с прошлого раза, —
	# готовое (перебор всех клеток большого города — 60 мс, рывок кадра при автосохранении)
	if not _save_dirty.is_empty() or _enc.is_empty():
		_encode()
	var plots := []
	for p in owned:
		plots.append([p.x, p.y])
	var out := {"cells": _enc[0], "kinds": _enc[1], "hs": _enc[2], "plots": plots}
	if not deco_cells.is_empty():
		var de := _deco_save()               # узор земли и улучшенные дороги (этап 5.7–5.8) — только если он есть
		out["deco"] = de[0]
		out["deco_v"] = de[1]
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
			set_deco(dc[n], dv[n] & (UP | GMASK))
	owned.clear()
	for p in d.get("plots", []):
		owned[Vector2i(int(p[0]), int(p[1]))] = true
