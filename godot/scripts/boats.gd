class_name Boats
extends Node3D
## Лодки на прудах («Уютный Рим», этап 7 «большое вау»): на прудах побольше днём плавает деревянная лодка с гребцом —
## медленно, кругами, вёсла загребают; к ночи лодка уходит к берегу и пропадает до утра. Только вид, новая игра.
## Лодка — своя сетка (корпус сужается к носу и корме, банка, борта), гребец — житель Citizen сидя.

const MIN_R := 10.0                      # пруд не меньше этого радиуса
const HOURS := [7.0, 19.5]
const SPEED := 0.04                      # радиан в секунду по кругу (×скорость игры)

var game
var boats: Array = []                    # [{n, oars: [L, R], c, r, a, w, ph}]


func setup(g) -> void:
	game = g
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for pd in Land.PONDS:
		var c3: Vector3 = pd[0]
		if c3.z < MIN_R:
			continue
		var n := Node3D.new()
		n.name = "Boat"
		add_child(n)
		var hull := MeshInstance3D.new()
		hull.mesh = hull_mesh()
		n.add_child(hull)
		var oars := []
		for sd: float in [-1.0, 1.0]:
			var piv := Node3D.new()
			piv.position = Vector3(sd * 0.42, 0.32, 0.05)
			n.add_child(piv)
			var oar := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(1.3, 0.035, 0.05)
			oar.mesh = bm
			oar.position = Vector3(sd * 0.55, -0.12, 0)
			oar.rotation.z = -sd * 0.3                # лопасть ниже уключины — в воде
			oar.material_override = _wood(Color("8a6238"))
			piv.add_child(oar)
			oars.append(piv)
		var rower := Citizen.create(rng, rng.randf() < 0.3)
		rower.scale = Vector3.ONE * Citizen.SIZE
		rower.position = Vector3(0, 0.12, 0.15)
		rower.rotation.y = PI                    # лицом к корме — гребут спиной вперёд
		n.add_child(rower)
		rower.play("Sitting_Idle", 0.0, rng.randf())
		boats.append({"n": n, "oars": oars, "c": Vector2(c3.x, c3.y), "r": c3.z * rng.randf_range(0.45, 0.6), "a": rng.randf() * TAU,
			"w": SPEED * (1.0 if rng.randf() < 0.5 else -1.0), "ph": rng.randf() * TAU})


func _process(dt: float) -> void:
	if game == null or not game.ready_done or game.city == null:
		return
	var on: bool = int(game.city.cozy_v) >= 1 and game.hour >= HOURS[0] and game.hour < HOURS[1] and game.mode != "menu"
	var spd := clampf(float(game.speed), 0.0, 3.0)
	var t := AnimClock.now()
	for b: Dictionary in boats:
		var n: Node3D = b["n"]
		n.visible = on
		if not on:
			continue
		b["a"] = float(b["a"]) + float(b["w"]) * dt * spd
		var a: float = b["a"]
		var rr: float = float(b["r"]) * (1.0 + 0.1 * sin(a * 2.0 + float(b["ph"])))
		var p: Vector2 = (b["c"] as Vector2) + Vector2(cos(a), sin(a)) * rr
		n.position = Vector3(p.x, Land.WATER_Y - 0.03 + sin(t * 1.3 + float(b["ph"])) * 0.02, p.y)
		var dir := Vector2(-sin(a), cos(a)) * signf(float(b["w"]))
		n.rotation.y = atan2(dir.x, dir.y)
		n.rotation.z = sin(t * 0.9 + float(b["ph"])) * 0.025
		# гребок: вёсла ходят вперёд-назад и чуть поднимаются над водой на возврате
		var st := t * 1.6 * maxf(0.3, spd) + float(b["ph"])
		for i in 2:
			var piv: Node3D = b["oars"][i]
			var sd := -1.0 if i == 0 else 1.0
			piv.rotation.y = sin(st) * 0.5 * sd
			piv.rotation.z = -(0.04 + 0.1 * cos(st)) * sd


static func _wood(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return m


## Корпус лодки (смотрит вдоль +Z): борта сужаются к носу и корме, дно, банка поперёк; длина ~2,4 м
static func hull_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var zs := [-1.2, -0.85, -0.3, 0.3, 0.85, 1.25]
	var ws := [0.12, 0.38, 0.48, 0.48, 0.36, 0.04]
	var top := 0.42
	var bot := 0.05
	var outer := Color("7a5230")
	var inner := Color("a57a4a")
	var rim := Color("5e3d22")
	for i in range(zs.size() - 1):
		for sd: float in [-1.0, 1.0]:
			var a0 := Vector3(sd * ws[i], top, zs[i])
			var a1 := Vector3(sd * ws[i + 1], top, zs[i + 1])
			var b0 := Vector3(sd * ws[i] * 0.6, bot, zs[i])
			var b1 := Vector3(sd * ws[i + 1] * 0.6, bot, zs[i + 1])
			_quad(st, a0, a1, b1, b0, outer)
			_quad(st, a0 - Vector3(sd * 0.04, 0, 0), b0 - Vector3(sd * 0.03, -0.02, 0), b1 - Vector3(sd * 0.03, -0.02, 0), a1 - Vector3(sd * 0.04, 0, 0), inner)
			_quad(st, a0, a0 - Vector3(sd * 0.04, 0, 0), a1 - Vector3(sd * 0.04, 0, 0), a1, rim)
		# дно
		_quad(st, Vector3(-ws[i] * 0.6, bot + 0.02, zs[i]), Vector3(ws[i] * 0.6, bot + 0.02, zs[i]), Vector3(ws[i + 1] * 0.6, bot + 0.02, zs[i + 1]), Vector3(-ws[i + 1] * 0.6, bot + 0.02, zs[i + 1]), inner)
	# банки (сиденья) поперёк
	for z: float in [0.15, -0.65]:
		var w := 0.44 if z > 0.0 else 0.36
		var y := 0.3
		_quad(st, Vector3(-w, y, z - 0.1), Vector3(w, y, z - 0.1), Vector3(w, y, z + 0.1), Vector3(-w, y, z + 0.1), rim)
	st.generate_normals()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.85
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(m)
	return st.commit()


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	for v: Vector3 in [a, b, c, a, c, d]:
		st.set_color(col)
		st.add_vertex(v)
