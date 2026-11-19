extends Node
## Модели, четыре поля, смена поз и нагрузка полного отряда.

const Enemy = preload("res://scripts/legion_enemy_actor.gd")
const View = preload("res://scripts/legion_battle_view.gd")
const PersonLayer = preload("res://scripts/fort_person_layer.gd")
const OUT := "D:/CivCity/.work/stage7/enemy3d/shots/"
const STRESS := ["gaul", "bandit", "berserker", "cataphractFoe", "khopesh", "bear",
	"boar", "gaulArcher", "druid", "nileArcher", "giant"]

var game: Game
var battle: LegionBattle
var out := OUT
var fails := 0
var squad: Array[Dictionary]


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=").trim_suffix("/") + "/"
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1920, 1080)
	var saved_clock := Legion.clock
	var saved_v2 := Legion.V2
	var forced_v2 := Legion.v2_test
	Legion.v2_test = true
	Legion.V2 = true
	var lang_before := I18n.lang
	I18n.set_lang("ru")
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	game.can_save = false
	game.hero_screen_auto = false
	add_child(game)
	await _run()
	if is_instance_valid(battle) and LegionBattle.current == battle:
		battle.abort()
	I18n.set_lang(lang_before)
	Legion.clock = saved_clock
	Legion.V2 = saved_v2
	Legion.v2_test = forced_v2
	print("ENEMY3D DONE fails=", fails)
	get_tree().quit(int(fails > 0))


func check(ok: bool, reason: String) -> bool:
	if not ok:
		fails += 1
		print("ENEMY3D FAIL ", reason)
	return ok


func until(condition: Callable, timeout: float) -> bool:
	var start := Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec() - start < timeout * 1000.0:
		await get_tree().process_frame
	return condition.call()


func shot(file: String, crop := Rect2i()) -> void:
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := out.path_join(file)
	var picture := get_viewport().get_texture().get_image()
	if not check(picture != null and not picture.is_empty(), "read " + file):
		return
	if crop.has_area():
		picture = picture.get_region(crop.intersection(Rect2i(Vector2i.ZERO, picture.get_size())))
	if check(picture.save_png(path) == OK, "save " + file):
		print("ENEMY3D SHOT ", path)


func _run() -> void:
	if not check(await until(func() -> bool: return game.ready_done, 180.0), "ready_done"):
		return
	game.settings["autosave"] = false
	if not check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory " + out):
		return
	if not check(DisplayServer.get_name() != "headless", "screenshots require graphics"):
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for id: String in Legion.ENEMIES:
		var options := int(Enemy.HUMANS.has(id)) + int(Enemy.BEASTS.has(id)) + int(id in Enemy.SPRITES)
		check(options == 1, "mapping " + id)
	for id: String in Enemy.HUMANS.keys() + Enemy.BEASTS.keys() + Enemy.SPRITES:
		check(Legion.ENEMIES.has(id), "unknown key " + id)
	print("ENEMY3D ROSTER %d humans %d beasts %d sprites" % [Enemy.HUMANS.size(), Enemy.BEASTS.size(), Enemy.SPRITES.size()])
	for file: String in DirAccess.get_files_at(Enemy.ASSETS):
		check(_good_name(file), "asset name " + file)
	await _lineup(Enemy.HUMANS.keys(), 12, 155.0, "1_lineup_humans.png")
	await _lineup(Enemy.BEASTS.keys(), 5, 197.0, "2_lineup_beasts.png")
	_make_squad(game.city.legion)
	await _fight("forest", ["forestBear", "boar", "bear", "boar"], "3_battle_forest.png")
	await _fight("gaul", ["gaul", "gaul", "gaulArcher", "druid"], "4_battle_gaul.png", true)
	await _fight("egypt", ["khopesh", "nileArcher", "priest", "venomBear"], "5_battle_egypt.png")
	await _fight("germania", STRESS, "7_boss.png")
	await _fight("britannia", ["briton", "chariot", "horseArcher"], "")


func _good_name(value: String) -> bool:
	var lower := value.to_lower()
	return not lower.contains("wolf") and not lower.contains("dog")


func _nodes(root: Node) -> void:
	check(_good_name(String(root.name)), "node name " + String(root.name))
	for child: Node in root.get_children():
		_nodes(child)


