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
const KID_CALL_H := 2                  # хозяйка (Мария) зовёт кошку раз в 2 игровых часа
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
var _hid_parts: Array = []             # деревья, кусты и высокие украшения, спрятанные на время ролика (Parts.hide_handles)
var _hid_lights: Array = []            # и свет спрятанных фонарей (иначе пятно света висит без фонаря)
var _hid_keys := {}                    # что уже спрятано (не прятать дважды)
var _tree_t := 0.0
var _tried := ""                       # с чем последний раз искали, кому предложить историю
var orders: StoryOrders                # «Заказы старосты» (этап 7.4) — строка между историями
var beast := {}                        # кого ищут, если не кошку (ослик): {n: Beast, p, kind}
var _clicks: Array = []                # места «щёлкнуть» в мире (лужи, труба): узлы
var _clicks_key := ""
const CLICK_HINT := "story_click"      # значки над лужами (через hint_h часов)
const WALK_MAX := 16.0                 # в ролике идут не дальше стольких метров пути (остальное — за кадром)
const DONKEY_LEN := 1.55               # ослик от морды до хвоста, м
var works_room := 40                   # «лавка у дома» (ослик): столько м² свободной земли рядом нужно под новую лавку


func setup(g) -> void:
	game = g
	hud = g.hud
	city = g.city
	ui = StoryUi.new(self)
	orders = StoryOrders.new(self)
	life = StoryLife.new()
	add_child(life)
	life.setup(self)
	city.building_removed.connect(_on_removed)
	city.family_left.connect(_on_family_left)
	city.festival_changed.connect(_on_fest)
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
			var pc: Dictionary = game.people.pet_cat(h, int(p.get("fur", 0)), String(p.get("name", "")), int(p.get("seed", 1)))
			pc["pet_rec"] = p                # дом снесли — кошка перейдёт к соседям, и запись с ней (этап 6.4)
	# кошка живёт, пока её не забрали домой (_after_final): и пока ищут, и когда нашли, а ролик встречи ещё ждёт щелчка;
	# ослик — пока ищут и пока не досмотрели встречу (дальше он у хозяина)
	var a: Dictionary = s["active"]
	if not a.is_empty():
		var st0 := _step(a)
		if st0.has("cine") and not st0.has("goal") and not bool(a.get("ready", false)):
			a["ready"] = true                # сохранились посреди ролика-шага (труба, встреча с осликом): снова ждём щелчка
			for b: Array in st0["cine"]:
				if String(b[0]) == "fix":
					a.erase("fixed")         # ролик с мастером покажут заново — течь пока не заделана
	if not a.is_empty() and a.has("spot") and _find_live(a):
		if _find_what(a) == "cat":
			_spawn_cat(a)
		else:
			_spawn_beast(a)


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


## Кошка мяукает (тихо, в мире — слышно, только если камера рядом) и над ней «мяу!»; ослик кричит «И-а!»
func _live(sdt: float) -> void:
	if (cat.is_empty() and beast.is_empty()) or sdt <= 0.0 or not allowed():
		return
	if _sit_t > 0.0:
		_sit_t -= sdt
		if _sit_t <= 0.0 and cat.has("story"):
			cat["state"] = "sleep"
		if _sit_t <= 0.0 and not beast.is_empty():
			_beast_play("Eating")
	_meow_t -= sdt
	if _meow_t <= 0.0:
		meow()


func meow() -> void:
	_meow_t = randf_range(MEOW[0], MEOW[1])
	if not beast.is_empty():
		var o := StoryDefs.find_opts(_story(S()["active"]))
		_beast_play("Idle_2")
		_sit_t = 2.5
		ui.bubble3d(_pet_pos() + Vector3(0, 1.3, 0), String(o.get("call", "И-а!")), 2.6, 28)
		return
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
	orders.tick()
	_sync_beast()
	_sync_clicks()
	_marks(true)
	_advise_once()
	_advise_square()
	_advise_step()


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
	return int(s["h"]) - int(s["last_h"]) >= gap_now()


## Пауза до следующей истории: обычно GAP_H; у истории-продолжения (gap_h — «Разбойники у арки» после «Маси», Д9) —
## своя, если её очередь: та, что в after, пройдена, ранг и жители позволяют, и её не пропускают (skip_if)
func gap_now() -> int:
	var s := S()
	var done: Dictionary = s["done"]
	for sd: Dictionary in StoryDefs.all():
		if not sd.has("gap_h") or done.has(String(sd["id"])) or not done.has(String(sd.get("after", ""))):
			continue
		if city.level < int(sd.get("lvl", 0)) or int(city.stats.get("pop", 0)) < int(sd.get("pop", 0)):
			continue
		var sk := String(sd.get("skip_if", ""))
		if sk != "" and city.research.has(sk) and String((s.get("granted", {}) as Dictionary).get(sk, "")) != String(sd["id"]):
			continue
		return mini(StoryDefs.GAP_H, int(sd["gap_h"]))
	return StoryDefs.GAP_H


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
	# Легион уже открыт (старый город изучил его за очки) — «Разбойники у арки» не нужны. Открыла его сама эта история,
	# а потом она прервалась (семья уехала, дом снесли) — предлагаем снова, как любую прерванную: награда не пропадёт
	var sk := String(sd.get("skip_if", ""))
	if sk != "" and city.research.has(sk) and String((S().get("granted", {}) as Dictionary).get(sk, "")) != String(sd["id"]):
		return {}
	# сначала та история (на «Хуторе» первой остаётся «Где Мася?»); с «Деревни» не держим, если ту сейчас не предложить
	var af := String(sd.get("after", ""))
	if af != "" and not (S()["done"] as Dictionary).has(af) and not StoryDefs.story(af).is_empty():
		if city.level < 2 or not can_offer(StoryDefs.story(af)).is_empty():
			return {}
	for r in sd.get("needs", []):
		if not city.research.has(r):
			return {}
	for np: Array in sd.get("need_p", []):
		if city.progress_of(np[0]) < int(np[1]):
			return {}
	var fo := StoryDefs.find_opts(sd)
	var cg := StoryDefs.click_goal(sd)
	var wg := StoryDefs.works_goal(sd)
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
		if not cg.is_empty() and click_spots(bind, int(cg[2]), cg[3] if cg.size() > 3 else {}).size() < int(cg[2]):
			continue                         # у дома нет улицы, по которой бежит вода: лужи класть некуда
		if not wg.is_empty() and not _works_room(bind, wg):
			continue                         # у дома возчика ни лавки, ни места под неё: историю не пройти без сноса
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


## Цель «лавка у дома торгует» можно выполнить: такая лавка уже стоит рядом или есть где её поставить
func _works_room(bind: Dictionary, wg: Array) -> bool:
	var hp := _home_pos(bind)
	for id in city.buildings:
		var b: Dictionary = city.buildings[id]
		if _is(b, String(wg[1])) and (b["pos"] as Vector2).distance_to(hp) <= float(wg[2]):
			return true
	return free_near(hp, float(wg[2])) >= works_room


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
			"child": bool(ex[k].get("child", false)), "cls": String(bind.get("cls", "plebs")), "old": bool(ex[k].get("old", false))}
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


## Кого просить: дома нужного класса, где живёт семья с ребёнком (child) или со взрослой жительницей (young — Мария
## из «Где Мася?»), — ближние к станции первыми; [{home, fam, kid, seed…}] (kid — имя героя: мальчик семьи или cast.name)
func _cast(sd: Dictionary) -> Array:
	var cast: Dictionary = sd.get("cast", {})
	var ctr := city.center()
	if cast.is_empty():
		return [] if ctr.is_empty() else [{"home": int(ctr["id"]), "fam": "", "kid": ""}]
	var role: Dictionary = cast.values()[0]
	var clss := String(role.get("cls", "plebs")).split("|")
	var child := bool(role.get("child", false))
	var floors := int(role.get("floors", 0))     # дом ровно в столько этажей («Тесно у …» — в два, чтобы надстроить третий)
	var c0: Vector2 = ctr["pos"] if not ctr.is_empty() else Land.CENTER
	var young := bool(role.get("young", false))
	var kids := {}                       # «семья|дом» — у кого есть ребёнок / взрослая женщина (один проход по жителям)
	if child or young:
		for r in game.people.residents:
			if (child and bool(r["child"])) or (young and not child and bool(r["female"]) and not bool(r["child"])):
				kids["%s|%d" % [r["fam"], int(r["home"])]] = true
	var out := []
	for id in city.buildings:
		var b: Dictionary = city.buildings[id]
		if not city.is_house(b) or not (String(city.def(b)["cls"]) in clss) or int(b["pop"]) <= 0:
			continue
		if floors > 0 and (int(b.get("tier", 1)) != floors or Defs.floors_max(String(city.def(b)["cls"])) <= floors):
			continue
		for f: Dictionary in b["families"]:
			var fam := String(f["name"])
			if (child or young) and not kids.has("%s|%d" % [fam, int(id)]):
				continue
			var e := {"home": int(id), "fam": fam, "kid": String(role.get("name", StoryDefs.boy(fam))), "cls": String(city.def(b)["cls"]), "female": bool(role.get("female", false)),
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
				city._quiet("Открыто украшение «%s» (Украшения) — для истории «%s»." % [Defs.B[t]["name"], StoryDefs.title_of(_story(a), a)], "decor")
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
	# ролик прошлого шага заделал течь (даже если его пропустили Esc): лужи и труба больше не появятся
	if i > 0:
		for b: Array in (steps[i - 1] as Dictionary).get("cine", []):
			if String(b[0]) == "fix":
				a["fixed"] = true
				break
	var st: Dictionary = steps[i]
	for r in st.get("grant", []):
		# шаг открывает исследование (Легион из истории): без очков, событие — в колокольчик
		if not city.research.has(String(r)):
			city.research[String(r)] = true
			# кто открыл: прервётся история — её предложат снова, skip_if её не остановит (can_offer)
			(S().get_or_add("granted", {}) as Dictionary)[String(r)] = String(a.get("id", ""))
			var rd := Defs.research(String(r))
			city._quiet("Открыто: «%s» — для истории «%s»." % [rd.get("name", r), StoryDefs.title_of(_story(a), a)], "research")
		if String(r) == "legion":
			city.legion.flags["advised"] = true   # что такое Легион и как его строить, скажет совет шага (с военным кварталом), не окно Легиона
	if bool(st.get("quarter", false)):
		quarter()                        # военный квартал у арки — один раз на город (Legion.flags.quarter)
	if not (st.get("grant", []) as Array).is_empty():
		city.changed.emit()              # медальон «Легион» и карточки стройки — сразу, не через игровой час
	if st.has("goal"):
		var g: Array = st["goal"]
		if String(g[0]) == "find":
			_start_find(a, g[2], String(g[1]))
		elif String(g[0]) == "click":
			_start_click(a, g)
	elif st.has("cine"):
		a["ready"] = true                # ролик-шаг ждёт щелчка игрока (свиток над домом, «Посмотреть»)
	_sync_beast()
	_sync_clicks()


## Найти: где кошка (ослик) прячется, место поисков (пятно света вокруг, не по центру), сама кошка (ослик)
func _start_find(a: Dictionary, o: Dictionary, what := "cat") -> void:
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
		_cancel("Кошка нашлась сама — спряталась прямо у порога." if what == "cat" else "%s нашёлся сам — стоял прямо у порога." % String(o.get("name", "")))
		return
	a["spot"] = [spot.x, spot.y]
	for k in 2:
		var r := float(o["ring"] if k == 0 else o["ring2"])
		var ang := rg.randf() * TAU
		var c := spot + Vector2(cos(ang), sin(ang)) * r * rg.randf_range(0.25, 0.5)
		a["area%d" % k] = [c.x, c.y, r]
	a["cat_name"] = String(o.get("name", "Мася"))
	a["fur"] = int(o.get("fur", 0))
	if what == "cat":
		_spawn_cat(a)
	else:
		_spawn_beast(a)
	_meow_t = 6.0
	_call_kid(a)


func _spawn_cat(a: Dictionary) -> void:
	if not cat.is_empty():
		game.people.drop_cat(cat)
	var home: Dictionary = city.buildings.get(int(a.get("home", -1)), city.center())
	var sp: Array = a["spot"]
	cat = game.people.story_cat(home, Vector2(float(sp[0]), float(sp[1])), int(a.get("fur", 0)), hash(a.get("fam", "")) & 0xffff)
	cat["yaw"] = _rng(a, 2).randf() * TAU


## Хозяйка у дома зовёт кошку (маленькая подпись над ней; без всплывашек)
func _call_kid(a: Dictionary) -> void:
	var home: Dictionary = city.buildings.get(int(a.get("home", -1)), {})
	if home.is_empty():
		return
	var dp: Vector2 = city.door_point(home)
	var name := String(a.get("cat_name", "Мася"))
	var call := String(StoryDefs.find_opts(_story(a)).get("kid", "%s! Кис-кис-кис!" % name))
	ui.bubble3d(Vector3(dp.x, game.land.height_at(dp.x, dp.y) + 1.6, dp.y), call, 4.0, 28)


## Часы историй: подсказки, след лапки, хозяйка сама нашла (find), ожидание (wait), семья без дома
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
	elif _goal_kind(a) in ["click", "wait", "fest"]:
		hud.refresh()                        # «ищем N ч», значки над лужами, часы ожидания


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
				% [StoryDefs.title_of(_story(a), a), StoryDefs.fam_gen(String(a.get("fam", "")))], "scroll")
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
	# молодые — те самые жених и невеста из роликов: имена и облик — в записи членов семьи (сохраняются, этап 6.1)
	var ms := couple_members(nm, 2, String(city.def(h)["cls"]), hid, a.get("roles", {}))
	city.pending[nm] = {"name": nm, "n": 2, "cls": String(city.def(h)["cls"]), "home": hid, "back": true, "m": ms}
	if city.settled(hid, 2, nm) <= 0:
		city.pending.erase(nm)
		return
	a["couple"] = nm
	game.people._make_family(nm, 2, hid, city.door_point(h))
	city._quiet("Юлия и Марк поселились в новом доме — теперь это семья %s. Свадьбу сыграют вечером: посмотрите шествие!" \
		% StoryDefs.fam_gen(nm), "ring")


