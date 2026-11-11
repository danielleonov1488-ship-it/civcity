class_name KitShutters
extends Node
## Ставни и двери домов из своего набора живут по часам (владелец 11.11: «окошки закрываются, открываются»):
## утром распахиваются, вечером закрываются — у каждого дома в своё время (по номеру дома), на ночь прикрыта и дверь.
## Створки — детали Parts (MultiMesh): у дома меняется место его створок (поворот на петле), плавно, ~1,5 с.
## Пустой дом стоит со ставнями закрытыми.

const OPEN_H := [6.0, 8.0]            # утром — в этот промежуток (у каждого дома свой час)
const CLOSE_H := [20.0, 22.0]         # вечером
const SPEED := 0.7                    # доля раскрытия в секунду
const TICK := 0.25

var game
var _k := {}                          # id дома → доля раскрытия 0…1 (1 — как задумано в Blender)
var _goal := {}                       # id → куда движется
var _t := 0.0
var _knock := {}                      # id → сколько секунд ещё распахнута дверь (житель вошёл)
const KNOCK_T := 1.8
const DOOR_WIDE := 1.45               # рад — на сколько распахивается дверь, когда входят


func setup(g) -> void:
	game = g


## Дом заново выставлен (Game._show): створки снова в задуманном положении
func reset(id: int) -> void:
	_k[id] = 1.0
	_goal.erase(id)


## Житель вошёл в дом id (People._door_done): дверь распахивается и через пару секунд прикрывается
func knock(id: int) -> void:
	if _k.has(id):
		_knock[id] = KNOCK_T


func forget(id: int) -> void:
	_k.erase(id)
	_goal.erase(id)


func _want(b: Dictionary, h: float) -> float:
	if int(b.get("pop", 0)) <= 0:
		return 0.0
	var r := float(hash(int(b["id"]) * 7 + 3) % 1000) / 1000.0
	var o := lerpf(OPEN_H[0], OPEN_H[1], r)
	var c := lerpf(CLOSE_H[0], CLOSE_H[1], fmod(r * 7.31, 1.0))
	return 1.0 if h >= o and h < c else 0.0


func _process(delta: float) -> void:
	if game == null or game.city == null:
		return
	_t += delta
	var h: float = game.look_hour if game.look_hour >= 0.0 else game.hour
	if _t >= TICK:
		_t = 0.0
		for id in _k.keys():
			var b: Dictionary = game.city.buildings.get(id, {})
			if b.is_empty() or not game.visuals.has(id):
				_k.erase(id)
				continue
			var w := _want(b, h)
			if absf(w - float(_k[id])) > 0.001:
				_goal[id] = w
	for id in _knock.keys():
		var left: float = float(_knock[id]) - delta
		if left <= 0.0:
			_knock.erase(id)
			_pose(id, float(_k.get(id, 1.0)))
			continue
		_knock[id] = left
		var x := 1.0 - left / KNOCK_T                       # 0 → 1 за время «стука»
		var w := clampf(minf(x / 0.2, (1.0 - x) / 0.35), 0.0, 1.0)
		_pose(id, float(_k.get(id, 1.0)), w)
	if _goal.is_empty():
		return
	for id in _goal.keys():
		var w: float = _goal[id]
		var k: float = _k.get(id, 1.0)
		k = move_toward(k, w, SPEED * delta)
		_k[id] = k
		_pose(id, k)
		if absf(k - w) < 0.001:
			_goal.erase(id)


## Створки дома id — на долю раскрытия k
func _pose(id: int, k: float, door_w := 0.0) -> void:
	var b: Dictionary = game.city.buildings.get(id, {})
	var vis: Dictionary = game.visuals.get(id, {})
	if b.is_empty() or vis.is_empty():
		return
	var bp: Bp = game.city.blueprint(b)
	if bp.kit_mov.is_empty():
		return
	var xf: Transform3D = game.city.xf(b) * bp.kit_sq
	var hs: Array = vis.get("h", [])
	for m: Array in bp.kit_mov:
		var pi: int = m[0]
		if pi >= hs.size():
			continue
		var o: Vector3 = m[1]
		var u: Vector3 = m[2]
		var n: Vector3 = m[3]
		var side: int = m[4]
		var ang: float = float(m[5]) * k
		if door_w > 0.0 and String(m[6]) == "door" and o.y < 0.6:
			ang = lerpf(ang, DOOR_WIDE, door_w)
		var t := xf * Transform3D(Basis(u, Vector3.UP, n) * Basis(Vector3.UP, ang * side), o)
		var hnd: Array = hs[pi]
		var g: Dictionary = hnd[0]
		var slot: int = hnd[1]
		for sub in g["subs"]:
			(sub["mm"] as MultiMesh).set_instance_transform(slot, t * (sub["local"] as Transform3D))
