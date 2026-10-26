class_name City
extends RefCounted
## Жизнь города — как в Town to City: три класса жителей, лавки по видам потребностей обслуживают
## ближайшие дома в своей дальности (сколько потянут рабочие), памятники и украшения радуют всех вокруг,
## теснота огорчает. Этаж полному счастливому дому покупает игрок (buy_floor); новые семьи едут, пока
## город счастлив (arrivals_blocked), и только в свободные дома (free_fit).
## Деньги — налоги с домов; очки исследований — почта на станции, скрипторий, школа, библиотека. Новый уровень —
## как в Town to City: когда выполнены условия (жители, счастье, постройки — Defs.LEVELS need), игрок сам жмёт
## «Перейти на новый уровень» (rank_up); город сам не растёт. Большие траты: игры в честь богов (festival, с «Посёлка»)
## и участки земли (buy_plot: у новой игры своя земля — 2×3 участка, Land.START_PLOTS).

signal changed                       # что-то поменялось — перерисовать интерфейс
signal building_added(b)
signal building_removed(b)
signal house_changed(b, up)
signal event(text, icon)             # событие для колокольчика и всплывашки справа
signal family_left(home, name)       # семья уехала из дома (жители уходят по большой дороге)
signal arrivals_changed              # на площади у станции стало больше или меньше семей
signal family_came(f)                # повозка привезла семью
signal family_assigned(name, home)   # игрок выбрал семье дом — жители идут туда
signal arrive_advice(text)           # повозка впервые встала из-за низкого счастья — объясняет советник
signal level_up(lvl)                 # город перешёл на новый уровень — ролик «Новый ранг» (rank_cine.gd)
signal quiet(text, icon)             # событие только в колокольчик, без всплывашки
signal festival_changed(on)          # игры в честь богов начались / кончились — город наряжается (game.gd)

var land: Land
var money := float(Defs.START_MONEY)
var rp := 0.0
var day := 0
var level := 0
var research := {}                    # id → true
var buildings := {}                   # id → запись постройки
var next_id := 1
## happy_parts — счастье города по слагаемым [[подпись, %], …]; happy_tips — 1–3 подсказки, что поднимет счастье;
## arrive_block — почему не едут новые семьи ("" — едут)
var stats := {"pop": 0, "happy": 0, "income": 0.0, "upkeep": 0.0, "rp_day": 0.0, "residents": {}, "workers": {}, "jobs": {}, "free": {}, "class_happy": {},
	"happy_parts": [], "happy_tips": [], "arrive_block": ""}
var goods := {}                       # сырьё, которое есть в городе: wheat, olives, grapes
## Приезд семей — как поезд в Town to City: повозка привозит семью, она ждёт на площади у станции,
## пока игрок не выберет ей дом. Ждать могут не больше ARRIVAL_MAX семей — тогда новые не едут.
var arrivals: Array = []              # семьи на площади: [{name, n, cls}]
var pending := {}                     # семьи, которым выбран дом, идут туда: имя → {name, n, cls, home}
var cats: Array = []                  # кошки города с именами (этап 6.4): [{nm, sx, fur, home, sd}] — сохраняются
var hero := {}                        # свой герой (Д11, Hero): {v, m: запись, как у жителя, + облик с плащом, made, seen, kit}; {} — ещё нет
var incoming := 0                     # сколько семей едет в повозке
var arrive_t := 0.0                   # часов с прошлой повозки
var arrive_block_h := 0               # сколько часов повозка не везёт семьи из-за низкого счастья
var arrive_block_said := -999         # в какой час советник последний раз объяснил, почему семьи не едут
var arrive_block_told := false        # советник сказал «не едут» — когда поедут, скажет «снова едут»
var hour_n := 0                       # игровых часов с начала (с загрузки)
var settled_total := 0                # сколько семей заселено за игру
var moving_id := -1                   # постройку переносят — жильцы не уходят из неё
var tips := {}                        # какие советы и шаги обучения уже показаны
signal rehomed(old, new)              # перенесённый дом получил новый номер
var waiting: int:
	get:
		return arrivals.size()
var goals_done: Array = []
var events: Array = []                # [{day, text, icon}]
var unread := 0                       # события, записанные при загрузке (до интерфейса): число на колокольчике
var road_cells := 0                   # сколько клеток дорог проложил игрок
var rng := RandomNumberGenerator.new()
var bulk := false                     # place() без пересчёта (витрина Showcase ставит сотни построек, compute — в конце)
var legion := Legion.new()            # армия: походы, Слава, чудеса (legion.gd); сохраняется под ключом "legion"
var fest_left := 0                    # сколько игровых часов ещё идут игры в честь богов (Defs.FESTIVAL)
var fest_cd := 0                      # через сколько часов можно устроить новые игры
var plots_bought := 0                 # сколько участков земли куплено (от него цена следующего)
var name := ""                        # название города — копия имени с сервера (CityName); "" — ещё не знаем («Новый Рим»)
var seg_thin := false                 # звено забора — узкой полосой (заборы мышью); готовый город меню — по-старому
## Правила экономики (этап 2.5/2.6, решение владельца Q3/Q4): 0 — как до сборки 35 (живые города без «да» владельца:
## счастье не меняется), 1 — новая игра: вторая лавка того же вида — вполовину, одинаковые украшения рядом — всё меньше
var econ := 0
## Украшения этапа 5 (решение владельца Q17): 0 — живой город (все прежние облики открыты, как были), 1 — новая игра:
## часть прежних обликов открывается позже, в наборах (Defs.DECOR_LATER)
var decor_v := 0
## Истории этапа 7b (решение владельца Q20): 0 — живой город («Пост вигилов» изучается за очки, как прежде), 1 — новая
## игра: его открывает история «Пожар у горшечников» (Defs.story_of — свиток исследований смотрит сюда)
var story_v := 0:
	set(v):
		story_v = v
		Defs.story_rules = v
## Налоги по классам (этап 2.7, с «Деревни»): класс → 0 мягкие, 1 обычные, 2 высокие (Defs.TAX_SET)
var taxes := {}
## История денег и жителей (этап 2.4): последние Defs.HIST_N игровых часов, строки по Defs.HIST_KEYS (сохраняются)
var hist: Array = []
var hist_acc := {}                     # движение денег за идущий час по видам (стройка, земля, игры, Легион, награды)
var hist_mark := NAN                   # казна в конце прошлого часа (NAN — после загрузки ещё не знаем)
var _street := {}                      # «ухоженная улица» (этап 5.7): id дома → [правка узора земли, вход, бонус, правка покрытий] — кэш
signal rp_reward(n)                    # просьба принесла очки исследований — «+N» летит к счётчику свитков (без звука)
## «Истории горожан» (scripts/stories.gd, данные — StoryDefs): часы, предложение, идущая история, пройденные,
## отложенные, бонусы к счастью (их строки — в happy_parts дома), кошки-награды. Сохраняется под ключом "stories"
var stories := stories_new()
var chron := Chronicle.fresh()         # «Летопись города»: счётчики и лавровые венки (scripts/chronicle.gd)
var chron_on := false                  # венки проверяются только в своём городе (game: play/new), не в меню и не в готовом


func _init(l: Land) -> void:
	land = l
	rng.seed = 5
	legion.bind(self)


func def(b: Dictionary) -> Dictionary:
	return Defs.B[b["type"]]


func is_house(b: Dictionary) -> bool:
	return def(b)["kind"] == "house"


# ---------- окантовка у построек (Town to City): глина у домов и лавок, у домусов и храмов — каменный бордюр ----------

const APRON_KINDS := ["house", "shop", "rp", "store", "military"]
const KERB_TYPES := ["house_patrician", "temple", "pantheon"]
const PAVE_SLOPE := 0.5                # дом и лавка на мостовой — только на почти ровном месте (иначе ступени вокруг)


## 1 — глина вокруг (land.wear), 2 — каменный бордюр (его ставит game._show), 0 — ничего (украшения, поля, площади)
func apron_of(b: Dictionary) -> int:
	if b.has("host") or (b["cells"] as PackedInt32Array).is_empty():
		return 0
	var d := def(b)
	if d.get("water", false):
		return 0
	if String(b["type"]) in KERB_TYPES:
		return 2
	return 1 if d["kind"] in APRON_KINDS else 0


func _apron_add(b: Dictionary) -> void:
	if apron_of(b) == 1:
		land.wear_stamp(b["cells"], door_point(b))


## Все окантовки заново (загрузка сохранения: окантовка не сохраняется — старые города получают её сами).
## Сначала — какие постройки с бордюром: глина за их стены не заходит, как и при постройке по ходу игры
func apron_all() -> void:
	land.wear.fill(0)
	land.wear_block.clear()
	for id in buildings:
		if apron_of(buildings[id]) == 2:
			land.wear_block[int(id)] = true
	for id in buildings:
		_apron_add(buildings[id])


## Постройку убрали: её окантовку стереть, кольца соседей в том месте — записать заново (снесли домус — глина
## соседей снова доходит до этого места)
func _apron_remove(b: Dictionary) -> void:
	if apron_of(b) == 0:
		return
	land.wear_block.erase(int(b["id"]))
	_apron_refresh(b)


## Окантовку вокруг постройки b — заново: стереть у её клеток и двери, кольца соседей записать заново. Поставили
## домус — глина соседей уходит с его стен и из сада (порядок постройки не важен: как если бы домус стоял первым)
func _apron_refresh(b: Dictionary) -> void:
	var cells: PackedInt32Array = b["cells"]
	var lo := Vector2i(Land.N, Land.N)
	var hi := Vector2i(-1, -1)
	for k in cells:
		lo = lo.min(Vector2i(k % Land.N, k / Land.N))
		hi = hi.max(Vector2i(k % Land.N, k / Land.N))
	var dc := land.cell(door_point(b))
	var R := Land.APRON_W.size() - 1
	lo = lo.min(dc - Vector2i(Land.APRON_DOOR, Land.APRON_DOOR)) - Vector2i(R, R)
	hi = hi.max(dc + Vector2i(Land.APRON_DOOR, Land.APRON_DOOR)) + Vector2i(R, R)
	land.wear_clear(lo.x, lo.y, hi.x, hi.y)
	# соседи, чьи кольца и пятна у дверей могли заходить в стёртое (с запасом на кольцо и пятно)
	var m := R + Land.APRON_DOOR + 2
	var area := Rect2i(lo - Vector2i(m, m), hi - lo + Vector2i(2 * m + 1, 2 * m + 1))
	for id in buildings:
		var o: Dictionary = buildings[id]
		if int(o["id"]) == int(b["id"]) or apron_of(o) != 1:
			continue
		var oc := land.cell(o["pos"])
		if area.grow(80).has_point(oc):          # грубо по середине (постройки до ~40 м), точнее — по клеткам
			for k in (o["cells"] as PackedInt32Array):
				if area.has_point(Vector2i(k % Land.N, k / Land.N)):
					_apron_add(o)
					break


func unlocked(type: String) -> bool:
	if Defs.STORY_OPENS.has(type) and research.has(String(Defs.STORY_OPENS[type])):
		return true                               # открыла история (живую изгородь — «Лабиринт Тесея»)
	if decor_v >= 1 and Defs.DECOR_LATER.has(type):      # новая игра: этот облик — в наборе этапа 5
		return research.has(String(Defs.DECOR_LATER[type]))
	var u: String = Defs.B[type].get("unlock", "")
	if u.begins_with("boss"):                 # военные постройки: победа Легиона над N-м боссом
		return legion.bosses() >= int(u.substr(4))
	if u.begins_with("rank:"):                # здания Легиона (Д10): с уровня города, когда Легион собран
		return level >= int(u.substr(5)) and legion.window_open()
	if u.begins_with("trophy:"):              # трофей провинции: все 30 звёзд её боёв
		return legion.has_trophy(u.substr(7))
	return u == "" or research.has(u) or legion.wonder_unlocks(type)   # чудеса открывает и рейтинг походов


## Чем открывается постройка в этом городе (новая игра — с переездами обликов этапа 5)
func unlock_id(type: String) -> String:
	return Defs.unlock_of(type, decor_v >= 1)


func blueprint(b: Dictionary) -> Bp:
	return Catalog.make(b["type"], int(b["tier"]), int(b.get("variant", 0)), int(b.get("color", 0)))


func xf(b: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, b["yaw"]), Vector3(b["pos"].x, b["y"], b["pos"].y))


static func facing(yaw: float) -> Vector2:
	return Vector2(sin(yaw), cos(yaw))


static func axis(yaw: float) -> Vector2:
	return Vector2(cos(yaw), -sin(yaw))


func door_point(b: Dictionary) -> Vector2:
	var p3: Vector3 = Transform3D(Basis(Vector3.UP, b["yaw"]), Vector3(b["pos"].x, 0, b["pos"].y)) * blueprint(b).door
	return Vector2(p3.x, p3.z)


func center() -> Dictionary:
	for id in buildings:
		if buildings[id]["type"] == "center":
			return buildings[id]
	return {}


func building_at(p: Vector2) -> Dictionary:
	# сначала — украшения на стенах (у них нет клеток на земле)
	for id in buildings:
		var b: Dictionary = buildings[id]
		if b.has("host") and (b["pos"] as Vector2).distance_to(p) < 0.7:
			return b
	var id := land.occ_at(p)
	return buildings.get(id, {})


func money_cap() -> float:
	return money_cap_for(level)


## Сколько вмещает казна на уровне lvl (с уже изученными хранилищами)
func money_cap_for(lvl: int) -> float:
	var li := clampi(lvl, 0, Defs.LEVELS.size() - 1)
	var c := float(Defs.LEVELS[li]["money"])
	if econ < 1 and li <= 1:
		c = [3000.0, 5000.0][li]          # живые города (без econ_v): казна «Стоянки» и «Хутора» — прежняя, деньги не срезаем (D-q)
	if research.has("vault1"):
		c *= 2.0
	if research.has("vault2"):
		c *= 2.0
	return c


func rp_cap() -> float:
	return rp_cap_for(level)


## Предел очков исследований на уровне lvl (с уже изученным «research1»)
func rp_cap_for(lvl: int) -> float:
	return float(Defs.LEVELS[clampi(lvl, 0, Defs.LEVELS.size() - 1)]["rp"]) * (2.0 if research.has("research1") else 1.0)


func house_cap(b: Dictionary) -> int:
	var cls: String = def(b)["cls"]
	return int(Defs.CLASSES[cls]["per_floor"]) * int(b["tier"])


# ---------- стройка ----------

## Можно ли поставить; возвращает {"err": текст или "", "cells": клетки, "y": высота}
func check_place(type: String, pos: Vector2, yaw: float, variant := 0, color := 0, ignore_id := -1, pre := PackedInt32Array()) -> Dictionary:
	var d: Dictionary = Defs.B[type]
	var res := {"err": "", "cells": PackedInt32Array(), "y": 0.0}
	if not unlocked(type):
		res["err"] = "Откроется %s" % Defs.unlock_text(unlock_id(type))
		return res
	if money < float(d["cost"]) and ignore_id == -1:
		res["err"] = "Не хватает денариев"
		return res
	if ignore_id == -1 and legion.glory + 0.001 < float(d.get("glory", 0)):
		res["err"] = "Не хватает Славы: нужно %d (Слава — за победы Легиона)" % int(d["glory"])
		return res
	if ignore_id == -1 and d.get("unique", false) and _count(func(o): return o["type"] == type) > 0:
		res["err"] = "Такая постройка в городе уже есть"
		return res
	if ignore_id == -1 and cap_err(type) != "":   # предел уровня города (перенос и готовый город — без него)
		res["err"] = cap_err(type)
		return res
	if d.get("wall", false):
		return res                            # украшение на стене: место выбирает игра (стена дома)
	var tier := 1 if d["kind"] == "house" else (6 if type == "center" else 0)   # станция занимает место на вырост
	var bp := Catalog.make(type, tier, variant, color)
	var rects: Array = bp.footprint()
	if d.get("seg", false) and seg_thin:
		# звено забора занимает узкую полосу посередине: концы свободны — соседнее звено (и угол) встаёт вплотную
		rects = [Rect2(-0.82, -0.14, 1.64, 0.28)]
	var cells := pre if not pre.is_empty() else land.footprint_cells(rects, pos, yaw)     # pre — след уже посчитан (перестройка)
	if cells.is_empty():
		cells = land.footprint_cells([Rect2(-0.4, -0.4, 0.8, 0.8)], pos, yaw)
	res["cells"] = cells
	var lo := INF
	var hi := -INF
	var on_water := 0
	var arches := not land.under.is_empty()
	for k in cells:
		var q := land.cell_center(k % Land.N, k / Land.N)
		if q.x < 1.0 or q.y < 1.0 or q.x > Land.SIZE - 1.0 or q.y > Land.SIZE - 1.0:
			res["err"] = "Край карты"
			return res
		if not land.is_owned(q) and ignore_id != -2:
			res["err"] = "Эта земля ещё не куплена"
			return res
		var o := land.occ[k]
		# отрицательная занятость — неподвижное (арка у въезда): занято всегда, при любом ignore_id
		# (ignore_id −1/−2/−3 — это режимы проверки, а не номер постройки)
		if o < 0 or (o != 0 and o != ignore_id):
			res["err"] = "Место занято"
			return res
		if arches:
			var u := int(land.under.get(k, 0))
			if u != 0 and u != ignore_id:
				res["err"] = "Место занято: здесь арки акведука"
				return res
		var y := land.hq(k)
		if y < Land.WATER_Y + 0.05:
			on_water += 1
		lo = minf(lo, y)
		hi = maxf(hi, y)
	# у акведука арки землю не занимают, но и сквозь дом или другие арки не проходят
	for k in land.footprint_cells(CatGrand.under_rects(type), pos, yaw):
		var o := land.occ[k]
		var u := int(land.under.get(k, 0))
		if o < 0 or (o != 0 and o != ignore_id) or (u != 0 and u != ignore_id):
			res["err"] = "Место занято"
			return res
	if d.get("water", false):
		if on_water < cells.size():
			res["err"] = "Ставится только на воду"
			return res
		res["y"] = Land.WATER_Y - 0.02
		return res
	if on_water > 0:
		res["err"] = "Здесь вода"
		return res
	if hi - lo > 1.3:
		res["err"] = "Слишком круто"
		return res
	if d.get("shore", false) and not _near_water(cells, 3.0):
		res["err"] = "Ставится у самой воды — у пруда или озера"
		return res
	res["y"] = roundf((lo + hi) * 0.5 / Land.STEP) * Land.STEP
	if d["kind"] != "decor" and d["kind"] != "farm" and type != "center" and not d.get("noroad", false):
		var dp3: Vector3 = Transform3D(Basis(Vector3.UP, yaw), Vector3(pos.x, 0, pos.y)) * bp.door
		if not _road_near(Vector2(dp3.x, dp3.z), 1.7, cells):
			res["err"] = "Нужна дорога у входа"
			return res
	return res


## Вода ближе r метров к следу постройки (маяк — у пруда, этап 5.6)
func _near_water(cells: PackedInt32Array, r: float) -> bool:
	var lo := Vector2i(Land.N, Land.N)
	var hi := Vector2i(-1, -1)
	for k in cells:
		lo = lo.min(Vector2i(k % Land.N, k / Land.N))
		hi = hi.max(Vector2i(k % Land.N, k / Land.N))
	var rc := int(ceil(r / Land.CELL))
	for j in range(lo.y - rc, hi.y + rc + 1, 2):
		for i in range(lo.x - rc, hi.x + rc + 1, 2):
			if land.inside(i, j) and land.hq(land.idx(i, j)) < Land.WATER_Y + 0.05:
				return true
	return false


