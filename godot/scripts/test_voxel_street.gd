extends Node
## Пробная воксельная улица (для сравнения A/B): настоящая игра с её светом и та же дорога, что в test_street.gd;
## вдоль дороги — воксельные римские домики «как в Town to City», фонтан, кипарис, олива, скамьи, фонарь и люди.
## Аргументы (после --): tag=voxel  hour=12.5  mode=naive|greedy  views=0,1,2,3
## Снимки: D:/CivCity/.work/street/<tag>_v<N>.png
const VP := preload("res://scripts/voxel_proto.gd")

var game
var tag := "voxel"
var hour := 12.5
var mode := "naive"
var views := [0, 1, 2, 3]
var root: Node3D
var y0 := 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv.size() == 2:
			match kv[0]:
				"tag": tag = kv[1]
				"hour": hour = float(kv[1])
				"mode": mode = kv[1]
				"views": views = Array(kv[1].split(",")).map(func(x): return int(x))
	Game.boot = {"new": "1", "noui": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _add(vp, pos: Vector3, yaw := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = vp.build_greedy() if mode == "greedy" else vp.build_mesh()
	mi.position = pos
	mi.rotation.y = yaw
	root.add_child(mi)
	if hour >= 18.5 or hour <= 6.0:
		for lp: Vector3 in vp.lights:
			var l := OmniLight3D.new()
			l.light_color = Color("ffbe6e")
			l.light_energy = 2.0
			l.omni_range = 6.0
			l.position = lp
			mi.add_child(l)
	return mi


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	game.hud.visible = false
	var z := 140.0
	game.land.paint_line(Vector2(162, z), Vector2(262, z), 1.4, Land.Kind.ROAD, true)
	game.people.refresh(game.land.road_chunks.keys())
	root = Node3D.new()
	game.add_child(root)
	y0 = game.land.height_at(200.0, z)

	var houses := [
		{"w": 26, "wall": VP.W_LILAC, "low": ["win", "door", "winf"], "up": ["win", "door"], "chim": 4, "pots": [2], "wall_lamp": true, "seed": 101},
		{"w": 20, "wall": VP.W_YELLOW, "low": ["door", "winf"], "up": ["door", "win"], "pergola": true, "chim": 14, "wall_lamp": true, "seed": 202},
		{"w": 26, "wall": VP.W_BLUE, "low": ["winf", "door", "win"], "up": ["door", "win"], "chim": 19, "pots": [22], "seed": 303},
		{"w": 22, "wall": VP.W_PINK, "low": ["win", "door"], "up": ["win", "door"], "shut": VP.SHUT_B, "band": true, "canopy": true, "chim": 3, "pots": [17], "seed": 404},
	]
	var zf := 137.6                     # плоскость фасадов
	var gap := 0.6
	var x := 168.0
	var xs := []
	for h in houses:
		xs.append(x)
		x += h["w"] * VP.V + gap
	var x_end: float = x - gap
	var mx := (168.0 + x_end) / 2.0
	# земля под улицей ровная, на высоте дороги
	var cells: PackedInt32Array = game.land.footprint_cells([Rect2(0, 0, x_end - 168.0 + 8.0, 15.5)], Vector2(164.0, 130.5), 0.0)
	game.land.flatten_cells(cells, y0)

	# мостовая перед домами
	var pave = VP.new()
	pave.pavement(int((x_end - 168.0 + 3.0) / VP.V), 12)
	_add(pave, Vector3(166.5, y0 - VP.V + 0.04, zf - 1.6))
	print("pavement tris ", pave.tris)

	var total := 0
	var total_g := 0
	for i in houses.size():
		var vp = VP.new()
		vp.house(houses[i])
		_add(vp, Vector3(xs[i], y0, zf))
		var cnt = VP.new()
		cnt.house(houses[i])
		cnt.build_mesh()
		var naive: int = cnt.tris
		cnt.build_greedy()
		var greedy: int = cnt.tris
		print("house %d (%d vox wide): naive %d tris, greedy %d tris" % [i, houses[i]["w"], naive, greedy])
		total += naive
		total_g += greedy

	# скамьи у домов, фонарь в промежутке
	var b1 = VP.new()
	b1.bench()
	_add(b1, Vector3(xs[0] + VP._layout(houses[0]["low"], 26)[0] * VP.V, y0 + 0.04, zf + 0.42))
	var b2 = VP.new()
	b2.bench()
	_add(b2, Vector3(xs[2] + VP._layout(houses[2]["low"], 26)[2] * VP.V, y0 + 0.04, zf + 0.42))
	var lmp = VP.new()
	lmp.lamp()
	_add(lmp, Vector3(xs[1] - gap * 0.5, y0 + 0.04, zf + 0.35), -PI / 2.0)
	var lmp2 = VP.new()
	lmp2.lamp()
	_add(lmp2, Vector3(xs[3] - gap * 0.5, y0 + 0.04, zf + 0.35), -PI / 2.0)
	# деревья по краям
	var cy = VP.new()
	cy.cypress(28, 3)
	_add(cy, Vector3(168.0 - 1.1, y0, zf - 2.0))
	var cy2 = VP.new()
	cy2.cypress(24, 9)
	_add(cy2, Vector3(168.0 - 2.4, y0, zf - 3.6))
	var ol = VP.new()
	ol.olive(5)
	_add(ol, Vector3(x_end + 2.2, y0, zf - 2.2))
	print("cypress tris ", cy.tris, ", olive tris ", ol.tris)
	# фонтан и скамья через дорогу
	var fo = VP.new()
	fo.fountain()
	_add(fo, Vector3(mx - 3.5, y0, 143.4))
	var b3 = VP.new()
	b3.bench()
	_add(b3, Vector3(mx + 1.5, y0 + 0.02, 143.2))
	print("fountain tris ", fo.tris)
	var n := float(houses.size())
	print("VOXEL per house avg: naive %d tris, greedy %d tris -> 300 houses ~ %.2f M (naive) / %.2f M (greedy) tris" % [int(total / n), int(total_g / n), total / n * 300.0 / 1e6, total_g / n * 300.0 / 1e6])

	# люди для масштаба — как в test_street.gd
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for k in 10:
		var c := Citizen.create(rng, k % 2 == 0, k % 4 == 3)
		game.actors_root.add_child(c)
		var px := mx - 12.0 + k * 2.7
		c.position = Vector3(px, game.land.height_at(px, z + 0.4 * (k % 3) - 0.4), z + 0.4 * (k % 3) - 0.4)
		c.rotation.y = rng.randf() * TAU
		c.play("Idle_Loop" if k % 3 else "Walk_Loop", 0.0)
	game.speed = 0.0
	game.clock_hours = false
	game._set_hour(hour)
	await frames(20)
	for v in views:
		match v:
			0: game.rig.set_view(Vector3(mx, 1.5, z - 3), 15, 34, 22)     # три четверти спереди
			1: game.rig.set_view(Vector3(mx - 6, 1.5, z - 3), 35, 24, 11)  # вблизи
			2: game.rig.set_view(Vector3(mx, 1.5, z - 2), 10, 46, 40)     # как играют в Town to City
			3: game.rig.set_view(Vector3(mx, 1.5, z - 4), 200, 32, 22)    # сзади-сбоку
		await frames(70)
		get_viewport().get_texture().get_image().save_png("D:/CivCity/.work/street/%s_v%d.png" % [tag, v])
	print("voxel street done ", tag)
	get_tree().quit()