func _lineup(keys: Array, columns: int, height: float, file: String) -> void:
	var vp := get_viewport()
	var old_disable := vp.disable_3d
	vp.disable_3d = true
	var canvas := CanvasLayer.new()
	canvas.layer = 80
	add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("e7d6b9")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(background)
	var area := vp.get_visible_rect().size
	var layer := PersonLayer.new()
	background.add_child(layer)
	layer.setup("Lineup3D", 6.0)
	layer.fit(area)
	var labels := Node2D.new()
	background.add_child(labels)
	var rows := ceili(float(keys.size()) / columns)
	for i in keys.size():
		var id: String = keys[i]
		var model := Enemy.new()
		model.name = id
		layer.viewport.add_child(model)
		if not check(model.build_enemy(id, i), "%s %s" % [id, model.problem]):
			continue
		var row: int = i / columns
		var count := mini(columns, keys.size() - row * columns)
		var step := area.x / columns
		var feet := Vector2(area.x * 0.5 + ((i % columns) - (count - 1) * 0.5) * step,
			area.y * (0.06 + (row + 0.78) * 0.88 / rows))
		var visual_scale := clampf(float(Legion.ENEMIES[id].get("size", 1.0)), 0.9, 1.48 if model.wide else 1.25)
		if Enemy.HUMANS.has(id) and Enemy.HUMANS[id][1] in ["staff", "spear"]:
			visual_scale = minf(visual_scale, 1.06)
		if id in ["bear", "boar"]:
			_check_palette(model, id)
		layer.shadows.append(Vector3(feet.x, feet.y + 2.0, height * (1.24 if model.wide else 0.68)))
		layer.place(model, feet, height * visual_scale, -15.0 if not model.wide else -59.0)
		var caption := Label.new()
		caption.text = I18n.t(String(Legion.ENEMIES[id]["name"]))
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.add_theme_color_override("font_color", Color("36221c"))
		caption.add_theme_font_size_override("font_size", 17 if rows > 2 else 25)
		caption.size.x = step - 8.0
		caption.position = feet + Vector2(-caption.size.x * 0.5, 15.0)
		labels.add_child(caption)
	_nodes(layer.viewport)
	await shot(file)
	canvas.queue_free()
	vp.disable_3d = old_disable
	await get_tree().process_frame


func _check_palette(model: Node3D, id: String) -> void:
	var ok := false
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as StandardMaterial3D
			if material != null and material.resource_name == "Coat":
				var colors: PackedColorArray = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
				ok = material.vertex_color_use_as_albedo and not colors.is_empty() and colors[0] != Color.WHITE
	check(ok, "vertex palette " + id)


func _make_squad(legion: Legion) -> void:
	game.city.legion_v = 3
	squad.append(Legion.hero_unit_stats(5, 1, 1))
	for role: String in ["legionary", "spearman", "legionary", "archer"]:
		var person := legion._add_soldier({"cls": role, "female": false})
		var id := int(person["id"])
		if role != "archer":
			for part: String in ["armor", "helmet", "offhand", "sword"]:
				var item := legion.add_item(Gear.craft_item(part, 1))
				check(legion.equip(id, int(item["id"])), "test squad equipment " + part)
		var stats := Legion.unit_stats(role, 5)
		stats["sid"] = id
		squad.append(stats)