## Записи молодых (Residents): Марк и Юлия, облик — как у жениха и невесты в роликах (зерно роли); n > 2 — дальше по правилам.
## Та же — для старых сохранений, где свадьбу сыграли до записей (People._old_couples)
static func couple_members(nm: String, n: int, cls: String, key: int, roles: Dictionary) -> Array:
	var ms := Residents.gen(nm, 2, cls, key)
	for i in 2:
		var ro: Dictionary = roles.get("groom" if i == 0 else "bride", {})
		ms[i]["pn"] = "Марк" if i == 0 else "Юлия"
		if not ro.is_empty():
			ms[i]["sd"] = int(ro.get("seed", 1))
			var rr := RandomNumberGenerator.new()
			rr.seed = int(ro.get("seed", 1))
			var rc := String(ro.get("cls", cls))
			ms[i]["look"] = Citizen.roll_look(rr, i == 1, false, rc == "patricians", "", rc)   # одежда — как в ролике
	if n > 2:
		ms = Residents.gen(nm, n, cls, key, ms)
	return ms


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
	if a.has("spot") and _find_live(a):
		if _find_what(a) == "cat" and cat.is_empty():
			_spawn_cat(a)                # кошка — в кадре встречи (и потом — домой, к семье)
		elif _find_what(a) != "cat" and beast.is_empty():
			_spawn_beast(a)              # ослик — в кадре встречи с хозяином
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
	_drop_beast()


## Щелчок по миру без инструмента: кошка или ослик (в CLICK_PX точек) — нашли; лужа — отмечена. true — щелчок забран
func try_click(mp: Vector2) -> bool:
	if kit != null or not allowed() or game.rig == null:
		return false
	var a: Dictionary = S()["active"]
	if a.is_empty():
		return false
	if _goal_kind(a) == "click":
		var i := _click_at(mp)
		if i < 0:
			return false
		click_target(i)
		return true
	if _goal_kind(a) != "find" or (cat.is_empty() and beast.is_empty()):
		return false
	if not near_cat(mp):
		return false
	found()
	return true


## Мышь над кошкой, осликом или лужей, по которой надо щёлкнуть (курсор-«рука»)
func near_cat(mp: Vector2) -> bool:
	if game.rig == null:
		return false
	if not beast.is_empty() or not cat.is_empty():
		var cam: Camera3D = game.rig.cam
		var w := (_cat_pos() + Vector3(0, 0.18, 0)) if not cat.is_empty() else (_pet_pos() + Vector3(0, 0.55, 0))
		if not cam.is_position_behind(w) and cam.unproject_position(w).distance_to(mp) <= CLICK_PX * (1.0 if not cat.is_empty() else 1.4):
			return true
	var a: Dictionary = S()["active"] if city != null else {}
	return not a.is_empty() and _goal_kind(a) == "click" and _click_at(mp) >= 0


## Кошку (ослика) нашли: ролик встречи (награда — сразу, если это конец истории)
func found() -> void:
	var a: Dictionary = S()["active"]
	if a.is_empty() or _goal_kind(a) != "find":
		return
	(a["flags"] as Dictionary)["found"] = true
	_advance(true)


## Долго искали — нашёлся сам. Кошка: Мария нашла её сама — без очков и ролика, только колокольчик (история кончилась).
## Ослик: хозяин нашёл его сам, но история идёт дальше — ролик встречи ждёт щелчка, лавка ещё впереди
func _give_up() -> void:
	var a: Dictionary = S()["active"]
	var st := _step(a)
	var steps: Array = _story(a)["steps"]
	var more := false
	for k in range(int(a["step"]) + 1, steps.size()):
		more = more or (steps[k] as Dictionary).has("goal")
	if more:
		(a["flags"] as Dictionary)["found"] = true
		city._quiet(StoryDefs.fill(String(st.get("giveup", "")), a), String(_story(a).get("icon", "scroll")))
		_advance(false)
		return
	a["step"] = steps.size() - 1
	var text := StoryDefs.fill(String(st.get("giveup", "")), a)
	_finish("self", text)
	if not cat.is_empty():
		game.people.free_cat(cat, int(a.get("home", -1)), String(a.get("cat_name", "")))
		cat = {}
	_drop_beast()


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
	for k in ["roles", "flags", "fam2", "home2", "couple", "old", "child", "female", "at"]:
		if a.has(k):
			e[k] = a[k]                      # для «Пересмотреть»: кто был в роликах (и каков облик), что выбрали, где новый дом
	e["text"] = (text + " " if text != "" else "") + "Награда: " + rw + "."
	s["done"][String(sd["id"])] = e
	s["active"] = {}
	s["last_h"] = int(s["h"])
	city._quiet("История «%s» завершена. %s" % [StoryDefs.title_of(sd, a), e["text"]], String(sd.get("icon", "scroll")))
	city.compute()
	_marks(true)
	hud.refresh()


## Награда истории (без денег): украшение, счастье, очки исследований, Слава, кошка (и добавка по выбору, если он уже
## сделан). Возвращает её описание
func _reward(sd: Dictionary, a: Dictionary, full: bool) -> String:
	var r: Dictionary = (sd.get("reward", {}) as Dictionary).duplicate()
	var ch := String((a.get("flags", {}) as Dictionary).get("choice", ""))
	var bc: Dictionary = r.get("by_choice", {})
	if bc.has(ch):
		r.merge(bc[ch], true)
	return _give(r, sd, a, full)


## Выбор в последнем ролике (награда уже выдана, пока ролик шёл): добавка по выбору — сейчас, строка журнала — дописать
func _reward_choice(sd: Dictionary, val: String) -> void:
	var id := String(sd["id"])
	var e: Dictionary = (S()["done"] as Dictionary).get(id, {})
	var bc: Dictionary = (sd.get("reward", {}) as Dictionary).get("by_choice", {})
	if e.is_empty() or not bc.has(val) or String((e.get("flags", {}) as Dictionary).get("choice", "")) == val:
		return
	var fl: Dictionary = e.get("flags", {})
	fl["choice"] = val
	e["flags"] = fl
	var add := _give(bc[val], sd, e, true)
	var t := String(e.get("text", ""))
	e["text"] = (t.trim_suffix(".") + ", " + add + ".") if t != "" else "Награда: " + add + "."
	city.compute()


## Выдать награду r (без денег): украшение, счастье, очки исследований, Слава, кошка. Возвращает её описание
func _give(r: Dictionary, sd: Dictionary, a: Dictionary, full: bool) -> String:
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
	city._quiet("История «%s» прервалась. %s" % [StoryDefs.title_of(_story(a), a), why], "scroll")
	if not cat.is_empty():
		game.people.drop_cat(cat)
		cat = {}
	_drop_beast()
	s["active"] = {}
	_sync_clicks()
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
		"click":
			var n := 0
			for c: Array in a.get("clicks", []):
				n += int(int(c[2]) > 0)
			var need := int(g[2])
			return {"have": n, "need": need, "ok": n >= need and not (a.get("clicks", []) as Array).is_empty(), "txt": "%d/%d" % [mini(n, need), need]}
		"works":
			var w := works_eval(a, g)
			if int(w["ok_id"]) >= 0:
				flags["shop"] = int(w["ok_id"])  # лавка, что заработала (ослик повезёт товар к ней)
			return {"have": int(int(w["ok_id"]) >= 0), "need": 1, "ok": int(w["ok_id"]) >= 0, "txt": ""}
		"floor":
			var h: Dictionary = city.buildings.get(int(a.get("home", -1)), {})
			var t := int(h.get("tier", 0)) if not h.is_empty() else 0
			return {"have": mini(t, int(g[2])), "need": int(g[2]), "ok": t >= int(g[2]), "txt": "%d/%d" % [mini(t, int(g[2])), int(g[2])]}
		"happy_home":
			var h: Dictionary = city.buildings.get(int(a.get("home", -1)), {})
			var hv := clampi(int(h.get("happy", 0)), 0, 100) if not h.is_empty() else 0
			# ["happy_home", 75, 3]: этаж уже надстроили (счастье могло потом просесть) — счастье своё дело сделало
			var fl_done := g.size() > 2 and not h.is_empty() and int(h.get("tier", 0)) >= int(g[2])
			return {"have": hv, "need": int(g[1]), "ok": hv >= int(g[1]) or fl_done, "txt": "%d%%/%d%%" % [hv, int(g[1])]}
		"beauty":
			var n := beauty_near(hp, float(g[1]))
			var tiers: Array = g[2]
			var tier := 0
			for k in tiers.size():
				if n >= int(tiers[k]):
					tier = k + 1
			flags["tier"] = tier
			return {"have": n, "need": int(tiers[0]), "ok": tier >= 1 and bool(flags.get("ready", false)), "tier": tier,
				"txt": "%d (%s)" % [n, TIER[mini(tier, 3)]]}
		"fest":
			var n := int(flags.get("fest", 0))
			return {"have": mini(n, int(g[1])), "need": int(g[1]), "ok": n >= int(g[1]), "txt": "%d/%d" % [mini(n, int(g[1])), int(g[1])]}
		"legion_win":
			var n := legion_wins(int(g[1]))
			return {"have": mini(n, int(g[2])), "need": int(g[2]), "ok": n >= int(g[2]), "txt": "%d/%d" % [mini(n, int(g[2])), int(g[2])]}
		"all":
			var have := 0
			var subs: Array = g[1]
			for sg: Array in subs:
				have += int(bool(progress(a, sg)["ok"]))
			return {"have": have, "need": subs.size(), "ok": have >= subs.size(), "txt": "%d/%d" % [have, subs.size()]}
	return {"have": 0, "need": 1, "ok": false, "txt": ""}


## Цель «лавка у дома торгует»: {shops: [[id, почему не торгует ("" — торгует)]], ok_id — первая торгующая или -1}
func works_eval(a: Dictionary, g: Array) -> Dictionary:
	var hp := _home_pos(a)
	var out := []
	var ok_id := -1
	if g.size() < 3:
		return {"shops": out, "ok_id": ok_id}
	for id in city.buildings:
		var b: Dictionary = city.buildings[id]
		if not _is(b, String(g[1])) or (b["pos"] as Vector2).distance_to(hp) > float(g[2]):
			continue
		var why := String(b.get("why", "road"))
		out.append([int(id), why])
		if why == "" and ok_id < 0:
			ok_id = int(id)
	return {"shops": out, "ok_id": ok_id}


## Очков украшений в r м от точки (как их считает счастье дома)
func beauty_near(p: Vector2, r: float) -> int:
	var n := 0.0
	for id in city.buildings:
		var b: Dictionary = city.buildings[id]
		if city.def(b)["kind"] == "decor" and (b["pos"] as Vector2).distance_to(p) <= r:
			n += float(city.def(b).get("deco", 1))
	return int(n)


## Побед Легиона в провинции r (звёзды первого круга походов)
func legion_wins(r: int) -> int:
	var lg = city.legion
	var n := 0
	for s in Legion.STAGES:
		if lg.stage_done(0, r, s):
			n += 1
	return n


## Игры в честь богов начались: цель «столько игр» идущей истории
func _on_fest(on: bool) -> void:
	if not on or city == null:
		return
	var a: Dictionary = S()["active"]
	if not a.is_empty() and _goal_kind(a) == "fest":
		var fl: Dictionary = a["flags"]
		fl["fest"] = int(fl.get("fest", 0)) + 1


