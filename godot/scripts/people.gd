class_name People
extends Node3D
## Жители — настоящие люди, как в Town to City: каждого жителя города видно, когда он на улице.
## Семьи приезжают на повозке по большой дороге из-за горизонта, сходят на площадь у станции, потом идут в свой дом.
## Утром работники выходят из дома и идут на работу (встают за прилавок, к печи, в поле), вечером
## возвращаются домой; остальные ходят по лавкам и на площадь; ночью все спят дома, окна светятся.
## Если жилья нет — семьи ждут на площади. Кошки гуляют по улицам и спят у дверей.

var land: Land
var city: City
var game
var grid := AStarGrid2D.new()
var residents := []                  # все жители города
var by_id := {}
var next_rid := 1
var waiting_fams := []               # семьи без дома на площади: [{name, members: [rid]}]
var slots := {}                      # id постройки → [rid или 0 по местам работы]
var rng := RandomNumberGenerator.new()
var cart := {}
var cats := []
var visible_count := 0
var _tick := 0.0
var _jobs_dirty := true
var _hour := 8.0

const MAX_VIS := 150                 # больше людей на улице не рисуем (остальные идут «невидимо»)
var max_vis := MAX_VIS               # …а на «Низкой» и «Очень низкой» графике — меньше (Gfx.VIS)
const MENU_RES := 300                # витрина главного меню: жителей не больше (ходят по улицам за меню — меньше работы процессору)
const RADIUS := 0.3
const CART_FAR := 46.0               # повозка появляется (и исчезает) так далеко за краем карты на большой дороге
## Повозка переселенцев (размеры — в единицах модели телеги Synty, вся она в масштабе построек Catalog.ARCH)
const CART_V := 2.4                  # шаг лошади, м/с
const CART_SX := 1.25                # кузов телеги шире
const CART_SZ := 1.75                # и длиннее — на три ряда седоков (колёса свои, круглые)
const CART_FLOOR := 0.72             # пол кузова
const CART_HIP := 0.417              # сидящий (движения Sitting_*): таз над ступнями
const CART_HIP_BACK := 0.29          # и позади ступней
const CART_ROWS := [0.62, 0.02, -0.58]   # ступни седоков по рядам, от облучка назад
const CART_ROW_W := 1.36             # ширина ряда: взрослый 0.56, ребёнок 0.4
const CART_DRIVER := Vector3(0.26, 0.98, 1.24)   # возница на облучке (рядом место ещё одному седоку)
const CART_WHEEL_R := 0.49
const CART_WHEEL_X := 0.95
const CART_WHEEL_Z := [-0.78, 0.62]
const CART_HORSE_LEN := 2.5          # лошадь от морды до хвоста
const CART_HORSE_Z := 2.72           # её середина: круп — у облучка, оглобли — по бокам до груди
const G := 2                         # клетка сетки ходьбы — 2×2 клетки земли (50 см)
const GN := Land.N / G
const WALK := 1.15                   # м/с при обычной скорости (люди маленькие — и шаг короче)


func setup(l: Land, c: City, g) -> void:
	land = l
	city = c
	game = g
	rng.seed = 21
	grid.region = Rect2i(0, 0, GN, GN)
	grid.cell_size = Vector2(Land.CELL * G, Land.CELL * G)
	grid.offset = Vector2(Land.CELL * G, Land.CELL * G) * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	grid.fill_solid_region(grid.region, true)
	refresh(land.road_chunks.keys())
	_make_cart()
	city.building_removed.connect(_on_building_removed)
	city.building_added.connect(_on_building_added)
	city.changed.connect(func(): _jobs_dirty = true)
	city.family_left.connect(_on_family_left)
	city.family_assigned.connect(_on_assigned)
	city.rehomed.connect(_on_rehomed)
	_old_couples()
	# жители уже заселённых домов (загрузка, готовый город)
	for id in city.buildings:
		var b: Dictionary = city.buildings[id]
		if city.is_house(b):
			if game.mode == "menu" and residents.size() >= MENU_RES:
				break
			for f in b["families"]:
				_make_family(f["name"], int(f["n"]), id, city.door_point(b), "", f)
	# семьи, которые ждут жилья на площади
	for f in city.arrivals:
		var fam := _make_family(f["name"], int(f["n"]), -1, Land.CENTER, f["cls"], f)
		for r in fam:
			r["p"] = _plaza_point()
			r["goal"] = "plaza"
			_arrive(r)
		waiting_fams.append({"name": f["name"], "members": fam.map(func(x): return x["id"])})
	_assign_jobs()
	_start_of_day(true)
	_cats_load()
	hero_spawn()                             # свой герой (Д11): ходит по городу, в счёт жителей не входит


# ---------- сетка ходьбы ----------

func _walk_g(gi: int, gj: int) -> bool:
	var n := 0
	for dj in G:
		for di in G:
			var k := land.idx(gi * G + di, gj * G + dj)
			if Land.walk_kind(land.kind[k]) and land.occ[k] == 0:
				n += 1
	return n * 2 >= G * G


func refresh(chunks: Array) -> void:
	var s := Land.CH / G
	for ch: Vector2i in chunks:
		for j in range(ch.y * s, ch.y * s + s):
			for i in range(ch.x * s, ch.x * s + s):
				grid.set_point_solid(Vector2i(i, j), not _walk_g(i, j))


## Сетка ходьбы под клетками постройки (и кольцом вокруг) — сразу, как постройку поставили или убрали.
## На ровной мостовой земля под домом не меняется, чанк к перестройке не помечается, и без этого жители
## ходили бы сквозь новый дом на площади, а на месте снесённого оставалась бы невидимая стена
func refresh_cells(cells: PackedInt32Array) -> void:
	var seen := {}
	for k in cells:
		var gi := (k % Land.N) / G
		var gj := (k / Land.N) / G
		for dj in range(-1, 2):
			for di in range(-1, 2):
				var g := Vector2i(gi + di, gj + dj)
				if g.x < 0 or g.y < 0 or g.x >= GN or g.y >= GN or seen.has(g):
					continue
				seen[g] = true
				grid.set_point_solid(g, not _walk_g(g.x, g.y))


## Путь (от p по точкам path с номера i) проходит по клеткам постройки id?
func _path_hits(p: Vector2, path: PackedVector2Array, i: int, id: int) -> bool:
	var a := p
	for j in range(i, path.size()):
		var b: Vector2 = path[j]
		var n := maxi(1, int(a.distance_to(b) / 0.25))
		for s in n + 1:
			if land.occ_at(a.lerp(b, float(s) / n)) == id:
				return true
		a = b
	return false


func gcell(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x / (Land.CELL * G)), 0, GN - 1), clampi(int(p.y / (Land.CELL * G)), 0, GN - 1))


func _free(p: Vector2) -> bool:
	return not grid.is_point_solid(gcell(p))


func _near_free(p: Vector2, rmax := 14) -> Vector2:
	if _free(p):
		return p
	for r in range(1, rmax):
		for a in 12:
			var q := p + Vector2(cos(TAU * a / 12.0), sin(TAU * a / 12.0)) * r * Land.CELL * G * 0.5
			if _free(q):
				return q
	return Vector2.INF


func _path(a: Vector2, b: Vector2) -> PackedVector2Array:
	var fa := _near_free(a)
	var fb := _near_free(b)
	if fa == Vector2.INF or fb == Vector2.INF:
		return PackedVector2Array()
	var raw := grid.get_point_path(gcell(fa), gcell(fb))
	if raw.is_empty():
		return PackedVector2Array()
	var out := PackedVector2Array([a, fa])
	var i := 0
	while i < raw.size() - 1:
		var j := mini(raw.size() - 1, i + 30)
		while j > i + 1 and not _clear(out[out.size() - 1], raw[j]):
			j -= 1
		out.append(raw[j])
		i = j
	out.append(b)
	return out


func _clear(a: Vector2, b: Vector2) -> bool:
	var n := int(a.distance_to(b) / 0.25) + 1
	for k in range(1, n):
		if not _free(a.lerp(b, float(k) / n)):
			return false
	return true


# ---------- жители ----------

## Люди семьи name (n человек) у дома home. fam — запись семьи (в доме, на площади, в повозке): её члены (fam.m,
## Residents) и есть эти люди — имя, пол, возраст, облик, работа. Без записи — ищем её в доме или на площади по имени;
## нет и там (проверки) — члены по правилам Residents, не сохраняются
func _make_family(name: String, n: int, home: int, at: Vector2, cls := "", fam := {}) -> Array:
	var out := []
	var house: Dictionary = city.buildings.get(home, {})
	if not house.is_empty():
		cls = city.def(house)["cls"]
	elif cls == "":
		cls = "plebs"
	if fam.is_empty():
		fam = _family_rec(name, home)
	if fam.is_empty() or int(fam.get("n", -1)) != n:
		fam = {"name": name, "n": n, "cls": cls}
	var ms := Residents.fit(fam, hash([name, home]), cls)
	for i in n:
		var m: Dictionary = ms[i]
		var child := int(m["age"]) == 0
		var r := {"id": next_rid, "home": home, "fam": name, "female": int(m["sx"]) == 1, "child": child, "old": int(m["age"]) == 2,
			"rich": cls == "patricians", "cls": cls, "job": -1, "state": "home", "p": at, "path": PackedVector2Array(), "i": 0,
			"node": null, "yaw": rng.randf() * TAU, "speed": rng.randf_range(0.92, 1.12) * (0.8 if child else 1.0), "goal": "",
			"t": 0.0, "slot": -1, "seed": int(m["sd"]), "dep": rng.randf_range(-0.6, 0.6), "ret": rng.randf_range(0.0, 1.2), "done_today": false,
			# что делает на месте (лавка, скамья, кошка, разговор…), куда шёл, с кем говорит, череда движений
			"act": "", "dest": {}, "conv": {}, "seq": [], "si": 0, "st": 0.0, "at": 0.0, "face": 0.0, "yoff": 0.0, "yoff_to": 0.0,
			"fade": 1.0, "outs": 0, "serve": 0, "pal": 0, "door": {},
			"m": m, "pn": String(m["pn"])}          # запись члена семьи (сохраняется) и имя
		# работа из сохранения — если та постройка ещё стоит и берёт работников (лишних отпустит _assign_jobs)
		var jb := int(m.get("job", -1))
		if jb >= 0 and home > 0 and not child and city.buildings.has(jb) and city.def(city.buildings[jb]).has("jobs"):
			r["job"] = jb
		next_rid += 1
		residents.append(r)
		by_id[r["id"]] = r
		out.append(r)
	return out


## Старое сохранение, где «Свадьба» уже сыграна, а у молодых ещё нет записей: один раз — жених и невеста из роликов
## (Марк и Юлия, облик по зерну роли), как у новых свадеб (Stories.couple_members); дальше записи сохраняются
func _old_couples() -> void:
	var st: Dictionary = city.stories if typeof(city.stories) == TYPE_DICTIONARY else {}
	var recs: Array = (st.get("done", {}) as Dictionary).values() if typeof(st.get("done")) == TYPE_DICTIONARY else []
	if typeof(st.get("active")) == TYPE_DICTIONARY and not (st["active"] as Dictionary).is_empty():
		recs.append(st["active"])
	for rec in recs:
		if typeof(rec) != TYPE_DICTIONARY or String(rec.get("couple", "")) == "" or typeof(rec.get("roles")) != TYPE_DICTIONARY:
			continue
		var nm := String(rec["couple"])
		var f := {}
		var cls := ""
		var key := -1
		for id in city.buildings:
			var b: Dictionary = city.buildings[id]
			if not city.is_house(b):
				continue
			for fm: Dictionary in b.get("families", []):
				if String(fm.get("name", "")) == nm:
					f = fm
					cls = String(city.def(b)["cls"])
					key = int(id)
		if f.is_empty():
			for fm: Dictionary in city.arrivals:
				if String(fm.get("name", "")) == nm:
					f = fm
					cls = String(fm.get("cls", "plebs"))
		if f.is_empty() or (typeof(f.get("m")) == TYPE_ARRAY and not (f["m"] as Array).is_empty()):
			continue
		f["m"] = Stories.couple_members(nm, int(f.get("n", 2)), cls, key, rec["roles"])


## Запись семьи name: в доме home (последняя с этим именем) или на площади; {} — нет такой
func _family_rec(name: String, home: int) -> Dictionary:
	var h: Dictionary = city.buildings.get(home, {})
	if not h.is_empty():
		var fs: Array = h.get("families", [])
		for k in range(fs.size() - 1, -1, -1):
			if String(fs[k].get("name", "")) == name:
				return fs[k]
		return {}
	for f: Dictionary in city.arrivals:
		if String(f.get("name", "")) == name:
			return f
	return {}


## Перед сохранением: кто где работает — в записи членов семей (после загрузки работа та же)
func sync_members() -> void:
	for r in residents:
		var m: Dictionary = r.get("m", {})
		if m.is_empty():
			continue
		if int(r["job"]) >= 0 and int(r["home"]) > 0:
			m["job"] = int(r["job"])
		else:
			m.erase("job")


func _node(r: Dictionary) -> Citizen:
	if r["node"] != null:
		return r["node"]
	if visible_count >= max_vis and int(r["id"]) != focus_rid and not r.has("hero"):
		return null                          # выбранного (карточка, «Следовать») и героя рисуем всегда
	var c := Citizen.build(look_of(r), r["child"])
	add_child(c)
	if int(r["id"]) == focus_rid:
		_outline(c, true)
	c.anim.speed_scale = maxf(0.01, game.speed)
	r["node"] = c
	visible_count += 1
	_place(r)
	return c


func _hide(r: Dictionary) -> void:
	if r["node"] != null:
		(r["node"] as Node).queue_free()
		r["node"] = null
		visible_count -= 1


func _place(r: Dictionary) -> void:
	var c: Citizen = r["node"]
	if c == null:
		return
	var p: Vector2 = r["p"]
	c.position = Vector3(p.x, land.height_at(p.x, p.y) + float(r["yoff"]), p.y)
	c.rotation.y = float(r["yaw"])


# ---------- житель с именем: щелчок, обводка, «Следовать», облик (этапы 6.3–6.5) ----------

var focus_rid := 0                   # выбранный житель (открыта его карточка): рисуется всегда, с обводкой
var focus_cat := {}                  # выбранная кошка
var _hov_mp := Vector2(-999, -999)
var _hov_t := 0
var _hov_hit := {}
static var _outline_mat: ShaderMaterial
const PICK_MIN_PX := 10.0            # щелчок по жителю: не дальше max(10 точек, 0.35 его роста на экране) от него
const PICK_K := 0.35
const CAT_PICK_PX := 30.0            # по кошке — 0,9 её длины на экране, не больше 30 точек (вблизи) и не меньше 10 (издали)
const CAT_NEAR_PX := 12.0            # …а если под курсором и житель — кошка, только когда курсор почти на ней
const OCC_M := 0.4                   # житель или кошка у самой стены (в дверях) — ещё не «за постройкой»
var _occ := []                       # постройка на луче под курсором (pick): [расстояние, id], пусто — ещё не считали
## Имена кошек [имя, 0 — кот, 1 — кошка]; «Мурка» — у кошки истории
const CAT_NAMES := [["Феликс", 0], ["Луна", 1], ["Тигрис", 0], ["Пушинка", 1], ["Мелла", 1], ["Минерва", 1], ["Бусина", 1], ["Цезарь", 0],
	["Венера", 1], ["Плутон", 0], ["Каштан", 0], ["Уголёк", 0], ["Снежка", 1], ["Рыжик", 0], ["Дымка", 1], ["Юнона", 1], ["Марсик", 0],
	["Ночка", 1], ["Купидон", 0], ["Флора", 1], ["Пирожок", 0], ["Ласка", 1], ["Бруно", 0], ["Аврора", 1]]


## Облик жителя: из записи члена семьи (Residents.look_of), у кого записи нет — по зерну, как раньше
func look_of(r: Dictionary) -> Dictionary:
	if r.has("hero"):
		return Hero.look(city)                # свой герой: облик из его записи (с плащом и венком)
	var m: Dictionary = r.get("m", {})
	if not m.is_empty():
		return Residents.look_of(m, String(r["cls"]))
	var rr := RandomNumberGenerator.new()
	rr.seed = int(r["seed"])
	return Citizen.roll_look(rr, r["female"], r["child"], r["rich"], "", r["cls"])


## Дом перестроили в следующий класс (Д12): его жильцы теперь этого класса — одежда по новому классу, у кого облик
## не выбран сам (запись члена семьи та же: имя, пол, работа)
func reclass(h: Dictionary) -> void:
	var cl := h_cls(h)
	for r in residents:
		if int(r["home"]) != int(h["id"]) or String(r["cls"]) == cl:
			continue
		r["cls"] = cl
		r["rich"] = cl == "patricians"
		if r["node"] != null:
			_hide(r)
			_show(r)
			if r["node"] != null:
				_sparkle((r["node"] as Node3D).global_position + Vector3(0, 0.9, 0))


## Сменить облик жителя (поход в лавку или выбор игрока): запись — сразу, виден — меняется на глазах
func set_look(r: Dictionary, lk: Dictionary, sparkle := false) -> void:
	var m: Dictionary = r.get("m", {})
	if not m.is_empty():
		m["look"] = lk
	var c: Citizen = r["node"]
	if c == null:
		return
	if not c.apply_look(lk):
		_hide(r)                          # другая модель — собрать заново
		_show(r)
		c = r["node"]
	if c and int(r["id"]) == focus_rid:
		_outline(c, true)
	if c and sparkle:
		_sparkle(c.global_position + Vector3(0, 1.0 * c.scale.y / Citizen.SIZE, 0))


