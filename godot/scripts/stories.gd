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
const WAIT_HOME_H := 24                # семья без дома (снесли): столько часов ждём, пока заселится, потом история прерывается

var game
var hud
var city: City
var ui: StoryUi
var force := false                     # проверки: истории и когда игра — не главная сцена
var kit: CineKit = null                # идёт ролик
var cine := {}                         # ролик: такты, где он, кто в кадре, выбор, что потом
var cat := {}                          # кошка, которую ищут (запись в people.cats)
var _poll := 0.0
var _h_seen := -1
var _meow_t := 10.0
var _sit_t := 0.0                      # кошка мяукнула — сидит, потом снова спит
var _glow: Decal = null
var _paws: Array = []
var _paws_key := ""
var _spot_cache := {}                  # «дом:час» → кошке есть где спрятаться
var _hidden: Array = []                # прохожие, спрятанные на время ролика (заслоняли героя)
var _tried := ""                       # с чем последний раз искали, кому предложить историю


func setup(g) -> void:
	game = g
	hud = g.hud
	city = g.city
	ui = StoryUi.new(self)
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
	var a: Dictionary = s["active"]
	if not a.is_empty() and _goal_kind(a) == "find" and a.has("spot"):
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


## Пора предложить новую историю: обучение кончилось, прошло FIRST_H (первая) или GAP_H (после прошлой)
func time_ok() -> bool:
	if int(city.tips.get("tut", -1)) >= 0 or hud.ui_level() < 3:
		return false
	var s := S()
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
	var fo := StoryDefs.find_opts(sd)
	for bind: Dictionary in _cast(sd).slice(0, 4):
		if fo.is_empty() or _spot_ok(bind, fo):
			if bind.has("fam"):
				bind["seed"] = _fair_seed(hash(String(bind["fam"])) & 0xffffff)
			return bind
	return {}


## Кошке есть где спрятаться у этого дома (поиск пути — дорогой: ответ помним до конца игрового часа)
func _spot_ok(bind: Dictionary, fo: Dictionary) -> bool:
	var key := "%d:%d" % [int(bind["home"]), int(S()["h"])]
	if not _spot_cache.has(key):
		if _spot_cache.size() > 64:
			_spot_cache.clear()
		var home: Dictionary = city.buildings[int(bind["home"])]
		var spot: Vector2 = game.people.hide_spot(city.door_point(home), float(fo["rmin"]), float(fo["rmax"]), fo.get("hide", []), _rng(bind, 1))
		_spot_cache[key] = spot != Vector2.INF
	return bool(_spot_cache[key])


## Кого просить: дома нужного класса, где живёт семья с ребёнком, — ближние к станции первыми; [{home, fam, kid, seed…}]
func _cast(sd: Dictionary) -> Array:
	var cast: Dictionary = sd.get("cast", {})
	var ctr := city.center()
	if cast.is_empty():
		return [] if ctr.is_empty() else [{"home": int(ctr["id"]), "fam": "", "kid": ""}]
	var role: Dictionary = cast.values()[0]
	var cls := String(role.get("cls", "plebs"))
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
		if not city.is_house(b) or String(city.def(b)["cls"]) != cls or int(b["pop"]) <= 0:
			continue
		for f: Dictionary in b["families"]:
			var fam := String(f["name"])
			if child and not kids.has("%s|%d" % [fam, int(id)]):
				continue
			out.append({"home": int(id), "fam": fam, "kid": StoryDefs.boy(fam), "cls": cls, "female": bool(role.get("female", false)),
				"child": child, "d": (b["pos"] as Vector2).distance_to(c0)})
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
	if String(cine.get("choice", "go")) == "later":
		postpone()
		return
	accept()


## Согласились помочь: история идёт, со второго шага
func accept() -> void:
	var s := S()
	var o: Dictionary = s["offer"]
	if o.is_empty():
		return
	var a := o.duplicate(true)
	a["flags"] = {}
	a["step"] = 0
	s["active"] = a
	s["offer"] = {}
	_enter_step(1)
	hud.refresh()


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


