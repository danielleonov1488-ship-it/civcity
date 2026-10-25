class_name Stories
extends Node
## «Истории горожан» (этап 4, решение владельца Д7): житель просит о помощи — над его домом свиток, наверху
## «Просьб горожан» золотая строка; щёлкнул — короткий ролик с облачком (портрет, имя, текст), выбор; дальше — шаг
## за шагом (найти кошку, поставить скамейки…), с подсказками, если долго не выходит; в конце — ролик и награда
## (не деньги: украшение, счастье, очки исследований). Одна история за раз; первая — через FIRST_H часов после обучения,
## дальше — GAP_H часов между историями; «Отложить» — снова через сутки. Всплывашек нет: события — в колокольчик,
## новое объясняет советник один раз.
## Данные историй — StoryDefs, состояние — city.stories (сохраняется), ролики — CineKit, облачко и журнал — StoryUi.
## Ролики не мешают игроку: начинаются только по его щелчку; пока идёт ролик, rank_cine.calm() — false.

const POLL := 0.5                      # как часто проверять предложение и шаги, с
const CLICK_PX := 34.0                 # щелчок по кошке — в стольких точках от неё
const MEOW := [20.0, 40.0]             # кошка мяукает раз в 20–40 с (при скорости ×1)
const KID_CALL_H := 2                  # мальчик зовёт кошку раз в 2 игровых часа
const BUILD_GLOW := 0.3               # пятно «где строить» (скверик, сад, новый дом) — мягче, чем место поисков
const FILL := 0.55                     # свет-заполнение на лица героев ролика
const PROC_LEN := 15.0                 # свадебное шествие: столько метров пути до нового дома
const PROC_V := 1.2                    # шаг шествия, м/с
const DUSK := 21.2                     # «вечер» в свадебном ролике: такой свет (часы игры не трогаем)
const TIER := ["нет", "бронза", "серебро", "золото"]
## Шествие: кто где идёт — [роль, сколько метров позади пары, в сторону]
const PROC := [["bride", 0.0, 0.42], ["groom", 0.0, -0.42], ["mother", -1.4, 0.3], ["guest1", -2.3, -0.5], ["guest2", -2.4, 0.55],
	["guest3", -3.3, 0.0]]
const WAIT_HOME_H := 24                # семья без дома (снесли): столько часов ждём, пока заселится, потом история прерывается

var game
var hud
var city: City
var ui: StoryUi
var life: StoryLife                    # старики в скверике и за столом латрункулов
var force := false                     # проверки: истории и когда игра — не главная сцена
var kit: CineKit = null                # идёт ролик
var cine := {}                         # ролик: такты, где он, кто в кадре, выбор, что потом
var cat := {}                          # кошка, которую ищут (запись в people.cats)
var _poll := 0.0
var _h_seen := -1
var _meow_t := 10.0
var _sit_t := 0.0                      # кошка мяукнула — сидит, потом снова спит
var _glow: Node3D = null               # пятно поисков: Decal (Forward+, Mobile) или сетка по земле (OpenGL — там Decal нет)
var _glow_key := ""
var _glow_r := 0.0                     # радиус пятна сейчас (0 — нет)
var _glow_edge := false                # пятно с чёткой границей (в руках то, что идёт в счёт цели)
const EDGE_OUT := 0.5                  # чёткая граница: свет гаснет к R + 0,5 м…
const EDGE_AL := 0.22                  # …а внутри — ровный, такой яркости
var _paws: Array = []
var _paws_key := ""
var _no_decals := RenderingServer.get_current_rendering_method() == "gl_compatibility"
var _spot_cache := {}                  # «история:дом:час» → где кошке спрятаться (INF — негде)
var _hidden: Array = []                # прохожие, спрятанные на время ролика (заслоняли героя)
var _tried := ""                       # с чем последний раз искали, кому предложить историю


func setup(g) -> void:
	game = g
	hud = g.hud
	city = g.city
	ui = StoryUi.new(self)
	life = StoryLife.new()
	add_child(life)
	life.setup(self)
	city.building_removed.connect(_on_removed)
	city.family_left.connect(_on_family_left)
	if game.mode in ["new", "play"]:
		_restore()


## Где истории бывают: своя игра (новая или загруженная), не снимок, не автопроверка, не тестовая сцена
func allowed() -> bool:
	if game == null or not game.ready_done or game.rig == null:
		return false
	if not (game.mode in ["new", "play"]) or game.shot_path != "" or QaDrive._inst != null:
		return false
	return force or game == get_tree().current_scene


## Идёт ролик истории
func busy() -> bool:
	return kit != null


func S() -> Dictionary:
	return city.stories


# ---------- после загрузки: кошки-награды, кошка, которую ищут ----------

func _restore() -> void:
	var s := S()
	for p: Dictionary in s["pets"]:
		var h: Dictionary = city.buildings.get(int(p.get("home", -1)), {})
		if h.is_empty():
			h = city.center()
		if not h.is_empty():
			game.people.pet_cat(h, int(p.get("fur", 0)), String(p.get("name", "")), int(p.get("seed", 1)))
	# кошка живёт, пока её не забрали домой (_after_final): и пока ищут, и когда нашли, а ролик встречи ещё ждёт щелчка
	var a: Dictionary = s["active"]
	if not a.is_empty() and a.has("spot"):
		_spawn_cat(a)


# ---------- каждый кадр: ролик, кошка мяукает ----------

func _process(dt: float) -> void:
	if kit != null:
		if float(game._min_speed) >= 0.0:
			return                       # окно свёрнуто: ролик ждёт игрока
		var d := minf(dt, 0.05)
		kit.tick(d)
		if kit != null and kit.phase == "run":
			_beat_tick(d)
		return
	if game == null or not game.ready_done or city == null:
		return
	if not _flash.is_empty() and Time.get_ticks_msec() > _flash_until:
		_flash_clear()                   # ✓ над тем, что в счёт, — гаснут через 3 с
	_live(dt * float(game.speed))
	_poll += dt
	if _poll < POLL:
		return
	_poll = 0.0
	tick()


## Кошка мяукает (тихо, в мире — слышно, только если камера рядом) и над ней «мяу!»
func _live(sdt: float) -> void:
	if cat.is_empty() or sdt <= 0.0 or not allowed():
		return
	if _sit_t > 0.0:
		_sit_t -= sdt
		if _sit_t <= 0.0 and cat.has("story"):
			cat["state"] = "sleep"
	_meow_t -= sdt
	if _meow_t <= 0.0:
		meow()


func meow() -> void:
	_meow_t = randf_range(MEOW[0], MEOW[1])
	if cat.is_empty():
		return
	cat["state"] = "sit"
	_sit_t = 3.5
	if game.sound and cat.has("snd"):
		game.sound.cat(cat["snd"])
	ui.bubble3d(_cat_pos() + Vector3(0, 0.55, 0), "мяу!", 2.6, 26)


## Раз в POLL: часы, предложение, шаги, значки
func tick() -> void:
	if not allowed():
		_marks(false)
		return
	var s := S()
	var h := int(s["h"])
	if h != _h_seen:
		var first := _h_seen < 0
		_h_seen = h
		if not first:
			_on_hour()
	if not (s["active"] as Dictionary).is_empty():
		_tick_active()
	elif not (s["offer"] as Dictionary).is_empty():
		_tick_offer()
	elif time_ok():
		_try_offer()
	_marks(true)
	_advise_once()
	_advise_square()


## Пора предложить новую историю: обучение кончилось, прошло FIRST_H (первая) или GAP_H (после прошлой)
func time_ok() -> bool:
	if int(city.tips.get("tut", -1)) >= 0 or hud.ui_level() < 3:
		return false
	var s := S()
	# «Отложить» (и снятое предложение) — пауза для всех историй, а не только для этой: сказали «не сейчас» — не просим
	# тут же о другом; пауза кончилась — первой снова та, что отложили
	for t in (s["later"] as Dictionary).values():
		if int(s["h"]) < int(t):
			return false
	if int(s["last_h"]) < 0:
		return int(s["h"]) >= StoryDefs.FIRST_H
	return int(s["h"]) - int(s["last_h"]) >= StoryDefs.GAP_H


# ---------- предложение ----------

func _try_offer() -> void:
	var s := S()
	# пробуем, когда что-то поменялось: час, ранг, жители (а не каждые полсекунды)
	var key := "%d|%d|%d|%d" % [int(s["h"]), city.level, int(city.stats.get("pop", 0)), city.buildings.size()]
	if key == _tried:
		return
	_tried = key
	for sd: Dictionary in StoryDefs.all():
		var id := String(sd["id"])
		if (s["done"] as Dictionary).has(id):
			continue
		if (s["later"] as Dictionary).has(id) and int(s["h"]) < int(s["later"][id]):
			continue
		var bind := can_offer(sd)
		if bind.is_empty():
			continue
		bind["id"] = id
		bind["since"] = int(s["h"])
		s["offer"] = bind
		(s["later"] as Dictionary).erase(id)
		city._quiet(StoryDefs.fill(String(sd.get("ask", sd["title"])), bind), String(sd.get("icon", "scroll")))
		hud.refresh()
		return


## Можно ли предложить историю сейчас (ранг, жители, есть кого просить и её правда можно пройти) — привязка или {}
func can_offer(sd: Dictionary) -> Dictionary:
	if city.level < int(sd.get("lvl", 0)) or int(city.stats.get("pop", 0)) < int(sd.get("pop", 0)):
		return {}
	for r in sd.get("needs", []):
		if not city.research.has(r):
			return {}
	for np: Array in sd.get("need_p", []):
		if city.progress_of(np[0]) < int(np[1]):
			return {}
	var fo := StoryDefs.find_opts(sd)
	var room: Array = sd.get("space", [])
	# сначала — семьи, которые ещё ни о чём не просили (разные истории — у разных соседей)
	var asked := {}
	for e: Dictionary in (S()["done"] as Dictionary).values():
		asked[String(e.get("fam", ""))] = true
	var fresh := []
	var again := []
	for e: Dictionary in _cast(sd):
		(again if asked.has(String(e.get("fam", ""))) else fresh).append(e)
	for bind: Dictionary in (fresh + again).slice(0, 4 if not fo.is_empty() else 8):
		bind["id"] = String(sd["id"])        # тот же посев _rng, что в _start_find: проверяем то самое место
		if not room.is_empty() and free_near(_home_pos(bind), float(room[0])) < int(room[1]):
			continue                         # вокруг всё застроено: скверик или новый дом ставить негде
		var sp := Vector2.INF if fo.is_empty() else _spot_for(bind, fo)
		if fo.is_empty() or sp != Vector2.INF:
			if sp != Vector2.INF:
				bind["spot0"] = [sp.x, sp.y]
			if bind.has("fam"):
				bind["seed"] = _fair_seed(hash(String(bind["fam"])) & 0xffffff)
			if not _bind_roles(sd, bind):
				continue
			return bind
	return {}


## Свободной земли (м², по точкам через 2 м) в r м от p: своя земля, не постройка, не дорога, не вода
func free_near(p: Vector2, r: float) -> int:
	var land: Land = game.land
	var n := 0
	var k := int(r / 2.0)
	for j in range(-k, k + 1):
		for i in range(-k, k + 1):
			var q := p + Vector2(i, j) * 2.0
			if Vector2(i, j).length() * 2.0 > r or not land.is_owned(q) or land.occ_at(q) != 0 or land.is_water(q) or land.is_road(q):
				continue
			n += 4
	return n


## Кто ещё в истории (свадьба): жених из соседнего дома, мать и гости — облик по семье, имя — StoryDefs.roles.
## Пишет bind["roles"] {роль: {seed, female, child, cls, old}}; false — некого позвать (жениха нет)
func _bind_roles(sd: Dictionary, bind: Dictionary) -> bool:
	var cast: Dictionary = sd.get("cast", {})
	if cast.size() <= 1 and not sd.has("extras"):
		return true
	var fam := String(bind.get("fam", ""))
	var roles := {}
	var keys := cast.keys()
	var r0: Dictionary = cast[keys[0]]
	roles[keys[0]] = {"seed": int(bind.get("seed", 1)), "female": bool(r0.get("female", false)), "child": false, "cls": String(bind.get("cls", "plebs")),
		"old": bool(r0.get("old", false))}
	for k in keys.slice(1):
		var r: Dictionary = cast[k]
		if not bool(r.get("other", false)):
			continue
		var o := _other_family(bind)
		if o.is_empty():
			return false
		bind["home2"] = int(o["home"])
		bind["fam2"] = String(o["fam"])
		roles[k] = {"seed": _fair_seed(hash(String(o["fam"])) & 0xffffff), "female": bool(r.get("female", false)), "child": false,
			"cls": String(o["cls"])}
	var ex: Dictionary = sd.get("extras", {})
	for k in ex:
		roles[k] = {"seed": _fair_seed(hash(fam + ":" + String(k)) & 0xffffff), "female": bool(ex[k].get("female", false)),
			"child": bool(ex[k].get("child", false)), "cls": String(bind.get("cls", "plebs"))}
	bind["roles"] = roles
	return true


## Соседняя семья (в другом доме, до 70 м — ближняя): {home, fam, cls} или {}
func _other_family(bind: Dictionary) -> Dictionary:
	var hp := _home_pos(bind)
	var best := {}
	var bd := 70.0
	for id in city.buildings:
		var b: Dictionary = city.buildings[id]
		if int(id) == int(bind.get("home", -1)) or not city.is_house(b) or int(b["pop"]) <= 0:
			continue
		var d := (b["pos"] as Vector2).distance_to(hp)
		if d >= bd:
			continue
		for f: Dictionary in b["families"]:
			if String(f["name"]) != String(bind.get("fam", "")):
				bd = d
				best = {"home": int(id), "fam": String(f["name"]), "cls": String(city.def(b)["cls"])}
				break
	return best


## Где кошке спрятаться у этого дома (INF — негде; поиск пути — дорогой: ответ помним до конца игрового часа)
func _spot_for(bind: Dictionary, fo: Dictionary) -> Vector2:
	var key := "%s:%d:%d" % [String(bind.get("id", "")), int(bind["home"]), int(S()["h"])]
	if not _spot_cache.has(key):
		if _spot_cache.size() > 64:
			_spot_cache.clear()
		var home: Dictionary = city.buildings[int(bind["home"])]
		_spot_cache[key] = game.people.hide_spot(city.door_point(home), float(fo["rmin"]), float(fo["rmax"]), fo.get("hide", []), _rng(bind, 1))
	return _spot_cache[key]


## Кого просить: дома нужного класса, где живёт семья с ребёнком, — ближние к станции первыми; [{home, fam, kid, seed…}]
func _cast(sd: Dictionary) -> Array:
	var cast: Dictionary = sd.get("cast", {})
	var ctr := city.center()
	if cast.is_empty():
		return [] if ctr.is_empty() else [{"home": int(ctr["id"]), "fam": "", "kid": ""}]
	var role: Dictionary = cast.values()[0]
	var clss := String(role.get("cls", "plebs")).split("|")
	var child := bool(role.get("child", false))
	var c0: Vector2 = ctr["pos"] if not ctr.is_empty() else Land.CENTER
	var kids := {}                       # «семья|дом» — у кого есть ребёнок (один проход по жителям)
	if child:
		for r in game.people.residents:
			if bool(r["child"]):
				kids["%s|%d" % [r["fam"], int(r["home"])]] = true
	var out := []
	for id in city.buildings:
		var b: Dictionary = city.buildings[id]
		if not city.is_house(b) or not (String(city.def(b)["cls"]) in clss) or int(b["pop"]) <= 0:
			continue
		for f: Dictionary in b["families"]:
			var fam := String(f["name"])
			if child and not kids.has("%s|%d" % [fam, int(id)]):
				continue
			var e := {"home": int(id), "fam": fam, "kid": StoryDefs.boy(fam), "cls": String(city.def(b)["cls"]), "female": bool(role.get("female", false)),
				"child": child, "d": (b["pos"] as Vector2).distance_to(c0)}
			if bool(role.get("old", false)):
				e["old"] = true
			out.append(e)
	out.sort_custom(func(x, y): return float(x["d"]) < float(y["d"]))
	for e: Dictionary in out:
		e.erase("d")
	return out