## Искорки над тем, кто сменил облик (вышел от цирюльника, из красильни)
func _sparkle(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 10
	p.lifetime = 0.9
	p.explosiveness = 0.85
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0, -0.4, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var qm := QuadMesh.new()
	qm.size = Vector2(0.07, 0.07)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color("ffe9a8")
	mat.emission_enabled = true
	mat.emission = Color("ffd86a")
	qm.material = mat
	p.mesh = qm
	add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


## Сходил в лавку типа t (Looks.visit): иногда новая причёска, туника, кайма, венок
func _shop_visit(r: Dictionary, t: String) -> void:
	if t == "" or not Looks.CHANCE.has(t) or r.get("m", {}).is_empty() or r.has("hero"):
		return
	var lk: Dictionary = look_of(r).duplicate()
	if Looks.visit(lk, t, r["female"], r["child"], String(r["cls"]), rng):
		set_look(r, lk, true)


## Мягкая светлая обводка выбранного (переднюю сторону сетки раздуваем и красим, видна только кайма вокруг)
static func _outline_material() -> ShaderMaterial:
	if _outline_mat == null:
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = load("res://shaders/outline_hull.gdshader")
	return _outline_mat


func _outline(c: Node, on: bool) -> void:
	if c == null or not is_instance_valid(c):
		return
	on = on and not outline_off
	for mi: MeshInstance3D in c.find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = _outline_material() if on else null


var outline_off := false             # режим фото: за кем идёт камера, тот рисуется всегда, но без обводки


## Выбрать жителя (rid; 0 — снять выбор): обводка, рисуется всегда, даже сверх MAX_VIS
func set_focus(rid: int) -> void:
	if focus_rid == rid:
		return
	var old: Dictionary = by_id.get(focus_rid, {})
	if not old.is_empty() and old["node"] != null:
		_outline(old["node"], false)
	focus_rid = rid
	var r: Dictionary = by_id.get(rid, {})
	if r.is_empty():
		focus_rid = 0
		return
	if r["node"] != null:
		_outline(r["node"], true)
	elif _drawable(r):
		_show(r)


## Выбрать кошку ({} — снять): обводка
func set_focus_cat(c: Dictionary) -> void:
	if not focus_cat.is_empty() and is_same(focus_cat, c):
		return
	if not focus_cat.is_empty():
		_outline(focus_cat.get("n"), false)
	focus_cat = c
	if not c.is_empty():
		_outline(c.get("n"), true)


## Житель на виду (на улице, у прилавка): его можно рисовать
func _drawable(r: Dictionary) -> bool:
	var st: String = r["state"]
	return st in ["walk", "idle", "work"] and not (st == "idle" and r["act"] == "inside") and not (st == "work" and int(r["slot"]) < 0)


## Где житель (камера «Следовать»): на улице — он сам; в доме или в лавке — у двери, куда вошёл
func person_pos(r: Dictionary) -> Vector3:
	var c: Node3D = r["node"]
	if c != null and is_instance_valid(c):
		return c.global_position
	var p: Vector2 = r["p"]
	return Vector3(p.x, land.height_at(p.x, p.y), p.y)


func cat_pos(c: Dictionary) -> Vector3:
	var n: Node3D = c.get("n")
	if n != null and is_instance_valid(n):
		return n.global_position
	var p: Vector2 = c["p"]
	return Vector3(p.x, land.height_at(p.x, p.y), p.y)


## Кто под курсором: житель (ближний к камере) или кошка — {"r": житель} / {"cat": кошка} / {}.
## Житель — отрезок от ступней до макушки на экране; кошка — круг по её размеру на экране (вблизи щедро, издали — 10 точек).
## Кого заслоняет постройка (дальше от камеры, чем постройка на луче под курсором), того не ловим: щелчок и подпись — постройке
func pick(mp: Vector2) -> Dictionary:
	var rig = game.rig
	var cam: Camera3D = rig.cam if rig else null
	if cam == null:
		return {}
	if game.tutorial != null and game.tutorial.cur_id() == "house":
		return {}                            # обучение «Щёлкните по дому»: щелчок — дому, а не семье у его двери
	var cp := cam.global_position
	_occ = []
	var best := {}
	var bd := INF
	for r in (residents if hero_r.is_empty() else residents + [hero_r]):
		var c: Citizen = r["node"]
		if c == null or float(r["fade"]) < 0.3 or not c.is_visible_in_tree():
			continue
		var feet := c.global_position
		if cam.is_position_behind(feet):
			continue
		var head := feet + Vector3(0, 1.3 * c.scale.y / Citizen.SIZE, 0)
		if c.hair_att != null:
			head = c.hair_att.global_position + Vector3(0, 0.12 * c.scale.y / Citizen.SIZE, 0)
		var a := cam.unproject_position(feet)
		var b := cam.unproject_position(head)
		var tol := maxf(PICK_MIN_PX, PICK_K * a.distance_to(b))
		var q := Geometry2D.get_closest_point_to_segment(mp, a, b)
		if q.distance_to(mp) > tol:
			continue
		var d := cp.distance_squared_to(feet)
		if d >= bd:
			continue
		# точка жителя под курсором: за постройкой (не той, у которой он стоит) — не виден
		var ab := a.distance_to(b)
		var wp := feet.lerp(head, clampf(a.distance_to(q) / ab, 0.0, 1.0) if ab > 0.01 else 0.5)
		var wl := _wall(mp)
		if cp.distance_to(wp) > float(wl[0]) + OCC_M and int(wl[1]) != at_bid(r):
			continue
		bd = d
		best = {"r": r}
	# кошка: круг по её длине на экране, но жителя под курсором она не перебивает — только если курсор почти на ней
	var cat := {}
	var cd := INF
	var ctol := CAT_PICK_PX
	for ct in cats:
		if ct.has("story"):
			continue                         # потерянную кошку ищут — щелчок по ней забирает история
		var n: Node3D = ct.get("n")
		if n == null or not n.is_visible_in_tree():
			continue
		var w := n.global_position + Vector3(0, 0.18, 0)
		if cam.is_position_behind(w):
			continue
		var sp := cam.unproject_position(w)
		var px := sp.distance_to(mp)
		if px > CAT_PICK_PX or px >= cd:
			continue
		var tol := clampf(sp.distance_to(cam.unproject_position(w + cam.global_basis.x * CAT_LEN)) * 0.9, PICK_MIN_PX, CAT_PICK_PX)
		if px > tol:
			continue
		if cp.distance_to(w) > float(_wall(mp)[0]) + OCC_M:
			continue                         # кошка за постройкой (у двери с той стороны) — щелчок постройке
		cd = px
		cat = ct
		ctol = tol
	if not cat.is_empty() and (best.is_empty() or cd <= minf(CAT_NEAR_PX, ctol)):
		return {"cat": cat}
	return best


## Постройка на луче под курсором: [расстояние до неё от камеры, её id] (нет — [INF, -1]); один раз за pick и только
## когда кто-то уже попал по экрану — лишнего счёта на кадр нет
func _wall(mp: Vector2) -> Array:
	if _occ.is_empty():
		var h: Dictionary = game.ray_hit(mp) if game.has_method("ray_hit") else {}
		_occ = [float(h.get("t", INF)), int(h.get("id", -1))]
	return _occ


## Постройка, у которой житель сейчас стоит (за прилавком, в поле, в дверях, у лавки, на скамье): его она не заслоняет
func at_bid(r: Dictionary) -> int:
	var dr: Dictionary = r["door"]
	if not dr.is_empty():
		return int(dr.get("bid", -1))
	match String(r["state"]):
		"work":
			return int(r["job"])
		"idle":
			return int((r["dest"] as Dictionary).get("bid", -1))
	return -1


## То же для курсора и подписи у мыши: считаем заново, только когда мышь сдвинулась или прошло 0,15 с
func hover_pick(mp: Vector2) -> Dictionary:
	var now := Time.get_ticks_msec()
	if mp.distance_to(_hov_mp) < 2.0 and now - _hov_t < 150:
		return _hov_hit
	_hov_mp = mp
	_hov_t = now
	_hov_hit = pick(mp)
	return _hov_hit


## Имя жителя: «Гай Юлий»
static func name_of(r: Dictionary) -> String:
	var m: Dictionary = r.get("m", {})
	if r.has("hero"):
		return String(m.get("pn", "Герой"))   # имя героя — как его назвал игрок
	if m.is_empty():
		return "Житель"
	return Residents.full_name(m, String(r["fam"]))


## Подпись у курсора: «Гай Юлий · пекарь»
func tag_of(r: Dictionary) -> String:
	var t := name_of(r)
	if r.has("hero"):
		return t + " · герой города"
	if bool(r["child"]):
		return t + (" · дочь" if r["female"] else " · сын")
	var jb: Dictionary = city.buildings.get(int(r["job"]), {})
	if not jb.is_empty():
		var noun := Residents.job_noun(String(jb["type"]), r["female"])
		return t + " · " + (noun if noun != "" else String(city.def(jb)["name"]).to_lower())
	return t


# ---------- свой герой (Д11): живёт в городе ----------
# Герой — запись жителя с пометкой "hero" (облик и имя — из city.hero, Hero): в by_id (карточка, «Следовать», щелчок),
# но не в residents — работы не ищет, в счёт жителей, семей и MAX_VIS не входит, рисуется всегда. Днём гуляет: лавки
# по всему городу, площади, форум и храмы, военный квартал (здания Легиона), статуи, скамьи, кошки, игры в честь богов;
# ночует в Казармах (нет их — на почтовой станции). Случайности у героя свои (hero_rng) — горожане ходят как раньше.

var hero_r := {}                     # герой на улицах ({} — нет героя)
var hero_rng := RandomNumberGenerator.new()
var _hero_dt := 0.0
var _hero_hov := false               # мышь над героем — мягкая золотая обводка
static var _hover_mat: ShaderMaterial
## Куда герой ходит «посмотреть»: площади и большие постройки, здания Легиона
const HERO_SITES := ["forum", "temple", "pantheon", "colosseum", "baths", "theatre", "odeon", "library", "academy", "fountain"]


## Вывести героя на улицы (загрузка, создан, переделан): у двери своего дома; днём — сразу где-нибудь на площади
func hero_spawn() -> void:
	hero_despawn()
	if not Hero.exists(city) or not (game.mode in ["play", "new"]):
		return
	var m: Dictionary = city.hero["m"]
	hero_rng.seed = int(m.get("sd", 1)) ^ 0x2545F491
	var h := hero_home()
	var at: Vector2 = city.door_point(h) if not h.is_empty() else Land.CENTER
	var fem := int(m.get("sx", 0)) == 1
	hero_r = {"id": Hero.HERO_RID, "hero": true, "home": int(h.get("id", -1)), "fam": "", "female": fem, "child": false, "old": false,
		"rich": true, "cls": "patricians", "job": -1, "state": "home", "p": at, "path": PackedVector2Array(), "i": 0,
		"node": null, "yaw": 0.0, "speed": 1.05, "goal": "", "t": 0.0, "slot": -1, "seed": int(m.get("sd", 1)), "dep": 0.0, "ret": 0.0,
		"done_today": false, "act": "", "dest": {}, "conv": {}, "seq": [], "si": 0, "st": 0.0, "at": 0.0, "face": 0.0, "yoff": 0.0,
		"yoff_to": 0.0, "fade": 1.0, "outs": 0, "serve": 0, "pal": 0, "door": {}, "m": m, "pn": String(m.get("pn", ""))}
	by_id[Hero.HERO_RID] = hero_r
	var hr: float = game.hour
	if hr >= 6.5 and hr < 21.0:
		var keep := rng
		rng = hero_rng
		var d := _plaza_target(hero_r, at)
		if not d.is_empty() and d.has("p"):
			_claim(hero_r, d)
			hero_r["p"] = d["p"]
			hero_r["goal"] = "errand"
			_arrive(hero_r)
		rng = keep


func hero_despawn() -> void:
	if hero_r.is_empty():
		return
	if focus_rid == Hero.HERO_RID:
		set_focus(0)
	_release(hero_r)
	_hide(hero_r)
	by_id.erase(Hero.HERO_RID)
	hero_r = {}
	_hero_hov = false


## Где герой ночует: Казармы (первые), нет их — почтовая станция
func hero_home() -> Dictionary:
	var best := {}
	for id in city.buildings:
		var b: Dictionary = city.buildings[id]
		if String(b["type"]) == "barracks" and (best.is_empty() or int(id) < int(best["id"])):
			best = b
	return best if not best.is_empty() else city.center()


## Облик героя поменяли (гардероб, «Изменить»): на улице — сразу, с искорками
func hero_refresh(sparkle := true) -> void:
	if hero_r.is_empty():
		hero_spawn()
		return
	var m: Dictionary = city.hero["m"]
	hero_r["m"] = m
	hero_r["pn"] = String(m.get("pn", ""))
	if bool(hero_r["female"]) != (int(m.get("sx", 0)) == 1):
		hero_r["female"] = int(m.get("sx", 0)) == 1
		_hide(hero_r)                         # другой пол — другая модель: собрать заново
		if _drawable(hero_r):
			_show(hero_r)
		return
	set_look(hero_r, Hero.look(city), sparkle)


## Мышь над героем (Hud: подпись у курсора): мягкая золотая обводка; выбран (карточка) — обычная кремовая
func hero_hover(on: bool) -> void:
	if hero_r.is_empty() or on == _hero_hov:
		return
	_hero_hov = on
	var c: Citizen = hero_r["node"]
	if c == null or focus_rid == Hero.HERO_RID:
		return
	if _hover_mat == null:
		_hover_mat = ShaderMaterial.new()
		_hover_mat.shader = load("res://shaders/outline_hull.gdshader")
		_hover_mat.set_shader_parameter("color", Color(1.0, 0.84, 0.42))
		_hover_mat.set_shader_parameter("width", 0.013)
	for mi: MeshInstance3D in c.find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = _hover_mat if on else null


## Кадр героя: шаг, дело на месте, двери (как у горожан), раз в четверть секунды — распорядок; случайности — свои
func _hero_tick(dt: float, sdt: float) -> void:
	var keep := rng
	rng = hero_rng
	var r := hero_r
	_hero_dt += dt
	if _hero_dt >= 0.25:
		_hero_schedule(_hero_dt * game.speed * 24.0 / Game.DAY_LEN)
		_hero_dt = 0.0
	if not hero_r.is_empty():
		match r["state"]:
			"walk":
				_step(r, sdt)
			"idle":
				if r["node"] != null:
					(r["node"] as Citizen).anim.speed_scale = game.speed
				if r["act"] != "":
					_act_step(r, sdt)
			"door":
				if r["node"] != null:
					(r["node"] as Citizen).anim.speed_scale = game.speed
				_door_step(r, sdt)
		if r["node"] != null and float(r["fade"]) < 1.0 and r["state"] != "walk" and r["state"] != "door":
			r["fade"] = minf(1.0, float(r["fade"]) + sdt / 0.6)
			(r["node"] as Citizen).set_alpha(float(r["fade"]))
	rng = keep


## Распорядок героя: с рассвета до темноты — на улицах (дело за делом), ночью — домой
func _hero_schedule(dh: float) -> void:
	var r := hero_r
	var h: float = game.hour
	var night := h >= 21.0 or h < 6.5
	if not city.buildings.has(int(r["home"])):
		r["home"] = int(hero_home().get("id", -1))
	match String(r["state"]):
		"home":
			if not night and rng.randf() < 0.3 * dh * 40.0:
				_hero_errand(r)
		"idle":
			r["t"] = float(r["t"]) - dh
			if night and String(r["act"]) != "inside":
				_hero_go_home(r)
			elif String(r["act"]) == "" and float(r["t"]) <= 0.0:
				_hero_next(r)
		"walk":
			if night and String(r["goal"]) != "home":
				_hero_go_home(r)


func _hero_go_home(r: Dictionary) -> void:
	var hb: Dictionary = city.buildings.get(int(r["home"]), {})
	if hb.is_empty():
		hb = hero_home()
		r["home"] = int(hb.get("id", -1))
	if hb.is_empty():
		return
	_go(r, city.door_point(hb), "home")


## Дело сделано: днём — следующее, ночью — домой
func _hero_next(r: Dictionary) -> void:
	var h: float = game.hour
	if h >= 21.0 or h < 6.5:
		_hero_go_home(r)
	else:
		_hero_errand(r)


## Куда герою пойти: лавка (любая в городе, к прилавку), большая постройка или площадь, здание Легиона, статуя,
## скамья, кошка; в праздник — на игры у станции. Ближние — чаще
func _hero_errand(r: Dictionary) -> void:
	var from: Vector2 = r["p"]
	var opts := []
	var shops := []
	var sites := []
	var mil := []
	var last := int((r["dest"] as Dictionary).get("bid", -1))
	for id in city.buildings:
		var b: Dictionary = city.buildings[id]
		if int(id) == last or not b.get("active", true):
			continue
		var t := String(b["type"])
		var dd := (b["pos"] as Vector2).distance_to(from)
		if dd > 110.0:
			continue
		var d: Dictionary = city.def(b)
		if String(d.get("kind", "")) == "shop" and not (t in ENTER):
			shops.append([dd + rng.randf() * 30.0, b])
		elif t in HERO_SITES:
			sites.append([dd + rng.randf() * 30.0, b])
		elif Legion.is_building(t):
			mil.append([dd + rng.randf() * 30.0, b])
	for e: Array in [[shops, 4.0, "shop"], [sites, 3.0, "look"], [mil, 3.0, "look"]]:
		var list: Array = e[0]
		if list.is_empty():
			continue
		list.sort_custom(func(a, c): return a[0] < c[0])
		var b: Dictionary = list[0][1]
		var tg := {}
		if String(e[2]) == "shop":
			tg = _watch_target(r, b) if String(b["type"]) in WATCH else _counter_target(r, b)
		else:
			tg = _front_target(r, b, "look")
		if not tg.is_empty():
			opts.append([float(e[1]), tg])
	var pz := _plaza_target(r, from)
	if not pz.is_empty():
		opts.append([2.0, pz])
	for e: Array in [["statue", "look", 70.0, 1.5], ["column", "look", 70.0, 0.8], ["bench", "sit", 50.0, 1.5], ["well", "well", 40.0, 0.6]]:
		var t := _decor_target(r, from, e[0], e[1], e[2])
		if not t.is_empty():
			opts.append([e[3], t])
	var cat := _cat_free(from, 30.0)
	if not cat.is_empty():
		var ct := _cat_target(r, cat)
		if not ct.is_empty():
			opts.append([1.2, ct])
	if city.fest_left > 0:
		var fz := _fest_target(r, from)
		if not fz.is_empty():
			opts.append([6.0, fz])
	var sum := 0.0
	for o in opts:
		sum += float(o[0])
	var x := rng.randf() * sum
	var pick := {}
	for o in opts:
		x -= float(o[0])
		if x <= 0.0:
			pick = o[1]
			break
	if pick.is_empty():
		pick = {"act": "stroll", "p": _near_road(from, 12.0)}
	_release(r)
	_claim(r, pick)
	_go(r, pick["p"], "errand", true)


## Постройку убрали: герой ночевал в ней — новый дом (станция или другие Казармы); шёл к ней или стоял у неё — дальше
func _hero_lost(b: Dictionary) -> void:
	if hero_r.is_empty():
		return
	var r := hero_r
	var id := int(b["id"])
	if int(r["home"]) == id and id != city.moving_id:
		var nh := hero_home()
		r["home"] = int(nh.get("id", -1))
		if r["state"] == "home" and not nh.is_empty():
			r["p"] = city.door_point(b)
			var keep := rng
			rng = hero_rng
			_hero_next(r)
			rng = keep
	if int((r["dest"] as Dictionary).get("bid", -1)) == id and r["state"] == "idle" and r["act"] != "":
		_release(r)
		r["yoff"] = 0.0
		r["yoff_to"] = 0.0
		_place(r)
		r["t"] = 0.0
	elif r["state"] == "door" and int((r["door"] as Dictionary).get("bid", -1)) == id and id != city.moving_id:
		_door_cancel(r)
		r["t"] = 0.0


# ---------- кошки с именами (этап 6.4) ----------

## Кошки из сохранения; старое сохранение (кошек с именами ещё не было) — сразу столько, сколько городу положено
func _cats_load() -> void:
	var houses := _lived_houses()
	if houses.is_empty():
		return
	for rec: Dictionary in city.cats:
		var h: Dictionary = city.buildings.get(int(rec["home"]), {})
		if h.is_empty() or not city.is_house(h):
			h = houses[absi(hash(String(rec["nm"]))) % houses.size()]
			rec["home"] = int(h["id"])
		cats.append(_cat_from(rec, h))
	if city.cats.is_empty() and game.mode == "play":
		for k in clampi(int(city.stats["pop"]) / 14, 0, 12):
			_new_cat()


func _lived_houses() -> Array:
	return city.buildings.values().filter(func(b): return city.is_house(b) and int(b["pop"]) > 0)


## Новая кошка с именем у случайного дома — и в сохранение
func _new_cat() -> Dictionary:
	var houses := _lived_houses()
	if houses.is_empty():
		return {}
	var h: Dictionary = houses[rng.randi() % houses.size()]
	var used := {}
	for e: Dictionary in city.cats:
		used[String(e["nm"])] = true
	for c in cats:
		used[String(c.get("named", c.get("nm", "")))] = true
	var nm := ""
	var sx := 1
	var k0 := rng.randi() % CAT_NAMES.size()
	for k in CAT_NAMES.size():
		var e: Array = CAT_NAMES[(k0 + k) % CAT_NAMES.size()]
		if not used.has(e[0]):
			nm = e[0]
			sx = int(e[1])
			break
	if nm == "":
		nm = "Мурлыка %d" % (city.cats.size() + 1)
	var rec := {"nm": nm, "sx": sx, "fur": rng.randi() % CAT_FURS.size(), "home": int(h["id"]), "sd": rng.randi()}
	city.cats.append(rec)
	var c := _cat_from(rec, h)
	cats.append(c)
	return c


## Живая кошка по записи (окрас и рост — из своего зерна: после загрузки та же)
func _cat_from(rec: Dictionary, h: Dictionary) -> Dictionary:
	var rg := RandomNumberGenerator.new()
	rg.seed = int(rec["sd"])
	var c := _make_cat(h, {"fur": int(rec["fur"]), "rng": rg})
	c["rec"] = rec
	c["nm"] = String(rec["nm"])
	c["sx"] = int(rec.get("sx", 1))
	return c


## Дом кошки снесли — она переходит к ближнему дому, где живут
func _cat_rehome(c: Dictionary, from: Vector2) -> void:
	var best := {}
	var bd := INF
	for h in _lived_houses():
		if int(h["id"]) == int(c.get("home", -1)):
			continue
		var d := (h["pos"] as Vector2).distance_squared_to(from)
		if d < bd:
			bd = d
			best = h
	if best.is_empty():
		return
	c["home"] = int(best["id"])
	for k: String in ["rec", "pet_rec"]:
		if c.has(k):
			(c[k] as Dictionary)["home"] = int(best["id"])
	if c["state"] != "pet":
		c["state"] = "sit"
		c["t"] = 0.5                     # сейчас пойдёт к новому дому


## Запись кошки с именем (городская — rec, кошка-награда истории — pet_rec); {} — у кошки записи нет
static func cat_rec(c: Dictionary) -> Dictionary:
	if c.has("rec"):
		return c["rec"]
	return c.get("pet_rec", {})


## Как зовут кошку и кто она: [имя, «кот»/«кошка»]
static func cat_name(c: Dictionary) -> Array:
	var nm := String(c.get("nm", c.get("named", "")))
	var sx := int(c.get("sx", 1))
	return [nm if nm != "" else ("Кошка" if sx == 1 else "Кот"), "кошка" if sx == 1 else "кот"]


## Погладить кошку (карточка): садится, поднимает голову, сердечки над ней. Без звука и без пользы для города
func pet_now(c: Dictionary) -> void:
	if c.is_empty() or c.has("story"):
		return
	c["state"] = "pet"
	c["t"] = 5.0
	c["path"] = PackedVector2Array()
	c["walk"] = 0.0
	var at := cat_pos(c) + Vector3(0, 0.45, 0)
	for k in 4:
		var l := Label3D.new()
		l.text = "♥"
		l.font_size = 64
		l.outline_size = 10
		l.modulate = Color("ff8fa8")
		l.outline_modulate = Color("8a2a3a")
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.pixel_size = 0.004                 # без no_depth_test: сквозь стену сердечки не видны
		add_child(l)
		l.global_position = at + Vector3(randf_range(-0.15, 0.15), 0, randf_range(-0.15, 0.15))
		l.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(k * 0.35)
		tw.tween_property(l, "modulate:a", 1.0, 0.2)
		tw.parallel().tween_property(l, "global_position:y", at.y + 0.7, 1.4)
		tw.tween_property(l, "modulate:a", 0.0, 0.5)
		tw.tween_callback(l.queue_free)


## Начать прогулку к точке to; goal — что будет по приходу. keep — не отпускать занятое место (скамью, разговор)
func _go(r: Dictionary, to: Vector2, goal: String, keep := false) -> void:
	_leave_slot(r)
	# выходит из дома или лавки — появляется в дверях, а не посреди улицы
	var in_shop: bool = r["state"] == "work" and int(r["slot"]) < 0 and r["node"] == null
	var from_in: bool = r["state"] == "home" or (r["state"] == "idle" and r["act"] == "inside") or in_shop
	var door_id: int = int(r["home"]) if r["state"] == "home" else (int(r["job"]) if in_shop else int((r["dest"] as Dictionary).get("bid", -1)))
	var door_b: Dictionary = city.buildings.get(door_id, {})
	if r["state"] == "door":
		_door_cancel(r)
	if not keep:
		_release(r)
	r["yoff"] = 0.0
	r["yoff_to"] = 0.0
	if from_in and not door_b.is_empty():
		r["p"] = (r["p"] as Vector2) - City.facing(door_b["yaw"]) * 0.4
		r["yaw"] = float(door_b["yaw"])
	r["path"] = _path(r["p"], to)
	r["i"] = 1
	r["goal"] = goal
	if r["path"].size() < 2:
		r["p"] = to
		_arrive(r)
		return
	r["state"] = "walk"
	var had: bool = r["node"] != null
	var c := _node(r)
	if c:
		c.play("Walk_Loop")
		if from_in or not had:
			r["fade"] = 0.0
			c.set_alpha(0.0)


func _arrive(r: Dictionary) -> void:
	match r["goal"]:
		"home":
			r["state"] = "home"
			_door_in(r, city.buildings.get(r["home"], {}), "home")
		"work":
			_enter_work(r)
		"errand", "play", "stroll":
			# пришёл к настоящей цели: лавка, скамья, кошка, колодец, площадь — там и займётся делом
			_begin(r)
		"talk":
			_talk_arrived(r)
		"plaza":
			# новосёлы стоят на площади у станции и осматриваются
			r["state"] = "idle"
			r["t"] = 0.35 if int(r["home"]) > 0 else 9999.0
			r["goal"] = "arrived"
			var c := _node(r)
			if c:
				c.play("Idle_Loop")
		"settle":
			# семья въезжает, как только первый из неё дошёл до двери (остальные подтянутся)
			r["state"] = "home"
			_door_in(r, city.buildings.get(r["home"], {}), "home")
			var h: Dictionary = city.buildings.get(r["home"], {})
			var nm := str(r["fam"])
			var pf: Dictionary = city.pending.get(nm, {})
			if not h.is_empty() and not pf.is_empty() and int(pf["home"]) == int(r["home"]):
				var fam := _fam_members(nm, r["home"])
				var n := int(pf["n"])
				h["coming"] = maxi(0, int(h.get("coming", 0)) - n)
				var took := city.settled(r["home"], n, nm)
				_float_text(city.door_point(h), "+ семья %s" % nm)
				# кому не хватило места — уходят ждать на площадь
				var extra := []
				if took < fam.size():
					var keep := [r] if took > 0 else []
					extra = fam.filter(func(x): return not keep.has(x))
					extra = extra.slice(0, fam.size() - took)
					for m: Dictionary in extra:
						m["home"] = -1
						if m["state"] == "home":
							m["p"] = city.door_point(h)
						_go(m, _plaza_point(), "plaza")
					waiting_fams.append({"name": nm, "members": extra.map(func(x): return x["id"])})
					city.family_arrived({"name": nm, "n": extra.size(), "cls": h_cls(h), "m": _recs(extra)}, false)
				# в записи семьи в доме — именно те, кто вошёл (имена и облик остаются при них)
				var hf := _family_rec(nm, int(r["home"]))
				if took > 0 and not hf.is_empty():
					var stay := _recs(fam.filter(func(x): return not extra.has(x)))
					if stay.size() == int(hf["n"]):
						hf["m"] = stay
		"leave":
			_remove(r)


func h_cls(h: Dictionary) -> String:
	return city.def(h)["cls"] if not h.is_empty() else "plebs"


func _fam_members(name: String, home: int) -> Array:
	return residents.filter(func(x): return x["fam"] == name and x["home"] == home)


## Записи членов семьи у этих жителей (Residents)
static func _recs(rs: Array) -> Array:
	var out := []
	for r: Dictionary in rs:
		if r.has("m"):
			out.append(r["m"])
	return out


func _remove(r: Dictionary) -> void:
	if int(r["id"]) == focus_rid:
		set_focus(0)
	_leave_slot(r)
	_release(r)
	_hide(r)
	residents.erase(r)
	by_id.erase(r["id"])


# ---------- работа ----------

## Раздать работу: на каждое рабочее место — ближайший взрослый житель нужного класса (или выше)
func _assign_jobs() -> void:
	_jobs_dirty = false
	var need := []
	for id in city.buildings:
		var b: Dictionary = city.buildings[id]
		var d := city.def(b)
		if not d.has("jobs") or city.is_house(b) or not b.get("road", true) or b.get("over", false):
			continue                     # сверх предела уровня — не работает, работников не берёт
		var jb := city.jobs_of(b)
		for c in jb:
			for k in int(jb[c]):
				need.append([id, c])
	var keep := {}
	for r in residents:
		if r["job"] >= 0:
			if not city.buildings.has(r["job"]) or r["child"] or int(r["home"]) <= 0 or city.buildings[r["job"]].get("over", false):
				_quit_job(r)
			elif int(keep.get(r["job"], 0)) >= city.hired_of(city.buildings[r["job"]]):
				_quit_job(r)                  # игрок уволил лишних
			else:
				keep[r["job"]] = int(keep.get(r["job"], 0)) + 1
	var order := {"plebs": ["plebs", "artisans", "patricians"], "artisans": ["artisans", "patricians"], "patricians": ["patricians"]}
	var count := {}
	for nd in need:
		var bid: int = nd[0]
		count[bid] = int(count.get(bid, 0)) + 1
		if int(keep.get(bid, 0)) >= int(count[bid]):
			continue
		var bp: Vector2 = city.buildings[bid]["pos"]
		var best := {}
		var bd := INF
		for cl in order[nd[1]]:
			for r in residents:
				if r["job"] >= 0 or r["child"] or int(r["home"]) <= 0 or r["cls"] != cl:
					continue
				var dd := (r["p"] as Vector2).distance_squared_to(bp)
				if dd < bd:
					bd = dd
					best = r
			if not best.is_empty():
				break
		if best.is_empty():
			continue
		best["job"] = bid
		keep[bid] = int(keep.get(bid, 0)) + 1


func _quit_job(r: Dictionary) -> void:
	_leave_slot(r)
	r["job"] = -1
	if r["state"] == "work":
		r["state"] = "idle"
		r["t"] = 0.0
		r["goal"] = "errand"


func _enter_work(r: Dictionary) -> void:
	var b: Dictionary = city.buildings.get(r["job"], {})
	if b.is_empty():
		r["state"] = "idle"
		r["t"] = 0.0
		return
	r["state"] = "work"
	var bp := city.blueprint(b)
	var list: Array = slots.get(b["id"], [])
	list.resize(bp.actors.size())
	var free := -1
	for k in list.size():
		if list[k] == null or int(list[k]) == 0:
			free = k
			break
	if free < 0:
		if (r["p"] as Vector2).distance_to(city.door_point(b)) < 1.5:
			_door_in(r, b, "work")       # внутри мастерской — входит в дверь
		else:
			_hide(r)
		return
	list[free] = r["id"]
	slots[b["id"]] = list
	r["slot"] = free
	var a: Array = bp.actors[free]
	var c := _node(r)
	if c:
		var xf: Transform3D = city.xf(b) * Transform3D(Basis(Vector3.UP, float(a[1])), a[0])
		if (a[0] as Vector3).y < 0.05:
			xf.origin.y = land.height_at(xf.origin.x, xf.origin.z)      # стоит на земле, а не над ней
		c.transform = xf
		c.scale = Vector3.ONE * Citizen.SIZE * (0.68 if r["child"] else 1.0)
		c.set_alpha(1.0)
		r["fade"] = 1.0
		r["p"] = Vector2(xf.origin.x, xf.origin.z)
		# без собеседника никто не говорит «в воздух»: разговор — только с покупателем (_keeper_react)
		var sa: String = "Idle" if String(a[2]).begins_with("Idle_Talking") else String(a[2])
		r["slot_base"] = sa              # движение по чертежу; на лире музыкант играет, только когда она в руках (_slot_clip)
		r.erase("carry")
		c.play(sa, 0.3, rng.randf())
		# продавец за прилавком: помнит, как стоит, чтобы повернуться к покупателю и вернуться обратно
		r["slot_anim"] = sa
		r["slot_yaw"] = c.rotation.y
		r["slot_front"] = absf(wrapf(float(a[1]), -PI, PI)) < 0.8      # стоит лицом к улице
		r["face"] = c.rotation.y
		r["serve"] = 0
		r["wk"] = rng.randf_range(6.0, 14.0)


func _leave_slot(r: Dictionary) -> void:
	if int(r["slot"]) < 0:
		return
	HandProps.drop(r["node"])               # с работы — без лиры и серпа в руках
	var list: Array = slots.get(r["job"], [])
	if int(r["slot"]) < list.size():
		list[r["slot"]] = 0
	r["slot"] = -1


func work_door(r: Dictionary) -> Vector2:
	var b: Dictionary = city.buildings.get(r["job"], {})
	if b.is_empty():
		return r["p"]
	var bp := city.blueprint(b)
	if bp.actors.size() > 0:
		var a: Array = bp.actors[0]
		var p3: Vector3 = city.xf(b) * (a[0] as Vector3)
		var q := Vector2(p3.x, p3.z)
		if _free(q):
			return q
	return city.door_point(b)


# ---------- распорядок дня ----------

## В начале игры и после загрузки: кто уже на работе, кто гуляет
func _start_of_day(instant: bool) -> void:
	var h: float = game.hour
	for r in residents:
		if int(r["home"]) <= 0:
			continue
		if r["job"] >= 0 and h >= 8.0 and h < 17.0:
			r["p"] = work_door(r)
			_enter_work(r)
		elif instant and h >= 9.0 and h < 18.0 and rng.randf() < (0.3 if r["child"] else 0.25):
			# уже на улице: у прилавка, на скамье, у колодца, на площади
			var d := _pick_errand(r)
			if d.is_empty():
				continue
			_claim(r, d)
			r["p"] = d["p"]
			r["goal"] = "errand"
			_arrive(r)


func _hours_to(a: Vector2, b: Vector2) -> float:
	var mph := WALK * Game.DAY_LEN / 24.0
	return a.distance_to(b) * 1.3 / mph


## Раз в четверть секунды: кому куда идти по часам
func _schedule(dh: float) -> void:
	var h: float = game.hour
	var night := h >= 21.5 or h < 5.0
	for r in residents.duplicate():
		match r["state"]:
			"home":
				if int(r["home"]) <= 0:
					continue
				if r["job"] >= 0:
					var b: Dictionary = city.buildings.get(r["job"], {})
					if b.is_empty():
						continue
					var dep := 8.0 - _hours_to(r["p"], work_door(r)) + float(r["dep"])
					if h >= dep and h < 16.5 and not r["done_today"]:
						r["done_today"] = true
						_go(r, work_door(r), "work")
				elif not night and h >= 8.5 and h < 19.5:
					var chance := 0.02 if r["child"] else 0.025
					if rng.randf() < chance * dh * 4.0 * 10.0:
						r["outs"] = 0
						_errand(r)
			"work":
				if h >= 17.0 + float(r["ret"]) or h < 6.0:
					var hp: Dictionary = city.buildings.get(r["home"], {})
					if hp.is_empty():
						continue
					if rng.randf() < 0.3 and h < 19.0:
						r["outs"] = 1
						_errand(r)
					else:
						_go(r, city.door_point(hp), "home")
			"idle":
				r["t"] = float(r["t"]) - dh
				if r["goal"] == "arrived":
					if float(r["t"]) <= 0.0 and int(r["home"]) > 0:
						var hb: Dictionary = city.buildings.get(r["home"], {})
						if hb.is_empty():
							r["home"] = -1
						else:
							_go(r, city.door_point(hb), "settle")
					continue
				if r["act"] != "" and not night:
					continue                     # занят делом (лавка, скамья, разговор) — сам решит, когда уйти
				if float(r["t"]) <= 0.0 or night:
					var hp: Dictionary = city.buildings.get(r["home"], {})
					if hp.is_empty():
						continue
					_go(r, city.door_point(hp), "home")
	# новый день — снова можно на работу
	if h < _hour - 12.0:
		for r in residents:
			r["done_today"] = false
	_hour = h


func _near_road(p: Vector2, r: float) -> Vector2:
	for k in 24:
		var q := p + Vector2(rng.randf_range(-r, r), rng.randf_range(-r, r))
		if _free(q):
			return q
	return p


# ---------- жизнь на улице: лавки, скамьи, кошки, разговоры, двери ----------
# Как в Town to City: житель идёт к настоящей цели — к прилавку лавки, что кормит его дом, на скамью, к колодцу,
# к кошке, на площадь. У прилавка встаёт лицом к продавцу, говорит с ним, берёт товар; продавец поворачивается
# к нему и отвечает. На скамье садится и сидит, рядом сидящие болтают. На площади люди сходятся по двое-трое и
# разговаривают по очереди (один говорит — другие слушают и кивают); в одиночку никто не говорит в пустоту.
# В дом и в лавку входят через дверь: повернулся к ней, шагнул и растаял; выходят — проявляются в дверях.

var spots := {}                      # id постройки → {номер места: rid} — места у прилавка, зрителей, на скамьях, у колодца
var convs := []                      # разговоры: {"m": [rid], "spk": rid, "sw": сек до новой реплики, "left": сек, "open": можно подойти}
var _bp_spots := {}                  # места в осях постройки (по чертежу) — считаются один раз
var _vis_t := 0.0
## Жители без узла (их не видно: идут «невидимо», вне кадра) шагают не каждый кадр, а по очереди: за кадр — каждый
## FAR_N-й (по номеру жителя), за всё время, накопленное его очередью (1.7 плана 24.10): на экране то же самое,
## процессору меньше работы и без рывков (не все разом). far_n = 1 — каждый кадр (сверка в test_perf)
const FAR_N := 8
var far_n := FAR_N
var _far_acc := PackedFloat32Array()   # сколько времени накопила каждая очередь
var _far_ph := 0
var _frame_sdt := 0.0                # игровое время этого кадра: проявление не быстрее, чем за кадр (не по накопленному)
## Вещи в руках (HandProps): у работников — по месту работы, у прохожих — покупка, которую несут домой.
## Только вблизи камеры и не больше PROP_CAP разом; на «Низкой» и «Очень низкой» — нет (Gfx.apply)
var props_on := true
var _prop_t := 0.0
const PROP_R := 32.0
const PROP_CAP := 18

const SIT_BACK := 0.21               # сидящий: таз на столько позади ступней (движение Sitting_* при нашем росте)
const SIT_SEAT := 0.3                # и на такой высоте над землёй
const TALK_D := 0.85                 # расстояние между собеседниками
const RUN := 2.3                     # дети бегают (м/с)
const TALK_ANIMS := ["Idle_Talking", "Idle_Talking_M", "Idle_Talking", "Idle_Talking_M", "Idle_Talking", "Interact", "Interact_M", "Spell_Simple_Idle", "Spell_Simple_Idle_M"]
const LISTEN_ANIMS := ["Listen", "Listen_M", "Listen", "Listen_M", "Idle"]
const SOLO_ANIMS := ["Idle", "Look_Around", "Look_Around_M", "Idle"]
const WATCH := ["musicians", "dice", "mimes", "puppets", "ludus"]                 # смотрят представление
const ENTER := ["odeon", "theatre", "balnea", "baths", "medic", "taberna", "fullonica", "dyer", "thermae"]   # заходят внутрь
const STAND := ["Idle_Talking", "Interact", "Idle"]                    # продавцы, что стоят и могут повернуться


static func _yaw_to(a: Vector2, b: Vector2) -> float:
	var d := b - a
	return atan2(d.x, d.y) if d.length_squared() > 0.0001 else 0.0


## Включить движение у жителя (если он виден); phase < 0 — с любого места, чтобы соседи не двигались в такт
func _anim(r: Dictionary, name: String, blend := 0.35, phase := -1.0) -> void:
	var c: Citizen = r["node"]
	if c:
		c.play(name, blend, rng.randf() if phase < 0.0 else phase)


## Череда движений [[движение, секунды], …]; когда кончится — _act_done
func _seq(r: Dictionary, steps: Array) -> void:
	r["seq"] = steps
	r["si"] = -1
	r["st"] = 0.0
	_seq_next(r)


func _seq_next(r: Dictionary) -> bool:
	var steps: Array = r["seq"]
	var i := int(r["si"]) + 1
	if i >= steps.size():
		return false
	r["si"] = i
	var s: Array = steps[i]
	r["st"] = float(s[1])
	var nm: String = s[0]
	if nm == "SIT":
		_sit_pick(r)
	elif nm != "":
		_anim(r, nm, 0.3, 0.0 if nm in ["Sitting_Enter", "Sitting_Exit", "Fixing_Kneeling", "Fixing_Kneeling_M", "PickUp_Table", "PickUp_Table_M"] else -1.0)
	_on_step(r, nm)
	return true


# ---------- куда пойти ----------

## Новое дело вне дома: выбрать цель, занять место, идти
func _errand(r: Dictionary) -> void:
	if r.has("hero"):
		_hero_errand(r)
		return
	var d := _pick_errand(r)
	if d.is_empty():
		var hp: Dictionary = city.buildings.get(r["home"], {})
		if not hp.is_empty() and r["state"] != "home":
			_go(r, city.door_point(hp), "home")
		return
	_release(r)
	_claim(r, d)
	_go(r, d["p"], "errand", true)


func _claim(r: Dictionary, d: Dictionary) -> void:
	r["dest"] = d
	if d.has("bid") and int(d.get("k", -1)) >= 0:
		var sp: Dictionary = spots.get(d["bid"], {})
		sp[int(d["k"])] = int(r["id"])
		spots[d["bid"]] = sp
	if d.has("cat"):
		var c: Dictionary = d["cat"]
		c["pet"] = int(r["id"])
		c["t"] = 999.0                    # кошка ждёт, пока к ней подойдут


## Отпустить всё занятое: место у прилавка или на скамье, кошку, разговор
func _release(r: Dictionary) -> void:
	var d: Dictionary = r["dest"]
	if d.has("bid") and int(d.get("k", -1)) >= 0:
		var sp: Dictionary = spots.get(d["bid"], {})
		if int(sp.get(int(d["k"]), 0)) == int(r["id"]):
			sp.erase(int(d["k"]))
	if str(d.get("act", "")) == "shop":
		_keeper_free(int(d["bid"]), r)
	if d.has("cat"):
		var c: Dictionary = d["cat"]
		if int(c.get("pet", 0)) == int(r["id"]):
			c["pet"] = 0
			if c["state"] == "pet":
				c["state"] = "sit"
			c["t"] = rng.randf_range(2.0, 6.0)
	_conv_leave(r)
	if int(r["pal"]) > 0:
		var o: Dictionary = by_id.get(int(r["pal"]), {})
		if not o.is_empty() and int(o["pal"]) == int(r["id"]):
			o["pal"] = 0
		r["pal"] = 0
	r["dest"] = {}
	r["act"] = ""
	r["seq"] = []


## Что делать вне дома — по весам: лавки своего дома, скамья, колодец, фонтанчик, статуя, кошка, площадь. Дети играют.
func _pick_errand(r: Dictionary) -> Dictionary:
	var h: Dictionary = city.buildings.get(r["home"], {})
	var from: Vector2 = h["pos"] if not h.is_empty() else r["p"]
	var hour: float = game.hour
	var opts := []
	var cat := _cat_free(r["p"], 24.0)
	if r["child"]:
		opts.append([6.0, {"act": "play", "p": _near_road(city.door_point(h) if not h.is_empty() else r["p"], 7.0)}])
		if not cat.is_empty():
			opts.append([2.5, _cat_target(r, cat)])
	else:
		if not h.is_empty() and hour < 18.0:
			var s := _shop_target(r, h)
			if not s.is_empty():
				opts.append([7.0, s])
		for e: Array in [["bench", "sit", 50.0, 3.0], ["well", "well", 45.0, 1.2], ["smallfountain", "drink", 45.0, 1.2], ["statue", "look", 60.0, 0.8], ["column", "look", 60.0, 0.5]]:
			var t := _decor_target(r, from, e[0], e[1], e[2])
			if not t.is_empty():
				opts.append([e[3], t])
		if not cat.is_empty():
			opts.append([1.0, _cat_target(r, cat)])
		var pz := _plaza_target(r, from)
		if not pz.is_empty():
			opts.append([3.0, pz])
	if city.fest_left > 0:                     # игры в честь богов: город сходится на площадь у станции
		var fz := _fest_target(r, from)
		if not fz.is_empty():
			opts.append([4.0 if r["child"] else 6.0, fz])
	var sum := 0.0
	for o in opts:
		if not (o[1] as Dictionary).is_empty():
			sum += float(o[0])
	var x := rng.randf() * sum
	for o in opts:
		if (o[1] as Dictionary).is_empty():
			continue
		x -= float(o[0])
		if x <= 0.0:
			return o[1]
	return {}


## Лавка, что обслуживает дом (h["score"]): ближайшая такого вида; свободное место у прилавка
func _shop_target(r: Dictionary, h: Dictionary) -> Dictionary:
	var types: Array = (h.get("score", {}) as Dictionary).keys()
	for k in types.size():
		var j := rng.randi() % types.size()
		var tmp = types[k]
		types[k] = types[j]
		types[j] = tmp
	# откуда только что вышел (бани, таверна, лавка) — туда же сразу обратно не идёт
	var last := int((r["dest"] as Dictionary).get("bid", -1))
	for t in types:
		var best := {}
		var bd := 75.0
		for id in city.buildings:
			var b: Dictionary = city.buildings[id]
			if b["type"] != t or not b.get("active", true) or int(b["id"]) == last:
				continue
			var dd := (b["pos"] as Vector2).distance_to(h["pos"])
			if dd < bd:
				bd = dd
				best = b
		if best.is_empty():
			continue
		var d := {}
		if t in WATCH:
			d = _watch_target(r, best)
		elif t in ENTER:
			d = {"act": "enter", "bid": best["id"], "k": -1, "p": city.door_point(best)}
		else:
			if _keeper(best["id"]).is_empty() and rng.randf() < 0.75:
				continue                      # продавца нет за прилавком — в другой раз
			d = _counter_target(r, best)
		if not d.is_empty():
			return d
	return {}


## Свободная ли точка для человека (не внутри стен), иначе — подвинуть вперёд от постройки
func _spot_ok(w: Vector2, fwd: Vector2) -> Vector2:
	for k in 7:
		var q := w + fwd * 0.15 * k
		if _free(q):
			return q
	return Vector2.INF


## Места покупателей у прилавка (в осях постройки): перед продавцом и по бокам, сразу за прилавком
func _counter_spots(b: Dictionary) -> Array:
	var key := "c:%s:%d:%d:%d" % [b["type"], int(b["tier"]), int(b.get("variant", 0)), int(b.get("color", 0))]
	if _bp_spots.has(key):
		return _bp_spots[key]
	var bp := city.blueprint(b)
	var out := []
	var kp := Vector3(bp.door.x, 0, bp.door.z - 1.0)
	var ky := 0.0
	if bp.actors.size() > 0:
		kp = bp.actors[0][0]
		ky = float(bp.actors[0][1])
	if absf(wrapf(ky, -PI, PI)) > 0.8:
		# мастер стоит спиной к улице (пекарь у печи) — покупатели ждут у входа, напротив него
		for ox: float in [0.0, -0.5, 0.5]:
			out.append([Vector3(kp.x + ox, 0, bp.door.z + 0.1), kp])
		_bp_spots[key] = out
		return out
	var f := Vector3(sin(ky), 0, cos(ky))
	var l := Vector3(cos(ky), 0, -sin(ky))
	for ox: float in [0.0, -0.5, 0.5]:
		var z := 0.4
		for p in bp.parts:
			var nm: String = p[0]
			if nm.begins_with("#"):
				continue
			var box := Bp.model_aabb(nm)
			var xf: Transform3D = p[1]
			var lo := Vector3(INF, INF, INF)
			var hi := -lo
			for i in 8:
				var q := xf * box.get_endpoint(i) - kp
				var v := Vector3(q.dot(l), q.y, q.dot(f))
				lo = lo.min(v)
				hi = hi.max(v)
			# только низкое на земле перед продавцом: прилавок, стол, корзины
			if lo.y > 0.3 or hi.y > 1.35 or hi.y < 0.25 or hi.z < 0.05 or lo.z > 1.0 or hi.x < ox - 0.2 or lo.x > ox + 0.2:
				continue
			z = maxf(z, hi.z + 0.27)
		out.append([kp + l * ox + f * minf(z, 2.2), kp])
	_bp_spots[key] = out
	return out


func _counter_target(r: Dictionary, b: Dictionary) -> Dictionary:
	var xf := city.xf(b)
	var fwd := City.facing(b["yaw"])
	var sp: Dictionary = spots.get(b["id"], {})
	var list := _counter_spots(b)
	for k in list.size():
		if sp.has(k):
			continue
		var w: Vector3 = xf * (list[k][0] as Vector3)
		var q := _spot_ok(Vector2(w.x, w.z), fwd)
		if q == Vector2.INF:
			continue
		var kw: Vector3 = xf * (list[k][1] as Vector3)
		return {"act": "shop", "bid": b["id"], "k": k, "p": q, "face": Vector2(kw.x, kw.z)}
	return {}


## Зрители у музыкантов, игроков в кости, мимов: полукругом перед ними
func _watch_target(r: Dictionary, b: Dictionary) -> Dictionary:
	var bp := city.blueprint(b)
	var xf := city.xf(b)
	var fwd := City.facing(b["yaw"])
	var c := Vector3.ZERO
	for a in bp.actors:
		c += a[0] as Vector3
	if bp.actors.size() > 0:
		c /= bp.actors.size()
	var door := bp.door
	var rad := maxf(1.3, door.z - c.z + 0.4)
	var sp: Dictionary = spots.get(b["id"], {})
	var angs := [0.0, -0.45, 0.45, -0.9, 0.9, -0.22, 0.22]
	for k in angs.size():
		if sp.has(k):
			continue
		var a: float = angs[k]
		var rr := rad + (0.55 if k >= 5 else 0.0)
		var lp := c + Vector3(sin(a), 0, cos(a)) * rr
		var w: Vector3 = xf * lp
		var q := _spot_ok(Vector2(w.x, w.z), fwd)
		if q == Vector2.INF:
			continue
		var cw: Vector3 = xf * c
		return {"act": "watch", "bid": b["id"], "k": k, "p": q, "face": Vector2(cw.x, cw.z), "type": b["type"]}
	return {}


## Места у украшения: скамья — сиденья, колодец и фонтанчик — подойти спереди, статуя — посмотреть
func _decor_target(r: Dictionary, from: Vector2, base: String, act: String, maxd: float) -> Dictionary:
	var cands := []
	for id in city.buildings:
		var b: Dictionary = city.buildings[id]
		if b.has("host") or Defs.base_of(b["type"]) != base:
			continue
		var dd := (b["pos"] as Vector2).distance_to(from)
		if dd <= maxd:
			cands.append([dd + rng.randf() * 10.0, b])
	cands.sort_custom(func(a, c): return a[0] < c[0])
	for e in cands.slice(0, 4):
		var b: Dictionary = e[1]
		var d := _seat_target(r, b) if act == "sit" else _front_target(r, b, act)
		if not d.is_empty():
			return d
	return {}


## Сиденья скамьи (в осях постройки): [где стоят ступни, куда смотрит, высота сиденья]
func _bench_seats(b: Dictionary) -> Array:
	var key := "s:%s:%d:%d" % [b["type"], int(b.get("variant", 0)), int(b.get("color", 0))]
	if _bp_spots.has(key):
		return _bp_spots[key]
	var out := []
	var bp := city.blueprint(b)
	for p in bp.parts:
		var nm: String = p[0]
		if not nm.begins_with("SM_Prop_Seat_Bench"):
			continue
		var xf: Transform3D = p[1]
		var box := Bp.model_aabb(nm)
		var sc := xf.basis.get_scale()
		var w := box.size.x * sc.x
		var fwd := xf.basis.z.normalized()
		var side := xf.basis.x.normalized()
		var seat_h := minf(box.size.y, 0.5) * sc.y
		var mid := xf * Vector3(box.get_center().x, 0, box.get_center().z)
		var n := 3 if w > 1.55 else 2
		for i in n:
			var o := (i - (n - 1) / 2.0) * w * (0.3 if n == 3 else 0.44)
			out.append([mid + side * o + fwd * SIT_BACK, atan2(fwd.x, fwd.z), seat_h])
		break
	_bp_spots[key] = out
	return out


func _seat_target(r: Dictionary, b: Dictionary) -> Dictionary:
	var seats := _bench_seats(b)
	var sp: Dictionary = spots.get(b["id"], {})
	var xf := city.xf(b)
	var order := range(seats.size())
	if rng.randf() < 0.5:
		order.reverse()
	for k in order:
		if sp.has(k):
			continue
		var s: Array = seats[k]
		var w: Vector3 = xf * (s[0] as Vector3)
		return {"act": "sit", "bid": b["id"], "k": k, "p": Vector2(w.x, w.z), "yaw": float(b["yaw"]) + float(s[1]), "seat": float(s[2])}
	return {}


func _front_target(r: Dictionary, b: Dictionary, act: String) -> Dictionary:
	var bp := city.blueprint(b)
	var xf := city.xf(b)
	var fwd := City.facing(b["yaw"])
	var side := City.axis(b["yaw"])
	var sp: Dictionary = spots.get(b["id"], {})
	var dp := city.door_point(b)
	var ctr := Vector2(xf.origin.x, xf.origin.z)
	var offs := [0.0, -0.55, 0.55] if act != "look" else [0.0, -0.8, 0.8, -1.5, 1.5]
	for k in offs.size():
		if sp.has(k):
			continue
		var q := _spot_ok(dp + side * float(offs[k]) + (fwd * 0.4 if act == "look" else Vector2.ZERO), fwd)
		if q == Vector2.INF:
			continue
		return {"act": act, "bid": b["id"], "k": k, "p": q, "face": ctr}
	return {}


## Площадь: фонтан, храм, форум, почтовая станция — погулять и поговорить с кем-нибудь
func _plaza_target(r: Dictionary, from: Vector2) -> Dictionary:
	var opts := []
	for id in city.buildings:
		var b: Dictionary = city.buildings[id]
		if b["type"] in ["fountain", "temple", "forum", "center", "arch", "pantheon"] and (b["pos"] as Vector2).distance_to(from) < 80.0:
			opts.append(b)
	if opts.is_empty():
		var q := _near_road(r["p"], 10.0)
		return {"act": "stroll", "p": q}
	var b: Dictionary = opts[rng.randi() % opts.size()]
	var base := city.door_point(b)
	# рядом с теми, кто уже стоит там, — чтобы было с кем поговорить
	for o in residents:
		if o["state"] == "idle" and o["act"] == "solo" and not o["child"] and (o["p"] as Vector2).distance_to(base) < 9.0 and rng.randf() < 0.6:
			base = o["p"]
			break
	# не в толпу: точка, где в полутора метрах никто не стоит и не идёт туда же
	var near := _stand_points(base, 8.0)
	for k in 20:
		var a := rng.randf() * TAU
		var q := base + Vector2(cos(a), sin(a)) * rng.randf_range(1.2, 5.0 + k * 0.2)
		if _free(q) and not _crowded(q, near, 1.5):
			return {"act": "stroll", "p": q}
	return {}


## Игры в честь богов: место в толпе у почтовой станции — на площади и дороге у входа, лицом к станции
## (дети бегают там же); идут те, чей дом не дальше 110 м. Где едет и встаёт повозка, толпы нет: полоса большой
## дороги севернее станции и место разгрузки (_plaza_point) свободны — толпа больше южнее входа, откуда идёт город
func _fest_target(r: Dictionary, from: Vector2) -> Dictionary:
	var c := city.center()
	if c.is_empty():
		return {}
	var base := city.door_point(c)
	if from.distance_to(base) > 110.0:
		return {}
	var f := City.facing(float(c["yaw"]))
	var ax := City.axis(float(c["yaw"]))
	var near := _stand_points(base + f * 4.0 - ax * 4.0, 15.0)
	for k in 24:
		# через раз — на дороге и площади южнее входа (станция стоит всегда одинаково: −ax — к югу), иначе — где угодно у входа
		var q := base + f * rng.randf_range(1.5, 8.5) - ax * rng.randf_range(5.5, 16.0) if k % 2 == 0 \
			else base + f * rng.randf_range(1.0, 10.0) + ax * rng.randf_range(-16.0, 9.0)
		var d := q - base
		# повозке — дорогу: её полоса по большой дороге до станции и место, где она встаёт (_plaza_point: ±3,5 по x, ±4,5 по z)
		if (absf(q.x - Land.ROAD_X) < Land.ROAD_R + 0.5 and q.y < base.y + 5.5) or (absf(d.x) < 4.5 and absf(d.y) < 5.5):
			continue
		if _free(q) and not _crowded(q, near, 1.1):
			if r["child"]:
				return {"act": "play", "p": q}
			# взрослые смотрят игры (пляшут, как у музыкантов) или болтают с соседями
			return {"act": "watch" if rng.randf() < 0.6 else "stroll", "type": "musicians", "p": q, "face": base}
	return {}


## Где стоят (или куда идут, чтобы стоять) люди рядом с точкой
func _stand_points(c: Vector2, rad: float) -> Array:
	var out := []
	for o in residents:
		var p: Vector2 = o["p"]
		if o["state"] == "walk" and o["goal"] in ["errand", "talk"] and (o["path"] as PackedVector2Array).size() > 0:
			p = o["path"][o["path"].size() - 1]
		elif o["state"] != "idle":
			continue
		if p.distance_squared_to(c) < rad * rad:
			out.append(p)
	return out


func _crowded(q: Vector2, pts: Array, d: float) -> bool:
	for p: Vector2 in pts:
		if p.distance_squared_to(q) < d * d:
			return true
	return false


func _cat_free(from: Vector2, maxd: float) -> Dictionary:
	var best := {}
	var bd := maxd
	var hour: float = game.hour
	if hour < 7.0 or hour > 20.0:
		return best
	for c in cats:
		if c["state"] in ["sit", "sleep"] and int(c.get("pet", 0)) == 0 and not c.has("story"):
			var dd := (c["p"] as Vector2).distance_to(from)
			if dd < bd and _free(c["p"]):
				bd = dd
				best = c
	return best


func _cat_target(r: Dictionary, c: Dictionary) -> Dictionary:
	var cp: Vector2 = c["p"]
	var a0 := _yaw_to(cp, r["p"])
	for k in 8:
		var a := a0 + (k / 2) * 0.7 * (1.0 if k % 2 == 0 else -1.0)
		var q := cp + Vector2(sin(a), cos(a)) * 0.4
		if _free(q):
			return {"act": "cat", "cat": c, "p": q, "face": cp}
	return {}


# ---------- на месте ----------

## Пришёл к цели — занялся делом
func _begin(r: Dictionary) -> void:
	var d: Dictionary = r["dest"]
	var act: String = d.get("act", "stroll")
	if d.has("bid") and not city.buildings.has(d["bid"]):
		act = "stroll"
	if r["child"] and r["goal"] == "play":
		act = "play"
	r["state"] = "idle"
	r["t"] = 99.0
	r["act"] = act
	r["at"] = 0.0
	if d.has("face"):
		r["face"] = _yaw_to(r["p"], d["face"])
	else:
		r["face"] = float(r["yaw"])
	if act == "enter":
		_door_in(r, city.buildings.get(d["bid"], {}), "inside")
		return
	_node(r)
	match act:
		"shop":
			if _keeper(int(d.get("bid", -1))).is_empty():
				# продавца за прилавком нет (ушёл домой, не наняли) — не говорить с пустым прилавком: посмотреть товар и взять
				_seq(r, [["Idle", rng.randf_range(0.4, 0.8)], ["Look_Around" if rng.randf() < 0.5 else "Look_Around_M", 7.5],
					["PickUp_Table" if rng.randf() < 0.6 else "PickUp_Table_M", 1.66], ["Idle", 0.6]])
				return
			var talk := "Idle_Talking" if rng.randf() < 0.5 else "Idle_Talking_M"
			var steps := [["Idle", rng.randf_range(0.4, 1.2)], [talk, rng.randf_range(2.5, 4.5)], ["Listen", rng.randf_range(1.8, 3.0)],
				["PickUp_Table" if rng.randf() < 0.6 else "PickUp_Table_M", 1.66], ["Idle", rng.randf_range(0.5, 1.0)]]
			if rng.randf() < 0.4:
				steps.insert(3, [talk, rng.randf_range(1.5, 3.0)])
			_seq(r, steps)
		"watch":
			r["at"] = rng.randf_range(14.0, 30.0)
			_watch_pick(r)
		"sit":
			r["face"] = float(d["yaw"])
			r["at"] = rng.randf_range(18.0, 45.0)
			_seq(r, [["Idle", 0.7], ["Sitting_Enter", 1.3], ["SIT", r["at"]], ["Sitting_Exit", 1.03], ["Idle", 0.3]])
		"well":
			_seq(r, [["Idle", 0.4], ["Interact" if rng.randf() < 0.5 else "Interact_M", 4.0], ["PickUp_Table", 1.66], ["Idle", 0.6]])
		"drink":
			_seq(r, [["Idle", 0.4], ["PickUp_Table", 2.5], ["Idle", 0.6], ["Look_Around", 3.5]])
		"look":
			_seq(r, [["Idle", 0.6], ["Look_Around" if rng.randf() < 0.5 else "Look_Around_M", 7.5], ["Idle", rng.randf_range(1.0, 3.0)]])
		"cat":
			var c: Dictionary = d["cat"]
			c["state"] = "pet"
			c["yaw"] = _yaw_to(c["p"], r["p"])
			var kneel: String = ["Fixing_Kneeling", "Fixing_Kneeling_M", "Crouch_Idle", "Crouch_Idle_M"][rng.randi() % 4]
			var secs := 5.2 if kneel.begins_with("Fixing") else rng.randf_range(4.0, 6.5)
			_seq(r, [["Idle", 0.5], [kneel, secs], ["Idle", 0.8]])
		"play":
			_play_begin(r)
		_:
			_social(r)


## Дело сделано: дальше — ещё куда-нибудь или домой
func _act_done(r: Dictionary) -> void:
	if r["act"] in ["shop", "inside"]:
		# вышел от цирюльника, из красильни, от ткача — иногда в новом облике (этап 6.5)
		_shop_visit(r, String((city.buildings.get(int((r["dest"] as Dictionary).get("bid", -1)), {}) as Dictionary).get("type", "")))
	match r["act"]:
		"solo":
			if float(r["at"]) <= 0.0:
				_next(r)
			elif not _join_talk(r):
				_solo_cycle(r)
		"look":
			if rng.randf() < 0.5 and not r.has("hero"):
				_social(r)
			else:
				_next(r)
		"watch":
			if float(r["at"]) <= 0.0:
				_next(r)
			else:
				_watch_pick(r)
		"inside":
			_next(r)
		"talk":
			_seq(r, [["Idle", 9999.0]])
		"play":
			_play_tick(r)
		_:
			_next(r)


func _next(r: Dictionary) -> void:
	if r.has("hero"):
		_hero_next(r)
		return
	var hp: Dictionary = city.buildings.get(r["home"], {})
	r["outs"] = int(r["outs"]) + 1
	var h: float = game.hour
	if hp.is_empty():
		_release(r)
		r["state"] = "idle"
		r["t"] = 0.0
		return
	if int(r["job"]) >= 0 and h >= 7.0 and h < 16.5 and not r["done_today"] and city.buildings.has(r["job"]):
		r["done_today"] = true                # получил работу, пока гулял, — идёт прямо на работу
		_go(r, work_door(r), "work")
		return
	if h >= 8.0 and h < 19.0 and int(r["outs"]) < 3 and rng.randf() < (0.3 if r["child"] else 0.5):
		_errand(r)
	else:
		_go(r, city.door_point(hp), "home")


## Каждый кадр, пока житель занят делом на месте
func _act_step(r: Dictionary, dt: float) -> void:
	var c: Citizen = r["node"]
	var moved := false
	if r["act"] == "play":
		moved = _play_move(r, dt)
	if c:
		var dy := angle_difference(float(r["yaw"]), float(r["face"]))
		if absf(dy) > 0.01:
			r["yaw"] = float(r["yaw"]) + dy * minf(1.0, dt * 5.0)
			moved = true
		if absf(float(r["yoff"]) - float(r["yoff_to"])) > 0.001:
			r["yoff"] = move_toward(float(r["yoff"]), float(r["yoff_to"]), dt * 0.12)
			moved = true
		if moved:
			_place(r)
	if r["act"] in ["solo", "watch", "play"]:
		r["at"] = float(r["at"]) - dt
	if r["act"] == "sit" and _sitting(r):
		r["sw"] = float(r.get("sw", 0.0)) - dt
		if float(r["sw"]) <= 0.0:
			_sit_pick(r)
	r["st"] = float(r["st"]) - dt
	if float(r["st"]) <= 0.0:
		if not _seq_next(r):
			_act_done(r)


## Смена движения в череде: продавец отвечает покупателю, сидящий опускается на скамью
func _on_step(r: Dictionary, nm: String) -> void:
	var d: Dictionary = r["dest"]
	match r["act"]:
		"shop":
			var bid := int(d.get("bid", -1))
			match nm:
				"Idle_Talking", "Idle_Talking_M":
					_keeper_react(bid, r, "Listen" if rng.randf() < 0.6 else "Listen_M")
				"Listen":
					_keeper_react(bid, r, "Idle_Talking" if rng.randf() < 0.5 else "Idle_Talking_M")
				"PickUp_Table", "PickUp_Table_M":
					_keeper_react(bid, r, "Interact" if rng.randf() < 0.5 else "Interact_M")
					# взял покупку — понесёт домой (корзина, амфора, свёрток; HandProps.CARRY)
					var it := String(HandProps.CARRY.get(String((city.buildings.get(bid, {}) as Dictionary).get("type", "")), ""))
					if it != "":
						r["carry"] = it
		"sit":
			match nm:
				"Sitting_Enter":
					r["yoff_to"] = clampf(float(d.get("seat", SIT_SEAT)) - SIT_SEAT, -0.05, 0.14)
				"Sitting_Exit":
					r["yoff_to"] = 0.0
					r["face"] = float(d["yaw"])


func _sitting(r: Dictionary) -> bool:
	var s: Array = r["seq"]
	var i := int(r["si"])
	return i >= 0 and i < s.size() and str(s[i][0]) == "SIT"


## Сидит на скамье: если рядом сидит сосед — болтают по очереди, повернувшись друг к другу; один — сидит, смотрит
func _sit_pick(r: Dictionary) -> void:
	var d: Dictionary = r["dest"]
	r["sw"] = rng.randf_range(3.0, 6.0)
	var nb := {}
	for k in (spots.get(d.get("bid", -1), {}) as Dictionary):
		var o: Dictionary = by_id.get(int(spots[d["bid"]][k]), {})
		if not o.is_empty() and o != r and o["act"] == "sit" and o["state"] == "idle" and _sitting(o):
			nb = o
			break
	var base := float(d.get("yaw", r["face"]))
	if nb.is_empty():
		r["face"] = base
		_anim(r, ["Sitting_Idle", "Sitting_Idle_M"][rng.randi() % 2], 0.4)
		return
	# поворот к соседу — чуть, не сходя с места
	var side := City.axis(base)
	var turn := 0.35 if side.dot((nb["p"] as Vector2) - (r["p"] as Vector2)) > 0.0 else -0.35
	r["face"] = base - turn
	var talking: bool = str((nb["node"] as Citizen)._cur if nb["node"] != null else "").begins_with("Sitting_Talking")
	_anim(r, ("Sitting_Idle" if talking else ("Sitting_Talking" if rng.randf() < 0.5 else "Sitting_Talking_M")), 0.4)


func _watch_pick(r: Dictionary) -> void:
	var t: String = (r["dest"] as Dictionary).get("type", "")
	var opts := ["Idle", "Listen", "Listen_M", "Idle"]
	if t == "mimes" or t == "puppets":
		opts += ["Laugh", "Laugh"]
	elif t == "musicians":
		opts += ["Dance", "Listen"]
	elif t == "dice":
		opts += ["Look_Around", "Laugh"]
	elif t == "ludus":
		opts += ["Look_Around", "Listen", "Dance"]          # лудус: болеют за гладиаторов
	var a: String = opts[rng.randi() % opts.size()]
	_seq(r, [[a, rng.randf_range(2.5, 5.0) if a != "Laugh" else 2.5]])


# ---------- продавец за прилавком ----------

func _keeper(bid: int) -> Dictionary:
	var list: Array = slots.get(bid, [])
	if list.is_empty() or list[0] == null or int(list[0]) == 0:
		return {}
	var k: Dictionary = by_id.get(int(list[0]), {})
	if k.is_empty() or k["state"] != "work":
		return {}
	return k


## Продавец поворачивается к покупателю (не больше чем на 40°) и отвечает ему
func _keeper_react(bid: int, cust: Dictionary, anim: String) -> void:
	var k := _keeper(bid)
	if k.is_empty() or k["node"] == null or not (str(k.get("slot_anim", "")) in STAND) or not bool(k.get("slot_front", true)):
		return
	if int(k["serve"]) != 0 and int(k["serve"]) != int(cust["id"]) and by_id.has(int(k["serve"])):
		return
	k["serve"] = int(cust["id"])
	var base := float(k["slot_yaw"])
	var want := _yaw_to(k["p"], cust["p"])
	k["face"] = base + clampf(angle_difference(base, want), -0.7, 0.7)
	(k["node"] as Citizen).play(anim, 0.3, rng.randf())


func _keeper_free(bid: int, cust: Dictionary) -> void:
	var k := _keeper(bid)
	if k.is_empty() or int(k["serve"]) != int(cust["id"]):
		return
	k["serve"] = 0
	k["face"] = float(k["slot_yaw"])
	k["wk"] = rng.randf_range(4.0, 9.0)
	if k["node"] != null:
		(k["node"] as Citizen).play(k["slot_anim"], 0.4, rng.randf())


## Продавец без покупателей не стоит как статуя: то оглядится, то переложит товар
func _work_step(r: Dictionary, dt: float) -> void:
	var c: Citizen = r["node"]
	if not r.has("slot_yaw"):
		return
	var dy := angle_difference(c.rotation.y, float(r["face"]))
	if absf(dy) > 0.01:
		c.rotation.y += dy * minf(1.0, dt * 4.0)
	if int(r["serve"]) != 0:
		if not by_id.has(int(r["serve"])) or str((by_id[int(r["serve"])] as Dictionary)["act"]) != "shop":
			r["serve"] = 0
			r["face"] = float(r["slot_yaw"])
			c.play(r["slot_anim"], 0.4, rng.randf())
		return
	if not (str(r["slot_anim"]) in STAND):
		return
	r["wk"] = float(r.get("wk", 8.0)) - dt
	if float(r["wk"]) <= 0.0:
		var opts := [r["slot_anim"], r["slot_anim"], "Idle", "Look_Around", "Look_Around_M", "Interact", "Interact_M"]
		var a: String = opts[rng.randi() % opts.size()]
		r["wk"] = 7.5 if a.begins_with("Look") else rng.randf_range(5.0, 11.0)
		c.play(a, 0.4, 0.0 if a.begins_with("Look") else rng.randf())


# ---------- разговоры ----------

## Гуляет на площади: подойти к кому-нибудь поговорить, иначе постоять, оглядеться
func _social(r: Dictionary) -> void:
	r["act"] = "solo"
	r["at"] = rng.randf_range(12.0, 30.0)
	if not _join_talk(r):
		_solo_cycle(r)


func _solo_cycle(r: Dictionary) -> void:
	r["act"] = "solo"
	var a: String = SOLO_ANIMS[rng.randi() % SOLO_ANIMS.size()]
	_seq(r, [[a, 7.5 if a.begins_with("Look") else rng.randf_range(3.0, 6.0)]])


## Найти собеседника рядом: разговор, где меньше трёх, или одинокого прохожего. true — идёт к нему
func _join_talk(r: Dictionary) -> bool:
	if r["child"] or game.hour >= 21.0 or r.has("hero"):
		return false
	var p: Vector2 = r["p"]
	# одинокий прохожий рядом — чаще заговаривают вдвоём; к паре подходят третьим реже
	var q := {}
	var bd := 9.0
	for o in residents:
		if o == r or o["state"] != "idle" or o["act"] != "solo" or o["child"] or o["node"] == null and r["node"] != null:
			continue
		var dd := (o["p"] as Vector2).distance_to(p)
		if dd < bd:
			bd = dd
			q = o
	var best := {}
	bd = 9.0
	for cv in convs:
		if not cv["open"] or (cv["m"] as Array).size() >= 3:
			continue
		var c := _conv_center(cv)
		var dd := c.distance_to(p)
		if dd < bd:
			bd = dd
			best = cv
	if not best.is_empty() and ((q.is_empty() and rng.randf() < 0.5) or rng.randf() < 0.2):
		var to := _conv_slot(best, p)
		if to != Vector2.INF:
			(best["m"] as Array).append(int(r["id"]))
			if (best["m"] as Array).size() >= 3:
				best["open"] = false
			r["conv"] = best
			r["act"] = "talk"
			_go(r, to, "talk", true)
			return true
	if q.is_empty():
		return false
	var qp: Vector2 = q["p"]
	var a0 := _yaw_to(qp, p)
	var others := _stand_points(qp, 2.5).filter(func(x): return x.distance_squared_to(qp) > 0.01 and x.distance_squared_to(p) > 0.01)
	for k in 7:
		var a := a0 + (k / 2) * 0.55 * (1.0 if k % 2 == 0 else -1.0)
		var to := qp + Vector2(sin(a), cos(a)) * TALK_D
		if _free(to) and _free(qp.lerp(to, 0.5)) and not _crowded(to, others, 0.7):
			var cv := {"m": [int(q["id"]), int(r["id"])], "spk": int(q["id"]), "sw": 0.0, "left": rng.randf_range(18.0, 42.0), "open": true}
			convs.append(cv)
			q["conv"] = cv
			q["act"] = "talk"
			q["seq"] = []
			q["st"] = 9999.0
			_anim(q, "Idle", 0.4)
			r["conv"] = cv
			r["act"] = "talk"
			_go(r, to, "talk", true)
			return true
	return false


func _talk_arrived(r: Dictionary) -> void:
	r["state"] = "idle"
	r["t"] = 99.0
	_node(r)
	var cv: Dictionary = r["conv"]
	if cv.is_empty() or not convs.has(cv) or not (cv["m"] as Array).has(int(r["id"])):
		r["conv"] = {}
		r["at"] = rng.randf_range(6.0, 15.0)
		_solo_cycle(r)
		return
	r["act"] = "talk"
	r["seq"] = []
	r["st"] = 9999.0
	cv["sw"] = 0.0                       # все на месте — первая реплика
	_anim(r, "Idle", 0.3)


func _conv_center(cv: Dictionary) -> Vector2:
	var s := Vector2.ZERO
	var n := 0
	for id in cv["m"]:
		var m: Dictionary = by_id.get(int(id), {})
		if m.is_empty():
			continue
		var p: Vector2 = m["p"]
		if m["state"] == "walk" and (m["path"] as PackedVector2Array).size() > 0:
			p = m["path"][m["path"].size() - 1]
		s += p
		n += 1
	return s / maxi(1, n)


## Третий собеседник встаёт так, чтобы получился треугольник, с той стороны, откуда подходит
func _conv_slot(cv: Dictionary, from: Vector2) -> Vector2:
	var ps := []
	for id in cv["m"]:
		var m: Dictionary = by_id.get(int(id), {})
		if not m.is_empty():
			ps.append(m["path"][m["path"].size() - 1] if m["state"] == "walk" and (m["path"] as PackedVector2Array).size() > 0 else m["p"])
	if ps.size() != 2:
		return Vector2.INF
	var c: Vector2 = (ps[0] + ps[1]) * 0.5
	var ab: Vector2 = ps[1] - ps[0]
	var n := Vector2(-ab.y, ab.x).normalized()
	if n.dot(from - c) < 0.0:
		n = -n
	for k in 3:
		var to := c + n.rotated((k / 2) * 0.4 * (1.0 if k % 2 == 0 else -1.0)) * TALK_D * 0.8
		if _free(to):
			return to
	return Vector2.INF


## Разговор: говорят по очереди; говорящий жестикулирует, слушатели смотрят на него и кивают, иногда смеются
func _conv_step(cv: Dictionary, dt: float) -> void:
	var pres := []
	var walkers := []
	for id in cv["m"]:
		var m: Dictionary = by_id.get(int(id), {})
		if m.is_empty():
			continue
		if m["state"] == "idle" and m["act"] == "talk":
			pres.append(m)
		elif m["state"] == "walk":
			walkers.append(m)
	if pres.size() < 2:
		# ждёт подходящего — смотрит на него
		for m in pres:
			if not walkers.is_empty():
				m["face"] = _yaw_to(m["p"], walkers[0]["p"])
		if pres.size() + walkers.size() < 2:
			_conv_end(cv)
		return
	cv["left"] = float(cv["left"]) - dt
	if float(cv["left"]) <= 0.0:
		_conv_end(cv)
		return
	cv["sw"] = float(cv["sw"]) - dt
	if float(cv["sw"]) <= 0.0:
		var cur := int(cv["spk"])
		var cand := pres.filter(func(x): return int(x["id"]) != cur)
		var spk: Dictionary = cand[rng.randi() % cand.size()] if not cand.is_empty() and rng.randf() < 0.85 else pres[0]
		cv["spk"] = int(spk["id"])
		cv["sw"] = rng.randf_range(2.5, 5.5)
		var laugh := rng.randf() < 0.12
		for m in pres:
			if m == spk:
				_anim(m, TALK_ANIMS[rng.randi() % TALK_ANIMS.size()], 0.35)
			else:
				_anim(m, "Laugh" if laugh and rng.randf() < 0.7 else LISTEN_ANIMS[rng.randi() % LISTEN_ANIMS.size()], 0.4)
	var spk_r: Dictionary = by_id.get(int(cv["spk"]), {})
	for m in pres:
		if m == spk_r or spk_r.is_empty() or not pres.has(spk_r):
			var s := Vector2.ZERO
			for o in pres:
				if o != m:
					s += o["p"]
			m["face"] = _yaw_to(m["p"], s / (pres.size() - 1))
		else:
			m["face"] = _yaw_to(m["p"], spk_r["p"])


func _conv_end(cv: Dictionary) -> void:
	convs.erase(cv)
	for id in cv["m"]:
		var m: Dictionary = by_id.get(int(id), {})
		if m.is_empty() or m["conv"] != cv:
			continue
		m["conv"] = {}
		if m["state"] == "idle" and m["act"] == "talk":
			# расходятся не разом: кто-то ещё постоит
			m["act"] = "solo"
			m["at"] = 0.0
			_seq(m, [["Idle", rng.randf_range(0.3, 2.5)]])


func _conv_leave(r: Dictionary) -> void:
	var cv: Dictionary = r["conv"]
	r["conv"] = {}
	if cv.is_empty():
		return
	(cv["m"] as Array).erase(int(r["id"]))
	if (cv["m"] as Array).size() <= 1:
		_conv_end(cv)
	else:
		cv["open"] = true
		if int(cv["spk"]) == int(r["id"]):
			cv["sw"] = 0.0


# ---------- дети играют ----------

## Дети играют у дома: вдвоём — в догонялки (один убегает, другой догоняет, догнал — меняются), один — сидит
## на корточках, возится с камешками, подпрыгивает, перебегает
func _play_begin(r: Dictionary) -> void:
	r["act"] = "play"
	r["at"] = rng.randf_range(15.0, 35.0)
	r["pc"] = r["p"]
	r["pk"] = ""
	r["run_to"] = Vector2.INF
	for o in residents:
		# в догонялки — только с тем, кто рядом и до кого видно (не через дом): иначе догоняющий упрётся в стену,
		# а убегающий будет бежать на месте
		if o != r and o["child"] and o["act"] == "play" and o["state"] == "idle" and int(o["pal"]) == 0 \
				and (o["p"] as Vector2).distance_to(r["p"]) < 6.0 and _clear(r["p"], o["p"]):
			o["pal"] = int(r["id"])
			r["pal"] = int(o["id"])
			r["pc"] = o["pc"]
			o["blk"] = 0
			r["blk"] = 0
			o["pk"] = "run"
			_play_run(o)
			r["pk"] = "chase"
			_anim(r, "Jog_Fwd", 0.2)
			r["st"] = 9999.0
			return
	_play_solo(r)


func _play_solo(r: Dictionary) -> void:
	r["pk"] = "solo"
	r["run_to"] = Vector2.INF
	var x := rng.randf()
	if x < 0.45:
		_seq(r, [[["Crouch_Idle", "Crouch_Idle_M"][rng.randi() % 2], rng.randf_range(3.0, 6.0)]])
	elif x < 0.65:
		_seq(r, [["Dance", rng.randf_range(1.5, 3.0)]])
	else:
		var to := _play_point(r)
		if to != Vector2.INF:
			r["run_to"] = to
			r["seq"] = []
			r["st"] = 9999.0
			_anim(r, "Jog_Fwd", 0.2)
		else:
			_seq(r, [["Look_Around", 7.5]])


func _play_point(r: Dictionary) -> Vector2:
	var c: Vector2 = r["pc"]
	for k in 10:
		var a := rng.randf() * TAU
		var q := c + Vector2(cos(a), sin(a)) * rng.randf_range(1.0, 3.8)
		if _free(q) and _clear(r["p"], q):
			return q
	return Vector2.INF


func _play_run(r: Dictionary) -> void:
	var to := _play_point(r)
	if to == Vector2.INF:
		r["pc"] = r["p"]                 # место игры за домом — играем там, где стоим
		to = _play_point(r)
	if to == Vector2.INF:
		# бежать некуда (тесно): постоять и посмеяться — череда кончится, и _play_tick проверит, не пора ли домой
		r["run_to"] = Vector2.INF
		_seq(r, [["Laugh" if rng.randf() < 0.5 else "Idle", rng.randf_range(0.8, 1.5)]])
		return
	r["run_to"] = to
	r["seq"] = []
	r["st"] = 9999.0
	_anim(r, "Jog_Fwd", 0.2)


## Шаг игры: бег к точке или за товарищем. true — сдвинулся
func _play_move(r: Dictionary, dt: float) -> bool:
	if float(r["at"]) <= -5.0 and (r["seq"] as Array).is_empty():
		# игра давно кончилась, а череда так и не дошла до _play_tick (застрял) — заканчиваем череду сейчас:
		# _act_step сразу вызовет _act_done → _play_tick → _next
		r["st"] = 0.0
		return false
	var pal: Dictionary = by_id.get(int(r["pal"]), {})
	if r["pk"] in ["run", "chase"] and (pal.is_empty() or pal["act"] != "play" or pal["state"] != "idle" or int(pal["pal"]) != int(r["id"])):
		r["pal"] = 0
		_play_solo(r)
		return false
	if not (r["seq"] as Array).is_empty():
		return false                     # стоит, смеётся, сидит на корточках
	var to: Vector2 = r["run_to"]
	if r["pk"] == "chase":
		to = pal["p"]
		if (pal["p"] as Vector2).distance_to(r["p"]) < 0.45:
			# догнал! меняются: тот замирает и смеётся, этот убегает
			r["pk"] = "run"
			pal["pk"] = "caught"
			pal["run_to"] = Vector2.INF
			_seq(pal, [["Laugh" if rng.randf() < 0.5 else "Dance", 1.2]])
			_play_run(r)
			return false
	if to == Vector2.INF:
		return false
	var d := to - (r["p"] as Vector2)
	var dist := d.length()
	var mv := RUN * float(r["speed"]) * dt * (0.92 if r["pk"] == "chase" else 1.0)
	if dist <= mv or not _free((r["p"] as Vector2) + d / maxf(dist, 0.001) * minf(mv * 3.0, dist)):
		r["run_to"] = Vector2.INF
		if r["pk"] == "run":
			_seq(r, [["Dance" if rng.randf() < 0.4 else "Idle", rng.randf_range(0.6, 1.4)]])
		elif r["pk"] == "chase":
			r["blk"] = int(r.get("blk", 0)) + 1
			if r["blk"] >= 3 and not pal.is_empty():
				# не добежать (стена между ними) — игра врозь
				r["blk"] = 0
				pal["pal"] = 0
				r["pal"] = 0
				_play_solo(pal)
				_play_solo(r)
			else:
				_seq(r, [["Idle", 0.5]])
		elif r["pk"] == "solo":
			_seq(r, [[["Crouch_Idle", "Idle", "Dance"][rng.randi() % 3], rng.randf_range(1.5, 4.0)]])
		return false
	if r["pk"] == "chase":
		r["blk"] = 0
	r["p"] = (r["p"] as Vector2) + d / dist * mv
	r["face"] = atan2(d.x, d.y)
	r["yaw"] = lerp_angle(float(r["yaw"]), float(r["face"]), minf(1.0, dt * 10.0))
	return true


## Череда игры кончилась: что дальше
func _play_tick(r: Dictionary) -> void:
	if float(r["at"]) <= 0.0:
		_next(r)
		return
	match r["pk"]:
		"run":
			_play_run(r)
		"caught", "chase":
			r["pk"] = "chase"
			r["seq"] = []
			r["st"] = 9999.0
			_anim(r, "Jog_Fwd", 0.2)
		_:
			if int(r["pal"]) == 0:
				for o in residents:
					if o != r and o["child"] and o["act"] == "play" and o["state"] == "idle" and int(o["pal"]) == 0 and o["pk"] == "solo" \
							and (o["p"] as Vector2).distance_to(r["p"]) < 6.0 and _clear(r["p"], o["p"]):
						o["pal"] = int(r["id"])
						r["pal"] = int(o["id"])
						o["pc"] = r["pc"]
						o["blk"] = 0
						r["blk"] = 0
						o["pk"] = "chase"
						o["seq"] = []
						o["st"] = 9999.0
						_anim(o, "Jog_Fwd", 0.2)
						r["pk"] = "run"
						_play_run(r)
						return
			_play_solo(r)


# ---------- двери ----------

## Дошёл до двери: повернулся к ней, шагнул внутрь и растаял. then — "home" или "inside" (в лавке, в банях)
func _door_in(r: Dictionary, b: Dictionary, then: String) -> void:
	var c: Citizen = r["node"]
	if c == null or b.is_empty():
		_door_done(r, then, b)
		return
	var fwd := City.facing(b["yaw"])
	r["state"] = "door"
	r["door"] = {"t": 0.0, "then": then, "from": r["p"], "dir": -fwd, "bid": b["id"]}
	r["face"] = atan2(-fwd.x, -fwd.y)
	c.play("Idle", 0.2)


func _door_step(r: Dictionary, dt: float) -> void:
	var d: Dictionary = r["door"]
	var c: Citizen = r["node"]
	d["t"] = float(d["t"]) + dt
	var t: float = d["t"]
	if c == null:
		_door_done(r, d["then"], city.buildings.get(d["bid"], {}))
		return
	r["yaw"] = lerp_angle(float(r["yaw"]), float(r["face"]), minf(1.0, dt * 9.0))
	if t > 0.25:
		c.play("Walk", 0.15)
		var k := clampf((t - 0.25) / 0.75, 0.0, 1.0)
		r["p"] = (d["from"] as Vector2) + (d["dir"] as Vector2) * 0.5 * k
		c.set_alpha(1.0 - smoothstep(0.35, 1.0, k))
	_place(r)
	if t >= 1.0:
		r["p"] = d["from"]
		_door_done(r, d["then"], city.buildings.get(d["bid"], {}))


func _door_done(r: Dictionary, then: String, b: Dictionary) -> void:
	_hide(r)
	r["door"] = {}
	r.erase("carry")                         # покупку донесли (или зашёл с ней в лавку — дальше без неё)
	if then == "inside":
		r["state"] = "idle"
		r["act"] = "inside"
		r["seq"] = [["", rng.randf_range(15.0, 40.0)]]
		r["si"] = 0
		r["st"] = float(r["seq"][0][1])
	else:
		r["state"] = then


## Ушёл от двери, не дойдя (семья уехала, дом перенесли)
func _door_cancel(r: Dictionary) -> void:
	var d: Dictionary = r["door"]
	if not d.is_empty():
		r["p"] = d["from"]
	r["door"] = {}
	r["state"] = "idle"
	if r["node"] != null:
		(r["node"] as Citizen).set_alpha(1.0)
	r["fade"] = 1.0


# ---------- кадр ----------

func _process(dt: float) -> void:
	if city == null or land == null:
		return
	dt = minf(dt, 0.05)
	var speed: float = game.speed
	_tick += dt
	if _tick >= 0.25:
		var dh: float = _tick * speed * 24.0 / Game.DAY_LEN
		_tick = 0.0
		if _jobs_dirty:
			_assign_jobs()
		if speed > 0.0:
			_schedule(dh)
	_prop_t -= dt
	if _prop_t <= 0.0:
		_prop_t = 0.3
		_props_tick()
	if speed <= 0.0:
		for r in (residents if hero_r.is_empty() else residents + [hero_r]):
			if r["node"] != null:
				(r["node"] as Citizen).anim.speed_scale = 0.0
		for c in cats:
			c["walk"] = 0.0
			if c.has("anim"):
				(c["anim"] as AnimationPlayer).speed_scale = 0.0
		_cats_wear()                           # и на паузе: выбрали вещь в карточке — сразу надета
		return
	var sdt := dt * speed
	_frame_sdt = sdt
	if _far_acc.size() != far_n:
		_far_acc.resize(far_n)
		_far_acc.fill(0.0)
	for k in far_n:
		_far_acc[k] += sdt
	_far_ph = (_far_ph + 1) % far_n
	var fdt := _far_acc[_far_ph]
	_far_acc[_far_ph] = 0.0
	for r in residents.duplicate():
		var rdt := sdt
		if r["node"] == null:
			if int(r["id"]) % far_n != _far_ph:
				continue                       # невидимого — в его очередь, за всё накопленное время
			rdt = fdt
		match r["state"]:
			"walk":
				_step(r, rdt)
			"idle":
				if r["node"] != null:
					(r["node"] as Citizen).anim.speed_scale = speed
				if r["act"] != "":
					_act_step(r, rdt)
			"door":
				if r["node"] != null:
					(r["node"] as Citizen).anim.speed_scale = speed
				_door_step(r, rdt)
			"work":
				if r["node"] != null:
					(r["node"] as Citizen).anim.speed_scale = speed
					_work_step(r, sdt)
			_:
				if r["node"] != null:
					(r["node"] as Citizen).anim.speed_scale = speed
		if r["node"] != null and float(r["fade"]) < 1.0 and r["state"] != "walk" and r["state"] != "door":
			r["fade"] = minf(1.0, float(r["fade"]) + sdt / 0.6)
			(r["node"] as Citizen).set_alpha(float(r["fade"]))
	if not hero_r.is_empty():
		_hero_tick(dt, sdt)
	for cv in convs.duplicate():
		_conv_step(cv, sdt)
	_vis_t -= dt
	if _vis_t <= 0.0:
		_vis_t = 0.5
		_vis_tick()
	_cart_step(dt * speed)
	_cats_step(dt * speed)


## Что у жителя должно быть в руках сейчас: на работе — вещи места (лира, свиток, серп…), по дороге — покупка
func props_want(r: Dictionary) -> Array:
	match r["state"]:
		"work":
			if int(r["slot"]) >= 0:
				return HandProps.work(String((city.buildings.get(r["job"], {}) as Dictionary).get("type", "")), int(r["slot"]))
		"walk", "door":
			if String(r.get("carry", "")) != "":
				return [r["carry"]]
	return []


## Раздать и забрать вещи: ближним к тому, куда смотрит камера (не дальше PROP_R, не больше PROP_CAP), остальным —
## без вещей. Мерим от точки взгляда, а не от самой камеры: при обычном приближении камера в 80 м от города, и вещей
## не было бы видно вовсе; в ролике — от камеры (она у героев)
func _props_tick() -> void:
	var rig = game.rig
	var cam: Camera3D = rig.cam if rig else null
	var at := Vector3.ZERO
	if cam:
		at = cam.global_position if rig.cine else rig.target
	var cands := []
	var lyres := {}
	for r in residents:
		var c: Citizen = r["node"]
		if c == null:
			continue
		var want: Array = props_want(r) if props_on and cam else []
		var d2 := INF
		if not want.is_empty():
			d2 = c.global_position.distance_squared_to(at)
		if want.is_empty() or d2 > PROP_R * PROP_R:
			if HandProps.held(c) != "":
				HandProps.drop(c)
			c.set_carry(false)
			_slot_clip(r, false)
			continue
		cands.append([d2, r, want])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	for i in cands.size():
		var r: Dictionary = cands[i][1]
		var c: Citizen = r["node"]
		if i >= PROP_CAP:
			HandProps.drop(c)
			c.set_carry(false)
			_slot_clip(r, false)
			continue
		var carrying: bool = r["state"] != "work"
		if not carrying:
			_slot_clip(r, true)              # сначала движение с вещью (лира): хват считается по его позе
		HandProps.hold(c, cands[i][2], "Idle" if carrying else String(r.get("slot_anim", "Idle")))
		c.set_carry(carrying)
		if not carrying and "lyre" in cands[i][2]:
			lyres[int(r["job"])] = true
	_bench_lyres(lyres)


## Движение работника — в лад с вещью в руках: с лирой музыкант играет (HandProps.WORK_CLIP), без неё — как в чертеже
## (сидит, а лира лежит на скамье), чтобы не играть на пустой руке
func _slot_clip(r: Dictionary, with_props: bool) -> void:
	if r["state"] != "work" or int(r["slot"]) < 0 or not r.has("slot_base"):
		return
	var t := String((city.buildings.get(r["job"], {}) as Dictionary).get("type", ""))
	var want: String = HandProps.work_clip(t, int(r["slot"]), r["slot_base"]) if with_props else String(r["slot_base"])
	var cur := String(r.get("slot_anim", ""))
	if want == cur:
		return
	var c: Citizen = r["node"]
	if c and c._cur == cur:                  # отвечает покупателю — не перебиваем, вернётся уже к новому
		c.play(want, 0.3, rng.randf())
	r["slot_anim"] = want


var _lyre_hid := {}                  # id музыкантов → [ручка лиры на скамье, что спрятано (Parts.hide_handles)]


## Лира на скамье музыкантов: пока музыкант играет на ней (в руках), на скамье её нет — лира одна, а не две;
## положил (далеко от камеры, «Низкая», ушёл с работы) — снова на скамье
func _bench_lyres(held: Dictionary) -> void:
	var parts: Parts = game.parts
	if parts == null:
		return
	for id in _lyre_hid.keys():
		var e: Array = _lyre_hid[id]
		var h := _lyre_handle(id)
		var same := not h.is_empty() and is_same(h[0], e[0][0]) and int(h[1]) == int(e[0][1])
		if held.has(id) and same:
			continue
		if same:
			parts.restore(e[1])             # постройку снесли или показали заново — её новую лиру не трогаем
		_lyre_hid.erase(id)
	for id in held:
		var h := _lyre_handle(id)
		if not h.is_empty() and not parts.is_hidden(h):
			_lyre_hid[id] = [h, parts.hide_handles([h])]


## Ручка лиры на скамье музыкантов id ([] — нет: постройку ещё не показали или уже снесли)
func _lyre_handle(id: int) -> Array:
	var vis: Dictionary = game.visuals.get(id, {})
	for h: Array in vis.get("h", []):
		if String((h[0] as Dictionary)["key"]).begins_with("SM_Prop_Lyre_01|"):
			return h
	return []


## Кого рисовать: людей больше, чем MAX_VIS, — рисуем тех, кто в кадре, ближних к камере первыми;
## кто вне кадра — убираем, чтобы освободить место (вошедшие в кадр проявляются плавно)
func _vis_tick() -> void:
	var rig = game.rig
	if rig == null or rig.cam == null:
		return
	var cam: Camera3D = rig.cam
	var cp := cam.global_position
	if visible_count > max_vis:
		_vis_trim(cam)
		return
	var want := []
	var drop := []
	var fr: Dictionary = by_id.get(focus_rid, {})
	if not fr.is_empty() and fr["node"] == null and _drawable(fr):
		_show(fr)                            # выбранного — всегда (вышел из дома — сразу на виду)
	if not hero_r.is_empty() and hero_r["node"] == null and _drawable(hero_r):
		_show(hero_r)                        # и героя (он в счёт жителей и MAX_VIS не входит)
	for r in residents:
		var st: String = r["state"]
		if not (st in ["walk", "idle", "work"]) or (st == "idle" and r["act"] == "inside") or (st == "work" and int(r["slot"]) < 0):
			continue
		var p: Vector2 = r["p"]
		var p3 := Vector3(p.x, land.height_at(p.x, p.y) + 0.5, p.y)
		var seen := cam.is_position_in_frustum(p3)
		if r["node"] == null:
			if seen:
				want.append([p3.distance_squared_to(cp), r])
		elif not seen and int(r["id"]) != focus_rid:
			drop.append([p3.distance_squared_to(cp), r])
	if want.is_empty():
		return
	want.sort_custom(func(a, b): return a[0] < b[0])
	drop.sort_custom(func(a, b): return a[0] > b[0])
	var made := 0
	for w in want:
		if made >= 24:
			break                        # не всех разом — без рывка кадра при повороте камеры
		if visible_count >= max_vis:
			if drop.is_empty():
				break
			_hide(drop.pop_front()[1])
		_show(w[1])
		made += 1


## Графику облегчили (людей на улицах меньше): лишних убрать — сначала вне кадра, потом дальних
func _vis_trim(cam: Camera3D) -> void:
	var cp := cam.global_position
	var shown := []
	for r in residents:
		var st: String = r["state"]
		if r["node"] == null or not (st in ["walk", "idle", "work"]) or int(r["id"]) == focus_rid:
			continue
		var p: Vector2 = r["p"]
		var p3 := Vector3(p.x, land.height_at(p.x, p.y) + 0.5, p.y)
		shown.append([p3.distance_squared_to(cp) + (0.0 if cam.is_position_in_frustum(p3) else 1.0e9), r])
	shown.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(visible_count - max_vis, shown.size()):
		_hide(shown[i][1])


## Житель попал в кадр: создать его и поставить в нужной позе (идёт, сидит, говорит, стоит за прилавком)
func _show(r: Dictionary) -> void:
	var c := _node(r)
	if c == null:
		return
	r["fade"] = 0.0
	c.set_alpha(0.0)
	match r["state"]:
		"walk":
			c.play("Walk_Loop", 0.0, rng.randf())
		"work":
			var b: Dictionary = city.buildings.get(r["job"], {})
			if b.is_empty():
				return
			var bp := city.blueprint(b)
			if int(r["slot"]) >= bp.actors.size():
				return
			var a: Array = bp.actors[r["slot"]]
			var xf: Transform3D = city.xf(b) * Transform3D(Basis(Vector3.UP, float(a[1])), a[0])
			if (a[0] as Vector3).y < 0.05:
				xf.origin.y = land.height_at(xf.origin.x, xf.origin.z)
			c.transform = xf
			c.scale = Vector3.ONE * Citizen.SIZE * (0.68 if r["child"] else 1.0)
			var sa: String = "Idle" if String(a[2]).begins_with("Idle_Talking") else String(a[2])   # не говорит «в воздух»
			r["slot_base"] = sa
			if HandProps.held(c) != "":
				sa = HandProps.work_clip(b["type"], int(r["slot"]), sa)     # лира уже в руках — играет на ней
			c.play(sa, 0.0, rng.randf())
			r["slot_anim"] = sa
			r["slot_yaw"] = c.rotation.y
			r["slot_front"] = absf(wrapf(float(a[1]), -PI, PI)) < 0.8
			r["face"] = c.rotation.y
			r["serve"] = 0
		"idle":
			var nm := "Idle"
			if r["act"] == "sit" and _sitting(r):
				nm = "Sitting_Idle"
				r["yoff"] = r["yoff_to"]
			elif r["act"] == "talk":
				nm = "Listen"
			elif r["act"] == "play" and (r.get("pk", "") == "chase" or r.get("run_to", Vector2.INF) != Vector2.INF):
				nm = "Jog_Fwd"
			else:
				var s: Array = r["seq"]
				var i := int(r["si"])
				if i >= 0 and i < s.size() and not (str(s[i][0]) in ["", "SIT", "Sitting_Enter", "Sitting_Exit"]):
					nm = s[i][0]
			r["yaw"] = r["face"]
			_place(r)
			c.play(nm, 0.0, rng.randf())


func _step(r: Dictionary, dt: float) -> void:
	var path: PackedVector2Array = r["path"]
	var i: int = r["i"]
	if i >= path.size():
		_arrive(r)
		return
	var c: Citizen = r["node"]
	if c == null and visible_count < max_vis and (r["p"] as Vector2).distance_to(path[path.size() - 1]) > 3.0:
		c = _node(r)
		if c:
			c.play("Walk_Loop")
			r["fade"] = 0.0             # место на улице освободилось — проявляется, а не выскакивает
			c.set_alpha(0.0)
	var p: Vector2 = r["p"]
	var sf := 1.0
	if land.up_n > 0:
		var pc := land.cell(p)
		if land.is_up(land.idx(pc.x, pc.y)):
			sf = Defs.STREET_WALK                # по каменным плитам ходят быстрее (этап 5.7) — и шагают чаще: ноги не скользят
	if c:
		c.anim.speed_scale = game.speed * float(r["speed"]) * sf
		if float(r["fade"]) < 1.0:
			# получил узел в свою очередь — dt за 8 кадров; проявляется всё равно по кадру, а не выскакивает
			r["fade"] = minf(1.0, float(r["fade"]) + minf(dt, _frame_sdt) / 0.6)
			c.set_alpha(float(r["fade"]))
	var to := path[i] - p
	var dist := to.length()
	var mv := WALK * float(r["speed"]) * sf * dt
	while dist <= mv and i < path.size() - 1:
		p = path[i]
		mv -= dist
		i += 1
		to = path[i] - p
		dist = to.length()
	r["i"] = i
	if dist <= mv:
		r["p"] = path[path.size() - 1]
		r["i"] = path.size()
		_arrive(r)
		return
	var dir := to / dist
	r["p"] = p + dir * mv
	r["yaw"] = lerp_angle(float(r["yaw"]), atan2(dir.x, dir.y), minf(1.0, dt * 8.0))
	_place(r)


func _float_text(p: Vector2, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = game.hud.font_bold if game.hud else null
	l.font_size = 44
	l.outline_size = 12
	l.modulate = Color("ffe08a")
	l.outline_modulate = Color("5a3a1a")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.pixel_size = 0.008
	var y := land.height_at(p.x, p.y)
	l.position = Vector3(p.x, y + 2.6, p.y)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", y + 4.2, 2.6)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 2.6).set_delay(0.8)
	tw.tween_callback(l.queue_free)


# ---------- события города ----------

func _on_rehomed(old: int, new: int) -> void:
	var h: Dictionary = city.buildings.get(new, {})
	if not hero_r.is_empty() and int(hero_r["home"]) == old:
		hero_r["home"] = new                 # Казармы героя перенесли
		if hero_r["state"] == "home":
			hero_r["p"] = city.door_point(h)
	for r in residents:
		if int(r["home"]) == old:
			if r["state"] == "door" and str((r["door"] as Dictionary).get("then", "")) == "home":
				_hide(r)                     # входил в дом, который переносят — уже внутри
				r["door"] = {}
				r["state"] = "home"
			r["home"] = new
			if city.pending.has(r["fam"]) and r["state"] != "walk":
				if r["state"] == "home":
					r["p"] = city.door_point(h)
				_go(r, city.door_point(h), "settle")
			elif r["state"] == "home":
				r["p"] = city.door_point(h)
			elif r["state"] == "walk" and r["goal"] in ["home", "settle"]:
				_go(r, city.door_point(h), r["goal"])
	# кошки дома — за ним (и в записи)
	for c in cats:
		if int(c.get("home", -1)) == old:
			c["home"] = new
			for k: String in ["rec", "pet_rec"]:
				if c.has(k):
					(c[k] as Dictionary)["home"] = new
	_jobs_dirty = true


## Постройку поставили (в том числе на площадь, прямо на мостовую): кто стоит на её месте — отходит на
## свободную мостовую, кто шёл сквозь неё — обходит, кошки тоже
func _on_building_added(b: Dictionary) -> void:
	if land == null:
		return
	if not hero_r.is_empty() and String(b.get("type", "")) == "barracks":
		_hero_to_barracks()
	var cells: PackedInt32Array = b.get("cells", PackedInt32Array())
	refresh_cells(cells)
	if city.bulk or cells.is_empty():
		return
	var id := int(b["id"])
	for r in residents:
		_bump_out(r, id)
	if not hero_r.is_empty():
		var keep := rng
		rng = hero_rng                  # _go → _arrive → _begin берут случайности: у героя свои, горожане ходят как раньше
		_bump_out(hero_r, id)
		rng = keep
	for c in cats:
		if land.occ_at(c["p"]) == id:
			var q := _near_free(c["p"], 80)
			if q != Vector2.INF:
				c["p"] = q
		if c["state"] == "walk" and _path_hits(c["p"], c["path"], int(c["i"]), id):
			c["state"] = "sit"           # через миг пойдёт снова — уже в обход
			c["t"] = 0.5


## Стоит на месте новой постройки — отходит на свободную мостовую; шёл сквозь неё — обходит
func _bump_out(r: Dictionary, id: int) -> void:
	if r["state"] in ["home", "work", "door"] or r["act"] == "inside":
		return                          # дома, на работе, в дверях — их не видно на улице
	if land.occ_at(r["p"]) == id:
		var q := _near_free(r["p"], 80)          # до ~20 м — выйти и из-под большого храма
		if q != Vector2.INF:
			r["p"] = q
			_place(r)
	if r["state"] == "walk":
		var path: PackedVector2Array = r["path"]
		if path.size() >= 2 and _path_hits(r["p"], path, int(r["i"]), id):
			var to: Vector2 = path[path.size() - 1]
			if land.occ_at(to) == id:            # шёл как раз туда, где теперь стоит постройка, — к ближнему свободному месту
				to = _near_free(to, 80)
			if to != Vector2.INF:
				_go(r, to, r["goal"], true)


## Поставили Казармы: герой ночевал на почтовой станции — теперь живёт в Казармах (первых); уже в Казармах — не трогаем
## (вторые Казармы его не уводят). Спит — просто «живёт» теперь там; шёл ночевать — идёт в Казармы
func _hero_to_barracks() -> void:
	var cur: Dictionary = city.buildings.get(int(hero_r["home"]), {})
	if String(cur.get("type", "")) == "barracks" or (city.moving_id >= 0 and int(hero_r["home"]) == city.moving_id):
		return                          # его Казармы переносят — дом поменяет _on_rehomed
	var nh := hero_home()
	if nh.is_empty() or String(nh.get("type", "")) != "barracks":
		return
	hero_r["home"] = int(nh["id"])
	if hero_r["state"] == "home":
		hero_r["p"] = city.door_point(nh)
	elif hero_r["state"] == "walk" and String(hero_r["goal"]) == "home":
		var keep := rng
		rng = hero_rng
		_go(hero_r, city.door_point(nh), "home")
		rng = keep


func _on_building_removed(b: Dictionary) -> void:
	refresh_cells(b.get("cells", PackedInt32Array()))
	slots.erase(b["id"])
	_hero_lost(b)
	# кто стоял у этой лавки, сидел на скамье, был внутри — идут дальше
	for r in residents.duplicate():
		if int((r["dest"] as Dictionary).get("bid", -1)) == int(b["id"]) and r["state"] == "idle" and r["act"] != "":
			if r["act"] == "inside":
				_release(r)
				_node(r)
				_social(r)
			else:
				_release(r)
				# сидел на скамье, а её убрали — встаёт на землю сразу (иначе висел бы над мостовой на высоте сиденья)
				r["yoff"] = 0.0
				r["yoff_to"] = 0.0
				_place(r)
				_social(r)
		elif r["state"] == "door" and int((r["door"] as Dictionary).get("bid", -1)) == int(b["id"]) and int(b["id"]) != city.moving_id:
			_door_cancel(r)
			_social(r)
	spots.erase(b["id"])
	if city.def(b)["kind"] == "house" and int(b["id"]) != city.moving_id:
		# жильцы снесённого дома выходят и ждут нового жилья на площади
		var fams := {}
		for r in residents:
			if r["home"] == b["id"]:
				r["home"] = -1
				fams[r["fam"]] = true
				r["p"] = city.door_point(b) if r["state"] == "home" else r["p"]
				_go(r, _plaza_point(), "plaza")
		for f in fams:
			var rs: Array = residents.filter(func(x): return x["fam"] == f and int(x["home"]) <= 0)
			var ids: Array = rs.map(func(x): return x["id"])
			waiting_fams.append({"name": f, "members": ids})
			# «back»: семья уже жила в городе — в счёт приехавших (первые три семьи, просьба «Заселите три семьи») второй раз не идёт
			city.family_arrived({"name": f, "n": ids.size(), "cls": city.def(b)["cls"], "back": true, "m": _recs(rs)}, false)
		# кошки снесённого дома переходят к ближнему дому (этап 6.4)
		for ct in cats:
			if int(ct.get("home", -1)) == int(b["id"]):
				_cat_rehome(ct, b["pos"])
	for r in residents:
		if r["job"] == b["id"]:
			_quit_job(r)
	_jobs_dirty = true


func _on_family_left(home: int, name: String) -> void:
	var tun := Land.TUNNEL + Vector2(0, 1.0)
	for r in residents.duplicate():
		if r["fam"] == name and r["home"] == home:
			r["home"] = -2
			_quit_job(r)
			if r["state"] == "home":
				var h: Dictionary = city.buildings.get(home, {})
				r["p"] = city.door_point(h) if not h.is_empty() else r["p"]
			_go(r, tun, "leave")
			# уходят по большой дороге за край карты, к горизонту
			if r["state"] == "walk":
				var lp: PackedVector2Array = r["path"]
				lp.append(Vector2(Land.ROAD_X + rng.randf_range(-1.2, 1.2), -CART_FAR))
				r["path"] = lp


func _plaza_point() -> Vector2:
	var c := city.center()
	if c.is_empty():
		return Land.CENTER
	var base := city.door_point(c)
	for k in 20:
		var q := base + Vector2(rng.randf_range(-3.5, 3.5), rng.randf_range(-4.5, 4.5))
		if _free(q):
			return q
	return base


## Игрок выбрал семье дом: она идёт с площади к нему
func _on_assigned(name: String, home: int) -> void:
	var h: Dictionary = city.buildings.get(home, {})
	if h.is_empty():
		return
	for wf in waiting_fams.duplicate():
		if wf["name"] != name:
			continue
		waiting_fams.erase(wf)
		for id in wf["members"]:
			if not by_id.has(id):
				continue
			var r: Dictionary = by_id[id]
			r["home"] = home
			r["cls"] = h_cls(h)
			_go(r, city.door_point(h), "settle")


# ---------- повозка с переселенцами ----------

## Повозка — римская четырёхколёсная раеда из деталей Synty: кузов телеги шире и длиннее, четыре колеса
## (крутятся на ходу), по бортам красные полотнища со львами, поперёк кузова — скамьи с подушками.
## Седоки сидят лицом вперёд и видны по пояс над бортом, на облучке — возница с вожжами, сзади — поклажа.
## Повозка и лошадь — в «кукольном» масштабе построек; люди в ней — своего размера.
func _make_cart() -> void:
	var top := Node3D.new()
	var root := Node3D.new()
	root.scale = Vector3.ONE * Catalog.ARCH
	top.add_child(root)
	var body := Synty.make("SM_Prop_Cart_01")
	body.scale = Vector3(CART_SX, 1.0, CART_SZ)
	root.add_child(body)
	# колёса — отдельно от растянутого кузова (круглые), по два с каждой стороны
	var wheels := []
	for w in body.find_children("SM_Prop_Cart_01_Wheel_*", "MeshInstance3D", true, false):
		var mi := w as MeshInstance3D
		mi.get_parent().remove_child(mi)
		for z in CART_WHEEL_Z:
			var wn := mi.duplicate() as MeshInstance3D
			wn.position = Vector3(signf(mi.position.x) * CART_WHEEL_X, CART_WHEEL_R, z)
			root.add_child(wn)
			wheels.append(wn)
		mi.free()
	# скамьи с подушками: три ряда и облучок
	var benches := []
	for z in CART_ROWS:
		benches.append([float(z), CART_FLOOR + CART_HIP])
	benches.append([CART_DRIVER.z, CART_DRIVER.y + CART_HIP])
	for st in benches:
		var bz: float = float(st[0]) - CART_HIP_BACK - 0.02
		var b := Synty.make("SM_Prop_Bench_01")
		b.scale = Vector3(CART_ROW_W / 1.64, (float(st[1]) - CART_FLOOR - 0.07) / 0.47, 0.34 / 0.47)
		b.position = Vector3(0, CART_FLOOR, bz)
		root.add_child(b)
		var cu := Synty.make("SM_Prop_Pillow_05")
		cu.scale = Vector3(CART_ROW_W / 1.06, 0.6, 0.38 / 1.07)
		cu.position = Vector3(0, float(st[1]) - 0.04, bz)
		root.add_child(cu)
	# по бортам — красные полотнища со львами и амфорами
	for sx in [-1.0, 1.0]:
		var bn := Synty.make("SM_Prop_Banner_04_A")
		bn.rotation.y = PI / 2 * sx
		bn.scale = Vector3(2.3 / 4.87, 0.5 / 1.09, 0.5)
		bn.position = Vector3(0.79 * sx, 1.33, -0.08)
		root.add_child(bn)
	# поклажа сзади: амфора, мешок с корзиной, свёрнутый ковёр поперёк заднего борта
	for l in [["SM_Prop_Vase_05", Vector3(-0.45, CART_FLOOR, -1.1), 0.72, 0.3], ["SM_Prop_Sack_03", Vector3(0.42, CART_FLOOR, -1.12), 0.6, -0.4],
			["SM_Prop_Basket_06", Vector3(0.4, CART_FLOOR + 0.42, -1.1), 0.62, 0.25], ["SM_Prop_Rug_Folded_02", Vector3(-0.02, CART_FLOOR + 0.3, -1.12), 0.5, 0.1],
			["SM_Prop_Pillow_07", Vector3(0.0, 1.42, -1.2), 1.0, PI / 2]]:
		var p := Synty.make(l[0])
		p.position = l[1]
		p.scale = Vector3.ONE * float(l[2])
		p.rotation.y = float(l[3])
		root.add_child(p)
		if l[0] == "SM_Prop_Pillow_07":
			p.name = "bolster"           # убирается, когда на заднем борту сидят седоки
	# лошадь в оглоблях
	var horse := (load("res://assets/animals/Horse_b.glb") as PackedScene).instantiate() as Node3D
	root.add_child(horse)
	var aabb := Artisau.aabb(horse)
	horse.scale = Vector3.ONE * CART_HORSE_LEN / maxf(aabb.size.z, aabb.size.x)
	horse.position = Vector3(0, 0, CART_HORSE_Z)
	var hanim: AnimationPlayer = horse.find_children("*", "AnimationPlayer", true, false)[0]
	var head := BoneAttachment3D.new()
	head.bone_name = "Head"
	(horse.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D).add_child(head)
	# возница на облучке, вожжи — от его рук к голове лошади
	var driver := Citizen.create(rng, false)
	root.add_child(driver)
	driver.position = CART_DRIVER
	driver.scale = Vector3.ONE * Citizen.SIZE / Catalog.ARCH
	driver.play("Driving_Loop", 0.0)
	var hands := []
	for bn in ["LeftHand", "RightHand"]:
		var ba := BoneAttachment3D.new()
		ba.bone_name = bn
		(driver.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D).add_child(ba)
		hands.append(ba)
	var reins := []
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color("4a2e1a")
	rm.roughness = 0.9
	for k in 2:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.02, 0.02, 1.0)
		mi.mesh = bm
		mi.material_override = rm
		top.add_child(mi)
		reins.append(mi)
	add_child(top)
	top.visible = false
	cart = {"n": top, "body": root, "horse": hanim, "head": head, "hands": hands, "reins": reins, "wheels": wheels, "driver": driver,
		"path": PackedVector2Array(), "s": 0.0, "state": "wait", "t": 3.0, "load": [], "riders": [], "leaving": [], "fade": 0.0, "mult": 1.0, "show": false}


## Кто едет: у каждой семьи — её люди (мужчина, женщина, дети) того же облика, что и жители, которые сойдут на площадь.
## Садятся рядами лицом вперёд, семья к семье (взрослый занимает 0,56 ряда, ребёнок 0,4); кому ряда не хватило — рядом с возницей
func _cart_board(load: Array) -> void:
	for r: Node in cart["riders"] + cart["leaving"]:
		r.queue_free()
	cart["riders"] = []
	cart["leaving"] = []
	var root: Node3D = cart["body"]
	var rows := []
	for i in CART_ROWS.size():
		rows.append([])
	var spare := []
	var ri := 0
	var w := 0.0
	for f in load:
		var ms := []
		# седоки — те самые члены семьи (Residents): тот же облик и на повозке, и на площади, и дома
		for m: Dictionary in Residents.fit(f, Residents.key_new(city, String(f["name"])), String(f["cls"])):
			ms.append({"female": int(m["sx"]) == 1, "child": int(m["age"]) == 0, "rich": f["cls"] == "patricians", "cls": f["cls"],
				"seed": int(m["sd"]), "rec": m})
		f["members"] = ms
		for m in ms:
			var mw := 0.4 if m["child"] else 0.56
			while ri < rows.size() and w + mw > CART_ROW_W + 0.01:
				ri += 1
				w = 0.0
			if ri < rows.size():
				rows[ri].append(m)
				w += mw
			else:
				spare.append(m)
	# кому и рядом с возницей места нет — садятся на задний борт спиной к поклаже, ноги наружу (как на телегах)
	var tail := []
	if spare.size() > 1:
		w = 0.0
		for m in spare.slice(1):
			var mw := 0.4 if m["child"] else 0.56
			if w + mw > CART_ROW_W - 0.12:
				break
			tail.append(m)
			w += mw
	var seats := []                  # [кто, x, таз z, высота сиденья, лицом назад]
	for i in rows.size():
		var tw := 0.0
		for m in rows[i]:
			tw += 0.4 if m["child"] else 0.56
		var x := tw / 2.0
		for m in rows[i]:
			var mw := 0.4 if m["child"] else 0.56
			seats.append([m, x - mw / 2.0, float(CART_ROWS[i]) - CART_HIP_BACK, CART_FLOOR + CART_HIP, false])
			x -= mw
	if not spare.is_empty():
		seats.append([spare[0], -0.3, CART_DRIVER.z - CART_HIP_BACK, CART_DRIVER.y + CART_HIP, false])
	var tx := w / 2.0
	for m in tail:
		var mw := 0.4 if m["child"] else 0.56
		seats.append([m, tx - mw / 2.0, -1.3, 1.4, true])
		tx -= mw
	(root.get_node("bolster") as Node3D).visible = tail.is_empty()
	for s in seats:
		var m: Dictionary = s[0]
		var c := Citizen.build(Residents.look_of(m["rec"], String(m["cls"])), m["child"])
		root.add_child(c)
		var k := 0.68 if m["child"] else 1.0
		var back: bool = s[4]
		c.scale = Vector3.ONE * Citizen.SIZE * k / Catalog.ARCH
		c.position = Vector3(float(s[1]), float(s[3]) - CART_HIP * k, float(s[2]) + CART_HIP_BACK * k * (-1.0 if back else 1.0))
		c.rotation.y = PI if back else 0.0
		var an: Array = ["Sitting_Idle", "Sitting_Idle_M"] if m["child"] else ["Sitting_Idle", "Sitting_Idle_M", "Sitting_Talking", "Sitting_Talking_M"]
		c.play(an[rng.randi() % an.size()], 0.0, rng.randf())
		m["seat"] = c.position
		m["tail"] = back
		cart["riders"].append(c)


## Вожжи: от рук возницы к голове лошади (кости движутся — вожжи за ними)
func _cart_reins() -> void:
	var to: Vector3 = (cart["head"] as Node3D).global_position
	var side: Vector3 = (cart["n"] as Node3D).global_basis.x * 0.06
	for k in 2:
		var a: Vector3 = (cart["hands"][k] as Node3D).global_position
		var b: Vector3 = to + (side if k == 0 else -side)
		var d := b - a
		if d.length() < 0.05:
			continue
		(cart["reins"][k] as MeshInstance3D).global_transform = Transform3D(Basis.looking_at(d / d.length(), Vector3.UP) * Basis.from_scale(Vector3(1, 1, d.length())), (a + b) * 0.5)


## Где повозка на своём пути: s — сколько проехала (на обратном пути — от площади); snap — сразу развернуть по дороге
func _cart_move(c: Dictionary, dt: float, snap: bool) -> void:
	var n: Node3D = c["n"]
	var path: PackedVector2Array = c["path"]
	if path.size() < 2:
		return
	var total := _cart_path_len(path)
	var s: float = c["s"] if c["state"] != "out" else total - float(c["s"])
	var p := path[0]
	var dir := Vector2(0, 1)
	var acc := 0.0
	for i in path.size() - 1:
		var l := path[i].distance_to(path[i + 1])
		if s <= acc + l or i == path.size() - 2:
			p = path[i].lerp(path[i + 1], clampf((s - acc) / maxf(l, 0.001), 0.0, 1.0))
			dir = (path[i + 1] - path[i]).normalized()
			break
		acc += l
	if c["state"] == "out":
		dir = -dir
	n.position = Vector3(p.x, land.height_at(p.x, p.y), p.y)
	var yaw := atan2(dir.x, dir.y)
	n.rotation.y = yaw if snap else lerp_angle(n.rotation.y, yaw, minf(1.0, dt * 4.0))


## Вступительный ролик: повозка сразу на большой дороге перед аркой (а не из-за горизонта)
func cart_seek_z(z: float) -> void:
	var path: PackedVector2Array = cart["path"]
	var acc := 0.0
	for i in path.size() - 1:
		var l := path[i].distance_to(path[i + 1])
		if path[i + 1].y >= z:
			cart["s"] = acc + l * clampf((z - path[i].y) / maxf(path[i + 1].y - path[i].y, 0.001), 0.0, 1.0)
			break
		acc += l
	_cart_move(cart, 0.0, true)


func _cart_path_len(path: PackedVector2Array) -> float:
	var t := 0.0
	for i in path.size() - 1:
		t += path[i].distance_to(path[i + 1])
	return t


func _cart_step(dt: float) -> void:
	if cart.is_empty():
		return
	var c := cart
	var n: Node3D = c["n"]
	match c["state"]:
		"wait":
			c["t"] = float(c["t"]) - dt
			if float(c["t"]) > 0.0 or city.center().is_empty():
				return
			if city.incoming <= 0:
				return
			var to := _plaza_point()
			# повозка выезжает из-за горизонта: по большой дороге за краем карты, через арку — к станции
			var cp := _path(Land.TUNNEL + Vector2(0, 0.8), to)
			if cp.size() >= 2:
				cp.insert(0, Vector2(Land.ROAD_X, -CART_FAR))
			c["path"] = cp
			if c["path"].size() < 2:
				c["t"] = 4.0
				return
			# семьи собираются разом, и каждой держится место в доме — никто не приезжает «в никуда»
			c["load"] = city.make_load(city.incoming)
			city.incoming = (c["load"] as Array).size()   # влезло меньше — везёт меньше
			if city.incoming <= 0:
				return
			c["state"] = "in"
			c["s"] = 0.0
			c["mult"] = 1.0
			_cart_board(c["load"])
			n.visible = true
			# первая повозка новой игры — вступительный ролик (повозка начнёт путь у арки)
			var tut = game.get("tutorial") if game != null else null
			if tut != null and tut.intro_wanted():
				tut.intro_start(c)
			_cart_move(c, 0.0, true)
		"in", "out":
			var total := _cart_path_len(c["path"])
			# дорога длинная: пока повозку не видно на экране, она едет втрое быстрее (кто смотрит — видит обычный шаг)
			# (в ролике камера ведёт повозку сама — та всегда едет своим шагом)
			var seen: bool = bool(c["show"]) or (game.rig != null and game.rig.cam != null and game.rig.cam.is_position_in_frustum(n.position))
			var ds := CART_V * float(c["mult"]) * dt * (1.0 if seen or not n.visible else 3.0)
			c["s"] = float(c["s"]) + ds
			_cart_move(c, dt, false)
			for wh: Node3D in c["wheels"]:
				wh.rotation.x += ds / (CART_WHEEL_R * Catalog.ARCH)
			_horse_anim(c["horse"], "Walk")
			(c["horse"] as AnimationPlayer).speed_scale = maxf(0.0, float(game.speed)) * float(c["mult"])
			if float(c["s"]) >= total:
				if c["state"] == "in":
					_drop()
					c["state"] = "unload"
					c["t"] = 3.0
				else:
					n.visible = false
					c["state"] = "wait"
					c["t"] = 4.0
		"unload":
			_horse_anim(c["horse"], "Idle")
			(c["horse"] as AnimationPlayer).speed_scale = maxf(0.0, float(game.speed))
			c["t"] = float(c["t"]) - dt
			if float(c["t"]) <= 0.0:
				c["state"] = "out"
				c["s"] = 0.0
				c["mult"] = 1.0
	# сошедшие седоки тают, пока на земле проявляются те же люди
	var lv: Array = c["leaving"]
	if not lv.is_empty():
		c["fade"] = float(c["fade"]) - dt / 0.35
		for r: Citizen in lv:
			r.set_alpha(maxf(0.0, float(c["fade"])))
		if float(c["fade"]) <= 0.0:
			for r: Node in lv:
				r.queue_free()
			c["leaving"] = []
	if n.visible:
		_cart_reins()


func _horse_anim(ap: AnimationPlayer, name: String) -> void:
	for a in ap.get_animation_list():
		if a == name or a.ends_with("|" + name):
			if ap.current_animation != a:
				ap.play(a, 0.3)
			return


## Семьи сходят с повозки на площадь — те самые люди, что сидели в ней: каждый спускается на свою сторону
## у своего ряда, и все идут на площадь ждать жилья
func _drop() -> void:
	var n: Node3D = cart["n"]
	var root: Node3D = cart["body"]
	var base := Vector2(n.position.x, n.position.z)
	for f in cart["load"]:
		var ms: Array = f.get("members", [])
		f.erase("members")                       # места в повозке — не для сохранения
		var fam := _make_family(f["name"], int(f["n"]), -1, base, f["cls"], f)
		for i in fam.size():
			var r: Dictionary = fam[i]
			var q := base + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
			if i < ms.size():
				var m: Dictionary = ms[i]
				if m.has("seat"):
					var sp: Vector3 = m["seat"]
					var w := root.to_global(Vector3(sp.x, 0.0, -2.3) if m.get("tail", false) else Vector3(1.7 if sp.x >= 0.0 else -1.7, 0.0, sp.z - CART_HIP_BACK))
					q = Vector2(w.x, w.z)
			r["p"] = _near_free(q)
			if r["p"] == Vector2.INF:
				r["p"] = base
			_go(r, _plaza_point(), "plaza")
		waiting_fams.append({"name": f["name"], "members": fam.map(func(x): return x["id"])})
		city.family_arrived(f)
	cart["load"] = []
	cart["leaving"] = cart["riders"]
	cart["riders"] = []
	cart["fade"] = 1.0
	_jobs_dirty = true
	_vis_tick()                      # сошедшие сразу на виду — проявляются, пока седоки тают


# ---------- кошки ----------

## Кошка — модель Quaternius (Animal Pack Vol.2, CC0) со своими позами; нет файла (старый пакет моделей) — прежняя, из Kit.
## Кости модели: Bone — таз, .001 — грудь, .002 — шея, .003 — голова, .004–.007 — хвост; передние лапы .014–.016 и
## .017–.019 (плечо, предплечье, кисть), задние .008–.010 и .011–.013 (бедро, голень, стопа)
const CAT_FILE := "res://assets/cat/Cat.fbx"     # в пакете с кодом, не в пакете моделей: обновление — пара МБ, а не ~100
const CAT_LEN := 0.6                   # длина кошки от кончика хвоста до носа (была 0,5 — рядом с жителями терялась)
const CAT_LEN_BED := 0.5               # кошка в корзинке-украшении и в облачке — прежнего размера (корзинка под неё)
## Окрас (тем же номером, что CAT_FURS): узор (0 гладкая, 1 тигровая, 2 «во фраке», 3 пятна), цвет полосок, цвет глаз
const CAT_LOOK := [[1, Color("b05c1c"), Color("c9962c")], [1, Color("4b4844"), Color("86ad3c")], [0, Color("1e1a18"), Color("d8b23a")],
	[0, Color("e2dccf"), Color("6f9fd2")], [1, Color("6a4322"), Color("a6a63a")], [2, Color("2c2826"), Color("8fb33c")]]
const CAT_HEAD := 1.22                 # голова крупнее: милее и читается издали
const CAT_EYE := Vector3(0.0281, 0.00215, 0.0288)   # где глаз в позе покоя (ед. модели, x — вперёд, z — вверх)
const CAT_EYE_R := 0.00095
const CAT_WALK := 0.42                 # шаг кошки (прежняя, вдвое крупнее, ходит 0.9)
const CAT_STEP := 1.74                 # как быстро лапа уходит назад в «Walking» (ед. модели в секунду) — чтобы лапы не скользили
## Окрасы: шерсть и грудка
const CAT_FURS := [[Color("e0913f"), Color("f6dcb4")], [Color("7d7a76"), Color("d9d4cc")], [Color("2c2724"), Color("4a423c")],
	[Color("f2ede4"), Color("ffffff")], [Color("a87447"), Color("efe0c8")], [Color("4a4440"), Color("f2ede4")]]
## Чёрная Мася из истории «Где Мася?» (решение владельца Д15): свой окрас вне CAT_FURS — случайные кошки города его
## не получают. Шерсть чёрная, жёлтые глаза, голубоватый отлив по краю (sheen) — видно и в тени, и на мостовой
const CAT_MASYA := 6
const CAT_MASYA_FUR := [Color("1d1a19"), Color("2c2725")]
const CAT_MASYA_LOOK := [0, Color("141110"), Color("f0c232")]
const CAT_MASYA_SHEEN := 0.45
## Состояние кошки → движение и его скорость
const CAT_CLIP := {"walk": ["Walk", 1.0], "sit": ["Sit", 1.0], "sleep": ["Sleep", 0.3], "pet": ["Pet", 1.0]}

static var _cat_parts := {}
static var _cat_scene: PackedScene
static var _cat_ok := -1               # -1 — ещё не проверяли, 1 — модель годится, 0 — кошки из Kit
static var _cat_lib: AnimationLibrary
static var _cat_size := 1.0            # длина модели в файле
static var _cat_v2: ArrayMesh          # общая сетка кошки: одна поверхность, глаза, голова крупнее (_cat_build)
static var _cat_shader: Shader


## Модель кошки на месте и годится: скелет, «Idle» и «Walking». Заодно один раз собираются её движения
static func _cat_model_ok() -> bool:
	if _cat_ok >= 0:
		return _cat_ok == 1
	_cat_ok = 0
	if not ResourceLoader.exists(CAT_FILE):
		return false
	_cat_scene = load(CAT_FILE) as PackedScene
	if _cat_scene == null:
		return false
	var root := Node3D.new()
	var m := _cat_scene.instantiate() as Node3D
	root.add_child(m)
	var aps := m.find_children("*", "AnimationPlayer", true, false)
	var sks := m.find_children("*", "Skeleton3D", true, false)
	if not aps.is_empty() and not sks.is_empty() and LegionFighter._find(aps[0], ["Idle"]) != "" \
			and LegionFighter._find(aps[0], ["Walking", "Walk"]) != "":
		var box := Artisau.aabb(m)
		_cat_size = maxf(0.01, maxf(box.size.x, box.size.z))
		_cat_lib = _cat_clips(aps[0], sks[0])
		_cat_ok = 1
	root.free()
	print("Кошки: ", "модель Quaternius" if _cat_ok == 1 else "запасные (модели нет)")
	return _cat_ok == 1


## Движения кошки, общие на всех: «Idle» и «Walk» из файла (по кругу) и свои позы поверх «Idle» (дыхание, хвост):
## «Sit» — сидит, «Pet» — сидит, подняв голову к человеку, хвост ходит, «Sleep» — спит клубком
static func _cat_clips(ap: AnimationPlayer, sk: Skeleton3D) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	var idle := ap.get_animation(LegionFighter._find(ap, ["Idle"])).duplicate(true) as Animation
	var walk := ap.get_animation(LegionFighter._find(ap, ["Walking", "Walk"])).duplicate(true) as Animation
	idle.loop_mode = Animation.LOOP_LINEAR
	walk.loop_mode = Animation.LOOP_LINEAR
	lib.add_animation("Idle", idle)
	lib.add_animation("Walk", walk)
	var L := idle.length * 2.0
	# сидит: таз ниже и откинут назад, передние лапы прямо, задние сложены, хвост лежит позади
	var sit := {"Bone": Vector3(0, -0.52, 0), "Bone.002": Vector3(0, 0.2, 0), "Bone.003": Vector3(0, 0.3, 0),
		"Bone.014": Vector3(0, 0.52, 0), "Bone.017": Vector3(0, 0.52, 0),
		"Bone.008": Vector3(0, -1.14, 0), "Bone.011": Vector3(0, -1.14, 0), "Bone.009": Vector3(0, 2.43, 0), "Bone.012": Vector3(0, 2.43, 0),
		"Bone.010": Vector3(0, -0.77, 0), "Bone.013": Vector3(0, -0.77, 0),
		"Bone.004": Vector3(0, -1.68, 0), "Bone.005": Vector3(0, 0.53, 0.45), "Bone.006": Vector3(0, 0.36, 0.6),
		"Bone.007": func(t: float) -> Vector3: return Vector3(0, -0.2, 0.5 + 0.35 * sin(TAU * 2.0 * t / L))}
	# сидит мягче: хвост обвивает бок и кончиком подрагивает, голова чуть набок
	var sit_soft := sit.duplicate()
	sit_soft["Bone.003"] = Vector3(0.14, 0.3, 0.08)
	lib.add_animation("Sit", _cat_pose(idle, 2, sk, sit_soft, Vector3(0, 0, -1.29)))
	# гладят: голова поднята к человеку, хвост ходит из стороны в сторону
	var pet := sit.duplicate()
	pet["Bone.003"] = Vector3(0, 0.0, 0)
	pet["Bone.006"] = func(t: float) -> Vector3: return Vector3(0, 0.36, sin(TAU * 4.0 * t / L) * 0.4)
	pet["Bone.007"] = func(t: float) -> Vector3: return Vector3(0, -0.27, sin(TAU * 4.0 * t / L - 0.8) * 0.5)
	lib.add_animation("Pet", _cat_pose(idle, 2, sk, pet, Vector3(0, 0, -1.29)))
	# спит клубком на животе: передние лапы вперёд по земле, задние поджаты, голова лежит, повёрнута к боку,
	# хвост лёг на землю и обвил бок
	var sleep := {"Bone.001": Vector3(0, 0, -0.2), "Bone.002": Vector3(0, 0.25, -0.9), "Bone.003": Vector3(0, 0.3, -0.4),
		"Bone.014": Vector3(0, 1.24, 0), "Bone.017": Vector3(0, 1.24, 0), "Bone.015": Vector3(0, -2.85, 0), "Bone.018": Vector3(0, -2.85, 0),
		"Bone.016": Vector3(0, 1.7, 0), "Bone.019": Vector3(0, 1.7, 0),
		"Bone.008": Vector3(0, -1.41, 0), "Bone.011": Vector3(0, -1.41, 0), "Bone.009": Vector3(0, 2.41, 0), "Bone.012": Vector3(0, 2.41, 0),
		"Bone.010": Vector3(0, -1.0, 0), "Bone.013": Vector3(0, -1.0, 0),
		"Bone.004": Vector3(0, -2.55, 0), "Bone.005": Vector3(0, 0.27, 0), "Bone.006": Vector3(0, 0.8, 1.3), "Bone.007": Vector3(0, -0.25, 0.9)}
	lib.add_animation("Sleep", _cat_pose(idle, 2, sk, sleep, Vector3(0, 0, -1.15)))
	return lib


## Поза поверх src (повторяется reps раз): pose — кость → поворот в осях скелета (x — вперёд, y — вбок, z — вверх):
## Vector3 углов — сначала кивок y (носом вниз), потом крен x, потом поворот z (влево) — или Callable(t) → такие углы.
## Кость поворачивается вместе с родителем, а потом ещё на свой угол. lift — сдвиг таза (в единицах модели:
## скелет в файле в 100 раз мельче)
static func _cat_pose(src: Animation, reps: int, sk: Skeleton3D, pose: Dictionary, lift: Vector3) -> Animation:
	var a := Animation.new()
	var L := src.length * reps
	a.length = L
	a.loop_mode = Animation.LOOP_LINEAR
	var n := int(L * 15.0)
	var node := ""
	var done := {}
	for t in src.get_track_count():
		var path := src.track_get_path(t)
		node = String(path).get_slice(":", 0)
		var bone := String(path).get_slice(":", 1)
		var ty := src.track_get_type(t)
		var nt := a.add_track(ty)
		a.track_set_path(nt, path)
		a.track_set_interpolation_type(nt, src.track_get_interpolation_type(t))
		var bi := sk.find_bone(bone)
		if ty == Animation.TYPE_ROTATION_3D and pose.has(bone) and bi >= 0:
			done[bone] = true
			for i in n + 1:
				var tt := L * i / n
				a.rotation_track_insert_key(nt, tt, _cat_off(sk, bi, pose, tt) * src.rotation_track_interpolate(t, fmod(tt, src.length)))
			continue
		var up := lift * 0.01 if ty == Animation.TYPE_POSITION_3D and bone == "Bone" else Vector3.ZERO
		for r in reps:
			for k in src.track_get_key_count(t):
				var v = src.track_get_key_value(t, k)
				a.track_insert_key(nt, src.track_get_key_time(t, k) + r * src.length, v + up if ty == Animation.TYPE_POSITION_3D else v)
	# кости без своей дорожки в src — от покоя
	for bone: String in pose:
		var bi := sk.find_bone(bone)
		if done.has(bone) or bi < 0:
			continue
		var nt := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(nt, NodePath(node + ":" + bone))
		for i in n + 1:
			var tt := L * i / n
			a.rotation_track_insert_key(nt, tt, _cat_off(sk, bi, pose, tt) * sk.get_bone_rest(bi).basis.get_rotation_quaternion())
	return a


## Свой поворот кости из позы (в осях скелета)
static func _cat_rot(spec: Variant, t: float) -> Quaternion:
	var e: Vector3 = (spec as Callable).call(t) if spec is Callable else spec
	return Basis.from_euler(e, EULER_ORDER_ZXY).get_rotation_quaternion()


## Поворот кости в позе вместе со всеми родителями (в осях скелета)
static func _cat_turn(sk: Skeleton3D, bi: int, pose: Dictionary, t: float) -> Quaternion:
	var q := Quaternion.IDENTITY
	while bi >= 0:
		var nm := sk.get_bone_name(bi)
		if pose.has(nm):
			q = q * _cat_rot(pose[nm], t)
		bi = sk.get_bone_parent(bi)
	return q


## Свой поворот кости → добавка к её повороту в движении (через родителя — в покое и уже повёрнутого позой)
static func _cat_off(sk: Skeleton3D, bi: int, pose: Dictionary, t: float) -> Quaternion:
	var r := _cat_rot(pose[sk.get_bone_name(bi)], t)
	var p := sk.get_bone_parent(bi)
	if p < 0:
		return r
	var g := _cat_turn(sk, p, pose, t) * sk.get_bone_global_rest(p).basis.get_rotation_quaternion()
	return g.inverse() * r * g


## Общая сетка кошки из модели: три поверхности (шерсть, грудка и лапки, уши и нос) — в одну (одна отрисовка вместо
## трёх), голова в CAT_HEAD раз крупнее (вершины головы — от её кости), два глаза (полусферы на кости головы).
## В вершинах: COLOR.r — часть тела, UV/UV2 — место в позе покоя (по нему окрас шейдера cat_fur), у глаза — его координаты
static func _cat_build(mi: MeshInstance3D, sk: Skeleton3D) -> ArrayMesh:
	if _cat_v2:
		return _cat_v2
	var src: ArrayMesh = mi.mesh
	var hb := -1
	for i in mi.skin.get_bind_count():
		if mi.skin.get_bind_name(i) == "Bone.003":
			hb = i
	var o := sk.get_bone_global_rest(sk.find_bone("Bone.003")).origin
	var eight := (src.surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) != 0
	var nb := 8 if eight else 4
	var V := PackedVector3Array()
	var Nn := PackedVector3Array()
	var B := PackedInt32Array()
	var W := PackedFloat32Array()
	var C := PackedColorArray()
	var U := PackedVector2Array()
	var U2 := PackedVector2Array()
	var I := PackedInt32Array()
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		var mn: String = src.surface_get_material(s).resource_name if src.surface_get_material(s) else ""
		var part := 0.25 if mn == "White" else (0.5 if mn == "Pink" else 0.0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var bo: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var we: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var base := V.size()
		for i in v.size():
			var wh := 0.0
			for k in nb:
				if bo[i * nb + k] == hb:
					wh += we[i * nb + k]
			var p := o + (v[i] - o) * lerpf(1.0, CAT_HEAD, wh)
			V.append(p)
			Nn.append(n[i])
			C.append(Color(part, 0, 0, 1))
			U.append(Vector2(v[i].x, v[i].z))
			U2.append(Vector2(v[i].y, 0))
		B.append_array(bo)
		W.append_array(we)
		for k in ix:
			I.append(k + base)
	# глаза: сплюснутые полусферы на морде (точка — где луч из головы выходит наружу), смотрят вперёд, чуть в стороны
	# и вверх, чуть утоплены
	var head_tris := []
	for t in range(0, I.size(), 3):
		var a := V[I[t]]
		if a.x > o.x - 0.001 and a.z > o.z - 0.006:
			head_tris.append([a, V[I[t + 1]], V[I[t + 2]]])
	for sgn: float in [-1.0, 1.0]:
		var e0 := Vector3(CAT_EYE.x, CAT_EYE.y * sgn, CAT_EYE.z)
		var r := CAT_EYE_R * CAT_HEAD
		var f := Vector3(1.0, 0.55 * sgn, 0.3).normalized()
		var from := o + Vector3(0.007, CAT_EYE.y * sgn * 0.5, (CAT_EYE.z - o.z) * CAT_HEAD)     # изнутри головы
		var c := o + (e0 - o) * CAT_HEAD
		var best := INF
		for tr: Array in head_tris:
			var hit = Geometry3D.ray_intersects_triangle(from, f, tr[0], tr[1], tr[2])
			if hit != null and from.distance_to(hit) < best:
				best = from.distance_to(hit)
				c = hit
		var side := f.cross(Vector3(0, 0, 1)).normalized()
		var up := side.cross(f).normalized()
		c -= f * r * 0.35
		var rings := 4
		var segs := 10
		var base := V.size()
		for ri in rings + 1:
			var th := PI * 0.5 * ri / rings
			for j in segs:
				var ph := TAU * j / segs
				var d := side * cos(ph) + up * sin(ph)
				V.append(c + f * (r * cos(th) * 0.6) + d * (r * sin(th)))
				Nn.append((f * cos(th) + d * sin(th)).normalized())
				C.append(Color(0.75, 0, 0, 1))
				U.append(Vector2(cos(ph) * sin(th), sin(ph) * sin(th)))
				U2.append(Vector2(e0.y, 0))
				for k in nb:
					B.append(hb if k == 0 else 0)
					W.append(1.0 if k == 0 else 0.0)
				if ri == 0:
					break                    # полюс — одна вершина
		for ri in rings:
			for j in segs:
				var j2 := (j + 1) % segs
				var a0 := base if ri == 0 else base + 1 + (ri - 1) * segs + j
				var a1 := base if ri == 0 else base + 1 + (ri - 1) * segs + j2
				var b0 := base + 1 + ri * segs + j
				var b1 := base + 1 + ri * segs + j2
				var tri3 := [[a0, b1, b0]] if ri == 0 else [[a0, a1, b1], [a0, b1, b0]]
				for q: Array in tri3:
					# лицевая сторона в Godot — по часовой: векторное произведение в буфере смотрит внутрь глаза
					var nrm := (V[q[1]] - V[q[0]]).cross(V[q[2]] - V[q[0]])
					if nrm.dot((V[q[0]] + V[q[1]] + V[q[2]]) / 3.0 - c) > 0.0:
						I.append_array([q[0], q[2], q[1]])
					else:
						I.append_array(q)
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = V
	out[Mesh.ARRAY_NORMAL] = Nn
	out[Mesh.ARRAY_COLOR] = C
	out[Mesh.ARRAY_TEX_UV] = U
	out[Mesh.ARRAY_TEX_UV2] = U2
	out[Mesh.ARRAY_BONES] = B
	out[Mesh.ARRAY_WEIGHTS] = W
	out[Mesh.ARRAY_INDEX] = I
	_cat_v2 = ArrayMesh.new()
	_cat_v2.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out, [], {}, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if eight else 0)
	return _cat_v2


## Одеть модель кошки окрасом fi: общая сетка и свой материал (у каждой кошки — свои моргание и сон). Материал — в meta «fur_mat»
static func _cat_dress(m: Node3D, fi: int) -> ShaderMaterial:
	var mi: MeshInstance3D = m.find_children("*", "MeshInstance3D", true, false)[0]
	var sk: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
	mi.mesh = _cat_build(mi, sk)
	for s in mi.get_surface_override_material_count():
		mi.set_surface_override_material(s, null)
	if _cat_shader == null:
		_cat_shader = load("res://shaders/cat_fur.gdshader")
	var f: Array = cat_fur(fi)
	var lk: Array = CAT_MASYA_LOOK if fi == CAT_MASYA else CAT_LOOK[clampi(fi, 0, CAT_LOOK.size() - 1)]
	var mat := ShaderMaterial.new()
	mat.shader = _cat_shader
	mat.set_shader_parameter("fur", f[0])
	mat.set_shader_parameter("belly", f[1])
	mat.set_shader_parameter("pattern", int(lk[0]))
	mat.set_shader_parameter("mark", lk[1])
	mat.set_shader_parameter("eye_col", lk[2])
	mat.set_shader_parameter("blink_ph", float(m.get_instance_id() % 997) / 997.0)
	if fi == CAT_MASYA:
		mat.set_shader_parameter("sheen", CAT_MASYA_SHEEN)
	mi.material_override = mat
	m.set_meta("fur_mat", mat)
	return mat


## Окрас fi: [шерсть, грудка] (Мася — свой, остальные — CAT_FURS)
static func cat_fur(fi: int) -> Array:
	return CAT_MASYA_FUR if fi == CAT_MASYA else CAT_FURS[clampi(fi, 0, CAT_FURS.size() - 1)]


## Номер окраса кошки (для портрета в карточке: cat_node(cat_fi(c), …)): из «fi», у кошки без него — по цвету шерсти
## (чёрная Мася — вне CAT_FURS, её цвет проверяем отдельно)
static func cat_fi(ct: Dictionary) -> int:
	if ct.has("fi"):
		return int(ct["fi"])
	var col: Color = ct.get("fur", Color.BLACK)
	if (CAT_MASYA_FUR[0] as Color).is_equal_approx(col):
		return CAT_MASYA
	for i in CAT_FURS.size():
		if (CAT_FURS[i][0] as Color).is_equal_approx(col):
			return i
	return 0


static func _cat_mesh(fur: Color, belly: Color) -> Array:
	var key := fur.to_html() + belly.to_html()
	if _cat_parts.has(key):
		return _cat_parts[key]
	var body := Kit.new()
	body.blob(Vector3(0, 0.17, 0), Vector3(0.14, 0.13, 0.32), fur, 3, 0.06)
	body.blob(Vector3(0, 0.13, 0.03), Vector3(0.11, 0.08, 0.22), belly, 4, 0.05)
	var head := Kit.new()
	head.blob(Vector3(0, 0, 0), Vector3(0.12, 0.11, 0.11), fur, 5, 0.05)
	head.blob(Vector3(0, -0.02, 0.05), Vector3(0.07, 0.05, 0.05), belly, 6, 0.04)
	head.cone(Vector3(-0.04, 0.04, -0.005), 0.025, 0.05, 4, fur)
	head.cone(Vector3(0.04, 0.04, -0.005), 0.025, 0.05, 4, fur)
	head.boxc(Vector3(-0.025, 0.012, 0.055), Vector3(0.018, 0.015, 0.01), Color("2c3a1c"))
	head.boxc(Vector3(0.025, 0.012, 0.055), Vector3(0.018, 0.015, 0.01), Color("2c3a1c"))
	head.boxc(Vector3(0, -0.012, 0.062), Vector3(0.014, 0.01, 0.008), Color("d98a8a"))
	var tail := Kit.new()
	tail.rod(Vector3(0, 0, 0), Vector3(0, 0.1, -0.2), 0.022, 5, fur)
	tail.rod(Vector3(0, 0.1, -0.2), Vector3(0, 0.22, -0.24), 0.02, 5, fur)
	var leg := Kit.new()
	leg.rod(Vector3(0, 0, 0), Vector3(0, -0.11, 0), 0.022, 5, fur)
	var out := [body.mesh(), head.mesh(), tail.mesh(), leg.mesh()]
	_cat_parts[key] = out
	return out


## Новая кошка у дома (rng — в том же порядке, что у прежней: витрина и меню расставляются как раньше).
## opts — кошка истории горожан: fur (номер окраса), p (где), rng (свой поток: общий rng жителей не сдвигается)
func _make_cat(home: Dictionary, opts := {}) -> Dictionary:
	if not _cat_model_ok():
		return _make_cat_kit(home, opts)
	var rg: RandomNumberGenerator = opts.get("rng", rng)
	var fi: int = int(opts["fur"]) if opts.has("fur") else rg.randi() % CAT_FURS.size()
	var f: Array = cat_fur(fi)
	var root := Node3D.new()
	var m := _cat_scene.instantiate() as Node3D
	m.rotation.y = -PI / 2                 # в файле кошка смотрит вдоль +x, у нас — вдоль +z
	var sc := CAT_LEN / _cat_size * rg.randf_range(0.88, 1.05)
	m.scale = Vector3.ONE * sc
	root.add_child(m)
	# окрас: шерсть с узором, грудка и лапки, розовые уши и нос, глаза (cat_fur.gdshader)
	var fmat := _cat_dress(m, fi)
	var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
	ap.add_animation_library("cat", _cat_lib)
	add_child(root)
	var p: Vector2 = opts["p"] if opts.has("p") else _near_free(city.door_point(home))
	if p == Vector2.INF:
		p = city.door_point(home)
	var snd := AudioStreamPlayer3D.new()
	snd.max_distance = 30.0
	snd.unit_size = 4.0
	snd.volume_db = -14.0
	snd.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	root.add_child(snd)
	var cat := {"n": root, "anim": ap, "clip": "", "fur": f[0], "fi": fi, "mat": fmat, "k": CAT_WALK / (CAT_STEP * sc), "p": p, "path": PackedVector2Array(), "i": 0,
		"state": "sit", "t": rg.randf_range(2, 6), "home": home["id"], "yaw": rg.randf() * TAU, "walk": 0.0, "ph": rg.randf() * TAU,
		"snd": snd, "meow_t": rg.randf_range(10, 60)}
	_cat_place(cat)
	_cat_anim(cat)
	ap.seek(float(cat["ph"]) / TAU * ap.current_animation_length, true)     # кошки дышат и машут хвостом не в лад
	return cat


## Прежняя кошка, собранная из Kit (если модели нет)
func _make_cat_kit(home: Dictionary, opts := {}) -> Dictionary:
	var rg: RandomNumberGenerator = opts.get("rng", rng)
	var fi: int = int(opts["fur"]) if opts.has("fur") else rg.randi() % CAT_FURS.size()
	var f: Array = cat_fur(fi)
	var meshes := _cat_mesh(f[0], f[1])
	var mat := Kit.material(0.9)
	var root := Node3D.new()
	var mk := func(m: Mesh, pos: Vector3) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = mat
		mi.position = pos
		root.add_child(mi)
		return mi
	mk.call(meshes[0], Vector3.ZERO)
	var head: MeshInstance3D = mk.call(meshes[1], Vector3(0, 0.28, 0.3))
	var tail: MeshInstance3D = mk.call(meshes[2], Vector3(0, 0.22, -0.3))
	var legs := []
	for lp: Vector3 in [Vector3(-0.07, 0.12, 0.2), Vector3(0.07, 0.12, 0.2), Vector3(-0.07, 0.12, -0.2), Vector3(0.07, 0.12, -0.2)]:
		legs.append(mk.call(meshes[3], lp))
	var s := rg.randf_range(0.85, 1.05)
	root.scale = Vector3.ONE * s
	add_child(root)
	var p: Vector2 = opts["p"] if opts.has("p") else _near_free(city.door_point(home))
	if p == Vector2.INF:
		p = city.door_point(home)
	var snd := AudioStreamPlayer3D.new()
	snd.max_distance = 30.0
	snd.unit_size = 4.0
	snd.volume_db = -14.0
	snd.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	root.add_child(snd)
	var cat := {"n": root, "head": head, "tail": tail, "legs": legs, "fur": f[0], "fi": fi, "p": p, "path": PackedVector2Array(), "i": 0, "state": "sit", "t": rg.randf_range(2, 6),
		"home": home["id"], "yaw": rg.randf() * TAU, "walk": 0.0, "ph": rg.randf() * TAU, "snd": snd, "meow_t": rg.randf_range(10, 60)}
	_cat_place(cat)
	return cat


func _cat_place(c: Dictionary) -> void:
	var n: Node3D = c["n"]
	var p: Vector2 = c["p"]
	n.position = Vector3(p.x, land.height_at(p.x, p.y), p.y)
	n.rotation.y = float(c["yaw"])


## Модель кошки: движение по состоянию (сменилось — плавный переход), скорость — как у игры
func _cat_anim(c: Dictionary) -> void:
	var ap: AnimationPlayer = c["anim"]
	var cl: Array = CAT_CLIP.get(c["state"], CAT_CLIP["sit"])
	if c["clip"] != cl[0]:
		ap.play("cat/" + String(cl[0]), 0.0 if c["clip"] == "" else 0.35)
		c["clip"] = cl[0]
		if c.has("mat"):
			(c["mat"] as ShaderMaterial).set_shader_parameter("sleep", 1.0 if cl[0] == "Sleep" else 0.0)   # спит — глаза закрыты
	ap.speed_scale = game.speed * (float(c["k"]) if cl[0] == "Walk" else float(cl[1]))


## Прежняя кошка: лапы, хвост, голова — кодом
func _cat_kit_anim(c: Dictionary, dt: float, t: float) -> void:
	var n: Node3D = c["n"]
	var w: float = c["walk"]
	var ph: float = c["ph"] + t * 9.0
	var legs: Array = c["legs"]
	for k in 4:
		(legs[k] as Node3D).rotation.x = sin(ph + (PI if k % 3 == 0 else 0.0)) * 0.6 * w
	# гладят — хвост ходит быстрее и шире, голова поднята к человеку
	var petted: bool = c["state"] == "pet"
	(c["tail"] as Node3D).rotation.y = sin(t * (5.5 if petted else 2.2) + float(c["ph"])) * (0.6 if petted else 0.35)
	(c["head"] as Node3D).rotation.x = lerpf((c["head"] as Node3D).rotation.x, -0.35 if petted else 0.0, minf(1.0, dt * 3.0))
	var body_y := 0.0
	if c["state"] == "sit" or petted:
		body_y = -0.04
	elif c["state"] == "sleep":
		body_y = -0.09
	n.get_child(0).position.y = lerpf(n.get_child(0).position.y, body_y, minf(1.0, dt * 4.0))
	(c["head"] as Node3D).position.y = 0.28 + body_y * 1.6


## Вещица из «Кошачьей лавки» (Д14): купили или сменили в карточке — надеть
func _cats_wear() -> void:
	for c in cats:
		var wr := String(cat_rec(c).get("wr", ""))
		if wr != String(c.get("wr_on", "")):
			c["wr_on"] = wr
			cat_wear(c["n"], wr)


func _cats_step(dt: float) -> void:
	var want := clampi(int(city.stats["pop"]) / 14, 0, 12)
	var own := 0                           # кошки историй (потерянная и найденные, «named») — сверх обычных
	for c in cats:
		if c.has("story") or c.has("named"):
			own += 1
	if cats.size() - own < want and rng.randf() < 0.02:
		_new_cat()                             # с именем, в сохранение (этап 6.4)
	var night: bool = game.hour >= 21.0 or game.hour < 6.0
	var t := AnimClock.now()
	_cats_wear()
	for c in cats:
		if c.has("story"):
			# потерянная кошка истории: где спит и что делает — решает Stories (scripts/stories.gd)
			_cat_place(c)
			if c.has("anim"):
				_cat_anim(c)
			else:
				_cat_kit_anim(c, dt, t)
			continue
		c["t"] = float(c["t"]) - dt
		match c["state"]:
			"walk":
				var path: PackedVector2Array = c["path"]
				var i: int = c["i"]
				if i >= path.size():
					c["state"] = "sleep" if night else "sit"
					c["t"] = rng.randf_range(4, 14)
				else:
					var to := path[i] - (c["p"] as Vector2)
					var d := to.length()
					var mv := (CAT_WALK if c.has("anim") else 0.9) * dt
					if d <= mv:
						c["p"] = path[i]
						c["i"] = i + 1
					else:
						var dir := to / d
						c["p"] = (c["p"] as Vector2) + dir * mv
						c["yaw"] = lerp_angle(float(c["yaw"]), atan2(dir.x, dir.y), minf(1.0, dt * 8.0))
					c["walk"] = 1.0
			_:
				c["walk"] = 0.0
				if float(c["t"]) <= 0.0:
					var home: Dictionary = city.buildings.get(c["home"], {})
					var base: Vector2 = city.door_point(home) if not home.is_empty() else c["p"]
					var to: Vector2 = base if night else _near_road(base, 12.0)
					var path := _path(c["p"], to)
					if path.size() >= 2:
						c["path"] = path
						c["i"] = 1
						c["state"] = "walk"
					else:
						c["t"] = rng.randf_range(3, 8)
		_cat_place(c)
		if c.has("anim"):
			_cat_anim(c)
		else:
			_cat_kit_anim(c, dt, t)
		# изредка мяукает, если камера рядом
		c["meow_t"] = float(c["meow_t"]) - dt
		if float(c["meow_t"]) <= 0.0:
			c["meow_t"] = rng.randf_range(90, 240)
			if c["state"] != "sleep" and game.sound:
				game.sound.cat(c["snd"])


# ---------- истории горожан (scripts/stories.gd): кошка, где ей спрятаться, люди для роликов ----------



## Кошка без жизни на улице — для корзинки-украшения и портрета в облачке: модель окраса fur в позе clip
## (Sleep, Sit, Pet), без звука и прогулок. Модели нет — кошка из Kit. length — длина: по умолчанию как в корзинке,
## в «Пересмотреть» — как на улице (CAT_LEN), чтобы Мася в ролике не была меньше себя
static func cat_node(fur: int, clip := "Sleep", seed_v := 0, length := CAT_LEN_BED) -> Node3D:
	var f: Array = cat_fur(fur)
	var root := Node3D.new()
	if not _cat_model_ok():
		var meshes := _cat_mesh(f[0], f[1])
		var mat := Kit.material(0.9)
		for e: Array in [[0, Vector3.ZERO], [1, Vector3(0, 0.28, 0.3)], [2, Vector3(0, 0.22, -0.3)]]:
			var mi := MeshInstance3D.new()
			mi.mesh = meshes[int(e[0])]
			mi.material_override = mat
			mi.position = e[1]
			root.add_child(mi)
		root.scale = Vector3.ONE * (length / CAT_LEN_BED)
		return root
	var m := _cat_scene.instantiate() as Node3D
	m.rotation.y = -PI / 2
	m.scale = Vector3.ONE * length / _cat_size * 0.95
	root.add_child(m)
	var fmat := _cat_dress(m, fur)
	var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
	ap.add_animation_library("cat", _cat_lib)
	var cl: Array = CAT_CLIP.get(clip.to_lower(), CAT_CLIP["sleep"])
	fmat.set_shader_parameter("sleep", 1.0 if cl[0] == "Sleep" else 0.0)
	ap.play("cat/" + String(cl[0]))
	ap.speed_scale = float(cl[1])
	ap.seek(float(seed_v % 1000) / 1000.0 * ap.current_animation_length, true)
	return root


# ---------- вещицы «Кошачьей лавки» на кошке (Д14) ----------
# Вещь — маленькая сетка из Kit (цвет в вершинах, общий материал, без тени): на голове (шляпка, венок, бантик, цветок),
# на шее (ошейник с колокольчиком, бандана, бабочка) или на спине (плащик). На модели Quaternius она висит на кости
# (BoneAttachment3D) и двигается с головой, шеей, спиной; у запасной кошки из Kit — на месте головы. Сетки собраны
# в метрах для кошки длиной CAT_LEN; к кости — через позу покоя (точки ниже — в единицах скелета, голова уже крупнее)

## Куда крепится вещь: кость и точка в позе покоя (скелет: x — вперёд, y — влево, z — вверх)
const CAT_SLOT := {
	"head": ["Bone.003", Vector3(0.0255, 0.0, 0.0332)],     # макушка между ушами
	"neck": ["Bone.002", Vector3(0.0172, 0.0, 0.0249)],     # шея у головы
	"back": ["Bone.001", Vector3(0.0035, 0.0, 0.0272)],     # спина у лопаток
}
## У запасной кошки из Kit — от её корня (метры, кошка смотрит вдоль +z)
const CAT_SLOT_KIT := {"head": Vector3(0, 0.39, 0.3), "neck": Vector3(0, 0.28, 0.22), "back": Vector3(0, 0.3, 0.02)}
const CAT_NECK_TILT := -0.616          # шея идёт вперёд и вверх (35°): ошейник — поперёк неё
static var _wear_mesh := {}
static var _wear_mat: StandardMaterial3D


## Надеть кошке (узел кошки: живой c["n"] или cat_node) вещь item; "" — снять. Прежняя вещь уходит
static func cat_wear(root: Node3D, item: String) -> void:
	if root == null or not is_instance_valid(root):
		return
	for old in root.find_children("cat_acc*", "", true, false):
		old.get_parent().remove_child(old)
		old.queue_free()
	if item == "" or not Defs.CAT_ITEMS.has(item):
		return
	var slot := String(Defs.CAT_ITEMS[item]["slot"])
	var mi := MeshInstance3D.new()
	mi.name = "cat_acc_mesh"
	mi.mesh = _wear_build(item)
	if _wear_mat == null:
		_wear_mat = Kit.material(0.75)
	mi.material_override = _wear_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sks := root.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		var holder := Node3D.new()
		holder.name = "cat_acc"
		holder.position = CAT_SLOT_KIT[slot]
		holder.add_child(mi)
		root.add_child(holder)
		return
	var sk: Skeleton3D = sks[0]
	var sl: Array = CAT_SLOT[slot]
	var bi := sk.find_bone(String(sl[0]))
	if bi < 0:
		mi.queue_free()
		return
	var ba := BoneAttachment3D.new()
	ba.name = "cat_acc"
	ba.bone_name = String(sl[0])
	sk.add_child(ba)
	# метры (вещь: x — влево, y — вверх, z — вперёд) → единицы скелета (x — вперёд, y — влево, z — вверх)
	var k := _cat_size / (100.0 * CAT_LEN) if _cat_size > 0.01 else 0.095
	var axes := Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0))
	var t_skel := Transform3D(axes * Basis.from_scale(Vector3.ONE * k), sl[1])
	mi.transform = sk.get_bone_global_rest(bi).affine_inverse() * t_skel
	ba.add_child(mi)