func _tick_active() -> void:
	var s := S()
	var a: Dictionary = s["active"]
	if _story(a).is_empty():
		s["active"] = {}
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
	if not cat.is_empty() and a.has("spot"):
		var cp: Vector2 = cat["p"]
		a["spot"] = [cp.x, cp.y]         # на кошку поставили постройку — она перебралась рядом
	if a.get("ready", false):
		return
	var st := _step(a)
	if not st.has("goal") or _goal_kind(a) == "find":
		return
	var pr := progress(a, st["goal"])
	if bool(pr["ok"]):
		_advance(false)


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
		var hp := _home_pos(a)
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
		(s["bonus"] as Array).append({"id": id, "line": line, "pct": int(pct), "x": hp.x, "z": hp.y, "r": float(mo[1]), "left": -1})
		out.append("домам в %d м +%d%% счастья навсегда" % [int(mo[1]), int(pct)])
	if r.has("rp") and full:
		city.rp = maxf(city.rp, minf(city.rp_cap(), city.rp + float(r["rp"])))
		out.append("+%d очков исследований" % int(r["rp"]))
	if r.has("glory"):
		city.legion.glory += int(r["glory"])
		out.append("+%d Славы" % int(r["glory"]))
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
			var n := _count_near(String(g[1]), hp, float(g[2]), int(a.get("id0", 0)))
			return {"have": mini(n, 1), "need": 1, "ok": n > 0, "txt": ""}
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


## Сколько построек вида base (тип или облик украшения) в r м от p; after ≥ 0 — только построенные после (born > after)
func _count_near(base: String, p: Vector2, r: float, after: int) -> int:
	var n := 0
	for id in city.buildings:
		var b: Dictionary = city.buildings[id]
		if b["type"] != base and Defs.base_of(b["type"]) != base:
			continue
		if after >= 0 and int(b.get("born", id)) < after:
			continue
		if (b["pos"] as Vector2).distance_to(p) <= r:
			n += 1
	return n


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
			flags["choice"] = val
	_tick_active()
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
		elif not a.is_empty() and a.get("ready", false) and _lives(a):
			key = "story"
			pos = _badge_pos(int(a["home"]))
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
	_area_marks(area, a)


## Место поисков: мягкое пятно тёплого света на земле (не кольцо) и цепочка следов лапок от дома в его сторону
func _area_marks(area: Array, a: Dictionary) -> void:
	if area.is_empty():
		if _glow != null:
			_glow.queue_free()
			_glow = null
		for p in _paws:
			(p as Node).queue_free()
		_paws = []
		_paws_key = ""
		return
	var c := Vector2(float(area[0]), float(area[1]))
	var r := float(area[2])
	if _glow == null:
		_glow = Decal.new()
		_glow.texture_albedo = StoryUi.glow_tex()
		_glow.modulate = Color(1.0, 0.82, 0.42, 0.5)
		_glow.albedo_mix = 1.0
		_glow.normal_fade = 0.6
		_glow.upper_fade = 0.2
		_glow.lower_fade = 0.2
		_glow.cull_mask = Game.LAND_LAYER   # только земля: дома, люди и деревья не светятся
		game.add_child(_glow)
	_glow.size = Vector3(r * 2.0, 8.0, r * 2.0)
	_glow.position = Vector3(c.x, game.land.height_at(c.x, c.y), c.y)
	var k := "%.1f,%.1f,%.1f" % [c.x, c.y, r]
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
		var pd := Decal.new()
		pd.texture_albedo = StoryUi.paw_tex()
		pd.modulate = Color(0.32, 0.2, 0.11, 0.8 * (1.0 - 0.05 * i))
		pd.size = Vector3(0.6, 2.0, 0.6)
		pd.normal_fade = 0.6
		pd.cull_mask = Game.LAND_LAYER
		pd.position = Vector3(q.x, game.land.height_at(q.x, q.y), q.y)
		pd.rotation.y = atan2(dir.x, dir.y) + PI
		game.add_child(pd)
		_paws.append(pd)


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
	if _goal_kind(a) == "find":
		var g: Dictionary = _step(a)["goal"][2]
		var hours := int(S()["h"]) - int(a.get("t0", S()["h"]))
		var ar: Array = a.get("area1" if hours >= int(g.get("shrink_h", 3)) else "area0", [])
		if not ar.is_empty():
			c = Vector2(float(ar[0]), float(ar[1]))
	var rig = game.rig
	rig._target_t = Vector3(c.x, game.land.height_at(c.x, c.y), c.y)
	rig._dist_t = clampf(rig._dist_t, 30.0, 55.0)