func _road_near(p: Vector2, r: float, own_cells: PackedInt32Array) -> bool:
	var c := land.cell(p)
	var rc := int(ceil(r / Land.CELL))
	for j in range(c.y - rc, c.y + rc + 1):
		for i in range(c.x - rc, c.x + rc + 1):
			if not land.inside(i, j):
				continue
			var k := land.idx(i, j)
			if Land.walk_kind(land.kind[k]) and land.occ[k] == 0 and land.cell_center(i, j).distance_to(p) <= r:
				return true
	return false


## Поставить постройку (деньги списываются); возвращает запись. free — даром и без проверок (готовый город)
func place(type: String, pos: Vector2, yaw: float, variant := 0, color := -1, free := false) -> Dictionary:
	place_gen += 1
	var d: Dictionary = Defs.B[type]
	if color < 0:
		color = pick_color(pos)
	var chk := check_place(type, pos, yaw, variant, color, -2 if free else -1)
	# здание Легиона встаёт сразу в облике своего уровня (уровень «в запасе» — после переноса старого сохранения)
	var b := {"id": next_id, "type": type, "tier": 1 if d["kind"] == "house" else (level if type == "center" else (Legion.vis_tier(legion.b_level(type)) if Legion.is_building(type) else 0)),
		"pos": pos, "yaw": yaw, "variant": variant, "color": color, "y": float(chk["y"]), "cells": chk["cells"],
		"pop": 0, "families": [], "happy": 50, "up": 0, "down": 0, "staff": 1.0, "active": true, "road": true,
		"needs": {}, "served": 0, "score": {}, "missing": [], "coming": 0, "born": next_id}   # born — порядок постройки (перенос его не меняет)
	next_id += 1
	if not free:
		money -= float(d["cost"])
		flow("build", -float(d["cost"]))
		legion.glory = maxf(0.0, legion.glory - float(d.get("glory", 0)))   # чудеса Легиона стоят ещё и Славы
		if not bulk:
			Chronicle.add(self, "decor" if d["kind"] == "decor" else "built")   # летопись: построено игроком
	var cells: PackedInt32Array = b["cells"]
	if not d.get("water", false):
		land.flatten_cells(cells, b["y"], Land.Kind.FIELD if d["kind"] == "farm" else -1)
		if d["kind"] != "decor":
			land.blend_ring(cells, b["y"], 8)
	for k in cells:
		if land.occ[k] >= 0:                   # арку у въезда (занятость < 0) не затираем даже готовым городом
			land.occ[k] = b["id"]
	land.walk_ver += 1
	_under_add(b)
	buildings[b["id"]] = b
	_apron_add(b)
	if apron_of(b) == 2:
		land.wear_block[int(b["id"])] = true
		_apron_refresh(b)
	if bulk:                                    # готовый город раскладывается разом — пересчёт один раз в конце
		building_added.emit(b)
		return b
	compute()
	building_added.emit(b)
	_check_goals()
	changed.emit()
	return b


## Полоса под арками постройки (акведук) — в Land.under: b.under — её клетки (не сохраняется, при загрузке — заново)
func _under_add(b: Dictionary) -> void:
	var ur := CatGrand.under_rects(String(b["type"]))
	if ur.is_empty():
		return
	var uc := land.footprint_cells(ur, b["pos"], float(b["yaw"]))
	b["under"] = uc
	for k in uc:
		if not land.under.has(k):
			land.under[k] = int(b["id"])


## Цвет новой постройки: не такой, как у соседей
func pick_color(pos: Vector2) -> int:
	var used := {}
	for id in buildings:
		var o: Dictionary = buildings[id]
		if (o["pos"] as Vector2).distance_to(pos) < 11.0:
			used[int(o.get("color", 0))] = true
	var opts := []
	for i in Defs.PALETTE.size():
		if not used.has(i):
			opts.append(i)
	if opts.is_empty():
		return rng.randi() % Defs.PALETTE.size()
	return opts[rng.randi() % opts.size()]


## quiet — без пересчёта города и сигнала changed (убирают сразу несколько: ластик по забору, отмена постройки —
## пересчитает тот, кто убирал)
func remove(b: Dictionary, refund := true, quiet := false) -> void:
	if def(b).get("fixed", false):
		return
	place_gen += 1
	if refund:
		money += float(def(b)["cost"]) * Defs.REFUND
		flow("build", float(def(b)["cost"]) * Defs.REFUND)
	for k in (b["cells"] as PackedInt32Array):
		if land.occ[k] == int(b["id"]):        # чужое (арку у въезда, соседа) не освобождаем
			land.occ[k] = 0
	land.walk_ver += 1
	for k in (b.get("under", PackedInt32Array()) as PackedInt32Array):
		if int(land.under.get(k, 0)) == int(b["id"]):
			land.under.erase(k)
	buildings.erase(b["id"])
	_apron_remove(b)
	# украшения на стенах снесённого дома падают вместе с ним
	for oid in buildings.keys():
		if buildings.has(oid) and int(buildings[oid].get("host", -1)) == int(b["id"]):
			remove(buildings[oid], refund, quiet)
	# семьи, которые шли в этот дом, возвращаются на площадь
	for nm in pending.keys():
		if int(pending[nm]["home"]) == int(b["id"]) and int(b["id"]) != moving_id:
			var f: Dictionary = pending[nm]
			pending.erase(nm)
			arrivals.append({"name": f["name"], "n": f["n"], "cls": f["cls"], "back": bool(f.get("back", false)), "m": f.get("m", [])})
	if quiet:
		building_removed.emit(b)
		return
	compute()
	building_removed.emit(b)
	arrivals_changed.emit()
	changed.emit()


## Перенесённый дом: те, кто шёл в старый, идут в новый
func rehome(old: int, new: int) -> void:
	if not buildings.has(new):
		return
	var b: Dictionary = buildings[new]
	for nm in pending:
		if int(pending[nm]["home"]) == old:
			pending[nm]["home"] = new
			b["coming"] = int(b.get("coming", 0)) + int(pending[nm]["n"])
	_story_rehome(old, new)
	rehomed.emit(old, new)


## Сменить цвет дома (щелчок по значку в карточке)
func recolor(b: Dictionary) -> void:
	b["color"] = (int(b["color"]) + 1) % Defs.PALETTE.size()
	house_changed.emit(b, false)
	changed.emit()


# ---------- работники (как в Town to City: сколько нанять — решает игрок) ----------

## Денариев в час за каждого нанятого работника — растёт с уровнем города (Defs.WAGE)
func wage() -> float:
	return float(Defs.WAGE[clampi(level, 0, Defs.WAGE.size() - 1)])


## Сколько построек этого вида можно держать на нынешнем уровне города (−1 — сколько угодно)
func build_max(type: String) -> int:
	var mx: Array = Defs.B[type].get("max", [])
	if mx.is_empty():
		return -1
	return int(mx[clampi(level, 0, mx.size() - 1)])


func count_type(type: String) -> int:
	return _count(func(o): return o["type"] == type)


## Почему ещё одну такую постройку не поставить из-за предела уровня ("" — можно).
## Лишние, поставленные раньше, остаются, но не работают (over_cap)
func cap_err(type: String) -> String:
	var mx := build_max(type)
	if mx < 0 or count_type(type) < mx:
		return ""
	var d: Dictionary = Defs.B[type]
	var many := String(d.get("gen", String(d["name"]).to_lower()))
	var Many := many.left(1).to_upper() + many.substr(1)
	if level >= Defs.LEVELS.size() - 1:
		return "Больше %s не поставить — это предел" % many
	if mx == 0:
		return "%s на уровне «%s» пока не строят — первые на уровне «%s»" % [Many, Defs.LEVELS[level]["name"], Defs.LEVELS[level + 1]["name"]]
	return "%s на уровне «%s» — не больше %d. Больше — на уровне «%s»" % [Many, Defs.LEVELS[level]["name"], mx, Defs.LEVELS[level + 1]["name"]]


## Постройки сверх предела уровня (старые города: поставлены, когда предела не было) — id → true.
## Работают первые build_max каждого вида по порядку постройки (born; перенос его не меняет); остальные стоят,
## но не работают и ничего не стоят
func over_cap() -> Dictionary:
	var by := {}
	for id in buildings:
		var t: String = buildings[id]["type"]
		if Defs.B[t].has("max"):
			if not by.has(t):
				by[t] = []
			by[t].append([int(buildings[id].get("born", id)), int(id)])
	var out := {}
	for t in by:
		var mx := build_max(t)
		var ids: Array = by[t]
		if ids.size() <= mx:
			continue
		ids.sort()                          # [born, id] — сначала по порядку постройки
		for i in range(maxi(0, mx), ids.size()):
			out[int(ids[i][1])] = true
	return out


## Очков исследований в час от полностью занятой постройки — с изученными прибавками (ученики писцов…)
func rp_per_hour(type: String) -> float:
	var d: Dictionary = Defs.B[type]
	var rate := float(d.get("rp", 0))
	var out := rate
	var up: Dictionary = d.get("rp_up", {})
	for r in up:
		if research.has(r):
			out += rate * float(up[r])
	return out


func job_max(b: Dictionary) -> int:
	var n := 0
	for c in def(b).get("jobs", {}):
		n += int(def(b)["jobs"][c])
	return n


## Рабочие места постройки с учётом найма: сначала младшие классы
func jobs_of(b: Dictionary) -> Dictionary:
	var d := def(b)
	if not d.has("jobs"):
		return {}
	var h := int(b.get("hire", -1))
	if h < 0 or h >= job_max(b):
		return (d["jobs"] as Dictionary).duplicate()
	var out := {}
	var left := h
	for c in Defs.CLASS_ORDER:
		if d["jobs"].has(c):
			var n := mini(int(d["jobs"][c]), left)
			out[c] = n
			left -= n
	return out


func hired_of(b: Dictionary) -> int:
	var n := 0
	var jb := jobs_of(b)
	for c in jb:
		n += int(jb[c])
	return n


func set_hire(b: Dictionary, n: int) -> void:
	b["hire"] = clampi(n, 0, job_max(b))
	compute(true)
	changed.emit()


# ---------- расчёт: обслуживание, счастье ----------

## same_place — постройки и земля те же (час игры, заселение, налоги, наём, игры): проверки места перестройки — из запаса
func compute(same_place := false) -> void:
	if not same_place:
		place_gen += 1
	var houses := []
	var residents := {}
	var jobs := {}
	for c in Defs.CLASS_ORDER:
		residents[c] = 0
		jobs[c] = 0
	var shops := []
	var monuments := []
	var decor := []
	var prem := []                          # «главные» украшения (этап 5.3): радуют, как маленький памятник
	var stores := []
	var oc := over_cap()                    # сверх предела уровня — не работают и не берут работников
	for id in buildings:
		var b: Dictionary = buildings[id]
		var d := def(b)
		match d["kind"]:
			"house":
				houses.append(b)
				residents[d["cls"]] += int(b["pop"])
			"decor":
				decor.append(b)
				if d.has("mon"):
					prem.append(b)
				continue
		b["road"] = d["kind"] in ["farm", "center"] or d.get("noroad", false) or _road_near(door_point(b), 1.7, b["cells"])
		if d.has("jobs") and b["road"] and not oc.has(int(id)):
			var jb := jobs_of(b)
			for c in jb:
				jobs[c] += int(jb[c])
	# работники: у каждого класса свои, лишние высшего класса идут на работу классом ниже
	var workers := {}
	var spare := {}
	var filled := {}
	for c in Defs.CLASS_ORDER:
		workers[c] = int(floor(residents[c] * float(Defs.CLASSES[c]["work"])))
		filled[c] = mini(jobs[c], workers[c])
		spare[c] = workers[c] - filled[c]
	for pair: Array in [["patricians", "artisans"], ["artisans", "plebs"]]:
		var take := mini(jobs[pair[1]] - filled[pair[1]], spare[pair[0]])
		if take > 0:
			filled[pair[1]] += take
			spare[pair[0]] -= take
	var ratio := {}
	for c in Defs.CLASS_ORDER:
		ratio[c] = float(filled[c]) / jobs[c] if jobs[c] > 0 else 1.0
	goods = {}
	for id in buildings:
		var b: Dictionary = buildings[id]
		var d := def(b)
		if d["kind"] == "decor" or d["kind"] == "house":
			continue
		var st := 1.0
		if d.has("jobs"):
			var jb := jobs_of(b)
			var hired := 0
			for c in jb:
				hired += int(jb[c])
				if int(jb[c]) > 0:
					st = minf(st, ratio[c])
			b["fill"] = st if b["road"] else 0.0               # хватает ли жителей на нанятые места
			st *= float(hired) / float(maxi(1, job_max(b)))     # наняли меньше — работает слабее
		b["staff"] = st if b["road"] else 0.0
		b["active"] = b["road"] and (not d.has("jobs") or float(b["staff"]) >= 0.25)
		b["over"] = oc.has(int(id))
		if b["over"]:
			b["fill"] = 0.0
			b["staff"] = 0.0
			b["active"] = false
		if d["kind"] == "farm" and b["active"]:
			goods[d["makes"]] = true
		elif d["kind"] == "store" and b["active"]:
			stores.append(b)
	for id in buildings:
		var b: Dictionary = buildings[id]
		var d := def(b)
		if d["kind"] == "shop":
			b["why"] = "" if b["active"] else ("road" if not b["road"] else "staff")
			if b["active"] and d.get("store", false) and not _store_near(b, stores):
				b["active"] = false
				b["why"] = "store"
			if b["active"] and d.has("needs_good") and not goods.has(d["needs_good"]):
				b["active"] = false
				b["why"] = "good"
			if b["active"]:
				shops.append(b)
		elif d["kind"] == "monument" and b["active"]:
			monuments.append(b)
	# лавки обслуживают ближайшие дома в своей дальности, сколько хватит сил
	for h in houses:
		h["score"] = {}            # тип лавки → бонус
		h["needs"] = {}            # вид потребности → true
		h["monuments"] = 0.0
	for s in shops:
		var d := def(s)
		var r := shop_range(d)
		var cap := int(ceil(float(Defs.CAPACITY[int(d["cap"])]) * float(s["staff"])))
		var near := []
		for h in houses:
			var dd := (h["pos"] as Vector2).distance_to(s["pos"])
			if dd <= r:
				# сначала — дома, где живут (или куда уже идёт семья), потом пустые; среди них — ближние
				var lived := int(h["pop"]) + int(h.get("coming", 0)) > 0
				near.append([dd + (0.0 if lived else 10000.0), h])
		near.sort_custom(func(a, b): return a[0] < b[0])
		var served := 0
		var serves := []
		for e in near:
			if served >= cap:
				break
			var h: Dictionary = e[1]
			serves.append(h["id"])
			var sc: Dictionary = h["score"]
			if int(sc.get(s["type"], 0)) < int(d["bonus"]):
				sc[s["type"]] = int(d["bonus"])
			h["needs"][d["sub"]] = true
			served += 1
		s["served"] = served
		s["serves"] = serves           # какие дома обслуживает (для подсветки охвата)
		s["cap"] = cap                 # сколько домов может обслужить сейчас (с нынешними работниками)
		s["near_n"] = near.size()      # сколько домов в её дальности
	# Счастье дома — сумма слагаемых, как в Town to City (их список — b["happy_parts"], для карточки дома):
	#   основа класса: плебеи 44, ремесленники 41, патриции 38 (Defs.CLASSES base)
	#   + бонус каждой РАЗНОЙ лавки, что обслуживает дом (две фруктовые лавки — один бонус), любые виды
	#   + украшения в радиусе DECOR_RADIUS: +1% за каждые 2 очка украшения, не больше deco_max класса (12/14/16)
	#   + памятники в своей дальности (каждый вид памятника — один раз)
	#   − теснота: −2% за каждого соседа сверх DENSITY_FREE в радиусе DENSITY_RADIUS (не больше −16%)
	#   − 10% за каждый нужный классу вид лавки (еда, одежда…), которой нет рядом
	# Для плебеев: только фруктовая лавка — 49%, с парой фонарей — 52–55%; приезд новых семей (60%) —
	# две лавки еды и украшения; 65% (второй этаж) — три разные лавки и украшения; 75% (третий) — ещё мясо, хлеб, фонтан.
	var happy_sum := 0.0
	var pop := 0
	var dim_any := false                       # где-то повтор лавки или украшения дал меньше (совет «Разнообразие» — один раз)
	var sums := {"base": 0.0, "shops": 0.0, "deco": 0.0, "mon": 0.0, "fest": 0.0, "crowd": 0.0, "miss": 0.0, "w": 0.0}
	var fb := fest_bonus()                     # игры в честь богов — всем домам, как триумф Легиона
	for b: Dictionary in stories["bonus"]:
		if b.has("at"):                        # «памятник» скверика: пока скверик стоит (разобрали — бонуса нет)
			b["_live"] = Stories.square_live_pct(self, b)
	for h in houses:
		var cls: String = def(h)["cls"]
		var cd: Dictionary = Defs.CLASSES[cls]
		var parts := []
		var base := int(cd.get("base", 40))
		parts.append(["Основа", base])
		var shop_sum := 0
		var types: Array = (h["score"] as Dictionary).keys()
		types.sort_custom(func(a, b): return _shop_rank(a) < _shop_rank(b))
		# новая игра (econ): внутри одного вида лавок первая — целиком, вторая — вполовину, дальше — четверть (shop_parts)
		for e2: Array in shop_parts(types, h["score"], econ):
			parts.append([e2[0], e2[1]])
			shop_sum += int(e2[1])
			dim_any = dim_any or bool(e2[2])
		# украшения рядом: [вид, очки]; новая игра — одинаковые 100% / 60% / 30% (deco_points)
		var near := []
		var sets := {}                  # набор этапа 5 → его виды рядом (новая игра: три разных — бонус набора)
		for o in decor:
			if (h["pos"] as Vector2).distance_to(o["pos"]) <= Defs.DECOR_RADIUS:
				near.append([Defs.base_of(o["type"]), float(def(o).get("deco", 1))])
				if econ >= 1:
					var sk := Defs.set_of(o["type"])        # набор — по облику (как в новой игре), чем бы он ни открылся
					if sk != "":
						if not sets.has(sk):
							sets[sk] = {}
						sets[sk][Defs.base_of(o["type"])] = true
		var dp := deco_points(near, econ)
		var deco: float = dp[0]
		dim_any = dim_any or bool(dp[1])
		var deco_b := mini(int(cd.get("deco_max", 12)), int(floor(deco * Defs.DECO_RATE)))
		parts.append(["Украшения", deco_b])
		var set_b := set_bonus(sets, parts)
		var mon := {}                   # вид памятника → бонус (одинаковые не складываются)
		for m in monuments:
			var md := def(m)
			if (h["pos"] as Vector2).distance_to(m["pos"]) <= Defs.range_m(md):
				mon[m["type"]] = maxi(int(mon.get(m["type"], 0)), int(md["bonus"]))
		for m in prem:                  # «главные» украшения — каждый вид один раз, сверх предела украшений
			var pd := def(m)
			if (h["pos"] as Vector2).distance_to(m["pos"]) <= Defs.range_m(pd):
				mon[m["type"]] = maxi(int(mon.get(m["type"], 0)), int(pd["mon"]))
		var mon_sum := 0
		for t in mon:
			parts.append([Defs.B[t]["name"], int(mon[t])])
			mon_sum += int(mon[t])
		var lg := legion.city_happy()          # чудеса Легиона без постройки и триумф — всем домам
		if lg > 0:
			parts.append(["Легион: чудеса и триумф", lg])
			mon_sum += lg
		if fb > 0:
			parts.append(["Праздник: игры в честь богов", fb])
		var st_sum := 0                         # истории горожан: награды к счастью (дому, соседям, всем)
		for e: Array in story_parts(h):
			parts.append(e)
			st_sum += int(e[1])
		var sb := street_bonus(h)               # «ухоженная улица» (этап 5.7): у входа — улучшенная мостовая
		if sb > 0:
			parts.append(["Ухоженная улица", sb])
		# налоги класса (с «Деревни»): мягкие +5%, высокие −8% — от счастья без потолка, то есть съедают «запас»
		var tx := int(Defs.TAX_SET[tax_of(cls)]["happy"])
		if tx != 0:
			parts.append(["Налоги: %s" % String(Defs.TAX_SET[tax_of(cls)]["name"]).to_lower(), tx])
		var crowd := 0
		for o in houses:
			if o != h and (h["pos"] as Vector2).distance_to(o["pos"]) <= Defs.DENSITY_RADIUS:
				crowd += 1
		var dens := -mini(Defs.DENSITY_MAX, maxi(0, crowd - Defs.DENSITY_FREE) * Defs.DENSITY_STEP)
		if dens < 0:
			parts.append(["Теснота", dens])
		var missing := []
		for n in cd["needs"]:
			if not h["needs"].has(n):
				missing.append(n)
				parts.append(["Нет лавки: " + String(Defs.NEEDS[n]["name"]).to_lower(), -Defs.MISSING_PENALTY])
		var hp := base + shop_sum + deco_b + set_b + sb + mon_sum + fb + st_sum + tx + dens - missing.size() * Defs.MISSING_PENALTY
		h["deco"] = deco
		h["deco_bonus"] = deco_b
		h["set_bonus"] = set_b
		h["street"] = sb
		h["monuments"] = float(mon_sum)
		h["mon_types"] = mon
		h["density"] = dens
		h["missing"] = missing
		h["happy_parts"] = parts
		h["happy"] = clampi(hp, 0, 200)
		happy_sum += clampf(hp, 0.0, 100.0) * int(h["pop"])
		pop += int(h["pop"])
		var w := float(int(h["pop"]))
		sums["w"] += w
		sums["base"] += base * w
		sums["shops"] += shop_sum * w
		sums["deco"] += (deco_b + set_b + sb) * w
		sums["mon"] += mon_sum * w
		sums["fest"] += fb * w
		sums["story"] = float(sums.get("story", 0.0)) + st_sum * w
		sums["tax"] = float(sums.get("tax", 0.0)) + tx * w
		sums["crowd"] += dens * w
		sums["miss"] += -missing.size() * Defs.MISSING_PENALTY * w
		sums["clip"] = float(sums.get("clip", 0.0)) + (clampf(hp, 0.0, 100.0) - hp) * w   # счастье дома — от 0 до 100%
	# счастье города — среднее по жителям, округлённое; его слагаемые округляем так, чтобы в сумме вышло
	# ровно оно (заголовок подсказки «Счастье города: N%» и строки под ним всегда сходятся)
	var city_happy := roundi(happy_sum / pop) if pop > 0 else 0
	var cp := []
	if float(sums["w"]) > 0.0:
		var wt: float = sums["w"]
		var rows := [["Основа", "base", true], ["Лавки", "shops", true], ["Украшения", "deco", true], ["Памятники", "mon", false],
				["Праздник: игры в честь богов", "fest", false], ["Истории горожан", "story", false], ["Налоги", "tax", false], ["Теснота", "crowd", false], ["Нет нужных лавок", "miss", false], ["", "clip", false]]
		var fv := []
		var vi := []
		var acc := 0
		for e: Array in rows:
			var f := float(sums.get(e[1], 0.0)) / wt
			fv.append(f)
			vi.append(int(floor(f)))
			acc += int(floor(f))
		var order := range(rows.size())
		order.sort_custom(func(a, b): return fv[a] - floor(fv[a]) > fv[b] - floor(fv[b]))
		var left := city_happy - acc           # остаток — тем, у кого дробная часть больше
		for i in order:
			if left <= 0:
				break
			vi[i] += 1
			left -= 1
		for i in rows.size():
			var v: int = vi[i]
			if v == 0 and not rows[i][2]:
				continue
			var nm: String = rows[i][0]
			if rows[i][1] == "clip":
				nm = "Больше 100% не бывает" if v < 0 else "Меньше 0% не бывает"
			cp.append([nm, v])
	stats["happy_parts"] = cp
	stats["dim_any"] = dim_any
	stats["pop"] = pop
	stats["residents"] = residents
	stats["workers"] = workers
	stats["jobs"] = jobs
	stats["free"] = spare
	stats["ratio"] = ratio
	stats["filled"] = filled
	stats["happy"] = city_happy
	# счастье класса — как и счастье города, по жителям (пустые дома не тянут вниз); если в домах класса
	# ещё никто не живёт — просто среднее по его домам (что их ждёт)
	var per_class := {}
	for c in Defs.CLASS_ORDER:
		var hs := 0.0
		var n := 0
		var hs0 := 0.0
		var n0 := 0
		for h in houses:
			if def(h)["cls"] == c:
				var hv := clampf(float(h["happy"]), 0.0, 100.0)
				hs += hv * int(h["pop"])
				n += int(h["pop"])
				hs0 += hv
				n0 += 1
		per_class[c] = roundi(hs / n) if n > 0 else (roundi(hs0 / n0) if n0 > 0 else 0)
	stats["class_happy"] = per_class
	stats["happy_tips"] = _happy_tips(houses, stores)
	stats["arrive_block"] = arrivals_blocked()
	_upg_ready = null                          # готовность к перестройке — заново (счастье, лавки, соседи могли поменяться)