## Сетка вещи (одна на всех кошек): метры, начало — точка крепления, x — влево, y — вверх, z — вперёд
static func _wear_build(item: String) -> ArrayMesh:
	if _wear_mesh.has(item):
		return _wear_mesh[item]
	var kt := Kit.new()
	match item:
		"bow":
			# розовый бантик у левого уха: две петли и узелок
			var c := Vector3(0.036, 0.004, -0.004)
			kt.xf = Transform3D(Basis(Vector3.FORWARD, 0.35), c)
			for s: float in [-1.0, 1.0]:
				kt.blob(Vector3(0.019 * s, 0, 0), Vector3(0.018, 0.013, 0.006), Color("f07fa6"), 3 + int(s), 0.08)
			kt.blob(Vector3.ZERO, Vector3(0.008, 0.008, 0.008), Color("d9507e"), 7, 0.05)
			for s: float in [-1.0, 1.0]:
				kt.rod(Vector3(0.003 * s, -0.004, 0), Vector3(0.012 * s, -0.022, 0.002), 0.004, 4, Color("e86a94"))
		"wreath":
			# лавровый венок вокруг макушки: листочки по кругу, спереди — золотые ягодки
			var n := 16
			for i in n:
				var a := TAU * i / n
				var p := Vector3(sin(a) * 0.056, -0.012 - cos(a) * 0.006, cos(a) * 0.05)
				var lc := Color("4f8a32") if i % 2 == 0 else Color("6aa83e")
				kt.xf = Transform3D(Basis(Vector3.UP, a + 0.5) * Basis(Vector3.RIGHT, 0.5), p)
				kt.blob(Vector3.ZERO, Vector3(0.011, 0.004, 0.019), lc, i, 0.1)
			kt.xf = Transform3D.IDENTITY
			for s: float in [-1.0, 1.0]:
				kt.blob(Vector3(0.012 * s, -0.006, 0.054), Vector3(0.005, 0.005, 0.005), Color("e8b33a"), 11, 0.05)
		"pileus":
			# колпачок с помпоном: войлочный конус чуть набок, белый отворот, пушистый помпон
			kt.xf = Transform3D(Basis(Vector3.FORWARD, -0.18) * Basis(Vector3.RIGHT, -0.12), Vector3(0, -0.004, -0.002))
			kt.cyl(Vector3.ZERO, 0.037, 0.012, 10, Color("f4efe4"), 0.036)
			kt.cyl(Vector3(0, 0.011, 0), 0.033, 0.066, 10, Color("c8432f"), 0.006)
			kt.blob(Vector3(0, 0.08, 0), Vector3(0.014, 0.014, 0.014), Color("fbf7ee"), 5, 0.12)
		"petasos":
			# соломенная шляпка-петас: широкие поля, низкая тулья, красная лента
			kt.xf = Transform3D(Basis(Vector3.RIGHT, -0.1), Vector3(0, -0.002, -0.004))
			kt.cyl(Vector3.ZERO, 0.074, 0.006, 14, Color("e2bd62"), 0.07)
			kt.cyl(Vector3(0, 0.006, 0), 0.038, 0.013, 12, Color("c9472f"), 0.038, false)
			kt.cyl(Vector3(0, 0.019, 0), 0.038, 0.02, 12, Color("ebc86e"), 0.03)
		"flower":
			# цветок за правым ухом: пять белых лепестков, жёлтая серединка, листик
			kt.xf = Transform3D((Basis(Vector3.FORWARD, -0.5) * Basis(Vector3.RIGHT, -0.9)).scaled(Vector3.ONE * 1.35), Vector3(-0.038, 0.002, -0.006))
			for i in 5:
				var a := TAU * i / 5.0
				kt.blob(Vector3(cos(a) * 0.012, 0, sin(a) * 0.012), Vector3(0.009, 0.003, 0.009), Color("fbf4f0") if i % 2 == 0 else Color("ffd6e2"), i, 0.05)
			kt.blob(Vector3(0, 0.002, 0), Vector3(0.006, 0.004, 0.006), Color("f2c230"), 9, 0.05)
			kt.blob(Vector3(0.012, -0.002, -0.016), Vector3(0.007, 0.002, 0.013), Color("5c9a3a"), 4, 0.05)
		"collar":
			# красный ошейник поперёк шеи и золотой колокольчик внизу спереди
			kt.xf = Transform3D(Basis(Vector3.RIGHT, CAT_NECK_TILT), Vector3.ZERO)
			_ring(kt, 0.061, 0.066, 0.008, 0.012, Color("b8322a"))
			kt.blob(Vector3(0, -0.075, 0.012), Vector3(0.011, 0.011, 0.011), Color("f0c040"), 3, 0.04)
			kt.boxc(Vector3(0, -0.084, 0.018), Vector3(0.006, 0.003, 0.003), Color("6a4a14"))
		"bandana":
			# синяя бандана: узел по шее и треугольник на груди
			kt.xf = Transform3D(Basis(Vector3.RIGHT, CAT_NECK_TILT), Vector3.ZERO)
			_ring(kt, 0.062, 0.067, 0.011, 0.014, Color("3d74c4"))
			var a := Vector3(-0.05, -0.052, 0.045)
			var b := Vector3(0.05, -0.052, 0.045)
			var tip := Vector3(0, -0.125, 0.068)
			kt.tri_out(a, b, tip, Color("3d74c4"), Vector3(0, -0.07, 0.0))
			kt.tri_out(a, tip, b, Color("2f5ea3"), Vector3(0, -0.07, 0.12))
			for p: Vector3 in [Vector3(-0.017, -0.072, 0.056), Vector3(0.02, -0.074, 0.056), Vector3(0, -0.098, 0.062)]:
				kt.blob(p, Vector3(0.005, 0.005, 0.002), Color("f4f0e6"), 2, 0.02)
		"bowtie":
			# бабочка под подбородком: два треугольника и узелок, на тонкой ленточке
			kt.xf = Transform3D(Basis(Vector3.RIGHT, CAT_NECK_TILT), Vector3.ZERO)
			_ring(kt, 0.06, 0.065, 0.004, 0.006, Color("2a2a3a"))
			var c := Vector3(0, -0.07, 0.038)
			for s: float in [-1.0, 1.0]:
				kt.tri_out(c, c + Vector3(0.041 * s, 0.019, 0.005), c + Vector3(0.041 * s, -0.019, 0.005), Color("c22f4a"), c + Vector3(0.0, 0.0, -0.02))
				kt.tri_out(c, c + Vector3(0.041 * s, -0.019, 0.005), c + Vector3(0.041 * s, 0.019, 0.005), Color("a1243c"), c + Vector3(0.0, 0.0, 0.03))
			kt.blob(c + Vector3(0, 0, 0.004), Vector3(0.009, 0.009, 0.007), Color("d9384f"), 4, 0.03)
		"cape":
			# плащик легионера: красная ткань по спине и бокам, золотая застёжка у шеи
			# дуга ткани вокруг спины (туловище в разрезе — около 14 см в ширину, середина на 7 см ниже хребта)
			var segs := 8
			for i in segs:
				var a0 := lerpf(-1.45, 1.45, float(i) / segs)
				var a1 := lerpf(-1.45, 1.45, float(i + 1) / segs)
				var p00 := Vector3(sin(a0) * 0.082, cos(a0) * 0.082 - 0.068, 0.03)
				var p01 := Vector3(sin(a1) * 0.082, cos(a1) * 0.082 - 0.068, 0.03)
				var p10 := Vector3(sin(a0) * 0.096, cos(a0) * 0.092 - 0.078, -0.165)
				var p11 := Vector3(sin(a1) * 0.096, cos(a1) * 0.092 - 0.078, -0.165)
				var col := Color("b52a2a") if i % 2 == 0 else Color("a52424")
				kt.quad_out(p00, p01, p11, p10, col, Vector3(0, -0.07, -0.07))
				kt.quad_out(p00, p10, p11, p01, Color("7c1c1c"), Vector3(0, 0.14, -0.07))
			kt.blob(Vector3(0, 0.016, 0.034), Vector3(0.013, 0.01, 0.007), Color("e7b84a"), 6, 0.05)
	var m := kt.mesh()
	_wear_mesh[item] = m
	return m