## Облик героя ролика: светлый вариант палитры Synty (у тёмных вблизи нарисована щетина — ребёнку не к лицу).
## Citizen.create берёт из rng сначала модель, потом вариант (A, A, B, C)
static func _fair_seed(s0: int) -> int:
	var r := RandomNumberGenerator.new()
	for k in 64:
		r.seed = s0 + k
		r.randi()
		if r.randi() % 4 < 2:
			return s0 + k
	return s0


func _rng(bind: Dictionary, salt := 0) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([int(bind.get("home", 0)), String(bind.get("fam", "")), String(bind.get("id", "")), salt])
	return r


## Предложение ещё в силе: дом стоит, семья живёт в нём
func _tick_offer() -> void:
	var o: Dictionary = S()["offer"]
	if city.moving_id >= 0 and city.moving_id == int(o.get("home", -1)):
		return                           # дом переносят — предложение поедет за ним (City._story_rehome)
	if StoryDefs.story(String(o.get("id", ""))).is_empty() or not _lives(o):
		_drop_offer()


## Просящего больше нет (дом снесли, семья уехала): предложение снимаем молча; эту историю — не сразу другому
func _drop_offer() -> void:
	var s := S()
	var o: Dictionary = s["offer"]
	if o.is_empty():
		return
	s["later"][String(o.get("id", ""))] = int(s["h"]) + StoryDefs.FIRST_H
	s["offer"] = {}
	_marks(true)
	hud.refresh()


func _lives(b: Dictionary) -> bool:
	var h: Dictionary = city.buildings.get(int(b.get("home", -1)), {})
	if h.is_empty():
		return false
	if String(b.get("fam", "")) == "":
		return true
	for f: Dictionary in h["families"]:
		if String(f["name"]) == String(b["fam"]):
			return true
	return false


## «Отложить»: снова через сутки
func postpone() -> void:
	var s := S()
	var o: Dictionary = s["offer"]
	if o.is_empty():
		return
	s["later"][String(o["id"])] = int(s["h"]) + StoryDefs.LATER_H
	s["offer"] = {}
	_marks(true)
	hud.refresh()


## Игрок щёлкнул свиток над домом (или «Выслушать»): ролик просьбы, в конце — выбор
func open_offer() -> void:
	var o: Dictionary = S()["offer"]
	if o.is_empty() or not can_start():
		return
	var sd := StoryDefs.story(String(o["id"]))
	var steps: Array = sd["steps"]
	_play(sd, o, (steps[0] as Dictionary).get("cine", []), "ask", _after_ask)


func _after_ask() -> void:
	var o: Dictionary = S()["offer"]
	if o.is_empty():
		return
	var ch := String(cine.get("choice", "go"))
	if ch == "later":
		postpone()
		return
	accept(ch)


## Согласились помочь: история идёт, со второго шага; choice — что выбрали в ролике (сад или таверна)
func accept(choice := "go") -> void:
	var s := S()
	var o: Dictionary = s["offer"]
	if o.is_empty():
		return
	var a := o.duplicate(true)
	a["flags"] = {}
	a["step"] = 0
	s["active"] = a
	s["offer"] = {}
	if not (choice in ["go", ""]):
		_choose(a, choice)
	_enter_step(1)
	hud.refresh()


## Выбор сделан (в ролике или в золотой строке): запомнить; что история открывает сразу (арка из роз) — открыть.
## С этой минуты считается «новый дом» (built_after): построили его для молодых сразу, ещё до пира, — он в счёт;
## передумали в золотой строке — отсчёт не сдвигается
func _choose(a: Dictionary, val: String) -> void:
	var flags: Dictionary = a["flags"]
	flags["choice"] = val
	if not flags.has("after"):
		flags["after"] = city.next_id
	var u := String((_story(a).get("grant", {}) as Dictionary).get(val, ""))
	if u != "" and not city.research.has(u):
		city.research[u] = true
		for t in Defs.B:
			if String(Defs.B[t].get("unlock", "")) == u:
				city._quiet("Открыто украшение «%s» (Украшения) — для истории «%s»." % [Defs.B[t]["name"], _story(a)["title"]], "decor")
				break


# ---------- шаги ----------

func _story(a: Dictionary) -> Dictionary:
	return StoryDefs.story(String(a.get("id", "")))


func _step(a: Dictionary) -> Dictionary:
	var steps: Array = _story(a).get("steps", [])
	var i := int(a.get("step", 0))
	return steps[i] if i >= 0 and i < steps.size() else {}


func _goal_kind(a: Dictionary) -> String:
	var g: Array = _step(a).get("goal", [])
	return "" if g.is_empty() else String(g[0])


## Всё сделано: остался последний ролик (ждёт щелчка «Посмотреть»)
func _final_ready(a: Dictionary) -> bool:
	return bool(a.get("ready", false)) and int(a.get("step", 0)) >= (_story(a).get("steps", []) as Array).size() - 1


func _enter_step(i: int) -> void:
	var a: Dictionary = S()["active"]
	var steps: Array = _story(a)["steps"]
	if i >= steps.size():
		_finish("done")
		return
	a["step"] = i
	a["t0"] = int(S()["h"])
	a["id0"] = city.next_id
	a.erase("ready")
	var st: Dictionary = steps[i]
	if st.has("goal"):
		if String(st["goal"][0]) == "find":
			_start_find(a, st["goal"][2])
	elif st.has("cine"):
		a["ready"] = true                # ролик-шаг ждёт щелчка игрока (свиток над домом, «Посмотреть»)


## Найти: где кошка прячется, место поисков (пятно света вокруг, не по центру кошки), кошка
func _start_find(a: Dictionary, o: Dictionary) -> void:
	var home: Dictionary = city.buildings.get(int(a["home"]), {})
	var door: Vector2 = city.door_point(home) if not home.is_empty() else (city.center()["pos"] as Vector2)
	var rg := _rng(a, 1)
	var spot: Vector2 = game.people.hide_spot(door, float(o["rmin"]), float(o["rmax"]), o.get("hide", []), rg)
	if spot == Vector2.INF and a.has("spot0"):
		# с предложения город поменялся: место, проверенное тогда, ещё годится?
		var s0 := Vector2(float(a["spot0"][0]), float(a["spot0"][1]))
		var d0 := s0.distance_to(door)
		if d0 >= float(o["rmin"]) and d0 <= float(o["rmax"]) and game.people._hide_ok(s0) and game.people._path(door, s0).size() >= 2:
			spot = s0
	if spot == Vector2.INF:
		spot = game.people._near_free(door + City.facing(float(home.get("yaw", 0.0))) * 6.0, 40)
	if spot == Vector2.INF:
		_cancel("Кошка нашлась сама — спряталась прямо у порога.")
		return
	a["spot"] = [spot.x, spot.y]
	for k in 2:
		var r := float(o["ring"] if k == 0 else o["ring2"])
		var ang := rg.randf() * TAU
		var c := spot + Vector2(cos(ang), sin(ang)) * r * rg.randf_range(0.25, 0.5)
		a["area%d" % k] = [c.x, c.y, r]
	a["cat_name"] = String(o.get("name", "Мурка"))
	a["fur"] = int(o.get("fur", 0))
	_spawn_cat(a)
	_meow_t = 6.0
	_call_kid(a)


func _spawn_cat(a: Dictionary) -> void:
	if not cat.is_empty():
		game.people.drop_cat(cat)
	var home: Dictionary = city.buildings.get(int(a.get("home", -1)), city.center())
	var sp: Array = a["spot"]
	cat = game.people.story_cat(home, Vector2(float(sp[0]), float(sp[1])), int(a.get("fur", 0)), hash(a.get("fam", "")) & 0xffff)
	cat["yaw"] = _rng(a, 2).randf() * TAU


## Мальчик у дома зовёт кошку (маленькая подпись над ним; без всплывашек)
func _call_kid(a: Dictionary) -> void:
	var home: Dictionary = city.buildings.get(int(a.get("home", -1)), {})
	if home.is_empty():
		return
	var dp: Vector2 = city.door_point(home)
	var name := String(a.get("cat_name", "Мурка"))
	ui.bubble3d(Vector3(dp.x, game.land.height_at(dp.x, dp.y) + 1.6, dp.y), "%s! Кис-кис-кис!" % name, 4.0, 28)


## Часы историй: подсказки, след лапки, мальчик сам нашёл (find), ожидание (wait), семья без дома
func _on_hour() -> void:
	var s := S()
	var a: Dictionary = s["active"]
	if a.is_empty():
		return
	var hours := int(s["h"]) - int(a.get("t0", s["h"]))
	if a.has("homeless") and int(s["h"]) - int(a["homeless"]) >= WAIT_HOME_H:
		_cancel("Семья %s так и не нашла новый дом." % StoryDefs.fam_gen(String(a.get("fam", ""))))
		return
	if _goal_kind(a) == "find":
		var o: Dictionary = _step(a)["goal"][2]
		if hours >= int(o.get("giveup_h", 12)):
			_give_up()
			return
		if hours > 0 and hours % KID_CALL_H == 0:
			_call_kid(a)
		hud.refresh()


## play_now — игрок сам нажал «Готово»: ролик-шаг — сразу
func _tick_active(play_now := false) -> void:
	var s := S()
	var a: Dictionary = s["active"]
	if _story(a).is_empty():
		s["active"] = {}
		return
	if not cat.is_empty() and a.has("spot"):
		var cp: Vector2 = cat["p"]
		a["spot"] = [cp.x, cp.y]         # на кошку поставили постройку — она перебралась рядом
	if _final_ready(a):
		a.erase("homeless")              # всё сделано, осталось посмотреть ролик: дом семьи для этого не нужен
		return
	# дом семьи: перенесли — история идёт за ним (City._story_rehome); снесли — ждём, пока семья заселится
	if not _lives(a):
		if city.moving_id == int(a.get("home", -1)):
			return
		var nh := _find_family(String(a.get("fam", "")))
		if nh >= 0:
			a["home"] = nh
			a.erase("homeless")
		elif not _family_in_city(String(a.get("fam", ""))):
			_cancel("Семья %s уехала из города." % StoryDefs.fam_gen(String(a.get("fam", ""))))
			return
		elif not a.has("homeless"):
			a["homeless"] = int(s["h"])
			city._quiet("История «%s» ждёт: дом семьи %s снесли. Когда семья заселится в новый дом, история продолжится." \
				% [_story(a)["title"], StoryDefs.fam_gen(String(a.get("fam", "")))], "scroll")
			hud.refresh()
	if a.get("ready", false) or a.has("homeless"):
		return                           # семья без дома — история ждёт: цели не меряем (иначе мерили бы от станции)
	var st := _step(a)
	if not st.has("goal") or _goal_kind(a) == "find":
		return
	var pr := progress(a, st["goal"])
	if bool(pr["ok"]):
		if _goal_kind(a) == "square":
			var sq := square_center(a, float(st["goal"][1]))
			var at := _home_pos(a)
			(a["flags"] as Dictionary)["sq"] = [sq.x, sq.y]
			(a["flags"] as Dictionary)["sq_at"] = [at.x, at.y]   # откуда мерили скверик (для «памятника»)
		if String(st.get("done", "")) == "couple":
			_couple(a)
		_advance(play_now)


## Свадьба: новый дом построен — молодые сразу в нём поселяются (пока его не заняли другие). Новая семья — по роду
## жениха; с повозки не приезжала (повозки от этого чаще не ходят); облик — как у жениха и невесты в роликах
func _couple(a: Dictionary) -> void:
	var flags: Dictionary = a["flags"]
	var hid := int(flags.get("built", -1))
	var h: Dictionary = city.buildings.get(hid, {})
	if h.is_empty() or a.has("couple"):
		return
	var nm := _couple_name(String(a.get("fam2", a.get("fam", ""))))
	city.pending[nm] = {"name": nm, "n": 2, "cls": String(city.def(h)["cls"]), "home": hid, "back": true}
	if city.settled(hid, 2, nm) <= 0:
		city.pending.erase(nm)
		return
	a["couple"] = nm
	var roles: Dictionary = a.get("roles", {})
	var fam: Array = game.people._make_family(nm, 2, hid, city.door_point(h))
	for i in fam.size():
		var ro: Dictionary = roles.get("groom" if i == 0 else "bride", {})
		if not ro.is_empty():
			(fam[i] as Dictionary)["seed"] = int(ro["seed"])
			(fam[i] as Dictionary)["female"] = i == 1
	city._quiet("Юлия и Марк поселились в новом доме — теперь это семья %s. Свадьбу сыграют вечером: посмотрите шествие!" \
		% StoryDefs.fam_gen(nm), "ring")


## Имя новой семьи: род жениха и своё прозвище («Валерии Руфы»), какого в городе ещё нет
func _couple_name(fam: String) -> String:
	var f := StoryDefs._fam1(fam)
	if f == "":
		f = "Юлии"
	var used := {}
	for id in city.buildings:
		for fm: Dictionary in city.buildings[id].get("families", []):
			used[String(fm["name"])] = true
	for fm: Dictionary in city.arrivals:
		used[String(fm["name"])] = true
	for k in city.pending:
		used[String(k)] = true
	var k0 := hash(fam) % Defs.COGNOMENS.size()
	for i in Defs.COGNOMENS.size():
		var nm := "%s %s" % [f, Defs.COGNOMENS[(k0 + i) % Defs.COGNOMENS.size()]]
		if not used.has(nm):
			return nm
	return "%s Младшие" % f


## Где новый дом молодых (свадьба): построенный для них, тот, где они живут теперь, или дом невесты
func _built_pos(a: Dictionary) -> Vector2:
	var h: Dictionary = city.buildings.get(int((a.get("flags", {}) as Dictionary).get("built", -1)), {})
	if h.is_empty() and String(a.get("couple", "")) != "":
		h = city.buildings.get(_find_family(String(a["couple"])), {})
	return h["pos"] if not h.is_empty() else _home_pos(a)


## Цель шага выполнена: следующий шаг; ролик-шаг — сразу (по щелчку игрока) или ждёт щелчка
func _advance(play_now: bool) -> void:
	var a: Dictionary = S()["active"]
	var steps: Array = _story(a)["steps"]
	var i := int(a["step"]) + 1
	if i >= steps.size():
		_finish("done")
		return
	var st: Dictionary = steps[i]
	if st.has("cine") and not st.has("goal"):
		a["step"] = i
		a["ready"] = true
		if play_now:
			play_ready()
		else:
			hud.refresh()
		return
	_enter_step(i)
	hud.refresh()