## «вторая лавка с едой — вполовину»: вид потребности в творительном падеже
const SUB_WITH := {"food": "с едой", "clothes": "с одеждой", "fun": "с развлечениями", "services": "с услугами", "goods": "с товарами"}


## Слагаемые счастья от лавок дома: types — разные лавки по порядку (_shop_rank), score — тип → бонус. econ ≥ 1 (новая
## игра): внутри одного вида первая — целиком, вторая — вполовину, дальше — четверть (Defs.SHOP_REPEAT).
## [[строка, %, меньше ли из-за повтора], …]
static func shop_parts(types: Array, score: Dictionary, econ_v: int) -> Array:
	var out := []
	var nth := {}
	for t in types:
		var v := int(score[t])
		var nm := String(Defs.B[t]["name"])
		var dim := false
		if econ_v >= 1:
			var sub := String(Defs.B[t].get("sub", ""))
			var k := int(nth.get(sub, 0))
			nth[sub] = k + 1
			if k > 0:
				v = roundi(v * float(Defs.SHOP_REPEAT[mini(k, Defs.SHOP_REPEAT.size() - 1)]))
				nm += " (%s %s — %s)" % ["вторая" if k == 1 else "ещё одна", SUB_WITH.get(sub, ""), "вполовину" if k == 1 else "на четверть"]
				dim = true
		out.append([nm, v, dim])
	return out


## «Ухоженная улица» (этап 5.7): у входа дома (2 м вокруг) мостовая — больше чем наполовину улучшенная (плиты или
## травертин) — +STREET_BONUS% счастья. Кэш — до новой правки узора, покрытия или занятости земли (Land.walk_ver:
## простую мостовую у входа дорисовали или стёрли) или переноса дома
func street_bonus(h: Dictionary) -> int:
	if land.up_n == 0:
		return 0
	var dp := door_point(h)
	var c: Array = _street.get(int(h["id"]), [])
	if c.size() == 4 and int(c[0]) == land.deco_ver and int(c[3]) == land.walk_ver and (c[1] as Vector2) == dp:
		return int(c[2])
	var cc := land.cell(dp)
	var walk := 0
	var up := 0
	for dj in range(-8, 9, 2):                # клетки через одну (0,5 м) — быстрее, точности хватает
		for di in range(-8, 9, 2):
			if di * di + dj * dj > 64 or not land.inside(cc.x + di, cc.y + dj):
				continue
			var k := land.idx(cc.x + di, cc.y + dj)
			if Land.walk_kind(land.kind[k]) and land.occ[k] == 0:
				walk += 1
				if land.is_up(k):
					up += 1
	var v := Defs.STREET_BONUS if up >= 4 and up * 2 >= walk else 0
	_street[int(h["id"])] = [land.deco_ver, dp, v, land.walk_ver]
	return v


## Бонус наборов этапа 5 (Defs.DECOR_SETS): sets — набор → {вид: true} рядом с домом; три разных вида — +SET_BONUS%,
## не больше SET_MAX наборов; строки — в parts. Сколько всего %
static func set_bonus(sets: Dictionary, parts: Array) -> int:
	var got := []
	for sk in sets:
		if (sets[sk] as Dictionary).size() >= Defs.SET_KINDS:
			got.append(String(sk))
	got.sort_custom(func(a, b): return Defs.DECOR_SETS.find(a) < Defs.DECOR_SETS.find(b))
	var s := 0
	for sk: String in got.slice(0, Defs.SET_MAX):
		parts.append(["Набор «%s»" % String(Defs.research(sk).get("name", sk)), Defs.SET_BONUS])
		s += Defs.SET_BONUS
	return s


## Очки украшений рядом с домом: near — [[вид, очки], …]. econ ≥ 1: одинаковые (один вид, любой облик) — 100% / 60% /
## 30% (Defs.DECO_REPEAT), разные — целиком; иначе простая сумма. [очки, был ли повтор]
static func deco_points(near: Array, econ_v: int) -> Array:
	var s := 0.0
	if econ_v < 1:
		for e2: Array in near:
			s += float(e2[1])
		return [s, false]
	var by := {}
	for e2: Array in near:
		if not by.has(e2[0]):
			by[e2[0]] = []
		(by[e2[0]] as Array).append(float(e2[1]))
	var rep := false
	for bk in by:
		var vs: Array = by[bk]
		vs.sort()
		vs.reverse()
		for i in vs.size():
			s += float(vs[i]) * float(Defs.DECO_REPEAT[mini(i, Defs.DECO_REPEAT.size() - 1)])
		rep = rep or vs.size() > 1
	return [s, rep]


## Порядок лавок в списке слагаемых: по виду потребности (еда, одежда…), внутри — по бонусу
func _shop_rank(t: String) -> int:
	var d: Dictionary = Defs.B[t]
	return Defs.NEED_ORDER.find(d.get("sub", "")) * 100 - int(d.get("bonus", 0))


## Лавки дома по видам потребности: вид → бонусы по убыванию (для _shop_gain; один раз на дом в _happy_tips)
static func _shop_subs(score: Dictionary) -> Dictionary:
	var out := {}
	for t in score:
		var sub := String(Defs.B[t].get("sub", ""))
		if not out.has(sub):
			out[sub] = []
		(out[sub] as Array).append(int(score[t]))
	for sub in out:
		(out[sub] as Array).sort()
		(out[sub] as Array).reverse()
	return out


## На сколько вырастет счастье дома от лавок, если новая лавка t (бонус b) начнёт его снабжать: по старым правилам —
## целиком, в новой игре (econ) — как в shop_parts: внутри вида первая целиком, вторая вполовину, дальше четверть.
## subs — _shop_subs(score) этого дома
func _shop_gain(subs: Dictionary, t: String, b: int) -> int:
	if econ < 1:
		return b
	var vs: Array = subs.get(String(Defs.B[t].get("sub", "")), [])
	if vs.is_empty():
		return b
	var before := 0
	var after := 0
	var j := 0                          # место в ряду вместе с новой лавкой
	var put := false
	for i in vs.size():
		var v := int(vs[i])
		before += _rep_part(v, i)
		if not put and b > v:
			after += _rep_part(b, j)
			j += 1
			put = true
		after += _rep_part(v, j)
		j += 1
	if not put:
		after += _rep_part(b, j)
	return after - before


## Доля k-й (с нуля) лавки одного вида у дома (Defs.SHOP_REPEAT, как в shop_parts)
static func _rep_part(v: int, k: int) -> int:
	return v if k == 0 else roundi(v * float(Defs.SHOP_REPEAT[mini(k, Defs.SHOP_REPEAT.size() - 1)]))


static func plural(n: int, one: String, few: String, many: String) -> String:
	var m := n % 100
	if m >= 11 and m <= 14:
		return many
	match n % 10:
		1: return one
		2, 3, 4: return few
	return many


## 1–3 короткие подсказки, что сильнее всего поднимет счастье города (для советника и окна счастья).
## Польза каждой — сколько процентов прибавит в среднем на жителя; берём самые полезные.
func _happy_tips(houses: Array, stores: Array) -> Array:
	if houses.is_empty():
		return []
	var ws := {}
	var tot := 0.0
	for h in houses:
		ws[h["id"]] = float(int(h["pop"]))
		tot += float(int(h["pop"]))
	var nobody := tot <= 0.0             # в городе ещё никто не живёт (первая семья не заселена)
	if nobody:
		for h in houses:
			ws[h["id"]] = 1.0
		tot = float(houses.size())
	var cands := []                     # [польза, текст]
	# нужные виды лавок, которых нет рядом с домами
	for n in Defs.NEED_ORDER:
		var w := 0.0
		var cnt := 0
		for h in houses:
			if n in h["missing"] and float(ws[h["id"]]) > 0.0:     # только дома, где живут
				w += float(ws[h["id"]])
				cnt += 1
		if cnt == 0:
			continue
		var open := false
		for t in Defs.B:
			if Defs.B[t]["kind"] == "shop" and Defs.B[t].get("sub", "") == n and unlocked(t):
				open = true
				break
		var nm: String = Defs.NEEDS[n]["name"]
		var g_need := Defs.MISSING_PENALTY * w / tot + 4.0
		# лавка этого вида уже стоит рядом, но не работает или не успевает ко всем — сказать почему
		# (а не «поставьте ещё одну»: при нехватке работников новая лавка сделает только хуже)
		var iss := _need_shop_issue(n, houses, ws)
		if not iss.is_empty():
			var sb: Dictionary = iss["b"]
			var sn: String = def(sb)["name"]
			var k := int(iss["cnt"])
			if iss["idle"]:
				var g := g_need
				if nobody and String(sb.get("why", "")) == "staff":
					g = 1.0                     # пустой город: заработает сама с первыми жителями
				cands.append([g, "«%s» рядом с %d %s не работает: %s" % [sn, k, plural(k, "домом", "домами", "домами"), idle_text(sb)]])
			elif float(sb.get("fill", 1.0)) < 0.99:
				pass                            # не успевает из-за нехватки работников — об этом совет про работников ниже
			elif hired_of(sb) < job_max(sb):
				cands.append([g_need, "«%s» не успевает ко всем домам рядом — наймите работника кнопкой «+» в карточке постройки" % sn])
			else:
				cands.append([g_need, "«%s» не успевает ко всем домам рядом — поставьте ещё одну лавку «%s» (+%d%%)" % [sn, nm, Defs.MISSING_PENALTY]])
		elif open:
			cands.append([g_need, "У %d %s нет рядом лавки «%s» — поставьте её поближе (+%d%%)" % [cnt, plural(cnt, "дома", "домов", "домов"), nm, Defs.MISSING_PENALTY]])
		else:
			cands.append([Defs.MISSING_PENALTY * w / tot + 2.0, "Изучите лавку вида «%s» — её не хватает %d %s" % [nm, cnt, plural(cnt, "дому", "домам", "домам")]])
	# новая лавка, которой у домов ещё нет (разнообразие); в новой игре — сколько она правда прибавит с повторами
	var subs := {}
	if econ >= 1:
		for h in houses:
			subs[h["id"]] = _shop_subs(h["score"])
	var best := [0.0, ""]
	for t in Defs.B:
		var d: Dictionary = Defs.B[t]
		if d["kind"] != "shop" or not unlocked(t):
			continue
		if d.get("store", false) and stores.is_empty():
			continue
		if d.has("needs_good") and not goods.has(d["needs_good"]):
			continue
		if not _staffable(d) or _workers_short(d):
			continue                            # работать в ней некому (или и так не хватает) — стояла бы пустой
		if nobody:
			continue                            # пока никто не живёт, разнообразие не к спеху
		var w := 0.0
		var gs := 0.0                           # прибавка, взвешенная по жителям
		for h in houses:
			if not (h["score"] as Dictionary).has(t):
				var hw := float(ws[h["id"]])
				w += hw
				gs += (float(_shop_gain(subs[h["id"]], t, int(d["bonus"]))) if econ >= 1 else float(d["bonus"])) * hw
		var g := gs / tot
		if g > float(best[0]):
			var pct := int(d["bonus"]) if econ < 1 or w <= 0.0 else int(roundf(gs / w))
			best = [g, "Новая лавка у домов: «%s» — +%d%% каждому дому рядом" % [d["name"], pct]]
	if float(best[0]) >= 1.0:
		cands.append(best)
	# исследование новой лавки (если готовые уже стоят)
	var rb := [0.0, ""]
	for r in Defs.RESEARCH:
		if research.has(r["id"]) or int(r["lvl"]) > level or (r.has("after") and not research.has(r["after"])):
			continue
		for t in Defs.B:
			var d: Dictionary = Defs.B[t]
			if d["kind"] == "shop" and d.get("unlock", "") == r["id"] and _staffable(d):
				var avg := float(d["bonus"])
				if econ >= 1:
					# новая игра: средняя настоящая прибавка домам, где живут (у кого уже есть лавка того же вида — меньше)
					var sg := 0.0
					for h in houses:
						sg += float(_shop_gain(subs[h["id"]], t, int(d["bonus"]))) * float(ws[h["id"]])
					avg = sg / tot
				var g := avg * 0.4 - float(r["cost"]) * 0.001
				if g > float(rb[0]):
					rb = [g, "Изучите «%s» — новая лавка даст домам ещё +%d%%" % [r["name"], int(roundf(avg))]]
	if float(rb[0]) > 0.0:
		cands.append(rb)
	# украшения
	var dw := 0.0
	for h in houses:
		dw += float(int(Defs.CLASSES[def(h)["cls"]].get("deco_max", 12)) - int(h["deco_bonus"])) * float(ws[h["id"]])
	dw /= tot
	if dw >= 2.0:
		cands.append([dw * 0.9, "Украшения между домами: можно добавить ещё до +%d%%" % int(roundf(dw))])
	# памятники (фонтан, храм…)
	var mb := [0.0, ""]
	for t in Defs.B:
		var d: Dictionary = Defs.B[t]
		if d["kind"] != "monument" or not unlocked(t) or not _staffable(d) or _workers_short(d):
			continue
		var w := 0.0
		for h in houses:
			if not (h.get("mon_types", {}) as Dictionary).has(t):
				w += float(ws[h["id"]])
		var g := float(d["bonus"]) * w / tot * 0.7
		if g > float(mb[0]):
			mb = [g, "«%s» среди домов: +%d%% всем вокруг" % [d["name"], int(d["bonus"])]]
	if float(mb[0]) >= 1.0:
		cands.append(mb)
	# теснота
	var cw := 0.0
	for h in houses:
		cw += float(h["density"]) * float(ws[h["id"]])
	cw /= tot
	if cw <= -2.0:
		cands.append([-cw, "Дома стоят слишком тесно (%d%%) — оставляйте между ними место" % int(roundf(cw))])
	# работники: лавка уже стоит у домов, но людей на её местах не хватает — и она обслуживает меньше домов,
	# чем могла бы. Польза — счастье, которое эти дома недополучают (а не просто «мест больше, чем людей»)
	if not nobody:
		var lost := 0.0
		var worst := {}
		var worst_g := 0.0
		for id in buildings:
			var s: Dictionary = buildings[id]
			var d := def(s)
			if d["kind"] != "shop" or not s.get("active", false) or float(s.get("fill", 1.0)) >= 0.99:
				continue
			var full := int(Defs.CAPACITY[int(d["cap"])])
			var extra := full - int(s.get("cap", full))
			if extra <= 0 or int(s.get("served", 0)) < int(s.get("cap", 0)):
				continue                        # и с нынешними работниками успевает ко всем
			var r := shop_range(d)
			var near := []
			for h in houses:
				var dd := (h["pos"] as Vector2).distance_to(s["pos"])
				if dd <= r and float(ws[h["id"]]) > 0.0 and int((h["score"] as Dictionary).get(s["type"], 0)) < int(d["bonus"]):
					near.append([dd, h])
			near.sort_custom(func(a, b): return a[0] < b[0])
			var g := 0.0
			for k in mini(extra, near.size()):
				g += float(d["bonus"]) * float(ws[(near[k][1] as Dictionary)["id"]]) / tot
			lost += g
			if g > worst_g:
				worst_g = g
				worst = s
		if lost >= 1.0 and not worst.is_empty():
			# место можно забрать без вреда счастью у скриптория или школы (они дают только очки исследований)
			var cls_need := ""
			for c in def(worst).get("jobs", {}):
				cls_need = c
			var spare_at := ""
			for id in buildings:
				var o: Dictionary = buildings[id]
				if def(o)["kind"] == "rp" and not o.get("over", false) and int(jobs_of(o).get(cls_need, 0)) > 0:
					spare_at = def(o)["name"]
					break
			var txt := "Не хватает работников: «%s» обслуживает меньше домов, чем может. Заселите ещё семьи" % def(worst)["name"]
			if spare_at != "":
				txt += " — или уберите одно место у «%s» кнопкой «−» в карточке постройки" % spare_at
			cands.append([lost, txt])
	cands.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
	var out := []
	for c in cands:
		if float(c[0]) >= 1.0 and out.size() < 3:
			out.append(c[1])
	return out