## Кольцо поперёк шеи (в плоскости xy, ось — z): полуоси rx, ry, толщина th, ширина w
static func _ring(kt: Kit, rx: float, ry: float, th: float, w: float, col: Color) -> void:
	var n := 14
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var o0 := Vector3(sin(a0) * rx, cos(a0) * ry, 0)
		var o1 := Vector3(sin(a1) * rx, cos(a1) * ry, 0)
		var i0 := o0 * (1.0 - th / rx)
		var i1 := o1 * (1.0 - th / rx)
		var dz := Vector3(0, 0, w * 0.5)
		kt.quad_out(o0 - dz, o1 - dz, o1 + dz, o0 + dz, col, Vector3.ZERO)
		kt.quad_out(i0 + dz, i1 + dz, o1 + dz, o0 + dz, col.lightened(0.08), Vector3(0, 0, -1))
		kt.quad_out(i0 - dz, o0 - dz, o1 - dz, i1 - dz, col.darkened(0.1), Vector3(0, 0, 1))


## Кошка истории: свой поток случайностей (общий rng жителей не сдвигается — витрина и меню прежние), окрас fur,
## у точки p. Замерла (story): что ей делать, решает Stories; в число обычных кошек не входит
func story_cat(home: Dictionary, p: Vector2, fur: int, seed_v: int) -> Dictionary:
	var rg := RandomNumberGenerator.new()
	rg.seed = seed_v
	var c := _make_cat(home, {"fur": fur, "p": p, "rng": rg})
	c["story"] = true
	c["state"] = "sleep"
	cats.append(c)
	_cat_place(c)
	if c.has("anim"):
		_cat_anim(c)
	return c


