class_name Tourism
extends Node3D
## Туризм («Уютный Рим», этап 6 — часть без сервера, docs/PLAN_COZY.md): гостиница принимает гостей, они днём
## гуляют по достопримечательностям рядом (храм, форум, арка, акведук, маяк, театр, термы, фонтаны, статуи) и платят
## за ночлег и прогулку. Чем больше и краше достопримечательностей в шаге от гостиницы — тем больше гостей и денег.
## Цель становится бесконечной без роста населения. Только в новой игре (City.cozy_v ≥ 1).
##
## Числа (static — их же зовёт City.sim_day каждый игровой час):
##   звёзды места = Σ привлекательности достопримечательностей в TOUR_R м от гостиницы (каждый тип — не больше
##   TOUR_SAME раз, украшения — deco / 10), не больше TOUR_MAX;
##   гостей в сутки = TOUR_CAP × штат × (TOUR_BASE + звёзды / TOUR_DIV), не больше TOUR_CAP × 1,6;
##   денариев в час = гостей × TOUR_SPEND × (1 + счастье города / 200) / 24.
## Картинка: днём из гостиницы выходит пара-тройка гостей (шляпы-петасы, сумки) и обходит ближние достопримечательности.

const TOUR_R := 48.0
const TOUR_SAME := 2
const TOUR_MAX := 40.0
const TOUR_CAP := 10
const TOUR_BASE := 0.35
const TOUR_DIV := 22.0
const TOUR_SPEND := 100.0                 # денариев с гостя за ночлег, еду и прогулку (без достопримечательностей гостиница едва окупается)
const WALK_H := [8.5, 18.5]                # когда гости гуляют
const WALK_GAP := [25.0, 50.0]             # с между выходами групп у одной гостиницы (×1)
const WALK_SPEED := 1.1

## Привлекательность достопримечательностей (тип → очки); остальные памятники — по цене
const SIGHTS := {"arch": 8.0, "aqua": 9.0, "pharos": 10.0, "pantheon": 12.0, "colosseum": 12.0, "forum": 8.0, "temple": 6.0, "venus": 8.0,
	"theatre": 7.0, "odeon": 6.0, "thermae": 8.0, "baths": 6.0, "nymphaeum": 6.0, "fountain": 4.0, "circus_fl": 9.0, "obelisk": 5.0,
	"ludus": 5.0, "balnea": 3.0}


static func cozy(city) -> bool:
	return city != null and int(city.get("cozy_v")) >= 1


## Достопримечательности у гостиницы b: {score, list: [[название, очки, id]], decor}
static func sights(city, b: Dictionary) -> Dictionary:
	var at: Vector2 = b["pos"]
	var per := {}
	var list := []
	var score := 0.0
	var decor := 0.0
	for id in city.buildings:
		var o: Dictionary = city.buildings[id]
		if int(o["id"]) == int(b["id"]):
			continue
		var p: Vector2 = o["pos"]
		if p.distance_to(at) > TOUR_R:
			continue
		var t := String(o["type"])
		var base := Defs.base_of(t)
		var d: Dictionary = Defs.B.get(t, {})
		var pts := 0.0
		if SIGHTS.has(base):
			pts = float(SIGHTS[base])
		elif String(d.get("kind", "")) == "monument":
			pts = clampf(float(d.get("cost", 0)) / 400.0, 2.0, 8.0)
		elif String(d.get("kind", "")) == "decor":
			decor += float(d.get("deco", 0)) / 10.0
			continue
		if pts <= 0.0:
			continue
		per[base] = int(per.get(base, 0)) + 1
		if int(per[base]) > TOUR_SAME:
			continue
		score += pts
		list.append([String(d.get("name", t)), pts, int(o["id"])])
	score += minf(decor, 8.0)
	list.sort_custom(func(a, c): return float(a[1]) > float(c[1]))
	return {"score": minf(TOUR_MAX, score), "list": list, "decor": minf(decor, 8.0)}


