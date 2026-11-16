extends Node3D
## PERF4: сброс кешей, прежний порядок RNG, пауза и снимки A/B. Запускает Claude.

const PerfTest := preload("res://scripts/test_perf.gd")
const Probe := preload("res://scripts/perf_process_probe.gd")
var game
var fails := 0
var out := "D:/CivCity/.work/stage5/perf4/shots"


class InnHost extends Node:
	var ready_done := true
	var city: City
	var people: Node
	var speed := 1.0
	var hour := 10.0
	var mode := "new"
	var settings := {"quality": "high"}


class TickTarget extends Node:
	var ticks := 0
	var elapsed := 0.0
	var stop_after_next := false

	func _process(dt: float) -> void:
		ticks += 1
		elapsed += dt
		if stop_after_next:
			set_process(false)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=")
	Game.boot = {"new": "1", "hour": "10"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	game.can_save = false
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, message: String) -> void:
	if not ok:
		fails += 1
		print("PERF4 FAIL ", message)


func _roster_tests() -> void:
	var ppl: People = game.people
	var family: Array = ppl._make_family("PERF4", 3, -1, Land.START, "plebs")
	Gfx.proc_fast = true
	var snapshot := ppl._roster_snapshot()
	check(snapshot.size() == ppl.residents.size(), "roster includes new family")
	check(is_same(snapshot, ppl._roster_snapshot()), "unchanged roster reuses snapshot")
	var r: Dictionary = family[0]
	var cap := ppl.max_vis
	ppl.max_vis += 4
	check(ppl._node(r) != null, "resident node created")
	var expected := ppl.residents.filter(func(x): return x["node"] != null)
	check(ppl._props_snapshot() == expected, "props retain full roster order")
	ppl._hide(r)
	check(not ppl._props_snapshot().has(r), "hiding invalidates props cache")
	ppl._remove(r)
	check(snapshot.has(r) and not ppl._roster_snapshot().has(r), "removal leaves current iteration intact")
	for member: Dictionary in family:
		if ppl.by_id.has(member["id"]):
			ppl._remove(member)
	ppl.max_vis = cap
	Gfx.proc_fast = false
	check(ppl._roster_snapshot() == ppl.residents and ppl._props_snapshot() == ppl.residents, "p4=0 returns original lists")
	Gfx.proc_fast = true


func _tour_tests() -> void:
	var host := InnHost.new()
	host.city = City.new(game.land)
	host.people = Node.new()
	host.city.cozy_v = 1
	host.city.buildings = {
		1: {"id": 1, "type": "tree", "active": true},
		2: {"id": 2, "type": "mansio", "active": true},
		3: {"id": 3, "type": "mansio", "active": false},
		4: {"id": 4, "type": "mansio", "active": true}}
	var tour := Tourism.new()
	tour.setup(host)
	var reference := {}
	var reference_rng := 0
	for on: bool in [false, true]:
		Gfx.proc_fast = on
		tour._rng.seed = 4421
		tour._next = {2: 100.0, 3: 200.0, 4: 300.0}
		for step: Array in [[0.01, 1.0], [0.04, 3.0], [0.005, 0.0], [0.02, 2.0]]:
			host.speed = float(step[1])
			tour._process(float(step[0]))
		if not on:
			reference = tour._next.duplicate()
			reference_rng = tour._rng.state
		else:
			check(tour._next == reference and tour._rng.state == reference_rng, "tourism timers and RNG match A/B at variable speed and pause")
	check(tour._inn_list().size() == 3, "all inns cached, including unstaffed")
	host.city.buildings[5] = {"id": 5, "type": "mansio", "active": true}
	host.city.building_added.emit(host.city.buildings[5])
	check(tour._inn_list().size() == 4, "adding invalidates inn cache")
	host.city.buildings.erase(5)
	host.city.building_removed.emit({"id": 5})
	check(tour._inn_list().size() == 3, "removal invalidates inn cache")
	host.city.buildings[2] = {"id": 2, "type": "mansio", "active": false}
	host.city.changed.emit()
	check(not bool((tour._inn_list()[0] as Dictionary)["active"]), "replacement at same building count invalidates cache")
	tour.free()
	host.people.free()
	host.city = null
	host.free()


func _probe_test() -> void:
	var target := TickTarget.new()
	var total := [0, 0]
	var probe := Probe.new()
	probe.setup(target, total)
	target.set_process(false)
	probe._process(0.125)
	probe._process(0.25)
	check(target.ticks == 2 and is_equal_approx(target.elapsed, 0.375) and int(total[1]) == 2, "probe calls target once with exact dt")
	target.stop_after_next = true
	probe._process(0.05)
	check(not probe.enabled and not target.is_processing(), "probe preserves self-disabled callback")
	probe.free()
	target.free()