func _fight(region: String, keys: Array, file: String, close := false) -> void:
	var legion := game.city.legion
	var region_index := -1
	for i in Legion.regions().size():
		if Legion.regions()[i].get("id", "") == region:
			region_index = i
			break
	if not check(region_index >= 0, "province " + region):
		return
	var troops := squad.duplicate(true)
	var wave := []
	for id: String in keys:
		wave.append(Legion.enemy_stats(id, 1.0))
	if keys == STRESS:
		# Оставляем все 16 моделей в кадре до конца замера.
		for stats: Dictionary in troops + wave:
			stats["hp"] = int(stats["hp"]) * 8
	var setup := {"kind": "campaign", "stage": legion.stage_info(0, region_index, 0), "seed": 532,
		"squad": troops, "waves": [wave], "rations_paid": true, "perks": {"oil": 1, "bandage": 1, "volley": 1}}
	battle = LegionBattle.open(game, setup, Callable(), {"legion": legion, "speed": 1.0})
	if not check(await until(func() -> bool: return battle.sim != null and battle.fade.modulate.a <= 0.01, 35), "battle " + region):
		battle.abort()
		return
	var layer := battle.battle_view.people_layer
	var enemies := 0
	var sprites := 0
	var gaul_variants := {}
	var live_model: View.Fighter
	for view: View.Fighter in battle.views.values():
		if view.unit.side == "ally":
			check(view.actor != null and view.actor.get_parent() == layer.viewport, "ally shared viewport")
		elif view.unit.key in Enemy.SPRITES:
			sprites += 1
			check(view.sprite != null and view.actor == null, "2D fallback " + view.unit.key)
			if view.sprite != null:
				check(is_equal_approx(view.sprite.offset.y + View.BASELINE, View.CELL * 0.5), "2D baseline")
		elif check(view.actor != null and view.sprite == null and view.actor.get_parent() == layer.viewport
				and view.actor.rotation_degrees.y < 0.0, "3D shared viewport/facing " + view.unit.key):
			enemies += 1
			if view.unit.key == "gaul":
				gaul_variants[view.actor.get_meta("enemy_variant", -1)] = true
			if view.unit.boss or live_model == null:
				live_model = view
	check(enemies > 0 and enemies + sprites == keys.size(), "province coverage " + region)
	if region == "gaul":
		check(gaul_variants.size() == 2, "two variants of Gaul")
	print("ENEMY3D PROVINCE %s 3D=%d 2D=%d" % [region, enemies, sprites])
	_nodes(layer.viewport)
	_nodes(battle.battle_view.units)
	if not file.is_empty():
		await until(func() -> bool: return battle.sim.t >= 2.7, 14)
		if keys == STRESS:
			await _fps()
		battle.paused = true
		await shot(file)
		battle.paused = false
		if close:
			await _close_battle()
		if keys == STRESS:
			if check(is_instance_valid(live_model) and live_model.unit.alive, "live target for death check"):
				await _death(live_model)
	battle.abort()
	await get_tree().process_frame


func _melee() -> View.Fighter:
	for f: View.Fighter in battle.views.values():
		var u := f.unit
		if u.side == "ally" and u.alive and not u.ranged() and u.target != null and u.target.alive and f.clip == f.attack_clip:
			return f
	return null


func _close_battle() -> void:
	if not check(await until(func() -> bool: return _melee() != null, 8.0), "melee close-up"):
		return
	battle.paused = true
	var ally := _melee()
	var enemy: View.Fighter = battle.views[ally.unit.target.id]
	var view := battle.battle_view
	var feet := view.screen(ally.position).lerp(view.screen(enemy.position), 0.5)
	var height := maxf(ally.body_height(), enemy.body_height()) * view.world.scale.y
	var crop := Rect2i(Vector2i(feet - Vector2(510.0, height * 1.28 + 55.0)), Vector2i(1020, int(height * 1.42 + 105.0)))
	await shot("6_battle_close.png", crop)
	battle.paused = false


func _fps() -> void:
	check(battle.views.size() == 16, "5 allies + 10 enemies + boss for FPS")
	check(get_viewport().get_texture().get_size() == Vector2(1920.0, 1080.0), "FPS resolution")
	var start := Time.get_ticks_usec()
	for i in 120:
		await get_tree().process_frame
	var fps := 120000000.0 / maxf(1.0, Time.get_ticks_usec() - start)
	check(battle.views.size() == 16, "all 16 combatants at end of FPS sample")
	var viewport := battle.battle_view.people_layer.viewport
	var draws := viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var triangles := viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	print("ENEMY3D FPS %.1f at %dx%d, %d draws, %d triangles" % [fps, viewport.size.x, viewport.size.y, draws, triangles])
	check(fps >= 60.0, "60 FPS budget")


func _death(view: View.Fighter) -> void:
	var id := view.unit.id
	var unit := view.unit
	battle.sim._hurt(unit, unit.hp + 1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	check(not unit.alive and view.clip == view.death_clip and view.death >= 0.0, "death starts on sim kill")
	check(await until(func() -> bool: return not battle.views.has(id), 3.0), "fallen model hides and leaves the view")
	print("ENEMY3D DEATH ", unit.key)