## Строки цели с ✓ (золотая строка «Просьб горожан»): [{text, ok, do}] — do: что сделать (Hud.need_do-вид: взять
## постройку, исследование, «Этаж», «Обзор» со слоем); щелчок по невыполненной строке — сразу к делу
func goal_parts(a: Dictionary, g: Array, st: Dictionary = {}) -> Array:
	if g.is_empty():
		return []
	var out := []
	var hp := _home_pos(a)
	match String(g[0]):
		"p":
			var n := city.progress_of(g[1])
			var need := int(g[2])
			out.append({"text": "%s %d/%d" % [String(st.get("label", "Сделано")), mini(n, need), need], "ok": n >= need,
				"do": {} if n >= need else hud.need_do(g[1], String(st.get("tool", "")))})
		"around":
			for base in (g[2] as Dictionary):
				var n := _count_near(String(base), hp, float(g[1]), -1)
				var need := int(g[2][base])
				var t := _first_open(String(base))
				var nm := String(PART_WORDS.get(String(base), Defs.B.get(String(base).split("|")[0], {}).get("name", base)))
				out.append({"text": "%s %d/%d" % [nm, mini(n, need), need], "ok": n >= need,
					"do": {} if n >= need or t == "" else hud._do_type(t)})
		"works":
			var w := works_eval(a, g)
			var names := []
			for k in String(g[1]).split("|"):
				names.append(String(Defs.B.get(k, {}).get("name", k)).to_lower())
			if (w["shops"] as Array).is_empty():
				var sn := " или ".join(names)
				sn = sn.left(1).to_upper() + sn.substr(1)     # «Мясная лавка или пекарня» (capitalize() — каждое слово с большой)
				out.append({"text": "%s у дома (в %d м): нет" % [sn, int(g[2])], "ok": false,
					"do": hud.need_do(["count", String(g[1]).split("|")[0]])})
			for e: Array in w["shops"]:
				var b: Dictionary = city.buildings[int(e[0])]
				var nm := String(city.def(b)["name"])
				var why := String(e[1])
				var line: String = {"": "товар есть ✓", "store": "нет склада рядом", "staff": "нет работников", "road": "нет дороги",
					"good": "нет сырья с полей"}.get(why, "не торгует")
				var dw := {}
				match why:
					"store": dw = hud._do_type("warehouse")
					"good": dw = hud._do_type(String({"wheat": "farm", "olives": "grove", "grapes": "vineyard"}.get(String(city.def(b).get("needs_good", "")), "farm")))
					"road": dw = {"kind": "road", "tip": "Мостовая", "say": "Лавке нужна дорога к двери"}
					"staff": dw = hud.need_do(["pop"])
				out.append({"text": "%s: %s" % [nm, line], "ok": why == "", "do": dw})
		"floor":
			var h: Dictionary = city.buildings.get(int(a.get("home", -1)), {})
			var t := int(h.get("tier", 0)) if not h.is_empty() else 0
			var why := "" if h.is_empty() or t >= int(g[2]) else city.can_buy_floor(h, false)
			out.append({"text": "Этажей %d/%d%s" % [mini(t, int(g[2])), int(g[2]), (" — " + why.left(1).to_lower() + why.substr(1)) if why != "" else ""],
				"ok": t >= int(g[2]), "do": {} if t >= int(g[2]) else hud.need_do(["floors", int(g[2])])})
		"happy_home":
			var pr := progress(a, g)
			var h: Dictionary = city.buildings.get(int(a.get("home", -1)), {})
			var gap := [] if bool(pr["ok"]) or h.is_empty() else happy_gaps(h)
			var tail := (" — не хватает: " + String(gap[0]["text"])) if not gap.is_empty() else ""
			out.append({"text": "Счастье дома %s%s" % [pr["txt"], tail], "ok": bool(pr["ok"]), "do": {} if gap.is_empty() else gap[0]["do"]})
		"beauty":
			var pr := progress(a, g)
			out.append({"text": "Очков красоты рядом с домом: %s" % pr["txt"], "ok": int(pr.get("tier", 0)) >= 1, "do": {} if int(pr.get("tier", 0)) >= 1 else hud._do_type(_first_open("flowers|planter|tree"))})
		"fest":
			var pr := progress(a, g)
			out.append({"text": "Игры в честь богов %s" % pr["txt"], "ok": bool(pr["ok"]), "do": {}})
		"legion_win":
			var pr := progress(a, g)
			var rn := String((Legion.REGIONS[int(g[1])] as Dictionary).get("name", "")) if int(g[1]) < Legion.REGIONS.size() else ""
			out.append({"text": "Победы в «%s» %s" % [rn, pr["txt"]], "ok": bool(pr["ok"]), "do": {}})
		"built_after":
			var pr := progress(a, g)
			out.append({"text": "Новый %s в %d м" % [String(Defs.B.get(String(g[1]), {}).get("name", "дом")).to_lower(), int(g[2])], "ok": bool(pr["ok"]),
				"do": {} if bool(pr["ok"]) else hud._do_type(String(g[1]))})
		"all":
			for sg: Array in g[1]:
				out.append_array(goal_parts(a, sg, st))
	return out


## Первый открытый облик вида («flowers|planter» → клумба) или ""
func _first_open(key: String) -> String:
	for k in key.split("|"):
		for t in Defs.looks_of(k):
			if city.unlocked(t):
				return t
	return ""


## Чего дому не хватает до счастья — самое выгодное первым: [{text, gain, do}] (нет лавки нужного вида, мало красоты рядом,
## нет фонтана, мало разных лавок). «Красоты» — клумба или дерево рядом, «фонтана» — фонтан в охвате
func happy_gaps(h: Dictionary) -> Array:
	var out := []
	var cl := String(city.def(h)["cls"])
	var cd: Dictionary = Defs.CLASSES[cl]
	for n in h.get("missing", []):
		out.append({"text": "лавки «%s» рядом" % String(Defs.NEEDS[n]["name"]).to_lower(), "gain": Defs.MISSING_PENALTY + 5, "do": hud._do_shop(String(n))})
	var deco_room := int(cd.get("deco_max", 12)) - int(h.get("deco_bonus", 0))
	if deco_room > 0:
		var t := _first_open("flowers|planter|bush|tree")
		if t == "":
			t = "bench"
		out.append({"text": "красоты (клумба или дерево рядом)", "gain": mini(deco_room, 6), "do": hud._do_type(t)})
	if not (h.get("mon_types", {}) as Dictionary).has("fountain"):
		out.append({"text": "фонтана рядом", "gain": int(Defs.B["fountain"]["bonus"]), "do": hud._do_type("fountain")})
	var shops := (h.get("score", {}) as Dictionary).size()
	if shops < 6:
		out.append({"text": "ещё одной разной лавки рядом", "gain": 4, "do": hud._do_shop(null)})
	out.sort_custom(func(x, y): return int(x["gain"]) > int(y["gain"]))
	return out


## Куда показать золотой стрелкой по идущей истории (Hud._update_pointer — после обучения, до просьб): Hud.need_do-вид
## (+ tip) или {} — истории стрелка не нужна (ищут в мире, ждут ролика, выбирают)
func pointer_do() -> Dictionary:
	if city == null or not allowed():
		return {}
	var a: Dictionary = S()["active"]
	if a.is_empty() or a.get("ready", false) or a.has("homeless"):
		return {}
	var st := _step(a)
	if st.has("point"):
		var pt: Array = st["point"]
		match String(pt[0]):
			"card":
				return hud._do_type(String(pt[1]))
			"tool":
				return {"kind": String(pt[1]), "tip": {"floor": "Этаж", "road": "Мостовая"}.get(String(pt[1]), "")}
			"overview":
				return {"kind": "view", "layer": String(pt[1]), "tip": "Обзор"}
			"research":
				return hud._do_research(String(pt[1]), "")
			"legion":
				return {"kind": "legion", "tip": "Легион"}
	var g: Array = st.get("goal", [])
	if g.is_empty() or not (String(g[0]) in PART_KINDS or String(g[0]) == "built_after"):
		return {}
	for p: Dictionary in goal_parts(a, g, st):
		if not bool(p["ok"]) and not (p["do"] as Dictionary).is_empty():
			return p["do"]
	return {}


## Постройка вида base (тип, облик украшения или «a|b» — любой из них)
static func _is(b: Dictionary, base: String) -> bool:
	var bt := Defs.base_of(b["type"])
	for k in base.split("|"):
		if b["type"] == k or bt == k or bt in (KIND_ALSO.get(k, []) as Array):
			return true
	return false


## Новые виды этапа 5 в счёт прежних: «дерево» — и большие деревья (дуб, олива, пальма), «куст» — и самшит
const KIND_ALSO := {"tree": ["bigtree"], "bush": ["topiary"]}


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
		"battle":
			# бой Легиона прямо из истории (учебный бой леса с маслом): 3D-бой откроется по сигналу legion.battle_requested
			var lg = city.legion
			var bt: Array = _step(a).get("battle", [0, 0, 0])
			var st: Dictionary = lg.stage_info(int(bt[0]), int(bt[1]), int(bt[2]))
			var why: String = lg.can_fight(st)
			if why != "":
				hud.notify(why, "lock")
				return
			lg.flags["tut_fought"] = true            # обучение Легиону: шаг «первый бой» позади
			lg.start_battle(st)
			return
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
	# след лапки над кошкой (значок над осликом) — через paw_h часов поисков
	var paw := false
	var area := []
	var trail := {}                          # след лапок от двери — только к месту, где ищут кошку (не к заказу, не к ослику)
	if on and not cine_on and not a.is_empty() and _goal_kind(a) == "find" and (not cat.is_empty() or not beast.is_empty()):
		var g: Dictionary = _step(a)["goal"][2]
		var hours := int(s["h"]) - int(a.get("t0", s["h"]))
		paw = hours >= int(g.get("paw_h", 6))
		area = a.get("area1" if hours >= int(g.get("shrink_h", 3)) else "area0", [])
		if not cat.is_empty():
			trail = a
	if paw and not cat.is_empty():
		# значок над кошкой — как у истории (чёрная Мася — чёрная кошка на значке)
		hud.set_badge("story_paw", _cat_pos() + Vector3(0, 0.75, 0), String(_story(a).get("icon", "cat")), false, "", found)
	elif paw:
		hud.set_badge("story_paw", _pet_pos() + Vector3(0, 1.6, 0), "horse", false, "", found)
	else:
		hud.clear_badge("story_paw")
	# лужи: через hint_h часов над каждой ещё не найденной — значок с каплей (щёлкнуть можно и по нему)
	var hints := {}
	if on and not cine_on and not a.is_empty() and _goal_kind(a) == "click":
		var go: Dictionary = (_step(a)["goal"] as Array)[3] if (_step(a)["goal"] as Array).size() > 3 else {}
		if int(s["h"]) - int(a.get("t0", s["h"])) >= int(go.get("hint_h", 4)):
			var cl: Array = a.get("clicks", [])
			for i in cl.size():
				if int(cl[i][2]) == 0:
					var q := Vector2(float(cl[i][0]), float(cl[i][1]))
					hints["%s%d" % [CLICK_HINT, i]] = [Vector3(q.x, game.land.height_at(q.x, q.y) + 1.1, q.y), i]
	for k in hud.badges.keys():
		if String(k).begins_with(CLICK_HINT) and not hints.has(k):
			hud.clear_badge(k)
	for k in hints:
		hud.set_badge(k, hints[k][0], "water", false, "", click_target.bind(int(hints[k][1])), "mark")
	if on and not cine_on and area.is_empty() and not a.is_empty() and not a.get("ready", false) and not a.has("homeless"):
		area = _goal_area(a)                # где строить (скверик, сад, новый дом): то же мягкое пятно света
	# заказ старосты: пятно у его места — пока в руках то, что идёт в счёт (или после «Показать»); у истории своё место —
	# заказ берёт пятно себе, когда в руках то, что в счёт заказа, а не истории
	var t := String(game.tool) if game != null else ""
	var ord_tool := _zone_hit(orders.zone(), t)
	if on and not cine_on and (area.is_empty() or (ord_tool and not _zone_hit(_story_zone(), t)) or orders.showing()):
		var oa := orders.area(ord_tool)
		if not oa.is_empty():
			area = oa
			trail = {}
	# здание Легиона в руках и других пятен нет — военный квартал у арки (Д10: совет, а не правило)
	if on and not cine_on and area.is_empty() and t in MILITARY:
		var lz := _legion_zone()
		if not lz.is_empty():
			area = [(lz["hp"] as Vector2).x, (lz["hp"] as Vector2).y, float(lz["r"]), BUILD_GLOW, true]
	_area_marks(area, trail)