## Ролик-шаг, которого ждут (щёлкнули свиток или «Посмотреть»): награда (если он последний) — сразу, потом ролик
func play_ready() -> void:
	var s := S()
	var a: Dictionary = s["active"]
	if a.is_empty() or not a.get("ready", false) or not can_start():
		return
	var sd := _story(a)
	var steps: Array = sd["steps"]
	var i := int(a["step"])
	var beats: Array = (steps[i] as Dictionary).get("cine", [])
	if cat.is_empty() and a.has("spot"):
		_spawn_cat(a)                    # кошка — в кадре встречи (и потом — домой, к семье)
	var bind := a.duplicate(true)
	if i >= steps.size() - 1:
		_finish("found")                 # действие — сразу: пропустят ролик или выйдут из игры — награда уже есть
		_play(sd, bind, beats, "final", _after_final)
	else:
		a.erase("ready")
		_play(sd, bind, beats, "step", func(): _enter_step(i + 1))


func _after_final() -> void:
	if not cat.is_empty():
		var b: Dictionary = cine.get("bind", {})
		game.people.free_cat(cat, int(b.get("home", -1)), String(b.get("cat_name", "")))
		cat = {}


## Щелчок по миру без инструмента: кошка (в CLICK_PX точек от неё) — нашли. true — щелчок забран
func try_click(mp: Vector2) -> bool:
	if kit != null or cat.is_empty() or not allowed() or game.rig == null:
		return false
	var a: Dictionary = S()["active"]
	if a.is_empty() or _goal_kind(a) != "find":
		return false
	if not near_cat(mp):
		return false
	found()
	return true


## Мышь над кошкой (курсор-«рука»)
func near_cat(mp: Vector2) -> bool:
	if cat.is_empty() or game.rig == null:
		return false
	var cam: Camera3D = game.rig.cam
	var w := _cat_pos() + Vector3(0, 0.18, 0)
	if cam.is_position_behind(w):
		return false
	return cam.unproject_position(w).distance_to(mp) <= CLICK_PX


## Кошку нашли: ролик встречи (награда — сразу)
func found() -> void:
	var a: Dictionary = S()["active"]
	if a.is_empty() or _goal_kind(a) != "find":
		return
	(a["flags"] as Dictionary)["found"] = true
	_advance(true)


## Мальчик нашёл кошку сам (долго искали): без очков исследований, без ролика — только колокольчик
func _give_up() -> void:
	var a: Dictionary = S()["active"]
	var st := _step(a)
	var steps: Array = _story(a)["steps"]
	a["step"] = steps.size() - 1
	var text := StoryDefs.fill(String(st.get("giveup", "")), a)
	_finish("self", text)
	if not cat.is_empty():
		game.people.free_cat(cat, int(a.get("home", -1)), String(a.get("cat_name", "")))
		cat = {}


## История пройдена: награда, в журнал, часы до следующей пошли. full — с очками исследований (не сам нашёл)
func _finish(how: String, text := "") -> void:
	var s := S()
	var a: Dictionary = s["active"]
	if a.is_empty():
		return
	var sd := _story(a)
	var full := how != "self"
	var rw := _reward(sd, a, full)
	var e := {"day": city.day, "h": int(s["h"]), "home": int(a.get("home", -1)), "fam": a.get("fam", ""), "kid": a.get("kid", ""),
		"seed": int(a.get("seed", 1)), "cls": a.get("cls", "plebs"), "how": how, "cat_name": a.get("cat_name", ""), "fur": int(a.get("fur", 0))}
	if a.has("spot"):
		e["spot"] = a["spot"]
	for k in ["roles", "flags", "fam2", "home2", "couple", "old", "child", "female"]:
		if a.has(k):
			e[k] = a[k]                      # для «Пересмотреть»: кто был в роликах (и каков облик), что выбрали, где новый дом
	e["text"] = (text + " " if text != "" else "") + "Награда: " + rw + "."
	s["done"][String(sd["id"])] = e
	s["active"] = {}
	s["last_h"] = int(s["h"])
	city._quiet("История «%s» завершена. %s" % [sd["title"], e["text"]], String(sd.get("icon", "scroll")))
	city.compute()
	_marks(true)
	hud.refresh()


## Награда истории (без денег): украшение, счастье, очки исследований, Слава, кошка. Возвращает её описание
func _reward(sd: Dictionary, a: Dictionary, full: bool) -> String:
	var r: Dictionary = sd.get("reward", {})
	var s := S()
	var out := []
	var id := String(sd["id"])
	var line := String(sd.get("line", sd["title"]))
	var fam := String(a.get("fam", ""))
	if r.has("unlock"):
		city.research[String(r["unlock"])] = true
		for t in Defs.B:
			if String(Defs.B[t].get("unlock", "")) == String(r["unlock"]):
				out.append("украшение «%s» (Украшения)" % Defs.B[t]["name"])
				break
	if r.has("happy_home"):
		var hh: Array = r["happy_home"]
		var b := {"id": id, "line": line, "pct": int(hh[0]), "left": int(hh[1])}
		if fam != "":
			b["fam"] = fam               # бонус — семье: переедут — он с ними
		else:
			b["home"] = int(a.get("home", -1))
		(s["bonus"] as Array).append(b)
		out.append("дому %s +%d%% счастья на %s" % [StoryDefs.fam_gen(fam), int(hh[0]), _hours(int(hh[1]))])
	if r.has("happy_area"):
		var ha: Array = r["happy_area"]
		var hp := _built_pos(a) if ha.size() > 3 and String(ha[3]) == "built" else _home_pos(a)
		(s["bonus"] as Array).append({"id": id, "line": line, "pct": int(ha[0]), "x": hp.x, "z": hp.y, "r": float(ha[1]), "left": int(ha[2])})
		out.append("домам в %d м +%d%% счастья на %s" % [int(ha[1]), int(ha[0]), _hours(int(ha[2]))])
	if r.has("happy_all"):
		var hl: Array = r["happy_all"]
		(s["bonus"] as Array).append({"id": id, "line": line, "pct": int(hl[0]), "left": int(hl[1])})
		out.append("всем домам +%d%% счастья на %s" % [int(hl[0]), _hours(int(hl[1]))])
	if r.has("monument"):
		var mo: Array = r["monument"]
		var pct = mo[0]
		if pct is Array:
			pct = (pct as Array)[clampi(int((a.get("flags", {}) as Dictionary).get("tier", 1)) - 1, 0, (pct as Array).size() - 1)]
		var hp := _home_pos(a)
		var bn := {"id": id, "line": line, "pct": int(pct), "r": float(mo[1]), "left": -1}
		var sq: Array = (a.get("flags", {}) as Dictionary).get("sq", [])
		if mo.size() > 2 and String(mo[2]) == "square":
			# где мерили скверик: бонус — пока он там стоит (City.compute)
			bn["at"] = (a.get("flags", {}) as Dictionary).get("sq_at", [hp.x, hp.y])
			if sq.size() == 2:
				hp = Vector2(float(sq[0]), float(sq[1]))
		bn["x"] = hp.x
		bn["z"] = hp.y
		(s["bonus"] as Array).append(bn)
		out.append("домам в %d м +%d%% счастья %s" % [int(mo[1]), int(pct), "— пока стоит скверик" if bn.has("at") else "навсегда"])
	if r.has("rp") and full:
		var was := city.rp
		city.rp = maxf(city.rp, minf(city.rp_cap(), city.rp + float(r["rp"])))
		var got := int(round(city.rp - was))   # полки полны — пишем, сколько правда легло
		if got >= int(r["rp"]):
			out.append("+%d очков исследований" % got)
		elif got > 0:
			out.append("+%d очков исследований (больше не уместилось на полках)" % got)
		else:
			out.append("очки исследований не уместились — полки полны")
	if r.has("glory"):
		city.legion.glory += int(r["glory"])
		out.append("+%d Славы" % int(r["glory"]))
	if bool(r.get("family", false)) and String(a.get("couple", "")) != "":
		out.append("молодые живут своим домом — семья %s" % StoryDefs.fam_gen(String(a["couple"])))
	if int(r.get("cats", 0)) > 0:
		(s["pets"] as Array).append({"home": int(a.get("home", -1)), "fur": int(a.get("fur", 0)), "name": String(a.get("cat_name", "")),
			"seed": hash(fam) & 0xffff})
		out.append("ещё одна кошка в городе")
	return ", ".join(out) if not out.is_empty() else "радость горожан"


func _home_pos(a: Dictionary) -> Vector2:
	var h: Dictionary = city.buildings.get(int(a.get("home", -1)), {})
	return h["pos"] if not h.is_empty() else (city.center()["pos"] as Vector2)


static func _hours(h: int) -> String:
	if h % 24 == 0:
		var d := h / 24
		return "%d %s" % [d, Hud._plural(d, "день", "дня", "дней")]
	return "%d ч" % h


## История прервалась (дом снесли, семья уехала): колокольчик, кошку — прочь; часы до следующей пошли
func _cancel(why: String) -> void:
	var s := S()
	var a: Dictionary = s["active"]
	if a.is_empty():
		return
	if _final_ready(a):
		# всё уже сделано — оставалось посмотреть ролик: награду не отнимаем, ролик — в журнале («Пересмотреть»)
		_finish("found")
		if not cat.is_empty():
			if city.buildings.has(int(a.get("home", -1))):
				game.people.free_cat(cat, int(a["home"]), String(a.get("cat_name", "")))
			else:
				game.people.drop_cat(cat)    # дома нет — кошка-награда появится у станции после загрузки
			cat = {}
		return
	city._quiet("История «%s» прервалась. %s" % [_story(a).get("title", ""), why], "scroll")
	if not cat.is_empty():
		game.people.drop_cat(cat)
		cat = {}
	s["active"] = {}
	s["last_h"] = int(s["h"])
	_marks(true)
	hud.refresh()


func _on_removed(b: Dictionary) -> void:
	if int(b["id"]) == city.moving_id:
		return                           # перенос: дом встанет на новое место (City._story_rehome)
	var s := S()
	var o: Dictionary = s["offer"]
	if not o.is_empty() and int(o.get("home", -1)) == int(b["id"]):
		_drop_offer()
	_poll = POLL                         # проверить идущую историю сразу


func _on_family_left(home: int, nm: String) -> void:
	var s := S()
	var o: Dictionary = s["offer"]
	if not o.is_empty() and String(o.get("fam", "")) == nm:
		_drop_offer()
	var a: Dictionary = s["active"]
	if not a.is_empty() and String(a.get("fam", "")) == nm:
		_cancel("Семья %s уехала из города." % StoryDefs.fam_gen(nm))


## Дом, где теперь живёт семья (-1 — нет)
func _find_family(fam: String) -> int:
	if fam == "":
		return -1
	for id in city.buildings:
		var b: Dictionary = city.buildings[id]
		if city.is_house(b):
			for f: Dictionary in b["families"]:
				if String(f["name"]) == fam:
					return int(id)
	return -1


## Семья ещё в городе (в доме, на площади или идёт в дом)
func _family_in_city(fam: String) -> bool:
	if _find_family(fam) >= 0 or city.pending.has(fam):
		return true
	for f: Dictionary in city.arrivals:
		if String(f["name"]) == fam:
			return true
	return false


# ---------- цели шагов ----------

## Сколько сделано по цели шага: {have, need, ok, txt}
func progress(a: Dictionary, g: Array) -> Dictionary:
	var flags: Dictionary = a.get("flags", {})
	var hp := _home_pos(a)
	match String(g[0]):
		"find":
			var f := bool(flags.get("found", false))
			return {"have": int(f), "need": 1, "ok": f, "txt": ""}
		"p":
			var n := city.progress_of(g[1])
			return {"have": n, "need": int(g[2]), "ok": n >= int(g[2]), "txt": "%d/%d" % [mini(n, int(g[2])), int(g[2])]}
		"around":
			var need: Dictionary = g[2]
			var have := 0
			var tot := 0
			var ok := true
			for base in need:
				var n := _count_near(String(base), hp, float(g[1]), -1)
				have += mini(n, int(need[base]))
				tot += int(need[base])
				ok = ok and n >= int(need[base])
			return {"have": have, "need": tot, "ok": ok, "txt": "%d/%d" % [have, tot]}
		"built_after":
			var room := int(g[3]) if g.size() > 3 else 0
			# новый — построенный после выбора (свадьба: сад или таверна), иначе — после начала шага
			var after := int(flags.get("after", a.get("id0", 0)))
			# дом самой семьи (и жениха) — не «свой угол» молодым, даже если он новый (семья заселилась в новый дом)
			var skip := [int(a.get("home", -1)), int(a.get("home2", -1))]
			var nb := _new_near(String(g[1]), hp, float(g[2]), after, room, skip)
			if nb >= 0:
				flags["built"] = nb
			var any := nb >= 0 or (room > 0 and _new_near(String(g[1]), hp, float(g[2]), after, 0, skip) >= 0)
			return {"have": int(nb >= 0), "need": 1, "ok": nb >= 0, "txt": "", "full": any and nb < 0}
		"square":
			return _square(a, g)
		"score":
			var n := _count_near(String(g[1]), hp, float(g[2]), -1)
			var tiers: Array = g[3]
			var tier := 0
			for k in tiers.size():
				if n >= int(tiers[k]):
					tier = k + 1
			flags["tier"] = tier
			return {"have": n, "need": int(tiers[0]), "ok": tier >= 1 and bool(flags.get("ready", false)), "tier": tier,
				"txt": "%d (%s)" % [n, ["нет", "бронза", "серебро", "золото"][mini(tier, 3)]]}
		"choice":
			var c := String(flags.get("choice", ""))
			return {"have": int(c != ""), "need": 1, "ok": c != "", "txt": ""}
		"pay":
			var paid := bool(flags.get("paid", false))
			return {"have": int(paid), "need": 1, "ok": paid, "txt": ""}
		"wait":
			var hrs := int(S()["h"]) - int(a.get("t0", S()["h"]))
			return {"have": mini(hrs, int(g[1])), "need": int(g[1]), "ok": hrs >= int(g[1]), "txt": "%d/%d ч" % [mini(hrs, int(g[1])), int(g[1])]}
		"flag":
			var sub: Dictionary = g[2]
			var v := String(flags.get(String(g[1]), ""))
			if sub.has(v):
				return progress(a, sub[v])
			return {"have": 0, "need": 1, "ok": false, "txt": ""}
	return {"have": 0, "need": 1, "ok": false, "txt": ""}


## Постройка вида base (тип, облик украшения или «a|b» — любой из них)
static func _is(b: Dictionary, base: String) -> bool:
	for k in base.split("|"):
		if b["type"] == k or Defs.base_of(b["type"]) == k:
			return true
	return false


## Сколько построек вида base («a|b» — любой) в r м от p; after ≥ 0 — только построенные после (born > after)
func _count_near(base: String, p: Vector2, r: float, after: int) -> int:
	return count_near(city, base, p, r, after)


static func count_near(cty: City, base: String, p: Vector2, r: float, after: int) -> int:
	var n := 0
	for id in cty.buildings:
		var b: Dictionary = cty.buildings[id]
		if (b["pos"] as Vector2).distance_to(p) > r or not _is(b, base):   # сначала — дешёвое: далеко ли
			continue
		if after >= 0 and int(b.get("born", id)) < after:
			continue
		n += 1
	return n


