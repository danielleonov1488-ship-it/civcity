class_name Spectacle
extends Node3D
## Зрелища: большие постройки живут. К представлению горожане идут в амфитеатр, цирк и театр, рассаживаются
## по трибунам — лицом к арене, ровно на ступенях (таз на сиденье, ступни на ступени ниже), под навесами
## и на парапете не садятся; на арене бьются гладиаторы, в цирке скачут колесницы, в театре — спектакль.
## Сидящие живые: разговаривают, оглядываются, подаются вперёд, хлопают и кричат «ура» на удачный удар.
## Зрители — толпа (Crowd): сотни людей одной пачкой на модель, кадры не проседают.
##
## Места считаются по самой постройке: ступени трибун (SM_Bld_Amphitheatre_01 — их профиль снят с модели),
## скамьи цирка (#bench), а потом каждое место проверяется вертикальными лучами по всем треугольникам постройки:
## под тазом — сиденье, под ступнями — ступень ниже, над головой и перед коленями — пусто (_check).
## Приходят зрители сверху, из проходов по верхнему обходу, спускаются по лестницам между секторами, идут вдоль
## своего ряда и садятся (клип «enter»); ряды заполняются от дальних мест к проходу, чтобы никто не шёл сквозь сидящих.
##
## Жители: перед представлением к постройке идут настоящие горожане (People.show_call), у входа исчезают внутри
## и появляются на трибунах тем же человеком (облик, цвета одежды); после представления выходят и идут домой.
## Остальные места занимают гости из округи — их не видно на улицах.

signal sfx(kind: String, at: Vector3, vol: float)     # звук зрелища (для ролика: promo_cam пишет их по времени)

## Расписание (часы): сбор, начало, конец, все разошлись
const VENUES := {
	"colosseum": {"kind": "arena", "hours": [12.6, 14.0, 17.4, 18.2], "fill": 0.86},
	"circus_fl": {"kind": "circus", "hours": [9.0, 10.2, 13.0, 13.8], "fill": 0.82},
	"theatre": {"kind": "theatre", "hours": [16.4, 17.6, 20.4, 21.0], "fill": 0.8},
	# «Уютный Рим», этап 3: большие здания работают — утренняя служба в храме, термы открыты днём
	"temple": {"kind": "temple", "hours": [7.0, 7.8, 9.4, 10.0], "fill": 0.9},
	"baths": {"kind": "bath", "hours": [9.0, 9.8, 16.6, 17.4], "fill": 0.75},
	"thermae": {"kind": "bath", "hours": [8.6, 9.4, 17.4, 18.2], "fill": 0.75},
	# форум: днём сенатор говорит с ростр, горожане слушают на площади; одеон: вечерний концерт
	"forum": {"kind": "forum", "hours": [10.6, 11.3, 14.0, 14.6], "fill": 0.55},
	"odeon": {"kind": "theatre", "hours": [18.4, 19.2, 21.2, 21.8], "fill": 0.8},
	# школа: утром дети сидят на скамьях под перголой, учитель рассказывает
	"school": {"kind": "school", "hours": [7.7, 8.3, 12.4, 12.9], "fill": 0.9},
	# «Уютный Рим», этап 5: вечером в таверне — за столиками и на скамьях, пара человек стоит у жаровни (только новая игра)
	"taberna": {"kind": "tavern", "hours": [18.2, 18.8, 22.0, 22.6], "fill": 0.85},
}
## Площадки-зрелища (овация в конце, совет «Зрелища»); остальные — храм, термы
const SHOWS := ["arena", "circus", "theatre"]
const BATH_DEPTH := 0.7                 # купальщик в бассейне: ступни на столько ниже воды (видны голова, плечи и грудь)
const STAND_GAP := 0.62                  # между стоящими (храм, бассейн), м
const TEMPLE_MAX := 64                   # мест на утренней службе у храма — не больше (у прежнего храма их 46–51)
## Профиль ступеней Synty «SM_Bld_Amphitheatre_01» (в осях детали, до масштаба; снят с модели): ряды —
## [радиус переднего края сиденья, высота сиденья]; проход — посредине сектора; верхний обход
const AMPHI_ROWS := [[8.02, 0.96], [9.32, 1.41], [10.66, 1.86], [11.97, 2.31], [13.30, 2.76], [14.61, 3.21], [15.92, 3.66], [17.26, 4.11]]
const AMPHI_AISLE := 22.5                # градусов от края сектора
const AMPHI_AISLE_HW := 1.1              # полуширина прохода (в осях детали)
const AMPHI_RIM := [19.3, 4.56]          # верхний обход: радиус, высота
const SPACING := 0.41                    # между зрителями вдоль ряда, м
const PELVIS_IN := 0.12 * Citizen.K                  # таз — на столько за передним краем сиденья
const HEAD := 0.86                       # сидящему над сиденьем нужно столько свободы (голова и запас)
const WALK := 1.15                       # м/с
const WALK_STAIRS := 0.85
const SHADOW_D := 48.0                   # тени от зрителей — только ближе этого (м от камеры до постройки)

var game
var city: City
var venues := {}                         # id постройки → площадка
var rng := RandomNumberGenerator.new()
var paused := false
var speed := 1.0                         # скорость игры (×1…×3): люди и бои быстрее
var no_residents := false                # горожан не звать (проверки)
var _debug := ""                         # --spectacle=show[:доля] — сразу представление во всех площадках (проверки)
var _perf := false                       # --spectacle_perf: раз в 4 с — средние кадры в секунду и сколько людей
var _perf_t := 0.0
var _perf_n := 0
var _perf_us := 0
static var _layouts := {}                # тип|вариант → места, проходы, треугольники
## Звуки (assets/sfx): ликование трибун — Gregor Quendel (CC BY 4.0), удары и скрип ворот — Kenney (CC0)
const SND := {"cheer": ["arena/crowd_cheer.ogg", -6.0], "roar": ["arena/crowd_roar.ogg", -2.0],
	"clang": [["battle/metalPot1.ogg", "battle/metalPot2.ogg", "battle/metalPot3.ogg"], -4.0],
	"hit": [["battle/metalPot2.ogg", "battle/knifeSlice.ogg"], -4.0], "gate": ["battle/creak1.ogg", -10.0]}
static var _streams := {}
var _shots := 0


func setup(g, args := {}) -> void:
	game = g
	city = g.city
	rng.seed = 90210
	_debug = str(args.get("spectacle", ""))
	sfx.connect(_on_sfx)
	_perf = args.has("spectacle_perf")


static func is_venue(type: String) -> bool:
	return VENUES.has(type)


# ---------- площадки ----------

## Постройка показана (Game._show): трибуны, толпа, бойцы
func venue_show(b: Dictionary) -> void:
	if not VENUES.has(b["type"]):
		return
	if String(VENUES[b["type"]]["kind"]) == "tavern" and int(city.cozy_v) < 1:
		return                                   # вечер в таверне — в новой игре
	venue_hide(b)
	var lay := layout(b)
	var root := Node3D.new()
	root.name = "Venue_%d" % int(b["id"])
	root.transform = city.xf(b)
	add_child(root)
	var cr := Crowd.new()
	root.add_child(cr)
	var V := {"b": b, "id": int(b["id"]), "type": b["type"], "kind": VENUES[b["type"]]["kind"], "root": root, "crowd": cr, "lay": lay,
		"taken": {}, "who": [], "phase": "idle", "forced": "", "target": 0, "due": 0.0, "order": [], "oi": 0, "rid_q": [],
		"t": 0.0, "act": null, "react_t": 0.0, "called": false}
	venues[V["id"]] = V
	V["order"] = _fill_order(lay)
	# гул трибун: громче, чем больше народу
	var mur := AudioStreamPlayer3D.new()
	mur.stream = stream("arena/crowd_murmur.ogg", true)
	mur.bus = "SFX"
	mur.unit_size = 14.0
	mur.max_distance = 160.0
	mur.volume_db = -80.0
	root.add_child(mur)
	mur.position = Vector3(0, 3.0, 0)
	V["murmur"] = mur
	if _debug != "":
		var dv := _debug.split(":")
		if dv.size() < 3 or dv[2] == V["type"]:
			force(V["id"], dv[0], float(dv[1]) if dv.size() > 1 else -1.0, dv[0] == "show")
		else:
			force(V["id"], "idle")
	match V["kind"]:
		"arena":
			_gates(V, city.blueprint(b))
			V["act"] = ArenaShow.new(self, V)
		"circus":
			V["act"] = CircusShow.new(self, V)
		"theatre":
			V["act"] = null


func venue_hide(b: Dictionary) -> void:
	var V: Dictionary = venues.get(int(b["id"]), {})
	if V.is_empty():
		return
	_release_all(V)
	_fx(V, false)
	if V["act"] != null:
		V["act"].free_all()
	(V["root"] as Node).queue_free()
	venues.erase(int(b["id"]))