## Где выполнять цель шага: [x, z, радиус, яркость, край] у дома просящего — или []. Край (чёткая граница, без кольца) —
## только пока в руках то, что идёт в счёт цели (украшение для скверика и сада, дом для молодых): иначе мягкое пятно
func _goal_area(a: Dictionary, g: Array = []) -> Array:
	if g.is_empty():
		if bool(_step(a).get("quarter", false)):
			# военный квартал у арки: мягкое пятно; с военной постройкой в руках — чёткий край (не кольцо)
			var q := quarter()
			var qe := game != null and _zone_hit(_story_zone(), String(game.tool))
			return [float(q[0]), float(q[1]), float(q[2]), BUILD_GLOW, qe]
		g = _step(a).get("goal", [])
	if g.is_empty():
		return []
	var hp := _home_pos(a)
	var edge := game != null and _zone_hit(_story_zone(), String(game.tool))   # только цель истории (не заказа)
	match String(g[0]):
		"square", "around":
			return [hp.x, hp.y, float(g[1]), BUILD_GLOW, edge]
		"built_after", "works":
			return [hp.x, hp.y, float(g[2]), BUILD_GLOW, edge]
		"happy_home":
			# красота дома — украшения в DECOR_RADIUS: пятно, только пока украшение в руках (иначе дом и так виден)
			return [hp.x, hp.y, Defs.DECOR_RADIUS, BUILD_GLOW, edge] if edge else []
		"all":
			for sg: Array in g[1]:
				var ar := _goal_area(a, sg)
				if not ar.is_empty():
					return ar
		"flag":
			var sub: Array = (g[2] as Dictionary).get(String((a.get("flags", {}) as Dictionary).get(String(g[1]), "")), [])
			if not sub.is_empty() and String(sub[0]) == "around":
				return [hp.x, hp.y, float(sub[1]), BUILD_GLOW, edge]
	return []


# ---------- «рядом с домом» (скверик, свадебный сад, дом молодым): у курсора — в счёт ли, ✓ над тем, что в счёт ----------

## Цели «рядом с домом» сейчас: шаг истории и взятый заказ старосты (бывают обе) — [{hp, r, keys: [вид…],
## label — «скверика», no — «Это не дерево», none — чего не надо (деревянные скамьи у заказа мраморных)}]
func zone_goals() -> Array:
	if city == null or not allowed():
		return []
	var out := []
	var sz := _story_zone()
	for z: Dictionary in [sz, orders.zone()]:
		if not z.is_empty():
			out.append(z)
	# здания Легиона — военный квартал и вне истории (Д10), если история сама туда не ведёт
	if sz.is_empty() or not (sz.get("keys", []) as Array).has("barracks"):
		var lz := _legion_zone()
		if not lz.is_empty():
			out.append(lz)
	return out


## Первая из целей (история, иначе заказ) — прежним вызовам и проверкам
func zone_goal() -> Dictionary:
	var zz := zone_goals()
	return zz[0] if not zz.is_empty() else {}


func _story_zone() -> Dictionary:
	var a: Dictionary = S()["active"]
	if a.is_empty() or a.get("ready", false) or a.has("homeless"):
		return {}
	var st := _step(a)
	if bool(st.get("quarter", false)):
		# военный квартал: у курсора — в квартале ли; вне его строить тоже можно (подсказка, а не «не в счёт»)
		var q := quarter()
		return {"hp": Vector2(float(q[0]), float(q[1])), "r": float(q[2]), "keys": MILITARY.duplicate(), "label": "военного квартала",
			"ok": "В военном квартале ✓", "far": "Можно и здесь — а военный квартал у арки", "no": "", "after": -1, "room": 0, "skip": []}
	var g: Array = st.get("goal", [])
	if g.is_empty():
		return {}
	if String(g[0]) == "all":
		for sg: Array in g[1]:
			if String(sg[0]) in ["works", "happy_home", "around"]:
				g = sg
				break
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
		"works":
			r = float(g[2])
			keys = [String(g[1])]
		"happy_home":
			r = Defs.DECOR_RADIUS
			keys = ["*decor"]
			if not (zl is Array and not (zl as Array).is_empty()):
				zl = ["красоты дома", ""]
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


## Постройка type идёт в счёт какой-то цели «рядом с домом» (или похожа на нужное — тогда у курсора скажем «не в счёт»)
func zone_tool(type: String) -> bool:
	for z: Dictionary in zone_goals():
		if _zone_hit(z, type):
			return true
	return false


## type относится к этой цели: идёт в счёт или похож на нужное (у курсора скажем «не в счёт»)
func _zone_hit(z: Dictionary, type: String) -> bool:
	return not z.is_empty() and Defs.B.has(type) and (_zone_key(z, type) != "" or _zone_no(z, type) != "")


## Похожее на нужное, но не в счёт: горшки и вазы у скверика («Это не дерево»), деревянная скамья у заказа мраморных
func _zone_no(z: Dictionary, type: String) -> String:
	if type in (z.get("none", []) as Array):
		return "%s — не в счёт" % String(Defs.B[type]["name"])
	if String(z.get("no", "")) != "" and String(Defs.B[type].get("sub", "")) in ["plants", "trees"]:
		return "%s — не в счёт" % String(z["no"])
	return ""


func _zone_key(z: Dictionary, type: String) -> String:
	for k in z["keys"]:
		var ks := String(k)
		if ks == "*decor":
			if Defs.B.has(type) and String(Defs.B[type]["kind"]) == "decor":
				return "*decor"                 # любое украшение: красота дома
			continue
		if ks.begins_with("="):
			if type == ks.substr(1):
				return ks                       # «=bench» — только этот облик (мраморная скамья, не деревянная)
			continue
		if _is({"type": type}, ks):
			return ks
	return ""


## Строка у курсора для постройки type в точке p: [текст, в счёт ли] или [] (целей нет / к ним не относится).
## В счёт хоть одной цели (истории или заказа) — так и говорим; иначе «далеко от …» той, к которой относится
func zone_note(type: String, p: Vector2) -> Array:
	if not Defs.B.has(type) or not p.is_finite():
		return []
	var far := []
	var no := ""
	for z: Dictionary in zone_goals():
		if _zone_key(z, type) == "":
			if no == "":
				no = _zone_no(z, type)
			continue
		if p.distance_to(z["hp"]) <= float(z["r"]):
			return [String(z.get("ok", "В счёт %s ✓" % String(z["label"]))), true]
		if far.is_empty():
			far = [String(z.get("far", "Далеко от дома — не в счёт")), false]
	if not far.is_empty():
		return far
	return [] if no == "" else [no, false]


const ZONE_FLASH_MS := 3000                # ✓ над тем, что в счёт, — столько после постановки
var _flash: Array = []                     # ключи значков ✓
var _flash_until := 0


## Поставили постройку: на 3 с ✓ над всем, что идёт в счёт цели «рядом с домом» (если поставленное к ней относится)
func flash_counted(b: Dictionary) -> void:
	var t := String(b.get("type", ""))
	# цели, в счёт которых идёт поставленное: сначала те, у чьего места его поставили (история или заказ)
	var zs := []
	var all := []
	for z: Dictionary in zone_goals():
		if _zone_key(z, t) == "":
			continue
		all.append(z)
		if (b.get("pos", Vector2.INF) as Vector2).distance_to(z["hp"]) <= float(z["r"]):
			zs.append(z)
	if zs.is_empty():
		zs = all
	if zs.is_empty():
		return
	_flash_clear()
	var seen := {}
	for z: Dictionary in zs:
		for id in city.buildings:
			var o: Dictionary = city.buildings[id]
			if seen.has(int(id)) or (o["pos"] as Vector2).distance_to(z["hp"]) > float(z["r"]) or _zone_key(z, String(o["type"])) == "":
				continue
			if int(z["after"]) >= 0:
				# дом молодым: только новые дома (не семьи и не жениха) со свободными местами — как в _new_near
				if int(o.get("born", id)) < int(z["after"]) or int(id) in z["skip"]:
					continue
				if int(z["room"]) > 0 and (not city.is_house(o) or city.house_cap(o) - int(o["pop"]) - int(o.get("coming", 0)) < int(z["room"])):
					continue
			seen[int(id)] = true
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


## Строки цели «рядом с домом»: как назвать вид
const PART_WORDS := {"bench": "Скамьи", "tree|cypress|palm|bush": "Деревья и кусты", "well|smallfountain": "Колодец",
	"flowers|planter|bush|wall_flowers": "Цветы", "pergola|rosearch": "Беседка или арка", "taberna|thermopolium": "Таверна"}
## Цели, у которых в золотой строке — строки с ✓ (у прежних историй своя строка текста)
const PART_KINDS := ["p", "works", "floor", "happy_home", "beauty", "fest", "legion_win", "all"]


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
	var pk := k + "|" + str(a.get("home", -1))     # след — от двери этого дома (или его нет вовсе)
	if pk == _paws_key:
		return
	_paws_key = pk
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
	if _goal_kind(a) == "click":
		for cl: Array in a.get("clicks", []):
			if int(cl[2]) == 0:
				c = Vector2(float(cl[0]), float(cl[1]))   # к первой ещё не найденной луже
				break
	if _goal_kind(a) == "find":
		var g: Dictionary = _step(a)["goal"][2]
		var hours := int(S()["h"]) - int(a.get("t0", S()["h"]))
		var ar: Array = a.get("area1" if hours >= int(g.get("shrink_h", 3)) else "area0", [])
		if not ar.is_empty():
			c = Vector2(float(ar[0]), float(ar[1]))
	game.rig.look_at_point(Vector3(c.x, game.land.height_at(c.x, c.y), c.y))    # и перестаёт следовать за жителем


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


## Советник один раз на шаг с советом (advice): как устроено то, чему учит история (вода, склад, этажи)
func _advise_step() -> void:
	var a: Dictionary = S()["active"]
	if a.is_empty() or a.get("ready", false) or kit != null:
		return
	var st := _step(a)
	if not st.has("advice"):
		return
	var key := "story_adv_%s_%s" % [String(a.get("id", "")), String(st.get("id", ""))]
	if city.tips.has(key) or not hud._tip_free():
		return
	city.tips[key] = true
	var adv: Array = st["advice"]
	hud.advisor(String(adv[0]), StoryDefs.fill(String(adv[1]), a))


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
		return {"title": StoryDefs.title_of(sd, o), "icon": sd.get("icon", "scroll"), "text": StoryDefs.fill(row, o),
			"tip": StoryDefs.fill(String(sd.get("ask", "")), o) + "\nНажмите «Выслушать» или свиток над их домом.",
			"buttons": [["Выслушать", open_offer], ["Отложить", postpone]]}
	if a.is_empty():
		return {}
	var sd := _story(a)
	if sd.is_empty():
		return {}
	var info := {"title": StoryDefs.title_of(sd, a), "icon": sd.get("icon", "scroll"), "buttons": []}
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
		"click":
			var pr := progress(a, g)
			text += " Найдено: %s." % pr["txt"]
			info["buttons"] = [["Показать", show_area]]
		"beauty":
			var pr := progress(a, g)
			info["buttons"] = [["Показать", show_area]]
			if int(pr.get("tier", 0)) >= 1:
				info["buttons"] = [["Готово (%s)" % TIER[int(pr["tier"])], press.bind("ready", "")], ["Показать", show_area]]
		"works", "floor", "happy_home", "all":
			info["buttons"] = [["Показать", show_area]]
		"legion_win":
			if st.has("battle") and not bool(progress(a, g)["ok"]):
				info["buttons"] = [["В бой!", press.bind("battle", "")]]
		"p":
			if bool(st.get("quarter", false)):
				info["buttons"] = [["Показать", show_area]]
		"", "around", "wait":
			if kind != "":
				var pr := progress(a, g)
				if String(pr["txt"]) != "":
					text += " %s." % pr["txt"]
				if kind == "around":
					text += near_miss(_home_pos(a), float(g[1]), g[2])
	if kind in PART_KINDS:
		info["parts"] = goal_parts(a, g, st)    # строки с ✓: щёлкнуть невыполненную — сразу к делу
	info["text"] = text
	return info


## Щелчок по строке цели истории: нужная постройка, исследование, «Этаж» или «Обзор» (как у просьб горожан)
func part_click(p: Dictionary) -> void:
	var w: Dictionary = p.get("do", {})
	if not w.is_empty():
		hud._do_click(w)


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
	# истории помнят друг друга: такты «если та история пройдена (и выбрали это)» и имена из неё ({ref.история.поле})
	var refs := {}
	for id in (S()["done"] as Dictionary):
		refs[String(id)] = StoryDefs.ref_of(S()["done"][id])
	bind["refs"] = refs
	var bs := []
	for b: Array in beats:
		if String(b[0]) == "if":
			if _cond(String(b[1])):
				bs.append(b[2])
		else:
			bs.append(b)
	beats = bs
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
				_cine_choice(String(cine["choice"]))
				break
	_end_cine(0.9)