## Дальность лавки (еда — дальше после исследования «reach1»), как в compute()
func shop_range(d: Dictionary) -> float:
	var r := Defs.range_m(d)
	if d.get("sub", "") == "food" and research.has("reach1"):
		r *= 1.33
	return r


## Есть ли кому работать в постройке: на каждое её место нужен житель этого класса или выше
## (высшие подменяют низших, не наоборот). Пустой город — первыми приедут плебеи
func _staffable(d: Dictionary) -> bool:
	var res: Dictionary = stats.get("residents", {})
	var total := 0
	for c in res:
		total += int(res[c])
	var jb: Dictionary = d.get("jobs", {})
	for c in jb:
		if int(jb[c]) <= 0:
			continue
		var i := Defs.CLASS_ORDER.find(c)
		var have := 0
		for k in range(maxi(0, i), Defs.CLASS_ORDER.size()):
			have += int(res.get(Defs.CLASS_ORDER[k], 0))
		if have == 0 and not (total == 0 and i == 0):
			return false
	return true


## На места этой постройки уже сейчас не хватает людей (в её классе работников меньше, чем мест):
## новая такая постройка только растащит работников у тех, что стоят
func _workers_short(d: Dictionary) -> bool:
	var ratio: Dictionary = stats.get("ratio", {})
	for c in d.get("jobs", {}):
		if int(d["jobs"][c]) > 0 and float(ratio.get(c, 1.0)) < 0.99:
			return true
	return false


## Лавка вида n стоит рядом с домами, где этой нужды нет: не работает или уже обслуживает всех, кого может.
## {b, cnt (сколько таких домов в её дальности), idle} или {} — тогда лавки рядом просто нет
func _need_shop_issue(n: String, houses: Array, ws: Dictionary) -> Dictionary:
	var best := {}
	var best_key := -1
	for id in buildings:
		var s: Dictionary = buildings[id]
		var d := def(s)
		if d["kind"] != "shop" or d.get("sub", "") != n:
			continue
		var idle := not bool(s.get("active", true))
		if not idle and int(s.get("served", 0)) < int(s.get("cap", 0)):
			continue                    # работает и силы ещё есть — эти дома просто вне её дальности
		var r := shop_range(d)
		var cnt := 0
		for h in houses:
			if n in h["missing"] and float(ws.get(h["id"], 0.0)) > 0.0 and (h["pos"] as Vector2).distance_to(s["pos"]) <= r:
				cnt += 1
		if cnt == 0:
			continue
		var key := cnt + (1000 if idle else 0)     # неработающая важнее переполненной
		if key > best_key:
			best_key = key
			best = {"b": s, "cnt": cnt, "idle": idle}
	return best


## Почему лавка не работает — коротко, со строчной буквы (для советов и карточки дома)
func idle_text(b: Dictionary) -> String:
	var d := def(b)
	if b.get("over", false):
		return "сверх предела уровня — не работает"
	match String(b.get("why", "")):
		"road":
			return "нет дороги у входа"
		"store":
			return "нет склада рядом — нечем торговать"
		"good":
			for t in Defs.B:
				if Defs.B[t].get("makes", "") == d.get("needs_good", "-"):
					return "нет сырья — нужно «%s»" % Defs.B[t]["name"]
			return "нет сырья"
		"staff":
			if int(stats.get("pop", 0)) <= 0:
				return "заработает, когда заселятся жители"
			if not _staffable(d):
				var who := []
				for c in d.get("jobs", {}):
					who.append(String(Defs.CLASSES[c]["name"]).to_lower())
				return "работать некому — нужны %s" % ", ".join(who)
			if float(b.get("fill", 1.0)) < 0.99:
				return "не хватает работников — нужно больше жителей"
			return "мало работников — наймите кнопкой «+» в карточке постройки"
	return "не работает"


## Склад лавки (3.9): ближайший работающий в дальности {"b", "d" — м, "ok": true, "near": true}; в дальности только
## неработающий — он же с "ok": false; в дальности нет — ближайший любой ("near": false); складов нет — {}
func store_for(s: Dictionary) -> Dictionary:
	var r := float(Defs.RANGE[4]) * (2.0 if research.has("store1") else 1.0)
	var best := {}
	var idle := {}
	var any := {}
	for id in buildings:
		var w: Dictionary = buildings[id]
		if def(w)["kind"] != "store":
			continue
		var d := (w["pos"] as Vector2).distance_to(s["pos"])
		if d <= r:
			if bool(w.get("active", false)):
				if best.is_empty() or d < float(best["d"]):
					best = {"b": w, "d": d, "ok": true, "near": true}
			elif idle.is_empty() or d < float(idle["d"]):
				idle = {"b": w, "d": d, "ok": false, "near": true}
		if any.is_empty() or d < float(any["d"]):
			any = {"b": w, "d": d, "ok": false, "near": false}
	if not best.is_empty():
		return best
	return idle if not idle.is_empty() else any


func _store_near(s: Dictionary, stores: Array) -> bool:
	var r := float(Defs.RANGE[4]) * (2.0 if research.has("store1") else 1.0)
	for w in stores:
		if (w["pos"] as Vector2).distance_to(s["pos"]) <= r:
			return true
	return false


# ---------- час ----------

## Налог с жителя дома в час (до поправки на счастье): по классу, патриции — с «taxes1» на четверть больше
func house_tax(b: Dictionary) -> float:
	var cls: String = def(b)["cls"]
	var tax := float(Defs.CLASSES[cls]["tax"])
	if cls == "patricians" and research.has("taxes1"):
		tax *= 1.25
	return tax * float(Defs.TAX_SET[tax_of(cls)]["k"])


## Откуда очки исследований в час: {"post": почта на станции, тип постройки: сумма} (подсказка у счётчика свитков)
func rp_sources() -> Dictionary:
	var out := {}
	for id in buildings:
		var b: Dictionary = buildings[id]
		if def(b)["kind"] == "rp" and not b.get("over", false):
			out[b["type"]] = float(out.get(b["type"], 0.0)) + rp_per_hour(b["type"]) * float(b.get("staff", 0.0))
	if not center().is_empty():
		out["post"] = float(Defs.LEVELS[level].get("rp_h", 0.0))
	return out


## Налоги класса: 0 мягкие, 1 обычные, 2 высокие (Defs.TAX_SET)
func tax_of(cls: String) -> int:
	return clampi(int(taxes.get(cls, 1)), 0, Defs.TAX_SET.size() - 1)


## Налоги по классам можно менять: с «Деревни» (Defs.TAX_LVL)
func tax_open() -> bool:
	return level >= Defs.TAX_LVL


func set_tax(cls: String, v: int) -> void:
	if not Defs.CLASSES.has(cls):
		return
	v = clampi(v, 0, Defs.TAX_SET.size() - 1)
	if v == 1:
		taxes.erase(cls)
	else:
		taxes[cls] = v
	compute(true)
	changed.emit()


## Каким станет счастье города, если налоги класса cls будут v (окно «Финансы» — предупреждение до выбора).
## Без пересчёта города: налог — просто слагаемое счастья домов класса, прибавляем разницу к их счастью (как compute).
## Для «высоких» точно; неточно только для домов, уже упёршихся в 0%, при более мягких налогах
func happy_if_tax(cls: String, v: int) -> int:
	var was := tax_of(cls)
	if was == v:
		return int(stats.get("happy", 0))
	var dt := int(Defs.TAX_SET[v]["happy"]) - int(Defs.TAX_SET[was]["happy"])
	var s := 0.0
	var pop := 0
	for id in buildings:
		var h: Dictionary = buildings[id]
		var d := def(h)
		if d["kind"] != "house":
			continue
		var hp := int(h.get("happy", 0)) + (dt if String(d["cls"]) == cls else 0)
		s += clampf(float(hp), 0.0, 100.0) * int(h["pop"])
		pop += int(h["pop"])
	return roundi(s / pop) if pop > 0 else 0


## Движение денег вне часа налогов (история за сутки, этап 2.4): dv < 0 — потратили, > 0 — пришло. cat: build, fest,
## land, legion, reward (что не учтено ни здесь, ни налогами, — «прочее» в конце часа)
func flow(cat: String, dv: float) -> void:
	hist_acc[cat] = float(hist_acc.get(cat, 0.0)) + dv


## Конец игрового часа: строка истории — налоги, жалованье, содержание, траты по видам, «прочее» (чтобы сумма за сутки
## сходилась с казной), сколько не уместилось в казну, казна, жители, счастье
func _hist_hour(tax: float, wages: float, upk: float, lost: float) -> void:
	var row := []
	var known := 0                         # сумма уже округлённых видов (без «прочего»), минус то, что не уместилось
	for k: String in Defs.HIST_KEYS:
		var v := 0
		match k:
			"tax": v = roundi(tax)
			"wage": v = -roundi(wages)
			"upkeep": v = -roundi(upk)
			"lost": v = roundi(lost)
			"money": v = roundi(money)
			"pop": v = int(stats.get("pop", 0))
			"happy": v = int(stats.get("happy", 0))
			"other": v = 0
			_: v = roundi(float(hist_acc.get(k, 0.0)))
		if not (k in ["lost", "money", "pop", "happy", "other"]):
			known += v
		elif k == "lost":
			known -= v
		row.append(v)
	# «прочее» — чтобы строка точно сходилась с казной (дороги, истории…): за сутки сумма = изменение казны
	if not is_nan(hist_mark):
		row[Defs.HIST_KEYS.find("other")] = roundi(money) - roundi(hist_mark) - known
	hist.append(row)
	while hist.size() > Defs.HIST_N:
		hist.pop_front()
	hist_acc = {}
	hist_mark = money


## Сумма по виду за последние n часов истории (окно «Финансы»: «За сутки»)
func hist_sum(key: String, n := 24) -> int:
	var i := Defs.HIST_KEYS.find(key)
	var s := 0
	for row: Array in hist.slice(maxi(0, hist.size() - n)):
		if i < row.size():
			s += int(row[i])
	return s


## Ряд истории по виду (для искорки в «Финансах» и «Жителях»): последние n часов
func hist_series(key: String, n := 48) -> Array:
	var out := []
	var i := Defs.HIST_KEYS.find(key)
	for row: Array in hist.slice(maxi(0, hist.size() - n)):
		out.append(int(row[i]) if i < row.size() else 0)
	return out


## Раз в игровой час: налоги, очки исследований, рост домов, переселенцы, уровень города
func sim_day() -> void:
	compute(true)
	var income := 0.0
	var upkeep := 0.0
	var wages := 0.0
	var rpd := 0.0
	var gday := 0.0                               # Слава в день от лудуса, маяка, цирка (этап 5, glory_day)
	for id in buildings.keys():
		var b: Dictionary = buildings[id]
		var d := def(b)
		if d.has("glory_day") and bool(b.get("active", false)):
			gday += float(d["glory_day"])
		match d["kind"]:
			"house":
				income += int(b["pop"]) * house_tax(b) * (0.5 + minf(100.0, float(b["happy"])) / 100.0)
				_grow_house(b)
			"rp":
				if b.get("over", false):
					continue                              # сверх предела уровня: стоит, не работает, не стоит денег
				rpd += rp_per_hour(b["type"]) * float(b["staff"])
				upkeep += float(d["cost"]) * Defs.UPKEEP + wage() * hired_of(b)     # писцам и учителям тоже платят
				wages += wage() * hired_of(b)
			"shop", "monument", "store", "farm", "military":
				upkeep += float(d["cost"]) * Defs.UPKEEP + wage() * hired_of(b)
				wages += wage() * hired_of(b)
	if not center().is_empty():
		rpd += float(Defs.LEVELS[level].get("rp_h", 0.0))   # почта привозит на станцию свитки
	hour_n += 1
	if int(stories.get("tax_off", 0)) > 0:
		income = 0.0                              # Сатурналии, день отдыха: лавки закрыты — налогов нет (часы тают в _story_hour)
	# что пропало за час: казна и полки полны (значки «Казна полна», «Полки полны»)
	stats["money_lost"] = maxf(0.0, money + income - upkeep - money_cap()) if income > upkeep else 0.0
	stats["rp_lost"] = maxf(0.0, rp + rpd - maxf(rp, rp_cap()))
	money = minf(money_cap(), money + income - upkeep)
	rp = maxf(rp, minf(rp_cap(), rp + rpd))      # сверх полок (возврат очков) не срезаем — просто не копим дальше
	stats["income"] = income
	stats["upkeep"] = upkeep
	stats["wages"] = wages
	stats["rp_day"] = rpd
	if gday > 0.0:
		legion.glory_acc += gday / 24.0          # копится, как у чудес Легиона: набралась целая Слава — в казну Славы
		if legion.glory_acc >= 1.0:
			var gw := floorf(legion.glory_acc)
			legion.glory += gw
			legion.glory_acc -= gw
	for ev: Array in legion.on_hour():           # Легион: таймеры улучшений (настоящие часы), Слава чудес, триумф
		if ev.size() > 2 and bool(ev[2]):
			_quiet(ev[0], ev[1])                 # здание Легиона выросло — только в колокольчик
		else:
			_event(ev[0], ev[1])
	_fest_hour()
	_cat_shop_hour()
	_story_hour()
	_tick_arrivals()
	_update_level()
	_check_goals()
	if chron_on:
		Chronicle.check(self)                    # летопись: новые лавровые венки — по строке в колокольчик
	_hist_hour(income, wages, upkeep - wages, float(stats["money_lost"]))
	changed.emit()


## Час жизни дома. Сам дом больше не растёт: этаж покупает игрок (buy_floor), а несчастные семьи уезжают
func _grow_house(b: Dictionary) -> void:
	# несчастные уезжают
	if int(b["happy"]) < 25 and int(b["pop"]) > 0:
		b["down"] = int(b["down"]) + 1
		if int(b["down"]) >= 20:
			b["down"] = 0
			var fams: Array = b["families"]
			if not fams.is_empty():
				var f: Dictionary = fams.pop_back()
				b["pop"] = maxi(0, int(b["pop"]) - int(f["n"]))
				b.erase("_fam_" + str(f["name"]))
				_event("Семья %s уехала: им плохо живётся" % f["name"], "person")
				family_left.emit(b["id"], f["name"])
				house_changed.emit(b, false)
	else:
		b["down"] = 0


func _fam_name(b: Dictionary) -> String:
	var fams: Array = b["families"]
	return fams[0]["name"] if not fams.is_empty() else "без имени"


# ---------- этажи: покупает игрок инструментом «Этаж» (U) или в карточке дома (как в Town to City) ----------

## Цена следующего этажа (0 — надстраивать некуда)
func floor_price(b: Dictionary) -> int:
	if b.is_empty() or not is_house(b):
		return 0
	var cls: String = def(b)["cls"]
	var nx := int(b["tier"]) + 1
	if nx > Defs.floors_max(cls, int(b.get("variant", 0))):
		return 0
	return int((Defs.FLOOR_PRICE[cls] as Dictionary).get(nx, 0))


## С какого счастья дома можно надстроить следующий этаж
func floor_need(b: Dictionary) -> int:
	return int(Defs.FLOOR_HAPPY.get(int(b.get("tier", 1)) + 1, 100))


## "" — этаж можно купить; иначе — почему нельзя (для подсказки у кнопки и у курсора инструмента «Этаж»).
## check_money = false — дом готов, а хватит ли денариев, не смотрим (стрелка с красной ценой)
func can_buy_floor(b: Dictionary, check_money := true) -> String:
	if b.is_empty() or not buildings.has(b.get("id", -1)) or not is_house(b):
		return "Этаж можно надстроить только жилому дому"
	var h: Dictionary = buildings[b["id"]]
	var nx := int(h["tier"]) + 1
	var fmx := Defs.floors_max(def(h)["cls"], int(h.get("variant", 0)))
	if nx > fmx:
		return "Выше не строят: у «%s» не больше %d этажей" % [def(h)["name"], fmx]
	var rid: String = Defs.FLOOR_RESEARCH.get(nx, "")
	if rid != "" and not research.has(rid):
		return "Сначала изучите «%s»" % Defs.research(rid)["name"]
	# «дом полон» — когда в него не влезет ни одна семья его класса (семьи по 2–4 человека, и одно
	# свободное место у плебеев так и осталось бы пустым навсегда)
	var left := house_cap(h) - int(h["pop"]) - int(h.get("coming", 0))
	if int(h["pop"]) <= 0:
		return "Дом пока пустой — сначала заселите в него семью"
	if int(h.get("coming", 0)) > 0:
		return "Семья ещё идёт в этот дом — подождите, пока она заселится"
	if left >= int(Defs.FAMILY_SIZE[String(def(h)["cls"])][0]):
		return "В доме есть место ещё для семьи (%d %s) — сначала заселите её" % [left, plural(left, "место", "места", "мест")]
	if int(h["happy"]) < floor_need(h):
		return "Счастье дома %d%% — для %d-го этажа нужно от %d%%" % [clampi(int(h["happy"]), 0, 100), nx, floor_need(h)]
	if check_money and money < float(floor_price(h)):
		return "Не хватает денариев"
	return ""


