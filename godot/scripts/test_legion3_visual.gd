extends Node3D
## Пять кадров, свет города, границы камеры и бюджет отрисовки. Запускает владелец тестов.

const SCENERY := preload("res://scripts/camp_scenery.gd")

var out := "D:/CivCity/.work/stage2/legion3/shots/"
var game
var camp: CampUI


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2 and pair[0] == "out":
			out = pair[1] if pair[1].ends_with("/") else pair[1] + "/"
	Game.boot = {"new": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	game.can_save = false
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, reason: String) -> bool:
	if not ok:
		print("LEGION3 FAIL " + reason)
		get_tree().quit(1)
	return ok


func shot(file: String) -> bool:
	await frames(8)
	var peak := 0
	for i in 8:
		await RenderingServer.frame_post_draw
		peak = maxi(peak, camp.diorama.sub.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
		await frames(1)
	print("LEGION3 DRAWCALLS %d" % peak)
	if not check(peak > 0 and peak <= 900, "visible draw calls %d for %s (limit 900)" % [peak, file]):
		return false
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(out + file)
	if not check(err == OK, "save " + file):
		return false
	print("LEGION3 SHOT " + file)
	return true


func _inside_plaques() -> bool:
	var screen := Rect2(camp.global_position, camp.size)
	for slot: String in camp.plaques:
		var panel: Control = camp.plaques[slot]["panel"]
		if not check(screen.encloses(panel.get_global_rect()), "plaque outside screen: " + slot):
			return false
	return true


func _finish_upgrade(legion: Legion, slot: String) -> bool:
	var before := legion.camp_level(slot)
	if not check(legion.camp_upgrade(slot), "upgrade " + slot + ": " + legion.camp_can_upgrade(slot)):
		return false
	legion.upg["camp_" + slot]["end"] = Legion.now() - 1
	legion.tick()
	return check(legion.camp_level(slot) == before + 1, "finish timer " + slot)


func _run() -> void:
	var waited := 0
	while not game.ready_done:
		await frames(5)
		waited += 5
		if not check(waited < 18000, "ready_done timeout"):
			return
	game.can_save = false
	game.settings["autosave"] = false
	await frames(30)
	if not check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory"):
		return
	var city: City = game.city
	city.cozy_v = 1
	city.legion_v = 3
	city.money = 1000000
	city.hero = Hero.make("Гай Валерий", 0, Hero.PRESETS[0]["look"], true, 777)
	for i in 16:
		var house := city.place("house_pleb", Land.START + Vector2(8.0 * (i % 8), 8.0 * (i / 8)), 0, 0, 0, true)
		if not check(not house.is_empty(), "house %d" % i):
			return
		house["families"] = [{"name": "Юлии%d" % i, "n": 4, "cls": "plebs"}]
		house["pop"] = 4
	city.compute()
	var legion: Legion = city.legion
	legion.army_tick()
	legion.glory = 10000
	legion.mats = {"iron": 1000.0, "wood": 1000.0, "leather": 1000.0}
	if not check(city.stats["pop"] >= 60 and legion.v3(), "V3 and population"):
		return
	# Стартовые уровни — фикстура; изменения проходят через обычные таймеры.
	preload("res://scripts/test_fort_fixture.gd").set_level(legion, "hq", 3)
	preload("res://scripts/test_fort_fixture.gd").set_level(legion, "barracks", 2)
	preload("res://scripts/test_fort_fixture.gd").set_level(legion, "forge", 1)
	preload("res://scripts/test_fort_fixture.gd").set_level(legion, "store", 1)
	preload("res://scripts/test_fort_fixture.gd").set_level(legion, "mars", 1)
	if not _finish_upgrade(legion, "barracks") or not _finish_upgrade(legion, "forge"):
		return
	var recruits: Array[int] = []
	for i in 4:
		var soldier := legion.recruit_resident()
		if not check(not soldier.is_empty(), "recruit %d" % i):
			return
		recruits.append(int(soldier["id"]))
	# Герой уже занимает первое место, ставим ещё трёх новобранцев.
	for i in 3:
		if not check(legion.set_place(i + 1, recruits[i]), "place %d" % i):
			return
	if not check(legion.squad_v3().size() == 4, "three placed plus hero"):
		return
	city.money = maxf(city.money, 100000.0)
	legion.glory = maxf(legion.glory, 10000.0)
	var why := legion.camp_can_upgrade("store")
	if not check(legion.camp_upgrade("store"), "start store scaffold: " + why):
		return
	legion.flags["camp3d_guide"] = 4
	legion.rations = 8
	legion.pending_resources = {"rations": 6.0, "iron": 12.0, "wood": 10.0, "leather": 7.0}
	city.changed.emit()
	camp = CampUI.of(game.hud)
	if not check(camp != null, "camp attached"):
		return
	camp.open()
	await frames(10)
	if not check(is_instance_valid(camp.diorama), "Camp3D created (no painting fallback)"):
		return
	if not check(get_viewport().disable_3d, "city render disabled while camp open"):
		return
	if not check(camp.diorama.sub.own_world_3d and camp.diorama.figures.size() <= 16, "own world / figure cap"):
		return
	var view := camp.diorama
	if not _city_look(view):
		return
	for slot: String in Camp3D.PLOTS:
		if not check(view._pick(view.project(slot)) == slot, "footprint picking: " + slot):
			return
		if slot != "drill":
			var plot: Node3D = view.buildings[slot]
			if not check(bool(plot.get_meta("cutaway", false)) and int(plot.get_meta("city_piece_count", 0)) > 20, "Synty cutaway: " + slot):
				return
	if not check(view.world.find_children("*", "MultiMeshInstance3D", true, false).size() > 0, "batched scenery"):
		return
	var extent := Rect2()
	for slot: String in Camp3D.PLOTS:
		extent = view.footprint(slot) if extent.size == Vector2.ZERO else extent.merge(view.footprint(slot))
	var coverage := extent.size.x / view.size.x
	if not check(coverage >= 0.63 and coverage <= 0.78, "default camp width %.3f" % coverage):
		return
	if not _inside_plaques() or not await shot("1_camp.png"):
		return
	view.focus_plot("barracks")
	if not _inside_plaques() or not await shot("2_barracks.png"):
		return
	view.focus_plot("forge")
	if not await shot("3_forge.png"):
		return
	view.focus_plot("hq")
	var hero_found := false
	for entry: Dictionary in view.figures:
		if entry["role"] == "hero":
			hero_found = true
	if not check(hero_found, "hero at headquarters") or not await shot("4_hq_hero.png"):
		return
	# Все четыре предельных положения, а не только красивый угол для снимка.
	for x: float in [-22, 22]:
		for z: float in [-16, 16]:
			view.focus = Vector3(x, 0, z)
			view.zoom = Camp3D.MAX_ZOOM
			view._update_camera()
			if not _ground_in_frame(view):
				return
	if not _inside_plaques() or not await shot("5_edge.png"):
		return
	# Новобранец по-прежнему проходит через ворота в локальных координатах лагеря.
	view.focus_plot("barracks", false)
	var before := legion.soldiers.size()
	camp._recruit_pick(legion.recruit_candidates()[0])
	camp._close_modal()
	camp._hide_card()
	if not check(legion.soldiers.size() == before + 1, "recruit from picker"):
		return
	var sid := int(legion.soldiers[-1]["id"])
	await get_tree().create_timer(2.0).timeout
	var walking := false
	for entry: Dictionary in view.figures:
		if int(entry["id"]) == sid:
			var pos: Vector3 = (entry["node"] as Node3D).position
			walking = pos.distance_to(Camp3D.GATE) > 0.2 and pos.distance_to(entry["home"]) > 0.2
	if not check(walking and view.arrivals.has(sid), "recruit walks inside shifted world"):
		return
	if not check(view.scaffolds.has("store") and view.figures.size() <= 16, "scaffold / figure cap"):
		return
	var old: WeakRef = weakref(view)
	camp.close()
	await frames(2)
	if not check(not get_viewport().disable_3d and old.get_ref() == null, "close restores city and frees world"):
		return
	camp.open()
	await frames(8)
	if not check(is_instance_valid(camp.diorama), "reopen creates camp") or not _city_look(camp.diorama):
		return
	camp.close()
	await frames(2)
	print("LEGION3 DONE")
	get_tree().quit()


func _city_look(view: Camp3D) -> bool:
	var we := view.world.get_node("CityEnvironment") as WorldEnvironment
	var source: Environment = game.env
	if not check(we.environment != source and we.environment.sky != source.sky, "independent environment and sky"):
		return false
	for property: String in ["tonemap_mode", "tonemap_exposure", "ssao_enabled", "glow_enabled", "fog_enabled", "ssil_enabled"]:
		if not check(we.environment.get(property) == source.get(property), "city quality: " + property):
			return false
	var sun := view.world.get_node("CampSun11") as DirectionalLight3D
	if not check(sun.light_color == Color("fff1de") and is_equal_approx(sun.light_energy, 2.6), "11:00 sun"):
		return false
	var layer := view.sub.get_node("CampGrade") as CanvasLayer
	var grade := (layer.get_child(0) as ColorRect).material as ShaderMaterial
	if not check(grade != game.grade and grade.shader == game.grade.shader, "own grade with city shader"):
		return false
	if not check(grade.get_shader_parameter("tint") == Vector3.ONE and is_equal_approx(float(grade.get_shader_parameter("rain")), 0.0), "daylight grade"):
		return false
	var ground := view.world.get_node("CampTerrain") as MeshInstance3D
	var mat := ground.material_override as ShaderMaterial
	if not check(mat != game.land_mat and mat.shader == game.land_mat.shader, "own terrain with city shader"):
		return false
	if not check(mat.get_shader_parameter("surf") != game.land_mat.get_shader_parameter("surf"), "camp road mask is independent"):
		return false
	return true


func _ground_in_frame(view: Camp3D) -> bool:
	var sz := Vector2(view.sub.size)
	for uv: Vector2 in [Vector2.ZERO, Vector2(1, 0), Vector2(0, 1), Vector2.ONE]:
		var origin := view.camera.project_ray_origin(uv * sz)
		var ray := view.camera.project_ray_normal(uv * sz)
		if not check(ray.y < -0.1, "camera corner points at ground"):
			return false
		var distance := (view.world.global_position.y - origin.y) / ray.y
		var point := view.world.to_local(origin + ray * distance)
		if not check(absf(point.x) < SCENERY.SPAN / 2 - 20 and absf(point.z) < SCENERY.SPAN / 2 - 20, "terrain margin at camera corner"):
			return false
		if not check(distance > 0 and distance < view.camera.far - 20, "ground before far clip"):
			return false
	return true