## Места постройки (по её чертежу; один раз на тип и вариант)
func layout(b: Dictionary) -> Dictionary:
	var key := "%s|%d|%d" % [b["type"], int(b.get("variant", 0)), int(b.get("color", 0))]
	if SizeLadder.old_lot(b):
		key += "|O"                              # постройка старого сохранения на прежнем следе — свой чертёж (Catalog.fit)
	if _layouts.has(key):
		return _layouts[key]
	var t0 := Time.get_ticks_msec()
	var bp := city.blueprint(b)
	var tris := Tris.new()
	tris.build(bp)
	var lay := {"seats": [], "groups": {}, "tris": tris}
	# уменьшенная трибуна (Catalog.SHRINK): ступени ниже — зритель сидит на своём месте, ступни чуть ниже кромки ступени
	_amphi_drop = Crowd.SEAT_DROP * float(Catalog.SHRINK.get(String(b["type"]), 1.0))
	match String(VENUES[b["type"]]["kind"]):
		"temple":
			_temple(lay, bp, tris)
		"bath":
			_bath(lay, bp, tris)
		"forum":
			_forum(lay, bp, tris)
		"school":
			_school(lay, bp, tris)
		"tavern":
			_tavern(lay, bp, tris)
		_:
			if NewArena.covers(String(b["type"])):
				NewArena.seats(self, lay, tris, String(b["type"]))     # новые амфитеатр и цирк: места — по их рядам и проходам
			else:
				for p in bp.parts:
					if p[0] == "SM_Bld_Amphitheatre_01":
						_amphi(lay, p[1], tris)
					elif p[0] == "#bench":
						_bench(lay, p[1], tris)
	if String(VENUES[b["type"]]["kind"]) == "theatre":
		_stage(lay, bp)
	lay["ms"] = Time.get_ticks_msec() - t0
	print("SPECTACLE layout %s: %d seats (dropped %d), %d tris, %d ms" % [key, (lay["seats"] as Array).size(), int(lay.get("dropped", 0)), tris.count, lay["ms"]])
	_layouts[key] = lay
	return lay


## Места на ступенях одного сектора амфитеатра (деталь с осями xf): ряды по дуге, проход посредине сектора.
## Путь каждого зрителя: из-под верхнего обхода — вверх на обход, вниз по проходу, вдоль своего ряда — к месту
func _amphi(lay: Dictionary, xf: Transform3D, tris: Tris) -> void:
	var sx := xf.basis.x.length()
	var c := xf.origin
	var aisle := deg_to_rad(AMPHI_AISLE)
	var pt := func(r: float, th: float, y: float) -> Vector3: return xf * Vector3(r * sin(th), y, -r * cos(th))
	# проход: сверху вниз — точки по высоте ступеней (луч сверху, ближняя ступень не выше прежней)
	var rim: Vector3 = pt.call(AMPHI_RIM[0], aisle, AMPHI_RIM[1])
	var down := PackedVector3Array()
	down.append(rim - (rim - Vector3(c.x, rim.y, c.z)).normalized() * 0.5 - Vector3(0, 0.75, 0))   # из-под обхода
	down.append(rim)
	var r := float(AMPHI_RIM[0]) - 0.3
	var y_prev := rim.y
	while r > float(AMPHI_ROWS[0][0]) - 0.9:
		var q: Vector3 = pt.call(r, aisle, 0.0)
		var h := tris.surface(q.x, q.z, y_prev + 0.06)
		if h > -INF:
			y_prev = h
			down.append(Vector3(q.x, h, q.z))
		r -= 0.3
	for k in AMPHI_ROWS.size():
		var rf := float(AMPHI_ROWS[k][0])
		var top: float = (pt.call(rf, 0.0, float(AMPHI_ROWS[k][1])) as Vector3).y
		var floor_y := top - Crowd.SEAT_DROP
		var rw := rf * sx                                    # радиус переднего края в метрах
		var r_root := (rw - (PELVIS_IN - People.SIT_BACK)) / sx     # ступни: на 0,09 м перед краем сиденья
		# спуск по проходу до этого ряда, потом — по дуге ряда
		var via := PackedVector3Array()
		for q in down:
			if q.y < floor_y - 0.02 and via.size() > 2:
				break
			via.append(q)
		var at_row: Vector3 = pt.call(r_root, aisle, 0.0)
		via.append(Vector3(at_row.x, floor_y, at_row.z))
		for side: int in [-1, 1]:
			var gkey := "%s|%d|%d" % [str(c.snapped(Vector3.ONE * 0.01)) + str(xf.basis.z.snapped(Vector3.ONE * 0.01)), k, side]
			var list := []
			var hw := AMPHI_AISLE_HW * sx + 0.24
			var th_lo := 0.0 if side < 0 else aisle + hw / rw
			var th_hi := aisle - hw / rw if side < 0 else deg_to_rad(45.0)
			var span := (th_hi - th_lo) * rw
			var n := int(floor(span / SPACING))
			if n <= 0:
				continue
			var step := (th_hi - th_lo) / n
			for i in n:
				var th := th_lo + (i + 0.5) * step
				var E: Vector3 = pt.call(rf, th, 0.0)
				E.y = top
				var F := Vector3(c.x - E.x, 0, c.z - E.z).normalized()
				var pelvis := E - F * PELVIS_IN
				var root := pelvis + F * People.SIT_BACK
				var seat_y := _check(tris, pelvis, root, F, top, _amphi_drop)
				if seat_y == -INF:
					lay["dropped"] = int(lay.get("dropped", 0)) + 1
					continue
				root.y = seat_y - Crowd.SEAT_RISE
				# вдоль ряда от прохода к месту
				var path := via.duplicate()
				var a0 := aisle
				var steps := maxi(1, int(absf(th - a0) * r_root * sx / 0.3))
				for s in range(1, steps + 1):
					var tt := lerpf(a0, th, float(s) / steps)
					var q: Vector3 = pt.call(r_root, tt, 0.0)
					path.append(Vector3(q.x, floor_y, q.z))
				list.append({"root": root, "yaw": atan2(F.x, F.z), "row": k, "path": path, "far": absf(th - aisle)})
			list.sort_custom(func(x, y): return x["far"] > y["far"])     # дальние от прохода — первыми
			var ids := []
			for s in list:
				ids.append((lay["seats"] as Array).size())
				(lay["seats"] as Array).append(s)
			lay["groups"][gkey] = ids


## Скамья цирка (#bench: коробка 1×1×1, растянутая по скамье; лицо — +Z детали, к дорожке). Путь — из-под верхнего
## обхода на обход, вниз по ближней лестнице (за концом скамьи) и вдоль ряда
func _bench(lay: Dictionary, xf: Transform3D, tris: Tris) -> void:
	var ax := xf.basis.x
	var L := ax.length()
	var dir := ax / L
	var F := xf.basis.z.normalized()
	F.y = 0.0
	F = F.normalized()
	var top := (xf * Vector3(0, 0.5, 0)).y
	var front := xf * Vector3(0, 0.5, 0.5)
	front.y = top
	var n := int(floor((L - 0.2) / SPACING))
	if n <= 0:
		return
	var step := (L - 0.2) / n
	var rootline := front - F * PELVIS_IN + F * People.SIT_BACK
	var floor_y := top - Crowd.SEAT_DROP
	# лестницы — за концами скамьи: путь вверх от ряда до обхода (по ступеням), потом — обратно вниз
	var ups := []
	for e: float in [-1.0, 1.0]:
		var s0 := rootline + dir * e * (L * 0.5 + 0.33)
		s0.y = floor_y
		var pts := PackedVector3Array([s0])
		var y_prev := floor_y
		var q := s0
		for k in 40:
			q -= F * 0.12
			var h := tris.surface(q.x, q.z, y_prev + 0.45)
			if h == -INF or h < y_prev - 0.3:
				break
			y_prev = h
			pts.append(Vector3(q.x, h, q.z))
		var down := PackedVector3Array()
		var last := pts[pts.size() - 1]
		down.append(last - Vector3(0, 0.9, 0))               # из-под обхода, как по лестнице снизу
		for k in range(pts.size() - 1, -1, -1):
			down.append(pts[k])
		ups.append(down)
	var list := []
	for i in n:
		var E := front + dir * (-L / 2.0 + 0.1 + (i + 0.5) * step)
		var pelvis := E - F * PELVIS_IN
		var root := pelvis + F * People.SIT_BACK
		var seat_y := _check(tris, pelvis, root, F, top)
		if seat_y == -INF:
			lay["dropped"] = int(lay.get("dropped", 0)) + 1
			continue
		root.y = seat_y - Crowd.SEAT_RISE
		var e := 0 if i < n / 2 else 1
		var path: PackedVector3Array = (ups[e] as PackedVector3Array).duplicate()
		var s0 := path[path.size() - 1]
		var tgt := Vector3(root.x, floor_y, root.z)
		var m := maxi(1, int(s0.distance_to(tgt) / 0.3))
		for k in range(1, m + 1):
			path.append(s0.lerp(tgt, float(k) / m))
		list.append({"root": root, "yaw": atan2(F.x, F.z), "row": int(round((top - 0.0) / 0.36)), "path": path,
			"far": float(mini(i, n - 1 - i)) * -1.0})
	list.sort_custom(func(x, y): return x["far"] < y["far"])     # от середины скамьи (дальних от лестниц) — первыми
	var ids := []
	for s in list:
		ids.append((lay["seats"] as Array).size())
		(lay["seats"] as Array).append(s)
	lay["groups"]["bench%d" % (lay["groups"] as Dictionary).size()] = ids