## Кошка-награда истории: живёт у дома home как обычная (гуляет, спит, дети гладят), сверх числа обычных
func pet_cat(home: Dictionary, fur: int, nm: String, seed_v: int, at := Vector2.INF) -> Dictionary:
	var rg := RandomNumberGenerator.new()
	rg.seed = seed_v
	var opts := {"fur": fur, "rng": rg}
	if at != Vector2.INF:
		opts["p"] = at
	var c := _make_cat(home, opts)
	c["named"] = nm
	cats.append(c)
	return c


## Кошка истории стала кошкой-наградой: живёт у дома home (хозяйка унесла её домой) и гуляет как все
func free_cat(c: Dictionary, home: int, nm: String) -> void:
	c.erase("story")
	c["named"] = nm
	c["home"] = home
	c["state"] = "sit"
	c["t"] = 2.0
	var h: Dictionary = city.buildings.get(home, {})
	if not h.is_empty():
		var q := _near_free(city.door_point(h))
		if q != Vector2.INF:
			c["p"] = q
			c["path"] = PackedVector2Array()
			_cat_place(c)


## Убрать кошку (история прервалась)
func drop_cat(c: Dictionary) -> void:
	cats.erase(c)
	var n = c.get("n")
	if n != null and is_instance_valid(n):
		(n as Node).queue_free()