## Новый дом вида base в r м от p, построенный после after, где свободно хотя бы room мест (ближний), или -1;
## skip — эти дома не в счёт
func _new_near(base: String, p: Vector2, r: float, after: int, room: int, skip := []) -> int:
	var best := -1
	var bd := INF
	for id in city.buildings:
		var b: Dictionary = city.buildings[id]
		if not _is(b, base) or int(b.get("born", id)) < after or int(id) in skip:
			continue
		var d := (b["pos"] as Vector2).distance_to(p)
		if d > r or d >= bd:
			continue
		if room > 0 and (not city.is_house(b) or city.house_cap(b) - int(b["pop"]) - int(b.get("coming", 0)) < room):
			continue
		bd = d
		best = int(id)
	return best


## Скверик: всё из списка рядом (скамьи, деревья, колодец); порог — по скамьям: бронза, серебро, золото (и солнечные
## часы); «Готово» — когда хватает
func _square(a: Dictionary, g: Array) -> Dictionary:
	var flags: Dictionary = a["flags"]
	var out := square_eval(city, _home_pos(a), g)
	flags["tier"] = int(out["tier"])
	out["ok"] = bool(out["min"]) and int(out["tier"]) >= 1 and bool(flags.get("ready", false))
	return out


## Скверик у точки hp (по цели g): {have, need, min — самое нужное есть, tier, benches, sun, parts, txt}
static func square_eval(cty: City, hp: Vector2, g: Array) -> Dictionary:
	var r := float(g[1])
	var need: Dictionary = g[2]
	var parts := []
	var ok := true
	var have := 0
	var tot := 0
	for base in need:
		var n := count_near(cty, String(base), hp, r, -1)
		ok = ok and n >= int(need[base])
		have += mini(n, int(need[base]))
		tot += int(need[base])
		parts.append([String(base), n, int(need[base])])
	var nb := count_near(cty, String(g[3]), hp, r, -1)
	var tiers: Array = g[4]
	var gold := String(g[5]) if g.size() > 5 else ""
	var sun := gold == "" or count_near(cty, gold, hp, r, -1) > 0
	var tier := 0
	if ok:
		for k in tiers.size():
			if nb >= int(tiers[k]) and (k < tiers.size() - 1 or sun):
				tier = k + 1
	return {"have": have, "need": tot, "tier": tier, "min": ok, "benches": nb, "sun": sun, "parts": parts, "txt": "%d/%d" % [have, tot]}


## «Памятник» готового скверика (награда без срока) — пока скверик стоит: % сейчас (0 — скверик разобрали).
## Меряем там же, где мерили цель (у дома просящего в час «Готово»), не больше заслуженного тогда
static func square_live_pct(cty: City, b: Dictionary) -> int:
	var sd := StoryDefs.story(String(b.get("id", "")))
	var g: Array = StoryDefs.goal_step(sd, "square").get("goal", [])
	if g.is_empty():
		return int(b.get("pct", 0))
	var at: Array = b.get("at", [b.get("x", 0.0), b.get("z", 0.0)])
	var tier := int(square_eval(cty, Vector2(float(at[0]), float(at[1])), g)["tier"])
	if tier <= 0:
		return 0
	var mo: Array = (sd.get("reward", {}) as Dictionary).get("monument", [])
	var pcts = mo[0] if not mo.is_empty() else int(b.get("pct", 0))
	var p := int((pcts as Array)[mini(tier, (pcts as Array).size()) - 1]) if pcts is Array else int(pcts)
	return mini(int(b.get("pct", 0)), p)


## Середина скверика: среди скамеек в r м от дома (нет скамеек — сам дом)
func square_center(a: Dictionary, r: float) -> Vector2:
	var hp := _home_pos(a)
	var sum := Vector2.ZERO
	var n := 0
	for id in city.buildings:
		var b: Dictionary = city.buildings[id]
		if Defs.base_of(b["type"]) == "bench" and (b["pos"] as Vector2).distance_to(hp) <= r:
			sum += b["pos"]
			n += 1
	return sum / n if n > 0 else hp


## «Готово» (score), «Заплатить» (pay), выбор (choice) — из золотой строки
func press(what: String, val := "") -> void:
	var a: Dictionary = S()["active"]
	if a.is_empty():
		return
	var flags: Dictionary = a["flags"]
	var g: Array = _step(a).get("goal", [])
	match what:
		"ready":
			flags["ready"] = true
		"pay":
			var n := int(g[2])
			if String(g[1]) == "glory":
				if city.legion.glory < n:
					return
				city.legion.glory -= n
			else:
				if city.money < n:
					return
				city.money -= n
				if game.sound:
					game.sound.ui("coins")
			flags["paid"] = true
		"choice":
			_choose(a, val)
	_tick_active(what == "ready")
	hud.refresh()


# ---------- значки над миром и место поисков ----------

func _marks(on: bool) -> void:
	var s := S()
	var key := ""
	var pos := Vector3.ZERO
	var icon := "scroll"
	var cb := Callable()
	var a: Dictionary = s["active"]
	var o: Dictionary = s["offer"]
	var cine_on: bool = game.rig != null and game.rig.cine
	if on and not cine_on:
		if not o.is_empty() and _lives(o):
			key = "story"
			pos = _badge_pos(int(o["home"]))
			cb = open_offer
		elif not a.is_empty() and a.get("ready", false) and (_lives(a) or _final_ready(a)) and _ready_home(a) >= 0:
			key = "story"
			pos = _badge_pos(_ready_home(a))
			icon = "check"
			cb = play_ready
	if key != "":
		hud.set_badge("story", pos, icon, false, "Просьба" if icon == "scroll" else "Готово", cb)
	else:
		hud.clear_badge("story")
	# след лапки над кошкой — через paw_h часов поисков
	var paw := false
	var area := []
	if on and not cine_on and not a.is_empty() and _goal_kind(a) == "find" and not cat.is_empty():
		var g: Dictionary = _step(a)["goal"][2]
		var hours := int(s["h"]) - int(a.get("t0", s["h"]))
		paw = hours >= int(g.get("paw_h", 6))
		area = a.get("area1" if hours >= int(g.get("shrink_h", 3)) else "area0", [])
	if paw:
		hud.set_badge("story_paw", _cat_pos() + Vector3(0, 0.75, 0), "cat", false, "", found)
	else:
		hud.clear_badge("story_paw")
	if on and not cine_on and area.is_empty() and not a.is_empty() and not a.get("ready", false) and not a.has("homeless"):
		area = _goal_area(a)                # где строить (скверик, сад, новый дом): то же мягкое пятно света
	_area_marks(area, a)


## Где выполнять цель шага: [x, z, радиус, яркость, край] у дома просящего — или []. Край (чёткая граница, без кольца) —
## только пока в руках то, что идёт в счёт цели (украшение для скверика и сада, дом для молодых): иначе мягкое пятно
func _goal_area(a: Dictionary) -> Array:
	var g: Array = _step(a).get("goal", [])
	if g.is_empty():
		return []
	var hp := _home_pos(a)
	var edge := game != null and zone_tool(String(game.tool))
	match String(g[0]):
		"square", "around":
			return [hp.x, hp.y, float(g[1]), BUILD_GLOW, edge]
		"built_after":
			return [hp.x, hp.y, float(g[2]), BUILD_GLOW, edge]
		"flag":
			var sub: Array = (g[2] as Dictionary).get(String((a.get("flags", {}) as Dictionary).get(String(g[1]), "")), [])
			if not sub.is_empty() and String(sub[0]) == "around":
				return [hp.x, hp.y, float(sub[1]), BUILD_GLOW, edge]
	return []


# ---------- «рядом с домом» (скверик, свадебный сад, дом молодым): у курсора — в счёт ли, ✓ над тем, что в счёт ----------

## Цель шага «рядом с домом» сейчас: {hp, r, keys: [вид…], label — «скверика», no — «Это не дерево»} или {}
func zone_goal() -> Dictionary:
	if city == null or not allowed():
		return {}
	var a: Dictionary = S()["active"]
	if a.is_empty() or a.get("ready", false) or a.has("homeless"):
		return {}
	var st := _step(a)
	var g: Array = st.get("goal", [])
	if g.is_empty():
		return {}
	var zl = st.get("zone", [])
	var keys := []
	var r := 0.0
	var after := -1                       # «построенный после» (дом молодым): те же отборы, что у _new_near
	var room := 0
	var skip := []
	match String(g[0]):
		"square":
			r = float(g[1])
			keys = (g[2] as Dictionary).keys()
			if not keys.has(String(g[3])):
				keys.append(String(g[3]))
			if g.size() > 5:
				keys.append(String(g[5]))       # солнечные часы — для золота
		"around":
			r = float(g[1])
			keys = (g[2] as Dictionary).keys()
		"built_after":
			r = float(g[2])
			keys = [String(g[1])]
			after = int((a.get("flags", {}) as Dictionary).get("after", a.get("id0", 0)))
			room = int(g[3]) if g.size() > 3 else 0
			skip = [int(a.get("home", -1)), int(a.get("home2", -1))]
		"flag":
			var ch := String((a.get("flags", {}) as Dictionary).get(String(g[1]), ""))
			var sub: Array = (g[2] as Dictionary).get(ch, [])
			if sub.is_empty() or String(sub[0]) != "around":
				return {}
			r = float(sub[1])
			keys = (sub[2] as Dictionary).keys()
			zl = (zl as Dictionary).get(ch, []) if zl is Dictionary else zl
		_:
			return {}
	var lab: Array = zl if zl is Array else []
	return {"hp": _home_pos(a), "r": r, "keys": keys, "label": String(lab[0]) if lab.size() > 0 else "цели",
		"no": String(lab[1]) if lab.size() > 1 else "", "after": after, "room": room, "skip": skip}


## Постройка type идёт в счёт цели «рядом с домом» (или похожа на нужное — тогда у курсора скажем «не в счёт»)
func zone_tool(type: String) -> bool:
	var z := zone_goal()
	if z.is_empty() or not Defs.B.has(type):
		return false
	return _zone_key(z, type) != "" or (String(z["no"]) != "" and String(Defs.B[type].get("sub", "")) in ["plants", "trees"])


func _zone_key(z: Dictionary, type: String) -> String:
	for k in z["keys"]:
		if _is({"type": type}, String(k)):
			return String(k)
	return ""


## Строка у курсора для постройки type в точке p: [текст, в счёт ли] или [] (цели нет / к ней не относится)
func zone_note(type: String, p: Vector2) -> Array:
	var z := zone_goal()
	if z.is_empty() or not Defs.B.has(type) or not p.is_finite():
		return []
	if _zone_key(z, type) == "":
		if String(z["no"]) != "" and String(Defs.B[type].get("sub", "")) in ["plants", "trees"]:
			return ["%s — не в счёт" % String(z["no"]), false]     # горшки, вазы, клумбы — не деревья
		return []
	if p.distance_to(z["hp"]) <= float(z["r"]):
		return ["В счёт %s ✓" % String(z["label"]), true]
	return ["Далеко от дома — не в счёт", false]


const ZONE_FLASH_MS := 3000                # ✓ над тем, что в счёт, — столько после постановки
var _flash: Array = []                     # ключи значков ✓
var _flash_until := 0


## Поставили постройку: на 3 с ✓ над всем, что идёт в счёт цели «рядом с домом» (если поставленное к ней относится)
func flash_counted(b: Dictionary) -> void:
	var z := zone_goal()
	if z.is_empty() or _zone_key(z, String(b.get("type", ""))) == "":
		return
	_flash_clear()
	for id in city.buildings:
		var o: Dictionary = city.buildings[id]
		if (o["pos"] as Vector2).distance_to(z["hp"]) > float(z["r"]) or _zone_key(z, String(o["type"])) == "":
			continue
		if int(z["after"]) >= 0:
			# дом молодым: только новые дома (не семьи и не жениха) со свободными местами — как в _new_near
			if int(o.get("born", id)) < int(z["after"]) or int(id) in z["skip"]:
				continue
			if int(z["room"]) > 0 and (not city.is_house(o) or city.house_cap(o) - int(o["pop"]) - int(o.get("coming", 0)) < int(z["room"])):
				continue
		var top: float = city.blueprint(o).top_y() + 0.6
		var key := "zok%d" % int(id)
		hud.set_badge(key, Vector3(o["pos"].x, float(o["y"]) + top, o["pos"].y), "check", false, "", Callable(), "mark")
		_flash.append(key)
	_flash_until = Time.get_ticks_msec() + ZONE_FLASH_MS


func _flash_clear() -> void:
	for k in _flash:
		hud.clear_badge(String(k))
	_flash = []


## «Ещё 2 дерева стоят дальше 15 м — подвиньте их ближе»: того, чего не хватает, — сколько стоит чуть дальше (до +12 м)
func near_miss(hp: Vector2, r: float, need: Dictionary) -> String:
	var out := ""
	for base in need:
		var n := _count_near(String(base), hp, r, -1)
		if n >= int(need[base]):
			continue
		var far := _count_near(String(base), hp, r + 12.0, -1) - n
		if far <= 0:
			continue
		var k := mini(far, int(need[base]) - n)
		var w: Array = ZONE_WORDS.get(String(base), ["постройка", "постройки", "построек", "её"])
		out += " Ещё %d %s %s дальше %d м — подвиньте %s ближе." % [k, Hud._plural(k, w[0], w[1], w[2]), "стоит" if k == 1 else "стоят",
			int(r), w[3] if k == 1 else "их"]
	return out


## Слова для «Ещё 2 дерева…»: одно, два, пять, «подвиньте его/её»
const ZONE_WORDS := {"bench": ["скамья", "скамьи", "скамей", "её"], "tree|cypress|palm|bush": ["дерево", "дерева", "деревьев", "его"],
	"well|smallfountain": ["колодец", "колодца", "колодцев", "его"], "flowers|planter|bush|wall_flowers": ["цветник", "цветника", "цветников", "его"],
	"pergola|rosearch": ["беседка", "беседки", "беседок", "её"], "taberna|thermopolium": ["таверна", "таверны", "таверн", "её"]}


