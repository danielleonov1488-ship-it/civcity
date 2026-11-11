extends Node3D
## Просмотр для владельца: модель из нейросети (Higgsfield/Tripo, .glb с диска) рядом с нашим домом в готовом
## городке, со светом игры. В игру модель не попадает: .glb читается прямо с диска (GLTFDocument), без импорта.
##   bash .work/py/gpu_run.sh res://test_hf_house.tscn -- glb=D:/CivCity/.work/higgsfield/house/house_tripo.glb
##     [out=D:/CivCity/.work/hf_house] [type=house_artisan] [scale=1.0 — к ширине нашего дома] [hour=11]
var game
var out := "D:/CivCity/.work/hf_house"
var glb := "D:/CivCity/.work/higgsfield/house/house_tripo.glb"
var type := "house_artisan"
var k := 1.0
var hour := "11.0"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		match kv[0]:
			"out": out = kv[1]
			"glb": glb = kv[1]
			"type": type = kv[1]
			"scale": k = float(kv[1])
			"hour": hour = kv[1]
	DirAccess.make_dir_recursive_absolute(out)
	Game.boot = {"demo": "1", "noui": "1", "hour": hour}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	await frames(8)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("shot ", name)


## Границы постройки на земле (по клеткам Land): Rect2 в метрах
func _rect(b: Dictionary) -> Rect2:
	var cells: PackedInt32Array = b["cells"]
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	for c in cells:
		var p := Vector2(c % Land.N, c / Land.N) * Land.CELL
		mn = mn.min(p)
		mx = mx.max(p + Vector2.ONE * Land.CELL)
	return Rect2(mn, mx - mn)


func _free(r: Rect2) -> bool:
	var land: Land = game.land
	var x := r.position.x
	while x < r.end.x:
		var z := r.position.y
		while z < r.end.y:
			var i := int(x / Land.CELL)
			var j := int(z / Land.CELL)
			if not land.inside(i, j) or land.occ[land.idx(i, j)] != 0:
				return false
			z += Land.CELL
		x += Land.CELL
	return absf(land.height_at(r.position.x, r.position.y) - land.height_at(r.end.x, r.end.y)) < 0.6


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(30)
	game.speed = 0.0
	if game.rig.attrs:
		game.rig.attrs.dof_blur_far_enabled = false
		game.rig.attrs.dof_blur_near_enabled = false
	# модель с диска
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var t0 := Time.get_ticks_msec()
	var err := doc.append_from_file(glb, st)
	if err != OK:
		print("GLB error ", err)
		get_tree().quit(1)
		return
	var model: Node3D = doc.generate_scene(st)
	var tris := 0
	var aabb := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		for s in m.get_surface_count():
			tris += (m.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		var bb: AABB = (mi as MeshInstance3D).get_aabb()
		aabb = bb if first else aabb.merge(bb)
		first = false
	print("GLB loaded in ", Time.get_ticks_msec() - t0, " ms, triangles ", tris, ", aabb ", aabb)
	# наш дом с местом сбоку
	var c = game.city
	var pick := {}
	var spot := Rect2()
	# сначала дома нужного типа, потом любые дома; место — слева, справа, спереди или сзади
	for pass_any in [false, true]:
		for id in c.buildings:
			var b: Dictionary = c.buildings[id]
			if (b["type"] != type) if not pass_any else not c.is_house(b):
				continue
			var r := _rect(b)
			var w := r.size.x + 1.0
			var dd := r.size.y + 1.0
			for s: Rect2 in [Rect2(Vector2(r.end.x + 0.5, r.position.y - 0.5), Vector2(w, r.size.y + 1.0)),
					Rect2(Vector2(r.position.x - 0.5 - w, r.position.y - 0.5), Vector2(w, r.size.y + 1.0)),
					Rect2(Vector2(r.position.x - 0.5, r.end.y + 0.5), Vector2(r.size.x + 1.0, dd)),
					Rect2(Vector2(r.position.x - 0.5, r.position.y - 0.5 - dd), Vector2(r.size.x + 1.0, dd))]:
				if _free(s):
					pick = b
					spot = s
					break
			if not pick.is_empty():
				break
		if not pick.is_empty():
			break
	if pick.is_empty():
		print("no free spot next to ", type)
		get_tree().quit(1)
		return
	var hr := _rect(pick)
	var sc := hr.size.x / aabb.size.x * k
	add_child(model)
	model.scale = Vector3.ONE * sc
	var cx := spot.get_center()
	var gy: float = game.land.height_at(cx.x, cx.y)
	model.global_position = Vector3(cx.x, gy - aabb.position.y * sc, cx.y)
	print("house ", pick["id"], " ", pick["type"], " rect ", hr, " → model at ", model.global_position, " scale ", snappedf(sc, 0.01),
		" size ", aabb.size * sc)
	# камера: на середину между домами, с четырёх сторон; потом крупно — модель и наш дом
	var mid := Vector3((hr.get_center().x + cx.x) * 0.5, gy + 1.0, (hr.get_center().y + cx.y) * 0.5)
	for yaw in [0.0, 90.0, 180.0, 270.0]:
		game.rig.set_view(mid, yaw, 32.0, 13.0)                  # (цель, поворот, наклон, расстояние)
		await frames(20)
		await shot("pair_%d" % int(yaw))
	for yaw in [0.0, 90.0, 180.0, 270.0]:
		game.rig.set_view(model.global_position + Vector3(0, -0.3, 0), yaw, 24.0, 9.0)
		await frames(20)
		await shot("close_%d" % int(yaw))
	for yaw in [0.0, 180.0]:
		game.rig.set_view(Vector3(hr.get_center().x, gy + 1.0, hr.get_center().y), yaw, 24.0, 9.0)
		await frames(20)
		await shot("ours_%d" % int(yaw))
	# на пустом ровном месте: копия нашего дома (те же детали, что в городе) и модель рядом — ничто не заслоняет
	var best := 1e9
	var base := Vector2(-1, -1)
	for bx in range(40, 360, 8):
		for bz in range(40, 330, 8):
			var r := Rect2(Vector2(bx - 8, bz - 6), Vector2(16, 22))
			if not _free(r):
				continue
			var n := 0
			for dx in range(-8, 9, 2):
				for dz in range(-6, 17, 2):
					n += (game.nature.get(Vector2i(int((bx + dx) / 2.0), int((bz + dz) / 2.0)), []) as Array).size()
			if n < best:
				best = n
				base = Vector2(bx, bz)
	if base.x < 0:
		print("no empty flat place")
	else:
		var xf: Transform3D = c.xf(pick)
		var o1 := Vector3(base.x - hr.size.x * 0.8, 0, base.y)
		o1.y = game.land.height_at(o1.x, o1.z)
		game.parts.place(c.blueprint(pick), Transform3D(xf.basis, o1), {})
		var o2 := Vector2(base.x + hr.size.x * 0.8, base.y)
		var gy2: float = game.land.height_at(o2.x, o2.y)
		model.global_position = Vector3(o2.x, gy2 - aabb.position.y * sc, o2.y)
		print("solo at ", base, " nature ", best)
		var m2 := Vector3(base.x, gy2 + 1.0, base.y)
		for yaw in [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]:
			game.rig.set_view(m2, yaw, 22.0, 10.0)
			await frames(20)
			await shot("solo_%d" % int(yaw))
	print("FPS ", Engine.get_frames_per_second())
	get_tree().quit()
