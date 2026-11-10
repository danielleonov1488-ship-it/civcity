extends Node3D
## Лист моделей для владельца: все люди, кошки, бойцы и враги Легиона крупно, группами, с подписями — отметить,
## что выглядит плохо. Город готовый (demo), интерфейс спрятан. Запуск:
##   bash .work/py/gpu_run.sh res://test_models_sheet.tscn -- [out=D:/CivCity/.work/models_sheet]
var game
var out := "D:/CivCity/.work/models_sheet"
var root: Node3D


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	Game.boot = {"demo": "1", "noui": "1", "hour": "11.0"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	await frames(6)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("shot ", name)


## Площадка: ровное место у края города (земля под ногами — высота Land)
var base := Vector2(150, 175)


func _y(x: float, z: float) -> float:
	return game.land.height_at(x, z)


func _label(t: String, at: Vector3) -> void:
	var l := Label3D.new()
	l.text = t
	l.font_size = 48
	l.pixel_size = 0.0035
	l.outline_size = 12
	l.modulate = Color("fff4dc")
	l.outline_modulate = Color(0.15, 0.1, 0.05)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	root.add_child(l)
	l.global_position = at


func _clear() -> void:
	if root != null:
		root.queue_free()
	root = Node3D.new()
	add_child(root)


## Ряд: объекты по одному через step, подпись под каждым; камера — на середину ряда
func _row(items: Array, step: float, cam_d: float, name: String, z := 0.0) -> void:
	var n := items.size()
	for i in n:
		var it: Array = items[i]
		var x := base.x + (i - (n - 1) * 0.5) * step
		var zz := base.y + z
		var node: Node3D = it[0]
		if node.get_parent() == null:
			root.add_child(node)
		node.global_position = Vector3(x, _y(x, zz), zz)
		node.rotation.y = PI * 0.08          # к камере, чуть вполоборота
		_label(String(it[1]), Vector3(x, _y(x, zz) + float(it[2]) if it.size() > 2 else _y(x, zz) + 2.2, zz))


func _cam(d: float, pitch := 14.0, h := 0.9) -> void:
	var c := Vector3(base.x, _y(base.x, base.y) + h, base.y)
	game.rig.set_view(c, 0.0, pitch, d)              # (цель, поворот, наклон, расстояние)


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(30)
	game.speed = 0.0
	# площадка: где меньше всего деревьев и кустов (game.nature — клетки по 2 м) и нет построек — ряд ±14 м, камера — до 16 м спереди
	var best := 1e9
	for cx in range(40, 360, 10):
		for cz in range(40, 300, 10):
			var n := 0
			var occ := false
			for dx in range(-16, 17, 2):
				for dz in range(-6, 18, 2):
					var key := Vector2i(int((cx + dx) / 2.0), int((cz + dz) / 2.0))
					n += (game.nature.get(key, []) as Array).size()
					var ci := int((cx + dx) / Land.CELL)
					var cj := int((cz + dz) / Land.CELL)
					if game.land.inside(ci, cj) and game.land.occ[game.land.idx(ci, cj)] != 0:
						occ = true
			var flat := absf(_y(cx - 14, cz) - _y(cx + 14, cz)) < 1.0
			if not occ and flat and n < best:
				best = n
				base = Vector2(cx, cz)
	if game.rig.attrs:
		game.rig.attrs.dof_blur_far_enabled = false     # лист — резкий целиком
		game.rig.attrs.dof_blur_near_enabled = false
	print("base ", base, " nature ", best)
	var c = game.city
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# --- 1. горожане, туристы, герой ---
	_clear()
	var ppl := []
	for e: Array in [[false, false, false, "горожанин"], [true, false, false, "горожанка"], [false, false, true, "богатый"], [true, false, true, "богатая"],
			[false, true, false, "ребёнок"], [true, true, false, "девочка"]]:
		var p := Citizen.create(rng, e[0], e[1], e[2])
		p.scale = Vector3.ONE * Citizen.SIZE
		root.add_child(p)
		p.play("Idle_Loop", 0.0, rng.randf())
		ppl.append([p, e[3], 1.5])
	var tour: Tourism = game.get_node("Tourism")
	for i in 2:
		var t := Citizen.create(rng, i == 1, false, false)
		t.scale = Vector3.ONE * Citizen.SIZE
		root.add_child(t)
		tour._dress(t, i)
		t.play("Idle_Loop", 0.0, rng.randf())
		ppl.append([t, "турист" if i == 0 else "туристка", 1.5])
	_row(ppl, 1.6, 7.0, "people")
	_cam(11.0, 16.0, 0.6)
	await frames(30)
	await shot("1_people")
	# --- 2. кошки: все окрасы ---
	_clear()
	var home := {}
	for id in c.buildings:
		if c.is_house(c.buildings[id]):
			home = c.buildings[id]
			break
	var cats := []
	var furs: int = game.people.CAT_FURS.size()
	for i in mini(furs + 1, 9):
		var cat: Dictionary = game.people._make_cat(home, {"fur": i if i < furs else game.people.CAT_SIAMESE, "rng": rng, "p": Vector2(base.x, base.y)})
		var n: Node3D = cat["n"]
		n.reparent(root)
		cats.append([n, "окрас %d" % (i + 1) if i < furs else "сиамская", 0.75])
	_row(cats, 1.25, 4.0, "cats")
	for e in cats:
		(e[0] as Node3D).rotation.y = -PI * 0.3
	_cam(6.8, 18.0, 0.25)
	await frames(30)
	await shot("2_cats")
	# --- 3. Легион и его враги ---
	var keys: Array = LegionFighter.LOOKS.keys()
	var beasts: Array = LegionFighter.BEASTS.keys() + LegionFighter.STATUES.keys() + ["ballista", "catapult"]
	var chunks := []
	for i in range(0, keys.size(), 9):
		chunks.append(keys.slice(i, i + 9))
	for i in range(0, beasts.size(), 7):
		chunks.append(beasts.slice(i, i + 7))
	var page := 0
	for ch: Array in chunks:
		_clear()
		var row := []
		for k in ch:
			var f := LegionFighter.create(String(k), 1.0, 3)
			root.add_child(f)
			var nm := String(k)
			if Legion.UNITS.has(nm):
				nm = String(Legion.UNITS[nm].get("name", nm))
			elif Legion.ENEMIES.has(nm):
				nm = String(Legion.ENEMIES[nm].get("name", nm))
			row.append([f, nm, 2.3])
		_row(row, 1.75, 10.0, "legion")
		_cam(15.0, 24.0, 1.0)
		await frames(40)
		page += 1
		await shot("3_legion_%d" % page)
	print("SHEET DONE")
	get_tree().quit()