## Выбор в ролике после просьбы (дед остаётся или к соседям): запомнить в истории; если награда уже выдана (последний
## ролик) — добавка по выбору сейчас. Просьба («помочь / позже») — не здесь, её решает _after_ask
func _cine_choice(val: String) -> void:
	if val in ["", "go", "later"] or not (String(cine.get("mode", "")) in ["step", "final"]):
		return
	var sd: Dictionary = cine["story"]
	var a: Dictionary = S()["active"]
	if not a.is_empty() and String(a.get("id", "")) == String(sd["id"]):
		_choose(a, val)
	else:
		_reward_choice(sd, val)
	var bf: Dictionary = (cine["bind"] as Dictionary).get("flags", {})
	bf["choice"] = val
	cine["bind"]["flags"] = bf


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
	var tb = cine.get("tbeast")
	if tb != null and is_instance_valid(tb):
		(tb as Node).queue_free()
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
	trees_back()
	kit = null
	var after: Callable = cine.get("after", Callable())
	if after.is_valid():
		after.call()
	if kit == null:
		cine = {}
	if cat.has("story"):
		cat["state"] = "sleep"
	if not beast.is_empty():
		_beast_play("Eating")
	_sync_beast()
	_sync_clicks()
	_marks(true)
	hud.refresh()


func _speaker(who: String) -> Dictionary:
	var b: Dictionary = cine["bind"]
	var sd: Dictionary = cine["story"]
	if who == "cat":
		return {"kind": "cat", "fur": int(b.get("fur", 0)), "name": String(b.get("cat_name", "Мася")),
			"role": "кошка семьи %s" % StoryDefs.fam_gen(String(b.get("fam", "")))}
	if who == "advisor":
		return {"kind": "pic", "pic": "advisor.png", "name": "Советник Марк", "role": "советник градоначальника"}
	if who == "hero" and Hero.exists(city):
		return {"kind": "look", "look": Hero.look(city).duplicate(), "name": Hero.name_of(city), "role": "ваш герой", "pic": ""}
	if who == "donkey":
		return {"kind": "beast", "beast": "donkey", "name": String(b.get("cat_name", "Пузан")),
			"role": "ослик семьи %s" % StoryDefs.fam_gen(String(b.get("fam", ""))), "pic": ""}
	var ro := _role(b, who)
	var nm: Array = (sd.get("roles", {}) as Dictionary).get(who, [sd.get("who", ""), sd.get("role", "")])
	return {"kind": "citizen", "seed": int(ro["seed"]), "female": bool(ro["female"]), "child": bool(ro["child"]), "old": bool(ro.get("old", false)),
		"cls": String(ro["cls"]), "name": StoryDefs.fill(String(nm[0]), b), "role": StoryDefs.fill(String(nm[1]), b),
		"pic": "class_%s.png" % String(ro["cls"])}


## Кто играет роль: облик (seed, пол, ребёнок, сословие, старик) — из bind["roles"] или общий (история с одним героем).
## Чего в привязке нет (в журнале прежних версий не было пола и «ребёнок ли») — как у героя истории (cast): Мария
## из «Где Мася?» — взрослая девушка, дед из «Скверика» — взрослый и седой
func _role(b: Dictionary, role: String) -> Dictionary:
	var roles: Dictionary = b.get("roles", {})
	if roles.has(role):
		return roles[role]
	var cast: Dictionary = (cine.get("story", StoryDefs.story(String(b.get("id", "")))) as Dictionary).get("cast", {})
	var r0: Dictionary = cast.get(role, cast.values()[0] if not cast.is_empty() else {})
	return {"seed": int(b.get("seed", 1)), "female": bool(b.get("female", r0.get("female", false))),
		"child": bool(b.get("child", r0.get("child", false))), "cls": String(b.get("cls", "plebs")),
		"old": bool(b.get("old", r0.get("old", false)))}


## Где стоит человек роли who (кошка, ослик, место): точка на земле и куда смотрит
func _who_at(who: String) -> Array:
	if who == "cat" or (who == "donkey" and not (cine["actors"] as Dictionary).has("donkey")):
		var p: Vector3
		if who == "cat":
			var tc = _tcat() if cine["mode"] == "replay" else null
			p = _cat_pos() if tc == null else (tc as Node3D).position
		else:
			var tb = _tbeast() if cine["mode"] == "replay" or beast.is_empty() else null
			p = _pet_pos() if tb == null else (tb as Node3D).position
		# «лицом» кошки (ослика) для кадра — к дому хозяина: там обычно улица, открыто
		var h: Dictionary = city.buildings.get(int(cine["bind"].get("home", -1)), {})
		var to := ((city.door_point(h) if not h.is_empty() else Vector2(p.x, p.z) + Vector2(0, 1)) - Vector2(p.x, p.z)).normalized()
		return [p, to if to != Vector2.ZERO else Vector2(0, 1)]
	if not (cine["actors"] as Dictionary).has(who) and _is_place(who):
		var q := _place_pos(who)
		var h: Dictionary = city.buildings.get(int(cine["bind"].get("home", -1)), {})
		var to2: Vector2 = ((city.door_point(h) if not h.is_empty() else q + Vector2(0, 1)) - q).normalized()
		return [Vector3(q.x, game.land.height_at(q.x, q.y), q.y), to2 if to2 != Vector2.ZERO else Vector2(0, 1)]
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
			elif (b.size() > 2 and String(b[2]) == "wide") or (_is_place(String(b[1])) and not (cine["actors"] as Dictionary).has(String(b[1]))):
				# общий план места: трубы, фонтана, лавки (или героя издали)
				var w := _who_at(String(b[1]))
				var q := Vector2((w[0] as Vector3).x, (w[0] as Vector3).z)
				shot = _square_shot(q)
				cine["focus"] = q
			elif String(b[1]) == "proc":
				shot = (cine.get("proc", {}) as Dictionary).get("shot", [])
				if shot.is_empty():
					return
				cine["focus"] = Vector2((shot[1] as Vector3).x, (shot[1] as Vector3).z)
			else:
				var w := _who_at(String(b[1]))
				shot = _talk_shot(w[0], w[1], String(b[1]) == "cat")
				if String(b[1]) == "donkey":
					shot[1] = (shot[1] as Vector3) + Vector3(0, 0.25, 0)   # ослик выше кошки: смотрим ему в морду
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
				_act(cine["actors"].get(String(b[1])), String(b[2]))
		"walk":
			if b.size() > 3 and String(b[2]) == "to":
				_walk_begin(b)
			else:
				_act(cine["actors"].get(String(b[1])), String(b[3]) if b.size() > 3 else "Walk")
		"look":
			_look(String(b[1]), String(b[2]), String(b[3]) if b.size() > 3 else "")
		"say":
			ui.say(_speaker(String(b[1])), StoryDefs.fill(String(b[2]), bind))
			var c = cine["actors"].get(String(b[1]))
			if c != null and c is Citizen and String(b[1]) != "cat" and (c as Citizen)._cur in ["Idle", "Look_Around"]:
				(c as Citizen).play("Idle_Talking")
			elif String(b[1]) == "donkey":
				_beast_play("Idle_2")
			cine["wait"] = true
		"choice":
			ui.say(_speaker(String(b[1])), StoryDefs.fill(String(b[2]), bind))
			var opts := _avail(b[3])
			cine["opts"] = opts
			ui.choices(opts, _picked)
		"cat":
			_cat_state(String(b[1]))
		"donkey":
			_beast_play({"eat": "Eating", "idle": "Idle", "walk": "Walk"}.get(String(b[1]), "Idle"))
		"fix":
			var a: Dictionary = S()["active"]
			if not a.is_empty() and String(a.get("id", "")) == String(sd["id"]):
				a["fixed"] = true               # течь заделана: лужи и струя у трубы пропадают
			_sync_clicks()
		"fx":
			var w := _who_at(String(b[2]))
			if String(b[1]) == "hearts":
				ui.hearts((w[0] as Vector3) + Vector3(0, 0.25 if String(b[2]) != "donkey" else 1.0, 0))
			elif String(b[1]) == "petals":
				ui.petals((w[0] as Vector3) + Vector3(0, 0.6, 0))
			elif String(b[1]) == "splash":
				splash(w[0])
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
		"cart":
			_gate_cart()
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
	_tree_t -= dt
	if _tree_t <= 0.0:
		_tree_t = 0.2
		_trees_clear()
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
		"anim", "actor", "cat", "elders", "dusk", "donkey", "fix", "cart":
			if bt >= 0.35:
				_next_beat()
		"look":
			if bt >= 0.6:
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
			if b.size() > 3 and String(b[2]) == "to":
				if _walk_to_step(dt) or bt > 30.0:
					_walk_end()
					_next_beat()
			elif _walk_step(String(b[1]), dt, String(b[2])) or bt > 6.0:
				_act(cine["actors"].get(String(b[1])), "Idle")
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
	_cine_choice(val)
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
	var c: Node3D = _beast_actor(true) if role == "donkey" else _make_actor(role)
	var h: Dictionary = city.buildings.get(int(b.get("home", -1)), {})
	var p := Vector2.ZERO
	var yaw := 0.0
	if where.begins_with("from:"):
		# в начале пути к месту (последние WALK_MAX м): оттуда он пойдёт настоящими улицами (такт walk … to)
		var pts := _walk_path(where.substr(5))
		p = pts[0]
		var d := (pts[1] - pts[0]) if pts.size() > 1 else Vector2(0, 1)
		yaw = atan2(d.x, d.y)
	elif where.begins_with("near:"):
		# у постройки (ближней к дому): на свободном месте перед её входом, лицом к ней
		var bb := _near_building(where.substr(5))
		if not bb.is_empty():
			var dp: Vector2 = city.door_point(bb)
			p = _open_spot(dp + City.facing(float(bb["yaw"])) * 1.6)
			var to: Vector2 = bb["pos"]
			yaw = atan2(to.x - p.x, to.y - p.y)
		elif not h.is_empty():
			p = city.door_point(h) + City.facing(float(h["yaw"]))
	elif where == "near_pet":
		var cp3: Vector3 = _who_at("donkey")[0]
		var cp := Vector2(cp3.x, cp3.z)
		p = _approach(1.9)
		yaw = atan2(cp.x - p.x, cp.y - p.y)
	elif where == "beside" and not (cine["actors"] as Dictionary).is_empty():
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
	elif where == "gate":
		# у арки, рядом с телегой, лицом от дороги: камера встаёт перед ним, за спиной — дорога и арка (столбы с
		# флажками вдоль дороги не заслоняют кадр)
		var g0 := gate_spot()
		p = _open_spot(g0 + Vector2(-1.6, 1.8))
		var to := p + Vector2(1.0, 0.45)
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
	_act(c, "Idle")
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
	if role == "hero" and Hero.exists(city):
		# свой герой (Д11): его облик — плащ, венок, цвета (как на улице)
		var hc := Citizen.build(Hero.look(city).duplicate())
		Citizen.face_fix(hc)
		game.people.add_child(hc)
		hc.anim.speed_scale = 1.0
		return hc
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


func _put_actor(role: String, c: Node3D) -> void:
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


## Откуда хозяйка прибежит к кошке: в 4,2 м от неё, со стороны её дома, по прямой без построек (одно на ролик)
func _approach(dist := 4.2) -> Vector2:
	if cine.has("approach"):
		return cine["approach"]
	var cp3: Vector3
	if StoryDefs.find_what(cine["story"]) in ["cat", ""]:
		var tc = cine.get("tcat")
		cp3 = _cat_pos() if tc == null else (tc as Node3D).position
	else:
		cp3 = _who_at("donkey")[0]
	var cp := Vector2(cp3.x, cp3.z)
	var k_d := dist / 4.2
	var h: Dictionary = city.buildings.get(int(cine["bind"].get("home", -1)), {})
	var from: Vector2 = city.door_point(h) if not h.is_empty() else cp + Vector2(4, 0)
	var dir := (from - cp).normalized() if from.distance_to(cp) > 0.1 else Vector2(1, 0)
	var p := cp + dir * 4.2 * k_d
	var cands := []
	if cine.has("cam_dir"):
		# камера уже смотрит на кошку: хозяйка вбегает в кадр сбоку (не из-за камеры и не заслоняя кошку)
		var cd: Vector2 = cine["cam_dir"]
		for a: float in [PI / 2, -PI / 2, PI / 2 - 0.35, -PI / 2 + 0.35, PI / 2 + 0.35, -PI / 2 - 0.35, PI / 2 - 0.7, -PI / 2 + 0.7]:
			cands.append(cp + cd.rotated(a) * 3.2 * maxf(k_d, 0.75))
	for k in 12:
		cands.append(cp + dir.rotated(0.5 * ((k + 1) / 2) * (1 if k % 2 == 0 else -1)) * 4.2 * k_d)
	for q: Vector2 in cands:
		if _clear_run(q, cp):
			p = q
			break
	cine["approach"] = p
	return p