## Свободное место вплотную к украшению b, куда кошка может забиться (в траве лучше, чем на мостовой); Vector2.INF — нет
func _beside(b: Dictionary, rg: RandomNumberGenerator) -> Vector2:
	var c: Vector2 = b["pos"]
	var a0 := rg.randf() * TAU
	var paved := Vector2.INF
	for r: float in [0.8, 1.15, 1.6, 2.1]:
		for k in 10:
			var a := a0 + TAU * k / 10.0
			var q := c + Vector2(cos(a), sin(a)) * r
			if not _hide_ok(q):
				continue
			if not land.is_road(q):
				return q
			if paved == Vector2.INF:
				paved = q
	return paved


## Сюда кошке можно: на своей земле, не в постройке, не в воде и не на круче
func _hide_ok(q: Vector2) -> bool:
	if q.x < 1.0 or q.y < 1.0 or q.x > Land.SIZE - 1.0 or q.y > Land.SIZE - 1.0:
		return false
	if not land.is_owned(q) or land.occ_at(q) != 0 or land.is_water(q):
		return false
	var h := land.height_at(q.x, q.y)
	for d: Vector2 in [Vector2(0.4, 0), Vector2(-0.4, 0), Vector2(0, 0.4), Vector2(0, -0.4)]:
		if absf(land.height_at(q.x + d.x, q.y + d.y) - h) > 0.3:
			return false
	return true


