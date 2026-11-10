class_name LegionEvents
extends RefCounted
## События недели Легиона (docs/ONLINE_V2.md §3) — вкладка «События» окна «Легион», только в новой игре (Легион 2.0).
## Неделя — как на сервере (server/events.js): от понедельника 2.11.2026 00:00 UTC, у всех одна и та же.
##   - Испытание недели — с сервером (SocialNet.events_*): бой по правилу недели против врага недели, три сложности,
##     таблица очков; награду за первую победу на сложности даёт сервер.
##   - Нашествие варваров (чётные недели) и Подземелья (нечётные) — без сервера: бои против варваров (враги походов:
##     галлы, германцы, берсерки, волки), сила — под силу нашего отряда. Набегов — RAIDS_DAY в сутки; этажей
##     подземелья — FLOORS за неделю, по порядку, каждый сильнее. Награда — денарии и Слава (подземелье — ещё обломки
##     для Кузницы, если Легион 2.0).
## Бой — обычный 3D-бой с городом (kind "pvp": враги строем, их умения жмёт бой) с пометкой setup.event; итог считает
## apply(), а не бои с городами (LegionBattle._begin_end).

const EPOCH := 1793577600                # 2.11.2026 00:00 UTC — как EPOCH в server/events.js
const WEEK := 604800
const RAIDS_DAY := 3
const RAID_K := [0.85, 1.0, 1.15]
const RAID_FOES := ["gaul", "gaul", "gaulArcher", "berserker", "germArcher", "wolf"]
const FLOORS := 5
const FLOOR_K := [0.8, 0.95, 1.1, 1.25, 1.45]
const FLOOR_FOES := [["wolf", "wolf", "wolf", "wolf", "bandit"], ["bandit", "bandit", "gaulArcher", "bandit", "wolf"],
	["gaul", "gaul", "gaulArcher", "gaulArcher", "gaul"], ["berserker", "berserker", "germArcher", "germArcher", "berserker"],
	["gaulKing", "gaul", "gaul", "gaulArcher", "gaulArcher"]]
const FLOOR_NAMES := ["Волчье логово", "Пещера разбойников", "Галльские катакомбы", "Святилище берсерков", "Чертог вождя"]


static func week(t := -1.0) -> int:
	var now := Legion.now() if t < 0.0 else t
	return maxi(0, int(floor((now - EPOCH) / WEEK)))


static func ends_in() -> int:
	return maxi(0, int(EPOCH + (week() + 1) * WEEK - Legion.now()))


## Событие города этой недели: "invasion" — Нашествие варваров, "dungeon" — Подземелья
static func kind(w := -1) -> String:
	return "invasion" if (week() if w < 0 else w) % 2 == 0 else "dungeon"


static func on(lg: Legion) -> bool:
	return lg != null and lg.army_on() and lg.window_open()


## Записи этой недели в Legion.flags["ev"]: {w, d (сутки набегов), n (набегов в эти сутки), raids (за неделю), floor}
static func rec(lg: Legion) -> Dictionary:
	var e: Dictionary = lg.flags.get("ev", {})
	var w := week()
	if int(e.get("w", -1)) != w:
		e = {"w": w, "d": -1, "n": 0, "raids": 0, "floor": 0}
		lg.flags["ev"] = e
	var d := int(floor(Legion.now() / 86400.0))
	if int(e.get("d", -1)) != d:
		e["d"] = d
		e["n"] = 0
	return e


static func raids_left(lg: Legion) -> int:
	return maxi(0, RAIDS_DAY - int(rec(lg).get("n", 0)))


static func floor_now(lg: Legion) -> int:
	return int(rec(lg).get("floor", 0))


## Почему нельзя в бой ("" — можно)
static func can(lg: Legion, what: String) -> String:
	if not on(lg):
		return "События — с Легионом 2.0 (новая игра)"
	if lg.battle_squad().is_empty():
		return "Сначала соберите отряд (вкладка «Войска»)"
	if what == "raid":
		if kind() != "invasion":
			return "Нашествие — на следующей неделе"
		if raids_left(lg) <= 0:
			return "Набеги на сегодня отбиты — варвары вернутся завтра"
	elif what == "floor":
		if kind() != "dungeon":
			return "Подземелья — на следующей неделе"
		if floor_now(lg) >= FLOORS:
			return "Все подземелья недели пройдены!"
	return ""


## Сила нашего отряда (как в окне)
static func my_power(lg: Legion) -> int:
	var p := 0
	for s: Dictionary in lg.battle_squad():
		p += Legion.power(s)
	return p


## Враги на силу target: подобрать масштаб (как у врагов походов: Legion.foe_stats)
static func foes_for(keys: Array, target: float) -> Array:
	var lo := 0.2
	var hi := 40.0
	for i in 28:
		var mid := (lo + hi) * 0.5
		var p := 0
		for k in keys:
			p += Legion.power(Legion.foe_stats({"scale": mid, "boss_scale": mid * 0.7}, String(k)))
		if p < target:
			lo = mid
		else:
			hi = mid
	var out := []
	for k in keys:
		out.append(Legion.foe_stats({"scale": hi, "boss_scale": hi * 0.7}, String(k)))
	return out