## Прохожие не заслоняют героя: кто рядом с ним или на линии камеры — прячется до конца ролика. Свой герой (Д11) с улицы —
## тоже; а если у ролика свой герой-актёр — уличный спрятан весь ролик (два одинаковых в кадре). Каждый кадр: вышел из
## двери (новая модель) — снова спрятан; _cleanup вернёт
func _crowd_clear() -> void:
	if kit == null:
		return
	var hr: Dictionary = game.people.hero_r
	var hn = null if hr.is_empty() else hr["node"]
	if hn != null and (hn as Node3D).visible and (cine.get("actors", {}) as Dictionary).has("hero"):
		(hn as Node3D).visible = false
		_hidden.append(hn)
	if not cine.has("focus"):
		return
	var focus: Vector2 = cine["focus"]
	var cam := Vector2(kit.pos.x, kit.pos.z)
	for r in game.people.residents:
		_crowd_hide(r["node"], cam, focus)
	if hn != null:
		_crowd_hide(hn, cam, focus)


func _crowd_hide(n, cam: Vector2, focus: Vector2) -> void:
	if n == null or not (n as Node3D).visible:
		return
	var p := Vector2((n as Node3D).position.x, (n as Node3D).position.z)
	var q := Geometry2D.get_closest_point_to_segment(p, cam, focus)
	if p.distance_to(focus) < 3.0 or p.distance_to(q) < 1.0:
		(n as Node3D).visible = false
		_hidden.append(n)


## Деревья, кусты и высокие украшения между камерой и героем прячутся до конца ролика (свадебное шествие шло
## сквозь кроны): луч камера → то, на что смотрит камера, проходит через крону (ствол) по высоте — дерево прячется.
## У самого героя (ближе 1,2 м) — не прячем: он стоит у этого куста, это видно
func _trees_clear() -> void:
	if kit == null or game.rig == null:
		return
	var cam3: Vector3 = kit.pos
	var at3: Vector3 = kit.look
	var a := Vector2(cam3.x, cam3.z)
	var b := Vector2(at3.x, at3.z)
	if a.distance_to(b) < 0.5:
		return
	var hit := func(p: Vector2, r: float, y0: float, y1: float) -> bool:
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		if q.distance_to(p) > r or q.distance_to(b) < 1.2:
			return false
		var y := lerpf(cam3.y, at3.y, a.distance_to(q) / maxf(a.distance_to(b), 0.01))
		return y > y0 - 0.2 and y < y1
	# украшения: деревья и всё высокое (колонны, статуи, фонари)
	for id in city.buildings:
		var bd: Dictionary = city.buildings[id]
		var key := "b%d" % int(id)
		if _hid_keys.has(key) or Defs.B.get(bd["type"], {}).get("kind", "") != "decor" or bd.has("host"):
			continue
		var p: Vector2 = bd["pos"]
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) > 3.0:
			continue
		var top: float = city.blueprint(bd).top_y()
		var tree := String(Defs.B[bd["type"]].get("sub", "")) == "trees"
		if not tree and top < 1.6:
			continue
		if hit.call(p, clampf(top * 0.4, 0.8, 2.2) if tree else 0.7, float(bd["y"]), float(bd["y"]) + top):
			var vis: Dictionary = game.visuals.get(id, {})
			if not vis.is_empty():
				_hid_parts.append_array(game.parts.hide_handles(vis["h"]))
				for l in vis.get("lights", []):
					game.night_lights.erase(l)
					(l as Node3D).visible = false
					_hid_lights.append(l)
				_hid_keys[key] = true
	# природа: деревья и кусты вдоль луча
	var lo := a.min(b) - Vector2(3, 3)
	var hi := a.max(b) + Vector2(3, 3)
	for kz in range(int(lo.y / 2.0), int(hi.y / 2.0) + 1):
		for kx in range(int(lo.x / 2.0), int(hi.x / 2.0) + 1):
			for it: Dictionary in game.nature.get(Vector2i(kx, kz), []):
				var nm := String(it.get("name", ""))
				var tree := nm.contains("Tree")
				if not tree and not nm.contains("Bush"):
					continue
				var key := "n%s" % str(it["p"])
				if _hid_keys.has(key):
					continue
				var p: Vector2 = it["p"]
				var gy: float = game.land.height_at(p.x, p.y)
				if hit.call(p, 2.0 if tree else 1.0, gy, gy + (6.5 if tree else 1.4)):
					_hid_parts.append_array(game.parts.hide_handles(it["h"]))
					_hid_keys[key] = true


## Ролик кончился (или пропущен): спрятанные деревья — на место
func trees_back() -> void:
	if not _hid_parts.is_empty():
		game.parts.restore(_hid_parts)
	_hid_parts = []
	_hid_keys = {}
	var relit := false
	for l in _hid_lights:
		if is_instance_valid(l) and not (l as Node).is_queued_for_deletion():      # фонарь не снесли за время ролика
			game.night_lights.append(l)
			relit = true
	_hid_lights = []
	if relit:
		game._set_hour(game.hour)               # свет фонарей — как положено в этот час


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


## Человек бежит к кошке (ослику); true — добежал
func _walk_step(role: String, dt: float, target := "cat") -> bool:
	var c = cine["actors"].get(role)
	if c == null or not is_instance_valid(c):
		return true
	var n := c as Node3D
	var cp: Vector3 = _who_at(target)[0]
	var to := Vector2(cp.x, cp.z)
	var p := Vector2(n.position.x, n.position.z)
	var d := to - p
	var stop := 0.5 if target == "cat" else 1.05
	if d.length() <= stop:
		return true
	var mv := 1.7 * dt
	var step := d.normalized() * minf(mv, d.length() - stop)
	p += step
	n.position = Vector3(p.x, game.land.height_at(p.x, p.y), p.y)
	n.rotation.y = atan2(d.x, d.y)
	return d.length() - mv <= stop


## Кошка в ролике: сидит, ласкается, спит (настоящая — через её состояние, в «Пересмотреть» — своя на время);
## сидит и ласкается — головой к хозяйке (или туда, откуда она прибежит)
func _cat_state(state: String) -> void:
	var cp := _who_at("cat")[0] as Vector3
	var cast: Dictionary = (cine["story"] as Dictionary).get("cast", {})
	var c = cine["actors"].get(cast.keys()[0] if not cast.is_empty() else "kid")
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
	var n := People.cat_node(int(b.get("fur", 0)), "Sit", 3, People.CAT_LEN)     # того же роста, что на улице
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


# ---------- ищут не только кошку: ослик; места в мире (лужи); ходьба и взгляды в роликах ----------

## Что ищут в идущей истории: «cat», «donkey» или ""
func _find_what(a: Dictionary) -> String:
	return StoryDefs.find_what(_story(a))


## Кошка (ослик) истории сейчас в мире: пока ищут — и пока ролик встречи (шаг сразу после поисков) ждёт щелчка
func _find_live(a: Dictionary) -> bool:
	if a.is_empty() or not a.has("spot"):
		return false
	var steps: Array = _story(a).get("steps", [])
	var i := int(a.get("step", 0))
	if i < 0 or i >= steps.size():
		return false
	var g: Array = (steps[i] as Dictionary).get("goal", [])
	if not g.is_empty() and String(g[0]) == "find":
		return true
	if bool(a.get("ready", false)) and i > 0:
		var pg: Array = (steps[i - 1] as Dictionary).get("goal", [])
		return not pg.is_empty() and String(pg[0]) == "find"
	return false


## Где кошка или ослик (для кадров, значков, щелчка)
func _pet_pos() -> Vector3:
	if not cat.is_empty():
		return _cat_pos()
	if not beast.is_empty():
		var p: Vector2 = beast["p"]
		return Vector3(p.x, game.land.height_at(p.x, p.y), p.y)
	return Vector3.ZERO


## Ослик (модель Quaternius, CC0): движения по именам, как у жителей («Walk», «Idle», «Jog_Fwd» — галоп)
class Beast extends Node3D:
	var ap: AnimationPlayer = null
	var _cur := ""

	func play(nm: String, blend := 0.3, _phase := 0.0) -> void:
		if ap == null:
			return
		var an: String = {"Jog_Fwd": "Gallop", "Idle_Talking": "Idle", "Interact": "Idle_Headlow", "Look_Around": "Idle_2"}.get(nm, nm)
		if not ap.has_animation(an):
			an = "Idle"
		if an == _cur:
			return
		_cur = an
		ap.play(an, blend)

	func set_alpha(_a: float) -> void:
		pass


## Ослик: длиной DONKEY_LEN; sacks — с поклажей (мешки по бокам, корзина сверху — везёт товар в лавку)
static func beast_node(sacks := false) -> Beast:
	var bn := Beast.new()
	var m := (load("res://assets/animals/Donkey.glb") as PackedScene).instantiate() as Node3D
	bn.add_child(m)
	var box := Artisau.aabb(m)
	m.scale = Vector3.ONE * DONKEY_LEN / maxf(0.01, maxf(box.size.x, box.size.z))
	var aps := m.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		bn.ap = aps[0]
		for an in ["Walk", "Idle", "Eating", "Gallop", "Idle_2", "Idle_Headlow"]:
			if bn.ap.has_animation(an):
				bn.ap.get_animation(an).loop_mode = Animation.LOOP_LINEAR
	if sacks:
		# поклажа на спине (детали Synty): по мешку с боков, сверху — корзина с товаром
		var back := DONKEY_LEN * 0.47
		for sx: float in [-1.0, 1.0]:
			var sk := Synty.make("SM_Prop_Sack_03")
			sk.scale = Vector3.ONE * 0.42
			sk.rotation = Vector3(0, PI / 2, sx * 0.25)
			sk.position = Vector3(sx * 0.17, back - 0.2, -0.05)
			bn.add_child(sk)
		var bk := Synty.make("SM_Prop_Basket_06")
		bk.scale = Vector3.ONE * 0.45
		bk.position = Vector3(0, back + 0.02, -0.08)
		bn.add_child(bk)
	return bn


## Ослик-актёр ролика (в начале пути к лавке — с поклажей)
func _beast_actor(sacks: bool) -> Beast:
	var bn := beast_node(sacks)
	game.add_child(bn)
	bn.play("Idle", 0.0)
	return bn


## Ослик, которого ищут: там, где спрятался, жуёт
func _spawn_beast(a: Dictionary) -> void:
	_drop_beast()
	var sp: Array = a.get("spot", [])
	if sp.size() < 2:
		return
	var bn := beast_node(false)
	game.add_child(bn)
	var p := Vector2(float(sp[0]), float(sp[1]))
	bn.position = Vector3(p.x, game.land.height_at(p.x, p.y), p.y)
	bn.rotation.y = _rng(a, 2).randf() * TAU
	bn.play("Eating", 0.0)
	beast = {"n": bn, "p": p, "kind": _find_what(a)}


func _drop_beast() -> void:
	if beast.is_empty():
		return
	var n = beast.get("n")
	if n != null and is_instance_valid(n):
		(n as Node).queue_free()
	beast = {}


## Ослик в мире — только пока он нужен истории (_find_live); в ролике не трогаем
func _sync_beast() -> void:
	if beast.is_empty() or city == null or kit != null:
		return
	if not _find_live(S()["active"]):
		_drop_beast()


func _beast_play(an: String) -> void:
	var n = beast.get("n") if not beast.is_empty() else null
	if (n == null or not is_instance_valid(n)) and not cine.is_empty() and cine.has("tbeast"):
		n = cine["tbeast"]
	if n != null and is_instance_valid(n):
		(n as Beast).play(an)


## Ослик для «Пересмотреть» (и если настоящего нет): там, где прятался, или у дома
func _tbeast() -> Node3D:
	var tb = cine.get("tbeast")
	if tb != null and is_instance_valid(tb):
		return tb
	var b: Dictionary = cine["bind"]
	var sp: Array = b.get("spot", [])
	var h: Dictionary = city.buildings.get(int(b.get("home", -1)), city.center())
	var p: Vector2 = Vector2(float(sp[0]), float(sp[1])) if sp.size() == 2 else city.door_point(h) + City.facing(float(h["yaw"])) * 5.0
	var n := beast_node(false)
	game.add_child(n)
	n.position = Vector3(p.x, game.land.height_at(p.x, p.y), p.y)
	n.rotation.y = hash(b.get("fam", "")) % 628 / 100.0
	n.play("Eating", 0.0)
	cine["tbeast"] = n
	return n


## Движение героя ролика (житель или ослик)
func _act(c, anim: String) -> void:
	if c != null and is_instance_valid(c) and (c as Object).has_method("play"):
		c.play(anim)


## Повернуться к кому-то (месту) и, если задано, показать рукой
func _look(role: String, target: String, anim: String) -> void:
	var c = cine["actors"].get(role)
	if c == null or not is_instance_valid(c):
		return
	var to: Vector3 = _who_at(target)[0]
	var n := c as Node3D
	n.rotation.y = atan2(to.x - n.position.x, to.z - n.position.z)
	if anim != "":
		_act(c, anim)


## Условие такта «если»: «история» — пройдена; «история=выбор» — пройдена, и выбрали это
func _cond(c: String) -> bool:
	if c == "hero":
		return Hero.exists(city)                 # свой герой (Д11) есть — его такты в ролике
	var e: Dictionary = (S()["done"] as Dictionary).get(c.get_slice("=", 0), {})
	if e.is_empty():
		return false
	if not c.contains("="):
		return true
	return String((e.get("flags", {}) as Dictionary).get("choice", "")) == c.get_slice("=", 1)