## Где спрятаться кошке: у украшения из bases (сено, корзины, кусты…) от rmin до rmax м от точки from, на свободном
## месте, куда от from можно дойти; таких нет — на своей земле в траве. Vector2.INF — негде (историю не предлагаем)
func hide_spot(from: Vector2, rmin: float, rmax: float, bases: Array, rg: RandomNumberGenerator) -> Vector2:
	var cand := []
	for id in city.buildings:
		var b: Dictionary = city.buildings[id]
		if city.def(b)["kind"] != "decor" or b.has("host") or not (Defs.base_of(b["type"]) in bases):
			continue
		var d := (b["pos"] as Vector2).distance_to(from)
		if d >= rmin and d <= rmax:
			cand.append(b)
	for i in range(cand.size() - 1, 0, -1):
		var j := rg.randi() % (i + 1)
		var tmp = cand[i]
		cand[i] = cand[j]
		cand[j] = tmp
	# дойти можно: от двери до тропы рядом с местом (тропа — в паре шагов, _path ищет её сам)
	for b in cand.slice(0, 12):
		var q := _beside(b, rg)
		if q != Vector2.INF and q.distance_to(from) >= rmin and _path(from, q).size() >= 2:
			return q
	for k in 60:
		var a := rg.randf() * TAU
		var q := from + Vector2(cos(a), sin(a)) * rg.randf_range(rmin, rmax)
		if _hide_ok(q) and not land.is_road(q) and _path(from, q).size() >= 2:
			return q
	return Vector2.INF