## Дома, которым можно надстроить этаж прямо сейчас; check_money = false — и те, кому не хватает только денариев
func floor_ready(check_money := true) -> Array:
	var out := []
	for id in buildings:
		var b: Dictionary = buildings[id]
		if is_house(b) and can_buy_floor(b, check_money) == "":
			out.append(id)
	return out


## Купить этаж: деньги списываются, дом растёт, в него может въехать ещё семья.
## quiet — инструментом «Этаж»: без события на каждый дом, итог мазка — одной строкой в колокольчик (floors_done)
func buy_floor(b: Dictionary, quiet := false) -> bool:
	if can_buy_floor(b) != "":
		return false
	var h: Dictionary = buildings[b["id"]]
	money -= float(floor_price(h))
	flow("build", -float(floor_price(h)))
	h["tier"] = int(h["tier"]) + 1
	Chronicle.add(self, "floors")
	compute()
	house_changed.emit(h, true)
	if not quiet:
		_event("Дому семьи %s надстроили %d-й этаж — место ещё для %d жителей" % [_fam_name(h), int(h["tier"]), int(Defs.CLASSES[def(h)["cls"]]["per_floor"])], "housing")
	_check_goals()
	changed.emit()
	return true


## Мазок инструмента «Этаж» окончен: одна запись в колокольчик (без всплывашки) — сколько этажей, кому и за сколько
func floors_done(ids: Array, spent: int) -> void:
	if ids.is_empty():
		return
	var names := []
	var room := 0
	for id in ids:
		if buildings.has(id):
			var h: Dictionary = buildings[id]
			names.append(_fam_name(h))
			room += int(Defs.CLASSES[def(h)["cls"]]["per_floor"])
	if ids.size() == 1 and buildings.has(ids[0]):
		_quiet("Дому семьи %s надстроили %d-й этаж за %d ден. — место ещё для %d жителей" % [names[0], int(buildings[ids[0]]["tier"]), spent, room], "housing")
		return
	var who := ", ".join(names.slice(0, 3)) + (" и ещё %d" % (names.size() - 3) if names.size() > 3 else "")
	_quiet("Надстроили %d %s за %d ден. (дома семей %s) — место ещё для %d жителей" % [ids.size(), plural(ids.size(), "этаж", "этажа", "этажей"), spent, who, room], "housing")


# ---------- «Перестроить» (Shift+U, Д12): дом в следующий класс — только щелчком игрока, как в Town to City ----------

var _upg_ready = null                  # готовые к перестройке (без денариев) — до следующего compute

## Тип дома следующего класса ("" — выше некуда)
func upgrade_to(b: Dictionary) -> String:
	return String(Defs.UPGRADE_NEXT.get(String(b.get("type", "")), "")) if not b.is_empty() else ""


## Облик после перестройки: дом ремесленников — тем же номером фасада, домус — городской (в коробке дома ремесленников)
func upgrade_variant(b: Dictionary) -> int:
	if upgrade_to(b) == "house_patrician":
		return Defs.PAT_TOWN + int(b.get("variant", 0)) % Defs.PAT_TOWN_N
	return int(b.get("variant", 0)) % int(Defs.B["house_artisan"]["variants"])


## Этажей после перестройки: столько же, сколько было (не выше, чем строят у нового облика)
func upgrade_tier(b: Dictionary) -> int:
	var nt := upgrade_to(b)
	if nt == "":
		return int(b.get("tier", 1))
	return mini(int(b["tier"]), Defs.floors_max(String(Defs.B[nt]["cls"]), upgrade_variant(b)))


## Цена перестройки (0 — нельзя): по классу и этажам дома сейчас
func upgrade_price(b: Dictionary) -> int:
	if upgrade_to(b) == "":
		return 0
	return int((Defs.UPGRADE_PRICE.get(String(def(b)["cls"]), {}) as Dictionary).get(int(b["tier"]), 0))


## Счастье, какое было бы в доме, живи в нём следующий класс: те же лавки, украшения, памятники и истории (без потолка —
## «запас» выше 100% идёт в счёт), но основа, предел украшений, налоги и нужды — нового класса (план 6.6, D-e)
func upgrade_happy(b: Dictionary) -> int:
	var nt := upgrade_to(b)
	if nt == "":
		return 0
	var c0: Dictionary = Defs.CLASSES[String(def(b)["cls"])]
	var cl1 := String(Defs.B[nt]["cls"])
	var c1: Dictionary = Defs.CLASSES[cl1]
	var raw := 0
	for p: Array in b.get("happy_parts", []):
		raw += int(p[1])
	var deco1 := mini(int(c1.get("deco_max", 12)), int(floor(float(b.get("deco", 0.0)) * Defs.DECO_RATE)))
	var tx0 := int(Defs.TAX_SET[tax_of(String(def(b)["cls"]))]["happy"])
	var tx1 := int(Defs.TAX_SET[tax_of(cl1)]["happy"])
	var miss1 := 0
	for n in c1["needs"]:
		if not (b.get("needs", {}) as Dictionary).has(n):
			miss1 += 1
	var miss0 := (b.get("missing", []) as Array).size()
	return raw - int(c0.get("base", 40)) + int(c1.get("base", 40)) - int(b.get("deco_bonus", 0)) + deco1 - tx0 + tx1 \
		+ (miss0 - miss1) * Defs.MISSING_PENALTY


## Счастье после перестройки, если украшений ids не станет («Сносить мешающие украшения»): их очки, наборы и «главные»
## украшения — не в счёт (как посчитал бы compute без них)
func upgrade_happy_without(b: Dictionary, ids: Array) -> int:
	var hp := upgrade_happy(b)
	if ids.is_empty() or upgrade_to(b) == "":
		return hp
	var dmax := int(Defs.CLASSES[String(Defs.B[upgrade_to(b)]["cls"])].get("deco_max", 12))
	var near := [[], []]                       # 0 — как сейчас, 1 — без снесённых
	var sets := [{}, {}]
	var mon := [{}, {}]
	for id in buildings:
		var o: Dictionary = buildings[id]
		var d := def(o)
		if String(d["kind"]) != "decor":
			continue
		var dist := (b["pos"] as Vector2).distance_to(o["pos"])
		var bk := Defs.base_of(o["type"])
		var sk := Defs.set_of(o["type"]) if econ >= 1 else ""
		for k in (1 if ids.has(id) else 2):
			if dist <= Defs.DECOR_RADIUS:
				(near[k] as Array).append([bk, float(d.get("deco", 1))])
				if sk != "":
					if not (sets[k] as Dictionary).has(sk):
						sets[k][sk] = {}
					sets[k][sk][bk] = true
			if d.has("mon") and dist <= Defs.range_m(d):
				mon[k][o["type"]] = maxi(int((mon[k] as Dictionary).get(o["type"], 0)), int(d["mon"]))
	var sc := [0, 0]
	for k in 2:
		sc[k] = mini(dmax, int(floor(float(deco_points(near[k], econ)[0]) * Defs.DECO_RATE))) + set_bonus(sets[k], [])
		for t in mon[k]:
			sc[k] += int(mon[k][t])
	return hp - (int(sc[0]) - int(sc[1]))


## Нужды следующего класса, которых у дома нет: ["одежда", "развлечения"]
func upgrade_missing(b: Dictionary) -> Array:
	var out := []
	var nt := upgrade_to(b)
	if nt == "":
		return out
	for n in Defs.CLASSES[String(Defs.B[nt]["cls"])]["needs"]:
		if not (b.get("needs", {}) as Dictionary).has(n):
			out.append(String(Defs.NEEDS[n]["name"]).to_lower())
	return out


var _upg_cells := {}                   # id дома → [облик и место, клетки нового облика]: след модели не считать заново
var _upg_fit := {}                     # id дома → [облик, место и счётчики правок, итог upgrade_place]
var place_gen := 0                     # правки построек (поставили, снесли, перестроили, пересчёт после действия игрока)

## Клетки нового облика дома (из запаса, пока облик и место те же)
func _upgrade_cells(b: Dictionary) -> PackedInt32Array:
	var nt := upgrade_to(b)
	var nv := upgrade_variant(b)
	var col := int(b.get("color", 0))
	var key := "%s:%d:%d:%s:%s" % [nt, nv, col, b["pos"], b["yaw"]]
	var e: Array = _upg_cells.get(int(b["id"]), [])
	if e.size() == 2 and String(e[0]) == key:
		return e[1]
	var cells := land.footprint_cells(Catalog.make(nt, 1, nv, col).footprint(), b["pos"], float(b["yaw"]))
	_upg_cells[int(b["id"])] = [key, cells]
	return cells


## Встанет ли новый облик на место дома: {err, cells, y} (свои клетки не в счёт; дверь — там же, у той же дороги).
## Новые клетки (двор, садик позади) — по правилам постановки игрока (_upgrade_rules)
func upgrade_place(b: Dictionary) -> Dictionary:
	# итог — из запаса, пока ни постройки, ни земля не менялись (часовой пересчёт города место не трогает)
	var nt := upgrade_to(b)
	var key := "%s:%d:%d:%s:%s:%d:%d:%s" % [nt, upgrade_variant(b), int(b.get("color", 0)), b["pos"], b["yaw"], place_gen, land.gen, unlocked(nt)]
	var e: Array = _upg_fit.get(int(b["id"]), [])
	if e.size() == 2 and String(e[0]) == key:
		return e[1]
	var res := check_place(nt, b["pos"], float(b["yaw"]), upgrade_variant(b), int(b.get("color", 0)), int(b["id"]), _upgrade_cells(b))
	if String(res["err"]) == "":
		res["err"] = _upgrade_rules(b, res["cells"])
	_upg_fit[int(b["id"])] = [key, res]
	return res


## Новые клетки перестройки — как постановка игрока (game._free_checks): не на большую дорогу к станции, вход соседа
## не загородить (ни его крыльцо, ни всю мостовую у его двери), мостовая под двором — почти ровная. "" — можно
func _upgrade_rules(h: Dictionary, cells: PackedInt32Array) -> String:
	var old := {}
	for k in (h["cells"] as PackedInt32Array):
		old[k] = true
	var mine := {}
	var paved := 0
	var lo := float(h["y"])
	var hi := lo
	for k in cells:
		if old.has(k):
			continue
		mine[k] = true
		if Land.walk_kind(land.base_kind[k]):
			return "За домом большая дорога — по ней ездят повозки"
		if Land.walk_kind(land.kind[k]):
			paved += 1
			lo = minf(lo, land.hq(k))
			hi = maxf(hi, land.hq(k))
	if mine.is_empty():
		return ""
	if paved * 2 >= mine.size() and hi - lo > PAVE_SLOPE:
		return "Мостовая за домом слишком наклонная"
	var col := int(h.get("color", 0))
	var rects: Array = Catalog.make(upgrade_to(h), 1, upgrade_variant(h), col).footprint()
	var rects0: Array = Catalog.make(String(h["type"]), 1, int(h.get("variant", 0)), col).footprint()
	var hp: Vector2 = h["pos"]
	var ax := axis(float(h["yaw"]))
	var f := facing(float(h["yaw"]))
	for id in buildings:
		if id == h["id"]:
			continue
		var o: Dictionary = buildings[id]
		if (o["pos"] as Vector2).distance_squared_to(hp) > 225.0:
			continue
		var od := def(o)
		if od["kind"] == "decor" or od["kind"] == "farm":
			continue
		var odp := door_point(o)
		var rel := odp - hp
		var lp := Vector2(rel.dot(ax), rel.dot(f))
		if not _in_rects(rects, lp, 1.9):
			continue                               # вход далеко от нового облика — ему не мешает
		if _in_rects(rects, lp, 0.4) and not _in_rects(rects0, lp, 0.4):
			return "Так загородится вход соседней постройки"
		# сосед у дороги, а новый двор закроет ему всю мостовую у входа
		if od["kind"] != "center" and bool(o.get("road", false)) and not _road_free_near_excl(odp, 1.7, mine) \
				and _road_free_near_excl(odp, 1.7, {}):
			return "Так загородится вход соседней постройки"
	return ""


static func _in_rects(rects: Array, p: Vector2, grow: float) -> bool:
	for r: Rect2 in rects:
		if r.grow(grow).has_point(p):
			return true
	return false


## Есть ли свободная мостовая (не под постройкой и не среди клеток excl) ближе r к точке
func _road_free_near_excl(p: Vector2, r: float, excl: Dictionary) -> bool:
	var c := land.cell(p)
	var rc := int(ceil(r / Land.CELL))
	for j in range(c.y - rc, c.y + rc + 1):
		for i in range(c.x - rc, c.x + rc + 1):
			if not land.inside(i, j):
				continue
			var k := land.idx(i, j)
			if Land.walk_kind(land.kind[k]) and land.occ[k] == 0 and not excl.has(k) and land.cell_center(i, j).distance_to(p) <= r:
				return true
	return false


## Что мешает новому облику встать (для подсказки): «дом за ним», «Фонтан» — постройка на нужных клетках
func _upgrade_blocker(b: Dictionary) -> String:
	for k in _upgrade_cells(b):
		var o := land.occ[k]
		if o < 0:
			return "арка у въезда"
		if o != 0 and o != int(b["id"]) and buildings.has(o):
			var ob: Dictionary = buildings[o]
			return "дом за ним" if is_house(ob) else "«%s»" % String(def(ob)["name"])
	return ""


## Украшения, которые одни мешают новому облику (их можно снести за возврат, как в Town to City); [] — мешает
## что-то другое (дом, лавка, арка) или ничего
func upgrade_decor_blockers(b: Dictionary) -> Array:
	var ids := []
	for k in _upgrade_cells(b):
		var o := land.occ[k]
		if o < 0:
			return []
		if o != 0 and o != int(b["id"]) and buildings.has(o):
			if String(def(buildings[o])["kind"]) != "decor":
				return []
			if not ids.has(o):
				ids.append(o)
	return ids


var _upg_clear := {}                   # id дома → [облик, место и счётчики правок, итог upgrade_room_clearing]

## «Сносить мешающие украшения» (как в Town to City): встанет ли новый облик, если убрать украшения позади ("" — да).
## Как upgrade_place, но клетки этих украшений на миг считаются свободными; итог — из запаса, пока ничего не менялось
func upgrade_room_clearing(b: Dictionary) -> String:
	var dec := upgrade_decor_blockers(b)
	if dec.is_empty():
		return upgrade_room(b)
	var nt := upgrade_to(b)
	var key := "%s:%d:%d:%s:%s:%d:%d" % [nt, upgrade_variant(b), int(b.get("color", 0)), b["pos"], b["yaw"], place_gen, land.gen]
	var e: Array = _upg_clear.get(int(b["id"]), [])
	if e.size() == 2 and String(e[0]) == key:
		return e[1]
	var keep := {}
	for id in dec:
		for k in (buildings[id]["cells"] as PackedInt32Array):
			if land.occ[k] == int(id):
				keep[k] = int(id)
				land.occ[k] = 0
	var res := check_place(nt, b["pos"], float(b["yaw"]), upgrade_variant(b), int(b.get("color", 0)), int(b["id"]), _upgrade_cells(b))
	var err := String(res["err"])
	if err == "":
		err = _upgrade_rules(b, res["cells"])
	for k in keep:
		land.occ[k] = keep[k]
	if err != "":
		err = "Не помещается и без украшений: " + err.to_lower()
	_upg_clear[int(b["id"])] = [key, err]
	return err


## Сколько вернётся за украшения, мешающие перестройке (половина цены, как при сносе)
func upgrade_decor_refund(b: Dictionary) -> int:
	var back := 0.0
	for id in upgrade_decor_blockers(b):
		back += float(def(buildings[id])["cost"]) * Defs.REFUND
	return int(back)


## Как can_upgrade, но украшения позади дома не помеха — их снесут за возврат ("" — можно перестроить так)
func can_upgrade_clearing(b: Dictionary, check_money := true) -> String:
	var err := can_upgrade(b, false)
	if err == "":
		return can_upgrade(b, check_money)
	if upgrade_decor_blockers(b).is_empty() or err != upgrade_room(b):
		return err                                 # мешает не место позади (нужды, счастье, дом за ним)
	var e2 := upgrade_room_clearing(b)
	if e2 != "":
		return e2
	# украшения позади радуют и этот дом: без них счастье может не дотянуть — тогда и сносить нечего
	var need := int(Defs.UPGRADE_HAPPY.get(String(Defs.B[upgrade_to(b)]["cls"]), 65))
	var hp := upgrade_happy_without(b, upgrade_decor_blockers(b))
	if hp < need:
		return "Без украшений позади счастье после перестройки было бы %d%% — нужно от %d%%" % [clampi(hp, 0, 100), need]
	if check_money and money + float(upgrade_decor_refund(b)) < float(upgrade_price(b)):
		return "Не хватает денариев"
	return ""


## Перестроить, снеся мешающие украшения (деньги за них вернутся, как при сносе). Сначала — на пробу, без сноса:
## не выйдет и без них — украшения остаются, ничего не списано
func upgrade_clearing(b: Dictionary, quiet := false) -> bool:
	if can_upgrade_clearing(b) != "":
		return false
	if can_upgrade(b) == "":
		return upgrade_house(b, quiet)
	var dec := upgrade_decor_blockers(b)
	if not _upgrade_try_without(b, dec):
		return false
	for id in dec:
		if buildings.has(id):
			remove(buildings[id], true, true)
	compute()
	return upgrade_house(b, quiet)


## На пробу: готов ли дом к перестройке (без денариев), если украшений ids не станет — их будто нет, город пересчитан;
## потом всё как было (без сигналов: ни модели, ни жители не трогаются)
func _upgrade_try_without(b: Dictionary, ids: Array) -> bool:
	var keep := {}
	var occ := {}
	for id in ids:
		if not buildings.has(id):
			continue
		keep[id] = buildings[id]
		for k in (buildings[id]["cells"] as PackedInt32Array):
			if land.occ[k] == int(id):
				occ[k] = int(id)
				land.occ[k] = 0
		buildings.erase(id)
	compute()
	var err := can_upgrade(b, false)
	for id in keep:
		buildings[id] = keep[id]
	for k in occ:
		land.occ[k] = occ[k]
	compute()
	return err == ""


## Место для нового облика: "" — помещается; иначе — почему нет (подпись у курсора, кнопка и галочка в карточке)
func upgrade_room(b: Dictionary) -> String:
	var err := String(upgrade_place(b)["err"])
	if err == "":
		return ""
	if err == "Место занято":
		var who := _upgrade_blocker(b)
		return "Не помещается: %s дому нужно больше места сзади%s" % [{"artisans": "новому", "patricians": "городскому"}.get(String(Defs.B[upgrade_to(b)]["cls"]), ""),
			(" — мешает " + who) if who != "" else ""]
	return "Не помещается: " + err.to_lower()