func _pointer_test() -> void:
	var hud: Hud = game.hud
	var visible_before := hud.root.visible
	hud.root.visible = false
	hud._pointer_dirty = false
	hud._pointer_poll = 0.1
	hud._pointer_elapsed = 0.0
	hud._pointer_mouse = hud.get_viewport().get_mouse_position()
	hud._pointer_tool = game.tool
	hud._pointer_tick(0.02)
	check(is_equal_approx(hud._pointer_elapsed, 0.02), "pointer poll retains elapsed time")
	hud._input(InputEventMouseMotion.new())
	hud._pointer_tick(0.01)
	check(not hud._pointer_dirty and hud._pointer_elapsed == 0.0, "mouse movement polls immediately")
	hud._pointer_tick(0.11)
	check(hud._pointer_elapsed == 0.0, "stationary pointer polls at 10 Hz")
	hud.root.visible = visible_before


func _same_lod(c: Citizen, label: String) -> void:
	Gfx.proc_fast = true
	game.gfx._anims(0.0)
	var k := c.lod_k
	var hidden := c.batch_hidden
	Gfx.proc_fast = false
	game.gfx._anims(0.0)
	check(c.lod_k == k and c.batch_hidden == hidden, label)
	Gfx.proc_fast = true
	game.gfx._anims(0.0)
	game.gfx._anims(0.0)                     # неподвижная поза попала в кеш


func _gfx_tests(c: Citizen) -> void:
	var at := c.global_position
	var cam: Camera3D = game.rig.cam
	game.rig.set_view(at, 15.0, 35.0, 9.0)
	_same_lod(c, "near LOD matches A/B")
	check(c.lod_k == 1, "near resident stays full rate")
	game.rig.set_view(at, 15.0, 35.0, 70.0)
	_same_lod(c, "camera movement invalidates LOD")
	var fov := cam.fov
	cam.fov = 15.0
	_same_lod(c, "projection change invalidates LOD")
	cam.fov = fov
	c.scale *= 0.68
	_same_lod(c, "scale change invalidates LOD")
	c.scale = Vector3.ONE * Citizen.SIZE
	c.global_position = cam.global_position + cam.global_basis.z * 10.0
	_same_lod(c, "leaving frame invalidates LOD")
	check(c.batch_hidden, "offscreen pose is hidden")
	c.global_position = at
	game.rig.set_view(at, 15.0, 35.0, 9.0)
	_same_lod(c, "return to frame invalidates LOD")
	c.anim.speed_scale = 0.0
	c.batch_flush()
	var count := c.batch_steps
	for f in 16:
		game.gfx._anims(1.0 / 60.0)
	check(c.batch_steps == count, "pause avoids repeated writes of unchanged pose")
	c.batch_dirty = true
	game.gfx._anims(0.0)
	check(not c.batch_dirty and c.batch_steps == count + 1, "pause still applies dirty pose")
	c.batch_acc = 0.15
	game.gfx._anims(0.0)
	check(is_zero_approx(c.batch_acc), "pause flushes pending animation time")


func _shots(c: Citizen) -> void:
	var freezer := PerfTest.new()
	freezer.game = game
	freezer._freeze(true)
	for view: Array in [["close", 9.0], ["mid", 35.0]]:
		game.rig.set_view(c.global_position, 15.0, 35.0, float(view[1]))
		var before: Image
		for on: bool in [false, true]:
			Gfx.proc_fast = on
			game.gfx._anims(0.0)
			await frames(240)
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var path := out.path_join("fixture_%s_p4%d.png" % [view[0], int(on)])
			check(img.save_png(path) == OK, "save " + path)
			print("PERF4 SHOT ", path)
			if not on:
				before = img
			else:
				var diff: Dictionary = PerfTest._same(before, img)
				print("PERF4 diff %s %s" % [view[0], diff["info"]])
				check(bool(diff["same"]), "frozen A/B screenshot " + str(view[0]))
	freezer._unfreeze()
	freezer.free()


func _run() -> void:
	var waited := 0
	while not game.ready_done and waited < 18000:
		await frames(5)
		waited += 5
	if not game.ready_done:
		check(false, "ready_done timeout")
		get_tree().quit(1)
		return
	game.can_save = false
	game.settings["autosave"] = false
	game.speed = 0.0
	game.clock_hours = false
	game.rig.cine = true
	game.set_process(false)
	game.people.set_process(false)
	game.hud.set_process(false)
	game.gfx.set_process(false)
	game.settings["quality"] = "high"
	game._apply_quality()
	check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory")
	_roster_tests()
	_tour_tests()
	_probe_test()
	_pointer_test()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7801
	var c := Citizen.create(rng, false)
	game.actors_root.add_child(c)
	c.position = Vector3(Land.START.x, game.land.height_at(Land.START.x, Land.START.y), Land.START.y)
	c.play("Walk", 0.0, 0.2)
	_gfx_tests(c)
	await _shots(c)
	Gfx.proc_fast = true
	print("PERF4 DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