## Место поисков: мягкое пятно тёплого света на земле (не кольцо) и цепочка следов лапок от дома в его сторону
func _area_marks(area: Array, a: Dictionary) -> void:
	if area.is_empty():
		if _glow != null:
			_glow.queue_free()
			_glow = null
		_glow_key = ""
		_glow_r = 0.0
		_glow_edge = false
		for p in _paws:
			(p as Node).queue_free()
		_paws = []
		_paws_key = ""
		return
	var c := Vector2(float(area[0]), float(area[1]))
	var r := float(area[2])
	var al := float(area[3]) if area.size() > 3 else 0.5   # где строить — свет мягче, чем где искать кошку
	var edge := area.size() > 4 and bool(area[4])
	# с нужным украшением в руках — ровный свет до R−1,5 м и чёткий спад к R+0,5 м (граница видна, но это не кольцо)
	var rr := r + (EDGE_OUT if edge else 0.0)
	var tex: Texture2D = StoryUi.edge_tex(r, EDGE_OUT) if edge else StoryUi.glow_tex()
	if edge:
		al = EDGE_AL
	var k := "%.1f,%.1f,%.1f,%.2f,%s" % [c.x, c.y, r, al, edge]
	if _no_decals:
		if k != _glow_key:
			if _glow != null:
				_glow.queue_free()
			_glow = _glow_mesh(c, rr, al, tex)
			game.add_child(_glow)
	else:
		if _glow == null:
			var dc := Decal.new()
			dc.modulate = Color(1.0, 0.82, 0.42, 0.5)
			dc.albedo_mix = 1.0
			dc.normal_fade = 0.6
			dc.upper_fade = 0.2
			dc.lower_fade = 0.2
			dc.cull_mask = Game.LAND_LAYER   # только земля: дома, люди и деревья не светятся
			game.add_child(dc)
			_glow = dc
		(_glow as Decal).texture_albedo = tex
		(_glow as Decal).size = Vector3(rr * 2.0, 8.0, rr * 2.0)
		(_glow as Decal).modulate = Color(1.0, 0.82, 0.42, al)
		_glow.position = Vector3(c.x, game.land.height_at(c.x, c.y), c.y)
	_glow_key = k
	_glow_r = r
	_glow_edge = edge
	if k == _paws_key:
		return
	_paws_key = k
	for p in _paws:
		(p as Node).queue_free()
	_paws = []
	var home: Dictionary = city.buildings.get(int(a.get("home", -1)), {})
	if home.is_empty():
		return
	var d0: Vector2 = city.door_point(home)
	var dir := (c - d0)
	var len := dir.length() - r * 0.8
	if len < 2.0:
		return
	dir = dir.normalized()
	var side := Vector2(-dir.y, dir.x)
	var n := mini(10, int(len / 1.5))
	for i in n:
		var q := d0 + dir * (1.8 + i * 1.5) + side * (0.22 if i % 2 == 0 else -0.22)
		var col := Color(0.32, 0.2, 0.11, 0.8 * (1.0 - 0.05 * i))
		var pd: Node3D
		if _no_decals:
			var pm := PlaneMesh.new()        # лежит на земле (XZ)
			pm.size = Vector2(0.6, 0.6)
			var mi := MeshInstance3D.new()
			mi.mesh = pm
			mi.material_override = _flat_mat(StoryUi.paw_tex(), col)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = Vector3(q.x, game.land.height_at(q.x, q.y) + 0.03, q.y)
			pd = mi
		else:
			var dc := Decal.new()
			dc.texture_albedo = StoryUi.paw_tex()
			dc.modulate = col
			dc.size = Vector3(0.6, 2.0, 0.6)
			dc.normal_fade = 0.6
			dc.cull_mask = Game.LAND_LAYER
			dc.position = Vector3(q.x, game.land.height_at(q.x, q.y), q.y)
			pd = dc
		pd.rotation.y = atan2(dir.x, dir.y) + PI
		game.add_child(pd)
		_paws.append(pd)