## "" — дом можно перестроить; иначе — почему нельзя (подпись у курсора, кнопка в карточке).
## check_money = false — готов, а хватит ли денариев, не смотрим (стрелка с красной ценой)
func can_upgrade(b: Dictionary, check_money := true) -> String:
	if b.is_empty() or not buildings.has(b.get("id", -1)) or not is_house(b):
		return "Перестроить можно только жилой дом"
	var h: Dictionary = buildings[b["id"]]
	var nt := upgrade_to(h)
	if nt == "":
		return "Это уже домус патрициев — выше класса нет"
	var nd: Dictionary = Defs.B[nt]
	var cl1 := String(nd["cls"])
	if not unlocked(nt):
		return "Сначала изучите «%s»" % Defs.research(String(nd.get("unlock", "")))["name"]
	if int(h["pop"]) <= 0:
		return "Дом пока пустой — перестраивают дом, где уже живут"
	if int(h.get("coming", 0)) > 0:
		return "Семья ещё идёт в этот дом — подождите, пока она заселится"
	var miss := upgrade_missing(h)
	if not miss.is_empty():
		return "%s нужны ещё: %s — поставьте лавки рядом" % [{"artisans": "Ремесленникам", "patricians": "Патрициям"}.get(cl1, ""), ", ".join(miss)]
	var need := int(Defs.UPGRADE_HAPPY.get(cl1, 65))
	var hp := upgrade_happy(h)
	if hp < need:
		return "Счастье после перестройки было бы %d%% — нужно от %d%% (украшения и лавки рядом его поднимут)" % [clampi(hp, 0, 100), need]
	var room := upgrade_room(h)
	if room != "":
		return room
	if check_money and money < float(upgrade_price(h)):
		return "Не хватает денариев"
	return ""


## Дома, которые можно перестроить прямо сейчас; check_money = false — и те, кому не хватает только денариев.
## Список без денариев считается раз на пересчёт города (compute сбрасывает): кнопка с числом и стрелки — без пересчёта мест
func upgrade_ready(check_money := true) -> Array:
	if _upg_ready == null:
		var all := []
		for id in buildings:
			var b: Dictionary = buildings[id]
			if is_house(b) and upgrade_to(b) != "" and can_upgrade(b, false) == "":
				all.append(id)
		_upg_ready = all
	var live := (_upg_ready as Array).filter(func(id): return buildings.has(id))     # снесли без пересчёта — не в счёт
	if not check_money:
		return live
	return live.filter(func(id): return money >= float(upgrade_price(buildings[id])))


## Перестроить дом: деньги списываются, дом тот же (номер, семьи, цвет, этажи — сколько влезет), класс — следующий.
## Семьи остаются и становятся этим классом; мест меньше, чем жильцов, — «тесновато», никого не выселяют (Q9).
## quiet — инструментом «Перестроить»: итог мазка — одной строкой в колокольчик (upgrades_done)
func upgrade_house(b: Dictionary, quiet := false) -> bool:
	if can_upgrade(b) != "":
		return false
	var h: Dictionary = buildings[b["id"]]
	var price := upgrade_price(h)
	var chk := upgrade_place(h)
	var nt := upgrade_to(h)
	var nv := upgrade_variant(h)
	var nf := upgrade_tier(h)
	money -= float(price)
	flow("build", -float(price))
	_apron_remove(h)
	var old: PackedInt32Array = h["cells"]
	for k in old:
		if land.occ[k] == int(h["id"]):
			land.occ[k] = 0
	h["type"] = nt
	h["variant"] = nv
	h["tier"] = nf
	Chronicle.add(self, "upg")
	h["cells"] = (chk["cells"] as PackedInt32Array).duplicate()     # свой список: запас следов (_upg_cells) не делим
	var cells: PackedInt32Array = h["cells"]
	land.flatten_cells(cells, h["y"])          # высота дома прежняя: двор позади подравнивается к ней
	land.blend_ring(cells, h["y"], 8)
	for k in cells:
		if land.occ[k] >= 0:
			land.occ[k] = h["id"]
	_apron_add(h)
	if apron_of(h) == 2:
		land.wear_block[int(h["id"])] = true
		_apron_refresh(h)
	compute()
	h["_upg"] = true                           # game: леса и рабочие, жители — в новом классе
	h["_old_cells"] = old                      # game → People: сетка ходьбы и под прежним обликом
	house_changed.emit(h, true)
	h.erase("_upg")
	h.erase("_old_cells")
	if not quiet:
		# только в колокольчик (без всплывашки): перестроили сами, щелчком в карточке
		_quiet("Дом семьи %s перестроили: теперь это %s" % [_fam_name(h), String(Defs.B[nt]["name"]).to_lower()], String(Defs.CLASSES[String(Defs.B[nt]["cls"])]["icon"]))
	_check_goals()
	changed.emit()
	return true


## Мазок «Перестроить» окончен: одна запись в колокольчик (без всплывашки) — сколько домов, кому и за сколько
func upgrades_done(ids: Array, spent: int) -> void:
	if ids.is_empty():
		return
	var names := []
	var tight := 0
	var grow := 0                              # из тесных — сколько ещё можно надстроить
	for id in ids:
		if buildings.has(id):
			var bb: Dictionary = buildings[id]
			names.append(_fam_name(bb))
			if int(bb["pop"]) > house_cap(bb):
				tight += 1
				if int(bb["tier"]) < Defs.floors_max(String(def(bb)["cls"]), int(bb.get("variant", 0))):
					grow += 1
	var tail := ""
	if tight > 0:
		tail = " Где жильцов больше, чем мест, — тесновато, но никто не уехал" + (": надстройте этаж." if grow > 0 else "; новые семьи туда не въедут, пока не станет свободнее.")
	if ids.size() == 1 and buildings.has(ids[0]):
		_quiet("Дом семьи %s перестроили за %d ден.: теперь это %s.%s" % [names[0], spent, String(def(buildings[ids[0]])["name"]).to_lower(), tail], "housing")
		return
	var who := ", ".join(names.slice(0, 3)) + (" и ещё %d" % (names.size() - 3) if names.size() > 3 else "")
	_quiet("Перестроили %d %s за %d ден. (семьи %s).%s" % [ids.size(), plural(ids.size(), "дом", "дома", "домов"), spent, who, tail], "housing")


## Счастье жилых домов, где живут (0…100), — до и после стройки: над кем оно поменялось, всплывают рожицы (game._happy_pops)
func happy_map() -> Dictionary:
	var out := {}
	for id in buildings:
		var b: Dictionary = buildings[id]
		if is_house(b) and int(b["pop"]) + int(b.get("coming", 0)) > 0:
			out[id] = clampi(int(b.get("happy", 0)), 0, 100)
	return out


# ---------- приезд семей ----------

## Сколько семей уже приехало (заселены, ждут на площади, идут к дому, едут в повозке)
func families_came() -> int:
	# семьи «back» уже жили в городе (их дом снесли или в дом влезли не все) — они уже в settled_total
	var n := settled_total + incoming
	for f in arrivals:
		if not bool(f.get("back", false)):
			n += 1
	for nm in pending:
		if not bool((pending[nm] as Dictionary).get("back", false)):
			n += 1
	return n


## Семьи едут без условия счастья: первые Defs.ARRIVE_FREE семей, а на стоянке — пока людей меньше, чем нужно
## хутору (семьи бывают по 2 человека — семи семей может не хватить до 20)
func _arrive_free() -> bool:
	return families_came() < Defs.ARRIVE_FREE or (level == 0 and int(stats.get("pop", 0)) < int(Defs.LEVELS[1]["pop"]))


## Почему повозка не везёт новые семьи ("" — везёт): первые Defs.ARRIVE_FREE семей едут всегда,
## дальше — только пока счастье города не ниже Defs.ARRIVE_HAPPY (как поезд в Town to City)
func arrivals_blocked() -> String:
	if _arrive_free() or int(stats.get("pop", 0)) <= 0:
		return ""
	if int(stats.get("happy", 0)) < Defs.ARRIVE_HAPPY:
		return "Новые семьи приедут, когда счастье города будет не ниже %d%% (сейчас %d%%)" % [Defs.ARRIVE_HAPPY, int(stats["happy"])]
	return ""


## Советник объясняет, почему повозка стоит, — один раз, без повторов (и снова не раньше чем через сутки)
func _arrive_gate(why: String) -> void:
	if why != "":
		if arrive_block_h == 0 and hour_n - arrive_block_said >= 24:
			arrive_block_said = hour_n
			arrive_block_told = true
			var tip := ""
			var ht: Array = stats.get("happy_tips", [])
			if not ht.is_empty():
				tip = " Совет: " + String(ht[0]) + "."
			var msg := "Новые семьи не едут: в город переселяются, только если счастье не ниже %d%%, а сейчас %d%%.%s" % [Defs.ARRIVE_HAPPY, int(stats["happy"]), tip]
			if not tips.has("arrive_block") and not arrive_advice.get_connections().is_empty():
				# в первый раз объясняет советник (окно с текстом), а не всплывашка; в колокольчик — как обычно
				tips["arrive_block"] = true
				events.append({"day": day, "text": msg, "icon": "happy"})
				if events.size() > 60:
					events.pop_front()
				arrive_advice.emit(msg)
			else:
				_event(msg, "happy")
		arrive_block_h += 1
	else:
		if arrive_block_told:              # «снова едут» — только в ответ на «не едут»
			_event("Счастье города %d%% — повозка снова везёт новые семьи" % int(stats["happy"]), "family")
		arrive_block_told = false
		arrive_block_h = 0


## Сколько семей каждого открытого класса влезет в дома прямо сейчас: по каждому дому — свободные места ÷ самая
## маленькая семья класса; семьи, что уже ждут на площади, сначала занимают места по своему числу людей.
## (Те, кто идёт к дому, уже в его «coming».)
func fit_by_class() -> Dictionary:
	var out := {}
	for cl in Defs.CLASS_ORDER:
		if unlocked(Defs.CLASSES[cl]["house"]):
			out[cl] = 0
	var free := _free_rooms()
	for id in free:
		var cl: String = def(buildings[id])["cls"]
		if out.has(cl):
			out[cl] += int(free[id]) / int(Defs.FAMILY_SIZE[cl][0])
	return out


## Свободные места в домах открытых классов (дом → мест) за вычетом семей, что ждут на площади:
## каждая ждущая семья занимает самый тесный дом своего класса, куда входит целиком (не входит никуда — ничего не занимает)
func _free_rooms() -> Dictionary:
	var free := {}
	for id in buildings:
		var b: Dictionary = buildings[id]
		if is_house(b) and unlocked(Defs.CLASSES[def(b)["cls"]]["house"]):
			free[id] = maxi(0, house_cap(b) - int(b["pop"]) - int(b.get("coming", 0)))
	var wait := arrivals.duplicate()
	wait.sort_custom(func(x, y): return int(x["n"]) > int(y["n"]))      # большие семьи — первыми
	for f in wait:
		_take_room(free, String(f["cls"]), int(f["n"]))
	return free


## Занять в free место семье из n человек класса cls: в самом тесном доме, где она помещается. false — места нет
func _take_room(free: Dictionary, cls: String, n: int) -> bool:
	var best := -1
	for id in free:
		if def(buildings[id])["cls"] == cls and int(free[id]) >= n and (best < 0 or int(free[id]) < int(free[best])):
			best = int(id)
	if best < 0:
		return false
	free[best] = int(free[best]) - n
	return true


## Сколько ещё семей можно везти: влезут в дома, минус те, что уже едут в повозке
func free_fit() -> int:
	var n := 0
	var fit := fit_by_class()
	for cl in fit:
		n += int(fit[cl])
	return n - incoming


## Счастливый город и праздник зовут чаще: множитель промежутка между повозками (1 — обычный) и почему
func arrive_mult() -> Array:
	var hp := int(stats.get("happy", 0))
	var m := 1.0
	var why := []
	for e: Array in Defs.ARRIVE_FAST:
		if hp >= int(e[0]):
			m = float(e[1])
			why.append("счастье города от %d%%" % int(e[0]))
			break
	if fest_left > 0:
		m *= float(Defs.FESTIVAL["cart"])
		why.append("идут игры в честь богов")
	return [maxf(Defs.ARRIVE_MULT_MIN, m), " и ".join(why)]


## Повозка раз в столько игровых часов — с поправкой на счастье
func arrive_every() -> float:
	return float(Defs.ARRIVE_EVERY[clampi(level, 0, Defs.ARRIVE_EVERY.size() - 1)]) * float(arrive_mult()[0])


## Почему повозка ждёт из-за жилья ("" — не ждёт): мест нет, едет или ждёт семья «ищет жильё»
func arrive_wait() -> String:
	if center().is_empty() or arrivals_blocked() != "":
		return ""
	if free_fit() > 0:
		return ""
	if not arrivals.is_empty():
		for f in arrivals:
			if not homes_for(f).is_empty():
				return "Семьи ждут на площади — выберите им дом (значок семьи слева вверху)"
		return "Семья ищет жильё — постройте дом. Новые семьи приедут, когда в домах будет место"
	return "Свободных мест в домах нет — повозка привезёт одну семью, и та будет искать жильё"


## Раз в час: не пора ли повозке привезти новую семью. Едут только туда, где есть место (free_fit);
## если места нет, а на площади и в повозке пусто — одна семья «ищет жильё» (подсказка, что пора строить)
func _tick_arrivals() -> void:
	if center().is_empty() or _count(func(b): return is_house(b)) == 0:
		return
	var why := arrivals_blocked()
	stats["arrive_block"] = why
	_arrive_gate(why)
	if why != "":
		arrive_t = minf(arrive_t + 1.0, 99.0)     # как только счастье поднимется — повозка поедет сразу
		return
	var room: int = int(Defs.ARRIVAL_MAX[clampi(level, 0, Defs.ARRIVAL_MAX.size() - 1)]) - arrivals.size() - incoming
	if room <= 0:
		if arrive_t >= 1.0:
			arrive_t = 0.0                        # долгое ожидание не копим; дробный остаток прошлой повозки — да
		return
	arrive_t += 1.0
	var fit := free_fit()
	var nobody := arrivals.is_empty() and incoming == 0 and pending.is_empty()
	if fit <= 0 and not nobody:
		return                                    # мест нет, а семьи уже ждут или едут — повозка стоит
	var first := settled_total == 0 and nobody
	if arrive_t >= arrive_every() or first:
		# часы идут целыми: остаток меньше часа переносим на следующую повозку — «раз в 1,6 ч» в среднем так и есть
		# (после долгой стоянки остаток в час и больше — с нуля, без нескольких повозок подряд)
		var over := arrive_t - arrive_every()
		arrive_t = over if over > 0.0 and over < 1.0 else 0.0
		var n := mini(room, int(Defs.FAMILIES_PER_CART[clampi(level, 0, Defs.FAMILIES_PER_CART.size() - 1)]))
		n = mini(n, fit if fit > 0 else 1)        # мест нет — одна семья «ищет жильё»
		if int(stats["happy"]) < Defs.ARRIVE_HAPPY and int(stats["pop"]) > 0 and not _arrive_free():
			n = mini(n, maxi(0, Defs.ARRIVE_FREE - families_came()))   # без счастья — только первые ARRIVE_FREE семей
		incoming += maxi(0, n)


## Кого везёт повозка: семьи тех классов, которым есть место в домах. Если места нет ни у кого
## (семья «ищет жильё») — любого открытого класса, чаще плебеев
func pick_class() -> String:
	var fit := fit_by_class()
	var opts := []
	var total := 0.0
	for cl in fit:
		if int(fit[cl]) > 0:
			opts.append([cl, 5.0])
			total += 5.0
	if opts.is_empty():
		for cl in fit:
			var w := 1.0 if cl == "plebs" else 0.5
			opts.append([cl, w])
			total += w
	var x := rng.randf() * total
	for o in opts:
		x -= float(o[1])
		if x <= 0.0:
			return o[0]
	return "plebs"


## Кого везёт повозка (k семей): каждой — настоящее место в доме её класса, считая и тех, кто ждёт на площади,
## и тех, кого повозка уже взяла. Влезло меньше — везёт меньше. Места нет ни у кого и на площади пусто —
## одна семья «ищет жильё» (seek), подсказка, что пора строить
func make_load(k: int) -> Array:
	var free := _free_rooms()
	var out := []
	var names := {}
	for i in k:
		var opts := {}                            # класс → самое большое место, куда войдёт его самая маленькая семья
		for id in free:
			var cl: String = def(buildings[id])["cls"]
			if int(free[id]) >= int(Defs.FAMILY_SIZE[cl][0]):
				opts[cl] = maxi(int(opts.get(cl, 0)), int(free[id]))
		if opts.is_empty():
			if i == 0 and arrivals.is_empty():
				var s := new_family(pick_class())
				s["seek"] = true
				out.append(s)
			break
		var cls: String = opts.keys()[rng.randi() % opts.size()]
		var f := new_family(cls)
		for r in 8:                               # два одинаковых рода в одной повозке — не бывает
			if not names.has(f["name"]):
				break
			f = new_family(cls)
		var sz: Array = Defs.FAMILY_SIZE[cls]
		f["n"] = rng.randi_range(int(sz[0]), mini(int(sz[1]), int(opts[cls])))
		_take_room(free, cls, int(f["n"]))
		names[f["name"]] = true
		out.append(f)
	return out


## Новая семья: родовое имя, которого ещё нет в городе
func new_family(cls: String) -> Dictionary:
	var used := {}
	for f in arrivals:
		used[f["name"]] = true
	for nm in pending:
		used[nm] = true
	for id in buildings:
		for f in buildings[id].get("families", []):
			used[f["name"]] = true
	var name := ""
	for k in 60:
		var nm: String = Defs.FAMILIES[rng.randi() % Defs.FAMILIES.size()]
		if k >= 20:
			nm += " " + Defs.COGNOMENS[rng.randi() % Defs.COGNOMENS.size()]
		if not used.has(nm):
			name = nm
			break
	if name == "":
		name = "%s %d" % [Defs.FAMILIES[rng.randi() % Defs.FAMILIES.size()], rng.randi() % 1000]
	var sz: Array = Defs.FAMILY_SIZE[cls]
	# семья едет туда, где есть место: не больше, чем влезет в самый просторный свободный дом её класса
	var hi := int(sz[1])
	var room := 0
	for id in buildings:
		var b: Dictionary = buildings[id]
		if is_house(b) and def(b)["cls"] == cls:
			room = maxi(room, house_cap(b) - int(b["pop"]) - int(b.get("coming", 0)))
	if room >= int(sz[0]):
		hi = mini(hi, room)
	return {"name": name, "n": rng.randi_range(int(sz[0]), hi), "cls": cls}


## Семья сошла с повозки (или осталась без дома) и ждёт на площади
func family_arrived(f: Dictionary, from_cart := true) -> void:
	if from_cart:
		incoming = maxi(0, incoming - 1)
	# вернулась семья, что уже жила в городе (дом снесли, или в дом влезли не все): второй раз её не считаем
	var back := not from_cart and (bool(f.get("back", false)) or bool((pending.get(f["name"], {}) as Dictionary).get("back", false)) \
		or _lives_here(String(f["name"])))
	pending.erase(f["name"])
	for a in arrivals:
		if a["name"] == f["name"]:
			return
	var af := {"name": f["name"], "n": int(f["n"]), "cls": f["cls"], "back": back}
	if typeof(f.get("m")) == TYPE_ARRAY and not (f["m"] as Array).is_empty():
		af["m"] = f["m"]                     # члены семьи с именами (Residents) — те же, что сошли с повозки
	arrivals.append(af)
	arrivals_changed.emit()
	changed.emit()
	if from_cart:
		family_came.emit(arrivals[-1])


## Есть ли в городе дом, где уже живёт семья с этим именем
func _lives_here(name: String) -> bool:
	for id in buildings:
		for f in buildings[id].get("families", []):
			if String(f["name"]) == name:
				return true
	return false


func arrival(name: String) -> Dictionary:
	for a in arrivals:
		if a["name"] == name:
			return a
	return {}