## Советник один раз: что такое истории горожан (когда появилось первое предложение)
func _advise_once() -> void:
	if (S()["offer"] as Dictionary).is_empty() or city.tips.has("story_tip") or not hud._tip_free():
		return
	city.tips["story_tip"] = true
	hud.advisor("Истории горожан", "Горожане иногда просят градоначальника о помощи. Над домом просящего появился свиток, а наверху «Просьб горожан» — золотая строка.\n\n" \
		+ "Щёлкните по свитку, когда будет время, — житель сам расскажет, что случилось. Не до того — нажмите «Отложить»: он попросит снова через сутки. За помощь горожане отблагодарят: редкое украшение, радость в доме, очки исследований. Пройденные истории — в журнале (книжка у «Просьб горожан»).")


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
		return {"title": sd["title"], "icon": sd.get("icon", "scroll"), "text": "%s просит о помощи" % StoryDefs.fill(String(sd.get("who", "")), o),
			"tip": StoryDefs.fill(String(sd.get("ask", "")), o) + "\nНажмите «Выслушать» или свиток над их домом.",
			"buttons": [["Выслушать", open_offer], ["Отложить", postpone]]}
	if a.is_empty():
		return {}
	var sd := _story(a)
	if sd.is_empty():
		return {}
	var info := {"title": sd["title"], "icon": sd.get("icon", "scroll"), "buttons": []}
	if a.has("homeless"):
		info["text"] = "Семья %s осталась без дома — история подождёт, пока они заселятся." % StoryDefs.fam_gen(String(a.get("fam", "")))
		return info
	if a.get("ready", false):
		info["text"] = "Готово! Посмотрите, чем всё кончилось."
		info["buttons"] = [["Посмотреть", play_ready]]
		return info
	var st := _step(a)
	var text := StoryDefs.fill(String(st.get("text", "")), a)
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
		"", "flag", "around", "built_after", "wait", "p":
			if kind != "":
				var pr := progress(a, g)
				if String(pr["txt"]) != "":
					text += " %s." % pr["txt"]
	info["text"] = text
	return info


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
		"wait": false, "choice": "", "opts": [], "end": false, "tcat": null}
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
				cine["choice"] = String(((b[3] as Array)[0] as Array)[1])
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
	return {"kind": "citizen", "seed": int(b.get("seed", 1)), "female": bool(b.get("female", false)), "child": bool(b.get("child", true)),
		"cls": String(b.get("cls", "plebs")), "name": StoryDefs.fill(String(sd.get("who", "")), b), "role": StoryDefs.fill(String(sd.get("role", "")), b),
		"pic": "class_%s.png" % String(b.get("cls", "plebs"))}


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
			var w := _who_at(String(b[1]))
			var shot := _talk_shot(w[0], w[1], String(b[1]) == "cat")
			cine["focus"] = Vector2((w[0] as Vector3).x, (w[0] as Vector3).z)
			var cd: Vector2 = Vector2((shot[0] as Vector3).x, (shot[0] as Vector3).z) - (cine["focus"] as Vector2)
			cine["cam_dir"] = cd.normalized() if cd.length() > 0.01 else Vector2(0, 1)
			if bool(cine.get("snap", false)):
				cine["snap"] = false
				kit.cam_set(shot[0], shot[1])
			else:
				kit.cam_to(shot[0], shot[1], 1.7)
		"anim":
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
			cine["opts"] = b[3]
			ui.choices(b[3], _picked)
		"cat":
			_cat_state(String(b[1]))
		"fx":
			var w := _who_at(String(b[2]))
			if String(b[1]) == "hearts":
				ui.hearts((w[0] as Vector3) + Vector3(0, 0.25, 0))
			else:
				game._puff(w[0], Color("fff3c8"))
		"reward":
			kit.say_caption(_reward_caption())
			if game.sound:
				game.sound.ui("coins")       # из звуков интерфейса владелец оставил только монетки
		"cut":
			cine["cut"] = 0.0
		"wait":
			pass


## Ролик идёт: камера долетела, человек дошёл, пауза кончилась — следующий такт
func _beat_tick(dt: float) -> void:
	if cine.is_empty() or bool(cine["end"]):
		return
	ui.track()
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
		"anim", "actor", "cat":
			if bt >= 0.35:
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
	var c: Citizen = game.people.actor(int(b.get("seed", 1)), bool(b.get("female", false)), bool(b.get("child", true)), String(b.get("cls", "plebs")))
	var h: Dictionary = city.buildings.get(int(b.get("home", -1)), {})
	var p := Vector2.ZERO
	var yaw := 0.0
	if where == "near_cat":
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
	for k: float in [1.0, 0.8, 0.62]:
		for turn: float in turns:
			var dir := f.rotated(-turn)
			var cam := p + Vector3(dir.x, 0, dir.y) * d0 * k + Vector3.UP * h0 * k
			if _clear_view(Vector2(cam.x, cam.z), Vector2(p.x, p.z)):
				return [cam, p + Vector3.UP * (0.1 if is_cat else 0.3) - Vector3(dir.x, 0, dir.y) * 0.6]
	return [p + Vector3(f.x, 0, f.y) * 2.2 + Vector3.UP * 5.0, p + Vector3.UP * 0.3]


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