## Настройка боя события (city event): what — "raid" | "floor"
static func make(lg: Legion, what: String) -> Dictionary:
	var e := rec(lg)
	var keys: Array
	var k: float
	var title: String
	if what == "raid":
		var i := clampi(int(e.get("n", 0)), 0, RAIDS_DAY - 1)
		var rnd := RandomNumberGenerator.new()
		rnd.seed = hash([week(), int(e.get("d", 0)), i, "raid"])
		keys = []
		for j in 5 + rnd.randi() % 3:
			keys.append(RAID_FOES[rnd.randi() % RAID_FOES.size()])
		k = float(RAID_K[i])
		title = "Набег варваров %d из %d" % [i + 1, RAIDS_DAY]
	else:
		var f := clampi(int(e.get("floor", 0)), 0, FLOORS - 1)
		keys = FLOOR_FOES[f]
		k = float(FLOOR_K[f])
		title = "Подземелье %d: %s" % [f + 1, FLOOR_NAMES[f]]
	var foes := foes_for(keys, my_power(lg) * k)
	var s := {"kind": "pvp", "opponent": {"name": title, "rating": 0}, "squad": lg.battle_squad(), "waves": [foes], "perks": lg.open_perks(),
		"enemy_perks": {}, "enemy_auto": true, "enemy_formation": true, "seed": (int(Legion.now() * 1000.0) & 0xffffff) + 1,
		"event": {"id": what, "title": title, "k": k, "power": my_power(lg)}}
	if lg.hero_ready():
		var c = lg.city()
		s["hero_look"] = Hero.battle_look(c, lg.hero_kit_level())
	return s


## «В бой» события города: проверить и попросить 3D-бой
static func start(lg: Legion, what: String) -> Dictionary:
	if can(lg, what) != "":
		return {}
	var s := make(lg, what)
	lg.battle_requested.emit(s)
	return s


## Бой испытания недели: ответ сервера (SocialNet.trial_attack) → настройка боя (воюем ровно тем отрядом, что вернул сервер)
static func make_trial(lg: Legion, a: Dictionary) -> Dictionary:
	var own: Dictionary = a.get("attack", {})
	var enemy: Dictionary = a.get("enemy", {})
	var s := {"kind": "pvp", "opponent": {"name": String(a.get("name", "Испытание недели")), "rating": 0}, "squad": Legion.snapshot_stats(own),
		"waves": [Legion.snapshot_stats(enemy)], "perks": Legion.snapshot_perks(own), "enemy_perks": Legion.snapshot_perks(enemy),
		"enemy_auto": true, "enemy_formation": true, "seed": int(a.get("seed", 1)),
		"event": {"id": "trial", "title": String(a.get("name", "")), "battle": String(a.get("battle", "")), "tier": int(a.get("tier", 1))}}
	return s


## Итог боя события → награда (испытание — награду даёт сервер: SocialNet.trial_report)
static func apply(lg: Legion, setup: Dictionary, result: Dictionary) -> Dictionary:
	var ev: Dictionary = setup.get("event", {})
	var what := String(ev.get("id", ""))
	var win := bool(result.get("win", false)) and not bool(result.get("retreat", false))
	var out := result.duplicate()
	out["reward"] = {}
	out["event"] = ev
	var e := rec(lg)
	if what == "raid":
		e["n"] = int(e.get("n", 0)) + 1                  # набег — и проигранный (варвары ушли с добычей)
		if win:
			e["raids"] = int(e.get("raids", 0)) + 1
			var rw := {"money": roundi(200.0 + 0.5 * float(ev.get("power", 0)) * float(ev.get("k", 1.0))), "glory": 2 + int(e.get("n", 1))}
			out["money_lost"] = lg._give(rw)
			out["reward"] = rw
			out["note"] = "Набег отбит! За неделю отбито: %d" % int(e["raids"])
		else:
			out["note"] = "Варвары ушли с добычей, но город цел. Следующий набег — сильнее нашего духа!"
	elif what == "floor":
		if win:
			var f := int(e.get("floor", 0))
			e["floor"] = f + 1
			var rw := {"money": roundi(300.0 + 0.7 * float(ev.get("power", 0)) * float(ev.get("k", 1.0))), "glory": 3 + 2 * f}
			out["money_lost"] = lg._give(rw)
			out["reward"] = rw
			if lg.army_on():
				var n := 10 + 6 * f                       # материалы мастерских (Gear.MATS) — до вместимости Склада
				for m: String in Gear.MATS:
					lg.mats[m] = minf(float(lg.mat_cap(m)), float(lg.mats.get(m, 0.0)) + n)
				out["note"] = "Подземелье пройдено! Материалы для Кузницы: +%d каждого" % n
			else:
				out["note"] = "Подземелье пройдено!"
			if f + 1 >= FLOORS:
				out["note"] = "Все подземелья недели пройдены! Вождь повержен."
		else:
			out["note"] = "Отряд отступил из подземелья — попробуйте снова, когда окрепнете"
	elif what == "trial":
		out["note"] = "Очки испытания — с сервера…" if win else "Испытание не пройдено — попыток в сутки 5"
	var c = lg.city()
	if c != null:
		c.changed.emit()
	lg.changed.emit()
	return out