## Подходит ли дом семье: её класса и хватает места
func can_host(b: Dictionary, f: Dictionary) -> bool:
	return is_house(b) and def(b)["cls"] == f["cls"] and house_cap(b) - int(b["pop"]) - int(b.get("coming", 0)) >= int(f["n"])


func homes_for(f: Dictionary) -> Array:
	var out := []
	for id in buildings:
		if can_host(buildings[id], f):
			out.append(buildings[id])
	return out


## Игрок выбрал семье дом
func assign(name: String, home: int) -> bool:
	var f := arrival(name)
	if f.is_empty() or not buildings.has(home) or not can_host(buildings[home], f):
		return false
	arrivals.erase(f)
	var b: Dictionary = buildings[home]
	b["coming"] = int(b.get("coming", 0)) + int(f["n"])
	pending[name] = {"name": name, "n": f["n"], "cls": f["cls"], "home": home, "back": bool(f.get("back", false)), "m": f.get("m", [])}
	family_assigned.emit(name, home)
	arrivals_changed.emit()
	changed.emit()
	return true


## Семья дошла до дома
func settled(id: int, n: int, name := "") -> int:
	if not buildings.has(id):
		return 0
	var b: Dictionary = buildings[id]
	var room := house_cap(b) - int(b["pop"])
	n = mini(n, room)
	if n <= 0:
		return 0
	if name == "":
		name = Defs.FAMILIES[rng.randi() % Defs.FAMILIES.size()]
	var back := bool((pending.get(name, {}) as Dictionary).get("back", false))
	var pm: Array = (pending.get(name, {}) as Dictionary).get("m", [])
	pending.erase(name)
	if not back:
		settled_total += 1                 # семья, что уже жила в городе и переезжает снова, — не новая
		Chronicle.add(self, "people", n)
	var fam := {"name": name, "n": n}
	if pm.size() >= n:
		fam["m"] = pm.slice(0, n)          # члены семьи с именами (Residents); кто вошёл — уточнит People при входе
	(b["families"] as Array).append(fam)
	b["pop"] = int(b["pop"]) + n
	compute(true)
	_check_goals()
	house_changed.emit(b, false)
	changed.emit()
	return n


## Раз в час: город сам уровень не поднимает — только отмечает, что готов (кнопка «Перейти на новый уровень»),
## и один раз на каждый уровень пишет об этом в колокольчик
func _update_level() -> void:
	var ok := rank_ok()
	stats["rank_ready"] = ok
	if ok and int(tips.get("rank_said", -1)) != level + 1:
		tips["rank_said"] = level + 1
		_quiet("Город готов стать «%s» — нажмите «Перейти на новый уровень» под табличкой города" % Defs.LEVELS[level + 1]["name"], "level")


func next_level() -> Dictionary:
	return Defs.LEVELS[level + 1] if level < Defs.LEVELS.size() - 1 else {}


## Условия перехода на уровень lvl (по умолчанию — следующий): [{text, icon, have, need, ok}]
## Жители и счастье — из Defs.LEVELS pop/happy, постройки — из need
func rank_needs(lvl := -1) -> Array:
	if lvl < 0:
		lvl = level + 1
	if lvl <= 0 or lvl >= Defs.LEVELS.size():
		return []
	var L: Dictionary = Defs.LEVELS[lvl]
	var pop := int(stats.get("pop", 0))
	var hp := int(stats.get("happy", 0))
	# p (и tool) — то же условие, что у просьб: по нему интерфейс знает, куда показать стрелку (Hud.need_do)
	var out := [{"text": "Жителей", "icon": "family", "have": pop, "need": int(L["pop"]), "ok": pop >= int(L["pop"]), "pct": false, "p": ["pop"]},
		{"text": "Счастье города", "icon": "happy", "have": hp, "need": int(L["happy"]), "ok": hp >= int(L["happy"]), "pct": true, "p": ["happy"]}]
	for n: Dictionary in L.get("need", []):
		var have := progress_of(n["p"])
		out.append({"text": n["text"], "say": n.get("say", String(n["text"]).to_lower()), "icon": n.get("icon", "check"), "have": have,
			"need": int(n["n"]), "ok": have >= int(n["n"]), "pct": false, "p": n["p"], "tool": String(n.get("tool", ""))})
	return out


## Сколько условий уровня lvl уже выполнено
func rank_met(lvl := -1) -> int:
	var k := 0
	for e: Dictionary in rank_needs(lvl):
		if e["ok"]:
			k += 1
	return k


## Все условия следующего уровня выполнены — можно жать кнопку
func rank_ok() -> bool:
	if level >= Defs.LEVELS.size() - 1:
		return false
	var nd := rank_needs()
	return not nd.is_empty() and rank_met() == nd.size()


## «20 жителей, счастье от 55%, фруктовая лавка и скрипторий» — что нужно уровню lvl (для подсказок)
func rank_text(lvl := -1) -> String:
	var parts := []
	for e: Dictionary in rank_needs(lvl):
		if e["pct"]:
			parts.append("счастье от %d%%" % int(e["need"]))
		elif e["icon"] == "family":
			parts.append("%d %s" % [int(e["need"]), plural(int(e["need"]), "житель", "жителя", "жителей")])
		else:
			parts.append(String(e["say"]))
	if parts.size() <= 1:
		return "".join(parts)
	return ", ".join(parts.slice(0, parts.size() - 1)) + " и " + String(parts[-1])


## Игрок нажал «Перейти на новый уровень»: +1 уровень, ролик «Новый ранг», новые исследования.
## force — без проверки условий (тесты, отладка)
func rank_up(force := false) -> bool:
	if level >= Defs.LEVELS.size() - 1 or (not force and not rank_ok()):
		return false
	level += 1
	var nx: Dictionary = Defs.LEVELS[level]
	tips["rank_pressed"] = true
	level_up.emit(level)         # раньше всплывашки: ролик её заменяет и придерживает новую станцию
	_event("Город теперь — «%s»! Открылись новые исследования, казна вмещает %d ден." % [nx["name"], int(money_cap())], "level")
	var c := center()
	if not c.is_empty():
		c["tier"] = level
		house_changed.emit(c, true)
	compute()                    # пределы уровня выросли — лишние школы и скриптории могут заработать
	stats["rank_ready"] = rank_ok()
	_check_goals()
	changed.emit()
	return true


# ---------- исследования ----------

func can_research(id: String) -> String:
	var r := Defs.research(id)
	if r.is_empty() or research.has(id):
		return "Уже изучено"
	if Defs.story_of(r) != "":
		return "Откроется %s" % Defs.unlock_text(id)
	if int(r["lvl"]) > level:
		return "Нужен уровень «%s»" % Defs.LEVELS[int(r["lvl"])]["name"]
	if r.has("after") and not research.has(r["after"]):
		return "Сначала — «%s»" % Defs.research(r["after"])["name"]
	if rp < float(r["cost"]):
		# дороже, чем вмещают полки: копить бесполезно — сказать, что поможет
		if float(r["cost"]) > rp_cap():
			if not research.has("research1") and level >= int(Defs.research("research1")["lvl"]):
				return "Не помещается на полки (%d очков) — сначала изучите «%s»" % [int(rp_cap()), Defs.research("research1")["name"]]
			return "Не помещается на полки (%d очков) — полки вырастут на новом уровне" % int(rp_cap())
		return "Не хватает очков исследований"
	return ""


func do_research(id: String) -> bool:
	if can_research(id) != "":
		return false
	var r := Defs.research(id)
	rp -= float(r["cost"])
	research[id] = true
	var where := research_where(id)
	_event("Изучено: %s%s" % [r["name"], (" — " + where) if where != "" else ""], "research")
	compute()
	_check_goals()
	changed.emit()
	return true


## Где искать то, что открыло исследование id: «карточка в «Лавки · Товары»», «инструмент «Этаж» справа внизу (U)»
func research_where(id: String) -> String:
	if id in ["floor2", "floor3"]:
		return "инструмент «Этаж» справа внизу (клавиша U)"
	var by := {}                          # раздел меню стройки → его вкладки с новыми карточками
	var order := []
	var n := 0
	for t in Defs.B:
		var d: Dictionary = Defs.B[t]
		if unlock_id(t) != id or String(d.get("cat", "")) == "":
			continue
		n += 1
		var cl: String = Defs.CAT_SHORT.get(d["cat"], d["cat"])
		if not by.has(cl):
			by[cl] = []
			order.append(cl)
		var sl := sub_name(t)
		if sl != "" and not (by[cl] as Array).has(sl):
			by[cl].append(sl)
	if order.is_empty():
		return ""
	var parts := []
	for cl in order.slice(0, 2):
		parts.append("«%s»" % (cl + ((" · " + ", ".join(by[cl])) if not (by[cl] as Array).is_empty() else "")))
	return ("карточка в " if n == 1 else "карточки в ") + " и ".join(parts)


## Вкладка меню стройки, где карточка: «Товары» у лавок, «Цветы» у украшений; у остальных — ""
static func sub_name(type: String) -> String:
	var d: Dictionary = Defs.B[type]
	if d.get("cat", "") == "commerce" and Defs.NEEDS.has(d.get("sub", "")):
		return String(Defs.NEEDS[d["sub"]]["name"])
	if d.get("cat", "") == "decor":
		for ds: Array in Defs.DECOR_SUBS:
			if ds[0] == Defs.decor_sub(type):
				return String(ds[1])
	return ""


# ---------- «НОВОЕ»: открылось, а игрок ещё не смотрел (tips.seen — карточки построек и «@floor» — инструмент «Этаж»,
# tips.seen_r — исследования, которые можно изучать). Старые сохранения: seed_seen — ничего не новое ----------

## Карточка постройки открыта, а игрок её ещё не видел (не наводил мышь, не брал)
func is_new(type: String) -> bool:
	if type == "@floor":
		return research.has("floor2") and not (tips.get("seen", {}) as Dictionary).has(type)
	if type == "@upgrade":
		return research.has("artisans") and not (tips.get("seen", {}) as Dictionary).has(type)
	return String(Defs.B[type].get("cat", "")) != "" and unlocked(type) and not (tips.get("seen", {}) as Dictionary).has(type)


## Игрок посмотрел на карточку (или взял инструмент): true — она была новой
func mark_seen(type: String) -> bool:
	if not is_new(type):
		return false
	var s: Dictionary = tips.get("seen", {})
	s[type] = true
	tips["seen"] = s
	return true


## Исследование можно изучать (уровень есть, нужное раньше изучено), но ещё не изучено
func research_open(id: String) -> bool:
	var r := Defs.research(id)
	return not r.is_empty() and Defs.story_of(r) == "" and not research.has(id) and int(r["lvl"]) <= level and (not r.has("after") or research.has(r["after"]))


func is_new_r(id: String) -> bool:
	return research_open(id) and not (tips.get("seen_r", {}) as Dictionary).has(id)


func mark_seen_r(id: String) -> bool:
	if not is_new_r(id):
		return false
	var s: Dictionary = tips.get("seen_r", {})
	s[id] = true
	tips["seen_r"] = s
	return true


## Новых карточек в разделе cat (и вкладке sub; "" — во всём разделе)
func new_count(cat: String, sub := "") -> int:
	var n := 0
	for t in Defs.B:
		var d: Dictionary = Defs.B[t]
		if d.get("cat", "") == cat and (sub == "" or d.get("sub", "") == sub) and is_new(t):
			n += 1
	return n


## Все счётчики новых карточек за один проход: раздел → число, «раздел|вкладка» → число (для пометок на кнопках)
func new_counts() -> Dictionary:
	var out := {}
	for t in Defs.B:
		if is_new(t):
			var d: Dictionary = Defs.B[t]
			var cat: String = d["cat"]
			out[cat] = int(out.get(cat, 0)) + 1
			var k := cat + "|" + (Defs.decor_sub(t) if cat == "decor" else String(d.get("sub", "")))
			out[k] = int(out.get(k, 0)) + 1
	return out


func new_research() -> int:
	var n := 0
	for r in Defs.RESEARCH:
		if is_new_r(r["id"]):
			n += 1
	return n


## Всё, что открыто сейчас, — уже «видели»: новая игра и старое сохранение без tips.seen начинают без пометок
func seed_seen() -> void:
	var s := {}
	for t in Defs.B:
		if unlocked(t):
			s[t] = true
	if research.has("floor2"):
		s["@floor"] = true
	var r := {}
	for e in Defs.RESEARCH:
		if research_open(e["id"]):
			r[e["id"]] = true
	tips["seen"] = s
	tips["seen_r"] = r


# ---------- праздник «Игры в честь богов» (Defs.FESTIVAL) ----------

## Сколько счастья всем домам дают игры сейчас (City.compute)
func fest_bonus() -> int:
	return int(Defs.FESTIVAL["happy"]) if fest_left > 0 else 0


## Цена игр: tax_k часовых налогов каждого жителя (плебей — 3 ден., ремесленник — 5,5, патриций — 11,25), вверх
## до десятков. За сутки игр +8% счастья вернут налогами не больше 1,92 часового налога — игры всегда трата
func fest_price() -> int:
	var s := 0.0
	for b in buildings.values():
		if def(b)["kind"] == "house":
			s += int(b["pop"]) * house_tax(b)
	return int(ceil(s * float(Defs.FESTIVAL["tax_k"]) / 10.0 - 0.0001)) * 10


func fest_open() -> bool:
	return level >= int(Defs.FESTIVAL["lvl"])


## "" — игры можно устроить; иначе — почему нельзя (для кнопки в карточке станции)
func can_festival() -> String:
	if not fest_open():
		return "Игры откроются на уровне «%s»" % Defs.LEVELS[int(Defs.FESTIVAL["lvl"])]["name"]
	if fest_left > 0:
		return "Игры уже идут — ещё %d ч" % fest_left
	if fest_cd > 0:
		return "Новые игры можно устроить через %d ч" % fest_cd
	if int(stats.get("pop", 0)) <= 0:
		return "Праздновать пока некому"
	if money < float(fest_price()):
		return "Не хватает денариев: нужно %d" % fest_price()
	return ""


## Устроить игры: казна платит, сутки весь город празднует (счастье, повозка чаще); в колокольчик — тихо
func festival() -> bool:
	if can_festival() != "":
		return false
	var F: Dictionary = Defs.FESTIVAL
	flow("fest", -float(fest_price()))
	money -= float(fest_price())
	fest_left = int(F["hours"])
	fest_cd = int(F["cd"])
	Chronicle.add(self, "fests")
	_quiet("Игры в честь богов! %d ч счастье всех домов +%d%%, повозка с семьями ходит чаще" % [int(F["hours"]), int(F["happy"])], "laurels")
	compute(true)
	festival_changed.emit(true)
	_check_goals()
	changed.emit()
	return true


## Час праздника (sim_day): игры идут — на час меньше; кончились — тихая запись в колокольчик
func _fest_hour() -> void:
	fest_cd = maxi(0, fest_cd - 1)
	if fest_left <= 0:
		return
	fest_left -= 1
	if fest_left == 0:
		_quiet("Игры в честь богов окончены. Новые можно устроить через %d ч — в карточке почтовой станции" % fest_cd, "laurels")
		compute(true)
		festival_changed.emit(false)


# ---------- участки ----------

## Цена следующего участка: k-й купленный — Defs.PLOT_BASE × PLOT_GROW^(k−1), до тысяч (6, 8, 10, 13, 17 тыс. …)
func plot_price() -> int:
	return int(roundf(float(Defs.PLOT_BASE) * pow(Defs.PLOT_GROW, plots_bought) / 1000.0)) * 1000


func can_buy(p: Vector2i) -> bool:
	if land.owned.has(p):
		return false
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if land.owned.has(p + d):
			return true
	return false


func buy_plot(p: Vector2i) -> bool:
	if not can_buy(p) or money < plot_price():
		return false
	flow("land", -float(plot_price()))
	money -= plot_price()
	plots_bought += 1
	land.owned[p] = true
	var c := int(Land.PLOT / Land.CELL)
	for j in range(p.y * c, p.y * c + c, Land.CH):
		for i in range(p.x * c, p.x * c + c, Land.CH):
			land._mark(i + 1, j + 1)
	_quiet("Куплен новый участок земли — на нём можно строить", "keys")
	_check_goals()
	changed.emit()
	return true


# ---------- задания ----------

func _count(pred: Callable) -> int:
	var n := 0
	for id in buildings:
		if pred.call(buildings[id]):
			n += 1
	return n


func goal_progress(id: String) -> int:
	var g := Defs.request(id)
	if g.is_empty():
		return 0
	return progress_of(g["p"])


## Сколько уже есть по условию p (просьбы горожан и условия уровней): [вид, параметр…]
func progress_of(pp: Array) -> int:
	var arg = pp[1] if pp.size() > 1 else null
	match pp[0]:
		"rank":                                     # «Станьте хутором»: сколько условий уровня выполнено
			return rank_needs(int(arg)).size() if level >= int(arg) else rank_met(int(arg))
		"road": return road_cells
		"houses": return _count(func(b): return is_house(b))
		"fam": return settled_total
		"count": return _count(func(b): return b["type"] == arg or Defs.base_of(b["type"]) == arg)   # любой облик украшения
		"kind": return _count(func(b): return def(b)["kind"] == arg)
		"pop": return int(stats["pop"])
		"happy": return int(stats["happy"]) if int(stats["pop"]) >= 10 else 0
		"cls": return int(stats["residents"].get(arg, 0))
		"floors": return _count(func(b): return is_house(b) and int(b["tier"]) >= int(arg))
		"fed": return _count(func(b): return is_house(b) and bool((b.get("needs", {}) as Dictionary).get(arg, false)))
		# награды просьб (q_), историй (s_) и заказов старосты (o_) — не исследования
		"research": return research.keys().filter(func(k): return not (String(k).begins_with("q_") or String(k).begins_with("s_") or String(k).begins_with("o_"))).size()
		"shops":                                    # разные лавки (["shops", "food"] — только этого вида)
			var kinds := {}
			for id2 in buildings:
				var sd := def(buildings[id2])
				if sd["kind"] == "shop" and (arg == null or sd.get("sub", "") == arg):
					kinds[buildings[id2]["type"]] = true
			return kinds.size()
		"near":
			var cls: String = pp[2]
			var n := 0
			for id2 in buildings:
				var h: Dictionary = buildings[id2]
				if not is_house(h) or def(h)["cls"] != cls:
					continue
				for id3 in buildings:
					var o: Dictionary = buildings[id3]
					if o["type"] == arg and (o["pos"] as Vector2).distance_to(h["pos"]) <= maxf(18.0, Defs.range_m(def(o))):
						n += 1
						break
			return n
		"store": return mini(1, _count(func(b): return b["type"] == "warehouse")) + mini(1, _count(func(b): return b["type"] == "butcher"))
		"light": return _count(func(b): return def(b).get("light", false))
	return 0


func active_goals(n := 3) -> Array:
	var out := []
	for g in Defs.REQUESTS:
		if not goals_done.has(g["id"]):
			out.append(g)
			if out.size() >= n:
				break
	return out