## Место для ролика: «spot» (где шла цель — труба), «home», «shop» (лавка, что заработала), «warehouse», «near:тип»
static func _is_place(s: String) -> bool:
	return s in ["spot", "home", "shop", "warehouse", "gate"] or s.begins_with("near:")


func _place_pos(s: String) -> Vector2:
	var b: Dictionary = cine["bind"] if not cine.is_empty() else S()["active"]
	var h: Dictionary = city.buildings.get(int(b.get("home", -1)), {})
	match s:
		"spot":
			var at: Array = b.get("at", [])
			if at.size() == 2:
				return Vector2(float(at[0]), float(at[1]))
		"shop":
			var sh: Dictionary = city.buildings.get(int((b.get("flags", {}) as Dictionary).get("shop", -1)), {})
			if not sh.is_empty():
				return city.door_point(sh)
		"warehouse":
			var wh := _nearest_store(_home_pos(b))
			if not wh.is_empty():
				return city.door_point(wh)
		"gate":
			return gate_spot()
	if s.begins_with("near:"):
		var nb := _near_building(s.substr(5))
		if not nb.is_empty():
			return nb["pos"]
	return city.door_point(h) if not h.is_empty() else (city.center()["pos"] as Vector2)


# ---------- арка на въезде и военный квартал (история «Разбойники у арки», Д9; здания Легиона на карте — этап L.2) ----------

## Военные постройки Легиона: в счёт военного квартала (у курсора — «В военном квартале ✓»)
const MILITARY := ["barracks", "range", "spearcamp", "ballistae", "catapults", "forge", "infirmary", "armory"]
const QUARTER_R := 11.0                  # радиус военного квартала, м (Казармы — участок ~9×9 м, рядом встанут и другие)
## Квартал разрастается, когда в нём встают другие здания Легиона (Д10): у курсора и пятно — на столько метров шире
const QUARTER_GROW := 6.0


## Военный квартал вне истории (Д10): здание Легиона в руках — мягкое пятно и у курсора «В военном квартале ✓»
## (строить можно где угодно: квартал — совет, бонуса «рядом» нет). {} — квартала нет или Легион закрыт
func _legion_zone() -> Dictionary:
	if city == null or not city.legion.window_open():
		return {}
	var q: Array = city.legion.quarter()
	if q.size() != 3 and game != null and String(game.tool) in MILITARY:
		q = quarter()                        # старый город (Легион изучен до истории): квартал ищем, когда здание в руках
	if q.size() != 3:
		return {}
	return {"hp": Vector2(float(q[0]), float(q[1])), "r": float(q[2]) + QUARTER_GROW, "keys": MILITARY.duplicate(), "label": "военного квартала",
		"ok": "В военном квартале ✓", "far": "Можно и здесь — а военный квартал у арки", "no": "", "after": -1, "room": 0, "skip": []}


## Где у арки стоит телега переселенцев: на обочине большой дороги, по эту сторону арки (помним до конца ролика)
func gate_spot() -> Vector2:
	if not cine.is_empty() and cine.has("gate_at"):
		return cine["gate_at"]
	var q := _open_spot(Land.GATE + Vector2(4.6, 8.5))
	if not cine.is_empty():
		cine["gate_at"] = q
	return q


## Такт «cart»: у арки — телега с мешками и рассыпанный товар (только на время ролика)
func _gate_cart() -> void:
	if cine.has("cart_on"):
		return
	cine["cart_on"] = true
	var q := gate_spot()
	for e: Array in [["cart", Vector2.ZERO, 0.35], ["goods_3", Vector2(1.5, -1.3), 1.1]]:
		var p: Vector2 = q + (e[1] as Vector2)
		if game.land.occ_at(p) != 0:
			continue
		var bp := Catalog.make(String(e[0]))
		var xf := Transform3D(Basis(Vector3.UP, float(e[2])), Vector3(p.x, game.land.height_at(p.x, p.y), p.y))
		cine["props"].append(game.parts.place(bp, xf))


## Военный квартал у арки: [x, z, радиус] — свободное место у большой дороги между аркой и станцией (один раз на город:
## Legion.flags.quarter; здания Легиона на карте, этап L.2, советник предложит ставить сюда же)
func quarter() -> Array:
	var q: Array = city.legion.quarter()
	if q.is_empty():
		q = _find_quarter()
		city.legion.flags["quarter"] = q
	return q


## Где поставить военный квартал: у большой дороги между аркой и станцией, ближе к арке; весь круг — на своей земле,
## а Казармы там правда встают (дорога у входа, не круто, свободно — City.check_place). Всё застроено — дальше по городу
func _find_quarter() -> Array:
	var cands := []
	for z: float in [77.0, 83.0, 89.0, 95.0]:
		for dx: float in [-8.5, 8.5, -10.5, 10.5]:
			cands.append(Vector2(Land.ROAD_X + dx, z))
	for z: float in [104.0, 112.0, 120.0, 128.0]:
		for dx: float in [-8.5, 8.5]:
			cands.append(Vector2(Land.ROAD_X + dx, z))
	for k in 36:                           # запас: кольца вокруг станции
		cands.append(Land.CENTER + Vector2(cos(k * TAU / 12.0), sin(k * TAU / 12.0)) * (24.0 + 12.0 * (k / 12)))
	var scored := []
	for c: Vector2 in cands:
		var whole: bool = game.land.is_owned(c)
		for k in 8:
			whole = whole and game.land.is_owned(c + Vector2(cos(k * TAU / 8.0), sin(k * TAU / 8.0)) * (QUARTER_R - 1.0))
		if not whole:
			continue
		var free := free_near(c, QUARTER_R)
		if free < 120:
			continue
		scored.append([float(mini(free, 300)) * 0.2 - c.distance_to(Land.GATE), c])
	scored.sort_custom(func(x, y): return float(x[0]) > float(y[0]))
	for e2: Array in scored:
		var spot := _barracks_spot(e2[1])
		if spot != Vector2.INF:
			return [spot.x, spot.y, QUARTER_R]           # середина квартала — ровно там, где встают Казармы
	var best: Vector2 = scored[0][1] if not scored.is_empty() else Land.GATE + Vector2(10.0, 16.0)
	return [snappedf(best.x, 0.5), snappedf(best.y, 0.5), QUARTER_R]


## Встают ли здесь Казармы (у входа дорога, свободно, не круто): точка у c или INF
func _barracks_spot(c: Vector2) -> Vector2:
	for off: Vector2 in [Vector2.ZERO, Vector2(0, 3.0), Vector2(0, -3.0), Vector2(2.5, 0), Vector2(-2.5, 0)]:
		for yaw: float in [0.0, PI / 2.0, PI, -PI / 2.0]:
			if String(city.check_place("barracks", c + off, yaw, 0, 0, -3)["err"]) == "":
				return c + off
	return Vector2.INF


## Ближняя к дому истории постройка типа (вид — как у целей, «a|b») или {}
func _near_building(type: String) -> Dictionary:
	var b: Dictionary = cine["bind"] if not cine.is_empty() else S()["active"]
	var hp := _home_pos(b)
	var best := {}
	var bd := INF
	for id in city.buildings:
		var o: Dictionary = city.buildings[id]
		if not _is(o, type):
			continue
		var d := (o["pos"] as Vector2).distance_to(hp)
		if d < bd:
			bd = d
			best = o
	return best


## Ближний к точке склад или {}
func _nearest_store(p: Vector2) -> Dictionary:
	var best := {}
	var bd := INF
	for id in city.buildings:
		var o: Dictionary = city.buildings[id]
		if city.def(o)["kind"] != "store":
			continue
		var d := (o["pos"] as Vector2).distance_to(p)
		if d < bd:
			bd = d
			best = o
	return best


## Путь к месту (последние WALK_MAX м — остальное за кадром): к трубе — от двери дома просящего, к лавке — от склада
func _walk_path(dest: String) -> PackedVector2Array:
	var key := "path:" + dest
	if cine.has(key):
		return cine[key]
	var to := _place_pos(dest)
	var b: Dictionary = cine["bind"]
	var h: Dictionary = city.buildings.get(int(b.get("home", -1)), {})
	var from: Vector2 = city.door_point(h) if not h.is_empty() else to + Vector2(6, 0)
	if dest == "shop":
		var wh := _nearest_store(to)
		if not wh.is_empty():
			from = city.door_point(wh)
	var path: PackedVector2Array = game.people._path(from, to)
	if path.size() < 2:
		path = PackedVector2Array([from, to])
	var pts := _tail(path, WALK_MAX)
	if pts.size() < 2 or _plen(pts) < 0.5:
		var back := (from - to).normalized() if from.distance_to(to) > 0.01 else Vector2(1, 0)
		pts = PackedVector2Array([to + back * 4.0, to])
	cine[key] = pts
	return pts


## Такт «идти к месту»: путь, скорость (шаг, бег; ослик), кто идёт рядом, камера следом
func _walk_begin(b: Array) -> void:
	var role := String(b[1])
	var c = cine["actors"].get(role)
	if c == null or not is_instance_valid(c):
		return
	var pts := _walk_path(String(b[3]))
	var anim := String(b[4]) if b.size() > 4 else "Walk"
	var with := ""
	var follow := false
	for k in range(5, b.size()):
		var o := String(b[k])
		if o == "follow":
			follow = true
		elif o.begins_with("with:"):
			with = o.substr(5)
	var v := People.RUN if anim == "Jog_Fwd" else People.WALK
	cine["walk"] = {"role": role, "pts": pts, "len": _plen(pts), "s": 0.0, "v": v, "with": with, "follow": follow, "re": 0.0}
	_act(c, anim)
	if with != "":
		_act(cine["actors"].get(with), "Walk")
	_walk_place()


## Все на местах по ходу пути: идущий — по пути, спутник — чуть позади и сбоку (не в стене)
func _walk_place() -> void:
	var w: Dictionary = cine.get("walk", {})
	if w.is_empty():
		return
	var pts: PackedVector2Array = w["pts"]
	var s := float(w["s"])
	var at := _proc_at(pts, s)
	var f: Vector2 = (_proc_at(pts, s + 0.6)[0] as Vector2) - (_proc_at(pts, s - 0.6)[0] as Vector2)
	f = f.normalized() if f.length() > 0.01 else (at[1] as Vector2)
	var c = cine["actors"].get(String(w["role"]))
	if c != null and is_instance_valid(c):
		var n := c as Node3D
		var q: Vector2 = at[0]
		n.position = Vector3(q.x, game.land.height_at(q.x, q.y), q.y)
		n.rotation.y = lerp_angle(n.rotation.y, atan2(f.x, f.y), 0.25) if s > 0.0 else atan2(f.x, f.y)
	var wr := String(w["with"])
	if wr != "":
		var c2 = cine["actors"].get(wr)
		if c2 != null and is_instance_valid(c2):
			var a2 := _proc_at(pts, maxf(0.0, s - 0.9))
			var side := Vector2(-f.y, f.x)
			var q2: Vector2 = (a2[0] as Vector2) + side * 0.75
			if game.land.occ_at(q2) != 0:
				q2 = (a2[0] as Vector2) - side * 0.75
			if game.land.occ_at(q2) != 0:
				q2 = a2[0]
			var n2 := c2 as Node3D
			n2.position = Vector3(q2.x, game.land.height_at(q2.x, q2.y), q2.y)
			n2.rotation.y = lerp_angle(n2.rotation.y, atan2(f.x, f.y), 0.25)


## Идут; true — дошли. «follow» — камера спереди идущего, плавно (не мечется: точку выбираем раз в 0,7 с)
func _walk_to_step(dt: float) -> bool:
	var w: Dictionary = cine.get("walk", {})
	if w.is_empty():
		return true
	var stop := maxf(0.0, float(w["len"]) - 0.35)
	w["s"] = minf(stop, float(w["s"]) + float(w["v"]) * dt)
	_walk_place()
	if bool(w["follow"]):
		var c = cine["actors"].get(String(w["role"]))
		if c != null and is_instance_valid(c):
			var n := c as Node3D
			w["re"] = float(w["re"]) - dt
			if float(w["re"]) <= 0.0 or not w.has("shot"):
				w["re"] = 0.7
				w["shot"] = _talk_shot(n.position, Vector2(sin(n.rotation.y), cos(n.rotation.y)), false)
			var shot: Array = w["shot"]
			if not kit.moving():
				kit.cam_set(kit.pos.lerp(shot[0], minf(1.0, dt * 1.6)), kit.look.lerp(shot[1], minf(1.0, dt * 2.5)))
			cine["focus"] = Vector2(n.position.x, n.position.z)
	return float(w["s"]) >= stop


func _walk_end() -> void:
	var w: Dictionary = cine.get("walk", {})
	if w.is_empty():
		return
	_act(cine["actors"].get(String(w["role"])), "Idle")
	if String(w["with"]) != "":
		_act(cine["actors"].get(String(w["with"])), "Idle")
	cine.erase("walk")


