extends Node3D
## Картинки комнат за проёмами (16.11, владелец: «рисунки неверно расположены»): каждая постройка из Interiors.IMAGES — одна на чистом месте,
## 11:00, людей нет; два близких снимка с земли (камера 1,6–2,5 м, 4–7 м перед главным проёмом), взгляд внутрь.
##   bash .work/py/gpu_run.sh res://test_rooms.tscn -- out=D:/CivCity/.work/stage2/rooms/r2/ [only=mansio,bakery] [variants=0,1] [hour=11]
##   → «ROOMS SHOT <файл>», «ROOMS DONE»
var game
var out := "D:/CivCity/.work/stage2/rooms/r2/"
var only: PackedStringArray = []
var variants: PackedStringArray = ["0"]
var hour := 11.0
var dist := 5.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"out": out = kv[1] if kv[1].ends_with("/") else kv[1] + "/"
			"only": only = kv[1].split(",")
			"variants": variants = kv[1].split(",")
			"hour": hour = float(kv[1])
			"dist": dist = float(kv[1])
	Game.boot = {"new": "1", "hour": str(int(hour))}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(30)
	var c: City = game.city
	for r in Defs.RESEARCH:
		c.research[r["id"]] = true
	c.level = 7
	c.money = 9000000
	var X0 := 140.0
	var Z0 := 120.0
	game.clear_nature(Vector2(X0, Z0), 40.0)
	await frames(4)
	game.hud.visible = false
	game.env.fog_enabled = false
	game.env.volumetric_fog_enabled = false
	for ch in game.get_children():       # вода (земля у здания может уйти под неё) — прочь
		if ch is MeshInstance3D and (ch as MeshInstance3D).mesh is PlaneMesh:
			(ch as Node3D).visible = false
	game.rig.cine = true
	game.rig.attrs.dof_blur_far_enabled = false
	game.rig.attrs.dof_blur_near_enabled = false
	game._set_hour(hour)
	DirAccess.make_dir_recursive_absolute(out)
	var types: Array = Interiors.IMAGES.keys()
	types.sort()
	for t: String in types:
		if not only.is_empty() and not (t in only):
			continue
		if not Defs.B.has(t):
			continue
		for vs in variants:
			var b := c.place(t, Vector2(X0, Z0), 0.0, int(vs), 0, true)
			if b.is_empty() or not b.has("id"):
				print("ROOMS SKIP ", t, " ", vs)
				continue
			game._show(b)
			game._set_hour(hour)
			await frames(6)
			var bp: Bp = c.blueprint(b)
			var xf: Transform3D = c.xf(b)
			var fz := bp.front_z()
			if is_inf(fz) or is_nan(fz):
				fz = bp.door.z - 1.0
			var dx := bp.door.x
			var shots := [
				[Vector3(dx, 1.9, fz + dist), Vector3(dx, 1.3, fz - 3.0)],
				[Vector3(dx + 3.8, 2.2, fz + dist), Vector3(dx - 0.5, 1.3, fz - 2.0)],
			]
			for k in 2:
				var s: Array = shots[k]
				var p: Vector3 = xf * (s[0] as Vector3)
				var l: Vector3 = xf * (s[1] as Vector3)
				game.rig.cam.global_position = p
				game.rig.cam.look_at(l, Vector3.UP)
				_no_particles(game)
				await frames(12)
				_no_particles(game)
				var img := get_viewport().get_texture().get_image()
				img.convert(Image.FORMAT_RGB8)
				var fn := "%s%s%s_%d.jpg" % [out, t, "" if vs == "0" else "_v" + vs, k]
				img.save_jpg(fn, 0.85)
				print("ROOMS SHOT ", fn)
			game._hide(b)
			c.remove(b, false, true)
			await frames(2)
	print("ROOMS DONE")
	get_tree().quit(0)


func _no_particles(n: Node) -> void:
	for ch in n.get_children():
		if ch is GPUParticles3D or ch is CPUParticles3D:
			(ch as Node3D).visible = false
		_no_particles(ch)