func _check_goals() -> void:
	for g in active_goals():
		var pp: Array = g["p"]
		if pp[0] == "rank" and level < int(pp[1]):
			continue                                # «Станьте хутором» — только когда игрок нажал кнопку
		if goal_progress(g["id"]) >= int(g["need"]):
			goals_done.append(g["id"])
			# казна полна — предел остаётся, но в колокольчике честно: сколько не уместилось (как у историй)
			var lost := maxi(0, roundi(float(g["money"]) - maxf(0.0, money_cap() - money)))
			var m0 := money
			money = minf(money_cap(), money + float(g["money"]))
			flow("reward", money - m0)
			var r0 := rp
			rp = maxf(rp, minf(rp_cap(), rp + float(g["rp"])))
			if rp - r0 >= 0.5:
				rp_reward.emit(roundi(rp - r0))
			var extra := ""
			if g.has("unlock"):
				research[g["unlock"]] = true
				extra = ". Открыто: %s" % g.get("reward", "новые украшения")
			var mtxt := ("+%d ден." % g["money"]) if lost <= 0 else ("+%d ден. (казна полна — не уместилось %d)" % [g["money"], lost])
			_event("Просьба выполнена: %s (%s%s)%s" % [g["text"], mtxt, (", +%d оч." % g["rp"]) if int(g["rp"]) > 0 else "", extra], "check")


## Старые сохранения: исследование «Площади из плитки» (roads2) ничего не давало — площадь открыта с начала.
## Его убрали; потраченные очки возвращаем сверх предела полок и пишем об этом в колокольчик (один раз)
const ROADS2_RP := 160


func _drop_roads2() -> void:
	if not research.has("roads2"):
		return
	research.erase("roads2")
	rp += ROADS2_RP
	events.append({"day": day, "icon": "research",
		"text": "Исследование «Площади из плитки» убрано: площадь из плитки и так открыта с самого начала. Потраченные %d очков исследований вернулись." % ROADS2_RP})
	if events.size() > 60:
		events.pop_front()
	unread += 1


func _event(text: String, icon: String) -> void:
	events.append({"day": day, "text": text, "icon": icon})
	if events.size() > 60:
		events.pop_front()
	event.emit(text, icon)


## Событие только в колокольчик (без всплывашки)
func _quiet(text: String, icon: String) -> void:
	events.append({"day": day, "text": text, "icon": icon})
	if events.size() > 60:
		events.pop_front()
	quiet.emit(text, icon)


# ---------- истории горожан: данные (ведёт их scripts/stories.gd, тексты — StoryDefs) ----------

## Пустое состояние: часы историй (идут после обучения), когда кончилась прошлая (-1 — ещё ни одной), пройденные,
## идущая, предложенная, отложенные (id → до какого часа), бонусы к счастью, кошки-награды, заказы старосты (StoryOrders)
static func stories_new() -> Dictionary:
	# granted — исследование → история, чей шаг его открыл («legion» → «bandits»): прерванную такую историю предложат снова
	return {"v": 1, "h": 0, "last_h": -1, "done": {}, "active": {}, "offer": {}, "later": {}, "bonus": [], "pets": [], "orders": {}, "granted": {}}


## Из сохранения: чего нет — по умолчанию (старые сохранения — без историй: ничего не идёт, часы с нуля)
static func stories_load(d: Variant) -> Dictionary:
	var s := stories_new()
	if typeof(d) != TYPE_DICTIONARY:
		return s
	var dd: Dictionary = d
	s["h"] = int(dd.get("h", 0))
	s["last_h"] = int(dd.get("last_h", -1))
	for k in ["done", "active", "offer", "later", "orders", "granted"]:
		if typeof(dd.get(k)) == TYPE_DICTIONARY:
			s[k] = dd[k]
	for k in ["bonus", "pets"]:
		if typeof(dd.get(k)) == TYPE_ARRAY:
			s[k] = dd[k]
	for p in s["pets"]:
		if typeof(p) == TYPE_DICTIONARY and (p.has("it") or p.has("wr")):
			var pe := {}
			cat_items_load(p, pe)              # вещицы кошки-награды — только известные
			p.erase("it")
			p.erase("wr")
			p.merge(pe)
	if int(dd.get("tax_off", 0)) > 0:
		s["tax_off"] = int(dd["tax_off"])     # Сатурналии, день отдыха: часов без налогов осталось
	# истории, которой в игре больше нет, — не продолжаем
	for k in ["active", "offer"]:
		if not (s[k] as Dictionary).is_empty() and StoryDefs.story(String(s[k].get("id", ""))).is_empty():
			s[k] = {}
	# сохранено посреди истории до записи granted: что открыли её пройденные шаги — открыла она
	var a0: Dictionary = s["active"]
	if not a0.is_empty():
		var steps: Array = StoryDefs.story(String(a0.get("id", ""))).get("steps", [])
		for i in mini(int(a0.get("step", 0)) + 1, steps.size()):
			for r in (steps[i] as Dictionary).get("grant", []):
				if not (s["granted"] as Dictionary).has(String(r)):
					s["granted"][String(r)] = String(a0["id"])
	StoryDefs.migrate(s)                    # «Где Мурка?» → «Где Мася?» (Д15): новые имена, чёрная кошка
	return s


## Час историй: часы идут, когда обучение кончилось; временные бонусы к счастью тают
func _story_hour() -> void:
	if int(tips.get("tut", -1)) < 0:
		stories["h"] = int(stories["h"]) + 1
	var keep := []
	for b: Dictionary in stories["bonus"]:
		var left := int(b.get("left", -1))
		if left > 0:
			b["left"] = left - 1
			if left - 1 <= 0:
				continue
		keep.append(b)
	stories["bonus"] = keep
	if int(stories.get("tax_off", 0)) > 0:
		stories["tax_off"] = int(stories["tax_off"]) - 1     # день отдыха: часы без налогов тают


## Слагаемые счастья дома h от историй: [[строка, %], …] (семье, дому, соседям в радиусе, всем)
func story_parts(h: Dictionary) -> Array:
	var out := []
	for b: Dictionary in stories["bonus"]:
		var ok := true
		if b.has("fam"):                       # семье: переехала — бонус с ней
			ok = false
			for f: Dictionary in h.get("families", []):
				if String(f["name"]) == String(b["fam"]):
					ok = true
		elif b.has("home"):
			ok = int(b["home"]) == int(h["id"])
		elif b.has("cls"):
			ok = String(def(h).get("cls", "")) == String(b["cls"])   # всем домам сословия (лабиринт — патрициям)
		elif b.has("x"):
			ok = (h["pos"] as Vector2).distance_to(Vector2(float(b["x"]), float(b["z"]))) <= float(b.get("r", 0.0))
		var pct := int(b.get("_live", b.get("pct", 0))) if b.has("at") else int(b.get("pct", 0))
		if not ok or pct == 0:
			continue                           # меньше нуля — тоже строка: копоть после пожара (этап 7b)
		var line := String(b.get("line", "История горожан"))
		var left := int(b.get("left", -1))
		if left > 0:
			line += " (ещё %s)" % (("%d ч" % left) if left < 24 else ("%d дн." % ceili(left / 24.0)))
		out.append([line, pct])
	return out


## Перенесённый дом: история, бонусы и кошки-награды идут за ним
func _story_rehome(old: int, new: int) -> void:
	for k in ["active", "offer"]:
		var a: Dictionary = stories[k]
		if not a.is_empty() and int(a.get("home", -1)) == old:
			a["home"] = new
		if not a.is_empty() and int(a.get("home2", -1)) == old:
			a["home2"] = new                   # дом жениха
		var fl: Dictionary = a.get("flags", {})
		if int(fl.get("built", -1)) == old:
			fl["built"] = new                  # новый дом молодых
	for e: Dictionary in stories["bonus"] + stories["pets"] + (stories["done"] as Dictionary).values():
		if e.has("home") and int(e["home"]) == old:
			e["home"] = new


# ---------- «Кошачья лавка» (Д14): вещицы кошек — в записи кошки: it — что есть, wr — что надето ("" — ничего) ----------

## Записи всех кошек с именами: городские (cats) и кошки-награды историй (stories.pets)
func cat_recs() -> Array:
	return cats + (stories.get("pets", []) as Array)


## Имя кошки по записи (у кошек-наград — name)
static func cat_rec_name(rec: Dictionary) -> String:
	return String(rec.get("nm", rec.get("name", "")))


## Работает ли в городе хоть одна «Кошачья лавка»
func cat_shop_open() -> bool:
	for id in buildings:
		var b: Dictionary = buildings[id]
		if String(b["type"]) == "catshop" and bool(b.get("active", false)):
			return true
	return false


## Дома, которые обслуживают работающие «Кошачьи лавки»
func cat_shop_homes() -> Dictionary:
	var out := {}
	for id in buildings:
		var b: Dictionary = buildings[id]
		if String(b["type"]) == "catshop" and bool(b.get("active", false)):
			for h in b.get("serves", []):
				out[int(h)] = true
	return out


## Вещь item кошке rec: в её вещи и сразу надеть. by_player — выбрал игрок в карточке кошки: нужна работающая лавка
## и денарии (цена из CAT_ITEMS); хозяева покупают сами — город не платит
func buy_cat_item(rec: Dictionary, item: String, by_player := true) -> bool:
	if rec.is_empty() or not Defs.CAT_ITEMS.has(item):
		return false
	var it: Array = rec.get("it", [])
	if not it.has(item):
		if by_player:
			var price := float(Defs.CAT_ITEMS[item]["price"])
			if not cat_shop_open() or money < price:
				return false
			money -= price
			flow("other", -price)
		it.append(item)
		rec["it"] = it
	rec["wr"] = item
	changed.emit()
	return true


## Надеть кошке её вещь item ("" — снять всё)
func wear_cat_item(rec: Dictionary, item: String) -> bool:
	if rec.is_empty() or (item != "" and not (rec.get("it", []) as Array).has(item)):
		return false
	rec["wr"] = item
	changed.emit()
	return true


## Час «Кошачьих лавок»: хозяева кошки из дома, который обслуживает лавка, иногда покупают ей обновку (не больше
## CAT_ITEMS_MAX вещиц) и сразу надевают. Свой поток случайностей: общий rng города (семьи, цвета) не сдвигается
func _cat_shop_hour() -> void:
	var homes := cat_shop_homes()
	if homes.is_empty():
		return
	var rg := RandomNumberGenerator.new()
	rg.seed = hash([hour_n, day, "cats"])
	for rec: Dictionary in cat_recs():
		if not homes.has(int(rec.get("home", -1))):
			continue
		var it: Array = rec.get("it", [])
		if it.size() >= Defs.CAT_ITEMS_MAX or rg.randf() >= Defs.CAT_BUY_P:
			continue
		var opts: Array = Defs.CAT_ITEM_ORDER.filter(func(x): return not it.has(x))
		if opts.is_empty():
			continue
		var item: String = opts[rg.randi() % opts.size()]
		buy_cat_item(rec, item, false)
		var h: Dictionary = buildings.get(int(rec.get("home", -1)), {})
		var who := ("Семья %s купила" % _fam_name(h)) if not h.is_empty() and not (h.get("families", []) as Array).is_empty() else "Хозяева купили"
		_quiet("%s в «Кошачьей лавке» обновку: %s теперь %s" % [who, cat_rec_name(rec), String(Defs.CAT_ITEMS[item]["wear"])], "cat")
		tips["cat_item_first"] = true            # советник объяснит один раз (hud._once_tips)


## Вещи кошки из сохранения: только известные; надето — из её вещей (старые сохранения — без вещей)
static func cat_items_load(e: Dictionary, out: Dictionary) -> void:
	var it := []
	if typeof(e.get("it")) == TYPE_ARRAY:
		for x in e["it"]:
			if Defs.CAT_ITEMS.has(String(x)) and not it.has(String(x)):
				it.append(String(x))
	if not it.is_empty():
		out["it"] = it
		var wr := String(e.get("wr", ""))
		out["wr"] = wr if it.has(wr) else ""


# ---------- сохранение ----------

func save_data() -> Dictionary:
	var bl := []
	for id in buildings:
		var b: Dictionary = buildings[id]
		bl.append({"id": id, "type": b["type"], "tier": b["tier"], "x": b["pos"].x, "z": b["pos"].y, "yaw": b["yaw"], "variant": b["variant"],
			"color": b["color"], "y": b["y"], "pop": b["pop"], "families": b["families"], "host": b.get("host", -1), "hire": b.get("hire", -1),
			"born": int(b.get("born", id)), "cells": _cells64(b["cells"])})
	return {"money": money, "rp": rp, "day": day, "level": level, "research": research.keys(), "buildings": bl, "next_id": next_id,
		"goals": goals_done, "arrivals": arrivals + pending.values().map(func(f): return {"name": f["name"], "n": f["n"], "cls": f["cls"], "back": bool(f.get("back", false)), "m": f.get("m", [])}),
		# семьи в повозке (и те, за кем она едет) — числом: после загрузки повозка привезёт их заново
		"incoming": incoming,
		"arrive_t": arrive_t, "settled_total": settled_total, "tips": tips, "events": events, "road_cells": road_cells,
		"fest_left": fest_left, "fest_cd": fest_cd, "plots_bought": plots_bought, "name": name,
		"econ_v": econ, "decor_v": decor_v, "story_v": story_v, "taxes": taxes, "hist": hist,
		"stories": stories.duplicate(true), "legion": legion.to_dict(), "cats": cats.duplicate(true), "hero": hero.duplicate(true), "chron": chron.duplicate(true)}


## Клетки постройки — строкой base64; пустые — пустой строкой (Marshalls ругается на пустой массив в журнал)
static func _cells64(cells: PackedInt32Array) -> String:
	return "" if cells.is_empty() else Marshalls.raw_to_base64(cells.to_byte_array())


func load_data(d: Dictionary) -> void:
	money = float(d.get("money", Defs.START_MONEY))
	rp = float(d.get("rp", 0))
	day = int(d.get("day", 0))
	level = int(d.get("level", 0))
	research = {}
	for r in d.get("research", []):
		research[r] = true
	goals_done = d.get("goals", [])
	for g in Defs.REQUESTS:
		if goals_done.has(g["id"]) and g.has("unlock"):
			research[g["unlock"]] = true
	arrivals = []
	for f in d.get("arrivals", []):
		var af := {"name": f["name"], "n": int(f["n"]), "cls": f.get("cls", "plebs"), "back": bool(f.get("back", false))}
		if typeof(f.get("m")) == TYPE_ARRAY and not (f["m"] as Array).is_empty():
			af["m"] = f["m"]
			Residents.fit(af, hash([String(af["name"]), -1]))    # члены семьи из сохранения (числа — целыми)
		arrivals.append(af)
	pending = {}
	incoming = maxi(0, int(d.get("incoming", 0)))
	arrive_t = float(d.get("arrive_t", 0.0))
	settled_total = int(d.get("settled_total", 0))
	tips = d.get("tips", {})
	road_cells = int(d.get("road_cells", 0))
	events = d.get("events", [])
	StoryDefs.migrate_events(events)             # колокольчик: «Где Мурка?» → «Где Мася?» (Д15), как журнал
	fest_left = maxi(0, int(d.get("fest_left", 0)))
	fest_cd = maxi(0, int(d.get("fest_cd", 0)))
	name = String(d.get("name", ""))             # старые сохранения — без названия: его скажет сервер
	# старые сохранения — без econ_v: счастье по прежним правилам (лавки и украшения без «повторов»), пока владелец не скажет «да»
	econ = int(d.get("econ_v", 0))
	decor_v = int(d.get("decor_v", 0))           # старые сохранения — все прежние облики украшений открыты, как были
	story_v = int(d.get("story_v", 0))           # старые сохранения — «Пост вигилов» за очки, как был
	taxes = {}
	var tx = d.get("taxes", {})
	if typeof(tx) == TYPE_DICTIONARY:
		for cl in tx:
			if Defs.CLASSES.has(String(cl)) and int(tx[cl]) != 1:
				taxes[String(cl)] = clampi(int(tx[cl]), 0, Defs.TAX_SET.size() - 1)
	hist = []
	var hs = d.get("hist", [])
	if typeof(hs) == TYPE_ARRAY:
		for row in hs:
			if typeof(row) == TYPE_ARRAY:
				hist.append((row as Array).map(func(x): return int(x)))
	hist = hist.slice(maxi(0, hist.size() - Defs.HIST_N))
	hist_acc = {}
	hist_mark = NAN
	stories = stories_load(d.get("stories", {}))  # старые сохранения — историй ещё не было: часы с нуля, ничего не идёт
	for sid in stories["done"]:
		var su := String((StoryDefs.story(sid).get("reward", {}) as Dictionary).get("unlock", ""))
		if su != "":
			research[su] = true                  # украшение-награда истории остаётся открытым
	# старые сохранения: своя земля с начала была 4×4 участка — купленные сверх них (земля загружена раньше города)
	plots_bought = maxi(0, int(d.get("plots_bought", land.owned.size() - Land.OLD_PLOTS)))
	_drop_roads2()
	legion.from_dict(d.get("legion", {}))
	hero = Hero.norm(d.get("hero", {}))           # старые сохранения — героя ещё нет: его создаст игра (Game._hero_check)
	cats = []
	var cl = d.get("cats", [])
	if typeof(cl) == TYPE_ARRAY:
		for e in cl:
			if typeof(e) == TYPE_DICTIONARY:
				var ce := {"nm": String(e.get("nm", "")), "sx": int(e.get("sx", 1)), "fur": int(e.get("fur", 0)), "home": int(e.get("home", -1)),
					"sd": int(e.get("sd", 1))}
				cat_items_load(e, ce)            # вещицы из «Кошачьей лавки» (Д14); старые сохранения — без них
				cats.append(ce)
	next_id = int(d.get("next_id", 1))
	buildings = {}
	land.under.clear()
	for bd in d.get("buildings", []):
		var c64 := String(bd.get("cells", ""))
		var cells := Marshalls.base64_to_raw(c64).to_int32_array() if c64 != "" else PackedInt32Array()
		var b := {"id": int(bd["id"]), "type": bd["type"], "tier": int(bd["tier"]), "pos": Vector2(float(bd["x"]), float(bd["z"])),
			"yaw": float(bd["yaw"]), "variant": int(bd.get("variant", 0)), "color": int(bd.get("color", 0)), "y": float(bd.get("y", Land.BASE_Y)),
			"cells": cells, "pop": int(bd["pop"]), "families": bd.get("families", []), "happy": 50, "up": 0, "down": 0, "staff": 1.0,
			"active": true, "road": true, "needs": {}, "served": 0, "score": {}, "missing": [], "coming": 0,
			"born": int(bd.get("born", bd["id"]))}         # старые сохранения: порядок постройки — по номеру
		if int(bd.get("host", -1)) >= 0:
			b["host"] = int(bd["host"])
		if int(bd.get("hire", -1)) >= 0:
			b["hire"] = int(bd["hire"])
		buildings[b["id"]] = b
		for k in cells:
			if land.occ[k] >= 0:               # арка у въезда остаётся занятой, даже если старое сохранение залезло на неё
				land.occ[k] = b["id"]
		_under_add(b)                          # полоса под арками акведука — заново (не сохраняется)
		next_id = maxi(next_id, int(b["id"]) + 1)
	legion.sync_tiers()                          # облик зданий Легиона — по их уровням (старые сохранения: уровни войск)
	apron_all()
	compute()
	# летопись: старое сохранение без неё — счётчики из того, что стоит, заслуженные венки разом (одна строка)
	chron = Chronicle.load_from(d.get("chron"))
	if chron.is_empty():
		Chronicle.migrate(self)
	# старое сохранение (до пометок «НОВОЕ»): всё, что уже открыто, — «видели», новым ничего не горит
	if not tips.has("seen"):
		seed_seen()