## Пятно поисков без Decal (OpenGL): сетка по земле чуть выше неё, мягкий свет без теней; дома и деревья его заслоняют
func _glow_mesh(c: Vector2, r: float, al := 0.5, tex: Texture2D = null) -> MeshInstance3D:
	var n := 24
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in n + 1:
		for i in n + 1:
			var x := c.x - r + 2.0 * r * i / n
			var z := c.y - r + 2.0 * r * j / n
			# земля ступеньками по 0,25 м: берём самую высокую рядом — пятно не уходит под бугорки
			var y: float = game.land.height_at(x, z)
			for dd: Vector2 in [Vector2(-0.6, -0.6), Vector2(0.6, -0.6), Vector2(-0.6, 0.6), Vector2(0.6, 0.6)]:
				y = maxf(y, game.land.height_at(x + dd.x, z + dd.y))
			st.set_uv(Vector2(float(i) / n, float(j) / n))
			st.add_vertex(Vector3(x, y + 0.06, z))
	for j in n:
		for i in n:
			var k := j * (n + 1) + i
			for v in [k, k + 1, k + n + 1, k + 1, k + n + 2, k + n + 1]:
				st.add_index(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _flat_mat(tex if tex != null else StoryUi.glow_tex(), Color(1.0, 0.82, 0.42, al))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _flat_mat(tex: Texture2D, col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = tex
	m.albedo_color = col
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = -1
	return m


## Над каким домом «Готово»: дом семьи; снесли — новый дом молодых (свадьба); нет и его — -1 (кнопка — в золотой строке)
func _ready_home(a: Dictionary) -> int:
	if city.buildings.has(int(a.get("home", -1))):
		return int(a["home"])
	var bid := int((a.get("flags", {}) as Dictionary).get("built", -1))
	if city.buildings.has(bid):
		return bid
	return _find_family(String(a.get("couple", "")))


func _badge_pos(id: int) -> Vector3:
	var b: Dictionary = city.buildings.get(id, {})
	if b.is_empty():
		return Vector3.ZERO
	var top: float = city.blueprint(b).top_y() + 1.4
	return Vector3(b["pos"].x, float(b["y"]) + top, b["pos"].y)


func _cat_pos() -> Vector3:
	if cat.is_empty():
		return Vector3.ZERO
	var p: Vector2 = cat["p"]
	return Vector3(p.x, game.land.height_at(p.x, p.y), p.y)


## Камера — к месту поисков (кнопка «Показать»)
func show_area() -> void:
	var a: Dictionary = S()["active"]
	if a.is_empty():
		return
	var c := _home_pos(a)
	var ga := _goal_area(a)
	if not ga.is_empty():
		c = Vector2(float(ga[0]), float(ga[1]))
	if _goal_kind(a) == "find":
		var g: Dictionary = _step(a)["goal"][2]
		var hours := int(S()["h"]) - int(a.get("t0", S()["h"]))
		var ar: Array = a.get("area1" if hours >= int(g.get("shrink_h", 3)) else "area0", [])
		if not ar.is_empty():
			c = Vector2(float(ar[0]), float(ar[1]))
	var rig = game.rig
	rig._target_t = Vector3(c.x, game.land.height_at(c.x, c.y), c.y)
	rig._dist_t = clampf(rig._dist_t, 30.0, 55.0)


## Советник один раз: как устроен скверик — пороги по скамьям и «Готово»
func _advise_square() -> void:
	var a: Dictionary = S()["active"]
	if a.is_empty() or _goal_kind(a) != "square" or city.tips.has("story_square") or not hud._tip_free() or kit != null:
		return
	city.tips["story_square"] = true
	# свиток просьб свёрнут (золотая точка на нём горит всю историю) — «Готово» будет, когда его развернут
	var ready_t := "в золотой строке свитка «Просьбы» появится «Готово» — сейчас свиток свёрнут, разверните его щелчком" if hud.tasks_folded() \
		else "в «Просьбах горожан» появится «Готово»"
	hud.advisor("Скверик для стариков", "Скамьи, деревья или кусты из раздела «Украшения» и колодец ставьте не дальше 15 м от середины дома просящего — это место подсвечено на земле. С украшением в руках у курсора видно, в счёт ли оно, а край места светится чётче. Дикие деревья, что выросли сами, не в счёт. Старики начнут приходить, как только появятся скамьи: чем больше скамей, тем больше стариков.\n\n" \
		+ "Когда хватит самого нужного, " + ready_t + ". Нажмёте сразу — бронза (3 скамьи): +3% счастья домам вокруг. Пять скамей — серебро, +5%. Семь скамей и солнечные часы — золото, +7%. Награда остаётся, пока стоит скверик.")


## Советник один раз: что такое истории горожан (когда появилось первое предложение)
func _advise_once() -> void:
	if (S()["offer"] as Dictionary).is_empty() or city.tips.has("story_tip") or not hud._tip_free():
		return
	city.tips["story_tip"] = true
	# свиток просьб свёрнут (сам не разворачивается) — говорим, как до строки добраться
	var fold: bool = hud.tasks_folded()
	var where := "Над домом просящего появился свиток, а на свёрнутом свитке «Просьбы» — золотая точка: щёлкните по нему, он развернётся, и наверху будет золотая строка." if fold \
		else "Над домом просящего появился свиток, а наверху «Просьб горожан» — золотая строка."
	var later := "Не до того — разверните свиток и нажмите «Отложить»" if fold else "Не до того — нажмите «Отложить»"
	hud.advisor("Истории горожан", "Горожане иногда просят градоначальника о помощи. " + where + "\n\n" \
		+ "Щёлкните по свитку над домом, когда будет время, — житель сам расскажет, что случилось. " + later + ": он попросит снова через сутки. За помощь горожане отблагодарят: редкое украшение, радость в доме, очки исследований. Пройденные истории — в журнале (книжка у «Просьб горожан»).")


# ---------- золотая строка и журнал ----------

## Что показать в золотой строке «Просьб горожан»: {title, text, icon, tip, buttons: [[подпись, Callable]]} или {}
func row_info() -> Dictionary:
	if city == null or not (game.mode in ["new", "play"]):
		return {}
	var s := S()
	var o: Dictionary = s["offer"]
	var a: Dictionary = s["active"]
	if not o.is_empty():
		var sd := StoryDefs.story(String(o["id"]))
		var row := String(sd.get("row", "%s просит о помощи" % String(sd.get("who", ""))))
		return {"title": sd["title"], "icon": sd.get("icon", "scroll"), "text": StoryDefs.fill(row, o),
			"tip": StoryDefs.fill(String(sd.get("ask", "")), o) + "\nНажмите «Выслушать» или свиток над их домом.",
			"buttons": [["Выслушать", open_offer], ["Отложить", postpone]]}
	if a.is_empty():
		return {}
	var sd := _story(a)
	if sd.is_empty():
		return {}
	var info := {"title": sd["title"], "icon": sd.get("icon", "scroll"), "buttons": []}
	if a.has("homeless") and not _final_ready(a):
		info["text"] = "Семья %s осталась без дома — история подождёт, пока они заселятся." % StoryDefs.fam_gen(String(a.get("fam", "")))
		return info
	if a.get("ready", false):
		info["text"] = "Готово! Посмотрите, чем всё кончилось."
		info["buttons"] = [["Посмотреть", play_ready]]
		return info
	var st := _step(a)
	var ch := String((a.get("flags", {}) as Dictionary).get("choice", ""))
	var text := StoryDefs.fill(String((st.get("texts", {}) as Dictionary).get(ch, st.get("text", ""))), a)
	var hours := int(s["h"]) - int(a.get("t0", s["h"]))
	for hn: Array in st.get("hints", []):
		if hours >= int(hn[0]):
			text = StoryDefs.fill(String(hn[1]), a)
	var g: Array = st.get("goal", [])
	var kind := "" if g.is_empty() else String(g[0])
	match kind:
		"find":
			info["buttons"] = [["Показать", show_area]]
			if hours > 0:
				text += " Ищем %d ч." % hours
		"score":
			var pr := progress(a, g)
			text += " Сейчас: %s." % pr["txt"]
			if int(pr.get("tier", 0)) >= 1:
				info["buttons"] = [["Готово", press.bind("ready", "")]]
		"pay":
			info["buttons"] = [["Заплатить %d %s" % [int(g[2]), "Славы" if String(g[1]) == "glory" else "ден."], press.bind("pay", "")]]
		"choice":
			var bs := []
			for op: Array in g[1]:
				bs.append([String(op[0]), press.bind("choice", String(op[1]))])
			info["buttons"] = bs
		"square":
			var pr := progress(a, g)
			text += " " + _square_text(sd, g, pr)
			info["buttons"] = [["Показать", show_area]]
			if bool(pr["min"]):
				info["buttons"] = [["Готово (%s)" % TIER[int(pr["tier"])], press.bind("ready", "")], ["Показать", show_area]]
		"flag":
			if ch == "":
				# ещё не выбрали (пропустили ролик и выбор): выбрать здесь
				text = "Где устроить праздник? Выберите — и за дело."
				for op: Array in choice_opts(sd):
					info["buttons"].append([String(op[0]), press.bind("choice", String(op[1]))])
			else:
				var pr := progress(a, g)
				if String(pr["txt"]) != "":
					text += " Сейчас: %s." % pr["txt"]
				var sg: Array = (g[2] as Dictionary).get(ch, [])
				if not sg.is_empty() and String(sg[0]) == "around":
					text += near_miss(_home_pos(a), float(sg[1]), sg[2])
				info["buttons"] = [["Показать", show_area]]
				for op: Array in choice_opts(sd):
					if String(op[1]) != ch:
						info["buttons"].append(["Лучше: %s" % String(op[0]).to_lower(), press.bind("choice", String(op[1]))])
		"built_after":
			var pr := progress(a, g)
			if bool(pr.get("full", false)):
				text += " Новый дом уже заняли — нужен такой, где свободно хотя бы %d места." % int(g[3])
			info["buttons"] = [["Показать", show_area]]
		"", "around", "wait", "p":
			if kind != "":
				var pr := progress(a, g)
				if String(pr["txt"]) != "":
					text += " %s." % pr["txt"]
				if kind == "around":
					text += near_miss(_home_pos(a), float(g[1]), g[2])
	info["text"] = text
	return info


## Строка скверика: что уже есть, какой порог сейчас и что нужно до следующего
func _square_text(sd: Dictionary, g: Array, pr: Dictionary) -> String:
	var names := {"bench": "скамей", "tree|cypress|palm|bush": "деревьев и кустов", "well|smallfountain": "колодцев"}
	var bits := []
	for e: Array in pr["parts"]:
		var nm := String(names.get(String(e[0]), String(e[0])))
		bits.append("%s %d" % [nm, int(e[1])] if String(e[0]) == String(g[3]) else "%s %d/%d" % [nm, mini(int(e[1]), int(e[2])), int(e[2])])
	var out := "Сейчас: " + ", ".join(bits) + "."
	var a: Dictionary = S()["active"]
	if not a.is_empty():
		out += near_miss(_home_pos(a), float(g[1]), g[2])
	var tier := int(pr["tier"])
	var tiers: Array = g[4]
	var pct: Array = ((sd.get("reward", {}) as Dictionary).get("monument", [[0]]) as Array)[0]
	if tier >= 1:
		out += " Это %s: +%d%% счастья домам рядом." % [TIER[tier], int(pct[tier - 1])]
	if tier < tiers.size():
		var nb_need := int(tiers[tier])
		var more := "%d %s" % [nb_need, Hud._plural(nb_need, "скамья", "скамьи", "скамей")]
		if tier == tiers.size() - 1 and g.size() > 5 and not bool(pr["sun"]):
			more += " и солнечные часы"
		out += " %s — %s." % [TIER[tier + 1].capitalize(), more]
	return out


## Есть что показать в журнале (кнопка-книжка у «Просьб горожан»)
func journal_any() -> bool:
	if city == null:
		return false
	var s := S()
	return not (s["done"] as Dictionary).is_empty() or not (s["active"] as Dictionary).is_empty()


# ---------- ролик ----------

## Можно начать ролик: своя игра, ничего другого не идёт (ролик ранга, обучение, бой), окно не свёрнуто
func can_start() -> bool:
	if not allowed() or kit != null:
		return false
	var rc = game.rank_cine
	if rc != null and (not rc.cine.is_empty() or not rc.pending.is_empty()):
		return false
	var tut = game.tutorial
	if tut != null and (not tut.cine.is_empty() or tut.active()):
		return false
	if LegionBattle.current != null or float(game._min_speed) >= 0.0:
		return false
	return not game.painting and game.moving.is_empty() and game.moving_nature.is_empty()


## Пересмотреть пройденную историю (журнал): ролики просьбы и встречи, без наград и выбора
func replay(id: String) -> void:
	var e: Dictionary = (S()["done"] as Dictionary).get(id, {})
	var sd := StoryDefs.story(id)
	if e.is_empty() or sd.is_empty():
		return
	hud.close_panels()
	if not can_start():
		return
	var steps: Array = sd["steps"]
	var beats: Array = []
	for i in steps.size():
		var b: Array = (steps[i] as Dictionary).get("cine", [])
		if b.is_empty():
			continue
		if not beats.is_empty():
			beats.append(["cut"])
		beats.append_array(b)
	var bind := e.duplicate(true)
	if not city.buildings.has(int(bind.get("home", -1))):
		var nh := _find_family(String(bind.get("fam", "")))
		bind["home"] = nh if nh >= 0 else int(city.center()["id"])
	_play(sd, bind, beats, "replay", Callable())


func _play(sd: Dictionary, bind: Dictionary, beats: Array, mode: String, after: Callable) -> void:
	hud.close_panels()
	kit = CineKit.new()
	add_child(kit)
	kit.on_skip = _skip
	kit.on_next = _next
	kit.begin(game)
	kit.finished.connect(_cleanup)
	ui.bubble(kit.block)
	cine = {"story": sd, "bind": bind, "beats": beats, "i": -1, "bt": 0.0, "mode": mode, "after": after, "actors": {},
		"wait": false, "choice": "", "opts": [], "end": false, "tcat": null, "props": [], "lights": []}
	# мягкий свет спереди, со стороны камеры, — только на героев ролика (слой Citizen.FACE_LAYER): тень от бровей
	# не ложится на глаза, лица приветливые; город он не трогает
	var fl := DirectionalLight3D.new()
	fl.light_cull_mask = Citizen.FACE_LAYER
	fl.light_energy = 0.0 if Citizen.plain_faces else FILL
	fl.light_color = Color("fff1dc")
	fl.light_specular = 0.0
	fl.shadow_enabled = false
	game.add_child(fl)
	cine["fill"] = fl
	_marks(false)
	_next_beat()


func _next_beat() -> void:
	cine["i"] = int(cine["i"]) + 1
	cine["bt"] = 0.0
	cine["wait"] = false
	var beats: Array = cine["beats"]
	if int(cine["i"]) >= beats.size():
		_end_cine()
		return
	_beat_start(beats[int(cine["i"])])


## Пробел, Enter, щелчок: допечатать реплику; напечатана — дальше; выбор — ждёт кнопку
func _next() -> void:
	if cine.is_empty() or bool(cine["end"]):
		return
	if ui.typing():
		ui.finish_typing()
		return
	if ui.choosing():
		return
	if bool(cine["wait"]):
		_next_beat()


## Esc, правая кнопка, «Пропустить ›»: ролик — домой; выбор не сделан — первый (помочь); действие шага уже случилось
func _skip() -> void:
	if cine.is_empty() or bool(cine["end"]):
		return
	if String(cine["choice"]) == "":
		var beats: Array = cine["beats"]
		for i in range(int(cine["i"]), beats.size()):
			var b: Array = beats[maxi(i, 0)]
			if String(b[0]) == "choice":
				cine["choice"] = String((_avail(b[3])[0] as Array)[1])
				break
	_end_cine(0.9)


func _end_cine(dur := 1.2) -> void:
	if bool(cine["end"]):
		return
	cine["end"] = true
	if ui.panel != null:
		ui.panel.create_tween().tween_property(ui.panel, "modulate:a", 0.0, 0.25)
	kit.back(dur)


## Ролик кончился (камера дома): люди и временная кошка уходят, облачко закрывается; потом — что решили
func _cleanup() -> void:
	for k in cine.get("actors", {}):
		var c = cine["actors"][k]
		if c != null and is_instance_valid(c):
			(c as Node).queue_free()
	var tc = cine.get("tcat")
	if tc != null and is_instance_valid(tc):
		(tc as Node).queue_free()
	var fl = cine.get("fill")
	if fl != null and is_instance_valid(fl):
		(fl as Node).queue_free()
	for h in cine.get("props", []):
		game.parts.remove(h)
	for l in cine.get("lights", []):
		game.night_lights.erase(l)
		(l as Node).queue_free()
	if bool(cine.get("dusk", false)):
		game.look_hour = -1.0
		game._set_hour(game.hour)
	life.force_off()
	ui.close()
	for n in _hidden:
		if n != null and is_instance_valid(n):
			(n as Node3D).visible = true
	_hidden = []
	kit = null
	var after: Callable = cine.get("after", Callable())
	if after.is_valid():
		after.call()
	if kit == null:
		cine = {}
	if cat.has("story"):
		cat["state"] = "sleep"
	_marks(true)
	hud.refresh()


func _speaker(who: String) -> Dictionary:
	var b: Dictionary = cine["bind"]
	var sd: Dictionary = cine["story"]
	if who == "cat":
		return {"kind": "cat", "fur": int(b.get("fur", 0)), "name": String(b.get("cat_name", "Мурка")),
			"role": "кошка семьи %s" % StoryDefs.fam_gen(String(b.get("fam", "")))}
	if who == "advisor":
		return {"kind": "pic", "pic": "advisor.png", "name": "Советник Марк", "role": "советник градоначальника"}
	var ro := _role(b, who)
	var nm: Array = (sd.get("roles", {}) as Dictionary).get(who, [sd.get("who", ""), sd.get("role", "")])
	return {"kind": "citizen", "seed": int(ro["seed"]), "female": bool(ro["female"]), "child": bool(ro["child"]), "old": bool(ro.get("old", false)),
		"cls": String(ro["cls"]), "name": StoryDefs.fill(String(nm[0]), b), "role": StoryDefs.fill(String(nm[1]), b),
		"pic": "class_%s.png" % String(ro["cls"])}


## Кто играет роль: облик (seed, пол, ребёнок, сословие, старик) — из bind["roles"] или общий (история с одним героем).
## Чего в привязке нет (в журнале прежних версий не было пола и «ребёнок ли») — как у героя истории (cast): мальчик
## из «Где Мурка?» — ребёнок, дед из «Скверика» — взрослый и седой
func _role(b: Dictionary, role: String) -> Dictionary:
	var roles: Dictionary = b.get("roles", {})
	if roles.has(role):
		return roles[role]
	var cast: Dictionary = (cine.get("story", StoryDefs.story(String(b.get("id", "")))) as Dictionary).get("cast", {})
	var r0: Dictionary = cast.get(role, cast.values()[0] if not cast.is_empty() else {})
	return {"seed": int(b.get("seed", 1)), "female": bool(b.get("female", r0.get("female", false))),
		"child": bool(b.get("child", r0.get("child", false))), "cls": String(b.get("cls", "plebs")),
		"old": bool(b.get("old", r0.get("old", false)))}


## Где стоит человек роли who (или кошка): точка на земле и куда смотрит
func _who_at(who: String) -> Array:
	if who == "cat":
		var tc = _tcat() if cine["mode"] == "replay" else null
		var p := _cat_pos() if tc == null else (tc as Node3D).position
		# «лицом» кошки для кадра — к дому мальчика: там обычно улица, открыто
		var h: Dictionary = city.buildings.get(int(cine["bind"].get("home", -1)), {})
		var to := ((city.door_point(h) if not h.is_empty() else Vector2(p.x, p.z) + Vector2(0, 1)) - Vector2(p.x, p.z)).normalized()
		return [p, to if to != Vector2.ZERO else Vector2(0, 1)]
	var c = cine["actors"].get(who)
	if c != null and is_instance_valid(c):
		var n := c as Node3D
		return [n.position, Vector2(sin(n.rotation.y), cos(n.rotation.y))]
	var h: Dictionary = city.buildings.get(int(cine["bind"].get("home", -1)), {})
	if h.is_empty():
		return [Vector3.ZERO, Vector2(0, 1)]
	var dp: Vector2 = city.door_point(h)
	return [Vector3(dp.x, game.land.height_at(dp.x, dp.y), dp.y), City.facing(float(h["yaw"]))]


func _beat_start(b: Array) -> void:
	var sd: Dictionary = cine["story"]
	var bind: Dictionary = cine["bind"]
	match String(b[0]):
		"actor":
			_actor(String(b[1]), String(b[2]))
		"fly":
			var shot: Array
			if String(b[1]) == "square":
				shot = _square_shot(_sq_center(bind))
				cine["focus"] = _sq_center(bind)
			elif String(b[1]) == "proc":
				shot = (cine.get("proc", {}) as Dictionary).get("shot", [])
				if shot.is_empty():
					return
				cine["focus"] = Vector2((shot[1] as Vector3).x, (shot[1] as Vector3).z)
			else:
				var w := _who_at(String(b[1]))
				shot = _talk_shot(w[0], w[1], String(b[1]) == "cat")
				cine["focus"] = Vector2((w[0] as Vector3).x, (w[0] as Vector3).z)
			var cd: Vector2 = Vector2((shot[0] as Vector3).x, (shot[0] as Vector3).z) - (cine["focus"] as Vector2)
			cine["cam_dir"] = cd.normalized() if cd.length() > 0.01 else Vector2(0, 1)
			if bool(cine.get("snap", false)):
				cine["snap"] = false
				kit.cam_set(shot[0], shot[1])
			else:
				kit.cam_to(shot[0], shot[1], 1.7)
		"anim":
			if String(b[1]) == "guests":
				var k := 0
				for r in cine["actors"]:
					if String(r) in ["bride", "groom"]:
						continue
					# гости — кто как: зеркально, вразнобой, не в такт
					var gc := cine["actors"][r] as Citizen
					var an := String(b[2])
					if k % 2 == 1 and gc.anim.has_animation(an + "_M"):
						an += "_M"
					gc.play(an, 0.3, k * 0.37)
					k += 1
			else:
				var c = cine["actors"].get(String(b[1]))
				if c != null:
					(c as Citizen).play(String(b[2]))
		"walk":
			var c = cine["actors"].get(String(b[1]))
			if c != null:
				(c as Citizen).play(String(b[3]) if b.size() > 3 else "Walk")
		"say":
			ui.say(_speaker(String(b[1])), StoryDefs.fill(String(b[2]), bind))
			var c = cine["actors"].get(String(b[1]))
			if c != null and String(b[1]) != "cat" and (c as Citizen)._cur in ["Idle", "Look_Around"]:
				(c as Citizen).play("Idle_Talking")
			cine["wait"] = true
		"choice":
			ui.say(_speaker(String(b[1])), StoryDefs.fill(String(b[2]), bind))
			var opts := _avail(b[3])
			cine["opts"] = opts
			ui.choices(opts, _picked)
		"cat":
			_cat_state(String(b[1]))
		"fx":
			var w := _who_at(String(b[2]))
			if String(b[1]) == "hearts":
				ui.hearts((w[0] as Vector3) + Vector3(0, 0.25, 0))
			elif String(b[1]) == "petals":
				ui.petals((w[0] as Vector3) + Vector3(0, 0.6, 0))
			else:
				game._puff(w[0], Color("fff3c8"))
		"reward":
			kit.say_caption(_reward_caption())
			if game.sound:
				game.sound.ui("coins")       # из звуков интерфейса владелец оставил только монетки
		"cut":
			cine["cut"] = 0.0
		"elders":
			life.force_on(_sq_center(bind), _sq_r(sd))
		"dusk":
			cine["dusk"] = true
			game.look_hour = DUSK
			game._set_hour(game.hour)
		"proc":
			if String(b[1]) == "set":
				_proc_set()
		"cheer":
			_cheer(String(b[1]))
		"enter":
			_enter_house()
		"wait":
			pass


## Ролик идёт: камера долетела, человек дошёл, пауза кончилась — следующий такт
func _beat_tick(dt: float) -> void:
	if cine.is_empty() or bool(cine["end"]):
		return
	ui.track()
	var fl = cine.get("fill")
	if fl != null and is_instance_valid(fl) and game.rig != null:
		(fl as Node3D).global_transform.basis = game.rig.cam.global_transform.basis * Basis(Vector3.RIGHT, -0.3)
	_crowd_clear()
	cine["bt"] = float(cine["bt"]) + dt
	var bt: float = cine["bt"]
	var beats: Array = cine["beats"]
	var i := int(cine["i"])
	if i < 0 or i >= beats.size():
		return
	var b: Array = beats[i]
	match String(b[0]):
		"fly":
			if not kit.moving() or bt > 3.0:
				_next_beat()
		"anim", "actor", "cat", "elders", "dusk":
			if bt >= 0.35:
				_next_beat()
		"proc":
			if String(b[1]) != "walk" or _proc_step(dt) or bt > 30.0:
				_next_beat()
		"cheer":
			if bt >= 1.4:
				_next_beat()
		"enter":
			_enter_step_fade(dt)
			if bt >= 1.6:
				_next_beat()
		"fx":
			if bt >= 0.6:
				_next_beat()
		"reward":
			if bt >= 0.4:
				_next_beat()
		"wait":
			if bt >= float(b[1]):
				_next_beat()
		"walk":
			if _walk_step(String(b[1]), dt) or bt > 6.0:
				var c = cine["actors"].get(String(b[1]))
				if c != null:
					(c as Citizen).play("Idle")
				_next_beat()
		"cut":
			# смена сцены: затемнение, люди — прочь, следующий кадр — сразу
			var veil: ColorRect = kit.veil
			if bt < 0.4:
				veil.color.a = bt / 0.4
			elif not cine.has("cut_done"):
				cine["cut_done"] = true
				veil.color.a = 1.0
				for k in cine["actors"]:
					var c = cine["actors"][k]
					if c != null and is_instance_valid(c):
						(c as Node).queue_free()
				cine["actors"] = {}
				cine["snap"] = true
				if ui.panel != null:
					ui.panel.modulate.a = 0.0
			if bt >= 0.4:
				cine.erase("cut_done")
				var tw := veil.create_tween()
				tw.tween_property(veil, "color:a", 0.0, 0.5)
				_next_beat()


## Подпись внизу ролика: что дала история
func _reward_caption() -> String:
	var e: Dictionary = (S()["done"] as Dictionary).get(String(cine["story"]["id"]), {})
	var t := String(e.get("text", ""))
	if t == "" or cine["mode"] == "replay":
		return String(cine["story"].get("line", ""))
	var k := t.find("Награда:")
	return t.substr(k) if k >= 0 else t


func _picked(val: String) -> void:
	cine["choice"] = val
	for o: Array in cine.get("opts", []):
		if String(o[1]) == val and o.size() > 2:
			var b: Array = cine["beats"][int(cine["i"])]
			ui.say(_speaker(String(b[1])), StoryDefs.fill(String(o[2]), cine["bind"]))
			cine["wait"] = true
			return
	_next_beat()


## Человек для ролика: у двери дома (лицом на улицу) или в нескольких шагах от кошки (лицом к ней)
func _actor(role: String, where: String) -> void:
	var b: Dictionary = cine["bind"]
	var c := _make_actor(role)
	var h: Dictionary = city.buildings.get(int(b.get("home", -1)), {})
	var p := Vector2.ZERO
	var yaw := 0.0
	if where == "beside" and not (cine["actors"] as Dictionary).is_empty():
		# рядом с первым (жених рядом с невестой): на шаг в сторону, чуть повернувшись к ней
		var o: Node3D = cine["actors"].values()[0]
		var f := Vector2(sin(o.rotation.y), cos(o.rotation.y))
		var side := Vector2(f.y, -f.x)
		p = Vector2(o.position.x, o.position.z) + side * 0.95 - f * 0.15
		yaw = o.rotation.y + 0.35
	elif where == "square":
		# старик — посреди скверика, на просторе (не у стены), лицом к своему дому: скверик со стариками — за ним
		var sc := _sq_center(b)
		p = _open_spot(sc)
		var to: Vector2 = (h["pos"] as Vector2) if not h.is_empty() else p + Vector2(0, 1)
		yaw = atan2(to.x - p.x, to.y - p.y)
	elif where == "near_cat":
		var cp3: Vector3 = _who_at("cat")[0]
		var cp := Vector2(cp3.x, cp3.z)
		p = _approach()
		yaw = atan2(cp.x - p.x, cp.y - p.y)
	elif not h.is_empty():
		var f := City.facing(float(h["yaw"]))
		p = city.door_point(h) + f * 1.0
		yaw = atan2(f.x, f.y)
	c.position = Vector3(p.x, game.land.height_at(p.x, p.y), p.y)
	c.rotation.y = yaw
	c.play("Idle")
	_put_actor(role, c)


## Свободное место у точки c, где вокруг (1,2 м) ни построек, ни воды: человеку в кадре не мешает стена
func _open_spot(c: Vector2) -> Vector2:
	for r: float in [0.0, 1.0, 2.0, 3.0, 4.0, 5.5, 7.0]:
		for k in (1 if r == 0.0 else 12):
			var q := c + Vector2(cos(k * TAU / 12.0), sin(k * TAU / 12.0)) * r
			var ok: bool = game.people._hide_ok(q)
			for j in 8:
				ok = ok and game.land.occ_at(q + Vector2(cos(j * TAU / 8.0), sin(j * TAU / 8.0)) * 1.2) == 0
			if ok:
				return q
	var q: Vector2 = game.people._near_free(c, 12)
	return q if q != Vector2.INF else c


## Человек роли для ролика: облик по роли; festive — на свадьбе невеста в платье цвета огня и с венком
func _make_actor(role: String, festive := false) -> Citizen:
	var ro := _role(cine["bind"], role)
	var c: Citizen = game.people.actor(int(ro["seed"]), bool(ro["female"]), bool(ro["child"]), String(ro["cls"]), bool(ro.get("old", false)))
	if role == "bride" and festive:
		_bride_look(c)
	return c


## Невеста: платье цвета огня (flammeum — так в Риме одевались к свадьбе) и венок
static func _bride_look(c: Citizen) -> void:
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		for mi: MeshInstance3D in c.find_children("*", "MeshInstance3D", true, false):
			mi.set_instance_shader_parameter("cloth_main", Color("e98a2e").srgb_to_linear())
			mi.set_instance_shader_parameter("cloth_second", Color("f4ead6").srgb_to_linear())
	var sks := c.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return
	var att := BoneAttachment3D.new()
	att.bone_name = "Head"
	(sks[0] as Skeleton3D).add_child(att)
	var cr := (load("res://assets/synty/FBX/Attachments/SM_Chr_Attach_Crown_Leaf_01.fbx") as PackedScene).instantiate() as Node3D
	for mi: MeshInstance3D in cr.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = Citizen._plain("A")
		mi.layers |= Citizen.FACE_LAYER
	att.add_child(cr)


func _put_actor(role: String, c: Citizen) -> void:
	var old = cine["actors"].get(role)
	if old != null and is_instance_valid(old):
		(old as Node).queue_free()
	cine["actors"][role] = c


## Кадр «разговор»: камера перед героем (p, лицом по f) чуть сбоку, смотрит чуть ниже него — он в середине кадра,
## над облачком. В тесном городе ищем точку, откуда героя не заслоняют ни дома, ни заборы (и камера не в стене);
## всё заслонено — повыше и ближе, почти сверху
func _talk_shot(p: Vector3, f: Vector2, is_cat: bool) -> Array:
	var d0 := 3.6 if is_cat else 5.2
	var h0 := 1.5 if is_cat else 1.9
	var turns := [0.55, -0.55, 0.95, -0.95, 0.2, -0.2, 1.35, -1.35] if is_cat else [0.42, -0.42, 0.8, -0.8, 0.1, 1.2, -1.2]
	for k: float in [1.0, 0.8]:
		for turn: float in turns:
			var dir := f.rotated(-turn)
			var cam := p + Vector3(dir.x, 0, dir.y) * d0 * k + Vector3.UP * h0 * k
			if _clear_view(Vector2(cam.x, cam.z), Vector2(p.x, p.z)):
				return [cam, p + Vector3.UP * (0.1 if is_cat else 0.3) - Vector3(dir.x, 0, dir.y) * 0.6]
	# тесно (узкая улица, напротив дома): повыше, над заборами и украшениями — не вплотную к лицу
	for hk: float in [1.8, 2.6]:
		for turn: float in turns:
			var dir := f.rotated(-turn)
			var cam := p + Vector3(dir.x, 0, dir.y) * d0 + Vector3.UP * h0 * hk
			if _clear_view3(cam, p + Vector3.UP * (0.2 if is_cat else 1.0)):
				return [cam, p + Vector3.UP * (0.1 if is_cat else 0.5) - Vector3(dir.x, 0, dir.y) * 0.6]
	for turn: float in turns:
		var dir := f.rotated(-turn)
		var cam := p + Vector3(dir.x, 0, dir.y) * d0 * 0.62 + Vector3.UP * h0 * 0.62
		if _clear_view(Vector2(cam.x, cam.z), Vector2(p.x, p.z)):
			return [cam, p + Vector3.UP * (0.1 if is_cat else 0.3) - Vector3(dir.x, 0, dir.y) * 0.6]
	return [p + Vector3(f.x, 0, f.y) * 2.2 + Vector3.UP * 5.0, p + Vector3.UP * 0.3]


## То же, но с высотой: луч от камеры до героя идёт над низкими украшениями и крышами ниже него, но не сквозь дом и не
## сквозь холм. Высота постройки — по её чертежу (top_y)
func _clear_view3(cam: Vector3, at: Vector3) -> bool:
	var a := Vector2(cam.x, cam.z)
	var b := Vector2(at.x, at.z)
	var n := maxi(1, int(a.distance_to(b) / 0.15))
	var tops := {}
	for k in n:
		var u := float(k) / n
		var q := a.lerp(b, u)
		if q.distance_to(b) < 0.7:
			break
		var y := lerpf(cam.y, at.y, u)
		if y < game.land.height_at(q.x, q.y) + 0.15:
			return false
		var id: int = game.land.occ_at(q)
		if id == 0:
			continue
		if not tops.has(id):
			var bb: Dictionary = city.buildings.get(id, {})
			tops[id] = float(bb["y"]) + city.blueprint(bb).top_y() if not bb.is_empty() else INF
		if y < float(tops[id]):
			return false
	# кроны деревьев шире ствола (на земле занят только ствол): луч сквозь крону — тоже заслонено
	for cr: Array in _crowns(b):
		var cp: Vector2 = cr[0]
		var q := Geometry2D.get_closest_point_to_segment(cp, a, b)
		if q.distance_to(cp) > float(cr[1]) or q.distance_to(b) < 1.5:
			continue
		var u := a.distance_to(q) / maxf(a.distance_to(b), 0.01)
		var y := lerpf(cam.y, at.y, u)
		if y > float(cr[2]) and y < float(cr[3]):
			return false
	return true


## Кроны деревьев (украшения и природа) в 45 м от точки: [середина, радиус, низ кроны, верх] — один раз на ролик
func _crowns(near: Vector2) -> Array:
	if cine.has("crowns") and (cine["crowns_at"] as Vector2).distance_to(near) < 15.0:
		return cine["crowns"]
	var out := []
	for id in city.buildings:
		var b: Dictionary = city.buildings[id]
		if String(Defs.B.get(b["type"], {}).get("sub", "")) != "trees" or (b["pos"] as Vector2).distance_to(near) > 45.0:
			continue
		var top: float = city.blueprint(b).top_y()
		out.append([b["pos"], clampf(top * 0.4, 0.8, 2.2), float(b["y"]) + top * 0.45, float(b["y"]) + top])
	var k0 := Vector2i(int(near.x / 2.0), int(near.y / 2.0))
	for j in range(-22, 23):
		for i in range(-22, 23):
			for it: Dictionary in game.nature.get(k0 + Vector2i(i, j), []):
				if String(it.get("name", "")).contains("Tree") and (it["p"] as Vector2).distance_to(near) <= 45.0:
					var p: Vector2 = it["p"]
					var gy: float = game.land.height_at(p.x, p.y)
					out.append([p, 2.0, gy + 2.0, gy + 6.5])
	if not cine.is_empty():
		cine["crowns"] = out
		cine["crowns_at"] = near
	return out


## Между камерой (a) и героем (b) по земле — ни построек, ни украшений (у самого героя — можно: он у двери, у копны)
func _clear_view(a: Vector2, b: Vector2) -> bool:
	var len := a.distance_to(b)
	var n := int(len / 0.12)
	for k in n:
		var q := a.lerp(b, float(k) / n)
		if q.distance_to(b) < 0.7:
			break
		if game.land.occ_at(q) != 0:
			return false
	return true


## Откуда мальчик прибежит к кошке: в 4,2 м от неё, со стороны его дома, по прямой без построек (одно на ролик)
func _approach() -> Vector2:
	if cine.has("approach"):
		return cine["approach"]
	var tc = cine.get("tcat")
	var cp3: Vector3 = _cat_pos() if tc == null else (tc as Node3D).position
	var cp := Vector2(cp3.x, cp3.z)
	var h: Dictionary = city.buildings.get(int(cine["bind"].get("home", -1)), {})
	var from: Vector2 = city.door_point(h) if not h.is_empty() else cp + Vector2(4, 0)
	var dir := (from - cp).normalized() if from.distance_to(cp) > 0.1 else Vector2(1, 0)
	var p := cp + dir * 4.2
	var cands := []
	if cine.has("cam_dir"):
		# камера уже смотрит на кошку: мальчик вбегает в кадр сбоку (не из-за камеры и не заслоняя кошку)
		var cd: Vector2 = cine["cam_dir"]
		for a: float in [PI / 2, -PI / 2, PI / 2 - 0.35, -PI / 2 + 0.35, PI / 2 + 0.35, -PI / 2 - 0.35, PI / 2 - 0.7, -PI / 2 + 0.7]:
			cands.append(cp + cd.rotated(a) * 3.2)
	for k in 12:
		cands.append(cp + dir.rotated(0.5 * ((k + 1) / 2) * (1 if k % 2 == 0 else -1)) * 4.2)
	for q: Vector2 in cands:
		if _clear_run(q, cp):
			p = q
			break
	cine["approach"] = p
	return p


## Прохожие не заслоняют героя: кто рядом с ним или на линии камеры — прячется до конца ролика
func _crowd_clear() -> void:
	if kit == null or not cine.has("focus"):
		return
	var focus: Vector2 = cine["focus"]
	var cam := Vector2(kit.pos.x, kit.pos.z)
	for r in game.people.residents:
		var n = r["node"]
		if n == null or not (n as Node3D).visible:
			continue
		var p := Vector2((n as Node3D).position.x, (n as Node3D).position.z)
		var q := Geometry2D.get_closest_point_to_segment(p, cam, focus)
		if p.distance_to(focus) < 3.0 or p.distance_to(q) < 1.0:
			(n as Node3D).visible = false
			_hidden.append(n)


## От a до b (у кошки) — ни построек, ни воды, ни круч
func _clear_run(a: Vector2, b: Vector2) -> bool:
	if not game.people._hide_ok(a):
		return false
	var n := int(a.distance_to(b) / 0.3)
	for k in range(1, n):
		var q := a.lerp(b, float(k) / n)
		if game.land.occ_at(q) != 0 or game.land.is_water(q):
			return false
	return true


## Человек бежит к кошке; true — добежал
func _walk_step(role: String, dt: float) -> bool:
	var c = cine["actors"].get(role)
	if c == null or not is_instance_valid(c):
		return true
	var n := c as Node3D
	var cp: Vector3 = _who_at("cat")[0]
	var to := Vector2(cp.x, cp.z)
	var p := Vector2(n.position.x, n.position.z)
	var d := to - p
	var stop := 0.5
	if d.length() <= stop:
		return true
	var mv := 1.7 * dt
	var step := d.normalized() * minf(mv, d.length() - stop)
	p += step
	n.position = Vector3(p.x, game.land.height_at(p.x, p.y), p.y)
	n.rotation.y = atan2(d.x, d.y)
	return d.length() - mv <= stop


## Кошка в ролике: сидит, ласкается, спит (настоящая — через её состояние, в «Пересмотреть» — своя на время);
## сидит и ласкается — головой к мальчику (или туда, откуда он прибежит)
func _cat_state(state: String) -> void:
	var cp := _who_at("cat")[0] as Vector3
	var c = cine["actors"].get("kid")
	var to := Vector2((c as Node3D).position.x, (c as Node3D).position.z) if c != null and is_instance_valid(c) else _approach()
	var yaw := atan2(to.x - cp.x, to.y - cp.z)
	if cine["mode"] == "replay":
		var tc := _tcat()
		tc.rotation.y = yaw
		for ap: AnimationPlayer in tc.find_children("*", "AnimationPlayer", true, false):
			var cl: Array = People.CAT_CLIP.get(state, People.CAT_CLIP["sit"])
			ap.play("cat/" + String(cl[0]), 0.3)
			ap.speed_scale = float(cl[1])
		return
	if cat.is_empty():
		return
	cat["state"] = state
	_sit_t = 0.0
	if state in ["sit", "pet"]:
		cat["yaw"] = yaw


## Кошка для «Пересмотреть» (своя на время ролика): там, где пряталась, или у дома
func _tcat() -> Node3D:
	var tc = cine.get("tcat")
	if tc != null and is_instance_valid(tc):
		return tc
	var b: Dictionary = cine["bind"]
	var sp: Array = b.get("spot", [])
	var h: Dictionary = city.buildings.get(int(b.get("home", -1)), city.center())
	var p: Vector2 = Vector2(float(sp[0]), float(sp[1])) if sp.size() == 2 else city.door_point(h) + City.facing(float(h["yaw"])) * 5.0
	var n := People.cat_node(int(b.get("fur", 0)), "Sit", 3)
	game.add_child(n)
	n.position = Vector3(p.x, game.land.height_at(p.x, p.y), p.y)
	n.rotation.y = hash(b.get("fam", "")) % 628 / 100.0
	cine["tcat"] = n
	return n


# ---------- скверик и свадьба: варианты выбора, кадры, шествие ----------

## Варианты выбора, которые правда можно выбрать: у варианта с постройками [4-й элемент] хоть одна из них открыта
## (таверна — если изучен термополий или таверна)
func _avail(opts: Array) -> Array:
	var out := []
	for o: Array in opts:
		if o.size() > 3 and o[3] is Array:
			var any := false
			for t in o[3]:
				any = any or city.unlocked(String(t))
			if not any:
				continue
		out.append(o)
	return out if not out.is_empty() else opts


## Варианты выбора истории (без «позже») — для кнопок в золотой строке: [[подпись, значение], …]
func choice_opts(sd: Dictionary) -> Array:
	var out := []
	for st: Dictionary in sd.get("steps", []):
		for b: Array in st.get("cine", []):
			if String(b[0]) == "choice":
				for o: Array in _avail(b[3]):
					if String(o[1]) != "later":
						out.append([String(o[0]), String(o[1])])
				return out
	return out


## Радиус скверика (из цели истории)
static func _sq_r(sd: Dictionary) -> float:
	var st := StoryDefs.goal_step(sd, "square")
	return float(st["goal"][1]) if not st.is_empty() else 15.0


## Середина скверика: запомненная (когда нажали «Готово») или среди скамеек у дома
func _sq_center(b: Dictionary) -> Vector2:
	var sq: Array = (b.get("flags", {}) as Dictionary).get("sq", [])
	if sq.size() == 2:
		return Vector2(float(sq[0]), float(sq[1]))
	return square_center(b, _sq_r(StoryDefs.story(String(b.get("id", "square")))))


## Общий план скверика: сверху-сбоку, откуда ни дома, ни деревья не заслоняют середину
func _square_shot(c: Vector2) -> Array:
	var h: float = game.land.height_at(c.x, c.y)
	var home: Dictionary = city.buildings.get(int(cine["bind"].get("home", -1)), {})
	var a0 := 0.0
	if not home.is_empty():
		var d: Vector2 = c - (home["pos"] as Vector2)
		a0 = atan2(d.x, d.y)              # со стороны, противоположной дому: дом — фоном
	for k in 10:
		var a: float = a0 + [0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5, 2.2, -2.2, PI][k]
		var dir := Vector2(sin(a), cos(a))
		var cam := c + dir * 10.5
		if _clear_view3(Vector3(cam.x, h + 5.2, cam.y), Vector3(c.x, h + 0.6, c.y)):
			return [Vector3(cam.x, h + 5.2, cam.y), Vector3(c.x, h + 0.4, c.y)]
	return [Vector3(c.x + 5.0, h + 9.0, c.y + 5.0), Vector3(c.x, h + 0.4, c.y)]


## Новый дом молодых для шествия: построенный для них, где они живут теперь, или (пересмотр без дома) дом невесты
func _proc_house(b: Dictionary) -> Dictionary:
	var h: Dictionary = city.buildings.get(int((b.get("flags", {}) as Dictionary).get("built", -1)), {})
	if h.is_empty() and String(b.get("couple", "")) != "":
		h = city.buildings.get(_find_family(String(b["couple"])), {})
	if h.is_empty():
		h = city.buildings.get(int(b.get("home", -1)), city.center())
	return h


## Шествие: путь от дома невесты к новому дому (последние PROC_LEN м), все на местах, у двери — две жаровни
func _proc_set() -> void:
	var b: Dictionary = cine["bind"]
	var to_h := _proc_house(b)
	var from_h: Dictionary = city.buildings.get(int(b.get("home", -1)), {})
	var door: Vector2 = city.door_point(to_h)
	var fwd := City.facing(float(to_h.get("yaw", 0.0)))
	var start: Vector2 = city.door_point(from_h) if not from_h.is_empty() and int(from_h["id"]) != int(to_h["id"]) else door + fwd * (PROC_LEN + 4.0)
	var path: PackedVector2Array = game.people._path(start, door)
	if path.size() < 2:
		path = PackedVector2Array([door + fwd * (PROC_LEN + 4.0), door])
	var lead := 3.4                       # гости идут позади — путь начинается раньше пары
	var pts := _tail(path, PROC_LEN + lead)
	var pr := {"pts": pts, "len": _plen(pts), "s": minf(lead, _plen(pts) * 0.3), "door": door, "cheer": lead + 2.5}
	cine["proc"] = pr
	for e: Array in PROC:
		var c := _make_actor(String(e[0]), true)
		_put_actor(String(e[0]), c)
		c.play("Walk", 0.0, randf())
	_proc_place()
	# камера — сбоку от шествия, с той стороны, где ничто не заслоняет
	var at := _proc_at(pts, float(pr["len"]) * 0.5)
	var mid: Vector2 = at[0]
	var side := Vector2(-(at[1] as Vector2).y, (at[1] as Vector2).x)
	pr["side"] = side if _clear_view(mid + side * 7.0, mid) or not _clear_view(mid - side * 7.0, mid) else -side
	pr["cam_i"] = -1
	pr["shot"] = _proc_cam()
	# огонь у двери нового дома: две жаровни по бокам (только на время ролика)
	var bp := Catalog.make("brazier")
	var ax := Vector2(fwd.y, -fwd.x)
	for sx: float in [-1.0, 1.0]:
		var q := door + ax * 2.1 * sx + fwd * 0.3
		if game.land.occ_at(q) != 0:
			continue
		var xf := Transform3D(Basis(Vector3.UP, float(to_h.get("yaw", 0.0))), Vector3(q.x, game.land.height_at(q.x, q.y), q.y))
		cine["props"].append(game.parts.place(bp, xf))
		for lp in bp.lights:
			cine["lights"].append(game._light(xf * lp, 0.55))
	game._set_hour(game.hour)             # огни в жаровнях разгораются сразу (вечерний свет)


## Последние len м пути
static func _tail(path: PackedVector2Array, len: float) -> PackedVector2Array:
	var out := PackedVector2Array([path[path.size() - 1]])
	var acc := 0.0
	for i in range(path.size() - 1, 0, -1):
		var a := path[i]
		var b := path[i - 1]
		var d := a.distance_to(b)
		if acc + d >= len:
			out.append(a.lerp(b, (len - acc) / maxf(d, 0.001)))
			out.reverse()
			return out
		acc += d
		out.append(b)
	out.reverse()
	return out


static func _plen(pts: PackedVector2Array) -> float:
	var n := 0.0
	for i in pts.size() - 1:
		n += pts[i].distance_to(pts[i + 1])
	return n


## Точка пути на s м от начала и куда он идёт там: [точка, направление]
static func _proc_at(pts: PackedVector2Array, s: float) -> Array:
	var acc := 0.0
	s = maxf(0.0, s)
	for i in pts.size() - 1:
		var d := pts[i].distance_to(pts[i + 1])
		if acc + d >= s or i == pts.size() - 2:
			var dir := (pts[i + 1] - pts[i]).normalized() if d > 0.001 else Vector2(0, 1)
			return [pts[i].lerp(pts[i + 1], clampf((s - acc) / maxf(d, 0.001), 0.0, 1.0)), dir]
		acc += d
	return [pts[0], Vector2(0, 1)]


## Все на своих местах в шествии (направление — сглаженное по паре метров пути: на углах не дёргаются)
func _proc_place() -> void:
	var pr: Dictionary = cine["proc"]
	var pts: PackedVector2Array = pr["pts"]
	for e: Array in PROC:
		var c = cine["actors"].get(String(e[0]))
		if c == null or not is_instance_valid(c):
			continue
		var s0 := float(pr["s"]) + float(e[1])
		var a := _proc_at(pts, s0)
		var f: Vector2 = (_proc_at(pts, s0 + 0.8)[0] as Vector2) - (_proc_at(pts, s0 - 0.8)[0] as Vector2)
		f = f.normalized() if f.length() > 0.01 else (a[1] as Vector2)
		# у стены сбоку места нет — ближе к середине пути (жених тогда чуть позади), а не сквозь стену
		var sn := Vector2(-f.y, f.x)
		var want := float(e[2])
		var lat := 0.0
		for k: float in [1.0, 0.6, 0.3, 0.0]:
			var p2: Vector2 = (a[0] as Vector2) + sn * want * k
			if game.land.occ_at(p2) == 0 and game.land.occ_at(p2 + sn * (0.32 if want >= 0.0 else -0.32)) == 0:
				lat = want * k
				break
		var lats: Dictionary = pr.get("lat", {})
		var cur := float(lats.get(String(e[0]), lat))
		cur = lerpf(cur, lat, 0.2) if bool(pr.get("placed", false)) else lat
		lats[String(e[0])] = cur
		pr["lat"] = lats
		if String(e[0]) == "groom" and absf(cur) < 0.2:
			a = _proc_at(pts, s0 - 0.6)
		var q: Vector2 = (a[0] as Vector2) + sn * cur
		var n := c as Node3D
		n.position = Vector3(q.x, game.land.height_at(q.x, q.y), q.y)
		n.rotation.y = lerp_angle(n.rotation.y, atan2(f.x, f.y), 0.25) if bool(pr.get("placed", false)) else atan2(f.x, f.y)
	pr["placed"] = true


## Откуда смотреть на шествие (от пары): [вперёд, вбок, высота] — спереди (идут на камеру), сбоку, выше, сверху
const PROC_CAMS := [[6.0, 1.4, 2.3], [2.2, 6.2, 2.6], [2.2, -6.2, 2.6], [4.0, 4.6, 4.6], [4.0, -4.6, 4.6], [5.5, 0.0, 4.2],
	[-5.5, 1.5, 3.8], [4.0, 0.5, 5.6], [-4.0, 0.5, 5.6], [3.0, 5.0, 6.5], [3.0, -5.0, 6.5], [2.0, 2.0, 8.0]]


## Камера шествия: из PROC_CAMS — первая по порядку, откуда видно пару (раз в 0,8 с; между проверками — прежняя, пока
## её видно: камера не мечется); смотрит на пару
func _proc_cam() -> Array:
	var pr: Dictionary = cine["proc"]
	var a := _proc_at(pr["pts"], float(pr["s"]) - 0.4)
	var c: Vector2 = a[0]
	var d: Vector2 = a[1]
	var side: Vector2 = pr["side"]
	var h: float = game.land.height_at(c.x, c.y)
	var head := Vector3(c.x, h + 1.0, c.y)
	var order := range(PROC_CAMS.size())
	var ci := int(pr.get("cam_i", -1))
	if ci >= 0 and float(pr.get("re", 0.0)) > 0.0:
		order.erase(ci)
		order.push_front(ci)
	else:
		pr["re"] = 0.8
	var pick := PROC_CAMS.size() - 1
	for i: int in order:
		var e: Array = PROC_CAMS[i]
		var q := c + d * float(e[0]) + side * float(e[1])
		if _clear_view3(Vector3(q.x, h + float(e[2]), q.y), head):
			pick = i
			break
	pr["cam_i"] = pick
	var e: Array = PROC_CAMS[pick]
	var q := c + d * float(e[0]) + side * float(e[1])
	return [Vector3(q.x, h + float(e[2]), q.y), Vector3(c.x, h + 0.7, c.y) + Vector3(d.x, 0, d.y) * 0.5]


## Шествие идёт: шаг, камера следом, гости кричат «Таласио!»; true — пара у двери (повернулась к гостям)
func _proc_step(dt: float) -> bool:
	var pr: Dictionary = cine.get("proc", {})
	if pr.is_empty():
		return true
	var stop := float(pr["len"]) - 1.2
	if pr.has("aside"):
		return _proc_aside(dt)
	pr["re"] = float(pr.get("re", 0.0)) - dt
	pr["s"] = minf(stop, float(pr["s"]) + PROC_V * dt)
	_proc_place()
	var shot := _proc_cam()
	if not kit.moving():
		kit.cam_set(kit.pos.lerp(shot[0], minf(1.0, dt * 2.5)), kit.look.lerp(shot[1], minf(1.0, dt * 3.0)))
	cine["focus"] = Vector2((shot[1] as Vector3).x, (shot[1] as Vector3).z)
	if float(pr["s"]) >= float(pr["cheer"]):
		pr["cheer"] = float(pr["cheer"]) + 5.0
		_cheer("Таласио!")
	if float(pr["s"]) < stop:
		return false
	# пришли: молодые поворачиваются к улице, гости расступаются по бокам (перед молодыми — камера)
	var cp := Vector2.ZERO
	var fs := Vector2.ZERO
	for r in ["bride", "groom"]:
		var n = cine["actors"].get(r)
		if n != null and is_instance_valid(n):
			cp += Vector2((n as Node3D).position.x, (n as Node3D).position.z) * 0.5
			(n as Node3D).rotation.y += PI
			(n as Citizen).play("Idle", 0.3)
			fs = Vector2(sin((n as Node3D).rotation.y), cos((n as Node3D).rotation.y))
	var aside := {}
	var k := 0
	for e: Array in PROC:
		if String(e[0]) in ["bride", "groom"]:
			continue
		var a: float = [1.05, -1.05, 1.5, -1.5][k % 4]
		var q := cp + fs.rotated(a) * (1.7 + 0.35 * (k / 2))
		if not game.people._hide_ok(q):
			q = cp + fs.rotated(a * 0.6) * 2.2
		aside[String(e[0])] = q
		k += 1
	pr["aside"] = aside
	pr["cp"] = cp
	pr["at"] = 0.0
	return false


## Гости отходят в стороны и поворачиваются к молодым; true — встали
func _proc_aside(dt: float) -> bool:
	var pr: Dictionary = cine["proc"]
	pr["at"] = float(pr["at"]) + dt
	var cp: Vector2 = pr["cp"]
	var done := true
	for r in pr["aside"]:
		var c = cine["actors"].get(r)
		if c == null or not is_instance_valid(c):
			continue
		var n := c as Node3D
		var p := Vector2(n.position.x, n.position.z)
		var to: Vector2 = pr["aside"][r]
		if p.distance_to(to) > 0.05 and float(pr["at"]) < 2.5:
			done = false
			var d := (to - p).normalized()
			p = p.move_toward(to, 1.3 * dt)
			n.position = Vector3(p.x, game.land.height_at(p.x, p.y), p.y)
			n.rotation.y = lerp_angle(n.rotation.y, atan2(d.x, d.y), 0.3)
			(c as Citizen).play("Walk", 0.2)
		else:
			n.rotation.y = lerp_angle(n.rotation.y, atan2(cp.x - p.x, cp.y - p.y), 0.25)
			(c as Citizen).play("Idle", 0.3)
	return done and float(pr["at"]) > 0.6


## Гости кричат (подписи над ними, вразнобой)
func _cheer(text: String) -> void:
	var k := 0
	for r in cine["actors"]:
		if String(r) in ["bride", "groom"] or k >= 3:
			continue
		var n = cine["actors"][r]
		if n == null or not is_instance_valid(n):
			continue
		ui.bubble3d((n as Node3D).position + Vector3(0, 1.45 + 0.12 * k, 0), text, 2.2, 26)
		k += 1


## Молодые входят в новый дом: поворачиваются к двери и идут (тают — _enter_step_fade)
func _enter_house() -> void:
	var pr: Dictionary = cine.get("proc", {})
	if pr.is_empty():
		return
	var door: Vector2 = pr["door"]
	for r in ["bride", "groom"]:
		var c = cine["actors"].get(r)
		if c != null and is_instance_valid(c):
			var n := c as Node3D
			n.rotation.y = atan2(door.x - n.position.x, door.y - n.position.z)
			(c as Citizen).play("Walk", 0.2)


func _enter_step_fade(dt: float) -> void:
	var pr: Dictionary = cine.get("proc", {})
	if pr.is_empty():
		return
	var door: Vector2 = pr["door"]
	var t := float(cine["bt"])
	for r in ["bride", "groom"]:
		var c = cine["actors"].get(r)
		if c == null or not is_instance_valid(c):
			continue
		var n := c as Node3D
		var p := Vector2(n.position.x, n.position.z)
		if p.distance_to(door) > 0.15:
			p = p.move_toward(door, 0.9 * dt)
			n.position = Vector3(p.x, game.land.height_at(p.x, p.y), p.y)
		(c as Citizen).set_alpha(clampf(1.0 - (t - 0.6) / 0.9, 0.0, 1.0))