## Гостиница сейчас: {score, guests (в сутки), per_h (денариев в час), list}
static func inn_info(city, b: Dictionary) -> Dictionary:
	var s := sights(city, b)
	var staff := float(b.get("staff", 0.0)) if bool(b.get("active", false)) else 0.0
	var g := TOUR_CAP * staff * minf(1.6, TOUR_BASE + float(s["score"]) / TOUR_DIV)
	var happy := float(city.stats.get("happy", 50))
	s["guests"] = roundi(g)
	var vin := 1.33 if int(city.fest_left) > 0 and String(city.get("cal_fest_id")) == "vinalia" else 1.0   # Виналии
	s["per_h"] = g * TOUR_SPEND * (1.0 + happy / 200.0) / 24.0 * vin
	return s


## Доход туризма за игровой час (City.sim_day)
static func hour_income(city) -> float:
	if not cozy(city):
		return 0.0
	var sum := 0.0
	for id in city.buildings:
		var b: Dictionary = city.buildings[id]
		if String(b["type"]) == "mansio":
			sum += float(inn_info(city, b)["per_h"])
	# туристы из городов друзей и других игроков (SocialNet, docs/ONLINE_V2.md): +6% за город-друг, +3% за прочий, до +40%
	return sum * (1.0 + SocialNet.tour_bonus(city))


# =====================================================================
#   гуляющие гости (картинка)
# =====================================================================

var game
var groups: Array = []                     # [{n: [Citizen], path, len, d}]
var _next := {}                            # id гостиницы → с до выхода следующей группы
var _rng := RandomNumberGenerator.new()


func setup(g) -> void:
	game = g
	_rng.randomize()


func _process(dt: float) -> void:
	if game == null or not game.ready_done or game.city == null or game.people == null:
		return
	var spd := clampf(float(game.speed), 0.0, 3.0)
	var h: float = game.hour
	var on: bool = cozy(game.city) and h >= WALK_H[0] and h < WALK_H[1] and str(game.settings.get("quality", "high")) != "verylow"
	if on and spd > 0.0:
		for id in game.city.buildings:
			var b: Dictionary = game.city.buildings[id]
			if String(b["type"]) != "mansio" or not bool(b.get("active", false)):
				continue
			var k := int(b["id"])
			_next[k] = float(_next.get(k, _rng.randf_range(2.0, 8.0))) - dt * spd
			if float(_next[k]) <= 0.0 and groups.size() < 6:
				_next[k] = _rng.randf_range(WALK_GAP[0], WALK_GAP[1])
				_spawn(b)
	_step(dt, dt * spd)


## Группа гостей: из двери гостиницы к 1–3 ближним достопримечательностям и обратно
func _spawn(b: Dictionary) -> void:
	var s := sights(game.city, b)
	var stops: Array = (s["list"] as Array).slice(0, 3)
	if stops.is_empty():
		return
	stops.shuffle()
	var city = game.city
	var home: Vector2 = city.door_point(b)
	var pts := PackedVector2Array([home])
	var cur := home
	for e: Array in stops.slice(0, _rng.randi_range(1, mini(3, stops.size()))):
		var o: Dictionary = city.buildings.get(int(e[2]), {})
		if o.is_empty():
			continue
		var to: Vector2 = city.door_point(o)
		var seg: PackedVector2Array = game.people._path(cur, to)
		if seg.size() < 2:
			continue
		pts.append_array(seg.slice(1))
		cur = to
	var back: PackedVector2Array = game.people._path(cur, home)
	if back.size() >= 2:
		pts.append_array(back.slice(1))
	if pts.size() < 3:
		return
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	var n := _rng.randi_range(2, 3)
	var people := []
	for i in n:
		var c := Citizen.create(_rng, _rng.randf() < 0.5, i == 2 and _rng.randf() < 0.5, _rng.randf() < 0.4)
		c.name = "Tourist"
		add_child(c)
		c.scale = Vector3.ONE * Citizen.SIZE
		c.visible = false
		_dress(c, i)
		c.play("Walk_Loop", 0.0, _rng.randf())
		people.append(c)
	var grp := {"n": people, "path": pts, "len": total, "d": 0.0}
	# гости из другого города (друга или просто игрока): подпись над группой, вблизи; городу-источнику — известность
	var sn := SocialNet.live()
	var from: Dictionary = sn.guest_pick(_rng) if sn != null else {}
	if not from.is_empty():
		sn.mark_visit(int(from["id"]))
		var lb := Label3D.new()
		lb.text = "из «%s»" % String(from["name"]) + (" ♥" if bool(from.get("friend", false)) else "")
		lb.font_size = 56
		lb.pixel_size = 0.00028
		lb.outline_size = 10
		lb.modulate = Color("fff4dc")
		lb.outline_modulate = Color(0.18, 0.11, 0.05, 0.85)
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.no_depth_test = true
		lb.fixed_size = true                 # одного размера на экране, как значки над постройками
		lb.visible = false
		add_child(lb)
		grp["label"] = lb
		grp["from"] = from
	groups.append(grp)


