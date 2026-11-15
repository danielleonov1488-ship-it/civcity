class_name Birds
extends Node3D
## Птицы над городом: кружат стайками на разной высоте, машут крыльями, иногда планируют.

var birds := []
var center := Vector3(38, 0, 44)
var game = null                           # игра: по её постройкам птицы держат высоту (15.11 — не пролетают сквозь дома)
var _tops := {}                           # клетка 8 м → высота самой высокой постройки в ней
var _tops_t := 0.0


func _ready() -> void:
	var body_k := Kit.new()
	body_k.box(Vector3(-0.06, -0.05, -0.16), Vector3(0.06, 0.05, 0.16), Color("b9b2a6"))
	body_k.box(Vector3(-0.04, -0.02, 0.16), Vector3(0.04, 0.05, 0.26), Color("b9b2a6"))
	body_k.box(Vector3(-0.015, 0.0, 0.26), Vector3(0.015, 0.02, 0.31), Color("e2a13c"))
	body_k.box(Vector3(-0.05, -0.02, -0.26), Vector3(0.05, 0.02, -0.16), Color("9e978c"))
	var wing_k := Kit.new()
	wing_k.box(Vector3(0.0, -0.01, -0.09), Vector3(0.36, 0.01, 0.09), Color("aaa398"))
	wing_k.box(Vector3(0.26, -0.012, -0.08), Vector3(0.36, 0.012, 0.06), Color("6d6a66"))
	var body_m := body_k.mesh()
	var wing_m := wing_k.mesh()
	var mat := Kit.material()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 14:
		var b := Node3D.new()
		var body := MeshInstance3D.new()
		body.mesh = body_m
		body.material_override = mat
		b.add_child(body)
		var wl := MeshInstance3D.new()
		wl.mesh = wing_m
		wl.material_override = mat
		var wr := MeshInstance3D.new()
		wr.mesh = wing_m
		wr.material_override = mat
		wr.scale = Vector3(-1, 1, 1)
		b.add_child(wl)
		b.add_child(wr)
		add_child(b)
		var flock := i % 3
		b.scale = Vector3.ONE * 0.42
		# низко над крышами: камера теперь выше и дальше — птицы не должны пролетать у самого объектива
		birds.append({"n": b, "l": wl, "r": wr, "rad": 9.0 + flock * 6.0 + rng.randf() * 3.0, "y": 6.5 + flock * 1.6 + rng.randf() * 1.2,
			"sp": (0.22 + rng.randf() * 0.08) * (1.0 if flock != 1 else -1.0), "ph": rng.randf() * TAU, "fl": rng.randf() * TAU,
			"cx": center.x + (flock - 1) * 9.0, "cz": center.z - flock * 4.0})


## Высоты построек по клеткам 8 м — раз в несколько секунд
func _refresh_tops() -> void:
	_tops.clear()
	if game == null or game.city == null:
		return
	for id in game.city.buildings:
		var b: Dictionary = game.city.buildings[id]
		var o: Vector3 = game.city.xf(b).origin
		var h: float = o.y + game.city.blueprint(b).top_y()
		var k := Vector2i(int(floor(o.x / 8.0)), int(floor(o.z / 8.0)))
		_tops[k] = maxf(float(_tops.get(k, 0.0)), h)


## Высота, ниже которой над точкой летать нельзя: самая высокая постройка в соседних клетках + запас
func _clear_y(x: float, z: float) -> float:
	var kx := int(floor(x / 8.0))
	var kz := int(floor(z / 8.0))
	var top := 0.0
	for j in range(kz - 1, kz + 2):
		for i in range(kx - 1, kx + 2):
			top = maxf(top, float(_tops.get(Vector2i(i, j), 0.0)))
	return top + 2.5 if top > 0.0 else 0.0


func _process(dt: float) -> void:
	var t := AnimClock.now()
	_tops_t -= dt
	if _tops_t <= 0.0:
		_tops_t = 3.0
		_refresh_tops()
	for b in birds:
		b["ph"] += b["sp"] * dt
		var a: float = b["ph"]
		var r: float = b["rad"] + sin(a * 1.7) * 1.5
		var px: float = b["cx"] + cos(a) * r
		var pz: float = b["cz"] + sin(a) * r
		# высота плавно поднимается над крышами внизу (и опускается обратно над пустым местом)
		var wy: float = maxf(float(b["y"]), _clear_y(px, pz))
		b["yc"] = lerpf(float(b.get("yc", wy)), wy, 1.0 - exp(-dt * 1.5))
		var p := Vector3(px, float(b["yc"]) + sin(a * 2.3) * 0.8, pz)
		var dir := Vector3(-sin(a), 0, cos(a)) * signf(b["sp"])
		var n: Node3D = b["n"]
		n.position = p
		n.look_at(p + dir, Vector3.UP)
		n.rotate_object_local(Vector3.UP, PI)
		n.rotate_object_local(Vector3.BACK, -0.35 * signf(b["sp"]))
		# машет крыльями, а иногда парит
		var glide := sin(t * 0.4 + b["fl"]) > 0.5
		var flap := 0.15 if glide else sin(t * 11.0 + b["fl"]) * 0.7
		(b["l"] as Node3D).rotation.z = flap
		(b["r"] as Node3D).rotation.z = -flap