## Ребёнок семьи fam из дома home (житель) или {}
func child_of(fam: String, home: int) -> Dictionary:
	for r in residents:
		if r["fam"] == fam and int(r["home"]) == home and bool(r["child"]):
			return r
	return {}


## Человек для ролика истории: как житель с тем же seed (тот же облик и одежда), сам по себе (не ходит по делам).
## Лицо — для крупного плана (Citizen.face_fix); old — старик (седой)
func actor(seed_v: int, female: bool, child: bool, cls: String, old := false) -> Citizen:
	var rr := RandomNumberGenerator.new()
	rr.seed = seed_v
	var c := Citizen.create(rr, female, child, cls == "patricians", "", cls)
	if child:
		kid_look(c)
	if old:
		Citizen.elder_look(c)
	else:
		Citizen.face_fix(c, false, child)
	add_child(c)
	c.anim.speed_scale = 1.0
	return c


## Человек для ролика по облику (герой истории — настоящий житель, этап 6.10): тот же, что на улице, лицо — для крупного плана
func actor_look(lk: Dictionary, child := false, old := false) -> Citizen:
	var c := Citizen.build(lk, child)
	if child:
		kid_look(c)
	if old:
		Citizen.elder_look(c)
	else:
		Citizen.face_fix(c, false, child)
	add_child(c)
	c.anim.speed_scale = 1.0
	return c


## Ребёнок в ролике и на портрете: без бороды, голова чуть крупнее (дети у нас — уменьшенные взрослые Synty;
## вблизи, в ролике, иначе выходит маленький бородач)
static func kid_look(c: Node) -> void:
	no_beard(c)
	Citizen.kid_face(c)                       # то же, что у детей на улице (Citizen.create): без щетины, голова крупнее


## Борода ни к чему (причёску жителя выбирает Citizen.create)
static func no_beard(c: Node) -> void:
	for att in c.find_children("*", "BoneAttachment3D", true, false):
		for ch in att.get_children():
			if String(ch.name).contains("Beard") or not ch.find_children("*Beard*", "", true, false).is_empty():
				att.remove_child(ch)
				ch.free()


## Где сейчас семья, что ждёт жилья (середина её людей) — для значка над ней; Vector3.INF — такой нет
func waiting_family_pos(name: String) -> Vector3:
	for wf in waiting_fams:
		if wf["name"] != name:
			continue
		var sum := Vector2.ZERO
		var n := 0
		for id in wf["members"]:
			if by_id.has(id):
				sum += by_id[id]["p"]
				n += 1
		if n == 0:
			return Vector3.INF
		var p := sum / n
		return Vector3(p.x, land.height_at(p.x, p.y), p.y)
	return Vector3.INF