## Гость с дороги: широкополая шляпа-петас и дорожная сумка (из коробок и цилиндров — без файлов)
func _dress(c: Citizen, i: int) -> void:
	var sk: Skeleton3D = c.find_children("*", "Skeleton3D", true, false)[0] if not c.find_children("*", "Skeleton3D", true, false).is_empty() else null
	if sk == null:
		return
	var head := sk.find_bone("Head")
	if head < 0:
		return
	var ba := BoneAttachment3D.new()
	ba.bone_name = "Head"
	sk.add_child(ba)
	var hat := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.1
	cm.bottom_radius = 0.24
	cm.height = 0.1
	cm.radial_segments = 12
	hat.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = [Color("b08a52"), Color("8c6a3c"), Color("c9a86a")][i % 3]
	m.roughness = 0.9
	hat.material_override = m
	hat.position = Vector3(0, 0.27, 0.01)
	ba.add_child(hat)


func _step(dt: float, sdt: float) -> void:
	var left := []
	for g: Dictionary in groups:
		var ppl: Array = g["n"]
		g["d"] = float(g["d"]) + sdt * WALK_SPEED
		var alive := false
		for i in ppl.size():
			var obj = ppl[i]
			if not is_instance_valid(obj):
				continue                          # уже дошёл и ушёл в гостиницу
			var c: Citizen = obj
			var at := float(g["d"]) - i * 0.9
			if at >= float(g["len"]):
				c.queue_free()
				ppl[i] = null
				continue
			alive = true
			if at < 0.0:
				continue
			var e := _along(g["path"], at)
			var q: Vector2 = e[0]
			var dir: Vector2 = e[1]
			var side := Vector2(-dir.y, dir.x) * (0.35 if i % 2 == 0 else -0.35)
			q += side
			c.visible = true
			c.position = Vector3(q.x, game.land.height_at(q.x, q.y), q.y)
			c.rotation.y = lerp_angle(c.rotation.y, atan2(dir.x, dir.y), minf(1.0, dt * 6.0))
			if c.anim != null:
				c.anim.speed_scale = maxf(0.3, sdt / maxf(dt, 0.0001)) if sdt > 0.0 else 0.0
		var lb = g.get("label")
		if lb != null and is_instance_valid(lb):
			# подпись — над первым гостем в пути, только не издалека (дальше — не загромождать город)
			var lead = null
			for obj in ppl:
				if obj != null and is_instance_valid(obj) and (obj as Citizen).visible:
					lead = obj
					break
			var near: bool = lead != null and game.rig != null and game.rig.cam != null and game.rig.cam.global_position.distance_to((lead as Citizen).global_position) < 70.0
			(lb as Label3D).visible = near
			if lead != null:
				(lb as Label3D).global_position = (lead as Citizen).global_position + Vector3(0, 1.45, 0)
			if not alive:
				(lb as Label3D).queue_free()
		if alive:
			left.append(g)
	groups = left


static func _along(path: PackedVector2Array, d: float) -> Array:
	for i in range(1, path.size()):
		var seg := path[i - 1].distance_to(path[i])
		if d <= seg or i == path.size() - 1:
			var t := clampf(d / maxf(seg, 0.001), 0.0, 1.0)
			return [path[i - 1].lerp(path[i], t), (path[i] - path[i - 1]).normalized()]
		d -= seg
	return [path[path.size() - 1], Vector2(0, 1)]