# ---------- «щёлкнуть по местам в мире»: лужи вдоль улицы, последняя — у треснувшей трубы ----------

## Места у дома просящего: вдоль улицы от двери — первое через from м, дальше через step м (последнее — у трубы).
## [] — у дома нет такой улицы (этому дому историю не предлагаем). Ответ помним до конца игрового часа
func click_spots(bind: Dictionary, n: int, o: Dictionary = {}) -> Array:
	var key := "clk:%s:%d:%d" % [String(bind.get("id", "")), int(bind.get("home", -1)), int(S()["h"])]
	if _spot_cache.has(key):
		return _spot_cache[key]
	var out := _click_spots(bind, n, float(o.get("from", 4.0)), float(o.get("step", 5.0)))
	if _spot_cache.size() > 64:
		_spot_cache.clear()
	_spot_cache[key] = out
	return out


func _click_spots(bind: Dictionary, n: int, d0: float, dstep: float) -> Array:
	var land: Land = game.land
	var h: Dictionary = city.buildings.get(int(bind.get("home", -1)), {})
	if h.is_empty():
		return []
	var door: Vector2 = city.door_point(h)
	# начало — ближняя к двери мостовая (не дальше 6 м)
	var start := Vector2.INF
	for r in range(0, 13):
		for k in (1 if r == 0 else 12):
			var q := door + Vector2(cos(k * TAU / 12.0), sin(k * TAU / 12.0)) * r * 0.5
			if land.is_road(q) and land.occ_at(q) == 0:
				start = q
				break
		if start != Vector2.INF:
			break
	if start == Vector2.INF:
		return []
	# обход мостовой шагом 1 м: у каждой точки — сколько метров до неё по улице; дальняя — та, что дальше всех по улице
	# (и от двери: вода бежит от дома, лужи уводят вдоль улицы)
	var want := d0 + dstep * (n - 1)
	var seen := {Vector2i(0, 0): 0.0}
	var par := {}
	var q := [Vector2i(0, 0)]
	var far := Vector2i(0, 0)
	var far_s := -1.0
	var rg := _rng(bind, 3)
	var head := 0
	while head < q.size() and q.size() < 4000:
		var c: Vector2i = q[head]
		head += 1
		var cd: float = seen[c]
		if cd >= want:
			continue
		for dv: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = c + dv
			if seen.has(nb):
				continue
			var p := start + Vector2(nb)
			if not land.is_road(p) or land.occ_at(p) != 0 or not land.is_owned(p) or land.is_water(p):
				continue
			seen[nb] = cd + 1.0
			par[nb] = c
			q.append(nb)
			var score := cd + 1.0 + p.distance_to(door) * 0.3 + rg.randf() * 0.4
			if score > far_s:
				far_s = score
				far = nb
	var total := float(seen.get(far, 0.0))
	if total < want * 0.6:
		return []
	var chain := [far]
	while chain[chain.size() - 1] != Vector2i(0, 0):
		chain.append(par[chain[chain.size() - 1]])
	chain.reverse()
	var out := []
	for i in n:
		var dd := (d0 + dstep * i) * minf(1.0, total / want)
		var p := start + Vector2(chain[clampi(int(round(dd)), 0, chain.size() - 1)])
		out.append([p.x, p.y])
	return out


## Шаг «щёлкнуть»: где лужи (последняя — у трубы: туда потом пойдёт мастер — «spot»)
func _start_click(a: Dictionary, g: Array) -> void:
	var n := int(g[2])
	var sp := click_spots(a, n, g[3] if g.size() > 3 else {})
	if sp.size() < n:
		# с предложения улицу перестроили: лужи — прямо перед домом
		sp = []
		var h: Dictionary = city.buildings.get(int(a.get("home", -1)), {})
		var door: Vector2 = city.door_point(h) if not h.is_empty() else (city.center()["pos"] as Vector2)
		var f := City.facing(float(h.get("yaw", 0.0)))
		for i in n:
			var q: Vector2 = game.people._near_free(door + f * (3.0 + 2.5 * i), 20)
			if q == Vector2.INF:
				q = door + f * (3.0 + 2.5 * i)
			sp.append([q.x, q.y])
	var cl := []
	for p: Array in sp:
		cl.append([float(p[0]), float(p[1]), 0])
	a["clicks"] = cl
	var last: Array = sp[sp.size() - 1]
	a["at"] = [float(last[0]), float(last[1])]
	_clicks_key = "-"
	_sync_clicks()


## Лужи и труба в мире: пока ищут течь — и пока мастер её не заделал (ролик после поисков)
func _sync_clicks() -> void:
	if city == null or game == null:
		return
	var a: Dictionary = S()["active"]
	var want: bool = not a.is_empty() and a.has("clicks") and not bool(a.get("fixed", false)) and allowed() \
		and (_goal_kind(a) == "click" or bool(a.get("ready", false)) or kit != null)
	var key := str(a.get("clicks", [])) if want else ""
	if key == _clicks_key:
		return
	_clicks_key = key
	_clear_clicks()
	if not want:
		return
	var cl: Array = a["clicks"]
	for i in cl.size():
		var n := _puddle_node(Vector2(float(cl[i][0]), float(cl[i][1])), int(cl[i][2]) > 0, i == cl.size() - 1, _rng(a, 10 + i))
		game.add_child(n)
		_clicks.append(n)


func _clear_clicks() -> void:
	for n in _clicks:
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
	_clicks = []
	for k in hud.badges.keys():
		if String(k).begins_with(CLICK_HINT):
			hud.clear_badge(k)


## Лужа на мостовой: несколько плоских пятен воды, по ним расходятся круги; dry — уже нашли (мокрое пятно).
## Последняя (pipe) — ямка, поперёк неё свинцовая труба, из трещины бьёт струя
func _puddle_node(p: Vector2, dry: bool, pipe: bool, rg: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(p.x, game.land.height_at(p.x, p.y) + 0.015, p.y)
	root.rotation.y = rg.randf() * TAU
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.27, 0.52, 0.64, 0.84) if not dry else Color(0.13, 0.11, 0.09, 0.42)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.04 if not dry else 0.5
	water.metallic_specular = 0.9
	water.render_priority = -1
	for k in 3:
		var cm := CylinderMesh.new()
		var r := rg.randf_range(0.42, 0.72) * (1.35 if pipe else 1.0)
		cm.top_radius = r
		cm.bottom_radius = r
		cm.height = 0.01
		cm.radial_segments = 9
		cm.rings = 1
		var mi := MeshInstance3D.new()
		mi.mesh = cm
		mi.material_override = water
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(rg.randf_range(-0.4, 0.4), 0.003 * k, rg.randf_range(-0.4, 0.4))
		mi.scale = Vector3(1.0, 1.0, rg.randf_range(0.6, 1.0))
		root.add_child(mi)
	if not dry or pipe:
		# круги по воде: кольцо растёт и тает (лужа живая — видно, что сюда капает)
		var tm := TorusMesh.new()
		tm.inner_radius = 0.9
		tm.outer_radius = 1.0
		tm.rings = 16
		tm.ring_segments = 4
		var rm := StandardMaterial3D.new()
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rm.albedo_color = Color(0.9, 0.97, 1.0, 0.0)
		var ring := MeshInstance3D.new()
		ring.mesh = tm
		ring.material_override = rm
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.position = Vector3(0, 0.02, 0)
		ring.scale = Vector3(0.1, 0.02, 0.1)
		root.add_child(ring)
		var tw := ring.create_tween().set_loops()
		tw.tween_interval(rg.randf_range(0.05, 0.8))
		tw.tween_property(ring, "scale", Vector3(0.1, 0.02, 0.1), 0.01)
		tw.tween_property(rm, "albedo_color:a", 0.75, 0.01)
		tw.tween_property(ring, "scale", Vector3(0.75, 0.02, 0.75), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(rm, "albedo_color:a", 0.0, 1.5)
	if pipe:
		# ямка в мостовой, по краю камешки; поперёк — свинцовая труба (серая), из трещины бьёт струя
		var pit := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.5
		pm.bottom_radius = 0.42
		pm.height = 0.02
		pm.radial_segments = 8
		pit.mesh = pm
		var dm := StandardMaterial3D.new()
		dm.albedo_color = Color("3a2a1c")
		dm.roughness = 1.0
		pit.material_override = dm
		pit.position = Vector3(0, 0.012, 0)
		root.add_child(pit)
		var pc := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.07
		cy.bottom_radius = 0.07
		cy.height = 1.5
		cy.radial_segments = 8
		pc.mesh = cy
		var lm := StandardMaterial3D.new()
		lm.albedo_color = Color("7f8a93")
		lm.roughness = 0.45
		lm.metallic = 0.3
		pc.material_override = lm
		pc.rotation = Vector3(0, 0, PI / 2)
		pc.position = Vector3(0, 0.07, 0)
		root.add_child(pc)
		for sx: float in [-0.62, 0.6]:
			var pb := Synty.make("SM_Env_Pebbles_0%d" % (1 + rg.randi() % 3))
			pb.scale = Vector3.ONE * 0.55
			pb.position = Vector3(sx, 0, rg.randf_range(-0.35, 0.35))
			root.add_child(pb)
		var jug := Synty.make("SM_Prop_Jug_0%d" % (1 + rg.randi() % 4))
		jug.scale = Vector3.ONE * 0.6
		jug.position = Vector3(0.35, 0, 0.55)
		root.add_child(jug)
		root.add_child(_jet())
	return root


## Струя из трещины: капли летят вверх и падают (частицы — работают и в режиме совместимости)
static func _jet() -> CPUParticles3D:
	var pp := CPUParticles3D.new()
	pp.amount = 36
	pp.lifetime = 0.8
	pp.direction = Vector3(0.15, 1, 0)
	pp.spread = 10.0
	pp.initial_velocity_min = 2.0
	pp.initial_velocity_max = 2.8
	pp.gravity = Vector3(0, -9.0, 0)
	pp.scale_amount_min = 0.6
	pp.scale_amount_max = 1.2
	var qm := QuadMesh.new()
	qm.size = Vector2(0.06, 0.06)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.82, 0.94, 1.0, 0.85)
	qm.material = m
	pp.mesh = qm
	pp.position = Vector3(0.05, 0.12, 0)
	return pp


## Брызги воды (лужа, починенная труба, новый фонтан): капли разлетаются и падают (без облака — вблизи оно заслоняет кадр)
func splash(at: Vector3) -> void:
	var pp := _jet()
	pp.one_shot = true
	pp.explosiveness = 0.9
	pp.amount = 28
	pp.spread = 55.0
	pp.initial_velocity_min = 1.4
	pp.initial_velocity_max = 2.6
	pp.position = at + Vector3(0, 0.12, 0)
	pp.emitting = true
	game.add_child(pp)
	get_tree().create_timer(1.8).timeout.connect(pp.queue_free)


## Под курсором лужа, по которой надо щёлкнуть: её номер или -1
func _click_at(mp: Vector2) -> int:
	if game.rig == null:
		return -1
	var a: Dictionary = S()["active"]
	var cam: Camera3D = game.rig.cam
	var cl: Array = a.get("clicks", [])
	var best := -1
	var bd := CLICK_PX * 1.6
	for i in cl.size():
		if int(cl[i][2]) > 0:
			continue
		var q := Vector2(float(cl[i][0]), float(cl[i][1]))
		var w := Vector3(q.x, game.land.height_at(q.x, q.y) + 0.1, q.y)
		if cam.is_position_behind(w):
			continue
		var d := cam.unproject_position(w).distance_to(mp)
		if d < bd:
			bd = d
			best = i
	return best


## Нашли лужу i: брызги, «Плюх!» (у трубы — «Вот она — трещина!»), лужа становится мокрым пятном; все найдены — ролик
func click_target(i: int) -> void:
	var a: Dictionary = S()["active"]
	if a.is_empty() or _goal_kind(a) != "click":
		return
	var cl: Array = a.get("clicks", [])
	if i < 0 or i >= cl.size() or int(cl[i][2]) > 0:
		return
	cl[i][2] = 1
	var p := Vector2(float(cl[i][0]), float(cl[i][1]))
	var y: float = game.land.height_at(p.x, p.y)
	var last := i == cl.size() - 1
	splash(Vector3(p.x, y, p.y))
	ui.bubble3d(Vector3(p.x, y + 1.0, p.y), "Вот она — трещина!" if last else "Плюх!", 2.4, 28)
	if not last and i < _clicks.size() and is_instance_valid(_clicks[i]):
		var nn := _puddle_node(p, true, false, _rng(a, 10 + i))
		game.add_child(nn)
		(_clicks[i] as Node).queue_free()
		_clicks[i] = nn
	_clicks_key = str(cl)
	hud.clear_badge("%s%d" % [CLICK_HINT, i])
	_tick_active(true)
	hud.refresh()