## Путь от точки a по земле и ступеням к точке b (высоты — лучом сверху, не выше прежней + подъём ступени)
func _ground_path(tris: Tris, a: Vector3, b: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array([a])
	var n := maxi(1, int(a.distance_to(Vector3(b.x, a.y, b.z)) / 0.25))
	var y := a.y
	for k in range(1, n + 1):
		var q := a.lerp(b, float(k) / n)
		var h := tris.surface(q.x, q.z, y + 0.45)
		y = h if h > -INF else y
		out.append(Vector3(q.x, y, q.z))
	return out


## Над точкой открыто: до высоты up нет ни кровли, ни колонны, ни статуи (и рядом — на r в четыре стороны)
func _open(tris: Tris, p: Vector3, up: float, r := 0.22) -> bool:
	for o: Vector2 in [Vector2.ZERO, Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
		if tris.any_in(p.x + o.x, p.z + o.y, p.y + 0.06, p.y + up):
			return false
	return true


## Стоять можно и на ступенях: над самой точкой открыто до up, а рядом (на r в четыре стороны) ступени выше ног — до
## колена — не в счёт (у лестницы храма ступень 9 см при проступи 16 см), стены, колонны и статуи — в счёт
func _stand_open(tris: Tris, p: Vector3, up: float, r := 0.22) -> bool:
	if tris.any_in(p.x, p.z, p.y + 0.06, p.y + up):
		return false
	for o: Vector2 in [Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
		if tris.any_in(p.x + o.x, p.z + o.y, p.y + 0.3, p.y + up):
			return false
	return true


## Место не занято человеком при деле (жрец, служитель у алтаря): они стоят по чертежу, а не в Tris
func _free_of_actors(bp: Bp, x: float, z: float) -> bool:
	for a: Array in bp.actors:
		var p: Vector3 = a[0]
		if Vector2(p.x - x, p.z - z).length() < 0.55:
			return false
	return true


## По пути можно пройти: от колен до головы (над поверхностью под ногами) нет ни алтаря, ни статуи, ни стены
## (ступени ниже колен — по ним шагают)
func _path_clear(tris: Tris, path: PackedVector3Array, r := 0.15) -> bool:
	for q: Vector3 in path:
		for o: Vector2 in [Vector2.ZERO, Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
			if tris.any_in(q.x + o.x, q.z + o.y, q.y + 0.3, q.y + 1.5):
				return false
	return true


## Храм: утренняя служба — горожане стоят на ступенях и перед ними лицом к храму (к −Z), жрец наверху лестницы
## поднимает руки к ним. Места — где под ногами ступень или мостовая, а над головой открыто (не под портиком)
func _temple(lay: Dictionary, bp: Bp, tris: Tris) -> void:
	var door := bp.door
	var lo: Vector2 = tris.lo_xz
	var hi: Vector2 = tris.hi_xz
	var hw_in := minf(absf(lo.x), absf(hi.x)) - 0.3
	# перед узким храмом (NewTemple, 5 м) горожане встают на мостовой и чуть шире его следа (до 2,5 м в каждую сторону) —
	# мест почти столько же, сколько у прежнего; сбоку, в глубине следа — не шире храма (там может стоять сосед)
	var hw := maxf(hw_in, 2.5)
	# жрец: вверх по середине лестницы — где ступени кончились (подиум), там его место
	var y := 0.0
	var found := false
	var flat := 0.0
	var top := Vector3(0, 0, door.z)
	var z := door.z + 0.2
	while z > lo.y:
		var h := tris.surface(0.0, z, y + 0.45)
		if h == -INF:
			if found:
				break
			z -= 0.1
			continue
		found = true
		if h > y + 0.02:
			flat = 0.0
			top = Vector3(0, h, z)
		else:
			flat += 0.1
		y = maxf(y, h)
		if flat > 0.45 and y > 0.3:
			break                                # наверху лестницы (ровный двор перед ней — ещё не верх: у большого храма он в метр)
		z -= 0.1
	var list := []
	var x := -hw
	while x <= hw:
		z = top.z + 0.35
		while z < door.z + 3.2:
			if absf(x) > hw_in and z < hi.y + 0.15:
				z += STAND_GAP
				continue
			var h := tris.surface(x, z, top.y + 0.1)
			if h == -INF and z > top.z + 0.2:
				h = 0.0                          # перед храмом — мостовая (за чертежом): стоят и там
			var jx := x + rng.randf_range(-0.13, 0.13)          # не строем: чуть вразброс
			var jz := z + rng.randf_range(-0.1, 0.1)
			if h > -INF and absf(x) > 0.55 and _stand_open(tris, Vector3(jx, h, jz), 1.9) and rng.randf() < 0.88 and _free_of_actors(bp, jx, jz):
				var root := Vector3(jx, h, jz)
				# путь: с улицы — к своей «дорожке» перед храмом, по ней прямо к месту (вверх по ступеням); места,
				# к которым так не пройти (за алтарём, львом, щекой лестницы, в цветнике), пропускаем
				var a := Vector3(door.x + clampf(jx, -1.5, 1.5), 0.0, door.z + 3.6)
				var path := PackedVector3Array()
				if jz < door.z + 0.25:
					var m := Vector3(jx, 0.0, door.z + 0.25)
					path = _ground_path(tris, a, m)
					path.append_array(_ground_path(tris, path[path.size() - 1], root).slice(1))
				else:
					path = _ground_path(tris, a, root)
				if _path_clear(tris, path):
					var yaw := atan2(top.x - jx, top.z - jz) + rng.randf_range(-0.2, 0.2)     # лицом к жрецу
					list.append({"root": root, "yaw": yaw, "row": 0, "path": path, "far": -h * 10.0 + absf(x) * 0.1 + z * 0.3, "pose": "stand"})
			z += STAND_GAP
		x += STAND_GAP
	list.sort_custom(func(a, b): return a["far"] < b["far"])     # сначала выше по лестнице и ближе к середине
	if list.size() > TEMPLE_MAX:
		list.resize(TEMPLE_MAX)              # большой храм (NewTemple, 90 м²): служба — не толпа на полплощади
	var ids := []
	for s in list:
		ids.append((lay["seats"] as Array).size())
		(lay["seats"] as Array).append(s)
	lay["groups"]["temple"] = ids
	lay["fx"] = []
	for p in bp.parts:
		if String(p[0]) == "SM_Prop_Brazier_01":           # жаровни у лестницы: во время службы — дым благовоний
			var bx: Transform3D = p[1]
			(lay["fx"] as Array).append(["incense", bx.origin + Vector3(0, bx.basis.y.length() * 1.25, 0), Vector3.ZERO])
	if top.y > 0.2:
		lay["priest"] = {"root": top + Vector3(0, 0, -0.3), "yaw": 0.0, "row": 0, "path": PackedVector3Array(), "far": 0.0, "pose": "priest"}


## Термы: купальщики стоят в бассейнах по грудь в воде и болтают (#water — вода, коробка); входят от двери
func _bath(lay: Dictionary, bp: Bp, tris: Tris) -> void:
	var door := bp.door
	var list := []
	for p in bp.parts:
		if String(p[0]) != "#water":
			continue
		var xf: Transform3D = p[1]
		var sx := xf.basis.x.length()
		var sz := xf.basis.z.length()
		var c := xf.origin
		var wy := c.y + xf.basis.y.length() * 0.5
		if not lay.has("fx"):
			lay["fx"] = []
		(lay["fx"] as Array).append(["steam", Vector3(c.x, wy + 0.05, c.z), Vector3(sx, 0, sz)])
		var nx := maxi(1, int(floor((sx - 0.5) / 0.5)))
		var nz := maxi(1, int(floor((sz - 0.5) / 0.55)))
		for i in nx:
			for j in nz:
				var lp := Vector3(-sx / 2.0 + 0.25 + (i + 0.5) * (sx - 0.5) / nx, 0, -sz / 2.0 + 0.25 + (j + 0.5) * (sz - 0.5) / nz)
				var w := c + xf.basis.x.normalized() * lp.x + xf.basis.z.normalized() * lp.z
				var root := Vector3(w.x, wy - BATH_DEPTH, w.z)
				# к бассейну от двери, у края — вниз по ступеням в воду
				var edge := Vector3(w.x, 0.0, c.z + sz / 2.0 + 0.35)
				var path := PackedVector3Array([Vector3(door.x, 0.0, door.z + 0.6), edge, Vector3(w.x, wy - BATH_DEPTH * 0.5, c.z + sz / 2.0 - 0.3), root])
				var yaw := atan2(c.x - w.x + 0.01, c.z - w.z) + rng.randf_range(-0.6, 0.6)
				list.append({"root": root, "yaw": yaw, "row": 0, "path": path, "far": rng.randf(), "pose": "bath"})
	list.sort_custom(func(a, b): return a["far"] < b["far"])
	var ids := []
	for s in list:
		ids.append((lay["seats"] as Array).size())
		(lay["seats"] as Array).append(s)
	lay["groups"]["bath"] = ids


## Форум: оратор на рострах (#marble — помост посредине, самый широкий) лицом к площади, слушатели стоят на
## площади перед рострами лицом к нему (где над головой открыто — не под портиками)
func _forum(lay: Dictionary, bp: Bp, tris: Tris) -> void:
	var ro: Transform3D
	var best := 0.0
	for p in bp.parts:
		if String(p[0]) == "#marble":
			var x: Transform3D = p[1]
			if absf(x.origin.x) < 0.5 and x.basis.x.length() > best:
				best = x.basis.x.length()
				ro = x
	if best <= 0.0:
		return
	var top := ro.origin.y + ro.basis.y.length() * 0.5
	var front := ro.origin.z + ro.basis.z.length() * 0.5
	var spk := Vector3(0, top, front - 0.45)
	lay["priest"] = {"root": spk, "yaw": 0.0, "row": 0, "path": PackedVector3Array(), "far": 0.0, "pose": "orator"}
	var door := bp.door
	var hw := minf(absf(tris.lo_xz.x), absf(tris.hi_xz.x)) - 0.6
	var list := []
	var x := -hw
	while x <= hw:
		var z := front + 0.9
		while z < door.z - 0.2:
			var jx := x + rng.randf_range(-0.14, 0.14)
			var jz := z + rng.randf_range(-0.12, 0.12)
			var h := tris.surface(jx, jz, 0.6)
			if h > -INF and _open(tris, Vector3(jx, h, jz), 1.9) and rng.randf() < 0.85:
				var root := Vector3(jx, h, jz)
				var path := _ground_path(tris, Vector3(door.x + clampf(jx, -1.5, 1.5), 0.0, door.z + 0.6), root)
				var yaw := atan2(spk.x - jx, spk.z - jz) + rng.randf_range(-0.25, 0.25)
				list.append({"root": root, "yaw": yaw, "row": 0, "path": path, "far": jz + absf(jx) * 0.3, "pose": "stand"})
			z += STAND_GAP
		x += STAND_GAP
	list.sort_custom(func(a, b): return a["far"] < b["far"])     # сначала ближе к рострам
	var ids := []
	for s in list:
		ids.append((lay["seats"] as Array).size())
		(lay["seats"] as Array).append(s)
	lay["groups"]["forum"] = ids


## Таверна: посетители на стульях у круглых столиков и на скамьях у длинного стола (лицом к столу), двое-трое стоят
## во дворе друг к другу лицом — болтают у жаровни. Высота сиденья — по самой модели (луч сверху)
func _tavern(lay: Dictionary, bp: Bp, tris: Tris) -> void:
	var door := bp.door
	var tables := []
	for p in bp.parts:
		if String(p[0]).begins_with("SM_Prop_Table_0"):
			tables.append((p[1] as Transform3D).origin)
	if tables.is_empty():
		return
	var near_t := func(o: Vector3) -> Vector3:
		var best: Vector3 = tables[0]
		for t: Vector3 in tables:
			if Vector2(t.x, t.z).distance_to(Vector2(o.x, o.z)) < Vector2(best.x, best.z).distance_to(Vector2(o.x, o.z)):
				best = t
		return best
	var list := []
	for p in bp.parts:
		var nm := String(p[0])
		var x: Transform3D = p[1]
		var spots := []                          # [таз, лицом куда]
		if nm.begins_with("SM_Prop_Seat_Chair"):
			var t: Vector3 = near_t.call(x.origin)
			var F := Vector3(t.x - x.origin.x, 0, t.z - x.origin.z).normalized()
			spots.append([x.origin - F * 0.04, F])
		elif nm.begins_with("SM_Prop_Seat_Bench"):
			var t2: Vector3 = near_t.call(x.origin)
			var ax := x.basis.z.normalized()
			var F2 := ax if ax.dot(t2 - x.origin) > 0.0 else -ax
			var side := x.basis.x.normalized()
			var bb := Bp.model_aabb(nm)
			var mid := x * bb.get_center()               # у скамьи начало координат — не середина сиденья
			mid.y = x.origin.y
			var w := bb.size.x * x.basis.get_scale().x
			var n := 3 if w > 1.4 else 2
			for i in n:
				spots.append([mid + side * (i - (n - 1) / 2.0) * w * 0.3, F2])
		for e in spots:
			var pelvis: Vector3 = e[0]
			var F3: Vector3 = e[1]
			var seat := -INF                       # сиденье из реек: ищем верх рядом с тазом
			for o: Vector2 in [Vector2.ZERO, Vector2(0.07, 0), Vector2(-0.07, 0), Vector2(0, 0.07), Vector2(0, -0.07), Vector2(0.14, 0), Vector2(-0.14, 0)]:
				seat = maxf(seat, tris.surface(pelvis.x + o.x, pelvis.z + o.y, x.origin.y + 0.55))
			if seat == -INF or seat < x.origin.y + 0.2:
				continue
			var root := pelvis + F3 * People.SIT_BACK
			root.y = seat - Crowd.SEAT_RISE
			var path := PackedVector3Array([Vector3(door.x, 0, door.z + 0.4), Vector3(root.x - F3.x * 0.5, 0, root.z - F3.z * 0.5),
				Vector3(root.x, root.y + Crowd.SEAT_RISE - Crowd.SEAT_DROP, root.z)])
			list.append({"root": root, "yaw": atan2(F3.x, F3.z), "row": 0, "path": path, "far": rng.randf(), "pose": "sit"})
	# стоят у жаровни: пары лицом друг к другу
	var pairs := 0
	var z := door.z - 0.7
	while z > 0.6 and pairs < 2:
		for x0: float in [-2.0, 1.6]:
			if pairs >= 2:
				break
			var a := Vector3(x0, 0, z)
			var c := a + Vector3(0.55, 0, 0)
			var ha := maxf(tris.surface(a.x, a.z, 0.6), 0.0)    # двор — земля (у постройки под ним своих граней нет)
			var hc := maxf(tris.surface(c.x, c.z, 0.6), 0.0)
			if ha > 0.05 or hc > 0.05 or not _open(tris, Vector3(a.x, ha, a.z), 1.9) or not _open(tris, Vector3(c.x, hc, c.z), 1.9):
				continue
			for q: Array in [[Vector3(a.x, ha, a.z), PI / 2], [Vector3(c.x, hc, c.z), -PI / 2]]:
				var r0: Vector3 = q[0]
				list.append({"root": r0, "yaw": float(q[1]) + rng.randf_range(-0.2, 0.2), "row": 0,
					"path": _ground_path(tris, Vector3(door.x, 0.0, door.z + 0.4), r0), "far": 2.0 + rng.randf(), "pose": "stand"})
			pairs += 1
		z -= 0.8
	list.sort_custom(func(a2, b2): return a2["far"] < b2["far"])
	var ids := []
	for s2 in list:
		ids.append((lay["seats"] as Array).size())
		(lay["seats"] as Array).append(s2)
	lay["groups"]["tavern"] = ids


## Школа: ученики на скамьях (SM_Prop_Seat_Bench — лицом к учителю, +Z), учитель у своего кресла лицом к ним
func _school(lay: Dictionary, bp: Bp, tris: Tris) -> void:
	var door := bp.door
	var list := []
	var teacher := Vector3.INF
	for p in bp.parts:
		var nm := String(p[0])
		var x: Transform3D = p[1]
		if nm.begins_with("SM_Prop_Seat_Chair"):
			teacher = x.origin
		if not nm.begins_with("SM_Prop_Seat_Bench"):
			continue
		var box := Bp.model_aabb(nm)
		var sc := x.basis.get_scale()
		var w := box.size.x * sc.x
		var F := x.basis.z.normalized()
		var side := x.basis.x.normalized()
		var top := x.origin.y + minf(box.size.y, 0.5) * sc.y
		var n := 3 if w > 1.1 else 2
		for i in n:
			var o := (i - (n - 1) / 2.0) * w * 0.3
			var pelvis := x.origin + side * o
			var root := pelvis + F * People.SIT_BACK * 0.68
			root.y = top - Crowd.SEAT_RISE * 0.68
			var path := PackedVector3Array([Vector3(door.x, 0, door.z + 0.4), Vector3(root.x, 0, root.z + 0.45), Vector3(root.x, root.y + (Crowd.SEAT_RISE - Crowd.SEAT_DROP) * 0.68, root.z)])
			list.append({"root": root, "yaw": atan2(F.x, F.z), "row": 0, "path": path, "far": -x.origin.z + absf(o) * 0.1, "pose": "sit", "child": true})
	var ids := []
	for s in list:
		ids.append((lay["seats"] as Array).size())
		(lay["seats"] as Array).append(s)
	lay["groups"]["school"] = ids
	if teacher != Vector3.INF:
		lay["priest"] = {"root": Vector3(0, 0, teacher.z - 0.1), "yaw": PI, "row": 0, "path": PackedVector3Array(), "far": 0.0, "pose": "orator"}


## Театр и одеон: на сцене (#marble — самый широкий помост) — актёр или музыкант лицом к трибунам (к −Z)
func _stage(lay: Dictionary, bp: Bp) -> void:
	var st: Transform3D
	var best := 0.0
	for p in bp.parts:
		if String(p[0]) == "#marble":
			var x: Transform3D = p[1]
			if x.basis.y.length() > 0.2 and x.basis.x.length() > best:
				best = x.basis.x.length()
				st = x
	if best <= 0.0:
		return
	var top := st.origin.y + st.basis.y.length() * 0.5
	lay["priest"] = {"root": Vector3(st.origin.x, top, st.origin.z - st.basis.z.length() * 0.2), "yaw": PI, "row": 0,
		"path": PackedVector3Array(), "far": 0.0, "pose": "actor"}


## Можно ли сесть (высота сиденья по модели или −INF): под тазом — сиденье (у задуманной высоты top), под ступнями —
## ступень ниже ровно на Crowd.SEAT_DROP (ноги на ступени, а не в воздухе и не в камне), над ступнями и перед коленями
## ничего не торчит (парапет), над головой — пусто (навесы, статуи, жаровни)
var _amphi_drop := Crowd.SEAT_DROP


func _check(tris: Tris, pelvis: Vector3, root: Vector3, F: Vector3, top: float, drop := Crowd.SEAT_DROP) -> float:
	var seat := tris.surface(pelvis.x, pelvis.z, top + 0.05)
	if seat == -INF or absf(seat - top) > 0.06:
		return -INF
	if tris.any_in(pelvis.x, pelvis.z, seat + 0.04, seat + HEAD) or tris.any_in(pelvis.x + F.x * 0.08, pelvis.z + F.z * 0.08, seat + 0.3, seat + HEAD):
		return -INF
	var foot := root + F * 0.03
	var fl := tris.surface(foot.x, foot.z, seat - 0.05)
	if fl == -INF or absf(seat - fl - drop) > 0.035:
		return -INF
	if tris.any_in(foot.x, foot.z, fl + 0.05, seat + 0.45):
		return -INF
	var knee := pelvis + F * 0.16
	if tris.any_in(knee.x, knee.z, seat + 0.03, seat + 0.45):
		return -INF
	return seat


## Порядок, в котором занимают места: по группам (ряд, сторона прохода) — от дальних к проходу; группы вперемешку,
## нижние ряды чуть раньше верхних
func _fill_order(lay: Dictionary) -> Array:
	var queues := []
	for k in lay["groups"]:
		var ids: Array = lay["groups"][k]
		if not ids.is_empty():
			queues.append(ids.duplicate())
	var out := []
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	while not queues.is_empty():
		var tot := 0.0
		for q: Array in queues:
			tot += 1.0 / (1.0 + 0.12 * int((lay["seats"][q[0]] as Dictionary)["row"]))
		var x := r.randf() * tot
		var pick := 0
		for i in queues.size():
			x -= 1.0 / (1.0 + 0.12 * int((lay["seats"][queues[i][0]] as Dictionary)["row"]))
			if x <= 0.0:
				pick = i
				break
		var q: Array = queues[pick]
		out.append(q.pop_front())
		if q.is_empty():
			queues.remove_at(pick)
	return out


# ---------- звук ----------

static func stream(name: String, loop := false) -> AudioStream:
	var key := name + str(loop)
	if not _streams.has(key):
		var path := "res://assets/sfx/" + name
		var st: AudioStream = load(path) if ResourceLoader.exists(path) else null
		if st is AudioStreamOggVorbis and loop:
			st = st.duplicate()
			(st as AudioStreamOggVorbis).loop = true
		_streams[key] = st
	return _streams[key]


## Звук зрелища в точке (удар, звон щита, крик трибун, скрип ворот); не больше 10 сразу
func _on_sfx(kind: String, at: Vector3, vol: float) -> void:
	if not SND.has(kind) or _shots >= 10:
		return
	var e: Array = SND[kind]
	var nm = e[0]
	if nm is Array:
		nm = nm[rng.randi() % (nm as Array).size()]
	var st := stream(nm)
	if st == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = st
	p.bus = "SFX"
	p.unit_size = 10.0
	p.max_distance = 150.0
	p.volume_db = float(e[1]) + linear_to_db(maxf(vol, 0.05))
	p.pitch_scale = rng.randf_range(0.93, 1.07)
	add_child(p)
	p.global_position = at
	_shots += 1
	p.finished.connect(func():
		_shots -= 1
		p.queue_free())
	p.play()


# ---------- ворота арены ----------

## Створки ворот арены (в проёмах SM_Bld_Wall_Door_Large_01 у самой арены) и огонь в проходе за ними: закрытые
## ворота — дерево, открытые — освещённый ход, а не чёрная дыра. Открывает бой (gate_open)
func _gates(V: Dictionary, bp: Bp) -> void:
	var walls := []
	var fresh := NewArena.covers(String(V["type"]))      # новый амфитеатр: рамы ворот — из NewArena, проход за ними открыт небу
	if fresh:
		for xf: Transform3D in NewArena.gate_frames():
			walls.append([0.0, xf])
	else:
		for p in bp.parts:
			if p[0] == "SM_Bld_Wall_Door_Large_01":
				var o: Vector3 = (p[1] as Transform3D) * Vector3(1.25, 0, 0)
				walls.append([Vector2(o.x, o.z).length(), p[1]])
		walls.sort_custom(func(x, y): return x[0] < y[0])
	V["gates"] = []
	var root: Node3D = V["root"]
	for w in walls.slice(0, 2):
		var xf: Transform3D = w[1]
		var leaves := []
		for k in 2:
			var n := Synty.make("SM_Bld_Door_Large_Half_0%d" % (1 + k), {})
			root.add_child(n)
			leaves.append(n)
		var c: Vector3 = xf * Vector3(1.25, 0, 0)
		var inward := (xf.basis.z).normalized()               # лицом к арене
		var g := {"xf": xf, "leaves": leaves, "a": 0.0, "to": 0.0, "c": c, "in": inward}
		V["gates"].append(g)
		_door_pose(g)
		if fresh:
			continue                                          # днём проход светлый и так; лишних источников света нет
		var lt := OmniLight3D.new()
		lt.light_color = Color(1.0, 0.72, 0.42)
		lt.light_energy = 1.6
		lt.omni_range = 2.4
		lt.shadow_enabled = false
		root.add_child(lt)
		lt.position = c - inward * 1.3 + Vector3(0, 1.35, 0)
		var torch := Synty.make("SM_Prop_Torch_01")
		root.add_child(torch)
		torch.transform = Transform3D(Basis.looking_at(-inward).scaled(Vector3.ONE * 0.8), c - inward * 1.75 + Vector3(0, 1.25, 0) + (xf.basis.x).normalized() * 0.55)


func _door_pose(g: Dictionary) -> void:
	var xf: Transform3D = g["xf"]
	var a: float = g["a"]
	(g["leaves"][0] as Node3D).transform = xf * Transform3D(Basis(Vector3.UP, a), Vector3(0.69, 0, 0))
	(g["leaves"][1] as Node3D).transform = xf * Transform3D(Basis(Vector3.UP, PI - a), Vector3(1.81, 0, 0))


## Открыть (закрыть) ворота i арены
func gate_open(V: Dictionary, i: int, open: bool) -> void:
	var gs: Array = V.get("gates", [])
	if i < gs.size():
		gs[i]["to"] = 1.65 if open else 0.0
		if open:
			sfx.emit("gate", (V["root"] as Node3D).to_global(gs[i]["c"]), 0.6)


## Точка в проходе за воротами i (на d за створками), на полу арены
func gate_point(V: Dictionary, i: int, d: float) -> Vector3:
	var gs: Array = V.get("gates", [])
	if i >= gs.size():
		return Vector3.ZERO
	return (gs[i]["c"] as Vector3) - (gs[i]["in"] as Vector3) * d


func _doors_step(V: Dictionary, dt: float) -> void:
	for g: Dictionary in V.get("gates", []):
		if absf(float(g["a"]) - float(g["to"])) > 0.001:
			g["a"] = move_toward(float(g["a"]), float(g["to"]), dt * 1.4)
			_door_pose(g)


# ---------- расписание ----------

## Час представления по расписанию площадки (или вручную: force)
func _phase_of(V: Dictionary) -> String:
	if V["forced"] != "":
		return V["forced"]
	var hs: Array = VENUES[V["type"]]["hours"]
	var h: float = game.hour
	if h >= float(hs[0]) and h < float(hs[1]):
		return "gather"
	if h >= float(hs[1]) and h < float(hs[2]):
		return "show"
	if h >= float(hs[2]) and h < float(hs[3]):
		return "leave"
	return "idle"


## Вручную (ролик, проверки): phase — gather / show / leave / idle; fill — доля мест; instant — сразу рассадить
func force(bid: int, phase: String, fill := -1.0, instant := false) -> void:
	var V: Dictionary = venues.get(bid, {})
	if V.is_empty():
		return
	V["forced"] = phase
	if fill >= 0.0:
		V["fill_k"] = fill
	_target(V)                               # пора могла уже идти (по часам): цель — по новой доле мест
	if instant:
		while (V["who"] as Array).size() < int(V["target"]) and int(V["oi"]) < (V["order"] as Array).size():
			_arrive(V, {}, true)


func _target(V: Dictionary) -> void:
	var n: int = (V["lay"]["seats"] as Array).size()
	V["target"] = int(round(n * float(V.get("fill_k", VENUES[V["type"]]["fill"])) * _q_fill()))


## На «Низкой» и «Очень низкой» графике зрителей меньше (как и жителей на улицах — Gfx.VIS); съёмка ролика — всегда полно
func _q_fill() -> float:
	if game.promo:
		return 1.0
	match str(game.settings.get("quality", "high")):
		"low":
			return 0.55
		"verylow":
			return 0.35
	return 1.0


func _process(dt: float) -> void:
	if game == null or not game.ready_done or paused or game.mode == "menu":
		return                               # за главным меню представлений нет: фон не тратит кадры
	var us0 := Time.get_ticks_usec()
	_step(dt)
	if _perf:
		_perf_us += Time.get_ticks_usec() - us0
		_perf_t += dt
		_perf_n += 1
		if _perf_t >= 4.0:
			var n := 0
			for id in venues:
				n += (venues[id]["who"] as Array).size()
			print("SPECTACLE_PERF fps %.1f (кадр %.1f мс, из них зрелища %.2f мс), зрителей %d, жителей на улицах %d" % [_perf_n / _perf_t,
				1000.0 * _perf_t / _perf_n, _perf_us / 1000.0 / _perf_n, n, game.people.visible_count if game.people else 0])
			_perf_t = 0.0
			_perf_n = 0
			_perf_us = 0


func _step(dt: float) -> void:
	if game.people:
		visible = game.people.visible         # зрители — те же жители: прячут жителей (проверки, ролики) — прячутся и они
	speed = maxf(game.speed, 0.0) if not game.promo else 1.0
	var sdt := dt * speed
	if sdt <= 0.0:
		return
	var cam := get_viewport().get_camera_3d()
	for id in venues:
		var V: Dictionary = venues[id]
		if cam:
			var d := cam.global_position.distance_to((V["root"] as Node3D).global_position)
			(V["crowd"] as Crowd).set_shadows(d < SHADOW_D and not Gfx.is_low(str(game.settings.get("quality", "high"))))
		var ph := _phase_of(V)
		if ph != V["phase"]:
			_enter_phase(V, ph)
		match ph:
			"gather":
				_gather_step(V, sdt)
			"show":
				_late_step(V)
			"leave":
				_leave_step(V, sdt)
		_people_step(V, sdt)
		_doors_step(V, sdt)
		if V.has("priest_cp"):
			V["priest_t"] = float(V.get("priest_t", 4.0)) - sdt
			if float(V["priest_t"]) <= 0.0:
				V["priest_t"] = rng.randf_range(3.5, 7.0)
				(V["crowd"] as Crowd).play(V["priest_cp"], _idle_clip(V, V["lay"]["priest"]))
		var mur: AudioStreamPlayer3D = V["murmur"]
		var full := float((V["who"] as Array).size()) / maxf(1.0, float((V["lay"]["seats"] as Array).size()))
		var want := -80.0 if full <= 0.01 else linear_to_db(clampf(full, 0.08, 1.0)) - 4.0
		mur.volume_db = lerpf(mur.volume_db, want, minf(1.0, dt * 2.0))
		if want > -60.0 and not mur.playing:
			mur.play(randf() * 10.0)
		elif want <= -60.0 and mur.playing and mur.volume_db < -60.0:
			mur.stop()
		if V["act"] != null:
			V["act"].tick(sdt, ph)
	_proc_step(dt, sdt)


## Советник один раз, когда в городе впервые собираются на представление: что происходит и куда смотреть
func _first_tip(V: Dictionary) -> void:
	if game.mode != "play" and game.mode != "new":
		return
	if not (V["kind"] in SHOWS):
		return
	var hud = game.hud
	if hud == null or city.tips.has("spectacle_tip") or not hud._tip_free() or not hud._screen_free():
		return
	if game.tutorial and game.tutorial.active():
		return
	city.tips["spectacle_tip"] = true
	var what := {"arena": "в амфитеатре — бои гладиаторов", "circus": "в цирке — скачки колесниц", "theatre": "в театре — спектакль"}
	hud.advisor("Зрелища", "Скоро %s. Горожане сами идут смотреть: заходят внутрь и рассаживаются по трибунам, остальные места занимают гости из округи. Подведите камеру поближе — посмотрите, как трибуны хлопают на удачный удар. Расписание: амфитеатр — днём, цирк — утром, театр — вечером." % what.get(V["kind"], "представление"))


func _enter_phase(V: Dictionary, ph: String) -> void:
	var old: String = V["phase"]
	V["phase"] = ph
	if ph == "gather" and V["kind"] == "arena":
		_procession(V)
	_priest(V, ph != "idle")
	_fx(V, ph != "idle")
	match ph:
		"gather":
			_target(V)
			V["due"] = 0.0
			V["called"] = false
			_first_tip(V)
			sfx.emit("horn", (V["root"] as Node3D).global_position + Vector3(0, 6, 0), 0.6)
		"show":
			_target(V)
			if old == "idle":
				# представление уже идёт (игру загрузили посреди дня) — зрители на местах
				while (V["who"] as Array).size() < int(V["target"]) and int(V["oi"]) < (V["order"] as Array).size():
					_arrive(V, {}, true)
		"leave":
			# конец представления: овация, потом встают и расходятся
			V["due"] = 0.0
			V["wait"] = 3.5
			if (V["who"] as Array).size() > 0 and V["kind"] in SHOWS:
				react(V, 0.9, 3.5)
				sfx.emit("roar", (V["root"] as Node3D).global_position + Vector3(0, 3, 0), 1.0)
		"idle":
			_release_all(V)
	if V["act"] != null:
		V["act"].phase(ph)


## Жрец храма наверху лестницы (лицом к людям, руки к небу): с начала сбора до конца расхода
func _priest(V: Dictionary, on: bool) -> void:
	var pr: Dictionary = (V["lay"] as Dictionary).get("priest", {})
	if pr.is_empty():
		return
	var cr: Crowd = V["crowd"]
	if on and not V.has("priest_cp"):
		var lk := Citizen.roll_look(rng, rng.randf() < 0.4 and String(pr["pose"]) == "actor", false, true, "", "patricians")
		V["priest_cp"] = cr.add(lk, _seat_xf(pr), _idle_clip(V, pr), Crowd.now() - rng.randf() * 3.0, false)
		V["priest_t"] = 4.0
	elif not on and V.has("priest_cp"):
		cr.remove(V["priest_cp"])
		V.erase("priest_cp")


## Дым благовоний у храма и пар над бассейнами терм — пока площадка живёт (не на «Очень низкой»)
func _fx(V: Dictionary, on: bool) -> void:
	if on and not V.has("fx") and not str(game.settings.get("quality", "high")) == "verylow":
		var list := []
		for e: Array in (V["lay"] as Dictionary).get("fx", []):
			var p: GPUParticles3D = game._smoke((V["root"] as Node3D).global_transform * (e[1] as Vector3))
			var pm := p.process_material as ParticleProcessMaterial
			if String(e[0]) == "incense":
				p.amount = 12
				p.lifetime = 5.0
				pm.initial_velocity_min = 0.45
				pm.initial_velocity_max = 0.7
			else:                                # пар: низко, широко, медленно, над всей водой
				var sz: Vector3 = e[2]
				p.amount = maxi(6, int(sz.x * sz.z * 1.5))
				p.lifetime = 3.5
				pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
				pm.emission_box_extents = Vector3(sz.x * 0.4, 0.02, sz.z * 0.4)
				pm.direction = Vector3(0, 1, 0)
				pm.initial_velocity_min = 0.08
				pm.initial_velocity_max = 0.18
				pm.gravity = Vector3(0.03, 0.02, 0.0)
				pm.scale_min = 0.35
				pm.scale_max = 0.6
				var grad := Gradient.new()
				grad.set_color(0, Color(1, 1, 1, 0.16))
				grad.set_color(1, Color(1, 1, 1, 0.0))
				var gt := GradientTexture1D.new()
				gt.gradient = grad
				pm.color_ramp = gt
			list.append(p)
		V["fx"] = list
	elif not on and V.has("fx"):
		for p: Node in V["fx"]:
			if is_instance_valid(p):
				p.queue_free()
		V.erase("fx")


## Сбор: зовём горожан к входу, гостей сажаем понемногу (за час — все). На ×1 час — 15 с
func _gather_step(V: Dictionary, sdt: float) -> void:
	if not V["called"]:
		V["called"] = true
		if game.people and not no_residents:
			_call_residents(V)
	var hs: Array = VENUES[V["type"]]["hours"]
	var hours := maxf(0.2, float(hs[1]) - float(hs[0])) if V["forced"] == "" else 1.0
	var secs: float = hours * game.DAY_LEN / 24.0
	var rate := float(V["target"]) / maxf(secs * 0.85, 1.0)
	V["due"] = float(V["due"]) + sdt * rate
	while float(V["due"]) >= 1.0 and (V["who"] as Array).size() < int(V["target"]):
		V["due"] = float(V["due"]) - 1.0
		var r := {}
		while not (V["rid_q"] as Array).is_empty():
			var rid: int = (V["rid_q"] as Array).pop_front()
			r = game.people.by_id.get(rid, {})
			if not r.is_empty():
				break
		if not _arrive(V, r, false):
			break


## Опоздавшие горожане (дошли до входа, когда уже началось) — тоже на трибуну, если есть место
func _late_step(V: Dictionary) -> void:
	var q: Array = V["rid_q"]
	while not q.is_empty():
		var r: Dictionary = game.people.by_id.get(int(q.pop_front()), {})
		if r.is_empty():
			continue
		if not _arrive(V, r, false):
			game.people.show_out(r)


## Расход: зрители встают и уходят тем же путём (сначала ближние к проходу), жители выходят из дверей
func _leave_step(V: Dictionary, sdt: float) -> void:
	if float(V.get("wait", 0.0)) > 0.0:
		V["wait"] = float(V["wait"]) - sdt
		return
	var hs: Array = VENUES[V["type"]]["hours"]
	var secs: float = maxf(0.2, float(hs[3]) - float(hs[2])) * game.DAY_LEN / 24.0
	var rate := maxf(4.0, (V["who"] as Array).size() / maxf(secs * 0.6, 1.0))
	V["due"] = float(V["due"]) + sdt * rate
	var who: Array = V["who"]
	for i in range(who.size() - 1, -1, -1):
		if float(V["due"]) < 1.0:
			break
		var s: Dictionary = who[i]
		if s["st"] == "sit":
			V["due"] = float(V["due"]) - 1.0
			_stand_up(V, s)


## Горожане, свободные сейчас (дома, без дела на улице), — к входу постройки; ближние охотнее
func _call_residents(V: Dictionary) -> void:
	var ppl = game.people
	var b: Dictionary = V["b"]
	var door: Vector2 = city.door_point(b)
	var want := int(V["target"]) / 3
	var cands := []
	var school: bool = V["kind"] == "school"
	for r: Dictionary in ppl.residents:
		if r.has("hero") or int(r["home"]) <= 0 or r["state"] != "home":
			continue
		if school != bool(r["child"]):
			if school or rng.randf() < 0.7 or V["kind"] == "tavern":
				continue                         # в таверну детей не берут                         # в школу — только дети; на зрелища дети ходят реже взрослых
		var h: Dictionary = city.buildings.get(r["home"], {})
		if h.is_empty():
			continue
		var d := (h["pos"] as Vector2).distance_to(door)
		if d > 110.0:
			continue
		cands.append([d + rng.randf() * 25.0, r])
	cands.sort_custom(func(x, y): return x[0] < y[0])
	for e in cands.slice(0, want):
		ppl.show_call(e[1], b)


## Житель дошёл до входа и скрылся внутри (People): через пару секунд он — на трибуне
func admit(r: Dictionary, bid: int) -> void:
	var V: Dictionary = venues.get(bid, {})
	if V.is_empty():
		return
	(V["rid_q"] as Array).push_front(int(r["id"]))
	V["due"] = float(V["due"]) + 1.0


# ---------- зрители ----------

## Новый зритель: следующее по очереди место, облик жителя r (или гостя), путь к месту. instant — сразу сидит
func _arrive(V: Dictionary, r: Dictionary, instant: bool) -> bool:
	var order: Array = V["order"]
	while int(V["oi"]) < order.size() and (V["taken"] as Dictionary).has(order[V["oi"]]):
		V["oi"] = int(V["oi"]) + 1
	if int(V["oi"]) >= order.size():
		return false
	var si: int = order[V["oi"]]
	V["oi"] = int(V["oi"]) + 1
	var seat: Dictionary = V["lay"]["seats"][si]
	var lk: Dictionary
	var child := false
	if not r.is_empty():
		lk = game.people.look_of(r)
		child = bool(r["child"])
		city.note_visit(int(r.get("home", 0)), String(V["kind"]))   # «Уютный Рим»: семья сходила — дому счастье
	elif V["kind"] == "school":
		lk = Citizen.roll_look(rng, rng.randf() < 0.5, true)
		child = true
	else:
		lk = _guest_look()
	var cr: Crowd = V["crowd"]
	var s := {"seat": si, "rid": int(r.get("id", 0)), "t": 0.0, "u": 0.0, "i": 0}
	(V["taken"] as Dictionary)[si] = s
	(V["who"] as Array).append(s)
	var path: PackedVector3Array = seat["path"]
	if instant or path.size() < 2:
		s["st"] = "sit"
		s["cp"] = cr.add(lk, _seat_xf(seat), _idle_clip(V, seat), Crowd.now() - rng.randf() * 4.0, child)
		s["next"] = rng.randf_range(2.0, 9.0)
	else:
		s["st"] = "walk"
		s["path"] = path
		s["lane"] = rng.randf_range(-0.16, 0.16)
		s["cp"] = cr.add(lk, _walk_xf(V, s), "walk", Crowd.now() - rng.randf(), child)
	return true


func _seat_xf(seat: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, float(seat["yaw"])), seat["root"])


## Где идущий: точка пути (со сдвигом в своей «полосе» прохода), лицом по ходу
func _walk_xf(V: Dictionary, s: Dictionary) -> Transform3D:
	var path: PackedVector3Array = s["path"]
	var i: int = s["i"]
	var a := path[i]
	var b := path[mini(i + 1, path.size() - 1)]
	var p := a.lerp(b, float(s["u"]))
	var d := b - a
	d.y = 0.0
	if d.length() < 1e-4:
		d = Vector3(0, 0, 1)
	d = d.normalized()
	var side := Vector3(d.z, 0, -d.x)
	var lane: float = s.get("lane", 0.0) * (1.0 - smoothstep(path.size() - 4.0, path.size() - 1.0, float(i) + float(s["u"])))
	return Transform3D(Basis(Vector3.UP, atan2(d.x, d.z)), p + side * lane)


func _people_step(V: Dictionary, sdt: float) -> void:
	var cr: Crowd = V["crowd"]
	var who: Array = V["who"]
	var lay: Dictionary = V["lay"]
	var gone := []
	for s: Dictionary in who:
		match s["st"]:
			"walk", "out":
				var path: PackedVector3Array = s["path"]
				var i: int = s["i"]
				var a := path[i]
				var b := path[mini(i + 1, path.size() - 1)]
				var seg := maxf(a.distance_to(b), 0.001)
				var v := (WALK_STAIRS if absf(b.y - a.y) > 0.05 else WALK) * (1.25 if s["st"] == "out" else 1.0)
				s["u"] = float(s["u"]) + sdt * v / seg
				while float(s["u"]) >= 1.0 and int(s["i"]) < path.size() - 2:
					s["u"] = float(s["u"]) - 1.0
					s["i"] = int(s["i"]) + 1
				if int(s["i"]) >= path.size() - 2 and float(s["u"]) >= 1.0:
					if s["st"] == "out":
						gone.append(s)
						continue
					s["st"] = "turn"
					s["t"] = 0.0
					var xf := _walk_xf(V, s)
					s["yaw0"] = xf.basis.get_euler().y
					cr.play(s["cp"], "stand")
				cr.move(s["cp"], _walk_xf(V, s))
			"turn":
				# у своего места: повернуться лицом к арене и сесть
				s["t"] = float(s["t"]) + sdt
				var seat: Dictionary = lay["seats"][s["seat"]]
				var k := clampf(float(s["t"]) / 0.35, 0.0, 1.0)
				var yaw := lerp_angle(float(s["yaw0"]), float(seat["yaw"]), k * k * (3.0 - 2.0 * k))
				var root: Vector3 = seat["root"]
				var stands := String(seat.get("pose", "sit")) != "sit"
				cr.move(s["cp"], Transform3D(Basis(Vector3.UP, yaw), root + (Vector3.ZERO if stands else Vector3(0, Crowd.SEAT_RISE - Crowd.SEAT_DROP, 0))))
				if k >= 1.0 and stands:
					s["st"] = "sit"                  # стоит на месте (храм, бассейн): сразу своим делом
					s["next"] = rng.randf_range(3.0, 8.0)
					cr.play(s["cp"], _idle_clip(V, seat))
				elif k >= 1.0:
					s["st"] = "sitdown"
					s["t"] = 0.0
					cr.move(s["cp"], _seat_xf(seat))
					cr.play(s["cp"], "enter")
			"sitdown":
				s["t"] = float(s["t"]) + sdt
				if float(s["t"]) >= Crowd.clip_len("enter") - 0.05:
					s["st"] = "sit"
					s["next"] = rng.randf_range(3.0, 8.0)
					cr.play(s["cp"], _idle_clip(V, lay["seats"][s["seat"]]))
			"sit":
				s["next"] = float(s["next"]) - sdt
				if float(s["next"]) <= 0.0:
					s["next"] = rng.randf_range(4.0, 11.0)
					cr.play(s["cp"], _idle_clip(V, lay["seats"][s["seat"]]))
			"cheer":
				s["next"] = float(s["next"]) - sdt
				if float(s["next"]) <= 0.0:
					s["st"] = "sit"
					s["next"] = rng.randf_range(3.0, 9.0)
					cr.play(s["cp"], _idle_clip(V, lay["seats"][s["seat"]]))
			"standup":
				s["t"] = float(s["t"]) + sdt
				if float(s["t"]) >= 0.45:
					s["st"] = "out"
					cr.play(s["cp"], "walk")
	for s: Dictionary in gone:
		_drop(V, s)


## Встать и уйти: путь к месту — в обратную сторону
func _stand_up(V: Dictionary, s: Dictionary) -> void:
	var seat: Dictionary = V["lay"]["seats"][s["seat"]]
	var path: PackedVector3Array = seat["path"]
	var back := PackedVector3Array()
	for i in range(path.size() - 1, -1, -1):
		back.append(path[i])
	if back.size() < 2:
		_drop(V, s)
		return
	s["path"] = back
	s["i"] = 0
	s["u"] = 0.0
	s["lane"] = rng.randf_range(-0.16, 0.16)
	s["st"] = "standup"
	s["t"] = 0.0
	var cr: Crowd = V["crowd"]
	if String(seat.get("pose", "sit")) != "sit":
		s["st"] = "out"                          # стоял (храм, бассейн) — сразу уходит
		cr.play(s["cp"], "walk")
		return
	cr.move(s["cp"], Transform3D(Basis(Vector3.UP, float(seat["yaw"])), (seat["root"] as Vector3) + Vector3(0, Crowd.SEAT_RISE - Crowd.SEAT_DROP, 0)))
	cr.play(s["cp"], "stand")


func _drop(V: Dictionary, s: Dictionary) -> void:
	(V["crowd"] as Crowd).remove(s["cp"])
	(V["taken"] as Dictionary).erase(s["seat"])
	(V["who"] as Array).erase(s)
	if int(s["rid"]) > 0 and game.people:
		var r: Dictionary = game.people.by_id.get(int(s["rid"]), {})
		if not r.is_empty():
			game.people.show_out(r)


func _release_all(V: Dictionary) -> void:
	for s: Dictionary in (V["who"] as Array).duplicate():
		_drop(V, s)
	if game.people:
		for rid: int in V["rid_q"]:
			var r: Dictionary = game.people.by_id.get(rid, {})
			if not r.is_empty():
				game.people.show_out(r)
	V["oi"] = 0
	V["rid_q"] = []


## Чем занят сидящий: сидит спокойно, разговорился с соседом, оглядывается; во время боя — подался вперёд
func _idle_clip(V: Dictionary, seat := {}) -> String:
	match String(seat.get("pose", "sit")):
		"priest":
			return "pray" if rng.randf() < 0.7 else "s_talk"
		"orator", "actor":                       # говорит с ростр, играет на сцене: жесты обеими руками, иногда — руки к небу
			var z := rng.randf()
			return "s_talk" if z < 0.42 else ("s_talk_m" if z < 0.84 else "pray")
		"stand":                                 # на службе: слушают жреца, кивают, перешёптываются
			var y := rng.randf()
			return "listen" if y < 0.45 else ("stand" if y < 0.75 else ("s_talk" if y < 0.88 else "s_talk_m"))
		"bath":                                  # в бассейне: болтают, оглядываются
			var y2 := rng.randf()
			return "s_talk" if y2 < 0.35 else ("s_talk_m" if y2 < 0.6 else ("listen" if y2 < 0.8 else "stand"))
	var show: bool = V["phase"] == "show"
	var x := rng.randf()
	if show and x < 0.22:
		return "lean"
	if V["kind"] == "tavern" and x < 0.45:
		return "drink" if rng.randf() < 0.5 else "drink_m"          # в таверне пьют вино за столом
	x = rng.randf()
	if x < 0.32:
		return "sit"
	if x < 0.52:
		return "sit_m"
	if x < 0.76:
		return "talk"
	return "talk_m"


## Удачный удар, обгон, финал: часть зрителей хлопает и кричит (k — доля, near — ближе к точке охотнее)
func react(V: Dictionary, k: float, dur := 3.0, at := Vector3.INF) -> void:
	var cr: Crowd = V["crowd"]
	var lay: Dictionary = V["lay"]
	for s: Dictionary in V["who"]:
		if s["st"] != "sit" and s["st"] != "cheer":
			continue
		var kk := k
		if at != Vector3.INF:
			var d := (lay["seats"][s["seat"]]["root"] as Vector3).distance_to(at)
			kk *= 1.3 - clampf(d / 20.0, 0.0, 0.8)
		if rng.randf() > kk:
			continue
		s["st"] = "cheer"
		s["next"] = dur * rng.randf_range(0.7, 1.3)
		var c: String = ["clap", "clap", "cheer", "cheer_m"][rng.randi() % 4]
		cr.play(s["cp"], c, rng.randf() * 0.3)


## Облик гостя из округи: как у горожан (сословия вперемешку, больше простых)
func _guest_look() -> Dictionary:
	var rich := rng.randf() < 0.18
	var art := not rich and rng.randf() < 0.3
	var fem := rng.randf() < 0.42
	var cls := "patricians" if rich else ("artisans" if art else "plebs")
	return Citizen.roll_look(rng, fem, false, rich, "", cls)


func count(bid: int) -> int:
	var V: Dictionary = venues.get(bid, {})
	return 0 if V.is_empty() else (V["who"] as Array).size()


func venue_of(type: String) -> Dictionary:
	for id in venues:
		if venues[id]["type"] == type:
			return venues[id]
	return {}


# ---------- треугольники постройки: высоты по вертикальным лучам ----------

class Tris:
	const CELL := 0.5
	var v := PackedVector3Array()          # по три вершины
	var cells := []                        # клетка → номера треугольников (Array)
	var ox := 0.0
	var oz := 0.0
	var nx := 0
	var nz := 0
	var count := 0
	var lo_xz := Vector2.ZERO               # границы треугольников по x и z (в осях постройки)
	var hi_xz := Vector2.ZERO

	## Все треугольники чертежа (в осях постройки), кроме отвесных: им вертикальный луч не нужен
	func build(bp: Bp) -> void:
		var gh := Parts.ghost(bp, "place")
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for mi: MeshInstance3D in gh.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null:
				continue
			var xf := Citizen._rel(mi, gh)
			var f := mi.mesh.get_faces()
			for i in range(0, f.size(), 3):
				var a := xf * f[i]
				var b := xf * f[i + 1]
				var c := xf * f[i + 2]
				var n := (b - a).cross(c - a)
				if n.length_squared() < 1e-10 or absf(n.normalized().y) < 0.08:
					continue
				v.append(a)
				v.append(b)
				v.append(c)
				lo.x = minf(lo.x, minf(a.x, minf(b.x, c.x)))
				lo.y = minf(lo.y, minf(a.z, minf(b.z, c.z)))
				hi.x = maxf(hi.x, maxf(a.x, maxf(b.x, c.x)))
				hi.y = maxf(hi.y, maxf(a.z, maxf(b.z, c.z)))
		gh.free()
		lo_xz = lo
		hi_xz = hi
		count = v.size() / 3
		ox = lo.x
		oz = lo.y
		nx = int(ceil((hi.x - lo.x) / CELL)) + 1
		nz = int(ceil((hi.y - lo.y) / CELL)) + 1
		var lists := []
		lists.resize(nx * nz)
		for t in count:
			var a := v[t * 3]
			var b := v[t * 3 + 1]
			var c := v[t * 3 + 2]
			var x0 := int((minf(a.x, minf(b.x, c.x)) - ox) / CELL)
			var x1 := int((maxf(a.x, maxf(b.x, c.x)) - ox) / CELL)
			var z0 := int((minf(a.z, minf(b.z, c.z)) - oz) / CELL)
			var z1 := int((maxf(a.z, maxf(b.z, c.z)) - oz) / CELL)
			for zi in range(z0, z1 + 1):
				for xi in range(x0, x1 + 1):
					var k := zi * nx + xi
					if lists[k] == null:
						lists[k] = []
					(lists[k] as Array).append(t)
		cells = lists

	## Высоты всех поверхностей над точкой (x, z)
	func heights(x: float, z: float) -> PackedFloat32Array:
		var out := PackedFloat32Array()
		var xi := int((x - ox) / CELL)
		var zi := int((z - oz) / CELL)
		if xi < 0 or zi < 0 or xi >= nx or zi >= nz:
			return out
		var lst = cells[zi * nx + xi]
		if lst == null:
			return out
		for t: int in lst:
			var a := v[t * 3]
			var b := v[t * 3 + 1]
			var c := v[t * 3 + 2]
			var d := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
			if absf(d) < 1e-9:
				continue
			var l1 := ((b.z - c.z) * (x - c.x) + (c.x - b.x) * (z - c.z)) / d
			var l2 := ((c.z - a.z) * (x - c.x) + (a.x - c.x) * (z - c.z)) / d
			var l3 := 1.0 - l1 - l2
			if l1 < -1e-4 or l2 < -1e-4 or l3 < -1e-4:
				continue
			out.append(l1 * a.y + l2 * b.y + l3 * c.y)
		return out

	## Есть поверхность на высоте y (±tol)
	func has_at(x: float, z: float, y: float, tol: float) -> bool:
		for h in heights(x, z):
			if absf(h - y) <= tol:
				return true
		return false

	## Есть что-нибудь между y0 и y1
	func any_in(x: float, z: float, y0: float, y1: float) -> bool:
		for h in heights(x, z):
			if h > y0 and h < y1:
				return true
		return false

	## Верхняя поверхность не выше below (−INF — нет)
	func surface(x: float, z: float, below: float) -> float:
		var best := -INF
		for h in heights(x, z):
			if h <= below and h > best:
				best = h
		return best


# ---------- шествие перед играми («Уютный Рим», этап 3) ----------
## Перед боями в амфитеатре из школы гладиаторов (Лудус) по улицам идёт колонна: впереди знаменосец Легиона,
## за ним гладиаторы — мирмиллоны, ретиарии, фракийцы; у амфитеатра входят внутрь. Только в новой игре, не на «Очень низкой»
const PROC_N := 6
const PROC_GAP := 1.15                   # между идущими, м
const PROC_SPEED := 1.25                 # м/с при скорости игры ×1
var _procs: Array = []                   # [{f, path, len, off}]


func _procession(V: Dictionary, a := Vector2.INF, z := Vector2.INF) -> void:
	if int(city.cozy_v) < 1 or str(game.settings.get("quality", "high")) == "verylow" or game.people == null or not _procs.is_empty():
		return
	var from := {}
	for id in city.buildings:
		var b: Dictionary = city.buildings[id]
		if String(b["type"]) == "ludus":
			from = b
			break
	if from.is_empty() and a == Vector2.INF:
		return
	var path: PackedVector2Array = game.people._path(city.door_point(from) if a == Vector2.INF else a, city.door_point(V["b"]) if z == Vector2.INF else z)
	if path.size() < 2:
		return
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	var kinds := ["murmillo", "retiarius", "thraex"]
	var sz := Citizen.SIZE / LegionFighter.HUMAN
	for i in PROC_N + 1:
		var f: LegionFighter = LegionFighter.create("legionary", sz, 77) if i == 0 else Stories.gladiator(kinds[(i - 1) % 3], 300 + i, sz)
		f.name = "Procession_%d" % i
		add_child(f)
		f.visible = false
		_procs.append({"f": f, "path": path, "len": total, "off": i * PROC_GAP, "d": 0.0})


## Точка пути на расстоянии d от начала и направление
func _along(path: PackedVector2Array, d: float) -> Array:
	for i in range(1, path.size()):
		var seg := path[i - 1].distance_to(path[i])
		if d <= seg or i == path.size() - 1:
			var t := clampf(d / maxf(seg, 0.001), 0.0, 1.0)
			return [path[i - 1].lerp(path[i], t), (path[i] - path[i - 1]).normalized()]
		d -= seg
	return [path[path.size() - 1], Vector2(0, 1)]


func _proc_step(dt: float, sdt: float) -> void:
	if _procs.is_empty():
		return
	var left := []
	for p: Dictionary in _procs:
		var f: LegionFighter = p["f"]
		if not is_instance_valid(f):
			continue
		p["d"] = float(p["d"]) + sdt * PROC_SPEED
		var at := float(p["d"]) - float(p["off"])
		if at >= float(p["len"]):
			f.queue_free()                       # дошёл до амфитеатра — внутрь
			continue
		left.append(p)
		if at < 0.0:
			continue
		var e := _along(p["path"], at)
		var q: Vector2 = e[0]
		var dir: Vector2 = e[1]
		f.visible = true
		f.position = Vector3(q.x, game.land.height_at(q.x, q.y), q.y)
		f.rotation.y = lerp_angle(f.rotation.y, atan2(dir.x, dir.y), minf(1.0, dt * 6.0))
		f.set_motion(true)
		f.set_speed(maxf(0.5, speed))
		f.tick(dt)
	_procs = left
